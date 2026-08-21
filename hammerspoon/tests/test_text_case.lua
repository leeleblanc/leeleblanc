-- =====================================================================
-- test_text_case.lua — the six cases, and the one definition of a word
-- =====================================================================
--     lua5.4 test_text_case.lua [/path/to/hammerspoon]
--
-- Executes modules/text_case.lua. There is no Mac in this module — no
-- eventtap, no chooser, no clipboard — so the stub below is three lines
-- and every check is a pure question about a string.
--
-- FOUR SECTIONS HAVE TEETH:
--
--   §1 A BYTE ABOVE 127 IS PART OF A WORD. Lua's %w is ASCII-only, so a
--      plain [%w]+ run pattern treats the two bytes of "é" as
--      punctuation and DROPS THEM — café comes out of snake_case as
--      "caf", silently. BREAK A is exactly that regression.
--
--   §3 THE REBUILDING CASES RUN PER LINE. Select eight lines, choose
--      snake_case, and you must get eight snake_case lines rather than
--      one 200-character identifier with the whole list welded into it.
--      BREAK E welds it.
--
--   §4 THE PICKER'S EXAMPLES ARE COMPUTED. A hand-written "helloWorld"
--      beside a camelCase implementation that has since changed is a lie
--      in the one place people decide which row to press. BREAK F makes
--      it hand-written and the lie appears immediately.
--
--   §7 NOTHING ELSE DEFINES A CASE. The whole reason this file exists is
--      that ⇪; and ⇪R were about to own one copy each. The sentries read
--      power_tools.lua and bulk_rename.lua and fail if either grows its
--      own :upper() rule again.

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

_G.diag = { say = function() end, warn = function() end, err = function() end }

local PROVIDED = {}
local CORE = { provide = function(n, f) PROVIDED[n] = f end }

local f = assert(io.open(HS .. "/modules/text_case.lua", "r"))
local src = f:read("*a") ; f:close()

local chunk = assert(loadfile(HS .. "/modules/text_case.lua"))
local M = chunk()
M.setup(CORE)
local tc = _G.textCase

-- =====================================================================
section("1. ✂️ what counts as a word")
-- =====================================================================
local function toks(s) return table.concat(tc.tokens(s), "|") end

check("plain words split on the space", toks("two words") == "two|words",
      toks("two words"))
check("punctuation of every kind is a boundary",
      toks("a-b_c.d/e f") == "a|b|c|d|e|f", toks("a-b_c.d/e f"))
check("a camel hump is a boundary", toks("fooBarBaz") == "foo|Bar|Baz",
      toks("fooBarBaz"))
check("a digit before a capital is a boundary — without it iPhone14Pro "
      .. "comes back as iphone14pro",
      toks("iPhone14Pro") == "i|Phone14|Pro", toks("iPhone14Pro"))
check("an acronym splits off the word behind it",
      toks("XMLHttpRequest") == "XML|Http|Request", toks("XMLHttpRequest"))
check("…and an acronym on its own stays whole",
      toks("XML") == "XML", toks("XML"))
check("runs of punctuation collapse rather than making empty words",
      toks("a  --  b") == "a|b", toks("a  --  b"))
check("nothing but punctuation is no words at all",
      #tc.tokens("--- ...") == 0, #tc.tokens("--- ..."))
check("the empty string is no words at all", #tc.tokens("") == 0)
check("nil is no words at all, and does not throw", #tc.tokens(nil) == 0)

-- 🚨 THE ONE THAT SILENTLY DELETES TEXT. See the header.
check("🚨 an accented letter survives tokenising",
      toks("café society") == "café|society", toks("café society"))
check("🚨 …and survives snake_case, rather than becoming caf_society",
      tc.snake("café society") == "café_society", tc.snake("café society"))
-- ⚠️ AND THE OTHER HALF OF THE SAME RULE. An em dash is above 127 too,
-- so "everything above 127 is a letter" would weld `this—that` into one
-- word. The separators are named rather than guessed at; see tc.separators.
check("🚨 an em dash is a separator, not a word",
      toks("this—that") == "this|that", toks("this—that"))
check("🚨 …and so is an en dash", toks("a–b") == "a|b", toks("a–b"))
check("a curly apostrophe splits the same way an ASCII one does — an "
      .. "identifier cannot hold either",
      toks("don’t stop") == toks("don't stop"),
      toks("don’t stop") .. " vs " .. toks("don't stop"))
check("a curly quote does not become part of the word",
      tc.kebab("“hello world”") == "hello-world", tc.kebab("“hello world”"))
check("a non-breaking space separates like a real one",
      toks("a\194\160b") == "a|b", toks("a\194\160b"))
check("🚨 normalising is for tokens ONLY — UPPERCASE does not rewrite "
      .. "your punctuation", tc.upper("don’t") == "DON’T", tc.upper("don’t"))

-- =====================================================================
section("2. 🔤 the three that keep the text's shape")
-- =====================================================================
check("upper", tc.upper("Hello, world!") == "HELLO, WORLD!",
      tc.upper("Hello, world!"))
check("lower", tc.lower("Hello, World!") == "hello, world!",
      tc.lower("Hello, World!"))
check("title", tc.title("hello there, world") == "Hello There, World",
      tc.title("hello there, world"))
check("title lowercases the tail of a SHOUTED word",
      tc.title("HELLO WORLD") == "Hello World", tc.title("HELLO WORLD"))
check("title keeps an apostrophe inside one word — not Don'T",
      tc.title("don't stop") == "Don't Stop", tc.title("don't stop"))
-- The whole point of the "keeps" half: nothing about the spacing moves.
check("🚨 upper keeps every space, comma and line break exactly",
      tc.upper("a, b\n  c") == "A, B\n  C",
      (tc.upper("a, b\n  c"):gsub("\n", "\\n")))
check("🚨 title keeps them too", tc.title("a, b\n  c") == "A, B\n  C",
      (tc.title("a, b\n  c"):gsub("\n", "\\n")))
-- ⚠️ ASCII-only, and the failure is a letter left alone rather than a
-- letter turned into two wrong bytes. See the module header.
check("⚠️ upper leaves an accented letter alone rather than mangling it",
      tc.upper("café") == "CAFé", tc.upper("café"))
check("nil does not throw", tc.upper(nil) == "" and tc.lower(nil) == ""
      and tc.title(nil) == "")

-- =====================================================================
section("3. 🔧 the three that rebuild from words")
-- =====================================================================
check("camel", tc.camel("two words-here") == "twoWordsHere",
      tc.camel("two words-here"))
check("kebab", tc.kebab("two words-here") == "two-words-here",
      tc.kebab("two words-here"))
check("snake", tc.snake("two words-here") == "two_words_here",
      tc.snake("two words-here"))
check("🚨 camel does NOT capitalise the first word — that would be Pascal",
      tc.camel("hello world"):sub(1, 1) == "h", tc.camel("hello world"))
check("camel flattens a SHOUTED word instead of keeping it shouted",
      tc.camel("HELLO WORLD") == "helloWorld", tc.camel("HELLO WORLD"))
check("the rebuilding three drop punctuation, because the separator IS "
      .. "the case", tc.kebab("Hello, world!") == "hello-world",
      tc.kebab("Hello, world!"))
check("an existing snake_case round-trips to camelCase",
      tc.camel("read_the_file") == "readTheFile", tc.camel("read_the_file"))
check("…and back again", tc.snake("readTheFile") == "read_the_file",
      tc.snake("readTheFile"))

-- 🚨 PER LINE. A selected list must come back as a list.
local list = "First Item\nSecond Item\nThird Item"
check("🚨 snake_case of three lines is three lines",
      tc.snake(list) == "first_item\nsecond_item\nthird_item",
      (tc.snake(list):gsub("\n", "\\n")))
check("🚨 …and camelCase of three lines is three lines",
      tc.camel(list) == "firstItem\nsecondItem\nthirdItem",
      (tc.camel(list):gsub("\n", "\\n")))
check("a line with no word characters is returned untouched",
      tc.snake("one\n---\ntwo") == "one\n---\ntwo",
      (tc.snake("one\n---\ntwo"):gsub("\n", "\\n")))
check("a blank line stays a blank line",
      tc.kebab("a\n\nb") == "a\n\nb", (tc.kebab("a\n\nb"):gsub("\n", "\\n")))

-- 🚨 tc.lines: the trailing newline is the off-by-one everybody writes.
check("lines splits", #tc.lines("a\nb\nc") == 3, #tc.lines("a\nb\nc"))
check("🚨 a trailing newline is a real, empty, final line",
      #tc.lines("a\n") == 2, #tc.lines("a\n"))
check("🚨 …so text ending in a newline still ends in one afterwards",
      tc.snake("Some Words\n") == "some_words\n",
      (tc.snake("Some Words\n"):gsub("\n", "\\n")))
check("no newline at all is one line", #tc.lines("a") == 1)
check("the empty string is one empty line", #tc.lines("") == 1)

-- =====================================================================
section("4. THE LIST — six, ordered, and the examples are computed")
-- =====================================================================
check("six cases", #tc.cases == 6, #tc.cases)
do
    local order = {}
    for _, c in ipairs(tc.cases) do order[#order + 1] = c.id end
    check("in the order both pickers draw",
          table.concat(order, ",") == "upper,lower,title,camel,kebab,snake",
          table.concat(order, ","))
end
check("the shape-keeping three say so", tc.byId("upper").keeps == true
      and tc.byId("lower").keeps == true and tc.byId("title").keeps == true)
check("…and the rebuilding three say so", tc.byId("camel").keeps == false
      and tc.byId("kebab").keeps == false and tc.byId("snake").keeps == false)
check("byId on a name that is not there returns nil",
      tc.byId("pascal") == nil)

do
    local L = tc.list()
    check("list() gives all six", #L == 6, #L)
    -- 🚨 COMPUTED, NOT WRITTEN DOWN. Each example must be that case's own
    -- function applied to tc.sample — see BREAK F.
    local okAll = true
    for _, row in ipairs(L) do
        local want = tc.byId(row.id).fn(tc.sample)
        if row.example ~= want then okAll = false end
    end
    check("🚨 every example is the case applied to tc.sample", okAll)
    check("…so the camel example really is camelCase",
          L[4].example == "twoWordsHere", L[4].example)
    -- A picker must not be able to reach in and edit the source of truth.
    L[1].label = "vandalised"
    check("list() hands back a fresh table each call",
          tc.list()[1].label == "UPPERCASE", tc.list()[1].label)
end

-- =====================================================================
section("5. apply — and what happens when it cannot")
-- =====================================================================
do
    local out, why = tc.apply("kebab", "Two Words")
    check("apply returns the text", out == "two-words", out)
    check("…and no reason", why == nil)
end
do
    local out, why = tc.apply("pascal", "Two Words")
    check("🚨 an unknown case returns nil, not the original text — a caller "
          .. "cannot tell 'unchanged' from 'no such case'", out == nil)
    check("…and names it", tostring(why):find("pascal") ~= nil, why)
end
do
    -- A case function that throws must come back as a reason, not as an
    -- error out of ⇪R in the middle of renaming a hundred files.
    local keep = tc.byId("upper").fn
    tc.byId("upper").fn = function() error("boom", 0) end
    local out, why = tc.apply("upper", "x")
    check("a throwing case is caught", out == nil)
    check("…and the reason carries the throw",
          tostring(why):find("boom") ~= nil, why)
    tc.byId("upper").fn = keep
end
do
    local before = tc.applied
    tc.apply("lower", "ABC")
    check("apply counts", tc.applied == before + 1, tc.applied)
    check("…and remembers what it did", tc.lastId == "lower"
          and tc.lastOut == "abc", tostring(tc.lastId) .. "/" .. tostring(tc.lastOut))
end
do
    local before = tc.applied
    tc.apply("nope", "ABC")
    check("a refused apply does NOT count", tc.applied == before, tc.applied)
end

-- =====================================================================
section("6. the services, and the report")
-- =====================================================================
check("case.apply is published", PROVIDED["case.apply"] ~= nil)
check("case.list is published", PROVIDED["case.list"] ~= nil)
check("case.tokens is published", PROVIDED["case.tokens"] ~= nil)
check("case.report is published", PROVIDED["case.report"] ~= nil)
check("case.apply through the service is the same answer",
      PROVIDED["case.apply"]("snake", "Two Words") == "two_words")
check("case.list through the service has six rows",
      #PROVIDED["case.list"]() == 6)

do
    local r = _G.caseReport()
    check("the report names every case", r:find("upper") and r:find("lower")
          and r:find("title") and r:find("camel") and r:find("kebab")
          and r:find("snake") ~= nil)
    check("…shows the sample it ran them against",
          r:find(tc.sample, 1, true) ~= nil)
    check("…shows a computed example beside each",
          r:find("two_words_here", 1, true) ~= nil)
    check("…says which ones keep your punctuation",
          r:find("keeps spacing and punctuation") ~= nil)
    check("…and which rebuild", r:find("rebuilds from words") ~= nil)
    check("…and how many have run", r:find("applied") ~= nil)
    tc.apply("kebab", "Some Long Thing")
    local r2 = _G.caseReport()
    check("the last transform is shown, in and out",
          r2:find("some%-long%-thing") ~= nil, r2)
end

-- =====================================================================
section("7. 🚨 nothing else defines a case")
-- =====================================================================
-- The whole reason this module exists. If either consumer grows its own
-- :upper() rule again, the two definitions drift and nothing reports it.
local function read(p)
    local h = assert(io.open(HS .. p, "r"))
    local s = h:read("*a") ; h:close()
    return s
end
local ptSrc = read("/modules/power_tools.lua")
local brSrc = read("/modules/bulk_rename.lua")

check("🚨 bulk_rename defines no case function of its own — it delegates",
      brSrc:find('br%.rules%.lower%s*=%s*{') == nil, "br.rules.lower = { ... }")
check("🚨 …and every case rule it declares goes through case.apply",
      brSrc:find('case%.apply') ~= nil)
check("🚨 …and marks itself `case` so br.plan can refuse without an engine",
      brSrc:find('case%s*=%s*id') ~= nil)
check("🚨 br.plan refuses a case rule when the engine is missing",
      brSrc:find('rule%.case and not') ~= nil)
check("all six are offered by ⇪R", (function()
    for _, id in ipairs({ "upper", "lower", "title", "camel", "kebab", "snake" }) do
        if not brSrc:find('br%.rules%.' .. id .. '%s*=%s*caseRule') then return false end
    end
    return true
end)())
check("…and all six are in the picker's order list", (function()
    local order = brSrc:match('local order = {(.-)}') or ""
    for _, id in ipairs({ "upper", "lower", "title", "camel", "kebab", "snake" }) do
        if not order:find('"' .. id .. '"') then return false, order end
    end
    return true
end)())

check("🚨 power_tools defines no case function of its own",
      ptSrc:find("function pt%.camel") == nil
      and ptSrc:find("function pt%.snake") == nil
      and ptSrc:find("function pt%.kebab") == nil)
check("🚨 …it asks for the list rather than hardcoding six rows",
      ptSrc:find('case%.list') ~= nil)
check("🚨 …and asks for the transform rather than doing it",
      ptSrc:find('case%.apply') ~= nil)

-- The run class is load-bearing enough to be read out of the source: a
-- future tidy-up that "simplifies" it to [%w]+ deletes accented letters.
check("🚨 the run pattern still carries the high bytes",
      src:find("%[%%w\\128%-\\255%]%+") ~= nil,
      src:match("gmatch%(\"([^\"]+)\"%)") or "?")

-- =====================================================================
section("8. 🔨 break tests")
-- =====================================================================
-- Each one changes the source the way a plausible edit would, loads the
-- damaged module and asserts the damage shows up. A break test that a
-- real regression walks through is worse than no break test.
local function build(broken, name)
    local bchunk = assert(load(broken, name))
    local bm = bchunk()
    bm.setup({ provide = function() end })
    return _G.textCase
end

-- BREAK A — the run class loses its high bytes. This is the "simplify
-- the pattern" edit, and it deletes text without a word of complaint.
do
    local broken = src:gsub("%[%%w\\128%-\\255%]%+", "[%%w]+", 1)
    check("BREAK A changed the source", broken ~= src)
    local b = build(broken, "broken-A")
    check("🔨 BREAK A caught: the accented letter is deleted outright",
          b.snake("café society") == "caf_society", b.snake("café society"))
end

-- BREAK B — drop the digit-before-capital hump rule.
do
    local broken = src:gsub(':gsub%("%(%%d%)%(%%u%)", "%%1\\1%%2"%)\n', "\n", 1)
    check("BREAK B changed the source", broken ~= src)
    local b = build(broken, "broken-B")
    check("🔨 BREAK B caught: iPhone14Pro loses its last word",
          b.camel("iPhone14Pro") == "iPhone14pro", b.camel("iPhone14Pro"))
end

-- BREAK C — drop the acronym rule.
do
    local broken = src:gsub(':gsub%("%(%%u%)%(%%u%%l%)", "%%1\\1%%2"%)', "", 1)
    check("BREAK C changed the source", broken ~= src)
    local b = build(broken, "broken-C")
    -- The lower→upper rule still splits Http|Request, so the damage is
    -- narrower than "one word" — XML welds onto Http and nothing says so.
    check("🔨 BREAK C caught: the acronym welds onto the word behind it",
          b.snake("XMLHttpRequest") == "xmlhttp_request", b.snake("XMLHttpRequest"))
end

-- BREAK D — camel capitalises the first word too. That is PascalCase,
-- which is a different case with a different name, offered under this
-- one's label.
do
    local broken = src:gsub("if capitalise and i > 1 then",
                            "if capitalise then", 1)
    check("BREAK D changed the source", broken ~= src)
    local b = build(broken, "broken-D")
    check("🔨 BREAK D caught: camelCase turned into PascalCase",
          b.camel("hello world") == "HelloWorld", b.camel("hello world"))
end

-- BREAK E — the rebuilding cases stop running per line. A selected list
-- welds into one identifier, which is the single most destructive way
-- this module can be wrong: it is applied by typing over your selection.
do
    local broken = src:gsub("return perLine%(s, function%(line%)",
                            "return (function(line)", 1)
                      :gsub("            end%)\n        end\n    end\n\n    tc%.camel",
                            "            end)(s)\n        end\n    end\n\n    tc.camel", 1)
    check("BREAK E changed the source", broken ~= src)
    local b = build(broken, "broken-E")
    check("🔨 BREAK E caught: three lines weld into one identifier",
          b.snake(list):find("\n") == nil, (b.snake(list):gsub("\n", "\\n")))
end

-- BREAK F — the picker's examples are written down instead of computed,
-- so the row can advertise a transform the code no longer performs.
do
    local broken = src:gsub("example = %(ok and type%(ex%) == \"string\"%) "
                            .. "and ex or tc%.sample,",
                            'example = "helloWorld",', 1)
    check("BREAK F changed the source", broken ~= src)
    local b = build(broken, "broken-F")
    local L = b.list()
    local lies = 0
    for _, row in ipairs(L) do
        if row.example ~= b.byId(row.id).fn(b.sample) then lies = lies + 1 end
    end
    check("🔨 BREAK F caught: the picker advertises what it will not do",
          lies >= 5, lies)
end

-- BREAK G — tc.lines written the obvious way, with a gmatch that cannot
-- see a trailing newline. Every paragraph copied out of a document ends
-- in one, so this eats a line break on almost every real use.
do
    local broken = src:gsub(
        "local out, i = {}, 1\n        while true do.-\n        end\n        return out",
        "local out = {}\n        for l in s:gmatch(\"([^\\n]+)\") do "
        .. "out[#out + 1] = l end\n        if #out == 0 then out[1] = \"\" end"
        .. "\n        return out", 1)
    check("BREAK G changed the source", broken ~= src)
    local b = build(broken, "broken-G")
    check("🔨 BREAK G caught: the trailing newline is eaten",
          b.snake("Some Words\n") == "some_words",
          (b.snake("Some Words\n"):gsub("\n", "\\n")))
end

-- BREAK H — apply hands back the original text when the case is unknown,
-- instead of nil. ⇪; would then type the selection back over itself and
-- ⇪R would plan a rename to the name the file already has.
do
    local broken = src:gsub(
        'if not c then return nil, "no such case: " %.%. tostring%(id%) end',
        'if not c then return text, nil end', 1)
    check("BREAK H changed the source", broken ~= src)
    local b = build(broken, "broken-H")
    local out, why = b.apply("pascal", "Two Words")
    check("🔨 BREAK H caught: a typo in the id looks like a successful "
          .. "no-op", out == "Two Words" and why == nil, tostring(out))
end

-- =====================================================================
print = REALPRINT
io.write("\n")
if fail > 0 then
    io.write("FAILURES:\n")
    for _, f2 in ipairs(failures) do io.write("   ❌ " .. f2 .. "\n") end
end
io.write(("── test_text_case: %d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
