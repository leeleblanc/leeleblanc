-- =====================================================================
-- TOOL: OUTLOOK PROBE — find out what we can actually read, before
-- building a tracker on top of a guess
-- =====================================================================
-- ⚠️ THIS IS A DIAGNOSTIC, NOT A FEATURE — and since 6.105.0 it is not a
-- module either. Paste this into the Hammerspoon Console to run it:
--
--        dofile(hs.configdir .. "/tools/outlook-probe.lua")
--
-- 📦 WHY IT MOVED. It bound no key, watched nothing, and answered its one
-- question on the home Mac in 6.65.0 — but it still loaded on every boot,
-- held a module slot, and printed itself onto the cheat sheet forever. A
-- question that has been answered does not need to be asked at every
-- login. It lives here instead of being deleted because the WORK Mac is a
-- different Mac: a different Outlook build, a different security posture,
-- possibly a different answer. One line brings it back when that matters.
--
-- Everything below is unchanged from the module, minus the module
-- wrapper. It exists to answer ONE question with evidence instead of
-- assumption:
--
-- WHY IT EXISTS. The email tracker LL asked for — every message read or
-- sent, searchable by sender, keyword, attachment type, month, weekday —
-- is entirely buildable IF we can read those fields. Whether we can
-- depends on which Outlook is installed, and the two differ enormously:
--
--   · LEGACY OUTLOOK ships a full AppleScript dictionary. sender,
--     recipients, subject, content, attachments and dates are all
--     readable directly. The whole spec is achievable.
--   · NEW OUTLOOK (the redesign) dropped most of it. What is left is
--     Accessibility, which can usually see the message list and the
--     reading pane as TEXT — so subject and sender are likely, full body
--     and a reliable attachment list are doubtful.
--
-- Building the tracker without knowing which of those we are on is how
-- you get a module that works perfectly on my model of your Mac and does
-- nothing on the real one. This config has already paid for that once
-- (the Teams meeting patterns in 6.63.0 were an informed guess, and they
-- muted your microphone for a week).
--
-- 📅 6.116.0 — IT NOW ASKS ABOUT THE CALENDAR TOO, which is a separate
-- question from mail with a separate answer: a different dictionary, a
-- different macOS permission, and possibly a different APPLICATION. See
-- the three routes documented at CAL_PROBES. The short version is that
-- the interesting one is route B — if the Exchange account is added to
-- macOS Calendar.app, today's meetings are readable through Calendar's
-- own stable AppleScript no matter what New Outlook does or does not
-- support. That route needs no admin and survives Outlook updates.
--
-- WHAT TO DO: open Outlook, click a message so it is showing in the
-- reading pane, then run _G.outlookProbe() in the Hammerspoon Console
-- and paste the output back. Every line is a fact about YOUR Mac.
-- Run it on BOTH Macs — the work one is the one that can say no.
--
-- 🔒 IT READS, IT DOES NOT SEND. Nothing leaves your machine: the report
-- goes to the Console and the clipboard, and message text is truncated
-- to a short sample so a paste-back cannot spill a whole email.

-- Wrapped in a do-block so dofile()ing this twice in one session is
-- harmless: the locals are fresh each time and _G.outlookProbe is simply
-- redefined. A console tool that punishes you for running it twice is a
-- console tool you will hesitate to run at all.
do
    local op = {}

    op.sampleChars = 120     -- how much of any string the report may show
    op.axTimeout   = 0.25    -- see the 🚨 below

    local function trunc(s, n)
        s = tostring(s or ""):gsub("%s+", " ")
        n = n or op.sampleChars
        if #s <= n then return s end
        return s:sub(1, n) .. "…"
    end

    -- ---- 1. which Outlook is this ---------------------------------------
    -- 🚨 6.116.0 — THE VERSION LINE USED TO SAY "?" ON EVERY MAC. It read
    -- the plist with hs.task.new(bin, nil, args) — a nil callback — then
    -- waitUntilExit() and standardOutput(). With no callback there is
    -- nothing collecting the pipe, so standardOutput() comes back empty
    -- and the probe reported "?" for a value sitting in a plain text file
    -- it had just read successfully. It looked like a scripting failure
    -- and was not. A real callback fixes it, and it also removes the last
    -- waitUntilExit() in this file — see the 🧊 note on ask().
    local function appInfo(out, done)
        local app
        pcall(function() app = hs.application.get("Microsoft Outlook") end)
        if not app then
            out[#out + 1] = "   ❌ Outlook is not running — start it and run this again"
            return done(nil)
        end
        local bundle, path = "?", "?"
        pcall(function() bundle = app:bundleID() or "?" end)
        pcall(function() path   = app:path() or "?" end)

        out[#out + 1] = "   bundle : " .. bundle
        -- Reserved now, filled in by the callback, so the three lines keep
        -- their order however late the version arrives.
        local vLine = #out + 1
        out[vLine] = "   version: ?"
        out[#out + 1] = "   path   : " .. path

        local settled = false
        local function got(v)
            if settled then return end
            settled = true
            out[vLine] = "   version: " .. (v and v ~= "" and v or "? (could not read the plist)")
            done(app)
        end
        local ok = pcall(function()
            local t = hs.task.new("/usr/bin/defaults",
                function(code, stdout)
                    local v = tostring(stdout or ""):gsub("%s+$", "")
                    got(code == 0 and v or nil)
                end,
                { "read", path .. "/Contents/Info.plist", "CFBundleShortVersionString" })
            if not t or not t:start() then got(nil) end
        end)
        if not ok then got(nil) end
    end

    -- ---- 2. does AppleScript still answer -------------------------------
    -- The single most important question in this file. If these come back
    -- with real values, the full tracker is buildable. If they error, we
    -- are on Accessibility and the spec has to shrink to what it can see.
    local PROBES = {
        { "is scriptable at all",
          [[tell application "Microsoft Outlook" to return name of it]] },
        { "can list accounts",
          [[tell application "Microsoft Outlook" to return count of exchange accounts]] },
        { "can reach the inbox",
          [[tell application "Microsoft Outlook" to return count of messages of inbox]] },
        -- 🕳 6.116.0 — ADDED AFTER THE FIRST REAL RUN. Every message-level
        -- probe came back "Can't get item 1 of {}", which is an error
        -- ABOUT AN EMPTY LIST, not a refusal — and the difference decides
        -- everything. This asks the question directly so the report states
        -- the count instead of leaving it to be inferred from six errors.
        { "how many messages are SELECTED",
          [[tell application "Microsoft Outlook" to return count of (get current messages)]] },
        { "can read the SELECTED message's subject",
          [[tell application "Microsoft Outlook"
                set m to item 1 of (get current messages)
                return subject of m
            end tell]] },
        { "can read its SENDER",
          [[tell application "Microsoft Outlook"
                set m to item 1 of (get current messages)
                return (address of sender of m) & " / " & (name of sender of m)
            end tell]] },
        { "can read its DATE",
          [[tell application "Microsoft Outlook"
                set m to item 1 of (get current messages)
                return (time received of m) as string
            end tell]] },
        { "can read its RECIPIENTS",
          [[tell application "Microsoft Outlook"
                set m to item 1 of (get current messages)
                set out to ""
                repeat with r in (to recipients of m)
                    set out to out & (address of email address of r) & " "
                end repeat
                return out
            end tell]] },
        { "can list its ATTACHMENTS",
          [[tell application "Microsoft Outlook"
                set m to item 1 of (get current messages)
                set out to ""
                repeat with a in (attachments of m)
                    set out to out & (name of a) & " "
                end repeat
                if out is "" then return "(none on this message)"
                return out
            end tell]] },
        { "can read its BODY text",
          [[tell application "Microsoft Outlook"
                set m to item 1 of (get current messages)
                return plain text content of m
            end tell]] },
    }

    -- ---- 2b. THE CALENDAR, WHICH IS A DIFFERENT QUESTION -----------------
    -- 📅 6.116.0 — LL is on NEW OUTLOOK 16.112.1 on BOTH Macs and asked
    -- about pulling today's meetings into the Pomodoro. Everything above
    -- this line is about MAIL; none of it answers whether the calendar is
    -- readable, and the two are not the same permission, the same
    -- dictionary, or even necessarily the same application.
    --
    -- 🚨 THERE ARE THREE ROUTES AND THEY ARE TESTED IN ORDER OF HOW MUCH I
    -- WOULD RATHER BUILD ON THEM:
    --
    --   A. OUTLOOK'S OWN SCRIPTING. Best if it works — it is the source
    --      of truth and needs no extra setup. Classic Outlook exposes
    --      `calendar events` in full. New Outlook dropped most of the
    --      dictionary, so this is the one being measured, not assumed.
    --
    --   B. macOS CALENDAR.APP, and this is the route people forget. If the
    --      Exchange account is added in System Settings → Internet
    --      Accounts, the same meetings appear in Calendar.app — which has
    --      a full, stable AppleScript dictionary that has nothing to do
    --      with which Outlook build is installed. A New Outlook that
    --      answers nothing in route A can still be completely readable
    --      here. It costs one checkbox in System Settings and no admin.
    --
    --   C. MICROSOFT GRAPH. Not probed, because it cannot be: it needs an
    --      app registration and, on a managed tenant, admin consent. It is
    --      the answer only if A and B are both dead, and it is the one
    --      route that turns a config change into a conversation with IT.
    --
    -- ⚠️ RUNNING THIS MAY RAISE A macOS PERMISSION PROMPT — "osascript
    -- wants to access your calendars". That is expected and it is TCC, not
    -- a bug. Allowing it is what route B needs; denying it makes route B
    -- report ❌ and costs nothing else.
    --
    -- ⏱ AND A SLOW ANSWER IS ITSELF A RESULT. Calendar.app's `whose`
    -- queries can take seconds across many subscribed calendars. Every
    -- query below carries an explicit AppleScript timeout, and the report
    -- prints how long each took — because "it works but takes four
    -- seconds" decides the DESIGN (poll on a timer and cache; never read
    -- the calendar on the keypress that starts a Pomodoro), and that is a
    -- thing to learn now rather than from a wedged keyboard later.
    local CAL_PROBES = {
        { "A · Outlook: has a calendar at all",
          [[with timeout of 15 seconds
                tell application "Microsoft Outlook" to return count of calendars
            end timeout]] },
        { "A · Outlook: can count its events",
          [[with timeout of 15 seconds
                tell application "Microsoft Outlook"
                    return count of calendar events of calendar 1
                end tell
            end timeout]] },
        { "A · Outlook: can read TODAY's events",
          [[with timeout of 20 seconds
                tell application "Microsoft Outlook"
                    set d to current date
                    set hours of d to 0
                    set minutes of d to 0
                    set seconds of d to 0
                    set d2 to d + (1 * days)
                    set out to ""
                    repeat with e in (calendar events of calendar 1)
                        set s to start time of e
                        if s ≥ d and s < d2 then
                            set out to out & (subject of e) & " @ " & (s as string) & " ; "
                        end if
                    end repeat
                    if out is "" then return "(no events today)"
                    return out
                end tell
            end timeout]] },
        { "B · Calendar.app: is reachable",
          [[with timeout of 15 seconds
                tell application "Calendar" to return count of calendars
            end timeout]] },
        -- `name` is what Calendar.app's dictionary calls it; older builds
        -- and some forks answer to `title`. Asking for one and falling
        -- back to the other costs three lines and is the difference
        -- between a calendar list and a bare error on a Mac I cannot see.
        { "B · Calendar.app: which calendars exist",
          [[with timeout of 15 seconds
                tell application "Calendar"
                    set out to ""
                    repeat with c in calendars
                        try
                            set n to name of c
                        on error
                            set n to title of c
                        end try
                        set out to out & n & " ; "
                    end repeat
                    return out
                end tell
            end timeout]] },
        -- The one that decides route B. Deliberately asks EVERY calendar
        -- rather than a guessed-at "Work" one: the Exchange calendar's
        -- title is whatever the account was named, and hardcoding a guess
        -- is how a probe reports "no meetings" on a day full of them.
        { "B · Calendar.app: can read TODAY's events",
          [[with timeout of 30 seconds
                tell application "Calendar"
                    set d to current date
                    set hours of d to 0
                    set minutes of d to 0
                    set seconds of d to 0
                    set d2 to d + (1 * days)
                    set out to ""
                    repeat with c in calendars
                        repeat with e in (every event of c whose start date ≥ d and start date < d2)
                            set out to out & (summary of e) & " @ " & (start date of e as string) & " ; "
                        end repeat
                    end repeat
                    if out is "" then return "(no events today in any calendar)"
                    return out
                end tell
            end timeout]] },
        -- 🚨 6.116.1 — THE PROBE THAT SETTLES IT, ADDED BECAUSE THE HOME
        -- MAC RAN AND THE REPORT STILL COULD NOT ANSWER THE QUESTION.
        -- Calendar.app was reachable and listed seven real calendars, and
        -- then said "no events today in any calendar" — which is produced
        -- IDENTICALLY by two opposite situations:
        --
        --   · a genuinely clear day, and
        --   · an Exchange account that is not syncing into Calendar.app
        --     at all, so every calendar it can see is one that was never
        --     going to hold a work meeting.
        --
        -- One day of nothing distinguishes neither. A fortnight, counted
        -- PER CALENDAR, distinguishes both: if every calendar reports 0
        -- across fourteen days there is no data here to build on, and if
        -- Home has events while Work has none then the account is the
        -- problem rather than the API. Counting rather than listing is
        -- deliberate — a count cannot spill fourteen days of meeting
        -- titles into a paste-back.
        { "B · Calendar.app: events per calendar, ±7 days",
          [[with timeout of 45 seconds
                tell application "Calendar"
                    set d to current date
                    set hours of d to 0
                    set minutes of d to 0
                    set seconds of d to 0
                    set d1 to d - (7 * days)
                    set d2 to d + (7 * days)
                    set out to ""
                    repeat with c in calendars
                        try
                            set n to name of c
                        on error
                            set n to title of c
                        end try
                        set k to count of (every event of c whose start date ≥ d1 and start date < d2)
                        set out to out & n & "=" & k & " ; "
                    end repeat
                    if out is "" then return "(no calendars)"
                    return out
                end tell
            end timeout]] },
    }

    -- 🚨 6.65.1 — OUT OF PROCESS, and in THIS file it matters most of all.
    -- The in-process form (hs.osascript.applescript) sends Apple Events on
    -- Hammerspoon's main thread, and an Objective-C exception from that
    -- machinery ABORTS the app — past any pcall, because a pcall catches
    -- Lua errors and an ObjC exception is not one. See the 🚨 on
    -- ocrWriteFinderComment in init.lua for the crash this caused.
    --
    -- A DIAGNOSTIC MUST NOT BE ABLE TO CRASH THE THING IT IS DIAGNOSING.
    -- This file exists to poke at nine Outlook scripting entry points on a
    -- Mac we know nothing about, which is exactly the situation most
    -- likely to raise one. Every probe is a separate osascript process:
    -- the worst any of them can do is exit non-zero, which is a result.
    --
    -- 🧊 6.116.0 — AND IT NO LONGER BLOCKS. This used to be hs.execute,
    -- with a comment arguing that synchronous was fine because the file
    -- only runs when you type its name. That argument was wrong, and the
    -- first work-Mac run proved it: the very first probe raised the macOS
    -- "allow Hammerspoon to control Outlook?" prompt, which is MODAL and
    -- blocks the osascript process until a human answers — so hs.execute
    -- never returned, and Hammerspoon beachballed with the dialog on top
    -- of it. A permission prompt is not an edge case in this file; it is
    -- the single most likely thing to happen on a Mac we have never
    -- probed, which is the only kind of Mac worth probing.
    --
    -- A DIAGNOSTIC MUST NOT FREEZE THE THING IT IS DIAGNOSING, any more
    -- than it may crash it. So each probe is an hs.task and the report is
    -- assembled in a callback chain. Two properties are preserved from the
    -- old code on purpose:
    --   · SEQUENTIAL, not parallel. Nine osascript processes asking a
    --     mail client nine questions at once is a worse experiment than
    --     one at a time, and it would stack nine permission dialogs.
    --   · ALL ANSWERED BEFORE THE VERDICT. The verdicts compare probes
    --     against each other, so the report is written in the final
    --     callback, not incrementally.
    --
    -- 🚨 AND A WATCHDOG. AppleScript's own `with timeout` does NOT cover
    -- this case: the TCC prompt blocks BEFORE the script starts running,
    -- so the script's timeout never begins. Without a Lua-side timer, a
    -- prompt left unanswered means a task that never exits and a report
    -- that never prints. op.hardTimeout kills it and records the fact,
    -- because "no answer in that long" is itself a finding about this Mac.
    --
    -- ⚠️ INVARIANT: this must EXCEED the longest `with timeout of N` in
    -- any probe below, or the watchdog kills a script that was still
    -- legitimately working and reports a timeout that says more about
    -- this number than about the Mac. The ±7-day calendar probe asks for
    -- 45s; a one-day query already measured 5.7s on the home Mac, so the
    -- headroom is not theoretical.
    op.hardTimeout = 75

    local function ask(src, cb)
        local done = false
        local task, guard
        local function finish(ok, text)
            if done then return end
            done = true
            if guard then pcall(function() guard:stop() end) end
            cb(ok, tostring(text or ""):gsub("%s+$", ""))
        end

        local started = pcall(function()
            task = hs.task.new("/usr/bin/osascript",
                function(code, stdout, stderr)
                    -- stderr carries the useful half: "can't get sender"
                    -- and "not authorised" are different problems with
                    -- different fixes. The old code got this with 2>&1.
                    local body = (stdout or "")
                    if body:gsub("%s+", "") == "" then body = stderr or "" end
                    finish(code == 0, body)
                end,
                { "-e", src })
            if not task or not task:start() then
                finish(false, "osascript could not be started")
            end
        end)
        if not started then
            finish(false, "osascript could not be started")
            return
        end

        guard = hs.timer.doAfter(op.hardTimeout, function()
            if done then return end
            pcall(function() if task then task:terminate() end end)
            finish(false, string.format(
                "no answer in %ds — if a permission dialog is showing, "
                .. "answer it and run the probe again", op.hardTimeout))
        end)
    end

    -- Runs `list` one at a time, calling step(item, ok, result) for each
    -- answer, then done(). The sequential chain lives here so both probe
    -- sections share it rather than each growing their own.
    local function runQueue(list, step, done)
        local i = 0
        local function next()
            i = i + 1
            local item = list[i]
            if not item then return done() end
            ask(item[2], function(ok, res)
                step(item, ok, res)
                next()
            end)
        end
        next()
    end

    local function scriptProbes(out, done)
        local worked, failed = 0, 0
        local vals = {}          -- label → answer, for the verdict below
        runQueue(PROBES, function(p, ok, res)
            if ok then vals[p[1]] = res end
            if ok then
                worked = worked + 1
                out[#out + 1] = string.format("   ✅ %-46s %s", p[1], trunc(res))
            else
                failed = failed + 1
                -- The error text is the useful part: "can't get sender" and
                -- "not authorised" are different problems with different
                -- fixes, and collapsing both to ❌ throws that away. This
                -- is why ask() falls back to stderr when stdout is empty —
                -- osascript writes its errors there, and discarding them
                -- would report every failure as a bare ❌.
                out[#out + 1] = string.format("   ❌ %-46s %s", p[1],
                    trunc(tostring(res):gsub("^.*error[^:]*:%s*", ""), 90))
            end
        end, function() done(worked, failed, vals) end)
    end

    -- 🚨 6.116.1 — THIS VERDICT USED TO COUNT REPLIES, AND IT WAS WRONG ON
    -- THE FIRST MAC IT EVER SAW. The home Mac answered all three route-A
    -- probes — "has a calendar" 1, "can count its events" 0, "today's
    -- events" (none) — and the old rule, routeA >= 3, declared route A the
    -- winner. Outlook holds ZERO events. It is the same hollow dictionary
    -- the mail section had just been taught to catch one screen above,
    -- and the calendar section fell for it because it was counting how
    -- many probes replied instead of reading what they said.
    --
    -- A DIAGNOSTIC THAT MISREADS ITS OWN EVIDENCE IS WORSE THAN NO
    -- DIAGNOSTIC: it is a confident wrong answer, and the whole reason
    -- this file exists is to stop a build resting on one. So the verdict
    -- now looks at VALUES, and a route counts as alive only if it can
    -- produce an actual event.
    local function calendarVerdict(out, vals)
        local function num(s)
            return tonumber((tostring(s or ""):match("^%s*(%-?%d+)")))
        end
        local aCals  = num(vals["A · Outlook: has a calendar at all"])
        local aCount = num(vals["A · Outlook: can count its events"])
        local bCals  = num(vals["B · Calendar.app: is reachable"])
        local window = vals["B · Calendar.app: events per calendar, ±7 days"]

        -- Parse "Work=0 ; Home=12 ; " into a total and the names that
        -- actually carry events, which is the line worth printing.
        local total, withEvents = nil, {}
        if window then
            total = 0
            for name, k in tostring(window):gmatch("([^;=]+)=(%d+)") do
                local n = tonumber(k) or 0
                total = total + n
                if n > 0 then
                    withEvents[#withEvents + 1] = (name:gsub("^%s+", ""):gsub("%s+$", ""))
                        .. " (" .. n .. ")"
                end
            end
        end

        local aAlive = (aCount or 0) > 0
        local bAlive = (bCals or 0) > 0 and (total or 0) > 0

        out[#out + 1] = ""
        if aCals and aCals > 0 and aCount == 0 then
            out[#out + 1] = "   🕳 Outlook reports " .. aCals .. " calendar(s) holding 0"
            out[#out + 1] = "      events. Same hollow shape as the mail section:"
            out[#out + 1] = "      the call answers, and answers nothing."
        end
        if total then
            out[#out + 1] = "   📅 Calendar.app, ±7 days: " .. total .. " event(s) total"
            if #withEvents > 0 then
                out[#out + 1] = "      carried by: " .. table.concat(withEvents, ", ")
            end
        end

        out[#out + 1] = ""
        if aAlive then
            out[#out + 1] = "   ✅ VERDICT: ROUTE A — Outlook answers about its own"
            out[#out + 1] = "      calendar AND actually holds events (" .. aCount .. ")."
            out[#out + 1] = "      Build on this; no extra setup, and it is the"
            out[#out + 1] = "      source of truth rather than a copy of it."
        elseif bAlive then
            out[#out + 1] = "   ✅ VERDICT: ROUTE B — Outlook's own calendar is empty,"
            out[#out + 1] = "      but Calendar.app has real events and a stable"
            out[#out + 1] = "      dictionary. This is the good outcome on New"
            out[#out + 1] = "      Outlook: it works, it survives Outlook updates,"
            out[#out + 1] = "      and it needs no admin. NOTE the timing above —"
            out[#out + 1] = "      whatever is built must poll on a timer and cache,"
            out[#out + 1] = "      never read the calendar on the keypress."
        elseif (bCals or 0) > 0 then
            out[#out + 1] = "   ⚠️ VERDICT: Calendar.app WORKS but has no events in a"
            out[#out + 1] = "      fourteen-day window — so there is nothing here to"
            out[#out + 1] = "      build on yet. The permission and the dictionary"
            out[#out + 1] = "      are fine; the DATA is missing. Most likely the"
            out[#out + 1] = "      Exchange account is not syncing into Calendar.app:"
            out[#out + 1] = "      System Settings → Internet Accounts, add it, tick"
            out[#out + 1] = "      Calendars, then re-run this probe. If the list"
            out[#out + 1] = "      above is all personal calendars, that is exactly"
            out[#out + 1] = "      what happened."
        else
            out[#out + 1] = "   ❌ VERDICT: neither route answered. Before concluding"
            out[#out + 1] = "      Graph is the only way, check whether the macOS"
            out[#out + 1] = "      permission prompt was DENIED — that produces this"
            out[#out + 1] = "      same result and is undone in System Settings →"
            out[#out + 1] = "      Privacy & Security → Calendars."
        end
        return
    end

    -- Same runner as scriptProbes, but it TIMES each answer. How long a
    -- route takes is part of what is being measured, not incidental to it:
    -- a calendar read that costs four seconds cannot sit on a keypress.
    --
    -- ⏱ WALL CLOCK, NOT os.clock(). This measured os.clock() until
    -- 6.116.0, which is CPU time burned by Hammerspoon itself — and the
    -- work being timed happens in a SEPARATE osascript process that
    -- contributes none of it. It under-reported from the day it was
    -- written, and now that the probes are async it would report ~0 for
    -- everything. secondsSinceEpoch answers the question actually being
    -- asked: how long does this Mac make you wait?
    local function calendarProbes(out, done)
        local vals = {}
        local t0 = hs.timer.secondsSinceEpoch()
        runQueue(CAL_PROBES, function(p, ok, res)
            local now = hs.timer.secondsSinceEpoch()
            local ms = math.floor((now - t0) * 1000)
            t0 = now
            -- Only the slow ones get a time. A column of "3ms" on every
            -- row is noise that hides the one row that said 4,200.
            local took = (ms >= 400) and string.format("  [%dms]", ms) or ""
            if ok then
                vals[p[1]] = res
                out[#out + 1] = string.format("   ✅ %-42s %s%s", p[1], trunc(res), took)
            else
                out[#out + 1] = string.format("   ❌ %-42s %s%s", p[1],
                    trunc(tostring(res):gsub("^.*error[^:]*:%s*", ""), 80), took)
            end
        end, function()
            calendarVerdict(out, vals)
            done(vals)
        end)
    end

    -- ---- 3. what Accessibility can see ----------------------------------
    -- The fallback path. Even on New Outlook the reading pane is usually a
    -- tree of AXStaticText, and the message LIST usually exposes rows — so
    -- this reports the shape of what is there rather than trying to parse
    -- it, which is the next conversation, not this one.
    local function axProbe(app, out)
        local granted = false
        pcall(function() granted = hs.accessibilityState() == true end)
        if not granted then
            out[#out + 1] = "   ❌ Accessibility is not granted to Hammerspoon —"
            out[#out + 1] = "      System Settings → Privacy & Security → Accessibility"
            return
        end
        local el
        pcall(function() el = hs.axuielement.applicationElement(app) end)
        if not el then
            out[#out + 1] = "   ❌ no Accessibility element for Outlook"
            return
        end
        -- 🚨 TIMEOUT BEFORE ANY QUESTION. Outlook is a big Electron-era app
        -- and a slow answer here holds the main thread. Same rule as
        -- menubar_items 6.47.0, and for the same reason.
        pcall(function() el:setTimeout(op.axTimeout) end)

        local win
        pcall(function() win = el:attributeValue("AXFocusedWindow") end)
        if not win then
            out[#out + 1] = "   ❌ no focused Outlook window — click one and re-run"
            return
        end
        local title = "?"
        pcall(function() title = win:attributeValue("AXTitle") or "?" end)
        out[#out + 1] = "   focused window: " .. trunc(title)

        -- Walk a bounded distance and count what kinds of thing exist.
        -- BOUNDED IS THE POINT: an unbounded walk of a mail client's view
        -- tree is tens of thousands of nodes and would hang the probe.
        local kinds, seen, budget = {}, 0, 4000
        local function walk(node, depth)
            if seen >= budget or depth > 12 then return end
            local kids
            pcall(function() kids = node:attributeValue("AXChildren") end)
            for _, k in ipairs(kids or {}) do
                if seen >= budget then return end
                seen = seen + 1
                local role
                pcall(function() role = k:attributeValue("AXRole") end)
                if role then kinds[role] = (kinds[role] or 0) + 1 end
                walk(k, depth + 1)
            end
        end
        walk(win, 0)
        local names = {}
        for r in pairs(kinds) do names[#names + 1] = r end
        table.sort(names, function(a, b) return kinds[a] > kinds[b] end)
        out[#out + 1] = string.format("   walked %d elements%s", seen,
            seen >= budget and " (hit the budget — the tree is bigger)" or "")
        for i = 1, math.min(8, #names) do
            out[#out + 1] = string.format("      %-28s %d", names[i], kinds[names[i]])
        end
        out[#out + 1] = "   ↳ AXRow count is the message list; AXStaticText is the"
        out[#out + 1] = "     reading pane. Both non-zero = a tracker is possible"
        out[#out + 1] = "     from Accessibility even if AppleScript said no."
    end

    -- ---- the report ------------------------------------------------------
    -- 🧊 ASYNC SINCE 6.116.0 — this returns immediately and PRINTS LATER.
    -- The old version returned the finished report, which read better in
    -- the Console but froze the app to do it (see the 🧊 note on ask()).
    -- The one line printed up front is not decoration: it is what tells
    -- you the probe is alive while a permission dialog is covering it.
    -- Pass a callback if something ever wants the text programmatically.
    function _G.outlookProbe(cb)
        local out = {
            "════════════════════════════════════════════════════════════",
            " OUTLOOK PROBE   " .. os.date("%Y-%m-%d %H:%M"),
            " Run this with Outlook open and a message showing.",
            "════════════════════════════════════════════════════════════",
            "",
            "── 1. WHICH OUTLOOK ──",
        }

        print(string.format(
            "📧 Outlook probe running — %d probes, one at a time. The report "
            .. "prints below when they are all in.\n"
            .. "   If macOS asks whether Hammerspoon may control Outlook or "
            .. "read Calendars, click Allow —\n"
            .. "   the probe waits for you, and answering DON'T ALLOW is "
            .. "remembered and reported as a refusal.",
            #PROBES + #CAL_PROBES))

        local function finish()
            out[#out + 1] = ""
            out[#out + 1] = "── NEXT ──"
            out[#out + 1] = "   Paste all of the above back. Nothing here was sent"
            out[#out + 1] = "   anywhere — it is on your Console and your clipboard."
            out[#out + 1] = "   Run it on BOTH Macs: the work one is the one that can"
            out[#out + 1] = "   say no, and it is the one the answer has to fit."
            out[#out + 1] = "════════════════════════════════════════════════════════════"

            local text = table.concat(out, "\n")
            print(text)
            pcall(function() hs.pasteboard.setContents(text) end)
            hs.alert.show("📧 Outlook probe copied — paste it back", 3)
            if cb then pcall(cb, text) end
        end

        -- 📅 OUTSIDE the `if app` branch, deliberately. Route B does not
        -- involve Outlook at all: Calendar.app holds the same meetings via
        -- the Exchange account and answers whether Outlook is running,
        -- installed, or scriptable. Skipping this when Outlook is absent
        -- would report "cannot read your calendar" on a Mac that can.
        local function calendarSection()
            out[#out + 1] = ""
            out[#out + 1] = "── 2b. THE CALENDAR (a different question — see the header) ──"
            calendarProbes(out, finish)
        end

        appInfo(out, function(app)
        if not app then return calendarSection() end

        out[#out + 1] = ""
        out[#out + 1] = "── 2. APPLESCRIPT (the full-featured path) ──"
        scriptProbes(out, function(worked, failed, vals)
            out[#out + 1] = ""
            out[#out + 1] = string.format("   %d of %d probes answered", worked, worked + failed)

            -- 🕳 THE HOLLOW-DICTIONARY SIGNATURE, and the reason this
            -- section needs more than a pass/fail count. New Outlook keeps
            -- the old AppleScript vocabulary and stops backing it with
            -- data: the calls SUCCEED and return nothing. An inbox that
            -- answers 0 while section 3 walks rows in that same inbox is
            -- the proof, and it is emphatically NOT a permission problem —
            -- a Mac that refused would ERROR, not answer zero. Called out
            -- on its own line because "3 of 10 answered" reads like
            -- partial access when what is actually there is an empty
            -- shell, and those two lead to completely different builds.
            local inbox    = vals["can reach the inbox"]
            local selected = vals["how many messages are SELECTED"]
            local hollow   = (inbox == "0") or (selected == "0")
            if hollow then
                out[#out + 1] = ""
                out[#out + 1] = "   🕳 HOLLOW DICTIONARY: the calls below answered, but"
                out[#out + 1] = "      answered with NOTHING —"
                if inbox then
                    out[#out + 1] = "        inbox message count ....... " .. inbox
                end
                if selected then
                    out[#out + 1] = "        selected message count .... " .. selected
                end
                out[#out + 1] = "      If section 3 finds AXRows in that same window, the"
                out[#out + 1] = "      messages exist and scripting simply cannot see"
                out[#out + 1] = "      them. This is New Outlook's shape, not a denied"
                out[#out + 1] = "      permission — a refusal errors, it does not say 0."
                out[#out + 1] = "      One confound worth ruling out: if NO message was"
                out[#out + 1] = "      clicked in the reading pane, a selected count of 0"
                out[#out + 1] = "      is honest. The inbox count is the one that cannot"
                out[#out + 1] = "      be explained that way."
            end

            out[#out + 1] = ""
            if hollow then
                out[#out + 1] = "   ❌ VERDICT: the dictionary is present but EMPTY."
                out[#out + 1] = "      Treat this as scripting being closed. Building on"
                out[#out + 1] = "      calls that succeed and return nothing is worse"
                out[#out + 1] = "      than building on calls that fail, because nothing"
                out[#out + 1] = "      errors and the tracker just silently logs zero"
                out[#out + 1] = "      messages forever. Section 3 decides what is left."
            elseif worked >= 6 then
                out[#out + 1] = "   ✅ VERDICT: legacy-style scripting is alive here."
                out[#out + 1] = "      The tracker you asked for is buildable in full —"
                out[#out + 1] = "      sender, recipients, keywords, attachments, dates."
            elseif worked >= 2 then
                out[#out + 1] = "   ⚠️ VERDICT: partial. Some fields are readable and"
                out[#out + 1] = "      some are not — the ❌ lines above are the ones"
                out[#out + 1] = "      that would have to come from Accessibility."
            else
                out[#out + 1] = "   ❌ VERDICT: scripting is closed on this build."
                out[#out + 1] = "      Section 3 decides whether Accessibility can"
                out[#out + 1] = "      carry it instead."
            end
            out[#out + 1] = ""
            out[#out + 1] = "── 3. ACCESSIBILITY (the fallback path) ──"
            axProbe(app, out)
            calendarSection()
        end)
        end)
    end

    -- Registered as a service when the registry is there, so ⇪space's 🔧
    -- rows can still reach it once it has been loaded — but never
    -- required, because this file has to work when it is the only thing
    -- you have typed into a Console on a Mac that is misbehaving.
    if _G.service and _G.service.provide then
        pcall(_G.service.provide, "outlook.probe",
              function() return _G.outlookProbe() end)
    end

    _G.outlookProbeConfig = op
end

print("📧 Outlook probe loaded — run  _G.outlookProbe()  with a message open")
return _G.outlookProbe
