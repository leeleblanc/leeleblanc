-- =====================================================================
-- test_search_index.lua — the file index ⇪D searches. 6.96.0
-- =====================================================================
--     lua5.4 test_search_index.lua [/path/to/hammerspoon]
--
-- The requirement is EFFICIENCY, so that is what is held here:
--   B1  THE BUILD IS A CHILD PROCESS AT IDLE PRIORITY — nice -n 19,
--       /usr/bin/find, capped with head, atomic publish via mv. The
--       main thread's total cost is composing one shell string.
--   B2  ONE BUILD AT A TIME; a failed build keeps the previous index.
--   S1  A KEYSTROKE TOUCHES NO DISK — the file loads once, lazily.
--   S2  EVERY WORD MUST MATCH; a FILENAME hit outranks a folder hit;
--       shorter paths outrank deeper ones; the limit is a hard cap.
--   S3  EXTENDING THE QUERY NARROWS THE LAST RESULT instead of
--       rescanning everything (and gets the same answers).
--   S4  A MAC WITH NO INDEX, OR NO hs.task, DEGRADES TO NOTHING —
--       empty results and honest console lines, never a throw.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        local line = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        failures[#failures + 1] = line
        io.write("   ❌ " .. line .. "\n")
    end
end
local function out(s) io.write(s) end

-- ---- a controllable Mac ----------------------------------------------
local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function saidLine(s)
    for _, l in ipairs(printed) do if l:find(s, 1, true) then return true end end
end

local TASKS, TIMERS, MTIME = {}, {}, nil
hs = {
    task = { new = function(cmd, cb, args)
        local t = { cmd = cmd, cb = cb, args = args, started = false }
        function t:start() self.started = true ; return self end
        TASKS[#TASKS + 1] = t
        return t
    end },
    timer = { doEvery = function(secs, fn)
        local t = { secs = secs, fn = fn }
        TIMERS[#TIMERS + 1] = t
        return t
    end },
    fs = { attributes = function(_, what)
        if what == "modification" then return MTIME end
    end },
}
_G.diag = { say = function() end, warn = function() end }

-- A REAL scratch folder: load() reads a real file, which is the point.
local TMP = (os.getenv("TMPDIR") or "/tmp"):gsub("/$", "")
            .. "/hs-index-test-" .. tostring(os.time())
os.execute("mkdir -p '" .. TMP .. "'")

local HOME  = "/Users/lee"
local CLOUD = HOME .. "/Library/CloudStorage/OneDrive-Personal"
local PROVIDED = {}
local CORE = {
    homeDir = HOME, cloudDir = CLOUD, logsDir = TMP, hostTag = "Test-Mac",
    provide = function(n, f) PROVIDED[n] = f end,
}

local M, IX
local function boot(core)
    printed, TASKS, TIMERS, PROVIDED = {}, {}, {}, {}
    M = dofile(HS .. "/modules/search_index.lua")
    M.setup(core or CORE)
    IX = M.idx
end

local INDEX_LINES = {
    HOME .. "/Documents/Report Q3.docx",
    HOME .. "/Documents/Budget 2026.xlsx",
    HOME .. "/Desktop/report-final.pdf",
    CLOUD .. "/Projects/report/meeting notes.txt",
    CLOUD .. "/Projects/plans/Roadmap.docx",
    HOME .. "/Documents/deep/nested/very/report copy.docx",
}
local function writeIndex(lines)
    local f = assert(io.open(TMP .. "/search_index-Test-Mac.txt", "w"))
    for _, l in ipairs(lines or INDEX_LINES) do f:write(l, "\n") end
    f:close()
end
local function rmIndex() os.remove(TMP .. "/search_index-Test-Mac.txt") end

local function names(rows)
    local t = {}
    for _, r in ipairs(rows or {}) do t[#t + 1] = r.name end
    return table.concat(t, ",")
end

-- =====================================================================
out("── test_search_index (module at " .. HS .. ")\n")

-- ---- 1. contract ----------------------------------------------------
out("   1. module contract\n")
boot()
check("module name", M.name == "Search Index", M.name)
check("cheatsheet names ⇪D — this feeds the launcher, it binds no key",
      (M.cheatsheet.title or ""):find("⇪D", 1, true))
check("index file is per-Mac, in the OneDrive Logs folder",
      IX.file == TMP .. "/search_index-Test-Mac.txt", IX.file)
check("service index.search provided",  type(PROVIDED["index.search"]) == "function")
check("service index.rebuild provided", type(PROVIDED["index.rebuild"]) == "function")
check("_G.fileIndex published for ⇪D", _G.fileIndex == IX)
check("_G.indexNow and _G.fileIndexReport published",
      type(_G.indexNow) == "function" and type(_G.fileIndexReport) == "function")
check("config table exposed for profile overrides", M.config == IX)
check("warm() defined — nothing scans at boot", type(M.warm) == "function")

-- ---- 2. the build script (B1) ---------------------------------------
out("   2. the build: nice'd find, pruned, capped, atomic\n")
local script = IX.buildScript()
check("runs at idle priority", script:find("/usr/bin/nice -n 19", 1, true))
check("walks the OneDrive root", script:find(CLOUD, 1, true))
check("…to the bottom — no depth cap on documents", (function()
    for line in script:gmatch("[^\n]+") do
        if line:find(CLOUD, 1, true) then
            return not line:find("-maxdepth", 1, true)
        end
    end
end)())
check("walks the home folder", (function()
    for line in script:gmatch("[^\n]+") do
        if line:find("find '" .. HOME .. "'", 1, true) then return true end
    end
end)())
check("…capped at homeDepth", script:find("-maxdepth " .. IX.homeDepth, 1, true))
check("prunes dot-folders, node_modules, Library and .app bundles",
      script:find("'.*'", 1, true) and script:find("node_modules", 1, true)
      and script:find("'Library'", 1, true) and script:find("'*.app'", 1, true))
check("each root is capped with head — the file cannot grow unbounded",
      script:find("head -n " .. IX.maxEntries, 1, true))
check("find's stderr is discarded — an unreadable folder is not an event",
      script:find("2>/dev/null", 1, true))
check("writes a temp file and RENAMES — a half-built index never publishes",
      script:find(IX.file .. ".tmp", 1, true)
      and script:find("/bin/mv -f", 1, true))
check("reports the line count on stdout", script:find("/usr/bin/wc -l", 1, true))
check("a root with a quote in it is shell-quoted, not spliced", (function()
    IX.extraRoots = { "/Users/lee/My 'Docs'" }
    local s2 = IX.buildScript()
    IX.extraRoots = {}
    return s2:find("My '\\''Docs'\\''", 1, true) ~= nil
end)())

-- ---- 3. the build task (B2) -----------------------------------------
out("   3. one build at a time; failure keeps the old index\n")
boot()
check("rebuild starts a /bin/sh task", IX.rebuild() and #TASKS == 1
      and TASKS[1].cmd == "/bin/sh" and TASKS[1].started, #TASKS)
check("…with -c and the script", TASKS[1].args[1] == "-c"
      and TASKS[1].args[2]:find("/usr/bin/find", 1, true) ~= nil)
check("a second rebuild while one runs is refused", IX.rebuild() == false)
IX.entries = { "stale" }
TASKS[1].cb(0, "  1234 \n", "")
check("success: count recorded, memory invalidated for a lazy reload",
      IX.lastBuild.count == 1234 and IX.entries == nil,
      IX.lastBuild and IX.lastBuild.count)
check("…and one honest console line", saidLine("🗂 Search Index: rebuilt — 1234"))
check("…which is NOT error-shaped (it must not land in a banner)",
      not saidLine("fail") and not saidLine("error"))
printed = {}
check("after the callback a new rebuild may start", IX.rebuild() and #TASKS == 2)
IX.entries = { "the previous index" }
TASKS[2].cb(1, "", "find: boom")
check("failure: says so and keeps the previous in-memory index",
      saidLine("⚠️ Search Index") and IX.entries[1] == "the previous index")

-- ---- 4. search (S1, S2) ---------------------------------------------
out("   4. search: lazy load, every word, names beat folders\n")
boot()
writeIndex()
check("nothing is loaded before the first search", IX.entries == nil)
local rows = IX.search("report")
check("the first search loads the file", type(IX.entries) == "table"
      and #IX.entries == #INDEX_LINES, IX.entries and #IX.entries)
check("it finds every path containing the word", #rows == 4, names(rows))
check("FILENAME hits outrank the folder-only hit", (function()
    -- "meeting notes.txt" matches only via its folder; it must be last
    return rows[#rows].name == "meeting notes.txt"
end)(), names(rows))
check("shorter paths outrank deeper ones among name hits",
      rows[1].name == "Report Q3.docx"
      and rows[3].name == "report copy.docx", names(rows))
check("every word must match — 'report q3' is one file",
      #IX.search("report q3") == 1
      and IX.search("report q3")[1].name == "Report Q3.docx")
check("matching is case-insensitive", #IX.search("REPORT Q3") == 1)
check("the folder column shortens home to ~", (function()
    local r = IX.search("report q3")[1]
    return r.dir == "~/Documents", r.dir
end)())
check("below minQuery letters the answer is empty, instantly",
      #IX.search("re") == 0)
check("the limit is a hard cap", #IX.search("report", 2) == 2)
check("a nonsense query answers empty, not nil", (function()
    local r = IX.search("zzzqqq")
    return type(r) == "table" and #r == 0
end)())

-- ---- 5. narrowing (S3) ----------------------------------------------
out("   5. each added letter narrows the last answer\n")
boot()
writeIndex()
IX.search("rep")
local afterRep = #IX.lastIds
check("the match set is cached for narrowing", afterRep == 4, afterRep)
local narrowed = IX.search("report q")
check("extending the query kept only the survivors",
      #IX.lastIds == 1, #IX.lastIds)
check("…and the narrowed answer equals a from-scratch answer", (function()
    local viaCache = names(narrowed)
    IX.lastQ, IX.lastIds = nil, nil
    return viaCache == names(IX.search("report q")), viaCache
end)())
check("deleting letters falls back to a full pass (correctly)", (function()
    IX.search("report q3")
    return #IX.search("rep") == 4
end)())

-- ---- 6. freshness ---------------------------------------------------
out("   6. warm() rebuilds only a stale index, then keeps a timer\n")
boot()
MTIME = os.time() - 1 * 3600          -- one hour old: fresh
M.warm()
check("a fresh index is left alone", #TASKS == 0, #TASKS)
check("…but the timer is armed at the rebuild cadence",
      #TIMERS == 1 and TIMERS[1].secs == IX.rebuildHours * 3600,
      TIMERS[1] and TIMERS[1].secs)
boot()
MTIME = os.time() - 48 * 3600         -- two days old: stale
M.warm()
check("a stale index triggers a rebuild", #TASKS == 1)
boot()
MTIME = nil                           -- no file at all
M.warm()
check("a MISSING index triggers the first build", #TASKS == 1)

-- ---- 7. the hostile shapes (S4) -------------------------------------
out("   7. no index file, no hs.task: degrade, never throw\n")
boot()
rmIndex()
local okMiss, r = pcall(IX.search, "report")
check("no index file: search answers empty without throwing",
      okMiss and type(r) == "table" and #r == 0)
local savedTask = hs.task
hs.task = nil
boot()
check("no hs.task: rebuild refuses politely", IX.rebuild() == false)
local okNow = pcall(_G.indexNow)
check("…and _G.indexNow explains instead of throwing",
      okNow and saidLine("not started"))
hs.task = savedTask
boot()
writeIndex()
local rep = _G.fileIndexReport()
check("the report names the file, the age and every root",
      type(rep) == "string" and rep:find(IX.file, 1, true) ~= nil
      and rep:find(CLOUD, 1, true) ~= nil
      and rep:find("depth " .. IX.homeDepth, 1, true) ~= nil)

-- ---- cleanup --------------------------------------------------------
rmIndex()
os.execute("rmdir '" .. TMP .. "' 2>/dev/null")

-- =====================================================================
out(string.format("\n── test_search_index: %d passed, %d failed\n", pass, fail))
if fail > 0 then
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
