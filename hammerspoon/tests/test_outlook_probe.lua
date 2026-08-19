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
-- None of those show up as an error. They show up as a report that is
-- quietly wrong, which for a DIAGNOSTIC is the worst failure available:
-- the whole point of the file is that its output is trusted enough to
-- design against. That is what is checked here.
--
-- HOW. hs.task is stubbed so nothing runs, and answers are delivered by
-- draining a fake queue — which is also how the stub proves the probes
-- run ONE AT A TIME (it asserts if two are ever live at once) and that
-- hs.execute is never reached. Six scenarios, including the exact shape
-- of the work Mac: an Outlook that answers every call and answers zero.
--
-- 🚨 The stub deliberately does NOT provide waitUntilExit or
-- standardOutput. Reaching for that pair with a nil callback is the bug
-- that made the version line read "?" on every Mac it ever ran on, so
-- touching them here is an error rather than a quiet wrong answer.
local DIR = arg[1] or "."
local pending, timers = {}, {}
local started = {}          -- order in which osascript was launched
local liveTasks = 0         -- how many are running at once

local ANSWERS = {}          -- set per scenario: src-substring -> {code, out}

local function answerFor(src)
    for needle, a in pairs(ANSWERS) do
        if src:find(needle, 1, true) then return a[1], a[2] end
    end
    return 1, "", "execution error: not authorised (-1743)"
end

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
VERSION_OUT = { 0, "16.112.1\n" }   -- what /usr/bin/defaults answers

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
    -- Deliberately absent: waitUntilExit / standardOutput. The probe must
    -- not reach for them — that pair with a nil callback is exactly the
    -- bug that made every run report "version: ?", so a call here should
    -- blow up rather than quietly return the right answer.
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
hs.application = { get = function() return {
    bundleID = function() return "com.microsoft.Outlook" end,
    path = function() return "/Applications/Microsoft Outlook.app" end,
} end }
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
local function check(name, cond)
    checks = checks + 1
    if not cond then fails = fails + 1; io.write("   ❌ ", name, "\n")
    else io.write("   ✅ ", name, "\n") end
end

local function reset()
    pending, timers, started, printed, liveTasks = {}, {}, {}, {}, 0
end

local function report()
    -- the last print is the assembled report
    return printed[#printed] or ""
end

-- ── scenario 1: everything answers ────────────────────────────────────
io.write("\n── 1. every probe answers ──\n")
reset()
ANSWERS = { [""] = { 0, "yes" } }
dofile(DIR .. "/tools/outlook-probe.lua")
local returned = _G.outlookProbe()
check("returns immediately, before any answer", returned == nil)
-- printed[1] is the "probe loaded" line from the dofile above; the banner
-- we care about is whatever was printed LAST before any answer arrived.
check("printed a running banner up front", report():find("probe running", 1, true) ~= nil)
check("no report yet", report():find("── NEXT ──", 1, true) == nil)
drain()
local r = report()
check("report printed after the queue drained", r:find("── NEXT ──", 1, true) ~= nil)
check("16 osascript probes were launched", #started == 16)
check("the version came from the plist, not '?'", r:find("version: 16.112.1", 1, true) ~= nil)

local function at(needle) return (r:find(needle, 1, true)) end
check("section 1 before section 2", at("1. WHICH OUTLOOK") < at("2. APPLESCRIPT"))
check("section 2 before section 3", at("2. APPLESCRIPT") < at("3. ACCESSIBILITY"))
check("section 3 before section 2b", at("3. ACCESSIBILITY") < at("2b. THE CALENDAR"))
check("2b before NEXT", at("2b. THE CALENDAR") < at("── NEXT ──"))
check("mail verdict is the alive one", r:find("legacy%-style scripting is alive"))
check("calendar verdict is route A", r:find("VERDICT: ROUTE A"))
check("hs.execute was never used", true)  -- it errors if called

-- ── scenario 2: Outlook refuses, Calendar answers ─────────────────────
io.write("\n── 2. Outlook says no, Calendar.app says yes ──\n")
reset()
ANSWERS = { ["Calendar"] = { 0, "Work ; Home" } }
_G.outlookProbe()
drain()
r = report()
check("route B verdict", r:find("VERDICT: ROUTE B") ~= nil)
check("mail verdict is closed", r:find("scripting is closed on this build") ~= nil)
check("the refusal text survives into the report", r:find("not authorised") ~= nil)

-- ── scenario 3: Outlook is not running — calendar STILL runs ──────────
io.write("\n── 3. Outlook absent, calendar section still runs ──\n")
reset()
ANSWERS = { ["Calendar"] = { 0, "Work ; Home" } }
hs.application.get = function() return nil end
_G.outlookProbe()
drain()
r = report()
check("says Outlook is not running", r:find("Outlook is not running") ~= nil)
check("calendar section still present", r:find("2b. THE CALENDAR") ~= nil)
check("still reached the verdict", r:find("VERDICT: ROUTE B") ~= nil)
check("no AppleScript mail section", r:find("2. APPLESCRIPT") == nil)
hs.application.get = function() return {
    bundleID = function() return "com.microsoft.Outlook" end,
    path = function() return "/Applications/Microsoft Outlook.app" end,
} end

-- ── scenario 4: the watchdog ──────────────────────────────────────────
io.write("\n── 4. a probe that never answers ──\n")
reset()
ANSWERS = { [""] = { 0, "yes" } }
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
check("timeout is reported as a finding", r:find("no answer in 45s") ~= nil)
check("timeout names the dialog as the likely cause", r:find("permission dialog") ~= nil)

-- A late answer from the killed task must not re-enter the queue. Printing
-- is NOT enough to detect this: a second pass through the chain re-queues
-- the calendar probes and only prints once those are answered, so the tell
-- is the queue growing, not the console.
local before, beforePending = #printed, #pending
stuck.cb(0, "late", "")
check("a late answer after the watchdog is ignored",
      #printed == before and #pending == beforePending)

-- ── scenario 5: the hollow dictionary — LL's actual work Mac ──────────
-- Outlook answers, and answers zero, while the message list plainly has
-- rows. This is the shape the first real run produced and the one the
-- report has to name rather than call "partial access".
io.write("\n── 5. answers, but answers nothing (New Outlook) ──\n")
reset()
ANSWERS = {
    ["return name of it"]              = { 0, "Microsoft Outlook" },
    ["count of messages of inbox"]     = { 0, "0" },
    ["count of (get current messages)"] = { 0, "0" },
    ["Calendar"]                       = { 0, "Work ; Home" },
}
_G.outlookProbe()
drain()
r = report()
check("the hollow signature is named", r:find("HOLLOW DICTIONARY") ~= nil)
check("it prints the inbox count it saw", r:find("inbox message count ....... 0", 1, true) ~= nil)
check("it prints the selected count it saw", r:find("selected message count .... 0", 1, true) ~= nil)
check("verdict is EMPTY, not partial",
      r:find("dictionary is present but EMPTY") ~= nil)
check("it does NOT claim scripting is alive",
      r:find("legacy%-style scripting is alive") == nil)
check("it says a refusal would have errored instead",
      r:find("a refusal errors, it does not say 0", 1, true) ~= nil)
check("it still names the no-message-selected confound",
      r:find("if NO message was", 1, true) ~= nil)
check("calendar section still ran", r:find("VERDICT: ROUTE B") ~= nil)

-- ── scenario 6: the plist read fails ──────────────────────────────────
io.write("\n── 6. the version cannot be read ──\n")
reset()
VERSION_OUT = { 1, "" }
ANSWERS = { [""] = { 0, "yes" } }
_G.outlookProbe()
drain()
r = report()
check("says so plainly rather than a bare '?'",
      r:find("could not read the plist", 1, true) ~= nil)
check("the rest of the report still ran", r:find("── NEXT ──", 1, true) ~= nil)
VERSION_OUT = { 0, "16.112.1\n" }

io.write(string.format("\n%d passed, %d failed\n", checks - fails, fails))
os.exit(fails == 0 and 0 or 1)
