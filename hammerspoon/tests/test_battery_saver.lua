-- =====================================================================
-- test_battery_saver.lua — on battery, the config slows ITSELF down
-- =====================================================================
--     lua5.4 test_battery_saver.lua [/path/to/hammerspoon]
--
-- Executes modules/battery_saver.lua against a stubbed hs and drives the
-- REAL functions: the debounced flip to battery and back, exact-cadence
-- restore, the flap that must NOT flip anything, boot-on-battery with no
-- debounce, the hog caller-out (strikes, naming, the once-an-hour mute),
-- the forced console modes, and the desktop/no-API stand-down. The eco
-- registry it drives is EXTRACTED FROM init.lua's real source, not
-- re-typed here — so a drifted stub fails this suite, and the late-
-- registration rule is tested against the code that ships. Source
-- sentries then pin every shipped registration by name, and pin that
-- each one preserves running state across its rebuild (the lag-probe
-- contract).

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local function readAll(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- ---- the stub Mac ------------------------------------------------------
local POWER    = "AC Power"   -- what hs.battery.powerSource answers
local PCT      = 73
local AMPS     = -748
local MINS     = 250
local NOW      = 100000
local TIMERS   = {}           -- every doEvery, with a live running flag
local AFTERS   = {}           -- every doAfter, fired by hand
local TASKS    = {}           -- every hs.task the sampler starts
local NOTES    = {}           -- every notification sent
local PRINTED  = {}
local WATCH_FN = nil          -- the battery-watcher callback
local WATCHER_STARTS = 0
local NO_BATTERY_API = false

local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

hs = {
    timer = {
        secondsSinceEpoch = function() return NOW end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, isRunning = true }
            function t:stop()    self.isRunning = false end
            function t:start()   self.isRunning = true  end
            function t:running() return self.isRunning  end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            AFTERS[#AFTERS + 1] = t
            return t
        end,
    },
    battery = {
        powerSource     = function() return POWER end,
        percentage      = function() return PCT end,
        isCharging      = function() return false end,
        amperage        = function() return AMPS end,
        timeRemaining   = function() return MINS end,
        healthCondition = function() return "Good" end,
        watcher = {
            new = function(fn)
                if NO_BATTERY_API then return nil end
                WATCH_FN = fn
                return { start = function(s) WATCHER_STARTS = WATCHER_STARTS + 1 return s end,
                         stop  = function(s) return s end }
            end,
        },
    },
    task = {
        new = function(path, cb, args)
            local t = { path = path, cb = cb, args = args }
            function t:start() return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    notify = {
        new = function(_, opts)
            local n = { opts = opts }
            function n:send() NOTES[#NOTES + 1] = self.opts return self end
            return n
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

-- fire every pending doAfter once (the debounce)
local function firePending()
    for _, t in ipairs(AFTERS) do
        if not t.stopped and not t.done then t.done = true t.fn() end
    end
end

-- ---- the REAL registry, extracted from init.lua ------------------------
local initSrc = assert(readAll(HS .. "/init.lua"), "cannot read init.lua")
local stubBody = initSrc:match("_G%.eco%s*=%s*(%b{})")

local chunk = assert(loadfile(HS .. "/modules/battery_saver.lua"),
                     "cannot load modules/battery_saver.lua")

local function installRegistry()
    _G.eco = nil
    assert(load("_G.eco = " .. stubBody, "eco-stub"))()
end

local function boot()
    TIMERS, AFTERS, TASKS, NOTES, PRINTED = {}, {}, {}, {}, {}
    WATCH_FN, WATCHER_STARTS = nil, 0
    installRegistry()
    _G.batterySaver = nil
    local M = chunk()
    M.setup({})
    return _G.batterySaver, M
end

-- =====================================================================
out("── Battery Saver: on battery, the config slows itself down ──\n")

out("\n=== 1. The registry stub in init.lua is real, and drives late arrivals ===\n")
check("init.lua defines the eco registry (extraction found it)",
      stubBody ~= nil and #stubBody > 50, stubBody and #stubBody)
installRegistry()
check("register records a spec", (function()
    _G.eco.register("probe", { normal = 1, saver = 5, apply = function() end })
    return _G.eco.registry["probe"] ~= nil
end)())
check("🚨 a late registration while eco is ACTIVE gets the battery cadence "
      .. "applied at once (boot-on-battery, warm-phase modules)", (function()
    _G.eco.active = true
    local got = nil
    _G.eco.register("late", { normal = 4, saver = 12,
                              apply = function(s) got = s end })
    return got == 12, got
end)())
check("…and a late HOLD registration is held at once", (function()
    local held = nil
    _G.eco.register("lateHold", { hold = function(on) held = on end })
    return held == true, held
end)())
check("…but while INACTIVE a registration is recorded and left alone", (function()
    _G.eco.active = false
    local got = nil
    _G.eco.register("quiet", { normal = 4, saver = 12,
                               apply = function(s) got = s end })
    return got == nil, got
end)())

out("\n=== 2. Contract, and an AC boot does nothing at all ===\n")
local bs, M = boot()
check("the module is in the runs-itself family with a cheat sheet box",
      M.family == "auto" and M.cheatsheet
      and M.cheatsheet.title:find("BATTERY", 1, true) ~= nil)
check("setup survived and exposed the state table", bs ~= nil)
check("the battery watcher is wired and started", WATCH_FN ~= nil and WATCHER_STARTS == 1)
check("on AC nothing is applied and nothing recurs — zero periodic work",
      bs.applied == "ac" and #TIMERS == 0, #TIMERS)

out("\n=== 3. The flip to battery is debounced, then real ===\n")
local applied, heldState = {}, {}
_G.eco.register("fake poll", { normal = 0.5, saver = 2,
                               apply = function(s) applied[#applied + 1] = s end })
_G.eco.register("fake scan", { hold = function(on) heldState[#heldState + 1] = on end })
POWER = "Battery Power"
WATCH_FN()
check("the watcher event alone changes NOTHING — a debounce timer waits",
      #applied == 0 and #AFTERS == 1 and AFTERS[1].secs == bs.debounceSecs,
      #AFTERS > 0 and AFTERS[1].secs or "no timer")
firePending()
check("after the debounce holds, the battery cadence is applied",
      applied[#applied] == 2 and _G.eco.active == true, applied[#applied])
check("…and held work is held", heldState[#heldState] == true)
check("…and the hog sampler starts, plus one sample right away",
      bs.sampler ~= nil and #TASKS == 1, #TASKS)
check("…the sample is ps with an ARGUMENT ARRAY, never a shell string",
      TASKS[1].path == "/bin/ps" and TASKS[1].args[1] == "-Aceo",
      TASKS[1] and TASKS[1].path)
check("…and the console said so once", (function()
    for _, l in ipairs(PRINTED) do
        if l:find("On battery", 1, true) then return true end
    end
    return false
end)())

out("\n=== 4. A flap must flip nothing ===\n")
local before = #applied
POWER = "AC Power"
WATCH_FN()                       -- unplug noticed…
POWER = "Battery Power"
WATCH_FN()                       -- …replugged before the debounce ran — wait,
                                 -- this is the opposite flap: we are ON
                                 -- battery cadence, briefly saw AC, then
                                 -- battery again. Nothing may change.
firePending()
check("brief AC inside the debounce window: cadence untouched",
      #applied == before and _G.eco.active == true, #applied - before)

out("\n=== 5. The cord comes back: EXACT normal cadence, sampler off ===\n")
POWER = "AC Power"
WATCH_FN()
firePending()
check("normal cadence restored, exactly as registered",
      applied[#applied] == 0.5 and _G.eco.active == false, applied[#applied])
check("held work released", heldState[#heldState] == false)
check("the sampler is gone and its strikes forgotten",
      bs.sampler == nil and next(bs.strikes) == nil)

out("\n=== 6. The hog caller-out: strikes, one name, then quiet ===\n")
local rows = bs.parsePs("%CPU COMM\n 87.4 Chrome\n 61,0 Docker\n  3.2 Finder\n")
check("ps output parses past the header, dots and comma decimals both",
      #rows == 3 and rows[1].name == "Chrome" and rows[1].pct == 87.4
      and rows[2].pct == 61.0, #rows)
bs.note(rows)
check("one sample over the line is a strike, not a naming",
      #NOTES == 0 and bs.strikes["Chrome"] == 1 and bs.strikes["Docker"] == 1,
      #NOTES)
check("an app under the line never accrues", bs.strikes["Finder"] == nil)
bs.note(rows)
check("the second consecutive sample NAMES both hogs, once each",
      #NOTES == 2 and NOTES[1].title:find("Chrome", 1, true) ~= nil, #NOTES)
check("…saying the percentage and the key that ends it",
      NOTES[1].informativeText:find("87%%") ~= nil
      and NOTES[1].informativeText:find("⇪⇧;", 1, true) ~= nil,
      NOTES[1].informativeText)
bs.note(rows)
check("a third sample stays QUIET — named once per app per hour", #NOTES == 2, #NOTES)
bs.note(bs.parsePs(" 2.0 Chrome\n"))
check("dropping under the line resets the strikes…", bs.strikes["Chrome"] == nil)
bs.note(rows) bs.note(rows)
check("…but NOT the mute: sawing across the threshold is still one name an hour",
      #NOTES == 2, #NOTES)
NOW = NOW + 3601
bs.note(rows)
check("an hour later the same hog can be named again", #NOTES > 2, #NOTES)

out("\n=== 7. The console can force it, either way, immediately ===\n")
before = #applied
_G.ecoOn()
check("_G.ecoOn() applies the battery cadence NOW — a typed order is not a flap",
      applied[#applied] == 2 and _G.eco.active == true and #AFTERS == #AFTERS)
_G.ecoAuto()
check("_G.ecoAuto() hands control back to the power source (AC → full speed)",
      applied[#applied] == 0.5 and _G.eco.active == false, applied[#applied])
_G.ecoOff()
check("_G.ecoOff() while already at full speed changes nothing more",
      applied[#applied] == 0.5)
_G.ecoAuto()

out("\n=== 8. Reports answer, in both worlds ===\n")
local rep = _G.eco.report()
check("_G.eco() lists every registration with its two cadences",
      rep:find("fake poll", 1, true) ~= nil and rep:find("0.5s", 1, true) ~= nil
      and rep:find("2s", 1, true) ~= nil, rep)
check("…and the registry table stays callable as _G.eco() itself", (function()
    local ok, s = pcall(function() return _G.eco() end)
    return ok and type(s) == "string" and s:find("Battery Saver", 1, true) ~= nil
end)())
local br = _G.battReport()
check("_G.battReport() reads charge, source and drain from hs.battery",
      br:find("73%%") ~= nil and br:find("748 mA", 1, true) ~= nil
      and br:find("4h 10m", 1, true) ~= nil, br)

out("\n=== 9. Boot on battery applies at once — no debounce at boot ===\n")
POWER = "Battery Power"
local bs2 = boot()
check("booted straight into eco with no debounce timer pending",
      bs2.applied == "battery" and _G.eco.active == true and bs2.pending == nil)
POWER = "AC Power"

out("\n=== 10. A desktop, or no battery API: load, sleep, still answer ===\n")
NO_BATTERY_API = true
local bs3 = boot()
check("no watcher: the module stands down without a throw and says so",
      bs3.status:find("idle", 1, true) ~= nil, bs3.status)
check("…and _G.ecoOn() still works as a hand switch", (function()
    _G.ecoOn()
    return bs3.applied == "battery"
end)())
_G.ecoAuto()
check("…and _G.battReport() still answers", (function()
    local ok, s = pcall(_G.battReport)
    return ok and type(s) == "string"
end)())
NO_BATTERY_API = false

out("\n=== 11. Source sentries: the shipped registrations exist and are safe ===\n")
local shipped = {
    { file = "init.lua",                     name = "clipboard poll" },
    { file = "core/coexist.lua",             name = "injection watchdog" },
    { file = "modules/autocorrect.lua",      name = "autocorrect watchdog" },
    { file = "modules/text_expander.lua",    name = "expander watchdog" },
    { file = "modules/activity_tracker.lua", name = "activity poll" },
    { file = "modules/focus_mode.lua",       name = "focus detection" },
    { file = "modules/recent_docs.lua",      name = "recent docs boot scan" },
}
for _, s in ipairs(shipped) do
    local src = readAll(HS .. "/" .. s.file)
    local found = src and src:find('eco%.register%("' .. s.name .. '"') ~= nil
    check(s.file .. " registers '" .. s.name .. "'", found)
    if found and s.name ~= "recent docs boot scan" then
        -- every cadence registration must preserve running state across
        -- its rebuild — the lag probe holds watchdogs down BY NAME, and a
        -- rebuild that always starts would quietly revive them.
        local block = src:match('eco%.register%("' .. s.name .. '".-%}%)')
        check("…and '" .. s.name .. "' preserves running state across the rebuild",
              block ~= nil and block:find("running", 1, true) ~= nil)
    end
end
check("recent_docs defers the boot scan under the hold, and any real scan "
      .. "clears the deferral", (function()
    local src = readAll(HS .. "/modules/recent_docs.lua") or ""
    return src:find("ecoHold", 1, true) ~= nil
       and src:find("ecoDeferred = false", 1, true) ~= nil
end)())
check("the loader's BASE list ships the module", (function()
    local base = initSrc:match("local BASE = (%b{})") or ""
    return base:find('"battery_saver"', 1, true) ~= nil
end)())

print = realPrint
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do io.write("  ✗ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
