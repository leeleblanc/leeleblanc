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
local SECURE = false
local ALERTS, TIMERS = {}, {}
local BOUND = {}

hs = {
  eventtap = {
    -- 🚨 6.200.0 — every real Mac answers this; the dictionary check asks
    -- before it rewrites a word, and treats "cannot answer" as locked.
    isSecureInputEnabled = function() return SECURE end,
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

-- =====================================================================
out("\n=== 6. 🚨 WHAT ⇪Z LEARNS IS VISIBLE AND REVERSIBLE (6.199.0) ===\n")
-- =====================================================================
-- LL: "I fixed HOw by deleting the entry and you can see that it is still
-- HOw" — and his grep of 11,000 lines: `11052:allow,HOw,`. One ⇪Z press,
-- long forgotten, switching the TWo-caps rule off for that word on BOTH
-- Macs. Permanent is the design. Invisible was the bug, and there was no
-- report in this module at all, which is why a text editor was the only
-- way to find it.
do
  local mine = 0
  local function ck(label, cond, extra)
    mine = mine + 1 ; check(label, cond, extra)
  end
  local CSV = TMP .. "/autocorrect.csv"
  local function readCsv()
    local f = io.open(CSV, "r") ; local t = f and f:read("*a") or "" 
    if f then f:close() end ; return t
  end
  local function lineCount(t)
    local n = 0 ; for _ in t:gmatch("([^\r\n]+)") do n = n + 1 end ; return n
  end
  local function append(row)
    local f = io.open(CSV, "a") ; f:write(row .. "\n") ; f:close()
    mod.warm(core)
  end

  -- ---- LL's row, exactly ---------------------------------------------
  ck("before it is learned, HOw is corrected", typeWord("HOw ") == "How ")
  append("allow,HOw,")
  ck("🚨 one `allow,HOw,` row is the whole bug — HOw is left alone now",
     typeWord("HOw ") == nil, tostring(typeWord("HOw ")))

  local rep = _G.autocorrectReport()
  ck("🚨 the report NAMES it as something ⇪Z learned — this module had no"
     .. " report at all, which is why grep was the only way to find it",
     rep:find("HOw", 1, true) ~= nil and rep:find("⇪Z learned", 1, true) ~= nil,
     rep:match("⇪Z learned[^\n]*"))
  ck("…and hands over the exact way to undo it",
     rep:find('_G.autocorrectForget("HOw")', 1, true) ~= nil)
  ck("…while an exception this config SHIPS is not called something he"
     .. " taught it", (function()
        local block = rep:match("⇪Z learned.*") or ""
        return block:find("IDs", 1, true) == nil
     end)(), rep:match("⇪Z learned[^\n]*"))

  -- ---- and the way back ----------------------------------------------
  -- The rule matches case-sensitively, so HOw and How are two different
  -- exceptions and forgetting one must not take the other with it.
  append("allow,How,")
  local before = lineCount(readCsv())
  local okF, whyF = _G.autocorrectForget("HOw")
  ck("_G.autocorrectForget removes it and says so", okF == true, whyF)
  ck("…the rule corrects HOw again, without a reload",
     typeWord("HOw ") == "How ", tostring(typeWord("HOw ")))
  local after = readCsv()
  ck("🚨 …and it took exactly ONE row out of the file — a whole-file"
     .. " rewrite that loses rows is 11,000 lines of LL's own work",
     lineCount(after) == before - 1, before .. " -> " .. lineCount(after))
  ck("…every other row is still there",
     after:find("allow,IDs,", 1, true) and after:find("fix,teh,the", 1, true)
     and after:find("type,wrong,right", 1, true))
  ck("🚨 …including the word that differs only in CASE — HOw and How are"
     .. " two exceptions, and one is not the other",
     after:find("allow,How,", 1, true) ~= nil)
  ck("…and it survives a reload", (function()
     mod.warm(core) ; return typeWord("HOw ") == "How "
  end)())

  local okG, whyG = _G.autocorrectForget("HOw")
  ck("forgetting a word that is not an exception refuses and says which",
     okG == false and whyG:find("not an exception", 1, true) ~= nil, whyG)
  ck("…and forgetting nothing at all refuses too", (function()
     local o, w = _G.autocorrectForget("")
     return o == false and w:find("give it a word", 1, true) ~= nil
  end)())
  _G.autocorrectForget("How")     -- the case-sensitivity fixture, cleared
  ck("a Mac that has learned nothing says exactly that, and differently",
     _G.autocorrectReport():find("nothing on this Mac", 1, true) ~= nil)

  -- ---- ⇪Z itself: no duplicate row, and it names the way back --------
  local zKey = BOUND["ctrl+alt+cmd+Z"]
  ck("⇪Z is bound", type(zKey) == "function")
  typeWord("GHq ")                      -- a rule fix, so acLast.wasRule
  ALERTS = {}
  zKey()
  ck("⇪Z learns the word", _G.autocorrectReport():find("GHq", 1, true) ~= nil)
  ck("🚨 …and the alert names the way back, so it is never only in a CSV",
     (ALERTS[#ALERTS] or ""):find('_G.autocorrectForget("GHq")', 1, true) ~= nil,
     ALERTS[#ALERTS])
  _G.autocorrectForget("GHq")

  -- 📌 A DUPLICATE ROW IS UNREACHABLE IN ONE SESSION and reachable
  -- across two: once a word is allowed the rule stops firing, so ⇪Z has
  -- nothing to undo — but the OTHER Mac, which has not reloaded since the
  -- row synced, still corrects it and appends a second. So the defence is
  -- not the in-memory guard (which cannot see that): it is that the
  -- loader counts DISTINCT words and forget removes EVERY matching row.
  -- No in-memory guard is written for this, because no test could fail
  -- against it: the mutation that removed one survived, so the guard did.
  append("allow,ZZq,") ; append("allow,ZZq,")
  local dupBefore = lineCount(readCsv())
  ck("a word learned twice on two Macs is still ONE exception",
     (_G.autocorrectReport():gsub("[^\n]*ZZq[^\n]*", "x", 1)
      :find("ZZq", 1, true)) == nil)
  local okD = _G.autocorrectForget("ZZq")
  ck("…and forgetting it removes BOTH rows, not one of them",
     okD == true and lineCount(readCsv()) == dupBefore - 2,
     dupBefore .. " -> " .. lineCount(readCsv()))

  -- ---- a `fix` row whose two sides are the same word -----------------
  -- Obeyed, it MANGLES: the dictionary lowercases both sides and then
  -- re-applies sentence case, so IDs comes back Ids. It also costs the
  -- TWo-caps rule its turn, because a dictionary hit returns first.
  append("fix,IDs,IDs")
  ck("🚨 a dead `fix` row is SKIPPED — obeyed it turns IDs into Ids",
     typeWord("IDs ") == nil, tostring(typeWord("IDs ")))
  -- 🚨 AND THE SIDES ONLY HAVE TO MATCH ONCE LOWERED. The dictionary
  -- stores both sides lowercased, so `fix,TVs,tvs` is the same dead row
  -- written differently — and obeyed it hands back Tvs.
  append("fix,TVs,tvs")
  ck("🚨 …and a row whose sides differ only in CASE is dead too",
     typeWord("TVs ") == nil, tostring(typeWord("TVs ")))
  local rep2 = _G.autocorrectReport()
  ck("…and the report names it WITH ITS LINE NUMBER, so it can be found"
     .. " in an 11,000-line file", (function()
        local n = select(2, readCsv():gsub("[^\r\n]+", ""))
        return rep2:find("dead rows", 1, true)
           and rep2:find("fix,IDs,IDs", 1, true)
           and rep2:match("line%s+(%d+)%s+fix,IDs,IDs") ~= nil
     end)(), rep2:match("[^\n]*fix,IDs,IDs[^\n]*"))
  ck("…and it is not counted as a dictionary row it obeys", (function()
        return rep2:match("dictionary%s*:%s*(%d+)") ==
               rep:match("dictionary%s*:%s*(%d+)")
     end)(), rep2:match("dictionary[^\n]*"))
  ck("…and the CSV itself is NOT edited — his file, his call",
     readCsv():find("fix,IDs,IDs", 1, true) ~= nil)

  check("§6 ran every one of its checks", mine == 24, mine)
end

-- =====================================================================
out("\n=== 7. 📖 THE REAL DICTIONARY CHECK (6.200.0) ===\n")
-- =====================================================================
-- LL: "The actual word is somethgni, somethingg, somethinng, somethng,
-- somtething" — five spellings of one word, listed to make the point that
-- he should not have to keep adding custom rows. The risk is not missing
-- a typo; it is CORRECTING SOMETHING THAT WAS RIGHT, because a word list
-- holds no names, no jargon and no identifiers. So most of this section
-- is about what it must leave alone.
do
  local mine = 0
  local function ck(label, cond, extra)
    mine = mine + 1 ; check(label, cond, extra)
  end
  local WORDS = TMP .. "/words"
  local function seedWords(list)
    local f = io.open(WORDS, "w")
    for _, w in ipairs(list) do f:write(w .. "\n") end
    f:close()
    mod.config.wordsFile = WORDS
    mod.warm(core)
  end
  seedWords({ "something", "porter", "potter", "house", "houses", "backed",
              "collect", "the", "man", "and", "that", "their", "receive",
              "separate", "iphone" })

  -- ---- LL's five, by name --------------------------------------------
  for _, typo in ipairs({ "somethingg", "somethinng", "somethng", "somtething",
                          "somethgni" }) do
    ck("🚨 " .. typo .. " → something, with no row written for it",
       typeWord(typo .. " ") == "something ", tostring(typeWord(typo .. " ")))
  end
  ck("…and the word spelled correctly is left alone",
     typeWord("something ") == nil, tostring(typeWord("something ")))
  -- 🚨 TWO EDITS CAN REACH THE SAME WORD: inserting the l before or
  -- after the l already in "colect" both give "collect". Counted twice
  -- that reads as two candidates — a guess — and nothing is corrected.
  ck("🚨 one word reached two ways is still ONE candidate",
     typeWord("colect ") == "collect ", tostring(typeWord("colect ")))

  -- ---- what it must NOT touch ----------------------------------------
  ck("🚨 two real words a single edit away is a GUESS — poter does nothing"
     .. " while both porter and potter exist",
     typeWord("poter ") == nil, tostring(typeWord("poter ")))
  -- potter removed. house/houses and backed stay: a REAL word with
  -- exactly one real neighbour is the only fixture that can prove
  -- "it is already a word" and the length floor actually BITE, and
  -- "backed" is the only one that can prove the deletion rule does.
  seedWords({ "something", "porter", "house", "houses", "backed", "iphone" })
  ck("…and the moment only ONE is left, it corrects",
     typeWord("poter ") == "porter ", tostring(typeWord("poter ")))

  ck("a leading capital is restored onto the fix",
     typeWord("Somethingg ") == "Something ", tostring(typeWord("Somethingg ")))
  ck("🚨 ALL CAPS is never touched — that is an acronym",
     typeWord("SOMETHINGG ") == nil, tostring(typeWord("SOMETHINGG ")))
  ck("🚨 mixed case is never touched — that is CamelCase or a product name",
     typeWord("iPhonee ") == nil, tostring(typeWord("iPhonee ")))
  ck("🚨 a word that IS in the list is never touched, even when exactly"
     .. " one real word sits a single edit away — house must not become houses",
     typeWord("house ") == nil, tostring(typeWord("house ")))
  ck("🚨 a word under the length floor is never touched, even when exactly"
     .. " one real word is one edit away (hous → house)",
     typeWord("hous ") == nil, tostring(typeWord("hous ")))
  ck("two neighbours the wrong way round is its own edit — hosue → house",
     typeWord("hosue ") == "house ", tostring(typeWord("hosue ")))
  -- 🚨 THE MEASURED ONE. Against the real 73,000-word list, deleting
  -- ANY letter turned rsync into sync, backend into backed and frontend
  -- into fronted. A deleted letter must be one that REPEATS within the
  -- next two positions — already coming, so plainly typed twice or early.
  ck("🚨 a word is not shortened into another word — backend must never"
     .. " become backed, however alone that leaves it in the word list",
     typeWord("backend ") == nil, tostring(typeWord("backend ")))
  ck("a word nothing in the list is near is left exactly as typed",
     typeWord("qwertyuio ") == nil, tostring(typeWord("qwertyuio ")))

  -- ---- it is asked LAST ----------------------------------------------
  ck("the CSV dictionary still answers first", typeWord("teh ") == "the ",
     tostring(typeWord("teh ")))
  ck("the TWo-caps rule still answers before it",
     typeWord("USa ") == "Usa ", tostring(typeWord("USa ")))

  -- ---- ⇪Z governs it too ---------------------------------------------
  -- The learned exception is checked by the word-list rule as well, so
  -- 6.199.0's report and _G.autocorrectForget already govern this
  -- feature — there is no second thing to learn or unlearn.
  local f = io.open(TMP .. "/autocorrect.csv", "a")
  f:write("allow,somethingg,\n") ; f:close() ; mod.warm(core)
  ck("🚨 a word ⇪Z was told to leave alone is not spell-corrected either",
     typeWord("somethingg ") == nil, tostring(typeWord("somethingg ")))
  ck("…and it shows up in the SAME learned list, with the same way back",
     _G.autocorrectReport():find('_G.autocorrectForget("somethingg")', 1, true) ~= nil)
  _G.autocorrectForget("somethingg")
  ck("…and forgetting it brings the correction straight back",
     typeWord("somethingg ") == "something ", tostring(typeWord("somethingg ")))

  -- ---- where it stands down ------------------------------------------
  FRONTAPP = "Code"
  ck("🚨 it does not speak in a code editor — identifiers look exactly"
     .. " like misspellings to a word list",
     typeWord("somethingg ") == nil, tostring(typeWord("somethingg ")))
  FRONTAPP = "Terminal"
  ck("…nor in a terminal", typeWord("somethingg ") == nil)
  FRONTAPP = "TextEdit"
  SECURE = true
  ck("🚨 …nor into a password field", typeWord("somethingg ") == nil,
     tostring(typeWord("somethingg ")))
  SECURE = false
  ck("…and it comes back afterwards", typeWord("somethingg ") == "something ")

  -- 🚨 IT FAILS CLOSED. A Mac that cannot answer whether the keyboard is
  -- locked is treated as locked — the opposite choice would run the one
  -- feature that rewrites text in the one place it must never speak.
  local realSec = hs.eventtap.isSecureInputEnabled
  hs.eventtap.isSecureInputEnabled = nil
  ck("🚨 a Mac that cannot answer about secure input is treated as locked",
     typeWord("somethingg ") == nil, tostring(typeWord("somethingg ")))
  hs.eventtap.isSecureInputEnabled = realSec

  -- ---- 🚨 IT MUST NOT BLOCK THE THREAD THAT READS THE KEYBOARD ----
  -- The real list is ~235,000 lines. Folding that into a table in one go
  -- is a visible hitch on the main thread, so it goes in acSpell.slice
  -- words per turn of the event loop. A fixture smaller than one slice
  -- proves the slicing EXISTS, never that it BITES (6.187.0's rule), so
  -- this one is deliberately bigger than the slice it is given.
  TIMERS = {}
  mod.config.slice = 2
  seedWords({ "aaa", "bbb", "ccc", "ddd", "eee", "something" })
  ck("🚨 a list bigger than one slice does not finish inline — it hands"
     .. " the thread back and comes round again",
     #TIMERS > 0 and _G.autocorrectReport():find("reading the word list", 1, true) ~= nil,
     #TIMERS .. " timers · " .. tostring(_G.autocorrectReport():match("word list[^\n]*")))
  -- typeWord() empties TIMERS (it watches for the inject timer), so the
  -- half-built list's next slice is put back by hand here. On a real Mac
  -- the timer holds its own reference in _G.acSpellTimer.
  local held = TIMERS
  local midAnswer = typeWord("somethingg ")
  TIMERS = held
  ck("…and it is not answering yet, rather than answering wrongly",
     midAnswer == nil, tostring(midAnswer))
  local rounds = 0
  while rounds < 20 do
    rounds = rounds + 1
    local pending = TIMERS ; TIMERS = {}
    if #pending == 0 then break end
    for _, t in ipairs(pending) do if t.running then t.fn() end end
  end
  ck("…and when the last slice lands it is ready and answers",
     _G.autocorrectReport():find("ready", 1, true) ~= nil
     and typeWord("somethingg ") == "something ",
     tostring(_G.autocorrectReport():match("word list[^\n]*")))
  mod.config.slice = 20000

  -- ---- and when there is no word list at all -------------------------
  mod.config.wordsFile = TMP .. "/no-such-file"
  mod.warm(core)
  ck("no word list: it says so and changes nothing",
     typeWord("somethingg ") == nil, tostring(typeWord("somethingg ")))
  ck("…and the CSV dictionary still works, untouched by any of it",
     typeWord("teh ") == "the ", tostring(typeWord("teh ")))
  local repOff = _G.autocorrectReport()
  ck("…and the report NAMES the missing file rather than going quiet",
     repOff:find("no word list at", 1, true) ~= nil,
     repOff:match("word list[^\n]*"))

  -- ---- the report ----------------------------------------------------
  seedWords({ "something", "porter", "house" })
  typeWord("somethingg ")
  local rep = _G.autocorrectReport()
  ck("the report says the list is ready, and how many words",
     rep:find("ready", 1, true) and rep:match("word list[^\n]*3 words") ~= nil,
     rep:match("word list[^\n]*"))
  ck("…counts what it changed and shows the last few, so an app that"
     .. " misfires is named from EVIDENCE rather than guessed at",
     rep:find("somethingg → something", 1, true) ~= nil,
     rep:match("spelling[^\n]*"))
  ck("…and lists where it deliberately does not speak",
     rep:find("not asked in", 1, true) and rep:find("Terminal", 1, true)
     and rep:find("password field", 1, true))

  -- ---- the rule itself, with no Mac near it --------------------------
  local function known(w)
    return ({ something = true, porter = true, house = true })[w] == true
  end
  ck("the rule is pure and reachable, so every shape above is provable"
     .. " without typing anything",
     _G.acSpellCorrection("somethgni", known, 4) == "something"
     and _G.acSpellCorrection("something", known, 4) == nil
     and _G.acSpellCorrection("hous", known, 4) == "house"
     and _G.acSpellCorrection("hou", known, 4) == nil)

  check("§7 ran every one of its checks", mine == 37, mine)
end

-- =====================================================================
out("\n=== 8. 🚨 AN INFLECTION OF A WORD IS A WORD (6.205.0) ===\n")
-- =====================================================================
-- LL, on 6.203.0 in Chrome: "starets which should be starts", "allows is
-- changing to gallows", and "convinced" rewritten mid-sentence. macOS's
-- word list is a list of BASE words — it has start, allow and convince,
-- and not starts, allows or convinced — so every regular inflection read
-- as "not a word", and the one real word an insertion away was an
-- obscure entry. The fixture below is that list in miniature.
do
  local mine = 0
  local function ck(label, cond, extra)
    mine = mine + 1 ; check(label, cond, extra)
  end
  local WORDS = TMP .. "/words"
  local function seedWords(list)
    local f = io.open(WORDS, "w")
    for _, w in ipairs(list) do f:write(w .. "\n") end
    f:close()
    mod.config.wordsFile = WORDS
    mod.warm(core)
  end
  seedWords({ "start", "starets", "allow", "gallows", "convince", "run",
              "stop", "happy", "quick", "kind", "wish", "try", "make",
              "tall", "nice", "big", "something", "house" })

  -- ---- LL's three, by name -------------------------------------------
  ck("🚨 starts is left alone — start is a word, so starts is one too"
     .. " (it became starets)", typeWord("starts ") == nil,
     tostring(typeWord("starts ")))
  ck("🚨 allows is left alone (it became gallows)",
     typeWord("allows ") == nil, tostring(typeWord("allows ")))
  ck("🚨 convinced is left alone — the e-dropping past tense",
     typeWord("convinced ") == nil, tostring(typeWord("convinced ")))
  ck("Starts with a capital is left alone too",
     typeWord("Starts ") == nil, tostring(typeWord("Starts ")))

  -- ---- every regular ending, one word each ---------------------------
  for _, w in ipairs({ "running", "stopped", "happier", "happiest", "happily",
                       "happiness", "quickly", "kindness", "wishes", "tries",
                       "tried", "making", "taller", "tallest", "nicer",
                       "nicest", "bigger", "houses" }) do
    ck(w .. " is an inflection of a listed word and is left alone",
       typeWord(w .. " ") == nil, tostring(typeWord(w .. " ")))
  end

  -- ---- and the rule still corrects a real typo ------------------------
  ck("🚨 statrs → starts: an inflection is a real ANSWER as well, not only"
     .. " a word to leave alone — starts is not listed, start is",
     typeWord("statrs ") == "starts ", tostring(typeWord("statrs ")))
  ck("somethingg → something still works", typeWord("somethingg ") == "something ",
     tostring(typeWord("somethingg ")))
  ck("a stem must keep two letters — 'as' is not read as a plural of 'a'",
     (function()
        local known = function(w) return w == "a" end
        for _, s in ipairs(_G.acSpellStems("as")) do if known(s) then return false end end
        return true
     end)())

  -- ---- the pure rule, with no Mac near it ----------------------------
  local known = function(w)
    return ({ start = true, starets = true, allow = true, gallows = true })[w] == true
  end
  ck("_G.acSpellStems names start for starts", (function()
     for _, s in ipairs(_G.acSpellStems("starts")) do if s == "start" then return true end end
     return false
  end)(), table.concat(_G.acSpellStems("starts"), " "))
  ck("🚨 …and the pure rule refuses to touch starts while it would still"
     .. " turn a word with NO known stem into starets",
     _G.acSpellCorrection("starts", known, 4) == nil
     and _G.acSpellCorrection("stares", known, 4) == nil     -- stare? not listed, stares → starets? two-edit; stays
     and _G.acSpellCorrection("starts", function(w) return w == "starets" end, 4) == "starets",
     tostring(_G.acSpellCorrection("starts", known, 4)))
  ck("allows: allow is a stem; gallows is not a correction of it",
     _G.acSpellCorrection("allows", known, 4) == nil)

  -- ---- ✏️ the door for a fix row ---------------------------------------
  local CSV = TMP .. "/autocorrect.csv"
  local function readCsv()
    local f = io.open(CSV, "r") ; local t = f and f:read("*a") or ""
    if f then f:close() end ; return t
  end
  ck("before the row, intsead is left alone", typeWord("intsead ") == nil,
     tostring(typeWord("intsead ")))
  local okA, whyA = _G.autocorrectAdd("intsead", "instead")
  ck("_G.autocorrectAdd writes the row and says so", okA == true
     and whyA:find("intsead → instead", 1, true) ~= nil, whyA)
  ck("…and it corrects at once, with no reload",
     typeWord("intsead ") == "instead ", tostring(typeWord("intsead ")))
  ck("…the row is in the file as fix,intsead,instead",
     readCsv():find("\nfix,intsead,instead\n", 1, true) ~= nil)
  ck("…and it survives a reload", (function()
     mod.warm(core) ; return typeWord("intsead ") == "instead "
  end)())
  ck("…with the capitalisation rules of any other row (Intsead → Instead)",
     typeWord("Intsead ") == "Instead ", tostring(typeWord("Intsead ")))
  ck("the report counts it as a dictionary row",
     tonumber(_G.autocorrectReport():match("dictionary%s*:%s*(%d+)")) >= 11)
  local n0 = select(2, readCsv():gsub("\n", ""))
  local okD, whyD = _G.autocorrectAdd("IDs", "ids")
  ck("🚨 a dead row is REFUSED, not written — obeyed it would turn IDs into Ids",
     okD == false and whyD:find("same word", 1, true) ~= nil
     and select(2, readCsv():gsub("\n", "")) == n0, whyD)
  local okC, whyC = _G.autocorrectAdd("a,b", "ab")
  ck("…and so is a comma, which would corrupt the file",
     okC == false and select(2, readCsv():gsub("\n", "")) == n0, whyC)
  local okE, whyE = _G.autocorrectAdd("", "x")
  ck("…and an empty side", okE == false and whyE:find("two words", 1, true) ~= nil, whyE)
  ck("the cheat sheet tells LL the door exists", (function()
     for _, e in ipairs(mod.cheatsheet.entries) do
       if e[2]:find("_G.autocorrectAdd", 1, true) then return true end
     end
     return false
  end)())

  check("§8 ran every one of its checks", mine == 39, mine)
end

-- =====================================================================
out("\n=== 8b. 🚨 AN INFLECTED ANSWER MUST CARRY THE TYPED ENDING (6.213.2) ===\n")
-- =====================================================================
-- 6.205.0 was proven against the fixture above, and the fixture shared
-- its blind spot. Measured against the REAL /usr/share/dict/words:
-- plugin → pluging (plug+ing), backend → backened (backen+ed), signin →
-- signing (sign+ing) — right words, rewritten, the class 6.205.0 was
-- shipped to end. And LL's own report: statrs stayed statrs, because
-- the real list has stater AND stator, so starts was one of THREE
-- answers. The fixture below holds exactly the real list's words that
-- bit. Two mutations fail rows here: dropping the ending gate turns
-- plugin into pluging; comparing endings strictly instead of by family
-- loses wishess → wishes.
do
  local mine = 0
  local function ck(label, cond, extra)
    mine = mine + 1 ; check(label, cond, extra)
  end
  local WORDS = TMP .. "/words"
  local function seedWords(list)
    local f = io.open(WORDS, "w")
    for _, w in ipairs(list) do f:write(w .. "\n") end
    f:close()
    mod.config.wordsFile = WORDS
    mod.warm(core)
  end
  seedWords({ "plug", "backen", "sign", "wish", "start", "stater", "stator",
              "something", "convince" })

  ck("🚨 plugin is left alone — pluging (plug+ing) is no answer for a word"
     .. " typed with no ending", typeWord("plugin ") == nil, tostring(typeWord("plugin ")))
  ck("🚨 backend is left alone (it became backened — backen is listed)",
     typeWord("backend ") == nil, tostring(typeWord("backend ")))
  ck("🚨 signin is left alone (it became signing)",
     typeWord("signin ") == nil, tostring(typeWord("signin ")))
  ck("wishess → wishes: es and s are ONE ending family (the list has wish,"
     .. " not wishes; wishs itself is wish+s and is left alone)",
     typeWord("wishess ") == "wishes " and typeWord("wishs ") == nil,
     tostring(typeWord("wishess ")) .. " / " .. tostring(typeWord("wishs ")))
  ck("sttarts → starts: a doubled letter in the stem, the ending kept",
     typeWord("sttarts ") == "starts ", tostring(typeWord("sttarts ")))
  ck("somethingg → something: a word the list holds outright is never gated",
     typeWord("somethingg ") == "something ", tostring(typeWord("somethingg ")))
  ck("🔎 STATED: statrs is SILENT once stater and stator are listed —"
     .. " starts, staters, stators are three answers and the rule never"
     .. " guesses (LL's real-list report on 6.213.1)",
     typeWord("statrs ") == nil, tostring(typeWord("statrs ")))
  ck("…and the measured cost, named: a typo INSIDE the ending (convincd)"
     .. " is left alone now — silence is the safe side",
     typeWord("convincd ") == nil, tostring(typeWord("convincd ")))

  -- ---- the pure helper, with no Mac near it ---------------------------
  local E = _G.acSpellEnding
  ck("_G.acSpellEnding: wishes, tries, starts are all the s family",
     E("wishes") == "s" and E("tries") == "s" and E("starts") == "s")
  ck("…allowed/tried → ed · running → ing · taller/happier → er ·"
     .. " tallest/happiest → est · quickly/happily → ly · kindness/happiness → ness",
     E("allowed") == "ed" and E("tried") == "ed" and E("running") == "ing"
     and E("taller") == "er" and E("happier") == "er" and E("tallest") == "est"
     and E("happiest") == "est" and E("quickly") == "ly" and E("happily") == "ly"
     and E("kindness") == "ness" and E("happiness") == "ness")
  ck("…and a word with no ending answers \"\" — plugin, backend, signin,"
     .. " and a bare suffix is not an ending of itself (s, ing)",
     E("plugin") == "" and E("backend") == "" and E("signin") == ""
     and E("s") == "" and E("ing") == "")
  local known = function(w) return ({ plug = true, start = true })[w] == true end
  ck("the pure rule: plugin stays under a known() that lists plug…",
     _G.acSpellCorrection("plugin", known, 5) == nil,
     tostring(_G.acSpellCorrection("plugin", known, 5)))
  ck("…while startss → starts, the typed s family carried by the answer",
     _G.acSpellCorrection("startss", known, 5) == "starts",
     tostring(_G.acSpellCorrection("startss", known, 5)))

  check("§8b ran every one of its checks", mine == 13, mine)
end

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.execute("rm -rf '" .. TMP .. "'")
os.exit(fail == 0 and 0 or 1)
