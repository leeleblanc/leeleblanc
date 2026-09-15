-- =====================================================================
-- MODULE: TEXT CASE — the six cases, defined once, used in two places
-- =====================================================================
-- LL: "I need a way to Change/Transform Text Case — upper, lower, title,
--      camel, kebab, or snake. I think I have something already to pick
--      out and transform file names, can we add this to that tool?"
--
-- Yes and no, and the "no" half is the reason this file exists.
--
-- ⇪R (bulk rename) transforms FILE NAMES. It walks a Finder selection,
-- groups sidecars, checks for collisions and calls os.rename. It cannot
-- touch the sentence you have highlighted in an email, because there is
-- no file there to rename. So the case rules went in ⇪R as asked — all
-- six of them — and the same six also went on ⇪; (power tools) for text
-- you have selected anywhere on the Mac.
--
-- 🚨 WHICH MEANT THE RULES COULD NOT LIVE IN EITHER OF THEM. Two copies
-- of "what is a word?" is two copies that drift, and the drift is silent:
-- ⇪R would snake_case a file one way and ⇪; would snake_case the same
-- text another way, and nothing anywhere would report a problem. So the
-- six cases are DEFINED HERE, once, and both tools ask for them.
--
--        (no key of its own — nothing to press, nothing to see)
--        ⇪;  →  Change the case of the selection
--        ⇪R  →  UPPERCASE · lowercase · Title · camel · kebab · snake
--
-- 🔌 LOAD ORDER DOES NOT MATTER. Both consumers reach this through
-- core.call at the moment you press the key, not at setup — so this can
-- load before or after either of them. It sits between them in the module
-- list only because that is where a reader will look for it.
--
-- ---------------------------------------------------------------------
-- 🔤 THE TWO KINDS OF CASE, AND WHY THEY BEHAVE DIFFERENTLY
-- ---------------------------------------------------------------------
-- These six are not six variations of one idea. They are two ideas:
--
--   UPPER · lower · Title      KEEP THE TEXT'S SHAPE. Every space, comma,
--                              hyphen and line break stays exactly where
--                              it was; only the letters change.
--
--   camel · kebab · snake      REBUILD THE TEXT FROM ITS WORDS. The
--                              punctuation is not preserved because it is
--                              the thing being replaced — the separator IS
--                              the case. These three make identifiers.
--
-- That is why `Hello, world!` becomes `HELLO, WORLD!` under upper and
-- `hello-world` under kebab. The comma and the bang are not lost by
-- accident; a kebab-case identifier cannot contain them.
--
-- ⚠️ AND WHY THAT IS WORTH SAYING OUT LOUD: the second group is lossy.
-- Running camelCase over a paragraph and pressing ⏎ is not undoable from
-- inside this config. The ⇪; row shows you the result of all six against
-- YOUR OWN TEXT before you choose one, which is the only real protection
-- against picking the wrong one — a sample of "hello world" tells you
-- nothing about what will happen to the thing you actually highlighted.
--
-- ---------------------------------------------------------------------
-- ✂️ WHAT COUNTS AS A WORD (tc.tokens) — the whole of the hard part
-- ---------------------------------------------------------------------
-- camel, kebab and snake all need the same answer: where do the words
-- start? Three rules, applied in order:
--
--   1. Split on every run of punctuation and space.  a-b_c  →  a b c
--   2. Split at a lower-or-digit followed by an upper. fooBar → foo Bar,
--      and iPhone14Pro → i Phone14 Pro, which is why that rule includes
--      digits: without it you get "iphone14pro" back.
--   3. Split an acronym off the word behind it: UPPER UPPER lower means
--      the last upper starts a new word. XMLHttpRequest → XML Http Request.
--
-- 🚨 A BYTE ABOVE 127 IS PART OF A WORD. Lua's %w is ASCII-only in the C
-- locale, so a plain [%w]+ run pattern treats the two bytes of "é" as
-- punctuation and DROPS THEM: café would come out of snake_case as
-- "caf". Not mangled, not flagged — gone. The run pattern therefore
-- carries \128-\255 explicitly, and the accented letter travels through
-- as itself.
--
-- ⚠️ UPPER AND LOWER ARE ASCII-ONLY, AND THAT IS THE SAFE FAILURE.
-- string.upper works a byte at a time, so it changes a-z and leaves é
-- alone rather than corrupting it. `café` uppercases to `CAFé`. Doing
-- better needs Unicode case mapping tables, which is a real library; a
-- letter left alone is a visible, obvious, harmless miss, and a letter
-- turned into two wrong bytes is a corrupted file name.
--
-- ⚠️ TITLE CASE HERE IS START CASE: every word is capitalised, including
-- "of" and "the". Real title case needs a stop-word list plus rules about
-- the first and last word, and gets them wrong often enough to be worse
-- than the simple version. This is the rule ⇪R has used since 6.48.0 and
-- it has not moved — it moved HOUSE, into this file, so that ⇪; agrees
-- with it by construction.
--
-- ---------------------------------------------------------------------
-- ↩️ LINE BY LINE, ALWAYS
-- ---------------------------------------------------------------------
-- The rebuilding three run once per line and the lines are put back with
-- their breaks intact. Select a list of eight things, choose snake_case,
-- and you get eight snake_case lines — not one 200-character identifier
-- with the whole list welded into it. A line with no word characters in
-- it at all (a `---` separator, a blank line) is returned untouched.
-- =====================================================================

local M = {
    name  = "Text Case",
    -- 13.985 sits between ⇪; (13.98) and its next neighbour. Not 13.99:
    -- tab_search holds that, and a TIE makes the cheat sheet's running
    -- order depend on table iteration. test_integration fails on ties for
    -- exactly that reason, and it caught this one.
    order = 13.985,
    family = "text",
    cheatsheet = {
        title = "🔠 TEXT CASE (no key — it answers for ⇪; and ⇪R)",
        entries = {
            -- 🔑 "in ⇪;" and "via ⇪R", not the bare keys: power_tools owns
            -- ⇪; and bulk_rename owns ⇪R, and the sheet is grouped by
            -- family — a bare key here would render the same tool twice in
            -- two different bands. See the one-owner audit in
            -- tests/test_diagnostics.lua.
            { "in ⇪;",  "Change the case of the selection — previews all six" },
            { "via ⇪R", "The same six as bulk-rename rules, for file names" },
            { "keeps", "UPPER · lower · Title keep every space and comma" },
            { "makes", "camel · kebab · snake rebuild the text from its words" },
            { "check", "_G.caseReport() — the six, run against a sample" },
        },
    },
}

function M.setup(core)
    local tc = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    tc.enabled = true
    -- The string every row's example is COMPUTED from. Nothing in this file
    -- stores a hand-written example: a hand-written "helloWorld" beside a
    -- camelCase implementation that has since changed is a lie in a picker,
    -- and the picker is where people decide which one to press.
    tc.sample  = "two words-here"
    -- ✏️ UTF-8 PUNCTUATION THAT SEPARATES WORDS. Everything else above
    -- byte 127 is treated as a letter, which is what keeps café whole —
    -- but an em dash is above 127 too, and `this—that` is two words in
    -- every language that uses one. Rather than guess from the bytes,
    -- the separators are named. Adding to this list is safe; taking the
    -- accented letters out is not, and there is nothing to take out.
    tc.separators = {
        "\226\128\147",  -- – en dash
        "\226\128\148",  -- — em dash
        "\226\128\146",  -- ‒ figure dash
        "\226\128\149",  -- ― horizontal bar
        "\226\128\152",  -- ‘ left single quote
        "\226\128\153",  -- ’ right single quote / curly apostrophe
        "\226\128\156",  -- “ left double quote
        "\226\128\157",  -- ” right double quote
        "\226\128\166",  -- … ellipsis
        "\226\128\162",  -- • bullet
        "\226\128\139",  -- zero-width space
        "\194\160",      -- non-breaking space
        "\194\183",      -- · middle dot
        "\194\171",      -- « guillemet
        "\194\187",      -- » guillemet
    }
    -- ----------------------------------------------------------------------

    tc.lastId, tc.lastIn, tc.lastOut = nil, nil, nil
    tc.applied = 0

    local function say(m) if _G.diag then _G.diag.say("textCase", m) end end

    -- =====================================================================
    -- ✂️ WORDS
    -- =====================================================================
    -- See the header. \128-\255 is in the run class on purpose; taking it
    -- out silently deletes every accented letter.
    -- The named separators become plain spaces before anything is split.
    -- 🚨 ONLY tokens() CALLS THIS. The three shape-keeping cases must never
    -- touch it: turning a curly apostrophe into a space inside UPPERCASE
    -- would edit the text rather than case it, which is the one thing
    -- those three promise not to do.
    function tc.normalise(s)
        s = tostring(s or "")
        for _, sep in ipairs(tc.separators) do s = s:gsub(sep, " ") end
        return s
    end

    function tc.tokens(s)
        s = tc.normalise(s)
        local out = {}
        for run in s:gmatch("[%w\128-\255]+") do
            -- \1 is the marker because it cannot occur in text a human
            -- selected. Three passes, in the order the header lists them.
            local marked = run:gsub("(%l)(%u)", "%1\1%2")
                              :gsub("(%d)(%u)", "%1\1%2")
                              :gsub("(%u)(%u%l)", "%1\1%2")
            for part in marked:gmatch("[^\1]+") do
                out[#out + 1] = part
            end
        end
        return out
    end

    -- Split on \n and put it back with concat, rather than a gmatch that
    -- can match the empty string: "a\n" must come back as "a\n" and not as
    -- "a", and an off-by-one there eats the blank line at the end of
    -- everything anybody ever selects out of a document.
    function tc.lines(s)
        s = tostring(s or "")
        local out, i = {}, 1
        while true do
            local j = s:find("\n", i, true)
            if not j then out[#out + 1] = s:sub(i) break end
            out[#out + 1] = s:sub(i, j - 1)
            i = j + 1
        end
        return out
    end

    local function perLine(s, fn)
        local ls = tc.lines(s)
        for i, line in ipairs(ls) do ls[i] = fn(line) end
        return table.concat(ls, "\n")
    end

    -- =====================================================================
    -- 🔤 THE THREE THAT KEEP THE SHAPE
    -- =====================================================================
    function tc.upper(s) return (tostring(s or ""):upper()) end
    function tc.lower(s) return (tostring(s or ""):lower()) end

    -- Start case: every word, including "of" and "the". See the header for
    -- why this does not try to be cleverer. `%w'` in the tail keeps
    -- "don't" one word instead of turning it into "Don'T".
    function tc.title(s)
        return (tostring(s or ""):gsub("([%a][%w']*)", function(w)
            return w:sub(1, 1):upper() .. w:sub(2):lower()
        end))
    end

    -- =====================================================================
    -- 🔧 THE THREE THAT REBUILD FROM WORDS
    -- =====================================================================
    -- A line with no word characters in it is returned as it came in. That
    -- is what keeps a `---` separator and a blank line intact in the middle
    -- of a selected list.
    local function joined(sep, capitalise)
        return function(s)
            return perLine(s, function(line)
                local t = tc.tokens(line)
                if #t == 0 then return line end
                local out = {}
                for i, w in ipairs(t) do
                    w = w:lower()
                    -- camelCase only. With no separator between the words,
                    -- the capital IS the separator — which is also why the
                    -- first word does not get one.
                    if capitalise and i > 1 then
                        w = w:sub(1, 1):upper() .. w:sub(2)
                    end
                    out[#out + 1] = w
                end
                return table.concat(out, sep)
            end)
        end
    end

    tc.camel = joined("",  true)
    tc.kebab = joined("-", false)
    tc.snake = joined("_", false)

    -- =====================================================================
    -- THE LIST
    -- =====================================================================
    -- ✏️ To add one: copy a row. `id` is what both pickers pass back and
    -- what _G.caseReport() counts by, so keep it stable. `keeps` is not
    -- decoration — it is how the ⇪; row explains, in the picker, that
    -- three of these will drop your punctuation.
    tc.cases = {
        { id = "upper", label = "UPPERCASE",  keeps = true,  fn = function(s) return tc.upper(s) end },
        { id = "lower", label = "lowercase",  keeps = true,  fn = function(s) return tc.lower(s) end },
        { id = "title", label = "Title Case", keeps = true,  fn = function(s) return tc.title(s) end },
        { id = "camel", label = "camelCase",  keeps = false, fn = function(s) return tc.camel(s) end },
        { id = "kebab", label = "kebab-case", keeps = false, fn = function(s) return tc.kebab(s) end },
        { id = "snake", label = "snake_case", keeps = false, fn = function(s) return tc.snake(s) end },
    }

    function tc.byId(id)
        for _, c in ipairs(tc.cases) do
            if c.id == id then return c end
        end
        return nil
    end

    -- apply(id, text) -> newText, nil   or   nil, why
    -- Never returns a half-transformed string: a case function that throws
    -- gives back the reason and the caller keeps the original, which for
    -- ⇪R means the file is not renamed and for ⇪; means nothing is typed.
    function tc.apply(id, text)
        local c = tc.byId(id)
        if not c then return nil, "no such case: " .. tostring(id) end
        local ok, out = pcall(c.fn, text)
        if not (ok and type(out) == "string") then
            return nil, tostring(id) .. " failed: " .. tostring(out)
        end
        tc.applied = tc.applied + 1
        tc.lastId, tc.lastIn, tc.lastOut = id, text, out
        return out, nil
    end

    -- What the pickers draw themselves from. `example` is COMPUTED — see
    -- tc.sample. The table is rebuilt on every call so a picker cannot
    -- hold a reference and mutate the source of truth.
    function tc.list()
        local out = {}
        for _, c in ipairs(tc.cases) do
            local ok, ex = pcall(c.fn, tc.sample)
            out[#out + 1] = {
                id      = c.id,
                label   = c.label,
                keeps   = c.keeps,
                example = (ok and type(ex) == "string") and ex or tc.sample,
            }
        end
        return out
    end

    -- ---- the report ------------------------------------------------------
    function _G.caseReport()
        local L = { "🔠 TEXT CASE — the six, run against \"" .. tc.sample .. "\"" }
        for _, c in ipairs(tc.list()) do
            L[#L + 1] = ("   %-12s %-22s %s")
                        :format(c.id, c.example,
                                c.keeps and "keeps spacing and punctuation"
                                         or "rebuilds from words")
        end
        L[#L + 1] = ("   applied      : %d time%s this session")
                    :format(tc.applied, tc.applied == 1 and "" or "s")
        if tc.lastId then
            local function short(s)
                s = tostring(s or ""):gsub("%s+", " ")
                if #s > 46 then s = s:sub(1, 45) .. "…" end
                return s
            end
            L[#L + 1] = "   last         : " .. tc.lastId
            L[#L + 1] = "      in        : " .. short(tc.lastIn)
            L[#L + 1] = "      out       : " .. short(tc.lastOut)
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if tc.enabled then
        say("six cases published")
    end
    core.provide("case.apply",  function(id, s) return tc.apply(id, s) end)
    core.provide("case.list",   function() return tc.list() end)
    core.provide("case.tokens", function(s) return tc.tokens(s) end)
    core.provide("case.report", function() return _G.caseReport() end)

    _G.textCase = tc
    M.tc     = tc
    M.config = tc
end

return M
