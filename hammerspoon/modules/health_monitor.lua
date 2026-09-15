-- =====================================================================
-- MODULE: HEALTH MONITOR — tells you when a tool QUIETLY stops working
-- =====================================================================
-- The boot report says what LOADED. The capability report says what this
-- Mac CAN do. Neither notices the thing that actually goes wrong: a
-- module that loaded fine, reports no error, and silently stopped doing
-- its job three days ago. Command History still bound to its key, still
-- listed as loaded, no longer writing a single line to its file.
--
-- You only find that out by opening the Console, and you do not have the
-- Console open. So this watches the OUTPUT of every tool that is
-- supposed to produce some, and puts a notification on screen when one
-- goes quiet.
--
-- ---------------------------------------------------------------------
-- WHY IT WATCHES FILES AND NOT CODE
-- ---------------------------------------------------------------------
-- Every data-producing module writes to a file. If that file stops
-- changing, the module stopped working — whatever the reason, including
-- reasons nobody thought to catch. That means:
--
--   · NOT ONE LINE of any existing module changes. Nineteen modules,
--     zero regression risk, which is the whole reason this shape was
--     chosen over adding a heartbeat call to each one.
--   · It catches HALF-broken, not just dead. A module whose watcher
--     silently detached still loads, still binds, still reports healthy
--     — and stops writing. That is invisible to every other check here.
--   · It is honest about what it cannot see. A tool with no output file
--     cannot be watched this way, and is listed as such rather than
--     quietly assumed fine.
--
-- ---------------------------------------------------------------------
-- 🚨 THE REAL DESIGN PROBLEM: FALSE ALARMS
-- ---------------------------------------------------------------------
-- A monitor that cries wolf gets ignored, and an ignored monitor is
-- worse than no monitor — it converts a real alert into noise you have
-- trained yourself to dismiss. Four defences, and every one of them
-- exists because of a specific way this would otherwise lie to you:
--
--   1. AWAKE TIME, NOT WALL CLOCK. Shut the lid on Friday, open it
--      Monday, and every file on this Mac is "three days stale" while
--      nothing whatsoever is wrong. The check timer only ticks while the
--      Mac is awake, so COUNTING TICKS IS COUNTING AWAKE TIME. Staleness
--      is measured in ticks. Sleep is invisible to it, for free.
--   2. ACTIVE HOURS. Command History going quiet at 3 a.m. is not a
--      fault, it is a person asleep. Each check names the window in
--      which it is expected to produce anything.
--   3. ONCE PER DAY, PER CHECK. Not once per fifteen minutes.
--   4. A BOOT GRACE PERIOD. Modules warm on a timer after boot; a check
--      that fired immediately would alert every single reload.
--
-- ---------------------------------------------------------------------
-- ⚠️ WHAT IS DELIBERATELY NOT WATCHED, and this matters more than what is
-- ---------------------------------------------------------------------
-- Only tools that write ON THEIR OWN are monitored. Image OCR, the
-- diagnostic dump, Quick Append and the Capture Pad write only when YOU
-- act — so "no output for six hours" is the normal state of a Tuesday,
-- and monitoring them would generate exactly the noise defence 3 exists
-- to prevent. They are listed in the report as "on demand" so it is
-- clear they were considered and excluded, not forgotten.

local M = {
    name  = "Health Monitor",
    order = 13.8,
    family = "config",
    cheatsheet = {
        title = "🩺 HEALTH MONITOR (watches the other tools, tells you when one dies)",
        entries = {
            { "automatic", "Checks every 15 min that each tool is still WRITING" },
            { "notifies",  "A persistent macOS notification when one goes quiet" },
            { "⇪⇧H",      "Health report right now — every tool, state and why" },
            { "console",   "_G.healthReport() · _G.healthCheckNow() to force one" },
            { "no alarms", "Sleep does not count · quiet hours do not count ·" },
            { "",          "one notice per tool per day · grace period after boot" },
            { "why",       "Boot report = what LOADED. This = what still WORKS." },
            -- 📧 6.117.0 removed the Outlook probe's row from here. The probe
            -- was deleted, and a cheat sheet line for a file that no longer
            -- exists is worse than no line at all.
        },
    },
}

function M.setup(core)
    local health = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    health.enabled      = true
    health.intervalMins = 15      -- how often to look. Also the tick size.
    health.bootGraceMins = 20     -- modules warm on a timer; don't judge early
    health.notify       = true    -- false = report only, never a notification
    -- A small always-visible dot in the menu bar. OFF by default because it
    -- is a permanent change to YOUR menu bar that you did not ask for; turn
    -- it on if you would rather see health at a glance than wait for a
    -- notification.
    health.menubar      = false
    health.key          = "h"     -- ⇪⇧H (⇪H is Command History)
    -- ----------------------------------------------------------------------

    local logs = core.logsDir
    local host = core.hostTag

    -- ---- WHAT IS WATCHED -------------------------------------------------
    -- `hours` is AWAKE hours of silence before this counts as a fault, and
    -- each one is a judgement about that tool's natural cadence. Set one
    -- too low and you get noise; too high and you find out late. The `why`
    -- is the reasoning, kept next to the number so it can be argued with.
    health.checks = {
        {
            key = "activity", label = "Activity Tracker",
            file = logs .. "/activity_history-" .. host .. ".csv",
            hours = 4, active = { 8, 19 },
            why = "writes on every app switch — 4 waking hours with none "
               .. "means it stopped watching, not that you stopped working",
        },
        {
            key = "files", label = "File Tracker",
            file = logs .. "/file_changes-" .. host .. ".csv",
            hours = 10, active = { 8, 19 },
            why = "a whole working day touching no watched file is possible "
               .. "but unusual; 10 hours is deliberately forgiving",
        },
        {
            key = "commands", label = "Command History",
            file = logs .. "/Terminal+Ghostty/command_history.log",
            hours = 12, active = { 8, 19 }, optional = true,
            why = "you may genuinely not open a terminal all day, so this "
               .. "is the loosest of the automatic checks",
        },
        {
            key = "backup", label = "Daily Backup",
            file = core.backupDir, hours = 30, active = { 0, 24 },
            why = "runs at 5 PM daily; 30 awake hours covers a missed run "
               .. "plus a normal overnight without crying wolf",
            needsCloud = true,
        },
        {
            key = "updates", label = "App Update Tracker",
            file = logs .. "/app_updates-" .. host .. ".csv",
            hours = 60, active = { 0, 24 }, optional = true,
            why = "checks daily and only writes when something CHANGED, so "
               .. "silence here is weak evidence — hence the long window",
        },
    }

    -- Named so the report can say "considered and excluded" rather than
    -- leaving you to wonder whether they were forgotten.
    health.onDemand = {
        "Image OCR", "Diagnostics (⇪⇧D)", "Capture Pad", "Quick Append",
        "Mouse Grid", "URL Cleaner", "Cheat Sheet", "Window Switcher",
    }

    -- ---- state -----------------------------------------------------------
    health.tick        = 0        -- one per interval, ONLY while awake
    health.lastFresh   = {}       -- check key -> tick when its file last moved
    health.lastMtime   = {}       -- check key -> mtime we last saw
    health.notifiedOn  = {}       -- check key -> "YYYY-MM-DD" of last notice
    health.state       = {}       -- check key -> "OK"|"STALE"|"MISSING"|"WAIT"|"OFF"
    health.timer       = nil      -- HELD: an unreferenced hs.timer is collected
                                  -- and silently never fires — which would make
                                  -- this module fail in exactly the way it
                                  -- exists to detect.
    health.menu        = nil      -- HELD for the same reason
    health.lastRun     = nil

    local function say(m)  if _G.diag then _G.diag.say("health", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("health", m) end end

    local function mtimeOf(path)
        if not path then return nil end
        local ok, t = pcall(hs.fs.attributes, path, "modification")
        if ok and type(t) == "number" then return t end
        return nil
    end

    local function today() return os.date("%Y-%m-%d") end
    local function hourNow() return tonumber(os.date("%H")) or 12 end

    local function inActiveHours(c)
        local a = c.active or { 0, 24 }
        local h = hourNow()
        if a[1] <= a[2] then return h >= a[1] and h < a[2] end
        return h >= a[1] or h < a[2]        -- a window that wraps midnight
    end

    -- ---- the notification ------------------------------------------------
    -- ⚠️ hs.notify.show() IS THE WRONG CALL HERE, and it looks like the right
    -- one. Its notifications inherit withdrawAfter = 5 seconds, so they
    -- vanish while you are looking somewhere else — which is the entire
    -- situation this module was built for. withdrawAfter = 0 makes the
    -- notice PERSIST in Notification Center until you deal with it.
    local function notifyUser(title, text)
        if not health.notify then return false end
        local ok = pcall(function()
            hs.notify.new({
                title            = title,
                informativeText  = text,
                withdrawAfter    = 0,
                hasActionButton  = false,
                autoWithdraw     = false,
            }):send()
        end)
        if not ok then
            -- Notifications can be refused (Do Not Disturb, a managed
            -- profile, Focus). Losing the alert entirely would be the worst
            -- outcome for THIS module, so fall back to an on-screen alert.
            pcall(function()
                hs.alert.show("🩺 " .. title .. "\n" .. text, 6)
            end)
            warn("hs.notify refused; fell back to hs.alert")
            return false
        end
        return true
    end

    -- ---- one pass --------------------------------------------------------
    function health.check(force)
        health.tick    = health.tick + 1
        health.lastRun = os.date("%Y-%m-%d %H:%M")
        local graceTicks = math.ceil(health.bootGraceMins / health.intervalMins)
        local problems = {}

        -- A module that did not LOAD is an unambiguous fault, needs no
        -- staleness reasoning, and is worth saying immediately.
        for _, st in ipairs(_G.moduleStatus or {}) do
            if st.ok == false then
                health.state["mod:" .. st.name] = "FAILED"
                if force or health.notifiedOn["mod:" .. st.name] ~= today() then
                    health.notifiedOn["mod:" .. st.name] = today()
                    problems[#problems + 1] = st.name .. " failed to load"
                end
            end
        end

        for _, c in ipairs(health.checks) do
            local disabled = (c.needsCloud and not core.cloudDir)
            if disabled then
                health.state[c.key] = "OFF"
            else
                local m = mtimeOf(c.file)
                if m == nil then
                    -- Never written vs stopped writing are different
                    -- problems with different fixes, so they are different
                    -- states and different messages.
                    health.state[c.key] = "MISSING"
                    if health.tick > graceTicks and inActiveHours(c) and not c.optional then
                        if force or health.notifiedOn[c.key] ~= today() then
                            health.notifiedOn[c.key] = today()
                            problems[#problems + 1] = c.label ..
                                " has never written its file"
                        end
                    end
                else
                    if health.lastMtime[c.key] ~= m then
                        health.lastMtime[c.key] = m
                        health.lastFresh[c.key] = health.tick
                    end
                    local firstSeen = health.lastFresh[c.key] or health.tick
                    local quietTicks = health.tick - firstSeen
                    local quietHours = quietTicks * health.intervalMins / 60
                    if quietHours >= c.hours then
                        health.state[c.key] = "STALE"
                        if health.tick > graceTicks and inActiveHours(c) then
                            if force or health.notifiedOn[c.key] ~= today() then
                                health.notifiedOn[c.key] = today()
                                problems[#problems + 1] = string.format(
                                    "%s: nothing written in %.0f waking hours",
                                    c.label, quietHours)
                            end
                        end
                    elseif health.tick <= graceTicks then
                        health.state[c.key] = "WAIT"
                    else
                        health.state[c.key] = "OK"
                    end
                end
            end
        end

        if #problems > 0 then
            notifyUser("Hammerspoon: a tool stopped working",
                       table.concat(problems, "\n") .. "\n⇪⇧H for the full report")
            say("ALERT — " .. table.concat(problems, "; "))
        end
        health.updateMenu()
        return problems
    end

    function health.updateMenu()
        if not health.menu then return end
        local bad = 0
        for _, s in pairs(health.state) do
            if s == "STALE" or s == "FAILED" or s == "MISSING" then bad = bad + 1 end
        end
        pcall(function()
            health.menu:setTitle(bad == 0 and "🩺" or ("🩺" .. bad))
        end)
    end

    -- ---- the report ------------------------------------------------------
    function _G.healthReport()
        local L = { "🩺 TOOL HEALTH on " .. tostring(host),
                    "   last checked " .. tostring(health.lastRun or "not yet")
                    .. "  ·  " .. string.format("%.1f", health.tick * health.intervalMins / 60)
                    .. " waking hours observed" }
        local mark = { OK = "✅", STALE = "🔴", MISSING = "⚠️", WAIT = "⏳",
                       OFF = "⚪️", FAILED = "❌" }
        for _, c in ipairs(health.checks) do
            local st = health.state[c.key] or "WAIT"
            local age = "—"
            local m = mtimeOf(c.file)
            if m then age = string.format("%.1fh ago", (os.time() - m) / 3600) end
            L[#L + 1] = string.format("   %s %-22s %-8s last write %s",
                mark[st] or "?", c.label, st, age)
            if st == "STALE" or st == "MISSING" then
                L[#L + 1] = "        ↳ " .. c.why
                L[#L + 1] = "        ↳ " .. tostring(c.file)
            end
        end
        local failed = {}
        for k, v in pairs(health.state) do
            if v == "FAILED" then failed[#failed + 1] = k:gsub("^mod:", "") end
        end
        if #failed > 0 then
            L[#L + 1] = "   ❌ modules that failed to LOAD: " .. table.concat(failed, ", ")
        end
        L[#L + 1] = "   not watched (these only write when you act, so silence "
                 .. "means nothing):"
        L[#L + 1] = "        " .. table.concat(health.onDemand, " · ")
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    function _G.healthCheckNow()
        local p = health.check(true)
        if #p == 0 then hs.alert.show("🩺 All tools are writing normally") end
        return p
    end

    -- ---- wiring ----------------------------------------------------------
    if health.enabled then
        core.hyperAddShortcut({ "shift" }, health.key, function()
            health.check(false)
            local r = _G.healthReport()
            pcall(function() hs.pasteboard.setContents(r) end)
            hs.alert.show("🩺 Health report printed and copied", 2)
        end, "health report")
    end

    if health.menubar then
        local ok, mb = pcall(hs.menubar.new)
        if ok and mb then
            health.menu = mb
            pcall(function()
                mb:setTitle("🩺")
                mb:setClickCallback(function() _G.healthReport() end)
            end)
        end
    end

    core.provide("health.check",  function() return health.check(true) end)
    core.provide("health.report", function() return _G.healthReport() end)

    _G.health = health
    M.health  = health
    M.config  = health
end

-- The periodic check starts in warm(), not setup(). setup() runs during
-- boot while eighteen other modules are still loading, and the first
-- thing this would do is stat five files on a possibly-cloud-backed
-- folder. That belongs after the boot path, not in it.
function M.warm(core)
    local health = _G.health
    if not (health and health.enabled) then return end
    health.timer = hs.timer.doEvery(health.intervalMins * 60, function()
        local ok, err = pcall(health.check, false)
        if not ok and _G.diag then
            _G.diag.warn("health", "check threw: " .. tostring(err))
        end
    end)
    pcall(health.check, false)     -- one immediate pass to seed the baseline
    if _G.diag then
        _G.diag.say("health", "watching " .. #health.checks
                    .. " tools every " .. health.intervalMins .. " min")
    end
end

return M
