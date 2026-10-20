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
local DISK, WRITE_REFUSES, RENAME_REFUSES = {}, false, false
local realOpen, realRename, realRemove = io.open, os.rename, os.remove
io.open = function(path, mode)
    if (mode or "r"):find("w") then
        if WRITE_REFUSES then return nil, "refused" end
        local buf = {}
        return { write = function(_, t) buf[#buf + 1] = tostring(t) end,
                 close = function() DISK[path] = table.concat(buf) end,
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
    fs = { attributes = function() return nil end,
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
    local CORE = { logsDir = "/logs", cloudDir = "/cloud", homeDir = "/home",
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
    od.folderList = { "/v" }
    local TREE = { ["/v"] = { { name = "film.mp4", isDir = false } } }
    local realDir, realAttr = hs.fs.dir, hs.fs.attributes
    hs.fs.dir = function(d)
        local i, list = 0, TREE[d] or {}
        return function() i = i + 1 ; return list[i] and list[i].name or nil end
    end
    hs.fs.attributes = function(p, kind)
        if kind == "mode" then return "file" end
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
    od.folderList = nil

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
out("\n§7 the find the sweep runs, and the prune that must not eat a root\n")
do
    local a = od.findArgs({ "/cloud", "/cloud/Vault" })
    check("the roots come first, in order", a[1] == "/cloud" and a[2] == "/cloud/Vault")
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
    -- top: without -mindepth 1 find tests the ROOTS too, so a root whose
    -- own basename begins with a dot is pruned on sight, the sweep walks
    -- nothing, and the report says the tree is clean. Every other root
    -- agrees with both implementations (6.230.0).
    local dotRoot = od.findArgs({ "/home/.hammerspoon" })
    local dj = table.concat(dotRoot, " ")
    check("🚨 -mindepth 1 keeps the prune off the ROOTS themselves",
          dj:find("-mindepth 1", 1, true) ~= nil
          and dj:find("-mindepth 1") < (dj:find("-name") or 1e9), dj)
    check("…and dot-folders INSIDE the tree are still pruned",
          dj:find("-name .* -prune", 1, true) ~= nil, dj)

    local none, why = od.findArgs({})
    check("no folder to watch is a REFUSAL with a reason, never an empty find",
          none == nil and tostring(why):find("no folder") ~= nil, tostring(why))
    local dup = od.findArgs({ "/a", "/a", "/b" })
    check("a folder named twice is walked once", #dup == #od.findArgs({ "/a", "/b" }))
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
        od.baseline, od.baselineAt, od.lastSweep, od.lastResult = nil, nil, nil, nil
        od.offloads, od.toldAt, od.storeRead = {}, 0, true
        od.sweeps, od.sweepFails, od.noKiller = 0, 0, 0
        od.folderList = { "/cloud" }
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

    -- 🔕 it must not shout once a sweep
    ALERTS = {}
    od.sweep("a test")
    TASKS[3].cb(0, GONE, "")
    check("🔕 the same offload does not shout again inside the window", #ALERTS == 0)

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
    od.folderList = { "/cloud" }
    od.offloads, od.baseline, od.lastResult, od.lastSweep = {}, nil, nil, nil
    od.storeRead = true

    -- 🔌 6.228.0 — THE WATCH STARTS IN warm, NEVER setup: a profile's
    -- settings land AFTER setup returns, so a watcher started there can
    -- only ever be stopped by an override and never started.
    EVERY, AFTER = {}, {}
    od.stopWatch()
    local r0 = reportText()
    check("🔌 a watch that is WANTED and not running says so, loudly",
          r0:find("WANTED but NOT RUNNING", 1, true) ~= nil, r0:sub(1, 400))

    M.warm()
    check("M.warm arms the repeating sweep", #EVERY == 1 and EVERY[1].secs == od.sweepEvery,
          #EVERY)
    check("…and one first sweep shortly after boot, so nothing at boot waits on find",
          #AFTER >= 1)
    local r1 = reportText()
    check("⏳ 'no sweep has finished yet' is its own state, never 'all clear'",
          r1:find("no sweep has finished yet", 1, true) ~= nil, r1:sub(1, 400))
    check("⏳ …and so is 'nothing to compare against yet'",
          r1:find("nothing to compare against yet", 1, true) ~= nil, r1:sub(1, 600))

    -- a finished sweep: the numbers come from it and the report SAYS so
    TASKS = {}
    od.sweep("a test")
    TASKS[1].cb(0, "104857600 204800 /cloud/film.mov", "")
    local r2 = reportText()
    check("the report names WHERE its numbers came from",
          r2:find("the background sweep", 1, true) ~= nil, r2:sub(1, 600))
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

    -- the switch, real in both directions
    od.watch = false
    M.warm()
    local r4 = reportText()
    check("the OFF switch is real and the report says it is OFF",
          r4:find("watch  : OFF", 1, true) ~= nil, r4:sub(1, 400))
    od.watch = true
    od.stopWatch()
    od.folderList = nil
end

out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("   ❌ " .. f) end
os.exit(fail == 0 and 0 or 1)
