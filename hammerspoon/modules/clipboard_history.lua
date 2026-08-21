-- =====================================================================
-- MODULE: CLIPBOARD HISTORY (⇪V) — every copy, searchable · ⇪⇧V to edit
-- =====================================================================
-- ⇪V searches the FULL text of every saved copy, not just the 100
-- characters a row shows. ⇪⇧V opens the same list to edit or delete an
-- entry — and an edited entry is put back on the clipboard, because you
-- edited it in order to paste it.
--
-- ---------------------------------------------------------------------
-- 6.55.0 — WHY THIS IS A MODULE NOW
-- ---------------------------------------------------------------------
-- This lived in init.lua, spread over four separate places: the file
-- path in §0.2, load/save in §2, the dedupe inside the pasteboard
-- watcher in §3, and two choosers in §5. Every one of those lines ran
-- BEFORE the module loader, in the stretch where a single error takes
-- the whole config down rather than costing you one feature. Moving it
-- buys three things: init.lua gets shorter, a fault in clipboard
-- history now costs you clipboard history, and the behaviour finally
-- has somewhere to be tested.
--
-- 🔗 THE ONE THING THAT STAYED BEHIND, and why. The pasteboard watcher
-- in init.lua is SHARED with image OCR — one timer reading one
-- changeCount, deciding between "copied image files", "a raw image" and
-- "text". Splitting that in two would mean two timers polling the same
-- counter and racing over which handled a change first. So the watcher
-- stays, and calls clipboard.add through the service registry. If this
-- module is switched off the watcher simply gets no provider, prints so
-- once, and OCR carries on.
--
-- ---------------------------------------------------------------------
-- 🚨 THE FAILURE THAT MATTERS HERE IS LOSING THE HISTORY
-- ---------------------------------------------------------------------
-- The file is rewritten on EVERY copy, so a bad write is not a one-off:
-- it is a thousand chances a day to destroy the lot. Two guards, both
-- carried over intact because both were earned by real incidents:
--   · AN UNREADABLE FILE IS BACKED UP BEFORE ANYTHING ELSE. It used to
--     fall back to {} silently, and the very next copy overwrote the
--     broken file with that empty list — losing whatever was still
--     recoverable inside it.
--   · AN ENCODE IS VERIFIED BEFORE IT IS COMMITTED. If encode ever
--     produces something that will not read back, the existing file is
--     left ALONE. Writing it was what corrupted the file in the first
--     place, and it was discovered only at the next reload, as
--     "history wiped".

local M = {
    name  = "Clipboard History",
    order = 14.3,
    -- 🗂 6.113.0 — MOVED FROM "text" TO "capture", ON REQUEST. The families
    -- are about what a tool is FOR, not what it operates on, and a store
    -- that catches everything you copy so you can go back for it later is
    -- the same shape as the Capture Pad and Quick Append: it takes
    -- something in and keeps it. "text" is where things that TRANSFORM
    -- text live — Text Expander, Autocorrect, Begone, OCR, URL Cleaner.
    -- ⚠️ NOTHING FOLLOWS IT AUTOMATICALLY. ⇪H (Command History) reads a
    -- shell's history file rather than catching anything, and was already
    -- filed under FIND & OPEN; the hand-written CLIPBOARD & OCR group in
    -- core/cheatsheet.lua is ⇪O/⇪⇧O/⇪⇧C, which is OCR and copy-on-select,
    -- so it stays in "text" too. Say the word if either should move.
    family = "capture",
    cheatsheet = {
        title = "📋 CLIPBOARD HISTORY (⇪V — every copy, searchable)",
        entries = {
            { "⇪V",   "Search clipboard history — matches the FULL text" },
            { "⇪⇧V",  "Edit or delete an entry · an edit is re-copied" },
            { "☑️ row","Pick several rows, then delete or copy them as ONE" },
            { "keeps","The last 1,000 copies, newest first" },
            { "skips","Anything over ~1 MB, so the file stays quick to write" },
            { "dedupe","Copying something again moves it up, not a second row" },
        },
    },
}

function M.setup(core)
    local clip = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    clip.enabled     = true
    clip.key         = "v"          -- ⇪V search · ⇪⇧V edit
    clip.max         = 1000         -- how many copies to keep
    clip.maxItemSize = 1000000      -- ~1 MB; bigger copies are not stored
    clip.rows        = 250          -- rows shown before you narrow the search
    clip.preview     = 100          -- characters shown per row
    clip.file        = (core.logsDir or hs.configdir)
                       .. "/clipboard_history-" .. tostring(core.hostTag) .. ".json"
    -- ----------------------------------------------------------------------

    -- The one-time migration of the pre-6.10 file from ~/.hammerspoon into
    -- the Logs folder came across with the rest of the feature: it belongs
    -- with the code that owns the file, not in the orchestrator.
    if core.adoptLegacyFile then
        pcall(core.adoptLegacyFile, clip.file,
              hs.configdir .. "/clipboard_history.json")
    end

    _G.clipboardCache = _G.clipboardCache or {}
    clip.loaded  = false
    clip.preload = {}     -- copies made before the file finished loading

    local function say(m)  if _G.diag then _G.diag.say("clipboard", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("clipboard", m) end end

    -- Anything that goes wrong here is exactly the kind of thing that used
    -- to be visible only in the Console. 6.54.0 gave us somewhere better.
    local function tellFailure(title, detail, key)
        if _G.notices then
            _G.notices.record("runtime", "clipboard_history", detail)
            _G.notices.tell(title, detail, { key = key, every = 600, seconds = 6 })
        else
            hs.alert.show("⚠️ " .. title .. "\n" .. detail, 6)
        end
        print("🚨 Clipboard history: " .. detail)
    end

    -- ---- disk -------------------------------------------------------------
    function clip.load()
        local f = io.open(clip.file, "r")
        if not f then _G.clipboardCache = {} return true end
        local content = f:read("*a"); f:close()
        local ok, data = pcall(hs.json.decode, content)
        if ok and type(data) == "table" then
            _G.clipboardCache = data
            return true
        end
        -- 🚨 BACK UP BEFORE STARTING FRESH. Falling back to {} silently
        -- meant the next copy overwrote the broken file with an empty
        -- list, destroying whatever was still recoverable in it.
        _G.clipboardCache = {}
        local backupPath = clip.file .. ".corrupt-" .. os.date("%Y%m%d-%H%M%S")
        local bf = io.open(backupPath, "w")
        if bf then bf:write(content); bf:close() end
        tellFailure("Clipboard history was unreadable",
                    "backed up to " .. backupPath .. " and started fresh",
                    "clip:corrupt")
        return false
    end

    function clip.save()
        local okEnc, body = pcall(hs.json.encode, _G.clipboardCache)
        if not okEnc or type(body) ~= "string" then
            tellFailure("Clipboard history NOT saved",
                        "encode failed; the existing file was left untouched",
                        "clip:encode")
            return false
        end
        -- 🚨 VERIFY BEFORE COMMITTING. Writing an encode that will not read
        -- back is what corrupted the file originally, and it was noticed
        -- only at the next reload, as "history wiped".
        local okDec, decoded = pcall(hs.json.decode, body)
        if not okDec or type(decoded) ~= "table" then
            tellFailure("Clipboard history NOT saved",
                        "the encoded JSON would not read back; file untouched",
                        "clip:roundtrip")
            return false
        end
        local f = io.open(clip.file, "w")
        if not f then
            if core.warnWriteFailed then core.warnWriteFailed("clipboard history") end
            return false
        end
        f:write(body); f:close()
        return true
    end

    -- ---- adding -----------------------------------------------------------
    -- Called by init.lua's shared pasteboard watcher via the service
    -- registry. Returns true when something was actually stored.
    function clip.add(text)
        if type(text) ~= "string" or text == "" then return false end
        if #text > clip.maxItemSize then
            print("📋 Clipboard item not saved to history (over 1 MB)")
            return false
        end
        local cache = _G.clipboardCache
        -- Already at the top: nothing to do. This is also what stops the
        -- clipboard-edit path filing a duplicate — the edited entry
        -- carries the arriving text, so the dedupe below lifts it rather
        -- than copying it.
        if cache[1] and cache[1].text == text then return false end
        for i = #cache, 1, -1 do
            if cache[i].text == text then table.remove(cache, i) end
        end
        table.insert(cache, 1, { date = os.date("%b %d %H:%M"), text = text })
        while #cache > clip.max do table.remove(cache) end
        -- 🚨 DO NOT SAVE BEFORE THE FILE HAS BEEN READ. Deferring the
        -- load to warm() opened a two-second window at boot in which a
        -- copy would write a ONE-ITEM file straight over the real
        -- history — and warm() would then dutifully load that back,
        -- having destroyed everything. The copy is held instead and
        -- re-applied on top once the file is in, which is what
        -- clip.preload is for. Found by test_clipboard's P4.
        if not clip.loaded then
            clip.preload[#clip.preload + 1] = text
            return true
        end
        clip.save()
        return true
    end

    -- ---- the pickers -------------------------------------------------------
    clip.chooser, clip.editChooser = nil, nil   -- HELD: else collected
    local editSnapshot = {}

    -- ☑️ 6.97.0 — SELECT MODE, the same pattern the Document Watcher list
    -- proved in 6.40.0: hs.chooser has no shift-click multi-select, so
    -- Enter TAGS rows (✓) and an action row applies to all of them at
    -- once. Tags key on the ENTRY TABLE, not the index — a copy made
    -- while the picker is open shifts every index, but identity holds.
    clip.selectMode = false
    clip.tagged     = {}        -- entry table -> true

    function clip.taggedCount()
        local n = 0
        for _ in pairs(clip.tagged) do n = n + 1 end
        return n
    end

    -- Both bulk actions end select mode: the job the mode existed for is
    -- done, and coming back to a stale pick-list is how mistakes happen.
    function clip.deleteTagged()
        local kept, removed = {}, 0
        for _, item in ipairs(_G.clipboardCache) do
            if clip.tagged[item] then removed = removed + 1
            else kept[#kept + 1] = item end
        end
        if removed > 0 then
            _G.clipboardCache = kept
            clip.save()
        end
        clip.selectMode, clip.tagged = false, {}
        return removed
    end

    function clip.copyTagged()
        local parts = {}
        for _, item in ipairs(_G.clipboardCache) do
            if clip.tagged[item] then parts[#parts + 1] = item.text or "" end
        end
        if #parts > 0 then
            -- One pasteboard write; the shared watcher files the joined
            -- text as a NEW top entry, which is what a copy means here.
            pcall(function() hs.pasteboard.setContents(table.concat(parts, "\n")) end)
        end
        clip.selectMode, clip.tagged = false, {}
        return #parts
    end

    local function oneLine(s) return (s:gsub("%s+", " ")) end

    function clip.render(query)
        local q = (query or ""):lower():match("^%s*(.-)%s*$")
        local choices = {}
        for _, item in ipairs(_G.clipboardCache) do
            if q == "" or (item.text or ""):lower():find(q, 1, true) then
                choices[#choices + 1] = {
                    text    = oneLine(item.text or ""):sub(1, clip.preview),
                    subText = item.date or "",
                    rawText = item.text,
                }
                if #choices >= clip.rows then break end
            end
        end
        if #choices == 0 then
            choices[1] = {
                text = (q == "") and "Clipboard history is empty"
                       or ("No matches for \"" .. q .. "\""),
                subText = "Searches the full text of every saved item",
            }
        end
        clip.chooser:choices(choices)
    end

    -- 🚨 THE SNAPSHOT+INDEX PATTERN IS LOAD-BEARING, and the reason is not
    -- obvious. This originally put the entry TABLE on the choice and
    -- compared it with == in the callback — but hs.chooser round-trips
    -- every choice through its Objective-C bridge, and what comes back is
    -- a FRESHLY REBUILT Lua table, never the object you handed it. Table
    -- identity cannot survive that trip, so the match always failed and
    -- every edit answered "that entry is gone". A NUMBER survives, so the
    -- index is passed and the real object looked up on our side.
    function clip.renderEdit(query)
        local q = (query or ""):lower():match("^%s*(.-)%s*$")
        editSnapshot = {}
        local choices = {}
        if #_G.clipboardCache == 0 then
            -- An empty history gets no action rows — nothing to pick.
        elseif clip.selectMode then
            local n = clip.taggedCount()
            choices[#choices + 1] = {
                text    = (n == 0) and "☑️ Nothing picked yet"
                          or ("🗑 Delete the " .. n .. " I picked"),
                subText = (n == 0)
                          and "Go down the list and press Enter on the rows you want"
                          or "Press Enter HERE to delete them all",
                action  = "deletetagged",
            }
            choices[#choices + 1] = {
                text    = "📋 Copy the picked rows as ONE text",
                subText = (n == 0) and "Pick rows first"
                          or (n .. " row" .. ((n == 1) and "" or "s")
                              .. " joined with line breaks, then copied"),
                action  = "copytagged",
            }
            choices[#choices + 1] = {
                text    = "✖️ Never mind — go back",
                subText = "Forget the picks and return to one-at-a-time editing",
                action  = "selectoff",
            }
        else
            choices[#choices + 1] = {
                text    = "☑️ Select several…",
                subText = "Pick rows with Enter, then delete them or copy them as one",
                action  = "selecton",
            }
        end
        local shown = 0
        for i, item in ipairs(_G.clipboardCache) do
            if q == "" or (item.text or ""):lower():find(q, 1, true) then
                editSnapshot[i] = item
                local hint
                if not clip.selectMode then hint = "Enter to edit or delete"
                elseif clip.tagged[item] then hint = "PICKED — Enter unpicks it"
                else hint = "Enter picks it" end
                choices[#choices + 1] = {
                    text    = (clip.tagged[item] and "✓ " or "")
                              .. oneLine(item.text or ""):sub(1, clip.preview),
                    subText = (item.date or "") .. "  ·  " .. hint,
                    idx     = i,
                }
                shown = shown + 1
                if shown >= clip.rows then break end
            end
        end
        if shown == 0 then
            choices[#choices + 1] = {
                text = (q == "") and "Clipboard history is empty"
                       or ("No matches for \"" .. q .. "\""),
                subText = "",
            }
        end
        clip.editChooser:choices(choices)
    end

    function clip.applyEdit(idxFromChoice, text)
        local entry = editSnapshot[idxFromChoice]
        if not entry then return "gone" end
        -- Re-find the entry's CURRENT position: a copy made while the
        -- picker was open shifts every index.
        local idx = nil
        for i, v in ipairs(_G.clipboardCache) do
            if v == entry then idx = i break end
        end
        if not idx then return "gone" end

        if not text or text:match("^%s*$") then
            table.remove(_G.clipboardCache, idx)
            clip.save()
            return "deleted"
        end
        _G.clipboardCache[idx].text = text
        clip.save()
        -- 🚨 THE EDITED TEXT GOES ON THE CLIPBOARD, and the ORDER matters.
        -- Setting the pasteboard wakes the watcher, which would normally
        -- file a second entry. It does not, because clip.add's dedupe
        -- removes any entry matching the arriving text and this one now
        -- carries exactly that text — so it is lifted to the front rather
        -- than copied. The cache must hold the new text BEFORE the
        -- pasteboard does, or the duplicate reappears.
        pcall(function() hs.pasteboard.setContents(text) end)
        return "updated"
    end

    -- ---- wiring ------------------------------------------------------------
    if clip.enabled then
        clip.chooser = hs.chooser.new(function(c)
            if c and c.rawText then
                pcall(function() hs.pasteboard.setContents(c.rawText) end)
                hs.alert.show("📋 Copied")
            end
        end)
        -- ⎋ 6.93.0: filed in _G.choosers so Esc closes ⇪V before the cheat sheet
        _G.choosers = _G.choosers or {}
        _G.choosers.clipboardHistory = clip.chooser
        pcall(function()
            clip.chooser:placeholderText("Search Clipboard History...")
        end)
        clip.chooser:queryChangedCallback(function(query)
            local ok, err = pcall(clip.render, query)
            if not ok then
                warn("render failed: " .. tostring(err))
                clip.chooser:choices({ { text = "⚠️ Display error — see Console",
                                         subText = tostring(err) } })
            end
        end)

        local function reopenEdit()
            clip.renderEdit("")
            pcall(function() clip.editChooser:query("") end)
            if core.showPopup then core.showPopup(clip.editChooser)
            else clip.editChooser:show() end
        end

        clip.editChooser = hs.chooser.new(function(choice)
            if not choice then return end
            if choice.action == "selecton" then
                clip.selectMode, clip.tagged = true, {}
                reopenEdit(); return
            elseif choice.action == "selectoff" then
                clip.selectMode, clip.tagged = false, {}
                reopenEdit(); return
            elseif choice.action == "deletetagged" then
                local n = clip.deleteTagged()
                hs.alert.show((n > 0)
                    and ("🗑 Deleted " .. n .. " clipboard entr"
                         .. ((n == 1) and "y" or "ies"))
                    or "Nothing picked — press Enter on the rows you want first")
                return
            elseif choice.action == "copytagged" then
                local n = clip.copyTagged()
                hs.alert.show((n > 0)
                    and ("📋 Copied " .. n .. " entr" .. ((n == 1) and "y" or "ies")
                         .. " as one")
                    or "Nothing picked — press Enter on the rows you want first")
                return
            end
            if not choice.idx then return end
            if clip.selectMode then
                local entry = editSnapshot[choice.idx]
                if entry then
                    if clip.tagged[entry] then clip.tagged[entry] = nil
                    else clip.tagged[entry] = true end
                end
                reopenEdit(); return
            end
            local b, text = hs.dialog.textPrompt(
                "✏️ Edit clipboard entry",
                "Edit the text below.\nSave with it EMPTY to delete this entry.",
                (editSnapshot[choice.idx] or {}).text or "", "Save", "Cancel")
            if b ~= "Save" then return end
            local result = clip.applyEdit(choice.idx, text)
            if result == "gone" then
                hs.alert.show("⚠️ That entry is gone — history changed since "
                              .. "this picker opened")
            elseif result == "deleted" then
                hs.alert.show("🗑 Clipboard entry deleted")
            else
                hs.alert.show("✏️ Clipboard entry updated — and copied")
            end
        end)
        _G.choosers = _G.choosers or {}
        _G.choosers.clipboardEdit = clip.editChooser   -- ⎋ 6.93.0: same rule for ⇪⇧V
        pcall(function()
            clip.editChooser:placeholderText(
                "Search clipboard history to edit or delete — Enter opens a row")
        end)
        clip.editChooser:queryChangedCallback(function(query)
            local ok, err = pcall(clip.renderEdit, query)
            if not ok then
                warn("edit render failed: " .. tostring(err))
                clip.editChooser:choices({ { text = "⚠️ Display error — see Console",
                                             subText = tostring(err) } })
            end
        end)

        -- ⇪V / ⇪⇧V. The old ⌃⌥⌘V and ⌃⌥⌘⇧V chords are what §0.4's
        -- migration map POINTS AT these; binding the hyper keys directly
        -- is the same destination without the indirection.
        core.hyperAddShortcut({}, clip.key, function()
            clip.render("")
            if core.showPopup then core.showPopup(clip.chooser)
            else clip.chooser:show() end
        end, "clipboard history")

        core.hyperAddShortcut({ "shift" }, clip.key, function()
            -- A fresh ⇪⇧V always starts in one-at-a-time mode: reopening
            -- into week-old ✓ marks is how the wrong rows get deleted.
            clip.selectMode, clip.tagged = false, {}
            clip.renderEdit("")
            if core.showPopup then core.showPopup(clip.editChooser)
            else clip.editChooser:show() end
        end, "clipboard edit")
    end

    -- 🗂 6.116.0 — listed for the ⌘⌘ editor picker. There is no `view`: a
    -- chooser is not a window this config can bring forward, so ⏎ always
    -- opens a fresh one, which for a picker is the same thing.
    --
    -- 🚨 INSIDE the enabled check. clip.chooser is only built when this
    -- module is enabled, so registering unconditionally would put a row in
    -- the picker whose ⏎ calls a method on nil — a dead row is worse than
    -- an absent one, because you only find out by pressing it.
    if clip.enabled then
        _G.editors = _G.editors or {}
        table.insert(_G.editors, {
            name  = "Clipboard",
            -- 6.132.0 — LL: "Shouldn't this be in the edit picker? ⇪⇧V."
            -- It was: ⇪⇧V is this row's EDIT view. The row simply never
            -- said so, so the picker read as if ⇪V were the only way in.
            -- Same shape as the Screenshots row's "⇪4 / ⇪⇧4", where the
            -- second key is likewise a different view, not a second door
            -- into the same one.
            key   = "⇪V / ⇪⇧V",
            what  = "everything you have copied",
            order = 40,
            unit  = "items",
            show  = function()
                clip.render("")
                if core.showPopup then core.showPopup(clip.chooser)
                else clip.chooser:show() end
            end,
            size  = function() return #(_G.clipboardCache or {}) end,
            text  = function()
                local top = (_G.clipboardCache or {})[1]
                return top and top.text or nil
            end,
            -- 💾 6.130.0 — the whole history for the one-file CSV export.
            -- `text` above is the ⌥⏎ answer and is deliberately just the
            -- newest item; this is every item, and the cache is stored
            -- newest-first already, which is the order the export wants.
            csv   = function()
                local out = {}
                for _, it in ipairs(_G.clipboardCache or {}) do
                    if type(it) == "table" and type(it.text) == "string" then
                        out[#out + 1] = { when = it.date, text = it.text }
                    end
                end
                return out
            end,
        })
    end

    core.provide("clipboard.add",   function(t) return clip.add(t)   end)
    core.provide("clipboard.save",  function()  return clip.save()   end)
    core.provide("clipboard.count", function()  return #_G.clipboardCache end)

    -- ⏱ THE FILE IS READ IN warm(), NOT setup(). It can be a megabyte and
    -- it is on the boot path otherwise. Copies made in the ~2 seconds
    -- before it lands are kept in clip.preload and re-applied on top
    -- afterwards, so nothing copied during boot is lost to the load.
    M.warm = function()
        clip.load()
        for i = #clip.preload, 1, -1 do
            local t = clip.preload[i]
            local cache = _G.clipboardCache
            for j = #cache, 1, -1 do
                if cache[j].text == t then table.remove(cache, j) end
            end
            table.insert(cache, 1, { date = os.date("%b %d %H:%M"), text = t })
        end
        while #_G.clipboardCache > clip.max do table.remove(_G.clipboardCache) end
        if #clip.preload > 0 then clip.save() end
        clip.preload, clip.loaded = {}, true
        say(#_G.clipboardCache .. " items loaded")
    end

    _G.clipboardHistory = clip
    M.clip   = clip
    M.config = clip
end

return M
