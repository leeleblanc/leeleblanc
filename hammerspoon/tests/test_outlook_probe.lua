-- =====================================================================
-- TEST: tools/outlook-probe.lua
-- =====================================================================
-- WHY A DIAGNOSTIC GETS A SUITE. Until 6.116.0 this file was a straight
-- line: ask, wait, print. Then the first real run on the work Mac froze
-- Hammerspoon for four minutes behind a permission dialog and macOS
-- disabled two event taps on the way out, so it became a callback chain
-- with a watchdog — and a callback chain can fail in ways a straight line
-- cannot. It can print its sections out of order, drop one entirely,
-- re-enter its own queue on a late answer, or never print at all.
--
-- 🚨 AND THEN IT GOT THE ANSWER WRONG, which is the real reason this
-- suite exists. On the home Mac the calendar section counted three
-- route-A replies and declared "ROUTE A — build on this", when what
-- those three replies actually said was: one calendar, zero events,
-- nothing today. The mail section one screen above had just been taught
-- to catch that exact shape. The calendar section had not, because it
-- was counting REPLIES instead of reading VALUES.
--
-- A wrong verdict from a diagnostic is worse than a crash from one. A
-- crash gets fixed; a confident wrong answer gets BUILT ON. Section 7
-- below is the home Mac's exact numbers, and it fails on the old rule.
--
-- HOW. hs.task is stubbed so nothing runs, and answers are delivered by
-- draining a fake queue — which is also how the stub proves the probes
-- run ONE AT A TIME (it asserts if two are ever live at once) and that
-- hs.execute is never reached.
--
-- 🚨 The stub deliberately does NOT provide waitUntilExit or
-- standardOutput. Reaching for that pair with a nil callback is the bug
-- that made the version line read "?" on every Mac it ever ran on, so
-- touching them here is an error rather than a quiet wrong answer.
local DIR = arg[1] or "."
local pending, timers = {}, {}
local started = {}          -- order in which osascript was launched
local liveTasks = 0         -- how many are running at once

-- Ordered, because a catch-all has to come LAST. A keyed table was tried
-- first and pairs() order made whichever answer Lua felt like winning.
local ANSWERS = {}          -- { { needle | "*", exitCode, stdout }, ... }

local function answerFor(src)
    for _, a in ipairs(ANSWERS) do
        if a[1] == "*" or src:find(a[1], 1, true) then return a[2], a[3] end
    end
    return 1, "", "execution error: not authorised (-1743)"
end

-- Needles that pick out one probe each. "count of calendars" alone is
-- ambiguous — Outlook and Calendar.app are both asked it — so the app
-- name is part of the needle.
local A_CALS   = 'Outlook" to return count of calendars'
local A_EVENTS = "count of calendar events of calendar 1\n"
local A_TODAY  = "(no events today)"
local B_REACH  = 'Calendar" to return count of calendars'
local B_NAMES  = 'set out to out & n & " ; "'
local B_TODAY  = "(no events today in any calendar)"
local B_WINDOW = 'set out to out & n & "=" & k & " ; "'
local MAIL_ONE = "return name of it"
local MAIL_IN  = "count of messages of inbox"
local MAIL_SEL = "count of (get current messages)"

VERSION_OUT = { 0, "16.112.1\n" }   -- what /usr/bin/defaults answers

hs = {}
hs.configdir = DIR
hs.timer = {
    secondsSinceEpoch = function() return os.time() + 0.0 end,
    doAfter = function(secs, fn)
        local t = { secs = secs, fn = fn, stopped = false }
        t.stop = function(self) (self or t).stopped = true end
        timers[#timers + 1] = t
        return t
    end,
}
hs.task = {}
hs.task.new = function(bin, cb, args)
    local t = {}
    t.args = args
    t.cb = cb
    t.osa = (bin == "/usr/bin/osascript")
    t.started = false
    t.terminated = false
    t.start = function()
        t.started = true
        if t.osa then
            liveTasks = liveTasks + 1
            assert(liveTasks == 1, "PARALLEL: two osascript tasks live at once")
            started[#started + 1] = args[2]
        end
        pending[#pending + 1] = t
        return true
    end
    t.terminate = function() t.terminated = true end
    return t
end

local printed = {}
_G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(parts, " ")
end

hs.alert = { show = function() end }
hs.pasteboard = { setContents = function() return true end }
hs.accessibilityState = function() return false end
hs.axuielement = { applicationElement = function() return nil end }
local function outlookApp()
    return {
        bundleID = function() return "com.microsoft.Outlook" end,
        path = function() return "/Applications/Microsoft Outlook.app" end,
    }
end
hs.application = { get = outlookApp }
hs.execute = function() error("hs.execute must not be called — the probe must not block") end

-- drain: answer every queued task, one at a time, like a real run loop
local function drain()
    local guard = 0
    while #pending > 0 do
        guard = guard + 1
        assert(guard < 200, "runaway queue")
        local t = table.remove(pending, 1)
        if t.osa then
            liveTasks = liveTasks - 1
            local code, out, err = answerFor(t.args[2])
            t.cb(code, out, err)
        else
            t.cb(VERSION_OUT[1], VERSION_OUT[2], "")
        end
    end
end

local checks, fails = 0, 0
local function check(name, cond, detail)
    checks = checks + 1
    if not cond then
        fails = fails + 1
        io.write("   ❌ ", name, detail and ("  [" .. tostring(detail) .. "]") or "", "\n")
    else
        io.write("   ✅ ", name, "\n")
    end
end

local function reset()
    pending, timers, started, printed, liveTasks = {}, {}, {}, {}, 0
end

local function report() return printed[#printed] or "" end

dofile(DIR .. "/tools/outlook-probe.lua")

-- ── 1: everything answers, and Outlook really holds events ────────────
io.write("\n── 1. every probe answers, Outlook has a real calendar ──\n")
reset()
ANSWERS = {
    { A_CALS,   0, "2" },
    { A_EVENTS, 0, "137" },
    { A_TODAY,  0, "Standup @ Wednesday, 19 August 2026 09:00" },
    { B_REACH,  0, "7" },
    { B_NAMES,  0, "Work ; Home ; " },
    { B_TODAY,  0, "(no events today in any calendar)" },
    { B_WINDOW, 0, "Work=0 ; Home=0 ; " },
    { "*",      0, "yes" },
}
local returned = _G.outlookProbe()
check("returns immediately, before any answer", returned == nil)
check("printed a running banner up front", report():find("probe running", 1, true) ~= nil)
check("no report yet", report():find("── NEXT ──", 1, true) == nil)
drain()
local r = report()
check("report printed after the queue drained", r:find("── NEXT ──", 1, true) ~= nil)
check("17 osascript probes were launched", #started == 17, #started)
check("the version came from the plist, not '?'", r:find("version: 16.112.1", 1, true) ~= nil)

local function at(needle) return (r:find(needle, 1, true)) end
check("section 1 before section 2", at("1. WHICH OUTLOOK") < at("2. APPLESCRIPT"))
check("section 2 before section 3", at("2. APPLESCRIPT") < at("3. ACCESSIBILITY"))
check("section 3 before section 2b", at("3. ACCESSIBILITY") < at("2b. THE CALENDAR"))
check("2b before NEXT", at("2b. THE CALENDAR") < at("── NEXT ──"))
check("calendar verdict is route A when Outlook HOLDS events",
      r:find("VERDICT: ROUTE A") ~= nil)
check("...and it says how many it holds", r:find("holds events %(137%)") ~= nil)
check("hs.execute was never used", true)  -- it errors if called

-- ── 2: Outlook refuses, Calendar.app has real events ──────────────────
io.write("\n── 2. Outlook says no, Calendar.app has meetings ──\n")
reset()
ANSWERS = {
    { B_REACH,  0, "7" },
    { B_NAMES,  0, "Work ; Home ; " },
    { B_TODAY,  0, "Standup @ 09:00 ; " },
    { B_WINDOW, 0, "Work=12 ; Home=3 ; Birthdays=0 ; " },
}
_G.outlookProbe()
drain()
r = report()
check("route B verdict", r:find("VERDICT: ROUTE B") ~= nil)
check("mail verdict is closed", r:find("scripting is closed on this build") ~= nil)
check("the refusal text survives into the report", r:find("not authorised") ~= nil)
check("it totals the fortnight", r:find("15 event%(s%) total") ~= nil)
check("...and names only the calendars that carry them",
      r:find("Work %(12%), Home %(3%)", 1, true) ~= nil
      or r:find("Work (12), Home (3)", 1, true) ~= nil)
check("route B is told to cache rather than read on the keypress",
      r:find("never read the calendar on the keypress", 1, true) ~= nil)

-- ── 3: Outlook is not running — calendar STILL runs ───────────────────
io.write("\n── 3. Outlook absent, calendar section still runs ──\n")
reset()
ANSWERS = {
    { B_REACH,  0, "7" },
    { B_NAMES,  0, "Work ; Home ; " },
    { B_WINDOW, 0, "Work=12 ; " },
}
hs.application.get = function() return nil end
_G.outlookProbe()
drain()
r = report()
check("says Outlook is not running", r:find("Outlook is not running") ~= nil)
check("calendar section still present", r:find("2b. THE CALENDAR") ~= nil)
check("still reached the verdict", r:find("VERDICT: ROUTE B") ~= nil)
check("no AppleScript mail section", r:find("2. APPLESCRIPT") == nil)
hs.application.get = outlookApp

-- ── 4: the watchdog ───────────────────────────────────────────────────
io.write("\n── 4. a probe that never answers ──\n")
reset()
ANSWERS = { { "*", 0, "yes" } }
_G.outlookProbe()
-- The first queued task is the plist read, which has no watchdog. Let it
-- answer so the chain reaches an actual osascript probe, then strand that.
while pending[1] and not pending[1].osa do
    local t = table.remove(pending, 1)
    t.cb(VERSION_OUT[1], VERSION_OUT[2], "")
end
local stuck = table.remove(pending, 1)
assert(stuck and stuck.osa, "expected an osascript probe to strand")
liveTasks = liveTasks - 1
local fired = false
for _, t in ipairs(timers) do
    if not t.stopped and not fired then t.fn(); fired = true end
end
check("watchdog fired", fired)
check("watchdog terminated the stuck task", stuck.terminated == true)
drain()
r = report()
check("report still printed", r:find("── NEXT ──", 1, true) ~= nil)
check("timeout is reported as a finding", r:find("no answer in 75s") ~= nil)
check("timeout names the dialog as the likely cause", r:find("permission dialog") ~= nil)

-- A late answer from the killed task must not re-enter the queue. Printing
-- is NOT enough to detect this: a second pass through the chain re-queues
-- the calendar probes and only prints once those are answered, so the tell
-- is the queue growing, not the console.
local before, beforePending = #printed, #pending
stuck.cb(0, "late", "")
check("a late answer after the watchdog is ignored",
      #printed == before and #pending == beforePending)

-- 🚨 The watchdog must outlast the slowest script or it reports a timeout
-- that is really just this number being too small. Read from the source
-- so raising one without the other fails here.
do
    local f = io.open(DIR .. "/tools/outlook-probe.lua", "r")
    local src = f and f:read("*a") or ""
    if f then f:close() end
    local hard = tonumber(src:match("op%.hardTimeout%s*=%s*(%d+)"))
    local longest = 0
    for n in src:gmatch("with timeout of (%d+) seconds") do
        longest = math.max(longest, tonumber(n))
    end
    check("the watchdog outlasts the slowest AppleScript timeout",
          hard and longest > 0 and hard > longest,
          "hardTimeout=" .. tostring(hard) .. " longest=" .. tostring(longest))
end

-- ── 5: the hollow MAIL dictionary — LL's Macs ─────────────────────────
io.write("\n── 5. mail answers, but answers nothing (New Outlook) ──\n")
reset()
ANSWERS = {
    { MAIL_ONE, 0, "Microsoft Outlook" },
    { MAIL_IN,  0, "0" },
    { MAIL_SEL, 0, "0" },
    { B_REACH,  0, "7" },
    { B_NAMES,  0, "Work ; Home ; " },
    { B_WINDOW, 0, "Work=12 ; " },
}
_G.outlookProbe()
drain()
r = report()
check("the hollow signature is named", r:find("HOLLOW DICTIONARY") ~= nil)
check("it prints the inbox count it saw", r:find("inbox message count ....... 0", 1, true) ~= nil)
check("it prints the selected count it saw", r:find("selected message count .... 0", 1, true) ~= nil)
check("verdict is EMPTY, not partial", r:find("dictionary is present but EMPTY") ~= nil)
check("it does NOT claim scripting is alive",
      r:find("legacy%-style scripting is alive") == nil)
check("it says a refusal would have errored instead",
      r:find("a refusal errors, it does not say 0", 1, true) ~= nil)
check("it still names the no-message-selected confound",
      r:find("if NO message was", 1, true) ~= nil)

-- ── 6: the plist read fails ───────────────────────────────────────────
io.write("\n── 6. the version cannot be read ──\n")
reset()
VERSION_OUT = { 1, "" }
ANSWERS = { { "*", 0, "yes" } }
_G.outlookProbe()
drain()
r = report()
check("says so plainly rather than a bare '?'",
      r:find("could not read the plist", 1, true) ~= nil)
check("the rest of the report still ran", r:find("── NEXT ──", 1, true) ~= nil)
VERSION_OUT = { 0, "16.112.1\n" }

-- ── 7: THE HOME MAC, VERBATIM ─────────────────────────────────────────
-- 🚨 THE REGRESSION GUARD. These are the exact answers the home Mac gave
-- on 2026-08-19: Outlook says it has one calendar, that calendar holds
-- zero events, and nothing is on today. Calendar.app is reachable and
-- lists seven real calendars — and holds nothing either.
--
-- The old rule counted three route-A replies and printed "ROUTE A —
-- build on this; it is the source of truth". Every number in front of it
-- said the opposite. This section fails on that rule.
io.write("\n── 7. the home Mac's exact numbers (the wrong-verdict bug) ──\n")
reset()
ANSWERS = {
    { MAIL_ONE, 0, "Microsoft Outlook" },
    { MAIL_IN,  0, "0" },
    { MAIL_SEL, 0, "0" },
    { A_CALS,   0, "1" },
    { A_EVENTS, 0, "0" },
    { A_TODAY,  0, "(no events today)" },
    { B_REACH,  0, "7" },
    { B_NAMES,  0, "Work ; Home ; Safelite replacement appointment ; "
                .. "Scheduled Reminders ; Birthdays ; US Holidays ; Siri Suggestions ; " },
    { B_TODAY,  0, "(no events today in any calendar)" },
    { B_WINDOW, 0, "Work=0 ; Home=0 ; Safelite replacement appointment=0 ; "
                .. "Scheduled Reminders=0 ; Birthdays=0 ; US Holidays=0 ; "
                .. "Siri Suggestions=0 ; " },
}
_G.outlookProbe()
drain()
r = report()
check("🚨 does NOT declare ROUTE A on a calendar holding zero events",
      r:find("VERDICT: ROUTE A") == nil)
check("🚨 ...nor ROUTE B, which has no events either",
      r:find("VERDICT: ROUTE B") == nil)
check("names Outlook's calendar as hollow too",
      r:find("calendar%(s%) holding 0") ~= nil)
check("reports the fortnight total as zero",
      r:find("0 event%(s%) total") ~= nil)
check("verdict is 'works but no data', not a route",
      r:find("Calendar%.app WORKS but has no events") ~= nil)
check("...and it points at Internet Accounts as the likely cause",
      r:find("Internet Accounts", 1, true) ~= nil)
check("it separates the permission from the data",
      r:find("the DATA is missing", 1, true) ~= nil)

io.write(string.format("\n%d passed, %d failed\n", checks - fails, fails))
os.exit(fails == 0 and 0 or 1)
