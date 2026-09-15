-- =====================================================================
-- test_dialog_home.lua — dialogs land at YOUR spot on the primary monitor
-- =====================================================================
--     lua5.4 test_dialog_home.lua [/path/to/hammerspoon]
--
-- Executes modules/dialog_home.lua against a stubbed hs and drives the
-- REAL functions: the dialog-kind rule, the primary-screen default spot,
-- the place-and-verify path, the drag capture with its self-move
-- suppression and debounce, settings validation, the frontmost-app
-- observer wiring, the on-switch sweep, refusal bookkeeping, and the
-- Accessibility-off stand-down. Nothing here touches a real window.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

-- ---- the stub Mac ------------------------------------------------------
-- TWO screens on purpose: the whole request is "the PRIMARY monitor",
-- so the stub must be able to catch the module asking for the wrong one.
local PRIMARY = { x = 0,    y = 0, w = 2000, h = 1000 }
local OTHER   = { x = 2000, y = 0, w = 1000, h = 800  }
local SETTINGS  = {}
local ALERTS    = {}
local TIMERS    = {}      -- every doAfter, fired by hand via drain()
local OBSERVERS = {}      -- every AX observer the module builds
local PRINTED   = {}      -- refusal lines (once per app is the contract)
local NOW       = 1000
local ATIME     = 0
local AX        = true
local WATCH_FN  = nil     -- the app-watcher callback the module registers
local WATCHERS  = 0
local REFUSE_WATCH = false

local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

local function mkScreen(f)
    return { frame = function() return f end,
             fullFrame = function() return f end }
end

hs = {
    screen = {
        primaryScreen = function() return mkScreen(PRIMARY) end,
        -- mainScreen is the screen with keyboard FOCUS — deliberately a
        -- different one here, so reaching for it instead of primary fails.
        mainScreen    = function() return mkScreen(OTHER) end,
    },
    settings = {
        get = function(k) return SETTINGS[k] end,
        set = function(k, v) SETTINGS[k] = v end,
    },
    alert = { show = function(msg) ALERTS[#ALERTS + 1] = tostring(msg) end },
    timer = {
        secondsSinceEpoch = function() return NOW end,
        absoluteTime = function() ATIME = ATIME + 1000000; return ATIME end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    accessibilityState = function() return AX end,
    application = {
        frontmostApplication = function() return nil end,
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
                local o = { pid = pid, watched = {}, started = false }
                function o:callback(fn) self.fn = fn; return self end
                function o:addWatcher(_, notif)
                    if REFUSE_WATCH then error("no AX for you") end
                    self.watched[#self.watched + 1] = notif; return self
                end
                function o:start()
                    if REFUSE_WATCH then error("no AX for you") end
                    self.started = true; return self
                end
                function o:stop() self.started = false; return self end
                OBSERVERS[#OBSERVERS + 1] = o
                return o
            end,
        },
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
-- Same contract as init.lua's: clamp into whichever screen contains the
-- point (here: primary first, then the other).
_G.clampToScreen = function(pt, w, h)
    for _, f in ipairs({ PRIMARY, OTHER }) do
        if pt.x >= f.x and pt.x < f.x + f.w and pt.y >= f.y and pt.y < f.y + f.h then
            return { x = math.max(f.x, math.min(pt.x, f.x + f.w - (w or 0))),
                     y = math.max(f.y, math.min(pt.y, f.y + f.h - (h or 0))) }
        end
    end
    return { x = pt.x, y = pt.y }
end

-- A fake AX element. Attributes are a plain table; setting AXPosition
-- mutates it the way a real move does, unless the element refuses.
local function el(attrs)
    local e = { attrs = attrs, sets = 0, timeouts = 0 }
    function e:setTimeout() self.timeouts = self.timeouts + 1; return self end
    function e:attributeValue(k) return self.attrs[k] end
    function e:setAttributeValue(k, v)
        if self.attrs.refuse then error("refused") end
        self.sets = self.sets + 1
        if k == "AXPosition" then self.attrs.AXPosition = { x = v.x, y = v.y } end
        return true
    end
    return e
end

local function dialogEl(x, y, w, h, extra)
    local attrs = { AXRole = "AXWindow", AXSubrole = "AXDialog",
                    AXTitle = "Copy",
                    AXPosition = { x = x, y = y },
                    AXSize = { w = w, h = h } }
    for k, v in pairs(extra or {}) do attrs[k] = v end
    return el(attrs)
end

local function fapp(name, pid, bundle, axWindows)
    return {
        name = function() return name end,
        pid = function() return pid end,
        bundleID = function() return bundle end,
        _ax = el({ AXWindows = axWindows or {} }),
    }
end

-- fire every pending one-shot timer (verify, capture debounce, sweep)
local function drain()
    for _ = 1, 50 do
        local fired = false
        for _, t in ipairs(TIMERS) do
            if not t.stopped and not t.done then t.done = true; fired = true; t.fn() end
        end
        if not fired then return end
    end
end

local chunk = assert(loadfile(HS .. "/modules/dialog_home.lua"),
                     "cannot load modules/dialog_home.lua")
local function boot()
    TIMERS, OBSERVERS, ALERTS = {}, {}, {}
    local M = chunk()
    M.setup({})
    return _G.dialogHome, M
end

-- =====================================================================
out("── Dialog Home: dialogs land at your spot on the primary monitor ──\n")

out("\n=== 1. What counts as \"this kind of window\" ===\n")
local dh, M = boot()
check("the module registers a cheat sheet group in the windows family",
      M.family == "windows" and M.cheatsheet and
      M.cheatsheet.title:find("DIALOG HOME", 1, true) ~= nil)
check("AXDialog counts",
      dh.isDialogKind({ role = "AXWindow", subrole = "AXDialog" }))
check("AXSystemDialog counts",
      dh.isDialogKind({ role = "AXWindow", subrole = "AXSystemDialog" }))
check("a plain standard window does NOT",
      not dh.isDialogKind({ role = "AXWindow", subrole = "AXStandardWindow" }))
check("…unless it declares itself MODAL — a dialog in a window's clothing",
      dh.isDialogKind({ role = "AXWindow", subrole = "AXStandardWindow", modal = true }))
check("a SHEET is never ours — it is glued to its window, not to a spot",
      not dh.isDialogKind({ role = "AXSheet", subrole = "AXDialog" }))
check("alsoModal = false turns the modal rule off", (function()
    dh.alsoModal = false
    local r = dh.isDialogKind({ role = "AXWindow", subrole = "AXStandardWindow", modal = true })
    dh.alsoModal = true
    return not r
end)())

out("\n=== 2. The default spot is on the PRIMARY screen ===\n")
-- mainScreen (keyboard focus) is stubbed as a DIFFERENT monitor, so any
-- reach for the wrong screen puts the spot outside the primary frame.
local spot, kind = dh.spot(400, 200)
check("with nothing captured, the spot is the computed default", kind == "default")
check("🚨 centred on the PRIMARY monitor, not the focused one",
      spot and spot.x == (2000 - 400) * 0.5, spot and spot.x)
check("…and a little above centre, where macOS puts alerts",
      spot and spot.y == (1000 - 200) * 0.35, spot and spot.y)

out("\n=== 3. A dialog that appears is MOVED there, and the move is verified ===\n")
local d1 = dialogEl(1500, 700, 400, 200)
local okPlace, why = dh.place(d1, "Finder", "appeared")
check("the dialog is moved", okPlace and why == "moved", tostring(why))
check("…to the default spot",
      d1.attrs.AXPosition.x == 800 and d1.attrs.AXPosition.y == 280,
      d1.attrs.AXPosition.x .. "," .. d1.attrs.AXPosition.y)
check("…with the AX timeout set before anything was asked (the wedged-app rule)",
      d1.timeouts > 0)
check("…and the outcome goes on file for _G.dialogs()",
      dh.last and dh.last.app == "Finder"
      and tostring(dh.last.outcome):find("default", 1, true) ~= nil,
      dh.last and dh.last.outcome)
check("a dialog already AT the spot is left alone", (function()
    local d = dialogEl(800, 280, 400, 200)
    local ok2, why2 = dh.place(d, "Finder", "appeared")
    return ok2 and why2 == "already there" and d.sets == 0, tostring(why2)
end)())
check("🚨 the app snapping its dialog back is caught by the verify pass "
      .. "and moved once more (the VLC lesson)", (function()
    TIMERS = {}
    local d = dialogEl(1500, 700, 400, 200)
    dh.place(d, "Finder", "appeared")
    d.attrs.AXPosition = { x = 1500, y = 700 }    -- the app re-centres it
    local before = d.sets
    drain()                                        -- the verify timer fires
    return d.sets == before + 1
           and d.attrs.AXPosition.x == 800 and d.attrs.AXPosition.y == 280
end)())
check("a window with an unreadable size is left alone, honestly", (function()
    local d = el({ AXRole = "AXWindow", AXSubrole = "AXDialog",
                   AXPosition = { x = 5, y = 5 } })
    local ok2, why2 = dh.place(d, "Finder", "appeared")
    return not ok2 and why2 == "no size"
           and tostring(dh.last.outcome):find("left alone", 1, true) ~= nil
end)())
check("something dialog-FLAGGED but huge is not flung around", (function()
    local d = dialogEl(10, 10, 1900, 900)          -- > 60% of 2000x1000
    local ok2, why2 = dh.place(d, "Weird", "appeared")
    return not ok2 and why2 == "too big" and d.sets == 0
end)())
check("a dialog that refuses AXPosition is recorded, not retried forever", (function()
    local d = dialogEl(10, 10, 300, 100, { refuse = true })
    local ok2, why2 = dh.place(d, "Stubborn", "appeared")
    return not ok2 and why2 == "refused"
           and tostring(dh.last.outcome):find("refused", 1, true) ~= nil
end)())
check("a non-dialog created window is measured and skipped", (function()
    local d = el({ AXRole = "AXWindow", AXSubrole = "AXStandardWindow",
                   AXPosition = { x = 1, y = 1 }, AXSize = { w = 500, h = 400 } })
    local ok2 = dh.place(d, "Safari", "appeared")
    return not ok2 and d.sets == 0
           and dh.last.subrole == "AXStandardWindow"   -- _G.dialogs() teaches from this
end)())

out("\n=== 4. Your drag CAPTURES the spot; our own move never does ===\n")
-- The module just moved d1 at NOW=1000, so the suppression window is
-- open. AXWindowMoved inside it must be ignored.
TIMERS = {}
local d2 = dialogEl(1500, 700, 400, 200)
dh.place(d2, "Finder", "appeared")                 -- opens suppression at NOW
check("🚨 a move DURING the suppression window is not a capture "
      .. "(that is our own AXWindowMoved echoing back)",
      dh.onMoved(d2, "Finder") == false and dh.pending == nil)
NOW = NOW + 5                                       -- well past the window
d2.attrs.AXPosition = { x = 120, y = 60 }           -- you dragged it
check("a real drag is noticed", dh.onMoved(d2, "Finder") == true and dh.pending ~= nil)
check("…but nothing is kept until the drag goes QUIET (the debounce)",
      dh.pos == nil and SETTINGS["dialogHome.pos"] == nil)
drain()                                             -- the debounce fires
check("🚨 the spot is captured and persisted — LL's word, made literal",
      dh.pos and dh.pos.x == 120 and dh.pos.y == 60
      and SETTINGS["dialogHome.pos"] and SETTINGS["dialogHome.pos"].x == 120,
      dh.pos and dh.pos.x)
check("…and the capture says so on screen, with the way back",
      (ALERTS[#ALERTS] or ""):find("reset", 1, true) ~= nil, ALERTS[#ALERTS])
check("the NEXT dialog opens at the captured spot, not the default", (function()
    local d = dialogEl(1700, 500, 300, 150)
    NOW = NOW + 5
    dh.place(d, "Mail", "appeared")
    return d.attrs.AXPosition.x == 120 and d.attrs.AXPosition.y == 60,
           d.attrs.AXPosition.x .. "," .. d.attrs.AXPosition.y
end)())
check("moving a NON-dialog never captures anything", (function()
    NOW = NOW + 5
    local d = el({ AXRole = "AXWindow", AXSubrole = "AXStandardWindow",
                   AXPosition = { x = 999, y = 999 }, AXSize = { w = 500, h = 400 } })
    return dh.onMoved(d, "Safari") == false and dh.pos.x == 120
end)())
check("reset() forgets the captured spot and clears the setting", (function()
    dh.reset()
    local s, k = dh.spot(400, 200)
    return dh.pos == nil and SETTINGS["dialogHome.pos"] == nil
           and k == "default" and s.x == 800
end)())

out("\n=== 5. The spot survives a reload, and junk in settings does not ===\n")
SETTINGS["dialogHome.pos"] = { x = 120, y = 60 }
local dhR = boot()
check("a reload picks the captured spot back up",
      dhR.pos and dhR.pos.x == 120 and dhR.pos.y == 60, dhR.pos and dhR.pos.x)
for _, j in ipairs({
    { "a string",            "120,60" },
    { "a number",            42 },
    { "a table with no coordinates", { w = 10 } },
    { "a NaN",               { x = 0/0, y = 10 } },
    { "an infinity",         { x = math.huge, y = 10 } },
    { "coordinates as text", { x = "left", y = "top" } },
}) do
    SETTINGS["dialogHome.pos"] = j[2]
    local r = boot()
    check("junk in settings — " .. j[1] .. " — reads as NO spot", r.pos == nil,
          r.pos and (tostring(r.pos.x) .. "," .. tostring(r.pos.y)))
end
SETTINGS["dialogHome.pos"] = { x = "120", y = "60" }
check("numeric strings still count — a plist round trip is where that happens",
      boot().pos ~= nil and boot().pos.x == 120)
SETTINGS = {}
check("a captured spot on a monitor you no longer have is CLAMPED, not obeyed",
      (function()
    local d = boot()
    d.pos = { x = 2900, y = 100 }    -- on OTHER; clamp keeps it on a real screen
    local s = d.spot(400, 200)
    return s.x <= OTHER.x + OTHER.w - 400, s and s.x
end)())

out("\n=== 6. The watcher: frontmost app only, sweep on switch ===\n")
dh = boot()
check("exactly one app watcher is running for this", WATCH_FN ~= nil)
local waiting = dialogEl(1500, 300, 400, 200)      -- a dialog already up
local plain   = el({ AXRole = "AXWindow", AXSubrole = "AXStandardWindow",
                     AXPosition = { x = 9, y = 9 }, AXSize = { w = 600, h = 400 } })
local finder  = fapp("Finder", 100, "com.apple.finder", { plain, waiting })
NOW = NOW + 5
WATCH_FN(nil, hs.application.watcher.activated, finder)
local obs = OBSERVERS[#OBSERVERS]
check("activating an app attaches ONE observer to it", obs and obs.started)
check("…watching for windows appearing AND moving", (function()
    local created, moved = false, false
    for _, n in ipairs(obs.watched) do
        if n == "AXWindowCreated" then created = true end
        if n == "AXWindowMoved" then moved = true end
    end
    return created and moved, table.concat(obs.watched, ",")
end)())
drain()                                             -- the on-switch sweep fires
check("🚨 a dialog that was WAITING in the app is placed on switch "
      .. "(the background-copy case)",
      waiting.attrs.AXPosition.x == 800 and waiting.attrs.AXPosition.y == 280,
      waiting.attrs.AXPosition.x)
check("…and the app's ordinary windows are not touched",
      plain.sets == 0 and plain.attrs.AXPosition.x == 9)
check("the sweep is measured, so a slow app can be NAMED, not guessed at",
      dh.lastSweep and dh.lastSweep.app == "Finder" and dh.lastSweep.windows == 2)
check("a dialog APPEARING later comes through the observer and is placed",
      (function()
    local d = dialogEl(1600, 600, 350, 180)
    NOW = NOW + 5
    obs.fn(obs, d, "AXWindowCreated")
    return d.attrs.AXPosition.x ~= 1600
end)())
check("a drag reported by the observer is a capture", (function()
    NOW = NOW + 5
    local d = dialogEl(300, 400, 350, 180)
    obs.fn(obs, d, "AXWindowMoved")
    drain()
    return dh.pos and dh.pos.x == 300 and dh.pos.y == 400
end)())
check("Hammerspoon's own windows are never watched — the pads and pickers "
      .. "place themselves", (function()
    local n = #OBSERVERS
    WATCH_FN(nil, hs.application.watcher.activated,
             fapp("Hammerspoon", 7, "org.hammerspoon.Hammerspoon", {}))
    return #OBSERVERS == n
end)())
check("an app that refuses a watcher is recorded ONCE, not per activation",
      (function()
    PRINTED = {}
    REFUSE_WATCH = true
    local teams = fapp("Teams", 200, "com.microsoft.teams", {})
    WATCH_FN(nil, hs.application.watcher.activated, teams)
    WATCH_FN(nil, hs.application.watcher.activated, teams)
    REFUSE_WATCH = false
    local lines = 0
    for _, l in ipairs(PRINTED) do
        if l:find("didn't accept", 1, true) then lines = lines + 1 end
    end
    return lines == 1 and dh.refused["Teams"] == true, lines
end)())

out("\n=== 7. Status answers, and Accessibility-off stands down ===\n")
local status = dh.status()
check("_G.dialogs() names the home screen and the spot",
      status:find("primary", 1, true) ~= nil and status:find("spot", 1, true) ~= nil)
check("…and lists who refused", status:find("Teams", 1, true) ~= nil)
check("…and teaches where a missed dialog's subrole is read from",
      status:find("subrole", 1, true) ~= nil)
AX = false
local before = WATCHERS
local dhOff = boot()
check("with Accessibility off, NOTHING starts — no watcher, no observer",
      WATCHERS == before and #OBSERVERS == 0)
check("…but _G.dialogs() still says WHY, instead of silence", (function()
    return dhOff.status():find("Accessibility", 1, true) ~= nil
end)())
AX = true

print = realPrint
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do io.write("  ✗ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
