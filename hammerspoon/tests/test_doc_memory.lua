-- =====================================================================
-- test_doc_memory.lua — what Word had open, remembered for the quit panel
-- =====================================================================
--     lua5.4 test_doc_memory.lua [/path/to/hammerspoon]
--
-- Runs modules/doc_memory.lua against a stubbed hs (timed AX reads only,
-- a fake app watcher, held timers) and REAL files in a temp Logs folder:
-- the sample (AXWindows → AXDocument, timed, capped), the diff and its
-- CSV rows, the JSON memory and its reload, the quit path, what the quit
-- panel is offered and how a reopen runs `open`, the watchdog rest, the
-- unwatched-app and no-Accessibility stand-downs, the report, the
-- app_watcher wiring, and the sentries.

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

local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p '" .. TMP .. "'")
local HOST = "TestMac"
local function read(path)
    local f = io.open(path, "r"); if not f then return nil end
    local s = f:read("a"); f:close(); return s
end

-- ---- the stub Mac ------------------------------------------------------
local AX = true
local TIMERS, TASKS, TIMEOUTS, ALERTS, NOTICES = {}, {}, 0, {}, {}
local WATCH_FN = nil
local ATIME, ASTEP = 0, 1000000     -- 1 ms per clock read
local WARNED = {}

-- a fake app whose AX element answers AXWindows with fake windows
local function mkApp(name, windows)
    local app = { _name = name, _windows = windows or {} }
    function app:name() return self._name end
    app._ax = {}
    function app._ax:setTimeout() TIMEOUTS = TIMEOUTS + 1; return self end
    function app._ax:attributeValue(k)
        if k ~= "AXWindows" then return nil end
        if app._windows == "slow" then return nil end
        local out = {}
        for _, w in ipairs(app._windows) do
            local el = { _w = w }
            function el:setTimeout() TIMEOUTS = TIMEOUTS + 1; return self end
            function el:attributeValue(kk)
                if kk == "AXDocument" then return self._w.url end
                if kk == "AXTitle" then return self._w.title end
            end
            out[#out + 1] = el
        end
        return out
    end
    return app
end
local WORD = mkApp("Microsoft Word", {
    { url = "file:///Users/lee/Docs/Budget%20Q3.docx", title = "Budget Q3.docx" },
    { url = nil, title = "Font palette" },                         -- not a document
    { url = "file://localhost/Users/lee/Docs/Notes.docx", title = "Notes.docx" },
})
local SAFARI = mkApp("Safari", {})
local FRONT = WORD

-- a tiny JSON, enough for the memory file round-trip
local function encode(v, ind)
    local t = type(v)
    if t == "table" then
        local isArr = #v > 0 or next(v) == nil
        local parts = {}
        if isArr then
            for _, x in ipairs(v) do parts[#parts + 1] = encode(x) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do parts[#parts + 1] = string.format("%q:%s", k, encode(v[k])) end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then return string.format("%q", v)
    else return tostring(v) end
end
local function decode(s)
    -- the memory file is the only thing decoded here: turn it into Lua
    local lua = s:gsub("%[%]", "{}"):gsub("%[", "{"):gsub("%]", "}")
                 :gsub('("[^"]-")%s*:', "[%1]=")
    local fn = load("return " .. lua)
    return fn and fn() or nil
end

hs = {
    accessibilityState = function() return AX end,
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    timer = {
        absoluteTime = function() ATIME = ATIME + ASTEP; return ATIME end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn }
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
    json = { encode = function(v) return encode(v) end, decode = decode },
    application = {
        frontmostApplication = function() return FRONT end,
        watcher = {
            activated = 1, terminated = 4, launched = 3,
            new = function(fn)
                WATCH_FN = fn
                return { start = function(s) return s end, stop = function(s) return s end }
            end,
        },
    },
    axuielement = {
        applicationElement = function(app) return app and app._ax or nil end,
    },
}
_G.diag = { say = function() end, warn = function(_, m) WARNED[#WARNED + 1] = m end, err = function() end }
_G.notices = { record = function(a, b, c) NOTICES[#NOTICES + 1] = { a, b, c } end }
_G.findAppBundle = function(name)
    if name == "Microsoft Word" then return "/Applications/Microsoft Word.app" end
end

local function drain()
    local n = 0
    local keep = {}
    while #TIMERS > 0 do
        local t = table.remove(TIMERS, 1)
        if t.every or (t.secs or 0) >= 1 then keep[#keep + 1] = t
        elseif not t.stopped then t.fn(); n = n + 1 end
    end
    for _, t in ipairs(keep) do TIMERS[#TIMERS + 1] = t end
    return n
end

local PROVIDED = {}
local core = {
    logsDir = TMP, hostTag = HOST,
    csvQuote = function(v) return '"' .. tostring(v or ""):gsub('"', '""') .. '"' end,
    provide = function(name, fn) PROVIDED[name] = fn end,
}
local function boot()
    TIMERS, TASKS, WARNED, ALERTS = {}, {}, {}, {}
    local chunk = assert(loadfile(HS .. "/modules/doc_memory.lua"))
    local M = chunk()
    M.setup(core)
    return M, M.config
end

out("=== 1. Module shape ===\n")
local M, dm = boot()
check("name/family/config/global", M.name == "Open Documents" and M.family == "files"
      and M.config == dm and _G.docMemory == dm)
check("services: docs.openFor / reopen / quit / sample / report",
      PROVIDED["docs.openFor"] and PROVIDED["docs.reopen"] and PROVIDED["docs.quit"]
      and PROVIDED["docs.sample"] and PROVIDED["docs.report"])
check("Word, Excel, PowerPoint, Preview are watched; Safari is not",
      dm.apps["Microsoft Word"] and dm.apps["Microsoft Excel"] and dm.apps["Microsoft PowerPoint"]
      and dm.apps["Preview"] and not dm.apps["Safari"])
check("boot: an app watcher, a periodic timer (held), and Word in front → a settle timer",
      dm.appWatcher ~= nil and dm.everyTimer and dm.everyTimer.secs == 60
      and dm.sampleTimer and dm.sampleTimer.secs == 0.5 and dm.frontApp == "Microsoft Word")
check("files named for the Mac, in Logs",
      dm.jsonFile == TMP .. "/open_documents-" .. HOST .. ".json"
      and dm.csvFile == TMP .. "/open_documents-" .. HOST .. ".csv")

out("=== 2. A sample ===\n")
TIMEOUTS = 0
drain()
check("the settle timer sampled Word: two documents, the palette ignored", (function()
    local d = dm.open["Microsoft Word"]
    return d and d["/Users/lee/Docs/Budget Q3.docx"] and d["/Users/lee/Docs/Notes.docx"]
       and d["/Users/lee/Docs/Budget Q3.docx"].title == "Budget Q3.docx" and dm.samples == 1
end)())
check("%20 decoded, file://localhost stripped", dm.pathFromUrl("file:///a/b%20c.docx") == "/a/b c.docx"
      and dm.pathFromUrl("file://localhost/x.docx") == "/x.docx" and dm.pathFromUrl("https://x") == nil
      and dm.pathFromUrl(nil) == nil)
check("EVERY AX read was timed (app + 3 windows)", TIMEOUTS == 4, TIMEOUTS)
check("the hand-off timer is released after it fires", dm.sampleTimer == nil)
local csv = read(dm.csvFile)
check("CSV: a header, then one 'opened' row per document",
      csv and csv:sub(1, #dm.HEADER) == dm.HEADER
      and select(2, csv:gsub('"Microsoft Word",opened,', "")) == 2, csv)
check("JSON memory written", read(dm.jsonFile) and read(dm.jsonFile):find("Budget Q3.docx", 1, true) ~= nil)
check("last sample line", dm.last and dm.last.app == "Microsoft Word" and dm.last.n == 2 and dm.last.why == "boot")

-- one closes: the diff logs 'closed'
WORD._windows = { WORD._windows[1] }
dm.sample("test")
csv = read(dm.csvFile)
check("a document that went away is logged 'closed' and forgotten",
      csv:find(',closed,"/Users/lee/Docs/Notes.docx"', 1, true) ~= nil
      and dm.open["Microsoft Word"]["/Users/lee/Docs/Notes.docx"] == nil)
check("an unchanged sample writes nothing new", (function()
    local before = csv
    dm.sample("again")
    return read(dm.csvFile) == before
end)())
check("maxWindows caps the reads", (function()
    dm.maxWindows = 1
    local many = mkApp("Microsoft Word", {
        { url = "file:///a.docx", title = "a" }, { url = "file:///b.docx", title = "b" } })
    FRONT = many
    dm.sample("cap")
    FRONT = WORD
    local d = dm.open["Microsoft Word"]
    dm.maxWindows = 8
    return d["/a.docx"] and not d["/b.docx"]
end)())
dm.sample("back")

out("=== 3. Stand-downs ===\n")
FRONT = SAFARI
local ok, why = dm.sample("safari")
check("an app not in dm.apps is never read", ok == false and why == "front app not watched")
FRONT = WORD
AX = false
ok, why = dm.sample("no ax")
check("no Accessibility: no sample, says so", ok == false and why == "no Accessibility")
AX = true
WORD._windows = "slow"
ok, why = dm.sample("slow")
check("a silent AXWindows: no sample, memory untouched",
      ok == false and tostring(why):find("no window list") and dm.open["Microsoft Word"]["/Users/lee/Docs/Budget Q3.docx"])
WORD._windows = { { url = "file:///Users/lee/Docs/Budget%20Q3.docx", title = "Budget Q3.docx" } }
check("the watchdog: two slow samples in a minute → a rest, one notice, a held rest timer", (function()
    ASTEP = 400 * 1000000
    dm.sample("slow 1"); dm.sample("slow 2")
    ASTEP = 1000000
    local resting = dm.restUntil ~= nil and dm.restTimer ~= nil and NOTICES[#NOTICES] and NOTICES[#NOTICES][2] == "resting"
    local okR, whyR = dm.sample("while resting")
    return resting and okR == false and whyR == "resting"
end)())
check("the rest timer ends the rest", (function()
    for _, t in ipairs(TIMERS) do
        if t == dm.restTimer then t.fn() end
    end
    return dm.restUntil == nil and dm.restTimer == nil and dm.sample("after") == true
end)())

out("=== 4. Quit, offer, reopen ===\n")
WATCH_FN("Microsoft Word", hs.application.watcher.terminated, WORD)
check("quit: the list moves to lastOpen, 'quit' rows logged, open cleared",
      dm.open["Microsoft Word"] == nil and dm.lastOpen["Microsoft Word"]
      and #dm.lastOpen["Microsoft Word"].docs == 1
      and read(dm.csvFile):find(',quit,"/Users/lee/Docs/Budget Q3.docx"', 1, true) ~= nil)
local offer = PROVIDED["docs.openFor"]("Microsoft Word")
check("docs.openFor after a quit offers the remembered documents",
      #offer == 1 and offer[1].path == "/Users/lee/Docs/Budget Q3.docx" and offer[1].title == "Budget Q3.docx")
check("docs.openFor for an app never seen → {}", #PROVIDED["docs.openFor"]("Numbers") == 0)
local done, n = PROVIDED["docs.reopen"]("Microsoft Word")
check("docs.reopen runs `open -a <bundle> <docs…>` in a held task", (function()
    local t = TASKS[#TASKS]
    return done == true and n == 1 and t and t.bin == "/usr/bin/open" and t.started
       and t.args[1] == "-a" and t.args[2] == "/Applications/Microsoft Word.app"
       and t.args[3] == "/Users/lee/Docs/Budget Q3.docx" and dm.openTasks[#dm.openTasks] == t
end)(), TASKS[#TASKS] and table.concat(TASKS[#TASKS].args, " "))
check("docs.reopen with one path opens just that one", (function()
    local d = PROVIDED["docs.reopen"]("Microsoft Word", "/x.docx")
    return d == true and TASKS[#TASKS].args[3] == "/x.docx" and #TASKS[#TASKS].args == 3
end)())
check("an app with no bundle found is opened by name", (function()
    PROVIDED["docs.reopen"]("Numbers", { "/n.numbers" })
    return TASKS[#TASKS].args[2] == "Numbers"
end)())
check("nothing remembered → false, why", (function()
    local d, w = PROVIDED["docs.reopen"]("Keynote")
    return d == false and w:find("nothing remembered", 1, true)
end)())
check("a quit memory older than dm.keepQuit is not offered", (function()
    dm.lastOpen["Microsoft Word"].at = os.time() - 8 * 86400
    local o = PROVIDED["docs.openFor"]("Microsoft Word")
    dm.lastOpen["Microsoft Word"].at = os.time()
    return #o == 0
end)())
check("the memory survives a reload (JSON round-trip)", (function()
    local M2, dm2 = boot()
    return dm2.lastOpen["Microsoft Word"] and #PROVIDED["docs.openFor"]("Microsoft Word") == 1
end)())
M, dm = boot()
check("activation of a watched app schedules a sample; of Safari clears frontApp", (function()
    drain()
    WATCH_FN("Microsoft Word", hs.application.watcher.activated, WORD)
    local a = dm.frontApp == "Microsoft Word" and dm.sampleTimer ~= nil
    drain()
    WATCH_FN("Safari", hs.application.watcher.activated, SAFARI)
    return a and dm.frontApp == nil
end)())
check("the periodic timer samples only while a watched app is in front", (function()
    local before = dm.samples
    dm.everyTimer.fn(); drain()
    local none = dm.samples == before
    WATCH_FN("Microsoft Word", hs.application.watcher.activated, WORD); drain()
    before = dm.samples
    dm.everyTimer.fn(); drain()
    return none and dm.samples == before + 1
end)())

out("=== 5. Report and no Accessibility at boot ===\n")
local rep = _G.docMemoryReport()
check("report names the state, the apps, the last sample and the files",
      rep:find("state         : watching", 1, true) and rep:find("Microsoft Excel", 1, true)
      and rep:find("last sample   : ", 1, true) and rep:find(dm.csvFile, 1, true), rep)
AX = false
NOTICES = {}
M, dm = boot()
check("Accessibility off at boot: no watcher, a notice, the disk memory still serves the panel",
      dm.appWatcher == nil and NOTICES[1] and NOTICES[1][2] == "Accessibility off"
      and #PROVIDED["docs.openFor"]("Microsoft Word") == 1)
AX = true

out("=== 6. app_watcher wiring (6.169.0) ===\n")
local aw = read(HS .. "/modules/app_watcher.lua")
check("the quit panel asks docs.openFor and offers 📂 Spawn with its documents + 📄 Reopen rows",
      aw:find('_G.service.has("docs.openFor")', 1, true) and aw:find('action = "spawnDocs"', 1, true)
      and aw:find('"📄 Reopen "', 1, true) and aw:find('action = "doc", path = d.path', 1, true))
check("…and reopens through docs.reopen, never its own `open`",
      aw:find('"docs.reopen", appName, paths', 1, true) ~= nil)

out("=== 7. Source sentries ===\n")
local src = read(HS .. "/modules/doc_memory.lua")
local code = src:gsub("%-%-[^\n]*", "")
check("🚨 no hs.window reads — axuielement WITH setTimeout only",
      code:find("hs%.window") == nil and code:find("setTimeout") ~= nil and code:find("allWindows") == nil)
check("no work in the watcher callback: it hands off to a timer",
      code:find("dm%.scheduleSample%(\"activated\"%)") ~= nil)
check("every timer held", code:find("dm%.sampleTimer = t") and code:find("dm%.everyTimer = et")
      and code:find("dm%.restTimer = %(ok and t%) or nil"))
check("never hs.execute, never io.popen", code:find("hs%.execute") == nil and code:find("io%.popen") == nil)
check("returns its module table", src:find("\nreturn M", 1, true) ~= nil)

-- =====================================================================
out("\n=== 8. 🚨 A STORE IS A FILE, AND A FILE CAN BE ANY SHAPE (6.198.1) ===\n")
-- =====================================================================
-- LL's Console: an error at doc_memory.lua:363 — `d.title` on something
-- that is not a table — thrown from the app_watcher quit panel, i.e. the
-- moment he quits Word. dm.load() took data.open whole on the strength
-- of its OUTER type alone, so one value a level down that is not a table
-- reached every reader. And the report walks the same structure with
-- pairs(), so a bad store also took out the diagnostic that would have
-- named it.
do
    local mine = 0
    local function ck(label, cond, extra) mine = mine + 1 check(label, cond, extra) end

    -- ---- pure, no Mac anywhere near it --------------------------------
    local clean, bad = dm.cleanOpen({
        ["Microsoft Word"] = {
            ["/good.docx"] = { title = "Good", seen = 12 },
            ["/poison.docx"] = 363,               -- LL's crash, exactly
        },
        ["Excel"] = 7,                            -- a whole app gone wrong
        [5]       = { ["/x"] = { title = "n" } }, -- a key that is not a name
    })
    ck("cleanOpen keeps the row that is the right shape",
       clean["Microsoft Word"] and clean["Microsoft Word"]["/good.docx"]
       and clean["Microsoft Word"]["/good.docx"].title == "Good")
    ck("…drops the value that is not a table", clean["Microsoft Word"]
       and clean["Microsoft Word"]["/poison.docx"] == nil)
    ck("…drops an app whose whole entry is wrong", clean["Excel"] == nil)
    ck("…drops a key that is not an app name", clean[5] == nil)
    ck("…and COUNTS what it dropped rather than repairing in silence",
       bad == 3, bad)
    ck("cleanOpen on something that is not a table at all is empty, not a throw",
       (function() local c, n = dm.cleanOpen(42) ; return next(c) == nil and n == 0 end)())
    ck("a title that is not a string falls back to the path", (function()
        local c = dm.cleanOpen({ Word = { ["/a.docx"] = { title = 9 } } })
        return c.Word["/a.docx"].title == "/a.docx"
    end)())

    local cl2, bad2 = dm.cleanLastOpen({
        Word  = { at = 100, docs = { { path = "/a.docx", title = "A" }, 12 } },
        Excel = { at = 100, docs = "not a list" },
        Pages = { at = "not a number", docs = { { path = "/p.pages" } } },
    })
    ck("cleanLastOpen keeps the good document and drops the junk one",
       #cl2.Word.docs == 1 and cl2.Word.docs[1].path == "/a.docx")
    ck("…drops a record whose docs are not a list", cl2.Excel == nil)
    ck("…and a time it cannot read becomes 0 rather than throwing later",
       cl2.Pages and cl2.Pages.at == 0, cl2.Pages and cl2.Pages.at)
    ck("…counting both", bad2 == 2, bad2)

    -- ---- and the whole way through, from the file on disk ------------
    local f = io.open(dm.jsonFile, "w")
    f:write('{"open":{"Microsoft Word":{"/Users/lee/Docs/Real.docx":'
            .. '{"title":"Real","seen":5},"/Users/lee/Docs/Bad.docx":363}},'
            .. '"lastOpen":{"Pages":{"at":1,"docs":[7]}}}')
    f:close()
    dm.open, dm.lastOpen, dm.loadDropped = {}, {}, nil
    ck("a poisoned store still LOADS", dm.load() == true)

    local okOpen, list = pcall(PROVIDED["docs.openFor"], "Microsoft Word")
    ck("🚨 docs.openFor does not throw on it — LL's doc_memory.lua:363",
       okOpen == true, tostring(list))
    ck("…and it still offers the document that was fine",
       okOpen and #list == 1 and list[1].path == "/Users/lee/Docs/Real.docx",
       okOpen and #list)
    local okQuit = pcall(PROVIDED["docs.openFor"], "Pages")
    ck("…and the quit memory with a junk entry is safe to ask for too",
       okQuit == true)

    local okRep, rep = pcall(_G.docMemoryReport)
    ck("🚨 the REPORT survives it too — it walks the same structure, so a"
       .. " bad store used to take out the tool that would name it",
       okRep == true, tostring(rep))
    ck("…and it says the rows were dropped, with the count",
       okRep and rep:find("2 row(s) DROPPED", 1, true) ~= nil,
       okRep and rep:match("store%s*:[^\n]*"))
    ck("…and says plainly what that costs — a reopen, never a file",
       okRep and rep:find("never anything on disk", 1, true) ~= nil)

    -- A clean store must NOT read like a repaired one, and neither may
    -- read like a store that was never opened (6.196.1's rule).
    local g = io.open(dm.jsonFile, "w")
    g:write('{"open":{"Microsoft Word":{"/Users/lee/Docs/Real.docx":{"title":"Real"}}}}')
    g:close()
    dm.open, dm.lastOpen, dm.loadDropped = {}, {}, nil
    dm.load()
    ck("a store with nothing wrong says so, and differently",
       _G.docMemoryReport():find("every row the shape it should be", 1, true) ~= nil)
    dm.loadDropped = nil
    ck("…and a store never read says THAT, differently again",
       _G.docMemoryReport():find("not read yet", 1, true) ~= nil)

    check("§8 ran every one of its checks", mine == 20, mine)
end

os.execute("rm -rf '" .. TMP .. "'")
print = realPrint
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do io.write("  ✗ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
