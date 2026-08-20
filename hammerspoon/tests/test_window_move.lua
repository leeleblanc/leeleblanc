-- =====================================================================
-- test_window_move.lua — ⌘-drag any panel, drag the pickers, commit
-- =====================================================================
--     lua5.4 test_window_move.lua [/path/to/hammerspoon]
--
-- Executes modules/window_move.lua against a stubbed hs and drives the
-- REAL tap callback with synthetic mouse events: hit rules (⌘ vs plain,
-- inside vs outside), the drag engine's offset math, the chooser
-- re-anchor through chooser:show(pt), the popupOffset commit on drop,
-- and the five-strikes stand-down that protects the mouse.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- ---- the stub Mac ------------------------------------------------------
local MOUSE   = { x = 0, y = 0 }     -- what hs.mouse reports
local BUTTONS = {}                    -- what checkMouseButtons reports
local TIMERS  = {}                    -- every doEvery, tickable by hand
local TAP     = nil                   -- the one mouse tap the module makes

hs = {
    chooser = {},                     -- module installs globalCallback here
    eventtap = {
        event = { types = { leftMouseDown = 1, keyDown = 10, keyUp = 11 } },
        new = function(types, cb)
            TAP = { types = types, cb = cb, started = false }
            function TAP:start() self.started = true end
            function TAP:stop()  self.started = false end
            return TAP
        end,
        checkMouseButtons = function() return BUTTONS end,
    },
    mouse = { absolutePosition = function() return { x = MOUSE.x, y = MOUSE.y } end },
    timer = {
        doEvery = function(secs, fn)
            local t = { fn = fn, secs = secs, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    geometry = { point = function(x, y) return { x = x, y = y } end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

-- a chained callback installed BEFORE the module loads must keep firing
local PREV_CALLS = {}
hs.chooser.globalCallback = function(ch, state)
    PREV_CALLS[#PREV_CALLS + 1] = state
end

local PROVIDED = {}
local CORE = { provide = function(n, f) PROVIDED[n] = f end }

local function evt(x, y, flags)
    return {
        location = function() return { x = x, y = y } end,
        getFlags = function() return flags or {} end,
    }
end

-- press at (x, y) with flags; returns whether the tap CONSUMED the click
local function press(x, y, flags)
    MOUSE.x, MOUSE.y = x, y
    BUTTONS = { left = true }
    return TAP.cb(evt(x, y, flags))
end

local function lastTimer() return TIMERS[#TIMERS] end
local function tick() local t = lastTimer(); if t and not t.stopped then t.fn() end end
local function releaseAndTick() BUTTONS = {} tick() end

-- =====================================================================
out("── Window Move: hit rules, drag engine, chooser commit ──\n")
out("\n1. contract & wiring\n")
-- =====================================================================
local M = dofile(HS .. "/modules/window_move.lua")
check("module loads and has setup()", type(M.setup) == "function")
check("cheatsheet block present", type(M.cheatsheet) == "table"
      and #M.cheatsheet.entries >= 4)
M.setup(CORE)
local wm = _G.windowMove
check("module table exported", type(wm) == "table")
check("the mouse tap is up", TAP ~= nil and TAP.started == true)
check("…and listens for leftMouseDown only",
      #TAP.types == 1 and TAP.types[1] == 1)
check("the registry exists and is shared", type(_G.movablePanels) == "table")
check("_G.beginPanelDrag is published", type(_G.beginPanelDrag) == "function")
check("…and through the service registry too",
      type(PROVIDED["windowMove.drag"]) == "function")

-- =====================================================================
out("2. hit rules — ⌘ vs plain, inside vs outside\n")
-- =====================================================================
local MOVED_A = {}
table.insert(_G.movablePanels, {
    name  = "a",
    frame = function() return { x = 100, y = 100, w = 200, h = 150 } end,
    move  = function(x, y) MOVED_A[#MOVED_A + 1] = { x = x, y = y } end,
})
local MOVED_B = {}
table.insert(_G.movablePanels, {
    name  = "b", plain = true,
    frame = function() return { x = 600, y = 400, w = 100, h = 80 } end,
    move  = function(x, y) MOVED_B[#MOVED_B + 1] = { x = x, y = y } end,
})

check("a plain click over nothing passes through",
      press(50, 50) == false)
check("a plain click ON a ⌘-panel passes through (its clicks are its own)",
      press(150, 120) == false)
check("⌘⇧-click passes through — only bare ⌘ means 'move the window'",
      press(150, 120, { cmd = true, shift = true }) == false)
check("⌘-click over nothing passes through (no chooser open)",
      press(50, 50, { cmd = true }) == false)
check("nothing has moved yet", #MOVED_A == 0 and #MOVED_B == 0)

-- =====================================================================
out("3. the drag engine — grab offset, follow, release\n")
-- =====================================================================
check("⌘-click ON the panel is consumed",
      press(150, 120, { cmd = true }) == true)
check("…and a follow timer is running",
      lastTimer() ~= nil and lastTimer().stopped == false)
-- grabbed at (150,120) with the panel at (100,100): offset (50,20).
MOUSE.x, MOUSE.y = 170, 140
tick()
check("the panel moves WITH the pointer, offset held",
      #MOVED_A == 1 and MOVED_A[1].x == 120 and MOVED_A[1].y == 120,
      MOVED_A[1] and (MOVED_A[1].x .. "," .. MOVED_A[1].y))
MOUSE.x, MOUSE.y = 90, 95
tick()
check("…every tick, any direction",
      #MOVED_A == 2 and MOVED_A[2].x == 40 and MOVED_A[2].y == 75)
releaseAndTick()
check("button up ends the drag and stops the timer",
      lastTimer().stopped == true)
MOUSE.x, MOUSE.y = 500, 500
tick()
check("…and nothing follows the mouse afterwards", #MOVED_A == 2)

check("a plain=true panel drags with NO ⌘ at all",
      press(650, 430, {}) == true)
MOUSE.x, MOUSE.y = 660, 450
tick()
check("…and follows (offset from its own frame)",
      #MOVED_B == 1 and MOVED_B[1].x == 610 and MOVED_B[1].y == 420,
      MOVED_B[1] and (MOVED_B[1].x .. "," .. MOVED_B[1].y))
releaseAndTick()

check("a new drag tears the old one down first", (function()
    press(150, 120, { cmd = true })
    local first = lastTimer()
    BUTTONS = { left = true }            -- still held; grab B directly
    TAP.cb(evt(650, 430, {}))
    return first.stopped == true and lastTimer() ~= first
end)())
releaseAndTick()

check("a throwing frame() skips that panel, harming nothing", (function()
    table.insert(_G.movablePanels, 1, {
        name = "broken", frame = function() error("boom") end,
        move = function() end,
    })
    local took = press(150, 120, { cmd = true })   -- still lands on panel a
    releaseAndTick()
    table.remove(_G.movablePanels, 1)
    return took == true
end)())

-- =====================================================================
out("4. the pickers — grab, re-anchor live, COMMIT on drop\n")
-- =====================================================================
local CH = { shownAt = {} }
function CH:show(pt) self.shownAt[#self.shownAt + 1] = pt end
function CH:width() return 40 end
function CH:rows() return 10 end

check("the module chained the pre-existing globalCallback",
      type(hs.chooser.globalCallback) == "function")
hs.chooser.globalCallback(CH, "willOpen")
check("…which still receives events through the chain",
      PREV_CALLS[#PREV_CALLS] == "willOpen")
check("the open chooser is tracked", wm.openChooser == CH)

_G.popupOffset        = { x = 0, y = 0 }
_G.lastPopupPlacement = {
    point  = { x = 300, y = 200 },
    screen = { frame = function() return { x = 0, y = 0, w = 1000, h = 800 } end },
}
local SYNCS = 0
_G.taskMirrorSync = function() SYNCS = SYNCS + 1 end

check("⌘-click INSIDE the picker's computed box is consumed",
      press(400, 300, { cmd = true }) == true)
MOUSE.x, MOUSE.y = 430, 340
tick()
check("the picker re-anchors live through chooser:show(pt)",
      #CH.shownAt == 1 and CH.shownAt[1].x == 330 and CH.shownAt[1].y == 240,
      CH.shownAt[1] and (CH.shownAt[1].x .. "," .. CH.shownAt[1].y))
releaseAndTick()
check("the drop is COMMITTED to popupOffset — the position sticks",
      _G.popupOffset.x == 30 and _G.popupOffset.y == 40,
      _G.popupOffset.x .. "," .. _G.popupOffset.y)
check("…and the placement record moved with it",
      _G.lastPopupPlacement.point.x == 330
      and _G.lastPopupPlacement.point.y == 240)
check("…and the picker's companions were re-synced", SYNCS == 1)

check("⌘-click far OUTSIDE the picker's box still belongs to the Mac",
      press(50, 700, { cmd = true }) == false)

hs.chooser.globalCallback(CH, "didClose")
check("didClose forgets the chooser", wm.openChooser == nil)
check("…after which ⌘-clicks pass through again",
      press(400, 300, { cmd = true }) == false)

-- =====================================================================
out("4b. the search band — a picker drags with a BARE click-hold (6.102.0)\n")
-- =====================================================================
-- Geometry used throughout: placement point (300,200), width 40% of a
-- 1000-wide screen → the TIGHT strip is x 300..700, y 200..256. The box
-- around it keeps its 24px margin; the strip must not.
hs.chooser.globalCallback(CH, "willOpen")
_G.popupOffset        = { x = 0, y = 0 }
_G.lastPopupPlacement = {
    point  = { x = 300, y = 200 },
    screen = { frame = function() return { x = 0, y = 0, w = 1000, h = 800 } end },
}
local shownBefore = #CH.shownAt

check("a bare click-hold ON the search band is consumed — no ⌘ needed",
      press(450, 210) == true)
MOUSE.x, MOUSE.y = 480, 230
tick()
check("…and the picker follows, same engine, offset held",
      #CH.shownAt == shownBefore + 1
      and CH.shownAt[#CH.shownAt].x == 330
      and CH.shownAt[#CH.shownAt].y == 220,
      CH.shownAt[#CH.shownAt]
      and (CH.shownAt[#CH.shownAt].x .. "," .. CH.shownAt[#CH.shownAt].y))
releaseAndTick()
check("…and the drop commits to popupOffset, exactly like a ⌘ drag",
      _G.popupOffset.x == 30 and _G.popupOffset.y == 20,
      _G.popupOffset.x .. "," .. _G.popupOffset.y)

check("a bare click on the ROWS below the band still means 'pick this one'",
      press(450, 300) == false)
check("a bare click in the box's margin (outside the tight strip) passes through",
      press(450, 190) == false)

-- A declined ⌘-click must leave evidence in the diag trail — that line
-- is how the NEXT "I can't move this" report gets diagnosed.
local SAID = {}
_G.diag = { say  = function(_, m) SAID[#SAID + 1] = tostring(m) end,
            warn = function() end, err = function() end }
check("a ⌘-click outside the box is declined…",
      press(50, 700, { cmd = true }) == false)
check("…and says so in the diag trail, box included", (function()
    for _, m in ipairs(SAID) do
        if m:find("declined", 1, true) and m:find("box", 1, true) then
            return true
        end
    end
    return false
end)(), table.concat(SAID, " | "))
_G.diag = { say = function() end, warn = function() end, err = function() end }
hs.chooser.globalCallback(CH, "didClose")
check("the band is dead once the picker is closed", press(450, 210) == false)

-- =====================================================================
out("4c. 🚨 A RECORD FOR ANOTHER PICKER IS NOT A BOX (6.127.0)\n")
-- =====================================================================
-- LL: "The screenshot is a picker window I can't grab and move. Why?"
--
-- Because _G.lastPopupPlacement is ONE global record and the grab box is
-- computed from it. Fourteen modules opened their picker with a bare
-- chooser:show(), which records nothing — so the record still described
-- whichever picker ran showPopup LAST. The ⌘-click on the picker actually
-- on screen fell outside that stale box and was DECLINED, even though the
-- code is written to fall back to a jump-to-hand grab when there is NO
-- box. Those pickers could not be moved at all, in silence.
--
-- The record now names its chooser, and one that does not match the open
-- picker is treated as no record — which is the path that works.
local OTHER = { shownAt = {} }
function OTHER:show(pt) self.shownAt[#self.shownAt + 1] = pt end
function OTHER:width() return 40 end
function OTHER:rows() return 10 end

hs.chooser.globalCallback(CH, "willOpen")
_G.popupOffset        = { x = 0, y = 0 }
_G.lastPopupPlacement = {
    point   = { x = 300, y = 200 },
    screen  = { frame = function() return { x = 0, y = 0, w = 1000, h = 800 } end },
    chooser = OTHER,                     -- a DIFFERENT picker's placement
}
check("🚨 a placement belonging to another picker yields NO box",
      wm.chooserBox() == nil)
check("…and the reason is on the record, in words",
      type(wm.boxWhy) == "string"
      and wm.boxWhy:find("different picker", 1, true) ~= nil, wm.boxWhy)

local shownCH = #CH.shownAt
check("🚨 …so the ⌘-drag GRABS BY HAND instead of being declined",
      press(400, 300, { cmd = true }) == true)
MOUSE.x, MOUSE.y = 420, 320
tick()
check("…and the picker that is actually open is the one that moves",
      #CH.shownAt == shownCH + 1 and #OTHER.shownAt == 0)
releaseAndTick()

check("⚠️ the band strip is NOT offered against a stale record — a bare"
      .. " click there would have moved nothing", press(450, 210) == false)

-- The matching case still works exactly as before.
_G.lastPopupPlacement = {
    point   = { x = 300, y = 200 },
    screen  = { frame = function() return { x = 0, y = 0, w = 1000, h = 800 } end },
    chooser = CH,
}
check("a placement naming the OPEN picker computes a box as usual",
      (function()
    local b = wm.chooserBox()
    return b ~= nil and b.x == 300 - wm.chooserPad and b.y == 200 - wm.chooserPad,
           b and (b.x .. "," .. b.y)
end)())
check("…and the band drags again", press(450, 210) == true)
releaseAndTick()

-- ⚠️ A record with NO chooser named is a pre-6.127.0 caller. It is
-- trusted, because refusing it would break every picker that has not been
-- converted yet — the guard fires only on a POSITIVE mismatch.
_G.lastPopupPlacement = {
    point  = { x = 300, y = 200 },
    screen = { frame = function() return { x = 0, y = 0, w = 1000, h = 800 } end },
}
check("a record with no chooser named is still trusted (older caller)",
      wm.chooserBox() ~= nil)

-- =====================================================================
out("4d. the report that did not exist\n")
-- =====================================================================
-- 🚨 THIS MODULE FAILS SILENTLY BY DESIGN — a declined ⌘-click cannot
-- make a noise, because the click belongs to the app underneath. It was
-- the only module in the config with no report, which is why "I can't
-- move this one" had no answer anywhere.
check("_G.windowMoveReport is published", type(_G.windowMoveReport) == "function")
check("…and through the service registry too",
      type(PROVIDED["windowMove.report"]) == "function")

_G.lastPopupPlacement = {
    point   = { x = 300, y = 200 },
    screen  = { frame = function() return { x = 0, y = 0, w = 1000, h = 800 } end },
    chooser = OTHER,
}
-- ⚠️ CALLED THROUGH pcall AND DEFAULTED TO "". A missing report must fail
-- the checks below, not explode the suite — a crash here would take
-- sections 5 and 6 down with it and hide whatever they had to say.
local rep = ""
if type(_G.windowMoveReport) == "function" then
    local okR, r = pcall(_G.windowMoveReport)
    rep = (okR and type(r) == "string") and r or ""
end
check("the report is text and names the module", type(rep) == "string"
      and rep:find("WINDOW MOVE", 1, true) ~= nil)
check("🚨 it says the placement belongs to ANOTHER picker — the whole"
      .. " point of the report", rep:find("ANOTHER picker", 1, true) ~= nil, rep)
check("…and that showPopup is the missing call",
      rep:find("core.showPopup", 1, true) ~= nil)
check("it says whether the tap is up", rep:find("tap", 1, true) ~= nil)
check("…and counts the registered panels",
      rep:find("panels", 1, true) ~= nil)
check("it names the last refusal, with coordinates", (function()
    -- section 4b declined a ⌘-click at 50,700
    return rep:find("last refusal", 1, true) ~= nil
       and rep:find("50,700", 1, true) ~= nil
end)(), rep)
check("…and when there is no box it says the band cannot be found",
      rep:find("SEARCH BAND cannot be", 1, true) ~= nil)

check("the report survives an empty world", (function()
    if type(_G.windowMoveReport) ~= "function" then return false, "no report" end
    local savedPanels, savedPlace = _G.movablePanels, _G.lastPopupPlacement
    _G.movablePanels, _G.lastPopupPlacement = {}, nil
    hs.chooser.globalCallback(CH, "didClose")
    local ok, r = pcall(_G.windowMoveReport)
    _G.movablePanels, _G.lastPopupPlacement = savedPanels, savedPlace
    return ok and type(r) == "string" and r:find("none on record", 1, true) ~= nil,
           ok and r or r
end)())
hs.chooser.globalCallback(CH, "didClose")

-- =====================================================================
out("5. the header hook — _G.beginPanelDrag(name)\n")
-- =====================================================================
MOUSE.x, MOUSE.y = 150, 120
BUTTONS = { left = true }
check("beginPanelDrag drags a listed panel by name",
      _G.beginPanelDrag("a") == true)
MOUSE.x, MOUSE.y = 160, 135
tick()
check("…with the same engine and offset math",
      MOVED_A[#MOVED_A].x == 110 and MOVED_A[#MOVED_A].y == 115)
releaseAndTick()
check("an unknown name refuses politely", _G.beginPanelDrag("nope") == false)

-- =====================================================================
out("6. five strikes and the tap stands down, mouse untouched\n")
-- =====================================================================
local realOnMouseDown = wm.onMouseDown
wm.onMouseDown = function() error("deliberate test explosion") end
local consumedDuringFailure = false
for _ = 1, 5 do
    if TAP.cb(evt(10, 10, {})) == true then consumedDuringFailure = true end
end
check("a failing callback NEVER consumes the click", not consumedDuringFailure)
check("five consecutive errors stop the tap", TAP.started == false)
check("…and say so in the Console", (function()
    for _, l in ipairs(printed) do
        if l:find("STOPPED", 1, true) then return true end
    end
    return false
end)())
wm.onMouseDown = realOnMouseDown

-- =====================================================================
io.write(("\n%d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    io.write("FAILURES:\n")
    for _, f in ipairs(failures) do io.write("   ❌ " .. f .. "\n") end
    os.exit(1)
end
