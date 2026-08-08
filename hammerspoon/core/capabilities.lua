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

    return { capabilities = _G.capabilities, report = _G.capabilityReport }
end
