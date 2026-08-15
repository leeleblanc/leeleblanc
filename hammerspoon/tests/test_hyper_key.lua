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

-- ---- §0.3's REAL hs.hotkey.bind wrapper ------------------------------
-- The global fallback can only be as correct as the table it reads, and
-- that table is filled by one wrapper in init.lua. Lifted and RUN for the
-- same reason as the blocks above: a test that hand-fills _G.globalDispatch
-- proves the dispatcher right about a table nothing produces.
local BLOCK_NORM = INIT_SRC:match(
  "(local function normalizeCombo%(mods, key%).-_G%.globalCombo = normalizeCombo)")
local BLOCK_STUB = INIT_SRC:match("(_G%.hyperBindStub = function%(%).-\nend)")
local BLOCK_WRAP = INIT_SRC:match(
  "(local hsHotkeyBindOriginal = hs%.hotkey%.bind.-\n    return _G%.hyperBindStub%(%)\nend)")
assert(BLOCK_NORM, "could not lift normalizeCombo/_G.globalCombo from init.lua")
assert(BLOCK_STUB, "could not lift _G.hyperBindStub from init.lua")
assert(BLOCK_WRAP, "could not lift the hs.hotkey.bind wrapper from init.lua")
-- normalizeCombo is a chunk-local, so the wrapper has to be in the SAME
-- chunk to see it. Concatenated in source order, exactly as init.lua has
-- them.
local BLOCK_GLOBALS = BLOCK_NORM .. "\n" .. BLOCK_STUB .. "\n" .. BLOCK_WRAP

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

local KEYCODES = { f18 = 79, f19 = 80, a = 0, d = 2, q = 12, x = 7,
                   l = 37, g = 5, escape = 53 }

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
    w.posts[#w.posts + 1] = { key = ev.key, down = ev.down, posted = ev.posted }
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
    -- 🚨 A POSTED EVENT DOES NOT REACH CARBON. This one line is the whole
    -- of 6.76.0's mistake: event taps see a synthesised keystroke exactly
    -- like a real one, Carbon's RegisterEventHotKey dispatch does not, so
    -- a probe built on hs.eventtap.event:post() read zero in the Carbon
    -- column on EVERY Mac and 6.76.0 read that zero as "Carbon is dead".
    -- The old stub delivered posted events to both layers, which is why
    -- 33 mutations and 98 checks all passed over a bug that misdiagnosed
    -- LL's Mac on the first boot.
    if ev.posted then return end
    if not w.carbon then return end
    -- 🚨 CARBON DISPATCHES ON THE RUN LOOP, NOT INSIDE THE TAP CALLBACK.
    -- The tap runs in the event stream and returns; the hotkey handler
    -- comes afterwards. Modelling it as a same-instant call would let a
    -- verification that checks the Carbon counter IMMEDIATELY look
    -- correct here and misdiagnose every Mac in the world — which is the
    -- exact class of stub-is-kinder-than-reality bug this file exists
    -- because of. 0.05 against the check's 0.25.
    w.hs.timer.doAfter(0.05, function()
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
    end)
  end
  w.deliver = deliver

  local function mkEvent(mods, key, down, autorepeat, posted)
    local flags = {}
    for _, m in ipairs(mods or {}) do flags[m] = true end
    local e = { down = down, key = key, mods = mods or {}, posted = posted }
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
        -- Everything built through the real API is POSTED, by definition.
        newKeyEvent = function(mods, key, down)
          return mkEvent(mods, key, down, false, true)
        end,
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

  -- §0.3's own state, then §0.3's own wrapper over hs.hotkey.bind.
  SB.globalDispatch = {}
  SB.hyperKeyMap, SB.hyperMigrations, SB.hyperMigrationsSeen = {}, {}, {}
  SB.hotkeyRegistry, SB.knownSystemCombos = {}, {}
  SB.hotkeyBoundCount, SB.hotkeyConflictCount = 0, 0
  load(BLOCK_GLOBALS, "init-bindWrapper", "t", SB)()

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
    -- In DELAY ORDER. A round that fires a 0.25s check before a 0.05s
    -- dispatch is a round in which "wait for Carbon" and "do not wait for
    -- Carbon" are the same program.
    table.sort(due, function(x, y) return (x.secs or 0) < (y.secs or 0) end)
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

-- 🚨 A REAL CAPS LOCK PRESS, delivered the way the Mac delivers one: down
-- the whole event chain, taps first and Carbon after. This is the ONLY
-- thing that verifies ⇪ from 6.79.0 on, so it is the only thing the
-- scenarios below use to trigger verification. Posting a synthetic key
-- and watching for Carbon is exactly what got a healthy Mac misdiagnosed.
local function pressCapsLock(w, runTimersFn)
  w.mkEvent({}, "f18", true, false, false).post()
  if runTimersFn then runTimersFn(w) end
  w.mkEvent({}, "f18", false, false, false).post()
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

  check("nothing is claimed before you have pressed the key",
        w.SB.hyperVerified == nil, tostring(w.SB.hyperVerified))

  pressCapsLock(w, runTimers)

  check("one real Caps Lock press proves the hyper key",
        w.SB.hyperVerified == true, tostring(w.SB.hyperVerified))
  check("...and names both paths, because both delivered F18",
        w.SB.hyperPath == "carbon + tap", tostring(w.SB.hyperPath))
  check("🚨 the event tap does NOT swallow F18 — Carbon still sees it, or "
     .. "the fallback would break the very Mac it is meant to leave alone",
        w.SB.hyperCarbonPresses == 1, w.SB.hyperCarbonPresses)
  check("...and the tap saw it too", w.SB.hyperTapPresses == 1,
        w.SB.hyperTapPresses)
  check("🚨 the Carbon-free dispatcher stays OFF when Carbon works — this "
     .. "is the regression 6.76.0 shipped, and it cost a working Mac the "
     .. "cheat sheet's type-to-filter and ⌥Tab's arrows",
        w.SB.hyperDispatchEngaged == false)
  check("nothing is shouted at a Mac where everything is fine",
        printedFinding(w, "🚨") == nil and printedFinding(w, "WITHOUT CARBON") == nil,
        printedFinding(w, "🚨") or printedFinding(w, "WITHOUT CARBON"))
  check("...and nothing reaches the screen", #w.told == 0, w.told[1])
  check("⇪ is not left latched after the press",
        w.SB.hyperActive == false)

  -- Once answered, it must cost nothing: this runs inside a keystroke.
  local timersBefore = #w.timers
  for _ = 1, 5 do pressCapsLock(w, runTimers) end
  check("🚨 ...and it never checks again — the check lives in a callback "
     .. "every keystroke goes through",
        w.SB.hyperRealChecks == 1, w.SB.hyperRealChecks)
end

-- =====================================================================
section("2. THE WORK MAC — F18 arrives, Carbon never fires")
-- =====================================================================
do
  local w = world{ carbon = false, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)
  pressCapsLock(w, runTimers)

  check("a real press with no Carbon behind it switches ⇪ to the "
     .. "event-tap dispatcher",
        w.SB.hyperDispatchEngaged == true)
  check("...and the hyper key is PROVEN, not counted",
        w.SB.hyperVerified == true, tostring(w.SB.hyperVerified))
  check("...named for the path actually carrying it",
        w.SB.hyperPath == "event tap (dispatcher)", tostring(w.SB.hyperPath))
  check("🚨 and it SAYS SO — this is a real difference between two Macs "
     .. "and rule 7 does not allow it to be silent",
        printedFinding(w, "WITHOUT CARBON") ~= nil)
  check("...naming the REAL press as the evidence, not a synthetic one",
        printedFinding(w, "real Caps Lock press") ~= nil)
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
  pressCapsLock(w, runTimers)
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
  pressCapsLock(w, runTimers)
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
section("5. WHEN THE KEY NEVER ARRIVES AT ALL")
-- =====================================================================
-- There is no real press to measure, so there is nothing to conclude —
-- and saying so is the honest answer. "Not yet known" is reported by the
-- boot line and by ⇪⇧D; what must NEVER happen is a confident claim in
-- either direction on no evidence.
do
  local w = world{ carbon = false, tapKeys = false }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)
  pressCapsLock(w, runTimers)

  check("🚨 no evidence produces no verdict, in either direction",
        w.SB.hyperVerified == nil, tostring(w.SB.hyperVerified))
  check("...and the dispatcher is NOT engaged on a guess",
        w.SB.hyperDispatchEngaged == false)
  check("...and nothing is claimed on screen", #w.told == 0, w.told[1])
  check("the unproven state is the one the boot line and ⇪⇧D report",
        w.SB.hyperSelfTestPending == true)
end

-- =====================================================================
section("6. THE PROBE IS A DIAGNOSTIC NOW, NOT A DECISION")
-- =====================================================================
-- 🚨 6.76.0 posted a synthetic F18 and treated a silent Carbon as proof
-- that Carbon was dead. It is not proof: a posted CGEvent does not
-- reliably reach Carbon's hotkey dispatch, so the Carbon column read zero
-- on EVERY Mac. LL's MacBook Air — where ⇪ has worked for sixty releases
-- — was switched onto the fallback by it, losing the cheat sheet's
-- type-to-filter and ⌥Tab's arrows in the process.
do
  local w = world{ carbon = true, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)

  -- The world that caused the bug: Carbon works, but posted events do
  -- not reach it, so the probe sees exactly what it saw on LL's Mac.
  w.SB.hyperSelfTest()
  runTimers(w)

  check("the probe still reports what each layer saw",
        (w.SB.hyperSelfTestResult or {}).tap == 1,
        (w.SB.hyperSelfTestResult or {}).tap)
  check("🚨 ...but it CHANGES NOTHING. A silent Carbon column here is not "
     .. "evidence, and acting on it is what misdiagnosed a healthy Mac",
        w.SB.hyperDispatchEngaged == false and w.SB.hyperVerified == nil,
        tostring(w.SB.hyperDispatchEngaged) .. "/" .. tostring(w.SB.hyperVerified))
  check("...and it says so in the output rather than leaving you to infer it",
        printedFinding(w, "proves NOTHING") ~= nil)
  check("🚨 the probe never leaves ⇪ latched on",
        w.SB.hyperActive == false and w.modal.entered == false)

  -- and the real press still decides, afterwards
  pressCapsLock(w, runTimers)
  check("the real press is what settles it, probe or no probe",
        w.SB.hyperVerified == true and w.SB.hyperPath == "carbon + tap",
        tostring(w.SB.hyperPath))
end

do
  local w = world{ carbon = true, tapKeys = true, tapNewThrows = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)

  check("a Mac that refuses the event tap still boots", w.SB.hyperKeyTap == nil)
  check("...and says the fallback is missing rather than dropping it quietly",
        printedFinding(w, "could not start") ~= nil)
  check("🚨 ...and admits ⇪ can no longer be VERIFIED either, because the "
     .. "check lives inside that tap",
        printedFinding(w, "no longer be verified") ~= nil)
end

-- =====================================================================
section("7. THE TAP STANDS DOWN RATHER THAN DEGRADE THE KEYBOARD")
-- =====================================================================
do
  local w = world{ carbon = false, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)
  pressCapsLock(w, runTimers)
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
        and waiting:find("Caps Lock press", 1, true) ~= nil, waiting)
  check("...and does not promise a proof on a Mac with the hyper key off",
    (function()
      local off = bootLines(false)
      return off:find("All green", 1, true) ~= nil
             and off:find("Caps Lock press", 1, true) == nil
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


-- =====================================================================
section("11. THE PLAIN GLOBAL HOTKEYS RIDE THE SAME TAP")
-- =====================================================================
-- 🚨 6.76.0 rescued ⇪ and left everything else where it found it, with a
-- line in the GUIDE admitting so. That was a report, not a fix — and it
-- left a TRAP: ⇪/ opens a full-screen cheat sheet whose Escape is a
-- Carbon hotkey. A panel you can open and cannot close is worse than one
-- you cannot open.
do
  local w = world{ carbon = false, tapKeys = true }
  local fired = {}
  -- Through the REAL §0.3 wrapper, which is what fills _G.globalDispatch.
  w.SB.hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "L",
      function() fired[#fired + 1] = "ctrl-alt-cmd-L" end,
      function() fired[#fired + 1] = "L-up" end,
      function() fired[#fired + 1] = "L-repeat" end)
  w.SB.hs.hotkey.bind({ "cmd", "ctrl", "alt", "shift" }, "X",
      function() fired[#fired + 1] = "VEIL ESCAPE" end)

  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)
  pressCapsLock(w, runTimers)
  timePasses(w)
  local tap = w.taps[1]

  check("a standalone hs.hotkey.bind is recorded where the tap can find it",
        w.SB.globalDispatch["alt+cmd+ctrl+l"] ~= nil,
        (function() local n = {} for k in pairs(w.SB.globalDispatch) do n[#n+1] = k end
                    table.sort(n); return table.concat(n, " ") end)())
  check("🚨 ...and a ⇪ MODAL binding is not, because a table consulted "
     .. "while ⇪ is NOT held must never contain a bare letter",
        w.SB.globalDispatch["+d"] == nil and w.SB.globalDispatch["d"] == nil)

  fired = {}
  check("⌃⌥⌘L runs on a Mac with no working hotkey layer",
        tap.fn(w.mkEvent({ "ctrl", "alt", "cmd" }, "l", true)) == true
        and fired[1] == "ctrl-alt-cmd-L", fired[1])
  fired = {}
  check("...and its release handler runs on the way up",
        tap.fn(w.mkEvent({ "ctrl", "alt", "cmd" }, "l", false)) == true
        and fired[1] == "L-up", fired[1])
  fired = {}
  check("...and a held key runs the repeat handler",
        tap.fn(w.mkEvent({ "ctrl", "alt", "cmd" }, "l", true, true)) == true
        and fired[1] == "L-repeat", fired[1])

  fired = {}
  check("an unbound chord is passed straight through",
        tap.fn(w.mkEvent({ "ctrl", "cmd" }, "q", true)) == false and #fired == 0)

  -- 🚨 RAIL 1. This branch runs while you are ordinarily typing.
  w.SB.globalDispatch["+d"] = { pressed = function() fired[#fired + 1] = "BARE" end }
  fired = {}
  check("🚨 a bare key is NEVER dispatched from the global table — this "
     .. "branch runs while you are typing, and a letter that ran a "
     .. "shortcut instead of typing itself is the worst outcome here",
        tap.fn(w.mkEvent({}, "d", true)) == false and #fired == 0, fired[1])
  w.SB.globalDispatch["+d"] = nil

  -- 🚨 RAIL 2. The forwarded chord echoes back through this same tap.
  fired = {}
  w.SB.hyperForwardChord("x")           -- stamps _G.hyperChordUntil
  check("🔁 the echo of a forwarded ⌘⇧⌃⌥ chord is refused, so releasing ⇪ "
     .. "mid-forward cannot fire the chord's global hotkey",
        tap.fn(w.mkEvent({ "cmd", "ctrl", "alt", "shift" }, "x", true)) == false
        and #fired == 0, fired[1])
  timePasses(w, 1)
  fired = {}
  check("...and once the echo window has passed, the same chord pressed by "
     .. "hand works normally",
        tap.fn(w.mkEvent({ "cmd", "ctrl", "alt", "shift" }, "x", true)) == true
        and fired[1] == "VEIL ESCAPE", fired[1])

  -- the injection guard applies here too
  fired = {}
  w.SB.withInjection(function()
    check("an injected chord never fires a global hotkey either",
          tap.fn(w.mkEvent({ "ctrl", "alt", "cmd" }, "l", true)) == false
          and #fired == 0, fired[1])
  end)
end

do
  local w = world{ carbon = true, tapKeys = true }
  local fired = {}
  w.SB.hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "L",
      function() fired[#fired + 1] = "L" end)
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)
  timePasses(w)
  check("🚨 on a Mac where Carbon works the tap does NOT also run globals "
     .. "— that would fire every one of them twice",
        w.taps[1].fn(w.mkEvent({ "ctrl", "alt", "cmd" }, "l", true)) == false
        and #fired == 0, fired[1])
end

-- =====================================================================
section("12. ESCAPE IS RESCUED, so nothing can trap you")
-- =====================================================================
do
  local w = world{ carbon = false, tapKeys = true }
  loadHyperKey(w)
  bindShortcuts(w)
  runTimers(w)
  pressCapsLock(w, runTimers)
  timePasses(w)
  local tap = w.taps[1]

  check("Escape with no panel open is left alone — it belongs to the app",
        tap.fn(w.mkEvent({}, "escape", true)) == false)

  local closed = 0
  w.SB.routeEscape = function() closed = closed + 1; return "cheatsheet" end
  check("🚨 Escape reaches whichever panel claims it, so ⇪/ can never open "
     .. "a sheet that Carbon is too dead to close",
        tap.fn(w.mkEvent({}, "escape", true)) == true and closed == 1, closed)

  closed = 0
  w.SB.routeEscape = function() closed = closed + 1; return nil end
  check("...and when nothing wants it, it is passed through rather than "
     .. "eaten", tap.fn(w.mkEvent({}, "escape", true)) == false and closed == 1)

  w.SB.routeEscape = function() error("router is broken", 0) end
  check("🛟 a router that throws costs the Escape, not the keyboard",
        tap.fn(w.mkEvent({}, "escape", true)) == false)

  w.SB.routeEscape = function() return "cheatsheet" end
  check("⇧Escape and ⌘Escape are not the panel Escape and stay untouched",
        tap.fn(w.mkEvent({ "shift" }, "escape", true)) == false)
end

-- =====================================================================
section("13. THE FORWARDED CHORD IS STAMPED BEFORE IT IS SENT")
-- =====================================================================
do
  local w = world{ carbon = false, tapKeys = true }
  loadHyperKey(w)
  runTimers(w)
  pressCapsLock(w, runTimers)
  timePasses(w)
  w.SB.hyperMods = { "cmd", "shift", "ctrl", "alt" }
  w.SB.hyperChordUntil = 0
  w.SB.hyperForwardChord("g")
  check("forwarding writes down when it happened",
        w.SB.hyperChordUntil > (w.now or 0), w.SB.hyperChordUntil)
  check("...and the window is short enough to be over before you could "
     .. "press the same chord by hand", w.SB.hyperChordGrace <= 0.5,
        w.SB.hyperChordGrace)

  local code = {}
  for line in (INIT_SRC .. "\n"):gmatch("([^\n]*)\n") do
    code[#code + 1] = line:match("^%s*%-%-") and "" or line
  end
  local initCode = table.concat(code, "\n")
  check("🚨 §3.12 forwards THROUGH that helper rather than calling "
     .. "keyStroke straight, or the stamp would never be written",
        initCode:find("_G.hyperForwardChord(key)", 1, true) ~= nil)
  check("...with a plain send still behind it, so forwarding never depends "
     .. "on core/hyper_key.lua having loaded",
        initCode:find("if _G.hyperForwardChord then", 1, true) ~= nil
        and initCode:find("hs.eventtap.keyStroke(_G.hyperMods, key,", 1, true) ~= nil)
end

-- =====================================================================
section("14. THE CHANGELOG CSV CANNOT GO STALE AGAIN")
-- =====================================================================
-- It sat on 6.63.0 for thirteen releases: version, date and the whole
-- notes paragraph were hard-coded, so the file quietly stopped describing
-- the config while continuing to look like it did.
do
  local dir = os.tmpname(); os.remove(dir); os.execute("mkdir -p '" .. dir .. "'")
  local written = {}
  local function runCsv(version, configdir)
    local SB = {
      hs = { configdir = configdir or HS }, io = io, os = os,
      print = function(...)
        local p2 = {}
        for i = 1, select("#", ...) do p2[#p2 + 1] = tostring((select(i, ...))) end
        written[#written + 1] = table.concat(p2, " ")
      end,
      tostring = tostring, pairs = pairs, ipairs = ipairs, type = type,
      string = string, table = table,
    }
    SB._G = SB
    SB.configVersion = version
    local chunk = assert(loadfile(HS .. "/core/changelog_csv.lua", "t", SB))
    chunk()({ logsDir = dir,
              csvQuote = function(v) return '"' .. tostring(v):gsub('"', '""') .. '"' end })
  end

  runCsv("6.76.0")
  local f = io.open(dir .. "/changelog.csv", "r")
  local body = f and f:read("*a") or ""
  if f then f:close() end
  check("the row is written from CHANGELOG.md, not from a string somebody "
     .. "has to remember to retype",
        body:find("6.76.0", 1, true) ~= nil
        and body:find("HYPER KEY", 1, true) ~= nil, body:sub(1, 120))
  check("...with a header on a brand new file",
        body:sub(1, 4) == "Date")
  check("...and the notes are one CSV cell, newlines flattened",
        select(2, body:gsub("\n", "")) == 2, select(2, body:gsub("\n", "")))

  written = {}
  runCsv("6.76.0")
  local f2 = io.open(dir .. "/changelog.csv", "r")
  local again = f2 and f2:read("*a") or ""
  if f2 then f2:close() end
  check("🚨 a second boot on the same version appends nothing",
        again == body, #again .. " vs " .. #body)

  written = {}
  runCsv("9.99.0")
  check("🚨 a version with NO CHANGELOG.md entry is REPORTED, not written "
     .. "as a blank row — the exact silence that let it sit on 6.63.0",
    (function()
      for _, l in ipairs(written) do
        if l:find("no CHANGELOG.md entry", 1, true) then return true end
      end
      return false
    end)(), written[1])
  local f3 = io.open(dir .. "/changelog.csv", "r")
  local after = f3 and f3:read("*a") or ""
  if f3 then f3:close() end
  check("...and really writes nothing", after == body)

  written = {}
  runCsv("6.75.0", "/nonexistent")
  check("🛟 an unreadable CHANGELOG.md degrades to a message, not a throw",
    (function()
      for _, l in ipairs(written) do
        if l:find("no CHANGELOG.md entry", 1, true) then return true end
      end
      return false
    end)())

  os.execute("rm -rf '" .. dir .. "'")
end

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
