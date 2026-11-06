-- =====================================================================
-- test_right_click.lua — ⇪⇧F posts a real right-click, unmodified
-- =====================================================================
--     lua5.4 test_right_click.lua [/path/to/hammerspoon]
--
-- Executes modules/right_click.lua against a stubbed hs and inspects the
-- events it actually posts.
--
-- Section 3 is the one with teeth. ⇪⇧F means ⇧ is physically down at the
-- moment the key fires, and a context menu reads the modifiers held when
-- it OPENS: ⇧ gives you Chrome's own menu instead of the page's, ⌥ gives
-- you Finder's alternate items. A click posted on the keypress therefore
-- opens the wrong menu every single time, which is indistinguishable
-- from the feature being half-built. Every check there fails if the
-- settle wait or the empty flags are removed.

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

local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- ---- the stub Mac ------------------------------------------------------
local MOUSE    = { x = 100, y = 200 }
local MODS     = {}            -- what checkKeyboardModifiers reports
local AX       = true          -- accessibility granted?
local POSTED   = {}            -- every mouse event posted
local ALERTS   = {}
local TIMERS   = {}
local FRONT    = "Finder"
local NEWMOUSE_FAILS  = false  -- pretend this hs build has no setFlags
local RIGHTCLICK_CALLS = 0
local MOVES    = 0             -- how many times the pointer was moved

local TYPES = { rightMouseDown = 3, rightMouseUp = 4 }

local function makeEvent(t, point, mods)
    local ev = { type = t, point = { x = point.x, y = point.y },
                 mods = mods, flags = nil, posted = false }
    function ev:setFlags(f)
        if NEWMOUSE_FAILS then error("no setFlags on this build") end
        self.flags = f ; return self
    end
    function ev:post() self.posted = true ; POSTED[#POSTED + 1] = self ; return self end
    return ev
end

-- 🎯 6.409.0 — THE AX TREE, AND IT ANSWERS THE WAY A MAC DOES.
-- SELECTION is what the focused element hands back; FRAME is where that
-- row is. Either can be absent, and a stub where they never are is a
-- stub that cannot see the branch each absence takes (6.290.0).
local SELECTION   = nil   -- the frame AXFrame would answer, or nil
local SEL_ATTR    = "AXSelectedRows"   -- which attribute carries it
local SEL_VIA     = "AXFrame"          -- AXFrame | AXPosition | none
local HAS_AX      = true
local AX_ASKED    = {}

local function axElement(attrs)
    local e = { timeout = nil }
    function e:setTimeout(t) self.timeout = t ; return self end
    function e:attributeValue(a)
        AX_ASKED[#AX_ASKED + 1] = a
        return attrs[a]
    end
    return e
end

local function axRow()
    local f = SELECTION
    local attrs = {}
    if SEL_VIA == "AXFrame" then
        attrs.AXFrame = f
    elseif SEL_VIA == "AXPosition" then
        attrs.AXPosition = f and { x = f.x, y = f.y } or nil
        attrs.AXSize     = f and { w = f.w, h = f.h } or nil
    end
    return axElement(attrs)
end

hs = {
    -- 🖱 A SETTER AS WELL AS A GETTER. hs.mouse.absolutePosition(p) MOVES
    -- the pointer; a getter-only stub lets every "it went to the
    -- selection" check pass while nothing moves (6.227.0 · 6.239.0 ·
    -- 6.247.0 · 6.251.0 — the fifth time that shape has hidden a whole
    -- feature in this project).
    mouse = {
        absolutePosition = function(p)
            if type(p) == "table" and p.x and p.y then
                MOUSE = { x = p.x, y = p.y }
                MOVES = MOVES + 1
                return nil
            end
            return { x = MOUSE.x, y = MOUSE.y }
        end,
    },
    axuielement = {
        applicationElement = function()
            if not HAS_AX then error("no AX element") end
            local attrs = {}
            attrs.AXFocusedUIElement = axElement({
                [SEL_ATTR] = SELECTION and { axRow() } or nil,
                AXSelected = false,
            })
            return axElement(attrs)
        end,
    },
    accessibilityState = function() return AX end,
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    application = {
        frontmostApplication = function()
            return { name = function() return FRONT end }
        end,
    },
    eventtap = {
        event = { types = TYPES, newMouseEvent = makeEvent },
        checkKeyboardModifiers = function() return MODS end,
        rightClick = function(p)
            RIGHTCLICK_CALLS = RIGHTCLICK_CALLS + 1
            POSTED[#POSTED + 1] = { type = TYPES.rightMouseDown, point = p,
                                    viaRightClick = true }
        end,
    },
    timer = {
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false, every = true }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        -- 🪜 6.409.0 — the beat between moving the pointer and clicking.
        -- Held in its own slot, and the suite fires it by hand.
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false, every = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local BOUND, PROVIDED = {}, {}
local CORE = {
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local chunk = assert(loadfile(HS .. "/modules/right_click.lua"))
local M = chunk()
M.setup(CORE)
local rc = _G.rightClick

local function reset()
    POSTED, ALERTS, TIMERS = {}, {}, {}
    RIGHTCLICK_CALLS = 0
    rc.fires = 0
    rc.blind = 0
    rc.lastBlind = nil
    rc.lastNote = nil
    if rc.settleTimer then rc.settleTimer = nil end
end

-- Run the settle timer until it stops itself, or n ticks pass.
local function runTimers(n)
    for _ = 1, (n or 40) do
        local t = TIMERS[#TIMERS]
        if not t or t.stopped then return end
        t.fn()
    end
end

out("\n=== 1. it loads and binds ===\n")
check("the module returns a table with a name", M.name == "Right Click")
check("it declares a family", M.family == "windows")
check("⇪⇧F is bound", BOUND["shift+f"] ~= nil)
check("the binding is attributed to this module",
      BOUND["shift+f"] and BOUND["shift+f"].src == "right click")
check("it publishes _G.rightClick", type(rc) == "table")
check("two services are published",
      PROVIDED["rightClick.click"] and PROVIDED["rightClick.report"])

out("\n=== 2. the plain case: nothing held, click now ===\n")
reset()
MODS = {}
check("it reports success", rc.click() == true)
check("exactly two events were posted", #POSTED == 2, #POSTED)
check("a rightMouseDown", POSTED[1] and POSTED[1].type == TYPES.rightMouseDown)
check("then a rightMouseUp", POSTED[2] and POSTED[2].type == TYPES.rightMouseUp)
check("both at the pointer", POSTED[1].point.x == 100 and POSTED[1].point.y == 200
      and POSTED[2].point.x == 100 and POSTED[2].point.y == 200)
check("no timer was armed — there was nothing to wait for", #TIMERS == 0, #TIMERS)
check("the fire was counted", rc.fires == 1, rc.fires)
check("it recorded which app it landed in", rc.lastApp == "Finder", rc.lastApp)
check("…and that it waited no time at all", rc.lastWait == 0, rc.lastWait)
check("nothing was alerted — a click is not an announcement", #ALERTS == 0)

-- =====================================================================
out("\n=== 3. 🚨 THE MODIFIERS MUST NOT REACH THE MENU ===\n")
-- =====================================================================
check("every posted event carries EMPTY flags", (function()
    for _, e in ipairs(POSTED) do
        if type(e.flags) ~= "table" or next(e.flags) ~= nil then return false end
    end
    return true
end)())
check("…and empty modifiers were passed at construction too", (function()
    for _, e in ipairs(POSTED) do
        if type(e.mods) ~= "table" or next(e.mods) ~= nil then return false end
    end
    return true
end)())

-- ⇧ is held, because ⇪⇧F is how you pressed it.
reset()
MODS = { shift = true }
rc.click()
check("with ⇧ still down, NOTHING is posted yet", #POSTED == 0, #POSTED)
check("…a settle timer was armed instead", #TIMERS == 1, #TIMERS)
-- Guarded, so a build that clicks straight through REPORTS the failures
-- above rather than taking the whole file down on a nil timer.
local function tick() if TIMERS[1] then TIMERS[1].fn() end end
tick()              -- one tick, ⇧ still down
check("…and it keeps waiting while ⇧ stays down", #POSTED == 0, #POSTED)
MODS = {}
tick()              -- the tick where ⇧ has come up
check("the moment ⇧ comes up, the click fires", #POSTED == 2, #POSTED)
check("…and the timer stopped itself", TIMERS[1] and TIMERS[1].stopped == true)
check("…and it recorded how long it waited", (rc.lastWait or 0) > 0, rc.lastWait)

-- ⌥ matters most of all: it is the one that rewrites Finder's menu.
reset()
MODS = { alt = true }
rc.click()
check("⌥ held also holds the click", #POSTED == 0, #POSTED)
MODS = {}
runTimers()
check("…and releases it on the release", #POSTED == 2, #POSTED)

-- But it must never swallow the press: a modifier that never comes up
-- (a stuck key, a keyboard that lies) still gets a menu eventually.
reset()
MODS = { cmd = true }
rc.click()
runTimers(100)
check("a modifier that never clears still fires, after the timeout",
      #POSTED == 2, #POSTED)
check("…and says how long it waited for it",
      (rc.lastWait or 0) >= math.floor(rc.settleTimeout * 1000), rc.lastWait)

-- 🚨 6.132.0 — AND IT SAYS SO. LL: "I don't always have the same options
-- when I use our right-click tool." This is that, exactly: the wait ran
-- out with ⇧ still down, the click went anyway, and Chrome answered with
-- its own menu instead of the page's. Firing was right. Firing SILENTLY
-- was the bug, because a tool that behaves differently for a reason it
-- never states reads as a tool that behaves randomly.
check("🚨 a blind fire is counted", rc.blind == 1, rc.blind)
check("🚨 …and names the modifier that was still down, not just 'a modifier'",
      rc.lastBlind == "⌘", rc.lastBlind)
check("🚨 …on screen, where you are looking when the wrong menu opens",
      (ALERTS[#ALERTS] or ""):find("⌘") ~= nil, ALERTS[#ALERTS])
check("…and the alert says what to do about it",
      (ALERTS[#ALERTS] or ""):find("again") ~= nil, ALERTS[#ALERTS])
MODS = {}

-- Two modifiers down get both symbols, in a stable order.
reset()
MODS = { cmd = true, shift = true }
rc.click()
runTimers(100)
check("both held modifiers are named", rc.lastBlind == "⌘⇧", rc.lastBlind)
MODS = {}

-- 🚨 AND A CLEAN FIRE MUST NOT BE MARKED BLIND. If every click carried
-- the warning, the warning would be noise and would be ignored — which
-- is the same silence, wearing a different hat.
reset()
MODS = {}
rc.click()
check("a click with nothing held is not blind", rc.blind == 0, rc.blind)
check("…and carries no leftover modifier name", rc.lastBlind == nil,
      rc.lastBlind)
check("…and shows no warning", #ALERTS == 0, ALERTS[1])

-- The one that came up in time is not blind either.
reset()
MODS = { shift = true }
rc.click()
MODS = {}
runTimers(100)
check("a modifier that comes up in time is not blind", rc.blind == 0, rc.blind)
check("…and no warning is shown for it", #ALERTS == 0, ALERTS[1])

-- ⏳ The wait itself. 0.30s was not long enough to let go of a four-key
-- chord, which is how the blind fires were happening in the first place.
check("⏳ the settle window is at least 0.45s", rc.settleTimeout >= 0.45,
      rc.settleTimeout)
check("…and is still short enough not to feel broken",
      rc.settleTimeout <= 0.60, rc.settleTimeout)

-- The knob exists, and turning it off restores the old silence — which
-- is the only reason to check it: it proves the alert is what changed.
reset()
rc.warnOnBlind = false
MODS = { alt = true }
rc.click()
runTimers(100)
check("rc.warnOnBlind = false silences the warning", #ALERTS == 0, ALERTS[1])
check("…but the fire is still counted and still named", rc.blind == 1
      and rc.lastBlind == "⌥", tostring(rc.blind) .. "/" .. tostring(rc.lastBlind))
rc.warnOnBlind = true
MODS = {}

out("\n=== 3b. the pointer is re-read after the wait ===\n")
-- The trackpad is under the other hand; a click posted at where the
-- pointer WAS is a click on the wrong thing.
reset()
MODS = { shift = true }
MOUSE = { x = 10, y = 10 }
rc.click()
MOUSE = { x = 900, y = 700 }
MODS = {}
runTimers()
check("the click landed where the pointer ENDED, not where it started",
      POSTED[1].point.x == 900 and POSTED[1].point.y == 700,
      POSTED[1].point.x .. "," .. POSTED[1].point.y)
MOUSE = { x = 100, y = 200 }

out("\n=== 3c. one settle at a time ===\n")
reset()
MODS = { shift = true }
rc.click()
rc.click()
check("pressing twice while waiting arms one timer, not two",
      #TIMERS == 2 and TIMERS[1] and TIMERS[1].stopped == true, #TIMERS)
MODS = {}
runTimers()
check("…and posts one click, not two", #POSTED == 2, #POSTED)

out("\n=== 4. it refuses out loud rather than doing nothing ===\n")
reset()
AX = false
check("with Accessibility off it returns false", rc.click() == false)
check("…posts nothing", #POSTED == 0, #POSTED)
check("…and says which permission and where to find it",
      #ALERTS == 1 and ALERTS[1]:find("Accessibility", 1, true)
      and ALERTS[1]:find("System Settings", 1, true), ALERTS[1])
check("…and the report says so too",
      _G.rightClickReport():find("OFF", 1, true) ~= nil)
AX = true

reset()
local realPos = hs.mouse.absolutePosition
hs.mouse.absolutePosition = function() error("no mouse") end
check("with no readable pointer it returns false", rc.click() == false)
check("…and says so", #ALERTS == 1 and ALERTS[1]:find("pointer", 1, true), ALERTS[1])
hs.mouse.absolutePosition = realPos

out("\n=== 5. an hs without setFlags still clicks ===\n")
reset()
NEWMOUSE_FAILS = true
MODS = {}
check("it still reports success", rc.click() == true)
check("…by falling back to rightClick()", RIGHTCLICK_CALLS == 1, RIGHTCLICK_CALLS)
check("…and the fire was still counted", rc.fires == 1, rc.fires)
NEWMOUSE_FAILS = false

out("\n=== 6. the report answers 'is it working?' ===\n")
reset()
MODS = {}
rc.click()
local rep = _G.rightClickReport()
check("it counts what fired", rep:find("fired", 1, true) ~= nil)
check("it says where the last one landed", rep:find("100,200", 1, true) ~= nil, rep)
check("…and in which app", rep:find("Finder", 1, true) ~= nil)
check("it says where the pointer is now", rep:find("pointer now", 1, true) ~= nil)
-- 6.132.0 — the report is where "it keeps giving me the wrong menu" gets
-- answered, so the blind count is in it whether or not any have happened.
check("the report always carries the blind count",
      rep:find("blind", 1, true) ~= nil, rep)
check("…and says how long it is willing to wait",
      rep:find("450ms") ~= nil, rep)
do
    reset()
    MODS = { shift = true }
    rc.click()
    runTimers(100)
    local r2 = _G.rightClickReport()
    check("after a blind fire the report explains that menu",
          r2:find("modified one") ~= nil, r2)
    check("…and names the modifier in it", r2:find("⇧") ~= nil, r2)
    MODS = {}
end
check("with nothing clicked it says 'never', not '0,0'", (function()
    rc.fires, rc.lastAt = 0, nil
    return _G.rightClickReport():find("never", 1, true) ~= nil
end)())

out("\n=== 7. 🚨 IT MUST NOT GUESS AT OTHER APPS ===\n")
-- The header promised this module asks Accessibility nothing at all —
-- no focused element, no selected file, no window tree. 6.409.0 spent
-- HALF of that promise on his own ask ("it actuates where the mouse is
-- but not on the current highlighted file in Finder"), and the sentry
-- had to move with it.
--
-- 🔒 A SENTRY THAT BANS A NAME EXPIRES THE FIRST TIME THE NAME HAS AN
-- HONEST USE (6.321.0). "No axuielement anywhere" was right while
-- nothing here could legitimately ask; it is wrong the day one function
-- must. So it states the RULE instead: every AX question in this file
-- is asked INSIDE rc.selectionFrame, it asks only about SELECTION and
-- GEOMETRY, and it still never asks what is under the pointer.
local src = (function()
    local f = io.open(HS .. "/modules/right_click.lua", "rb")
    local s = f:read("*a") ; f:close() ; return s
end)()
local selFn = src:match("function rc%.selectionFrame%(%).-\n    end\n")
check("(the selection reader is there to measure)", selFn ~= nil)
check("every axuielement call is inside the selection reader", (function()
    local total  = select(2, src:gsub("axuielement", ""))
    local inside = select(2, (selFn or ""):gsub("axuielement", ""))
    return total > 0 and total == inside
end)(), select(2, src:gsub("axuielement", "")))
check("...and it asks only about the SELECTION and where it is", (function()
    -- the whole vocabulary it is allowed: what is selected, and the
    -- geometry of the thing selected. AXValue, AXTitle, AXChildren or
    -- anything that reads CONTENT is the line this must not cross.
    local allowed = {
        AXFocusedUIElement = true, AXSelectedRows = true,
        AXSelectedChildren = true, AXSelected = true,
        AXFrame = true, AXPosition = true, AXSize = true,
    }
    for attr in src:gmatch("\"(AX%w+)\"") do
        if not allowed[attr] then return false, attr end
    end
    return true
end)())
check("it never asks what is UNDER the pointer",
      src:find("elementAtPosition", 1, true) == nil
      and src:find("systemElementAtPosition", 1, true) == nil)
check("it never reaches for hs.window",
      src:find("hs%.window") == nil)
check("the only accessibility call is the permission check",
      select(2, src:gsub("accessibilityState", "")) == 1,
      select(2, src:gsub("accessibilityState", "")))
-- 🚨 AND THE SETTLE WAIT CANNOT BE TUNED INTO UselessNESS. A timeout at
-- zero silently restores the exact bug section 3 exists to prevent.
check("the settle timeout leaves time for a human to let go",
      rc.settleTimeout >= 0.1, rc.settleTimeout)
check("…and does not make a held key feel broken",
      rc.settleTimeout <= 0.6, rc.settleTimeout)
check("the tick is finer than the timeout", rc.settleTick < rc.settleTimeout)

-- ---- result ------------------------------------------------------------

-- =====================================================================
out("\n=== 8. 🎯 6.409.0 — IT AIMS AT WHAT IS SELECTED ===\n")
-- =====================================================================
-- LL: "Right-click actuates where the mouse is but not on the current
-- highlighted file in Finder. Please fix this functionality."
--
-- 🗿 The header promised the opposite and promised it on purpose. That
-- was a DECISION and it has expired (6.311.0). What has NOT changed is
-- the fallback: nothing selected, or the pointer already on it, and the
-- click goes exactly where the pointer is, as every release before this.
local function fireTimers()
    for _ = 1, 3 do
        for _, t in ipairs(TIMERS) do
            if not t.stopped and t.fn then local f = t.fn ; t.fn = nil ; f() end
        end
    end
end
local function press()
    POSTED, ALERTS, TIMERS = {}, {}, {}
    MODS = {}
    rc.click()
    fireTimers()
end

do
    local before = pass + fail

    local box = { x = 400, y = 300, w = 200, h = 20 }
    check("a point inside the selection is inside it",
          rc.inside({ x = 500, y = 310 }, box) == true)
    check("...and the edges count — a row's own border is the row",
          rc.inside({ x = 400, y = 300 }, box) == true
          and rc.inside({ x = 600, y = 320 }, box) == true)
    check("...and a point outside is outside",
          rc.inside({ x = 399, y = 310 }, box) == false
          and rc.inside({ x = 500, y = 321 }, box) == false)
    check("...and nothing is inside nothing",
          rc.inside(nil, box) == false and rc.inside({ x = 1, y = 1 }, nil) == false)

    local pt, why = rc.aimAt(nil, { x = 10, y = 20 })
    check("no selection aims at the pointer, and says so",
          pt.x == 10 and pt.y == 20
          and why:find("nothing is selected", 1, true) ~= nil)
    pt, why = rc.aimAt({ x = 0, y = 0, w = 0, h = 0 }, { x = 10, y = 20 })
    check("...and a zero-sized frame is not a selection either",
          pt.x == 10 and why:find("nothing is selected", 1, true) ~= nil)
    pt, why = rc.aimAt(box, { x = 500, y = 310 })
    check("🖱 the pointer ALREADY on the selection is left exactly where "
          .. "he put it — moving it would overrule his hand for nothing",
          pt.x == 500 and pt.y == 310
          and why:find("already on the selection", 1, true) ~= nil)
    pt, why = rc.aimAt(box, { x = 10, y = 20 })
    check("...and otherwise it aims at the middle of the selected row",
          pt.x == 500 and pt.y == 310 and why == "the selected item")

    -- 🚨 THE FIXTURE THAT BITES is a pointer NOWHERE NEAR the selection:
    -- with the pointer inside it, a module that ignored the selection
    -- entirely would post at the same place and pass (6.230.0).
    SELECTION, SEL_VIA, SEL_ATTR = { x = 400, y = 300, w = 200, h = 20 },
                                   "AXFrame", "AXSelectedRows"
    MOUSE, MOVES = { x = 10, y = 20 }, 0
    rc.onSel, rc.onPointer = 0, 0
    press()
    check("🎯 ⇪⇧F CLICKS THE SELECTED ROW, not the far-away pointer",
          #POSTED == 2 and POSTED[1].point.x == 500 and POSTED[1].point.y == 310,
          #POSTED .. " posted at " .. tostring(POSTED[1] and POSTED[1].point.x))
    check("...and the pointer really MOVED there first, because a context "
          .. "menu opens at the pointer",
          MOVES == 1 and MOUSE.x == 500 and MOUSE.y == 310,
          MOVES .. " move(s) → " .. MOUSE.x .. "," .. MOUSE.y)
    check("...and it is counted as the selection, not as the pointer",
          rc.onSel == 1 and rc.onPointer == 0,
          rc.onSel .. "/" .. rc.onPointer)
    check("...and the report says which of the two it was",
          _G.rightClickReport():find("1 the selected item", 1, true) ~= nil)

    SEL_ATTR = "AXSelectedChildren"
    MOUSE, MOVES = { x = 10, y = 20 }, 0
    press()
    check("an icon grid answers AXSelectedChildren and works the same — "
          .. "asking only one of the two is how this works in half the "
          .. "places he would try it",
          #POSTED == 2 and POSTED[1].point.x == 500, #POSTED)

    SEL_ATTR, SEL_VIA = "AXSelectedRows", "AXPosition"
    MOUSE, MOVES = { x = 10, y = 20 }, 0
    press()
    check("an app that answers AXPosition + AXSize instead of AXFrame is "
          .. "still aimed at",
          #POSTED == 2 and POSTED[1].point.x == 500, #POSTED)

    SEL_VIA = "AXFrame"
    MOUSE, MOVES = { x = 505, y = 305 }, 0
    press()
    check("🖱 with the pointer already on the selection NOTHING MOVES, and "
          .. "the click goes where he was pointing",
          MOVES == 0 and #POSTED == 2 and POSTED[1].point.x == 505,
          MOVES .. " move(s)")

    SELECTION = nil
    MOUSE, MOVES = { x = 77, y = 88 }, 0
    rc.onSel, rc.onPointer = 0, 0
    press()
    check("🔒 nothing selected → the pointer, untouched, exactly as every "
          .. "release before this one",
          MOVES == 0 and #POSTED == 2 and POSTED[1].point.x == 77
          and rc.onPointer == 1 and rc.onSel == 0,
          MOVES .. " / " .. tostring(POSTED[1] and POSTED[1].point.x))

    SELECTION = { x = 400, y = 300, w = 200, h = 20 }
    rc.useSelection = false
    MOUSE, MOVES = { x = 77, y = 88 }, 0
    press()
    check("🔌 the switch is REAL — useSelection = false and a selected row "
          .. "is not even asked about",
          MOVES == 0 and POSTED[1].point.x == 77, tostring(POSTED[1].point.x))
    rc.useSelection = true

    HAS_AX = false
    MOUSE, MOVES = { x = 77, y = 88 }, 0
    press()
    check("🛟 a Mac whose AX tree cannot be reached still CLICKS, at the "
          .. "pointer — a degraded aim beats a dead key",
          #POSTED == 2 and POSTED[1].point.x == 77, #POSTED)
    HAS_AX = true

    local realPos2 = hs.mouse.absolutePosition
    hs.mouse.absolutePosition = function(p)
        if p then error("this Mac will not move the pointer") end
        return { x = MOUSE.x, y = MOUSE.y }
    end
    MOUSE = { x = 10, y = 20 }
    press()
    hs.mouse.absolutePosition = realPos2
    check("🛟 a pointer that refuses to move still clicks the selection — "
          .. "the menu simply opens away from the pointer, and it is said",
          #POSTED == 2 and POSTED[1].point.x == 500
          and tostring(rc.lastAim):find("would not move", 1, true) ~= nil,
          tostring(rc.lastAim))

    SELECTION = nil
    local ran = (pass + fail) - before
    check("§8 ran all of its checks (" .. ran .. " of 17)", ran >= 17, ran)
end

out(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
os.exit(fail == 0 and 0 or 1)
