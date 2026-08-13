-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
-- Covers the App Monitor's PING SEQUENCE — the sounds played while the
-- popup waits for an answer.
--
-- WHY THIS FILE EXISTS: before 6.60.0 nothing in the suite executed a
-- single line of app_watcher's sound path. It was one constant and one
-- unconditional play(), so there was arguably nothing to test. 6.60.0
-- turned it into a resolve-and-filter loop plus a wrapping index, which
-- is real logic with real ways to be wrong: an off-by-one that skips the
-- first sound, a wrap that throws once the list runs out, a resolution
-- failure that takes the whole sequence down with it.
--
-- The tests DRIVE THE REAL MODULE — setup() against a stub hs, the real
-- application watcher callback, the real timer function — rather than
-- re-implementing the sequence here and checking my own copy. Doing the
-- latter is how a test passes while the shipped code is broken, which
-- has already happened more than once in this config's history.
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- The module prints when an app closes, so the harness silences print
-- while it runs. Test output therefore must NOT go through print — it
-- would be swallowed by the module's own gag and this file would report
-- nothing while appearing to succeed. (Which is exactly what it did the
-- first time it was run.)
local say = function(s) io.write(s, "\n") end

local pass, fail = 0, 0
local function ok(cond, label, detail)
    if cond then pass = pass + 1 else
        fail = fail + 1
        say("   ❌ " .. label .. (detail and ("\n      " .. detail) or ""))
    end
end
local function eq(got, want, label)
    ok(got == want, label, "expected: " .. tostring(want) .. "\n      got:      " .. tostring(got))
end

-- ── harness ──────────────────────────────────────────────────────────
-- Builds a stub hs, loads the REAL app_watcher.lua, and returns handles
-- for driving it. `soundNames` lets a test decide which names resolve,
-- so the typo-tolerance path can be exercised without editing the module.
local function bootModule(opts)
    opts = opts or {}
    local resolvable = opts.resolvable   -- nil = every name resolves
    local played     = {}                -- sound names, in play order
    local afterFns   = {}                -- hs.timer.doAfter callbacks
    local everyFns   = {}                -- hs.timer.doEvery callbacks
    local running    = { ["Shottr"] = true }
    local chooserShown = false
    local shownCount   = 0
    local lookups      = 0
    local chooserFn    = nil   -- the module's completion callback

    local function makeSound(name)
        return { play = function() played[#played + 1] = name end }
    end

    _G.print = function() end  -- module prints on close; keep output clean

    _G.hs = {
        configdir = HS,
        sound = { getByName = function(name)
            lookups = lookups + 1
            if resolvable and not resolvable[name] then return nil end
            return makeSound(name)
        end },
        timer = {
            doAfter = function(_, fn) afterFns[#afterFns + 1] = fn
                        return { stop = function() end } end,
            doEvery = function(interval, fn)
                        everyFns[#everyFns + 1] = { interval = interval, fn = fn }
                        return { stop = function() end } end,
            secondsSinceEpoch = function() return 100 end,
        },
        chooser = { new = function(fn) local c = {}
            chooserFn = fn
            local noop = function() return c end
            c.rows, c.width, c.bgDark, c.fgColor, c.subTextColor = noop, noop, noop, noop, noop
            c.placeholderText, c.choices, c.searchSubText = noop, noop, noop
            c.query, c.hide, c.cancel = noop, noop, noop
            c.show = function() chooserShown = true
                                shownCount = shownCount + 1; return c end
            return c end },
        geometry = { point = function(x, y) return { x = x, y = y } end },
        screen = { mainScreen = function() return { frame = function()
                     return { x = 0, y = 0, w = 1440, h = 900 } end } end },
        alert  = { show = function() end },
        notify = { new = function() return { send = function() end } end },
        application = {
            runningApplications = function()
                local out = {}
                for name, isUp in pairs(running) do
                    if isUp then out[#out + 1] = { name = function() return name end } end
                end
                return out
            end,
            get = function(name) return running[name] and {} or nil end,
            launchOrFocus = function() return true end,
            watcher = { new = function(fn)
                _G.__watcherFn = fn
                return { start = function(s) return s end, stop = function() end } end,
                terminated = "terminated", launched = "launched" },
        },
        fs = { attributes = function() return nil end },
        execute = function() return "", true end,
    }

    local core = {
        resolveBaseScreen = function() return hs.screen.mainScreen() end,
        provide = function() end,
        logsDir = "/tmp",
    }

    -- The notice ledger, recorded rather than stubbed away, so the tests
    -- can assert on what the module actually said.
    local recorded, told = {}, {}
    _G.notices = {
        record = function(kind, source, msg)
            recorded[#recorded + 1] = { kind = kind, source = source, msg = msg }
        end,
        tell = function(title, text, o)
            told[#told + 1] = { title = title, text = text, opts = o }
            return true
        end,
    }
    if opts.noNotices then _G.notices = nil end

    local chunk = assert(loadfile(HS .. "/modules/app_watcher.lua"))
    local M = chunk()
    M.setup(core)

    -- setup() defers the watcher install onto a 0.1s timer; fire it.
    for _, fn in ipairs(afterFns) do fn() end
    afterFns = {}

    return {
        played = played,
        everyFns = everyFns,
        afterFns = afterFns,
        recorded = recorded,
        told = told,
        warm = function() return M.warm and M.warm() end,
        hasWarm = function() return type(M.warm) == "function" end,
        wasShown = function() return chooserShown end,
        shownCount = function() return shownCount end,
        lookups = function() return lookups end,
        -- Quit a watched app and let the module notice, exactly the way a
        -- real termination arrives: name is nil, so it must re-scan.
        quit = function(name)
            running[name] = nil
            _G.__watcherFn(nil, hs.application.watcher.terminated, nil)
            for i = 1, #afterFns do afterFns[i]() end
            for i = #afterFns, 1, -1 do table.remove(afterFns, i) end
        end,
        -- 🚨 NEEDED FOR ANY "happens once" TEST. The module only opens a
        -- popup for an app it believes is RUNNING, so calling quit() twice
        -- in a row fires exactly one popup and any test counting repeats
        -- is measuring nothing. (Test 8 did precisely that until a
        -- mutation run showed it could not fail.) Bring the app back
        -- first, the way a relaunch would.
        relaunch = function(name)
            running[name] = true
            _G.__watcherFn(name, hs.application.watcher.launched, nil)
        end,
        -- 🚨 ALSO NEEDED FOR "happens once" TESTS. Only ONE popup is on
        -- screen at a time — further closes QUEUE behind it, by design.
        -- So a test that wants three popups must answer each one, exactly
        -- as pressing Esc would. Without this, relaunch+quit still yields
        -- a single popup and the test is measuring nothing again.
        dismiss = function() if chooserFn then chooserFn(nil) end end,
    }
end

-- Advances the repeating ping timer n times.
local function tick(h, n)
    for _ = 1, n do
        for _, t in ipairs(h.everyFns) do t.fn() end
    end
end

say("── APP WATCHER: the waiting ping ──")

-- 1. The popup sounds immediately, before any timer has fired ---------
do
    local h = bootModule()
    h.quit("Shottr")
    ok(h.wasShown(), "the popup is shown when a watched app quits")
    eq(#h.played, 1, "exactly one sound has played before the first tick")
    eq(h.played[1], "Hero", "the FIRST sound is the loudest one, not silence or entry two")
end

-- 2. Ten seconds, ten different sounds --------------------------------
do
    local h = bootModule()
    h.quit("Shottr")
    tick(h, 9)   -- the initial play + 9 ticks = the first ten seconds

    eq(#h.played, 10, "ten pings in the first ten seconds")

    local seen, dupe = {}, nil
    for _, name in ipairs(h.played) do
        if seen[name] then dupe = name end
        seen[name] = true
    end
    ok(dupe == nil, "all ten sounds in the first ten seconds are DIFFERENT",
       dupe and ("repeated: " .. dupe))

    eq(table.concat(h.played, ","),
       "Hero,Glass,Sosumi,Submarine,Basso,Ping,Funk,Morse,Bottle,Blow",
       "the sequence is the configured list, in order")
end

-- 3. It wraps rather than stopping ------------------------------------
--    This is the one that matters most: the popup can wait for hours, so
--    a sequence that ran out would silently undo the whole no-auto-
--    dismiss design.
do
    local h = bootModule()
    h.quit("Shottr")
    tick(h, 24)                       -- well past the end of a 10-item list

    eq(#h.played, 25, "the ping keeps sounding after the list is exhausted")
    eq(h.played[11], "Hero", "ping 11 wraps back to the first sound")
    eq(h.played[21], "Hero", "and wraps again on the next lap")
    eq(h.played[25], "Basso", "position within a later lap is still correct")
end

-- 4. The interval is one second ---------------------------------------
do
    local h = bootModule()
    h.quit("Shottr")
    eq(#h.everyFns, 1, "exactly one repeating timer is created")
    eq(h.everyFns[1].interval, 0.5, "the ping interval is half a second")
end

-- 5. One bad name costs one sound, not all of them --------------------
--    hs.sound.getByName returns nil for a name that does not exist. The
--    old single-constant version turned that into total silence; the
--    list version should drop the one and carry on.
do
    local every = { Hero = true, Glass = true, Sosumi = true, Submarine = true,
                    Basso = true, Ping = true, Funk = true, Morse = true,
                    Bottle = true, Blow = true }
    every.Sosumi = nil   -- pretend this one is misspelled
    local h = bootModule({ resolvable = every })
    h.quit("Shottr")
    tick(h, 8)

    eq(#h.played, 9, "the other nine sounds still play")
    for _, name in ipairs(h.played) do
        ok(name ~= "Sosumi", "the unresolvable name is never played")
    end
    eq(h.played[3], "Submarine", "the sequence closes the gap rather than pausing")
end

-- 6. Every name bad = no crash, and now: you are TOLD -----------------
do
    local h = bootModule({ resolvable = {} })
    local okRun = pcall(function() h.quit("Shottr") end)
    ok(okRun, "an unresolvable sound list does not throw")
    ok(h.wasShown(), "the popup is still shown when no sound can be played")
    eq(#h.played, 0, "nothing plays")
    eq(#h.everyFns, 0, "and no pointless timer is left running")

    -- 6.61.0: the whole point. A mute popup cannot draw you to itself,
    -- so total silence gets an ALERT, not just a ledger line.
    eq(#h.told, 1, "total silence raises exactly one alert")
    ok(h.told[1] and h.told[1].title:find("no sound"),
       "the alert says the App Monitor has no sound",
       h.told[1] and h.told[1].title)
    ok(h.told[1] and h.told[1].text:find("Hero"),
       "and names the spellings that failed, so it is actionable")
    ok(h.told[1] and h.told[1].opts and h.told[1].opts.key,
       "it carries a dedupe key, so it cannot nag on every app close")
end

-- 7. SOME names bad = ledger line, not an interruption -----------------
--    A partly-working list still makes noise, so it does not need to
--    interrupt; it needs to be findable in ⇪⇧D. Getting this backwards
--    (alerting every time) is how a safety net turns into something you
--    learn to dismiss without reading.
do
    local every = { Hero = true, Glass = true, Submarine = true, Basso = true,
                    Ping = true, Funk = true, Morse = true, Bottle = true,
                    Blow = true }   -- Sosumi missing
    local h = bootModule({ resolvable = every })
    h.quit("Shottr")

    eq(#h.told, 0, "a partly-working list does NOT interrupt with an alert")
    eq(#h.recorded, 1, "it records exactly one ledger entry")
    ok(h.recorded[1] and h.recorded[1].msg:find("Sosumi"),
       "naming the sound that failed", h.recorded[1] and h.recorded[1].msg)
    ok(h.recorded[1] and h.recorded[1].source == "app_watcher",
       "attributed to app_watcher so ⇪⇧D shows where it came from")
end

-- 8. Reported ONCE, not per popup --------------------------------------
--    Resolution is cached, so three app closes must not mean three
--    reports. This is also what stops a 1s ping path doing system
--    lookups forever.
do
    local h = bootModule({ resolvable = {} })
    h.quit("Shottr");                h.dismiss()
    h.relaunch("Shottr"); h.quit("Shottr"); h.dismiss()
    h.relaunch("Shottr"); h.quit("Shottr"); h.dismiss()
    -- First, prove the test is not vacuous: three closes must really have
    -- opened three popups. Without the relaunch between them the module
    -- ignores closes 2 and 3 and this whole case measures nothing.
    eq(h.shownCount(), 3, "three real closes opened three popups")
    -- THE ACTUAL CLAIM: resolution is cached, so ten lookups total rather
    -- than ten per popup. In the real ledger notices.tell's own key is
    -- what keeps the ALERT from repeating; the cache is what keeps the
    -- system calls from repeating, and only that is this module's job.
    eq(h.lookups(), 10, "sound names are looked up ONCE, not once per close")
end

-- 9. warm() reports at login, before anything has closed ---------------
do
    local h = bootModule({ resolvable = {} })
    ok(h.hasWarm(), "the module exposes warm()")
    eq(#h.told, 0, "nothing is reported before warm() runs")
    h.warm()
    eq(#h.told, 1, "warm() alone surfaces a broken sound list at login")
end

-- 10. A healthy list says NOTHING --------------------------------------
--     Silence has to mean "it worked", or the mechanism trains you to
--     ignore it.
do
    local h = bootModule()
    h.warm()
    h.quit("Shottr")
    eq(#h.told, 0, "a working sound list raises no alert")
    eq(#h.recorded, 0, "and writes no ledger entry")
end

-- 11. No ledger present = still no crash -------------------------------
--     notices is loaded before app_watcher in the real boot order, but
--     the module must not assume it: if the ledger itself failed to
--     load, App Monitor still has to work.
do
    local h = bootModule({ resolvable = {}, noNotices = true })
    local okRun = pcall(function() h.quit("Shottr") end)
    ok(okRun, "a missing notice ledger does not break the popup")
    ok(h.wasShown(), "the popup is still shown without the ledger")
end

-- run-tests.sh greps for this exact shape and adds its own "✅ <suite> —"
-- prefix, so print the counts BARE. Decorating them here prints the name
-- twice in the runner's output.
say(("\n%d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
