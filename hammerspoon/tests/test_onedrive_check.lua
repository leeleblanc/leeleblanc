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
hs = {
    fs = { attributes = function() return nil end,
           dir = function() return function() return nil end end },
    task = { new = function(bin, cb, args)
        local t = { bin = bin, cb = cb, args = args, started = false }
        function t:start() self.started = true ; TASKS[#TASKS + 1] = self ; return true end
        function t:terminate() self.killed = true end
        return t
    end },
    timer = { doAfter = function(_, fn)
        return { stop = function() end, fire = fn } end },
}
_G.diag = { say = function(m) SAID[#SAID + 1] = m end, warn = function() end }

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
    local f = assert(io.open(HS .. "/modules/onedrive_check.lua", "r"))
    local src = f:read("a") ; f:close()
    check("the sentry read something — a sentry over an empty haystack is"
          .. " green and measures nothing (6.313.0)", #src > 2000, #src)
    -- comments are stripped first, because the comments here QUOTE the
    -- calls they forbid in order to explain the rule (6.262.0 · 6.280.0)
    local code = src:gsub("%-%-[^\n]*", "")
    check("🚨 nothing in this module opens a file", code:find("io%.open") == nil)
    check("🚨 nothing in this module reads one", code:find(":read%(") == nil)
    check("🚨 …and it does not shell out to one either",
          code:find("/bin/cat") == nil and code:find("io%.lines") == nil)
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
    M.setup({ logsDir = "/logs", cloudDir = "/cloud", homeDir = "/home",
              provide = function() end, hyperAddShortcut = function() end })

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
    check("🔬 …and says plainly that nothing here decides what a name MEANS",
          r3:find("decides what any of these names MEAN", 1, true) ~= nil)
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

out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("   ❌ " .. f) end
os.exit(fail == 0 and 0 or 1)
