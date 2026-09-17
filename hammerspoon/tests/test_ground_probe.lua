-- =====================================================================
-- test_ground_probe.lua — 6.242.0: what THIS Mac answers, printed
-- =====================================================================
--     lua5.4 test_ground_probe.lua [/path/to/hammerspoon]
--
-- Executes modules/ground_probe.lua against a stubbed Mac. Three things
-- are worth proving and all three are proven by MAKING THEM FAIL:
--   · gp.parseSpotlight is PURE and is run against the real shape of
--     `defaults read com.apple.symbolichotkeys`, including the case that
--     matters most — NO 64 entry at all, which is a Mac nobody has
--     touched and where Spotlight certainly still owns ⌘Space.
--   · gp.axCount's three bounds BITE. A check that a budget EXISTS is
--     not a check that it bites (6.187.0, paid for twice), so every
--     bound is driven by a tree bigger than it.
--   · the report's states never read alike: not asked · asked and failed
--     · answered (6.196.1).
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

-- ---- the stub Mac ------------------------------------------------------
local PRINTED, TIMERS, TASKS = {}, {}, {}
local NOWMS      = 0        -- the clock the walk is timed against
local ACCESS     = true
local TAP_NEW_OK = true
local TAP_STARTS = true
local FRONT      = { name = "Chrome" }
local AXAPP      = nil      -- what applicationElement answers
local TASK_OK    = true

local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

hs = {
    timer = {
        -- Milliseconds since boot, as hs.timer.absoluteTime answers
        -- (nanoseconds); the module divides by 1e6.
        absoluteTime = function() return NOWMS * 1e6 end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    accessibilityState = function() return ACCESS end,
    application = { frontmostApplication = function() return FRONT end },
    axuielement = {
        applicationElement = function() return AXAPP end,
    },
    eventtap = {
        event = { types = { flagsChanged = 12, keyDown = 10 } },
        new = function(types, fn)
            if not TAP_NEW_OK then error("refused") end
            local t = { types = types, fn = fn, on = false }
            function t:start() self.on = TAP_STARTS ; return self end
            function t:stop() self.on = false ; return self end
            function t:isEnabled() return self.on end
            return t
        end,
    },
    task = {
        new = function(bin, cb, args)
            if not TASK_OK then error("no task") end
            local t = { bin = bin, cb = cb, args = args,
                        started = false, terminated = false }
            function t:start() self.started = true ; return self end
            function t:terminate() self.terminated = true ; return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
}
if FRONT then FRONT.name = function() return "Chrome" end end

-- A fake AX element: children, a role, and a parameterized answer.
local function el(role, kids, opts)
    opts = opts or {}
    local e = { role = role, kids = kids or {}, timeout = nil }
    function e:setTimeout(n) self.timeout = n ; return self end
    function e:attributeValue(name)
        if name == "AXRole" then return self.role end
        if name == "AXChildren" then return self.kids end
        if name == "AXFocusedUIElement" then return opts.focused end
        if name == "AXFocusedWindow" then return opts.window end
        if name == "AXSelectedTextRange" then return opts.range end
        return nil
    end
    function e:parameterizedAttributeValue(name, arg)
        if name == "AXBoundsForRange" and opts.bounds then
            return opts.bounds
        end
        return nil
    end
    return e
end

local CORE = { provide = function() end }
local M = dofile(HS .. "/modules/ground_probe.lua")
M.setup(CORE)
local gp = M.config

-- =====================================================================
out("\n=== 1. ⌘Space — three answers, not two ===\n")
-- =====================================================================
-- The real shape of `defaults read com.apple.symbolichotkeys`.
local PLIST_ON = [[
{
    AppleSymbolicHotKeys =     {
        60 =         {
            enabled = 1;
            value =             { parameters = ( 32, 49, 262144 ); type = standard; };
        };
        64 =         {
            enabled = 1;
            value =             { parameters = ( 32, 49, 1048576 ); type = standard; };
        };
        65 =         {
            enabled = 0;
            value =             { parameters = ( 32, 49, 1572864 ); type = standard; };
        };
    };
}
]]
local PLIST_OFF = PLIST_ON:gsub("64 =         {\n            enabled = 1;",
                                "64 =         {\n            enabled = 0;")

local on, why = gp.parseSpotlight(PLIST_ON)
check("⌘space: an enabled 64 entry reads as Spotlight still holding it",
      on == true, tostring(on) .. " / " .. tostring(why))
local off = gp.parseSpotlight(PLIST_OFF)
check("...and a disabled one reads as FREE", off == false, tostring(off))

-- 🚨 THE ROW THIS SECTION EXISTS FOR. macOS writes a hotkey into that file
-- only when it is CHANGED, so a Mac nobody has touched has no 64 block at
-- all — and Spotlight certainly still owns ⌘Space there. Reading "absent"
-- as "off" would tell him the key was free on the one Mac where it is not.
local none, noneWhy = gp.parseSpotlight([[
{
    AppleSymbolicHotKeys =     { 60 = { enabled = 1; }; };
}
]])
check("🚨 NO 64 entry is NOT 'disabled' — it is macOS's default, which is ON",
      none == nil and noneWhy:find("never been asked", 1, true) ~= nil,
      tostring(none) .. " / " .. tostring(noneWhy))

-- 🔎 ...and the block really is READ AS A BLOCK, which needs a fixture that
-- can tell the two implementations apart. "64 then the first `enabled` you
-- find" and "64's own `enabled`" agree on every ordinary file — the first
-- version of this check used one, passed, and proved nothing (6.230.0's
-- one-hop chain, in a parser). A 64 entry with NO flag of its own is what
-- separates them: bounded, that is unreadable; unbounded, it silently
-- answers with 65's flag and calls it Spotlight's.
local bounded, boundedWhy = gp.parseSpotlight([[
{
    AppleSymbolicHotKeys =     {
        64 =         { value = { type = standard; }; };
        65 =         { enabled = 1; };
    };
}
]])
check("🔎 ...and it stops at the NEXT key — 65's flag is never 64's answer",
      bounded == nil and boundedWhy:find("no enabled flag", 1, true) ~= nil,
      tostring(bounded) .. " / " .. tostring(boundedWhy))

check("an unreadable answer is its own state, never a guess",
      select(1, gp.parseSpotlight("")) == nil
      and select(1, gp.parseSpotlight(nil)) == nil
      and select(1, gp.parseSpotlight("{ 64 = { enabled = maybe; }; }")) == nil)
check("...and true/false spellings are real answers too",
      gp.parseSpotlight("{\n 64 = { enabled = true; };\n}") == true
      and gp.parseSpotlight("{\n 64 = { enabled = false; };\n}") == false)

-- ---- the IO half -------------------------------------------------------
TASKS = {}
gp.askSpotlight()
check("the read runs /usr/bin/defaults with no shell",
      #TASKS == 1 and TASKS[1].bin == "/usr/bin/defaults"
      and TASKS[1].args[1] == "read"
      and TASKS[1].args[2] == "com.apple.symbolichotkeys",
      TASKS[1] and (TASKS[1].bin .. " " .. table.concat(TASKS[1].args, " ")))
check("...and it is STARTED, not merely built", TASKS[1].started == true)
check("...and the state says it is asking, which is not an answer",
      gp.spotlight.state == "asking", gp.spotlight.state)
-- 🚨 A TASK WHOSE CALLBACK NEVER COMES must not leave the state reading
-- "asking" for ever — 6.155.0's killer timer, and the reason it is held.
local killer = TIMERS[#TIMERS]
check("...with a killer timer armed behind it", killer ~= nil and killer.secs == 6,
      killer and killer.secs)
killer.fn()
check("🚨 ...and when it never answers, the state SAYS never answered rather "
      .. "than staying 'asking' for the rest of the session",
      gp.spotlight.state == "asked and never answered", gp.spotlight.state)

TASKS[1].cb(0, PLIST_OFF, "")
check("...and a real answer overwrites it", gp.spotlight.state == "answered"
      and gp.spotlight.enabled == false, gp.spotlight.state)

TASK_OK = false
gp.askSpotlight()
check("🔎 a Mac where the task cannot run says so — 'could not run' is not "
      .. "'not asked' and is not 'disabled'",
      gp.spotlight.state == "asked and could not run", gp.spotlight.state)
TASK_OK = true

-- =====================================================================
out("\n=== 2. The AX walk — every bound BITES ===\n")
-- =====================================================================
-- A tree of known size: `wide` children under one root, each a leaf.
local function flat(n, role)
    local kids = {}
    for i = 1, n do kids[i] = el(role or "AXStaticText") end
    return el("AXWindow", kids)
end
-- A chain `deep` elements long.
local function chain(n)
    local e = el("AXStaticText")
    for _ = 2, n do e = el("AXGroup", { e }) end
    return e
end

NOWMS = 0
local small = gp.axCount(flat(10, "AXButton"), { maxElements = 400, maxDepth = 12,
                                                 budgetMs = 1e9, maxKids = 400 })
check("🧭 it counts what is there — one window and ten buttons",
      small.elements == 11 and small.clickable == 10, small.elements)
check("...and finishing inside every bound is its own state",
      small.stopped == nil, tostring(small.stopped))
check("...and a non-clickable role is not counted as one",
      gp.axCount(flat(10, "AXStaticText"), { budgetMs = 1e9 }).clickable == 0)

-- 🚨 THE ELEMENT BOUND BITES. A tree of 500 under a limit of 50.
local capped = gp.axCount(flat(500, "AXButton"),
                          { maxElements = 50, budgetMs = 1e9, maxKids = 1000 })
check("🚨 the element bound STOPS the walk — 500 elements, 50 allowed",
      capped.elements == 50 and capped.stopped == "elements",
      capped.elements .. " / " .. tostring(capped.stopped))

-- 🚨 THE DEPTH BOUND BITES, and it does NOT stop the whole walk: one deep
-- branch must not end every other branch.
local deep = gp.axCount(chain(30), { maxDepth = 5, maxElements = 400,
                                     budgetMs = 1e9, maxKids = 400 })
check("🚨 the depth bound STOPS descending — a 30-deep chain under a limit "
      .. "of 5 visits five", deep.elements == 5 and deep.depth == 5,
      deep.elements .. " deep " .. deep.depth)
check("...and it is REPORTED as a bound hit, not as a finished walk",
      deep.stopped == "depth", tostring(deep.stopped))

-- 🚨 THE TIME BUDGET BITES. The clock is a stub, so this is exact rather
-- than a race: every visit advances it.
NOWMS = 0
local slowRoot = flat(500, "AXButton")
local realNow = gp.nowMs
gp.nowMs = function() NOWMS = NOWMS + 10 ; return NOWMS end
local timed = gp.axCount(slowRoot, { maxElements = 400, maxDepth = 12,
                                     budgetMs = 100, maxKids = 1000 })
gp.nowMs = realNow
check("🚨 the time budget STOPS the walk, and says TIME rather than a count",
      timed.stopped == "time" and timed.elements < 400,
      timed.elements .. " / " .. tostring(timed.stopped))

-- 🚨 THE WIDTH BOUND. An element with more children than maxKids.
local wide = gp.axCount(flat(300, "AXButton"),
                        { maxKids = 20, maxElements = 400, budgetMs = 1e9 })
check("🚨 the children-per-element bound bites too, and is named",
      wide.elements == 21 and wide.stopped == "width",
      wide.elements .. " / " .. tostring(wide.stopped))

check("no element at all is not a crash, and not a zero-count success",
      gp.axCount(nil).stopped == "no element")
check("an element that THROWS on every question is counted, never fatal",
      (function()
           local bad = { }
           function bad:setTimeout() error("nope") end
           function bad:attributeValue() error("nope") end
           local r = gp.axCount(bad, { budgetMs = 1e9 })
           return r.elements == 1 and r.stopped == nil
       end)())

-- =====================================================================
out("\n=== 3. The focused element — the row that decides 🟥 ===\n")
-- =====================================================================
-- An app that answers a range AND a rectangle: the mark is drawable.
local okField = el("AXTextArea", {}, { range = { location = 4, length = 0 },
                                       bounds = { x = 10, y = 20, w = 8, h = 16 } })
AXAPP = el("AXApplication", {}, { focused = okField, window = flat(3) })
local f1 = gp.focusedFacts()
check("🟥 an app that answers AXBoundsForRange can carry the underline",
      f1.rangeOK == true and f1.boundsOK == true and f1.rect.w == 8,
      tostring(f1.why))
check("...and the role is named, because the answer is per element",
      f1.role == "AXTextArea", tostring(f1.role))
check("...and every element it touched had a TIMEOUT set first — an AX read "
      .. "without one is the ⇪Y beach ball in another costume",
      okField.timeout ~= nil and AXAPP.timeout ~= nil,
      tostring(okField.timeout) .. " / " .. tostring(AXAPP.timeout))

-- 🚨 THE CASE THE FEATURE TURNS ON. A range but NO rectangle is exactly an
-- Electron app, and it means the pink underline cannot be drawn there at
-- all — which is the difference between a mark and an alert.
local noBounds = el("AXTextArea", {}, { range = { location = 0, length = 0 } })
AXAPP = el("AXApplication", {}, { focused = noBounds, window = flat(3) })
local f2 = gp.focusedFacts()
check("🚨 a range with NO rectangle is its own answer, and says what it costs",
      f2.rangeOK == true and f2.boundsOK == false
      and f2.why:find("will not say where a word is", 1, true) ~= nil,
      tostring(f2.why))

-- ...and not a text element at all is a THIRD answer, never the same as
-- "an app that refuses the rectangle".
AXAPP = el("AXApplication", {}, { focused = el("AXButton"), window = flat(3) })
local f3 = gp.focusedFacts()
check("🔎 no AXSelectedTextRange is a different answer from no rectangle",
      f3.rangeOK == false and f3.boundsOK == false
      and f3.why:find("not a text element", 1, true) ~= nil, tostring(f3.why))

AXAPP = el("AXApplication", {}, { window = flat(3) })
check("...and nothing focused says so, and says what to do about it",
      (gp.focusedFacts().why or ""):find("click into a text field", 1, true) ~= nil,
      gp.focusedFacts().why)

AXAPP = nil
check("...and an app with no AX element is named, not a throw",
      (gp.focusedFacts().why or ""):find("no AX element", 1, true) ~= nil,
      gp.focusedFacts().why)

-- =====================================================================
out("\n=== 4. A modifier tap, and the report ===\n")
-- =====================================================================
local tOK, tWhy = gp.flagsTapOK()
check("⌘⌘/⌥⌥: a modifier tap that starts is the answer the feature needs",
      tOK == true, tostring(tWhy))
TAP_STARTS = false
check("🔎 ...and one that is CREATED but will not start is a different "
      .. "answer from one that could not be created",
      select(2, gp.flagsTapOK()):find("would not start", 1, true) ~= nil,
      select(2, gp.flagsTapOK()))
TAP_STARTS = true
TAP_NEW_OK = false
check("...and a refusal names the usual cause AND that it needs a relaunch",
      (function()
           local ok, w = gp.flagsTapOK()
           return ok == false and w:find("RELAUNCH", 1, true) ~= nil
       end)(), select(2, gp.flagsTapOK()))
TAP_NEW_OK = true

-- ---- the report --------------------------------------------------------
AXAPP = el("AXApplication", {}, { focused = okField, window = flat(6, "AXButton") })
_G.secureInput = { on = false, why = "clear" }
PRINTED = {}
local rep = _G.groundReport()
check("📋 the report prints as ONE string (6.179.1 — the console gate eats "
      .. "a report printed row by row)", #PRINTED == 1, #PRINTED)
for _, want in ipairs({ "access", "secure", "front", "caret", "bounds",
                        "clicks", "⌘space", "⌘⌘ / ⌥⌥", "clock" }) do
    check("...and it carries the '" .. want .. "' row", rep:find(want, 1, true) ~= nil)
end
check("🧭 ...and every probe names the RELEASE it decides — that is the whole "
      .. "point of the report existing before the features do",
      rep:find("DECIDES 🟥", 1, true) ~= nil
      and rep:find("DECIDES 🖱", 1, true) ~= nil
      and rep:find("DECIDES the ⌘Space launcher", 1, true) ~= nil
      and rep:find("DECIDES ⌘⌘", 1, true) ~= nil, rep)
check("...and it says out loud that it changed nothing",
      rep:find("changes NOTHING", 1, true) ~= nil)

-- 🔎 THE THREE STATES OF THE ⌘SPACE ROW, which is the row most likely to be
-- misread: a Mac that has not answered must not print like a Mac that said
-- "free".
gp.spotlight = { state = "not asked yet", enabled = nil, asks = 0, answers = 0 }
PRINTED = {}
local rep2 = _G.groundReport()
check("🔎 'not asked yet' does not read as an answer",
      rep2:find("⌘space   : not asked yet", 1, true) ~= nil,
      rep2:match("⌘space[^\n]*"))
gp.spotlight = { state = "answered", enabled = false, asks = 1, answers = 1 }
PRINTED = {}
check("...and FREE says free, in the one word he is looking for",
      _G.groundReport():find("⌘space   : FREE", 1, true) ~= nil)
gp.spotlight = { state = "answered", enabled = true, asks = 1, answers = 1 }
PRINTED = {}
check("...and still-held says so rather than staying quiet",
      _G.groundReport():find("Spotlight STILL HAS IT", 1, true) ~= nil)

-- Accessibility off is not a footnote (6.196.0's rule, in a new report).
ACCESS = false
PRINTED = {}
local rep3 = _G.groundReport()
check("🎹 no Accessibility says QUIT AND RELAUNCH, not 'reload'",
      rep3:find("NOT GRANTED", 1, true) ~= nil
      and rep3:find("QUIT AND RELAUNCH", 1, true) ~= nil, rep3)
ACCESS = true

-- Secure input is READ, never re-probed: a second opinion about something
-- the platform already answers is deleted, not tuned (6.202.0).
local src = (function()
    local fh = io.open(HS .. "/modules/ground_probe.lua", "r")
    local s = fh:read("*a") ; fh:close() ; return s
end)()
check("🔒 it never runs its own Secure Input probe — capabilities.lua owns "
      .. "that question and asks it in a held task",
      src:find("ioreg", 1, true) == nil
      and src:find("IOConsoleUsers", 1, true) == nil, "it greps for ioreg")
check("🚨 ...and it writes nothing at all: no io.open, no hs.settings",
      src:find("io%.open%s*%(") == nil and src:find("hs%.settings") == nil)
check("🚨 ...and it binds no key — this release adds no shortcut",
      src:find("hyperAddShortcut", 1, true) == nil
      and src:find("hs%.hotkey") == nil)

-- warm() must do ONE thing and do it off the boot path.
TIMERS, TASKS = {}, {}
M.warm()
check("🕒 warm() starts nothing itself — it arms a held timer",
      #TASKS == 0 and #TIMERS == 1 and TIMERS[1].secs == 3,
      #TASKS .. " task(s), " .. #TIMERS .. " timer(s)")
check("...and it is HELD, so nobody collects it mid-flight (6.196.1)",
      _G.groundProbeTimer ~= nil)
TIMERS[1].fn()
check("...and when it fires, the read is the only thing that runs",
      #TASKS == 1 and TASKS[1].bin == "/usr/bin/defaults")

print = realPrint
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
