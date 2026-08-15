-- =====================================================================
-- core/boot_report.lua — the Console's first impression, 6.44.11
-- =====================================================================
-- Lifted out of init.lua for one reason: while it lived inline it could
-- not be RUN by a test. The suite could only grep init.lua for the
-- strings it prints, which proves the text exists and nothing about
-- whether the logic around it works. A row-flagging rule that decides
-- what you see on every reload deserves better than a text match.
--
-- axOK is passed in rather than read here so the caller decides when to
-- ask macOS about Accessibility — that call is not free, and the test
-- needs to drive both answers.
-- =====================================================================

return function(core)
    local hostTag = core.hostTag
    local cloudDir = core.cloudDir
    local logsDir = core.logsDir
    local backupDir = core.backupDir
    local asanaEnabled = core.asanaEnabled
    local secretsStatus = core.secretsStatus
    local axOK = core.axOK

    -- =====================================================================
    -- BOOT REPORT — 6.44.11: QUIET WHEN HEALTHY, LOUD WHEN NOT
    -- =====================================================================
    -- This used to print fourteen lines on every single reload, healthy or
    -- not. Fourteen lines you have read a hundred times is not information;
    -- it is the thing you scroll past to find the line that matters, and it
    -- competes with the Console output you actually reloaded to look at.
    --
    -- The rule now: SAY WHAT IS WRONG, AND SUMMARISE WHAT IS RIGHT. A clean
    -- boot is two lines. Anything abnormal — a module that failed, a hotkey
    -- conflict, no Accessibility, a broken secret.lua — still prints its own
    -- full line, every time, because those are the lines worth the space.
    --
    -- Nothing was removed: _G.bootReport() prints the complete report on
    -- demand, and bootVerbose(true) makes it print at every boot again. That
    -- preference persists across reloads, which the old flag could not.
    --
    -- Accessibility is read by the CALLER and arrives as core.axOK, so it
    -- can be a row here instead of a straggler line underneath the report.
    --
    -- 🐛 It was read here too, for one version: lifting this block out of
    -- init.lua carried the original `local axOK = false; pcall(...)` along
    -- with it, and that local shadowed the parameter. The effect was that
    -- a Mac WITHOUT Accessibility still booted to "All green" — the single
    -- most important thing this report has to warn about, silently
    -- dropped. The whole-file text audit could not see it; the test that
    -- RUNS this file caught it on its first execution.

    -- Each row: { label, text, isProblem }. isProblem rows print always.
    local bootRows = {
        { "Storage", cloudDir and ("OneDrive found → " .. cloudDir)
                     or ("no OneDrive → local " .. logsDir), cloudDir == nil },
        { "Data", "ALL log/note/history files in " .. logsDir
                  .. "\n             (per-machine files tagged -" .. hostTag
                  .. " · shared: autocorrect.csv, custom_shortcuts.json)", false },
        { "Backup", (backupDir or "disabled (no cloud destination)")
                    .. " (secret.lua excluded)", backupDir == nil },
        { "Asana", asanaEnabled and "ON (secret.lua loaded)"
                   or ("OFF — secret.lua " .. secretsStatus), not asanaEnabled },
        { "Autocorrect", _G.autocorrectStatus or "off", false },
        -- The expander is the SECOND global keystroke tap in this config,
        -- and the one whose failure is invisible from the keyboard: a
        -- trigger that does nothing looks identical to a trigger you
        -- mistyped. It says its state at every boot for that reason.
        -- This line runs BEFORE warm(), so "snippets loading…" here is
        -- accurate rather than optimistic.
        { "Snippets", (_G.textExpander and _G.textExpander.status) or "off (not loaded)",
          (_G.textExpander and _G.textExpander.status or ""):sub(1, 3) == "OFF" },
        { "Hotkeys", _G.hotkeyBoundCount .. " global bound, "
            .. (_G.hotkeyConflictCount == 0 and "no internal conflicts"
                or (_G.hotkeyConflictCount .. " CONFLICTS — see warnings above"))
            .. " (other apps' shortcuts aren't detectable)",
            (_G.hotkeyConflictCount or 0) > 0 },
        { "Boot", string.format("%.2fs to here  ·  ⇪⇧D writes a diagnostic report",
            hs.timer.secondsSinceEpoch() - (_G.diagBootStart or hs.timer.secondsSinceEpoch())),
            false },
        { "Modules", tostring(_G.moduleLoaded or 0) .. " loaded, "
            .. tostring(_G.moduleFailed or 0) .. " failed  ·  profile: "
            .. tostring(_G.moduleProfileName) .. "  ·  " .. tostring(_G.moduleDir),
            (_G.moduleFailed or 0) > 0 },
        { "Hyper", tostring(_G.hyperShortcutCount or 0)
            .. " shortcuts on ⇪ (Caps Lock) + " .. tostring(_G.hyperForwardCount or 0)
            .. " keys forwarding ⌘⇧⌃⌥, "
            .. ((_G.hyperConflictCount or 0) == 0 and "no conflicts"
                or (_G.hyperConflictCount .. " CONFLICTS — see warnings above")),
            (_G.hyperConflictCount or 0) > 0 },
        { "Access", axOK and "Accessibility granted"
            or "NOT granted — window features inactive (System Settings → Privacy & Security → Accessibility)",
            not axOK },
    }

    function _G.bootReport()
        print("🧭 PORTABILITY REPORT — " .. hostTag)
        for _, r in ipairs(bootRows) do
            print(string.format("   %-11s %s", r[1] .. ":", r[2]))
        end
        return #bootRows
    end

    -- Persisted, so it survives the reload you set it before.
    function _G.bootVerbose(on)
        if on == nil then return hs.settings.get("hsBootVerbose") == true end
        hs.settings.set("hsBootVerbose", on and true or false)
        print("🧭 Boot report is now " .. (on and "VERBOSE — the full report prints every reload."
                                              or "QUIET — two lines unless something is wrong.")
              .. " Takes effect on the next reload; _G.bootReport() prints it right now.")
        return on and true or false
    end

    if hs.settings.get("hsBootVerbose") == true then
        _G.bootReport()
    else
        local problems = {}
        for _, r in ipairs(bootRows) do if r[3] then problems[#problems + 1] = r end end
        print(string.format("🧭 %s  ·  %s modules  ·  %s ⇪ shortcuts  ·  %.2fs",
            hostTag, tostring(_G.moduleLoaded or 0), tostring(_G.hyperShortcutCount or 0),
            hs.timer.secondsSinceEpoch() - (_G.diagBootStart or hs.timer.secondsSinceEpoch())))
        if #problems == 0 then
            -- 🚨 6.76.0 — "All green" ONCE MEANT "nothing complained".
            -- LL's work Mac printed this line under "80 ⇪ shortcuts" while
            -- not one of them worked: every shortcut had registered, and
            -- registering is not firing. §3.12 now presses one for real two
            -- seconds from here, and this line says so rather than letting
            -- the word "green" cover a key nobody has tried yet. Same
            -- reasoning as the warm-phase note above it — this summary
            -- prints before the things it would most like to promise.
            print("   All green." .. (_G.hyperSelfTestPending
                    and "  ⇪ is pressed for real in 2s — a failure will say so."
                    or "")
                  .. "  ⇪⇧D diagnostic report  ·  _G.bootReport() for the full detail")
        else
            for _, r in ipairs(problems) do
                print(string.format("   ⚠️ %-11s %s", r[1] .. ":", r[2]))
            end
            print("   _G.bootReport() prints everything, including what is fine.")
        end
    end


    -- Handed back so a test can drive the real rows and the real
    -- formatter instead of asserting on init.lua's source text.
    return { rows = bootRows, report = _G.bootReport, verbose = _G.bootVerbose }
end
