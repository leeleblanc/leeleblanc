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
--     _G.lagReport()    everything measured so far
--     _G.lagReset()     zero the counters and start again
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
                site     = okSite and site or "unknown",
                types    = names,
                keyboard = onKeyboard,
                calls    = 0,
                total    = 0,      -- milliseconds
                max      = 0,
                slow     = 0,      -- calls at or over lag.slowMs
                worstAt  = nil,
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
            return realNew(types, wrapped, ...)
        end

        lag.installedAt = os.date("%H:%M:%S")
        return true
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
    function lag.reset()
        for _, r in ipairs(lag.taps) do
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

    function _G.lagReport()
        local L = { "", "⏱ LAG PROBE" }
        local function line(s) L[#L + 1] = s end

        line("   installed  : " .. (lag.installedAt
             and (lag.installedAt .. "  (before any tap was created)")
             or  "NOT INSTALLED — nothing below was measured"))
        line("   taps seen  : " .. tostring(lag.wrapped))
        line("   slow line  : " .. tostring(lag.slowMs) .. "ms per call"
             .. "   ·   stall line: " .. tostring(lag.stallMs) .. "ms")
        if lag.note then line("   ⚠️ " .. lag.note) end

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
            line(("      %-26s %-22s %8s %8s %8s %6s")
                 :format("created at", "watches", "calls", "avg ms",
                         "max ms", "slow"))
            for _, r in ipairs(order) do
                local avg = (r.calls > 0) and (r.total / r.calls) or 0
                line(("      %-26s %-22s %8d %8.2f %8.2f %6d%s")
                     :format(r.site, r.types, r.calls, avg, r.max, r.slow,
                             r.keyboard and "" or "   (mouse only)"))
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

        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    lag.install()
    lag.startHeartbeat()

    _G.lagProbe = lag
    return lag
end
