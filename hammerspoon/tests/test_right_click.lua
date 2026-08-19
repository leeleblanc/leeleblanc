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

hs = {
    mouse = { absolutePosition = function() return { x = MOUSE.x, y = MOUSE.y } end },
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
            local t = { secs = secs, fn = fn, stopped = false }
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
check("with nothing clicked it says 'never', not '0,0'", (function()
    rc.fires, rc.lastAt = 0, nil
    return _G.rightClickReport():find("never", 1, true) ~= nil
end)())

out("\n=== 7. 🚨 IT MUST NOT GUESS AT OTHER APPS ===\n")
-- The header promises this module asks Accessibility nothing about what
-- is under the pointer — no focused element, no selected file, no window
-- tree. That promise is the reason it works in "anything that has a
-- right-click", and it is one refactor away from being broken quietly.
local src = (function()
    local f = io.open(HS .. "/modules/right_click.lua", "rb")
    local s = f:read("*a") ; f:close() ; return s
end)()
check("it never reaches for hs.axuielement",
      src:find("axuielement", 1, true) == nil)
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
out(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
os.exit(fail == 0 and 0 or 1)
