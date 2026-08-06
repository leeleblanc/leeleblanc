-- =====================================================================
-- MODULE: APP UPDATE TRACKER (was §3.10) — ⌃⌥⇧U · batch-check before an IT ticket
-- =====================================================================
-- Answers "which of my apps are behind RIGHT NOW?" so updates can be
-- batched into one IT ticket instead of installing them piecemeal.
-- HONEST LIMIT up front: no vendor here publishes a public release
-- schedule (Chrome is the closest exception — a new stable roughly
-- every 4 weeks — everything else ships whenever the vendor ships).
-- This tracker does not predict the future; it checks the PRESENT:
-- the version actually installed (read straight from each app's own
-- Info.plist) against the latest version Homebrew's Cask database
-- knows about — which tracks upstream release info for these apps
-- whether or not you actually installed them via Homebrew.
--
-- REQUIRES Homebrew (`brew`) on this Mac, used purely as a read-only
-- version oracle — nothing is installed or modified by this tracker;
-- it only reports. No Homebrew found → the feature politely reports
-- itself off in the boot log, same as Asana without secret.lua.
--
-- ✏️ EDIT THIS TABLE — one row per tracked app, mapping its process
-- name to its Homebrew Cask token (the part after /cask/ at
-- formulae.brew.sh). If the app's actual /Applications bundle name
-- differs from its process name (only Sublime Text does, here),
-- set appBundle. A renamed or wrong cask token is never silent: brew's
-- own error is caught and printed in the Console naming exactly which
-- row needs fixing.
-- ⚠️ These tokens are written from general knowledge, not verified
-- live against Homebrew from this machine — check the Console after
-- the first run and fix any row it flags.
-- Wrapped in do...end: this file's main chunk is already near Lua's
-- 200-local-variable ceiling (a single-file config this large adds up
-- fast), and everything in this section is self-contained — nothing
-- outside §3.10 references these locals by name. Scoping them frees
-- their slots for the rest of the file, the same reason §0.2 wraps its
-- secret.lua loading in its own do...end block.

-- (The original §3.10 wrapped its locals in a do...end block to stay under
-- init.lua's 200-local budget. That wrapper is gone: the body now lives
-- inside M.setup(), which is a function and scopes them already.)

-- Moved out of init.lua in 6.40.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "App Update Tracker",
    order = 9,
    cheatsheet = {
        title = "📦 APP UPDATES",
        entries = {
            { "⇪U", "Which apps are behind right now (searchable)" },
            { "auto 9:00 AM  ·  auto on open", "Always checks fresh" },
            { "Enter (brew-managed)", "Installs the update via Homebrew" },
            { "Enter (not brew-managed)", "Opens the vendor's download page" },
            { "⬆️ Upgrade ALL row", "Installs every brew-managed update at once" }
        },
    },
}

function M.setup(core)


    -- ✏️ `url` is the vendor's official download/update page — offered as
    -- the fallback action (Enter opens it in your browser) whenever a
    -- Homebrew install isn't possible or isn't safe (see §3.10.1 below).
    -- These are written from general knowledge, not verified live from
    -- this machine — spot-check each one once; unlike a cask token, a
    -- stale URL can't self-diagnose (a dead link just opens a 404, it
    -- doesn't error back into the Console the way brew does).
    local updateTrackerApps = {
        { app = "1Password",           cask = "1password",           url = "https://1password.com/downloads/mac/" },
        { app = "Alfred",               cask = "alfred",               url = "https://www.alfredapp.com/" },
        { app = "Bartender",            cask = "bartender",            url = "https://www.macbartender.com/" },
        { app = "CotEditor",            cask = "coteditor",            url = "https://coteditor.com/" },
        { app = "Ghostty",               cask = "ghostty",               url = "https://ghostty.org/download" },
        { app = "Google Chrome",        cask = "google-chrome",        url = "https://www.google.com/chrome/" },
        { app = "OneDrive",              cask = "onedrive",              url = "https://www.microsoft.com/en-us/microsoft-365/onedrive/download" },
        -- No cask: Defender for Mac is an enterprise product distributed
        -- via Microsoft's own installer / MDM (Intune, Jamf), not Homebrew
        -- — confirmed by brew itself: "No Cask with this name exists."
        -- The download link is the ONLY automatic action available for
        -- this row (see §3.10.1) since there's no brew path at all.
        { app = "Microsoft Defender",   cask = nil,                     url = "https://www.microsoft.com/en-us/microsoft-365/microsoft-defender-for-individuals" },
        { app = "Microsoft Excel",      cask = "microsoft-excel",      url = "https://www.microsoft.com/en-us/microsoft-365/excel" },
        { app = "Microsoft PowerPoint", cask = "microsoft-powerpoint", url = "https://www.microsoft.com/en-us/microsoft-365/powerpoint" },
        { app = "Microsoft Word",       cask = "microsoft-word",       url = "https://www.microsoft.com/en-us/microsoft-365/word" },
        { app = "Microsoft Outlook",    cask = "microsoft-outlook",    url = "https://www.microsoft.com/en-us/microsoft-365/outlook/email-and-calendar-software-microsoft-outlook" },
        { app = "Microsoft Teams",      cask = "microsoft-teams",      url = "https://www.microsoft.com/en-us/microsoft-teams/download-app" },
        { app = "NordVPN",               cask = "nordvpn",               url = "https://nordvpn.com/download/mac/" },
        { app = "Rectangle",             cask = "rectangle",             url = "https://rectangleapp.com/" },
        { app = "Shottr",                cask = "shottr",                url = "https://shottr.cc/" },
        { app = "Sublime", appBundle = "Sublime Text", cask = "sublime-text", url = "https://www.sublimetext.com/download" },
        { app = "Transmission",          cask = "transmission",          url = "https://transmissionbt.com/download" },
    }

    local updateTrackerMods       = {"ctrl", "alt", "shift"}
    local updateTrackerKey        = "U"
    local updateTrackerFile       = core.logsDir .. "/app_updates-" .. core.hostTag .. ".csv"
    local updateTrackerCheckTime  = "09:00"   -- daily automatic check, 24h format

    -- Homebrew's install location differs between Apple Silicon and Intel
    -- Macs; check both rather than assuming one.
    local brewPath = nil
    for _, candidate in ipairs({ "/opt/homebrew/bin/brew", "/usr/local/bin/brew" }) do
        local f = io.open(candidate, "r")
        if f then f:close(); brewPath = candidate; break end
    end

    local updateStatusLabel = {
        ["update-available"] = "🔔 Update available",
        ["check-failed"]      = "⚠️ Check failed",
        ["unknown-cask"]      = "❓ Unknown cask token",
        ["no-cask"]           = "🔍 No Homebrew cask — check manually",
        ["not-installed"]     = "— Not installed here",
        ["up-to-date"]        = "✅ Up to date",
        ["not-checked"]       = "… Not checked yet",
    }
    local updateStatusOrder = {
        ["update-available"] = 1, ["check-failed"] = 2, ["unknown-cask"] = 3,
        ["not-installed"] = 4, ["no-cask"] = 5, ["not-checked"] = 6, ["up-to-date"] = 7,
    }

    -- Loaded from disk at boot (so results survive a reload) and rewritten
    -- after every check. Keyed by app name, same shape either way:
    -- { installed=, latest=, status=, checkedAt= }
    _G.updateTrackerResults = {}

    local function loadUpdateResults()
        local f = io.open(updateTrackerFile, "r")
        if not f then return end
        local content = f:read("*a"); f:close()
        local first = true
        for line in content:gmatch("([^\r\n]+)") do
            if not (first and line:match("^checked_at,")) then
                local c = core.splitCSVLine(line)
                if c[2] and c[2] ~= "" then
                    _G.updateTrackerResults[c[2]] = {
                        checkedAt   = c[1] or "", installed = c[3] or "",
                        latest      = c[4] or "", status    = c[5] or "not-checked",
                        brewManaged = (c[6] == "true"),
                    }
                end
            end
            first = false
        end
    end
    loadUpdateResults()

    local function saveUpdateResults()
        local f = io.open(updateTrackerFile, "w")
        if not f then core.warnWriteFailed("app update tracker CSV"); return end
        f:write("checked_at,app,installed_version,latest_version,status,brew_managed\n")
        for _, entry in ipairs(updateTrackerApps) do
            local r = _G.updateTrackerResults[entry.app]
            if r then
                f:write(core.csvQuote(r.checkedAt) .. "," .. core.csvQuote(entry.app) .. ","
                    .. core.csvQuote(r.installed) .. "," .. core.csvQuote(r.latest) .. ","
                    .. core.csvQuote(r.status) .. "," .. core.csvQuote(tostring(r.brewManaged == true)) .. "\n")
            end
        end
        f:close()
    end

    -- Some apps version their own /Applications bundle name (Alfred ships
    -- as "Alfred 5.app", Bartender as "Bartender 5.app", not a fixed
    -- "Alfred.app" / "Bartender.app") — an exact-name guess wrongly reports
    -- these as "not installed" even when they are. Falls back to a prefix
    -- scan of /Applications (first matching "<name>*.app" wins) before
    -- giving up; entry.appBundle still short-circuits this for anything
    -- that needs an exact override.
    -- _G. so §3.7's App Monitor can reuse this same resolver (see the
    -- 6.16.1 fix note there) without a second copy of this logic.
    _G.findAppBundle = function(name)
        local exact = "/Applications/" .. name .. ".app"
        if hs.fs.attributes(exact, "mode") == "directory" then return exact end

        local found = nil
        pcall(function()
            for entry in hs.fs.dir("/Applications") do
                if found == nil and entry:sub(1, #name) == name and entry:sub(-4) == ".app" then
                    found = "/Applications/" .. entry
                end
            end
        end)
        return found
    end

    local isUpdateCheckRunning = false

    -- Runs the whole batch: for every tracked app, two async subprocesses
    -- (installed version via `defaults read`, latest version via
    -- `brew info --cask --json=v2`) race in parallel; this app's row is
    -- only finalized once both land. onComplete (optional) fires once
    -- every app has resolved.
    local function runUpdateCheck(onComplete)
        if isUpdateCheckRunning then
            hs.alert.show("⚠️ Update check already running…")
            return
        end
        if not brewPath then
            hs.alert.show("⚠️ Homebrew not found — App Update Tracker needs it (see §3.10)")
            return
        end

        isUpdateCheckRunning = true
        hs.alert.show("🔄 Checking " .. #updateTrackerApps .. " apps for updates…")

        local remaining = #updateTrackerApps

        local function finishOne()
            remaining = remaining - 1
            if remaining == 0 then
                isUpdateCheckRunning = false
                saveUpdateResults()
                local staleCount = 0
                for _, r in pairs(_G.updateTrackerResults) do
                    if r.status == "update-available" then staleCount = staleCount + 1 end
                end
                hs.alert.show(staleCount == 0
                    and "✅ All tracked apps are up to date"
                    or ("🔔 " .. staleCount .. " app(s) have updates available — ⌃⌥⇧U to review"), 4)
                if onComplete then onComplete() end
            end
        end

        for _, entry in ipairs(updateTrackerApps) do
            local bundleName = entry.appBundle or entry.app
            -- brewCheckDone starts TRUE when there's no cask at all — there's
            -- nothing to check, so it shouldn't block finishing.
            local partial = { installedDone = false, latestDone = false, brewCheckDone = not entry.cask }

            local function maybeFinish()
                if not (partial.installedDone and partial.latestDone and partial.brewCheckDone) then return end
                local status
                if not entry.cask then
                    -- No Homebrew cask exists for this app (see the note by
                    -- its entry in updateTrackerApps) — nothing to compare
                    -- against, so this is informational, not a check failure.
                    status = partial.installed and "no-cask" or "not-installed"
                elseif partial.checkErr then
                    status = "check-failed"
                elseif not partial.installed then
                    status = "not-installed"
                elseif not partial.latest then
                    status = "unknown-cask"
                elseif partial.installed == partial.latest then
                    status = "up-to-date"
                else
                    status = "update-available"
                end
                _G.updateTrackerResults[entry.app] = {
                    installed   = partial.installed or "",
                    latest      = partial.latest or "",
                    status      = status,
                    checkedAt   = os.date("%Y-%m-%d %H:%M:%S"),
                    brewManaged = partial.brewManaged or false,
                }
                finishOne()
            end

            -- Installed version: read straight from the app's own bundle,
            -- independent of how (or whether) it was installed via brew.
            -- findAppBundle handles apps whose .app folder is itself
            -- versioned on disk (Alfred 5.app, Bartender 5.app…).
            local appPath = _G.findAppBundle(bundleName)
            if appPath then
                hs.task.new("/usr/bin/defaults", function(exitCode, stdOut)
                    if exitCode == 0 and stdOut and #stdOut > 0 then
                        partial.installed = (stdOut:gsub("%s+$", ""))
                    end
                    partial.installedDone = true
                    maybeFinish()
                end, { "read", appPath .. "/Contents/Info.plist",
                       "CFBundleShortVersionString" }):start()
            else
                partial.installedDone = true
                maybeFinish()
            end

            -- Latest known version, per Homebrew's Cask database — skipped
            -- entirely when this app has no cask token (entry.cask == nil):
            -- there's no Homebrew lookup to make, so there's nothing to fail.
            if entry.cask then
                hs.task.new(brewPath, function(exitCode, stdOut, stdErr)
                    if exitCode == 0 and stdOut then
                        local ok, data = pcall(hs.json.decode, stdOut)
                        if ok and data and data.casks and data.casks[1] and data.casks[1].version then
                            partial.latest = tostring(data.casks[1].version)
                        end
                    else
                        partial.checkErr = true
                        print("⚠️ App Update Tracker: brew couldn't resolve cask '" .. entry.cask
                            .. "' for " .. entry.app .. " — check the token in updateTrackerApps (§3.10)"
                            .. ((stdErr and stdErr ~= "") and (": " .. stdErr:gsub("\n", " ")) or ""))
                    end
                    partial.latestDone = true
                    maybeFinish()
                end, { "info", "--cask", entry.cask, "--json=v2" }):start()

                -- §3.10.1: is this cask actually tracked by brew as
                -- INSTALLED (in its Caskroom)? `brew info` above only tells
                -- us the latest upstream version exists — it says nothing
                -- about how THIS app got onto THIS Mac. Most of these were
                -- almost certainly installed by direct download, not brew,
                -- so `brew upgrade --cask` would have nothing to upgrade
                -- (or worse, try to install fresh over an existing app).
                -- `brew list --cask --versions` exits 0 only when brew's own
                -- Caskroom has a record — that's the one-key-install gate.
                hs.task.new(brewPath, function(exitCode)
                    partial.brewManaged = (exitCode == 0)
                    partial.brewCheckDone = true
                    maybeFinish()
                end, { "list", "--cask", "--versions", entry.cask }):start()
            else
                partial.latestDone = true
                maybeFinish()
            end
        end
    end

    -- §3.10.1 HOMEBREW INSTALL — only ever offered for a row that is BOTH
    -- "update-available" AND brewManaged (see the check above): those are
    -- the only casks safe to hand straight to `brew upgrade` unattended.
    -- Runs one or many tokens in a single brew invocation (the "Upgrade
    -- ALL" row batches every eligible app into one call), then re-runs the
    -- full check so the picker reflects what actually happened rather than
    -- assuming success.
    local function brewUpgradeCasks(tokens)
        if not brewPath or #tokens == 0 then return end
        hs.alert.show("⬆️ Installing " .. #tokens .. " update(s) via Homebrew…", 4)
        local args = { "upgrade", "--cask" }
        for _, t in ipairs(tokens) do table.insert(args, t) end
        hs.task.new(brewPath, function(exitCode, stdOut, stdErr)
            if exitCode == 0 then
                hs.alert.show("✅ Homebrew finished — re-checking…", 3)
            else
                hs.alert.show("⚠️ Homebrew install had errors — check Console, ⌃⌥⇧U to re-check", 5)
                print("🚨 brew upgrade error: " .. tostring(stdErr))
            end
            runUpdateCheck()
        end, args):start()
    end

    -- ---- picker (⌃⌥⇧U) ----------------------------------------------------
    -- Enter's action depends on the row (see renderUpdateChoices below):
    --   🍺 update-available + brew-managed → installs via `brew upgrade`
    --   🌐 update-available (not brew-managed) or no-cask, with a URL
    --                                       → opens the vendor's download page
    --   otherwise                          → copies "installed → latest"
    _G.choosers.appUpdates = hs.chooser.new(function(choice)
        if not choice then return end

        if choice.isUpgradeAll then
            brewUpgradeCasks(choice.tokens)
            return
        end
        if not choice.appName then return end

        if choice.action == "brew" and choice.cask then
            brewUpgradeCasks({ choice.cask })
            return
        end
        if choice.action == "url" and choice.url then
            hs.urlevent.openURL(choice.url)
            hs.alert.show("🌐 Opening " .. choice.appName .. "'s download page…")
            return
        end

        local copied = choice.appName .. ": " .. (choice.installed or "") .. " → " .. (choice.latest or "")
        hs.pasteboard.setContents(copied)
        hs.alert.show("📋 Copied")
    end)
    _G.choosers.appUpdates:placeholderText("App updates — type to filter, Enter acts on a row")

    local function renderUpdateChoices(query)
        local q = (query or ""):lower():match("^%s*(.-)%s*$")
        local rows = {}
        for _, entry in ipairs(updateTrackerApps) do
            local r = _G.updateTrackerResults[entry.app]
            table.insert(rows, {
                appName     = entry.app,
                installed   = r and r.installed or "",
                latest      = r and r.latest or "",
                status      = r and r.status or "not-checked",
                cask        = entry.cask,
                url         = entry.url,
                brewManaged = r and r.brewManaged or false,
            })
        end
        table.sort(rows, function(a, b)
            local oa, ob = updateStatusOrder[a.status] or 9, updateStatusOrder[b.status] or 9
            if oa ~= ob then return oa < ob end
            return a.appName < b.appName
        end)

        local choices = {}

        -- "Upgrade ALL" synthetic row — only while the box is empty (so it
        -- doesn't linger while filtering for something specific), and only
        -- when at least one update-available app is actually brew-managed.
        if q == "" then
            local tokens, names = {}, {}
            for _, row in ipairs(rows) do
                if row.status == "update-available" and row.brewManaged and row.cask then
                    table.insert(tokens, row.cask)
                    table.insert(names, row.appName)
                end
            end
            if #tokens > 0 then
                table.insert(choices, {
                    text         = "⬆️ Upgrade ALL " .. #tokens .. " brew-managed app(s) now",
                    subText      = table.concat(names, ", "),
                    isUpgradeAll = true,
                    tokens       = tokens,
                })
            end
        end

        for _, row in ipairs(rows) do
            local haystack = (row.appName .. " " .. row.status):lower()
            if q == "" or haystack:find(q, 1, true) then
                local label    = updateStatusLabel[row.status] or row.status
                local versions = (row.installed ~= "" or row.latest ~= "")
                    and (row.installed .. "  →  " .. row.latest) or "not checked yet"

                local action, actionText = "copy", ""
                if row.status == "update-available" and row.brewManaged and row.cask then
                    action, actionText = "brew", "  ·  Enter installs via Homebrew"
                elseif (row.status == "update-available" or row.status == "no-cask") and row.url then
                    action, actionText = "url", "  ·  Enter opens the download page"
                end

                table.insert(choices, {
                    text      = row.appName,
                    subText   = label .. "  ·  " .. versions .. actionText,
                    appName   = row.appName,
                    installed = row.installed,
                    latest    = row.latest,
                    cask      = row.cask,
                    url       = row.url,
                    action    = action,
                })
            end
        end
        if #choices == 0 then
            table.insert(choices, { text = "No matches for \"" .. q .. "\"", subText = "" })
        end
        _G.choosers.appUpdates:choices(choices)
    end

    _G.choosers.appUpdates:queryChangedCallback(function(query)
        local ok, err = pcall(renderUpdateChoices, query)
        if not ok then
            print("🚨 App Update Tracker render error: " .. tostring(err))
            _G.choosers.appUpdates:choices({
                { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err) },
            })
        end
    end)

    -- ⌃⌥⇧U — open the picker immediately with whatever's cached from the
    -- last check, and always kicks off a fresh one in the background — same
    -- pattern as the Asana Dashboard (§6), which re-fetches every time you
    -- open it rather than showing yesterday's numbers. This also means a
    -- config update (a fixed cask token, a corrected bundle path) shows up
    -- on the very next press instead of waiting for the 9am timer or an
    -- empty cache — 18 lightweight subprocess pairs is cheap for something
    -- you trigger deliberately, not a background poll.
    hs.hotkey.bind(updateTrackerMods, updateTrackerKey, function()
        renderUpdateChoices("")
        core.showPopup(_G.choosers.appUpdates)
        runUpdateCheck(function()
            local q = ""
            pcall(function() q = _G.choosers.appUpdates:query() or "" end)
            renderUpdateChoices(q)
        end)
    end)

    -- Automatic daily check so results are already warm before you ever
    -- press ⌃⌥⇧U — same on-a-clock pattern as the Activity Tracker's
    -- reports (§3.6).
    if brewPath then
        _G.updateTrackerTimer = hs.timer.doAt(updateTrackerCheckTime, "1d", function() runUpdateCheck() end)
    else
        print("ℹ️ App Update Tracker: Homebrew not found on this Mac — feature disabled (see §3.10)")
    end

    -- =====================================================================
end

return M
