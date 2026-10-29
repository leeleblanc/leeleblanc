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
local DEGRADED = {}
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
    -- Deliberately NOT a full JSON parser FOR THE ALFRED PATH: that half
    -- only has to read what Alfred writes, and every field it reads is
    -- asserted below against a file this suite wrote from the real
    -- format.
    --
    -- 🚨 6.359.0 — AND IT HAD TO GROW A REAL ONE FOR EVERYTHING ELSE.
    -- The recent queue is the first thing in this module to round-trip a
    -- store of its OWN shape through hs.json, and against the Alfred-only
    -- stub `encode({recent=…})` produced nonsense and `decode` handed back
    -- `{}` — so the save/load pair would have "passed" while writing a
    -- file no Mac could read. That is 6.69.0's failure exactly: a stub
    -- more forgiving (or less) than the API it stands in for ratifies my
    -- idea of the API instead of testing the code.
    --
    -- 📏 TWO FIDELITIES THAT MATTER HERE, both taken from the extension's
    -- own behaviour rather than from memory:
    --   · hs.json.decode RAISES on input that is not JSON — it does not
    --     return nil — which is why text_expander pcalls it, and why the
    --     "unreadable" state exists at all. This errors too.
    --   · an empty Lua table encodes as `{}`, not `[]`, so a store saved
    --     with nothing in it reads back as an empty OBJECT. The module
    --     must survive that, and it does: ipairs over it yields nothing.
    decode = function(s)
      local obj = {}
      local inner = s:match('"alfredsnippet"%s*:%s*(%b{})')
      if not inner then
        -- ---- a real, small JSON reader --------------------------------
        local i = 1
        local function skip()
          while true do
            local c = s:sub(i, i)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then i = i + 1
            else return end
          end
        end
        local value
        local function str()
          i = i + 1                      -- past the opening quote
          local b = {}
          while true do
            local c = s:sub(i, i)
            if c == "" then error("unterminated string in JSON") end
            if c == '"' then i = i + 1; return table.concat(b) end
            if c == "\\" then
              local e = s:sub(i + 1, i + 1)
              local m = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f",
                          ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
              if m[e] then b[#b + 1] = m[e]; i = i + 2
              elseif e == "u" then
                b[#b + 1] = utf8.char(tonumber(s:sub(i + 2, i + 5), 16) or 63)
                i = i + 6
              else error("bad escape in JSON") end
            else b[#b + 1] = c; i = i + 1 end
          end
        end
        function value()
          skip()
          local c = s:sub(i, i)
          if c == "" then error("JSON ended early") end
          if c == '"' then return str() end
          if c == "{" then
            i = i + 1
            local t = {}
            skip()
            if s:sub(i, i) == "}" then i = i + 1; return t end
            while true do
              skip()
              if s:sub(i, i) ~= '"' then error("object key is not a string") end
              local k = str()
              skip()
              if s:sub(i, i) ~= ":" then error("object key with no colon") end
              i = i + 1
              t[k] = value()
              skip()
              local d = s:sub(i, i)
              i = i + 1
              if d == "}" then return t end
              if d ~= "," then error("bad object in JSON") end
            end
          end
          if c == "[" then
            i = i + 1
            local t = {}
            skip()
            if s:sub(i, i) == "]" then i = i + 1; return t end
            while true do
              t[#t + 1] = value()
              skip()
              local d = s:sub(i, i)
              i = i + 1
              if d == "]" then return t end
              if d ~= "," then error("bad array in JSON") end
            end
          end
          if s:sub(i, i + 3) == "true"  then i = i + 4; return true  end
          if s:sub(i, i + 4) == "false" then i = i + 5; return false end
          if s:sub(i, i + 3) == "null"  then i = i + 4; return nil   end
          local n = s:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
          if n and n ~= "" then i = i + #n; return tonumber(n) end
          error("unreadable JSON at byte " .. i)
        end
        local v = value()
        skip()
        if i <= #s then error("trailing bytes after the JSON value") end
        return v
      end
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
      if type(t) == "table" and t.alfredsnippet == nil then
        -- ---- a real, small JSON writer --------------------------------
        local function enc(v)
          local ty = type(v)
          if ty == "number"  then return tostring(v) end
          if ty == "boolean" then return tostring(v) end
          if ty == "string"  then
            return '"' .. v:gsub('[%c"\\]', function(c)
              local m = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n",
                          ["\r"] = "\\r", ["\t"] = "\\t" }
              return m[c] or string.format("\\u%04x", c:byte())
            end) .. '"'
          end
          if ty ~= "table" then error("cannot encode a " .. ty) end
          if #v > 0 then
            local b = {}
            for _, x in ipairs(v) do b[#b + 1] = enc(x) end
            return "[" .. table.concat(b, ",") .. "]"
          end
          -- 🚨 AN EMPTY TABLE IS AN OBJECT, which is what hs.json does —
          -- getting this backwards would hide a store that saved nothing.
          local ks = {}
          for k in pairs(v) do ks[#ks + 1] = tostring(k) end
          table.sort(ks)
          local b = {}
          for _, k in ipairs(ks) do b[#b + 1] = enc(k) .. ":" .. enc(v[k]) end
          return "{" .. table.concat(b, ",") .. "}"
        end
        return enc(t)
      end
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
    secondsSinceEpoch = function() return 1000.4231 end,
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
    setContents = function(t) table.insert(CLIPSET, t) ; return true end,
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
      -- 6.156.0: the module filters for itself and feeds the preview pane
      function c:queryChangedCallback(f) self.qcb = f; return c end
      function c:hideCallback(f) self.hideCb = f; return c end
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
local CALLS = {}       -- 6.156.0: every core.call — the preview pane services
local CLIPWRITES, CLIPBOARD, CLIPREFUSE = {}, nil, false

local core = {
  logsDir = TMP,
  -- 🚨 6.359.0 — THE RECENT QUEUE'S STORE HANGS OFF core.homeDir, and a
  -- harness that left this nil wrote into the REAL
  -- ~/Library/Application Support on whatever machine ran the suite. It
  -- did, once, before this line existed. A test that touches the
  -- developer's own home is a test that passes differently on the second
  -- run.
  homeDir = TMP,
  provide = function(n, fn) PROVIDED[n] = fn end,
  call    = function(n, ...) CALLS[#CALLS + 1] = { n = n, args = { ... } }; return true end,
  hyperAddShortcut = function(mods, key, fn, src)
    table.insert(HYPER, { combo = table.concat(mods, "+") .. "+" .. key, fn = fn, src = src })
  end,
  warnWriteFailed = function() end,
  -- 🔬 6.382.0 — AND IT HAD NO `copyText` EITHER, which is 6.339.0 for
  -- the second time in this one table: a core member the real init.lua
  -- publishes and the stub does not. The module calls it UNGUARDED on
  -- purpose — nil-guarding an incomplete contract is what turned four
  -- editor buttons into a four-release silence — so the suite died here
  -- rather than failing, and the fix belongs in the stub.
  --
  -- 🚨 IT CAN REFUSE. macOS's setContents answers false and never
  -- throws, so a stub that always says yes makes the degrade path
  -- unreachable and certifies a feature that cannot report its own
  -- failure (6.290.0, both directions).
  copyText = function(t, who)
    CLIPWRITES[#CLIPWRITES + 1] = { text = t, who = who }
    if CLIPREFUSE then return false, "macOS refused the write" end
    CLIPBOARD = t
    return true
  end,
  -- 🔬 6.377.0 — THE CORE STUB HAD NO `degrade`, so the 🔔 door this
  -- module takes on a refused insert could not be exercised at all and
  -- every check about it would have passed with the door deleted.
  -- 6.278.0's hole, in a third suite — it is this project's OWN core
  -- table, which is the one nobody thinks to model (6.290.0).
  degrade = function(tool, why)
    DEGRADED[#DEGRADED + 1] = { tool = tool, why = tostring(why) }
    return false, why
  end,
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
check("binds ⇪⇧S and nothing else (6.161.0: S for Snippets; T is free)",
  #HYPER == 1 and HYPER[1].combo == "shift+s", HYPER[1] and HYPER[1].combo)
check("publishes expander.show", type(PROVIDED["expander.show"]) == "function")
check("publishes expander.reload", type(PROVIDED["expander.reload"]) == "function")
check("publishes expander.toggle", type(PROVIDED["expander.toggle"]) == "function")
check("_G.snippetsImport is reachable from the Console",
  type(_G.snippetsImport) == "function")
check("_G.snippetAdd is reachable", type(_G.snippetAdd) == "function")
check("_G.snippetsList is reachable", type(_G.snippetsList) == "function")

-- =====================================================================
out("\n=== 2. Reading Alfred's actual format ===\n")
-- 6.159.0: six from the fixture's collections, plus the three built-ins
-- the code ships (§8c) — nothing in the fixture shadows them.
check("every snippet in all three collections loaded, plus the three built in",
  exp.count == 9 and exp.builtinCount == 3, exp.count)
check("a ;-prefixed keyword survives verbatim", exp.snippets[";bd"] ~= nil,
  exp.snippets[";bd"])
check("...with its text", exp.snippets[";bd"].text == "brew doctor")
check("...and its name, for the ⇪⇧S list", exp.snippets[";bd"].name == "Brew doctor")
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
addSnippet("{sl}", "{date:DD/MM/YYYY}", "Date, slashes")
addSnippet("{da}", "{date:DD-MM-YYYY}", "Date, dashes")
addSnippet("{al}", "{date:dd MMM yyyy}", "Date, Alfred's spelling")
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

-- 📅 6.158.0 — LL: "Date in this formats: DD/MM/YYYY and DD-MM-YYYY."
reset(); typeStr("{sl}"); drain()
check("📅 {date:DD/MM/YYYY} is today with slashes — LL's first format",
  KEYSTROKES[1] == os.date("%d/%m/%Y"), KEYSTROKES[1])
reset(); typeStr("{da}"); drain()
check("📅 {date:DD-MM-YYYY} is today with dashes — the second",
  KEYSTROKES[1] == os.date("%d-%m-%Y"), KEYSTROKES[1])
reset(); typeStr("{al}"); drain()
check("📅 case does not matter and MMM is the month's short name — "
   .. "dd MMM yyyy is how Alfred spells it",
  KEYSTROKES[1] == os.date("%d %b %Y"), KEYSTROKES[1])
check("...and none of the three is reported as unknown",
  not logged("is not a placeholder this config knows"),
  table.concat(log, " | "))

reset(); typeStr("{u}"); drain()
check("🚨 AN UNKNOWN PLACEHOLDER IS INSERTED LITERALLY, NOT DROPPED — a "
   .. "snippet that quietly loses {date:yyyy} is worse than one that "
   .. "visibly contains it", KEYSTROKES[1] == "hi {unknownthing}", KEYSTROKES[1])
check("...and it is reported once", logged("is not a placeholder this config knows"))
for _, k in ipairs({ "{c}", "{p}", "{d}", "{sl}", "{da}", "{al}", "{u}" }) do
  dropSnippet(k)
end

-- 📅 The date grammar itself, pinned on a KNOWN day (Thursday 3 September
-- 2026) so each form is checked by value rather than by running os.date
-- again with the same idea of the answer.
do
  local when = os.time({ year = 2026, month = 9, day = 3, hour = 12 })
  local function fmt(p) return exp.formatDate(p, when) end
  check("DD/MM/YYYY → 03/09/2026", fmt("DD/MM/YYYY") == "03/09/2026",
    fmt("DD/MM/YYYY"))
  check("DD-MM-YYYY → 03-09-2026", fmt("DD-MM-YYYY") == "03-09-2026",
    fmt("DD-MM-YYYY"))
  check("one letter is the unpadded number: D/M/YY → 3/9/26",
    fmt("D/M/YY") == "3/9/26", fmt("D/M/YY"))
  check("YYY reads as the full year rather than refusing — the ask was "
     .. "typed DD/MM/YYY once", fmt("DD/MM/YYY") == "03/09/2026",
    fmt("DD/MM/YYY"))
  check("MMM and MMMM are the month's names",
    fmt("MMM MMMM") == os.date("%b %B", when), fmt("MMM MMMM"))
  check("DDD and DDDD are the weekday's names",
    fmt("DDD DDDD") == os.date("%a %A", when), fmt("DDD DDDD"))
  check("lower case is the same date: dd.mm.yyyy → 03.09.2026",
    fmt("dd.mm.yyyy") == "03.09.2026", fmt("dd.mm.yyyy"))
  check("every other character is kept as typed — words included, as "
     .. "long as they hold no D, M or Y",
    fmt("YYYY-MM-DD (week of DD)") == "2026-09-03 (week of 03)",
    fmt("YYYY-MM-DD (week of DD)"))
  check("a run longer than four is the four-letter form, not an error",
    fmt("MMMMMM") == os.date("%B", when), fmt("MMMMMM"))
  check("{date} alone is STILL ISO — no snippet written before 6.158.0 "
     .. "changes", exp.substitute("{date}") == os.date("%Y-%m-%d"),
    exp.substitute("{date}"))
  local seen = {}
  local kept = exp.substitute("{date:}", seen)
  check("🚨 an EMPTY {date:} is an unknown like any other — kept as typed "
     .. "and reported, never silently dropped",
    kept == "{date:}" and seen["date:"] == true, kept)
  check("...and the report now lists the new form among the supported",
    logged("{date:DD/MM/YYYY}"), table.concat(log, " | "))
end

-- =====================================================================
out("\n=== 8c. 📌 6.159.0 — built-in snippets, in the build, under yours ===\n")
-- =====================================================================
-- LL: "create all three in this build." So a fresh install has them with
-- no Console line and no packs — and anything of yours with the same
-- trigger wins, because a built-in is a suggestion, not a claim.
check("three ship in the code", type(exp.builtin) == "table" and #exp.builtin == 3,
  #(exp.builtin or {}))
check("...and all three loaded", exp.builtinCount == 3
  and exp.snippets[";d/"] ~= nil and exp.snippets[";d-"] ~= nil
  and exp.snippets[";mp3"] ~= nil, exp.builtinCount)
check("...under their own ⇪⇧S heading, ranked with the shipped packs, not "
   .. "above your own", (function()
    local sec, rank = exp.sectionOf(exp.snippets[";d/"])
    return sec == "built in" and rank == exp.rankShipped, sec .. "/" .. tostring(rank)
  end)())
reset(); typeStr(";d/"); drain()
check("📅 ;d/ types today with slashes", KEYSTROKES[1] == os.date("%d/%m/%Y"),
  KEYSTROKES[1])
reset(); typeStr(";d-"); drain()
check("📅 ;d- types today with dashes", KEYSTROKES[1] == os.date("%d-%m-%Y"),
  KEYSTROKES[1])
reset(); typeStr(";mp3"); drain()
check("🎬 ;mp3 types the yt-dlp command with the clipboard quoted in",
  KEYSTROKES[1] == 'yt-dlp -x --audio-format mp3 "clipboard contents"',
  KEYSTROKES[1])
-- yours wins — through a REAL file and a real load, the way it happens
mkdirp(TMP .. "/snippets/Mine")
snippetFile(TMP .. "/snippets/Mine", "dslash.json", "Mine wins", ";d/", "my own date")
log = {}
exp.load()
check("🚨 a snippet of YOURS with the same trigger wins over the built-in",
  exp.snippets[";d/"] and exp.snippets[";d/"].text == "my own date"
  and exp.snippets[";d/"].source ~= "built in",
  exp.snippets[";d/"] and exp.snippets[";d/"].source)
check("...the shadowed one is not counted as loaded",
  exp.builtinCount == 2 and exp.builtinShadowed[1] == ";d/", exp.builtinCount)
check("...the Console says which built-in stood aside, and for whom",
  logged("built-in ;d/ stands aside") and logged("Mine wins"),
  table.concat(log, " | "))
check("...and that is a line, not a problem — nothing is reported as failing "
   .. "to load", #(exp.problems or {}) == 0, table.concat(exp.problems or {}, " | "))
os.remove(TMP .. "/snippets/Mine/dslash.json")
exp.load()
check("...and it comes back the moment yours is gone",
  exp.snippets[";d/"] and exp.snippets[";d/"].source == "built in"
  and exp.builtinCount == 3, exp.snippets[";d/"] and exp.snippets[";d/"].source)

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
   .. "is insertable from ⇪⇧S", not logged("nokw.json"))
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
out("\n=== 11. ⇪⇧S, the chooser ===\n")
CHOOSERS = {}
exp.show()
local ch = CHOOSERS[#CHOOSERS]
check("the chooser opens", ch and ch.shown == true)
-- 🗂 6.118.0 — the list is SECTIONED, so the row count is snippets +
-- the on/off row + one heading per collection. Counted from the rows
-- rather than from a number written here: a hard-coded total would have
-- to be edited every time this fixture grows a collection, and the day
-- somebody edits it to make the suite pass is the day it stops checking.
local function headings(c)
  local n = 0
  for _, r in ipairs((c and c.rows_) or {}) do
    if r.header then n = n + 1 end
  end
  return n
end
check("...listing every snippet, the on/off row, and one heading per section",
  ch and #ch.rows_ == exp.count + #(exp.chooserOnly or {}) + 1 + headings(ch),
  ch and (#ch.rows_ .. " rows, " .. headings(ch) .. " headings"))
check("...with the toggle FIRST, where it can always be found",
  ch.rows_[1].toggle == true, ch.rows_[1].text)
check("🗂 every snippet sits under the heading for its own collection",
  (function()
    local under, seen = nil, 0
    for i = 2, #ch.rows_ do
      local r = ch.rows_[i]
      if r.header then
        under = r.text
      else
        seen = seen + 1
        if not under then return false, "row " .. i .. " has no heading above it" end
        -- The heading is the section name upper-cased; if that ever
        -- stops being true this check must fail rather than be relaxed.
        if not under:find(tostring(r.sect):upper(), 1, true) then
          return false, r.text .. " is under " .. under
        end
      end
    end
    return seen > 0
  end)())
check("...and A–Z runs INSIDE a section, not across the whole list",
  (function()
    local prev
    for i = 2, #ch.rows_ do
      local r = ch.rows_[i]
      if r.header then prev = nil
      else
        -- 6.161.0: rows sort by the name AS WRITTEN (fullName); the shown
        -- text may have lost a leading glyph to the icon
        local key = r.fullName or r.text
        if prev and key < prev then return false, prev .. " then " .. key end
        prev = key
      end
    end
    return true
  end)())
check("🚨 a heading NEVER INSERTS — picking one types nothing at all",
  (function()
    reset()
    for _, r in ipairs(ch.rows_) do
      if r.header then ch.cb(r) end
    end
    drain()
    return #KEYSTROKES == 0 and DELETES == 0
  end)(), KEYSTROKES[1])

-- =====================================================================
out("\n=== 11b. 6.156.0 — what is in it, beside it: the pane and the narrowed view ===\n")
-- LL: "To the right of the snippets panel can you show what is in the
-- snippet collection? If I select one, nothing seems to happen. I can't
-- remember what is in the collection if I can't see it."
CHOOSERS, CALLS = {}, {}
exp.show()
ch = CHOOSERS[#CHOOSERS]
check("opening the picker asks for the preview pane, handing it THIS chooser "
   .. "and the rows on screen", (function()
  for _, c in ipairs(CALLS) do
    if c.n == "preview.open" and c.args[1] == ch and type(c.args[2]) == "function"
       and c.args[2]() == exp.lastChoices then return true end
  end
  return false
end)())
check("every snippet row carries its WHOLE text for the pane, and a head line "
   .. "naming trigger and collection", (function()
  for _, r in ipairs(ch.rows_) do
    if r.trigger == "gg1" then
      return type(r.rawText) == "string" and #r.rawText > 0
         and type(r.head) == "string" and r.head:find("gg1", 1, true) ~= nil
         and r.head:find(tostring(r.sect), 1, true) ~= nil
    end
  end
end)())
local heading
for _, r in ipairs(ch.rows_) do if r.header then heading = r; break end end
check("a collection heading lists what is IN it — trigger and name per line",
      heading and type(heading.rawText) == "string"
      and heading.rawText:find("\n", 1, true) ~= nil
      and heading.head:find("snippets", 1, true) ~= nil, heading and heading.head)
check("...every snippet of that collection is on the list", (function()
  local n = 0
  for _, r in ipairs(ch.rows_) do
    if not r.header and not r.toggle and r.sect == heading.sect then
      n = n + 1
      if not heading.rawText:find(r.text, 1, true) then return false, r.text end
    end
  end
  return n > 0 and select(2, heading.rawText:gsub("\n", "")) + 1 == n
end)())
check("the on/off row previews nothing", ch.rows_[1].toggle and ch.rows_[1].rawText == nil)
check("the picker hides → the pane is suspended (waits out a nudge)", (function()
  if not ch.hideCb then return false end
  ch.hideCb()
  return CALLS[#CALLS].n == "preview.suspend"
end)())

-- typing: our own filter, so the rows on screen are the rows the pane reads
local before = #ch.rows_
ch.qcb("gg1")
check("typing filters HERE — name or trigger hits first — and the rows on "
   .. "screen are what the pane reads",
      #ch.rows_ < before and ch.rows_[1].trigger == "gg1" and exp.lastChoices == ch.rows_,
      ch.rows_[1] and ch.rows_[1].trigger)
check("...headings and the on/off row step aside while a query is up", (function()
  for _, r in ipairs(ch.rows_) do if r.header or r.toggle then return false end end
  return true
end)())
ch.qcb("")
check("...and an empty box brings the whole sectioned list back",
      #ch.rows_ == before and ch.rows_[1].toggle == true)
check("the BODY is searchable now — a word only inside a snippet's text finds it", (function()
  local target
  for _, r in ipairs(ch.rows_) do
    if r.rawText and #r.rawText > 12 and not r.header then target = r; break end
  end
  if not target then return true end
  local word = target.rawText:match("%a%a%a%a+")
  if not word then return true end
  ch.qcb(word)
  for _, r in ipairs(ch.rows_) do if r == target then return true end end
  return false
end)())
ch.qcb("")

-- ⏎ on a heading: the picker re-opens on that collection alone
CHOOSERS = {}
ch.cb(heading)
check("⏎ on a heading queues a re-open a beat later, not inside the callback",
      #CHOOSERS == 0)
drain()
local narrow = CHOOSERS[#CHOOSERS]
check("...and the picker re-opens showing ONLY that collection",
      narrow and narrow.shown and (function()
        local seen = 0
        for _, r in ipairs(narrow.rows_) do
          if not (r.header or r.back) then
            seen = seen + 1
            if r.sect ~= heading.sect then return false end
          end
        end
        return seen > 0
      end)())
check("...with a way back on top instead of the on/off row",
      narrow.rows_[1].back == true and narrow.rows_[1].text:find("All snippets", 1, true) ~= nil)
check("...and the placeholder names the collection",
      tostring(narrow.ph):find(tostring(heading.sect):upper(), 1, true) ~= nil, narrow.ph)
CHOOSERS = {}
narrow.cb(narrow.rows_[1])
drain()
check("◂ All snippets brings the full list back",
      CHOOSERS[#CHOOSERS] and CHOOSERS[#CHOOSERS].rows_[1].toggle == true)
ch = CHOOSERS[#CHOOSERS]
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
check("all 2,006 triggers loaded from five collections (and the three built in)",
  exp.count == 2006 + 3, exp.count)
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
out("\n=== 17b. 📦 THE BUNDLED TABLE — 2,006 files folded into one ===\n")
-- 6.105.0 ships snippets/bundled.lua instead of the packs. These files
-- are REAL and loaded with the REAL loadfile, for the same reason §15's
-- corpus is real: a stubbed loader would only confirm my idea of what
-- loadfile does with an empty environment.
local BDIR = TMP .. "/bundledlua"
mkdirp(BDIR)
local function writeBundle(body)
  write(BDIR .. "/bundled.lua", body)
end
exp.dir        = TMP .. "/snippets"
exp.bundledDir = BDIR

writeBundle([[
return {
  version = 1,
  packs = { { "Mac_symbols", 2 }, { "textpanders", 1 } },
  triggers = {
    ["tbl1"] = { "from the table", "Table one", 1 },
    ["tbl2"] = { "second", "Table two", 2 },
    ["dup1"] = { "BUNDLED-TABLE", "Bundled dup", 1 },
  },
  chooserOnly = { { "no keyword here", "Keywordless", 1 } },
  collisions = { "Mac_symbols: trigger x already used by y — the later one wins" },
  problems   = { "Mac_symbols/broken.json: empty snippet" },
}
]])
exp.load()
check("a trigger from the table expands like any other",
  exp.snippets["tbl1"] and exp.snippets["tbl1"].text == "from the table",
  exp.snippets["tbl1"])
check("the pack index becomes the pack NAME, not a number",
  exp.snippets["tbl2"] and exp.snippets["tbl2"].source == "textpanders",
  exp.snippets["tbl2"] and exp.snippets["tbl2"].source)
check("...and the OneDrive folder is still read alongside it",
  exp.snippets["gg1"] ~= nil and exp.snippets[";bd"] ~= nil)
check("🚨 YOURS STILL WINS — the table cannot clobber your own snippet",
  exp.snippets["dup1"].text == "MINE", exp.snippets["dup1"].text)
check("a keyword-less entry lands in the chooser-only list",
  (function()
     for _, c in ipairs(exp.chooserOnly or {}) do
       if c.text == "no keyword here" then return c.name == "Keywordless" end
     end
   end)())
check("build-time problems are reported here, not swallowed",
  (function()
     local sawProblem, sawCollision = false, false
     for _, p in ipairs(exp.problems or {}) do
       if p:find("broken.json", 1, true)  then sawProblem   = true end
       if p:find("Mac_symbols: trigger x", 1, true) then sawCollision = true end
     end
     return sawProblem and sawCollision
   end)(), table.concat(exp.problems or {}, " | "))
check("exp.bundledFrom says which door they came through",
  exp.bundledFrom == "table" and exp.bundledCount == 3,
  tostring(exp.bundledFrom) .. "/" .. tostring(exp.bundledCount))

-- 🚨 THE POINT OF THE WHOLE DESIGN. Unzipping 6.105.0 over an older
-- install leaves 2,006 .json files next to the new table. Scanning both
-- would report every single trigger as colliding with itself.
mkdirp(BDIR .. "/Leftover")
snippetFile(BDIR .. "/Leftover", "old.json", "Stale pack copy", "tbl1", "STALE")
exp.load()
check("stale packs beside a good table are IGNORED, not scanned",
  exp.snippets["tbl1"].text == "from the table", exp.snippets["tbl1"].text)
check("...and no self-collision is reported for them",
  (function()
     for _, p in ipairs(exp.problems or {}) do
       if p:find("bundled: trigger", 1, true) then return false end
     end
     return true
   end)(), exp.problems)

-- Every way the table can be wrong falls through to the packs, which are
-- sitting right there in BDIR/Leftover.
local function fallsBack(label, body)
  writeBundle(body)
  exp.load()
  check(label .. " → falls back to reading the packs",
    exp.bundledFrom == "packs" and exp.snippets["tbl1"]
      and exp.snippets["tbl1"].text == "STALE",
    tostring(exp.bundledFrom))
  check("...and says so, rather than going quiet",
    (function()
       for _, p in ipairs(exp.problems or {}) do
         if p:find("bundled.lua:", 1, true) then return true end
       end
     end)(), exp.problems)
end
fallsBack("a syntax error",        "return { version = 1, triggers = ")
fallsBack("a file that throws",    "error('boom')")
fallsBack("not returning a table", "return 42")
fallsBack("a version from the future",
          "return { version = 99, triggers = { a = { 'x', 'y', 1 } } }")
fallsBack("no triggers table",     "return { version = 1 }")
fallsBack("triggers, but all junk",
          "return { version = 1, triggers = { [1] = 'no', b = {}, c = { '' } } }")

check("🔒 the table is DATA — it cannot reach hs, io or os",
  (function()
     -- Written WITHOUT calling anything: the environment is empty, so even
     -- tostring and type are absent, and a probe that called one would
     -- prove the point by throwing rather than by answering. A bare
     -- comparison is the only thing this file is allowed to do.
     writeBundle("return { version = 1, triggers = { z = {"
                 .. " (os == nil and io == nil and hs == nil)"
                 .. " and 'sealed' or 'open', 'x', 1 } } }")
     exp.load()
     return exp.snippets["z"] and exp.snippets["z"].text == "sealed"
   end)(), exp.snippets["z"] and exp.snippets["z"].text)

check("a bad pack index degrades to a label, never to nil",
  (function()
     writeBundle("return { version = 1, packs = { { 'One', 1 } },"
                 .. " triggers = { q = { 'text', 'Name', 77 } } }")
     exp.load()
     return exp.snippets["q"] and exp.snippets["q"].source == "bundled"
   end)(), exp.snippets["q"] and exp.snippets["q"].source)

check("no table at all is the old world, unchanged",
  (function()
     os.remove(BDIR .. "/bundled.lua")
     exp.load()
     return exp.bundledFrom == "packs" and exp.snippets["tbl1"].text == "STALE"
   end)(), tostring(exp.bundledFrom))

exp.bundledDir, exp.bundledPath, exp.bundledFrom = nil, nil, nil
exp.load()

-- =====================================================================
out("\n=== 17c. 📦 THE SHIPPED TABLE MATCHES THE SHIPPED PACKS ===\n")
-- 🚨 THE DRIFT SENTRY. snippets/bundled.lua is generated, and it can go
-- stale the moment a pack changes — nothing would say so until a trigger
-- did nothing on LL's Mac. The builder's --check mode rebuilds from the
-- packs and compares byte for byte.
--
-- The public packs are in git (packs/, 6.162.0) so a clone compares for
-- real; the shipped zip has only the table and --check reports a SKIP.
-- That is a pass here, and the line below says which of the two
-- happened rather than quietly accepting either.
check("snippets/bundled.lua is current for the packs on this machine",
  (function()
     local h = io.popen("cd '" .. HS .. "' && lua tools/build-snippets.lua . "
                        .. "--check 2>&1")
     local outp = h:read("*a") or ""
     local ok = h:close()
     if ok then
       out("      " .. (outp:gsub("%s+$", "")) .. "\n")
     else
       out("      " .. outp .. "\n")
     end
     return ok and true or false
   end)())

-- =====================================================================
out("\n=== 17d. 📦 …AND THE SENTRY KNOWS WHAT IT CANNOT CHECK (6.115.0) ===\n")
-- =====================================================================
-- 🚨 THE CHECK ABOVE REPORTED A FALSE STALE ON THE SHIPPED ZIP, which is
-- the tree LL actually installs from. The release packages
-- snippets/bundled.lua and deliberately leaves the source packs out
-- (textpanders holds real email addresses, a phone number and an
-- employee ID), so snippets/ EXISTS but is empty of packs: the builder
-- generated an empty table, compared it to the real one, and said STALE.
-- The skip branch only ever covered a missing snippets/ directory.
--
-- It survived from 6.105.0 because the suite was only ever run against
-- the repo, where the packs are present. The symptom is the worst kind
-- for a release — "❌ Do not ship this" on a tree that is correct.
--
-- ⚖️ SO THE POINT OF THIS SECTION IS THE OTHER HALF: proving the fix did
-- not blanket-disable the sentry. Real drift, on a tree that HAS packs,
-- must still fail. Everything below runs the real builder against
-- throwaway trees rather than this repo's snippets/.
do
    local function sh(cmd)
        local h = io.popen(cmd .. " 2>&1")
        local o = h:read("*a") or ""
        local ok, _, code = h:close()
        return o, (ok and 0 or (code or 1))
    end
    local TROOT = (os.getenv("TMPDIR") or "/tmp"):gsub("/$", "")
                  .. "/hs-snip-" .. tostring(os.time()) .. "-" .. tostring(math.random(9999))
    local BUILD = "lua5.4 '" .. HS .. "/tools/build-snippets.lua'"
    os.execute("mkdir -p '" .. TROOT .. "/snippets/Pack'")

    local pk = io.open(TROOT .. "/snippets/Pack/one.json", "w")
    if pk then
        -- Alfred's shape: the builder reads obj.alfredsnippet, and a
        -- fixture in any other shape yields an empty table that matches
        -- the empty table --check builds — which passes for the wrong
        -- reason and proves nothing.
        pk:write('{"alfredsnippet":{"snippet":"hello there",'
                 .. '"keyword":"hhh","name":"greeting"}}')
        pk:close()
    end

    local _, buildCode = sh(BUILD .. " '" .. TROOT .. "'")
    check("the builder makes a table from a pack", buildCode == 0
          and io.open(TROOT .. "/snippets/bundled.lua", "r") ~= nil)

    local o, c = sh(BUILD .. " '" .. TROOT .. "' --check")
    check("…and --check calls it current", c == 0 and o:find("current", 1, true) ~= nil, o)

    -- 🚨 REAL DRIFT, ON A TREE THAT HAS PACKS. This is the case the sentry
    -- exists for, and the one the skip must never swallow.
    local pk2 = io.open(TROOT .. "/snippets/Pack/one.json", "w")
    if pk2 then
        pk2:write('{"alfredsnippet":{"snippet":"changed underneath it",'
                  .. '"keyword":"hhh","name":"greeting"}}')
        pk2:close()
    end
    o, c = sh(BUILD .. " '" .. TROOT .. "' --check")
    check("🚨 a pack edited after the build still reports STALE — the "
          .. "skip added in 6.115.0 must not cover the one case drift can "
          .. "actually happen in", c ~= 0 and o:find("STALE", 1, true) ~= nil, o)

    -- The shipped-zip shape: the table, and no packs beside it.
    os.execute("rm -rf '" .. TROOT .. "/snippets/Pack'")
    o, c = sh(BUILD .. " '" .. TROOT .. "' --check")
    check("🚨 the table WITHOUT its packs is a skip, not a failure — this "
          .. "is the shipped zip, and it was reporting STALE", c == 0, o)
    check("…and it says so in words, rather than passing silently",
          o:find("no source packs", 1, true) ~= nil, o)

    -- The older skip: no snippets/ at all, as in a fresh clone.
    os.execute("rm -rf '" .. TROOT .. "/snippets'")
    o, c = sh(BUILD .. " '" .. TROOT .. "' --check")
    check("a fresh clone with no snippets/ at all is still a skip", c == 0, o)

    -- 🚨 AND ASKED TO BUILD, NOTHING IS STILL AN ERROR. A skip is about
    -- having nothing to COMPARE; generating an empty table over a good
    -- one is a different act, and it must keep failing loudly.
    o, c = sh(BUILD .. " '" .. TROOT .. "'")
    check("🚨 building from nothing is still a hard error — a skip must "
          .. "never become permission to write an empty table", c ~= 0, o)

    os.execute("rm -rf '" .. TROOT .. "'")
end

-- =====================================================================
out("\n=== 17e. 📦 packs/ IS A SOURCE, AND A PRIVATE snippets/ EXTRA WINS (6.162.0) ===\n")
-- =====================================================================
-- 🚨 6.161.0 SHIPPED WITH NO SNIPPETS because the packs lived only in a
-- gitignored folder that every container rebuild erased. The public
-- packs are committed under packs/ now, and the builder reads THAT
-- first, then snippets/ (where private extras may still sit) — the
-- later one winning a shared trigger, exactly as scanDir does. A fresh
-- clone therefore has packs/ and no snippets/, and BUILDING must create
-- the output folder rather than fail on it.
do
    local function sh(cmd)
        local h = io.popen(cmd .. " 2>&1")
        local o = h:read("*a") or ""
        local ok, _, code = h:close()
        return o, (ok and 0 or (code or 1))
    end
    local TROOT = (os.getenv("TMPDIR") or "/tmp"):gsub("/$", "")
                  .. "/hs-packs-" .. tostring(os.time()) .. "-" .. tostring(math.random(9999))
    local BUILD = "lua5.4 '" .. HS .. "/tools/build-snippets.lua'"
    os.execute("mkdir -p '" .. TROOT .. "/packs/Public'")
    local function put(path, keyword, text)
        local f = io.open(path, "w")
        if f then
            f:write('{"alfredsnippet":{"snippet":"' .. text .. '","keyword":"'
                    .. keyword .. '","name":"n"}}')
            f:close()
        end
    end
    put(TROOT .. "/packs/Public/a.json", "ppp", "from packs")
    put(TROOT .. "/packs/Public/b.json", "qqq", "only in packs")

    local o, c = sh(BUILD .. " '" .. TROOT .. "' --check")
    check("--check on a clone whose table was never built is a SKIP that "
          .. "says so, not STALE — nothing has drifted yet",
          c == 0 and o:find("not built yet", 1, true) ~= nil, o)

    o, c = sh(BUILD .. " '" .. TROOT .. "'")
    local tbl = io.open(TROOT .. "/snippets/bundled.lua", "r")
    check("a fresh clone — packs/ present, no snippets/ — BUILDS, creating "
          .. "snippets/ for the output", c == 0 and tbl ~= nil, o)
    local body = tbl and tbl:read("*a") or ""
    if tbl then tbl:close() end
    check("…and the table holds the public pack under its folder's name",
          body:find('"Public"', 1, true) ~= nil
          and body:find("only in packs", 1, true) ~= nil, body:sub(1, 400))
    o, c = sh(BUILD .. " '" .. TROOT .. "' --check")
    check("…and --check on that clone compares for real, not a skip",
          c == 0 and o:find("current", 1, true) ~= nil, o)

    -- A private pack left in snippets/ folds in too, and wins a collision.
    os.execute("mkdir -p '" .. TROOT .. "/snippets/Private'")
    put(TROOT .. "/snippets/Private/a.json", "ppp", "from snippets")
    o, c = sh(BUILD .. " '" .. TROOT .. "' --check")
    check("a pack added under snippets/ makes the table STALE",
          c ~= 0 and o:find("STALE", 1, true) ~= nil, o)
    o, c = sh(BUILD .. " '" .. TROOT .. "'")
    tbl = io.open(TROOT .. "/snippets/bundled.lua", "r")
    body = tbl and tbl:read("*a") or ""
    if tbl then tbl:close() end
    check("🔒 on a shared trigger the snippets/ (private) copy wins — "
          .. "later scan, same rule as scanDir",
          body:find("from snippets", 1, true) ~= nil
          and body:find("from packs", 1, true) == nil, body:sub(1, 600))
    check("…and both collections are named in the table",
          body:find('"Public"', 1, true) ~= nil
          and body:find('"Private"', 1, true) ~= nil)
    check("…and the collision is recorded, never silent",
          body:find("already used by", 1, true) ~= nil)

    -- 🚨 An EMPTY source directory must never clobber a good table.
    os.execute("rm -rf '" .. TROOT .. "/packs' '" .. TROOT .. "/snippets/Private'"
               .. " && mkdir -p '" .. TROOT .. "/packs'")
    o, c = sh(BUILD .. " '" .. TROOT .. "'")
    local kept = io.open(TROOT .. "/snippets/bundled.lua", "r")
    local keptBody = kept and kept:read("*a") or ""
    if kept then kept:close() end
    check("🚨 building from a packs/ that holds no .json refuses, and the "
          .. "old table is untouched", c ~= 0 and o:find("refusing", 1, true) ~= nil
          and keptBody == body, o)

    os.execute("rm -rf '" .. TROOT .. "'")
end

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

check("the ⇪⇧S chooser lists it without touching .text",
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
    -- Hand back the row VERBATIM, exactly as the real chooser would. A
    -- hand-built row would pass even if show() stopped emitting the field
    -- the callback looks up.
    local row
    for _, r in ipairs(c.rows_ or {}) do
      if r.trigger == "begone" then row = r end
    end
    if not row then return false end
    c.cb(row)
    drain()
    return RAN == 4 and DELETES == 0 and #KEYSTROKES == 0
  end)(), RAN)

-- 🚨 6.109.0 REGRESSION GUARD. Every value in a chooser row is converted to
-- an NSObject. Functions and nested tables cannot be, and LuaSkin does not
-- throw — it logs and discards THE ENTIRE LIST, so ⇪⇧S opens empty and the
-- keyboard gives no sign. This is the check that catches it in the repo
-- instead of in the Console.
check("🚨 every ⇪⇧S row survives the Objective-C bridge (image is the one "
   .. "object a row may carry — hs.chooser's own key for an hs.image)",
  (function()
    exp.show()
    local rows = CHOOSERS[#CHOOSERS].rows_ or {}
    if #rows == 0 then return false end
    for _, row in ipairs(rows) do
      for k, v in pairs(row) do
        local t = type(v)
        if k == "image" then
          if t ~= "userdata" and t ~= "table" then
            return false, ("row image is a %s"):format(t)
          end
        elseif t ~= "string" and t ~= "number" and t ~= "boolean" then
          return false, ("row field %s is a %s"):format(tostring(k), t)
        end
      end
    end
    return true
  end)())

check("...and the pick index still resolves to a real snippet",
  (function()
    exp.show()
    local rows, seen, heads = CHOOSERS[#CHOOSERS].rows_ or {}, 0, 0
    for _, row in ipairs(rows) do
      if row.pick then seen = seen + 1 end
      if row.header then heads = heads + 1 end
    end
    -- Every row but the ON/OFF toggle and the section headings carries
    -- one. A heading that grew a `pick` would be a divider that inserts
    -- text into a document, which is why the two are counted separately
    -- rather than the total being loosened to >=.
    return seen == #rows - 1 - heads and seen > 0
  end)())

-- =====================================================================
out("\n=== 20. 🗂 THE ⇪⇧S SECTIONS, IN ORDER (6.118.0) ===\n")
-- LL: "Can you separate the snippets into sections with my textpanders
-- first?" Four ranks, and this is the section that holds them apart:
-- a pinned collection, then yours-by-construction, then the shipped
-- packs A–Z, then the ⚡ actions. Everything below is built from the
-- REAL loader — a hand-made exp.snippets would only be my idea of what
-- load() produces, which is the mistake §2's fixture exists to avoid.
do
  local SDIR = TMP .. "/sections"
  mkdirp(SDIR)
  write(SDIR .. "/bundled.lua", [[
return {
  version = 1,
  packs = { { "Emoji_Pack", 1 }, { "textpanders", 1 }, { "ComposeKey", 1 },
            { "🧪 Lab", 1 } },
  triggers = {
    [":joy:"] = { "😂", "Joy", 1 },
    ["eml2"]  = { "work@example.com", "Work email", 2 },
    ["cmp1"]  = { "ä", "a umlaut", 3 },
    ["lab1"]  = { "specimen", "Lab one", 4 },
  },
}
]])
  -- 🚨 THAT LAST PACK IS THE WHOLE REASON THIS FIXTURE IS NOT SIMPLER,
  -- and it was added because the check below PASSED AGAINST BROKEN CODE.
  -- Rank the ⚡ actions as an ordinary shipped pack — the exact bug the
  -- check exists to catch — and they still came out last, because "⚡"
  -- is 0xE2… in UTF-8 and sorts after every ASCII pack name there is.
  -- The check was reading a lucky byte and calling it an ordering. "🧪"
  -- is 0xF0…, so it sorts AFTER the actions heading and the position is
  -- decided by the rank again, which is the thing being tested.
  exp.bundledDir = SDIR
  exp.load()
  exp.show()
  local c = CHOOSERS[#CHOOSERS]
  local order = {}
  for _, r in ipairs(c.rows_ or {}) do
    if r.header then order[#order + 1] = r.text end
  end

  -- 🕘 6.359.0 — the recent queue sits ABOVE the pinned collection, so
  -- "first" is now "first of the library's own collections". The rank
  -- this check exists to prove is unchanged: textpanders still beats
  -- every pack that sorts before it alphabetically.
  local libOrder = {}
  for _, t in ipairs(order) do
    if not t:find("RECENT", 1, true) then libOrder[#libOrder + 1] = t end
  end
  check("the pinned collection is the first of the LIBRARY'S sections",
    libOrder[1] and libOrder[1]:find("TEXTPANDERS", 1, true) ~= nil,
    table.concat(order, " | "))
  check("🕘 …and the recent queue is above even that — rank 0 beats a pin",
    order[1] and order[1]:find("RECENT", 1, true) ~= nil,
    table.concat(order, " | "))
  check("🕘 …and the rank it carries sorts above EVERY other section's, so "
     .. "folding these rows into the main sort one day still puts them "
     .. "first (the position is structural today; the rank is the promise)",
    exp.rankRecent < 1
    and exp.rankRecent < exp.rankOwn
    and exp.rankRecent < exp.rankShipped
    and exp.rankRecent < exp.rankAction, tostring(exp.rankRecent))
  check("🚨 …ahead of packs that beat it alphabetically. ComposeKey and "
     .. "Emoji_Pack both sort before textpanders, which is exactly why "
     .. "one flat A–Z buried the eighty snippets LL wrote",
    (function()
      for i = 2, #order do
        if order[i]:find("COMPOSEKEY", 1, true)
           or order[i]:find("EMOJI_PACK", 1, true) then return true end
      end
    end)(), table.concat(order, " | "))
  check("yours-by-construction come next — the collections in exp.dir",
    (function()
      local firstShipped, lastOwn
      for i, r in ipairs(c.rows_ or {}) do
        if r.sect and r.rank == exp.rankOwn      then lastOwn = i end
        if r.sect and r.rank == exp.rankShipped
           and not firstShipped                  then firstShipped = i end
      end
      return lastOwn and firstShipped and lastOwn < firstShipped,
             tostring(lastOwn) .. " vs " .. tostring(firstShipped)
    end)())
  check("⚡ actions are LAST — a module borrowing a trigger is not a "
     .. "snippet you wrote",
    order[#order]:find("ACTIONS", 1, true) ~= nil, order[#order])
  check("every heading names its collection AND says whose it is",
    (function()
      for _, r in ipairs(c.rows_ or {}) do
        if r.header and r.text:find("TEXTPANDERS", 1, true) then
          return r.subText:find("yours", 1, true) ~= nil, r.subText
        end
      end
    end)())
  check("🔎 …and every ROW names its collection too, because a SEARCH "
     .. "reorders the panel and takes the headings with it",
    (function()
      for _, r in ipairs(c.rows_ or {}) do
        if r.trigger == "eml2" then
          return r.subText:find("textpanders", 1, true) ~= nil, r.subText
        end
      end
    end)())

  check("✏️ exp.sectionOrder is the only thing that pins one — empty it "
     .. "and textpanders falls back among the shipped packs",
    (function()
      exp.sectionOrder = {}
      exp.show()
      local o = {}
      for _, r in ipairs(CHOOSERS[#CHOOSERS].rows_ or {}) do
        if r.header then o[#o + 1] = r.text end
      end
      return o[1] and o[1]:find("TEXTPANDERS", 1, true) == nil,
             table.concat(o, " | ")
    end)())
  check("✏️ exp.sections = false goes back to one flat A–Z list, no "
     .. "headings at all",
    (function()
      exp.sections = false
      exp.show()
      local rows = CHOOSERS[#CHOOSERS].rows_ or {}
      for _, r in ipairs(rows) do
        if r.header then return false end
      end
      return #rows == exp.count + #(exp.chooserOnly or {}) + 1, #rows
    end)())
  exp.sections, exp.sectionOrder = true, { "textpanders" }
  exp.bundledDir = nil
  exp.load()
end

out("\n=== 21. 🖼 ICONS ON THE ROWS (6.161.0) — the Alfred look ===\n")
-- A stub hs.canvas that counts: the module must make ONE offscreen
-- canvas and reuse it, never show it, and turn each glyph into an image
-- exactly once.
local CANVASES, RENDERS = 0, {}
local function canvasStub()
  return {
    new = function(frame)
      CANVASES = CANVASES + 1
      local c = { frame = frame, els = {} }
      function c:appendElements(e) self.els[#self.els + 1] = e; return self end
      function c:elementAttribute(i, k, v) self.els[i][k] = v; return self end
      function c:imageFromCanvas()
        local g = self.els[1].text
        RENDERS[#RENDERS + 1] = g
        return { image = g }
      end
      function c:delete() end
      function c:show() error("an offscreen render canvas must never be shown") end
      return c
    end,
  }
end
hs.canvas = canvasStub()
local function put(trigger, text, name, extra)
  if not exp.snippets[trigger] then addSnippet(trigger, text, name) end
  local sn = exp.snippets[trigger]
  sn.text, sn.name = text, name
  for k, v in pairs(extra or {}) do sn[k] = v end
  return sn
end
local function rowFor(rows, pred)
  for _, r in ipairs(rows or {}) do if pred(r) then return r end end
  return nil
end

check("what is a glyph: an emoji, a compose symbol, a flag, an arrow",
  exp.glyphOf({ text = "💯" }) == "💯" and exp.glyphOf({ text = "§" }) == "§"
  and exp.glyphOf({ text = "🇨🇦" }) == "🇨🇦" and exp.glyphOf({ text = "→" }) == "→")
check("what is not: ASCII, whitespace, an action, empty, too long",
  exp.glyphOf({ text = "--" }) == nil and exp.glyphOf({ text = "Good morning," }) == nil
  and exp.glyphOf({ text = "💯 💯" }) == nil and exp.glyphOf({ text = "💯", fn = function() end }) == nil
  and exp.glyphOf({ text = "" }) == nil and exp.glyphOf({ text = string.rep("→", 9) }) == nil
  and exp.glyphOf("💯") == nil)
check("a word with an accent is a word, not a picture (no ASCII letter in a glyph)",
  exp.glyphOf({ text = "café" }) == nil and exp.glyphOf({ text = "naïve" }) == nil
  and exp.glyphOf({ text = "1️⃣" }) == "1️⃣")
check("the marks: ✂️ yours · ⚙️ built in · ⚡ action · 📄 shipped",
  exp.markOf({ text = "x", own = true }) == exp.iconFor.own
  and exp.markOf({ text = "x", source = exp.builtinSource }) == exp.iconFor.builtin
  and exp.markOf({ text = "x", fn = function() end }) == exp.iconFor.action
  and exp.markOf({ text = "x", source = "Mac_symbols" }) == exp.iconFor.shipped)

put(":100:", "💯", "💯 :100:", { source = "Emoji_Pack", own = nil })
put("§§", "§", "§ section sign", { source = "ComposeKey", own = nil })
put("zzdash", "--", "Two dashes", { source = "Mac_symbols", own = nil })
exp.iconCache, exp.iconStats = {}, { rendered = 0, failed = 0, slices = 0, secs = 0 }
CANVASES, RENDERS = 0, {}
check("warmIcons draws every distinct glyph and mark, inline when the clock stands still",
  exp.warmIcons() == true and exp.iconPending == 0 and exp.iconTimer == nil
  and exp.iconCache["💯"] and exp.iconCache["💯"].image == "💯"
  and exp.iconCache["§"] and exp.iconCache[exp.iconFor.own] and exp.iconCache[exp.iconFor.heading]
  and exp.iconCache["--"] == nil and exp.iconStats.slices == 1,
  exp.iconPending .. " pending, " .. exp.iconStats.rendered .. " rendered")
check("ONE canvas, reused — not one per glyph", CANVASES == 1, CANVASES)
check("🚨 the ink is set explicitly — hs.canvas would draw a § white, invisible on a light picker",
  (function()
    local el = exp.iconCanvas and exp.iconCanvas.els[1]
    return el and type(el.textColor) == "table" and el.textColor.white ~= nil
  end)())
check("a glyph is drawn once: the second ask is the cached image",
  (function()
    local n = #RENDERS
    local a = exp.renderIcon("💯")
    return a == exp.iconCache["💯"] and #RENDERS == n
  end)())

exp.show()
local rows21 = CHOOSERS[#CHOOSERS].rows_ or {}
local r100 = rowFor(rows21, function(r) return r.trigger == ":100:" end)
check("an emoji row is drawn as ITSELF, and the glyph is dropped from the front of its name",
  r100 and r100.image and r100.image.image == "💯" and r100.text == ":100:",
  r100 and (r100.text .. " / " .. tostring(r100.image and r100.image.image)))
check("…while fullName keeps the name as written, for the sort and the pane",
  r100 and r100.fullName == "💯 :100:")
check("the EMOJI_PACK heading's pane lists the 💯, not the alias twice",
  (function()
    local h = rowFor(rows21, function(r) return r.header and r.sect == "Emoji_Pack" end)
    return h and h.rawText:find("💯 :100:", 1, true) ~= nil, h and h.rawText:sub(1, 80)
  end)())
check("the pause row's mark moved into the icon cell — the text no longer starts with it",
  rows21[1].toggle and rows21[1].text:sub(1, 4) == "Turn", rows21[1].text)
check("…its subText still names the trigger and the pack",
  r100 and r100.subText:find(":100:", 1, true) and r100.subText:find("Emoji_Pack", 1, true) ~= nil)
local rsec = rowFor(rows21, function(r) return r.trigger == "§§" end)
check("a compose row the same: § beside \"section sign\"",
  rsec and rsec.image.image == "§" and rsec.text == "section sign", rsec and rsec.text)
local rdash = rowFor(rows21, function(r) return r.trigger == "zzdash" end)
check("plain ASCII is text, not a picture: 📄, name untouched",
  rdash and rdash.image.image == exp.iconFor.shipped and rdash.text == "Two dashes")
local rgg = rowFor(rows21, function(r) return r.trigger == "gg1" end)
check("your own snippet wears ✂️", rgg and rgg.image and rgg.image.image == exp.iconFor.own,
  rgg and tostring(rgg.image and rgg.image.image))
local rbi = rowFor(rows21, function(r) return r.trigger == ";d/" end)
check("a built-in wears ⚙️", rbi and rbi.image and rbi.image.image == exp.iconFor.builtin,
  rbi and tostring(rbi.image and rbi.image.image))
check("every heading wears 🗂 and the pause row ⏸",
  (function()
    if not (rows21[1].toggle and rows21[1].image and rows21[1].image.image == exp.iconFor.toggleOn) then
      return false, "toggle row"
    end
    local n = 0
    for _, r in ipairs(rows21) do
      if r.header then
        n = n + 1
        if not (r.image and r.image.image == exp.iconFor.heading) then return false, r.text end
      end
    end
    return n > 0
  end)())
check("🚨 every row still crosses the bridge: scalars, plus the one image",
  (function()
    for _, row in ipairs(rows21) do
      for k, v in pairs(row) do
        local t = type(v)
        if k == "image" then
          if t ~= "table" then return false, k end
        elseif t ~= "string" and t ~= "number" and t ~= "boolean" then
          return false, k .. " is a " .. t
        end
      end
    end
    return true
  end)())
exp.enabled = false
exp.show()
check("expansion off: the row says ▶️", (CHOOSERS[#CHOOSERS].rows_ or {})[1].image.image == exp.iconFor.toggleOff)
exp.enabled = true
exp.show("Emoji_Pack")
check("a narrowed view: the way back wears ↩️, and its text dropped the ◂",
  (CHOOSERS[#CHOOSERS].rows_ or {})[1].back == true
  and (CHOOSERS[#CHOOSERS].rows_ or {})[1].image.image == exp.iconFor.back
  and (CHOOSERS[#CHOOSERS].rows_ or {})[1].text == "All snippets")
check("a picked emoji row still inserts the emoji (the pick index is untouched)",
  (function()
    KEYSTROKES = {}
    local ch = CHOOSERS[#CHOOSERS]      -- the narrowed view: its own picks
    ch.cb(rowFor(ch.rows_, function(r) return r.trigger == ":100:" end))
    drain()
    return KEYSTROKES[#KEYSTROKES] == "💯", KEYSTROKES[#KEYSTROKES]
  end)())

out("\n--- the pre-render is SLICED: a clock that moves parks a continuation ---\n")
local NOW21 = 5000
local stillClock = hs.timer.secondsSinceEpoch
hs.timer.secondsSinceEpoch = function() NOW21 = NOW21 + 0.0001; return NOW21 end
exp.iconCache, exp.iconStats = {}, { rendered = 0, failed = 0, slices = 0, secs = 0 }
exp.iconBudget = 0.00005
PENDING = {}
exp.warmIcons()
check("🚨 the first slice stops at the budget and PARKS a held doAfter(0) — it does not run on",
  exp.iconPending > 0 and #PENDING == 1 and PENDING[1].delay == 0 and exp.iconTimer == PENDING[1],
  exp.iconPending .. " pending, " .. #PENDING .. " timers")
do
  local rounds = 0
  while #PENDING > 0 and rounds < 500 do
    rounds = rounds + 1
    local b = PENDING; PENDING = {}
    for _, t in ipairs(b) do if t.running then t.fn() end end
  end
  check("…and the continuations finish the set: nothing pending, the timer let go, many slices",
    exp.iconPending == 0 and exp.iconTimer == nil and exp.iconStats.slices > 1
    and exp.iconCache["💯"] and exp.iconCache[exp.iconFor.own] ~= nil,
    exp.iconPending .. " pending after " .. rounds .. " rounds, " .. exp.iconStats.slices .. " slices")
end
check("a second warm with everything drawn is a no-op", exp.warmIcons() == true and exp.iconPending == 0)
exp.iconBudget = 0.04

out("\n--- an open has a budget of its own ---\n")
put("zznew", "🆕", "🆕 :new:", { source = "Emoji_Pack", own = nil })
exp.iconShowBudget = 0
exp.show()
local rnew = rowFor(CHOOSERS[#CHOOSERS].rows_ or {}, function(r) return r.trigger == "zznew" end)
local rold = rowFor(CHOOSERS[#CHOOSERS].rows_ or {}, function(r) return r.trigger == ":100:" end)
check("past the show budget an undrawn glyph opens WITHOUT an icon — no wait — while drawn ones keep theirs",
  rnew and rnew.image == nil and rold and rold.image and rold.image.image == "💯",
  tostring(rnew and rnew.image))
check("…and the name KEEPS its glyph when there is no icon to stand in for it",
  rnew and rnew.text == "🆕 :new:", rnew and rnew.text)
exp.iconShowBudget = 0.05
exp.show()
rnew = rowFor(CHOOSERS[#CHOOSERS].rows_ or {}, function(r) return r.trigger == "zznew" end)
check("with budget again the next open draws it", rnew and rnew.image and rnew.image.image == "🆕")
hs.timer.secondsSinceEpoch = stillClock

out("\n--- without hs.canvas, or with icons off, the rows are the plain 6.160.x rows ---\n")
hs.canvas = nil
exp.iconCanvas = nil      -- as on a Mac where the first canvas never came
exp.iconCache, exp.iconStats = {}, { rendered = 0, failed = 0, slices = 0, secs = 0 }
check("no hs.canvas: warm does not throw, every glyph is marked as undrawable once",
  (function()
    local ok = pcall(exp.warmIcons)
    return ok and exp.iconStats.failed > 0 and exp.iconCache["💯"] == false
  end)())
exp.show()
check("…and the picker still opens, rows without pictures, names whole",
  (function()
    local ch = CHOOSERS[#CHOOSERS]
    local r = rowFor(ch.rows_ or {}, function(r) return r.trigger == ":100:" end)
    return ch.shown and r and r.image == nil and r.text == "💯 :100:", r and r.text
  end)())
hs.canvas = canvasStub()
exp.iconCache = {}
exp.icons = false
exp.show()
check("exp.icons = false: no image on any row, and the glyph stays in the name",
  (function()
    local r = rowFor(CHOOSERS[#CHOOSERS].rows_ or {}, function(r) return r.trigger == ":100:" end)
    for _, row in ipairs(CHOOSERS[#CHOOSERS].rows_ or {}) do
      if row.image ~= nil then return false, row.text end
    end
    return r and r.text == "💯 :100:" and exp.warmIcons() == false, r and r.text
  end)())
exp.icons = true
exp.iconCache = {}
PROVIDED["expander.reload"]()
check("expander.reload re-warms the icons after the words", exp.iconCache[exp.iconFor.own] ~= nil
  and exp.iconCache[exp.iconFor.own] ~= false)
exp.iconCache = {}
exp.load()
check("…as does EVERY load — an import or a _G.snippetAdd draws its new pictures too",
  exp.iconCache[exp.iconFor.own] ~= nil and exp.iconCache[exp.iconFor.own] ~= false)
exp.show()
check("with no icon to carry it the pause row keeps its ⏸ in the text",
  (function()
    hs.canvas = nil; exp.iconCanvas = nil; exp.iconCache = {}
    exp.show()
    local t = (CHOOSERS[#CHOOSERS].rows_ or {})[1].text
    hs.canvas = canvasStub(); exp.iconCache = {}
    return t:sub(1, #"⏸") == "⏸", t
  end)())
check("the render canvas is never shown (source sentry)",
  (function()
    local src = io.open(HS .. "/modules/text_expander.lua"):read("a")
    return src:find("iconCanvas:show", 1, true) == nil
           and src:find("iconCanvas:elementAttribute", 1, true) ~= nil
  end)())


-- =====================================================================
-- 🕘 THE RECENT QUEUE (6.359.0)
--
-- LL, twice: "My most recently chose snippets are not at the top" ·
-- "Nothing selected moves to the top of the 'recent' as I call it,
-- queue". The grep that had to come first said `recent`, `lastUsed`,
-- `usedAt`, `mru` and `bumpTo` appeared ZERO times in the module — so
-- nothing was written and nothing went unread, and this is a BUILD.
--
-- 🚨 THE ONE RULE THE WHOLE RELEASE RESTS ON, and it is his word: a
-- snippet counts as used when it is PICKED from ⇪⇧S, never when its
-- trigger is typed. There is a behavioural check and a source sentry
-- for it below, because a day's typing would bury the handful he
-- chooses by hand and the queue would become a list of his habits.
-- =====================================================================
out("\n--- 🕘 the recent queue: the pure order ---\n")

exp.recent, exp.sections = true, true
os.remove(exp.recentFile)
exp.recentRows = {}
exp.load()

check("exp.recentKey: a snippet WITH a trigger is its trigger",
  exp.recentKey("gg1", "Greeting") == "t" .. "gg1", exp.recentKey("gg1", "Greeting"))
check("…and one WITHOUT is its name — the only handle a chooser-only snippet has",
  exp.recentKey("", "💯 :100:") == "n" .. "💯 :100:", exp.recentKey("", "💯 :100:"))
check("🔑 the two namespaces cannot collide: \"t\"..x never equals \"n\"..y",
  exp.recentKey("x", "ignored") ~= exp.recentKey("", "x"))

local function keys(list)
  local k = {}
  for _, r in ipairs(list) do k[#k + 1] = exp.recentKey(r.trigger, r.name) end
  return table.concat(k, ",")
end

check("a pick lands at the FRONT of an empty queue",
  keys(exp.noteRecent({}, { trigger = "a", name = "A" }, 100, 50)) == "ta")
check("a second pick goes above the first",
  keys(exp.noteRecent(exp.noteRecent({}, { trigger = "a", name = "A" }, 100, 50),
                      { trigger = "b", name = "B" }, 101, 50)) == "tb,ta")
check("🚨 the SAME snippet picked again MOVES — it is never listed twice "
   .. "(this is the bump, and it is the whole feature)",
  (function()
    local l = exp.noteRecent({}, { trigger = "a", name = "A" }, 100, 50)
    l = exp.noteRecent(l, { trigger = "b", name = "B" }, 101, 50)
    l = exp.noteRecent(l, { trigger = "a", name = "A" }, 102, 50)
    return keys(l) == "ta,tb", keys(l)
  end)())
check("🚨 the cap keeps the NEWEST — dropping from the front would forget "
   .. "exactly what he just picked",
  (function()
    local l = {}
    for i = 1, 6 do l = exp.noteRecent(l, { trigger = "t" .. i, name = "" }, 100 + i, 3) end
    return keys(l) == "tt6,tt5,tt4", keys(l)
  end)())
check("the cap is never below 1, whatever it is handed",
  #exp.noteRecent({ { trigger = "a" } }, { trigger = "b" }, 1, 0) == 1)
check("a row with NEITHER a trigger nor a name is dropped, not stored as a "
   .. "blank key that would swallow every other blank",
  keys(exp.noteRecent({ { trigger = "", name = "" } },
                      { trigger = "", name = "" }, 100, 50)) == "")
check("a chooser-only row survives and keys by its name",
  keys(exp.noteRecent({}, { trigger = "", name = "💯" }, 100, 50)) == "n💯")
check("the time is carried on the row that was just picked",
  exp.noteRecent({}, { trigger = "a", name = "A", at = 42 }, 100, 50)[1].at == 42)
check("…and a row with no time at all reads as 0 rather than throwing",
  exp.noteRecent({ { trigger = "b", name = "B" } },
                 { trigger = "a", name = "A" }, 100, 50)[2].at == 0)
check("nil in either place is survivable — a store that is not a list, and "
   .. "a call with nothing picked (which is how loadRecent re-caps)",
  (function()
    local ok1 = pcall(exp.noteRecent, nil, nil, 1, 5)
    local l = exp.noteRecent({ { trigger = "a" }, { trigger = "b" } }, nil, 1, 1)
    return ok1 and keys(l) == "ta", keys(l)
  end)())

out("\n--- 🕘 the store: local, bounded, and written the safe way ---\n")

exp.recentRows = exp.noteRecent({}, { trigger = "gg1", name = "Greeting" }, os.time(), exp.recentMax)
check("saveRecent writes the file", exp.saveRecent() == true
  and io.open(exp.recentFile, "r") ~= nil)
check("🔒 …and leaves no .tmp behind: the write is temp-then-rename (6.313.0)",
  io.open(exp.recentFile .. ".tmp", "r") == nil)
check("loadRecent reads it back, in order, and says so",
  (function()
    exp.recentRows = {}
    exp.loadRecent()
    return exp.recentState == "read" and keys(exp.recentRows) == "tgg1",
           exp.recentState .. " / " .. keys(exp.recentRows)
  end)())
check("🔎 no store at all is \"none\" — the ordinary state before his first "
   .. "pick, and it must not read the same as a broken one",
  (function()
    os.remove(exp.recentFile)
    exp.loadRecent()
    return exp.recentState == "none" and #exp.recentRows == 0, exp.recentState
  end)())
check("🔎 a ZERO-BYTE store is \"zero\", never \"read\" — io.open(w) truncates "
   .. "before it writes a byte, so this is the shape a crash leaves",
  (function()
    write(exp.recentFile, "")
    exp.loadRecent()
    return exp.recentState == "zero", exp.recentState
  end)())
check("🔎 JSON that is not ours is \"unreadable\", and nothing is trusted from it",
  (function()
    write(exp.recentFile, '{"queue":[1,2,3]}')
    exp.loadRecent()
    return exp.recentState == "unreadable" and #exp.recentRows == 0, exp.recentState
  end)())
check("🔎 …and so is a file that is not JSON at all",
  (function()
    write(exp.recentFile, "not json {{{")
    exp.loadRecent()
    return exp.recentState == "unreadable", exp.recentState
  end)())
check("🚨 A FAILED SAVE COSTS THE SAVE, NEVER THE THING SAVED: with the "
   .. "store pointed at a directory that does not exist the write refuses "
   .. "and the real store on disk is untouched",
  (function()
    os.remove(exp.recentFile)
    exp.recentRows = exp.noteRecent({}, { trigger = "keepme", name = "K" }, os.time(), 50)
    exp.saveRecent()
    local good = exp.recentFile
    exp.recentFile = TMP .. "/no/such/dir/recent.json"
    local refused = exp.saveRecent()
    exp.recentFile = good
    exp.recentRows = {}
    exp.loadRecent()
    return refused == false and keys(exp.recentRows) == "tkeepme", keys(exp.recentRows)
  end)())
check("🚨 …and so does a failed RENAME, which is the other half of the write "
   .. "and needs its own staging: the temp file lands, the move onto the "
   .. "store fails, and the queue in memory is still his",
  (function()
    -- a DIRECTORY where the store should be. The write to <path>.tmp
    -- succeeds and os.rename onto a non-empty directory does not, which
    -- is the only way to reach that branch without a full disk.
    local good = exp.recentFile
    local dirPath = TMP .. "/blocked.json"
    mkdirp(dirPath)
    write(dirPath .. "/occupant", "x")
    exp.recentFile = dirPath
    exp.recentRows = exp.noteRecent({}, { trigger = "survivor", name = "S" }, os.time(), 50)
    local refused = exp.saveRecent()
    local left = io.open(dirPath .. ".tmp", "r")
    if left then left:close() end
    exp.recentFile = good
    return refused == false
       and keys(exp.recentRows) == "tsurvivor"
       and left == nil, tostring(refused) .. " / " .. keys(exp.recentRows)
  end)())
check("the store is LOCAL — under Application Support, never the OneDrive "
   .. "Logs folder the shared stores live in",
  exp.recentFile:find("Application Support/Hammerspoon/snippets", 1, true) ~= nil
  and exp.recentFile:find("CloudStorage", 1, true) == nil, exp.recentFile)

out("\n--- 🕘 the picker: picked moves to the top, typed does not ---\n")

local function openPicker(section)
  exp.show(section)
  return CHOOSERS[#CHOOSERS]
end
local function rowOf(c, trigger)
  for _, r in ipairs(c.rows_ or {}) do
    if not (r.header or r.toggle or r.back) and r.trigger == trigger then return r end
  end
end
local function recentRowsOf(c)
  local got = {}
  for _, r in ipairs(c.rows_ or {}) do
    if r.recent and not r.header then got[#got + 1] = r.trigger end
  end
  return got
end
local function headingOf(c, needle)
  for i, r in ipairs(c.rows_ or {}) do
    if r.header and tostring(r.text):find(needle, 1, true) then return i, r end
  end
end

os.remove(exp.recentFile)
exp.recentRows = {}
local c = openPicker()
check("with nothing picked yet there is no 🕘 section — an empty queue draws "
   .. "no heading rather than an empty one",
  headingOf(c, "RECENT") == nil and #recentRowsOf(c) == 0)

c = openPicker()
c.cb(rowOf(c, "gg1"))
check("picking a snippet records it", keys(exp.recentRows) == "tgg1", keys(exp.recentRows))
check("…and it is written through to disk on the pick, not at quit",
  (function()
    local f = io.open(exp.recentFile, "r")
    if not f then return false end
    local raw = f:read("a") ; f:close()
    return raw:find("gg1", 1, true) ~= nil
  end)())

c = openPicker()
local hi = headingOf(c, "RECENT")
check("🕘 the section is now THERE, and it is the first heading on the list",
  hi ~= nil and (function()
    for i, r in ipairs(c.rows_) do
      if r.header then return i == hi end
    end
  end)(), tostring(hi))
check("…and the snippet he picked is the row under it",
  recentRowsOf(c)[1] == "gg1", table.concat(recentRowsOf(c), ","))

c.cb(rowOf(c, ";bd"))
c = openPicker()
check("🚨 THE MOST RECENT IS FIRST — the thing he asked for twice",
  recentRowsOf(c)[1] == ";bd" and recentRowsOf(c)[2] == "gg1",
  table.concat(recentRowsOf(c), ","))
c.cb(rowOf(c, "gg1"))
c = openPicker()
check("re-picking one already in the queue MOVES it to the top and does not "
   .. "leave a second copy behind",
  #recentRowsOf(c) == 2 and recentRowsOf(c)[1] == "gg1" and recentRowsOf(c)[2] == ";bd",
  table.concat(recentRowsOf(c), ","))

check("🚨 A TYPED TRIGGER IS NOT RECORDED — his rule, and the one the whole "
   .. "store depends on: thousands of expansions a day would bury the "
   .. "handful he picks by hand",
  (function()
    local was = keys(exp.recentRows)
    typeStr(" ;bd ")
    return keys(exp.recentRows) == was, was .. "  ->  " .. keys(exp.recentRows)
  end)())
check("🔒 …AND THERE IS EXACTLY ONE CALL TO THE RECORDER IN THE MODULE, at "
   .. "the picker's own inject. The typed path injects in three other "
   .. "places (a settled ambiguity, a trailing character, a plain "
   .. "trigger) and none of them may ever grow one — source sentry, "
   .. "because the behavioural check above can only prove the path it "
   .. "walks",
  (function()
    local src = io.open(HS .. "/modules/text_expander.lua"):read("a")
    local n = 0
    for _ in src:gmatch("exp%.noteUse%s*[,(]") do n = n + 1 end
    -- one definition + one call
    local before = src:match("(.-)\n%s*pcall%(exp%.noteUse")
    -- the window is the comment block between the two, not a guess: the
    -- check is "the recorder's nearest preceding inject is the PICKER's",
    -- and the picker's is the only one whose arguments are row.snip.
    local near = before:sub(-1200)
    return n == 2 and near:find("row.snip", 1, true) ~= nil
           and near:find("q.snip", 1, true) == nil
           and near:find("p.snip", 1, true) == nil, tostring(n)
  end)())

c = openPicker()
check("a 🕘 row carries the SAME pick as its twin in the collection, so it "
   .. "inserts the same snippet — one snippet, one place for a bug",
  (function()
    local rec, own
    for _, r in ipairs(c.rows_) do
      if not (r.header or r.toggle or r.back) and r.trigger == "gg1" then
        if r.recent then rec = r else own = r end
      end
    end
    return rec and own and rec.pick == own.pick and rec ~= own
  end)())
check("…and picking the 🕘 copy inserts the snippet, exactly as its twin does",
  (function()
    KEYSTROKES = {}
    local rec
    for _, r in ipairs(c.rows_) do
      if r.recent and not r.header and r.trigger == "gg1" then rec = r break end
    end
    c.cb(rec)
    return PASTED > 0 or #KEYSTROKES > 0
  end)())

check("the section draws at most exp.recentShow rows, however long the store is",
  (function()
    local l = {}
    for _, t in ipairs({ "gg1", ";bd", ";mp3" }) do
      l = exp.noteRecent(l, { trigger = t, name = t }, os.time(), exp.recentMax)
    end
    exp.recentRows = l
    local was = exp.recentShow
    exp.recentShow = 2
    local cc = openPicker()
    local n = #recentRowsOf(cc)
    exp.recentShow = was
    return n == 2, tostring(n)
  end)())

check("🔎 A STORED ROW THE LIBRARY NO LONGER HAS is SKIPPED in the picker and "
   .. "COUNTED for the report — a pack that is merely absent this morning "
   .. "is the commonest reason, so it is not pruned",
  (function()
    exp.recentRows = exp.noteRecent(exp.recentRows,
                                    { trigger = "no-such-trigger", name = "gone" },
                                    os.time(), exp.recentMax)
    local cc = openPicker()
    for _, t in ipairs(recentRowsOf(cc)) do
      if t == "no-such-trigger" then return false, "it was drawn" end
    end
    return exp.recentStale == 1, "stale = " .. tostring(exp.recentStale)
  end)())
check("…and the store still holds it, so the pack coming back brings it back",
  keys(exp.recentRows):find("tno%-such%-trigger") ~= nil)

check("🚨 A KEYWORD-LESS SNIPPET IS RECORDED BY ITS NAME, and it is the only "
   .. "row in the picker whose identity is not its trigger. Alfred ships "
   .. "them and ⇪⇧S is the ONLY way to reach one — so if any snippet "
   .. "belongs in a recent queue it is this one",
  (function()
    exp.recentRows = {}
    -- keyword-less, the way a pack ships one: no trigger at all, so the
    -- picker is the only door to it. Appended the way load() builds the
    -- list rather than written into exp.snippets, which is keyed by the
    -- trigger this snippet does not have.
    exp.chooserOnly[#exp.chooserOnly + 1] =
      { text = "no keyword here", name = "Keywordless", source = "test" }
    local cc = openPicker()
    local kw
    for _, r in ipairs(cc.rows_) do
      if not (r.header or r.toggle or r.back) and r.trigger == ""
         and r.fullName == "Keywordless" then kw = r break end
    end
    if not kw then return false, "the fixture has no keyword-less snippet" end
    cc.cb(kw)
    if keys(exp.recentRows) ~= "n" .. kw.fullName then
      return false, keys(exp.recentRows) .. " (wanted n" .. kw.fullName .. ")"
    end
    -- …and it comes back on the next open, under the heading
    local nn = openPicker()
    for _, r in ipairs(nn.rows_) do
      if r.recent and not r.header and r.fullName == kw.fullName then return true end
    end
    return false, "it was recorded and did not come back"
  end)())

out("\n--- 🕘 the duplicate earns its place only at rest ---\n")

exp.recentRows = exp.noteRecent({}, { trigger = "gg1", name = "Greeting" }, os.time(), 50)
c = openPicker()
check("with nothing typed, both copies are on the list",
  (function()
    local n = 0
    for _, r in ipairs(exp.filter(c.rows_, "")) do
      if r.trigger == "gg1" then n = n + 1 end
    end
    return n == 2, tostring(n)
  end)())
check("🔍 …and the moment he types, the 🕘 copy is dropped: searching \"gg1\" "
   .. "and getting it twice is a list that makes him check which is which",
  (function()
    local n = 0
    for _, r in ipairs(exp.filter(c.rows_, "gg1")) do
      if r.trigger == "gg1" then n = n + 1 end
    end
    return n == 1, tostring(n)
  end)())

out("\n--- 🕘 ⏎ on the heading, and the two off switches ---\n")

exp.recentRows = exp.noteRecent({}, { trigger = "gg1", name = "Greeting" }, os.time(), 50)
local nc = openPicker(exp.recentName)
check("⏎ on the 🕘 heading narrows to the recent rows ALONE — the whole "
   .. "library must not print under it",
  (function()
    local other = 0
    for _, r in ipairs(nc.rows_) do
      if not (r.header or r.back) and not r.recent then other = other + 1 end
    end
    return other == 0 and #recentRowsOf(nc) == 1, tostring(other)
  end)())
check("…with the way back at the top, like every other narrowed view",
  nc.rows_[1] and nc.rows_[1].back == true)
check("🚨 …AND A COLLECTION SOMEBODY NAMES \"🕘 recent\" CANNOT HIJACK THAT "
   .. "VIEW. This is what makes the guard load-bearing rather than "
   .. "decorative: the row test inside the loop is `r.sect == section`, "
   .. "and a pack whose folder carries the queue's own name passes it",
  (function()
    exp.snippets["imposter1"] = { text = "x", name = "Imposter",
                                  source = exp.recentName }
    exp.count = exp.count + 1
    exp.buildIndex()
    local cc = openPicker(exp.recentName)
    local seen = false
    for _, r in ipairs(cc.rows_) do
      if r.trigger == "imposter1" then seen = true end
    end
    exp.snippets["imposter1"] = nil
    exp.count = exp.count - 1
    exp.buildIndex()
    return not seen
  end)())
check("🗂 the 🕘 heading says what it IS, and the rank-0 branch has to be "
   .. "tested BEFORE the pinned one to manage it: with one collection "
   .. "pinned, `rank <= #sectionOrder` is `0 <= 1` — true — and the queue "
   .. "would introduce itself as \"yours — pinned first\"",
  (function()
    local cc = openPicker()
    local _, h = headingOf(cc, "RECENT")
    return h and tostring(h.subText):find("you picked here", 1, true) ~= nil,
           h and h.subText
  end)())
check("🔒 the store is written to a DIFFERENT path and renamed into place — "
   .. "io.open(w) truncates before it writes a byte, so writing straight "
   .. "at the store is the zero-byte failure with extra steps (source "
   .. "sentry: a mid-write failure cannot be staged from here)",
  (function()
    local s = io.open(HS .. "/modules/text_expander.lua"):read("a")
    local body = s:match("function exp%.saveRecent%(%)(.-)\n    end\n")
    return body ~= nil
       and body:find('local tmp = exp.recentFile .. ".tmp"', 1, true) ~= nil
       and body:find("os.rename(tmp, exp.recentFile)", 1, true) ~= nil
       and body:find('io.open(tmp, "w")', 1, true) ~= nil
       and body:find('io.open(exp.recentFile, "w")', 1, true) == nil
  end)())
check("🕘 warm() REALLY READS THE STORE — driven, not grepped. The sentry "
   .. "this replaced matched its own needle inside a COMMENT, which is "
   .. "the one way a sentry fails: a needle that can only match itself "
   .. "can never fail (E3's shape, found by this release's own sweep)",
  (function()
    exp.recentRows = exp.noteRecent({}, { trigger = "fromdisk", name = "D" }, os.time(), 50)
    exp.saveRecent()
    exp.recentRows, exp.recentState = {}, "unread"
    mod.warm()
    return keys(exp.recentRows) == "tfromdisk" and exp.recentState == "read",
           exp.recentState .. " / " .. keys(exp.recentRows)
  end)())
check("…and it is warm() that does it, not setup(): a read at setup is a tax "
   .. "every keypress of the boot pays (6.267.0). The comments come out "
   .. "before this looks.",
  (function()
    local s = io.open(HS .. "/modules/text_expander.lua"):read("a")
    local bare = s:gsub("%-%-[^\n]*", "")
    local warm = bare:match("function M%.warm%(%)(.-)\n    end\n")
    return warm ~= nil and warm:find("loadRecent", 1, true) ~= nil
  end)())

check("✏️ exp.recent = false: no section, and nothing is recorded either",
  (function()
    -- a REAL trigger in the queue first: the checks above leave a stale
    -- one behind, and a stale row draws nothing, so without this the
    -- section would be absent for the wrong reason and this check would
    -- pass while proving nothing.
    exp.recentRows = exp.noteRecent({}, { trigger = "gg1", name = "Greeting" },
                                    os.time(), 50)
    if #recentRowsOf(openPicker()) ~= 1 then return false, "fixture" end
    exp.recent = false
    local cc = openPicker()
    local drew = headingOf(cc, "RECENT") ~= nil
    local was = keys(exp.recentRows)
    exp.noteUse(";mp3", { name = "mp3" })
    local same = keys(exp.recentRows) == was
    exp.recent = true
    return (not drew) and same
  end)())
check("✏️ exp.sections = false: the flat A–Z list stays flat — nine unlabelled "
   .. "duplicates at the top of it would be neither thing it promises",
  (function()
    exp.sections = false
    local cc = openPicker()
    local n = #recentRowsOf(cc)
    for _, r in ipairs(cc.rows_) do if r.header then n = n + 100 end end
    exp.sections = true
    return n == 0, tostring(n)
  end)())

check("🚨 THE LIST DOES NOT MOVE UNDER HIS HAND: a pick made while the panel "
   .. "is up leaves the rows on screen exactly as they were — a list that "
   .. "renumbers between opening it and pressing ⏎ is 6.272.0's defect in "
   .. "the one place he is aiming at a row",
  (function()
    exp.recentRows = exp.noteRecent({}, { trigger = "gg1", name = "G" }, os.time(), 50)
    local cc = openPicker()
    local before = {}
    for i, r in ipairs(cc.rows_) do before[i] = r end
    cc.cb(rowOf(cc, ";bd"))          -- records ;bd above gg1
    if #cc.rows_ ~= #before then return false, "the row count changed" end
    for i, r in ipairs(cc.rows_) do
      if before[i] ~= r then return false, "row " .. i .. " was replaced" end
    end
    -- and the NEXT open is where the new order shows up
    local nn = openPicker()
    return recentRowsOf(nn)[1] == ";bd", table.concat(recentRowsOf(nn), ",")
  end)())

out("\n--- 📋 _G.snippetsReport() — the instrument this module never had ---\n")

check("🚨 it EXISTS. His Console, the day the recency was scoped: "
   .. "_G.snippetsReport() → \"attempt to call a nil value\"",
  type(_G.snippetsReport) == "function")

local function reportText()
  local said = {}
  local realPrint = print
  print = function(s) said[#said + 1] = tostring(s) end
  local ok, err = pcall(_G.snippetsReport)
  print = realPrint
  return ok and table.concat(said, "\n") or ("THREW: " .. tostring(err))
end

check("it does not throw, and it names the library's size",
  (function()
    local t = reportText()
    return t:find("SNIPPETS", 1, true) and t:find("trigger(s)", 1, true), t:sub(1, 90)
  end)())
check("it prints the recent queue, newest first, with the time of each pick",
  (function()
    local t = reportText()
    return t:find("recent :", 1, true) ~= nil
           and t:find("1%. %s*;bd") ~= nil, t
  end)())
check("🔑 it PRINTS THE RULE — a reader must not have to go and find out "
   .. "that a typed trigger is not counted",
  (function()
    local t = reportText()
    return t:find("NOT recorded", 1, true) ~= nil
  end)())
check("🔎 an EMPTY queue says WHICH empty — \"no store yet\" is a different "
   .. "fact from a zero-byte file, and only one of them is fine",
  (function()
    os.remove(exp.recentFile)
    exp.recentRows = {} ; exp.loadRecent()
    local none = reportText()
    write(exp.recentFile, "")
    exp.loadRecent()
    local zero = reportText()
    write(exp.recentFile, "{{{")
    exp.loadRecent()
    local bad = reportText()
    return none:find("no store yet", 1, true)
       and zero:find("ZERO BYTES", 1, true)
       and bad:find("could not be read", 1, true)
       and none ~= zero and zero ~= bad
  end)())
check("…and \"off\" is its own word too, never silence",
  (function()
    exp.recent = false
    local t = reportText()
    exp.recent = true
    return t:find("recent : OFF", 1, true) ~= nil, t
  end)())
check("the stale count is reported when there is one, and not invented when "
   .. "there is not",
  (function()
    os.remove(exp.recentFile)
    exp.recentRows = exp.noteRecent({}, { trigger = "gg1", name = "G" }, os.time(), 50)
    exp.recentStale = 0
    local clean = reportText()
    exp.recentStale = 2
    local dirty = reportText()
    exp.recentStale = 0
    return clean:find("no longer has", 1, true) == nil
       and dirty:find("2 row%(s%) name a snippet") ~= nil
  end)())
check("📋 the cheat sheet carries both doors — the queue and the report",
  (function()
    local saw = { recent = false, report = false }
    for _, e in ipairs(mod.cheatsheet.entries) do
      if e[1] == "recent" then saw.recent = true end
      if e[1] == "report" then saw.report = true end
    end
    return saw.recent and saw.report
  end)())


out("\n=== ⌨️ 6.377.0 — a picked snippet lands at the caret, and it is counted ===\n")
-- LL, answering the focus question: "When I select a snippet 99% of the
-- time I want it to instantly paste."
-- 🔎 IT ALREADY DOES — ⏎ in the picker has gone straight to exp.inject
-- since the picker was built. What was missing is any way to tell that
-- from "it did nothing", which is why the counts are the release.
do
  local before = pass + fail
  -- BY TRIGGER, not by the row's text: the row's `text` is the snippet's
  -- NAME and the fixture's names move between sections of this suite.
  local function pickTrigger(trig)
    reset(); DEGRADED = {}
    CHOOSERS = {}
    exp.show()
    local ch = CHOOSERS[#CHOOSERS]
    if not ch then return nil end
    for _, r in ipairs(ch.rows_ or {}) do
      if r.pick and r.trigger == trig then ch.cb(r) ; return r end
    end
    return nil
  end
  -- and the two snippets are CHOSEN from what is loaded right now, so
  -- this section cannot go stale when a fixture above it changes
  local shortTrig, shortText, multiTrig
  for t, s in pairs(exp.snippets or {}) do
    local body = tostring(s.text or "")
    if not multiTrig and body:find("\n", 1, true) then multiTrig = t end
    -- 🚨 NO TOKEN IN IT. `exp.substitute` expands {date:…}, {clip} and
    -- friends, so a snippet carrying one types something that is
    -- correctly NOT its raw text — and the real 1,926-snippet library
    -- inside the package has plenty. Found by running the gate from
    -- INSIDE the package, which is the whole reason that step exists:
    -- the working tree's snippets/ is gitignored and holds something
    -- else. The check asserts what was TYPED equals the body, so the
    -- fixture has to be a snippet for which that is true.
    if not shortTrig and not body:find("\n", 1, true)
       and not body:find("{", 1, true)
       and #body > 0 and #body < 30 and not s.fn then
      shortTrig, shortText = t, body
    end
  end
  -- a multi-line one is ADDED through the module's own door if the
  -- library as loaded here holds none: the rule under test is "a
  -- newline is always pasted", and it needs a newline to test it with
  if not multiTrig then
    pcall(exp.add, "mlx", "line one\nline two", "Multi line")
    multiTrig = exp.snippets and exp.snippets["mlx"] and "mlx" or nil
  end
  check("the fixture offers a short single-line snippet and a multi-line one",
        shortTrig ~= nil and multiTrig ~= nil,
        tostring(shortTrig) .. "/" .. tostring(multiTrig))

  -- the counters start empty, and an empty count SAYS which empty
  exp.inserts = { pick  = { typed = 0, pasted = 0, refused = 0 },
                  typed = { typed = 0, pasted = 0, refused = 0 } }
  exp.lastInsert = nil
  local r0 = _G.snippetsReport()
  check("before anything is picked the report says so, not '0 typed'",
        r0:find("none picked from", 1, true) ~= nil, r0:match("⏎ pick[^\n]*"))

  -- ⏎ ON A SHORT SNIPPET TYPES IT AT THE CARET
  local got = pickTrigger(shortTrig)
  check("⏎ in the picker inserts the snippet — nothing else has to happen",
        got ~= nil and KEYSTROKES[1] == shortText,
        tostring(KEYSTROKES[1]) .. " want " .. tostring(shortText))
  check("…and it is counted as a PICK that was TYPED",
        exp.inserts.pick.typed == 1 and exp.inserts.pick.pasted == 0
        and exp.inserts.typed.typed == 0,
        exp.inserts.pick.typed .. "/" .. exp.inserts.typed.typed)

  -- 🚨 A PICK AND A TYPED TRIGGER ARE COUNTED APART, which is the whole
  -- distinction his sentence is about: they fail for different reasons.
  reset(); typeStr(" " .. shortTrig); drain()
  check("a TYPED trigger lands in the other bucket, not the pick one",
        exp.inserts.typed.typed == 1 and exp.inserts.pick.typed == 1,
        exp.inserts.pick.typed .. "/" .. exp.inserts.typed.typed)

  -- a multi-line pick is PASTED, and counted as pasted
  local m = pickTrigger(multiTrig)
  check("a multi-line snippet picked from ⇪⇧S is PASTED, never typed",
        m ~= nil and PASTED == 1 and #KEYSTROKES == 0, PASTED)
  check("…and the route is recorded as pasted, not as typed",
        exp.inserts.pick.pasted == 1, exp.inserts.pick.pasted)

  local r1 = _G.snippetsReport()
  check("the report names both buckets and both routes",
        r1:find("⏎ pick:", 1, true) ~= nil
        and r1:find("typed at the caret", 1, true) ~= nil
        and r1:find("pasted", 1, true) ~= nil, r1:match("⏎ pick[^\n]*"))
  -- the last thing in was the multi-line PICK, so the line must say
  -- picked AND pasted — the pair is what makes it readable
  check("…and names the last one that landed, with its door and its route",
        (r1:match("last in[^\n]*") or ""):find("picked", 1, true) ~= nil
        and (r1:match("last in[^\n]*") or ""):find("pasted", 1, true) ~= nil,
        r1:match("last in[^\n]*"))

  -- 🔔 AND A REFUSAL IS SEEN, NOT ONLY LOGGED (6.214.0). A picker whose
  -- whole job is that something lands, inserting nothing and saying
  -- nothing, is the complaint this release is about.
  local realStrokes2 = hs.eventtap.keyStrokes
  hs.eventtap.keyStrokes = function() error("macOS refused the keystrokes", 0) end
  local bad = pickTrigger(shortTrig)
  hs.eventtap.keyStrokes = realStrokes2
  check("a refused insert is counted as refused",
        bad ~= nil and exp.inserts.pick.refused == 1, exp.inserts.pick.refused)
  check("🔔 …and it takes the degrade door, naming the snippet",
        #DEGRADED == 1 and DEGRADED[1].tool == "Snippets"
        and DEGRADED[1].why:find("could not insert", 1, true) ~= nil,
        #DEGRADED .. " " .. tostring(DEGRADED[1] and DEGRADED[1].why))
  local r2 = _G.snippetsReport()
  check("…and the report carries the refusal, the name and the reason",
        r2:find("last REFUSED", 1, true) ~= nil
        and r2:find("refused the keystrokes", 1, true) ~= nil,
        r2:match("last REFUSED[^\n]*"))

  -- 🔒 ONE DOOR: the picker must not grow an insert of its own, or the
  -- two paths come to disagree about typing vs pasting (6.231.0).
  -- io.open is NOT stubbed in this suite (it writes a real fixture tree
  -- under TMP), so the plain one reads the module — asserted below all
  -- the same, because a sentry over an empty haystack is green and
  -- measures nothing (6.313.0).
  local SRC = io.open(HS .. "/modules/text_expander.lua", "r")
  local TXT = SRC and SRC:read("*a") or ""
  if SRC then SRC:close() end
  check("the sentry below really read the module", #TXT > 40000, #TXT)
  check("the picker inserts through exp.inject and nothing else",
        select(2, TXT:gsub("function exp%.inject", "")) == 1
        and TXT:find('exp.inject(row.trigger or "", row.snip, 0, nil, "pick")',
                     1, true) ~= nil)
  check("every caller of inject names its door or takes the default",
        select(2, TXT:gsub('"pick"', "")) >= 2)

  local ran = (pass + fail) - before
  check("§6.377.0 ran all of its checks (" .. ran .. " of 14)", ran >= 14, ran)
end


-- =====================================================================
-- §6.382.0 — A PICKED SNIPPET IS LEFT ON THE CLIPBOARD
-- =====================================================================
-- LL: "A picked snippet needs to land on the clipboard."
--
-- 🔎 NEITHER ROUTE DID. A short snippet was TYPED at the caret, so the
-- clipboard was never touched; a long one was pasted through a BORROW
-- that put his old clipboard straight back 0.25 s later. So the snippet
-- was never on the clipboard afterwards by either road, and the fix has
-- to be different on each — which is why both are driven here.
out("\n=== 19. 6.382.0 — a picked snippet stays on the clipboard ===\n")
do
  local before = pass + fail

  local function pick(trig)
    reset(); DEGRADED = {}; CHOOSERS = {}
    CLIPWRITES, CLIPBOARD = {}, nil
    exp.show()
    local ch = CHOOSERS[#CHOOSERS]
    if not ch then return nil end
    for _, r in ipairs(ch.rows_ or {}) do
      if r.pick and r.trigger == trig then ch.cb(r) ; return r end
    end
    return nil
  end

  -- the two fixtures, chosen from what is loaded rather than typed in
  local shortTrig, shortText, multiTrig
  for t, sn in pairs(exp.snippets or {}) do
    local body = tostring(sn.text or "")
    if not multiTrig and body:find("\n", 1, true) then multiTrig = t end
    if not shortTrig and not body:find("\n", 1, true)
       and not body:find("{", 1, true)
       and #body > 0 and #body < 30 and not sn.fn then
      shortTrig, shortText = t, body
    end
  end
  if not multiTrig then
    pcall(exp.add, "mlz", "line one\nline two", "Multi line z")
    multiTrig = exp.snippets and exp.snippets["mlz"] and "mlz" or nil
  end
  check("the fixture offers both a typed-route and a pasted-route snippet",
        shortTrig ~= nil and multiTrig ~= nil,
        tostring(shortTrig) .. "/" .. tostring(multiTrig))

  exp.pickToClipboard = true
  exp.clipLand = { kept = 0, refused = 0, why = nil, last = nil }
  CLIPREFUSE = false

  -- ---- the TYPED route: nothing borrowed, so the keep is a real write
  pick(shortTrig)
  check("a picked SHORT snippet is left on the clipboard",
        CLIPBOARD == shortText, tostring(CLIPBOARD) .. " want " .. tostring(shortText))
  check("…written through core.copyText, the one door that reads the return",
        #CLIPWRITES == 1 and CLIPWRITES[1].who ~= nil, #CLIPWRITES)
  check("…and counted, so the report can be asked whether it landed",
        exp.clipLand.kept == 1 and exp.clipLand.refused == 0,
        exp.clipLand.kept .. "/" .. exp.clipLand.refused)

  -- ---- the PASTED route: it is already there, so the fix is to NOT
  -- arm the restore. 🚨 THE FIXTURE THAT BITES: a later write on top of
  -- the restore would also leave the snippet there MOST of the time,
  -- and would be a race with our own timer (6.246.0). Asserting that NO
  -- restore was armed is the only thing that tells the two apart.
  pick(multiTrig)
  check("a picked MULTI-LINE snippet arms NO restore — the snippet stays",
        RESTOREDELAY == nil, tostring(RESTOREDELAY))
  check("…and it is not written a second time on top of its own paste",
        #CLIPWRITES == 0, #CLIPWRITES)
  -- 🔕 the suppress is what tells ⇪V to look away; a keep must be SEEN
  check("…and the clipboard history is NOT told to ignore it (it is a ⇪V row now)",
        SUPPRESSED == 0, SUPPRESSED)

  -- ---- 🚨 THE ONE THAT PROTECTS HIM. A typed trigger fires thousands
  -- of times a day. If this leaked, every expansion would overwrite
  -- whatever he had copied — strictly worse than not having the feature.
  reset(); CLIPWRITES, CLIPBOARD = {}, nil
  typeStr(" " .. shortTrig); drain()
  check("🚨 a TYPED trigger does NOT touch the clipboard",
        CLIPBOARD == nil and #CLIPWRITES == 0,
        tostring(CLIPBOARD) .. "/" .. #CLIPWRITES)

  -- a typed MULTI-LINE trigger still borrows and still gives it back
  if multiTrig then
    reset(); CLIPWRITES, CLIPBOARD = {}, nil
    typeStr(" " .. multiTrig); drain()
    check("…and a typed multi-line trigger still BORROWS and restores",
          RESTOREDELAY == 0.25 and SUPPRESSED > 0,
          tostring(RESTOREDELAY) .. "/" .. SUPPRESSED)
  end

  -- ---- the switch is real in both directions
  exp.pickToClipboard = false
  pick(multiTrig)
  check("OFF restores the old behaviour exactly: the borrow is given back",
        RESTOREDELAY == 0.25, tostring(RESTOREDELAY))
  exp.pickToClipboard = true

  -- ---- 🔔 A REFUSED WRITE IS SEEN, not silently absent
  CLIPREFUSE = true
  exp.clipLand = { kept = 0, refused = 0, why = nil, last = nil }
  pick(shortTrig)
  check("a refused clipboard write is counted, not swallowed",
        exp.clipLand.refused == 1 and exp.clipLand.kept == 0,
        exp.clipLand.kept .. "/" .. exp.clipLand.refused)
  check("…and it takes the 🔔 door, so he sees it rather than reading a log",
        #DEGRADED > 0, #DEGRADED)
  local rR = _G.snippetsReport()
  check("…and the report carries the ⚠️ with macOS's own words",
        rR:find("REFUSED by macOS", 1, true) ~= nil, rR:match("clip[^\n]*"))
  CLIPREFUSE = false

  -- ---- 🚨 THE REPORT MUST NOT PROMISE THE OLD BEHAVIOUR. That line
  -- read "(⌘V, clipboard put back)" for BOTH routes, which is now false
  -- for a pick — 6.181.0's stale row, in a diagnostic.
  exp.clipLand = { kept = 2, refused = 0, why = nil,
                   last = { name = "x", route = "written after it was typed",
                            at = os.time() } }
  local rOn = _G.snippetsReport()
  check("the report says a PICK is left on the clipboard",
        (rOn:match("⏎ pick[^\n]*") or ""):find("LEFT on the clipboard", 1, true) ~= nil,
        rOn:match("⏎ pick[^\n]*"))
  -- 🚨 THE NEEDLE IS ANCHORED TO THE LINE'S OWN START. "typed at the
  -- caret" appears INSIDE the pick row too, so a bare "typed " match
  -- reads the neighbour and the check passes for the wrong reason —
  -- 6.263.0's unbounded window, met here in a check rather than a
  -- sentry. The first version of this did exactly that.
  local typedLine = rOn:match("\n   typed :[^\n]*") or ""
  check("…while a TYPED trigger still says the clipboard is put back",
        typedLine:find("clipboard put back", 1, true) ~= nil, typedLine)
  check("…and the clip line names the count",
        (rOn:match("\n   clip   :[^\n]*") or ""):find("left on the clipboard", 1, true) ~= nil,
        rOn:match("\n   clip   :[^\n]*"))
  exp.pickToClipboard = false
  local rOff = _G.snippetsReport()
  local clipOff = rOff:match("\n   clip   :[^\n]*") or ""
  check("…and with the switch OFF the report says OFF, with the line to turn it on",
        clipOff:find("OFF", 1, true) ~= nil
        and rOff:find("pickToClipboard = true", 1, true) ~= nil, clipOff)
  exp.pickToClipboard = true

  local ran = (pass + fail) - before
  check("§6.382.0 ran all of its checks (" .. ran .. " of 16)", ran >= 16, ran)
end

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.execute("rm -rf '" .. TMP .. "'")
os.exit(fail == 0 and 0 or 1)
