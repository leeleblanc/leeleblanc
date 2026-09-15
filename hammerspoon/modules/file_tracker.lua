-- =====================================================================
-- MODULE: FILE TRACKER (was §3.8) — rename / move / copy history, searchable (⌃⌥⇧F)
-- =====================================================================
-- Watches the folders below via macOS FSEvents (hs.pathwatcher) and
-- logs, with a 90-day history:
--   • Renamed        old name → new name, same folder
--   • Moved          same name, old folder → new folder
--   • Renamed+Moved  both changed at once
--   • Moved out/in   file left for / arrived from somewhere outside
--                    the watched folders (only one side is visible)
--   • Copied         a copy appeared (macOS never reports a copy's
--                    SOURCE — only the new file — so origin is blank)
--   • Created        a brand-new file appeared
--
-- ⌃⌥⇧F opens a searchable picker (type to filter across every column;
-- Enter copies the row). 6.10.0: the CSV lives DIRECTLY in your
-- OneDrive Logs folder, machine-tagged —
-- <OneDrive>/Logs/file_changes-<Mac>.csv (Excel-ready, quote-safe).
-- It's already cloud-synced, so the old separate daily-copy timer is
-- gone; your existing ~/.hammerspoon/file_changes.csv was adopted on
-- first boot.
--
-- CSV columns: timestamp (YYYY-MM-DD HH:MM), file_name, new_name,
-- present_location, moved_location, event, epoch (epoch = plain seconds
-- number used only for the 90-day pruning; harmless in Excel).
--
-- 📅 6.115.0 — THE DATE MOVED TO THE FRONT AND CHANGED FORMAT, and both
-- halves of that were a real bug rather than a preference. LL: "On the
-- {X} file, the date should be first? Can we do that & fix the current
-- file?"
--
--   · IT WAS THE FIFTH COLUMN. You had to scroll past four columns of
--     names and paths to find out WHEN anything happened, in a log whose
--     entire purpose is when-did-this-file-move.
--   · IT WAS WRITTEN DD/MM/YY, WHICH EXCEL READS AS MM/DD/YY on a US
--     locale. "11/07/26" is the 11th of July here and November 7th
--     there, and nothing in the file says which. Worse, Excel imports
--     the column as TEXT, so sorting it sorts alphabetically: every
--     row that starts "11/" clumps together regardless of month or
--     year. That is very probably what LL was looking at when he
--     reported the log "only shows July 11th" — not missing data, a
--     sort artefact of an ambiguous format.
--
-- ISO 8601 fixes both at once: unambiguous to a human, unambiguous to
-- Excel, and correct when sorted as plain text.
--
-- 🔧 YOUR EXISTING FILE IS MIGRATED IN PLACE, once, at the first boot on
-- this version — see the migration block below. Nothing is re-parsed
-- from the old date text: every row already carries an `epoch` column,
-- so the new timestamp is REGENERATED from that. There is no
-- day/month ambiguity to get wrong because the ambiguous field is
-- discarded rather than interpreted.
--
-- HOW RENAME/MOVE DETECTION WORKS (and its honest limits): FSEvents
-- announces a rename/move as TWO events — old path and new path —
-- usually in the same instant. We pair them by arrival within a short
-- window and by checking which path still exists. Two files renamed in
-- the exact same instant could theoretically mis-pair; in practice
-- Finder operations arrive cleanly. Temp/hidden files (.*, ~$Office
-- locks, .tmp/.part/.crdownload) are ignored to keep the log humane.
--
-- ✏️ EDIT THESE — what to watch and the hotkey:
-- Watching your ENTIRE home folder + your OneDrive. To keep that sane:
--   • ~/Library is excluded (hundreds of cache/pref events per minute)
--     — EXCEPT OneDrive, which lives inside it and gets its own watcher
--   • hidden folders/files anywhere (.git, .Trash, .hammerspoon…) excluded
--   • our own telemetry (the OneDrive Logs folder + Backups/Hammerspoon)
--     excluded so the tracker never logs itself, the histories, or the
--     nightly backup churn — this matters MORE in 6.10.0, since every
--     data file now lives inside the watched OneDrive
--   • a burst guard suppresses floods (unzipping, mass exports): >30
--     created-file rows in 10s pauses Created logging until quiet —
--     renames/moves are never suppressed
-- NOTE: OneDrive syncs BOTH Macs' changes down, so files you rename on
-- the work Mac inside OneDrive will also appear in this Mac's log —
-- cross-machine visibility, which cuts both ways.

-- Moved out of init.lua in 6.38.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "File Tracker",
    order = 10,
    family = "files",
    cheatsheet = {
        title = "📁 FILE TRACKER",
        entries = {
            { "⇪F", "Rename / move / copy history (searchable)" },
            { "Enter", "Copy row  ·  90-day history" }
        },
    },
}

function M.setup(core)
    local fileTrackerFolders = { core.homeDir }
    if core.cloudDir then table.insert(fileTrackerFolders, core.cloudDir) end
    local fileTrackerMods          = {"ctrl", "alt", "shift"}
    local fileTrackerKey           = "F"
    local fileTrackerRetentionDays = 90
    local fileTrackerFile          = core.logsDir .. "/file_changes-" .. core.hostTag .. ".csv"
    core.adoptLegacyFile(fileTrackerFile, hs.configdir .. "/file_changes.csv")

    -- 6.16.23: ✏️ EDIT THIS — macOS-internal noise the tracker should never
    -- log. These are files the OPERATING SYSTEM churns constantly on its
    -- own; none of them are documents you'd ever want a paper trail of.
    -- Real reported examples: temp-CPAnalyticsPropertiesCache.plist and
    -- store.updates rewriting themselves inside Photos Library every hour.
    --
    -- (1) DOCUMENT/MEDIA LIBRARY BUNDLES — these LOOK like a single file in
    -- Finder but are really folders full of databases the OS rewrites
    -- nonstop. Excluding the bundle excludes everything inside it. Moving
    -- or renaming the bundle ITSELF is still logged — only its internals
    -- are suppressed.
    local fileTrackerNoiseBundles = {
        "%.photoslibrary/", "%.photolibrary/", "%.musiclibrary/",
        "%.tvlibrary/", "%.aplibrary/", "%.imovielibrary/",
        "%.theater/", "%.logicx/", "%.band/", "%.fcpbundle/",
        "%.noindex/", "%.spotlightV3/", "%.lrdata/", "%.migratedphotolibrary/",
    }
    -- (2) OS-INTERNAL FILE TYPES — preference/cache/index files.
    local fileTrackerNoiseExts = {
        "%.plist$", "%.db$", "%.db%-wal$", "%.db%-shm$",
        "%.sqlite$", "%.sqlite%-wal$", "%.sqlite%-shm$",
        "%.updates$", "%.indexUpdates$", "%.spotlightV3$",
        "%.lock$", "%.pid$", "%.log$", "%.swp$", "%.swo$",
    }

    local function fileTrackerIgnored(path)
        local base = path:match("[^/]+$") or path
        if base:match("^%.")  then return true end   -- hidden / .DS_Store
        if base:match("^~%$") then return true end   -- Office lock files
        if base:match("%.tmp$") or base:match("%.part$")
           or base:match("%.crdownload$") or base:match("%.download$") then
            return true
        end
        -- 6.16.23: OS churn — anything inside a media/document library
        -- bundle, and OS-internal file types anywhere.
        for _, pat in ipairs(fileTrackerNoiseBundles) do
            if path:lower():find(pat) then return true end
        end
        for _, pat in ipairs(fileTrackerNoiseExts) do
            if base:lower():find(pat) then return true end
        end
        -- Sandbox/atomic-save scratch names (e.g. "foo.plist.sb-9e7584f9-3sh4il")
        if base:find("%.sb%-%w+$") then return true end
        return false
    end

    local function ftStartsWith(s, prefix)
        return s:sub(1, #prefix) == prefix
    end

    -- Path-level exclusions (see the notes above the folder list)
    local function fileTrackerExcludedPath(path)
        if ftStartsWith(path, core.logsDir .. "/") then return true end -- the whole Logs
                                                                   -- folder: every
                                                                   -- history file now
                                                                   -- lives there (also
                                                                   -- covers the local
                                                                   -- logs/ fallback)
        -- ~/.hammerspoon IS tracked despite being a hidden folder — config
        -- edits, init.lua swaps & secret.lua changes are worth a paper
        -- trail. Still excluded within it: any hidden items nested inside.
        -- (The tracker's own CSV no longer lives here — it's in Logs.)
        if ftStartsWith(path, hs.configdir .. "/") then
            local inside = path:sub(#hs.configdir + 2)
            if inside:match("^%.") or inside:match("/%.") then return true end
            return false
        end
        if path:match("/%.") then return true end                 -- hidden dir/file anywhere in path
        if core.cloudDir and ftStartsWith(path, core.cloudDir .. "/Backups/Hammerspoon/") then
            return true                                            -- nightly backup churn
        end
        if ftStartsWith(path, core.homeDir .. "/Library/") then
            -- Library is noise — except OneDrive, which lives inside it
            if not (core.cloudDir and ftStartsWith(path, core.cloudDir .. "/")) then
                return true
            end
        end
        return false
    end

    -- Burst guard: unzip/export floods suppress Created/Copied logging
    -- (never renames/moves) until the storm passes
    local ftBurst = { windowStart = 0, count = 0, warned = false }
    local function fileTrackerBurstOK()
        local now = os.time()
        if now - ftBurst.windowStart > 10 then
            ftBurst.windowStart, ftBurst.count, ftBurst.warned = now, 0, false
        end
        ftBurst.count = ftBurst.count + 1
        if ftBurst.count > 30 then
            if not ftBurst.warned then
                print("⚠️ File tracker: created-file burst — suppressing Created rows until quiet")
                ftBurst.warned = true
            end
            return false
        end
        return true
    end

    local function fileTrackerDirOf(path)  return path:match("^(.*)/[^/]+$") or "" end
    local function fileTrackerBaseOf(path) return path:match("[^/]+$") or path end
    local function fileTrackerPretty(dir)
        if dir == "" then return "" end
        return (dir:gsub("^" .. core.homeDir:gsub("%-", "%%-"), "~"))
    end

    -- ---- storage (same quote-safe CSV helpers as the activity tracker) --

    -- 📅 6.115.0 — ONE PLACE THAT SAYS WHAT A ROW LOOKS LIKE. The header
    -- and both writers used to spell the column order out separately,
    -- three times, which is how a schema change becomes a corrupted file:
    -- change two of the three and every row after the change is silently
    -- shifted by one field.
    local FT_HEADER = "timestamp,file_name,new_name,present_location," ..
                      "moved_location,event,epoch"

    local function fileTrackerRow(e)
        return core.csvQuote(e.timestamp) .. "," .. core.csvQuote(e.fileName) .. ","
            .. core.csvQuote(e.newName) .. "," .. core.csvQuote(e.presentLoc) .. ","
            .. core.csvQuote(e.movedLoc) .. "," .. core.csvQuote(e.event) .. ","
            .. tostring(e.epoch) .. "\n"
    end

    local function fileTrackerRewrite(log)
        local f = io.open(fileTrackerFile, "w")
        if not f then return false end
        f:write(FT_HEADER .. "\n")
        for _, e in ipairs(log) do f:write(fileTrackerRow(e)) end
        f:close()
        return true
    end

    -- Set by the loader when it meets a row (or a header) in the pre-6.115.0
    -- layout, so boot knows the file on disk needs rewriting rather than
    -- guessing from a version number that says nothing about this Mac's data.
    local ftNeedsMigration = false

    -- 🚨 READS BOTH LAYOUTS, AND DECIDES PER ROW RATHER THAN PER FILE.
    -- Per-file would have been simpler and wrong: this CSV is appended to
    -- by a long-running process, so a file can genuinely contain old rows
    -- written before an upgrade and new rows written after it. A header
    -- read once at the top cannot describe both halves.
    --
    -- The discriminator is the FIRST FIELD, and it cannot collide: in the
    -- new layout it is an ISO date, in the old one it is a file name, and
    -- a file name that begins "2026-08-19" still has no second field
    -- shaped like a bare integer epoch — the row is rejected either way
    -- rather than mis-read.
    local function fileTrackerLoad()
        local f = io.open(fileTrackerFile, "r")
        if not f then return {} end
        local content = f:read("*a"); f:close()
        local log, isFirst = {}, true
        for line in content:gmatch("([^\r\n]+)") do
            local skip = false
            if isFirst then
                if line:match("^file_name,") then
                    ftNeedsMigration = true        -- 6.114.0 and earlier
                    skip = true
                elseif line:match("^timestamp,") then
                    skip = true
                end
            end
            if not skip then
                local c = core.splitCSVLine(line)
                local epoch = tonumber(c[7])
                local first = c[1] or ""
                if epoch and first ~= "" then
                    if first:match("^%d%d%d%d%-%d%d%-%d%d") then
                        table.insert(log, {
                            timestamp = first,      fileName   = c[2] or "",
                            newName   = c[3] or "", presentLoc = c[4] or "",
                            movedLoc  = c[5] or "", event      = c[6] or "",
                            epoch     = epoch,
                        })
                    else
                        -- OLD LAYOUT. The old fifth column held the
                        -- DD/MM/YY text and is deliberately DROPPED, not
                        -- parsed: the same string means two different days
                        -- depending on who reads it, and this row already
                        -- carries the moment it happened as an epoch. The
                        -- unambiguous field wins.
                        ftNeedsMigration = true
                        table.insert(log, {
                            timestamp  = os.date("%Y-%m-%d %H:%M", epoch),
                            fileName   = first,     newName  = c[2] or "",
                            presentLoc = c[3] or "", movedLoc = c[4] or "",
                            event      = c[6] or "", epoch    = epoch,
                        })
                    end
                end
            end
            isFirst = false
        end
        return log
    end

    -- One-time safety copy of the pre-migration file. The migration is
    -- lossless by construction — every field is carried across and the
    -- timestamp is rebuilt from a number, not re-parsed from text — but
    -- this is 90 days of LL's file history being rewritten in place on a
    -- Mac nobody is watching, and "lossless by construction" is a claim
    -- about the code rather than about the disk it just ran on.
    local function fileTrackerBackupOnce()
        local backup = fileTrackerFile .. ".before-iso-dates"
        local exists = io.open(backup, "r")
        if exists then exists:close(); return end   -- already kept one
        local src = io.open(fileTrackerFile, "r")
        if not src then return end
        local body = src:read("*a"); src:close()
        local dst = io.open(backup, "w")
        if not dst then
            print("⚠️ File tracker: could not write " .. backup
                  .. " — migrating anyway, the data is rebuilt from the epoch column")
            return
        end
        dst:write(body); dst:close()
        print("📦 File tracker: kept the pre-6.115.0 CSV at " .. backup)
    end

    -- How many recorded rows between in-session prunes. A prune is O(n), so
    -- checking every insert would make recording O(n) per file event; every
    -- 200 makes the amortised share negligible while still keeping the list
    -- from growing all week. Declared here so both the recorder and the
    -- prune itself can see them.
    local fileTrackerPruneEvery = 200
    local _ftSincePrune = 0

    local function fileTrackerPrune(log)
        local cutoff = os.time() - fileTrackerRetentionDays * 86400
        local kept = {}
        for _, e in ipairs(log) do
            if e.epoch >= cutoff then table.insert(kept, e) end
        end
        return kept
    end

    local _ftLoaded = fileTrackerLoad()
    _G.fileTrackerLog = fileTrackerPrune(_ftLoaded)
    -- 📅 THE MIGRATION, and note the ORDER: back up, then rewrite. A
    -- backup taken after the rewrite would be a backup of the new file,
    -- which is not a backup of anything.
    if ftNeedsMigration then fileTrackerBackupOnce() end
    if ftNeedsMigration or #_G.fileTrackerLog ~= #_ftLoaded or #_ftLoaded == 0 then
        if not fileTrackerRewrite(_G.fileTrackerLog) then
            core.warnWriteFailed("file tracker CSV")
        elseif ftNeedsMigration then
            print(("📅 File tracker: migrated %d rows to date-first ISO "
                   .. "timestamps (%s)"):format(#_G.fileTrackerLog, fileTrackerFile))
        end
    end

    local function fileTrackerAppendRow(e)
        local f = io.open(fileTrackerFile, "a")
        if f then
            f:write(fileTrackerRow(e))
            f:close()
        else
            core.warnWriteFailed("file tracker CSV")
        end
    end

    local function fileTrackerRecord(event, fileName, newName, presentLoc, movedLoc)
        local entry = {
            event      = event,
            fileName   = fileName,
            newName    = newName or "",
            presentLoc = fileTrackerPretty(presentLoc or ""),
            movedLoc   = fileTrackerPretty(movedLoc or ""),
            -- 📅 ISO, not DD/MM/YY — see the header. Sorts correctly as
            -- text and means the same day to every reader.
            timestamp  = os.date("%Y-%m-%d %H:%M"),
            epoch      = os.time(),
        }
        table.insert(_G.fileTrackerLog, entry)
        fileTrackerAppendRow(entry)

        -- ⚡ 6.44.4 — PRUNE DURING THE SESSION, NOT ONLY AT BOOT. The
        -- retention cutoff used to be applied exactly once, when this module
        -- loaded, so on a Mac that stays logged in for weeks the in-memory
        -- log grew without limit until the next reload — and every ⇪F
        -- keystroke scans that whole list. Checked every
        -- fileTrackerPruneEvery inserts rather than on each one, so the cost
        -- is amortised to nothing: a prune is O(n), and doing it once per
        -- 200 rows makes the per-row share negligible.
        _ftSincePrune = _ftSincePrune + 1
        if _ftSincePrune >= fileTrackerPruneEvery then
            _ftSincePrune = 0
            local before = #_G.fileTrackerLog
            _G.fileTrackerLog = fileTrackerPrune(_G.fileTrackerLog)
            if #_G.fileTrackerLog ~= before then
                _G.diag.say("fileTracker", string.format(
                    "pruned in-session: %d → %d rows", before, #_G.fileTrackerLog))
            end
        end
    end

    -- ---- event classification --------------------------------------------

    -- A completed old→new pair becomes one log row
    local function fileTrackerPair(oldPath, newPath)
        local oldBase, newBase = fileTrackerBaseOf(oldPath), fileTrackerBaseOf(newPath)
        local oldDir,  newDir  = fileTrackerDirOf(oldPath),  fileTrackerDirOf(newPath)
        if oldDir == newDir and oldBase ~= newBase then
            fileTrackerRecord("Renamed", oldBase, newBase, oldDir, "")
        elseif oldDir ~= newDir and oldBase == newBase then
            fileTrackerRecord("Moved", oldBase, "", oldDir, newDir)
        elseif oldDir ~= newDir and oldBase ~= newBase then
            fileTrackerRecord("Renamed+Moved", oldBase, newBase, oldDir, newDir)
        end -- identical old==new: FSEvents echo, ignore
    end

    -- One shared pending slot pairs the two halves of a rename/move even
    -- when they arrive via different folder watchers (e.g. Desktop →
    -- Documents). If no partner shows up quickly, it was one-sided: the
    -- file crossed the boundary of the watched folders.
    local ftPending, ftPendingId = nil, 0
    -- 6.16.18: held in _G. (not left as a bare, unstored doAfter return
    -- value) so Lua's GC can't collect this one-shot timer before its 1.5s
    -- elapses — the same real Hammerspoon gotcha that broke App Monitor.
    _G.fileTrackerPendingTimers = {}

    local function fileTrackerFlushPending(id)
        if not ftPending or ftPending.id ~= id then return end
        local p = ftPending
        ftPending = nil
        local base, dir = fileTrackerBaseOf(p.path), fileTrackerDirOf(p.path)
        if p.exists then
            fileTrackerRecord("Moved in", base, "", "(outside watched folders)", dir)
        else
            fileTrackerRecord("Moved out", base, "", dir, "(outside watched folders)")
        end
    end

    local function fileTrackerCallback(paths, flagTables)
        for i, path in ipairs(paths or {}) do
            local flags = (flagTables or {})[i] or {}
            if flags.itemIsFile and not fileTrackerIgnored(path)
               and not fileTrackerExcludedPath(path) then
                if flags.itemRenamed then
                    local exists = (hs.fs.attributes(path) ~= nil)
                    if ftPending and path ~= ftPending.path
                       and (hs.timer.secondsSinceEpoch() - ftPending.t) < 1.5 then
                        -- second half arrived: order by which side still exists
                        local oldP, newP = ftPending.path, path
                        if not exists and hs.fs.attributes(oldP) then
                            oldP, newP = path, ftPending.path
                        end
                        ftPending = nil
                        fileTrackerPair(oldP, newP)
                    else
                        ftPendingId = ftPendingId + 1
                        ftPending = { path = path, exists = exists,
                                      t = hs.timer.secondsSinceEpoch(), id = ftPendingId }
                        local myId = ftPendingId
                        local pt
                        pt = hs.timer.doAfter(1.5, function()
                            fileTrackerFlushPending(myId)
                            for i, t in ipairs(_G.fileTrackerPendingTimers) do
                                if t == pt then table.remove(_G.fileTrackerPendingTimers, i); break end
                            end
                        end)
                        table.insert(_G.fileTrackerPendingTimers, pt)
                    end
                elseif flags.itemCreated and not flags.itemRemoved then
                    if fileTrackerBurstOK() then
                        local base, dir = fileTrackerBaseOf(path), fileTrackerDirOf(path)
                        if flags.itemCloned then
                            fileTrackerRecord("Copied", base, "", dir, "")
                        else
                            fileTrackerRecord("Created", base, "", dir, "")
                        end
                    end
                end
            end
        end
    end

    _G.fileTrackerWatchers = {}
    for _, folder in ipairs(fileTrackerFolders) do
        local ok, w = pcall(hs.pathwatcher.new, folder, fileTrackerCallback)
        if ok and w then
            pcall(function() w:start() end)
            table.insert(_G.fileTrackerWatchers, w)
        else
            print("⚠️ File tracker couldn't watch " .. folder)
        end
    end

    -- (6.10.0: the daily 5 PM copy-to-OneDrive timer is gone — the live
    --  CSV above already IS in OneDrive, machine-tagged.)

    -- ---- searchable picker (⌃⌥⇧F) ---------------------------------------

    _G.choosers.fileTracker = hs.chooser.new(function(choice)
        if choice and choice.text then
            local copied = choice.text
            if choice.subText and choice.subText ~= "" then
                copied = copied .. " — " .. choice.subText
            end
            hs.pasteboard.setContents(copied)
            hs.alert.show("📋 Copied")
        end
    end)
    _G.choosers.fileTracker:placeholderText("File changes — type to search name, folder, event, date…")

    local function renderFileTrackerChoices(query)
        local q = (query or ""):lower():match("^%s*(.-)%s*$")
        local choices = {}
        -- ⚡ 6.44.4 — BUILT ONCE PER ENTRY, NOT ONCE PER KEYSTROKE. This runs
        -- from queryChangedCallback, so it fires on every character typed,
        -- across 90 days of retained history. Concatenating six fields and
        -- lowercasing them each time measured 18ms per keystroke at 10,000
        -- entries; cached it is ~18x faster. `_hay` is prefixed with _ and
        -- both CSV writers in this file name their columns explicitly, so
        -- the cache never reaches disk.
        for i = #_G.fileTrackerLog, 1, -1 do  -- newest first
            local e = _G.fileTrackerLog[i]
            local haystack = e._hay
            if not haystack then
                haystack = (e.fileName .. " " .. e.newName .. " " .. e.presentLoc .. " "
                    .. e.movedLoc .. " " .. e.event .. " " .. e.timestamp):lower()
                e._hay = haystack
            end
            if q == "" or haystack:find(q, 1, true) then
                local text = e.fileName
                if e.newName ~= "" then text = text .. "  →  " .. e.newName end
                local locBits = {}
                if e.presentLoc ~= "" then table.insert(locBits, e.presentLoc) end
                if e.movedLoc   ~= "" then table.insert(locBits, "➜ " .. e.movedLoc) end
                table.insert(choices, {
                    text    = text,
                    subText = e.event .. "  ·  " .. table.concat(locBits, "  ") .. "  ·  " .. e.timestamp,
                    -- 👁 6.157.0 — the pane: every field on its own line,
                    -- nothing truncated
                    rawText = e.event .. "  " .. e.fileName
                              .. (e.newName ~= "" and ("\n→ " .. e.newName) or "")
                              .. (e.presentLoc ~= "" and ("\nin  " .. e.presentLoc) or "")
                              .. (e.movedLoc ~= "" and ("\nto  " .. e.movedLoc) or "")
                              .. "\n" .. e.timestamp,
                    when    = e.timestamp,
                })
            end
            if #choices >= 400 then break end
        end
        if #choices == 0 then
            table.insert(choices, {
                text    = (q == "") and "No file changes recorded yet" or ("No matches for \"" .. q .. "\""),
                subText = "Watching: home folder + OneDrive (edit list in init.lua §3.8)",
            })
        end
        _G.choosers.fileTracker:choices(choices)
    end

    _G.choosers.fileTracker:queryChangedCallback(function(query)
        local ok, err = pcall(renderFileTrackerChoices, query)
        if not ok then
            print("🚨 File tracker render error: " .. tostring(err))
            _G.choosers.fileTracker:choices({
                { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err) },
            })
        end
    end)

    -- 👁 6.157.0 — the preview pane follows this picker too
    pcall(function()
        _G.choosers.fileTracker:hideCallback(function()
            if core.call then pcall(core.call, "preview.suspend") end
        end)
    end)
    hs.hotkey.bind(fileTrackerMods, fileTrackerKey, function()
        renderFileTrackerChoices("")
        core.showPopup(_G.choosers.fileTracker)
        if core.call then pcall(core.call, "preview.open", _G.choosers.fileTracker) end
    end)
end

return M
