-- =====================================================================
-- test_daily_backup.lua — the rebuild kit: what leaves, what never does
-- =====================================================================
--     lua5.4 test_daily_backup.lua [/path/to/hammerspoon]
--
-- Executes modules/daily_backup.lua against a stubbed Mac and drives the
-- REAL run: the kit table, the one-at-a-time task chain, the rsync
-- argument arrays, the app manifest with its three sources, the written
-- apps.csv and README.md, the degradation paths (no OneDrive, no brew,
-- Full Disk Access refused), and — above everything — the promise that
-- secret.lua and the SSH keys never leave the machine.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

-- Real files land here: the manifest and README are checked by READING
-- THEM BACK, not by trusting the code that claims to have written them.
local TMP = "/tmp/hs-test-backup-" .. tostring(os.time()) .. "-"
            .. tostring(math.random(10000))
os.execute("mkdir -p '" .. TMP .. "/RebuildKit'")

-- ---- the stub Mac ------------------------------------------------------
local FS      = {}   -- set of paths that exist
local DIRLIST = {}   -- hs.fs.dir listings per folder
local PLISTS  = {}   -- hs.plist.read results per path
local TASKS   = {}   -- every hs.task, completed by hand from a script
local TIMERS  = {}   -- every doAfter/doEvery/doAt
local ALERTS  = {}
local MKDIRS  = {}
local SETTINGS = {}
local SEQ     = {}   -- start/done interleaving, proving one-at-a-time

hs = {
    fs = {
        attributes = function(p) return FS[p] and { mode = FS[p] } or nil end,
        mkdir      = function(p) MKDIRS[#MKDIRS + 1] = p return true end,
        dir        = function(d)
            local list = DIRLIST[d]
            if not list then error("no such directory: " .. tostring(d)) end
            local i = 0
            return function() i = i + 1 return list[i] end
        end,
    },
    plist = { read = function(p) return PLISTS[p] end },
    task = {
        new = function(bin, cb, args)
            local t = { bin = bin, cb = cb, args = args,
                        started = false, completed = false, terminated = false }
            t.idx = #TASKS + 1
            function t:start()
                self.started = true
                SEQ[#SEQ + 1] = "start " .. self.idx
                return self
            end
            function t:terminate() self.terminated = true return self end
            TASKS[#TASKS + 1] = t
            return t
        end,
    },
    timer = {
        absoluteTime = (function()
            local at = 0
            return function() at = at + 1000000 return at end
        end)(),
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, every = true, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doAt = function(when, rep, fn)
            local t = { at = when, every = rep, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    settings = {
        get = function(k) return SETTINGS[k] end,
        set = function(k, v) SETTINGS[k] = v end,
    },
    alert = { show = function(msg) ALERTS[#ALERTS + 1] = tostring(msg) end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local PROVIDED = {}
local CORE = {
    version   = "6.139.0-test",
    homeDir   = "/Users/ll",
    cloudDir  = "/Users/ll/Library/CloudStorage/OneDrive-Personal",
    logsDir   = "/logs",
    backupDir = TMP,
    configDir = "/Users/ll/.hammerspoon",
    hostTag   = "Test-Mac",
    csvQuote  = function(v)
        local s = tostring(v or ""):gsub('[\r\n]+', ' '):gsub('"', '""')
        return '"' .. s .. '"'
    end,
    warnWriteFailed = function() end,
    provide   = function(n, f) PROVIDED[n] = f end,
}

-- Drives the chain: fires the short step timers, then completes exactly
-- the tasks that are in flight, feeding each the next scripted result.
-- The 600s watchdogs are deliberately NOT fired here — a watchdog that
-- fires before its task completes is its own test, run by hand below.
local function pump(script)
    local si = 0
    for _ = 1, 400 do
        local acted = false
        for _, t in ipairs(TIMERS) do
            if not t.every and not t.at and not t.done and not t.stopped
               and (t.secs or 0) <= 1 then
                t.done = true acted = true t.fn()
            end
        end
        for _, tk in ipairs(TASKS) do
            if tk.started and not tk.completed then
                tk.completed = true
                SEQ[#SEQ + 1] = "done " .. tk.idx
                si = si + 1
                local r = script[si] or { 0, "", "" }
                acted = true
                tk.cb(r[1], r[2], r[3])
            end
        end
        if not acted then return end
    end
end

local function readBack(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

-- ---- the fake Mac's contents -------------------------------------------
FS["/opt/homebrew/bin/brew"]        = "file"
FS["/Users/ll/.hammerspoon"]        = "directory"
FS["/Users/ll/.zshrc"]              = "file"
-- .zprofile deliberately absent: a missing source is "not on this Mac"
FS["/Users/ll/.gitconfig"]          = "file"
FS["/Users/ll/.ssh/config"]         = "file"
FS["/Users/ll/.config"]             = "directory"
FS["/Users/ll/Library/LaunchAgents"]= "directory"
FS["/Users/ll/Library/Fonts"]       = "directory"
FS["/Users/ll/Documents"]           = "directory"
FS["/Users/ll/Desktop"]             = "directory"
FS["/Users/ll/Library/Logs/DiagnosticReports"] = "directory"

-- 🚨 6.197.0 — the crash-report folder as macOS really leaves it: OUR
-- reports in two different generations of name, and another app's beside
-- them. The legacy `Hammerspoon_<date>_<Mac>.crash` is the trap: "_"
-- sorts AFTER "-", so a plain string compare calls that 2024 file the
-- newest and hands LL the wrong evidence with a straight face.
local CRASHDIR  = "/Users/ll/Library/Logs/DiagnosticReports"
local CRASHDEST = TMP .. "/RebuildKit/CrashReports"
DIRLIST[CRASHDIR] = { ".", "..",
    "Hammerspoon-2026-09-01-093000.ips",
    "Hammerspoon-2026-09-09-114412.ips",
    "Hammerspoon_2024-01-02-030405_Lees-MacBook-Air.crash",
    "Google Chrome-2026-09-08-120000.ips" }
DIRLIST[CRASHDEST] = { ".", "..", "Hammerspoon-2026-09-01-093000.ips" }
FS[CRASHDIR]  = "directory"
FS[CRASHDEST] = "directory"
-- A folder that is THERE and will not open: macOS guards
-- DiagnosticReports behind Full Disk Access, and that is the state a
-- count alone cannot tell apart from "no crashes, you are fine".
FS["/refused"] = "directory"    -- exists, no DIRLIST → the listing throws
FS["/emptydiag"] = "directory"  -- readable and genuinely empty
DIRLIST["/emptydiag"] = { ".", ".." }
-- An UNDATED name beside dated ones: letters sort above digits in a byte
-- compare, so one Hammerspoon.crash would outrank every real report.
FS["/undated"] = "directory"
DIRLIST["/undated"] = { ".", "..", "Hammerspoon.crash",
                        "Hammerspoon-2026-09-09-114412.ips" }
FS["/allundated"] = "directory"
DIRLIST["/allundated"] = { ".", "..", "Hammerspoon.crash", "Hammerspoon.other" }

DIRLIST["/Applications"] = { "Safari.app", "Google Chrome.app",
                             "Hammerspoon.app", "WeirdTool.app", "notes.txt" }
DIRLIST["/Users/ll/Applications"] = { "Ghostty.app" }
PLISTS["/Applications/Safari.app/Contents/Info.plist"] =
    { CFBundleIdentifier = "com.apple.Safari", CFBundleShortVersionString = "18.0" }
PLISTS["/Applications/Google Chrome.app/Contents/Info.plist"] =
    { CFBundleIdentifier = "com.google.Chrome", CFBundleShortVersionString = "131.0" }
PLISTS["/Applications/Hammerspoon.app/Contents/Info.plist"] =
    { CFBundleIdentifier = "org.hammerspoon.Hammerspoon", CFBundleShortVersionString = "1.0.0" }
PLISTS["/Applications/WeirdTool.app/Contents/Info.plist"] =
    { CFBundleIdentifier = "com.weird.tool", CFBundleShortVersionString = "2.1" }
PLISTS["/Users/ll/Applications/Ghostty.app/Contents/Info.plist"] =
    { CFBundleIdentifier = "com.mitchellh.ghostty", CFBundleShortVersionString = "1.2" }
FS["/Applications/WeirdTool.app/Contents/_MASReceipt/receipt"] = "file"

-- =====================================================================
out("── Daily Backup: the rebuild kit ──\n")
out("\n1. contract & wiring\n")
-- =====================================================================
local M = dofile(HS .. "/modules/daily_backup.lua")
check("module loads and has setup()", type(M.setup) == "function")
check("filed under the auto family", M.family == "auto")
check("cheat group present, no ⇪ key claimed", (function()
    if type(M.cheatsheet) ~= "table" then return false end
    for _, e in ipairs(M.cheatsheet.entries) do
        if tostring(e[1]):match("^⇪") then return false end
    end
    return #M.cheatsheet.entries >= 5
end)())
check("…and the sheet SAYS what never leaves the Mac", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if tostring(e[2]):find("secret.lua", 1, true) then return true end
    end
    return false
end)())

M.setup(CORE)
local bk = _G.dailyBackup
check("namespace exported", type(bk) == "table")
check("console commands published",
      type(_G.backupNow) == "function" and type(_G.backupReport) == "function"
      and type(_G.backupAdopt) == "function")
check("services provided for the power tools rows",
      type(PROVIDED["backup.now"]) == "function"
      and type(PROVIDED["backup.report"]) == "function")
check("the daily timer is armed at bk.time, repeating daily", (function()
    for _, t in ipairs(TIMERS) do
        if t.at == bk.time and t.every == "1d" then return true end
    end
    return false
end)())
check("Homebrew found at its Apple Silicon home", bk.brew == "/opt/homebrew/bin/brew")
check("config table exported for per-machine profile overrides",
      M.config == bk)

-- =====================================================================
out("\n2. 🚨 the kit table — what is IN is curated, what is OUT is law\n")
-- =====================================================================
local kit = bk.buildKit()
local ids = {}
for _, e in ipairs(kit) do ids[e.id] = e end
check("the config entry still lands at the backup root (unchanged home)",
      ids.config and ids.config.dest == TMP, ids.config and ids.config.dest)
check("everything else lands inside RebuildKit/", (function()
    for _, e in ipairs(kit) do
        if e.id ~= "config" and not e.dest:find("/RebuildKit", 1, true) then
            return false
        end
    end
    return true
end)())
check("Documents and Desktop ride along while bk.docs is true",
      ids.documents ~= nil and ids.desktop ~= nil)
bk.docs = false
local worKit = bk.buildKit()
-- 6.140.1 — no shipped profile sets this any more (LL: "all documents
-- are safe to backup" on the work Mac too), but the knob must keep
-- working for any future Mac that needs it.
check("…and the docs=false knob drops exactly those two",
      #worKit == #kit - 2, #worKit)
bk.docs = true
check("🚨 SSH appears ONLY as its config FILE — never the keys folder", (function()
    for _, e in ipairs(kit) do
        if e.src:match("%.ssh$") then return false end          -- the folder
        if e.src:find("id_rsa", 1, true) then return false end
        if e.src:find("id_ed25519", 1, true) then return false end
    end
    return ids.sshconfig and ids.sshconfig.file == true
           and ids.sshconfig.src == "/Users/ll/.ssh/config"
end)())
-- 🚨 6.197.0 — LL: "If my work Mac or my home Mac get wiped, I will lose
-- this information for you." Crash reports lived in exactly one place,
-- macOS prunes it, and nothing here had ever copied them.
check("🚨 6.197.0 — Hammerspoon's crash reports are IN the kit",
      ids.crashes ~= nil
      and ids.crashes.src == "/Users/ll/Library/Logs/DiagnosticReports"
      and ids.crashes.dest == TMP .. "/RebuildKit/CrashReports",
      ids.crashes and (ids.crashes.src .. " → " .. ids.crashes.dest))
check("🚨 ...and the entry is FILTERED, never the bare folder — that "
      .. "folder holds every app's diagnostics and this destination is "
      .. "a cloud folder",
      ids.crashes and ids.crashes.only == "Hammerspoon*",
      ids.crashes and tostring(ids.crashes.only))
check("...the rollback knob drops exactly that one entry", (function()
    bk.crashes = false
    local noCrash = bk.buildKit()
    bk.crashes = true
    for _, e in ipairs(noCrash) do
        if e.id == "crashes" then return false end
    end
    return #noCrash == #kit - 1
end)())
check("🚨 the Keychain is in no kit entry", (function()
    for _, e in ipairs(kit) do
        if e.src:find("Keychain", 1, true) then return false end
    end
    return true
end)())
check("🚨 secret.lua is in the global exclude list — every rsync, not just one",
      (function()
    for _, pat in ipairs(bk.excludes) do
        if pat == "secret.lua" then return true end
    end
    return false
end)())

-- =====================================================================
out("\n3. the run — one thing in flight, argument arrays, honest records\n")
-- =====================================================================
check("run() reports it started", bk.run(true) == true)
check("…and a second call while running is refused", bk.run(true) == false)
check("…with an alert saying so",
      ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("already running", 1, true) ~= nil,
      ALERTS[#ALERTS])

pump({
    { 0, "Number of regular files transferred: 12\n", "" },   -- config
    { 0, "Number of regular files transferred: 1\n",  "" },   -- zshrc
    { 0, "Number of regular files transferred: 1\n",  "" },   -- gitconfig
    { 0, "Number of regular files transferred: 1\n",  "" },   -- sshconfig
    { 0, "Number of regular files transferred: 40\n", "" },   -- .config
    { 0, "Number of regular files transferred: 3\n",  "" },   -- LaunchAgents
    { 23, "", "rsync: opendir failed: Operation not permitted (1)" }, -- Fonts
    { 0, "Number of regular files transferred: 2\n",  "" },   -- CrashReports
    { 0, "Number of regular files transferred: 900\n", "" },  -- Documents
    { 0, "Number of regular files transferred: 33\n",  "" },  -- Desktop
    { 0, "google-chrome\nhammerspoon\n", "" },                -- brew list
    { 0, "", "" },                                            -- brew bundle dump
})

check("the run finished and stood down", bk.running == false)
check("🚨 every external command is an ARGUMENT ARRAY — no shell anywhere",
      (function()
    for _, t in ipairs(TASKS) do
        if t.bin:find("sh$") then return false end
        for _, a in ipairs(t.args) do
            if tostring(a):find("&&", 1, true) then return false end
        end
    end
    return #TASKS >= 11
end)(), #TASKS)
check("🚨 every rsync carries --exclude secret.lua", (function()
    local sawRsync = false
    for _, t in ipairs(TASKS) do
        if t.bin == "/usr/bin/rsync" then
            sawRsync = true
            local hit = false
            for i, a in ipairs(t.args) do
                if a == "--exclude" and t.args[i + 1] == "secret.lua" then hit = true end
            end
            if not hit then return false end
        end
    end
    return sawRsync
end)())
-- 🚨 6.197.0 — THE FILTER, ARGUMENT BY ARGUMENT. rsync takes the FIRST
-- rule that matches a path, so the whole safety of pointing this at
-- ~/Library/Logs/DiagnosticReports is that the includes come BEFORE the
-- catch-all exclude — and that the catch-all is there at all.
local crashArgs = (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/usr/bin/rsync" then
            for _, a in ipairs(t.args) do
                if tostring(a):find("DiagnosticReports", 1, true) then
                    return t.args
                end
            end
        end
    end
    return nil
end)()
local function argIndex(args, want, after)
    for i = (after or 1), #args do
        if args[i] == want then return i end
    end
    return nil
end
check("🚨 the crash copy takes ONLY Hammerspoon's own reports — the name "
      .. "include, then a catch-all exclude, in that order", (function()
    if not crashArgs then return false end
    local inc = argIndex(crashArgs, "--include")
    local hitName, catchAll = nil, nil
    for i = 1, #crashArgs - 1 do
        if crashArgs[i] == "--include" and crashArgs[i + 1] == "Hammerspoon*" then
            hitName = i
        end
        if crashArgs[i] == "--exclude" and crashArgs[i + 1] == "*" then
            catchAll = i
        end
    end
    return inc ~= nil and hitName ~= nil and catchAll ~= nil
           and hitName < catchAll
end)(), crashArgs and table.concat(crashArgs, " "))
check("🚨 ...and it walks INTO folders (macOS keeps older reports in a "
      .. "Retired/ one), pruning the empty ones -m leaves", (function()
    if not crashArgs then return false end
    local dirs, catchAll, dashM = nil, nil, false
    for i = 1, #crashArgs do
        if crashArgs[i] == "-m" then dashM = true end
        if crashArgs[i] == "--include" and crashArgs[i + 1] == "*/" then dirs = i end
        if crashArgs[i] == "--exclude" and crashArgs[i + 1] == "*" then catchAll = i end
    end
    return dashM and dirs ~= nil and catchAll ~= nil and dirs < catchAll
end)(), crashArgs and table.concat(crashArgs, " "))
check("🚨 ...with NO --delete: macOS prunes the originals, and a backup "
      .. "that followed would delete the only evidence there is",
      (function()
    if not crashArgs then return false end
    for _, a in ipairs(crashArgs) do
        if tostring(a):find("delete", 1, true) then return false end
    end
    return true
end)())
check("🚨 ...and the filter is SCOPED to that one entry — a catch-all in "
      .. "the shared arguments would empty every other rsync in the kit",
      (function()
    local others = 0
    for _, t in ipairs(TASKS) do
        if t.bin == "/usr/bin/rsync" and t.args ~= crashArgs then
            others = others + 1
            for i = 1, #t.args - 1 do
                if t.args[i] == "--exclude" and t.args[i + 1] == "*" then
                    return false
                end
                if t.args[i] == "-m" then return false end
            end
        end
    end
    return others >= 6
end)())
check("🚨 one task at a time — task N+1 never starts before N completes",
      (function()
    local open = 0
    for _, ev in ipairs(SEQ) do
        if ev:match("^start") then
            open = open + 1
            if open > 1 then return false end
        else
            open = open - 1
        end
    end
    return true
end)(), table.concat(SEQ, " · "))

local rec = {}
for _, e in ipairs(bk.last.entries) do rec[e.id] = e end
check("a healthy rsync records its file count",
      rec.config and rec.config.status == "ok"
      and rec.config.detail:find("12 files", 1, true) ~= nil,
      rec.config and rec.config.detail)
check("a missing source is 'not on this Mac', never a failure",
      rec.zprofile and rec.zprofile.status == "skipped",
      rec.zprofile and rec.zprofile.status)
check("the crash copy records its file count like any other entry",
      rec.crashes and rec.crashes.status == "ok"
      and rec.crashes.detail:find("2 files", 1, true) ~= nil,
      rec.crashes and rec.crashes.detail)
check("a permission refusal is partial AND names Full Disk Access",
      rec.fonts and rec.fonts.status == "partial"
      and rec.fonts.detail:find("Full Disk Access", 1, true) ~= nil,
      rec.fonts and rec.fonts.detail)
check("the Brewfile step ran through brew bundle dump --force", (function()
    for _, t in ipairs(TASKS) do
        if t.bin == "/opt/homebrew/bin/brew" and t.args[1] == "bundle" then
            return t.args[2] == "dump" and t.args[3] == "--force"
        end
    end
    return false
end)())
check("the manual run ends in one quiet summary alert",
      ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("Rebuild kit updated", 1, true) ~= nil,
      ALERTS[#ALERTS])
check("the summary survives a reload (hs.settings)",
      type(SETTINGS["dailyBackup.last"]) == "table"
      and SETTINGS["dailyBackup.last"].appCount == 4)

-- =====================================================================
out("\n4. the app manifest — every app, and how to get it back\n")
-- =====================================================================
local apps = {}
for _, r in ipairs(bk.last.apps or {}) do apps[r.app] = r end
check("four apps made the manifest (Apple's own are skipped)",
      bk.last.apps and #bk.last.apps == 4, bk.last.apps and #bk.last.apps)
check("…Safari is the one that was skipped", apps["Safari"] == nil)
check("an owned cask is credited to Homebrew",
      apps["Google Chrome"] and apps["Google Chrome"].source == "homebrew"
      and apps["Google Chrome"].from == "brew install --cask google-chrome",
      apps["Google Chrome"] and apps["Google Chrome"].from)
check("an App Store receipt beats everything",
      apps["WeirdTool"] and apps["WeirdTool"].source == "app-store")
check("everything else is honest: direct, from the vendor",
      apps["Ghostty"] and apps["Ghostty"].source == "direct")
check("cask tokens are derived the way brew names them",
      bk.caskToken("Visual Studio Code") == "visual-studio-code"
      and bk.caskToken("Google Chrome.app") == "google-chrome",
      bk.caskToken("Visual Studio Code"))

local csv = readBack(TMP .. "/RebuildKit/apps.csv")
check("apps.csv was really written, with a header",
      csv ~= nil and csv:find("app,version,bundle_id,source,reinstall", 1, true) == 1)
check("…and carries the Chrome row verbatim",
      csv ~= nil and csv:find('"brew install --cask google-chrome"', 1, true) ~= nil)

local readme = readBack(TMP .. "/RebuildKit/README.md")
check("README.md was really written", readme ~= nil)
check("…it tells future-you to recreate secret.lua BY HAND",
      readme ~= nil and readme:find("secret.lua BY HAND", 1, true) ~= nil)
check("…it points at the token page rather than carrying a token",
      readme ~= nil and readme:find("app.asana.com/0/my%-apps") ~= nil)
check("…and it walks the brew bundle restore",
      readme ~= nil and readme:find("brew bundle --file Brewfile", 1, true) ~= nil)
check("🚨 …and it tells future-you what CrashReports/ is and which file "
      .. "to send — the kit is read on a blank Mac, in a hurry",
      readme ~= nil and readme:find("CrashReports/", 1, true) ~= nil
      and readme:find("newest file in there is the one to send", 1, true) ~= nil,
      readme)

-- =====================================================================
out("\n5. 🍺 adoption — which hand-installed apps brew could own\n")
-- =====================================================================
local LINES = {}
local realPrint = print
print = function(...) LINES[#LINES + 1] = table.concat({ ... }, " ") end
bk.adopt()
pump({ { 0, "==> Casks\nghostty\nghostty@edge\n", "" } })  -- one direct app → one ask
print = realPrint
check("adoption asked brew about exactly the direct apps", (function()
    local n = 0
    for _, t in ipairs(TASKS) do
        if t.bin == "/opt/homebrew/bin/brew" and t.args[1] == "search" then
            n = n + 1
        end
    end
    return n == 1
end)())
check("…an exact cask match becomes an --adopt suggestion", (function()
    for _, l in ipairs(LINES) do
        if l:find("brew install --cask --adopt ghostty", 1, true) then return true end
    end
    return false
end)(), table.concat(LINES, " | "))

-- =====================================================================
out("\n6. failure is loud, refusal is explained\n")
-- =====================================================================
bk.run(true)
pump({ { 12, "", "rsync: connection unexpectedly closed" } })
check("a hard rsync failure is recorded as failed", (function()
    for _, e in ipairs(bk.last.entries) do
        if e.id == "config" and e.status == "failed" then return true end
    end
    return false
end)())
check("…and the run ends in a FAILURE alert pointing at the report",
      (function()
    for _, a in ipairs(ALERTS) do
        if a:find("finished with failures", 1, true) then return true end
    end
    return false
end)())

check("the report prints without error", (function()
    local ok = pcall(function() bk.report() end)
    return ok
end)())

-- =====================================================================
out("\n7. degradation — no brew, no OneDrive, and the sentry\n")
-- =====================================================================
FS["/opt/homebrew/bin/brew"] = nil
M.setup(CORE)
local bk2 = _G.dailyBackup
check("no Homebrew → the module still sets up, brew steps stand down",
      bk2.brew == nil)

local CORE2 = {}
for k, v in pairs(CORE) do CORE2[k] = v end
CORE2.backupDir, CORE2.cloudDir = nil, nil
local before = #TIMERS
local LINES2 = {}
print = function(...) LINES2[#LINES2 + 1] = table.concat({ ... }, " ") end
M.setup(CORE2)
print = realPrint
local bk3 = _G.dailyBackup
check("no OneDrive → no daily timer is armed", (function()
    for i = before + 1, #TIMERS do
        if TIMERS[i].at then return false end
    end
    return true
end)())
check("…the console says so instead", (function()
    for _, l in ipairs(LINES2) do
        if l:find("No OneDrive", 1, true) then return true end
    end
    return false
end)())
ALERTS = {}
check("…and a by-hand run EXPLAINS rather than half-working",
      bk3.run(true) == false and ALERTS[1]
      and ALERTS[1]:find("No OneDrive", 1, true) ~= nil, ALERTS[1])

-- 🚨 THE ASYNC SENTRY. The 6.137.0 lag was synchronous work on the one
-- thread every keystroke shares. This module runs rsync and brew — the
-- exact kind of slow call that recreates it — so the shipped file must
-- never contain a synchronous escape hatch.
local src = readBack(HS .. "/modules/daily_backup.lua") or ""
check("🚨 the module never shells synchronously (io.popen / os.execute / hs.execute)",
      not src:find("io%.popen") and not src:find("os%.execute")
      and not src:find("hs%.execute"))
check("🚨 nor does it build shell strings for a shell binary",
      not src:find('"/bin/zsh"') and not src:find('"/bin/bash"')
      and not src:find('"/bin/sh"'))

-- =====================================================================
out("\n8. 🚨 the crash reports — counted, named, and never deleted (6.197.0)\n")
-- =====================================================================
-- LL had to send a SCREENSHOT of a crash because there was no line to
-- run. These checks are about the line.
do
    local n, newest = bk.crashScan(CRASHDIR)
    check("🚨 the scan counts OUR reports and no other app's",
          n == 3, n)
    check("🚨 ...and picks the newest on the DATE IN THE NAME, not on the "
          .. "name: '_' sorts after '-', so a plain compare hands back a "
          .. "2024 .crash and calls it today's",
          newest == "Hammerspoon-2026-09-09-114412.ips", newest)
    check("a folder that cannot even be listed is 0 — never a throw",
          (function()
              local ok, cnt = pcall(bk.crashScan, "/refused")
              return ok and cnt == 0
          end)())
    check("no folder at all is 0 too", bk.crashScan(nil) == 0)

    -- 🚨 6.196.1's rule, on the folder macOS guards: "cannot see" must
    -- never read the same as "nothing there". Without Full Disk Access
    -- the listing is refused, and a scan that returned only a number
    -- would have the report say "none anywhere — Hammerspoon has not
    -- crashed on this Mac". That is the most reassuring line in the file
    -- and it would be false.
    local _, _, okState = bk.crashScan(CRASHDIR)
    check("a folder we CAN read says so", okState == "ok", okState)
    local rn, _, refState = bk.crashScan("/refused")
    check("🚨 a folder we are REFUSED is 'unreadable', never 0-and-fine",
          refState == "unreadable" and rn == 0, refState)
    local _, undNewest = bk.crashScan("/undated")
    check("🚨 an UNDATED name never outranks a dated report — 'H' sorts "
          .. "above '9', so one Hammerspoon.crash would otherwise be "
          .. "handed over as today's evidence",
          undNewest == "Hammerspoon-2026-09-09-114412.ips", undNewest)
    local allN, allNewest = bk.crashScan("/allundated")
    check("...and with nothing dated at all it still names one",
          allN == 2 and allNewest == "Hammerspoon.other", allNewest)

    local _, _, misState = bk.crashScan("/Users/ll/nothing-here")
    check("...and one that simply is not there is 'missing' — a Mac that "
          .. "has never crashed is not a permissions problem",
          misState == "missing", misState)

    check("_G.crashReport() is published for LL to type",
          type(_G.crashReport) == "function")

    -- bk.crashReport, not the global: §7 re-ran setup on a Mac with no
    -- OneDrive and the global now belongs to THAT namespace.
    local CL, realP = {}, print
    print = function(...) CL[#CL + 1] = table.concat({ ... }, " ") end
    bk.crashReport()
    print = realP
    -- 6.179.1's rule: a report prints as ONE string, or console.lua's
    -- repeat gate swallows rows out of the middle of it.
    check("🚨 the crash report prints as ONE string", #CL == 1, #CL)
    local ct = table.concat(CL, "\n")
    check("🚨 ...and it carries the FULL PATH of the newest report — that "
          .. "is the thing being asked for, and half a path is no use",
          ct:find(CRASHDIR .. "/Hammerspoon-2026-09-09-114412.ips", 1, true) ~= nil,
          ct)
    check("...it names the backup copy, and answers the real question "
          .. "BY NAME: is the newest one on this Mac safe?",
          ct:find(CRASHDEST, 1, true) ~= nil
          and ct:find("newest report on this Mac is NOT in the backup",
                      1, true) ~= nil, ct)
    check("...and it says plainly that nothing in the backup is deleted",
          ct:find("is ever deleted", 1, true) ~= nil, ct)

    local RL = {}
    print = function(...) RL[#RL + 1] = table.concat({ ... }, " ") end
    bk.report()
    print = realP
    local rt = table.concat(RL, "\n")
    check("the backup report names the crash reports without being asked",
          rt:find("crashes :", 1, true) ~= nil
          and rt:find("1 kept · 3 on this Mac", 1, true) ~= nil, rt)
    check("...naming the newest one KEPT (not the newest on the Mac — "
          .. "they are different questions and sat on adjacent lines)",
          rt:find("newest kept: Hammerspoon%-2026%-09%-01") ~= nil, rt)

    -- IT DEGRADES, IT NEVER BREAKS: no OneDrive is a sentence, not a
    -- failure — and it must not read as "you are covered".
    local keptDest = bk.crashDest
    bk.crashDest = nil
    RL = {}
    print = function(...) RL[#RL + 1] = table.concat({ ... }, " ") end
    bk.report()
    bk.crashReport()
    print = realP
    local dt = table.concat(RL, "\n")
    check("🚨 no OneDrive → both reports SAY there is nowhere to copy them,"
          .. " rather than going quiet",
          dt:find("nowhere to copy them", 1, true) ~= nil
          and dt:find("nowhere — no OneDrive", 1, true) ~= nil, dt)
    bk.crashDest = keptDest

    -- 🚨 And the whole point of the state: what BOTH reports say when
    -- the folder is there and macOS will not open it.
    local keptDir = bk.crashDir
    bk.crashDir = "/refused"
    local function capture(fn)
        local out, realp = {}, print
        print = function(...) out[#out + 1] = table.concat({ ... }, " ") end
        fn()
        print = realp
        return table.concat(out, "\n")
    end
    local bt = capture(function() bk.report() end)
    local kt = capture(function() bk.crashReport() end)
    check("🚨 refused → the BACKUP report names Full Disk Access",
          bt:find("Full Disk Access", 1, true) ~= nil, bt)
    check("🚨 refused → the CRASH report names Full Disk Access",
          kt:find("Full Disk Access", 1, true) ~= nil, kt)
    check("🚨 ...and NEITHER of them says 'has not crashed on this Mac' — "
          .. "that sentence is the lie this state exists to prevent",
          bt:find("has not crashed", 1, true) == nil
          and kt:find("has not crashed", 1, true) == nil, bt .. "\n" .. kt)
    bk.crashDir = keptDir

    -- 🚨 THE TRAP A COUNT WALKS INTO. The two folders diverge BY
    -- DESIGN: macOS prunes the Mac's copy and nothing prunes the
    -- backup, so after the first prune the backup holds MORE than the
    -- Mac does — and "hereN > kitN" can never fire again, on the very
    -- day a fresh crash has not been copied. Membership, not
    -- subtraction.
    FS["/mac2"]  = "directory"
    FS["/kit2"]  = "directory"
    DIRLIST["/mac2"] = { ".", "..",
        "Hammerspoon-2026-06-01-090000.ips",       -- also in the backup
        "Hammerspoon-2026-09-09-114412.ips" }      -- TODAY, not copied
    DIRLIST["/kit2"] = { ".", "..",
        "Hammerspoon-2026-01-01-000000.ips",       -- macOS pruned this one
        "Hammerspoon-2026-02-01-000000.ips",       -- and this one
        "Hammerspoon-2026-06-01-090000.ips" }
    local keptDir3, keptDest3 = bk.crashDir, bk.crashDest
    bk.crashDir, bk.crashDest = "/mac2", "/kit2"
    local bt3 = capture(function() bk.report() end)
    local kt3 = capture(function() bk.crashReport() end)
    check("🚨 the backup holds MORE than the Mac and today's crash is "
          .. "still missing — BOTH reports must say so",
          bt3:find("NOT backed up yet", 1, true) ~= nil
          and kt3:find("is NOT in the backup yet", 1, true) ~= nil,
          bt3 .. "\n" .. kt3)
    DIRLIST["/kit2"] = { ".", "..",
        "Hammerspoon-2026-01-01-000000.ips",
        "Hammerspoon-2026-06-01-090000.ips",
        "Hammerspoon-2026-09-09-114412.ips" }
    local bt4 = capture(function() bk.report() end)
    local kt4 = capture(function() bk.crashReport() end)
    check("...and once it IS there both say so plainly",
          bt4:find("is in the backup", 1, true) ~= nil
          and kt4:find("IS in the backup", 1, true) ~= nil,
          bt4 .. "\n" .. kt4)
    bk.crashDir, bk.crashDest = keptDir3, keptDest3

    -- 🚨 The glob and the COPY must never disagree. bk is exported as
    -- M.config, so a profile override can change it — and a scan that
    -- only understood a literal prefix answered "no such folder" about a
    -- folder full of reports rsync was copying correctly.
    do
        local keptGlob = bk.crashGlob
        bk.crashGlob = "*.ips"
        local n2 = bk.crashScan(CRASHDIR)
        check("🚨 a glob with a LEADING wildcard is matched, not "
              .. "shrugged at — the copy uses the same glob",
              n2 == 3, n2)
        bk.crashGlob = "Hammerspoon-*.ips"
        check("...and a narrower glob really narrows (the legacy .crash "
              .. "drops out)", bk.crashScan(CRASHDIR) == 2,
              bk.crashScan(CRASHDIR))
        bk.crashGlob = ""
        local n3, _, st3 = bk.crashScan(CRASHDIR)
        check("🚨 an EMPTY glob is 'unmatchable' — never one of the two "
              .. "reassuring states",
              n3 == 0 and st3 == "unmatchable", st3)
        local et = capture(function() bk.crashReport() end)
        check("...and the report says the count is impossible while the "
              .. "copy is unaffected",
              et:find("nothing can be counted", 1, true) ~= nil, et)
        bk.crashGlob = keptGlob
    end

    -- 🚨 THE OTHER FOLDER. A BACKUP folder we were refused may hold every
    -- report macOS has already pruned — which is the whole point of this
    -- release — so neither report may say "none anywhere" about it.
    local keptDir2, keptDest2 = bk.crashDir, bk.crashDest
    bk.crashDir, bk.crashDest = "/emptydiag", "/refused"
    local bt2 = capture(function() bk.report() end)
    local kt2 = capture(function() bk.crashReport() end)
    -- The local folder here really IS readable and really IS empty, so
    -- "none — Hammerspoon has not crashed here" is TRUE of it. What must
    -- never appear is a claim about the folder nobody could open.
    check("🚨 backup folder refused → the backup report never says 'none "
          .. "anywhere' or 'none copied yet' about it",
          bt2:find("none anywhere", 1, true) == nil
          and bt2:find("none copied yet", 1, true) == nil, bt2)
    check("🚨 ...and neither report counts what is waiting to be copied",
          bt2:find("not copied yet", 1, true) == nil
          and kt2:find("not copied yet", 1, true) == nil,
          bt2 .. "\n" .. kt2)
    check("🚨 ...and both say the backup folder could not be read",
          bt2:find("cannot say what is kept", 1, true) ~= nil
          and kt2:find("CANNOT READ THE BACKUP FOLDER", 1, true) ~= nil,
          bt2 .. "\n" .. kt2)
    bk.crashDir, bk.crashDest = keptDir2, keptDest2

    -- 🚨 A core with no home folder must not leave bk.crashDir rooted
    -- at "/" — /Library/Logs/DiagnosticReports is the SYSTEM folder, and
    -- aiming an rsync there by accident is not a degrade.
    do
        local CORE3 = {}
        for k, v in pairs(CORE) do CORE3[k] = v end
        CORE3.homeDir = nil
        local realP3 = print
        print = function() end
        M.setup(CORE3)
        print = realP3
        local bk4 = _G.dailyBackup
        check("🚨 no home folder → no crash source, and NOTHING rooted at /",
              bk4.crashDir == nil, tostring(bk4.crashDir))
        -- buildKit itself needs a home folder for the dotfiles rows —
        -- that predates this release — so the gate on crashDir is asked
        -- of a namespace that HAS one.
        check("...and a nil crash source drops the entry rather than "
              .. "building a path from nothing", (function()
            local kept = bk.crashDir
            bk.crashDir = nil
            local out = bk.buildKit()
            bk.crashDir = kept
            for _, e in ipairs(out) do
                if e.id == "crashes" then return false end
            end
            return true
        end)())
        check("...and both reports still print rather than throwing",
              (function()
                  local realp = print
                  print = function() end
                  local ok1 = pcall(function() bk4.report() end)
                  local ok2 = pcall(function() bk4.crashReport() end)
                  print = realp
                  return ok1 and ok2
              end)())
    end

    bk.crashes = false
    RL = {}
    print = function(...) RL[#RL + 1] = table.concat({ ... }, " ") end
    bk.report()
    print = realP
    check("...and switching the whole thing off is said out loud too",
          table.concat(RL, "\n"):find("bk.crashes is false", 1, true) ~= nil,
          table.concat(RL, "\n"))
    bk.crashes = true
end

-- =====================================================================
out("\n=== 🏠 the stores: mirrored half-hourly, seeded once (6.190.0) ===\n")
-- =====================================================================
-- LL: "Would it be better to save everything to my home folder? Then,
-- every 30 minutes write a back up of all the files that have histories
-- or modifications." This is that second half — a separate job from the
-- 5 PM rebuild kit, on its own timer, one rsync, off the main thread.
local SEEDLINES = {}
do
    local before = #TASKS
    local got
    bk.mirrorStores(function(ok, why) got = { ok = ok, why = why } end)
    local t = TASKS[#TASKS]
    check("the mirror is ONE rsync, in a task — never on the main thread",
          #TASKS == before + 1 and t.bin == "/usr/bin/rsync" and t.started)
    check("...HELD on the module, or the collector takes it before it runs",
          bk.mirrorTask == t)
    check("...copying the LOGS folder to the backup",
          t.args[#t.args - 1] == "/logs/" and t.args[#t.args] == TMP .. "/Logs/",
          table.concat({ t.args[#t.args - 1], t.args[#t.args] }, " → "))
    check("🚨 ...with NO --delete — a store that failed to load this "
          .. "session must not be able to erase its own backup",
          (function()
              for _, a in ipairs(t.args) do
                  if tostring(a):find("delete", 1, true) then return false end
              end
              return true
          end)())
    check("🚨 ...and secret.lua is excluded here too — that promise holds "
          .. "on EVERY rsync in this file",
          (function()
              for _, a in ipairs(t.args) do
                  if a == "secret.lua" then return true end
              end
              return false
          end)())
    t.cb(0, "", "")
    check("a clean run is recorded ok", got and got.ok == true and bk.mirrorLast.ok)

    bk.mirrorStores(function(ok, why) got = { ok = ok, why = why } end)
    TASKS[#TASKS].cb(23, "", "rsync: some error")
    check("a FAILED run is recorded, with the reason, not swallowed",
          bk.mirrorLast.ok == false
          and tostring(bk.mirrorLast.why):find("23", 1, true) ~= nil,
          bk.mirrorLast.why)

    -- IT DEGRADES: a Mac with no OneDrive has nowhere to mirror to, and
    -- says so rather than failing silently or throwing.
    local keptDest = bk.mirrorDest
    bk.mirrorDest = nil
    local n = #TASKS
    bk.mirrorStores(function(ok, why) got = { ok = ok, why = why } end)
    check("🚨 no OneDrive → it SAYS so and starts nothing",
          got.ok == false and tostring(got.why):find("OneDrive", 1, true) ~= nil
          and #TASKS == n, got.why)
    check("...and the report names that state rather than going quiet",
          (function()
              local L3, realP = {}, print
              print = function(...) L3[#L3 + 1] = table.concat({ ... }, " ") end
              bk.report()
              print = realP
              return table.concat(L3, "\n"):find("nowhere", 1, true) ~= nil
          end)())
    bk.mirrorDest = keptDest

    -- 🚨 THE SEED, and the rule that makes the local switch safe: it runs
    -- ONLY into an EMPTY folder. Seeding over a local store that already
    -- holds this session's writes would overwrite them with the older
    -- cloud copy — data loss dressed up as a restore.
    _G.localFirstState = "off"
    local n2 = #TASKS
    bk.seedLocalStores(function(ok, why) got = { ok = ok, why = why } end)
    check("with localFirst off there is nothing to seed and nothing runs",
          got.ok == false and #TASKS == n2)

    _G.localFirstState, _G.localLogsDir = "seeding", TMP .. "/LocalLogs"
    DIRLIST[TMP .. "/LocalLogs"] = { "." , "..", "clipboard.json" }   -- NOT empty
    bk.seedLocalStores(function(ok, why) got = { ok = ok, why = why } end)
    check("🚨 a local folder that already has files is NEVER seeded over",
          got.ok == false
          and tostring(got.why):find("not empty", 1, true) ~= nil, got.why)

    DIRLIST[TMP .. "/LocalLogs"] = { ".", ".." }                      -- empty
    SEEDLINES = {}
    local realP2 = print
    print = function(...) SEEDLINES[#SEEDLINES + 1] = table.concat({ ... }, " ") end
    bk.seedLocalStores(function(ok) got = { ok = ok } end)
    local st = TASKS[#TASKS]
    check("an EMPTY local folder is seeded, from OneDrive's Logs",
          st.bin == "/usr/bin/rsync"
          and st.args[#st.args - 1] == CORE.cloudDir .. "/Logs/"
          and st.args[#st.args] == TMP .. "/LocalLogs/",
          table.concat({ st.args[#st.args - 1], st.args[#st.args] }, " → "))
    st.cb(0, "", "")
    print = realP2
    check("🚨 ...and it does NOT switch this session — it says RELOAD, so "
          .. "there is never a moment where a history reads as empty",
          _G.localFirstState == "seeded"
          and table.concat(SEEDLINES, "\n"):find("RELOAD", 1, true) ~= nil)
    _G.localFirstState = nil
end

os.execute("rm -rf '" .. TMP .. "'")

-- =====================================================================
out("\n──\n")
if fail == 0 then
    out(string.format("%d passed, 0 failed\n", pass))
else
    out(string.format("%d passed, %d failed\n", pass, fail))
    for _, f in ipairs(failures) do out("  ❌ " .. f .. "\n") end
    os.exit(1)
end
