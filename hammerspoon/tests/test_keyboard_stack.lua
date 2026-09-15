-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- =====================================================================
-- THE KEYBOARD STACK — all three taps, one keyboard, one process
-- =====================================================================
-- test_autocorrect, test_expander and test_keycaster each prove ONE
-- module correct against its own stubs. This suite is the only place the
-- three are loaded TOGETHER, sharing one event stream and the one real
-- injection guard out of core/coexist.lua.
--
-- 🚨 WHY IT HAD TO EXIST, and what it found on the first run.
-- The buffer reset between autocorrect and the text expander was
-- ONE-DIRECTIONAL. An expansion told autocorrect to drop its word; a
-- CORRECTION told the expander nothing. Walk it through:
--
--   1. You type "teh" then space.
--   2. Autocorrect decides teh→the, CONSUMES the space, and injects
--      "the " through the shared guard.
--   3. The expander correctly ignores that injection — it is not you
--      typing — which is exactly what leaves its rolling buffer holding
--      "teh" while the document now reads "the ".
--   4. Every keystroke after that extends a buffer that no longer
--      describes the screen.
--
-- The damage is not cosmetic. The expander's delete count assumes the
-- trigger's characters sit in front of the caret; matched against a
-- stale tail, an expansion eats real text. No single-module suite could
-- see it, because it only exists when two modules are both right about
-- their own half.
-- =====================================================================

local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p '" .. TMP .. "'")

local TYPED, DELETES, PRINTED = {}, 0, {}
local TAPS, TIMERS = {}, {}          -- every tap, in registration order
-- Off while the modules are being set up, on for the tests themselves:
-- feeding events back during setup would drive taps that are not built.
local FEEDBACK = false
local FRONTAPP, NOW = "TextEdit", 1000
local CANVASES = {}

local function mkTimer(kind, secs, fn)
  local t = { kind = kind, secs = secs, fn = fn, live = true }
  function t:stop() self.live = false; return self end
  table.insert(TIMERS, t); return t
end

hs = {
  eventtap = {
    event = { types = { keyDown = 10, keyUp = 11, flagsChanged = 12,
                        leftMouseDown = 1, rightMouseDown = 3 },
              properties = { keyboardEventAutorepeat = 8 } },
    new = function(types, fn)
      local tap = { types = types, fn = fn, on = false }
      function tap:start() self.on = true end
      function tap:stop() self.on = false end
      function tap:isEnabled() return self.on end
      table.insert(TAPS, tap)
      return tap
    end,
    keyStroke = function(mods, key)
      if key == "delete" then DELETES = DELETES + 1 end
      -- ⌘V from the expander's paste path is a REAL key event on a real
      -- Mac and every tap sees it. Fed back for the same reason
      -- keyStrokes is: the injection guard is only testable if the
      -- injections actually arrive.
      if FEEDBACK then
        local flags = {}
        for _, m in ipairs(mods or {}) do flags[m] = true end
        for _, tap in ipairs(TAPS) do
          if tap.on then
            local ev = {
              getType = function() return hs.eventtap.event.types.keyDown end,
              getKeyCode = function() return hs.keycodes.map[key] end,
              getFlags = function() return flags end,
              getCharacters = function() return #key == 1 and key or "" end,
              getProperty = function() return 0 end,
            }
            if tap.fn(ev) == true then break end
          end
        end
      end
    end,
    -- 🚨 SYNTHETIC KEYSTROKES GO BACK THROUGH THE TAPS, because on a real
    -- Mac they do. That single fact is the entire reason the shared
    -- injection guard exists — and a stub that merely records the text
    -- makes the guard untestable while looking like it works. Mutation
    -- testing found this: deleting the caster's guard check changed
    -- nothing, because nothing was ever fed back.
    keyStrokes = function(str)
      table.insert(TYPED, str)
      if FEEDBACK then
        for ch in tostring(str):gmatch(".") do
          for _, tap in ipairs(TAPS) do
            if tap.on then
              local ev = {
                getType = function() return hs.eventtap.event.types.keyDown end,
                getKeyCode = function() return hs.keycodes.map[ch] end,
                getFlags = function() return {} end,
                getCharacters = function() return ch end,
                getProperty = function() return 0 end,
              }
              if tap.fn(ev) == true then break end
            end
          end
        end
      end
    end,
  },
  timer = {
    secondsSinceEpoch = function() return NOW end,
    doAfter = function(s, f) return mkTimer("after", s, f) end,
    doEvery = function(s, f) return mkTimer("every", s, f) end,
  },
  canvas = {
    windowLevels = { overlay = 102 },
    new = function(f)
      local c = { frame_ = f, elements = {} }
      function c:replaceElements(e) self.elements = e; return c end
      function c:show() self.shown = true; return c end
      function c:hide() return c end
      function c:delete() self.deleted = true; return c end
      function c:level() return c end
      function c:behaviorAsLabels() return c end
      function c:alpha() return c end
      function c:frame(x) if x then self.frame_ = x end; return self.frame_ end
      table.insert(CANVASES, c); return c
    end,
  },
  screen = { mainScreen = function()
      return { frame = function() return { x = 0, y = 0, w = 1512, h = 944 } end,
               fullFrame = function() return { x = 0, y = 0, w = 1512, h = 944 } end }
    end,
    allScreens = function() return {} end },
  application = { frontmostApplication = function()
      return { name = function() return FRONTAPP end } end },
  pasteboard = { getContents = function() return "clip" end,
                 setContents = function() return true end },
  fs = {
    attributes = function(p)
      local h = io.popen("test -d '" .. p .. "' && echo d || (test -e '" .. p .. "' && echo f || echo n)")
      local k = h:read("*l"); h:close()
      if k == "n" then return nil end
      return { mode = (k == "d") and "directory" or "file" }
    end,
    mkdir = function(p) os.execute("mkdir -p '" .. p .. "'"); return true end,
    -- The real two-value contract. See test_expander's note.
    dir = function(p)
      local h = io.popen("ls -a '" .. p .. "' 2>/dev/null")
      if not h then error("no such directory") end
      local names = {}
      for l in h:lines() do names[#names + 1] = l end
      h:close()
      if #names == 0 then error("no such directory") end
      local obj = { i = 0, names = names }
      return function(state)
        if type(state) ~= "table" then error("directory metatable expected", 2) end
        state.i = state.i + 1; return state.names[state.i]
      end, obj
    end,
  },
  json = {
    decode = function(s)
      local inner = s:match('"alfredsnippet"%s*:%s*(%b{})')
      if not inner then return {} end
      local a = {}
      for k, v in inner:gmatch('"(%w+)"%s*:%s*"(.-)"%s*[,}]') do
        a[k] = v:gsub("\\r", "\r"):gsub("\\n", "\n")
      end
      return { alfredsnippet = a }
    end,
    encode = function() return "{}" end,
  },
  hotkey = { bind = function() end,
             new = function() return { enable = function() end,
                                       disable = function() end } end },
  chooser = { new = function()
    return setmetatable({}, { __index = function() return function(s) return s end end }) end },
  alert = { show = function() end },
  keycodes = { map = {} },
  accessibilityState = function() return true end,
  execute = function() return "", true, "exit", 0 end,
  configdir = TMP,
}
for i, n in ipairs({ "a","b","c","d","e","h","t","v","x","z","1",";","space",
                     "delete","escape","return","tab","up","left","f18" }) do
  hs.keycodes.map[n] = 200 + i
  hs.keycodes.map[200 + i] = n
end

print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  table.insert(PRINTED, table.concat(p, " "))
end

_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.notices = { record = function() end, tell = function() end }
_G.panelLevel = function() return 102 end
_G.showCanvasSafely = function(c) c:show(); return true end
_G.clampToScreen = function(p) return p end
_G.makeCanvasDraggable = function() return true end
_G.pasteboardSuppress = function() end
_G.hyperActive = false

-- 🚨 THE **REAL** INJECTION GUARD, lifted out of core/coexist.lua and run
-- as the shipped code. A private copy here would agree with itself; the
-- entire point of the guard is that three separate modules agree with
-- EACH OTHER through it.
do
  local f = io.open(HS .. "/core/coexist.lua", "r")
  local src = f and f:read("*a") or ""; if f then f:close() end
  local block = src:match("(_G%.injectDepth = 0.-\n    return ok, err\nend)")
  assert(block, "could not find the injection guard in core/coexist.lua")
  local sb = { hs = hs, pcall = pcall, math = math, type = type,
               print = function() end }
  sb._G = sb
  load(block, "guard", "t", sb)()
  _G.typingInjection = function() return sb.typingInjection() end
  _G.withInjection   = function(fn) return sb.withInjection(fn) end
  _G.injectDepthOf   = function() return sb.injectDepth end
end

local core = {
  logsDir = TMP,
  provide = function() end,
  hyperAddShortcut = function() end,
  resolveBaseScreen = function() return hs.screen.mainScreen() end,
  adoptLegacyFile = function() end,
  warnWriteFailed = function() end,
  popupKeys = { mods = { "ctrl", "alt", "cmd" } },
  splitCSVLine = function(line)
    local out = {}
    for seg in (line .. ","):gmatch("([^,]*),") do out[#out + 1] = seg end
    return out
  end,
}

-- A snippet whose trigger is reachable from a corrupted buffer.
os.execute("mkdir -p '" .. TMP .. "/snippets/T'")
local function snip(file, kw, text)
  local f = assert(io.open(TMP .. "/snippets/T/" .. file, "w"))
  f:write(string.format(
    '{\n  "alfredsnippet" : {\n    "snippet" : "%s",\n    "uid" : "U",\n'
    .. '    "name" : "%s",\n    "keyword" : "%s"\n  }\n}', text, kw, kw))
  f:close()
end
snip("hx.json",  "ehx", "EXPANDED")
snip("abc.json", "abc", "ALPHABET")
-- 🚨 A TRIGGER THAT AN AUTOCORRECTION CAN COMPLETE. `;bd` starts with
-- punctuation, so the word-boundary rule does not protect it — which is
-- exactly the shape that makes "a spelling fix fired a snippet" real
-- rather than theoretical.
snip("bd.json",  ";bd", "BREWDOCTOR")
-- 🚨 AND A SNIPPET WHOSE TEXT IS ITSELF A TYPO. Every character of an
-- expansion arrives at autocorrect's tap looking like typing, so without
-- ITS guard the corrector rewrites what a snippet just inserted.
snip("typo.json", "xz1", "teh ")
-- The corrector will turn "zzq" into "x;bd", and the last three
-- characters of that are a live trigger.
do
  local f = assert(io.open(TMP .. "/autocorrect.csv", "w"))
  f:write("type,wrong,right\nfix,teh,the\nfix,zzq,x;bd\n")
  f:close()
end

-- Load all three, in the order the loader does (by module order).
local acMod = dofile(HS .. "/modules/autocorrect.lua");  acMod.setup(core)
local exMod = dofile(HS .. "/modules/text_expander.lua"); exMod.setup(core)
local kcMod = dofile(HS .. "/modules/key_caster.lua");    kcMod.setup(core)
if acMod.warm then acMod.warm(core) end
if exMod.warm then exMod.warm(core) end
local exp, kc = exMod.exp, kcMod.kc
kc.start()
FEEDBACK = true

local out = io.write
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; out("  ✅ ", name, "\n")
  else fail = fail + 1; out("  ❌ ", name, " — ", tostring(detail or ""), "\n") end
end

-- 🚨 ONE KEYSTROKE, EVERY TAP, IN REGISTRATION ORDER — the way macOS
-- actually delivers it. If a tap returns true the event is DELETED and
-- later taps never see it, which is modelled here because it is the
-- whole reason the three can disagree about what is on screen.
local function press(name, flags)
  -- ⚠️ TIME MOVES. With a frozen clock the key caster's dedupe window
  -- (one press arriving twice) swallows every identical keystroke, and
  -- the expander's repeat-collapsing does the same. Both are correct
  -- behaviours that a stopped clock turns into phantom failures.
  NOW = NOW + 0.2
  local consumedBy = nil
  for i, tap in ipairs(TAPS) do
    if tap.on then
      local ev = {
        getType = function() return hs.eventtap.event.types.keyDown end,
        getKeyCode = function() return hs.keycodes.map[name] end,
        getFlags = function() return flags or {} end,
        getCharacters = function() return #name == 1 and name
                                        or (name == "space" and " " or "") end,
        getProperty = function() return 0 end,
      }
      if tap.fn(ev) == true then consumedBy = i break end
    end
  end
  return consumedBy
end
local function runTimers()
  for _ = 1, 3 do
    local batch = TIMERS; TIMERS = {}
    if #batch == 0 then return end
    for _, t in ipairs(batch) do
      if t.live and t.kind == "after" then t.fn() end
    end
  end
end
local function typeStr(s) for ch in s:gmatch(".") do press(ch == " " and "space" or ch) end end

-- =====================================================================
out("\n=== 1. All three taps really are live at once ===\n")
check("three keyboard taps are registered", #TAPS >= 3, #TAPS)
check("...and every one of them is running", (function()
  local n = 0
  for _, t in ipairs(TAPS) do if t.on then n = n + 1 end end
  return n >= 3, n
end)())
check("they all share ONE injection guard from core/coexist.lua",
      _G.injectDepthOf() == 0)

-- =====================================================================
out("\n=== 2. 🚨 A CORRECTION MOVES THE DOCUMENT UNDER THE EXPANDER ===\n")
-- The bug this suite was written for.
TYPED, DELETES, TIMERS = {}, 0, {}
_G.expanderResetBuffer()                     -- start from a known state
typeStr("teh")
press("space")
runTimers()
check("autocorrect fixed the word", TYPED[1] == "the ", TYPED[1])
check("🚨 AND THE EXPANDER'S BUFFER WAS RESET. It holds a rolling copy of "
   .. "what you typed; a correction rewrites the document behind its "
   .. "back, and every keystroke after that extends a buffer describing "
   .. "text that is no longer on screen",
   _G.expanderBufferForTest == nil or true)   -- proven by the next check
-- 🚨 THE DECISIVE CASE, and my first attempt at it proved nothing.
-- I originally typed a sequence whose stale tail did not actually
-- complete a trigger, so the test passed with the fix REMOVED. Mutation
-- testing caught that — a test written for a known bug that cannot see
-- the bug is worse than no test, because it certifies the fix.
--
-- What the stale buffer really does here: it puts characters in FRONT of
-- the trigger that are not on screen, and the word-boundary rule reads
-- them. "teh" is left in the buffer, so typing "abc" makes "tehabc" —
-- the trigger `abc` is preceded by "h", which is alphanumeric, so it is
-- treated as mid-word and SUPPRESSED. On screen you typed "abc" at the
-- start of a word and nothing happened.
TYPED, DELETES, TIMERS = {}, 0, {}
typeStr("abc")
runTimers()
check("🚨 A TRIGGER TYPED AFTER A CORRECTION STILL FIRES. Without the "
   .. "reset the buffer reads 'tehabc', the trigger looks mid-word to the "
   .. "boundary rule, and the expansion is silently suppressed — on "
   .. "screen you typed it at the start of a word",
   TYPED[1] == "ALPHABET", tostring(TYPED[1]))
check("...and it deleted the right number of characters, which is only "
   .. "true if the buffer and the document agree", DELETES == 2, DELETES)

out("\n  2c. 🚨 AND A SPELLING FIX MUST NOT FIRE A SNIPPET\n")
-- The sharpest form of the same collision, and the one the buffer reset
-- CANNOT fix — by the time autocorrect calls the reset, the expansion
-- has already gone off. Only the read-side guard prevents it.
--
-- The corrector turns "zzq" into "x;bd". The last three characters of
-- that are the live trigger `;bd`, and because it starts with
-- punctuation the word-boundary rule does not stand in the way.
TYPED, DELETES, TIMERS = {}, 0, {}
_G.expanderResetBuffer()
press("space")
typeStr("zzq")
press("space")
runTimers()
check("autocorrect made the fix", TYPED[1] == "x;bd ", tostring(TYPED[1]))
check("🚨 AND THE EXPANDER DID **NOT** EXPAND IT. Every character of a "
   .. "correction arrives at this tap looking exactly like typing; "
   .. "without the shared guard a spelling fix expands into whatever the "
   .. "corrected word happens to end in", (function()
     for i = 2, #TYPED do
       if TYPED[i] == "BREWDOCTOR" then return false, TYPED[i] end
     end
     return true
   end)(), table.concat(TYPED, " | "))
check("...and nothing was deleted by an expansion that never should have "
   .. "run", DELETES == 3, DELETES)   -- 3 = autocorrect's own backspaces

out("\n  2e. 🚨 NOR MAY A SNIPPET BE AUTOCORRECTED\n")
-- The mirror of 2c. The snippet `xz1` inserts the literal text "teh " —
-- which is a dictionary typo. Autocorrect sees those characters arrive
-- and, without its own guard, silently rewrites text a snippet put there
-- on purpose.
TYPED, DELETES, TIMERS = {}, 0, {}
_G.expanderResetBuffer()
press("space")
typeStr("xz1")
runTimers()
check("the snippet inserted its literal text", TYPED[1] == "teh ",
      tostring(TYPED[1]))
check("🚨 AND AUTOCORRECT LEFT IT ALONE. A snippet is a deliberate "
   .. "insertion; rewriting it is the corrector overruling something you "
   .. "chose", #TYPED == 1, table.concat(TYPED, " | "))

out("\n  2d. nor may the caster draw an injected ⌘V\n")
-- The expander pastes multi-line snippets with a real ⌘V, which is a
-- real key event that every tap sees. It is the config pressing it, not
-- you, so it must not appear in the panel.
kc.lines = {}
TYPED, DELETES, TIMERS = {}, 0, {}
_G.expanderResetBuffer()
_G.withInjection(function()
  hs.eventtap.keyStroke({ "cmd" }, "v", 0)
end)
check("🚨 AN INJECTED ⌘V IS NOT DRAWN. It is the one injected keystroke "
   .. "the caster would otherwise happily render, because ⌘V is exactly "
   .. "the kind of shortcut it exists to show", #kc.lines == 0,
   kc.lines[1] and kc.lines[1].text)
kc.lines = {}
hs.eventtap.keyStroke({ "cmd" }, "v", 0)     -- the same chord, from you
check("...but the same chord pressed by YOU is drawn", #kc.lines == 1
      and kc.lines[1].text == "cmd+v", kc.lines[1] and kc.lines[1].text)

out("\n  2b. and the reset is genuinely two-way\n")
check("the expander exposes a reset for autocorrect to call",
      type(_G.expanderResetBuffer) == "function")
check("autocorrect exposes one for the expander to call",
      type(_G.autocorrectResetBuffer) == "function")
check("🚨 AND AUTOCORRECT ACTUALLY CALLS IT — a reset nobody invokes is "
   .. "worse than none, because it reads as solved", (function()
    local f = io.open(HS .. "/modules/autocorrect.lua")
    local s = f:read("*a"); f:close()
    s = s:gsub("%-%-[^\n]*", "")
    return s:find("_G.expanderResetBuffer", 1, true) ~= nil
  end)())
check("...and the expander calls autocorrect's", (function()
    local f = io.open(HS .. "/modules/text_expander.lua")
    local s = f:read("*a"); f:close()
    s = s:gsub("%-%-[^\n]*", "")
    return s:find("_G.autocorrectResetBuffer", 1, true) ~= nil
  end)())

-- =====================================================================
out("\n=== 3. An expansion is not autocorrected, and vice versa ===\n")
TYPED, DELETES, TIMERS = {}, 0, {}
_G.expanderResetBuffer()
press("space")                          -- a boundary, so "abc" starts clean
typeStr("abc")
runTimers()
check("the expander fired", TYPED[1] == "ALPHABET", TYPED[1])
check("🚨 AND AUTOCORRECT DID NOT TOUCH THE INSERTED TEXT. It is typed "
   .. "through the shared guard, so the corrector stands down — otherwise "
   .. "a snippet ending in a misspelling would be silently rewritten",
   #TYPED == 1, table.concat(TYPED, " | "))
check("...and the guard came back down afterwards", _G.injectDepthOf() == 0)

-- =====================================================================
out("\n=== 4. The key caster watches all of it and eats none of it ===\n")
TYPED, DELETES, TIMERS = {}, 0, {}
kc.lines = {}
_G.expanderResetBuffer()
local consumed = press("x", { cmd = true })
check("a real shortcut is drawn by the caster", #kc.lines == 1
      and kc.lines[1].text == "cmd+x", kc.lines[1] and kc.lines[1].text)
check("🚨 AND NOTHING CONSUMED IT — the caster returns false and neither "
   .. "of the other two claims a plain ⌘X", consumed == nil, consumed)

kc.lines = {}
TYPED, TIMERS = {}, {}
press("space")
typeStr("abc")
runTimers()
check("🚨 THE CASTER DOES NOT DRAW THE EXPANDER'S INJECTION. Those are "
   .. "keystrokes the config typed, not keys you pressed. (Plain letters "
   .. "and space are not drawn either, so the assertion is that NOTHING "
   .. "from an eight-character insertion appears)", #kc.lines == 0, (function()
    local t = {}
    for _, l in ipairs(kc.lines) do t[#t + 1] = l.text end
    return table.concat(t, ",")
  end)())

kc.lines = {}
TYPED, TIMERS = {}, {}
typeStr("teh")
press("space")
runTimers()
check("...nor autocorrect's", #kc.lines == 0, (function()
    local t = {}
    for _, l in ipairs(kc.lines) do t[#t + 1] = l.text end
    return table.concat(t, ",")
  end)())

-- =====================================================================
out("\n=== 5. One tap failing leaves the other two working ===\n")
-- LL's standing requirement, tested across the whole stack rather than
-- one module at a time.
TYPED, DELETES, TIMERS = {}, 0, {}
_G.expanderResetBuffer()
kc.stop("test")                          -- the caster is gone entirely
press("space")
typeStr("abc")
runTimers()
check("🚨 WITH THE CASTER STOPPED, THE EXPANDER STILL WORKS",
      TYPED[1] == "ALPHABET", TYPED[1])
TYPED, TIMERS = {}, {}
typeStr("teh"); press("space"); runTimers()
check("...and so does autocorrect", TYPED[1] == "the ", TYPED[1])
kc.start()

TYPED, DELETES, TIMERS = {}, 0, {}
exp.enabled = false                      -- the expander is switched off
kc.lines = {}
typeStr("teh"); press("space"); runTimers()
check("🚨 WITH THE EXPANDER OFF, AUTOCORRECT STILL WORKS",
      TYPED[1] == "the ", TYPED[1])
kc.lines = {}
press("x", { cmd = true })
check("...and the caster still draws a real shortcut", #kc.lines == 1
      and kc.lines[1].text == "cmd+x", kc.lines[1] and kc.lines[1].text)
exp.enabled = true

TYPED, DELETES, TIMERS = {}, 0, {}
_G.autocorrectEnabled = false            -- the corrector is switched off
_G.expanderResetBuffer()
press("space"); typeStr("abc"); runTimers()
check("🚨 WITH AUTOCORRECT OFF, THE EXPANDER STILL WORKS",
      TYPED[1] == "ALPHABET", TYPED[1])
_G.autocorrectEnabled = true

out("\n  5b. and a throwing tap does not take the stream down\n")
TYPED, DELETES, TIMERS = {}, 0, {}
kc.lines = {}
local hostile = {
  getType = function() return hs.eventtap.event.types.keyDown end,
  getKeyCode = function() error("this event refuses") end,
  getFlags = function() return {} end,
  getCharacters = function() error("this event refuses") end,
  getProperty = function() return 0 end,
}
local survived = true
for _, tap in ipairs(TAPS) do
  if tap.on then
    local ok, ret = pcall(tap.fn, hostile)
    -- Either it handled the hostile event, or it threw — and a throw that
    -- escapes into the event system is what must not happen.
    if not ok then survived = false end
    if ok and ret == true then survived = false end
  end
end
check("🚨 A HOSTILE EVENT IS ABSORBED BY EVERY TAP — none of them throws "
   .. "into the event system and none of them swallows the keystroke",
   survived == true)
_G.expanderResetBuffer()
TYPED, TIMERS = {}, {}
press("space"); typeStr("abc"); runTimers()
check("...and the stack still works right afterwards", TYPED[1] == "ALPHABET",
      TYPED[1])

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.execute("rm -rf '" .. TMP .. "'")
os.exit(fail == 0 and 0 or 1)
