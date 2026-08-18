-- =====================================================================
-- MODULE: OUTLOOK PROBE — find out what we can actually read, before
-- building a tracker on top of a guess
-- =====================================================================
-- ⚠️ THIS IS A DIAGNOSTIC, NOT A FEATURE. It binds no key, watches
-- nothing, and runs only when you call it by name. It exists to answer
-- ONE question with evidence instead of assumption:
--
--        _G.outlookProbe()      ← run this with Outlook open, on a message
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
-- WHAT TO DO: open Outlook, click a message so it is showing in the
-- reading pane, then run _G.outlookProbe() in the Hammerspoon Console
-- and paste the output back. Every line is a fact about YOUR Mac.
--
-- 🔒 IT READS, IT DOES NOT SEND. Nothing leaves your machine: the report
-- goes to the Console and the clipboard, and message text is truncated
-- to a short sample so a paste-back cannot spill a whole email.

local M = {
    name  = "Outlook Probe",
    order = 13.85,
    family = "auto",
    summary = "Diagnostic — reports what Outlook will and will not answer",
    cheatsheet = {
        title = "📧 OUTLOOK PROBE (diagnostic — no key)",
        entries = {
            { "console", "_G.outlookProbe() — run it with a message open" },
            { "why",     "Decides whether the email tracker is buildable here" },
            { "safe",    "Reads only · truncates samples · nothing is sent" },
        },
    },
}

function M.setup(core)
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
        out[#out + 1] = ""
        out[#out + 1] = "── NEXT ──"
        out[#out + 1] = "   Paste all of the above back. Nothing here was sent"
        out[#out + 1] = "   anywhere — it is on your Console and your clipboard."
        out[#out + 1] = "════════════════════════════════════════════════════════════"

        local text = table.concat(out, "\n")
        print(text)
        pcall(function() hs.pasteboard.setContents(text) end)
        hs.alert.show("📧 Outlook probe copied — paste it back", 3)
        return text
    end

    core.provide("outlook.probe", function() return _G.outlookProbe() end)

    _G.outlookProbeConfig = op
    M.config = op
end

return M
