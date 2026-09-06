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

os.execute("rm -rf '" .. TMP .. "'")
print = realPrint
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do io.write("  ✗ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
