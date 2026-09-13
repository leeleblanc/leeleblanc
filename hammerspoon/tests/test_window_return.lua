-- =====================================================================
-- test_window_return.lua — frames per monitor setup, restored on return
-- =====================================================================
--     lua5.4 test_window_return.lua [/path/to/hammerspoon]
--
-- Executes modules/window_return.lua against a stubbed hs and drives the
-- REAL functions: the signature, the snapshot filter, the id-then-title
-- matching with consumption, the off-screen and drift guards, the
-- settle-then-decide path, persistence across a simulated reload, and
-- the Accessibility-off stand-down.

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
local SCREENS  = {}       -- what allScreens() reports; each { uuid, frame }
local WINDOWS  = {}       -- what allWindows() reports
local APPS     = {}       -- what runningApplications() reports (6.137.0 sweep)
local SETTINGS = {}       -- what hs.settings holds
local ALERTS   = {}
local TIMERS   = {}       -- every doAfter/doEvery, fired by hand
local AX       = true
local ATIME    = 0        -- fake absoluteTime, advancing 1ms per reading

local function screen(uuid, x, y, w, h)
    return { getUUID   = function() return uuid end,
             fullFrame = function() return { x = x, y = y, w = w, h = h } end }
end

-- A fake window. `opts` can turn off standard, turn on minimized, or
-- change the bundle; frame is mutable through setFrame like the real one.
local function win(id, bundle, title, x, y, w, h, opts)
    opts = opts or {}
    local o = { _frame = { x = x, y = y, w = w, h = h }, moved = 0 }
    o.id          = function() return id end
    o.title       = function() return title end
    o.isStandard  = function() return opts.standard ~= false end
    o.isMinimized = function() return opts.minimized == true end
    o.application = function()
        if opts.noApp then return nil end
        return { bundleID = function() return bundle end }
    end
    o.frame    = function() return o._frame end
    o.setFrame = function(_, f) o._frame = { x = f.x, y = f.y, w = f.w, h = f.h }
                                o.moved = o.moved + 1 end
    return o
end

-- A fake application for the chunked snapshot sweep (6.137.0). `kind`
-- mirrors hs.application:kind(): 1 = regular GUI app, 0 = agent. _asked
-- counts allWindows() calls, which is how the tests prove an agent is
-- never paid an Accessibility round trip.
local function fapp(name, kind, wins)
    return {
        _asked = 0,
        name = function() return name end,
        kind = function() return kind end,
        allWindows = function(self) self._asked = self._asked + 1; return wins end,
    }
end

hs = {
    screen = {
        allScreens = function() return SCREENS end,
        watcher = { new = function(fn) return {
            fn = fn, started = false,
            start = function(self) self.started = true end,
            stop  = function(self) self.started = false end,
        } end },
    },
    window   = { allWindows = function() return WINDOWS end },
    application = { runningApplications = function() return APPS end },
    settings = {
        get = function(k) return SETTINGS[k] end,
        set = function(k, v) SETTINGS[k] = v end,
    },
    alert = { show = function(msg) ALERTS[#ALERTS + 1] = tostring(msg) end },
    timer = {
        absoluteTime = function() ATIME = ATIME + 1000000; return ATIME end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, every = true, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    accessibilityState = function() return AX end,
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
local CORE = {}

-- fire every pending one-shot timer (the settle path chains them)
local function drain()
    for _ = 1, 50 do
        local fired = false
        for _, t in ipairs(TIMERS) do
            if not t.every and not t.stopped and not t.done then
                t.done = true; fired = true; t.fn()
            end
        end
        if not fired then return end
    end
end

-- =====================================================================
out("── Window Return: remember per setup, restore on return ──\n")
out("\n1. contract & wiring\n")
-- =====================================================================
local DOCKED = { screen("UUID-A", 0, 0, 1512, 982), screen("UUID-B", 1512, 0, 2560, 1440) }
local LAPTOP = { screen("UUID-A", 0, 0, 1512, 982) }
SCREENS = DOCKED

local M = dofile(HS .. "/modules/window_return.lua")
check("module loads and has setup()", type(M.setup) == "function")
check("filed under the windows family", M.family == "windows")
check("cheat group present, no ⇪ key claimed", (function()
    if type(M.cheatsheet) ~= "table" then return false end
    for _, e in ipairs(M.cheatsheet.entries) do
        if tostring(e[1]):match("^⇪") then return false end
    end
    return #M.cheatsheet.entries >= 4
end)())
M.setup(CORE)
local wr = _G.windowReturn
check("module table exported", type(wr) == "table")
check("_G.windowsBack is published", type(_G.windowsBack) == "function")
check("the screen watcher is up", wr.watcher ~= nil and wr.watcher.started == true)
check("snapshot cadence timer is HELD (an unreferenced timer never fires)",
      wr.snapTimer ~= nil and wr.snapTimer.every == true)

-- =====================================================================
out("2. the signature — sorted, order-blind\n")
-- =====================================================================
check("two screens make one signature", wr.signature() == "UUID-A+UUID-B")
SCREENS = { DOCKED[2], DOCKED[1] }
check("…the SAME one whatever order macOS lists them in",
      wr.signature() == "UUID-A+UUID-B")
SCREENS = LAPTOP
check("the laptop alone is a different setup", wr.signature() == "UUID-A")
SCREENS = DOCKED

-- =====================================================================
out("3. the snapshot — who gets remembered\n")
-- =====================================================================
local safari  = win(101, "com.apple.Safari",  "Apple",    100, 50, 900, 700)
local excel   = win(102, "com.microsoft.Excel", "Q3.xlsx", 1600, 80, 1200, 900)
local mini    = win(103, "com.apple.TextEdit", "hidden",   0, 0, 400, 300, { minimized = true })
local weird   = win(104, "com.apple.Finder",  "popup",     0, 0, 200, 100, { standard = false })
local ourOwn  = win(105, "org.hammerspoon.Hammerspoon", "picker", 300, 200, 400, 500)
local orphan  = win(106, nil, "no app", 0, 0, 300, 300, { noApp = true })
WINDOWS = { safari, excel, mini, weird, ourOwn, orphan }

-- 6.137.0: the snapshot sweeps app by app, so the fake Mac's windows
-- live in fake apps now. One agent (kind 0) stands guard: paying it an
-- Accessibility round trip is the regression these checks exist to stop.
local agent = fapp("BackgroundAgent", 0, {})
APPS = {
    fapp("Safari",      1, { safari }),
    fapp("Excel",       1, { excel  }),
    fapp("TextEdit",    1, { mini   }),
    fapp("Finder",      1, { weird  }),
    fapp("Hammerspoon", 1, { ourOwn }),
    fapp("Ghost",       1, { orphan }),
    agent,
}

-- The single whole-desktop call was the 1,586ms keyboard freeze. The
-- snapshot must never make it again; wr.plan (section 4) still may.
local wholeDesktopAsks = 0
local realAllWindows = hs.window.allWindows
hs.window.allWindows = function()
    wholeDesktopAsks = wholeDesktopAsks + 1; return WINDOWS
end

wr.snapshot()
check("the sweep is chunked — nothing is committed before the steps run",
      wr.layouts["UUID-A+UUID-B"] == nil and wr.sweeping == true)
drain()
hs.window.allWindows = realAllWindows
local saved = wr.layouts["UUID-A+UUID-B"]
check("the docked setup was remembered", saved ~= nil and type(saved.entries) == "table")
check("…with exactly the two real windows — minimized, non-standard, our"
      .. " own pickers and app-less windows all skipped",
      saved and #saved.entries == 2, saved and #saved.entries)
check("…and persisted through hs.settings, so a reload costs nothing",
      type(SETTINGS["windowReturn.layouts"]) == "table"
      and SETTINGS["windowReturn.layouts"]["UUID-A+UUID-B"] ~= nil)
check("the snapshot never asks for the whole desktop at once",
      wholeDesktopAsks == 0, wholeDesktopAsks)
check("a kind-0 agent is never asked for its windows", agent._asked == 0)
check("the sweep profile names every app it paid a round trip",
      wr.lastSweep ~= nil and #wr.lastSweep.apps == 6,
      wr.lastSweep and #wr.lastSweep.apps)
check("a snapshot mid-transition is refused — it would save the mess", (function()
    wr.transitioning = true
    wr.snapshot()
    wr.transitioning = false
    return wr.layouts["UUID-A+UUID-B"] == saved   -- same table: no commit
end)())
check("a monitor change MID-SWEEP abandons the pass uncommitted", (function()
    wr.snapshot()                 -- a fresh sweep takes off
    wr.transitioning = true       -- …and the screens change under it
    drain()
    wr.transitioning = false
    return wr.layouts["UUID-A+UUID-B"] == saved and wr.sweeping == false
end)())

-- =====================================================================
out("4. the plan — id first, exact title second, guards always\n")
-- =====================================================================
-- Scatter: macOS piled both onto the laptop screen.
safari._frame = { x = 10, y = 10, w = 800, h = 600 }
excel._frame  = { x = 40, y = 40, w = 900, h = 700 }

local moves = wr.plan(saved)
check("both scattered windows are planned home", #moves == 2, #moves)

check("a relaunched app (new id) is still caught by bundle + exact title", (function()
    local reborn = win(999, "com.microsoft.Excel", "Q3.xlsx", 40, 40, 900, 700)
    WINDOWS = { safari, reborn }
    local mv = wr.plan(saved)
    local hit = false
    for _, m in ipairs(mv) do if m.win == reborn then hit = true end end
    return #mv == 2 and hit
end)())

check("two same-titled windows get one frame EACH — matching consumes", (function()
    local twinsSaved = { entries = {
        { id = 1, bundle = "b", title = "Untitled", x = 0,   y = 0, w = 500, h = 500 },
        { id = 2, bundle = "b", title = "Untitled", x = 600, y = 0, w = 500, h = 500 },
    } }
    local wA = win(11, "b", "Untitled", 50, 50, 100, 100)
    local wB = win(12, "b", "Untitled", 60, 60, 100, 100)
    WINDOWS = { wA, wB }
    local mv = wr.plan(twinsSaved)
    return #mv == 2 and mv[1].win ~= mv[2].win
end)())

check("a frame off every current screen is skipped, never flung", (function()
    local ghost = { entries = {
        { id = 101, bundle = "com.apple.Safari", title = "Apple",
          x = 9000, y = 9000, w = 500, h = 500 },
    } }
    WINDOWS = { safari }
    return #wr.plan(ghost) == 0
end)())

check("a window already within minDriftPx is left alone", (function()
    local near = { entries = {
        { id = 101, bundle = "com.apple.Safari", title = "Apple",
          x = 11, y = 11, w = 801, h = 601 },
    } }
    WINDOWS = { safari }   -- sits at 10,10 800x600 — 4px total drift
    return #wr.plan(near) == 0
end)())

check("an unmatched saved window is skipped — never guessed at", (function()
    WINDOWS = { safari }   -- Excel is gone entirely
    local mv = wr.plan(saved)
    return #mv == 1 and mv[1].win == safari
end)())

-- =====================================================================
out("5. unplug, replug — the whole journey\n")
-- =====================================================================
WINDOWS = { safari, excel }
ALERTS = {}

-- unplug: macOS scatters, the watcher fires, the laptop setup settles
SCREENS = LAPTOP
safari._frame = { x = 10, y = 10, w = 800, h = 600 }
excel._frame  = { x = 40, y = 40, w = 900, h = 700 }
wr.watcher.fn()
check("a screen change pauses snapshots until settled", wr.transitioning == true)
drain()
check("after settling the laptop is the known setup", wr.lastSig == "UUID-A")
check("…and snapshots resume", wr.transitioning == false)
check("nothing was restored — the laptop had no memory yet, and the"
      .. " docked memory was NOT overwritten",
      safari.moved == 0 and wr.layouts["UUID-A+UUID-B"] ~= nil)

-- replug: the docked signature returns
SCREENS = DOCKED
wr.watcher.fn()
drain()
check("both windows snapped back to their docked frames",
      safari.moved == 1 and excel.moved == 1
      and safari._frame.x == 100 and excel._frame.x == 1600,
      safari._frame.x .. "," .. excel._frame.x)
check("…announced honestly", (function()
    for _, a in ipairs(ALERTS) do if a:find("2 windows returned", 1, true) then return true end end
    return false
end)(), table.concat(ALERTS, " | "))
check("a second settle on the SAME setup does nothing — restore fires on"
      .. " the transition, not on a timer", (function()
    local before = safari.moved
    wr.watcher.fn()
    drain()
    return safari.moved == before
end)())

-- =====================================================================
out("6. by hand, and by a fresh boot\n")
-- =====================================================================
ALERTS = {}
safari._frame = { x = 500, y = 500, w = 800, h = 600 }
check("_G.windowsBack() puts them back on demand", (function()
    local n = _G.windowsBack()
    return n == 1 and safari._frame.x == 100
end)())
ALERTS = {}
_G.windowsBack()
check("…and says so when there is nothing left to move", (function()
    for _, a in ipairs(ALERTS) do if a:find("already", 1, true) then return true end end
    return false
end)(), table.concat(ALERTS, " | "))

check("a fresh instance reads the layouts back from hs.settings", (function()
    local M2 = dofile(HS .. "/modules/window_return.lua")
    M2.setup(CORE)
    local wr2 = M2.wr
    return wr2.layouts["UUID-A+UUID-B"] ~= nil
end)())

-- =====================================================================
out("7. Accessibility off — stand down, stay honest\n")
-- =====================================================================
AX = false
ALERTS = {}
local M3 = dofile(HS .. "/modules/window_return.lua")
M3.setup(CORE)
check("no watcher and no timers without Accessibility",
      M3.wr.watcher == nil and M3.wr.snapTimer == nil)
check("_G.windowsBack still answers instead of silently failing", (function()
    local n = _G.windowsBack()
    for _, a in ipairs(ALERTS) do
        if a:find("Accessibility", 1, true) then return n == 0 end
    end
    return false
end)(), table.concat(ALERTS, " | "))
AX = true

-- =====================================================================
io.write(("\n%d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    io.write("FAILURES:\n")
    for _, f in ipairs(failures) do io.write("   ❌ " .. f .. "\n") end
    os.exit(1)
end
