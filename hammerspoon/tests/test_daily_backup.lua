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
