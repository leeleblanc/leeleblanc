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
--       CrashReports/    Hammerspoon's own crash reports (6.197.0)
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
-- 🚨 6.197.0 — CRASH REPORTS, AND ONLY OUR OWN. LL: "Is this in my logs
-- folder, OneDrive? If my work Mac or my home Mac get wiped, I will lose
-- this information for you." He was right, and nothing in this file had
-- ever copied them: ~/Library/Logs/DiagnosticReports is the ONLY place a
-- Hammerspoon crash report has ever lived, macOS prunes that folder on
-- its own schedule, and a crash report is the one piece of evidence that
-- names the framework that died. The kit now carries them.
-- THE FILTER IS DELIBERATELY NARROW — Hammerspoon's own reports, never
-- another app's. That folder holds diagnostics for everything on the
-- Mac, and this destination syncs to OneDrive; copying the lot would be
-- a decision about other people's software, taken quietly, into a cloud
-- folder. `entry.only` is what keeps it to ours. And rsync runs without
-- --delete here as it does everywhere else in this file, so a report
-- macOS has already thrown away stays in the backup for good — which is
-- the whole point of the exercise.
--
-- ⏱ AND NOTHING HERE TOUCHES THE KEYBOARD. Every rsync and every brew
-- call is an hs.task (never a shell string — an argument ARRAY, the
-- net_tools rule), one at a time with a breath between steps, and the
-- app scan reads Info.plists a small slice per step. This module was
-- rebuilt three releases after 6.137.0; it does not reintroduce the
-- disease the lag emergency cured.
--
-- 🏢 THE WORK MAC RUNS THE SAME FILE — INCLUDING DOCUMENTS. 6.139.0
-- shipped the work profile with docs = false on the guess that work
-- Documents belonged only in the company's OneDrive; 6.140.1 removed
-- that override after LL confirmed "all documents are safe to backup"
-- on that machine. Both Macs now build the full kit. §0.1 already
-- lands each machine on whatever OneDrive it has; no Homebrew on the
-- work Mac → the Brewfile step skips itself and the report says so.
-- The docs knob below stays for any future Mac that needs it.

local M = {
    name  = "Daily Backup",
    order = 15,
    family = "auto",
    summary = "The rebuild kit: config, dotfiles, app manifest → OneDrive daily",
    cheatsheet = {
        title = "☁️ BACKUP — THE REBUILD KIT (automatic)",
        entries = {
            { "daily 5:00 PM", "config · dotfiles · LaunchAgents · Fonts · crash reports · Documents → OneDrive" },
            { "apps", "Brewfile + apps.csv record how to reinstall EVERYTHING" },
            { "restore", "RebuildKit/README.md — written fresh after every run" },
            { "never", "secret.lua, SSH keys, Keychain — those stay on this Mac" },
            { "_G.backupNow()", "Console: run the whole kit right now" },
            { "_G.backupReport()", "Console: destination, last run, what was skipped and why" },
            { "_G.backupAdopt()", "Console: which hand-installed apps Homebrew could own" },
            { "_G.crashReport()", "Console: where Hammerspoon's crash reports are — the newest one is the file to send" },
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
    -- 🏠 6.190.0 — LL: "every 30 minutes write a back up of all the files
    -- that have histories or modifications." That is the STORES, not the
    -- rebuild kit: one rsync of the whole Logs folder to OneDrive, on its
    -- own timer, independent of the 5 PM kit. It runs whether or not the
    -- stores are local — a half-hourly copy of the histories is worth
    -- having either way — and it is the other half of init.lua's
    -- localFirst switch: local for speed, OneDrive for safety and for the
    -- other Mac.
    bk.mirrorMins  = 30      -- 0 disables the half-hourly store mirror
    bk.mirrorFirst = 120     -- seconds after boot before the first one
    bk.mirrorLast  = nil     -- { at, ok, why } — for the report
    bk.docs        = true    -- Documents + Desktop in the kit (both Macs)
    -- 🚨 6.197.0 — Hammerspoon's crash reports. The glob is the whole
    -- safety of pointing an rsync at that folder: it holds every app's
    -- diagnostics and this destination is a cloud folder. Narrow it, or
    -- turn the entry off with bk.crashes = false; never widen it.
    bk.crashes     = true
    bk.crashGlob   = "Hammerspoon*"  -- .ips today; older macOS wrote _*.crash
    bk.crashScanMax = 500    -- names the REPORTS will look at (the copy is
                             -- rsync's job and has no such limit); hitting
                             -- it is said out loud, never silently trimmed
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
    -- Named once, because the RUN copies from one to the other and the
    -- REPORT counts both. A Mac with no OneDrive has no destination —
    -- that reads as "nowhere to copy them to", never as a failure.
    -- No home folder (a stub core, a Mac we cannot read) → NIL, not a
    -- path rooted at "/": /Library/Logs/DiagnosticReports is the SYSTEM
    -- folder and pointing an rsync at it by accident is not a degrade.
    bk.crashDir  = core.homeDir
                   and (core.homeDir .. "/Library/Logs/DiagnosticReports")
                   or nil
    bk.crashDest = bk.kitDir and (bk.kitDir .. "/CrashReports") or nil

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
        -- 🚨 THE FILTER FAILS CLOSED. `only` is what makes it safe to aim
        -- an rsync at a folder full of other apps' diagnostics — so an
        -- UNSET glob must DROP the entry, never widen it. Without this
        -- guard, clearing bk.crashGlob (or a profile override setting it
        -- to false — bk is exported as M.config and init.lua applies
        -- settings straight into it) left `only` falsy, rsyncArgs skipped
        -- the whole filter block, and the kit copied EVERY app's crash
        -- reports and spindumps into a cloud folder. The knob sits under
        -- a comment inviting the reader to narrow it; deleting that line
        -- must not be the way to widen it.
        local glob = (type(bk.crashGlob) == "string" and bk.crashGlob ~= "")
                     and bk.crashGlob or nil
        if bk.crashes and bk.crashDir and bk.crashDest and glob then
            list[#list + 1] = { id = "crashes", src = bk.crashDir,
                dest = bk.crashDest, only = glob, mustFilter = true,
                label = "Hammerspoon's own crash reports — macOS prunes"
                        .. " the originals; nothing here is ever deleted" }
        end
        if bk.docs then
            list[#list + 1] = { id = "documents", src = home .. "/Documents", dest = kit .. "/Documents" }
            list[#list + 1] = { id = "desktop",   src = home .. "/Desktop",   dest = kit .. "/Desktop" }
        end
        return list
    end

    local function rsyncArgs(entry)
        local args = { "-a", "--stats" }
        -- 6.197.0 — -m prunes the empty folders a name filter leaves
        -- behind. Only ever set for a filtered entry.
        if entry.only then args[#args + 1] = "-m" end
        for _, pat in ipairs(bk.excludes) do
            args[#args + 1] = "--exclude"
            args[#args + 1] = pat
        end
        -- 🚨 entry.only — copy ONLY the names that match, at any depth.
        -- THE ORDER IS THE RULE: rsync takes the FIRST filter that
        -- matches a path, so "*/" (walk into folders — macOS keeps older
        -- reports in a Retired/ one) and the name pattern must both come
        -- BEFORE the catch-all exclude. Put --exclude "*" first and the
        -- entry copies nothing at all — 0 files, exit 0, no error, which
        -- is why it is a gate check and not a comment (measured against
        -- real rsync 3.2.7, both orders). This block is scoped to
        -- the one entry that asks for it: a filter in the base args would
        -- empty every other rsync in the kit.
        if entry.only then
            args[#args + 1] = "--include"; args[#args + 1] = "*/"
            args[#args + 1] = "--include"; args[#args + 1] = entry.only
            args[#args + 1] = "--exclude"; args[#args + 1] = "*"
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
        if bk.crashes then
            local extra = {
                "## If Hammerspoon ever quits by itself",
                "",
                "`CrashReports/` holds Hammerspoon's own crash reports, copied out",
                "of ~/Library/Logs/DiagnosticReports. macOS deletes the originals",
                "on its own schedule; nothing in this folder is ever deleted.",
                "The newest file in there is the one to send — its crashing thread",
                "names the framework that died, which is the fact that ends a hunt.",
                "",
            }
            for _, line in ipairs(extra) do L[#L + 1] = line end
        end
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
        -- 🚨 BELT AND BRACES, the way secret.lua is excluded twice: an
        -- entry that declares it MUST be filtered is never copied whole,
        -- even if something upstream handed it a broken glob. It is
        -- refused and SAID, never quietly widened.
        if entry.mustFilter
           and not (type(entry.only) == "string" and entry.only ~= "") then
            return function(done)
                record(rep, entry.id, "skipped",
                       "no name filter set — this source is never copied whole")
                done()
            end
        end
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
    -- 🚨 CRASH REPORTS — the evidence, and how to find it (6.197.0)
    -- =====================================================================
    -- A LISTING, never a read. hs.fs.dir names the files without opening
    -- one, so a OneDrive placeholder is never hydrated and nothing here
    -- can block the thread every keystroke shares — which is what makes
    -- it safe to call from a report LL types by hand.
    --
    -- 🔎 NEWEST IS DECIDED ON THE DIGITS IN THE NAME, NOT ON THE NAME.
    -- macOS wrote `Hammerspoon_<date>_<Mac>.crash` before it wrote
    -- `Hammerspoon-<date>.ips`, and "_" sorts AFTER "-", so a plain
    -- string compare hands you a years-old file and calls it the newest
    -- — while the report reads perfectly sensibly. The digit run
    -- (20260909114412) is the same shape in both names.
    -- 🚨 IT RETURNS A STATE, NOT JUST A COUNT — 6.196.1's rule, applied
    -- to a folder macOS guards. ~/Library/Logs/DiagnosticReports needs
    -- FULL DISK ACCESS on modern macOS: without it the listing fails and
    -- a scan that only returned a number would answer 0, and the report
    -- would say "none anywhere — Hammerspoon has not crashed on this
    -- Mac". That is the most reassuring sentence in this file and it
    -- would be a lie. "Cannot see" must never read as "nothing there".
    --    "ok"          listed it
    --    "missing"     no such folder (a Mac with no crashes yet, or no
    --                  backup written yet — nothing is wrong)
    --    "unreadable"  it is there and we were refused
    --    "unmatchable" bk.crashGlob is not set, so nothing CAN be counted
    --                  — and, because the filter fails closed, nothing is
    --                  being copied either. Never one of the first two.
    --
    -- The scan matches the SAME glob rsync is given, so the count and the
    -- copy can never disagree — a literal-prefix shortcut worked for
    -- "Hammerspoon*" and answered 0 for anything starting with a
    -- wildcard, and bk is exported as M.config, so that was reachable
    -- from a profile override rather than only from a code edit.
    function bk.globPattern(g)
        g = tostring(g or "")
        if g == "" then return nil end
        local p = g:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%1")
        p = p:gsub("%*", ".*"):gsub("%?", ".")
        return "^" .. p .. "$"
    end

    -- 🚨 IT WALKS ONE LEVEL DOWN, BECAUSE THE COPY DOES. rsync is given
    -- `--include */`, so it takes macOS's Retired/ folder — where older
    -- reports are moved shortly before they are deleted, which is to say
    -- the ones this whole feature exists for. A scan that stopped at the
    -- top level would count a SUBSET of what the backup holds and answer
    -- "is the newest one safe?" about names it never saw. Keyed by
    -- BASENAME on both sides, so a report that has since moved into
    -- Retired/ still matches its copy.
    --
    -- It also hands back the NAMES it saw. "Is today's crash safe?" is a
    -- membership question, not a subtraction: the two folders diverge by
    -- design (macOS prunes one, nothing prunes the other), so once the
    -- backup holds more than the Mac does, a count difference can never
    -- notice a brand-new report that has not been copied yet.
    --
    -- Budgeted by bk.crashScanMax, and the budget is REPORTED rather than
    -- silently truncating — a count that stopped early must not read as a
    -- count that finished.
    -- returns: count, newest, state, names, capped
    function bk.crashScan(dir)
        local pat = bk.globPattern(bk.crashGlob)
        if not pat then return 0, nil, "unmatchable", {}, false end
        if not (dir and dir ~= "") then return 0, nil, "missing", {}, false end
        if not exists(dir) then return 0, nil, "missing", {}, false end
        local n, newest, newestKey, newestDated, names = 0, nil, nil, false, {}
        local seen, capped, budget = 0, false, tonumber(bk.crashScanMax) or 500
        local function isDir(p)
            local okA, a = pcall(hs.fs.attributes, p)
            return okA and type(a) == "table" and a.mode == "directory"
        end
        local function walk(folder, depth)
            local subs = {}
            for entry in hs.fs.dir(folder) do
                if entry ~= "." and entry ~= ".." then
                    seen = seen + 1
                    if seen > budget then capped = true return end
                    if entry:match(pat) then
                        names[entry] = true
                        n = n + 1
                        -- TWO KEY SPACES, NEVER COMPARED TO EACH OTHER: a
                        -- dated name sorts by its digits, an undated one
                        -- by its name, and a DATED one always wins.
                        -- Comparing across them is a byte compare where
                        -- 'H' (0x48) beats '9' (0x39), so one stray
                        -- undated file — Hammerspoon.crash, a .diag —
                        -- would outrank every real report and be handed
                        -- over as "the newest".
                        local key   = entry:gsub("%D", "")
                        local dated = key ~= ""
                        if not dated then key = entry end
                        if (not newest)
                           or (dated and not newestDated)
                           or (dated == newestDated and key > newestKey) then
                            newestKey, newestDated, newest = key, dated, entry
                        end
                    elseif depth < 1 and isDir(folder .. "/" .. entry) then
                        subs[#subs + 1] = folder .. "/" .. entry
                    end
                end
            end
            for _, sub in ipairs(subs) do
                if capped then return end
                walk(sub, depth + 1)
            end
        end
        local ok = pcall(function() walk(dir, 0) end)
        return n, newest, ok and "ok" or "unreadable", names, capped
    end

    -- One sentence for a scanned folder, so the three states read the
    -- same wherever they are printed.
    -- 🚨 The unmatchable sentence used to say "the copy is unaffected".
    -- It was false in both directions — an empty glob made rsync's
    -- include match nothing, an absent one removed the filter entirely —
    -- and it was the one line added to be honest about a mis-set knob.
    -- Now the filter fails closed, so there is one true thing to say.
    function bk.crashSay(n, state, where)
        if state == "unmatchable" then
            return "bk.crashGlob is not set, so crash reports are NOT"
                   .. " being copied at all"
        elseif state == "unreadable" then
            return "CANNOT READ " .. where .. " — grant Hammerspoon Full"
                   .. " Disk Access (⇪,) and ask again"
        elseif state == "missing" then
            -- "not there" and "not visible to us" can look the same from
            -- outside a TCC refusal, so this never says "none".
            return "no folder " .. where .. " yet (or not visible without"
                   .. " Full Disk Access)"
        end
        return n .. " " .. where
    end

    -- LL, twice now, has had to send a screenshot because there was no
    -- line to run. This is the line: it names the exact file, in full,
    -- ready to paste into Finder's Go → Go to Folder.
    function bk.crashReport()
        local L = { "🚨 HAMMERSPOON CRASH REPORTS" }
        local function row(k, v)
            L[#L + 1] = string.format("   %-12s %s", k, tostring(v or "—"))
        end
        local hereN, hereNewest, hereState, _, hereCapped =
            bk.crashScan(bk.crashDir)
        row("on this Mac:", bk.crashDir)
        if hereState == "unmatchable" then
            row("", "🚨 bk.crashGlob is not set — nothing can be counted"
                    .. " here, AND nothing is being copied. Set it back")
            row("", "   to \"Hammerspoon*\" (the kit drops the whole"
                    .. " entry rather than copying the folder whole).")
        elseif hereState == "unreadable" then
            row("", "🚨 CANNOT READ IT — Hammerspoon has no Full Disk"
                    .. " Access, so this cannot tell you whether there")
            row("", "   are crash reports in there. System Settings →"
                    .. " Privacy & Security → Full Disk Access.")
        elseif hereState == "missing" then
            row("", "no such folder on this Mac — nothing has crashed"
                    .. " here yet (macOS makes it with the first")
            row("", "   report). If Hammerspoon has no Full Disk Access,"
                    .. " that is the other reason it can look absent.")
        elseif hereN > 0 then
            row("", hereN .. " report(s) — the newest is:")
            row("", bk.crashDir .. "/" .. hereNewest)
            row("", "↳ THAT is the file to send: its crashing thread"
                    .. " names the framework that died.")
        else
            row("", "none — Hammerspoon has not crashed here (or macOS"
                    .. " has already pruned them).")
        end
        if not bk.crashes then
            row("backup:", "OFF — bk.crashes is false, nothing is copied")
        elseif not bk.crashDest then
            row("backup:", "nowhere — no OneDrive on this Mac (§0.1), so"
                           .. " these stay here and macOS will prune them")
        else
            local kitN, kitNewest, kitState, kitNames, kitCapped =
                bk.crashScan(bk.crashDest)
            row("backup:", bk.crashDest)
            if hereCapped or kitCapped then
                row("", "⚠️ stopped counting at " .. tostring(bk.crashScanMax)
                        .. " names — the totals below are a floor, not a"
                        .. " total.")
            end
            if kitState == "unmatchable" then
                row("", "nothing can be counted there either, for the"
                        .. " same reason.")
            elseif kitState == "unreadable" then
                row("", "🚨 CANNOT READ THE BACKUP FOLDER — so this cannot"
                        .. " say what is kept there. It may hold every")
                row("", "   report macOS has already pruned. Grant Full"
                        .. " Disk Access and ask again.")
            elseif kitState == "missing" then
                row("", "nothing copied there yet — the folder appears"
                        .. " with the first report")
            else
                row("", kitN .. " kept"
                        .. (kitNewest and (", newest " .. kitNewest) or ""))
            end
            -- THE QUESTION LL IS ACTUALLY ASKING: is the newest one
            -- safe? Asked by NAME, never by subtracting two counts.
            if hereState == "ok" and hereNewest and kitState == "ok" then
                if kitNames[hereNewest] then
                    row("", "✅ the newest report on this Mac IS in the"
                            .. " backup")
                else
                    row("", "⏳ the newest report on this Mac is NOT in the"
                            .. " backup yet — _G.backupNow() takes it now;")
                    row("", "   " .. bk.time .. " takes it anyway")
                end
            end
        end
        row("note:", "macOS deletes the originals on its own schedule."
                     .. " Nothing in the backup is ever deleted.")
        print(table.concat(L, "\n"))
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
        -- 🚨 6.197.0 — the crash reports, counted where they actually
        -- are. This line is here rather than only in _G.crashReport()
        -- because it answers the question LL asked ("if this Mac gets
        -- wiped, do I lose this?") and nobody runs a report they have
        -- not been told exists.
        if not bk.crashes then
            L[#L + 1] = "   crashes : not copied — bk.crashes is false"
        elseif not bk.crashDest then
            local hereN, _, hereState = bk.crashScan(bk.crashDir)
            L[#L + 1] = "   crashes : "
                        .. bk.crashSay(hereN, hereState, "on this Mac")
                        .. " and nowhere to copy them — no OneDrive (§0.1)"
        else
            local hereN, hereNewest, hereState, _, hereCapped =
                bk.crashScan(bk.crashDir)
            local kitN, kitNewest, kitState, kitNames, kitCapped =
                bk.crashScan(bk.crashDest)
            -- Four states, four sentences. "unmatchable" used to fall
            -- through to UNREADABLE, which everywhere else in this file
            -- means "macOS refused us" and sent LL to System Settings for
            -- a permission he already had.
            local kept = kitState == "ok" and (kitN .. " kept")
                         or kitState == "missing" and "none copied yet"
                         or kitState == "unmatchable" and "NOT being copied"
                         or "backup folder UNREADABLE"
            L[#L + 1] = "   crashes : " .. kept .. " · "
                        .. bk.crashSay(hereN, hereState, "on this Mac")
                        .. "  → " .. bk.crashDest
            -- 🚨 BOTH FOLDERS HAVE TO HAVE BEEN READ before either of
            -- these sentences is true. A backup folder we were REFUSED
            -- may hold every pruned report there is — saying "none
            -- anywhere" there is the same lie the state exists to stop,
            -- just told about the other folder.
            if kitNewest then
                L[#L + 1] = "             newest kept: " .. kitNewest
                            .. " — _G.crashReport() has the full path"
            elseif kitState == "unreadable" then
                L[#L + 1] = "             …so this cannot say what is kept"
                            .. " there. Grant Full Disk Access and ask again."
            elseif hereState == "ok" and hereN > 0 then
                L[#L + 1] = "             none copied yet — _G.backupNow()"
                            .. " takes them"
            elseif hereState == "ok" then
                L[#L + 1] = "             none anywhere — Hammerspoon has not"
                            .. " crashed on this Mac"
            end
            if hereCapped or kitCapped then
                L[#L + 1] = "             ⚠️ stopped counting at "
                            .. tostring(bk.crashScanMax) .. " names — those"
                            .. " numbers are a floor, not a total"
            end
            -- Membership, not subtraction — see bk.crashScan.
            if hereState == "ok" and hereNewest and kitState == "ok" then
                L[#L + 1] = "             " .. (kitNames[hereNewest]
                    and "✅ the newest one on this Mac is in the backup"
                    or ("⏳ the newest one on this Mac is NOT backed up yet"
                        .. " — _G.backupNow()"))
            end
        end
        -- 6.190.0 — the stores are a SEPARATE job from the kit, on their
        -- own timer, so they get their own lines. The degraded states are
        -- named rather than left to read as silence.
        L[#L + 1] = "   stores  : " .. tostring(core.logsDir)
        local state = _G.localFirstState or "off"
        if state == "local" then
            L[#L + 1] = "             on THIS Mac (localFirst) — no "
                        .. "placeholder can block the main thread"
        elseif state == "seeding" then
            L[#L + 1] = "             ⏳ localFirst is ON but not seeded yet — "
                        .. "still OneDrive; copying, then RELOAD"
        elseif state == "seeded" then
            L[#L + 1] = "             ✅ copied locally — RELOAD to start "
                        .. "using " .. tostring(_G.localLogsDir)
        else
            L[#L + 1] = "             in OneDrive (localFirst is off)"
        end
        if (tonumber(bk.mirrorMins) or 0) > 0 then
            L[#L + 1] = "   mirror  : every " .. bk.mirrorMins .. " min → "
                        .. (bk.mirrorDest or "nowhere — no OneDrive")
            local m = bk.mirrorLast
            if m then
                L[#L + 1] = "             last " .. tostring(m.at or "—") .. " "
                            .. (m.ok and "ok" or ("FAILED: " .. tostring(m.why)))
            else
                L[#L + 1] = "             not run yet this session"
            end
        else
            L[#L + 1] = "   mirror  : off (bk.mirrorMins = 0)"
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
    _G.crashReport  = function() return bk.crashReport() end
    if core.provide then
        core.provide("backup.now",    function() return bk.run(true) end)
        core.provide("backup.report", function() return bk.report() end)
    end

    -- =====================================================================
    -- 🏠 THE STORES: MIRRORED HALF-HOURLY, AND SEEDED ONCE (6.190.0)
    -- =====================================================================
    -- Two jobs, one rsync each, both in HELD hs.tasks and never on the
    -- main thread — the whole point of the local switch is that nothing
    -- about a store touches the main thread again.
    --
    --   MIRROR  logs → <OneDrive>/Backups/Hammerspoon/<Mac>/Logs, every
    --           bk.mirrorMins. It is a COPY, never a move: nothing is
    --           deleted at either end, and --delete is deliberately absent
    --           so a store that failed to load this session cannot erase
    --           its own backup.
    --   SEED    <OneDrive>/Logs → the local folder, ONCE, when init.lua
    --           says localFirst is on but the local folder is still empty.
    --           Until it finishes this session keeps using OneDrive, so
    --           nothing is ever blank.
    --
    -- Both return ok, why and neither ever throws: a Mac with no OneDrive
    -- reports "nowhere to mirror to" and everything else still works.
    bk.mirrorDest = core.backupDir and (core.backupDir .. "/Logs") or nil

    function bk.mirrorStores(done)
        done = type(done) == "function" and done or function() end
        local src = core.logsDir
        if not (src and src ~= "") then
            bk.mirrorLast = { ok = false, why = "no logs folder" }
            return done(false, "no logs folder")
        end
        if not bk.mirrorDest then
            bk.mirrorLast = { ok = false, why = "no OneDrive — nowhere to mirror to" }
            return done(false, "no OneDrive — nowhere to mirror to")
        end
        if src == bk.mirrorDest then
            bk.mirrorLast = { ok = false, why = "source and destination are the same" }
            return done(false, "source and destination are the same")
        end
        mkpath(bk.mirrorDest)
        local args = { "-a" }
        for _, pat in ipairs(bk.excludes) do
            args[#args + 1] = "--exclude"; args[#args + 1] = pat
        end
        args[#args + 1] = src .. "/"
        args[#args + 1] = bk.mirrorDest .. "/"
        local okT = pcall(function()
            local t = hs.task.new("/usr/bin/rsync", function(code, _, se)
                bk.mirrorTask = nil
                local ok = (code == 0)
                bk.mirrorLast = { at = os.date("%Y-%m-%d %H:%M"), ok = ok,
                                  why = ok and "" or ("rsync exit " .. tostring(code)
                                        .. ": " .. tostring(se or ""):sub(1, 120)) }
                if not ok then warn("store mirror failed — " .. bk.mirrorLast.why) end
                done(ok, bk.mirrorLast.why)
            end, args)
            bk.mirrorTask = t          -- HELD: an unreferenced task is collected
            t:start()
        end)
        if not okT then
            bk.mirrorLast = { ok = false, why = "could not start rsync" }
            return done(false, "could not start rsync")
        end
        return true
    end

    -- Runs ONCE, and only into an EMPTY folder: a seed over a local store
    -- that already has this session\'s writes in it would overwrite them
    -- with the older cloud copy, which is data loss dressed as a restore.
    function bk.seedLocalStores(done)
        done = type(done) == "function" and done or function() end
        if _G.localFirstState ~= "seeding" then
            return done(false, "nothing to seed")
        end
        local dest = _G.localLogsDir
        local src  = core.cloudDir and (core.cloudDir .. "/Logs") or nil
        if not (dest and src) then return done(false, "no OneDrive to seed from") end
        local empty = true
        pcall(function()
            for entry in hs.fs.dir(dest) do
                if entry ~= "." and entry ~= ".." then empty = false break end
            end
        end)
        if not empty then return done(false, "the local folder is not empty") end
        mkpath(dest)
        local okT = pcall(function()
            local t = hs.task.new("/usr/bin/rsync", function(code)
                bk.seedTask = nil
                if code == 0 then
                    _G.localFirstState = "seeded"
                    print("🏠 The stores have been copied to " .. dest
                          .. " — RELOAD Hammerspoon and they are the live ones.")
                    pcall(function()
                        hs.alert.show("🏠 Stores copied locally — reload to use them", 6)
                    end)
                else
                    warn("could not seed the local stores (rsync exit "
                         .. tostring(code) .. ") — still using OneDrive")
                end
                done(code == 0)
            end, { "-a", src .. "/", dest .. "/" })
            bk.seedTask = t
            t:start()
        end)
        if not okT then return done(false, "could not start rsync") end
        return true
    end

    _G.storeMirrorNow = function() return bk.mirrorStores() end

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

    -- HELD in _G, like every other timer here: an unreferenced timer is
    -- collected and a collected timer never fires.
    if (tonumber(bk.mirrorMins) or 0) > 0 and bk.enabled then
        _G.storeMirrorTimer = hs.timer.doEvery(bk.mirrorMins * 60,
                                               function() bk.mirrorStores() end)
        -- Not at boot: the first one waits, so a reload never adds an
        -- rsync to the moment everything else is starting.
        _G.storeMirrorFirst = hs.timer.doAfter(bk.mirrorFirst,
                                               function() bk.mirrorStores() end)
        say("stores mirror every " .. bk.mirrorMins .. " min → "
            .. tostring(bk.mirrorDest))
    end
    if _G.localFirstState == "seeding" then
        print("🏠 Local stores are switched ON but nothing is there yet — "
              .. "still using OneDrive this session, copying in the "
              .. "background.")
        _G.storeSeedTimer = hs.timer.doAfter(10, function() bk.seedLocalStores() end)
    end

    _G.dailyBackup = bk
    M.bk     = bk
    M.config = bk
end

return M
