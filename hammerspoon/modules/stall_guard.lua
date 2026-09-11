-- =====================================================================
-- MODULE: STALL GUARD — a beach ball no longer costs you the keyboard
-- =====================================================================
-- 6.208.0, LL: "if a beachball appears, can hammerspoon pause itself,
-- warn me to quit it or reload itself so I don't have to kill it to get
-- control of my Mac's keyboard back."
--
-- THE HONEST ANSWER FIRST: it cannot pause ITSELF. A beach ball is the
-- main thread stuck — the one thread that draws every window, runs
-- every timer, reads every key — and code that would notice the stall
-- runs on that same thread, so it is stuck too. Everything this config
-- already does about hangs (the 8 s ⇪ watchdog, the tap re-enabler, the
-- lag probe) runs on a timer and is therefore silent for exactly as long
-- as the hang lasts. That is why 6.160.0 took the Mac for four hours
-- and 6.196.0 died with nothing in the Console: nothing INSIDE could
-- speak.
--
-- So the watcher is OUTSIDE. Two halves:
--
--   1. THE PULSE. Every `sg.beatSecs` (2) seconds a held timer writes
--      the epoch second to ~/.hammerspoon/.stall-guard/heartbeat. It is
--      written from the main thread ON PURPOSE — that is the whole
--      point. When the main thread stalls, the beat stops. (A tiny local
--      file, never OneDrive: a placeholder read on the boot path is the
--      6.152.x stall class and would make the guard cause what it
--      watches for.)
--
--   2. THE GUARD. warm() starts tools/hs-stall-guard.sh as its own
--      process — plain /bin/sh, `nohup … &`, run as LL from LL's own
--      folder. No sudo, no launchd, no LaunchAgent, nothing the work
--      Mac's IT policy can refuse (§6.44.12). It sleeps `checkSecs`
--      (5), reads the beat, and after TWO readings in a row older than
--      `stallSecs` (20) — with Hammerspoon actually running — it logs
--      the fact, kills the process (-9 is the only thing that frees a
--      hung main thread), lifts the ⇪ remap a hard kill leaves behind
--      (init.lua's own "manual escape hatch" line), and opens
--      Hammerspoon again. The script's header lists what stops it lying:
--      sleep, a clean quit, a newer guard, a relaunch limit, and "not
--      running" never reading as "stalled".
--
-- THE WARNING LL ASKED FOR is the next boot: warm() reads the guard's
-- log and every relaunch it has not announced before is said in three
-- places — an alert, a notification, and the Console with the stall's
-- length and the time — and filed with _G.notices. Once, remembered in
-- hs.settings, so the same stall is not reported every reload after.
-- A "gave up" line (three relaunches in ten minutes: a config that
-- stalls AT BOOT must not be bounced forever) is announced the same
-- way, with the fix — hold ⇧ while it launches, or reload after
-- editing — named.
--
-- IT DEGRADES: a folder it cannot create, a beat it cannot write, a
-- script that is not installed, an hs.task the Mac will not start — each
-- is a named state on _G.stallGuardReport() and the rest of the config
-- never notices. `settings = { stall_guard = { on = false } }` turns it
-- off; the beat stops and no guard is started.
--
-- 🔑 A CLEAN QUIT WRITES A MARKER (6.208.0). This module wraps
-- hs.shutdownCallback: on a quit or a reload it stops the beat and
-- writes .stall-guard/quit, which the guard reads on its next loop and
-- exits on. Without that, a reload's few seconds of silence would look
-- like a stall to the guard that outlived the old instance. The NEW
-- boot's guard removes the marker as it starts.
--
-- Console: _G.stallGuardReport() · _G.stallGuard (the state)

local M = {
    name    = "Stall Guard",
    order   = 13.85,
    family  = "auto",
    summary = "A second process watches Hammerspoon's pulse and relaunches it when the main thread hangs",
    cheatsheet = {
        title = "🧊 STALL GUARD (a beach ball no longer costs you the keyboard)",
        entries = {
            { "automatic", "Hammerspoon writes a heartbeat every 2 s; a separate /bin/sh process reads it" },
            { "relaunch",  "Two readings 20 s stale, in a row, while it is running → kill -9, lift the ⇪ remap, open it again" },
            { "warns",     "The next boot announces the relaunch: an alert, a notification, the Console, _G.notices" },
            { "never",     "on a sleeping Mac (a clock gap is skipped) · after a clean quit · more than 3× in 10 min" },
            { "console",   "_G.stallGuardReport() — beat, guard, log, every relaunch ever" },
            { "off",       "settings = { stall_guard = { on = false } } — no beat, no guard" },
        },
    },
}

function M.setup(core)
    core = core or {}
    local function say(m)  if _G.diag then pcall(_G.diag.say,  "stall", m) end end
    local function warn(m) if _G.diag then pcall(_G.diag.warn, "stall", m) end end
    local function record(what, why)
        if _G.notices and _G.notices.record then
            pcall(_G.notices.record, "runtime", "stall_guard", what .. (why and (" — " .. why) or ""))
        end
    end

    local configDir = (hs and hs.configdir) or core.configDir
    local sg = {
        on            = true,
        stallSecs     = 20,     -- a beat this old is one stale reading
        checkSecs     = 5,      -- the guard's loop
        beatSecs      = 2,      -- the pulse
        maxRelaunches = 3,      -- per ten minutes, then the guard gives up
        dir           = configDir and (configDir .. "/.stall-guard") or nil,
        script        = configDir and (configDir .. "/tools/hs-stall-guard.sh") or nil,
        settingsKey   = "stallGuard.seenEpoch",
        logTail       = 8192,   -- bytes of the log read at boot, never the whole file
        beats         = 0,
        beatFails     = 0,
        lastBeat      = nil,    -- epoch of the last successful write
        lastBeatWhy   = nil,
        state         = "not yet warmed",
        spawned       = false,
        spawnWhy      = nil,
        spawnAt       = nil,
        announced     = {},     -- lines said this boot, for the report
        announceWhy   = nil,
        quitWritten   = false,
    }
    M.config = sg
    _G.stallGuard = sg

    -- ---- the folder --------------------------------------------------------
    function sg.ensureDir()
        if not sg.dir then return false, "no config folder known" end
        local ok, attrs = pcall(function() return hs.fs and hs.fs.attributes and hs.fs.attributes(sg.dir) end)
        if ok and type(attrs) == "table" and attrs.mode == "directory" then return true end
        if ok and type(attrs) == "table" then return false, sg.dir .. " exists and is not a folder" end
        local mk = pcall(function() if hs.fs and hs.fs.mkdir then hs.fs.mkdir(sg.dir) end end)
        local f = io.open(sg.dir .. "/.probe", "w")
        if not f then return false, "cannot create " .. sg.dir .. (mk and "" or " (hs.fs.mkdir threw)") end
        f:close()
        os.remove(sg.dir .. "/.probe")
        return true
    end

    -- ---- the pulse ---------------------------------------------------------
    function sg.beat()
        if not sg.on or not sg.dir then return false, "off" end
        local f = io.open(sg.dir .. "/heartbeat", "w")
        if not f then
            sg.beatFails = sg.beatFails + 1
            sg.lastBeatWhy = "cannot write " .. sg.dir .. "/heartbeat"
            return false, sg.lastBeatWhy
        end
        local okW = f:write(tostring(os.time()))
        f:close()
        if not okW then
            sg.beatFails = sg.beatFails + 1
            sg.lastBeatWhy = "write refused"
            return false, sg.lastBeatWhy
        end
        sg.beats = sg.beats + 1
        sg.lastBeat = os.time()
        return true
    end

    function sg.startBeat()
        if sg.beatTimer then return true end
        local okDir, whyDir = sg.ensureDir()
        if not okDir then return false, whyDir end
        sg.beat()
        local ok, t = pcall(function()
            return hs.timer.doEvery(sg.beatSecs, function() pcall(sg.beat) end)
        end)
        if not ok or not t then return false, "no timer (" .. tostring(t) .. ")" end
        sg.beatTimer = t              -- HELD: an unreferenced timer is collected and the pulse dies
        _G.stallGuardBeat = t
        return true
    end

    function sg.stopBeat()
        if sg.beatTimer then pcall(function() sg.beatTimer:stop() end) end
        sg.beatTimer = nil
        _G.stallGuardBeat = nil
    end

    -- The first beat lands in setup, before the guard can exist: a guard
    -- left over from a hard relaunch is still reading, and a boot that
    -- took its time to warm must not read as a second stall.
    local okBeat, whyBeat = sg.startBeat()
    if not okBeat then sg.state = "degraded — " .. tostring(whyBeat) end

    -- ---- the clean-quit marker --------------------------------------------
    function sg.writeQuit()
        if not sg.dir then return false, "no folder" end
        local f = io.open(sg.dir .. "/quit", "w")
        if not f then return false, "cannot write " .. sg.dir .. "/quit" end
        f:write(tostring(os.time()))
        f:close()
        sg.quitWritten = true
        return true
    end

    function _G.stallGuardQuit()
        sg.stopBeat()
        local ok, why = sg.writeQuit()
        if not ok then warn("quit marker not written — " .. tostring(why)) end
        return ok, why
    end

    -- init.lua sets hs.shutdownCallback before any module loads (the ⇪
    -- remap's own cleanup); wrap it rather than replace it, so that
    -- cleanup still runs and this marker is written beside it.
    do
        local prev = hs and hs.shutdownCallback
        pcall(function()
            hs.shutdownCallback = function()
                if type(prev) == "function" then pcall(prev) end
                pcall(_G.stallGuardQuit)
            end
        end)
        sg.wrappedShutdown = type(prev) == "function"
    end

    -- ---- the log ------------------------------------------------------------
    -- PURE: the guard's lines are "<epoch> <date> <time> <event…>".
    function sg.parseLog(text)
        local rows = {}
        for line in tostring(text or ""):gmatch("[^\n]+") do
            local epoch, when, rest = line:match("^(%d+) (%S+ %S+) (.*)$")
            if epoch then
                local event = rest:match("^(%a[%a ]-):") or rest:match("^(%a+)") or "?"
                rows[#rows + 1] = { epoch = tonumber(epoch), when = when, event = event, text = rest }
            end
        end
        return rows
    end

    -- PURE: what the boot must say — relaunches and give-ups newer than
    -- the last one announced.
    function sg.newEvents(rows, seenEpoch)
        local out = {}
        for _, r in ipairs(rows or {}) do
            if (r.event == "relaunched" or r.event == "gave up")
               and r.epoch > (tonumber(seenEpoch) or 0) then
                out[#out + 1] = r
            end
        end
        return out
    end

    function sg.readLog()
        if not sg.dir then return nil, "no folder" end
        local f = io.open(sg.dir .. "/stall-guard.log", "r")
        if not f then return "", nil end
        local size = f:seek("end") or 0
        if size > sg.logTail then f:seek("set", size - sg.logTail) else f:seek("set", 0) end
        local text = f:read("a") or ""
        f:close()
        if size > sg.logTail then text = text:gsub("^[^\n]*\n", "", 1) end   -- drop the cut line
        return text
    end

    function sg.seen()
        local v
        local ok = pcall(function() v = hs.settings.get(sg.settingsKey) end)
        if not ok then return 0, "hs.settings unavailable — every boot will announce again" end
        return tonumber(v) or 0
    end

    function sg.markSeen(epoch)
        local ok = pcall(function() hs.settings.set(sg.settingsKey, epoch) end)
        return ok
    end

    function sg.wording(r)
        if r.event == "gave up" then
            return "🧊 Stall guard GAVE UP at " .. r.when .. " — " .. r.text
                .. ". If Hammerspoon stalls at boot, hold ⇧ while it launches, fix the config, then reload."
        end
        local secs = r.text:match("stalled (%d+)s") or "?"
        return "🧊 Hammerspoon HUNG for " .. secs .. " s at " .. r.when
            .. " and was relaunched by the stall guard (" .. r.text .. ")"
    end

    function sg.announce()
        local text, why = sg.readLog()
        if not text then sg.announceWhy = why; return 0 end
        local seen, seenWhy = sg.seen()
        sg.announceWhy = seenWhy
        local rows = sg.newEvents(sg.parseLog(text), seen)
        local top = seen
        local L = {}
        for _, r in ipairs(rows) do
            local line = sg.wording(r)
            L[#L + 1] = line
            sg.announced[#sg.announced + 1] = line
            record(r.event, r.text)
            if r.epoch > top then top = r.epoch end
        end
        if #L > 0 then
            print(table.concat(L, "\n") .. "\n   _G.stallGuardReport() has the whole log.")
            pcall(function() hs.alert.show(L[#L], 8) end)
            pcall(function()
                hs.notify.new({ title = "Hammerspoon was relaunched", informativeText = L[#L],
                                withdrawAfter = 0, hasActionButton = false }):send()
            end)
            if top > seen then sg.markSeen(top) end
        end
        return #L
    end

    -- ---- the guard ---------------------------------------------------------
    function sg.spawn()
        if not sg.on then return false, "off" end
        if not sg.dir or not sg.script then return false, "no config folder known" end
        local f = io.open(sg.script, "r")
        if not f then return false, "script not installed at " .. sg.script end
        f:close()
        local okDir, whyDir = sg.ensureDir()
        if not okDir then return false, whyDir end
        local ok, t = pcall(function()
            return hs.task.new("/bin/sh", function() end, {
                "-c", 'nohup /bin/sh "$1" "$2" "$3" "$4" "$5" >/dev/null 2>&1 &',
                "stall-guard", sg.script, sg.dir,
                tostring(sg.stallSecs), tostring(sg.checkSecs), tostring(sg.maxRelaunches),
            })
        end)
        if not ok or not t then return false, "hs.task refused (" .. tostring(t) .. ")" end
        local started = pcall(function() t:start() end)
        if not started then return false, "hs.task would not start" end
        sg.spawnTask = t              -- HELD until the wrapper exits (it does at once)
        sg.spawned = true
        sg.spawnAt = os.time()
        return true
    end

    -- ---- the report ---------------------------------------------------------
    local function hms(epoch) return epoch and os.date("%H:%M:%S", epoch) or "never" end

    function _G.stallGuardReport()
        local L = {}
        L[#L + 1] = "🧊 STALL GUARD " .. tostring(_G.configVersion or "") .. " — " .. sg.state
        if sg.on then
            local b = string.format("every %d s → %s/heartbeat · %d written · last %s",
                                    sg.beatSecs, tostring(sg.dir), sg.beats, hms(sg.lastBeat))
            if sg.beatFails > 0 then
                b = b .. string.format(" · ⚠️ %d failed — %s", sg.beatFails, tostring(sg.lastBeatWhy))
            end
            L[#L + 1] = "   beat   : " .. b
        else
            L[#L + 1] = "   beat   : off — settings = { stall_guard = { on = false } }"
        end
        if sg.spawned then
            local pid
            if sg.dir then
                local f = io.open(sg.dir .. "/guard.pid", "r")
                if f then pid = (f:read("l") or ""):match("%d+"); f:close() end
            end
            L[#L + 1] = string.format("   guard  : started %s from %s%s", hms(sg.spawnAt),
                                      tostring(sg.script), pid and (" · guard.pid says " .. pid) or " · no guard.pid yet")
        else
            L[#L + 1] = "   guard  : not running — " .. tostring(sg.spawnWhy or sg.state)
        end
        L[#L + 1] = string.format("   rule   : relaunch after 2 readings in a row ≥ %d s stale, checked every %d s, "
                                  .. "at most %d× in 10 min · a clock gap is skipped · a clean quit ends it",
                                  sg.stallSecs, sg.checkSecs, sg.maxRelaunches)
        L[#L + 1] = "   quit   : " .. (sg.wrappedShutdown and "hs.shutdownCallback wrapped — a reload writes the marker"
                                       or "⚠️ no hs.shutdownCallback was set before this module — the marker is written by _G.stallGuardQuit() only")
        local text, why = sg.readLog()
        if not text then
            L[#L + 1] = "   log    : cannot read — " .. tostring(why)
        elseif text == "" then
            L[#L + 1] = "   log    : no log yet — the guard has not written a line"
        else
            local rows = sg.parseLog(text)
            local re = {}
            for _, r in ipairs(rows) do
                if r.event == "relaunched" or r.event == "gave up" then re[#re + 1] = r end
            end
            L[#L + 1] = string.format("   log    : %d line(s) read · last: %s %s", #rows,
                                      rows[#rows] and rows[#rows].when or "?", rows[#rows] and rows[#rows].text or "")
            if #re == 0 then
                L[#L + 1] = "   stalls : none — the guard has never had to relaunch Hammerspoon"
            else
                L[#L + 1] = string.format("   stalls : %d relaunch/give-up line(s) in the log read", #re)
                for i = math.max(1, #re - 5), #re do
                    L[#L + 1] = "     ↳ " .. re[i].when .. " " .. re[i].text
                end
            end
        end
        if #sg.announced > 0 then
            L[#L + 1] = string.format("   said   : %d announced this boot", #sg.announced)
        end
        if sg.announceWhy then L[#L + 1] = "   ⚠️ " .. sg.announceWhy end
        print(table.concat(L, "\n"))
        return sg
    end

    say("ready — beat " .. (okBeat and "started" or ("NOT started: " .. tostring(whyBeat))))
end

function M.warm(core)
    local sg = M.config
    if not sg then return end
    if not sg.on then
        sg.stopBeat()
        sg.state = "off — settings = { stall_guard = { on = false } }"
        return
    end
    if not sg.beatTimer then
        local ok, why = sg.startBeat()
        if not ok then
            sg.state = "degraded — " .. tostring(why)
            sg.spawnWhy = "no beat, so no guard (" .. tostring(why) .. ")"
            return
        end
    end
    pcall(sg.announce)
    local ok, why = sg.spawn()
    if ok then
        sg.state = "watching"
    else
        sg.spawnWhy = why
        sg.state = "degraded — guard not started: " .. tostring(why)
        print("🧊 stall guard: the beat is written but the guard could not be started — " .. tostring(why))
    end
end

return M
