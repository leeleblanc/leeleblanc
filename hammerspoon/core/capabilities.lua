-- =====================================================================
-- core/capabilities.lua — how THIS Mac differs, in one place
-- =====================================================================
-- THE PROBLEM THIS SOLVES. One init.lua runs on two very different Macs:
-- a personal MacBook Air with admin rights, and a managed work MacBook
-- with none. Roughly a dozen things legitimately differ between them —
-- OneDrive, Accessibility, the Caps Lock remap, the OCR Shortcut, the
-- Asana token, Homebrew. Every one of those was already handled, and
-- every one printed its own line somewhere at boot. That is the problem:
-- twelve separate lines scattered across a boot log is not an answer to
-- "what works on this machine?" — it is twelve things to go and find.
--
-- This is the answer in one call. Each capability reports:
--   state  ON / OFF / PARTIAL / UNKNOWN
--   why    the actual reason, not a restatement of the state
--   cost   what you lose when it is off — because "OFF" only matters if
--          you know what it takes with it
--
-- WHY IT IS A FUNCTION AND NOT A TABLE. Several of these are decided
-- ASYNCHRONOUSLY after boot: the OCR shortcut probe is an hs.task that
-- finishes whenever it finishes, and modules load on a warm timer. A
-- table built at load time would freeze answers that were not true yet
-- and would report OCR as missing on every Mac. Everything below is read
-- at the moment you ask.
--
-- WHY IT IS core/ AND NOT modules/. The §1.12 loader runs last; this has
-- to be callable from §1.11's diagnostic report, which is built before
-- it. Same reason diagnostics and the cheat sheet are core files.
-- =====================================================================

return function(core)
    local cloudDir      = core.cloudDir
    local logsDir       = core.logsDir
    local backupDir     = core.backupDir
    local hostTag       = core.hostTag
    local asanaEnabled  = core.asanaEnabled
    local secretsStatus = core.secretsStatus
    local hyperEnabled  = core.hyperEnabled

    -- A capability is { key, label, state, why, cost }. state is one of
    -- "ON" | "OFF" | "PARTIAL" | "UNKNOWN". UNKNOWN is a real answer and
    -- deliberately not folded into OFF: "the probe has not finished yet"
    -- and "this Mac cannot do it" need different reactions from me.
    local function cap(key, label, state, why, cost)
        return { key = key, label = label, state = state, why = why, cost = cost }
    end

    -- =================================================================
    -- 🔒 SECURE INPUT — the thing that took LL's keyboard for four hours
    -- =================================================================
    -- 6.196.0. LL: "Something happened. Nothing works." The Console said
    -- "All green · 104 ⇪ shortcuts · 0.44s" and meant every word of it.
    -- Every shortcut was bound. Carbon counted every F18. The event tap
    -- was enabled with zero failures. And nothing worked, for hours,
    -- across two versions and a rollback.
    --
    -- The cause was OUTSIDE this config entirely: Chrome had left macOS
    -- SECURE EVENT INPUT switched on. That is the mode a password field
    -- turns on so no other process can read the keyboard — which is
    -- exactly what an hs.eventtap is. While it is on:
    --      · every event tap stops receiving keys (snippets, autocorrect,
    --        the expander, the key caster, ⇪'s own fallback dispatcher)
    --      · hotkeys stop dispatching, hyper and plain alike
    --      · OTHER apps break too — LL's ⇧Return died in Asana, which is
    --        the tell that separates this from anything we could cause
    -- and macOS reports NOTHING. No error, no notification, no log line.
    --
    -- 🚨 SO THIS IS RULE 7 ("nothing fails silently") APPLIED TO THE ONE
    -- THING THAT CAN FALSIFY THE ENTIRE BOOT REPORT. A config that says
    -- "All green" while the keyboard is locked away is not reporting; it
    -- is guessing and getting lucky. It is not our bug — and saying so
    -- in one line at boot is the difference between four hours and four
    -- seconds.
    --
    -- WHY ioreg AND NOT AN API. macOS exposes IsSecureEventInputEnabled()
    -- in Carbon and Hammerspoon does not bridge it, so the PID holding
    -- it is read where the system publishes it: the IOConsoleUsers
    -- property, key kCGSSessionSecureInputPID. Reading it is how you
    -- would do it by hand, and LL did exactly that to find Chrome.
    --
    -- 🚨 IT NEVER RUNS ON THE MAIN THREAD. `ioreg -l` is a multi-megabyte
    -- dump of the whole IO registry and this config has beachballed LL's
    -- Mac twice already on main-thread work (6.152.x, 6.170.x). So it is
    -- an hs.task, HELD in _G (an unreferenced task is collected and a
    -- collected task never calls back — 6.155.0's rule), narrowed with
    -- -k IOConsoleUsers so the dump is a few lines rather than the lot,
    -- and it falls back to the broad form only if the narrow one finds
    -- nothing. A probe that cannot run reports UNKNOWN and costs nothing.
    local SI_NARROW = { "-n", "Root", "-d1", "-k", "IOConsoleUsers", "-w", "0" }
    local SI_BROAD  = { "-l", "-w", "0" }
    _G.secureInput = _G.secureInput
        or { on = nil, pid = nil, app = nil, at = nil, checks = 0,
             fails = 0, why = "not probed yet", changes = 0, lastSaid = nil,
             -- 6.304.0: three ways a probe can fail, counted APART. One
             -- "failed" total reads the same for all three and names
             -- none of them, and they want different fixes. A table kept
             -- across a reload will not carry these, so every read of
             -- them stays `or 0`.
             refused = 0, timeouts = 0, noBelt = 0 }

    -- PURE, so the gate can prove the parse with no Mac under it. Returns
    -- pid (number) or nil. A PID of 0 is macOS saying "nobody" and must
    -- read as OFF, not as "process 0 has your keyboard".
    function _G.secureInputParse(out)
        if type(out) ~= "string" then return nil end
        local pid = tonumber(out:match('kCGSSessionSecureInputPID"?%s*=%s*(%d+)'))
        if not pid or pid <= 0 then return nil end
        return pid
    end

    -- Names the process. hs.application may not know a PID it never saw
    -- as an app (a helper, a daemon), so an unnamed PID is still reported
    -- BY NUMBER rather than dropped — "something with pid 94680" is a
    -- lead; silence is not.
    local function siName(pid)
        local name
        pcall(function()
            local app = hs.application and hs.application.applicationForPID(pid)
            if app then name = app:name() end
        end)
        return name
    end

    local function siApply(pid, why)
        local si   = _G.secureInput
        local was  = si.on
        si.on   = pid ~= nil
        si.pid  = pid
        si.app  = pid and (siName(pid) or ("pid " .. pid)) or nil
        si.at   = os.time()
        si.why  = why or (pid and "held by " .. tostring(si.app) or "clear")
        si.checks = si.checks + 1
        -- Only a CHANGE is announced. This runs on a timer forever, and a
        -- line every minute saying the same thing is how a real warning
        -- gets scrolled past and then ignored.
        if was ~= nil and was ~= si.on then
            si.changes = si.changes + 1
            if si.on then
                print("🔒 SECURE INPUT IS ON — " .. tostring(si.app) .. " has locked "
                      .. "the keyboard. Snippets, autocorrect and MOST ⇪ shortcuts "
                      .. "will do nothing until it lets go. Not a fault in this "
                      .. "config: quit that app, or leave its password field.")
                if _G.notices then
                    pcall(_G.notices.record, "runtime", "secure input",
                          "on — " .. tostring(si.app))
                    pcall(_G.notices.tell, "🔒 " .. tostring(si.app)
                          .. " has locked the keyboard",
                          "Secure Input is on — most shortcuts are dead until it stops",
                          { key = "secureinput:on", every = 300 })
                end
            else
                print("🔓 Secure Input released — shortcuts, snippets and autocorrect "
                      .. "are live again.")
            end
        end
        return si
    end

    -- ONE probe in flight at a time (the 6.170.1 rule for any external
    -- command on a timer): a slow ioreg under load must not stack up.
    --
    -- 🚨 AND A GUARD THAT ONLY A SUCCESS CAN CLEAR IS A WEDGE (6.304.0).
    -- siBusy short-circuits EVERY later probe and was cleared in exactly
    -- one place — finish(), reachable only from a task callback. So one
    -- ioreg that never called back, or one macOS refused to launch, shut
    -- Secure Input down for the whole session, silently, with the state
    -- reading "not probed yet" for ever and `started` frozen at 1 while
    -- the 60 s timer went on ticking into the short-circuit.
    -- WHY THIS ONE MATTERS MORE THAN ITS SIZE: Secure Input is the thing
    -- that stops every event tap AND hotkey dispatch system-wide with no
    -- error anywhere (6.196.0 — it took the keyboard for four hours). A
    -- probe that has gone quiet and a Mac that is healthy read exactly
    -- the same, which is 6.196.1's rule broken inside the one instrument
    -- built to keep it.
    local siBusy = false
    local siGen  = 0
    local function siProbe(done)
        if siBusy then if done then done(_G.secureInput) end return false end
        if not (hs.task and hs.task.new) then
            _G.secureInput.why = "hs.task is unavailable — cannot probe"
            _G.secureInput.fails = _G.secureInput.fails + 1
            if done then done(_G.secureInput) end
            return false
        end
        siBusy = true
        siGen  = siGen + 1
        local myGen = siGen
        -- STARTED vs CHECKS. `checks` only rises when a probe COMPLETES,
        -- so a probe that starts and dies leaves the state reading
        -- "not probed yet" forever — which is exactly what 6.196.0's
        -- crash looked like from outside: the honest-looking state of a
        -- feature that had never once run. Counting the attempts makes
        -- the difference visible instead of indistinguishable. It is also
        -- what NAMED 6.304.0: started 1 · checks 0, nine ticks after boot.
        _G.secureInput.started = (_G.secureInput.started or 0) + 1
        local answerSecs = tonumber(_G.secureInputAnswerSecs) or 20

        local finish
        -- 🛟 THE BELT IS ARMED BEFORE THE ASK (6.246.0), covers the WHOLE
        -- probe rather than one run (the narrow → broad chain is one
        -- probe), and lives in its OWN held slot (6.196.1). A Mac that
        -- cannot arm a timer still probes — it simply has no belt, and
        -- the report counts that apart rather than implying one is there.
        local beltOK = pcall(function()
            _G.secureInputBelt = hs.timer.doAfter(answerSecs, function()
                _G.secureInput.timeouts = (_G.secureInput.timeouts or 0) + 1
                _G.secureInput.fails    = _G.secureInput.fails + 1
                finish(nil, "ioreg was asked and never answered in "
                            .. answerSecs .. "s", true)
            end)
        end)
        if not beltOK then
            _G.secureInput.noBelt = (_G.secureInput.noBelt or 0) + 1
        end

        finish = function(pid, why, failed)
            -- ANSWERED EXACTLY ONCE, THROUGH ONE DOOR (6.299.0). Two
            -- callers reach here for one probe — the real callback and
            -- the belt — and a callback that arrives AFTER its own belt
            -- fired belongs to a probe that is over: without the
            -- generation check it would close the NEXT probe instead,
            -- which is the same wedge wearing a different hat.
            if myGen ~= siGen or not siBusy then return end
            siBusy = false
            pcall(function()
                if _G.secureInputBelt then _G.secureInputBelt:stop() end
            end)
            _G.secureInputBelt = nil
            if failed then
                -- 🚨 A PROBE THAT COULD NOT RUN IS NOT AN ANSWER, and
                -- routing one through siApply says it is: that function
                -- sets `on = (pid ~= nil)`, so a refused launch reported
                -- "off — nothing is holding the keyboard" off a probe
                -- that never happened. That is the confident lie
                -- 6.196.0's boot line told for four hours, in the one
                -- row that cannot afford it. `checks` must not move
                -- either — it counts COMPLETIONS, and started-vs-checks
                -- is the fingerprint that named this bug in the first
                -- place. The last good reading stands; only `why` moves,
                -- because one failed probe is not evidence the state
                -- changed.
                _G.secureInput.why      = why
                _G.secureInput.failedAt = os.time()
            else
                siApply(pid, why)
            end
            if done then pcall(done, _G.secureInput) end
        end
        -- 🚨 ONE SLOT PER PROBE, NEVER ONE SLOT FOR BOTH (6.196.1). The
        -- fallback below starts while the narrow probe's own callback is
        -- still on the stack. With both tasks sharing a single global,
        -- starting the second DROPPED the only reference to the first —
        -- and hs.task's finaliser then tore down the NSTask and the
        -- callback block underneath the frame that was running it. That
        -- is a use-after-free: Hammerspoon dies natively, with no Lua
        -- error and nothing in the Console, whenever a GC cycle happens
        -- to land inside that window. Separate slots, and the fallback
        -- deferred out of the callback below, close it from both sides.
        _G.secureInputTasks = _G.secureInputTasks or {}
        local function run(slot, args, andThen)
            local why, refused
            local ok = pcall(function()
                local t = hs.task.new("/usr/sbin/ioreg", function(_, so)
                    andThen(_G.secureInputParse(so))
                end, args)
                if not t then
                    why = "hs.task would not make the ioreg task"
                    return
                end
                -- 🔬 :start() REFUSES BY RETURNING FALSE. It does not
                -- throw — extensions/task/libtask.m, task_launch: the
                -- success path pushes the task itself, the @catch pushes
                -- a boolean. So on a refusal this pcall SUCCEEDED, fails
                -- stayed 0, finish was never called and siBusy stayed
                -- true for the session. 6.179.0's read-the-return rule,
                -- and 6.265.0's: a dependency that is MISSING and one
                -- that REFUSES are different failures, and driving the
                -- path with it absent never exercises the second.
                _G.secureInputTasks[slot] = t:start() or false
                if not _G.secureInputTasks[slot] then
                    refused, why = true, "macOS refused to run ioreg"
                end
            end)
            if not ok then why = "ioreg could not be run" end
            if not why then return true end
            _G.secureInput.fails = _G.secureInput.fails + 1
            if refused then
                _G.secureInput.refused = (_G.secureInput.refused or 0) + 1
            end
            finish(nil, why, true)
            return false
        end
        -- Narrow first. The broad form is the fallback and runs ONLY when
        -- the narrow one came back with nothing — which on a healthy Mac
        -- is EVERY time, so this fallback is the normal path, not a rare
        -- one. It is started from a HELD timer rather than directly, so
        -- the narrow callback has RETURNED before anything can release
        -- the task that owns it. Never start a task from inside another
        -- task's callback without stepping off it first.
        run("narrow", SI_NARROW, function(pid)
            if myGen ~= siGen then return end
            if pid then return finish(pid) end
            _G.secureInputHop = hs.timer.doAfter(0, function()
                if myGen ~= siGen then return end
                run("broad", SI_BROAD, function(pid2) finish(pid2) end)
            end)
        end)
        return true
    end
    _G.secureInputCheck = siProbe

    function _G.secureInputReport()
        local si = _G.secureInput
        local L = { "🔒 SECURE INPUT — can anything else read the keyboard?" }
        if si.on == nil then
            L[#L + 1] = "   state  : UNKNOWN — " .. tostring(si.why)
            if (si.started or 0) > 0 and si.checks == 0 then
                L[#L + 1] = "   ⚠️ " .. si.started .. " probe(s) STARTED and none "
                            .. "finished. The ↳ lines below say why; with none of "
                            .. "them, one is still in flight."
            end
            if si.failedAt then
                L[#L + 1] = "   tried  : " .. os.date("%Y-%m-%d %H:%M:%S", si.failedAt)
                            .. " (the last probe that could not answer)"
            end
        elseif si.on then
            L[#L + 1] = "   state  : ON — " .. tostring(si.app) .. " holds it"
            L[#L + 1] = "   costs  : every event tap (snippets, autocorrect, the "
                        .. "expander, ⇪'s fallback) and most hotkeys. Other apps too."
            L[#L + 1] = "   fix    : quit that app, or leave the password field it "
                        .. "is sitting on. Nothing here needs changing."
        else
            L[#L + 1] = "   state  : off — nothing is holding the keyboard"
        end
        L[#L + 1] = string.format("   probes : %d checked · %d failed · %d change(s) seen",
            si.checks or 0, si.fails or 0, si.changes or 0)
        -- THREE WAYS A PROBE CAN FAIL AND THEY WANT DIFFERENT FIXES
        -- (6.196.1): macOS refusing to launch ioreg, ioreg starting and
        -- never answering, and a Mac that could not arm the belt that
        -- tells the first two apart. Printed only when non-zero, so a
        -- healthy Mac stays as quiet as it was (6.269.0).
        if (si.refused or 0) > 0 then
            L[#L + 1] = "   ↳ " .. si.refused .. " × macOS REFUSED to launch ioreg "
                        .. "— hs.task:start() said no, which it does by returning "
                        .. "false rather than throwing"
        end
        if (si.timeouts or 0) > 0 then
            L[#L + 1] = "   ↳ " .. si.timeouts .. " × ioreg started and NEVER "
                        .. "ANSWERED — the belt ended the probe, so the next one runs"
        end
        if (si.noBelt or 0) > 0 then
            L[#L + 1] = "   ⚠️ " .. si.noBelt .. " probe(s) ran with NO belt — this Mac "
                        .. "would not arm a timer, so a hung ioreg can still wedge it"
        end
        if si.at then
            L[#L + 1] = "   last   : " .. os.date("%Y-%m-%d %H:%M:%S", si.at)
        end
        -- ONE string, one print: core/console.lua's repeat gate eats rows
        -- from a report printed line by line (6.179.1).
        print(table.concat(L, "\n"))
        return si
    end

    function _G.capabilities()
        local caps = {}

        -- ---- storage ------------------------------------------------
        caps[#caps + 1] = cloudDir
            and cap("cloud", "OneDrive", "ON",
                    "found at " .. cloudDir,
                    nil)
            or  cap("cloud", "OneDrive", "OFF",
                    "no OneDrive-* folder under ~/Library/CloudStorage",
                    "logs stay local in " .. tostring(logsDir)
                    .. "; the daily backup is disabled; the two Macs do not share "
                    .. "autocorrect.csv or custom_shortcuts.json")

        caps[#caps + 1] = backupDir
            and cap("backup", "Daily backup", "ON",
                    "5:00 PM → " .. backupDir, nil)
            or  cap("backup", "Daily backup", "OFF",
                    "no cloud destination on this Mac",
                    "your config is not copied anywhere automatically")

        -- ---- credentials --------------------------------------------
        -- secretsStatus is "missing" | "loaded" | "broken: <why>", and
        -- broken is NOT the same as missing: missing is a Mac you never
        -- set up, broken is a file that exists and failed to parse, which
        -- is a typo you can fix in thirty seconds once you know.
        if asanaEnabled then
            caps[#caps + 1] = cap("asana", "Asana", "ON", "secret.lua loaded", nil)
        elseif tostring(secretsStatus):match("^broken") then
            caps[#caps + 1] = cap("asana", "Asana", "OFF",
                "secret.lua EXISTS but failed to load — " .. tostring(secretsStatus),
                "every Asana feature is off: ⌃⌥⌘L dashboard, ⌃⌥⌘T task creator, "
                .. "⌃⌥⌘A url formatter, and the Capture Pad's 4 PM send. "
                .. "This one is fixable — the file is there, it just did not parse.")
        else
            caps[#caps + 1] = cap("asana", "Asana", "OFF",
                "no ~/.hammerspoon/secret.lua on this Mac",
                "Asana features off. Copy secret.lua across (it is deliberately "
                .. "per-machine and never synced or backed up).")
        end

        -- ---- permissions --------------------------------------------
        -- The one macOS permission this config genuinely needs. On a
        -- managed Mac IT can withhold it, which is survivable: only the
        -- features that touch OTHER apps' windows stop working.
        local axOK = false
        local axKnown = pcall(function() axOK = hs.accessibilityState() end)
        caps[#caps + 1] = (not axKnown)
            and cap("ax", "Accessibility", "UNKNOWN",
                    "hs.accessibilityState() could not be read", "unclear — re-run ⇪⇧D")
            or (axOK and cap("ax", "Accessibility", "ON", "granted", nil)
                     or cap("ax", "Accessibility", "OFF",
                            "not granted (System Settings → Privacy & Security → Accessibility)",
                            "Window Arranger, App Peek and app summon cannot move or hide "
                            .. "other apps' windows. Hotkeys, pickers, tracking and Asana "
                            .. "all still work."))

        -- ---- secure input (6.196.0) ---------------------------------
        -- 🚨 THIS ONE CAN FALSIFY EVERY ROW ABOVE IT. Accessibility can be
        -- granted, the remap can be on, every module can be loaded, and
        -- with Secure Input held by some other app NONE of it reaches the
        -- keyboard. So it is reported even when off, and its cost names
        -- the symptom LL actually saw rather than the mechanism.
        local si = _G.secureInput or {}
        if si.on == true then
            caps[#caps + 1] = cap("secureinput", "Secure Input", "OFF",
                "ON — " .. tostring(si.app) .. " has locked the keyboard",
                "event taps receive nothing: snippets, autocorrect, the "
                .. "expander and ⇪'s fallback dispatcher are all dead, and "
                .. "most hotkeys will not dispatch. OTHER APPS ARE AFFECTED "
                .. "TOO — that is how you tell it from a fault in here. Quit "
                .. "that app or leave its password field; nothing in this "
                .. "config needs changing.")
        elseif si.on == false then
            caps[#caps + 1] = cap("secureinput", "Secure Input", "ON",
                "off — nothing else is holding the keyboard", nil)
        else
            caps[#caps + 1] = cap("secureinput", "Secure Input", "UNKNOWN",
                tostring(si.why or "not probed yet"),
                "if shortcuts and snippets are dead everywhere at once, run "
                .. "_G.secureInputReport() — that is the state this cannot see")
        end

        -- ---- the hyper key ------------------------------------------
        -- hidutil property --set is per-user and needs no password, but a
        -- managed Mac can still refuse it, and macOS Sonoma+ tightened
        -- this. _G.hyperRemapOK is set by the hs.task callback in §3.12,
        -- so it is nil until that returns — genuinely UNKNOWN, not off.
        if not hyperEnabled then
            caps[#caps + 1] = cap("hyper", "Hyper key (Caps Lock)", "OFF",
                "hyperEnabled = false in init.lua — your choice, not a failure",
                "Caps Lock behaves normally; every ⇪ shortcut is unavailable")
        elseif _G.hyperRemapOK == true then
            caps[#caps + 1] = cap("hyper", "Hyper key (Caps Lock)", "ON",
                "hidutil accepted the remap", nil)
        elseif _G.hyperRemapOK == false then
            caps[#caps + 1] = cap("hyper", "Hyper key (Caps Lock)", "OFF",
                "hidutil refused the remap — " .. tostring(_G.hyperRemapWhy or "no reason given"),
                "every ⇪ shortcut is unavailable. This is the documented "
                .. "macOS Sonoma+ restriction; everything else still works.")
        else
            caps[#caps + 1] = cap("hyper", "Hyper key (Caps Lock)", "UNKNOWN",
                "the hidutil task has not reported back yet", "ask again in a second")
        end

        -- ---- OCR ----------------------------------------------------
        -- Depends on a Shortcut YOU created, per Mac. The probe is async.
        if _G.ocrShortcutAvailable == true then
            caps[#caps + 1] = cap("ocr", "Image OCR", "ON",
                "the Shortcuts app has your OCR shortcut", nil)
        elseif _G.ocrShortcutAvailable == false then
            caps[#caps + 1] = cap("ocr", "Image OCR", "OFF",
                "the Shortcuts app on this Mac has no OCR shortcut by that name",
                "copied images are not read for text and nothing is written to "
                .. "image_text-" .. tostring(hostTag) .. ".csv. Recreate the "
                .. "shortcut to turn it back on.")
        else
            caps[#caps + 1] = cap("ocr", "Image OCR", "UNKNOWN",
                "the Shortcuts probe has not finished yet", "ask again in a second")
        end

        -- ---- Homebrew (the work-Mac question) ------------------------
        -- OPTIONAL, and the only thing here that would ever need IT's
        -- blessing. It powers exactly one feature and nothing else.
        if _G.brewPathInUse then
            caps[#caps + 1] = cap("brew", "Homebrew", "ON",
                "using " .. tostring(_G.brewPathInUse), nil)
        else
            caps[#caps + 1] = cap("brew", "Homebrew", "OFF",
                "no brew found in ~/homebrew, ~/.homebrew, ~/.local/homebrew, "
                .. "/opt/homebrew or /usr/local, and none on your login shell's PATH",
                "⌃⌥⇧U update checks are off. NOTHING ELSE USES BREW — this config "
                .. "installs nothing and needs no admin rights.")
        end

        -- ---- modules ------------------------------------------------
        local failed = _G.moduleFailed or 0
        caps[#caps + 1] = (failed == 0)
            and cap("modules", "Modules", "ON",
                    tostring(_G.moduleLoaded or 0) .. " loaded, none failed", nil)
            or  cap("modules", "Modules", "PARTIAL",
                    tostring(failed) .. " of " .. tostring((_G.moduleLoaded or 0) + failed)
                    .. " failed to load — see the Console for which",
                    "those features are off; the rest are unaffected because the "
                    .. "loader pcalls each module separately")

        return caps
    end

    -- A formatted block, used by ⇪⇧D and callable on its own.
    function _G.capabilityReport()
        local caps = _G.capabilities()
        local lines = { "CAPABILITIES ON " .. tostring(hostTag) }
        local degraded = 0
        for _, c in ipairs(caps) do
            local mark = (c.state == "ON" and "✅")
                      or (c.state == "OFF" and "⚪️")
                      or (c.state == "PARTIAL" and "⚠️") or "❔"
            if c.state ~= "ON" then degraded = degraded + 1 end
            lines[#lines + 1] = string.format("  %s %-22s %-8s %s",
                mark, c.label, c.state, c.why or "")
            if c.cost and c.cost ~= "" then
                -- Wrapped at a readable width: a cost you cannot read is a
                -- cost you will not act on.
                --
                -- 🐛 The first version of this was a one-line conditional,
                -- `line == a or line == b and "" or " "`, and Lua's `and`
                -- binds tighter than `or` — so when the first test was true
                -- the whole expression evaluated to the BOOLEAN true and the
                -- next concat raised "attempt to concatenate a boolean".
                -- Written out properly below. Clever precedence in a
                -- formatting helper buys nothing and costs a crash.
                local first  = "        ↳ "
                local indent = "          "
                local out, line = {}, nil
                for word in tostring(c.cost):gmatch("%S+") do
                    local prefix = (#out == 0) and first or indent
                    if line == nil then
                        line = prefix .. word
                    elseif #line + 1 + #word > 76 then
                        out[#out + 1] = line
                        line = indent .. word
                    else
                        line = line .. " " .. word
                    end
                end
                if line then out[#out + 1] = line end
                for _, l in ipairs(out) do lines[#lines + 1] = l end
            end
        end
        lines[#lines + 1] = (degraded == 0)
            and "  Everything this config can do, this Mac can do."
            or  ("  " .. degraded .. " capability/ies are not fully on — see the ↳ lines "
                 .. "for exactly what that costs you.")
        return table.concat(lines, "\n")
    end

    -- 🔒 THE WATCH. Secure Input comes and goes — a password field takes
    -- it and gives it back — so one reading at boot is a snapshot, not an
    -- answer. The timer is HELD in _G (an unreferenced hs.timer is
    -- collected and a collected timer never fires) and only ever prints a
    -- CHANGE, so a quiet Mac stays quiet.
    --
    -- The FIRST probe runs a few seconds after boot rather than on the
    -- boot path: this is an external command, and the one thing this
    -- config will not spend is main-thread time during startup.
    _G.secureInputEvery = tonumber(_G.secureInputEvery) or 60
    -- How long a probe may go unanswered before the belt ends it. Well
    -- under the poll interval on purpose: a belt that outlives the tick
    -- it protects is a wedge with a longer fuse. Read INSIDE siProbe, not
    -- captured here, so setting it later is real (6.228.0).
    _G.secureInputAnswerSecs = tonumber(_G.secureInputAnswerSecs) or 20
    pcall(function()
        _G.secureInputFirstTimer = hs.timer.doAfter(3, function()
            _G.secureInputCheck(function(si)
                -- The boot line. A clear Mac says NOTHING — the boot report
                -- is already long and "everything is normal" is not news.
                -- A locked one says so before anything else can mislead.
                if si.on then
                    print("🔒 SECURE INPUT IS ON at boot — " .. tostring(si.app)
                          .. " has locked the keyboard. Snippets, autocorrect and "
                          .. "most ⇪ shortcuts will do nothing until it lets go. "
                          .. "This is NOT a fault in this config — quit that app, "
                          .. "or leave the password field it is sitting on. "
                          .. "_G.secureInputReport() has the detail.")
                end
            end)
        end)
        _G.secureInputTimer = hs.timer.doEvery(_G.secureInputEvery, function()
            _G.secureInputCheck()
        end)
    end)

    return { capabilities = _G.capabilities, report = _G.capabilityReport }
end
