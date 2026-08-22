-- =====================================================================
-- test_lag.lua — the probe that names the tap eating the keystroke
-- =====================================================================
--     lua5.4 test_lag.lua [/path/to/hammerspoon]
--
-- Executes core/lag.lua against a stubbed hs and drives real wrapped
-- callbacks through it with a clock this file controls.
--
-- The checks with teeth are sections 3, 4, 9 and 12.
--
--   3  THE WRAPPER MUST BE INVISIBLE. It sits in the path of every
--      keystroke on this Mac. If it drops a return value the expander
--      stops consuming the key it replaced; if it adds a pcall the
--      errors stop reaching the guards that switch a broken tap off.
--      Both are silent, and both are worse than the lag.
--   4  THE ARITHMETIC IS THE PRODUCT. A probe that measures wrongly is
--      not a weaker probe, it is a liar with a table of numbers, and
--      6.130.0 already shipped one sentry that a real break walked
--      straight through.
--   9  IT MUST BEAT THE FIRST TAP. The whole design rests on being
--      loaded before anything creates one; a report that silently
--      covered half the taps would read exactly like a clean bill.
--  12  THE SWITCH IS PRESSED BY SOMEONE WHOSE TYPING IS ALREADY BROKEN,
--      and both of its failure modes are silent. Returning true instead
--      of false makes it EAT every keystroke. Stopping the taps instead
--      of making them inert gets quietly undone by the expander and
--      autocorrect watchdogs half a minute later — which does not fail,
--      it lies, and it lies in the direction of "taps are innocent".
-- =====================================================================

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

local printed = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- ---- the stub Mac ------------------------------------------------------
local TYPES = { keyDown = 10, keyUp = 11, flagsChanged = 12,
                leftMouseDown = 1, rightMouseDown = 3 }

local CLOCK      = 0        -- nanoseconds, driven by hand
local MADE       = {}       -- every tap the REAL (stub) new was asked for
local TIMERS     = {}
local FRONT      = "Excel"
local NEW_FAILS  = false

local function stubNew(types, fn, ...)
    if NEW_FAILS then error("no accessibility") end
    -- stopCalls exists for section 12: the switch must make a tap INERT
    -- without stopping it, because a stopped tap is what the expander and
    -- autocorrect watchdogs go looking for and restart.
    -- started = true from birth: the real hs.eventtap.new is followed by
    -- :start() everywhere in this config, and section 16 needs to tell a
    -- tap that was RUNNING when the test began from one that was already
    -- stopped — those two must be restored differently.
    local tap = { types = types, fn = fn, started = true, extra = { ... },
                  stopCalls = 0, startCalls = 0 }
    function tap:start()
        self.startCalls = self.startCalls + 1
        self.started = true
        return self
    end
    function tap:stop()
        self.stopCalls = self.stopCalls + 1
        self.started = false
        return self
    end
    function tap:isEnabled() return self.started end
    MADE[#MADE + 1] = tap
    return tap
end

-- 6.135.0 — driven by hand so section 16 can prove the report says so.
-- nil means "this Hammerspoon cannot tell us", which is a third state and
-- must print neither the warning nor the all-clear.
local SECURE = false

local function freshEventtap()
    MADE = {}
    hs.eventtap = {
        event = { types = TYPES },
        new   = stubNew,
        isSecureInputEnabled = function()
            if SECURE == nil then error("not available") end
            return SECURE
        end,
    }
end

local AFTERS  = {}       -- every hs.timer.doAfter asked for
local ALERTS  = {}       -- every hs.alert.show
local CLIP    = nil      -- last hs.pasteboard.setContents

local function stubDoEvery(secs, fn)
    local t = { secs = secs, fn = fn, stopped = false }
    function t:stop()  self.stopped = true  ; return self end
    function t:start() self.stopped = false ; return self end
    TIMERS[#TIMERS + 1] = t
    return t
end
local function stubTimerNew(secs, fn)
    local t = { secs = secs, fn = fn, stopped = false, kind = "new" }
    function t:stop() self.stopped = true ; return self end
    function t:start() self.stopped = false ; return self end
    TIMERS[#TIMERS + 1] = t
    return t
end
local function stubDoAfter(secs, fn)
    local t = { secs = secs, fn = fn, stopped = false }
    function t:stop() self.stopped = true ; return self end
    AFTERS[#AFTERS + 1] = t
    return t
end

hs = {
    timer = {
        absoluteTime = function() return CLOCK end,
        doEvery  = stubDoEvery,
        new      = stubTimerNew,
        doAfter  = stubDoAfter,
    },
    application = {
        frontmostApplication = function()
            return { name = function() return FRONT end }
        end,
    },
    alert = { show = function(s) ALERTS[#ALERTS + 1] = tostring(s) end },
    pasteboard = { setContents = function(s) CLIP = s end },
}
freshEventtap()

-- 6.134.0 — the timer wrap has its own once-only guard, exactly like the
-- eventtap one. Without clearing it here every probe after the first
-- would measure timers into the FIRST probe's table, and section 13
-- would be reading numbers that belong to a probe it did not create.
local function freshTimers()
    TIMERS, AFTERS = {}, {}
    hs.timer.doEvery = stubDoEvery
    hs.timer.new     = stubTimerNew
    hs.timer.__lagOriginalDoEvery = nil
    hs.timer.__lagOriginalNew     = nil
end

local chunk = assert(loadfile(HS .. "/core/lag.lua"))

-- A brand-new probe over a brand-new eventtap stub. Used by most
-- sections: the double-install guard is deliberate and would otherwise
-- make every section after the first one measure nothing.
local function freshProbe()
    freshEventtap()
    freshTimers()
    return chunk()({})
end

-- Advance the controlled clock by ms and return it (nanoseconds inside).
local function advance(ms) CLOCK = CLOCK + ms * 1e6 end

local lag = freshProbe()

-- =====================================================================
out("1. it installs, and says so\n")
-- =====================================================================
check("hs.eventtap.new was replaced", hs.eventtap.new ~= stubNew)
check("the original is kept, so the wrap can be seen and undone",
      hs.eventtap.__lagOriginalNew == stubNew)
check("installedAt is stamped", type(lag.installedAt) == "string"
      and lag.installedAt:match("%d%d:%d%d:%d%d") ~= nil, lag.installedAt)
check("nothing is wrapped yet", lag.wrapped == 0, lag.wrapped)
check("no note — the install went cleanly", lag.note == nil, lag.note)
check("the heartbeat timer is HELD (an unreferenced timer never fires)",
      lag.beat ~= nil and lag.beat.secs == lag.stallEvery)

-- =====================================================================
out("2. a created tap is recorded, and named by where it came from\n")
-- =====================================================================
local keyTap = hs.eventtap.new({ TYPES.keyDown, TYPES.flagsChanged },
                               function() return false end)
check("the real hs.eventtap.new still ran", #MADE == 1)
check("it returned the real tap object", keyTap == MADE[1])
check("one tap recorded", #lag.taps == 1, #lag.taps)
check("wrapped count follows", lag.wrapped == 1, lag.wrapped)

local rec = lag.taps[1]
check("the site names THIS file, not an anonymous function",
      tostring(rec.site):find("test_lag%.lua:") ~= nil, rec.site)
check("the site carries a line number",
      tostring(rec.site):match(":%d+$") ~= nil, rec.site)
-- 🚨 THE TWO WAYS THIS COLUMN GOES WRONG, both of which shipped once
-- during 6.131.0's own build and neither of which threw anything. A
-- report whose every row says "core/lag.lua" or "[C]" is not a broken
-- probe you would notice — it is a full, confident, useless table.
check("🚨 the site is never the probe's own file — it must not name itself",
      tostring(rec.site):find("core/lag%.lua") == nil, rec.site)
check("🚨 the site is never a C frame — pcall is not somewhere to look",
      tostring(rec.site):find("%[C%]") == nil, rec.site)
check("…and never gives up when a real caller exists",
      rec.site ~= "unknown", rec.site)
check("the watched types are named, not numbered",
      rec.types == "keyDown+flagsChanged", rec.types)
check("it is classified as a keyboard tap", rec.keyboard == true)
check("counters start at zero",
      rec.calls == 0 and rec.total == 0 and rec.max == 0 and rec.slow == 0)

-- 🚨 A MOUSE-ONLY TAP CANNOT DELAY A KEYSTROKE, and a report that let a
-- busy mouse tap sit at the top of the list would send the reader after
-- the wrong thing. The classification is what keeps it out of the verdict.
local mouseTap = hs.eventtap.new({ TYPES.leftMouseDown },
                                 function() return false end)
check("a mouse-only tap is recorded", #lag.taps == 2)
check("…but is NOT counted as a keyboard tap",
      lag.taps[2].keyboard == false, lag.taps[2].keyboard)
check("…and its types are still named",
      lag.taps[2].types == "leftMouseDown", lag.taps[2].types)

-- =====================================================================
out("3. the wrapper is invisible to the tap it wraps\n")
-- =====================================================================
-- 🚨 THIS SECTION IS THE ONE THAT PROTECTS THE KEYBOARD. Everything the
-- callback said before must still be said, and everything it threw must
-- still be thrown.
local SEEN = {}
local replacement = { "an", "event", "list" }
freshProbe()
local echo = hs.eventtap.new({ TYPES.keyDown }, function(ev)
    SEEN[#SEEN + 1] = ev
    return true, replacement
end)
local a, b = echo.fn("the-event")
check("the event is passed through untouched", SEEN[1] == "the-event")
check("the boolean return survives the wrapper", a == true, a)
check("🚨 THE SECOND RETURN VALUE SURVIVES TOO — a dropped event list "
      .. "means a replaced keystroke silently vanishes",
      b == replacement, tostring(b))

-- An eventtap callback that throws must still throw. Every tap in this
-- config has its own guard that counts failures and switches itself off;
-- a pcall in the wrapper would eat the error and those guards would never
-- fire again.
freshProbe()
local boom = hs.eventtap.new({ TYPES.keyDown },
                             function() error("tap exploded", 0) end)
local okCall, errCall = pcall(boom.fn, "ev")
check("🚨 an error inside the callback still propagates — the wrapper "
      .. "adds no pcall", okCall == false)
check("…and the message is unchanged", tostring(errCall) == "tap exploded",
      errCall)

-- Something that is not a callback is not ours to police.
freshProbe()
local before = #lag.taps
local raw = hs.eventtap.new({ TYPES.keyDown }, nil)
check("a non-function callback is handed straight to the real new",
      raw ~= nil and #MADE >= 1)
check("…and is not recorded as a measurable tap", #lag.taps == before,
      #lag.taps)

-- =====================================================================
out("4. the arithmetic\n")
-- =====================================================================
lag = freshProbe()
lag.slowMs = 8
local t = hs.eventtap.new({ TYPES.keyDown }, function()
    advance(2)                      -- this callback "takes" 2ms
    return false
end)
t.fn("a") ; t.fn("b") ; t.fn("c")
local r = lag.taps[1]
check("three calls counted", r.calls == 3, r.calls)
check("total is the sum in MILLISECONDS", math.abs(r.total - 6) < 0.001, r.total)
check("max is one call's worth", math.abs(r.max - 2) < 0.001, r.max)
check("none of them was slow", r.slow == 0, r.slow)
check("worstAt is stamped when the max moves",
      type(r.worstAt) == "string", r.worstAt)

-- One slow call, and the max must move to it.
local slow = hs.eventtap.new({ TYPES.keyDown }, function()
    advance(40) ; return false
end)
slow.fn("x")
local rs = lag.taps[2]
check("a 40ms call is over the 8ms line", rs.slow == 1, rs.slow)
check("…and max reflects it", math.abs(rs.max - 40) < 0.001, rs.max)

-- 🚨 THE BOUNDARY. slowMs is a >= comparison; a call landing exactly on
-- the line counts. Off by one here silently under-reports every tap that
-- sits right at the threshold, which is where the interesting ones are.
local edge = hs.eventtap.new({ TYPES.keyDown }, function()
    advance(8) ; return false
end)
edge.fn("x")
check("a call exactly ON the slow line counts as slow",
      lag.taps[3].slow == 1, lag.taps[3].slow)

-- =====================================================================
out("5. the double-install guard\n")
-- =====================================================================
-- Wrapping twice would put two layers of timing on every keystroke and
-- double every number in the report — a config that appeared to have
-- halved in speed overnight, caused entirely by the tool sent to explain
-- why it felt slow.
local wrappedNew = hs.eventtap.new
local second = chunk()({})
check("the second install refuses", second.installedAt == nil,
      second.installedAt)
check("…and says why", tostring(second.note):find("already installed") ~= nil,
      second.note)
check("🚨 hs.eventtap.new is NOT wrapped a second time",
      hs.eventtap.new == wrappedNew)

-- And a Hammerspoon with no eventtap at all must not take the config down.
do
    local savedTap = hs.eventtap
    hs.eventtap = {}
    local noTap = chunk()({})
    check("no hs.eventtap.new — the probe declines instead of throwing",
          noTap.installedAt == nil)
    check("…and names the reason",
          tostring(noTap.note):find("not available") ~= nil, noTap.note)
    hs.eventtap = savedTap
end

-- =====================================================================
out("6. the clock, and its fallback\n")
-- =====================================================================
do
    local savedAbs = hs.timer.absoluteTime
    hs.timer.absoluteTime = nil
    hs.timer.secondsSinceEpoch = function() return CLOCK / 1e9 end
    freshEventtap() ; freshTimers()
    local fb = chunk()({})
    local before2 = CLOCK
    local ft = hs.eventtap.new({ TYPES.keyDown }, function()
        advance(5) ; return false
    end)
    ft.fn("x")
    check("secondsSinceEpoch is used when absoluteTime is missing",
          math.abs(fb.taps[1].total - 5) < 0.001, fb.taps[1].total)
    check("…and it is still normalised to milliseconds",
          fb.taps[1].total < 100, fb.taps[1].total)
    CLOCK = before2 + 5e6
    hs.timer.secondsSinceEpoch = nil
    hs.timer.absoluteTime = savedAbs

    -- No clock at all: the numbers are worthless and the report must SAY
    -- so rather than print a table of confident zeroes.
    local savedTimer = hs.timer
    hs.timer = { doEvery = savedTimer.doEvery }
    freshEventtap() ; freshTimers()
    local blind = chunk()({})
    check("with no clock the probe still installs",
          blind.installedAt ~= nil)
    check("🚨 …and warns that every timing will read zero",
          tostring(blind.note):find("no usable clock") ~= nil, blind.note)
    hs.timer = savedTimer
end

-- =====================================================================
out("7. stalls\n")
-- =====================================================================
lag = freshProbe()
lag.stallMs = 120
local beat = lag.beat
check("the heartbeat is on the timer list", beat ~= nil)

-- A tick that arrives on time is not a stall.
local function tick(ms) advance(ms) ; beat.fn() end
tick(50)
check("an on-time tick records nothing", lag.stallCount == 0, lag.stallCount)
tick(60)
check("10ms of jitter is not a stall", lag.stallCount == 0, lag.stallCount)

-- 350ms late is felt.
tick(400)
check("a 350ms block is recorded", lag.stallCount == 1, lag.stallCount)
check("…with the app that was in front", lag.stalls[1].app == "Excel",
      lag.stalls[1].app)
check("…and the lateness, not the interval",
      math.abs(lag.stalls[1].late - 350) < 1, lag.stalls[1].late)
check("…and a time of day", tostring(lag.stalls[1].when):match("%d%d:%d%d")
      ~= nil, lag.stalls[1].when)

-- 🚨 THE LIST KEEPS THE WORST, NOT THE LAST. A stall storm of small ones
-- must not push out the four-second freeze that is the actual problem.
lag = freshProbe()
lag.stallMs, lag.keepStalls = 100, 3
local b2 = lag.beat
local function tick2(ms) advance(ms) ; b2.fn() end
tick2(50)
tick2(4050)                   -- 4000ms — the big one
for _ = 1, 8 do tick2(250) end -- 200ms each, eight of them
check("the list is capped", #lag.stalls == 3, #lag.stalls)
check("every stall is still COUNTED, capped list or not",
      lag.stallCount == 9, lag.stallCount)
local biggest = 0
for _, s in ipairs(lag.stalls) do
    if s.late > biggest then biggest = s.late end
end
check("🚨 the four-second freeze SURVIVED eight later smaller ones",
      math.abs(biggest - 4000) < 1, biggest)

-- =====================================================================
out("8. the report\n")
-- =====================================================================
lag = freshProbe()
lag.slowMs = 8
local quick = hs.eventtap.new({ TYPES.keyDown }, function()
    advance(1) ; return false
end)
local heavy = hs.eventtap.new({ TYPES.keyDown, TYPES.flagsChanged }, function()
    advance(30) ; return false
end)
local mouseOnly = hs.eventtap.new({ TYPES.leftMouseDown }, function()
    advance(90) ; return false
end)

-- Nothing has run yet: the verdict must not pretend to know anything.
local early = _G.lagReport()
check("with no keystrokes seen, the verdict says so",
      early:find("no keyboard tap has run yet") ~= nil)

for _ = 1, 10 do quick.fn("k") end
for _ = 1, 10 do heavy.fn("k") end
mouseOnly.fn("m")

local rep = _G.lagReport()
check("the report prints", #printed > 0)
check("it names the install time", rep:find("installed") ~= nil)
check("it names how many taps it saw", rep:find("taps seen  : 3") ~= nil)
check("every tap's site is listed",
      rep:find("test_lag%.lua:") ~= nil)
check("the columns are there",
      rep:find("calls") ~= nil and rep:find("avg ms") ~= nil
      and rep:find("max ms") ~= nil)
check("a mouse-only tap is labelled as such",
      rep:find("%(mouse only%)") ~= nil)

-- 🚨 SORTED BY TOTAL, NOT BY AVERAGE. The mouse tap here averages 90ms —
-- nine times the heavy keyboard tap — but has run once, for 90ms total,
-- against the keyboard tap's 300ms. Sorting by average would put the
-- irrelevant one at the top of a report about slow typing.
do
    local hi = rep:find("300%.00") or 0            -- heavy: 10 × 30ms
    local mo = rep:find("90%.00")  or 0
    local _  = mo
    local heavyLine  = rep:match("([^\n]*30%.00[^\n]*)") or ""
    local firstRow   = rep:match("max ms%s+slow\n(.-)\n") or ""
    check("the heaviest tap is the first row",
          firstRow:find("test_lag%.lua:") ~= nil
          and firstRow:find("30%.00") ~= nil, firstRow)
    check("the heavy tap's line reports its average",
          heavyLine:find("30%.00") ~= nil, heavyLine)
    local _ = hi
end

-- The verdict must name the tap, not leave the reader to work it out.
check("🚨 the verdict NAMES the worst keyboard tap",
      rep:find("VERDICT") ~= nil and rep:find("averaging 30%.0ms") ~= nil,
      rep:match("VERDICT[^\n]*"))
-- 🚨 THIS CHECK USED TO SEARCH THE VERDICT LINE FOR "90" — the mouse
-- tap's 90ms average — and it was a proxy that broke the moment this
-- file grew: the heavy tap moved to line 390, so the verdict read
-- "test_lag.lua:390 is averaging 30.0ms" and the check failed over a
-- probe that was behaving perfectly. A test that fails on a line number
-- is a test that will be silenced rather than read. It now compares the
-- verdict against the SITES the probe actually recorded, which is the
-- thing the check was always trying to say.
do
    local verdict  = rep:match("VERDICT[^\n]*") or ""
    local heavyRec, mouseRec
    for _, r in ipairs(lag.taps) do
        if r.keyboard and r.max >= 29 then heavyRec = r end
        if not r.keyboard then mouseRec = r end
    end
    check("the heavy keyboard tap and the mouse tap are both on record",
          heavyRec ~= nil and mouseRec ~= nil)
    check("…and it is the KEYBOARD tap the verdict names",
          verdict:find(heavyRec.site, 1, true) ~= nil, verdict)
    check("…never the mouse tap, which cannot delay a keystroke",
          verdict:find(mouseRec.site, 1, true) == nil, verdict)
end

-- When nothing is slow the verdict has to say THAT, clearly, because
-- "no tap is at fault" is the answer that sends you to the stalls.
lag = freshProbe()
lag.slowMs = 8
local fastTap = hs.eventtap.new({ TYPES.keyDown }, function()
    advance(0.5) ; return false
end)
for _ = 1, 5 do fastTap.fn("k") end
local clean = _G.lagReport()
check("a clean run says every tap is fast",
      clean:find("every keyboard tap is fast") ~= nil,
      clean:match("VERDICT[^\n]*"))
check("…and points at the stalls instead",
      clean:find("it is not a tap") ~= nil)
check("…and reports the per-keystroke total, which is the number that "
      .. "actually answers the question",
      clean:find("0%.50ms total per keystroke") ~= nil,
      clean:match("VERDICT[^\n]*"))
check("with no stalls it says the thread stayed responsive",
      clean:find("has stayed responsive") ~= nil)
check("🚨 the report says a stall is not automatically a bug",
      clean:find("not proof of a bug") ~= nil)

-- Reset.
local msg = _G.lagReset()
check("reset says when", tostring(msg):find("zeroed") ~= nil, msg)
check("counters are zero", lag.taps[1].calls == 0 and lag.taps[1].total == 0)
check("stalls are cleared", #lag.stalls == 0 and lag.stallCount == 0)
check("…but the taps themselves are still listed — a reset must not "
      .. "make the config look tap-free", #lag.taps == 1, #lag.taps)

-- A report before any install at all.
do
    local savedTap = hs.eventtap
    hs.eventtap = {}
    local none = chunk()({})
    local s = _G.lagReport()
    check("an uninstalled probe reports that fact loudly",
          s:find("NOT INSTALLED") ~= nil)
    local _ = none
    hs.eventtap = savedTap
end

-- =====================================================================
out("9. it must beat the first tap — the load-order sentry\n")
-- =====================================================================
local initSrc do
    local f = assert(io.open(HS .. "/init.lua", "r"))
    initSrc = f:read("*a") ; f:close()
end

local lagAt   = initSrc:find("core/lag%.lua")
local hyperAt = initSrc:find("core/hyper_key%.lua'")
local sheetAt = initSrc:find("core/cheatsheet%.lua'")
check("init.lua loads core/lag.lua", lagAt ~= nil)
check("🚨 …BEFORE core/hyper_key.lua, which makes the hyper tap",
      lagAt ~= nil and hyperAt ~= nil and lagAt < hyperAt, lagAt)
check("🚨 …and before core/cheatsheet.lua, which makes one too",
      lagAt ~= nil and sheetAt ~= nil and lagAt < sheetAt, sheetAt)

-- 🚨 AND NOTHING MAY CREATE A TAP ABOVE IT. This is the check that
-- actually holds the design up: every assertion in the report — "taps
-- seen: 9", the verdict, the whole table — is only true if no tap was
-- born before the wrap went on. A tap added above this line would not
-- appear anywhere, and the report would look exactly as it does now.
do
    local head = initSrc:sub(1, lagAt or 1)
    check("🚨 no hs.eventtap.new is called before the probe installs",
          head:find("hs%.eventtap%.new") == nil,
          head:match("[^\n]*hs%.eventtap%.new[^\n]*"))
end

-- The module loader must come after it too, or half the modules' taps
-- would be invisible.
do
    local loaderAt = initSrc:find("_G%.loadModules%(profile%.modules")
    check("🚨 …and before the module loader runs",
          lagAt ~= nil and loaderAt ~= nil and lagAt < loaderAt, loaderAt)
end

-- =====================================================================
out("10. the source itself\n")
-- =====================================================================
local src do
    local f = assert(io.open(HS .. "/core/lag.lua", "r"))
    src = f:read("*a") ; f:close()
end

-- The hot path is the wrapped callback. Find it and check what is NOT
-- in it — this is a probe for per-keystroke cost, so per-keystroke cost
-- it adds itself is the one bug it cannot have.
local hot = src:match("local wrapped = function%(ev%)(.-)\n            end")
check("the wrapped callback was found", hot ~= nil)
if hot then
    check("🚨 no pcall in the hot path", hot:find("pcall") == nil, hot)
    check("🚨 no table.pack in the hot path — it would allocate on every "
          .. "keystroke", hot:find("table%.pack") == nil)
    check("🚨 no os.date on every call — only when the max actually moves",
          hot:find("os%.date") ~= nil
          and hot:match("if dt > rec%.max then\n.-os%.date") ~= nil)
    check("the callback is called directly, not through a guard",
          hot:find("local a, b = fn%(ev%)") ~= nil)
end

check("the heartbeat timer is held in a field, not a local",
      src:find("lag%.beat = t") ~= nil)
check("the front app is only read inside recordStall, never per-tick",
      select(2, src:gsub("frontmostApplication", "")) == 1)
check("the probe publishes itself for the report to reach",
      src:find("_G%.lagProbe = lag") ~= nil)
check("both report entry points exist",
      src:find("function _G%.lagReport") ~= nil
      and src:find("function _G%.lagReset") ~= nil)

-- =====================================================================
-- 🔨 BREAK TESTS — each one restores a real bug and must be CAUGHT.
-- =====================================================================
out("11. break tests\n")

-- BREAK A — the wrapper drops the second return value.
do
    -- The anchor moved in 6.134.0 when the wrapper started keeping the tap
    -- object (rec.tap) so the switch could reach it. The BREAK is unchanged
    -- — drop the second return value — only the text around it is new.
    local broken = src:gsub("return a, b\n            end\n            rec%.tap = realNew",
                            "return a\n            end\n            rec.tap = realNew", 1)
    check("BREAK A changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    bchunk()({})
    local tapB = hs.eventtap.new({ TYPES.keyDown },
                                 function() return true, { "list" } end)
    local x, y = tapB.fn("ev")
    check("🔨 BREAK A caught: the event list is lost", y == nil, tostring(y))
    local _ = x
end

-- BREAK B — sort the report by average instead of by total, which puts
-- a once-run mouse tap above the tap that runs on every key.
do
    local broken = src:gsub("if a%.total ~= b%.total then return a%.total > b%.total end",
                            "if a.max ~= b.max then return a.max > b.max end", 1)
    check("BREAK B changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    bl.slowMs = 8
    local q = hs.eventtap.new({ TYPES.keyDown }, function() advance(1) return false end)
    local m = hs.eventtap.new({ TYPES.leftMouseDown }, function() advance(90) return false end)
    for _ = 1, 10 do q.fn("k") end
    m.fn("m")
    local rp = _G.lagReport()
    local firstRow = rp:match("max ms%s+slow\n(.-)\n") or ""
    check("🔨 BREAK B caught: the once-run mouse tap climbs to the top",
          firstRow:find("mouse only") ~= nil, firstRow)
end

-- BREAK C — drop the double-install guard.
do
    local broken = src:gsub("if hs%.eventtap%.__lagOriginalNew then",
                            "if false then", 1)
    check("BREAK C changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local first = bchunk()({})
    local afterFirst = hs.eventtap.new
    bchunk()({})
    check("🔨 BREAK C caught: a second install re-wraps the same function",
          hs.eventtap.new ~= afterFirst)
    -- And the damage it does: doubled timing on every keystroke.
    local dt = hs.eventtap.new({ TYPES.keyDown },
                               function() advance(10) return false end)
    dt.fn("k")
    check("🔨 BREAK C caught: the same keystroke is counted twice",
          #first.taps >= 1 and first.taps[#first.taps].calls == 1
          and first.taps[#first.taps].total > 0)
end

-- BREAK D — the stall list keeps the LAST instead of the worst.
-- 🚨 THE FIRST VERSION OF THIS BREAK DID NOT BREAK ANYTHING. It removed
-- only the "is this bigger than the smallest we kept" guard, and the
-- eviction below still replaced the SMALLEST entry — so the four-second
-- freeze survived and the check passed over a source that was, by then,
-- genuinely different. Restoring the real bug takes BOTH edits: accept
-- every stall, and evict slot 1 instead of the smallest. A break test
-- that a real regression walks through is worse than no break test,
-- which 6.130.0's OCR sentry had already demonstrated once.
do
    local broken = src:gsub("if late <= %(worstVal or 0%) then return end", "", 1)
                      :gsub("if worstVal == nil or s%.late < worstVal then",
                            "if worstVal == nil then", 1)
    check("BREAK D changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    bl.stallMs, bl.keepStalls = 100, 3
    local bb = bl.beat
    local function tk(ms) advance(ms) ; bb.fn() end
    tk(50)
    tk(4050)
    for _ = 1, 8 do tk(250) end
    local biggest2 = 0
    for _, s in ipairs(bl.stalls) do
        if s.late > biggest2 then biggest2 = s.late end
    end
    check("🔨 BREAK D caught: the four-second freeze was pushed out by "
          .. "eight small ones", biggest2 < 1000, biggest2)
end

-- BREAK E — the slow-line comparison goes strictly greater-than.
do
    local broken = src:gsub("if dt >= lag%.slowMs then", "if dt > lag.slowMs then", 1)
    check("BREAK E changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    bl.slowMs = 8
    local e = hs.eventtap.new({ TYPES.keyDown }, function() advance(8) return false end)
    e.fn("k")
    check("🔨 BREAK E caught: a call exactly on the line stops counting",
          bl.taps[1].slow == 0, bl.taps[1].slow)
end

-- BREAK F — the verdict stops excluding mouse-only taps.
do
    local broken = src:gsub("            if r%.keyboard then\n                keyCalls",
                            "            if true then\n                keyCalls", 1)
    check("BREAK F changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    bl.slowMs = 8
    local q = hs.eventtap.new({ TYPES.keyDown }, function() advance(1) return false end)
    local m = hs.eventtap.new({ TYPES.leftMouseDown }, function() advance(90) return false end)
    for _ = 1, 10 do q.fn("k") end
    m.fn("m")
    local rp = _G.lagReport()
    local v = rp:match("VERDICT[^\n]*") or ""
    check("🔨 BREAK F caught: the mouse tap is blamed for slow typing",
          v:find("90%.0ms") ~= nil, v)
end

-- BREAK G — stop skipping C frames, and every site becomes "[C]:-1".
-- This is not hypothetical: it is what the file did for two runs during
-- its own build, after the FIRST site bug was fixed. The fix moved the
-- wrong answer rather than removing it.
do
    local broken = src:gsub('if info%.what ~= "C" and src ~= SELF then',
                            "if src ~= SELF then", 1)
    check("BREAK G changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    check("🔨 BREAK G caught: the site is a C frame nobody can go and read",
          tostring(bl.taps[1].site):find("%[C%]") ~= nil, bl.taps[1].site)
end

-- BREAK H — resolve SELF through pcall, the original bug. SELF becomes
-- "[C]", matches no frame, and the walk returns on its first step: every
-- tap in the config is reported as created inside core/lag.lua.
do
    local broken = src:gsub("        local info = getInfo%(1, \"S\"%)\n"
                            .. "        if type%(info%) == \"table\" then "
                            .. "SELF = tostring%(info%.short_src%) end",
                            "        local _ok, info = pcall(getInfo, 1, \"S\")\n"
                            .. "        if type(info) == \"table\" then "
                            .. "SELF = tostring(info.short_src) end", 1)
    check("BREAK H changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    -- The chunk is named "broken-lag", so "this file" is [string "broken-lag"].
    check("🔨 BREAK H caught: the probe names ITSELF as the tap's creator",
          tostring(bl.taps[1].site):find("broken%-lag") ~= nil,
          bl.taps[1].site)
end

-- =====================================================================
out("12. the switch — inert, not stopped\n")
-- =====================================================================
-- 🚨 THIS SECTION IS THE ONE WITH TEETH IN 6.134.0. The switch is the
-- thing LL will actually press while their typing is broken, and its two
-- failure modes are both silent: a switch that EATS keystrokes makes the
-- problem look catastrophically worse, and a switch that STOPS the taps
-- gets quietly undone by the expander and autocorrect watchdogs thirty
-- seconds later — returning a confident wrong answer.
lag = freshProbe()
do
    local ran = 0
    local t1 = hs.eventtap.new({ TYPES.keyDown }, function()
        ran = ran + 1 ; advance(2) ; return true, { "replacement" }
    end)
    local t2 = hs.eventtap.new({ TYPES.keyDown }, function()
        ran = ran + 1 ; return false
    end)

    t1.fn("k") ; t2.fn("k")
    check("both taps ran before the switch", ran == 2, ran)
    check("the probe counted them", lag.taps[1].calls == 1)

    local msg = _G.lagTapsOff()
    check("lagTapsOff says how many taps went inert",
          msg:find("2 keyboard taps are INERT") ~= nil, msg)
    check("it warns that ⇪ stops working, because ⇪ IS a tap",
          msg:find("⇪ shortcuts will not work") ~= nil)
    check("the probe knows it is suspended", lag.isSuspended() == true)

    ran = 0
    local a, b = t1.fn("k")
    t2.fn("k")
    check("🚨 no module handler ran while inert", ran == 0, ran)
    check("🚨 the wrapper returns FALSE — the keystroke reaches the app",
          a == false, tostring(a))
    check("🚨 …and no replacement events are offered", b == nil, tostring(b))

    -- The watchdog-proof property, stated as a check rather than a hope.
    check("🚨 the tap object was NEVER stopped — a watchdog has nothing "
          .. "to re-arm", t1.stopCalls == 0 and t2.stopCalls == 0,
          tostring(t1.stopCalls) .. "/" .. tostring(t2.stopCalls))
    check("…and it is still marked started",
          MADE[1].started ~= false or MADE[1].stopCalls == 0)

    check("inert events are counted separately, not as calls",
          lag.taps[1].skipped == 1 and lag.taps[1].calls == 1,
          lag.taps[1].skipped .. "/" .. lag.taps[1].calls)

    -- The restore timer: the thing that stops the switch stranding you.
    check("a restore timer was armed", #AFTERS == 1, #AFTERS)
    check("…for the documented default of 90 seconds",
          AFTERS[1].secs == 90, AFTERS[1] and AFTERS[1].secs)
    check("…and the report says when it comes back",
          _G.lagReport():find("Back on at %d%d:%d%d:%d%d") ~= nil)

    local rep2 = _G.lagReport()
    check("🚨 the report SHOUTS that the taps are inert, at the top",
          rep2:find("EVERY TAP IS INERT RIGHT NOW") ~= nil)
    check("…and tells you the numbers stopped moving",
          rep2:find("stopped") ~= nil)
    check("the NEXT line tells you to type NOW, while it is off",
          rep2:find("type a paragraph NOW") ~= nil)

    -- 🚨 reset must NOT lift the suspension. reset is what you call at the
    -- start of a measured run; one that turned the taps back on would
    -- silently end the experiment it was called to begin.
    _G.lagReset()
    check("🚨 zeroing the counters does NOT lift the suspension",
          lag.isSuspended() == true)
    check("…and the counters really did zero", lag.taps[1].calls == 0)

    -- Firing the restore timer by hand is what 90 seconds of waiting
    -- would have done.
    AFTERS[1].fn()
    check("the restore timer put the taps back", lag.isSuspended() == false)
    ran = 0 ; t1.fn("k")
    check("…and the handlers run again", ran == 1, ran)
end

-- =====================================================================
out("13. mute, solo, and a number that does not move\n")
-- =====================================================================
lag = freshProbe()
do
    local ranA, ranB, ranC = 0, 0, 0
    local a = hs.eventtap.new({ TYPES.keyDown }, function() ranA = ranA + 1 return false end)
    local b = hs.eventtap.new({ TYPES.keyDown }, function() ranB = ranB + 1 advance(40) return false end)
    local c = hs.eventtap.new({ TYPES.keyDown }, function() ranC = ranC + 1 return false end)

    check("each tap carries its creation number",
          lag.taps[1].n == 1 and lag.taps[2].n == 2 and lag.taps[3].n == 3)

    _G.lagMute(2)
    ranA, ranB, ranC = 0, 0, 0
    a.fn("k") ; b.fn("k") ; c.fn("k")
    check("the muted tap does not run", ranB == 0, ranB)
    check("…and the others are untouched", ranA == 1 and ranC == 1)

    _G.lagUnmute(2)
    ranB = 0 ; b.fn("k")
    check("unmute puts it back", ranB == 1, ranB)

    _G.lagOnly(3)
    ranA, ranB, ranC = 0, 0, 0
    a.fn("k") ; b.fn("k") ; c.fn("k")
    check("solo leaves exactly one live", ranC == 1 and ranA == 0 and ranB == 0,
          ("%d/%d/%d"):format(ranA, ranB, ranC))

    _G.lagTapsOn()
    ranA, ranB, ranC = 0, 0, 0
    a.fn("k") ; b.fn("k") ; c.fn("k")
    check("lagTapsOn clears every mute, not just the suspension",
          ranA == 1 and ranB == 1 and ranC == 1)

    -- 🚨 THE NUMBER MUST NOT MOVE. The report SORTS by time spent, and b
    -- is by far the slowest — so if the # column were the sort position,
    -- b would print as #1 and typing _G.lagMute(1) would mute a. Naming
    -- the wrong tap is the one bug this whole numbering exists to avoid.
    for _ = 1, 5 do b.fn("k") end
    local rep = _G.lagReport()
    local firstRow = rep:match("max ms%s+slow\n(.-)\n") or ""
    check("the slowest tap sorts to the top", firstRow:find(lag.taps[2].site, 1, true) ~= nil,
          firstRow)
    check("🚨 …and still prints its CREATION number, not its sort position",
          firstRow:match("^%s*(%d+)") == "2", firstRow)

    -- Typed by someone who is annoyed, into a console. It must not throw.
    local bad = _G.lagMute(99)
    check("a number with no tap explains itself instead of throwing",
          bad:find("there is no tap #99") ~= nil, bad)
    check("…and says what the valid range is", bad:find("1 to 3") ~= nil, bad)
    check("a non-number is handled too",
          _G.lagOnly("banana"):find("# column") ~= nil)
end

-- =====================================================================
out("14. the timers, so 'not a tap' is not a dead end\n")
-- =====================================================================
lag = freshProbe()
do
    check("hs.timer.doEvery was wrapped",
          hs.timer.__lagOriginalDoEvery == stubDoEvery)
    check("hs.timer.new was wrapped too",
          hs.timer.__lagOriginalNew == stubTimerNew)
    -- 🚨 doAfter is deliberately NOT wrapped: it is the hot one-shot, and
    -- resolving a call site on every alert and every debounce would put a
    -- stack walk on a hot path in order to measure cost.
    check("🚨 hs.timer.doAfter is NOT wrapped — it is the hot one-shot",
          hs.timer.doAfter == stubDoAfter)

    -- The probe's own heartbeat must appear, under its OWN name.
    local hb
    for _, r in ipairs(lag.timerOrder) do
        if tostring(r.site):find("heartbeat") then hb = r end
    end
    check("🚨 the probe measures its own heartbeat", hb ~= nil)
    check("🚨 …and files it under core/lag.lua, not under whoever loaded it",
          hb and tostring(hb.site):find("core/lag%.lua") ~= nil,
          hb and hb.site)
    check("…at the interval it actually uses",
          hb and hb.interval == lag.stallEvery, hb and hb.interval)

    local fired = 0
    local slow = hs.timer.doEvery(0.5, function() fired = fired + 1 advance(10) end)
    check("the caller gets the real timer back", slow.secs == 0.5)
    slow.fn() ; slow.fn()
    check("the wrapped timer still runs its function", fired == 2, fired)

    local rec
    for _, r in ipairs(lag.timerOrder) do
        if tostring(r.site):find("test_lag%.lua:") then rec = r end
    end
    check("the timer is recorded against this file", rec ~= nil, rec and rec.site)
    check("both fires are counted", rec and rec.calls == 2, rec and rec.calls)
    check("the average is right", rec and math.abs(rec.total / rec.calls - 10) < 0.01,
          rec and rec.total)

    -- 🚨 BOUNDED BY CALL SITES, NOT BY CREATIONS. A timer made in a loop
    -- must not grow the table forever — the leak would be inside the tool
    -- whose job is finding leaks.
    local before = #lag.timerOrder
    for _ = 1, 20 do hs.timer.doEvery(1, function() end) end
    check("🚨 twenty timers from one line make ONE record",
          #lag.timerOrder == before + 1, #lag.timerOrder - before)
    local loopRec = lag.timerOrder[#lag.timerOrder]
    check("…and it counts how many were made", loopRec.made == 20, loopRec.made)

    -- 🚨 THE PROBE MUST BE RULE-OUT-ABLE. Its heartbeat is the one thing
    -- 6.131.0 added that runs 20 times a second forever, and the lag came
    -- back two versions later. Evidence from the accused is not enough.
    check("the heartbeat is running to start with",
          lag.beat ~= nil and lag.beat.stopped == false)
    local q = _G.lagQuiet()
    check("lagQuiet stops the probe's own heartbeat", lag.beat.stopped == true)
    check("…and says plainly that no stall is recorded until it is back",
          q:find("no stall is recorded") ~= nil, q)
    _G.lagQuiet(false)
    check("…and it starts again", lag.beat.stopped == false)

    local rep = _G.lagReport()
    check("the report has a TIMERS section", rep:find("TIMERS —") ~= nil)
    check("…naming the interval", rep:find("0%.50s") ~= nil)
    check("…and totalling the cost as a share of the one thread",
          rep:find("of the one thread") ~= nil)
    check("the report goes to the clipboard too", CLIP == rep, type(CLIP))
end

-- =====================================================================
out("15. break tests for the switch\n")
-- =====================================================================

-- BREAK I — the suspend branch returns TRUE. A switch that consumes
-- every keystroke, pressed by someone whose typing is already broken.
do
    local broken = src:gsub("if SUSPENDED or rec%.muted then\n"
                            .. "                    rec%.skipped = rec%.skipped %+ 1\n"
                            .. "                    return false\n",
                            "if SUSPENDED or rec.muted then\n"
                            .. "                    rec.skipped = rec.skipped + 1\n"
                            .. "                    return true\n", 1)
    check("BREAK I changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    local t = hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    bl.tapsOff(30)
    check("🔨 BREAK I caught: the switch EATS every keystroke it makes inert",
          t.fn("k") == true)
end

-- BREAK J — the switch does nothing at all, which is how a diagnostic
-- returns a confident wrong answer: taps look innocent because they
-- never actually went quiet.
do
    local broken = src:gsub("if SUSPENDED or rec%.muted then", "if false then", 1)
    check("BREAK J changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    local ran = 0
    local t = hs.eventtap.new({ TYPES.keyDown }, function() ran = ran + 1 return false end)
    bl.tapsOff(30)
    t.fn("k")
    check("🔨 BREAK J caught: the handler still runs with the switch on",
          ran == 1, ran)
end

-- BREAK K — reset lifts the suspension, silently ending the experiment
-- it was called to begin.
do
    local broken = src:gsub("lag%.stalls, lag%.stallCount = {}, 0",
                            "lag.stalls, lag.stallCount = {}, 0\n        SUSPENDED = false", 1)
    check("BREAK K changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    bl.tapsOff(30)
    bl.reset()
    check("🔨 BREAK K caught: zeroing the counters turned the taps back on",
          bl.isSuspended() == false)
end

-- BREAK L — timer records keyed by creation instead of by call site.
-- The table then grows for as long as Hammerspoon runs.
do
    local broken = src:gsub("local rec = lag%.timers%[site%]\n        if rec then",
                            "local rec = nil\n        if rec then", 1)
    check("BREAK L changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    local before = #bl.timerOrder
    for _ = 1, 20 do hs.timer.doEvery(1, function() end) end
    check("🔨 BREAK L caught: one line of code makes twenty records",
          #bl.timerOrder - before == 20, #bl.timerOrder - before)
end

-- BREAK M — the heartbeat loses its site override and files its own cost
-- under whoever loaded core/, which is how a tool exonerates itself.
do
    local broken = src:gsub('siteOverride = "core/lag%.lua %(the probe\'s own heartbeat%)"\n',
                            "", 1)
    check("BREAK M changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    local named = false
    for _, r in ipairs(bl.timerOrder) do
        if tostring(r.site):find("core/lag%.lua") then named = true end
    end
    check("🔨 BREAK M caught: the probe's own heartbeat is filed under "
          .. "somebody else's name", named == false)
end

-- =====================================================================
-- 16. the stronger dose — STOPPED, not merely inert
-- =====================================================================
-- The reason this section exists: lagTapsOff hollows the callbacks out
-- but leaves the taps installed, so it measures what our code DOES and
-- not what having taps COSTS. If the lag lives in the event-tap
-- machinery itself, the inert test reports no change and the honest
-- reading of that is "not the callbacks", not "not the taps". These
-- checks hold tapsGone to the harder promise.
out("16. the stronger dose — stopped, not inert\n")

do
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = chunk()({})

    -- Two keyboard taps and a mouse tap. The mouse tap must be left
    -- alone: this switch answers a question about typing.
    local k1 = hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    local k2 = hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    local m1 = hs.eventtap.new({ TYPES.leftMouseDown }, function() return false end)

    -- A tap that is ALREADY stopped when the test begins — screenshots'
    -- select-mode tap lives like this. Restoring must not start it.
    local k3 = hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    k3:stop()
    local k3stops = k3.stopCalls

    -- The watchdogs the real config runs, standing in for the module ones.
    local dog1 = { stopped = false }
    function dog1:stop()  self.stopped = true  ; return self end
    function dog1:start() self.stopped = false ; return self end
    local dog2 = { stopped = false }
    function dog2:stop()  self.stopped = true  ; return self end
    function dog2:start() self.stopped = false ; return self end
    _G.expanderWatchdog, _G.autocorrectWatchdog = dog1, dog2

    bl.tapsGone(30)

    check("the keyboard taps are actually STOPPED, not just inert",
          k1.started == false and k2.started == false)
    check("the mouse tap is left running — this is a question about typing",
          m1.started == true)
    check("a tap that was already stopped is not stopped again",
          k3.stopCalls == k3stops, k3.stopCalls)
    check("both watchdogs are held down, or they undo this in 30 seconds",
          dog1.stopped == true and dog2.stopped == true)
    check("the probe knows it is in the stronger state", bl.gone == true)
    check("belt and braces: a revived tap would still meet an inert callback",
          bl.isSuspended() == true)

    -- and the restore
    bl.tapsOn(true)
    check("the stopped keyboard taps are started again",
          k1.started == true and k2.started == true)
    check("the already-stopped tap STAYS stopped — restoring must not "
          .. "switch on what the config had deliberately switched off",
          k3.started == false)
    check("both watchdogs are watching again",
          dog1.stopped == false and dog2.stopped == false)
    check("and the probe is out of the stronger state", bl.gone ~= true)
    check("and out of the inert state too", bl.isSuspended() == false)

    _G.expanderWatchdog, _G.autocorrectWatchdog = nil, nil
end

do
    -- The restore timer, which is what stops this stranding you in a
    -- config whose ⇪ key does nothing.
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = chunk()({})
    hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    local before = #AFTERS
    bl.tapsGone(45)
    check("tapsGone arms a restore timer", #AFTERS > before)
    check("and it is armed for the seconds asked for",
          AFTERS[#AFTERS].secs == 45, AFTERS[#AFTERS].secs)
    AFTERS[#AFTERS].fn()
    check("and firing it puts the taps back", bl.gone ~= true)
end

do
    -- The report must say which state it is describing. A table of zeros
    -- read by someone who has forgotten they pressed the switch is how a
    -- diagnostic tells a lie without printing a false number.
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = chunk()({})
    hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    bl.tapsGone(30)
    local rp = _G.lagReport()
    check("the report announces the STOPPED state, not the inert one",
          rp:find("STOPPED RIGHT NOW") ~= nil)
    check("and it names the stronger state ahead of the weaker one",
          rp:find("EVERY TAP IS INERT RIGHT NOW") == nil)
    bl.tapsOn(true)
end

do
    -- Secure input: an OS-level fact about every tap at once, which no
    -- per-tap number can show and no amount of bisecting will find.
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = chunk()({})
    SECURE = true
    check("lag.secureInput reports it on", bl.secureInput() == true)
    local rp = _G.lagReport()
    check("and the report warns loudly", rp:find("SECURE INPUT IS ON") ~= nil)
    check("and says this config did not cause it",
          rp:find("Nothing in this config turns it on") ~= nil)
    SECURE = false
    check("lag.secureInput reports it off", bl.secureInput() == false)
    rp = _G.lagReport()
    check("and the all-clear is quiet, not a warning",
          rp:find("SECURE INPUT IS ON") == nil
          and rp:find("secure inp : off") ~= nil)
    SECURE = nil
    check("an hs that cannot answer gets nil, not a guess",
          bl.secureInput() == nil)
    rp = _G.lagReport()
    check("and then the report says nothing either way, rather than "
          .. "printing an all-clear it cannot support",
          rp:find("secure inp") == nil and rp:find("SECURE INPUT") == nil)
    SECURE = false
end

do
    -- The NEXT block is the part the user actually acts on, and the old
    -- wording was wrong in a way that mattered: "still slow? it is not a
    -- tap" is not what an INERT test can conclude.
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = chunk()({})
    hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    bl.tapsOff(30)
    local rp = _G.lagReport()
    check("the inert report no longer claims a null result clears the taps",
          rp:find("Still slow%? It is not a tap") == nil)
    check("it points at the stronger dose instead",
          rp:find("_G%.lagTapsGone") ~= nil)
    bl.tapsOn(true)
    rp = _G.lagReport()
    check("and the idle report offers the ladder in order",
          rp:find("_G%.lagTapsOff") ~= nil and rp:find("_G%.lagTapsGone") ~= nil)
end

-- =====================================================================
-- 🔨 17. break tests for the stronger dose
-- =====================================================================
out("17. break tests for the stronger dose\n")

-- BREAK N — the watchdogs are not held down. The taps come back inside
-- thirty seconds and the test quietly reports the opposite of the truth.
do
    local broken = src:gsub("local dogs = pauseWatchdogs%(%)",
                            "local dogs = 0", 1)
    check("BREAK N changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    local dog = { stopped = false }
    function dog:stop()  self.stopped = true  ; return self end
    function dog:start() self.stopped = false ; return self end
    _G.expanderWatchdog = dog
    bl.tapsGone(30)
    check("🔨 BREAK N caught: the watchdog is still running and will "
          .. "revive the taps mid-test", dog.stopped == false)
    _G.expanderWatchdog = nil
end

-- BREAK O — restore starts every tap rather than only the ones this
-- switch stopped, switching on what the config had switched off.
do
    local broken = src:gsub("if r%.wasRunning and r%.tap then",
                            "if r.tap then", 1)
    check("BREAK O changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    local idle = hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    idle:stop()
    bl.tapsGone(30)
    bl.tapsOn(true)
    check("🔨 BREAK O caught: a tap the config had deliberately stopped "
          .. "was switched on by the restore", idle.started == true)
end

-- BREAK P — tapsGone stops the taps but never sets lag.gone, so tapsOn
-- has nothing to restore and the taps stay dead after the window ends.
do
    local broken = src:gsub("lag%.gone = true", "lag.gone = false", 1)
    check("BREAK P changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    local k = hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    bl.tapsGone(30)
    bl.tapsOn(true)
    check("🔨 BREAK P caught: the taps were stopped and never came back",
          k.started == false)
end

-- BREAK Q — the report checks the weaker state first, so the stronger
-- one is never announced and the reader is told "inert" about a config
-- whose taps are gone.
do
    local broken = src:gsub("if lag%.gone then\n            %-%- Checked BEFORE isSuspended",
                            "if false then\n            -- Checked BEFORE isSuspended", 1)
    check("BREAK Q changed the source", broken ~= src)
    local bchunk = assert(load(broken, "broken-lag"))
    freshEventtap() ; freshTimers()
    hs.eventtap.__lagOriginalNew = nil
    local bl = bchunk()({})
    hs.eventtap.new({ TYPES.keyDown }, function() return false end)
    bl.tapsGone(30)
    local rp = _G.lagReport()
    check("🔨 BREAK Q caught: a stopped config is described as merely inert",
          rp:find("STOPPED RIGHT NOW") == nil
          and rp:find("EVERY TAP IS INERT RIGHT NOW") ~= nil)
    bl.tapsOn(true)
end

print = realPrint

-- ---- result ------------------------------------------------------------
out(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
os.exit(fail == 0 and 0 or 1)
