-- =====================================================================
-- test_master_log.lua — every store in one log, and its FTS5 index
-- =====================================================================
--     lua5.4 test_master_log.lua [/path/to/hammerspoon]
--
-- Runs modules/master_log.lua against a stubbed hs and REAL files in a
-- temp Logs folder: the seven readers, the fixed column layout, newest
-- first, the day window, the row cap, the slicing (a build spans event-
-- loop turns and never runs twice at once), the write-ledger
-- registration, the sqlite3 task (its exact arguments), the FTS query
-- builder, the search callback both ways, the report, and the sentries.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local PRINTED = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

-- ---- a temp Logs folder ------------------------------------------------
local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p '" .. TMP .. "'")
local HOST = "TestMac"
local function write(name, body)
    local f = assert(io.open(TMP .. "/" .. name, "w")); f:write(body); f:close()
end
local function read(path)
    local f = io.open(path, "r"); if not f then return nil end
    local s = f:read("a"); f:close(); return s
end

-- ---- the stub Mac ------------------------------------------------------
local NOW = os.time()
local function stamp(secsAgo) return os.date("%Y-%m-%d %H:%M:%S", NOW - secsAgo) end
local CLOCK = NOW
local TIMERS, TASKS, JSON_DECODE_FAIL = {}, {}, false
local SQLITE_EXISTS = true
local ATTRS = {}

local function drain(limit)
    local n = 0
    while #TIMERS > 0 and n < (limit or 1000) do
        local t = table.remove(TIMERS, 1)
        if not t.stopped and (t.secs or 0) < 1 then t.fn(); n = n + 1
        elseif not t.stopped then ATTRS.kept = (ATTRS.kept or 0) + 1 end
    end
    return n
end

-- a tiny JSON: enough for the clipboard array and sqlite3's -json reply
local function jsonDecode(s)
    if JSON_DECODE_FAIL then error("bad json") end
    local rows = {}
    for obj in s:gmatch("{(.-)}") do
        local r = {}
        for k, v in obj:gmatch('"([%w_]+)"%s*:%s*"(.-)"') do r[k] = v end
        for k, v in obj:gmatch('"([%w_]+)"%s*:%s*(%d+)') do r[k] = tonumber(v) end
        rows[#rows + 1] = r
    end
    return rows
end

hs = {
    timer = {
        secondsSinceEpoch = function() return CLOCK end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, every = true }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    task = {
        new = function(bin, cb, args)
            local t = { bin = bin, cb = cb, args = args, started = false }
            function t:start() self.started = true; return true end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    fs = {
        attributes = function(p)
            if p == "/usr/bin/sqlite3" then return SQLITE_EXISTS and { mode = "file" } or nil end
            return nil
        end,
        mkdir = function(p) ATTRS.mkdir = p; return true end,
    },
    json = { decode = jsonDecode },
}
_G.diag = { say = function() end, warn = function(_, m) ATTRS.warned = m end, err = function() end }

-- core: the real csvQuote/splitCSVLine shape (quoted fields, "" inside)
local function csvQuote(v)
    local s = tostring(v or ""):gsub("[\r\n]+", " "):gsub('"', '""')
    return '"' .. s .. '"'
end
local function splitCSVLine(line)
    local out, i, n = {}, 1, #line
    while i <= n + 1 do
        if line:sub(i, i) == '"' then
            local j, buf = i + 1, {}
            while j <= n do
                local c = line:sub(j, j)
                if c == '"' then
                    if line:sub(j + 1, j + 1) == '"' then buf[#buf + 1] = '"'; j = j + 2
                    else break end
                else buf[#buf + 1] = c; j = j + 1 end
            end
            out[#out + 1] = table.concat(buf)
            i = j + 2
        else
            local j = line:find(",", i, true) or (n + 1)
            out[#out + 1] = line:sub(i, j - 1)
            i = j + 1
        end
    end
    return out
end

local PROVIDED = {}
local core = {
    logsDir = TMP, hostTag = HOST, csvQuote = csvQuote, splitCSVLine = splitCSVLine,
    provide = function(name, fn) PROVIDED[name] = fn end,
    warnWriteFailed = function(l) ATTRS.writeFailed = l end,
}

local function boot()
    TIMERS, TASKS, PRINTED = {}, {}, {}
    _G.rewrittenFiles = nil
    local chunk = assert(loadfile(HS .. "/modules/master_log.lua"))
    local M = chunk()
    M.setup(core)
    return M, M.config
end

-- ---- the stores ------------------------------------------------------------
write("file_changes-" .. HOST .. ".csv",
      "timestamp,file_name,new_name,present_location,moved_location,event,epoch\n"
      .. stamp(100) .. ',"Budget, Q3.docx","","/Users/lee/Docs/Budget, Q3.docx","",renamed,' .. (NOW - 100) .. "\n"
      .. stamp(400 * 86400) .. ',"old.txt","","/tmp/old.txt","",moved,' .. (NOW - 400 * 86400) .. "\n")
write("activity_history-" .. HOST .. ".csv",
      "date,app,title,seconds,url\n"
      .. stamp(170) .. ',"Microsoft Word","Budget, Q3.docx — Word",120,""\n')
write("chrome_history-" .. HOST .. ".csv",
      "date,time,title,url,visits,profile\n"
      .. os.date("%Y-%m-%d", NOW - 200) .. "," .. os.date("%H:%M", NOW - 200) .. ',"Asana — Tasks","https://app.asana.com/0/1",3,Default\n')
write("image_text-" .. HOST .. ".csv", "date,text\n" .. stamp(150) .. ',"invoice 4471 total"\n')
write("app_updates-" .. HOST .. ".csv",
      "checkedAt,app,installed,latest,status,brewManaged\n" .. stamp(160) .. ",Alfred,5.5,5.6,behind,yes\n")
write("open_documents-" .. HOST .. ".csv",
      "timestamp,app,event,path,epoch\n" .. stamp(130) .. ',"Microsoft Word",opened,"/Users/lee/Docs/Budget, Q3.docx",' .. (NOW - 130) .. "\n")
write("clipboard_history-" .. HOST .. ".json",
      '[{"date":"' .. os.date("%b %d %H:%M", NOW - 5) .. '","text":"copied words"},{"date":"nonsense","text":"x"}]')

out("=== 1. Module shape ===\n")
local M, ml = boot()
check("name/family/config", M.name == "Master Log" and M.family == "find" and M.config == ml and _G.masterLog == ml)
check("five services provided", PROVIDED["masterLog.build"] and PROVIDED["masterLog.search"]
      and PROVIDED["masterLog.rows"] and PROVIDED["masterLog.report"])
check("the .db lives under ~/Library/Application Support, never in Logs",
      ml.dbPath:find("/Library/Application Support/", 1, true) and not ml.dbPath:find(TMP, 1, true))
check("the CSV lives in Logs, named for the Mac", ml.file == TMP .. "/master_log-" .. HOST .. ".csv")
check("boot arms ONE first-build timer (held), nothing runs yet",
      #TIMERS == 1 and TIMERS[1].secs == 120 and ml.firstTimer == TIMERS[1] and ml.builds == 0)

out("=== 2. The build ===\n")
local started = ml.build("test")
check("build starts and slices through timers", started and ml.building == true)
local n = drain()
check("the build finished across event-loop turns", ml.building == false and ml.builds == 1 and n >= 1, n)
check("seven sources read", (function()
    local c = 0
    for _ in pairs(ml.counts) do c = c + 1 end
    return c == 7
end)(), (function() local t = {} for k, v in pairs(ml.counts) do t[#t + 1] = k .. "=" .. v end return table.concat(t, " ") end)())
check("rows per source: files 1 (the 400-day-old one left out), activity 1, chrome 1, ocr 1, updates 1, documents 1, clipboard 1 (nonsense date dropped)",
      ml.counts.files == 1 and ml.counts.activity == 1 and ml.counts.chrome == 1 and ml.counts.ocr == 1
      and ml.counts.updates == 1 and ml.counts.documents == 1 and ml.counts.clipboard == 1)
check("newest first", ml.rows[1].source == "clipboard" and ml.rows[#ml.rows].source == "chrome",
      ml.rows[1].source .. " … " .. ml.rows[#ml.rows].source)
local body = read(ml.file)
check("the file exists with the fixed header", body and body:sub(1, #ml.HEADER) == ml.HEADER)
check("a comma inside a title survives quoting", body and body:find('"Budget, Q3.docx"', 1, true) ~= nil)
check("chrome's date+time columns became one timestamp", (function()
    for _, r in ipairs(ml.rows) do
        if r.source == "chrome" then
            return r.app == "Google Chrome" and r.action == "visited" and r.path == "https://app.asana.com/0/1"
                   and r.timestamp:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:00$") ~= nil
        end
    end
end)())
check("the file tracker's own epoch column is used as-is", (function()
    for _, r in ipairs(ml.rows) do
        if r.source == "files" then return r.epoch == NOW - 100 and r.action == "renamed" and r.app == "Finder" end
    end
end)())
check("write ledger told it is rewritten whole", _G.rewrittenFiles and _G.rewrittenFiles[ml.file] ~= nil)
check("report reads right", (function()
    local r = _G.masterLogReport()
    return r:find("last build    : ", 1, true) and r:find("7 rows", 1, true) and r:find("clipboard  : 1", 1, true)
end)(), _G.masterLogReport())

out("=== 3. The index task ===\n")
check("sqlite3 was asked to build the FTS5 index, in a task, with the CSV imported", (function()
    local t = TASKS[#TASKS]
    if not (t and t.bin == "/usr/bin/sqlite3" and t.started) then return false end
    local a = table.concat(t.args, " | ")
    return a:find("USING fts5", 1, true) and a:find(".mode csv", 1, true)
       and a:find('.import --skip 1 "' .. ml.file .. '" log', 1, true) and a:find("DELETE FROM log", 1, true)
       and ml.indexState == "building…" and ml.indexTask == t
end)(), TASKS[#TASKS] and table.concat(TASKS[#TASKS].args, " | "))
TASKS[#TASKS].cb(0, "", "")
check("exit 0 → built", ml.indexState:find("^built ") ~= nil and ml.indexTask == nil, ml.indexState)
ml.build("again"); drain()
TASKS[#TASKS].cb(1, "", "Error: no such module: fts5\n")
check("exit 1 → failed, with sqlite3's words", ml.indexState:find("failed %(exit 1%): Error: no such module: fts5$") ~= nil, ml.indexState)
SQLITE_EXISTS = false
local before = #TASKS
ml.build("no sqlite"); drain()
check("no sqlite3 binary: the CSV still builds, no task, the report says why",
      #TASKS == before and ml.builds == 3 and ml.indexState:find("unavailable — no /usr/bin/sqlite3", 1, true) ~= nil)
SQLITE_EXISTS = true
ml.index = false
ml.build("index off"); drain()
check("ml.index = false: no task, said so", #TASKS == before and ml.indexState:find("off", 1, true) ~= nil)
ml.index = true

out("=== 4. Guards ===\n")
ml.build("one"); local second = ml.build("two")
check("a build already running is not started twice", second == false and ml.building == true)
drain()
ml.maxRows = 3
ml.build("cap"); drain()
check("ml.maxRows keeps the newest N", #ml.rows == 3 and ml.rows[1].source == "clipboard")
ml.maxRows = 200000
ml.days = 0.0001
ml.build("window"); drain()
check("ml.days shrinks the window", #ml.rows == 0, #ml.rows)
ml.days = 180
ml.maxRows = "5"
ml.build("string knob"); drain()
check("a knob as a string still works (num)", #ml.rows == 5)
ml.maxRows = 200000
check("a source file that is missing counts 0 and never throws", (function()
    os.remove(TMP .. "/image_text-" .. HOST .. ".csv")
    ml.build("missing"); drain()
    return ml.counts.ocr == 0 and ml.lastErr == nil
end)())
check("an unwritable target is reported, not thrown", (function()
    local keep = ml.file
    ml.file = TMP .. "/no/such/dir/master.csv"
    ml.build("bad path"); drain()
    local bad = ml.lastErr and ml.lastErr:find("cannot write", 1, true) and ATTRS.writeFailed == "master log"
    ml.file = keep
    return bad
end)(), ml.lastErr)
ml.sliceBudget = -1
ml.build("bad budget"); drain()
check("a negative slice budget falls back and still finishes", ml.building == false and ml.lastErr == nil)
ml.sliceBudget = 0.04

out("=== 5. Search ===\n")
check("FTS query: words quoted, last one a prefix", ml.ftsQuery('budget q3') == '"budget" "q3"*')
check("FTS query: a double quote is doubled", ml.ftsQuery('say "hi"') == '"say" """hi"""*')
check("FTS query: empty → nil", ml.ftsQuery("   ") == nil)
local got, gotErr
local okS = ml.search("budget q3", 5, function(rows, err) got, gotErr = rows, err end)
check("search runs sqlite3 -json with the MATCH and the limit", (function()
    local t = TASKS[#TASKS]
    if not (okS and t and t.started and t.args[2] == "-json" and t.args[3] == ml.dbPath) then return false end
    return t.args[4]:find([[WHERE log MATCH '"budget" "q3"*' ORDER BY epoch DESC LIMIT 5;]], 1, true) ~= nil
end)(), TASKS[#TASKS] and TASKS[#TASKS].args[4])
TASKS[#TASKS].cb(0, '[{"timestamp":"2026-09-05 08:20:12","source":"files","app":"Finder","action":"renamed","text":"Budget","path":"/x","epoch":1}]', "")
check("rows come back decoded, newest first", got and #got == 1 and got[1].app == "Finder" and gotErr == nil)
ml.search("x", 5, function(rows, err) got, gotErr = rows, err end)
TASKS[#TASKS].cb(1, "", "Error: no such table: log\n")
check("a failed query hands back the error", got == nil and gotErr == "Error: no such table: log", gotErr)
ml.search("x", 5, function(rows, err) got, gotErr = rows, err end)
TASKS[#TASKS].cb(0, "", "")
check("no hits → empty table, no error", got and #got == 0 and gotErr == nil)
check("an apostrophe in the words is SQL-escaped", (function()
    ml.search("lee's", 5, function() end)
    return TASKS[#TASKS].args[4]:find([[MATCH '"lee''s"*']], 1, true) ~= nil
end)(), TASKS[#TASKS].args[4])
check("_G.masterLogSearch prints the hits", (function()
    PRINTED = {}
    _G.masterLogSearch("budget")
    TASKS[#TASKS].cb(0, '[{"timestamp":"t","source":"files","app":"Finder","action":"renamed","text":"Budget","path":"/x","epoch":1}]', "")
    return PRINTED[1] and PRINTED[1]:find('1 hit for "budget"', 1, true) and PRINTED[2] and PRINTED[2]:find("Finder", 1, true)
end)(), table.concat(PRINTED, " / "))
SQLITE_EXISTS = false
local nope
ml.search("x", 5, function(rows, err) nope = err end)
check("no sqlite3: the callback says so at once", nope == "no /usr/bin/sqlite3", nope)
SQLITE_EXISTS = true

out("=== 6. Boot timers ===\n")
M, ml = boot()
TIMERS[1].fn()
check("the first timer builds and arms the periodic one (held)", ml.builds == 1 or ml.building,
      tostring(ml.builds) .. " " .. tostring(ml.building))
drain()
check("periodic timer held at ml.every", ml.timer and ml.timer.secs == 900 and ml.timer.every == true)
ml.enabled = false
check("_G.masterLogBuild() honours ml.enabled = false", _G.masterLogBuild() == false)
ml.enabled = true

out("=== 7. Source sentries ===\n")
local src = read(HS .. "/modules/master_log.lua")
local code = src:gsub("%-%-[^\n]*", "")
check("never hs.execute / io.popen — sqlite3 only ever runs in an hs.task",
      code:find("hs%.execute") == nil and code:find("io%.popen") == nil and code:find("hs%.task%.new") ~= nil)
check("never hs.window.filter", code:find("window%.filter") == nil)
check("every timer HELD (firstTimer, timer, sliceTimer)",
      code:find("ml%.firstTimer = ft") and code:find("ml%.timer = et") and code:find("ml%.sliceTimer = t"))
check("registers with the write ledger", code:find("_G%.rewrittenFiles%[ml%.file%]") ~= nil)
check("never writes a store it reads", (function()
    for _, name in ipairs({ "file_changes", "activity_history", "chrome_history", "image_text",
                            "app_updates", "open_documents", "clipboard_history" }) do
        -- the only io.open(..., "w") is on ml.file
    end
    local writes = 0
    for _ in code:gmatch('io%.open%([^\n]-"w"%)') do writes = writes + 1 end
    return writes == 1 and code:find('io%.open%(ml%.file, "w"%)') ~= nil
end)())
check("returns its module table", src:find("\nreturn M", 1, true) ~= nil)

os.execute("rm -rf '" .. TMP .. "'")
print = realPrint
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do io.write("  ✗ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
