-- =====================================================================
-- test_arranger.lua — the monitor jump that only half-worked (6.123.0)
-- =====================================================================
--     lua5.4 test_arranger.lua [/path/to/hammerspoon]
--
-- Executes modules/window_arranger.lua against a stubbed hs and drives
-- the REAL bindings. The window in the stub is a VLC: it ACCEPTS the
-- origin it is given and REFUSES the size, exactly as an aspect-locked
-- video window does, which is the behaviour that made ⇪[ and ⇪] land a
-- window hanging off the edge of the monitor with its sidebar sliced off.
--
-- What is proven here:
--   • a compliant window is not touched (the fix costs nothing normally)
--   • a window that kept its own size is pulled back onto the monitor
--   • a window WIDER THAN THE SCREEN keeps its top-left corner on screen —
--     the far edge is what overhangs, never the controls
--   • the alert tells the truth in all three cases, including when the
--     window refused to change monitor at all
--   • settleIntoScreen NEVER resizes — setTopLeft only

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local realPrint = print
local function out(s) io.write(s) end

-- ---- the stub Mac ------------------------------------------------------
local ALERTS   = {}
local BINDINGS = {}          -- "mods+key" -> fn
local SCREENS  = {}
local FOCUSED  = nil
local SETFRAME_CALLS, SETTOPLEFT_CALLS = 0, 0

local function makeScreen(name, x, y, w, h)
    local s = { _name = name, _f = { x = x, y = y, w = w, h = h } }
    function s:frame() return { x = self._f.x, y = self._f.y, w = self._f.w, h = self._f.h } end
    function s:name() return self._name end
    function s:toEast()
        for _, o in ipairs(SCREENS) do
            if o._f.x > self._f.x then return o end
        end
        return nil
    end
    function s:toWest()
        for _, o in ipairs(SCREENS) do
            if o._f.x < self._f.x then return o end
        end
        return nil
    end
    return s
end

-- A window with a personality. `refuseResize` makes it keep its own w/h
-- whatever it is asked for — the VLC behaviour. `refuseMove` makes
-- moveToScreen a no-op, the other half of "doesn't all the way work".
local function makeWindow(opts)
    opts = opts or {}
    local w = {
        _f = opts.frame or { x = 0, y = 0, w = 800, h = 600 },
        _screen = opts.screen,
        refuseResize = opts.refuseResize or false,
        refuseMove   = opts.refuseMove or false,
        _id = opts.id or 1,
    }
    function w:id() return self._id end
    function w:isStandard() return true end
    function w:isFullScreen() return false end
    function w:focus() end
    function w:raise() end
    function w:frame() return { x = self._f.x, y = self._f.y, w = self._f.w, h = self._f.h } end
    function w:screen() return self._screen end
    function w:setFrame(f)
        SETFRAME_CALLS = SETFRAME_CALLS + 1
        self._f.x, self._f.y = f.x, f.y
        if not self.refuseResize then self._f.w, self._f.h = f.w, f.h end
    end
    function w:setTopLeft(p)
        SETTOPLEFT_CALLS = SETTOPLEFT_CALLS + 1
        self._f.x, self._f.y = p.x, p.y
    end
    function w:maximize()
        local f = self._screen:frame()
        self:setFrame(f)
    end
    function w:moveToScreen(target)
        if self.refuseMove then return end
        -- What hs.window.moveToScreen actually does: scale the frame into
        -- the target screen proportionally, then set it. The window is then
        -- free to answer with something else, which is the whole point.
        local from, to = self._screen:frame(), target:frame()
        local nx = to.x + (self._f.x - from.x) * (to.w / from.w)
        local ny = to.y + (self._f.y - from.y) * (to.h / from.h)
        local nw = self._f.w * (to.w / from.w)
        local nh = self._f.h * (to.h / from.h)
        self._screen = target
        self:setFrame({ x = nx, y = ny, w = nw, h = nh })
    end
    function w:application() return { name = function() return opts.app or "VLC" end } end
    return w
end

hs = {
    window = {
        animationDuration = 0,
        focusedWindow = function() return FOCUSED end,
        orderedWindows = function() return {} end,
    },
    screen = { allScreens = function() return SCREENS end },
    hotkey = {
        bind = function(mods, key, fn)
            BINDINGS[table.concat(mods, "+") .. "+" .. key] = fn
            return { enable = function() end, disable = function() end }
        end,
    },
    alert  = { show = function(msg) ALERTS[#ALERTS + 1] = tostring(msg) end },
    timer  = { doAfter = function(_, fn) return { stop = function() end } end },
    chooser = { new = function(cb)
        local c = { _cb = cb }
        function c:choices(x) self._choices = x end
        function c:placeholderText() end
        function c:query() end
        function c:show() end
        return c
    end },
    application = { runningApplications = function() return {} end,
                    applicationForPID = function() return nil end },
    fnutils = {},
    settings = { get = function() return nil end, set = function() end },
}
_G.choosers = {}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.service = {
    registry = {}, owner = {},
    provide = function(n, f) _G.service.registry[n] = f end,
    has     = function(n) return _G.service.registry[n] ~= nil end,
    call    = function(n, ...)
        local f = _G.service.registry[n]
        if not f then return nil end
        return f(...)
    end,
}

local core = {
    provide = function(n, f) _G.service.provide(n, f) end,
    call    = function(n, ...) return _G.service.call(n, ...) end,
    resolveBaseScreen = function() return SCREENS[1] end,
    showPopup = function() end,
    logsDir = "/tmp", hostTag = "test",
    csvQuote = function(s) return '"' .. tostring(s):gsub('"', '""') .. '"' end,
    formatDuration = function(s) return tostring(s) .. "s" end,
}

-- ---- load the real module ---------------------------------------------
local chunk = assert(loadfile(HS .. "/modules/window_arranger.lua"))
local M = chunk()
M.setup(core)

local settle = _G.service.registry["windows.settle"]

out("\n== 1. THE SETTLE ITSELF ==\n")
check("the module publishes windows.settle", type(settle) == "function")

local mon = makeScreen("Studio Display", 0, 0, 2560, 1440)
SCREENS = { mon }

do
    -- A window entirely inside the monitor must not be touched at all.
    local before = SETTOPLEFT_CALLS
    local w = makeWindow({ frame = { x = 100, y = 100, w = 800, h = 600 }, screen = mon })
    local fits = settle(w, mon)
    check("a window already inside the monitor reports fitting", fits == true)
    check("...and is not moved — the fix costs a compliant window nothing",
          SETTOPLEFT_CALLS == before and w._f.x == 100 and w._f.y == 100)
end

do
    -- 🎬 THE VLC CASE. The window hangs off the RIGHT edge.
    local w = makeWindow({ frame = { x = 2000, y = 100, w = 1200, h = 800 }, screen = mon })
    local fits = settle(w, mon)
    check("a window hanging off the right edge is pulled back on", fits == true)
    check("...to exactly flush with the right edge, not further",
          w._f.x == 2560 - 1200, w._f.x)
    check("...and its SIZE is untouched — settle never resizes",
          w._f.w == 1200 and w._f.h == 800)
end

do
    -- The screenshot LL sent: sidebar sliced off the LEFT edge.
    local w = makeWindow({ frame = { x = -300, y = 50, w = 1200, h = 800 }, screen = mon })
    local fits = settle(w, mon)
    check("a window hanging off the LEFT edge is pulled back on", fits == true)
    check("...flush with the left edge, so the sidebar is visible again",
          w._f.x == 0, w._f.x)
end

do
    local w = makeWindow({ frame = { x = 100, y = 1200, w = 800, h = 600 }, screen = mon })
    settle(w, mon)
    check("a window hanging off the bottom is lifted", w._f.y == 1440 - 600, w._f.y)
end

do
    -- 🚨 THE ORDER-OF-CLAMPS RULE. A window WIDER than the screen cannot
    -- fit. What matters is WHICH edge is sacrificed: the far one, so the
    -- title bar and the left-hand controls stay reachable.
    local w = makeWindow({ frame = { x = 900, y = 900, w = 3000, h = 2000 }, screen = mon })
    local fits = settle(w, mon)
    check("a window bigger than the monitor reports that it does NOT fit",
          fits == false)
    check("...but its top-left corner is anchored ON the monitor",
          w._f.x == 0 and w._f.y == 0, w._f.x .. "," .. w._f.y)
    check("...and it was still not resized — the app would only fight back",
          w._f.w == 3000 and w._f.h == 2000)
end

do
    check("settle on a nil window is false, not a crash", settle(nil, mon) == false)
    check("settle on a nil screen is false, not a crash",
          settle(makeWindow({ screen = mon }), nil) == false)
end

out("\n== 2. ⇪[ / ⇪] ACROSS TWO MONITORS ==\n")

local left  = makeScreen("Laptop", 0, 0, 1440, 900)
local right = makeScreen("Studio Display", 1440, 0, 2560, 1440)
SCREENS = { left, right }

local jumpWest = BINDINGS["ctrl+alt+cmd+["]
local jumpEast = BINDINGS["ctrl+alt+cmd+]"]
check("⌃⌥⌘[ is bound", type(jumpWest) == "function")
check("⌃⌥⌘] is bound", type(jumpEast) == "function")

do
    -- A well-behaved window: moves and scales, lands inside, alert is plain.
    ALERTS = {}
    FOCUSED = makeWindow({ frame = { x = 1440, y = 0, w = 1280, h = 720 },
                           screen = right, app = "Sublime Text" })
    jumpWest()
    check("a compliant window changes monitor", FOCUSED._screen == left)
    check("...and lands fully inside it",
          FOCUSED._f.x >= 0 and FOCUSED._f.x + FOCUSED._f.w <= 1440,
          FOCUSED._f.x .. " + " .. FOCUSED._f.w)
    check("...with the plain success alert",
          ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("→ Laptop", 1, true) ~= nil,
          ALERTS[#ALERTS])
    check("...and no overhang warning",
          ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("overhangs", 1, true) == nil)
end

do
    -- 🎬 VLC: refuses to shrink, so the scaled origin plus its own width
    -- puts it off the edge of the smaller monitor. THE BUG.
    ALERTS = {}
    FOCUSED = makeWindow({ frame = { x = 2600, y = 100, w = 1300, h = 900 },
                           screen = right, refuseResize = true, app = "VLC" })
    jumpWest()
    check("VLC changes monitor", FOCUSED._screen == left)
    check("🚨 ...and is NOT left hanging off the monitor — the 6.123.0 fix",
          FOCUSED._f.x >= 0 and FOCUSED._f.x + FOCUSED._f.w <= 1440,
          "x=" .. FOCUSED._f.x .. " w=" .. FOCUSED._f.w)
    check("...it kept the size it insisted on", FOCUSED._f.w == 1300)
end

do
    -- A window that will not move at all must not be congratulated.
    ALERTS = {}
    FOCUSED = makeWindow({ frame = { x = 1440, y = 0, w = 800, h = 600 },
                           screen = right, refuseMove = true, app = "VLC" })
    jumpWest()
    check("🚨 a window that refused the move is NOT reported as moved",
          ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("would not move", 1, true) ~= nil,
          ALERTS[#ALERTS])
    check("...and the success arrow is absent from that alert",
          ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("→", 1, true) == nil)
end

do
    -- Too big for the target monitor: moved, anchored, and SAID SO.
    ALERTS = {}
    FOCUSED = makeWindow({ frame = { x = 1440, y = 0, w = 2200, h = 1300 },
                           screen = right, refuseResize = true, app = "VLC" })
    jumpWest()
    check("a window too big for the target still changes monitor",
          FOCUSED._screen == left)
    check("🚨 ...and the alert admits the overhang instead of claiming success",
          ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("overhangs", 1, true) ~= nil,
          ALERTS[#ALERTS])
    check("...with its corner on the monitor so it can still be grabbed",
          FOCUSED._f.x == 0 and FOCUSED._f.y == 0)
end

do
    ALERTS = {}
    SCREENS = { left }
    FOCUSED = makeWindow({ frame = { x = 0, y = 0, w = 800, h = 600 }, screen = left })
    jumpEast()
    check("with one monitor connected it says so and does nothing",
          ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("Only one monitor", 1, true) ~= nil)
    SCREENS = { left, right }
end

out("\n== 3. THE HALVES USE THE SAME SETTLE ==\n")

do
    local half = BINDINGS["ctrl+alt+Right"]
    check("⌃⌥→ is bound", type(half) == "function")
    -- Right half of the laptop screen = x 720, w 720. VLC keeps 1300 wide,
    -- so without settling it would run to x=2020 — 580px off the edge.
    FOCUSED = makeWindow({ frame = { x = 0, y = 0, w = 1300, h = 800 },
                           screen = left, refuseResize = true, app = "VLC" })
    half()
    check("🚨 a right-half snap that the app resized out of bounds is settled back",
          FOCUSED._f.x + FOCUSED._f.w <= 1440,
          "x=" .. FOCUSED._f.x .. " w=" .. FOCUSED._f.w)
end

out("\n== 4. BREAK TESTS — proving the checks have teeth ==\n")

do
    -- 🔨 BREAK 1: clamp left/top FIRST instead of last. For a window that
    -- fits this changes nothing; for an oversized one it anchors the WRONG
    -- corner — the far edge on screen, the title bar off it. If section 1's
    -- oversized check cannot see that, it is decoration.
    local function brokenSettle(w, s)
        local f, sf = w:frame(), s:frame()
        local x, y = f.x, f.y
        if x < sf.x then x = sf.x end
        if y < sf.y then y = sf.y end
        if x + f.w > sf.x + sf.w then x = sf.x + sf.w - f.w end
        if y + f.h > sf.y + sf.h then y = sf.y + sf.h - f.h end
        w:setTopLeft({ x = x, y = y })
        local a = w:frame()
        return a.x >= sf.x and a.y >= sf.y
    end
    local w = makeWindow({ frame = { x = 900, y = 900, w = 3000, h = 2000 }, screen = mon })
    brokenSettle(w, mon)
    check("🔨 BREAK 1: clamping in the wrong order anchors the wrong corner, "
          .. "and the oversized check catches it",
          not (w._f.x == 0 and w._f.y == 0),
          w._f.x .. "," .. w._f.y)
end

do
    -- 🔨 BREAK 2: trust the request instead of re-reading the frame. This is
    -- the ACTUAL bug — it is what moveToScreen's ensureInScreenBounds does.
    -- Clamp the rectangle you are about to ask for, then let the app resize
    -- afterwards, and the window ends up off the edge with nothing noticing.
    -- The clamp uses the SCALED-DOWN width it is about to request. That is
    -- the arithmetic that makes the bug: the origin is chosen for a small
    -- window, the app then keeps a large one, and the difference hangs off
    -- the edge.
    local function blindSettle(w, s)
        local f, sf = w:frame(), s:frame()
        local want = { x = f.x, y = f.y, w = 400, h = 300 }   -- what moveToScreen asks for
        if want.x + want.w > sf.x + sf.w then want.x = sf.x + sf.w - want.w end
        if want.x < sf.x then want.x = sf.x end
        w:setFrame(want)   -- the app accepts the origin and refuses the size
        return true        -- and we believe our own request
    end
    local w = makeWindow({ frame = { x = 1200, y = 0, w = 1300, h = 800 },
                           screen = left, refuseResize = true })
    local claimed = blindSettle(w, left)
    check("🔨 BREAK 2: believing the request instead of re-reading leaves the "
          .. "window off the edge while reporting success",
          claimed == true and (w._f.x + w._f.w) > 1440,
          "x=" .. w._f.x .. " w=" .. w._f.w)
    -- ...and the real one fixes exactly that window.
    settle(w, left)
    check("...and the real settle, run on that same window, brings it back",
          w._f.x + w._f.w <= 1440)
end

do
    -- 🔨 BREAK 3: a settle that resizes. It "fits" — and it has picked a
    -- fight with an aspect-locked window that will bounce back, or worse,
    -- silently shrunk a window the user sized on purpose.
    local before = SETFRAME_CALLS
    local w = makeWindow({ frame = { x = 2000, y = 0, w = 1200, h = 800 }, screen = mon })
    settle(w, mon)
    check("🔨 BREAK 3: the real settle calls setFrame ZERO times — it moves "
          .. "with setTopLeft only",
          SETFRAME_CALLS == before, SETFRAME_CALLS - before)
end

-- ---- report -------------------------------------------------------------
out("\n")
-- The runner greps for "N passed, M failed" — print it in that exact shape
-- whatever the outcome, or a green suite is reported as one that crashed.
if fail == 0 then
    out(string.format("✅ test_arranger: %d passed, %d failed\n", pass, fail))
else
    out(string.format("❌ test_arranger: %d passed, %d failed\n", pass, fail))
    for _, f in ipairs(failures) do out("   • " .. f .. "\n") end
end
os.exit(fail == 0 and 0 or 1)
