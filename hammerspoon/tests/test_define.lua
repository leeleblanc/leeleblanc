-- =====================================================================
-- test_define.lua — ⇪8: what it means, what else you could say
-- =====================================================================
--     lua5.4 test_define.lua [/path/to/hammerspoon]
--
-- Executes modules/define.lua against a stubbed hs. There is no
-- Homebrew, no WordNet and no network anywhere in this file: both
-- parsers are pure functions of a string, which is the whole reason the
-- providers were built that way.
--
-- FOUR SECTIONS HAVE TEETH:
--
--   §2 THE PARSER IS THE PRODUCT. A gloss that contains " -- " must not
--      bleed into the synonym list, a sense whose only member is the
--      word itself must KEEP ITS DEFINITION, and light_up must reach
--      your sentence as "light up". BREAKs A, C and E.
--
--   §5 🚨 A STALE ANSWER MUST NEVER BE DRAWN. Look up `terse`, give up,
--      look up `laconic`; terse's slow reply arrives and repaints the
--      open picker with terse's synonyms under laconic's title. ⏎ then
--      types the wrong word into a document and everything on screen
--      agreed it was right. BREAK D removes the guard and the test
--      watches the wrong word arrive.
--
--   §7 THE GUARDS LIVE IN power_tools, NOT HERE. Replacing a selection
--      needs a secure-input check, a wait for ⌘⇧⌃⌥ and a length cap. A
--      second copy of those is a second place to forget the first one —
--      which is the only one whose absence is invisible.
--
--   §9 NOTHING IN THIS MODULE MAY BLOCK THE THREAD. hs.http.get and
--      io.popen would each freeze every keystroke on the Mac for the
--      length of a lookup. A source sentry reads the file.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function section(s) io.write("\n=== " .. s .. " ===\n") end

local REALPRINT = print
print = function() end

-- ---- the stub Mac ------------------------------------------------------
local ALERTS, TIMERS, TASKS, CHOOSERS = {}, {}, {}, {}
local CLIP, OPENED, SHOWS = nil, {}, 0
local FILES = { ["/opt/homebrew/bin/wn"] = 2048 }   -- WordNet is installed
local DIRS  = { ["/opt/homebrew/share/wordnet"] = true }
local HTTP_STATUS, HTTP_BODY = 200, "[]"
local HTTP_CALLS = {}

hs = {
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = { setContents = function(s) CLIP = s ; return true end },
    urlevent = { openURL = function(u) OPENED[#OPENED + 1] = u end },
    fs = {
        attributes = function(p, what)
            if what == "mode" then return DIRS[p] and "directory" or nil end
            if what == "size" then return FILES[p] end
            if FILES[p] then return { size = FILES[p], mode = "file" } end
            if DIRS[p] then return { mode = "directory" } end
            return nil
        end,
    },
    timer = {
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    task = {
        new = function(bin, cb, args)
            local t = { bin = bin, cb = cb, args = args,
                        started = false, terminated = false, env = nil }
            function t:start() self.started = true ; return self end
            function t:terminate() self.terminated = true ; return self end
            function t:setEnvironment(e) self.env = e ; return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    http = {
        encodeForQuery = function(s) return (tostring(s):gsub(" ", "%%20")) end,
        asyncGet = function(url, hdrs, cb)
            HTTP_CALLS[#HTTP_CALLS + 1] = { url = url, cb = cb }
        end,
    },
    json = {
        decode = function(s)
            -- The suite hands apiParse a real table; decode only has to
            -- survive being called and to throw on rubbish, which is the
            -- path the "unreadable JSON" branch takes.
            if s == "<<bad>>" then error("bad json", 0) end
            return _G.__DECODED
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, choices_ = {}, placeholder = "",
                        query_ = nil, qcb = nil }
            function c:choices(x) self.choices_ = x ; return self end
            function c:placeholderText(x) self.placeholder = x ; return self end
            function c:query(x) self.query_ = x ; return self end
            function c:show() SHOWS = SHOWS + 1 ; return self end
            function c:width(n) return self end
            function c:searchSubText(b) return self end
            function c:queryChangedCallback(f) self.qcb = f ; return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

-- The service bus, as define.lua sees it. REPLACED records every call to
-- power.replaceSelection so §7 can prove the guards are reached rather
-- than reimplemented.
local REPLACED, READ_LABEL = {}, nil
local SELECTION = nil
local HAS_POWER = true
_G.service = {
    has = function(n)
        if not HAS_POWER then return false end
        return n == "power.replaceSelection" or n == "power.readSelection"
    end,
    call = function(n, a, b, c)
        if not HAS_POWER then return nil end
        if n == "power.replaceSelection" then
            REPLACED[#REPLACED + 1] = { text = a, icon = b, what = c }
            return true
        end
        if n == "power.readSelection" then
            READ_LABEL = a
            if SELECTION ~= nil then b(SELECTION, "accessibility") end
            return true
        end
    end,
}

local BOUND, PROVIDED = {}, {}
local CORE = {
    homeDir = "/Users/test",
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local f = assert(io.open(HS .. "/modules/define.lua", "r"))
local src = f:read("*a") ; f:close()

local chunk = assert(loadfile(HS .. "/modules/define.lua"))
local M = chunk()
M.setup(CORE)
local d = _G.define

local function reset()
    ALERTS, TIMERS, TASKS = {}, {}, {}
    OPENED, REPLACED, HTTP_CALLS = {}, {}, {}
    CLIP, SELECTION, READ_LABEL = nil, nil, nil
    HAS_POWER = true
    d.cache, d.cacheOrder = {}, {}
    d.lastNote, d.lastResult = nil, nil
    d._wn = nil
end

-- The real thing `wn light -over` prints, trimmed to the senses that
-- matter here. Sense 3 has ONE synonym, sense 4 has only the headword
-- (so it must keep its definition and offer nothing), and sense 5's
-- gloss contains " -- " on purpose — see BREAK A.
local WN = [[

Overview of noun light

The noun light has 10 senses (first 6 from tagged texts)

1. (395) light, visible light, visible radiation -- ((physics) electromagnetic radiation that can produce a visual sensation; "the light was filtered through a soft glass window")
2. (22) light, light source -- (any device serving as a source of illumination; "he stopped the car and turned off the lights")
3. lighting -- (having abundant light or illumination)
4. light -- (mental understanding as an enlightening experience)
5. light, lamp -- (a wick or oil lamp -- the older kind; "an oil light")

Overview of verb light

The verb light has 5 senses (first 3 from tagged texts)

1. (7) light, illume, illuminate, light_up, illumine -- (make lighter or brighter; "This lamp lightens the room a bit")
]]

-- =====================================================================
section("1. it loads and binds")
-- =====================================================================
check("⇪8 is bound", BOUND["+8"] ~= nil)
check("…and nothing here claims ⇪⇧8", BOUND["shift+8"] == nil)
check("the cheat sheet key cell is exactly ⇪8", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪8" then return true end
    end
    return false
end)())
check("every action has a service", PROVIDED["define.show"] and
      PROVIDED["define.selection"] and PROVIDED["define.lookup"] and
      PROVIDED["define.report"])
check("the module declares a family so the cheat sheet can place it",
      M.family == "text")

-- =====================================================================
section("2. 📖 parsing WordNet — the product")
-- =====================================================================
local senses = d.wnParse(WN, "light")
check("every sense is found", #senses == 6, #senses)
check("the part of speech travels with the sense",
      senses[1].pos == "noun" and senses[6].pos == "verb",
      tostring(senses[1].pos) .. "/" .. tostring(senses[6].pos))
check("the gloss is unwrapped from its parentheses",
      senses[1].gloss == "(physics) electromagnetic radiation that can "
                         .. "produce a visual sensation", senses[1].gloss)
check("🚨 …and the corpus frequency is not left on the front of it",
      senses[1].gloss:find("395") == nil, senses[1].gloss)
check("the example is split off rather than glued to the definition",
      senses[1].example == "the light was filtered through a soft glass window",
      senses[1].example)
check("the synonyms are split on the comma",
      table.concat(senses[1].synonyms, "|") == "visible light|visible radiation",
      table.concat(senses[1].synonyms, "|"))
check("🚨 the word itself is NOT among its own synonyms — a row whose ⏎ "
      .. "retypes the word you already had reads as a broken tool",
      (function()
          for _, s in ipairs(senses) do
              for _, syn in ipairs(s.synonyms) do
                  if syn:lower() == "light" then return false end
              end
          end
          return true
      end)())
check("a sense with one synonym keeps it",
      table.concat(senses[3].synonyms, "|") == "lighting",
      table.concat(senses[3].synonyms, "|"))
check("🚨 a sense whose only member IS the word keeps its definition",
      senses[4].gloss == "mental understanding as an enlightening experience",
      senses[4].gloss)
check("🚨 …and simply offers no synonyms, rather than vanishing",
      #senses[4].synonyms == 0, #senses[4].synonyms)
check("a sense with no example says so by having none",
      senses[3].example == nil, senses[3].example)
-- 🚨 The one a greedy pattern gets wrong. See BREAK A.
check("🚨 a gloss containing ' -- ' does not bleed into the synonyms",
      table.concat(senses[5].synonyms, "|") == "lamp",
      table.concat(senses[5].synonyms, "|"))
check("🚨 …and the gloss keeps the dash it owns",
      senses[5].gloss == "a wick or oil lamp -- the older kind", senses[5].gloss)
check("🚨 an underscore never reaches your sentence",
      (function()
          for _, syn in ipairs(senses[6].synonyms) do
              if syn == "light up" then return true end
          end
          return false
      end)(), table.concat(senses[6].synonyms, "|"))
check("nothing at all parses to nothing, without throwing",
      #d.wnParse("", "x") == 0)
check("nil parses to nothing", #d.wnParse(nil, "x") == 0)
check("wn's 'no information' answer yields no senses",
      #d.wnParse("\nNo information available for noun frobnicate\n",
                 "frobnicate") == 0)

-- =====================================================================
section("3. 🌐 parsing dictionaryapi.dev")
-- =====================================================================
local API = { {
    word = "terse",
    meanings = { {
        partOfSpeech = "adjective",
        synonyms = { "concise", "succinct" },
        definitions = {
            { definition = "Sparing of words.", example = "a terse reply",
              synonyms = { "curt" } },
            { definition = "Abruptly brief." },
        },
    } },
} }
local a = d.apiParse(API, "terse")
check("each definition becomes a sense", #a == 2, #a)
check("the part of speech is carried down to it",
      a[1].pos == "adjective", a[1].pos)
check("the definition and its example survive",
      a[1].gloss == "Sparing of words." and a[1].example == "a terse reply")
check("🚨 synonyms are read from BOTH levels — the definition's first, "
      .. "then the part of speech's",
      table.concat(a[1].synonyms, "|") == "curt|concise|succinct",
      table.concat(a[1].synonyms, "|"))
check("…and a definition with none still inherits the shared ones",
      table.concat(a[2].synonyms, "|") == "concise|succinct",
      table.concat(a[2].synonyms, "|"))
check("🚨 the word itself is dropped here too", (function()
    local B = { { meanings = { { partOfSpeech = "n", synonyms = { "Terse", "x" },
                  definitions = { { definition = "d" } } } } } }
    local r = d.apiParse(B, "terse")
    return table.concat(r[1].synonyms, "|") == "x"
end)())
check("a duplicate synonym is not listed twice", (function()
    local B = { { meanings = { { partOfSpeech = "n", synonyms = { "curt" },
                  definitions = { { definition = "d", synonyms = { "curt" } } } } } } }
    return #d.apiParse(B, "terse")[1].synonyms == 1
end)())
check("rubbish parses to nothing rather than throwing",
      #d.apiParse("not a table", "x") == 0 and #d.apiParse(nil, "x") == 0)
check("an empty array parses to nothing", #d.apiParse({}, "x") == 0)

-- =====================================================================
section("4. the providers, and what they say when they are not there")
-- =====================================================================
reset()
check("WordNet is asked first", d.providers[1].id == "wordnet")
check("…and the network one second", d.providers[2].id == "api")
check("wn is found where Homebrew put it",
      d.wnPath() == "/opt/homebrew/bin/wn", d.wnPath())
d._wn = nil ; FILES = { ["/Users/test/homebrew/bin/wn"] = 100 }
check("🚨 a Homebrew in the HOME directory is still a Homebrew — the work "
      .. "Mac has no admin rights and /opt does not exist there",
      d.wnPath() == "/Users/test/homebrew/bin/wn", d.wnPath())
d._wn = nil ; FILES = {}
check("no wn anywhere is nil, not a guess", d.wnPath() == nil, d.wnPath())
check("…and the provider reports itself unavailable",
      d.providers[1].available() == false)
check("🚨 …with a reason that names the FIX, not just the fault",
      d.providers[1].why():find("brew install wordnet") ~= nil,
      d.providers[1].why())
FILES = { ["/opt/homebrew/bin/wn"] = 2048 } ; d._wn = nil

check("🚨 the network provider is OFF by default — a lookup must not send "
      .. "the word you are writing about anywhere by surprise",
      d.allowNetwork == false)
check("…so it reports itself unavailable", d.providers[2].available() == false)
check("…and says what turning it on costs",
      d.providers[2].why():find("somebody else's server") ~= nil,
      d.providers[2].why())
d.allowNetwork = true
check("…and it becomes available when you say so",
      d.providers[2].available() == true)
d.allowNetwork = false

check("wn's data directory is found beside the binary",
      d.wnSearchDir("/opt/homebrew/bin/wn") == "/opt/homebrew/share/wordnet",
      d.wnSearchDir("/opt/homebrew/bin/wn"))
check("🚨 …and is left unset when it cannot be found, because a wrong "
      .. "WNSEARCHDIR makes every word look nonexistent",
      d.wnSearchDir("/nowhere/bin/wn") == nil, d.wnSearchDir("/nowhere/bin/wn"))

-- =====================================================================
section("5. 🚨 the lookup, and the stale answer that must never be drawn")
-- =====================================================================
reset()
do
    local got
    d.lookup("light", function(r) got = r end)
    check("the lookup runs wn asynchronously", #TASKS == 1 and TASKS[1].started)
    check("…with the word and -over",
          TASKS[1].args[1] == "light" and TASKS[1].args[2] == "-over",
          table.concat(TASKS[1].args, " "))
    check("…and WNSEARCHDIR set from beside the binary",
          TASKS[1].env and TASKS[1].env.WNSEARCHDIR == "/opt/homebrew/share/wordnet")
    check("…and a timeout armed so the picker cannot say 'looking up' forever",
          #TIMERS == 1 and TIMERS[1].secs == d.wnTimeout)
    TASKS[1].cb(0, WN)
    check("the answer arrives shaped for the panel",
          got and got.word == "light" and #got.senses == 6, got and #got.senses)
    check("…and names the source that answered", got.source == "WordNet",
          got and got.source)
    check("…and the timeout was stood down", TIMERS[1].stopped == true)
end
do
    -- Same word again: no second process.
    local before = #TASKS
    local got
    d.lookup("light", function(r) got = r end)
    check("a repeat lookup is served from the cache", #TASKS == before, #TASKS)
    check("…with the same answer", got and #got.senses == 6)
end
do
    reset()
    local got, called = nil, 0
    d.lookup("frobnicate", function(r) got = r ; called = called + 1 end)
    TASKS[1].cb(1, "\nNo information available for noun frobnicate\n")
    check("a word nobody knows comes back as nil, once", got == nil and called == 1,
          called)
    check("…and is NOT cached, so installing WordNet later fixes it without "
          .. "a reload", d.cache["frobnicate"] == nil)
end
do
    -- 🚨 THE GENERATION GUARD. See the header and BREAK D.
    reset()
    local drawn = {}
    d.lookup("terse", function(r) drawn[#drawn + 1] = r end)
    local terseTask = TASKS[1]
    d.lookup("laconic", function(r) drawn[#drawn + 1] = r end)
    local laconicTask = TASKS[2]
    laconicTask.cb(0, "\nOverview of adj laconic\n\n1. laconic, curt -- (brief)\n")
    check("the second lookup is drawn", #drawn == 1 and drawn[1].word == "laconic",
          #drawn)
    terseTask.cb(0, WN)
    check("🚨 the first lookup's late answer is DROPPED, not drawn over it",
          #drawn == 1, #drawn)
    check("…and the note says a stale answer was seen", d.lastResult.word == "laconic",
          d.lastResult and d.lastResult.word)
end
do
    -- A provider that answers twice must not repaint the panel twice.
    reset()
    local calls = 0
    local fake = { id = "fake", label = "Fake", available = function() return true end,
                   why = function() return "" end,
                   lookup = function(w, done)
                       done({ { pos = "n", gloss = "g", synonyms = { "x" } } })
                       done({ { pos = "n", gloss = "OTHER", synonyms = { "y" } } })
                   end }
    local saved = d.providers
    d.providers = { fake }
    d.lookup("thing", function() calls = calls + 1 end)
    check("🚨 a provider that answers twice is heard exactly once", calls == 1, calls)
    d.providers = saved
end
do
    -- Nobody available at all: the caller is told, once, and the panel
    -- can fall back to Dictionary.app.
    reset()
    FILES = {} ; d._wn = nil ; d.allowNetwork = false
    local got, called = "unset", 0
    d.lookup("light", function(r) got = r ; called = called + 1 end)
    check("with no source at all the answer is nil, exactly once",
          got == nil and called == 1, called)
    FILES = { ["/opt/homebrew/bin/wn"] = 2048 } ; d._wn = nil
end
do
    reset()
    local got, called = "unset", 0
    d.lookup("   ", function(r) got = r ; called = called + 1 end)
    check("a blank word is refused without starting anything",
          got == nil and called == 1 and #TASKS == 0, #TASKS)
end
do
    -- The cache is bounded. A config that runs for weeks must not grow a
    -- table forever.
    reset()
    local keep = d.cacheMax
    d.cacheMax = 3
    for i = 1, 6 do
        d.remember("w" .. i, { word = "w" .. i, source = "x", senses = {} })
    end
    check("🚨 the cache is bounded", #d.cacheOrder == 3, #d.cacheOrder)
    check("…and it is the OLDEST that leaves", d.cache["w1"] == nil
          and d.cache["w6"] ~= nil)
    d.cacheMax = keep
end

-- =====================================================================
section("6. the rows — definition and synonyms on the same line")
-- =====================================================================
reset()
local result = { word = "light", source = "WordNet", senses = d.wnParse(WN, "light") }
local rows = d.rows(result)
check("every sense contributes a definition row", (function()
    local n = 0
    for _, r in ipairs(rows) do if r.kind == "definition" then n = n + 1 end end
    return n == 6
end)())
-- 2 + 1 + 1 + 0 + 1 for the noun senses, 4 for the verb.
check("every synonym contributes a row", (function()
    local n = 0
    for _, r in ipairs(rows) do if r.kind == "synonym" then n = n + 1 end end
    return n == 9
end)())
check("🚨 a synonym row carries the definition it belongs to, which is what "
      .. "'at the same time' has to mean if you are going to act on it",
      (function()
          for _, r in ipairs(rows) do
              if r.kind == "synonym" and r.payload == "visible light" then
                  return r.subText:find("electromagnetic") ~= nil
              end
          end
          return false
      end)())
check("…and its part of speech, so a noun's synonym is not offered for a verb",
      (function()
          for _, r in ipairs(rows) do
              if r.payload == "light up" then return r.pos == "verb" end
          end
          return false
      end)())
-- 🚨 The payload is what gets typed into your document, so it must be
-- the word alone — not the row's text, which carries an emoji and two
-- spaces of padding in front of it.
check("the synonym row's payload is the bare word, ready to type",
      (function()
          for _, r in ipairs(rows) do
              if r.kind == "synonym" then
                  return r.payload == "visible light"
                         and r.text:find(r.payload, 1, true) ~= nil
                         and r.text ~= r.payload
              end
          end
      end)())
check("a definition row's payload is the definition, ready to copy",
      (function()
          for _, r in ipairs(rows) do
              if r.kind == "definition" then
                  return r.payload:find("electromagnetic") ~= nil
              end
          end
      end)())
check("nothing at all yields no rows", #d.rows(nil) == 0 and #d.rows({}) == 0)
do
    local keep = d.maxSynonyms
    d.maxSynonyms = 1
    local r2 = d.rows(result)
    local n = 0
    for _, r in ipairs(r2) do if r.kind == "synonym" then n = n + 1 end end
    check("the per-sense synonym cap holds", n <= 6, n)
    d.maxSynonyms = keep
end
do
    local keep = d.maxSenses
    d.maxSenses = 2
    local n = 0
    for _, r in ipairs(d.rows(result)) do
        if r.kind == "definition" then n = n + 1 end
    end
    check("the sense cap holds — a word like 'set' has hundreds", n == 2, n)
    d.maxSenses = keep
end

-- =====================================================================
section("7. 🚨 acting on a row — and whose guards run")
-- =====================================================================
reset()
d.pick({ kind = "synonym", payload = "succinct" })
check("🚨 ⏎ on a synonym goes through power.replaceSelection — the "
      .. "secure-input check, the modifier wait and the length cap have "
      .. "exactly one home and it is not this file",
      #REPLACED == 1 and REPLACED[1].text == "succinct",
      #REPLACED)
check("…and it is labelled so the refusals name the tool you pressed",
      REPLACED[1].icon == "📖" and REPLACED[1].what == "synonym",
      tostring(REPLACED[1].icon) .. "/" .. tostring(REPLACED[1].what))
reset()
d.pick({ kind = "definition", payload = "sparing of words" })
check("⏎ on a definition copies it", CLIP == "sparing of words", CLIP)
check("…and nothing is typed over your selection", #REPLACED == 0)
reset()
d.pick({ kind = "dictionary", payload = "light" })
check("⏎ on the last row opens Dictionary.app",
      (OPENED[1] or ""):find("^dict://") ~= nil, OPENED[1])
check("…at the word", (OPENED[1] or ""):find("light") ~= nil, OPENED[1])
reset()
check("a row with no kind does nothing rather than throwing",
      d.pick({}) == false and d.pick(nil) == false)

-- 🚨 POWER TOOLS MISSING must not silently do nothing.
reset()
HAS_POWER = false
local ok = d.pick({ kind = "synonym", payload = "succinct" })
check("🚨 with power_tools absent the word goes to the clipboard instead",
      CLIP == "succinct", CLIP)
check("…and it says why rather than appearing to work",
      (ALERTS[#ALERTS] or ""):find("Power Tools") ~= nil, ALERTS[#ALERTS])
check("…and reports it", tostring(d.lastNote):find("replaceSelection") ~= nil,
      d.lastNote)
local _ = ok
HAS_POWER = true

-- =====================================================================
section("8. ⇪8 — the panel")
-- =====================================================================
reset()
d.show("light")
local ch = CHOOSERS[#CHOOSERS]
check("the panel opens immediately, before any answer",
      ch.choices_[1] and ch.choices_[1].kind == "waiting",
      ch.choices_[1] and ch.choices_[1].kind)
check("🚨 …and the Dictionary.app row is there from the first frame, so a "
      .. "source that never answers still leaves you somewhere to go",
      ch.choices_[2] and ch.choices_[2].kind == "dictionary")
TASKS[1].cb(0, WN)
check("the rows arrive when the answer does", #ch.choices_ > 5, #ch.choices_)
check("the placeholder names the source that answered",
      ch.placeholder:find("WordNet") ~= nil, ch.placeholder)
check("…and how many senses", ch.placeholder:find("6 sense") ~= nil, ch.placeholder)
check("the Dictionary.app row is still last",
      ch.choices_[#ch.choices_].kind == "dictionary")

reset()
d.show("the quick brown fox")
check("🚨 a whole sentence is cut to its first word — a lookup of forty "
      .. "words is a lookup of nothing, and would send forty words to the "
      .. "API if that were switched on",
      TASKS[1] and TASKS[1].args[1] == "the", TASKS[1] and TASKS[1].args[1])
check("…and the panel says it did that", (CHOOSERS[#CHOOSERS].placeholder or "")
      :find("first word") ~= nil, CHOOSERS[#CHOOSERS].placeholder)

reset()
local before = #TASKS
d.show("!!! ???")
check("something with no word in it looks nothing up", #TASKS == before, #TASKS)
check("…and says so", (ALERTS[#ALERTS] or ""):find("no word") ~= nil, ALERTS[#ALERTS])

reset()
d.show("")
check("nothing selected opens the box empty rather than refusing",
      #CHOOSERS[#CHOOSERS].choices_ == 0)
check("…and invites you to type", CHOOSERS[#CHOOSERS].placeholder
      :find("type a word") ~= nil, CHOOSERS[#CHOOSERS].placeholder)
check("…and looks nothing up until you do", #TASKS == 0, #TASKS)
do
    local c = CHOOSERS[#CHOOSERS]
    c.qcb("laconic")
    check("typing offers a Look up row", c.choices_[1]
          and c.choices_[1].kind == "lookup", c.choices_[1] and c.choices_[1].kind)
    check("…carrying what you typed", c.choices_[1].payload == "laconic",
          c.choices_[1].payload)
end

reset()
FILES = {} ; d._wn = nil
d.show("light")
d.lookup("light", function() end)
check("with no source, the panel says WordNet is missing rather than "
      .. "'no such word'", (function()
          for _, r in ipairs(CHOOSERS[#CHOOSERS].choices_) do
              if (r.subText or ""):find("WordNet is not installed") then return true end
          end
          return false
      end)())
FILES = { ["/opt/homebrew/bin/wn"] = 2048 } ; d._wn = nil

-- ⇪8 reads the selection through power_tools rather than growing its own.
reset()
SELECTION = "terse"
d.fromSelection()
check("⇪8 reads the selection through power.readSelection",
      READ_LABEL == "📖", READ_LABEL)
check("…and looks up what it found", TASKS[1] and TASKS[1].args[1] == "terse",
      TASKS[1] and TASKS[1].args[1])
reset()
HAS_POWER = false
d.fromSelection()
check("…and with power_tools gone it still opens, empty",
      CHOOSERS[#CHOOSERS].placeholder:find("type a word") ~= nil,
      CHOOSERS[#CHOOSERS].placeholder)
HAS_POWER = true

-- =====================================================================
section("9. the report, and the thread it must never block")
-- =====================================================================
reset()
do
    local r = _G.defineReport()
    check("the report lists every source", r:find("WordNet") and
          r:find("dictionaryapi") and r:find("Dictionary.app") ~= nil)
    check("…marks which are ready on THIS Mac", r:find("✅") ~= nil)
    check("…and which are not, with the fix",
          r:find("brew install wordnet") ~= nil or r:find("❌") ~= nil, r)
    check("…says plainly whether words leave the Mac",
          r:find("nothing is sent anywhere") ~= nil, r)
    d.allowNetwork = true
    check("…and says the other thing when they do",
          _G.defineReport():find("leave this Mac") ~= nil)
    d.allowNetwork = false
    check("…names the wn binary it found", r:find("/opt/homebrew/bin/wn") ~= nil)
    check("…and counts what happened", r:find("looked up") and
          r:find("swapped") ~= nil)
end

-- 🚨 SOURCE SENTRIES. Hammerspoon has one thread and it is the thread
-- that reads the keyboard: a synchronous fetch or a synchronous shell
-- freezes typing in every app for the length of a lookup. That is the
-- exact fault core/lag.lua was built to measure in 6.131.0, and shipping
-- a new cause of it in the next release would be a poor joke.
check("🚨 no io.popen anywhere in the module",
      src:find("io%.popen") == nil)
check("🚨 no hs.execute — it blocks the thread that reads your keyboard",
      src:find("hs%.execute") == nil)
check("🚨 no synchronous hs.http.get / .post",
      src:find("hs%.http%.get") == nil and src:find("hs%.http%.post") == nil)
check("🚨 …the fetch is asyncGet", src:find("hs%.http%.asyncGet") ~= nil)
check("🚨 the wn call goes through hs.task, not a shell",
      src:find("hs%.task%.new") ~= nil)
check("🚨 the generation guard is present and compared",
      src:find("mine ~= d%.gen") ~= nil)
check("closing the picker bumps the generation, so a reply cannot repaint "
      .. "a panel you have shut", src:find("if not choice then d%.gen") ~= nil)

-- =====================================================================
section("10. 🔨 break tests")
-- =====================================================================
local function build(broken, name)
    local bchunk = assert(load(broken, name))
    local bm = bchunk()
    bm.setup({ homeDir = "/Users/test", hyperAddShortcut = function() end,
               provide = function() end })
    return _G.define
end

-- BREAK A — split the sense line on the LAST " -- " instead of the
-- first. This is the "tidy up the pattern" edit, and it silently feeds
-- half a definition into the list of words you might type.
do
    local broken = src:gsub('local left, right = body:match%("%^%(%.%-%) %%%-%%%- %(%.%*%)%$"%)',
                            'local left, right = body:match("^(.*) %%-%%- (.*)$")', 1)
    check("BREAK A changed the source", broken ~= src)
    local b = build(broken, "broken-A")
    local s = b.wnParse(WN, "light")
    check("🔨 BREAK A caught: a gloss bleeds into the synonym list",
          table.concat(s[5].synonyms, "|") ~= "lamp",
          table.concat(s[5].synonyms, "|"))
end

-- BREAK B — stop dropping the headword from its own synonyms. Every
-- sense grows a row whose ⏎ retypes the word you already had.
do
    local broken = src:gsub(
        'if s ~= "" and s:lower%(%) ~= tostring%(word or ""%):lower%(%) then',
        'if s ~= "" then', 1)
    check("BREAK B changed the source", broken ~= src)
    local b = build(broken, "broken-B")
    local s = b.wnParse(WN, "light")
    check("🔨 BREAK B caught: the word is offered as its own synonym",
          s[1].synonyms[1] == "light", s[1].synonyms[1])
end

-- BREAK C — drop a sense that has no synonyms. Sense 4 of `light` is a
-- real meaning with a real definition and no other word for it; losing
-- it loses the definition, which is half of what was asked for.
do
    local broken = src:gsub("senses%[#senses %+ 1%] = {\n%s+pos = pos, gloss = gloss, example = example,\n%s+synonyms = syns,\n%s+}",
        "if #syns > 0 then senses[#senses + 1] = {\n"
        .. "                        pos = pos, gloss = gloss, example = example,\n"
        .. "                        synonyms = syns,\n                    } end", 1)
    check("BREAK C changed the source", broken ~= src)
    local b = build(broken, "broken-C")
    check("🔨 BREAK C caught: a definition disappears because nothing "
          .. "shares its sense", #b.wnParse(WN, "light") < 6,
          #b.wnParse(WN, "light"))
end

-- BREAK D — remove the generation guard. The stale answer lands.
do
    local broken = src:gsub("if mine ~= d%.gen then", "if false then", 1)
    check("BREAK D changed the source", broken ~= src)
    local b = build(broken, "broken-D")
    b.cache, b.cacheOrder = {}, {}
    TASKS = {}
    local drawn = {}
    b.lookup("terse", function(r) drawn[#drawn + 1] = r end)
    local terseTask = TASKS[1]
    b.lookup("laconic", function(r) drawn[#drawn + 1] = r end)
    TASKS[2].cb(0, "\nOverview of adj laconic\n\n1. laconic, curt -- (brief)\n")
    terseTask.cb(0, WN)
    check("🔨 BREAK D caught: the abandoned lookup repaints the panel, and "
          .. "⏎ would type the wrong word into your document",
          #drawn == 2 and drawn[2].word == "terse",
          #drawn .. "/" .. tostring(drawn[2] and drawn[2].word))
end

-- BREAK E — stop turning underscores into spaces.
do
    local broken = src:gsub('s = tostring%(s or ""%):gsub%("_", " "%)',
                            's = tostring(s or "")', 1)
    check("BREAK E changed the source", broken ~= src)
    local b = build(broken, "broken-E")
    local s = b.wnParse(WN, "light")
    check("🔨 BREAK E caught: light_up would be typed into your sentence",
          (function()
              for _, syn in ipairs(s[6].synonyms) do
                  if syn == "light_up" then return true end
              end
              return false
          end)(), table.concat(s[6].synonyms, "|"))
end

-- BREAK F — let a provider be heard twice.
do
    local broken = src:gsub("if answered then return end\n", "", 1)
    check("BREAK F changed the source", broken ~= src)
    local b = build(broken, "broken-F")
    b.cache, b.cacheOrder = {}, {}
    local calls = 0
    b.providers = { { id = "f", label = "F", available = function() return true end,
                      why = function() return "" end,
                      lookup = function(w, done)
                          done({ { pos = "n", gloss = "g", synonyms = { "x" } } })
                          done({ { pos = "n", gloss = "h", synonyms = { "y" } } })
                      end } }
    b.lookup("thing", function() calls = calls + 1 end)
    check("🔨 BREAK F caught: the panel is repainted under you", calls == 2, calls)
end

-- BREAK G — cache a word nobody could define. Install WordNet afterwards
-- and the word stays broken until you reload.
do
    local broken = src:gsub("if not senses or #senses == 0 then tryNext%(%) return end",
                            "if not senses then senses = {} end", 1)
    check("BREAK G changed the source", broken ~= src)
    local b = build(broken, "broken-G")
    b.cache, b.cacheOrder = {}, {}
    TASKS = {}
    b.lookup("frobnicate", function() end)
    TASKS[1].cb(1, "")
    check("🔨 BREAK G caught: an empty answer is remembered as the truth",
          b.cache["frobnicate"] ~= nil)
end

-- =====================================================================
print = REALPRINT
io.write("\n")
if fail > 0 then
    io.write("FAILURES:\n")
    for _, f2 in ipairs(failures) do io.write("   ❌ " .. f2 .. "\n") end
end
io.write(("── test_define: %d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
