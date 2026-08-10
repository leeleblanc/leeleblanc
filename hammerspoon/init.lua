-- =====================================================================
-- * Working VERSION *
-- =====================================================================
-- =====================================================================
-- 08-05-26 using Claude
-- =====================================================================
-- .Hammerspoon ARCHITECTURE VERSION CONTROL: 6.49.0-UNIVERSAL-COMMENTS
-- =====================================================================

-- NEW IN 6.49.0 — THE NUMBER PAD, SWITCHED ON, WITH TWO LAYERS:
--   🔢 THE PAD IS LIVE. It shipped PARKED in 6.44.0 — a worked-out layout
--      bound to nothing — and it is now on, with a second layer added:
--         ⇪  + pad  →  WINDOWS   (the key's position IS the window's)
--         ⇪⇧ + pad  →  TOOLS     (focus, rename, grid, menu bar, links)
--      That is ~28 live shortcuts that cost ZERO letters on the main
--      keyboard, because the pad sends its own key codes: pad7 is not 7,
--      and ⇪pad7 is not ⇪⇧pad7.
--   🪟 WINDOWS STAYED ON THE UNSHIFTED LAYER, deliberately. Its mnemonic is
--      the best thing in that module — pad7 is the top-left quarter because
--      7 IS the top-left key — and there is nothing to memorise. Burying it
--      under a modifier to make room for tools would have traded the one
--      layout that needs no memory for one that does. Tools took the
--      shifted layer instead.
--   🔌 THE TOOL LAYER BINDS BY SERVICE NAME, NOT BY FUNCTION. numpad_layer
--      knows nothing about focus mode or renaming; it calls "focus.toggle"
--      and the dispatcher resolves it. A pad key whose module is switched
--      off on this Mac prints "no provider" instead of erroring. Four
--      modules gained the entry-point service they had been missing —
--      focus.toggle, rename.show, rename.undo, menuBar.show,
--      url.cleanClipboard — because they had published only QUERIES
--      (report, list, plan) and nothing a key could actually press.
--   🚨 WHICH CREATED A NEW FAILURE MODE, SO IT GOT A NEW TEST. A typo in a
--      service name — "focus.tggle" — binds perfectly, does nothing when
--      pressed, and prints to a Console nobody is reading. The check that
--      every shifted binding resolves to a real provider had to go in
--      test_integration.lua and NOWHERE ELSE: every other suite loads one
--      module at a time against stubs, so the registry is empty there and
--      the same check would have passed vacuously while proving nothing.
--      Verified by planting the typo and watching it fail.
--   ✏️ ONE ECHO ACROSS THE LAYERS, on purpose: pad. undoes on both. ⇪pad.
--      puts a window back where it was, ⇪⇧pad. undoes the last rename.
--      The tool rows are grouped by row (meetings · pickers · clipboard)
--      rather than pretending to a spatial logic they do not have.
--   🧪 1,483 checks. Turning the layer on broke nine existing tests, which
--      is exactly what they were for — they asserted it ships parked. They
--      now assert the live two-layer contract, that parking is still
--      reachable, and that the nil-key guard covers the shifted layer too.
-- NEW IN 6.48.0 — FOCUS MODE (⇪F) AND BULK RENAME (⇪R):
--   🎯 FOCUS MODE. A Zoom or Teams MEETING WINDOW — not merely the app
--      being open — mutes the mic, turns the camera off if it is provably
--      on, runs your Do Not Disturb Shortcut, and dims every app that is
--      not the meeting. Leaving puts back exactly what it changed.
--      · IT CANNOT REVOKE CAMERA ACCESS. No macOS API exists. What it does
--        instead is READ the meeting app's own menu: "Stop Video" present
--        means the camera is on, so clicking it is deterministic. If only
--        "Start Video" is there the camera is already off and it does
--        NOTHING. Firing ⌘⇧V blindly is a coin flip that switches the
--        camera ON half the time, which is worse than doing nothing.
--        Teams exposes no readable camera menu, so Teams gets a muted mic
--        and its camera left alone — stated rather than faked.
--      · OUTLOOK'S CALENDAR IS NOT READ, deliberately. Classic Outlook had
--        AppleScript; the rewritten one largely dropped it, and a detector
--        that works on one build and silently fails on the next is worse
--        than none. It watches the REMINDER WINDOW for a join link, which
--        works on both builds and fires exactly when you care.
--      · THE FAILURE THAT MATTERS IS A MIC LEFT MUTED, so the design is
--        built around restoring rather than detecting: prior state is
--        recorded BEFORE any change and a mic you muted yourself is never
--        unmuted; every restore step is independently pcall'd and the mic
--        goes first; a watchdog disengages on its own if detection dies.
--   ✏️ BULK RENAME. Select files in Finder, ⇪R, pick a rule, check the
--      preview, ⏎. ⇪⇧R undoes the batch and survives a restart.
--      · SUBTITLES MOVE WITH THEIR VIDEO, BY CONSTRUCTION. A player finds
--        captions by filename, so renaming a .mp4 and not its .srt does
--        not leave a stray file — it silently kills subtitles. Rules
--        rewrite the GROUP stem and extensions are reattached, so there is
--        no code path that can separate them. It knows the tails that
--        break naive matching too: film.en.srt, film.forced.srt.
--      · IT REFUSES RATHER THAN OVERWRITES. os.rename destroys the target
--        with no warning and no undo, and a bulk rename is exactly where
--        two names collapse into one. Any collision aborts the WHOLE
--        batch — a half-renamed folder is worse than an unrenamed one —
--        and renames run in two phases through temporaries so a swap or a
--        rotation works instead of eating a file.
--      · The `tv` rule fixes the season that prompted this: eight episodes
--        named .1080p.ATVP-[y2flix.cc] and one named .108 all become
--        Dark.Matter.2024.S01E01 and siblings, subtitles included.
--   🚨 THE SUITE CAUGHT TWO REAL BUGS IN THIS RELEASE BEFORE IT SHIPPED:
--      · order = 13.10 IS order = 13.1 IN LUA. Trailing zeros do not
--        survive, and 13.1 is the Capture Pad — so the obvious "next
--        number after 13.9" was a silent cheat-sheet tie whose running
--        order then depended on table iteration. Both new modules moved to
--        14.x. This is why the integration suite loads all 24 modules
--        together instead of testing each alone.
--      · INSTALL.md's module count is asserted against disk, so 22-vs-24
--        failed two suites rather than shipping a doc that lies.
--   🧪 1,479 checks across twelve Lua suites. The two new ones are
--      property-based: 400 random messy folders assert that no file is
--      lost, no clean plan collides, every subtitle stays with its video
--      and every batch undoes exactly; 500 random meeting days assert the
--      mic is never stranded and never unmuted against the user's wishes.
--      Three mutations were too weak to fire and had to be rewritten —
--      one grouped by a rule that changed nothing, one probed a teardown
--      that already guarded itself and was aimed at a step that runs
--      first anyway.
-- NEW IN 6.47.1 — THE EXPLORER TURNED ON THE THREE NEWEST TOOLS:
--   🔎 The random-sequence explorer built for the Mouse Grid now runs
--      against the URL Cleaner, the Health Monitor and Menu Bar Items.
--      Four findings came back. NONE was a bug in the shipped modules —
--      three were faults in my own test instrumentation and one was a
--      deliberate design decision the property had stated too broadly.
--      That is worth recording rather than quietly fixing, because it is
--      what property testing actually feels like: the properties are
--      harder to state correctly than the code is to write.
--   🔗 URL CLEANER, 8,000 generated URLs. Properties: never throws,
--      IDEMPOTENT (cleaning a clean URL is a no-op), still a URL,
--      wrapping cannot change the answer, every non-tracker survives,
--      every tracker goes, the fragment is untouched.
--      → Finding: it refused to unwrap a generic ?url= pointing at its
--        OWN host. That is correct and now has its own test:
--        example.com/login?url=example.com/dashboard is a login return
--        path, not a redirect, and rewriting it sends you somewhere you
--        did not ask to go. The fuzzer had generated an unrealistic
--        input and asserted a naive substring match.
--   🩺 HEALTH MONITOR, 600 random timelines / 36,000 events — files
--      going quiet and coming back, midnight mid-outage, the lid shutting
--      during a fault, modules failing and recovering, interleaved.
--      → Finding: a module that FAILED TO LOAD is announced during the
--        boot grace period. Deliberate: the grace period exists because
--        module files do not exist yet, which says nothing about load
--        status, and a certain fault should not wait twenty minutes.
--      → Two of mine: the property read the clock BEFORE the action that
--        changed it, and the harness let the simulated date run backward
--        between timelines, visiting one calendar day twice.
--      → And it added a rule nothing had checked: load failures obey the
--        once-per-day limit too.
--   📊 MENU BAR ITEMS, 500 random Mac populations — up to 30 apps mixing
--      healthy, silent, wedged and action-refusing. The property that
--      matters is that the scan returns inside its budget however bad the
--      population, because that budget is your keyboard.
--   🧬 EVERY PROPERTY WAS THEN MUTATION-TESTED, because a property that
--      cannot fail is decoration. Breaking idempotence, the parameter
--      blocklist, the once-per-day guard, the active-hours guard and the
--      scan budget each fails the suite by name. Two of my first attempts
--      at those mutations were too narrow to fire and had to be rewritten.
--   🧪 1,410 checks across eleven suites.
--   🩹 THE SHIP CHECK THEN FOUND TWO THINGS THE SUITES CANNOT SEE, both
--      in what travels ALONGSIDE the code rather than in the code:
--      · hs-doctor.sh's "is each module current?" markers stopped at
--        6.44.4, so the four newest tools had no staleness check at all.
--        Added, and menubar_items is checked for mb.axTimeout
--        specifically — a copy without it is not merely old, it is the
--        version that can hold the keyboard while an app fails to answer.
--      · GUIDE.md still said 6.44.0, "18 modules", and "five suites, 593
--        checks". It now says 22, eleven and 1,410, documents core/ and
--        tools/, and stops listing §1.6 and §1.11 as work to do — they
--        moved to core/ in 6.46.1. Headroom re-measured: 111, not 116.
--      · hs-install.sh shipped WITHOUT its executable bit while the
--        other two tools had theirs. All three are 755 now.
--      None is a runtime change, so the version stays 6.47.1.
--   📦 THE ZIP IS VERIFIED BY EXTRACTING IT: unpacked to an empty
--      directory, its own tools/run-tests.sh runs all 1,410 checks green
--      with nothing else present.
-- NEW IN 6.47.0 — MENU BAR ITEMS (⇪M), AND WHY IT IS NOT BARTENDER:
--   🚫 THE HONEST PART FIRST. Bartender's central trick — HIDING other
--      apps' menu bar icons — CANNOT be done in Hammerspoon, and the
--      reason is not a gap in Hammerspoon. A menu bar icon is an
--      NSStatusItem owned by the app that made it; macOS exposes no
--      public API for one process to hide, move or reorder another
--      process's status item. There is nothing to call. Bartender works
--      around it by covering the real bar and drawing its own copies of
--      the icons, which is why it needs SCREEN RECORDING — it has to
--      photograph the menu bar, because it cannot ask for the images
--      either. Hammerspoon could draw a black strip and nothing more.
--   ✅ FOR REAL HIDING, USE ICE — free, open source, actively maintained:
--      https://github.com/jordanbaird/Ice. It coexists fine with this.
--   ⌨️ WHAT IS REACHABLE is the half that suits a keyboard-driven setup
--      better anyway. ⇪M lists every status icon by owning app; type a
--      few letters and press ⏎ to open it. No aiming at a 22-pixel glyph
--      you cannot identify. ⇪⇧M prints an inventory. Accessibility only —
--      no Screen Recording, nothing covered, nothing moved.
--   🚨 ITS WORST FAILURE WOULD BE A FREEZE, NOT A CRASH. Reading another
--      app's Accessibility tree is a SYNCHRONOUS call into that app, and
--      Hammerspoon's main thread is your keyboard. Fifty apps with no
--      timeout is a plausible way to lose the Mac for a minute — 6.33.0's
--      ⌥Tab froze for exactly this reason. So every app element gets an
--      explicit 0.1s timeout BEFORE it is asked anything, the whole scan
--      is time-boxed at 2s and checked every iteration, and results are
--      cached. The suite drives forty deliberately wedged apps and fails
--      if the scan does not give up.
--   🐛 One of mine, caught by the tests: pcall(function() el:performAction
--      (a) end) DISCARDS the return value, so the success check never saw
--      it and AXShowMenu fired straight after a perfectly good AXPress —
--      activating every item twice. The `return` inside the wrapper is
--      load-bearing.
--   🧪 1,405 checks across eleven suites.
-- NEW IN 6.46.1 — init.lua GOES BACK TO BEING AN ORCHESTRATOR:
--   📉 3,735 LINES → 3,511, AND NOT ONE LINE OF CODE WAS TOUCHED. 6.44.11
--      cut this file from 6,012 to 3,376 by moving history out; within a
--      few releases it was back to TWELVE inline changelog entries against
--      a stated rule of five. Bloat creeps back about fifty lines a
--      release and nobody notices, because each release only adds a little.
--   🚨 AND IT NEARLY COST THREE VERSIONS OF HISTORY. 6.44.11, 6.44.12 and
--      6.44.13 existed ONLY in this header — they were never backfilled
--      into CHANGELOG.md. Trimming on the assumption that CHANGELOG.md was
--      complete would have deleted them silently. They were moved across
--      FIRST; CHANGELOG.md now holds all 114 versions.
--   🧬 A TEST NOW ENFORCES BOTH HALVES, because a convention nothing checks
--      is a convention that decays: at most five entries inline, and
--      nothing inline that CHANGELOG.md is missing. The second is the one
--      that matters — it makes losing history by trimming impossible.
--   📐 AND THE ARCHITECTURAL CLAIM IS NOW TESTED RATHER THAN ASSERTED. A
--      new tool costs init.lua its NAME in three profiles and nothing
--      else. Across the whole of 6.45.0 → 6.46.0, three new tools added
--      1,867 lines of module code and exactly NINE lines to init.lua.
--      The suite fails if a module name ever appears here as code.
--   🧪 1,358 checks across ten suites.

-- =====================================================================
-- WHAT EACH TOOL DOES :: ARCHITECTURE VERSION CONTROL: 6.49.0
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
-- ⇪⇧ ARROWS  POPUP NUDGING (§1.5)
--    Every popup in this config opens centered on whichever monitor
--    your frontmost app is on — no manual pinning. If you want it
--    elsewhere, nudge it with ⇪⇧ + arrow keys (hold to walk it).
--    ⇪⇧R resets the offset back to automatic.
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
-- ⇪O  OCR LOG SEARCH (§2)
--    When an image lands on the clipboard, Hammerspoon runs your
--    "HS OCR" Apple Shortcut automatically and indexes the extracted
--    text. ⌃⌥⌘O searches everything ever OCR'd; selecting a row
--    copies the text. NEW: copy image FILES in Finder (⌘C) and the
--    OCR text is also written into each file's Finder comment —
--    Spotlight-searchable, so meaningless filenames stop mattering.
--    ⌘⌃⌥⇧O opens the same history to EDIT or DELETE an entry instead —
--    fixes a bad OCR read in place, or clears out junk. Save with the
--    text cleared deletes it.
--
-- ✅ ⇪T  ASANA TASK CREATOR (§4 / §5)
--    Creates a task in your Asana project without opening a browser.
--    Format: Title | Description | Assignee | /path/to/attachment
--    All fields after Title are optional. Posts an auto-comment on
--    every new task and uploads an attachment if you provide a path.
--    30-day history is searchable (saved per-machine in OneDrive);
--    filter by typing in the box. Your typed text is a DRAFT: if
--    the popup closes before you create the task (click away, Esc),
--    ⌃⌥⌘T reopens with it intact. A live MIRROR panel above the box
--    shows your whole text, word-wrapped — long titles never scroll
--    out of sight.
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

-- 🔇 6.44.10 — QUIET THE CONSOLE SO IT IS WORTH READING. hs.hotkey logs
-- every enable and disable at info level. The ⌥Tab switcher binds 32 arrow
-- hotkeys when it opens and releases them when it closes (8 keys × 4
-- modifier masks, because hs.hotkey matches modifier flags EXACTLY, so a
-- bare-mask binding cannot fire while ⌥ is held). That is 64 console lines
-- per use of the switcher. Three switches in half a minute buried the only
-- lines that mattered — the boot report and the Capture Pad's send results
-- — under ~200 lines of bookkeeping, which is how a console stops being a
-- debugging tool. Warnings and errors still print; the routine chatter does
-- not. Set this to "info" if a hotkey ever fails to bind and you want the
-- play-by-play back.
pcall(function() hs.hotkey.setLogLevel("warning") end)

-- DYNAMIC HOME DIRECTORY RESOLUTION
local homeDir = os.getenv("HOME")

-- The boot clock starts here, before any real work, so §1.11's
-- report can say how long loading actually took.
_G.configVersion = "6.49.0"
_G.diagBootStart = hs.timer.secondsSinceEpoch()

-- A NO-OP STAND-IN for the diagnostics API, replaced by the real one in
-- §1.11. Sections earlier in the file log through _G.diag, and a section
-- that loaded before §1.11 — or a partial load that never reached it —
-- would otherwise throw on a logging call. A diagnostics system that can
-- cause the outage it exists to explain is worse than none.
_G.diag = { verbose = false, trail = {}, errors = {}, marks = {},
            say = function() end, warn = function() end,
            err = function() end, mark = function() end }

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
-- one file would mean OneDrive conflict copies). Existing files in
-- ~/.hammerspoon are adopted on first boot; originals left in place.
local historyFile   = logsDir .. "/asana_history-" .. hostTag .. ".json"
local clipboardFile = logsDir .. "/clipboard_history-" .. hostTag .. ".json"
adoptLegacyFile(historyFile,   hs.configdir .. "/asana_history.json")
adoptLegacyFile(clipboardFile, hs.configdir .. "/clipboard_history.json")

-- 💬 AUTO-COMMENT — this text is posted as a comment on every task you
-- create with the Task Creator (⌃⌥⌘T). Set it to "" to disable.
local autoCommentText = "Sent by Hammerspoon Task Creator \"⌃⌥⌘T\", file init.lua"

-- OCR log + the Apple Shortcuts shortcut the OCR daemon runs. A Mac
-- without that shortcut (checked at boot) just skips image OCR —
-- recreate the shortcut there, or rename yours here. The CSV is
-- per-machine (see hostTag above); existing shared-name data adopted.
local csvFile         = logsDir .. "/image_text-" .. hostTag .. ".csv"
local ocrShortcutName = "HS OCR"
adoptLegacyFile(csvFile, logsDir .. "/image_text.csv")

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
    ["alt+cmd+ctrl+t"]       = { {},        "t"     },  -- create task
    ["alt+cmd+ctrl+l"]       = { {},        "l"     },  -- list tasks
    -- ---- Clipboard / OCR / Activity ----
    ["alt+cmd+ctrl+v"]       = { {},        "v"     },  -- clipboard history
    ["alt+cmd+ctrl+shift+v"] = { {"shift"}, "v"     },  -- clipboard EDIT
    ["alt+cmd+ctrl+o"]       = { {},        "o"     },  -- OCR search
    ["alt+cmd+ctrl+shift+o"] = { {"shift"}, "o"     },  -- OCR EDIT
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
    -- for constantly), and the Document Watcher moved to ⇪⇧W.
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
    return hsHotkeyBindOriginal(mods, key, fn, releasedFn, repeatFn)
end

-- =====================================================================
-- 1. GLOBAL STATE INITIALIZATION
-- =====================================================================
_G.choosers = {}

_G.asanaTaskHistory = {}  -- populated from disk below after historyFile is defined

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
local csOK, csErr = pcall(function()
    local path = hs.configdir .. '/core/cheatsheet.lua'
    local chunk, loadErr = loadfile(path)
    if not chunk then error(loadErr or ('cannot read ' .. path), 0) end
    chunk()({
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
-- 2. UTILITY & OCR ENGINE
-- =====================================================================
local function formatDuration(seconds)
    if seconds < 60 then return seconds .. "s" end
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    if mins < 60 then return mins .. "m " .. secs .. "s" end
    local hrs = math.floor(mins / 60)
    return hrs .. "h " .. (mins % 60) .. "m"
end

local function loadClipboardHistoryIntoCache()
    local f = io.open(clipboardFile, "r")
    if not f then _G.clipboardCache = {} return end
    local content = f:read("*a"); f:close()
    local success, data = pcall(hs.json.decode, content)
    if success and type(data) == "table" then
        _G.clipboardCache = data
        return
    end
    -- 6.15.2 FIX: this used to fall back to {} silently — and the VERY
    -- NEXT save (any future edit or copy) would then overwrite the
    -- broken file with that empty array, permanently losing whatever
    -- was still in it. Back up the unreadable file first and say so
    -- loudly, instead of quietly starting over.
    _G.clipboardCache = {}
    local backupPath = clipboardFile .. ".corrupt-" .. os.date("%Y%m%d-%H%M%S")
    local bf = io.open(backupPath, "w")
    if bf then bf:write(content); bf:close() end
    hs.alert.show("⚠️ Clipboard history was unreadable — backed up, starting fresh (see Console)", 8)
    print("🚨 Clipboard history JSON failed to parse — raw content backed up to " .. backupPath)
end
loadClipboardHistoryIntoCache()

-- Clipboard history is written on EVERY copy, so a failed write here
-- (OneDrive quit / Logs folder online-only) is the most likely place
-- to notice a storage problem — it warns once instead of silently
-- dropping history (see warnWriteFailed, §0.1).
local function saveClipboardToDisk(data)
    local body = hs.json.encode(data)
    -- 6.15.2 FIX: verify before committing. If encode ever produces
    -- something that doesn't round-trip, DON'T write it — that's what
    -- silently corrupted the file in the first place, discovered only
    -- much later (next reload) as "history wiped". Abort and warn now.
    local ok, decoded = pcall(hs.json.decode, body)
    if not ok or type(decoded) ~= "table" then
        hs.alert.show("⚠️ Clipboard history NOT saved — bad encode, existing file left untouched (see Console)", 6)
        print("🚨 saveClipboardToDisk: hs.json.encode produced unparseable JSON — write aborted")
        return
    end
    local f = io.open(clipboardFile, "w")
    if f then f:write(body); f:close()
    else warnWriteFailed("clipboard history") end
end

-- OCR Daemon (Apple Shortcut Integrated)
-- Boot check: does THIS Mac's Shortcuts app have the OCR shortcut?
-- (nil = still checking → optimistic; false = confirmed missing →
-- image OCR skips quietly on this machine; text clipboard unaffected)
_G.ocrShortcutAvailable = nil
pcall(function()
    hs.task.new("/usr/bin/shortcuts", function(exitCode, stdOut)
        if exitCode == 0 and type(stdOut) == "string" then
            _G.ocrShortcutAvailable = (stdOut:find(ocrShortcutName, 1, true) ~= nil)
            if not _G.ocrShortcutAvailable then
                print("ℹ️ Shortcuts app has no '" .. ocrShortcutName .. "' — image OCR off on this Mac (recreate the shortcut to enable)")
            end
        end
    end, { "list" }):start()
end)

-- Strips anything not producible by a standard US QWERTY keyboard (the
-- full printable ASCII range, 0x20-0x7E, plus tab/CR/LF) — OCR output
-- routinely contains stray Unicode glyphs (smart quotes, box-drawing
-- artifacts, emoji, mis-decoded bytes) that don't belong in a CSV row
-- or a Finder comment. Characters outside that set are REMOVED, not
-- replaced — no placeholder is inserted in their place.
local function stripToQwerty(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("[^\9\13\10\32-\126]", ""))
end

local function processAutomaticImageOCR(img)
    if _G.ocrShortcutAvailable == false then return end
    if not img then return end
    local imgPath = "/tmp/hs_auto_ocr.png"

    if img:saveToFile(imgPath) then
        hs.task.new("/usr/bin/shortcuts", function(exitCode, stdOut, stdErr)
            os.remove(imgPath)

            local extractedText = stdOut
            if not extractedText or #extractedText == 0 then
                extractedText = hs.pasteboard.readString()
            end

            if extractedText and #extractedText > 0 then
                extractedText = stripToQwerty(extractedText:gsub("%z", ""):gsub("\x1A", ""))

                if #extractedText > 0 then
                    local f = io.open(csvFile, "a")
                    if f then
                        f:write(os.date("%Y-%m-%d %H:%M:%S") .. ',"' ..
                            extractedText:gsub('"', '""'):gsub('\r\n', '\\n'):gsub('\r', '\\n'):gsub('\n', '\\n') .. '"\n')
                        f:close()
                        hs.alert.show("📋 OCR Indexed")
                    else
                        warnWriteFailed("OCR log")
                    end
                end
            end
        end, {"run", ocrShortcutName, "-i", imgPath}):start()
    end
end

-- ---- FILE-TAGGING OCR (6.11.0) --------------------------------------
-- Copy image FILES in Finder (⌘C) → each is OCR'd and the text is
-- written into the file's Finder comment (Get Info → Comments), which
-- Spotlight & Finder search index — so a folder full of meaningless
-- filenames becomes searchable by what's written IN the images. The
-- text also goes to the ⌃⌥⌘O history like any other OCR.
-- Rules & limits (see the 6.11.0 changelog note): existing comments
-- are never overwritten; needs one-time Automation permission for
-- Finder; comments are local metadata (OneDrive doesn't sync them);
-- raw clipboard images have no file to tag and behave as before.
local ocrTagMaxChars        = 500  -- Finder-comment length cap
local ocrTagMaxFilesPerCopy = 15   -- safety cap per ⌘C (floods ignored)
local ocrImageExtensions = { png = true, jpg = true, jpeg = true, gif = true,
    tif = true, tiff = true, heic = true, heif = true, webp = true, bmp = true }

local function ocrUrlToPath(u)
    if type(u) ~= "string" then return nil end
    if not u:match("^file://") then return nil end
    local p = u:gsub("^file://", "")
    p = p:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    return p
end

-- Which image files (if any) does the clipboard point at right now?
-- Finder puts a public.file-url flavor on the pasteboard for every
-- copied file. 6.11.1: read the RAW pasteboard items (readAllData) —
-- the reliable route — with readURL and plain-text paths kept as
-- fallbacks for other tools. Every decision is narrated in the
-- Console so a miss is never a mystery again.
local function clipboardImageFilePaths()
    local paths, seen, sawFileURL = {}, {}, false
    local firstMiss = nil  -- 6.11.2: first rejected candidate, for diagnosis
    local function consider(candidate)
        if #paths >= ocrTagMaxFilesPerCopy then return end
        if type(candidate) ~= "string" or seen[candidate] then return end
        seen[candidate] = true
        local ext = candidate:match("%.(%w+)$")
        local preview = stripToQwerty(candidate:sub(1, 160))
        if ext and ocrImageExtensions[ext:lower()] then
            local mode = nil
            pcall(function() mode = hs.fs.attributes(candidate, "mode") end)
            if mode == "file" then
                table.insert(paths, candidate)
            elseif not firstMiss then
                firstMiss = "ext ." .. ext .. " is supported, but not a readable local file (mode = "
                    .. tostring(mode) .. ") — raw value: \"" .. preview .. "\""
            end
        elseif not firstMiss then
            firstMiss = (ext and ("ext ." .. ext .. " isn't in the supported list") or "no file extension found")
                .. " — raw value: \"" .. preview .. "\""
        end
    end

    -- Method 1 (primary): raw pasteboard items, every flavor of every
    -- copied item keyed by its UTI — Finder always includes
    -- public.file-url here, one per file.
    -- Hammerspoon's readAllData() shape has drifted across versions:
    -- normally an array of {UTI = data} tables, but a single copied
    -- item has been seen returned as one bare {UTI = data} table
    -- instead of a one-element array (handled below), and some builds
    -- nest each representation as {uti = ..., data = ...} rather than
    -- keying by UTI directly (also handled below) — a shape change
    -- degrades to methods 2/3 instead of going silent.
    pcall(function()
        local items = hs.pasteboard.readAllData()
        if items ~= nil and type(items) ~= "table" then
            print("🏷 OCR tag: hs.pasteboard.readAllData() returned a " .. type(items)
                .. " instead of a table — Hammerspoon version mismatch, falling back to older readers")
            return
        end
        if type(items) ~= "table" then return end
        if #items == 0 and next(items) ~= nil then items = { items } end
        for _, item in ipairs(items) do
            if type(item) == "table" then
                for k, v in pairs(item) do
                    if type(k) == "string" and k:lower():find("file%-url", 1, false) then
                        sawFileURL = true
                        if type(v) == "string" then consider(ocrUrlToPath(v) or v) end
                    elseif type(v) == "table" then
                        -- alternate shape seen on some builds: an array of
                        -- {uti = "...", data = "..."} entries instead of a
                        -- UTI-keyed dictionary
                        local uti  = v.uti or v.UTI or v.type
                        local data = v.data or v.value or v.contents
                        if type(uti) == "string" and uti:lower():find("file%-url", 1, false) then
                            sawFileURL = true
                            if type(data) == "string" then consider(ocrUrlToPath(data) or data) end
                        end
                    end
                end
            end
        end
    end)

    -- Method 2 (fallback): the older readURL API — shape varies by
    -- Hammerspoon version, which is why it is no longer primary
    if #paths == 0 then
        pcall(function()
            local urls = hs.pasteboard.readURL(nil, true)
            if type(urls) ~= "table" then return end
            if urls.url or urls.filePath then urls = { urls } end
            for _, item in ipairs(urls) do
                local u = (type(item) == "table" and (item.url or item.filePath)) or item
                if type(u) == "string" and u:match("^file://") then sawFileURL = true end
                consider(ocrUrlToPath(u) or u)
            end
        end)
    end

    -- Method 3 (fallback): plain text that is already a POSIX path
    -- (some tools copy full paths as text; Finder copies only NAMES
    -- as text, which rightly never match here)
    if #paths == 0 then
        pcall(function()
            local s = hs.pasteboard.readString()
            if type(s) == "string" and #s < 4000 then
                for line in s:gmatch("[^\r\n]+") do
                    if line:sub(1, 1) == "/" then consider(line) end
                end
            end
        end)
    end

    -- Self-diagnosis: file URL(s) present but nothing usable came out
    -- — non-image files land here too (normal), so only note it when
    -- it looks like images were intended
    if sawFileURL and #paths == 0 then
        print("🏷 OCR tag: clipboard has file URL(s) but no image files matched (non-image files, unsupported extension, or unreadable path)")
        if firstMiss then print("   ↳ first candidate: " .. firstMiss) end
    end
    return paths
end

local function ocrEscapeAS(s)
    return (s:gsub("\\", "\\\\"):gsub('"', '\\"'))
end

-- Write the OCR text as the file's Finder comment — via Finder
-- scripting, the only route macOS reliably Spotlight-indexes (writing
-- the xattr directly is NOT dependably picked up by Spotlight).
-- Never clobbers: only writes when the current comment is empty.
-- Returns true only when a comment was actually written.
local function ocrWriteFinderComment(path, text)
    local snippet = text:gsub("%s+", " "):match("^%s*(.-)%s*$"):sub(1, ocrTagMaxChars)
    if snippet == "" then return false end
    local script = 'tell application "Finder"\n'
        .. 'set theFile to (POSIX file "' .. ocrEscapeAS(path) .. '") as alias\n'
        .. 'if (comment of theFile) is "" then\n'
        .. 'set comment of theFile to "' .. ocrEscapeAS(snippet) .. '"\n'
        .. 'return "written"\n'
        .. 'else\n'
        .. 'return "skipped"\n'
        .. 'end if\n'
        .. 'end tell'
    local wrote = false
    pcall(function()
        local ok, result = hs.osascript.applescript(script)
        wrote = (ok and result == "written")
        if not ok then
            print("⚠️ OCR tag: Finder scripting failed for " .. path
                .. " — grant Hammerspoon Automation permission for Finder "
                .. "(System Settings → Privacy & Security → Automation)")
        end
    end)
    return wrote
end

-- One copied batch: OCR each file with the same "HS OCR" shortcut the
-- clipboard-image path uses, then log to history + tag the file.
-- (No pasteboard fallback for the text here — for file OCR the
-- clipboard holds the file reference, not the extracted text.)
local function processClipboardFileOCR(paths)
    if _G.ocrShortcutAvailable == false then
        print("🏷 OCR tag: skipped — Shortcuts app has no '" .. ocrShortcutName .. "' on this Mac")
        return
    end
    for _, p in ipairs(paths) do
        hs.task.new("/usr/bin/shortcuts", function(exitCode, stdOut, stdErr)
            local textOut = stdOut
            if not textOut or #textOut == 0 then return end
            textOut = stripToQwerty(textOut:gsub("%z", ""):gsub("\x1A", ""))
            if #textOut == 0 then return end

            local f = io.open(csvFile, "a")
            if f then
                f:write(os.date("%Y-%m-%d %H:%M:%S") .. ',"' ..
                    textOut:gsub('"', '""'):gsub('\r\n', '\\n'):gsub('\r', '\\n'):gsub('\n', '\\n') .. '"\n')
                f:close()
            else
                warnWriteFailed("OCR log")
            end

            local name = p:match("[^/]+$") or p
            if ocrWriteFinderComment(p, textOut) then
                hs.alert.show("🏷 OCR → Finder comment: " .. name)
            else
                print("ℹ️ OCR tag skipped for " .. name .. " (existing comment kept, or Finder scripting unavailable) — text is in the ⌃⌥⌘O history")
                hs.alert.show("📋 OCR indexed (file comment untouched): " .. name)
            end
        end, {"run", ocrShortcutName, "-i", p}):start()
    end
end

local function loadOCRHistory()
    local f = io.open(csvFile, "rb")
    local items = {}
    if f then
        local content = f:read("*a")
        f:close()

        if content then
            content = content:gsub("%z", "")
            for line in content:gmatch("([^\r\n]+)") do
                local timestamp, rawText = line:match("^([^,]+),(.*)$")
                if timestamp and rawText then
                    local cleanText = rawText:gsub('^"', ''):gsub('"$', ''):gsub('""', '"'):gsub('\\n', '\n')
                    local shortTitle = cleanText:gsub("%s+", " "):sub(1, 65)
                    table.insert(items, 1, { text = shortTitle, subText = "🕒 " .. timestamp, rawText = cleanText })
                end
            end
        end
    end
    return items
end

-- =====================================================================
-- 3. BACKGROUND MONITORING
-- =====================================================================
-- ✏️ Clipboard history size — how many copied texts to keep. Each new
-- copy is checked against the whole list: an item you've copied before
-- moves to the front (fresh timestamp) instead of occupying two slots.
-- Items over ~1 MB are left out of history (they'd bloat the JSON file
-- that gets rewritten on every copy) — a console line notes the skip.
local clipboardHistoryMax  = 1000
local clipboardMaxItemSize = 1000000  -- ~1 MB per item

local lastChangeCount = hs.pasteboard.changeCount()
_G.clipboardTimer = hs.timer.doEvery(0.5, function()
    local currentChangeCount = hs.pasteboard.changeCount()
    if currentChangeCount ~= lastChangeCount then
        lastChangeCount = currentChangeCount

        -- Copied image FILES take priority (6.11.0): OCR + tag each
        -- one, and skip the image/text handling for this clipboard
        -- change (a Finder file-copy would otherwise just deposit the
        -- file's pathname into text history).
        local copiedImageFiles = clipboardImageFilePaths()
        if #copiedImageFiles > 0 then
            print("🏷 OCR tag: " .. #copiedImageFiles .. " copied image file(s) detected — running OCR on each")
            processClipboardFileOCR(copiedImageFiles)
        else
        local img = hs.pasteboard.readImage()
        if img then
            processAutomaticImageOCR(img)
        else
            local text = hs.pasteboard.readString()
            if text and #text > 0 then
                if #text > clipboardMaxItemSize then
                    print("📋 Clipboard item not saved to history (over 1 MB)")
                elseif not _G.clipboardCache[1] or _G.clipboardCache[1].text ~= text then
                    -- Dedupe: same text anywhere in history moves to front
                    for i = #_G.clipboardCache, 1, -1 do
                        if _G.clipboardCache[i].text == text then
                            table.remove(_G.clipboardCache, i)
                        end
                    end
                    table.insert(_G.clipboardCache, 1, { date = os.date("%b %d %H:%M"), text = text })
                    if #_G.clipboardCache > clipboardHistoryMax then
                        table.remove(_G.clipboardCache)
                    end
                    saveClipboardToDisk(_G.clipboardCache)
                end
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
hs.hotkey.bind({}, "F18",
    function() _G.hyperModal:enter() end,
    function() _G.hyperModal:exit()  end)

-- ---- binding helper + conflict sentry for the hyper namespace --------
-- The §0.3 sentry only sees hs.hotkey.bind, so once shortcuts moved into
-- the modal they'd have become invisible to it — and a silently-dead
-- shortcut is exactly the failure this config exists to prevent. This is
-- the same guard, for the hyper keyspace.
_G.hyperBound = {}   -- normalized combo -> what claimed it
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
end

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
            local send = function()
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

    _G.hyperShortcutCount = #_G.hyperMigrations
    _G.hyperForwardCount  = forwarded
end

-- Apply the remap ASYNCHRONOUSLY. Deliberately hs.task and not a
-- blocking call: §3.7's 11-second beachball was caused by slow work on
-- the main thread at boot, and this must never become the next one.
if hyperEnabled then
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

-- OCR chooser
_G.choosers.ocr = hs.chooser.new(function(c)
    if c and c.rawText then
        hs.pasteboard.setContents(c.rawText)
        hs.alert.show("📋 Copied")
    end
end):placeholderText("Search OCR Logs...")

-- Clipboard chooser — searches the FULL text of every saved item, not
-- just the 100 characters a row displays. Matches are newest first,
-- capped at 250 rows for snappy typing (narrow the search for more).
_G.choosers.clipboard = hs.chooser.new(function(c)
    if c and c.rawText then
        hs.pasteboard.setContents(c.rawText)
        hs.alert.show("📋 Sync")
    end
end):placeholderText("Search Clipboard History...")

local function renderClipboardChoices(query)
    local q = (query or ""):lower():match("^%s*(.-)%s*$")
    local choices = {}
    for _, item in ipairs(_G.clipboardCache) do
        if q == "" or item.text:lower():find(q, 1, true) then
            local oneLine = item.text:gsub("%s+", " ")
            table.insert(choices, {
                text    = oneLine:sub(1, 100),
                subText = item.date or "",
                rawText = item.text,
            })
            if #choices >= 250 then break end
        end
    end
    if #choices == 0 then
        table.insert(choices, {
            text    = (q == "") and "Clipboard history is empty" or ("No matches for \"" .. q .. "\""),
            subText = "Searches the full text of every saved item",
        })
    end
    _G.choosers.clipboard:choices(choices)
end

_G.choosers.clipboard:queryChangedCallback(function(query)
    local ok, err = pcall(renderClipboardChoices, query)
    if not ok then
        print("🚨 Clipboard chooser render error: " .. tostring(err))
        _G.choosers.clipboard:choices({
            { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

-- =====================================================================
-- TASK HISTORY — Persistent 30-day store (OneDrive, machine-tagged)
-- =====================================================================
local TASK_HISTORY_DAYS = 30

local function loadTaskHistory()
    local f = io.open(historyFile, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local ok, data = pcall(hs.json.decode, content)
    if ok and type(data) == "table" then return data end
    return {}
end

local function pruneTaskHistory(history)
    local cutoff = os.time() - (TASK_HISTORY_DAYS * 86400)
    local pruned = {}
    for _, entry in ipairs(history) do
        if type(entry.timestamp) == "number" and entry.timestamp >= cutoff then
            table.insert(pruned, entry)
        end
    end
    return pruned
end

local function saveTaskHistory(history)
    local f = io.open(historyFile, "w")
    if f then f:write(hs.json.encode(history)); f:close()
    else warnWriteFailed("task history") end
end

-- Boot: load from disk, prune old entries, sync into global
local _diskHistory = pruneTaskHistory(loadTaskHistory())
saveTaskHistory(_diskHistory)           -- persist the pruned version immediately
_G.asanaTaskHistory = _diskHistory      -- override the empty table set earlier

-- =====================================================================
-- ATTACHMENT UPLOAD — multipart via curl (hs.http has no multipart support)
-- =====================================================================
local function uploadAttachmentToTask(taskId, filePath, onDone)
    -- Verify the file actually exists before attempting upload
    local testF = io.open(filePath, "r")
    if not testF then
        hs.alert.show("⚠️ Attachment not found: " .. filePath)
        if onDone then onDone(false) end
        return
    end
    testF:close()

    hs.alert.show("📎 Uploading attachment…")

    hs.task.new("/usr/bin/curl", function(exitCode, stdOut, stdErr)
        if exitCode == 0 then
            hs.alert.show("📎 Attachment uploaded")
            if onDone then onDone(true) end
        else
            hs.alert.show("❌ Attachment upload failed")
            print("Attachment curl error: " .. tostring(stdErr))
            if onDone then onDone(false) end
        end
    end, {
        "-s", "-o", "/dev/null",
        "-w", "%{http_code}",
        "-X", "POST",
        "https://app.asana.com/api/1.0/tasks/" .. taskId .. "/attachments",
        "-H", "Authorization: Bearer " .. asanaToken,
        "-F", "file=@" .. filePath
    }):start()
end

-- =====================================================================
-- PIPE PARSER — splits "Title | Desc | Assignee | /path/to/file"
--   • All fields after Title are optional
--   • Assignee can be a GID (numeric) or an email address
-- =====================================================================

-- Split on "|" while PRESERVING empty fields, so "time | | | /path" and
-- even "time|||/path" (no spaces) both land the path in field #4.
local function splitPipes(raw)
    local parts, start = {}, 1
    while true do
        local sep = raw:find("|", start, true)
        if sep then
            table.insert(parts, raw:sub(start, sep - 1):match("^%s*(.-)%s*$"))
            start = sep + 1
        else
            table.insert(parts, raw:sub(start):match("^%s*(.-)%s*$"))
            break
        end
    end
    return parts
end

-- Clean up a pasted attachment path so small slips still work:
--   • strips surrounding single/double quotes
--   • expands  ~  and  ~/…  to your home folder
--   • snaps to the first "/" so stray leading junk (e.g. "r /Users/…")
--     is dropped and the path starts where the real path starts
local function normalizeAttachmentPath(raw)
    if not raw or raw == "" then return "" end
    local s = raw:match("^%s*(.-)%s*$")             -- trim ends
    s = s:gsub("^[\"']", ""):gsub("[\"']$", "")     -- strip wrapping quotes
    s = s:match("^%s*(.-)%s*$")                      -- trim again (quotes may have hidden spaces)

    -- Expand ~ BEFORE looking for the first slash
    if s == "~" then
        s = homeDir
    elseif s:sub(1, 2) == "~/" then
        s = homeDir .. s:sub(2)
    end

    -- If anything precedes the first "/", drop it. Absolute paths start
    -- at "/", so "r /Users/…" and "  /Users/…" both become "/Users/…".
    local slashIdx = s:find("/", 1, true)
    if slashIdx and slashIdx > 1 then
        s = s:sub(slashIdx)
    end

    return s
end

local function parseTaskInput(raw)
    local parts = splitPipes(raw)
    return {
        title      = parts[1] or "",
        desc       = parts[2] or "",
        assignee   = parts[3] or "",
        attachment = normalizeAttachmentPath(parts[4] or ""),
    }
end

-- =====================================================================
-- CHOOSER RENDERER — live preview while typing
-- =====================================================================
local function renderTaskChoices(query)
    local choices = {}
    local searchKey = ""

    if query and #query > 0 then
        local p = parseTaskInput(query)
        searchKey = p.title:lower()

        -- 6.16.13: INLINE ASSIGNEE AUTOCOMPLETE — while the cursor is
        -- still IN the Assignee segment (title | desc | <here>, i.e.
        -- exactly two pipes typed so far and no third one yet — a
        -- completed 3rd pipe means you've moved on to the attachment
        -- field), matching names from the ⌃⌥⌘B team roster show as
        -- suggestions right here. Picking one splices the exact name
        -- into the query and reopens (see the chooser callback below) —
        -- no more leaving this picker, copying a name from a separate
        -- window, and coming back to paste it.
        local pipeCount = select(2, query:gsub("|", "|"))
        if pipeCount == 2 and p.assignee ~= "" then
            local partial = p.assignee:lower()
            local shown = 0
            for _, m in ipairs(_G.asanaTeamMembers) do
                if m.name:lower():find(partial, 1, true) then
                    table.insert(choices, {
                        text                  = "👤 " .. m.name,
                        subText               = (m.email or "") .. "  ·  Enter fills the Assignee field",
                        isAssigneeSuggestion  = true,
                        memberName            = m.name,
                    })
                    shown = shown + 1
                    if shown >= 8 then break end
                end
            end
            -- 6.16.14 FIX: zero matches showed NOTHING here — indistinguishable
            -- from the feature not working at all. isHistory=true makes Enter
            -- on this row a safe no-op (same pattern "No matching past tasks"
            -- already uses below), so it can't get submitted as a fake assignee.
            if shown == 0 then
                table.insert(choices, {
                    text      = "👤 No team member matches \"" .. p.assignee .. "\"",
                    subText   = "Keep typing, or use their exact email instead",
                    isHistory = true,
                })
            end
        end

        -- Build a compact summary line for the subText
        local hints = {}
        if p.desc      ~= "" then table.insert(hints, "📝 " .. p.desc:sub(1, 40)) end
        if p.assignee  ~= "" then table.insert(hints, "👤 " .. p.assignee) end
        if p.attachment~= "" then table.insert(hints, "📎 " .. (p.attachment:match("[^/]+$") or p.attachment)) end  -- folder paths (trailing /) have no basename → show the path itself
        local subTextMsg = #hints > 0 and table.concat(hints, "  ·  ") or "Press Enter to create…"

        table.insert(choices, {
            text       = "➕ Create: " .. (p.title ~= "" and p.title or "…"),
            subText    = subTextMsg,
            isAction   = true,
            rawTitle   = p.title,
            rawDesc    = p.desc,
            rawAssignee= p.assignee,
            rawAttach  = p.attachment,
        })
    end

    -- Append persisted history (newest first), FILTERED against searchKey.
    -- Matches against title, description, and assignee so you can search
    -- by any of those; empty searchKey (nothing typed) shows everything.
    local matchCount = 0
    if #_G.asanaTaskHistory > 0 then
        for i = #_G.asanaTaskHistory, 1, -1 do
            local e = _G.asanaTaskHistory[i]
            local haystack = ((e.title or "") .. " " .. (e.desc or "") .. " " .. (e.assignee or "")):lower()
            if searchKey == "" or haystack:find(searchKey, 1, true) then
                matchCount = matchCount + 1
                table.insert(choices, {
                    text    = e.title or "(untitled)",
                    subText = e.displaySub or "",
                    -- mark as history so Enter on these is a no-op (they're read-only)
                    isHistory = true,
                })
            end
        end
    end

    if #_G.asanaTaskHistory == 0 and (not query or #query == 0) then
        table.insert(choices, {
            text    = "Type a task name…",
            subText = "Format: Title | Description | Assignee | /path/to/attachment"
        })
    elseif searchKey ~= "" and matchCount == 0 then
        table.insert(choices, {
            text      = "No matching past tasks",
            subText   = "Searched title, description & assignee for \"" .. searchKey .. "\"",
            isHistory = true,
        })
    end

    _G.choosers.task:choices(choices)
end

-- =====================================================================
-- DRAFT MIRROR — full wrapped view of what you're typing (6.10.2)
-- =====================================================================
-- HONEST LIMIT this works around: hs.chooser's search field is a
-- native macOS single-line input — there is no API to make the field
-- itself wrap, so a long title scrolls out of view inside it. This
-- companion hs.canvas panel (same tech + placement as the dashboard's
-- legend strip, §6) sits just above the picker and mirrors the ENTIRE
-- text, word-wrapped, live with every keystroke. Up to 8 lines tall;
-- appears the moment the box has text, vanishes when it's empty or
-- the popup resolves, and rides along with ⌃⌥⌘-arrow nudges.
_G.taskMirrorCanvas = nil

local function taskMirrorHide()
    if _G.taskMirrorCanvas then
        pcall(function() _G.taskMirrorCanvas:delete() end)
        _G.taskMirrorCanvas = nil
    end
end

local function taskMirrorShow(text)
    taskMirrorHide()
    if not text or text == "" then return end
    local chooser = _G.choosers.task
    if not chooser then return end
    local visible = false
    pcall(function() visible = chooser:isVisible() end)
    if not visible then return end

    -- Reuse the exact placement showPopup recorded for the picker —
    -- same reasoning as the legend strip (§6): resolving the screen
    -- again could disagree and draw the mirror on the wrong monitor.
    local place = _G.lastPopupPlacement
    local screen = (place and place.screen) or resolveBaseScreen()
    local sf = screen:frame()
    local topLeft = (place and place.point) or chooserTopLeft(chooser, screen)
    local pct = 40
    local okW, w = pcall(function() return chooser:width() end)
    if okW and type(w) == "number" and w > 0 and w <= 100 then pct = w end
    local panelW = sf.w * (pct / 100)

    -- Height: estimate wrapped line count from average glyph width.
    -- The canvas wraps the text itself (textLineBreak below) — this
    -- estimate only sizes the panel, so being a little off is fine.
    local textSize, pad, maxLines = 16, 12, 8
    local charsPerLine = math.max(10, math.floor((panelW - pad * 2) / (textSize * 0.55)))
    local lines = math.min(maxLines, math.max(1, math.ceil(#text / charsPerLine)))
    local lineH = textSize + 6
    local panelH = pad * 2 + lines * lineH

    -- Just above the picker's search field, clamped on-screen — the
    -- same exact-placement trick the legend uses (§6): the picker's
    -- top-left is a position we set ourselves, so no estimation.
    local panelY = math.max(sf.y + 4, topLeft.y - panelH - 8)

    local canvas = hs.canvas.new({ x = topLeft.x, y = panelY, w = panelW, h = panelH })
    if not canvas then return end

    canvas:appendElements({
        {
            type = "rectangle", action = "fill",
            fillColor = { red = 0.11, green = 0.11, blue = 0.13, alpha = panelAlpha },
            roundedRectRadii = { xRadius = 12, yRadius = 12 },
        },
        {
            type = "text", text = text,
            textSize = textSize, textColor = { white = 0.95 },
            textLineBreak = "wordWrap",
            frame = { x = pad, y = pad, w = panelW - pad * 2, h = panelH - pad * 2 },
        },
    })
    pcall(function() canvas:level(hs.canvas.windowLevels.overlay) end)
    -- Same Spaces/full-screen visibility declarations as the legend
    -- and cheat sheet — without them the mirror can't appear over
    -- native full-screen apps
    pcall(function() canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
    canvas:show()
    _G.taskMirrorCanvas = canvas
end

-- Nudging (⌃⌥⌘ arrows) repositions the picker — §1.5 calls this so
-- the mirror rides along, exactly like the dashboard legend does.
_G.taskMirrorSync = function()
    if _G.taskMirrorCanvas then taskMirrorShow(_G.taskDraft or "") end
end

-- =====================================================================
-- TASK CHOOSER
-- =====================================================================
_G.choosers.task = hs.chooser.new(function(choice)
    -- History rows are read-only; ignore selection
    if not choice or choice.isHistory then taskMirrorHide(); return end

    -- Picking an inline assignee suggestion is an AUTOCOMPLETE, not a
    -- submit: splice the exact name into the Assignee segment and
    -- reopen with it, same as the draft-restore reopen below — Enter
    -- here should never create the task.
    if choice.isAssigneeSuggestion then
        local parts = splitPipes(_G.taskDraft or "")
        parts[3] = choice.memberName
        local rebuilt = (parts[1] or "") .. " | " .. (parts[2] or "") .. " | " .. parts[3]
            .. (parts[4] and (" | " .. parts[4]) or " | ")
        _G.taskDraft = rebuilt
        _G.choosers.task:query(rebuilt)
        renderTaskChoices(rebuilt)  -- explicit: programmatic query() doesn't re-fire the callback
        showPopup(_G.choosers.task)
        pcall(taskMirrorShow, rebuilt)
        return
    end

    taskMirrorHide()   -- popup resolved (pick / Esc / click away)

    if choice.isAction then
        local title    = choice.rawTitle
        local desc     = choice.rawDesc
        local assignee = choice.rawAssignee
        local attach   = choice.rawAttach

        if title == "" then
            hs.alert.show("⚠️ Task title cannot be empty")
            return
        end

        -- Build display summary for history subText
        local subParts = {}
        if desc     ~= "" then table.insert(subParts, "📝 " .. desc:sub(1, 35)) end
        if assignee ~= "" then table.insert(subParts, "👤 " .. assignee) end
        if attach   ~= "" then table.insert(subParts, "📎 " .. (attach:match("[^/]+$") or attach)) end

        -- Asana's API rejects a display name outright (the actual bug:
        -- "Not a valid actor ID: Lee") — assignee must be "me", a
        -- numeric GID, or an email. Resolve a typed name against the
        -- cached team roster (§3.5) before it ever reaches the API;
        -- an unresolvable name ABORTS instead of sending a doomed
        -- request, so the failure is a clear alert, not a Console error.
        local function resolveAssignee(raw)
            if raw == "" then return "" end
            local lower = raw:lower()
            if lower == "me" or lower == "myself" or lower == "i" then return "me" end
            -- 6.16.14 FIX: real Asana GIDs are long (15+ digits, e.g. this
            -- file's own asanaWorkspaceId/asanaProjectId) — a short digit
            -- string like "1" isn't one, but ^%d+$ blindly accepted it
            -- and sent it straight to the API unchecked, producing a raw
            -- "Not a valid actor ID: 1" error instead of our own clear
            -- "no match" alert. Require 6+ digits before trusting it.
            if raw:match("^%d%d%d%d%d%d+$") then return raw end          -- already a GID
            if raw:match("^[%w.+-]+@[%w.-]+%.%a+$") then return raw end  -- email
            for _, m in ipairs(_G.asanaTeamMembers) do
                if m.name:lower() == lower then return m.gid end
            end
            for _, m in ipairs(_G.asanaTeamMembers) do
                if m.name:lower():find(lower, 1, true) then return m.gid end
            end
            return nil
        end

        local resolvedAssignee = resolveAssignee(assignee)
        if assignee ~= "" and not resolvedAssignee then
            hs.alert.show("⚠️ No team member matches \"" .. assignee
                .. "\" — ⌃⌥⌘B to browse names, or use their email", 5)
            return
        end

        -- Create history entry (timestamp used for 30-day pruning)
        local historyEntry = {
            title      = title,
            timestamp  = os.time(),
            displaySub = "⏳ Posting…" .. (#subParts > 0 and "  ·  " .. table.concat(subParts, "  ·  ") or ""),
            desc       = desc,
            assignee   = assignee,
            attachment = attach,
        }
        table.insert(_G.asanaTaskHistory, historyEntry)

        -- Build Asana task payload
        local payloadData = { name = title, projects = { asanaProjectId } }
        if desc ~= "" then payloadData.notes = desc end
        if resolvedAssignee ~= "" then payloadData.assignee = resolvedAssignee end
        local body = hs.json.encode({ data = payloadData })

        hs.http.asyncPost("https://app.asana.com/api/1.0/tasks", body, {
            ["Authorization"] = "Bearer " .. asanaToken,
            ["Content-Type"]  = "application/json"
        }, function(status, responseBody)
            if status == 200 or status == 201 then
                hs.alert.show("✅ Task Created: " .. title)
                historyEntry.displaySub = "✅ " .. os.date("%b %d %H:%M") ..
                    (#subParts > 0 and "  ·  " .. table.concat(subParts, "  ·  ") or "")

                -- Parse the new task's GID once — used for comments & attachments
                local parsed  = _G.safeJson(responseBody, "asana/newtask")
                local taskGid = parsed and parsed.data and parsed.data.gid

                if taskGid then
                    -- 💬 Auto-comment (configured at top of file; "" disables)
                    if autoCommentText ~= "" then
                        _G.service.call("asana.addComment", taskGid, autoCommentText)
                    end

                    -- 📎 Attachment upload
                    if attach ~= "" then
                        uploadAttachmentToTask(taskGid, attach, function(ok)
                            if ok then
                                historyEntry.displaySub = historyEntry.displaySub .. "  ·  📎 attached"
                            else
                                historyEntry.displaySub = historyEntry.displaySub .. "  ·  ⚠️ attach failed"
                            end
                            saveTaskHistory(_G.asanaTaskHistory)
                        end)
                    end
                elseif attach ~= "" then
                    hs.alert.show("⚠️ Could not parse task GID for attachment")
                end
            else
                hs.alert.show("❌ Error: " .. tostring(status))
                print("Asana API Error: ", responseBody)
                historyEntry.displaySub = "❌ Failed (HTTP " .. tostring(status) .. ")" ..
                    (#subParts > 0 and "  ·  " .. table.concat(subParts, "  ·  ") or "")
            end

            -- Always persist history after any outcome (including non-attachment path)
            if attach == "" then saveTaskHistory(_G.asanaTaskHistory) end
        end)

        _G.taskDraft = ""            -- task submitted: draft's job is done
        _G.choosers.task:query("")
    end
end):placeholderText("Title | Description | Assignee | /path/to/attachment")

-- 6.10.2: wider box — 60% of the screen instead of hs.chooser's 40%
-- default, so much more of a long title stays visible before the
-- field starts scrolling. Edit the number freely (10–100); the
-- draft mirror and centering adapt automatically.
pcall(function() _G.choosers.task:width(60) end)

-- DRAFT PERSISTENCE (6.10.1): every keystroke in the box is mirrored
-- into _G.taskDraft, so the text survives the popup being dismissed
-- ANY way (click away, Esc, accidental Enter on a read-only history
-- row) — the ⌃⌥⌘T binding in §5 restores it on reopen. Cleared only
-- on successful task creation, or by deleting the text yourself.
-- In-memory (like window prior-positions): a config reload starts fresh.
_G.taskDraft = ""

-- Armored: if rendering ever errors again, show the error IN the
-- chooser instead of a silent blank window (which is what an error
-- inside a queryChangedCallback otherwise produces).
_G.choosers.task:queryChangedCallback(function(query)
    _G.taskDraft = query or ""
    pcall(taskMirrorShow, _G.taskDraft)   -- live wrapped mirror (6.10.2)
    local ok, err = pcall(renderTaskChoices, query)
    if not ok then
        print("🚨 Task chooser render error: " .. tostring(err))
        _G.choosers.task:choices({
            { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err), isHistory = true },
        })
    end
end)

-- =====================================================================
-- 5. HOTKEY INTEGRATIONS
-- =====================================================================
-- ✏️ EDIT YOUR KEYS HERE — the five core pickers, one line each.
-- Change the letter (or the mods) and reload; nothing else to touch.
-- The Hotkey Sentry (§0.3) will warn at boot if an edit collides with
-- another combo in this file or a known macOS default.
local coreKeys = {
    formatAsanaURL   = { {"cmd", "ctrl", "alt"},  "A" },  -- format Asana URL from clipboard
    clipboardHistory = { {"ctrl", "alt", "cmd"},  "V" },  -- searchable clipboard history
    taskCreator      = { {"ctrl", "alt", "cmd"},  "T" },  -- Asana task creator
    activityTracker  = { {"cmd", "alt", "shift"}, "0" },  -- activity tracker picker
    ocrSearch        = { {"cmd", "ctrl", "alt"},  "O" },  -- OCR log search
}

-- Format Asana URL from clipboard
hs.hotkey.bind(coreKeys.formatAsanaURL[1], coreKeys.formatAsanaURL[2], function()
    if not requireAsana() then return end
    local url = hs.pasteboard.readString()
    if url and url:match("asana%.com") then
        local id = url:match(".*/(%d+)")
        if id then
            hs.http.asyncGet("https://app.asana.com/api/1.0/tasks/" .. id,
                { ["Authorization"] = "Bearer " .. asanaToken },
                function(s, b)
                    if s == 200 then
                        local taskData = _G.safeJson(b, "asana/task")
                        if taskData and taskData.data and taskData.data.name then
                            hs.pasteboard.setContents(taskData.data.name .. " | " .. url)
                            hs.alert.show("✅ Formatted")
                        else
                            hs.alert.show("❌ Failed to parse task name")
                        end
                    else
                        hs.alert.show("❌ API Error: " .. tostring(s))
                    end
                end)
        else
            hs.alert.show("❌ No Task ID found in URL")
        end
    else
        hs.alert.show("❌ Clipboard does not contain an Asana URL")
    end
end)

-- Clipboard history
hs.hotkey.bind(coreKeys.clipboardHistory[1], coreKeys.clipboardHistory[2], function()
    renderClipboardChoices("")
    showPopup(_G.choosers.clipboard)
end)

-- ⌘⌃⌥⇧V — EDIT or DELETE a clipboard history entry.
-- 6.15.3 FIX: this originally matched by putting the entry TABLE
-- itself on the choice and comparing it by == inside the callback —
-- but hs.chooser round-trips every choice through its Objective-C
-- bridge, and what the completion callback receives back is a FRESHLY
-- REBUILT Lua table, never the same object you handed it. Table
-- identity can never survive that trip, so the match always failed
-- ("That entry is gone" even though nothing had changed) — exactly
-- why the OCR edit picker (which passes a plain NUMBER index — a
-- VALUE, which the bridge preserves correctly) worked and this didn't.
-- Same snapshot+index pattern as OCR now: clipboardEditSnapshot is
-- built fresh each time the picker opens, keyed by each entry's
-- position in _G.clipboardCache at that moment; the callback looks up
-- clipboardEditSnapshot[choice.idx] to get the TRUE entry object (an
-- ordinary Lua reference from OUR OWN code, never bridged), then
-- re-finds that object's CURRENT position in the live cache before
-- mutating — still safe if a new copy shifted every index in between.
-- Wrapped in do...end (same reasoning as the OCR edit picker above):
-- these locals are needed nowhere else, so scoping them here frees
-- their slots for the rest of the file.
do

local clipboardEditSnapshot = {}

_G.choosers.clipboardEdit = hs.chooser.new(function(choice)
    if not (choice and choice.idx) then return end
    local entry = clipboardEditSnapshot[choice.idx]
    if not entry then return end

    local idx = nil
    for i, v in ipairs(_G.clipboardCache) do
        if v == entry then idx = i break end
    end
    if not idx then
        hs.alert.show("⚠️ That entry is gone — history changed since this picker opened")
        return
    end

    local button, text = hs.dialog.textPrompt(
        "✏️ Edit clipboard entry (" .. (entry.date or "") .. ")",
        "Edit the text below.\nSave with it EMPTY to delete this entry.",
        entry.text, "Save", "Cancel")
    if button ~= "Save" then return end

    if not text or text:match("^%s*$") then
        table.remove(_G.clipboardCache, idx)
        saveClipboardToDisk(_G.clipboardCache)
        hs.alert.show("🗑 Clipboard entry deleted")
    else
        _G.clipboardCache[idx].text = text
        saveClipboardToDisk(_G.clipboardCache)
        hs.alert.show("✏️ Clipboard entry updated")
    end
end)
_G.choosers.clipboardEdit:placeholderText("Search clipboard history to edit or delete — Enter opens a row")

local function renderClipboardEditChoices(query)
    local q = (query or ""):lower():match("^%s*(.-)%s*$")
    clipboardEditSnapshot = {}
    local choices = {}
    for i, item in ipairs(_G.clipboardCache) do
        if q == "" or item.text:lower():find(q, 1, true) then
            clipboardEditSnapshot[i] = item
            local oneLine = item.text:gsub("%s+", " ")
            table.insert(choices, {
                text    = oneLine:sub(1, 100),
                subText = (item.date or "") .. "  ·  Enter to edit or delete",
                idx     = i,
            })
            if #choices >= 250 then break end
        end
    end
    if #choices == 0 then
        table.insert(choices, {
            text    = (q == "") and "Clipboard history is empty" or ("No matches for \"" .. q .. "\""),
            subText = "",
        })
    end
    _G.choosers.clipboardEdit:choices(choices)
end

_G.choosers.clipboardEdit:queryChangedCallback(function(query)
    local ok, err = pcall(renderClipboardEditChoices, query)
    if not ok then
        print("🚨 Clipboard edit render error: " .. tostring(err))
        _G.choosers.clipboardEdit:choices({
            { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

hs.hotkey.bind({"cmd", "ctrl", "alt", "shift"}, "V", function()
    renderClipboardEditChoices("")
    showPopup(_G.choosers.clipboardEdit)
end)

end -- do...end (⌘⌃⌥⇧V clipboard edit/delete picker locals)

-- Task creator — reopens with your unsent DRAFT restored (6.10.1).
-- Previously this line wiped the box with query("") on every open,
-- which is exactly why a stray click could eat what you'd typed.
hs.hotkey.bind(coreKeys.taskCreator[1], coreKeys.taskCreator[2], function()
    if not requireAsana() then return end
    local draft = _G.taskDraft or ""
    _G.choosers.task:query(draft)
    renderTaskChoices(draft)  -- render explicitly; programmatic query() alone isn't guaranteed to re-fire the callback
    showPopup(_G.choosers.task)
    if draft ~= "" then
        hs.alert.show("📝 Draft restored — keep typing, or delete it to start fresh")
        pcall(taskMirrorShow, draft)   -- mirror needs the popup visible, so after showPopup
    end
end)

-- App tracker (today's activity; type 'week'/'month'/search once open)
hs.hotkey.bind(coreKeys.activityTracker[1], coreKeys.activityTracker[2], function()
    _G.service.call("activity.renderChoices", "")
    showPopup(_G.choosers.appTracker)
end)

-- OCR log search
hs.hotkey.bind(coreKeys.ocrSearch[1], coreKeys.ocrSearch[2], function()
    _G.choosers.ocr:choices(loadOCRHistory())
    showPopup(_G.choosers.ocr)
end)

-- ⌘⌃⌥⇧O — EDIT or DELETE an OCR history entry. A snapshot of the CSV
-- (ocrEditSnapshot) is taken the moment the picker opens and reused by
-- the completion callback, so a selection always maps to the row you
-- actually saw, even if a background OCR appends a new row in between.
-- Save with the text field emptied DELETES the entry — stated plainly
-- in the dialog itself rather than needing a separate delete hotkey.
-- Wrapped in do...end: this file's main chunk is near Lua's 200-local
-- ceiling, and loadOCRHistoryRaw/saveOCRHistoryRaw are needed nowhere
-- else — scoping them here frees their slots for the rest of the file,
-- same reasoning as §0.2's secret.lua block and §3.10's do...end.
do

local function loadOCRHistoryRaw()
    local f = io.open(csvFile, "rb")
    local items = {}
    if f then
        local content = f:read("*a"); f:close()
        if content then
            content = content:gsub("%z", "")
            for line in content:gmatch("([^\r\n]+)") do
                local timestamp, rawText = line:match("^([^,]+),(.*)$")
                if timestamp and rawText then
                    local cleanText = rawText:gsub('^"', ''):gsub('"$', ''):gsub('""', '"'):gsub('\\n', '\n')
                    table.insert(items, { timestamp = timestamp, text = cleanText })
                end
            end
        end
    end
    return items
end

local function saveOCRHistoryRaw(entries)
    local f = io.open(csvFile, "w")
    if not f then warnWriteFailed("OCR log"); return end
    for _, e in ipairs(entries) do
        local escaped = e.text:gsub('"', '""'):gsub('\r\n', '\\n'):gsub('\r', '\\n'):gsub('\n', '\\n')
        f:write(e.timestamp .. ',"' .. escaped .. '"\n')
    end
    f:close()
end

local ocrEditSnapshot = {}

_G.choosers.ocrEdit = hs.chooser.new(function(choice)
    if not (choice and choice.idx) then return end
    local entry = ocrEditSnapshot[choice.idx]
    if not entry then return end

    local button, text = hs.dialog.textPrompt(
        "✏️ Edit OCR entry (" .. entry.timestamp .. ")",
        "Edit the extracted text below.\nSave with it EMPTY to delete this entry.",
        entry.text, "Save", "Cancel")
    if button ~= "Save" then return end

    if not text or text:match("^%s*$") then
        table.remove(ocrEditSnapshot, choice.idx)
        saveOCRHistoryRaw(ocrEditSnapshot)
        hs.alert.show("🗑 OCR entry deleted")
    else
        entry.text = text
        saveOCRHistoryRaw(ocrEditSnapshot)
        hs.alert.show("✏️ OCR entry updated")
    end
end)
_G.choosers.ocrEdit:placeholderText("Select an OCR entry — Enter opens it to edit or delete")

hs.hotkey.bind({"cmd", "ctrl", "alt", "shift"}, "O", function()
    ocrEditSnapshot = loadOCRHistoryRaw()
    if #ocrEditSnapshot == 0 then
        hs.alert.show("📋 OCR history is empty")
        return
    end
    local choices = {}
    for i = #ocrEditSnapshot, 1, -1 do   -- newest first, matches the browse picker
        local e = ocrEditSnapshot[i]
        table.insert(choices, {
            text    = e.text:gsub("%s+", " "):sub(1, 100),
            subText = "🕒 " .. e.timestamp .. "  ·  Enter to edit or delete",
            idx     = i,
        })
    end
    _G.choosers.ocrEdit:choices(choices)
    showPopup(_G.choosers.ocrEdit)
end)

end -- do...end (⌘⌃⌥⇧O OCR edit/delete picker locals)

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

    local els = {}
    table.insert(els, {
        type = "rectangle", action = "fill",
        fillColor = { red = 0.11, green = 0.11, blue = 0.13, alpha = panelAlpha },
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
    canvas:show()
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
-- moved into a module. Four other features (File Tracker, Update
-- Tracker, Document Watcher) and the changelog writer at the bottom of
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
--     name  = "App Peek",            -- shown in the boot report
--     order = 7,                     -- its slot in the cheat sheet
--     cheatsheet = {                 -- travels WITH the module
--       title = "👀 APP PEEK",
--       entries = { { "⇪P", "Hide the frontmost app" } },
--     },
--     config = someTable,            -- OPTIONAL: settings a machine
--                                    -- profile may override
--     setup = function(core) ... end,-- REQUIRED: binds keys, cheap work
--   }
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
_G.moduleProfiles = {
    -- ---- personal Mac: everything on -------------------------------
    ["Lees-MacBook-Air"] = {
        modules = {
            "daily_backup", "app_peek", "window_switcher", "window_arranger",
            "copy_on_select", "command_history", "app_watcher", "file_tracker",
            "autocorrect", "activity_tracker", "update_tracker",
            "asana_comments", "document_watcher",
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
        },
    },

    -- ---- work Mac -------------------------------------------------
    -- ✏️ PUT YOUR WORK MACHINE'S NAME HERE. Find it by running
    --      scutil --get ComputerName
    -- on that Mac, or just read the 🧭 PORTABILITY REPORT line at the
    -- top of its Hammerspoon Console — it prints the same name.
    -- Until you do, the work Mac uses `default` below, which loads
    -- everything; nothing breaks either way.
    ["Lees-Work-MacBook"] = {
        modules = {
            "daily_backup", "app_peek", "window_switcher", "window_arranger",
            "copy_on_select", "command_history", "app_watcher", "file_tracker",
            "autocorrect", "activity_tracker", "update_tracker",
            "asana_comments", "document_watcher",
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
        },
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
    },

    -- ---- any other Mac --------------------------------------------
    default = {
        modules = {
            "daily_backup", "app_peek", "window_switcher", "window_arranger",
            "copy_on_select", "command_history", "app_watcher", "file_tracker",
            "autocorrect", "activity_tracker", "update_tracker",
            "asana_comments", "document_watcher",
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
        },
    },
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
    panelAlpha       = panelAlpha,
    -- hyper keyspace (§3.12) — the supported way for a module to claim a
    -- ⇪ shortcut. Wrapped rather than captured, so it resolves at call
    -- time and this table stays honest if §3.12 ever moves.
    hyperAddShortcut = function(...) return _G.hyperAddShortcut(...) end,
    -- credentials (§0.2) — nil when secret.lua is absent, by design
    asanaEnabled     = asanaEnabled,
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
    if type(mod.cheatsheet) == "table" and mod.cheatsheet.title then
        table.insert(_G.moduleCheatsheets, {
            title   = mod.cheatsheet.title,
            entries = mod.cheatsheet.entries or {},
            order   = mod.order or 500,
        })
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
    return loaded, failed
end

-- Pick this machine's profile and run it.
_G.moduleProfileName = _G.moduleProfiles[hostTag] and hostTag or "default"
do
    local profile = _G.moduleProfiles[_G.moduleProfileName]
    _G.loadModules(profile.modules, profile.settings)
end

if _G.hyperFinalize then _G.hyperFinalize() end
if _G.diag then _G.diag.mark("§3.12 hyper wired") end

print("📌 init.lua ARCHITECTURE VERSION: " .. _G.configVersion)

-- ---- CHANGELOG CSV (6.30.1) -----------------------------------------
-- Verbose version notes go here instead of bloating the header forever.
-- Written once per version on first boot — the file is append-only and
-- lives in your OneDrive Logs folder (Excel-ready).
;(function()
    local changelogFile = logsDir .. "/changelog.csv"
    local currentVersion = "6.49.0"
    local currentDate    = "08-08-26"
    -- One line. The full entry for every version lives in CHANGELOG.md
    -- beside this file — which is also why prose no longer sits in a
    -- Lua string here: the work-Mac safety scan reads string literals
    -- as code, and a paragraph describing "no sudo, no launchctl"
    -- failed the very check it was describing.
    local currentNotes   = "Turned the random-sequence explorer on the URL Cleaner, Health Monitor and Menu Bar Items. 8000 generated URLs checking idempotence and that wrapping cannot change the answer; 600 random timelines checking the alerting rules; 500 random Mac populations checking the scan budget holds. Four findings, none a bug in the shipped modules: the cleaner correctly refuses to unwrap a site's own return path, the monitor correctly announces a load failure without waiting out the grace period, and two were faults in my own instrumentation - reading the clock before the action that changed it, and letting the simulated date run backward. Added a rule nothing had checked, that load failures obey the once-per-day limit. Every property was then mutation tested so none of them is decoration. See CHANGELOG.md for the full entry."

    -- Only append if this version isn't already in the file
    local found = false
    local f = io.open(changelogFile, "r")
    if f then
        local content = f:read("*a"); f:close()
        found = content:find(currentVersion, 1, true) ~= nil
    end
    if not found then
        -- 6.35.0: this used to be io.open(...) == nil, which opens the
        -- file and drops the handle on the floor — a leak that only
        -- closes when the garbage collector gets round to it.
        local probe = io.open(changelogFile, "r")
        local needsHeader = (probe == nil)
        if probe then probe:close() end
        local out = io.open(changelogFile, "a")
        if out then
            if needsHeader then out:write("Date,Version,Change notes\n") end
            out:write(csvQuote(currentDate) .. "," .. csvQuote(currentVersion) .. ","
                .. csvQuote(currentNotes) .. "\n")
            out:close()
            print("📝 Changelog: " .. currentVersion .. " → " .. changelogFile)
        end
    end
end)()

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