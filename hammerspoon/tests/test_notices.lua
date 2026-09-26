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

-- =====================================================================
-- 🔕 6.295.0 — LOUD BY DEFAULT, QUIET ONLY WHERE HE SAID SO
-- =====================================================================
-- LL: visible warnings for anything that writes or gathers information
-- (Hamsidian, Asana, backups) — "anything that affects my productivity"
-- — and Console only for the ones he does not care about, "would be
-- Music Player".
out("\n-- the quiet list --\n")
boot()
check("🔕 the verdict is PURE and answers WHY, so the report can name the "
      .. "rule rather than printing a bare verdict",
      (function()
  local v, why = N.degradeVoice("Jug Player", { "Jug Player" })
  if v ~= "console" then return false, v end
  if not tostring(why):find("quiet list", 1, true) then return false, why end
  local v2, why2 = N.degradeVoice("Hamsidian", { "Jug Player" })
  return v2 == "alert" and tostring(why2):find("default", 1, true) ~= nil,
         v2 .. " / " .. tostring(why2)
end)())

-- 🚨 FAIL LOUD. The asymmetry is the whole design: a needless alert is
-- an annoyance, a swallowed one is the failure 6.278.0 exists to stop.
check("🚨 AN UNKNOWN TOOL ALERTS — the list is an allowlist that must be "
      .. "earned, never a guess at what matters (6.276.0, fail closed)",
      N.degradeVoice("Some brand new tool", {}) == "alert"
      and N.degradeVoice("Some brand new tool", { "Jug Player" }) == "alert")

-- 🔤 6.236.0's boundary rule, fourth time. music_player takes this door
-- as BOTH "Music player" and "Music player media keys".
check("🔤 one entry covers a tool and its sub-names, at a WORD BOUNDARY — "
      .. "'Jug Player' takes 'Jug Player media keys' and not "
      .. "'Jug PlayerX'",
      N.degradeVoice("Jug Player media keys", { "Jug Player" }) == "console"
      and N.degradeVoice("Jug PlayerX", { "Jug Player" }) == "alert")
check("...and it folds case, because a tool name is prose",
      N.degradeVoice("JUG PLAYER", { "jug player" }) == "console")

-- The shipped default is exactly what he named, and nothing else.
check("📏 the SHIPPED list is the Jug Player alone — everything he called "
      .. "productivity is loud without appearing on it",
      #N.quietTools == 1 and N.quietTools[1] == "Jug Player", table.concat(N.quietTools, ","))

-- And now the functional half, through the real door.
boot()
N.degrade("Jug Player", "this Mac has no hs.sound")
check("🔕 a quiet tool draws NO alert", #ALERTS == 0, #ALERTS .. " alerts")
check("📓 ...but the ⚠️ Console line is still printed, which is the whole "
      .. "of what he asked for — 'those items only need to post messages "
      .. "in the console'", printedHas("⚠️ Jug Player: this Mac has no hs.sound")
      and #printed > 0, tostring(#printed))
check("📓 ...and the LEDGER still has it — ⇪⇧D and _G.noticesReport() are "
      .. "not allowed a hole named 'music'",
      #N.ledger == 1 and N.ledger[1].kind == "degrade")
check("📓 ...and it is still COUNTED, so the report can say how often",
      N.degrades["Jug Player"].n == 1 and N.degradeTotal == 1)
check("...and the quiet route is counted apart", N.quietCount == 1
      and N.degrades["Jug Player"].quiet == 1)
N.degrade("Hamsidian", "Asana is off on this Mac")
check("🔔 ...while a tool NOT on the list alerts on screen in the same run",
      #ALERTS == 1 and ALERTS[1]:find("Hamsidian", 1, true) ~= nil, ALERTS[1])

-- 🚨 6.269.0 — THE NEW RULE MUST NOT BREAK THE INSTRUMENT WATCHING IT.
-- _G.degradeReport() has printed "never alerted — hs.alert refused"
-- whenever alerts was 0, which is now TRUE of every quiet tool: the
-- report would cry wolf on a healthy Mac on its first run.
boot()
N.degrade("Jug Player", "this Mac has no hs.sound")
printed = {}
local rq = _G.degradeReport()
check("🚨 A QUIET TOOL IS NOT A REFUSED ALERT — the report says Console "
      .. "only, never 'hs.alert refused' (6.269.0: a new rule must not "
      .. "break the instrument built to watch it)",
      rq:find("Console only", 1, true) ~= nil
      and rq:find("hs.alert refused", 1, true) == nil, rq)
check("🔎 ...and the report NAMES the quiet tools, because a policy you "
      .. "cannot read is a policy you cannot correct",
      rq:find("quiet", 1, true) ~= nil
      and rq:find("Jug Player", 1, true) ~= nil
      and rq:find("_G.degradeLoud", 1, true) ~= nil, rq)
check("🔎 ...and says the LOG still gets them, where he goes at 4 PM",
      rq:find("todayReport", 1, true) ~= nil, rq)

-- Three states on that line (6.196.1): the middle one is the trap —
-- "quiet and nothing has used it" must not read as "quiet and busy".
boot()
printed = {}
local rq0 = _G.degradeReport()
check("🔎 three states: quiet but unused says so, rather than reading as "
      .. "used", rq0:find("none has degraded this session", 1, true) ~= nil, rq0)
boot()
local savedQuiet = N.quietTools
N.quietTools = {}
printed = {}
local rqn = _G.degradeReport()
check("🔎 ...and with nothing quiet it says every tool alerts",
      rqn:find("every tool alerts on screen", 1, true) ~= nil, rqn)
N.quietTools = savedQuiet

-- The doors. He does not edit files (6.267.0), so adding a tool is a
-- Console line and it is reversible.
boot()
check("🚪 _G.degradeQuiet adds one and _G.degradeLoud takes it away",
      (function()
  local n0 = #N.quietTools
  if not _G.degradeQuiet("Weather thing") then return false, "add refused" end
  if #N.quietTools ~= n0 + 1 then return false, "not added" end
  if N.degradeVoice("Weather thing", N.quietTools) ~= "console" then return false, "still loud" end
  if _G.degradeQuiet("weather thing") then return false, "added twice" end
  if not _G.degradeLoud("Weather thing") then return false, "remove refused" end
  if N.degradeVoice("Weather thing", N.quietTools) ~= "alert" then return false, "still quiet" end
  return #N.quietTools == n0, #N.quietTools .. " vs " .. n0
end)())
check("🚪 ...and an empty name is refused rather than silencing everything",
      _G.degradeQuiet("") == false and _G.degradeQuiet(nil) == false)

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


out("\n=== 10. 6.274.0 — 🔔 THE CHANNEL EVERY OTHER TOOL REPORTS THROUGH ===\n")
-- LL: "hyper+4 is intermittently working", with eight hours of Console
-- carrying THREE "⚠️ an alert could not draw" lines. A refused alert is
-- the failure of the thing that reports failures, and nothing counted it
-- or recorded what it had been about.
boot()

-- ✂️ PURE. hs.alert takes a string OR a table of styled text, and this is
-- called from inside a failure path, so it must never add a second one.
check("alertWords: a plain string comes back", _G.alertWords("hello") == "hello")
check("alertWords: a styled table answers its .text",
      _G.alertWords({ text = "styled one" }) == "styled one")
check("alertWords: ...or its first element", _G.alertWords({ "first" }) == "first")
check("alertWords: nil is named, never blank", _G.alertWords(nil) == "(no text)")
check("alertWords: an empty string is named too", _G.alertWords("") == "(empty)")
check("alertWords: a report line is ONE line — newlines and tabs flatten",
      _G.alertWords("a\nb\tc") == "a b c", _G.alertWords("a\nb\tc"))
local long = string.rep("x", 200)
-- 🚨 MEASURED IN CHARACTERS, NOT BYTES — `#` and `:len()` count bytes,
-- and "…" alone is three of them, so a byte-counted assertion here fails
-- on a correct answer (6.226.0's rule, in the check rather than the code).
check("alertWords: a long alert is cut to the budget with an ellipsis",
      utf8.len(_G.alertWords(long, 20)) == 20
      and _G.alertWords(long, 20):sub(-3) == "…",
      _G.alertWords(long, 20) .. "  (" .. tostring(utf8.len(_G.alertWords(long, 20))) .. " chars)")
-- 🚨 CUT ON A GLYPH, NEVER A BYTE (6.226.0's rule in a new place): one
-- emoji is four bytes, and half of one is a string WebKit and the Console
-- both render as rubbish.
-- 🧪 AND THE FIRST VERSION OF THIS CHECK PASSED ITS OWN MUTATION. It
-- asked only "is the answer still valid UTF-8" at max = 5, and a BYTE
-- cut there takes s:sub(1, 4) — which is exactly one whole four-byte
-- emoji, valid by luck. The mutation that cuts in bytes bit nothing. So
-- it asserts the COUNT as well, which a byte cut cannot get right: five
-- characters means five emoji and an ellipsis, not one.
local emo = string.rep("😀", 10)
local cutE = _G.alertWords(emo, 5)
check("alertWords: the cut lands on a character boundary, not mid-emoji",
      utf8.len(cutE) ~= nil, cutE)
check("alertWords: ...and the budget is five CHARACTERS, not five bytes",
      utf8.len(cutE) == 5 and cutE:sub(-3) == "…", tostring(utf8.len(cutE)))

-- 🔎 THREE STATES, NEVER TWO (6.196.1). "you saw it late" and "you never
-- saw it" are different facts, and a healthy Mac must read as healthy.
_G.alertLate = { asked = 12, refused = 0, recovered = 0, lost = 0 }
local healthy = _G.alertReport()
check("alertReport: a Mac that refused nothing says so plainly",
      healthy:find("refused   : none", 1, true) ~= nil
      and healthy:find("⚠️", 1, true) == nil, healthy)
check("alertReport: ...and it is NOT silent about how many it drew",
      healthy:find("asked     : 12", 1, true) ~= nil)

_G.alertLate = { asked = 9, refused = 3, recovered = 3, lost = 0,
                 last = "Screenshot area selector — could not start", lastAt = "20:38:45" }
local late = _G.alertReport()
check("alertReport: alerts that drew on the RETRY are not counted as lost",
      late:find("recovered : 3", 1, true) ~= nil
      and late:find("🚨", 1, true) == nil, late)
check("alertReport: ...and the last refusal's own words ride into it",
      late:find("Screenshot area selector", 1, true) ~= nil
      and late:find("20:38:45", 1, true) ~= nil, late)

_G.alertLate = { asked = 9, refused = 3, recovered = 1, lost = 2,
                 last = "File tracker — a CSV write took 400 ms", lastAt = "04:16:51" }
local lost = _G.alertReport()
check("alertReport: a LOST alert is a fault he never saw, and it says so",
      lost:find("lost      : 2", 1, true) ~= nil
      and lost:find("A TOOL THAT REPORTED A FAULT YOU NEVER SAW", 1, true) ~= nil, lost)
check("alertReport: ...and it points at the reports that DID record it",
      lost:find("_G.degradeReport()", 1, true) ~= nil
      and lost:find("_G.canvasShowReport()", 1, true) ~= nil)
_G.alertLate = nil

-- 🔒 SOURCE: the counting lives in init.lua's wrapper, which is the only
-- place it can (it wraps before any module loads). A stub hs.alert cannot
-- prove this — the wrapper is installed at boot and the suite never runs
-- init.lua — so it is asserted against the file, as 6.198.0's timer slot
-- and 6.196.1's task slots are.
local initSrc2 = (function() local f = realIoOpen(HS .. "/init.lua", "r")
    if not f then return "" end local x = f:read("*a"); f:close(); return x end)()
check("SOURCE: every alert asked for is counted",
      initSrc2:find("_G.alertLate.asked = _G.alertLate.asked + 1", 1, true) ~= nil)
check("SOURCE: a refusal is counted",
      initSrc2:find("_G.alertLate.refused = _G.alertLate.refused + 1", 1, true) ~= nil)
check("SOURCE: one that drew on the retry is counted as RECOVERED, not lost",
      initSrc2:find("_G.alertLate.recovered = _G.alertLate.recovered + 1", 1, true) ~= nil)
check("SOURCE: one the retry could not draw is counted LOST",
      initSrc2:find("_G.alertLate.lost = _G.alertLate.lost + 1", 1, true) ~= nil)
-- 🚨 AND A RETRY THAT COULD NEVER BE ARMED IS ALSO LOST — without this
-- branch a Mac with no hs.timer reads as "still in flight" for ever,
-- which is 6.196.1's exact failure in the instrument built to keep it.
check("SOURCE: a retry that could not be ARMED is lost too, not left pending",
      initSrc2:find("if not armed then _G.alertLate.lost = _G.alertLate.lost + 1 end", 1, true) ~= nil)
check("SOURCE: the refusal remembers WHAT the alert said",
      initSrc2:find("_G.alertWords(args[1])", 1, true) ~= nil)

out("\n=== 11. 6.279.0 — 📓 WHAT FAILED TODAY, AFTER A RELOAD ===\n")
-- =====================================================================
-- LL: "Can you also create an error message log for any of my tools that
-- fail? I can check this log at 4pm for a double verification that
-- anything I was using today that should capture information worked."
--
-- 🚨 The ledger is a Lua TABLE — every reload empties it, and a reload is
-- likeliest exactly when something broke and got edited. These checks run
-- against a REAL file on disk, because the whole claim is that the answer
-- outlives the process.
do
    local DIR = os.getenv("TMPDIR") or "/tmp"
    local LOG = DIR .. "/hs-degrades-test-" .. tostring(os.time()) .. ".csv"
    os.remove(LOG)

    -- ✏️ PURE first: a row the reader cannot parse vanishes in silence
    -- (6.179.0), and a real `why` carries commas, quotes and newlines —
    -- a path, a shell error, macOS's own words.
    boot()
    local row = N.logRow("Screenshots", 'folder "A, B" missing\nsecond line', 1700000000)
    check("📓 the row is CSV-safe: the comma stays inside its field",
          select(2, row:gsub(",", "")) == 4 or row:find('"folder ""A, B"" missing', 1, true) ~= nil,
          row)
    check("...a quote in the cause is doubled, not left to end the field",
          row:find('""A, B""', 1, true) ~= nil, row)
    check("...and a newline never becomes a second row",
          row:find("\n") == nil, row)
    check("...the date, the clock and the epoch are all there, so a row "
          .. "can be filtered by day and still sorted exactly",
          row:find("^\"%d%d%d%d%-%d%d%-%d%d\",\"%d%d:%d%d:%d%d\",1700000000,") ~= nil,
          row)

    -- ⏳ BUFFERED UNTIL IT KNOWS WHERE TO WRITE. notices.lua loads before
    -- §0.1 exists, so without this every BOOT-TIME degrade — the ones
    -- most worth having — would simply not be in the log.
    boot()
    N.degrade("Early tool", "broke during boot")
    check("⏳ a degrade before the path is known is BUFFERED, not lost — "
          .. "boot-time failures are the ones worth having",
          #N.logQueue == 1 and N.logWrote == 0, #N.logQueue)
    check("...and _G.todayReport() says so rather than reading clean: "
          .. "'no log yet' must never print as 'nothing failed'", (function()
        local r = _G.todayReport()
        return r:find("no log file yet", 1, true) ~= nil
               and r:find("NOT 'nothing failed'", 1, true) ~= nil
               and r:find("nothing failed today", 1, true) == nil
    end)())

    N.logTo(LOG)
    check("...and logTo() flushes the buffer to disk", N.logWrote == 1 and #N.logQueue == 0,
          N.logWrote .. "/" .. #N.logQueue)

    -- and from here it appends as it goes
    N.degrade("Hamsidian 4 PM send", "Asana would not accept it")
    N.degrade("Hamsidian 4 PM send", "Asana would not accept it")
    N.degrade("Screenshots", "no folder to write to")
    check("every later degrade appends immediately", N.logWrote == 4, N.logWrote)

    local rep = _G.todayReport()
    check("📓 the 4 PM answer names every tool that failed today",
          rep:find("Early tool", 1, true) ~= nil
          and rep:find("Hamsidian 4 PM send", 1, true) ~= nil
          and rep:find("Screenshots", 1, true) ~= nil, rep)
    check("...with the CAUSE, not just a count — a tool name alone sends "
          .. "him nowhere", rep:find("Asana would not accept it", 1, true) ~= nil)
    check("...and repeats are collapsed with a count rather than listed "
          .. "twice", rep:find("×2", 1, true) ~= nil, rep)
    check("...and the total is stated", rep:find("4 failure", 1, true) ~= nil, rep)

    -- 🔕 6.295.0 — AND A QUIET TOOL IS IN THE LOG TOO. This is the whole
    -- of "quiet is about the alert and nothing else", and it is the half
    -- with real consequences: his 4 PM double-check (6.279.0) must not
    -- acquire a blind spot named "music". Found by the mutation sweep —
    -- the guarantee was written down, asserted in the ledger, and NOT
    -- asserted here, so moving the log write behind the quiet verdict
    -- passed every check in the release (6.273.0: when a fix lands on a
    -- line no mutation can kill, the line is not the finding).
    N.degrade("Jug Player", "this Mac has no hs.sound")
    check("🔕 a QUIET tool is written to the log — quiet is the alert and "
          .. "nothing else, and this is where he looks at 4 PM",
          N.logWrote == 5, N.logWrote)
    local repQ = _G.todayReport()
    check("📓 ...and _G.todayReport() names it, beside the loud ones",
          repQ:find("Jug Player", 1, true) ~= nil
          and repQ:find("this Mac has no hs.sound", 1, true) ~= nil, repQ)

    -- 🔁 IT SURVIVES THE RELOAD. This is the entire claim of the release:
    -- a FRESH notices (an empty ledger, exactly as after a reload) reads
    -- the same answer back off disk.
    boot()
    check("the fresh ledger really is empty — otherwise the next check "
          .. "proves nothing", N.degradeTotal == 0)
    N.logTo(LOG)
    local after = _G.todayReport()
    check("🔁 AFTER A RELOAD the answer is still there — the ledger is "
          .. "empty and the log is not",
          after:find("Hamsidian 4 PM send", 1, true) ~= nil
          and after:find("Asana would not accept it", 1, true) ~= nil, after)

    -- a different day reads clean, and says which day it read
    local other = _G.todayReport("1999-01-01")
    check("a day with no rows reads CLEAN and says the log was read",
          other:find("nothing failed", 1, true) ~= nil
          and other:find("the log was read", 1, true) ~= nil, other)

    -- 🚨 AND AN UNREADABLE LOG IS NOT A CLEAN ONE (6.196.1). This is the
    -- state the whole report exists to keep honest: "nothing failed
    -- today" is the most reassuring sentence this config can print, and
    -- it would be a lie on exactly the day the disk is full.
    boot()
    N.logTo(DIR .. "/no-such-dir-" .. tostring(os.time()) .. "/x.csv")
    local unread = _G.todayReport()
    check("🚨 a log that cannot be READ says UNKNOWN, never 'nothing "
          .. "failed today'",
          unread:find("COULD NOT READ", 1, true) ~= nil
          and unread:find("not as clear", 1, true) ~= nil
          and unread:find("nothing failed today", 1, true) == nil, unread)

    -- 🔁 AND THE LOGGER NEVER TAKES THE DOOR ITSELF. A logger reporting
    -- its own failure through core.degrade calls itself, for ever, on the
    -- first unwritable disk — so a degrade must stay exactly one degrade
    -- however badly the write goes.
    local before = N.degradeTotal
    N.degrade("Some tool", "something broke")
    check("🔁 an unwritable log does not make the degrade recurse — one "
          .. "degrade stays one degrade",
          N.degradeTotal == before + 1, N.degradeTotal - before)
    check("...the failed write is COUNTED instead", N.logFails >= 1, N.logFails)
    check("...and named in the report, with the warning that it may be "
          .. "missing failures it never saw", (function()
        local r = _G.todayReport()
        return r:find("could not be written", 1, true) ~= nil
               and r:find("missing failures", 1, true) ~= nil
    end)())

    -- bounded, newest kept
    boot()
    for i = 1, N.logMax + 25 do N.degrade("Flood", "cause " .. i) end
    check("the pending buffer is BOUNDED", #N.logQueue == N.logMax, #N.logQueue)
    -- 🧪 ANSWERS FALSELY RATHER THAN INDEXING A NIL (6.186.0, and this
    -- suite learned it the same way every other one has): the mutation
    -- that deletes the buffer leaves logQueue empty, and `last():find`
    -- on a nil ENDS THE RUN with "0 failed" never printed. A dead suite
    -- looks like a passing one in a gate that only reads the tail.
    local function lastQueued()
        local q = N.logQueue
        return (type(q) == "table" and type(q[#q]) == "string") and q[#q] or ""
    end
    check("...and it keeps the NEWEST — if a boot degrades two hundred "
          .. "times, the recent ones are the ones still true afterwards",
          lastQueued():find("cause " .. (N.logMax + 25), 1, true) ~= nil,
          lastQueued())

    os.remove(LOG)
end

io.open = realIoOpen
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
