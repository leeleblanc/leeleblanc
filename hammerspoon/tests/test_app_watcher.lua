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
    local running    = { ["Shottr"] = true, ["Ghostty"] = true }
    local chooserShown = false
    local shownCount   = 0
    local lookups      = 0
    local chooserFn    = nil   -- the module's completion callback
    local chooserVisible = false -- what isVisible() reports (6.150.0)
    local lastPlaceholder = nil  -- which app the popup is asking about
    local notified   = {}        -- informativeText of every notification sent
    local escTap     = nil       -- the module's Esc eventtap (6.150.0)

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
            -- 6.150.0: stop() marks the timer, and tick() below skips
            -- marked ones — without this, "the alarm goes quiet after
            -- Esc" cannot be tested at all.
            doEvery = function(interval, fn)
                        local t = { interval = interval, fn = fn, stopped = false }
                        t.stop = function() t.stopped = true end
                        everyFns[#everyFns + 1] = t
                        return t end,
            secondsSinceEpoch = function() return 100 end,
        },
        chooser = { new = function(fn) local c = {}
            chooserFn = fn
            local noop = function() return c end
            c.rows, c.width, c.bgDark, c.fgColor, c.subTextColor = noop, noop, noop, noop, noop
            c.choices, c.searchSubText = noop, noop
            c.query, c.cancel = noop, noop
            c.placeholderText = function(_, s) lastPlaceholder = s; return c end
            c.isVisible = function() return chooserVisible end
            c.hide = function() chooserVisible = false; return c end
            c.show = function() chooserShown = true; chooserVisible = true
                                shownCount = shownCount + 1; return c end
            return c end },
        -- 6.150.0: the Esc watcher. The stub records start/stop so the
        -- "live only while a popup waits" claim is checkable, and keeps
        -- the callback so tests can press Esc the way the tap sees it.
        eventtap = {
            event = { types = { keyDown = 10 } },
            new = function(_, fn)
                local t = { started = false, fn = fn }
                t.start = function() t.started = true; return t end
                t.stop  = function() t.started = false; return t end
                escTap = t
                return t
            end,
        },
        keycodes = { map = { escape = 53 } },
        geometry = { point = function(x, y) return { x = x, y = y } end },
        screen = { mainScreen = function() return { frame = function()
                     return { x = 0, y = 0, w = 1440, h = 900 } end } end },
        alert  = { show = function() end },
        notify = { new = function(_, o)
            return { send = function()
                notified[#notified + 1] = (o and o.informativeText) or "?"
            end } end },
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
        -- 6.150.0: dismissing now IS the full Esc sequence — the tap sees
        -- the keypress while the popup is up, then macOS hides the
        -- chooser and calls the callback with nil. A bare chooserFn(nil)
        -- no longer dismisses anything: that is the click-off shape, and
        -- the module now answers it by bringing the popup back.
        dismiss = function()
            if escTap then escTap.fn({ getKeyCode = function() return 53 end }) end
            chooserVisible = false
            if chooserFn then chooserFn(nil) end
        end,
        -- The two halves of dismiss, separately, plus the other ways a
        -- popup can leave the screen — for the 6.150.0 tests.
        pressEsc = function()
            if escTap then escTap.fn({ getKeyCode = function() return 53 end }) end
        end,
        clickOff = function()      -- focus theft: macOS hides it, callback nil, NO Esc
            chooserVisible = false
            if chooserFn then chooserFn(nil) end
        end,
        choose = function(action)  -- a button press
            chooserVisible = false
            if chooserFn then chooserFn({ action = action }) end
        end,
        vanish = function() chooserVisible = false end,  -- hidden with NO callback at all
        fireAfters = function()    -- run pending doAfter timers (the re-show)
            for i = 1, #afterFns do afterFns[i]() end
            for i = #afterFns, 1, -1 do table.remove(afterFns, i) end
        end,
        visible    = function() return chooserVisible end,
        tapStarted = function() return escTap ~= nil and escTap.started end,
        placeholder = function() return lastPlaceholder or "" end,
        notified   = notified,
    }
end

-- Advances the repeating ping timer n times. Skips stopped timers, the
-- way real time would.
local function tick(h, n)
    for _ = 1, n do
        for _, t in ipairs(h.everyFns) do
            if not t.stopped then t.fn() end
        end
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

say("── APP WATCHER: only Esc dismisses (6.150.0) ──")

-- 12. A click elsewhere does NOT end the alarm ------------------------
--     macOS closes a chooser on focus loss and calls the callback with
--     nil — the same nil as Esc. Before 6.150.0 that stray click
--     silenced the alarm as if you had acknowledged it.
do
    local h = bootModule()
    h.quit("Shottr")
    eq(h.shownCount(), 1, "one popup up before the click")
    h.clickOff()
    eq(#h.notified, 0, "a click-off posts NO 'closed' notification — nothing was answered")
    eq(h.shownCount(), 1, "the re-show is scheduled, not synchronous (the click has to finish landing)")
    h.fireAfters()
    eq(h.shownCount(), 2, "the popup comes back on its own")
    ok(h.visible(), "and it is visible again")
    local before = #h.played
    tick(h, 2)
    eq(#h.played, before + 2, "the pings never stopped — the alarm ran straight through the click")
end

-- 13. Esc still dismisses, exactly as before --------------------------
do
    local h = bootModule()
    h.quit("Shottr")
    h.dismiss()   -- tap sees Esc while visible, then hide + nil callback
    eq(#h.notified, 1, "Esc posts exactly one notification")
    ok(h.notified[1]:find("Shottr"), "naming the app that closed", h.notified[1])
    h.fireAfters()
    eq(h.shownCount(), 1, "no re-show was scheduled — Esc is an answer")
    local before = #h.played
    tick(h, 3)
    eq(#h.played, before, "and the alarm is silent afterwards")
end

-- 14. The buttons still resolve ---------------------------------------
do
    local h = bootModule()
    h.quit("Shottr")
    h.choose("end")
    eq(#h.notified, 0, "End acknowledges without a notification, as before")
    h.fireAfters()
    eq(h.shownCount(), 1, "and no re-show fights the button")
end

-- 15. The Esc tap runs ONLY while a popup is waiting ------------------
--     This config has real history with keyboard taps and lag
--     (core/lag.lua exists because of it); a watcher that ran all day
--     would be a standing suspect. It must start with the popup and
--     stop with the answer.
do
    local h = bootModule()
    ok(not h.tapStarted(), "no popup, no tap")
    h.quit("Shottr")
    ok(h.tapStarted(), "popup up → tap running")
    h.dismiss()
    ok(not h.tapStarted(), "popup answered → tap stopped")
end

-- 16. An Esc pressed while the popup is HIDDEN does not count ---------
--     During the beat between a click-off and the re-show, an Esc is
--     aimed at whatever the user clicked — not at a popup they cannot
--     see. It must not silently resolve the question.
do
    local h = bootModule()
    h.quit("Shottr")
    h.vanish()            -- off screen, question still open
    h.pressEsc()          -- aimed at something else entirely
    h.clickOff()          -- the nil callback arrives
    eq(#h.notified, 0, "the hidden-popup Esc resolved nothing")
    h.fireAfters()
    eq(h.shownCount(), 2, "the popup still comes back")
end

-- 17. A popup hidden with NO callback is brought back by the ping -----
--     Some hide paths skip the chooser callback entirely. The alarm you
--     can hear and the popup you can answer must stay one thing, so the
--     ping doubles as the watchdog.
do
    local h = bootModule()
    h.quit("Shottr")
    h.vanish()            -- hidden, no callback, no Esc anywhere
    tick(h, 1)
    eq(h.shownCount(), 2, "the next ping re-presents the popup")
    ok(h.visible(), "and it reports visible again")
end

-- 18. Click-off does not skip the queue -------------------------------
--     Two apps close together; the second waits its turn. A click-off
--     on the first must re-ask about the FIRST — only a real answer
--     moves the queue along.
do
    local h = bootModule()
    h.quit("Shottr")
    h.quit("Ghostty")
    eq(h.shownCount(), 1, "the second close queues behind the first popup")
    h.clickOff(); h.fireAfters()
    ok(h.placeholder():find("Shottr"), "click-off re-asks about the SAME app", h.placeholder())
    h.dismiss()
    ok(h.placeholder():find("Ghostty"), "Esc moves on to the queued app", h.placeholder())
    eq(#h.notified, 1, "and only the Esc'd app got a notification")
end

-- 19. A SYNTHETIC Esc does not answer the alarm -----------------------
--     The expander and autocorrect inject keystrokes that reach an
--     eventtap looking exactly like fingers (the lint's
--     keyboard-tap-ignores-injection rule exists for this). While
--     _G.typingInjection() is up, an Esc must not count — otherwise an
--     expansion fired at the wrong moment silently acknowledges a
--     crashed app.
do
    local h = bootModule()
    _G.typingInjection = function() return true end
    h.quit("Shottr")
    h.pressEsc()          -- injected, not fingers
    h.clickOff()
    eq(#h.notified, 0, "the injected Esc resolved nothing")
    h.fireAfters()
    eq(h.shownCount(), 2, "the popup comes back — only real fingers can answer")
    _G.typingInjection = nil
end

-- run-tests.sh greps for this exact shape and adds its own "✅ <suite> —"
-- prefix, so print the counts BARE. Decorating them here prints the name
-- twice in the runner's output.
say(("\n%d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
