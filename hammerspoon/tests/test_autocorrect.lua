-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- =====================================================================
-- Harness for AUTOCORRECT. Drives the REAL event tap with real key
-- events and reads back what it typed.
--
-- 🚨 WHY THIS SUITE EXISTS, WRITTEN IN 6.69.0 AND OVERDUE.
-- Autocorrect has run on LL's Mac since 6.10.0 against an ~11,000-row
-- dictionary and had NO behavioural test of any kind — the other suites
-- only ever checked that the module loaded and deferred its CSV. The
-- TWo-caps rule in particular is one line of Lua pattern:
--
--     word:match("^%u%u%l")
--
-- and LL's own description of what it must do is precise enough to test
-- directly: "USa" is turned into "Usa", and only if it is three capitals
-- is it left alone — "USA". Three capitals cause nothing to change. Two
-- capitals cause a change from SAt to Sat.
--
-- That got a suite the moment a SECOND event tap started sharing the
-- keyboard with it. Two taps on one keystroke stream is exactly the
-- arrangement where a rule this quiet breaks without anyone noticing.
-- =====================================================================

local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p '" .. TMP .. "'")

local KEYSTROKES, DELETES, log = {}, 0, {}
local TAP, FRONTAPP = nil, "TextEdit"
local ALERTS, TIMERS = {}, {}
local BOUND = {}

hs = {
  eventtap = {
    event = { types = { keyDown = 10, leftMouseDown = 1, rightMouseDown = 3 } },
    new = function(types, fn)
      TAP = { types = types, fn = fn, on = false }
      function TAP:start() self.on = true end
      function TAP:stop() self.on = false end
      function TAP:isEnabled() return self.on end
      return TAP
    end,
    keyStroke = function(mods, key)
      if key == "delete" then DELETES = DELETES + 1 end
    end,
    keyStrokes = function(s) table.insert(KEYSTROKES, s) end,
  },
  timer = {
    secondsSinceEpoch = function() return 1000 end,
    doAfter = function(d, fn)
      local t = { delay = d, fn = fn, running = true }
      function t:stop() self.running = false end
      table.insert(TIMERS, t); return t
    end,
    doEvery = function(d, fn)
      local t = { delay = d, fn = fn, running = true }
      function t:stop() self.running = false end
      return t
    end,
  },
  application = {
    frontmostApplication = function()
      return { name = function() return FRONTAPP end }
    end,
  },
  hotkey = { bind = function(mods, key, fn)
    BOUND[table.concat(mods or {}, "+") .. "+" .. tostring(key)] = fn
  end },
  alert = { show = function(m) table.insert(ALERTS, m) end },
  accessibilityState = function() return true end,
  configdir = TMP,
}

print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  table.insert(log, table.concat(p, " "))
end

-- The REAL shared injection guard, lifted out of core/coexist.lua rather
-- than reimplemented — the point of the guard is that both taps agree,
-- and a private copy here would agree with itself.
local INJECT_PEAK = 0
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
  _G.withInjection = function(fn)
    local r = { sb.withInjection(fn) }
    if sb.injectDepth + 1 > INJECT_PEAK then INJECT_PEAK = sb.injectDepth + 1 end
    return table.unpack(r)
  end
end

_G.diag = { say = function() end, warn = function() end, err = function() end }

local core = {
  logsDir = TMP,
  adoptLegacyFile = function() end,
  popupKeys = { mods = { "ctrl", "alt", "cmd" } },
  warnWriteFailed = function() end,
  splitCSVLine = function(line)
    local out = {}
    for seg in (line .. ","):gmatch("([^,]*),") do out[#out + 1] = seg end
    return out
  end,
}

local mod = dofile(HS .. "/modules/autocorrect.lua")
mod.setup(core)
if mod.warm then mod.warm(core) end     -- reads the seeded CSV

local out = io.write
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; out("  ✅ ", name, "\n")
  else fail = fail + 1; out("  ❌ ", name, " — ", tostring(detail or ""), "\n") end
end

-- Type a string through the real tap. Returns the text it typed back, or
-- nil if it left the word alone.
local function typeWord(s)
  KEYSTROKES, DELETES, TIMERS = {}, 0, {}
  for ch in s:gmatch(".") do
    TAP.fn({
      getType = function() return hs.eventtap.event.types.keyDown end,
      getFlags = function() return {} end,
      getKeyCode = function() return 0 end,
      getCharacters = function() return ch end,
    })
  end
  -- The fix is injected on a short timer, the same as the expander's.
  for _, t in ipairs(TIMERS) do if t.running then t.fn() end end
  return KEYSTROKES[1]
end
local function press(code)
  TAP.fn({ getType = function() return hs.eventtap.event.types.keyDown end,
           getFlags = function() return {} end,
           getKeyCode = function() return code end,
           getCharacters = function() return "" end })
end

-- =====================================================================
out("\n=== 1. The TWo-caps rule, exactly as LL describes it ===\n")
-- "if the first two letters are capitals like this USa it is turned into
--  Usa, and only if it is three capitals is it left alone USA. Three
--  capitals cause nothing to change. Two capitals cause a change from
--  SAt to Sat."
check("USa → Usa", typeWord("USa ") == "Usa ", typeWord("USa "))
check("SAt → Sat", typeWord("SAt ") == "Sat ", typeWord("SAt "))
check("THe → The", typeWord("THe ") == "The ")
check("MAn → Man", typeWord("MAn ") == "Man ")

out("\n  1b. 🚨 THREE CAPITALS CHANGE NOTHING\n")
check("USA is left alone", typeWord("USA ") == nil, typeWord("USA "))
check("OCLC is left alone", typeWord("OCLC ") == nil, typeWord("OCLC "))
check("SAC is left alone", typeWord("SAC ") == nil, typeWord("SAC "))
check("🚨 AND A THREE-CAP WORD WITH A LOWERCASE TAIL IS NOT AN ACRONYM. "
   .. "USAf reads as a typo of USAF, and the rule only ever looks at the "
   .. "first three characters — so it stays out of it",
  typeWord("USAf ") == nil, typeWord("USAf "))

out("\n  1c. the rule needs a THIRD letter before it can decide\n")
check("a two-letter all-caps word is untouched — there is no third "
   .. "character to tell an acronym from a typo", typeWord("US ") == nil,
   typeWord("US "))
check("...and so is a single capital", typeWord("A ") == nil)
check("🚨 TV's KEEPS ITS APOSTROPHE. The rule needs a third LETTER, and "
   .. "the apostrophe ends the word before one arrives — otherwise every "
   .. "acronym possessive would be corrected",
  typeWord("TV's ") == nil, typeWord("TV's "))
check("lowercase words are not the rule's business", typeWord("the ") == nil)
-- ⚠️ ONE GUARD IN autocorrectFor IS NOT REACHABLE FROM HERE, and saying so
-- is better than pretending otherwise: the rule also requires
-- word:match("^%a+$"), but the tap only ever puts LETTERS in the buffer
-- (a digit clears it, see §3), so that condition is always true by the
-- time it is read. Removing it changes nothing observable. It is correct
-- defensive code guarding an invariant enforced one layer up — worth
-- keeping, and not something this suite can prove.
check("...nor is a normally capitalised one", typeWord("The ") == nil)

out("\n  1d. exceptions are honoured\n")
-- Seeded into autocorrect.csv by the module itself on first boot.
check("IDs is a real plural, not a typo", typeWord("IDs ") == nil, typeWord("IDs "))
check("TVs likewise", typeWord("TVs ") == nil)
check("MHz likewise", typeWord("MHz ") == nil)
check("🚨 BUT ITs IS NOT ON THE LIST, on purpose — it is a typo of Its far "
   .. "more often than a plural of IT", typeWord("ITs ") == "Its ",
   typeWord("ITs "))

-- =====================================================================
out("\n=== 2. The dictionary, and your capitalisation ===\n")
check("mna → man", typeWord("mna ") == "man ", typeWord("mna "))
check("Mna → Man (leading capital preserved)", typeWord("Mna ") == "Man ",
  typeWord("Mna "))
check("MNA → MAN (all caps preserved)", typeWord("MNA ") == "MAN ",
  typeWord("MNA "))
check("teh → the", typeWord("teh ") == "the ")
check("a word that is not in the dictionary is left alone",
  typeWord("hello ") == nil)
check("the boundary character is retyped after the fix, so the space you "
   .. "pressed still arrives", (typeWord("teh ") or ""):sub(-1) == " ")
check("...and the wrong word is deleted first, one backspace per letter",
  (function() typeWord("teh "); return DELETES == 3 end)(), DELETES)

out("\n  2b. which boundary characters end a word\n")
for _, b in ipairs({ ".", ",", ";", ":", "!", "?", ")", "-", "/", "'" }) do
  check("'" .. b .. "' ends a word", typeWord("teh" .. b) == "the" .. b,
        typeWord("teh" .. b))
end

-- =====================================================================
out("\n=== 3. What abandons the word ===\n")
check("an arrow key abandons it — the cursor moved and we cannot know "
   .. "where the word now is", (function()
    KEYSTROKES, DELETES, TIMERS = {}, 0, {}
    for ch in ("teh"):gmatch(".") do
      TAP.fn({ getType = function() return hs.eventtap.event.types.keyDown end,
               getFlags = function() return {} end,
               getKeyCode = function() return 0 end,
               getCharacters = function() return ch end })
    end
    press(123)                      -- left arrow
    return typeWord(" ") == nil
  end)())
check("a ⌘ chord abandons it", (function()
    KEYSTROKES, TIMERS = {}, {}
    for ch in ("teh"):gmatch(".") do
      TAP.fn({ getType = function() return hs.eventtap.event.types.keyDown end,
               getFlags = function() return {} end,
               getKeyCode = function() return 0 end,
               getCharacters = function() return ch end })
    end
    TAP.fn({ getType = function() return hs.eventtap.event.types.keyDown end,
             getFlags = function() return { cmd = true } end,
             getKeyCode = function() return 9 end,
             getCharacters = function() return "v" end })
    return typeWord(" ") == nil
  end)())
check("digits abandon it — a token with a number in it is not a word",
  typeWord("teh1 ") == nil, typeWord("teh1 "))
check("an excluded app is never corrected", (function()
    FRONTAPP = "Terminal"
    local r = typeWord("teh ")
    FRONTAPP = "TextEdit"
    return r == nil
  end)())
check("...and the very next app is", typeWord("teh ") == "the ")
check("the off switch stops it dead", (function()
    _G.autocorrectEnabled = false
    local r = typeWord("teh ")
    _G.autocorrectEnabled = true
    return r == nil
  end)())

-- =====================================================================
out("\n=== 4. 6.69.0 — sharing the keyboard with the text expander ===\n")
check("🚨 AUTOCORRECT'S OWN TYPING GOES THROUGH THE SHARED GUARD, so the "
   .. "expander's tap stands down while a correction is retyped — "
   .. "otherwise a spelling fix ending in a trigger fires a snippet",
  (function()
    INJECT_PEAK = 0
    typeWord("teh ")
    return INJECT_PEAK > 0
  end)(), INJECT_PEAK)
check("...and the guard is released again", _G.typingInjection() == false)

check("🚨 AND AUTOCORRECT IGNORES KEYSTROKES THE EXPANDER IS TYPING. "
   .. "Without this, expanding `hte` into \"the\" fed a word nobody typed "
   .. "into an 11,000-row dictionary", (function()
    KEYSTROKES, TIMERS = {}, {}
    _G.withInjection(function()
      for ch in ("teh "):gmatch(".") do
        TAP.fn({ getType = function() return hs.eventtap.event.types.keyDown end,
                 getFlags = function() return {} end,
                 getKeyCode = function() return 0 end,
                 getCharacters = function() return ch end })
      end
    end)
    for _, t in ipairs(TIMERS) do if t.running then t.fn() end end
    return #KEYSTROKES == 0
  end)(), KEYSTROKES[1])

check("_G.autocorrectResetBuffer exists for the expander to call",
  type(_G.autocorrectResetBuffer) == "function")
check("🚨 AND IT REALLY EMPTIES THE WORD. The expander CONSUMES a "
   .. "trigger's last character, so this module is left holding the front "
   .. "of a word that is no longer on screen — 'ht' from 'hte', which "
   .. "would go on to join whatever you type next",
  (function()
    KEYSTROKES, TIMERS = {}, {}
    for ch in ("te"):gmatch(".") do        -- "teh" minus the eaten "h"
      TAP.fn({ getType = function() return hs.eventtap.event.types.keyDown end,
               getFlags = function() return {} end,
               getKeyCode = function() return 0 end,
               getCharacters = function() return ch end })
    end
    _G.autocorrectResetBuffer()
    -- If the buffer had survived, "te" + "h" would make "teh" and fix.
    return typeWord("h ") == nil
  end)())
check("...and the text expander actually calls it", (function()
    local f = io.open(HS .. "/modules/text_expander.lua")
    local s = f:read("*a"); f:close()
    s = s:gsub("%-%-[^\n]*", "")       -- comments discuss it freely
    return s:find("_G.autocorrectResetBuffer", 1, true) ~= nil
  end)())

-- =====================================================================
out("\n=== 5. The tap itself ===\n")
check("the tap was started", TAP.on == true)
check("it is held in a global so the GC cannot collect it",
  _G.autocorrectTap == TAP)
check("a watchdog exists to revive it when macOS switches it off",
  _G.autocorrectWatchdog ~= nil)
check("the dictionary is deferred to warm(), off the boot path",
  type(mod.warm) == "function")
check("...and it really loaded", (_G.autocorrectStatus or ""):find("fixes") ~= nil,
  _G.autocorrectStatus)

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.execute("rm -rf '" .. TMP .. "'")
os.exit(fail == 0 and 0 or 1)
