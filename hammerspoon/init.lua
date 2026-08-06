-- =====================================================================
-- * Working VERSION *
-- =====================================================================
-- =====================================================================
-- 08-05-26 using Claude
-- =====================================================================
-- .Hammerspoon ARCHITECTURE VERSION CONTROL: 6.42.0-UNIVERSAL-COMMENTS
-- =====================================================================

-- NEW IN 6.42.0 — DANGLING CALLS FIXED + A GUARD SO THEY CANNOT RETURN:
--   💥 WHAT BROKE: ⇪0 crashed with "attempt to call a nil value (global
--      'renderActivityChoices')". When §3.6 became a module its
--      functions went with it, but hotkey handlers left behind in THIS
--      file kept calling them by bare name. Lua turns a vanished local
--      into a nil GLOBAL — no compile error, no boot error, nothing at
--      all until the key is pressed. A static scan found TWO:
--        · renderActivityChoices  → activity_tracker.lua   (⇪0)
--        · addCommentToTask       → asana_comments.lua     (task
--          creator auto-comment, and the dashboard's comment prompt)
--   🔌 FIXED PROPERLY, NOT PATCHED — A SERVICE REGISTRY. A module now
--      PUBLISHES what the rest of the config may call:
--          core.provide("activity.renderChoices", fn)
--      and anything else calls it with:
--          _G.service.call("activity.renderChoices", "")
--      A missing provider PRINTS which module is absent and returns nil
--      instead of throwing, so an unloaded module degrades to a dead
--      key with an explanation rather than a red error. The registry is
--      stubbed on line one so it can never itself be nil, and ⇪⇧D lists
--      every published service.
--   🛡 THE GUARD THAT SHOULD HAVE EXISTED. The audit suite already
--      checked that no MODULE reaches into init.lua's locals. It never
--      checked the reverse — that init.lua does not call something that
--      LEFT. It does now: the audit walks init.lua for calls to any
--      function defined in any module file. That check is what would
--      have caught this before delivery.
--   🍺 HOMEBREW: ONE BREAKAGE, ONE MESSAGE. A corrupt brew API cache
--      fails every cask at once, and the tracker printed "check the
--      token in updateTrackerApps" fifteen times — sending you to fix
--      something that was never wrong. The two causes are told apart
--      now, and the brew-side one is reported ONCE per check with the
--      actual repair:  rm -rf "$(brew --cache)/api" && brew update --force
-- NEW IN 6.41.0 — ⌥TAB: A DEADLINE, A CACHE, AND A NAMED CULPRIT:
--   🧊 WHAT HAPPENED: on a real Mac, ⌥Tab took 15.90 SECONDS across 15
--      apps. The per-application Accessibility sweep that 6.39.0 added
--      to reach other desktops can block for a second or more PER APP
--      (an app swapped out after an idle period is the usual reason),
--      and fifteen of those in a row is a freeze, not a switcher. The
--      6.39.0 instrumentation is what turned it into a number instead
--      of a mystery — but a number is not a fix.
--   ⏱ A HARD DEADLINE. altTab.listBudget (0.8s) is checked BEFORE each
--      application, so it caps what gets asked for rather than
--      reporting what was already spent. When it trips, the switcher
--      opens with what it collected and the HUD says "list cut short",
--      because a partial list you can see beats a complete one that
--      arrives 16 seconds late — and a silently short list is the bug
--      class this config keeps refusing to ship.
--   🎯 THE CULPRIT GETS NAMED. Every application is timed individually;
--      the Console and ⇪⇧D report the slowest one by name. If a single
--      app is responsible, put it in altTab.skipApps and it is never
--      asked again. That turns an unfixable "sometimes slow" into a
--      one-line fix.
--   💾 A SHORT CACHE (altTab.cacheFor, 4s) so repeated presses do not
--      re-pay the cost. Short on purpose: a stale switcher missing the
--      window you just opened would be worse than a slow one.
--   🚫 NO BACKGROUND REFRESH, DELIBERATELY. A timer running this sweep
--      every few seconds would move the freeze somewhere you cannot see
--      it coming — strictly worse than a slow keypress.
-- NEW IN 6.40.0 — FEATURES ALL MODULAR · MACHINE PROFILES · WARM-UP:
--   🧩 FOUR MORE SECTIONS OUT: Activity Tracker, App Update Tracker,
--      Asana Comments, Document Watcher. THIRTEEN modules now, and this
--      file is 5,377 lines — down from 9,529 at 6.35.0, a 44% cut.
--      What remains here is core plus two pieces of infrastructure
--      (the cheat sheet and the hyper key) that everything depends on.
--   💻 MACHINE PROFILES (§1.12). The same init.lua and the same
--      modules/ folder go on BOTH Macs; a table keyed by machine name
--      is the only thing that differs. It lists which modules load and
--      can override any module's `config` per machine, so a work Mac
--      can run a lower ⌥Tab cap without editing the module. An unknown
--      machine falls back to `default` and SAYS SO in the boot report
--      rather than quietly loading nothing. Set your work Mac's name
--      from `scutil --get ComputerName`.
--   ⏱ PERFORMANCE — A WARM-UP PHASE. A module may define warm(), which
--      the loader runs ~2s AFTER boot on a HELD timer. Autocorrect is
--      why: parsing an 11,000-row CSV was the most expensive thing this
--      config did at startup, and it bought nothing — a typo-corrector
--      cannot help you before the desktop has drawn. The event tap now
--      starts instantly and the dictionary arrives a moment later.
--      setup() and warm() are timed separately in ⇪⇧D.
--   🐛 TWO EXTRACTION BUGS, BOTH CAUGHT BY TESTS, BOTH WORTH KNOWING:
--      1. Removing §3.6 deleted the ONLY definitions of csvQuote and
--         splitCSVLine. Lua turns a vanished local into a GLOBAL lookup,
--         so the file still COMPILED and would have crashed at boot the
--         moment the changelog writer ran. Both are promoted into a new
--         §1.4 — a compile that succeeds is not proof of anything.
--      2. A `do` anchor matched the letters "do" inside a word in a
--         comment and cut a module in half. Anchors are line-exact now.
--   📖 HAMMERSPOON-GUIDE.md ships alongside: layout, install, the
--      two-Mac workflow, how to write a module, and a troubleshooting
--      table keyed by symptom.
-- NEW IN 6.39.0 — ⌥TAB NOW SEES EVERY DESKTOP, NOT JUST THIS ONE:
--   🖥 THE BUG: ⌥Tab listed only the windows on the desktop you were
--      looking at. hs.window.orderedWindows() and hs.window.allWindows()
--      report ONLY the current Mission Control Space — a documented
--      macOS limit, not a Hammerspoon bug. Hammerspoon's own documented
--      answer is hs.window.filter, which is the module that froze this
--      Mac for 44 seconds in 6.33.0, so that door stays shut.
--   🔑 THE THIRD ROUTE: ask each APPLICATION for its own windows. The
--      Accessibility API has no concept of a Space, so an app hands over
--      its windows wherever they are — other desktops, other monitors,
--      minimised. Only GUI apps are asked (app:kind() == 1), which skips
--      exactly the background and menu-bar agents whose AX timeouts made
--      window.filter unusable. The current Space is still listed FIRST,
--      front-to-back, then everything else is appended and deduplicated
--      by window id.
--   📦 EVERY OPEN PROGRAM, not just every open window: minimised windows
--      are included by default now, and a running app with NO window at
--      all gets its own tile that ACTIVATES the app when selected.
--      Cap raised 24 → 36. Knobs: altTab.includeOtherSpaces,
--      includeApps, includeMinimized, maxWindows.
--   🐛 CAUGHT BY THE TESTS MID-CHANGE: an app whose windows had all been
--      picked up by the current-Space pass contributed nothing new in
--      the per-app pass, so it looked like it owned no windows and got a
--      second, bogus "no open window" tile — one per app on your current
--      desktop. Ownership is now derived from the assembled entries.
--   🔊 A failed enumeration phase PRINTS again (the rewrite had made it
--      silent), and a failure on the current Space now degrades to the
--      per-app list rather than to an empty switcher.
-- NEW IN 6.38.0 — THREE MORE OUT (nine modules, init.lua −27%):
--   🧩 App Watcher (§3.7), File Tracker (§3.8) and Autocorrect (§3.9)
--      are now modules. init.lua is 6,952 lines, down from 9,529 at
--      6.35.0 — a 27% reduction, and every module file carries its own
--      fresh 200-local budget.
--   🔧 splitCSVLine MOVED INTO core. It was declared inside §3.6 but
--      used by three OTHER sections — always a shared helper living in
--      the wrong place. Moving it is precisely what let File Tracker
--      and Autocorrect leave, and it is the pattern for the sections
--      still waiting: find the helper the section is squatting on,
--      promote it to core, THEN move the section.
--   ✅ Autocorrect still publishes _G.autocorrectStatus and
--      _G.autocorrectTap, so the boot report and ⇪⇧D read them exactly
--      as before — the diagnostics did not need to know it moved.
-- NEW IN 6.37.0 — THREE MORE SECTIONS MOVED OUT:
--   🧩 Window Arranger (§1.9), Copy-on-Select (§3.11) and Command
--      History (§6.5) are now modules. Six in total; this file is down
--      from 9,529 lines at 6.35.0 to 7,947.
--   🔑 core.hyperAddShortcut — the supported way for a module to claim a
--      ⇪ key. Wrapped rather than captured so it resolves at CALL time,
--      which keeps the core table honest if §3.12 ever moves. Command
--      History uses it, and carries a note that this only works because
--      §1.12 loads modules BEFORE hyperFinalize drains the queue: move
--      the loader earlier and that shortcut would silently never bind.
--   ⚠️ Copy-on-Select declares NO cheat sheet group on purpose — its one
--      entry (⇪⇧C) belongs to the 📋 CLIPBOARD & OCR group, which is
--      still in this file. Splitting it out would drop a one-line group
--      into the middle of the sheet for no benefit. Stated in the
--      module rather than left as a silent inconsistency.
--   🐛 AN EXTRACTION BUG THE TESTS CAUGHT: the old §3.11 wrapped its
--      locals in a do...end block to stay under the 200-local budget.
--      Moving the body into M.setup() split that `do` from its `end`
--      across the function boundary — which still COMPILED, and made
--      the module return nil instead of its contract table. The
--      loader's "does not return a table with a setup() function"
--      check is what caught it, which is precisely why it exists.
--      The wrapper is gone now: a function scopes its locals already.
-- NEW IN 6.36.0 — MODULES: SECTIONS NOW LIVE IN THEIR OWN FILES:
--   🧩 NEW §1.12 MODULE LOADER. Sections can now live in
--      ~/.hammerspoon/modules/<name>.lua and are listed in moduleList.
--      Three moved out first — Daily Backup (§1.7), App Peek (§1.8) and
--      Window Switcher (§1.10), 464 lines out of this file. Everything
--      not yet moved still works exactly as before: the two styles
--      coexist on purpose so the move happens a few sections at a time
--      instead of as one all-or-nothing rewrite.
--   📏 WHY IT MATTERS MORE THAN TIDINESS: Lua's 200-local limit is PER
--      CHUNK, and a file is a chunk. This file was measured at exactly
--      200 with ZERO headroom in 6.35.0 — the next top-level `local`
--      anywhere would have been a compile error taking the WHOLE config
--      down. init.lua is at 12 free now, and every module file gets its
--      own fresh 200.
--   📖 THE CHEAT SHEET IS ASSEMBLED, NOT HARD-CODED. Each module
--      registers its own group when it loads, and groups sort by an
--      explicit UNIQUE order number (unique because table.sort in Lua
--      is not stable — equal keys could reshuffle between reloads).
--      Delete a module file and its group goes with it, instead of the
--      sheet advertising a shortcut nothing binds — the exact drift the
--      "hand-written snapshot" warning has apologised for since 6.10.
--   🛟 FAILURE IS ISOLATED, which is the other half of the point. Every
--      module is loaded, executed AND set up inside its own pcall: a
--      syntax error in one costs you that module, not your hotkeys, not
--      autocorrect, not the whole config. Before this, one bad line
--      anywhere meant NOTHING loaded. Failures are named in the
--      Console, counted in the boot report, listed in ⇪⇧D and shown as
--      a ⚠️ group at the TOP of the cheat sheet.
--   ☁️ MODULES LOAD FROM LOCAL DISK, DELIBERATELY. Loading them from
--      the OneDrive folder would save a copy step and is the wrong
--      trade: Files-On-Demand can leave a file as an online-only
--      placeholder, and reading one triggers a SYNCHRONOUS download —
--      a main-thread stall at every login on a slow network, the same
--      failure shape as the 6.33.0 ⌥Tab freeze. Master copies live in
--      OneDrive for durability and for copying to another Mac; the
--      loader only ever reads local disk. The 5pm backup already
--      rsyncs ~/.hammerspoon, so modules/ is covered automatically.
-- NEW IN 6.35.0 — APP LOCK REMOVED · DIAGNOSTICS ADDED · AUDIT FIXES:
--   🗑 APP LOCK IS GONE. The whole PIN-gate feature (old §6.6, ~1150
--      lines) has been deleted: the manager, the covers, the PIN
--      prompts, the re-lock watcher, the panic key and its cheat sheet
--      group. applock.json is STILL excluded from the backup, so a
--      leftover file from an older version can never sync anywhere.
--   🩺 NEW §1.11 DIAGNOSTICS — ⇪⇧D. Writes one report containing
--      versions, boot timings, screens, hotkey counts, feature states,
--      file paths with their write status, a LIVE window-enumeration
--      timing, recent errors and the last 25 internal events — to the
--      Console, your clipboard AND Logs/diagnostics-<machine>.txt.
--      A 200-entry trail is recorded in memory ALWAYS, so the report
--      shows what happened before a problem even though verbose was
--      off at the time — which is the normal case, because nobody
--      turns verbose on until after something breaks. Live verbose:
--      type  _G.diag.verbose = true  in the Console, no reload.
--      hs.uncaughtErrorHandler is now set, so an error thrown inside
--      an async callback (HTTP reply, timer, watcher — everywhere a
--      pcall in the calling function cannot reach) is captured with a
--      timestamp instead of scrolling past.
--   🔴 AUDIT FIX (MAJOR) — JSON OFF THE NETWORK COULD THROW. All six
--      hs.json.decode calls on Asana replies ran unprotected INSIDE
--      async HTTP callbacks. hs.json.decode RAISES on malformed input,
--      and a corporate proxy or captive portal answering HTTP 200 with
--      an HTML login page is precisely that — likelier on a work
--      network than a broken API. The throw escaped every enclosing
--      pcall. All six now go through _G.safeJson, which logs how many
--      bytes arrived and how they start, then returns nil so the
--      caller's existing "if not data" branch handles it.
--   🟠 AUDIT FIX (MEDIUM) — THE FILE WAS ON THE 200-LOCAL CEILING WITH
--      ZERO HEADROOM. Measured, not guessed: the main chunk of a Lua
--      file IS a function, the limit is 200 locals per function, and
--      this file was at exactly 200. The next `local` added ANYWHERE at
--      top level would have been a compile error taking the WHOLE
--      config down — a landmine for whoever edited next. §1.6's nine
--      loose locals were folded into the cheatSheet table it already
--      had, which buys 8 back. New sections must namespace.
--   🟠 AUDIT FIX (MEDIUM) — the diagnostics API is now declared as a
--      no-op stub on the FIRST line of the file and extended by §1.11.
--      Sections earlier in the file log through it, so a partial load
--      that never reached §1.11 would have thrown on a logging call:
--      a diagnostics system causing the outage it exists to explain.
--   🟠 AUDIT FIX (MEDIUM) — ⌥Tab captured thumbnails for up to 24
--      windows and THEN trimmed the list to what the screen could hold,
--      so a laptop captured 24 images to draw 15. Snapshots are cheap
--      but not free (~5-20ms each) and that waste lands on the keypress
--      you are waiting on. The grid is now worked out first, the list
--      trimmed, and only the survivors captured — timed, and reported
--      in the Console if it ever crosses 0.35s.
--   🟡 AUDIT FIX (MINOR) — a leaked file handle: the changelog writer
--      tested for the CSV with io.open(...) == nil and never closed
--      what it opened, leaving it to the garbage collector.
--   ⏱ Boot report now prints total load time, so a slow start is a
--      number you can quote rather than a feeling.
-- NEW IN 6.34.0 — ⌥TAB SWITCHER REBUILT (6.33.0 FROZE THE MAC):
--   🧊 WHAT WENT WRONG. 6.33.0's switcher beachballed Hammerspoon for
--      44 seconds on the FIRST ⌥Tab. The Console dated it exactly:
--        10:01:25  -- Loading extensions: window.filter
--        10:02:09  ✏️ Autocorrect tap was disabled by macOS — revived
--      macOS switches an event tap off when the owning app stops
--      answering, so that second line is the main thread returning.
--      CAUSE: hs.window.switcher is built on hs.window.filter, which
--      enumerates and then SUBSCRIBES TO every running application over
--      the Accessibility API — and clearing the default filter to get
--      minimised windows pulled hidden and background apps in too. Each
--      unresponsive app costs a full AX timeout, on the one thread
--      Hammerspoon has. That is not tunable; the module was the wrong
--      tool for a Mac with a lot of apps open.
--   🔨 REBUILT WITHOUT hs.window.filter. §1.10 now lists windows with
--      hs.window.orderedWindows() — one snapshot, already front-to-back,
--      no watchers, GUI apps only — draws its own tile grid on hs.canvas
--      and watches for the ⌥ release by POLLING
--      hs.eventtap.checkKeyboardModifiers on a timer instead of adding
--      another event tap macOS can switch off.
--   📏 IT MEASURES ITSELF. Every enumeration is timed; anything past
--      0.35s prints how long it actually took and which knob to turn.
--      A slow machine now reports a number instead of a beachball.
--      The list is capped (altTab.maxWindows = 24) — a bounded cost
--      instead of a promise that can't be kept.
--   🗑 A SECOND BUG, FOUND WHILE FIXING THE FIRST: 6.33.0's warm-up
--      timer was created and its object thrown away on the same line.
--      An unreferenced hs.timer is garbage-collected, so it never
--      fired. Every timer here is stored.
--   🛟 Esc cancels without switching · a watchdog closes a stuck HUD
--      after 30s · altTab.enabled = false is a panic switch that makes
--      ⌥Tab inert without touching anything else in this file.
--   ⚠️ MINIMISED WINDOWS ARE OFF BY DEFAULT now (they need the slower
--      hs.window.allWindows call): altTab.includeMinimized = true.
-- NEW IN 6.33.0 — ⌥TAB WINDOW SWITCHER (§1.10):
--   🔄 WINDOWS-STYLE ALT+TAB, WHICH macOS DOES NOT HAVE. Hold ⌥ and tap
--      Tab to walk every open WINDOW with a thumbnail tile each (title
--      underneath), ⌥⇧Tab to walk back, release ⌥ to switch. ⌘Tab
--      switches APPS and buries a five-window app behind one icon;
--      this is per-window. ⌘Tab itself is untouched — macOS reserves
--      it, as §0.3's own knownSystemCombos table says.
--      Lists minimised windows and hidden apps too (altTab.includeHidden
--      = false for visible-only), across all Spaces.
--   ⚡ COSTS NOTHING AT BOOT. hs.window.filter has to subscribe to every
--      running app and enumerate its windows, so it is built on the
--      FIRST ⌥Tab and cached — then warmed quietly 5s after boot so
--      that first press is instant anyway.
--   🛟 DEGRADES INSTEAD OF DYING. Every setup step is pcall'd with a
--      fallback: UI prefs rejected → stock look; custom filter fails →
--      default filter. A plain-looking switcher still switches windows;
--      an error during setup would have left ⌥Tab dead and silent.
--   📖 CHEAT SHEET REORDERED to how you actually reach for things:
--      App Monitor first, App Peek under Window Arranger, the new
--      switcher after it, then App Updates → App Lock → File Tracker →
--      Document Watcher, Autocorrect under Command History, Help last.
-- NEW IN 6.32.1:
--   📖 HELP MOVED TO THE BOTTOM. The ❓ HELP group sat in the middle of
--      the feature groups; it now comes last of the built-ins, directly
--      after ☁️ BACKUP. Your own ⭐ entries still follow it.
-- NEW IN 6.32.0 — CHEAT SHEET IS ONE SCROLLING COLUMN:
--   📜 IT GROWS DOWN, NOT SIDEWAYS. The sheet used to fill a column and
--      then start another one to the right, so a long list spread into a
--      wall of text. It is now a SINGLE column you scroll: ↑↓ a row at a
--      time (hold to keep going), PgUp/PgDn a screenful, Home/End to the
--      ends, or the scroll wheel / trackpad. A scrollbar and an
--      "N–N of N" counter in the footer show where you are.
--      The wheel is only claimed while the pointer is OVER the sheet —
--      anywhere else it passes through, so the window underneath still
--      scrolls normally with the sheet open beside it.
--      ⚠️ Esc, the arrows, PgUp/PgDn and Home/End are captured GLOBALLY
--      while the sheet is up (it takes no keyboard focus, so that is the
--      only way it can hear them). Close it and they all go straight
--      back to the app underneath.
--   🫥 TRANSLUCENT AGAIN, BUT READABLE. The sheet now has its OWN
--      see-through setting (cheatSheet.alpha = 0.75, top of §1.6) rather
--      than sharing panelAlpha, and sits on a near-black panel instead
--      of a grey one. That combination is the point: at the same alpha a
--      darker panel holds white text at roughly 8:1 contrast, so you can
--      see the window behind the sheet without the shortcuts fading into
--      it. panelAlpha (0.90) still governs the legend strip and draft
--      mirror — the two are now independent.
--   ⚡ COST NO LONGER GROWS WITH THE LIST. Only the rows actually in
--      view become canvas elements (~30), so 300 custom entries paint
--      exactly as fast as 30. Scrolling changes one number and repaints
--      that window of rows.
--   📍 A REDRAW KEEPS YOUR PLACE. Adding, editing or deleting an entry
--      while the sheet is open no longer throws you back to the top; a
--      fresh ⇪/ still opens at the top. If the list gets SHORTER than
--      where you were, the view clamps back into range instead of
--      leaving you on blank rows.
--   🧱 STRUCTURAL — the section is now one namespaced table
--      (`local cheatSheet = {}`) instead of loose top-level locals.
--      This file was at Lua's hard ceiling of 200 locals per chunk, and
--      the main chunk IS a function: adding the scroll machinery as
--      loose locals blew past it, which is a COMPILE error — the whole
--      config would have refused to load, not just the cheat sheet.
--      Fields on one table cost exactly one local however many are
--      added later.
-- NEW IN 6.31.0 — CHEAT SHEET LEGIBILITY + HYPER W SWAP:
--   📖 CHEAT SHEET ENTRIES NO LONGER GET CUT OFF. Every entry was one
--      canvas text element in a fixed-width frame, so anything wider
--      than the column was silently clipped mid-sentence — "F1-F12 —
--      Not forwarded — macOS reserves some" just stopped there, with
--      nothing to indicate text was missing. Long entries now wrap onto
--      indented continuation lines. Width is ESTIMATED, not measured
--      (hs.canvas exposes no text metrics), so the estimate is
--      deliberately conservative: wrapping a word early is invisible,
--      overrunning the column is the bug.
--      Also fixed while in there: the width maths now counts CHARACTERS
--      via utf8.len, not bytes. ⇪, ⌘ and — are multi-byte, so # would
--      have over-counted them badly and wrapped far too early.
--   🫥 PANELS 10% LESS TRANSLUCENT: panelAlpha 0.80 → 0.90. Affects the
--      cheat sheet, the dashboard legend strip and the draft mirror.
--   🖱 A CLICK NO LONGER CLOSES THE CHEAT SHEET. A stray click anywhere
--      on a very wide panel used to dismiss the reference you were
--      reading. It now stays up until you press Esc or ⇪/ deliberately.
--      Mouse events are off entirely, so clicks pass through to whatever
--      is underneath instead of being swallowed.
--   ⌨️ HYPER W SWAPPED: ⇪W now summons an app to this monitor (the one
--      reached for constantly) and ⇪⇧W opens the Document Watcher.
-- NEW IN 6.30.1:
--   🧹 HOUSEKEEPING: removed the legacy "Lee additions / Be sure to
--      have this added in" app list from the header (the watched-apps
--      list in §3.7 IS the live list and always has been). Date stamp
--      now always reads "MM-DD-YY using Claude". Added a changelog CSV
--      at <logsDir>/changelog.csv — every version's verbose notes are
--      written there on first boot (Excel-ready: Date | Version |
--      Change notes). When the next MAJOR version lands (7.0.0), the
--      in-file changelog for 6.x will be compressed to one-liners.
-- NEW IN 6.30.0 — APP LOCK: NEW KEY, OVERLAY-ONLY, NO REDUNDANT UNLOCK:
--   ⌨️ THE MANAGER MOVED: ⇪⇧L → ⇪⇧H. (⇪H on its own is still Command
--      History — hyper+H and hyper+shift+H are different combos, and the
--      sentry confirms no conflict.) Nothing else about the manager
--      changed. The cheat sheet and boot report were updated with it.
--   🪟 OVERLAY ONLY, NO HIDING (appLockCoverThenHide now false).
--      A locked app is no longer hidden and focus is no longer thrown to
--      Finder — the app is left exactly where it sits and an opaque
--      panel is painted over its screen. Hiding was what moved focus,
--      and moving focus was the monitor-to-monitor bounce, so removing
--      the hide removes the bounce by construction.
--      TWO honest exceptions, both deliberate: if the cover cannot be
--      painted at all it falls back to hiding rather than leaving the
--      app exposed, and a CANCELLED or WRONG PIN hides it too — at that
--      point the cover must come down, and an app left on screen with
--      no PIN entered is exactly the leak this feature prevents.
--   🔧 FIX — THE COVER WAS BURYING THE PIN PROMPT. The cover was drawn
--      at canvas level `overlay` (102). An hs.chooser panel draws at
--      `popUpMenu` (101). So the prompt was open and focused underneath
--      a panel you could not see past — which is why the only way
--      through was the panic key, and why the PIN worked immediately
--      after clearing the cover. The cover now draws at `floating` (3):
--      still above every ordinary app window, comfortably below the
--      prompt.
--   🔧 FIX — YOU COULD "UNLOCK" AN APP THAT WAS ALREADY UNLOCKED.
--      Two causes, both fixed. (1) Opening the manager or a PIN prompt
--      takes focus, so macOS fires `deactivated` for the app you were
--      in — and with re-lock-on-leave ON that silently re-locked the app
--      you had just unlocked, the moment you opened the list showing it.
--      Our own popups no longer count as "you switched away". (2) The
--      lock/unlock rows are rendered when the manager opens and can go
--      stale while it is on screen; both actions now check LIVE state
--      when you press Enter, so unlocking something already unlocked
--      says so instead of asking for a PIN nothing needed.
-- NEW IN 6.29.1 — APP LOCK: the cover was destroying itself:
--   🩹 Cover mode was really hide mode with an extra step. Covering is
--      immediately followed by hiding the app and focusing Finder — and
--      hiding the frontmost app makes macOS fire `deactivated` for it.
--      6.29.0's deactivate handler removed covers unconditionally, so
--      the panel was torn down roughly a frame after being painted, by
--      our own side effect.
--      The cover is now kept while a challenge is in flight. A genuine
--      switch away (no prompt open) still clears it, and the 3s watchdog
--      is unchanged as the backstop. Verified by restoring the old
--      unconditional removal and watching the suite fail.
--
-- NEW IN 6.29.0 — APP LOCK: COVER INSTEAD OF HIDE (kills the bounce):
--   🖥 The bounce was never a placement bug and could not be patched.
--      HIDING an app forces macOS to hand focus to something else, and
--      on two monitors that drags your view across and straight back.
--      Hiding IS the bounce. 6.27.1 and 6.28.2 both aimed at the wrong
--      thing; only the prompt's position improved.
--      Now: an opaque panel is painted over the locked app's screen,
--      the app is hidden BEHIND that panel (so there is no flash), and
--      focus is sent deliberately to Finder. macOS never gets to choose
--      the destination, so there is nothing to bounce to.
--      Only the screens the app actually occupies are covered — blacking
--      out every monitor to conceal one window would be its own problem.
--   🚪 FOUR WAYS OUT, because a panel that will not clear is worse than
--      any bug in this file so far:
--        1. Enter the PIN.
--        2. ⌘⇧⌃⌥K (or ⇪K) — panic key. A GLOBAL hotkey on purpose, so
--           it fires even if the hyper modal is wedged. The panel says
--           so, on screen, in the text.
--        3. A watchdog every 3s clears any cover with no prompt behind
--           it.
--        4. Quit Hammerspoon — the panel is drawn by Hammerspoon, so it
--           cannot outlive it. That one is true by construction.
--      Each of the first three was verified by deleting it and watching
--      the suite fail.
--   ⚙️ appLockUseCover = false returns to the old hide-only behaviour;
--      appLockCoverThenHide / appLockFallbackApp control the hide and
--      where focus lands. All at §6.6.
--
-- NEW IN 6.28.2 — APP LOCK: the monitor bounce, actually fixed:
--   🖥 6.27.1 claimed to fix this and did not. It captured the locked
--      app's screen inside appLockChallenge — but the watcher HIDES the
--      app before calling that function, and a hidden app has no focused
--      window. appLockRememberScreen returned nil every time, no screen
--      override was ever set, and the PIN prompt kept following the
--      focus bounce to the monitor you came from.
--      The screen is now captured in the watcher BEFORE the hide and
--      passed into the challenge.
--   🧪 WHY THE TEST PASSED ANYWAY: the mock returned a window for an app
--      even while that app was hidden, which cannot happen on a real
--      Mac. It certified code that could not work. The mock now returns
--      nil for a hidden app, and the old ordering fails the test with
--      "prompt opened on the FALLBACK monitor" — the same thing the real
--      Mac was doing.
--
-- NEW IN 6.28.1 — DOCUMENT WATCHER: say it in plain English:
--   💬 The multi-copy rows read "Copy 2 tagged / Enter here copies every
--      tagged row · Enter on a row tags/untags it". "Tagged" was a word
--      invented in this file — it meant nothing to anyone who had not
--      read the source, and the row never said WHY it existed. Rewritten:
--        ☑️ Copy several at once...   (pick rows one at a time)
--        📋 Copy the 2 documents I picked
--        ✖️ Never mind — go back
--      and every row now states what Enter does TO THAT ROW: "Enter
--      copies this one", "Enter adds this to the copy list", "PICKED —
--      Enter removes it from the copy list".
--      A test asserts the invented vocabulary stays out and that every
--      row explains its own Enter. Confusing wording in the only
--      instruction a user ever sees is a defect, not a cosmetic detail.
--
-- NEW IN 6.28.0 — DOCUMENT WATCHER (EXPERIMENTAL SECTION):
--   📄 ⇪W lists every document you have worked in, with how long you
--      spent in each. Searchable by name, extension or date; the first
--      row is a running tally of today's documents and total time.
--      Enter copies the highlighted row. ⇪⇧E edits or deletes an entry
--      (clear the filename and press OK to delete it).
--      Stored as Logs/doc_wather.csv — Date, Time of day, File name,
--      Working time.
--   🧪 It lives inside the EXPERIMENTAL SECTION banner near the end of
--      this file, entirely within one immediately-invoked function. It
--      borrows only logsDir, showPopup, csvQuote and hyperAddShortcut.
--      Delete the whole block and nothing else breaks.
--   ⚠️ THREE DEVIATIONS FROM THE REQUEST, all hs.chooser limits:
--      1. Shift-click multi-select does not exist — hs.chooser is a
--         single-selection list with no modifier-aware click callback.
--         Replaced with a select mode: Enter tags rows (✓) and a
--         "Copy N tagged" row copies them together.
--      2. Bare "W" cannot be a command inside the window; the keyboard
--         belongs to the search field, so it would just type "w". Edit
--         moved to ⇪⇧E, which works while the list is open.
--      3. ⇪W was already the app-summon picker — that moved to ⇪⇧W.
--   ✅ ACCURACY: a sample counts only if you are present (2 min without
--      input stops the clock) and the gap since the last sample is
--      sane. Sleep, stalls and idle gaps are DISCARDED rather than
--      billed to whatever document happened to be open, and any CSV row
--      that is not fully well formed is dropped at load with a count in
--      the Console. Wrong data is worse than missing data here.
--
-- NEW IN 6.27.1 — APP LOCK: the PIN prompt stops bouncing monitors:
--   🖥 ⌘-Tab to a locked app on a second monitor and you landed on the
--      app, then got thrown back to the monitor you came from. Cause:
--      hiding the app makes macOS fall back to whatever was frontmost
--      BEFORE — usually on the other screen — and by the time the prompt
--      opened, showPopup resolved "the frontmost app" to that fallback.
--      The prompt followed the bounce.
--      App Lock now captures the locked app's screen BEFORE hiding it
--      (once hidden it has no window and no screen to ask about) and
--      pins the prompt there via a new _G.popupScreenOverride, which
--      resolveBaseScreen honours ahead of everything else. The override
--      is cleared the moment the prompt is placed — leaving it set would
--      strand every other picker in this config on that monitor.
--      Tested by asserting the actual coordinates the prompt opens at,
--      not merely that a flag was set.
--
-- NEW IN 6.27.0 — APP LOCK: only real apps, and a reachable exit:
--   🧹 The picker listed every running PROCESS, so it filled with
--      loginwindow, photolibraryd, universalaccessd, siriactionsd,
--      nbagent, printtool and dozens more — none of them lockable, and
--      they buried the few apps you actually care about. It now offers
--      an app only if it has a Dock icon (kind() == 1, verified against
--      Hammerspoon source) AND lives under /Applications,
--      /System/Applications or ~/Applications. Helper apps nested inside
--      another bundle are excluded too — they can report a Dock icon.
--      Edit appLockAppRoots at §6.6 if you keep apps somewhere else.
--   ⬆️ "⚙️ Stop protecting an app…" is now the FIRST row. It was at the
--      bottom of a long list and effectively undiscoverable. Safe as the
--      default row: it only opens the removal list, and removing
--      anything still asks for the PIN.
--
-- NEW IN 6.26.0 — APP LOCK: the reason it kept "working once":
--   🔁 A PIN unlocked an app PERMANENTLY, until you re-locked it by hand
--      from ⇪⇧L. So the first switch prompted, and every switch after it
--      correctly did nothing at all — which reads exactly like the
--      feature degrading. It was doing what 6.22 was told to do ("no
--      time limits"), taken literally.
--      New option: RE-LOCK WHEN YOU SWITCH AWAY. Leaving a protected app
--      locks it again, so coming back always asks for the PIN. It is not
--      a timer — nothing expires while you are sitting in the app; it
--      locks on an event, the way a screen lock does.
--      OFF by default (nothing automatic unless you ask), and toggleable
--      straight from ⇪⇧L — "🔁 Re-lock when I switch away: ON/OFF" — so
--      you can try both without editing this file. The choice is saved in
--      applock.json, and the boot report says which mode you are in.
--
-- NEW IN 6.25.1 — APP LOCK: kill the flash when you click the Dock icon:
--   ⚡ ⌘-Tab was already clean; the Dock was not. Your own Console log
--      showed why — every Dock click logged "still visible after hide",
--      and 6.25.0 only LOOKED ONCE, 150ms after hiding. So the window
--      really was on screen for that whole 150ms. That is the flash.
--      It now polls every 30ms and re-hides the instant it sees the
--      window, so the visible moment is ~30ms instead of ~150ms.
--   🐛 A single look was also just wrong: macOS can finish its unhide
--      AFTER that check, and 6.25.0 would sail straight past it, leaving
--      the app sitting visible behind the prompt. The poll now waits for
--      the app to STAY hidden across a few consecutive checks.
--   ⛔️ Bounded: it gives up after ~0.6s and prompts anyway rather than
--      spinning timers at an app that refuses to stay hidden, and it is
--      still ONE poll per challenge — never 6.22's per-event storm.
--
-- NEW IN 6.25.0 — APP LOCK: ESC NO LONGER HANDS YOU THE APP:
--   🚪 THE HOLE: the app could be sitting VISIBLE behind the PIN prompt,
--      and pressing Esc simply closed the prompt and left you in it.
--      Two causes, both fixed:
--      1. A RACE WITH macOS. Clicking a hidden app's Dock icon makes
--         macOS unhide AND activate it. Our hide() lands in the middle
--         and macOS finishes unhiding afterwards — app back on screen,
--         document readable, prompt floating on top. The challenge now
--         confirms the app really went away (0.15s) and re-hides if it
--         didn't, BEFORE the prompt appears.
--      2. CANCEL DID NOTHING. Esc, a wrong PIN, or the prompt closing
--         abnormally now all re-hide the app. Any outcome that is not a
--         successful unlock leaves it off screen.
--   ♻️ This restores what 6.22's retry was protecting, WITHOUT the
--      strobe: 6.22 queued a timer on every activation event, so a
--      ⌘-Tab burst queued dozens. This fires once per challenge, behind
--      promptOpen, and re-checks before acting. A test asserts a
--      25-event burst queues at most one.
--
-- NEW IN 6.24.1 — APP LOCK: FIX "works once, then it's unreliable":
--   🕳 SECURITY HOLE introduced by 6.24.0's own fix. Its 2-second
--      cooldown check sat ABOVE the hide, so during those 2 seconds the
--      handler bailed out completely — and a locked app clicked in the
--      Dock inside that window came back on screen WITH NO PIN. The
--      cooldown now gates only the PROMPT. Hiding happens on every
--      activation, always. (Hiding was never what looped: it moves focus
--      to some OTHER app, which isn't locked, so nothing re-fires. The
--      loop was the prompt reopening as focus returned.)
--      Locking from ⇪⇧L no longer starts a cooldown at all — it opens no
--      prompt, so there is nothing to damp, and the cooldown was just
--      delaying the first real PIN challenge.
--   🩹 A prompt that closed WITHOUT its completion callback running left
--      promptOpen stuck true, and the watcher's early return on that
--      meant App Lock quietly stopped working until a reload. A
--      hideCallback safety net now recovers it and says so in the
--      Console. Silent death was the likeliest cause of "works one time".
--   🔍 DIAGNOSTICS: App Lock now logs what it decided on every event for
--      a locked app — hidden, prompt shown, suppressed by cooldown,
--      ignored. Every bug in this feature so far has been invisible in
--      the Console, which is why they took so many rounds to pin down.
--      Set appLockDebug = false at §6.6 once you're happy with it.
--
-- NEW IN 6.24.0 — APP LOCK: FIX THE STROBE AND THE 5-SECOND BEACHBALL:
--   ⚡ Both symptoms were ONE bug: a focus feedback loop. Hiding an app
--      changes focus, a focus change fires another `activated` event,
--      and closing the PIN chooser hands focus straight back to the app
--      that was just hidden. hide -> focus -> activated -> hide -> …
--      Holding ⌘-Tab feeds that loop a stream of events, so the screen
--      strobed between the app and Hammerspoon (genuinely unpleasant to
--      look at), and the churn pinned the main thread long enough to
--      beachball for about five seconds.
--   🛑 Three changes, each verified to be load-bearing by removing it
--      and watching the tests fail:
--      1. The watcher now returns EARLY — before hiding anything — when
--         a PIN prompt is already open. 6.23 hid first and checked
--         after, so every event in a ⌘-Tab burst hid again.
--      2. A 2-second per-app cooldown after we act. This is what
--         absorbs the focus-return event when the chooser closes, and
--         stops the prompt reopening on itself.
--      3. The 0.15s "hide again in case it bounced back" retry added in
--         6.22 is GONE. It guarded a race that was never confirmed and
--         it was the engine driving the strobe.
--      A test fires 25 activation events in a burst and asserts exactly
--      ONE hide results, plus a separate one for the post-close case.
--
-- NEW IN 6.23.0 — APP LOCK: PIN PROMPT IS A REAL WINDOW, AND ENTER
-- FINALLY DOES THE OBVIOUS THING:
--   🖥 The PIN prompt was an osascript `display dialog`. osascript is a
--      command-line process, not an app, and that one fact caused four
--      separate complaints: it could not take keyboard focus, ⌘-Tab
--      could not reach it, window tools like Scoot could not see it, and
--      it ignored which monitor you were working on. It is now an
--      hs.chooser like every other picker here, so showPopup() puts it
--      on your ACTIVE screen, already focused — just type the PIN.
--      The digits are masked: the real text is held in a buffer and the
--      field is rewritten to bullets on each keystroke, behind a
--      re-entrancy guard so it cannot loop.
--   🔁 FIX the lock / "it says unlocked" / lock rhythm. Every protected
--      app had ONE row and Enter always meant "remove from the protected
--      list". So after unlocking with your PIN, pressing Enter to lock it
--      again quietly UN-PROTECTED it; you then re-added it (2nd press)
--      and locked it (3rd). Enter now flips exactly what the row shows:
--      🔒 LOCKED + Enter asks for the PIN and unlocks · 🔓 UNLOCKED +
--      Enter locks it again immediately. Re-locking needs no PIN (it only
--      adds protection); unlocking always does.
--   🛡 Removing an app from App Lock now REQUIRES the PIN, and lives
--      behind its own "⚙️ Stop protecting an app…" row. Previously
--      anyone could open ⇪⇧L and un-protect an app with one keypress and
--      no PIN, which made the whole lock decorative.
--
-- NEW IN 6.22.0 — APP LOCK: NO TIMER, AND LOCKING ACTUALLY LOCKS:
--   🔒 FIX: locking an app that was ALREADY OPEN did nothing visible.
--      The watcher only reacted to an app launching or being switched
--      to, so locking the app sitting in front of you left it fully
--      usable — you could keep typing in it. Locking now hides the app
--      immediately, and "Re-lock everything now" hides every locked app
--      that is running.
--   ⏱ REMOVED: the 15-minute unlock timer. It was never asked for and
--      made the feature feel arbitrary. An unlock now lasts until YOU
--      lock the app again from ⇪⇧L. The only thing that re-locks on its
--      own is restarting Hammerspoon (unlocks are in memory only —
--      surviving a reboot would defeat the point). If you DO want the
--      screen locking to re-lock everything, flip
--      appLockRelockOnScreenLock at §6.6; it ships off.
--   🐛 hide() failures used to be swallowed by a bare pcall, so a lock
--      that silently did nothing looked identical to one that worked.
--      They now print. Hiding also verifies 0.15s later and re-hides if
--      the app bounced back, which single-shot hiding raced against.
--
-- NEW IN 6.21.1 — FIX: "Set a PIN" did nothing at all:
--   🔑 The PIN dialog never appeared and the Console said nothing. The
--      AppleScript was written across several lines for readability, but
--      AppleScript has NO implicit line continuation (it needs a literal
--      ¬), so osascript failed to COMPILE. It exited non-zero with empty
--      output, which the callback read as "user typed no PIN", and the
--      row looked dead. The `display dialog` statement is now built on a
--      single line, and a non-zero exit is now reported in the Console
--      with the offending script printed — it can't fail mute again.
--
-- NEW IN 6.21.0 — APP LOCK (§6.6, ⇪⇧L):
--   🔒 A PIN gate on chosen apps. A locked app is hidden the moment it
--      launches or comes to the front, and a masked PIN prompt appears;
--      correct PIN un-hides it and keeps it open for 15 minutes. The
--      unlock ends early when the screen locks or the Mac sleeps.
--      ⇪⇧L manages everything: set/change the PIN, and toggle any
--      running app in or out of the locked list.
--
--      ⚠️⚠️ THIS IS A PRIVACY SCREEN, NOT SECURITY. It stops someone
--      casually opening an app on your unlocked Mac. It does NOT stop
--      anyone trying: quitting Hammerspoon removes every lock, a 4-digit
--      PIN is brute-forceable in an instant by anyone who copies the
--      hash file, and it cannot stop reading DATA (locking Finder does
--      nothing about Terminal or `cat`). For OS-enforced app locking use
--      Screen Time → Content & Privacy; for data at rest use FileVault.
--
--      SAFE BY DEFAULT: nothing is locked until you add it yourself, and
--      Hammerspoon can never be locked, so the Console is always
--      reachable. Locked-but-no-PIN-set fails OPEN rather than trapping
--      you. Escape hatch: delete ~/.hammerspoon/applock.json.
--      The PIN hash lives in ~/.hammerspoon/applock.json — local to this
--      Mac, never synced to OneDrive, and now excluded from the nightly
--      backup alongside secret.lua.
--      NO BEACHBALL: the prompt runs as a separate osascript process via
--      hs.task. hs.dialog.textPrompt / hs.osascript block the main
--      thread, which would freeze all of Hammerspoon behind a dialog you
--      walked away from.
--
-- NEW IN 6.20.0 — COMMAND HISTORY PICKER (§6.5, ⇪H):
--   ⌨️ Clipboard History, but for your terminal. ⇪H opens a searchable
--      list of every command in command_history.log; type to filter,
--      Enter copies the command to the clipboard. Newest first, and
--      repeated commands collapse to a single row so a wall of identical
--      lines doesn't bury everything else.
--      ⚠️ THIS CONFIG DOES NOT WRITE THAT LOG — your shell does. So the
--      parser accepts several formats rather than assuming one: plain
--      lines, zsh EXTENDED_HISTORY (": <epoch>:0;cmd"), "[timestamp] cmd",
--      "2026-07-29 03:48:12  cmd", ISO timestamps, and numbered bash
--      history. A line it doesn't recognise is shown as-is rather than
--      dropped. If your format is none of these, tell me and I'll add it.
--      The file is re-read on every open, never cached, or commands run
--      after Hammerspoon started would be invisible.
--      Only the last 512 KB is read (~10,000 commands): the log grows
--      forever, and reading it whole on the main thread is exactly how
--      the §3.7 beachball happened.
--      If no log is found, the Console lists every path it checked —
--      set commandHistoryPath in §6.5 and reload.
--   🔑 New: _G.hyperAddShortcut(mods, key, fn, name) — the supported way
--      to add a NEW hyper shortcut. It runs through the same conflict
--      sentry as everything else. (§0.4's map is only for OLD shortcuts
--      that moved.)
--
-- NEW IN 6.19.0 — EVERY SHORTCUT NOW LIVES ON CAPS LOCK (⇪):
--   ⇪ All 33 shortcuts moved off ⌃⌥⌘ / ⌃⌥ / ⌃⌥⇧ / ⌘⌥⇧ / ⌘⌃⌥⇧ and onto
--      the hyper key. One modifier to hold instead of five combos to
--      remember: ⇪A, ⇪T, ⇪V, ⇪F, ⇪/ …  The full map is in §0.4 and the
--      cheat sheet (⇪/) has been rewritten to match.
--      TWO TIERS, because a flat map was impossible — V, C and O each
--      meant three different things and F/←/→ two apiece:
--        ⇪ + key   → the 25 primary tools
--        ⇪⇧ + key  → edit/delete variants + popup nudging (8)
--      WINDOW KEYS ARE NOW SPATIAL: ⇪←/→ halves, ⇪↑ fill, ⇪↓ put back,
--      ⇪\\ split, ⇪[ / ⇪] move a monitor. That freed F for ⇪F Files.
--      🗑 REMOVED: the five app launchers (Ghostty/Chrome/Outlook/Teams/
--      Sublime) that 6.17.0 added. They were never asked for, and they
--      were sitting on T/C/O/S/M where the real tools belong.
--      SAFETY: two boot-time self-checks, because a silently dead
--      shortcut is the worst outcome here — one warns if two shortcuts
--      land on the same hyper combo, the other warns if a §0.4 entry
--      never matched (meaning that feature quietly kept its OLD key).
--      The boot report's new "Hyper:" line shows both counts.
--      Keys no shortcut claims still forward raw ⌘⇧⌃⌥ to the front app.
--
-- NEW IN 6.18.1 — FIX: endless Console errors on every Caps Lock press:
--   🔇 6.18.0 forwarded F1–F12 as well. Each forwarded key is registered
--      as a BARE hotkey, and macOS reserves some bare function keys
--      system-wide (F11 = Show Desktop), so registering them failed with
--      "RegisterEventHotKey failed: -9878 ... already registered".
--      Entering the modal re-enables every binding, so that error was
--      re-logged on EVERY Caps Lock press — forever. The hyper key still
--      worked; the Console just filled up. Function keys are now OFF by
--      default. Everything else (a–z, 0–9, arrows, punctuation, editing
--      keys) is unchanged. Set hyperForwardFKeys = true at §3.12 to get
--      them back and accept the noise.
--
-- NEW IN 6.18.0 — HYPER KEY IS NOW A REAL ⌘⇧⌃⌥ CHORD (§3.12):
--   ⌨️ Caps Lock no longer fires only the five shortcuts below — it now
--      emits the actual four-modifier chord. Caps Lock + K sends ⌘⇧⌃⌥K
--      to the frontmost app, exactly as if you held all four modifiers.
--      That means hyper works with ANY app you can teach a ⌘⇧⌃⌥ shortcut
--      to (Raycast, Alfred, Rectangle, Slack, browser extensions, app
--      prefs) — the app never needs to know Hammerspoon exists.
--      Covered: a–z, 0–9, F1–F12, arrows, and the usual punctuation.
--      (6.19.0 note: the app launchers this version shipped have been
--      removed, and the config's own shortcuts now claim most keys —
--      see the 6.19.0 entry above for the current layout.)
--
-- NEW IN 6.17.0 — HYPER KEY, NO KARABINER (§3.12):
--   ⌨️ Caps Lock became a 5th modifier via hidutil (see 6.19.0 above for
--      how it behaves now).
--      HOW, WITHOUT AN EXTRA APP: macOS's own /usr/bin/hidutil remaps
--      Caps Lock to F18 (a key in the spec that no Mac keyboard has, so
--      nothing else ever sends it); Hammerspoon treats F18 as hyper.
--      Nothing to install — the whole thing travels in this file, which
--      is the point: same config on the work Macs, no admin install.
--      Re-applied at every Hammerspoon launch, so it survives reboots
--      WITHOUT the LaunchDaemon plist the usual guides require (that
--      route needs admin; this one does not).
--      ⚠️ HONEST LIMIT: macOS Sonoma+ restricts hidutil in some
--      configurations. If it's blocked on a managed Mac the boot log
--      says so plainly on the 🎹 line — it will not fail silently, and
--      nothing else in this config is affected.
--      ⚠️ Caps Lock no longer toggles capitals while this is on. To
--      revert: set hyperEnabled = false and reload, or run
--      hidutil property --set '{"UserKeyMapping":[]}'
-- NEW IN 6.16.23:
--   🧹 File Tracker no longer logs macOS's own internal churn. It was
--      filling with Photos Library guts rewriting themselves every
--      hour (temp-CPAnalyticsPropertiesCache.plist, store.updates,
--      live.0.indexUpdates…). Now excluded: everything INSIDE media/
--      document library bundles (.photoslibrary, .musiclibrary,
--      .fcpbundle, .logicx…), Spotlight index folders, .noindex
--      folders, OS-internal file types (.plist, .db/.sqlite + their
--      -wal/-shm siblings, .log, .lock), and sandbox atomic-save
--      scratch names (foo.plist.sb-9e7584f9-3sh4il).
--      The bundles THEMSELVES are still tracked — move or rename your
--      Photos Library and it still logs; only its internals are quiet.
--      ✏️ Edit fileTrackerNoiseBundles / fileTrackerNoiseExts in §3.8
--      to tune. Verified against the exact paths from the real report.
-- NEW IN 6.16.22:
--   🥶 FIX: the reload beachball is gone. Console timestamps pinned an
--      11-SECOND main-thread freeze to App Monitor's baseline scan,
--      which called hs.application.get(name) once per watched app —
--      20 separate NAME RESOLUTIONS (the gap opened on hs.application's
--      own "alternate names / Spotlight support" line). 6.16.8's 0.1s
--      deferral had only moved it off the config-LOAD path, which is
--      why "-- Done." printed instantly while the UI still locked up
--      right afterward — hs.timer.doAfter runs on the MAIN thread.
--      Replaced with ONE hs.application.runningApplications() call plus
--      a pure-Lua name match: verified 1 bulk call and 0 name lookups,
--      down from 20. Old per-name path kept as a fallback if the
--      enumeration ever returns empty.
-- NEW IN 6.16.21:
--   🔔 App Monitor's popup no longer auto-dismisses after 30s — if
--      you're away when a watched app quits, it now stays on screen
--      (gently pinging every 2s, same "Ping" sound) until you actually
--      respond, however long that takes. Esc still dismisses it and
--      posts a notification either way.
-- NEW IN 6.16.20:
--   🚨 FIX (the REAL remaining cause, found via Console instrumentation):
--      6.16.18 fixed a genuine GC bug but App Monitor still never fired.
--      Live Console evidence (Ghostty AND Microsoft Teams, reproduced
--      twice) showed hs.application.get(name) still reporting the app
--      as RUNNING even 0.3s after its own "terminated" event — re-scan-
--      via-get() is unreliably stale on this Mac. The watcher itself
--      handed us the correct appName directly every time in that same
--      log, so the fix trusts THAT instead: no re-scan, no re-query,
--      no dependency on get() ever catching up. Falls back to the old
--      re-scan only if appName is ever nil (rare safety net).
-- NEW IN 6.16.18:
--   🚨 FIX (real bug, confirmed reproducible): App Monitor never fired
--      for ANY app — Teams, Ghostty, Sublime all confirmed dead — on
--      both Macs. Root cause: 6.16.8's deferred boot setup used
--      hs.timer.doAfter() WITHOUT storing its return value. That's a
--      real, documented Hammerspoon gotcha (confirmed against
--      Hammerspoon's own GitHub issues + wiki) — an unreferenced timer
--      object can be silently garbage-collected before its delay
--      elapses, canceling it with no error. Fixed by holding every
--      such timer in a _G. variable (arrays for ones that can have
--      several in flight at once, self-removing once each fires).
--      Audited the WHOLE file for this same unstored-doAfter pattern
--      and fixed all of them, not just App Monitor's: File Tracker's
--      rename-pairing timer, Autocorrect's injection timer, and the
--      three boot-time alert timers were all equally at risk.
-- NEW IN 6.16.17:
--   🗑 Removed the §3.12 Change History picker (⌃⌥⌘H) and its
--      init_changes.csv backing file, along with the 6.16.15/6.16.16
--      entries proposing/backfilling it — decided it wasn't needed.
--      Changelog entries resume living here as normal, same as always.
--      (If <OneDrive>/Logs/init_changes.csv already got created on a
--      reload, it's harmless to leave or delete by hand — nothing
--      reads it anymore.)
-- NEW IN 6.16.14:
--   🔧 FIX: typing an assignee that matched nobody showed nothing at
--      all in the new inline suggestions — indistinguishable from the
--      feature being broken. Now shows a clear "No team member
--      matches" row (safe no-op, can't be submitted).
--   🚨 FIX (the actual reported bug): a short digit string like "1"
--      typed as the assignee was blindly treated as "already a valid
--      GID" and sent straight to Asana, which rejected it with a raw
--      API error. Real Asana GIDs are long (15+ digits); now requires
--      6+ digits before trusting it as one — anything shorter falls
--      through to the roster lookup and gets the same clear "no
--      match" abort-and-alert as an unresolvable name.
-- NEW IN 6.16.13:
--   👤 The Task Creator (⌃⌥⌘T) now suggests matching Asana team members
--      INLINE while you're typing the Assignee field — no more leaving
--      to ⌃⌥⌘B, copying a name, and coming back. Picking a suggestion
--      splices the exact name into the draft and reopens; it does not
--      submit the task. Suggestions only show while still in that
--      field — once you're typing the attachment path, they stop.
-- NEW IN 6.16.12:
--   ⌨️ Standardized every Asana hotkey onto the same ⌃⌥⌘ chord:
--      ⌃⌥⌘A Format URL · ⌃⌥⌘B Browse Teams (was ⌃⇧⌥M) · ⌃⌥⌘C Comment
--      (was ⌃⇧⌥C) · ⌃⌥⌘T Create task · ⌃⌥⌘L List tasks/Dashboard (was
--      ⌃⇧⌥A). Verified zero conflicts via the file's own §0.3 Hotkey
--      Conflict Sentry (still 33 bound, 0 internal conflicts) before
--      shipping — not just a manual check. Cheat sheet (⌃⌥⌘/) merged
--      the old separate TASKS/DASHBOARD groups into one, matching.
-- NEW IN 6.16.11:
--   🏷️ The ⌃⇧⌥M team picker now shows which team each person is on
--      (subText, e.g. "lee@x.com · SAC Library Core Projects") — cleaned
--      of the "| N. ... |" formatting. Someone on both your teams shows
--      once with both names, not as a duplicate row. Search now matches
--      team name too (searchSubText), so typing "core" narrows to just
--      that team. Doesn't touch hs.chooser's own native ⌘+number row
--      shortcuts — those aren't ours to begin with.
-- NEW IN 6.16.10:
--   🔤 FIX: 6.16.9's team names didn't match — the real Asana team names
--      include the "| N. ... |" formatting (e.g. "| 1. SAC Library Core
--      Projects |"), which the boot log confirmed as two straight
--      "team not found" warnings. asanaTeamNames now has the exact
--      literal names.
-- NEW IN 6.16.9:
--   👥 FIX: the Asana team-member picker (⌃⇧⌥M) searched your ENTIRE
--      organization (thousands of accounts on a big org) instead of
--      just your team. Now scoped to specific team(s) by name — ✏️ EDIT
--      asanaTeamNames near §0.2 to change which team(s) — resolved to
--      their real GIDs once at boot (GET /workspaces/{gid}/teams) and
--      merged from each team's own roster (GET /teams/{gid}/users).
--      Falls back to the old whole-workspace roster if the list is
--      empty or a name doesn't match.
-- NEW IN 6.16.8:
--   🥶 FIX: reload beachballed every time. Timed boot checkpoints (6.16.7,
--      now removed) proved it was Hammerspoon's OWN hs.application module
--      taking 5-12s on its FIRST touch on this Mac, inside App Monitor's
--      boot-time baseline scan — not our loop logic (everything after it,
--      incl. the whole File Tracker FSEvents setup, ran in under a
--      second). Ruled out Microsoft Defender file-scanning and a
--      Gatekeeper network check as the cause (delay persisted with
--      Defender-excluded and with Airplane Mode on) — the cost is
--      apparently inherent on this machine and outside what our code
--      controls. Fix: deferred App Monitor's baseline scan + watcher
--      setup by 0.1s via hs.timer.doAfter, off the synchronous boot
--      path — the other 32 hotkeys are live and the reload itself
--      completes instantly; App Monitor's own protection comes online a
--      few seconds later in the background instead of freezing the
--      whole reload.
-- NEW IN 6.16.6:
--   🚨 FIX: 6.16.4 called hideOnLostFocus() on the report chooser — NOT
--      a real hs.chooser method, so it crashed the entire config on
--      load. Reverted. Escape-to-close still works (it always did,
--      natively) — there's no supported way to also block click-away
--      dismissal.
-- NEW IN 6.16.5:
--   🕒 FIX: Activity Tracker counted "app left frontmost" as usage, not
--      actual use — leaving VLC playing or Sublime open while away from
--      the keyboard for hours inflated its total. Now stops the clock
--      after 5 min of no mouse/keyboard input (hs.host.idleTime), and
--      credits time only up to when idling actually began.
-- NEW IN 6.16.4:
--   📊 Activity Tracker reports now stay on screen until you press Esc —
--      clicking away no longer auto-dismisses them (hideOnLostFocus off).
--   🗓 Added a second weekly-recap firing: Friday 7:30 AM, alongside the
--      existing Monday 7:30 AM one.
-- NEW IN 6.16.1:
--   🔧 FIX: App Monitor's Spawn button didn't relaunch Alfred/Bartender
--      — launchOrFocus(name) needs an exact bundle name, and those ship
--      versioned on disk ("Alfred 5.app"), same mismatch already fixed
--      in the App Update Tracker. Spawn now resolves the real bundle
--      path first (shared findAppBundle) and launches via `open -a`.
-- NEW IN 6.16.0 — GLOBAL COPY-ON-SELECT (§3.11, ⌘⌃⌥⇧C, off by default):
--   🖱️ Highlighting text anywhere — any app, any web page — copies it
--      immediately, like Ghostty's terminal selection already does.
--      Built on an hs.axuielement Accessibility observer watching the
--      frontmost app; re-attaches on every app switch. Auto-copies
--      flow through Clipboard History (⌃⌥⌘V) exactly like a manual ⌘C.
--      HONEST LIMIT: only works where an app exposes standard
--      Accessibility text selection — most native apps and browser
--      page content do; some Electron/custom-drawn UIs don't. Password
--      fields are protected by macOS and never exposed, by design.
-- NEW IN 6.15.4:
--   📌 Boot now prints "init.lua ARCHITECTURE VERSION: X.Y.Z" as the
--      very first Console line — any pasted Console log now proves
--      which file is actually loaded, instead of guessing whether a
--      bug report is against the latest fix or a stale copy.
-- NEW IN 6.15.3:
--   🔧 FIX: clipboard edit/delete (⌘⌃⌥⇧V) always said "That entry is
--      gone" — it matched a choice back to _G.clipboardCache by TABLE
--      IDENTITY, but hs.chooser round-trips every choice through its
--      Objective-C bridge, handing the completion callback a freshly
--      rebuilt table, never the original object. Identity can't
--      survive that. Switched to the same snapshot+index pattern the
--      OCR edit picker already used successfully (a plain number
--      survives the bridge by value, which is exactly why OCR worked
--      and this didn't).
-- NEW IN 6.15.2:
--   🔧 FIX: a clipboard history that failed to parse at boot ("Error
--      deserialising JSON") used to fall back to an empty cache with
--      no warning — and the NEXT save (any edit or copy) then wrote
--      that emptiness over the broken file, permanently losing
--      whatever was still in it. That's the "one edit wiped everything"
--      report. Now: a bad file is backed up (clipboard_history-
--      *.json.corrupt-<timestamp>) with an on-screen warning instead
--      of silently starting empty, AND every save round-trips through
--      decode first — if hs.json.encode ever produces something that
--      doesn't parse back, the write is ABORTED (existing file left
--      alone) rather than committed.
-- NEW IN 6.15.1:
--   🔧 FIX: the team roster fetch 404'd — /projects/{gid}/users isn't
--      a real Asana endpoint (not a private-project permission issue;
--      that would be a 403, and this token already reads/writes this
--      exact project fine elsewhere). Switched to workspace-level user
--      listing, which is both correct AND a better fit: it's every
--      person in the team's Asana workspace, not just whoever's
--      already a member of this one project.
-- NEW IN 6.15.0:
--   🔧 FIX: assigning a task to "Me" or a name ("Lee") failed with
--      Asana's own error — "Not a valid actor ID" — because a display
--      name was sent straight to the API, which only accepts "me", a
--      numeric GID, or an email. resolveAssignee (§5) now resolves a
--      typed name against a cached roster of the project's team before
--      ever calling the API; an unresolvable name now shows a clear
--      alert and ABORTS instead of guaranteeing an API error.
--   👥 ⌃⇧⌥M browses that same roster — Enter copies a member's exact
--      name so pasting it into the Assignee field always resolves.
-- NEW IN 6.14.0 — EDIT / DELETE CLIPBOARD & OCR HISTORY ENTRIES:
--   ✏️ Both histories were browse-and-copy only until now. ⌘⌃⌥⇧V opens
--      the clipboard history to EDIT or DELETE an entry (searchable,
--      same as ⌃⌥⌘V); ⌘⌃⌥⇧O does the same for OCR history. Selecting a
--      row opens a pre-filled dialog — change the text and Save to fix
--      a bad OCR read or a copy you want cleaned up, or clear the text
--      entirely and Save to DELETE that entry (stated plainly in the
--      dialog, no separate delete hotkey needed).
--      Clipboard edits match by the entry's actual identity, not a
--      list position, so a new copy landing while the picker is open
--      can't make an edit land on the wrong row. OCR edits work off a
--      snapshot taken the moment the picker opens, same reasoning.
-- NEW IN 6.13.0 — APP UPDATE TRACKER ACTUALLY INSTALLS (§3.10.1):
--   🍺 HOMEBREW ONE-KEY INSTALL: a row that's both "update-available"
--      AND actually tracked by Homebrew as installed (checked via
--      `brew list --cask --versions` — NOT the same as merely having a
--      valid cask token, since most of these 18 apps were almost
--      certainly installed by direct download, not brew) now installs
--      the update on Enter: `brew upgrade --cask <token>`, then
--      re-checks automatically so the row reflects what really
--      happened. A new "⬆️ Upgrade ALL N brew-managed app(s) now" row
--      appears at the top whenever more than one qualifies, batching
--      them into a single brew invocation.
--      HONEST LIMIT: this is deliberately conservative — an app brew
--      never installed is left alone rather than force-reinstalling
--      over it (which risks a conflict prompt or clobbering settings
--      outside brew's view). Needs an admin-capable account; a
--      locked-down managed Mac may block it entirely.
--   🌐 DOWNLOAD-PAGE FALLBACK: every app now carries its vendor's
--      official download/update page. Any "update-available" row that
--      ISN'T brew-managed, and Microsoft Defender's permanent "no-cask"
--      row, open that page on Enter instead of just copying — covering
--      exactly the apps Homebrew can't touch.
-- NEW IN 6.12.2:
--   🔧 FIX: Alfred and Bartender showed "Not installed here" despite
--      being installed — both ship a VERSIONED .app bundle name on disk
--      (Alfred 5.app, Bartender 5.app), not the fixed "Alfred.app" /
--      "Bartender.app" this tracker assumed. findAppBundle now falls
--      back to a prefix scan of /Applications when the exact name
--      isn't found, the same fix Sublime already needed a one-off
--      appBundle override for — this generalizes it for any app.
--   🔄 FIX: the picker only auto-refreshed on the very first-ever
--      check (or the 9am timer), so a corrected cask token or bundle
--      path kept showing STALE cached results from before the fix
--      until the next scheduled run — which is exactly what made the
--      Defender fix above look like it hadn't taken effect. ⌃⌥⇧U now
--      always kicks a fresh check in the background on open, the same
--      pattern the Asana Dashboard already uses — cheap for something
--      you trigger deliberately, not a background poll.
-- NEW IN 6.12.1:
--   🔧 FIX: Microsoft Defender's guessed cask token ('microsoft-defender')
--      doesn't exist in Homebrew — confirmed by the Console error the
--      6.12.0 self-diagnosis was designed to surface: "No Cask with
--      this name exists." Turns out there's no cask for Defender at
--      all — it's an enterprise product distributed via Microsoft's
--      installer / MDM (Intune, Jamf), not Homebrew. Rather than guess
--      another token, updateTrackerApps entries can now have cask = nil
--      for exactly this case: the tracker still reads the installed
--      version and shows "🔍 No Homebrew cask — check manually" instead
--      of hammering brew with a lookup that can only ever fail.
-- NEW IN 6.12.0 — APP UPDATE TRACKER (§3.10, ⌃⌥⇧U):
--   📦 Answers "which of my apps are behind right now?" so updates can
--      be batched into one IT ticket instead of installed piecemeal.
--      For each app in updateTrackerApps, compares the version actually
--      installed (read from its own Info.plist) against the latest
--      version Homebrew's Cask database knows about — which tracks
--      upstream releases whether or not the app was installed via
--      Homebrew. Results are cached to app_updates-<Mac>.csv, refresh
--      automatically once a day, and ⌃⌥⇧U opens a searchable picker
--      sorted with "update available" first.
--      HONEST LIMIT: no vendor here publishes a public release
--      schedule (Chrome is the closest exception — a new stable
--      roughly every 4 weeks), so this reports the PRESENT, not a
--      forecast. Requires Homebrew on this Mac (read-only — nothing is
--      installed or changed); missing → the feature reports itself off
--      in the boot log. A wrong/renamed cask token is never silent:
--      brew's own error is caught and named per-app in the Console.
-- NEW IN 6.11.3 — ACTIVITY TRACKER: REAL APPS ONLY, NO SLEEP INFLATION:
--   👁 Only regular Dock apps (hs.application kind 1) are tracked now —
--      loginwindow (the lock-screen process) and ScreenSaverEngine were
--      being logged as "apps" because they're whatever's frontmost while
--      the screen is locked. Filtering by kind is self-updating: install
--      a real app tomorrow, it's tracked automatically, nothing to
--      maintain. An activityIgnoredApps table lets you exclude a real
--      app by name if you ever want to.
--   🛌 FIX — THE 30-HOUR GHOST: a session left open across sleep/lock
--      kept its original start time, and Hammerspoon's timers pause
--      during sleep while the wall clock doesn't — so waking up Monday
--      after locking Friday credited whatever was frontmost at lock
--      time with the ENTIRE elapsed span. A new lock/sleep watcher now
--      closes the open session the instant the screen locks or the
--      system sleeps, so its duration stops at the real moment of lock.
--      This was also quietly padding real apps' totals any time the Mac
--      slept while one was frontmost — those historical numbers were
--      somewhat inflated and won't be going forward.
--   🧹 One-time boot cleanup purges any loginwindow / ScreenSaverEngine
--      rows already sitting in your activity_history CSV from before
--      this fix — harmless no-op once the CSV is already clean.
-- NEW IN 6.11.2 — DIAGNOSING "FILE URL(S) BUT NO IMAGE FILES MATCHED":
--   🔍 That Console line said something didn't qualify but never said
--      WHAT. Now it does: the first rejected candidate per copy is
--      captured and printed underneath it — either its extension
--      isn't in the supported list, or it is but the path didn't
--      resolve to a readable local file. Non-printable bytes in the
--      preview render as "?", which immediately shows if what Finder
--      handed over wasn't a plain file:// string at all.
-- NEW IN 6.11.1:
--   🔧 FIX: copying image files in Finder did nothing — the
--      pasteboard file-URL reader (hs.pasteboard.readURL) returns
--      nothing on some Hammerspoon versions, and every failure was
--      swallowed silently. Detection rebuilt on readAllData (the raw
--      pasteboard items, where Finder reliably puts a public.file-url
--      per copied file), with the old readers kept as fallbacks.
--      And it now NARRATES: the Console says how many image files
--      were detected on every copy, says when a file URL was seen
--      but unusable, and says when the OCR shortcut is missing —
--      the next miss diagnoses itself instead of being silent.
-- NEW IN 6.11.0 — OCR TAGS THE FILE ITSELF:
--   🏷 Copy image FILES in Finder (select → ⌘C, up to 15 at once) and
--      each is OCR'd via your "HS OCR" shortcut; the extracted text
--      is written into the file's FINDER COMMENT (Get Info →
--      Comments, capped at 500 chars) — which Spotlight and Finder
--      search index. A folder of screenshots with meaningless names
--      becomes searchable by what's WRITTEN IN the images. The text
--      also lands in the ⌃⌥⌘O OCR history as usual.
--      • Files with an EXISTING comment are never clobbered — the
--        OCR still goes to history; a console line notes the skip.
--      • First run macOS asks "Hammerspoon wants to control Finder"
--        — click OK, or comments can't be written (Automation
--        permission, System Settings → Privacy & Security).
--      HONEST LIMITS: raw clipboard images (screenshots, browser
--      copies) have NO file behind them — they keep going to history
--      only. And Finder comments are LOCAL metadata: OneDrive does
--      not sync them, so a tag written on one Mac won't appear on
--      the other. (Recent macOS also finds image text natively in
--      Spotlight — this makes it explicit, visible, and yours.)
-- NEW IN 6.10.3:
--   🫥 TRANSLUCENT PANELS: the cheat sheet, the dashboard's color
--      legend strip, and the Task Creator's draft mirror are now 80%
--      opaque (were 92–97%), so what's behind them stays visible.
--      One setting controls all three: panelAlpha in §1.5 — raise it
--      toward 1.0 for more solid, lower for more see-through (text
--      readability suffers below ~0.65 over bright backgrounds).
--      HONEST LIMIT: the PICKER LISTS (clipboard, Task Creator,
--      dashboard…) are native macOS hs.chooser panels — Hammerspoon
--      exposes NO opacity control for them, and they already have
--      macOS's built-in slight blur. To watch something behind a
--      picker: nudge it aside with ⌃⌥⌘-arrows (the offset sticks
--      until ⌃⌥⌘R), or hide the front app with ⌃⌥⌘P App Peek.
-- NEW IN 6.10.2:
--   📖 TASK CREATOR — SEE EVERYTHING YOU TYPE (⌃⌥⌘T): the popup is
--      wider (60% of the screen, was 40%), and a LIVE DRAFT MIRROR
--      panel appears just above the box the moment you type — your
--      entire text, word-wrapped across up to 8 lines, updating on
--      every keystroke. Long titles no longer vanish past the edge
--      of the field. Rides along with ⌃⌥⌘-arrow nudges; disappears
--      when the popup resolves.
--      HONEST LIMIT: the input field itself is a native macOS
--      single-line control — Hammerspoon can't make IT wrap, which
--      is why the mirror exists. The field still holds the real
--      text; the mirror is where you read it.
-- NEW IN 6.10.1:
--   📝 TASK CREATOR DRAFT PERSISTENCE (⌃⌥⌘T): whatever you've typed
--      in the box now survives the popup closing — click away, press
--      Esc, or accidentally Enter on a history row, and the next
--      ⌃⌥⌘T restores your exact text (a "Draft restored" alert says
--      so). Every keystroke updates the draft, so nothing is ever
--      more than one reopen away. The draft clears ONLY when a task
--      is actually created (or if you delete the text yourself).
--      In-memory, like window prior-positions — a Hammerspoon reload
--      starts fresh.
-- NEW IN 6.10.0 — ONE DATA HOME (everything syncs, work-Mac ready):
--   ☁️ ALL log, note & history files now live in your OneDrive Logs
--      folder (~/Library/CloudStorage/OneDrive-Personal/Logs) —
--      nothing data-like is stranded in ~/.hammerspoon anymore:
--        PER-MACHINE (tagged with the Mac's name, so the two Macs
--        never fight over a file):
--          clipboard_history-<Mac>.json · asana_history-<Mac>.json ·
--          file_changes-<Mac>.csv — joining activity_history-<Mac>.csv
--          and image_text-<Mac>.csv, which already lived there.
--        SHARED between both Macs (learned once, works everywhere):
--          autocorrect.csv (your 10,970-fix dictionary + every
--          exception ⌃⌥⌘Z ever learns) · custom_shortcuts.json
--          (your ⭐ cheat-sheet entries).
--      Existing files are ADOPTED automatically on first boot after
--      this upgrade — contents copied to the new location, originals
--      left untouched in ~/.hammerspoon. Nothing already recorded is
--      lost.
--   🗑 File Tracker's separate daily 5 PM OneDrive copy removed —
--      the live CSV itself is in OneDrive now, so the copy timer
--      had nothing left to do.
--   🔐 secret.lua is now EXCLUDED from the nightly rsync backup —
--      your Asana token never leaves this Mac, not even into your
--      own OneDrive. (Each Mac keeps its own local secret.lua.)
--   ⚠️ Writes to the Logs folder that fail (OneDrive quit, or the
--      folder set to online-only) now warn ON SCREEN once per file
--      instead of silently losing data. Keep the Logs folder set to
--      "Always keep on this device" in OneDrive.
--   💻 WORK MAC: no edits needed. The portability layer already
--      prefers OneDrive-Personal even when a company OneDrive is
--      also signed in — so both Macs read and write the same Logs
--      folder. Install = copy this file + create secret.lua there.
-- NEW IN 6.9.2:
--   ⌨️ The five core picker hotkeys (§5: format-URL A, clipboard V,
--      task creator T, activity tracker 0, OCR O) moved into an
--      editable coreKeys table — they were the last hardcoded keys
--      in the file. Re-keying any of them is now a one-line edit,
--      checked by the Hotkey Sentry at boot. No behavior change.
-- NEW IN 6.9.1:
--   📋 Clipboard history upgraded: 100 → 1,000 items, and search now
--      matches the FULL text of every item (was only the first 100
--      characters a row displays — a match deep in a long copy was
--      invisible). Re-copying something moves it to the front instead
--      of using a second slot; items over ~1 MB are left out of
--      history so the JSON file stays fast (console line notes it).
--      Render armored like every other picker. Dates now include the
--      day (Jul 13 09:41), since 1,000 items span weeks.
-- NEW IN 6.9.0:
--   📖 247 classic human typos merged into autocorrect.csv (now
--      10,970 fixes): teh→the, mna→man, alot→"a lot" (multi-word
--      corrections work), dont→don't (apostrophes in corrections
--      work), thier, recieve, seperate, libary… — the TextExpander
--      export was machine-generated transpositions and had NONE of
--      them. Real-word traps (wont, cant, its, wether, lets…)
--      screened out by hand, then ALL 10,970 keys machine-audited:
--      zero collide with another entry's correction or with the
--      ~1,200 highest-frequency English words.
--   🔑 HOTKEY CONFLICT SENTRY (§0.3): every hs.hotkey.bind passes
--      through a registry wrapper. Binding the same combo twice
--      inside this config prints a Console warning naming it (the
--      later bind silently kills the earlier feature — now it
--      announces itself). Combos matching known macOS defaults
--      (Spotlight, Spaces, screenshots…) are also flagged. Boot
--      report shows "Hotkeys: N bound, no internal conflicts".
--      Honest limit: other APPS' shortcuts have no public API and
--      can't be detected — the report says so.
-- NEW IN 6.8.1:
--   📚 TWo-caps exceptions properly researched: ~80 defaults (the
--      real taxonomy — two-letter initialisms with s/ed/ing suffixes
--      like DMs/TAs/IDed/DJing, plus units like MHz/GPa/MWh/MBps).
--      "ITs" deliberately excluded: it's a typo of "Its" far more
--      often than a plural of IT.
--   ↩️ ⌃⌥⌘Z — undo & learn: a wrong TWo-caps fix is rewound (if you
--      haven't typed since) AND appended as a permanent "allow" row
--      in autocorrect.csv — the exception list grows itself, since
--      no list of acronyms is ever complete. Wrong dictionary fixes
--      rewind once; the alert names the exact CSV row to delete if
--      you want that permanent (dict entries are deliberate, so
--      they're never silently removed).
-- NEW IN 6.8.0:
--   ✏️ AUTOCORRECT (§3.9, ⌃⌥⌘S toggles): fixes the word you just
--      finished typing, system-wide. Dictionary corrections (mna→man,
--      case-preserving: Mna→Man, MNA→MAN) live EXTERNALLY in
--      autocorrect.csv (~10,700 entries would bloat this file) —
--      plain text, no permissions, auto-seeded with a starter list
--      if missing. TWo-caps typos (MAn→Man, THe→The) are ONE RULE,
--      not data: verified to reproduce all 3,597 ⇪ rows of the
--      source list, and covers words not in it; real two-caps words
--      (IDs, TVs, MHz…) are "allow" rows in the CSV.
--      Needs Accessibility (politely off without it — boot report
--      says so); passwords are protected by macOS secure input;
--      pasted/existing text never touched. Excluded-apps list +
--      30s watchdog (macOS silently disables slow event taps).
-- NEW IN 6.7.4:
--   🔧 FIX: legend was invisible over native FULL-SCREEN apps (their
--      own private Space) — a canvas belongs to one Space unless it
--      declares canJoinAllSpaces + fullScreenAuxiliary, which the
--      picker's panel does internally and ours didn't. Both the
--      legend AND the cheat sheet (same latent bug) now declare them,
--      so both appear everywhere, full screen included. A console
--      line now logs the legend's monitor + frame on every show, so
--      any future placement issue diagnoses itself.
-- NEW IN 6.7.3:
--   🔧 FIX: legend appeared on one monitor but not the other — the
--      picker and the legend each resolved "which screen?" separately,
--      a moment apart, and focus shifting as the popup opens could
--      make them disagree. showPopup now RECORDS the exact placement
--      it used and the legend reuses it verbatim: same monitor, same
--      coordinates, always.
--   🔍 Legend text enlarged to 16px; pills scaled to match, and the
--      strip is clamped fully on-screen at both edges (matters on
--      wide-count days and on monitors left of the main display).
-- NEW IN 6.7.2:
--   🔧 FIX: legend strip overlaid the bottom of the task list — its
--      below-the-picker position relied on estimating the picker's
--      height, and the estimate ran short. Now sits just ABOVE the
--      search field, where placement is exact (we set the picker's
--      top-left ourselves) — overlap is impossible by construction.
--      Clamped so nudging the picker to the screen top can't push the
--      strip off-screen.
-- NEW IN 6.7.1:
--   🎨 Color legend strip under the dashboard picker: one pill per
--      category (red Overdue, yellow Due today, blue Due this week,
--      orange Due later, purple No due date) with the number of rows
--      each contributed. Empty categories show no pill. Appears when
--      the dashboard opens, follows ⌃⌥⌘-arrow nudges, and disappears
--      when the picker resolves (pick, Esc, or click away). Built on
--      hs.canvas since hs.chooser has no footer of its own — its
--      position is estimated from row count, so it may sit a few px
--      off if a macOS update changes row heights (cosmetic only).
-- NEW IN 6.7.0:
--   📅 Dashboard rebuilt (drop-in Section 6 replacement): up to 100
--      tasks across five capped categories, in this order —
--      🔴 Overdue (max 40, newest due first), 🟡 Due today (max 10),
--      🔵 Due this week (max 30, soonest first), 🟠 Due later
--      (max 10, soonest first), 🟣 No due date (max 10, newest
--      created first, listed last). Category names capitalize the
--      first word only. Caps live in the asanaCaps config table.
--      Both ⌃⇧⌥A (open) and ⌃⇧⌥C (comment) modes unchanged.
-- NEW IN 6.6.0:
--   📅 Dashboard (⌃⇧⌥A / ⌃⇧⌥C) now shows EVERY incomplete task, not
--      just dated-within-a-week ones: new ⚪️ NO DUE DATE bucket
--      (newest created first — where fresh tasks live, fixing "recent
--      tasks don't show") and 🟣 LATER bucket (due beyond this week,
--      soonest first). Order: overdue → today → this week → no due
--      date → later. Fetch limit set to 100 tasks explicitly.
-- NEW IN 6.5.2:
--   🔧 FIX: Task Creator went BLANK when the attachment field held a
--      folder path (trailing slash) — basename extraction returned nil
--      and crashed the render callback, which leaves a chooser empty.
--      Fixed, and ALL THREE searchable popups (tasks, activity, file
--      tracker) are now armored: a render error shows an error row
--      pointing at the Console instead of a silent blank window.
-- NEW IN 6.5.1:
--   🔒 Asana token hardening: whitespace around the token in
--      secret.lua is trimmed (a trailing space is invisible but causes
--      a 401 identical to a revoked token), the token's shape is
--      sanity-checked at boot (catches smart quotes / truncated
--      pastes), and a 401 now says "revoked or mistyped — make a new
--      token" instead of a bare status code.
-- NEW IN 6.5.0:
--   🗑 All-display brightness REMOVED (§1.10, its event tap and its
--      30s watchdog): unused, and only ever helped Apple/LG external
--      displays. F1/F2 are now purely stock macOS. Nothing else
--      touched — one less always-running listener.
-- NEW IN 6.4.1:
--   🔧 FIX: 6.4.0 consumed F1/F2 and re-applied brightness itself —
--      on Macs where setBrightness silently no-ops, that killed the
--      keys entirely. Redesigned to NEVER consume: macOS handles the
--      built-in display natively (keys can't break, by construction)
--      and we mirror the resulting level to other supported displays
--      a beat later. Headless Macs get manual stepping. Key-hold
--      events coalesce into one trailing sync.
-- NEW IN 6.4.0:
--   🔆 All-display brightness (§1.10): F1/F2 now adjust EVERY display
--      macOS can control, in sync (native rebuild of the AllBrightness
--      Spoon, ~50 lines). Self-healing: any failure passes the key
--      back to macOS (stock behavior, never broken keys) and a 30s
--      watchdog revives the listener if macOS disables it. Externals
--      respond only if Apple/LG UltraFine (macOS limit — DDC monitors
--      need MonitorControl/Lunar).
-- NEW IN 6.3.1:
--   📁 ~/.hammerspoon is now TRACKED by the File Tracker despite being
--      a hidden folder — init.lua swaps, secret.lua changes, and JSON
--      creations all get a paper trail. Still excluded within it: the
--      tracker's own CSV, hidden items, and the logs/ fallback folder.
--      JSON rewrites stay silent (Modified events aren't logged).
-- NEW IN 6.3.0:
--   📁 File Tracker now watches the ENTIRE home folder + OneDrive:
--      ~/Library excluded (except OneDrive, which gets its own
--      watcher), hidden folders/files excluded, own telemetry (Logs
--      CSVs, Backups/Hammerspoon) excluded so it never logs itself,
--      and a burst guard suppresses Created-row floods (unzips, mass
--      exports) — renames/moves are never suppressed. Note: OneDrive
--      sync means the other Mac's OneDrive file changes appear here
--      too. Exclusion logic verified against 10 boundary cases.
-- NEW IN 6.2.0:
--   📁 File Tracker (§3.8, ⌃⌥⇧F): logs renames, moves, renamed+moved,
--      copies & created files in Desktop/Documents/Downloads (editable
--      list) with old→new names & folders. Searchable picker; Enter
--      copies a row. 90-day history in local Excel-ready
--      ~/.hammerspoon/file_changes.csv, copied daily at 5:00 PM to
--      OneDrive Logs (machine-tagged). Temp/hidden files ignored.
--      Note: macOS reports a copy's destination only — sources of
--      copies are unknowable via FSEvents.
-- NEW IN 6.1.1:
--   🔍 secret.lua diagnostics: the boot report now distinguishes
--      "missing" from "broken" (with the exact Lua error), and a
--      broken file raises an on-screen alert instead of silently
--      looking like a missing one.
-- NEW IN 6.1.0 — TWO MACS, ONE ONEDRIVE, NO COLLISIONS:
--   🏷 Per-machine identity (hostTag from the Mac's name): activity &
--      OCR CSVs are tagged per machine and backups go to
--      Backups/Hammerspoon/<MachineName>/ — two Macs syncing the same
--      Personal OneDrive can no longer create conflict copies or
--      overwrite each other's backups. Existing untagged files are
--      adopted automatically (originals left untouched).
--   ♿️ Accessibility status in the boot PORTABILITY REPORT, with a
--      pointer alert when not granted (window features inactive until
--      then; everything else unaffected).
-- NEW IN 6.0.0 — PORTABLE ARCHITECTURE (work + personal Mac, one file):
--   🧭 §0.1 Portability layer: OneDrive auto-detected per machine
--      (OneDrive-Personal preferred, any OneDrive-* accepted, local
--      ~/.hammerspoon/logs fallback). Override variables provided.
--      Daily backup auto-disables where there's no cloud destination.
--   🔐 §0.2 Credentials moved OUT of this file into per-machine
--      ~/.hammerspoon/secret.lua — init.lua is now secret-free and
--      freely copyable. No secret.lua → Asana features politely off.
--   📴 Graceful degradation: Asana hotkeys gated; image OCR checks at
--      boot whether this Mac's Shortcuts app has the OCR shortcut.
--   🧾 Boot PORTABILITY REPORT in the Console + status in the ready
--      alert. Manifest rewritten. Dead activityLogFile var removed.
-- (Older 4.x / 5.x changelog entries unchanged — see version history
--  in your backups if ever needed.)
-- =====================================================================

-- =====================================================================
-- WHAT EACH TOOL DOES :: ARCHITECTURE VERSION CONTROL: 6.42.0
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

-- DYNAMIC HOME DIRECTORY RESOLUTION
local homeDir = os.getenv("HOME")

-- The boot clock starts here, before any real work, so §1.11's
-- report can say how long loading actually took.
_G.configVersion = "6.42.0"
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
-- A single-column 20pt reference panel of every shortcut in this config,
-- plus any entries YOU add on the fly (⇪=), which persist in
-- custom_shortcuts.json and survive reloads. 6.10.0: that file now
-- lives in the OneDrive Logs folder and is SHARED between both Macs —
-- it changes only when you deliberately add/edit an entry, so the two
-- machines won't fight over it, and a ⭐ entry added on one Mac shows
-- up on the other after its next Hammerspoon reload.
--
-- 6.32.0 — ONE VERTICAL COLUMN THAT SCROLLS. It grows DOWNWARD only:
-- the column is a fixed, readable width (never wider than 760pt or 55%
-- of the screen), as tall as the content needs up to 86% of the screen,
-- and everything past that is reached by scrolling — ↑↓, PgUp/PgDn,
-- Home/End, or the wheel while the pointer is over it. Always sized to
-- the monitor holding the frontmost app (resolveBaseScreen), never
-- spilling off it.
--
-- Built on hs.canvas (Hammerspoon's drawing layer), which is what allows
-- literal 20pt text and a real translucent panel — hs.chooser (the
-- version before that) could do neither. Lessons applied from the
-- webview incident — TWO independent ways to close it:
--   1. ⇪/ again (our own hotkey — always works)
--   2. Esc (captured only while the sheet is visible)
-- A CLICK DOES NOT CLOSE IT (6.31.0): a stray click used to dismiss the
-- reference mid-lookup. Mouse events are off, so clicks pass through.
-- Note: the sheet does NOT take keyboard focus, so it never interrupts
-- typing — but that is also why Esc AND the scroll keys are captured
-- globally while it's up. Close the sheet and they all return to the
-- app underneath.
--
-- ⚠️ The BUILT-IN list is a hand-written snapshot, not auto-generated —
-- if we add/change a hotkey later, ask and I'll keep it in sync.
-- YOUR custom entries never need that; they live in the JSON file.
-- To remove a custom entry, use ⇪- (or edit the JSON directly).
-- ⚠️ ONE TABLE, NOT NINE LOCALS. The main chunk of this file sits ON
-- Lua's hard ceiling of 200 locals — measured, not estimated — and the
-- main chunk IS a function, so every top-level `local` counts. Going one
-- over is a COMPILE error and the WHOLE config fails to load, not just
-- the section that added it. Everything §1.6 needs therefore hangs off
-- one table. Do the same in any new section.
local cheatSheet = {}
cheatSheet.key       = "/"   -- toggle key; same mods as everything above
cheatSheet.addKey    = "="   -- add-a-custom-entry key ("+" without shift)

cheatSheet.customFile = logsDir .. "/custom_shortcuts.json"
adoptLegacyFile(cheatSheet.customFile, hs.configdir .. "/custom_shortcuts.json")

function cheatSheet.loadCustom()
    local f = io.open(cheatSheet.customFile, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local ok, data = pcall(hs.json.decode, content)
    if ok and type(data) == "table" then return data end
    return {}
end

function cheatSheet.saveCustom(list)
    local f = io.open(cheatSheet.customFile, "w")
    if f then f:write(hs.json.encode(list)); f:close()
    else warnWriteFailed("custom_shortcuts.json") end
end

_G.customShortcuts = cheatSheet.loadCustom()

-- Built-ins + custom entries, as ordered groups of {keys, description}.
function cheatSheet.groups()
    local groups = {
        { title = "✅ ASANA — TASKS & DASHBOARD", order = 2, entries = {
            { "⇪A", "Format Asana URL from clipboard" },
            { "⇪B", "Browse Asana Teams — Enter copies a name for Assignee" },
            { "⇪C", "Comment on a task" },
            { "⇪T", "Create a task — type in the Assignee field for inline suggestions" },
            { "⇪L", "List tasks — Today / Week / Overdue" },
            { "auto", "Color legend strip under the list" },
        }},
        { title = "📋 CLIPBOARD & OCR", order = 3, entries = {
            { "⇪V", "Clipboard history" },
            { "⇪⇧V", "Edit or delete a clipboard entry" },
            { "⇪O", "OCR text search" },
            { "⇪⇧O", "Edit or delete an OCR entry" },
            { "⌘C files", "OCR image files → Finder comment tag" },
            { "⇪⇧C", "Toggle copy-on-select (off by default)" },
        }},
        { title = "🕹 POPUP POSITION", order = 5, entries = {
            { "⇪⇧ ↑↓←→", "Nudge popup (hold to repeat)" },
            { "⇪⇧R", "Reset nudge offset" },
        }},
        { title = "⌨️ ⇪ = CAPS LOCK (hold it, tap a key)", order = 14, entries = {
            { "⇪ + key", "Every shortcut on this sheet — hold Caps Lock" },
            { "⇪⇧ + key", "The few second-level ones (edit/delete, nudging)" },
            { "unassigned key", "Sends ⌘⇧⌃⌥+that key to the front app" },
            { "so: Raycast etc.", "Bind them to ⌘⇧⌃⌥ and ⇪ drives them too" },
            { "Caps Lock alone", "No longer toggles capitals (§3.12 reverts)" },
            { "F1–F12", "Not forwarded — macOS reserves some (see 6.18.1)" },
        }},
        { title = "❓ HELP", order = 16, entries = {
            { "⇪/", "Toggle this cheat sheet" },
            { "↑ ↓", "Scroll it a row at a time — hold to keep going" },
            { "PgUp / PgDn", "Scroll a screenful  ·  Home / End jump to the ends" },
            { "scroll wheel", "Scrolls it too, while the pointer is over the sheet" },
            { "⇪=", "Add your own entry to this sheet" },
            { "⇪E", "Edit a custom entry (picker)" },
            { "⇪-", "Remove a custom entry (picker)" },
            { "⇪⇧D", "Diagnostic report — Console + clipboard + Logs file" },
            { "Esc", "Closes this sheet — a click does not" },
        }},
    }

    -- 6.36.0 — GROUPS COME FROM MODULES TOO. A section that has moved
    -- into its own file registers its cheat sheet group when it loads
    -- (§1.12), so this sheet is ASSEMBLED rather than hard-coded.
    -- Delete a module file and its group disappears with it, instead of
    -- the sheet advertising a shortcut that nothing binds any more —
    -- exactly the drift the "hand-written snapshot" warning at the top
    -- of this section has been apologising for since 6.10.
    for _, g in ipairs(_G.moduleCheatsheets or {}) do
        table.insert(groups, { title = g.title, entries = g.entries, order = g.order })
    end

    -- A module that FAILED to load is announced AT THE TOP, not quietly
    -- omitted. A feature that vanishes without explanation is the worst
    -- of both worlds: you reach for the shortcut, nothing happens, and
    -- nothing anywhere tells you why.
    local broken = {}
    for _, rec in ipairs(_G.moduleStatus or {}) do
        if not rec.ok then
            table.insert(broken, { rec.name, tostring(rec.err):sub(1, 64) })
        end
    end
    if #broken > 0 then
        table.insert(groups, { title = "⚠️ MODULES THAT FAILED TO LOAD (⇪⇧D for detail)",
                               entries = broken, order = 0 })
    end

    -- User-added entries, grouped by their group name (default CUSTOM),
    -- in the order groups were first used. They sort last.
    local custOrder, byGroup = {}, {}
    for _, c in ipairs(_G.customShortcuts) do
        local g = (type(c.group) == "string" and c.group ~= "" and c.group or "CUSTOM"):upper()
        if not byGroup[g] then byGroup[g] = {}; table.insert(custOrder, g) end
        table.insert(byGroup[g], { tostring(c.keys or "?"), tostring(c.desc or "") })
    end
    for i, g in ipairs(custOrder) do
        table.insert(groups, { title = "⭐ " .. g, entries = byGroup[g], order = 900 + i })
    end

    -- Assemble. Every group carries a UNIQUE order number, which matters
    -- because table.sort in Lua is NOT stable — equal keys could shuffle
    -- between reloads and the sheet would quietly reorder itself.
    table.sort(groups, function(a, b) return (a.order or 500) < (b.order or 500) end)
    return groups
end

-- ONE NAMESPACE INSTEAD OF NINE TOP-LEVEL LOCALS. This file sits close
-- to Lua's hard ceiling of 200 locals per chunk — and the main chunk IS
-- a function, so every top-level `local` counts against it. Adding the
-- scroll machinery as loose locals went straight past the limit, which
-- is a COMPILE error ("too many local variables"): the entire config
-- would have failed to load, not just the cheat sheet. Fields on one
-- table cost exactly one local no matter how many get added later.

-- ✏️ SEE-THROUGH, this panel only (§1.5's panelAlpha covers the other
-- canvas panels). 1.0 = solid, lower = more see-through. 0.75 shows the
-- window behind the sheet clearly while white text on the near-black
-- panel still reads at roughly 8:1 contrast. Below ~0.6 the shortcuts
-- start losing the fight against a bright background.
cheatSheet.alpha = 0.75

-- ---- The sheet: one tall column you scroll -------------------------
-- 6.32.0 — the sheet used to fill a column, then start ANOTHER column
-- to the right, so on a long list it grew sideways into a wall of text.
-- It is now a single column that grows DOWNWARD and scrolls.
--
-- hs.canvas has no scroll view: a canvas clips to its frame but has no
-- viewport, so "scrolling" here means painting a DIFFERENT WINDOW OF
-- ROWS. That is why layout and render are separate below —
-- cheatSheet.show() works out the rows and the panel once, and
-- cheatSheet.render() paints only the rows currently in view (~30 canvas
-- elements no matter how long the list gets). Scrolling changes one
-- number and repaints, so a fast trackpad flick can't get expensive.
--
-- EVERY ROW IS THE SAME HEIGHT, headers included (blank spacer rows do
-- the separating instead of a variable gap). That is a deliberate
-- constraint, not a simplification: it means the view is always a whole
-- number of rows, so no row is ever half-drawn at the top or bottom
-- edge, and the scroll maths is exact rather than approximate.
--
-- THREE ways to close it, unchanged: ⇪/ again, Esc, or the panic route
-- of reloading. A CLICK STILL DOES NOT CLOSE IT (6.31.0) and mouse
-- events stay off, so clicks pass through to whatever is underneath.
--
-- ⚠️ While the sheet is up it claims Esc, the arrows, PgUp/PgDn and
-- Home/End GLOBALLY — it takes no keyboard focus, so that is the only
-- way it can hear them. Close the sheet and every one of those keys
-- goes straight back to the app underneath. The wheel is different: it
-- is only claimed while the pointer is actually over the panel.
_G.cheatSheetCanvas     = nil   -- the panel itself, while it is up
_G.cheatSheetState      = nil   -- layout + scroll position for that panel
_G.cheatSheetEscHotkey  = nil   -- Esc closes         (enabled only while up)
_G.cheatSheetScrollKeys = nil   -- ↑↓ PgUp/PgDn Home/End    (same)
_G.cheatSheetWheelTap   = nil   -- trackpad / mouse wheel    (same)

function cheatSheet.hide()
    if _G.cheatSheetEscHotkey then
        pcall(function() _G.cheatSheetEscHotkey:disable() end)
    end
    for _, hk in ipairs(_G.cheatSheetScrollKeys or {}) do
        pcall(function() hk:disable() end)
    end
    if _G.cheatSheetWheelTap then
        pcall(function() _G.cheatSheetWheelTap:stop() end)
    end
    if _G.cheatSheetCanvas then
        pcall(function() _G.cheatSheetCanvas:delete() end)
        _G.cheatSheetCanvas = nil
    end
    _G.cheatSheetState = nil
end

-- Paint the rows currently in view. Safe to call any time: with no
-- sheet up it does nothing.
function cheatSheet.render()
    local st, canvas = _G.cheatSheetState, _G.cheatSheetCanvas
    if not (st and canvas) then return end

    local els = {}

    -- The panel. Near-black rather than grey ON PURPOSE: at the same
    -- alpha a darker panel keeps white text readable over a bright
    -- window behind it, which is the whole trade being made here.
    -- Tune the see-through with cheatSheet.alpha at the top of §1.6.
    table.insert(els, {
        type = "rectangle", action = "strokeAndFill",
        fillColor   = { red = 0.06, green = 0.06, blue = 0.08, alpha = cheatSheet.alpha },
        strokeColor = { white = 1, alpha = 0.22 },
        strokeWidth = 1,
        roundedRectRadii = { xRadius = 16, yRadius = 16 },
    })

    table.insert(els, {
        type = "text", text = "⌨️  Hammerspoon Shortcuts",
        textSize = st.titleSize, textColor = { white = 1 }, textAlignment = "center",
        frame = { x = 0, y = st.pad * 0.55, w = st.panelW, h = st.titleH },
    })

    local last = math.min(#st.lines, st.first + st.visible - 1)
    local y = st.contentTop
    for i = st.first, last do
        local line = st.lines[i]
        if line.kind == "header" then
            table.insert(els, {
                type = "text", text = line.text,
                textSize = st.headerSize,
                textColor = { red = 0.55, green = 0.83, blue = 1.0 },
                frame = { x = st.contentX, y = y, w = st.contentW, h = st.lineH },
            })
        elseif line.kind == "entry" then
            table.insert(els, {
                type = "text", text = line.text,
                textSize = st.entrySize, textColor = { white = 1.0 },
                frame = { x = st.contentX, y = y, w = st.contentW, h = st.lineH },
            })
        end   -- a "spacer" row draws nothing; it just holds the gap open
        y = y + st.lineH
    end

    -- Scrollbar, only when there is actually something to scroll. It is
    -- the only thing telling you more text exists below the fold, so it
    -- is drawn even though nothing can drag it.
    if st.maxFirst > 1 then
        local trackY, trackH = st.contentTop, st.visible * st.lineH
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { white = 1, alpha = 0.10 },
            roundedRectRadii = { xRadius = 3, yRadius = 3 },
            frame = { x = st.sbX, y = trackY, w = st.sbW, h = trackH },
        })
        local thumbH = math.max(30, trackH * (st.visible / #st.lines))
        local thumbY = trackY + (trackH - thumbH) * ((st.first - 1) / (st.maxFirst - 1))
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { white = 1, alpha = 0.50 },
            roundedRectRadii = { xRadius = 3, yRadius = 3 },
            frame = { x = st.sbX, y = thumbY, w = st.sbW, h = thumbH },
        })
    end

    local footer
    if st.maxFirst > 1 then
        footer = string.format(
            "%d–%d of %d   ·   ↑↓ PgUp/PgDn or scroll   ·   Esc or ⇪/ closes   ·   ⇪= adds",
            st.first, last, #st.lines)
    else
        footer = "Esc or ⇪/ closes   ·   ⇪= adds an entry"
    end
    table.insert(els, {
        type = "text", text = footer,
        textSize = 13, textColor = { white = 0.62 }, textAlignment = "center",
        frame = { x = 0, y = st.panelH - st.footerH - 4, w = st.panelW, h = st.footerH },
    })

    local ok, err = pcall(function() canvas:replaceElements(els) end)
    if not ok then
        print("⌨️ Cheat sheet: render failed — " .. tostring(err))
    end
end

-- Scrolling is CLAMPED, never wrapped: you cannot scroll past either
-- end, and a redraw that shortens the list (deleting a custom entry
-- while the sheet is open) pulls the view back into range instead of
-- leaving you staring at blank rows.
function cheatSheet.scrollTo(index)
    local st = _G.cheatSheetState
    if not st then return end
    local target = math.floor(math.max(1, math.min(st.maxFirst, index)))
    if target ~= st.first then
        st.first = target
        cheatSheet.render()
    end
end

function cheatSheet.scrollBy(delta)
    local st = _G.cheatSheetState
    if not st then return end
    cheatSheet.scrollTo(st.first + delta)
end

-- A page keeps two rows of overlap so you don't lose your place.
function cheatSheet.pageStep()
    local st = _G.cheatSheetState
    return st and math.max(1, st.visible - 2) or 1
end

function cheatSheet.wheelHandler(e)
    local st = _G.cheatSheetState
    if not st then return false end

    -- Only claim the wheel when the pointer is over the sheet. Anywhere
    -- else the event passes straight through, so the window underneath
    -- scrolls normally while the sheet sits open beside it.
    local okPos, pos = pcall(hs.mouse.absolutePosition)
    if not (okPos and pos) then return false end
    local r = st.rect
    if pos.x < r.x or pos.x > r.x + r.w or pos.y < r.y or pos.y > r.y + r.h then
        return false
    end
    if st.maxFirst <= 1 then return true end   -- nothing to scroll, but the
                                               -- sheet still swallows it

    local props = hs.eventtap.event.properties
    local rows = 0
    local continuous = e:getProperty(props.scrollWheelEventIsContinuous)
    if continuous and continuous ~= 0 then
        -- Trackpads report PIXELS, mice report LINES. The pixels are
        -- accumulated across events, otherwise a slow two-finger drag
        -- rounds to zero every time and the sheet never moves.
        local px = e:getProperty(props.scrollWheelEventPointDeltaAxis1) or 0
        st.wheelAccum = (st.wheelAccum or 0) + px
        rows = st.wheelAccum / st.lineH
        rows = (rows >= 0) and math.floor(rows) or math.ceil(rows)
        st.wheelAccum = st.wheelAccum - rows * st.lineH
    else
        local d = e:getProperty(props.scrollWheelEventDeltaAxis1) or 0
        rows = (d >= 0) and math.floor(d) or math.ceil(d)
    end

    if rows ~= 0 then
        -- A POSITIVE delta always means "move the view toward the top",
        -- under natural AND legacy scrolling — macOS flips the sign
        -- itself — so this needs no preference check. Capped so one
        -- violent flick can't teleport you to the end.
        cheatSheet.scrollBy(-math.max(-10, math.min(10, rows)))
    end
    return true
end

-- Built once, then enabled/disabled with the sheet. Every step is
-- individually pcall'd: if one key can't be bound the sheet still opens
-- and still scrolls by the other routes, and the Console says which one
-- was lost rather than the whole feature dying.
function cheatSheet.enableInput()
    if not _G.cheatSheetEscHotkey then
        local ok, hk = pcall(hs.hotkey.new, {}, "escape", cheatSheet.hide)
        if ok then _G.cheatSheetEscHotkey = hk end
    end
    if not _G.cheatSheetScrollKeys then
        local defs = {
            { "up",       function() cheatSheet.scrollBy(-1) end },
            { "down",     function() cheatSheet.scrollBy(1) end },
            { "pageup",   function() cheatSheet.scrollBy(-cheatSheet.pageStep()) end },
            { "pagedown", function() cheatSheet.scrollBy(cheatSheet.pageStep()) end },
            { "home",     function() cheatSheet.scrollTo(1) end },
            { "end",      function() cheatSheet.scrollTo(math.maxinteger) end },
        }
        local keys = {}
        for _, d in ipairs(defs) do
            -- Same function as pressedfn AND repeatfn, so holding the
            -- key keeps scrolling instead of moving exactly one row.
            local ok, hk = pcall(hs.hotkey.new, {}, d[1], d[2], nil, d[2])
            if ok and hk then
                table.insert(keys, hk)
            else
                print("⌨️ Cheat sheet: couldn't bind " .. d[1] .. " for scrolling")
            end
        end
        _G.cheatSheetScrollKeys = keys
    end
    if not _G.cheatSheetWheelTap then
        local ok, tap = pcall(hs.eventtap.new,
            { hs.eventtap.event.types.scrollWheel }, cheatSheet.wheelHandler)
        if ok then _G.cheatSheetWheelTap = tap end
    end

    if _G.cheatSheetEscHotkey then
        pcall(function() _G.cheatSheetEscHotkey:enable() end)
    end
    for _, hk in ipairs(_G.cheatSheetScrollKeys or {}) do
        pcall(function() hk:enable() end)
    end
    if _G.cheatSheetWheelTap then
        pcall(function() _G.cheatSheetWheelTap:start() end)
    end
end

-- preserveScroll: redraws triggered by adding/editing/deleting an entry
-- keep your place in the list. A fresh ⇪/ always starts at the top.
function cheatSheet.show(preserveScroll)
    local keepFirst = (preserveScroll and _G.cheatSheetState
                       and _G.cheatSheetState.first) or 1
    cheatSheet.hide()  -- never stack two

    -- ---- layout metrics (20pt text as originally requested) ----
    local entrySize, headerSize, titleSize = 20, 20, 24
    local lineH = 30                          -- uniform row height, see above
    local pad, titleH, footerH = 26, 46, 34
    local sbW = 6                             -- scrollbar width

    local screen = resolveBaseScreen()
    local sf = screen:frame()

    -- ONE COLUMN, ALWAYS. Wide enough to read comfortably, capped so it
    -- stays a panel instead of a wall on a 4K monitor, and shrunk to fit
    -- a laptop display. It never grows sideways — length goes downward
    -- and you scroll it.
    local panelW   = math.max(360, math.min(760, sf.w * 0.55))
    local contentX = pad
    local contentW = panelW - pad * 2 - sbW - 10

    -- ⚠️ 6.31.0 — ENTRIES WRAP INSTEAD OF BEING CLIPPED.
    -- Each entry was one canvas text element in a fixed-width frame, so
    -- anything longer than the column was silently CUT OFF mid-sentence
    -- ("F1-F12 — Not forwarded — macOS reserves some"). Nothing warned;
    -- the text just stopped. Long entries are now split across
    -- continuation lines, indented under the key so the column still
    -- reads cleanly.
    --
    -- Width is estimated, not measured: hs.canvas has no text-metrics
    -- call, so this uses an average glyph width for the font size. The
    -- estimate is deliberately CONSERVATIVE (0.52 of the point size) —
    -- wrapping a line one word early is invisible, running past the
    -- column edge is the bug we are fixing.
    local wrapChars = math.max(20, math.floor(contentW / (entrySize * 0.52)))

    -- All widths are in CHARACTERS, and every string here can contain
    -- multi-byte glyphs (⇪, ⌘, —, emoji), so length must be measured
    -- with utf8.len — Lua's # counts BYTES and would over-count these
    -- badly, wrapping far too early. utf8.len returns nil on malformed
    -- input, hence the fallback.
    local function ulen(str)
        return (utf8 and utf8.len(str)) or #str
    end

    local INDENT = "      "   -- continuation lines sit under the key
    local function wrapEntry(keys, desc)
        local out  = {}
        local head = keys .. "  —  "
        local headLen = ulen(head)

        -- If the key label alone eats most of the column there is no
        -- room to start the description beside it, so the key gets its
        -- own line and the whole description wraps underneath. The old
        -- fallback kept writing beside a long key and simply overran the
        -- column, which is the clipping this function exists to prevent.
        local sameLine = (wrapChars - headLen) >= 12
        local budget   = sameLine and (wrapChars - headLen)
                                   or (wrapChars - ulen(INDENT))
        if not sameLine then table.insert(out, head) end

        local line, first = "", sameLine
        local function flush()
            if line == "" then return end
            table.insert(out, (first and head or INDENT) .. line)
            first = false
            budget = wrapChars - ulen(INDENT)
            line = ""
        end
        for word in tostring(desc):gmatch("%S+") do
            local candidate = (line == "") and word or (line .. " " .. word)
            if ulen(candidate) > budget and line ~= "" then
                flush()
                line = word
            else
                line = candidate
            end
        end
        if line ~= "" then
            flush()
        elseif #out == 0 then
            table.insert(out, head)
        end
        return out
    end

    -- Flatten every group into one flat list of rows. A blank spacer row
    -- separates groups, which keeps every row the same height.
    local lines = {}
    for gi, g in ipairs(cheatSheet.groups()) do
        if gi > 1 then table.insert(lines, { kind = "spacer", text = "" }) end
        table.insert(lines, { kind = "header", text = g.title })
        for _, e in ipairs(g.entries) do
            for _, seg in ipairs(wrapEntry(tostring(e[1]), tostring(e[2]))) do
                table.insert(lines, { kind = "entry", text = seg })
            end
        end
    end

    -- Height: as tall as the content needs, up to 86% of the screen.
    -- A SHORT list gets a short panel (no dead space); a long one fills
    -- the height and scrolls.
    local contentTop = pad + titleH
    local chromeH    = contentTop + footerH + 8
    local panelH     = math.min(sf.h * 0.86, chromeH + #lines * lineH)
    local visible    = math.max(1, math.floor((panelH - chromeH) / lineH))
    -- Snap to a whole number of rows so there is never a half-row strip
    -- of dead space above the footer.
    panelH = chromeH + visible * lineH
    local maxFirst = math.max(1, #lines - visible + 1)

    local rect = {
        x = sf.x + (sf.w - panelW) / 2,
        y = sf.y + (sf.h - panelH) / 2,
        w = panelW,
        h = panelH,
    }

    local canvas = hs.canvas.new(rect)
    if not canvas then
        hs.alert.show("❌ Couldn't create cheat sheet — check Hammerspoon Console")
        return
    end

    _G.cheatSheetCanvas = canvas
    _G.cheatSheetState  = {
        lines      = lines,
        first      = math.max(1, math.min(maxFirst, keepFirst)),
        visible    = visible,
        maxFirst   = maxFirst,
        lineH      = lineH,
        entrySize  = entrySize,
        headerSize = headerSize,
        titleSize  = titleSize,
        pad        = pad,
        titleH     = titleH,
        footerH    = footerH,
        panelW     = panelW,
        panelH     = panelH,
        rect       = rect,
        contentX   = contentX,
        contentW   = contentW,
        contentTop = contentTop,
        sbX        = panelW - pad * 0.6 - sbW,
        sbW        = sbW,
        wheelAccum = 0,
    }

    cheatSheet.render()
    _G.diag.say("cheatSheet", string.format("opened: %d rows, %d visible, panel %dx%d",
        #lines, visible, panelW, panelH))

    pcall(function() canvas:level(hs.canvas.windowLevels.overlay) end)
    -- Same Spaces/full-screen visibility fix as the dashboard legend:
    -- without these, the sheet can't appear over full-screen apps.
    pcall(function() canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
    -- 6.31.0 — CLICK NO LONGER CLOSES THE SHEET. It used to, and a
    -- stray click anywhere on the panel dismissed the reference you were
    -- reading mid-lookup. Mouse events are left OFF entirely so clicks
    -- pass through to whatever is underneath instead of being swallowed
    -- (the wheel is handled by an eventtap, not by the canvas).
    canvas:show()

    cheatSheet.enableInput()
end

function cheatSheet.toggle()
    if _G.cheatSheetCanvas then
        cheatSheet.hide()
    else
        cheatSheet.show()
    end
end

hs.hotkey.bind(popupScreenKeys.mods, cheatSheet.key, cheatSheet.toggle)

-- ⌃⌥⌘= — add a custom entry to the sheet, persisted across reloads.
-- Same pipe format as the task creator: Keys | Description | Group
-- (group optional, defaults to CUSTOM). Example:
--   ⌘⇧5 | Screenshot & recording menu | MACOS
hs.hotkey.bind(popupScreenKeys.mods, cheatSheet.addKey, function()
    local button, text = hs.dialog.textPrompt(
        "⭐ Add cheat sheet entry",
        "Format:  Keys | Description | Group     (Group is optional)\nExample:  ⌘⇧5 | Screenshot menu | MACOS",
        "", "Add", "Cancel")
    if button ~= "Add" or not text or #text == 0 then return end

    local parts = {}
    for seg in text:gmatch("([^|]+)") do
        table.insert(parts, seg:match("^%s*(.-)%s*$"))
    end
    local keys, desc, group = parts[1] or "", parts[2] or "", parts[3] or ""
    if keys == "" or desc == "" then
        hs.alert.show("⚠️ Need at least: Keys | Description")
        return
    end

    table.insert(_G.customShortcuts, { keys = keys, desc = desc, group = group })
    cheatSheet.saveCustom(_G.customShortcuts)
    hs.alert.show("⭐ Added to cheat sheet")

    -- If the sheet is open right now, redraw it with the new entry
    if _G.cheatSheetCanvas then cheatSheet.show(true) end
end)

-- ⌃⌥⌘- — remove a custom entry: opens a picker of everything you've
-- added; selecting one deletes it from custom_shortcuts.json. Built-in
-- entries never appear here — they can't be deleted this way.
cheatSheet.removeKey = "-"

_G.choosers.removeShortcut = hs.chooser.new(function(choice)
    if not (choice and choice.idx) then return end
    local removed = table.remove(_G.customShortcuts, choice.idx)
    cheatSheet.saveCustom(_G.customShortcuts)
    hs.alert.show("🗑 Removed: " .. (removed and removed.keys or "entry"))
    if _G.cheatSheetCanvas then cheatSheet.show(true) end
end)
_G.choosers.removeShortcut:placeholderText("Select a custom entry to DELETE — Esc cancels")

hs.hotkey.bind(popupScreenKeys.mods, cheatSheet.removeKey, function()
    if #_G.customShortcuts == 0 then
        hs.alert.show("⭐ No custom entries yet — add one with ⌃⌥⌘=")
        return
    end
    local choices = {}
    for i, c in ipairs(_G.customShortcuts) do
        table.insert(choices, {
            text    = (c.keys or "?") .. "  —  " .. (c.desc or ""),
            subText = "🗑 Deletes on select  ·  group: " .. ((c.group and c.group ~= "") and c.group or "CUSTOM"),
            idx     = i,
        })
    end
    _G.choosers.removeShortcut:choices(choices)
    showPopup(_G.choosers.removeShortcut)
end)

-- ⌃⌥⌘E — edit a custom entry: opens the same style of picker, but
-- selecting an entry re-opens the add dialog PRE-FILLED with its
-- current values. Change what you want, keep the pipe format, hit
-- Save — the entry is updated in place (same position, same file).
-- Esc at either step cancels without changing anything.
cheatSheet.editKey = "E"

_G.choosers.editShortcut = hs.chooser.new(function(choice)
    if not (choice and choice.idx) then return end
    local c = _G.customShortcuts[choice.idx]
    if not c then return end

    local current = (c.keys or "") .. " | " .. (c.desc or "")
    if c.group and c.group ~= "" then
        current = current .. " | " .. c.group
    end

    local button, text = hs.dialog.textPrompt(
        "✏️ Edit cheat sheet entry",
        "Format:  Keys | Description | Group     (Group is optional)",
        current, "Save", "Cancel")
    if button ~= "Save" or not text or #text == 0 then return end

    local parts = {}
    for seg in text:gmatch("([^|]+)") do
        table.insert(parts, seg:match("^%s*(.-)%s*$"))
    end
    local keys, desc, group = parts[1] or "", parts[2] or "", parts[3] or ""
    if keys == "" or desc == "" then
        hs.alert.show("⚠️ Need at least: Keys | Description — entry unchanged")
        return
    end

    _G.customShortcuts[choice.idx] = { keys = keys, desc = desc, group = group }
    cheatSheet.saveCustom(_G.customShortcuts)
    hs.alert.show("✏️ Updated: " .. keys)
    if _G.cheatSheetCanvas then cheatSheet.show(true) end
end)
_G.choosers.editShortcut:placeholderText("Select a custom entry to EDIT — Esc cancels")

hs.hotkey.bind(popupScreenKeys.mods, cheatSheet.editKey, function()
    if #_G.customShortcuts == 0 then
        hs.alert.show("⭐ No custom entries yet — add one with ⌃⌥⌘=")
        return
    end
    local choices = {}
    for i, c in ipairs(_G.customShortcuts) do
        table.insert(choices, {
            text    = (c.keys or "?") .. "  —  " .. (c.desc or ""),
            subText = "✏️ Opens pre-filled editor  ·  group: " .. ((c.group and c.group ~= "") and c.group or "CUSTOM"),
            idx     = i,
        })
    end
    _G.choosers.editShortcut:choices(choices)
    showPopup(_G.choosers.editShortcut)
end)

-- =====================================================================
-- 1.11 DIAGNOSTICS — ⇪⇧D writes the report I need to debug anything
-- =====================================================================
-- THE PROBLEM THIS SOLVES. When something misbehaves, the Console shows
-- what Hammerspoon chose to log, which is rarely what actually matters.
-- The ⌥Tab freeze was only diagnosable because two unrelated lines
-- happened to bracket it. This section makes that luck unnecessary.
--
-- ⇪⇧D builds a full report — versions, boot timings, screens, hotkey
-- counts, feature states, file paths with their write status, a LIVE
-- window-enumeration timing, the last errors, and the last 25 internal
-- events — then does three things with it: prints it to the Console,
-- copies it to your clipboard, and writes it to
--   <logsDir>/diagnostics-<machine>.txt
-- Paste it into chat and I have the whole picture in one message
-- instead of asking you six questions.
--
-- TWO LEVELS, deliberately:
--   • THE TRAIL is always recorded (a 200-entry ring buffer in memory,
--     no I/O, no Console noise). So the report can show what happened
--     just before a problem even though verbose mode was off at the
--     time — which is the normal case, because nobody runs verbose
--     until after something breaks.
--   • VERBOSE also PRINTS each of those events live. Turn it on without
--     reloading by typing this in the Hammerspoon Console:
--         _G.diag.verbose = true
--     Turn it off the same way with false. Nothing persists it: a
--     reload always comes back quiet.
--
-- ERRORS ARE CAPTURED EVEN WHEN NOBODY IS WATCHING. hs.uncaughtErrorHandler
-- is set below, so a Lua error thrown inside an async callback — an HTTP
-- reply, a timer, a watcher, all the places a pcall in the calling
-- function cannot reach — lands in the report with a timestamp instead
-- of scrolling past in the Console.
_G.diagBootStart = _G.diagBootStart or hs.timer.secondsSinceEpoch()

-- Extends the no-op stub declared at the top of the file rather than
-- replacing it, so anything already recorded survives.
_G.diag.verbose   = false   -- live-toggle in the Console: _G.diag.verbose = true
_G.diag.trail     = _G.diag.trail  or {}   -- ring buffer of recent events
_G.diag.errors    = _G.diag.errors or {}   -- ring buffer of errors, newest last
_G.diag.marks     = _G.diag.marks  or {}   -- boot timings, in order
_G.diag.maxTrail  = 200
_G.diag.maxErrors = 30

function _G.diag.stamp()
    return os.date("%H:%M:%S")
end

-- Record an event. Always stored, printed only in verbose mode.
function _G.diag.say(tag, msg)
    local line = string.format("%s [%s] %s", _G.diag.stamp(), tostring(tag), tostring(msg))
    local t = _G.diag.trail
    t[#t + 1] = line
    while #t > _G.diag.maxTrail do table.remove(t, 1) end
    if _G.diag.verbose then print("🔍 " .. line) end
end

-- Record AND always print: for things worth seeing without verbose on.
function _G.diag.warn(tag, msg)
    _G.diag.say(tag, msg)
    print("⚠️ " .. tostring(tag) .. ": " .. tostring(msg))
end

function _G.diag.err(err)
    local line = string.format("%s %s", os.date("%Y-%m-%d %H:%M:%S"), tostring(err))
    local e = _G.diag.errors
    e[#e + 1] = line
    while #e > _G.diag.maxErrors do table.remove(e, 1) end
    _G.diag.say("error", tostring(err))
end

-- Boot timings. Called at the end of the heavy sections; the report
-- prints them in order so a slow start says WHICH part was slow.
function _G.diag.mark(name)
    local at = hs.timer.secondsSinceEpoch() - (_G.diagBootStart or 0)
    table.insert(_G.diag.marks, { name = name, at = at })
    _G.diag.say("boot", string.format("%s at %.3fs", name, at))
end

-- A Lua error in an async callback (HTTP reply, timer, watcher) cannot
-- be caught by a pcall in the function that scheduled it. This is the
-- only place it can be seen at all.
hs.uncaughtErrorHandler = function(err)
    _G.diag.err(err)
    print("💥 UNCAUGHT: " .. tostring(err))
    pcall(function() hs.alert.show("💥 Hammerspoon error — ⇪⇧D for the report") end)
end

-- Decode JSON that came off the network WITHOUT throwing. hs.json.decode
-- raises on malformed input, and every caller in this file is an async
-- HTTP callback, so a throw there escapes to the handler above and the
-- operation dies with an unhelpful message. A corporate proxy or captive
-- portal answering HTTP 200 with an HTML login page is exactly that
-- case, and it is far likelier on a work network than a broken API.
function _G.safeJson(body, tag)
    if type(body) ~= "string" or body == "" then
        _G.diag.warn(tag or "json", "empty response body")
        return nil
    end
    local ok, data = pcall(hs.json.decode, body)
    if not ok then
        _G.diag.warn(tag or "json",
            "response was not JSON (" .. #body .. " bytes, starts: "
            .. body:sub(1, 60):gsub("%s+", " ") .. ")")
        return nil
    end
    return data
end

-- ---- the report -----------------------------------------------------
function _G.diag.fileInfo(path)
    if not path then return "not configured" end
    local attrs = hs.fs.attributes(path)
    if not attrs then return path .. "  (MISSING)" end
    local writable = "read-only?"
    if attrs.mode == "directory" then
        local probe = path .. "/.hs-write-probe"
        local f = io.open(probe, "w")
        if f then f:close(); os.remove(probe); writable = "writable" end
        return string.format("%s  (dir, %s)", path, writable)
    end
    local f = io.open(path, "a")
    if f then f:close(); writable = "writable" end
    return string.format("%s  (%d bytes, %s)", path, attrs.size or 0, writable)
end

function _G.diag.report()
    local L = {}
    local function add(fmt, ...)
        local ok, s = pcall(string.format, fmt, ...)
        table.insert(L, ok and s or fmt)
    end

    add("🩺 HAMMERSPOON DIAGNOSTIC REPORT — %s", os.date("%Y-%m-%d %H:%M:%S"))
    add("   config version : %s", tostring(_G.configVersion or "?"))
    pcall(function()
        add("   Hammerspoon    : %s", tostring(hs.processInfo.version))
    end)
    pcall(function()
        add("   macOS          : %s", hs.host.operatingSystemVersionString())
    end)
    add("   machine        : %s", tostring(hostTag))
    add("   accessibility  : %s", hs.accessibilityState() and "granted" or "NOT GRANTED")
    add("   lua memory     : %.0f KB", collectgarbage("count"))
    add("   verbose mode   : %s", _G.diag.verbose and "ON" or "off  (_G.diag.verbose = true)")

    add("")
    add("── BOOT ──────────────────────────────────────────────")
    if #_G.diag.marks == 0 then
        add("   (no marks recorded)")
    else
        for _, m in ipairs(_G.diag.marks) do add("   %-28s %6.3fs", m.name, m.at) end
    end

    add("")
    add("── SCREENS ───────────────────────────────────────────")
    pcall(function()
        for _, s in ipairs(hs.screen.allScreens()) do
            local f = s:frame()
            add("   %-24s %dx%d at (%d,%d)", s:name() or "?", f.w, f.h, f.x, f.y)
        end
    end)

    add("")
    add("── HOTKEYS ───────────────────────────────────────────")
    add("   global bound   : %s   conflicts: %s",
        tostring(_G.hotkeyBoundCount), tostring(_G.hotkeyConflictCount))
    add("   hyper          : %s shortcuts + %s forwarded, %s conflicts",
        tostring(_G.hyperShortcutCount or 0), tostring(_G.hyperForwardCount or 0),
        tostring(_G.hyperConflictCount or 0))

    add("")
    add("── FEATURES ──────────────────────────────────────────")
    add("   Asana          : %s", asanaEnabled and "on" or "off")
    add("   Autocorrect    : %s", tostring(_G.autocorrectStatus or "?"))
    add("   Autocorrect tap: %s", (function()
        if not _G.autocorrectTap then return "not created" end
        local ok, on = pcall(function() return _G.autocorrectTap:isEnabled() end)
        return (ok and on) and "running" or "STOPPED (macOS may have disabled it)"
    end)())
    add("   Cheat sheet    : %s", _G.cheatSheetState and "open" or "closed")
    -- The switcher is a MODULE now, so "not loaded" is a real state the
    -- report has to be able to say out loud.
    local at = _G.altTab
    add("   ⌥Tab switcher  : %s", at and string.format(
        "%s · minimised:%s · cap:%s · session:%s",
        at.enabled and "on" or "OFF", tostring(at.includeMinimized),
        tostring(at.maxWindows), at.session and "OPEN" or "idle")
        or "module not loaded")

    add("")
    add("── SERVICES (published by modules) ───────────────────")
    do
        local names = {}
        for k in pairs((_G.service or {}).registry or {}) do table.insert(names, k) end
        table.sort(names)
        add("   %s", #names > 0 and table.concat(names, ", ") or "(none)")
    end

    add("")
    add("── MODULES ───────────────────────────────────────────")
    add("   folder         : %s", tostring(_G.moduleDir))
    if not _G.moduleStatus or #_G.moduleStatus == 0 then
        add("   (none listed)")
    else
        for _, rec in ipairs(_G.moduleStatus) do
            add("   %-18s %-7s %5.0fms%s", rec.name,
                rec.ok and "loaded" or "FAILED", rec.ms,
                rec.ok and "" or ("   — " .. tostring(rec.err)))
        end
    end

    add("")
    add("── LIVE PROBE (measured right now) ───────────────────")
    -- This is the measurement that mattered for the ⌥Tab freeze: how
    -- long this Mac actually takes to enumerate its windows.
    pcall(function()
        local t0 = hs.timer.secondsSinceEpoch()
        local wins = hs.window.orderedWindows() or {}
        local dt = hs.timer.secondsSinceEpoch() - t0
        add("   orderedWindows : %d windows in %.3fs%s", #wins, dt,
            dt > 0.35 and "   ⚠️ SLOW" or "")
    end)
    pcall(function()
        local app = hs.application.frontmostApplication()
        add("   frontmost app  : %s", app and app:name() or "?")
    end)

    add("")
    add("── PATHS ─────────────────────────────────────────────")
    add("   logs dir       : %s", _G.diag.fileInfo(logsDir))
    add("   backup dir     : %s", _G.diag.fileInfo(backupDir))
    pcall(function()
        add("   custom cuts    : %s", _G.diag.fileInfo(logsDir .. "/custom_shortcuts.json"))
        add("   autocorrect    : %s", _G.diag.fileInfo(logsDir .. "/autocorrect.csv"))
        add("   changelog      : %s", _G.diag.fileInfo(logsDir .. "/changelog.csv"))
    end)

    add("")
    add("── ERRORS (%d) ───────────────────────────────────────", #_G.diag.errors)
    if #_G.diag.errors == 0 then
        add("   none recorded since load")
    else
        for _, e in ipairs(_G.diag.errors) do add("   %s", e) end
    end

    add("")
    add("── LAST 25 EVENTS ────────────────────────────────────")
    local t, from = _G.diag.trail, math.max(1, #_G.diag.trail - 24)
    if #t == 0 then
        add("   (nothing recorded yet)")
    else
        for i = from, #t do add("   %s", t[i]) end
    end
    add("")
    add("── END OF REPORT ─────────────────────────────────────")
    return table.concat(L, "\n")
end

-- ⇪⇧D — print it, copy it, save it. Three routes because the one you
-- need is never the one that is working.
function _G.diag.show()
    local ok, text = pcall(_G.diag.report)
    if not ok then
        print("🩺 Diagnostics failed to build: " .. tostring(text))
        hs.alert.show("🩺 Diagnostics failed — see Console")
        return
    end
    print("\n" .. text .. "\n")
    pcall(function() hs.pasteboard.setContents(text) end)

    local saved = false
    pcall(function()
        local path = logsDir .. "/diagnostics-" .. tostring(hostTag) .. ".txt"
        local f = io.open(path, "w")
        if f then f:write(text); f:close(); saved = true
            print("🩺 Diagnostic report → " .. path)
        end
    end)
    hs.alert.show(saved and "🩺 Report copied to clipboard + saved to Logs"
                        or "🩺 Report copied to clipboard (file write failed)")
end

hs.hotkey.bind({ "ctrl", "alt", "cmd", "shift" }, "D", _G.diag.show)

_G.diag.mark("§1.11 diagnostics ready")

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
            if exitCode == 0 then
                print("🎹 Hyper key ON — Caps Lock is the hyper modifier (it no longer toggles capitals)")
            else
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
    local currentVersion = "6.42.0"
    local currentDate    = "08-05-26"
    local currentNotes   = "FIX (major): hyper+0 crashed with attempt to call a nil value (renderActivityChoices). When section 3.6 became a module its functions went with it, but hotkey handlers left behind in init.lua kept calling them by bare name — and Lua turns a vanished local into a nil GLOBAL, so nothing failed until the key was pressed. A static scan found two: renderActivityChoices (Activity Tracker) and addCommentToTask (Asana Comments, called from the task creator and the dashboard). Both fixed properly rather than patched: modules now PUBLISH what the rest of the config may call via core.provide, callers use _G.service.call, and a missing provider prints which module is absent instead of crashing. The registry is stubbed on line one so it can never itself be nil, and it is listed in the hyper+shift+D report. A permanent regression guard was added to the audit suite: it walks init.lua for calls to any function that now lives in a module, which is the check that would have caught this before delivery and did not exist. FIX (medium): a broken Homebrew (corrupt API cache) printed check the token in updateTrackerApps fifteen times, sending you to fix something that was never wrong; the two causes are now told apart and the brew-side one is reported ONCE per check with the actual repair command. Not caused by this config: the Homebrew API cache corruption itself — rm -rf $(brew --cache)/api and brew update --force."

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

print("🧭 PORTABILITY REPORT — " .. hostTag)
print("   Storage:  " .. (cloudDir and ("OneDrive found → " .. cloudDir) or ("no OneDrive → local " .. logsDir)))
print("   Data:     ALL log/note/history files in " .. logsDir)
print("             (per-machine files tagged -" .. hostTag .. " · shared: autocorrect.csv, custom_shortcuts.json)")
print("   Backup:   " .. (backupDir or "disabled (no cloud destination)") .. " (secret.lua excluded)")
print("   Asana:    " .. (asanaEnabled and "ON (secret.lua loaded)"
    or ("OFF — secret.lua " .. secretsStatus)))
print("   Autocorrect: " .. (_G.autocorrectStatus or "off"))
print("   Hotkeys:  " .. _G.hotkeyBoundCount .. " global bound, "
    .. (_G.hotkeyConflictCount == 0 and "no internal conflicts"
        or (_G.hotkeyConflictCount .. " CONFLICTS — see warnings above"))
    .. " (other apps' shortcuts aren't detectable)")
print(string.format("   Boot:     %.2fs to here  ·  ⇪⇧D writes a diagnostic report",
    hs.timer.secondsSinceEpoch() - (_G.diagBootStart or hs.timer.secondsSinceEpoch())))
print("   Modules:  " .. tostring(_G.moduleLoaded or 0) .. " loaded, "
    .. tostring(_G.moduleFailed or 0) .. " failed  ·  profile: " .. tostring(_G.moduleProfileName)
    .. "  ·  " .. tostring(_G.moduleDir))
print("   Hyper:    " .. tostring(_G.hyperShortcutCount or 0)
    .. " shortcuts on ⇪ (Caps Lock) + "
    .. tostring(_G.hyperForwardCount or 0) .. " keys forwarding ⌘⇧⌃⌥, "
    .. ((_G.hyperConflictCount or 0) == 0 and "no conflicts"
        or (_G.hyperConflictCount .. " CONFLICTS — see warnings above")))
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
local axOK = false
pcall(function() axOK = hs.accessibilityState() end)
print("   Access:   " .. (axOK and "Accessibility granted"
    or "NOT granted — window features inactive (System Settings → Privacy & Security → Accessibility)"))
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