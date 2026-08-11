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

    local function makeSound(name)
        return { play = function() played[#played + 1] = name end }
    end

    _G.print = function() end  -- module prints on close; keep output clean

    _G.hs = {
        configdir = HS,
        sound = { getByName = function(name)
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
        chooser = { new = function() local c = {}
            local noop = function() return c end
            c.rows, c.width, c.bgDark, c.fgColor, c.subTextColor = noop, noop, noop, noop, noop
            c.placeholderText, c.choices, c.searchSubText = noop, noop, noop
            c.query, c.hide, c.cancel = noop, noop, noop
            c.show = function() chooserShown = true; return c end
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
        wasShown = function() return chooserShown end,
        -- Quit a watched app and let the module notice, exactly the way a
        -- real termination arrives: name is nil, so it must re-scan.
        quit = function(name)
            running[name] = nil
            _G.__watcherFn(nil, hs.application.watcher.terminated, nil)
            for i = 1, #afterFns do afterFns[i]() end
            for i = #afterFns, 1, -1 do table.remove(afterFns, i) end
        end,
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
    eq(h.everyFns[1].interval, 1, "the ping interval is one second")
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

-- 6. Every name bad = no crash (documented silent case) ---------------
--    Worth pinning even though it is the known gap: the failure mode
--    must stay "no sound", never "the popup throws and you get nothing
--    at all". Recorded so that if the notice ledger is ever wired in,
--    this test says what the behaviour used to be.
do
    local h = bootModule({ resolvable = {} })
    local okRun = pcall(function() h.quit("Shottr") end)
    ok(okRun, "an unresolvable sound list does not throw")
    ok(h.wasShown(), "the popup is still shown when no sound can be played")
    eq(#h.played, 0, "nothing plays (the documented silent case)")
    eq(#h.everyFns, 0, "and no pointless timer is left running")
end

-- run-tests.sh greps for this exact shape and adds its own "✅ <suite> —"
-- prefix, so print the counts BARE. Decorating them here prints the name
-- twice in the runner's output.
say(("\n%d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
