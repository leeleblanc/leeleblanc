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
    -- 📁 6.374.0 — THIS PLIST USED TO LIVE IN ~/Library/Preferences,
    -- and that fixture encoded a decision that has EXPIRED: an opened
    -- plist there is exactly what LL's thirty-four-app list asks not to
    -- see. The RULE under test is unchanged — a learned type lists only
    -- files you opened — so the fixture moves to a plist in a project
    -- folder, which is a plist he really does open and really is a
    -- document (6.248.0: assert the rule, not the fixture).
    "U\t" .. HOME .. "/Code/app/Info.plist\t"
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
check("the plist LL genuinely opened IS here — in a project folder",
      entryNamed("Info.plist") ~= nil)
-- 🎓 6.375.0 — ONE OPEN IS NOT A TYPE, which is the decision this check
-- used to assert the other way round ("`.plist` was LEARNED from that
-- one open"). LL: catch the common types "but files types like .nfo or
-- .edm shouldn't" turn up. The RULE is the same shape — a type he works
-- in joins — and the evidence it demands is two DIFFERENT files.
check("one opened file does NOT make .plist a type he works in",
      rd.learned.plist == nil, tostring(rd.learned.plist))
check("…and it is NAMED as waiting, with the count, not silently dropped",
      rd.waiting and rd.waiting.plist == 1, rd.waiting and rd.waiting.plist)
check("…and .lua is a SEED now, so it is not 'learned'",
      rd.learned.lua == nil and entryNamed("init.lua") ~= nil)
check("a seed-type file merely MODIFIED shows (the sent attachment)",
      entryNamed("sent to you.xlsx") ~= nil)

-- A SECOND file of the type is the evidence, and it joins.
local two = {
    { path = HOME .. "/Code/app/Info.plist",     used = BASE - 300 },
    { path = HOME .. "/Code/app/Settings.plist", used = BASE - 290 },
}
rd.assemble(two, { [two[1].path] = two[1], [two[2].path] = two[2] })
check("two different files of a type DO make it one he works in",
      rd.learned.plist ~= nil
      and rd.learned.plist.example == "Settings.plist",
      rd.learned.plist and rd.learned.plist.example)
check("…and it is no longer waiting", rd.waiting.plist == nil)

-- 🔁 RE-OPENING ONE FILE IS NO EVIDENCE ABOUT A TYPE, and the floor
-- gets that from upstream rather than from a guard of its own: the scan
-- emits a U row AND an M row for one file and `rd.parse` merges them, so
-- one entry is one file. Driven END TO END through parse, because that
-- merge is the thing the claim rests on.
mod, rd = freshModule()
local dupe = table.concat({
    "U\t" .. HOME .. "/Downloads/movie.nfo\t" .. stamp(-20) .. "\t" .. stamp(-20),
    "M\t" .. HOME .. "/Downloads/movie.nfo\t-\t" .. stamp(-19),
    "U\t" .. HOME .. "/Downloads/movie.nfo\t" .. stamp(-18) .. "\t-",
}, "\n")
local dl, dbp = rd.parse(dupe)
check("three scan rows about ONE file are one entry — the merge upstream "
      .. "is what makes the floor count files", #dl == 1, #dl)
rd.assemble(dl, dbp)
check("so re-opening one file never reaches the floor",
      rd.learned.nfo == nil and rd.waiting.nfo == 1,
      rd.waiting and rd.waiting.nfo)

-- 🔁 AND THE FLOOR GOVERNS JOINING, NEVER EVICTION: a month in which he
-- opens only one .key must not un-learn a type he works in.
local keyed = {
    { path = HOME .. "/Documents/one.key", used = BASE - 40 },
    { path = HOME .. "/Documents/two.key", used = BASE - 39 },
}
rd.assemble(keyed, { [keyed[1].path] = keyed[1], [keyed[2].path] = keyed[2] })
check(".key is learned from two files", rd.learned.key ~= nil)
local lonely = { { path = HOME .. "/Documents/three.key", used = BASE - 5 } }
rd.assemble(lonely, { [lonely[1].path] = lonely[1] })
check("a later scan with ONE file of a learned type keeps it learned",
      rd.learned.key ~= nil and rd.waiting.key == nil)
check("…and the newer example is taken",
      rd.learned.key.example == "three.key", rd.learned.key.example)
mod, rd = freshModule()
local same = { { path = HOME .. "/Downloads/movie.nfo", used = BASE - 20 } }
rd.assemble(same, { [same[1].path] = same[1] })
-- ↩️ AND A RULE THAT REFUSES OWES A WAY PAST IT (6.199.0)
check("learn() joins a type by hand, once",
      rd.learn("nfo") == true and rd.learned.nfo ~= nil
      and rd.learn("nfo") == false)
check("learn() refuses a built-in type and nonsense, and says why",
      rd.learn("docx") == false and rd.learn("") == false
      and rd.learn("not an ext") == false
      and select(2, rd.learn("xlsx")):find("built-in", 1, true) ~= nil)
check("learn() takes a leading dot and any case",
      rd.learn(".EDM") == true and rd.learned.edm ~= nil)
-- a type joined by hand has to SURVIVE a reload, or the command is a
-- courtesy that lasts until the next ⌘⌃R
rd.learned = {}
rd.loadTypes()
check("a type joined by hand is written to disk, not held in memory",
      rd.learned.nfo ~= nil and rd.learned.edm ~= nil,
      tostring(rd.learned.nfo) .. "/" .. tostring(rd.learned.edm))
-- the floor is a NUMBER the gate can move, and floor 1 is the old rule
mod, rd = freshModule()
rd.learnFloor = 1
rd.assemble(same, { [same[1].path] = same[1] })
check("floor = 1 is the pre-6.375.0 rule exactly — one open joins",
      rd.learned.nfo ~= nil and next(rd.waiting) == nil)
mod, rd = freshModule()
rd.learnFloor = 0
check("a floor of 0 or less clamps to 1 — a typo cannot admit everything",
      rd.learnFloorValue() == 1)
rd.learnFloor = "nonsense"
check("an unreadable floor falls back to the shipped 2, never to 0",
      rd.learnFloorValue() == 2)

-- put the corpus state back for the checks below
mod, rd = freshModule()
list, byPath = rd.parse(corpus)
rd.assemble(list, byPath)
rd.assemble(two, { [two[1].path] = two[1], [two[2].path] = two[2] })
entryNamed = function(n)
    for _, e in ipairs(rd.entries) do if e.name == n then return e end end
end

-- 🚨 IN A DOCUMENT FOLDER, DELIBERATELY: under ~/Library this row is
-- refused by 6.374.0's folder rule as well, so the check would pass with
-- the anti-flood rule deleted — the fixture has to be one where only the
-- rule under test can say no (6.230.0 · 6.273.0).
local flood = { { path = HOME .. "/Code/app/junk.plist",
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
      == "Settings.plist")
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

-- =======================================================================
out("9) 🔤 6.361.0 — the key is READABLE, and it is BUILT not typed\n")
-- =======================================================================
-- LL, reading this very card: "hyper+| spilts two recent windows … it
-- says it is for Recent Documents. Is it not?" It is — ⇪I has been
-- bound since 6.93.0 — but core/cheatsheet.lua sets no font, so a
-- capital I draws as a bare vertical stroke and reads as a pipe. The
-- only vertical bar on the keyboard is the backslash key, which §0.4
-- maps to the window split. Both cards honest, the tool unreachable.
do
    local cs = mod.cheatsheet
    check("6.361.0: the card's TITLE names the letter",
          cs.title:find("LETTER I", 1, true) ~= nil, cs.title)

    -- 🔑 THE KEY COLUMN STAYS A PURE COMBO — 6.196.0's auditor reads a
    -- word in it as a POINTER and stops auditing the row, so naming the
    -- letter there would cost the audit that catches a stale key.
    local row1, rowS
    for _, e in ipairs(cs.entries) do
        if e[1] == "⇪I"  then row1 = e end
        if e[1] == "⇪⇧I" then rowS = e end
    end
    check("6.361.0: the panel row is still keyed by the bare combo ⇪I",
          row1 ~= nil and row1[1] == "⇪I")
    check("6.361.0: …and its DESCRIPTION names the letter",
          row1 ~= nil and row1[2]:find("LETTER I", 1, true) ~= nil,
          row1 and row1[2])
    check("6.361.0: …and it names the key he actually pressed, so the "
          .. "mistake is answered where he makes it",
          row1 ~= nil and row1[2]:find("splits two windows", 1, true) ~= nil)
    check("6.361.0: the re-scan row is keyed ⇪⇧I and names the letter too",
          rowS ~= nil and rowS[2]:find("LETTER I", 1, true) ~= nil)
    check("6.361.0: the report names the key, so the Console answers "
          .. "\"which key is this?\" without the sheet",
          _G.recentDocsReport():find("LETTER I", 1, true) ~= nil)
end

-- 🏷 BUILT, NOT TYPED (6.311.0 / 6.239.0): move the module's own
-- literal and require every surface to follow. A typed "⇪I" passes
-- every check above and fails this one — which is the mutation that
-- matters, because a typed label is exactly how the title and the row
-- come to disagree the next time the key moves.
do
    local f = assert(io.open(HS .. "/modules/recent_docs.lua", "r"))
    local src = f:read("a") ; f:close()
    check("6.361.0: the suite really read the module",
          #src > 20000 and src:find("local KEY", 1, true) ~= nil, #src)
    local moved, n = src:gsub('local KEY%s*=%s*"i"', 'local KEY = "q"', 1)
    check("6.361.0: …and the literal is a single module-level KEY", n == 1, n)
    local other = assert(load(moved, "recent_docs(KEY=q)"))()
    check("6.361.0: moving KEY moves the card's TITLE",
          other.cheatsheet.title:find("⇪Q", 1, true) ~= nil
          and other.cheatsheet.title:find("LETTER Q", 1, true) ~= nil,
          other.cheatsheet.title)
    local sawQ = false
    for _, e in ipairs(other.cheatsheet.entries) do
        if e[1] == "⇪Q" then sawQ = true end
        check("6.361.0: no row still carries the OLD key after the move",
              e[1] ~= "⇪I" and e[1] ~= "⇪⇧I", e[1])
    end
    check("6.361.0: …and the panel row moved with it", sawQ)

    -- 🔑 AND THE BINDING FOLLOWS THE SAME LITERAL. `rd.key = "i"` typed
    -- by hand is EQUIVALENT today and drifts the day the key moves —
    -- which is the whole shape 6.239.0 exists for: a card that still
    -- says ⇪I over a binding that is somewhere else.
    TASKS, ALERTS, HYPER, OPENED, PASTED = {}, {}, {}, {}, {}
    WEBVIEWS, CLAIMS = {}, {}
    other.setup(CORE)
    check("6.361.0: moving KEY moves the BINDING too, not just the card",
          HYPER["|q"] ~= nil and HYPER["shift|q"] ~= nil
          and HYPER["|i"] == nil,
          (HYPER["|q"] and "q bound" or "q NOT bound")
          .. (HYPER["|i"] and " · i still bound" or ""))
    mod, rd = freshModule()   -- put the real module back for anything after
end



-- =======================================================================
out("\n9) 6.374.0 — ~/Library is an app's own folder, not his documents\n")
-- =======================================================================
-- LL's list of thirty-four apps — 1Password, Activity Monitor, App
-- Store, Audio MIDI, Calculator, Chess, ColorSync, Digital Color Meter,
-- Disk Utility, DisplayLink, … System Settings, Tips, TV, … Weather —
-- against the five he said he WOULD work in. Every one of the
-- thirty-four keeps a folder under ~/Library; none of the five does.
mod, rd = freshModule()

-- The pure rule, and the REASON as well as the verdict: a document
-- wrongly turned away has to be readable in the report (6.196.1).
local function owned(p) return (rd.appOwned(p, HOME)) end
local function why(p) local _, w = rd.appOwned(p, HOME) ; return w end

check("a document in Documents is his", not owned(HOME .. "/Documents/Budget.xlsx"))
check("a document on the Desktop is his", not owned(HOME .. "/Desktop/notes.md"))
check("1Password's own icon cache is NOT a document",
      owned(HOME .. "/Library/Application Support/1Password/icon.png"),
      why(HOME .. "/Library/Application Support/1Password/icon.png"))
check("a Notes container file is NOT a document",
      owned(HOME .. "/Library/Containers/com.apple.Notes/Data/note.csv"))
check("a Preferences plist is NOT a document",
      owned(HOME .. "/Library/Preferences/com.apple.Weather.plist"))
check("the reason names the folder, so the report can print it",
      why(HOME .. "/Library/Containers/com.apple.Notes/Data/note.csv")
          :find("Library", 1, true) ~= nil)

-- ☁️ THE FIXTURE THAT SEPARATES A CORRECT RULE FROM A LIST-EMPTYING ONE
-- (6.230.0): OneDrive lives INSIDE ~/Library, so "skip ~/Library" and
-- "skip ~/Library except the cloud folder" agree about every path but
-- this one — and this one is where the Vault, the screenshots and
-- nearly everything he works on actually live.
local CLOUD = HOME .. "/Library/CloudStorage/OneDrive-Personal"
check("the Vault inside ~/Library/CloudStorage IS his",
      not owned(CLOUD .. "/Vault/Note.md"), why(CLOUD .. "/Vault/Note.md"))
check("a screenshot in the cloud folder IS his",
      not owned(CLOUD .. "/2026 Screenshots/shot.png"))
check("the cloud exception is named as such, not as a document folder",
      why(CLOUD .. "/Vault/Note.md"):find("cloud", 1, true) ~= nil)

check("a file inside an app bundle is not a document",
      owned("/Applications/Thing.app/Contents/readme.txt"))
check("a package folder is not a document",
      owned(HOME .. "/code/proj/node_modules/pkg/readme.md"))
check("a hidden folder is not a document",
      owned(HOME .. "/.Trash/old.docx"))
check("an empty path fails CLOSED", owned(nil) and owned(""))
-- home is an ARGUMENT, so the gate can move it under the rule (6.239.0)
check("the rule follows the home folder it is given",
      rd.appOwned("/Users/other/Library/Caches/x.png", "/Users/other")
      and not rd.appOwned("/Users/other/Library/Caches/x.png", HOME))

-- =======================================================================
out("\n9b) the folder rule runs in the SCRIPT, before mdls and before the cap\n")
-- =======================================================================
-- 🚨 THE CHECK THAT EARNS ITS PLACE RUNS THE SHIPPED SCRIPT. A `case`
-- pattern cannot be proven by reading, and the Lua half cannot see it
-- at all — so the script is lifted out of the argv the module really
-- built and executed by /bin/sh with mdfind and mdls shimmed, which is
-- what the RD_MDFIND / RD_MDLS defaults exist for (6.208.0's shape).
local function runScript(hits, capN, hm)
    local dir = os.tmpname() ; os.remove(dir)
    os.execute("mkdir -p '" .. dir .. "/bin'")
    local f = io.open(dir .. "/scan.sh", "w")
    if not f then return nil end
    f:write(TASKS[1].args[2]) ; f:close()
    f = io.open(dir .. "/hits", "w")
    for _, h in ipairs(hits) do
        f:write(h, "\n")
        -- every hit must EXIST as a plain file or the script's own
        -- `[ -f ]` rejects it and the fixture proves nothing
        local d = h:match("^(.*)/[^/]+$")
        os.execute("mkdir -p '" .. d .. "' 2>/dev/null")
        os.execute("touch '" .. h .. "' 2>/dev/null")
    end
    f:close()
    f = io.open(dir .. "/bin/mdfind", "w")
    f:write("#!/bin/sh\ncat \"$FAKE_HITS\"\n") ; f:close()
    f = io.open(dir .. "/bin/mdls", "w")
    f:write("#!/bin/sh\nprintf '2026-10-18 09:00:00 +0000'\n"
            .. "printf '\\0'\nprintf '2026-10-19 10:00:00 +0000'\n") ; f:close()
    os.execute("chmod +x '" .. dir .. "/bin/mdfind' '" .. dir .. "/bin/mdls'")
    local cmd = "FAKE_HITS='" .. dir .. "/hits' RD_MDFIND='" .. dir
        .. "/bin/mdfind' RD_MDLS='" .. dir .. "/bin/mdls' /bin/sh '"
        .. dir .. "/scan.sh' '" .. hm .. "' " .. tostring(capN)
        .. " usedq modq 2>/dev/null"
    local p = io.popen(cmd)
    local o = p and p:read("*a") or ""
    if p then p:close() end
    os.execute("rm -rf '" .. dir .. "' 2>/dev/null")
    return o
end

rd.refresh()        -- so TASKS[1] carries the shipped script to lift
local SHOME = (os.tmpname() .. "-home"):gsub("'", "")
local SCLOUD = SHOME .. "/Library/CloudStorage/OneDrive-Personal"
local ran = runScript({
    SHOME .. "/Documents/Budget.xlsx",
    SHOME .. "/Library/Application Support/1Password/icon.png",
    SHOME .. "/Library/Containers/com.apple.Notes/note.csv",
    SCLOUD .. "/Vault/Note.md",
    SHOME .. "/Applications/Thing.app/Contents/readme.txt",
}, 400, SHOME)
if not ran or ran == "" then
    check("the shipped script runs under /bin/sh", false,
          "no output — /bin/sh or the shims did not run")
else
    check("the script keeps a Documents file", ran:find("Budget.xlsx", 1, true))
    check("the script keeps the cloud folder", ran:find("Note.md", 1, true))
    check("the script turns 1Password's folder away",
          not ran:find("icon.png", 1, true), ran)
    check("the script turns a container away",
          not ran:find("note.csv", 1, true), ran)
    check("the script turns an app bundle away",
          not ran:find("readme.txt", 1, true), ran)
end

-- 🚨 AND THE CAP COUNTS DOCUMENTS, WHICH IS THE SHARPER HALF. The old
-- script took `head -n "$cap"` BEFORE filtering, so on a Mac whose
-- ~/Library churns more than the cap in a fortnight his real documents
-- never reached the loop. This fixture puts the junk FIRST and sets the
-- cap to 2: the old order answers nothing but junk (and therefore
-- nothing at all, once the rule drops it), the new order answers the
-- document. Old and new MUST differ here (6.230.0).
local many = {}
for i = 1, 40 do
    many[#many + 1] = SHOME .. "/Library/Application Support/1Password/j"
                      .. i .. ".png"
end
many[#many + 1] = SHOME .. "/Documents/Real.docx"
local ran2 = runScript(many, 2, SHOME)
check("the cap is spent on documents, not on the files it turned away",
      ran2 and ran2:find("Real.docx", 1, true) ~= nil, tostring(ran2))

-- =======================================================================
out("\n9c) the same rule in Lua: a stale cache, the learn loop, the report\n")
-- 🔬 INTEGER STAMPS, DELIBERATELY: this harness advances its clock by a
-- fraction on every read (6.282.0 — macOS's own clock is a float), so a
-- fixture built from NOW carries a fraction into os.date, which refuses
-- one. The module floors its clock; a test fixture has to as well.
-- =======================================================================
-- A cache written by an older build already holds ~/Library rows, so
-- the Lua half is not decoration: without it the list goes on showing
-- them until they age out of the window.
mod, rd = freshModule()
local stale = {
    { path = HOME .. "/Documents/Budget.xlsx", used = BASE - 100 },
    { path = HOME .. "/Library/Application Support/1Password/icon.png",
      used = BASE - 50 },
    { path = CLOUD .. "/Vault/Note.md", used = BASE - 60 },
}
local byPath = {} ; for _, e in ipairs(stale) do byPath[e.path] = e end
local kept = rd.assemble(stale, byPath)
local names = {}
for _, e in ipairs(kept) do names[e.name] = true end
check("a stale ~/Library row is turned away on load",
      names["Budget.xlsx"] and names["Note.md"] and not names["icon.png"])
check("the turned-away count is kept, not discarded in silence",
      rd.turnedAway == 1, tostring(rd.turnedAway))
check("the report names what it turned away and why",
      (function()
          printed = {}
          local r = _G.recentDocsReport()
          return r:find("turned away", 1, true) ~= nil
                 and r:find("Library", 1, true) ~= nil
      end)())

-- 🔎 THE THIRD STATE, DRIVEN (6.273.0 — the sweep found this one
-- missing). Before any list is assembled the count is nil, and "nothing
-- has been read" must NOT print the words for "read it and turned
-- nothing away": one is a tool that has not run, the other is a clean
-- bill of health, and they are opposite facts.
mod, rd = freshModule()
local fresh = _G.recentDocsReport()
check("a module that has assembled nothing says so, not '0 turned away'",
      fresh:find("nothing read yet", 1, true) ~= nil
      and fresh:find("0 turned away", 1, true) == nil, fresh)
-- and a list with nothing to turn away says THAT, which is the health line
local clean = { { path = HOME .. "/Documents/Only.docx", used = BASE - 10 } }
rd.assemble(clean, { [clean[1].path] = clean[1] })
local okline = _G.recentDocsReport()
check("a list with nothing to turn away reads as health, not as unread",
      okline:find("0 turned away", 1, true) ~= nil
      and okline:find("nothing read yet", 1, true) == nil, okline)

-- 🎓 THE LEARN LOOP DECIDES THE SAME THING (6.305.0): one opened file
-- inside a container would teach its extension, and a learned type then
-- admits every opened file of that type for ever — the folder rule
-- leaking back in a week later through the types list.
mod, rd = freshModule()
-- TWO files, so the floor is cleared and only the folder rule can
-- refuse: with one file this check would pass with 6.374.0's rule
-- deleted, because 6.375.0's floor would refuse it anyway (6.273.0).
local one = { { path = HOME .. "/Library/Containers/com.apple.Notes/x.sqlite",
                used = BASE - 10 },
              { path = HOME .. "/Library/Containers/com.apple.Notes/y.sqlite",
                used = BASE - 9 } }
rd.assemble(one, { [one[1].path] = one[1], [one[2].path] = one[2] })
check("opened files in a container do NOT teach their extension",
      rd.learned["sqlite"] == nil)
-- two different files, because 6.375.0's floor is two — the point here
-- is the FOLDER, so the fixture has to clear the other rule
mod, rd = freshModule()
local docs = {
    { path = HOME .. "/Documents/one.sqlite", used = BASE - 10 },
    { path = HOME .. "/Documents/two.sqlite", used = BASE - 9 },
}
rd.assemble(docs, { [docs[1].path] = docs[1], [docs[2].path] = docs[2] })
check("opened files in Documents DO teach their extension",
      rd.learned["sqlite"] ~= nil)
mod, rd = freshModule()
local cl = {
    { path = CLOUD .. "/Vault/one.sqlite", used = BASE - 10 },
    { path = CLOUD .. "/Vault/two.sqlite", used = BASE - 9 },
}
rd.assemble(cl, { [cl[1].path] = cl[1], [cl[2].path] = cl[2] })
check("opened files in the cloud folder teach their extension too",
      rd.learned["sqlite"] ~= nil)

-- 🔒 A SENTRY ON THE ONE EXCEPTION. A filter that drops ~/Library
-- without naming the cloud folder back would empty the list of almost
-- everything he works on, and NOTHING functional in Lua can see the
-- script's `case` — so the exception is asserted against the shipped
-- text as well as driven above.
mod, rd = freshModule()
rd.refresh()
local SRC = TASKS[1].args[2]
check("the script names the cloud folder back by hand",
      SRC:find("Library/CloudStorage/", 1, true) ~= nil)
check("the script skips the rest of ~/Library",
      SRC:find('"$hm"/Library/%*%)') ~= nil
      or SRC:find('"$hm"/Library/*)', 1, true) ~= nil)
check("the cap is applied after the filter, never by head",
      not SRC:find("head -n", 1, true) and SRC:find("-le \"$cap\"", 1, true))


-- =======================================================================
out("\n9d) 6.375.0 — the report says what is being held back, and why\n")
-- =======================================================================
mod, rd = freshModule()
local r0 = _G.recentDocsReport()
check("before any scan the waiting line says nothing was asked",
      r0:find("waiting : nothing asked yet", 1, true) ~= nil, r0)
check("…and the learned line names the FLOOR, so the sentence cannot go "
      .. "stale when the number moves (6.181.0 · 6.239.0)",
      r0:find("open " .. rd.learnFloorValue() .. " different files",
              1, true) ~= nil, r0)

local held = {
    { path = HOME .. "/Downloads/a.nfo", used = BASE - 30 },
    { path = HOME .. "/Downloads/b.edm", used = BASE - 20 },
    { path = HOME .. "/Documents/one.key", used = BASE - 15 },
    { path = HOME .. "/Documents/two.key", used = BASE - 14 },
}
local hbp = {} ; for _, e in ipairs(held) do hbp[e.path] = e end
rd.assemble(held, hbp)
local r1 = _G.recentDocsReport()
check(".key reached the floor and is learned", rd.learned.key ~= nil)
check(".nfo and .edm are held back, by name, with their counts",
      rd.waiting.nfo == 1 and rd.waiting.edm == 1)
check("the report names both and gives the command that joins one",
      r1:find("%.nfo") and r1:find("%.edm")
      and r1:find("recentDocs.learn", 1, true) ~= nil, r1)
check("the report does NOT list .key as waiting", not r1:find("%.key  1"))

-- the health line: everything he opened reached the floor
mod, rd = freshModule()
local allgood = {
    { path = HOME .. "/Documents/one.key", used = BASE - 15 },
    { path = HOME .. "/Documents/two.key", used = BASE - 14 },
}
rd.assemble(allgood, { [allgood[1].path] = allgood[1],
                       [allgood[2].path] = allgood[2] })
local r2 = _G.recentDocsReport()
check("with nothing held back it reads as health, not as unasked",
      r2:find("waiting : none", 1, true) ~= nil
      and r2:find("nothing asked yet", 1, true) == nil, r2)

-- 🔒 the floor is READ in one place, never retyped: the drawing, the
-- learn loop and the report all ask learnFloorValue(), so moving the
-- config moves all three (6.239.0).
mod, rd = freshModule()
rd.learnFloor = 4
local r3 = _G.recentDocsReport()
check("moving the floor moves the sentence the report prints",
      r3:find("open 4 different files", 1, true) ~= nil, r3)
local SRC = io.open(HS .. "/modules/recent_docs.lua"):read("*a")
local defs    = select(2, SRC:gsub("function rd%.learnFloorValue", ""))
local mentions = select(2, SRC:gsub("learnFloorValue%(%)", ""))
check("the floor has ONE definition and is ASKED by the rule and the "
      .. "report, never retyped as a literal",
      defs == 1 and (mentions - defs) >= 2
      and not SRC:find("rd%.learnFloor >= ")
      and not SRC:find("b%.n >= 2"), defs .. "/" .. mentions)

os.remove(TMPA) ; os.remove(TMPB)
out(string.format("\n%d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
