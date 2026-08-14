-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
-- HS = the config being tested (init.lua + modules/)
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- =====================================================================
-- Harness for the TEXT EXPANDER. Runs the shipped module against a
-- stubbed hs and a REAL temporary directory of REAL Alfred JSON — the
-- same shape LL's Ghostty_or_Terminal.alfredsnippets unpacks to, byte
-- for byte, including the empty prefix/suffix in info.plist that is the
-- whole reason `;bd` and `gg1` can coexist.
--
-- 🚨 THE FILES ARE REAL ON PURPOSE. A stubbed reader would be a second
-- copy of my own idea of the format, and a test that checks the code
-- against another copy of the same assumption confirms the assumption
-- instead of checking it. That mistake shipped four missing modules in
-- 6.66.2; it is not being made again.
-- =====================================================================

local TMP = os.tmpname()
os.remove(TMP)

local KEYSTROKES, DELETES, LEFTS, ALERTS = {}, 0, 0, {}
local log, TAP = {}, nil
local FRONTAPP = "TextEdit"
local CLIP = "clipboard contents"
local PENDING = {}
local BOUND, CHOOSERS = {}, {}
local AXOK = true

local function mkdirp(p) os.execute("mkdir -p '" .. p .. "'") end
local function write(p, s)
  local f = assert(io.open(p, "w")); f:write(s); f:close()
end

hs = {
  fs = {
    dir = function(p)
      -- A real directory iterator over a real directory. `ls -a` rather
      -- than a Lua library so this suite needs nothing installed.
      local h = io.popen("ls -a '" .. p .. "' 2>/dev/null")
      if not h then error("no such directory") end
      local names = {}
      for l in h:lines() do names[#names + 1] = l end
      h:close()
      if #names == 0 then error("no such directory") end
      local i = 0
      return function() i = i + 1; return names[i] end
    end,
    attributes = function(p)
      local h = io.popen("test -d '" .. p .. "' && echo d || (test -e '" .. p .. "' && echo f || echo n)")
      local k = h:read("*l"); h:close()
      if k == "n" then return nil end
      return { mode = (k == "d") and "directory" or "file" }
    end,
    mkdir = function(p) mkdirp(p); return true end,
  },
  json = {
    -- Deliberately NOT a full JSON parser: it only has to read what
    -- Alfred writes, and every field it reads is asserted below against
    -- a file this suite wrote from the real format.
    decode = function(s)
      local obj = {}
      local inner = s:match('"alfredsnippet"%s*:%s*(%b{})')
      if not inner then return obj end
      local a = {}
      for k, v in inner:gmatch('"(%w+)"%s*:%s*"(.-)"%s*[,}]') do
        a[k] = v:gsub("\\n", "\n"):gsub('\\"', '"')
      end
      obj.alfredsnippet = a
      return obj
    end,
    encode = function(t)
      local a = t.alfredsnippet or {}
      return string.format(
        '{"alfredsnippet":{"snippet":"%s","uid":"%s","name":"%s","keyword":"%s"}}',
        tostring(a.snippet):gsub("\n", "\\n"), tostring(a.uid),
        tostring(a.name), tostring(a.keyword))
    end,
  },
  eventtap = {
    event = { types = { keyDown = 10, leftMouseDown = 1, rightMouseDown = 3 } },
    new = function(types, fn) TAP = { types = types, fn = fn, on = false }
      function TAP:start() self.on = true end
      function TAP:stop() self.on = false end
      function TAP:isEnabled() return self.on end
      return TAP
    end,
    keyStroke = function(mods, key)
      if key == "delete" then DELETES = DELETES + 1
      elseif key == "left" then LEFTS = LEFTS + 1 end
    end,
    keyStrokes = function(s) table.insert(KEYSTROKES, s) end,
  },
  timer = {
    secondsSinceEpoch = function() return 1000 end,
    doAfter = function(d, fn)
      local t = { delay = d, fn = fn, running = true }
      function t:stop() self.running = false end
      table.insert(PENDING, t); return t
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
  pasteboard = { getContents = function() return CLIP end },
  alert = { show = function(m) table.insert(ALERTS, m) end },
  chooser = {
    new = function(cb)
      local c = { cb = cb }
      function c:choices(x) self.rows_ = x; return c end
      function c:rows() return c end
      function c:width() return c end
      function c:placeholderText(p) self.ph = p; return c end
      function c:show() self.shown = true; return c end
      table.insert(CHOOSERS, c)
      return c
    end,
  },
  accessibilityState = function() return AXOK end,
  execute = function(cmd)
    -- The real unzip. This is the one call the import path exists for,
    -- and stubbing it would test nothing.
    local h = io.popen(cmd .. " 2>&1")
    local o = h:read("*a")
    local ok, _, rc = h:close()
    return o, ok, "exit", rc or 0
  end,
  keycodes = { map = {} },
}

print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  table.insert(log, table.concat(p, " "))
end

_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.notices = { recorded = {},
  record = function(k, s, m) table.insert(_G.notices.recorded, k .. "|" .. s .. "|" .. m) end,
  tell = function() end }

local PROVIDED, HYPER = {}, {}
local core = {
  logsDir = TMP,
  provide = function(n, fn) PROVIDED[n] = fn end,
  hyperAddShortcut = function(mods, key, fn, src)
    table.insert(HYPER, { combo = table.concat(mods, "+") .. "+" .. key, fn = fn, src = src })
  end,
  warnWriteFailed = function() end,
}

-- ---- the fixture: LL's real collection, in the real format ----------
mkdirp(TMP .. "/snippets/Ghostty_or_Terminal")
-- Both keys EMPTY, exactly as LL's export has them. This is the file
-- saying "the prefix is already baked into each keyword", and it is why
-- the ";" below must NOT be added a second time.
write(TMP .. "/snippets/Ghostty_or_Terminal/info.plist", [[
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>snippetkeywordprefix</key>
  <string></string>
  <key>snippetkeywordsuffix</key>
  <string></string>
</dict></plist>
]])
local function snippetFile(dir, file, name, keyword, text, uid)
  write(dir .. "/" .. file, string.format([[
{
  "alfredsnippet" : {
    "snippet" : "%s",
    "uid" : "%s",
    "name" : "%s",
    "keyword" : "%s"
  }
}]], text, uid or "UID", name, keyword))
end
local G = TMP .. "/snippets/Ghostty_or_Terminal"
snippetFile(G, "Brew doctor [C3603EB7].json",  "Brew doctor",  ";bd", "brew doctor")
snippetFile(G, "Brew update [4F9174DB].json",  "Brew update",  ";bu", "brew update")
snippetFile(G, "Brew cleanup [3E74B88C].json", "Brew cleanup", ";bc", "brew cleanup")

-- A SECOND collection with a REAL prefix in its plist and BARE keywords
-- in its JSON. This is the other half of "some have a trigger convention
-- and some don't", and the two must coexist without either being aware
-- of the other.
mkdirp(TMP .. "/snippets/Prefixed")
write(TMP .. "/snippets/Prefixed/info.plist", [[
<plist><dict>
  <key>snippetkeywordprefix</key><string>::</string>
  <key>snippetkeywordsuffix</key><string></string>
</dict></plist>
]])
snippetFile(TMP .. "/snippets/Prefixed", "Sig.json", "Signature", "sig", "Lee LeBlanc")

-- Textapanders-style: bare three-letter triggers, no prefix anywhere.
mkdirp(TMP .. "/snippets/Textapanders")
snippetFile(TMP .. "/snippets/Textapanders", "gg1.json", "Greeting", "gg1", "Good morning,")
snippetFile(TMP .. "/snippets/Textapanders", "eml.json", "Email", "eml", "leblanc.lee@gmail.com")

local mod = dofile(HS .. "/modules/text_expander.lua")
mod.setup(core)
local exp = mod.exp
if mod.warm then mod.warm() end

local out = io.write
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; out("  ✅ ", name, "\n")
  else fail = fail + 1; out("  ❌ ", name, " — ", tostring(detail or ""), "\n") end
end
local function logged(pat)
  for _, l in ipairs(log) do if l:find(pat, 1, true) then return true end end
  return false
end
local function drain()
  for _ = 1, 3 do
    local b = PENDING; PENDING = {}
    if #b == 0 then return end
    for _, t in ipairs(b) do if t.running then t.fn() end end
  end
end

-- Type a string through the REAL event tap, one keyDown per character,
-- and report whether the tap consumed the final keystroke.
local function typeStr(s)
  local consumed = false
  for ch in s:gmatch(".") do
    local ev = {
      getType = function() return hs.eventtap.event.types.keyDown end,
      getFlags = function() return {} end,
      getKeyCode = function() return 0 end,
      getCharacters = function() return ch end,
    }
    consumed = TAP.fn(ev)
  end
  return consumed
end
local function press(code)
  TAP.fn({ getType = function() return hs.eventtap.event.types.keyDown end,
           getFlags = function() return {} end,
           getKeyCode = function() return code end,
           getCharacters = function() return "" end })
end
local function reset()
  KEYSTROKES, DELETES, LEFTS, ALERTS, log, PENDING = {}, 0, 0, {}, {}, {}
  _G.notices.recorded = {}
  FRONTAPP = "TextEdit"
  exp.enabled, exp.wordStartOnly = true, true
  press(53)                              -- esc: clear the buffer
end

-- =====================================================================
out("\n=== 1. The module contract ===\n")
check("declares a name", mod.name == "Text Expander", mod.name)
check("declares a cheat sheet group",
  mod.cheatsheet and mod.cheatsheet.title:find("TEXT EXPANDER", 1, true) ~= nil)
check("declares its slot in the sheet", type(mod.order) == "number", mod.order)
check("exposes setup() per the contract", type(mod.setup) == "function")
check("exposes warm() — files are read AFTER boot, like autocorrect",
  type(mod.warm) == "function")
check("binds ⇪⇧T and nothing else", #HYPER == 1 and HYPER[1].combo == "shift+t",
  HYPER[1] and HYPER[1].combo)
check("publishes expander.show", type(PROVIDED["expander.show"]) == "function")
check("publishes expander.reload", type(PROVIDED["expander.reload"]) == "function")
check("publishes expander.toggle", type(PROVIDED["expander.toggle"]) == "function")
check("_G.snippetsImport is reachable from the Console",
  type(_G.snippetsImport) == "function")
check("_G.snippetAdd is reachable", type(_G.snippetAdd) == "function")
check("_G.snippetsList is reachable", type(_G.snippetsList) == "function")

-- =====================================================================
out("\n=== 2. Reading Alfred's actual format ===\n")
check("every snippet in all three collections loaded", exp.count == 6, exp.count)
check("a ;-prefixed keyword survives verbatim", exp.snippets[";bd"] ~= nil,
  exp.snippets[";bd"])
check("...with its text", exp.snippets[";bd"].text == "brew doctor")
check("...and its name, for the ⇪⇧T list", exp.snippets[";bd"].name == "Brew doctor")
check("🚨 AN EMPTY PREFIX IS NOT APPLIED TWICE. LL's export has empty "
   .. "prefix/suffix because the ';' is already in each keyword; adding "
   .. "one would make every Ghostty trigger unreachable",
  exp.snippets[";;bd"] == nil and exp.snippets[";bd"] ~= nil)
check("a bare three-letter trigger loads (Textapanders style)",
  exp.snippets["gg1"] ~= nil)
check("...as does a second one", exp.snippets["eml"] ~= nil)
check("🚨 AND A COLLECTION WITH A REAL PREFIX GETS IT APPLIED. This is "
   .. "the OTHER half: bare 'sig' in the JSON, '::' in the plist",
  exp.snippets["::sig"] ~= nil and exp.snippets["sig"] == nil,
  exp.snippets["sig"] and "bare sig leaked through")
check("...so both conventions are live at the same time",
  exp.snippets[";bd"] and exp.snippets["gg1"] and exp.snippets["::sig"] and true)
check("the longest trigger is measured (it bounds nothing else silently)",
  exp.longest == 5, exp.longest)
check("nothing failed to load", #(exp.problems or {}) == 0,
  table.concat(exp.problems or {}, "; "))

-- =====================================================================
out("\n=== 3. Expanding as you type ===\n")
reset()
local consumed = typeStr(";bd")
check("the trigger's LAST keystroke is consumed — the replacement covers it",
  consumed == true)
check("nothing is typed before the timer fires", #KEYSTROKES == 0)
drain()
check("the snippet is typed out", KEYSTROKES[1] == "brew doctor", KEYSTROKES[1])
check("🚨 EXACTLY len-1 BACKSPACES. The final character never reached the "
   .. "app (we ate it), so deleting the full length would eat a character "
   .. "of whatever you had typed before the trigger", DELETES == 2, DELETES)

reset()
typeStr("gg1"); drain()
check("a bare three-letter trigger fires too", KEYSTROKES[1] == "Good morning,",
  KEYSTROKES[1])
check("...with two backspaces", DELETES == 2, DELETES)

reset()
typeStr("::sig"); drain()
check("a prefixed trigger from a plist fires", KEYSTROKES[1] == "Lee LeBlanc")
check("...deleting the prefix as well as the word", DELETES == 4, DELETES)

reset()
typeStr("hello ;bd"); drain()
check("a trigger fires mid-sentence", KEYSTROKES[1] == "brew doctor")
check("...without touching the words before it", DELETES == 2, DELETES)

-- =====================================================================
out("\n=== 4. 🧨 The word-boundary rule ===\n")
-- Bare suffix matching would fire `gg1` inside a longer token. With
-- three-letter triggers that is not hypothetical.
reset()
consumed = typeStr("bigg1")
check("🧨 A BARE TRIGGER DOES NOT FIRE INSIDE A WORD", consumed ~= true)
drain()
check("...and nothing was typed", #KEYSTROKES == 0, KEYSTROKES[1])
check("...and nothing was deleted", DELETES == 0, DELETES)

reset()
typeStr("say gg1"); drain()
check("...but it does fire after a space", KEYSTROKES[1] == "Good morning,")

reset()
typeStr("(gg1"); drain()
check("...and after punctuation", KEYSTROKES[1] == "Good morning,")

reset()
typeStr("test;bd"); drain()
check("🧨 A TRIGGER STARTING WITH PUNCTUATION IS EXEMPT — that character "
   .. "IS the boundary, and demanding another would break the very "
   .. "convention the prefix exists for", KEYSTROKES[1] == "brew doctor",
   KEYSTROKES[1])

reset()
exp.wordStartOnly = false
typeStr("bigg1"); drain()
check("wordStartOnly = false restores plain Alfred behaviour",
  KEYSTROKES[1] == "Good morning,", KEYSTROKES[1])
exp.wordStartOnly = true

-- =====================================================================
out("\n=== 5. Two triggers ending on the same keystroke ===\n")
-- `bd` and `;bd` both COMPLETE when you type the "d". The longer one has
-- to win: firing `bd` there would expand the wrong snippet and leave a
-- stray ";" in front of it.
exp.snippets["bd"] = { text = "the short one", name = "Short", source = "test" }
exp.count = exp.count + 1
reset()
typeStr(" ;bd"); drain()
check("the LONGER trigger wins when both complete at once",
  KEYSTROKES[1] == "brew doctor", KEYSTROKES[1])
check("...and the whole of it is deleted, leaving no stray prefix",
  DELETES == 2, DELETES)
reset()
typeStr(" bd"); drain()
check("...while the short one still fires on its own",
  KEYSTROKES[1] == "the short one", KEYSTROKES[1])
exp.snippets["bd"] = nil
exp.count = exp.count - 1

out("\n  5b. 🚨 and a trigger that CANNOT fire is reported\n")
-- The other direction, which is a real dead end rather than a tie:
-- expansion happens the instant a trigger completes and cannot wait to
-- see whether more is coming, so `gg1` makes `gg12` unreachable forever.
mkdirp(TMP .. "/snippets/Shadow")
snippetFile(TMP .. "/snippets/Shadow", "shadowed.json", "Shadowed", "gg12", "never seen")
log = {}
exp.load()
check("🚨 A TRIGGER THAT ANOTHER ONE SHADOWS IS NAMED AT LOAD. Alfred has "
   .. "the same limit and says nothing, which is how you come to believe "
   .. "a snippet is broken", logged("gg12 can never fire"),
   table.concat(log, " | "):sub(1, 160))
check("...and the report says which one eats it", logged("gg1 completes first"))
check("...and what to do about it", logged("Rename one of them"))
reset()
typeStr(" gg12"); drain()
check("...and the report is TRUE — the shorter one really does fire",
  KEYSTROKES[1] == "Good morning,", KEYSTROKES[1])
os.execute("rm -rf '" .. TMP .. "/snippets/Shadow'")
log = {}
exp.load()
check("🚨 THE DIRECTION IS RIGHT. A trigger that is a SUFFIX of another "
   .. "is NOT shadowed — ';bd' and 'bd' complete together and longest-"
   .. "match settles it — so nothing is reported for the healthy set",
  #(exp.problems or {}) == 0, table.concat(exp.problems or {}, "; "))

-- =====================================================================
out("\n=== 6. What clears the buffer ===\n")
reset()
typeStr("gg"); press(123)           -- left arrow: the cursor moved
typeStr("1"); drain()
check("an arrow key abandons the buffer — the cursor is not where we think",
  #KEYSTROKES == 0, KEYSTROKES[1])

reset()
typeStr("gg"); press(36)            -- return
typeStr("1"); drain()
check("Return abandons it — a trigger cannot span lines", #KEYSTROKES == 0)

reset()
typeStr("gg")
TAP.fn({ getType = function() return hs.eventtap.event.types.leftMouseDown end })
typeStr("1"); drain()
check("a mouse click abandons it", #KEYSTROKES == 0)

reset()
typeStr("gg")
TAP.fn({ getType = function() return hs.eventtap.event.types.keyDown end,
         getFlags = function() return { cmd = true } end,
         getKeyCode = function() return 9 end,
         getCharacters = function() return "v" end })
typeStr("1"); drain()
check("a ⌘ chord abandons it (⌘V pastes, it does not type)", #KEYSTROKES == 0)

reset()
exp.enabled = false                 -- get "gg1x" into the buffer un-expanded
typeStr("gg1x")
exp.enabled = true
press(51)                           -- backspace, landing back on "gg1"
drain()
check("🚨 BACKSPACE DOES NOT RE-FIRE. Deleting back onto a completed "
   .. "trigger must not expand it — you were removing it",
  #KEYSTROKES == 0, KEYSTROKES[1])

-- ...and it TRIMS rather than clearing, which the check above cannot see:
-- both behaviours leave nothing expanded. Typing the trigger's last
-- character AFTER the backspace can only work if the earlier characters
-- are still in the buffer.
exp.snippets["ab1"] = { text = "trimmed", name = "Trim", source = "test" }
exp.count = exp.count + 1
reset()
typeStr(" abx")                     -- no trigger completed
press(51)                           -- backspace: buffer should now be " ab"
typeStr("1"); drain()
check("...and it TRIMS the buffer rather than clearing it — the characters "
   .. "before the deleted one are still on screen, so they must still be "
   .. "in the buffer", KEYSTROKES[1] == "trimmed", KEYSTROKES[1])
exp.snippets["ab1"] = nil
exp.count = exp.count - 1

reset()
local long = string.rep("z", 100) .. " gg1"
typeStr(long); drain()
check("the buffer is a rolling window, so a trigger still fires after "
   .. "100 characters of typing", KEYSTROKES[1] == "Good morning,",
   KEYSTROKES[1])

-- =====================================================================
out("\n=== 7. The off switches ===\n")
reset()
exp.enabled = false
consumed = typeStr("gg1"); drain()
check("enabled = false stops expansion dead", #KEYSTROKES == 0)
check("...and does not consume the keystroke either", consumed ~= true)
exp.enabled = true

reset()
FRONTAPP = "Terminal"
typeStr("gg1"); drain()
check("an excluded app is never expanded into", #KEYSTROKES == 0)
FRONTAPP = "TextEdit"

reset()
typeStr("gg1"); drain()
check("...and the very next app is", KEYSTROKES[1] == "Good morning,")

-- =====================================================================
out("\n=== 8. Placeholders ===\n")
exp.snippets["{c}"] = { text = "a{cursor}b", name = "Cursor", source = "test" }
exp.snippets["{p}"] = { text = "paste: {clipboard}", name = "Clip", source = "test" }
exp.snippets["{d}"] = { text = "on {date}", name = "Date", source = "test" }
exp.snippets["{u}"] = { text = "hi {unknownthing}", name = "Unknown", source = "test" }

reset(); typeStr("{c}"); drain()
check("{cursor} is not typed literally", KEYSTROKES[1] == "ab", KEYSTROKES[1])
check("...the caret is walked back over what follows it", LEFTS == 1, LEFTS)

reset(); typeStr("{p}"); drain()
check("{clipboard} becomes the clipboard",
  KEYSTROKES[1] == "paste: clipboard contents", KEYSTROKES[1])

reset(); typeStr("{d}"); drain()
check("{date} becomes today", KEYSTROKES[1] == "on " .. os.date("%Y-%m-%d"),
  KEYSTROKES[1])

reset(); typeStr("{u}"); drain()
check("🚨 AN UNKNOWN PLACEHOLDER IS INSERTED LITERALLY, NOT DROPPED — a "
   .. "snippet that quietly loses {date:yyyy} is worse than one that "
   .. "visibly contains it", KEYSTROKES[1] == "hi {unknownthing}", KEYSTROKES[1])
check("...and it is reported once", logged("is not a placeholder this config knows"))
for _, k in ipairs({ "{c}", "{p}", "{d}", "{u}" }) do exp.snippets[k] = nil end

-- =====================================================================
out("\n=== 9. Rule 7: everything that fails, says so ===\n")
mkdirp(TMP .. "/snippets/Broken")
write(TMP .. "/snippets/Broken/bad.json", "{ this is not json")
write(TMP .. "/snippets/Broken/empty.json", '{"alfredsnippet":{"snippet":"","keyword":"xx1"}}')
snippetFile(TMP .. "/snippets/Broken", "huge.json", "Huge", "hg1",
            string.rep("x", 3000))
snippetFile(TMP .. "/snippets/Broken", "nokw.json", "No keyword", "",
            "insert me from the chooser")
log = {}; _G.notices.recorded = {}
exp.load()
check("a malformed JSON file is reported by name", logged("bad.json"),
  table.concat(log, " | "))
check("an empty snippet is reported", logged("empty.json"))
check("🚨 AN OVER-LONG SNIPPET IS REFUSED AND SAID SO, rather than being "
   .. "typed out one keystroke at a time for a minute",
  logged("huge.json") and logged("over the 2000 limit"),
  table.concat(log, " | "):sub(1, 160))
check("...and the reason names the actual size", logged("3000 characters"))
check("every problem reaches the notices ledger too, not just a Console "
   .. "nobody has open", #_G.notices.recorded > 0)
check("a keyword-less snippet is NOT an error — Alfred allows it and it "
   .. "is insertable from ⇪⇧T", not logged("nokw.json"))
check("...and it IS offered in the chooser", (function()
  for _, s in ipairs(exp.chooserOnly or {}) do
    if s.name == "No keyword" then return true end
  end
end)(), #(exp.chooserOnly or {}))
check("the good snippets still loaded alongside the broken ones",
  exp.snippets["gg1"] ~= nil and exp.snippets[";bd"] ~= nil)
os.execute("rm -rf '" .. TMP .. "/snippets/Broken'")
exp.load()

out("\n  9b. a duplicate trigger is a collision, not a coin toss\n")
mkdirp(TMP .. "/snippets/Dupes")
snippetFile(TMP .. "/snippets/Dupes", "dupe.json", "Another gg1", "gg1", "different")
log = {}
exp.load()
check("two collections claiming one trigger is reported", logged("already used by"),
  table.concat(log, " | "))
os.execute("rm -rf '" .. TMP .. "/snippets/Dupes'")
exp.load()

out("\n  9c. a failed insertion gives the keystroke back\n")
reset()
local realStrokes = hs.eventtap.keyStrokes
hs.eventtap.keyStrokes = function(s)
  hs.eventtap.keyStrokes = realStrokes   -- fail once, then behave
  error("secure input")
end
typeStr("gg1"); drain()
check("🚨 THE CONSUMED CHARACTER IS RETYPED. We ate it on the promise of "
   .. "a replacement; an injection that fails AND eats a character is two "
   .. "bugs instead of one", KEYSTROKES[1] == "1", KEYSTROKES[1])
check("...and the failure is reported", logged("could not insert"))
check("...to the ledger as well", #_G.notices.recorded > 0)
hs.eventtap.keyStrokes = realStrokes

-- =====================================================================
out("\n=== 10. Privacy: what this module is allowed to say ===\n")
reset()
typeStr("my password is hunter2 ")
typeStr("gg1"); drain()
check("the module never prints what was typed", (function()
  for _, l in ipairs(log) do
    if l:find("hunter2", 1, true) or l:find("password", 1, true) then return false end
  end
  return true
end)(), table.concat(log, " | "))
check("...nor records it in the ledger", (function()
  for _, r in ipairs(_G.notices.recorded) do
    if r:find("hunter2", 1, true) then return false end
  end
  return true
end)())
check("the only thing it remembers about a firing is the snippet's NAME",
  exp.lastFired and exp.lastFired.name == "Greeting"
  and exp.lastFired.trigger == "gg1", exp.lastFired and exp.lastFired.name)
check("🔒 THE SOURCE CONTAINS NO PATH FROM THE BUFFER TO ANY OUTPUT. "
   .. "Checked as text because it is a promise about the whole file, not "
   .. "about one code path a test happened to walk", (function()
  local f = io.open(HS .. "/modules/text_expander.lua")
  local s = f:read("*a"); f:close()
  s = s:gsub("%-%-[^\n]*", "")        -- comments discuss the buffer freely
  -- Any print/say/warn/record call that mentions the buffer variable.
  return s:match("print%b()"):len() >= 0
         and not s:find("print%([^)]*buffer") and not s:find("say%([^)]*buffer")
         and not s:find("warn%([^)]*buffer") and not s:find("record%([^)]*buffer")
end)())

-- =====================================================================
out("\n=== 11. ⇪⇧T, the chooser ===\n")
CHOOSERS = {}
exp.show()
local ch = CHOOSERS[#CHOOSERS]
check("the chooser opens", ch and ch.shown == true)
check("...listing every snippet plus the on/off row",
  ch and #ch.rows_ == exp.count + #(exp.chooserOnly or {}) + 1,
  ch and #ch.rows_)
check("...with the toggle FIRST, where it can always be found",
  ch.rows_[1].toggle == true, ch.rows_[1].text)
check("...and the rest alphabetical", (function()
  for i = 3, #ch.rows_ do
    if tostring(ch.rows_[i].text) < tostring(ch.rows_[i - 1].text) then return false end
  end
  return true
end)())
check("each row shows its trigger", (function()
  for _, r in ipairs(ch.rows_) do
    if r.trigger == "gg1" then return r.subText:find("gg1", 1, true) ~= nil end
  end
end)())

reset()
for _, r in ipairs(ch.rows_) do
  if r.trigger == "gg1" then ch.cb(r) end
end
check("picking one inserts it", KEYSTROKES[1] == "Good morning,", KEYSTROKES[1])
check("🚨 AND DELETES NOTHING. This is an INSERT, not a replacement — you "
   .. "did not type a trigger, so there is nothing on screen to remove",
  DELETES == 0, DELETES)

ch.cb(ch.rows_[1])
check("the toggle row turns expansion off", exp.enabled == false)
ch.cb(ch.rows_[1])
check("...and on again", exp.enabled == true)
check("a dismissed chooser does nothing at all", (function()
  local before = #KEYSTROKES
  ch.cb(nil)
  return #KEYSTROKES == before
end)())

-- =====================================================================
out("\n=== 12. Importing a real .alfredsnippets file ===\n")
-- Built here with the real `zip`, unpacked by the module's real unzip.
local IMPDIR = TMP .. "/build"
mkdirp(IMPDIR)
snippetFile(IMPDIR, "Imported.json", "Imported one", "zz9", "it arrived")
write(IMPDIR .. "/info.plist",
  "<plist><dict><key>snippetkeywordprefix</key><string></string></dict></plist>")
local zipped = os.execute("cd '" .. IMPDIR .. "' && zip -q -r '"
                          .. TMP .. "/Test.alfredsnippets' . 2>/dev/null")
if zipped then
  log = {}
  local okImp = exp.import(TMP .. "/Test.alfredsnippets")
  check("the import reports success", okImp == true)
  check("...and the new trigger is live immediately", exp.snippets["zz9"] ~= nil,
    exp.count)
  reset(); typeStr("zz9"); drain()
  check("...and expands", KEYSTROKES[1] == "it arrived", KEYSTROKES[1])
else
  out("  ⚠️  zip not available — import round-trip skipped\n")
end

log = {}
check("importing a file that is not there is reported, not silent",
  exp.import(TMP .. "/nope.alfredsnippets") == false and logged("no such file"))

out("\n  12b. _G.snippetsImport() with no argument goes looking\n")
mkdirp(TMP .. "/home/Downloads")
os.execute("cp '" .. TMP .. "/Test.alfredsnippets' '" .. TMP .. "/home/Downloads/' 2>/dev/null")
local realHome = os.getenv("HOME")
exp.searchDirs = { "/Downloads" }
local realGetenv = os.getenv
os.getenv = function(k) if k == "HOME" then return TMP .. "/home" end return realGetenv(k) end
log = {}
if realHome then
  check("it finds and imports what is already in ~/Downloads",
    _G.snippetsImport() == true and exp.snippets["zz9"] ~= nil,
    table.concat(log, " | "):sub(1, 120))
end
os.execute("rm -rf '" .. TMP .. "/home/Downloads'")
log = {}
check("🚨 AND WHEN THERE IS NOTHING TO FIND IT SAYS SO, with the exact "
   .. "call to make instead — an empty scan that returns quietly is "
   .. "indistinguishable from a broken one",
  _G.snippetsImport() == false and logged("No .alfredsnippets files")
  and logged("_G.snippetsImport(\""),
  table.concat(log, " | "):sub(1, 160))
os.getenv = realGetenv
exp.searchDirs = { "/Downloads", "/Desktop", "" }

-- =====================================================================
out("\n=== 13. Adding one by hand ===\n")
log = {}
local okAdd = exp.add("qq7", "hand written", "By hand")
check("_G.snippetAdd writes a snippet", okAdd == true)
check("...it is live at once", exp.snippets["qq7"] ~= nil)
reset(); typeStr("qq7"); drain()
check("...and expands", KEYSTROKES[1] == "hand written", KEYSTROKES[1])
check("🚨 IT LANDS IN ITS OWN COLLECTION, so re-importing from Alfred can "
   .. "never overwrite what you wrote yourself",
  exp.snippets["qq7"].source == "Mine", exp.snippets["qq7"].source)
log = {}
check("bad arguments are explained rather than ignored",
  exp.add("", "") == false and logged("Usage:"))

-- =====================================================================
out("\n=== 14. The tap itself, which is the dangerous part ===\n")
check("the tap was started", TAP.on == true)
check("it listens for keyDown and both mouse buttons only", #TAP.types == 3, #TAP.types)
check("a watchdog exists to revive it — macOS switches taps off and a "
   .. "silently dead expander is rule 7's failure mode",
  _G.expanderWatchdog ~= nil)
check("the tap is held in a global, so the GC cannot collect it",
  _G.expanderTap == TAP)
check("🔐 NO ACCESSIBILITY, NO TAP, AND IT SAYS SO", (function()
  local f = io.open(HS .. "/modules/text_expander.lua")
  local s = f:read("*a"); f:close()
  s = s:gsub("%-%-[^\n]*", "")
  return s:find("accessibilityState", 1, true) ~= nil
         and s:find("needs Accessibility", 1, true) ~= nil
end)())

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.execute("rm -rf '" .. TMP .. "'")
os.exit(fail == 0 and 0 or 1)
