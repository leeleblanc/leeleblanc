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
             fails = 0, why = "not probed yet", changes = 0, lastSaid = nil }

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
    local siBusy = false
    local function siProbe(done)
        if siBusy then if done then done(_G.secureInput) end return false end
        if not (hs.task and hs.task.new) then
            _G.secureInput.why = "hs.task is unavailable — cannot probe"
            _G.secureInput.fails = _G.secureInput.fails + 1
            if done then done(_G.secureInput) end
            return false
        end
        siBusy = true
        local function finish(pid, why)
            siBusy = false
            siApply(pid, why)
            if done then pcall(done, _G.secureInput) end
        end
        local function run(args, andThen)
            local ok = pcall(function()
                _G.secureInputTask = hs.task.new("/usr/sbin/ioreg", function(_, so)
                    andThen(_G.secureInputParse(so))
                end, args):start()
            end)
            if not ok then
                _G.secureInput.fails = _G.secureInput.fails + 1
                finish(nil, "ioreg could not be run")
            end
        end
        -- Narrow first. The broad form is the fallback and runs ONLY when
        -- the narrow one came back with nothing, so the expensive dump is
        -- not the normal path.
        run(SI_NARROW, function(pid)
            if pid then return finish(pid) end
            run(SI_BROAD, function(pid2) finish(pid2) end)
        end)
        return true
    end
    _G.secureInputCheck = siProbe

    function _G.secureInputReport()
        local si = _G.secureInput
        local L = { "🔒 SECURE INPUT — can anything else read the keyboard?" }
        if si.on == nil then
            L[#L + 1] = "   state  : UNKNOWN — " .. tostring(si.why)
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
