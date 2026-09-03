-- =====================================================================
-- MODULE: DEFINE (⇪8) — what it means and what else you could say
-- =====================================================================
-- LL: "I need a way to look up words for their definition and be
--      presented at the same time with their synonyms. How can we build
--      this?"
--
-- Put the cursor on a word, or select it, and press ⇪8. One list opens
-- holding both: every sense of the word with its definition, and under
-- each sense the words that share it. ⏎ on a synonym REPLACES YOUR
-- SELECTION with it.
--
--        ⇪8         define the selection — and its synonyms
--        ⇪;         the same, as a row
--
-- ---------------------------------------------------------------------
-- ❓ "MY MAC ALREADY DOES THIS — ⌃⌘D." IT DOES, AND IT IS NOT THIS.
-- ---------------------------------------------------------------------
-- Apple's Look Up popover is good and this does not replace it. Three
-- things it will not do, which are the three reasons this exists:
--
--   · The thesaurus is a SEPARATE ENTRY you scroll to or click into.
--     "At the same time" was the whole of the ask.
--   · You cannot act on it. Reading that `terse` is a synonym of `curt`
--     and then retyping it by hand is the part that wastes the time.
--   · In a good half of the apps here it wants the mouse — three-finger
--     tap, or right-click → Look Up.
--
-- So: same job, different shape. ⏎ on a row swaps the word.
--
-- ---------------------------------------------------------------------
-- 📚 WHERE THE WORDS COME FROM — and why it is a LIST of sources
-- ---------------------------------------------------------------------
-- There is no one source that is present on every Mac, offline, free,
-- and legally ours to read. There are four partial ones, so this asks
-- them in order and SAYS WHICH ONE ANSWERED.
--
--   1. WORDNET (`wn`, from `brew install wordnet`) — the default and the
--      best fit, not a compromise. Offline, one process, no network, and
--      its data model is exactly the thing that was asked for: a SENSE,
--      its definition, and the set of words that share that sense. Most
--      dictionaries make you infer that pairing. WordNet stores it.
--   2. THE WEB (dictionaryapi.dev) — definitions and synonyms per sense
--      in one keyless call. 🚨 OFF BY DEFAULT. See the note below.
--   3. DICTIONARY.APP — `open dict://word`. Always there, every Mac,
--      nothing to install, and it is Oxford rather than WordNet's terser
--      glosses. It is not in-panel, so it is the floor rather than the
--      answer — but a row that hands off to the thing that definitely
--      works beats a panel that says "nothing found".
--
-- 🚫 AND THE ONE THAT IS NOT HERE, DELIBERATELY: Apple's own dictionary
-- DATA. It is the best text on the machine and already licensed to you,
-- and it lives in Body.data — zlib-compressed chunks of Apple-schema XML
-- whose layout has changed across macOS releases. It is crackable
-- without Homebrew (macOS ships a Perl with zlib). It is not here
-- because a parser that breaks on a macOS update fails by handing you
-- GARBLED TEXT rather than by saying it cannot read the file, and this
-- config would rather refuse than lie. If it is ever written it becomes
-- provider 0 and nothing else in this file changes — which is most of
-- why the providers are a list at all.
--
-- ⚠️ WHY THE WEB PROVIDER IS OFF UNTIL YOU TURN IT ON. A lookup sends
-- the word you are writing about to somebody else's server. On the work
-- MacBook that is a sentence fragment leaving a managed machine, and the
-- proxy may eat the request anyway. The default therefore sends nothing
-- anywhere; d.allowNetwork = true is one edit, and _G.defineReport()
-- says the option exists whether or not you have taken it.
--
-- ---------------------------------------------------------------------
-- ⏱ EVERY LOOKUP IS ASYNC. THIS IS NOT A PREFERENCE.
-- ---------------------------------------------------------------------
-- 🚨 Hammerspoon has ONE thread, and it is the thread that reads your
-- keyboard. A synchronous `wn` or a synchronous fetch does not make the
-- panel slow — it stops your typing, in every app, for as long as it
-- takes. That is precisely the fault 6.131.0 built core/lag.lua to
-- measure, and shipping a new cause of it in the next release would be
-- a poor joke. hs.task and hs.http.asyncGet, always.
--
-- 🚨 AND A LATE ANSWER MUST NOT LAND IN THE WRONG WORD. Look up `terse`,
-- give up, look up `laconic`; `terse`'s reply arrives a second later and
-- repaints the open picker with terse's synonyms under laconic's title.
-- ⏎ then types the wrong word into your document, and everything on
-- screen agreed it was right. Every lookup therefore carries a
-- GENERATION number, and a reply whose generation is stale is dropped
-- without being drawn. See d.gen.
--
-- ---------------------------------------------------------------------
-- 🧩 THE SHAPE EVERY PROVIDER FILLS
-- ---------------------------------------------------------------------
-- The parsers are the testable part and the panel never learns which one
-- ran, because they all return this:
--
--     { word = "light", source = "WordNet", senses = {
--         { pos = "noun", gloss = "…", example = "…",
--           synonyms = { "visible light", "visible radiation" } }, … } }
--
-- Both parsers are pure functions of a string, so the suite drives them
-- from captured `wn` output and captured JSON with no Mac, no Homebrew
-- and no network anywhere in it.
--
-- ⚠️ THE WORD IS REMOVED FROM ITS OWN SYNONYM LIST. WordNet lists the
-- headword first in every synset, and a row whose ⏎ retypes the word you
-- already had reads as a broken tool rather than as a no-op. A sense
-- left with no synonyms KEEPS ITS DEFINITION ROW — "this sense has no
-- other words for it" is an answer, and dropping the sense would lose
-- the definition with it.
-- =====================================================================

local M = {
    name  = "Define",
    order = 13.986,      -- beside ⇪; (13.98) and text_case (13.985)
    family = "text",
    cheatsheet = {
        title = "📖 DEFINE (⇪8 — meaning and synonyms, together)",
        entries = {
            { "⇪8",     "Define the selection — senses, and the words that" },
            { "",       "share each one. ⏎ on a synonym swaps your word" },
            { "type",   "Nothing selected? Type a word in the box, ⏎ looks it up" },
            { "📕",     "Last row always opens it in Dictionary.app instead" },
            { "needs",  "brew install wordnet — offline, and the only source on" },
            { "",       "by default. Without it ⇪8 hands off to Dictionary.app" },
            { "check",  "_G.defineReport() — which sources this Mac has" },
        },
    },
}

function M.setup(core)
    local d = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    d.enabled      = true
    d.key          = "8"           -- ⇪8 (⇪⇧8 is free and stays free)
    d.keyMods      = {}
    -- 🌐 THE ONE THAT SENDS YOUR WORD SOMEWHERE ELSE. Off. See the header.
    d.allowNetwork = false
    d.apiURL       = "https://api.dictionaryapi.dev/api/v2/entries/en/"
    d.netTimeout   = 6             -- seconds before the fetch is abandoned
    d.wnTimeout    = 5             -- seconds before `wn` is abandoned
    d.maxSenses    = 40            -- a word like "set" has hundreds
    d.maxSynonyms  = 12            -- per sense, before the row list bloats
    d.cacheMax     = 60            -- words remembered this session
    d.glossChars   = 96            -- gloss shown on a row before it is cut
    d.dictScheme   = "dict://"     -- Dictionary.app's URL scheme
    -- ----------------------------------------------------------------------

    d.chooser   = nil     -- HELD: an unreferenced hs.chooser is collected
    d.task      = nil     -- HELD
    d.timer     = nil     -- HELD
    d.gen       = 0       -- see the header: a stale reply is never drawn
    d.cache     = {}      -- word -> result
    d.cacheOrder = {}
    d.lastResult = nil
    d.lastNote  = nil
    d.lookups   = 0
    d.swaps     = 0
    d.bySource  = {}      -- source name -> how many answers

    local function say(m)  if _G.diag then _G.diag.say("define", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("define", m) end end
    local function note(m) d.lastNote = m ; warn(m) end

    -- =====================================================================
    -- 🔎 FINDING wn — the same search the QR reader does for zbarimg
    -- =====================================================================
    -- 🚨 A HOMEBREW IN THE HOME DIRECTORY IS STILL A HOMEBREW. The work
    -- Mac has no admin rights, so brew lives under ~/ there and /opt/
    -- does not exist. Checking only the two admin paths would report
    -- "WordNet is not installed" on a machine where it is.
    d.WN_PATHS = function(home)
        return {
            "/opt/homebrew/bin/wn", "/usr/local/bin/wn",
            home .. "/homebrew/bin/wn", home .. "/.homebrew/bin/wn",
            home .. "/.local/homebrew/bin/wn", home .. "/bin/wn",
        }
    end

    function d.wnPath()
        if d._wn ~= nil then return d._wn or nil end
        local home = core.homeDir or os.getenv("HOME") or ""
        for _, p in ipairs(d.WN_PATHS(home)) do
            local sz
            pcall(function() sz = hs.fs.attributes(p, "size") end)
            if sz then d._wn = p return p end
        end
        d._wn = false
        return nil
    end

    -- 🚨 wn CANNOT FIND ITS OWN DATA IN SOME INSTALLS. The binary compiles
    -- in a default dictionary path; a relocated Homebrew (the home-dir
    -- one above, or an Intel prefix on Apple silicon) leaves that path
    -- pointing at nothing, and `wn` answers "Can't open dictionary" for
    -- every word — which looks exactly like "that word does not exist".
    -- WNSEARCHDIR is set when the data can be found beside the binary,
    -- and left alone when it cannot, because a wrong value is worse than
    -- no value.
    function d.wnSearchDir(binPath)
        local prefix = tostring(binPath or ""):match("^(.*)/bin/wn$")
        if not prefix then return nil end
        for _, sub in ipairs({ "/share/wordnet", "/opt/wordnet/dict",
                               "/share/wordnet/dict", "/dict" }) do
            local mode
            pcall(function() mode = hs.fs.attributes(prefix .. sub, "mode") end)
            if mode == "directory" then return prefix .. sub end
        end
        return nil
    end

    -- =====================================================================
    -- 📖 PARSING WordNet — a pure function of the text it printed
    -- =====================================================================
    -- `wn light -over` prints, per part of speech:
    --
    --     Overview of noun light
    --     The noun light has 10 senses (first 6 from tagged texts)
    --     1. (395) light, visible light -- ((physics) radiation …; "the …")
    --
    -- The frequency in the first parens is dropped: it is a corpus count,
    -- and a number nobody asked for on a row is a number in the way.
    local function tidySynonym(s)
        -- WordNet writes multi-word entries with underscores in some
        -- outputs and spaces in others. A row reading `light_up` is a row
        -- whose ⏎ types an underscore into your sentence.
        s = tostring(s or ""):gsub("_", " ")
        return (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end

    function d.wnParse(text, word)
        local senses = {}
        local pos = nil
        for line in tostring(text or ""):gmatch("[^\n]+") do
            local p = line:match("^Overview of (%a+)")
            if p then pos = p end
            local body = line:match("^%s*%d+%.%s+(.*)$")
            if body and pos then
                body = body:gsub("^%(%d+%)%s*", "")      -- the corpus count
                -- Split at the FIRST " -- ": a gloss may contain one, a
                -- synonym never can.
                local left, right = body:match("^(.-) %-%- (.*)$")
                if left then
                    local gloss = right:match("^%((.*)%)%s*$") or right
                    -- Examples are appended as ; "…". They are worth
                    -- keeping and worth keeping SEPARATE, because a row
                    -- shows the gloss and the example is the tooltip.
                    local core_, example = gloss:match('^(.-); "(.*)"%s*$')
                    if core_ then gloss = core_ end
                    if example then
                        example = example:gsub('"%s*;%s*"', " · ")
                    end
                    local syns = {}
                    for s in (left .. ","):gmatch("([^,]*),") do
                        s = tidySynonym(s)
                        -- The headword itself is dropped: see the header.
                        if s ~= "" and s:lower() ~= tostring(word or ""):lower() then
                            syns[#syns + 1] = s
                        end
                    end
                    senses[#senses + 1] = {
                        pos = pos, gloss = gloss, example = example,
                        synonyms = syns,
                    }
                end
            end
        end
        return senses
    end

    -- =====================================================================
    -- 🌐 PARSING dictionaryapi.dev — also a pure function
    -- =====================================================================
    -- Synonyms arrive at TWO levels: on the part of speech and on the
    -- individual definition. Both are real and neither is complete, so
    -- both are read and the result de-duplicated.
    function d.apiParse(decoded, word)
        local senses = {}
        if type(decoded) ~= "table" then return senses end
        for _, entry in ipairs(decoded) do
            if type(entry) == "table" and type(entry.meanings) == "table" then
                for _, meaning in ipairs(entry.meanings) do
                    local pos = tostring(meaning.partOfSpeech or "?")
                    local shared = {}
                    for _, s in ipairs(meaning.synonyms or {}) do
                        shared[#shared + 1] = s
                    end
                    for _, def in ipairs(meaning.definitions or {}) do
                        local syns, seen = {}, {}
                        local function add(s)
                            s = tidySynonym(s)
                            if s == "" or seen[s:lower()] then return end
                            if s:lower() == tostring(word or ""):lower() then return end
                            seen[s:lower()] = true
                            syns[#syns + 1] = s
                        end
                        for _, s in ipairs(def.synonyms or {}) do add(s) end
                        for _, s in ipairs(shared) do add(s) end
                        senses[#senses + 1] = {
                            pos = pos,
                            gloss = tostring(def.definition or ""),
                            example = def.example and tostring(def.example) or nil,
                            synonyms = syns,
                        }
                    end
                end
            end
        end
        return senses
    end

    -- =====================================================================
    -- THE PROVIDERS
    -- =====================================================================
    -- ✏️ To add one: copy a row. `available()` answers for THIS Mac and is
    -- what _G.defineReport() prints; `why` is the sentence shown when it
    -- is not — it must name the fix, because "no definition found" for a
    -- missing dependency is the lie this list exists to avoid.
    -- `lookup(word, done)` MUST be asynchronous and MUST call done exactly
    -- once, with senses or with nil.
    d.providers = {
        {
            id = "wordnet", label = "WordNet",
            available = function() return d.wnPath() ~= nil end,
            why = function()
                return "not installed — `brew install wordnet` turns this on, "
                       .. "and it works offline forever after"
            end,
            lookup = function(word, done)
                local bin = d.wnPath()
                if not bin then done(nil) return end
                local okNew, t = pcall(hs.task.new, bin, function(code, sout)
                    d.task = nil
                    if d.timer then
                        pcall(function() d.timer:stop() end) ; d.timer = nil
                    end
                    local senses = d.wnParse(sout, word)
                    if #senses == 0 then
                        -- code ~= 0 with no senses is "no such word", which
                        -- is a real answer and not an error.
                        say("wordnet had nothing for " .. tostring(word)
                            .. " (exit " .. tostring(code) .. ")")
                        done(nil)
                    else
                        done(senses)
                    end
                end, { word, "-over" })
                if not (okNew and t) then
                    note("could not run " .. bin)
                    done(nil)
                    return
                end
                local dir = d.wnSearchDir(bin)
                if dir then
                    pcall(function() t:setEnvironment({ WNSEARCHDIR = dir }) end)
                end
                d.task = t
                pcall(function() t:start() end)
                -- ⏳ A `wn` that never returns must not leave the picker
                -- saying "looking up…" forever.
                d.timer = hs.timer.doAfter(d.wnTimeout, function()
                    d.timer = nil
                    if d.task == t then
                        pcall(function() t:terminate() end)
                        d.task = nil
                        note("wn did not answer in " .. d.wnTimeout .. "s")
                        done(nil)
                    end
                end)
            end,
        },
        {
            id = "api", label = "dictionaryapi.dev",
            available = function() return d.allowNetwork == true end,
            why = function()
                return "OFF — it sends the word you looked up to somebody "
                       .. "else's server. Set d.allowNetwork = true to use it"
            end,
            lookup = function(word, done)
                if not d.allowNetwork then done(nil) return end
                local url = d.apiURL .. hs.http.encodeForQuery(word)
                local ok = pcall(function()
                    hs.http.asyncGet(url, nil, function(status, body)
                        if status ~= 200 or type(body) ~= "string" then
                            note("the dictionary API answered " .. tostring(status))
                            done(nil)
                            return
                        end
                        local okJson, decoded = pcall(hs.json.decode, body)
                        if not okJson then note("the API sent unreadable JSON") end
                        local senses = okJson and d.apiParse(decoded, word) or {}
                        done(#senses > 0 and senses or nil)
                    end)
                end)
                if not ok then note("could not start the fetch") ; done(nil) end
            end,
        },
    }

    function d.providerById(id)
        for _, p in ipairs(d.providers) do
            if p.id == id then return p end
        end
        return nil
    end

    -- =====================================================================
    -- 🔎 THE LOOKUP
    -- =====================================================================
    -- Providers in order until one answers. `done(result)` where result is
    -- the shape in the header, or nil when nobody could answer.
    --
    -- 🚨 THE GENERATION GUARD. See the header: a reply from a lookup you
    -- have moved on from must be dropped, not drawn.
    function d.lookup(word, done)
        word = tostring(word or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if word == "" then done(nil) return end
        local hit = d.cache[word:lower()]
        if hit then done(hit) return end

        d.gen = d.gen + 1
        local mine = d.gen
        d.lookups = d.lookups + 1

        local i = 0
        local function tryNext()
            i = i + 1
            local p = d.providers[i]
            if not p then
                if mine == d.gen then done(nil) end
                return
            end
            local okAvail, live = pcall(p.available)
            if not (okAvail and live) then tryNext() return end
            local answered = false
            local okRun = pcall(p.lookup, word, function(senses)
                -- MUST be called once; a provider that calls twice is a
                -- provider that repaints the picker under you.
                if answered then return end
                answered = true
                if mine ~= d.gen then
                    say("dropped a stale answer for " .. word)
                    return
                end
                if not senses or #senses == 0 then tryNext() return end
                local result = { word = word, source = p.label,
                                 senses = senses }
                d.remember(word, result)
                d.bySource[p.label] = (d.bySource[p.label] or 0) + 1
                d.lastResult = result
                done(result)
            end)
            if not okRun and not answered then
                answered = true
                note(p.id .. " threw during lookup")
                tryNext()
            end
        end
        tryNext()
    end

    function d.remember(word, result)
        local k = word:lower()
        if d.cache[k] == nil then
            d.cacheOrder[#d.cacheOrder + 1] = k
            -- Oldest out first. A cache that grows without limit in a
            -- config that runs for weeks is a slow leak.
            while #d.cacheOrder > d.cacheMax do
                local old = table.remove(d.cacheOrder, 1)
                d.cache[old] = nil
            end
        end
        d.cache[k] = result
    end

    -- =====================================================================
    -- THE ROWS
    -- =====================================================================
    -- One row per synonym, with the definition it belongs to as its
    -- subtext — which is what "definition and synonyms at the same time"
    -- has to mean if you are going to act on it. Every sense also gets a
    -- definition row of its own, so a sense with no synonyms still shows
    -- what the word means there.
    local function cut(s, n)
        s = tostring(s or ""):gsub("%s+", " ")
        if #s <= n then return s end
        return s:sub(1, n - 1) .. "…"
    end

    function d.rows(result)
        local out = {}
        if not (result and type(result.senses) == "table") then return out end
        local shown = 0
        for _, sense in ipairs(result.senses) do
            shown = shown + 1
            if shown > d.maxSenses then break end
            local pos = tostring(sense.pos or "?")
            local gloss = tostring(sense.gloss or "")
            out[#out + 1] = {
                text    = "📖  " .. pos .. " · " .. cut(gloss, 72),
                subText = sense.example and ("“" .. cut(sense.example, 96) .. "”")
                          or "definition — ⏎ copies it",
                kind    = "definition",
                payload = gloss,
                pos     = pos,
            }
            local n = 0
            for _, syn in ipairs(sense.synonyms or {}) do
                n = n + 1
                if n > d.maxSynonyms then break end
                out[#out + 1] = {
                    text    = "🔤  " .. syn,
                    subText = pos .. " · " .. cut(gloss, d.glossChars),
                    kind    = "synonym",
                    payload = syn,
                    pos     = pos,
                }
            end
        end
        return out
    end

    -- =====================================================================
    -- ⇪8
    -- =====================================================================
    -- The Dictionary.app row is ALWAYS last, answer or no answer. Even a
    -- good WordNet result is a terser gloss than Oxford's, and the escape
    -- hatch costs one row.
    function d.dictRow(word)
        return {
            text    = "📕  Open “" .. tostring(word) .. "” in Dictionary.app",
            subText = "Apple's own dictionary and thesaurus, in their window",
            kind    = "dictionary",
            payload = word,
        }
    end

    function d.openInDictionary(word)
        local ok = pcall(function()
            hs.urlevent.openURL(d.dictScheme .. hs.http.encodeForQuery(word))
        end)
        if not ok then
            note("could not open " .. d.dictScheme)
            hs.alert.show("📖 Could not open Dictionary.app", 3)
            return false
        end
        return true
    end

    function d.pick(choice)
        if not (choice and choice.kind) then return false end
        if choice.kind == "dictionary" then
            return d.openInDictionary(choice.payload)
        end
        if choice.kind == "definition" then
            local ok = pcall(function()
                hs.pasteboard.setContents(tostring(choice.payload))
            end)
            hs.alert.show(ok and "📖 Definition copied"
                             or  "📖 The clipboard refused it", 2.5)
            return ok
        end
        if choice.kind == "lookup" then
            d.show(choice.payload)
            return true
        end
        -- 🔤 a synonym. The guarded replace lives in power_tools and is
        -- reached through the service bus, so the secure-input check, the
        -- wait for ⌘⇧⌃⌥ and the length cap have exactly one home.
        if not (_G.service and _G.service.has
                and _G.service.has("power.replaceSelection")) then
            local ok = pcall(function()
                hs.pasteboard.setContents(tostring(choice.payload))
            end)
            note("power.replaceSelection has no provider — copied instead")
            hs.alert.show(ok and ("📖 Power Tools is not loaded, so “"
                                  .. choice.payload .. "” went to the clipboard")
                             or  "📖 Nothing could be done with that word", 4)
            return ok
        end
        d.swaps = d.swaps + 1
        return _G.service.call("power.replaceSelection", choice.payload,
                               "📖", "synonym") and true or false
    end

    function d.render(word, rows, headline)
        if not d.chooser then return end
        local all = {}
        for _, r in ipairs(rows or {}) do
            -- 👁 6.157.0 — a definition row carries its whole gloss for
            -- the preview pane (the row itself is one truncated line)
            if r.kind == "definition" and r.rawText == nil then
                r.rawText = tostring(r.payload or "")
                r.head    = "📖 " .. word .. "  ·  " .. tostring(r.subText or "")
            end
            all[#all + 1] = r
        end
        all[#all + 1] = d.dictRow(word)
        d.chooser:choices(all)
        d.chooser:placeholderText(headline)
    end

    function d.ensureChooser()
        if d.chooser then return d.chooser end
        d.chooser = hs.chooser.new(function(choice)
            -- ⎋ or a click away closes with nil. Bumping the generation
            -- here is what stops a slow reply repainting a closed picker.
            if not choice then d.gen = d.gen + 1 return end
            d.pick(choice)
        end)
        _G.choosers = _G.choosers or {}
        _G.choosers.define = d.chooser
        pcall(function()
            d.chooser:searchSubText(true)
            d.chooser:width(46)
        end)
        -- 👁 6.157.0 — the preview pane goes down with the picker
        pcall(function()
            d.chooser:hideCallback(function()
                if core.call then pcall(core.call, "preview.suspend") end
            end)
        end)
        -- Nothing selected? Type a word. The row updates as you type and
        -- ⏎ looks it up — which is also how you look up a SECOND word
        -- without closing the panel.
        d.chooser:queryChangedCallback(function(q)
            q = tostring(q or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if q == "" or d.rowsAreFor == q:lower() then return end
            if d.lastResult and d.lastResult.word:lower() == q:lower() then return end
            d.chooser:choices({
                { text = "🔎  Look up “" .. q .. "”",
                  subText = "⏎ searches " .. d.sourceSummary(),
                  kind = "lookup", payload = q },
            })
        end)
        return d.chooser
    end

    function d.sourceSummary()
        local live = {}
        for _, p in ipairs(d.providers) do
            local ok, yes = pcall(p.available)
            if ok and yes then live[#live + 1] = p.label end
        end
        if #live == 0 then return "Dictionary.app (no in-panel source is set up)" end
        return table.concat(live, ", ")
    end

    function d.show(word)
        local ch = d.ensureChooser()
        if not ch then
            note("no chooser could be built")
            return false
        end
        word = tostring(word or ""):gsub("^%s+", ""):gsub("%s+$", "")
        -- One word, not a paragraph: a lookup of forty words is a lookup
        -- of nothing, and it would send forty words to the API if that
        -- were on. First word wins, and the placeholder says so.
        local first = word:match("[%a][%a'%-]*")
        if word ~= "" and not first then
            hs.alert.show("📖 “" .. cut(word, 30) .. "” has no word in it", 3)
            return false
        end
        local trimmed = (first and #first < #word)
        word = first or ""

        d.rowsAreFor = nil
        if word == "" then
            d.chooser:choices({})
            d.chooser:placeholderText("type a word and press ⏎ — "
                                      .. d.sourceSummary())
            d.chooser:query("")
        else
            d.chooser:choices({
                { text = "🔎  Looking up “" .. word .. "”…",
                  subText = d.sourceSummary(), kind = "waiting" },
                d.dictRow(word),
            })
            d.chooser:placeholderText(trimmed
                and ("“" .. word .. "” — the first word of the selection")
                or  ("“" .. word .. "”"))
            d.chooser:query("")
        end
        if core.showPopup then core.showPopup(d.chooser)
        else d.chooser:show() end
        -- 👁 6.157.0 — the pane shows a sense's whole gloss beside the list
        if core.call then pcall(core.call, "preview.open", d.chooser) end

        if word == "" then return true end
        d.lookup(word, function(result)
            if not result then
                d.chooser:choices({
                    { text = "📖  Nothing found for “" .. word .. "”",
                      subText = d.wnPath() and "no source had this word"
                                or "WordNet is not installed — see _G.defineReport()",
                      kind = "waiting" },
                    d.dictRow(word),
                })
                return
            end
            d.rowsAreFor = word:lower()
            d.render(word, d.rows(result),
                     ("“%s” — %d sense%s from %s"):format(
                        word, #result.senses,
                        #result.senses == 1 and "" or "s", result.source))
        end)
        return true
    end

    -- ⇪8 reads the selection the same two ways ⇪; does, through the same
    -- service — accessibility first, ⌘C second. Nothing selected opens the
    -- box empty rather than refusing, because "I want to look up a word I
    -- am about to write" is at least as common as looking up one on screen.
    function d.fromSelection()
        if _G.service and _G.service.has
           and _G.service.has("power.readSelection") then
            local started = _G.service.call("power.readSelection", "📖",
                                            function(text) d.show(text) end)
            if started then return true end
        end
        return d.show("")
    end

    -- =====================================================================
    -- 🩺 THE REPORT
    -- =====================================================================
    function _G.defineReport()
        local L = { "📖 DEFINE (⇪8)" }
        L[#L + 1] = "   sources, in the order they are asked:"
        for _, p in ipairs(d.providers) do
            local ok, live = pcall(p.available)
            local mark = (ok and live) and "✅" or "❌"
            L[#L + 1] = ("      %s %-18s %s"):format(mark, p.label,
                (ok and live) and "ready" or tostring(p.why and p.why() or "off"))
        end
        L[#L + 1] = "      ✅ Dictionary.app     always — the last row hands off to it"
        local wn = d.wnPath()
        L[#L + 1] = "   wn binary    : " .. (wn or "not found on this Mac")
        if wn then
            L[#L + 1] = "   wn data      : " ..
                (d.wnSearchDir(wn) or "using the path compiled into wn")
        end
        L[#L + 1] = "   network      : " ..
            (d.allowNetwork and "ALLOWED — looked-up words leave this Mac"
                            or "off — nothing is sent anywhere")
        L[#L + 1] = ("   looked up    : %d word%s this session"):format(
            d.lookups, d.lookups == 1 and "" or "s")
        for label, n in pairs(d.bySource) do
            L[#L + 1] = ("      %-18s answered %d"):format(label, n)
        end
        L[#L + 1] = ("   swapped      : %d word%s replaced by a synonym"):format(
            d.swaps, d.swaps == 1 and "" or "s")
        L[#L + 1] = ("   cached       : %d of %d"):format(#d.cacheOrder, d.cacheMax)
        if d.lastResult then
            L[#L + 1] = ("   last         : “%s” — %d senses from %s"):format(
                d.lastResult.word, #d.lastResult.senses, d.lastResult.source)
        end
        if d.lastNote then L[#L + 1] = "   last problem : " .. d.lastNote end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if d.enabled then
        core.hyperAddShortcut(d.keyMods, d.key, function() d.fromSelection() end,
                              "define")
    end
    core.provide("define.show",      function(w) return d.show(w) end)
    core.provide("define.selection", function() return d.fromSelection() end)
    core.provide("define.lookup",    function(w, cb) return d.lookup(w, cb) end)
    core.provide("define.report",    function() return _G.defineReport() end)

    _G.define = d
    M.d      = d
    M.config = d
end

return M
