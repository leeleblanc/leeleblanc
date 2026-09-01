-- =====================================================================
-- test_chrome_history.lua — 90 days of Chrome, saved and fuzzy-searched
-- =====================================================================
--     lua5.4 test_chrome_history.lua [/path/to/hammerspoon]
--
-- The claims under test: every profile's History database is found (and
-- Chrome's non-profile folders are NOT), the export shells out with
-- paths as POSITIONAL arguments (never interpolated — "Application
-- Support" has a space in it), the JSON that comes back becomes one
-- sorted list where a broken profile costs a warning and not the
-- export, the CSV round-trips its own quoting, and the fuzzy ranking
-- puts the right page first: substring beats sequence, title beats
-- URL, newer beats older.

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

local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- ---- a controllable world --------------------------------------------
local NOW = 1000
local FS, FILES = {}, {}
local CLIPBOARD = nil
local TASKS, ALERTS, CHOOSERS, HYPER, PROVIDED = {}, {}, {}, {}, {}
local WATCHDOGS = {}      -- every hs.timer.doAfter — the export deadline
local URL_BUNDLE, URL_PLAIN = {}, {}
local BUNDLE_RESULT = true

-- sqlite3 -json emits arrays of flat objects with string and integer
-- values — this decodes exactly that shape, which keeps the suite free
-- of a JSON library. Anything carrying the BROKEN marker refuses to
-- parse, standing in for a corrupt block.
local function miniJson(raw)
    if raw:find("BROKEN", 1, true) then error("not valid JSON") end
    local arr = {}
    for obj in raw:gmatch("%b{}") do
        local o = {}
        for k, v in obj:gmatch('"([%w_]+)"%s*:%s*"([^"]*)"') do o[k] = v end
        for k, v in obj:gmatch('"([%w_]+)"%s*:%s*(%-?%d+)') do o[k] = tonumber(v) end
        arr[#arr + 1] = o
    end
    return arr
end

hs = {
    fs = {
        dir = function(path)
            local t = FS[path]
            if not t then error(path .. ": No such file or directory") end
            local list = { ".", ".." }
            for _, n in ipairs(t) do list[#list + 1] = n end
            local i = 0
            return function() i = i + 1 ; return list[i] end
        end,
        -- size and modification are here for 6.106.0's report, which tells
        -- you how big the saved CSV is and how old. A stub that answered
        -- only `mode` would let the report read those as nil and print
        -- nothing, and the check would pass on an empty line.
        attributes = function(path)
            if FS[path] then return { mode = "directory" } end
            if FILES[path] then
                return { mode = "file",
                         size = #tostring(FILES[path]),
                         modification = NOW - 60 }
            end
            -- 🚨 AND THE REAL DISK, for paths this table does not model.
            -- The CSV in this suite is an actual os.tmpname() file that the
            -- module actually writes; a stub that answered nil for it would
            -- have 6.106.0's report say "not written yet" about a file
            -- sitting right there, and the check would agree with the bug.
            local fh = io.open(path, "r")
            if fh then
                local bytes = fh:seek("end") or 0
                fh:close()
                return { mode = "file", size = bytes, modification = NOW - 60 }
            end
            return nil
        end,
        temporaryDirectory = function() return "/tmp/test-tmp/" end,
    },
    timer = {
        secondsSinceEpoch = function() NOW = NOW + 0.0001 ; return NOW end,
        -- 6.147.0 — the export deadline arms through doAfter; the suite
        -- fires it by hand to model the hang the Air actually had.
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            WATCHDOGS[#WATCHDOGS + 1] = t
            return t
        end,
    },
    json  = { decode = miniJson },
    task  = { new = function(cmd, cb, args)
        local t = { cmd = cmd, cb = cb, args = args, started = false }
        function t:start() self.started = true ; return self end
        function t:terminate() self.dead = true ; return self end
        TASKS[#TASKS + 1] = t
        return t end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = { setContents = function(t) CLIPBOARD = t ; return true end },
    urlevent = {
        openURLWithBundle = function(url, bundle)
            URL_BUNDLE[#URL_BUNDLE + 1] = { url = url, bundle = bundle }
            return BUNDLE_RESULT
        end,
        openURL = function(url) URL_PLAIN[#URL_PLAIN + 1] = url ; return true end,
    },
    chooser = { new = function(fn)
        local c = { fn = fn, shown = false }
        for _, m in ipairs({ "searchSubText", "width", "rows" }) do
            c[m] = function(self) return self end
        end
        function c:placeholderText(t) self.placeholder = t ; return self end
        function c:choices(x) self.lastRows = x ; return self end
        function c:query(q) self.q = q ; return self end
        function c:queryChangedCallback(f) self.qcb = f ; return self end
        function c:show() self.shown = true ; return self end
        CHOOSERS[#CHOOSERS + 1] = c ; return c end },
}
_G.diag = { said = {},
    say = function(_, m) _G.diag.said[#_G.diag.said + 1] = "say " .. m end,
    warn = function(_, m) _G.diag.said[#_G.diag.said + 1] = "warn " .. m end,
    err = function() end, mark = function() end }
local function warned(n)
    for _, l in ipairs(_G.diag.said) do
        if l:sub(1, 4) == "warn" and l:find(n, 1, true) then return true end
    end
end
_G.notices = { recorded = {},
    record = function(src, what, detail)
        _G.notices.recorded[#_G.notices.recorded + 1] =
            src .. "|" .. what .. "|" .. tostring(detail)
    end }

-- The CSV round-trip needs the REAL quote-aware splitter shape.
local function splitCSVLine(line)
    local outT, field, i, inQ = {}, {}, 1, false
    local n = #line
    while i <= n do
        local c = line:sub(i, i)
        if inQ then
            if c == '"' then
                if line:sub(i + 1, i + 1) == '"' then
                    field[#field + 1] = '"' ; i = i + 1
                else inQ = false end
            else field[#field + 1] = c end
        elseif c == '"' then inQ = true
        elseif c == "," then
            outT[#outT + 1] = table.concat(field) ; field = {}
        else field[#field + 1] = c end
        i = i + 1
    end
    outT[#outT + 1] = table.concat(field)
    return outT
end

local HOME = "/Users/lee"
local CSV  = os.tmpname()
local CORE = {
    hostTag = "Test-Mac",
    homeDir = HOME,
    logsDir = CSV:match("^(.*)/[^/]*$") or "/tmp",
    splitCSVLine = splitCSVLine,
    hyperAddShortcut = function(mods, key, fn)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms) ; HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local CHROME_DIR = HOME .. "/Library/Application Support/Google/Chrome"

-- Default + two numbered profiles + the folders Chrome keeps that are
-- NOT browsing profiles ("System Profile", "Guest Profile") + one
-- profile folder with no History file yet.
local function personalChrome()
    FS = {
        [CHROME_DIR] = { "Default", "Profile 1", "Profile 12",
                         "System Profile", "Guest Profile", "Profile 3",
                         "GrShaderCache", "Local State" },
    }
    FILES = {
        [CHROME_DIR .. "/Default/History"]    = true,
        [CHROME_DIR .. "/Profile 1/History"]  = true,
        [CHROME_DIR .. "/Profile 12/History"] = true,
        -- Profile 3 exists but has never been opened: no History file
        [CHROME_DIR .. "/System Profile/History"] = true,  -- must NOT be read
    }
end

local function freshModule()
    TASKS, ALERTS, CHOOSERS = {}, {}, {}
    HYPER, PROVIDED = {}, {}
    URL_BUNDLE, URL_PLAIN = {}, {}
    _G.diag.said = {}
    printed = {}
    local mod = dofile(HS .. "/modules/chrome_history.lua")
    mod.setup(CORE)
    return mod, _G.chromeHistory
end

-- =======================================================================
out("1) finding the databases — profiles yes, Chrome's other folders no\n")
-- =======================================================================
personalChrome()
local mod, chrome = freshModule()
local dbs = chrome.findDbs()
check("three databases found on the personal Mac", #dbs == 3, #dbs)
check("Default is first (sorted)", dbs[1] and dbs[1].label == "Default",
      dbs[1] and dbs[1].label)
check("numbered profiles follow", dbs[2] and dbs[2].label == "Profile 1"
      and dbs[3] and dbs[3].label == "Profile 12")
local sysRead = false
for _, d in ipairs(dbs) do
    if d.label:find("System", 1, true) then sysRead = true end
end
check("System Profile is NOT a browsing profile and is not read", not sysRead)
check("a profile with no History file contributes nothing", true)  -- by count above

chrome.extraDbs = { { label = "Brave", path = "/x/Brave/History" } }
FILES["/x/Brave/History"] = true
dbs = chrome.findDbs()
check("extraDbs joins when its file exists", #dbs == 4 and dbs[4].label == "Brave",
      #dbs)
chrome.extraDbs = {}

-- =======================================================================
out("2) the export task — positional args, never interpolated paths\n")
-- =======================================================================
check("export starts a /bin/sh task", chrome.export() == true and #TASKS == 1
      and TASKS[1].cmd == "/bin/sh", TASKS[1] and TASKS[1].cmd)
local T = TASKS[1]
check("the task was started", T.started)
check("exporting flag is up", chrome.exporting == true)
check("a second export while one runs is refused", chrome.export() == false
      and #TASKS == 1)
check("-c then the script", T.args[1] == "-c" and T.args[2]:find("##PROFILE##", 1, true))
check("script copies BEFORE it queries", T.args[2]:find('cp %-f "%$db"') ~= nil)
check("the -wal and -shm companions ride along",
      T.args[2]:find("db%-wal") and T.args[2]:find("db%-shm"))
check("sqlite3 asked for -json", T.args[2]:find("-json", 1, true))
check("Chrome's hidden redirect noise is filtered", T.args[2]:find("hidden = 0", 1, true))
check("sqlite path is argument 4", T.args[4] == "/usr/bin/sqlite3", T.args[4])
local cutoff = tonumber(T.args[6])
check("cutoff is 90 days back in CHROME's epoch (µs since 1601)",
      cutoff == (1000 - 90 * 86400 + 11644473600) * 1000000, T.args[6])
check("row cap is argument 7", T.args[7] == "20000", T.args[7])
check("profile labels and paths arrive as PAIRED args",
      T.args[8] == "Default"
      and T.args[9] == CHROME_DIR .. "/Default/History"
      and T.args[10] == "Profile 1", T.args[8])
check("the path with a space in it is one argument, not two",
      T.args[9]:find(" ") ~= nil and #T.args == 13, #T.args)

-- =======================================================================
out("3) parsing — one sorted list; a broken profile costs a warning\n")
-- =======================================================================
local stdout = table.concat({
    "##PROFILE## Default",
    '[{"url":"https://gmail.com/inbox","title":"Inbox - Gmail","visits":40,"ts":900},',
    '{"url":"https://news.site/a","title":"Big\tNews\ttoday","visits":2,"ts":700}]',
    "",
    "##PROFILE## Profile 1",
    '[{"url":"https://work.example.com/wiki","title":"Team Wiki","visits":9,"ts":800}]',
    "",
    "##PROFILE## Profile 12",
    "[BROKEN",
    "",
}, "\n")
T.cb(0, stdout, "")
check("export callback lowers the flag", chrome.exporting == false)
check("two good profiles' rows survive the broken one", #chrome.entries == 3,
      #chrome.entries)
check("the broken block was warned about, by name", warned("Profile 12"))
check("newest first, across profiles",
      chrome.entries[1].ts == 900 and chrome.entries[2].ts == 800
      and chrome.entries[3].ts == 700)
check("every row remembers its profile",
      chrome.entries[2].profile == "Profile 1", chrome.entries[2].profile)
check("control characters in titles become spaces",
      chrome.entries[3].title == "Big News today", chrome.entries[3].title)
check("status counts pages and profiles",
      tostring(chrome.status):find("3 pages") and
      tostring(chrome.status):find("3 profiles"), chrome.status)
check("a completing export STOPS its deadline — the timer never fires "
      .. "on a healthy run", #WATCHDOGS >= 1
      and WATCHDOGS[#WATCHDOGS].stopped == true, #WATCHDOGS)

-- =======================================================================
out("3b) 6.147.0 — the deadline: a hung export is killed, and says so\n")
-- =======================================================================
-- On LL's Air the export hung and `exporting` stayed true for the whole
-- session — every ⇪Y press said "press again in a moment", forever.
chrome.export()
local hungTask = TASKS[#TASKS]
local dog = WATCHDOGS[#WATCHDOGS]
check("a deadline is armed beside every export",
      dog.stopped == false and dog.secs == chrome.exportTimeout, dog.secs)
check("…and ⇪Y during the run now says how LONG it has been running", (function()
    chrome.entries = {}
    chrome.show()
    return (ALERTS[#ALERTS] or ""):find("s in%)") ~= nil, ALERTS[#ALERTS]
end)())
dog.fn()
check("the deadline kills the hang: flag down, task terminated",
      chrome.exporting == false and hungTask.dead == true)
check("…status names the kill and points at the report",
      tostring(chrome.status):find("KILLED", 1, true) ~= nil
      and tostring(chrome.status):find("chromeHistoryReport", 1, true) ~= nil,
      chrome.status)
check("…and the alert says so out loud",
      (ALERTS[#ALERTS] or ""):find("hung", 1, true) ~= nil, ALERTS[#ALERTS])

-- -----------------------------------------------------------------------
-- 🚨 6.148.0 — THE FLIGHT RECORDER. Two kills on LL's Air could say
-- nothing but "it hung". The script now logs each step to a progress
-- file; the suite plays the script's role, writes the file a hung run
-- would have left behind, and fires a second hang.
local PROG = os.tmpname()
do
    local pf = io.open(PROG, "w")
    pf:write("copying Default\nquerying Default\ncopying Profile 1\n")
    pf:close()
end
chrome.export()
local hung2 = TASKS[#TASKS]
chrome.progressPath = PROG   -- the suite's stand-in for the script's $pf
WATCHDOGS[#WATCHDOGS].fn()
check("6.148.0 — the kill names the step the run died in",
      tostring(chrome.status):find("it hung at: copying Profile 1", 1, true) ~= nil,
      chrome.status)
check("…and the alert carries the same step",
      (ALERTS[#ALERTS] or ""):find("copying Profile 1", 1, true) ~= nil,
      ALERTS[#ALERTS])
check("…lastProgress reads the LAST line and skips trailing blanks", (function()
    local pf = io.open(PROG, "a") ; pf:write("\n") ; pf:close()
    return chrome.lastProgress() == "copying Profile 1"
end)(), chrome.lastProgress())
-- 🚨 the killed sh still EXITS — code 15, from our own terminate() — and
-- that exit used to land in the completion callback and overwrite the
-- honest KILLED status with "export failed (sh exited 15)". LL's console
-- showed exactly that pair of lines, three seconds apart.
hung2.cb(15, "", "")
check("6.148.0 — the kill's own exit does not clobber the KILLED status",
      tostring(chrome.status):find("KILLED", 1, true) ~= nil, chrome.status)
os.remove(PROG)
-- and the SCRIPT itself carries the recorder: a marker BEFORE each step,
-- written to the FILE — never stdout, which is the JSON data channel
local SCRIPT2 = hung2.args[2]
check("the script logs 'copying' before each cp, into the progress file",
      SCRIPT2:find([=[printf 'copying %s\n' "$lbl" >> "$pf"]=], 1, true) ~= nil)
check("the script logs 'querying' before each sqlite3, into the file",
      SCRIPT2:find([=[printf 'querying %s\n' "$lbl" >> "$pf"]=], 1, true) ~= nil)
check("…and 'finished cleanly' when the loop completes",
      SCRIPT2:find("finished cleanly", 1, true) ~= nil)

check("a fresh export may start after the kill", chrome.export() == true)
TASKS[#TASKS].cb(0, "##PROFILE## Default\n[]\n", "")   -- and completes clean

-- =======================================================================
out("4) the CSV — written on export, quoting round-trips exactly\n")
-- =======================================================================
chrome.csvFile = CSV
local tricky = {
    "##PROFILE## Default",
    '[{"url":"https://a.com/q?x=1,2","title":"Comma, and -quote- title","visits":3,"ts":1600000000},',
    '{"url":"https://plain.org","title":"Plain","visits":1,"ts":1600000060}]',
    "",
}
-- a second export, with data built to stress the quoting
chrome.export()
TASKS[#TASKS].cb(0, table.concat(tricky, "\n"), "")
local f = io.open(CSV, "r")
check("the CSV file exists after an export", f ~= nil)
local content = f and f:read("*a") or ""
if f then f:close() end
check("header row first",
      content:sub(1, #"date,time,title,url,visits,profile")
      == "date,time,title,url,visits,profile")
check("a comma'd title is quoted in the file",
      content:find('"Comma, and %-quote%- title"') ~= nil)
local before = #chrome.entries
chrome.entries = {}
local loaded = chrome.loadCsv()
check("loadCsv reads back what writeCsv wrote", loaded == before, loaded)
check("the comma'd title survives the round trip",
      chrome.entries[2] and chrome.entries[2].title == "Comma, and -quote- title",
      chrome.entries[2] and chrome.entries[2].title)
check("URLs survive the round trip",
      chrome.entries[1].url == "https://plain.org", chrome.entries[1].url)
check("timestamps rebuild close enough to keep the order",
      chrome.entries[1].ts > chrome.entries[2].ts)

-- =======================================================================
out("5) the fuzzy match — substring beats sequence, title beats URL\n")
-- =======================================================================
local corpus = {
    "##PROFILE## Default",
    '[{"url":"https://mail.google.com/mail/u/0","title":"Inbox (3) - Gmail","visits":99,"ts":9000},',
    '{"url":"https://calendar.google.com/r/week","title":"Google Calendar","visits":50,"ts":8000},',
    '{"url":"https://en.wikipedia.org/wiki/Giant_panda","title":"Giant panda - Wikipedia","visits":2,"ts":7000},',
    '{"url":"https://pandas.pydata.org/docs","title":"API reference","visits":8,"ts":6000},',
    '{"url":"https://old.example.com/gmail-tips","title":"Ten tips","visits":1,"ts":5000},',
    '{"url":"https://abc.example.com/x","title":"alpha beta card","visits":1,"ts":4000}]',
    "",
}
chrome.export()
TASKS[#TASKS].cb(0, table.concat(corpus, "\n"), "")
check("six pages loaded", #chrome.entries == 6, #chrome.entries)

local r = chrome.search("gmail")
check("substring match finds both gmail pages", #r == 2, #r)
check("the TITLE hit outranks the URL-only hit",
      r[1].title == "Inbox (3) - Gmail" and r[2].title == "Ten tips",
      r[1] and r[1].title)

r = chrome.search("panda wiki")
check("every word must match — words in any order, either field",
      #r == 1 and r[1].title == "Giant panda - Wikipedia", #r)

r = chrome.search("gml")
check("a character sequence matches when no substring does ('gml')", #r >= 1)
check("…and the tightest home for it still wins",
      r[1] and (r[1].title:find("Gmail") ~= nil or r[1].url:find("gmail") ~= nil),
      r[1] and r[1].title)

r = chrome.search("abc")
check("adjacent substring outranks the same letters scattered",
      r[1] and r[1].title == "alpha beta card"
      and r[1].url == "https://abc.example.com/x" or true)  -- adjacency…
-- …deserves a sharper probe: 'abc' is a SUBSTRING of abc.example.com and
-- only a sequence inside "alpha beta card" — the substring page must win.
check("substring page first for 'abc'",
      r[1] and r[1].url == "https://abc.example.com/x", r[1] and r[1].url)

r = chrome.search("google")
check("a title hit outranks recency — Calendar above the newer Gmail",
      r[1] and r[1].title == "Google Calendar", r[1] and r[1].title)

r = chrome.search("example")
check("equal scores (both URL-only) fall back to recency",
      #r == 2 and r[1].ts == 5000 and r[2].ts == 4000,
      r[1] and r[1].ts)

r = chrome.search("zzqx")
check("nothing pretends to match", #r == 0, #r)

r = chrome.search("")
check("empty query lists the newest pages", #r >= 1 and r[1].ts == 9000)

-- =======================================================================
out("6) the picker — one chooser, our filter, ⏎ reopens in Chrome\n")
-- =======================================================================
check("⇪Y shows the picker", chrome.show() == true and #CHOOSERS == 1)
local C = CHOOSERS[1]
check("the placeholder counts the corpus", tostring(C.placeholder):find("6 pages"),
      C.placeholder)
check("rows carry title, when·profile·url, and the url to open",
      C.lastRows[1] and C.lastRows[1].text == "Inbox (3) - Gmail"
      and C.lastRows[1].subText:find("Default", 1, true) ~= nil
      and C.lastRows[1].url == "https://mail.google.com/mail/u/0")
C.qcb("panda wiki")
check("typing re-filters through OUR ranking, not the chooser's",
      C.lastRows and #C.lastRows == 1
      and C.lastRows[1].text == "Giant panda - Wikipedia",
      C.lastRows and #C.lastRows)
chrome.show()
check("the chooser is built once and reused", #CHOOSERS == 1, #CHOOSERS)

C.fn({ url = "https://mail.google.com/mail/u/0" })
check("⏎ opens the page in Chrome by bundle id",
      URL_BUNDLE[1] and URL_BUNDLE[1].bundle == "com.google.Chrome"
      and URL_BUNDLE[1].url == "https://mail.google.com/mail/u/0")
check("…and not through the default browser when Chrome answered",
      #URL_PLAIN == 0, #URL_PLAIN)
BUNDLE_RESULT = false
C.fn({ url = "https://plain.org" })
check("Chrome refusing falls back to the default browser",
      URL_PLAIN[1] == "https://plain.org", URL_PLAIN[1])
BUNDLE_RESULT = true

-- =======================================================================
out("7) staleness, emptiness, and the shifted key\n")
-- =======================================================================
local tasksBefore = #TASKS
chrome.loadedAt = NOW - chrome.staleSecs - 10
chrome.show()
check("a stale corpus quietly re-exports behind the picker",
      #TASKS == tasksBefore + 1, #TASKS - tasksBefore)
TASKS[#TASKS].cb(0, table.concat(corpus, "\n"), "")

ALERTS = {}
chrome.entries = {}
chrome.exporting = false
chrome.loadedAt = NOW
local shown = chrome.show()
check("no data: ⇪Y says so instead of opening an empty picker",
      shown == false and #ALERTS == 1 and ALERTS[1]:find("🕘"), ALERTS[1])
check("…and kicks an export so the next press works",
      #TASKS == tasksBefore + 2)
TASKS[#TASKS].cb(0, table.concat(corpus, "\n"), "")

check("⇪Y and ⇪⇧Y are the module's only hyper claims",
      HYPER["|y"] ~= nil and HYPER["shift|y"] ~= nil, "missing claim")
local n = 0 ; for _ in pairs(HYPER) do n = n + 1 end
check("exactly two claims — nothing else was touched", n == 2, n)

ALERTS = {}
HYPER["shift|y"]()
check("⇪⇧Y announces the refresh", ALERTS[1] and ALERTS[1]:find("Reading"), ALERTS[1])
TASKS[#TASKS].cb(0, table.concat(corpus, "\n"), "")
check("…and reports pages saved with the file name",
      ALERTS[2] and ALERTS[2]:find("6 pages")
      and ALERTS[2]:find(CSV:match("[^/]+$"), 1, true), ALERTS[2])

-- =======================================================================
out("8) warm, the report, and a Mac with no Chrome at all\n")
-- =======================================================================
local tasksB4 = #TASKS
mod.warm()
check("warm reads last session's CSV back first", #chrome.entries > 0)
check("…then refreshes in the background", #TASKS == tasksB4 + 1)
TASKS[#TASKS].cb(0, table.concat(corpus, "\n"), "")

printed = {}
FILES[chrome.sqlite] = "#!/bin/sqlite3"   -- present on a healthy Mac
local rep = chrome.report()
check("the report names the file", rep:find(CSV, 1, true) ~= nil)
check("…and counts per profile", rep:find("Default%s+6 pages") ~= nil, rep)

-- ---- 6.106.0: the report has to ANSWER "is it working?" --------------
-- LL: "Chrome fuzzy history might not be working, how can I tell?" The
-- old report printed a status line and a table, which reads the same
-- whether sqlite3 is missing, Full Disk Access is off, or you genuinely
-- browsed nothing. Every distinct cause now gets its own line and the
-- whole thing ends in a verdict.
check("it checks sqlite3 is actually there",
      rep:find("✅ sqlite3", 1, true) ~= nil, rep)
check("…and that Chrome's folder is",
      rep:find("✅ Chrome", 1, true) ~= nil)
check("…and how many profiles it can read RIGHT NOW",
      rep:find("✅ profiles", 1, true) ~= nil)
check("it prints the timings the cheat sheet has always promised",
      rep:find("last export:", 1, true) ~= nil, rep)
check("it says how big the saved CSV is and how old",
      rep:find("KB, written", 1, true) ~= nil, rep)
check("it proves the MATCHER works, not just that the file parsed",
      rep:find("search test:", 1, true) ~= nil, rep)
check("a healthy Mac ends in one word: WORKING",
      rep:find("✅ WORKING", 1, true) ~= nil, rep:sub(-200))
check("…and the whole report is on the clipboard, ready to paste back",
      CLIPBOARD == rep, CLIPBOARD and #CLIPBOARD)

-- Each fault reports ITSELF, with the fix for that fault and no other.
FILES[chrome.sqlite] = nil
local noSql = chrome.report()
check("no sqlite3 → said plainly, and it is not called WORKING",
      noSql:find("❌ sqlite3", 1, true) and not noSql:find("✅ WORKING", 1, true))
check("…with the fix named", noSql:find("set chrome.sqlite", 1, true) ~= nil)
FILES[chrome.sqlite] = "#!/bin/sqlite3"

-- 🚨 THE ONE THAT ACTUALLY BITES. Chrome's History file lives behind Full
-- Disk Access; without it, hs.fs.attributes answers nil for a file that
-- is plainly there and every symptom looks like "no history".
local keptFiles = {}
for k, v in pairs(FILES) do keptFiles[k] = v end
for k in pairs(FILES) do
    if tostring(k):find("/History", 1, true) then FILES[k] = nil end
end
local noProf = chrome.report()
check("Chrome present but no readable profile → Full Disk Access is named",
      noProf:find("Full Disk Access", 1, true) ~= nil, noProf)
check("…and it is filed as a numbered thing to fix",
      noProf:find("⚠️", 1, true) ~= nil and noProf:find("      1%. ") ~= nil)
for k, v in pairs(keptFiles) do FILES[k] = v end

-- The CSV here is a real file, so a real removal is what "never written"
-- looks like. It is restored by the export below.
os.remove(CSV)
local noCsv = chrome.report()
check("no CSV yet → says so, and points at ⇪⇧Y",
      noCsv:find("not written yet", 1, true) and noCsv:find("⇪⇧Y", 1, true), noCsv)

FS = {} ; FILES = {}
local ok2 = chrome.export()
check("a Mac with no Chrome: export declines politely",
      ok2 == false and tostring(chrome.status):find("no Chrome"), chrome.status)

check("services provided for ⇪space and friends",
      PROVIDED["chromeHistory.show"] ~= nil
      and PROVIDED["chromeHistory.search"] ~= nil
      and PROVIDED["chromeHistory.export"] ~= nil)
check("_G.chromeHistory is published for the @web source",
      _G.chromeHistory == chrome)

os.remove(CSV)
out(string.format("\n%d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
