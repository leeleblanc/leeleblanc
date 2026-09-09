-- =====================================================================
-- test_mouse_follows.lua — the pointer goes where focus goes (⇪1)
-- =====================================================================
--     lua5.4 test_mouse_follows.lua [/path/to/hammerspoon]
--
-- Executes modules/mouse_follows.lua against a stubbed hs and drives the
-- REAL functions: the two rules (focus changed → centre; focused window
-- moved with no button down → new centre), the guards that keep it
-- polite (a button held, our own windows, the pause switch, an app on
-- the skip list, a repeat of the same move), the observer hand-over on an
-- app switch, the ⇪1 toggle, the refusal bookkeeping, the report, and
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

TAP = nil                 -- 6.168.0: the click tap the module built
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

-- Fires the zero-delay hand-offs. A LONG timer (6.161.0: the rest) stays
-- in TIMERS for the test to fire by hand — a real doAfter(300) does not
-- fire because a notification arrived.
local SETTINGS = {}       -- 6.161.0: the hs.settings the memory lives in
local function drain()
    local n = 0
    local keep = {}
    while #TIMERS > 0 do
        local t = table.remove(TIMERS, 1)
        if t.secs and t.secs >= 1 then keep[#keep + 1] = t
        elseif not t.stopped then t.fn(); n = n + 1 end
    end
    for _, t in ipairs(keep) do TIMERS[#TIMERS + 1] = t end
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
    eventtap = {
        checkMouseButtons = function() return BTNS end,
        -- 6.168.0: the click-stamping tap
        event = { types = { leftMouseDown = 1, rightMouseDown = 3, otherMouseDown = 25,
                            leftMouseUp = 2, rightMouseUp = 4, otherMouseUp = 26 } },
        new = function(kinds, fn)
            local t = { kinds = kinds, fn = fn, started = false }
            function t:start() self.started = true; return self end
            function t:stop() self.started = false; return self end
            TAP = t
            return t
        end,
    },
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
    settings = {
        get = function(k) return SETTINGS[k] end,
        set = function(k, v) SETTINGS[k] = v end,
    },
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
check("cheat sheet names ⇪1", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪1" then return true end
    end
    return false
end)())
check("M.config is the live table", M.config == mf and _G.mouseFollows == mf)
check("starts OFF on a fresh Mac (6.160.2) — ⇪1 opts in, nothing remembered yet",
      mf.enabled == true and mf.active == false and mf.remembered == nil)
check("the memory is on, with a settings key of its own (6.161.0)",
      mf.remember == true and type(mf.SETTINGS_KEY) == "string")
check("safety knobs: an AX timeout and a watchdog",
      mf.axTimeout > 0 and mf.axTimeout <= 0.5 and mf.slowMs > 0 and mf.slowStrikes >= 1)
mf.active = true      -- the rest of the file exercises it ON

out("\n=== 2. Boot wires the watcher, the key, the observer — and does NOT jump ===\n")
-- 6.194.0 — moved to ⇪1 (⇪⇧3 is the delayed screenshot now). The MODS
-- are asserted as empty, not just the key: leaving the shift on would
-- bind ⇪⇧1, which is the screenshot editor — two owners for one combo.
check("⇪1 bound with a source, and with NO modifier", (function()
    local b = BOUND[1]
    return b and b.key == "1" and #b.mods == 0
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
check("paused (⇪⇧Esc): stands still and says so",
      MOUSE.x == 300 and mf.lastSkip == "paused (⇪⇧Esc)" and mf.skipped == skippedBefore + 1)
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

out("\n=== 8. ⇪1 toggles ===\n")
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

out("\n=== 8b. ⇪1 is remembered across a reload (6.161.0) ===\n")
check("every press is written to hs.settings — ON now",
      SETTINGS[mf.SETTINGS_KEY] == true)
BOUND[1].fn()
check("…off now", SETTINGS[mf.SETTINGS_KEY] == false and mf.active == false)
BOUND[1].fn()
check("…and on again", SETTINGS[mf.SETTINGS_KEY] == true and mf.active == true)
do
    local setsBefore = #SETS
    local M2, mf2 = boot()
    check("a reload with ON remembered starts ON — no ⇪1 needed",
          mf2.active == true and mf2.remembered == true)
    check("…and still moves nothing at boot", #SETS == setsBefore)
    check("the report says so", _G.mouseFollowsReport():find("ON at boot", 1, true) ~= nil)
    SETTINGS[mf2.SETTINGS_KEY] = false
    local _, mf3 = boot()
    check("a reload with off remembered starts off", mf3.active == false and mf3.remembered == false)
    SETTINGS[mf3.SETTINGS_KEY] = "garbage"
    local _, mf4 = boot()
    check("a corrupt memory is ignored — boot default, nothing remembered",
          mf4.active == false and mf4.remembered == nil)
    mf4.remember = false
    check("mf.remember = false: the press is not stored", (function()
        SETTINGS[mf4.SETTINGS_KEY] = nil
        mf4.toggle()
        return SETTINGS[mf4.SETTINGS_KEY] == nil and mf4.active == true
    end)())
    SETTINGS = {}
    hs.settings.set = function() error("disk says no") end
    local _, mf5 = boot()
    check("hs.settings that throws: the press still lands, nothing else breaks",
          mf5.toggle() == true and mf5.active == true)
    hs.settings.set = function(k, v) SETTINGS[k] = v end
    -- back to the suite's module: the fixture from here on is `mf`
    M, mf = boot()
    mf.active = true
    FRONT = MAIL
    activate(MAIL)
end

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
check("strike two: it RESTS (6.161.0) — off, on screen, in the notices, the rest timer held",
      mf.active == false and mf.stoodDown ~= nil and mf.restUntil ~= nil
      and #ALERTS == alertsW + 1 and ALERTS[#ALERTS]:find("rest", 1, true)
      and #NOTICES == noticesW + 1 and NOTICES[#NOTICES][2] == "resting"
      and mf.restTimer ~= nil and #TIMERS == 1 and TIMERS[1].secs == mf.slowRest)
check("the strikes are spent — the next rest needs two fresh ones", mf.slowHits == 0 and #mf.strikes == 0)
MAIL._frame = { x = 30, y = 30, w = 100, h = 100 }
fire("AXFocusedWindowChanged")
check("…and nothing is even scheduled while it rests", #TIMERS == 1 and mf.pending == nil)
check("the report names the rest", _G.mouseFollowsReport():find("resting until", 1, true) ~= nil)
ASTEP = 1000000
do
    local rest = table.remove(TIMERS, 1)
    rest.fn()
    check("the rest ends on its own: ON again, and it says so",
          mf.active == true and mf.restUntil == nil and mf.restTimer == nil
          and ALERTS[#ALERTS]:find("back ON", 1, true) ~= nil)
    check("…and the report files the rest as history, not as the state",
          mf.stoodDown == nil and mf.lastRest ~= nil
          and _G.mouseFollowsReport():find("last rest", 1, true) ~= nil
          and _G.mouseFollowsReport():find("stood down", 1, true) == nil)
end
out("\n=== 9c. A rest cut short by ⇪1, and strikes that expire ===\n")
SETTINGS[mf.SETTINGS_KEY] = true       -- what a real ⇪1 ON left behind
ASTEP = 400 * 1000000
MAIL._frame = { x = 40, y = 40, w = 100, h = 100 }
fire("AXFocusedWindowChanged")
MAIL._frame = { x = 50, y = 50, w = 100, h = 100 }
fire("AXFocusedWindowChanged")
check("resting again after two more slow jumps", mf.active == false and #TIMERS == 1)
check("a rest never writes the memory — a reload mid-rest comes back ON",
      SETTINGS[mf.SETTINGS_KEY] == true)
ASTEP = 1000000
-- BOUND[#BOUND]: the newest boot's ⇪⇧3 (8b rebooted the module)
BOUND[#BOUND].fn()
check("⇪⇧3 during a rest wakes it now — the rest timer is stopped, not left to fire",
      mf.active == true and mf.restUntil == nil and TIMERS[1].stopped == true
      and mf.restTimer == nil and SETTINGS[mf.SETTINGS_KEY] == true)
TIMERS = {}
BOUND[#BOUND].fn()
check("…and an explicit off after that stays off", mf.active == false and #TIMERS == 0)
BOUND[#BOUND].fn()
mf.strikes = { os.time() - mf.slowWindow - 5 }
mf.slowHits = 1
ASTEP = 400 * 1000000
MAIL._frame = { x = 60, y = 60, w = 100, h = 100 }
fire("AXFocusedWindowChanged")
check("a strike older than slowWindow is forgotten — one slow jump does not stand it down",
      mf.active == true and mf.slowHits == 1 and #mf.strikes == 1)
ASTEP = 1000000
mf.strikes, mf.slowHits = {}, 0
mf.active = true

out("\n=== 10. The report ===\n")
local r = _G.mouseFollowsReport()
check("names the state, the last jump and who refused",
      r:find("ON", 1, true) and r:find("last", 1, true) and r:find("Teams", 1, true)
      and r:find("jumped", 1, true) ~= nil)
check("…and the watchdog's verdict (now history) and the timeout", r:find("last rest", 1, true)
      and r:find("AX timeout", 1, true) ~= nil)
check("the service returns the same text", PROVIDED["mouseFollows.report"]() == r)

out("\n=== 11. Accessibility off stands down, and says so ===\n")
AX = false
local boundBefore, watchersBefore = #BOUND, WATCHERS
SETTINGS = {}
local _, off = boot()
local offKey = BOUND[#BOUND]           -- THIS instance's ⇪⇧3
check("nothing starts: no watcher — but ⇪⇧3 IS bound (6.161.0)",
      WATCHERS == watchersBefore and #BOUND == boundBefore + 1)
check("…and the press explains where to grant Accessibility instead of doing nothing",
      (function()
          local n = #ALERTS
          offKey.fn()
          return off.active == false and off.appWatcher == nil and #ALERTS == n + 1
                 and ALERTS[#ALERTS]:find("Accessibility", 1, true) ~= nil
      end)())
check("a notice records why", (function()
    local n = NOTICES[#NOTICES]
    return n and n[1] == "mouseFollows" and n[2] == "Accessibility off"
end)())
check("the report says OFF", _G.mouseFollowsReport():find("OFF", 1, true) ~= nil)
check("…and the table is still published for a profile", _G.mouseFollows == off)
check("…and the memory was still read, so the report knows it",
      (function()
          SETTINGS["mouseFollows.active"] = true
          local _, off2 = boot()
          local r = _G.mouseFollowsReport()
          SETTINGS = {}
          return off2.remembered == true and r:find("ON at boot", 1, true) ~= nil
      end)())
out("\n--- Accessibility granted AFTER boot: ⇪⇧3 starts the watcher itself (6.161.0) ---\n")
AX = true
do
    local w0, setsBefore = WATCHERS, #SETS
    FRONT = MAIL
    MAIL._frame = { x = 700, y = 700, w = 200, h = 200 }   -- somewhere the pointer is not
    offKey.fn()
    check("the press turns it ON and starts the app watcher — no reload needed",
          off.active == true and off.appWatcher ~= nil and WATCHERS == w0 + 1)
    check("…the front app is observed and the first jump happened",
          live() and live().pid == 200 and #SETS == setsBefore + 1)
    check("a second press does not start a second watcher",
          (function() offKey.fn(); offKey.fn(); return WATCHERS == w0 + 1 end)())
end
out("\n--- the memory, both ways, and a profile that turns it off ---\n")
do
    SETTINGS = {}
    SETTINGS["mouseFollows.active"] = false
    local _, m1 = boot()
    m1.active = true            -- as a profile override would set the default
    local _, m2 = boot()
    check("a remembered OFF is honoured too, not only a remembered ON",
          m2.active == false and m2.remembered == false)
    SETTINGS["mouseFollows.active"] = true
    local _, m3 = boot()
    m3.remember = false         -- the profile override lands AFTER setup
    m3.toggle()
    check("remember = false from a profile: the first press wipes the stale memory",
          SETTINGS["mouseFollows.active"] == nil)
    SETTINGS = {}
end


out("\n=== 11b. ✋ The hand on the mouse (6.168.0) ===\n")
do
    -- Fresh boot, Accessibility on, ON — the click tap is part of start().
    AX = true; SETTINGS = {}; TAP = nil
    MAIL._frame   = { x = 1000, y = 100, w = 400, h = 300 }   -- centre 1200,250
    SAFARI._frame = { x = 0,    y = 0,   w = 800, h = 600 }   -- centre 400,300
    local M2, m = boot()
    m.active = true
    check("start() builds ONE click tap and holds it", m.clickTap ~= nil and m.clickTap == TAP and TAP.started)
    check("the tap listens for buttons down AND up, nothing else",
          TAP and #TAP.kinds == 6 and TAP.kinds[1] == 1 and TAP.kinds[4] == 2)
    check("a second start() keeps the same tap", (function()
        local before = TAP; m.appWatcher = nil; m.start(); return TAP == before and m.clickTap == before
    end)())
    -- the module's warp target: Mail's centre
    FRONT = MAIL; MOUSE = { x = 10, y = 10 }; SETS = {}
    ASTEP = 1000000

    -- CLICK GRACE: a click, then the focus notification the click caused
    local passThrough = TAP.fn()
    check("the tap lets the click through", passThrough == false and m.clicks == 1 and m.lastClickMs ~= nil)
    activate(MAIL)
    check("a focus change right after a click does NOT jump", #SETS == 0, #SETS)
    check("…and says whose focus it was", tostring(m.lastSkip):find("you clicked %d+ms ago") ~= nil, m.lastSkip)
    ATIME = ATIME + 700 * 1000000  -- the clock jumps past the grace (one leap: the watchdog times jumps)
    activate(MAIL)
    check("past the click grace it follows again", #SETS == 1 and MOUSE.x == 1200 and MOUSE.y == 250, #SETS .. " " .. tostring(m.lastSkip) .. " " .. MOUSE.x .. "," .. MOUSE.y)

    -- SETTLE: the hand-off waits a beat, not zero
    m.schedule("focus")
    local t = TIMERS[#TIMERS]
    check("the hand-off waits mf.settle (0.12 s), not 0", t and t.secs == 0.12, t and t.secs)
    check("…and remembers where the pointer was", m.pendingFrom and m.pendingFrom.x == 1200)
    -- the hand moves the mouse while it waits
    MOUSE = { x = 1230, y = 250 }
    SETS = {}
    drain()
    check("a hand that moved the mouse while it waited wins — no jump", #SETS == 0, #SETS)
    check("…and the report knows why", tostring(m.lastSkip):find("your hand moved the mouse 30px") ~= nil, m.lastSkip)
    ATIME = ATIME + 3000 * 1000000        -- well past the repeat grace
    check("a 2px tremor is not a hand", (function()
        MOUSE = { x = 10, y = 10 }; m.schedule("focus"); MOUSE = { x = 12, y = 11 }; SETS = {}; drain()
        return #SETS == 1 and MOUSE.x == 1200
    end)(), tostring(m.lastSkip))

    -- A CENTRE STAYS YOURS: sent to Mail's centre, moved away, same centre again
    MOUSE = { x = 900, y = 900 }; SETS = {}
    fire("AXFocusedWindowChanged")
    check("the same centre announced again within 2 s is a repeat — no jump", #SETS == 0, #SETS)
    check("…said in words", tostring(m.lastSkip):find("sent there [%d%.]+s ago and you moved away") ~= nil, m.lastSkip)
    ATIME = ATIME + 3000 * 1000000
    fire("AXFocusedWindowChanged")
    check("after mf.repeatGrace it is a real change again", #SETS == 1 and MOUSE.x == 1200,
          #SETS .. " skip=" .. tostring(m.lastSkip))
    check("none of that tripped the watchdog (the clock leapt between jumps, not inside one)",
          m.active and m.slowHits == 0, m.slowHits)
    check("a NEW centre is never a repeat", (function()
        FRONT = SAFARI; MOUSE = { x = 900, y = 900 }; SETS = {}
        activate(SAFARI)
        return #SETS == 1 and MOUSE.x == 400 and MOUSE.y == 300
    end)(), tostring(m.lastSkip) .. " " .. #SETS .. " " .. MOUSE.x)

    -- knobs survive a profile's strings and nonsense
    m.clickGrace = "0.5"; m.settle = -1; m.handPx = "three"; m.repeatGrace = nil
    check("knobs as strings / nonsense fall back and never throw", (function()
        local ok = pcall(function() m.schedule("focus"); drain() end)
        return ok and TIMERS[#TIMERS] == nil or ok
    end)())
    local rep = _G.mouseFollowsReport()
    check("report: the hand line with the defaults restored for bad values",
          rep:find("your hand     : click grace 500ms · settles 120ms · hand 3px · a centre stays yours 2.0s · ", 1, true) ~= nil, rep)
    check("report counts the clicks it saw", rep:find("1 click seen", 1, true) ~= nil, rep)
    m.clickGrace, m.settle, m.handPx, m.repeatGrace = 0.6, 0.12, 3, 2

    -- the pause switch: the tap stamps nothing while paused
    _G.hsPaused = true
    local before = m.clicks
    TAP.fn()
    check("paused: the tap lets the click through and stamps nothing", m.clicks == before)
    _G.hsPaused = false

    -- no tap at all (an hs without eventtap.new): the grace is off, nothing throws
    local savedNew = hs.eventtap.new
    hs.eventtap.new = nil
    AX = true; SETTINGS = {}; TAP = nil
    local _, m3 = boot()
    check("no eventtap.new: boot survives, clickTap nil, report says so",
          m3.clickTap == nil and _G.mouseFollowsReport():find("click tap NOT running", 1, true) ~= nil)
    hs.eventtap.new = savedNew
    AX = true; SETTINGS = {}
    M, mf = boot()
end

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
check("6.168.0: the click tap is HELD, the hand-off waits mf.settle, the tap honours the pause",
      code:find("mf%.clickTap = tap") ~= nil and code:find("num%(mf%.settle") ~= nil
      and code:find("if _G%.hsPaused then return false end") ~= nil)
check("returns its module table and exposes config",
      src:find("\nreturn M", 1, true) ~= nil and src:find("M%.config") ~= nil)

print = realPrint
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do io.write("  ✗ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
