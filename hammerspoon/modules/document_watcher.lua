-- =====================================================================
-- MODULE: DOCUMENT WATCHER (was X.1) — ⇪W list · ⇪⇧E edit · doc_wather.csv
-- =====================================================================
-- Records every document you actually work in, with how long you spent
-- in it, and gives you a searchable list.
--
-- SELF-CONTAINED BY DESIGN. Everything lives inside the immediately
-- invoked function below: its own state, its own file, its own timers,
-- its own pickers. It reads logsDir, showPopup, csvQuote and
-- _G.hyperAddShortcut from the rest of the config and touches nothing
-- else. Deleting this whole block leaves the rest of init.lua working.
--
-- ⚠️ THREE THINGS I COULD NOT BUILD AS ASKED — hs.chooser limits, not
--    preferences. Read these before judging the result:
--
--    1. SHIFT-CLICK MULTI-SELECT does not exist. hs.chooser is a
--       single-selection list; there is no API for a second selected
--       row, and no click handler that reports modifier keys. Instead
--       there is a SELECT MODE: Enter tags a row (✓), and a "Copy N
--       tagged" row copies them all at once. Same outcome, supported
--       API.
--    2. BARE "W" INSIDE THE WINDOW cannot be an edit command. The
--       keyboard belongs to the search field, so pressing W types a "w"
--       into your search. You asked for search AND bare-letter commands
--       in the same window; those are mutually exclusive. Editing is on
--       ⇪⇧E instead, and works while the list is open.
--    3. ⇪W was already the app-summon picker. That moved to ⇪⇧W.
--
-- HOW TIME IS MEASURED: the frontmost window is sampled every 5s. A
-- sample only counts if you are actually present (no keyboard/mouse for
-- 2 minutes stops the clock) and if the gap since the last sample is
-- sane. After sleep or a long stall the gap is discarded rather than
-- billed to whatever document happened to be open — that is the
-- "dump it if it is not accurate" rule.

-- Moved out of init.lua in 6.40.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "Document Watcher",
    order = 11,
    cheatsheet = {
        title = "📄 DOCUMENT WATCHER (experimental)",
        entries = {
            { "⇪⇧W", "Documents worked on today — search name / ext / date" },
            { "Enter", "Copy the highlighted row" },
            { "☑️ row", "Copy several: pick rows with Enter, then copy together" },
            { "⇪⇧E", "Edit or delete an entry (clear the name = delete)" },
            { "☑️ row", "Delete several: pick rows with Enter, then together" },
            { "auto", "Samples every 5s · stops when you are idle" },
            { "file", "Logs/doc_wather.csv — Date · Time · File · Working time" }
        },
    },
}

function M.setup(core)
    ;(function()

    local docEnabled       = true
    local docFile          = core.logsDir .. "/doc_wather.csv"   -- spelling as requested
    local docPollSeconds   = 5      -- how often the frontmost window is sampled
    local docIdleCutoff    = 120    -- no input for this long = stop the clock
    local docSaveSeconds   = 60     -- how often the CSV is flushed
    local docMaxRows       = 500    -- rows shown in the picker at once

    if not docEnabled then return end

    -- ---- state -----------------------------------------------------------
    -- rows: { date=, time=, file=, secs= } — one per document per day.
    local docRows      = {}
    local docIndex     = {}     -- "date|file" -> row, so a sample is O(1)
    local docDirty     = false
    local docLastKey   = nil    -- which doc the previous sample saw
    local docLastStamp = nil    -- os.time() of the previous sample
    local docTagged    = {}     -- "date|file" -> true, in select mode
    local docSelectMode = false

    local function docKey(date, file) return date .. "|" .. file end

    -- ---- time formatting -------------------------------------------------
    local function docFormatSecs(secs)
        secs = math.max(0, math.floor(tonumber(secs) or 0))
        return string.format("%d:%02d:%02d", secs // 3600, (secs % 3600) // 60, secs % 60)
    end

    -- Strict on purpose: anything that is not exactly H:MM:SS is treated as
    -- corrupt and the row is dropped rather than guessed at.
    local function docParseSecs(text)
        local h, m, sec = tostring(text or ""):match("^(%d+):(%d%d):(%d%d)$")
        if not h then return nil end
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
    end

    -- ---- CSV -------------------------------------------------------------
    -- Minimal RFC-4180 field splitter: handles quoted fields containing
    -- commas, which filenames genuinely do.
    local function docSplitCSV(line)
        local out, field, inQuotes, i = {}, {}, false, 1
        while i <= #line do
            local c = line:sub(i, i)
            if inQuotes then
                if c == '"' then
                    if line:sub(i + 1, i + 1) == '"' then
                        table.insert(field, '"'); i = i + 1
                    else
                        inQuotes = false
                    end
                else
                    table.insert(field, c)
                end
            elseif c == '"' then
                inQuotes = true
            elseif c == "," then
                table.insert(out, table.concat(field)); field = {}
            else
                table.insert(field, c)
            end
            i = i + 1
        end
        table.insert(out, table.concat(field))
        return out
    end

    local DOC_HEADER = "Date,Time of day,File name,Working time"

    local function docLoad()
        docRows, docIndex = {}, {}
        local f = io.open(docFile, "r")
        if not f then return end
        local content = f:read("*a"); f:close()
        local dropped, first = 0, true
        for line in content:gmatch("[^\r\n]+") do
            if first then
                first = false
                if line:sub(1, 4):lower() == "date" then goto continue end
            end
            do
                local c = docSplitCSV(line)
                local date, time, file, worked = c[1], c[2], c[3], c[4]
                local secs = docParseSecs(worked)
                -- Every field must be present and well formed, or the row is
                -- discarded. A half-written row from a crash is worse than a
                -- missing one, because it would silently skew the totals.
                if date and date:match("^%d%d%d%d%-%d%d%-%d%d$")
                   and time and time:match("^%d%d:%d%d$")
                   and file and file:match("%S") and secs then
                    local row = { date = date, time = time, file = file, secs = secs }
                    table.insert(docRows, row)
                    docIndex[docKey(date, file)] = row
                else
                    dropped = dropped + 1
                end
            end
            ::continue::
        end
        if dropped > 0 then
            print("📄 Document Watcher: dropped " .. dropped
                .. " malformed row(s) from doc_wather.csv rather than trust them")
        end
    end

    local function docSave()
        if not docDirty then return end
        local f = io.open(docFile, "w")
        if not f then
            print("🚨 Document Watcher: cannot write " .. docFile)
            return
        end
        f:write(DOC_HEADER .. "\n")
        for _, r in ipairs(docRows) do
            f:write(r.date .. "," .. r.time .. "," .. core.csvQuote(r.file)
                .. "," .. docFormatSecs(r.secs) .. "\n")
        end
        f:close()
        docDirty = false
    end

    -- ---- what counts as a document --------------------------------------
    -- Window titles look like "Report.docx — Word", "notes.md - Sublime",
    -- "Untitled.txt — Edited". Take the part before the separator and insist
    -- it looks like a real filename. Anything else is dumped: a wrong entry
    -- is worse than a missing one in a log you are going to trust.
    local docTitleSeparators = { " — ", " – ", " - ", " — " }

    local function docExtractFileName(title, appName)
        if type(title) ~= "string" then return nil end
        local head = title
        for _, sep in ipairs(docTitleSeparators) do
            local cut = head:find(sep, 1, true)
            if cut then head = head:sub(1, cut - 1) end
        end
        head = head:gsub("^%s+", ""):gsub("%s+$", "")
        if head == "" then return nil end
        if appName and head == appName then return nil end
        -- Must end in a plausible extension.
        local base, ext = head:match("^(.+)%.([%a%d]+)$")
        if not base or not ext then return nil end
        if #ext < 1 or #ext > 6 then return nil end
        if base:match("^%s*$") then return nil end
        return head
    end

    _G.docExtractFileNameForTest = docExtractFileName
    _G.docParseSecsForTest       = docParseSecs
    _G.docFormatSecsForTest      = docFormatSecs
    _G.docRowsForTest            = function() return docRows end
    _G.docSaveForTest            = function() docDirty = true; docSave() end
    _G.docFileForTest            = docFile
    _G.docLoadForTest            = function() docLoad() end
    _G.docResetSamplerForTest    = function() docLastKey, docLastStamp = nil, nil end

    -- ---- the sampler -----------------------------------------------------
    local function docSample()
        local now = os.time()

        -- Away from the keyboard? Stop the clock and forget where we were,
        -- so the idle gap is never billed to the document.
        local okIdle, idle = pcall(hs.host.idleTime)
        if okIdle and type(idle) == "number" and idle > docIdleCutoff then
            docLastKey, docLastStamp = nil, nil
            return
        end

        local okApp, app = pcall(hs.application.frontmostApplication)
        if not okApp or not app then docLastKey, docLastStamp = nil, nil; return end
        local okName, appName = pcall(function() return app:name() end)
        if not okName then appName = nil end

        local okWin, win = pcall(function() return app:focusedWindow() or app:mainWindow() end)
        if not okWin or not win then docLastKey, docLastStamp = nil, nil; return end
        local okTitle, title = pcall(function() return win:title() end)
        if not okTitle then docLastKey, docLastStamp = nil, nil; return end

        local file = docExtractFileName(title, appName)
        if not file then docLastKey, docLastStamp = nil, nil; return end

        local date = os.date("%Y-%m-%d", now)
        local key  = docKey(date, file)

        -- Bill the elapsed time only when this is the SAME document as last
        -- sample and the gap is sane. After sleep, a long stall, or a date
        -- rollover the gap is discarded — see the "dump it" rule above.
        if docLastKey == key and docLastStamp then
            local delta = now - docLastStamp
            if delta > 0 and delta <= docPollSeconds * 3 then
                local row = docIndex[key]
                if not row then
                    row = { date = date, time = os.date("%H:%M", now), file = file, secs = 0 }
                    table.insert(docRows, row)
                    docIndex[key] = row
                end
                row.secs = row.secs + delta
                docDirty = true
            end
        else
            -- First sighting today: create the row with a 0 time so it shows
            -- up in the list (and the tally) straight away.
            if not docIndex[key] then
                local row = { date = date, time = os.date("%H:%M", now), file = file, secs = 0 }
                table.insert(docRows, row)
                docIndex[key] = row
                docDirty = true
            end
        end

        docLastKey, docLastStamp = key, now
    end

    _G.docSampleForTest = docSample

    -- ---- the list (⇪W) ---------------------------------------------------
    local function docTodayTally()
        -- os.date() with no time argument reads the WALL CLOCK, while every
        -- row is stamped from os.time(). Those are the same thing on a real
        -- Mac right up until they aren't — across midnight, or under a test
        -- clock — and then "documents today" silently reports zero. Same
        -- source for both, always.
        local today, count, secs = os.date("%Y-%m-%d", os.time()), 0, 0
        for _, r in ipairs(docRows) do
            if r.date == today then count = count + 1; secs = secs + r.secs end
        end
        return count, secs
    end

    local function docCountTagged()
        local n = 0
        for _ in pairs(docTagged) do n = n + 1 end
        return n
    end

    local function docRowText(r)
        return r.file .. "   ·   " .. docFormatSecs(r.secs)
    end

    local function docCopyRows(rows)
        local lines = {}
        for _, r in ipairs(rows) do
            table.insert(lines, r.date .. "  " .. r.time .. "  " .. r.file
                .. "  " .. docFormatSecs(r.secs))
        end
        if #lines == 0 then return 0 end
        hs.pasteboard.setContents(table.concat(lines, "\n"))
        return #lines
    end

    local function docRenderList(query)
        local q = tostring(query or ""):lower():match("^%s*(.-)%s*$")
        local choices = {}
        local count, secs = docTodayTally()

        -- The running tally, always the first row.
        table.insert(choices, {
            text    = "📊 " .. count .. " document" .. ((count == 1) and "" or "s")
                      .. " today   ·   " .. docFormatSecs(secs) .. " worked",
            subText = "Type to search by name, extension or date",
            action  = "noop",
        })

        if docSelectMode then
            local picked = docCountTagged()
            table.insert(choices, {
                text    = (picked == 0) and "📋 Nothing picked yet"
                          or ("📋 Copy the " .. picked .. " document"
                              .. ((picked == 1) and "" or "s") .. " I picked"),
                subText = (picked == 0)
                          and "Go down the list and press Enter on the ones you want"
                          or "Press Enter HERE when you have picked them all",
                action  = "copytagged",
            })
            table.insert(choices, {
                text = "✖️ Never mind — go back",
                subText = "Forget the picks and return to the normal list",
                action = "selectoff",
            })
        else
            table.insert(choices, {
                text    = "☑️ Copy several at once…",
                subText = "Pick rows one at a time, then copy them together",
                action  = "selecton",
            })
        end

        -- Newest first: same date order as the file, reversed.
        local shown = 0
        for i = #docRows, 1, -1 do
            local r = docRows[i]
            local hay = (r.file .. " " .. r.date .. " " .. r.time):lower()
            if q == "" or hay:find(q, 1, true) then
                local isPicked = docTagged[docKey(r.date, r.file)]
                local hint
                if not docSelectMode then
                    hint = "Enter copies this one"
                elseif isPicked then
                    hint = "PICKED — Enter removes it from the copy list"
                else
                    hint = "Enter adds this to the copy list"
                end
                table.insert(choices, {
                    text    = (isPicked and "✓ " or "") .. docRowText(r),
                    subText = r.date .. "  " .. r.time .. "   ·   " .. hint,
                    action  = "row", key = docKey(r.date, r.file),
                })
                shown = shown + 1
                if shown >= docMaxRows then break end
            end
        end

        if shown == 0 then
            table.insert(choices, {
                text    = (q == "") and "No documents recorded yet"
                          or ("No matches for \"" .. q .. "\""),
                subText = "Documents appear once you have worked in one for a few seconds",
                action  = "noop",
            })
        end

        _G.choosers.docWatcher:choices(choices)
    end

    _G.docRenderListForTest = function(q)
        docRenderList(q)
        return _G.choosers.docWatcher.lastChoices
    end
    _G.docSelectModeForTest = function(on) docSelectMode = on and true or false end
    _G.docTaggedForTest     = function() return docTagged end

    local function docFindRow(key)
        for _, r in ipairs(docRows) do
            if docKey(r.date, r.file) == key then return r end
        end
        return nil
    end

    _G.choosers.docWatcher = hs.chooser.new(function(c)
        if not c or not c.action or c.action == "noop" then return end

        if c.action == "selecton" then
            docSelectMode, docTagged = true, {}
            docRenderList(""); _G.choosers.docWatcher:query("")
            core.showPopup(_G.choosers.docWatcher)

        elseif c.action == "selectoff" then
            docSelectMode, docTagged = false, {}
            docRenderList(""); _G.choosers.docWatcher:query("")
            core.showPopup(_G.choosers.docWatcher)

        elseif c.action == "copytagged" then
            local rows = {}
            for _, r in ipairs(docRows) do
                if docTagged[docKey(r.date, r.file)] then table.insert(rows, r) end
            end
            local n = docCopyRows(rows)
            hs.alert.show((n > 0)
                and ("📋 Copied " .. n .. " document" .. ((n == 1) and "" or "s"))
                or "Nothing picked — press Enter on the rows you want first")

        elseif c.action == "row" then
            local row = docFindRow(c.key)
            if not row then return end
            if docSelectMode then
                -- Tag / untag, then reopen so the ✓ and the count update.
                if docTagged[c.key] then docTagged[c.key] = nil else docTagged[c.key] = true end
                docRenderList(""); _G.choosers.docWatcher:query("")
                core.showPopup(_G.choosers.docWatcher)
            else
                docCopyRows({ row })
                hs.alert.show("📋 Copied " .. row.file)
            end
        end
    end)
    _G.choosers.docWatcher:placeholderText("Documents worked on — search by name, extension or date")
    _G.choosers.docWatcher:queryChangedCallback(function(query)
        local ok, err = pcall(docRenderList, query)
        if not ok then
            print("🚨 Document Watcher render error: " .. tostring(err))
            _G.choosers.docWatcher:choices({
                { text = "⚠️ Display error — see Hammerspoon Console", subText = tostring(err) },
            })
        end
    end)

    -- ---- edit / delete (⇪⇧E) --------------------------------------------
    -- ☑️ 6.97.0 — the same select mode the ⇪⇧W list has had since day
    -- one, here for DELETING: pick rows with Enter, delete them together.
    local docEditSelect = false
    local docEditTagged = {}     -- "date|file" -> true

    local function docRenderEdit(query)
        local q = tostring(query or ""):lower():match("^%s*(.-)%s*$")
        local choices = {}
        if #docRows == 0 then
            -- An empty log gets no action rows — nothing to pick.
        elseif docEditSelect then
            local picked = 0
            for _ in pairs(docEditTagged) do picked = picked + 1 end
            table.insert(choices, {
                text    = (picked == 0) and "☑️ Nothing picked yet"
                          or ("🗑 Delete the " .. picked .. " entr"
                              .. ((picked == 1) and "y" or "ies") .. " I picked"),
                subText = (picked == 0)
                          and "Go down the list and press Enter on the ones to delete"
                          or "Press Enter HERE to delete them all",
                action  = "deletetagged",
            })
            table.insert(choices, {
                text = "✖️ Never mind — go back",
                subText = "Forget the picks and return to one-at-a-time editing",
                action = "editselectoff",
            })
        else
            table.insert(choices, {
                text    = "☑️ Delete several at once…",
                subText = "Pick rows one at a time, then delete them together",
                action  = "editselecton",
            })
        end
        local shown = 0
        for i = #docRows, 1, -1 do
            local r = docRows[i]
            local hay = (r.file .. " " .. r.date):lower()
            if q == "" or hay:find(q, 1, true) then
                local key = docKey(r.date, r.file)
                local isPicked = docEditTagged[key]
                local hint
                if not docEditSelect then hint = "Enter to rename or delete"
                elseif isPicked then hint = "PICKED — Enter unpicks it"
                else hint = "Enter adds this to the delete list" end
                table.insert(choices, {
                    text    = (isPicked and "✓ " or "✏️ ") .. docRowText(r),
                    subText = r.date .. "  " .. r.time .. "  ·  " .. hint,
                    action  = "edit", key = key,
                })
                shown = shown + 1
                if shown >= docMaxRows then break end
            end
        end
        if shown == 0 then
            table.insert(choices, { text = "Nothing to edit", subText = "No matching rows" })
        end
        _G.choosers.docWatcherEdit:choices(choices)
    end

    _G.docRenderEditForTest = function(q)
        docRenderEdit(q)
        return _G.choosers.docWatcherEdit.lastChoices
    end
    _G.docEditSelectForTest = function(on) docEditSelect = on and true or false end
    _G.docEditTaggedForTest = function() return docEditTagged end

    _G.choosers.docWatcherEdit = hs.chooser.new(function(c)
        if not c or not c.action then return end
        local function reopen()
            docRenderEdit(""); _G.choosers.docWatcherEdit:query("")
            core.showPopup(_G.choosers.docWatcherEdit)
        end
        if c.action == "editselecton" then
            docEditSelect, docEditTagged = true, {}
            reopen(); return
        elseif c.action == "editselectoff" then
            docEditSelect, docEditTagged = false, {}
            reopen(); return
        elseif c.action == "deletetagged" then
            local removed = 0
            for i = #docRows, 1, -1 do
                local r = docRows[i]
                local key = docKey(r.date, r.file)
                if docEditTagged[key] then
                    table.remove(docRows, i)
                    docIndex[key] = nil
                    removed = removed + 1
                end
            end
            docEditSelect, docEditTagged = false, {}
            if removed > 0 then
                docDirty = true; docSave()
                hs.alert.show("🗑 Deleted " .. removed .. " entr"
                              .. ((removed == 1) and "y" or "ies"))
            else
                hs.alert.show("Nothing picked — press Enter on the rows you want first")
            end
            return
        end
        if c.action ~= "edit" then return end
        local row = docFindRow(c.key)
        if not row then return end
        if docEditSelect then
            if docEditTagged[c.key] then docEditTagged[c.key] = nil
            else docEditTagged[c.key] = true end
            reopen(); return
        end
        local button, text = hs.dialog.textPrompt(
            "Edit document entry",
            "File name for this entry.\nClear the field and press OK to DELETE the row.\n\n"
                .. row.date .. "  " .. row.time .. "  ·  " .. docFormatSecs(row.secs),
            row.file, "OK", "Cancel")
        if button ~= "OK" then return end
        text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then
            for i, r in ipairs(docRows) do
                if r == row then table.remove(docRows, i); break end
            end
            docIndex[docKey(row.date, row.file)] = nil
            docDirty = true; docSave()
            hs.alert.show("🗑 Deleted " .. row.file)
        elseif text ~= row.file then
            docIndex[docKey(row.date, row.file)] = nil
            row.file = text
            docIndex[docKey(row.date, row.file)] = row
            docDirty = true; docSave()
            hs.alert.show("✏️ Renamed to " .. text)
        end
    end)
    _G.choosers.docWatcherEdit:placeholderText("Edit or delete a document entry")
    _G.choosers.docWatcherEdit:queryChangedCallback(function(query)
        pcall(docRenderEdit, query)
    end)

    -- ---- wiring ----------------------------------------------------------
    docLoad()

    core.hyperAddShortcut({"shift"}, "w", function()
        docSelectMode, docTagged = false, {}
        docRenderList("")
        _G.choosers.docWatcher:query("")
        core.showPopup(_G.choosers.docWatcher)
    end, "document watcher")

    core.hyperAddShortcut({"shift"}, "e", function()
        docEditSelect, docEditTagged = false, {}
        docRenderEdit("")
        _G.choosers.docWatcherEdit:query("")
        core.showPopup(_G.choosers.docWatcherEdit)
    end, "document watcher edit")

    -- Held in _G. so the garbage collector cannot quietly cancel them —
    -- the same trap that silently killed the App Monitor's timers in 6.16.
    _G.docWatcherTimer = hs.timer.doEvery(docPollSeconds, function() pcall(docSample) end)
    _G.docWatcherSaveTimer = hs.timer.doEvery(docSaveSeconds, function() pcall(docSave) end)

    end)()

    -- // EXPERIMENTAL SECTION END                //
    -- /////////////////////////////////////////////
    -- ////////////////////////////////////////////
end

return M
