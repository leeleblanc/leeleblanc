-- =====================================================================
-- test_mouse_follows.lua — the pointer goes where focus goes (⇪⇧3)
-- =====================================================================
--     lua5.4 test_mouse_follows.lua [/path/to/hammerspoon]
--
-- Executes modules/mouse_follows.lua against a stubbed hs and drives the
-- REAL functions: the two rules (focus changed → centre; focused window
-- moved with no button down → new centre), the guards that keep it
-- polite (a button held, our own windows, the pause switch, an app on
-- the skip list, a repeat of the same move), the observer hand-over on an
-- app switch, the ⇪⇧3 toggle, the refusal bookkeeping, the report, and
-- the Accessibility-off stand-down. Nothing here touches a real pointer.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local PRINTED = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

-- ---- the stub Mac ------------------------------------------------------
local MOUSE     = { x = 10, y = 10 }
local SETS      = {}          -- every pointer move the module asked for
local BTNS      = {}          -- what checkMouseButtons reports
local AX        = true
local ALERTS    = {}
local OBSERVERS = {}
local WATCH_FN  = nil
local WATCHERS  = 0
local REFUSE_WATCH = false
local NOTICES   = {}

local TIMEOUTS = 0        -- every setTimeout the module asks for
local TIMERS   = {}       -- every doAfter, fired by hand via drain()
local ATIME    = 0
local ASTEP    = 1000000  -- 1ms per absoluteTime call; the watchdog test raises it

-- 6.160.2 — the module reads windows through hs.axuielement WITH a
-- timeout, never hs.window. The fake app's AX element answers
-- AXFocusedWindow with a fake window element built from the frame.
local function mkApp(name, bundle, pid, frame)
    local app = { _name = name, _bundle = bundle, _pid = pid, _frame = frame,
                  _title = name .. " window" }
    function app:name() return self._name end
    function app:bundleID() return self._bundle end
    function app:pid() return self._pid end
    app._ax = { app = name }
    function app._ax:setTimeout() TIMEOUTS = TIMEOUTS + 1; return self end
    function app._ax:attributeValue(k)
        if k ~= "AXFocusedWindow" or not app._frame then return nil end
        local w = {}
        function w:setTimeout() TIMEOUTS = TIMEOUTS + 1; return self end
        function w:attributeValue(kk)
            local f = app._frame
            if kk == "AXPosition" then return { x = f.x, y = f.y } end
            if kk == "AXSize" then return { w = f.w, h = f.h } end
            if kk == "AXTitle" then return app._title end
        end
        return w
    end
    return app
end

local function drain()
    local n = 0
    while #TIMERS > 0 do
        local t = table.remove(TIMERS, 1)
        if not t.stopped then t.fn(); n = n + 1 end
    end
    return n
end

local SAFARI = mkApp("Safari", "com.apple.Safari", 100, { x = 0,   y = 0,   w = 800, h = 600 })
local MAIL   = mkApp("Mail",   "com.apple.mail",   200, { x = 1000, y = 100, w = 400, h = 300 })
local OWN    = mkApp("Hammerspoon", "org.hammerspoon.Hammerspoon", 300,
                     { x = 50, y = 50, w = 100, h = 100 })
local FRONT  = SAFARI

hs = {
    mouse = {
        absolutePosition = function(p)
            if p then MOUSE = { x = p.x, y = p.y }; SETS[#SETS + 1] = MOUSE end
            return { x = MOUSE.x, y = MOUSE.y }
        end,
    },
    eventtap = { checkMouseButtons = function() return BTNS end },
    timer = {
        absoluteTime = function() ATIME = ATIME + ASTEP; return ATIME end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    accessibilityState = function() return AX end,
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    application = {
        frontmostApplication = function() return FRONT end,
        watcher = {
            activated = 1, deactivated = 2, launched = 3, terminated = 4,
            new = function(fn)
                WATCH_FN = fn; WATCHERS = WATCHERS + 1
                return { start = function(s) return s end,
                         stop  = function(s) return s end }
            end,
        },
    },
    axuielement = {
        applicationElement = function(app) return app and app._ax or nil end,
        observer = {
            new = function(pid)
                local o = { pid = pid, watched = {}, started = false, stopped = false }
                function o:callback(fn) self.fn = fn; return self end
                function o:addWatcher(_, notif)
                    if REFUSE_WATCH then error("no AX for you") end
                    self.watched[#self.watched + 1] = notif; return self
                end
                function o:start()
                    if REFUSE_WATCH then error("no AX for you") end
                    self.started = true; return self
                end
                function o:stop() self.started = false; self.stopped = true; return self end
                OBSERVERS[#OBSERVERS + 1] = o
                return o
            end,
        },
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.notices = { record = function(a, b, c) NOTICES[#NOTICES + 1] = { a, b, c } end }

local function live()
    for i = #OBSERVERS, 1, -1 do
        if OBSERVERS[i].started then return OBSERVERS[i] end
    end
    return nil
end

local function fire(notif)
    local o = live()
    if o and o.fn then o.fn(o, nil, notif) end
    drain()
end
local function activate(app)
    WATCH_FN(nil, hs.application.watcher.activated, app)
    drain()
end

-- ---- boot --------------------------------------------------------------
local BOUND = {}
local PROVIDED = {}
local function boot()
    local core = {
        provide = function(name, fn) PROVIDED[name] = fn end,
        hyperAddShortcut = function(mods, key, fn, source)
            BOUND[#BOUND + 1] = { mods = mods, key = key, fn = fn, source = source }
        end,
    }
    local chunk = assert(loadfile(HS .. "/modules/mouse_follows.lua"))
    local M = chunk()
    M.setup(core)
    return M, M.config
end

out("=== 1. Module shape ===\n")
local M, mf = boot()
check("name and family", M.name == "Mouse Follows Focus" and M.family == "windows")
check("cheat sheet names ⇪⇧3", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪⇧3" then return true end
    end
    return false
end)())
check("M.config is the live table", M.config == mf and _G.mouseFollows == mf)
check("starts OFF (6.160.2) — ⇪⇧3 opts in", mf.enabled == true and mf.active == false)
check("safety knobs: an AX timeout and a watchdog",
      mf.axTimeout > 0 and mf.axTimeout <= 0.5 and mf.slowMs > 0 and mf.slowStrikes >= 1)
mf.active = true      -- the rest of the file exercises it ON

out("\n=== 2. Boot wires the watcher, the key, the observer — and does NOT jump ===\n")
check("⇪⇧3 bound with a source", (function()
    local b = BOUND[1]
    return b and b.key == "3" and b.mods[1] == "shift" and #b.mods == 1
           and b.source == "mouse follows focus"
end)())
check("one app watcher", WATCHERS == 1 and type(WATCH_FN) == "function")
check("the frontmost app has the ONE observer, both notifications", (function()
    local o = live()
    if not o then return false, "no observer" end
    local seen = {}
    for _, n in ipairs(o.watched) do seen[n] = true end
    return o.pid == 100 and seen.AXFocusedWindowChanged and seen.AXWindowMoved
end)())
check("a reload does not move the pointer", #SETS == 0 and MOUSE.x == 10)
check("boot asked no window question at all (nothing to time out on)", TIMEOUTS == 0)
check("services provided", type(PROVIDED["mouseFollows.toggle"]) == "function"
      and type(PROVIDED["mouseFollows.warp"]) == "function")

out("\n=== 3. Rule 1 — focus changes, pointer to the centre ===\n")
do
    local o = live()
    o.fn(o, nil, "AXFocusedWindowChanged")
    check("🚨 the AX callback does NO work — the jump waits for a timer (6.160.2)",
          #SETS == 0 and #TIMERS == 1 and mf.pending ~= nil)
    o.fn(o, nil, "AXWindowMoved")
    check("…and a second notification while one waits is coalesced", #TIMERS == 1)
    drain()
end
check("pointer at Safari's centre", MOUSE.x == 400 and MOUSE.y == 300, MOUSE.x .. "," .. MOUSE.y)
check("🚨 every window question carried a timeout", TIMEOUTS >= 2, TIMEOUTS)
check("counted, and the last line says why", mf.warps == 1 and mf.last
      and mf.last.why == "focus" and mf.last.app == "Safari")
fire("AXFocusedWindowChanged")
check("the same centre again is a no-op (already there)",
      #SETS == 1 and mf.lastSkip == "already there")

out("\n=== 4. An app switch hands the observer over and jumps ===\n")
local first = live()
FRONT = MAIL
activate(MAIL)
check("the old observer is stopped, the new one is Mail's",
      first.stopped == true and live() and live().pid == 200)
check("pointer at Mail's centre", MOUSE.x == 1200 and MOUSE.y == 250, MOUSE.x .. "," .. MOUSE.y)
check("why = activated", mf.last.why == "activated" and mf.currentApp == "Mail")
WATCH_FN(nil, hs.application.watcher.deactivated, MAIL); drain()
check("a deactivation does nothing", #SETS == 2)

out("\n=== 5. Rule 2 — the focused window moves, no button down ===\n")
MAIL._frame = { x = 0, y = 0, w = 400, h = 300 }
fire("AXWindowMoved")
check("pointer follows to the new centre", MOUSE.x == 200 and MOUSE.y == 150,
      MOUSE.x .. "," .. MOUSE.y)
check("why = moved", mf.last.why == "moved" and mf.warps == 3)
MOUSE = { x = 5, y = 5 }         -- you moved the mouse away by hand…
fire("AXWindowMoved")            -- …and AX reports the SAME move again
check("a repeat of the same move does not yank the pointer back",
      MOUSE.x == 5 and mf.lastSkip == "already there")
MAIL._frame = { x = 0, y = 0, w = 400, h = 300 }
fire("AXWindowMoved")
check("a non-focused window moving (focused frame unchanged) does nothing",
      MOUSE.x == 5 and #SETS == 3)
MAIL._frame = { x = 100, y = 100, w = 400, h = 300 }
fire("AXFocusedWindowChanged")
check("…but a focus change to that frame does jump", MOUSE.x == 300 and MOUSE.y == 250)

out("\n=== 6. The guards ===\n")
BTNS = { left = true }
MAIL._frame = { x = 200, y = 200, w = 400, h = 300 }
fire("AXWindowMoved")
check("a mouse button down: the window is YOUR drag — no jump",
      MOUSE.x == 300 and mf.lastSkip == "a mouse button is down")
fire("AXFocusedWindowChanged")
check("…not even on a focus change (a click IS a button down)", MOUSE.x == 300)
BTNS = {}
local skippedBefore = mf.skipped
_G.hsPaused = true
fire("AXFocusedWindowChanged")
check("paused (⇪⇧1): stands still and says so",
      MOUSE.x == 300 and mf.lastSkip == "paused (⇪⇧1)" and mf.skipped == skippedBefore + 1)
_G.hsPaused = false
fire("AXFocusedWindowChanged")
check("unpaused: the jump it withheld happens on the next change",
      MOUSE.x == 400 and MOUSE.y == 350)

mf.followMoves = false
MAIL._frame = { x = 0, y = 0, w = 400, h = 300 }
fire("AXWindowMoved")
check("followMoves = false ignores rule 2", MOUSE.x == 400)
mf.followMoves = true

mf.skipApps = { Mail = true }
fire("AXFocusedWindowChanged")
check("an app on the skip list is never followed",
      MOUSE.x == 400 and tostring(mf.lastSkip):find("skipped app: Mail", 1, true) ~= nil)
mf.skipApps = {}

MAIL._frame = nil
fire("AXFocusedWindowChanged")
check("no focused window: no jump, reason recorded",
      MOUSE.x == 400 and tostring(mf.lastSkip):find("no focused window", 1, true) ~= nil)
MAIL._frame = { x = 0, y = 0, w = 400, h = 300 }

out("\n=== 7. Our own windows are never a target ===\n")
local obsBefore = #OBSERVERS
FRONT = OWN
activate(OWN)
check("no observer on Hammerspoon itself", #OBSERVERS == obsBefore and live() == nil)
check("no jump into a pad or a picker",
      MOUSE.x == 400 and mf.lastSkip == "own window")
FRONT = MAIL
activate(MAIL)
check("back to Mail: observed and jumped", live() and live().pid == 200 and MOUSE.x == 200)

out("\n=== 8. ⇪⇧3 toggles ===\n")
local alertsBefore = #ALERTS
BOUND[1].fn()
check("off: says so, and a focus change moves nothing", (function()
    MAIL._frame = { x = 400, y = 400, w = 400, h = 300 }
    fire("AXFocusedWindowChanged")
    return mf.active == false and #ALERTS == alertsBefore + 1
           and ALERTS[#ALERTS]:find("off", 1, true) and MOUSE.x == 200
           and mf.pending == nil
end)())
BOUND[1].fn()
check("on: says so and jumps to the focused window right away",
      mf.active == true and ALERTS[#ALERTS]:find("ON", 1, true) ~= nil
      and MOUSE.x == 600 and MOUSE.y == 550)
check("the service toggles the same switch", PROVIDED["mouseFollows.toggle"]() == false
      and PROVIDED["mouseFollows.toggle"]() == true)

out("\n=== 9. An app that refuses a watcher is said ONCE ===\n")
REFUSE_WATCH = true
local TEAMS = mkApp("Teams", "com.microsoft.teams", 400, { x = 0, y = 0, w = 200, h = 200 })
FRONT = TEAMS
activate(TEAMS)
activate(TEAMS)
check("one Console line for two activations", (function()
    local n = 0
    for _, l in ipairs(PRINTED) do
        if l:find("Teams didn't accept", 1, true) then n = n + 1 end
    end
    return n == 1 and mf.refused.Teams == true, n
end)())
check("…and the jump still happened (rule 1 rides the app watcher)",
      MOUSE.x == 100 and MOUSE.y == 100)
REFUSE_WATCH = false
FRONT = MAIL

out("\n=== 9b. The watchdog — a slow app turns it OFF, never hangs it ===\n")
activate(MAIL)                 -- Teams refused, so Mail's observer must come back
check("Mail is observed again after the refusal", live() and live().pid == 200)
ASTEP = 400 * 1000000          -- every clock read is now 400ms later
local alertsW, noticesW = #ALERTS, #NOTICES
MAIL._frame = { x = 10, y = 10, w = 100, h = 100 }
fire("AXFocusedWindowChanged")
check("strike one: the jump still happens, and its time is kept",
      mf.slowHits == 1 and mf.active == true and mf.lastMs and mf.lastMs >= 400)
MAIL._frame = { x = 20, y = 20, w = 100, h = 100 }
fire("AXFocusedWindowChanged")
check("strike two: OFF for the session, on screen, in the notices",
      mf.active == false and mf.stoodDown ~= nil
      and #ALERTS == alertsW + 1 and ALERTS[#ALERTS]:find("OFF", 1, true)
      and #NOTICES == noticesW + 1 and NOTICES[#NOTICES][2] == "stood down")
MAIL._frame = { x = 30, y = 30, w = 100, h = 100 }
fire("AXFocusedWindowChanged")
check("…and nothing is even scheduled while it is off", #TIMERS == 0 and mf.pending == nil)
ASTEP = 1000000
mf.active = true

out("\n=== 10. The report ===\n")
local r = _G.mouseFollowsReport()
check("names the state, the last jump and who refused",
      r:find("ON", 1, true) and r:find("last", 1, true) and r:find("Teams", 1, true)
      and r:find("jumped", 1, true) ~= nil)
check("…and the watchdog's verdict and the timeout", r:find("stood down", 1, true)
      and r:find("AX timeout", 1, true) ~= nil)
check("the service returns the same text", PROVIDED["mouseFollows.report"]() == r)

out("\n=== 11. Accessibility off stands down, and says so ===\n")
AX = false
local boundBefore, watchersBefore = #BOUND, WATCHERS
local _, off = boot()
check("nothing starts: no watcher, no key", WATCHERS == watchersBefore and #BOUND == boundBefore)
check("a notice records why", (function()
    local n = NOTICES[#NOTICES]
    return n and n[1] == "mouseFollows" and n[2] == "Accessibility off"
end)())
check("the report says OFF", _G.mouseFollowsReport():find("OFF", 1, true) ~= nil)
check("…and the table is still published for a profile", _G.mouseFollows == off)
AX = true

out("\n=== 12. Source sentries ===\n")
local src = io.open(HS .. "/modules/mouse_follows.lua"):read("a")
local code = {}
for line in (src .. "\n"):gmatch("([^\n]*)\n") do
    code[#code + 1] = (line:gsub("%-%-.*$", ""))
end
code = table.concat(code, "\n")
check("no hs.window.filter (the 44-second beachball)", code:find("hs%.window%.filter") == nil)
check("no hs.window.orderedWindows (a full sweep per call)",
      code:find("orderedWindows") == nil)
check("no setAbsolutePosition (a deprecated shim)", code:find("setAbsolutePosition") == nil)
check("no polling timer — it is event-driven", code:find("doEvery") == nil)
check("🚨 no hs.window reads — every question goes through axuielement WITH setTimeout (6.160.2)",
      code:find("focusedWindow%(") == nil and code:find(":frame%(") == nil
      and code:find("setTimeout") ~= nil)
check("honours the pause switch", code:find("_G%.hsPaused") ~= nil)
check("checks the mouse buttons before every jump", code:find("checkMouseButtons") ~= nil)
check("returns its module table and exposes config",
      src:find("\nreturn M", 1, true) ~= nil and src:find("M%.config") ~= nil)

print = realPrint
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do io.write("  ✗ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
