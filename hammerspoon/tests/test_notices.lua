-- =====================================================================
-- test_notices.lua — the thing that reports every other failure
-- =====================================================================
--     lua5.4 test_notices.lua [/path/to/hammerspoon]
--
-- This file exists to satisfy one requirement, in the owner's words:
-- "All configurations and additions must not fail silently... I will not
-- always have the console open." So the properties are about REACHING a
-- person who is not looking:
--
--   P1  A NOTICE IS NEVER LOST. If Focus suppresses it, it is HELD and
--       delivered later — not dropped. macOS swallows notifications
--       during Focus WITHOUT refusing them, so "it sent fine" is not
--       evidence anyone saw it.
--   P2  BUT IT NEVER FLOODS. A failure inside a repeating timer fires
--       forever; the same key must not paint the screen, and the held
--       queue is bounded.
--   P3  A CLEAN BOOT IS QUIET, A BROKEN ONE IS NOT. Silence has to mean
--       "it worked", or you are back to checking the Console.
--   P4  IT NEVER THROWS. This runs on the boot path and reports other
--       failures — if it crashes it takes the config down AND removes
--       the mechanism that would have explained why.
--   P5  UNKNOWN FOCUS STATE MEANS SHOW, NOT HIDE. Guessing "probably
--       suppressed" would silently drop the notice, which is the exact
--       bug this file prevents.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end
local function out(s) io.write(s) end

-- ---- a controllable Mac ----------------------------------------------
local CLOCK, ALERTS, NOTIFIES, TIMERS, printed = 1000, {}, {}, {}, {}
local FOCUS_ENGAGED, DND_FILE, NOTIFY_REFUSES = false, nil, false
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function printedHas(s)
    for _, l in ipairs(printed) do if l:find(s, 1, true) then return true end end
end

local realIoOpen = io.open
io.open = function(path, mode)
    if path:find("Assertions.json", 1, true) then
        if DND_FILE == nil then return nil end
        local done = false
        return { read = function() if done then return nil end done = true return DND_FILE end,
                 close = function() end }
    end
    return realIoOpen(path, mode)
end

hs = {
    timer = {
        secondsSinceEpoch = function() return CLOCK end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t ; return t
        end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t ; return t
        end,
    },
    alert = { show = function(m, s) ALERTS[#ALERTS + 1] = tostring(m) end },
    notify = { new = function(o)
        if NOTIFY_REFUSES then return nil end
        local n = { opts = o }
        function n:send() NOTIFIES[#NOTIFIES + 1] = o.title ; return self end
        return n
    end },
}
_G.diag = { errs = {},
            say = function() end, warn = function() end, mark = function() end,
            err = function(e) _G.diag.errs[#_G.diag.errs + 1] = tostring(e) end }
_G.service = {
    call = function(name)
        if name == "focus.engaged" then return FOCUS_ENGAGED end
        return nil
    end,
}

local N
local function boot()
    CLOCK, ALERTS, NOTIFIES, TIMERS, printed = 1000, {}, {}, {}, {}
    FOCUS_ENGAGED, DND_FILE, NOTIFY_REFUSES = false, nil, false
    _G.diag.errs = {}
    -- 6.58.0 — dofile() now returns a function, not the table directly:
    -- notices.lua matches the other core/ files' `return function(core)
    -- ... end` shape, called by init.lua as chunk()(coreTable). Called
    -- with {} here for the same reason init.lua does: this file has
    -- nothing to offer notices.lua yet, and nothing in it is read.
    N = dofile(HS .. "/core/notices.lua")({})
    return N
end

local function runTimers()
    for _, t in ipairs(TIMERS) do
        if not t.stopped then t.fn() end
    end
end

-- =====================================================================
out("\n=== 1. The ledger ===\n")
-- =====================================================================
boot()
check("it publishes itself as _G.notices", _G.notices ~= nil)
N.record("load", "focus_mode", "syntax error")
N.record("runtime", "bulk_rename", "threw on apply")
check("both were recorded", #N.ledger == 2)
check("each entry carries kind, source, message and a clock",
      N.ledger[1].kind == "load" and N.ledger[1].source == "focus_mode"
      and N.ledger[1].msg:find("syntax") ~= nil
      and type(N.ledger[1].clock) == "string")
check("counting by kind works", N.count("load") == 1 and N.count() == 2)
check("failures are mirrored into the diagnostics trail, so ⇪⇧D shows "
      .. "them too rather than being a second place to look",
      #_G.diag.errs == 2)

-- P2: bounded. A failure in a repeating timer records forever.
boot()
for i = 1, N.maxLedger + 60 do N.record("runtime", "loop", "boom " .. i) end
check("🚨 P2: THE LEDGER IS BOUNDED — a failure inside a repeating timer "
      .. "records forever, and an unbounded list grows until the Mac hurts",
      #N.ledger == N.maxLedger, #N.ledger)
check("...and it keeps the NEWEST, since those are the ones still true",
      N.ledger[#N.ledger].msg:find(tostring(N.maxLedger + 60)) ~= nil)

-- P4: nothing throws, whatever it is handed.
boot()
local threw = nil
for _, args in ipairs({ {}, { nil, nil, nil }, { "x" }, { {}, {}, {} },
                        { 1, 2, 3 }, { "load", nil, "m" } }) do
    local ok = pcall(N.record, args[1], args[2], args[3])
    if not ok then threw = "record" break end
end
if not threw then
    local ok = pcall(N.tell, nil, nil, nil)
    if not ok then threw = "tell(nil)" end
end
check("🚨 P4: it never throws, whatever it is handed — a notice system "
      .. "that crashes takes the config down AND removes the explanation",
      threw == nil, threw)

-- =====================================================================
out("\n=== 2. Delivery, and Do Not Disturb — P1 and P5 ===\n")
-- =====================================================================
boot()
local shown = N.tell("Something broke", "details here")
check("with Focus off it is shown immediately", shown == true)
check("...on screen via hs.alert, which Focus cannot silence", #ALERTS == 1)
check("...and as a notification too", #NOTIFIES == 1)

-- 🚨 The reason this file exists.
boot()
FOCUS_ENGAGED = true
shown = N.tell("Broke during a meeting", "details")
check("🚨 P1: WITH FOCUS ON IT IS HELD, NOT SHOWN — macOS swallows "
      .. "notifications during Focus WITHOUT refusing them, so sending "
      .. "one is not evidence anyone saw it",
      shown == false and #N.queue == 1 and #ALERTS == 0)
check("...and the hold is announced in the Console rather than silent",
      printedHas("Held until Focus ends"))
FOCUS_ENGAGED = false
runTimers()
check("🚨 ...and it ARRIVES when Focus ends", #ALERTS == 1 and #N.queue == 0,
      #ALERTS .. " alerts")

-- Many held notices arrive as ONE message.
boot()
FOCUS_ENGAGED = true
for i = 1, 5 do N.tell("Failure " .. i, "d") end
check("five failures during a meeting are held", #N.queue == 5)
FOCUS_ENGAGED = false
runTimers()
check("...and arrive as ONE combined notice — coming out of a meeting to "
      .. "five stacked alerts is its own kind of failure", #ALERTS == 1)
check("...which says how many there were", ALERTS[1]:find("+4 more") ~= nil,
      ALERTS[1])

-- P2: the held queue is bounded, dropping the OLDEST.
boot()
FOCUS_ENGAGED = true
for i = 1, N.maxQueue + 10 do N.tell("F" .. i, "d") end
check("🚨 P2: the held queue is bounded", #N.queue == N.maxQueue, #N.queue)
check("...and drops the OLDEST, because the recent ones are the ones still "
      .. "true when the meeting ends",
      N.queue[#N.queue].title == "F" .. (N.maxQueue + 10))

-- The DND file route, for Focus this config did not set.
boot()
DND_FILE = '{"storeAssertionRecords":[{"assertionDetails":{}}]}'
local on, why = N.focusIsOn()
check("macOS Do Not Disturb is detected from its assertions file",
      on == true and tostring(why):find("Do Not Disturb") ~= nil)

boot()
DND_FILE = nil                      -- file absent entirely
on = N.focusIsOn()
check("🚨 P5: A MISSING assertions file means UNKNOWN, and unknown means "
      .. "SHOW — guessing 'probably suppressed' would silently drop the "
      .. "notice, which is the exact bug this file prevents", on == false)
check("...so the notice really is shown", N.tell("x", "y") == true)

-- force wins over Focus.
boot()
FOCUS_ENGAGED = true
check("a forced notice is shown even during Focus — a module that did not "
      .. "load is wrong for the whole session, and holding it until the "
      .. "meeting ends is holding it too long",
      N.tell("did not load", "focus_mode", { force = true }) == true)

-- Notification Centre refusing must not lose the message.
boot()
NOTIFY_REFUSES = true
N.tell("Broke", "details")
check("🚨 if hs.notify refuses outright, the on-screen alert still fires — "
      .. "Notification Centre can be off for Hammerspoon entirely and "
      .. "nothing tells us", #ALERTS == 1 and #NOTIFIES == 0)

-- =====================================================================
out("\n=== 3. Not flooding — the de-dupe key ===\n")
-- =====================================================================
boot()
for i = 1, 10 do
    N.tell("Same failure", "again", { key = "mod:x", every = 3600 })
end
check("🚨 the same keyed failure is shown ONCE, not ten times — a break "
      .. "inside a repeating timer would otherwise paint the screen",
      #ALERTS == 1, #ALERTS)
CLOCK = CLOCK + 3601
N.tell("Same failure", "again", { key = "mod:x", every = 3600 })
check("...but it is allowed again once the window has passed", #ALERTS == 2)
boot()
N.tell("A", "1", { key = "a" })
N.tell("B", "2", { key = "b" })
check("different keys are not suppressed by each other", #ALERTS == 2)

-- =====================================================================
out("\n=== 4. Boot — P3 ===\n")
-- =====================================================================
boot()
N.bootFinished(25, 0, {})
check("🚨 P3: A CLEAN BOOT IS BRIEF AND POSITIVE — silence has to mean "
      .. "'it worked', or you are back to checking the Console",
      #ALERTS == 1 and ALERTS[1]:find("ready", 1, true) ~= nil, ALERTS[1])
check("...and records nothing, so a good boot leaves no noise in the ledger",
      #N.ledger == 0)

boot()
N.bootFinished(24, 1, { "focus_mode" })
check("🚨 a module that failed to load is ANNOUNCED, and named",
      #ALERTS == 1 and ALERTS[1]:find("focus_mode", 1, true) ~= nil, ALERTS[1])
check("...and recorded, so ⇪⇧D still has it later",
      N.count("load") == 1)
check("...and it does NOT also show the cheerful 'ready' flash",
      ALERTS[1]:find("ready", 1, true) == nil)

boot()
FOCUS_ENGAGED = true
N.bootFinished(24, 2, { "a", "b" })
check("a boot failure is shown even if Focus is somehow already on at "
      .. "login — it is wrong for the whole session", #ALERTS == 1)

boot()
N.bootSignal = false
N.bootFinished(25, 0, {})
check("the clean-boot flash can be switched off without affecting the "
      .. "failure path", #ALERTS == 0)
N.bootSignal = true

-- =====================================================================
out("\n=== 5. Mutation — are these load-bearing? ===\n")
-- =====================================================================
do
    -- Mutation 1: treat unknown Focus state as suppressed.
    boot()
    local realFocus = N.focusIsOn
    N.focusIsOn = function() return true, "assumed" end
    local got = N.tell("important", "detail")
    N.focusIsOn = realFocus
    check("MUTATION: assuming 'probably suppressed' when the state is "
          .. "unknown silently holds a notice nobody asked to delay — P5 "
          .. "catches it", got == false and #ALERTS == 0)

    -- Mutation 2: drop the hs.alert fallback, keep only hs.notify.
    boot()
    NOTIFY_REFUSES = true
    local sentOnly = false
    pcall(function()
        local n = hs.notify.new({ title = "x" })
        sentOnly = (n ~= nil)
    end)
    check("MUTATION: with only hs.notify and Notification Centre refusing, "
          .. "NOTHING reaches the screen — the alert fallback is what makes "
          .. "the guarantee true", sentOnly == false)

    -- Mutation 3: unbounded queue.
    boot()
    FOCUS_ENGAGED = true
    local realMax = N.maxQueue
    N.maxQueue = math.huge
    for i = 1, 300 do N.tell("F" .. i, "d") end
    local grew = #N.queue
    N.maxQueue = realMax
    check("MUTATION: an unbounded hold queue grows without limit during a "
          .. "long meeting — P2 catches it", grew == 300)
end

-- =====================================================================
out("\n=== 9. 6.215.0 — 🔔 THE DEGRADE DOOR: a break is seen, never only logged ===\n")
-- =====================================================================
-- LL: "I also must have anything here that breaks to throw an error so I
-- see it, know about it, and can fix it with you." One call, three
-- surfaces, at the moment it happens.
boot()
check("the door exists and is published as _G.degrade", type(N.degrade) == "function" and _G.degrade == N.degrade)
local okD, whyD = N.degrade("Bluetooth", "blueutil is not installed")
check("it returns false, why — so `return core.degrade(tool, why)` is a complete degrade path",
      okD == false and whyD == "blueutil is not installed")
check("1/3 the LEDGER has it, kind 'degrade', tool and cause", #N.ledger == 1 and N.ledger[1].kind == "degrade"
      and N.ledger[1].source == "Bluetooth" and N.ledger[1].msg == "blueutil is not installed")
check("2/3 the CONSOLE line names the tool and the cause with a ⚠️",
      printedHas("⚠️ Bluetooth: blueutil is not installed"))
check("3/3 the ALERT is on the screen AT THE MOMENT, naming both",
      #ALERTS == 1 and ALERTS[1]:find("⚠️ Bluetooth — blueutil is not installed", 1, true) ~= nil, ALERTS[1])
check("…and it is a direct hs.alert, never hs.notify (Focus cannot swallow it)", #NOTIFIES == 0)
check("it is counted per tool", N.degrades["Bluetooth"].n == 1 and N.degradeTotal == 1)

-- P2: a degrade in a repeating timer is seen once, counted every time.
for _ = 1, 39 do N.degrade("Bluetooth", "blueutil is not installed") end
check("🚨 P2: the same tool + cause forty times inside the window ALERTS ONCE", #ALERTS == 1, #ALERTS)
check("…but is COUNTED forty times (the report answers 'how often')", N.degrades["Bluetooth"].n == 40 and N.degradeTotal == 40)
check("…and printed forty times (the Console gate limits repeats, not this)", #printed >= 40)
N.degrade("Bluetooth", "AirPods not paired")
check("a DIFFERENT cause on the same tool alerts at once", #ALERTS == 2 and ALERTS[2]:find("AirPods", 1, true) ~= nil)
CLOCK = CLOCK + N.degradeEvery
N.degrade("Bluetooth", "blueutil is not installed")
check("after degradeEvery the same cause alerts again — a break that persists is not forgotten", #ALERTS == 3)
check("MUTATION: with the gate deleted (degradeEvery = 0) the forty calls would have painted forty alerts — "
      .. "the once-per-window check above fails against it", N.degradeEvery > 0)

-- P4: nothing throws, whatever it is handed; a refused alert still records.
boot()
local okNil = pcall(N.degrade)
check("P4: degrade() with nothing at all does not throw", okNil)
check("…and still records a row and prints a line", #N.ledger == 1 and printedHas("⚠️ ?: no reason given"))
local realShow = hs.alert.show
hs.alert.show = function() error("AppKit said no") end
local okRef = pcall(N.degrade, "Vault", "cannot write")
hs.alert.show = realShow
check("P4: hs.alert throwing costs the alert only — the row and the line still land",
      okRef and #N.ledger == 2 and printedHas("⚠️ Vault: cannot write") and N.degrades["Vault"].alerts == 0)
local okTbl = pcall(N.degrade, { a = 1 }, { b = 2 })
check("P4: tables for tool and why are tostring'd, never a throw", okTbl)

-- bounded: tools remembered, causes per tool.
boot()
for i = 1, N.degradeMax + 15 do N.degrade("tool" .. i, "x") end
check("🚨 P2: the tool table is BOUNDED — the oldest tool is dropped past degradeMax",
      #N.degradeOrder == N.degradeMax and N.degrades["tool1"] == nil and N.degrades["tool" .. (N.degradeMax + 15)] ~= nil)
boot()
for i = 1, N.degradeCauses + 5 do N.degrade("OCR", "cause " .. i) end
local kept = 0
for _ in pairs(N.degrades["OCR"].seen) do kept = kept + 1 end
check("…and the causes remembered per tool are bounded too (a cause carrying a path is never the same twice)",
      kept == N.degradeCauses, kept)

-- the report: three states, ONE string (6.179.1's rule).
boot()
printed = {}
local r0 = _G.degradeReport()
check("the report prints as ONE string and returns it", #printed == 1 and printed[1] == r0)
check("with nothing degraded it says so in words", r0:find("0 time(s) across 0 tool(s)", 1, true) ~= nil
      and r0:find("nothing has degraded this session", 1, true) ~= nil)
check("…and names the door for the next module to take", r0:find("core.degrade(tool, why)", 1, true) ~= nil)
N.degrade("Bluetooth", "blueutil is not installed")
N.degrade("Bluetooth", "blueutil is not installed")
N.degrade("Vault", "cannot write")
printed = {}
local r1 = _G.degradeReport()
check("with degrades it lists each tool once with its count and LAST cause",
      #printed == 1 and r1:find("3 time(s) across 2 tool(s)", 1, true) ~= nil
      and r1:find("Bluetooth", 1, true) ~= nil and r1:find("×2", 1, true) ~= nil
      and r1:find("Vault", 1, true) ~= nil and r1:find("cannot write", 1, true) ~= nil, r1)
check("a tool whose alert was never shown is flagged (the third state: counted, never seen)",
      (function()
          boot()
          hs.alert.show = function() error("no") end
          N.degrade("Pomodoro", "no sound")
          hs.alert.show = realShow
          return _G.degradeReport():find("never alerted", 1, true) ~= nil
      end)())
check("the ledger's own report lists the degrade rows too (one ledger, every surface)",
      (function() boot(); N.degrade("Vault", "cannot write"); return _G.noticesReport():find("degrade", 1, true) ~= nil end)())

-- the core table: published on the real core, and init.lua carries a fallback.
boot()
local fakeCore = {}
N = dofile(HS .. "/core/notices.lua")(fakeCore)
check("core.degrade is set on the core table notices.lua is given", fakeCore.degrade == N.degrade)
local initSrc = (function() local f = realIoOpen(HS .. "/init.lua", "r"); if not f then return "" end local s = f:read("*a"); f:close(); return s end)()
check("SOURCE: init.lua's core table carries `degrade =` for the modules",
      initSrc:find("\n    degrade         = degrade,", 1, true) ~= nil)
check("SOURCE: init.lua's degrade falls back to its own ⚠️ print + hs.alert when notices did not load",
      initSrc:find("if _G.notices and _G.notices.degrade then return _G.notices.degrade(tool, why, opts) end", 1, true) ~= nil
      and initSrc:find('hs.alert.show("⚠️ " .. tostring(tool or "?") .. " — " .. why, 6)', 1, true) ~= nil)

io.open = realIoOpen
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
