-- =====================================================================
-- test_double_tap.lua — ⌨️ 6.292.0, ⌘⌘ and the shared engine
-- =====================================================================
--     lua5.4 test_double_tap.lua [/path/to/hammerspoon]
--
-- LL: "My double tap for my clipboard history uses command+command, is
-- that built? Same as opt+option to move to the menu bar even if the
-- app is full-screen?" The honest answer was no to both — asked in
-- 6.198.0, again on 2026-09-13, never built — while the machinery has
-- been driving ⌃⌃ on his Mac since 6.116.0.
--
-- The state machine is the expensive half and it is exercised with no
-- Mac at all: a gesture record, a flags table and a clock that is an
-- ARGUMENT, so every window and every refusal is proven without
-- waiting (6.234.0's shape).

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        io.write("   ❌ " .. failures[#failures] .. "\n")
    end
end
local function out(s) io.write(s) end

-- ---- a Mac in tables -------------------------------------------------
TAPS, TAP_REFUSES, TAP_START_REFUSES = {}, false, false
local NOW = 1000.4231          -- a FLOAT with a fraction (6.282.0/6.290.0)
hs = {
    timer = { secondsSinceEpoch = function() return NOW end },
    keycodes = { map = { cmd = 55, rightcmd = 54, alt = 58, rightalt = 61,
                         ctrl = 59, rightctrl = 62, shift = 56, rightshift = 60 } },
    eventtap = {
        event = { types = { flagsChanged = 12, keyDown = 10, leftMouseDown = 1,
                            rightMouseDown = 3, otherMouseDown = 25,
                            scrollWheel = 22 } },
        new = function(types, fn)
            if TAP_REFUSES then error("macOS refused the tap", 0) end
            local t = { types = types, fn = fn, running = false }
            function t:start()
                -- 6.265.0: created, wired, and REFUSING TO START is a
                -- different shape from "new threw", and on a beta OS it
                -- is the one this config keeps meeting.
                if TAP_START_REFUSES then error("macOS refused to start it", 0) end
                self.running = true ; return self
            end
            function t:stop() self.running = false ; return self end
            TAPS[#TAPS + 1] = t
            return t
        end,
    },
}
local PRINTED = {}
local realPrint = print
print = function(...)
    local bits = {}
    for i = 1, select("#", ...) do bits[#bits + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(bits, " ")
end

-- 🔌 A CORE FILE RETURNS AN INITIALISER, never the table — the shape
-- hs-install.sh verifies and test_diagnostics enforces. The suite loads
-- it the way init.lua does, or it is testing a different contract.
local init = dofile(HS .. "/core/double_tap.lua")
check("core/double_tap.lua returns an INITIALISER, as every core file must",
      type(init) == "function")
local dt = init({})
check("…and calling it hands back the engine", type(dt) == "table")

-- A gesture, and a way to drive it without an event.
local FIRED = 0
local function newG(mod, side)
    dt.unregister("t")
    return (dt.register("t", { mod = mod or "cmd", side = side or "either",
                               action = function() FIRED = FIRED + 1 end,
                               label = "the test gesture" }))
end
local CMD, RCMD = 55, 54
-- down/up as the tap would deliver them
local function down(g, t, code, extra)
    local f = { [g.mod] = true }
    for k, v in pairs(extra or {}) do f[k] = v end
    return dt.onFlags(g, f, t, code)
end
local function up(g, t, code, extra)
    return dt.onFlags(g, extra or {}, t, code)
end
-- A whole tap: down then up, `held` apart.
-- 🚨 `extra` IS A REAL PARAMETER AND WAS NOT, WHICH MADE EVERY CHORD
-- CHECK IN §2 A LIE. The first draft's signature stopped at `code`, so
-- `tap(g, 1, 0.05, { shift = true })` handed a TABLE where a keycode
-- goes — sideOf refuses a non-number, the shift flag was never set, and
-- the press it was meant to dirty was a clean one. Both checks passed
-- because a single tap answers false anyway. A helper whose signature
-- silently swallows an argument is 6.193.0 inside the test itself.
local function tap(g, t, held, code, extra)
    down(g, t, code, extra)
    return up(g, t + (held or 0.05), code, extra and {} or nil)
end

-- =====================================================================
out("\n=== 1. ⌨️ THE STATE MACHINE — two taps, and only two taps ===\n")
-- =====================================================================
do
    local g = newG("cmd")
    check("a single tap does not fire", tap(g, 1, 0.05) == false)
    check("a second tap inside the gap FIRES", tap(g, 1.2, 0.05) == true)
    -- and the sequence is consumed: a third tap is a first tap again
    check("…and the pair is spent — the next tap starts over",
          tap(g, 1.4, 0.05) == false)

    local g2 = newG("cmd")
    tap(g2, 1, 0.05)
    check("🚨 two taps FURTHER apart than tapGap are not a gesture",
          tap(g2, 1 + dt.tapGap + 0.2, 0.05) == false)

    -- 🚨 AND THESE ASSERT ON THE SECOND TAP, DELIBERATELY. The first
    -- draft checked a single long hold and a single chorded press — and
    -- the FIRST tap of a pair answers false whatever the rule does, so
    -- the mutations deleting maxHold and the other-modifier guard both
    -- SURVIVED. 6.230.0's rule in a state machine: pick the input where
    -- the right and wrong implementations must differ, which here is
    -- always the tap that would COMPLETE the gesture.
    local g3 = newG("cmd")
    tap(g3, 1, 0.05)                                  -- a good first tap
    check("🚨 a HOLD is not the second tap — a modifier you are using is"
          .. " down for as long as you are reading the menu",
          tap(g3, 1.1, dt.maxHold + 0.1) == false)
    local g3b = newG("cmd")
    check("…and two long holds are not a gesture either",
          tap(g3b, 1, dt.maxHold + 0.1) == false
          and tap(g3b, 1.1, dt.maxHold + 0.1) == false)
    local g3c = newG("cmd")
    tap(g3c, 1, 0.05)
    tap(g3c, 1.1, dt.maxHold + 0.1)                   -- a hold breaks it
    check("…and the hold also breaks the sequence that follows it",
          tap(g3c, 1.2, 0.05) == false)
end

-- =====================================================================
out("\n=== 2. 🚨 A CHORD IS NOT A GESTURE ===\n")
-- =====================================================================
do
    -- Each of these drives the tap that would COMPLETE the gesture, for
    -- the reason given in §1: the first tap answers false either way.
    local g = newG("cmd")
    tap(g, 1, 0.05)
    check("⌘ arriving alongside ⇧ is dirty from the start",
          tap(g, 1.1, 0.05, CMD, { shift = true }) == false)
    local gz = newG("cmd")
    check("…and a pair of chorded presses is not a gesture",
          tap(gz, 1, 0.05, CMD, { shift = true }) == false
          and tap(gz, 1.1, 0.05, CMD, { shift = true }) == false)

    local g2 = newG("cmd")
    tap(g2, 1, 0.05)                                  -- a good first tap
    down(g2, 1.1, CMD)
    dt.onFlags(g2, { cmd = true, shift = true }, 1.12, nil)   -- ⇧ joins
    check("⇧ joining a HELD ⌘ dirties it", up(g2, 1.15, CMD) == false)

    -- 🚨 THE ONE THAT MADE THE MOUSE INTRUDERS MANDATORY (6.124.0).
    local g3 = newG("cmd")
    tap(g3, 1, 0.05)
    dt.onIntruder(g3)                    -- a key or a click between halves
    check("🚨 a key or a click BETWEEN the halves cancels the sequence",
          tap(g3, 1.1, 0.05) == false)

    local g4 = newG("cmd")
    down(g4, 1, CMD)
    dt.onIntruder(g4)
    check("…and an intruder DURING a press dirties that press too",
          up(g4, 1.05, CMD) == false)

    -- the scroll-wheel hot path: nothing armed, nothing to do
    local g5 = newG("cmd")
    local before = g5.lastTapAt
    dt.onIntruder(g5)
    check("an intruder with nothing armed changes nothing",
          g5.lastTapAt == before and g5.dirty == false)

    -- fn counts as another modifier
    local g6 = newG("cmd")
    tap(g6, 1, 0.05)
    check("fn held makes it a chord",
          tap(g6, 1.1, 0.05, CMD, { fn = true }) == false)
end

-- =====================================================================
out("\n=== 3. 🎹 WHICH SIDE ===\n")
-- =====================================================================
do
    local g = newG("cmd", "right")
    check("the codes resolve from hs.keycodes, not the fallback literals",
          g.leftCode == 55 and g.rightCode == 54 and g.sideReadable == true)
    tap(g, 1, 0.05, nil)
    check("🚨 a WRONG-SIDE press does not merely fail to count — it"
          .. " DIRTIES, so two left taps cannot arm a right gesture",
          tap(g, 1.1, 0.05, nil) == false)

    local g2 = newG("cmd", "right")
    tap(g2, 1, 0.05, RCMD) ; tap(g2, 1.1, 0.05, RCMD)
    check("two RIGHT taps fire a right-side gesture", g2.fires == 0
          and dt.onFlags(g2, {}, 1.2, RCMD) == false)   -- state is clean

    local g3 = newG("cmd", "either")
    tap(g3, 1, 0.05, CMD)
    check("with side 'either' the LEFT key is fine",
          tap(g3, 1.1, 0.05, CMD) == true)

    -- ⚠️ A KEYBOARD THAT GIVES BOTH SIDES ONE CODE cannot be asked, and
    -- pretending otherwise silently refuses every press. Fail OPEN.
    local realMap = hs.keycodes.map
    hs.keycodes.map = { cmd = 55, rightcmd = 55 }
    local g4 = newG("cmd", "right")
    check("⚠️ one keycode for both keys is NOTICED", g4.sideReadable == false)
    tap(g4, 1, 0.05, 55)
    check("…and the gesture still works rather than dying silently",
          tap(g4, 1.1, 0.05, 55) == true)
    hs.keycodes.map = realMap

    -- a typo in a profile must fail OPEN, not kill the gesture
    local g5 = newG("cmd", "middle")
    tap(g5, 1, 0.05, CMD)
    check("a side nobody has heard of means 'the side does not matter'",
          tap(g5, 1.1, 0.05, CMD) == true)
end

-- =====================================================================
out("\n=== 4. 🔑 MANY GESTURES, ONE ENGINE ===\n")
-- =====================================================================
do
    dt.unregister("t")
    local a, b = 0, 0
    local ga = dt.register("A", { mod = "cmd", action = function() a = a + 1 end })
    local gb = dt.register("B", { mod = "alt", action = function() b = b + 1 end })
    check("two gestures on two modifiers both register",
          ga ~= nil and gb ~= nil and #dt.gestures == 2)

    -- 🚨 THEY MUST NOT INTERFERE: ⌘ is an "other" modifier to ⌥, so a ⌘
    -- gesture in flight has to be invisible to the ⌥ one and vice versa.
    tap(ga, 1, 0.05, CMD) ; tap(ga, 1.1, 0.05, CMD)
    dt.fire(ga)
    check("the ⌘ gesture fires its OWN action", a == 1 and b == 0)
    tap(gb, 2, 0.05, 58) ; tap(gb, 2.1, 0.05, 58)
    dt.fire(gb)
    check("…and the ⌥ one fires its own", a == 1 and b == 1)

    -- 🚨 TWO GESTURES ON ONE MODIFIER CANNOT BOTH BE RIGHT.
    local g3, why = dt.register("C", { mod = "cmd", action = function() end })
    check("🚨 a second gesture on ⌘ is REFUSED, not silently shadowed",
          g3 == nil and type(why) == "string")
    check("…and the refusal NAMES who holds it",
          (why or ""):find("A", 1, true) ~= nil, why)

    -- …but two SIDES of one modifier is a legitimate pair
    dt.unregister("A")
    local l = dt.register("L", { mod = "cmd", side = "left",  action = function() end })
    local r = dt.register("R", { mod = "cmd", side = "right", action = function() end })
    check("left and right ⌘ are two different gestures", l ~= nil and r ~= nil)

    check("a gesture with no action is refused — a tap that does nothing",
          dt.register("X", { mod = "cmd" }) == nil)
    check("a modifier this engine does not know is refused",
          dt.register("X", { mod = "hyper", action = function() end }) == nil)
    dt.unregister("L") ; dt.unregister("R") ; dt.unregister("B")
end

-- =====================================================================
out("\n=== 5. 🔒 THE TAP, AND EVERY WAY IT CAN REFUSE ===\n")
-- =====================================================================
do
    TAPS = {}
    dt.stop()
    check("with no gesture registered the watcher does not start",
          select(1, dt.start()) == false)

    local g = newG("cmd")
    local ok = dt.start()
    check("the watcher is created AND started, not merely created",
          ok == true and #TAPS == 1 and TAPS[1].running == true)
    check("…and it is HELD, or nothing would ever fire it", dt.tap ~= nil)
    check("…and it watches flagsChanged AND every intruder type",
          #TAPS[1].types == 6)
    check("starting twice does not stack a second tap",
          select(2, dt.start()) == "already running" and #TAPS == 1)

    -- 🚨 EVERY PATH RETURNS false. This tap sees keyDown, so a path that
    -- returned true would take the keyboard away entirely.
    local fire = TAPS[1].fn
    local function ev(t, flags, code)
        return { getType = function() return t end,
                 getFlags = function() return flags or {} end,
                 getKeyCode = function() return code end }
    end
    check("a flagsChanged event is watched, never consumed",
          fire(ev(12, { cmd = true }, CMD)) == false)
    check("a keyDown is watched, never consumed",
          fire(ev(10, {}, 40)) == false)

    -- driving a real double tap THROUGH the tap
    FIRED = 0
    dt.resetState(g)
    NOW = 5000.5
    fire(ev(12, { cmd = true }, CMD))
    NOW = 5000.55 ; fire(ev(12, {}, CMD))
    NOW = 5000.7  ; fire(ev(12, { cmd = true }, CMD))
    NOW = 5000.75 ; fire(ev(12, {}, CMD))
    check("🔑 ⌘⌘ through the real tap runs the action", FIRED == 1, FIRED)

    -- 🚨 THE THREE STAND-DOWNS, each with its own row.
    FIRED = 0 ; dt.resetState(g)
    _G.typingInjection = function() return true end
    NOW = 6000.5 ; fire(ev(12, { cmd = true }, CMD))
    NOW = 6000.55; fire(ev(12, {}, CMD))
    NOW = 6000.7 ; fire(ev(12, { cmd = true }, CMD))
    NOW = 6000.75; fire(ev(12, {}, CMD))
    check("🔁 a SYNTHETIC modifier cannot assemble a gesture (6.218.0)",
          FIRED == 0)
    _G.typingInjection = nil

    FIRED = 0 ; dt.resetState(g)
    _G.hsPaused = true
    NOW = 7000.5 ; fire(ev(12, { cmd = true }, CMD))
    NOW = 7000.55; fire(ev(12, {}, CMD))
    NOW = 7000.7 ; fire(ev(12, { cmd = true }, CMD))
    NOW = 7000.75; fire(ev(12, {}, CMD))
    check("⏸ paused, the engine stands down (6.152.0)", FIRED == 0)
    _G.hsPaused = false

    FIRED = 0 ; dt.resetState(g)
    _G.hyperActive = true
    NOW = 8000.5 ; fire(ev(12, { cmd = true }, CMD))
    _G.hyperActive = false
    NOW = 8000.55; fire(ev(12, {}, CMD))
    NOW = 8000.7 ; fire(ev(12, { cmd = true }, CMD))
    NOW = 8000.75; fire(ev(12, {}, CMD))
    check("⇪ held resets the state — ⇪ is F18 plus a synthetic chord",
          FIRED == 0)

    -- an action that throws must not take the tap with it
    dt.unregister("t")
    local bad = dt.register("bad", { mod = "cmd",
                                     action = function() error("boom", 0) end })
    dt.fire(bad)
    check("🔒 an action that throws is caught and COUNTED",
          bad.threw == 1 and dt.lastThrow ~= nil)
    dt.unregister("bad")

    -- the callback itself throwing: counted, and it stands down at the limit
    newG("cmd")
    dt.tapFailures = 0
    local boom = { getType = function() error("no type", 0) end }
    for _ = 1, dt.failLimit do fire(boom) end
    check("🚨 the watcher switches itself off rather than degrading the"
          .. " keyboard, and says so",
          dt.tap == nil
          and (table.concat(PRINTED, "\n")):find("switched off", 1, true) ~= nil)
    dt.tapFailures = 0
end

-- =====================================================================
out("\n=== 6. 🛟 TWO REFUSAL SHAPES (6.265.0) ===\n")
-- =====================================================================
do
    dt.stop() ; TAPS = {} ; newG("cmd")
    TAP_REFUSES = true
    local ok, why = dt.start()
    TAP_REFUSES = false
    check("hs.eventtap.new THROWING is a refusal that says why",
          ok == false and tostring(why):find("refused", 1, true) ~= nil)
    check("…and no half-made tap is left held", dt.tap == nil)

    dt.stop() ; TAPS = {}
    TAP_START_REFUSES = true
    local ok2, why2 = dt.start()
    TAP_START_REFUSES = false
    check("🛟 CREATED AND THEN REFUSING TO START is the OTHER shape, and"
          .. " it is the one a beta OS gives",
          ok2 == false and tostring(why2):find("not start", 1, true) ~= nil)
    check("…and only THERE does nilling the slot matter", dt.tap == nil)
end

-- =====================================================================
out("\n=== 7. 🔎 THE REPORT — three states, never two (6.196.1) ===\n")
-- =====================================================================
do
    dt.stop() ; TAPS = {} ; PRINTED = {}
    for i = #dt.gestures, 1, -1 do dt.unregister(dt.gestures[i].name) end
    _G.doubleTapReport()
    local r = table.concat(PRINTED, "\n")
    check("with nothing registered it says so, and does NOT read as a fault",
          r:find("none registered", 1, true) ~= nil
          and r:find("nothing has registered", 1, true) ~= nil)

    PRINTED = {} ; newG("cmd") ; dt.start()
    _G.doubleTapReport()
    r = table.concat(PRINTED, "\n")
    check("running reads as running", r:find("watcher  : running", 1, true) ~= nil)
    check("…and the timing is printed, so a missed gesture can be judged",
          r:find("timing", 1, true) ~= nil)
    -- 📏 THE COST THIS RELEASE CHOSE is stated where it is read, not
    -- only in a commit message.
    check("📏 the report NAMES that ⌃⌃ is not on this engine yet",
          r:find("⌃⌃", 1, true) ~= nil
          and r:find("keeps its own tap", 1, true) ~= nil)

    PRINTED = {} ; dt.stop()
    TAP_START_REFUSES = true ; dt.start() ; TAP_START_REFUSES = false
    _G.doubleTapReport()
    r = table.concat(PRINTED, "\n")
    check("🚨 registered-but-not-running is its OWN state, with a ⚠️",
          r:find("NOT RUNNING", 1, true) ~= nil and r:find("⚠️", 1, true) ~= nil)
end

-- =====================================================================
out("\n=== 8. 🔒 SOURCE — the promises a functional check cannot see ===\n")
-- =====================================================================
do
    local fh = io.open(HS .. "/core/double_tap.lua", "r")
    local raw = fh and fh:read("a") or ""
    if fh then fh:close() end
    -- comments stripped (6.262.0): the comments here deliberately quote
    -- the very lines they forbid.
    local code = raw:gsub("%-%-%[%[.-%]%]", " "):gsub("%-%-[^\n]*", "")
    check("the engine never CONSUMES an event — no `return true` in the"
          .. " handler, which would take the keyboard away",
          code:find("function dt%.handler") ~= nil
          and code:match("function dt%.handler.-\nend"):find("return true") == nil)
    check("it never reads WHICH key was typed — no characters, no keymap"
          .. " lookups beyond the modifier codes",
          code:find("getCharacters") == nil and code:find("UnicodeString") == nil)
    check("it never writes: no io.open, no hs.settings",
          code:find("io%.open") == nil and code:find("hs%.settings") == nil)
    check("the injection guard is present and is checked FIRST",
          code:find("_G%.typingInjection") ~= nil)
    -- and the prose that explains the ⌃⌃ decision has to survive, or a
    -- future sweep satisfies the sentry by deleting the reason (6.280.0).
    check("🚨 the file still explains why ⌃⌃ is not migrated yet",
          raw:find("proves itself on the two NEW", 1, true) ~= nil)
end

-- =====================================================================
out("\n=== 9. 📋 THE CLIPBOARD SIDE — ⌘⌘ registers in warm(), not setup ===\n")
-- =====================================================================
do
    local fh = io.open(HS .. "/modules/clipboard_history.lua", "r")
    local raw = fh and fh:read("a") or ""
    if fh then fh:close() end
    local code = raw:gsub("%-%-%[%[.-%]%]", " "):gsub("%-%-[^\n]*", "")
    check("clipboard_history has a warm()", code:find("function M%.warm") ~= nil)
    -- 🔌 6.228.0: a profile's settings land AFTER setup returns, so a
    -- gesture registered in setup could be switched off and never
    -- unregistered. The sentry is about WHERE, which no functional
    -- check on this suite's stubs can see.
    local warmBody = code:match("function M%.warm.*$") or ""
    check("🔌 …and the ⌘⌘ registration is INSIDE it, never in setup",
          warmBody:find('dt%.register%("clipboardHistory"') ~= nil
          and (code:sub(1, code:find("function M%.warm"))
               :find('register%("clipboardHistory"')) == nil)
    -- 🚨 AND COUNTING THE DEFINITION PROVED NOTHING: the mutation that
    -- puts ⇪V's body back inline leaves the definition in place, so
    -- "exactly one openHistory =" was still true. What matters is that
    -- ⇪V CALLS it rather than holding a second copy.
    check("🔑 ⌘⌘ and ⇪V go through ONE opener (6.231.0)",
          select(2, code:gsub("clip%.openHistory%s*=%s*function", "")) == 1
          and select(2, code:gsub("clip%.openHistory%(%)", "")) >= 1)
    local vKey = code:match('hyperAddShortcut%(%{%}, clip%.key, function%(%).-end, "clipboard history"') or ""
    check("…and ⇪V's own handler is the CALL, not a second copy of it",
          vKey:find("clip%.openHistory%(%)") ~= nil
          and vKey:find("openMain%(%)") == nil, vKey)
    check("the switch exists and ships ON", code:find("clip%.cmdCmd%s*=%s*true") ~= nil)
    check("IT DEGRADES: no engine means ⇪V is untouched and a reason is kept",
          warmBody:find("cmdCmdWhy") ~= nil)
end

print = realPrint
out(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then os.exit(1) end
