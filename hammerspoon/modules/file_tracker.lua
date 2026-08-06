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
-- CSV columns: file_name, new_name, present_location, moved_location,
-- timestamp (DD/MM/YY HH:MM), event, epoch (epoch = plain seconds
-- number used only for the 90-day pruning; harmless in Excel).
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

    local function fileTrackerRewrite(log)
        local f = io.open(fileTrackerFile, "w")
        if not f then return false end
        f:write("file_name,new_name,present_location,moved_location,timestamp,event,epoch\n")
        for _, e in ipairs(log) do
            f:write(core.csvQuote(e.fileName) .. "," .. core.csvQuote(e.newName) .. ","
                .. core.csvQuote(e.presentLoc) .. "," .. core.csvQuote(e.movedLoc) .. ","
                .. core.csvQuote(e.timestamp) .. "," .. core.csvQuote(e.event) .. ","
                .. tostring(e.epoch) .. "\n")
        end
        f:close()
        return true
    end

    local function fileTrackerLoad()
        local f = io.open(fileTrackerFile, "r")
        if not f then return {} end
        local content = f:read("*a"); f:close()
        local log, isFirst = {}, true
        for line in content:gmatch("([^\r\n]+)") do
            if not (isFirst and line:match("^file_name,")) then
                local c = core.splitCSVLine(line)
                local epoch = tonumber(c[7])
                if c[1] and epoch then
                    table.insert(log, {
                        fileName = c[1], newName = c[2] or "",
                        presentLoc = c[3] or "", movedLoc = c[4] or "",
                        timestamp = c[5] or "", event = c[6] or "",
                        epoch = epoch,
                    })
                end
            end
            isFirst = false
        end
        return log
    end

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
    if #_G.fileTrackerLog ~= #_ftLoaded or #_ftLoaded == 0 then
        if not fileTrackerRewrite(_G.fileTrackerLog) then
            core.warnWriteFailed("file tracker CSV")
        end
    end

    local function fileTrackerAppendRow(e)
        local f = io.open(fileTrackerFile, "a")
        if f then
            f:write(core.csvQuote(e.fileName) .. "," .. core.csvQuote(e.newName) .. ","
                .. core.csvQuote(e.presentLoc) .. "," .. core.csvQuote(e.movedLoc) .. ","
                .. core.csvQuote(e.timestamp) .. "," .. core.csvQuote(e.event) .. ","
                .. tostring(e.epoch) .. "\n")
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
            timestamp  = os.date("%d/%m/%y %H:%M"),
            epoch      = os.time(),
        }
        table.insert(_G.fileTrackerLog, entry)
        fileTrackerAppendRow(entry)
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
        for i = #_G.fileTrackerLog, 1, -1 do  -- newest first
            local e = _G.fileTrackerLog[i]
            local haystack = (e.fileName .. " " .. e.newName .. " " .. e.presentLoc .. " "
                .. e.movedLoc .. " " .. e.event .. " " .. e.timestamp):lower()
            if q == "" or haystack:find(q, 1, true) then
                local text = e.fileName
                if e.newName ~= "" then text = text .. "  →  " .. e.newName end
                local locBits = {}
                if e.presentLoc ~= "" then table.insert(locBits, e.presentLoc) end
                if e.movedLoc   ~= "" then table.insert(locBits, "➜ " .. e.movedLoc) end
                table.insert(choices, {
                    text    = text,
                    subText = e.event .. "  ·  " .. table.concat(locBits, "  ") .. "  ·  " .. e.timestamp,
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

    hs.hotkey.bind(fileTrackerMods, fileTrackerKey, function()
        renderFileTrackerChoices("")
        core.showPopup(_G.choosers.fileTracker)
    end)
end

return M
