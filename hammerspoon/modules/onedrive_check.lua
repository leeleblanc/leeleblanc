-- ☁️ ONEDRIVE CHECK — is the file really HERE, and did it LEAVE? (6.368.0)
-- =====================================================================
-- LL: "Can we build some kind of check tool? I'm finding that sometimes
-- even with me marking OneDrive files to 'Always keep on device'
-- OneDrive will offload them."
--
-- 🔬 THE DETECTION IS PROVEN AND THE PIN IS NOT, so this release is
-- honest about which half is which.
--
--   · PROVEN: `hs.fs.attributes` answers BOTH `size` (st_size, the
--     LOGICAL size) and `blocks` (st_blocks, the 512-byte blocks really
--     ALLOCATED) — extensions/fs/libfs.m:679-688, field table :734-737,
--     read with the file named (6.233.0). A dehydrated placeholder
--     carries the full logical size with almost nothing behind it, and
--     that difference is the only thing on this Mac that can tell the
--     two apart WITHOUT READING THE FILE. 6.357.0 rests on it already.
--   · NOT KNOWN: whether "Always keep on device" is readable at all.
--     The pin belongs to macOS's File Provider and may live in an
--     extended attribute, or may live only inside OneDrive. Designing
--     on a belief about that is what 6.233.0 forbids — so this release
--     ASKS his Mac and prints the answer, rather than shipping a guess
--     about where a pin lives.
--
-- 🚨 THE ONE RULE THIS MODULE MUST NEVER BREAK: IT DOES NOT READ A FILE.
-- Reading a placeholder HYDRATES it, a hydration is a download, and a
-- download on the main thread is the 72-second freeze that killed his
-- Hammerspoon on 2026-10-12 (6.357.0 · 6.228.0). Every answer here comes
-- from a STAT, which touches no bytes. A source sentry in the suite
-- fails the gate if io.open or :read ever appears in this file.
--
-- 🔑 AND IT IS A DIFFERENT QUESTION FROM `vid.onDisk`, deliberately, so
-- nobody merges them later: that one answers "is it safe to READ this
-- film now" and is biased TOWARD reading, because refusing a local film
-- costs one keypress and reading a cloud one costs a frozen Mac. This
-- one answers "is this file actually here" and has no bias at all — it
-- is a report, and a report that guesses is worse than one that says it
-- cannot tell (6.196.1).
--
--   _G.oneDriveCheck()   — the report
--   settings = { onedrive_check = { folders = { "/path", … } } }

-- 🗂 FILED AS "files": it is about the files OneDrive holds, which is
-- where a reader will look for it. The gate reads these off the table
-- itself, so a module that declares none cannot reach a release unfiled.
local M = {
    name   = "onedrive_check",
    order  = 96,
    family = "files",
    summary = "☁️ onedrive_check — watches the OneDrive tree and says when a"
              .. " file that was on this Mac is taken back to the cloud",
}
M.cheatsheet = {
    title = "☁️ ONEDRIVE CHECK (Console)",
    entries = {
        { "cloud check", "6.367.0: _G.oneDriveCheck() — walks the folders that hold your data and names every file whose BYTES are not on this Mac, however it is marked in Finder. It never reads a file: reading one downloads it, and that is the 72-second freeze" },
        { "probe",       "The same report prints the extended attributes macOS keeps on a local file and on an offloaded one, side by side — that comparison is what can say whether \"Always keep on device\" is readable at all" },
        { "folders",     "By default the Vault, the Logs folder and the OneDrive root. settings = { onedrive_check = { folders = { \"/full/path\" } } } names your own" },
        { "the watch",   "6.368.0: every 30 min it walks the WHOLE tree with find+stat in a background task and compares against the last sweep. A file that was HERE and is in the cloud now has been taken back — that is the one thing \"Always keep on device\" was supposed to prevent, and you get an alert naming it" },
        { "sweep now",   "_G.oneDriveSweep() runs one at once. The report's ☁️ LEFT THIS MAC block survives a reload — it is kept in Application Support, never in OneDrive" },
        { "if it stops", "A sweep that fails takes the 🔔 door: an alert, a ⚠️ Console line and a row in _G.todayReport(). The report's watch line reads WANTED but NOT RUNNING rather than printing a reassuring count" },
    },
}

local od = {
    enabled   = true,
    -- 📏 BOUNDED, AND EVERY BOUND IS A STATE (6.197.2). Walking a folder
    -- is main-thread work, and his vault holds hundreds of notes while
    -- OneDrive holds everything. A count taken under a bound is a FLOOR,
    -- never a total, and the report says so rather than printing a
    -- number that reads like an answer.
    maxFiles  = 4000,     -- stats per run, across all folders
    maxDepth  = 6,        -- how deep to walk
    maxNamed  = 12,       -- offloaded files named in the report
    probeMax  = 3,        -- files of each kind whose xattrs are listed
    probeSecs = 8,        -- before the xattr walk is given up on
    -- ☁️ The same arithmetic 6.357.0 uses, and the same reason: a file
    -- with most of its bytes allocated is here, one with almost none is
    -- a placeholder. `smallest` exists because a 2 KB note fits inside a
    -- single 4 KB allocation unit, so the ratio says nothing about it.
    frac      = 0.9,
    smallest  = 64 * 1024,
    -- 🕵️ 6.368.0 — THE WATCH. 30 minutes is the store mirror's own
    -- cadence and it is chosen for the same reason: often enough that he
    -- hears about an offload the morning it happens, rare enough that a
    -- `find` over a cloud tree is not a thing his Mac is ever busy doing.
    watch      = true,
    sweepEvery = 1800,      -- seconds between sweeps
    firstSweep = 25,        -- after warm, so nothing at boot waits on find
    sweepSecs  = 180,       -- the killer timer: a big tree is slow
    parseMs    = 150,       -- past this the parse takes the 🔔 door
    maxTrack   = 60000,     -- paths remembered between sweeps
    tellEvery  = 900,       -- one on-screen alert per 15 min, at most
    ledgerMax  = 200,       -- offloads kept on disk
    -- state
    last      = nil,
    runs      = 0,
    sweeps     = 0,
    sweepFails = 0,
    sweepGen   = 0,
    sweepBusy  = false,
    sweepWhy   = nil,
    sweepTask  = nil,
    sweepKiller = nil,
    tickTimer  = nil,
    firstTimer = nil,
    noKiller   = 0,
    lastSweep  = nil,
    lastResult = nil,
    baseline   = nil,
    baselineAt = nil,
    offloads   = {},
    toldAt     = 0,
    storeRead  = false,
    xattrs    = nil,
    xattrWhy  = "the extended attributes have not been read yet",
    task      = nil,
    timer     = nil,
}
M.config = od
_G.oneDriveCheckCfg = od

-- ---- PURE: what a stat says about one file ------------------------------
-- 🔎 THREE ANSWERS, NEVER TWO (6.196.1). "it is here", "it is in the
-- cloud" and "this Mac would not say" are three different facts, and the
-- third is the one a report must never render as either of the others —
-- the whole point of the tool is telling him something he cannot see.
function od.fileState(size, blocks, frac, smallest)
    local s  = tonumber(size)
    local b  = tonumber(blocks)
    local fr = tonumber(frac) or 0.9
    local sm = tonumber(smallest) or 65536
    if not s then
        return "unknown", "this Mac would not say how big the file is"
    end
    if not b then
        -- Not a failure of the file: some filesystems do not report
        -- st_blocks at all, and saying "offloaded" there would accuse
        -- OneDrive of something the Mac never said.
        return "unknown", "this Mac does not report how much of it is stored locally"
    end
    local have = b * 512
    if s < sm then
        return "local", "small enough that the allocation says nothing — treated as here"
    end
    if have >= s * fr then
        return "local", "stored on this Mac"
    end
    return "cloud", "only " .. math.floor((have / s) * 100)
                    .. "% of its bytes are on this Mac — the rest is still in the cloud"
end

-- ---- PURE: the walk -----------------------------------------------------
-- 🔌 THE LISTER AND THE STAT ARE ARGUMENTS (6.230.0), so the whole walk
-- — the bounds, the ordering, the totals — is proven with no Mac and no
-- OneDrive. `lister(dir)` answers a list of {name, isDir}; `stat(path)`
-- answers {size, blocks}. Either may answer nil, and nil is a STATE.
function od.walk(roots, lister, stat, opts)
    opts = (type(opts) == "table") and opts or {}
    local maxFiles = math.max(1, math.floor(tonumber(opts.maxFiles) or 4000))
    local maxDepth = math.max(1, math.floor(tonumber(opts.maxDepth) or 6))
    local frac     = tonumber(opts.frac) or 0.9
    local smallest = tonumber(opts.smallest) or 65536

    local out = {
        files = 0, localN = 0, cloudN = 0, unknownN = 0,
        cloudBytes = 0, localBytes = 0,
        cloud = {},              -- the offloaded ones, biggest first
        unreadable = {},         -- folders that would not list
        capped = false, roots = {},
    }
    if type(roots) ~= "table" or type(lister) ~= "function"
       or type(stat) ~= "function" then
        return out
    end

    local seen = {}
    local function one(dir, depth)
        if out.capped then return end
        if depth > maxDepth then return end
        if seen[dir] then return end
        seen[dir] = true
        local entries = lister(dir)
        if type(entries) ~= "table" then
            out.unreadable[#out.unreadable + 1] = dir
            return
        end
        for _, e in ipairs(entries) do
            if out.capped then return end
            local name = tostring(e.name or "")
            -- 📏 A dot-folder is skipped: .trash holds his deleted notes
            -- (6.321.0) and nothing in it is live data he is waiting on.
            if name ~= "" and name ~= "." and name ~= ".."
               and name:sub(1, 1) ~= "." then
                local full = dir .. "/" .. name
                if e.isDir then
                    one(full, depth + 1)
                else
                    out.files = out.files + 1
                    if out.files > maxFiles then
                        out.files  = out.files - 1
                        out.capped = true
                        return
                    end
                    local a = stat(full)
                    local st, why = od.fileState(a and a.size, a and a.blocks,
                                                 frac, smallest)
                    if st == "local" then
                        out.localN = out.localN + 1
                        out.localBytes = out.localBytes + (tonumber(a and a.size) or 0)
                    elseif st == "cloud" then
                        out.cloudN = out.cloudN + 1
                        out.cloudBytes = out.cloudBytes + (tonumber(a and a.size) or 0)
                        out.cloud[#out.cloud + 1] = { path = full,
                                                      size = tonumber(a and a.size) or 0,
                                                      why = why }
                    else
                        out.unknownN = out.unknownN + 1
                    end
                end
            end
        end
    end

    for _, r in ipairs(roots) do
        if type(r) == "string" and r ~= "" then
            out.roots[#out.roots + 1] = r
            one(r, 1)
        end
    end
    -- Biggest first: the one that costs him most when it is not there.
    table.sort(out.cloud, function(x, y)
        if x.size ~= y.size then return x.size > y.size end
        return tostring(x.path) < tostring(y.path)
    end)
    return out
end

-- ---- PURE: the xattr names a probe found --------------------------------
-- 📣 It NEVER decides that a name means "pinned". It reports what macOS
-- keeps on a file that IS here beside what it keeps on one that is NOT,
-- and the DIFFERENCE between those two sets is the only thing that could
-- point at a pin. A guess here would be a feature built on a belief,
-- which is the mistake 6.233.0 exists to stop.
function od.xattrDiff(localNames, cloudNames)
    local function set(list)
        local s = {}
        for _, n in ipairs(type(list) == "table" and list or {}) do
            -- BOTH ends: `xattr -s` pads its "path: name" output, and a
            -- name trimmed on one side only makes " a" and "a" two
            -- different attributes — which would show a difference
            -- between a local file and a placeholder that is whitespace.
            n = tostring(n or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if n ~= "" then s[n] = true end
        end
        return s
    end
    local L, C = set(localNames), set(cloudNames)
    local both, onlyLocal, onlyCloud = {}, {}, {}
    for n in pairs(L) do
        if C[n] then both[#both + 1] = n else onlyLocal[#onlyLocal + 1] = n end
    end
    for n in pairs(C) do if not L[n] then onlyCloud[#onlyCloud + 1] = n end end
    table.sort(both) ; table.sort(onlyLocal) ; table.sort(onlyCloud)
    return { both = both, onlyLocal = onlyLocal, onlyCloud = onlyCloud }
end


-- ---- PURE: the argv one sweep runs ---------------------------------------
-- 🔑 6.368.0 — THE SWEEP IS OUT OF PROCESS, and that is forced rather
-- than preferred. 6.367.0's in-Lua walk stats every file ON THE MAIN
-- THREAD, which is the thread that draws his screen and reads his
-- keyboard (6.228.0) — and his own run stopped at the 4,000-file bound
-- with 821 offloaded files already found, so the number he was shown was
-- a floor over a fraction of the tree. `find` + `stat` in one hs.task
-- walks the WHOLE tree, touches no bytes, and costs the main thread
-- nothing but the parse.
--
-- 🚨 `-mindepth 1` IS LOAD-BEARING, not tidiness: without it the
-- `-name '.*'` test is applied to the ROOTS as well, so a root whose own
-- basename begins with a dot is pruned on sight and the sweep walks
-- nothing, finds nothing and reports a clean tree. That is 6.196.1's
-- exact failure — "there is nothing" printed where "I looked nowhere"
-- is the truth — in the one tool whose whole job is noticing an absence.
function od.findArgs(roots)
    local args, used = {}, {}
    for _, r in ipairs(type(roots) == "table" and roots or {}) do
        r = tostring(r or "")
        if r ~= "" and not used[r] then
            used[r] = true
            args[#args + 1] = r
        end
    end
    if #args == 0 then return nil, "no folder to watch" end
    local tail = { "-mindepth", "1", "-name", ".*", "-prune", "-o",
                   "-type", "f", "-exec", "/usr/bin/stat", "-f",
                   "%z %b %N", "{}", "+" }
    for _, a in ipairs(tail) do args[#args + 1] = a end
    return args
end

-- ---- PURE: what `stat -f '%z %b %N'` answered ----------------------------
-- 📏 THE PATH IS LAST ON PURPOSE. A file name may hold spaces, a newline
-- or a colon; a size and a block count may not. Anchoring the two numbers
-- at the START and taking everything after them as the path is the only
-- split that cannot be broken by one of his own file names (6.237.0 is
-- the same lesson about a name this config could not read).
--
-- 🔎 AND A LINE IT CANNOT PARSE IS COUNTED, never dropped. A parser that
-- silently eats what it does not understand reports a healthy tree over a
-- read that half failed, which is the one thing a watcher must not do.
function od.parseStat(text, opts)
    opts = (type(opts) == "table") and opts or {}
    local frac     = tonumber(opts.frac) or 0.9
    local smallest = tonumber(opts.smallest) or 65536
    local maxTrack = math.max(1, math.floor(tonumber(opts.maxTrack) or 60000))
    local out = { files = 0, localN = 0, cloudN = 0, unknownN = 0,
                  cloudBytes = 0, localBytes = 0, cloud = {},
                  localSet = {}, tracked = 0, capped = false, bad = 0 }
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        local s, b, p = line:match("^(%d+)%s+(%d+)%s+(.+)$")
        if p then
            out.files = out.files + 1
            -- 🔑 ONE RULE, TWO CALLERS (6.231.0): `od.fileState` decides
            -- here exactly as it decides in `od.walk`, so the sweep and
            -- the on-demand report can never disagree about one file.
            local st = od.fileState(tonumber(s), tonumber(b), frac, smallest)
            if st == "local" then
                out.localN = out.localN + 1
                out.localBytes = out.localBytes + (tonumber(s) or 0)
                if out.tracked < maxTrack then
                    out.localSet[p]  = true
                    out.tracked      = out.tracked + 1
                else
                    out.capped = true
                end
            elseif st == "cloud" then
                out.cloudN     = out.cloudN + 1
                out.cloudBytes = out.cloudBytes + (tonumber(s) or 0)
                out.cloud[#out.cloud + 1] = { path = p, size = tonumber(s) or 0 }
            else
                out.unknownN = out.unknownN + 1
            end
        elseif line:match("%S") then
            out.bad = out.bad + 1
        end
    end
    table.sort(out.cloud, function(x, y)
        if x.size ~= y.size then return x.size > y.size end
        return tostring(x.path) < tostring(y.path)
    end)
    return out
end

-- ---- PURE: what LEFT this Mac between two sweeps -------------------------
-- 🚨 THIS IS THE ONE QUESTION HE ASKED — "watching files that are
-- offloading to the cloud, as that is the most important aspect" — and it
-- is a DIFFERENT question from "what is in the cloud". His own report
-- already names 821 files that are not here; almost all of them have
-- never been here and are not news. A file that was HERE at the last
-- sweep and is in the cloud NOW is OneDrive taking something back, which
-- is the thing he cannot see and the thing "Always keep on device" was
-- supposed to prevent.
function od.offloaded(before, now)
    local out = {}
    if type(before) ~= "table" or type(now) ~= "table" then return out end
    for _, f in ipairs(now.cloud or {}) do
        if before[f.path] then
            out[#out + 1] = { path = f.path, size = tonumber(f.size) or 0 }
        end
    end
    table.sort(out, function(x, y)
        if x.size ~= y.size then return x.size > y.size end
        return tostring(x.path) < tostring(y.path)
    end)
    return out
end

-- ---- PURE: what a finished sweep means -----------------------------------
-- 🔎 FIVE ANSWERS, AND THE FIRST TWO ARE THE ONES THAT MATTER (6.196.1).
-- "nothing has left this Mac" and "I have nothing to compare against yet"
-- read identically from outside and are opposite facts: the first is
-- health, the second is a watcher that has run exactly once. A reload
-- throws the baseline away, so the second state is the ordinary morning
-- state and must never be rendered as the first.
function od.sweepVerdict(hadBaseline, offloads, capped)
    local n = (type(offloads) == "table") and #offloads or 0
    if not hadBaseline then
        return "baseline", "the first sweep — there was nothing to compare"
               .. " against yet, so nothing can be said about what left"
    end
    if n > 0 then
        return "left", n .. " file(s) were on this Mac at the last sweep"
               .. " and are back in the cloud now"
    end
    if capped then
        return "clean-capped", "nothing that is being tracked has left this"
               .. " Mac — but the tracking bound bit, so this covers only"
               .. " part of the tree"
    end
    return "clean", "nothing that was here has gone back to the cloud"
end

function M.setup(core)
    local function say(msg) if _G.diag and _G.diag.say then _G.diag.say(msg) end end

    local function mb(n)
        n = tonumber(n) or 0
        if n >= 1024 * 1024 * 1024 then
            return ("%.1f GB"):format(n / (1024 * 1024 * 1024))
        end
        if n >= 1024 * 1024 then return ("%.1f MB"):format(n / (1024 * 1024)) end
        if n >= 1024 then return ("%.0f KB"):format(n / 1024) end
        return tostring(math.floor(n)) .. " B"
    end

    -- 🗂 THE FOLDERS COME FROM THE MODULES THAT OWN THEM (6.257.0): the
    -- vault knows where the notes are, core knows where the Logs and the
    -- cloud root are. A copy of any of those here is a path that drifts
    -- the day one of them moves.
    function od.folders()
        if type(od.folderList) == "table" and #od.folderList > 0 then
            return od.folderList
        end
        local out, seen = {}, {}
        local function add(p)
            p = tostring(p or "")
            if p ~= "" and not seen[p] then seen[p] = true ; out[#out + 1] = p end
        end
        if _G.vault and type(_G.vault.dir) == "string" then add(_G.vault.dir) end
        add(core.logsDir)
        add(core.cloudDir)
        return out
    end

    local function lister(dir)
        local entries = nil
        local ok = pcall(function()
            if type(hs) ~= "table" or type(hs.fs) ~= "table"
               or type(hs.fs.dir) ~= "function" then return end
            local got = {}
            -- 🔬 `hs.fs.dir` RETURNS (iterator, state) and the iterator is
            -- called WITH that state, LuaFileSystem-style. A
            -- `pcall(hs.fs.dir, d)` keeps the iterator and THROWS THE
            -- STATE AWAY, which raises "directory metatable expected, got
            -- nil" at runtime and never at load. The generic `for`
            -- captures all three control values, which is why the pcall
            -- goes AROUND the loop and not around the call. hs-lint's
            -- `fs-dir-loses-state` rule is about exactly this.
            for name in hs.fs.dir(dir) do
                local full = dir .. "/" .. name
                local a = nil
                pcall(function() a = hs.fs.attributes(full, "mode") end)
                got[#got + 1] = { name = name, isDir = (a == "directory") }
            end
            entries = got
        end)
        if not ok then return nil end
        return entries
    end

    local function stat(path)
        local a = nil
        pcall(function() a = hs.fs.attributes(path) end)
        if type(a) ~= "table" then return nil end
        return { size = a.size, blocks = a.blocks }
    end

    -- ---- 6.368.0: THE WATCH ---------------------------------------------
    -- LL: "Watch OneDrive from its lowest level folder and give a screen
    -- report if it is not working watching files that are offloading to
    -- the cloud as that is the most important aspect."
    --
    -- 🔬 AND HIS OWN PROBE DECIDED THE SHAPE, which is what 6.367.0 was
    -- for. It asked macOS what it keeps on a local file and on a
    -- placeholder, and the answer was: `com.apple.macl` and
    -- `com.apple.provenance` on one, `com.apple.FinderInfo` on the other,
    -- and NOTHING in common. Not one File Provider attribute, not one
    -- OneDrive attribute, nothing that could be a pin. So "Always keep on
    -- device" is NOT readable from this side — which means a tool that
    -- asks whether a file is pinned cannot be built, and the only honest
    -- answer is to WATCH and notice when a file leaves. The measurement
    -- closed one road and chose the other; that is the whole reason
    -- 6.367.0 shipped a probe instead of a guess.
    -- 📏 IT DEGRADES, IT NEVER BREAKS: a core that cannot say where home
    -- is must not take the module down on its setup line. HOME, then a
    -- literal, then nothing — and with no home at all the ledger simply
    -- is not written, which the report already has a state for.
    local home = (type(core.homeDir) == "string" and core.homeDir ~= "" and core.homeDir)
                 or os.getenv("HOME") or ""
    od.storeDir  = home .. "/Library/Application Support/Hammerspoon/onedrive"
    od.storeFile = od.storeDir .. "/offloads.json"

    local function note(msg)
        if _G.diag and _G.diag.note then _G.diag.note("onedrive", msg) end
    end

    local function loadLedger()
        if od.storeRead then return end
        od.storeRead = true
        local f = io.open(od.storeFile, "r")
        if not f then return end
        local raw = nil
        pcall(function() raw = f:read("*a") ; f:close() end)
        if type(raw) ~= "string" or raw == "" then return end
        local ok, got = pcall(function() return hs.json.decode(raw) end)
        if ok and type(got) == "table" then
            local rows = {}
            for _, r in ipairs(got) do
                if type(r) == "table" and type(r.path) == "string" then
                    rows[#rows + 1] = { path = r.path,
                                        at   = tonumber(r.at) or 0,
                                        size = tonumber(r.size) or 0 }
                end
            end
            od.offloads = rows
        end
    end

    -- 🔒 TEMP FILE, THEN RENAME (6.313.0). This ledger is the only record
    -- of what left his Mac while he was not looking, so a write cut off
    -- half way must cost the WRITE and never the record.
    local function saveLedger()
        local rows = {}
        for i = 1, math.min(#od.offloads, tonumber(od.ledgerMax) or 200) do
            rows[#rows + 1] = od.offloads[i]
        end
        local ok, raw = pcall(function() return hs.json.encode(rows) end)
        if not (ok and type(raw) == "string") then return false end
        pcall(function() hs.fs.mkdir(od.storeDir) end)
        local tmp = od.storeFile .. ".tmp"
        local f = io.open(tmp, "w")
        if not f then return false end
        local wrote = pcall(function() f:write(raw) ; f:close() end)
        if not wrote then pcall(function() os.remove(tmp) end) ; return false end
        if not os.rename(tmp, od.storeFile) then
            pcall(function() os.remove(tmp) end)
            return false
        end
        return true
    end

    -- 🚪 ONE EXIT, AND IT CLEARS THE FLAG (6.304.0). `sweepBusy` stops two
    -- finds running over the same tree at once; a guard only a SUCCESS can
    -- release is a wedge, and the first sweep that could never finish
    -- would shut the watch down for the whole session, silently, while the
    -- timer went on ticking into the short-circuit.
    local function sweepEnd(gen, ok, why, res, ms)
        if gen ~= od.sweepGen then return end        -- a superseded run
        if not od.sweepBusy then return end
        od.sweepBusy = false
        if od.sweepKiller then
            pcall(function() od.sweepKiller:stop() end)
            od.sweepKiller = nil
        end
        od.sweepTask = nil
        od.lastSweep = { at = os.time(), ok = ok, why = why, ms = ms,
                         files = res and res.files or 0,
                         localN = res and res.localN or 0,
                         cloudN = res and res.cloudN or 0 }
        if not ok then
            od.sweepFails = (tonumber(od.sweepFails) or 0) + 1
            -- 📣 HIS "screen report if it is not working", exactly: the
            -- 🔔 door is an alert AND a ⚠️ Console line AND a ledger row,
            -- so a watcher that has stopped watching cannot be silent.
            core.degrade("OneDrive watch", tostring(why or "the sweep failed"))
            return
        end
        od.sweeps = (tonumber(od.sweeps) or 0) + 1
    end

    -- 📣 The offload alert. NOT the degrade door: a file leaving is the
    -- thing he asked to be told about, not a failure of this tool — and
    -- routing it through `degrade` would file his own OneDrive's behaviour
    -- in the "what broke today" log beside real faults.
    local function tellOffloads(list)
        local n = #list
        if n == 0 then return end
        local now = os.time()
        if now - (tonumber(od.toldAt) or 0) < (tonumber(od.tellEvery) or 900) then
            return
        end
        od.toldAt = now
        local first = list[1]
        local msg = "☁️ OneDrive took " .. n .. " file(s) back"
                    .. "\nbiggest: " .. tostring(first.path):match("[^/]+$")
                    .. "\n_G.oneDriveCheck() names them"
        pcall(function() hs.alert.show(msg, 6) end)
        print("⚠️ OneDrive watch: " .. n .. " file(s) that were on this Mac"
              .. " are back in the cloud — _G.oneDriveCheck() names them")
        if _G.notices and _G.notices.tell then
            pcall(_G.notices.tell, "OneDrive",
                  n .. " file(s) left this Mac", { key = "onedrive.offload" })
        end
    end

    function od.sweep(reason, onDone)
        loadLedger()
        if od.sweepBusy then
            if onDone then pcall(onDone, false, "a sweep is already running") end
            return false, "a sweep is already running"
        end
        local args, why = od.findArgs(od.folders())
        if not args then
            core.degrade("OneDrive watch", tostring(why or "no folder to watch"))
            if onDone then pcall(onDone, false, why) end
            return false, why
        end
        if type(hs) ~= "table" or type(hs.task) ~= "table" then
            core.degrade("OneDrive watch", "this Hammerspoon has no hs.task")
            if onDone then pcall(onDone, false, "no hs.task") end
            return false, "no hs.task"
        end
        od.sweepGen  = (tonumber(od.sweepGen) or 0) + 1
        local gen    = od.sweepGen
        od.sweepBusy = true
        od.sweepWhy  = tostring(reason or "asked")
        local began  = os.time()

        local t = hs.task.new("/usr/bin/find", function(code, out)
            -- `find` exits non-zero when a single folder refuses to be
            -- listed, and still prints everything it COULD walk. Throwing
            -- that away would turn one unreadable folder into a silent
            -- dead watcher, so a partial answer is used and SAID.
            local text = tostring(out or "")
            if code ~= 0 and text == "" then
                return sweepEnd(gen, false,
                                "find exited " .. tostring(code)
                                .. " and printed nothing", nil, nil)
            end
            local t0 = (hs.timer and hs.timer.secondsSinceEpoch
                        and hs.timer.secondsSinceEpoch()) or began
            local res = od.parseStat(text, { frac = od.frac,
                                             smallest = od.smallest,
                                             maxTrack = od.maxTrack })
            local t1 = (hs.timer and hs.timer.secondsSinceEpoch
                        and hs.timer.secondsSinceEpoch()) or began
            local ms = math.floor(((t1 - t0) * 1000) + 0.5)
            res.partial = (code ~= 0)
            local had = (type(od.baseline) == "table")
            local gone = had and od.offloaded(od.baseline, res) or {}
            local kind, kwhy = od.sweepVerdict(had, gone, res.capped)
            res.kind, res.kindWhy = kind, kwhy
            od.baseline   = res.localSet
            od.baselineAt = os.time()
            od.lastResult = res
            if #gone > 0 then
                local at = os.time()
                local add = {}
                for _, g in ipairs(gone) do
                    add[#add + 1] = { path = g.path, size = g.size, at = at }
                end
                for _, old in ipairs(od.offloads) do add[#add + 1] = old end
                od.offloads = add
                saveLedger()
                tellOffloads(gone)
            end
            sweepEnd(gen, true, nil, res, ms)
            -- ⏱ 6.228.0 — THE PARSE IS THE ONLY PART ON THE MAIN THREAD,
            -- so it is the only part that can cost him a dropped click.
            -- It is timed, and past the budget it says so with the number
            -- rather than leaving a stutter nobody can attribute.
            if ms > (tonumber(od.parseMs) or 150) then
                core.degrade("OneDrive watch",
                             "reading " .. res.files .. " file(s) back took "
                             .. ms .. " ms on the main thread")
            end
            if onDone then pcall(onDone, true, nil, res) end
        end, args)
        if not t then
            od.sweepBusy = false
            core.degrade("OneDrive watch", "macOS would not create the task")
            if onDone then pcall(onDone, false, "no task") end
            return false, "no task"
        end
        od.sweepTask = t
        -- 🛟 ARMED BEFORE THE ASK (6.246.0), in its own slot (6.196.1). A
        -- find over a cloud tree can be slow; one that never answers must
        -- not hold the flag for the rest of the session.
        if type(hs.timer) == "table" and type(hs.timer.doAfter) == "function" then
            od.sweepKiller = hs.timer.doAfter(tonumber(od.sweepSecs) or 180, function()
                pcall(function() if od.sweepTask then od.sweepTask:terminate() end end)
                sweepEnd(gen, false, "the sweep did not answer in "
                         .. tostring(od.sweepSecs or 180) .. " s", nil, nil)
            end)
        else
            od.noKiller = (tonumber(od.noKiller) or 0) + 1
        end
        if not t:start() then
            sweepEnd(gen, false, "macOS refused to start find", nil, nil)
            return false, "refused"
        end
        note("sweep started (" .. od.sweepWhy .. ")")
        return true
    end

    function od.startWatch()
        od.stopWatch()
        if od.watch == false then return false, "switched off" end
        if type(hs.timer) ~= "table" or type(hs.timer.doEvery) ~= "function" then
            core.degrade("OneDrive watch", "this Hammerspoon has no hs.timer")
            return false, "no hs.timer"
        end
        od.tickTimer = hs.timer.doEvery(tonumber(od.sweepEvery) or 1800, function()
            pcall(od.sweep, "the timer")
        end)
        od.firstTimer = hs.timer.doAfter(tonumber(od.firstSweep) or 25, function()
            pcall(od.sweep, "the first sweep after boot")
        end)
        return true
    end

    function od.stopWatch()
        if od.tickTimer then pcall(function() od.tickTimer:stop() end) end
        if od.firstTimer then pcall(function() od.firstTimer:stop() end) end
        od.tickTimer, od.firstTimer = nil, nil
    end
    _G.oneDriveSweep = function() return od.sweep("by hand") end

    function od.run()
        od.runs = (tonumber(od.runs) or 0) + 1
        local at = os.time()
        local r = od.walk(od.folders(), lister, stat, {
            maxFiles = od.maxFiles, maxDepth = od.maxDepth,
            frac = od.frac, smallest = od.smallest })
        r.at = at
        od.last = r
        return r
    end

    -- 🔬 THE PROBE, OFF THE MAIN THREAD. `xattr` lists an attribute's
    -- NAMES without reading the file's contents — so it cannot hydrate a
    -- placeholder — but it is still a process per file, so it is bounded
    -- and it runs in an hs.task with a killer timer beside it (6.170.1).
    -- Its answer is printed, never interpreted.
    function od.probe(paths, kind, onDone)
        if type(hs) ~= "table" or type(hs.task) ~= "table" then
            if onDone then onDone(nil, "this Hammerspoon has no hs.task") end
            return false
        end
        local args = { "-s" }        -- short: names only, never values
        local n = 0
        for _, p in ipairs(type(paths) == "table" and paths or {}) do
            if n >= (tonumber(od.probeMax) or 3) then break end
            args[#args + 1] = tostring(p) ; n = n + 1
        end
        if n == 0 then
            if onDone then onDone({}, "no " .. tostring(kind) .. " file to probe") end
            return false
        end
        local answered = false
        local function finish(names, why)
            if answered then return end
            answered = true
            if od.timer then pcall(function() od.timer:stop() end) ; od.timer = nil end
            od.task = nil
            if onDone then pcall(onDone, names, why) end
        end
        local t = hs.task.new("/usr/bin/xattr", function(code, out)
            if code ~= 0 then return finish(nil, "xattr exited " .. tostring(code)) end
            local names = {}
            for line in tostring(out or ""):gmatch("[^\r\n]+") do
                -- `xattr -s f1 f2` prints "<path>: <name>"; one file
                -- prints the bare name. Take whatever follows the colon,
                -- and the whole line when there is none.
                local name = line:match(":%s*([^:]+)$") or line
                name = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
                if name ~= "" then names[#names + 1] = name end
            end
            finish(names, nil)
        end, args)
        if not t then return finish(nil, "macOS would not create the task") end
        od.task = t
        -- 🛟 The belt is armed BEFORE the ask (6.246.0), in its own slot
        -- (6.196.1). A Mac that cannot arm one still probes, and the
        -- missing belt is said rather than assumed away.
        if type(hs.timer) == "table" and type(hs.timer.doAfter) == "function" then
            od.timer = hs.timer.doAfter(tonumber(od.probeSecs) or 8, function()
                pcall(function() if od.task then od.task:terminate() end end)
                finish(nil, "xattr did not answer in "
                       .. tostring(od.probeSecs or 8) .. " s")
            end)
        end
        local started = t:start()
        if not started then return finish(nil, "macOS refused to start xattr") end
        return true
    end

    -- ---- the report ------------------------------------------------------
    -- ⏱ Relative time, because "4 minutes ago" is the thing he can act
    -- on and a timestamp is a thing he has to subtract.
    local function ago(at)
        at = tonumber(at)
        if not at or at <= 0 then return "never" end
        local d = os.time() - at
        if d < 90 then return "just now" end
        if d < 5400 then return math.floor(d / 60) .. " minutes ago" end
        if d < 172800 then return math.floor(d / 3600) .. " hours ago" end
        return math.floor(d / 86400) .. " days ago"
    end

    _G.oneDriveCheck = function()
        local L = { "☁️ ONEDRIVE CHECK — is it really on this Mac?" }
        if type(hs) ~= "table" or type(hs.fs) ~= "table" then
            L[#L + 1] = "   ⚠️ this Hammerspoon has no hs.fs — nothing can be checked"
            print(table.concat(L, "\n"))
            return
        end
        loadLedger()
        L[#L + 1] = "   folders: " .. (#od.folders() > 0
                        and table.concat(od.folders(), "  ·  ")
                        or "⚠️ none — no vault, no Logs folder, no OneDrive")

        -- 🔎 FOUR STATES ON THE WATCH LINE, and the ⚠️ ones outrank the
        -- counts below them (6.196.1 · 6.260.0): a healthy-looking number
        -- printed over a watcher that has stopped is the exact failure
        -- this release exists to prevent.
        if od.watch == false then
            L[#L + 1] = "   watch  : OFF — settings = { onedrive_check = { watch = true } }"
                        .. " turns it back on"
        elseif not od.tickTimer then
            L[#L + 1] = "   watch  : ⚠️ WANTED but NOT RUNNING — nothing is watching for"
                        .. " files leaving this Mac"
        elseif not od.lastSweep then
            L[#L + 1] = "   watch  : every " .. math.floor((tonumber(od.sweepEvery) or 1800) / 60)
                        .. " min · ⏳ no sweep has finished yet (the first runs "
                        .. tostring(od.firstSweep) .. " s after boot)"
        else
            local ls = od.lastSweep
            L[#L + 1] = "   watch  : every " .. math.floor((tonumber(od.sweepEvery) or 1800) / 60)
                        .. " min · last sweep " .. ago(ls.at)
                        .. (ls.ok and (" — " .. ls.files .. " file(s) read back in "
                                       .. tostring(ls.ms or 0) .. " ms on the main thread")
                            or (" — ⚠️ FAILED: " .. tostring(ls.why)))
            if (tonumber(od.sweepFails) or 0) > 0 then
                L[#L + 1] = "   ↳ ⚠️ " .. od.sweepFails .. " sweep(s) have failed this session"
            end
            if (tonumber(od.noKiller) or 0) > 0 then
                L[#L + 1] = "   ↳ ⚠️ " .. od.noKiller .. " sweep(s) ran with NO killer timer"
                            .. " — this Mac would not arm one"
            end
        end

        -- The numbers, and WHERE THEY CAME FROM. The sweep walks the whole
        -- tree out of process; the on-demand walk is bounded and runs on
        -- the main thread. Those are different answers and the report must
        -- never let one wear the other's authority.
        local r, from = od.lastResult, nil
        if r then
            from = "the background sweep — the whole tree, "
                   .. (r.partial and "⚠️ PARTIAL (a folder refused to be listed)"
                       or "nothing skipped")
        else
            r = od.run()
            from = "an on-demand walk on the main thread, bounded at "
                   .. tostring(od.maxFiles) .. " file(s)"
        end
        L[#L + 1] = "   from   : " .. from
        L[#L + 1] = "   walked : " .. r.files .. " file(s)"
                    .. (r.capped and (" ⚠️ STOPPED AT THE " .. od.maxFiles
                        .. "-FILE BOUND — every number below is a FLOOR, not a total")
                        or "")
        L[#L + 1] = "   here   : " .. r.localN .. " file(s), " .. mb(r.localBytes)
        if r.cloudN > 0 then
            L[#L + 1] = "   ☁️ NOT HERE: " .. r.cloudN .. " file(s), " .. mb(r.cloudBytes)
                        .. " — these are placeholders, whatever Finder says about them"
            local shown = 0
            for _, f in ipairs(r.cloud) do
                if shown >= (tonumber(od.maxNamed) or 12) then
                    L[#L + 1] = "            … and " .. (r.cloudN - shown) .. " more"
                    break
                end
                shown = shown + 1
                L[#L + 1] = "            · " .. mb(f.size) .. "  " .. f.path
            end
            L[#L + 1] = "   ↳ to bring one back, open it ONCE in Finder — this tool"
            L[#L + 1] = "     never reads a file, because reading one downloads it and"
            L[#L + 1] = "     a download on the main thread is the 72-second freeze."
        else
            L[#L + 1] = "   ☁️ NOT HERE: none — every file walked has its bytes on this Mac"
        end

        -- 🚨 THE LINE HE ASKED FOR, and it is a DIFFERENT fact from the one
        -- above it. "in the cloud" counts 821 files, nearly all of which
        -- have never been here. "LEFT THIS MAC" counts the ones OneDrive
        -- took back after he had them — which is what "Always keep on
        -- device" was supposed to prevent and the only thing here that is
        -- news.
        if #od.offloads > 0 then
            L[#L + 1] = "   ☁️ LEFT THIS MAC: " .. #od.offloads
                        .. " file(s) — they were here at one sweep and in the cloud at the next"
            local shown = 0
            for _, f in ipairs(od.offloads) do
                if shown >= (tonumber(od.maxNamed) or 12) then
                    L[#L + 1] = "            … and " .. (#od.offloads - shown) .. " more"
                    break
                end
                shown = shown + 1
                L[#L + 1] = "            · " .. os.date("%Y-%m-%d %H:%M", f.at)
                            .. "  " .. mb(f.size) .. "  " .. f.path
            end
            L[#L + 1] = "   ↳ kept in " .. od.storeFile .. " (LOCAL — never OneDrive),"
            L[#L + 1] = "     so it survives a reload and is here in the morning."
        elseif type(od.baseline) ~= "table" then
            L[#L + 1] = "   ☁️ LEFT THIS MAC: ⏳ nothing to compare against yet — a"
                        .. " baseline is taken on the first sweep, and a reload starts over"
        else
            local kind = (od.lastResult and od.lastResult.kind) or "clean"
            L[#L + 1] = "   ☁️ LEFT THIS MAC: none"
                        .. (kind == "clean-capped"
                            and " that is being tracked — ⚠️ the "
                                .. tostring(od.maxTrack) .. "-path bound bit, so this"
                                .. " covers only part of the tree"
                            or " — nothing that was here has gone back to the cloud")
        end

        -- 🔬 THE PROBE'S ANSWER, printed and not interpreted.
        L[#L + 1] = "   pin    : " .. tostring(od.xattrWhy)
        if type(od.xattrs) == "table" then
            local d = od.xattrDiff(od.xattrs.localNames, od.xattrs.cloudNames)
            L[#L + 1] = "   ↳ on BOTH kinds : "
                        .. (#d.both > 0 and table.concat(d.both, " · ") or "(none)")
            L[#L + 1] = "   ↳ only on a file that IS here : "
                        .. (#d.onlyLocal > 0 and table.concat(d.onlyLocal, " · ") or "(none)")
            L[#L + 1] = "   ↳ only on a PLACEHOLDER        : "
                        .. (#d.onlyCloud > 0 and table.concat(d.onlyCloud, " · ") or "(none)")
            L[#L + 1] = "   ↳ MEASURED 2026-10-20 on his Mac: macl + provenance on a local"
            L[#L + 1] = "     file, FinderInfo on a placeholder, NOTHING in common and no"
            L[#L + 1] = "     File Provider attribute at all. \"Always keep on device\" is"
            L[#L + 1] = "     not readable from here, which is why this tool WATCHES."
        end
        -- 🚨 6.282.0 — A REPORT THAT RAISES IS EVERY ASK ANSWERED WITH
        -- NOTHING. `unreadable` is a field only the main-thread walk
        -- fills; the sweep's result has no such key, and `#nil` throws.
        if type(r.unreadable) == "table" and #r.unreadable > 0 then
            L[#L + 1] = "   ⚠️ could not LIST: " .. #r.unreadable .. " folder(s), first: "
                        .. tostring(r.unreadable[1])
        end
        if (tonumber(r.unknownN) or 0) > 0 then
            L[#L + 1] = "   ⚠️ could not tell: " .. r.unknownN .. " file(s) — this Mac"
                        .. " did not report how much of them is stored locally"
        end
        if (tonumber(r.bad) or 0) > 0 then
            L[#L + 1] = "   ⚠️ " .. r.bad .. " line(s) of the sweep could not be read"
        end
        print(table.concat(L, "\n"))
    end

    _G.oneDriveProbe = function()
        local r = od.last or od.run()
        local cloudPaths, localPaths = {}, {}
        for _, f in ipairs(r.cloud or {}) do cloudPaths[#cloudPaths + 1] = f.path end
        -- a handful of files that ARE here, for the other side of the
        -- comparison; without both sides the names mean nothing
        local roots = r.roots or {}
        if #roots > 0 then
            local got = lister(roots[1])
            for _, e in ipairs(type(got) == "table" and got or {}) do
                if not e.isDir and #localPaths < (tonumber(od.probeMax) or 3)
                   and tostring(e.name):sub(1, 1) ~= "." then
                    localPaths[#localPaths + 1] = roots[1] .. "/" .. e.name
                end
            end
        end
        od.probe(localPaths, "local", function(names, why)
            od.xattrs = od.xattrs or {}
            od.xattrs.localNames = names
            od.probe(cloudPaths, "cloud", function(cn, cw)
                od.xattrs.cloudNames = cn
                od.xattrWhy = (why or cw)
                    and ("⚠️ " .. tostring(why or cw))
                    or "read from this Mac — the names are below"
                pcall(_G.oneDriveCheck)
            end)
        end)
        print("☁️ asking macOS for the extended attributes… the report follows")
    end

    say("☁️ onedrive check 6.368.0 — watching " .. #od.folders()
        .. " folder(s) for files OneDrive takes back")
    return true
end

-- 🔌 6.228.0 — THE WATCH STARTS IN warm, NEVER IN setup. init.lua applies
-- a profile's `settings` AFTER setup returns, so anything started inside
-- setup can only ever be STOPPED by an override and never started: the
-- switch would be decorative in the useful direction. And there is
-- exactly ONE M.warm in this file, declared here — 6.308.0 is the release
-- where a module carrying both a top-level warm and one assigned inside
-- setup silently lost the top-level one, on every boot, for releases.
function M.warm()
    if type(od.startWatch) == "function" then pcall(od.startWatch) end
end

return M
