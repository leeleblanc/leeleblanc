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
-- Watching the FOLDERS INSIDE your home folder, one watcher each, plus your
-- OneDrive. Until 6.229.0 it was the whole home folder in one watcher, and
-- ~/Library came free with it: 60,115 wake-ups to keep 49 rows in a day.
-- To keep that sane:
--   • ~/Library is not WATCHED at all now (it used to be watched and then
--     thrown away in Lua, which paid the whole cost and kept nothing)
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
            { "Enter", "Copy row  ·  90-day history" },
            { "check", "_G.fileTrackerReport() — what it watches, and what it costs your mouse" }
        },
    },
}

function M.setup(core)
    -- ✏️ EDIT HERE ---------------------------------------------------------
    -- 🕵️ 6.228.0 — THE TRACKER IS TIMED, AND IT CAN BE TURNED OFF.
    local ft = {}
    ft.enabled = true    -- false: no folder is watched at all. The picker,
                         -- the CSV and the 90-day history still work — only
                         -- new events stop being recorded.
    ft.slowMs  = 120     -- a callback or a CSV write slower than this is a
                         -- BREAK and takes the 🔔 door, so LL sees it happen
    -- ----------------------------------------------------------------------

    ft.state     = "not started yet"
    ft.clockName = "nothing timed yet"
    ft.stats = { callbacks = 0, paths = 0, rows = 0,
                 cbMs = 0, cbWorstMs = 0, cbWorstAt = nil, slowCb = 0,
                 writes = 0, writeMs = 0, writeWorstMs = 0,
                 writeWorstAt = nil, slowWrite = 0, writeFails = 0,
                 startedAt = nil }

    -- A monotonic millisecond, with a degrade: a Hammerspoon without
    -- absoluteTime still counts, less precisely, rather than reporting 0 for
    -- everything — 6.196.1's rule, that "never measured" must not read the
    -- same as "measured and fast". The report names which clock answered.
    function ft.nowMs()
        if hs.timer and hs.timer.absoluteTime then
            local ok, v = pcall(hs.timer.absoluteTime)
            if ok and tonumber(v) then
                ft.clockName = "hs.timer.absoluteTime"
                return tonumber(v) / 1e6
            end
        end
        ft.clockName = "os.clock — hs.timer.absoluteTime is missing"
        return os.clock() * 1000
    end

    -- 🔔 6.228.0 — THE BREAK IS SEEN. LL, 2026-09-14: "I can't move files in
    -- drag and drop again … caps lock stays on and Hammerspoon seems locked
    -- up." macOS wakes this module for EVERY file event under the home
    -- folder, and the work it then does — path checks, and a synchronous
    -- append into the OneDrive-synced CSV — happens ON THE MAIN THREAD.
    -- While that runs every hs.eventtap on the Mac is queued behind it, and
    -- a mouse-down delayed past Finder's drag threshold is a drag that never
    -- starts. Nothing crashed, the boot was fast, no report said a word, and
    -- his mouse was simply gone. It alerts now.
    local function tooSlow(what, ms)
        local why = ("%s took %d ms on the main thread — every click on this "
                     .. "Mac waits behind it, so drag and drop stops working")
                    :format(what, math.floor(ms + 0.5))
        if type(core.degrade) == "function" then
            return core.degrade("File tracker", why)
        end
        print("⚠️ File tracker: " .. why)
        return false, why
    end

    -- The two counters are kept APART on purpose. "The file tracker is slow"
    -- names a module, not a cause: the wake-up and the write are two
    -- different repairs (narrow the watched folders / move the write off the
    -- main thread), and only the bigger of these two numbers says which.
    function ft.noteCallback(ms, paths)
        local s = ft.stats
        s.callbacks = s.callbacks + 1
        s.paths = s.paths + (tonumber(paths) or 0)
        ms = tonumber(ms) or 0
        s.cbMs = s.cbMs + ms
        if ms > s.cbWorstMs then s.cbWorstMs, s.cbWorstAt = ms, os.date("%H:%M:%S") end
        if ms > (tonumber(ft.slowMs) or 120) then
            s.slowCb = s.slowCb + 1
            tooSlow("an FSEvents wake-up", ms)
        end
    end

    function ft.noteWrite(ms)
        local s = ft.stats
        s.writes = s.writes + 1
        ms = tonumber(ms) or 0
        s.writeMs = s.writeMs + ms
        if ms > s.writeWorstMs then s.writeWorstMs, s.writeWorstAt = ms, os.date("%H:%M:%S") end
        if ms > (tonumber(ft.slowMs) or 120) then
            s.slowWrite = s.slowWrite + 1
            tooSlow("a CSV write", ms)
        end
    end

    -- ===================================================================
    -- 🎯 6.229.0 — THE WATCH IS THE COST, AND IT IS NARROWED AT THE WATCH
    -- ===================================================================
    -- LL, 2026-09-15, having installed 6.228.0 and run it for a day:
    -- "Can I get a paper trail of /Users/leeleblanc or is that too broad?"
    -- His own report answered him, and it is the whole reason this release
    -- exists:
    --
    --     events : 60115 wake-up(s) · 204662 path(s) seen · 49 row(s) written
    --     wake-ups : 16597 ms total · worst 58 ms
    --
    -- Sixty THOUSAND wake-ups and sixteen and a half SECONDS of main thread,
    -- to keep forty-nine rows. Four thousand paths examined for every row
    -- that survived. Every one of those wake-ups queues behind it whatever
    -- click the Mac was about to deliver, which is his drag and drop.
    --
    -- 🔎 AND NOT ONE CROSSED 120 ms, so 6.228.0's alert never fired and was
    -- right not to. THE INSTRUMENT MEASURED THE WRONG DIMENSION: ft.slowMs
    -- guards a single expensive event, and the damage here is FREQUENCY —
    -- sixty thousand cheap ones. A worst case of 58 ms says nothing about a
    -- module that costs 58 ms sixty thousand times. RULE, and it generalises
    -- past this file: a budget on the size of one event is not a budget on
    -- the cost of the feature; when a cost is paid per wake-up, COUNT THE
    -- WAKE-UPS.
    --
    -- 🚨 THE FILTERING WAS IN THE WRONG PLACE, AND THAT IS THE BUG.
    -- fileTrackerExcludedPath already throws away everything under
    -- ~/Library — but it throws it away in LUA, which is to say AFTER macOS
    -- has woken the main thread, built the path array and handed it over.
    -- The work was always wasted; only the wake-up was not. So the exclusion
    -- moves to where it costs nothing: the folders are never watched, and
    -- FSEvents never wakes us for them at all.
    --
    -- 💡 WHICH IS WHY THIS LOSES HIM NOTHING, and that is provable from his
    -- own numbers rather than promised: the rows that stop arriving are the
    -- rows the Lua exclusions were already discarding. 204,662 paths seen,
    -- 49 rows kept. The 49 stay.
    --
    -- 📏 THE ONE COST, NAMED (a consequence you decide not to act on is one
    -- you are obliged to name — 6.201.1): a LOOSE FILE sitting at the top of
    -- ~ , in no folder at all, is no longer watched, and a NEW top-level
    -- folder is picked up at the next reload rather than the moment it is
    -- made. The report says both, and `folders` names the list by hand.
    ft.folders = nil     -- nil: work it out from the home folder.
                         -- A table of paths: watch exactly those, nothing else.
    ft.skip    = { "Library" }   -- top-level names never watched. Library is
                         -- macOS's folder, not his — caches, cookies,
                         -- containers and the OneDrive sync engine, and every
                         -- path in it was already being discarded in Lua.
    -- Hidden folders are skipped, with ONE exception, because the path
    -- exclusions go out of their way to KEEP it: ~/.hammerspoon is tracked
    -- deliberately (config edits and init.lua swaps are worth a paper
    -- trail). Narrowing the watch must not quietly retire a decision the
    -- exclusions already made.
    ft.keepHidden = { ".hammerspoon" }

    -- 🎯 6.241.0 — AND THE SAME RULE, ONE LEVEL DOWN, INSIDE THE CLOUD
    -- FOLDER. 6.229.0 moved the ~/Library exclusion from Lua to the WATCH
    -- because "an exclusion that runs after the expensive thing has
    -- happened is not a filter, it is a receipt". Two receipts were left
    -- behind in this very file: fileTrackerExcludedPath discards the whole
    -- Logs folder, and Logs is inside OneDrive-Personal — which 6.229.0
    -- then added BACK by name as a watched root. So every store this
    -- config writes (the clipboard poll, the OCR log, the boot cost row,
    -- the master log, and this module's OWN CSV) woke this module, handed
    -- it a path, and had that path thrown away in Lua. The module was
    -- waking itself, thousands of times a day, to discard its own writes.
    --
    -- The cloud folder is watched by its CHILDREN now, minus these names.
    --
    -- 🚨 `Logs` AND NOTHING MORE, deliberately. The exclusions also drop
    -- <cloud>/Backups/Hammerspoon/ — but they keep the REST of Backups, so
    -- skipping the whole `Backups` folder here would quietly un-decide
    -- something the exclusions decided (6.229.0's own rule about ~/.hammer-
    -- spoon, in the other direction). The nightly backup and the 30-minute
    -- store mirror still wake this module and are still discarded in Lua:
    -- named, not fixed, because narrowing those needs a second level of
    -- the same trick and this release changes one thing.
    ft.cloudSkip     = { "Logs" }
    ft.maxCloudRoots = 40   -- past this many folders inside the cloud folder,
                            -- watch it whole instead: a hundred pathwatchers
                            -- to save one is not a saving, and the report
                            -- says which of the two happened.

    ft.skipped      = {}
    ft.dropped      = {}
    ft.cloudSkipped = {}
    ft.cloudWhy     = "not worked out yet"
    ft.watchWhy     = "not worked out yet"

    -- Does `root` already cover `path`? Two pathwatchers over the same tree
    -- means macOS wakes us TWICE for one file event — the exact cost this
    -- release exists to cut, paid in duplicate.
    function ft.covers(root, path)
        if type(root) ~= "string" or type(path) ~= "string" then return false end
        if root == "" or path == "" then return false end
        return path == root or path:sub(1, #root + 1) == (root .. "/")
    end

    -- 🔗 6.230.0 — AND A SYMLINK WALKS STRAIGHT PAST ft.covers, BECAUSE
    -- ft.covers COMPARES TEXT. LL's Mac, on the first 6.229.0 report:
    --     /Users/leeleblanc/OneDrive
    --     /Users/leeleblanc/Library/CloudStorage/OneDrive-Personal
    -- Two rows, ONE tree. `~/OneDrive` is a symlink macOS leaves behind when
    -- OneDrive moves into CloudStorage (`hs.fs.symlinkAttributes(p, "mode")`
    -- → "link", his Console, not a theory). Neither string is a prefix of
    -- the other, so the duplicate guard 6.229.0 added had nothing to catch,
    -- and the busiest tree on the Mac was watched twice: TWO WAKE-UPS FOR
    -- EVERY FILE EVENT IN ONEDRIVE — the exact cost that release existed to
    -- cut, paid in duplicate, in the release that cut it.
    --
    -- 🚨 AND ft.homeDirs COULD NOT SEE IT EITHER: hs.fs.attributes FOLLOWS a
    -- link, so the mode came back "directory" and the link read as an
    -- ordinary folder. RULE, general: a check that identifies a thing by its
    -- PATH is not a check about the thing — resolve before you compare, and
    -- ask symlinkAttributes when the question is "what is this", because
    -- attributes answers about the destination.
    --
    -- 💡 RESOLVE, THEN DE-DUPLICATE — never "skip every symlink". A link to
    -- a folder he really does keep elsewhere is a folder he wants watched;
    -- what is wrong is watching one tree twice, not reaching it by a link.
    -- So a root becomes its real path, and a real path already in the list
    -- (or already inside another kept root) is dropped and NAMED.
    function ft.realOf(path, abs, link)
        if type(path) ~= "string" or path == "" then return path end
        -- 🚨 `abs or default` is NOT how you take an optional dependency you
        -- also want the gate to be able to switch OFF: `false or default` is
        -- the default, so the belt below could never be tested alone. nil
        -- means "work it out", anything else is taken at its word.
        if abs  == nil then abs  = hs.fs and hs.fs.pathToAbsolutePath end
        if link == nil then link = hs.fs and hs.fs.symlinkAttributes end
        -- realpath() first: it resolves every link in the whole path, not
        -- just a final one, and answers in one call. Its answer is only
        -- usable if it is ABSOLUTE — a relative one is not a path we can
        -- hand to hs.pathwatcher, so it falls through to the belt.
        if type(abs) == "function" then
            local ok, r = pcall(abs, path)
            if ok and type(r) == "string" and r:sub(1, 1) == "/" and r ~= path then
                return (r:gsub("/+$", ""))
            end
        end
        -- The belt: a Hammerspoon without pathToAbsolutePath, or one that
        -- hands the path straight back, still gets the one hop that matters.
        if type(link) == "function" then
            local ok, t = pcall(link, path, "target")
            if ok and type(t) == "string" and t ~= "" then
                if t:sub(1, 1) ~= "/" then
                    t = (path:match("^(.*)/[^/]*$") or "") .. "/" .. t
                end
                return (t:gsub("/+$", ""))
            end
        end
        return (path:gsub("/+$", ""))
    end

    -- PURE given `realOf`, so the gate proves the whole rule with a table of
    -- fake links and no Mac. Returns the roots actually worth a watcher, and
    -- every root dropped WITH THE REASON — a watcher that quietly disappears
    -- from the report is how a narrowing becomes a loss nobody can see.
    function ft.dedupeRoots(roots, realOf)
        realOf = realOf or ft.realOf
        local kept, dropped, seen, first = {}, {}, {}, {}

        local rows = {}
        for _, p in ipairs(roots or {}) do
            if type(p) == "string" and p ~= "" then
                local r = realOf(p)
                if type(r) ~= "string" or r == "" then r = p end
                rows[#rows + 1] = { given = (p:gsub("/+$", "")), real = (r:gsub("/+$", "")) }
            end
        end

        -- One tree under two names is one watcher — and THE REAL PATH WINS
        -- THE SLOT, never whichever name came first in the listing. On LL's
        -- Mac the link is listed before the folder it points at (hs.fs.dir
        -- returns filesystem order), so "first wins" would have watched the
        -- tree under its link name and then reported the REAL path as the
        -- redundant one. That reads backwards against the watching list
        -- directly above it, and a report that contradicts itself is worse
        -- than one that says less.
        for _, e in ipairs(rows) do
            local best = seen[e.real]
            if best == nil then
                seen[e.real] = e
                first[#first + 1] = e
            elseif best.given ~= best.real and e.given == e.real then
                -- the real path has turned up after its link: swap them, so
                -- the survivor is always the name FSEvents itself reports
                dropped[#dropped + 1] = { path = best.given, real = best.real,
                    why = "the same folder as " .. e.real
                          .. " — a link, not a second tree" }
                for i, f in ipairs(first) do if f == best then first[i] = e ; break end end
                seen[e.real] = e
            else
                dropped[#dropped + 1] = { path = e.given, real = e.real,
                    why = "the same folder as " .. best.real
                          .. " — a link, not a second tree" }
            end
        end

        -- And a tree INSIDE a tree already watched is one watcher too — the
        -- same rule 6.229.0 wrote for the cloud folder, applied now to real
        -- paths rather than to the names they were reached by.
        for i, e in ipairs(first) do
            local inside = nil
            for j, o in ipairs(first) do
                if i ~= j and o.real ~= e.real and ft.covers(o.real, e.real) then
                    inside = o.real ; break
                end
            end
            if inside then
                dropped[#dropped + 1] = { path = e.given, real = e.real,
                    why = "inside " .. inside .. " — already watched" }
            else
                kept[#kept + 1] = e.real
            end
        end
        return kept, dropped
    end

    -- 🎯 6.241.0 — WHICH FOLDERS INSIDE THE CLOUD FOLDER ARE WATCHED.
    -- PURE. Answers the kept child paths, what was skipped and why, or
    -- NIL AND A REASON when narrowing would be worse than not narrowing —
    -- the caller then watches the cloud folder whole, exactly as before
    -- this release, and the report says so rather than quietly doing less.
    function ft.cloudRoots(cloud, names, skipNames, max)
        if type(cloud) ~= "string" or cloud == "" then return nil, nil, nil end
        cloud = cloud:gsub("/+$", "")
        -- nil is "this Mac could not answer", which is NOT an empty folder —
        -- ft.homeDirs' rule, and the cost of confusing them here is watching
        -- none of his cloud files while the report reads perfectly normal.
        if names == nil then
            return nil, nil, "could not list " .. cloud
        end
        max = tonumber(max) or 40
        local skip = {}
        for _, n in ipairs(skipNames or {}) do
            if type(n) == "string" then skip[n:lower()] = true end
        end
        local kept, skipped = {}, {}
        for _, n in ipairs(names) do
            if type(n) == "string" and n ~= "" and n ~= "." and n ~= ".." then
                local low = n:lower()
                if skip[low] then
                    skipped[#skipped + 1] = { name = n,
                        why = "this config's own stores — every write in here"
                              .. " was waking the module that wrote it" }
                elseif n:sub(1, 1) == "." then
                    skipped[#skipped + 1] = { name = n, why = "hidden" }
                else
                    kept[#kept + 1] = cloud .. "/" .. n
                end
            end
        end
        if #kept == 0 then
            return nil, skipped, "nothing inside " .. cloud .. " to watch"
        end
        if #kept > max then
            return nil, skipped, #kept .. " folder(s) inside " .. cloud
                   .. " — more than the " .. max .. " this budgets"
        end
        return kept, skipped, nil
    end

    -- 🎯 6.241.0 — AND THE SWAP ITSELF, PURE, AND IT RUNS AFTER THE DEDUPE
    -- ON PURPOSE. ~/OneDrive is a LINK to the cloud folder (6.230.0), so at
    -- the moment watchRoots builds its list there are two names for that
    -- tree and only ft.dedupeRoots knows it. Expanding before that runs
    -- would put the children in the list and then have the dedupe drop
    -- every one of them as "inside" the link's own whole-tree watcher —
    -- this release doing nothing at all, quietly, on the exact Mac it was
    -- written for. So the cloud folder wins its slot first, by whichever
    -- name, and the slot is swapped for its children here.
    -- → the new list, and whether the swap actually happened.
    function ft.expandCloud(roots, cloudReal, children)
        if type(roots) ~= "table" or type(children) ~= "table"
           or #children == 0 or type(cloudReal) ~= "string" or cloudReal == "" then
            return roots, false
        end
        cloudReal = cloudReal:gsub("/+$", "")
        local out, replaced = {}, false
        for _, r in ipairs(roots) do
            if (type(r) == "string" and r:gsub("/+$", "") == cloudReal) then
                replaced = true
                for _, c in ipairs(children) do out[#out + 1] = c end
            else
                out[#out + 1] = r
            end
        end
        return out, replaced
    end

    -- PURE, and that is the point: every rule about WHAT IS WATCHED is
    -- decided here, off a plain list of names, so the gate proves the whole
    -- of it with no Mac and no file system. `names` is the top-level
    -- DIRECTORY names in the home folder; the listing itself is ft.homeDirs.
    function ft.watchRoots(home, cloud, names)
        local kept, skipped = {}, {}
        if type(home) ~= "string" or home == "" then return kept, skipped end
        home = home:gsub("/+$", "")

        local skip = {}
        for _, n in ipairs(ft.skip or {}) do
            if type(n) == "string" then skip[n:lower()] = true end
        end
        local keepHidden = {}
        for _, n in ipairs(ft.keepHidden or {}) do
            if type(n) == "string" then keepHidden[n:lower()] = true end
        end

        for _, n in ipairs(names or {}) do
            if type(n) == "string" and n ~= "" and n ~= "." and n ~= ".." then
                local low = n:lower()
                if skip[low] then
                    skipped[#skipped + 1] = { name = n, why = "noise — nothing here was ever logged" }
                elseif n:sub(1, 1) == "." and not keepHidden[low] then
                    skipped[#skipped + 1] = { name = n, why = "hidden" }
                else
                    kept[#kept + 1] = home .. "/" .. n
                end
            end
        end

        -- OneDrive lives INSIDE ~/Library on this Mac, so skipping Library
        -- would take it with it. It is added back by name — unless a folder
        -- already kept contains it, which would be two watchers over one
        -- tree and two wake-ups for every file event in it.
        if type(cloud) == "string" and cloud ~= "" then
            cloud = cloud:gsub("/+$", "")
            local already = false
            for _, k in ipairs(kept) do
                if ft.covers(k, cloud) then already = true ; break end
            end
            if not already then kept[#kept + 1] = cloud end
        end
        return kept, skipped
    end

    -- The thin IO half: the top-level DIRECTORIES of the home folder.
    -- Returns nil when this Mac cannot answer, which is NOT the same as an
    -- empty home folder — the caller falls back to the old whole-home watch
    -- and says so, rather than silently watching nothing at all.
    function ft.homeDirs(home, lister, statter)
        lister  = lister  or (hs.fs and hs.fs.dir)
        statter = statter or (hs.fs and hs.fs.attributes)
        if type(lister) ~= "function" or type(statter) ~= "function" then return nil end
        -- 🚨 `local names, ok = {}, pcall(...)` looks identical and is not:
        -- Lua evaluates the whole right-hand side BEFORE the locals exist,
        -- so the closure would close over a GLOBAL `names` that is nil, throw
        -- on the first insert, and report this Mac as unable to list its own
        -- home folder. Declared first, deliberately.
        local names = {}
        local ok = pcall(function()
            for n in lister(home) do
                if n ~= "." and n ~= ".." then
                    local mode = statter(home .. "/" .. n, "mode")
                    if mode == "directory" then names[#names + 1] = n end
                end
            end
        end)
        if not ok then return nil end
        return names
    end

    -- Which folders will be watched, and why — one answer, so the report
    -- and the watcher loop cannot disagree about it.
    function ft.resolveFolders()
        if type(ft.folders) == "table" and #ft.folders > 0 then
            local list = {}
            for _, f in ipairs(ft.folders) do
                if type(f) == "string" and f ~= "" then list[#list + 1] = f end
            end
            if #list > 0 then
                ft.cloudWhy, ft.cloudSkipped =
                    "your own folders list — nothing is added or narrowed", {}
                -- Deduped too: his list is honoured verbatim in REACH, but a
                -- folder named twice (or named once by a link and once by its
                -- real path) is still one tree and still one watcher.
                local one, gone = ft.dedupeRoots(list)
                return one, {}, "settings = { file_tracker = { folders = ... } }", gone
            end
        end
        local names = ft.homeDirs(core.homeDir)
        if not names then
            local why = "could not list " .. tostring(core.homeDir)
                        .. " — watching the WHOLE home folder instead, which is"
                        .. " the slow way round"
            if type(core.degrade) == "function" then
                pcall(core.degrade, "File tracker", why)
            else
                print("⚠️ File tracker: " .. why)
            end
            local wide = { core.homeDir }
            if core.cloudDir and not ft.covers(core.homeDir, core.cloudDir) then
                wide[#wide + 1] = core.cloudDir
            end
            local wideOne, wideGone = ft.dedupeRoots(wide)
            ft.cloudWhy, ft.cloudSkipped =
                "the WHOLE folder — the home folder could not be listed either", {}
            return wideOne, {}, "⚠️ " .. why, wideGone
        end
        local kept, skipped = ft.watchRoots(core.homeDir, core.cloudDir, names)
        local one, gone = ft.dedupeRoots(kept)
        one = ft.narrowCloud(one)
        return one, skipped, "your folders, one watcher each — ~/Library is not one of them", gone
    end

    -- 🎯 6.241.0 — THE IO HALF OF THE CLOUD NARROWING, and the only place
    -- ft.cloudWhy / ft.cloudSkipped are decided. Three states, and they must
    -- not read alike: narrowed to the cloud folder's own folders · watched
    -- whole with the reason · no cloud folder at all.
    function ft.narrowCloud(roots)
        ft.cloudSkipped = {}
        if not core.cloudDir then
            ft.cloudWhy = "no cloud folder on this Mac"
            return roots
        end
        -- The SAME lister the home folder uses, asked about the cloud folder.
        local cloudNames = ft.homeDirs(core.cloudDir)
        local children, cskip, why =
            ft.cloudRoots(core.cloudDir, cloudNames, ft.cloudSkip, ft.maxCloudRoots)
        ft.cloudSkipped = cskip or {}
        if not children then
            ft.cloudWhy = "the WHOLE folder — " .. (why or "not narrowed")
            -- A Mac that cannot list its own cloud folder is a BREAK, not a
            -- preference: the wake-ups this release exists to cut go on
            -- being paid, so it is seen rather than only logged.
            if cloudNames == nil then
                local cwhy = "could not list " .. tostring(core.cloudDir)
                    .. " — watching the whole cloud folder, so this config's"
                    .. " own writes in it still wake this module"
                if type(core.degrade) == "function" then
                    pcall(core.degrade, "File tracker", cwhy)
                else
                    print("⚠️ File tracker: " .. cwhy)
                end
            end
            return roots
        end
        local out, replaced = ft.expandCloud(roots, ft.realOf(core.cloudDir), children)
        if replaced then
            ft.cloudWhy = "by its " .. #children .. " folder(s), not whole"
            return out
        end
        -- Not in the list at all: a cloud folder that lives inside a folder
        -- already being watched was never added as its own root (6.229.0),
        -- so there is no slot to swap and its Logs folder is still covered.
        ft.cloudWhy = "inside a folder already watched — not narrowed, so its"
                      .. " Logs folder is still under a watcher"
        return roots
    end

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

    -- =====================================================================
    -- ⏱ 6.267.0 - THE 90 DAYS ARE READ WHEN THEY ARE FIRST NEEDED
    -- =====================================================================
    -- LL, with a boot log: "How can I wrap the file_tracker and
    -- activity_tracker initialization in an asynchronous timer to speed up
    -- the boot?" His ⏱ line read 453 ms across 72 modules, and 200 of
    -- them were THIS module - by a wide margin the slowest thing in the
    -- boot. All of it was here: setup() opened a CSV that lives in
    -- OneDrive, read it whole, parsed every row, pruned it, and on a
    -- migration or a prune REWROTE it - synchronously, on the main thread,
    -- before a single ⇪ shortcut had been bound.
    --
    -- 🔑 A TIMER IS THE RIGHT INSTRUMENT AND A BARE doAfter IS THE WRONG
    -- ONE, for two reasons this project has already paid for. The first is
    -- that the config HAS this timer: `M.warm` runs a couple of seconds
    -- after boot, inside its own pcall, and a warm that throws is named
    -- rather than lost (6.33.0). A second unheld timer beside it is a
    -- second thing to keep in step. The second is worse: between boot and
    -- whenever the timer landed, `_G.fileTrackerLog` would be an EMPTY
    -- LIST, and ⇪F pressed in that window would draw a 90-day history
    -- with nothing in it. "Not read yet" and "you have no history" are
    -- opposite facts and must not read the same (6.196.1).
    --
    -- So the read is LAZY and there is exactly ONE DOOR to it. The first
    -- caller that wants the rows pays for them; `M.warm` is that caller on
    -- an ordinary Mac, a few seconds after boot when nothing is happening,
    -- so no keypress ever waits. A keypress that does arrive first gets
    -- the read rather than an empty answer - his press, his 200 ms, and
    -- the honest one.
    --
    -- 📏 COST, NAMED: the read is still synchronous when it happens, and
    -- it still happens on the main thread. What changes is WHEN - off the
    -- boot path, where it was delaying every other module and every key.
    -- Moving the parse itself off the thread is a different release and
    -- needs a different mechanism (/bin/cat in an hs.task, 6.170.3's
    -- shape); it is not what was asked for and is not smuggled in here.
    ft.loadState = "not read yet"
    ft.loadMs    = 0
    ft.loadedAt  = nil
    local _ftLog = nil

    -- 🔒 THE ONE DOOR. Every reader and every writer below asks for the
    -- rows through this, and a source sentry in the suite fails if any of
    -- them reaches for the bare global instead - a single caller left
    -- reading `_G.fileTrackerLog` directly is a caller that sees nil
    -- before the read, which is the whole class this shape exists to
    -- close. The global is still published, because that is what it has
    -- always been, but it is published only once it holds real rows.
    local function ftLog()
        if _ftLog then return _ftLog end
        local t0 = ft.nowMs()
        local loaded = fileTrackerLoad()
        _ftLog = fileTrackerPrune(loaded)
        _G.fileTrackerLog = _ftLog
        -- 📅 THE MIGRATION, and note the ORDER: back up, then rewrite. A
        -- backup taken after the rewrite would be a backup of the new file,
        -- which is not a backup of anything.
        if ftNeedsMigration then fileTrackerBackupOnce() end
        if ftNeedsMigration or #_ftLog ~= #loaded or #loaded == 0 then
            if not fileTrackerRewrite(_ftLog) then
                core.warnWriteFailed("file tracker CSV")
            elseif ftNeedsMigration then
                print(("📅 File tracker: migrated %d rows to date-first ISO "
                       .. "timestamps (%s)"):format(#_ftLog, fileTrackerFile))
            end
        end
        ft.loadMs   = ft.nowMs() - t0
        ft.loadedAt = os.date("%H:%M:%S")
        ft.loadState = ("read %d row(s) in %d ms at %s")
                       :format(#_ftLog, math.floor(ft.loadMs + 0.5), ft.loadedAt)
        return _ftLog
    end
    ft.history = ftLog   -- the door other modules ask (recent_docs does)

    local function fileTrackerAppendRow(e)
        local t0 = ft.nowMs()
        local f = io.open(fileTrackerFile, "a")
        if f then
            f:write(fileTrackerRow(e))
            f:close()
            ft.stats.rows = ft.stats.rows + 1
        else
            ft.stats.writeFails = ft.stats.writeFails + 1
            core.warnWriteFailed("file tracker CSV")
        end
        ft.noteWrite(ft.nowMs() - t0)
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
        table.insert(ftLog(), entry)
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
            local before = #ftLog()
            _ftLog = fileTrackerPrune(_ftLog)
            _G.fileTrackerLog = _ftLog     -- the two names are ONE list
            if #_ftLog ~= before then
                _G.diag.say("fileTracker", string.format(
                    "pruned in-session: %d → %d rows", before, #_ftLog))
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

    local function fileTrackerCallbackInner(paths, flagTables)
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

    -- ⏱ macOS wakes this module here and nowhere else, so the clock goes
    -- here and nowhere else. The pcall is part of the same rule: a throw
    -- inside the classifier must still be timed, must still be counted, and
    -- must cost this module rather than the pathwatcher.
    local function fileTrackerCallback(paths, flagTables)
        local t0 = ft.nowMs()
        local ok, err = pcall(fileTrackerCallbackInner, paths, flagTables)
        ft.noteCallback(ft.nowMs() - t0, #(paths or {}))
        if not ok then
            print("🚨 File tracker callback error: " .. tostring(err))
        end
    end

    -- 🔌 THE WATCHERS START IN warm(), NOT HERE, and that is what makes the
    -- switch real: init.lua applies a profile's `settings` AFTER setup
    -- returns, so a watcher started in setup could never be stopped by
    -- `settings = { file_tracker = { enabled = false } }` — the override
    -- would land on a flag nobody reads again. warm() runs after that block.
    -- It also takes the slowest module at boot (190 ms on LL's Air, 4x the
    -- next one) off the boot path entirely.
    _G.fileTrackerWatchers = {}

    function ft.startWatching()
        if not ft.enabled then
            ft.state = "OFF — settings = { file_tracker = { enabled = false } }"
            return false, "off"
        end
        if #_G.fileTrackerWatchers > 0 then return true end
        -- 🎯 6.229.0: worked out HERE, not at load, so a profile's
        -- `settings` block (applied after setup returns) is read before a
        -- single watcher exists — 6.228.0's rule, that a switch is only real
        -- if the thing it governs starts after setup.
        fileTrackerFolders, ft.skipped, ft.watchWhy, ft.dropped = ft.resolveFolders()
        for _, folder in ipairs(fileTrackerFolders) do
            local ok, w = pcall(hs.pathwatcher.new, folder, fileTrackerCallback)
            if ok and w then
                pcall(function() w:start() end)
                table.insert(_G.fileTrackerWatchers, w)
            else
                print("⚠️ File tracker couldn't watch " .. folder)
            end
        end
        ft.stats.startedAt = os.time()
        ft.state = (#_G.fileTrackerWatchers > 0)
            and ("watching " .. #_G.fileTrackerWatchers .. " folder(s)")
            or  "⚠️ NOTHING IS WATCHED — every pathwatcher refused"
        return #_G.fileTrackerWatchers > 0
    end

    function ft.stopWatching()
        for _, w in ipairs(_G.fileTrackerWatchers) do
            pcall(function() w:stop() end)
        end
        _G.fileTrackerWatchers = {}
        ft.state = "stopped by hand — _G.fileTracker.startWatching() puts it back"
        return true
    end

    -- ⏱ 6.267.0 - THE WARM PHASE PAYS FOR THE READ, so no keypress does.
    -- `warmAfter` puts this module's read and activity_tracker's onto
    -- DIFFERENT turns of the run loop: two reads of two OneDrive CSVs in
    -- one turn is one long stall wearing two names, and a main thread this
    -- config is busy on is a mouse this Mac has lost (6.228.0).
    M.warmAfter = 3.0
    M.warm = function()
        ftLog()
        return ft.startWatching()
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
        local log = ftLog()
        for i = #log, 1, -1 do                -- newest first
            local e = log[i]
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
                subText = "Watching " .. #fileTrackerFolders .. " folder(s) — _G.fileTrackerReport() names them",
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

    -- ---- the report -------------------------------------------------------
    -- 📋 6.224.0's rule, applied to the module that earned it: when a
    -- diagnostic is asked for and its answer still does not decide anything,
    -- the missing half is a CLOCK. This module had no report at all, so
    -- "Hammerspoon takes my mouse when I move files" had nowhere to be
    -- answered — the boot was fast, the storm guard was quiet, the stall
    -- guard was healthy, and every one of those was true.
    function _G.fileTrackerReport()
        local s, L = ft.stats, { "📁 FILE TRACKER — ⌃⌥⇧F" }
        local function line(t) L[#L + 1] = t end
        local slowMs = math.floor(tonumber(ft.slowMs) or 120)

        line("   state    : " .. tostring(ft.state))
        line("   watching : " .. #fileTrackerFolders .. " folder(s) — "
             .. tostring(ft.watchWhy))
        for _, f in ipairs(fileTrackerFolders) do
            line("      " .. f
                 .. ((f == core.homeDir) and "   ← YOUR WHOLE HOME FOLDER" or ""))
        end
        if #(ft.skipped or {}) > 0 then
            local names = {}
            for _, sk in ipairs(ft.skipped) do names[#names + 1] = sk.name end
            line("   not      : " .. table.concat(names, ", "))
            line("   ↳ macOS never wakes this module for those, and THAT is the")
            line("     saving — every path in them was discarded anyway")
        end
        -- 🔗 6.230.0 — a folder REACHED but not watched twice. It is printed
        -- rather than left out, because a root that vanishes from this list
        -- with no explanation is indistinguishable from a folder that stopped
        -- being watched, and those are opposite facts.
        if #(ft.dropped or {}) > 0 then
            line("   linked   : " .. #ft.dropped .. " folder(s) reached by another name —")
            for _, d in ipairs(ft.dropped) do
                line("      " .. tostring(d.path))
                line("      ↳ " .. tostring(d.why))
            end
            line("   ↳ still watched, once. Two watchers over one tree is two")
            line("     wake-ups for every file event in it.")
        end
        line("   ↳ a loose file at the top of ~ is not watched now, and a NEW")
        line("     folder there is picked up at the next reload")
        -- 🎯 6.241.0 — THREE STATES, and they must not read alike: narrowed
        -- to the cloud folder's children · watched whole with the reason ·
        -- no cloud folder at all.
        line("   cloud    : " .. tostring(ft.cloudWhy))
        if #(ft.cloudSkipped or {}) > 0 then
            local cn = {}
            for _, sk in ipairs(ft.cloudSkipped) do cn[#cn + 1] = sk.name end
            line("   not here : " .. table.concat(cn, ", "))
            line("   ↳ this config's own stores live there. Every row it wrote")
            line("     used to wake the module that wrote it, and the path was")
            line("     then discarded in Lua — AFTER the wake-up it cost.")
        end
        line("   csv      : " .. tostring(fileTrackerFile))
        if core.cloudDir and tostring(fileTrackerFile):sub(1, #core.cloudDir)
                             == core.cloudDir then
            -- 🔎 ASKED, NOT CLAIMED. Whether this file's own folder is still
            -- watched is a FACT about the list two lines above, so it is read
            -- off that list rather than asserted by the release that changed
            -- it — a settings `folders` line can put Logs back under a
            -- watcher, and the report must say so when it does.
            local selfWatched = false
            for _, f in ipairs(fileTrackerFolders) do
                if ft.covers(f, fileTrackerFile) then selfWatched = true ; break end
            end
            line("   ↳ it is INSIDE OneDrive, and each row is still a synchronous")
            if selfWatched then
                line("     write on the main thread — AND its folder is watched, so")
                line("     this module is still woken by its own writes")
            else
                line("     write on the main thread — but its folder is NOT watched,")
                line("     so the write no longer wakes this module (6.241.0)")
            end
        end
        line("   history  : " .. ft.loadState)
        line("   rows     : " .. (_ftLog and #_ftLog or 0) .. " in memory · kept "
             .. tostring(fileTrackerRetentionDays) .. " days")
        line("   clock    : " .. tostring(ft.clockName))

        if s.callbacks == 0 then
            line("   events   : macOS has not woken this module once"
                 .. (ft.enabled and " — nothing has moved yet"
                                 or " — it is OFF, so it never will"))
        else
            line(("   events   : %d wake-up(s) · %d path(s) seen · %d row(s) written")
                 :format(s.callbacks, s.paths, s.rows))
            line(("   wake-ups : %.0f ms total · worst %.0f ms at %s")
                 :format(s.cbMs, s.cbWorstMs, tostring(s.cbWorstAt)))
            line(("   writes   : %d · %.0f ms total · worst %.0f ms at %s · %d FAILED")
                 :format(s.writes, s.writeMs, s.writeWorstMs,
                         tostring(s.writeWorstAt), s.writeFails))
            -- 🎯 6.229.0: the number that decided this release. A worst case
            -- says nothing about a cost paid sixty thousand times, so the
            -- report prints what the wake-ups BOUGHT beside what they cost.
            -- 🚨 6.230.0 — AND NOT OVER ZERO ROWS. `s.paths / max(rows, 1)`
            -- printed "65 path(s) ... for every row kept" on a session that
            -- kept NO rows, which is a division that did not happen dressed
            -- as a measurement. No rows is its own answer and says so.
            if s.paths > 0 and s.rows > 0 then
                line(("   yield    : %d path(s) woke this module for every row kept")
                     :format(math.floor(s.paths / s.rows)))
            elseif s.paths > 0 then
                line(("   yield    : %d path(s) seen and NO rows kept yet — "
                      .. "nothing worth logging has moved"):format(s.paths))
            end
            if (s.slowCb + s.slowWrite) > 0 then
                line(("   ⚠️ SLOW   : %d over %d ms — %d wake-up(s) · %d write(s)")
                     :format(s.slowCb + s.slowWrite, slowMs, s.slowCb, s.slowWrite))
                line("   ↳ THAT is what stops drag and drop. Whichever of those")
                line("     two counts is larger names the half to fix.")
            else
                line("   ⚠️ slow   : none over " .. slowMs
                     .. " ms — nothing here has held your mouse this session")
            end
        end
        line("   off      : settings = { file_tracker = { enabled = false } }")
        line("   reach    : settings = { file_tracker = { folders = "
             .. "{ \"/Users/you/Documents\" } } }")
        line("   ↳ now    : _G.fileTracker.stopWatching()  ·  put it back with"
             .. " _G.fileTracker.startWatching()")
        print(table.concat(L, "\n"))
        return ft.stats
    end

    if core.provide then
        core.provide("fileTracker.report", function() return _G.fileTrackerReport() end)
    end
    _G.fileTracker = ft
    M.ft     = ft
    M.config = ft
end

return M
