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
    cheatsheet = {
        title = "✏️ AUTOCORRECT",
        entries = {
            { "⇪S", "Toggle on/off" },
            { "⇪Z", "Undo last fix & learn the exception" },
            { "auto", "Fixes typos & TWo-caps as you type (autocorrect.csv)" }
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

    _G.autocorrectEnabled = true
    local autocorrectDict, autocorrectAllow = {}, {}
    local autocorrectDictCount, autocorrectAllowCount = 0, 0

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

    local function autocorrectLoad()
        autocorrectDict, autocorrectAllow = {}, {}
        autocorrectDictCount, autocorrectAllowCount = 0, 0
        local f = io.open(autocorrectFile, "r")
        if not f then return false end
        local content = f:read("*a"); f:close()
        local first = true
        for line in content:gmatch("([^\r\n]+)") do
            if not (first and line:match("^type,")) then
                local c = core.splitCSVLine(line)
                local kind, wrong, right = c[1], c[2], c[3]
                if kind == "fix" and wrong and right and wrong ~= "" and right ~= "" then
                    autocorrectDict[wrong:lower()] = right:lower()
                    autocorrectDictCount = autocorrectDictCount + 1
                elseif kind == "allow" and wrong and wrong ~= "" then
                    autocorrectAllow[wrong] = true
                    autocorrectAllowCount = autocorrectAllowCount + 1
                end
            end
            first = false
        end
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

    -- The decision for one completed word: returns the corrected word, or
    -- nil if it's fine as typed. Dictionary first, then the TWo-caps rule.
    local function autocorrectFor(word)
        if #word < 2 then return nil end
        local hit = autocorrectDict[word:lower()]
        if hit then
            local fixed = autocorrectApplyCase(word, hit)
            if fixed ~= word then return fixed end
            return nil
        end
        if #word >= 3 and word:match("^%u%u%l") and word:match("^%a+$")
           and not autocorrectAllow[word] then
            return word:sub(1, 1) .. word:sub(2, 2):lower() .. word:sub(3)
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

    local function acIsExcludedApp()
        local ok, app = pcall(hs.application.frontmostApplication)
        if not ok or not app then return false end
        local okN, name = pcall(function() return app:name() end)
        if not okN or not name then return false end
        for _, ex in ipairs(autocorrectExcludedApps) do
            if name == ex then return true end
        end
        return false
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

    _G.autocorrectTap = hs.eventtap.new(
        { hs.eventtap.event.types.keyDown,
          hs.eventtap.event.types.leftMouseDown,
          hs.eventtap.event.types.rightMouseDown },
        function(ev)
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
                    local fixed = autocorrectFor(word)
                    if fixed and not acIsExcludedApp() then
                        local wasRule = (autocorrectDict[word:lower()] == nil)
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
            autocorrectAllow[last.word] = true
            autocorrectAllowCount = autocorrectAllowCount + 1
            local f = io.open(autocorrectFile, "a")
            if f then
                f:write("allow," .. last.word .. ",\n")
                f:close()
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
            hs.alert.show(last.wasRule
                and ("↩️ Restored " .. last.word .. " — added to exceptions permanently")
                or  ("↩️ Restored " .. last.word .. " — to make permanent, delete the CSV row: fix," .. last.word:lower() .. "," .. last.fixed:lower()))
        else
            hs.alert.show(last.wasRule
                and ("✏️ " .. last.word .. " added to exceptions for next time (text left as-is)")
                or  ("✏️ Noted — to stop fixing " .. last.word:lower() .. ", delete its row in autocorrect.csv"))
        end
    end)

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
            _G.autocorrectWatchdog = hs.timer.doEvery(30, function()
                pcall(function()
                    if _G.autocorrectTap and not _G.autocorrectTap:isEnabled() then
                        _G.autocorrectTap:start()
                        print("✏️ Autocorrect tap was disabled by macOS — revived")
                    end
                end)
            end)
        else
            _G.autocorrectStatus = "OFF (event tap failed to start)"
        end
    else
        _G.autocorrectStatus = "OFF (needs Accessibility — files fine, no permission for typing watcher)"
    end
end

return M
