-- =====================================================================
-- MODULE: DAILY BACKUP (was §1.7) — ~/.hammerspoon → OneDrive (secret.lua excluded)
-- =====================================================================
-- Once a day (time below), copies your ~/.hammerspoon folder into
-- OneDrive, so a dead Mac or a bad edit never costs you this setup.
-- 6.10.0: your DATA files don't live in ~/.hammerspoon anymore (they're
-- in the OneDrive Logs folder directly), so this backup now mainly
-- protects init.lua itself — and secret.lua is EXCLUDED from the copy:
-- the Asana token stays on this Mac only, never in the cloud, even
-- your own OneDrive. (Losing secret.lua just means minting a fresh
-- token at app.asana.com/0/my-apps — 30 seconds, zero risk.)
-- Uses rsync, so unchanged files aren't recopied; nothing is ever
-- deleted from the backup, only added/updated. OneDrive's own version
-- history gives you point-in-time copies on top of this.
-- Quiet on success (a line in the Hammerspoon Console); an on-screen
-- alert appears only if the backup FAILS (e.g. OneDrive unavailable).
-- Same wake-time caveat as the reports: if the Mac is asleep at backup
-- time, that day's run is skipped, not run late.
-- Runs only when a cloud-synced destination exists (see §0.1): no
-- OneDrive on this Mac → no backup timer, with a console note instead.

-- Moved out of init.lua in 6.36.0. Nothing about the behaviour changed;
-- it reads its paths from `core` instead of from init.lua's locals,
-- which is the whole difference between a section and a module.
local M = {
    name  = "Daily Backup",
    order = 15,                    -- slot in the cheat sheet
    cheatsheet = {
        title = "☁️ BACKUP (automatic)",
        entries = {
            { "daily 5:00 PM", "~/.hammerspoon → OneDrive/Backups (token excluded)" },
        },
    },
}

function M.setup(core)
    local backupTime = "17:00"  -- 5:00 PM daily, 24h format

    if core.backupDir then
        local function runHammerspoonBackup()
            local src = core.configDir
            -- applock.json was the App Lock PIN hash. App Lock was removed
            -- in 6.35.0; the exclusion stays so a leftover file from an
            -- older version still never reaches the backup. It is
            -- excluded for the same reason secret.lua is: per-machine only,
            -- never synced to the cloud, never in a backup.
            local cmd = "mkdir -p '" .. core.backupDir .. "' && /usr/bin/rsync -a "
                .. "--exclude 'secret.lua' --exclude 'applock.json' '"
                .. src .. "/' '" .. core.backupDir .. "/'"
            hs.task.new("/bin/zsh", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    print("☁️ Hammerspoon backup completed → " .. core.backupDir .. " (secret.lua + applock.json excluded)")
                else
                    hs.alert.show("⚠️ Hammerspoon backup FAILED — is OneDrive available?", 5)
                    print("🚨 Backup error: " .. tostring(stdErr))
                end
            end, { "-c", cmd }):start()
        end

        _G.backupTimer = hs.timer.doAt(backupTime, "1d", runHammerspoonBackup)
    else
        print("ℹ️ No OneDrive on this Mac — daily backup disabled; data stays in " .. core.configDir .. " and " .. core.logsDir)
    end
end

return M
