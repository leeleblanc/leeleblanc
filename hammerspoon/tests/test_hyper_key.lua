-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- =====================================================================
-- THE HYPER KEY — BOTH WAYS IN, AND THE TEST THAT PRESSES IT
-- =====================================================================
-- 🚨 WHY THIS SUITE EXISTS. LL's work Mac booted to "32 modules · 80 ⇪
-- shortcuts · 1.03s / All green" and not one shortcut worked. Every
-- number on that line was correct. Registering a shortcut is not the same
-- as being able to fire it, and until 6.76.0 nothing in this config could
-- tell the two apart — including this test suite, which is the more
-- uncomfortable half of that sentence.
--
-- So this file models the ONE distinction that mattered:
--
--   hs.hotkey   → Carbon's RegisterEventHotKey, dispatched by the system
--   hs.eventtap → a CGEventTap, which sees the key BEFORE Carbon does
--
-- The stub below has a switch for each layer, and the delivery order is
-- the real one: every running tap first, and Carbon only if no tap
-- consumed the event. Turn Carbon off and you have the work Mac. That
-- machine is a test case now, not an anecdote.
--
-- 🧪 AND IT RUNS THE SHIPPED CODE. §3.12's hyperEnter/hyperExit/hyperBind
-- are lifted out of init.lua as source and executed here, the same way
-- test_keyboard_stack lifts the real injection guard. A private copy
-- would agree with itself. The point is that init.lua and
-- core/hyper_key.lua agree with EACH OTHER — that a shortcut filed by
-- hyperBind is one the dispatcher can find, under the same name.
-- =====================================================================

local pass, fail = 0, 0
local function out(s) io.write(s) end
local function check(label, ok, detail)
  if ok then pass = pass + 1; out("  ✅ " .. label .. "\n")
  else
    fail = fail + 1
    out("  ❌ " .. label .. (detail ~= nil and ("  [" .. tostring(detail) .. "]") or "") .. "\n")
  end
end
local function section(s) out("\n" .. s .. "\n") end

local function readAll(p)
  local f = io.open(p, "r"); if not f then return nil end
  local s = f:read("*a"); f:close(); return s
end

local INIT_SRC = readAll(HS .. "/init.lua")
assert(INIT_SRC, "cannot read init.lua at " .. HS)
local COEXIST_SRC = readAll(HS .. "/core/coexist.lua")
assert(COEXIST_SRC, "cannot read core/coexist.lua")

-- ---- the two blocks of §3.12 this suite runs for real ----------------
local BLOCK_ENTER = INIT_SRC:match(
  "(_G%.hyperCarbonPresses = 0.-_G%.hyperEnter, _G%.hyperExit = hyperEnter, hyperExit)")
local BLOCK_BIND = INIT_SRC:match(
  "(_G%.hyperBound = %{%}.-_G%.hyperCombo = hyperCombo)")
assert(BLOCK_ENTER, "could not lift hyperEnter/hyperExit + the F18 bind from init.lua")
assert(BLOCK_BIND,  "could not lift hyperCombo/hyperBind from init.lua")

-- hyperBind is a LOCAL inside that block, so the only way to reach it is
-- from inside the same chunk. Appended, not re-declared: a second copy
-- here would be the private-copy mistake this whole file exists to avoid.
BLOCK_BIND = BLOCK_BIND .. "\n_G.hyperBindForTest = hyperBind"

-- ---- the real injection guard, out of core/coexist.lua ---------------
local BLOCK_GUARD = COEXIST_SRC:match("(_G%.injectDepth = 0.-\n    return ok, err\nend)")
assert(BLOCK_GUARD, "could not lift the injection guard from core/coexist.lua")

-- =====================================================================
-- THE MAC
-- =====================================================================
local W          -- the world under test, rebuilt for every scenario

local function comboOf(mods, key)
  local m = {}
  for _, x in ipairs(mods or {}) do m[#m + 1] = tostring(x):lower() end
  table.sort(m)
  if #m == 0 then return tostring(key):lower() end
  return table.concat(m, "+") .. "+" .. tostring(key):lower()
end

local KEYCODES = { f18 = 79, f19 = 80, a = 0, d = 2, q = 12, x = 7 }

local function newWorld(opts)
  opts = opts or {}
  local w = {
    carbon    = opts.carbon ~= false,    -- does RegisterEventHotKey deliver?
    tapKeys   = opts.tapKeys ~= false,   -- do event taps receive posted keys?
    dropKeyUp = opts.dropKeyUp == true,  -- swallow F18 keyUp on the way out
    tapNewThrows = opts.tapNewThrows == true,
    taps = {}, timers = {}, printed = {}, told = {}, recorded = {},
    carbonBinds = {}, enters = 0, exits = 0, tapThrows = 0, posts = {},
  }

  local TYPES = { keyDown = 10, keyUp = 11 }

  local modal = { entered = false, binds = {} }
  function modal:bind(mods, key, p, r, rep)
    self.binds[comboOf(mods, key)] = { p, r, rep }; return self
  end
  function modal:enter() self.entered = true; w.enters = w.enters + 1; return self end
  function modal:exit()  self.entered = false; w.exits  = w.exits  + 1; return self end
  w.modal = modal

  -- 🚨 THE DELIVERY ORDER IS THE REAL ONE: taps first, Carbon only if
  -- nothing consumed the event. Getting this backwards would make the tap
  -- fallback look like it works when it cannot, which is the exact
  -- direction of error that put a green boot line on a dead keyboard.
  local function deliver(ev)
    w.posts[#w.posts + 1] = { key = ev.key, down = ev.down }
    if w.dropKeyUp and ev.key == "f18" and not ev.down then return end
    if w.tapKeys then
      for _, t in ipairs(w.taps) do
        if t.on then
          local ok, ret = pcall(t.fn, ev)
          if not ok then w.tapThrows = w.tapThrows + 1 end
          if ok and ret == true then return end
        end
      end
    end
    if not w.carbon then return end
    local c = comboOf(ev.mods, ev.key)
    local g = w.carbonBinds[c]
    if g then
      local fn = ev.down and g[1] or g[2]
      if fn then fn() end
      return
    end
    if modal.entered then
      local b = modal.binds[c]
      if b then
        local fn = ev.down and b[1] or b[2]
        if fn then fn() end
      end
    end
  end
  w.deliver = deliver

  local function mkEvent(mods, key, down, autorepeat)
    local flags = {}
    for _, m in ipairs(mods or {}) do flags[m] = true end
    local e = { down = down, key = key, mods = mods or {} }
    e.getType     = function() return down and TYPES.keyDown or TYPES.keyUp end
    e.getKeyCode  = function() return KEYCODES[key] end
    e.getFlags    = function() return flags end
    e.getProperty = function() return autorepeat and 1 or 0 end
    e.post        = function() deliver(e) end
    return e
  end
  w.mkEvent = mkEvent

  local hs = {
    eventtap = {
      event = {
        types = TYPES,
        properties = { keyboardEventAutorepeat = 8 },
        newKeyEvent = function(mods, key, down) return mkEvent(mods, key, down) end,
      },
      new = function(types, fn)
        if w.tapNewThrows then error("Accessibility withheld", 0) end
        local t = { types = types, fn = fn, on = false }
        function t:start() self.on = true; return self end
        function t:stop()  self.on = false; return self end
        function t:isEnabled() return self.on end
        w.taps[#w.taps + 1] = t
        return t
      end,
      keyStroke = function() end,
    },
    hotkey = {
      bind = function(mods, key, p, r)
        w.carbonBinds[comboOf(mods, key)] = { p, r }
        return { enable = function(s) return s end, disable = function(s) return s end,
                 delete = function(s) return s end }
      end,
      modal = { new = function() return modal end },
    },
    timer = {
      secondsSinceEpoch = function() return w.now or 1000 end,
      doAfter = function(s, fn)
        local t = { secs = s, fn = fn, live = true }
        function t:stop() self.live = false; return self end
        w.timers[#w.timers + 1] = t
        return t
      end,
      doEvery = function(s, fn)
        local t = { secs = s, fn = fn, live = true, every = true }
        function t:stop() self.live = false; return self end
        w.timers[#w.timers + 1] = t
        return t
      end,
    },
    keycodes = { map = setmetatable({}, { __index = function(_, k)
      if type(k) == "number" then
        for name, code in pairs(KEYCODES) do if code == k then return name end end
        return nil
      end
      return KEYCODES[k]
    end }) },
    configdir = HS,
  }
  w.hs = hs

  -- The sandbox every lifted block and core/hyper_key.lua runs inside.
  local SB = {
    hs = hs, pcall = pcall, ipairs = ipairs, pairs = pairs, type = type,
    tostring = tostring, tonumber = tonumber, table = table, math = math,
    string = string, error = error, select = select, loadfile = loadfile,
    setmetatable = setmetatable,
    print = function(...)
      local p = {}
      for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
      w.printed[#w.printed + 1] = table.concat(p, " ")
    end,
  }
  SB._G = SB
  SB.diag = { say = function() end, warn = function() end, err = function() end }
  SB.notices = {
    record = function(kind, src, msg) w.recorded[#w.recorded + 1] = tostring(msg) end,
    tell   = function(title, body) w.told[#w.told + 1] = tostring(title) end,
  }
  SB.hyperShortcutCount = 107
  w.SB = SB

  -- the real injection guard, then the real §3.12 blocks
  load(BLOCK_GUARD, "coexist-guard", "t", SB)()
  SB.hyperModal = modal
  SB.hyperActive = false
  load(BLOCK_ENTER, "init-hyperEnter", "t", SB)()
  load(BLOCK_BIND,  "init-hyperBind",  "t", SB)()

  return w
end

-- Runs pending timers, oldest first, including any created while running.
-- The clock ADVANCES with them: _G.suppressTypingFor() is a deadline, and
-- a world where time never moves is one where the self-test's own
-- suppression window never closes. That is not a hypothetical — it is
-- what this stub did on its first run, and every dispatcher assertion
-- below passed for the wrong reason because of it.
local function runTimers(w, rounds)
  for _ = 1, (rounds or 6) do
    local due = w.timers
    w.timers = {}
    if #due == 0 then return end
    for _, t in ipairs(due) do
      if t.live and not t.every then
        w.now = (w.now or 1000) + (t.secs or 0)
        t.fn()
      end
    end
  end
end

-- Everything the boot did is over and the clock has moved on — the state
-- you are actually in when you reach for ⇪.
local function timePasses(w, secs)
  w.now = (w.now or 1000) + (secs or 5)
end

local function loadHyperKey(w)
  local chunk, err = loadfile(HS .. "/core/hyper_key.lua", "t", w.SB)
  assert(chunk, err)
  local init = chunk()
  assert(type(init) == "function", "core/hyper_key.lua must return an initialiser")
  w.SB.hyperSelfTestPending = true
  init({ enter = w.SB.hyperEnter, exit = w.SB.hyperExit, combo = w.SB.hyperCombo })
end

-- A minimal but REAL set of hyper shortcuts, registered the way every
-- shortcut in the config is: through §3.12's own hyperBind.
local function bindShortcuts(w)
  w.ran = {}
  w.SB.hyperBindForTest({}, "d", function() w.ran[#w.ran + 1] = "d-pressed" end,
      function() w.ran[#w.ran + 1] = "d-released" end,
      function() w.ran[#w.ran + 1] = "d-repeat" end, "test")
  w.SB.hyperBindForTest({ "shift" }, "x",
      function() w.ran[#w.ran + 1] = "shift-x" end, nil, nil, "test")
  w.SB.hyperBindForTest({}, "a", function() error("this shortcut throws", 0) end,
      nil, nil, "test")
end

local function printedFinding(w, needle)
  for _, l in ipairs(w.printed) do
    if l:find(needle, 1, true) then return l end
  end
  return nil
end

local world = newWorld

local function toldFinding(w, needle)
  for _, t in ipairs(w.told) do
    if t:find(needle, 1, true) then return t end
  end
  return nil
end

out("\n=== HYPER KEY ==========================================\n")

-- =====================================================================
section("1. A MAC WHERE CARBON WORKS — the personal MacBook Air")
-- =====================================================================
do
  local w = world{ carbon = true, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)

  check("the self-test reports a hyper key that actually fires",
        w.SB.hyperVerified == true, tostring(w.SB.hyperVerified))
  check("...and names BOTH paths, because both delivered F18",
        w.SB.hyperPath == "carbon + tap", tostring(w.SB.hyperPath))
  check("...having pressed ⇪⇧F19 exactly once",
        (w.SB.hyperProbeFires or 0) == 1, w.SB.hyperProbeFires)
  check("🚨 the event tap does NOT swallow F18 — Carbon still sees it, or "
     .. "the fallback would break the very Mac it is meant to leave alone",
        (w.SB.hyperSelfTestResult or {}).carbon == 1,
        (w.SB.hyperSelfTestResult or {}).carbon)
  check("...and the tap saw it too",
        (w.SB.hyperSelfTestResult or {}).tap == 1,
        (w.SB.hyperSelfTestResult or {}).tap)
  check("the Carbon-free dispatcher stays OFF when Carbon works",
        w.SB.hyperDispatchEngaged == false)
  check("nothing is shouted at a Mac where everything is fine",
        printedFinding(w, "🚨") == nil, printedFinding(w, "🚨"))
  check("...and nothing reaches the screen",
        #w.told == 0, w.told[1])
  check("🚨 the probe never leaves ⇪ latched on",
        w.SB.hyperActive == false and w.modal.entered == false,
        tostring(w.SB.hyperActive) .. "/" .. tostring(w.modal.entered))
end

-- =====================================================================
section("2. THE WORK MAC — F18 arrives, Carbon never fires")
-- =====================================================================
do
  local w = world{ carbon = false, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)

  check("🚨 the config NOTICES that its shortcuts do not work",
        printedFinding(w, "did not fire") ~= nil)
  check("...switches ⇪ to the Carbon-free dispatcher",
        w.SB.hyperDispatchEngaged == true)
  check("...re-tests rather than assuming the fix worked",
        (w.SB.hyperSelfTestResult or {}).stage == 2,
        (w.SB.hyperSelfTestResult or {}).stage)
  check("...and ends up with a hyper key that is PROVEN, not counted",
        w.SB.hyperVerified == true, tostring(w.SB.hyperVerified))
  check("...named for the path actually carrying it",
        w.SB.hyperPath == "event tap (dispatcher)", tostring(w.SB.hyperPath))
  check("🚨 and it SAYS SO — this is a real difference between two Macs "
     .. "and rule 7 does not allow it to be silent",
        printedFinding(w, "WITHOUT CARBON") ~= nil)
  check("...on screen as well as in the Console", #w.told > 0, #w.told)
  check("...and in the notices ledger", #w.recorded > 0, #w.recorded)

  -- and now the part that matters: does a shortcut actually run?
  timePasses(w)
  w.enters, w.exits = 0, 0
  w.mkEvent({}, "f18", true).post()
  check("holding ⇪ marks the hyper key active through the tap",
        w.SB.hyperActive == true)
  check("...and deliberately does NOT enter a modal whose hotkeys are dead",
        w.modal.entered == false and w.enters == 0, w.enters)

  local consumed = w.taps[1].fn(w.mkEvent({}, "d", true))
  check("⇪D RUNS ITS SHORTCUT on a Mac with no working hotkey layer",
        w.ran[1] == "d-pressed", w.ran[1])
  check("...and EATS the keystroke, or ⇪D would also type a letter d",
        consumed == true, tostring(consumed))

  local up = w.taps[1].fn(w.mkEvent({}, "d", false))
  check("...the release handler runs on the way up", w.ran[2] == "d-released")
  check("...and the keyUp is consumed too", up == true)

  w.mkEvent({}, "f18", false).post()
  check("releasing ⇪ ends it", w.SB.hyperActive == false)
end

-- =====================================================================
section("3. THE DISPATCHER, key by key")
-- =====================================================================
do
  local w = world{ carbon = false, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)
  timePasses(w)
  local tap = w.taps[1]
  w.mkEvent({}, "f18", true).post()   -- ⇪ held

  w.ran = {}
  check("⇪⇧X finds the shift-qualified shortcut and not the bare one",
        tap.fn(w.mkEvent({ "shift" }, "x", true)) == true and w.ran[1] == "shift-x",
        w.ran[1])

  w.ran = {}
  check("🚨 an UNBOUND hyper key is passed through, never eaten",
        tap.fn(w.mkEvent({}, "q", true)) == false and #w.ran == 0, #w.ran)

  -- 🔁 The pathological binding, registered on purpose. NOTHING in the
  -- config claims all four modifiers today — every hyper shortcut is bare
  -- or ⇧-qualified — so with the shipped shortcut set this guard never
  -- fires. That is exactly why it has to be tested against a shortcut
  -- that WOULD match: an unclaimed hyper key forwards ⌘⇧⌃⌥+itself, that
  -- synthetic chord comes straight back through this same tap, and if it
  -- ever found an entry the dispatcher would forward it again. Forever.
  -- One hyperAddShortcut with four modifiers is all it would take, and
  -- the person who writes it will not be looking here.
  w.SB.hyperBindForTest({ "cmd", "shift", "ctrl", "alt" }, "d",
      function() w.ran[#w.ran + 1] = "CHORD LOOP" end, nil, nil, "pathological")
  w.ran = {}
  check("🔁 the forwarded ⌘⇧⌃⌥ chord is refused outright even when a "
     .. "shortcut IS registered on it — this is what stops the dispatcher "
     .. "feeding itself its own output, forever",
        tap.fn(w.mkEvent({ "cmd", "shift", "ctrl", "alt" }, "d", true)) == false
        and #w.ran == 0, w.ran[1])

  w.ran = {}
  tap.fn(w.mkEvent({}, "d", true, true))    -- autorepeat
  check("a held key runs the REPEAT handler, not the press handler again",
        w.ran[1] == "d-repeat" and #w.ran == 1, w.ran[1])

  w.ran = {}
  check("🛟 a shortcut that THROWS does not throw into the event system",
        tap.fn(w.mkEvent({}, "a", true)) == true, "threw out of the tap")
  check("...and the tap is still running afterwards", tap.on == true)

  w.ran = {}
  check("nothing dispatches when ⇪ is not held", (function()
      w.mkEvent({}, "f18", false).post()
      return tap.fn(w.mkEvent({}, "d", true)) == false and #w.ran == 0
    end)(), w.ran[1])
end

-- =====================================================================
section("4. THE INJECTION GUARD — a shortcut must not run because "
        .. "ANOTHER module typed")
-- =====================================================================
do
  local w = world{ carbon = false, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)
  timePasses(w)
  local tap = w.taps[1]
  w.mkEvent({}, "f18", true).post()

  w.ran = {}
  w.SB.withInjection(function()
    check("🚨 an injected keystroke never fires a hyper shortcut",
          tap.fn(w.mkEvent({}, "d", true)) == false and #w.ran == 0, w.ran[1])
  end)

  w.ran = {}
  check("...and a real one right afterwards still does",
        tap.fn(w.mkEvent({}, "d", true)) == true and w.ran[1] == "d-pressed",
        w.ran[1])

  -- The deliberate exception, and the reason it has to exist.
  w.ran = {}
  w.SB.suppressTypingFor(0.8)
  check("the time-bounded window suppresses too",
        tap.fn(w.mkEvent({}, "d", true)) == false and #w.ran == 0, w.ran[1])
  w.SB.hyperSelfTestInFlight = true
  w.ran = {}
  check("🚨 ...EXCEPT for the self-test's own keystroke, which exists to "
     .. "reach the dispatcher — without this the test measures its own "
     .. "suppression and calls a working hyper key dead",
        tap.fn(w.mkEvent({}, "d", true)) == true and w.ran[1] == "d-pressed",
        w.ran[1])
  w.SB.hyperSelfTestInFlight = false
end

-- =====================================================================
section("5. WHEN NOTHING WORKS AT ALL")
-- =====================================================================
do
  local w = world{ carbon = false, tapKeys = false }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)

  check("a hyper key that cannot fire is reported as broken, not counted",
        w.SB.hyperVerified == false, tostring(w.SB.hyperVerified))
  check("🚨 ...loudly", printedFinding(w, "🚨") ~= nil)
  check("...naming the fact that F18 never arrived at all, which is a "
     .. "different repair from a shortcut that will not run",
        printedFinding(w, "never reached the config") ~= nil)
  check("...on screen, because the Console is not where you are looking",
        #w.told > 0)
  check("...and it does NOT leave the dispatcher engaged, which would "
     .. "stop the modal being entered for no benefit",
        w.SB.hyperDispatchEngaged == false)
end

do
  -- F18 gets through, but no shortcut runs on EITHER path.
  local w = world{ carbon = false, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  w.SB.hyperDispatch["shift+f19"] = nil   -- nothing left to answer the probe
  w.modal.binds["shift+f19"] = nil
  runTimers(w)

  check("F18 arriving with nothing to answer it is also reported",
        w.SB.hyperVerified == false, tostring(w.SB.hyperVerified))
  check("...as the OTHER failure, with the other repair",
        printedFinding(w, "on either path") ~= nil)
  check("🚨 ...and the dispatcher is rolled back rather than left half-on",
        w.SB.hyperDispatchEngaged == false)
end

-- =====================================================================
section("6. THE PROBE CANNOT MAKE THINGS WORSE")
-- =====================================================================
do
  -- The F18 keyUp goes missing — the one outcome that would latch ⇪ on
  -- and turn every subsequent keystroke into a hyper chord.
  local w = world{ carbon = true, tapKeys = true, dropKeyUp = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)

  check("🚨 a lost keyUp does not leave the hyper key latched on",
        w.SB.hyperActive == false, tostring(w.SB.hyperActive))
  check("...and the modal is forced back out", w.modal.entered == false)
end

do
  local w = world{ carbon = true, tapKeys = true, tapNewThrows = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)

  check("a Mac that refuses the event tap still boots", w.SB.hyperKeyTap == nil)
  check("...and says the fallback is missing rather than dropping it quietly",
        printedFinding(w, "could not start") ~= nil)
  check("...and Carbon alone is still enough, and is proven so",
        w.SB.hyperVerified == true and w.SB.hyperPath == "carbon",
        tostring(w.SB.hyperPath))
end

-- =====================================================================
section("7. THE TAP STANDS DOWN RATHER THAN DEGRADE THE KEYBOARD")
-- =====================================================================
do
  local w = world{ carbon = false, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)
  timePasses(w)
  local tap = w.taps[1]
  w.mkEvent({}, "f18", true).post()

  -- A dispatcher that throws on every keystroke is the shape macOS
  -- punishes by switching the tap off without telling anyone.
  w.SB.hyperTapDispatch = function() error("broken", 0) end
  local everConsumed, everThrew = false, false
  for _ = 1, 5 do
    local ok, ret = pcall(tap.fn, w.mkEvent({}, "d", true))
    if not ok then everThrew = true end
    if ok and ret == true then everConsumed = true end
  end
  check("🛟 a failing callback never throws into the event system",
        everThrew == false)
  check("...and never eats the keystroke on the failure path",
        everConsumed == false)
  check("...it counts its failures", w.SB.hyperTapFailures == 5,
        w.SB.hyperTapFailures)
  check("...and takes ITSELF out at five rather than slow the whole keyboard",
        tap.on == false)
  check("...saying so on screen, by name",
        toldFinding(w, "switched itself off") ~= nil, w.told[#w.told])
end

-- =====================================================================
section("8. THE TWO FILES AGREE WITH EACH OTHER")
-- =====================================================================
do
  local w = world{ carbon = true, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  check("🚨 every shortcut hyperBind files is one the dispatcher can find, "
     .. "under the same name — the two are the same function, so they "
     .. "cannot drift",
    (function()
      for combo in pairs(w.SB.hyperBound) do
        if not w.SB.hyperDispatch[combo] then return false, combo end
      end
      return true
    end)())
  check("...and the dispatch entry carries all three handlers", (function()
      local e = w.SB.hyperDispatch["d"]
      return e and type(e.pressed) == "function"
             and type(e.released) == "function"
             and type(e.repeated) == "function"
    end)())
  check("...and the probe key is NOT counted as one of your shortcuts",
        w.SB.hyperBound["shift+f19"] == nil
        and w.SB.hyperDispatch["shift+f19"] ~= nil)
end

-- =====================================================================
section("9. THE SOURCE CONTRACT")
-- =====================================================================
do
  local code = {}
  for line in (INIT_SRC .. "\n"):gmatch("([^\n]*)\n") do
    code[#code + 1] = line:match("^%s*%-%-") and "" or line
  end
  local initCode = table.concat(code, "\n")

  check("init.lua publishes the two handlers core/hyper_key.lua drives ⇪ with",
        initCode:find("_G.hyperEnter, _G.hyperExit = hyperEnter, hyperExit", 1, true) ~= nil)
  check("...and the combo normaliser the dispatcher matches keys with",
        initCode:find("_G.hyperCombo = hyperCombo", 1, true) ~= nil)
  check("🚨 core/hyper_key.lua is loaded AFTER _G.hyperFinalize(), or the "
     .. "dispatcher would be built against an empty shortcut table",
    (function()
      local fin = initCode:find("_G.hyperFinalize()", 1, true)
      local load_ = initCode:find("/core/hyper_key.lua", 1, true)
      return fin and load_ and fin < load_, tostring(fin) .. " vs " .. tostring(load_)
    end)())
  check("...inside a pcall, so a missing core file degrades the fallback "
     .. "instead of killing the boot",
        initCode:find("local hkOK, hkErr = pcall(", 1, true) ~= nil)
  check("...and a failure prints, because a silent one looks like success",
        initCode:find("if not hkOK then", 1, true) ~= nil)

  -- 🚨 RUN, not grepped. A check for the string "hyperSelfTestPending" in
  -- core/boot_report.lua stays green under `false and
  -- _G.hyperSelfTestPending` — mutation testing found exactly that, and
  -- a source match that survives the code being switched off is not a
  -- test. So the real file is executed, twice, and the line it prints is
  -- read.
  local function bootLines(pending)
    local lines = {}
    local SB = {
      hs = { timer = { secondsSinceEpoch = function() return 1000 end },
             settings = { get = function() return false end,
                          set = function() end } },
      pcall = pcall, ipairs = ipairs, type = type, tostring = tostring,
      table = table, string = string, math = math,
      print = function(...)
        local p2 = {}
        for i = 1, select("#", ...) do p2[#p2 + 1] = tostring((select(i, ...))) end
        lines[#lines + 1] = table.concat(p2, " ")
      end,
    }
    SB._G = SB
    SB.hotkeyBoundCount, SB.hotkeyConflictCount = 5, 0
    SB.moduleLoaded, SB.moduleFailed = 32, 0
    SB.moduleProfileName, SB.moduleDir = "BASE", "modules"
    SB.hyperShortcutCount, SB.hyperForwardCount, SB.hyperConflictCount = 80, 40, 0
    SB.autocorrectStatus = "on"
    SB.textExpander = { status = "2006 snippets" }
    SB.diagBootStart = 999
    SB.hyperSelfTestPending = pending
    local chunk = assert(loadfile(HS .. "/core/boot_report.lua", "t", SB))
    chunk()({ hostTag = "TestMac", cloudDir = "/cloud", logsDir = "/logs",
              backupDir = "/bk", asanaEnabled = true, secretsStatus = "loaded",
              axOK = true })
    return table.concat(lines, "\n")
  end

  local waiting = bootLines(true)
  check("🚨 the healthy boot line no longer lets \"All green\" imply a key "
     .. "nobody has tried — it says the proof is still coming",
        waiting:find("All green", 1, true) ~= nil
        and waiting:find("⇪", 1, true) ~= nil
        and waiting:find("2s", 1, true) ~= nil, waiting)
  check("...and does not promise a proof on a Mac with the hyper key off",
    (function()
      local off = bootLines(false)
      return off:find("All green", 1, true) ~= nil
             and off:find("a failure will say so", 1, true) == nil
    end)())

  local diag = readAll(HS .. "/core/diagnostics.lua") or ""
  check("⇪⇧D reports whether ⇪ was PROVEN, next to the count that was not "
     .. "enough on its own",
        diag:find("hyper PROVEN", 1, true) ~= nil
        and diag:find("hyperVerified", 1, true) ~= nil)
end

-- =====================================================================
section("10. suppressTypingFor — an injection that outlives its caller")
-- =====================================================================
do
  local w = world{}
  local SB = w.SB
  w.now = 1000
  check("no injection by default", SB.typingInjection() == false)
  SB.suppressTypingFor(0.5)
  check("a posted-keystroke window stands the typing watchers down",
        SB.typingInjection() == true)
  w.now = 1000.4
  check("...for as long as it was given", SB.typingInjection() == true)
  w.now = 1000.6
  check("🚨 ...and then ends BY ITSELF — a deadline cannot leak the way a "
     .. "counter with no matching decrement does",
        SB.typingInjection() == false)
  SB.injectUntil = 0
  check("it is capped, so no caller can switch typing off for a session",
        SB.suppressTypingFor(600) == 2.0)
  SB.injectUntil = 0
  check("a zero or negative window is a no-op",
        SB.suppressTypingFor(0) == 0 and SB.typingInjection() == false)

  -- 🚨 A SHORTER WINDOW MUST NOT SHORTEN A LONGER ONE ALREADY OPEN. Two
  -- callers overlap all the time — the self-test posts its four keys
  -- while an expansion is still going out — and last-write-wins would let
  -- the shorter one end the longer one's suppression early, which is the
  -- injection bug this guard exists to prevent, one level up.
  SB.injectUntil = 0
  w.now = 1000
  SB.suppressTypingFor(1.0)          -- open until 1001.0
  SB.suppressTypingFor(0.1)          -- would close at 1000.1
  w.now = 1000.5
  check("...and a shorter window never shortens a longer one already open",
        SB.typingInjection() == true)
end

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
