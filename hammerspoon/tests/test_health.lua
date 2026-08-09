-- =====================================================================
-- test_health.lua — the monitor that must not cry wolf
-- =====================================================================
--     lua5.4 test_health.lua [/path/to/hammerspoon]
--
-- Executes modules/health_monitor.lua with a controllable clock and a
-- controllable filesystem, so staleness can be driven directly instead
-- of waited for.
--
-- MOST OF THIS FILE IS ABOUT NOT ALERTING. A monitor that fires wrongly
-- gets ignored, and an ignored monitor is worse than none — it trains
-- you to dismiss the one notice that mattered. So the cases that must
-- stay SILENT (asleep, out of hours, freshly booted, already told you
-- today) get more attention here than the cases that must fire.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end
local function out(s) io.write(s) end

-- ---- controllable world ---------------------------------------------
local MTIMES, NOTIFIES, ALERTS, TIMERS, printed = {}, {}, {}, {}, {}
local HOUR, TODAY = 10, "2026-08-09"      -- 10 a.m., inside every active window
local NOWSEC = 1770000000
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local HYPER, PROVIDED = {}, {}

hs = {
    fs = { attributes = function(path, what)
        if what == "modification" then return MTIMES[path] end
        return MTIMES[path] and { mode = "file" } or nil end },
    notify = { new = function(t)
        return { send = function() NOTIFIES[#NOTIFIES + 1] = t end } end,
        show = function() error("hs.notify.show auto-withdraws after 5s") end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    timer = { doEvery = function(secs, fn)
        local t = { secs = secs, fn = fn, stopped = false }
        function t:stop() self.stopped = true end
        TIMERS[#TIMERS + 1] = t ; return t end,
        secondsSinceEpoch = function() return NOWSEC end },
    pasteboard = { setContents = function() return true end },
    menubar = { new = function()
        local m = {}
        function m:setTitle(t) self.title = t ; return m end
        function m:setClickCallback() return m end
        return m end },
}
os.date = (function(orig) return function(fmt, t)
    if fmt == "%Y-%m-%d" then return TODAY end
    if fmt == "%H" then return string.format("%02d", HOUR) end
    return orig(fmt, t) end end)(os.date)
os.time = function() return NOWSEC end

_G.diag = { said = {},
    say  = function(_, m) _G.diag.said[#_G.diag.said + 1] = "say " .. m end,
    warn = function(_, m) _G.diag.said[#_G.diag.said + 1] = "warn " .. m end,
    err = function() end, mark = function() end }
_G.moduleStatus = {}

local CORE = {
    logsDir = "/L", backupDir = "/B", cloudDir = "/C", hostTag = "Test-Mac",
    hyperAddShortcut = function(mods, key, fn)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms) ; HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local M, H
local function boot(coreOverrides, clearKeys)
    MTIMES, NOTIFIES, ALERTS, TIMERS, printed = {}, {}, {}, {}, {}
    _G.diag.said = {} ; _G.moduleStatus = {}
    local c = {}
    for k, v in pairs(CORE) do c[k] = v end
    for k, v in pairs(coreOverrides or {}) do c[k] = v end
    -- ⚠️ `{ cloudDir = nil }` stores NOTHING: pairs() never yields a nil
    -- value, so an override table cannot clear a key. Names to remove have
    -- to be passed as a LIST and assigned nil explicitly. This codebase has
    -- been bitten by this exact trap before.
    for _, k in ipairs(clearKeys or {}) do c[k] = nil end
    M = dofile(HS .. "/modules/health_monitor.lua")
    M.setup(c)
    H = _G.health
    return H
end
-- Every watched file present and just written.
local function allFresh()
    -- A check whose file comes from a core path that is absent on this Mac
    -- (no OneDrive -> no backupDir) has file == nil, and MTIMES[nil] throws.
    for _, c in ipairs(H.checks) do
        if c.file then MTIMES[c.file] = NOWSEC end
    end
end
-- Advance N awake hours WITHOUT touching any file.
local function quietHours(n)
    for _ = 1, math.floor(n * 60 / H.intervalMins) do H.check(false) end
end

-- =====================================================================
out("\n=== 1. Contract ===\n")
-- =====================================================================
boot()
check("loads and sets up", M ~= nil and H ~= nil)
check("declares a name/order/cheatsheet", M.name == "Health Monitor"
      and type(M.order) == "number" and M.cheatsheet ~= nil)
check("⇪⇧H is claimed", HYPER["shift|h"] ~= nil)
check("services published", PROVIDED["health.check"] ~= nil
      and PROVIDED["health.report"] ~= nil)
check("it has a warm() — the periodic check must NOT run during boot, "
      .. "where it would stat cloud-backed files in the boot path",
      type(M.warm) == "function")
check("setup() starts NO timer", #TIMERS == 0, #TIMERS)
M.warm(CORE)
check("warm() starts exactly one timer", #TIMERS == 1)
check("...and it is HELD, or it would be collected and never fire — this "
      .. "module failing the way it exists to detect", H.timer ~= nil)
check("the timer interval matches the setting",
      TIMERS[1].secs == H.intervalMins * 60)

-- =====================================================================
out("\n=== 2. 🚨 IT MUST NOT CRY WOLF ===\n")
-- =====================================================================
out("   -- freshly booted --\n")
boot() ; allFresh() ; H.check(false)
check("a fresh boot with everything writing alerts nothing", #NOTIFIES == 0)
boot()          -- nothing has ever written; still inside the grace period
H.check(false)
check("during the boot grace period NOTHING alerts, even with no files at "
      .. "all — modules warm on a timer and would trip every reload",
      #NOTIFIES == 0, #NOTIFIES)

out("   -- the lid was shut for three days --\n")
boot() ; allFresh() ; H.check(false)
NOWSEC = NOWSEC + 3 * 24 * 3600        -- three days of WALL CLOCK pass
H.check(false)                          -- ...but only one more awake tick
check("🚨 three days asleep alerts NOTHING. Staleness is counted in ticks, "
      .. "and ticks only happen while the Mac is awake, so sleep is "
      .. "invisible for free", #NOTIFIES == 0, #NOTIFIES)
NOWSEC = 1770000000

out("   -- the middle of the night --\n")
boot() ; allFresh()
quietHours(1)                           -- past the grace period
HOUR = 3
quietHours(20)                          -- long past every threshold
check("nothing alerts outside a check's active hours — a quiet terminal at "
      .. "3 a.m. is a person asleep, not a fault", #NOTIFIES == 0, #NOTIFIES)
HOUR = 10

out("   -- it already told you today --\n")
boot() ; allFresh() ; quietHours(1)
local function noticesAbout(tool)
    local n = 0
    for _, x in ipairs(NOTIFIES) do
        if tostring(x.informativeText):find(tool, 1, true) then n = n + 1 end
    end
    return n
end
quietHours(6)                           -- Activity Tracker is 4h
check("it alerts once the threshold is crossed", noticesAbout("Activity Tracker") == 1,
      noticesAbout("Activity Tracker"))
quietHours(6)
-- The guard is per TOOL, not global: File Tracker (10h) and Command
-- History (12h) legitimately cross their own thresholds in this window and
-- get their own first notice. Counting every notification would call that
-- a bug.
check("...and does NOT alert about the SAME tool again the same day, "
      .. "however long it stays broken", noticesAbout("Activity Tracker") == 1,
      noticesAbout("Activity Tracker"))
TODAY = "2026-08-10"
quietHours(1)
check("...but it DOES speak up about it again the next day",
      noticesAbout("Activity Tracker") == 2, noticesAbout("Activity Tracker"))
TODAY = "2026-08-09"

out("   -- a feature that is off on this Mac --\n")
boot(nil, { "cloudDir", "backupDir" })
allFresh() ; quietHours(1) ; quietHours(40)
check("the daily backup is not reported broken on a Mac with no OneDrive — "
      .. "it is OFF, which is a different thing", H.state.backup == "OFF",
      H.state.backup)

-- =====================================================================
out("\n=== 3. It DOES fire when something really stops ===\n")
-- =====================================================================
boot() ; allFresh() ; quietHours(1)
quietHours(5)
check("🔴 a tool that stops writing for longer than its window is reported",
      H.state.activity == "STALE", H.state.activity)
check("...as a persistent notification", #NOTIFIES >= 1)
check("...naming the tool and how long it has been quiet", (function()
    for _, n in ipairs(NOTIFIES) do
        if tostring(n.informativeText):find("Activity Tracker", 1, true)
           and tostring(n.informativeText):find("waking hours", 1, true) then return true end
    end
end)(), NOTIFIES[1] and NOTIFIES[1].informativeText)

check("🚨 the notification PERSISTS — hs.notify.show() inherits a 5-second "
      .. "withdrawAfter and would vanish while you were looking elsewhere, "
      .. "which is the entire situation this module exists for",
      NOTIFIES[1] and NOTIFIES[1].withdrawAfter == 0, NOTIFIES[1] and NOTIFIES[1].withdrawAfter)
check("...and does not auto-withdraw", NOTIFIES[1].autoWithdraw == false)

out("   -- one tool stopping does not implicate the others --\n")
boot() ; allFresh() ; quietHours(1)
for _ = 1, math.floor(5 * 60 / H.intervalMins) do
    MTIMES["/L/file_changes-Test-Mac.csv"] = NOWSEC + H.tick    -- still working
    H.check(false)
end
check("the tool that IS still writing stays OK", H.state.files == "OK", H.state.files)
check("...while the one that stopped is STALE", H.state.activity == "STALE")

out("   -- never written vs stopped writing --\n")
boot() ; quietHours(1) ; quietHours(5)
check("a file that NEVER existed is MISSING, not STALE — different problem, "
      .. "different fix", H.state.activity == "MISSING", H.state.activity)
check("...and says 'has never written'", (function()
    for _, n in ipairs(NOTIFIES) do
        if tostring(n.informativeText):find("never written", 1, true) then return true end
    end
end)())

out("   -- a module that did not load at all --\n")
boot() ; allFresh()
_G.moduleStatus = { { name = "capture_pad", ok = false, err = "syntax error" } }
H.check(false)
check("a module that FAILED TO LOAD is reported immediately, with no "
      .. "staleness reasoning needed", H.state["mod:capture_pad"] == "FAILED")
check("...and named in the notification", (function()
    for _, n in ipairs(NOTIFIES) do
        if tostring(n.informativeText):find("capture_pad", 1, true) then return true end
    end
end)())

-- =====================================================================
out("\n=== 4. Robustness — this module must not be the broken one ===\n")
-- =====================================================================
boot() ; allFresh() ; M.warm(CORE)
do
    local savedAttr = hs.fs.attributes
    hs.fs.attributes = function() error("disk went away") end
    local ok = pcall(H.check, false)
    hs.fs.attributes = savedAttr
    check("a filesystem that throws does not take the monitor down", ok)
end
do
    local savedNew = hs.notify.new
    hs.notify.new = function() error("Focus mode refused it") end
    boot() ; allFresh() ; quietHours(1) ; quietHours(5)
    hs.notify.new = savedNew
    check("if notifications are REFUSED (Do Not Disturb, Focus, a managed "
          .. "profile) it falls back to an on-screen alert rather than "
          .. "losing the warning entirely", #ALERTS > 0, #ALERTS)
end
boot() ; allFresh() ; M.warm(CORE)
do
    local savedCheck = H.check
    H.check = function() error("boom") end
    local ok = pcall(TIMERS[1].fn)
    H.check = savedCheck
    check("a throw inside the periodic tick is caught, so one bad pass does "
          .. "not stop every future one", ok)
end

-- =====================================================================
out("\n=== 5. The report ===\n")
-- =====================================================================
boot() ; allFresh() ; H.check(false)
local r = _G.healthReport()
check("_G.healthReport() returns its text", type(r) == "string")
check("it names every watched tool", (function()
    for _, c in ipairs(H.checks) do
        if not r:find(c.label, 1, true) then return false, c.label end
    end
    return true
end)())
check("it says how much WAKING time it has actually observed — otherwise "
      .. "'all OK' after 30 seconds reads like a real all-clear",
      r:find("waking hours observed", 1, true) ~= nil)
check("it lists what is deliberately NOT watched, so those read as "
      .. "considered rather than forgotten", r:find("only write when you act", 1, true) ~= nil)
boot() ; quietHours(1) ; quietHours(6)
r = _G.healthReport()
check("a broken tool's report includes the REASONING for its threshold",
      r:find("waking hours with none", 1, true) ~= nil)
check("...and the exact path to look at", r:find("/L/activity_history", 1, true) ~= nil)
check("⇪⇧H produces a report", (function()
    ALERTS = {} ; HYPER["shift|h"]()
    return #ALERTS > 0 end)())

-- =====================================================================
out("\n=== 6. Work-Mac safety ===\n")
-- =====================================================================
do
    local f = io.open(HS .. "/modules/health_monitor.lua", "r")
    local body = f:read("*a") ; f:close()
    local code = body:gsub("%-%-[^\n]*", "")
    for _, bad in ipairs({ "sudo", "launchctl", "chown", "os%.execute",
                           "io%.popen", "hs%.http", "hs%.task" }) do
        check("health_monitor runs no " .. bad:gsub("%%", ""), code:find(bad) == nil)
    end
    check("it only READS the filesystem — a monitor that writes could be the "
          .. "thing that fills your disk", code:find("io%.open") == nil)
    check("the menu bar icon is OFF by default — a permanent change to YOUR "
          .. "menu bar should be opt-in", body:find("health.menubar      = false", 1, true) ~= nil)
end

out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
