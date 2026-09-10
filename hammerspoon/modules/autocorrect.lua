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
            { "⇪Z", "Undo last fix & learn the exception — reversible" },
            { "auto", "Fixes typos & TWo-caps as you type (autocorrect.csv)" },
            { "see", "_G.autocorrectReport() — what ⇪Z has learned, and how"
                     .. " to unlearn it (_G.autocorrectForget \"HOw\")" }
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
    --     off — so two candidates does nothing at all.
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
    local function acSpellCorrection(word, known, minLen)
        if type(word) ~= "string" or type(known) ~= "function" then return nil end
        minLen = tonumber(minLen) or 4
        if #word < minLen then return nil end
        -- Letters only, and at most ONE leading capital. This single test
        -- is what keeps IDs, iPhone, SKU7, don't and camelCase out.
        local capped = word:match("^%u%l+$") ~= nil
        if not (word:match("^%l+$") or capped) then return nil end
        local w = word:lower()
        if known(w) then return nil end            -- it is already a word

        local seen, hits, n = {}, nil, 0
        local function try(cand)
            if cand == w or seen[cand] then return end
            seen[cand] = true
            if known(cand) then n = n + 1 ; hits = cand end
        end
        for i = 1, #w - 1 do                        -- swap two neighbours
            try(w:sub(1, i - 1) .. w:sub(i + 1, i + 1) .. w:sub(i, i)
                .. w:sub(i + 2))
        end
        -- 🚨 ONE LETTER TOO MANY — BUT ONLY A LETTER THAT WAS ALREADY
        -- COMING. Deleting ANY letter is where a word list starts
        -- rewriting words it has simply never heard of. MEASURED against
        -- the real /usr/share/dict/words: unrestricted deletion turned
        -- rsync into sync, backend into backed and frontend into fronted
        -- — three of 104 ordinary words, which is three too many for a
        -- feature that edits LL's text without asking. Restricting it to
        -- a letter that REPEATS within the next two positions — a doubled
        -- letter (somethingg, somethinng) or one typed early
        -- (somtething) — caught MORE typos, 17 of 18 including all five
        -- LL listed by name, and changed NONE of those 104 words.
        for i = 1, #w do
            if w:sub(i, i) == w:sub(i + 1, i + 1)
               or w:sub(i, i) == w:sub(i + 2, i + 2) then
                try(w:sub(1, i - 1) .. w:sub(i + 1))
            end
        end
        for i = 1, #w + 1 do                        -- one letter missing
            for c = 97, 122 do
                try(w:sub(1, i - 1) .. string.char(c) .. w:sub(i))
            end
        end
        for i = 1, #w - 2 do                        -- three turned round
            try(w:sub(1, i - 1) .. w:sub(i + 2, i + 2) .. w:sub(i + 1, i + 1)
                .. w:sub(i, i) .. w:sub(i + 3))
        end
        -- 🚨 EXACTLY ONE. Two real words a single edit away is a guess,
        -- and this feature is only worth having if it never guesses.
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

    local function acInject(word, fixed, boundary, wasRule)
        acInjecting = true
        -- 🚨 6.69.0 — THROUGH THE SHARED GUARD. acInjecting only ever told
        -- THIS tap to stand down. The text expander has its own tap on the
        -- same keystrokes, and without a shared flag a correction that
        -- happens to end in a snippet trigger fires that snippet — a
        -- spelling fix that expands into an email signature. See
        -- _G.withInjection in init.lua. The local flag stays because it is
        -- what protects this module when the shared one is unavailable.
        local ok = (_G.withInjection or pcall)(function()
            for _ = 1, #word do
                hs.eventtap.keyStroke({}, "delete", 0)
            end
            hs.eventtap.keyStrokes(fixed .. boundary)
        end)
        acInjecting = false
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
            if acInjecting then return false end
            if _G.typingInjection and _G.typingInjection() then return false end

            local t = ev:getType()
            if t == hs.eventtap.event.types.leftMouseDown
               or t == hs.eventtap.event.types.rightMouseDown then
                acBuffer = ""
                if acLast then acLast.undoSafe = false end   -- cursor moved
                return false
            end

            local flags = ev:getFlags()
            if flags.cmd or flags.ctrl then
                acBuffer = ""
                return false   -- chords (incl. ⌃⌥⌘Z itself) don't spoil undo
            end

            local code = ev:getKeyCode()
            if code == 51 then                       -- delete: trim buffer
                if #acBuffer > 0 then acBuffer = acBuffer:sub(1, -2) end
                if acLast then acLast.undoSafe = false end
                return false
            end
            if acClearKeycodes[code] then
                acBuffer = ""
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
                if _G.autocorrectEnabled and #word >= 2 then
                    local fixed, source = autocorrectFor(word, acSpellHereOK())
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
            hs.alert.show("✏️ No autocorrection to undo")
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
            acInjecting = true
            -- Same shared guard as acInject: an undo types too, and the
            -- expander must not read the restored word as a trigger.
            ;(_G.withInjection or pcall)(function()
                for _ = 1, #last.fixed + #last.boundary do
                    hs.eventtap.keyStroke({}, "delete", 0)
                end
                hs.eventtap.keyStrokes(last.word .. last.boundary)
            end)
            acInjecting = false
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
