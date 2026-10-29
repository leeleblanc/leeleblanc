-- =====================================================================
-- test_onedrive_check.lua — ☁️ is the file really HERE?
-- =====================================================================
-- LL: "I'm finding that sometimes even with me marking OneDrive files to
-- 'Always keep on device' OneDrive will offload them."
--
-- The whole walk is driven with the lister and the stat handed IN
-- (6.230.0), so every bound, every state and every total is proven with
-- no Mac, no OneDrive and — the rule that matters most here — no file
-- ever read.
local HS = arg[1] or "."
local pass, fail = 0, 0
local failures = {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
        failures[#failures + 1] = label
            .. (extra ~= nil and ("  — " .. tostring(extra)) or "") end
end
local function out(s) io.write(tostring(s), "\n") end

-- ---- the smallest world the module touches ---------------------------
local TASKS = {}
local SAID  = {}
local ALERTS = {}
local EVERY  = {}          -- the repeating timers that were armed
local AFTER  = {}          -- the one-shot ones
local CLOCK  = 1000.5      -- 🕒 A FLOAT, because macOS's is (6.282.0)
local TASK_REFUSES = false
-- 🔬 A VIRTUAL DISK, because the ledger is temp-then-rename (6.313.0)
-- and a harness whose io.open always succeeds cannot drive the one
-- failure that matters: a write cut off half way.
local DISK, WRITE_REFUSES, RENAME_REFUSES, CLOSE_REFUSES = {}, false, false, false
-- 🗂 A TREE, because 6.380.0 asks whether a folder is really there
-- before it hands it to find. `FSMODE[path] = "directory"` is a folder on
-- this Mac; absent is a folder that is not. `FSLINK[path] = target` is a
-- symlink — the shape his ~/OneDrive had in 6.230.0.
local FSMODE, FSLINK = {}, {}
local realOpen, realRename, realRemove = io.open, os.rename, os.remove
io.open = function(path, mode)
    if (mode or "r"):find("w") then
        if WRITE_REFUSES then return nil, "refused" end
        -- 🔬 6.290.0 — AND IT TRUNCATES ON OPEN, because a real one does.
        -- `io.open(path, "w")` empties the file BEFORE a byte is written,
        -- which is the entire reason temp-then-rename exists (6.313.0).
        -- A harness that only empties it on a SUCCESSFUL close leaves the
        -- one failure that matters unreachable, and certifies the bug.
        DISK[path] = ""
        local buf = {}
        return { write = function(_, t) buf[#buf + 1] = tostring(t) end,
                 -- a disk that fills MID-WRITE: the open already emptied
                 -- the file, and the close is where it is noticed.
                 close = function()
                     if CLOSE_REFUSES then error("no space left on device", 0) end
                     DISK[path] = table.concat(buf)
                 end,
                 read  = function() return nil end }
    end
    local held = DISK[path]
    if held == nil then return nil, "no such file" end
    return { read = function(_, _) return held end, close = function() end }
end
os.rename = function(a, b)
    if RENAME_REFUSES then return nil, "refused" end
    if DISK[a] == nil then return nil, "no such file" end
    DISK[b], DISK[a] = DISK[a], nil
    return true
end
os.remove = function(a) DISK[a] = nil ; return true end
hs = {
    fs = { attributes = function(p, key)
               -- 🔬 6.290.0, THIRTEENTH TIME — AND THIS ONE CERTIFIED THE
               -- BUG. The stub answered nil for EVERY path, which is a Mac
               -- with no filesystem at all, so 6.380.0's "is this folder
               -- actually on this Mac?" test could not exist in the gate:
               -- a folders() that skipped the check entirely would pass
               -- every check in this file. The real one answers
               -- "directory" for a folder, and so does this.
               local mode = FSMODE[tostring(p)]
               if mode == nil then return nil end
               if key == "mode" then return mode end
               return { mode = mode }
           end,
           -- 🔗 AND A LINK ANSWERS ABOUT THE LINK, not its target — the
           -- distinction 6.230.0 rests on. `attributes` FOLLOWS a link,
           -- which is why ~/OneDrive read as an ordinary folder and one
           -- tree was watched twice.
           symlinkAttributes = function(p, key)
               local tgt = FSLINK[tostring(p)]
               if tgt == nil then return nil end
               if key == "target" then return tgt end
               if key == "mode" then return "link" end
               return { mode = "link", target = tgt }
           end,
           pathToAbsolutePath = function(p)
               return FSLINK[tostring(p)] or tostring(p)
           end,
           dir = function() return function() return nil end end,
           mkdir = function() return true end },
    task = { new = function(bin, cb, args)
        if TASK_REFUSES then return nil end
        local t = { bin = bin, cb = cb, args = args, started = false }
        function t:start() self.started = true ; TASKS[#TASKS + 1] = self ; return true end
        function t:terminate() self.killed = true end
        return t
    end },
    timer = {
        doAfter = function(secs, fn)
            local t = { stop = function(self) self.stopped = true end, fire = fn, secs = secs }
            AFTER[#AFTER + 1] = t ; return t
        end,
        doEvery = function(secs, fn)
            local t = { stop = function(self) self.stopped = true end, fire = fn, secs = secs }
            EVERY[#EVERY + 1] = t ; return t
        end,
        secondsSinceEpoch = function() return CLOCK end,
    },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    json = {
        -- enough of a round trip for a list of flat rows, and it RAISES
        -- on a non-table exactly as LuaSkin does (6.345.0).
        encode = function(t)
            assert(type(t) == "table", "hs.json.encode takes a table")
            local parts = {}
            for _, r in ipairs(t) do
                parts[#parts + 1] = ("{\"path\":%q,\"at\":%d,\"size\":%d}")
                                    :format(r.path, math.floor(r.at or 0),
                                            math.floor(r.size or 0))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end,
        decode = function(raw)
            local rows = {}
            for path, at, size in tostring(raw):gmatch('{"path":"(.-)","at":(%d+),"size":(%d+)}') do
                rows[#rows + 1] = { path = path, at = tonumber(at), size = tonumber(size) }
            end
            return rows
        end,
    },
}
local DEGRADES = {}
local TOLD = {}
_G.notices = { tell = function(a, b) TOLD[#TOLD + 1] = tostring(a) .. ": " .. tostring(b) end }
_G.diag = { say = function(m) SAID[#SAID + 1] = m end, warn = function() end,
            note = function() end }

local M = dofile(HS .. "/modules/onedrive_check.lua")
local od = M.config

-- =====================================================================
-- §1 — ONE FILE, THREE ANSWERS
-- =====================================================================
out("\n§1 what a stat says about one file\n")
do
    local st, why = od.fileState(100 * 1024 * 1024, (100 * 1024 * 1024) / 512)
    check("☁️ every block allocated = it is HERE", st == "local", st .. " / " .. why)

    st, why = od.fileState(100 * 1024 * 1024, 8)
    check("☁️ the full size with almost nothing allocated = a PLACEHOLDER",
          st == "cloud", st .. " / " .. why)
    check("…and it says what fraction is really here", why:find("%%") ~= nil, why)

    -- 🔎 THREE STATES, NEVER TWO (6.196.1). "this Mac would not say" must
    -- not render as "it is fine" — the whole point of the tool is telling
    -- him something he cannot see, and a confident wrong answer is worse
    -- than none.
    st = od.fileState(100 * 1024 * 1024, nil)
    check("🔎 no `blocks` at all is UNKNOWN, never 'offloaded'", st == "unknown", st)
    st = od.fileState(nil, 8)
    check("🔎 no `size` at all is UNKNOWN too", st == "unknown", st)

    -- 🚨 THE FIXTURE THAT BITES. A small file fits inside one allocation
    -- unit, so the ratio says nothing about it — without the floor every
    -- note in his vault would be reported as offloaded, which is a tool
    -- he would switch off on its first run (6.269.0).
    st = od.fileState(2 * 1024, 8)
    check("🚨 a 2 KB note is HERE — below the floor the ratio means nothing",
          st == "local", st)
    st = od.fileState(1024 * 1024, 8)
    check("…but a 1 MB file with 4 KB allocated is a placeholder", st == "cloud", st)

    -- the boundary itself, both sides
    local big = od.smallest * 4
    check("exactly at the fraction it reads as HERE",
          od.fileState(big, (big * od.frac) / 512) == "local")
    check("just under it, it does not", od.fileState(big, (big * 0.5) / 512) == "cloud")
end

-- =====================================================================
-- §2 — THE WALK
-- =====================================================================
out("\n§2 the walk, its bounds and its states\n")
do
    local TREE = {
        ["/v"]       = { { name = "a.md", isDir = false },
                         { name = "sub",  isDir = true },
                         { name = ".trash", isDir = true } },
        ["/v/sub"]   = { { name = "b.mp4", isDir = false },
                         { name = "c.mp4", isDir = false } },
        ["/v/.trash"] = { { name = "gone.md", isDir = false } },
    }
    local STAT = {
        ["/v/a.md"]     = { size = 2048, blocks = 8 },
        ["/v/sub/b.mp4"] = { size = 2000 * 1024 * 1024, blocks = 16 },
        ["/v/sub/c.mp4"] = { size = 700 * 1024 * 1024,
                             blocks = (700 * 1024 * 1024) / 512 },
        ["/v/.trash/gone.md"] = { size = 900 * 1024 * 1024, blocks = 8 },
    }
    local lister = function(d) return TREE[d] end
    local stat   = function(p) return STAT[p] end

    local r = od.walk({ "/v" }, lister, stat, { smallest = od.smallest, frac = od.frac })
    check("☁️ it walks into sub-folders", r.files == 3, r.files)
    check("☁️ …and names the one placeholder", r.cloudN == 1
          and r.cloud[1] and r.cloud[1].path == "/v/sub/b.mp4",
          r.cloudN .. " / " .. tostring(r.cloud[1] and r.cloud[1].path))
    check("☁️ …and counts the two that are here", r.localN == 2, r.localN)
    -- 🗑 .trash holds his DELETED notes (6.321.0) — nothing in it is live
    -- data he is waiting on, and reporting it would bury the files that
    -- are.
    check("🗑 a dot-folder is skipped, so the bin is not reported",
          r.files == 3 and r.cloudN == 1, r.files)

    -- biggest first: the one that costs him most when it is not there
    local STAT2 = {
        ["/v/a.md"]      = { size = 900 * 1024 * 1024, blocks = 8 },
        ["/v/sub/b.mp4"] = { size = 2000 * 1024 * 1024, blocks = 16 },
        ["/v/sub/c.mp4"] = { size = 100 * 1024 * 1024, blocks = 8 },
    }
    local r2 = od.walk({ "/v" }, lister, function(p) return STAT2[p] end, {})
    check("☁️ the offloaded ones are listed BIGGEST first",
          r2.cloud[1].path == "/v/sub/b.mp4" and r2.cloud[3].path == "/v/sub/c.mp4",
          r2.cloud[1].path .. " … " .. r2.cloud[3].path)

    -- 📏 A BOUND IS A STATE (6.197.2), never a footnote: a count taken
    -- under one is a FLOOR, and a fixture whose wanted rows come first
    -- proves the caveat exists rather than that it BITES.
    local r3 = od.walk({ "/v" }, lister, stat, { maxFiles = 2 })
    check("📏 the file bound BITES and says so", r3.capped == true and r3.files == 2,
          tostring(r3.capped) .. " / " .. r3.files)
    local r4 = od.walk({ "/v" }, lister, stat, { maxDepth = 1 })
    check("📏 the depth bound BITES — the sub-folder is not walked",
          r4.files == 1, r4.files)

    -- a folder that will not list is its own fact
    local r5 = od.walk({ "/nope" }, function() return nil end, stat, {})
    check("⚠️ a folder that cannot be listed is NAMED, not counted as empty",
          #r5.unreadable == 1 and r5.files == 0, #r5.unreadable)

    -- a file the Mac will not stat
    local r6 = od.walk({ "/v" }, lister, function() return nil end, {})
    check("⚠️ a file that cannot be stat'd is UNKNOWN, not 'here'",
          r6.unknownN == 3 and r6.localN == 0 and r6.cloudN == 0,
          r6.unknownN)

    -- a loop cannot hang it
    local LOOP = { ["/l"] = { { name = "x", isDir = true } },
                   ["/l/x"] = { { name = "..", isDir = true } } }
    local r7 = od.walk({ "/l" }, function(d) return LOOP[d] end, stat, {})
    check("a folder that points back at itself does not hang the walk",
          type(r7) == "table")

    check("nothing at all answers an empty result rather than throwing",
          od.walk(nil, nil, nil, {}).files == 0)
end

-- =====================================================================
-- §3 — THE XATTR COMPARISON
-- =====================================================================
out("\n§3 the probe reports, and decides nothing\n")
do
    local d = od.xattrDiff({ "com.apple.quarantine", "com.apple.fileprovider.X" },
                           { "com.apple.quarantine", "com.apple.fileprovider.Y" })
    check("🔬 it names what BOTH kinds carry", #d.both == 1
          and d.both[1] == "com.apple.quarantine", table.concat(d.both, ","))
    check("🔬 …what only a file that IS here carries",
          #d.onlyLocal == 1 and d.onlyLocal[1] == "com.apple.fileprovider.X",
          table.concat(d.onlyLocal, ","))
    check("🔬 …and what only a PLACEHOLDER carries",
          #d.onlyCloud == 1 and d.onlyCloud[1] == "com.apple.fileprovider.Y",
          table.concat(d.onlyCloud, ","))
    local e = od.xattrDiff(nil, nil)
    check("nothing on either side answers three empty lists rather than throwing",
          #e.both == 0 and #e.onlyLocal == 0 and #e.onlyCloud == 0)
    local f = od.xattrDiff({ "a", "a", " a " }, {})
    check("the same name twice is one name, trimmed", #f.onlyLocal == 1,
          table.concat(f.onlyLocal, ","))
end

-- =====================================================================
-- §4 — 🚨 IT MUST NEVER READ A FILE
-- =====================================================================
out("\n§4 the rule this module cannot break\n")
do
    -- Reading a placeholder HYDRATES it, a hydration is a download, and
    -- a download on the main thread is the 72-second freeze the stall
    -- guard killed on 2026-10-12 (6.357.0 · 6.228.0). A functional check
    -- cannot see this — the module is CORRECT today and the next edit is
    -- what adds the read — so it is asserted against the SOURCE.
    -- 🚨 AND IT READS THE SOURCE THROUGH THE REAL io.open, not the
    -- virtual disk this suite installs. 6.313.0 is the release where a
    -- sentry read its haystack through a STUBBED opener, got nil, and
    -- went green while measuring nothing.
    local f = assert(realOpen(HS .. "/modules/onedrive_check.lua", "r"))
    local src = f:read("a") ; f:close()
    check("the sentry read something — a sentry over an empty haystack is"
          .. " green and measures nothing (6.313.0)", #src > 2000, #src)
    -- comments are stripped first, because the comments here QUOTE the
    -- calls they forbid in order to explain the rule (6.262.0 · 6.280.0)
    local code = src:gsub("%-%-[^\n]*", "")
    -- 🔒 6.368.0 — THE SENTRY ASKS THE RULE, NOT A NAME. It used to ban
    -- the word `io.open` outright, which was exactly right while nothing
    -- in this file could legitimately open anything — and exactly wrong
    -- the day the offload ledger needed writing. 6.321.0 is the same
    -- lesson about `os.remove` in the vault: a sentry that bans a NAME
    -- expires the first time the name has an honest use; one that states
    -- the RULE does not. The rule is that the only file this module ever
    -- opens is ITS OWN LEDGER — never a file in the tree it is watching,
    -- because opening one of those downloads it.
    local opens, store = 0, 0
    for line in code:gmatch("[^\n]+") do
        if line:find("io%.open") then
            opens = opens + 1
            if line:find("od%.storeFile") or line:find("tmp") then store = store + 1 end
        end
    end
    check("🚨 every io.open in this module is its own ledger, never a watched file",
          opens > 0 and opens == store, opens .. " open(s), " .. store .. " on the ledger")
    check("…and there really are some to check — never an empty haystack",
          opens >= 2, opens)
    check("🚨 the only :read( is the ledger's own", select(2, code:gsub(":read%(", "")) <= 1,
          select(2, code:gsub(":read%(", "")))
    check("🚨 …and it does not shell out to a file's contents either",
          code:find("/bin/cat") == nil and code:find("io%.lines") == nil)
    -- 🔑 the ledger is LOCAL on purpose: a record of what OneDrive took
    -- back must not itself be a file OneDrive can take back.
    check("🔑 the ledger lives in Application Support, never in OneDrive",
          code:find("Application Support/Hammerspoon/onedrive", 1, true) ~= nil
          and code:find('storeDir  = core%.cloudDir') == nil)
    -- and the comment explaining WHY is still there, so the sentry cannot
    -- be satisfied by deleting the explanation
    check("…and the reason is still written down beside the rule",
          src:find("hydrat", 1, true) ~= nil)
    -- 🔬 `hs.fs.dir` returns (iterator, state) and a pcall around the CALL
    -- throws the state away — "directory metatable expected, got nil" at
    -- runtime, never at load (the 6.311.0 install failure).
    check("🔬 the directory walk keeps hs.fs.dir's state — the pcall goes"
          .. " AROUND the loop, never around the call",
          code:find("pcall%(hs%.fs%.dir") == nil
          and code:find("for name in hs%.fs%.dir") ~= nil)
end

-- =====================================================================
-- §5 — THE PROBE'S OWN FAILURES
-- =====================================================================
out("\n§5 the probe, and every way it can fail\n")
do
    -- 🔬 6.339.0 / 6.278.0 — THE STUB CARRIES `degrade` BECAUSE THE REAL
    -- CORE TABLE DOES. A core stub missing it sends every module under
    -- test down its no-door fallback, so the one channel this release
    -- exists to use is never exercised.
    -- 🔬 AND IT REPRODUCES HIS GEOMETRY, which is the whole shape of the
    -- bug 6.380.0 fixes. On his Mac `logsDir` IS `<cloud>/Logs` and the
    -- vault IS `<cloud>/Vault` — so two of the old three roots were INSIDE
    -- the third. A stub putting the Logs folder at "/logs", outside the
    -- cloud root, cannot see that containment at all: the rule would be
    -- proven in §7c and the path that actually assembles the list would
    -- never meet the case (6.290.0 — a harness gentler than the world).
    _G.vault = { dir = "/cloud/Vault" }
    local CORE = { logsDir = "/cloud/Logs", cloudDir = "/cloud", homeDir = "/home",
                   provide = function() end, hyperAddShortcut = function() end,
                   degrade = function(tool, why)
                       DEGRADES[#DEGRADES + 1] = tostring(tool) .. ": " .. tostring(why)
                       return false, why
                   end }
    M.setup(CORE)

    check("☁️ the report global exists", type(_G.oneDriveCheck) == "function")
    check("☁️ …and so does the probe", type(_G.oneDriveProbe) == "function")

    -- it never probes with nothing
    local gotWhy = nil
    od.probe({}, "cloud", function(_, why) gotWhy = why end)
    check("a probe with no file to look at says so rather than running xattr",
          tostring(gotWhy):find("no cloud file", 1, true) ~= nil, tostring(gotWhy))

    -- it asks for NAMES only: a value could be anything, including the
    -- file's own bytes on some providers
    TASKS = {}
    od.probe({ "/v/a.md" }, "local", function() end)
    check("🔬 xattr is asked for NAMES only, never values",
          TASKS[1] and TASKS[1].args[1] == "-s",
          TASKS[1] and TASKS[1].args[1])
    check("…and it is the absolute binary, never a bare name (6.208.0)",
          TASKS[1] and TASKS[1].bin == "/usr/bin/xattr", TASKS[1] and TASKS[1].bin)

    -- 🚨 CREATED AND THEN REFUSING TO START is the shape this Mac keeps
    -- meeting (6.265.0, fifth time) — different from "could not create".
    local realNew = hs.task.new
    hs.task.new = function(bin, cb, args)
        local t = { bin = bin, cb = cb, args = args }
        function t:start() return false end
        function t:terminate() end
        return t
    end
    local why2 = nil
    od.probe({ "/v/a.md" }, "local", function(_, w) why2 = w end)
    check("🚨 a task that is CREATED and then REFUSES to start is caught",
          tostring(why2):find("refused to start", 1, true) ~= nil, tostring(why2))

    hs.task.new = function() return nil end
    local why3 = nil
    od.probe({ "/v/a.md" }, "local", function(_, w) why3 = w end)
    check("…and one macOS will not create at all is a DIFFERENT message",
          tostring(why3):find("would not create", 1, true) ~= nil, tostring(why3))
    hs.task.new = realNew

    -- no hs.task at all
    local keptTask = hs.task
    hs.task = nil
    local why4 = nil
    od.probe({ "/v/a.md" }, "local", function(_, w) why4 = w end)
    check("a Hammerspoon with no hs.task degrades and SAYS so",
          tostring(why4):find("no hs.task", 1, true) ~= nil, tostring(why4))
    hs.task = keptTask

    -- the belt, and the answer it gives
    TASKS = {}
    local armed = nil
    local keptTimer = hs.timer.doAfter
    hs.timer.doAfter = function(secs, fn)
        armed = { secs = secs, fn = fn }
        return { stop = function() end }
    end
    local why5 = nil
    od.probe({ "/v/a.md" }, "local", function(_, w) why5 = w end)
    check("🛟 a belt is armed BEFORE the ask (6.246.0)",
          armed ~= nil and TASKS[1] ~= nil, tostring(armed ~= nil))
    armed.fn()
    check("🛟 …and firing it ends the probe with a reason, not a silence",
          tostring(why5):find("did not answer", 1, true) ~= nil, tostring(why5))
    check("🛟 …and it KILLED the process it gave up on",
          TASKS[1] and TASKS[1].killed == true, tostring(TASKS[1] and TASKS[1].killed))

    -- 🚨 EXACTLY ONCE, through one door (6.299.0): the belt fired, so the
    -- real callback arriving late must change nothing.
    local calls = 0
    local why6 = nil
    hs.timer.doAfter = function(_, fn) armed = { fn = fn } ; return { stop = function() end } end
    TASKS = {}
    od.probe({ "/v/a.md" }, "local", function(_, w) calls = calls + 1 ; why6 = w end)
    armed.fn()
    TASKS[1].cb(0, "com.apple.quarantine")
    check("🚨 a late answer after the belt fired is DROPPED — answered once",
          calls == 1 and tostring(why6):find("did not answer", 1, true) ~= nil, calls)
    hs.timer.doAfter = keptTimer

    -- a real answer, parsed
    TASKS = {}
    local names = nil
    od.probe({ "/v/a.md", "/v/b.md" }, "local", function(n) names = n end)
    TASKS[1].cb(0, "/v/a.md: com.apple.quarantine\n/v/b.md: com.apple.fileprovider.pin\n")
    check("🔬 the names are read out of xattr's own 'path: name' output",
          type(names) == "table" and #names == 2
          and names[1] == "com.apple.quarantine"
          and names[2] == "com.apple.fileprovider.pin",
          type(names) == "table" and table.concat(names, ",") or tostring(names))

    TASKS = {}
    local why7 = nil
    od.probe({ "/v/a.md" }, "local", function(_, w) why7 = w end)
    TASKS[1].cb(1, "")
    check("a non-zero exit is a reason, never an empty list of names",
          tostring(why7):find("exited 1", 1, true) ~= nil, tostring(why7))
end

-- =====================================================================
-- §6 — THE REPORT
-- =====================================================================
out("\n§6 the report, and the states it must keep apart\n")
do
    local function reportText()
        local cap, saved = {}, print
        print = function(...) local q = {}
            for i = 1, select("#", ...) do q[#q + 1] = tostring((select(i, ...))) end
            cap[#cap + 1] = table.concat(q, " ") end
        pcall(_G.oneDriveCheck) ; print = saved
        return table.concat(cap, "\n")
    end

    od.last, od.xattrs = nil, nil
    od.xattrWhy = "the extended attributes have not been read yet"
    local r = reportText()
    check("🔎 with nothing offloaded it SAYS so rather than printing nothing",
          r:find("NOT HERE: none", 1, true) ~= nil, r:sub(1, 120))
    check("🔎 …and it names the folders it walked", r:find("folders:", 1, true) ~= nil)
    check("🔎 …and says the pin has not been read yet, never that there is none",
          r:find("have not been read yet", 1, true) ~= nil)

    -- with a placeholder found
    od.folderList, od.roots = { "/v" }, nil
    local TREE = { ["/v"] = { { name = "film.mp4", isDir = false } } }
    local realDir, realAttr = hs.fs.dir, hs.fs.attributes
    hs.fs.dir = function(d)
        local i, list = 0, TREE[d] or {}
        return function() i = i + 1 ; return list[i] and list[i].name or nil end
    end
    hs.fs.attributes = function(p, kind)
        -- 📏 6.380.0 — THE FOLDER HAS TO BE A FOLDER. The plan stats each
        -- candidate before handing it to find, so a stub that calls every
        -- path a "file" drops the root and the walk finds nothing — which
        -- is the harness, not the code, and is exactly 6.290.0's shape.
        if kind == "mode" then return (p == "/v") and "directory" or "file" end
        if p == "/v/film.mp4" then return { size = 2000 * 1024 * 1024, blocks = 16 } end
        return nil
    end
    local r2 = reportText()
    check("☁️ a placeholder is NAMED, with its size",
          r2:find("/v/film.mp4", 1, true) ~= nil and r2:find("NOT HERE: 1", 1, true) ~= nil,
          r2:sub(1, 200))
    check("☁️ …and the report says how to bring it back WITHOUT this tool reading it",
          r2:find("never reads a file", 1, true) ~= nil)

    -- the xattr block prints both sides and interprets neither
    od.xattrs = { localNames = { "com.apple.quarantine" },
                  cloudNames = { "com.apple.quarantine", "com.apple.fileprovider.unpin" } }
    od.xattrWhy = "read from this Mac — the names are below"
    local r3 = reportText()
    check("🔬 the report prints both sides of the comparison",
          r3:find("only on a PLACEHOLDER", 1, true) ~= nil
          and r3:find("com.apple.fileprovider.unpin", 1, true) ~= nil, r3:sub(-300))
    -- 🔑 6.368.0 — THE CHECK ASKS THE RULE, NOT THE SENTENCE (6.248.0).
    -- 6.367.0's report hedged ("nothing here decides what a name means")
    -- because the question was open. His probe ANSWERED it — macl and
    -- provenance on a local file, FinderInfo on a placeholder, nothing in
    -- common and no File Provider attribute anywhere — so the report now
    -- states the measurement and says what it decided. What must stay
    -- true either way is that it never claims a given name IS a pin.
    check("🔬 the report states the measurement rather than guessing at a pin",
          r3:find("not readable from here", 1, true) ~= nil
          and r3:find("MEASURED", 1, true) ~= nil, r3:sub(-400))
    check("🔬 …and never calls any attribute a pin",
          r3:find("is the pin", 1, true) == nil
          and r3:find("pinned by", 1, true) == nil)
    hs.fs.dir, hs.fs.attributes = realDir, realAttr
    od.folderList, od.roots = nil, nil

    -- no hs.fs at all
    local keptFs = hs.fs
    hs.fs = nil
    local r4 = reportText()
    check("a Hammerspoon with no hs.fs says so and checks nothing",
          r4:find("no hs.fs", 1, true) ~= nil, r4:sub(1, 120))
    hs.fs = keptFs
end

-- =====================================================================
-- §7 — THE ARGV ONE SWEEP RUNS
-- =====================================================================
out("\n§7 the find ONE TURN runs, and the prunes that must not eat a root\n")
do
    local a = od.findArgs("/cloud/Vault")
    check("the ONE root comes first", a[1] == "/cloud/Vault", tostring(a[1]))
    local joined = table.concat(a, " ")
    check("it asks for FILES only", joined:find("-type f", 1, true) ~= nil, joined)
    check("…and stats them in ONE child, not one per file",
          joined:find("{} +", 1, true) ~= nil, joined)
    check("…for size, blocks and the path, the PATH LAST",
          joined:find("%z %b %N", 1, true) ~= nil, joined)
    check("…through the absolute binary, never a bare name (6.208.0)",
          joined:find("/usr/bin/stat", 1, true) ~= nil, joined)

    -- 🚨 THE FIXTURE THAT BITES, and nothing else does. `-name '.*'
    -- -prune` is right for everything INSIDE the tree and lethal at the
    -- top: without -mindepth 1 find tests the ROOT too, so a root whose
    -- own basename begins with a dot is pruned on sight, the turn walks
    -- nothing, and the report says the folder is clean. Every other root
    -- agrees with both implementations (6.230.0).
    local dotRoot = od.findArgs("/home/.hammerspoon")
    local dj = table.concat(dotRoot, " ")
    check("🚨 -mindepth 1 keeps the prune off the ROOT itself",
          dj:find("-mindepth 1", 1, true) ~= nil
          and dj:find("-mindepth 1") < (dj:find("-name") or 1e9), dj)
    check("…and dot-folders INSIDE the tree are still pruned",
          dj:find("-name .*", 1, true) ~= nil
          and dj:find(") -prune", 1, true) ~= nil, dj)

    -- 📏 6.380.0 — APPLE'S LIBRARY BUNDLES. His Music folder can hold a
    -- `*.musiclibrary` or a `*.photoslibrary`: ONE document holding tens
    -- of thousands of files, not one of which any OneDrive can offload.
    -- Walking one would spend the whole budget this release exists to
    -- fix, on files whose answer is known before the walk starts.
    check("🎬 the library bundles are pruned by name",
          joined:find("-name *.photoslibrary", 1, true) ~= nil
          and joined:find("-name *.musiclibrary", 1, true) ~= nil, joined)
    -- 🚨 AND Media.localized IS NOT PRUNED, deliberately: that is where
    -- his actual music FILES live, and pruning it to go faster would
    -- blind the tool to the very thing he asked it to watch. Asserted so
    -- that a later "make it faster" cannot quietly add it.
    check("🚨 …but Media.localized is NOT — that is where the music is",
          joined:find("Media.localized", 1, true) == nil, joined)

    -- 🔬 THE PARENTHESES MUST BE BARE. In a shell they need escaping
    -- because the SHELL eats them; hs.task execs find directly, so a
    -- `\\(` would reach find as a literal backslash and it would refuse
    -- the whole expression.
    local opens, closes = 0, 0
    for _, tok in ipairs(a) do
        if tok == "(" then opens = opens + 1 end
        if tok == ")" then closes = closes + 1 end
        check("no argv token carries a shell escape", not tostring(tok):find("\\", 1, true), tok)
    end
    check("🔬 the group is balanced and bare", opens == 1 and closes == 1,
          opens .. "/" .. closes)
    -- 🔬 AND THE EXPRESSION'S SHAPE, which is the thing a reader gets
    -- wrong. `( prunes ) -prune -o -type f -exec …` has exactly ONE -o
    -- outside the group and it must sit immediately after -prune: that is
    -- what makes "pruned OR a file to stat" rather than "pruned AND…".
    -- Every other -o belongs inside, joining one -name to the next.
    local oOpen, oClose = nil, nil
    for i, tok in ipairs(a) do
        if tok == "(" then oOpen = i end
        if tok == ")" then oClose = i end
    end
    local outside = {}
    for i, tok in ipairs(a) do
        if tok == "-o" and (i < oOpen or i > oClose) then outside[#outside + 1] = i end
    end
    check("🔬 exactly ONE -o sits outside the group",
          #outside == 1, #outside)
    check("…and it is the one right after -prune, which is what makes it an OR",
          a[oClose + 1] == "-prune" and a[oClose + 2] == "-o"
          and a[oClose + 3] == "-type", table.concat(a, " ", oClose, oClose + 3))

    local none, why = od.findArgs("")
    check("no folder to watch is a REFUSAL with a reason, never an empty find",
          none == nil and tostring(why):find("no folder") ~= nil, tostring(why))
    -- 🚨 FOUND BY THIS SUITE'S OWN OLD CHECK, and it is why the guard
    -- exists: findArgs took a LIST until this release, and `tostring({})`
    -- is "table: 0x55…" — a NON-EMPTY string. A caller left on the old
    -- signature would have had find walk a literal path of that name,
    -- match nothing, and report a clean folder (6.338.0's shape: a value
    -- that fails into a valid-looking answer is worse than a throw).
    local tbl, tw = od.findArgs({ "/a", "/b" })
    check("🚨 a LIST is refused outright, never turned into a literal path",
          tbl == nil and tostring(tw):find("not a path") ~= nil, tostring(tw))
    local nilr, nw = od.findArgs(nil)
    check("…and so is nil", nilr == nil and tostring(nw):find("no folder") ~= nil, tostring(nw))
end

-- =====================================================================
-- §7b — DOES THIS FOLDER ALREADY COVER THAT ONE?
-- =====================================================================
out("\n§7b containment, which is what text equality could never see\n")
do
    check("a folder covers itself", od.covers("/a", "/a"))
    check("…and everything under it", od.covers("/a", "/a/b/c.md"))
    -- 🚨 THE FIXTURE THAT BITES: a SIBLING whose name merely starts the
    -- same way. "/ab" is not inside "/a", and a prefix test without the
    -- slash says it is — which would silently stop watching a folder.
    check("🚨 a sibling sharing a prefix is NOT inside it", not od.covers("/a", "/ab"))
    check("…and the slash is what separates them", od.covers("/a", "/a/b"))
    check("nothing covers anything when either side is empty",
          not od.covers("", "/a") and not od.covers("/a", ""))
    check("…or is not a string", not od.covers(nil, "/a") and not od.covers("/a", 7))
end

-- =====================================================================
-- §7c — WHICH FOLDERS ARE WORTH A TURN
-- =====================================================================
out("\n§7c the plan: resolve, then de-duplicate by containment (6.230.0)\n")
do
    -- 🚨 THE EXACT SHAPE THAT HAD NEVER BEEN CAUGHT: his three roots were
    -- the Vault, the Logs folder and the cloud ROOT — and the first two
    -- live inside the third. The old guard compared the strings, found
    -- three different ones, and handed find one tree three times.
    local kept, dropped = od.rootPlan({
        "/cloud/Vault", "/cloud/Logs", "/cloud" }, nil)
    check("🚨 a folder INSIDE another is dropped, not walked a second time",
          #kept == 1 and kept[1].real == "/cloud", #kept)
    check("…and both of the folded ones are NAMED with the reason",
          #dropped == 2
          and tostring(dropped[1].why):find("inside /cloud") ~= nil, #dropped)

    -- 👁 THE PARENT IS SEEN FIRST WHATEVER ORDER THEY ARRIVE IN. "First
    -- wins" over an arbitrary order would keep a child and then drop its
    -- own parent, which is a narrowing nobody asked for.
    local k2 = od.rootPlan({ "/cloud/Vault", "/cloud" }, nil)
    local k3 = od.rootPlan({ "/cloud", "/cloud/Vault" }, nil)
    check("👁 the parent wins whichever order they are given in",
          #k2 == 1 and #k3 == 1 and k2[1].real == "/cloud" and k3[1].real == "/cloud")

    check("two unrelated folders are both kept",
          #od.rootPlan({ "/a", "/b" }, nil) == 2)
    check("the same folder named twice is kept once",
          #od.rootPlan({ "/a", "/a" }, nil) == 1)
    check("a trailing slash is not a different folder",
          #od.rootPlan({ "/a", "/a/" }, nil) == 1)
    check("an empty candidate is simply not a folder",
          #od.rootPlan({ "", "/a" }, nil) == 1)

    -- 🔗 AND THE FIXTURE THAT ONLY A RESOLVER CAN PASS. Neither string is
    -- a prefix of the other, so containment over the RAW paths keeps both
    -- and one tree is walked twice — 6.230.0 exactly, and the reason
    -- ~/Music is resolved rather than reasoned about.
    local function realOf(p)
        if p == "/home/Music" then return "/cloud/Music" end
        return p
    end
    local raw = od.rootPlan({ "/cloud/Music", "/home/Music" }, nil)
    check("🔗 without a resolver a link and its target read as two folders",
          #raw == 2, #raw)
    local res, resDropped, didResolve = od.rootPlan({ "/cloud/Music", "/home/Music" }, realOf)
    check("🔗 …and WITH one they are the one tree they really are",
          #res == 1 and res[1].real == "/cloud/Music", #res)
    check("…and the dropped one says it was a LINK, not a mistake",
          #resDropped == 1 and tostring(resDropped[1].why):find("link") ~= nil,
          resDropped[1] and resDropped[1].why)
    check("…and the plan reports WHETHER it could resolve at all",
          didResolve == true and select(3, od.rootPlan({ "/a" }, nil)) == false)

    -- a resolver that throws must not take the plan down with it
    local threw = od.rootPlan({ "/a", "/b" }, function() error("no", 0) end)
    check("a resolver that THROWS leaves the folders as asked, never none",
          #threw == 2, #threw)
    -- …and one answering a RELATIVE path is refused: it is not a path
    -- anything can be handed (ft.realOf's own rule)
    local rel = od.rootPlan({ "/a" }, function() return "b/c" end)
    check("…and a RELATIVE answer is refused, not believed",
          #rel == 1 and rel[1].real == "/a", rel[1] and rel[1].real)
end

-- =====================================================================
-- §7d — HOW LONG THIS FOLDER'S WALK MAY TAKE
-- =====================================================================
out("\n§7d the budget, measured off the walk rather than typed (6.355.0)\n")
do
    local opts = { floor = 90, ceiling = 600, multiple = 4 }
    -- 🚨 FAIL TO THE FLOOR, NEVER TO 0. A folder with no history must not
    -- produce a budget of 0: that reads as a valid number, kills every
    -- walk the instant it starts, and blames the walk while doing it.
    local b, why = od.turnBudget(nil, opts)
    check("🚨 no history is the FLOOR, never 0", b == 90, b)
    check("…and it says so rather than looking like a measurement",
          tostring(why):find("not been walked yet") ~= nil, why)
    check("🚨 a ZERO is the floor too, not a zero budget", od.turnBudget(0, opts) == 90)
    -- 🚨 A CLOCK THAT MOVED BACKWARDS IS NOT A FAST WALK — and asserting
    -- the NUMBER proves nothing here, which the sweep found: without the
    -- `n <= 0` guard a -5000 falls through, 4 × -5 is -20, and the FLOOR
    -- branch catches it and returns 90 anyway. What the guard really
    -- holds is the SENTENCE: the mutant prints "its last walk took -5.0 s"
    -- to him, which is a report telling him something impossible.
    -- 6.248.0 — assert the RULE, never the constant.
    local bn, wn = od.turnBudget(-5000, opts)
    check("🚨 …and so is a NEGATIVE, which is a clock that moved", bn == 90, bn)
    check("🚨 …and it is NOT described as a walk that took -5 s",
          tostring(wn):find("not been walked yet") ~= nil
          and tostring(wn):find("-5") == nil, tostring(wn))

    -- a walk well inside the floor keeps the floor
    local b2, w2 = od.turnBudget(2000, opts)
    check("a 2 s walk still gets the floor, and the line says why",
          b2 == 90 and tostring(w2):find("under it") ~= nil, b2 .. " " .. tostring(w2))

    -- 📏 THE MEASURED CASE, which is the whole release: 40 s × 4 = 160 s,
    -- a number no literal in this file ever chose.
    local b3, w3 = od.turnBudget(40000, opts)
    check("📏 a 40 s walk is given 4× that, measured",
          b3 == 160 and tostring(w3):find("× its last walk") ~= nil,
          b3 .. " " .. tostring(w3))
    check("…and the 180 s that never worked is nowhere in it", b3 ~= 180)

    -- the ceiling, so a pathological folder cannot run all day
    local b4, w4 = od.turnBudget(400000, opts)
    check("a pathological walk is capped, and told it was capped",
          b4 == 600 and tostring(w4):find("ceiling") ~= nil, b4 .. " " .. tostring(w4))

    -- 🚨 AND A FLOOR ABOVE THE CEILING CANNOT PRODUCE AN IMPOSSIBLE RANGE
    check("🚨 a settings line with floor above ceiling still answers sanely",
          od.turnBudget(1000, { floor = 300, ceiling = 100, multiple = 4 }) == 300)
    check("…and a multiple below 1 cannot shrink a budget under the floor",
          od.turnBudget(40000, { floor = 90, ceiling = 600, multiple = 0 }) >= 90)
end

-- =====================================================================
-- §8 — READING `stat` BACK
-- =====================================================================
out("\n§8 what the sweep makes of stat's answer\n")
do
    local text = table.concat({
        "104857600 204800 /cloud/here.mov",        -- every block allocated
        "104857600 8 /cloud/gone.mov",             -- a placeholder
        "2048 8 /cloud/note.md",                   -- under the floor: here
        "104857600 8 /cloud/a film with spaces.mov",
        "stat: /cloud/x: No such file or directory",
    }, "\n")
    local r = od.parseStat(text)
    check("🔎 it counts every line it could read", r.files == 4, r.files)
    check("…a fully allocated file is HERE", r.localN == 2, r.localN)
    check("…a file with nothing behind it is in the CLOUD", r.cloudN == 2, r.cloudN)

    -- 📏 THE FIXTURE THAT BITES THE SPLIT. A name with spaces in it is
    -- the only input where "take the last field" and "take everything
    -- after the two numbers" differ — and his films are full of them.
    local names = {}
    for _, f in ipairs(r.cloud) do names[f.path] = true end
    check("📏 a file name with SPACES in it survives the split whole",
          names["/cloud/a film with spaces.mov"] == true,
          r.cloud[1] and r.cloud[1].path)

    -- 🔎 a line it cannot read is COUNTED, never dropped: a parser that
    -- quietly eats what it does not understand reports a healthy tree
    -- over a read that half failed.
    check("🔎 a line stat could not produce is counted, not swallowed",
          r.bad == 1, r.bad)

    check("the cloud list is biggest first — the one that costs him most",
          r.cloud[1].size >= r.cloud[2].size)
    check("…and the local SET holds the paths that were here",
          r.localSet["/cloud/here.mov"] == true
          and r.localSet["/cloud/gone.mov"] == nil)

    -- 📏 BOUNDED, AND THE BOUND IS A STATE (6.197.2)
    local r2 = od.parseStat(text, { maxTrack = 1 })
    check("📏 past the tracking bound it stops remembering and SAYS so",
          r2.capped == true and r2.tracked == 1, tostring(r2.tracked))
    check("…and the counts are still complete — only the tracking is bounded",
          r2.localN == 2 and r2.cloudN == 2)

    check("nothing at all is an empty answer, never a throw",
          od.parseStat(nil).files == 0 and od.parseStat("").files == 0)
end

-- =====================================================================
-- §9 — WHAT LEFT THIS MAC
-- =====================================================================
out("\n§9 the one question he asked, and the state that must not read like it\n")
do
    local now = od.parseStat(table.concat({
        "104857600 8 /cloud/was-here.mov",     -- in the cloud now
        "104857600 8 /cloud/never-here.mov",   -- in the cloud now
    }, "\n"))
    local before = { ["/cloud/was-here.mov"] = true, ["/cloud/other.mov"] = true }
    local gone = od.offloaded(before, now)
    check("☁️ a file that WAS here and is in the cloud now is an offload",
          #gone == 1 and gone[1].path == "/cloud/was-here.mov",
          gone[1] and gone[1].path)
    -- 🚨 THE DISTINCTION THE WHOLE RELEASE RESTS ON. His own report names
    -- 821 files that are in the cloud; nearly all have never been here.
    -- Counting those as offloads would bury the handful that are news.
    check("🚨 a file that was NEVER here is not news and is not counted", #gone == 1)
    check("nothing at all is an empty list, never a throw",
          #od.offloaded(nil, now) == 0 and #od.offloaded(before, nil) == 0)

    -- 🔎 "nothing has left" and "I have nothing to compare against" are
    -- opposite facts and a reload makes the second one the ordinary
    -- morning state (6.196.1).
    local k = od.sweepVerdict(false, {}, false)
    check("🔎 the FIRST sweep says it had nothing to compare against",
          k == "baseline", k)
    check("…and a later sweep with nothing gone says THAT instead",
          od.sweepVerdict(true, {}, false) == "clean")
    check("…and one that found something says so", od.sweepVerdict(true, gone, false) == "left")
    -- 📏 and a clean answer taken under a bound is its own state: it is
    -- true of what was tracked and says nothing about the rest.
    local kc, kw = od.sweepVerdict(true, {}, true)
    check("📏 a clean sweep that hit the tracking bound says it covered only part",
          kc == "clean-capped" and kw:find("part of the tree", 1, true) ~= nil, kw)
end

-- =====================================================================
-- §10 — THE SWEEP, DRIVEN END TO END
-- =====================================================================
out("\n§10 the sweep: its flag, its belt, its alert and its ledger\n")
do
    local function reset()
        TASKS, AFTER, EVERY, ALERTS, DEGRADES, TOLD = {}, {}, {}, {}, {}, {}
        od.sweepBusy, od.sweepTask, od.sweepKiller = false, nil, nil
        od.lastSweep, od.lastResult = nil, nil
        od.baselines, od.rootMs, od.turnLast = {}, {}, {}
        od.turnIdx, od.turns, od.roots = 0, 0, nil
        od.offloads, od.toldAt, od.storeRead = {}, 0, true
        od.sweeps, od.sweepFails, od.noKiller = 0, 0, 0
        od.folderList = { "/cloud" }
        FSMODE["/cloud"] = "directory"
    end
    local HERE = "104857600 204800 /cloud/film.mov\n104857600 204800 /cloud/two.mov"
    local GONE = "104857600 8 /cloud/film.mov\n104857600 204800 /cloud/two.mov"

    reset()
    od.sweep("a test")
    check("the sweep runs find, out of process", TASKS[1] and TASKS[1].bin == "/usr/bin/find",
          TASKS[1] and TASKS[1].bin)
    check("🛟 the belt is armed BEFORE the ask (6.246.0), in its own slot",
          od.sweepKiller ~= nil and #AFTER >= 1)
    check("…and the flag is up while it runs", od.sweepBusy == true)
    local second = od.sweep("again")
    check("a second sweep while one is in flight is refused, not stacked",
          second == false and #TASKS == 1)

    TASKS[1].cb(0, HERE, "")
    check("🚪 the flag is cleared when the sweep answers (6.304.0)", od.sweepBusy == false)
    check("…and the belt is stood down with it", od.sweepKiller == nil)
    check("the first sweep takes a BASELINE and claims nothing about what left",
          od.lastResult.kind == "baseline", od.lastResult.kind)
    check("…and nothing is alerted on it", #ALERTS == 0, ALERTS[1])

    -- the second sweep: one file has gone back to the cloud
    od.sweep("a test")
    TASKS[2].cb(0, GONE, "")
    check("☁️ the second sweep names the file that left", #od.offloads == 1
          and od.offloads[1].path == "/cloud/film.mov", od.offloads[1] and od.offloads[1].path)
    check("📣 …and it is SAID on screen, which is what he asked for",
          #ALERTS == 1 and ALERTS[1]:find("took 1 file", 1, true) ~= nil, ALERTS[1])
    check("…through notices too, so Focus holds it rather than eating it", #TOLD == 1)
    -- 🚨 AN OFFLOAD IS NOT A FAULT OF THIS TOOL. Routing it through the
    -- degrade door would file his own OneDrive's behaviour in the "what
    -- broke today" log beside real failures.
    check("🚨 an offload does NOT take the degrade door", #DEGRADES == 0, DEGRADES[1])
    check("🔒 the ledger is written where a reload can find it",
          DISK[od.storeFile] ~= nil and DISK[od.storeFile]:find("film.mov", 1, true) ~= nil)
    check("…temp-then-rename, so a cut-off write costs the WRITE (6.313.0)",
          DISK[od.storeFile .. ".tmp"] == nil)

    -- 🔕 IT MUST NOT SHOUT ONCE A SWEEP — and the fixture has to make
    -- something REALLY leave, or the rate limit is never reached and the
    -- check passes with the window deleted. The mutation sweep found
    -- exactly that: driving a sweep where nothing moved proves nothing
    -- about a guard that only runs when something did (6.273.0).
    ALERTS = {}
    od.sweep("a test")
    TASKS[3].cb(0, "104857600 8 /cloud/film.mov\n104857600 8 /cloud/two.mov", "")
    check("…and the SECOND file really did leave, so there was something to say",
          #od.offloads == 2, #od.offloads)
    check("🔕 a second offload inside the window is counted and not shouted",
          #ALERTS == 0, ALERTS[1])
    -- …and once the window has passed it speaks again, or "quiet" and
    -- "nothing happened" become the same thing.
    od.toldAt = 0
    od.sweep("a test")
    TASKS[4].cb(0, "104857600 8 /cloud/film.mov\n104857600 8 /cloud/two.mov\n104857600 204800 /cloud/three.mov", "")
    od.sweep("a test")
    TASKS[5].cb(0, "104857600 8 /cloud/three.mov", "")
    check("🔕 …and once the window has passed it speaks again", #ALERTS == 1, #ALERTS)

    -- 🔒 THE LEDGER SURVIVES A WRITE THAT FAILS (6.313.0), and the
    -- fixture has to make a DIFFERENT file leave on every attempt — the
    -- sweep found the first version of these checks passing because the
    -- baseline had already emptied and `saveLedger` was never reached at
    -- all. A check that drives a path the guard does not run on proves
    -- nothing about the guard (6.273.0).
    do
        TASKS, ALERTS, DEGRADES = {}, {}, {}
        od.sweepBusy, od.offloads, od.toldAt = false, {}, 0
        od.baselines = {}
        DISK[od.storeFile] = nil
        local ALL   = "104857600 204800 /c/a.mov\n104857600 204800 /c/b.mov\n104857600 204800 /c/c.mov"
        local GONE1 = "104857600 8 /c/a.mov\n104857600 204800 /c/b.mov\n104857600 204800 /c/c.mov"
        local GONE2 = "104857600 8 /c/a.mov\n104857600 8 /c/b.mov\n104857600 204800 /c/c.mov"
        local GONE3 = "104857600 8 /c/a.mov\n104857600 8 /c/b.mov\n104857600 8 /c/c.mov"
        od.sweep("t") ; TASKS[#TASKS].cb(0, ALL, "")        -- the baseline
        od.sweep("t") ; TASKS[#TASKS].cb(0, GONE1, "")      -- a.mov leaves
        local held = DISK[od.storeFile]
        check("…there is a ledger on disk to protect",
              held ~= nil and held:find("a.mov", 1, true) ~= nil, tostring(held))

        -- a disk that fills MID-WRITE: the open has already emptied
        -- whatever it opened, so a direct write destroys the record of
        -- what left his Mac. Temp-then-rename costs the WRITE instead.
        CLOSE_REFUSES = true
        od.sweep("t") ; TASKS[#TASKS].cb(0, GONE2, "")      -- b.mov leaves
        CLOSE_REFUSES = false
        check("🔒 a ledger write that fails MID-WRITE leaves the old ledger whole",
              DISK[od.storeFile] == held, tostring(DISK[od.storeFile]))

        RENAME_REFUSES = true
        od.sweep("t") ; TASKS[#TASKS].cb(0, GONE3, "")      -- c.mov leaves
        RENAME_REFUSES = false
        check("🔒 …and so does a rename this Mac refuses",
              DISK[od.storeFile] == held, tostring(DISK[od.storeFile]))
        check("🔒 …with no half-written temp file left behind",
              DISK[od.storeFile .. ".tmp"] == nil, DISK[od.storeFile .. ".tmp"])
        -- …and an open that is refused outright is the third way, where
        -- nothing was truncated and nothing may be lost either.
        WRITE_REFUSES = true
        od.baselines["/c"] = { set = { ["/c/d.mov"] = true }, at = 1 }
        od.sweep("t") ; TASKS[#TASKS].cb(0, "104857600 8 /c/d.mov", "")
        WRITE_REFUSES = false
        check("🔒 …and so does an open this Mac refuses outright",
              DISK[od.storeFile] == held, tostring(DISK[od.storeFile]))
    end

    -- ---- every way the sweep can fail -----------------------------------
    reset()
    od.sweep("a test")
    TASKS[1].cb(1, "", "find: /cloud: Permission denied")
    check("🔔 a find that printed NOTHING takes the degrade door — his"
          .. " 'screen report if it is not working'",
          #DEGRADES == 1 and DEGRADES[1]:find("OneDrive watch", 1, true) ~= nil, DEGRADES[1])
    check("…and the flag is released, so the watch is not wedged for the session",
          od.sweepBusy == false)

    -- 🚨 A PARTIAL ANSWER IS USED AND SAID. `find` exits non-zero when a
    -- single folder refuses to be listed and still prints everything it
    -- COULD walk; throwing that away turns one unreadable folder into a
    -- dead watcher.
    reset()
    od.sweep("a test")
    TASKS[1].cb(1, HERE, "find: /cloud/x: Permission denied")
    check("🚨 a PARTIAL find is used rather than discarded",
          od.lastResult ~= nil and od.lastResult.files == 2, od.lastResult and od.lastResult.files)
    check("…and the report will say it was partial", od.lastResult.partial == true)

    -- the belt, fired
    reset()
    od.sweep("a test")
    od.sweepKiller.fire()
    check("🛟 a sweep that never answers is ended by the belt and NAMED",
          od.sweepBusy == false and #DEGRADES == 1
          and DEGRADES[1]:find("did not answer", 1, true) ~= nil, DEGRADES[1])
    check("…and the task is terminated rather than left running", TASKS[1].killed == true)

    -- 🔬 6.265.0 — MISSING is not REFUSING, and this Mac does both.
    reset()
    TASK_REFUSES = true
    local ok = od.sweep("a test")
    TASK_REFUSES = false
    check("🔬 macOS refusing to CREATE the task degrades and clears the flag",
          ok == false and od.sweepBusy == false and #DEGRADES == 1, DEGRADES[1])

    -- the parse budget
    reset()
    od.sweep("a test")
    local was = od.parseMs
    od.parseMs = -1
    CLOCK = CLOCK + 5
    TASKS[1].cb(0, HERE, "")
    od.parseMs = was
    check("⏱ a parse that costs the main thread too much SAYS so with the number",
          #DEGRADES == 1 and DEGRADES[1]:find("ms on the main thread", 1, true) ~= nil,
          DEGRADES[1])
    od.folderList = nil
end

-- =====================================================================
-- §11 — THE WATCH, AND THE REPORT'S NEW STATES
-- =====================================================================
out("\n§11 the watch itself, and the states the report must keep apart\n")
do
    local function reportText()
        local kept, buf = print, {}
        print = function(s) buf[#buf + 1] = tostring(s) end
        pcall(_G.oneDriveCheck)
        print = kept
        return table.concat(buf, "\n")
    end
    od.folderList, od.roots = { "/cloud" }, nil
    FSMODE["/cloud"] = "directory"
    od.offloads, od.lastResult, od.lastSweep = {}, nil, nil
    od.baselines, od.rootMs, od.turnLast = {}, {}, {}
    od.turnIdx, od.turns = 0, 0
    od.storeRead = true
    -- 🚨 6.381.0 — THIS SECTION IS ABOUT THE MECHANISM, SO IT TURNS THE
    -- WATCH ON RATHER THAN RELYING ON THE SHIPPED DEFAULT. The default is
    -- OFF now (he parked it), and a check that reads a default is a check
    -- that goes red with nothing to say the day the default moves —
    -- 6.248.0, which this release met the moment the default flipped.
    -- The OFF half is driven explicitly at the end of the section.
    od.enabled = true

    -- 🔌 6.228.0 — THE WATCH STARTS IN warm, NEVER setup: a profile's
    -- settings land AFTER setup returns, so a watcher started there can
    -- only ever be stopped by an override and never started.
    EVERY, AFTER = {}, {}
    od.stopWatch()
    local r0 = reportText()
    check("🔌 a watch that is WANTED and not running says so, loudly",
          r0:find("WANTED but NOT RUNNING", 1, true) ~= nil, r0:sub(1, 400))

    M.warm()
    check("M.warm arms the repeating TURN timer, at turnEvery",
          #EVERY == 1 and EVERY[1].secs == od.turnEvery, #EVERY)
    check("…and one first turn shortly after boot, so nothing at boot waits on find",
          #AFTER >= 1)
    local r1 = reportText()
    check("⏳ 'no turn has finished yet' is its own state, never 'all clear'",
          r1:find("no turn has finished yet", 1, true) ~= nil, r1:sub(1, 400))
    check("⏳ …and so is 'nothing to compare against yet'",
          r1:find("nothing to compare against yet", 1, true) ~= nil, r1:sub(1, 600))

    -- a finished sweep: the numbers come from it and the report SAYS so
    TASKS = {}
    od.sweep("a test")
    TASKS[1].cb(0, "104857600 204800 /cloud/film.mov", "")
    local r2 = reportText()
    -- 📏 AND IT NAMES THE FOLDER NOW, never "the whole tree". A turn's
    -- numbers are ONE folder's, and letting them wear the tree's
    -- authority is the old line's lie in reverse.
    check("the report names WHERE its numbers came from, and which folder",
          r2:find("the last TURN", 1, true) ~= nil
          and r2:find("alone, not every folder", 1, true) ~= nil, r2:sub(1, 700))
    check("…and never wears the 4000-file bound when the sweep walked the tree",
          r2:find("STOPPED AT THE", 1, true) == nil)
    check("☁️ LEFT THIS MAC reads 'none' once there is a baseline to compare",
          r2:find("LEFT THIS MAC: none", 1, true) ~= nil, r2:sub(-600))

    -- and with something gone
    TASKS = {}
    od.toldAt = 0
    od.sweep("a test")
    TASKS[1].cb(0, "104857600 8 /cloud/film.mov", "")
    local r3 = reportText()
    check("☁️ …and names the file, with when it went",
          r3:find("LEFT THIS MAC: 1", 1, true) ~= nil
          and r3:find("/cloud/film.mov", 1, true) ~= nil, r3:sub(-700))
    check("…and says the ledger is LOCAL, never in the folder being watched",
          r3:find("never OneDrive", 1, true) ~= nil)

    -- 🚨 6.282.0 — THE REPORT MUST NEVER RAISE. The sweep's result has no
    -- `unreadable` key at all; the on-demand walk's does. A report that
    -- throws is every ask in this file answered with nothing.
    check("🚨 the report printed rather than throwing, on a sweep result",
          #r3 > 200, #r3)

    -- 🗑 6.381.0 — THE SWITCH IS REAL IN BOTH DIRECTIONS, and it is the
    -- one he would actually reach for. `enabled` shipped as a field that
    -- was READ NOWHERE while a second flag did the governing, so the
    -- house idiom was a line that parsed and did nothing. These checks
    -- drive the FIELD, so re-introducing a second flag fails by name.
    od.enabled = false
    M.warm()
    local r4 = reportText()
    check("OFF is real: no timer is armed",
          od.tickTimer == nil and od.firstTimer == nil,
          tostring(od.tickTimer) .. " / " .. tostring(od.firstTimer))
    check("the report says it is OFF",
          r4:find("watch  : OFF", 1, true) ~= nil, r4:sub(1, 400))
    -- 🚨 NOTHING WAS DELETED, and the report has to SAY so — "off" and
    -- "your records are gone" are opposite facts (6.196.1 · 6.356.0).
    check("OFF names what is kept",
          r4:find("kept", 1, true) ~= nil
          and r4:find("nothing was deleted", 1, true) ~= nil, r4:sub(1, 600))
    check("OFF names the way back on",
          r4:find("enabled = true", 1, true) ~= nil, r4:sub(1, 600))
    -- 🚪 PARKED IS NOT REMOVED: both by-hand doors must still be there.
    check("the by-hand doors survive the park",
          type(_G.oneDriveSweep) == "function"
          and type(_G.oneDriveCheck) == "function")
    -- the verdict is PURE and answers the REASON, not just the branch
    local onOK = od.watchVerdict(true)
    local offOK, offWhy = od.watchVerdict(false)
    check("watchVerdict: true runs, false is off AND says why",
          onOK == true and offOK == false
          and type(offWhy) == "string" and offWhy:find("OFF", 1, true) ~= nil,
          tostring(offWhy))
    od.enabled = true
    M.warm()
    check("ON is real too: the timer comes back",
          od.tickTimer ~= nil, tostring(od.tickTimer))
    od.stopWatch()
    od.folderList = nil
end


-- =====================================================================
-- §12 — WHICH FOLDERS, AND WHICH ONE IS DELIBERATELY NOT THERE
-- =====================================================================
out("\n§12 the candidates: his music and films in, the cloud ROOT out\n")
do
    od.folderList, od.roots = nil, nil
    local cands = od.candidatePaths()
    local function has(p)
        for _, c in ipairs(cands) do if c == p then return true end end
        return false
    end
    -- 🎬 HIS ASK, BOTH PLACES EACH. Which of the two he means is not
    -- something that can be known from here: <cloud>/Music can hold
    -- placeholders outright, and ~/Music can too — but only if it is a
    -- LINK into OneDrive, which is why it is offered and resolved rather
    -- than reasoned about.
    check("🎬 <cloud>/Music is a candidate", has("/cloud/Music"), table.concat(cands, " "))
    check("🎬 <cloud>/Movies is a candidate", has("/cloud/Movies"))
    check("🎬 ~/Music is a candidate too", has("/home/Music"))
    check("🎬 ~/Movies is a candidate too", has("/home/Movies"))
    check("the Vault is still a candidate", has("/cloud/Vault"))
    check("the Logs folder is still a candidate", has("/cloud/Logs"))

    -- 🚨 AND NOTHING FOLDS, which is what taking the root out BUYS. The
    -- four cloud folders are siblings, so all four get their own turn.
    FSMODE = {}
    for _, p in ipairs(cands) do FSMODE[p] = "directory" end
    od.roots = nil
    check("🚨 with the root out of the list, nothing folds into anything",
          #od.folders() == #cands and #od.rootsDropped == 0,
          #od.folders() .. " of " .. #cands)
    -- …and the proof that the containment really is wired end to end:
    -- put the root BACK and every one of them folds into it, which is
    -- exactly the walk that took 358 seconds.
    FSMODE["/cloud"] = "directory"
    od.folderList = { "/cloud", "/cloud/Vault", "/cloud/Logs",
                      "/cloud/Music", "/cloud/Movies" }
    od.roots = nil
    local folded = od.folders()
    check("🚨 …and with the root back in, all four fold INTO it",
          #folded == 1 and folded[1] == "/cloud" and #od.rootsDropped == 4,
          #folded .. " kept, " .. #od.rootsDropped .. " dropped")
    od.folderList, od.roots = nil, nil
    FSMODE["/cloud"] = nil

    -- 🚨 THE ONE THAT IS NOT, AND IT IS THE RELEASE. The cloud root
    -- CONTAINS every one of the above, and walking it is the 358 seconds
    -- his own log recorded against a 180-second budget. A check that only
    -- asserted the four new rows would pass with the root still in the
    -- list and the walk still never finishing.
    check("🚨 the cloud ROOT is NOT a candidate — it contains the others",
          not has("/cloud"), table.concat(cands, " "))

    -- 📏 A CANDIDATE THAT IS NOT ON THIS MAC IS SKIPPED, AND SAID. ~/Music
    -- exists on every Mac while <cloud>/Movies may not, so a missing one
    -- is ordinary and must not read like a fault (6.196.1).
    FSMODE = {}
    FSMODE["/cloud/Vault"] = "directory"
    FSMODE["/home/Music"]  = "directory"
    od.roots = nil
    local kept = od.folders()
    table.sort(kept)
    check("only the folders that are really there are walked",
          #kept == 2 and kept[1] == "/cloud/Vault" and kept[2] == "/home/Music",
          table.concat(kept, " "))
    check("…and the ones that are not are counted APART from a drop",
          #od.rootsSkipped >= 1
          and tostring(od.rootsSkipped[1].why):find("not on this Mac") ~= nil,
          #od.rootsSkipped)
    -- a path that exists and is a FILE is not a folder to walk
    FSMODE["/cloud/Movies"] = "file"
    od.roots = nil
    od.folders()
    local sawFile = false
    for _, sk in ipairs(od.rootsSkipped) do
        if sk.asked == "/cloud/Movies" and tostring(sk.why):find("not a folder") then
            sawFile = true
        end
    end
    check("a candidate that is a FILE says so, rather than being walked",
          sawFile, #od.rootsSkipped)

    -- 🔗 AND THE LINK CASE, END TO END THROUGH THE SERVICE. file_tracker
    -- publishes `files.realpath`; this module asks for it AT USE TIME, so
    -- a Mac where that module failed to load still works and SAYS it
    -- could not have spotted a duplicate.
    FSMODE = {}
    FSMODE["/cloud/Music"] = "directory"
    FSMODE["/home/Music"]  = "directory"
    local keptService = _G.service
    _G.service = {
        has  = function(n) return n == "files.realpath" end,
        call = function(_, p)
            if p == "/home/Music" then return "/cloud/Music" end
            return p
        end,
    }
    od.roots = nil
    local one = od.folders()
    check("🔗 ~/Music linked into OneDrive is ONE folder, not two",
          #one == 1 and one[1] == "/cloud/Music", table.concat(one, " "))
    check("…and the plan records that it COULD resolve", od.rootsResolved == true)

    -- 🚨 WITHOUT THE SERVICE IT IS NOT SILENT. "watched" and "watched, and
    -- a duplicate may have slipped through" are different facts.
    _G.service = nil
    od.roots = nil
    local two = od.folders()
    check("🚨 with no resolver the same pair reads as two folders",
          #two == 2, table.concat(two, " "))
    check("…and the report can SAY a link could not have been spotted",
          od.rootsResolved == false)
    _G.service = keptService
end

-- =====================================================================
-- §13 — 🚨 ONE BASELINE PER FOLDER
-- =====================================================================
out("\n§13 the dangerous half: a turn compares against ITS OWN folder\n")
do
    -- 🚨 THIS IS THE CHECK THE RELEASE RESTS ON. Walking one folder per
    -- turn is only safe if each turn is compared against THAT folder's
    -- own last answer. With a single shared baseline the comparison is
    -- made against whatever folder happened to be walked last — and
    -- because `od.offloaded` asks "was this file local BEFORE?", a
    -- baseline belonging to a different folder matches NOTHING, so every
    -- offload is missed. Round-robin means a folder is never walked twice
    -- in a row, so the watcher would be silently and permanently blind:
    -- green report, zero alerts, and nothing to see.
    FSMODE = {}
    FSMODE["/a"], FSMODE["/b"] = "directory", "directory"
    od.folderList, od.roots = { "/a", "/b" }, nil
    od.baselines, od.rootMs, od.turnLast = {}, {}, {}
    od.turnIdx, od.turns, od.offloads, od.toldAt = 0, 0, {}, 0
    od.sweepBusy, od.storeRead = false, true
    TASKS, ALERTS, DEGRADES = {}, {}, {}

    local A_HERE = "104857600 204800 /a/one.mov"
    local A_GONE = "104857600 8 /a/one.mov"
    local B_HERE = "104857600 204800 /b/two.mov"

    -- turn 1: folder /a, its first — a baseline, and no claim
    od.sweep("t")
    check("turn 1 walks the FIRST folder", od.turnRoot == "/a", tostring(od.turnRoot))
    TASKS[#TASKS].cb(0, A_HERE, "")
    check("…and takes a baseline for /a alone",
          type(od.baselines["/a"]) == "table" and od.baselines["/b"] == nil)
    check("…and claims nothing about what left", od.lastResult.kind == "baseline")

    -- turn 2: folder /b, its first — /a's baseline must be untouched
    od.sweep("t")
    check("turn 2 walks the SECOND folder", od.turnRoot == "/b", tostring(od.turnRoot))
    TASKS[#TASKS].cb(0, B_HERE, "")
    check("🚨 /a's baseline SURVIVES a turn on /b",
          type(od.baselines["/a"]) == "table"
          and od.baselines["/a"].set["/a/one.mov"] == true)
    check("…and /b has one of its own now",
          type(od.baselines["/b"]) == "table"
          and od.baselines["/b"].set["/b/two.mov"] == true)

    -- turn 3: back to /a, and the file has gone to the cloud
    od.sweep("t")
    check("turn 3 comes back round to /a", od.turnRoot == "/a", tostring(od.turnRoot))
    TASKS[#TASKS].cb(0, A_GONE, "")
    -- 🚨 THE MUTATION THIS KILLS: a single shared baseline would have been
    -- overwritten by /b's local set at turn 2, so /a/one.mov would not be
    -- found in it and this offload would be MISSED, for ever, on every
    -- folder, with the report reading clean.
    check("🚨 the offload IS caught after an intervening turn on another folder",
          #od.offloads == 1 and od.offloads[1].path == "/a/one.mov",
          #od.offloads)
    -- the folder is named by its BASENAME, because "Music" is what reads
    -- on an alert and a full cloud path is forty characters of prefix
    check("…and he is told, with the folder named",
          #ALERTS == 1 and tostring(ALERTS[1]):find("in a", 1, true) ~= nil,
          ALERTS[1])
    check("…and it is NOT filed as a fault of this tool", #DEGRADES == 0, DEGRADES[1])

    -- …and the other folder's own answer is still its own
    check("…while /b's baseline is untouched by any of it",
          od.baselines["/b"].set["/b/two.mov"] == true)

    -- 🚨 A FOLDER THAT LEAVES THE LIST KEEPS NO BASELINE. A set held over
    -- from a folder nothing walks any more sits waiting to be compared
    -- against a turn that never covers it.
    od.folderList, od.roots = { "/a" }, nil
    od.folders(true)
    check("🚨 a folder dropped from the list loses its baseline",
          od.baselines["/b"] == nil and type(od.baselines["/a"]) == "table")

    -- 📏 AND ONLY A FINISHED WALK TEACHES THE BUDGET. A killed turn's
    -- elapsed time IS the budget, so feeding it back would ratchet the
    -- budget up off its own timeout and call that a measurement.
    od.rootMs = {}
    od.turnIdx = 0
    TASKS, AFTER = {}, {}
    od.sweep("t")
    local killer = AFTER[#AFTER]
    killer.fire()
    check("a turn killed by its belt is a FAILURE, named with the folder",
          od.lastSweep.ok == false
          and tostring(od.lastSweep.why):find("did not answer") ~= nil,
          tostring(od.lastSweep and od.lastSweep.why))
    -- 🚨 THE CHECK THE SWEEP FORCED. Asserting `rootMs == nil` after a
    -- killed turn proved nothing, because the killed path used to pass no
    -- time at all — so assigning it was a no-op and the guard could not
    -- be killed by any mutation (6.273.0: the line was not the finding,
    -- the missing check was). The failure paths CARRY their elapsed time
    -- now, for the report, so the guard has something to refuse: a killed
    -- turn's elapsed time IS the budget, and letting it teach the budget
    -- would raise the budget BECAUSE it timed out and call that a
    -- measurement — a loop that ratchets itself up off its own failure.
    check("🚨 …and the report KNOWS how long it ran before giving up",
          type(od.turnLast["/a"]) == "table"
          and tonumber(od.turnLast["/a"].walkMs) ~= nil,
          tostring(od.turnLast["/a"] and od.turnLast["/a"].walkMs))
    check("🚨 …while the BUDGET learns nothing from it, so it cannot ratchet up",
          od.rootMs["/a"] == nil, tostring(od.rootMs["/a"]))

    -- …and the same for a find that exits non-zero with nothing to show
    od.rootMs, od.turnLast = {}, {}
    od.sweepBusy, od.turnIdx = false, 0
    TASKS = {}
    od.sweep("t")
    TASKS[#TASKS].cb(3, "", "")
    check("a find that exits non-zero with no output is a FAILURE too",
          od.lastSweep.ok == false
          and tostring(od.lastSweep.why):find("exited 3") ~= nil,
          tostring(od.lastSweep.why))
    check("🚨 …and it does not teach the budget either",
          od.rootMs["/a"] == nil and tonumber(od.turnLast["/a"].walkMs) ~= nil,
          tostring(od.rootMs["/a"]))
    check("…and it takes the 🔔 door, naming the folder",
          #DEGRADES >= 1 and tostring(DEGRADES[#DEGRADES]):find("a") ~= nil,
          DEGRADES[#DEGRADES])

    od.folderList, od.roots = nil, nil
end

-- =====================================================================
-- §14 — THE ROUND ROBIN, AND WHAT A NEW PASS RE-ASKS
-- =====================================================================
out("\n§14 one folder per turn, and the wrap that starts a new pass\n")
do
    FSMODE = {}
    FSMODE["/a"], FSMODE["/b"], FSMODE["/c"] = "directory", "directory", "directory"
    od.folderList, od.roots = { "/a", "/b", "/c" }, nil
    od.turnIdx = 0
    local seen = {}
    for _ = 1, 6 do
        local r = od.nextTurnRoot()
        seen[#seen + 1] = r
    end
    check("every folder gets a turn, in order, and then it comes round again",
          table.concat(seen, " ") == "/a /b /c /a /b /c", table.concat(seen, " "))

    -- 🔁 THE WRAP RE-ASKS WHAT EXISTS. A folder can appear (OneDrive
    -- finishes mounting, the vault loads its own) or leave, so a list
    -- worked out once at boot is a list that was true at boot — 6.284.0,
    -- where the stale half turned out to be the question and not the
    -- answer.
    od.turnIdx = 0
    od.nextTurnRoot() ; od.nextTurnRoot() ; od.nextTurnRoot()   -- a full pass
    FSMODE["/d"] = "directory"
    od.folderList = { "/a", "/b", "/c", "/d" }
    local nxt = od.nextTurnRoot()
    check("🔁 a folder that appeared mid-pass is picked up at the next wrap",
          nxt == "/a" and #od.folders() == 4, tostring(nxt) .. " " .. #od.folders())

    -- …and one that went away is not walked
    FSMODE["/b"] = nil
    od.turnIdx = 99          -- force the wrap
    od.nextTurnRoot()
    local list = table.concat(od.folders(), " ")
    check("…and one that went away is dropped at the next wrap",
          list:find("/b", 1, true) == nil, list)

    -- 🚨 NO FOLDER AT ALL IS A REFUSAL WITH A REASON, never a turn on ""
    FSMODE = {}
    od.folderList, od.roots = {}, nil
    od.sweepBusy = false
    TASKS, DEGRADES = {}, {}
    local ok, why = od.sweep("t")
    check("🚨 with nothing to walk the turn is REFUSED and said, never silent",
          ok == false and tostring(why):find("no folder") ~= nil
          and #TASKS == 0 and #DEGRADES == 1, tostring(why))

    od.folderList, od.roots = nil, nil
end

out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("   ❌ " .. f) end
os.exit(fail == 0 and 0 or 1)
