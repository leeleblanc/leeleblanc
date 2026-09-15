-- =====================================================================
-- MODULE: BATTERY SAVER — on battery, the config slows ITSELF down
-- =====================================================================
-- 🔋 LL: "when I am only on battery power, I lower the battery
-- consumption … DO not propose screen dimming. I can do that on my own.
-- Let's be creative, but aim for stability." Both halves of that
-- sentence shaped this module.
--
-- WHAT IT DOES, in two halves:
--
--   1. ECO MODE. On battery, the config's own pollers slow down and its
--      one expensive background job waits for the cord. What may be
--      slowed is declared by the code that OWNS each timer, through the
--      eco registry in init.lua — a registration names a normal and a
--      battery cadence and an apply function that rebuilds its own
--      timer; this module only says WHEN. Nothing here reaches into
--      another module's timer, ever. The shipped registrations:
--         clipboard poll        0.5s → 2s    (7,200 → 1,800 wakes/hour)
--         injection watchdog    5s   → 60s
--         autocorrect watchdog  30s  → 120s
--         expander watchdog     30s  → 120s
--         activity poll         5s   → 15s
--         focus detection       4s   → 12s
--         recent docs boot scan held until AC (the Spotlight sweep —
--                               the priciest periodic thing here)
--      Every cadence is restored the moment the cord is back. Honest
--      sizing: this half buys minutes of battery, not hours — its real
--      value is that the config becomes close to free on battery.
--
--   2. THE HOG CALLER-OUT. The real battery goes to other apps. On
--      battery only, one out-of-process ps sample every few minutes
--      watches for an app holding serious CPU across two consecutive
--      samples, and NAMES it in a notification — once per app per
--      hour, never more. It never kills anything: naming is this
--      module's whole job, and ⇪⇧; already exists as the hammer.
--
-- ⚖️ WHAT IT DELIBERATELY DOES NOT DO, and each is a decision:
--   · NO screen dimming — LL does that by hand, by request.
--   · NO macOS Low Power Mode toggling. pmset needs root: a password
--     prompt on every unplug, or a sudoers edit. Both are against this
--     config's security posture, and System Settings already offers
--     Low Power Mode "Only on Battery" natively — set it once by hand.
--   · NO killing, pausing or renicing of other apps. A tool that
--     quietly stops your app on battery is a bug report from the
--     future. This one only tells you what it sees.
--
-- 🧷 STABILITY RULES, because a power tool that flaps is worse than
-- none:
--   · EVENT-DRIVEN. hs.battery.watcher fires only when power state
--     changes; on AC this module adds ZERO periodic work. The only
--     recurring thing it ever runs — the ps sample — exists on battery
--     alone and stops with it.
--   · DEBOUNCED. Power must HOLD for debounceSecs before anything
--     changes cadence, so briefly unplugging to move to the couch never
--     thrashes six timers. Boot skips the debounce — a Mac that boots
--     on battery IS on battery, there is no flap to wait out.
--   · STATE-PRESERVING. Every shipped apply rebuilds its timer keeping
--     the running/stopped state it found, so the lag probe's held-down
--     watchdogs stay held down through a flip and nothing deliberately
--     off is quietly switched back on.
--   · A DESKTOP IS A NO-OP. The power source never reads Battery Power,
--     the watcher never fires, the module loads and sleeps. The work
--     Mac needs no profile override.
--
-- Console doors: _G.eco() says what is slowed right now and by how
-- much · _G.battReport() charge, drain, time left, top consumers ·
-- _G.ecoOn() / _G.ecoOff() force it either way · _G.ecoAuto() hands
-- control back to the power source.

local M = {
    name    = "Battery Saver",
    order   = 16,
    family  = "auto",
    summary = "On battery the config's own pollers slow down; battery hogs get named",
    cheatsheet = {
        title = "🔋 BATTERY SAVER (automatic)",
        entries = {
            { "on battery", "the config's own timers slow; Spotlight boot scan waits for AC" },
            { "on power", "every cadence restored the moment the cord is back" },
            { "hogs", "an app eating the CPU on battery is NAMED, never killed — ⇪⇧; is the hammer" },
            { "_G.eco()", "Console: what is slowed right now, and by how much" },
            { "_G.battReport()", "Console: charge, drain rate, time left, top consumers" },
            { "_G.ecoOn() · _G.ecoOff() · _G.ecoAuto()", "Console: force eco either way, or hand it back" },
        },
    },
}

function M.setup(core)
    local bs = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    bs.enabled      = true
    bs.debounceSecs = 20     -- power must HOLD this long before cadence flips
    bs.sampleSecs   = 240    -- battery-only: seconds between CPU samples
    bs.hogPct       = 60     -- % CPU that counts toward being named
    bs.hogStrikes   = 2      -- consecutive samples over hogPct before naming
    bs.hogQuietMins = 60     -- once named, an app stays quiet this long
    bs.ps           = "/bin/ps"
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("battery", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("battery", m) end end
    local function epoch()
        local ok, t = pcall(hs.timer.secondsSinceEpoch)
        return ok and tonumber(t) or os.time()
    end

    -- Standalone runs (a test file, the hostile pass) load this module
    -- without init.lua, so the registry stub may be absent. This shim
    -- only RECORDS, same as the real one — drive logic all lives here.
    if not _G.eco then
        _G.eco = { registry = {}, active = false,
                   register = function(n, s) _G.eco.registry[n] = s end }
    end

    bs.mode    = "auto"   -- auto · on (forced eco) · off (forced full speed)
    bs.applied = "ac"     -- what the registry is currently set to
    bs.pending = nil      -- the debounce timer, when a flip is waiting
    bs.since   = nil      -- epoch of the last applied flip
    bs.status  = "watching the power source"

    -- ---- what the power source wants ----------------------------------
    local function onBattery()
        local src
        pcall(function() src = hs.battery.powerSource() end)
        return src == "Battery Power"
    end

    function bs.desired()
        if bs.mode == "on"  then return "battery" end
        if bs.mode == "off" then return "ac" end
        return onBattery() and "battery" or "ac"
    end

    -- ---- the hog caller-out --------------------------------------------
    -- One ps, no shell, argument array (the net_tools rule). -c keeps the
    -- command NAME rather than a full path with spaces to mis-split; -r
    -- sorts by CPU so the top rows are the only ones that matter.
    bs.sampler    = nil
    bs.strikes    = {}    -- app name → consecutive samples over hogPct
    bs.mutedUntil = {}    -- app name → epoch until which it stays named-once
    bs.lastTop    = {}    -- last sample's top rows, for _G.battReport()
    bs.named      = 0     -- lifetime count, for the report

    function bs.parsePs(out)
        -- The %CPU COMM header line does not start with a number, so the
        -- pattern skips it for free; a comma decimal (some locales) still
        -- reads as a number.
        local rows = {}
        for line in tostring(out or ""):gmatch("[^\r\n]+") do
            local pct, name = line:match("^%s*(%d+[%.,]?%d*)%s+(.+)$")
            if pct then
                rows[#rows + 1] = { pct = tonumber((pct:gsub(",", "."))) or 0,
                                    name = name }
            end
        end
        return rows
    end

    function bs.nameHog(r)
        local now = epoch()
        if (bs.mutedUntil[r.name] or 0) > now then return false end
        bs.mutedUntil[r.name] = now + bs.hogQuietMins * 60
        bs.named = bs.named + 1
        local mins = math.max(1, math.floor((bs.strikes[r.name] or bs.hogStrikes)
                                            * bs.sampleSecs / 60 + 0.5))
        local body = string.format(
            "%d%% CPU across the last %d minutes on battery. ⇪⇧; ends it if you want that.",
            math.floor(r.pct + 0.5), mins)
        pcall(function()
            bs.lastNotify = hs.notify.new(nil, {
                title = "🔋 " .. r.name .. " is eating your battery",
                informativeText = body,
            })
            bs.lastNotify:send()
        end)
        say("named " .. r.name .. " at " .. tostring(r.pct) .. "% CPU")
        return true
    end

    function bs.note(rows)
        bs.lastTop = {}
        for i = 1, math.min(#rows, 5) do bs.lastTop[i] = rows[i] end
        local seen = {}
        for _, r in ipairs(rows) do
            if r.pct >= bs.hogPct and not seen[r.name] then
                seen[r.name] = true
                bs.strikes[r.name] = (bs.strikes[r.name] or 0) + 1
                if bs.strikes[r.name] >= bs.hogStrikes then
                    bs.nameHog(r)
                end
            end
        end
        -- An app that dropped back under the line starts over. Muting is
        -- separate bookkeeping: dropping does NOT clear a mute, so an app
        -- that saws across the threshold is still named once an hour.
        for name in pairs(bs.strikes) do
            if not seen[name] then bs.strikes[name] = nil end
        end
    end

    function bs.sampleOnce()
        local ok = pcall(function()
            local t = hs.task.new(bs.ps, function(code, sout, serr)
                if code ~= 0 then return end
                bs.note(bs.parsePs(sout))
            end, { "-Aceo", "pcpu,comm", "-r" })
            bs.task = t          -- HELD: an unreferenced hs.task is reaped
            t:start()
        end)
        if not ok then warn("ps sample could not start") end
    end

    local function startSampler()
        if bs.sampler then return end
        local ok = pcall(function()
            bs.sampler = hs.timer.doEvery(bs.sampleSecs, bs.sampleOnce)
        end)
        if ok then bs.sampleOnce() end   -- first sample now, not in 4 minutes
    end

    local function stopSampler()
        if bs.sampler then pcall(function() bs.sampler:stop() end) end
        bs.sampler, bs.strikes = nil, {}
    end

    -- ---- applying a state ----------------------------------------------
    local function registryCounts()
        local slowed, held = 0, 0
        for _, spec in pairs(_G.eco.registry) do
            if type(spec) == "table" then
                if spec.apply and spec.saver then slowed = slowed + 1
                elseif spec.hold then held = held + 1 end
            end
        end
        return slowed, held
    end

    function bs.apply(state)
        if state == bs.applied then return end
        bs.applied, bs.since = state, epoch()
        local saving = state == "battery"
        _G.eco.active = saving
        for _, spec in pairs(_G.eco.registry) do
            if type(spec) == "table" then
                if spec.apply and spec.saver and spec.normal then
                    pcall(spec.apply, saving and spec.saver or spec.normal)
                elseif spec.hold then
                    pcall(spec.hold, saving)
                end
            end
        end
        local slowed, held = registryCounts()
        if saving then
            startSampler()
            bs.status = "ECO — on battery"
            print(string.format(
                "🔋 On battery — eco: %d timer(s) slowed, %d job(s) held for AC, "
                .. "hog watch every %d min. _G.eco() explains; full speed returns with the cord.",
                slowed, held, math.floor(bs.sampleSecs / 60)))
        else
            stopSampler()
            bs.status = "full speed — on power"
            print("🔌 On power — eco off: every timer back at its normal cadence.")
        end
        say("applied " .. state .. " (" .. slowed .. " slowed, " .. held .. " held)")
    end

    -- ---- deciding WHEN, with the debounce ------------------------------
    -- immediate = true skips the debounce: boot (no flap to wait out) and
    -- the console commands (a typed order is not a flap).
    function bs.evaluate(immediate)
        if bs.pending then
            pcall(function() bs.pending:stop() end)
            bs.pending = nil
        end
        local want = bs.desired()
        if want == bs.applied then return end
        if immediate then
            bs.apply(want)
            return
        end
        local ok = pcall(function()
            bs.pending = hs.timer.doAfter(bs.debounceSecs, function()
                bs.pending = nil
                local still = bs.desired()
                if still ~= bs.applied then bs.apply(still) end
            end)
        end)
        if not ok then bs.apply(want) end   -- no timers? act now, honestly
    end

    -- ---- console doors --------------------------------------------------
    function _G.eco.report()
        local L = { "🔋 Battery Saver — " .. bs.status
                        .. " (mode: " .. bs.mode .. ")" }
        local src
        pcall(function() src = hs.battery.powerSource() end)
        L[#L + 1] = "   power   : " .. tostring(src or "unknown")
        if bs.pending then
            L[#L + 1] = "   pending : a flip is waiting out the "
                        .. bs.debounceSecs .. "s debounce"
        end
        local names = {}
        for name in pairs(_G.eco.registry) do names[#names + 1] = name end
        table.sort(names)
        L[#L + 1] = "   registry:"
        for _, name in ipairs(names) do
            local spec = _G.eco.registry[name]
            if spec.apply and spec.saver then
                local now = _G.eco.active and spec.saver or spec.normal
                L[#L + 1] = string.format("     · %-22s %gs → %gs on battery (now %gs)",
                                          name, spec.normal, spec.saver, now)
            elseif spec.hold then
                L[#L + 1] = string.format("     · %-22s %s", name,
                    _G.eco.active and "HELD until AC" or "runs normally")
            end
        end
        if #names == 0 then L[#L + 1] = "     (nothing registered)" end
        L[#L + 1] = "   hogs    : " .. (bs.sampler and
            ("watching every " .. bs.sampleSecs .. "s — " .. bs.named .. " named so far")
            or "off (AC) — runs on battery only")
        local out = table.concat(L, "\n")
        print(out)
        return out
    end

    -- _G.eco() the call — the report — while _G.eco.register stays the
    -- registry door. One name, both jobs, via the call metamethod.
    pcall(function()
        setmetatable(_G.eco, { __call = function() return _G.eco.report() end })
    end)

    function _G.battReport()
        local pct, charging, src, amps, mins, health
        pcall(function() pct      = hs.battery.percentage() end)
        pcall(function() charging = hs.battery.isCharging() end)
        pcall(function() src      = hs.battery.powerSource() end)
        pcall(function() amps     = hs.battery.amperage() end)
        pcall(function() mins     = hs.battery.timeRemaining() end)
        pcall(function() health   = hs.battery.healthCondition() end)
        local L = { "🔋 Battery" }
        if pct == nil and src == nil then
            L[#L + 1] = "   no battery readings on this Mac — a desktop, or the API is unavailable"
        else
            L[#L + 1] = "   charge  : " .. (pct and (math.floor(pct + 0.5) .. "%") or "unknown")
                        .. (charging and " · charging" or "")
            L[#L + 1] = "   source  : " .. tostring(src or "unknown")
            if amps and amps < 0 then
                L[#L + 1] = "   drain   : " .. math.floor(-amps + 0.5) .. " mA"
            end
            if mins and mins > 0 then
                L[#L + 1] = string.format("   left    : ~%dh %02dm",
                                          math.floor(mins / 60), mins % 60)
            elseif mins == -1 then
                L[#L + 1] = "   left    : calculating…"
            end
            if health then L[#L + 1] = "   health  : " .. tostring(health) end
        end
        L[#L + 1] = "   eco     : " .. bs.status .. " (mode: " .. bs.mode .. ")"
        if #bs.lastTop > 0 then
            L[#L + 1] = "   top CPU at the last battery sample:"
            for _, r in ipairs(bs.lastTop) do
                L[#L + 1] = string.format("     %5.1f%%  %s", r.pct, r.name)
            end
        end
        local out = table.concat(L, "\n")
        print(out)
        return out
    end

    function _G.ecoOn()   bs.mode = "on";   bs.evaluate(true); return bs.status end
    function _G.ecoOff()  bs.mode = "off";  bs.evaluate(true); return bs.status end
    function _G.ecoAuto() bs.mode = "auto"; bs.evaluate(true); return bs.status end

    _G.batterySaver = bs   -- inspectable from the Console, drivable by tests

    -- ---- wiring ---------------------------------------------------------
    if not bs.enabled then
        bs.status = "off (bs.enabled = false)"
        return
    end

    local watcherOK = false
    pcall(function()
        bs.watcher = hs.battery.watcher.new(function() bs.evaluate(false) end)
        if bs.watcher and bs.watcher.start then
            bs.watcher:start()
            watcherOK = true
        end
    end)
    if not watcherOK then
        -- No battery API: a desktop build, a stripped Hammerspoon, the
        -- hostile world. Eco never engages by itself; the console doors
        -- still answer, and _G.ecoOn() still works as a hand switch.
        bs.status = "idle — no battery watcher on this Mac (_G.ecoOn() still works)"
        warn("battery watcher unavailable — automatic eco is off")
        return
    end

    -- Boot on battery IS on battery: apply now, no debounce. Modules that
    -- register after this moment (warm-phase registrations like focus
    -- detection) are caught by the registry itself, which applies the
    -- battery cadence to late arrivals while eco is active.
    bs.evaluate(true)
end

return M
