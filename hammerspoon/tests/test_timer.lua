-- =====================================================================
-- test_timer.lua — ⏱ say how long, in words
-- =====================================================================
-- LL: "add a simple timer I can launch using a shortcut key. I like
-- hyper+shift+t if that is not taken … I should be able to type a time in
-- natural language … like 24 hours and five minutes or 24h and 35m or 15
-- seconds or 15s. Using the shortcut key when it is visible, hides it.
-- When visible, hitting escape, stops the timer."
--
-- The grammar, the key's four answers, the Esc rule and the reload are
-- all PURE, so every one of his examples is proven with no Mac. The
-- functional half then drives the card, the hide, the alarm and the
-- restore against stubs that REFUSE the way macOS refuses (6.290.0).
local HS = arg[1] or "."
local pass, fail = 0, 0
local failures = {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
        failures[#failures + 1] = label
            .. (extra ~= nil and ("  — " .. tostring(extra)) or "") end
end
local function out(s) io.write(tostring(s), "\n") end
local function readAll(p)
    local f = io.open(p, "r") ; if not f then return nil end
    local s = f:read("*a") ; f:close() ; return s
end

local MOD = HS .. "/modules/timer.lua"

-- =====================================================================
out("\n=== 1. THE GRAMMAR — his own examples, word for word ===")
-- =====================================================================
local M = assert(loadfile(MOD))()
local MAX, DEF = 7 * 86400, 60

local function P(s) return M.parseDuration(s, MAX, DEF) end

-- 🚨 HIS FOUR, BY NAME. If any of these moves, the feature he asked for
-- is not the feature that shipped.
check("“15s” is fifteen seconds", P("15s") == 15, P("15s"))
check("“15 seconds” is fifteen seconds", P("15 seconds") == 15)
check("“24h and 35m” is 24 hours 35 minutes",
      P("24h and 35m") == 24 * 3600 + 35 * 60, P("24h and 35m"))
check("“24 hours and five minutes” — SPELLED OUT — is 24h 5m",
      P("24 hours and five minutes") == 24 * 3600 + 5 * 60,
      P("24 hours and five minutes"))

-- the rest of the grammar
check("“15 sec” works too", P("15 sec") == 15)
check("“5m30s” — glued, no spaces", P("5m30s") == 330, P("5m30s"))
check("“1h30m” — glued hours", P("1h30m") == 5400)
check("“twenty five minutes” — a compound ten", P("twenty five minutes") == 1500,
      P("twenty five minutes"))
check("“forty five seconds”", P("forty five seconds") == 45)
check("“half an hour” — “an” is NOT a 1 in front of “half”",
      P("half an hour") == 1800, P("half an hour"))
check("“an hour and a half” — the half belongs to the hour",
      P("an hour and a half") == 5400, P("an hour and a half"))
check("“two and a half hours”", P("two and a half hours") == 9000,
      P("two and a half hours"))
check("“a minute” is one minute", P("a minute") == 60)
check("“3 days”", P("3 days") == 3 * 86400)
check("“2d”", P("2d") == 2 * 86400)
check("“1 day 2 hours 3 minutes 4 seconds” — all four units at once",
      P("1 day 2 hours 3 minutes 4 seconds") == 86400 + 2*3600 + 3*60 + 4)
check("the separator may be a comma", P("24h, 35m") == 24*3600 + 35*60)
check("...or a hyphen (twenty-five)", P("twenty-five minutes") == 1500)
check("...or nothing at all", P("24h 35m") == 24*3600 + 35*60)
check("case does not matter", P("24H AND 35M") == 24*3600 + 35*60)

out("   -- the two assumptions, and both are SAID --")
do
    local secs, why = P("25")
    check("a bare number is minutes...", secs == 1500, secs)
    -- 🔑 6.297.0 — an assumption SHOWN before he presses Return is not a
    -- guess. A check that only asserted the number would pass with the
    -- sentence deleted, and then the box would silently decide for him.
    check("...and the reading SAYS it assumed minutes",
          type(why) == "string" and why:find("no unit", 1, true) ~= nil, why)
    -- and the unit is an ARGUMENT, so the gate moves it rather than
    -- asserting the shipped default twice over (6.239.0)
    check("...and the default unit is a parameter, not a constant",
          M.parseDuration("25", MAX, 1) == 25, M.parseDuration("25", MAX, 1))
end
do
    local secs, why = P("1h 30")
    check("a trailing number is the next unit down ...", secs == 5400, secs)
    check("...and the reading SAYS so", why:find("read as minute", 1, true) ~= nil, why)
end

out("   -- it refuses, and every refusal is a sentence he can act on --")
local function R(s, needle)
    local secs, why = P(s)
    return secs == nil and type(why) == "string"
           and (needle == nil or why:find(needle, 1, true) ~= nil), why
end
check("nothing typed is not a refusal — it says so", R("", "nothing typed"))
check("...and neither is whitespace", R("   ", "nothing typed"))
check("a non-string is nothing typed", R(nil, "nothing typed"))
check('“banana” is named back', R("banana", 'could not read "banana"'))
check("zero is “no time at all”", R("0", "no time at all"))
check("...and so is 0m", R("0m", "no time at all"))
check("over the cap is refused AND the cap is named",
      R("99 days", "longer than 7 days"))
-- 🚨 ":" IS REFUSED ON PURPOSE, and the refusal names BOTH readings. A
-- parse that guessed would be wrong half the time, silently (6.200.0).
check('“1:30” is refused, naming both readings', R("1:30", "1m30s"))
check("a unit with no number", R("h", 'no number in front'))
check("two numbers with no unit between them", R("5 7 minutes", "two numbers"))
check("a number after seconds has nothing below it", R("30s 5", "no unit below"))
check("the cap is a parameter too",
      M.parseDuration("2 hours", 3600, DEF) == nil, "2h under a 1h cap")

-- =====================================================================
out("\n=== 2. THE WORDS — the preview echoes HIM, not arithmetic ===")
-- =====================================================================
-- 🚨 THE FIXTURE THAT BITES: 24h and 35m is 1 day 35 minutes, and a
-- preview saying so reads as though the box had rewritten what he typed.
-- Every other duration agrees with both readings, so this is the input
-- where right and wrong must differ (6.230.0).
check("24h 35m reads as HOURS, not “1 day 35 minutes”",
      M.sayDuration(24*3600 + 35*60) == "24 hours 35 minutes",
      M.sayDuration(24*3600 + 35*60))
check("...and the parse's own reading says the same",
      select(2, P("24h and 35m")) == "24 hours 35 minutes")
check("a whole day IS a day", M.sayDuration(86400) == "1 day")
check("two days are days", M.sayDuration(2*86400) == "2 days")
check("three days and two hours are days", M.sayDuration(3*86400 + 2*3600)
      == "3 days 2 hours", M.sayDuration(3*86400 + 2*3600))
check("singulars are singular", M.sayDuration(61) == "1 minute 1 second",
      M.sayDuration(61))
check("zero says so", M.sayDuration(0) == "no time at all")
check("an infinity does not throw", M.sayDuration(math.huge) == "an unknown length")
check("...nor does a NaN", M.sayDuration(0/0) == "an unknown length")
check("...nor does a string", M.sayDuration("x") == "an unknown length")

-- =====================================================================
out("\n=== 3. THE DIGITS — and the guard pomodoro 6.70.0 paid for ===")
-- =====================================================================
check("under an hour is MM:SS", M.clockText(15) == "00:15", M.clockText(15))
check("...five minutes", M.clockText(300) == "05:00")
check("an hour brings the hours in", M.clockText(3600) == "1:00:00")
check("24h 35m", M.clockText(24*3600 + 35*60) == "24:35:00")
check("the cap is still legible", M.clockText(7*86400) == "168:00:00")
-- 🚨 string.format("%02d", math.huge) RAISES, inside a pcall'd tick, once
-- a second, for ever, with nobody ever seeing it. That cost a release.
check("INFINITY does not raise", M.clockText(math.huge) == "--:--")
check("...nor negative infinity", M.clockText(-math.huge) == "--:--")
check("...nor NaN", M.clockText(0/0) == "--:--")
check("...nor a string", M.clockText("x") == "--:--")
check("a negative is floored to zero", M.clockText(-5) == "00:00")

-- =====================================================================
out("\n=== 4. THE KEY — his three sentences, and the fourth they force ===")
-- =====================================================================
check("nothing running → ask how long", M.keyVerdict(false, false) == "ask")
check("running, card up → HIDE (his second sentence)",
      M.keyVerdict(true, true) == "hide")
check("running, card hidden → bring it back (forced by the other two)",
      M.keyVerdict(true, false) == "show")
check("...and hide SAYS the timer keeps running",
      select(2, M.keyVerdict(true, true)):find("keeps running", 1, true) ~= nil,
      select(2, M.keyVerdict(true, true)))
check("every answer carries a reason",
      select(2, M.keyVerdict(false, false)) ~= nil
      and select(2, M.keyVerdict(true, false)) ~= nil)

-- =====================================================================
out("\n=== 5. THE ESC RULE — narrow, and it explains itself ===")
-- =====================================================================
check("the card is not up → not ours", M.escWanted(false, false, 0, 10) == false)
check("the pointer is ON the card → ours", M.escWanted(true, true, 999, 10) == true)
check("just brought up → ours", M.escWanted(true, false, 3, 10) == true)
check("up, cold, pointer elsewhere → NOT ours (this is the rule)",
      M.escWanted(true, false, 30, 10) == false)
check("the boundary is inclusive", M.escWanted(true, false, 10, 10) == true)
check("...and one second past it is not", M.escWanted(true, false, 10.5, 10) == false)
check("a negative age (a clock that moved) is not a window",
      M.escWanted(true, false, -5, 10) == false)
check("a missing age is not a window", M.escWanted(true, false, nil, 10) == false)
-- 🔑 The card PRINTS this sentence, so it is what makes the rule
-- learnable rather than something he has to look up (6.377.0's ⌨️ rule).
check("when it is ours the reason is the line the card shows",
      select(2, M.escWanted(true, true, 0, 10)) == "esc stops it")
check("...and when it is not, it names the key that DOES work",
      select(2, M.escWanted(true, false, 99, 10)):find("⇪⎋", 1, true) ~= nil,
      select(2, M.escWanted(true, false, 99, 10)))

-- =====================================================================
out("\n=== 6. THE CARD'S OPACITY, and where it opens ===")
-- =====================================================================
check("faint most of the way", M.alphaFor(600, 60, false, false, 0.3, 1.0) == 0.3)
check("solid in the last minute", M.alphaFor(30, 60, false, false, 0.3, 1.0) == 1.0)
check("solid under the pointer", M.alphaFor(600, 60, true, false, 0.3, 1.0) == 1.0)
check("solid while it is shouting", M.alphaFor(600, 60, false, true, 0.3, 1.0) == 1.0)
check("a short timer is solid all the way through",
      M.alphaFor(15, 60, false, false, 0.3, 1.0) == 1.0)
check("an infinity does not pick the alert alpha",
      M.alphaFor(math.huge, 60, false, false, 0.3, 1.0) == 0.3)

out("   -- the two cards do not sit on top of each other --")
check("no pomodoro on screen → no offset", M.slotOffset(nil, 8, 6) == 0)
check("...and it says why",
      select(2, M.slotOffset(nil, 8, 6)):find("not on screen", 1, true) ~= nil)
check("a pomodoro above us → drop below it",
      M.slotOffset({ x = 0, y = 6, w = 204, h = 180 }, 8, 6) == 188,
      M.slotOffset({ x = 0, y = 6, w = 204, h = 180 }, 8, 6))
-- 🚨 the fixture that bites: a pomodoro DRAGGED to the bottom of the
-- screen must not push this card off the top of it.
check("a pomodoro already below us → no offset",
      M.slotOffset({ x = 0, y = 700, w = 204, h = 180 }, 8, 900) == 0,
      M.slotOffset({ x = 0, y = 700, w = 204, h = 180 }, 8, 900))
check("a frame with no height is not a frame",
      M.slotOffset({ x = 0, y = 6 }, 8, 6) == 0)

-- =====================================================================
out("\n=== 7. A DEADLINE THAT OUTLIVED THE CONFIG — three states ===")
-- =====================================================================
check("nothing stored → nothing was running",
      M.restoreVerdict(nil, 1000) == "none")
check("junk stored → nothing was running",
      M.restoreVerdict({ asked = "x" }, 1000) == "none")
check("a deadline in the future is still running",
      M.restoreVerdict({ endsAt = 1600, asked = "10 minutes" }, 1000) == "running")
check("...and it says how much is left",
      select(2, M.restoreVerdict({ endsAt = 1600 }, 1000)):find("10:00", 1, true) ~= nil,
      select(2, M.restoreVerdict({ endsAt = 1600 }, 1000)))
-- 🚨 THE MIDDLE STATE IS THE WHOLE REASON THIS IS A FUNCTION. An alarm
-- fired hours late is indistinguishable from one going off now.
check("a deadline that PASSED while we were down is “ended”, not “running”",
      M.restoreVerdict({ endsAt = 500, asked = "10 minutes" }, 1000) == "ended")
check("...and it says how long ago, and that we were not running",
      (function()
          local _, w = M.restoreVerdict({ endsAt = 500 }, 1000)
          return w:find("ago", 1, true) and w:find("not running", 1, true)
      end)())
check("no clock to compare against is not “ended”",
      M.restoreVerdict({ endsAt = 500 }, nil) == "none")

-- =====================================================================
out("\n=== 8. THE MODULE, DRIVEN — stubs that refuse like macOS does ===")
-- =====================================================================
local CLOCK, CANVASES, TIMERS, ALERTS, SAID, TOLD = 1000.5, {}, {}, {}, {}, {}
local BOUND, PROVIDED, ESCAPE, SETTINGS, CHOOSERS = {}, {}, {}, {}, {}
local MODALS, POPUPS, DEGRADES, PRINTED = {}, {}, {}, {}
local NO_CANVAS, SHOW_REFUSES, NO_TIMER, NO_SOUND, NO_SOUND_FILE = false, false, false, false, false
local MOUSE = { x = 5000, y = 5000 }     -- off the card unless a check moves it

local realPrint = print
hs = {
    timer = {
        secondsSinceEpoch = function() return CLOCK end,   -- 🕒 A FLOAT (6.282.0)
        doEvery = function(secs, fn)
            if NO_TIMER then error("no timer available", 0) end
            local t = { secs = secs, fn = fn, every = true, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doAfter = function(secs, fn)
            if NO_TIMER then error("no timer available", 0) end
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    alert  = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    mouse  = {
        -- 🔬 macOS NEVER answers nil here, so neither does this (6.318.0 —
        -- a stub that returned nil made an arm-time draw unreachable).
        absolutePosition = function() return { x = MOUSE.x, y = MOUSE.y } end,
    },
    screen = {
        mainScreen = function()
            return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
        end,
    },
    settings = {
        get = function(k) return SETTINGS[k] end,
        -- 🔬 6.290.0 — set(k, nil) DOES NOT DELETE here, because on a Mac
        -- it is not a reliable delete either: that is the whole reason
        -- hs.settings.clear exists and the reason mouse_follows.lua has
        -- used it since 6.160.2. A stub where writing nil worked would
        -- have certified a timer he stopped coming back on the next boot.
        set = function(k, v) if v ~= nil then SETTINGS[k] = v end end,
        clear = function(k) SETTINGS[k] = nil ; return true end,
    },
    sound = {
        getByName = function(n)
            if NO_SOUND then return nil end
            local s = { name = n, played = 0 }
            function s:volume(v) self.vol = v return self end
            function s:play() self.played = self.played + 1 return self end
            return s
        end,
        getByFile = function(f)
            if NO_SOUND_FILE then return nil end
            local s = { file = f, played = 0 }
            function s:volume(v) self.vol = v return self end
            function s:play() self.played = self.played + 1 return self end
            return s
        end,
    },
    canvas = {
        windowLevels = { overlay = 100, screenSaver = 1000 },
        new = function(rect)
            if NO_CANVAS then return nil end
            local c = { rect = rect, elements = {}, shown = false, deleted = false }
            function c:level(l) self.lvl = l return self end
            function c:behaviorAsLabels(b) self.behav = b return self end
            function c:replaceElements(e) self.elements = e return self end
            function c:alpha(a) if a == nil then return self.a end self.a = a return self end
            function c:frame(f) if f == nil then return self.rect end self.rect = f return self end
            function c:topLeft(p) self.rect.x, self.rect.y = p.x, p.y return self end
            function c:show() self.shown = true return self end
            function c:delete() self.deleted = true return self end
            CANVASES[#CANVASES + 1] = c
            return c
        end,
    },
    hotkey = {
        modal = {
            new = function()
                local m = { entered = 0, exited = 0, inside = false, binds = {} }
                function m:bind(mods, key, fn)
                    self.binds[(#mods > 0 and table.concat(mods, "+") .. "+" or "") .. key] = fn
                    return self
                end
                function m:enter() self.entered = self.entered + 1 ; self.inside = true return self end
                function m:exit()  self.exited  = self.exited + 1  ; self.inside = false return self end
                MODALS[#MODALS + 1] = m
                return m
            end,
        },
    },
    chooser = {
        new = function(fn)
            local c = { onPick = fn, rows = {}, q = "", sel = 0, shown = false }
            function c:width(w) self.w = w return self end
            function c:rows(n) if type(n) == "number" then self.nrows = n end return self end
            function c:searchSubText(b) self.sst = b return self end
            function c:queryChangedCallback(f) self.qcb = f return self end
            -- 🔬 :choices() DROPS THE SELECTION on a real hs.chooser
            -- (6.227.0). A stub that KEPT it made the re-select
            -- unreachable, so the row ⏎ takes could be the wrong one.
            function c:choices(r) self.rows = r ; self.sel = 0 return self end
            function c:selectedRow(n) if n == nil then return self.sel end self.sel = n return self end
            function c:query(q) if q == nil then return self.q end self.q = q return self end
            function c:placeholderText(p) self.ph = p return self end
            function c:show() self.shown = true return self end
            function c:hide() self.shown = false return self end
            -- type a query the way a person does: every keystroke
            function c:type(s)
                self.q = s
                if self.qcb then self.qcb(s) end
                return self
            end
            function c:enter()      -- ⏎ on whatever is selected
                local row = self.rows[self.sel] or self.rows[1]
                if self.onPick then self.onPick(row) end
                return self
            end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
    configdir = "/tmp",
    fs = { attributes = function() return nil end },
}
_G.showCanvasSafely = function(c, who)
    if SHOW_REFUSES then return false end
    c:show() ; return true
end
_G.panelLevel  = function() return 100 end
_G.claimEscape = function(name, prio, active, handle)
    ESCAPE[name] = { priority = prio, active = active, handle = handle }
    return true
end
_G.clampToScreen = function(p) return p end
_G.diag = {
    say  = function(who, m) SAID[#SAID + 1] = tostring(who) .. ": " .. tostring(m) end,
    warn = function(who, m) SAID[#SAID + 1] = "WARN " .. tostring(who) .. ": " .. tostring(m) end,
}
_G.notices = {
    tell = function(title, body, o) TOLD[#TOLD + 1] = tostring(title) .. " " .. tostring(body) end,
}
_G.movablePanels = {}

local function freshCore(withDegrade)
    return {
        provide = function(n, f) PROVIDED[n] = f end,
        call    = function(n, ...) if PROVIDED[n] then return PROVIDED[n](...) end end,
        -- 🔬 6.278.0 — a core stub with NO degrade makes every module
        -- take its no-door fallback, so the door is never exercised.
        -- Present by default, and ABSENT in one check on purpose.
        degrade = withDegrade ~= false
                  and function(tool, why)
                        DEGRADES[#DEGRADES + 1] = tostring(tool) .. ": " .. tostring(why)
                        return false, why
                      end or nil,
        resolveBaseScreen = function() return hs.screen.mainScreen() end,
        showPopup = function(c) POPUPS[#POPUPS + 1] = c ; c:show() end,
        hyperAddShortcut = function(mods, key, fn, src)
            BOUND[(#mods > 0 and table.concat(mods, "+") .. "+" or "") .. key] =
                { fn = fn, src = src }
        end,
    }
end

local tm
-- 📣 print is ours for the whole run: _G.timerReport() and the Console
-- line at zero both use it, and out() writes with io.write so the
-- suite's own output is untouched.
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    PRINTED[#PRINTED + 1] = table.concat(parts, "\t")
end
local function report()
    PRINTED = {}
    _G.timerReport()
    return table.concat(PRINTED, " || ")
end

local function boot(opts)
    opts = opts or {}
    -- 🕒 keepClock: the restore checks advance the clock to stand for
    -- downtime, and a boot that reset it would wipe the one fact they
    -- are about.
    if not opts.keepClock then CLOCK = 1000.5 end
    CANVASES, TIMERS, ALERTS, SAID, TOLD = {}, {}, {}, {}, {}
    BOUND, PROVIDED, ESCAPE, CHOOSERS, MODALS, POPUPS, DEGRADES = {}, {}, {}, {}, {}, {}, {}
    PRINTED = {}
    if opts.keepSettings ~= true then SETTINGS = {} end
    NO_CANVAS   = opts.noCanvas   == true
    SHOW_REFUSES = opts.showRefuses == true
    NO_TIMER    = opts.noTimer    == true
    NO_SOUND    = opts.noSound    == true
    NO_SOUND_FILE = opts.noSoundFile == true
    MOUSE = { x = 5000, y = 5000 }
    _G.movablePanels = {}
    _G.pomodoro = opts.pomodoro
    M = assert(loadfile(MOD))()
    M.setup(freshCore(opts.degrade))
    tm = M.tm
    if opts.warm then M.warm(freshCore(opts.degrade)) end
    return tm
end
local function ticks(n)
    for _ = 1, (n or 1) do
        CLOCK = CLOCK + 1
        for _, t in ipairs(TIMERS) do
            if t.every and not t.stopped and t.secs == 1 then t.fn() end
        end
    end
end
local function hoverTicks(n)
    for _ = 1, (n or 1) do
        for _, t in ipairs(TIMERS) do
            if t.every and not t.stopped and t.secs == tm.hoverSecs then t.fn() end
        end
    end
end
local function liveCanvas()
    for i = #CANVASES, 1, -1 do
        if not CANVASES[i].deleted then return CANVASES[i] end
    end
end
local function cardText()
    local c = liveCanvas()
    if not c then return "" end
    local bits = {}
    for _, e in ipairs(c.elements or {}) do
        if e.text then bits[#bits + 1] = tostring(e.text) end
    end
    return table.concat(bits, " | ")
end
local function joined(t) return table.concat(t, " || ") end

boot()
check("the module loads and publishes itself", tm ~= nil and _G.timer == tm)
check("⇪⇧T is the key it binds — HIS key, by name",
      BOUND["shift+t"] ~= nil and BOUND["shift+t"].src == "timer",
      BOUND["shift+t"] and BOUND["shift+t"].src)
check("...and it claims nothing else", (function()
    local n = 0 ; for _ in pairs(BOUND) do n = n + 1 end ; return n == 1, n
end)())
check("the four services are published",
      PROVIDED["timer.start"] and PROVIDED["timer.stop"]
      and PROVIDED["timer.ask"] and PROVIDED["timer.report"])
check("_G.timerReport() exists", type(_G.timerReport) == "function")
-- 6.232.0 — a panel absent from this table is movable by NO means
check("the card is listed for ⌘-drag", (function()
    for _, p in ipairs(_G.movablePanels) do if p.name == "timer" then return true end end
end)())
-- ⎋ the router claim, which is the only route to a HIDDEN timer
check("it claims Esc in the router", ESCAPE["timer"] ~= nil)
check("...with NO hard-coded priority, so coexist decides the order",
      ESCAPE["timer"].priority == nil)
check("...and core/coexist.lua declares a rung for it, so the boot does "
      .. "not print “not in _G.escapePriorities” and run on the fallback 50",
      (readAll(HS .. "/core/coexist.lua") or ""):find("timer%s*=%s*101") ~= nil)

out("   -- the box --")
boot()
BOUND["shift+t"].fn()
check("the key with nothing running opens the box", #CHOOSERS == 1)
check("...through core.showPopup, never a bare :show() (6.127.0)",
      #POPUPS == 1 and POPUPS[1] == CHOOSERS[1])
check("...and the box is registered for the Esc router",
      _G.choosers and _G.choosers.timer == CHOOSERS[1])
check("the placeholder teaches the grammar",
      (CHOOSERS[1].ph or ""):find("24h and 35m", 1, true) ~= nil, CHOOSERS[1].ph)
do
    local c = CHOOSERS[1]
    c:type("24h and 35m")
    check("typing re-renders the preview row",
          (c.rows[1].text or ""):find("24 hours 35 minutes", 1, true) ~= nil,
          c.rows[1].text)
    check("...and the row carries the seconds ⏎ will start",
          c.rows[1].secs == 24*3600 + 35*60)
    -- 🚨 :choices() dropped the selection, so ⏎ would land on nothing
    check("...and the row is RE-SELECTED after :choices() dropped it",
          c.sel == 1, c.sel)
    c:type("banana")
    check("a reading it cannot make says why, in the row",
          (c.rows[1].text or ""):find('could not read "banana"', 1, true) ~= nil,
          c.rows[1].text)
    check("...and that row cannot be started", c.rows[1].secs == nil)
    check("...and the subtext still offers the forms that work",
          (c.rows[1].subText or ""):find("15s", 1, true) ~= nil)
    c:type("25")
    check("the bare-number assumption is VISIBLE before ⏎",
          (c.rows[1].text or ""):find("no unit", 1, true) ~= nil, c.rows[1].text)
end

out("   -- ⏎ starts it, and the card is real --")
boot()
BOUND["shift+t"].fn()
CHOOSERS[1]:type("5m")
CHOOSERS[1]:enter()
check("⏎ on a readable row starts the timer", tm.state ~= nil)
check("...for the length the row said", tm.state.secs == 300)
check("...the card is on screen", liveCanvas() ~= nil and liveCanvas().shown)
check("...it shows the countdown", cardText():find("05:00", 1, true) ~= nil, cardText())
check("...and the words he typed", cardText():find("5 minutes", 1, true) ~= nil, cardText())
check("...and a ticker is HELD on the state (an unreferenced hs.timer is "
      .. "collected and never fires — 6.196.1)",
      tm.state.ticker ~= nil and tm.state.ticker.secs == 1)
check("...and the hover poll is held too", tm.state.hoverer ~= nil)
ticks(60)
check("a minute later the card has counted down",
      cardText():find("04:00", 1, true) ~= nil, cardText())
check("...and it has not fired", tm.state.fired ~= true)

out("   -- ⏎ on an unreadable row starts NOTHING --")
boot()
BOUND["shift+t"].fn()
CHOOSERS[1]:type("banana")
CHOOSERS[1]:enter()
check("a row with no length starts nothing", tm.state == nil)
check("...and no card was drawn", liveCanvas() == nil)

-- =====================================================================
out("\n=== 9. HIDE IS NOT STOP — his two sentences, apart ===")
-- =====================================================================
boot()
tm.start(600, "10 minutes")
local firstCanvas = liveCanvas()
check("the card is up", firstCanvas ~= nil)
BOUND["shift+t"].fn()
check("the key PUTS THE CARD AWAY", liveCanvas() == nil and firstCanvas.deleted)
check("...and the timer IS STILL RUNNING", tm.state ~= nil and tm.state.fired ~= true)
check("...its ticker is still alive — that is what reaches zero",
      tm.state.ticker ~= nil and tm.state.ticker.stopped == false)
check("...the hover poll went with the card (nothing to point at)",
      tm.state.hoverer == nil)
ticks(60)
check("...and it counted down while it was invisible",
      math.abs((tm.state.endsAt - CLOCK) - 540) < 1.5, tm.state.endsAt - CLOCK)
BOUND["shift+t"].fn()
check("the key BRINGS IT BACK", liveCanvas() ~= nil and liveCanvas().shown)
check("...showing the time that is actually left, not the time he asked for",
      cardText():find("09:00", 1, true) ~= nil, cardText())
check("...and the same timer, never a second one", tm.state.secs == 600)

out("   -- and the report tells the two apart --")
boot()
tm.start(600, "10 minutes")
local rep1 = report()
check("with the card up the report says so",
      rep1:find("the card is up", 1, true) ~= nil, rep1)
tm.hide("test")
local rep2 = report()
-- 🔎 6.196.1 — "hidden and counting" and "nothing is running" must not
-- read the same, because one of them is a timer he has forgotten about.
check("with the card hidden the report SHOUTS that it is still counting",
      rep2:find("THE CARD IS HIDDEN", 1, true) ~= nil, rep2)
tm.stop("test")
local rep3 = report()
check("...and with nothing running it says that instead",
      rep3:find("running: nothing", 1, true) ~= nil, rep3)

-- =====================================================================
out("\n=== 10. ESC — the modal is entered ONLY when it is ours ===")
-- =====================================================================
boot()
tm.start(600, "10 minutes")
local modal = MODALS[1]
check("a modal was built, once", #MODALS == 1 and modal ~= nil)
check("esc is the only key it binds", modal.binds["escape"] ~= nil
      and (function() local n = 0 ; for _ in pairs(modal.binds) do n = n + 1 end ; return n == 1 end)())
check("it is entered as the card appears — he just pressed the key",
      modal.inside == true)
check("...and the card's last line SAYS esc stops it",
      cardText():find("esc stops it", 1, true) ~= nil, cardText())
CLOCK = CLOCK + tm.escSecs + 2
ticks(1)
-- 🚨 THE WHOLE POINT: bare Esc goes back to his apps. A binding that
-- stayed would swallow Esc for up to seven days (see the module header).
check("once the window closes the modal is EXITED", modal.inside == false)
check("...and the card's last line now names ⇪⎋ instead",
      cardText():find("⇪⎋", 1, true) ~= nil, cardText())
check("...and it no longer promises esc",
      cardText():find("esc stops it", 1, true) == nil, cardText())
-- the pointer brings it back
local fr = liveCanvas():frame()
MOUSE = { x = fr.x + 5, y = fr.y + 5 }
hoverTicks(1)
check("the pointer ON the card takes esc back", modal.inside == true)
check("...and the line says so again", cardText():find("esc stops it", 1, true) ~= nil)
MOUSE = { x = 5000, y = 5000 }
hoverTicks(1)
check("the pointer leaving gives it back to his apps", modal.inside == false)

out("   -- and esc, when it is ours, STOPS it --")
boot()
tm.start(600, "10 minutes")
MODALS[1].binds["escape"]()
check("esc stops the timer", tm.state == nil)
check("...and takes the card with it", liveCanvas() == nil)
check("...and the modal is left exited, never stuck inside",
      MODALS[1].inside == false)
check("...and it is counted as an esc stop, apart from any other stop",
      tm.counts.escStops == 1 and tm.counts.stopped == 1)

out("   -- ⇪⎋ reaches a HIDDEN timer, which bare esc cannot --")
boot()
tm.start(600, "10 minutes")
tm.hide("test")
check("the router's claim is ACTIVE even with no card on screen — this is "
      .. "the only way to stop a timer you have put away",
      ESCAPE["timer"].active() == true)
ESCAPE["timer"].handle()
check("...and it stops it", tm.state == nil)
boot()
check("with nothing running the claim stands down, so Esc closes whatever "
      .. "else is open exactly as before", ESCAPE["timer"].active() == false)

-- =====================================================================
out("\n=== 11. ZERO — the announcement IS the feature ===")
-- =====================================================================
boot()
tm.start(3, "3 seconds")
ticks(4)
check("it fires at zero", tm.state ~= nil and tm.state.fired == true)
check("the card shouts TIME UP", cardText():find("TIME UP", 1, true) ~= nil, cardText())
check("...and reads 0:00, never a negative", cardText():find("0:00", 1, true) ~= nil)
check("an alert names the length", (function()
    for _, a in ipairs(ALERTS) do if a:find("TIME UP") and a:find("3 seconds") then return true end end
end)(), joined(ALERTS))
check("a Console line is written too",
      joined(PRINTED):find("TIME UP", 1, true) ~= nil, joined(PRINTED))
check("...and it is the module's own line, not the report's",
      joined(PRINTED):find("⏱ Timer: TIME UP", 1, true) ~= nil, joined(PRINTED))
-- 🔔 6.278.0 — a notification HOLDS through Focus and lands when it ends.
-- A 24-hour timer is exactly the one that fires during a meeting.
check("a notification is sent, which survives Focus", #TOLD >= 1, joined(TOLD))
check("...naming the length", joined(TOLD):find("3 seconds", 1, true) ~= nil)
check("it blinks", tm.state.flasher ~= nil)
check("the tone was played", tm.sound and tm.sound.played >= 1, tm.sound and tm.sound.played)
check("...and only fires ONCE no matter how long the ticker runs", (function()
    local before = tm.counts.fired
    ticks(10)
    return tm.counts.fired == before, tm.counts.fired
end)())
-- 🚨 tm.fire is PUBLISHED on the module table, so "called twice" is a
-- real contract and not a hypothetical: a second announcement would
-- alert, notify and play the tone all over again. The ticker's own
-- guard means no mutation inside fire() could be killed through it, so
-- this drives the published door directly (6.273.0).
check("...and calling fire() again announces nothing a second time",
      (function()
          local alerts, told, fired = #ALERTS, #TOLD, tm.counts.fired
          tm.fire()
          return #ALERTS == alerts and #TOLD == told
                 and tm.counts.fired == fired,
                 #ALERTS - alerts .. " alert(s), " .. (#TOLD - told) .. " told"
      end)())

out("   -- it fires even with the card hidden, and SHOWS ITSELF --")
boot()
tm.start(3, "3 seconds")
tm.hide("test")
check("the card is away", liveCanvas() == nil)
ticks(4)
check("a hidden timer still reaches zero", tm.state.fired == true)
-- 🚨 This is what makes hiding safe. Without it, a timer he put away
-- would end in silence with nothing on screen.
check("...and the card PUTS ITSELF BACK to say so",
      liveCanvas() ~= nil and liveCanvas().shown
      and cardText():find("TIME UP", 1, true) ~= nil, cardText())
check("...and the alarm owns esc again, bounded, from the moment it went off",
      MODALS[1].inside == true)

-- 🚨 6.379.0 — THE RE-STAMP, driven where it is the only thing that can
-- matter: the card ALREADY UP and its Esc window long closed. The hidden
-- case above cannot see it, because showing the card stamps shownAt
-- anyway — so without this the line was unkillable (6.273.0).
boot()
tm.start(30, "30 seconds")
CLOCK = CLOCK + tm.escSecs + 2
ticks(1)
check("with the card up and cold, esc has gone back to his apps",
      MODALS[1].inside == false)
for _ = 1, 40 do
    ticks(1)
    if tm.state.fired then break end
end
check("...the alarm goes off", tm.state.fired == true)
-- 🚨 IN THE SAME INSTANT, not on the next tick: the first second of an
-- alarm is when the key gets pressed.
check("...and it takes esc back THAT SECOND, so the key he reaches for "
      .. "answers it", MODALS[1].inside == true)
check("...and the card says so", cardText():find("esc stops it", 1, true) ~= nil,
      cardText())
CLOCK = CLOCK + tm.escSecs + 2
ticks(1)
check("...and it gives it back again afterwards — an alarm nobody is "
      .. "there to answer must not hold the key for ever",
      MODALS[1].inside == false)

out("   -- the alarm stays until it is answered --")
boot()
tm.start(3, "3 seconds")
ticks(4)
check("it is still up a long time later", (function()
    ticks(600)
    return liveCanvas() ~= nil and not liveCanvas().deleted
end)())
check("...and the key ANSWERS it rather than hiding an alarm that is "
      .. "going off", (function()
    BOUND["shift+t"].fn()
    return tm.state == nil and liveCanvas() == nil
end)())

out("   -- the tone has three states, never two (6.196.1) --")
boot({ noSound = true })
tm.start(3, "x")
check("no sound BY NAME falls back to the file",
      tm.sound ~= false and tm.sound ~= nil, tostring(tm.sound))
boot({ noSound = true, noSoundFile = true })
tm.start(3, "x")
check("neither available is FALSE, not nil — “looked and found none”",
      tm.sound == false)
local repS = report()
check("...and the report says SILENT, with the reason",
      repS:find("SILENT", 1, true) ~= nil, repS)
ticks(4)
check("...and it still flashes and still alerts, with no sound",
      tm.state.fired == true and #ALERTS >= 1)
boot()
local repN = report()
check("before any keypress the tone reads “not looked for yet”, which is "
      .. "not the same as silent",
      repN:find("not looked for yet", 1, true) ~= nil, repN)

-- =====================================================================
out("\n=== 12. IT DEGRADES — and the timer outlives the card ===")
-- =====================================================================
boot({ noCanvas = true })
local ok = tm.start(600, "10 minutes")
-- 🚨 A countdown with no card is worth more than no countdown, and the
-- announcement at zero does not need the card to exist.
check("macOS refusing to MAKE the card does not stop the timer",
      tm.state ~= nil and tm.state.ticker ~= nil)
check("...and it takes the 🔔 door rather than failing silently",
      #DEGRADES >= 1 and joined(DEGRADES):find("Timer", 1, true) ~= nil,
      joined(DEGRADES))
check("...and the degrade SAYS the timer is running anyway",
      joined(DEGRADES):find("running anyway", 1, true) ~= nil, joined(DEGRADES))
ticks(601)
check("...and it still announces at zero, with no card to draw on",
      tm.counts.fired == 1 and #ALERTS >= 1, joined(ALERTS))

-- 🚨 6.265.0, FIFTH TIME — "created, wired, REFUSED TO SHOW" is a
-- different shape from "new threw", and on a beta OS it is the one this
-- config keeps meeting. Driven apart.
boot({ showRefuses = true })
tm.start(600, "10 minutes")
check("macOS refusing to SHOW the card is a different failure, handled",
      tm.state ~= nil and tm.state.ticker ~= nil)
check("...the refused canvas is TORN DOWN, never left orphaned (6.265.0)",
      (function()
          for _, c in ipairs(CANVASES) do if not c.deleted then return false end end
          return #CANVASES >= 1
      end)())
check("...and the message tells him to press the key again",
      joined(DEGRADES):find("again", 1, true) ~= nil, joined(DEGRADES))

-- 🚨 NO TICKER IS THE ONE FAILURE THAT MUST STOP EVERYTHING: a timer
-- that cannot count is not a timer, and reporting it as running is worse
-- than refusing.
boot({ noTimer = true })
local ok2, why2 = tm.start(600, "10 minutes")
check("a Mac that will not give us a ticker starts NOTHING",
      ok2 == false and tm.state == nil, tostring(ok2) .. " " .. tostring(why2))
check("...and says so loudly", joined(DEGRADES):find("cannot", 1, true) ~= nil,
      joined(DEGRADES))
check("...and counts it, so the report can say it happened",
      tm.counts.noBelt == 1)
check("...and leaves no card behind", liveCanvas() == nil)

-- 🔬 6.278.0 — with NO core.degrade the module must still speak, through
-- its own fallback. A suite whose core stub carries degrade can never
-- prove this, which is how that hole stayed open in three modules.
boot({ noCanvas = true, degrade = false })
tm.start(600, "10 minutes")
check("with no core.degrade it alerts on its own rather than going quiet",
      #ALERTS >= 1 and joined(ALERTS):find("Timer", 1, true) ~= nil, joined(ALERTS))

-- =====================================================================
out("\n=== 13. A RELOAD DOES NOT LOSE A LONG TIMER ===")
-- =====================================================================
boot()
tm.start(3600, "1 hour")
check("starting writes the deadline down", (function()
    local s = SETTINGS[tm.settingsKey]
    return type(s) == "table" and s.endsAt == tm.state.endsAt and s.asked == "1 hour"
end)(), tostring(SETTINGS[tm.settingsKey]))
tm.hide("test")
check("...and hiding does not forget it — it is still running",
      SETTINGS[tm.settingsKey] ~= nil)
tm.stop("test")
check("stopping forgets it", SETTINGS[tm.settingsKey] == nil)

out("   -- and warm brings it back --")
boot()
tm.start(3600, "1 hour")
local deadline = tm.state.endsAt
CLOCK = CLOCK + 1200                      -- twenty minutes of downtime
boot({ keepSettings = true, keepClock = true, warm = true })
check("a timer that was still running comes back", tm.state ~= nil)
check("...with the time that is actually left, not the length he asked for",
      math.abs((tm.state.endsAt - CLOCK) - 2400) < 2, tm.state.endsAt - CLOCK)
check("...and it is counted as a restore", tm.counts.restored == 1)
check("...and the card is up showing it",
      cardText():find("40:00", 1, true) ~= nil, cardText())

out("   -- a deadline that passed while we were down is SAID, not fired --")
boot()
tm.start(60, "1 minute")
CLOCK = CLOCK + 7200                      -- two hours later
boot({ keepSettings = true, keepClock = true, warm = true })
-- 🚨 An alarm going off two hours late is indistinguishable from one
-- going off now. This is the state the restore exists to separate.
check("nothing is started", tm.state == nil)
check("...it is not counted as a restore", tm.counts.restored == 0)
check("...it is counted as having ended while away", tm.counts.endedAway == 1)
check("...he is TOLD, naming what it was",
      joined(ALERTS):find("ended while", 1, true) ~= nil
      and joined(ALERTS):find("1 minute", 1, true) ~= nil, joined(ALERTS))
check("...and the stale deadline is cleared, so it cannot say it twice",
      SETTINGS[tm.settingsKey] == nil)
local repR = report()
check("...and the report carries the reason",
      repR:find("not running", 1, true) ~= nil, repR)

boot({ warm = true })
check("nothing stored → warm does nothing and says nothing on screen",
      tm.state == nil and #ALERTS == 0, joined(ALERTS))

-- 🚨 THE READ IS IN WARM, NEVER setup: anything a module reads from disk
-- at setup is a tax every other module and every key pays (6.267.0).
do
    local src = readAll(MOD) or ""
    local setupAt = src:find("function M.setup", 1, true)
    local warmAt  = src:find("function M.warm", 1, true)
    local getAt   = src:find("hs.settings.get", 1, true)
    check("hs.settings.get is read in warm, not in setup",
          setupAt and warmAt and getAt and getAt > warmAt,
          tostring(setupAt) .. "/" .. tostring(warmAt) .. "/" .. tostring(getAt))
    -- 🚨 6.308.0 — TWO M.warm in one file loses one of them, silently,
    -- because setup() runs after the file is loaded.
    local code = src:gsub("%-%-[^\n]*", "")
    check("...and the stripper really read something (6.313.0)", #code > 3000, #code)
    local n = 0
    for _ in code:gmatch("function M%.warm") do n = n + 1 end
    for _ in code:gmatch("M%.warm%s*=") do n = n + 1 end
    check("...and M.warm is given a body exactly ONCE — two of them and "
          .. "setup() destroys the one that registers (6.308.0)", n == 1, n)
end

-- =====================================================================
out("\n=== 14. WHERE IT OPENS, and the pomodoro it must not cover ===")
-- =====================================================================
boot()
tm.start(600, "x")
local fr = liveCanvas():frame()
check("it opens in the top-right corner under the clock",
      fr.x == 1440 - tm.width - tm.marginX and fr.y == tm.marginY,
      fr.x .. "," .. fr.y)
boot({ pomodoro = { state = { canvas = {
    frame = function() return { x = 1200, y = 6, w = 204, h = 180 } end } } } })
tm.start(600, "x")
local fr2 = liveCanvas():frame()
check("with the pomodoro's card up it drops BELOW it rather than over it",
      fr2.y == tm.marginY + 180 + tm.slotGap, fr2.y)
local repP = report()
check("...and the report says which rule placed it",
      repP:find("below the pomodoro", 1, true) ~= nil, repP)
-- the read is nil-guarded: a pomodoro that is loaded but not running,
-- and a pomodoro that is not loaded at all, are both just "no offset"
boot({ pomodoro = { state = nil } })
tm.start(600, "x")
check("a loaded-but-idle pomodoro is no offset",
      liveCanvas():frame().y == tm.marginY)
boot()
tm.pos = { x = 100, y = 400 }
tm.start(600, "x")
check("a position he dragged it to wins", (function()
    local f = liveCanvas():frame()
    return f.x == 100 and f.y == 400, f.x .. "," .. f.y
end)())

-- =====================================================================
out("\n=== 15. SOURCE SENTRIES — the rules a functional check cannot see ===")
-- =====================================================================
do
    local src = readAll(MOD) or ""
    check("the sentries read a file that is really there", #src > 4000, #src)
    -- 🚨 the card's Esc line must be READ from the one decision function,
    -- never typed, or it can promise a key that is not live
    check("the card's hint comes from escState(), not a literal",
          src:find("local _, hint = escState()", 1, true) ~= nil)
    check("...and escState is the ONLY caller of the decision function, so "
          .. "the card and the modal cannot disagree about it", (function()
        local body = src:sub(src:find("function M.setup", 1, true) or 1)
        local n = 0
        for _ in body:gmatch("M%.escWanted%(") do n = n + 1 end
        return n == 1, n
    end)())
    -- 🚨 one literal for the key, every surface (6.311.0)
    check("the key label is BUILT from the binding, not typed",
          src:find("function tm.keyLabel", 1, true) ~= nil)
    check("...and no visible string types ⇪⇧T by hand outside a comment",
          (function()
              -- TRAILING comments too: a line-start stripper leaves
              -- `tm.key = "t"  -- ⇪⇧T …` in the haystack and the sentry
              -- then reports its own comment (6.303.0's caveat does not
              -- bite here — this module passes no "--" argument).
              local code = src:gsub("%-%-[^\n]*", "")
              if #code < 3000 then return false, "stripped to nothing" end
              -- the cheatsheet table is DATA read before setup runs, so
              -- its rows are literals on purpose and are skipped here
              local body = code:sub(code:find("function M.setup", 1, true) or 1)
              return body:find("⇪⇧T", 1, true) == nil
          end)())
    -- 🚨 showCanvasSafely, never a bare :show() (6.66.3)
    check("the card goes through showCanvasSafely",
          src:find("_G.showCanvasSafely", 1, true) ~= nil)
    check("...and core.showPopup places the box (6.127.0)",
          src:find("core.showPopup", 1, true) ~= nil)
    -- 🚨 6.303.0 / 6.308.0 — `a and b or c` cannot carry a false b
    check("no `and nil or` in the file (6.308.0's trap)",
          src:find("and nil or", 1, true) == nil)
    -- 🚨 6.282.0 — a clock formatted by hand is a report that can RAISE
    check("no os.date over a stored clock outside the report's own line",
          (function()
              local n = 0
              for _ in src:gmatch("os%.date") do n = n + 1 end
              return n <= 1, n
          end)())
    -- every timer this module arms must be HELD in a slot (6.196.1)
    check("every repeating timer is ASSIGNED to a slot, never armed bare "
          .. "— an unreferenced hs.timer is collected and never fires, so "
          .. "the assignment IS the mechanism (6.196.1)", (function()
        local armed, held = 0, 0
        for _ in src:gmatch("hs%.timer%.doEvery%(") do armed = armed + 1 end
        for _ in src:gmatch("=%s*hs%.timer%.doEvery%(") do held = held + 1 end
        return armed > 0 and armed == held, armed .. " armed, " .. held .. " held"
    end)())
    -- 6.263.0 — no box this config draws asks macOS to spell-check it.
    -- This module draws no text input of its own, so the rule is met by
    -- having none; asserted so that adding one is a decision.
    check("it draws no text input, so macOS's correction panel cannot "
          .. "reach it (6.263.0)",
          src:find("<textarea", 1, true) == nil and src:find("<input", 1, true) == nil)
end

-- the shipped cheat sheet must name the key and the Esc rule
do
    local rows = {}
    for _, e in ipairs(M.cheatsheet.entries or {}) do
        rows[#rows + 1] = tostring(e[1]) .. " " .. tostring(e[2])
    end
    local j = table.concat(rows, " || ")
    check("the card names ⇪⇧T", j:find("⇪⇧T", 1, true) ~= nil)
    -- ⌨️ 6.377.0 — a key named only as a glyph is a key that has not been
    -- named. The row says where T is on the keyboard.
    check("...and says where that key IS, in words", j:find("letter T", 1, true) ~= nil, j)
    check("...and that the key hides it without stopping it",
          j:find("PUTS IT AWAY", 1, true) ~= nil)
    check("...and both ways to stop it", j:find("esc", 1, true) ~= nil
          and j:find("⇪⎋", 1, true) ~= nil)
    check("...and the report command", j:find("_G.timerReport()", 1, true) ~= nil)
    check("the title names the key too",
          (M.cheatsheet.title or ""):find("⇪⇧T", 1, true) ~= nil)
end

-- =====================================================================
out("\n=== 16. THE CONTRACT ===")
-- =====================================================================
check("name/order/family are declared",
      M.name == "timer" and type(M.order) == "number" and M.family == "time")
check("it loads AFTER the pomodoro it reads the frame of",
      M.order > 13.65, M.order)
check("setup and warm are both functions",
      type(M.setup) == "function" and type(M.warm) == "function")
check("the loader list names it", (readAll(HS .. "/init.lua") or "")
      :find('"timer",', 1, true) ~= nil)
check("the gate's own list names its suite (6.367.0)",
      (readAll(HS .. "/tools/run-tests.sh") or ""):find("test_timer", 1, true) ~= nil)
check("the pure answers live on M, so build-feature-list.lua reads a "
      .. "table that is true before setup has run (6.311.0)",
      type(M.parseDuration) == "function" and type(M.keyVerdict) == "function"
      and type(M.escWanted) == "function" and type(M.restoreVerdict) == "function")

out("")
for _, f in ipairs(failures) do out("   ❌ " .. f) end
out(("\n%d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
