-- =====================================================================
-- MODULE: MACHINE SCAN (_G.workmacbookScan) — one paste that describes
--         the Mac this config is running on
-- =====================================================================
-- LL, 2026-11-14, giving the work MacBook's name at last: "be sure to
-- give me a comprehensive Hammerspoon console report so that when I
-- install this on any work Macbook, I can give you a rich, detailed
-- output, perhaps something like _G.workmacbookScan()."
--
--        _G.workmacbookScan()        the block, in the Console
--        _G.workmacbookScan(true)    the same text, returned
--
-- ---- 🚪 IT IS A DOOR, NOT A TENTH INSTRUMENT ----------------------------
-- 6.317.0's rule, which this project has now paid five times: when he
-- asks for something this config can already answer, the work is a
-- DOOR. Nearly every fact below already exists — `_G.capabilityReport()`
-- has the permissions, `_G.bootReport()` the modules, `_G.stores()` the
-- folders, `_G.snippetsReport()` the library, `_G.selfTest()` whether
-- the tools answer. What has never existed is ONE command that gathers
-- them with the three facts none of them carries: what this Mac is
-- CALLED, which profile that name resolved to and HOW, and which of the
-- external binaries this config reaches for are actually on the disk.
-- So the sections below READ those reports rather than re-deriving
-- them; a second copy of a fact is a fact that will be half-updated
-- (6.363.0).
--
-- ---- 🔒 IT NEVER DOES THE THING (6.413.0) -------------------------------
-- No screenshot is taken, no snippet typed, no file written, no app
-- activated, no process started. Everything here is a stat, a table
-- read or a report asked for its text. A scan that ACTS can break the
-- Mac it is describing — and this one exists to be run on a machine
-- somebody else administers.
--
-- ---- 🔎 AND A SECTION THAT RAISES SAYS SO ------------------------------
-- Each block runs in its own pcall and prints ❔ with the error rather
-- than taking the whole scan down. The one thing a diagnostic must
-- never do is explode (6.282.0), and this is the diagnostic that gets
-- run on the Mac where something is already wrong.
-- =====================================================================

local M = {
    name   = "Machine Scan",
    order  = 99.7,              -- after self_test; it reads what everything else published
    family = "config",
    cheatsheet = {
        title = "🪪 MACHINE SCAN (_G.workmacbookScan — describe this Mac)",
        entries = {
            { "run it",   "_G.workmacbookScan() — one block, in the Console" },
            { "as text",  "_G.workmacbookScan(true) returns it instead" },
            { "says",     "This Mac's name · its profile · permissions ·" },
            { "",         "binaries · folders · snippets · modules · reports" },
            { "for",      "Pasting back from a Mac I cannot see — a work one" },
            { "never",    "Writes, types, captures or starts anything" },
            { "vs 🩺",    "self test asks whether the TOOLS answer" },
            { "vs 🩺",    "install check asks whether the FILES are here" },
        },
    },
}

function M.setup(core)
    -- Bounded on purpose: this walks `_G` and stats a list, and an
    -- unbounded walk in a diagnostic is the diagnostic becoming the
    -- problem (6.197.2). Both bounds are settings, and both are
    -- reported as a FLOOR when they bite rather than as a total.
    local scan = { pathMax = 64, reportMax = 200 }

    local function ok(f, ...)
        local good, v = pcall(f, ...)
        if good then return v end
        return nil, tostring(v)
    end

    -- Every external this config reaches for, with the Homebrew prefixes
    -- BOTH ways round — an Apple-silicon Mac puts brew under
    -- /opt/homebrew and an Intel one under /usr/local, and a work Mac is
    -- as likely to be one as the other. Each row is { label, candidates }
    -- and the scan reports WHICH candidate answered, never that "it is
    -- installed": the path is the actionable half.
    local WANT = {
        { "osascript  (Finder, Chrome, Outlook reads)", { "/usr/bin/osascript" } },
        { "ioreg      (Secure Input)",                  { "/usr/sbin/ioreg" } },
        { "screencapture (⇪4 ⇪5 ⇪⇧2)",                  { "/usr/sbin/screencapture" } },
        { "shortcuts  (OCR)",                           { "/usr/bin/shortcuts" } },
        { "sqlite3    (⇪Y Chrome history, ⇪space index)", { "/usr/bin/sqlite3" } },
        { "rsync      (backups, mirrors)",              { "/usr/bin/rsync" } },
        { "find/grep  (Hamsidian's index)",             { "/usr/bin/find" } },
        { "mdfind     (⇪I, app removal)",               { "/usr/bin/mdfind" } },
        { "mdls       (film codecs)",                   { "/usr/bin/mdls" } },
        { "hidutil    (the ⇪ remap)",                   { "/usr/bin/hidutil" } },
        { "scutil     (this Mac's name)",               { "/usr/sbin/scutil" } },
        { "sw_vers    (the macOS line)",                { "/usr/bin/sw_vers" } },
        { "xattr      (OneDrive placeholders)",         { "/usr/bin/xattr" } },
        { "dict words (autocorrect's spell check)",     { "/usr/share/dict/words" } },
        { "blueutil   (⇪⇧7 connect/disconnect)",
          { "/opt/homebrew/bin/blueutil", "/usr/local/bin/blueutil" } },
        { "brew       (update tracker)",
          { "/opt/homebrew/bin/brew", "/usr/local/bin/brew" } },
        { "zbarimg    (QR fallback)",
          { "/opt/homebrew/bin/zbarimg", "/usr/local/bin/zbarimg" } },
        { "wn         (⇪⇧; define)",
          { "/opt/homebrew/bin/wn", "/usr/local/bin/wn" } },
    }

    -- PURE given a stat function, so the gate proves the whole rule with
    -- no Mac: the FIRST candidate that exists wins, a row where none
    -- exists is NAMED with every path it looked at (a missing binary
    -- whose search path is secret is a missing binary nobody can
    -- install), and a stat that raises is "could not ask" — never
    -- "not there" (6.196.1).
    function M.binaryRows(want, stat)
        local rows = {}
        for _, w in ipairs(want or {}) do
            local label, cands = w[1], w[2] or {}
            local found, failed
            for _, c in ipairs(cands) do
                local good, a = pcall(stat, c)
                if not good then failed = failed or tostring(a)
                elseif a then found = c ; break end
            end
            rows[#rows + 1] = {
                label = label, path = found, tried = cands,
                state = found and "ok" or (failed and "unknown" or "missing"),
                why   = failed,
            }
        end
        return rows
    end

    local function statExists(p)
        return hs.fs and hs.fs.attributes and hs.fs.attributes(p) ~= nil
    end

    -- A folder's three states, and they are not two: there, there and
    -- unwritable, and not there at all. "I could not ask" is a fourth
    -- and reads as its own row rather than as absence.
    function M.folderState(path, stat)
        if not path or path == "" then return "unset", nil end
        local good, a = pcall(stat, path)
        if not good then return "unknown", tostring(a) end
        if not a then return "missing", nil end
        if a.mode and a.mode ~= "directory" then return "notdir", a.mode end
        return "ok", nil
    end

    local function section(L, title, fn)
        L[#L + 1] = ""
        L[#L + 1] = title
        local good, err = pcall(fn)
        if not good then
            L[#L + 1] = "   ❔ this section could not be read — " .. tostring(err)
        end
    end

    function _G.workmacbookScan(asText)
        local L = { "🪪 MACHINE SCAN — Hammerspoon config "
                    .. tostring(_G.configVersion) .. "  ·  "
                    .. os.date("%Y-%m-%d %H:%M:%S") }

        section(L, "── 🪪 this Mac ──", function()
            local id = _G.profileIdentity or {}
            L[#L + 1] = "   name    : " .. tostring(_G.hostRawName or "(macOS would not say)")
            L[#L + 1] = "   tag     : " .. tostring(core.hostTag)
                        .. "   (what every per-Mac filename carries)"
            local how = id.how or "?"
            if how == "exact" then
                L[#L + 1] = "   profile : " .. tostring(_G.moduleProfileName)
                            .. " — matched by name"
            elseif how == "normalised" then
                L[#L + 1] = "   profile : " .. tostring(_G.moduleProfileName)
                            .. " — matched once punctuation was ignored"
            elseif how == "ambiguous" then
                L[#L + 1] = "   profile : ⚠️ DEFAULT — "
                            .. #(id.ambiguous or {}) .. " keys match this name: "
                            .. table.concat(id.ambiguous or {}, " · ")
                            .. " — rename all but one"
            elseif how == "safe mode" then
                L[#L + 1] = "   profile : 🚑 SAFE MODE — delete ~/.hammerspoon/SAFE and reload"
            else
                L[#L + 1] = "   profile : ℹ️ DEFAULT — this Mac has no tuning of its own."
                            .. " Send the name above and it gets one."
            end
            local v = ok(function() return hs.host.operatingSystemVersionString() end)
            L[#L + 1] = "   macOS   : " .. tostring(v or "(could not be read)")
            local loaded, failed = 0, 0
            for _, st in ipairs(_G.moduleStatus or {}) do
                if st.ok then loaded = loaded + 1 else failed = failed + 1 end
            end
            L[#L + 1] = string.format("   loaded  : %d module(s) · %d FAILED · %s ⇪ shortcuts",
                        loaded, failed, tostring(_G.hyperShortcutCount or "?"))
        end)

        section(L, "── 🔑 permissions ──", function()
            local acc = ok(function() return hs.accessibilityState() end)
            L[#L + 1] = "   access  : " .. (acc == true and "✅ granted"
                        or acc == false and "⚠️ NOT GRANTED — taps and hotkeys are dead."
                                            .. " Grant it, then QUIT AND RELAUNCH"
                        or "❔ could not be asked")
            local si = _G.secureInput or {}
            if si.on == true then
                L[#L + 1] = "   secure  : ⚠️ HELD by " .. tostring(si.app)
                            .. " — every tap and hotkey on this Mac is dead"
            elseif si.on == false then
                L[#L + 1] = "   secure  : ✅ clear"
            else
                L[#L + 1] = "   secure  : ❔ " .. tostring(si.why or "not probed yet")
            end
            -- 📏 NAMED RATHER THAN GUESSED: macOS exposes no way to read
            -- an Automation or Screen Recording grant, so this scan does
            -- not pretend to. What it CAN do is name the tools whose
            -- failures would mean a refused grant, and point at the
            -- counts that would show it.
            L[#L + 1] = "   📏 Automation and Screen Recording cannot be READ from here."
            L[#L + 1] = "      Automation shows up as _G.chromeTabsReport() /"
            L[#L + 1] = "      _G.universalActionsReport() refusals; Screen Recording as"
            L[#L + 1] = "      _G.screenshotsReport() captures that write nothing."
        end)

        section(L, "── 🧰 binaries ──", function()
            local rows = M.binaryRows(WANT, statExists)
            local missing = 0
            for i = 1, math.min(#rows, scan.pathMax) do
                local r = rows[i]
                if r.state == "ok" then
                    L[#L + 1] = "   ✅ " .. r.label .. "  →  " .. r.path
                elseif r.state == "unknown" then
                    L[#L + 1] = "   ❔ " .. r.label .. "  — could not ask: " .. tostring(r.why)
                else
                    missing = missing + 1
                    L[#L + 1] = "   ⚠️ " .. r.label .. "  — NOT HERE. Looked in: "
                                .. table.concat(r.tried, " · ")
                end
            end
            L[#L + 1] = "   " .. missing .. " missing — each one is a feature that"
                        .. " degrades and says so, never a config that breaks."
        end)

        section(L, "── 📁 folders ──", function()
            local rows = {
                { "cloud (OneDrive)", core.cloudDir },
                { "logs  (stores)",   core.logsDir },
                { "backup (kit)",     core.backupDir },
                { "config",           core.configDir },
                { "modules",          _G.moduleDir },
            }
            local v = _G.vault
            if v and v.dir then rows[#rows + 1] = { "Hamsidian notes", v.dir } end
            local sh = _G.screenshots
            if sh and sh.dir then rows[#rows + 1] = { "screenshots", sh.dir } end
            for _, r in ipairs(rows) do
                local st, why = M.folderState(r[2], function(p) return hs.fs.attributes(p) end)
                local mark = (st == "ok" and "✅") or (st == "unknown" and "❔") or "⚠️"
                L[#L + 1] = "   " .. mark .. " " .. r[1] .. "  :  "
                            .. tostring(r[2] or "(not resolved)")
                            .. (st == "ok" and "" or ("   [" .. st
                                .. (why and (": " .. why) or "") .. "]"))
            end
            -- 🚨 THE ONE THAT COSTS HIS NOTES. If OneDrive was not found
            -- when this config booted, Hamsidian silently reads a LOCAL
            -- folder, creates it, and honestly reports "no notes yet"
            -- about the wrong place (6.317.0). On a work Mac that is the
            -- likeliest single failure of the lot, so it SHOUTS.
            if not core.cloudDir then
                L[#L + 1] = "   🚨 NO CLOUD FOLDER WAS FOUND AT BOOT — every store and the"
                L[#L + 1] = "      notes are LOCAL ONLY on this Mac. Nothing is lost; it is"
                L[#L + 1] = "      reading the wrong folder. Start OneDrive and reload (⌘⌃R)."
            end
        end)

        section(L, "── ✂️ snippets ──", function()
            -- Asked of the module, never counted here: two counts of one
            -- library is how they come to disagree (6.363.0).
            local n
            if _G.service and _G.service.has and _G.service.has("expander.state") then
                local got = ok(function() return _G.service.call("expander.state") end)
                if type(got) == "table" then n = tonumber(got.count) end
            end
            if type(n) == "number" then
                L[#L + 1] = "   loaded  : " .. n .. " trigger(s)"
                if n == 0 then
                    L[#L + 1] = "   ⚠️ NONE. The four public packs ship INSIDE the archive as"
                    L[#L + 1] = "      snippets/bundled.lua — if that file is missing, the"
                    L[#L + 1] = "      install was partial: _G.installCheck() names it."
                end
            else
                L[#L + 1] = "   loaded  : ❔ the expander did not publish a count"
            end
            L[#L + 1] = "   detail  : _G.snippetsReport() — the packs, the file, the recent queue"
            -- 🔒 AND THE PRIVATE PACK IS NAMED AS ABSENT ON PURPOSE.
            -- textpanders holds real addresses, a phone number and an
            -- employee id. It is in his OneDrive snippets folder and in
            -- NO archive, by a hard rule — so a work Mac without that
            -- folder synced has the public packs and nothing else, and
            -- that is the config working, not a failed install.
            L[#L + 1] = "   📏 A private pack (textpanders) is never in the archive. If it is"
            L[#L + 1] = "      missing here, this Mac has not synced the OneDrive snippets"
            L[#L + 1] = "      folder — that is the cause, and it is not an install fault."
        end)

        section(L, "── 🧩 modules ──", function()
            local bad = {}
            for _, st in ipairs(_G.moduleStatus or {}) do
                if not st.ok then bad[#bad + 1] = "      ⚠️ " .. tostring(st.name)
                                                 .. " — " .. tostring(st.err) end
            end
            if #bad == 0 then
                L[#L + 1] = "   ✅ every module in this profile loaded"
            else
                L[#L + 1] = "   ⚠️ " .. #bad .. " did NOT load:"
                for _, b in ipairs(bad) do L[#L + 1] = b end
            end
        end)

        section(L, "── 📋 what to run next ──", function()
            local names, n = {}, 0
            for k, v in pairs(_G) do
                if n >= scan.reportMax then break end
                if type(v) == "function" and type(k) == "string"
                   and k:match("Report$") then
                    n = n + 1 ; names[#names + 1] = k
                end
            end
            table.sort(names)
            L[#L + 1] = "   " .. #names .. " report(s) are published on this Mac."
            L[#L + 1] = "      ⇪D then @report lists every one with what it answers."
            L[#L + 1] = "      _G.selfTest()      — do the big tools answer?"
            L[#L + 1] = "      _G.installCheck()  — did the whole release land?"
            L[#L + 1] = "      _G.capabilityReport() · _G.stores() · _G.todayReport()"
        end)

        local s = table.concat(L, "\n")
        if asText then return s end
        print(s)
    end

    if core.provide then
        core.provide("machine.scan", function() return _G.workmacbookScan(true) end)
    end
    M.config = scan
end

return M
