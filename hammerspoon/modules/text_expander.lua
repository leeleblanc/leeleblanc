-- =====================================================================
-- MODULE: TEXT EXPANDER (⇪⇧T) — Alfred snippets, typed anywhere
-- =====================================================================
-- LL: "Snippets attached. Some have a trigger convention and some are
-- just three letter combos like gg1 … Not all my snippets require a
-- prefix. Ghostty does. Textapanders doesn't it's three letters instead."
--
-- Type a trigger, get the text. `;bd` becomes "Brew doctor"; `gg1`
-- becomes whatever you set it to. Both conventions work at once, which
-- is the entire point — the prefix is a property of the COLLECTION the
-- snippet came from, not a rule the expander imposes.
--
-- ---- WHERE SNIPPETS COME FROM ---------------------------------------
-- Alfred's .alfredsnippets file is a ZIP. Inside it, one JSON per
-- snippet plus an info.plist:
--
--     Brew doctor [C3603EB7-…].json
--        { "alfredsnippet": { "snippet": "Brew doctor",
--                             "keyword": ";bd", "name": "Brew doctor" } }
--     info.plist
--        <key>snippetkeywordprefix</key><string></string>
--        <key>snippetkeywordsuffix</key><string></string>
--
-- The plist prefix/suffix are the COLLECTION-WIDE convention, and they
-- are what makes the two styles coexist: a collection exported with
-- prefix ";" has bare keywords in its JSON and gets the ";" added here,
-- while LL's own export has an EMPTY prefix because the ";" is already
-- baked into each keyword. Read both, apply the plist, and `;bd` and
-- `gg1` come out the far end as equals. Nothing is hard-coded.
--
--     ⇪⇧T                    search and insert a snippet by name
--     _G.snippetsImport()    find and import every .alfredsnippets file
--                            in ~/Downloads, ~/Desktop or ~
--     _G.snippetsImport(p)   import one by path
--     _G.snippetAdd(t, txt)  write one by hand
--     _G.snippetsList()      print every trigger loaded, and every one
--                            that did NOT load, with the reason
--
-- ---- 🚨 THIS MODULE WATCHES EVERY KEYSTROKE YOU TYPE -----------------
-- There is no other way to build an expander, and it is the reason for
-- every rule below:
--   · NOTHING IS EVER LOGGED. Not the buffer, not to the console, not to
--     the ledger, not in a diagnostic. The only thing that leaves this
--     module is the NAME of a snippet that fired.
--   · The buffer holds expander.bufferMax characters and no more.
--   · macOS "secure input" switches event taps off inside password
--     fields, so those are structurally unreachable from here — that is
--     the OS protecting you, not a promise this file makes.
--   · expander.excludedApps is exact-name, and terminal apps that
--     already have their own expansion belong in it.
--   · The tap is revived when macOS disables it, on the same 30s
--     watchdog autocorrect uses, because a silently dead expander is
--     rule #7's exact failure mode.
--   · expander.enabled = false, or the ⏸ row in ⇪⇧T, stops it dead
--     while leaving the tap running — the flag is checked per keystroke.
--
-- ---- 🧨 WHY A BARE `gg1` DOES NOT FIRE INSIDE A WORD -----------------
-- Suffix matching alone means a trigger fires the moment the last of its
-- characters is typed, WHEREVER it lands. With three-letter triggers
-- that is a live hazard: `abc` would expand in the middle of "fabcd".
-- So a trigger that STARTS with a letter or digit also needs a word
-- boundary in front of it (start of buffer, whitespace, or punctuation).
-- A trigger that starts with punctuation — `;bd`, `:sig`, `\\eml` — is
-- exempt, because that leading character IS the boundary and requiring
-- another one would break the very convention it exists to serve.
-- expander.wordStartOnly = false restores plain Alfred behaviour.

local M = {
    name  = "Text Expander",
    order = 13.58,         -- beside the tool picker; autocorrect shares its machinery
    cheatsheet = {
        title = "✂️ TEXT EXPANDER (Alfred snippets)",
        entries = {
            { "⇪⇧T",   "Search your snippets and insert one" },
            { "type",  "A trigger expands as you type it — ;bd or gg1, both work" },
            { "add",   "_G.snippetAdd(\"gg1\", \"text\") in the Console" },
            { "import", "_G.snippetsImport() — finds .alfredsnippets in ~/Downloads" },
            { "list",  "_G.snippetsList() — every trigger, in the Console" },
            { "{cursor}", "In a snippet: where the caret lands afterwards" },
            { "{clipboard}", "In a snippet: whatever is on the clipboard" },
            { "{date} {time}", "In a snippet: today, and now" },
            { "off",   "expander.enabled = false, or the ⏸ row in ⇪⇧T" },
            { "never", "Nothing you type is ever logged — see the module header" },
        },
    },
}

function M.setup(core)
    local exp = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    exp.enabled       = true
    exp.key           = "t"       -- ⇪⇧T — the snippet chooser
    exp.dir           = core.logsDir .. "/snippets"
    exp.bufferMax     = 64        -- characters of typing kept in memory
    exp.maxChars      = 2000      -- a snippet longer than this is REFUSED
    exp.wordStartOnly = true      -- see the 🧨 note in the header
    exp.injectDelay   = 0.01      -- let the app settle before we retype
    -- Snippets longer than this, and ANY snippet containing a newline,
    -- are pasted rather than typed. See the 📋 note at pasteText.
    exp.pasteOver     = 80
    exp.restoreAfter  = 0.25      -- seconds before your clipboard comes back
    -- How long a trigger that is a PREFIX of a longer trigger waits to see
    -- whether you are still typing. Only affects those few — !!del and
    -- !!tab in LL's Mac symbols pack. Everything else fires immediately.
    exp.ambiguityWait = 0.35
    exp.slowLoadSecs  = 2.0       -- past this, the scan reports itself
    exp.excludedApps  = {         -- exact names; expansion never runs here
        "Terminal",
    }
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("expander", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("expander", m) end end

    exp.snippets   = {}    -- trigger -> { text, name, source }
    exp.count      = 0
    exp.longest    = 0     -- characters in the longest trigger
    exp.status     = "off"
    exp.lastFired  = nil   -- { name, trigger, at } — for ⇪⇧D, never the buffer

    -- ---- reading the files ----------------------------------------------
    -- utf8-aware length: triggers are ASCII in practice but the delete
    -- count is a CHARACTER count, and one wrong assumption there deletes
    -- somebody's sentence.
    local function clen(s)
        local n = utf8 and utf8.len(s)
        return n or #s
    end

    local function readFile(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local c = f:read("*a")
        f:close()
        return c
    end

    -- The collection-wide convention. Both keys are optional and BOTH ARE
    -- ROUTINELY EMPTY — LL's own export has empty strings for each, which
    -- is not a parse failure, it is the file saying "the prefix is
    -- already in the keywords". An absent key and an empty key mean the
    -- same thing here, so both come back as "".
    local function readPlist(dir)
        local c = readFile(dir .. "/info.plist")
        if not c then return "", "" end
        local function val(key)
            local v = c:match("<key>" .. key .. "</key>%s*<string>(.-)</string>")
            return v or ""
        end
        return val("snippetkeywordprefix"), val("snippetkeywordsuffix")
    end

    -- One Alfred JSON file. Always four values, in one shape:
    --     trigger, text, name, reason
    -- A loadable snippet returns a trigger; a snippet Alfred saved with NO
    -- keyword returns nil for the trigger but still returns its text, so
    -- it is insertable from ⇪⇧T even though nothing can type it (that is a
    -- legitimate Alfred snippet, not a fault); anything broken returns a
    -- reason and nothing else.
    --
    -- 🚨 THE SHAPE IS UNIFORM ON PURPOSE. The first draft of this returned
    -- the reason in slot 2 for one case and the text in slot 2 for the
    -- other, which made the caller file every keyword-less snippet under
    -- its own error message. A function whose return positions change
    -- meaning is a function that will be misread — including by me.
    local function readSnippet(path, prefix, suffix)
        local raw = readFile(path)
        if not raw then return nil, nil, nil, "unreadable" end
        local ok, obj = pcall(hs.json.decode, raw)
        if not (ok and type(obj) == "table") then
            return nil, nil, nil, "not valid JSON"
        end
        local s = obj.alfredsnippet
        if type(s) ~= "table" then return nil, nil, nil, "no alfredsnippet key" end
        local text = s.snippet
        if type(text) ~= "string" or text == "" then
            return nil, nil, nil, "empty snippet"
        end
        -- 🚨 CRLF IS NORMALISED AT LOAD. Alfred stores what was on the
        -- clipboard when the snippet was made, and two of LL's — kn1
        -- ("Kindly,\r\nLL") and ll1 — carry Windows line endings. A lone
        -- CR is a Return to macOS: pasted into a chat box, "Kindly," would
        -- send on its own and "LL" would become a second message. One
        -- gsub here is worth more than any amount of care later.
        text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
        if clen(text) > exp.maxChars then
            return nil, nil, nil, string.format("%d characters — over the %d limit",
                                                clen(text), exp.maxChars)
        end
        local name = s.name
        if type(name) ~= "string" or name == "" then name = nil end
        local kw = s.keyword
        if type(kw) ~= "string" or kw == "" then
            return nil, text, name, nil          -- chooser only
        end
        return prefix .. kw .. suffix, text, name or kw, nil
    end

    -- Scan one directory of .json files. Collections are subdirectories
    -- (that is how an import lands); loose .json in the top level works
    -- too, with no prefix, so a single file can just be dropped in.
    local function scanDir(dir, label, into, problems, chooserOnly)
        local okIter, iter = pcall(hs.fs.dir, dir)
        if not okIter or not iter then return 0, 0 end
        local prefix, suffix = readPlist(dir)
        local loaded, subdirs = 0, {}
        for entry in iter do
            if entry ~= "." and entry ~= ".." then
                local full = dir .. "/" .. entry
                local attrs = hs.fs.attributes(full) or {}
                if attrs.mode == "directory" then
                    subdirs[#subdirs + 1] = { full, entry }
                elseif entry:sub(-5) == ".json" then
                    local trigger, text, name, reason = readSnippet(full, prefix, suffix)
                    if trigger then
                        if into[trigger] then
                            problems[#problems + 1] = string.format(
                                "%s: trigger %s already used by %s — the later one wins",
                                label, trigger, tostring(into[trigger].name))
                        end
                        into[trigger] = { text = text, name = name, source = label }
                        loaded = loaded + 1
                    elseif text then
                        -- keyword-less: usable from the chooser only
                        chooserOnly[#chooserOnly + 1] =
                            { text = text, name = name or entry:gsub("%.json$", ""),
                              source = label }
                    else
                        problems[#problems + 1] = label .. "/" .. entry
                                                  .. ": " .. tostring(reason)
                    end
                end
            end
        end
        local subLoaded = 0
        for _, d in ipairs(subdirs) do
            local n = scanDir(d[1], d[2], into, problems, chooserOnly)
            subLoaded = subLoaded + n
        end
        return loaded + subLoaded
    end

    -- 🚨 EVERY PROBLEM IS REPORTED. A snippet that did not load is a
    -- trigger you will type and watch do nothing, and "it just didn't
    -- work" is the single least debuggable sentence in this config.
    function exp.load()
        local t0 = hs.timer.secondsSinceEpoch()
        local into, problems, chooserOnly = {}, {}, {}
        local attrs = hs.fs.attributes(exp.dir)
        if not attrs then
            local okMk = hs.fs.mkdir(exp.dir)
            if not okMk then
                exp.status = "OFF (cannot create " .. exp.dir .. ")"
                warn("could not create the snippets folder: " .. exp.dir)
                if _G.notices then
                    _G.notices.record("expander", "snippets folder",
                                      "could not create " .. exp.dir)
                end
                return false
            end
            say("created the snippets folder: " .. exp.dir)
        end

        scanDir(exp.dir, "snippets", into, problems, chooserOnly)

        exp.snippets    = into
        exp.chooserOnly = chooserOnly
        exp.count, exp.longest, exp.longestBytes = 0, 0, 0
        for trigger in pairs(into) do
            exp.count = exp.count + 1
            local n = clen(trigger)
            if n > exp.longest then exp.longest = n end
            if #trigger > exp.longestBytes then exp.longestBytes = #trigger end
        end
        exp.buildIndex()
        exp.problems = problems
        if #problems > 0 then
            table.sort(problems)
            for _, p in ipairs(problems) do
                print("✂️ Text expander: " .. p)
            end
            if _G.notices then
                _G.notices.record("expander", "snippets that did not load",
                                  table.concat(problems, " · "))
            end
        end
        exp.loadSecs = hs.timer.secondsSinceEpoch() - t0
        say(string.format("loaded %d triggers in %.0fms (longest %d chars, %d "
                          .. "trie nodes, %d waiting), %d chooser-only, %d problems",
                          exp.count, exp.loadSecs * 1000, exp.longest,
                          exp.indexNodes or 0, exp.ambiguousCount or 0,
                          #chooserOnly, #problems))
        -- 🚨 A SLOW SCAN IS REPORTED WITH ITS NUMBER, not left to be felt.
        -- The snippets live in the OneDrive Logs folder, shared with the
        -- other Mac like autocorrect.csv — and two thousand tiny files in
        -- a synced folder is exactly the shape that OneDrive Files
        -- On-Demand turns into two thousand downloads. This runs in warm()
        -- so it is off the boot path either way, but a scan that has gone
        -- from a quarter of a second to twenty is a fact worth having
        -- rather than a Mac that feels wrong after login.
        if exp.loadSecs > exp.slowLoadSecs then
            print(string.format(
                "✂️ Text expander: reading %d snippets took %.1fs from %s. "
                .. "If that folder is on OneDrive, its files may be cloud-only "
                .. "placeholders — mark it \"Always keep on this device\", or "
                .. "set expander.dir to a local path.",
                exp.count, exp.loadSecs, exp.dir))
            if _G.notices then
                _G.notices.record("expander", "slow snippet scan",
                    string.format("%.1fs for %d files in %s",
                                  exp.loadSecs, exp.count, exp.dir))
            end
        end
        return true
    end

    -- ---- placeholders ----------------------------------------------------
    -- Alfred's dynamic tokens. The four that are cheap and unambiguous are
    -- supported; anything else in braces is LEFT EXACTLY AS TYPED and
    -- reported, rather than silently deleted — a snippet that quietly
    -- loses "{date:yyyy}" is worse than one that visibly contains it.
    -- {cursor} is handled by the caller (it needs arrow keys, not text).
    function exp.substitute(text, seenUnknown)
        local out = text
        out = out:gsub("{clipboard}", function()
            local ok, c = pcall(hs.pasteboard.getContents)
            return (ok and c) or ""
        end)
        out = out:gsub("{date}", os.date("%Y-%m-%d"))
        out = out:gsub("{time}", os.date("%H:%M"))
        for token in out:gmatch("{(%a[%w:%-%. ]*)}") do
            if token ~= "cursor" and seenUnknown and not seenUnknown[token] then
                seenUnknown[token] = true
                print("✂️ Text expander: {" .. token .. "} is not a placeholder this "
                      .. "config knows — it was inserted literally. Supported: "
                      .. "{cursor} {clipboard} {date} {time}")
            end
        end
        return out
    end

    -- ---- typing it out ---------------------------------------------------
    exp.injecting = false
    _G.expanderTimers = {}          -- HELD: an unreferenced timer never fires
    exp.unknownSeen = {}

    local function hold(t)
        table.insert(_G.expanderTimers, t)
        while #_G.expanderTimers > 8 do table.remove(_G.expanderTimers, 1) end
        return t
    end

    -- deleteCount is the number of characters ALREADY IN THE DOCUMENT, so
    -- it is the trigger minus its final character: that keystroke was
    -- consumed by the tap and never reached the app.
    -- 📋 WHY SOME SNIPPETS ARE PASTED INSTEAD OF TYPED.
    -- hs.eventtap.keyStrokes sends text as synthetic key events. For a
    -- word or an emoji that is exactly right — fast, and it leaves your
    -- clipboard alone. For anything with a NEWLINE in it it is dangerous:
    -- a synthetic Return inside a chat box, a Teams message or an Asana
    -- comment SENDS the thing instead of breaking the line. LL has eight
    -- such snippets — the out-of-office, the book-recommendation reply,
    -- the Asana and OCLC blocks — and they are precisely the ones where
    -- firing early would be most embarrassing.
    --
    -- So: multi-line or long → the clipboard, ⌘V, and put the old
    -- contents straight back. Everything else is typed.
    --
    -- ⚠️ THE RESTORE IS NOT OPTIONAL AND NOT BEST-EFFORT. Borrowing
    -- someone's clipboard and forgetting to give it back is worse than
    -- not having the feature. It restores on the failure path too.
    local function shouldPaste(text)
        return text:find("\n", 1, true) ~= nil or clen(text) > exp.pasteOver
    end

    local function pasteText(text)
        local okRead, prior = pcall(hs.pasteboard.getContents)
        if _G.pasteboardSuppress then _G.pasteboardSuppress(exp.restoreAfter + 1.0) end
        local okSet = pcall(function() hs.pasteboard.setContents(text) end)
        if not okSet then return false, "could not put the snippet on the clipboard" end
        local okPaste = pcall(function() hs.eventtap.keyStroke({ "cmd" }, "v", 0) end)
        -- The restore is DELAYED, not immediate: ⌘V is asynchronous from
        -- here — the paste is a synthetic event the app has not processed
        -- yet — and putting the old text back in the same breath is a race
        -- the app loses, pasting whatever was there before.
        hold(hs.timer.doAfter(exp.restoreAfter, function()
            pcall(function()
                hs.pasteboard.setContents((okRead and prior) or "")
            end)
        end))
        if not okPaste then return false, "⌘V was refused" end
        return true
    end

    -- tail: characters that were typed AFTER the trigger and consumed by
    -- us, which have to reappear after the snippet. Only the deferred
    -- path uses it — see the ⏳ note in the tap.
    function exp.inject(trigger, snip, deleteCount, tail)
        exp.injecting = true
        local body = exp.substitute(snip.text, exp.unknownSeen)
        local before, after = body, nil
        local cut = body:find("{cursor}", 1, true)
        if cut then
            before = body:sub(1, cut - 1)
            after  = body:sub(cut + #"{cursor}")
        end
        local whole = before .. (after or "") .. (tail or "")
        local pasteErr
        -- 🚨 THROUGH THE SHARED GUARD (6.69.0), not just our own flag.
        -- exp.injecting stops OUR tap re-reading what we type; it says
        -- nothing to autocorrect's tap, which is watching the same
        -- keystrokes. Without this, expanding `hte` into "the" fed a word
        -- nobody typed into the spelling corrector. See _G.withInjection.
        local ok, err = (_G.withInjection or pcall)(function()
            for _ = 1, deleteCount do
                hs.eventtap.keyStroke({}, "delete", 0)
            end
            if shouldPaste(whole) then
                local okP, why = pasteText(whole)
                if not okP then pasteErr = why; error(why) end
                snip.viaPaste = true
            else
                hs.eventtap.keyStrokes(whole)
            end
            -- {cursor} walks back over everything that follows it, which
            -- includes any tail we re-typed — the caret belongs where the
            -- snippet said, not before the character you happened to end on.
            local back = clen(after or "") + clen(tail or "")
            if after and back > 0 then
                for _ = 1, back do
                    hs.eventtap.keyStroke({}, "left", 0)
                end
            end
        end)
        err = pasteErr or err
        exp.injecting = false
        if ok then
            exp.lastFired = { name = snip.name, trigger = trigger,
                              at = os.date("%H:%M:%S") }
            -- Autocorrect watched us eat the trigger's last character and
            -- is now holding the front of a word that no longer exists on
            -- screen. Tell it to let go — see the 🚨 above its tap.
            if _G.autocorrectResetBuffer then
                pcall(_G.autocorrectResetBuffer)
            end
            say("expanded " .. snip.name)
            return true
        end
        -- 🚨 THE KEYSTROKES ARE NOT LOST. Whatever we consumed on the
        -- promise that this would replace it gets typed back — the final
        -- character of the trigger on the immediate path, the tail on the
        -- deferred one. An injection that fails AND eats a character is
        -- two bugs instead of one.
        local owed = tail or trigger:sub(-1)
        pcall(function() hs.eventtap.keyStrokes(owed) end)
        print("✂️ Text expander: could not insert '" .. tostring(snip.name)
              .. "' — " .. tostring(err))
        if _G.notices then
            _G.notices.record("expander", "insertion failed",
                              tostring(snip.name) .. ": " .. tostring(err))
        end
        return false
    end

    -- ---- matching --------------------------------------------------------
    -- 🚨 THIS RUNS ON EVERY KEYSTROKE YOU MAKE, ON THE MAIN THREAD, WHICH
    -- IS THE ONLY THREAD HAMMERSPOON HAS. LL's five Alfred collections
    -- come to 2,006 triggers. The first version of this function walked
    -- every one of them per character typed — 2,006 string comparisons
    -- between pressing a key and the letter appearing. That is fine for
    -- the six snippets it was written against and it is not fine for the
    -- corpus it was written FOR, and "correct but too slow to type
    -- through" is a bug like any other.
    --
    -- So: a REVERSE TRIE, keyed on bytes. Each trigger is inserted
    -- backwards; matching walks the buffer backwards from the end and
    -- stops the moment there is no child. Cost is bounded by the LONGEST
    -- TRIGGER (33 bytes here), not by how many there are — the same 33
    -- steps whether you have six snippets or six thousand.
    --
    -- Bytes rather than characters on purpose: a UTF-8 string compares
    -- and slices by byte in Lua, the buffer is bytes, and every multi-byte
    -- character has a unique byte sequence — so byte-wise matching gives
    -- exactly the same answers as character-wise matching, without
    -- decoding anything on the hot path. It is the character COUNT that
    -- has to be right, and that is computed once at load.
    exp.index = { children = {} }

    -- 🚨 ONE FUNCTION REBUILDS **EVERYTHING** DERIVED FROM exp.snippets.
    -- There are two derived structures — the trie and the ambiguity map —
    -- and while they were built in different places, adding a trigger
    -- rebuilt one and left the other stale. A snippet that exists, matches,
    -- and then takes the wrong path is worse than one that does not load.
    -- If you add a third derived thing, it goes in here.
    function exp.buildIndex()
        local root, nodes, list = { children = {} }, 1, {}
        for trigger, snip in pairs(exp.snippets) do
            list[#list + 1] = trigger
            local node = root
            for i = #trigger, 1, -1 do
                local b = trigger:sub(i, i)
                local nxt = node.children[b]
                if not nxt then
                    nxt = { children = {} }
                    node.children[b] = nxt
                    nodes = nodes + 1
                end
                node = nxt
            end
            node.trigger, node.snip = trigger, snip
        end
        exp.index = root
        exp.indexNodes = nodes

        -- ⏳ WHICH TRIGGERS ARE PREFIXES OF OTHER TRIGGERS.
        -- !!del is one, because !!delf exists; those wait before expanding
        -- (see the ⏳ note in the tap) so both stay reachable.
        --
        -- 🚨 SORTED-ADJACENCY, NOT EVERY PAIR. The obvious double loop is
        -- O(n²) — 4,024,036 comparisons on LL's 2,006 triggers, on the
        -- main thread, every reload. Sorted lexicographically, every
        -- string beginning with A lands immediately after A, so scanning
        -- forward while the prefix still holds finds all of them and stops.
        -- O(n log n) plus the number of matches, which here is three.
        table.sort(list)
        exp.ambiguous, exp.ambiguousCount = {}, 0
        for i = 1, #list do
            local a = list[i]
            local j = i + 1
            while list[j] and #list[j] > #a and list[j]:sub(1, #a) == a do
                if not exp.ambiguous[a] then
                    exp.ambiguous[a] = {}
                    exp.ambiguousCount = exp.ambiguousCount + 1
                end
                exp.ambiguous[a][#exp.ambiguous[a] + 1] = list[j]
                j = j + 1
            end
        end
        return nodes
    end

    -- boundaryOK: see the 🧨 note in the header. Only triggers that begin
    -- with a letter or digit are asked for one — 77 of LL's 2,006, which
    -- is exactly the `gg1` family the rule exists for.
    --
    -- ⚠️ THE PRECEDING CHARACTER IS TESTED BY ITS LAST BYTE. If what comes
    -- before the trigger is multi-byte (§, an emoji, an accented letter),
    -- `at` lands on a UTF-8 continuation byte, which never matches %w — so
    -- it reads as a boundary. That is the right answer for the right
    -- reason: Lua's %w is ASCII-only, so a non-ASCII letter would not
    -- match even if we decoded it properly. Written down because it looks
    -- like an accident and is not one.
    function exp.boundaryOK(buffer, trigger)
        if not exp.wordStartOnly then return true end
        if not trigger:sub(1, 1):match("[%w]") then return true end
        local at = #buffer - #trigger
        if at <= 0 then return true end            -- start of the buffer
        return buffer:sub(at, at):match("[%w]") == nil
    end

    -- Walks back from the end of the buffer. The DEEPEST node carrying a
    -- trigger wins, which is longest-match: `;bd` beats `bd` when both end
    -- on the same keystroke. A trigger whose word boundary fails is
    -- skipped but the walk CONTINUES — a longer trigger further back may
    -- still be legitimate.
    function exp.match(buffer)
        local node, best = exp.index, nil
        local n = #buffer
        local limit = math.min(n, exp.longestBytes or n)
        for i = 0, limit - 1 do
            local b = buffer:sub(n - i, n - i)
            node = node.children[b]
            if not node then break end
            if node.trigger and exp.boundaryOK(buffer, node.trigger) then
                best = { trigger = node.trigger, snip = node.snip }
            end
        end
        return best
    end

    -- Forward-declared: armPending's timer needs it, and the definition
    -- lives with the rest of the tap below where it reads in context.
    local excluded

    -- ---- the deferred expansion, armed and disarmed ----------------------
    -- Held in exp.pending so ⇪⇧D can see one waiting, and so the cancel
    -- paths below have one thing to clear rather than three.
    exp.pending, exp.pendingTimer = nil, nil

    function exp.cancelPending(why)
        if exp.pendingTimer then
            pcall(function() exp.pendingTimer:stop() end)
        end
        if why and exp.pending then
            say("stopped waiting on " .. exp.pending.trigger .. " (" .. why .. ")")
        end
        exp.pending, exp.pendingTimer = nil, nil
    end

    function exp.armPending(p)
        if exp.pendingTimer then pcall(function() exp.pendingTimer:stop() end) end
        exp.pending = p
        exp.pendingTimer = hs.timer.doAfter(exp.ambiguityWait, function()
            local q = exp.pending
            exp.pending, exp.pendingTimer = nil, nil
            if not q then return end
            if not exp.enabled then return end
            if excluded() then return end
            -- You stopped typing. Nothing was consumed, so the trigger AND
            -- everything typed since it are both on screen and ours to
            -- remove; `since` is re-typed after the snippet.
            exp.inject(q.trigger, q.snip,
                       clen(q.trigger) + clen(q.since), q.since ~= "" and q.since or nil)
        end)
        hold(exp.pendingTimer)
    end

    -- ---- the typing watcher ---------------------------------------------
    -- Deliberately close to autocorrect's, because that one has been right
    -- for a long time. The differences are the ones the job requires:
    --   · digits and punctuation EXTEND the buffer instead of clearing it,
    --     because `gg1` and `;bd` are both triggers and clearing on either
    --     would make them unmatchable;
    --   · there is no boundary key — a trigger fires on its own last
    --     character, the way Alfred does it;
    --   · the buffer is a rolling window, not a word.
    local buffer = ""

    local clearCodes = {
        [53]  = true,                                       -- esc
        [123] = true, [124] = true, [125] = true, [126] = true, -- arrows
        [115] = true, [119] = true, [116] = true, [121] = true, -- home/end/pg
        [117] = true,                                       -- forward delete
        [36]  = true, [76]  = true, [48] = true,            -- return, enter, tab
    }

    function excluded()
        local ok, app = pcall(hs.application.frontmostApplication)
        if not ok or not app then return false end
        local okN, name = pcall(function() return app:name() end)
        if not okN or not name then return false end
        for _, ex in ipairs(exp.excludedApps) do
            if name == ex then return true end
        end
        return false
    end

    _G.expanderTap = hs.eventtap.new(
        { hs.eventtap.event.types.keyDown,
          hs.eventtap.event.types.leftMouseDown,
          hs.eventtap.event.types.rightMouseDown },
        function(ev)
            if exp.injecting then return false end

            -- 🚨 EVERY PATH THAT ABANDONS THE BUFFER MUST ALSO ABANDON A
            -- PENDING EXPANSION, and this is the sharpest edge in the whole
            -- module. A deferred expansion deletes N characters BACKWARDS
            -- FROM THE CARET on the assumption the trigger is still sitting
            -- there. Click somewhere else, press an arrow, hit Return — the
            -- caret is now somewhere else entirely and those deletes would
            -- eat a sentence you did not type. Cancelling is always safe
            -- (nothing was consumed, so nothing is owed); firing into a
            -- moved caret never is.
            local t = ev:getType()
            if t ~= hs.eventtap.event.types.keyDown then
                buffer = ""              -- the cursor moved; nothing carries over
                exp.cancelPending("mouse click")
                return false
            end

            local flags = ev:getFlags()
            if flags.cmd or flags.ctrl then
                buffer = ""
                exp.cancelPending("a ⌘/⌃ chord")
                return false
            end

            local code = ev:getKeyCode()
            if code == 51 then                                  -- delete
                if #buffer > 0 then
                    local n = clen(buffer)
                    buffer = (utf8 and utf8.offset and n > 0)
                             and buffer:sub(1, (utf8.offset(buffer, n) or #buffer) - 1)
                             or  buffer:sub(1, -2)
                end
                -- Backspace means you are UNDOING the trigger, which is the
                -- clearest possible "no" a pending expansion can receive.
                exp.cancelPending("backspace")
                return false
            end
            if clearCodes[code] then
                buffer = ""
                exp.cancelPending("the caret moved")
                return false
            end

            local ch = ev:getCharacters()
            if not ch or ch == "" or clen(ch) ~= 1 then
                buffer = ""                                     -- function keys, IME
                exp.cancelPending("a key we cannot account for")
                return false
            end

            buffer = buffer .. ch
            if clen(buffer) > exp.bufferMax then
                -- Trim from the FRONT: the tail is what matches.
                local drop = clen(buffer) - exp.bufferMax
                local off = utf8 and utf8.offset and utf8.offset(buffer, drop + 1)
                buffer = off and buffer:sub(off) or buffer:sub(-exp.bufferMax)
            end

            if not (exp.enabled and exp.count > 0) then return false end
            local hit = exp.match(buffer)

            -- ⏳ ---- THE DEFERRED PATH: TRIGGERS THAT ARE PREFIXES OF OTHERS
            -- !!del is a trigger and so is !!delf. Fire on the "l" and
            -- !!delf is unreachable forever and you are left holding a
            -- stray "f". So !!del WAITS to see whether you are still
            -- typing. Three of LL's Mac symbols depend on this; nothing
            -- else in 2,006 triggers pays a millisecond for it.
            --
            -- 🚨 WHILE WAITING WE CONSUME NOTHING. The characters reach
            -- the document exactly as typed, so if the wait is abandoned
            -- there is nothing to give back and nothing to undo. That is
            -- the whole reason this is safe: the ONLY thing a pending
            -- expansion ever does is delete text it can see is there.
            if exp.pending then
                local p = exp.pending
                -- Did this keystroke keep us on the road to a longer one?
                local grown = p.trigger .. p.since .. ch
                local stillPossible = false
                for _, longer in ipairs(exp.ambiguous[p.trigger] or {}) do
                    if #longer >= #grown and longer:sub(1, #grown) == grown then
                        stillPossible = true break
                    end
                end
                if hit and #hit.trigger > #p.trigger then
                    -- The longer one completed. The wait did its job.
                    exp.cancelPending("a longer trigger completed")
                    -- fall through to the immediate path below
                elseif stillPossible then
                    p.since = p.since .. ch
                    exp.armPending(p)          -- restart the clock
                    return false
                else
                    -- 🚨 THIS KEYSTROKE SETTLES IT: no longer trigger can
                    -- follow, so the short one was right after all. Consume
                    -- this character and re-type it AFTER the snippet — the
                    -- same move autocorrect makes with its boundary key.
                    -- Deleting the whole trigger, not len-1: none of it was
                    -- consumed on the way in.
                    local tail = p.since .. ch
                    exp.cancelPending(nil)
                    buffer = ""
                    if excluded() then return false end
                    hold(hs.timer.doAfter(exp.injectDelay, function()
                        exp.inject(p.trigger, p.snip, clen(p.trigger) + clen(tail), tail)
                    end))
                    return true
                end
            end

            if not hit then return false end
            if excluded() then return false end

            local trigger, snip = hit.trigger, hit.snip

            if exp.ambiguous[trigger] then
                exp.armPending({ trigger = trigger, snip = snip, since = "" })
                return false             -- let the character through
            end

            buffer = ""
            -- The last character is consumed here and re-typed as part of
            -- the replacement, so only the preceding characters need
            -- deleting. Injecting on a short timer rather than inline for
            -- the same reason autocorrect does: our synthetic events must
            -- arrive after the app has finished with the real ones.
            local deletes = clen(trigger) - 1
            hold(hs.timer.doAfter(exp.injectDelay, function()
                exp.inject(trigger, snip, deletes)
            end))
            return true                  -- consume; the replacement covers it
        end
    )

    -- ---- importing -------------------------------------------------------
    -- .alfredsnippets is a ZIP. unzip is in every macOS install, so there
    -- is nothing to install and nothing to vendor.
    function exp.import(path)
        path = tostring(path or ""):gsub("^~", os.getenv("HOME") or "~")
        local attrs = hs.fs.attributes(path)
        if not attrs then
            print("✂️ Text expander: no such file — " .. path)
            return false
        end
        local base = path:match("([^/]+)%.alfredsnippets$")
                     or path:match("([^/]+)%.zip$")
                     or path:match("([^/]+)$")
        local dest = exp.dir .. "/" .. base
        hs.fs.mkdir(exp.dir)
        hs.fs.mkdir(dest)
        -- Single-quoted with the '\'' escape: %q would escape a newline as
        -- backslash-newline, which is correct Lua and a line continuation
        -- to the shell. This config has been bitten by that before.
        local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
        local out, ok, _, rc = hs.execute("/usr/bin/unzip -o "
                                          .. shq(path) .. " -d " .. shq(dest) .. " 2>&1")
        if not ok then
            print("✂️ Text expander: unzip failed (" .. tostring(rc) .. ") — "
                  .. tostring(out))
            if _G.notices then
                _G.notices.record("expander", "import failed",
                                  base .. ": unzip returned " .. tostring(rc))
            end
            return false
        end
        exp.load()
        local msg = string.format("imported %s — %d triggers loaded in total", base, exp.count)
        print("✂️ " .. msg)
        hs.alert.show("✂️ " .. msg)
        return true
    end

    -- _G.snippetsImport() with NO argument: find the .alfredsnippets files
    -- you have already downloaded and import all of them. Typing an exact
    -- path with a UUID in it is the kind of small friction that stops a
    -- feature being used at all.
    --
    -- ⚠️ IT SCANS, IT DOES NOT WATCH. Nothing here imports on its own — a
    -- config that quietly ingested files out of ~/Downloads would be doing
    -- something you did not ask for with files you did not choose.
    exp.searchDirs = { "/Downloads", "/Desktop", "" }
    function exp.importFound()
        local home = os.getenv("HOME") or "~"
        local found = {}
        for _, d in ipairs(exp.searchDirs) do
            local okIter, iter = pcall(hs.fs.dir, home .. d)
            if okIter and iter then
                for entry in iter do
                    if entry:sub(-15) == ".alfredsnippets" then
                        found[#found + 1] = home .. d .. "/" .. entry
                    end
                end
            end
        end
        if #found == 0 then
            print("✂️ No .alfredsnippets files in ~/Downloads, ~/Desktop or ~. "
                  .. "Pass a path: _G.snippetsImport(\"/full/path/x.alfredsnippets\")")
            hs.alert.show("✂️ No .alfredsnippets files found")
            return false
        end
        table.sort(found)
        local ok = 0
        for _, f in ipairs(found) do
            if exp.import(f) then ok = ok + 1 end
        end
        print(string.format("✂️ Imported %d of %d collections found", ok, #found))
        return ok > 0
    end

    -- Hand-written snippets go in their own collection so an Alfred
    -- re-import can never overwrite them.
    function exp.add(trigger, text, name)
        if type(trigger) ~= "string" or trigger == ""
           or type(text) ~= "string" or text == "" then
            print("✂️ Usage: _G.snippetAdd(\"gg1\", \"the text\", \"optional name\")")
            return false
        end
        local dest = exp.dir .. "/Mine"
        hs.fs.mkdir(exp.dir)
        hs.fs.mkdir(dest)
        local safe = trigger:gsub("[^%w]", "_")
        local file = dest .. "/" .. safe .. ".json"
        local body = hs.json.encode({
            alfredsnippet = { keyword = trigger, snippet = text,
                              name = name or trigger, uid = safe },
        })
        local f = io.open(file, "w")
        if not f then
            print("✂️ Text expander: could not write " .. file)
            if core.warnWriteFailed then core.warnWriteFailed("snippets/Mine") end
            return false
        end
        f:write(body); f:close()
        exp.load()
        print("✂️ Added " .. trigger .. " → " .. file)
        hs.alert.show("✂️ Snippet " .. trigger .. " added")
        return true
    end

    function exp.list()
        local rows = {}
        for trigger, s in pairs(exp.snippets) do
            rows[#rows + 1] = string.format("  %-12s  %s  (%s)", trigger,
                                            (s.name or ""):sub(1, 40), s.source)
        end
        table.sort(rows)
        print("✂️ " .. #rows .. " snippet triggers in " .. exp.dir .. ":")
        if #rows == 0 then
            print("  (none — run _G.snippetsImport() to find your "
                  .. ".alfredsnippets files, or _G.snippetAdd(\"gg1\", \"text\"))")
        end
        for _, r in ipairs(rows) do print(r) end
        for _, p in ipairs(exp.problems or {}) do print("  ⚠️ " .. p) end
        return #rows
    end

    -- ---- ⇪⇧T, the chooser ------------------------------------------------
    -- Same reasoning as the tool picker: hs.chooser is a native panel
    -- built to be typed into. Insert-by-search covers the snippet you know
    -- you have and cannot remember the trigger for, which is most of them
    -- until the trigger is in your fingers.
    function exp.show()
        local choices = {}
        choices[#choices + 1] = {
            text    = exp.enabled and "⏸  Turn expansion OFF" or "▶️  Turn expansion ON",
            subText = exp.enabled
                      and "Triggers stop firing; ⇪⇧T still inserts by hand"
                      or  "Start expanding triggers as you type again",
            toggle  = true,
        }
        for trigger, s in pairs(exp.snippets) do
            choices[#choices + 1] = {
                text    = s.name or trigger,
                subText = trigger .. "   ·   " .. (s.text:gsub("%s+", " "):sub(1, 70)),
                trigger = trigger, snip = s,
            }
        end
        for _, s in ipairs(exp.chooserOnly or {}) do
            choices[#choices + 1] = {
                text    = s.name,
                subText = "(no trigger)   ·   " .. (s.text:gsub("%s+", " "):sub(1, 70)),
                snip    = s,
            }
        end
        table.sort(choices, function(a, b)
            if a.toggle then return true end
            if b.toggle then return false end
            return tostring(a.text) < tostring(b.text)
        end)

        local okC, chooser = pcall(hs.chooser.new, function(choice)
            if not choice then return end
            if choice.toggle then
                exp.enabled = not exp.enabled
                hs.alert.show(exp.enabled and "✂️ Expansion ON" or "✂️ Expansion OFF")
                return
            end
            if not choice.snip then return end
            -- Nothing to delete: this is an insert, not a replacement.
            exp.inject(choice.trigger or "", choice.snip, 0)
        end)
        if not (okC and chooser) then
            warn("could not open the snippet chooser")
            hs.alert.show("✂️ Snippet chooser failed — see the Console")
            return false
        end
        pcall(function()
            chooser:choices(choices)
            chooser:rows(12)
            chooser:width(45)
            chooser:placeholderText(exp.count > 0
                and ("search " .. exp.count .. " snippets")
                or  "no snippets yet — run _G.snippetsImport() in the Console")
            chooser:show()
        end)
        return true
    end

    -- ---- wiring ----------------------------------------------------------
    if exp.enabled then
        core.hyperAddShortcut({ "shift" }, exp.key, function() exp.show() end,
                              "text expander")
    end

    core.provide("expander.show",   function() return exp.show() end)
    core.provide("expander.reload", function() return exp.load() end)
    core.provide("expander.toggle", function()
        exp.enabled = not exp.enabled
        return exp.enabled
    end)

    _G.snippetsImport = function(p)
        if p == nil or p == "" then return exp.importFound() end
        return exp.import(p)
    end
    _G.snippetAdd     = function(t, x, n) return exp.add(t, x, n) end
    _G.snippetsList   = function() return exp.list() end
    _G.textExpander   = exp
    M.exp    = exp
    M.config = exp

    -- ---- boot ------------------------------------------------------------
    -- Same shape as autocorrect: the tap starts NOW so nothing is missed
    -- structurally, and the files are read in warm() a couple of seconds
    -- later. Between the two, triggers do not fire — which is the same as
    -- the expander being off, not a broken state.
    local axOK = false
    pcall(function() axOK = hs.accessibilityState() end)
    if not axOK then
        exp.status = "OFF (needs Accessibility)"
        return
    end
    local started = false
    pcall(function() _G.expanderTap:start(); started = true end)
    if not started then
        exp.status = "OFF (event tap failed to start)"
        warn("event tap would not start — no expansion this session")
        if _G.notices then
            _G.notices.record("expander", "event tap", "would not start")
        end
        return
    end
    exp.status = "ON (snippets loading…)"

    function M.warm()
        exp.load()
        exp.status = exp.count > 0
            and string.format("ON (%d triggers, ⇪⇧T to search)", exp.count)
            or  "ON (no snippets yet — run _G.snippetsImport() in the Console)"
    end

    -- macOS switches event taps off when it feels like it. A dead expander
    -- is indistinguishable from a wrong trigger from where you are sitting,
    -- so it is revived and the revival is announced.
    _G.expanderWatchdog = hs.timer.doEvery(30, function()
        pcall(function()
            if _G.expanderTap and not _G.expanderTap:isEnabled() then
                _G.expanderTap:start()
                print("✂️ Text expander tap was disabled by macOS — revived")
            end
        end)
    end)
end

return M
