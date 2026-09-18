-- =====================================================================
-- MODULE: AUTOCORRECT (was §3.9) — fixes typos & TWo-caps as you type (⌃⌥⌘S toggles)
-- =====================================================================
-- Watches your typing system-wide and fixes a completed word the
-- moment you end it (space, return, punctuation, apostrophe…):
--   • DICTIONARY fixes from autocorrect.csv — e.g. "mna" → "man" —
--     with your capitalization preserved:
--     mna→man · Mna→Man · MNA→MAN  (so "Mna's Search" heals itself)
--   • TWo-caps RULE: any word starting with exactly two capitals then
--     a lowercase letter gets the second capital lowered (MAn→Man,
--     THe→The). One rule instead of thousands of entries; the
--     exceptions that are real (IDs, TVs, MHz…) live in the CSV as
--     "allow" rows. Acronym possessives like "TV's" are untouched
--     (the rule needs a third letter before the apostrophe).
--
-- THE DICTIONARY IS EXTERNAL on purpose: ~10,970 corrections would
-- bloat init.lua massively. 6.10.0: autocorrect.csv lives in the
-- OneDrive Logs folder and is SHARED by both Macs — one dictionary,
-- and an exception ⌃⌥⌘Z learns on one Mac reaches the other after its
-- next Hammerspoon reload. Your existing ~/.hammerspoon/autocorrect.csv
-- (all 10,970 entries) is adopted into OneDrive on first boot.
-- If it's somehow missing at boot, a small starter file is created so
-- the feature still works — drop the full CSV in anytime and reload.
-- CSV format:  type,wrong,right   → fix,mna,man   |   allow,IDs,
--
-- HONEST LIMITS:
--   • Needs Accessibility (same permission the window features use).
--     Not granted → autocorrect is OFF, everything else unaffected —
--     the boot report says so. Files themselves need no permissions.
--   • Password fields: macOS "secure input" blocks event taps there,
--     so nothing is watched or corrected in password boxes (good).
--   • Corrections fire on the word you JUST finished typing at the
--     keyboard — pasted text and existing text are never touched.

-- Moved out of init.lua in 6.38.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "Autocorrect",
    order = 13,
    family = "text",
    cheatsheet = {
        title = "✏️ AUTOCORRECT",
        entries = {
            { "⇪S", "Toggle on/off" },
            -- 🔑 ONE KEY, ONE ROW. The 6.196.0 auditor reads a combo listed
            -- twice as a conflict, and it is right to: ⇪space would offer
            -- the same key twice with only one of them runnable. Two states
            -- of one key belong in one sentence.
            { "⇪Z", "Was OURS wrong? Undo it and learn the exception."
                     .. " Nothing of ours to undo? It learns the correction"
                     .. " YOU just made — backspace over a typo, retype it,"
                     .. " press ⇪Z within 30s" },
            { "auto", "Fixes typos & TWo-caps as you type (autocorrect.csv)" },
            { "see", "_G.autocorrectReport() — what ⇪Z has learned, and how"
                     .. " to unlearn it (_G.autocorrectForget \"HOw\")" },
            { "add", "_G.autocorrectAdd(\"intsead\", \"instead\") — a permanent"
                     .. " fix row in autocorrect.csv, live at once, on both Macs" },
            { "undo", "_G.autocorrectForgetFix(\"makee\") — takes a fix row back,"
                      .. " the way _G.autocorrectForget takes back an exception" },
        },
    },
}

function M.setup(core)
    local autocorrectFile         = core.logsDir .. "/autocorrect.csv"
    core.adoptLegacyFile(autocorrectFile, hs.configdir .. "/autocorrect.csv")
    local autocorrectToggleKey    = "S"          -- ⌃⌥⌘S on/off
    local autocorrectExcludedApps = {            -- exact app names; edit freely
        "Terminal",
        -- "Code",
    }


    -- =====================================================================
    -- 📖 6.200.0 — THE REAL DICTIONARY CHECK
    -- =====================================================================
    -- LL: "The actual word is somethgni, somethingg, somethinng, somethng,
    -- somtething" — five spellings of one word, and the point of listing
    -- them was that he should NOT have to keep adding custom rows. So the
    -- last thing the corrector tries is macOS's own word list, which every
    -- Mac has at /usr/share/dict/words and neither Mac has to sync.
    --
    -- 🔒 THE RISK IS NOT MISSING A TYPO, IT IS "CORRECTING" SOMETHING
    -- THAT WAS RIGHT. That word list holds no names, no jargon, no product
    -- codes, no identifiers. So this fires only when ALL of it is true:
    --   · the word is at least acSpell.minLen letters (4)
    --   · it is letters only, all lower case or one leading capital —
    --     never MIXED case, never with a digit, never with an apostrophe,
    --     which is what keeps acronyms, CamelCase and code out
    --   · the word itself is NOT in the dictionary
    --   · it is not one of ⇪Z's learned exceptions
    --   · and EXACTLY ONE real word is a single edit away. Two candidates
    --     is a guess, and a guess is what makes people switch a feature
    --     off — so two candidates does nothing at all. 6.213.4: words the
    --     list holds outright are asked first, any kind of edit; only when
    --     none is near are words-by-an-ending asked, and those in kind
    --     order (swap, doubled letter, missing letter, three turned round).
    -- Anything it leaves alone is deliberate. It is the last rule asked,
    -- so the CSV dictionary and the TWo-caps rule are unchanged by it.
    local acSpell = {
        on        = true,
        wordsFile = "/usr/share/dict/words",
        -- 📏 FIVE, MEASURED. At four, "repo" became "rope" against the
        -- real word list — short words have proportionally more real
        -- neighbours, and a four-letter fix is worth little. At five,
        -- nothing in a 104-word sample of real prose, names and jargon
        -- was changed at all, and no typo worth catching was lost.
        minLen    = 5,
        slice     = 20000,      -- words folded into the set per turn
        keep      = 12,         -- corrections remembered for the report
        -- 🌩 6.218.0 — how long the tap ignores keys after a retype, at
        -- most: the count below releases it the moment our own keys
        -- have all come back through, this is only the belt for a key
        -- macOS never delivered. settings = { autocorrect = { injectHold = 0.5 } }
        injectHold = 0.3,
        -- 🔤 6.243.0 — ⇪Z LEARNS THE CORRECTION HE JUST MADE HIMSELF.
        -- LL: "I wanted a quick way to use the last correction I makee and
        -- then I type make to fix it, is either added by you catching it,
        -- or me adding it via shortcut key." His call, asked and answered:
        -- ARM, not write. Backspacing over a word and retyping a near-twin
        -- of it ARMS the pair, silently; ⇪Z within selfSecs writes it. A
        -- pair nobody presses ⇪Z on is never written down.
        selfLearn  = true,      -- settings = { autocorrect = { selfLearn = false } }
        selfSecs   = 30,        -- how long an armed pair stays offered
        selfMinLen = 3,         -- "teh"/"the" is three letters and is THE typo
        selfAlert  = false,     -- true: say "⇪Z learns x → y" as it arms
        -- 🚨 Where a word list is wrong far more often than right. LL
        -- chose exactly these plus password fields; anywhere else gets
        -- added from EVIDENCE — the report names every word it changed —
        -- and never from guessing. No release needed for either knob:
        --   settings = { autocorrect = { offIn = { "Excel", … } } }
        --   settings = { autocorrect = { on = false } }   -- all of it off
        -- (M.config is this table; init.lua applies a profile into it
        -- after setup and before warm, which is what reads it.)
        offIn     = { "Terminal", "iTerm2", "iTerm", "Ghostty", "Warp",
                      "Alacritty", "kitty", "Hyper", "Code",
                      "Visual Studio Code", "Xcode", "Sublime Text",
                      "Nova", "BBEdit", "Emacs", "MacVim",
                      "IntelliJ IDEA", "PyCharm", "Android Studio" },
    }
    M.config = acSpell   -- so a per-Mac profile can reach both knobs

    local acSpellWords   = nil        -- word -> true, once it is built
    local acSpellCount   = 0
    local acSpellState   = "not started"
    local acSpellFixes   = {}         -- the last few, for the report
    local acSpellFixed   = 0
    local acSpellDown    = 0          -- times it stood down (app or password)
    -- 6.219.0 — pieces handed to the dictionary alone because the
    -- boundary that ended them was an apostrophe. See the tap below.
    local acApostrophe   = 0
    _G.acSpellTimer      = nil        -- HELD: the slicing timer

    _G.autocorrectEnabled = true
    local autocorrectDict, autocorrectAllow = {}, {}
    local autocorrectDictCount, autocorrectAllowCount = 0, 0
    -- 🚨 6.199.0 — WHAT ⇪Z LEARNS WAS PERMANENT, CROSS-MACHINE AND
    -- INVISIBLE. One press appends `allow,<the exact word>,` to a CSV that
    -- syncs through OneDrive, switching the TWo-caps rule off for that word
    -- on BOTH Macs, for ever, with nothing anywhere naming it. LL found his
    -- by grepping 11,000 lines: "I fixed HOw by deleting the entry and you
    -- can see that it is still HOw" — line 11052, `allow,HOw,`. A rule this
    -- config learns about your typing has to be readable and removable
    -- without a text editor. These three tables are what makes that
    -- possible; none of them changes a single correction.
    local autocorrectAllowLines = {}   -- word  -> { line numbers it sits on }
    local autocorrectNoop       = {}   -- the dead `fix` rows, with lines
    -- 6.243.0 — the fix rows carrying a fourth column, i.e. the ones a
    -- keypress wrote rather than a person editing the CSV by hand.
    -- wrong -> { right, lines = {...}, how }
    local autocorrectTaught     = {}
    local autocorrectDefaultSet = {}   -- the ones WE ship, so the report can
                                       -- separate them from what ⇪Z learned
    local autocorrectLoaded     = false -- read at least once? "nothing
                                       -- learned" and "never read" differ

    -- Default TWo-caps exceptions: two-letter initialisms with s/ed/ing
    -- suffixes, plus unit symbols. Deliberately NOT here: "ITs" — it's a
    -- typo of "Its" far more often than a plural of IT. The list can never
    -- be complete (new acronyms appear constantly), so ⌃⌥⌘Z below learns
    -- new exceptions the moment a fix goes wrong.
    local autocorrectDefaultAllows = {
        "ACs","AIs","APs","ARs","BAs","CBs","CDs","COs","DBs","DJs","DJed","DJing",
        "DMs","EPs","ERs","EVs","GBs","GBps","GHz","GMs","GPa","GPs","GWh","HQs","HRs",
        "IDs","IDed","IDing","IMs","IPs","IQs","IVs","KBs","KOs","KOed","LBs","LPs","MAs",
        "MBs","MBps","MCs","MCed","MCing","MDs","MHz","MPa","MPs","MWh","OKs","OKed","OKing",
        "ORs","OSs","PAs","PBs","PCs","PEs","PJs","PMs","POs","POed","PRs","PTs","QBs","RAs",
        "RBs","RNs","RVs","SOs","TAs","TBs","TDs","THz","TVs","TWh","UIs","VCs","VPs","WRs","XLs",
    }

    for _, a in ipairs(autocorrectDefaultAllows) do
        autocorrectDefaultSet[a] = true
    end

    -- Seed a small starter file if none exists, so a fresh Mac isn't silent
    local function autocorrectSeedIfMissing()
        local f = io.open(autocorrectFile, "r")
        if f then f:close(); return end
        local out = io.open(autocorrectFile, "w")
        if not out then return end
        out:write("type,wrong,right\n")
        for _, a in ipairs(autocorrectDefaultAllows) do
            out:write("allow," .. a .. ",\n")
        end
        for _, p in ipairs({ {"teh","the"}, {"adn","and"}, {"mna","man"}, {"taht","that"}, {"thier","their"},
                             {"recieve","receive"}, {"seperate","separate"}, {"definately","definitely"},
                             {"occured","occurred"}, {"untill","until"} }) do
            out:write("fix," .. p[1] .. "," .. p[2] .. "\n")
        end
        out:close()
        print("✏️ Created starter " .. autocorrectFile .. " — replace it with your full dictionary anytime")
    end

    -- 🗂 6.199.0 — A DEAD `fix` ROW IS SKIPPED AND NAMED. A row whose
    -- two sides are the SAME word once you lower them (`fix,IDs,IDs`,
    -- `fix,how,HOW`) reads like "leave this alone" and does the opposite:
    -- the dictionary stores both sides lowercased and then re-applies
    -- sentence case, so typing IDs comes back Ids. It also costs the
    -- TWo-caps rule its turn on that word, because a dictionary hit
    -- returns before the rule is ever reached. Neither is what anybody
    -- meant by writing the row, so it is dropped at load and listed in
    -- the report with its LINE NUMBER — the CSV itself is never touched.
    local function autocorrectNoopRow(wrong, right)
        return type(wrong) == "string" and type(right) == "string"
               and wrong ~= "" and right ~= ""
               and wrong:lower() == right:lower()
    end

    local function autocorrectLoad()
        autocorrectDict, autocorrectAllow = {}, {}
        autocorrectDictCount, autocorrectAllowCount = 0, 0
        autocorrectAllowLines, autocorrectNoop = {}, {}
        autocorrectTaught = {}
        local f = io.open(autocorrectFile, "r")
        if not f then return false end
        local content = f:read("*a"); f:close()
        local first, n = true, 0
        for line in content:gmatch("([^\r\n]+)") do
            n = n + 1
            if not (first and line:match("^type,")) then
                local c = core.splitCSVLine(line)
                local kind, wrong, right = c[1], c[2], c[3]
                if kind == "fix" and wrong and right and wrong ~= "" and right ~= "" then
                    if autocorrectNoopRow(wrong, right) then
                        autocorrectNoop[#autocorrectNoop + 1] =
                            { line = n, wrong = wrong, right = right }
                    else
                        autocorrectDict[wrong:lower()] = right:lower()
                        autocorrectDictCount = autocorrectDictCount + 1
                        -- 🔤 6.243.0 — A FOURTH COLUMN MARKS THE ROWS ⇪Z
                        -- WROTE. 6.199.0's rule is that anything this
                        -- config LEARNS about his typing owes a report
                        -- naming it and a one-liner that undoes it; the
                        -- `allow` rows manage that by set-differencing
                        -- against the ~85 this config ships, and there is
                        -- no such list for eleven thousand fix rows. So
                        -- the row says so itself: `fix,makee,make,CapsZ`.
                        -- The loader has always read c[1..3] and ignored
                        -- the rest, so every older row still loads and
                        -- every older build still reads these.
                        if c[4] and c[4] ~= "" then
                            local at = autocorrectTaught[wrong:lower()]
                                       or { right = right:lower(), lines = {},
                                            how = c[4] }
                            at.right = right:lower()
                            at.lines[#at.lines + 1] = n
                            autocorrectTaught[wrong:lower()] = at
                        end
                    end
                elseif kind == "allow" and wrong and wrong ~= "" then
                    -- Counted DISTINCT: ⇪Z appends without looking, so the
                    -- same word pressed twice was two rows and a count that
                    -- overstated what the config actually knows.
                    if not autocorrectAllow[wrong] then
                        autocorrectAllowCount = autocorrectAllowCount + 1
                    end
                    autocorrectAllow[wrong] = true
                    local at = autocorrectAllowLines[wrong] or {}
                    at[#at + 1] = n
                    autocorrectAllowLines[wrong] = at
                end
            end
            first = false
        end
        autocorrectLoaded = true
        return true
    end

    -- Restore the user's capitalization onto a lowercase correction:
    -- typed "Mna" → "Man" · typed "MNA" → "MAN" · typed "mna" → "man"
    local function autocorrectApplyCase(typed, correction)
        if typed == typed:upper() and #typed > 1 then
            return correction:upper()
        elseif typed:sub(1, 1):match("%u") then
            return correction:sub(1, 1):upper() .. correction:sub(2)
        end
        return correction
    end

    -- 🧮 PURE, AND IT IS THE WHOLE DECISION. `known(w)` answers "is
    -- that a real word"; everything else here is arithmetic on a string,
    -- so the gate proves every rule against a dictionary of a dozen words
    -- with no Mac, no file and no timing anywhere near it.
    -- FOUR EDITS, and each one is a shape LL's own five typos take:
    --   · two neighbours swapped            teh          -> the
    --   · a letter that was already coming   somethingg   -> something
    --     (doubled, or typed early)          somtething   -> something
    --   · one letter missing                somethng     -> something
    --   · three neighbours turned round     somethgni    -> something
    -- 📌 THAT FOURTH ONE IS AN ADDITION TO WHAT LL APPROVED, and it is
    -- here because without it "somethgni" — a word he listed by name — is
    -- missed: reversing a run of three is TWO adjacent swaps, so a strict
    -- single-swap rule cannot see it. It stays as safe as the others
    -- because the answer must still be unique.
    -- Deliberately NOT here: substitution (a mistyped neighbouring key).
    -- It generates 25 candidates per letter and is where a word list
    -- starts rewriting words that were right.
    -- 🚨 6.205.0 — AN INFLECTION OF A WORD IS A WORD. LL, three days
    -- into 6.200.0: "starets which should be starts", "allows is changing
    -- to gallows", and "convinced" rewritten mid-sentence in Chrome. The
    -- word list macOS ships (Webster's Second, /usr/share/dict/words) is a
    -- list of BASE words: it has start, allow and convince, and NOT starts,
    -- allows or convinced. So every regular plural, past tense and -ing
    -- form LL typed read as "not a word", and any of them that sat one
    -- insertion from an obscure entry was rewritten into it — starets is a
    -- Russian religious elder, and the list has it. 6.200.0's 104-word
    -- measurement never noticed because the sample was base words.
    -- These are the stems a word may be an inflection of. PURE, so the
    -- gate proves every shape with a dozen-word fixture; `known` is asked
    -- about the word and then about each stem, and a hit anywhere means
    -- "this is a word — leave it alone", on BOTH sides of the rule: a typed
    -- word with a known stem is never corrected, and a candidate with a
    -- known stem is a real answer (statrs → starts, where starts itself is
    -- not listed but start is). Conservative on purpose: only the regular
    -- English endings, and a stem must keep at least two letters.
    local function acSpellStems(w)
        local out, n = {}, #w
        local function add(s) if #s >= 2 then out[#out + 1] = s end end
        local function ends(suf) return n > #suf and w:sub(-#suf) == suf end
        local function cut(k) return w:sub(1, n - k) end
        -- stopped → stopp → stop · running → runn → run · bigger → bigg → big
        local function undoubled(s)
            if #s >= 3 and s:sub(-1) == s:sub(-2, -2) then return s:sub(1, -2) end
        end
        local function addAll(s) add(s) ; local u = undoubled(s) ; if u then add(u) end end
        if ends("ies")   then add(cut(3) .. "y") end          -- tries → try
        if ends("es")    then add(cut(2)) end                  -- wishes → wish
        if ends("s")     then add(cut(1)) end                  -- starts → start
        if ends("ied")   then add(cut(3) .. "y") end          -- tried → try
        if ends("ed")    then addAll(cut(2)) ; add(cut(1)) end -- allowed → allow · convinced → convince
        if ends("ing")   then addAll(cut(3)) ; add(cut(3) .. "e") end -- running → run · making → make
        if ends("ier")   then add(cut(3) .. "y") end          -- happier → happy
        if ends("iest")  then add(cut(4) .. "y") end          -- happiest → happy
        if ends("er")    then addAll(cut(2)) ; add(cut(1)) end -- taller → tall · nicer → nice
        if ends("est")   then addAll(cut(3)) ; add(cut(2)) end -- tallest → tall · nicest → nice
        if ends("ily")   then add(cut(3) .. "y") end          -- happily → happy
        if ends("ly")    then add(cut(2)) end                  -- quickly → quick
        if ends("iness") then add(cut(5) .. "y") end          -- happiness → happy
        if ends("ness")  then add(cut(4)) end                  -- kindness → kind
        return out
    end
    _G.acSpellStems = acSpellStems   -- the gate reads it directly

    -- 6.213.2 — the ending FAMILY a word carries, or "". PURE; the gate
    -- reads it. es, ies and s are ONE family (the list has wish, not
    -- wishes, so wishs → wishes must still stand), as are ed/ied,
    -- er/ier, est/iest, ly/ily and ness/iness. Longest suffix first.
    local acSpellFamilies = {
        { "iness", "ness" }, { "ness", "ness" }, { "iest", "est" },
        { "ies", "s" }, { "ied", "ed" }, { "ing", "ing" }, { "ier", "er" },
        { "ily", "ly" }, { "est", "est" }, { "es", "s" }, { "ed", "ed" },
        { "er", "er" }, { "ly", "ly" }, { "s", "s" },
    }
    -- =====================================================================
    -- 🔤 6.243.0 — IS THIS PAIR ONE EDIT APART? (PURE)
    -- =====================================================================
    -- Damerau–Levenshtein, capped at one: one substitution, one insertion,
    -- one deletion, or one swap of NEIGHBOURS. Written as three branches
    -- rather than a matrix because the answer is only ever "one or not
    -- one", and a matrix over two words on every keystroke is work the
    -- main thread does not need (6.228.0).
    --
    -- 🚨 WHY A SIMILARITY TEST AT ALL, when LL typed both words himself:
    -- because every ordinary EDIT looks identical to a correction at this
    -- tap. Typing "cat", changing your mind and typing "dog" is a rewrite,
    -- not a typo, and a dictionary that learned it would rewrite the word
    -- for ever, on both Macs. One edit apart is what separates the two, and
    -- the fact that this only ARMS — nothing is written without ⇪Z — is
    -- what makes a wrong guess here cost nothing at all.
    local function acEditsOne(a, b)
        if type(a) ~= "string" or type(b) ~= "string" then return false end
        local la, lb = #a, #b
        if la == lb then
            local i = 1
            while i <= la and a:byte(i) == b:byte(i) do i = i + 1 end
            if i > la then return false end         -- identical, not one edit
            local j = la
            while j > i and a:byte(j) == b:byte(j) do j = j - 1 end
            if i == j then return true end          -- one substitution
            if j == i + 1 and a:byte(i) == b:byte(j)
               and a:byte(j) == b:byte(i) then
                return true                          -- two neighbours swapped
            end
            return false
        end
        if math.abs(la - lb) ~= 1 then return false end
        -- The longer string with one character taken out is the shorter one.
        local long, short = a, b
        if lb > la then long, short = b, a end
        local i = 1
        while i <= #short and long:byte(i) == short:byte(i) do i = i + 1 end
        -- Everything after the skipped character must line up.
        local k = i
        while k <= #short do
            if long:byte(k + 1) ~= short:byte(k) then return false end
            k = k + 1
        end
        return true
    end

    -- → ok, why. The whole rule for "did he just correct himself", in one
    -- PURE place, so the gate proves every refusal without a keyboard.
    local function acSelfPair(before, after, minLen)
        minLen = tonumber(minLen) or 3
        if type(before) ~= "string" or type(after) ~= "string" then
            return false, "not two words"
        end
        if before == "" or after == "" then return false, "an empty side" end
        if #before < minLen or #after < minLen then
            return false, "shorter than " .. minLen .. " letters — too many"
                          .. " real words are one edit from each other down there"
        end
        if not before:match("^%a+$") or not after:match("^%a+$") then
            return false, "letters only — a number or a symbol is not a typo"
        end
        -- 🚨 THE DICTIONARY STORES BOTH SIDES LOWERCASED and re-applies
        -- sentence case, so a pair that differs only in capitals would be
        -- written as a row whose two sides are the same word — the DEAD ROW
        -- 6.199.0 skips at load. Refused here, with the real reason, rather
        -- than written and silently ignored for ever.
        if before:lower() == after:lower() then
            return false, "the same word once lowered — that row would be dead"
        end
        if not acEditsOne(before:lower(), after:lower()) then
            return false, "more than one edit apart — that is a rewrite, not"
                          .. " a typo, and this never guesses at one"
        end
        return true, "one edit apart"
    end

    local function acSpellEnding(w)
        for _, p in ipairs(acSpellFamilies) do
            if #w > #p[1] and w:sub(-#p[1]) == p[1] then return p[2] end
        end
        return ""
    end
    _G.acSpellEnding = acSpellEnding   -- the gate reads it directly

    local function acSpellCorrection(word, known, minLen)
        if type(word) ~= "string" or type(known) ~= "function" then return nil end
        minLen = tonumber(minLen) or 4
        if #word < minLen then return nil end
        -- Letters only, and at most ONE leading capital. This single test
        -- is what keeps IDs, iPhone, SKU7, don't and camelCase out.
        local capped = word:match("^%u%l+$") ~= nil
        if not (word:match("^%l+$") or capped) then return nil end
        local w = word:lower()
        -- 6.205.0 — "is that a word" asks about the word AND its stems.
        local function isWord(x)
            if known(x) then return true end
            for _, s in ipairs(acSpellStems(x)) do
                if known(s) then return true end
            end
            return false
        end
        if isWord(w) then return nil end           -- it is already a word

        -- 🚨 6.213.2 — AN ANSWER THAT IS ONLY A WORD BY INFLECTION MUST
        -- CARRY THE ENDING LL TYPED. Measured against the REAL list after
        -- 6.205.0 shipped: plugin → pluging (plug+ing), backend → backened
        -- (backen+ed), signin → signing (sign+ing). Right words, rewritten
        -- — the very class 6.205.0 was shipped to end, and a 12-word
        -- fixture could not see it. The typist typed the ending; the typo
        -- is in the stem. So an inflected candidate counts only when its
        -- ending family is the one the typed word carries; a candidate
        -- the list holds outright is never gated (somethingg →
        -- something). Measured cost, stated: a typo INSIDE the ending
        -- (convincd) is left alone now, and against the real list statrs
        -- is silent either way — starts, staters and stators are three
        -- answers, and this rule never guesses.
        local typedEnd = acSpellEnding(w)

        -- 🚨 6.213.4 — TWO TIERS, AND THE KIND OF EDIT ORDERS ONLY THE
        -- SECOND. LL, on 6.213.3: "statrs is still not corrected" — the
        -- real list has stater and stator, so starts (a swap) shared the
        -- vote with staters and stators (a letter missing) and "exactly
        -- one" fell silent. His call was to prefer the swap. MEASURED
        -- FIRST, because a plain kind order (swap, then doubled letter,
        -- then missing letter, then three turned round) also turned
        -- adress into daress — dares+s, a swap, outvoting address, a
        -- listed word an insertion away — and sceen into scene over
        -- screen. So: TIER ONE asks every kind for words the list holds
        -- OUTRIGHT, exactly one wins and two is still a guess (sceen:
        -- scene and screen → nothing; wierd: weird and wired → nothing).
        -- Only when NO listed word is near does TIER TWO ask for words
        -- that are words by an ending (6.205.0/6.213.2), and THERE the
        -- kinds run in order and the first kind with an answer decides
        -- (statrs: starts by a swap, before staters and stators). Against
        -- the real list this corrects four more typos than 6.213.3 and
        -- rewrites nothing new; the kind order in tier one was measured
        -- and refused for the two words above.
        local function sweep(test, ordered)
            local seen, hits, n = {}, nil, 0
            local function try(cand)
                if cand == w or seen[cand] then return end
                seen[cand] = true
                if test(cand) then n = n + 1 ; hits = cand end
            end
            local kinds = {
                function()                          -- swap two neighbours
                    for i = 1, #w - 1 do
                        try(w:sub(1, i - 1) .. w:sub(i + 1, i + 1) .. w:sub(i, i)
                            .. w:sub(i + 2))
                    end
                end,
                function()                          -- a letter already coming
                    for i = 1, #w do
                        if w:sub(i, i) == w:sub(i + 1, i + 1)
                           or w:sub(i, i) == w:sub(i + 2, i + 2) then
                            try(w:sub(1, i - 1) .. w:sub(i + 1))
                        end
                    end
                end,
                function()                          -- one letter missing
                    for i = 1, #w + 1 do
                        for c = 97, 122 do
                            try(w:sub(1, i - 1) .. string.char(c) .. w:sub(i))
                        end
                    end
                end,
                function()                          -- three turned round
                    for i = 1, #w - 2 do
                        try(w:sub(1, i - 1) .. w:sub(i + 2, i + 2) .. w:sub(i + 1, i + 1)
                            .. w:sub(i, i) .. w:sub(i + 3))
                    end
                end,
            }
            for _, kind in ipairs(kinds) do
                kind()
                if ordered and n > 0 then break end
            end
            return n, hits
        end
        local function listed(x) return known(x) == true end
        local function byEnding(x)
            if known(x) then return false end
            if acSpellEnding(x) ~= typedEnd then return false end
            for _, s in ipairs(acSpellStems(x)) do
                if known(s) then return true end
            end
            return false
        end
        local n, hits = sweep(listed, false)        -- tier one: listed words, any kind
        if n == 0 then n, hits = sweep(byEnding, true) end   -- tier two: by ending, in kind order
        -- 🚨 EXACTLY ONE, within the tier that answered. Two real words the
        -- same distance away is a guess, and this feature is only worth
        -- having if it never guesses.
        if n ~= 1 or not hits then return nil end
        if capped then return hits:sub(1, 1):upper() .. hits:sub(2) end
        return hits
    end
    _G.acSpellCorrection = acSpellCorrection   -- the gate reads it directly

    -- The live wrapper: the pure rule, plus the reasons this Mac might
    -- not be able to answer at all. A word list still loading, missing,
    -- or switched off means the word passes through untouched — it never
    -- means a guess.
    local function acSpellFor(word)
        if not acSpell.on or not acSpellWords then return nil end
        if autocorrectAllow[word] then return nil end   -- ⇪Z said no
        return acSpellCorrection(word, function(w)
            return acSpellWords[w] == true
        end, acSpell.minLen)
    end

    -- 🚨 SLICED, BECAUSE THIS IS THE THREAD THAT READS THE KEYBOARD.
    -- /usr/share/dict/words is ~235,000 lines: the READ is cheap (a local
    -- system file, never a OneDrive placeholder — that distinction is the
    -- whole 6.152.x stall story), but folding it into a table in one go
    -- is a visible hitch. So it goes in at acSpell.slice words per turn
    -- of the event loop, on a HELD timer, and until it is finished the
    -- check is simply not asked. NOTHING waits for it, and a Mac where
    -- the file is missing says so once and carries on with everything
    -- else working exactly as before.
    local function acSpellLoad()
        -- 🚨 CLEARED FIRST. A reload that cannot read the file used to
        -- leave the PREVIOUS set live while the state said "no word
        -- list" — the report and the behaviour disagreeing, which is the
        -- one thing a report must never do. Found by the check that
        -- points wordsFile at a file that is not there.
        acSpellWords, acSpellCount = nil, 0
        if not acSpell.on then
            acSpellState = "off — acSpell.on is false"
            return
        end
        local f = io.open(acSpell.wordsFile, "r")
        if not f then
            acSpellState = "no word list at " .. tostring(acSpell.wordsFile)
            print("✏️ " .. acSpellState .. " — the dictionary check is off."
                  .. " Your rows and the TWo-caps rule are unaffected.")
            return
        end
        local okR, body = pcall(function() return f:read("*a") end)
        pcall(function() f:close() end)
        if not (okR and type(body) == "string" and body ~= "") then
            acSpellState = "the word list could not be read"
            print("✏️ " .. acSpellState .. " — the dictionary check is off.")
            return
        end
        local set, n, pos = {}, 0, 1
        acSpellState = "reading the word list"
        local function step()
            local done = 0
            while done < (tonumber(acSpell.slice) or 20000) do
                if pos > #body then
                    acSpellWords, acSpellCount = set, n
                    acSpellState = "ready"
                    _G.acSpellTimer = nil
                    _G.diag.say("autocorrect", string.format(
                        "dictionary check ready: %d words from %s",
                        n, acSpell.wordsFile))
                    return
                end
                local nl = body:find("\n", pos, true)
                local word = body:sub(pos, (nl or (#body + 1)) - 1)
                pos = (nl or #body) + 1
                word = word:lower():gsub("%s", "")
                -- Letters only. A hyphenated or apostrophised entry can
                -- never be a candidate here anyway (the rule refuses
                -- those shapes), so keeping it would only cost memory.
                if word ~= "" and word:match("^%l+$") then
                    if not set[word] then n = n + 1 end
                    set[word] = true
                end
                done = done + 1
            end
            _G.acSpellTimer = hs.timer.doAfter(0, step)
        end
        step()
    end

    -- The decision for one completed word: returns the corrected word, or
    -- nil if it's fine as typed. Dictionary first, then the TWo-caps rule.
    -- 📌 6.200.0 — IT NAMES ITS SOURCE: "dictionary" (a row LL wrote),
    -- "rule" (TWo-caps) or "spelling" (the word list). The caller used to
    -- work out which by looking the word up a SECOND time; one answer
    -- from one place cannot drift from itself.
    -- 🔒 spellOK MUST BE EXACTLY true. It fails CLOSED on purpose — a
    -- caller that forgets to pass it gets no dictionary check at all,
    -- rather than one everywhere including the places it must not speak
    -- (6.197.1's lesson, on the feature that acts on every word typed).
    local function autocorrectFor(word, spellOK)
        if #word < 2 then return nil end
        local hit = autocorrectDict[word:lower()]
        if hit then
            local fixed = autocorrectApplyCase(word, hit)
            if fixed ~= word then return fixed, "dictionary" end
            return nil
        end
        if #word >= 3 and word:match("^%u%u%l") and word:match("^%a+$")
           and not autocorrectAllow[word] then
            return word:sub(1, 1) .. word:sub(2, 2):lower() .. word:sub(3),
                   "rule"
        end
        -- 6.200.0 — the word list is asked LAST, so it only ever sees a
        -- word no deliberate row and no rule has already claimed.
        if spellOK == true then
            local spelled = acSpellFor(word)
            if spelled and spelled ~= word then return spelled, "spelling" end
        end
        return nil
    end

    -- ---- the typing watcher ---------------------------------------------
    -- A word buffer follows what you type. Letters extend it; delete trims
    -- it; navigation, clicks, shortcuts, digits and anything exotic clear
    -- it (the cursor moved or the token isn't a plain word — never guess).
    -- A boundary key (space/return/tab/punctuation/apostrophe) checks the
    -- buffer: if a fix applies, the boundary keystroke is consumed, the
    -- word is replaced (backspaces + retype), and the boundary is retyped
    -- after it. Our own synthetic keystrokes are flagged so the watcher
    -- ignores them.
    local acBuffer    = ""
    local acInjecting = false
    -- 6.16.18: held in _G. so Lua's GC can't collect this one-shot timer
    -- before its (short) delay elapses — same real Hammerspoon gotcha
    -- that broke App Monitor; see that fix's note in §3.7 for the details.
    _G.acInjectTimers = {}

    -- The last correction made, for ⌃⌥⌘Z (undo + learn). undoSafe stays
    -- true only until you type or click again — after that the text can't
    -- be safely rewound, but the exception can still be learned.
    local acLast = nil   -- { word, fixed, boundary, wasRule, undoSafe }

    -- 🔤 6.243.0 — WHAT HE WAS TYPING BEFORE HE STARTED BACKSPACING, and
    -- the pair that is currently offered to ⇪Z. `before` is the word as it
    -- stood when the FIRST delete of a run arrived; `pair` is what the
    -- boundary made of it. Nothing here is ever written by itself.
    --
    -- 🚨 THE DISCRIMINATOR ALREADY EXISTS AND IS THE WHOLE DESIGN. This
    -- module corrects by deleting and retyping, and 6.218.0's rule is that
    -- those keys come BACK through this tap as typing — so the config's own
    -- corrections are indistinguishable from LL correcting himself unless
    -- something separates them. The injection guard is that something, and
    -- it already returns before any of the code below runs. Learn from our
    -- own retype and the dictionary starts teaching itself its own rules.
    local acSelf = { before = nil, pair = nil, armed = 0, learned = 0,
                     lastWhy = nil }

    local acClearKeycodes = {   -- keys that mean "cursor moved / abandon word"
        [53] = true,  -- esc
        [123] = true, [124] = true, [125] = true, [126] = true,  -- arrows
        [115] = true, [119] = true, [116] = true, [121] = true,  -- home/end/pgup/pgdn
        [117] = true, -- forward delete
    }

    local function acFrontAppName()
        local ok, app = pcall(hs.application.frontmostApplication)
        if not ok or not app then return nil end
        local okN, name = pcall(function() return app:name() end)
        if not okN or type(name) ~= "string" then return nil end
        return name
    end

    local function acIsExcludedApp()
        local name = acFrontAppName()
        if not name then return false end
        for _, ex in ipairs(autocorrectExcludedApps) do
            if name == ex then return true end
        end
        return false
    end

    -- 🔒 6.200.0 — WHERE THE DICTIONARY CHECK DOES NOT SPEAK. The CSV
    -- dictionary and the TWo-caps rule are unaffected by any of this;
    -- only the word list stands down, because only the word list is
    -- guessing. It FAILS CLOSED: an app it cannot name is not silently
    -- trusted, and a Mac that cannot answer about secure input is
    -- treated as if the lock were on.
    local function acSpellHereOK()
        if not acSpell.on or not acSpellWords then return false end
        local okS, secure = pcall(hs.eventtap.isSecureInputEnabled)
        if (not okS) or secure then
            acSpellDown = acSpellDown + 1
            return false
        end
        local name = acFrontAppName()
        if not name then acSpellDown = acSpellDown + 1 return false end
        for _, ex in ipairs(acSpell.offIn or {}) do
            if name == ex then acSpellDown = acSpellDown + 1 return false end
        end
        return true
    end

    -- 🌩 6.218.0 — THE GUARD STAYS UP UNTIL THE RETYPE HAS DRAINED.
    -- hs.eventtap.keyStrokes POSTS its events: the call returns before
    -- a single one of them has reached this tap. Until now acInjecting
    -- was cleared on the line after it, so every word this module ever
    -- retyped came straight back through its own tap as if LL had
    -- typed it. That was harmless while the retype held no boundary —
    -- and it took LL's 6.216.0 install to type one that did: "doesnt "
    -- → the dictionary row fix,doesnt,doesn't → the retyped apostrophe
    -- is a boundary → the word before it, "doesn", is not on the word
    -- list and "doesnt" IS (Webster's Second has it) → the spelling
    -- rule retyped "doesnt'" → the dictionary retyped "doesn't" → for
    -- ever. Every "t" that landed on a Chrome page instead of a field
    -- was Vimium's new-tab key: his "took off like a banshee", the
    -- endless New Tabs and "dododod…doesnt" in one mechanism, and
    -- `_G.autocorrectReport()` showed it (24× "doesn → doesnt").
    -- The undo path (⇪Z) had the same shape and a quieter cost: the
    -- restored word came back through the tap and was corrected again.
    --
    -- THE FIX COUNTS, WITH A TIMER AS THE BELT. We know exactly how
    -- many keyDowns we posted (one per delete, one per character), so
    -- the tap counts them off as they arrive and releases the guard on
    -- the last one — LL's next real key is examined, not skipped. A
    -- held timer (`acSpell.injectHold`) releases it anyway in case a key
    -- was never delivered, so nothing can leave the guard up for good.
    -- Both ways are counted for the report's "retype guard" line.
    local acInjectPending = 0
    local acDrain = { retypes = 0, byCount = 0, byTimer = 0 }
    _G.acInjectHold = nil
    local function acInjectRelease(how)
        if not acInjecting then return end
        acInjecting = false
        acInjectPending = 0
        if how == "count" then acDrain.byCount = acDrain.byCount + 1
        elseif how == "timer" then acDrain.byTimer = acDrain.byTimer + 1 end
        if _G.acInjectHold then
            pcall(function() _G.acInjectHold:stop() end)
            _G.acInjectHold = nil
        end
    end
    -- Delete nDeletes characters and type text, with this tap standing
    -- down until every one of those keys has come back through it.
    local function acType(nDeletes, text)
        acInjecting = true
        acDrain.retypes = acDrain.retypes + 1
        acInjectPending = nDeletes + (utf8.len(text) or #text)
        -- 🚨 6.69.0 — THROUGH THE SHARED GUARD. acInjecting only ever told
        -- THIS tap to stand down. The text expander has its own tap on the
        -- same keystrokes, and without a shared flag a correction that
        -- happens to end in a snippet trigger fires that snippet — a
        -- spelling fix that expands into an email signature. See
        -- _G.withInjection in init.lua. The local flag stays because it is
        -- what protects this module when the shared one is unavailable.
        local ok, err = (_G.withInjection or pcall)(function()
            for _ = 1, nDeletes do
                hs.eventtap.keyStroke({}, "delete", 0)
            end
            hs.eventtap.keyStrokes(text)
        end)
        if _G.acInjectHold then pcall(function() _G.acInjectHold:stop() end) end
        local okT, t = pcall(hs.timer.doAfter, acSpell.injectHold or 0.3,
                             function() acInjectRelease("timer") end)
        if okT and t then
            _G.acInjectHold = t
        else
            -- No timer means no belt: a dropped key would hold the guard
            -- up for good, so this Mac gets the old behaviour instead.
            acInjectRelease("no timer")
        end
        return ok, err
    end

    local function acInject(word, fixed, boundary, wasRule)
        local ok = acType(#word, fixed .. boundary)
        -- 🚨 TELL THE EXPANDER THE DOCUMENT MOVED (6.72.0). We just
        -- deleted a word and typed a different one, and its rolling
        -- buffer has no way to know — our injection is invisible to it by
        -- design, via the shared guard. Left unsaid, its buffer describes
        -- text that is no longer on screen, and an expansion matched
        -- against that stale tail deletes characters that are not there.
        -- The mirror of the call it makes to us.
        if _G.expanderResetBuffer then pcall(_G.expanderResetBuffer) end
        if ok then
            acLast = { word = word, fixed = fixed, boundary = boundary,
                       wasRule = wasRule, undoSafe = true }
        else
            print("⚠️ Autocorrect injection failed for '" .. word .. "'")
        end
    end

    -- 🚨 6.69.0 — THE EXPANDER CAN LEAVE HALF A TRIGGER IN THIS BUFFER.
    -- When the text expander fires on `hte` it CONSUMES the final "e", so
    -- this module saw "h" and "t" and never the end of the word. It then
    -- types "the", which the shared guard makes us ignore — correctly.
    -- What is left behind is "ht", which goes on to join whatever you type
    -- next: "htre", checked against an 11,000-row dictionary at the next
    -- space. It will almost always miss. "Almost always" is not a standard
    -- this config holds itself to, and the fix is one line called from the
    -- one place that knows an expansion happened.
    function _G.autocorrectResetBuffer()
        acBuffer = ""
        if acLast then acLast.undoSafe = false end
    end

    -- 🛟 6.72.0 — THE CALLBACK BODY IS GUARDED, and returns false if it
    -- throws. This ran unguarded from 6.10.0 to here: every line below
    -- reaches into an event object and any error in it — a malformed
    -- event, a nil index introduced by a later edit — escapes straight
    -- into Hammerspoon's event machinery, ON EVERY KEYSTROKE. It does not
    -- stop; it just makes the whole keyboard louder and slower, and macOS
    -- switches taps off that behave that way.
    --
    -- The key caster was written with this from the start. The two older
    -- taps were not, which a three-tap integration test found by feeding
    -- all of them one hostile event. Same shape in all three now:
    -- absorb, count, and past acMaxFailures stand down rather than throw
    -- on every key for the rest of the session.
    local acFailures = 0
    local acMaxFailures = 5
    local function acOnEvent(ev)
            -- ⏸ 6.152.0 — the pause switch (⇪⇧1, power_tools): while it
            -- is up, every keystroke passes through untouched. The tap
            -- stays running — a stopped tap needs its watchdog dance to
            -- come back, a pass-through guard costs one comparison.
            if _G.hsPaused then return false end
            -- Either flag standing means "this keystroke is not a person
            -- typing". The local one covers our own injection; the shared
            -- one covers the text expander's (6.69.0).
            if acInjecting then
                -- 6.218.0 — our own keys, counted off as they come back
                if acInjectPending > 0
                   and ev:getType() == hs.eventtap.event.types.keyDown then
                    acInjectPending = acInjectPending - 1
                    if acInjectPending == 0 then acInjectRelease("count") end
                end
                return false
            end
            if _G.typingInjection and _G.typingInjection() then return false end

            local t = ev:getType()
            if t == hs.eventtap.event.types.leftMouseDown
               or t == hs.eventtap.event.types.rightMouseDown then
                acBuffer = ""
                acSelf.before = nil          -- a click is a different word
                if acLast then acLast.undoSafe = false end   -- cursor moved
                return false
            end

            local flags = ev:getFlags()
            if flags.cmd or flags.ctrl then
                acBuffer = ""
                -- 🔑 The ARMED PAIR deliberately survives a chord: ⇪Z is a
                -- chord, and clearing it here would make the key that
                -- learns the pair the key that throws it away. `before` is
                -- a half-typed word and does not survive.
                acSelf.before = nil
                return false   -- chords (incl. ⌃⌥⌘Z itself) don't spoil undo
            end

            local code = ev:getKeyCode()
            if code == 51 then                       -- delete: trim buffer
                -- 🔤 6.243.0 — the FIRST delete of a run is the moment the
                -- word he typed still exists. Kept only when there IS one:
                -- backspacing into text this tap never saw typed gives an
                -- empty buffer, and an empty "before" would pair with the
                -- next word he types and offer a row he never corrected.
                if acSelf.before == nil and #acBuffer > 0 then
                    acSelf.before = acBuffer
                end
                if #acBuffer > 0 then acBuffer = acBuffer:sub(1, -2) end
                if acLast then acLast.undoSafe = false end
                return false
            end
            if acClearKeycodes[code] then
                acBuffer = ""
                acSelf.before = nil          -- the caret moved off the word
                if acLast then acLast.undoSafe = false end   -- cursor moved
                return false
            end

            local ch = ev:getCharacters()
            if not ch or #ch ~= 1 then               -- function keys, IME, etc.
                acBuffer = ""
                return false
            end

            if acLast then acLast.undoSafe = false end       -- typed something new

            if ch:match("^%a$") then                 -- letter: extend the word
                acBuffer = acBuffer .. ch
                if #acBuffer > 40 then acBuffer = "" end
                return false
            end

            -- Boundary characters end a word and trigger the check
            if ch == " " or ch == "\r" or ch == "\t"
               or ch:match("^[%.,;:!%?'\"%(%)%[%]{}<>/\\%-_=%+%*&%%%$#@~`|%^]$") then
                local word = acBuffer
                acBuffer = ""
                -- 🔤 6.243.0 — HE CORRECTED HIMSELF. Deletes removed the
                -- word `acSelf.before` and he typed `word` in its place;
                -- if they are one edit apart, ⇪Z is offered the pair.
                -- ARMED, NEVER WRITTEN — his own call on the one decision
                -- this feature had: "if the method can introduce errors,
                -- singles only" is his rule about the OCR filter, and a
                -- similarity test is a guess where a keypress is not.
                local wasBefore = acSelf.before
                acSelf.before = nil
                if wasBefore and acSpell.selfLearn ~= false then
                    local ok, why = acSelfPair(wasBefore, word, acSpell.selfMinLen)
                    acSelf.lastWhy = wasBefore .. " → " .. word .. ": " .. why
                    -- 🚨 A NEW RETYPE REPLACES THE OFFER WHETHER OR NOT IT
                    -- QUALIFIES. ⇪Z offers "the last correction you made",
                    -- and once he has backspaced over another word that is
                    -- no longer the pair from three words ago — pressing it
                    -- would write a row he had stopped thinking about.
                    -- Cleared only when he really did retype something:
                    -- typing an ordinary word must NOT cancel the offer, or
                    -- the 30 seconds are only until the next space.
                    acSelf.pair = nil
                    if ok then
                        acSelf.pair = { wrong = wasBefore, right = word,
                                        at = os.time() }
                        acSelf.armed = acSelf.armed + 1
                        if acSpell.selfAlert then
                            pcall(function()
                                hs.alert.show("⇪Z learns " .. wasBefore
                                              .. " → " .. word, 2)
                            end)
                        end
                    end
                end
                if _G.autocorrectEnabled and #word >= 2 then
                    -- 🚨 6.219.0 — AN APOSTROPHE INSIDE A WORD IS NOT A
                    -- WORD ENDING, and the piece before it is not a word.
                    -- LL, on 6.218.0: "Doesnt't kinda works as you can
                    -- see." The storm was gone; this was left. An
                    -- apostrophe is a boundary character, so typing
                    -- "Doesn't" hands "Doesn" to the rules — and
                    -- /usr/share/dict/words is Webster's Second, which
                    -- HOLDS the apostrophe-less contractions. Measured
                    -- against the real list (web2, 234,454 words): doesn
                    -- → doesnt, wouldn → wouldnt, mightn → mightnt,
                    -- oughtn → oughtnt. Four words nobody can type.
                    -- (couldn, shouldn, mustn, needn, weren, haven are
                    -- silent — one is a word, the rest have no single
                    -- answer; can't, won't, isn't, didn't are under
                    -- minLen. That is why only "doesn't" ever reached
                    -- him.) So the WORD LIST is not asked when the
                    -- boundary is an apostrophe. The dictionary rows and
                    -- the TWo-caps rule still are — "teh'" must still
                    -- correct, and "THe'" must still become "The'".
                    -- COST, stated: a real typo immediately before an
                    -- apostrophe (somethign's) is now silent. That is
                    -- the trade for four contractions that are not.
                    local spellHere = false
                    if ch == "'" then
                        acApostrophe = acApostrophe + 1
                    else
                        spellHere = acSpellHereOK()
                    end
                    local fixed, source = autocorrectFor(word, spellHere)
                    if fixed and not acIsExcludedApp() then
                        -- A rule fix and a spelling fix are both undone AND
                        -- permanently refused by ⇪Z, because acSpellFor
                        -- asks autocorrectAllow too — so 6.199.0's report
                        -- and _G.autocorrectForget already govern this.
                        local wasRule = (source ~= "dictionary")
                        if source == "spelling" then
                            acSpellFixed = acSpellFixed + 1
                            table.insert(acSpellFixes, 1, word .. " → " .. fixed)
                            acSpellFixes[(acSpell.keep or 12) + 1] = nil
                        end
                        local it
                        it = hs.timer.doAfter(0.01, function()
                            acInject(word, fixed, ch, wasRule)
                            for i, t in ipairs(_G.acInjectTimers) do
                                if t == it then table.remove(_G.acInjectTimers, i); break end
                            end
                        end)
                        table.insert(_G.acInjectTimers, it)
                        return true                  -- consume; we retype it
                    end
                end
                return false
            end

            acBuffer = ""                            -- digits & anything else
            return false
    end

    _G.autocorrectTap = hs.eventtap.new(
        { hs.eventtap.event.types.keyDown,
          hs.eventtap.event.types.leftMouseDown,
          hs.eventtap.event.types.rightMouseDown },
        function(ev)
            local ok, ret = pcall(acOnEvent, ev)
            if ok then acFailures = 0; return ret end
            acFailures = acFailures + 1
            if acFailures >= acMaxFailures then
                pcall(function() _G.autocorrectTap:stop() end)
                _G.autocorrectStatus = "OFF (failed " .. acFailures
                                       .. " times in a row)"
                print("✏️ Autocorrect: switched itself OFF after " .. acFailures
                      .. " consecutive failures — your keyboard and every "
                      .. "other tool are unaffected. Last error: " .. tostring(ret))
                if _G.notices then
                    _G.notices.record("autocorrect", "disabled itself", tostring(ret))
                end
            end
            -- 🚨 false, ALWAYS. A corrector that eats a keystroke when it
            -- fails is worse than one that simply does not correct.
            return false
        end
    )

    -- ⌃⌥⌘S — toggle on/off (the tap keeps running; the flag gates action,
    -- so toggling is instant and the buffer logic stays warm)
    hs.hotkey.bind(core.popupKeys.mods, autocorrectToggleKey, function()
        _G.autocorrectEnabled = not _G.autocorrectEnabled
        hs.alert.show(_G.autocorrectEnabled and "✏️ Autocorrect ON" or "✏️ Autocorrect OFF")
    end)

    -- ⌃⌥⌘Z — the correction was WRONG: undo it and learn from it.
    --   • TWo-caps rule fix (e.g. a real acronym plural not yet in the
    --     list): the word is appended as an "allow" row in autocorrect.csv
    --     — permanent, synced to the in-memory set immediately — and the
    --     text is rewound if you haven't typed since. Because the CSV is
    --     shared via OneDrive, the other Mac learns it too (after reload).
    --   • Dictionary fix: the text is rewound this once; dictionary rows
    --     are deliberate entries, so removing one permanently stays a
    --     manual CSV edit (the alert names the exact row).
    -- If you've typed or clicked since the fix, rewinding text isn't safe,
    -- so only the learning half happens.
    local autocorrectUndoKey = "Z"

    hs.hotkey.bind(core.popupKeys.mods, autocorrectUndoKey, function()
        local last = acLast
        if not last then
            -- 🔤 6.243.0 — NOTHING OF OURS TO UNDO, so the other thing ⇪Z
            -- governs: the correction LL just made HIMSELF. One key, two
            -- states, nothing new to remember — 6.199.0's own test for
            -- whether a rule belongs in this module ("⇪Z ALREADY GOVERNS
            -- IT … Nothing new to learn"), and 6.182.0's rule that a tool
            -- living inside another tool does not also get its own key.
            --
            -- 🚨 THE CONFIG'S OWN CORRECTION WINS when there is one. It is
            -- the more urgent of the two (something on screen is wrong
            -- NOW), it is the behaviour that already existed, and after it
            -- runs the pair below is stale anyway.
            local p = acSelf.pair
            local maxAge = tonumber(acSpell.selfSecs) or 30
            if p and (os.time() - (p.at or 0)) <= maxAge then
                acSelf.pair = nil
                local ok, why = _G.autocorrectAdd(p.wrong, p.right, "⇪Z")
                if ok then
                    acSelf.learned = acSelf.learned + 1
                else
                    pcall(function()
                        hs.alert.show("✏️ " .. p.wrong .. " → " .. p.right
                                      .. " was NOT added — " .. tostring(why), 5)
                    end)
                end
                return
            end
            -- 🔎 AND THE REFUSAL SAYS WHICH OF THE THREE THINGS IT WAS, or
            -- a key that does nothing is a key he stops trusting.
            if p then
                acSelf.pair = nil
                hs.alert.show("✏️ " .. p.wrong .. " → " .. p.right
                              .. " was more than " .. maxAge
                              .. "s ago — retype it and press ⇪Z again", 4)
            elseif acSpell.selfLearn == false then
                hs.alert.show("✏️ Nothing to undo — learning your own"
                              .. " corrections is switched off", 4)
            elseif acSelf.lastWhy then
                hs.alert.show("✏️ Nothing to undo. The last word you retyped"
                              .. " was not offered: " .. acSelf.lastWhy, 5)
            else
                hs.alert.show("✏️ No autocorrection to undo — and you have"
                              .. " not retyped a word for me to learn", 4)
            end
            return
        end
        acLast = nil

        -- Learn: rule fixes become permanent exceptions
        if last.wasRule then
            -- 📌 6.199.0 — THIS APPENDS WITHOUT LOOKING, AND THAT IS FINE.
            -- A duplicate row cannot happen in one session (once the word
            -- is allowed the rule stops firing, so ⇪Z has nothing to
            -- undo) and CAN happen across two Macs, where the other one
            -- has not reloaded since the row synced — which an in-memory
            -- check could never see. So the defence is downstream and
            -- provable: the loader counts DISTINCT words, and
            -- _G.autocorrectForget removes EVERY matching row. A guard
            -- here would be code no test could fail.
            autocorrectAllow[last.word] = true
            autocorrectAllowCount = autocorrectAllowCount + 1
            local f = io.open(autocorrectFile, "a")
            if f then
                f:write("allow," .. last.word .. ",\n")
                f:close()
                local at = autocorrectAllowLines[last.word] or {}
                at[#at + 1] = -1     -- appended; the real line is known next load
                autocorrectAllowLines[last.word] = at
            else
                core.warnWriteFailed("autocorrect.csv")
            end
        end

        -- Rewind the text if nothing has happened since the fix
        if last.undoSafe then
            -- Same drained guard as acInject (6.218.0): the restored
            -- word must not come back through this tap and be corrected
            -- again, and the expander must not read it as a trigger.
            acType(#last.fixed + #last.boundary, last.word .. last.boundary)
            -- An undo rewrites the document too — same reasoning as the
            -- injection above.
            if _G.expanderResetBuffer then pcall(_G.expanderResetBuffer) end
            hs.alert.show(last.wasRule
                and ("↩️ Restored " .. last.word .. " — an exception now"
                     .. ", on both Macs.\n_G.autocorrectForget(\""
                     .. last.word .. "\") undoes it")
                or  ("↩️ Restored " .. last.word .. " — to make permanent, delete the CSV row: fix," .. last.word:lower() .. "," .. last.fixed:lower()))
        else
            hs.alert.show(last.wasRule
                and ("✏️ " .. last.word .. " is an exception now, on both"
                     .. " Macs (text left as-is).\n_G.autocorrectForget(\""
                     .. last.word .. "\") undoes it")
                or  ("✏️ Noted — to stop fixing " .. last.word:lower() .. ", delete its row in autocorrect.csv"))
        end
    end)

    -- =====================================================================
    -- ⇪Z'S WAY BACK, AND THE REPORT THAT NAMES WHAT IT LEARNED (6.199.0)
    -- =====================================================================
    -- LL had to grep 11,000 lines of his own CSV to find `allow,HOw,` —
    -- one ⇪Z press, months ago, still switching the TWo-caps rule off for
    -- that word on both Macs. Permanent is fine; INVISIBLE is not.
    _G.rewrittenFiles = _G.rewrittenFiles or {}
    _G.rewrittenFiles[autocorrectFile] =
        "the autocorrect dictionary — rewritten whole ONLY by"
        .. " _G.autocorrectForget, one exception at a time"

    -- → ok, why. Removes every `allow,<word>,` row for one word, exactly
    -- as ⇪Z wrote it (case-sensitive, because the rule matches that way).
    function _G.autocorrectForget(word)
        if type(word) ~= "string" or word == "" then
            local why = 'give it a word, e.g. _G.autocorrectForget("HOw")'
            print("✏️ " .. why) ; return false, why
        end
        local f = io.open(autocorrectFile, "r")
        if not f then
            local why = "there is no " .. autocorrectFile .. " to edit"
            print("✏️ " .. why) ; return false, why
        end
        local content = f:read("*a") ; f:close()
        local kept, removed = {}, 0
        for line in content:gmatch("([^\r\n]+)") do
            local c = core.splitCSVLine(line)
            if c[1] == "allow" and c[2] == word then
                removed = removed + 1
            else
                kept[#kept + 1] = line
            end
        end
        if removed == 0 then
            local why = '"' .. word .. '" is not an exception in that file'
                        .. " — nothing was changed"
            print("✏️ " .. why) ; return false, why
        end
        -- 🚨 TEMP FILE THEN RENAME. This is the ONE thing that rewrites
        -- LL's dictionary whole, and it is 11,000 lines of his own work: a
        -- half-written file is far worse than a wrong exception. Nothing
        -- is destroyed until the complete replacement exists on disk.
        local tmp = autocorrectFile .. ".new"
        local out = io.open(tmp, "w")
        if not out then
            core.warnWriteFailed("autocorrect.csv")
            return false, "could not write beside " .. autocorrectFile
        end
        local okW = pcall(function() out:write(table.concat(kept, "\n") .. "\n") end)
        pcall(function() out:close() end)
        if not okW then
            os.remove(tmp)
            core.warnWriteFailed("autocorrect.csv")
            return false, "the write failed — your file is untouched"
        end
        if not os.rename(tmp, autocorrectFile) then
            os.remove(tmp)
            core.warnWriteFailed("autocorrect.csv")
            return false, "could not put the rewritten file in place"
                          .. " — your file is untouched"
        end
        autocorrectAllow[word]      = nil
        autocorrectAllowLines[word] = nil
        autocorrectAllowCount = math.max(0, autocorrectAllowCount - 1)
        local msg = "✏️ " .. word .. " is no longer an exception ("
                    .. removed .. " row" .. (removed == 1 and "" or "s")
                    .. " removed) — the TWo-caps rule will correct it again."
                    .. " The other Mac follows once OneDrive syncs and it"
                    .. " reloads."
        print(msg)
        pcall(function() hs.alert.show(msg, 4) end)
        return true, msg
    end

    -- 🔤 6.243.0 — AND THE WAY BACK, because a row a KEYPRESS wrote is
    -- exactly the thing 6.199.0 was written about: "anything this config
    -- LEARNS about LL's typing owes a report that names it and a one-liner
    -- that undoes it — a rule you can only find with grep is a rule you
    -- cannot govern." ⇪Z's `allow` rows have had that since 6.199.0; a fix
    -- row written by the same key would have had nothing but an
    -- 11,000-line CSV, which is the exact hole that release closed.
    --
    -- Removes EVERY `fix,<wrong>,...` row for one word — the duplicate the
    -- other Mac appends before it has reloaded included — through the same
    -- temp-file-then-rename rewriter, and it removes a HAND-WRITTEN row for
    -- that word too. That is deliberate: he asked to stop the word being
    -- rewritten, and leaving one row behind because it has no fourth column
    -- would mean the word goes on being rewritten after a command that said
    -- it would not.
    -- → ok, why
    function _G.autocorrectForgetFix(wrong)
        if type(wrong) ~= "string" or wrong == "" then
            local why = [[give it a word, e.g. _G.autocorrectForgetFix("makee")]]
            print("✏️ " .. why) ; return false, why
        end
        local key = wrong:lower()
        local f = io.open(autocorrectFile, "r")
        if not f then
            local why = "there is no " .. autocorrectFile .. " to edit"
            print("✏️ " .. why) ; return false, why
        end
        local content = f:read("*a") ; f:close()
        local kept, removed = {}, 0
        for line in content:gmatch("([^\r\n]+)") do
            local c = core.splitCSVLine(line)
            if c[1] == "fix" and type(c[2]) == "string" and c[2]:lower() == key then
                removed = removed + 1
            else
                kept[#kept + 1] = line
            end
        end
        if removed == 0 then
            local why = [["]] .. wrong .. [[" is not a fix row in that file]]
                        .. " — nothing was changed"
            print("✏️ " .. why) ; return false, why
        end
        -- 🚨 TEMP FILE THEN RENAME, for the same reason _G.autocorrectForget
        -- does it: this is 11,000 lines of his own work and a half-written
        -- file is far worse than one row too many.
        local tmp = autocorrectFile .. ".new"
        local out = io.open(tmp, "w")
        if not out then
            core.warnWriteFailed("autocorrect.csv")
            return false, "could not write beside " .. autocorrectFile
        end
        local okW = pcall(function() out:write(table.concat(kept, "\n") .. "\n") end)
        pcall(function() out:close() end)
        if not okW then
            os.remove(tmp)
            core.warnWriteFailed("autocorrect.csv")
            return false, "the write failed — your file is untouched"
        end
        if not os.rename(tmp, autocorrectFile) then
            os.remove(tmp)
            core.warnWriteFailed("autocorrect.csv")
            return false, "could not put the rewritten file in place"
                          .. " — your file is untouched"
        end
        if autocorrectDict[key] then
            autocorrectDictCount = math.max(0, autocorrectDictCount - 1)
        end
        autocorrectDict[key]   = nil
        autocorrectTaught[key] = nil
        local msg = "✏️ " .. key .. " is no longer corrected ("
                    .. removed .. " row" .. (removed == 1 and "" or "s")
                    .. " removed). The other Mac follows once OneDrive syncs"
                    .. " and it reloads."
        print(msg)
        pcall(function() hs.alert.show(msg, 4) end)
        return true, msg
    end

    -- ✏️ 6.205.0 — THE DOOR FOR A FIX ROW. LL: "How do I add an
    -- autocorrect entry like starets which should be starts?" The answer
    -- used to be "open an 11,000-line CSV in OneDrive and type a row at the
    -- bottom" — the same file ⇪Z appends to, so this appends the same way:
    -- one `fix,<wrong>,<right>` row, live in memory at once, on the other
    -- Mac after its next reload. → ok, why. It refuses rather than writes
    -- a row the loader would skip: a dead row (both sides the same word
    -- once lowered), an empty side, or a side carrying a comma or a line
    -- break, which would corrupt the file it is meant to help.
    function _G.autocorrectAdd(wrong, right, how)
        local function refuse(why)
            print("✏️ " .. why) ; return false, why
        end
        if type(wrong) ~= "string" or type(right) ~= "string"
           or wrong == "" or right == "" then
            return refuse('give it two words, e.g. _G.autocorrectAdd("intsead", "instead")')
        end
        if wrong:find("[,\r\n]") or right:find("[,\r\n]") then
            return refuse("a comma or a line break cannot go in a CSV row — nothing was written")
        end
        if autocorrectNoopRow(wrong, right) then
            return refuse('"' .. wrong .. '" and "' .. right .. '" are the same word once'
                          .. " lowered — that row would be skipped as dead (6.199.0),"
                          .. " so it was not written")
        end
        local f = io.open(autocorrectFile, "a")
        if not f then
            core.warnWriteFailed("autocorrect.csv")
            return refuse("could not append to " .. autocorrectFile .. " — nothing was written")
        end
        -- 🔤 6.243.0 — the optional fourth column, so the report can find
        -- this row again. A comma or a newline in it would corrupt the file
        -- the same way the two words would, so it is held to the same rule.
        local tag = ""
        if type(how) == "string" and how ~= "" and not how:find("[,\r\n]") then
            tag = "," .. how
        end
        local okW = pcall(function()
            f:write("fix," .. wrong:lower() .. "," .. right:lower() .. tag .. "\n")
        end)
        pcall(function() f:close() end)
        if not okW then
            core.warnWriteFailed("autocorrect.csv")
            return refuse("the write failed — nothing was added")
        end
        if not autocorrectDict[wrong:lower()] then
            autocorrectDictCount = autocorrectDictCount + 1
        end
        autocorrectDict[wrong:lower()] = right:lower()
        if tag ~= "" then
            local at = autocorrectTaught[wrong:lower()]
                       or { right = right:lower(), lines = {}, how = how }
            at.right, at.how = right:lower(), how
            at.lines[#at.lines + 1] = -1   -- appended; the line is known next load
            autocorrectTaught[wrong:lower()] = at
        end
        local msg = "✏️ " .. wrong:lower() .. " → " .. right:lower()
                    .. " is a fix row now — live here at once, on the other Mac"
                    .. " after OneDrive syncs and it reloads. To take it back:"
                    .. " _G.autocorrectForgetFix(" .. string.format("%q", wrong:lower()) .. ")"
        print(msg)
        pcall(function() hs.alert.show(msg, 4) end)
        return true, msg
    end

    function _G.autocorrectReport()
        local L = { "✏️ AUTOCORRECT" }
        L[#L + 1] = "   state        : " .. tostring(_G.autocorrectStatus)
                    .. (_G.autocorrectEnabled and "" or "  · PAUSED (⌃⌥⌘S)")
        L[#L + 1] = "   file         : " .. autocorrectFile
        L[#L + 1] = "   dictionary   : " .. autocorrectDictCount .. " fix row(s)"
        L[#L + 1] = "   exceptions   : " .. autocorrectAllowCount
                    .. " word(s) the TWo-caps rule leaves alone"
        local learned = {}
        for w in pairs(autocorrectAllow) do
            if not autocorrectDefaultSet[w] then learned[#learned + 1] = w end
        end
        table.sort(learned)
        -- 🔎 "nothing learned" and "never loaded" must not read the same,
        -- and neither may read like a list that was simply not printed.
        if not autocorrectLoaded then
            L[#L + 1] = "   ⇪Z learned  : the file has not been read yet"
        elseif #learned == 0 then
            L[#L + 1] = "   ⇪Z learned  : nothing on this Mac — every exception"
                        .. " above is one this config ships with"
        else
            L[#L + 1] = "   ⇪Z learned  : " .. #learned .. " — these are YOURS."
                        .. " They are permanent and they reach the other Mac:"
            for _, w in ipairs(learned) do
                local at = autocorrectAllowLines[w] or {}
                local where = {}
                for _, n in ipairs(at) do
                    where[#where + 1] = (n == -1) and "added just now" or tostring(n)
                end
                L[#L + 1] = ("      %-18s line %-14s _G.autocorrectForget(%q)")
                            :format(w, table.concat(where, ", "), w)
            end
        end
        if #autocorrectNoop > 0 then
            L[#L + 1] = "   ⚠️ dead rows : " .. #autocorrectNoop
                        .. " `fix` row(s) whose two sides are the same word,"
            L[#L + 1] = "                  SKIPPED. Obeyed, they turn IDs into"
            L[#L + 1] = "                  Ids and cost the TWo-caps rule its"
            L[#L + 1] = "                  turn on that word. Your file is not"
            L[#L + 1] = "                  touched — delete them when you like:"
            for i, r in ipairs(autocorrectNoop) do
                if i > 20 then
                    L[#L + 1] = ("      …and %d more"):format(#autocorrectNoop - 20)
                    break
                end
                L[#L + 1] = ("      line %-8d fix,%s,%s"):format(r.line, r.wrong, r.right)
            end
        else
            L[#L + 1] = "   dead rows    : none"
        end
        -- 📖 6.200.0 — the word list, and every reason it might not be
        -- answering. "Not loaded yet", "no file", "off" and "ready but it
        -- has never had to change anything" are four different things and
        -- must never read as one.
        L[#L + 1] = "   word list    : " .. acSpellState
                    .. (acSpellState == "ready"
                        and ("  · " .. acSpellCount .. " words · "
                             .. acSpell.wordsFile) or "")
        L[#L + 1] = "   spelling     : " .. acSpellFixed
                    .. " word(s) corrected from it this session"
                    .. (acSpellDown > 0
                        and ("  · stood down " .. acSpellDown
                             .. "× (a password field or an app below)") or "")
        if #acSpellFixes > 0 then
            for _, r in ipairs(acSpellFixes) do
                L[#L + 1] = "      " .. r
            end
            L[#L + 1] = "      ↳ any of these wrong? ⇪Z right after it, or"
            L[#L + 1] = "        _G.autocorrectForget(\"<the word>\") later."
        end
        L[#L + 1] = "   apostrophe   : "
                    .. (acApostrophe == 0
                        and "no word ended on a ' yet this session"
                        or (acApostrophe .. " piece(s) before a ' — dictionary"
                            .. " and TWo-caps only, never the word list"))
        -- 🔤 6.243.0 — WHAT ⇪Z LEARNED FROM HIS OWN TYPING, and the one
        -- line that takes each back. 6.199.0's rule, paid in the other
        -- column: permanent and cross-machine is fine, invisible is not.
        local taught = {}
        for w in pairs(autocorrectTaught) do taught[#taught + 1] = w end
        table.sort(taught)
        if not autocorrectLoaded then
            L[#L + 1] = "   ⇪Z taught   : the file has not been read yet"
        elseif #taught == 0 then
            L[#L + 1] = "   ⇪Z taught   : nothing — no fix row here was written"
                        .. " by a keypress"
        else
            L[#L + 1] = "   ⇪Z taught   : " .. #taught .. " — these are YOURS."
                        .. " They are permanent and they reach the other Mac:"
            for _, w in ipairs(taught) do
                local at = autocorrectTaught[w]
                local where = {}
                for _, n in ipairs(at.lines or {}) do
                    where[#where + 1] = (n == -1) and "added just now" or tostring(n)
                end
                L[#L + 1] = ("      %-14s → %-14s line %-14s _G.autocorrectForgetFix(%q)")
                            :format(w, tostring(at.right), table.concat(where, ", "), w)
            end
        end
        -- 🔎 THREE STATES, AND THEY DECIDE WHETHER THE KEY LOOKS BROKEN:
        -- switched off · armed and waiting · nothing offered and why not.
        if acSpell.selfLearn == false then
            L[#L + 1] = "   self-fix     : OFF — settings = { autocorrect ="
                        .. " { selfLearn = false } }"
        else
            local p = acSelf.pair
            local age = p and (os.time() - (p.at or 0)) or nil
            local live = p and age <= (tonumber(acSpell.selfSecs) or 30)
            L[#L + 1] = "   self-fix     : " .. acSelf.armed .. " pair(s) armed · "
                        .. acSelf.learned .. " written by ⇪Z · offered for "
                        .. tostring(acSpell.selfSecs) .. "s"
            if live then
                L[#L + 1] = "      ↳ NOW: ⇪Z writes " .. p.wrong .. " → " .. p.right
                            .. " (" .. age .. "s ago)"
            elseif p then
                L[#L + 1] = "      ↳ the last pair (" .. p.wrong .. " → " .. p.right
                            .. ") is " .. age .. "s old — too late now"
            elseif acSelf.lastWhy then
                L[#L + 1] = "      ↳ nothing offered. Last retype: " .. acSelf.lastWhy
            else
                L[#L + 1] = "      ↳ nothing offered — no word has been"
                            .. " backspaced over and retyped yet"
            end
        end
        L[#L + 1] = "   retype guard : "
                    .. (acDrain.retypes == 0 and "no retype yet this session"
                        or (acDrain.retypes .. " retype(s) · released by count "
                            .. acDrain.byCount .. " · by timer " .. acDrain.byTimer))
                    .. (acInjecting and ("  · UP NOW, " .. acInjectPending
                                         .. " key(s) still to drain") or "")
        L[#L + 1] = "   not asked in : " .. table.concat(acSpell.offIn or {}, ", ")
        L[#L + 1] = "                  (and any password field)"
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    -- Boot: needs Accessibility; degrade politely without it
    local acAxOK = false
    pcall(function() acAxOK = hs.accessibilityState() end)
    _G.autocorrectStatus = "off"
    if acAxOK then
        local started = false
        pcall(function() _G.autocorrectTap:start(); started = true end)
        if started then
            _G.autocorrectStatus = "ON (dictionary loading…)"

            -- ⏱ 6.40.0 — PHASE TWO: THE DICTIONARY LOADS AFTER BOOT.
            -- Parsing an 11,000-row CSV was the single most expensive
            -- thing this config did during startup, and it bought
            -- nothing: a typo-corrector cannot help you in the second
            -- before your desktop has even drawn. The event tap starts
            -- immediately (so nothing is missed structurally), and the
            -- dictionary arrives a couple of seconds later via the
            -- loader's warm() phase. Between the two, typing is simply
            -- not corrected — which is the same as autocorrect being
            -- off, not a broken state.
            function M.warm(core)
                if not started then return end
                local t0 = hs.timer.secondsSinceEpoch()
                autocorrectSeedIfMissing()
                autocorrectLoad()
                acSpellLoad()          -- 6.200.0; slices itself, never blocks
                _G.autocorrectStatus = string.format(
                    "ON (%d fixes, %d exceptions, ⌃⌥⌘S toggles)",
                    autocorrectDictCount, autocorrectAllowCount)
                _G.diag.say("autocorrect", string.format(
                    "dictionary loaded: %d fixes, %d exceptions, %.0fms",
                    autocorrectDictCount, autocorrectAllowCount,
                    (hs.timer.secondsSinceEpoch() - t0) * 1000))
            end

            -- Lesson from the brightness saga: macOS silently disables event
            -- taps it thinks are slow. A watchdog quietly revives ours.
            local function autocorrectRevive()
                pcall(function()
                    if _G.autocorrectTap and not _G.autocorrectTap:isEnabled() then
                        _G.autocorrectTap:start()
                        print("✏️ Autocorrect tap was disabled by macOS — revived")
                    end
                end)
            end
            _G.autocorrectWatchdog = hs.timer.doEvery(30, autocorrectRevive)

            -- 🔋 6.144.0 — on battery the revive check runs every two
            -- minutes instead of every thirty seconds. The honest cost:
            -- a tap macOS kills on battery could stay dead up to two
            -- minutes before revival — typing is simply not corrected in
            -- that window, the same as autocorrect being off. Running
            -- state is preserved across the rebuild so the lag probe's
            -- held-down watchdog stays held down (core/lag.lua pauses
            -- these BY NAME and restarts by name too, so the new object
            -- under the old name is exactly what it will restart).
            if _G.eco then
                _G.eco.register("autocorrect watchdog", {
                    normal = 30, saver = 120,
                    apply = function(secs)
                        local was, running = _G.autocorrectWatchdog, true
                        pcall(function() running = was:running() end)
                        if was then pcall(function() was:stop() end) end
                        _G.autocorrectWatchdog = hs.timer.doEvery(secs, autocorrectRevive)
                        if not running then
                            pcall(function() _G.autocorrectWatchdog:stop() end)
                        end
                    end,
                })
            end
        else
            _G.autocorrectStatus = "OFF (event tap failed to start)"
        end
    else
        _G.autocorrectStatus = "OFF (needs Accessibility — files fine, no permission for typing watcher)"
    end
end

return M
