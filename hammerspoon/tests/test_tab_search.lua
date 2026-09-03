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
    ts.pending, ts.lastNote = false, nil
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
check("🚨 the script asks System Events for the running process list",
      ts.scanScript:find("name of every process", 1, true) ~= nil)
check("🚨 …and skips anything not in it",
      ts.scanScript:find("runningNames contains bn", 1, true) ~= nil)
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
check("every browser is passed as an argument, not baked into the script",
      TASKS[1] and #TASKS[1].args == 2 + #ts.browsers(),
      TASKS[1] and #TASKS[1].args)

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
check("the first press scans", #TASKS == 1, #TASKS)
-- Guarded: a build that CACHED would not scan at all, and reading
-- TASKS[1] on nil would take the file down before it could report the
-- failures this section exists for.
if TASKS[1] then TASKS[1].cb(0, FIXTURE, "") end
local firstShows = SHOWS
check("…and the panel opened", firstShows >= 1, firstShows)

reset()
ts.show()
check("🚨 the SECOND press scans again — no cache, ever", #TASKS == 1, #TASKS)
NOW = NOW + 1
reset()
ts.show()
check("…and so does the third, one second later", #TASKS == 1, #TASKS)

-- =====================================================================
out("\n=== 6. 🚨 A ROW CARRIES A NUMBER, NOT A TABLE ===\n")
-- =====================================================================
reset()
ts.show()
if TASKS[1] then TASKS[1].cb(0, FIXTURE, "") end
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
check("⏎ on a row jumps to THAT tab", (function()
    TASKS = {}
    c.cb({ idx = 3 })
    local j = TASKS[1]
    return j and j.args[3] == "Google Chrome" and j.args[4] == "2"
end)(), TASKS[1] and table.concat(TASKS[1].args, "|", 3))

-- =====================================================================
out("\n=== 7. nothing found, and nothing answering, are different ===\n")
-- =====================================================================
reset()
ts.show()
if TASKS[1] then TASKS[1].cb(0, "", "") end
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
local scanTask = TASKS[1]
check("a timeout timer was armed", #TIMERS >= 1, #TIMERS)
if TIMERS[#TIMERS] then TIMERS[#TIMERS].fn() end
check("the timeout terminates the child rather than leaking it",
      scanTask ~= nil and scanTask.terminated == true)
check("…and points at the Automation prompt, which is the usual cause",
      (function()
    for _, a in ipairs(ALERTS) do
        if a:find("Automation prompt", 1, true) then return true end
    end
    return false
end)(), ALERTS[1])

-- =====================================================================
out("\n=== 8. the report tells the truth ===\n")
-- =====================================================================
reset()
ts.show()
if TASKS[1] then TASKS[1].cb(0, FIXTURE, "") end
local rep = _G.tabReport()
check("the report names the module", rep:find("TAB SEARCH", 1, true) ~= nil)
check("…counts tabs per browser", rep:find("Google Chrome", 1, true) ~= nil, rep)
check("…and lists every browser it asked", rep:find("Microsoft Edge", 1, true) ~= nil)

ts.lastCounts = {}
rep = _G.tabReport()
check("with nothing answering it says what to check",
      rep:find("Automation", 1, true) ~= nil, rep)

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
