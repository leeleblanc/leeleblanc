-- =====================================================================
-- MODULE: SETTINGS SEARCH (⇪,) — type a setting, land where it lives
-- =====================================================================
-- LL: "Can you create a tool that lets me search then open macOS
-- settings pane?"
--
-- ⌘, opens preferences in every Mac app ever written. ⇪, is that for the
-- system: press it, type "accessib", press ⏎, and System Settings opens
-- ON Accessibility rather than on whatever it was showing last.
--
--        ⇪,         search every pane AND the settings inside them
--        ⏎          open the pane that holds it — the row says where
--        last row   🔎 hand your words to System Settings' own search
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
-- 🔎 "SEARCH ALL SETTINGS" — WHAT THAT ACTUALLY TAKES (6.122.0)
-- ---------------------------------------------------------------------
-- LL: "What does this mean? I wanted to be able to search all Settings
-- app."
--
-- A fair complaint about 6.119.0. What shipped searched the ~58 PANES —
-- the destinations in the sidebar. It could find "Displays"; it could not
-- find "Night Shift", which is a switch INSIDE Displays. Nobody thinks
-- "I need the Displays pane"; they think "where is Night Shift".
--
-- There is no list of every setting macOS has that this config can read.
-- Apple does not publish one, the panes are SwiftUI views rather than
-- files on disk, and the index behind System Settings' own search box is
-- private. So the answer is two answers, and it is worth being clear
-- about which is which:
--
--   1. sp.terms — A HAND-WRITTEN INDEX, and therefore exactly as complete
--      as somebody made it. Roughly 190 of the settings people actually
--      hunt for, each pointing at the pane that holds it and saying where
--      in that pane to look. Typing "night shift" lands you in Displays
--      with a note telling you it is bottom-right. This is the fast half:
--      one keystroke and you are THERE.
--
--   2. sp.askApple — THE COMPLETE HALF, and it is not mine. Whatever you
--      typed can be handed to System Settings' own search field, which
--      indexes every setting Apple ships and is updated by the same
--      people who move them. Slower — it lands you in Settings looking at
--      a result list — but it cannot be out of date and it cannot be
--      missing an entry.
--
-- The last row of the picker is always "🔎 Search System Settings for
-- …", so the hand-written index is never a ceiling. When it does not
-- know a term, Apple's does, and it is one more ⏎ away.
--
-- 🚨 THE HAND-OFF TYPES; IT DOES NOT POKE A VALUE IN. Setting AXValue on
-- a SwiftUI search field frequently updates the text and runs no search —
-- the field's binding never fires. So the field is FOCUSED and then the
-- characters are typed, which is indistinguishable from you typing them.
-- That means real synthetic keystrokes, so it goes through
-- _G.withInjection like every other typing tool here: autocorrect, the
-- expander and the Key Caster must not treat this config's own typing as
-- yours.
--
-- ⏳ AND IT POLLS RATHER THAN SLEEPING A FIXED TIME. System Settings can
-- take a moment or an age to draw its window depending on what it decides
-- to load. A fixed delay is either too short on a cold launch or wasted
-- on a warm one, so this looks for the field every sp.appleTick until
-- sp.appleTimeout, then says plainly that it could not find it — rather
-- than typing the query into whatever happened to have focus.
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
        title = "⚙️ SETTINGS SEARCH (⇪, — panes AND the settings inside them)",
        entries = {
            { "⇪,",      "Type any setting — “night shift”, “hot corners”, “vpn”" },
            { "⏎",       "Opens the pane that holds it, and says where to look" },
            { "last row","🔎 hands your words to System Settings' OWN search —" },
            { "",        "Apple's index, so it knows what this one does not" },
            { "privacy", "Accessibility · Screen Recording · Automation · Input" },
            { "",        "Monitoring · Full Disk Access — each one direct, no scrolling" },
            { "note",    "Apple renames these identifiers between releases —" },
            { "",        "_G.settingsProbe() opens each in turn so you can see" },
            { "check",   "_G.settingsReport() — panes, terms, and where from" },
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

    -- ---- the settings INSIDE the panes -----------------------------------
    -- { what you would type, which pane holds it, where in that pane }
    --
    -- 🚨 THE SECOND FIELD IS A PANE NAME FROM THE TABLE ABOVE, matched
    -- exactly. A term pointing at a pane that does not exist is a dead row
    -- that would look fine in the picker and do nothing on ⏎, so
    -- sp.build() drops it and _G.settingsReport() counts what it dropped —
    -- and the test suite fails outright on the first orphan.
    --
    -- ⚠️ THE THIRD FIELD IS A HINT, NOT A PROMISE. macOS moves controls
    -- between releases far more often than it moves whole panes. A hint
    -- that has gone stale costs you two seconds of looking; the pane it
    -- sent you to is still the right pane. Anything here is one line to
    -- fix and needs no new version of anything.
    sp.terms = {
        -- ---- Displays ----
        { "Night Shift",              "Displays",            "bottom right — Night Shift…" },
        { "True Tone",                "Displays",            "the checkbox under the resolution row" },
        { "resolution",               "Displays",            "the row of scaled sizes" },
        { "scaled resolution",        "Displays",            "More Space / Larger Text" },
        { "refresh rate",             "Displays",            "under the resolution row" },
        { "colour profile",           "Displays",            "Color Profile pop-up" },
        { "color profile",            "Displays",            "Color Profile pop-up" },
        { "arrange displays",         "Displays",            "the Arrange… button, with two screens attached" },
        { "mirror displays",          "Displays",            "Use as: Mirror, per display" },
        { "second monitor",           "Displays",            "each screen gets its own tab" },
        { "brightness",               "Displays",            "the top slider" },
        { "auto brightness",          "Displays",            "Automatically adjust brightness" },
        -- ---- Desktop & Dock ----
        { "hot corners",              "Desktop & Dock",      "the very bottom — Hot Corners…" },
        { "dock size",                "Desktop & Dock",      "the first slider" },
        { "dock magnification",       "Desktop & Dock",      "Magnification, under Size" },
        { "dock position",            "Desktop & Dock",      "Position on screen" },
        { "hide the dock",            "Desktop & Dock",      "Automatically hide and show the Dock" },
        { "minimise to icon",         "Desktop & Dock",      "Minimize windows into application icon" },
        { "recent applications",      "Desktop & Dock",      "Show suggested and recent apps in Dock" },
        { "mission control",          "Desktop & Dock",      "the Mission Control section, halfway down" },
        { "spaces",                   "Desktop & Dock",      "Mission Control section — rearrange Spaces" },
        { "displays have separate spaces", "Desktop & Dock", "Mission Control section" },
        { "stage manager",            "Desktop & Dock",      "the Stage Manager section" },
        { "tiled windows",            "Desktop & Dock",      "Windows section — drag to screen edge" },
        { "default web browser",      "Desktop & Dock",      "Windows & Apps → Default web browser" },
        { "click wallpaper to reveal desktop", "Desktop & Dock", "Desktop & Stage Manager section" },
        -- ---- Keyboard ----
        { "key repeat",               "Keyboard",            "the top two sliders" },
        { "delay until repeat",       "Keyboard",            "the second slider" },
        { "caps lock",                "Keyboard",            "Keyboard Shortcuts… → Modifier Keys" },
        { "modifier keys",            "Keyboard",            "Keyboard Shortcuts… → Modifier Keys" },
        { "function keys",            "Keyboard",            "Keyboard Shortcuts… → Function Keys" },
        { "fn key",                   "Keyboard",            "Press 🌐 key to: pop-up" },
        { "globe key",                "Keyboard",            "Press 🌐 key to: pop-up" },
        { "keyboard brightness",      "Keyboard",            "the backlight rows, on a laptop" },
        { "dictation",                "Keyboard",            "the Dictation section at the bottom" },
        { "input sources",            "Keyboard",            "Text Input → Input Sources Edit…" },
        { "emoji picker",             "Keyboard",            "Press 🌐 key to: → Show Emoji" },
        { "text replacement",         "Text Replacement",    "the list is the whole pane" },
        { "autocorrect",              "Text Replacement",    "Text Input → Input Sources → Edit…" },
        { "spelling",                 "Text Replacement",    "Text Input → Input Sources → Edit…" },
        { "smart quotes",             "Text Replacement",    "Text Input → Input Sources → Edit…" },
        { "capitalise words automatically", "Text Replacement", "Input Sources → Edit…" },
        { "keyboard shortcuts",       "Keyboard Shortcuts",  "the sidebar splits them by kind" },
        { "app shortcuts",            "Keyboard Shortcuts",  "App Shortcuts, at the bottom of the list" },
        { "spotlight shortcut",       "Keyboard Shortcuts",  "Spotlight, in the list" },
        { "screenshot shortcuts",     "Keyboard Shortcuts",  "Screenshots, in the list" },
        { "mission control shortcuts","Keyboard Shortcuts",  "Mission Control, in the list" },
        -- ---- Trackpad & Mouse ----
        { "tap to click",             "Trackpad",            "Point & Click tab" },
        { "tracking speed",           "Trackpad",            "Point & Click tab, the top slider" },
        { "natural scrolling",        "Trackpad",            "Scroll & Zoom tab — Natural scrolling" },
        { "scroll direction",         "Trackpad",            "Scroll & Zoom tab" },
        { "three finger drag",        "Trackpad",            "NOT here — Accessibility → Pointer Control" },
        { "swipe between pages",      "Trackpad",            "More Gestures tab" },
        { "swipe between apps",       "Trackpad",            "More Gestures tab" },
        { "app exposé",               "Trackpad",            "More Gestures tab" },
        { "force click",              "Trackpad",            "Point & Click tab" },
        { "secondary click",          "Trackpad",            "Point & Click tab" },
        { "right click",              "Trackpad",            "Point & Click → Secondary click" },
        { "mouse speed",              "Mouse",               "Tracking speed slider" },
        { "mouse scroll direction",   "Mouse",               "Natural scrolling checkbox" },
        -- ---- Sound ----
        { "output device",            "Sound",               "Output tab" },
        { "input device",             "Sound",               "Input tab" },
        { "microphone level",         "Sound",               "Input tab — Input volume" },
        { "alert volume",             "Sound",               "Sound Effects section" },
        { "alert sound",              "Sound",               "Sound Effects section" },
        { "startup sound",            "Sound",               "Play sound on startup" },
        { "volume in menu bar",       "Sound",               "Show Sound in Menu Bar" },
        { "balance",                  "Sound",               "Output tab, under the device list" },
        -- ---- Network & sharing ----
        { "known networks",           "Wi-Fi",               "the Details… button beside a network" },
        { "forget this network",      "Wi-Fi",               "… beside the network → Forget" },
        { "wifi password",            "Wi-Fi",               "… beside the network → Copy Password" },
        { "hotspot",                  "Wi-Fi",               "Personal Hotspot section" },
        { "personal hotspot",         "Wi-Fi",               "under the network list" },
        { "dns",                      "Network",             "the service → Details… → DNS" },
        { "proxies",                  "Network",             "the service → Details… → Proxies" },
        { "ip address",               "Network",             "the service → Details… → TCP/IP" },
        { "firewall",                 "Network",             "the Firewall row at the bottom" },
        { "vpn configuration",        "VPN",                 "the whole pane" },
        { "screen sharing",           "Sharing",             "the first row" },
        { "remote login",             "Sharing",             "ssh — the Remote Login row" },
        { "ssh",                      "Sharing",             "Remote Login" },
        { "file sharing",             "Sharing",             "the File Sharing row" },
        { "airdrop",                  "Sharing",             "AirDrop & Handoff, near the bottom" },
        { "handoff",                  "Sharing",             "AirDrop & Handoff" },
        { "airplay receiver",         "Sharing",             "AirPlay Receiver row" },
        { "computer name",            "Sharing",             "the very top of the pane" },
        { "printer sharing",          "Sharing",             "the Printer Sharing row" },
        { "bluetooth device",         "Bluetooth",           "the device list" },
        -- ---- Privacy & Security ----
        { "allow apps from",          "Privacy & Security",  "Security section, near the bottom" },
        { "gatekeeper",               "Privacy & Security",  "Allow applications from…" },
        { "open anyway",              "Privacy & Security",  "Security section, after a blocked launch" },
        { "filevault",                "FileVault",           "the whole pane" },
        { "disk encryption",          "FileVault",           "the whole pane" },
        { "lockdown mode",            "Privacy & Security",  "the very bottom" },
        { "analytics",                "Privacy & Security",  "Analytics & Improvements" },
        { "advertising",              "Privacy & Security",  "Apple Advertising" },
        { "local network",            "Privacy & Security",  "the Local Network row in the list" },
        { "bluetooth permission",     "Privacy & Security",  "the Bluetooth row in the list" },
        -- ---- Accessibility ----
        { "zoom the screen",          "Accessibility",       "Vision → Zoom" },
        { "increase contrast",        "Accessibility",       "Display, under Vision" },
        { "reduce motion",            "Accessibility",       "Display, under Vision" },
        { "reduce transparency",      "Accessibility",       "Display, under Vision" },
        { "pointer size",             "Accessibility",       "Display → Pointer" },
        { "shake to find pointer",    "Accessibility",       "Display → Pointer" },
        { "voiceover",                "Accessibility",       "Vision → VoiceOver" },
        { "spoken content",           "Accessibility",       "Vision → Spoken Content" },
        { "speak selection",          "Accessibility",       "Spoken Content → Speak Selection" },
        { "sticky keys",              "Accessibility",       "Motor → Keyboard" },
        { "slow keys",                "Accessibility",       "Motor → Keyboard" },
        { "mouse keys",               "Accessibility",       "Motor → Pointer Control" },
        { "three finger drag setting","Accessibility",       "Motor → Pointer Control → Trackpad Options" },
        { "dwell control",            "Accessibility",       "Motor → Pointer Control" },
        { "live captions",            "Accessibility",       "Hearing → Live Captions" },
        { "mono audio",               "Accessibility",       "Hearing → Audio" },
        { "flash the screen",         "Accessibility",       "Hearing → Audio" },
        -- ---- Notifications, Focus, Control Centre ----
        { "do not disturb",           "Focus",               "the Do Not Disturb focus" },
        { "focus schedule",           "Focus",               "open a focus → Set a Schedule" },
        { "share focus status",       "Focus",               "Focus Status, at the bottom" },
        { "notification preview",     "Notifications",       "Show previews, at the top" },
        { "allow notifications when locked", "Notifications","the three checkboxes at the top" },
        { "per app notifications",    "Notifications",       "the app list below the top section" },
        { "menu bar items",           "Control Center",      "the Menu Bar Only section" },
        { "clock options",            "Control Center",      "Menu Bar Only → Clock Options…" },
        { "show seconds",            "Control Center",       "Clock Options… → Display the time with seconds" },
        { "battery percentage",       "Control Center",      "Battery → Show Percentage" },
        { "spotlight icon",           "Control Center",      "Menu Bar Only → Spotlight" },
        { "auto hide menu bar",       "Control Center",      "Automatically hide and show the menu bar" },
        -- ---- General & system ----
        { "software update",          "Software Update",     "the whole pane" },
        { "automatic updates",        "Software Update",     "the ⓘ beside Automatic Updates" },
        { "airdrop and handoff",      "Sharing",             "AirDrop & Handoff" },
        { "storage",                  "Storage",             "the whole pane" },
        { "other volumes",            "Storage",             "the ⓘ rows under the bar" },
        { "login items",              "Login Items",         "Open at Login, at the top" },
        { "allow in the background",  "Login Items",         "the second list — background permissions" },
        { "startup disk",             "Startup Disk",        "the whole pane" },
        { "time zone",                "Date & Time",         "the second half of the pane" },
        { "24 hour time",             "Date & Time",         "the 24-hour time checkbox" },
        { "set date automatically",   "Date & Time",         "the top row" },
        { "first day of week",        "Language & Region",   "under the region list" },
        { "date format",              "Language & Region",   "Date format, near the bottom" },
        { "measurement units",        "Language & Region",   "Measurement system" },
        { "temperature unit",         "Language & Region",   "under Measurement system" },
        { "add a language",           "Language & Region",   "Preferred Languages, the + button" },
        { "time machine backup",      "Time Machine",        "the whole pane" },
        { "add backup disk",          "Time Machine",        "the + button" },
        { "airplay to mac",           "Sharing",             "AirPlay Receiver" },
        { "screen time limits",       "Screen Time",         "App Limits" },
        { "downtime",                 "Screen Time",         "the Downtime row" },
        { "erase all content",        "Transfer or Reset",   "Erase All Content and Settings" },
        { "migration assistant",      "Transfer or Reset",   "the Transfer button" },
        { "apple id",                 "Apple Account",       "the whole pane" },
        { "icloud",                   "Apple Account",       "iCloud, in the account pane" },
        { "icloud drive",             "Apple Account",       "iCloud → iCloud Drive" },
        { "sign out",                 "Apple Account",       "the very bottom of the account pane" },
        { "family sharing",           "Family",              "the whole pane" },
        { "passwords",                "Passwords",           "the whole pane" },
        { "verification codes",       "Passwords",           "open an entry → Set Up Verification Code" },
        { "touch id",                 "Touch ID & Password", "the whole pane" },
        { "change password",          "Touch ID & Password", "the Change… button" },
        { "auto login",               "Users & Groups",      "Automatically log in as…" },
        { "guest user",               "Users & Groups",      "the Guest User row" },
        { "add a user",               "Users & Groups",      "the Add Account… button" },
        { "login window",             "Users & Groups",      "the Network Account Server / login options" },
        -- ---- Appearance, wallpaper, lock screen ----
        { "dark mode",                "Appearance",          "the top row" },
        { "accent colour",            "Appearance",          "Accent color" },
        { "accent color",             "Appearance",          "the second row" },
        { "highlight colour",         "Appearance",          "Highlight color" },
        { "sidebar icon size",        "Appearance",          "the Sidebar icon size pop-up" },
        { "show scroll bars",         "Appearance",          "the Show scroll bars radio buttons" },
        { "wallpaper",                "Wallpaper",           "the whole pane" },
        { "screen saver",             "Screen Saver",        "the whole pane" },
        { "require password after sleep", "Lock Screen",     "Require password after…" },
        { "turn display off",         "Lock Screen",         "the two sleep timers" },
        { "screen sleep",             "Lock Screen",         "Turn display off on…" },
        { "battery settings",         "Battery",             "the whole pane" },
        { "low power mode",           "Battery",             "the top pop-up" },
        { "prevent sleep",            "Battery",             "Options… → Prevent automatic sleeping" },
        { "wake for network access",  "Battery",             "Options…" },
        { "printers",                 "Printers & Scanners", "the whole pane" },
        { "add printer",              "Printers & Scanners", "the Add Printer… button" },
        { "default printer",          "Printers & Scanners", "under the printer list" },
        { "siri",                     "Siri",                "the whole pane" },
        { "hey siri",                 "Siri",                "Listen for" },
        { "internet accounts",        "Internet Accounts",   "the whole pane" },
        { "add email account",        "Internet Accounts",   "the Add Account button" },
        { "game center",              "Game Center",         "the whole pane" },
        { "apple pay",                "Wallet & Apple Pay",  "the whole pane" },
    }

    sp.rows    = {}      -- index -> { name, url, group, from }
    sp.orphans = {}      -- terms naming a pane that is not in the table
    sp.scanned = 0
    sp.opens   = 0
    sp.asks    = 0       -- times the query was handed to Apple's own search
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
        local rows, byName = {}, {}
        for _, r in ipairs(sp.panes) do
            local row = { name = r[1], url = sp.urlFor(r[2]),
                          group = r[3], from = "table", kind = "pane" }
            rows[#rows + 1] = row
            byName[r[1]] = row
        end
        local scanned = sp.scan()
        sp.scanned = #scanned
        for _, r in ipairs(scanned) do
            r.kind = "pane"
            rows[#rows + 1] = r
            byName[r.name] = byName[r.name] or r
        end
        -- 🚨 A TERM IS A POINTER, AND A POINTER AT NOTHING IS WORSE THAN A
        -- MISSING ROW. It would look right in the picker and do nothing on
        -- ⏎ — the exact failure this module's header complains about in
        -- Apple's URL scheme. Dropped and counted instead; the suite fails
        -- on the first orphan, so one cannot reach a release.
        sp.orphans = {}
        for _, t in ipairs(sp.terms) do
            local pane = byName[t[2]]
            if pane then
                rows[#rows + 1] = {
                    name  = t[1],
                    url   = pane.url,
                    group = pane.name,
                    where = t[3] or "",
                    from  = pane.from,
                    kind  = "term",
                    pane  = pane.name,
                }
            else
                sp.orphans[#sp.orphans + 1] = t[1] .. " → " .. tostring(t[2])
            end
        end
        sp.rows = rows
        return rows
    end

    -- ---- 🔎 the complete half: Apple's own search ------------------------
    -- Everything from here to sp.askApple is the hand-off described in the
    -- header. It types rather than poking a value in, and it polls for the
    -- field rather than sleeping a fixed time — both for reasons that are
    -- written out up there rather than repeated here.
    sp.SETTINGS_BUNDLE = "com.apple.systempreferences"
    sp.appleTick    = 0.35   -- how often to look for the search field
    sp.appleTimeout = 6.0    -- and how long to keep looking
    sp.axTimeout    = 0.30   -- per AX question, so a busy Settings cannot hang us
    sp.axNodes      = 400    -- ceiling on the tree walk
    sp.appleTimer   = nil    -- HELD: an unreferenced hs.timer is collected
    sp.lastAsk      = nil

    -- Breadth-first, bounded twice: by node count and by the queue itself
    -- emptying. A search field is a handful of levels down in every macOS
    -- build so far, and an unbounded walk of somebody else's view tree is
    -- how a picker becomes a beachball.
    function sp.findSearchField(root)
        if not root then return nil end
        local queue, seen, fallback = { root }, 0, nil
        while #queue > 0 and seen < sp.axNodes do
            local node = table.remove(queue, 1)
            seen = seen + 1
            local role, subrole
            pcall(function() role    = node:attributeValue("AXRole") end)
            pcall(function() subrole = node:attributeValue("AXSubrole") end)
            if subrole == "AXSearchField" then return node, seen end
            -- A plain text field is the fallback, not the answer: System
            -- Settings has exactly one text field in its toolbar today,
            -- but a pane with a text box open would offer another, and the
            -- subrole is the only thing that says WHICH.
            if role == "AXTextField" and not fallback then fallback = node end
            local kids
            pcall(function() kids = node:attributeValue("AXChildren") end)
            if type(kids) == "table" then
                for _, k in ipairs(kids) do queue[#queue + 1] = k end
            end
        end
        return fallback, seen
    end

    -- The typing itself. Split out so the test can drive it without an
    -- event tap, and so there is one place the injection guard is applied.
    function sp.typeInto(field, text)
        if not field then return false end
        local focused = false
        pcall(function()
            field:setAttributeValue("AXFocused", true)
            focused = true
        end)
        -- Clear whatever is in the box first. Failing this is not fatal —
        -- a stale query in front of yours is ugly, not wrong — so it is
        -- attempted and not checked.
        pcall(function() field:setAttributeValue("AXValue", "") end)
        local typed = false
        local function doType()
            typed = pcall(function() hs.eventtap.keyStrokes(text) end) and true
        end
        if _G.withInjection then pcall(_G.withInjection, doType) else doType() end
        return focused and typed
    end

    function sp.stopAppleTimer()
        if sp.appleTimer then pcall(function() sp.appleTimer:stop() end) end
        sp.appleTimer = nil
    end

    function sp.askApple(query)
        query = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if query == "" then return false end
        sp.stopAppleTimer()
        sp.lastAsk = query
        local launched = pcall(function()
            hs.application.launchOrFocusByBundleID(sp.SETTINGS_BUNDLE)
        end)
        if not launched then
            -- 6.144.1 — through open(1) like every other destination here;
            -- hs.urlevent.openURL refused this scheme-only URL outright.
            sp.launch("x-apple.systempreferences:")
        end
        local waited = 0
        local okTimer = pcall(function()
            sp.appleTimer = hs.timer.doEvery(sp.appleTick, function()
                waited = waited + sp.appleTick
                local field
                pcall(function()
                    local app = hs.application.get(sp.SETTINGS_BUNDLE)
                    if not app then return end
                    local ax = hs.axuielement.applicationElement(app)
                    if not ax then return end
                    -- 🚨 setTimeout BEFORE ANYTHING IS ASKED, and on the
                    -- window as well: a child element inherits nothing, and
                    -- every question below waits on another process.
                    pcall(function() ax:setTimeout(sp.axTimeout) end)
                    local win = ax:attributeValue("AXFocusedWindow")
                             or (ax:attributeValue("AXWindows") or {})[1]
                    if not win then return end
                    pcall(function() win:setTimeout(sp.axTimeout) end)
                    field = sp.findSearchField(win)
                end)
                if field then
                    sp.stopAppleTimer()
                    sp.asks = sp.asks + 1
                    if sp.typeInto(field, query) then
                        say("handed “" .. query .. "” to Apple's own search")
                    else
                        sp.lastNote = "found the search field but could not type into it"
                        warn(sp.lastNote)
                        hs.alert.show("🔎 System Settings is open — its search box\n"
                                      .. "is top left. Type: " .. query, 5)
                    end
                    return
                end
                if waited >= sp.appleTimeout then
                    sp.stopAppleTimer()
                    -- ⚠️ SAY SO RATHER THAN TYPING INTO WHATEVER HAS FOCUS.
                    -- Blind keystrokes into an unknown window is how a
                    -- search query ends up in a document.
                    sp.lastNote = "could not find the System Settings search field"
                    warn(sp.lastNote)
                    hs.alert.show("🔎 Could not find the search box in System\n"
                                  .. "Settings. It is top left — type: " .. query, 5)
                end
            end)
        end)
        if not (okTimer and sp.appleTimer) then
            warn("could not arm the search hand-off")
            hs.alert.show("🔎 System Settings is opening — its search box is\n"
                          .. "top left. Type: " .. query, 5)
            return false
        end
        return true
    end

    -- ---- opening ---------------------------------------------------------
    -- 🚨 6.144.1 — EVERYTHING GOES THROUGH open(1), NOTHING THROUGH
    -- hs.urlevent.openURL. That call refuses ANY url without '://' — it
    -- logs "called for a URL that lacks '://'" and returns false without
    -- opening — and every x-apple.systempreferences: destination is
    -- exactly that shape. Worse, the old code wrapped it in a pcall, and
    -- A REFUSAL IS A RETURN VALUE, NOT A THROW: the pcall reported
    -- success, the hs.execute fallback on the next line never ran once,
    -- and sp.opens counted a pane that never opened. Every URL row of ⇪,
    -- was silently dead while reporting itself fine. /usr/bin/open takes
    -- a Settings URL and a .prefPane path alike as ONE ARGUMENT (an
    -- array, the net_tools rule — no shell, no quoting), and reports
    -- refusal in its exit code, which is the only place it does: that
    -- callback is where failure is said out loud now.
    sp.openBin = "/usr/bin/open"
    function sp.launch(target)
        local started = false
        pcall(function()
            local t = hs.task.new(sp.openBin, function(rc)
                if rc ~= 0 then
                    sp.lastNote = "open(1) refused: " .. tostring(target)
                    warn(sp.lastNote)
                    pcall(function()
                        hs.alert.show("⚙️ System Settings refused that pane", 3)
                    end)
                end
            end, { tostring(target) })
            sp.task = t     -- HELD: an unreferenced hs.task is reaped mid-run
            if t:start() then started = true end
        end)
        return started
    end

    -- 🚨 AN EMPTY STRING IS NOT A URL, AND `not ""` IS FALSE IN LUA. Until
    -- 6.122.0 this guard read `not row.url`, which a row carrying "" walks
    -- straight past — into the opener with nothing to open and then into a
    -- concatenation of row.name, which such a row does not have either.
    -- Found by a break test that CRASHED where it should have reported: a
    -- test harness cannot tell you about a nil field it never reaches.
    function sp.open(row)
        if not row then return false end
        if type(row.url) ~= "string" or row.url == "" then
            sp.lastNote = "no destination for " .. tostring(row.name or "that row")
            warn(sp.lastNote)
            return false
        end
        -- A .prefPane on disk is a FILE and a Settings destination is a
        -- URL; open(1) takes either as the same single argument, so the
        -- branch the old code needed is gone with the bug.
        local ok = sp.launch(row.url)
        if ok then
            sp.opens      = sp.opens + 1
            sp.lastOpened = row.name
            sp.lastURL    = row.url
            say("handed to open(1): " .. row.name)
            return true
        end
        sp.lastNote = "could not open " .. tostring(row.name or "that row")
        warn(sp.lastNote)
        hs.alert.show("⚙️ Could not open " .. row.name, 3)
        return false
    end

    -- ---- the picker ------------------------------------------------------
    -- ⚠️ The row carries an INTEGER, not the pane table. Every value in a
    -- chooser row crosses into Objective-C and a nested table does not
    -- survive it — LuaSkin discards the whole list and logs, so the panel
    -- would open empty with nothing thrown. Same rule as ⇪⇧T's snippets.
    function sp.rowChoice(r, i)
        if r.kind == "term" then
            return {
                text    = r.name,
                subText = "→ " .. r.pane
                          .. (r.where ~= "" and ("   ·   " .. r.where) or ""),
                idx     = i,
            }
        end
        return {
            text    = r.name,
            subText = r.group .. (r.from == "disk"
                      and "   ·   installed pane on disk" or ""),
            idx     = i,
        }
    end

    function sp.choices()
        local rows, out = sp.build(), {}
        for i, r in ipairs(rows) do out[#out + 1] = sp.rowChoice(r, i) end
        return out
    end

    -- Every word must appear somewhere in the row. "night dis" finds Night
    -- Shift because the row carries its pane name too — which is the whole
    -- reason a term row prints "→ Displays" rather than just the term.
    function sp.matches(r, words)
        local hay = (tostring(r.name or "") .. " "
                     .. tostring(r.pane or r.group or "") .. " "
                     .. tostring(r.where or "")):lower()
        for _, w in ipairs(words) do
            if not hay:find(w, 1, true) then return false end
        end
        return true
    end

    -- 🚨 THE ASK ROW IS ALWAYS LAST AND ALWAYS THERE. It is the promise
    -- that the hand-written index is not a ceiling: whatever you typed,
    -- Apple's own search can still be asked. It carries idx = 0, which no
    -- real row can have, so the callback cannot confuse the two.
    function sp.filter(query)
        query = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
        local rows = sp.rows
        if not rows or #rows == 0 then rows = sp.build() end
        if query == "" then
            local out = {}
            for i, r in ipairs(rows) do out[#out + 1] = sp.rowChoice(r, i) end
            return out
        end
        local words = {}
        for w in query:gmatch("%S+") do words[#words + 1] = w end
        local out = {}
        for i, r in ipairs(rows) do
            if sp.matches(r, words) then out[#out + 1] = sp.rowChoice(r, i) end
        end
        out[#out + 1] = {
            text    = "🔎 Search System Settings for “" .. query .. "”",
            subText = #out == 0
                      and "Nothing here matches — Apple's own index knows more"
                      or  "Apple's own search, in case the right row is not above",
            idx     = 0,
            ask     = query,
        }
        return out
    end

    function sp.show()
        if not sp.enabled then return end
        local choices = sp.choices()
        if not sp.chooser then
            sp.chooser = hs.chooser.new(function(pick)
                if not pick then return end
                if pick.idx == 0 then return sp.askApple(pick.ask) end
                sp.open(sp.rows[pick.idx])
            end)
            -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.settingsPanes = sp.chooser
            pcall(function()
                -- ⚠️ searchSubText OFF now that the filtering is ours. Left
                -- on, the chooser would ALSO filter what sp.filter already
                -- returned, and the ask row — whose subtitle says nothing
                -- about your query — would be filtered out of its own list.
                sp.chooser:searchSubText(false)
                sp.chooser:width(38)
            end)
            pcall(function()
                sp.chooser:queryChangedCallback(function(q)
                    -- per-keystroke: guarded like an eventtap, because an
                    -- error in here repeats on every character typed
                    pcall(function() sp.chooser:choices(sp.filter(q)) end)
                end)
            end)
        end
        sp.chooser:choices(choices)
        sp.chooser:placeholderText(#sp.panes .. " panes · " .. #sp.terms
            .. " settings — type anything, ⏎ takes you there")
        sp.chooser:query("")
        -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
        -- LAST picker's coordinates standing in _G.lastPopupPlacement,
        -- and window_move computes its grab box from that record. It
        -- could not be dragged at all until 6.127.0.
        if core.showPopup then core.showPopup(sp.chooser)
        else sp.chooser:show() end
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
        local L = { "⚙️ SETTINGS SEARCH" }
        L[#L + 1] = "   listed      : " .. #rows .. " rows"
        L[#L + 1] = "   curated     : " .. #sp.panes .. " panes in the table"
        L[#L + 1] = "   settings    : " .. #sp.terms .. " named settings inside them"
        L[#L + 1] = "   found       : " .. sp.scanned .. " .prefPane bundles on disk"
        L[#L + 1] = "   opened      : " .. sp.opens .. " this session"
        L[#L + 1] = "   handed off  : " .. sp.asks .. " to Apple's own search"
        if sp.lastAsk then
            L[#L + 1] = "   last search : " .. sp.lastAsk
        end
        -- 🚨 AN ORPHAN IS A ROW THAT LOOKS FINE AND DOES NOTHING. The suite
        -- fails on the first one, so this should always read zero — it is
        -- here for the case where a pane is renamed on a live machine.
        if #sp.orphans > 0 then
            L[#L + 1] = "   ⚠️ ORPHANS  : " .. #sp.orphans
                        .. " settings name a pane that is not in the table"
            for _, o in ipairs(sp.orphans) do L[#L + 1] = "        " .. o end
        end
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
    core.provide("settings.ask",    function(q) return sp.askApple(q) end)

    _G.settingsPanes = sp
    M.sp     = sp
    M.config = sp
end

return M
