-- =====================================================================
-- test_recent_docs.lua — ⇪I: opened-first documents, learned types,
-- ⇪F aliases, the 9-shelf, the remembered position
-- =====================================================================
--     lua5.4 test_recent_docs.lua [/path/to/hammerspoon]
--
-- The claims under test: the scan runs with every path and query as a
-- POSITIONAL /bin/sh argument, its tab/NUL output parses into merged
-- entries, the learned-types rule admits an opened plist while the
-- unopened thousands stay structurally impossible, ⇪F rename chains
-- become searchable aliases and story lines, the shelf numbers exactly
-- nine by opened-time, the CSV round-trips, and the panel remembers
-- where you dragged it — unless that screen is gone.

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
local TASKS, ALERTS, HYPER, OPENED, PASTED = {}, {}, {}, {}, {}
local WEBVIEWS, SCREENS = {}, {}
local CLAIMS = {}

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
        attributes = function(path)
            if FS[path] then return { mode = "directory" } end
            if FILES[path] then
                local a = { mode = "file" }
                if type(FILES[path]) == "table" then
                    for k, v in pairs(FILES[path]) do a[k] = v end
                end
                return a
            end
            return nil
        end,
    },
    timer = { secondsSinceEpoch = function() NOW = NOW + 0.0001 ; return NOW end },
    task  = { new = function(cmd, cb, args)
        local t = { cmd = cmd, cb = cb, args = args, started = false }
        function t:start() self.started = true ; return self end
        function t:terminate() return self end
        TASKS[#TASKS + 1] = t
        return t end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = { setContents = function(s) PASTED[#PASTED + 1] = s ; return true end },
    open = function(p) OPENED[#OPENED + 1] = p ; return true end,
    drawing = { windowLevels = { floating = 5 } },
    screen = {
        mainScreen = function() return SCREENS[1] end,
        allScreens = function() return SCREENS end,
    },
    webview = {
        usercontent = { new = function(name)
            local uc = { name = name }
            function uc:setCallback(f) self.cb = f ; return self end
            return uc
        end },
        new = function(rect, _, uc)
            local w = { rect = rect, uc = uc, deleted = false }
            for _, m in ipairs({ "windowTitle", "allowTextEntry", "closeOnEscape",
                                 "level", "behaviorAsLabels", "show",
                                 "bringToFront" }) do
                w[m] = function(self) return self end
            end
            function w:html(h) self.page = h ; return self end
            function w:delete() self.deleted = true ; return self end
            function w:frame(f)
                if f then self.rect = f ; return self end
                return self.rect
            end
            WEBVIEWS[#WEBVIEWS + 1] = w
            return w
        end,
    },
}
local function mkScreen(x, y, w, h)
    return { frame = function() return { x = x, y = y, w = w, h = h } end }
end
SCREENS = { mkScreen(0, 0, 1440, 900) }

_G.diag = { said = {},
    say = function(_, m) _G.diag.said[#_G.diag.said + 1] = "say " .. m end,
    warn = function(_, m) _G.diag.said[#_G.diag.said + 1] = "warn " .. m end,
    err = function() end, mark = function() end }
_G.claimEscape = function(name, priority, active, handle)
    CLAIMS[name] = { priority = priority, active = active, handle = handle }
    return true
end

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
local TMPA = os.tmpname()
local TMPB = os.tmpname()
local CORE = {
    hostTag = "Test-Mac",
    homeDir = HOME,
    logsDir = TMPA:match("^(.*)/[^/]*$") or "/tmp",
    splitCSVLine = splitCSVLine,
    hyperAddShortcut = function(mods, key, fn)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms) ; HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function() end,
}

local function freshModule()
    TASKS, ALERTS, HYPER, OPENED, PASTED = {}, {}, {}, {}, {}
    WEBVIEWS, CLAIMS = {}, {}
    _G.movablePanels = {}
    _G.diag.said = {}
    printed = {}
    local mod = dofile(HS .. "/modules/recent_docs.lua")
    mod.setup(CORE)
    local rd = _G.recentDocs
    rd.csvFile, rd.typesFile = TMPA, TMPB
    return mod, rd
end

-- =======================================================================
out("1) the scan: positional arguments, never interpolation\n")
-- =======================================================================
local mod, rd = freshModule()
check("⇪I and ⇪⇧I are the only keys claimed",
      HYPER["|i"] ~= nil and HYPER["shift|i"] ~= nil and (function()
          local n = 0 ; for _ in pairs(HYPER) do n = n + 1 end ; return n == 2
      end)())

check("refresh launches /bin/sh", rd.refresh() and TASKS[1]
      and TASKS[1].cmd == "/bin/sh" and TASKS[1].started)
local args = TASKS[1].args
check("argv: -c, script, name, home, cap, used query, mod query",
      #args == 7 and args[1] == "-c" and args[3] == "hs-recent-docs"
      and args[4] == HOME and args[5] == tostring(rd.cap))
check("the script itself contains NO path and NO query — they are $1..$4",
      not args[2]:find(HOME, 1, true)
      and not args[2]:find("time.now", 1, true))
check("the opened query reaches mdfind through $3, in seconds",
      args[6]:find("kMDItemLastUsedDate", 1, true) ~= nil
      and args[6]:find("$time.now(-" .. (rd.days * 86400) .. ")", 1, true) ~= nil)
check("the seed query names the types, LL's txt/lua/csv included",
      args[7]:find('%*%.docx') ~= nil and args[7]:find('%*%.lua') ~= nil
      and args[7]:find('%*%.csv') ~= nil and args[7]:find('%*%.txt') ~= nil)
check("a second refresh while one runs declines", rd.refresh() == false)

-- =======================================================================
out("2) parsing the scan output — tabs, NUL-marker dates, merging\n")
-- =======================================================================
check("parseDate reads UTC regardless of the machine's zone",
      rd.parseDate("1970-01-02 00:00:00 +0000") == 86400)
check("…and two stamps an hour apart differ by 3600",
      rd.parseDate("2026-08-10 10:00:00 +0000")
      - rd.parseDate("2026-08-10 09:00:00 +0000") == 3600)
check("the '-' null marker is not a date", rd.parseDate("-") == nil)

local BASE = rd.parseDate("2026-08-10 12:00:00 +0000")
NOW = BASE + 3600            -- "now" sits just after the newest open
local function stamp(off)    -- offset seconds → mdls-style UTC string
    return os.date("!%Y-%m-%d %H:%M:%S +0000", BASE + off)
end

local corpus = table.concat({
    "U\t" .. HOME .. "/Documents/Budget FINAL v3.xlsx\t" .. stamp(0) .. "\t" .. stamp(-50),
    "U\t" .. HOME .. "/Documents/report.docx\t" .. stamp(-100) .. "\t" .. stamp(-200),
    "U\t" .. HOME .. "/Library/Preferences/com.microsoft.Outlook.plist\t"
        .. stamp(-300) .. "\t" .. stamp(-300),
    "U\t" .. HOME .. "/Code/init.lua\t" .. stamp(-400) .. "\t" .. stamp(-400),
    "U\t" .. HOME .. "/Desktop/notes.txt\t" .. stamp(-500) .. "\t-",
    "M\t" .. HOME .. "/Documents/report.docx\t-\t" .. stamp(-40),
    "M\t" .. HOME .. "/Downloads/sent to you.xlsx\t-\t" .. stamp(-20),
    "M\t" .. HOME .. "/Downloads/photo.jpg\t-\t" .. stamp(-60),
}, "\n")

local list, byPath = rd.parse(corpus)
check("eight lines become seven files (report.docx merged)",
      #list == 7, #list)
local rep = byPath[HOME .. "/Documents/report.docx"]
check("a U row and an M row about one file MERGE — opened kept, "
      .. "the fresher modified date kept",
      rep and rep.used == BASE - 100 and rep.mod == BASE - 40)
check("a '-' modified date is simply absent",
      byPath[HOME .. "/Desktop/notes.txt"].mod == nil)

-- =======================================================================
out("3) the learned-types rule — eager to learn, unable to flood\n")
-- =======================================================================
rd.assemble(list, byPath)
local function entryNamed(n)
    for _, e in ipairs(rd.entries) do if e.name == n then return e end end
end
check("the plist LL genuinely opened IS here — the Outlook case",
      entryNamed("com.microsoft.Outlook.plist") ~= nil)
check(".plist was LEARNED from that one open",
      rd.learned.plist ~= nil
      and rd.learned.plist.example == "com.microsoft.Outlook.plist")
check("…and .lua is a SEED now, so it is not 'learned'",
      rd.learned.lua == nil and entryNamed("init.lua") ~= nil)
check("a seed-type file merely MODIFIED shows (the sent attachment)",
      entryNamed("sent to you.xlsx") ~= nil)

local flood = { { path = HOME .. "/Library/Caches/junk.plist",
                  mod = BASE - 10 } }
local fbp = { [flood[1].path] = flood[1] }
rd.assemble(flood, fbp)
check("🚨 a merely-modified file of a LEARNED type is refused — "
      .. "one opened plist never unleashes the thousands",
      #rd.entries == 0, #rd.entries)

rd.saveTypes()
rd.learned = {}
rd.loadTypes()
check("learned types survive the round-trip to disk",
      rd.learned.plist ~= nil and rd.learned.plist.example
      == "com.microsoft.Outlook.plist")
check("unlearn forgets one and says so",
      rd.unlearn("plist") == true and rd.learned.plist == nil
      and rd.unlearn("plist") == false)

for i = 1, 30 do
    rd.learned["zz" .. i] = { first = i, last = i, example = "f" .. i }
end
rd.saveTypes()
local kept = 0
for _ in pairs(rd.learned) do kept = kept + 1 end
check("the learned list is capped — newest survive",
      kept == rd.learnedCap and rd.learned.zz30 ~= nil
      and rd.learned.zz1 == nil, kept)
rd.learned = {}

-- =======================================================================
out("4) ⇪F integration — old names search, stories tell, chains carry\n")
-- =======================================================================
_G.fileTrackerLog = {
    { event = "Renamed", fileName = "Budget draft.xlsx",
      newName = "Budget v2.xlsx", presentLoc = "~/Documents", movedLoc = "",
      timestamp = "10/08/26 09:00", epoch = BASE - 900 },
    { event = "Renamed", fileName = "Budget v2.xlsx",
      newName = "Budget FINAL v3.xlsx", presentLoc = "~/Documents",
      movedLoc = "", timestamp = "10/08/26 10:00", epoch = BASE - 800 },
    { event = "Moved", fileName = "notes.txt", presentLoc = "~/Old",
      newName = "", movedLoc = "~/Desktop",
      timestamp = "10/08/26 10:30", epoch = BASE - 700 },
    { event = "Renamed", fileName = "gone-before.md", newName = "gone.md",
      presentLoc = "~/Documents", movedLoc = "",
      timestamp = "10/08/26 10:40", epoch = BASE - 650 },
    { event = "Moved out", fileName = "gone.md", presentLoc = "~/Documents",
      newName = "", movedLoc = "", timestamp = "10/08/26 10:50",
      epoch = BASE - 600 },
    { event = "Renamed", fileName = "old-slides.pptx",
      newName = "deck.pptx", presentLoc = "~/Desktop", movedLoc = "",
      timestamp = "10/08/26 11:00", epoch = BASE - 500 },
    { event = "Created", fileName = "auto-export.csv",
      presentLoc = "~/Desktop", newName = "", movedLoc = "",
      timestamp = "10/08/26 11:10", epoch = BASE - 400 },
}
FILES[HOME .. "/Desktop/deck.pptx"] = true
FILES[HOME .. "/Desktop/auto-export.csv"] = true

local map = rd.trackerIndex()
check("a rename CHAIN carries both old names to the current file",
      map[HOME .. "/Documents/Budget FINAL v3.xlsx"] ~= nil
      and #map[HOME .. "/Documents/Budget FINAL v3.xlsx"].aliases == 2)
check("'Moved out' drops the trail — no stale alias",
      map[HOME .. "/Documents/gone.md"] == nil)

list, byPath = rd.parse(corpus)
rd.assemble(list, byPath)
local budget = entryNamed("Budget FINAL v3.xlsx")
check("typing the OLD name finds the renamed file (alias in the haystack)",
      budget and budget.hay:find("budget draft.xlsx", 1, true) ~= nil)
check("…and the row tells the story",
      budget and budget.sub:find("was Budget draft.xlsx, Budget v2.xlsx", 1, true)
      ~= nil, budget and budget.sub)
local notes = entryNamed("notes.txt")
check("a moved file says where it came from",
      notes and notes.sub:find("from ~/Old", 1, true) ~= nil,
      notes and notes.sub)
check("a deliberate ⇪F rename earns a row even though Spotlight never "
      .. "saw an open", entryNamed("deck.pptx") ~= nil)
check("…but a Created event alone does NOT — scripts churn, hands rename",
      entryNamed("auto-export.csv") == nil)
check("tracker activity counts for ranking",
      entryNamed("deck.pptx").act == BASE - 500)

-- =======================================================================
out("5) the shelf — exactly nine, opened-time order, groups after\n")
-- =======================================================================
local big, bbp = {}, {}
for i = 1, 12 do
    local e = { path = HOME .. "/Documents/doc" .. string.format("%02d", i)
                       .. ".docx", used = BASE - i * 10, mod = BASE - i * 10 }
    big[#big + 1] = e ; bbp[e.path] = e
end
local m1 = { path = HOME .. "/Downloads/unopened.xlsx", mod = BASE - 5 }
big[#big + 1] = m1 ; bbp[m1.path] = m1
_G.fileTrackerLog = nil
rd.assemble(big, bbp)
local shelves = {}
for _, e in ipairs(rd.entries) do
    if e.shelf then shelves[#shelves + 1] = e end
end
table.sort(shelves, function(a, b) return a.shelf < b.shelf end)
check("exactly nine wear numbers", #shelves == 9, #shelves)
check("① is the newest OPENED file — the merely-modified one, though "
      .. "fresher, cannot hold a shelf",
      shelves[1].name == "doc01.docx" and shelves[9].name == "doc09.docx"
      and entryNamed("unopened.xlsx").shelf == nil)
local secs = rd.sections()
check("sections count only the OVERFLOW (shelf rows excluded)",
      secs[1] and secs[1].tag == "word" and secs[1].n == 3, secs[1] and secs[1].n)
local json = rd.rowsJson()
check("the page JSON numbers the shelf rows", json:find('"n":9') ~= nil
      and json:find('"n":10') == nil)

-- =======================================================================
out("6) the CSV cache round-trips, and reads back as STALE\n")
-- =======================================================================
local weird = { path = HOME .. '/Documents/q3, "final".xlsx',
                used = BASE - 7, mod = BASE - 7 }
rd.entries = { rd.finish(weird) }
rd.saveCsv()
rd.entries = {}
rd.loadCsv()
check("a path with a comma and quotes survives the round-trip",
      rd.entries[1] and rd.entries[1].path == weird.path
      and rd.entries[1].used == BASE - 7)
check("cache data is stale by definition — the next open re-scans",
      rd.loadedAt == 0)

-- =======================================================================
out("7) the panel — remembered position, claims, the bridge\n")
-- =======================================================================
mod, rd = freshModule()
NOW = BASE + 3600
local l2, b2 = rd.parse(corpus)
rd.assemble(l2, b2)
rd.loadedAt = NOW            -- fresh: show() must not kick a scan

check("the escape claim is 'recentdocs' — in the router from birth",
      CLAIMS.recentdocs ~= nil and CLAIMS.recentdocs.priority == nil)
check("…inactive while closed", CLAIMS.recentdocs.active() == false
      or CLAIMS.recentdocs.active() == nil)

rd.show()
local view = WEBVIEWS[#WEBVIEWS]
check("the panel opens centered the first time",
      view and math.floor(view.rect.x) == math.floor((1440 - rd.width) / 2))
check("…and now the claim is live", CLAIMS.recentdocs.active() == true)
check("the page teaches the multi-way search",
      view.page:find("name, folder, date, extension", 1, true) ~= nil
      and view.page:find("recentDocs.postMessage", 1, true) ~= nil
      and view.page:find("⌘1", 1, true) ~= nil)

local panel
for _, p in ipairs(_G.movablePanels) do
    if p.name == "recent documents" then panel = p end
end
check("listed for ⌘-drag like every panel", panel ~= nil)
panel.move(333, 222)
check("dragging writes the remembered position",
      rd.pos and rd.pos.x == 333 and rd.pos.y == 222)
rd.hide()
rd.show()
check("🖐 A REMEMBERED POSITION WINS — it reopened where it was dragged",
      WEBVIEWS[#WEBVIEWS].rect.x == 333 and WEBVIEWS[#WEBVIEWS].rect.y == 222)
rd.hide()
rd.pos = { x = 5000, y = 5000 }        -- that screen was unplugged
rd.show()
check("…but an off-screen memory re-centers instead of vanishing",
      math.floor(WEBVIEWS[#WEBVIEWS].rect.x)
      == math.floor((1440 - rd.width) / 2))

local uc = WEBVIEWS[#WEBVIEWS].uc
uc.cb({ body = { a = "open", id = 1 } })
check("⏎ opens the document with hs.open and closes the panel",
      OPENED[1] == rd.entries[1].path and rd.webview == nil)
rd.show()
WEBVIEWS[#WEBVIEWS].uc.cb({ body = { a = "reveal", id = 2 } })
local rev = TASKS[#TASKS]
check("⌘⏎ reveals via /usr/bin/open -R, path positional",
      rev.cmd == "/usr/bin/open" and rev.args[1] == "-R"
      and rev.args[2] == rd.entries[2].path)
rd.show()
WEBVIEWS[#WEBVIEWS].uc.cb({ body = { a = "path", id = 1 } })
check("⌥⏎ copies the path", PASTED[1] == rd.entries[1].path)
rd.show()
CLAIMS.recentdocs.handle()
check("the router's handle closes it — the sheet stays for last",
      rd.webview == nil)

-- =======================================================================
out("8) refresh lifecycle + the no-Spotlight fallback\n")
-- =======================================================================
mod, rd = freshModule()
NOW = BASE + 3600
rd.refresh("manual")
TASKS[#TASKS].cb(1, "", "Spotlight disabled")
check("a failed scan warns and (manual) alerts, and does not wedge",
      rd.running == false and #ALERTS > 0
      and ALERTS[#ALERTS]:find("Spotlight", 1, true) ~= nil)
rd.refresh()
TASKS[#TASKS].cb(0, corpus, "")
check("a good scan lands entries and freshens the clock",
      #rd.entries > 0 and rd.loadedAt > 0)

FS[HOME .. "/Desktop"] = { "walked.docx", "old.docx", ".hidden.docx" }
FILES[HOME .. "/Desktop/walked.docx"] = { modification = os.time() - 60 }
FILES[HOME .. "/Desktop/old.docx"] = { modification = os.time() - 90 * 86400 }
local n = rd.fallbackWalk()
check("the fallback walk finds the fresh file, skips hidden and ancient",
      n == 1 and rd.entries[1] and rd.entries[1].name == "walked.docx", n)

check("the report names the learned list and the tracker state",
      _G.recentDocsReport():find("tracker", 1, true) ~= nil)

os.remove(TMPA) ; os.remove(TMPB)
out(string.format("\n%d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
