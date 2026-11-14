-- =====================================================================
-- test_tab_search.lua — ⇪⇧' finds a tab and lands on the right one
-- =====================================================================
--     lua5.4 test_tab_search.lua [/path/to/hammerspoon]
--
-- Executes modules/tab_search.lua against a stubbed hs.
--
-- THREE SECTIONS HAVE TEETH:
--
--   §2 THE RUNNING CHECK. Naming an application in AppleScript LAUNCHES
--      it. A scan that asks a closed Safari for its tabs OPENS SAFARI —
--      so a keystroke meant to find a tab you already have would start a
--      browser you did not want, every single time.
--
--   §4 THE VERIFY. A tab is addressed as "tab 4 of window 2", which is
--      where it happens to be sitting. Drag a tab between the scan and
--      the jump and those numbers point somewhere else. The jump returns
--      the URL it actually landed on and Lua compares it, so "the tab
--      moved" is something you are told rather than something you find
--      out by reading the wrong page.
--
--   §5 NEVER CACHED. Following from §4: a list from ten seconds ago
--      describes a browser that has moved on, so every press rescans.

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

print = function() end

-- ---- the stub Mac ------------------------------------------------------
local TASKS    = {}
local ALERTS   = {}
local TIMERS   = {}
local CHOOSERS = {}
local SHOWS    = 0
local NOW      = 1000
-- Chrome and Safari, which is what FIXTURE describes. A test that wants
-- a different world sets this and calls reset().
local RUNNING  = { "Google Chrome", "Safari" }

hs = {
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    task = {
        new = function(bin, cb, args)
            local t = { bin = bin, cb = cb, args = args,
                        started = false, terminated = false }
            function t:start() self.started = true ; return self end
            function t:terminate() self.terminated = true ; return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    -- 🗂 6.439.0 — WHICH BROWSERS ARE RUNNING IS A LUA QUESTION NOW.
    -- The script used to ask System Events; the module asks Hammerspoon,
    -- which is one fewer Apple Event, one fewer Automation grant and one
    -- fewer app that has to be launched before a tab can be read. The
    -- stub has to answer it or every scan looks like "nothing running".
    application = {
        runningApplications = function()
            local out = {}
            for _, n in ipairs(RUNNING) do
                out[#out + 1] = { name = function() return n end }
            end
            return out
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, choices_ = {}, placeholder = "", query_ = nil }
            function c:choices(x) self.choices_ = x ; return self end
            function c:placeholderText(x) self.placeholder = x ; return self end
            function c:query(x) self.query_ = x ; return self end
            function c:show() SHOWS = SHOWS + 1 ; return self end
            function c:width(n) return self end
            function c:searchSubText(b) return self end
            function c:hideCallback(f) self.hideCb = f ; return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.notices = { record = function() end }

local BOUND, PROVIDED, CALLS = {}, {}, {}
local CORE = {
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
    call    = function(n, ...) CALLS[#CALLS + 1] = { n = n, args = { ... } } ; return true end,
}

local chunk = assert(loadfile(HS .. "/modules/tab_search.lua"))
local M = chunk()
M.setup(CORE)
local ts = _G.tabSearch

local SEP = "\31"
local function line(browser, w, t, url, title)
    return table.concat({ browser, w, t, url, title }, SEP)
end
local FIXTURE = table.concat({
    line("Google Chrome", 1, 1, "https://github.com/x/y", "x/y: a repo"),
    line("Google Chrome", 1, 2, "https://news.example.com/", "The News"),
    line("Google Chrome", 2, 1, "https://docs.example.com/a", "Docs — A"),
    line("Safari",        1, 1, "https://apple.com/", "Apple"),
}, "\n") .. "\n"

local function reset()
    TASKS, ALERTS, TIMERS = {}, {}, {}
    ts.pending, ts.lastNote, ts.lastWhy = false, nil, nil
    ts.scanTasks, ts.scanTimers = {}, {}
end

-- 🗂 6.439.0 — ONE TASK PER RUNNING BROWSER, so "answer the scan"
-- means answering each of them. A helper, because fifteen call sites
-- otherwise have to know how many browsers the world has.
-- 🔬 AND IT HANDS EACH TASK ONLY ITS OWN BROWSER'S LINES, because
-- that is what a real osascript run for one browser returns. A stub
-- that gave every task the whole fixture would duplicate every row and
-- certify a scan that double-counts (6.290.0).
local function answerAll(output, code, err)
    for _, t in ipairs(TASKS) do
        if t.cb then
            local b = t.args and t.args[3]
            local mine = output
            if mine == nil and b then
                local keep = {}
                for line in FIXTURE:gmatch("[^\n]+") do
                    if line:sub(1, #b) == b then keep[#keep + 1] = line end
                end
                mine = table.concat(keep, "\n") .. (#keep > 0 and "\n" or "")
            end
            t.cb(code or 0, mine or "", err or "")
        end
    end
end

-- =====================================================================
out("\n=== 1. it loads and binds ===\n")
-- =====================================================================
check("the module returns a table with a name", M.name == "Tab Search")
check("it declares a family", M.family == "find")
check("⇪⇧' is bound", BOUND["shift+'"] ~= nil)
check("the binding is attributed to this module",
      BOUND["shift+'"] and BOUND["shift+'"].src == "tab search")
check("it publishes _G.tabSearch", type(ts) == "table")
check("two services are published",
      PROVIDED["tabs.show"] and PROVIDED["tabs.report"])
check("the cheat sheet key cell is exactly ⇪⇧'", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪⇧'" then return true end
    end
    return false
end)())

-- =====================================================================
out("\n=== 2. 🚨 IT ONLY ASKS BROWSERS THAT ARE ALREADY RUNNING ===\n")
-- =====================================================================
-- Naming an app in AppleScript launches it. Without this guard, ⇪⇧' on a
-- Mac with Safari closed OPENS SAFARI — every time — and then lists its
-- blank new tab.
-- 🗂 6.439.0 — THE RULE, NOT THE MECHANISM. These pinned the two
-- lines of AppleScript that asked System Events, which was 6.248.0's
-- defect waiting to happen: the rule is "never name a browser that is
-- not running", and the moment that moved into Lua — one fewer Apple
-- Event, one fewer Automation grant, one fewer app to launch — two
-- green checks went red over code that got STRICTER.
check("🚨 a browser that is not running is never named to AppleScript",
      (function()
        local got = ts.runningFrom({ "Google Chrome", "Finder" }, ts.browsers())
        if #got ~= 1 or got[1] ~= "Google Chrome" then return false end
        -- The fixture that bites: Safari CLOSED. With every browser
        -- running, filtering and not filtering agree (6.230.0), and
        -- naming Safari here is what OPENS Safari.
        for _, b in ipairs(got) do if b:find("Safari") then return false end end
        return true
      end)())
check("🚨 …and with nothing running, nothing is asked at all",
      #ts.runningFrom({ "Finder", "Mail" }, ts.browsers()) == 0)
check("🗂 …and the script no longer reaches for System Events",
      ts.scanScript:find("System Events", 1, true) == nil)
-- ⚠️ `using terms from` is what makes a dynamic `tell application bn`
-- compile at all: AppleScript resolves an app's vocabulary at COMPILE
-- time, and a tell whose target is a variable has none — so `tabs` and
-- `active tab index` are unknown words and the whole script fails.
check("🚨 the Chromium branch borrows Chrome's dictionary",
      ts.scanScript:find('using terms from application "Google Chrome"', 1, true) ~= nil)
check("…and Safari is handled on its own branch, because its terms differ",
      ts.scanScript:find('bn starts with "Safari"', 1, true) ~= nil)
-- 🚨 6.152.0 — THE SAFARI BRANCH NEEDS THE SAME LOAN. Without `using
-- terms from application "Safari"`, the bare word `tab` in `tab ti of
-- window wi` parses as AppleScript's built-in tab CHARACTER constant and
-- the `ti` after it is a syntax error — a COMPILE failure that killed the
-- WHOLE script on every press ("osascript exited 1: 577:579", LL's ⛔
-- errors section) while the alert blamed Automation permission. These two
-- pins are the regression sentries for that.
check("🚨 the Safari SCAN branch borrows Safari's dictionary (6.152.0)",
      ts.scanScript:find('using terms from application "Safari"', 1, true) ~= nil)
check("🚨 the Safari JUMP branch borrows it too — same compile trap",
      ts.jumpScript:find('using terms from application "Safari"', 1, true) ~= nil)
check("Safari asks for `name of t`, which is what Safari calls a title",
      ts.scanScript:find("name of t", 1, true) ~= nil)
check("…and Chromium asks for `title of t`",
      ts.scanScript:find("title of t", 1, true) ~= nil)
check("every window is wrapped in its own try, so one bad window costs one",
      select(2, ts.scanScript:gsub("try", "")) >= 4,
      select(2, ts.scanScript:gsub("try", "")))
check("the browsers asked include both families",
      (function()
    local all = table.concat(ts.browsers(), ",")
    return all:find("Safari", 1, true) and all:find("Google Chrome", 1, true)
       and all:find("Microsoft Edge", 1, true) and all:find("Arc", 1, true)
end)())

-- 🚨 AND IT RUNS OUT OF PROCESS. An AppleScript error inside
-- Hammerspoon's own Apple Event handler is an Objective-C exception; it
-- unwinds past pcall and kills the app.
reset()
ts.scan(function() end)
check("🚨 the scan is a CHILD PROCESS, not hs.osascript",
      TASKS[1] and TASKS[1].bin == "/usr/bin/osascript", TASKS[1] and TASKS[1].bin)
check("…and it was actually started", TASKS[1] and TASKS[1].started == true)
check("the browser is passed as an ARGUMENT, not baked into the script",
      TASKS[1] and #TASKS[1].args == 3 and TASKS[1].args[1] == "-e",
      TASKS[1] and table.concat(TASKS[1].args or {}, "|", 3))
-- 🗂 ONE TASK PER RUNNING BROWSER. All of them used to go into one
-- osascript under one budget, so a browser with two hundred tabs spent
-- the whole six seconds and every other browser was killed with it —
-- then reported as "No browser answered" and blamed on a permission
-- prompt that had been granted years ago.
check("🗂 …one task per running browser, so a slow one cannot kill "
      .. "the rest", #TASKS == #RUNNING, #TASKS)
check("🗂 …and each is asked about exactly one browser",
      (function()
        local seen = {}
        for _, t in ipairs(TASKS) do
          local b = t.args and t.args[3]
          if not b or seen[b] then return false end
          seen[b] = true
        end
        return true
      end)())

-- =====================================================================
out("\n=== 3. parsing: five fields or the row is dropped ===\n")
-- =====================================================================
local rows, counts = ts.parse(FIXTURE)
check("every tab was parsed", #rows == 4, #rows)
check("the browser is kept", rows[1].browser == "Google Chrome", rows[1].browser)
check("window and tab are NUMBERS, because they index a window",
      math.type(rows[1].win) == "integer" and math.type(rows[1].tab) == "integer")
check("the URL is kept whole", rows[1].url == "https://github.com/x/y", rows[1].url)
check("the title is kept whole", rows[1].title == "x/y: a repo", rows[1].title)
check("a second window is distinguished from the first",
      rows[3].win == 2 and rows[3].tab == 1)
check("Safari's rows come through the same shape",
      rows[4].browser == "Safari" and rows[4].url == "https://apple.com/")
check("the per-browser counts are tallied",
      counts["Google Chrome"] == 3 and counts["Safari"] == 1,
      counts["Google Chrome"])

-- 🚨 A row missing its window number would jump SOMEWHERE, and there is
-- no safe default for "which window". Dropping it is the only honest
-- option.
local broken = "Google Chrome" .. SEP .. SEP .. "1" .. SEP .. "https://x/" .. SEP .. "X\n"
check("🚨 a row with no window number is DROPPED, not guessed at",
      #ts.parse(broken) == 0, #ts.parse(broken))
check("a title containing a comma or a dash survives", (function()
    local r = ts.parse(line("Safari", 1, 1, "https://a/", "A — b, c: d") .. "\n")
    return r[1] and r[1].title == "A — b, c: d"
end)())
check("an empty title falls back to the URL, so no row is blank", (function()
    local r = ts.parse(line("Safari", 1, 1, "https://a/", "") .. "\n")
    return r[1] and r[1].title == "https://a/"
end)())
check("empty output parses to nothing rather than throwing", #ts.parse("") == 0)
check("nil parses to nothing", #ts.parse(nil) == 0)

-- =====================================================================
out("\n=== 4. 🚨 THE JUMP VERIFIES WHERE IT LANDED ===\n")
-- =====================================================================
check("🚨 the jump script RETURNS the URL it ended on",
      ts.jumpScript:find("return URL of", 1, true) ~= nil)
check("…it raises the window as well as the tab",
      ts.jumpScript:find("set index of window wi to 1", 1, true) ~= nil)
check("…and activates the browser, so it comes to the front",
      ts.jumpScript:find("activate", 1, true) ~= nil)
check("Safari sets `current tab`, Chromium sets `active tab index`",
      ts.jumpScript:find("set current tab of window wi", 1, true) ~= nil
      and ts.jumpScript:find("set active tab index of window wi to ti", 1, true) ~= nil)

reset()
ts.jump(rows[1])
local jump = TASKS[1]
check("the jump is a child process too", jump and jump.bin == "/usr/bin/osascript")
check("…with the browser, window and tab as positional arguments",
      jump and jump.args[3] == "Google Chrome" and jump.args[4] == "1"
      and jump.args[5] == "1",
      jump and table.concat(jump.args, " | ", 3))

-- The happy path: it landed where it said.
jump.cb(0, "https://github.com/x/y\n", "")
check("landing on the picked URL is silent — success is not an announcement",
      #ALERTS == 0, ALERTS[1])
check("…and it is counted", ts.jumps == 1, ts.jumps)

-- 🚨 THE CASE THIS SECTION EXISTS FOR: the tab moved between the scan
-- and the jump, so window 1 tab 1 is now a different page.
reset()
ts.jump(rows[1])
TASKS[1].cb(0, "https://somewhere.else/\n", "")
check("🚨 landing SOMEWHERE ELSE is reported, not passed off as success",
      (function()
    for _, a in ipairs(ALERTS) do
        if a:find("That tab moved", 1, true) then return true end
    end
    return false
end)(), ALERTS[1])
check("…naming where you actually are", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("somewhere.else", 1, true) then return true end
    end
    return false
end)())
check("…and it is NOT counted as a successful jump", ts.jumps == 1, ts.jumps)

reset()
ts.jump(rows[1])
TASKS[1].cb(1, "", "Not authorised to send Apple events")
check("a refusal is reported with the browser named", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("would not switch", 1, true) then return true end
    end
    return false
end)(), ALERTS[1])
check("…and the reason is recorded for the report",
      ts.lastNote and ts.lastNote:find("Apple events", 1, true) ~= nil, ts.lastNote)

-- =====================================================================
out("\n=== 5. 🚨 THE LIST IS NEVER CACHED ===\n")
-- =====================================================================
-- Following from §4: window and tab numbers are positions, so a list
-- from ten seconds ago describes a browser that has moved on.
reset()
ts.show()
-- 🗂 6.439.0 — ONE TASK PER RUNNING BROWSER, asserted as the RULE
-- rather than the number 1: a single shared osascript is what let one
-- slow browser kill every other and report it as "no browser answered".
check("the first press scans every running browser, one task each",
      #TASKS == #RUNNING, #TASKS .. " for " .. #RUNNING .. " browser(s)")
-- Guarded: a build that CACHED would not scan at all, and reading
-- TASKS[1] on nil would take the file down before it could report the
-- failures this section exists for.
answerAll()
local firstShows = SHOWS
check("…and the panel opened", firstShows >= 1, firstShows)

reset()
ts.show()
check("🚨 the SECOND press scans again — no cache, ever",
      #TASKS == #RUNNING, #TASKS)
NOW = NOW + 1
reset()
ts.show()
check("…and so does the third, one second later", #TASKS == #RUNNING, #TASKS)

-- =====================================================================
out("\n=== 6. 🚨 A ROW CARRIES A NUMBER, NOT A TABLE ===\n")
-- =====================================================================
reset()
ts.show()
answerAll()
local c = CHOOSERS[#CHOOSERS]
check("the panel lists every tab", #c.choices_ == 4, #c.choices_)
check("every row value is a string, number or boolean", (function()
    for _, ch in ipairs(c.choices_) do
        for k, v in pairs(ch) do
            local t = type(v)
            if t ~= "string" and t ~= "number" and t ~= "boolean" then
                return false, k .. " is a " .. t
            end
        end
    end
    return true
end)())
check("…and every payload resolves to a real tab", (function()
    for _, ch in ipairs(c.choices_) do
        if ts.rows[ch.idx] == nil then return false end
    end
    return true
end)())
check("🚨 each row NAMES its browser — two copies stay two rows", (function()
    for _, ch in ipairs(c.choices_) do
        if not (ch.subText:find("Google Chrome", 1, true)
                or ch.subText:find("Safari", 1, true)) then return false end
    end
    return true
end)())
check("the URL is searchable too, so “github” finds it either way",
      (function()
    for _, ch in ipairs(c.choices_) do
        if ch.subText:find("github.com", 1, true) then return true end
    end
    return false
end)())
check("the placeholder counts each browser", c.placeholder:find("Google Chrome 3",
      1, true) ~= nil, c.placeholder)
-- 🗂 6.439.0 — ASSERTED AGAINST THE ROW, NOT AGAINST A POSITION.
-- This pinned "row 3 is Chrome window 2", which was true while one
-- script emitted the fixture in its own order and false the moment the
-- browsers were asked separately. The RULE is that ⏎ jumps to the tab
-- the row describes, whatever position it is in (6.248.0).
check("⏎ on a row jumps to THAT tab", (function()
    TASKS = {}
    local want = ts.rows[3]
    c.cb({ idx = 3 })
    local j = TASKS[1]
    return want and j and j.args[3] == want.browser
           and j.args[4] == tostring(want.win)
           and j.args[5] == tostring(want.tab)
end)(), TASKS[1] and table.concat(TASKS[1].args, "|", 3))
-- 🚨 AND THE ORDER IS DETERMINISTIC, which the parallel scan could
-- easily not have been: four browsers answer in whatever order they
-- finish, and ⌘–1–⌘9 name a POSITION — so a row that moves between
-- presses is a jump to the wrong tab.
-- 🚨 THE FIXTURE ANSWERS OUT OF ORDER, OR IT PROVES NOTHING. Chrome
-- answering LAST is what separates a sorted list from one that is
-- merely in the order the browsers happened to finish — with them
-- answering in sorted order already, both implementations agree and the
-- check passes with the sort deleted (6.230.0, found by the sweep).
do
    reset()
    ts.show()
    -- Answer in REVERSE, and hand Chrome's windows back high-to-low.
    for i = #TASKS, 1, -1 do
        local t, b = TASKS[i], TASKS[i].args and TASKS[i].args[3]
        local keep = {}
        for line in FIXTURE:gmatch("[^\n]+") do
            if b and line:sub(1, #b) == b then table.insert(keep, 1, line) end
        end
        t.cb(0, table.concat(keep, "\n") .. (#keep > 0 and "\n" or ""), "")
    end
    local rank = {}
    for i, b in ipairs(ts.browsers()) do rank[b] = i end
    check("🚨 the rows are in a fixed order — browser, then window, then "
          .. "tab — so ⌘9 means the same tab twice running", (function()
        local prev
        for _, r in ipairs(ts.rows) do
          if prev then
            local ra, rp = rank[r.browser] or 99, rank[prev.browser] or 99
            if ra < rp then return false end
            if ra == rp then
              if r.win < prev.win then return false end
              if r.win == prev.win and r.tab <= prev.tab then return false end
            end
          end
          prev = r
        end
        return #ts.rows == 4
    end)(), (function()
        local p = {}
        for _, r in ipairs(ts.rows) do p[#p+1] = r.browser.."/"..r.win.."/"..r.tab end
        return table.concat(p, " ")
    end)())
end

-- =====================================================================
out("\n=== 7. nothing found, and nothing answering, are different ===\n")
-- =====================================================================
reset()
ts.show()
answerAll("")
check("no tabs says so, and mentions the two reasons", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("No open tabs", 1, true) and a:find("Automation", 1, true) then
            return true
        end
    end
    return false
end)(), ALERTS[1])

reset()
ts.show()
local scanTasks = {}
for i, t in ipairs(TASKS) do scanTasks[i] = t end
check("a timeout timer was armed FOR EACH browser", #TIMERS >= #RUNNING, #TIMERS)
for _, tm in ipairs(TIMERS) do if tm.fn then tm.fn() end end
check("the timeout terminates the child rather than leaking it",
      (function()
        for _, t in ipairs(scanTasks) do
          if t.terminated ~= true then return false end
        end
        return #scanTasks > 0
      end)())
-- 🗂 6.439.0 — AND IT NAMES THE BROWSER INSTEAD OF BLAMING A
-- PERMISSION. This asserted the words "Automation prompt", which is the
-- sentence that sent LL to a System Settings pane where every grant was
-- already switched on — `osascript exited 15` is SIGTERM, from this
-- very timeout. A message that names the wrong cause is worse than
-- none (6.430.0). The RULE is that the failure says WHICH browser and
-- WHAT happened to it.
check("🗂 …and the message NAMES the browser that did not answer, "
      .. "rather than blaming a grant that is already given", (function()
    for _, a in ipairs(ALERTS) do
        if a:find("Google Chrome", 1, true) and a:find("did not answer", 1, true) then
            return true
        end
    end
    return false
end)(), ALERTS[1])
check("🗂 …and the report keeps a row per browser, so a scan that "
      .. "half-worked is readable rather than a single verdict",
      (function()
        local legs = ts.lastLegs or {}
        local n = 0
        for _, g in pairs(legs) do
          if g.state ~= "timeout" then return false end
          n = n + 1
        end
        return n == #RUNNING
      end)(), ts.lastWhy)

-- =====================================================================
out("\n=== 8. the report tells the truth ===\n")
-- =====================================================================
reset()
ts.show()
answerAll()
local rep = _G.tabReport(true)
check("the report names the module", rep:find("TAB SEARCH", 1, true) ~= nil)
check("…counts tabs per browser", rep:find("Google Chrome", 1, true) ~= nil, rep)
check("…and lists every browser it asked", rep:find("Microsoft Edge", 1, true) ~= nil)

-- 🔎 DRIVEN FOR REAL, not by emptying a count table. Setting
-- lastCounts to {} leaves every other record of the last scan in place,
-- so the report would be describing a world that cannot exist — and a
-- fixture that cannot happen proves nothing about the Mac that can
-- (6.290.0). A Mac with no browser open is one line.
-- 🔬 AND THE FIXTURE IS A MAC WITH APPS BUT NO BROWSER, never an
-- EMPTY app list. A real `runningApplications()` can never come back
-- empty — Hammerspoon is itself one of them — so an empty answer means
-- macOS refused, which the module correctly treats as "ask every
-- browser blind" rather than "nothing is running". A stub that returns
-- the impossible answer tests a branch no Mac can reach (6.290.0), and
-- it is how this check first went red over correct code.
local wasRunning = RUNNING
RUNNING = { "Finder", "Hammerspoon" }
reset()
ts.show()
rep = _G.tabReport(true)
RUNNING = wasRunning
-- 🗂 6.439.0 — "NOTHING RUNNING" IS NOT "NOTHING ANSWERED", and the
-- report used to print one sentence for both, blaming Automation. That
-- sentence is what sent LL to a settings pane where every grant was
-- already on, so the check now asserts the DISTINCTION rather than the
-- word (6.248.0 — a literal standing in for a rule).
check("with nothing running the report says THAT, not 'nothing answered'",
      rep:find("no browser was running", 1, true) ~= nil, rep)
check("…and it does NOT blame a permission for an empty Mac",
      rep:find("Automation", 1, true) == nil, rep)

-- =====================================================================
-- =====================================================================
out("\n=== 👁 6.157.0 — the preview pane beside the tab list ===\n")
-- LL: "I need a preview window for the relevant pickers … Can we
-- correct all the picker tools that don't have one?"
local paneRows = ts.choices({ { title = string.rep("a very long tab title ", 6),
                                url = "https://example.com/a/very/long/path/that/the/row/cuts",
                                browser = "Google Chrome", win = 2, tab = 5 } })
check("a tab row carries the WHOLE title and url for the pane, headed by browser, "
      .. "window and tab",
      paneRows[1].rawText == string.rep("a very long tab title ", 6)
                             .. "\nhttps://example.com/a/very/long/path/that/the/row/cuts"
      and paneRows[1].head == "🗂 Google Chrome  ·  window 2, tab 5", paneRows[1].head)
check("...the row itself still shows the cut versions", #paneRows[1].text < 200
      and paneRows[1].text:find("…", 1, true) ~= nil)
check("the picker asks for the pane after it shows", (function()
    for _, c in ipairs(CALLS) do
        if c.n == "preview.open" and c.args[1] == CHOOSERS[#CHOOSERS] then return true end
    end
    return false
end)())
check("...and suspends it when it hides", (function()
    local c = CHOOSERS[#CHOOSERS]
    if not (c and c.hideCb) then return false end
    c.hideCb()
    return CALLS[#CALLS].n == "preview.suspend"
end)())

out(("\n── test_tab_search: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
