-- =====================================================================
-- MODULE: DAILY BACKUP (was §1.7) — the rebuild kit → OneDrive, daily
-- =====================================================================
-- LL: "Is there a way for Hammerspoon to backup my user directory for
-- future OSX installs, my applications directory using homebrew as much
-- as possible, all to my OneDrive?" 6.139.0 is the answer, and it grew
-- out of the module that already copied ~/.hammerspoon here at 5 PM.
--
-- WHAT THIS IS AND IS NOT. This is a REBUILD KIT, not a Time Machine.
-- Time Machine (an external drive) stays the byte-for-byte safety net
-- with version history. What lands in OneDrive is the curated set a
-- future clean install actually needs:
--
--   <OneDrive>/Backups/Hammerspoon/<Mac>/            this config (as before)
--   <OneDrive>/Backups/Hammerspoon/<Mac>/RebuildKit/
--       dotfiles/        .zshrc · .zprofile · .gitconfig · .config/ · ssh config
--       LaunchAgents/    the per-user launchd jobs
--       Fonts/           ~/Library/Fonts
--       Documents/       (home Mac; the work profile turns these two off)
--       Desktop/
--       Brewfile         brew bundle dump — formulae, casks, App Store apps
--       apps.csv         EVERY installed app: version, bundle id, and HOW
--                        to get it back (App Store / brew cask / vendor)
--       README.md        the restore guide, rewritten after every run,
--                        with this Mac's real numbers in it
--
-- WHY A MIRROR OF THE WHOLE HOME FOLDER IS DELIBERATELY NOT HERE:
-- OneDrive chokes on huge file counts (caches, node_modules), sync is
-- not backup (it replicates a deletion as faithfully as an edit), and
-- Migration Assistant already does byte-for-byte. The kit is the part
-- a clean install cannot get anywhere else.
--
-- 🚨 WHAT NEVER LEAVES THIS MAC, BY DESIGN: secret.lua (the Asana
-- token — excluded from every rsync in this file, same as it has been
-- since 6.10.0), private SSH keys (only ~/.ssh/config, the settings
-- file, is copied — never the keys beside it), and the Keychain. The
-- README the kit writes says to recreate secret.lua by hand and where
-- the token comes from. Losing it costs 30 seconds at
-- app.asana.com/0/my-apps; leaking it costs more.
--
-- ⏱ AND NOTHING HERE TOUCHES THE KEYBOARD. Every rsync and every brew
-- call is an hs.task (never a shell string — an argument ARRAY, the
-- net_tools rule), one at a time with a breath between steps, and the
-- app scan reads Info.plists a small slice per step. This module was
-- rebuilt three releases after 6.137.0; it does not reintroduce the
-- disease the lag emergency cured.
--
-- 🏢 THE WORK MAC RUNS THE SAME FILE, SMALLER. §0.1 already lands that
-- machine on whatever OneDrive it has. The work profile in init.lua
-- sets docs = false: dotfiles, this config, the Brewfile and the app
-- manifest are backed up; Documents and Desktop are not — those live
-- in the company's own OneDrive already, and a personal backup habit
-- on a managed Mac should stay inside the lines. No Homebrew on that
-- Mac → the Brewfile step skips itself and the report says so.

local M = {
    name  = "Daily Backup",
    order = 15,
    family = "auto",
    summary = "The rebuild kit: config, dotfiles, app manifest → OneDrive daily",
    cheatsheet = {
        title = "☁️ BACKUP — THE REBUILD KIT (automatic)",
        entries = {
            { "daily 5:00 PM", "config · dotfiles · LaunchAgents · Fonts · Documents → OneDrive" },
            { "apps", "Brewfile + apps.csv record how to reinstall EVERYTHING" },
            { "restore", "RebuildKit/README.md — written fresh after every run" },
            { "never", "secret.lua, SSH keys, Keychain — those stay on this Mac" },
            { "_G.backupNow()", "Console: run the whole kit right now" },
            { "_G.backupReport()", "Console: destination, last run, what was skipped and why" },
            { "_G.backupAdopt()", "Console: which hand-installed apps Homebrew could own" },
        },
    },
}

function M.setup(core)
    local bk = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    bk.enabled     = true
    bk.time        = "17:00" -- daily, 24h format (5:00 PM, as it always was)
    bk.stepSecs    = 0.25    -- breath between steps, for keystrokes to pass
    bk.sliceApps   = 12      -- Info.plists read per step in the app scan
    bk.taskCapSecs = 600     -- watchdog: no single rsync/brew step runs longer
    bk.staleDays   = 3       -- boot note when the last good run is older
    bk.docs        = true    -- Documents + Desktop in the kit (work: false)
    -- Applied to EVERY rsync. secret.lua is here as well as on the config
    -- entry — belt and braces, because this is the one exclusion that is
    -- a promise, not a preference. applock.json is the removed App Lock's
    -- PIN hash (6.35.0): per-machine only, same rule.
    bk.excludes    = { ".DS_Store", "node_modules", ".git", "Caches",
                       "*.photoslibrary", "secret.lua", "applock.json" }
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("backup", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("backup", m) end end

    local SETTINGS_KEY = "dailyBackup.last"

    bk.kitDir = core.backupDir and (core.backupDir .. "/RebuildKit") or nil

    local function exists(p)
        local ok, a = pcall(hs.fs.attributes, p)
        return ok and a ~= nil
    end

    -- Homebrew's two homes: Apple Silicon, then Intel. Nil = not on this
    -- Mac, and every brew step quietly stands down.
    bk.brew = nil
    for _, p in ipairs({ "/opt/homebrew/bin/brew", "/usr/local/bin/brew" }) do
        if exists(p) then bk.brew = p break end
    end

    -- hs.fs.mkdir makes ONE level; a kit path is several deep.
    local function mkpath(path)
        local built = ""
        for part in path:gmatch("[^/]+") do
            built = built .. "/" .. part
            pcall(hs.fs.mkdir, built)
        end
    end

    -- =====================================================================
    -- THE KIT — what a clean install needs, most precious first, biggest
    -- last (so a timeout on Documents never starves the small stuff; and
    -- rsync picks up where a cut-off copy stopped, next run).
    -- =====================================================================
    -- `file = true` copies one file into dest/; otherwise src is a folder
    -- mirrored into dest/. Missing sources are reported as "not on this
    -- Mac", never treated as failures — the two Macs differ, on purpose.
    -- 🚨 ~/.ssh appears here ONLY as its config FILE. Never widen that
    -- entry to the folder: the keys live beside it.
    function bk.buildKit()
        local home, kit = core.homeDir, bk.kitDir
        local list = {
            { id = "config",    src = core.configDir,               dest = core.backupDir,
              label = "~/.hammerspoon (secret.lua excluded)" },
            { id = "zshrc",     src = home .. "/.zshrc",            dest = kit .. "/dotfiles",  file = true },
            { id = "zprofile",  src = home .. "/.zprofile",         dest = kit .. "/dotfiles",  file = true },
            { id = "gitconfig", src = home .. "/.gitconfig",        dest = kit .. "/dotfiles",  file = true },
            { id = "sshconfig", src = home .. "/.ssh/config",       dest = kit .. "/dotfiles/ssh", file = true,
              label = "~/.ssh/config — the settings file, never the keys" },
            { id = "xdg",       src = home .. "/.config",           dest = kit .. "/dotfiles/.config" },
            { id = "agents",    src = home .. "/Library/LaunchAgents", dest = kit .. "/LaunchAgents" },
            { id = "fonts",     src = home .. "/Library/Fonts",     dest = kit .. "/Fonts" },
        }
        if bk.docs then
            list[#list + 1] = { id = "documents", src = home .. "/Documents", dest = kit .. "/Documents" }
            list[#list + 1] = { id = "desktop",   src = home .. "/Desktop",   dest = kit .. "/Desktop" }
        end
        return list
    end

    local function rsyncArgs(entry)
        local args = { "-a", "--stats" }
        for _, pat in ipairs(bk.excludes) do
            args[#args + 1] = "--exclude"
            args[#args + 1] = pat
        end
        if entry.file then
            args[#args + 1] = entry.src
        else
            args[#args + 1] = entry.src .. "/"
        end
        args[#args + 1] = entry.dest .. "/"
        return args
    end

    -- =====================================================================
    -- THE APP MANIFEST — every installed app, and how to get it back
    -- =====================================================================
    -- Apple's own apps are skipped (a clean install brings them), and
    -- source is decided per app: an App Store receipt inside the bundle
    -- beats guessing; otherwise a Homebrew cask this Mac already owns;
    -- otherwise "direct" — reinstall from the vendor, and the row says so.
    function bk.caskToken(name)
        local t = tostring(name or ""):gsub("%.app$", ""):lower()
        t = t:gsub("[%s_]+", "-"):gsub("[^%w%-%+%.@]", "")
        return t
    end

    function bk.classify(appPath, name, caskSet)
        if exists(appPath .. "/Contents/_MASReceipt/receipt") then
            return "app-store", "Mac App Store"
        end
        local tok = bk.caskToken(name)
        if caskSet and caskSet[tok] then
            return "homebrew", "brew install --cask " .. tok
        end
        return "direct", "download from the vendor"
    end

    function bk.appFolders()
        return { "/Applications", core.homeDir .. "/Applications" }
    end

    local function listApps()
        local paths = {}
        for _, dir in ipairs(bk.appFolders()) do
            pcall(function()
                for entry in hs.fs.dir(dir) do
                    if entry:match("%.app$") then
                        paths[#paths + 1] = dir .. "/" .. entry
                    end
                end
            end)
        end
        table.sort(paths)
        return paths
    end

    local function readApp(path, caskSet)
        local name = path:match("([^/]+)%.app$") or path
        local bundle, ver = "", ""
        pcall(function()
            if hs.plist and hs.plist.read then
                local info = hs.plist.read(path .. "/Contents/Info.plist")
                if type(info) == "table" then
                    bundle = tostring(info.CFBundleIdentifier or "")
                    ver    = tostring(info.CFBundleShortVersionString
                                      or info.CFBundleVersion or "")
                end
            end
        end)
        if bundle:match("^com%.apple%.") then return nil end
        local source, from = bk.classify(path, name, caskSet)
        return { app = name, version = ver, bundle = bundle,
                 source = source, from = from }
    end

    local function writeFile(path, text, label)
        local f = io.open(path, "w")
        if not f then
            if core.warnWriteFailed then core.warnWriteFailed(label or path) end
            return false
        end
        f:write(text)
        f:close()
        return true
    end

    local function writeManifest(rows)
        local out = { "app,version,bundle_id,source,reinstall" }
        for _, r in ipairs(rows) do
            out[#out + 1] = table.concat({
                core.csvQuote(r.app), core.csvQuote(r.version),
                core.csvQuote(r.bundle), core.csvQuote(r.source),
                core.csvQuote(r.from) }, ",")
        end
        return writeFile(bk.kitDir .. "/apps.csv",
                         table.concat(out, "\n") .. "\n", "apps.csv (backup)")
    end

    -- The restore guide, rewritten with real numbers after every run —
    -- so the person doing the restore (future LL, on a blank Mac, maybe
    -- in a hurry) reads instructions that describe THIS kit, not a
    -- generic hope.
    local function writeReadme(rep)
        local n = { store = 0, brewd = 0, direct = 0 }
        for _, r in ipairs(rep.apps or {}) do
            if r.source == "app-store" then n.store = n.store + 1
            elseif r.source == "homebrew" then n.brewd = n.brewd + 1
            else n.direct = n.direct + 1 end
        end
        local L = {
            "# Rebuild kit — " .. core.hostTag,
            "",
            "Written automatically by Hammerspoon (Daily Backup, v"
                .. tostring(core.version) .. ") on " .. os.date("%Y-%m-%d %H:%M") .. ".",
            "Do not edit — the next run rewrites this file.",
            "",
            "## Restoring onto a clean Mac",
            "",
            "1. Sign into OneDrive and let this folder sync down.",
            "2. Install Homebrew: https://brew.sh",
            "3. In this folder run:  brew bundle --file Brewfile",
            (bk.brew and ""
                or "   (No Homebrew existed on the source Mac — the Brewfile may be absent.)"),
            "4. Open apps.csv — " .. n.direct .. " app(s) are marked `direct`:"
                .. " reinstall those from their vendors. The " .. n.store
                .. " `app-store` row(s) return via the App Store; the "
                .. n.brewd .. " `homebrew` row(s) came back in step 3.",
            "5. Copy dotfiles/ back into your home folder"
                .. " (.zshrc, .gitconfig, .config/, ssh/config into ~/.ssh/config).",
            "6. Copy the folder above this one (the Hammerspoon config)"
                .. " to ~/.hammerspoon.",
            "7. Recreate ~/.hammerspoon/secret.lua BY HAND — the Asana token"
                .. " is deliberately never backed up. A fresh token takes 30"
                .. " seconds at app.asana.com/0/my-apps.",
            "8. Open Hammerspoon, grant Accessibility / Input Monitoring /"
                .. " Full Disk Access when asked — ⇪⇧D reports what is missing.",
            "",
            "## What is NOT here, on purpose",
            "",
            "- secret.lua and every other credential (step 7)",
            "- private SSH keys (only ssh/config was copied)",
            "- the Keychain, browser profiles, Photos, Mail",
            "- a byte-for-byte home folder — that is Time Machine's job",
            "",
        }
        return writeFile(bk.kitDir .. "/README.md",
                         table.concat(L, "\n"), "README.md (backup)")
    end

    -- =====================================================================
    -- THE RUN — one queue, one thing in flight, a breath between steps
    -- =====================================================================
    bk.running  = false
    bk.last     = nil
    pcall(function()
        local saved = hs.settings.get(SETTINGS_KEY)
        if type(saved) == "table" then bk.last = saved end
    end)

    local function record(rep, id, status, detail)
        rep.entries[#rep.entries + 1] =
            { id = id, status = status, detail = detail or "" }
        if status == "failed" or status == "timed out" then
            rep.failed = (rep.failed or 0) + 1
        elseif status == "partial" then
            rep.partial = (rep.partial or 0) + 1
        end
    end

    -- One external command as one queue step. Argument array, never a
    -- shell string; watchdog HELD in bk (an unreferenced timer is
    -- collected and never fires — the 6.16.18 lesson).
    local function taskStep(bin, args, onExit)
        return function(done)
            local finished = false
            local okNew, t = pcall(hs.task.new, bin, function(code, so, se)
                if finished then return end
                finished = true
                if bk.guard then pcall(function() bk.guard:stop() end) end
                onExit(code, so or "", se or "")
                done()
            end, args)
            if not (okNew and t) then
                onExit(-1, "", "could not create the task")
                done()
                return
            end
            bk.task  = t
            bk.guard = hs.timer.doAfter(bk.taskCapSecs, function()
                if finished then return end
                finished = true
                pcall(function() t:terminate() end)
                onExit(-2, "", "timed out after " .. bk.taskCapSecs .. "s")
                done()
            end)
            local okStart = pcall(function() t:start() end)
            if not okStart and not finished then
                finished = true
                pcall(function() bk.guard:stop() end)
                onExit(-1, "", "could not start the task")
                done()
            end
        end
    end

    local function rsyncStep(entry, rep)
        if not exists(entry.src) then
            return function(done)
                record(rep, entry.id, "skipped", "not on this Mac")
                done()
            end
        end
        return function(done)
            mkpath(entry.dest)
            taskStep("/usr/bin/rsync", rsyncArgs(entry), function(code, so, se)
                if code == 0 then
                    local files = so:match("files transferred:%s*([%d,]+)") or "?"
                    record(rep, entry.id, "ok", files:gsub(",", "") .. " files updated")
                elseif code == 23 or code == 24 then
                    local hint = se:find("Operation not permitted", 1, true)
                               and " — grant Hammerspoon Full Disk Access (⇪,)" or ""
                    record(rep, entry.id, "partial", "some files unreadable" .. hint)
                elseif code == -2 then
                    record(rep, entry.id, "timed out",
                           "will pick up where it stopped, next run")
                else
                    record(rep, entry.id, "failed",
                           "rsync exit " .. code .. ": " .. se:sub(1, 160))
                end
            end)(done)
        end
    end

    function bk.run(manual)
        if not bk.enabled then
            if manual then hs.alert.show("☁️ Daily Backup is off (bk.enabled)") end
            return false
        end
        if not core.backupDir then
            if manual then
                hs.alert.show("☁️ No OneDrive on this Mac — nowhere"
                              .. " cloud-synced to back up to (see §0.1)")
            end
            return false
        end
        if bk.running then
            if manual then hs.alert.show("☁️ A backup is already running") end
            return false
        end
        bk.running = true
        local rep = { at = os.date("%Y-%m-%d %H:%M:%S"), entries = {},
                      manual = manual and true or false,
                      brew = bk.brew and "present" or "not on this Mac" }
        local t0 = hs.timer.absoluteTime()
        mkpath(bk.kitDir)

        local steps, caskSet = {}, nil
        for _, entry in ipairs(bk.buildKit()) do
            steps[#steps + 1] = rsyncStep(entry, rep)
        end

        if bk.brew then
            -- Which casks this Mac already owns — read BEFORE the scan, so
            -- the manifest can say "homebrew" with a straight face.
            steps[#steps + 1] = taskStep(bk.brew, { "list", "--cask", "-1" },
                function(code, so)
                    caskSet = {}
                    if code == 0 then
                        for tok in so:gmatch("[^\r\n]+") do caskSet[tok] = true end
                    end
                end)
            steps[#steps + 1] = taskStep(bk.brew,
                { "bundle", "dump", "--force", "--file", bk.kitDir .. "/Brewfile" },
                function(code, _, se)
                    if code == 0 then record(rep, "brewfile", "ok", "Brewfile written")
                    else record(rep, "brewfile", "failed",
                                "brew bundle exit " .. code .. ": " .. se:sub(1, 160)) end
                end)
        else
            steps[#steps + 1] = function(done)
                record(rep, "brewfile", "skipped", "no Homebrew on this Mac")
                done()
            end
        end

        -- The app scan, a slice per step: ~80 Info.plists is a real stall
        -- if read in one gulp, and one gulp on the shared thread is the
        -- exact shape of the 6.137.0 disease.
        local appPaths, rows, idx = nil, {}, 0
        local function scanSlice(done)
            if not appPaths then appPaths = listApps() end
            local upto = math.min(idx + bk.sliceApps, #appPaths)
            while idx < upto do
                idx = idx + 1
                local r = readApp(appPaths[idx], caskSet)
                if r then rows[#rows + 1] = r end
            end
            if idx < #appPaths then
                bk.stepTimer = hs.timer.doAfter(bk.stepSecs, function() scanSlice(done) end)
            else
                rep.apps = rows
                bk.lastRows = rows
                record(rep, "apps", "ok", #rows .. " apps in the manifest")
                done()
            end
        end
        steps[#steps + 1] = scanSlice

        steps[#steps + 1] = function(done)
            writeManifest(rows)
            writeReadme(rep)
            done()
        end

        local i = 0
        local function next()
            i = i + 1
            local s = steps[i]
            if not s then
                bk.running = false
                rep.ms = math.floor((hs.timer.absoluteTime() - t0) / 1e6)
                bk.last = rep
                pcall(function()
                    hs.settings.set(SETTINGS_KEY, { at = rep.at, ms = rep.ms,
                        failed = rep.failed, partial = rep.partial,
                        entries = rep.entries, brew = rep.brew,
                        appCount = rep.apps and #rep.apps or 0 })
                end)
                local verdict = (rep.failed or 0) > 0 and "with FAILURES"
                              or (rep.partial or 0) > 0 and "with gaps" or "clean"
                print("☁️ Rebuild kit " .. verdict .. " → " .. core.backupDir
                      .. " (" .. rep.ms .. "ms; secret.lua excluded)")
                if (rep.failed or 0) > 0 then
                    hs.alert.show("⚠️ Backup finished with failures —"
                                  .. " _G.backupReport() says which", 5)
                elseif manual then
                    hs.alert.show("☁️ Rebuild kit updated — "
                        .. #rep.entries .. " areas, "
                        .. (rep.apps and #rep.apps or 0) .. " apps listed", 3)
                end
                say("run done in " .. rep.ms .. "ms")
                return
            end
            bk.stepTimer = hs.timer.doAfter(bk.stepSecs, function() s(next) end)
        end
        next()
        return true
    end

    -- =====================================================================
    -- CONSOLE
    -- =====================================================================
    function bk.report()
        local L = { "☁️ DAILY BACKUP — the rebuild kit" }
        if core.backupDir then
            local flavor = "OneDrive"
            pcall(function()
                flavor = core.cloudDir and core.cloudDir:match("([^/]+)$") or flavor
            end)
            L[#L + 1] = "   to      : " .. core.backupDir .. "  (" .. flavor .. ")"
            L[#L + 1] = "   daily at: " .. bk.time
                        .. (bk.enabled and "" or "  — DISABLED (bk.enabled)")
            L[#L + 1] = "   homebrew: " .. (bk.brew or "not on this Mac"
                        .. " — Brewfile skipped, manifest still written")
        else
            L[#L + 1] = "   NO OneDrive on this Mac — the kit has nowhere"
                        .. " cloud-synced to go (§0.1)"
        end
        local last = bk.last
        if last and last.at then
            L[#L + 1] = "   last run: " .. last.at .. " (" .. tostring(last.ms) .. "ms)"
            for _, e in ipairs(last.entries or {}) do
                L[#L + 1] = string.format("     %-10s %-9s %s", e.id, e.status, e.detail)
            end
            local n = last.appCount or (last.apps and #last.apps)
            if n then L[#L + 1] = "   manifest: " .. n .. " apps in apps.csv" end
        else
            L[#L + 1] = "   last run: never — _G.backupNow() starts one"
        end
        print(table.concat(L, "\n"))
        return true
    end

    -- Which hand-installed apps could Homebrew own? `--adopt` takes over
    -- an app already in /Applications without reinstalling it — after
    -- that, the Brewfile covers it forever. On demand only: it asks brew
    -- one question per app, one at a time.
    function bk.adopt()
        if not bk.brew then
            print("🍺 No Homebrew on this Mac — nothing to adopt into.")
            return false
        end
        if not bk.lastRows then
            print("🍺 Run _G.backupNow() first — adoption reads the app manifest.")
            return false
        end
        if bk.running then
            print("🍺 A backup is running — try again when it finishes.")
            return false
        end
        local direct = {}
        for _, r in ipairs(bk.lastRows) do
            if r.source == "direct" then direct[#direct + 1] = r end
        end
        if #direct == 0 then
            print("🍺 Every app is already covered by the App Store or Homebrew.")
            return true
        end
        bk.running = true
        print("🍺 Asking Homebrew about " .. #direct .. " hand-installed app(s)…")
        local hits, i = {}, 0
        local function next()
            i = i + 1
            local r = direct[i]
            if not r then
                bk.running = false
                if #hits == 0 then
                    print("🍺 None of them have a cask — apps.csv stays the record.")
                else
                    print("🍺 " .. #hits .. " could join the Brewfile. Run:")
                    for _, tok in ipairs(hits) do
                        print("     brew install --cask --adopt " .. tok)
                    end
                    print("   --adopt takes over the copy already in /Applications.")
                end
                return
            end
            local tok = bk.caskToken(r.app)
            taskStep(bk.brew, { "search", "--casks", tok }, function(code, so)
                if code == 0 then
                    for line in so:gmatch("[^\r\n]+") do
                        if line:gsub("%s+", "") == tok then
                            hits[#hits + 1] = tok
                            break
                        end
                    end
                end
            end)(function()
                bk.stepTimer = hs.timer.doAfter(bk.stepSecs, next)
            end)
        end
        next()
        return true
    end

    _G.backupNow    = function() return bk.run(true) end
    _G.backupReport = function() return bk.report() end
    _G.backupAdopt  = function() return bk.adopt() end
    if core.provide then
        core.provide("backup.now",    function() return bk.run(true) end)
        core.provide("backup.report", function() return bk.report() end)
    end

    -- =====================================================================
    -- THE SCHEDULE — same identity as it has had since §1.7 was a section
    -- =====================================================================
    if core.backupDir and bk.enabled then
        _G.backupTimer = hs.timer.doAt(bk.time, "1d", function() bk.run(false) end)
        -- The doAt caveat, unchanged: a Mac asleep at bk.time skips that
        -- day. The staleness note below is the honest counterweight — a
        -- kit that quietly stopped updating gets named at boot, instead
        -- of being discovered the day it is needed.
        if bk.last and bk.last.at then
            local y, mo, d = tostring(bk.last.at):match("(%d+)-(%d+)-(%d+)")
            if y then
                local age = os.time() - os.time({ year = tonumber(y),
                    month = tonumber(mo), day = tonumber(d), hour = 12 })
                if age > bk.staleDays * 86400 then
                    print("☁️ The rebuild kit is " .. math.floor(age / 86400)
                          .. " days old — _G.backupNow() refreshes it")
                end
            end
        end
        say("armed for " .. bk.time .. " daily → " .. core.backupDir)
    else
        print("ℹ️ No OneDrive on this Mac — daily backup disabled; data stays in "
              .. core.configDir .. " and " .. tostring(core.logsDir))
    end

    _G.dailyBackup = bk
    M.bk     = bk
    M.config = bk
end

return M
