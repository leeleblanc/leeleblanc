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
        exp.count, exp.longest = 0, 0
        for trigger in pairs(into) do
            exp.count = exp.count + 1
            local n = clen(trigger)
            if n > exp.longest then exp.longest = n end
        end
        -- 🚨 A TRIGGER THAT CAN NEVER FIRE IS REPORTED. Expansion happens
        -- the instant a trigger COMPLETES — it cannot wait to see whether
        -- more is coming — so if `gg1` is a trigger, `gg12` is unreachable:
        -- `gg1` fires on the "1" and the "2" lands in a fresh buffer.
        -- Alfred has the same limit and says nothing about it, which is how
        -- you end up believing a snippet is broken.
        --
        -- Note the direction. A trigger that is a strict PREFIX of another
        -- shadows it. A trigger that is a SUFFIX does not: `bd` and `;bd`
        -- both complete on the same keystroke, and longest-match gives it
        -- to `;bd`. Getting that backwards would report the working case
        -- and stay quiet about the broken one.
        for a in pairs(into) do
            for b in pairs(into) do
                if a ~= b and #a < #b and b:sub(1, #a) == a then
                    problems[#problems + 1] = string.format(
                        "%s can never fire: %s completes first and expands. "
                        .. "Rename one of them.", b, a)
                end
            end
        end

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
        say(string.format("loaded %d triggers (longest %d chars), %d chooser-only, %d problems",
                          exp.count, exp.longest, #chooserOnly, #problems))
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
    function exp.inject(trigger, snip, deleteCount)
        exp.injecting = true
        local body = exp.substitute(snip.text, exp.unknownSeen)
        local before, after = body, nil
        local cut = body:find("{cursor}", 1, true)
        if cut then
            before = body:sub(1, cut - 1)
            after  = body:sub(cut + #"{cursor}")
        end
        local ok, err = pcall(function()
            for _ = 1, deleteCount do
                hs.eventtap.keyStroke({}, "delete", 0)
            end
            hs.eventtap.keyStrokes(before .. (after or ""))
            if after and #after > 0 then
                for _ = 1, clen(after) do
                    hs.eventtap.keyStroke({}, "left", 0)
                end
            end
        end)
        exp.injecting = false
        if ok then
            exp.lastFired = { name = snip.name, trigger = trigger,
                              at = os.date("%H:%M:%S") }
            say("expanded " .. snip.name)
            return true
        end
        -- 🚨 THE KEYSTROKE IS NOT LOST. The final character was consumed on
        -- the promise that this would replace it, and a failed injection
        -- that also ate a character is two bugs instead of one.
        pcall(function() hs.eventtap.keyStrokes(trigger:sub(-1)) end)
        print("✂️ Text expander: could not insert '" .. tostring(snip.name)
              .. "' — " .. tostring(err))
        if _G.notices then
            _G.notices.record("expander", "insertion failed",
                              tostring(snip.name) .. ": " .. tostring(err))
        end
        return false
    end

    -- ---- matching --------------------------------------------------------
    -- The longest trigger wins, so `;bdx` beats `;bd` when both exist and
    -- the shorter one can never shadow the longer one.
    --
    -- boundaryOK: see the 🧨 note in the header. Only triggers that begin
    -- with a letter or digit are asked for one.
    function exp.boundaryOK(buffer, trigger)
        if not exp.wordStartOnly then return true end
        if not trigger:sub(1, 1):match("[%w]") then return true end
        local at = #buffer - #trigger
        if at <= 0 then return true end            -- start of the buffer
        return buffer:sub(at, at):match("[%w]") == nil
    end

    function exp.match(buffer)
        local best, bestLen = nil, 0
        for trigger, snip in pairs(exp.snippets) do
            local n = #trigger
            if n > bestLen and #buffer >= n
               and buffer:sub(-n) == trigger
               and exp.boundaryOK(buffer, trigger) then
                best, bestLen = { trigger = trigger, snip = snip }, n
            end
        end
        return best
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

    local function excluded()
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

            local t = ev:getType()
            if t ~= hs.eventtap.event.types.keyDown then
                buffer = ""              -- the cursor moved; nothing carries over
                return false
            end

            local flags = ev:getFlags()
            if flags.cmd or flags.ctrl then buffer = "" return false end

            local code = ev:getKeyCode()
            if code == 51 then                                  -- delete
                if #buffer > 0 then
                    local n = clen(buffer)
                    buffer = (utf8 and utf8.offset and n > 0)
                             and buffer:sub(1, (utf8.offset(buffer, n) or #buffer) - 1)
                             or  buffer:sub(1, -2)
                end
                return false
            end
            if clearCodes[code] then buffer = "" return false end

            local ch = ev:getCharacters()
            if not ch or ch == "" or clen(ch) ~= 1 then
                buffer = ""                                     -- function keys, IME
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
            if not hit then return false end
            if excluded() then return false end

            local trigger, snip = hit.trigger, hit.snip
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
