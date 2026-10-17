-- ☁️ ONEDRIVE CHECK — is the file really HERE? (6.367.0)
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
    summary = "☁️ onedrive_check — _G.oneDriveCheck() names every file whose"
              .. " bytes are not really on this Mac, however Finder marks it",
}
M.cheatsheet = {
    title = "☁️ ONEDRIVE CHECK (Console)",
    entries = {
        { "cloud check", "6.367.0: _G.oneDriveCheck() — walks the folders that hold your data and names every file whose BYTES are not on this Mac, however it is marked in Finder. It never reads a file: reading one downloads it, and that is the 72-second freeze" },
        { "probe",       "The same report prints the extended attributes macOS keeps on a local file and on an offloaded one, side by side — that comparison is what can say whether \"Always keep on device\" is readable at all" },
        { "folders",     "By default the Vault, the Logs folder and the OneDrive root. settings = { onedrive_check = { folders = { \"/full/path\" } } } names your own" },
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
    -- state
    last      = nil,
    runs      = 0,
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
    _G.oneDriveCheck = function()
        local L = { "☁️ ONEDRIVE CHECK — is it really on this Mac?" }
        if type(hs) ~= "table" or type(hs.fs) ~= "table" then
            L[#L + 1] = "   ⚠️ this Hammerspoon has no hs.fs — nothing can be checked"
            print(table.concat(L, "\n"))
            return
        end
        local r = od.run()
        L[#L + 1] = "   folders: " .. (#r.roots > 0 and table.concat(r.roots, "  ·  ")
                                       or "⚠️ none — no vault, no Logs folder, no OneDrive")
        L[#L + 1] = "   walked : " .. r.files .. " file(s)"
                    .. (r.capped and (" ⚠️ STOPPED AT THE " .. od.maxFiles
                        .. "-FILE BOUND — every number below is a FLOOR, not a total")
                        or "")
        L[#L + 1] = "   here   : " .. r.localN .. " file(s), " .. mb(r.localBytes)
        -- 🚨 THE LINE HE ASKED FOR.
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
        -- 🔎 "could not be asked" is its own fact and must never be
        -- rendered as "it is fine" (6.196.1).
        if r.unknownN > 0 then
            L[#L + 1] = "   ⚠️ could not tell: " .. r.unknownN .. " file(s) — this Mac"
                        .. " did not report how much of them is stored locally"
        end
        if #r.unreadable > 0 then
            L[#L + 1] = "   ⚠️ could not LIST: " .. #r.unreadable .. " folder(s), first: "
                        .. tostring(r.unreadable[1])
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
            L[#L + 1] = "   ↳ an attribute in one of those last two lines is what a"
            L[#L + 1] = "     \"keep on device\" flag would look like. Send them to me:"
            L[#L + 1] = "     nothing here decides what any of these names MEAN."
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

    say("☁️ onedrive check 6.367.0 — _G.oneDriveCheck() names every file"
        .. " whose bytes are not really here")
    return true
end

return M
