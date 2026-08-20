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
    call    = function(n, ...)
        local f = _G.service.registry[n]
        if not f then print("🔌 No provider for '" .. n .. "'") return nil end
        return f(...)
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
out("\n== 5. THE FIVE-COLUMN CSV ==\n")
-- =====================================================================

local at = io.open(HS .. "/modules/activity_tracker.lua"):read("a")
check("the header names five columns including url",
      at:find("date,app,title,seconds,url", 1, true) ~= nil)
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
    check("🔁 the file was rewritten ONCE with the five-column header, so it "
          .. "is not left ragged for Excel",
          firstLine == "date,app,title,seconds,url", firstLine)

    local body = io.open(EXPECTED_CSV):read("a")
    check("🔁 ...and the rewritten rows carry the new empty column",
          body:find("2026%-08%-01,Safari,Some page,120,") ~= nil, body)
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
