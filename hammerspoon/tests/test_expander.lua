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
-- The paste path, watched: what went on the clipboard and in what order,
-- whether ⌘V was pressed, how long the restore waited, and whether the
-- shared pasteboard watcher was told to look away.
local PASTED, CMDV, SUPPRESSED = 0, 0, 0
local CLIPSET, RESTOREDELAY = {}, nil

local function mkdirp(p) os.execute("mkdir -p '" .. p .. "'") end
local function write(p, s)
  local f = assert(io.open(p, "w")); f:write(s); f:close()
end

hs = {
  fs = {
    -- 🚨 THIS STUB RETURNS **TWO** VALUES AND THE ITERATOR DEMANDS THE
    -- SECOND, because the real hs.fs.dir does. It used to return a
    -- self-contained closure that needed no state — which meant
    --      local iter = hs.fs.dir(p) ; for e in iter do
    -- worked perfectly here and threw on a real Mac:
    --      bad argument #1 to 'for iterator' (directory metatable
    --      expected, got nil)
    -- 6.69.0 shipped that. warm() died on the first directory and NOT ONE
    -- of LL's 2,006 snippets loaded. A stub more forgiving than the API it
    -- stands in for does not test the code, it ratifies my idea of the
    -- API — the same failure as reading a module list from the file that
    -- had it wrong. So the state is mandatory here now.
    dir = function(p)
      local h = io.popen("ls -a '" .. p .. "' 2>/dev/null")
      if not h then error("no such directory") end
      local names = {}
      for l in h:lines() do names[#names + 1] = l end
      h:close()
      if #names == 0 then error("no such directory") end
      local dirObj = { i = 0, names = names }
      local function iter(state)
        if type(state) ~= "table" or not state.names then
          error("bad argument #1 to 'for iterator' "
                .. "(directory metatable expected, got "
                .. type(state) .. ")", 2)
        end
        state.i = state.i + 1
        return state.names[state.i]
      end
      return iter, dirObj
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
        -- \r as well as \n: two of LL's snippets carry Windows line
        -- endings, and a decoder that silently dropped the CR would make
        -- the normalisation test pass without normalising anything.
        a[k] = v:gsub("\\r", "\r"):gsub("\\n", "\n"):gsub('\\"', '"')
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
      elseif key == "left" then LEFTS = LEFTS + 1
      elseif key == "v" and mods and mods[1] == "cmd" then
        CMDV = CMDV + 1; PASTED = PASTED + 1 end
    end,
    keyStrokes = function(s) table.insert(KEYSTROKES, s) end,
  },
  timer = {
    secondsSinceEpoch = function() return 1000 end,
    doAfter = function(d, fn)
      local t = { delay = d, fn = fn, running = true }
      function t:stop() self.running = false end
      -- The clipboard restore is the only 0.25s timer this module sets.
      if d == 0.25 then RESTOREDELAY = d end
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
  pasteboard = {
    getContents = function() return CLIP end,
    setContents = function(t) table.insert(CLIPSET, t) end,
  },
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
  configdir = TMP .. "/cfg",
}

print = function(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  table.insert(log, table.concat(p, " "))
end

_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.pasteboardSuppress = function(secs) SUPPRESSED = SUPPRESSED + 1 end
-- The real shared injection guard from init.lua, in miniature: the
-- expander must route its typing through it so autocorrect's tap stands
-- down. Counting depth here proves it is actually used.
_G.injectDepth, INJECT_PEAK = 0, 0
_G.typingInjection = function() return _G.injectDepth > 0 end
_G.withInjection = function(fn)
  _G.injectDepth = _G.injectDepth + 1
  if _G.injectDepth > INJECT_PEAK then INJECT_PEAK = _G.injectDepth end
  local ok, err = pcall(fn)
  _G.injectDepth = _G.injectDepth - 1
  return ok, err
end

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
-- 🚨 exp.snippets IS INDEXED. Writing a trigger straight into the table
-- leaves the reverse trie that exp.match walks without it, so the snippet
-- exists and never fires. Production only ever writes it through load(),
-- which reindexes; tests go through here for the same reason.
local function addSnippet(trigger, text, name)
  exp.snippets[trigger] = { text = text, name = name or trigger, source = "test" }
  exp.count = exp.count + 1
  if #trigger > (exp.longestBytes or 0) then exp.longestBytes = #trigger end
  exp.buildIndex()   -- rebuilds the trie AND the ambiguity map
end
local function dropSnippet(trigger)
  exp.snippets[trigger] = nil
  exp.count = exp.count - 1
  exp.buildIndex()
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
  PASTED, CMDV, SUPPRESSED, CLIPSET, RESTOREDELAY = 0, 0, 0, {}, nil
  _G.notices.recorded = {}
  exp.cancelPending(nil)
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
addSnippet("bd", "the short one", "Short")
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
dropSnippet("bd")

out("\n  5b. ⏳ a trigger that is a PREFIX of another — both must work\n")
-- The real collision, from LL's Mac symbols pack: !!del is ⌫ and !!delf
-- is ⌦. Firing on the "l" makes !!delf unreachable forever and leaves a
-- stray "f" behind. The short one waits instead.
addSnippet("!!del",  "⌫", "delete")
addSnippet("!!delf", "⌦", "delete forward")
addSnippet("!!tab",  "⇥", "tab")

check("the shorter trigger is recorded as ambiguous",
  exp.ambiguous["!!del"] ~= nil and exp.ambiguous["!!del"][1] == "!!delf",
  exp.ambiguous["!!del"])
check("...and an unambiguous one is not — nothing else pays for this",
  exp.ambiguous["!!tab"] == nil and exp.ambiguous[";bd"] == nil)

reset()
local consumed5 = typeStr(" !!del")
check("⏳ THE SHORT TRIGGER DOES NOT FIRE YET", #KEYSTROKES == 0, KEYSTROKES[1])
check("🚨 AND IT CONSUMES NOTHING WHILE WAITING. The characters reach the "
   .. "document exactly as typed, so abandoning the wait owes you nothing "
   .. "— that is what makes deferring safe at all", consumed5 ~= true)
check("...a wait really is armed", exp.pending ~= nil
  and exp.pending.trigger == "!!del", exp.pending and exp.pending.trigger)
drain()
check("...and it fires once you stop typing", KEYSTROKES[1] == "⌫", KEYSTROKES[1])
check("🚨 DELETING THE **WHOLE** TRIGGER, not len-1: nothing was consumed "
   .. "on the way in, so all five characters are on screen",
  DELETES == 5, DELETES)

reset()
typeStr(" !!delf"); drain()
check("⏳ AND THE LONGER ONE STILL WORKS — this is the snippet that was "
   .. "unreachable before", KEYSTROKES[1] == "⌦", KEYSTROKES[1])
check("...the wait was dropped the moment it completed", exp.pending == nil)
check("...len-1 deletes (5 of !!delf's 6), because the final keystroke WAS "
   .. "consumed on this path", DELETES == 5, DELETES)

reset()
typeStr(" !!del")
local consumedTail = typeStr(" ")     -- a space can never extend to !!delf
check("🚨 A CHARACTER THAT RULES THE LONGER TRIGGER OUT SETTLES IT "
   .. "IMMEDIATELY — no 0.35s pause you have to sit through", consumedTail == true)
drain()
check("...the short snippet is inserted", KEYSTROKES[1] == "⌫ ", KEYSTROKES[1])
check("...with the settling character re-typed after it, the same move "
   .. "autocorrect makes with its boundary key",
  (KEYSTROKES[1] or ""):sub(-1) == " ")
check("...and the deletes cover the trigger AND that character",
  DELETES == 6, DELETES)

out("\n  5c. 🚨 a pending expansion must never fire into a moved caret\n")
-- This is the sharpest edge in the module: a deferred expansion deletes
-- backwards from wherever the caret IS. If the caret moved, those deletes
-- land on text nobody asked to remove.
for _, case in ipairs({
  { "an arrow key",   function() press(123) end },
  { "Return",         function() press(36)  end },
  { "Escape",         function() press(53)  end },
  { "backspace",      function() press(51)  end },
  { "a mouse click",  function()
      TAP.fn({ getType = function() return hs.eventtap.event.types.leftMouseDown end })
    end },
  { "a ⌘ chord",      function()
      TAP.fn({ getType = function() return hs.eventtap.event.types.keyDown end,
               getFlags = function() return { cmd = true } end,
               getKeyCode = function() return 9 end,
               getCharacters = function() return "v" end })
    end },
}) do
  reset()
  typeStr(" !!del")
  case[2]()
  check("🚨 " .. case[1] .. " cancels the wait outright", exp.pending == nil)
  drain()
  check("   ...and nothing is typed or deleted afterwards",
    #KEYSTROKES == 0 and DELETES == 0, tostring(KEYSTROKES[1]) .. "/" .. DELETES)
end

reset()
typeStr(" !!de")
check("a partial trigger arms nothing at all", exp.pending == nil)
dropSnippet("!!del"); dropSnippet("!!delf"); dropSnippet("!!tab")

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
addSnippet("ab1", "trimmed", "Trim")
reset()
typeStr(" abx")                     -- no trigger completed
press(51)                           -- backspace: buffer should now be " ab"
typeStr("1"); drain()
check("...and it TRIMS the buffer rather than clearing it — the characters "
   .. "before the deleted one are still on screen, so they must still be "
   .. "in the buffer", KEYSTROKES[1] == "trimmed", KEYSTROKES[1])
dropSnippet("ab1")

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
addSnippet("{c}", "a{cursor}b", "Cursor")
addSnippet("{p}", "paste: {clipboard}", "Clip")
addSnippet("{d}", "on {date}", "Date")
addSnippet("{u}", "hi {unknownthing}", "Unknown")

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
for _, k in ipairs({ "{c}", "{p}", "{d}", "{u}" }) do dropSnippet(k) end

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

-- =====================================================================
out("\n=== 15. LL'S ACTUAL FIVE COLLECTIONS, at their real shape ===\n")
-- =====================================================================
-- Emoji Pack · ComposeKey · Ghostty or Terminal · Mac symbols ·
-- textpanders. 2,006 triggers between them. Everything asserted below
-- was READ OUT OF THOSE FILES before it was written here:
--
--   collection            snippets   info.plist prefix
--   Emoji_Pack               1349    NO info.plist AT ALL
--   ComposeKey                548    § (a two-byte character)
--   textpanders                80    empty (bare gg1-style keywords)
--   Mac_symbols                23    !!
--   Ghostty_or_Terminal         6    empty (";" baked into each keyword)
--
--   1,347 triggers begin with ":"   ·  548 with "§"  ·  24 with "!"
--       7 with ";"  ·  2 with "#"   ·  1 with an emoji
--      77 begin with a letter or digit — THE ONLY ONES the word-boundary
--         rule touches, and exactly the gg1 family it exists for
--     636 triggers CONTAIN A SPACE (":aerial tramway:", "!!caps lock")
--   1,946 of 2,006 snippets are non-ASCII; 1,193 contain astral
--         characters — emoji are the common case here, not the edge one
--       8 snippets are multi-line or over 80 characters
--       2 carry Windows CRLF line endings
--       3 triggers are shadowed: !!delf, !!tableft, !!tabright
--       0 triggers collide across collections
--
-- 🚨 IT IS GENERATED, NOT VENDORED, FOR TWO REASONS. textpanders holds
-- LL's email addresses, phone numbers, employee ID and out-of-office
-- text — that does not belong in a git repository. And 2,006 files is
-- 8MB of tiny blobs. What matters is the SHAPE, and every number above
-- came off the real files.
-- ⚠️ THE FILLER KEYWORDS ARE ZERO-PADDED (:e0001:, c001, m01). Unpadded
-- counters would make c1 a prefix of c10 and invent fifty-seven prefix
-- collisions the real corpus does not have — the real one has exactly
-- three, all in Mac symbols. A fixture that manufactures the condition
-- under test is a fixture that proves nothing.
local BIG = TMP .. "/big"
os.execute("rm -rf '" .. BIG .. "'")
local function collection(name, plistPrefix)
  local d = BIG .. "/snippets/" .. name
  mkdirp(d)
  if plistPrefix then
    write(d .. "/info.plist",
      "<plist><dict><key>snippetkeywordprefix</key><string>" .. plistPrefix
      .. "</string><key>snippetkeywordsuffix</key><string></string></dict></plist>")
  end
  return d
end
-- Emoji Pack: NO info.plist, :colon: keywords, astral emoji, spaces
local dEmoji = collection("Emoji_Pack", nil)
snippetFile(dEmoji, "100.json", "💯 :100:", ":100:", "💯")
snippetFile(dEmoji, "tram.json", "🚡 :aerial tramway:", ":aerial tramway:", "🚡")
snippetFile(dEmoji, "plus1.json", "👍 :+1:", ":+1:", "👍")
for i = 1, 1346 do
  snippetFile(dEmoji, "e" .. i .. ".json", "emoji " .. i,
              string.format(":e%04d:", i), "🙂")
end
-- ComposeKey: § prefix, bare keywords, symbol output
local dCompose = collection("ComposeKey", "§")
snippetFile(dCompose, "sect.json", "symbol section (3)", "!s", "§")
snippetFile(dCompose, "esc.json", "literal section", "§", "§")
snippetFile(dCompose, "down.json", "arrow down (1)", "|v", "↓")
for i = 1, 545 do
  snippetFile(dCompose, "c" .. i .. ".json", "compose " .. i,
              string.format("c%03d", i), "±")
end
-- Mac symbols: !! prefix, spaces in keywords, AND the real collisions
local dMac = collection("Mac_symbols", "!!")
snippetFile(dMac, "del.json",  "delete / backspace", "del",  "⌫")
snippetFile(dMac, "delf.json", "delete forward",     "delf", "⌦")
snippetFile(dMac, "tab.json",  "tab",                "tab",  "⇥")
snippetFile(dMac, "tabl.json", "tab left",       "tableft",  "⇤")
snippetFile(dMac, "tabr.json", "tab right",     "tabright",  "⇥")
snippetFile(dMac, "caps.json", "caps lock",    "caps lock",  "⇪")
for i = 1, 17 do
  snippetFile(dMac, "m" .. i .. ".json", "symbol " .. i,
              string.format("m%02d", i), "⌘")
end
-- Ghostty: empty prefix, ";" already in the keyword, one alnum-initial
local dGhost = collection("Ghostty_or_Terminal", "")
snippetFile(dGhost, "bd.json", "Brew doctor", ";bd", "Brew doctor")
snippetFile(dGhost, "op.json", "1 Password", "1OP", "op --help")
for i = 1, 4 do
  snippetFile(dGhost, "g" .. i .. ".json", "ghostty " .. i,
              ";g" .. i, "brew " .. i)
end
-- textpanders: bare two-letters-and-a-digit, CRLF, multi-line, long
local dText = collection("textpanders", "")
snippetFile(dText, "gg1.json", "Email", "gg1", "someone@example.com")
snippetFile(dText, "kn1.json", "Kindly", "kn1", "Kindly,\\r\\nLL")
snippetFile(dText, "ll1.json", "Thanks", "ll1", "Thanks!\\r\\n\\r\\nLL")
snippetFile(dText, "tkn.json", "Long one", "tkn", string.rep("word ", 60))
snippetFile(dText, "hte.json", "the", "hte", "the")
for i = 1, 75 do
  snippetFile(dText, "t" .. i .. ".json", "text " .. i,
              string.format("t%02dz", i), "plain " .. i)
end

exp.dir = BIG .. "/snippets"
local t0 = os.clock()
exp.load()
local loadMs = (os.clock() - t0) * 1000

out("   -- it all loaded --\n")
check("all 2,006 triggers loaded from five collections", exp.count == 2006, exp.count)
check("nothing failed to load", #(exp.problems or {}) == 0,
  table.concat(exp.problems or {}, " | "):sub(1, 200))
check("Emoji Pack loaded WITH NO info.plist — a missing plist is a "
   .. "collection with no prefix, not a broken one",
  exp.snippets[":100:"] ~= nil and exp.snippets[":100:"].text == "💯")
check("🚨 THE § PREFIX IS APPLIED, AND IT IS TWO BYTES. A prefix is not "
   .. "required to be ASCII and this one is not",
  exp.snippets["§|v"] ~= nil and #"§" == 2, exp.snippets["§|v"])
check("...so ComposeKey's own escape works: §§ gives you a literal §",
  exp.snippets["§§"] ~= nil and exp.snippets["§§"].text == "§")
check("the !! prefix is applied", exp.snippets["!!del"] ~= nil)
check("...even to a keyword containing a space (636 of them do)",
  exp.snippets["!!caps lock"] ~= nil)
check("Ghostty's empty prefix leaves ;bd alone",
  exp.snippets[";bd"] ~= nil and exp.snippets[";;bd"] == nil)
check("a bare gg1 sits alongside all of it", exp.snippets["gg1"] ~= nil)

out("   -- the three shadowed Mac symbols, which now work --\n")
check("!!delf, !!tableft and !!tabright are all present",
  exp.snippets["!!delf"] and exp.snippets["!!tableft"]
  and exp.snippets["!!tabright"] and true)
check("...and !!del and !!tab are the two that wait for them",
  exp.ambiguousCount == 2, exp.ambiguousCount)
check("🚨 AND NOTHING ELSE WAITS. 2,004 of 2,006 triggers fire instantly; "
   .. "the deferral is paid for by the two that need it",
  exp.ambiguous[":100:"] == nil and exp.ambiguous["gg1"] == nil
  and exp.ambiguous[";bd"] == nil)
reset(); typeStr(" !!tabright"); drain()
check("⇥ from !!tabright — unreachable before 6.69.0", KEYSTROKES[1] == "⇥",
  KEYSTROKES[1])
reset(); typeStr(" !!tab"); drain()
check("...and plain !!tab still gets there", KEYSTROKES[1] == "⇥", KEYSTROKES[1])

out("   -- CRLF, which would send a chat message early --\n")
check("🚨 WINDOWS LINE ENDINGS ARE NORMALISED AT LOAD. Alfred stored what "
   .. "was on the clipboard, and a lone CR is a Return to macOS: pasted "
   .. "into a chat box, \"Kindly,\" would send on its own",
  exp.snippets["kn1"].text == "Kindly,\nLL", exp.snippets["kn1"].text)
check("...for the blank-line case too", exp.snippets["ll1"].text == "Thanks!\n\nLL")

out("   -- typed or pasted, and the clipboard comes back --\n")
reset(); typeStr(" gg1"); drain()
check("a short single-line snippet is TYPED, leaving the clipboard alone",
  KEYSTROKES[1] == "someone@example.com" and PASTED == 0,
  tostring(KEYSTROKES[1]) .. " pasted=" .. PASTED)
reset(); typeStr(" kn1"); drain()
check("🚨 A MULTI-LINE SNIPPET IS PASTED, NOT TYPED. A synthetic Return in "
   .. "a Teams or Asana box SENDS the message instead of breaking the line",
  PASTED == 1 and #KEYSTROKES == 0, PASTED)
check("...the snippet really went on the clipboard",
  CLIPSET[1] == "Kindly,\nLL", CLIPSET[1])
check("...⌘V was pressed", CMDV == 1, CMDV)
check("🚨 AND YOUR CLIPBOARD IS PUT BACK. Borrowing it and forgetting to "
   .. "return it is worse than not having the feature",
  CLIPSET[#CLIPSET] == "clipboard contents", CLIPSET[#CLIPSET])
check("...the restore is DELAYED, because ⌘V is asynchronous from here — "
   .. "restoring in the same breath is a race the app loses",
  RESTOREDELAY ~= nil and RESTOREDELAY > 0, RESTOREDELAY)
check("...and the clipboard-history watcher is told to ignore it, so your "
   .. "history is not reordered by a snippet",
  SUPPRESSED > 0, SUPPRESSED)
reset(); typeStr(" tkn"); drain()
check("a long single-line snippet is pasted too", PASTED == 1, PASTED)

out("   -- ⌨️ SPEED: this runs between your key and the letter appearing --\n")
check("loading 2,006 snippets stays off the boot path (it is in warm())",
  type(mod.warm) == "function")
out(("      load: %.0fms for 2,006 files\n"):format(loadMs))
check("the reverse trie was built", (exp.indexNodes or 0) > 2006, exp.indexNodes)
local t1 = os.clock()
local N = 3000
for i = 1, N do exp.match("some ordinary typing " .. i) end
local perKey = (os.clock() - t1) / N * 1e6
out(("      match: %.1fµs per keystroke over 2,006 triggers\n"):format(perKey))
check("🚨 MATCHING IS BOUNDED BY THE LONGEST TRIGGER, NOT BY HOW MANY "
   .. "THERE ARE. The first version compared all 2,006 per character "
   .. "typed, on the main thread, between your key and the letter",
  perKey < 60, ("%.1fµs"):format(perKey))
check("...and a miss walks only as far as the trie has children", (function()
  -- "zzzz" shares no tail with any trigger, so the walk stops at depth 1.
  local t = os.clock()
  for _ = 1, N do exp.match("qqqqzzzz") end
  return (os.clock() - t) / N * 1e6 < perKey + 20
end)())

os.execute("rm -rf '" .. BIG .. "'")

-- =====================================================================
out("\n=== 16. Two taps on one keyboard ===\n")
-- =====================================================================
-- Autocorrect watches every keystroke and types corrections back.
-- This module watches every keystroke and types snippets back. Each one
-- had its own "am I injecting" flag, which is half of what is needed:
-- a flag only tells the module that wrote it to stand down.
reset()
INJECT_PEAK = 0
typeStr(" gg1"); drain()
check("🚨 THE EXPANSION GOES THROUGH THE **SHARED** GUARD, so autocorrect's "
   .. "tap stands down while we type. Without it, expanding `hte` into "
   .. "\"the\" fed a word nobody typed into the spelling corrector",
  INJECT_PEAK > 0, INJECT_PEAK)
check("...and the guard is released afterwards — a stuck guard switches "
   .. "BOTH typing features off silently, which is the worst outcome",
  _G.injectDepth == 0, _G.injectDepth)

reset()
INJECT_PEAK = 0
local realStrokes2 = hs.eventtap.keyStrokes
hs.eventtap.keyStrokes = function() error("app refused") end
typeStr(" gg1"); drain()
hs.eventtap.keyStrokes = realStrokes2
check("🚨 AND IT IS RELEASED EVEN WHEN THE INJECTION THROWS. A guard left "
   .. "standing would leave autocorrect and the expander both switched "
   .. "off for the rest of the session, with nothing to switch them back",
  _G.injectDepth == 0, _G.injectDepth)

check("autocorrect honours the shared guard too — checked in its source, "
   .. "because this is a promise about a file this suite does not load",
  (function()
    local f = io.open(HS .. "/modules/autocorrect.lua")
    local a = f:read("*a"); f:close()
    a = a:gsub("%-%-[^\n]*", "")          -- comments discuss it freely
    return a:find("_G.typingInjection", 1, true) ~= nil
           and a:find("_G.withInjection", 1, true) ~= nil
  end)())
check("...and this module never types outside the guard", (function()
  local f = io.open(HS .. "/modules/text_expander.lua")
  local m = f:read("*a"); f:close()
  m = m:gsub("%-%-[^\n]*", "")
  -- Every keyStrokes call is either inside withInjection or is the
  -- give-the-keystroke-back path, which runs after the guard is released
  -- and must NOT be inside it.
  local total = select(2, m:gsub("hs%.eventtap%.keyStrokes", ""))
  return total >= 2 and m:find("_G.withInjection", 1, true) ~= nil, total
end)())

-- =====================================================================
out("\n=== 17. 📦 SHIPPED SNIPPETS — unzipping IS the install ===\n")
-- LL: "wait... I still have to use the .alfredsnippets?" No. The release
-- zip carries all five collections already unpacked to
-- ~/.hammerspoon/snippets, scanned IN ADDITION to the OneDrive folder.
-- §15 pointed exp.dir at the big generated corpus and §16 never put it
-- back. Restored explicitly: a suite that silently inherits a previous
-- section's state is a suite whose later checks mean something else.
exp.dir = TMP .. "/snippets"
mkdirp(TMP .. "/bundled/Shipped")
snippetFile(TMP .. "/bundled/Shipped", "s.json", "Shipped", "sh9", "from the zip")
snippetFile(TMP .. "/bundled/Shipped", "dup.json", "Bundled dup", "dup1", "BUNDLED")
mkdirp(TMP .. "/snippets/Mine")
snippetFile(TMP .. "/snippets/Mine", "dup.json", "My dup", "dup1", "MINE")
exp.bundledDir = TMP .. "/bundled"
exp.load()
check("a bundled snippet loads with no import step at all",
  exp.snippets["sh9"] ~= nil and exp.snippets["sh9"].text == "from the zip",
  exp.snippets["sh9"])
check("...alongside everything in the OneDrive folder",
  exp.snippets[";bd"] ~= nil and exp.snippets["gg1"] ~= nil)
check("🚨 AND YOURS WINS ON A COLLISION, so re-unzipping can never "
   .. "clobber a snippet you imported or wrote yourself",
  exp.snippets["dup1"].text == "MINE", exp.snippets["dup1"].text)
check("a missing bundled folder is simply nothing, not an error",
  (function()
     exp.bundledDir = TMP .. "/nope"
     local ok = exp.load()
     return ok and exp.snippets["gg1"] ~= nil
   end)())
exp.bundledDir = nil

-- =====================================================================
out("\n=== 18. ⚡ Action triggers — the machinery `begone` rides ===\n")
-- =====================================================================
-- 6.92.0: a snippet whose payload is a FUNCTION. Same removal contract
-- as an expansion, nothing inserted, and — the part that would rot
-- silently — the action must survive exp.load() rebuilding exp.snippets
-- from disk, because _G.snippetsImport() calls that at any time.
reset()
local RAN, FAILME = 0, false
check("addAction is published for other modules",
  type(PROVIDED["expander.addAction"]) == "function")
check("...and refuses garbage",
  PROVIDED["expander.addAction"](nil, print) == false
  and PROVIDED["expander.addAction"]("x", "not a function") == false)
local countBefore = exp.count
check("a word registers as an action",
  PROVIDED["expander.addAction"]("begone",
    function() RAN = RAN + 1 ; if FAILME then error("boom") end end,
    "Begone test") == true)
check("...and counts as one more trigger", exp.count == countBefore + 1,
  exp.count)

reset()
typeStr("begone")
drain()
check("typing the word RUNS the function", RAN == 1, RAN)
check("len-1 backspaces — the word deletes itself",
  DELETES == 5, DELETES)
check("and NOTHING is typed in its place", #KEYSTROKES == 0, KEYSTROKES[1])
check("lastFired records the action for ⇪⇧D",
  exp.lastFired and exp.lastFired.name == "Begone test",
  exp.lastFired and exp.lastFired.name)

reset()
typeStr("xbegone")
drain()
check("the word-boundary rule still guards it — 'xbegone' does not fire",
  RAN == 1, RAN)

reset()
FAILME = true
typeStr("begone")
drain()
check("a throwing action is caught, not crashed through", RAN == 2)
check("...and reported to the ledger", (function()
    for _, l in ipairs(_G.notices.recorded) do
      if l:find("action failed", 1, true) then return true end
    end
  end)())
FAILME = false

check("🚨 exp.load() keeps the action alive across a rescan",
  (function()
    exp.load()
    return exp.snippets["begone"] ~= nil
       and type(exp.snippets["begone"].fn) == "function"
  end)())
reset()
typeStr("begone")
drain()
check("...and it still fires after that rescan", RAN == 3, RAN)

check("the ⇪⇧T chooser lists it without touching .text",
  (function()
    local nC = #CHOOSERS
    local okShow = exp.show()
    if not (okShow and #CHOOSERS > nC) then return false end
    for _, row in ipairs(CHOOSERS[#CHOOSERS].rows_ or {}) do
      if row.trigger == "begone" then
        return tostring(row.subText):find("action", 1, true) ~= nil
      end
    end
    return false
  end)())
check("...and PICKING it runs it — no deletes, nothing typed",
  (function()
    reset()
    local c = CHOOSERS[#CHOOSERS]
    c.cb({ trigger = "begone", snip = exp.snippets["begone"] })
    drain()
    return RAN == 4 and DELETES == 0 and #KEYSTROKES == 0
  end)(), RAN)

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.execute("rm -rf '" .. TMP .. "'")
os.exit(fail == 0 and 0 or 1)
