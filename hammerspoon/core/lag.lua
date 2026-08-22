-- =====================================================================
-- CORE: LAG PROBE — which tap is eating the keystroke? 6.131.0
-- =====================================================================
-- LL: "Something is running perhaps Hammerspoon to cause my typing to
-- lag. Once I quit Hammerspoon, the lag went away. Seems related, but
-- nothing to report from the console."
--
-- Quitting Hammerspoon fixing it is a real measurement, and it narrows
-- the problem to this config. Nothing narrower was available, because
-- the Console only prints what something CHOSE to print, and a slow
-- function is not an error — it prints nothing at all. That is the gap
-- this file closes: it does not wait to be told, it measures.
--
-- ---------------------------------------------------------------------
-- ⌨️ WHY A SLOW TAP IS FELT AS LAGGY TYPING
-- ---------------------------------------------------------------------
-- An hs.eventtap is not a listener. It sits IN THE PATH of the event.
-- macOS hands your keystroke to the tap, and the character does not
-- reach the app you are typing into until the callback returns. Every
-- tap in this config is on the same one thread, in series, so the delay
-- on each key is the SUM of all of them.
--
-- This config has eight or nine keyboard taps running at any time — the
-- hyper key, the expander, autocorrect, the editor-picker gesture, the
-- key caster when it is on, and more. Each is fast. "Fast" is a claim
-- nobody had ever checked, and eight unchecked claims is exactly the
-- shape of a problem that appears gradually and has no error to show.
--
-- ---------------------------------------------------------------------
-- 🎯 SO IT WRAPS hs.eventtap.new ITSELF, ONCE, BEFORE ANYTHING RUNS
-- ---------------------------------------------------------------------
-- Every tap in this config — core/ and modules/ alike — is born from
-- one function. Wrapping that function instruments all of them at once
-- and needs no cooperation from any module: nothing has to register,
-- nothing has to be edited, and a tap added in a future version is
-- measured the day it is written without anybody remembering to.
--
-- debug.getinfo names the CALLER, so each tap is reported as the file
-- and line that created it — "text_expander.lua:1133" — rather than as
-- an anonymous function nobody can place.
--
-- 🚨 THIS FILE MUST LOAD BEFORE THE FIRST TAP IS CREATED, and that is
-- the one thing about it that can silently half-work. It is loaded in
-- init.lua §0.3, immediately after the console gate: before
-- core/hyper_key.lua, before core/cheatsheet.lua, before the module
-- loader. A tap created earlier than this file is NOT measured and
-- would not appear in the report — so the report says how many it
-- wrapped and when it installed, rather than presenting a list whose
-- completeness you would have to take on trust.
--
-- ---------------------------------------------------------------------
-- ⏱ THE MEASUREMENT IS ALWAYS ON, AND THAT IS THE POINT
-- ---------------------------------------------------------------------
-- The obvious design is a switch: turn the probe on, reproduce the
-- problem, read the numbers. It is the wrong one here. Lag that comes
-- and goes is not reproducible on demand — by the time you have
-- noticed it, decided it is real, found the Console and turned a probe
-- on, the thing that caused it may be over. The evidence has to already
-- exist at the moment you think to look.
--
-- So it costs what it costs, always: two clock reads and four
-- arithmetic operations per event. hs.timer.absoluteTime is
-- mach_absolute_time — tens of nanoseconds. Against a callback budget
-- measured in milliseconds that is roughly one part in ten thousand.
--
-- 🚨 AND THERE IS NO pcall IN THE HOT PATH, deliberately. A probe whose
-- job is to measure per-keystroke cost must not add a per-keystroke
-- pcall to do it. Instead the clock function is resolved ONCE at install
-- time and the accounting only ever does arithmetic on numbers this file
-- produced — there is nothing in it that can throw. The callback itself
-- is called directly, so an error inside a module's handler propagates
-- exactly as it did before this file existed, to that module's own
-- guard, and the wrapper adds no new behaviour to the failure path.
--
-- ---------------------------------------------------------------------
-- 📉 THE SECOND HALF: STALLS, WHICH TAPS CANNOT EXPLAIN
-- ---------------------------------------------------------------------
-- Not every freeze is a tap. Hammerspoon runs on ONE thread, and
-- anything slow on it — a synchronous shell command, a folder read that
-- reaches OneDrive, a big JSON write — stops the keyboard just as
-- effectively, without any tap being slow at all.
--
-- A timer set to fire every 50ms cannot fire while that thread is busy,
-- so how LATE it fires is a direct measurement of how long the thread
-- was blocked. The probe keeps the worst dozen, with the time of day and
-- what app was in front, because a stall at 14:32 in Excel and a stall
-- every time you press ⇪4 are different problems.
--
-- ⚠️ SOME STALLS ARE HONEST. Opening a picker that scans a folder blocks
-- the thread on purpose, and will show up here. A stall is a fact about
-- the thread, not an accusation — the report says so rather than
-- implying every entry is a bug.
--
-- ---------------------------------------------------------------------
-- 🔌 6.134.0 — THE SWITCH, because measuring was not enough
-- ---------------------------------------------------------------------
-- LL, again, two versions later: "once I launch Hammerspoon my typing
-- goes very slowly. I quit Hammerspoon. Then, back to normal."
--
-- That is a BETTER symptom than the first report, and the difference is
-- the whole reason this section exists. "Sometimes it lags" needs a
-- probe that is always on. "It lags whenever this program is running"
-- is a controlled experiment waiting to happen — the variable is
-- already isolated, and what is missing is a way to move it in steps
-- smaller than quitting the whole application.
--
-- Quitting Hammerspoon changes EVERYTHING at once: nine keyboard taps,
-- forty timers, every watcher. It proves the config is responsible and
-- names nothing. So this file gains the intermediate positions:
--
--     _G.lagTapsOff()   every keyboard tap goes inert, nothing else does
--     _G.lagTapsGone()  every keyboard tap is STOPPED, watchdogs held down
--     _G.lagOnly(n)     exactly one tap runs; the others are inert
--
-- 🚨 INERT, NOT STOPPED, and that distinction is the entire design.
-- Stopping a tap looks obvious and does not survive contact with this
-- config: text_expander and autocorrect each run a 30-second watchdog
-- that finds a stopped tap and starts it again. A test that silently
-- undoes itself after thirty seconds is worse than no test, because it
-- returns a WRONG answer rather than no answer — you would type for a
-- minute, feel the lag come back, and conclude taps were innocent.
--
-- So the tap keeps running and the WRAPPER returns false without ever
-- calling the module's handler. Nothing can re-arm it because nothing
-- was disarmed, the keystroke passes through untouched, and the cost of
-- the whole mechanism on the normal path is one comparison against an
-- upvalue.
--
-- ⏲ AND IT PUTS ITSELF BACK. lagTapsOff takes a number of seconds and
-- defaults to 90. While taps are inert ⇪ does nothing — that is the
-- point, ⇪ IS a tap — so a switch with no timer would be a switch that
-- can strand you in a config with no shortcuts, needing the Console to
-- escape. The timer means the worst case is that you wait.
--
-- ---------------------------------------------------------------------
-- 🔌🔌 6.135.0 — AND WHY INERT ALONE WAS A TRAP
-- ---------------------------------------------------------------------
-- Inert is the right answer to the watchdogs and the wrong answer to the
-- question on its own, because an inert tap IS STILL A TAP. It is still
-- registered with macOS, and your keystroke still travels through the
-- event-tap machinery to reach it — it just meets a function that
-- returns immediately.
--
-- That measures what our CALLBACKS cost. It does not measure what HAVING
-- FIVE TAPS costs, and those are different numbers: the dispatch itself
-- has a price, secure input degrades every tap at once, and a stale
-- Accessibility grant can make the whole mechanism crawl with no
-- callback being slow at all.
--
-- 🚨 SO lagTapsOff COULD HAVE RETURNED A CONFIDENT WRONG ANSWER — type
-- during the inert window, feel no change, conclude the taps are
-- innocent, when the taps were the whole problem and the part switched
-- off was never where the cost lived. Precisely the failure this header
-- calls worse than no answer, reached by a different road.
--
-- lagTapsGone is the position that removes them for real. It stops each
-- tap AND stops the two watchdogs by name first, because stopping a tap
-- while its watchdog runs is a race the watchdog wins inside thirty
-- seconds. It restores only the taps it actually stopped — screenshots'
-- select-mode tap spends nearly all its life stopped, and a "restore"
-- that started it would switch on something the config had deliberately
-- switched off.
--
-- It is second, not first, because it needs that scaffolding, and a test
-- needing more scaffolding has more ways to lie. Run tapsOff first; run
-- tapsGone when tapsOff changed nothing.
--
-- ---------------------------------------------------------------------
-- ⏱ AND THE TIMERS, so that "not a tap" is not a dead end
-- ---------------------------------------------------------------------
-- If typing is still slow with every tap inert, the old report had
-- nothing else to offer: it could tell you the thread stalled at
-- 14:32:07 for 900ms and not one word about what was running. A stall
-- with no attribution is a symptom restated, not a diagnosis.
--
-- hs.timer.doEvery and hs.timer.new are wrapped the same way and for
-- the same reason — every repeating timer in this config is born from
-- them, so nothing has to register and a timer written next year is
-- measured on the day it is written. They are aggregated BY CALL SITE,
-- so the table is bounded by how many timers the config creates rather
-- than by how often they fire.
--
-- 🚨 hs.timer.doAfter IS DELIBERATELY NOT WRAPPED. It is the one-shot,
-- and it is called from alerts, debounces and every deferred paste —
-- often several times a second. Resolving a call site costs a stack
-- walk, and paying for one on every doAfter would put a real cost on a
-- hot path in order to measure cost. A one-shot that blocks the thread
-- still shows up, as a stall with the time of day beside it.
--
--     _G.lagReport()    everything measured so far (also to the clipboard)
--     _G.lagReset()     zero the counters and start again
--     _G.lagTapsOff(s)  every keyboard tap inert for s seconds (default 90)
--     _G.lagTapsGone(s) every keyboard tap STOPPED for s seconds, and the
--                       watchdogs held down so they cannot revive them
--     _G.lagTapsOn()    undo either of those now
--     _G.lagOnly(n)     only tap n runs — n is the # column in the report
--     _G.lagMute(n)     make tap n inert on its own
--     _G.lagUnmute(n)   and put it back
--     _G.lagQuiet()     stop the probe's OWN heartbeat — it is a suspect
--                       too, and it should be possible to rule it out
--     _G.lagOn()        arm the probe (writes the file, then reload)
--     _G.lagOff()       disarm it (removes the file, then reload)
--
-- ---------------------------------------------------------------------
-- 🚨🚨 6.136.0 — THIS PROBE IS OFF UNLESS YOU ASK FOR IT, AND HERE IS WHY
-- ---------------------------------------------------------------------
-- LL reported typing lag that started "the last, at least two versions"
-- and stopped the moment Hammerspoon quit. This file shipped in 6.131.0,
-- which is exactly that window. THE MEASURING TOOL IS THE LEADING
-- SUSPECT FOR THE THING IT WAS BUILT TO MEASURE.
--
-- The mechanism is not subtle once you look at it. install() replaces
-- hs.eventtap.new for the whole session, so EVERY tap in the config gets
-- an extra Lua closure between macOS and the real handler, and every one
-- of those closures does two clock reads, four table writes and a
-- comparison ON EVERY KEYSTROKE. With five always-on keyboard taps that
-- is five closures and ten clock reads per character typed.
--
-- 🚨 AND THEN THE SECOND-ORDER EFFECT, WHICH IS THE ONE THAT BITES:
-- macOS DISABLES an event tap whose callback takes too long. That is not
-- a theory — it is the documented reason text_expander and autocorrect
-- each run a watchdog to restart a stopped tap. So a probe that makes
-- every callback slower can push taps past that timeout, macOS kills
-- them, the watchdogs revive them, and they get killed again. From the
-- outside that is "all kinds of keys stopped working".
--
-- 🚨 AND THERE WAS NO WAY TO SWITCH IT OFF. _G.lagQuiet() stops the
-- heartbeat and NOT the wrapper, so the expensive half — the part on the
-- keystroke path — ran no matter what you typed into the console. The
-- one honest way out was deleting the file. 6.135.0 spent a whole
-- release on the difference between a tap that is INERT and one that is
-- GONE, and never noticed the probe only offered itself the weaker of
-- the two. Same trap, one level up.
--
-- ✅ SO: no file, no probe. Nothing is wrapped, nothing is measured, and
-- the config runs exactly as it did before 6.131.0. Arm it deliberately
-- for a diagnostic session and disarm it when you are done.
-- =====================================================================

return function(core)
    local lag = {}

    -- ✏️ A callback slower than this many milliseconds is counted as a
    -- slow call. One frame at 60 Hz is 16.7ms; a keystroke handler over
    -- 8ms is already spending half a frame and is worth naming.
    lag.slowMs     = 8

    -- ✏️ How late the heartbeat has to fire before it counts as a stall.
    -- Below ~100ms nobody feels a hitch; a scheduling jitter of a few ms
    -- is normal on a busy Mac and logging it would bury the real ones.
    lag.stallMs    = 120
    lag.stallEvery = 0.05      -- heartbeat interval, seconds
    lag.keepStalls = 12        -- how many of the worst to keep

    lag.taps       = {}        -- creation-ordered list of tap records
    lag.stalls     = {}        -- the worst, unordered until report time
    lag.stallCount = 0         -- how many there have been in total
    lag.installedAt = nil
    lag.wrapped    = 0
    lag.note       = nil       -- why the probe is not measuring, if so

    -- ✏️ How long lagTapsOff stays off before it restores itself. Long
    -- enough to type a paragraph and form an opinion; short enough that
    -- forgetting about it is not an event.
    lag.offSeconds = 90

    lag.timers     = {}        -- repeating-timer records, keyed by call site
    lag.timerOrder = {}        -- the same records, in creation order
    lag.timerNote  = nil

    -- ---- THE ARMING FILE -------------------------------------------------
    -- Same shape as SAFE mode, deliberately: a file whose EXISTENCE is the
    -- whole message, checked once at load, with nothing inside it to get
    -- wrong. It is a file rather than an hs.settings key because the state
    -- that matters is "what happens at the next launch", and a file is the
    -- one thing you can still change when the keyboard is the broken part.
    lag.probeFile = (hs and hs.configdir or "") .. "/LAGPROBE"

    -- 🚨 NOTHING BELOW THIS LINE RUNS WHEN THIS IS FALSE. Not the wrapper,
    -- not the timer wrapper, not the heartbeat. The functions are all still
    -- DEFINED — the report has to be able to explain that it is off, and
    -- _G.lagOn() has to exist in order to turn it on — but install() is
    -- never called, so hs.eventtap.new is never replaced.
    -- 🚨 SAFE MODE WINS, ALWAYS. init.lua loads this file at line ~641 and
    -- does not look for the SAFE file until line ~3290, so for its whole
    -- life SAFE mode has cut the module list from 58 to 4 and left the
    -- probe wrapping every tap that remained. That made SAFE mode unable
    -- to answer the one question it exists for — fewer modules also means
    -- fewer taps for the probe to wrap, so the two explanations move
    -- together and neither can be ruled out. SAFE now means safe: the
    -- smallest thing that could possibly work, with no instrument on the
    -- keystroke path, whatever the arming file says.
    lag.safeFile = (hs and hs.configdir or "") .. "/SAFE"

    local function exists(path)
        if not (hs and hs.fs and hs.fs.attributes) then return false end
        local ok, a = pcall(hs.fs.attributes, path)
        return (ok and a) and true or false
    end

    local function armed()
        if exists(lag.safeFile) then return false end
        return exists(lag.probeFile)
    end
    lag.armed  = armed()
    lag.inSafe = exists(lag.safeFile)

    -- 🚨 A PLAIN UPVALUE, NOT lag.suspended. Every wrapped callback closes
    -- over this one local, so the check on the normal path is a register
    -- read and a comparison. A field on lag would be a hash lookup on
    -- every keystroke in every tap, which is a strange thing to spend on
    -- a switch that is off almost always. lag.isSuspended() reads it for
    -- anyone outside; nothing outside may write it.
    local SUSPENDED = false
    lag.restoreAt = nil        -- when the switch puts itself back, or nil

    -- ---- the clock -------------------------------------------------------
    -- Resolved ONCE, here, so the hot path has a plain function to call
    -- and no branch to take. absoluteTime is nanoseconds since boot;
    -- secondsSinceEpoch is the fallback and is a double in seconds, so
    -- both are normalised to MILLISECONDS on the way out.
    local nowMs
    do
        local t = hs and hs.timer
        if t and type(t.absoluteTime) == "function" then
            local abs = t.absoluteTime
            nowMs = function() return abs() / 1e6 end
        elseif t and type(t.secondsSinceEpoch) == "function" then
            local sec = t.secondsSinceEpoch
            nowMs = function() return sec() * 1e3 end
        else
            nowMs = function() return 0 end
            lag.note = "this Hammerspoon exposes no usable clock — "
                       .. "every timing below will read 0"
        end
    end
    lag.nowMs = nowMs

    -- ---- naming the event types -----------------------------------------
    -- hs.eventtap.event.types maps name -> number. A tap is created with
    -- the numbers, and a report full of "10, 12" would be useless, so the
    -- map is inverted once at load.
    local TYPE_NAME = {}
    do
        local T = (hs and hs.eventtap and hs.eventtap.event
                   and hs.eventtap.event.types) or {}
        for name, num in pairs(T) do
            if type(num) == "number" then TYPE_NAME[num] = name end
        end
    end

    -- Only the types that can make TYPING feel slow. A tap that watches
    -- mouse events alone cannot delay a keystroke, and saying so in the
    -- report stops a busy mouse tap from being read as the culprit.
    local KEYBOARD = { keyDown = true, keyUp = true, flagsChanged = true }

    local function describeTypes(types)
        if type(types) ~= "table" then return "?", false end
        local names, onKeyboard = {}, false
        for _, num in ipairs(types) do
            local n = TYPE_NAME[num] or tostring(num)
            names[#names + 1] = n
            if KEYBOARD[n] then onKeyboard = true end
        end
        if #names == 0 then return "none", false end
        return table.concat(names, "+"), onKeyboard
    end

    -- ---- where the tap came from ----------------------------------------
    -- 🚨 IT WALKS THE STACK RATHER THAN COUNTING FRAMES. The obvious
    -- version asks debug.getinfo for a fixed level — 3, say: this
    -- function, the wrapper, the caller. It was wrong, and it was wrong
    -- in the way that matters: pcall is itself a frame, so every tap was
    -- reported as having been created inside core/lag.lua, and a report
    -- naming ONE file nine times looks like a formatting quirk rather
    -- than a broken measurement. Walking up until the frame is no longer
    -- this file cannot drift when a frame is added or removed.
    --
    -- SELF is resolved at load, not hard-coded, so this holds however the
    -- file was loaded and whatever chunk name it was given.
    --
    -- 🚨 AND IT IS RESOLVED WITHOUT pcall, WHICH IS THE WHOLE POINT.
    -- `pcall(debug.getinfo, 1, "S")` asks for "the function that called
    -- getinfo" — and when getinfo is called BY pcall, that function is
    -- pcall, a C function. SELF came back as "[C]", matched no frame at
    -- all, and the walk below returned on its very first step: every tap
    -- in the config was reported as having been created inside
    -- core/lag.lua. Nothing threw. The table was full and the column was
    -- wrong, which is the failure mode this whole file exists to avoid.
    local getInfo = (type(debug) == "table"
                     and type(debug.getinfo) == "function") and debug.getinfo
                    or nil
    local SELF = "?"
    if getInfo then
        local info = getInfo(1, "S")
        if type(info) == "table" then SELF = tostring(info.short_src) end
    end

    local function callerSite()
        if not getInfo then return "unknown" end
        for level = 2, 8 do
            -- A level past the top of the stack returns nil rather than
            -- raising, so the loop ends on its own.
            local info = getInfo(level, "Sl")
            if type(info) ~= "table" then break end
            local src = tostring(info.short_src or "?")
            -- C frames are skipped as well as our own. pcall is a C
            -- function and sits in this stack; "[C]:-1" is not a place
            -- anybody can go and look, which is the only thing a site is
            -- for.
            if info.what ~= "C" and src ~= SELF then
                -- Trimmed to the last two path components: narrow enough
                -- for a column, wide enough to say which folder.
                local short = src:match("([^/]+/[^/]+)$")
                              or src:match("([^/]+)$") or src
                return short .. ":" .. tostring(info.currentline or "?")
            end
        end
        return "unknown"
    end

    -- =====================================================================
    -- ⌨️ THE WRAP
    -- =====================================================================
    function lag.install()
        if not (hs and hs.eventtap and type(hs.eventtap.new) == "function") then
            lag.note = "hs.eventtap.new is not available — no tap can be "
                       .. "measured, and on this Hammerspoon none can be made"
            return false
        end
        -- 🚨 ONCE. A second wrap would put a second layer of timing around
        -- every tap and double-count every keystroke, and the arithmetic
        -- would look like the config had got twice as slow overnight —
        -- which is precisely the false alarm this file exists to prevent.
        if hs.eventtap.__lagOriginalNew then
            lag.note = "the probe was already installed — not wrapping twice"
            return false
        end

        local realNew = hs.eventtap.new
        hs.eventtap.__lagOriginalNew = realNew
        lag.realNew = realNew

        hs.eventtap.new = function(types, fn, ...)
            -- Not a callback we can time, and not our business to police:
            -- hand it straight to the real one and let it raise whatever
            -- it would have raised.
            if type(fn) ~= "function" then return realNew(types, fn, ...) end

            local names, onKeyboard = describeTypes(types)
            -- Once per tap CREATION, not per event — so a pcall here costs
            -- nothing measurable, and a stripped debug library must not be
            -- able to stop a tap from being made.
            local okSite, site = pcall(callerSite)
            local rec = {
                -- The number you type into lagOnly/lagMute. Creation order,
                -- fixed for the life of the session — the report sorts by
                -- time spent, and an index that moved when the sort moved
                -- would name a different tap between reading and typing.
                n        = #lag.taps + 1,
                site     = okSite and site or "unknown",
                types    = names,
                keyboard = onKeyboard,
                calls    = 0,
                total    = 0,      -- milliseconds
                max      = 0,
                slow     = 0,      -- calls at or over lag.slowMs
                worstAt  = nil,
                muted    = false,  -- inert on its own, via lagMute
                skipped  = 0,      -- events that arrived while inert
            }
            lag.taps[#lag.taps + 1] = rec
            lag.wrapped = lag.wrapped + 1

            -- 🚨 TWO RETURN VALUES, NOT table.pack. An eventtap callback
            -- returns a boolean and optionally a table of replacement
            -- events — that is the whole documented contract, so two named
            -- locals carry it exactly. table.pack would allocate a table on
            -- every keystroke, and a probe that adds garbage-collector
            -- pressure to the typing path is a probe that causes the
            -- symptom it was built to find.
            local wrapped = function(ev)
                -- 🚨 FIRST, AND IT RETURNS false. false means "I did not
                -- handle this event" — the keystroke continues to the app
                -- exactly as if this tap had never been created. Returning
                -- true here would EAT every keystroke in the config while
                -- the switch was on, and the switch is reached by someone
                -- whose typing is already broken.
                if SUSPENDED or rec.muted then
                    rec.skipped = rec.skipped + 1
                    return false
                end
                local t0 = nowMs()
                local a, b = fn(ev)
                local dt = nowMs() - t0
                rec.calls = rec.calls + 1
                rec.total = rec.total + dt
                if dt > rec.max then
                    rec.max     = dt
                    rec.worstAt = os.date("%H:%M:%S")
                end
                if dt >= lag.slowMs then rec.slow = rec.slow + 1 end
                return a, b
            end
            rec.tap = realNew(types, wrapped, ...)
            return rec.tap
        end

        lag.installedAt = os.date("%H:%M:%S")
        return true
    end

    -- =====================================================================
    -- ⏱ THE REPEATING TIMERS
    -- =====================================================================
    -- Same trick, same reason, one difference: records are keyed by CALL
    -- SITE and reused. A tap is created once and lives forever, so a
    -- record per creation is a record per tap. A timer can be created and
    -- discarded in a loop, and a record per creation would be a table that
    -- grows for as long as Hammerspoon runs — a leak inside the tool whose
    -- job is to find leaks.
    local function timerRec(site, kind, interval)
        local rec = lag.timers[site]
        if rec then
            -- Same site, new timer. The interval is worth keeping current
            -- because a site that creates timers at two different rates is
            -- exactly the kind of thing worth seeing in the table.
            rec.made     = rec.made + 1
            rec.interval = interval or rec.interval
            return rec
        end
        rec = { site = site, kind = kind, interval = interval, made = 1,
                calls = 0, total = 0, max = 0, slow = 0, worstAt = nil }
        lag.timers[site] = rec
        lag.timerOrder[#lag.timerOrder + 1] = rec
        return rec
    end

    -- 🚨 THE ONE TIMER callerSite CANNOT NAME IS THIS FILE'S OWN.
    -- callerSite deliberately walks PAST core/lag.lua, because a tap
    -- created by a module must be reported against the module and not
    -- against the probe that wrapped it. The heartbeat is the exception
    -- that rule cannot see: this file really is its creator, so the walk
    -- sails past and lands on whoever loaded core/ — init.lua. The probe
    -- would then be measuring its own 20-a-second timer and filing the
    -- cost under somebody else's name, which is the precise shape of a
    -- tool that exonerates itself.
    local siteOverride = nil
    local function timedFn(rec, fn)
        return function(...)
            local t0 = nowMs()
            local a, b = fn(...)
            local dt = nowMs() - t0
            rec.calls = rec.calls + 1
            rec.total = rec.total + dt
            if dt > rec.max then
                rec.max     = dt
                rec.worstAt = os.date("%H:%M:%S")
            end
            if dt >= lag.slowMs then rec.slow = rec.slow + 1 end
            return a, b
        end
    end

    -- 🚨 TIMERS ARE MEASURED BUT NEVER SUSPENDED, and that asymmetry is
    -- deliberate. An inert keyboard tap costs you shortcuts for ninety
    -- seconds. An inert timer costs you whatever that timer was in the
    -- middle of — a half-written CSV, a pomodoro that never ends, a
    -- clipboard poller that misses the copy you were about to paste. The
    -- switch exists to answer one question safely, not to be a general
    -- off button for the config.
    function lag.installTimers()
        if not (hs and hs.timer) then
            lag.timerNote = "hs.timer is not available — no timer is measured"
            return false
        end
        if hs.timer.__lagOriginalDoEvery or hs.timer.__lagOriginalNew then
            lag.timerNote = "already wrapped — not wrapping twice"
            return false
        end

        local realDoEvery = hs.timer.doEvery
        if type(realDoEvery) == "function" then
            hs.timer.__lagOriginalDoEvery = realDoEvery
            hs.timer.doEvery = function(interval, fn, ...)
                if type(fn) ~= "function" then
                    return realDoEvery(interval, fn, ...)
                end
                local okSite, site = pcall(callerSite)
                local rec = timerRec(siteOverride
                                     or (okSite and site or "unknown"),
                                     "doEvery", interval)
                siteOverride = nil
                return realDoEvery(interval, timedFn(rec, fn), ...)
            end
        end

        local realTimerNew = hs.timer.new
        if type(realTimerNew) == "function" then
            hs.timer.__lagOriginalNew = realTimerNew
            hs.timer.new = function(interval, fn, ...)
                if type(fn) ~= "function" then
                    return realTimerNew(interval, fn, ...)
                end
                local okSite, site = pcall(callerSite)
                local rec = timerRec(siteOverride
                                     or (okSite and site or "unknown"),
                                     "new", interval)
                siteOverride = nil
                return realTimerNew(interval, timedFn(rec, fn), ...)
            end
        end
        return true
    end

    -- =====================================================================
    -- 🔌 THE SWITCH
    -- =====================================================================
    function lag.isSuspended() return SUSPENDED end

    -- Cancelling a pending restore before arming another one: two calls to
    -- lagTapsOff in a row must not leave the first timer running, or the
    -- earlier one fires and turns the taps back on halfway through the
    -- test you just started.
    local function clearRestore()
        if lag.restoreTimer then
            pcall(function() lag.restoreTimer:stop() end)
            lag.restoreTimer = nil
        end
        lag.restoreAt = nil
    end

    -- 🚨 THE WATCHDOGS, WHICH EXIST TO UNDO EXACTLY WHAT tapsGone DOES.
    -- text_expander and autocorrect each run a 30-second timer that finds a
    -- stopped tap and starts it again — a good idea, because macOS really
    -- does disable taps it dislikes, and a silently dead expander is
    -- indistinguishable from a wrong trigger. It is also the reason a
    -- stop-based test cannot be trusted unless these are held down first.
    --
    -- They are stopped BY NAME rather than by asking the modules, because
    -- the modules must not gain a "please stop watching" API that ships
    -- forever for the sake of one diagnostic. If a module is not loaded the
    -- global is nil and the loop skips it.
    local WATCHDOGS = { "expanderWatchdog", "autocorrectWatchdog" }

    local function pauseWatchdogs()
        local held = {}
        for _, name in ipairs(WATCHDOGS) do
            local t = _G[name]
            if t and pcall(function() t:stop() end) then
                held[#held + 1] = name
            end
        end
        lag.heldDogs = held
        return #held
    end

    local function resumeWatchdogs()
        local n = 0
        for _, name in ipairs(lag.heldDogs or {}) do
            local t = _G[name]
            -- 🚨 RESTARTED EVEN IF IT THROWS ON THE WAY. A watchdog left
            -- stopped is a tap that stays dead the next time macOS kills
            -- it, and the user would never connect that to a lag test they
            -- ran an hour earlier.
            if t and pcall(function() t:start() end) then n = n + 1 end
        end
        lag.heldDogs = nil
        return n
    end

    function lag.tapsOn(quiet)
        clearRestore()
        SUSPENDED = false
        for _, r in ipairs(lag.taps) do r.muted = false end
        local back = 0
        if lag.gone then
            -- Only the ones THIS switch stopped. A tap that was already
            -- stopped when the test began — screenshots' select-mode tap
            -- spends almost all its life stopped — must stay that way, or
            -- the "restore" quietly turns on something the config had
            -- deliberately switched off.
            for _, r in ipairs(lag.taps) do
                if r.wasRunning and r.tap then
                    if pcall(function() r.tap:start() end) then back = back + 1 end
                end
                r.wasRunning = nil
            end
            resumeWatchdogs()
            lag.gone = false
        end
        local s = "🔌 Lag probe: every tap is live again"
        if back > 0 then
            s = s .. (" (%d restarted, watchdogs watching again)"):format(back)
        end
        if not quiet then
            pcall(function() hs.alert.show("🔌 Taps back ON") end)
        end
        return s
    end

    function lag.tapsOff(seconds)
        seconds = tonumber(seconds) or lag.offSeconds
        if seconds <= 0 then seconds = lag.offSeconds end
        clearRestore()
        SUSPENDED = true
        -- HELD, like every other timer in this config: an unreferenced
        -- hs.timer is collected, and a collected timer never fires. Here
        -- that would mean the switch never comes back on by itself, which
        -- is the one failure this timer exists to prevent.
        local okT, t = pcall(hs.timer.doAfter, seconds, function()
            lag.restoreTimer = nil
            lag.tapsOn(true)
            pcall(function()
                hs.alert.show("🔌 Taps back ON — the test window is over", 4)
            end)
        end)
        if okT and t then
            lag.restoreTimer = t
            lag.restoreAt = os.date("%H:%M:%S", os.time() + math.floor(seconds))
        end
        local s = ("🔌 Lag probe: %d keyboard taps are INERT for %d seconds.\n"
                   .. "   Type normally now. ⇪ shortcuts will not work — ⇪ is\n"
                   .. "   itself a tap, and that is the thing being tested.\n"
                   .. "   _G.lagTapsOn() ends it early.")
                  :format(lag.keyboardCount(), seconds)
        if not okT or not t then
            -- Said loudly, because without the timer this switch is the
            -- one that can stand you in a config with no shortcuts.
            s = s .. "\n   ⚠️ THE RESTORE TIMER DID NOT ARM. It will NOT come "
                  .. "back on by itself — run _G.lagTapsOn() yourself."
        end
        pcall(function()
            hs.alert.show("🔌 Taps INERT for " .. seconds .. "s", 4)
        end)
        return s
    end

    -- =====================================================================
    -- 🔌🔌 THE STRONGER DOSE — and why INERT was not enough on its own
    -- =====================================================================
    -- tapsOff makes the CALLBACKS inert. The taps stay installed, stay
    -- registered with macOS, and every keystroke still travels through the
    -- event-tap machinery on its way to the app — it just meets a function
    -- that returns false immediately.
    --
    -- That measures what our code costs. It does NOT measure what HAVING
    -- FIVE TAPS costs, and those are different numbers. The event-tap path
    -- itself has a price: macOS serialises the keystroke through each
    -- registered tap, secure input degrades the lot of them, and a stale
    -- Accessibility grant can make the whole mechanism crawl without any
    -- callback being slow at all.
    --
    -- 🚨 SO tapsOff ALONE COULD RETURN A CONFIDENT WRONG ANSWER: type
    -- during the inert window, feel no improvement, and conclude the taps
    -- are innocent — when the taps are the entire problem and the cost was
    -- never in the part that was switched off. That is the failure this
    -- file's own header calls worse than no answer, and it applied here.
    --
    -- This is the position that removes them from the path for real. It is
    -- second, not first, because it is the one that needs the watchdogs
    -- held down, and a test that needs more scaffolding is a test with more
    -- ways to lie. Run tapsOff first; run this when tapsOff changed
    -- nothing.
    function lag.tapsGone(seconds)
        seconds = tonumber(seconds) or lag.offSeconds
        if seconds <= 0 then seconds = lag.offSeconds end
        clearRestore()
        -- Watchdogs FIRST. Stopping a tap while its watchdog is still
        -- running is a race, and the watchdog wins within thirty seconds.
        local dogs = pauseWatchdogs()
        SUSPENDED = true   -- belt as well as braces: a tap that gets
                           -- revived anyway still meets an inert callback
        local stopped, failed = 0, 0
        for _, r in ipairs(lag.taps) do
            if r.keyboard and r.tap then
                local running = false
                pcall(function() running = r.tap:isEnabled() end)
                r.wasRunning = running
                if running then
                    if pcall(function() r.tap:stop() end) then
                        stopped = stopped + 1
                    else
                        failed = failed + 1
                    end
                end
            end
        end
        lag.gone = true
        local okT, t = pcall(hs.timer.doAfter, seconds, function()
            lag.restoreTimer = nil
            lag.tapsOn(true)
            pcall(function()
                hs.alert.show("🔌 Taps back ON — the test window is over", 4)
            end)
        end)
        if okT and t then
            lag.restoreTimer = t
            lag.restoreAt = os.date("%H:%M:%S", os.time() + math.floor(seconds))
        end
        local s = ("🔌🔌 Lag probe: %d keyboard taps are STOPPED for %d seconds,\n"
                   .. "   and %d watchdog(s) are held down so they cannot revive\n"
                   .. "   them. This is as close to \"Hammerspoon is not in the\n"
                   .. "   keyboard path\" as you can get without quitting it.\n"
                   .. "   If typing is smooth NOW but was not with _G.lagTapsOff(),\n"
                   .. "   the cost is in HAVING taps, not in what they do.\n"
                   .. "   _G.lagTapsOn() ends it early.")
                  :format(stopped, seconds, dogs)
        if failed > 0 then
            s = s .. ("\n   ⚠️ %d tap(s) would not stop — the test is partial.")
                     :format(failed)
        end
        if not okT or not t then
            s = s .. "\n   ⚠️ THE RESTORE TIMER DID NOT ARM. Nothing comes back "
                  .. "by itself — run _G.lagTapsOn() yourself."
        end
        pcall(function()
            hs.alert.show("🔌🔌 Taps STOPPED for " .. seconds .. "s", 4)
        end)
        return s
    end

    -- Reported because it changes what every tap costs and nothing in this
    -- config causes it: macOS turns secure input on for password fields,
    -- and a badly-behaved app can leave it on for everybody afterwards.
    -- When it is on, the taps below are being throttled by the OS and no
    -- amount of muting them one at a time will show it.
    function lag.secureInput()
        if not (hs and hs.eventtap and hs.eventtap.isSecureInputEnabled) then
            return nil
        end
        local ok, on = pcall(hs.eventtap.isSecureInputEnabled)
        if not ok then return nil end
        return on == true
    end

    -- 🚨 THE PROBE MUST BE TESTABLE AS A SUSPECT. It shipped in 6.131.0,
    -- the lag was reported again in 6.133.0, and the heartbeat is the one
    -- thing this config gained that runs 20 times a second forever whether
    -- you touch the keyboard or not. Its measured cost is in the TIMERS
    -- table under its own name, which is evidence — but evidence from the
    -- accused. This turns it off so the question can be settled instead of
    -- argued.
    --
    -- ⚠️ IT COSTS THE STALL LOG. With the heartbeat stopped nothing is
    -- watching the thread, so no stall can be recorded until it restarts.
    -- That is why lagTapsOff does NOT do this — the "still slow with the
    -- taps off" branch is exactly when the stall log matters most.
    function lag.quiet(on)
        on = (on ~= false)
        if not lag.beat then return "⏱ there is no heartbeat to stop" end
        if on then
            pcall(function() lag.beat:stop() end)
            lag.beatStopped = true
            return "⏱ the probe's own heartbeat is STOPPED. Type for a"
                   .. " minute.\n   _G.lagQuiet(false) starts it again —"
                   .. " no stall is recorded until you do."
        end
        local ok = pcall(function() lag.beat:start() end)
        if not ok then
            -- Some hs.timer objects will not restart after stop. Saying so
            -- beats a cheerful message and a dead heartbeat.
            lag.startHeartbeat()
        end
        lag.beatStopped = false
        return "⏱ the heartbeat is running again"
    end

    function lag.keyboardCount()
        local n = 0
        for _, r in ipairs(lag.taps) do if r.keyboard then n = n + 1 end end
        return n
    end

    -- n is the # column. Returns nil and a reason rather than throwing,
    -- because this is typed into a console by someone who is annoyed.
    local function tapByNumber(n)
        n = tonumber(n)
        if not n then return nil, "give me a number from the # column" end
        for _, r in ipairs(lag.taps) do if r.n == n then return r end end
        return nil, ("there is no tap #%d — the report lists 1 to %d")
                    :format(n, #lag.taps)
    end

    function lag.mute(n, on)
        local rec, why = tapByNumber(n)
        if not rec then return "🔌 " .. why end
        rec.muted = (on ~= false)
        return ("🔌 tap #%d (%s) is now %s")
               :format(rec.n, rec.site, rec.muted and "INERT" or "live")
    end

    -- The bisect step: everything inert except one. Deliberately does NOT
    -- arm a restore timer — solo leaves ⇪ working if you solo the hyper
    -- tap, and the state is visible at the top of every report.
    function lag.only(n)
        local rec, why = tapByNumber(n)
        if not rec then return "🔌 " .. why end
        SUSPENDED = false
        for _, r in ipairs(lag.taps) do r.muted = (r ~= rec) end
        return ("🔌 only tap #%d (%s) is live — every other tap is inert.\n"
                .. "   _G.lagTapsOn() puts them all back.")
               :format(rec.n, rec.site)
    end

    -- =====================================================================
    -- 📉 THE HEARTBEAT
    -- =====================================================================
    -- Fires every stallEvery seconds. However much later than that it
    -- actually fires is how long the one thread was busy elsewhere.
    function lag.startHeartbeat()
        if not (hs and hs.timer and type(hs.timer.doEvery) == "function") then
            return false
        end
        local last = nowMs()
        local expected = lag.stallEvery * 1000
        -- HELD in lag.beat: an unreferenced hs.timer is collected, and a
        -- collected timer never fires. Same rule as every timer here.
        siteOverride = "core/lag.lua (the probe's own heartbeat)"
        local ok, t = pcall(hs.timer.doEvery, lag.stallEvery, function()
            local t1 = nowMs()
            local late = (t1 - last) - expected
            last = t1
            if late < lag.stallMs then return end
            lag.stallCount = lag.stallCount + 1
            lag.recordStall(late)
        end)
        if not (ok and t) then return false end
        lag.beat = t
        return true
    end

    -- Keeps only the worst lag.keepStalls. The front app is read ONLY for
    -- a stall that earns a place in the list: it is the most useful column
    -- in the report and also an inter-process call, so a stall storm must
    -- not turn the probe into a second source of stalls.
    function lag.recordStall(late)
        local worstIdx, worstVal = nil, nil
        if #lag.stalls >= lag.keepStalls then
            for i, s in ipairs(lag.stalls) do
                if worstVal == nil or s.late < worstVal then
                    worstVal, worstIdx = s.late, i
                end
            end
            if late <= (worstVal or 0) then return end
        end
        local app = "?"
        pcall(function()
            local a = hs.application.frontmostApplication()
            if a then app = tostring(a:name() or "?") end
        end)
        local entry = { late = late, when = os.date("%H:%M:%S"), app = app }
        if worstIdx then lag.stalls[worstIdx] = entry
        else lag.stalls[#lag.stalls + 1] = entry end
    end

    -- =====================================================================
    -- 🩺 THE REPORT
    -- =====================================================================
    -- 🚨 ZEROES THE COUNTERS, NOT THE STATE. muted and SUSPENDED survive a
    -- reset on purpose: reset is what you call at the START of a measured
    -- run, and a reset that quietly turned every tap back on would undo
    -- the experiment you were about to measure.
    function lag.reset()
        for _, r in ipairs(lag.taps) do
            r.calls, r.total, r.max, r.slow, r.worstAt = 0, 0, 0, 0, nil
            r.skipped = 0
        end
        for _, r in ipairs(lag.timerOrder) do
            r.calls, r.total, r.max, r.slow, r.worstAt = 0, 0, 0, 0, nil
        end
        lag.stalls, lag.stallCount = {}, 0
        return "⏱ Lag probe: counters zeroed at " .. os.date("%H:%M:%S")
    end

    function _G.lagReset()
        local s = lag.reset()
        print(s)
        return s
    end

    -- The console is the only interface these have, so each one prints
    -- what it did rather than returning a value you would have to inspect.
    local function announce(s) print(s) return s end
    function _G.lagTapsOff(seconds)  return announce(lag.tapsOff(seconds)) end
    function _G.lagTapsGone(seconds) return announce(lag.tapsGone(seconds)) end
    function _G.lagTapsOn()          return announce(lag.tapsOn()) end
    function _G.lagOnly(n)          return announce(lag.only(n)) end
    function _G.lagMute(n)          return announce(lag.mute(n, true)) end
    function _G.lagUnmute(n)        return announce(lag.mute(n, false)) end
    function _G.lagQuiet(on)        return announce(lag.quiet(on)) end

    function _G.lagReport()
        local L = { "", "⏱ LAG PROBE" }
        local function line(s) L[#L + 1] = s end

        -- 🚨 FIRST LINE, BEFORE ANY NUMBER. A disarmed probe has an empty
        -- tap table and a zero count, which reads exactly like "measured
        -- everything, found nothing" — the most misleading thing this
        -- report could possibly say to someone whose typing is broken.
        if not lag.armed then
            line("")
            line("   🔒 THE PROBE IS DISARMED. Nothing is wrapped and nothing")
            line("      below was measured — the empty tables mean NO DATA,")
            line("      not a clean bill of health.")
            line("")
            if lag.inSafe then
                -- Worth saying on its own line: someone reading this in
                -- SAFE mode is mid-diagnosis and needs to know that arming
                -- the probe will not work until they leave.
                line("   🚑 SAFE MODE IS ON, AND SAFE MODE WINS. The probe stays")
                line("      off here even with the arming file present, because")
                line("      SAFE means the smallest thing that could work.")
                line("      rm ~/.hammerspoon/SAFE and reload to leave.")
                line("")
            end
            line("      This is the default since 6.136.0 because the probe")
            line("      itself costs something on every keystroke: it puts a")
            line("      Lua closure between macOS and every tap's handler.")
            line("")
            line("      _G.lagOn() then reload  — to measure.")
            line("      _G.lagOff() then reload — to stop paying for it.")
            line("")
            local s = table.concat(L, "\n")
            print(s)
            return s
        end

        line("   installed  : " .. (lag.installedAt
             and (lag.installedAt .. "  (before any tap was created)")
             or  "NOT INSTALLED — nothing below was measured"))
        line("   taps seen  : " .. tostring(lag.wrapped))
        line("   slow line  : " .. tostring(lag.slowMs) .. "ms per call"
             .. "   ·   stall line: " .. tostring(lag.stallMs) .. "ms")
        if lag.note then line("   ⚠️ " .. lag.note) end
        if lag.timerNote then line("   ⚠️ " .. lag.timerNote) end

        -- An OS-level fact about every tap at once, and one no per-tap
        -- number can reveal: when it is on, the taps below are being
        -- throttled by macOS and bisecting them one at a time will find
        -- nothing, because none of them is individually at fault.
        local secure = lag.secureInput()
        if secure == true then
            line("   ⚠️ SECURE INPUT IS ON. macOS is degrading every event tap"
                 .. " right now.")
            line("      Nothing in this config turns it on — a password field"
                 .. " does, and an app")
            line("      that quits badly can leave it on. Log out and back in"
                 .. " if it persists.")
        elseif secure == false then
            line("   secure inp : off (good — taps are not being throttled)")
        end

        -- 🚨 SAID AT THE TOP, NOT BURIED IN A COLUMN. A report read while
        -- the switch is on describes a config with its taps turned off,
        -- and every number below it is evidence about a machine that is
        -- not the one you normally use. Someone who has forgotten they
        -- pressed the switch would otherwise read a table of zeros as
        -- proof that the taps were innocent.
        local muted = {}
        for _, r in ipairs(lag.taps) do
            if r.muted then muted[#muted + 1] = "#" .. tostring(r.n) end
        end
        local backAt = lag.restoreAt and ("  Back on at " .. lag.restoreAt .. ".")
                       or "  No restore timer is armed."
        if lag.gone then
            -- Checked BEFORE isSuspended, because tapsGone sets both and
            -- the stronger statement is the true one.
            line("")
            line("   🔌🔌 EVERY KEYBOARD TAP IS STOPPED RIGHT NOW — not merely")
            line("      inert. They are out of the event path entirely and the"
                 .. " watchdogs")
            line("      are held down so they cannot revive them." .. backAt)
        elseif lag.isSuspended() then
            line("")
            line("   🔌 EVERY TAP IS INERT RIGHT NOW — the numbers below stopped")
            line("      moving when you pressed the switch." .. backAt)
        elseif #muted > 0 then
            line("")
            line("   🔌 INERT: " .. table.concat(muted, " ")
                 .. "   — those taps are not running. _G.lagTapsOn() restores them.")
        end

        -- ---- the taps, worst total first ---------------------------------
        -- Sorted by TOTAL time, not by average: a tap averaging 1ms that
        -- runs on every key costs more of your day than one averaging 40ms
        -- that has run twice. Total is the number that answers "where did
        -- the time go".
        local order = {}
        for i, r in ipairs(lag.taps) do order[i] = r end
        table.sort(order, function(a, b)
            if a.total ~= b.total then return a.total > b.total end
            return tostring(a.site) < tostring(b.site)
        end)

        line("")
        line("   TAPS — every hs.eventtap in this config, by total time spent")
        if #order == 0 then
            line("      none created yet")
        else
            line(("      %3s %-26s %-22s %8s %8s %8s %6s")
                 :format("#", "created at", "watches", "calls", "avg ms",
                         "max ms", "slow"))
            for _, r in ipairs(order) do
                local avg = (r.calls > 0) and (r.total / r.calls) or 0
                local tail = r.keyboard and "" or "   (mouse only)"
                if r.muted then tail = tail .. "   🔌 INERT" end
                line(("      %3d %-26s %-22s %8d %8.2f %8.2f %6d%s")
                     :format(r.n, r.site, r.types, r.calls, avg, r.max,
                             r.slow, tail))
            end
        end

        -- ---- the verdict --------------------------------------------------
        -- 🚨 THE WHOLE POINT OF THE FILE IS THIS PARAGRAPH. A table of
        -- numbers is not an answer to "my typing lags" — it is homework.
        -- The verdict names the tap, or says plainly that no tap is at
        -- fault, which is just as useful and much easier to get wrong by
        -- leaving the reader to infer it from a wall of small numbers.
        local worstKey, worstAvg = nil, 0
        local keyCalls = 0
        for _, r in ipairs(order) do
            if r.keyboard then
                keyCalls = math.max(keyCalls, r.calls)
                local avg = (r.calls > 0) and (r.total / r.calls) or 0
                if avg > worstAvg then worstAvg, worstKey = avg, r end
            end
        end
        line("")
        if keyCalls == 0 then
            line("   VERDICT    : no keyboard tap has run yet. Type a few"
                 .. " sentences and read this again —")
            line("                the probe has nothing to go on until it"
                 .. " has seen some keystrokes.")
        elseif worstKey and worstAvg >= lag.slowMs then
            line(("   VERDICT    : %s is averaging %.1fms on every key.")
                 :format(worstKey.site, worstAvg))
            line("                That is the one to look at first.")
        else
            local sum = 0
            for _, r in ipairs(order) do
                if r.keyboard and r.calls > 0 then sum = sum + r.total / r.calls end
            end
            line(("   VERDICT    : every keyboard tap is fast (%.2fms total"
                  .. " per keystroke, all taps added up)."):format(sum))
            line("                If typing still lags, it is not a tap —"
                 .. " read the stalls below.")
        end

        -- ---- the repeating timers -------------------------------------------
        -- Sorted by total time for the same reason the taps are: a timer
        -- firing 20 times a second for an hour has spent more of your Mac
        -- than one that ran once and took 200ms.
        line("")
        line("   TIMERS — every repeating timer, by total time spent")
        local trows = {}
        for i, r in ipairs(lag.timerOrder) do trows[i] = r end
        table.sort(trows, function(a, b)
            if a.total ~= b.total then return a.total > b.total end
            return tostring(a.site) < tostring(b.site)
        end)
        if #trows == 0 then
            line("      none created yet")
        else
            line(("      %-26s %8s %8s %8s %8s %6s")
                 :format("created at", "every", "fires", "avg ms",
                         "max ms", "slow"))
            for _, r in ipairs(trows) do
                local avg = (r.calls > 0) and (r.total / r.calls) or 0
                local ivl = tonumber(r.interval)
                line(("      %-26s %8s %8d %8.2f %8.2f %6d")
                     :format(r.site, ivl and (("%.2fs"):format(ivl)) or "?",
                             r.calls, avg, r.max, r.slow))
            end
            -- The number that actually answers "is a timer eating my Mac":
            -- cost per second of wall clock, summed. A 0.05s timer taking
            -- 1ms is 2% of the thread forever; a 60s timer taking 200ms is
            -- 0.3% and looks far worse in the max column.
            local load = 0
            for _, r in ipairs(trows) do
                local ivl = tonumber(r.interval)
                if ivl and ivl > 0 and r.calls > 0 then
                    load = load + (r.total / r.calls) / (ivl * 1000)
                end
            end
            line(("      → repeating timers are using about %.2f%% of the one"
                  .. " thread, all told"):format(load * 100))
        end

        -- ---- the stalls ---------------------------------------------------
        line("")
        line("   STALLS — the one thread blocked long enough to be felt")
        line("      total: " .. tostring(lag.stallCount)
             .. "   (a stall is a fact about the thread, not proof of a bug —")
        line("       opening a panel that reads a folder blocks it on purpose)")
        if #lag.stalls == 0 then
            line("      none over " .. tostring(lag.stallMs)
                 .. "ms since load — the thread has stayed responsive")
        else
            local st = {}
            for i, s in ipairs(lag.stalls) do st[i] = s end
            table.sort(st, function(a, b) return a.late > b.late end)
            line(("      %-10s %10s   %s"):format("at", "blocked", "front app"))
            for _, s in ipairs(st) do
                line(("      %-10s %8.0fms   %s")
                     :format(s.when, s.late, s.app))
            end
        end
        line("")

        -- ---- what to do with all this ---------------------------------------
        -- 🚨 THE REPORT ENDS BY NAMING THE NEXT ACTION. Everything above is
        -- evidence, and evidence handed to someone whose typing is broken
        -- is a second job. One command, chosen by what the numbers say.
        line("")
        if lag.isSuspended() then
            line("   NEXT       : type a paragraph NOW, while the taps are "
                 .. (lag.gone and "stopped." or "inert."))
            line("                Suddenly fine? It IS a tap — _G.lagTapsOn(),"
                 .. " then bisect with")
            line("                _G.lagOnly(n) using the # column.")
            if lag.gone then
                line("                Still slow with them STOPPED? Then it is"
                     .. " not the taps at all —")
                line("                read TIMERS and STALLS above.")
            else
                -- 🚨 NOT \"then it is not a tap\", which is what this said
                -- until the difference between inert and stopped was
                -- thought through. Inert taps are still in the event path.
                line("                Still slow? That rules out what the"
                     .. " callbacks DO, not the taps")
                line("                themselves — they are still installed."
                     .. " Try _G.lagTapsGone()")
                line("                next, which removes them for real.")
            end
        else
            line("   NEXT       : _G.lagTapsOff() makes every keyboard tap inert"
                 .. " for " .. tostring(lag.offSeconds) .. " seconds.")
            line("                Type during that window. Whether the lag goes"
                 .. " away is the whole answer.")
            line("                If it does NOT, _G.lagTapsGone() is the"
                 .. " stronger dose — it stops")
            line("                the taps outright instead of hollowing them"
                 .. " out.")
        end
        line("")

        local s = table.concat(L, "\n")
        print(s)
        -- On the clipboard as well as the console, because the useful thing
        -- to do with this is send it to someone, and selecting many lines
        -- out of the Hammerspoon console by hand is its own small misery.
        local copied = pcall(function() hs.pasteboard.setContents(s) end)
        if copied then print("📋 (that report is on your clipboard too)") end
        return s
    end

    -- 🚨 TIMERS ARE WRAPPED BEFORE THE HEARTBEAT STARTS, so the probe's own
    -- heartbeat appears in its own TIMERS table. A measuring tool that
    -- leaves itself out of the measurement is exactly the tool you cannot
    -- use to answer "is the measuring tool the problem" — which is a real
    -- question here, because this file was added in 6.131.0 and the lag
    -- was reported again in 6.133.0.
    -- =====================================================================
    -- 🔒 ARMING — the file decides, and it decides at LOAD, once
    -- =====================================================================
    -- Writing the file cannot arm a running session: install() has to run
    -- before the first tap is created, and by the time you can type a
    -- command every tap already exists. So both of these change the file
    -- and tell you to reload. Saying "armed" when the wrapper is not in
    -- place would be the same class of lie 6.135.0 was written to fix.
    local function armSay(on)
        return on
            and ("🔌 Lag probe ARMED — reload to start measuring.\n"
                 .. "   File: " .. lag.probeFile .. "\n"
                 .. "   ⚠️ It wraps every tap and every repeating timer, so\n"
                 .. "   it COSTS something on the keystroke path. Disarm it\n"
                 .. "   with _G.lagOff() when you have your answer.")
            or  ("🔌 Lag probe DISARMED — reload and nothing is wrapped.\n"
                 .. "   File removed: " .. lag.probeFile)
    end

    function lag.arm()
        local ok = pcall(function()
            local f = assert(io.open(lag.probeFile, "w"))
            -- The content is not read by anything. It is here so that a
            -- person who finds this file in six months knows what it is.
            f:write("Presence of this file arms core/lag.lua.\n"
                    .. "Remove it (or run _G.lagOff()) and reload.\n")
            f:close()
        end)
        if not ok then
            return "🔌 Could not write " .. lag.probeFile
        end
        lag.armed = true
        return armSay(true)
    end

    function lag.disarm()
        pcall(function() os.remove(lag.probeFile) end)
        if armed() then
            return "🔌 Could not remove " .. lag.probeFile
                   .. " — delete it by hand and reload."
        end
        lag.armed = false
        return armSay(false)
    end

    function _G.lagOn()  return announce(lag.arm())    end
    function _G.lagOff() return announce(lag.disarm()) end

    if lag.armed then
        -- 🚨 TIMERS ARE WRAPPED BEFORE THE HEARTBEAT STARTS, so the probe's
        -- own heartbeat appears in its own TIMERS table. A measuring tool
        -- that leaves itself out of the measurement is exactly the tool you
        -- cannot use to answer "is the measuring tool the problem" — which
        -- turned out to be the actual question. See the 6.136.0 block at
        -- the top of this file.
        lag.install()
        lag.installTimers()
        lag.startHeartbeat()
    else
        lag.note = "the probe is DISARMED — no tap and no timer is wrapped,"
                   .. " and nothing is being measured. _G.lagOn() then reload."
        lag.timerNote = lag.note
    end

    _G.lagProbe = lag
    return lag
end
