-- =====================================================================
-- MODULE: OCR ENGINE — copied images become searchable text
-- =====================================================================
-- 🔍 WHAT IT DOES. Copy an image and its text is extracted and indexed.
-- Copy image FILES in Finder and each one is OCR'd AND the text is
-- written into the file's Finder comment, so Spotlight can find a
-- screenshot by what is written inside it.
--
--   ⇪O        search everything ever OCR'd — Enter copies the full text
--   ⇪⇧O       edit or delete entries · ☑️ row deletes several at once
--   automatic  every copied image, via the "HS OCR" Apple Shortcut
--
-- 📦 6.105.0 — THIS WAS §2 OF init.lua. It was the last large feature
-- still living in the root file: about 500 lines of Apple Events, task
-- spawning, pasteboard shape-guessing and CSV rewriting, all of it
-- ABOVE the module loader, where a syntax error takes the entire config
-- down instead of costing one feature. That is the same argument that
-- moved the clipboard history out in 6.55.0 and the task creator in
-- 6.98.0, and it applied here more than to either of them: this is the
-- code that talks to Finder over Apple Events, which is the one thing in
-- this config with a documented history of aborting the whole app.
--
-- Nothing about the behaviour changed in the move. The globals other
-- files read — _G.ocrShortcutAvailable (core/capabilities.lua,
-- modules/screenshots.lua) and _G.choosers.ocr / _G.choosers.ocrEdit
-- (tests/test_select_mode.lua) — are still set, under the same names.
--
-- 🚨 THE CLIPBOARD WATCHER STAYED IN init.lua, and that is deliberate.
-- One timer reads one pasteboard changeCount and chooses between copied
-- image files, a raw image, and text; clipboard history is the other
-- half of that choice. Two timers polling the same counter would race
-- over which handled a change first. init.lua calls in here through the
-- service registry instead:
--
--     ocr.clipboardFiles()   ← which image files is the clipboard on?
--     ocr.tagFiles(paths)    ← OCR each and write its Finder comment
--     ocr.image(img)         ← OCR one raw clipboard image
--
-- A missing provider prints once and the clipboard carries on, which is
-- exactly what the watcher's comment has promised since 6.55.0.

local M = {
    name  = "OCR Engine",
    order = 2.5,
    family = "text",
    summary = "Copied images become searchable text · Finder comments too",
    cheatsheet = {
        title = "🔍 OCR ENGINE (copy an image — the words in it become searchable)",
        entries = {
            { "⇪O",      "Search everything ever OCR'd · Enter copies the text" },
            { "⇪⇧O",     "Edit an entry in a real window — ⌘⏎ saves, Esc cancels" },
            { "empty it", "Clear the box (or press Delete entry) to remove it" },
            { "☑️ row",   "Delete several at once — Enter picks, one row deletes" },
            { "automatic","Every copied image is read and indexed, silently" },
            { "🏷 files", "⌘C image files in Finder → text into Finder comments" },
            { "never",   "An existing Finder comment is never overwritten" },
            { "needs",   "The \"HS OCR\" Apple Shortcut · Automation → Finder" },
        },
    },
}

function M.setup(core)
    local ocr = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ocr.enabled          = true
    ocr.key              = "o"     -- ⇪O search · ⇪⇧O edit
    ocr.shortcutName     = "HS OCR"
    ocr.tagMaxChars      = 500     -- Finder-comment length cap
    -- ✍️ 6.115.0 — THE EDITOR IS A WINDOW NOW. LL: "Edit OCR is too small
    -- — give me a window like notepad", with a screenshot of one line of
    -- "All Snippets" in a box that could not show the rest.
    --
    -- It was hs.dialog.textPrompt, and that control was never going to be
    -- adequate here: a fixed-size NSAlert around a ONE-LINE NSTextField.
    -- It cannot be resized, it cannot scroll, and Return presses the
    -- default button instead of inserting a newline — while the thing
    -- being edited is OCR output, which is MULTI-LINE BY NATURE. A page of
    -- scanned text went into a control that could show about 25
    -- characters of it. win_pin hit exactly this in 6.112.0 and got the
    -- Capture Pad's window; this is that window, sized for a page.
    --
    -- 🎯 AND IT TAKES FOCUS ON OPEN, which is LL's other report: "it
    -- doesn't come to the front for an immediately editable window, I have
    -- to click on it". allowTextEntry + bringToFront, the same pair the
    -- Quick Append Pad uses.
    ocr.editorW          = 760
    ocr.editorH          = 520
    ocr.editorFont       = 14      -- the BOX's size, not the stored text's
    ocr.editorRows       = 16
    ocr.tagMaxFilesPerCopy = 15    -- safety cap per ⌘C (floods ignored)
    ocr.imageExtensions  = { png = true, jpg = true, jpeg = true, gif = true,
        tif = true, tiff = true, heic = true, heif = true, webp = true, bmp = true }
    -- ----------------------------------------------------------------------

    -- OCR log. The CSV is per-machine (hostTag); existing shared-name data
    -- is adopted rather than orphaned.
    ocr.csvFile = (core.logsDir or "") .. "/image_text-"
                  .. tostring(core.hostTag or "Mac") .. ".csv"
    if core.adoptLegacyFile then
        pcall(core.adoptLegacyFile, ocr.csvFile,
              (core.logsDir or "") .. "/image_text.csv")
    end

    local function warnWriteFailed(what)
        if core.warnWriteFailed then return core.warnWriteFailed(what) end
        print("⚠️ could not write the " .. tostring(what))
    end

    local function showPopup(chooser)
        if core.showPopup then return core.showPopup(chooser) end
        pcall(function() chooser:show() end)
    end

    -- OCR Daemon (Apple Shortcut Integrated)
    -- Boot check: does THIS Mac's Shortcuts app have the OCR shortcut?
    -- (nil = still checking → optimistic; false = confirmed missing →
    -- image OCR skips quietly on this machine; text clipboard unaffected)
    _G.ocrShortcutAvailable = nil
    pcall(function()
        -- HELD, for the same reason every other task in this file is: an
        -- unreferenced hs.task can be collected mid-run, and a boot check
        -- that sometimes does not answer leaves _G.ocrShortcutAvailable
        -- nil forever — which reads as "still checking", which is
        -- optimistic, which is the wrong default to arrive at by accident.
        ocr.probeTask = hs.task.new("/usr/bin/shortcuts", function(exitCode, stdOut)
            if exitCode == 0 and type(stdOut) == "string" then
                _G.ocrShortcutAvailable = (stdOut:find(ocr.shortcutName, 1, true) ~= nil)
                if not _G.ocrShortcutAvailable then
                    print("ℹ️ Shortcuts app has no '" .. ocr.shortcutName
                          .. "' — image OCR off on this Mac (recreate the shortcut to enable)")
                end
            end
        end, { "list" })
        ocr.probeTask:start()
    end)

    -- Strips anything not producible by a standard US QWERTY keyboard (the
    -- full printable ASCII range, 0x20-0x7E, plus tab/CR/LF) — OCR output
    -- routinely contains stray Unicode glyphs (smart quotes, box-drawing
    -- artifacts, emoji, mis-decoded bytes) that don't belong in a CSV row
    -- or a Finder comment. Characters outside that set are REMOVED, not
    -- replaced — no placeholder is inserted in their place.
    local function stripToQwerty(s)
        if type(s) ~= "string" then return "" end
        return (s:gsub("[^\9\13\10\32-\126]", ""))
    end
    ocr.stripToQwerty = stripToQwerty

    -- One row of the log. The escaping is the CSV's own convention and is
    -- read back by loadOCRHistory below and by ⇪space's OCR source — it
    -- is not free to change on one side only.
    local function appendRow(text)
        local f = io.open(ocr.csvFile, "a")
        if f then
            f:write(os.date("%Y-%m-%d %H:%M:%S") .. ',"' ..
                text:gsub('"', '""'):gsub('\r\n', '\\n'):gsub('\r', '\\n'):gsub('\n', '\\n')
                .. '"\n')
            f:close()
            return true
        end
        warnWriteFailed("OCR log")
        return false
    end

    function ocr.image(img)
        if _G.ocrShortcutAvailable == false then return end
        if not img then return end
        local imgPath = "/tmp/hs_auto_ocr.png"

        if img:saveToFile(imgPath) then
            hs.task.new("/usr/bin/shortcuts", function(exitCode, stdOut, stdErr)
                os.remove(imgPath)

                local extractedText = stdOut
                if not extractedText or #extractedText == 0 then
                    extractedText = hs.pasteboard.readString()
                end

                if extractedText and #extractedText > 0 then
                    extractedText = stripToQwerty(extractedText:gsub("%z", ""):gsub("\x1A", ""))

                    if #extractedText > 0 then
                        -- 6.65.0 silenced the success ALERT; 6.97.0
                        -- silences the console line too. LL: "Can't we
                        -- reduce the OCR indexed to errors only?" — so a
                        -- clean index prints NOTHING. The CSV is the
                        -- record, ⇪O is the receipt; failures still print.
                        appendRow(extractedText)
                    end
                end
            end, {"run", ocr.shortcutName, "-i", imgPath}):start()
        end
    end

    -- ---- FILE-TAGGING OCR (6.11.0) --------------------------------------
    -- Copy image FILES in Finder (⌘C) → each is OCR'd and the text is
    -- written into the file's Finder comment (Get Info → Comments), which
    -- Spotlight & Finder search index — so a folder full of meaningless
    -- filenames becomes searchable by what's written IN the images. The
    -- text also goes to the ⇪O history like any other OCR.
    -- Rules & limits (see the 6.11.0 changelog note): existing comments
    -- are never overwritten; needs one-time Automation permission for
    -- Finder; comments are local metadata (OneDrive doesn't sync them);
    -- raw clipboard images have no file to tag and behave as before.
    local function ocrUrlToPath(u)
        if type(u) ~= "string" then return nil end
        if not u:match("^file://") then return nil end
        local p = u:gsub("^file://", "")
        p = p:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        return p
    end

    -- Which image files (if any) does the clipboard point at right now?
    -- Finder puts a public.file-url flavor on the pasteboard for every
    -- copied file. 6.11.1: read the RAW pasteboard items (readAllData) —
    -- the reliable route — with readURL and plain-text paths kept as
    -- fallbacks for other tools. 6.98.0: narration is errors-only, same
    -- rule the OCR indexer follows — a normal miss prints nothing.
    function ocr.clipboardFiles()
        local paths, seen, sawFileURL = {}, {}, false
        local firstMiss = nil  -- first GENUINE anomaly, for diagnosis (6.98.0)
        local function consider(candidate)
            if #paths >= ocr.tagMaxFilesPerCopy then return end
            if type(candidate) ~= "string" or seen[candidate] then return end
            seen[candidate] = true
            -- 6.98.0 — FILE-REFERENCE PATHS. Some apps put a copied file on
            -- the pasteboard as "/.file/id=…" — macOS's name-independent way
            -- of pointing at a file — which has no extension to judge, so
            -- real images arrived here and were skipped as "no file
            -- extension found" (LL hit exactly this). The filesystem itself
            -- translates the id form (realpath), so resolve FIRST, then
            -- judge the real name.
            if candidate:find("/.file/", 1, true) == 1 then
                local resolved
                pcall(function()
                    resolved = hs.fs.pathToAbsolute((candidate:gsub("/+$", "")))
                end)
                if type(resolved) ~= "string" or resolved == "" then
                    if not firstMiss then
                        firstMiss = "a file-reference path macOS would not resolve — raw value: \""
                            .. stripToQwerty(candidate:sub(1, 160)) .. "\""
                    end
                    return
                end
                if seen[resolved] then return end   -- same file also came by name
                seen[resolved] = true
                candidate = resolved
            end
            local ext = candidate:match("%.(%w+)$")
            if ext and ocr.imageExtensions[ext:lower()] then
                local mode = nil
                pcall(function() mode = hs.fs.attributes(candidate, "mode") end)
                if mode == "file" then
                    table.insert(paths, candidate)
                elseif not firstMiss then
                    firstMiss = "ext ." .. ext .. " is supported, but not a readable local file (mode = "
                        .. tostring(mode) .. ") — raw value: \"" .. stripToQwerty(candidate:sub(1, 160)) .. "\""
                end
            end
            -- No/unsupported extension on a path that DID resolve is the
            -- everyday case — any non-image file ⌘C'd in Finder — and is
            -- deliberately NOT a firstMiss: it prints nothing (6.98.0).
        end

        -- Method 1 (primary): raw pasteboard items, every flavor of every
        -- copied item keyed by its UTI — Finder always includes
        -- public.file-url here, one per file.
        -- Hammerspoon's readAllData() shape has drifted across versions:
        -- normally an array of {UTI = data} tables, but a single copied
        -- item has been seen returned as one bare {UTI = data} table
        -- instead of a one-element array (handled below), and some builds
        -- nest each representation as {uti = ..., data = ...} rather than
        -- keying by UTI directly (also handled below) — a shape change
        -- degrades to methods 2/3 instead of going silent.
        pcall(function()
            local items = hs.pasteboard.readAllData()
            if items ~= nil and type(items) ~= "table" then
                print("🏷 OCR tag: hs.pasteboard.readAllData() returned a " .. type(items)
                    .. " instead of a table — Hammerspoon version mismatch, falling back to older readers")
                return
            end
            if type(items) ~= "table" then return end
            if #items == 0 and next(items) ~= nil then items = { items } end
            for _, item in ipairs(items) do
                if type(item) == "table" then
                    for k, v in pairs(item) do
                        if type(k) == "string" and k:lower():find("file%-url", 1, false) then
                            sawFileURL = true
                            if type(v) == "string" then consider(ocrUrlToPath(v) or v) end
                        elseif type(v) == "table" then
                            -- alternate shape seen on some builds: an array of
                            -- {uti = "...", data = "..."} entries instead of a
                            -- UTI-keyed dictionary
                            local uti  = v.uti or v.UTI or v.type
                            local data = v.data or v.value or v.contents
                            if type(uti) == "string" and uti:lower():find("file%-url", 1, false) then
                                sawFileURL = true
                                if type(data) == "string" then consider(ocrUrlToPath(data) or data) end
                            end
                        end
                    end
                end
            end
        end)

        -- Method 2 (fallback): the older readURL API — shape varies by
        -- Hammerspoon version, which is why it is no longer primary
        if #paths == 0 then
            pcall(function()
                local urls = hs.pasteboard.readURL(nil, true)
                if type(urls) ~= "table" then return end
                if urls.url or urls.filePath then urls = { urls } end
                for _, item in ipairs(urls) do
                    local u = (type(item) == "table" and (item.url or item.filePath)) or item
                    if type(u) == "string" and u:match("^file://") then sawFileURL = true end
                    consider(ocrUrlToPath(u) or u)
                end
            end)
        end

        -- Method 3 (fallback): plain text that is already a POSIX path
        -- (some tools copy full paths as text; Finder copies only NAMES
        -- as text, which rightly never match here)
        if #paths == 0 then
            pcall(function()
                local s = hs.pasteboard.readString()
                if type(s) == "string" and #s < 4000 then
                    for line in s:gmatch("[^\r\n]+") do
                        if line:sub(1, 1) == "/" then consider(line) end
                    end
                end
            end)
        end

        -- Self-diagnosis, errors only (6.98.0). LL: "Isn't this
        -- non-breaking? … do we even need to show that line or only show
        -- when it errors?" Copying non-image files is NORMAL and now prints
        -- nothing. A line appears only when something is actually wrong — a
        -- supported image that isn't readable, or a file-reference path
        -- that would not resolve — and the ⚠️ mark files it under the
        -- Console's NONBREAKING section where it belongs.
        if sawFileURL and #paths == 0 and firstMiss then
            print("⚠️ OCR tag: clipboard file URL(s) matched no usable image — " .. firstMiss)
        end
        return paths
    end

    local function ocrEscapeAS(s)
        return (s:gsub("\\", "\\\\"):gsub('"', '\\"'))
    end

    -- Write the OCR text as the file's Finder comment — via Finder
    -- scripting, the only route macOS reliably Spotlight-indexes (writing
    -- the xattr directly is NOT dependably picked up by Spotlight).
    -- Never clobbers: only writes when the current comment is empty.
    -- Returns true only when a comment was actually written.
    local function ocrWriteFinderComment(path, text)
        local snippet = text:gsub("%s+", " "):match("^%s*(.-)%s*$"):sub(1, ocr.tagMaxChars)
        if snippet == "" then return false end
        local script = 'tell application "Finder"\n'
            .. 'set theFile to (POSIX file "' .. ocrEscapeAS(path) .. '") as alias\n'
            .. 'if (comment of theFile) is "" then\n'
            .. 'set comment of theFile to "' .. ocrEscapeAS(snippet) .. '"\n'
            .. 'return "written"\n'
            .. 'else\n'
            .. 'return "skipped"\n'
            .. 'end if\n'
            .. 'end tell'
        -- 🚨 6.65.1 — OUT OF PROCESS, ALWAYS. The in-process version
        -- (hs.osascript.applescript) CRASHED Hammerspoon: an Objective-C
        -- exception in Apple Events unwinds straight PAST pcall — Lua's
        -- pcall catches Lua errors only — and aborts the app, from a path
        -- that fires on its own from the clipboard watcher. /usr/bin/osascript
        -- is the same script in a SEPARATE process: it can throw, hang or
        -- die and all that happens is a child exits. The trade, stated
        -- plainly: this function now answers "started", never "wrote" — the
        -- RESULT arrives later, in the task callback below.
        -- Full story: NEW IN 6.65.1.
        local okNew, t = pcall(hs.task.new, "/usr/bin/osascript",
            function(exitCode, stdOut, stdErr)
                local result = tostring(stdOut or ""):gsub("%s+$", "")
                if exitCode == 0 and result == "written" then
                    print("🏷 OCR → Finder comment: " .. (path:match("[^/]+$") or path))
                elseif exitCode == 0 then
                    -- "skipped" — the file already had a comment, and keeping
                    -- what you wrote by hand is the correct behaviour.
                    print("ℹ️ OCR tag: existing Finder comment kept for "
                        .. (path:match("[^/]+$") or path))
                else
                    print("⚠️ OCR tag: Finder scripting failed for " .. path
                        .. " — grant Hammerspoon Automation permission for Finder "
                        .. "(System Settings → Privacy & Security → Automation)")
                    if _G.notices then
                        _G.notices.record("ocr", "finder comment not written",
                            (path:match("[^/]+$") or path)
                            .. " — indexed for ⇪O, but Finder search will not match it")
                    end
                end
            end,
            { "-e", script })
        if not (okNew and t) then
            print("⚠️ OCR tag: could not start osascript for " .. path)
            return false
        end
        -- HELD: an unreferenced hs.task is collected mid-run, which shows up
        -- as "it works sometimes" and is miserable to chase.
        _G.ocrTagTasks = _G.ocrTagTasks or {}
        _G.ocrTagTasks[#_G.ocrTagTasks + 1] = t
        while #_G.ocrTagTasks > 20 do table.remove(_G.ocrTagTasks, 1) end
        pcall(function() t:start() end)
        return true          -- "started", not "wrote" — see the ⚠️ above
    end
    ocr.writeFinderComment = ocrWriteFinderComment

    -- One copied batch: OCR each file with the same "HS OCR" shortcut the
    -- clipboard-image path uses, then log to history + tag the file.
    -- (No pasteboard fallback for the text here — for file OCR the
    -- clipboard holds the file reference, not the extracted text.)
    function ocr.tagFiles(paths)
        if _G.ocrShortcutAvailable == false then
            print("🏷 OCR tag: skipped — Shortcuts app has no '" .. ocr.shortcutName .. "' on this Mac")
            return
        end
        for _, p in ipairs(paths or {}) do
            hs.task.new("/usr/bin/shortcuts", function(exitCode, stdOut, stdErr)
                local textOut = stdOut
                if not textOut or #textOut == 0 then return end
                textOut = stripToQwerty(textOut:gsub("%z", ""):gsub("\x1A", ""))
                if #textOut == 0 then return end

                appendRow(textOut)

                -- 6.65.1 — the tag is now written by a SEPARATE PROCESS (see
                -- the 🚨 on ocrWriteFinderComment: the in-process version was
                -- aborting Hammerspoon). It answers later, so the outcome is
                -- reported from ITS callback and there is nothing to branch on
                -- here. What this call still tells us is whether the attempt
                -- could be STARTED at all.
                local name = p:match("[^/]+$") or p
                if not ocrWriteFinderComment(p, textOut) then
                    print("ℹ️ OCR tag not attempted for " .. name
                          .. " — text is in the ⇪O history either way")
                end
            end, {"run", ocr.shortcutName, "-i", p}):start()
        end
    end

    -- ---- reading the log -------------------------------------------------
    function ocr.history()
        local f = io.open(ocr.csvFile, "rb")
        local items = {}
        if f then
            local content = f:read("*a")
            f:close()

            if content then
                content = content:gsub("%z", "")
                for line in content:gmatch("([^\r\n]+)") do
                    local timestamp, rawText = line:match("^([^,]+),(.*)$")
                    if timestamp and rawText then
                        local cleanText = rawText:gsub('^"', ''):gsub('"$', ''):gsub('""', '"'):gsub('\\n', '\n')
                        local shortTitle = cleanText:gsub("%s+", " "):sub(1, 65)
                        table.insert(items, 1, { text = shortTitle, subText = "🕒 " .. timestamp, rawText = cleanText })
                    end
                end
            end
        end
        return items
    end

    -- Same file, unformatted and oldest-first — what the editor needs.
    -- Two readers over one file rather than one reader and a transform,
    -- because the browse list is built newest-first with display text and
    -- the editor needs indexes that match the file's own order.
    local function loadOCRHistoryRaw()
        local f = io.open(ocr.csvFile, "rb")
        local items = {}
        if f then
            local content = f:read("*a"); f:close()
            if content then
                content = content:gsub("%z", "")
                for line in content:gmatch("([^\r\n]+)") do
                    local timestamp, rawText = line:match("^([^,]+),(.*)$")
                    if timestamp and rawText then
                        local cleanText = rawText:gsub('^"', ''):gsub('"$', ''):gsub('""', '"'):gsub('\\n', '\n')
                        table.insert(items, { timestamp = timestamp, text = cleanText })
                    end
                end
            end
        end
        return items
    end

    local function saveOCRHistoryRaw(entries)
        local f = io.open(ocr.csvFile, "w")
        if not f then warnWriteFailed("OCR log"); return end
        for _, e in ipairs(entries) do
            local escaped = e.text:gsub('"', '""'):gsub('\r\n', '\\n'):gsub('\r', '\\n'):gsub('\n', '\\n')
            f:write(e.timestamp .. ',"' .. escaped .. '"\n')
        end
        f:close()
    end

    -- ---- ⇪O, the search --------------------------------------------------
    _G.choosers = _G.choosers or {}
    _G.choosers.ocr = hs.chooser.new(function(c)
        if c and c.rawText then
            hs.pasteboard.setContents(c.rawText)
            hs.alert.show("📋 Copied")
        end
    end):placeholderText("Search OCR Logs...")

    function ocr.show()
        _G.choosers.ocr:choices(ocr.history())
        showPopup(_G.choosers.ocr)
        return true
    end

    -- ---- ⇪⇧O, edit or delete ---------------------------------------------
    -- A snapshot of the CSV (ocrEditSnapshot) is taken the moment the
    -- picker opens and reused by the completion callback, so a selection
    -- always maps to the row you actually saw, even if a background OCR
    -- appends a new row in between. Save with the text field emptied
    -- DELETES the entry — stated plainly in the dialog itself rather than
    -- needing a separate delete hotkey.
    local ocrEditSnapshot = {}
    -- ☑️ 6.97.0 — SELECT MODE: hs.chooser has no multi-select, so Enter
    -- TAGS rows (✓) and one action row deletes them all. Index-keyed tags
    -- are safe HERE because the snapshot is frozen while the picker is
    -- open — background OCRs append to the CSV, never to this table.
    local ocrEditSelect, ocrEditTagged = false, {}

    local function ocrEditRender()
        local choices = {}
        if ocrEditSelect then
            local n = 0
            for _ in pairs(ocrEditTagged) do n = n + 1 end
            table.insert(choices, {
                text    = (n == 0) and "☑️ Nothing picked yet"
                          or ("🗑 Delete the " .. n .. " I picked"),
                subText = (n == 0) and "Go down the list and press Enter on the rows you want"
                          or "Press Enter HERE to delete them all",
                action  = "deletetagged",
            })
            table.insert(choices, { text = "✖️ Never mind — go back",
                subText = "Forget the picks and return to one-at-a-time editing",
                action = "selectoff" })
        else
            table.insert(choices, { text = "☑️ Delete several at once…",
                subText = "Pick rows with Enter, then delete them together",
                action = "selecton" })
        end
        for i = #ocrEditSnapshot, 1, -1 do   -- newest first, matches the browse picker
            local e = ocrEditSnapshot[i]
            table.insert(choices, {
                text    = (ocrEditTagged[i] and "✓ " or "") .. e.text:gsub("%s+", " "):sub(1, 100),
                subText = "🕒 " .. e.timestamp .. "  ·  "
                          .. (ocrEditSelect
                              and (ocrEditTagged[i] and "PICKED — Enter unpicks it" or "Enter picks it")
                              or "Enter to edit or delete"),
                idx     = i,
            })
        end
        _G.choosers.ocrEdit:choices(choices)
    end

    -- =====================================================================
    -- ✍️ 6.115.0 — THE ENTRY EDITOR, AS A WINDOW
    -- =====================================================================
    -- What this replaces and why it could not be tuned instead: see the
    -- ✏️ EDIT HERE block at the top. Short version — the old control was a
    -- one-line NSTextField that cannot scroll and cannot take a Return,
    -- and OCR text is multi-line by definition.
    --
    -- 🚨 THE FALLBACK IS NOT DECORATION. This has to work on the managed
    -- work Mac, and hs.webview is the piece most likely to be missing or
    -- restricted there. Every path below that can fail falls back to the
    -- small prompt rather than leaving ⇪⇧O doing nothing: a worse box
    -- still edits the entry, and a dead key does not.
    local function esc(s)
        return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;")
                                 :gsub(">", "&gt;"):gsub('"', "&quot;"))
    end

    -- The one place that decides what saving means, so the window and the
    -- fallback prompt cannot drift apart on the rule that matters most:
    -- an emptied box DELETES. (Now also reachable as a button — "save it
    -- empty to delete" is a fine rule and a terrible thing to have to
    -- discover from a sentence you did not read.)
    function ocr.applyEdit(idx, text)
        local entry = ocrEditSnapshot[idx]
        if not entry then return false end
        if not text or text:match("^%s*$") then
            table.remove(ocrEditSnapshot, idx)
            saveOCRHistoryRaw(ocrEditSnapshot)
            hs.alert.show("🗑 OCR entry deleted")
        else
            entry.text = text
            saveOCRHistoryRaw(ocrEditSnapshot)
            hs.alert.show("✏️ OCR entry updated")
        end
        return true
    end

    function ocr.editorHtml(opts)
        return table.concat({
[[<meta charset="utf-8"><style>
  :root { color-scheme: dark; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,sans-serif;
         font-size:14px; background:#141418; color:#e8e8ec; }
  header { padding:12px 18px 8px; border-bottom:1px solid #2a2a32;
           cursor:grab; user-select:none; -webkit-user-select:none; }
  header:active, header.dragging { cursor:grabbing; }
  h1 { font-size:15px; margin:0 0 2px; font-weight:600; }
  .grip { color:#4a4a56; margin-right:8px; letter-spacing:2px; }
  .sub { color:#8a8a96; font-size:12px; }
  #wrap { padding:12px 18px 14px; }
  /* Longhand font rules on purpose — the shorthand+keyword mix is the
     invalid combination WebKit drops whole (the 6.44.1 textarea bug). */
  textarea { width:100%; box-sizing:border-box; resize:none;
             background:#1d1d24; color:#f2f2f6; border:1px solid #33333e;
             border-radius:8px; padding:11px;
             font-family:Menlo,ui-monospace,monospace;
             line-height:1.45; }
  textarea:focus { outline:none; border-color:#4a7fe0; }
  .bar { margin-top:11px; display:flex; gap:9px; align-items:center; }
  .count { color:#8a8a96; font-size:12px; margin-right:auto;
           font-variant-numeric:tabular-nums; }
  button { background:#2a2a34; color:#e8e8ec; border:1px solid #3b3b47;
           border-radius:7px; padding:7px 13px; font-size:13px; cursor:pointer; }
  button:hover { filter:brightness(1.18); }
  button.go { background:#3566cc; border-color:#4a7fe0; }
  button.rm { background:#4a2530; border-color:#6b3542; }
</style>
<header id="hdr"><h1><span class="grip">⠿</span>]],
            esc(opts.title),
[[</h1><div class="sub">]], esc(opts.sub), [[</div></header>
<div id="wrap">
  <textarea id="t" rows="]], tostring(opts.rows or 16),
            [[" spellcheck="false" placeholder="The extracted text. Empty it to delete this entry.">]],
            esc(opts.text), [[</textarea>
  <div class="bar">
    <span class="count" id="c"></span>
    <button type="button" class="rm" onclick="say({a:'delete'})">Delete entry</button>
    <button type="button" onclick="say({a:'cancel'})">Cancel (Esc)</button>
    <button type="button" class="go" onclick="save()">Save (⌘⏎)</button>
  </div>
</div>
<script>
  var t = document.getElementById('t'), c = document.getElementById('c');
  function say(m) {
    try { webkit.messageHandlers.ocrEdit.postMessage(m); } catch (e) {}
  }
  /* No cap to warn about — an OCR entry is as long as the page was — so
     the count is orientation rather than a limit: it is how you tell a
     truncated capture from a short one. */
  function tally() {
    var n = Array.from(t.value).length,
        l = t.value === '' ? 0 : t.value.split('\n').length;
    c.textContent = n + ' characters · ' + l + (l === 1 ? ' line' : ' lines');
  }
  function save() { say({ a: 'save', text: t.value }); }
  t.addEventListener('input', tally);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { say({ a: 'cancel' }); return; }
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); save(); }
  });
  /* The header is the title bar: hs.webview windows are borderless, and a
     WKWebView loses the mouse the moment the pointer leaves it, so the
     drag is finished on the Lua side. */
  document.getElementById('hdr').addEventListener('mousedown', function () {
    say({ a: 'drag' });
  });
  t.style.fontSize = ']], tostring(opts.font or 14), [[px';
  /* 🎯 Focused and caret-placed on open. This is the "I have to click on
     it" complaint: a box you must click before typing is a box that
     interrupted you twice. */
  t.focus();
  t.setSelectionRange(t.value.length, t.value.length);
  tally();
</script>]],
        })
    end

    -- ---- dragging the editor by its header --------------------------------
    -- ⚠️ THE FOURTH COPY OF THIS LOOP in the config (Capture Pad, Quick
    -- Append Pad, Window Pin, here). A WKWebView loses the mouse the
    -- moment the pointer leaves it, so the page only reports that a drag
    -- STARTED and the move is driven from Lua. It is copied rather than
    -- shared because there is no shared helper yet — and at four copies
    -- there should be. Extracting one is the right next move; doing it
    -- inside a release about something else is how three working windows
    -- get broken at once.
    local function mousePosition()
        local fns = {}
        if hs.mouse then
            if type(hs.mouse.absolutePosition) == "function" then
                fns[#fns + 1] = hs.mouse.absolutePosition
            end
            if type(hs.mouse.getAbsolutePosition) == "function" then
                fns[#fns + 1] = hs.mouse.getAbsolutePosition
            end
        end
        for _, fn in ipairs(fns) do
            local ok, p = pcall(fn)
            if ok and type(p) == "table" and p.x and p.y then return p end
        end
        return nil
    end

    local function leftButtonDown()
        local ok, down = pcall(function()
            return hs.eventtap.checkMouseButtons().left == true
        end)
        return ok and down
    end

    function ocr.endDrag()
        if ocr.dragTimer then pcall(function() ocr.dragTimer:stop() end) end
        ocr.dragTimer, ocr.dragOffset = nil, nil
    end

    function ocr.beginDrag()
        ocr.endDrag()
        if not ocr.editorView then return false end
        local okF, f = pcall(function() return ocr.editorView:frame() end)
        if not (okF and f) then return false end
        local m = mousePosition()
        if not m then return false end
        ocr.dragOffset = { x = m.x - f.x, y = m.y - f.y }
        local okT = pcall(function()
            ocr.dragTimer = hs.timer.doEvery(0.016, function()
                if not (ocr.editorView and ocr.dragOffset) then ocr.endDrag() return end
                if not leftButtonDown() then ocr.endDrag() return end
                local p = mousePosition()
                if not p then ocr.endDrag() return end
                pcall(function()
                    local cur = ocr.editorView:frame()
                    ocr.editorView:frame({ x = p.x - ocr.dragOffset.x,
                                           y = p.y - ocr.dragOffset.y,
                                           w = cur.w, h = cur.h })
                end)
            end)
        end)
        if not (okT and ocr.dragTimer) then ocr.endDrag() return false end
        return true
    end

    function ocr.closeEditor()
        ocr.endDrag()
        if ocr.editorView then
            pcall(function() ocr.editorView:delete() end)
        end
        ocr.editorView, ocr.editorUc, ocr.editorIdx = nil, nil, nil
    end

    function ocr.handleEditorMessage(body)
        if type(body) ~= "table" then return end
        if body.a == "drag" then pcall(ocr.beginDrag) return end
        local idx = ocr.editorIdx
        if body.a == "cancel" then ocr.closeEditor() return end
        if not idx then return end
        if body.a == "delete" then
            ocr.closeEditor()
            ocr.applyEdit(idx, "")
            return
        end
        if body.a == "save" then
            ocr.closeEditor()
            ocr.applyEdit(idx, body.text)
        end
    end

    -- A Mac with no webview must still be able to edit. Smaller box, same
    -- meaning, same delete-on-empty rule — ocr.applyEdit decides both.
    local function editorPromptFallback(idx)
        local entry = ocrEditSnapshot[idx]
        if not entry then return false end
        local okDlg, button, text = pcall(hs.dialog.textPrompt,
            "✏️ Edit OCR entry (" .. entry.timestamp .. ")",
            "Edit the extracted text below.\nSave with it EMPTY to delete this entry.",
            entry.text, "Save", "Cancel")
        if not okDlg then
            hs.alert.show("📋 OCR: the editor would not open — see the Console")
            print("📋 OCR edit: hs.dialog.textPrompt failed — " .. tostring(button))
            return false
        end
        if button ~= "Save" then return false end
        return ocr.applyEdit(idx, text)
    end

    function ocr.openEditor(idx)
        local entry = ocrEditSnapshot[idx]
        if not entry then return false end
        if not (hs.webview and hs.webview.usercontent) then
            return editorPromptFallback(idx)
        end
        ocr.closeEditor()                      -- never two at once

        local screen = (core.resolveBaseScreen and core.resolveBaseScreen())
                       or hs.screen.mainScreen()
        local sf = (screen and screen:frame()) or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(ocr.editorW, sf.w - 40)
        local h = math.min(ocr.editorH, sf.h - 40)
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 3,
                       w = w, h = h }

        local okUc, uc = pcall(hs.webview.usercontent.new, "ocrEdit")
        if not (okUc and uc) then return editorPromptFallback(idx) end
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(ocr.handleEditorMessage, msg and msg.body)
                if not ok then print("📋 OCR edit: message handler — " .. tostring(err)) end
            end)
        end)

        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then return editorPromptFallback(idx) end
        ocr.editorUc, ocr.editorView, ocr.editorIdx = uc, view, idx

        pcall(function() view:windowTitle("Edit OCR entry") end)
        -- allowTextEntry sets canBecomeKeyWindow — without it the box
        -- draws perfectly and swallows every keystroke.
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        pcall(function()
            view:html(ocr.editorHtml({
                title = "✏️ Edit OCR entry",
                sub   = "🕒 " .. tostring(entry.timestamp)
                        .. "  ·  ⌘⏎ saves · Esc cancels · empty the box to delete",
                text  = entry.text,
                rows  = ocr.editorRows,
                font  = ocr.editorFont,
            }))
        end)
        pcall(function() view:show() end)
        -- 🎯 DELIBERATELY ACTIVATING, unlike Window Pin's editor. That one
        -- must not pull Hammerspoon forward because it hides its note when
        -- the app loses focus. This box has no such rule and one job —
        -- being typed into — so it comes to the front and takes the caret.
        pcall(function() view:bringToFront(true) end)
        return true
    end

    _G.choosers.ocrEdit = hs.chooser.new(function(choice)
        if not choice then return end
        local function reopen() ocrEditRender(); showPopup(_G.choosers.ocrEdit) end
        if choice.action == "selecton" then
            ocrEditSelect, ocrEditTagged = true, {}
            reopen(); return
        elseif choice.action == "selectoff" then
            ocrEditSelect, ocrEditTagged = false, {}
            reopen(); return
        elseif choice.action == "deletetagged" then
            local kept, removed = {}, 0
            for i, e in ipairs(ocrEditSnapshot) do
                if ocrEditTagged[i] then removed = removed + 1 else kept[#kept + 1] = e end
            end
            ocrEditSelect, ocrEditTagged = false, {}
            if removed > 0 then
                ocrEditSnapshot = kept
                saveOCRHistoryRaw(ocrEditSnapshot)
                hs.alert.show("🗑 Deleted " .. removed .. " OCR entr"
                              .. ((removed == 1) and "y" or "ies"))
            else
                hs.alert.show("Nothing picked — press Enter on the rows you want first")
            end
            return
        end
        if not choice.idx then return end
        local entry = ocrEditSnapshot[choice.idx]
        if not entry then return end
        if ocrEditSelect then
            if ocrEditTagged[choice.idx] then ocrEditTagged[choice.idx] = nil
            else ocrEditTagged[choice.idx] = true end
            reopen(); return
        end

        ocr.openEditor(choice.idx)
    end)
    _G.choosers.ocrEdit:placeholderText("Select an OCR entry — Enter opens it to edit or delete")

    function ocr.edit()
        -- 🚨 CLOSE ANY OPEN BOX FIRST. ocr.edit RE-READS the CSV into
        -- ocrEditSnapshot, and an editor left open from a previous ⇪⇧O
        -- still holds an INDEX into the old snapshot — saving it would
        -- write over whichever entry now happens to sit at that position.
        -- The window is not modal any more, so this is reachable simply by
        -- pressing ⇪⇧O twice.
        ocr.closeEditor()
        ocrEditSnapshot = loadOCRHistoryRaw()
        if #ocrEditSnapshot == 0 then
            hs.alert.show("📋 OCR history is empty")
            return false
        end
        ocrEditSelect, ocrEditTagged = false, {}
        ocrEditRender()
        showPopup(_G.choosers.ocrEdit)
        return true
    end

    -- 🪟 The editor joins the panels ⇪⇧W can move, like every other window
    -- this config opens — a box that lands on the wrong monitor and cannot
    -- be moved by the tool built for moving them is a box you close.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "OCR entry editor",
        frame = function() return ocr.editorView and ocr.editorView:frame() end,
        move  = function(x, y)
            local f = ocr.editorView and ocr.editorView:frame()
            if f then ocr.editorView:frame({ x = x, y = y, w = f.w, h = f.h }) end
        end,
    })

    -- 🗂 6.116.0 — listed for the ⌘⌘ editor picker. `size` reads the CSV,
    -- which is a disk read — acceptable because the picker only ever opens
    -- on a deliberate gesture, exactly like ⇪O itself. ⌥⏎ copies the most
    -- recent capture, which is the thing you nearly always want back.
    _G.editors = _G.editors or {}
    table.insert(_G.editors, {
        name  = "OCR text",
        key   = "⇪⇧O",
        what  = "text lifted off screenshots",
        order = 30,
        unit  = "captures",
        view  = function() return ocr.editorView end,
        show  = function() ocr.edit() end,
        size  = function() return #ocr.history() end,
        text  = function()
            local h = ocr.history()
            return h[1] and h[1].rawText or nil
        end,
        -- 💾 6.130.0 — every capture, for the one-file CSV export.
        --
        -- 🚨 rawText, NOT .text. history() carries BOTH: .text is a
        -- 65-character single-line title built for a picker row, and
        -- exporting that would produce a spreadsheet of truncated
        -- previews that looks complete and is not. .rawText is the
        -- capture. The 🕒 is stripped off the timestamp because the When
        -- column is a date, not a label.
        csv   = function()
            local out = {}
            for _, it in ipairs(ocr.history()) do
                if type(it) == "table" and type(it.rawText) == "string" then
                    local when = tostring(it.subText or ""):gsub("^🕒%s*", "")
                    out[#out + 1] = { when = when, text = it.rawText }
                end
            end
            return out
        end,
    })

    -- ⎋ through the shared router, so the cheat sheet still closes LAST.
    -- The page handles Escape itself while it has the keyboard; this is
    -- for the case where it does not — the box is up but focus went
    -- somewhere else, which is exactly when an un-closable window is worst.
    if _G.claimEscape then
        _G.claimEscape("ocredit", nil,
            function() return ocr.editorView ~= nil end,
            function() ocr.closeEditor() end)
    end

    -- ---- the keys --------------------------------------------------------
    -- 🚨 CLAIMED DIRECTLY, NOT THROUGH _G.hyperKeyMap. The map exists to
    -- redirect chords that init.lua still binds; a module that binds its
    -- own keys must claim them here and have its map entries REMOVED, or
    -- both halves fire and the boot report calls it a hyper conflict.
    -- Exactly what clipboard_history had to do in 6.57.0, for the same
    -- reason and with the same symptom.
    if ocr.enabled then
        core.hyperAddShortcut({}, ocr.key, function() ocr.show() end,
                              "OCR log search")
        core.hyperAddShortcut({ "shift" }, ocr.key, function() ocr.edit() end,
                              "OCR log edit")
    end

    -- ---- what init.lua's clipboard watcher calls -------------------------
    core.provide("ocr.clipboardFiles", function() return ocr.clipboardFiles() end)
    core.provide("ocr.tagFiles",       function(p) return ocr.tagFiles(p) end)
    core.provide("ocr.image",          function(i) return ocr.image(i) end)
    core.provide("ocr.show",           function() return ocr.show() end)
    core.provide("ocr.edit",           function() return ocr.edit() end)
    core.provide("ocr.history",        function() return ocr.history() end)

    _G.ocrEngine = ocr
    M.config = ocr
end

return M
