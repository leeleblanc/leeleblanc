-- =====================================================================
-- MODULE: SETTINGS PANES (⇪,) — type a few letters, land in the pane
-- =====================================================================
-- LL: "Can you create a tool that lets me search then open macOS
-- settings pane?"
--
-- ⌘, opens preferences in every Mac app ever written. ⇪, is that for the
-- system: press it, type "accessib", press ⏎, and System Settings opens
-- ON Accessibility rather than on whatever it was showing last.
--
--        ⇪,         search every System Settings pane · ⏎ opens it
--
-- 🎯 THE PRIVACY SUB-PANES ARE THE REASON THIS EXISTS. This config tells
-- you to go to "System Settings → Privacy & Security → Accessibility"
-- in nine different alerts, and that trip is: open Settings, scroll a
-- sidebar of thirty rows, find Privacy & Security, scroll ITS list of
-- twenty, click Accessibility. Every one of those destinations has a
-- direct URL, and they are all in the table below — so ⇪, "access" ⏎
-- goes straight there, and the same for Screen Recording, Automation,
-- Input Monitoring and Full Disk Access.
--
-- ---------------------------------------------------------------------
-- 🚨 THESE IDENTIFIERS ARE APPLE'S, AND APPLE MOVES THEM
-- ---------------------------------------------------------------------
-- macOS opens a settings pane through a URL — x-apple.systempreferences:
-- followed by the pane's extension identifier. Ventura rewrote System
-- Settings from scratch and renamed nearly every one of them
-- (com.apple.preference.sound became com.apple.Sound-Settings.extension),
-- and Apple has moved several again since.
--
-- ⚠️ AND AN UNKNOWN IDENTIFIER FAILS SILENTLY. macOS does not refuse a
-- URL whose anchor it no longer recognises: System Settings opens, at
-- whatever page it feels like, and `open` still exits 0. So there is no
-- honest way for this module to verify a destination — it can only report
-- that it asked. That is why:
--
--   · the LEGACY anchors are kept alongside the modern ones. The old
--     com.apple.preference.security?Privacy_Accessibility form still
--     works on Ventura through today's builds, and is more stable across
--     releases than the new extension names.
--   · sp.probe() exists. It opens each entry in turn with a pause between
--     so you can watch what actually lands, which is the only test that
--     tells the truth about somebody else's URL scheme.
--   · anything that turns out to be wrong is ONE LINE to fix, in the
--     table below, and the fix does not need a new version of anything.
--
-- ---------------------------------------------------------------------
-- 📂 THE .prefPane SCAN IS A SUPPLEMENT, NOT THE SOURCE
-- ---------------------------------------------------------------------
-- Pre-Ventura, every pane was a bundle in /System/Library/PreferencePanes
-- and listing that folder WAS the answer. On a modern Mac that folder is
-- nearly empty — the panes moved inside System Settings — so the scan
-- finds third-party panes and legacy leftovers and little else. It runs
-- anyway, because a Mac with an old pane installed (a VPN client, a
-- driver) should still find it here, and it is additive: a scanned pane
-- never replaces a curated row.
-- =====================================================================

local M = {
    name  = "Settings Panes",
    order = 13.96,
    family = "config",
    cheatsheet = {
        title = "⚙️ SETTINGS PANES (⇪, — System Settings, by name)",
        entries = {
            { "⇪,",      "Search every System Settings pane — ⏎ opens it there" },
            { "privacy", "Accessibility · Screen Recording · Automation · Input" },
            { "",        "Monitoring · Full Disk Access — each one direct, no scrolling" },
            { "note",    "Apple renames these identifiers between releases —" },
            { "",        "_G.settingsProbe() opens each in turn so you can see" },
            { "check",   "_G.settingsReport() — how many panes, and where from" },
        },
    },
}

function M.setup(core)
    local sp = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    sp.enabled   = true
    sp.key       = ","          -- ⇪,  (⌘, is preferences everywhere else)
    sp.keyMods   = {}
    sp.probeGap  = 2.5          -- seconds between panes when probing
    sp.scanDirs  = {
        "/System/Library/PreferencePanes",
        "/Library/PreferencePanes",
    }
    -- ~/Library/PreferencePanes is added at setup, once the home directory
    -- is known — it is per-user and cannot be a constant here.
    -- ----------------------------------------------------------------------

    -- ---- the table -------------------------------------------------------
    -- { name, identifier-or-url, group }
    -- A value with no scheme is an extension identifier and gets the
    -- x-apple.systempreferences: prefix. A value that ALREADY carries a
    -- scheme is used as written, so a future row can point somewhere else
    -- entirely (an https: help page, say) without a second code path.
    --
    -- ⚠️ NOTE WHICH SIDE THE LEGACY ANCHORS FALL ON: they are identifiers
    -- WITH a query, not URLs — "com.apple.preference.security?Privacy_X"
    -- has no colon in it — so they take the prefix like everything else.
    -- The finished URL is x-apple.systempreferences:com.apple.preference
    -- .security?Privacy_X, which is the form that actually works. Reading
    -- the "?" as a scheme marker would leave them unprefixed and dead.
    sp.panes = {
        -- ---- the ones this config sends you to ----
        { "Accessibility (privacy)",  "com.apple.preference.security?Privacy_Accessibility",  "Privacy & Security" },
        { "Screen Recording",         "com.apple.preference.security?Privacy_ScreenCapture",  "Privacy & Security" },
        { "Automation",               "com.apple.preference.security?Privacy_Automation",     "Privacy & Security" },
        { "Input Monitoring",         "com.apple.preference.security?Privacy_ListenEvent",    "Privacy & Security" },
        { "Full Disk Access",         "com.apple.preference.security?Privacy_AllFiles",       "Privacy & Security" },
        { "Files and Folders",        "com.apple.preference.security?Privacy_FilesAndFolders","Privacy & Security" },
        { "Developer Tools",          "com.apple.preference.security?Privacy_DevTools",       "Privacy & Security" },
        { "Camera",                   "com.apple.preference.security?Privacy_Camera",         "Privacy & Security" },
        { "Microphone",               "com.apple.preference.security?Privacy_Microphone",     "Privacy & Security" },
        { "Location Services",        "com.apple.preference.security?Privacy_LocationServices","Privacy & Security" },
        { "Contacts (privacy)",       "com.apple.preference.security?Privacy_Contacts",       "Privacy & Security" },
        { "Calendars (privacy)",      "com.apple.preference.security?Privacy_Calendars",      "Privacy & Security" },
        { "Reminders (privacy)",      "com.apple.preference.security?Privacy_Reminders",      "Privacy & Security" },
        { "Photos (privacy)",         "com.apple.preference.security?Privacy_Photos",         "Privacy & Security" },
        { "Privacy & Security",       "com.apple.settings.PrivacySecurity.extension",         "Privacy & Security" },
        { "FileVault",                "com.apple.settings.PrivacySecurity.extension?FileVault","Privacy & Security" },
        -- ---- network & sharing ----
        { "Wi-Fi",                    "com.apple.wifi-settings-extension",                    "Network" },
        { "Bluetooth",                "com.apple.BluetoothSettings",                          "Network" },
        { "Network",                  "com.apple.Network-Settings.extension",                 "Network" },
        { "VPN",                      "com.apple.Network-Settings.extension?VPN",             "Network" },
        { "Sharing",                  "com.apple.Sharing-Settings.extension",                 "Network" },
        { "Internet Accounts",        "com.apple.Internet-Accounts-Settings.extension",       "Network" },
        -- ---- hardware ----
        { "Displays",                 "com.apple.Displays-Settings.extension",                "Hardware" },
        { "Sound",                    "com.apple.Sound-Settings.extension",                   "Hardware" },
        { "Keyboard",                 "com.apple.Keyboard-Settings.extension",                "Hardware" },
        { "Keyboard Shortcuts",       "com.apple.Keyboard-Settings.extension?Shortcuts",      "Hardware" },
        { "Text Replacement",         "com.apple.Keyboard-Settings.extension?Text",           "Hardware" },
        { "Mouse",                    "com.apple.Mouse-Settings.extension",                   "Hardware" },
        { "Trackpad",                 "com.apple.Trackpad-Settings.extension",                "Hardware" },
        { "Printers & Scanners",      "com.apple.Print-Scan-Settings.extension",              "Hardware" },
        { "Battery",                  "com.apple.Battery-Settings.extension",                 "Hardware" },
        { "Startup Disk",             "com.apple.Startup-Disk-Settings.extension",            "Hardware" },
        -- ---- appearance & desktop ----
        { "Appearance",               "com.apple.Appearance-Settings.extension",              "Desktop" },
        { "Desktop & Dock",           "com.apple.Desktop-Settings.extension",                 "Desktop" },
        { "Wallpaper",                "com.apple.Wallpaper-Settings.extension",               "Desktop" },
        { "Screen Saver",             "com.apple.ScreenSaver-Settings.extension",             "Desktop" },
        { "Lock Screen",              "com.apple.Lock-Screen-Settings.extension",             "Desktop" },
        { "Control Center",           "com.apple.ControlCenter-Settings.extension",           "Desktop" },
        { "Menu Bar",                 "com.apple.ControlCenter-Settings.extension?MenuBar",   "Desktop" },
        { "Notifications",            "com.apple.Notifications-Settings.extension",           "Desktop" },
        { "Focus",                    "com.apple.Focus-Settings.extension",                   "Desktop" },
        { "Accessibility",            "com.apple.Accessibility-Settings.extension",           "Desktop" },
        -- ---- account & system ----
        { "General",                  "com.apple.systempreferences.GeneralSettings",          "System" },
        { "Software Update",          "com.apple.Software-Update-Settings.extension",         "System" },
        { "Storage",                  "com.apple.settings.Storage",                           "System" },
        { "Login Items",              "com.apple.LoginItems-Settings.extension",              "System" },
        { "Users & Groups",           "com.apple.Users-Groups-Settings.extension",            "System" },
        { "Passwords",                "com.apple.Passwords-Settings.extension",               "System" },
        { "Touch ID & Password",      "com.apple.Touch-ID-Settings.extension",                "System" },
        { "Apple Account",            "com.apple.systempreferences.AppleIDSettings",          "System" },
        { "Family",                   "com.apple.Family-Settings.extension",                  "System" },
        { "Screen Time",              "com.apple.Screen-Time-Settings.extension",             "System" },
        { "Siri",                     "com.apple.Siri-Settings.extension",                    "System" },
        { "Date & Time",              "com.apple.Date-Time-Settings.extension",               "System" },
        { "Language & Region",        "com.apple.Localization-Settings.extension",            "System" },
        { "Time Machine",             "com.apple.Time-Machine-Settings.extension",            "System" },
        { "Transfer or Reset",        "com.apple.Transfer-Reset-Settings.extension",          "System" },
        { "Wallet & Apple Pay",       "com.apple.WalletSettingsExtension",                    "System" },
        { "Game Center",              "com.apple.Game-Center-Settings.extension",             "System" },
    }

    sp.rows    = {}      -- index -> { name, url, group, from }
    sp.scanned = 0
    sp.opens   = 0
    sp.lastOpened, sp.lastURL, sp.lastNote = nil, nil, nil
    sp.chooser = nil     -- HELD: an unreferenced hs.chooser is collected
    sp.probeTimer = nil  -- HELD: ditto an hs.timer

    local function say(m)  if _G.diag then _G.diag.say("settings", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("settings", m) end end

    if core.homeDir and core.homeDir ~= "" then
        sp.scanDirs[#sp.scanDirs + 1] = core.homeDir .. "/Library/PreferencePanes"
    end

    -- A value with no colon is an extension identifier; one with a colon is
    -- already a URL. Keeping both shapes in one table is what lets the
    -- legacy ?Privacy_ anchors sit beside the modern names — see the header.
    function sp.urlFor(value)
        local v = tostring(value or "")
        if v == "" then return nil end
        if v:find("^%a[%w%+%-%.]*:") then return v end
        return "x-apple.systempreferences:" .. v
    end

    -- ---- the .prefPane scan ----------------------------------------------
    -- Additive only: a pane found on disk is skipped if a curated row
    -- already carries that name, so the table always wins on wording.
    function sp.scan()
        local found, seen = {}, {}
        for _, r in ipairs(sp.panes) do seen[r[1]:lower()] = true end
        for _, dir in ipairs(sp.scanDirs) do
            local okDir = hs.fs.attributes(dir, "mode") == "directory"
            if okDir then
                -- 🚨 BOTH RETURN VALUES. hs.fs.dir hands back
                -- (iterator, directoryObject) and the iterator is useless
                -- without the second one: `for e in iter do` throws
                -- "directory metatable expected, got nil" at RUNTIME, never
                -- at load, so the scan would be silently dead and nothing
                -- would say so. hs-lint caught this one before it shipped.
                --
                -- ⚠️ AND THE WALK IS pcall'd, not just the dir() call. A
                -- throw anywhere in the loop — a permission that changed
                -- under us, a directory that vanished mid-iteration —
                -- would otherwise escape sp.scan, then sp.build, then
                -- sp.show, and ⇪, would do nothing at all. One unreadable
                -- directory must cost that directory, not the picker.
                local ok, iter, dirObj = pcall(hs.fs.dir, dir)
                if ok and iter then
                    local okWalk, why = pcall(function()
                        for entry in iter, dirObj do
                            local base = entry:match("^(.+)%.prefPane$")
                            if base and not seen[base:lower()] then
                                seen[base:lower()] = true
                                found[#found + 1] = {
                                    name  = base,
                                    url   = dir .. "/" .. entry,
                                    group = "Installed pane",
                                    from  = "disk",
                                }
                            end
                        end
                    end)
                    if not okWalk then
                        warn("could not read " .. dir .. ": " .. tostring(why))
                    end
                end
            end
        end
        return found
    end

    function sp.build()
        local rows = {}
        for _, r in ipairs(sp.panes) do
            rows[#rows + 1] = { name = r[1], url = sp.urlFor(r[2]),
                                group = r[3], from = "table" }
        end
        local scanned = sp.scan()
        sp.scanned = #scanned
        for _, r in ipairs(scanned) do rows[#rows + 1] = r end
        sp.rows = rows
        return rows
    end

    -- ---- opening ---------------------------------------------------------
    -- A .prefPane on disk is a FILE, not a URL: `open` on the bundle is
    -- what launches it, and that path is why sp.open branches rather than
    -- handing everything to hs.urlevent.
    function sp.open(row)
        if not row or not row.url then return false end
        local ok
        if row.from == "disk" then
            ok = pcall(function() hs.execute("/usr/bin/open " ..
                                             ("%q"):format(row.url)) end)
        else
            ok = pcall(function() hs.urlevent.openURL(row.url) end)
            if not ok then
                ok = pcall(function() hs.execute("/usr/bin/open " ..
                                                 ("%q"):format(row.url)) end)
            end
        end
        if ok then
            sp.opens      = sp.opens + 1
            sp.lastOpened = row.name
            sp.lastURL    = row.url
            say("opened " .. row.name)
            return true
        end
        sp.lastNote = "could not open " .. row.name
        warn(sp.lastNote)
        hs.alert.show("⚙️ Could not open " .. row.name, 3)
        return false
    end

    -- ---- the picker ------------------------------------------------------
    -- ⚠️ The row carries an INTEGER, not the pane table. Every value in a
    -- chooser row crosses into Objective-C and a nested table does not
    -- survive it — LuaSkin discards the whole list and logs, so the panel
    -- would open empty with nothing thrown. Same rule as ⇪⇧T's snippets.
    function sp.choices()
        local rows, out = sp.build(), {}
        for i, r in ipairs(rows) do
            out[#out + 1] = {
                text    = r.name,
                subText = r.group .. (r.from == "disk"
                          and "   ·   installed pane on disk" or ""),
                idx     = i,
            }
        end
        return out
    end

    function sp.show()
        if not sp.enabled then return end
        local choices = sp.choices()
        if not sp.chooser then
            sp.chooser = hs.chooser.new(function(pick)
                if not pick then return end
                sp.open(sp.rows[pick.idx])
            end)
            -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.settingsPanes = sp.chooser
            pcall(function()
                sp.chooser:searchSubText(true)
                sp.chooser:width(32)
            end)
        end
        sp.chooser:choices(choices)
        sp.chooser:placeholderText(#choices ..
            " settings panes — type to filter, ⏎ opens it there")
        sp.chooser:query("")
        sp.chooser:show()
    end

    -- ---- the probe -------------------------------------------------------
    -- The ONLY honest test of somebody else's URL scheme: open them one at
    -- a time, slowly enough to watch, and write down which ones landed
    -- somewhere other than where they said. `open` exits 0 for an anchor
    -- macOS no longer knows, so no amount of return-code checking can do
    -- this for you — see the header.
    function _G.settingsProbe(group)
        local rows, list = sp.build(), {}
        for _, r in ipairs(rows) do
            if r.from == "table" and (not group or r.group == group) then
                list[#list + 1] = r
            end
        end
        if #list == 0 then
            print("⚙️ settingsProbe: nothing matched group " .. tostring(group))
            return
        end
        print(("⚙️ settingsProbe: opening %d panes, %.1fs apart. Watch what "
               .. "lands — an identifier Apple has retired opens System "
               .. "Settings at the wrong page WITHOUT failing.")
              :format(#list, sp.probeGap))
        local i = 0
        local function step()
            i = i + 1
            local r = list[i]
            if not r then
                sp.probeTimer = nil
                print("⚙️ settingsProbe: done — " .. #list .. " opened")
                return
            end
            print(("   %2d/%d  %-26s %s"):format(i, #list, r.name, r.url))
            sp.open(r)
            sp.probeTimer = hs.timer.doAfter(sp.probeGap, step)
        end
        step()
    end

    function _G.settingsReport()
        local rows = sp.build()
        local L = { "⚙️ SETTINGS PANES" }
        L[#L + 1] = "   listed      : " .. #rows .. " panes"
        L[#L + 1] = "   curated     : " .. #sp.panes .. " in the table"
        L[#L + 1] = "   found       : " .. sp.scanned .. " .prefPane bundles on disk"
        L[#L + 1] = "   opened      : " .. sp.opens .. " this session"
        if sp.lastOpened then
            L[#L + 1] = "   last        : " .. sp.lastOpened
            L[#L + 1] = "   last url    : " .. tostring(sp.lastURL)
        else
            L[#L + 1] = "   last        : never — ⇪, has not been used"
        end
        if sp.lastNote then L[#L + 1] = "   last problem: " .. sp.lastNote end
        L[#L + 1] = "   ⚠️ an identifier Apple retired opens Settings at the"
        L[#L + 1] = "      wrong page and still exits 0 — run _G.settingsProbe()"
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if sp.enabled then
        core.hyperAddShortcut(sp.keyMods, sp.key, function() sp.show() end,
                              "settings panes")
    end
    core.provide("settings.show",   function() return sp.show() end)
    core.provide("settings.open",   function(name)
        for _, r in ipairs(sp.build()) do
            if r.name:lower() == tostring(name):lower() then return sp.open(r) end
        end
        return false
    end)
    core.provide("settings.report", function() return _G.settingsReport() end)

    _G.settingsPanes = sp
    M.sp     = sp
    M.config = sp
end

return M
