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
    local function appInfo(out)
        local app
        pcall(function() app = hs.application.get("Microsoft Outlook") end)
        if not app then
            out[#out + 1] = "   ❌ Outlook is not running — start it and run this again"
            return nil
        end
        local bundle, path, ver = "?", "?", "?"
        pcall(function() bundle = app:bundleID() or "?" end)
        pcall(function() path   = app:path() or "?" end)
        pcall(function()
            local t = hs.task.new("/usr/bin/defaults", nil,
                { "read", path .. "/Contents/Info.plist", "CFBundleShortVersionString" })
            t:start(); t:waitUntilExit()
            ver = (t:standardOutput() or "?"):gsub("%s+$", "")
        end)
        out[#out + 1] = "   bundle : " .. bundle
        out[#out + 1] = "   version: " .. ver
        out[#out + 1] = "   path   : " .. path
        return app
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
    -- hs-lint: allow blocking-main-thread — this file runs ONLY when you
    -- type _G.outlookProbe(). No key, no timer, no watcher. Synchronous is
    -- also correct here: nine probes whose results are compared against
    -- each other must all be answered before the verdict is written.
    local function ask(src)
        local quoted = "'" .. src:gsub("'", [['\'']]) .. "'"
        local okExec, out, ok = pcall(hs.execute, "/usr/bin/osascript -e " .. quoted .. " 2>&1")
        if not okExec then return false, "osascript could not be started" end
        return ok == true, tostring(out or ""):gsub("%s+$", "")
    end

    local function scriptProbes(out)
        local worked, failed = 0, 0
        for _, p in ipairs(PROBES) do
            local label, src = p[1], p[2]
            local ok, res = ask(src)
            if ok then
                worked = worked + 1
                out[#out + 1] = string.format("   ✅ %-46s %s", label, trunc(res))
            else
                failed = failed + 1
                -- The error text is the useful part: "can't get sender" and
                -- "not authorised" are different problems with different
                -- fixes, and collapsing both to ❌ throws that away. 2>&1
                -- on the command is what keeps it — osascript writes its
                -- errors to stderr, which we would otherwise discard and
                -- report every failure as a bare ❌.
                out[#out + 1] = string.format("   ❌ %-46s %s", label,
                    trunc(tostring(res):gsub("^.*error[^:]*:%s*", ""), 90))
            end
        end
        return worked, failed
    end

    -- Same runner as scriptProbes, but it TIMES each answer. See the ⏱
    -- note above: how long a route takes is part of what is being
    -- measured, not incidental to it.
    local function calendarProbes(out)
        local routeA, routeB = 0, 0
        for _, p in ipairs(CAL_PROBES) do
            local label, src = p[1], p[2]
            local t0 = os.clock()
            local ok, res = ask(src)
            local ms = math.floor((os.clock() - t0) * 1000)
            -- Only the slow ones get a time. A column of "3ms" on every
            -- row is noise that hides the one row that said 4,200.
            local took = (ms >= 400) and string.format("  [%dms]", ms) or ""
            if ok then
                if label:sub(1, 1) == "A" then routeA = routeA + 1 else routeB = routeB + 1 end
                out[#out + 1] = string.format("   ✅ %-42s %s%s", label, trunc(res), took)
            else
                out[#out + 1] = string.format("   ❌ %-42s %s%s", label,
                    trunc(tostring(res):gsub("^.*error[^:]*:%s*", ""), 80), took)
            end
        end

        out[#out + 1] = ""
        if routeA >= 3 then
            out[#out + 1] = "   ✅ VERDICT: ROUTE A — Outlook answers about its own"
            out[#out + 1] = "      calendar. Build on this; no extra setup, and it is"
            out[#out + 1] = "      the source of truth rather than a copy of it."
        elseif routeB >= 3 then
            out[#out + 1] = "   ✅ VERDICT: ROUTE B — Outlook will not talk, but"
            out[#out + 1] = "      Calendar.app has the same meetings and a stable"
            out[#out + 1] = "      dictionary. This is the good outcome on New"
            out[#out + 1] = "      Outlook: it works, it survives Outlook updates,"
            out[#out + 1] = "      and it needs no admin — just the Exchange account"
            out[#out + 1] = "      present in System Settings → Internet Accounts."
        elseif routeB >= 1 then
            out[#out + 1] = "   ⚠️ VERDICT: Calendar.app answers, but TODAY'S EVENTS"
            out[#out + 1] = "      did not come back. Most likely the Exchange account"
            out[#out + 1] = "      is not added to Calendar.app — check System"
            out[#out + 1] = "      Settings → Internet Accounts, then re-run. If the"
            out[#out + 1] = "      calendar list above shows only 'Home'/'Birthdays',"
            out[#out + 1] = "      that is exactly what happened."
        else
            out[#out + 1] = "   ❌ VERDICT: neither route answered. Before concluding"
            out[#out + 1] = "      Graph is the only way, check whether the macOS"
            out[#out + 1] = "      permission prompt was DENIED — that produces this"
            out[#out + 1] = "      same result and is undone in System Settings →"
            out[#out + 1] = "      Privacy & Security → Calendars."
        end
        return routeA, routeB
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
    function _G.outlookProbe()
        local out = {
            "════════════════════════════════════════════════════════════",
            " OUTLOOK PROBE   " .. os.date("%Y-%m-%d %H:%M"),
            " Run this with Outlook open and a message showing.",
            "════════════════════════════════════════════════════════════",
            "",
            "── 1. WHICH OUTLOOK ──",
        }
        local app = appInfo(out)
        if app then
            out[#out + 1] = ""
            out[#out + 1] = "── 2. APPLESCRIPT (the full-featured path) ──"
            local worked, failed = scriptProbes(out)
            out[#out + 1] = ""
            out[#out + 1] = string.format("   %d of %d probes answered", worked, worked + failed)
            if worked >= 6 then
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
        end

        -- 📅 OUTSIDE the `if app` block, deliberately. Route B does not
        -- involve Outlook at all: Calendar.app holds the same meetings via
        -- the Exchange account and answers whether Outlook is running,
        -- installed, or scriptable. Nesting this under "is Outlook there"
        -- would report "cannot read your calendar" on a Mac that can.
        out[#out + 1] = ""
        out[#out + 1] = "── 2b. THE CALENDAR (a different question — see the header) ──"
        calendarProbes(out)

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
        return text
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
