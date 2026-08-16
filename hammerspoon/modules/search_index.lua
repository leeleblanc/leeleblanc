-- =====================================================================
-- MODULE: SEARCH INDEX — the file list ⇪D searches, built ahead of time
-- =====================================================================
-- LL: "build some kind of index ... some kind of well structured file
-- ... essentially what I'm trying to do is have a file sitting in
-- OneDrive, that helps with search results, and this would get
-- integrated into my app picker/document searcher. So the search has
-- to be light, nimble, fast, doesn't use a lot of CPU cycles or GPU
-- cycles or RAM and instead is aggressively efficient. ... the primary
-- files it should search are my OneDrive folders, the other main
-- folder is my user level folder ... But above all else, we don't want
-- a heavy complicated burdensome search."
--
-- ---------------------------------------------------------------------
-- WHAT THE INDEX IS, and why it is a .txt and not JSON/XML/CSV
-- ---------------------------------------------------------------------
-- One plain text file, ONE ABSOLUTE PATH PER LINE, in the OneDrive Logs
-- folder next to every other store this config keeps:
--
--     <OneDrive>/Logs/search_index-<Mac>.txt
--
-- That format was chosen ON the "aggressively efficient" requirement:
-- a JSON or XML index must be parsed before the first match; a CSV
-- needs quoting because filenames contain commas. A path-per-line file
-- needs NOTHING — the name is the tail of the path, the folder is the
-- front, and reading it is one pass with no decoder. It is also the
-- friendliest shape to sync, diff, and open by eye. Per-machine (the
-- <Mac> tag), because the two Macs' paths genuinely differ.
--
-- ---------------------------------------------------------------------
-- HOW IT IS BUILT — off the main thread, at idle priority
-- ---------------------------------------------------------------------
-- /usr/bin/find walks the roots in a CHILD process wrapped in
-- `nice -n 19`, so the walk costs Hammerspoon nothing and the Mac
-- almost nothing — this is the same "out of process" rule the OCR
-- tagger learned in 6.65.1, applied before the bug instead of after.
-- The walk prunes dot-folders, node_modules, Library, and the inside
-- of .app bundles (⇪D's own scanner owns apps), caps each root at
-- maxEntries lines, writes to a temp file and renames — a half-built
-- index is never the index. OneDrive's cloud-only files list fine:
-- find reads metadata, it does not download anything.
--
-- WHEN: once at warm() if the file is missing or older than
-- rebuildHours, then on a timer at that same cadence. Type
-- _G.indexNow() to rebuild this second; _G.fileIndexReport() says
-- what the index currently holds.
--
-- ---------------------------------------------------------------------
-- HOW IT IS SEARCHED — the two tricks that keep a keystroke cheap
-- ---------------------------------------------------------------------
--   1. LAZY, ONCE. The file is read into memory on the FIRST search
--      after a (re)build, never at boot. After that a search touches
--      no disk at all.
--   2. EVERY KEYSTROKE NARROWS THE LAST ONE. Typing "repor" only
--      re-checks the lines that already matched "repo" — the classic
--      trick that makes each added letter CHEAPER, not costlier. Only
--      deleting a letter pays for a full pass.
-- Ranking is two rules, no cleverness: a word matching the FILENAME
-- beats one matching only the folder path, and shorter paths beat
-- deeper ones. The top rows go to ⇪D; nothing is ever sorted globally.
--
-- ⚠️ WHAT THIS IS NOT: a live view. A file created five minutes ago is
-- not in the index until the next rebuild — that staleness is the
-- entire price of "light, nimble, fast", and _G.indexNow() pays it
-- down on demand. ⇪I (recent docs) already covers the just-created.

local M = {
    name  = "Search Index",
    order = 7.6,               -- right behind the App Launcher (7.5) it feeds
    cheatsheet = {
        title = "🗂 FILE INDEX (feeds ⇪D — your files behind the apps)",
        entries = {
            { "⇪D",    "Type 3+ letters: matching FILES list under the apps" },
            { "scope", "OneDrive (all of it) · your home folder · extraRoots" },
            { "file",  "<OneDrive>/Logs/search_index-<Mac>.txt — one path per line" },
            { "auto",  "Rebuilt off-thread at idle priority, twice a day" },
            { "now",   "_G.indexNow() rebuilds · _G.fileIndexReport() explains" },
        },
    },
}

function M.setup(core)
    local idx = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    idx.enabled      = true
    idx.rebuildHours = 12         -- age at which warm()/the timer rebuilds
    idx.maxEntries   = 120000     -- per ROOT at build; total cap at load too
    idx.maxResults   = 12         -- file rows handed to ⇪D per keystroke
    idx.minQuery     = 3          -- letters typed before files join the apps
    idx.homeDepth    = 5          -- how deep under ~ the walk goes; OneDrive
                                  -- is walked to the bottom (it is documents)
    -- Folder names the walk never enters. '.*' covers .git/.Trash/etc;
    -- Library covers ~/Library (which also keeps OneDrive's real folder
    -- out of the HOME walk — OneDrive is its own root, walked fully).
    idx.prune = { ".*", "node_modules", "Library", "*.app", "*.photoslibrary" }
    -- ✏️ Extra folders (absolute paths), walked homeDepth deep — "any
    -- other folders that assist me": add them here, per machine if you
    -- like via the profile settings.
    idx.extraRoots = {}
    -- ----------------------------------------------------------------------

    local home = core.homeDir or os.getenv("HOME") or ""
    idx.file = (core.logsDir or "") .. "/search_index-"
               .. tostring(core.hostTag) .. ".txt"

    local function say(m)  if _G.diag then _G.diag.say("index", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("index", m) end end

    -- ---- the roots -------------------------------------------------------
    -- OneDrive full-depth, home capped, extras capped. A root that does
    -- not exist contributes nothing and complains about nothing — the
    -- work Mac without a personal OneDrive is a real shape, not an error.
    function idx.roots()
        local out = {}
        if core.cloudDir then
            out[#out + 1] = { path = core.cloudDir, depth = nil }
        end
        if home ~= "" then
            out[#out + 1] = { path = home, depth = idx.homeDepth }
        end
        for _, p in ipairs(idx.extraRoots) do
            out[#out + 1] = { path = p, depth = idx.homeDepth }
        end
        return out
    end

    -- Shell-quote with single quotes ('%q' is LUA quoting — the 6.65.1
    -- lesson; a filename with a space or quote must survive the trip).
    local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

    -- The whole build as one /bin/sh script: each root's find appends,
    -- head caps it, wc reports the total on stdout, and the final mv is
    -- the atomic publish. find's own grumbles (permission denied on
    -- some corporate folder) go to /dev/null — a folder it cannot read
    -- is a folder that is not in the index, which is the right outcome.
    function idx.buildScript()
        local tmp = idx.file .. ".tmp"
        local pr = {}
        for _, p in ipairs(idx.prune) do
            pr[#pr + 1] = "-name " .. shq(p)
        end
        local pruneExpr = "\\( " .. table.concat(pr, " -o ") .. " \\) -prune"
        local L = { ": > " .. shq(tmp) }
        for _, r in ipairs(idx.roots()) do
            local depth = r.depth and (" -maxdepth " .. r.depth) or ""
            L[#L + 1] = "/usr/bin/nice -n 19 /usr/bin/find " .. shq(r.path)
                .. depth .. " " .. pruneExpr .. " -o -print 2>/dev/null"
                .. " | /usr/bin/head -n " .. idx.maxEntries
                .. " >> " .. shq(tmp)
        end
        L[#L + 1] = "/usr/bin/wc -l < " .. shq(tmp)
        L[#L + 1] = "/bin/mv -f " .. shq(tmp) .. " " .. shq(idx.file)
        return table.concat(L, "\n")
    end

    idx.building  = false
    idx.lastBuild = nil     -- { at, secs, count } of the last finished build
    idx.task      = nil     -- HELD: a collected hs.task is reaped mid-run

    function idx.rebuild()
        if not idx.enabled or idx.building then return false end
        local t0 = os.time()
        -- The whole construction sits in a closure: `pcall(hs.task.new,…)`
        -- would index a nil hs.task BEFORE pcall could protect anything —
        -- exactly the hostile-world shape this module promises to survive.
        local okNew, t = pcall(function() return hs.task.new("/bin/sh",
            function(exitCode, stdOut)
                idx.building, idx.task = false, nil
                if exitCode == 0 then
                    local n = tonumber(tostring(stdOut or ""):match("%d+")) or 0
                    idx.lastBuild = { at = os.time(),
                                      secs = os.time() - t0, count = n }
                    idx.entries = nil         -- reload lazily, next search
                    say("index rebuilt: " .. n .. " paths")
                    print("🗂 Search Index: rebuilt — " .. n
                          .. " paths, ready for ⇪D")
                else
                    warn("index build exited " .. tostring(exitCode))
                    print("⚠️ Search Index: the walk exited " .. tostring(exitCode)
                          .. " — ⇪D keeps using the previous index")
                end
            end, { "-c", idx.buildScript() }) end)
        if not (okNew and t) then
            warn("hs.task unavailable for the index build")
            return false
        end
        idx.task = t
        local okStart = pcall(function() return t:start() end)
        if not okStart then idx.task = nil ; return false end
        idx.building = true
        return true
    end

    -- ---- loading ---------------------------------------------------------
    -- entries[i] = the path as written; lows[i]/tails[i] = lowercase
    -- full path / lowercase filename, precomputed ONCE so a keystroke
    -- never lowercases 100k strings.
    function idx.load()
        idx.entries, idx.lows, idx.tails = {}, {}, {}
        idx.lastQ, idx.lastIds = nil, nil
        local f = io.open(idx.file, "r")
        if not f then return 0 end
        local n = 0
        for line in f:lines() do
            if #line > 2 and n < idx.maxEntries then
                n = n + 1
                idx.entries[n] = line
                local low = line:lower()
                idx.lows[n]  = low
                idx.tails[n] = low:match("[^/]*$") or low
            end
        end
        f:close()
        say("index loaded: " .. n .. " paths")
        return n
    end

    -- ---- the search ------------------------------------------------------
    local function tokens(q)
        local out = {}
        for w in q:lower():gmatch("%S+") do out[#out + 1] = w end
        return out
    end

    function idx.search(query, limit)
        if not idx.enabled then return {} end
        local q = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if #q < idx.minQuery then return {} end
        if not idx.entries then pcall(idx.load) end
        if not idx.entries or #idx.entries == 0 then return {} end
        limit = limit or idx.maxResults

        local toks = tokens(q)
        local lq = q:lower()

        -- the narrowing cache: extend the last query, re-check only its
        -- matches; anything else (deletion, new word order) = full pass
        local base = nil
        if idx.lastQ and #lq > #idx.lastQ
           and lq:sub(1, #idx.lastQ) == idx.lastQ then
            base = idx.lastIds
        end

        local ids = {}
        local best = {}          -- the top rows, kept sorted, never > limit
        local function consider(i)
            local low = idx.lows[i]
            for _, w in ipairs(toks) do
                if not low:find(w, 1, true) then return end
            end
            ids[#ids + 1] = i
            local nameHits = 0
            local tail = idx.tails[i]
            for _, w in ipairs(toks) do
                if tail:find(w, 1, true) then nameHits = nameHits + 1 end
            end
            local score = nameHits * 100000 - #low
            local at = #best + 1
            while at > 1 and best[at - 1].score < score do at = at - 1 end
            if at <= limit then
                table.insert(best, at, { i = i, score = score })
                if #best > limit then best[#best] = nil end
            end
        end

        if base then
            for _, i in ipairs(base) do consider(i) end
        else
            for i = 1, #idx.entries do consider(i) end
        end
        idx.lastQ, idx.lastIds = lq, ids

        local out = {}
        for _, b in ipairs(best) do
            local path = idx.entries[b.i]
            local name = path:match("[^/]*$")
            local dir  = path:sub(1, #path - #name - 1)
            if home ~= "" then dir = dir:gsub("^" .. home:gsub("%p", "%%%0"), "~") end
            out[#out + 1] = { path = path, name = name, dir = dir }
        end
        return out
    end

    -- ---- freshness -------------------------------------------------------
    function idx.ageSecs()
        local mt
        pcall(function() mt = hs.fs.attributes(idx.file, "modification") end)
        if type(mt) ~= "number" then return nil end
        return os.time() - mt
    end

    function idx.rebuildIfStale()
        local age = idx.ageSecs()
        if age == nil or age > idx.rebuildHours * 3600 then
            return idx.rebuild()
        end
        return false
    end

    -- ---- console verbs ---------------------------------------------------
    function _G.indexNow()
        if idx.rebuild() then
            print("🗂 Search Index: rebuilding now (off-thread; a line "
                  .. "arrives here when it lands)")
        else
            print("🗂 Search Index: not started — "
                  .. (idx.building and "a build is already running"
                      or "the module is off or hs.task is unavailable"))
        end
    end

    function _G.fileIndexReport()
        local age = idx.ageSecs()
        if not idx.entries then pcall(idx.load) end
        local L = { "🗂 SEARCH INDEX on " .. tostring(core.hostTag) }
        L[#L + 1] = "   file    " .. idx.file
        L[#L + 1] = "   age     " .. (age and string.format("%.1f hours", age / 3600)
                                      or "no index file yet — _G.indexNow()")
        L[#L + 1] = "   loaded  " .. tostring(idx.entries and #idx.entries or 0)
                    .. " paths in memory (cap " .. idx.maxEntries .. ")"
        if idx.lastBuild then
            L[#L + 1] = string.format("   built   %s — %d paths in %ds",
                        os.date("%H:%M:%S", idx.lastBuild.at),
                        idx.lastBuild.count, idx.lastBuild.secs)
        end
        for _, r in ipairs(idx.roots()) do
            L[#L + 1] = "   root    " .. r.path
                        .. (r.depth and (" (depth " .. r.depth .. ")") or " (full)")
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    core.provide("index.search",  function(q, n) return idx.search(q, n) end)
    core.provide("index.rebuild", function() return idx.rebuild() end)
    core.provide("index.report",  function() return _G.fileIndexReport() end)

    -- Off the boot path on purpose: the staleness check reads one mtime,
    -- the build itself is a child process, and the timer keeps it fresh
    -- from then on. Nothing here can slow a keypress or the boot.
    M.warm = function()
        pcall(idx.rebuildIfStale)
        if not idx.timer then
            pcall(function()
                idx.timer = hs.timer.doEvery(idx.rebuildHours * 3600,
                    function() pcall(idx.rebuildIfStale) end)
            end)
        end
    end

    _G.fileIndex = idx
    M.idx    = idx
    M.config = idx
end

return M
