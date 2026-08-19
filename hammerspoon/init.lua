-- =====================================================================
-- * Working VERSION *
-- =====================================================================
-- =====================================================================
-- 08-19-26 using Claude          ← EDITED date. Bumped with every release.
-- =====================================================================
-- .Hammerspoon ARCHITECTURE VERSION CONTROL: 6.111.0
-- =====================================================================

-- NEW IN 6.111.0 — ⇪/ REOPENS WHERE YOU WERE READING:
--   LL: "the cheat sheet still isn't remembering where I am when I close
--   it." Three things could have meant, so all three were measured
--   against the shipped file first. The PANEL's position survived a
--   close (6.67.0) and a reload (6.106.0) — that half was working. What
--   did not survive was THE ROW YOU HAD SCROLLED TO: hide() dropped the
--   state table and show() always began at row 1, so a 300-row sheet you
--   had walked halfway down started again from the top every time.
--   The row is now kept at the moment of a real close and restored on
--   the next ⇪/.
--   🚨 THE FIX IS A THREE-WAY DISTINCTION, and it is the whole subtlety:
--   show(nil) is a fresh open and reopens where you were; show(false) is
--   a FILTER keystroke and must still snap to the top, because you are
--   looking at a shorter list and row 40 of the old one is blank space
--   that reads as "found nothing"; show(true) is an in-place redraw and
--   stays put. nil and false used to be the same thing, which is why
--   this could not be written as a one-line `or`.
--   Closing while a search is active does NOT store the filtered row —
--   row 12 of "what matched win" is not row 12 of the sheet — so you
--   reopen at the row you were on BEFORE you searched. A remembered row
--   past the end of a shorter sheet clamps to the last full view.
--   SESSION-SCOPED on purpose, unlike the panel position: a row is an
--   index into a list rebuilt from the modules every boot, and restoring
--   a stale index would put you confidently in the wrong place.
--   cheatSheet.rememberScroll = false goes back to always-from-the-top.
--
-- NEW IN 6.110.0 — DOC KEYWORDS STOPS SHOUTING:
--   The other half of what LL's Console log showed. The four LuaSkin
--   errors of 6.109.0 were buried in SEVERAL HUNDRED 🏷 Doc Keywords
--   lines — a first OneDrive sync, tagged one console line at a time
--   between 04:58 and 05:13. The module treated a sync exactly like a
--   save, so hundreds of files each started their own unzip the instant
--   they settled, each started its own osascript, and each said so.
--   A settled batch is a RUN now, bounded twice: 🚨 THREE FILES ARE
--   READ AT A TIME and the rest wait in a queue, so a thousand-file
--   sync costs time instead of a thousand child processes on a work
--   Mac — and a run bigger than three reports ONE total when it
--   finishes instead of a line per file. Nothing is dropped and nothing
--   is hidden: every file is still tagged, still recorded, and still
--   listed by _G.docKeywordsReport(). Saving one document still names
--   it, _G.tagDoc() always names the file you asked for even mid-run,
--   and a Mac that refuses every write now says so once instead of
--   three hundred times.
--   The Console is where errors are supposed to be visible. A module
--   that fills it with routine success is hiding them.
--
-- NEW IN 6.109.0 — ⇪⇧T GETS ITS ROWS BACK:
--   LL sent a Console log with four LuaSkin errors in it. They were real,
--   and they were not new — the snippet chooser has been handing the
--   snippet TABLE to hs.chooser:choices() since 6.68.0. A chooser row
--   crosses into Objective-C, so a function (.fn on an action) or a
--   nested table cannot make the trip; LuaSkin rejects the key, then the
--   row, then the whole list, and says so:
--     LuaSkin: hs.chooser:choices() table could not be parsed correctly.
--   🚨 IT LOGS, IT DOES NOT THROW — which is why the pcall around the
--   call never caught it and ⇪⇧T failed in silence for 41 versions.
--   The payload stays in Lua now and the row carries a plain integer
--   into it. A test walks every row and fails on any value that is not
--   a string, number or boolean, so this cannot come back quietly.
--
-- NEW IN 6.108.0 — BEGONE IS FILED UNDER TEXT:
--   One word in one file. LL flagged Begone's cheat-sheet placement;
--   Time ("the day, and what interrupts it") was defensible but not
--   where a hand goes looking for a typed keyword. It now sits in
--   ✂️ TEXT & CLIPBOARD directly under the Text Expander — the module
--   whose machinery fires it. No key, binding or behaviour changed;
--   this is the position of one card on one panel.
--
-- NEW IN 6.107.0 — ⇪space STAYS WHERE YOU PUT IT TOO:
--   The other half of 6.106.0. ⇪space has reopened where you dragged it
--   since 6.93.0, but only within a session — the module is rebuilt on
--   every reload and the position went with it. It is one hs.settings
--   key now, validated the same way the cheat sheet's is.
--   🚨 THE WRITE IS DEBOUNCED, and that is not a nicety. The drag layer
--   calls move() from a repeating timer for the WHOLE drag, not once
--   when you let go, so saving inline would write to the settings plist
--   tens of times a second for as long as the mouse is down. The panel
--   still tracks the pointer every tick; only the write waits 0.4s for
--   you to settle. _G.unifiedCenter() puts it back and forgets.
--
-- =====================================================================
-- WHAT EACH TOOL DOES :: ARCHITECTURE VERSION CONTROL: 6.111.0
-- =====================================================================
--
-- 🧭 PORTABILITY LAYER (§0.1)
--    One identical init.lua runs on any Mac. Auto-detects your
--    OneDrive folder (OneDrive-Personal preferred, even on the work
--    Mac where a company OneDrive is also signed in), tags every
--    per-machine data file with the Mac's name so two Macs sharing
--    one OneDrive never overwrite each other, and falls back to
--    local storage when no OneDrive is found. ALL log, note &
--    history files live in <OneDrive>/Logs — the only things left
--    in ~/.hammerspoon are init.lua and secret.lua.
--    Zero edits needed when you copy the file to the work Mac.
--
-- 🔐 CREDENTIALS (§0.2)  ·  no key: Asana features politely off
--    Your Asana token lives only in ~/.hammerspoon/secret.lua —
--    never in this file, never in OneDrive (the nightly backup
--    excludes it) — so init.lua can be shared, backed up, or
--    pasted in chat without exposing anything. Missing secret.lua
--    just turns Asana off; everything else keeps running.
--
-- 🔑 HOTKEY CONFLICT SENTRY (§0.3)
--    Every key binding registers through a watchdog. If the same
--    combo is claimed twice (the later one silently kills the
--    earlier feature), the Console names it at boot. Also flags
--    combos that match known macOS defaults like Spotlight or
--    Spaces so a dead key is never a mystery.
--
-- ⇪⇧D  DIAGNOSTICS (§1.11)
--    Writes a full report — versions, boot timings, screens,
--    hotkeys, feature states, a live window-enumeration timing,
--    recent errors and the last 25 internal events — to the
--    Console, your clipboard AND <logsDir>/diagnostics-<machine>.txt.
--    Paste it into chat when something misbehaves. Verbose live
--    logging: type  _G.diag.verbose = true  in the Console.
--
-- ⌥Tab  WINDOW SWITCHER (§1.10)
--    The Windows-style Alt+Tab macOS doesn't have: hold ⌥ and tap
--    Tab to walk every open WINDOW — one thumbnail tile each, title
--    underneath — ⌥⇧Tab to walk back, release ⌥ to switch. Lists
--    minimised windows and hidden apps across all Spaces. ⌘Tab is
--    left alone: macOS reserves it, and it switches apps not windows.
--
-- ⇪/  SHORTCUT CHEAT SHEET (§1.6)
--    One tall translucent column listing every hotkey in this
--    config — scroll it with ↑↓, PgUp/PgDn, Home/End or the wheel.
--    Press ⇪/ again or Esc to close; a click does NOT close it and
--    passes through to whatever is underneath. Add your own
--    entries with ⇪= (pipe format: Keys | Description | Group),
--    edit them with ⇪E, remove with ⇪-.
--    Custom entries live in <OneDrive>/Logs/custom_shortcuts.json —
--    SHARED between both Macs, so an entry added on one appears on
--    the other after its next reload.
--
-- ⇪⇧ ARROWS  POPUP NUDGING (§1.5) · 6.89.0: or just ⌘-DRAG it
--    Every popup opens centered on your frontmost app's monitor. Want
--    it elsewhere? Hold ⌘ and DRAG it (modules/window_move.lua — every
--    picker and panel; where you drop a picker STICKS), or nudge with
--    ⇪⇧ + arrow keys (hold to walk it). ⇪⇧R = back to automatic.
--
-- ☁️ DAILY BACKUP (§1.7)  ·  automatic at 5:00 PM
--    rsync copies your ~/.hammerspoon folder (EXCEPT secret.lua —
--    the token never leaves this Mac) to
--    OneDrive/Backups/Hammerspoon/<MachineName>/ every day.
--    Quiet on success; on-screen alert if something goes wrong.
--    Your data files don't need this backup anymore — they live in
--    OneDrive directly — this protects init.lua itself.
--
-- ⇪P  APP PEEK (§1.8)
--    Hides the frontmost app instantly so you can see what's
--    behind it. Same key brings it back and refocuses it.
--    Closest thing to "make a window transparent" that macOS allows.
--
-- ⇪ ARROWS / \\ / W / ⇪[ ]  WINDOW ARRANGER (§1.9)
--    ⇪←/→    snap to left or right half of the screen
--    ⇪↑       fill the screen (not native full-screen mode)
--    ⇪\\       split the two most recent windows side by side
--    ⇪⇧W      picker: summon any running app to this monitor
--    ⇪↓       return the window to where it was before you moved it
--    ⌃⌥⌘[ ]   throw the window to the next monitor right or left
--
-- 🔎 ⇪space  UNIFIED SEARCH (modules/unified_search.lua) — 6.89.0
--    One typed search over EVERY store: clipboard, commands, shots,
--    notes, Asana, OCR, docs, moves, pad. @tag pins one source;
--    ⏎ copies, ⌘⏎ the path. ⇪⇧space = big-thumbnail shot browser.
--
-- ⇪V  CLIPBOARD HISTORY (§2 / §3)
--    Keeps your last 1,000 copied texts, saved per-machine to
--    <OneDrive>/Logs/clipboard_history-<Mac>.json. Search matches
--    the FULL content of every item, not just what a row displays.
--    Copying something you've copied before moves it to the front
--    instead of using a second slot. Select any row to put it back
--    on the clipboard. Images go to the OCR engine instead.
--    ⌘⌃⌥⇧V opens the same history to EDIT or DELETE an entry instead —
--    Save with the text cleared deletes it.
--
-- ⇪O  OCR LOG SEARCH (modules/ocr_engine.lua — was §2 until 6.105.0)
--    When an image lands on the clipboard, Hammerspoon runs your
--    "HS OCR" Apple Shortcut automatically and indexes the extracted
--    text. ⇪O searches everything ever OCR'd; selecting a row
--    copies the text. NEW: copy image FILES in Finder (⌘C) and the
--    OCR text is also written into each file's Finder comment —
--    Spotlight-searchable, so meaningless filenames stop mattering.
--    ⇪⇧O opens the same history to EDIT or DELETE an entry instead —
--    fixes a bad OCR read in place, or clears out junk. Save with the
--    text cleared deletes it.
--
-- ✅ ⇪T  ASANA TASK CREATOR (§4 / §5 + modules/task_form.lua)
--    6.86.0: ⇪T opens a FORM — labeled Title/Description/Assignee/
--    Attachment. ⏎ sends from any field, ⌥⏎ = newline, Esc keeps the
--    draft; 📸/⌘L drops the newest ⇪4 screenshot into Attachment.
--    ⇪⇧S searches PAST tasks (the old pipe picker, 30-day history).
--
-- 📸 ⇪4  SCREENSHOTS (modules/screenshots.lua + screenshot_editor.lua)
--    ⇪4 = native crosshair capture (SPACE = window, Esc cancels) to
--    OneDrive's "2026 Screenshots" AND the clipboard. ⇪⇧4 = the
--    PANEL: ⌘1–⌘8 (⌘8 = BIG thumbnails) and TYPING searches. ⏎ image
--    · ⌘⏎ path · ⌃⏎ compress · ⌥⏎ EDITOR (blur/text/arrows; ⌘Z).
--
-- 📅 ⌃⌥⌘L / ⌃⌥⌘C  ASANA DASHBOARD (§6)
--    Fetches your incomplete Asana tasks and shows them in five
--    color-coded buckets with a legend strip above the list:
--    🔴 Overdue (40)  🟡 Due today (10)  🔵 Due this week (30)
--    🟠 Due later (10)  🟣 No due date (10) — newest created first
--    ⌃⌥⌘L lists tasks, opening one in the browser.
--    ⌃⌥⌘C prompts for a comment and posts it to Asana.
--
-- 📊 ⌘⌥⇧0  ACTIVITY TRACKER (§3.6)
--    Tracks which app and which document/window you're in, persisted
--    to OneDrive as a CSV. Only real Dock apps are counted (loginwindow
--    and ScreenSaverEngine are never logged), and a lock/sleep watcher
--    closes the open session the instant the screen locks — no more
--    inflated durations after a locked weekend. Open the picker and type:
--    (empty)   today's apps ranked most→least time
--    week      this week's totals
--    month     top apps AND top documents/windows this month
--    anything  searches all history by app name or window title
--    Automatic reports pop up daily at 4:00 PM and Monday at 7:30 AM.
--    Selecting any row copies the name + time to the clipboard.
--
-- 👁 APP WATCHER (§3.7)  ·  automatic, no key needed
--    Monitors apps you care about (edit the list in §3.7).
--    When one quits or crashes, a popup appears with 🚀 Spawn
--    (relaunch) or 🛑 End (leave closed), pinging every 2 seconds.
--    No response in 30 seconds → dismisses and posts a notification.
--
-- ⇪F  FILE TRACKER (§3.8)
--    Watches your home folder and OneDrive for renames, moves,
--    copies, and new files. Logs them straight to
--    <OneDrive>/Logs/file_changes-<Mac>.csv with 90-day history —
--    it's already in OneDrive, so no separate daily copy exists
--    anymore. ⌃⌥⇧F opens a searchable picker; Enter copies a row.
--
-- 📦 ⌃⌥⇧U  APP UPDATE TRACKER (§3.10 / §3.10.1)
--    Compares each tracked app's installed version against the latest
--    Homebrew knows about. ⌃⌥⇧U opens a picker (always re-checks fresh
--    on open, plus a daily 9am pass), "update available" rows sorted
--    first. Enter acts on the row: installs via `brew upgrade` when
--    Homebrew actually manages that app, opens the vendor's download
--    page otherwise — an "⬆️ Upgrade ALL" row batches every brew-
--    manageable update into one shot. No predicted dates — a live
--    "what's stale right now" report you can act on immediately.
--
-- ✏️ AUTOCORRECT (§3.9)  ·  ⇪S toggle · ⇪Z undo & learn
--    Fixes typos the instant you end a word (space, punctuation,
--    apostrophe, return) — system-wide, in any app:
--    Dictionary  10,970 entries: teh→the, Mna→Man, dont→don't,
--                alot→"a lot", thier→their, libary→library…
--                Case is preserved: Mna→Man, MNA→MAN, mna→man.
--    TWo-caps    MAn→Man, THe→The — one rule covers everything;
--                80 real exceptions (IDs, TVs, MHz…) in the CSV.
--    ⌃⌥⌘Z       if a fix was wrong: rewinds the text AND (for
--                two-caps fixes) permanently adds the word to your
--                exceptions so it never fires again.
--    The dictionary is SHARED: <OneDrive>/Logs/autocorrect.csv —
--    an exception learned on one Mac works on the other after its
--    next reload. Password fields, pasted text, and Terminal are
--    never touched.
--
-- =====================================================================
-- =====================================================================
-- REQUIRED on every Mac (this is the whole install):
--    • Hammerspoon app (runs fine from ~/Applications — no admin)
--    • ~/.hammerspoon/init.lua            ← this file, identical everywhere
--    • Accessibility permission for Hammerspoon (System Settings →
--      Privacy & Security → Accessibility) — needed by the Window
--      Arranger, App Peek & app summon; everything degrades politely
--      without it, but grant it if the Mac allows
-- PER-MACHINE, one-time:
--    • ~/.hammerspoon/secret.lua          ← Asana token (see §0.2);
--      omit on a Mac where Asana isn't used. NEVER put this in
--      OneDrive — each Mac keeps its own, and the nightly backup
--      deliberately skips it.
-- SHARED DATA (lives in <OneDrive>/Logs — arrives via OneDrive sync,
-- nothing to copy by hand once the first Mac has run 6.10.0):
--    • autocorrect.csv                    ← typo dictionary (§3.9);
--      auto-seeded with a starter list if somehow missing
--    • custom_shortcuts.json              ← your ⭐ cheat-sheet entries
-- CREATED AUTOMATICALLY (never make these yourself):
--    • <OneDrive>/Logs/clipboard_history-<MachineName>.json,
--      asana_history-<MachineName>.json,
--      file_changes-<MachineName>.csv,
--      activity_history-<MachineName>.csv,
--      image_text-<MachineName>.csv,
--      app_updates-<MachineName>.csv  (per-machine, so two Macs
--      sharing one OneDrive never fight over files) and
--      <OneDrive>/Backups/Hammerspoon/<MachineName>/ — or
--      ~/.hammerspoon/logs/ for all of it when the Mac has no
--      OneDrive (§0.1)
-- =====================================================================

-- =====================================================================
-- 🗺 FILE MAP — the sections below, in the order they actually RUN
-- =====================================================================
-- Lua reads this file once, top to bottom: a definition must exist
-- before its first use, and that execution order is the only order that
-- matters to Hammerspoon. Section NUMBERS are historical names — moving
-- code to make them tidy is how definitions get lost (NEW IN 6.40.0) —
-- so navigate by this map, not by the numbering:
--
--   §0     core environment · dock icon · EmmyLua
--   §0.1   portability — every path and folder resolved, per Mac
--   §0.2   credentials — secret.lua loader (no token lives here)
--   §0.3   hotkey conflict sentry    §0.4   hyper migration map
--   §1     global state              §1.5   popup positioning
--   §1.6   cheat sheet (core/cheatsheet.lua) · safe canvas show ·
--          draggable panels · shared arbitration (core/coexist.lua)
--   §1.11  diagnostics (core/diagnostics.lua)
--   §2     shared helpers (the OCR engine that was here moved to
--          modules/ocr_engine.lua in 6.105.0)
--   §3     background monitoring     §3.12  the hyper key itself
--   (the Asana task creator that sat between §3.12 and §5 moved to
--          modules/task_creator.lua in 6.98.0)
--   §5     hotkey integrations — the core pickers still bound here
--   §6     Asana dashboard           §7     bootstrap report
--   §1.4   shared text/CSV helpers (late on purpose — everything
--          CALLS them after load; nothing above needs them sooner)
--   §1.12  module loader → BASE list → machine profiles → safe
--          mode → boot report. The 46 modules/*.lua load HERE, last.
-- =====================================================================

-- =====================================================================
-- 0. CORE ENVIRONMENT & DEPENDENCIES
-- =====================================================================
local function safeRequire(mod)
    local s, r = pcall(require, mod)
    if not s then print('⚠️ Architecture Fault - Missing Module: ' .. mod) return nil end
    return r
end

safeRequire("hs.task"); safeRequire("hs.image"); safeRequire("hs.alert"); safeRequire("hs.http")
safeRequire("hs.json"); safeRequire("hs.timer"); safeRequire("hs.pasteboard"); safeRequire("hs.eventtap")
safeRequire("hs.screen"); safeRequire("hs.drawing"); safeRequire("hs.geometry"); safeRequire("hs.chooser")
safeRequire("hs.application"); safeRequire("hs.hotkey"); safeRequire("hs.dialog"); safeRequire("hs.urlevent")
safeRequire("hs.window"); safeRequire("hs.sound"); safeRequire("hs.notify"); safeRequire("hs.canvas")
safeRequire("hs.fs"); safeRequire("hs.host"); safeRequire("hs.pathwatcher"); safeRequire("hs.osascript")
safeRequire("hs.axuielement")
safeRequire("hs.caffeinate")
safeRequire("hs.dockicon")

-- =====================================================================
-- 🖥 THE DOCK ICON, AND WHY HIDING IT IS A FEATURE (6.66.2)
-- =====================================================================
-- 🚨 LOAD-BEARING: an hs.chooser can only open over a FULL-SCREEN app
-- while Hammerspoon has NO Dock icon (documented hs.chooser behaviour —
-- a Dock-less app is an ACCESSORY app whose panels float anywhere).
-- Every picker in this config is an hs.chooser, so hiding the icon is
-- what makes ⇪V/⇪O/⇪⇧/ work over full-screen Excel. The cost: no Dock
-- icon, no ⌘Tab entry. The menu bar icon, Console and every hotkey
-- remain. Full story: NEW IN 6.66.2.
-- ✏️ SET false to keep the Dock icon (pickers then fail over
-- full-screen apps). Deliberately overrides the Preferences checkbox on
-- every load — the FILE is the configuration; a checkbox doesn't sync.
local hideDockIcon = true

if hideDockIcon then
    local ok = pcall(function() hs.dockicon.hide() end)
    if ok then
        print("🖥 Dock icon hidden — pickers can now open over full-screen apps")
    else
        -- Not fatal, and worth saying rather than leaving you to wonder
        -- why ⇪V still will not open over Excel in full screen.
        print("⚠️ 🖥 Could not hide the Dock icon — hs.chooser pickers will")
        print("   not appear over full-screen apps. Uncheck 'Show dock icon'")
        print("   in Hammerspoon Preferences to get the same effect by hand.")
    end
end

-- 🔇 6.44.10 — hs.hotkey logs every enable/disable at info level (the
-- ⌥Tab switcher alone is 64 lines per use), which buries the lines that
-- matter. Warnings and errors still print. Set "info" to debug a
-- binding. Full story: NEW IN 6.44.10.
pcall(function() hs.hotkey.setLogLevel("warning") end)

-- DYNAMIC HOME DIRECTORY RESOLUTION
local homeDir = os.getenv("HOME")

-- The boot clock starts here, before any real work, so §1.11's
-- report can say how long loading actually took.
_G.configVersion = "6.111.0"
_G.diagBootStart = hs.timer.secondsSinceEpoch();

-- ---- EmmyLua: editor autocomplete for the hs.* API -----------------
-- Writes annotation files describing every hs.* function so an
-- LSP-capable editor can autocomplete and underline wrong API usage AS
-- YOU TYPE — the exact shape of several past bugs here. Zero runtime
-- cost: it generates files and stops. Not installed? One console line,
-- and the config carries on. ⚠️ The files alone do nothing — your
-- EDITOR must be pointed at them (CotEditor cannot use them).
(function()
    local home = os.getenv("HOME") or ""
    local spoonPath = home .. "/.hammerspoon/Spoons/EmmyLua.spoon"
    local there = false
    pcall(function() there = hs.fs.attributes(spoonPath) ~= nil end)
    if not there then
        print("💡 EmmyLua not installed — hs.* editor autocomplete is off.")
        print("   Get it: https://www.hammerspoon.org/Spoons/EmmyLua.html — then point your editor at Spoons/EmmyLua.spoon/annotations")
        return
    end
    local ok, err = pcall(hs.loadSpoon, "EmmyLua")
    if ok then
        print("💡 EmmyLua: hs.* annotations refreshed for your editor")
    else
        -- Never fatal. A dev convenience must not take the config down.
        print("⚠️ EmmyLua present but failed to load: " .. tostring(err))
    end
end)()

-- A NO-OP STAND-IN for the diagnostics API, replaced by the real one in
-- §1.11. Sections earlier in the file log through _G.diag, and a section
-- that loaded before §1.11 — or a partial load that never reached it —
-- would otherwise throw on a logging call. A diagnostics system that can
-- cause the outage it exists to explain is worse than none.
-- 🚨 6.53.0 — err() RECORDS RATHER THAN DISCARDS, AND THE HANDLER IS
-- INSTALLED HERE, NOT IN core/diagnostics.lua.
--
-- This stand-in used to have `err = function() end` — a no-op — and
-- hs.uncaughtErrorHandler was set ONLY by core/diagnostics.lua, which
-- loads about a thousand lines further down and is (correctly) wrapped
-- in a pcall so a broken copy cannot stop the config booting. Those two
-- facts together left two windows in which an error vanished in silence:
--
--   1. EVERY LINE BEFORE core/diagnostics.lua LOADS. An error raised in
--      an async callback during early boot had nowhere to go at all.
--   2. THE WHOLE SESSION, if core/diagnostics.lua failed to load. The
--      config survives that by design — but it survives it with NO error
--      reporting, which is the exact moment you most need some, and
--      nothing announces the loss.
--
-- A Lua error inside a timer, an HTTP reply or a watcher CANNOT be
-- caught by a pcall in whatever scheduled it; hs.uncaughtErrorHandler is
-- the only place it can be seen. So the earliest possible version is
-- installed right here, with no dependencies beyond hs.alert.
-- core/diagnostics.lua replaces it later with the fuller version, and
-- preserves this table's `errors` (see its `_G.diag.errors or {}`), so
-- anything caught during early boot still reaches ⇪⇧D.
_G.diag = { verbose = false, trail = {}, errors = {}, marks = {},
            say = function() end, warn = function() end,
            mark = function() end,
            err = function(e)
                local t = _G.diag.errors
                t[#t + 1] = os.date("%H:%M:%S ") .. tostring(e)
                -- Bounded: an error in a repeating timer fires forever,
                -- and an unbounded list would grow until the Mac hurts.
                while #t > 50 do table.remove(t, 1) end
            end }

hs.uncaughtErrorHandler = function(err)
    pcall(function() _G.diag.err(err) end)
    print("💥 UNCAUGHT (early): " .. tostring(err))
    -- Routed through the ledger once it exists, so a runtime error lands
    -- in the same place as every other failure. Before that it still
    -- reaches the Console and the screen — the point is that no window
    -- of the boot is ever silent.
    local told = false
    pcall(function()
        if _G.notices then
            _G.notices.record("runtime", "uncaught", tostring(err))
            told = _G.notices.tell("Hammerspoon hit an error",
                       tostring(err):sub(1, 160) .. "\n⇪⇧D for the report",
                       { key = "uncaught:" .. tostring(err):sub(1, 60),
                         every = 300, seconds = 6 })
        end
    end)
    if not told then
        pcall(function()
            hs.alert.show("💥 Hammerspoon error — ⇪⇧D for the report", 4)
        end)
    end
end

-- 🔔 THE NOTICE LEDGER, loaded as early as it can be.
-- It has to exist BEFORE the module loader runs, because the failure it
-- most needs to report is a module that would not load. Same shape as
-- the other core files: pcall'd, so a broken copy costs you the
-- reporting and not the Mac — and if it does fail, that fact is itself
-- printed rather than swallowed, which would be a bleak little irony.
local notOK, notErr = pcall(function()
    local path = hs.configdir .. '/core/notices.lua'
    local chunk, loadErr = loadfile(path)
    if not chunk then error(loadErr or ('cannot read ' .. path), 0) end
    -- 6.58.0 — chunk()(core), matching every other core/ file. This one
    -- loads before hostTag/logsDir exist as locals (§0.1 has not run
    -- yet) — moving the load point later to hand them over would undo
    -- the whole point of loading notices this early, which is to be
    -- able to report a module-load failure. So it gets an empty table:
    -- honest about having nothing to offer yet, and still the same
    -- shape every other core/ file expects to be called in.
    chunk()({})
end)
if not notOK then
    print('⚠️ core/notices.lua failed to load — failures will still reach the '
          .. 'Console and ⇪⇧D, but you will not be told about them on screen. '
          .. tostring(notErr))
    pcall(function()
        hs.alert.show("⚠️ Hammerspoon: failure reporting is OFF\n"
                      .. "core/notices.lua did not load", 8)
    end)
end

-- 🖥 THE CONSOLE GATE (core/console.lua): ⛔/⚠️ banners + repeat limiter — _G.errorsReport()
do
    local ok, e = pcall(function()
        local chunk, le = loadfile(hs.configdir .. '/core/console.lua')
        if not chunk then error(le or 'cannot read core/console.lua', 0) end
        chunk()({})
    end)
    if not ok then print('⚠️ core/console.lua failed to load — the Console is unfiltered: ' .. tostring(e)) end
end

-- 6.42.0 — THE SERVICE REGISTRY, stubbed here so it is never nil.
-- When a section moved into a module, any code left in THIS file that
-- called one of its functions became a call to a nil GLOBAL — which Lua
-- does not complain about until the moment you press the key. That is
-- how ⇪0 broke: `renderActivityChoices` went to a module and the hotkey
-- handler here kept calling a name that no longer existed.
-- Modules now PUBLISH what the rest of the config may call, and callers
-- go through _G.service.call, which reports a missing provider instead
-- of throwing. §1.12 replaces this stub with the real thing.
_G.service = {
    registry = {},
    provide  = function(name, fn) _G.service.registry[name] = fn end,
    has      = function(name) return _G.service.registry[name] ~= nil end,
    call     = function(name, ...)
        local fn = _G.service.registry[name]
        if not fn then
            print("🔌 No provider for '" .. tostring(name)
                  .. "' — is its module loaded? (⇪⇧D lists module status)")
            return nil
        end
        local ok, a, b, c = pcall(fn, ...)
        if not ok then
            print("🔌 Service '" .. tostring(name) .. "' failed — " .. tostring(a))
            _G.diag.err("service " .. tostring(name) .. ": " .. tostring(a))
            return nil
        end
        return a, b, c
    end,
}

-- =====================================================================
-- 0.1 PORTABILITY LAYER — the same file runs on ANY Mac, zero edits
-- =====================================================================
-- Where does ALL data live? Resolved automatically, per Mac:
--   1. If you set an override below, that wins (the "flexible" escape
--      hatch for a locked-down machine with unusual folders).
--   2. Otherwise ~/Library/CloudStorage is scanned for a OneDrive
--      folder — "OneDrive-Personal" preferred, else any "OneDrive-…"
--      (so the work Mac, which has BOTH a company OneDrive and your
--      personal one, still lands on Personal). Everything data-like →
--      <OneDrive>/Logs, backups → <OneDrive>/Backups/Hammerspoon.
--   3. No OneDrive at all → everything goes to ~/.hammerspoon/logs
--      (created automatically) and the daily backup quietly disables
--      itself.
-- The Hammerspoon Console prints a PORTABILITY report at boot saying
-- exactly which of these happened — check there first on a new Mac.
local forceLogsDir   = nil  -- e.g. homeDir .. "/Documents/HSLogs"  (nil = auto)
local forceBackupDir = nil  -- e.g. homeDir .. "/Documents/HSBackup" (nil = auto)

-- PER-MACHINE IDENTITY: your Personal OneDrive syncs to BOTH Macs, so
-- if they shared file names, both would append to the same CSVs
-- (OneDrive conflict copies) and both would rsync into the same backup
-- folder (each Mac overwriting the other's histories). Instead every
-- machine writes its own files tagged with its own name — e.g.
-- activity_history-Lees-MacBook-Air.csv — and backs up to its own
-- subfolder. The ONLY deliberately shared files are autocorrect.csv
-- and custom_shortcuts.json (see §3.9 / §1.6): they change rarely and
-- benefit both Macs. Existing untagged files are adopted automatically.
local hostTag = "Mac"
pcall(function()
    hostTag = (hs.host.localizedName() or "Mac"):gsub("%s+", "-"):gsub("[^%w%-]", "")
    if hostTag == "" then hostTag = "Mac" end
end)

local cloudDir = nil
pcall(function()
    local base = homeDir .. "/Library/CloudStorage"
    local candidates = {}
    for entry in hs.fs.dir(base) do
        if entry:match("^OneDrive") and not entry:match("^OneDrive%-SharedLibraries") then
            table.insert(candidates, entry)
        end
    end
    table.sort(candidates)
    for _, c in ipairs(candidates) do
        if c == "OneDrive-Personal" then cloudDir = base .. "/" .. c end
    end
    if not cloudDir and #candidates > 0 then
        cloudDir = base .. "/" .. candidates[1]
    end
end)

local logsDir, backupDir
if cloudDir then
    logsDir   = cloudDir .. "/Logs"
    backupDir = cloudDir .. "/Backups/Hammerspoon/" .. hostTag
else
    logsDir   = hs.configdir .. "/logs"
    backupDir = nil  -- nowhere cloud-synced to back up to
end
if forceLogsDir   then logsDir   = forceLogsDir   end
if forceBackupDir then backupDir = forceBackupDir end
pcall(function() hs.fs.mkdir(logsDir) end)

-- One-time adoption: if this machine's new-location file doesn't exist
-- yet but the old one does, copy its contents in — so nothing already
-- recorded is ever lost by a path change. The legacy file is left in
-- place untouched (delete it yourself whenever you're confident).
local function adoptLegacyFile(newPath, legacyPath)
    local nf = io.open(newPath, "r")
    if nf then nf:close(); return end
    local lf = io.open(legacyPath, "r")
    if not lf then return end
    local content = lf:read("*a"); lf:close()
    local out = io.open(newPath, "w")
    if out then
        out:write(content); out:close()
        print("📦 Adopted legacy " .. legacyPath .. " → " .. newPath)
    end
end

-- WRITE-FAILURE WARNINGS: every data file now lives in the OneDrive
-- Logs folder, and CloudStorage paths depend on OneDrive running.
-- If OneDrive is quit — or the Logs folder is set to online-only —
-- writes fail. Before 6.10.0 that was SILENT data loss; now the first
-- failure per file shows an on-screen alert (once, not a nag-storm).
-- Fix: keep the Logs folder "Always keep on this device" in OneDrive.
local writeWarned = {}
local function warnWriteFailed(label)
    if writeWarned[label] then return end
    writeWarned[label] = true
    hs.alert.show("⚠️ Can't write " .. label .. " — is the OneDrive Logs folder available?", 6)
    print("🚨 Write failed: " .. label .. " (OneDrive quit, or Logs folder online-only?)")
end

-- =====================================================================
-- 0.2 CREDENTIALS — live in secret.lua, NEVER in this file
-- =====================================================================
-- This file contains no secrets, so it can be copied between Macs,
-- shared, or backed up freely. Each Mac gets its own one-time file at
-- ~/.hammerspoon/secret.lua containing exactly this (with your real
-- token from https://app.asana.com/0/my-apps):
--
--     return {
--         asanaToken = "PASTE_TOKEN_HERE",
--     }
--
-- (Optionally add asanaWorkspaceId = "..." / asanaProjectId = "..."
-- lines to override the defaults below — they're IDs, not secrets.)
-- No secret.lua on a machine? Everything else works; the Asana
-- features politely say they're off when you press their keys.
-- secret.lua deliberately STAYS in ~/.hammerspoon (not OneDrive) and
-- is excluded from the nightly backup — the token never leaves the Mac.
local secrets = {}
local secretsStatus = "missing"   -- "missing" | "loaded" | "broken: <why>"
do
    local path = hs.configdir .. "/secret.lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        local ok, s = pcall(dofile, path)
        if ok and type(s) == "table" then
            secrets = s
            secretsStatus = "loaded"
        elseif ok then
            secretsStatus = "broken: file doesn't return a table — first word must be 'return'"
        else
            secretsStatus = "broken: " .. tostring(s)
        end
    end
end
-- Trim stray whitespace/newlines around the token — a trailing space
-- from a copy/paste is invisible but produces a 401 from Asana, which
-- looks identical to a revoked token. Trimming removes that whole
-- class of confusion.
local asanaToken       = (secrets.asanaToken or ""):match("^%s*(.-)%s*$")
local asanaWorkspaceId = secrets.asanaWorkspaceId or "182448385076670"
local asanaProjectId   = secrets.asanaProjectId or "745948257030523"
local asanaEnabled     = (asanaToken ~= "")

-- Shape check: Asana personal access tokens look like
-- 2/<digits>/<digits>:<hex>. A token that doesn't match is very likely
-- mangled (smart quotes, truncated paste) — warn at boot rather than
-- letting it fail mysteriously later.
if asanaEnabled and not asanaToken:match("^%d+/%d+/%d+:%w+$") then
    print("⚠️ Asana token in secret.lua doesn't look like a normal token "
        .. "(expected 2/<digits>/<digits>:<hex>) — check for smart quotes or a truncated paste")
end

-- Gate for every Asana hotkey: true if usable, otherwise explains why
local function requireAsana()
    if asanaEnabled then return true end
    hs.alert.show("🔒 Asana is off on this Mac — create ~/.hammerspoon/secret.lua (see init.lua §0.2)", 4)
    return false
end

-- 6.10.0: task history & clipboard history moved to the OneDrive Logs
-- folder, machine-tagged (both Macs write these constantly — sharing
-- one file would mean OneDrive conflict copies). 6.98.0: the task
-- history file (and the 💬 auto-comment knob, now a profile-overridable
-- config) went to modules/task_creator.lua with the rest of the creator.

-- 🔍 THE OCR LOG AND ITS SHORTCUT NAME MOVED OUT in 6.105.0, to
-- modules/ocr_engine.lua — the CSV path, the "HS OCR" Apple Shortcut, the
-- per-machine adoption, the two pickers and the Finder tagging travel
-- together. Only the clipboard watcher stayed (§3), because it is shared
-- with clipboard history; it calls the module through the registry.

-- =====================================================================
-- 0.3 HOTKEY CONFLICT SENTRY — warns in the Console at boot
-- =====================================================================
-- Every hs.hotkey.bind in this file passes through this wrapper, which
-- keeps a registry of registered combos and prints a Console warning:
--   • INTERNAL conflict — the same combo bound twice inside this
--     config. Nasty failure mode: the LATER binding silently wins and
--     the earlier feature's key just stops working. Now it announces
--     itself instead.
--   • KNOWN macOS default — the combo matches a stock system shortcut
--     (Spotlight, Spaces, screenshots…). The system usually wins;
--     the warning names it so a dead key isn't a mystery.
-- HONEST LIMIT: other APPS' shortcuts aren't detectable — macOS has
-- no public API to enumerate them — so a clash with, say, a menu-bar
-- app can only be found by noticing the key misbehaves. The boot
-- report says how many combos were checked.
local hotkeyRegistry = {}
_G.hotkeyBoundCount, _G.hotkeyConflictCount = 0, 0

-- 6.77.0 — the handlers themselves, kept a second time so that a Mac
-- whose Carbon hotkey layer is dead can still run them from the event
-- tap. See core/hyper_key.lua. Only STANDALONE binds land here: migrated
-- ones return above this point, and modal bindings never come through
-- hs.hotkey.bind at all — which is what keeps a bare ⇪-modal letter out
-- of a table that is consulted when ⇪ is NOT held.
_G.globalDispatch = {}

local knownSystemCombos = {
    ["cmd+space"]        = "Spotlight search",
    ["alt+cmd+space"]    = "Finder search window",
    ["ctrl+space"]       = "input source switching (if enabled)",
    ["alt+ctrl+space"]   = "input source switching (if enabled)",
    ["cmd+tab"]          = "app switcher (macOS reserves this)",
    ["cmd+shift+3"]      = "screenshot (full screen)",
    ["cmd+shift+4"]      = "screenshot (selection)",
    ["cmd+shift+5"]      = "screenshot & recording menu",
    ["ctrl+up"]          = "Mission Control",
    ["ctrl+down"]        = "App windows (App Exposé)",
    ["ctrl+left"]        = "previous Space",
    ["ctrl+right"]       = "next Space",
    ["cmd+shift+q"]      = "log out",
    ["ctrl+cmd+q"]       = "lock screen",
    ["ctrl+cmd+space"]   = "emoji & symbols picker",
}

local function normalizeCombo(mods, key)
    local m = {}
    for _, x in ipairs(mods or {}) do table.insert(m, tostring(x):lower()) end
    table.sort(m)
    return table.concat(m, "+") .. "+" .. tostring(key):lower()
end
-- The fallback dispatcher files a live keystroke under the same name.
_G.globalCombo = normalizeCombo

-- =====================================================================
-- 0.4 HYPER MIGRATION MAP (6.19.0) — every shortcut moves to Caps Lock
-- =====================================================================
-- 6.19.0 moved EVERY shortcut in this config onto the hyper key. Rather
-- than editing 33 scattered hs.hotkey.bind call sites (33 chances to
-- typo something), each old combo is listed here once with its new hyper
-- home, and the wrapper below re-routes it. One table = the whole
-- keymap, which is also what makes the boot-time self-checks possible.
--
-- TWO TIERS, so nothing collides. Flattening all 33 onto bare letters
-- was impossible: V, C and O each had three different meanings, and
-- F/←/→ had two apiece.
--   ⇪ + key       → the 25 primary tools
--   ⇪ + ⇧ + key   → secondary/"edit" variants + popup nudging
--
-- KEY = the OLD combo, normalized (mods sorted alphabetically, lower
-- case). VALUE = { new modifiers, new key } held WITH Caps Lock.
-- Both halves are verified at boot: a key listed here that never gets
-- claimed prints a warning (means the map has a typo and the old global
-- shortcut silently survived), and two entries landing on the same hyper
-- combo print a conflict.
_G.hyperKeyMap = {
    -- ---- Asana (⇪ tier 1) ----
    ["alt+cmd+ctrl+a"]       = { {},        "a"     },  -- format Asana URL
    ["alt+cmd+ctrl+b"]       = { {},        "b"     },  -- browse teams
    ["alt+cmd+ctrl+c"]       = { {},        "c"     },  -- comment on task
    ["alt+cmd+ctrl+t"]       = { {},        "t"     },  -- create task (6.86.0: the labeled form)
    ["alt+cmd+ctrl+l"]       = { {},        "l"     },  -- list tasks
    -- ---- Clipboard / OCR / Activity ----
    -- 6.57.0 — the two clipboard entries were REMOVED here. They existed
    -- to redirect ⌃⌥⌘V / ⌃⌥⌘⇧V onto ⇪V / ⇪⇧V, and 6.55.0 moved clipboard
    -- history into its own module which claims those hyper keys DIRECTLY.
    -- Leaving the map entries behind meant two claims on one key for the
    -- SAME feature — a HYPER CONFLICT warning about a conflict that was
    -- not real, which is its own kind of harm: it teaches you to ignore
    -- the warnings that are.
    -- 6.105.0 — THE TWO OCR ENTRIES WERE REMOVED HERE, for exactly the
    -- reason the clipboard pair above was removed in 6.57.0. The engine
    -- is modules/ocr_engine.lua now and claims ⇪O and ⇪⇧O directly.
    -- Leaving the map entries behind would mean two claims on one key for
    -- the SAME feature — a HYPER CONFLICT warning about a conflict that
    -- is not real, which teaches you to ignore the warnings that are.
    ["alt+cmd+ctrl+shift+c"] = { {"shift"}, "c"     },  -- copy-on-select toggle
    ["alt+cmd+shift+0"]      = { {},        "0"     },  -- activity tracker
    -- ---- Trackers ----
    ["alt+ctrl+shift+f"]     = { {},        "f"     },  -- file tracker
    ["alt+ctrl+shift+u"]     = { {},        "u"     },  -- update tracker
    -- ---- Autocorrect ----
    ["alt+cmd+ctrl+s"]       = { {},        "s"     },  -- toggle
    ["alt+cmd+ctrl+z"]       = { {},        "z"     },  -- undo & learn
    -- ---- Window arranger ----
    -- Arrows become spatial: ←/→ halves, ↑ fill, ↓ put it back. That
    -- reads better than the old ⌃⌥F/⌃⌥M letters and frees F for Files.
    ["alt+ctrl+left"]        = { {},        "left"  },  -- left half
    ["alt+ctrl+right"]       = { {},        "right" },  -- right half
    ["alt+ctrl+f"]           = { {},        "up"    },  -- fill screen
    ["alt+ctrl+m"]           = { {},        "down"  },  -- restore prior frame
    ["alt+ctrl+v"]           = { {},        "\\"    },  -- split two windows
    -- 6.31.0: swapped back — bare ⇪W is the app summon (the one reached
    -- for constantly), and the documents list moved to ⇪⇧W. (That list
    -- belonged to document_watcher until 6.104.0 and now belongs to
    -- activity_tracker; the KEY never moved, which is what matters here.)
    ["alt+ctrl+w"]           = { {},        "w"     },  -- summon-an-app picker
    ["alt+cmd+ctrl+["]       = { {},        "["     },  -- monitor left
    ["alt+cmd+ctrl+]"]       = { {},        "]"     },  -- monitor right
    -- ---- Cheat sheet & custom entries ----
    ["alt+cmd+ctrl+/"]       = { {},        "/"     },  -- toggle cheat sheet
    ["alt+cmd+ctrl+="]       = { {},        "="     },  -- add entry
    ["alt+cmd+ctrl+-"]       = { {},        "-"     },  -- remove entry
    ["alt+cmd+ctrl+e"]       = { {},        "e"     },  -- edit entry
    -- ---- Diagnostics (⇪⇧ tier 2) ----
    ["alt+cmd+ctrl+shift+d"] = { {"shift"}, "d"     },  -- diagnostic report
    -- ---- App peek ----
    ["alt+cmd+ctrl+p"]       = { {},        "p"     },  -- hide/show front app
    -- ---- Popup nudging (⇪⇧ tier 2 — rarely used, keeps tier 1 free) ----
    ["alt+cmd+ctrl+r"]       = { {"shift"}, "r"     },  -- reset nudge offset
    ["alt+cmd+ctrl+up"]      = { {"shift"}, "up"    },
    ["alt+cmd+ctrl+down"]    = { {"shift"}, "down"  },
    ["alt+cmd+ctrl+left"]    = { {"shift"}, "left"  },
    ["alt+cmd+ctrl+right"]   = { {"shift"}, "right" },
}

-- Queue, not immediate binding: the modal doesn't exist until §3.12, and
-- several features bind before that point. Everything is collected here
-- and flushed in one deterministic pass at the very end of the file.
_G.hyperMigrations     = {}   -- ordered list of queued bindings
_G.hyperMigrationsSeen = {}   -- which map entries actually matched

-- Migrated call sites get this back instead of a real hs.hotkey object.
-- Nothing in this file uses the return value, but returning a bare nil
-- would turn any future `local hk = hs.hotkey.bind(...)  hk:disable()`
-- into a crash — so hand back something harmless that answers the usual
-- hotkey methods.
-- _G. rather than a local: the main chunk is at Lua's hard ceiling of
-- 200 locals, and one more here fails to compile outright.
_G.hyperBindStub = function()
    local s = {}
    function s:enable()  return self end
    function s:disable() return self end
    function s:delete()  return self end
    return s
end

local hsHotkeyBindOriginal = hs.hotkey.bind
hs.hotkey.bind = function(mods, key, fn, releasedFn, repeatFn)
    local ok, combo = pcall(normalizeCombo, mods, key)
    local target = ok and _G.hyperKeyMap[combo] or nil
    if target then
        _G.hyperMigrationsSeen[combo] = true
        table.insert(_G.hyperMigrations, {
            from = combo, mods = target[1], key = target[2],
            fn = fn, releasedFn = releasedFn, repeatFn = repeatFn,
        })
        return _G.hyperBindStub()
    end
    if ok then
        _G.hotkeyBoundCount = _G.hotkeyBoundCount + 1
        if hotkeyRegistry[combo] then
            _G.hotkeyConflictCount = _G.hotkeyConflictCount + 1
            print("⚠️ HOTKEY CONFLICT inside init.lua: " .. combo
                .. " is bound TWICE — the later binding wins, the earlier feature's key is now dead")
        end
        hotkeyRegistry[combo] = true
        if knownSystemCombos[combo] then
            print("⚠️ HOTKEY may clash with macOS: " .. combo .. " = "
                .. knownSystemCombos[combo]
                .. " — the system usually wins (System Settings → Keyboard → Keyboard Shortcuts)")
        end
    end
    -- 🚨 6.53.0 — A BAD KEY NAME MUST COST ONE SHORTCUT, NOT THE CONFIG.
    -- hs.hotkey.bind THROWS on a key macOS has no code for ("Command",
    -- "esc " with a space, a typo in an ✏️ EDIT HERE block). A module's
    -- bad key was always survivable because §1.12 runs every setup()
    -- inside a pcall — but init.lua's OWN binds sit at top level in the
    -- stretch that runs BEFORE the loader, so one typo there took the
    -- entire config down: no hotkeys, no modules, no cheat sheet, and an
    -- explanation only in a Console you were not looking at.
    -- Now the throw is caught, named, and answered with the same inert
    -- stub the migration path already returns, so the caller's
    -- :enable()/:delete() still work and everything else boots.
    local bound, err = nil, nil
    local okBind = pcall(function()
        bound = hsHotkeyBindOriginal(mods, key, fn, releasedFn, repeatFn)
    end)
    if okBind and bound then
        -- Recorded only when the combo normalized cleanly, because that
        -- string is the key the tap will look it up under.
        if ok then
            _G.globalDispatch[combo] = { pressed = fn, released = releasedFn,
                                         repeated = repeatFn }
        end
        return bound
    end
    err = tostring(key)
    _G.hotkeyRejectedCount = (_G.hotkeyRejectedCount or 0) + 1
    _G.hotkeyRejected = _G.hotkeyRejected or {}
    table.insert(_G.hotkeyRejected, tostring(ok and combo or err))
    print("⚠️ HOTKEY REJECTED: " .. tostring(ok and combo or err)
          .. " — macOS has no such key, so THAT shortcut is off. Everything "
          .. "else still loaded. Check the key name where it is bound.")
    pcall(function() _G.diag.err("hotkey rejected: " .. tostring(ok and combo or err)) end)
    return _G.hyperBindStub()
end

-- =====================================================================
-- 1. GLOBAL STATE INITIALIZATION
-- =====================================================================
_G.choosers = {}

_G.asanaTaskHistory = {}  -- populated from disk by modules/task_creator.lua; stubbed so ⇪space search never sees nil

-- =====================================================================
-- 1.5 POPUP POSITIONING — EDIT YOUR HOTKEYS HERE
-- =====================================================================
-- Every popup chooser (Clipboard, Task Creator, OCR, App Tracker, Asana
-- Dashboard) is positioned automatically — no manual monitor picking.
-- Screen is resolved in this order, every time a popup opens or moves:
--   1. the FRONTMOST APPLICATION's window
--   2. otherwise, whatever window currently has keyboard focus
--   3. otherwise, the main screen
-- On top of that, you can nudge the exact spot with the keyboard
-- (hs.chooser has no title bar, so it can't be dragged like a normal
-- window):
--   • mods + arrow keys     → nudge popup position by nudgeStep pixels
--   • mods + reset          → clear the nudge offset
--
-- If any key conflicts with another app, just change it in this table.
-- If a chooser is already open when you press a nudge/reset key, it
-- jumps to the new position immediately.
local popupScreenKeys = {
    mods       = {"ctrl", "alt", "cmd"},   -- modifier combo for all keys below
    reset      = "R",                       -- clear nudge offset
    nudgeUp    = "Up",                      -- nudge popup up
    nudgeDown  = "Down",                    -- nudge popup down
    nudgeLeft  = "Left",                    -- nudge popup left
    nudgeRight = "Right",                   -- nudge popup right
}
local popupNudgeStep = 50  -- pixels moved per arrow-key tap; edit freely.
                            -- Hold the key down to walk it further.

-- ✏️ PANEL TRANSLUCENCY (6.10.3) — one number for the canvas panels:
-- the dashboard legend strip (§6) and the Task Creator draft mirror
-- (§4). 6.32.0: the CHEAT SHEET no longer uses this — it is the one
-- panel you read long-form, so it has its own, more see-through
-- setting (cheatSheet.alpha, top of §1.6) over a darker background.
-- 1.0 = solid, lower = more
-- see-through; below ~0.65 the white text gets hard to read over
-- bright windows. (The picker LISTS are native macOS panels with no
-- opacity API — this can't affect them; see the 6.10.3 note above.)
local panelAlpha = 0.90

_G.popupOffset = { x = 0, y = 0 }  -- pixel offset from nudging, stacks on
                                    -- top of wherever the popup would
                                    -- otherwise appear

-- Which screen should a popup use as its BASE position (before nudging)?
--   1. the monitor holding the FRONTMOST APPLICATION's window
--   2. otherwise, whatever window currently has keyboard focus
--   3. otherwise, the main screen
-- Checking the frontmost app directly (rather than only focusedWindow)
-- matters when the two diverge — e.g. a background window somehow holds
-- keyboard focus while a different app is what's actually frontmost.
-- 6.27.1: an explicit screen wins over everything below.
-- App Lock needs this. Hiding a locked app makes macOS fall back to
-- whatever app was in front BEFORE — often on another monitor — so by
-- the time the PIN prompt opens, "the frontmost app" is the wrong app on
-- the wrong screen and the prompt appears back where you came from.
-- App Lock captures the locked app's screen BEFORE hiding it and parks
-- it here. Always nil unless something is mid-flight.
_G.popupScreenOverride = nil

local function resolveBaseScreen()
    if _G.popupScreenOverride then return _G.popupScreenOverride end
    local ok, frontApp = pcall(hs.application.frontmostApplication)
    if ok and frontApp then
        local win = frontApp:focusedWindow() or frontApp:mainWindow()
        if win then
            local ok2, scr = pcall(function() return win:screen() end)
            if ok2 and scr then return scr end
        end
    end

    local ok3, focused = pcall(hs.window.focusedWindow)
    if ok3 and focused then
        local ok4, scr = pcall(function() return focused:screen() end)
        if ok4 and scr then return scr end
    end

    return hs.screen.mainScreen()
end

-- hs.chooser:show() accepts an optional top-left point, which is what
-- lets us place the popup on the resolved screen — and, combined with
-- popupOffset, what lets arrow-key nudging move it anywhere from there.
local function chooserTopLeft(chooser, screen)
    local f = screen:frame()
    local pct = 40  -- hs.chooser default width is 40% of the screen
    local ok, w = pcall(function() return chooser:width() end)
    if ok and type(w) == "number" and w > 0 and w <= 100 then pct = w end
    local width = f.w * (pct / 100)
    local x = f.x + (f.w - width) / 2 + _G.popupOffset.x
    local y = f.y + (f.h * 0.2)        + _G.popupOffset.y
    return hs.geometry.point(x, y)
end

-- Use this instead of chooser:show() everywhere below.
-- The resolved screen & point are recorded in _G.lastPopupPlacement so
-- companion drawings (the dashboard's legend strip, section 6) can
-- position themselves from the SAME placement — resolving the screen
-- twice can disagree when focus shifts as the popup opens, which put
-- the legend on a different monitor than its picker.
local function showPopup(chooser)
    local screen = resolveBaseScreen()
    if screen then
        local pt = chooserTopLeft(chooser, screen)
        _G.lastPopupPlacement = { screen = screen, point = pt }
        chooser:show(pt)
    else
        _G.lastPopupPlacement = nil
        chooser:show()
    end
end

-- Repositions any currently-visible popup at its (possibly new) spot.
-- Returns true if it found something to move, so callers (like nudge)
-- can tell whether their change had anything visible to apply to.
local function repositionVisiblePopups()
    local movedAny = false
    for _, c in pairs(_G.choosers) do
        if c.isVisible and c:isVisible() then
            c:hide()
            showPopup(c)
            movedAny = true
        end
    end
    -- The Asana dashboard's color legend strip (section 6) and the
    -- Task Creator's draft mirror (section 4) ride along with their
    -- pickers when nudged
    if movedAny and _G.asanaLegendSync then pcall(_G.asanaLegendSync) end
    if movedAny and _G.taskMirrorSync then pcall(_G.taskMirrorSync) end
    return movedAny
end

-- Nudge: shift the popup position by popupNudgeStep pixels. If a popup
-- is currently open it snaps to the new spot immediately; if nothing is
-- open, the offset is saved silently for the next popup you open — an
-- alert confirms the running offset so it's not invisible when nothing
-- is on screen to show it moving.
local function nudgePopup(dx, dy)
    _G.popupOffset.x = _G.popupOffset.x + dx
    _G.popupOffset.y = _G.popupOffset.y + dy
    local moved = repositionVisiblePopups()
    if not moved then
        hs.alert.show(string.format("↕ Popup offset: %d, %d — open a popup to see it",
            _G.popupOffset.x, _G.popupOffset.y))
    end
end

-- bindNudge wires the SAME function as both pressedfn and repeatfn, so
-- a quick tap nudges once, and holding the key auto-repeats the nudge
-- at the OS's key-repeat rate (System Settings → Keyboard → Key Repeat)
-- for as long as it's held — no need to tap repeatedly.
local function bindNudge(key, dx, dy)
    local function fn() nudgePopup(dx, dy) end
    hs.hotkey.bind(popupScreenKeys.mods, key, fn, nil, fn)
end

bindNudge(popupScreenKeys.nudgeUp,    0, -popupNudgeStep)
bindNudge(popupScreenKeys.nudgeDown,  0,  popupNudgeStep)
bindNudge(popupScreenKeys.nudgeLeft, -popupNudgeStep, 0)
bindNudge(popupScreenKeys.nudgeRight, popupNudgeStep, 0)

-- Reset: clears the nudge offset — back to pure automatic placement
hs.hotkey.bind(popupScreenKeys.mods, popupScreenKeys.reset, function()
    _G.popupOffset = { x = 0, y = 0 }
    hs.alert.show("🖥 Popup offset reset — following frontmost app")
    repositionVisiblePopups()
end)

-- =====================================================================
-- 1.6 SHORTCUT CHEAT SHEET — ⇪/ to toggle · ⇪= to add entries
-- =====================================================================
-- The 721 lines that were here now live in core/cheatsheet.lua, and run
-- at exactly this point, so the boot order is unchanged.
--
-- Not a modules/ file: every module registers its cheat sheet group while
-- the §1.12 loader runs, so _G.__cheatSheet must already exist when the
-- loader starts. A loader-managed module could not promise that.
--
-- If it fails, ⇪/ and the custom-shortcut editor are off for the session
-- and everything else still boots. Modules call the registration helper
-- defensively, so a missing cheat sheet costs you the panel, not the keys.
-- =====================================================================
-- 🚨 SHOWING A CANVAS CAN THROW, AND IT IS NOT OUR BUG — 6.56.0
-- =====================================================================
-- Ordering any window on screen notifies every AppKit observer —
-- including ANOTHER app's popup (Safari's URL completion, Spotlight)
-- living behind an NSRemoteView. Mid-transition, ITS assertion throws
-- into OUR canvas:show(), and an unprotected throw abandons the rest of
-- the open sequence, leaving a phantom half-open panel. So: catch it,
-- retry once next run-loop turn (a timing collision, not a permanent
-- state), and if it still refuses, say so and let the caller clean up.
-- Full story: NEW IN 6.56.0.
_G.canvasShowTimers = _G.canvasShowTimers or {}
function _G.showCanvasSafely(canvas, label)
    if not canvas then return false end
    local ok = pcall(function() canvas:show() end)
    if ok then return true end
    -- One retry, a run loop turn later.
    local t = hs.timer.doAfter(0.05, function()
        local ok2 = pcall(function() canvas:show() end)
        if ok2 then return end
        print("⚠️ " .. tostring(label or "canvas") .. ": macOS refused to show "
              .. "it twice — usually another app's popup (Safari's URL "
              .. "completion, Spotlight) was mid-transition. Press the key "
              .. "again.")
        if _G.notices then
            _G.notices.record("runtime", tostring(label or "canvas"),
                              "AppKit refused to order the window on screen")
            _G.notices.tell("A panel would not open",
                            tostring(label or "canvas") .. " — press the key again",
                            { key = "canvas:" .. tostring(label), every = 300 })
        end
    end)
    -- HELD: an unreferenced timer is collected and never fires.
    _G.canvasShowTimers[#_G.canvasShowTimers + 1] = t
    while #_G.canvasShowTimers > 8 do table.remove(_G.canvasShowTimers, 1) end
    return false
end

-- 6.88.0 — hs.alert draws with hs.canvas underneath, so ITS show hits
-- the same throw. Wrapped ONCE, here: every alert everywhere survives.
--
-- 🚨 6.100.1 — SURVIVING WAS NOT ENOUGH: THE PHANTOM PILL. The throw
-- lands MID-draw — hs.alert has already ordered its rounded frame on
-- screen when the other app's assertion throws back through it, before
-- the text is drawn and before the fade-out timer is armed. The pcall
-- saved the config and kept the wreckage: an empty black pill with a
-- white border that never fades and takes no clicks, because an alert
-- is not a window anything can close. LL met one on 08-18-26, hours
-- after "an alert could not draw" hit the Console. So the catch now
-- cleans up and retries, the showCanvasSafely way: one run-loop turn
-- later, sweep (below), then show the same alert again.
-- ⚖️ THE SWEEP'S COST IS REAL: hs.alert.closeAll also closes a healthy
-- alert sharing the screen at that instant. Accepted — alerts live two
-- seconds, phantoms live forever.
_G.rawAlertShow = _G.rawAlertShow or (hs.alert and hs.alert.show)

-- The sweep, also yours to run by hand: _G.phantom() in the Console
-- clears a stuck pill any time one survives the automatic path.
-- closeAll(0) reaches a wreck hs.alert managed to register before the
-- throw; the double collectgarbage reaches one it did NOT — a canvas
-- nobody references is torn down by its __gc, which is usually the
-- gotcha that makes panels vanish and here is the cleanup crew. Still
-- there after both? Reload Config resets the Lua state, which clears
-- it for certain.
function _G.phantom(quiet)
    pcall(function() hs.alert.closeAll(0) end)
    collectgarbage("collect"); collectgarbage("collect")
    if not quiet then
        hs.alert.show("🧹 swept — tracked alerts closed, stranded canvases"
                      .. " collected. Still on screen? Menu bar hammer →"
                      .. " Reload Config.")
    end
end

if _G.rawAlertShow then hs.alert.show = function(...)
    local okA, r = pcall(_G.rawAlertShow, ...)
    if okA then return r end
    print("⚠️ an alert could not draw — another app's popup was"
          .. " mid-transition. Sweeping the half-drawn frame and retrying…")
    local args = table.pack(...)
    -- pcall'd: in a world where even hs.timer is broken, this wrapper
    -- still must never throw into whoever asked for an alert.
    pcall(function()
        local t = hs.timer.doAfter(0.05, function()
            _G.phantom(true)
            local ok2 = pcall(_G.rawAlertShow, table.unpack(args, 1, args.n))
            if not ok2 then
                print("⚠️ …the retry failed too. If an empty pill is stuck"
                      .. " on screen: _G.phantom() — and Reload Config if"
                      .. " it survives that.")
            end
        end)
        -- HELD, same shelf and same reason as the canvas retries above.
        _G.canvasShowTimers[#_G.canvasShowTimers + 1] = t
        while #_G.canvasShowTimers > 8 do table.remove(_G.canvasShowTimers, 1) end
    end)
end end -- alert wrap (6.88.0, sweep-and-retry 6.100.1)

-- =====================================================================
-- 🖐 DRAGGABLE CANVAS PANELS (6.67.0)
-- =====================================================================
-- LL: "Great pop-up. But I can't drag the window. Same with shortcuts
-- window. Both should be moveable."
--
-- An hs.canvas is not an NSWindow with a title bar — there is nothing to
-- grab. Dragging has to be built: notice the press, follow the pointer,
-- move the panel. This is that, once, for every panel rather than twice
-- by hand.
--
-- 🚨 WHY AN EVENTTAP AND NOT canvas mouseMove. A canvas only reports
-- movement while the pointer is INSIDE it. Drag faster than the panel
-- redraws — which is most drags — and the pointer leaves, the events
-- stop, and the panel is stranded halfway. So the press is caught on the
-- canvas and the DRAG is followed by a global eventtap, which sees the
-- pointer wherever it goes.
--
-- ⚠️ AND AN EVENTTAP IS THE MOST DANGEROUS OBJECT IN THIS CONFIG, so:
--   · it starts on mouseDown and stops on mouseUp;
--   · a WATCHDOG stops it after dragMaxSecs no matter what, because a
--     mouseUp delivered to another process is a mouseUp we never see;
--   · it returns false, so the events still reach everything else —
--     this observes the drag, it does not swallow it;
--   · only ONE drag can be live at a time, and starting a second stops
--     the first.
-- A tap left running is a tap watching every mouse event you make for
-- the rest of the session.
--
-- ⚖️ THE COST, AND IT IS REAL: a panel that can be grabbed is a panel
-- that CAPTURES CLICKS. The cheat sheet used to let clicks fall through
-- to the window behind it. It cannot do both, and being able to move it
-- is what was asked for.
_G.dragMaxSecs = 20
_G.dragTap, _G.dragGuard, _G.dragging = nil, nil, nil

local function dragStop(why)
    if _G.dragTap   then pcall(function() _G.dragTap:stop()   end) end
    if _G.dragGuard then pcall(function() _G.dragGuard:stop() end) end
    _G.dragTap, _G.dragGuard, _G.dragging = nil, nil, nil
    if why and _G.diag then _G.diag.say("drag", "ended (" .. why .. ")") end
end
_G.dragStop = dragStop

-- onDrop(frame) is called when the drag finishes, so a caller can
-- REMEMBER where you put the panel. Without it a dragged panel snaps
-- back to its computed position the next time it is drawn — and the cheat
-- sheet redraws on every keystroke you type into it.
function _G.makeCanvasDraggable(canvas, label, onDrop)
    if not canvas then return false end
    local okEv = pcall(function() canvas:canvasMouseEvents(true, true, false, false) end)
    if not okEv then return false end
    local okCb = pcall(function()
        canvas:mouseCallback(function(cv, ev)
            if ev ~= "mouseDown" then
                if ev == "mouseUp" then dragStop("mouseUp on the panel") end
                return
            end
            dragStop(nil)                       -- never two at once
            local okM, m0 = pcall(hs.mouse.absolutePosition)
            local okF, f0 = pcall(function() return cv:frame() end)
            if not (okM and m0 and okF and f0) then return end
            _G.dragging = { canvas = cv, m0 = m0, f0 = f0, label = label }

            -- 🚨 WATCHDOG FIRST, THEN THE TAP — the same ordering the
            -- Mouse Grid and the pomodoro use. Armed before the thing it
            -- protects exists, so a throw in between cannot leave a
            -- global mouse tap running with nothing scheduled to stop it.
            _G.dragGuard = hs.timer.doAfter(_G.dragMaxSecs, function()
                dragStop("watchdog — no mouseUp arrived")
            end)

            local okTap, tap = pcall(hs.eventtap.new, {
                hs.eventtap.event.types.leftMouseDragged,
                hs.eventtap.event.types.leftMouseUp,
            }, function(e)
                local d = _G.dragging
                if not d then return false end
                local t = e:getType()
                if t == hs.eventtap.event.types.leftMouseUp then
                    local f
                    pcall(function() f = d.canvas:frame() end)
                    dragStop("mouseUp")
                    if f and onDrop then pcall(onDrop, f) end
                    return false
                end
                local okNow, m = pcall(hs.mouse.absolutePosition)
                if not (okNow and m) then return false end
                pcall(function()
                    d.canvas:topLeft({ x = d.f0.x + (m.x - d.m0.x),
                                       y = d.f0.y + (m.y - d.m0.y) })
                end)
                return false        -- observe, never swallow
            end)
            if not (okTap and tap) then
                dragStop("could not create the drag tap")
                return
            end
            _G.dragTap = tap
            pcall(function() tap:start() end)
        end)
    end)
    return okCb
end

-- Keep a panel on a real screen. A dragged position is remembered, and a
-- remembered position outlives the display it was set on: unplug the
-- monitor it was dragged to and the panel would otherwise be restored to
-- coordinates that no longer exist, i.e. invisibly off-screen with no
-- way to get it back.
function _G.clampToScreen(pt, w, h)
    if not pt then return nil end
    local best
    pcall(function()
        for _, scr in ipairs(hs.screen.allScreens() or {}) do
            local f = scr:fullFrame()
            if pt.x + (w or 0) > f.x and pt.x < f.x + f.w
               and pt.y + (h or 0) > f.y and pt.y < f.y + f.h then
                best = f; break
            end
        end
        if not best and hs.screen.mainScreen() then
            best = hs.screen.mainScreen():fullFrame()
        end
    end)
    if not best then return pt end
    return {
        x = math.max(best.x, math.min(pt.x, best.x + best.w - (w or 0))),
        y = math.max(best.y, math.min(pt.y, best.y + best.h - (h or 0))),
    }
end

-- =====================================================================
-- 🤝 SHARED ARBITRATION (§0.5) — core/coexist.lua
-- =====================================================================
-- Panel stacking, who gets Esc, the shared typing-injection guard and
-- clipboard borrowing. Lifted out of init.lua in 6.69.0 when it crossed
-- the 4,000-line ceiling; see that file's header for what each one is
-- for and why they belong together.
--
-- LOADED HERE, BEFORE EVERYTHING THAT USES IT. The cheat sheet asks
-- _G.routeEscape, the pomodoro asks _G.panelLevel, autocorrect and the
-- text expander ask _G.withInjection — all of which set up later. A
-- failure is degradation, not death: every caller checks the global
-- exists first, so a broken copy costs the arbitration and not the Mac.
local coOK, coErr = pcall(function()
    local path = hs.configdir .. '/core/coexist.lua'
    local chunk, loadErr = loadfile(path)
    if not chunk then error(loadErr or ('cannot read ' .. path), 0) end
    chunk()({})
end)
if not coOK then
    print('⚠️ core/coexist.lua failed to load — panels fall back to one shared '
          .. 'level, Esc goes to whichever binding was enabled last, and the '
          .. 'two typing watchers stop standing down for each other. '
          .. tostring(coErr))
    if _G.notices then
        _G.notices.record('boot', 'core/coexist.lua', tostring(coErr))
    end
end


local csOK, csErr = pcall(function()
    local path = hs.configdir .. '/core/cheatsheet.lua'
    local chunk, loadErr = loadfile(path)
    if not chunk then error(loadErr or ('cannot read ' .. path), 0) end
    -- 6.65.0 — THE RETURNED TABLE IS NOW PUBLISHED. It used to be dropped
    -- on the floor here (the file returns it so tests can drive the real
    -- namespace). Unified Search's 🔧 tools source (⇪⇧/, the Tool Picker's
    -- old key) searches the SAME assembled groups this sheet draws, which
    -- is the only way the two can never disagree about what exists — and it
    -- cannot reach them without this line.
    -- Assigned, not merged: nothing else owns this name.
    _G.cheatSheet = chunk()({
        logsDir           = logsDir,
        panelAlpha        = panelAlpha,
        popupScreenKeys   = popupScreenKeys,
        resolveBaseScreen = resolveBaseScreen,
        showPopup         = showPopup,
        warnWriteFailed   = warnWriteFailed,
        adoptLegacyFile   = adoptLegacyFile,
    })
end)
if not csOK then
    print('⚠️ core/cheatsheet.lua failed to load — ⇪/ and the shortcut editor '
          .. 'are OFF for this session. Every shortcut itself still works. '
          .. tostring(csErr))
end

-- =====================================================================
-- 1.11 DIAGNOSTICS — ⇪⇧D writes the report I need to debug anything
-- =====================================================================
-- The 287 lines that were here now live in core/diagnostics.lua. They
-- run at exactly this point, so the boot order is unchanged.
--
-- Not a modules/ file: the module loader in §1.12 runs last and logs
-- through _G.diag itself, so diagnostics cannot be loader-managed
-- without the loader depending on something it has not loaded yet.
--
-- FAILURE IS SURVIVABLE ON PURPOSE. Every section of this config calls
-- _G.diag.say/warn/err. If this file is missing or raises, the NO-OP
-- stand-in installed earlier stays in place and the config still boots;
-- you lose ⇪⇧D and the trail, not the Mac.
local diagOK, diagErr = pcall(function()
    local path = hs.configdir .. '/core/diagnostics.lua'
    local chunk, loadErr = loadfile(path)
    if not chunk then error(loadErr or ('cannot read ' .. path), 0) end
    chunk()({ logsDir = logsDir, hostTag = hostTag, asanaEnabled = asanaEnabled })
end)
if not diagOK then
    print('⚠️ core/diagnostics.lua failed to load — ⇪⇧D and the diagnostic '
          .. 'trail are OFF for this session. Everything else still works. '
          .. tostring(diagErr))
end


-- =====================================================================
-- 2. UTILITY
-- =====================================================================
local function formatDuration(seconds)
    if seconds < 60 then return seconds .. "s" end
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    if mins < 60 then return mins .. "m " .. secs .. "s" end
    local hrs = math.floor(mins / 60)
    return hrs .. "h " .. (mins % 60) .. "m"
end

-- 📋 CLIPBOARD HISTORY MOVED OUT in 6.55.0 — loading, saving, the
-- corrupt-file backup and the verify-before-write guard all now live in
-- modules/clipboard_history.lua. They used to run here, before the
-- module loader, where an error took the whole config down instead of
-- costing one feature.

-- 🔍 THE OCR ENGINE MOVED OUT in 6.105.0, to modules/ocr_engine.lua —
-- the boot check for the "HS OCR" Apple Shortcut, the QWERTY strip, the
-- clipboard-image path, the whole file-tagging route (pasteboard shape
-- guessing, /.file/ resolution, the out-of-process Finder scripting) and
-- the two pickers, about five hundred lines of it. It was the last large
-- feature still ABOVE the module loader, where an error in it takes the
-- entire config down rather than costing one feature — and it is the
-- code that talks to Finder over Apple Events, which is the one thing
-- here with a history of aborting the app (see 6.65.1).
--
-- What did NOT move is the clipboard watcher in §3: one timer, one
-- changeCount, choosing between copied image files, a raw image and
-- text. It calls ocr.clipboardFiles / ocr.tagFiles / ocr.image through
-- the service registry now.

-- =====================================================================
-- 3. BACKGROUND MONITORING
-- =====================================================================
-- ✏️ Clipboard history size — how many copied texts to keep. Each new
-- copy is checked against the whole list: an item you've copied before
-- moves to the front (fresh timestamp) instead of occupying two slots.
-- Items over ~1 MB are left out of history (they'd bloat the JSON file
-- that gets rewritten on every copy) — a console line notes the skip.

local lastChangeCount = hs.pasteboard.changeCount()
_G.clipboardTimer = hs.timer.doEvery(0.5, function()
    local currentChangeCount = hs.pasteboard.changeCount()
    if currentChangeCount ~= lastChangeCount then
        lastChangeCount = currentChangeCount

        -- 📋 6.69.0 — SOMEONE BORROWED THE CLIPBOARD. The text expander
        -- pastes multi-line snippets and puts your clipboard straight
        -- back; both changes land inside one 0.5s poll, so what we would
        -- see here is your ORIGINAL entry arriving as if freshly copied.
        -- Filing it again reorders the history you were about to use.
        -- The counter is still advanced above, so the NEXT real copy is
        -- seen normally.
        if hs.timer.secondsSinceEpoch() < (_G.pasteboardSuppressUntil or 0) then
            return
        end

        -- Copied image FILES take priority (6.11.0): OCR + tag each
        -- one, and skip the image/text handling for this clipboard
        -- change (a Finder file-copy would otherwise just deposit the
        -- file's pathname into text history).
        -- 6.105.0 — through the registry, because the engine is a module
        -- now. has() before call() on the FIRST of the three: if the
        -- module did not load there is nothing to ask about copied image
        -- files, and the text path below must still run. A clipboard that
        -- stops remembering what you copied because an OCR module failed
        -- would be a bad trade.
        local copiedImageFiles = {}
        if _G.service.has("ocr.clipboardFiles") then
            copiedImageFiles = _G.service.call("ocr.clipboardFiles") or {}
        end
        if #copiedImageFiles > 0 then
            print("🏷 OCR tag: " .. #copiedImageFiles .. " copied image file(s) detected — running OCR on each")
            _G.service.call("ocr.tagFiles", copiedImageFiles)
        else
        local img = hs.pasteboard.readImage()
        if img then
            if _G.service.has("ocr.image") then
                _G.service.call("ocr.image", img)
            end
        else
            local text = hs.pasteboard.readString()
            if text and #text > 0 then
                -- 6.55.0 — the history itself now lives in
                -- modules/clipboard_history.lua. THIS WATCHER STAYED
                -- BEHIND on purpose: it is shared with image OCR, one
                -- timer reading one changeCount and choosing between
                -- copied image files, a raw image, and text. Two timers
                -- polling the same counter would race over which handled
                -- a change first. A missing provider prints once and
                -- OCR carries on.
                _G.service.call("clipboard.add", text)
            end
        end
        end  -- closes the copied-image-files branch (6.11.0)
    end
end)

-- =====================================================================
-- 3.12 HYPER KEY — Caps Lock IS ⌘⇧⌃⌥ (replaces Karabiner)
-- =====================================================================
-- WHAT THIS DOES: Caps Lock stops toggling caps and becomes a real
-- four-modifier chord. Holding Caps Lock and pressing K sends exactly
-- ⌘⇧⌃⌥K to whatever app is in front — the same keystroke you would get
-- by holding all four modifier keys down yourself.
--
-- WHY THAT MATTERS (changed in 6.18.0): before this, Caps Lock only
-- fired the handful of shortcuts listed below and every other key did
-- nothing. Now the chord is emitted for the whole keyboard, so hyper
-- works with ANY app that can be taught a ⌘⇧⌃⌥ shortcut — Raycast,
-- Alfred, Rectangle, Slack, Chrome extensions, your own app prefs —
-- without that app needing to know Hammerspoon exists. ⌘⇧⌃⌥ is the
-- conventional "hyper" chord precisely because nothing ships bound to
-- it, so it stays collision-free.
--
-- HOW, WITHOUT KARABINER: macOS has a built-in tool, /usr/bin/hidutil,
-- that remaps keys at the HID layer. We use it to turn Caps Lock into
-- F18 — a real key that exists in the keyboard spec but is on no Mac
-- keyboard, so nothing else ever sends it. Hammerspoon then treats F18
-- as the hyper trigger. No external app, nothing to install, and the
-- config travels in this file like everything else.
--
-- PERSISTENCE: a hidutil remap is wiped by a reboot. This file re-applies
-- it at every Hammerspoon launch, so it survives reboots without the
-- LaunchDaemon/LaunchAgent plist that guides normally tell you to create
-- (that route needs admin on a managed Mac — this route does not).
--
-- ⚠️ HONEST LIMIT — READ THIS: on macOS Sonoma and later, Apple began
-- requiring elevated rights for hidutil in some configurations. If that
-- applies on your work Mac, the remap will fail and the Console will say
-- so plainly at boot (it will NOT fail silently). Everything else in
-- this config keeps working; you just won't get the hyper key there.
-- Check the boot log for the 🎹 line to know which happened.
--
-- CAPS LOCK IS GONE while this is on — it no longer toggles capitals at
-- all. To get it back, either set hyperEnabled = false below and reload,
-- or run this in Terminal to clear the remap immediately:
--   hidutil property --set '{"UserKeyMapping":[]}'
--
-- ✏️ EDIT THESE — your hyper shortcuts:
do

local hyperEnabled = true   -- false = leave Caps Lock completely alone

-- OPTIONAL EXTRAS — empty by default (6.19.0).
--
-- hyper + key  →  run this function. Nothing ships here: the config's
-- own 33 shortcuts are mapped in §0.4, and every key they don't claim
-- forwards the raw ⌘⇧⌃⌥ chord. Add an entry only if you want a brand
-- new hyper shortcut of your own, e.g.
--     local hyperActions = {
--         g = function() hs.application.launchOrFocus("Google Chrome") end,
--     }
-- Anything listed here TAKES that key away from chord forwarding, and
-- the boot report's Hyper line will show the count shift.
local hyperActions = {}

-- ---- implementation ---------------------------------------------------
-- Caps Lock = HID usage 0x700000039, F18 = 0x70000006D. Both are
-- standard Apple HID keyboard usage codes, not invented values.
local HYPER_REMAP_ON  =
    '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,'
    .. '"HIDKeyboardModifierMappingDst":0x70000006D}]}'

_G.hyperModal = hs.hotkey.modal.new({}, nil)

-- F18 held = hyper active. Pressed enters the modal, released exits it,
-- so bindings only fire while Caps Lock is actually held down.
_G.hyperActive = false

-- 🚨 6.76.0 — TWO INDEPENDENT WAYS IN, BECAUSE ON LL'S WORK MAC THE ONLY
-- ONE IT HAD SILENTLY STOPPED WORKING. hs.hotkey is Carbon's
-- RegisterEventHotKey; hs.eventtap is a CGEventTap that sees the key
-- BEFORE Carbon does. A managed Mac can lose the first and keep the
-- second. The tap, the Carbon-free dispatcher and the self-test that
-- decides between them all live in core/hyper_key.lua — including the
-- full account of what that Mac did and what was ruled out.
--
-- 🔦 _G.hyperActive IS PUBLISHED (6.71.0) because ⇪ IS INVISIBLE FROM THE
-- OUTSIDE. Caps Lock is remapped to F18 at the HID level and turned into
-- a modal here, so anything watching the keyboard sees either a bare F18
-- or — for an unclaimed key — a synthetic ⌘⇧⌃⌥ chord. Neither of those
-- is what you pressed. The Key Caster would have drawn "⌘⇧⌃⌥X" for a key
-- you experienced as "⇪X", which is technically accurate and useless. One
-- boolean, set in the handlers that already know, beats every consumer
-- guessing.
--
-- The counters exist so the self-test can tell the two paths apart AFTER
-- the fact. Without them the only thing that could honestly be said about
-- the hyper key is how many shortcuts REGISTERED — which is precisely the
-- number that read "80" on a Mac where none of them worked.
_G.hyperCarbonPresses = 0    -- F18 arrived via hs.hotkey (Carbon)
_G.hyperTapPresses    = 0    -- F18 arrived via the event tap
_G.hyperDispatchEngaged = false   -- true once the dispatcher takes over

local function hyperEnter(via)
    if via == "carbon" then
        _G.hyperCarbonPresses = _G.hyperCarbonPresses + 1
    else
        _G.hyperTapPresses = _G.hyperTapPresses + 1
    end
    _G.hyperActive = true
    -- When the tap is doing the dispatching, the modal is deliberately
    -- NOT entered: its bindings have been proven dead, and entering it
    -- would only re-register hotkeys that cannot fire.
    if not _G.hyperDispatchEngaged then _G.hyperModal:enter() end
end

local function hyperExit()
    _G.hyperActive = false
    if not _G.hyperDispatchEngaged then _G.hyperModal:exit() end
end

hs.hotkey.bind({}, "F18",
    function() hyperEnter("carbon") end,
    function() hyperExit() end)

-- ---- path two: the event tap ------------------------------------------
-- Built in core/hyper_key.lua, along with the Carbon-free dispatcher and
-- the self-test that decides whether it is needed. Loaded at the very END
-- of this file: the dispatcher needs the complete shortcut table, and that
-- does not exist until _G.hyperFinalize() has run. These two travel as
-- globals because the main chunk is at Lua's 200-local ceiling.
_G.hyperEnter, _G.hyperExit = hyperEnter, hyperExit

-- ---- binding helper + conflict sentry for the hyper namespace --------
-- The §0.3 sentry only sees hs.hotkey.bind, so once shortcuts moved into
-- the modal they'd have become invisible to it — and a silently-dead
-- shortcut is exactly the failure this config exists to prevent. This is
-- the same guard, for the hyper keyspace.
_G.hyperBound = {}   -- normalized combo -> what claimed it
_G.hyperDispatch = {}   -- normalized combo -> the functions themselves
_G.hyperBoundCount, _G.hyperConflictCount = 0, 0

local function hyperCombo(mods, key)
    local m = {}
    for _, x in ipairs(mods or {}) do table.insert(m, tostring(x):lower()) end
    table.sort(m)
    if #m == 0 then return tostring(key):lower() end
    return table.concat(m, "+") .. "+" .. tostring(key):lower()
end

local function hyperBind(mods, key, pressedFn, releasedFn, repeatFn, source)
    local combo = hyperCombo(mods, key)
    if _G.hyperBound[combo] then
        _G.hyperConflictCount = _G.hyperConflictCount + 1
        print("⚠️ HYPER CONFLICT: ⇪" .. combo .. " is claimed twice ("
            .. tostring(_G.hyperBound[combo]) .. " vs " .. tostring(source)
            .. ") — the later one wins, the earlier is dead")
    end
    _G.hyperBound[combo] = source or "?"
    _G.hyperBoundCount = _G.hyperBoundCount + 1
    _G.hyperModal:bind(mods, key, pressedFn, releasedFn, repeatFn)
    -- 6.76.0 — the same three functions, kept a second time in a plain
    -- table. This costs one table entry per shortcut and it is what makes
    -- the Carbon-free fallback possible at all: every hyper shortcut in
    -- the config already goes through this one function, so recording
    -- them here cannot miss one the way a second registration list would.
    _G.hyperDispatch[combo] = {
        pressed = pressedFn, released = releasedFn, repeated = repeatFn,
        source = source or "?",
    }
end

-- Published for the Carbon-free dispatcher, which normalizes a live
-- keystroke into the string hyperBind filed the shortcut under. One
-- function, so the two can never disagree about what "⇪⇧D" is called.
_G.hyperCombo = hyperCombo

-- ---- the chord itself -------------------------------------------------
-- Every remaining key forwards ⌘⇧⌃⌥+key. hs.hotkey.modal has no
-- "catch-all" binding, so the keys are enumerated explicitly — this is
-- the documented way to do it and it is exhaustive over anything you can
-- realistically bind a shortcut to.
--
-- NOTE: the modal is deliberately NOT exited here. You keep holding Caps
-- Lock, so you can fire several chords in one hold; releasing Caps Lock
-- exits the modal via the F18 released-handler above.
_G.hyperMods = { "cmd", "shift", "ctrl", "alt" }

-- Delay between synthesised keydown and keyup, in microseconds.
-- 0 = as fast as possible. If some app ever misses a hyper keystroke,
-- raise this to 1000 or 10000 — that is the documented fix, and it is
-- the only knob worth turning here.
local HYPER_KEYSTROKE_DELAY = 0

local hyperForwardKeys = {}
for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    table.insert(hyperForwardKeys, c)
end
for d = 0, 9 do
    table.insert(hyperForwardKeys, tostring(d))
end
-- ⚠️ FUNCTION KEYS ARE OFF BY DEFAULT — this is deliberate, see 6.18.1.
-- Each forwarded key is registered as a BARE hotkey (no modifiers), and
-- macOS reserves several bare function keys system-wide (F11 = Show
-- Desktop is the usual one). Registering those fails with
--   RegisterEventHotKey failed: -9878 ... already registered
-- which the modal re-logs on EVERY Caps Lock press, because entering the
-- modal re-enables every binding. The hyper key still works — the noise
-- is just noise — but it never stops, so we don't register them.
--
-- Set this to true if you actually want hyper+F-keys and can live with
-- the Console errors for whichever ones your Mac has reserved.
local hyperForwardFKeys = false
if hyperForwardFKeys then
    for n = 1, 12 do
        table.insert(hyperForwardKeys, "f" .. n)
    end
end
for _, k in ipairs({
    "left", "right", "up", "down",
    "home", "end", "pageup", "pagedown",
    "return", "space", "tab", "escape", "delete", "forwarddelete",
    "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/", "`",
}) do
    table.insert(hyperForwardKeys, k)
end

-- ---- registering a BRAND NEW hyper shortcut --------------------------
-- §0.4's map is only for shortcuts that already existed and moved. A new
-- feature calls this instead, any time before the end of the file. It
-- goes through the same conflict sentry, so a new shortcut landing on a
-- taken key is reported rather than silently stealing it.
--   _G.hyperAddShortcut({}, "h", myFunction, "command history")
_G.hyperPending = {}
function _G.hyperAddShortcut(mods, key, fn, source, releasedFn, repeatFn)
    table.insert(_G.hyperPending, {
        mods = mods or {}, key = key, fn = fn,
        releasedFn = releasedFn, repeatFn = repeatFn,
        source = source or "custom",
    })
end

-- ---- finalize: run ONCE at the very end of this file -----------------
-- Order matters and is the whole reason this is deferred rather than
-- done inline: real shortcuts must claim their keys BEFORE we decide
-- which keys are left over to forward as a raw chord. Features bind
-- themselves all the way down to §6, so this cannot run at §3.12.
function _G.hyperFinalize()
    -- 1. Every migrated shortcut, in the order it was declared.
    for _, m in ipairs(_G.hyperMigrations) do
        hyperBind(m.mods, m.key, m.fn, m.releasedFn, m.repeatFn, m.from)
    end

    -- 2. Shortcuts registered by features via _G.hyperAddShortcut.
    for _, p in ipairs(_G.hyperPending) do
        hyperBind(p.mods, p.key, p.fn, p.releasedFn, p.repeatFn, p.source)
    end

    -- 3. Anything you added yourself in hyperActions (empty by default).
    for key, fn in pairs(hyperActions) do
        hyperBind({}, key, function()
            _G.hyperModal:exit()      -- don't stay latched after acting
            pcall(fn)
        end, nil, nil, "hyperActions:" .. tostring(key))
    end

    -- 4. Whatever bare keys are still unclaimed forward the raw chord,
    --    so hyper keeps working with apps that know nothing about
    --    Hammerspoon (Raycast, Rectangle, browser extensions…).
    local forwarded = 0
    for _, key in ipairs(hyperForwardKeys) do
        if _G.hyperBound[tostring(key):lower()] == nil then
            -- 🔁 core/hyper_key.lua STAMPS the chord before sending it:
            -- it returns through the fallback tap a millisecond later, and
            -- if ⇪ were released in that gap it would look like a genuine
            -- ⌘⇧⌃⌥ hotkey press. Falls back to a plain send if that file
            -- did not load, so forwarding never depends on it.
            local send = function()
                if _G.hyperForwardChord then return _G.hyperForwardChord(key) end
                hs.eventtap.keyStroke(_G.hyperMods, key, HYPER_KEYSTROKE_DELAY)
            end
            -- pressed, released (nil), repeated — the repeat handler is
            -- what makes a held hyper+arrow behave like a held arrow.
            hyperBind({}, key, send, nil, send, "chord")
            forwarded = forwarded + 1
        end
    end

    -- 5. Self-check: any map entry that never matched a real bind call
    --    means the combo in §0.4 is wrong, and that feature is SILENTLY
    --    still on its old global shortcut. Without this you'd only find
    --    out by pressing the key and getting nothing.
    local orphans = {}
    for combo in pairs(_G.hyperKeyMap) do
        if not _G.hyperMigrationsSeen[combo] then
            table.insert(orphans, combo)
        end
    end
    table.sort(orphans)
    if #orphans > 0 then
        print("⚠️ HYPER MAP: " .. #orphans .. " entr" ..
            (#orphans == 1 and "y" or "ies") ..
            " in §0.4 never matched a real shortcut — those features are"
            .. " still on their OLD keys:")
        for _, c in ipairs(orphans) do print("     " .. c) end
    end

    -- 🚨 6.66.4 — THIS COUNTED ONE SOURCE OUT OF THREE AND CALLED IT THE
    -- TOTAL. It was #_G.hyperMigrations — the §0.4 migration map ONLY —
    -- so every shortcut a MODULE registers through hyperAddShortcut was
    -- invisible to it. That is why LL's boot line read "32 ⇪ shortcuts"
    -- both before and after 6.66.3 added four modules and four new keys:
    -- the number is a constant that has never described what it claims to.
    --
    -- Worse, it is on the ONE LINE printed at every login. A number that
    -- looks like a total and is not is exactly the kind of quiet
    -- misreport rule 7 exists to forbid — and it sat next to the module
    -- count that DID reveal the missing modules, lending it false weight.
    --
    -- _G.hyperBoundCount is the authoritative figure: hyperBind increments
    -- it once per combo actually claimed, from every source — migrations,
    -- modules, and your own hyperActions.
    --
    -- ⚠️ FORWARDED KEYS ARE NOT SHORTCUTS and are deliberately excluded.
    -- Every unclaimed letter re-sends ⌘⇧⌃⌥+itself so hyper keeps working
    -- with Raycast and friends; counting those would report ~40 whatever
    -- this config actually binds.
    _G.hyperShortcutCount = _G.hyperBoundCount - forwarded
    _G.hyperMigrationCount = #_G.hyperMigrations
    _G.hyperForwardCount  = forwarded
end

-- Apply the remap ASYNCHRONOUSLY. Deliberately hs.task and not a
-- blocking call: §3.7's 11-second beachball was caused by slow work on
-- the main thread at boot, and this must never become the next one.
if hyperEnabled then
    -- Read by the boot summary so its one healthy line can say that ⇪ has
    -- not been proven YET rather than let "All green" imply it has.
    _G.hyperSelfTestPending = true
    _G.hyperRemapTask = hs.task.new("/usr/bin/hidutil",
        function(exitCode, stdOut, stdErr)
            -- RECORDED, not just printed. This is THE most machine-dependent
            -- thing in the config — it is the difference between the work Mac
            -- having 34 shortcuts and having none — and it is decided
            -- asynchronously, well after the boot report has gone by. Writing
            -- the answer down is what lets _G.capabilities() and ⇪⇧D report
            -- it later instead of me asking you to scroll back for a line.
            _G.hyperRemapOK = (exitCode == 0)
            if exitCode == 0 then
                _G.hyperRemapWhy = nil
                _G.diag.say("hyper", "hidutil accepted the Caps Lock remap")
                print("🎹 Hyper key ON — Caps Lock is the hyper modifier (it no longer toggles capitals)")
            else
                _G.hyperRemapWhy = "exit " .. tostring(exitCode)
                    .. (stdErr and stdErr ~= "" and (" — " .. tostring(stdErr):gsub("%s+$", "")) or "")
                _G.diag.warn("hyper", "hidutil REFUSED the remap: " .. _G.hyperRemapWhy)
                print("⚠️ 🎹 Hyper key OFF — hidutil could not remap Caps Lock (exit " .. tostring(exitCode) .. ")")
                print("   " .. tostring(stdErr or ""):gsub("%s+$", ""))
                print("   This is the documented macOS Sonoma+ restriction. Everything else still works;")
                print("   this Mac just won't have the hyper key. Caps Lock behaves normally.")
            end
        end,
        { "property", "--set", HYPER_REMAP_ON })
    _G.hyperRemapTask:start()

    -- 🚨 6.65.1 — GIVE CAPS LOCK BACK WHEN HAMMERSPOON GOES AWAY.
    --
    -- A hidutil remap is a SYSTEM-WIDE HID mapping. It is not owned by
    -- this process and it does not die with it: quit Hammerspoon, force
    -- quit it, or let it crash, and Caps Lock is STILL sending F18 with
    -- nothing left running to turn that into anything. The keyboard is
    -- then quietly missing a key and the obvious remedy — "kill the app
    -- that did this" — is the one thing that cannot help.
    --
    -- LL hit exactly that: "killing it does not free up the trackpad or
    -- the keys you can use natively". The keys half is this line's
    -- absence. hs.shutdownCallback runs on a clean quit and on a reload,
    -- so the remap now lifts with the app that relies on it.
    --
    -- ⚠️ WHAT THIS STILL CANNOT COVER: a hard CRASH (SIGABRT) never runs
    -- this, because nothing gets to run. The manual escape hatch is
    -- therefore still the important one, and it is one line in Terminal:
    --        hidutil property --set '{"UserKeyMapping":[]}'
    -- A reboot clears it too.
    hs.shutdownCallback = function()
        -- Synchronous on purpose, unlike the async apply above. There is
        -- no "later" during shutdown — an hs.task started here would be
        -- reaped with the process before it ever ran, which is precisely
        -- how this kind of cleanup ends up looking implemented and doing
        -- nothing.
        -- hs-lint: allow blocking-main-thread — synchronous is the ONLY
        -- correct choice during shutdown. There is no "later": an hs.task
        -- started here is reaped with the process before it ever runs,
        -- which is how this kind of cleanup ends up looking implemented
        -- and doing nothing.
        pcall(function()
            hs.execute("/usr/bin/hidutil property --set '{\"UserKeyMapping\":[]}'")
        end)
    end
else
    print("🎹 Hyper key disabled in config (hyperEnabled = false) — Caps Lock untouched")
end

-- Loaded HERE, not next to core/diagnostics.lua where it belongs
-- logically: capabilities reports on hyperEnabled, and a Lua local is
-- invisible to anything written above its declaration. Placed above,
-- it captured nil and reported the hyper key as disabled on BOTH
-- Macs. Nothing calls it before this point — ⇪⇧D runs on a keypress.
-- ---------------------------------------------------------------------
-- CAPABILITIES — the one answer to "does this work on THIS Mac?"
-- ---------------------------------------------------------------------
-- One init.lua, two very different Macs. About a dozen things genuinely
-- differ between them, every one of them already handled, and every one
-- printing its own line somewhere at boot. Twelve scattered lines is not
-- an answer to "what works here" — it is twelve things to hunt for.
-- _G.capabilities() collects them, with the REASON and, more usefully,
-- what each one COSTS you when it is off. Loaded right after diagnostics
-- because §1.11's report calls it.
local capOK, capErr = pcall(function()
    local path = hs.configdir .. '/core/capabilities.lua'
    local chunk, loadErr = loadfile(path)
    if not chunk then error(loadErr or ('cannot read ' .. path), 0) end
    chunk()({ cloudDir = cloudDir, logsDir = logsDir, backupDir = backupDir,
              hostTag = hostTag, asanaEnabled = asanaEnabled,
              secretsStatus = secretsStatus, hyperEnabled = hyperEnabled })
end)
if not capOK then
    print('⚠️ core/capabilities.lua failed to load — _G.capabilities() is '
          .. 'unavailable and ⇪⇧D loses its capability block. Nothing else '
          .. 'is affected. ' .. tostring(capErr))
end

end -- do...end (§3.12 Hyper Key locals)

-- (The OCR chooser was here until 6.105.0. It is built by
--  modules/ocr_engine.lua now, under the same _G.choosers.ocr name, so
--  anything that reaches for it still finds it.)

-- Clipboard chooser — searches the FULL text of every saved item, not
-- just the 100 characters a row displays. Matches are newest first,
-- capped at 250 rows for snappy typing (narrow the search for more).

-- 📌 THE TASK CREATOR MOVED OUT in 6.98.0, to modules/task_creator.lua —
-- the 30-day history, the attachment upload, the pipe parser, the draft
-- mirror, the shared submit path (_G.asanaSubmitTask) and its three keys
-- (⌃⌥⌘T · ⇪⇧S · ⌃⌥⌘A) travel together. The dashboard (§6) stayed here.

-- =====================================================================
-- 5. HOTKEY INTEGRATIONS
-- =====================================================================
-- ✏️ EDIT YOUR KEYS HERE — the core pickers still bound in THIS file,
-- one line each. Change the letter (or the mods) and reload; nothing
-- else to touch. The Hotkey Sentry (§0.3) will warn at boot if an edit
-- collides with another combo in this file or a known macOS default.
-- (⌃⌥⌘A and ⌃⌥⌘T moved to modules/task_creator.lua in 6.98.0; the dead
-- clipboardHistory row went with them — ⌃⌥⌘V has been bound by
-- modules/clipboard_history.lua since 6.55.0.)
-- (ocrSearch left this table in 6.105.0 with the rest of the engine —
--  modules/ocr_engine.lua claims ⇪O and ⇪⇧O itself.)
local coreKeys = {
    activityTracker  = { {"cmd", "alt", "shift"}, "0" },  -- activity tracker picker
}

-- 📋 THE CLIPBOARD EDIT PICKER MOVED OUT in 6.55.0, to
-- modules/clipboard_history.lua — including the snapshot+index pattern
-- that makes it work at all (hs.chooser rebuilds every choice through
-- its Objective-C bridge, so table identity cannot survive the trip and
-- only a NUMBER comes back intact).

-- App tracker (today's activity; type 'week'/'month'/search once open)
hs.hotkey.bind(coreKeys.activityTracker[1], coreKeys.activityTracker[2], function()
    _G.service.call("activity.renderChoices", "")
    showPopup(_G.choosers.appTracker)
end)

-- (⇪⇧O's EDIT/DELETE picker was here until 6.105.0 — the CSV snapshot,
--  select mode, and the empty-the-box-to-delete dialog all moved to
--  modules/ocr_engine.lua with the rest of the engine. It is still built
--  as _G.choosers.ocrEdit, and tests/test_select_mode.lua still drives
--  that exact chooser.)

-- =====================================================================
-- 6. ASANA TASK DASHBOARD — ⌃⌥⌘L open · ⌃⌥⌘C comment
-- =====================================================================
-- Shows up to 100 tasks across five categories, in this order:
--   🔴 Overdue        max 40 — newest due first
--   🟡 Due today      max 10
--   🔵 Due this week  max 30 — soonest first
--   🟠 Due later      max 10 — soonest first
--   🟣 No due date    max 10 — newest created first
-- (Category names capitalize the first word only, per spec.)
-- Caps are the config table below — edit freely; the fetch itself
-- asks Asana for up to 100 incomplete tasks, then each category is
-- trimmed to its cap for display. The list is searchable; Enter opens
-- the task in the browser (⌃⌥⌘L mode) or prompts for a comment that
-- posts to Asana (⌃⌥⌘C mode).
local asanaCaps = {
    overdue = 40,   -- 🔴 Overdue
    today   = 10,   -- 🟡 Due today
    week    = 30,   -- 🔵 Due this week
    later   = 10,   -- 🟠 Due later
    undated = 10,   -- 🟣 No due date
}

local isAsanaFetching     = false
local asanaDashboardMode  = "open"   -- "open" or "comment"

-- ---- COLOR LEGEND STRIP — pills above the task list ------------------
-- hs.chooser can't draw a footer inside its own window, so the legend
-- is a slim hs.canvas strip (same tech as the cheat sheet). It sits
-- just ABOVE the picker's search field: the picker's top-left is a
-- position we set ourselves, so the strip's placement is exact — it
-- can never overlap the task list. (The first version sat below the
-- list, which required estimating the picker's height; the estimate
-- ran short and the strip overlaid the bottom rows.)
-- Appears when the dashboard opens; disappears when the picker
-- resolves (pick a task, Esc, or click away).
local asanaLegendDefs = {
    { key = "overdue", label = "Overdue",       color = { red = 0.92, green = 0.25, blue = 0.20 }, darkText = false },
    { key = "today",   label = "Due today",     color = { red = 1.00, green = 0.80, blue = 0.00 }, darkText = true  },
    { key = "week",    label = "Due this week", color = { red = 0.04, green = 0.52, blue = 1.00 }, darkText = false },
    { key = "later",   label = "Due later",     color = { red = 1.00, green = 0.58, blue = 0.00 }, darkText = false },
    { key = "undated", label = "No due date",   color = { red = 0.69, green = 0.32, blue = 0.87 }, darkText = false },
}

_G.asanaLegendCanvas = nil
local asanaLegendCounts = nil   -- set on each fetch; nil = nothing to show

local function asanaLegendHide()
    if _G.asanaLegendCanvas then
        pcall(function() _G.asanaLegendCanvas:delete() end)
        _G.asanaLegendCanvas = nil
    end
end

local function asanaLegendShow()
    asanaLegendHide()
    if not asanaLegendCounts then return end
    local chooser = _G.choosers.asana
    if not chooser then return end

    -- Reuse the EXACT placement showPopup just used for the picker —
    -- resolving the screen again here could disagree (focus shifts as
    -- the popup opens) and draw the legend on a different monitor.
    local place = _G.lastPopupPlacement
    local screen  = (place and place.screen) or resolveBaseScreen()
    local sf = screen:frame()
    local topLeft = (place and place.point)
    if not topLeft then
        topLeft = chooserTopLeft(chooser, screen)
    end
    local pct = 40
    local okW, w = pcall(function() return chooser:width() end)
    if okW and type(w) == "number" and w > 0 and w <= 100 then pct = w end
    local chooserW = sf.w * (pct / 100)

    local stripH, pad, gap, pillH, textSize = 44, 12, 10, 30, 16

    -- Just above the picker's top edge — exact, no height estimation.
    -- Clamped so a picker nudged to the very top of the screen can't
    -- push the strip off-screen.
    local stripY = math.max(sf.y + 4, topLeft.y - stripH - 8)

    -- Lay pills left→right; width estimated from label length
    local pills, x = {}, pad
    for _, def in ipairs(asanaLegendDefs) do
        local n = asanaLegendCounts[def.key] or 0
        if n > 0 then
            local label = def.label .. "  " .. n
            local pillW = 20 + math.floor(#label * 9.0)
            table.insert(pills, { label = label, color = def.color, darkText = def.darkText, x = x, w = pillW })
            x = x + pillW + gap
        end
    end
    if #pills == 0 then return end

    local stripW = x - gap + pad
    -- Center under the picker, then clamp fully on-screen
    local stripX = topLeft.x + math.max(0, (chooserW - stripW) / 2)
    if stripX + stripW > sf.x + sf.w then stripX = sf.x + sf.w - stripW - 4 end
    if stripX < sf.x then stripX = sf.x + 4 end

    local canvas = hs.canvas.new({ x = stripX, y = stripY, w = stripW, h = stripH })
    if not canvas then return end

    local sty = _G.uiStyle or {}   -- 🎨 6.90.0 shared card look
    local els = {}
    table.insert(els, {
        type = "rectangle", action = "fill",
        fillColor = (sty.bgWith and sty.bgWith(panelAlpha))
                    or { red = 0.11, green = 0.11, blue = 0.13, alpha = panelAlpha },
        roundedRectRadii = { xRadius = 12, yRadius = 12 },
    })
    for _, p in ipairs(pills) do
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { red = p.color.red, green = p.color.green, blue = p.color.blue, alpha = 1.0 },
            roundedRectRadii = { xRadius = pillH / 2, yRadius = pillH / 2 },
            frame = { x = p.x, y = (stripH - pillH) / 2, w = p.w, h = pillH },
        })
        table.insert(els, {
            type = "text", text = p.label, textSize = textSize,
            textColor = p.darkText and { white = 0.05 } or { white = 1.0 },
            textAlignment = "center",
            frame = { x = p.x, y = (stripH - pillH) / 2 + 4, w = p.w, h = pillH },
        })
    end

    canvas:appendElements(els)
    pcall(function() canvas:level(hs.canvas.windowLevels.overlay) end)
    -- CRITICAL for Spaces/full-screen: a canvas belongs only to the
    -- Space it was created on unless told otherwise — and a native
    -- full-screen app is its own private Space, so the legend simply
    -- never appeared there. canJoinAllSpaces = visible on every Space;
    -- fullScreenAuxiliary = allowed to overlay full-screen Spaces.
    -- (hs.chooser's panel declares these internally, which is why the
    -- picker never had this problem.)
    pcall(function() canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
    _G.showCanvasSafely(canvas, "popup panel")
    _G.asanaLegendCanvas = canvas
    -- Console diagnostic (harmless; invaluable if placement misbehaves)
    local scrName = "?"
    pcall(function() scrName = screen:name() or "?" end)
    print(string.format("🎨 Legend on '%s' at x=%d y=%d w=%d h=%d",
        scrName, math.floor(stripX), math.floor(stripY), math.floor(stripW), stripH))
end

-- Nudging (⌃⌥⌘ arrows) repositions the picker — this lets section 1.5
-- drag the legend along with it.
_G.asanaLegendSync = function()
    if _G.asanaLegendCanvas then asanaLegendShow() end
end

-- Helper: parse Asana date strings safely into unix timestamps
local function parseAsanaDate(dateStr)
    -- Guard against JSON null arriving as userdata
    if type(dateStr) ~= "string" or dateStr == "" then return nil end
    local y, m, d = dateStr:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
    if y and m and d then
        return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12, min = 0, sec = 0 })
    end
    return nil
end

-- Append up to `cap` entries from src into dst (the per-category limit)
local function appendCapped(dst, src, cap)
    for i = 1, math.min(#src, cap) do
        table.insert(dst, src[i])
    end
end

local function fetchAsanaDashboard(mode)
    if not requireAsana() then return end
    asanaDashboardMode = mode or "open"
    asanaLegendHide()   -- clear any stale strip from a previous open

    if isAsanaFetching then
        hs.alert.show("⚠️ Request pending. Please wait.")
        return
    end

    isAsanaFetching = true
    hs.alert.show("🔄 Syncing Asana Tasks...")

    local fullUrl = "https://app.asana.com/api/1.0/tasks"
        .. "?assignee=me&completed_since=now&workspace=" .. asanaWorkspaceId
        .. "&opt_fields=name,due_on,due_at,created_at,permalink_url&limit=100"

    local headers = {
        ["Authorization"] = "Bearer " .. asanaToken,
        ["Accept"]        = "application/json"
    }

    hs.http.asyncGet(fullUrl, headers, function(status, body, resHeaders)
        isAsanaFetching = false

        if status ~= 200 then
            if status == 401 then
                hs.alert.show("🔒 Asana rejected the token — it's revoked or mistyped. Create a new one at app.asana.com/0/my-apps and update ~/.hammerspoon/secret.lua", 8)
                print("🚨 ASANA 401 — the token in secret.lua is not valid (revoked, expired, or mistyped)")
            else
                hs.alert.show("❌ Asana Sync Failed (Status: " .. tostring(status) .. ")")
                print("🚨 ASANA API ERROR: " .. tostring(body))
            end
            return
        end

        local response = _G.safeJson(body, "asana/list")
        if not response or not response.data then
            hs.alert.show("❌ Error reading data from Asana")
            return
        end

        local now     = os.time()
        local current = os.date("*t", now)
        local todayStart = os.time({ year = current.year, month = current.month, day = current.day, hour = 0,  min = 0,  sec = 0  })
        local todayEnd   = os.time({ year = current.year, month = current.month, day = current.day, hour = 23, min = 59, sec = 59 })
        local weekEnd    = todayEnd + (7 * 86400)

        local overdueTasks = {}   -- 🔴 Overdue
        local todayTasks   = {}   -- 🟡 Due today
        local weekTasks    = {}   -- 🔵 Due this week
        local laterTasks   = {}   -- 🟠 Due later
        local undatedTasks = {}   -- 🟣 No due date

        for _, task in ipairs(response.data) do
            local dueStr  = task.due_on or task.due_at
            local dueTime = parseAsanaDate(dueStr)

            if dueTime then
                local cleanDateStr = string.sub(dueStr, 1, 10)
                if dueTime < todayStart then
                    table.insert(overdueTasks, { text = task.name, subText = "🔴 Overdue — due: " .. cleanDateStr, url = task.permalink_url, gid = task.gid, dueTime = dueTime })
                elseif dueTime >= todayStart and dueTime <= todayEnd then
                    table.insert(todayTasks,   { text = task.name, subText = "🟡 Due today — due: " .. cleanDateStr, url = task.permalink_url, gid = task.gid, dueTime = dueTime })
                elseif dueTime > todayEnd and dueTime <= weekEnd then
                    table.insert(weekTasks,    { text = task.name, subText = "🔵 Due this week — due: " .. cleanDateStr, url = task.permalink_url, gid = task.gid, dueTime = dueTime })
                else
                    table.insert(laterTasks,   { text = task.name, subText = "🟠 Due later — due: " .. cleanDateStr, url = task.permalink_url, gid = task.gid, dueTime = dueTime })
                end
            else
                -- No due date: typically the newest tasks. created_at is
                -- ISO-8601, which sorts correctly as a plain string.
                local created = (type(task.created_at) == "string") and task.created_at or ""
                table.insert(undatedTasks, {
                    text    = task.name,
                    subText = "🟣 No due date — created: " .. (created ~= "" and created:sub(1, 10) or "unknown"),
                    url     = task.permalink_url,
                    gid     = task.gid,
                    created = created,
                })
            end
        end

        -- Per-category sorting (before caps, so the cap keeps the most
        -- relevant entries of each category):
        table.sort(overdueTasks, function(a, b) return a.dueTime > b.dueTime end)  -- newest due first
        table.sort(weekTasks,    function(a, b) return a.dueTime < b.dueTime end)  -- soonest first
        table.sort(laterTasks,   function(a, b) return a.dueTime < b.dueTime end)  -- soonest first
        table.sort(undatedTasks, function(a, b) return a.created > b.created end)  -- newest created first

        -- Assemble in display order, each category trimmed to its cap:
        -- 40 + 10 + 30 + 10 + 10 = 100 tasks maximum
        local masterChoicesList = {}
        appendCapped(masterChoicesList, overdueTasks, asanaCaps.overdue)
        appendCapped(masterChoicesList, todayTasks,   asanaCaps.today)
        appendCapped(masterChoicesList, weekTasks,    asanaCaps.week)
        appendCapped(masterChoicesList, laterTasks,   asanaCaps.later)
        appendCapped(masterChoicesList, undatedTasks, asanaCaps.undated)

        if #masterChoicesList == 0 then
            hs.alert.show("✨ Clean slate! No urgent tasks found.")
            return
        end

        -- Legend pill counts = rows each category actually contributed
        asanaLegendCounts = {
            overdue = math.min(#overdueTasks, asanaCaps.overdue),
            today   = math.min(#todayTasks,   asanaCaps.today),
            week    = math.min(#weekTasks,    asanaCaps.week),
            later   = math.min(#laterTasks,   asanaCaps.later),
            undated = math.min(#undatedTasks, asanaCaps.undated),
        }

        -- Registered in _G.choosers so it participates in popup screen routing
        if not _G.choosers.asana then
            _G.choosers.asana = hs.chooser.new(function(choice)
                asanaLegendHide()   -- picker resolved (pick / Esc / click away)
                if not choice then return end

                if asanaDashboardMode == "comment" then
                    -- 💬 COMMENT MODE: prompt for text, post it as a comment
                    if choice.gid then
                        local button, text = hs.dialog.textPrompt(
                            "💬 Comment on: " .. (choice.text or "task"),
                            "Your comment will post to Asana exactly like the 'Add a comment' box.",
                            "", "Post", "Cancel")
                        if button == "Post" and text and #text > 0 then
                            _G.service.call("asana.addComment", choice.gid, text)
                        end
                    else
                        hs.alert.show("⚠️ No task ID found for this row")
                    end
                else
                    -- 🚀 OPEN MODE: open the task in the browser
                    if choice.url then
                        hs.urlevent.openURL(choice.url)
                        hs.alert.show("🚀 Opening task in Asana...")
                    end
                end
            end)
        end

        local placeholder = (asanaDashboardMode == "comment")
            and "💬 Pick a task to comment on…"
            or  "Filter your current priority tasks..."

        _G.choosers.asana:choices(masterChoicesList)
        _G.choosers.asana:placeholderText(placeholder)
        _G.choosers.asana:rows(math.min(#masterChoicesList, 10))
        showPopup(_G.choosers.asana)
        asanaLegendShow()
    end)
end

-- Dashboard: open task in browser
-- 6.16.12: standardized every Asana hotkey onto the same ⌃⌥⌘ chord
-- (was ⌃⇧⌥ for this one and the two below) — ⌃⌥⌘L, "List tasks".
hs.hotkey.bind({"cmd", "ctrl", "alt"}, "L", function()
    fetchAsanaDashboard("open")
end)

-- Dashboard: add a comment to a task — 6.16.12: ⌃⇧⌥C -> ⌃⌥⌘C
hs.hotkey.bind({"cmd", "ctrl", "alt"}, "C", function()
    fetchAsanaDashboard("comment")
end)

-- ⌃⌥⌘B — browse your Asana project's team; Enter copies the exact name
-- so pasting it into the Task Creator's Assignee field always resolves
-- (see resolveAssignee in §5). 6.16.12: ⌃⇧⌥M -> ⌃⌥⌘B, standardized onto
-- the same chord as the rest of the Asana hotkeys. Wrapped in do...end:
-- this file is near Lua's 200-local ceiling and nothing outside this
-- needs these locals.
do

_G.choosers.asanaTeam = hs.chooser.new(function(choice)
    if not choice or not choice.name then return end
    hs.pasteboard.setContents(choice.name)
    hs.alert.show("📋 Copied " .. choice.name .. " — paste into the Assignee field")
end)
_G.choosers.asanaTeam:placeholderText("Search your Asana team — Enter copies the name")
-- Team name is folded into subText below (e.g. "someone@x.com  ·  SAC
-- Library Core Projects") — searchSubText makes hs.chooser's own
-- filtering match against it too, so typing "core" narrows to just that
-- team. Pure display/search change — doesn't touch the native ⌘+number
-- row-shortcut badges the chooser already shows, those aren't ours.
pcall(function() _G.choosers.asanaTeam:searchSubText(true) end)

local function showTeamPicker()
    local choices = {}
    for _, m in ipairs(_G.asanaTeamMembers) do
        local teamLabel = (m.teams and #m.teams > 0) and table.concat(m.teams, " + ") or ""
        local sub = m.email or ""
        if teamLabel ~= "" then
            sub = (sub ~= "" and (sub .. "  ·  ") or "") .. teamLabel
        end
        table.insert(choices, { text = m.name, subText = sub, name = m.name })
    end
    _G.choosers.asanaTeam:choices(choices)
    showPopup(_G.choosers.asanaTeam)
end

hs.hotkey.bind({"cmd", "ctrl", "alt"}, "B", function()
    if not requireAsana() then return end
    if #_G.asanaTeamMembers > 0 then
        showTeamPicker()
        return
    end
    hs.alert.show("🔄 Fetching team members…")
    _G.fetchAsanaTeamMembers(function()
        if #_G.asanaTeamMembers == 0 then
            hs.alert.show("⚠️ Couldn't load team members — check Console")
        else
            showTeamPicker()
        end
    end)
end)

end -- do...end (⌃⌥⌘B team member picker locals)

-- =====================================================================
-- 7. BOOTSTRAP — portability report + ready alert
-- =====================================================================
-- Console report: on a new Mac, this is the first thing to check —
-- it says exactly how the portability layer resolved this machine.
-- 6.15.4: prints the version so a pasted Console log always says
-- which file actually loaded — no more guessing "is this the old one?"
-- 6.19.0: wire the hyper keyspace. MUST be here, after every section has
-- registered its shortcut — step 3 of hyperFinalize can only work out
-- which keys are free to forward once all the real ones have claimed
-- theirs. Pure table work and hotkey registration: no I/O, no app
-- enumeration, nothing that could stall the main thread at boot.
-- =====================================================================
-- 1.4 SHARED TEXT & CSV HELPERS
-- =====================================================================
-- 6.40.0 — these two lived inside §3.6 Activity Tracker, which has now
-- moved into a module. Other features (File Tracker, Update Tracker)
-- and the changelog writer at the bottom of
-- this file all borrow them, so leaving them inside a module would have
-- meant everything depending on that module loading first — the exact
-- coupling this migration exists to remove. They live here, and reach
-- modules through `core`.
--
-- ⚠️ THIS WAS CAUGHT BY A FAILING EXTRACTION, NOT BY REVIEW: removing
-- §3.6 silently deleted the only definitions of both, and Lua turns a
-- vanished local into a GLOBAL lookup — so the file still COMPILED and
-- would have crashed at boot the moment the changelog writer ran.
-- Wraps a text field for CSV: quotes it, doubles any internal quotes,
-- and collapses stray newlines to a space (window titles are normally
-- single-line, this is just defensive).
local function csvQuote(value)
    local s = tostring(value or "")
    s = s:gsub('[\r\n]+', ' ')
    s = s:gsub('"', '""')
    return '"' .. s .. '"'
end

-- Splits one CSV line into fields, honoring double-quoted fields with
-- "" as an escaped quote inside them — needed because app/window
-- titles routinely contain commas (e.g. a browser tab title).
local function splitCSVLine(line)
    local fields, i, n = {}, 1, #line
    while i <= n do
        if line:sub(i, i) == '"' then
            local j, buf = i + 1, {}
            while j <= n do
                local c = line:sub(j, j)
                if c == '"' then
                    if line:sub(j + 1, j + 1) == '"' then
                        table.insert(buf, '"')
                        j = j + 2
                    else
                        j = j + 1
                        break
                    end
                else
                    table.insert(buf, c)
                    j = j + 1
                end
            end
            table.insert(fields, table.concat(buf))
            if line:sub(j, j) == ',' then j = j + 1 end
            i = j
        else
            local commaPos = line:find(',', i, true)
            if commaPos then
                table.insert(fields, line:sub(i, commaPos - 1))
                i = commaPos + 1
            else
                table.insert(fields, line:sub(i))
                i = n + 1
            end
        end
    end
    return fields
end

-- =====================================================================
-- 1.12 MODULE LOADER — sections live in their own files from here on
-- =====================================================================
-- A section that has been moved out lives in ~/.hammerspoon/modules/
-- <name>.lua and is named in a MACHINE PROFILE below. Everything not yet
-- moved still lives in this file and works exactly as before; the two
-- styles coexist deliberately, so the move happens a few sections at a
-- time rather than as one all-or-nothing rewrite.
--
-- WHY THIS MATTERS MORE THAN TIDINESS: Lua's limit of 200 locals is PER
-- CHUNK, and a file is a chunk. This file was measured at exactly 200
-- with ZERO headroom in 6.35.0 — the next top-level `local` added
-- anywhere would have been a compile error taking the WHOLE config down.
-- Every module file gets its own fresh 200.
--
-- ⚠️ MODULES LOAD FROM LOCAL DISK, NOT FROM ONEDRIVE — DELIBERATELY.
-- Loading them straight from the cloud folder would be one fewer copy
-- step, and it is the wrong trade: OneDrive's Files-On-Demand can leave
-- a file as an online-only placeholder, and READING one triggers a
-- synchronous download. In the boot path that is a main-thread stall at
-- every login on a slow network — the same failure shape as the ⌥Tab
-- freeze in 6.33.0, which is not a mistake worth making twice. The
-- master copies live in OneDrive for durability and for copying to
-- another Mac; the loader only ever reads local disk.
--
-- ---------------------------------------------------------------------
-- THE MODULE CONTRACT, in full:
--
--   return {
--     name   = "App Peek",           -- shown in the boot report
--     order  = 7,                    -- LOAD order (and the A–Z tie-break)
--     family = "windows",            -- 6.101.0: which band of the cheat
--                                    -- sheet it sits under. The ids are
--                                    -- listed in core/cheatsheet.lua →
--                                    -- cheatSheet.families. Declare it
--                                    -- HERE, never in a list over there:
--                                    -- a membership list somewhere else
--                                    -- drifts the moment a module is
--                                    -- added. No family = the visible
--                                    -- "NOT YET FILED" band, and a test
--                                    -- fails until you pick one.
--     cheatsheet = {                 -- travels WITH the module
--       title = "👀 APP PEEK",
--       entries = { { "⇪P", "Hide the frontmost app" } },
--     },
--     config = someTable,            -- OPTIONAL: settings a machine
--                                    -- profile may override
--     setup = function(core) ... end,-- REQUIRED: binds keys, cheap work
--   }
--
-- 🗂 TWO SPECIAL FAMILY CASES (6.101.0):
--   family = "auto"  — no keys, runs by itself. It collapses into the one
--     "⚙️ RUNS ITSELF" box as a single line, taken from `summary = "…"`.
--     Such a module is listed even with NO cheatsheet at all.
--   cheatsheet may be a LIST of groups, each with its own `family`, for a
--     module whose keys genuinely serve two bands — see numpad_layer.
--
-- setup() may also assign M.warm = function(core) ... end before it
-- returns. See the two-phase note below.
-- ---------------------------------------------------------------------
--
-- ⏱ TWO PHASES: setup() THEN warm(). 6.40.0.
-- setup() runs during boot and must stay CHEAP — bind hotkeys, create
-- objects, nothing that touches a big file. Anything expensive goes in
-- warm(), which the loader runs a couple of seconds AFTER boot on a
-- stored timer. Autocorrect is the case that motivated it: parsing an
-- 11,000-row CSV was happening on the boot path, and a hotkey you cannot
-- press yet because the Mac is still starting is worth nothing. Now the
-- keys bind instantly and the dictionary arrives a moment later. The
-- Console and ⇪⇧D both show warm timings separately from setup timings,
-- so you can see exactly where the time goes.
--
-- FAILURE IS ISOLATED, which is the other half of the point. Every
-- module is loaded, executed, set up AND warmed inside its own pcall. A
-- syntax error in one module costs you that module — not your hotkeys,
-- not autocorrect, not the whole config. Before this, one bad line
-- anywhere meant NOTHING loaded. Failures are named in the Console,
-- counted in the boot report, listed in ⇪⇧D, and shown as a ⚠️ group at
-- the top of the cheat sheet so a missing feature is never a mystery.
_G.moduleDir         = hs.configdir .. "/modules"
_G.moduleStatus      = {}    -- one record per module, for the report
_G.moduleCheatsheets = {}    -- groups contributed by loaded modules
_G.moduleWarmTimers  = {}    -- HELD: an unreferenced hs.timer is collected

-- =====================================================================
-- ✏️ MACHINE PROFILES — WHICH MODULES RUN ON WHICH MAC
-- =====================================================================
-- The same init.lua and the same modules/ folder go on every Mac you
-- own; this table is the only thing that differs between them, and it
-- lives in the file rather than in per-machine edits so the two Macs
-- can never drift apart silently.
--
-- Keyed by the machine's ComputerName, which §0.1 already resolved into
-- hostTag — the same name that tags your log files. An unknown machine
-- (a new Mac, or one whose name changed) falls back to `default` and
-- says so in the boot report rather than loading nothing.
--
-- `modules`  = which module files to load, in load order.
-- `settings` = per-module overrides applied to that module's `config`
--              table after setup. Anything the module exposes there can
--              differ per machine without touching the module file.
-- 🚨 6.66.3 — ONE LIST, NOT THREE COPIES. Profiles used to hand-type
-- their own module lists; four releases of new modules were added only
-- to `default`, so LL's own Mac silently never loaded them — and the
-- boot report was green, because nothing was ASKED to load. Now BASE is
-- the list, a profile declares only its differences, and a module on
-- disk that no profile loads fails the build (test_integration reads
-- BASE straight out of this file). Full story: NEW IN 6.66.3.
local BASE = {
    "ui_style",           -- 🎨 6.90.0 the shared look — FIRST: panels read it
    "daily_backup", "app_peek", "window_switcher", "window_arranger",
    "copy_on_select", "command_history", "app_watcher", "file_tracker",
    "autocorrect", "activity_tracker", "update_tracker",
    -- 6.104.0 retired document_watcher from this list — ⇪⇧W and ⇪⇧E moved
    -- into activity_tracker, which derives the same documents from the
    -- sessions it already records instead of polling for them again.
    -- 🚨 NO QUOTED MODULE NAMES IN THIS BLOCK'S COMMENTS: the test suites
    -- read BASE by matching every quoted word between its braces, so a
    -- name mentioned in passing reads as a module that must exist on disk.
    "asana_comments",
    -- 6.44.0
    "screen_veil", "mini_calendar", "quick_append", "capture_pad",
    "numpad_layer",
    -- 6.45.0
    "mouse_grid",
    -- 6.46.0
    "url_cleaner", "health_monitor",
    -- 6.47.0
    "menubar_items",
    -- 6.48.0
    "focus_mode", "bulk_rename",
    -- 6.55.0
    "clipboard_history",
    -- 6.65.0 (tool_picker was retired from here in 6.104.0 — ⇪⇧/ now opens
    --  unified search on the tool tag, one source in the one search box)
    "universal_actions",  -- ⇪⇧A  act on the Finder selection
    "pomodoro",           -- ⇪⇧P  25 on, 5 off
    -- 6.105.0 the Outlook diagnostic left this list for tools/. It bound
    -- no key and answered its question in 6.65.0, but still loaded at
    -- every boot and sat on the cheat sheet. Run it by hand when the work
    -- Mac needs asking:  dofile(hs.configdir .. "/tools/outlook-probe.lua")
    -- 6.68.0
    "text_expander",      -- ⇪⇧T  Alfred snippets, typed anywhere
    -- 6.71.0
    "key_caster",         -- ⇪⇧K  show the shortcuts as you press them
    -- 6.86.0
    "screenshots",        -- ⇪4   capture → OneDrive + clipboard · ⇪⇧4 panel
    "task_form",          -- ⇪T   labeled Asana task entry (pipe search → ⇪⇧S)
    -- 6.87.0
    "screenshot_editor",  -- 🖌   blur boxes on a screenshot (via ⇪⇧4, no key)
    "window_move",        -- 🪟   6.89.0 ⌘-drag any panel or picker (no key)
    "unified_search",     -- ⇪space  one search over every store
    "app_launcher",       -- 6.91.0 ⇪D  launch any installed app, both Macs
    "chrome_history",     -- 6.92.0 ⇪Y  90 days of Chrome, saved + searched
    "recent_docs",        -- 6.93.0 ⇪I  the 9 last-opened, then every type you use
    "begone",             -- type `begone` (AFTER text_expander: registers there)
    "search_index", "doc_keywords",  -- 6.96.0 🗂 files behind ⇪D · 🏷 docx tags
    -- 6.98.0
    "task_creator",       -- ⌃⌥⌘T create · ⇪⇧S search past · ⌃⌥⌘A format URL
    -- 6.99.0 (rebuilt 6.100.0 as the combined Quick Append Pad)
    "note_pad",           -- ⇪pad2 one box: * idea + log ! task ? note
                          -- (AFTER quick_append AND capture_pad: it files
                          --  through both of their services)
    -- 6.103.0
    "window_return",      -- 🔁 dock back in, windows go back (no key)
    -- 6.104.0
    "win_pin",            -- 📌 ⇪⇧U a note stuck to ONE window, following it
    -- 6.105.0
    "ocr_engine",         -- 🔍 ⇪O search · ⇪⇧O edit (was §2 of this file)
    "daily_rollup",       -- 📊 16:01 card over the tracker and the pad
                          -- (AFTER both: it reads their services, no key)
}

-- BASE minus `without`, plus `plus`. The list is COPIED, never shared: a
-- profile that referenced BASE and then dropped an entry would drop it
-- for every other profile too.
local function profileFrom(opts)
    opts = opts or {}
    local drop = {}
    for _, n in ipairs(opts.without or {}) do drop[n] = true end
    local mods = {}
    for _, n in ipairs(BASE) do
        if not drop[n] then mods[#mods + 1] = n end
    end
    for _, n in ipairs(opts.plus or {}) do mods[#mods + 1] = n end
    return { modules = mods, settings = opts.settings }
end

-- ✏️ EACH PROFILE NOW SAYS ONLY WHAT MAKES IT DIFFERENT.
--      without = { "pomodoro" }      -- do not load this one here
--      plus    = { "something" }    -- load an extra one here
--      settings = { … }             -- per-machine config overrides
_G.moduleProfiles = {
    -- ---- personal Mac: everything on ----
    ["Lees-MacBook-Air"] = profileFrom(),

    -- ---- work Mac ----
    -- ✏️ PUT YOUR WORK MACHINE'S NAME HERE. Find it by running
    --      scutil --get ComputerName
    -- on that Mac, or read the 🧭 line at the top of its Console.
    ["Lees-Work-MacBook"] = profileFrom({
        settings = {
            -- Examples — delete or edit freely. These are exactly the
            -- knobs a work Mac tends to want different:
            window_switcher = {
                -- A work Mac with a lot of corporate agents running can
                -- make the cross-Space sweep slower; lower the cap or
                -- turn Spaces off here rather than editing the module.
                maxWindows = 24,
            },
        },
    }),

    -- ---- any other Mac ----
    default = profileFrom(),
}

_G.moduleWarmDelay = 2.0   -- seconds after boot before warm() runs

-- The shared surface. This is the ONLY thing modules may depend on, and
-- keeping it explicit is what stops the coupling growing back: anything
-- not listed here is private to this file.
local core = {
    version     = _G.configVersion,
    -- paths (§0.1 portability layer)
    homeDir     = homeDir,     cloudDir  = cloudDir,
    logsDir     = logsDir,     backupDir = backupDir,
    hostTag     = hostTag,     configDir = hs.configdir,
    -- file helpers (§0.1 / §3.6)
    warnWriteFailed = warnWriteFailed,
    adoptLegacyFile = adoptLegacyFile,
    csvQuote        = csvQuote,
    splitCSVLine    = splitCSVLine,
    formatDuration  = formatDuration,
    -- popups & screens (§1.5)
    popupKeys        = popupScreenKeys,
    popupMods        = popupScreenKeys.mods,
    showPopup        = showPopup,
    resolveBaseScreen = resolveBaseScreen,
    chooserTopLeft   = chooserTopLeft,   -- 6.98.0: the draft mirror places by it
    panelAlpha       = panelAlpha,
    -- hyper keyspace (§3.12) — the supported way for a module to claim a
    -- ⇪ shortcut. Wrapped rather than captured, so it resolves at call
    -- time and this table stays honest if §3.12 ever moves.
    hyperAddShortcut = function(...) return _G.hyperAddShortcut(...) end,
    -- credentials (§0.2) — nil when secret.lua is absent, by design
    asanaEnabled     = asanaEnabled,
    -- the press-time gate every Asana hotkey uses: true, or an alert
    -- explaining that this Mac has no secret.lua (6.98.0, for modules)
    requireAsana     = requireAsana,
    asanaToken       = asanaToken,
    asanaWorkspaceId = asanaWorkspaceId,
    -- 6.44.0: the Capture Pad files its 4 PM tasks into this project.
    -- Same value the Task Creator (§4) already uses, so both land in the
    -- same place and there is one thing to change, not two.
    asanaProjectId   = asanaProjectId,
    -- service registry (see the stub at the top of this file). A module
    -- publishes with core.provide("name", fn); anything else calls it
    -- with _G.service.call("name", ...) and gets a warning rather than a
    -- crash if the module is missing.
    provide  = function(name, fn) _G.service.provide(name, fn) end,
    call     = function(name, ...) return _G.service.call(name, ...) end,
    -- diagnostics (§1.11)
    diag     = _G.diag,
    safeJson = _G.safeJson,
}
_G.core = core   -- so a module author can inspect it from the Console

-- Load one module. Returns a status record; never throws, whatever the
-- module does.
local function loadOneModule(name, settings)
    local path = _G.moduleDir .. "/" .. name .. ".lua"
    local rec  = { name = name, path = path, ok = false, ms = 0 }
    local t0   = hs.timer.secondsSinceEpoch()

    -- loadfile REPORTS a syntax error rather than raising it, so this
    -- distinguishes "file missing" from "file broken" — two very
    -- different things to see in a boot report.
    local chunk, loadErr = loadfile(path)
    if not chunk then
        rec.err = (hs.fs.attributes(path) == nil)
                  and "not found at " .. path
                  or  ("syntax error — " .. tostring(loadErr))
        rec.ms  = (hs.timer.secondsSinceEpoch() - t0) * 1000
        return rec
    end

    local okRun, mod = pcall(chunk)
    if not okRun then
        rec.err = "failed while loading — " .. tostring(mod)
        rec.ms  = (hs.timer.secondsSinceEpoch() - t0) * 1000
        return rec
    end
    -- Validate the contract before trusting it: a module that returns
    -- nothing (a forgotten `return M`) would otherwise fail later, in a
    -- place with no obvious connection to the real mistake. This check
    -- has already earned its keep once — it caught a do...end block
    -- split across the new function boundary in 6.37.0.
    if type(mod) ~= "table" or type(mod.setup) ~= "function" then
        rec.err = "does not return a table with a setup() function"
        rec.ms  = (hs.timer.secondsSinceEpoch() - t0) * 1000
        return rec
    end

    local okSetup, setupErr = pcall(mod.setup, core)
    rec.ms = (hs.timer.secondsSinceEpoch() - t0) * 1000
    if not okSetup then
        rec.err = "setup() failed — " .. tostring(setupErr)
        return rec
    end

    -- Machine-profile overrides, applied AFTER setup so the module's own
    -- defaults exist to be overridden.
    if settings and type(mod.config) == "table" then
        local applied = {}
        for k, v in pairs(settings) do
            mod.config[k] = v
            table.insert(applied, k)
        end
        if #applied > 0 then
            rec.overrides = table.concat(applied, ", ")
            _G.diag.say("module", name .. " profile overrides: " .. rec.overrides)
        end
    end

    rec.ok      = true
    rec.title   = mod.name or name
    rec.module  = mod
    -- The cheat sheet group is registered only after setup SUCCEEDS, so
    -- the sheet can never advertise a shortcut that was never bound.
    -- 🗂 6.101.0 — THREE THINGS CHANGED HERE, all so the sheet can group by
    -- family without any list of who-belongs-where living outside the
    -- modules themselves:
    --   1. the group carries `family` (from the group, else the module);
    --   2. a module may register SEVERAL groups — `cheatsheet` can be a
    --      LIST — because numpad_layer's keys genuinely serve two families
    --      (⇪pad captures, ⇪⇧pad moves windows) and filing all 24 rows
    --      under either one is a lie about half of them;
    --   3. a module with family = "auto" registers EVEN WITH NO CHEATSHEET,
    --      so the "runs itself" box can list it by name. copy_on_select has
    --      never had a cheat sheet group and would otherwise be the one
    --      automatic tool the sheet never mentions.
    local cs     = mod.cheatsheet
    local groups = nil
    if type(cs) == "table" then groups = cs.title and { cs } or cs end
    if (not groups or #groups == 0) and mod.family == "auto" then
        groups = { { title = mod.name or name, entries = {} } }
    end
    for gi, g in ipairs(groups or {}) do
        if type(g) == "table" and g.title then
            table.insert(_G.moduleCheatsheets, {
                title   = g.title,
                entries = g.entries or {},
                -- ⚠️ A SLOT PER GROUP, NOT PER MODULE. Two groups sharing
                -- one order number is a real bug and not a cosmetic one:
                -- Lua's table.sort is not stable, so they would swap
                -- places at random between reloads and the sheet would
                -- never look the same twice. The thousandth keeps a
                -- multi-group module inside its own slot.
                order   = (mod.order or 500) + (gi - 1) / 1000,
                family  = g.family  or mod.family,
                summary = g.summary or mod.summary,
                source  = mod.name  or name,
            })
        end
    end
    return rec
end

-- Phase two. Scheduled, never inline: the whole point is that this work
-- is NOT on the boot path.
local function scheduleWarm(rec)
    local mod = rec.module
    if not (mod and type(mod.warm) == "function") then return end
    local delay = mod.warmAfter or _G.moduleWarmDelay
    local timer = hs.timer.doAfter(delay, function()
        local t0 = hs.timer.secondsSinceEpoch()
        local ok, err = pcall(mod.warm, core)
        rec.warmMs = (hs.timer.secondsSinceEpoch() - t0) * 1000
        if ok then
            rec.warmed = true
            _G.diag.say("module", string.format("%s warmed in %.0fms", rec.name, rec.warmMs))
        else
            rec.warmed = false
            rec.warmErr = tostring(err)
            print("🧩 MODULE WARM-UP FAILED — " .. rec.name .. ": " .. rec.warmErr)
            _G.diag.warn("module", rec.name .. " warm() — " .. rec.warmErr)
            -- 🚨 6.73.0 — AND IT REACHES THE LEDGER AND THE SCREEN.
            -- This was print-and-diag only, and that is precisely how
            -- 6.69.0 shipped with NOT ONE SNIPPET LOADED: text_expander's
            -- warm() threw, the Console said so once, and nothing else
            -- did. Worse, the boot line had ALREADY printed "All green" —
            -- it runs before this phase exists, so it was reporting on a
            -- phase that had not happened yet.
            -- A module that fails to warm is a DEAD FEATURE. It has no
            -- data, no dictionary, no snippets — and every key it bound
            -- still answers, doing nothing. That is the exact shape rule
            -- 7 exists to forbid.
            if _G.notices then
                pcall(_G.notices.record, "module", rec.name .. " warm() failed",
                      rec.warmErr)
                pcall(_G.notices.tell, "🧩 " .. rec.name .. " did not finish loading",
                      "Its data never loaded — see the Console",
                      { key = "warm:" .. rec.name, every = 900 })
            end
        end
    end)
    -- HELD. An unreferenced hs.timer is garbage-collected and silently
    -- never fires — that is exactly how 6.33.0 lost its warm-up.
    table.insert(_G.moduleWarmTimers, timer)
    rec.warmPending = true
end

-- Load every module in the given order. Order is EXPLICIT rather than a
-- directory scan: boot behaviour should not depend on how the filesystem
-- happens to sort names, and a stray file dropped in the folder must
-- never execute itself.
function _G.loadModules(list, settingsByModule)
    local loaded, failed = 0, 0
    for _, name in ipairs(list) do
        local rec = loadOneModule(name, settingsByModule and settingsByModule[name])
        table.insert(_G.moduleStatus, rec)
        if rec.ok then
            loaded = loaded + 1
            _G.diag.say("module", string.format("%s loaded in %.0fms", rec.name, rec.ms))
            scheduleWarm(rec)
        else
            failed = failed + 1
            print("🧩 MODULE FAILED — " .. rec.name .. ": " .. tostring(rec.err))
            _G.diag.warn("module", rec.name .. " — " .. tostring(rec.err))
        end
    end
    _G.diag.mark("§1.12 modules loaded")
    _G.moduleLoaded, _G.moduleFailed = loaded, failed

    -- 🚨 6.73.0 — THE BOOT LINE SAYS "All green" BEFORE THIS PHASE EXISTS.
    -- It prints at the end of setup; warm() runs seconds later, so the
    -- summary you read has no way to know whether the second half worked.
    -- 6.69.0 proved that the hard way: "31 modules · All green", and then
    -- the expander's warm() threw and all 2,006 snippets were missing.
    -- So the warm phase reports its OWN result, once, after the last
    -- module has had its turn. Silent when everything worked — a second
    -- "all green" nobody needs is how people learn to skim the first one.
    _G.warmSummaryTimer = hs.timer.doAfter(
        (_G.moduleWarmDelay or 2.0) + 1.5, function()
        local bad = {}
        for _, r in ipairs(_G.moduleStatus or {}) do
            if r.warmPending and r.warmed == false then bad[#bad + 1] = r.name end
        end
        if #bad == 0 then return end
        table.sort(bad)
        print(("🧩 WARM-UP: %d module(s) loaded but never finished starting — %s."
               .. " Their keys still answer and do nothing. The boot line above"
               .. " could not know: it prints before this phase runs.")
              :format(#bad, table.concat(bad, ", ")))
    end)
    return loaded, failed
end

-- =====================================================================
-- 🚑 SAFE MODE — 6.65.1
-- =====================================================================
-- WHAT IT IS FOR. When Hammerspoon is crashing at launch, every way of
-- fixing it goes THROUGH Hammerspoon: the cheat sheet, ⇪⇧D, the reload
-- key, the Console. A crash loop takes all of those away at once, and
-- the only advice left is "move init.lua out of the way", which turns
-- the whole config off and tells you nothing about which part was at
-- fault.
--
-- So: create an empty file called SAFE next to init.lua and Hammerspoon
-- boots with the smallest module set that still leaves the machine
-- usable. Delete it to go back to normal.
--
--        touch ~/.hammerspoon/SAFE      # then reload Hammerspoon
--        rm    ~/.hammerspoon/SAFE      # back to the full set
--
-- ✏️ WHAT SURVIVES SAFE MODE, and why exactly these:
--   · the hyper key and the cheat sheet are NOT modules — they are in
--     this file and always load, so ⇪/ still works and you can still
--     read your way out.
--   · health_monitor, so ⇪⇧H can tell you what it sees.
--   · NOTHING that talks to another application, drives a private macOS
--     API, or runs on a timer. That is the whole point: those are the
--     three things that can take the app down or wedge the desktop, and
--     in safe mode none of them is running.
--
-- 🚨 SPECIFICALLY EXCLUDED, and named so this is not a mystery:
--   · everything AppleScript-adjacent (bulk_rename, universal_actions)
--     — see the 🚨 on writeFinderComment in modules/ocr_engine.lua,
--     which is where that crash story now lives. The Outlook probe was
--     the third until 6.105.0 moved it to tools/, where safe mode does
--     not have to exclude it because nothing loads it.
--   · copy_on_select, menubar_items, app_watcher, file_tracker — all
--     Accessibility watchers or timers against other apps.
local safeMode = false
pcall(function()
    safeMode = hs.fs.attributes(hs.configdir .. "/SAFE") ~= nil
end)

_G.moduleProfileName = _G.moduleProfiles[hostTag] and hostTag or "default"
if safeMode then _G.moduleProfileName = "SAFE" end
do
    local profile = _G.moduleProfiles[_G.moduleProfileName]
    if safeMode then
        profile = { modules = { "health_monitor", "mini_calendar",
                                "window_arranger", "numpad_layer" } }
        print("🚑 SAFE MODE — " .. #profile.modules .. " modules only. "
              .. "Delete ~/.hammerspoon/SAFE and reload for the full set.")
        -- Said on screen as well as the console, because the whole reason
        -- you are here is that you could not see the console.
        -- HELD, like every other timer in this file: an unreferenced
        -- hs.timer can be collected before it fires, which turns a
        -- reliable message into one that shows up most of the time.
        _G.safeModeTimer = hs.timer.doAfter(1.0, function()
            pcall(function()
                hs.alert.show("🚑 Hammerspoon is in SAFE MODE\n"
                    .. "Most tools are off. rm ~/.hammerspoon/SAFE to restore.", 6)
            end)
        end)
    end
    _G.loadModules(profile.modules, profile.settings)
end

-- 🔔 THE ONE THING YOU SEE AT LOGIN.
-- Clean boot: a brief flash, then nothing. A module that did not load:
-- an alert naming it. You are never asked to go and check anything —
-- silence means it worked, which is the only arrangement that survives
-- not having the Console open.
--
-- ⏱ ON A TIMER, NOT INLINE. hs.alert during the boot chunk can land
-- before the screen is ready at login and simply not be seen — which
-- would make the whole mechanism a lie on the one boot you most care
-- about. A second's delay costs nothing and is reliably visible.
pcall(function()
    if not _G.notices then return end
    local names = {}
    for _, st in ipairs(_G.moduleStatus or {}) do
        if not st.ok then
            names[#names + 1] = tostring(st.name)
            _G.notices.record("load", tostring(st.name), tostring(st.err or "failed"))
        end
    end
    -- HELD in _G: an unreferenced hs.timer is collected, and a collected
    -- timer never fires — which would silently remove the one signal
    -- this whole mechanism exists to give.
    _G.noticesBootTimer = hs.timer.doAfter(1.0, function()
        pcall(_G.notices.bootFinished, _G.moduleLoaded, _G.moduleFailed, names)
    end)
end)

if _G.hyperFinalize then _G.hyperFinalize() end
if _G.diag then _G.diag.mark("§3.12 hyper wired") end

-- 🔬 THE SECOND WAY INTO ⇪, AND THE PROOF THAT ONE OF THEM WORKS. Loaded
-- HERE and nowhere earlier: the Carbon-free dispatcher inside it reads
-- _G.hyperDispatch, which _G.hyperFinalize() above has only just finished
-- filling. See core/hyper_key.lua for what LL's work Mac did and why a
-- registered shortcut is not a working one.
local hkOK, hkErr = pcall(function()
    local path = hs.configdir .. '/core/hyper_key.lua'
    local chunk, loadErr = loadfile(path)
    if not chunk then error(loadErr or ('cannot read ' .. path), 0) end
    chunk()({ enter = _G.hyperEnter, exit = _G.hyperExit,
              combo = _G.hyperCombo })
end)
if not hkOK then
    _G.hyperSelfTestPending = false
    print('⚠️ 🎹 core/hyper_key.lua failed to load — ⇪ has only its Carbon '
          .. 'hotkey, and nothing will check that it works. Everything else '
          .. 'is unaffected. ' .. tostring(hkErr))
    pcall(function() _G.diag.warn('hyper', 'hyper_key.lua: ' .. tostring(hkErr)) end)
end

print("📌 init.lua ARCHITECTURE VERSION: " .. _G.configVersion)

-- ---- CHANGELOG CSV --------------------------------------------------
-- An Excel-ready copy of the release notes in your OneDrive Logs folder,
-- appended once per version. Lifted into core/changelog_csv.lua in
-- 6.77.0: it is a feature, not orchestration, and init.lua is the
-- orchestrator. See that file for why it was stale for thirteen releases.
local clOK, clErr = pcall(function()
    local path = hs.configdir .. '/core/changelog_csv.lua'
    local chunk, loadErr = loadfile(path)
    if not chunk then error(loadErr or ('cannot read ' .. path), 0) end
    chunk()({ logsDir = logsDir, csvQuote = csvQuote })
end)
if not clOK then
    print('⚠️ core/changelog_csv.lua failed — no changelog row this version. '
          .. 'Nothing else is affected. ' .. tostring(clErr))
end

-- Seed earlier versions into the changelog if it was just created (so
-- the CSV has a meaningful history even for someone installing fresh).
-- (Structured as nested ifs, not goto, to keep locals scoped inside
-- the do-block — goto forces Lua to hold the scope open and that
-- pushed us past the 200-local ceiling.)
;(function()
    local changelogFile = logsDir .. "/changelog.csv"
    local f = io.open(changelogFile, "r")
    if not f then return end
    local content = f:read("*a"); f:close()
    local lineCount = 0
    for _ in content:gmatch("[^\n]+") do lineCount = lineCount + 1 end
    if lineCount > 3 then return end
    local out = io.open(changelogFile, "a")
    if not out then return end
    local seed = {
        { "07-18-26", "6.10.0", "ONE DATA HOME: all log/note/history files consolidated into OneDrive Logs folder; per-machine tagging; autocorrect.csv + custom_shortcuts.json shared between Macs; secret.lua excluded from nightly backup; write-failure warnings added" },
        { "07-18-26", "6.10.1", "Task Creator draft persistence: typed text survives popup dismissal; restored on reopen" },
        { "07-18-26", "6.10.2", "Task Creator wider (60%) + live word-wrapped draft mirror panel above the picker" },
        { "07-18-26", "6.10.3", "Canvas panels translucent (panelAlpha=0.80); hs.chooser pickers have no opacity API" },
        { "07-19-26", "6.11.0", "OCR file tagging: copy image files in Finder -> OCR -> Finder comment (Spotlight-indexed)" },
        { "07-19-26", "6.11.1", "OCR detection rebuilt on hs.pasteboard.readAllData; console narration added" },
        { "07-19-26", "6.11.2", "OCR detection: NUL/control byte stripping; file://localhost handling; per-candidate rejection diagnostics" },
        { "08-01-26", "6.11.3", "Beachball fix: File Tracker + Activity Tracker history loaded in background chunks (4000 rows/tick); 50000-row cap" },
        { "08-02-26", "6.30.0", "App Lock: manager moved to hyper+shift+H; cover-only mode (no hiding/bouncing); cover level fixed (was burying PIN prompt at overlay 102 > popUpMenu 101, now floating 3); live-state guards prevent redundant lock/unlock; own popups no longer trigger relock-on-leave" },
    }
    for _, row in ipairs(seed) do
        if not content:find(row[2], 1, true) then
            out:write(csvQuote(row[1]) .. "," .. csvQuote(row[2]) .. ","
                .. csvQuote(row[3]) .. "\n")
        end
    end
    out:close()
    print("📝 Changelog: seeded " .. #seed .. " earlier versions")
end)()

-- =====================================================================
-- BOOT REPORT — quiet when healthy, loud when not (6.44.11)
-- =====================================================================
-- Lives in core/boot_report.lua so a test can RUN it rather than grep
-- for the strings it prints. Accessibility is read here, not there, so
-- the report can carry it as a row instead of trailing it underneath.
local axOK = false
pcall(function() axOK = hs.accessibilityState() end)
local brOK, brErr = pcall(function()
    local path = hs.configdir .. '/core/boot_report.lua'
    local chunk, loadErr = loadfile(path)
    if not chunk then error(loadErr or ('cannot read ' .. path), 0) end
    chunk()({ hostTag = hostTag, cloudDir = cloudDir, logsDir = logsDir,
              backupDir = backupDir, asanaEnabled = asanaEnabled,
              secretsStatus = secretsStatus, axOK = axOK })
end)
if not brOK then
    -- The report failing must not cost you the boot, but it must not be
    -- silent either: a missing report looks exactly like a healthy one.
    print('⚠️ core/boot_report.lua failed — no boot summary this session. '
          .. tostring(brErr))
end

if secretsStatus:match("^broken") then
    -- 6.16.18: held in _G. — an unstored doAfter return value is a real
    -- Hammerspoon gotcha, its GC can silently cancel the timer before
    -- it fires (see the App Monitor fix above for the full story).
    _G.bootBrokenSecretTimer = hs.timer.doAfter(2, function()
        hs.alert.show("⚠️ secret.lua exists but couldn't load — see Console for the exact error", 6)
    end)
end

-- Accessibility: without it, hotkeys/popups/Asana/tracking all still
-- work, but the Window Arranger, App Peek, and app summon can't touch
-- other apps' windows. On a managed work Mac IT may block granting it.
-- (axOK is read above, so the boot report can carry it as a row rather
-- than trailing it underneath as a fifteenth line.)
if not axOK then
    _G.bootAccessibilityTimer = hs.timer.doAfter(3, function()
        hs.alert.show("♿️ Grant Hammerspoon Accessibility to enable window features (System Settings → Privacy & Security)", 6)
    end)
end

_G.bootReadyAlertTimer = hs.timer.doAfter(1.5, function()
    local notes = {}
    if not asanaEnabled then table.insert(notes, "Asana OFF") end
    if not cloudDir then table.insert(notes, "local logs") end
    local suffix = (#notes > 0) and ("  ·  " .. table.concat(notes, " · ")) or ""
    hs.alert.show("🚀 System Fully Synchronized" .. suffix, 3)
end)
print("⚡ Core Systems Booted. All pipelines active.")