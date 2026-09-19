-- =====================================================================
-- test_activity_url.lua — the url column in activity_history (6.123.0)
-- =====================================================================
--     lua5.4 test_activity_url.lua [/path/to/hammerspoon]
--
-- Executes modules/activity_tracker.lua against a stubbed hs and drives
-- the REAL URL engine: the AppleScript it builds, the answers it accepts
-- and refuses, what it cuts out of a URL before writing it down, the
-- five-column CSV, and the async race between "Chrome answered" and "you
-- already switched tabs".
--
-- The parts that matter most here are the ones that are about restraint
-- rather than capability: incognito windows are never recorded, named
-- secrets never reach the file, and an app name never reaches the
-- AppleScript source unless it is one of five exact literals.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local printed = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function logged(needle)
    for _, l in ipairs(printed) do if l:find(needle, 1, true) then return true end end
    return false
end

-- ---- the stub Mac ------------------------------------------------------
local TMP     = os.getenv("TMPDIR") or "/tmp"
local ALERTS  = {}
local TASKS   = {}       -- every hs.task.new, runnable by hand
local TIMERS  = {}
local CLIP    = nil
local FRONT   = { name = nil, title = nil, kind = 1 }
local NOW     = 1000000
local CLOCK   = 5000        -- seconds; hs.timer.secondsSinceEpoch (6.257.0)
local DEGRADES = {}         -- every trip through the 🔔 door

hs = {
    configdir = TMP,
    application = {
        frontmostApplication = function()
            if not FRONT.name then return nil end
            return {
                name = function() return FRONT.name end,
                kind = function() return FRONT.kind end,
                focusedWindow = function()
                    if not FRONT.title then return nil end
                    return { title = function() return FRONT.title end }
                end,
            }
        end,
    },
    task = {
        new = function(bin, cb, args)
            local t = { bin = bin, cb = cb, args = args, started = false, killed = false }
            function t:start() self.started = true; return self end
            function t:terminate() self.killed = true end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    timer = {
        doEvery = function(secs, fn)
            local t = { fn = fn, secs = secs, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doAt = function(_, _, fn) return { stop = function() end } end,
        doAfter = function(_, fn) return { stop = function() end } end,
        -- 6.257.0: the document read is TIMED, so the clock has to exist
        -- here or every read measures nothing and the 🔔 door is untestable.
        secondsSinceEpoch = function() return CLOCK end,
    },
    alert     = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    pasteboard = { setContents = function(s) CLIP = s; return true end,
                   getContents = function() return CLIP end },
    host      = { idleTime = function() return 0 end },
    caffeinate = { watcher = {
        screensDidLock = "lock", systemWillSleep = "sleep",
        new = function(fn) return { start = function() end, fn = fn } end,
    } },
    chooser = { new = function(cb)
        local c = { _cb = cb, _choices = {} }
        function c:choices(x) if x then self._choices = x end return self._choices end
        function c:placeholderText() end
        function c:queryChangedCallback(fn) self._onQuery = fn end
        function c:searchSubText() end
        function c:query() end
        function c:show() end
        function c:hide() end
        function c:refreshChoicesCallback() end
        return c
    end },
    fnutils = {},
    json    = { decode = function() return {} end, encode = function() return "{}" end },
    screen  = { allScreens = function() return {} end, mainScreen = function() return nil end },
    settings = { get = function() return nil end, set = function() end },
    styledtext = {},
}
_G.choosers = {}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.service = {
    registry = {}, owner = {},
    provide = function(n, f) _G.service.registry[n] = f end,
    has     = function(n) return _G.service.registry[n] ~= nil end,
    -- 🧪 6.257.0 — THE STUB PCALLS, BECAUSE THE REAL ONE DOES. init.lua's
    -- service.call wraps every provider in a pcall and answers nil when one
    -- throws; a stub that let the throw through turned a caller's "does it
    -- survive a provider that dies" check into a dead test run (6.193.0,
    -- and 6.186.0 on top: a mutation must FAIL a check, never kill the
    -- suite). It returns three values like the real one, too — a provider
    -- answering `nil, why` is the whole reason frontDoc can tell "no
    -- document" from "could not be asked".
    call    = function(n, ...)
        local f = _G.service.registry[n]
        if not f then print("🔌 No provider for '" .. n .. "'") return nil end
        local ok, a, b, c = pcall(f, ...)
        if not ok then
            print("🔌 Service '" .. tostring(n) .. "' failed — " .. tostring(a))
            return nil
        end
        return a, b, c
    end,
}

local CSVPATH = TMP .. "/at_url_test_" .. tostring(os.time()) .. ".csv"
os.remove(CSVPATH)

local core = {
    logsDir = TMP, hostTag = "urltest", configDir = TMP,
    adoptLegacyFile = function() end,
    warnWriteFailed = function(w) print("write failed: " .. tostring(w)) end,
    csvQuote = function(s)
        s = tostring(s)
        if s:find('[",\n]') then return '"' .. s:gsub('"', '""') .. '"' end
        return s
    end,
    splitCSVLine = function(line)
        local fields, pos = {}, 1
        while pos <= #line do
            local c = line:sub(pos, pos)
            if c == '"' then
                local buf, i = {}, pos + 1
                while i <= #line do
                    local ch = line:sub(i, i)
                    if ch == '"' then
                        if line:sub(i + 1, i + 1) == '"' then buf[#buf + 1] = '"'; i = i + 2
                        else i = i + 1; break end
                    else buf[#buf + 1] = ch; i = i + 1 end
                end
                fields[#fields + 1] = table.concat(buf)
                pos = i + 1
            else
                local nextComma = line:find(",", pos, true)
                if nextComma then
                    fields[#fields + 1] = line:sub(pos, nextComma - 1); pos = nextComma + 1
                else
                    fields[#fields + 1] = line:sub(pos); pos = #line + 1
                end
            end
        end
        if line:sub(-1) == "," then fields[#fields + 1] = "" end
        return fields
    end,
    formatDuration = function(s) return tostring(math.floor(s / 60)) .. "m" end,
    degrade = function(tool, why)
        DEGRADES[#DEGRADES + 1] = tostring(tool) .. ": " .. tostring(why)
        return false, why
    end,
    provide = function(n, f) _G.service.provide(n, f) end,
    call    = function(n, ...) return _G.service.call(n, ...) end,
    showPopup = function() end,
    resolveBaseScreen = function() return nil end,
    hyperAddShortcut = function() end,
    popupKeys = { mods = {} }, popupMods = {},
    panelAlpha = 1, chooserTopLeft = function() return { x = 0, y = 0 } end,
    version = "test",
}

-- the tracker names its own file from logsDir + hostTag; mirror that here
local EXPECTED_CSV = TMP .. "/activity_history-urltest.csv"
os.remove(EXPECTED_CSV)

local chunk = assert(loadfile(HS .. "/modules/activity_tracker.lua"))
local M = chunk()
M.setup(core)

local au = _G.activityURL   -- rebound in §5 after the fresh load
check("the module exposes its URL engine as _G.activityURL", type(au) == "table")

-- =====================================================================
out("\n== 1. THE APPLESCRIPT, AND THE ALLOW-LIST THAT GUARDS IT ==\n")
-- =====================================================================

check("Chrome is on the list", au.CHROMES["Google Chrome"] == true)
check("so are the other Chromium builds",
      au.CHROMES["Chromium"] and au.CHROMES["Google Chrome Beta"])
check("Safari is NOT — this is Chrome-only and says so in code",
      au.CHROMES["Safari"] == nil)

local script = au.scriptFor("Google Chrome")
check("a script is built for Chrome", type(script) == "string" and #script > 0)
check("...it asks for the active tab's URL",
      script:find("URL of active tab", 1, true) ~= nil)
check("...and it reads the window mode first",
      script:find("mode of w", 1, true) ~= nil)

-- 🔒 THE INJECTION GUARD. An app can be named anything, and that name
-- would otherwise be pasted into AppleScript source.
check("🔒 an app that is not on the list gets NO script at all",
      au.scriptFor("Sublime Text") == nil)
check("🔒 ...including one whose NAME is an AppleScript injection attempt",
      au.scriptFor('Google Chrome" \n do shell script "rm -rf ~" \n tell application "Finder') == nil)
check("🔒 ...and a nil app name does not crash the builder",
      au.scriptFor(nil) == nil)

-- 🕵️ FAIL CLOSED. The default in the script is incognito, not normal.
check("🕵️ the mode defaults to incognito, so an unreadable window is SKIPPED "
      .. "rather than recorded",
      script:find('set m to "incognito"', 1, true) ~= nil)
check("🕵️ ...and only an explicitly normal window is allowed through",
      script:find('if m is not "normal"', 1, true) ~= nil)

-- =====================================================================
out("\n== 2. WHAT GETS WRITTEN DOWN, AND WHAT NEVER DOES ==\n")
-- =====================================================================

check("an ordinary page survives intact",
      au.sanitise("https://example.com/docs/page") == "https://example.com/docs/page",
      au.sanitise("https://example.com/docs/page"))

check("a meaningful query parameter is KEPT — ?v= is what makes the row mean "
      .. "something",
      au.sanitise("https://www.youtube.com/watch?v=abc123")
        == "https://www.youtube.com/watch?v=abc123",
      au.sanitise("https://www.youtube.com/watch?v=abc123"))

-- 🔐 The secrets.
check("🔐 a session token is cut out",
      au.sanitise("https://app.example.com/home?token=SECRET&view=list")
        == "https://app.example.com/home?view=list",
      au.sanitise("https://app.example.com/home?token=SECRET&view=list"))
check("🔐 ...an OAuth code too",
      au.sanitise("https://example.com/cb?code=abc&state=xyz")
        == "https://example.com/cb?state=xyz",
      au.sanitise("https://example.com/cb?code=abc&state=xyz"))
check("🔐 ...a password reset link keeps nothing usable",
      au.sanitise("https://example.com/reset?reset=ABC") == "https://example.com/reset",
      au.sanitise("https://example.com/reset?reset=ABC"))
check("🔐 ...and the match is case-insensitive on the parameter name",
      au.sanitise("https://example.com/a?TOKEN=x&keep=1") == "https://example.com/a?keep=1",
      au.sanitise("https://example.com/a?TOKEN=x&keep=1"))

-- 🔐 The fragment is where OAuth's implicit flow puts its access token,
-- and a stripper that only reads the query string misses it entirely.
check("🔐 a token hiding in the FRAGMENT is cut out too",
      au.sanitise("https://example.com/cb#access_token=SECRET&scope=read")
        == "https://example.com/cb#scope=read",
      au.sanitise("https://example.com/cb#access_token=SECRET&scope=read"))
check("...but an ordinary anchor is left alone",
      au.sanitise("https://example.com/doc#section-4")
        == "https://example.com/doc#section-4",
      au.sanitise("https://example.com/doc#section-4"))

-- Only real pages.
check("chrome:// internals are not recorded", au.sanitise("chrome://newtab") == "")
check("about:blank is not recorded", au.sanitise("about:blank") == "")
check("a file:// path is not recorded", au.sanitise("file:///Users/x/a.html") == "")
check("an empty answer is not recorded", au.sanitise("") == "")
check("a non-string answer does not crash", au.sanitise(nil) == "")

-- ✏️ The skip list.
au.skipHosts = { "chase.com" }
check("✏️ a host on the skip list is never recorded",
      au.sanitise("https://chase.com/accounts") == "")
check("✏️ ...and the match covers subdomains",
      au.sanitise("https://secure.chase.com/accounts") == "")
check("✏️ ...but not a host that merely ends with the same letters",
      au.sanitise("https://notchase.com/x") ~= "")
au.skipHosts = {}

check("hostOf strips www. and a port",
      au.hostOf("https://www.example.com:8443/a") == "example.com",
      au.hostOf("https://www.example.com:8443/a"))

-- 🔗 The URL cleaner is REUSED rather than reimplemented.
_G.service.provide("url.clean", function(u) return (u:gsub("[?&]utm_[^&]*", "")) end)
check("🔗 the shared URL cleaner is applied when it is loaded",
      au.sanitise("https://example.com/a?utm_source=news") == "https://example.com/a",
      au.sanitise("https://example.com/a?utm_source=news"))
-- ...and secrets are stripped AFTER it, so nothing it does can put one back.
_G.service.registry["url.clean"] = function() return "https://evil.example/x?token=BACK" end
check("🔐 secrets are stripped AFTER the cleaner runs — a cleaner that "
      .. "reintroduced one could not sneak it past",
      au.sanitise("https://example.com/a") == "https://evil.example/x",
      au.sanitise("https://example.com/a"))
_G.service.registry["url.clean"] = nil

-- No provider must not narrate to the Console on every page view.
printed = {}
au.sanitise("https://example.com/quiet")
check("with no URL cleaner loaded it stays SILENT — this runs once per page "
      .. "you look at",
      not logged("No provider"))

-- =====================================================================
out("\n== 3. THE ANSWERS CHROME CAN GIVE ==\n")
-- =====================================================================

au.asked, au.answered, au.refused, au.privateSkipped, au.skipped = 0, 0, 0, 0, 0
au.lastError, au.lastURL, au.warnedAboutPermission = nil, nil, false

local got = nil
local function sink(url) got = url end

got = nil
check("a good answer is accepted",
      au.handleAnswer(0, "https://example.com/page\n", "", 1, sink) == true)
check("...and handed on cleanly", got == "https://example.com/page", got)
check("...and counted", au.answered == 1)

-- 🕵️ WHERE THE INCOGNITO PROTECTION ACTUALLY LIVES, stated plainly because
-- it is easy to test the wrong layer and feel covered. The real guard is in
-- the AppleScript (section 1): Chrome is asked for the window's mode and
-- never asked for the URL of a window that is not "normal", so the address
-- of an incognito page does not cross into Lua at all. What follows is the
-- SECOND layer — recognising the sentinel and counting it — and deleting it
-- would not leak anything, because sanitise()'s http-only rule refuses
-- "<<private>>" anyway. Two layers, and only one of them is load-bearing.
local beforeAnswered = au.answered
got = nil
check("🕵️ an incognito window is REFUSED",
      au.handleAnswer(0, "<<private>>", "", 1, sink) == false)
check("🕵️ ...nothing is handed on", got == nil)
check("🕵️ ...and it is not counted as an answer", au.answered == beforeAnswered)
check("🕵️ ...but IS counted separately, so the report can say why the "
      .. "column is thin", au.privateSkipped == 1)
-- The backstop, pinned: whatever a future sentinel is renamed to, anything
-- that is not an http(s) address is never recorded.
check("🕵️ the backstop holds regardless — a sentinel nobody recognises still "
      .. "cannot be written down, because it is not an http address",
      au.sanitise("<<private>>") == "" and au.sanitise("[whatever]") == "")

got = nil
check("a Chrome with no window gives nothing",
      au.handleAnswer(0, "<<none>>", "", 1, sink) == false)
check("...and is not counted as a refusal", au.refused == 0)

got = nil
check("a non-zero exit is a refusal",
      au.handleAnswer(1, "", "boom", 1, sink) == false)
check("...counted", au.refused == 1)
check("...with the error kept for the report", au.lastError == "boom")

-- The one failure that has a fix is the one that gets said out loud.
ALERTS = {}
au.handleAnswer(1, "", "execution error: Not authorized to send Apple events "
                       .. "to Google Chrome. (-1743)", 1, sink)
check("🔑 a -1743 refusal names the Automation permission on screen",
      ALERTS[1] and ALERTS[1]:find("Automation", 1, true) ~= nil, ALERTS[1])
check("🔑 ...and points at the right place in System Settings",
      ALERTS[1] and ALERTS[1]:find("Privacy", 1, true) ~= nil)
ALERTS = {}
au.handleAnswer(1, "", "execution error: … (-1743)", 1, sink)
check("🔑 ...and says it exactly ONCE — a five-second poller could say it "
      .. "seven hundred times a day", #ALERTS == 0)

-- =====================================================================
out("\n== 4. THE ASYNC RACE — an answer about a tab you already left ==\n")
-- =====================================================================

TASKS = {}
au.enabled = true
check("asking Chrome starts a task", au.fetch("Google Chrome", 111) == true)
check("...and it is osascript, off the main thread",
      TASKS[1] and TASKS[1].bin == "/usr/bin/osascript")
check("...running the built script", TASKS[1] and TASKS[1].args[1] == "-e")
check("...and it was actually started", TASKS[1] and TASKS[1].started == true)

check("asking about a non-Chrome app does nothing at all",
      au.fetch("Sublime Text", 112) == false)

-- A second ask abandons the first: its answer is about a page you left.
local first = TASKS[1]
au.fetch("Google Chrome", 113)
check("⚡ a second ask terminates the first — a stale answer is worse than "
      .. "no answer", first.killed == true)

-- 🏁 THE RACE ITSELF, driven through the REAL poller rather than described.
-- Two tab switches inside the same second — which is what makes this worth
-- testing, because os.time() cannot tell them apart.
local poller
for _, t in ipairs(TIMERS) do if t.secs == 5 then poller = t end end
check("(the five-second poller is the one being driven)", poller ~= nil)

TASKS = {}
FRONT = { name = "Google Chrome", title = "Page A", kind = 1 }
poller.fn()
local taskA = TASKS[#TASKS]
check("a Chrome window coming forward asks Chrome", taskA ~= nil)
local seqA = _G.activitySession.seq

FRONT.title = "Page B"
poller.fn()
local taskB = TASKS[#TASKS]
check("switching tabs opens a new session", _G.activitySession.seq ~= seqA)
check("...and asks again", taskB ~= nil and taskB ~= taskA)
check("...within the same second, so a start-time stamp could not tell them "
      .. "apart", _G.activitySession.startTime == os.time())

-- Page A's answer arrives LATE, after you have already moved to page B.
taskA.cb(0, "https://example.com/page-A", "")
check("🏁 a late answer about the tab you already left is DROPPED, not "
      .. "written onto the row you are on now",
      _G.activitySession.url == nil, _G.activitySession.url)

taskB.cb(0, "https://example.com/page-B", "")
check("🏁 ...while the answer for the session you ARE on is stored",
      _G.activitySession.url == "https://example.com/page-B",
      _G.activitySession.url)
FRONT = { name = nil, title = nil, kind = 1 }

-- =====================================================================
out("\n== 5. THE SIX-COLUMN CSV ==\n")
-- =====================================================================

local at = io.open(HS .. "/modules/activity_tracker.lua"):read("a")
check("the header names six columns — url and, since 6.257.0, doc",
      at:find("date,app,title,seconds,url,doc", 1, true) ~= nil)
check("the append writer writes the url", (function()
    for line in at:gmatch("[^\n]+") do
        if line:find("core.csvQuote(entry.url", 1, true) then return true end
    end
    return false
end)())
check("🔒 the url is QUOTED like every other field — a URL can contain a "
      .. "comma and would otherwise split the row",
      at:find("core%.csvQuote%(entry%.url") ~= nil)
check("🔒 the search cache still cannot reach disk", (function()
    for line in at:gmatch("[^\n]+") do
        if line:find("f:write") and line:find("_hay") then return false end
    end
    return true
end)())

-- 🔁 THE UPGRADE, RUN FOR REAL. A four-column file from a previous release
-- is put where the module looks, the module is loaded fresh over it, and
-- what comes back is inspected. Nothing here re-implements the parser —
-- re-implementing it is how a migration test passes while the migration
-- does not work.
do
    os.remove(EXPECTED_CSV)
    local f = io.open(EXPECTED_CSV, "w")
    f:write("date,app,title,seconds\n")
    f:write("2026-08-01,Safari,Some page,120\n")
    f:write('2026-08-01,Google Chrome,"A title, with a comma",60\n')
    f:close()

    local fresh = assert(loadfile(HS .. "/modules/activity_tracker.lua"))()
    fresh.setup(core)

    check("🔁 every pre-6.123.0 row survives the upgrade — none dropped",
          #_G.activityLog == 2, #_G.activityLog)
    check("🔁 ...with their data intact",
          _G.activityLog[1].app == "Safari" and _G.activityLog[1].seconds == 120)
    check("🔁 ...a quoted title containing a comma still reads as ONE field",
          _G.activityLog[2].title == "A title, with a comma",
          _G.activityLog[2].title)
    check("🔁 ...and the missing url reads as empty rather than nil",
          _G.activityLog[1].url == "")

    local firstLine = io.open(EXPECTED_CSV):read("l")
    check("🔁 the file was rewritten ONCE with the six-column header, so it "
          .. "is not left ragged for Excel",
          firstLine == "date,app,title,seconds,url,doc", firstLine)

    local body = io.open(EXPECTED_CSV):read("a")
    check("🔁 ...and the rewritten rows carry BOTH new empty columns",
          body:find("2026%-08%-01,Safari,Some page,120,,\n") ~= nil, body)
    os.remove(EXPECTED_CSV)

    -- That fresh load installed a NEW engine and a new _G.urlReport closed
    -- over it. Everything below must drive the live one, or it is testing a
    -- copy that nothing calls.
    au = _G.activityURL
    check("(the live engine is the one the rest of this file drives)",
          au ~= nil and _G.activityURL == au)
end

-- =====================================================================
out("\n== 6. SEARCH SEES URLS ==\n")
-- =====================================================================

_G.activityLog = {
    { date = "2026-08-20", app = "Google Chrome", title = "Invoice — Acme",
      seconds = 600, url = "https://billing.acme.example/invoices/88" },
    { date = "2026-08-20", app = "Sublime Text", title = "init.lua",
      seconds = 300, url = "" },
}
local ch = _G.choosers.appTracker
check("(the tracker chooser exists)", ch ~= nil)
_G.service.call("activity.renderChoices", "billing.acme")
local hits = ch:choices()
check("🔎 typing a DOMAIN finds the time spent on it",
      #hits >= 2 and hits[2] and hits[2].text:find("Invoice", 1, true) ~= nil,
      hits[2] and hits[2].text)
check("🔎 ...and the row shows the URL it matched",
      hits[2] and hits[2].subText:find("billing.acme.example", 1, true) ~= nil,
      hits[2] and hits[2].subText)
check("...the cache was built including the url",
      _G.activityLog[1]._hay:find("billing.acme.example", 1, true) ~= nil)

_G.service.call("activity.renderChoices", "init.lua")
check("a row with no url still searches by title as before",
      #ch:choices() >= 2)

-- =====================================================================
out("\n== 7. THE REPORT ==\n")
-- =====================================================================

au.asked, au.answered, au.refused = 4, 3, 0
au.privateSkipped, au.skipped, au.lastError = 1, 0, nil
au.enabled = true
CLIP = nil
local rep = _G.urlReport()
check("the report names the file", rep:find("activity_history", 1, true) ~= nil)
check("...counts the rows carrying a URL", rep:find("carrying a URL: 1", 1, true) ~= nil, rep)
check("...and ends in a tick when nothing is wrong",
      rep:find("✅", 1, true) ~= nil, rep)
check("...and copies itself to the clipboard, so it can be pasted back",
      CLIP == rep)

au.asked, au.answered, au.refused = 10, 0, 10
au.lastError = "execution error: Not authorized … (-1743)"
rep = _G.urlReport()
check("🔑 a permission refusal becomes a NUMBERED instruction, not a shrug",
      rep:find("1. macOS has NOT allowed", 1, true) ~= nil, rep)
check("🔑 ...naming Automation by its System Settings name",
      rep:find("Privacy & Security → Automation", 1, true) ~= nil)
check("...and no tick is shown when something is wrong",
      rep:find("✅", 1, true) == nil)

au.asked, au.refused = 0, 0
rep = _G.urlReport()
check("never having asked is diagnosed as its own thing",
      rep:find("has not been asked", 1, true) ~= nil, rep)

au.enabled = false
rep = _G.urlReport()
check("recording switched off is named, with the line to turn it back on",
      rep:find("_G.activityURL.enabled = true", 1, true) ~= nil, rep)
au.enabled = true

-- =====================================================================
out("\n== 8. BREAK TESTS — proving the checks have teeth ==\n")
-- =====================================================================

do
    -- 🔨 BREAK 1: a stripper that only reads the query string. Every
    -- query-string check above still passes. The one that matters — OAuth's
    -- access token in the fragment — is the only one that catches it.
    local function queryOnly(url)
        local base, query = url:match("^([^?]+)%?(.*)$")
        if not base then return url end
        local kept = {}
        for pair in query:gmatch("[^&]+") do
            local n = (pair:match("^([^=]*)") or ""):lower()
            if not au.SECRET_PARAMS[n] then kept[#kept + 1] = pair end
        end
        return #kept > 0 and (base .. "?" .. table.concat(kept, "&")) or base
    end
    check("🔨 BREAK 1: a query-only stripper still passes the query tests…",
          queryOnly("https://app.example.com/home?token=S&view=list")
            == "https://app.example.com/home?view=list")
    check("🔨 …but writes an OAuth access token straight into the CSV, and the "
          .. "fragment check is what sees it",
          queryOnly("https://example.com/cb#access_token=SECRET")
            :find("SECRET", 1, true) ~= nil)
end

do
    -- 🔨 BREAK 2: an allow-list built with a pattern instead of exact keys.
    -- It looks equivalent and it is not: it accepts the injection name.
    local function looseAllow(name)
        return type(name) == "string" and name:find("Chrome") ~= nil
    end
    check("🔨 BREAK 2: a substring allow-list accepts an app named to break "
          .. "out of the AppleScript string",
          looseAllow('Google Chrome" \n do shell script "rm -rf ~" \n tell application "Finder')
            == true)
    check("🔨 …while the real exact-match list refuses it",
          au.CHROMES['Google Chrome" \n do shell script "rm -rf ~" \n tell application "Finder']
            == nil)
end

do
    -- 🔨 BREAK 3: the incognito default flipped to "normal". A window whose
    -- mode cannot be read would then be RECORDED. This is the difference
    -- between failing closed and failing open, in one word of AppleScript.
    local broken = script:gsub('set m to "incognito"', 'set m to "normal"')
    check("🔨 BREAK 3: flipping the default to normal makes an unreadable "
          .. "window record instead of skip — and the fail-closed check sees it",
          broken:find('set m to "incognito"', 1, true) == nil
          and script:find('set m to "incognito"', 1, true) ~= nil)
end

do
    -- 🔨 BREAK 4: a fetch that does not terminate the previous task. Both
    -- answers come back, the later one about a page you already left, and it
    -- overwrites the row you are actually on.
    TASKS = {}
    au.fetch("Google Chrome", 201)
    local a = TASKS[1]
    au.fetch("Google Chrome", 202)
    check("🔨 BREAK 4: the real fetch DOES abandon the stale ask", a.killed == true)
    check("…and a hypothetical one that did not would leave two live tasks "
          .. "racing to write different URLs onto one row",
          #TASKS == 2)
end

do
    -- 🔨 BREAK 5: writing the url unquoted. A URL with a comma in it — and
    -- they are common — would split into two fields and shift every column
    -- after it.
    local nasty = "https://example.com/a,b?x=1"
    local quoted   = core.csvQuote(nasty)
    local unquoted = nasty
    check("🔨 BREAK 5: an unquoted URL with a comma splits the row",
          #core.splitCSVLine("2026-08-20,Chrome,T,60," .. unquoted) == 6)
    check("…while the quoted one the module actually writes keeps five fields",
          #core.splitCSVLine("2026-08-20,Chrome,T,60," .. quoted) == 5)
end

-- =====================================================================
out("\n== 9. THE DOCUMENT COLUMN — the name comes from the app (6.257.0) ==\n")
-- =====================================================================
-- LL: "It's not showing the documents I just worked on." His artefact was
-- one row — `Microsoft Word — 5m 40s` — and the missing half of it is the
-- whole bug: a search row is keyed `app — title`, so an app on its own
-- means the title was EMPTY. Every document name in this module used to be
-- read out of that title, so Word could never appear in the documents list
-- however good the parser was. This section drives the fix: the file the
-- APP has open, asked of doc_memory once per session, written as a sixth
-- column, and used by every reader.

local ad = _G.activityDocWatch
check("the module exposes its document engine as _G.activityDocWatch",
      type(ad) == "table")
check("...and names the six-column header in ONE place, which the writers "
      .. "and the upgrade check both read",
      ad.HEADER == "date,app,title,seconds,url,doc", ad.HEADER)

-- ---- ad.docName — PURE, and the title reader is an ARGUMENT ------------
-- Given a resolver rather than reaching for one (6.230.0's shape), so the
-- rule is provable with no Mac and no window plumbing.
-- The resolver handed in is the module's REAL title reader, not a
-- lookalike written here — a stand-in that cuts at a different dash proves
-- the wiring and nothing else.
local titleReader = _G.activityDocFileForTest
check("(the real title reader is what gets handed in)",
      type(titleReader) == "function")

do
    local name, why = ad.docName({ doc = "/Users/x/Documents/Report Q3.docx",
                                   title = "", app = "Microsoft Word" }, titleReader)
    check("📄 a session the APP named answers with the file's own name",
          name == "Report Q3.docx", name)
    check("...and says where the name came from, so the report can count "
          .. "the two sources apart",
          why == "the app named the file", why)
end

do
    -- 🔑 THE ORDER IS THE RULE. Word's title bar can say anything — and in
    -- LL's case said nothing at all — while AXDocument is the file itself.
    -- An answer beats a guess, so a session carrying both is named by the
    -- app. Reversing these two lines is a mutation below.
    local name = ad.docName({ doc = "/Users/x/Real.docx",
                              title = "Decoy.docx — Word", app = "Microsoft Word" },
                            titleReader)
    check("🔑 when a session has BOTH, the app's answer beats the title bar",
          name == "Real.docx", name)
end

do
    local name, why = ad.docName({ doc = "", title = "Notes.md - Sublime Text",
                                   app = "Sublime Text" }, titleReader)
    check("📄 a session with no document falls back to the title, exactly as "
          .. "before 6.257.0 — nothing that worked stops working",
          name == "Notes.md", name)
    check("...and says so", why == "read out of the window title", why)
end

check("📄 a session with neither is not a document",
      ad.docName({ doc = "", title = "#general", app = "Slack" }, titleReader) == nil)
check("📄 ...and the WHY is a sentence, not a silence",
      select(2, ad.docName({ doc = "", title = "#general", app = "Slack" },
                           titleReader)) == "no document")
check("📄 a path ending in a slash names no file and falls through",
      ad.docName({ doc = "/Users/x/Documents/", title = "", app = "Word" },
                 titleReader) == nil)
check("📄 nil in, nil out — never a throw", ad.docName(nil, titleReader) == nil)
check("📄 ...and with NO title reader at all it still answers about the doc",
      ad.docName({ doc = "/a/b/C.pdf" }) == "C.pdf")

-- ---- ad.rowLabel — what ⇪0 calls a session ----------------------------
check("🔎 a search row is still called by its title where there is one",
      ad.rowLabel({ title = "Invoice — Acme", doc = "/x/y.pdf" }) == "Invoice — Acme")
check("🔎 ...and by its DOCUMENT where there is not — which is LL's row, the "
      .. "one that read `Microsoft Word` and could not say which file",
      ad.rowLabel({ title = "", doc = "/Users/x/Strategies.docx" })
        == "Strategies.docx")
check("🔎 a session with neither is still named by its app alone",
      ad.rowLabel({ title = "", doc = "" }) == nil)

-- ---- ad.frontDoc — bounded three ways ---------------------------------
local FRONTCALLS = 0
local ANSWER = nil          -- what docs.front hands back
local function installDocs(watchList)
    _G.service.registry["docs.front"] = function()
        FRONTCALLS = FRONTCALLS + 1
        if type(ANSWER) == "function" then return ANSWER() end
        if type(ANSWER) == "table" then return ANSWER end
        return nil, "no document in the front window"
    end
    if watchList then
        _G.service.registry["docs.watches"] = function(n) return watchList[n] == true end
    else
        _G.service.registry["docs.watches"] = nil
    end
end
local function zero()
    ad.asked, ad.answered, ad.none, ad.failed, ad.skipped = 0, 0, 0, 0, 0
    ad.degraded, ad.worstMs, ad.lastMs = 0, nil, nil
    FRONTCALLS = 0; DEGRADES = {}
end

installDocs({ ["Microsoft Word"] = true })

zero()
ANSWER = { path = "/Users/x/Strategies of the Directors.docx",
           title = "Strategies of the Directors", app = "Microsoft Word" }
check("📄 an app doc_memory watches is asked, and the path comes back",
      ad.frontDoc("Microsoft Word") == "/Users/x/Strategies of the Directors.docx")
check("...counted as answered", ad.asked == 1 and ad.answered == 1, ad.answered)

zero()
check("🔒 an app doc_memory does NOT watch is never asked — the cost is an "
      .. "Accessibility read on the main thread, so it is not spent on an "
      .. "app that cannot answer",
      ad.frontDoc("Slack") == nil and FRONTCALLS == 0, FRONTCALLS)
check("...and that is a SKIP, not a failure", ad.skipped == 1 and ad.failed == 0)

-- 🔑 THE APP LIST LIVES IN doc_memory, and this module asks it rather than
-- keeping a copy. A copy is a list that drifts the day LL edits dm.apps.
zero()
installDocs({ ["Microsoft Word"] = true, ["Preview"] = true })
check("🔑 adding an app to doc_memory's list is enough — this module asks "
      .. "`docs.watches` and carries no list of its own",
      ad.frontDoc("Preview") ~= nil)
local atSrc = io.open(HS .. "/modules/activity_tracker.lua"):read("a")
check("🔒 ...asserted against the SOURCE too: there is no second copy of "
      .. "the app list here",
      not atSrc:find('["Microsoft Word"]', 1, true))
check("🔒 and it reads no Accessibility of its own — doc_memory is still the "
      .. "only AXDocument reader in this config",
      not atSrc:find("hs.axuielement", 1, true)
      and not atSrc:find("attributeValue(", 1, true))

-- 🔎 THREE STATES, NEVER TWO. "You were not in a document" and "this could
-- not be asked" are opposite facts about the same Mac.
zero()
ANSWER = nil     -- dm.front's own nil, why
check("📄 a front window with no document answers, and is counted as an "
      .. "ANSWER", ad.frontDoc("Microsoft Word") == nil and ad.none == 1)
check("...never as a failure", ad.failed == 0)

zero()
ANSWER = function() return nil end     -- nothing at all: no path, no reason
check("📄 a read that comes back with nothing AND no reason is a FAILURE",
      ad.frontDoc("Microsoft Word") == nil and ad.failed == 1)
check("...never a 'no document'", ad.none == 0)

zero()
ANSWER = function() error("AX went away", 0) end
check("📄 a provider that THROWS does not take the poller with it",
      ad.frontDoc("Microsoft Word") == nil)
check("...and is counted, not swallowed", ad.failed == 1)

zero()
ANSWER = { path = "", title = "x" }
check("📄 an empty path is not a document — it would name every row after "
      .. "it with nothing", ad.frontDoc("Microsoft Word") == nil)
check("...counted with the answers that had no document", ad.none == 1)

-- 🔔 THE DOOR. A slow Accessibility read is a stalled main thread, which is
-- a mouse this Mac has lost (6.228.0) — it is SEEN, not logged.
zero()
ANSWER = function()
    CLOCK = CLOCK + 0.5      -- 500 ms inside the read
    return { path = "/x/Slow.docx" }
end
ad.frontDoc("Microsoft Word")
check("🔔 a read past ad.slowMs takes the degrade door", #DEGRADES == 1, #DEGRADES)
check("...and the alert NAMES the tool and the milliseconds",
      DEGRADES[1] and DEGRADES[1]:find("Activity documents", 1, true)
      and DEGRADES[1]:find("500 ms", 1, true), DEGRADES[1])
check("...and it is counted for the report", ad.degraded == 1)
check("...and the worst read of the session is remembered",
      math.floor(ad.worstMs or 0) == 500, ad.worstMs)

zero()
ANSWER = { path = "/x/Fast.docx" }
ad.frontDoc("Microsoft Word")
check("🔔 a fast read says nothing — this runs every time you change window",
      #DEGRADES == 0 and ad.degraded == 0)

zero()
ad.askDocs = false
check("🔌 the switch is real: with askDocs off nothing is asked at all",
      ad.frontDoc("Microsoft Word") == nil and FRONTCALLS == 0)
check("...and it reads as a skip", ad.skipped == 1)
ad.askDocs = true

zero()
_G.service.registry["docs.front"] = nil
check("🔌 a Mac without doc_memory loaded skips silently and keeps the "
      .. "title fallback", ad.frontDoc("Microsoft Word") == nil and ad.skipped == 1)
installDocs({ ["Microsoft Word"] = true })

-- ---- END TO END: LL's own session, driven through the poller ----------
do
    local realTime = os.time
    NOW = 1758240000            -- a fixed second, so the row's date is fixed
    os.time = function() return NOW end

    os.remove(EXPECTED_CSV)
    local f = io.open(EXPECTED_CSV, "w")
    f:write("date,app,title,seconds,url,doc\n")
    f:close()

    local fresh = assert(loadfile(HS .. "/modules/activity_tracker.lua"))()
    fresh.setup(core)
    ad = _G.activityDocWatch
    installDocs({ ["Microsoft Word"] = true })
    ANSWER = { path = "/Users/x/Documents/Strategies of the Directors.docx",
               title = "Strategies of the Directors", app = "Microsoft Word" }

    -- 🚨 THIS IS THE REPORTED BUG, REPRODUCED: Word in front with NO window
    -- title. Before 6.257.0 the row written here carried an empty title and
    -- nothing else, and no document row could ever be derived from it.
    FRONT = { name = "Microsoft Word", title = nil, kind = 1 }
    _G.activityPoller.fn()
    check("🚨 the session opens with no title — the bug's own condition",
          _G.activitySession.title == nil and _G.activitySession.app == "Microsoft Word")
    check("🚨 ...and the document was asked for at the moment it opened",
          _G.activitySession.doc
            == "/Users/x/Documents/Strategies of the Directors.docx",
          _G.activitySession.doc)

    local asksAfterOpen = ad.asked
    _G.activityPoller.fn(); _G.activityPoller.fn(); _G.activityPoller.fn()
    check("⏱ ...and asked ONCE, not on every tick — an Accessibility read "
          .. "five times a minute for ever is 6.228.0's cost",
          ad.asked == asksAfterOpen, ad.asked)

    NOW = NOW + 340             -- 5m 40s, LL's own number
    FRONT = { name = "Finder", title = "Downloads", kind = 1 }
    _G.activityPoller.fn()

    local last = _G.activityLog[#_G.activityLog]
    check("📄 the closed session records the document",
          last and last.app == "Microsoft Word"
          and last.doc == "/Users/x/Documents/Strategies of the Directors.docx",
          last and last.doc)
    check("📄 ...with the time it always had", last and last.seconds == 340)

    local body = io.open(EXPECTED_CSV):read("a")
    check("📄 ...and the CSV row carries it as the sixth column",
          body:find("Strategies of the Directors.docx", 1, true) ~= nil, body)

    -- 📄 THE LIST LL WAS LOOKING AT
    local docs = _G.activityDocsForTest()
    check("📄 ⇪⇧W finally shows the document — the whole report, in one "
          .. "assertion", (function()
              for _, r in ipairs(docs) do
                  if r.file == "Strategies of the Directors.docx" then return true end
              end
              return false
          end)(), #docs)
    check("📄 ...named by the app, and the row says so",
          docs[1] and docs[1].why == "the app named the file", docs[1] and docs[1].why)

    -- 🔎 AND THE ROW HE ACTUALLY RAN: ⇪0, typing "Word"
    _G.service.call("activity.renderChoices", "Word")
    local hits = _G.choosers.appTracker:choices()
    check("🔎 ⇪0 no longer answers `Microsoft Word` alone — the row names the "
          .. "document",
          hits[2] and hits[2].text
            == "Microsoft Word — Strategies of the Directors.docx",
          hits[2] and hits[2].text)

    _G.service.call("activity.renderChoices", "Strategies")
    local byName = _G.choosers.appTracker:choices()
    check("🔎 ...and typing the FILE NAME finds the time spent in it",
          byName[2] and byName[2].text:find("Strategies", 1, true) ~= nil,
          byName[2] and byName[2].text)

    -- 🔒 A PATH HOLDS COMMAS AS READILY AS A URL DOES
    NOW = NOW + 10
    ANSWER = { path = "/Users/x/Notes, drafts/Plan, final.docx" }
    FRONT = { name = "Microsoft Word", title = nil, kind = 1 }
    _G.activityPoller.fn()
    NOW = NOW + 60
    FRONT = { name = "Finder", title = "Downloads", kind = 1 }
    _G.activityPoller.fn()
    local lines = {}
    for l in io.open(EXPECTED_CSV):read("a"):gmatch("[^\n]+") do lines[#lines + 1] = l end
    check("🔒 a document path containing commas is QUOTED and still reads as "
          .. "six fields", #core.splitCSVLine(lines[#lines]) == 6,
          #core.splitCSVLine(lines[#lines]))
    check("🔒 ...and comes back whole",
          core.splitCSVLine(lines[#lines])[6]
            == "/Users/x/Notes, drafts/Plan, final.docx",
          core.splitCSVLine(lines[#lines])[6])

    -- 🗑 ⇪⇧E DELETES A DOCUMENT THE APP NAMED. The editor finds a row's
    -- sessions by re-running the same join the list ran — so a join that
    -- still read the title would show LL a Word document and then delete
    -- nothing at all when he asked it to, which is worse than not showing
    -- it. One function, two callers (6.231.0), asserted here.
    do
        local before = #_G.activityLog
        local key
        for _, r in ipairs(_G.activityDocsForTest()) do
            if r.file == "Strategies of the Directors.docx" then key = r.key end
        end
        check("(the Word row is there to delete)", key ~= nil)
        local removed = _G.activityDocDeleteForTest(key)
        check("🗑 deleting a document the APP named removes its sessions",
              removed == 1 and #_G.activityLog == before - 1, removed)
        check("🗑 ...and the row is gone from the list", (function()
                  for _, r in ipairs(_G.activityDocsForTest()) do
                      if r.file == "Strategies of the Directors.docx" then return false end
                  end
                  return true
              end)())
    end

    -- 🔁 THE UPGRADE, RUN FOR REAL, over a five-column file
    os.remove(EXPECTED_CSV)
    local g = io.open(EXPECTED_CSV, "w")
    g:write("date,app,title,seconds,url\n")
    g:write("2026-09-01,Safari,Some page,120,https://example.com/a\n")
    g:close()
    local fresh2 = assert(loadfile(HS .. "/modules/activity_tracker.lua"))()
    fresh2.setup(core)
    check("🔁 a five-column row survives the upgrade with its url intact",
          #_G.activityLog == 1
          and _G.activityLog[1].url == "https://example.com/a", #_G.activityLog)
    check("🔁 ...and its missing doc reads as EMPTY rather than nil, so every "
          .. "reader can treat both shapes the same",
          _G.activityLog[1].doc == "")
    check("🔁 the file was rewritten ONCE into the six-column header",
          io.open(EXPECTED_CSV):read("l") == "date,app,title,seconds,url,doc",
          io.open(EXPECTED_CSV):read("l"))

    -- 🔎 THE REPORT — the tool that had none
    printed = {}
    local L = _G.activityDocsReport()
    check("🔎 _G.activityDocsReport() exists and prints as ONE string "
          .. "(6.179.1)", type(L) == "table" and #printed == 1, #printed)
    local rep = printed[1] or ""
    check("🔎 ...it counts the reads apart",
          rep:find("asked", 1, true) and rep:find("named a file", 1, true)
          and rep:find("had no document", 1, true)
          and rep:find("could not be asked", 1, true))
    check("🔎 ...names what the asking BOUGHT, not only what it cost",
          rep:find("document row", 1, true) ~= nil)
    check("🔎 ...and says plainly that old rows cannot gain a document",
          rep:find("before 6.257.0", 1, true) ~= nil)

    _G.service.registry["docs.front"] = nil
    printed = {}
    _G.activityDocsReport()
    check("🔎 a Mac with doc_memory absent reads DIFFERENTLY from one where "
          .. "nothing was asked", (printed[1] or ""):find("doc_memory is not loaded",
                                                          1, true) ~= nil,
          printed[1])
    installDocs({ ["Microsoft Word"] = true })

    os.time = realTime
    os.remove(EXPECTED_CSV)
    au = _G.activityURL
end

-- ---- doc_memory's half -------------------------------------------------
do
    local dmSrc = io.open(HS .. "/modules/doc_memory.lua"):read("a")
    check("🔌 doc_memory publishes the list it owns as `docs.watches`",
          dmSrc:find('core.provide("docs.watches"', 1, true) ~= nil)
    check("🔌 ...and the answer is an EXACT match, never a substring — "
          .. "`Microsoft Wordpad` is not `Microsoft Word`",
          dmSrc:find("return dm.apps%[name%] == true") ~= nil)
end

-- ---- cleanup ------------------------------------------------------------
os.remove(EXPECTED_CSV)
os.remove(CSVPATH)

-- ---- report -------------------------------------------------------------
print = realPrint
out("\n")
-- The runner greps for "N passed, M failed" — print it in that exact shape
-- whatever the outcome, or a green suite is reported as one that crashed.
if fail == 0 then
    out(string.format("✅ test_activity_url: %d passed, %d failed\n", pass, fail))
else
    out(string.format("❌ test_activity_url: %d passed, %d failed\n", pass, fail))
    for _, f in ipairs(failures) do out("   • " .. f .. "\n") end
end
os.exit(fail == 0 and 0 or 1)
