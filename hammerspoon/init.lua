-- =====================================================================
-- * Working VERSION *
-- =====================================================================
-- =====================================================================
-- 08-04-26 using Claude
-- =====================================================================
-- .Hammerspoon ARCHITECTURE VERSION CONTROL: 6.31.4-CAP-CHANGELOG-EMMYLUA
-- =====================================================================
--
-- NEW IN 6.31.4 — THE TWO DEFERRED ITEMS, AND EDITOR AUTOCOMPLETE:
--   🧯 HARD 50,000-ROW CAP on both tracker CSVs. This is the piece that
--      was missing: chunked loading (6.11.3) stopped a huge history
--      from BLOCKING boot, but nothing stopped the file growing to the
--      ~400,000 rows that caused the 13-second beachball. Keeps the
--      NEWEST rows and says on the console what it trimmed.
--   📋 changelog.csv in the Logs folder — Date | Version | Change
--      notes, appended once per version, never duplicated.
--   💡 EmmyLua annotations for editor autocomplete on hs.*. Zero
--      runtime cost, prints one line and carries on if not installed.
--      See the README: the generated files do nothing until your
--      EDITOR is pointed at them.
--   🔢 ONE version string instead of three. Three separate literals is
--      precisely how 6.31.1 shipped a stale 6.30.0 in the tool index —
--      two got bumped, one did not. Everything executable now reads
--      _G.configVersion.
--
-- NEW IN 6.31.3 — DESKTOPS, THE W SWAP, AND A RECONCILIATION:
--   🖥 MOVE A WINDOW TO ANOTHER DESKTOP: ⇪⇧[ and ⇪⇧]. Bare brackets
--      move it a MONITOR, shift moves it a DESKTOP (Space). Built on
--      hs.spaces, which drives PRIVATE macOS APIs — read the warning
--      at §X.3 before relying on it. Every failure path names the step
--      that broke instead of doing nothing.
--   🔄 ⇪W IS THE APP-SUMMON PICKER AGAIN; the Document Watcher moved to
--      ⇪⇧W. This was promised in a delivery that never reached this
--      file's lineage, which is why ⇪W kept opening the wrong thing.
--   🌫 panelAlpha 0.80 → 0.90. Same missed delivery.
--   🔔 OCR FAILURES ARE NO LONGER SILENT. A file that isn't an image
--      stays quiet (console only, as before), but an image we TRIED and
--      failed on now raises an alert naming why — shortcut error, no
--      text found, or nothing typeable. All three were bare returns.
--   🔄 Hammerspoon now appears in the update tracker (§3.10).
--
--   📋 RECONCILIATION: this file descends from 6.30.0 and silently
--      missed everything delivered after it. Audited every feature
--      promised across that history against what is actually here.
--      Still missing, deliberately deferred rather than rushed:
--      the 50,000-row cap on the tracker CSVs (beachball prevention)
--      and the changelog.csv writer. Both are noted in the README.
--
-- NEW IN 6.31.2 — HOUSEKEEPING (no behaviour changes):
--   🧹 The "Lee additions" app list is gone from this header. It was a
--      duplicate of the live watched-apps list in §3.7 (search for
--      appMonitorApps), which has always been the one the code reads.
--      Two copies of a list is one copy too many — edit §3.7.
--   📅 Header date now reads 08-04-26, per the standing rule that it is
--      updated on every delivery.
--   🔢 Fixed a stale version string in the §1 tool index: it still said
--      6.30.0 while the header and the boot print said 6.31.1. All three
--      now agree.
--
-- NEW IN 6.31.1 — CHEAT SHEET: ONE COLUMN, SEARCHABLE, SCROLLS:
--   🔎 There is a search box at the top now. Type to filter by key,
--      description or group; multiple words all have to match, in any
--      order, so "asana task" finds the task creator. Enter copies the
--      highlighted key combo.
--   📜 ONE COLUMN, FIXED HEIGHT, SCROLLS. The canvas version grew to fit
--      its content — columns filled downward then spilled sideways, so
--      every shortcut added made the sheet wider until it owned the
--      screen. Adding entries now costs scrolling, never screen.
--   🔤 SPELLED-OUT MODIFIERS FIND THE GLYPHS. This sheet is written in
--      ⇪ ⇧ ⌘ ⌥ ⌃ ← ↑ → ↓ and none of those are on the keyboard you would
--      search with. Typing "shift" and getting nothing back makes the
--      box look broken when it is only being literal, so every glyph a
--      row contains also contributes the words people actually type.
--      Tested in the direction that matters: searching the WORD never
--      misses a row carrying the GLYPH.
--   🧨 THE SEARCH IS PLAIN-TEXT, NOT PATTERN. A cheat sheet is full of
--      ⇪[ ⇪\ ⇪- ⇪/ and typing one of those into a box that fed Lua's
--      pattern engine would hand it a malformed pattern. Every one of
--      those characters is now a test case.
--   ⚠️ TWO THINGS GIVEN UP, both real. Literal 20pt text (hs.chooser
--      picks its own row font) and panelAlpha translucency (native
--      macOS panels expose no opacity API — the same limit §1.5 has
--      always noted for the picker LISTS).
--   ⚠️ IT TAKES KEYBOARD FOCUS NOW, because a search box you cannot type
--      into is not a search box. Upside: the old sheet floated without
--      focus and therefore had to capture Esc GLOBALLY, with a warning
--      to close it before pressing Esc in another app. That hazard is
--      gone. Downside: you can no longer type into another window while
--      it is open. Glance and dismiss, rather than leave it up.
--   ↩️ This reverses the 6.10 decision on purpose. The old comment said
--      canvas was chosen BECAUSE hs.chooser is single-column only —
--      still true, and now that is the requirement.
--
-- NEW IN 6.31.0 — QUICK NOTES → ASANA (EXPERIMENTAL SECTION):
--   🗒 ⇪N is a capture box: type a thought, press Enter, forget it. At
--      4:00 PM every note captured that day becomes a task on your
--      personal Asana project. ⇪⇧N searches the history, ⇪⇧G sends
--      early, ⇪⇧P raises a see-through panel that stays up until Esc.
--   📝 THE TITLE IS NEVER GUESSED. A note that already starts with a verb
--      is used verbatim ("Email Dana the invoice"). One that does not
--      cannot be honestly rewritten into an instruction, so it is
--      prefixed instead: "printer toner low" → "Task from notes: printer
--      toner low". You can always tell which happened by reading it.
--      Known limit, tested and left alone: a noun that is also a verb
--      ("budget numbers for Q3") reads as imperative. First-word
--      detection cannot separate those, and the failure is a slightly
--      awkward title, never a wrong one.
--   🏷 CUSTOM FIELDS. Row 2 of the capture box opens your project's real
--      Asana custom fields — enum, multi-enum, text, number, date — and
--      you can set any of them, or walk all of them in one pass. The
--      choices ride along in the CSV and go up with the task.
--   🔤 QWERTY ONLY on the way out, the same rule the OCR path uses:
--      smart quotes and em dashes are folded to plain equivalents first
--      (stripping alone would turn "don't" into "dont"), then anything
--      still off a standard keyboard is dropped.
--   🛡 A ROW IS RANGE-CHECKED, NOT JUST SHAPE-CHECKED. "2026-13-99" and
--      "99:99" both satisfy the obvious %d%d%d%d-%d%d-%d%d pattern the
--      Document Watcher uses. Here a bad row does not merely look odd in
--      a list — it gets POSTED to Asana as a real task, and a sent task
--      cannot be un-sent. Found by testing, fixed before shipping.
--   ⚠️ ONE HONEST CONFLICT IN THE REQUEST. A panel that stays on screen
--      while you work, AND a bare number key that opens a row, cannot
--      both be true: while the panel is up those digits belong to it.
--      Bare 1-9 is the default because that is what was asked for; ⇪1-⇪9
--      always work and never take a key from anything, and
--      qnPanelBareDigits = false switches to those alone. A 30s watchdog
--      releases the keys if the panel ever vanishes still holding them.
--   🧪 Lives entirely inside one immediately-invoked function in the
--      EXPERIMENTAL SECTION. Delete the block and nothing else breaks.
--
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
--      (6.31.1: the cheat sheet left this group — it is an hs.chooser
--      now, and native panels have no opacity API.)
--      One setting controls the rest: panelAlpha in §1.5 — raise it
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
-- WHAT EACH TOOL DOES :: ARCHITECTURE VERSION CONTROL: 6.31.4
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
-- ⇪/  SHORTCUT CHEAT SHEET (§1.6)
--    A floating multi-column panel listing every hotkey in this
--    config. Press again, Esc, or click to close. Add your own
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
--    ⇪W       picker: summon any running app to this monitor
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
    -- 6.31.3: swapped back. Summoning an app to this monitor is the
    -- far more frequent action, so it takes the bare letter; the
    -- Document Watcher moved to ⇪⇧W. (6.28.0 had it the other way.)
    ["alt+ctrl+w"]           = { {},        "w"     },  -- summon-an-app picker
    ["alt+cmd+ctrl+["]       = { {},        "["     },  -- monitor left
    ["alt+cmd+ctrl+]"]       = { {},        "]"     },  -- monitor right
    -- ---- Cheat sheet & custom entries ----
    ["alt+cmd+ctrl+/"]       = { {},        "/"     },  -- toggle cheat sheet
    ["alt+cmd+ctrl+="]       = { {},        "="     },  -- add entry
    ["alt+cmd+ctrl+-"]       = { {},        "-"     },  -- remove entry
    ["alt+cmd+ctrl+e"]       = { {},        "e"     },  -- edit entry
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

-- ✏️ PANEL TRANSLUCENCY (6.10.3) — one number for every canvas panel:
-- the dashboard legend strip (§6) and the Task Creator draft mirror
-- (§4). 1.0 = solid, lower = more see-through; below ~0.65 the white
-- text gets hard to read over bright windows. (The picker LISTS are
-- native macOS panels with no opacity API — this can't affect them; see
-- the 6.10.3 note above.)
-- 6.31.1: the cheat sheet used to be the third one. It is an hs.chooser
-- now (§1.6), so it is a native panel and this number no longer reaches
-- it — that is the same opacity limit, not a regression in this setting.
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
-- 1.6 SHORTCUT CHEAT SHEET — ⇪/ toggle · type to search · ⇪= to add
-- =====================================================================
-- A single searchable, scrolling column of every shortcut in this config,
-- plus any entries YOU add on the fly (⇪=), which persist in
-- custom_shortcuts.json and survive reloads. 6.10.0: that file now
-- lives in the OneDrive Logs folder and is SHARED between both Macs —
-- it changes only when you deliberately add/edit an entry, so the two
-- machines won't fight over it, and a ⭐ entry added on one Mac shows
-- up on the other after its next Hammerspoon reload.
--
-- 6.31.1 — BACK ON hs.chooser: ONE COLUMN, SEARCHABLE, SCROLLS.
-- The canvas version grew to fit its content: columns filled downward and
-- then spilled sideways, so every shortcut added made the sheet wider
-- until it owned the screen. That is the wrong shape for a reference you
-- open, glance at, and dismiss. It is now a single scrolling column with
-- a search box at the top:
--   • Type to filter — matches the key, the description or the group.
--     Multiple words all have to match, in any order, so "asana task"
--     finds the task creator.
--   • The list is a FIXED height and scrolls. Adding entries makes it
--     longer to scroll, never bigger on screen.
--   • Enter copies the highlighted key combo (same idiom as every other
--     picker in this file).
--
-- ⚠️ THIS REVERSES THE 6.10 DECISION, deliberately. The comment that used
--    to live here said canvas was chosen BECAUSE "hs.chooser is
--    single-column only". That was true and is still true — single
--    column is now the requirement, so the reason to avoid hs.chooser
--    became the reason to use it. Two things are genuinely given up:
--    literal 20pt text (hs.chooser sets its own row font) and the
--    panelAlpha translucency (native macOS panels expose no opacity
--    API — the same 6.10.3 limit noted at §1.5).
--
-- ⚠️ AND IT NOW TAKES KEYBOARD FOCUS. It has to: a search box you cannot
--    type into is not a search box. The old canvas sheet floated without
--    focus, which is why it had to capture Esc globally and warned you
--    to close it before pressing Esc in another app. That whole hazard
--    is gone — Esc now belongs to the sheet because the sheet is what is
--    focused — but you can no longer type into another window while it
--    is open. Glance and dismiss, rather than leave it up.
--
-- Still THREE independent ways to close it, the lesson from the webview
-- incident, and all three are now native rather than hand-rolled:
--   1. ⇪/ again (our own hotkey — always works)
--   2. Esc
--   3. Click anywhere outside it
--
-- ⚠️ The BUILT-IN list is a hand-written snapshot, not auto-generated —
-- if we add/change a hotkey later, ask and I'll keep it in sync.
-- YOUR custom entries never need that; they live in the JSON file.
-- To remove a custom entry, use ⇪- (or edit the JSON directly).
local cheatSheetKey  = "/"   -- toggle key; same mods as everything above
local addShortcutKey = "="   -- add-a-custom-entry key ("+" without shift)

local customShortcutsFile = logsDir .. "/custom_shortcuts.json"
adoptLegacyFile(customShortcutsFile, hs.configdir .. "/custom_shortcuts.json")

local function loadCustomShortcuts()
    local f = io.open(customShortcutsFile, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local ok, data = pcall(hs.json.decode, content)
    if ok and type(data) == "table" then return data end
    return {}
end

local function saveCustomShortcuts(list)
    local f = io.open(customShortcutsFile, "w")
    if f then f:write(hs.json.encode(list)); f:close()
    else warnWriteFailed("custom_shortcuts.json") end
end

_G.customShortcuts = loadCustomShortcuts()

-- Built-ins + custom entries, as ordered groups of {keys, description}.
local function cheatSheetGroups()
    local groups = {
        { title = "✅ ASANA — TASKS & DASHBOARD", entries = {
            { "⇪A", "Format Asana URL from clipboard" },
            { "⇪B", "Browse Asana Teams — Enter copies a name for Assignee" },
            { "⇪C", "Comment on a task" },
            { "⇪T", "Create a task — type in the Assignee field for inline suggestions" },
            { "⇪L", "List tasks — Today / Week / Overdue" },
            { "auto", "Color legend strip under the list" },
        }},
        { title = "📋 CLIPBOARD & OCR", entries = {
            { "⇪V", "Clipboard history" },
            { "⇪⇧V", "Edit or delete a clipboard entry" },
            { "⇪O", "OCR text search" },
            { "⇪⇧O", "Edit or delete an OCR entry" },
            { "⌘C files", "OCR image files → Finder comment tag" },
            { "⇪⇧C", "Toggle copy-on-select (off by default)" },
        }},
        { title = "📊 ACTIVITY TRACKER", entries = {
            { "⇪0", "Open — today's totals" },
            { "type: week", "This week's totals" },
            { "type: month", "Top apps & documents this month" },
            { "type: anything", "Search all saved history" },
            { "Enter", "Copy row to clipboard" },
            { "auto 4:00 PM", "Daily report pops up" },
            { "auto Mon 7:30 AM", "Weekly recap pops up" },
        }},
        { title = "👁 APP MONITOR (automatic)", entries = {
            { "Enter", "Spawn (relaunch) or End" },
            { "Esc", "Dismiss (stays open otherwise, no timeout) → posts notification" },
        }},
        { title = "🕹 POPUP POSITION", entries = {
            { "⇪⇧ ↑↓←→", "Nudge popup (hold to repeat)" },
            { "⇪⇧R", "Reset nudge offset" },
        }},
        { title = "🪟 WINDOW ARRANGER", entries = {
            { "⇪← / ⇪→", "Left / right half of screen" },
            { "⇪↑", "Fill screen (not full-screen mode)" },
            { "⇪\\", "Split two most recent windows side-by-side" },
            { "⇪W", "Summon an app to this monitor (picker)" },
            { "⇪↓", "Return window to prior spot (toggles)" },
            { "⇪[ / ⇪]", "Move window left / right a monitor" },
            { "⇪⇧[ / ⇪⇧]", "Move window to previous / next desktop (Space)" },
        }},
        { title = "📁 FILE TRACKER", entries = {
            { "⇪F", "Rename / move / copy history (searchable)" },
            { "Enter", "Copy row  ·  90-day history" },
        }},
        { title = "📦 APP UPDATES", entries = {
            { "⇪U", "Which apps are behind right now (searchable)" },
            { "auto 9:00 AM  ·  auto on open", "Always checks fresh" },
            { "Enter (brew-managed)", "Installs the update via Homebrew" },
            { "Enter (not brew-managed)", "Opens the vendor's download page" },
            { "⬆️ Upgrade ALL row", "Installs every brew-managed update at once" },
        }},
        { title = "✏️ AUTOCORRECT", entries = {
            { "⇪S", "Toggle on/off" },
            { "⇪Z", "Undo last fix & learn the exception" },
            { "auto", "Fixes typos & TWo-caps as you type (autocorrect.csv)" },
        }},
        { title = "👀 APP PEEK", entries = {
            { "⇪P", "Hide frontmost app — press again to bring back" },
        }},
        { title = "📄 DOCUMENT WATCHER (experimental)", entries = {
            { "⇪⇧W", "Documents worked on today — search name / ext / date" },
            { "Enter", "Copy the highlighted row" },
            { "☑️ row", "Copy several: pick rows with Enter, then copy together" },
            { "⇪⇧E", "Edit or delete an entry (clear the name = delete)" },
            { "auto", "Samples every 5s · stops when you are idle" },
            { "file", "Logs/doc_wather.csv — Date · Time · File · Working time" },
        }},
        { title = "🗒 QUICK NOTES → ASANA (experimental)", entries = {
            { "⇪N", "Capture a note — type it, press Enter, forget it" },
            { "row 2", "Save AND pick custom fields (any of them, or all)" },
            { "⇪⇧N", "History — search text, title, date or status" },
            { "⇪⇧P", "Floating panel — stays up until Esc  ·  1-9 opens in Asana" },
            { "⇪⇧G", "Send everything waiting now, without waiting for 4 PM" },
            { "auto 4:00 PM", "The day's notes become tasks on your personal project" },
            { "title", "Starts with a verb = used as-is, else \"Task from notes:\"" },
            { "file", "Logs/quick_notes-<mac>.csv — searchable, one row per note" },
        }},
        { title = "❓ HELP", entries = {
            { "⇪/", "Toggle this cheat sheet" },
            { "type here", "Filter by key, description or group — all words must match" },
            { "shift / cmd / hyper", "Spelled-out modifier names find the glyph rows too" },
            { "Enter", "Copy the highlighted key combo" },
            { "⇪=", "Add your own entry to this sheet" },
            { "⇪E", "Edit a custom entry (picker)" },
            { "⇪-", "Remove a custom entry (picker)" },
            { "Esc / click away", "Also closes this sheet" },
        }},
        { title = "🔒 APP LOCK (privacy screen, NOT security)", entries = {
            { "⇪⇧H", "Manage — Enter locks or unlocks the selected app" },
            { "PIN prompt", "Opens on your ACTIVE screen, already focused" },
            { "locking an app", "Hides it immediately, even if already open" },
            { "un-protect", "⚙️ row at the bottom — asks for your PIN" },
            { "after a prompt", "2s cooldown — stops ⌘-Tab strobing" },
            { "🔁 row in ⇪⇧H", "Re-lock when you switch away (off by default)" },
            { "unlock lasts", "Until YOU re-lock it — no timer" },
            { "restart", "Hammerspoon restart re-locks everything" },
            { "⚠️ limit", "Quitting Hammerspoon removes all locks" },
            { "forgot PIN?", "Delete ~/.hammerspoon/applock.json" },
            { "⌘⇧⌃⌥K / ⇪K", "Panic key — clears a stuck lock cover" },
        }},
        { title = "⌨️ COMMAND HISTORY", entries = {
            { "⇪H", "Search your shell history — Enter copies the command" },
            { "type: anything", "Matches anywhere in the command" },
            { "note", "Read from command_history.log, written by your shell" },
        }},
        { title = "⌨️ ⇪ = CAPS LOCK (hold it, tap a key)", entries = {
            { "⇪ + key", "Every shortcut on this sheet — hold Caps Lock" },
            { "⇪⇧ + key", "The few second-level ones (edit/delete, nudging)" },
            { "unassigned key", "Sends ⌘⇧⌃⌥+that key to the front app" },
            { "so: Raycast etc.", "Bind them to ⌘⇧⌃⌥ and ⇪ drives them too" },
            { "Caps Lock alone", "No longer toggles capitals (§3.12 reverts)" },
            { "F1–F12", "Not forwarded — macOS reserves some (see 6.18.1)" },
        }},
        { title = "☁️ BACKUP (automatic)", entries = {
            { "daily 5:00 PM", "~/.hammerspoon → OneDrive/Backups (token excluded)" },
        }},
    }

    -- Append user-added entries, grouped by their group name (default
    -- CUSTOM), in the order groups were first used.
    local order, byGroup = {}, {}
    for _, c in ipairs(_G.customShortcuts) do
        local g = (type(c.group) == "string" and c.group ~= "" and c.group or "CUSTOM"):upper()
        if not byGroup[g] then byGroup[g] = {}; table.insert(order, g) end
        table.insert(byGroup[g], { tostring(c.keys or "?"), tostring(c.desc or "") })
    end
    for _, g in ipairs(order) do
        table.insert(groups, { title = "⭐ " .. g, entries = byGroup[g] })
    end

    return groups
end

-- ⚠️ EVERYTHING NEW BELOW LIVES IN _G., NOT IN A LOCAL. The main chunk is
--    at Lua's hard ceiling of 200 locals (see §0.4's hyperBindStub note)
--    and there is exactly zero headroom left — adding a single `local`
--    here fails the whole file with "too many local variables (limit is
--    200)". Verified, not assumed.

-- The sheet, flattened once per open: group titles become non-selectable
-- header rows, entries become selectable ones that carry their group.
_G.cheatSheetRows = {}

-- This sheet is written in glyphs — ⇪ ⇧ ⌘ ⌥ ⌃ ← ↑ → ↓ — and none of them
-- are on the keyboard you would search with. Typing "shift" and getting
-- nothing back makes the search box look broken when it is only being
-- literal, so every glyph a row contains also contributes the words
-- people actually type for it.
_G.cheatSheetAliases = {
    ["⇪"] = " hyper caps capslock ",
    ["⇧"] = " shift ",
    ["⌘"] = " cmd command ",
    ["⌥"] = " alt option ",
    ["⌃"] = " ctrl control ",
    ["←"] = " left arrow ",
    ["→"] = " right arrow ",
    ["↑"] = " up arrow ",
    ["↓"] = " down arrow ",
    ["⏎"] = " enter return ",
}

-- Built once per open rather than per keystroke: you type into this box
-- and it re-renders on every character.
_G.cheatSheetHaystack = function(keys, desc, group)
    local hay = (keys .. " " .. desc .. " " .. group):lower()
    for glyph, words in pairs(_G.cheatSheetAliases) do
        if keys:find(glyph, 1, true) then hay = hay .. words end
    end
    return hay
end

_G.cheatSheetBuildRows = function()
    local rows = {}
    for _, g in ipairs(cheatSheetGroups()) do
        table.insert(rows, { header = true, keys = "", desc = "", group = g.title, hay = "" })
        for _, e in ipairs(g.entries) do
            local keys, desc = tostring(e[1] or ""), tostring(e[2] or "")
            table.insert(rows, {
                header = false,
                keys   = keys,
                desc   = desc,
                group  = g.title,
                hay    = _G.cheatSheetHaystack(keys, desc, g.title),
            })
        end
    end
    _G.cheatSheetRows = rows
    return rows
end

-- Every term has to appear somewhere in the row, in any order, so
-- "asana task" and "task asana" both find the task creator. Plain
-- substring matching (find with plain=true): a cheat sheet full of
-- ⇪[ and ⇪\ and ⇪- would otherwise hand Lua's pattern engine a live
-- grenade the moment you typed one of them into the search box.
_G.cheatSheetMatches = function(row, terms)
    local hay = row.hay or _G.cheatSheetHaystack(row.keys or "", row.desc or "", row.group or "")
    for _, t in ipairs(terms) do
        if not hay:find(t, 1, true) then return false end
    end
    return true
end

_G.cheatSheetRender = function(query)
    local terms = {}
    for t in tostring(query or ""):lower():gmatch("%S+") do table.insert(terms, t) end

    local choices, shown = {}, 0

    if #terms == 0 then
        -- Nothing typed: the whole sheet in source order, headers and all.
        for _, row in ipairs(_G.cheatSheetRows) do
            if row.header then
                table.insert(choices, { text = row.group, subText = "", cheatHeader = true })
            else
                table.insert(choices, {
                    text = row.keys .. "  —  " .. row.desc,
                    subText = row.group,
                    cheatKeys = row.keys,
                })
                shown = shown + 1
            end
        end
    else
        -- Searching: matching entries only. The headers are dropped —
        -- a header with everything under it filtered away is just noise —
        -- and each row shows its group in the subtitle instead, so a
        -- filtered list still says where every shortcut lives.
        for _, row in ipairs(_G.cheatSheetRows) do
            if not row.header and _G.cheatSheetMatches(row, terms) then
                table.insert(choices, {
                    text = row.keys .. "  —  " .. row.desc,
                    subText = row.group,
                    cheatKeys = row.keys,
                })
                shown = shown + 1
            end
        end
        table.insert(choices, 1, {
            text = "🔎 " .. shown .. " shortcut" .. ((shown == 1) and "" or "s")
                   .. " match \"" .. tostring(query) .. "\"",
            subText = (shown > 0) and "Enter copies the highlighted key"
                      or "Try part of a key (n, shift) or a word from the description",
            cheatHeader = true,
        })
    end

    _G.choosers.cheatSheet:choices(choices)
    return choices
end

_G.choosers.cheatSheet = hs.chooser.new(function(c)
    -- Header rows and a dismissal both land here with nothing to copy.
    if not (c and c.cheatKeys and c.cheatKeys ~= "") then return end
    hs.pasteboard.setContents(c.cheatKeys)
    hs.alert.show("📋 Copied " .. c.cheatKeys)
end)
_G.choosers.cheatSheet:placeholderText("Search shortcuts — key, description or group  ·  Esc closes")
-- Wider than the 40% default because the descriptions are full sentences,
-- and a FIXED row count so the list scrolls instead of growing. This is
-- the whole point of the 6.31.1 change: more entries now cost scrolling,
-- not screen.
pcall(function() _G.choosers.cheatSheet:width(60) end)
pcall(function() _G.choosers.cheatSheet:rows(14) end)
pcall(function() _G.choosers.cheatSheet:bgDark(true) end)
-- Armored like every other render callback in this file: an error inside
-- queryChangedCallback otherwise produces a silently blank window.
_G.choosers.cheatSheet:queryChangedCallback(function(query)
    local ok, err = pcall(_G.cheatSheetRender, query)
    if not ok then
        print("🚨 Cheat sheet render error: " .. tostring(err))
        _G.choosers.cheatSheet:choices({
            { text = "⚠️ Display error — see Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

-- Re-render in place if the sheet happens to be open when an entry is
-- added, edited or deleted. Rows are rebuilt on every open anyway, so
-- this only matters while it is actually on screen.
_G.cheatSheetRefreshIfOpen = function()
    local visible = false
    pcall(function() visible = _G.choosers.cheatSheet:isVisible() end)
    if not visible then return end
    _G.cheatSheetBuildRows()
    local q = ""
    pcall(function() q = _G.choosers.cheatSheet:query() or "" end)
    pcall(_G.cheatSheetRender, q)
end

local function cheatSheetHide()
    pcall(function() _G.choosers.cheatSheet:hide() end)
end

-- Always opens on a cleared search box showing the full sheet: a picker
-- that reopens still filtered by whatever you typed last time looks empty
-- and broken.
local function cheatSheetShow()
    _G.cheatSheetBuildRows()
    _G.cheatSheetRender("")
    pcall(function() _G.choosers.cheatSheet:query("") end)
    showPopup(_G.choosers.cheatSheet)
end

local function toggleCheatSheet()
    local visible = false
    pcall(function() visible = _G.choosers.cheatSheet:isVisible() end)
    if visible then cheatSheetHide() else cheatSheetShow() end
end

hs.hotkey.bind(popupScreenKeys.mods, cheatSheetKey, toggleCheatSheet)

-- ⌃⌥⌘= — add a custom entry to the sheet, persisted across reloads.
-- Same pipe format as the task creator: Keys | Description | Group
-- (group optional, defaults to CUSTOM). Example:
--   ⌘⇧5 | Screenshot & recording menu | MACOS
hs.hotkey.bind(popupScreenKeys.mods, addShortcutKey, function()
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
    saveCustomShortcuts(_G.customShortcuts)
    hs.alert.show("⭐ Added to cheat sheet")

    -- If the sheet is open right now, redraw it with the new entry
    _G.cheatSheetRefreshIfOpen()
end)

-- ⌃⌥⌘- — remove a custom entry: opens a picker of everything you've
-- added; selecting one deletes it from custom_shortcuts.json. Built-in
-- entries never appear here — they can't be deleted this way.
local removeShortcutKey = "-"

_G.choosers.removeShortcut = hs.chooser.new(function(choice)
    if not (choice and choice.idx) then return end
    local removed = table.remove(_G.customShortcuts, choice.idx)
    saveCustomShortcuts(_G.customShortcuts)
    hs.alert.show("🗑 Removed: " .. (removed and removed.keys or "entry"))
    _G.cheatSheetRefreshIfOpen()
end)
_G.choosers.removeShortcut:placeholderText("Select a custom entry to DELETE — Esc cancels")

hs.hotkey.bind(popupScreenKeys.mods, removeShortcutKey, function()
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
local editShortcutKey = "E"

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
    saveCustomShortcuts(_G.customShortcuts)
    hs.alert.show("✏️ Updated: " .. keys)
    _G.cheatSheetRefreshIfOpen()
end)
_G.choosers.editShortcut:placeholderText("Select a custom entry to EDIT — Esc cancels")

hs.hotkey.bind(popupScreenKeys.mods, editShortcutKey, function()
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
-- 1.7 DAILY BACKUP — ~/.hammerspoon → OneDrive (secret.lua excluded)
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
local backupTime = "17:00"  -- 5:00 PM daily, 24h format

if backupDir then
    local function runHammerspoonBackup()
        local src = hs.configdir
        -- applock.json holds the App Lock PIN hash and is deliberately
        -- excluded for the same reason secret.lua is: per-machine only,
        -- never synced to the cloud, never in a backup.
        local cmd = "mkdir -p '" .. backupDir .. "' && /usr/bin/rsync -a "
            .. "--exclude 'secret.lua' --exclude 'applock.json' '"
            .. src .. "/' '" .. backupDir .. "/'"
        hs.task.new("/bin/zsh", function(exitCode, stdOut, stdErr)
            if exitCode == 0 then
                print("☁️ Hammerspoon backup completed → " .. backupDir .. " (secret.lua + applock.json excluded)")
            else
                hs.alert.show("⚠️ Hammerspoon backup FAILED — is OneDrive available?", 5)
                print("🚨 Backup error: " .. tostring(stdErr))
            end
        end, { "-c", cmd }):start()
    end

    _G.backupTimer = hs.timer.doAt(backupTime, "1d", runHammerspoonBackup)
else
    print("ℹ️ No OneDrive on this Mac — daily backup disabled; data stays in " .. hs.configdir .. " and " .. logsDir)
end

-- =====================================================================
-- 1.8 APP PEEK — ⌃⌥⌘P hides the frontmost app / brings it back
-- =====================================================================
-- The closest macOS allows to "make an app translucent so you can see
-- behind it": true window opacity of OTHER apps isn't exposed by the
-- Accessibility API (position/size/hide yes, alpha no), so instead one
-- press HIDES the frontmost app entirely — revealing everything behind
-- it — and the same press brings it back and refocuses it. 0%/100%
-- rather than 50%/100%, but the same toggle rhythm.
-- Notes:
--   • Only one app is "peeked" at a time; pressing on a different app
--     while one is hidden restores the first one instead.
--   • If you manually unhide the app (click its Dock icon), the next
--     press just resets cleanly — nothing gets stuck.
local peekKey = "P"
_G.peekedApp = nil

hs.hotkey.bind(popupScreenKeys.mods, peekKey, function()
    if _G.peekedApp then
        local app = _G.peekedApp
        _G.peekedApp = nil
        local name = "app"
        pcall(function() name = app:name() or name end)
        pcall(function()
            app:unhide()
            app:activate()
        end)
        hs.alert.show("👀 Restored " .. name)
        return
    end

    local ok, app = pcall(hs.application.frontmostApplication)
    if not ok or not app then return end
    local name = "app"
    pcall(function() name = app:name() or name end)
    if name == "Hammerspoon" then
        hs.alert.show("👀 Won't peek Hammerspoon itself")
        return
    end

    _G.peekedApp = app
    pcall(function() app:hide() end)
    hs.alert.show("👀 Peeking behind " .. name .. " — ⌃⌥⌘P brings it back")
end)

-- =====================================================================
-- 1.9 WINDOW ARRANGER — halves, fill, split, monitor jumps, app summon
-- =====================================================================
-- ✏️ EDIT YOUR KEYS HERE — every binding below reads from this table.
-- Note the spec assigned ⌃⌥F to BOTH "50% halves" and "fill screen";
-- resolved as F = fill, arrow keys = halves. Swap any of these freely.
local windowKeys = {
    halfMods     = {"ctrl", "alt"},        -- modifiers for the five keys below
    halfLeft     = "Left",                 -- ⌃⌥←  left half of screen
    halfRight    = "Right",                -- ⌃⌥→  right half of screen
    maximize     = "F",                    -- ⌃⌥F  fill screen (NOT native full screen)
    split        = "V",                    -- ⌃⌥V  two most recent windows side-by-side
    appJump      = "W",                    -- ⌃⌥W  summon-an-app picker
    restore      = "M",                    -- ⌃⌥M  return window to prior position/monitor (toggles)
    monitorMods  = {"ctrl", "alt", "cmd"}, -- modifiers for the two keys below
    monitorLeft  = "[",                    -- ⌃⌥⌘[  move window one monitor LEFT (wraps) — [ sits left of ] on the keyboard
    monitorRight = "]",                    -- ⌃⌥⌘]  move window one monitor RIGHT (wraps)
}

hs.window.animationDuration = 0  -- window moves snap instantly, no slide

local function focusedStandardWindow()
    local ok, win = pcall(hs.window.focusedWindow)
    if not ok or not win then return nil end
    return win
end

-- Native macOS full-screen windows live on their own Space and can't
-- be resized/moved by frame-setting — every action below guards for
-- that and tells you instead of silently doing nothing.
local function guardNotFullScreen(win)
    local fs = false
    pcall(function() fs = win:isFullScreen() end)
    if fs then
        hs.alert.show("🪟 Exit full screen first (green button / ⌃⌘F)")
        return false
    end
    return true
end

-- PRIOR-POSITION MEMORY: every arrangement action below saves the
-- window's frame (position + size + monitor, since frames are absolute
-- screen coordinates) BEFORE moving it. ⌃⌥M restores it — and saves
-- where the window is now, so pressing ⌃⌥M again toggles back. One
-- memory slot per window, in-memory only (cleared on config reload).
_G.windowPriorFrames = {}

local function rememberFrame(win)
    local id, f = nil, nil
    pcall(function() id = win:id() end)
    pcall(function() f = win:frame() end)
    if id and f then _G.windowPriorFrames[id] = f end
end

-- ⌃⌥M — return the focused window to its remembered prior position
local function restorePriorFrame()
    local win = focusedStandardWindow()
    if not win then hs.alert.show("🪟 No window in focus") return end
    if not guardNotFullScreen(win) then return end

    local id = nil
    pcall(function() id = win:id() end)
    local prior = id and _G.windowPriorFrames[id]
    if not prior then
        hs.alert.show("🪟 No prior position remembered for this window")
        return
    end

    -- If the prior position was on a monitor that's since been
    -- unplugged, restoring would strand the window off-screen — check
    -- the frame still overlaps some connected screen first.
    local visible = false
    for _, s in ipairs(hs.screen.allScreens()) do
        local ok, inter = pcall(function() return prior:intersect(s:frame()) end)
        if ok and inter and inter.w > 0 and inter.h > 0 then
            visible = true
            break
        end
    end
    if not visible then
        hs.alert.show("🪟 Prior position was on a monitor that's no longer connected")
        return
    end

    -- Swap: remember where it is NOW, so ⌃⌥M toggles back and forth
    local current = nil
    pcall(function() current = win:frame() end)
    win:setFrame(prior)
    if current then _G.windowPriorFrames[id] = current end
    win:focus()
    hs.alert.show("🪟 Returned to prior position — ⌃⌥M again toggles back")
end

-- ⌃⌥← / ⌃⌥→ — snap the focused window to the left/right half
local function setHalf(side)
    local win = focusedStandardWindow()
    if not win then hs.alert.show("🪟 No window in focus") return end
    if not guardNotFullScreen(win) then return end
    rememberFrame(win)
    local f = win:screen():frame()
    if side == "left" then
        win:setFrame({ x = f.x, y = f.y, w = f.w / 2, h = f.h })
    else
        win:setFrame({ x = f.x + f.w / 2, y = f.y, w = f.w / 2, h = f.h })
    end
end

-- ⌃⌥F — fill the screen's usable area (menu bar & Dock stay visible;
-- this is NOT the green-button full-screen mode)
local function maximizeFocused()
    local win = focusedStandardWindow()
    if not win then hs.alert.show("🪟 No window in focus") return end
    if not guardNotFullScreen(win) then return end
    rememberFrame(win)
    win:maximize()
end

-- ⌃⌥V — split the two most recently used windows side-by-side on the
-- focused window's screen: current window LEFT half, previous RIGHT.
local function splitTopTwo()
    local wins = {}
    for _, w in ipairs(hs.window.orderedWindows()) do
        local ok, std = pcall(function() return w:isStandard() end)
        if ok and std then table.insert(wins, w) end
        if #wins == 2 then break end
    end
    if #wins < 2 then
        hs.alert.show("🪟 Need two visible windows to split")
        return
    end
    if not guardNotFullScreen(wins[1]) or not guardNotFullScreen(wins[2]) then return end
    rememberFrame(wins[1])
    rememberFrame(wins[2])

    local scr = wins[1]:screen()
    local f = scr:frame()
    if wins[2]:screen() ~= scr then
        pcall(function() wins[2]:moveToScreen(scr, false, true) end)
    end
    wins[1]:setFrame({ x = f.x,           y = f.y, w = f.w / 2, h = f.h })
    wins[2]:setFrame({ x = f.x + f.w / 2, y = f.y, w = f.w / 2, h = f.h })
    wins[1]:focus()

    local n1, n2 = "window", "window"
    pcall(function() n1 = wins[1]:application():name() or n1 end)
    pcall(function() n2 = wins[2]:application():name() or n2 end)
    hs.alert.show("🪟 " .. n1 .. "  ⇤⇥  " .. n2)
end

-- ⌃⌥⌘[ / ⌃⌥⌘] — throw the focused window to the next monitor right/
-- left. Wraps around: past the rightmost monitor lands on the leftmost,
-- and vice versa, so it cycles among ALL monitors.
local function moveFocusedToMonitor(direction)
    local win = focusedStandardWindow()
    if not win then hs.alert.show("🪟 No window in focus") return end
    if #hs.screen.allScreens() < 2 then
        hs.alert.show("🪟 Only one monitor connected")
        return
    end
    if not guardNotFullScreen(win) then return end
    rememberFrame(win)

    local scr = win:screen()
    local target = (direction == "east") and scr:toEast() or scr:toWest()
    if not target then
        -- wrap around the edge
        local screens = hs.screen.allScreens()
        table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
        target = (direction == "east") and screens[1] or screens[#screens]
    end
    if target == scr then return end

    pcall(function() win:moveToScreen(target, false, true) end)
    win:focus()
    local name = "monitor"
    pcall(function() name = target:name() or name end)
    hs.alert.show("🪟 → " .. name, target)
end

-- ⌃⌥W — summon picker: type an app's name, select it, and its window
-- jumps to the ACTIVE monitor (captured at the moment you press the
-- hotkey) in front of other apps. If the app is in native full screen
-- it can't be moved across monitors, so it's focused where it lives.
_G.appJumpTargetScreen = nil

_G.choosers.appJump = hs.chooser.new(function(choice)
    if not (choice and choice.pid) then return end
    local app = hs.application.applicationForPID(choice.pid)
    if not app then
        hs.alert.show("❌ " .. (choice.text or "App") .. " is no longer running")
        return
    end

    local target = _G.appJumpTargetScreen or resolveBaseScreen()
    local win = nil
    pcall(function() win = app:mainWindow() or app:focusedWindow() end)

    if win then
        local fs = false
        pcall(function() fs = win:isFullScreen() end)
        if fs then
            app:activate(true)
            hs.alert.show("🪟 " .. choice.text .. " is full screen — switched to it")
            return
        end
        pcall(function()
            rememberFrame(win)
            win:moveToScreen(target, false, true)
            win:raise()
        end)
    end
    app:activate(true)
    hs.alert.show("🪟 Summoned " .. choice.text)
end)
_G.choosers.appJump:placeholderText("Summon an app to this monitor…")

hs.hotkey.bind(windowKeys.halfMods, windowKeys.appJump, function()
    -- Capture the target BEFORE the picker opens, so "active monitor"
    -- means the one you were working on, not wherever the picker lands
    _G.appJumpTargetScreen = resolveBaseScreen()

    local choices = {}
    for _, app in ipairs(hs.application.runningApplications()) do
        local okK, kind = pcall(function() return app:kind() end)
        if okK and kind == 1 then  -- regular Dock apps only
            local okN, name = pcall(function() return app:name() end)
            if okN and name and name ~= "" and name ~= "Hammerspoon" then
                table.insert(choices, {
                    text    = name,
                    subText = "Jump to this monitor, in front of other apps",
                    pid     = app:pid(),
                })
            end
        end
    end
    table.sort(choices, function(a, b) return a.text:lower() < b.text:lower() end)
    _G.choosers.appJump:choices(choices)
    showPopup(_G.choosers.appJump)
end)

hs.hotkey.bind(windowKeys.halfMods, windowKeys.halfLeft,  function() setHalf("left")  end)
hs.hotkey.bind(windowKeys.halfMods, windowKeys.halfRight, function() setHalf("right") end)
hs.hotkey.bind(windowKeys.halfMods, windowKeys.maximize,  maximizeFocused)
hs.hotkey.bind(windowKeys.halfMods, windowKeys.split,     splitTopTwo)
hs.hotkey.bind(windowKeys.halfMods, windowKeys.restore,   restorePriorFrame)
hs.hotkey.bind(windowKeys.monitorMods, windowKeys.monitorRight, function() moveFocusedToMonitor("east") end)
hs.hotkey.bind(windowKeys.monitorMods, windowKeys.monitorLeft,  function() moveFocusedToMonitor("west") end)

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
            local nameF = p:match("[^/]+$") or p
            -- 6.31.3 — FAILURES USED TO BE SILENT.
            -- Every branch below used to be a bare `return`, so an image
            -- that failed to OCR looked identical to one that was never
            -- an image: nothing on screen either way. A file that isn't
            -- an image is still silent (it never reaches here — see the
            -- console-only line in the detection pass), but an image we
            -- TRIED and failed on now says so, because that is the case
            -- where you would otherwise sit waiting for a tag that is
            -- never coming.
            if exitCode ~= 0 then
                print("⚠️ OCR failed for " .. nameF .. " — shortcuts exit "
                    .. tostring(exitCode) .. " " .. tostring(stdErr or ""))
                hs.alert.show("⚠️ Not OCR'd: " .. nameF .. " (OCR shortcut failed)")
                return
            end
            local textOut = stdOut
            if not textOut or #textOut == 0 then
                print("⚠️ OCR returned nothing for " .. nameF)
                hs.alert.show("⚠️ Not OCR'd: " .. nameF .. " (no text found)")
                return
            end
            textOut = stripToQwerty(textOut:gsub("%z", ""):gsub("\x1A", ""))
            if #textOut == 0 then
                print("⚠️ OCR text was all non-typeable for " .. nameF)
                hs.alert.show("⚠️ Not OCR'd: " .. nameF .. " (no readable text)")
                return
            end

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
-- 3.5 ASANA COMMENTS ENGINE
-- =====================================================================
-- Posts a comment on any task via the Asana "stories" endpoint —
-- identical to typing in the "Add a comment" box in the Asana UI.
local function addCommentToTask(taskGid, commentText, onDone)
    if not asanaEnabled then
        if onDone then onDone(false) end
        return
    end
    if not taskGid or not commentText or #commentText == 0 then
        if onDone then onDone(false) end
        return
    end

    local body = hs.json.encode({ data = { text = commentText } })

    hs.http.asyncPost("https://app.asana.com/api/1.0/tasks/" .. taskGid .. "/stories", body, {
        ["Authorization"] = "Bearer " .. asanaToken,
        ["Content-Type"]  = "application/json"
    }, function(status, responseBody)
        if status == 200 or status == 201 then
            hs.alert.show("💬 Comment added")
            if onDone then onDone(true) end
        else
            hs.alert.show("❌ Comment failed (HTTP " .. tostring(status) .. ")")
            print("Asana comment error: ", responseBody)
            if onDone then onDone(false) end
        end
    end)
end

-- TEAM MEMBERS — Asana's API rejects a display name outright ("Not a
-- valid actor ID: Lee"); assignee must be "me", a numeric GID, or an
-- email. This caches {gid=, name=, email=} so a typed name can be
-- resolved to a real GID before it ever reaches the API (see the Task
-- Creator's resolveAssignee below).
-- _G. instead of local: called from two separate top-level closures
-- (boot, and the ⌃⌥⌘B picker) without spending another slot on this
-- already-near-the-200-local-ceiling file.
-- 6.15.1 FIX: /projects/{gid}/users is not a real Asana endpoint (the
-- 404 was that, not a private-project permission issue — a real
-- permission problem would be a 403, and this token already reads/
-- writes this exact project fine elsewhere).
-- 6.16.9: whole-WORKSPACE listing (the 6.15.1 fix above) turned out to
-- mean "everyone in the entire organization" on a big org (a college —
-- thousands of student accounts), making the picker useless. ✏️ EDIT
-- THESE — the exact team names as they appear in Asana; resolved to
-- their real GIDs once at boot (GET /workspaces/{gid}/teams, a real,
-- documented endpoint) and cached, then each team's own roster is
-- fetched via GET /teams/{gid}/users and merged, deduped by gid. Leave
-- the list empty ({}) to fall back to the old whole-workspace roster.
-- (wrapped in do...end — these names never need to be seen outside this
-- block — so they don't spend more of this file's already-tight 200
-- main-chunk local-variable budget than the single _G.fetchAsanaTeamMembers
-- entry point actually requires)
do
local asanaTeamNames = {
    "| 1. SAC Library Core Projects |",
    "| 2. SAC Library Team Member Projects & Tasks |",
}

_G.asanaTeamMembers = {}
local asanaTeamGidsResolved = false
local asanaTeamGids = {}
local asanaTeamGidNames = {}   -- gid -> clean display name (strips "| N. ... |")

-- Team names in this org are literally formatted "| N. Name |" — strip
-- that decoration for display (subText/search), not just the raw match.
local function asanaCleanTeamName(name)
    return name:match("^|%s*%d+%.%s*(.-)%s*|$") or name
end

local function resolveAsanaTeamGids(onDone)
    if asanaTeamGidsResolved or #asanaTeamNames == 0 then onDone() return end
    hs.http.asyncGet(
        "https://app.asana.com/api/1.0/workspaces/" .. asanaWorkspaceId .. "/teams?opt_fields=name",
        { ["Authorization"] = "Bearer " .. asanaToken },
        function(status, body)
            if status == 200 then
                local data = hs.json.decode(body)
                if data and data.data then
                    for _, wantName in ipairs(asanaTeamNames) do
                        local wantLower = wantName:lower():match("^%s*(.-)%s*$")
                        local found = false
                        for _, t in ipairs(data.data) do
                            if t.name and t.name:lower():match("^%s*(.-)%s*$") == wantLower then
                                table.insert(asanaTeamGids, t.gid)
                                asanaTeamGidNames[t.gid] = asanaCleanTeamName(t.name)
                                found = true
                                break
                            end
                        end
                        if not found then
                            print("⚠️ Asana team not found by name: \"" .. wantName .. "\" — check spelling/spacing against Asana")
                        end
                    end
                end
            else
                print("⚠️ Asana team list fetch failed (HTTP " .. tostring(status) .. ")")
            end
            asanaTeamGidsResolved = true
            onDone()
        end)
end

_G.fetchAsanaTeamMembers = function(onDone)
    if not asanaEnabled then if onDone then onDone() end return end

    local function fetchByGids()
        if #asanaTeamGids == 0 then
            -- fallback: whole workspace (no team names configured, or
            -- none of them matched a real team)
            hs.http.asyncGet(
                "https://app.asana.com/api/1.0/workspaces/" .. asanaWorkspaceId .. "/users?opt_fields=name,email",
                { ["Authorization"] = "Bearer " .. asanaToken },
                function(status, body)
                    local members = {}
                    if status == 200 then
                        local data = hs.json.decode(body)
                        if data and data.data then
                            for _, u in ipairs(data.data) do
                                table.insert(members, { gid = u.gid, name = u.name or "?", email = u.email })
                            end
                        end
                    else
                        print("⚠️ Asana team member fetch failed (HTTP " .. tostring(status) .. ")")
                    end
                    _G.asanaTeamMembers = members
                    if onDone then onDone() end
                end)
            return
        end

        local allMembers, remaining, seen = {}, #asanaTeamGids, {}
        for _, teamGid in ipairs(asanaTeamGids) do
            local teamName = asanaTeamGidNames[teamGid] or "Team"
            hs.http.asyncGet(
                "https://app.asana.com/api/1.0/teams/" .. teamGid .. "/users?opt_fields=name,email",
                { ["Authorization"] = "Bearer " .. asanaToken },
                function(status, body)
                    if status == 200 then
                        local data = hs.json.decode(body)
                        if data and data.data then
                            for _, u in ipairs(data.data) do
                                if seen[u.gid] then
                                    -- on both teams — show both, don't duplicate the row
                                    table.insert(seen[u.gid].teams, teamName)
                                else
                                    local m = { gid = u.gid, name = u.name or "?", email = u.email, teams = { teamName } }
                                    seen[u.gid] = m
                                    table.insert(allMembers, m)
                                end
                            end
                        end
                    else
                        print("⚠️ Asana team member fetch failed for team " .. teamGid .. " (HTTP " .. tostring(status) .. ")")
                    end
                    remaining = remaining - 1
                    if remaining <= 0 then
                        _G.asanaTeamMembers = allMembers
                        if onDone then onDone() end
                    end
                end)
        end
    end

    resolveAsanaTeamGids(fetchByGids)
end
if asanaEnabled then _G.fetchAsanaTeamMembers() end   -- warm the cache at boot

end -- do...end (§0.2 Asana team-scoping locals)

-- =====================================================================
-- 3.6 ACTIVITY TRACKER — persistent, searchable, day/week/month views
-- =====================================================================
-- Tracks time per app AND per document/window (approximated by window
-- title, since macOS has no universal "which file is open" API that
-- works the same across every app — window title is the closest thing
-- that generalizes: a browser tab's title, a text editor's filename, a
-- PDF viewer's document name, etc). This also means switching tabs or
-- documents WITHIN the same still-frontmost app gets tracked, not just
-- switches between different apps, which the old version couldn't do.
--
-- Persists to disk as CSV in your OneDrive Logs folder so it survives
-- Hammerspoon restarts/reloads AND syncs to OneDrive — the original
-- version was purely in-memory and reset every reload. CSV also means
-- you can open it directly in Numbers/Excel.
-- ⚠️ CloudStorage paths depend on OneDrive running; if OneDrive is
-- quit or the Logs folder is set to online-only, writes can fail.
-- Keep that folder "Always keep on this device" — since 6.10.0 a
-- failed write warns on screen instead of losing data silently.
--
-- ⌘⌥⇧0 opens it:
--   • empty box     → today's per-app totals
--   • type "week"   → this calendar week's per-app totals
--   • type "month"  → this month's top apps AND top documents/windows
--   • type anything else → searches app names & window titles across
--     ALL saved history (not just today)
--   • selecting any row copies its name + time to the clipboard
--
-- AUTOMATIC REPORTS (times/day editable below):
--   • Daily at 4:00 PM — today's apps ranked most→least, in minutes
--   • Monday at 7:30 AM — recap of the last 7 days, same ranking
--
-- Sessions are detected by POLLING every activityPollInterval seconds,
-- so a switch can take up to that long to be noticed, and only
-- recorded if they last at least activityMinSessionSeconds (filters
-- out quick accidental switches — same idea as the old 10s threshold).
local activityHistoryFile      = logsDir .. "/activity_history-" .. hostTag .. ".csv"
adoptLegacyFile(activityHistoryFile, logsDir .. "/activity_history.csv")
local activityOldCSVFile       = hs.configdir .. "/activity_history.csv"   -- pre-OneDrive location, migrated once below
local activityOldJSONFile      = hs.configdir .. "/activity_history.json"  -- pre-CSV format, migrated once below
local activityMinSessionSeconds = 10   -- ignore anything shorter than this
local activityPollInterval      = 5    -- seconds between checks
local activityRetentionDays     = 120  -- ~4 months of raw sessions kept on disk
local activityWeekStartsSunday  = true -- false = weeks start Monday instead
-- 6.16.5: frontmost-app time isn't ACTUAL use — leaving VLC or Sublime
-- frontmost while away from the keyboard (movie playing, stepped out)
-- kept the clock running for hours. The poller below now stops the
-- clock after 300s (5 min) of no mouse/keyboard input (hs.host.idleTime),
-- crediting time only up to when idling actually began, not up to now.
-- (Inlined, not a local, to stay under Lua's 200-local ceiling — search
-- "activityIdleThreshold" below to change the 5-min value.)
-- HONEST LIMIT: reading without touching input for this long also stops
-- the clock — raise the value if that's too aggressive for you.

-- 6.11.3: only REAL applications are tracked — currentAppAndTitle below
-- checks hs.application:kind() == 1 (the same "regular Dock app" test
-- windowKeys.appJump already uses), so background/system processes like
-- loginwindow (the lock screen) and ScreenSaverEngine are never recorded
-- as "the app you were using". This is self-updating: install a new
-- real app tomorrow and it's tracked automatically, no list to maintain.
-- ✏️ To exclude a REAL app by name anyway, add it here (exact name, as
-- it appears in this tracker's own rows):
local activityIgnoredApps = {
    -- "Hammerspoon",
}

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

local function activityFileExists()
    local f = io.open(activityHistoryFile, "r")
    if f then f:close(); return true end
    return false
end

local function loadActivityCSV(path)
    local f = io.open(path, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local log, isFirstLine = {}, true
    for line in content:gmatch("([^\r\n]+)") do
        if isFirstLine and line:match("^date,app,title,seconds") then
            -- skip header row
        else
            local fields = splitCSVLine(line)
            local seconds = tonumber(fields[4])
            if fields[1] and fields[2] and fields[3] and seconds then
                table.insert(log, { date = fields[1], app = fields[2], title = fields[3], seconds = seconds })
            end
        end
        isFirstLine = false
    end
    return log
end

-- One-time upgrade path, tried only when the OneDrive CSV doesn't
-- exist yet: first the CSV from when this lived in ~/.hammerspoon,
-- then the even older JSON format — so nothing already recorded is
-- lost, whichever version you were on.
local function migrateOldDataIfAny()
    local fromCSV = loadActivityCSV(activityOldCSVFile)
    if #fromCSV > 0 then return fromCSV end

    local f = io.open(activityOldJSONFile, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local ok, data = pcall(hs.json.decode, content)
    if ok and type(data) == "table" then return data end
    return {}
end

-- Writes the WHOLE file from scratch, including the header — used at
-- boot (after pruning) and for the one-time migration/first-run case.
-- Ongoing writes during normal use append instead (see below).
-- Returns false if the file couldn't be opened (e.g. OneDrive folder
-- unavailable) so boot can warn you instead of failing silently.
local function rewriteActivityLog(log)
    local f = io.open(activityHistoryFile, "w")
    if not f then return false end
    f:write("date,app,title,seconds\n")
    for _, e in ipairs(log) do
        f:write(e.date .. "," .. csvQuote(e.app) .. "," .. csvQuote(e.title) .. "," .. e.seconds .. "\n")
    end
    f:close()
    return true
end

-- Fast path for normal operation: append one row rather than rewriting
-- the whole growing file on every session close.
local function appendActivityRow(entry)
    local f = io.open(activityHistoryFile, "a")
    if f then
        f:write(entry.date .. "," .. csvQuote(entry.app) .. "," .. csvQuote(entry.title) .. "," .. entry.seconds .. "\n")
        f:close()
    else
        warnWriteFailed("activity history")
    end
end

-- 6.31.4 — HARD ROW CAP FOR BOTH TRACKER CSVs.
-- The day-based cutoffs alone let file_changes reach ~400,000 rows,
-- which took 13 seconds to parse at boot and beachballed the machine.
-- Chunked loading stopped that from BLOCKING, but nothing stopped the
-- file growing. This is the part that was missing.
-- In _G. rather than a local: the main chunk is at Lua's 200 ceiling.
_G.trackerMaxRows = 50000

-- Keeps the NEWEST rows. Every write appends, so newest are at the end.
_G.trackerCapRows = function(rows, label)
    if #rows <= _G.trackerMaxRows then return rows end
    local trimmed = {}
    for i = #rows - _G.trackerMaxRows + 1, #rows do
        trimmed[#trimmed + 1] = rows[i]
    end
    print(string.format("%s: capped %d rows to %d (newest kept)",
        label, #rows, #trimmed))
    return trimmed
end

local function pruneActivityLog(log)
    local cutoff = os.date("%Y-%m-%d", os.time() - (activityRetentionDays * 86400))
    local pruned = {}
    for _, entry in ipairs(log) do
        if type(entry.date) == "string" and entry.date >= cutoff then
            table.insert(pruned, entry)
        end
    end
    return _G.trackerCapRows(pruned, "📊 Activity tracker")
end

-- 6.11.3: one-time cleanup for rows recorded BEFORE kind-1 filtering
-- existed — loginwindow (the lock screen process) and ScreenSaverEngine
-- aren't real apps and never should have been logged. Runs once at
-- boot, alongside the retention prune below; harmless (a no-op) once
-- your CSV is already clean.
local activityJunkApps = { loginwindow = true, ScreenSaverEngine = true }
local function purgeJunkApps(log)
    local kept = {}
    for _, entry in ipairs(log) do
        if not activityJunkApps[entry.app] then
            table.insert(kept, entry)
        end
    end
    return kept
end

-- Boot: load existing OneDrive CSV data (or migrate from the old
-- ~/.hammerspoon files if this is the first run since upgrading),
-- purge known junk rows and prune anything past the retention window,
-- and rewrite the file (with header) if it's brand new or cleanup
-- removed something.
local _existedBefore = activityFileExists()
local _loaded = _existedBefore and loadActivityCSV(activityHistoryFile) or migrateOldDataIfAny()
local _purged = purgeJunkApps(_loaded)
local _pruned = pruneActivityLog(_purged)
_G.activityLog = _pruned
if not _existedBefore or #_pruned ~= #_loaded then
    if not rewriteActivityLog(_pruned) then
        hs.alert.show("⚠️ Can't write activity_history.csv — is the OneDrive Logs folder available?", 6)
    end
end

-- The session currently being tracked (app + window title + when it
-- started). Closed out and recorded whenever the poller notices either
-- one has changed.
_G.activitySession = { app = nil, title = nil, startTime = nil }

-- Best-effort read of "what's frontmost right now, and what does its
-- focused window's title bar say". Wrapped defensively since a window
-- can vanish between calls, or an app can have no accessible window.
-- 6.11.3: only regular Dock apps (kind 1) are tracked — the frontmost
-- "app" during a locked screen is loginwindow, a background system
-- process, not something you were using; ScreenSaverEngine is the
-- same story. Filtering by kind is self-updating (a real app installed
-- tomorrow is tracked automatically) instead of a hardcoded app list.
local function currentAppAndTitle()
    local ok, app = pcall(hs.application.frontmostApplication)
    if not ok or not app then return nil, nil end

    local okK, kind = pcall(function() return app:kind() end)
    if not okK or kind ~= 1 then return nil, nil end

    local ok2, name = pcall(function() return app:name() end)
    if not ok2 or not name then return nil, nil end

    for _, ignored in ipairs(activityIgnoredApps) do
        if name == ignored then return nil, nil end
    end

    local title = nil
    local ok3, win = pcall(function() return app:focusedWindow() end)
    if ok3 and win then
        local ok4, t = pcall(function() return win:title() end)
        if ok4 and type(t) == "string" and #t > 0 then title = t end
    end

    return name, title
end

local function closeActivitySession(endTime)
    local s = _G.activitySession
    if not (s.app and s.startTime) then return end

    endTime = endTime or os.time()
    local duration = endTime - s.startTime
    if duration >= activityMinSessionSeconds then
        local entry = {
            date    = os.date("%Y-%m-%d", s.startTime),
            app     = s.app,
            title   = s.title or "",
            seconds = duration,
        }
        table.insert(_G.activityLog, entry)
        appendActivityRow(entry)
    end
end

_G.activityPoller = hs.timer.doEvery(activityPollInterval, function()
    local okIdle, idle = pcall(hs.host.idleTime)
    if okIdle and idle and idle >= 300 then   -- activityIdleThreshold: 5 min away = stop the clock
        if _G.activitySession.app then
            -- credit only up to when idling actually began, not up to now
            closeActivitySession(os.time() - idle)
            _G.activitySession = { app = nil, title = nil, startTime = nil }
        end
        return
    end

    local appName, title = currentAppAndTitle()
    if not appName then return end  -- couldn't tell, or frontmost isn't a real app; leave current session running

    local s = _G.activitySession
    if s.app ~= appName or s.title ~= title then
        closeActivitySession()
        _G.activitySession = { app = appName, title = title, startTime = os.time() }
    end
end)

-- 6.11.3: THE 30-HOUR BUG — a session left open when the Mac sleeps or
-- the screen locks keeps its original startTime; Hammerspoon's own
-- timers pause during sleep, but wall-clock time doesn't, so on wake
-- closeActivitySession() computed end-minus-start across the ENTIRE
-- locked/asleep span (lock Friday 5 PM, return Monday 8 AM → the app
-- that was frontmost at lock time "used" for ~63 hours). Fixed at the
-- source: closing the session the INSTANT the screen locks or the
-- system sleeps, so its duration stops at the real moment of lock, not
-- at the next poll after you're back. The poller opens a fresh session
-- for whatever's actually frontmost as soon as polling resumes.
local activityLockWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidLock
       or event == hs.caffeinate.watcher.systemWillSleep then
        closeActivitySession()
        _G.activitySession = { app = nil, title = nil, startTime = nil }
    end
end)
activityLockWatcher:start()

-- ---- date-range helpers ---------------------------------------------

local function todayStr()
    return os.date("%Y-%m-%d")
end

local function weekStartStr()
    local t = os.date("*t")  -- t.wday: 1=Sunday ... 7=Saturday
    local offsetDays
    if activityWeekStartsSunday then
        offsetDays = t.wday - 1
    else
        offsetDays = (t.wday == 1) and 6 or (t.wday - 2)
    end
    return os.date("%Y-%m-%d", os.time() - offsetDays * 86400)
end

local function monthStartStr()
    local t = os.date("*t")
    return string.format("%04d-%02d-01", t.year, t.month)
end

-- ---- aggregation ------------------------------------------------------

local function sortedDescending(totalsTable)
    local list = {}
    for name, seconds in pairs(totalsTable) do
        table.insert(list, { name = name, seconds = seconds })
    end
    table.sort(list, function(a, b) return a.seconds > b.seconds end)
    return list
end

-- Per-app totals for [startStr, endStr] inclusive. Date strings compare
-- correctly with plain >= / <= since they're zero-padded YYYY-MM-DD.
local function appTotalsInRange(startStr, endStr)
    local totals = {}
    for _, e in ipairs(_G.activityLog) do
        if e.date >= startStr and e.date <= endStr then
            totals[e.app] = (totals[e.app] or 0) + e.seconds
        end
    end
    return sortedDescending(totals)
end

-- Per-app AND per-(app + window title) totals for a range — the
-- "documents" view is really "distinct window titles", the closest
-- proxy for a document that generalizes across arbitrary apps.
local function appAndTitleTotalsInRange(startStr, endStr)
    local appTotals, titleTotals = {}, {}
    for _, e in ipairs(_G.activityLog) do
        if e.date >= startStr and e.date <= endStr then
            appTotals[e.app] = (appTotals[e.app] or 0) + e.seconds
            if e.title and e.title ~= "" then
                local key = e.app .. " — " .. e.title
                titleTotals[key] = (titleTotals[key] or 0) + e.seconds
            end
        end
    end
    return sortedDescending(appTotals), sortedDescending(titleTotals)
end

local function grandTotal(list)
    local total = 0
    for _, e in ipairs(list) do total = total + e.seconds end
    return total
end

-- ---- chooser ------------------------------------------------------------

-- Selecting any row copies "name — time" to the clipboard
_G.choosers.appTracker = hs.chooser.new(function(choice)
    if choice and choice.text then
        local copied = choice.text
        if choice.subText and choice.subText ~= "" then
            copied = copied .. " — " .. choice.subText
        end
        hs.pasteboard.setContents(copied)
        hs.alert.show("📋 Copied")
    end
end)
_G.choosers.appTracker:placeholderText("Today's activity — or type 'week' / 'month' / search…")

local function renderActivityChoices(query)
    local q = (query or ""):match("^%s*(.-)%s*$")
    local qLower = q:lower()
    local choices = {}

    if qLower == "week" then
        local list = appTotalsInRange(weekStartStr(), todayStr())
        table.insert(choices, {
            text    = "📆 THIS WEEK — " .. formatDuration(grandTotal(list)) .. " total",
            subText = "Clear the box for today, or type 'month' for other views",
        })
        for _, e in ipairs(list) do
            table.insert(choices, { text = e.name, subText = formatDuration(e.seconds) })
        end

    elseif qLower == "month" then
        local appList, titleList = appAndTitleTotalsInRange(monthStartStr(), todayStr())
        table.insert(choices, { text = "🗓 THIS MONTH — TOP APPS", subText = "" })
        for i = 1, math.min(8, #appList) do
            table.insert(choices, { text = appList[i].name, subText = formatDuration(appList[i].seconds) })
        end
        table.insert(choices, { text = "📄 THIS MONTH — TOP DOCUMENTS / WINDOWS", subText = "" })
        if #titleList == 0 then
            table.insert(choices, { text = "(no window titles recorded yet)", subText = "" })
        end
        for i = 1, math.min(8, #titleList) do
            table.insert(choices, { text = titleList[i].name, subText = formatDuration(titleList[i].seconds) })
        end

    elseif qLower == "" then
        local list = appTotalsInRange(todayStr(), todayStr())
        table.insert(choices, {
            text    = "📅 TODAY — " .. formatDuration(grandTotal(list)) .. " total",
            subText = "Type 'week' or 'month' for other views, or search an app/doc name",
        })
        if #list == 0 then
            table.insert(choices, { text = "No activity recorded yet today", subText = "" })
        end
        for _, e in ipairs(list) do
            table.insert(choices, { text = e.name, subText = formatDuration(e.seconds) })
        end

    else
        -- Search: app name or window title, across ALL saved history
        local matchTotals = {}
        for _, e in ipairs(_G.activityLog) do
            local haystack = (e.app .. " " .. (e.title or "")):lower()
            if haystack:find(qLower, 1, true) then
                local key = e.app .. ((e.title and e.title ~= "") and (" — " .. e.title) or "")
                matchTotals[key] = (matchTotals[key] or 0) + e.seconds
            end
        end
        local list = sortedDescending(matchTotals)
        if #list == 0 then
            table.insert(choices, { text = "No matches for \"" .. q .. "\"", subText = "Searches app names & window titles, all-time" })
        else
            table.insert(choices, { text = "🔎 Matches for \"" .. q .. "\" — all time", subText = "" })
            for _, e in ipairs(list) do
                table.insert(choices, { text = e.name, subText = formatDuration(e.seconds) })
            end
        end
    end

    _G.choosers.appTracker:choices(choices)
end

_G.choosers.appTracker:queryChangedCallback(function(query)
    local ok, err = pcall(renderActivityChoices, query)
    if not ok then
        print("🚨 Activity chooser render error: " .. tostring(err))
        _G.choosers.appTracker:choices({
            { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

-- ---- scheduled reports ------------------------------------------------
-- Daily at activityDailyReportTime: today's apps ranked most→least used,
-- shown in minutes. Weekly on activityWeeklyReportWeekday at
-- activityWeeklyReportTime: the same ranking for the LAST 7 full days
-- (i.e. the 7 days ending yesterday — so Monday's report covers Mon–Sun
-- of last week and doesn't mix in the fresh morning's activity).
-- Reports appear as a popup you can search & copy rows from, exactly
-- like the ⌘⌥⇧0 tracker. Note: like any popup here, it takes keyboard
-- focus when it appears — it will interrupt typing at report time.
local activityDailyReportTime     = "16:00"  -- 4:00 PM, 24h format
local activityWeeklyReportTime    = "07:30"  -- 7:30 AM, 24h format
local activityWeeklyReportWeekday = 1        -- 0=Sun 1=Mon 2=Tue … 6=Sat
                                              -- (also fires Fri=5, see timer below)

local function minutesLabel(seconds)
    local mins = math.floor(seconds / 60 + 0.5)
    if mins < 1 then return "under 1 min" end
    return mins .. " min"
end

-- Report chooser: registered in _G.choosers so it follows the frontmost
-- app's screen and participates in nudging; selecting a row copies it.
_G.choosers.activityReport = hs.chooser.new(function(choice)
    if choice and choice.text then
        local copied = choice.text
        if choice.subText and choice.subText ~= "" then
            copied = copied .. " — " .. choice.subText
        end
        hs.pasteboard.setContents(copied)
        hs.alert.show("📋 Copied")
    end
end)
_G.choosers.activityReport:placeholderText("Activity report — Esc to close, Enter copies a row")
-- 6.16.6 REVERT: hideOnLostFocus is not a real hs.chooser method — it
-- doesn't exist in the actual API, only in a bad assumption of mine, and
-- calling it crashed the ENTIRE config on load ("attempt to call a nil
-- value"). hs.chooser has no supported way to suppress click-away
-- dismissal. Escape already closes it via the normal completion
-- callback (choice == nil), which was the one part of the ask this
-- popup could actually guarantee.

local function showActivityReport(titleText, startStr, endStr)
    local list = appTotalsInRange(startStr, endStr)
    local choices = {}
    table.insert(choices, {
        text    = titleText .. " — " .. formatDuration(grandTotal(list)) .. " total",
        subText = (startStr == endStr) and startStr or (startStr .. " → " .. endStr),
    })
    if #list == 0 then
        table.insert(choices, { text = "No activity recorded in this period", subText = "" })
    end
    for i, e in ipairs(list) do
        table.insert(choices, { text = i .. ". " .. e.name, subText = minutesLabel(e.seconds) })
    end
    _G.choosers.activityReport:choices(choices)
    _G.choosers.activityReport:rows(math.min(#choices, 12))
    showPopup(_G.choosers.activityReport)
end

local function showDailyActivityReport()
    showActivityReport("📊 DAILY REPORT", todayStr(), todayStr())
end

local function showWeeklyActivityReport()
    local endStr   = os.date("%Y-%m-%d", os.time() - 86400)       -- yesterday
    local startStr = os.date("%Y-%m-%d", os.time() - 7 * 86400)   -- 7 days back
    showActivityReport("🗓 WEEKLY RECAP", startStr, endStr)
end

-- hs.timer.doAt(time, "1d", fn) fires at that clock time every day.
-- Held in _G so Lua garbage collection can't silently kill them.
_G.activityDailyReportTimer = hs.timer.doAt(activityDailyReportTime, "1d", showDailyActivityReport)
_G.activityWeeklyReportTimer = hs.timer.doAt(activityWeeklyReportTime, "1d", function()
    local wd = tonumber(os.date("%w"))
    if wd == activityWeeklyReportWeekday or wd == 5 then   -- 5 = Friday
        showWeeklyActivityReport()
    end
end)

-- =====================================================================
-- 3.7 APP WATCHER — alert when a watched app closes
-- =====================================================================
-- Watches the apps listed below. When one of them quits (or crashes),
-- a popup appears front-and-center with two options:
--   🚀 Spawn — relaunch the app
--   🛑 End   — acknowledge and leave it closed
-- An audible ping repeats every few seconds until you respond — by
-- pressing a button, or dismissing with Escape. 6.16.21: NO auto-
-- dismiss anymore — if you're away when an app quits, a popup that
-- gives up after 30s means you'd never find out. It now stays on
-- screen (and keeps gently pinging) indefinitely until you actually
-- respond, however long that takes.
-- Dismissing with Esc posts a macOS notification — "{app} closed" —
-- so you still have a record even if you didn't take an action.
-- Requires notifications to be allowed for Hammerspoon in System
-- Settings → Notifications, or the notification silently won't
-- appear (a fallback on-screen alert covers that case).
--
-- ✏️ EDIT THIS LIST — exact app names, as shown in the menu bar next
-- to the  when the app is frontmost (or as they appear in your
-- Activity tracker rows). Case-sensitive.
local appMonitorWatchedApps = {
    "1Password",
    "Alfred",
    "Bartender",
    "CotEditor",
    "Ghostty",
    "Google Chrome",
    "IINA",
    "OneDrive",
    "Microsoft Defender",
    "Microsoft Excel",
    "Microsoft PowerPoint",
    "Microsoft Word",
    "Microsoft Outlook",
    "Microsoft Teams",
    "Microsoft Excel",
    "NordVPN",
    "Rectangle",
    "Shottr",
    "Sublime",
    "Transmission",
}
-- 6.16.21: no more auto-dismiss — if you're away when an app quits, a
-- popup that gives up after 30s means you'd never know. It now stays
-- up, pinging gently, until you actually respond (a button, or Esc).
local appMonitorSoundName      = "Ping"  -- any system sound: Ping, Glass, Hero, Sosumi, Submarine… ("Ping" is one of the gentler ones)
local appMonitorPingInterval   = 2       -- seconds between pings while waiting

local appMonitorQueue   = {}   -- apps waiting their turn if several close at once
local appMonitorCurrent = nil  -- app the popup is currently asking about
local appMonitorPing    = nil  -- repeating sound timer

local function appMonitorStopTimers()
    if appMonitorPing then appMonitorPing:stop(); appMonitorPing = nil end
end

local function appMonitorNotify(appName)
    local ok = pcall(function()
        hs.notify.new(nil, { title = "App Monitor", informativeText = appName .. " closed" }):send()
    end)
    -- If notifications are blocked/unavailable, at least flash an alert
    if not ok then hs.alert.show("ℹ️ " .. appName .. " closed") end
end

local appMonitorShowNext  -- forward declaration (finish + showNext call each other)

-- Resolves the current popup exactly once, no matter which path ends it
-- (button, Escape, or timeout) — appMonitorCurrent doubles as the guard.
local function appMonitorFinish(choice)
    local appName = appMonitorCurrent
    if not appName then return end
    appMonitorCurrent = nil
    appMonitorStopTimers()

    if choice and choice.action == "spawn" then
        -- 6.16.1 FIX: launchOrFocus(name) silently failed for apps
        -- whose real /Applications bundle is versioned on disk (Alfred
        -- ships as "Alfred 5.app", Bartender as "Bartender 5.app" —
        -- same mismatch already found in the App Update Tracker, §3.10).
        -- Resolve the real bundle path first and hand it straight to
        -- `open -a`, which doesn't care about the name mismatch;
        -- launchOrFocus stays as a fallback for anything not found.
        local path = _G.findAppBundle and _G.findAppBundle(appName)
        if path then
            hs.task.new("/usr/bin/open", nil, { "-a", path }):start()
        else
            hs.application.launchOrFocus(appName)
        end
        hs.alert.show("🚀 Relaunching " .. appName)
    elseif choice and choice.action == "end" then
        -- acknowledged; leave it closed, no notification
    else
        -- Esc — the only other way this resolves now (no more timeout)
        appMonitorNotify(appName)
    end

    appMonitorShowNext()  -- anything else queued up?
end

_G.appMonitorChooser = hs.chooser.new(function(choice)
    appMonitorFinish(choice)
end)
_G.appMonitorChooser:rows(2)

-- White text on black background. bgDark gives the chooser macOS's
-- dark panel (near-black, slightly translucent — choosers don't accept
-- an arbitrary flat background color); fgColor/subTextColor set the
-- main and secondary text to white. pcall-guarded in case a future
-- Hammerspoon version renames these.
pcall(function()
    _G.appMonitorChooser:bgDark(true)
    _G.appMonitorChooser:fgColor({ white = 1.0 })
    _G.appMonitorChooser:subTextColor({ white = 0.85 })
end)

appMonitorShowNext = function()
    if appMonitorCurrent then return end            -- one at a time
    local nextApp = table.remove(appMonitorQueue, 1)
    if not nextApp then return end
    appMonitorCurrent = nextApp

    _G.appMonitorChooser:placeholderText("⚠️  " .. nextApp .. " just closed — Spawn, End, or Esc to dismiss")
    _G.appMonitorChooser:choices({
        { text = "🚀 Spawn", subText = "Relaunch " .. nextApp,            action = "spawn" },
        { text = "🛑 End",   subText = "Acknowledge — leave it closed",   action = "end"   },
    })

    -- Front and center: chooser panels float above normal windows by
    -- nature; we center it on the frontmost app's screen. (Deliberately
    -- NOT registered in _G.choosers — it's an alert, not a picker, so
    -- popup nudging shouldn't drag it around.)
    local screen = resolveBaseScreen()
    local f = screen:frame()
    local pct = 40
    local okW, w = pcall(function() return _G.appMonitorChooser:width() end)
    if okW and type(w) == "number" and w > 0 and w <= 100 then pct = w end
    local width = f.w * (pct / 100)
    _G.appMonitorChooser:show(hs.geometry.point(f.x + (f.w - width) / 2, f.y + f.h * 0.35))

    -- Audible ping now, then repeating every appMonitorPingInterval
    -- seconds INDEFINITELY — no auto-dismiss anymore, so this keeps
    -- gently sounding until you actually respond, even if that's hours
    -- later. Stopped only by appMonitorStopTimers (called from
    -- appMonitorFinish, which only runs on a button press or Esc).
    local sound = nil
    pcall(function() sound = hs.sound.getByName(appMonitorSoundName) end)
    if sound then
        pcall(function() sound:play() end)
        appMonitorPing = hs.timer.doEvery(appMonitorPingInterval, function()
            pcall(function() sound:play() end)
        end)
    end
end

-- KNOWN GOTCHA this guards against: for `terminated` events, the
-- watcher's appName parameter is often NIL — the app is already gone
-- when the event arrives, so macOS can't always supply its name. So
-- instead of trusting the event's name, we keep our own running/
-- not-running map of the watched apps and RE-SCAN it whenever any
-- termination fires: whichever watched app just vanished is the one
-- that closed. The short delay lets the system settle so
-- hs.application.get() reliably reports the app as gone.
local appMonitorRunning = {}

-- 6.16.22 BEACHBALL FIX: this used to call hs.application.get(name)
-- once PER watched app — 20 separate name lookups. Console evidence
-- pinned an 11-second main-thread freeze to exactly that loop: the
-- gap opened on hs.application's own "alternate names / Spotlight
-- support" line, which is its NAME-RESOLUTION path announcing itself,
-- and closed 11s later. (6.16.8's 0.1s deferral moved this off the
-- config-LOAD path — which is why "-- Done." prints instantly — but
-- hs.timer.doAfter still runs on the MAIN thread, so the UI froze
-- 0.1s after the reload "finished" instead of during it.)
-- Now: ONE bulk enumeration (hs.application.runningApplications())
-- plus a pure-Lua name match. Same answer, one native call instead of
-- twenty name resolutions. Falls back to the old per-name lookup only
-- if the enumeration comes back empty, so behavior is never worse.
local function appMonitorScan(fireOnClose)
    local running = {}
    local okList, apps = pcall(hs.application.runningApplications)
    if okList and apps and #apps > 0 then
        for _, a in ipairs(apps) do
            local okName, n = pcall(function() return a:name() end)
            if okName and n then running[n] = true end
        end
    else
        for _, w in ipairs(appMonitorWatchedApps) do
            running[w] = (hs.application.get(w) ~= nil)
        end
    end

    for _, w in ipairs(appMonitorWatchedApps) do
        local isRunning = (running[w] == true)
        if fireOnClose and appMonitorRunning[w] and not isRunning then
            table.insert(appMonitorQueue, w)
            appMonitorShowNext()
        end
        appMonitorRunning[w] = isRunning
    end
end

-- 6.16.8: appMonitorScan's baseline is the FIRST thing in this file to
-- touch hs.application — and on this Mac that first touch alone costs
-- several seconds (confirmed with timed boot checkpoints; ruled out
-- both Microsoft Defender's file scanning and a Gatekeeper network
-- check as the cause — the delay is identical in Airplane Mode). We
-- can't make Hammerspoon's own module load faster, but we CAN keep it
-- off the critical boot path: deferring it means the other 32 hotkeys
-- are live and the reload itself completes instantly, and App
-- Monitor's own protection comes online a few seconds later instead of
-- blocking everything else.
-- 6.16.18 FIX: this whole feature silently never fired for ANY app
-- (Teams, Ghostty, Sublime all confirmed) — root cause was neither
-- `hs.timer.doAfter` call here stored its return value anywhere.
-- Unstored hs.timer objects are a real, documented Hammerspoon gotcha:
-- with nothing left referencing them, Lua's garbage collector can (and
-- evidently did) silently collect the timer before its delay elapsed,
-- canceling it with no error. Both now held in _G. so they can't be
-- collected before they fire.
-- 6.16.20 FIX: Console evidence (both Ghostty and Microsoft Teams,
-- reproduced twice) showed hs.application.get(name) STILL reporting
-- the app as running even 0.3s after its own "terminated" event fired
-- — the re-scan-via-get() approach is unreliable/stale on this Mac, not
-- just slow. The watcher itself hands us the correct appName directly
-- on every terminated event in this Console log, so trust THAT instead
-- of re-querying: no re-scan, no waiting, no dependency on get() ever
-- catching up. Falls back to a re-scan only in the rare case appName
-- is nil (matches the original 6.11.3 concern, kept as a safety net).
_G.appMonitorRescanTimers = {}   -- one-shot timers in flight; each removes itself once it fires
_G.appMonitorBootTimer = hs.timer.doAfter(0.1, function()
    appMonitorScan(false)  -- baseline: which watched apps are running now
    _G.appMonitorWatcher = hs.application.watcher.new(function(appName, eventType)
        if eventType == hs.application.watcher.terminated then
            if appName then
                local watched = false
                for _, w in ipairs(appMonitorWatchedApps) do
                    if w == appName then watched = true; break end
                end
                if watched and appMonitorRunning[appName] then
                    appMonitorRunning[appName] = false
                    table.insert(appMonitorQueue, appName)
                    appMonitorShowNext()
                end
            else
                local rt
                rt = hs.timer.doAfter(0.3, function()
                    appMonitorScan(true)
                    for i, t in ipairs(_G.appMonitorRescanTimers) do
                        if t == rt then table.remove(_G.appMonitorRescanTimers, i); break end
                    end
                end)
                table.insert(_G.appMonitorRescanTimers, rt)
            end
        elseif eventType == hs.application.watcher.launched then
            appMonitorScan(false)  -- keep the running map current
        end
    end)
    _G.appMonitorWatcher:start()
end)

-- =====================================================================
-- 3.8 FILE TRACKER — rename / move / copy history, searchable (⌃⌥⇧F)
-- =====================================================================
-- Watches the folders below via macOS FSEvents (hs.pathwatcher) and
-- logs, with a 90-day history:
--   • Renamed        old name → new name, same folder
--   • Moved          same name, old folder → new folder
--   • Renamed+Moved  both changed at once
--   • Moved out/in   file left for / arrived from somewhere outside
--                    the watched folders (only one side is visible)
--   • Copied         a copy appeared (macOS never reports a copy's
--                    SOURCE — only the new file — so origin is blank)
--   • Created        a brand-new file appeared
--
-- ⌃⌥⇧F opens a searchable picker (type to filter across every column;
-- Enter copies the row). 6.10.0: the CSV lives DIRECTLY in your
-- OneDrive Logs folder, machine-tagged —
-- <OneDrive>/Logs/file_changes-<Mac>.csv (Excel-ready, quote-safe).
-- It's already cloud-synced, so the old separate daily-copy timer is
-- gone; your existing ~/.hammerspoon/file_changes.csv was adopted on
-- first boot.
--
-- CSV columns: file_name, new_name, present_location, moved_location,
-- timestamp (DD/MM/YY HH:MM), event, epoch (epoch = plain seconds
-- number used only for the 90-day pruning; harmless in Excel).
--
-- HOW RENAME/MOVE DETECTION WORKS (and its honest limits): FSEvents
-- announces a rename/move as TWO events — old path and new path —
-- usually in the same instant. We pair them by arrival within a short
-- window and by checking which path still exists. Two files renamed in
-- the exact same instant could theoretically mis-pair; in practice
-- Finder operations arrive cleanly. Temp/hidden files (.*, ~$Office
-- locks, .tmp/.part/.crdownload) are ignored to keep the log humane.
--
-- ✏️ EDIT THESE — what to watch and the hotkey:
-- Watching your ENTIRE home folder + your OneDrive. To keep that sane:
--   • ~/Library is excluded (hundreds of cache/pref events per minute)
--     — EXCEPT OneDrive, which lives inside it and gets its own watcher
--   • hidden folders/files anywhere (.git, .Trash, .hammerspoon…) excluded
--   • our own telemetry (the OneDrive Logs folder + Backups/Hammerspoon)
--     excluded so the tracker never logs itself, the histories, or the
--     nightly backup churn — this matters MORE in 6.10.0, since every
--     data file now lives inside the watched OneDrive
--   • a burst guard suppresses floods (unzipping, mass exports): >30
--     created-file rows in 10s pauses Created logging until quiet —
--     renames/moves are never suppressed
-- NOTE: OneDrive syncs BOTH Macs' changes down, so files you rename on
-- the work Mac inside OneDrive will also appear in this Mac's log —
-- cross-machine visibility, which cuts both ways.
local fileTrackerFolders = { homeDir }
if cloudDir then table.insert(fileTrackerFolders, cloudDir) end
local fileTrackerMods          = {"ctrl", "alt", "shift"}
local fileTrackerKey           = "F"
local fileTrackerRetentionDays = 90
local fileTrackerFile          = logsDir .. "/file_changes-" .. hostTag .. ".csv"
adoptLegacyFile(fileTrackerFile, hs.configdir .. "/file_changes.csv")

-- 6.16.23: ✏️ EDIT THIS — macOS-internal noise the tracker should never
-- log. These are files the OPERATING SYSTEM churns constantly on its
-- own; none of them are documents you'd ever want a paper trail of.
-- Real reported examples: temp-CPAnalyticsPropertiesCache.plist and
-- store.updates rewriting themselves inside Photos Library every hour.
--
-- (1) DOCUMENT/MEDIA LIBRARY BUNDLES — these LOOK like a single file in
-- Finder but are really folders full of databases the OS rewrites
-- nonstop. Excluding the bundle excludes everything inside it. Moving
-- or renaming the bundle ITSELF is still logged — only its internals
-- are suppressed.
local fileTrackerNoiseBundles = {
    "%.photoslibrary/", "%.photolibrary/", "%.musiclibrary/",
    "%.tvlibrary/", "%.aplibrary/", "%.imovielibrary/",
    "%.theater/", "%.logicx/", "%.band/", "%.fcpbundle/",
    "%.noindex/", "%.spotlightV3/", "%.lrdata/", "%.migratedphotolibrary/",
}
-- (2) OS-INTERNAL FILE TYPES — preference/cache/index files.
local fileTrackerNoiseExts = {
    "%.plist$", "%.db$", "%.db%-wal$", "%.db%-shm$",
    "%.sqlite$", "%.sqlite%-wal$", "%.sqlite%-shm$",
    "%.updates$", "%.indexUpdates$", "%.spotlightV3$",
    "%.lock$", "%.pid$", "%.log$", "%.swp$", "%.swo$",
}

local function fileTrackerIgnored(path)
    local base = path:match("[^/]+$") or path
    if base:match("^%.")  then return true end   -- hidden / .DS_Store
    if base:match("^~%$") then return true end   -- Office lock files
    if base:match("%.tmp$") or base:match("%.part$")
       or base:match("%.crdownload$") or base:match("%.download$") then
        return true
    end
    -- 6.16.23: OS churn — anything inside a media/document library
    -- bundle, and OS-internal file types anywhere.
    for _, pat in ipairs(fileTrackerNoiseBundles) do
        if path:lower():find(pat) then return true end
    end
    for _, pat in ipairs(fileTrackerNoiseExts) do
        if base:lower():find(pat) then return true end
    end
    -- Sandbox/atomic-save scratch names (e.g. "foo.plist.sb-9e7584f9-3sh4il")
    if base:find("%.sb%-%w+$") then return true end
    return false
end

local function ftStartsWith(s, prefix)
    return s:sub(1, #prefix) == prefix
end

-- Path-level exclusions (see the notes above the folder list)
local function fileTrackerExcludedPath(path)
    if ftStartsWith(path, logsDir .. "/") then return true end -- the whole Logs
                                                               -- folder: every
                                                               -- history file now
                                                               -- lives there (also
                                                               -- covers the local
                                                               -- logs/ fallback)
    -- ~/.hammerspoon IS tracked despite being a hidden folder — config
    -- edits, init.lua swaps & secret.lua changes are worth a paper
    -- trail. Still excluded within it: any hidden items nested inside.
    -- (The tracker's own CSV no longer lives here — it's in Logs.)
    if ftStartsWith(path, hs.configdir .. "/") then
        local inside = path:sub(#hs.configdir + 2)
        if inside:match("^%.") or inside:match("/%.") then return true end
        return false
    end
    if path:match("/%.") then return true end                 -- hidden dir/file anywhere in path
    if cloudDir and ftStartsWith(path, cloudDir .. "/Backups/Hammerspoon/") then
        return true                                            -- nightly backup churn
    end
    if ftStartsWith(path, homeDir .. "/Library/") then
        -- Library is noise — except OneDrive, which lives inside it
        if not (cloudDir and ftStartsWith(path, cloudDir .. "/")) then
            return true
        end
    end
    return false
end

-- Burst guard: unzip/export floods suppress Created/Copied logging
-- (never renames/moves) until the storm passes
local ftBurst = { windowStart = 0, count = 0, warned = false }
local function fileTrackerBurstOK()
    local now = os.time()
    if now - ftBurst.windowStart > 10 then
        ftBurst.windowStart, ftBurst.count, ftBurst.warned = now, 0, false
    end
    ftBurst.count = ftBurst.count + 1
    if ftBurst.count > 30 then
        if not ftBurst.warned then
            print("⚠️ File tracker: created-file burst — suppressing Created rows until quiet")
            ftBurst.warned = true
        end
        return false
    end
    return true
end

local function fileTrackerDirOf(path)  return path:match("^(.*)/[^/]+$") or "" end
local function fileTrackerBaseOf(path) return path:match("[^/]+$") or path end
local function fileTrackerPretty(dir)
    if dir == "" then return "" end
    return (dir:gsub("^" .. homeDir:gsub("%-", "%%-"), "~"))
end

-- ---- storage (same quote-safe CSV helpers as the activity tracker) --

local function fileTrackerRewrite(log)
    local f = io.open(fileTrackerFile, "w")
    if not f then return false end
    f:write("file_name,new_name,present_location,moved_location,timestamp,event,epoch\n")
    for _, e in ipairs(log) do
        f:write(csvQuote(e.fileName) .. "," .. csvQuote(e.newName) .. ","
            .. csvQuote(e.presentLoc) .. "," .. csvQuote(e.movedLoc) .. ","
            .. csvQuote(e.timestamp) .. "," .. csvQuote(e.event) .. ","
            .. tostring(e.epoch) .. "\n")
    end
    f:close()
    return true
end

local function fileTrackerLoad()
    local f = io.open(fileTrackerFile, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local log, isFirst = {}, true
    for line in content:gmatch("([^\r\n]+)") do
        if not (isFirst and line:match("^file_name,")) then
            local c = splitCSVLine(line)
            local epoch = tonumber(c[7])
            if c[1] and epoch then
                table.insert(log, {
                    fileName = c[1], newName = c[2] or "",
                    presentLoc = c[3] or "", movedLoc = c[4] or "",
                    timestamp = c[5] or "", event = c[6] or "",
                    epoch = epoch,
                })
            end
        end
        isFirst = false
    end
    return log
end

local function fileTrackerPrune(log)
    local cutoff = os.time() - fileTrackerRetentionDays * 86400
    local kept = {}
    for _, e in ipairs(log) do
        if e.epoch >= cutoff then table.insert(kept, e) end
    end
    return _G.trackerCapRows(kept, "📁 File tracker")
end

local _ftLoaded = fileTrackerLoad()
_G.fileTrackerLog = fileTrackerPrune(_ftLoaded)
if #_G.fileTrackerLog ~= #_ftLoaded or #_ftLoaded == 0 then
    if not fileTrackerRewrite(_G.fileTrackerLog) then
        warnWriteFailed("file tracker CSV")
    end
end

local function fileTrackerAppendRow(e)
    local f = io.open(fileTrackerFile, "a")
    if f then
        f:write(csvQuote(e.fileName) .. "," .. csvQuote(e.newName) .. ","
            .. csvQuote(e.presentLoc) .. "," .. csvQuote(e.movedLoc) .. ","
            .. csvQuote(e.timestamp) .. "," .. csvQuote(e.event) .. ","
            .. tostring(e.epoch) .. "\n")
        f:close()
    else
        warnWriteFailed("file tracker CSV")
    end
end

local function fileTrackerRecord(event, fileName, newName, presentLoc, movedLoc)
    local entry = {
        event      = event,
        fileName   = fileName,
        newName    = newName or "",
        presentLoc = fileTrackerPretty(presentLoc or ""),
        movedLoc   = fileTrackerPretty(movedLoc or ""),
        timestamp  = os.date("%d/%m/%y %H:%M"),
        epoch      = os.time(),
    }
    table.insert(_G.fileTrackerLog, entry)
    fileTrackerAppendRow(entry)
end

-- ---- event classification --------------------------------------------

-- A completed old→new pair becomes one log row
local function fileTrackerPair(oldPath, newPath)
    local oldBase, newBase = fileTrackerBaseOf(oldPath), fileTrackerBaseOf(newPath)
    local oldDir,  newDir  = fileTrackerDirOf(oldPath),  fileTrackerDirOf(newPath)
    if oldDir == newDir and oldBase ~= newBase then
        fileTrackerRecord("Renamed", oldBase, newBase, oldDir, "")
    elseif oldDir ~= newDir and oldBase == newBase then
        fileTrackerRecord("Moved", oldBase, "", oldDir, newDir)
    elseif oldDir ~= newDir and oldBase ~= newBase then
        fileTrackerRecord("Renamed+Moved", oldBase, newBase, oldDir, newDir)
    end -- identical old==new: FSEvents echo, ignore
end

-- One shared pending slot pairs the two halves of a rename/move even
-- when they arrive via different folder watchers (e.g. Desktop →
-- Documents). If no partner shows up quickly, it was one-sided: the
-- file crossed the boundary of the watched folders.
local ftPending, ftPendingId = nil, 0
-- 6.16.18: held in _G. (not left as a bare, unstored doAfter return
-- value) so Lua's GC can't collect this one-shot timer before its 1.5s
-- elapses — the same real Hammerspoon gotcha that broke App Monitor.
_G.fileTrackerPendingTimers = {}

local function fileTrackerFlushPending(id)
    if not ftPending or ftPending.id ~= id then return end
    local p = ftPending
    ftPending = nil
    local base, dir = fileTrackerBaseOf(p.path), fileTrackerDirOf(p.path)
    if p.exists then
        fileTrackerRecord("Moved in", base, "", "(outside watched folders)", dir)
    else
        fileTrackerRecord("Moved out", base, "", dir, "(outside watched folders)")
    end
end

local function fileTrackerCallback(paths, flagTables)
    for i, path in ipairs(paths or {}) do
        local flags = (flagTables or {})[i] or {}
        if flags.itemIsFile and not fileTrackerIgnored(path)
           and not fileTrackerExcludedPath(path) then
            if flags.itemRenamed then
                local exists = (hs.fs.attributes(path) ~= nil)
                if ftPending and path ~= ftPending.path
                   and (hs.timer.secondsSinceEpoch() - ftPending.t) < 1.5 then
                    -- second half arrived: order by which side still exists
                    local oldP, newP = ftPending.path, path
                    if not exists and hs.fs.attributes(oldP) then
                        oldP, newP = path, ftPending.path
                    end
                    ftPending = nil
                    fileTrackerPair(oldP, newP)
                else
                    ftPendingId = ftPendingId + 1
                    ftPending = { path = path, exists = exists,
                                  t = hs.timer.secondsSinceEpoch(), id = ftPendingId }
                    local myId = ftPendingId
                    local pt
                    pt = hs.timer.doAfter(1.5, function()
                        fileTrackerFlushPending(myId)
                        for i, t in ipairs(_G.fileTrackerPendingTimers) do
                            if t == pt then table.remove(_G.fileTrackerPendingTimers, i); break end
                        end
                    end)
                    table.insert(_G.fileTrackerPendingTimers, pt)
                end
            elseif flags.itemCreated and not flags.itemRemoved then
                if fileTrackerBurstOK() then
                    local base, dir = fileTrackerBaseOf(path), fileTrackerDirOf(path)
                    if flags.itemCloned then
                        fileTrackerRecord("Copied", base, "", dir, "")
                    else
                        fileTrackerRecord("Created", base, "", dir, "")
                    end
                end
            end
        end
    end
end

_G.fileTrackerWatchers = {}
for _, folder in ipairs(fileTrackerFolders) do
    local ok, w = pcall(hs.pathwatcher.new, folder, fileTrackerCallback)
    if ok and w then
        pcall(function() w:start() end)
        table.insert(_G.fileTrackerWatchers, w)
    else
        print("⚠️ File tracker couldn't watch " .. folder)
    end
end

-- (6.10.0: the daily 5 PM copy-to-OneDrive timer is gone — the live
--  CSV above already IS in OneDrive, machine-tagged.)

-- ---- searchable picker (⌃⌥⇧F) ---------------------------------------

_G.choosers.fileTracker = hs.chooser.new(function(choice)
    if choice and choice.text then
        local copied = choice.text
        if choice.subText and choice.subText ~= "" then
            copied = copied .. " — " .. choice.subText
        end
        hs.pasteboard.setContents(copied)
        hs.alert.show("📋 Copied")
    end
end)
_G.choosers.fileTracker:placeholderText("File changes — type to search name, folder, event, date…")

local function renderFileTrackerChoices(query)
    local q = (query or ""):lower():match("^%s*(.-)%s*$")
    local choices = {}
    for i = #_G.fileTrackerLog, 1, -1 do  -- newest first
        local e = _G.fileTrackerLog[i]
        local haystack = (e.fileName .. " " .. e.newName .. " " .. e.presentLoc .. " "
            .. e.movedLoc .. " " .. e.event .. " " .. e.timestamp):lower()
        if q == "" or haystack:find(q, 1, true) then
            local text = e.fileName
            if e.newName ~= "" then text = text .. "  →  " .. e.newName end
            local locBits = {}
            if e.presentLoc ~= "" then table.insert(locBits, e.presentLoc) end
            if e.movedLoc   ~= "" then table.insert(locBits, "➜ " .. e.movedLoc) end
            table.insert(choices, {
                text    = text,
                subText = e.event .. "  ·  " .. table.concat(locBits, "  ") .. "  ·  " .. e.timestamp,
            })
        end
        if #choices >= 400 then break end
    end
    if #choices == 0 then
        table.insert(choices, {
            text    = (q == "") and "No file changes recorded yet" or ("No matches for \"" .. q .. "\""),
            subText = "Watching: home folder + OneDrive (edit list in init.lua §3.8)",
        })
    end
    _G.choosers.fileTracker:choices(choices)
end

_G.choosers.fileTracker:queryChangedCallback(function(query)
    local ok, err = pcall(renderFileTrackerChoices, query)
    if not ok then
        print("🚨 File tracker render error: " .. tostring(err))
        _G.choosers.fileTracker:choices({
            { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

hs.hotkey.bind(fileTrackerMods, fileTrackerKey, function()
    renderFileTrackerChoices("")
    showPopup(_G.choosers.fileTracker)
end)

-- =====================================================================
-- 3.9 AUTOCORRECT — fixes typos & TWo-caps as you type (⌃⌥⌘S toggles)
-- =====================================================================
-- Watches your typing system-wide and fixes a completed word the
-- moment you end it (space, return, punctuation, apostrophe…):
--   • DICTIONARY fixes from autocorrect.csv — e.g. "mna" → "man" —
--     with your capitalization preserved:
--     mna→man · Mna→Man · MNA→MAN  (so "Mna's Search" heals itself)
--   • TWo-caps RULE: any word starting with exactly two capitals then
--     a lowercase letter gets the second capital lowered (MAn→Man,
--     THe→The). One rule instead of thousands of entries; the
--     exceptions that are real (IDs, TVs, MHz…) live in the CSV as
--     "allow" rows. Acronym possessives like "TV's" are untouched
--     (the rule needs a third letter before the apostrophe).
--
-- THE DICTIONARY IS EXTERNAL on purpose: ~10,970 corrections would
-- bloat init.lua massively. 6.10.0: autocorrect.csv lives in the
-- OneDrive Logs folder and is SHARED by both Macs — one dictionary,
-- and an exception ⌃⌥⌘Z learns on one Mac reaches the other after its
-- next Hammerspoon reload. Your existing ~/.hammerspoon/autocorrect.csv
-- (all 10,970 entries) is adopted into OneDrive on first boot.
-- If it's somehow missing at boot, a small starter file is created so
-- the feature still works — drop the full CSV in anytime and reload.
-- CSV format:  type,wrong,right   → fix,mna,man   |   allow,IDs,
--
-- HONEST LIMITS:
--   • Needs Accessibility (same permission the window features use).
--     Not granted → autocorrect is OFF, everything else unaffected —
--     the boot report says so. Files themselves need no permissions.
--   • Password fields: macOS "secure input" blocks event taps there,
--     so nothing is watched or corrected in password boxes (good).
--   • Corrections fire on the word you JUST finished typing at the
--     keyboard — pasted text and existing text are never touched.
local autocorrectFile         = logsDir .. "/autocorrect.csv"
adoptLegacyFile(autocorrectFile, hs.configdir .. "/autocorrect.csv")
local autocorrectToggleKey    = "S"          -- ⌃⌥⌘S on/off
local autocorrectExcludedApps = {            -- exact app names; edit freely
    "Terminal",
    -- "Code",
}

_G.autocorrectEnabled = true
local autocorrectDict, autocorrectAllow = {}, {}
local autocorrectDictCount, autocorrectAllowCount = 0, 0

-- Default TWo-caps exceptions: two-letter initialisms with s/ed/ing
-- suffixes, plus unit symbols. Deliberately NOT here: "ITs" — it's a
-- typo of "Its" far more often than a plural of IT. The list can never
-- be complete (new acronyms appear constantly), so ⌃⌥⌘Z below learns
-- new exceptions the moment a fix goes wrong.
local autocorrectDefaultAllows = {
    "ACs","AIs","APs","ARs","BAs","CBs","CDs","COs","DBs","DJs","DJed","DJing",
    "DMs","EPs","ERs","EVs","GBs","GBps","GHz","GMs","GPa","GPs","GWh","HQs","HRs",
    "IDs","IDed","IDing","IMs","IPs","IQs","IVs","KBs","KOs","KOed","LBs","LPs","MAs",
    "MBs","MBps","MCs","MCed","MCing","MDs","MHz","MPa","MPs","MWh","OKs","OKed","OKing",
    "ORs","OSs","PAs","PBs","PCs","PEs","PJs","PMs","POs","POed","PRs","PTs","QBs","RAs",
    "RBs","RNs","RVs","SOs","TAs","TBs","TDs","THz","TVs","TWh","UIs","VCs","VPs","WRs","XLs",
}

-- Seed a small starter file if none exists, so a fresh Mac isn't silent
local function autocorrectSeedIfMissing()
    local f = io.open(autocorrectFile, "r")
    if f then f:close(); return end
    local out = io.open(autocorrectFile, "w")
    if not out then return end
    out:write("type,wrong,right\n")
    for _, a in ipairs(autocorrectDefaultAllows) do
        out:write("allow," .. a .. ",\n")
    end
    for _, p in ipairs({ {"teh","the"}, {"adn","and"}, {"mna","man"}, {"taht","that"}, {"thier","their"},
                         {"recieve","receive"}, {"seperate","separate"}, {"definately","definitely"},
                         {"occured","occurred"}, {"untill","until"} }) do
        out:write("fix," .. p[1] .. "," .. p[2] .. "\n")
    end
    out:close()
    print("✏️ Created starter " .. autocorrectFile .. " — replace it with your full dictionary anytime")
end

local function autocorrectLoad()
    autocorrectDict, autocorrectAllow = {}, {}
    autocorrectDictCount, autocorrectAllowCount = 0, 0
    local f = io.open(autocorrectFile, "r")
    if not f then return false end
    local content = f:read("*a"); f:close()
    local first = true
    for line in content:gmatch("([^\r\n]+)") do
        if not (first and line:match("^type,")) then
            local c = splitCSVLine(line)
            local kind, wrong, right = c[1], c[2], c[3]
            if kind == "fix" and wrong and right and wrong ~= "" and right ~= "" then
                autocorrectDict[wrong:lower()] = right:lower()
                autocorrectDictCount = autocorrectDictCount + 1
            elseif kind == "allow" and wrong and wrong ~= "" then
                autocorrectAllow[wrong] = true
                autocorrectAllowCount = autocorrectAllowCount + 1
            end
        end
        first = false
    end
    return true
end

-- Restore the user's capitalization onto a lowercase correction:
-- typed "Mna" → "Man" · typed "MNA" → "MAN" · typed "mna" → "man"
local function autocorrectApplyCase(typed, correction)
    if typed == typed:upper() and #typed > 1 then
        return correction:upper()
    elseif typed:sub(1, 1):match("%u") then
        return correction:sub(1, 1):upper() .. correction:sub(2)
    end
    return correction
end

-- The decision for one completed word: returns the corrected word, or
-- nil if it's fine as typed. Dictionary first, then the TWo-caps rule.
local function autocorrectFor(word)
    if #word < 2 then return nil end
    local hit = autocorrectDict[word:lower()]
    if hit then
        local fixed = autocorrectApplyCase(word, hit)
        if fixed ~= word then return fixed end
        return nil
    end
    if #word >= 3 and word:match("^%u%u%l") and word:match("^%a+$")
       and not autocorrectAllow[word] then
        return word:sub(1, 1) .. word:sub(2, 2):lower() .. word:sub(3)
    end
    return nil
end

-- ---- the typing watcher ---------------------------------------------
-- A word buffer follows what you type. Letters extend it; delete trims
-- it; navigation, clicks, shortcuts, digits and anything exotic clear
-- it (the cursor moved or the token isn't a plain word — never guess).
-- A boundary key (space/return/tab/punctuation/apostrophe) checks the
-- buffer: if a fix applies, the boundary keystroke is consumed, the
-- word is replaced (backspaces + retype), and the boundary is retyped
-- after it. Our own synthetic keystrokes are flagged so the watcher
-- ignores them.
local acBuffer    = ""
local acInjecting = false
-- 6.16.18: held in _G. so Lua's GC can't collect this one-shot timer
-- before its (short) delay elapses — same real Hammerspoon gotcha
-- that broke App Monitor; see that fix's note in §3.7 for the details.
_G.acInjectTimers = {}

-- The last correction made, for ⌃⌥⌘Z (undo + learn). undoSafe stays
-- true only until you type or click again — after that the text can't
-- be safely rewound, but the exception can still be learned.
local acLast = nil   -- { word, fixed, boundary, wasRule, undoSafe }

local acClearKeycodes = {   -- keys that mean "cursor moved / abandon word"
    [53] = true,  -- esc
    [123] = true, [124] = true, [125] = true, [126] = true,  -- arrows
    [115] = true, [119] = true, [116] = true, [121] = true,  -- home/end/pgup/pgdn
    [117] = true, -- forward delete
}

local function acIsExcludedApp()
    local ok, app = pcall(hs.application.frontmostApplication)
    if not ok or not app then return false end
    local okN, name = pcall(function() return app:name() end)
    if not okN or not name then return false end
    for _, ex in ipairs(autocorrectExcludedApps) do
        if name == ex then return true end
    end
    return false
end

local function acInject(word, fixed, boundary, wasRule)
    acInjecting = true
    local ok = pcall(function()
        for _ = 1, #word do
            hs.eventtap.keyStroke({}, "delete", 0)
        end
        hs.eventtap.keyStrokes(fixed .. boundary)
    end)
    acInjecting = false
    if ok then
        acLast = { word = word, fixed = fixed, boundary = boundary,
                   wasRule = wasRule, undoSafe = true }
    else
        print("⚠️ Autocorrect injection failed for '" .. word .. "'")
    end
end

_G.autocorrectTap = hs.eventtap.new(
    { hs.eventtap.event.types.keyDown,
      hs.eventtap.event.types.leftMouseDown,
      hs.eventtap.event.types.rightMouseDown },
    function(ev)
        if acInjecting then return false end

        local t = ev:getType()
        if t == hs.eventtap.event.types.leftMouseDown
           or t == hs.eventtap.event.types.rightMouseDown then
            acBuffer = ""
            if acLast then acLast.undoSafe = false end   -- cursor moved
            return false
        end

        local flags = ev:getFlags()
        if flags.cmd or flags.ctrl then
            acBuffer = ""
            return false   -- chords (incl. ⌃⌥⌘Z itself) don't spoil undo
        end

        local code = ev:getKeyCode()
        if code == 51 then                       -- delete: trim buffer
            if #acBuffer > 0 then acBuffer = acBuffer:sub(1, -2) end
            if acLast then acLast.undoSafe = false end
            return false
        end
        if acClearKeycodes[code] then
            acBuffer = ""
            if acLast then acLast.undoSafe = false end   -- cursor moved
            return false
        end

        local ch = ev:getCharacters()
        if not ch or #ch ~= 1 then               -- function keys, IME, etc.
            acBuffer = ""
            return false
        end

        if acLast then acLast.undoSafe = false end       -- typed something new

        if ch:match("^%a$") then                 -- letter: extend the word
            acBuffer = acBuffer .. ch
            if #acBuffer > 40 then acBuffer = "" end
            return false
        end

        -- Boundary characters end a word and trigger the check
        if ch == " " or ch == "\r" or ch == "\t"
           or ch:match("^[%.,;:!%?'\"%(%)%[%]{}<>/\\%-_=%+%*&%%%$#@~`|%^]$") then
            local word = acBuffer
            acBuffer = ""
            if _G.autocorrectEnabled and #word >= 2 then
                local fixed = autocorrectFor(word)
                if fixed and not acIsExcludedApp() then
                    local wasRule = (autocorrectDict[word:lower()] == nil)
                    local it
                    it = hs.timer.doAfter(0.01, function()
                        acInject(word, fixed, ch, wasRule)
                        for i, t in ipairs(_G.acInjectTimers) do
                            if t == it then table.remove(_G.acInjectTimers, i); break end
                        end
                    end)
                    table.insert(_G.acInjectTimers, it)
                    return true                  -- consume; we retype it
                end
            end
            return false
        end

        acBuffer = ""                            -- digits & anything else
        return false
    end
)

-- ⌃⌥⌘S — toggle on/off (the tap keeps running; the flag gates action,
-- so toggling is instant and the buffer logic stays warm)
hs.hotkey.bind(popupScreenKeys.mods, autocorrectToggleKey, function()
    _G.autocorrectEnabled = not _G.autocorrectEnabled
    hs.alert.show(_G.autocorrectEnabled and "✏️ Autocorrect ON" or "✏️ Autocorrect OFF")
end)

-- ⌃⌥⌘Z — the correction was WRONG: undo it and learn from it.
--   • TWo-caps rule fix (e.g. a real acronym plural not yet in the
--     list): the word is appended as an "allow" row in autocorrect.csv
--     — permanent, synced to the in-memory set immediately — and the
--     text is rewound if you haven't typed since. Because the CSV is
--     shared via OneDrive, the other Mac learns it too (after reload).
--   • Dictionary fix: the text is rewound this once; dictionary rows
--     are deliberate entries, so removing one permanently stays a
--     manual CSV edit (the alert names the exact row).
-- If you've typed or clicked since the fix, rewinding text isn't safe,
-- so only the learning half happens.
local autocorrectUndoKey = "Z"

hs.hotkey.bind(popupScreenKeys.mods, autocorrectUndoKey, function()
    local last = acLast
    if not last then
        hs.alert.show("✏️ No autocorrection to undo")
        return
    end
    acLast = nil

    -- Learn: rule fixes become permanent exceptions
    if last.wasRule then
        autocorrectAllow[last.word] = true
        autocorrectAllowCount = autocorrectAllowCount + 1
        local f = io.open(autocorrectFile, "a")
        if f then
            f:write("allow," .. last.word .. ",\n")
            f:close()
        else
            warnWriteFailed("autocorrect.csv")
        end
    end

    -- Rewind the text if nothing has happened since the fix
    if last.undoSafe then
        acInjecting = true
        pcall(function()
            for _ = 1, #last.fixed + #last.boundary do
                hs.eventtap.keyStroke({}, "delete", 0)
            end
            hs.eventtap.keyStrokes(last.word .. last.boundary)
        end)
        acInjecting = false
        hs.alert.show(last.wasRule
            and ("↩️ Restored " .. last.word .. " — added to exceptions permanently")
            or  ("↩️ Restored " .. last.word .. " — to make permanent, delete the CSV row: fix," .. last.word:lower() .. "," .. last.fixed:lower()))
    else
        hs.alert.show(last.wasRule
            and ("✏️ " .. last.word .. " added to exceptions for next time (text left as-is)")
            or  ("✏️ Noted — to stop fixing " .. last.word:lower() .. ", delete its row in autocorrect.csv"))
    end
end)

-- Boot: needs Accessibility; degrade politely without it
local acAxOK = false
pcall(function() acAxOK = hs.accessibilityState() end)
_G.autocorrectStatus = "off"
if acAxOK then
    autocorrectSeedIfMissing()
    autocorrectLoad()
    local started = false
    pcall(function() _G.autocorrectTap:start(); started = true end)
    if started then
        _G.autocorrectStatus = string.format("ON (%d fixes, %d exceptions, ⌃⌥⌘S toggles)",
            autocorrectDictCount, autocorrectAllowCount)
        -- Lesson from the brightness saga: macOS silently disables event
        -- taps it thinks are slow. A watchdog quietly revives ours.
        _G.autocorrectWatchdog = hs.timer.doEvery(30, function()
            pcall(function()
                if _G.autocorrectTap and not _G.autocorrectTap:isEnabled() then
                    _G.autocorrectTap:start()
                    print("✏️ Autocorrect tap was disabled by macOS — revived")
                end
            end)
        end)
    else
        _G.autocorrectStatus = "OFF (event tap failed to start)"
    end
else
    _G.autocorrectStatus = "OFF (needs Accessibility — files fine, no permission for typing watcher)"
end

-- =====================================================================
-- 3.10 APP UPDATE TRACKER — ⌃⌥⇧U · batch-check before an IT ticket
-- =====================================================================
-- Answers "which of my apps are behind RIGHT NOW?" so updates can be
-- batched into one IT ticket instead of installing them piecemeal.
-- HONEST LIMIT up front: no vendor here publishes a public release
-- schedule (Chrome is the closest exception — a new stable roughly
-- every 4 weeks — everything else ships whenever the vendor ships).
-- This tracker does not predict the future; it checks the PRESENT:
-- the version actually installed (read straight from each app's own
-- Info.plist) against the latest version Homebrew's Cask database
-- knows about — which tracks upstream release info for these apps
-- whether or not you actually installed them via Homebrew.
--
-- REQUIRES Homebrew (`brew`) on this Mac, used purely as a read-only
-- version oracle — nothing is installed or modified by this tracker;
-- it only reports. No Homebrew found → the feature politely reports
-- itself off in the boot log, same as Asana without secret.lua.
--
-- ✏️ EDIT THIS TABLE — one row per tracked app, mapping its process
-- name to its Homebrew Cask token (the part after /cask/ at
-- formulae.brew.sh). If the app's actual /Applications bundle name
-- differs from its process name (only Sublime Text does, here),
-- set appBundle. A renamed or wrong cask token is never silent: brew's
-- own error is caught and printed in the Console naming exactly which
-- row needs fixing.
-- ⚠️ These tokens are written from general knowledge, not verified
-- live against Homebrew from this machine — check the Console after
-- the first run and fix any row it flags.
-- Wrapped in do...end: this file's main chunk is already near Lua's
-- 200-local-variable ceiling (a single-file config this large adds up
-- fast), and everything in this section is self-contained — nothing
-- outside §3.10 references these locals by name. Scoping them frees
-- their slots for the rest of the file, the same reason §0.2 wraps its
-- secret.lua loading in its own do...end block.
do

-- ✏️ `url` is the vendor's official download/update page — offered as
-- the fallback action (Enter opens it in your browser) whenever a
-- Homebrew install isn't possible or isn't safe (see §3.10.1 below).
-- These are written from general knowledge, not verified live from
-- this machine — spot-check each one once; unlike a cask token, a
-- stale URL can't self-diagnose (a dead link just opens a 404, it
-- doesn't error back into the Console the way brew does).
local updateTrackerApps = {
    { app = "1Password",           cask = "1password",           url = "https://1password.com/downloads/mac/" },
    { app = "Alfred",               cask = "alfred",               url = "https://www.alfredapp.com/" },
    -- 6.31.3: Hammerspoon tracks its own updates now. It is excluded
    -- from the App Monitor (§3.7) and from App Lock on purpose — those
    -- would have it watching/locking itself — but an update tracker has
    -- no such conflict, and a stale Hammerspoon is exactly the thing
    -- that breaks every other tool in this file.
    { app = "Hammerspoon",          cask = "hammerspoon",          url = "https://www.hammerspoon.org/" },
    { app = "Bartender",            cask = "bartender",            url = "https://www.macbartender.com/" },
    { app = "CotEditor",            cask = "coteditor",            url = "https://coteditor.com/" },
    { app = "Ghostty",               cask = "ghostty",               url = "https://ghostty.org/download" },
    { app = "Google Chrome",        cask = "google-chrome",        url = "https://www.google.com/chrome/" },
    { app = "OneDrive",              cask = "onedrive",              url = "https://www.microsoft.com/en-us/microsoft-365/onedrive/download" },
    -- No cask: Defender for Mac is an enterprise product distributed
    -- via Microsoft's own installer / MDM (Intune, Jamf), not Homebrew
    -- — confirmed by brew itself: "No Cask with this name exists."
    -- The download link is the ONLY automatic action available for
    -- this row (see §3.10.1) since there's no brew path at all.
    { app = "Microsoft Defender",   cask = nil,                     url = "https://www.microsoft.com/en-us/microsoft-365/microsoft-defender-for-individuals" },
    { app = "Microsoft Excel",      cask = "microsoft-excel",      url = "https://www.microsoft.com/en-us/microsoft-365/excel" },
    { app = "Microsoft PowerPoint", cask = "microsoft-powerpoint", url = "https://www.microsoft.com/en-us/microsoft-365/powerpoint" },
    { app = "Microsoft Word",       cask = "microsoft-word",       url = "https://www.microsoft.com/en-us/microsoft-365/word" },
    { app = "Microsoft Outlook",    cask = "microsoft-outlook",    url = "https://www.microsoft.com/en-us/microsoft-365/outlook/email-and-calendar-software-microsoft-outlook" },
    { app = "Microsoft Teams",      cask = "microsoft-teams",      url = "https://www.microsoft.com/en-us/microsoft-teams/download-app" },
    { app = "NordVPN",               cask = "nordvpn",               url = "https://nordvpn.com/download/mac/" },
    { app = "Rectangle",             cask = "rectangle",             url = "https://rectangleapp.com/" },
    { app = "Shottr",                cask = "shottr",                url = "https://shottr.cc/" },
    { app = "Sublime", appBundle = "Sublime Text", cask = "sublime-text", url = "https://www.sublimetext.com/download" },
    { app = "Transmission",          cask = "transmission",          url = "https://transmissionbt.com/download" },
}

local updateTrackerMods       = {"ctrl", "alt", "shift"}
local updateTrackerKey        = "U"
local updateTrackerFile       = logsDir .. "/app_updates-" .. hostTag .. ".csv"
local updateTrackerCheckTime  = "09:00"   -- daily automatic check, 24h format

-- Homebrew's install location differs between Apple Silicon and Intel
-- Macs; check both rather than assuming one.
local brewPath = nil
for _, candidate in ipairs({ "/opt/homebrew/bin/brew", "/usr/local/bin/brew" }) do
    local f = io.open(candidate, "r")
    if f then f:close(); brewPath = candidate; break end
end

local updateStatusLabel = {
    ["update-available"] = "🔔 Update available",
    ["check-failed"]      = "⚠️ Check failed",
    ["unknown-cask"]      = "❓ Unknown cask token",
    ["no-cask"]           = "🔍 No Homebrew cask — check manually",
    ["not-installed"]     = "— Not installed here",
    ["up-to-date"]        = "✅ Up to date",
    ["not-checked"]       = "… Not checked yet",
}
local updateStatusOrder = {
    ["update-available"] = 1, ["check-failed"] = 2, ["unknown-cask"] = 3,
    ["not-installed"] = 4, ["no-cask"] = 5, ["not-checked"] = 6, ["up-to-date"] = 7,
}

-- Loaded from disk at boot (so results survive a reload) and rewritten
-- after every check. Keyed by app name, same shape either way:
-- { installed=, latest=, status=, checkedAt= }
_G.updateTrackerResults = {}

local function loadUpdateResults()
    local f = io.open(updateTrackerFile, "r")
    if not f then return end
    local content = f:read("*a"); f:close()
    local first = true
    for line in content:gmatch("([^\r\n]+)") do
        if not (first and line:match("^checked_at,")) then
            local c = splitCSVLine(line)
            if c[2] and c[2] ~= "" then
                _G.updateTrackerResults[c[2]] = {
                    checkedAt   = c[1] or "", installed = c[3] or "",
                    latest      = c[4] or "", status    = c[5] or "not-checked",
                    brewManaged = (c[6] == "true"),
                }
            end
        end
        first = false
    end
end
loadUpdateResults()

local function saveUpdateResults()
    local f = io.open(updateTrackerFile, "w")
    if not f then warnWriteFailed("app update tracker CSV"); return end
    f:write("checked_at,app,installed_version,latest_version,status,brew_managed\n")
    for _, entry in ipairs(updateTrackerApps) do
        local r = _G.updateTrackerResults[entry.app]
        if r then
            f:write(csvQuote(r.checkedAt) .. "," .. csvQuote(entry.app) .. ","
                .. csvQuote(r.installed) .. "," .. csvQuote(r.latest) .. ","
                .. csvQuote(r.status) .. "," .. csvQuote(tostring(r.brewManaged == true)) .. "\n")
        end
    end
    f:close()
end

-- Some apps version their own /Applications bundle name (Alfred ships
-- as "Alfred 5.app", Bartender as "Bartender 5.app", not a fixed
-- "Alfred.app" / "Bartender.app") — an exact-name guess wrongly reports
-- these as "not installed" even when they are. Falls back to a prefix
-- scan of /Applications (first matching "<name>*.app" wins) before
-- giving up; entry.appBundle still short-circuits this for anything
-- that needs an exact override.
-- _G. so §3.7's App Monitor can reuse this same resolver (see the
-- 6.16.1 fix note there) without a second copy of this logic.
_G.findAppBundle = function(name)
    local exact = "/Applications/" .. name .. ".app"
    if hs.fs.attributes(exact, "mode") == "directory" then return exact end

    local found = nil
    pcall(function()
        for entry in hs.fs.dir("/Applications") do
            if found == nil and entry:sub(1, #name) == name and entry:sub(-4) == ".app" then
                found = "/Applications/" .. entry
            end
        end
    end)
    return found
end

local isUpdateCheckRunning = false

-- Runs the whole batch: for every tracked app, two async subprocesses
-- (installed version via `defaults read`, latest version via
-- `brew info --cask --json=v2`) race in parallel; this app's row is
-- only finalized once both land. onComplete (optional) fires once
-- every app has resolved.
local function runUpdateCheck(onComplete)
    if isUpdateCheckRunning then
        hs.alert.show("⚠️ Update check already running…")
        return
    end
    if not brewPath then
        hs.alert.show("⚠️ Homebrew not found — App Update Tracker needs it (see §3.10)")
        return
    end

    isUpdateCheckRunning = true
    hs.alert.show("🔄 Checking " .. #updateTrackerApps .. " apps for updates…")

    local remaining = #updateTrackerApps

    local function finishOne()
        remaining = remaining - 1
        if remaining == 0 then
            isUpdateCheckRunning = false
            saveUpdateResults()
            local staleCount = 0
            for _, r in pairs(_G.updateTrackerResults) do
                if r.status == "update-available" then staleCount = staleCount + 1 end
            end
            hs.alert.show(staleCount == 0
                and "✅ All tracked apps are up to date"
                or ("🔔 " .. staleCount .. " app(s) have updates available — ⌃⌥⇧U to review"), 4)
            if onComplete then onComplete() end
        end
    end

    for _, entry in ipairs(updateTrackerApps) do
        local bundleName = entry.appBundle or entry.app
        -- brewCheckDone starts TRUE when there's no cask at all — there's
        -- nothing to check, so it shouldn't block finishing.
        local partial = { installedDone = false, latestDone = false, brewCheckDone = not entry.cask }

        local function maybeFinish()
            if not (partial.installedDone and partial.latestDone and partial.brewCheckDone) then return end
            local status
            if not entry.cask then
                -- No Homebrew cask exists for this app (see the note by
                -- its entry in updateTrackerApps) — nothing to compare
                -- against, so this is informational, not a check failure.
                status = partial.installed and "no-cask" or "not-installed"
            elseif partial.checkErr then
                status = "check-failed"
            elseif not partial.installed then
                status = "not-installed"
            elseif not partial.latest then
                status = "unknown-cask"
            elseif partial.installed == partial.latest then
                status = "up-to-date"
            else
                status = "update-available"
            end
            _G.updateTrackerResults[entry.app] = {
                installed   = partial.installed or "",
                latest      = partial.latest or "",
                status      = status,
                checkedAt   = os.date("%Y-%m-%d %H:%M:%S"),
                brewManaged = partial.brewManaged or false,
            }
            finishOne()
        end

        -- Installed version: read straight from the app's own bundle,
        -- independent of how (or whether) it was installed via brew.
        -- findAppBundle handles apps whose .app folder is itself
        -- versioned on disk (Alfred 5.app, Bartender 5.app…).
        local appPath = _G.findAppBundle(bundleName)
        if appPath then
            hs.task.new("/usr/bin/defaults", function(exitCode, stdOut)
                if exitCode == 0 and stdOut and #stdOut > 0 then
                    partial.installed = (stdOut:gsub("%s+$", ""))
                end
                partial.installedDone = true
                maybeFinish()
            end, { "read", appPath .. "/Contents/Info.plist",
                   "CFBundleShortVersionString" }):start()
        else
            partial.installedDone = true
            maybeFinish()
        end

        -- Latest known version, per Homebrew's Cask database — skipped
        -- entirely when this app has no cask token (entry.cask == nil):
        -- there's no Homebrew lookup to make, so there's nothing to fail.
        if entry.cask then
            hs.task.new(brewPath, function(exitCode, stdOut, stdErr)
                if exitCode == 0 and stdOut then
                    local ok, data = pcall(hs.json.decode, stdOut)
                    if ok and data and data.casks and data.casks[1] and data.casks[1].version then
                        partial.latest = tostring(data.casks[1].version)
                    end
                else
                    partial.checkErr = true
                    print("⚠️ App Update Tracker: brew couldn't resolve cask '" .. entry.cask
                        .. "' for " .. entry.app .. " — check the token in updateTrackerApps (§3.10)"
                        .. ((stdErr and stdErr ~= "") and (": " .. stdErr:gsub("\n", " ")) or ""))
                end
                partial.latestDone = true
                maybeFinish()
            end, { "info", "--cask", entry.cask, "--json=v2" }):start()

            -- §3.10.1: is this cask actually tracked by brew as
            -- INSTALLED (in its Caskroom)? `brew info` above only tells
            -- us the latest upstream version exists — it says nothing
            -- about how THIS app got onto THIS Mac. Most of these were
            -- almost certainly installed by direct download, not brew,
            -- so `brew upgrade --cask` would have nothing to upgrade
            -- (or worse, try to install fresh over an existing app).
            -- `brew list --cask --versions` exits 0 only when brew's own
            -- Caskroom has a record — that's the one-key-install gate.
            hs.task.new(brewPath, function(exitCode)
                partial.brewManaged = (exitCode == 0)
                partial.brewCheckDone = true
                maybeFinish()
            end, { "list", "--cask", "--versions", entry.cask }):start()
        else
            partial.latestDone = true
            maybeFinish()
        end
    end
end

-- §3.10.1 HOMEBREW INSTALL — only ever offered for a row that is BOTH
-- "update-available" AND brewManaged (see the check above): those are
-- the only casks safe to hand straight to `brew upgrade` unattended.
-- Runs one or many tokens in a single brew invocation (the "Upgrade
-- ALL" row batches every eligible app into one call), then re-runs the
-- full check so the picker reflects what actually happened rather than
-- assuming success.
local function brewUpgradeCasks(tokens)
    if not brewPath or #tokens == 0 then return end
    hs.alert.show("⬆️ Installing " .. #tokens .. " update(s) via Homebrew…", 4)
    local args = { "upgrade", "--cask" }
    for _, t in ipairs(tokens) do table.insert(args, t) end
    hs.task.new(brewPath, function(exitCode, stdOut, stdErr)
        if exitCode == 0 then
            hs.alert.show("✅ Homebrew finished — re-checking…", 3)
        else
            hs.alert.show("⚠️ Homebrew install had errors — check Console, ⌃⌥⇧U to re-check", 5)
            print("🚨 brew upgrade error: " .. tostring(stdErr))
        end
        runUpdateCheck()
    end, args):start()
end

-- ---- picker (⌃⌥⇧U) ----------------------------------------------------
-- Enter's action depends on the row (see renderUpdateChoices below):
--   🍺 update-available + brew-managed → installs via `brew upgrade`
--   🌐 update-available (not brew-managed) or no-cask, with a URL
--                                       → opens the vendor's download page
--   otherwise                          → copies "installed → latest"
_G.choosers.appUpdates = hs.chooser.new(function(choice)
    if not choice then return end

    if choice.isUpgradeAll then
        brewUpgradeCasks(choice.tokens)
        return
    end
    if not choice.appName then return end

    if choice.action == "brew" and choice.cask then
        brewUpgradeCasks({ choice.cask })
        return
    end
    if choice.action == "url" and choice.url then
        hs.urlevent.openURL(choice.url)
        hs.alert.show("🌐 Opening " .. choice.appName .. "'s download page…")
        return
    end

    local copied = choice.appName .. ": " .. (choice.installed or "") .. " → " .. (choice.latest or "")
    hs.pasteboard.setContents(copied)
    hs.alert.show("📋 Copied")
end)
_G.choosers.appUpdates:placeholderText("App updates — type to filter, Enter acts on a row")

local function renderUpdateChoices(query)
    local q = (query or ""):lower():match("^%s*(.-)%s*$")
    local rows = {}
    for _, entry in ipairs(updateTrackerApps) do
        local r = _G.updateTrackerResults[entry.app]
        table.insert(rows, {
            appName     = entry.app,
            installed   = r and r.installed or "",
            latest      = r and r.latest or "",
            status      = r and r.status or "not-checked",
            cask        = entry.cask,
            url         = entry.url,
            brewManaged = r and r.brewManaged or false,
        })
    end
    table.sort(rows, function(a, b)
        local oa, ob = updateStatusOrder[a.status] or 9, updateStatusOrder[b.status] or 9
        if oa ~= ob then return oa < ob end
        return a.appName < b.appName
    end)

    local choices = {}

    -- "Upgrade ALL" synthetic row — only while the box is empty (so it
    -- doesn't linger while filtering for something specific), and only
    -- when at least one update-available app is actually brew-managed.
    if q == "" then
        local tokens, names = {}, {}
        for _, row in ipairs(rows) do
            if row.status == "update-available" and row.brewManaged and row.cask then
                table.insert(tokens, row.cask)
                table.insert(names, row.appName)
            end
        end
        if #tokens > 0 then
            table.insert(choices, {
                text         = "⬆️ Upgrade ALL " .. #tokens .. " brew-managed app(s) now",
                subText      = table.concat(names, ", "),
                isUpgradeAll = true,
                tokens       = tokens,
            })
        end
    end

    for _, row in ipairs(rows) do
        local haystack = (row.appName .. " " .. row.status):lower()
        if q == "" or haystack:find(q, 1, true) then
            local label    = updateStatusLabel[row.status] or row.status
            local versions = (row.installed ~= "" or row.latest ~= "")
                and (row.installed .. "  →  " .. row.latest) or "not checked yet"

            local action, actionText = "copy", ""
            if row.status == "update-available" and row.brewManaged and row.cask then
                action, actionText = "brew", "  ·  Enter installs via Homebrew"
            elseif (row.status == "update-available" or row.status == "no-cask") and row.url then
                action, actionText = "url", "  ·  Enter opens the download page"
            end

            table.insert(choices, {
                text      = row.appName,
                subText   = label .. "  ·  " .. versions .. actionText,
                appName   = row.appName,
                installed = row.installed,
                latest    = row.latest,
                cask      = row.cask,
                url       = row.url,
                action    = action,
            })
        end
    end
    if #choices == 0 then
        table.insert(choices, { text = "No matches for \"" .. q .. "\"", subText = "" })
    end
    _G.choosers.appUpdates:choices(choices)
end

_G.choosers.appUpdates:queryChangedCallback(function(query)
    local ok, err = pcall(renderUpdateChoices, query)
    if not ok then
        print("🚨 App Update Tracker render error: " .. tostring(err))
        _G.choosers.appUpdates:choices({
            { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

-- ⌃⌥⇧U — open the picker immediately with whatever's cached from the
-- last check, and always kicks off a fresh one in the background — same
-- pattern as the Asana Dashboard (§6), which re-fetches every time you
-- open it rather than showing yesterday's numbers. This also means a
-- config update (a fixed cask token, a corrected bundle path) shows up
-- on the very next press instead of waiting for the 9am timer or an
-- empty cache — 18 lightweight subprocess pairs is cheap for something
-- you trigger deliberately, not a background poll.
hs.hotkey.bind(updateTrackerMods, updateTrackerKey, function()
    renderUpdateChoices("")
    showPopup(_G.choosers.appUpdates)
    runUpdateCheck(function()
        local q = ""
        pcall(function() q = _G.choosers.appUpdates:query() or "" end)
        renderUpdateChoices(q)
    end)
end)

-- Automatic daily check so results are already warm before you ever
-- press ⌃⌥⇧U — same on-a-clock pattern as the Activity Tracker's
-- reports (§3.6).
if brewPath then
    _G.updateTrackerTimer = hs.timer.doAt(updateTrackerCheckTime, "1d", function() runUpdateCheck() end)
else
    print("ℹ️ App Update Tracker: Homebrew not found on this Mac — feature disabled (see §3.10)")
end

end -- do...end (§3.10 App Update Tracker locals)
-- =====================================================================

-- =====================================================================
-- 3.11 GLOBAL COPY-ON-SELECT — ⌘⌃⌥⇧C toggles · OFF by default
-- =====================================================================
-- CORRECTED: AXSelectedTextChanged is posted by the specific FOCUSED
-- TEXT ELEMENT, not the application as a whole — watching the app root
-- for it (the previous version of this block) essentially never
-- fires. Fix: watch the app for AXFocusedUIElementChanged (a real,
-- reliable per-app notification), and each time focus lands on a new
-- element, attach a SEPARATE watcher to THAT element for
-- AXSelectedTextChanged.
-- HONEST LIMITS: reliability depends entirely on how well each app
-- implements Accessibility. Native Cocoa apps (TextEdit, Notes, Mail)
-- and browser page text generally expose this correctly. Electron apps
-- (Chrome, Slack, VS Code, Discord) have historically inconsistent AX
-- support — expect hit-or-miss there, not a guarantee. Test in TextEdit
-- or Notes first — that's the best-case, most reliable case.
do

local cosExcludedApps = {}
local cosFocusObserver, cosSelectionObserver = nil, nil

local function cosIsExcluded(name)
    for _, ex in ipairs(cosExcludedApps) do if name == ex then return true end end
    return false
end

-- Debounced: a drag-selection fires AXSelectedTextChanged on every
-- intermediate change, not just the final one. Each call restarts a
-- short timer instead of copying immediately; only the LAST call
-- (selection has stopped changing) actually reads AXSelectedText and
-- copies — reading it fresh at fire time, not a stale snapshot.
local cosDebounce = nil
local function cosCopyFrom(element)
    if cosDebounce then cosDebounce:stop() end
    cosDebounce = hs.timer.doAfter(0.35, function()
        local ok, text = pcall(function() return element:attributeValue("AXSelectedText") end)
        if ok and type(text) == "string" and #text > 0 then
            hs.pasteboard.setContents(text)
        end
    end)
end

local function cosStopSelectionWatch()
    if cosDebounce then cosDebounce:stop(); cosDebounce = nil end
    if cosSelectionObserver then
        pcall(function() cosSelectionObserver:stop() end)
        cosSelectionObserver = nil
    end
end

local function cosWatchFocusedElement(pid, element)
    cosStopSelectionWatch()
    if not (_G.copyOnSelectEnabled and element) then return end
    local ok, obs = pcall(hs.axuielement.observer.new, pid)
    if not ok or not obs then return end
    local okWatch = pcall(function()
        obs:callback(function(_, el) cosCopyFrom(el) end)
        obs:addWatcher(element, "AXSelectedTextChanged")
        obs:start()
    end)
    if okWatch then cosSelectionObserver = obs end
end

local function cosStopAll()
    cosStopSelectionWatch()
    if cosFocusObserver then
        pcall(function() cosFocusObserver:stop() end)
        cosFocusObserver = nil
    end
end

local function cosStartForApp(app)
    cosStopAll()
    if not (_G.copyOnSelectEnabled and app) then return end
    local okName, name = pcall(function() return app:name() end)
    if not okName or not name or name == "Hammerspoon" or cosIsExcluded(name) then return end
    local okPid, pid = pcall(function() return app:pid() end)
    if not okPid or not pid then return end
    local okAx, axApp = pcall(hs.axuielement.applicationElement, app)
    if not okAx or not axApp then return end

    local okObs, obs = pcall(hs.axuielement.observer.new, pid)
    if not okObs or not obs then return end
    local okWatch = pcall(function()
        obs:callback(function(_, element) cosWatchFocusedElement(pid, element) end)
        obs:addWatcher(axApp, "AXFocusedUIElementChanged")
        obs:start()
    end)
    if okWatch then
        cosFocusObserver = obs
        -- Also catch whatever's ALREADY focused right now, not just
        -- the next focus change.
        local okFocused, focused = pcall(function() return axApp:attributeValue("AXFocusedUIElement") end)
        if okFocused and focused then cosWatchFocusedElement(pid, focused) end
    else
        print("⚠️ Copy-on-select: " .. name .. " didn't accept an Accessibility watcher")
    end
end

_G.copyOnSelectWatcher = hs.application.watcher.new(function(_, eventType, app)
    if eventType == hs.application.watcher.activated then
        cosStartForApp(app)
    end
end)
_G.copyOnSelectWatcher:start()

_G.copyOnSelectEnabled = false
hs.hotkey.bind({"cmd", "ctrl", "alt", "shift"}, "C", function()
    _G.copyOnSelectEnabled = not _G.copyOnSelectEnabled
    if _G.copyOnSelectEnabled then
        local ok, app = pcall(hs.application.frontmostApplication)
        if ok then cosStartForApp(app) end
        hs.alert.show("🖱️ Copy-on-select ON")
    else
        cosStopAll()
        hs.alert.show("🖱️ Copy-on-select OFF")
    end
end)

end -- do...end (§3.11 Copy-on-Select locals, corrected)

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
                local parsed  = hs.json.decode(responseBody)
                local taskGid = parsed and parsed.data and parsed.data.gid

                if taskGid then
                    -- 💬 Auto-comment (configured at top of file; "" disables)
                    if autoCommentText ~= "" then
                        addCommentToTask(taskGid, autoCommentText)
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
                        local taskData = hs.json.decode(b)
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
    renderActivityChoices("")
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

        local response = hs.json.decode(body)
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
                            addCommentToTask(choice.gid, text)
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
-- 6.5 COMMAND HISTORY — ⇪H, searchable shell history, Enter copies
-- =====================================================================
-- Clipboard History for your terminal: search every command you've run
-- and press Enter to copy it back to the clipboard.
--
-- ⚠️ THIS CONFIG DOES NOT WRITE command_history.log — your shell does.
-- That means two things. First, the format is whatever your shell wrote,
-- so the parser below deliberately accepts several shapes rather than
-- assuming one (see commandHistoryParse). Second, the file is re-read
-- every time you open the picker rather than cached at boot — otherwise
-- commands run after Hammerspoon started would be invisible.
--
-- If nothing shows up, the picker tells you exactly which paths it
-- looked in instead of just showing an empty list — set
-- commandHistoryPath below to the real one and reload.
--
-- Wrapped in an immediately-invoked function, NOT a do...end block: the
-- main chunk sits at Lua's hard ceiling of 200 locals, and a do block's
-- locals still count against it. A function body gets its own budget.
-- The leading semicolon is REQUIRED, not style: without it Lua reads
-- `end)()` on the previous section followed by `(function()` here as ONE
-- expression — calling the previous section's return value with this
-- function as its argument. It compiles clean and fails at runtime with
-- "attempt to call a nil value". Every IIFE section below starts with one.
;(function()

-- ✏️ EDIT THIS if auto-detection doesn't find your file. nil = search
-- the candidates below, in order, and use the first that exists.
local commandHistoryPath = nil

local commandHistoryCandidates = {
    logsDir .. "/Terminal+Ghostty/command_history.log",
    logsDir .. "/command_history.log",
    hs.configdir .. "/logs/Terminal+Ghostty/command_history.log",
    os.getenv("HOME") .. "/Library/CloudStorage/OneDrive-Personal/Logs/Terminal+Ghostty/command_history.log",
}

local commandHistoryMaxRows = 400   -- rows shown in the picker at once

-- Never read an unbounded file on the main thread — that is precisely
-- how the §3.7 boot beachball happened. The log only ever grows, so read
-- at most the last 512 KB (roughly 10,000 commands). Measured: a 1.8 MB
-- read cost ~0.26s, which is long enough to feel like a stall on a
-- keypress; 512 KB keeps it comfortably imperceptible.
local COMMAND_HISTORY_MAX_BYTES = 512 * 1024

local function commandHistoryResolvePath()
    if commandHistoryPath then return commandHistoryPath end
    for _, p in ipairs(commandHistoryCandidates) do
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end
    return nil
end

-- Accepts every common shell-history shape, because this config didn't
-- write the file and can't dictate its format:
--   git status                        plain
--   : 1690000000:0;git status         zsh EXTENDED_HISTORY
--   [2026-07-29 03:48:12] git status  bracketed timestamp
--   2026-07-29 03:48:12  git status   plain timestamp (space or tab)
--   2026-07-29T03:48:12Z git status   ISO timestamp
--     42  git status                  numbered (bash history output)
-- Returns command, timestamp-or-nil. Anything unrecognised is treated as
-- a plain command rather than dropped — losing lines silently would be
-- worse than showing one with no date.
local function commandHistoryParse(line)
    local when, cmd

    -- zsh EXTENDED_HISTORY: ": <epoch>:<elapsed>;<command>"
    local epoch, rest = line:match("^:%s*(%d+):%d+;(.*)$")
    if epoch and rest then
        return rest, os.date("%Y-%m-%d %H:%M", tonumber(epoch))
    end

    -- "[2026-07-29 03:48:12] command"
    when, cmd = line:match("^%[([^%]]+)%]%s+(.*)$")
    if when and cmd ~= "" then return cmd, when end

    -- "2026-07-29 03:48:12  command" / "2026-07-29T03:48:12Z command"
    when, cmd = line:match("^(%d%d%d%d%-%d%d%-%d%d[T ]%d%d:%d%d:?%d*Z?)%s+(.*)$")
    if when and cmd ~= "" then return cmd, (when:gsub("T", " "):gsub("Z$", "")) end

    -- "  42  command" (numbered history)
    cmd = line:match("^%s*%d+%s+(.*)$")
    if cmd and cmd ~= "" then return cmd, nil end

    return line, nil
end

-- Newest first, consecutive duplicates collapsed. Shell history is full
-- of the same command repeated; showing 30 identical rows would bury
-- everything else.
local function commandHistoryLoad()
    local path = commandHistoryResolvePath()
    if not path then return nil, nil end

    local f = io.open(path, "rb")
    if not f then return nil, path end
    local size = f:seek("end") or 0
    if size > COMMAND_HISTORY_MAX_BYTES then
        f:seek("set", size - COMMAND_HISTORY_MAX_BYTES)
        f:read("*l")   -- drop the partial line we landed in the middle of
    else
        f:seek("set", 0)
    end
    local content = f:read("*a") or ""
    f:close()

    local entries, lastCmd = {}, nil
    for line in content:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^#") then
            local cmd, when = commandHistoryParse(trimmed)
            cmd = cmd and cmd:match("^%s*(.-)%s*$")
            if cmd and cmd ~= "" and cmd ~= lastCmd then
                table.insert(entries, { cmd = cmd, when = when })
                lastCmd = cmd
            end
        end
    end

    -- Reverse in place: file order is oldest-first, the picker wants the
    -- newest thing you ran sitting at the top.
    for i = 1, #entries // 2 do
        entries[i], entries[#entries - i + 1] = entries[#entries - i + 1], entries[i]
    end
    return entries, path
end

_G.commandHistoryEntries = {}

local function renderCommandHistory(query)
    local q = (query or ""):lower():match("^%s*(.-)%s*$")
    local choices = {}
    for _, e in ipairs(_G.commandHistoryEntries) do
        if q == "" or e.cmd:lower():find(q, 1, true) then
            table.insert(choices, {
                text    = e.cmd:gsub("%s+", " "):sub(1, 160),
                subText = e.when or "",
                rawText = e.cmd,
            })
            if #choices >= commandHistoryMaxRows then break end
        end
    end
    if #choices == 0 then
        table.insert(choices, {
            text    = (q == "") and "No commands found"
                      or ("No matches for \"" .. q .. "\""),
            subText = "Searches every command in the log",
        })
    end
    _G.choosers.commandHistory:choices(choices)
end

_G.choosers.commandHistory = hs.chooser.new(function(c)
    if c and c.rawText then
        hs.pasteboard.setContents(c.rawText)
        hs.alert.show("📋 Copied command")
    end
end)
_G.choosers.commandHistory:placeholderText(
    "Search your shell history — Enter copies the command")
_G.choosers.commandHistory:queryChangedCallback(function(query)
    local ok, err = pcall(renderCommandHistory, query)
    if not ok then
        print("🚨 Command History render error: " .. tostring(err))
        _G.choosers.commandHistory:choices({
            { text = "⚠️ Display error — details in Hammerspoon Console",
              subText = tostring(err) },
        })
    end
end)

_G.hyperAddShortcut({}, "h", function()
    local entries, path = commandHistoryLoad()
    if not path then
        -- Say WHERE we looked. An empty picker with no explanation is
        -- the thing that makes a feature feel broken rather than
        -- misconfigured.
        print("⚠️ Command History: no log found. Looked in:")
        for _, p in ipairs(commandHistoryCandidates) do print("     " .. p) end
        print("   Set commandHistoryPath in §6.5 to the real path and reload.")
        hs.alert.show("⌨️ No command_history.log found — see Console")
        return
    end
    _G.commandHistoryEntries = entries or {}
    if #_G.commandHistoryEntries == 0 then
        print("⚠️ Command History: " .. path .. " has no parseable commands.")
    end
    renderCommandHistory("")
    _G.choosers.commandHistory:query("")
    showPopup(_G.choosers.commandHistory)
end, "command history")

_G.commandHistoryLoadForTest = commandHistoryLoad
_G.commandHistoryParseForTest = commandHistoryParse

end)() -- §6.5 Command History

-- =====================================================================
-- 6.6 APP LOCK — ⇪⇧H, a PIN gate on chosen apps
-- =====================================================================
-- ⚠️⚠️ READ THIS FIRST — WHAT THIS IS AND IS NOT ⚠️⚠️
--
-- This is a PRIVACY SCREEN, not security. It stops someone who sits
-- down at your already-unlocked Mac from casually opening Outlook. It
-- does NOT stop anyone who is actually trying, because:
--   • Quitting Hammerspoon (⌘Q, Activity Monitor, killall) removes the
--     lock entirely. Hammerspoon is an ordinary userland app.
--   • The PIN hash sits in a file your account can read. A 4-digit PIN
--     has 10,000 possibilities — brute-forceable instantly by anyone who
--     copies that file, no matter what algorithm hashes it.
--   • It cannot stop reading DATA. Locking Finder does not stop `cat`,
--     Terminal, Spotlight previews, or another file manager.
--   • There is a brief moment between an app launching and this hiding
--     it, so a window can flash on screen.
--
-- FOR REAL, OS-ENFORCED APP LOCKING use macOS Screen Time → Content &
-- Privacy Restrictions, which enforces a passcode at the system level.
-- For protecting DATA at rest, use FileVault. This feature is worth
-- having for the casual case; just don't mistake it for those.
--
-- HOW TO GET BACK IN IF SOMETHING GOES WRONG (read before enabling):
--   • Delete ~/.hammerspoon/applock.json — that removes the PIN and
--     every lock. Nothing else is affected.
--   • Or set appLockEnabled = false below and reload.
--   • Hammerspoon itself can NEVER be locked (enforced in code), so the
--     Console is always reachable.
--
-- HOW IT WORKS: an app watcher notices a locked app launching or coming
-- to the front, hides it immediately, and asks for the PIN. Right PIN =
-- unhidden and unlocked for a grace period. The prompt runs as a
-- separate osascript process so it NEVER blocks Hammerspoon's main
-- thread — a modal dialog on the main thread would be a guaranteed
-- beachball if you walked away from it.
;(function()

-- ✏️ EDIT THESE ------------------------------------------------------
local appLockEnabled = true

-- Which apps to lock. Deliberately EMPTY by default: this only seeds
-- the list the very first time, and nothing should start locking itself
-- just because you installed a new init.lua. Add apps from the ⇪⇧H
-- manager instead — it writes them to applock.json.
local appLockSeedApps = {}

-- NO TIME LIMIT (6.22.0). Unlocking with the PIN keeps an app open until
-- YOU lock it again from ⇪⇧H. 6.21 expired the unlock after 15 minutes,
-- which was never asked for and made the whole thing feel random.
-- The one thing that is not under your control: unlocks live in memory
-- only, so restarting Hammerspoon (or the Mac) re-locks everything. That
-- is deliberate — an unlock surviving a reboot would defeat the point.
--
-- Optional: set this to true if you also want everything re-locked when
-- the screen locks or the Mac sleeps. OFF by default — you asked for
-- manual lock/unlock and nothing automatic.
-- 6.29.0 — COVER INSTEAD OF HIDE.
-- Hiding a locked app forces macOS to hand focus to something else,
-- which on a multi-monitor setup drags your view to the other screen and
-- back: the "bounce". No amount of patching fixes that, because hiding
-- IS the bounce. In cover mode the app is left exactly where it is and
-- an opaque panel is painted over its screen instead. Nothing is hidden,
-- so focus never moves, so there is nothing to bounce.
--
-- Set this to false to go back to the old hide-based behaviour.
local appLockUseCover = true

-- After the cover is up, ALSO hide the locked app and bring Finder
-- forward. The cover goes on first, so the hide happens behind it and
-- you never see the window disappear.
--
-- 6.30.0 — NOW OFF BY DEFAULT. The overlay alone is the whole feature:
-- hiding is what moves focus, and moving focus is what caused the
-- monitor-to-monitor bounce. With this false the locked app is left
-- exactly where it sits, an opaque panel is painted over its screen,
-- and NOTHING is hidden and NO focus is moved — so there is nothing to
-- bounce. Set it back to true to restore the old cover-then-hide.
--
-- The one place hiding still happens is a CANCELLED or FAILED PIN (see
-- the challenge flow): the cover has to come down at that point, and
-- concealment has to win over smoothness, so the app is hidden then.
local appLockCoverThenHide = false

-- Canvas level for the cover. MUST stay below hs.canvas.windowLevels
-- .popUpMenu (101), which is where the PIN chooser draws — see the
-- 6.30.0 note in appLockShowCovers. `floating` is above every normal
-- app window and below the prompt, which is exactly the window we want.
APPLOCK_COVER_LEVEL = hs.canvas.windowLevels.floating
local appLockFallbackApp   = "Finder"

local appLockRelockOnScreenLock = false

local appLockMaxAttempts    = 5   -- wrong PINs before a cooldown
local appLockLockoutMinutes = 5   -- how long that cooldown lasts

-- Never lockable. Locking Hammerspoon would make the escape hatch
-- itself unreachable, which is how a convenience feature turns into
-- being locked out of your own Mac.
local appLockNeverLock = { ["Hammerspoon"] = true }

-- ---- storage (LOCAL ONLY — never OneDrive, never backed up) --------
local appLockFile = hs.configdir .. "/applock.json"

local function appLockLoad()
    local f = io.open(appLockFile, "r")
    if not f then return { apps = {} } end
    local content = f:read("*a"); f:close()
    local ok, data = pcall(hs.json.decode, content)
    if ok and type(data) == "table" then
        data.apps = data.apps or {}
        return data
    end
    return { apps = {} }
end

local function appLockSave(data)
    local f = io.open(appLockFile, "w")
    if not f then
        print("🚨 App Lock: could not write " .. appLockFile)
        hs.alert.show("⚠️ App Lock: couldn't save settings")
        return false
    end
    f:write(hs.json.encode(data)); f:close()
    return true
end

local appLockData = appLockLoad()

-- ⚠️ 6.26.0 — THE SETTING THAT DECIDES HOW THIS FEELS.
-- false: a PIN unlocks the app until you re-lock it from ⇪⇧H. That is
--        what "no time limits" asked for literally, but in practice it
--        means the lock fires ONCE and then never again — which reads as
--        the feature degrading or breaking.
-- true:  switching AWAY from the app re-locks it, so coming back always
--        asks for the PIN. Not a timer — nothing expires while you are
--        using it. It just locks when you leave, like a screen lock.
-- Persisted in applock.json and toggleable from ⇪⇧H, so you can try both
-- without editing this file.
local function appLockRelockOnLeave()
    return appLockData.relockOnDeactivate == true
end
if next(appLockData.apps) == nil and #appLockSeedApps > 0 then
    for _, n in ipairs(appLockSeedApps) do appLockData.apps[n] = true end
    appLockSave(appLockData)
end

-- ---- PIN hashing ----------------------------------------------------
-- Salted SHA256. To be clear about what this buys: it stops someone
-- casually reading your PIN out of the file. It does NOT withstand a
-- brute force — 4 digits is 10,000 tries. Verified real API:
-- hs.hash.SHA256(string) -> hex, from extensions/hash/hash.lua.
local function appLockHash(pin, salt)
    return hs.hash.SHA256(tostring(salt) .. ":" .. tostring(pin))
end

local function appLockNewSalt()
    return tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
end

local function appLockHasPin()
    return appLockData.hash ~= nil and appLockData.salt ~= nil
end

local function appLockCheckPin(pin)
    if not appLockHasPin() then return false end
    return appLockHash(pin, appLockData.salt) == appLockData.hash
end

-- ---- state ----------------------------------------------------------
local unlocked      = {}   -- appName -> true while PIN-unlocked (no expiry)
local appLockHideAllLocked  -- forward declaration (used by the manager below)
local failedCount   = {}   -- appName -> consecutive wrong PINs
local lockoutUntil  = {}   -- appName -> epoch seconds
local promptOpen    = false
_G.appLockTasks     = {}   -- in-flight osascript tasks, held against GC

local function appLockIsLocked(name)
    if not appLockEnabled or not name then return false end
    if appLockNeverLock[name] then return false end
    return appLockData.apps[name] == true
end

local function appLockIsUnlocked(name)
    return unlocked[name] == true
end

-- ⚠️ 6.30.0 — OUR OWN UI MUST NOT COUNT AS "YOU SWITCHED AWAY".
-- Showing the manager or the PIN prompt takes keyboard focus, which
-- makes macOS fire `deactivated` for whatever app you were in. With
-- re-lock-on-leave ON that silently re-locked the very app you had just
-- unlocked — so the list you were looking at went stale the instant it
-- opened, and the app you believed was unlocked asked for a PIN again.
-- That is the "I can still unlock an app that is already unlocked"
-- confusion. A short grace window is enough: it only ever suppresses
-- the relock that OUR OWN popup caused.
local appLockOwnUIUntil = 0
local function appLockOwnUIActive() return os.time() < appLockOwnUIUntil end
local function appLockOwnUIOpening() appLockOwnUIUntil = os.time() + 2 end

-- ---- hiding, and the feedback loop it used to cause ------------------
-- ⚠️ 6.24.0 — READ BEFORE CHANGING ANY OF THIS.
-- Hiding an app CHANGES FOCUS, and a focus change fires another
-- `activated` event. Showing the PIN chooser changes focus again, and
-- CLOSING it hands focus straight back to the app we just hid. That is a
-- closed loop: hide -> focus moves -> activated -> hide -> …
--
-- In 6.23 that loop ran flat out. Holding ⌘-Tab fires activation events
-- in a stream, so the screen strobed between the app and Hammerspoon —
-- genuinely unpleasant, and the churn pinned the main thread long enough
-- to beachball for ~5 seconds. Both symptoms, one cause.
--
-- Damping, in order of importance:
--   1. A per-app COOLDOWN. After we act on an app we ignore its events
--      for a couple of seconds, which is what stops ⌘-Tab strobing and
--      stops the chooser reopening the instant it closes.
--   2. While a PIN prompt is open we do nothing at all — not even hide.
--      The app is already hidden; touching it again only moves focus.
--   3. The 0.15s "hide again in case it bounced back" retry from 6.22 is
--      GONE. It was guarding a race I never actually confirmed, and it
--      was the engine driving the strobe. Speculative complexity that
--      causes a real seizure risk is not a trade worth making.
local appLockCooldown = {}   -- appName -> os.time() until which we ignore it
local APPLOCK_COOLDOWN_SECS = 2

-- ✏️ Set false once you're happy with it. On by default because every
-- App Lock bug so far has been invisible in the Console — the feature
-- would just quietly stop working and there was nothing to read. This
-- only prints for apps that are actually locked, so it is not chatty.
local appLockDebug = true
local appLockPromptCount = 0

local function appLockLog(name, msg)
    if appLockDebug then
        print("🔒 App Lock [" .. tostring(name) .. "] " .. msg)
    end
end

local function appLockCoolingDown(name)
    local until_ = appLockCooldown[name]
    return until_ ~= nil and os.time() < until_
end

local function appLockStartCooldown(name)
    appLockCooldown[name] = os.time() + APPLOCK_COOLDOWN_SECS
end

-- ⚠️ 6.25.0 — WHY A VERIFY STEP EXISTS AGAIN.
-- Clicking a hidden app's Dock icon makes macOS unhide AND activate it.
-- Our hide() lands in the middle of that, and macOS finishes unhiding
-- afterwards — so the app ends up VISIBLE with the PIN prompt floating
-- over it, document and all. That is the race 6.22's retry was guarding;
-- 6.24.0 deleted it to stop the strobe without replacing what it did.
--
-- The difference from 6.22: that one fired a timer on EVERY activation
-- event, so a ⌘-Tab burst queued dozens of re-hides — the strobe. This
-- fires ONCE per challenge, behind promptOpen, and re-checks before
-- acting. One timer, not a stream.
_G.appLockVerifyTimers = {}

-- 6.25.1: POLL, don't take one look 150ms later.
-- A single check at 0.15s meant a Dock-launched app was on screen for
-- that whole 150ms — the visible flash. This checks every 30ms instead,
-- hides again the moment it sees the window, and only continues once the
-- app has stayed hidden for a few consecutive checks. macOS can finish
-- its unhide AFTER our first check, so "hidden once" is not enough —
-- that is the bug the single check had.
--
-- Still bounded and still ONE poll per challenge (behind promptOpen), so
-- it cannot become 6.22's per-event timer storm.
local APPLOCK_VERIFY_INTERVAL = 0.03
local APPLOCK_VERIFY_SETTLED  = 3     -- consecutive hidden checks required
local APPLOCK_VERIFY_MAX      = 20    -- ~0.6s ceiling, then give up and prompt

local function appLockVerifyHidden(app, name, unlockedRef, whenDone)
    local attempts, settled, warned = 0, 0, false
    local function tick()
        attempts = attempts + 1
        if unlockedRef() then
            if whenDone then whenDone() end
            return
        end
        local visible = false
        pcall(function() visible = (app:isHidden() == false) end)
        if visible then
            settled = 0
            if not warned then
                warned = true
                appLockLog(name, "macOS re-showed it after our hide — hiding again")
            end
            pcall(function() app:hide() end)
        else
            settled = settled + 1
        end
        if settled >= APPLOCK_VERIFY_SETTLED or attempts >= APPLOCK_VERIFY_MAX then
            if attempts >= APPLOCK_VERIFY_MAX and visible then
                appLockLog(name, "could not keep it hidden after "
                    .. attempts .. " tries — prompting anyway")
            end
            if whenDone then whenDone() end
            return
        end
        local t
        t = hs.timer.doAfter(APPLOCK_VERIFY_INTERVAL, function()
            for i, x in ipairs(_G.appLockVerifyTimers) do
                if x == t then table.remove(_G.appLockVerifyTimers, i); break end
            end
            tick()
        end)
        table.insert(_G.appLockVerifyTimers, t)
    end
    local first
    first = hs.timer.doAfter(APPLOCK_VERIFY_INTERVAL, function()
        for i, x in ipairs(_G.appLockVerifyTimers) do
            if x == first then table.remove(_G.appLockVerifyTimers, i); break end
        end
        tick()
    end)
    table.insert(_G.appLockVerifyTimers, first)
end

-- Remember which screen the app was on BEFORE it disappears — once it
-- is hidden it has no window and no screen to ask about.
local function appLockRememberScreen(app)
    local ok, win = pcall(function() return app:focusedWindow() or app:mainWindow() end)
    if ok and win then
        local ok2, scr = pcall(function() return win:screen() end)
        if ok2 and scr then return scr end
    end
    return nil
end

local function appLockHideObject(app, name)
    if not app then return false end
    local ok, err = pcall(function() app:hide() end)
    if not ok then
        print("🚨 App Lock: could not hide " .. tostring(name) .. ": " .. tostring(err))
        return false
    end
    return true
end

-- ---- the cover ------------------------------------------------------
-- ⚠️ SAFETY FIRST. An opaque panel that will not clear is worse than any
-- bug in this file so far, so there are FOUR independent ways out:
--   1. Enter the PIN — the normal path.
--   2. ⌘⇧⌃⌥K (or ⇪K) — panic key, clears every cover instantly. It is a
--      GLOBAL hotkey, so it works even if the hyper modal is confused.
--   3. A watchdog every 3s clears any cover with no PIN prompt behind it.
--   4. Quit Hammerspoon. The panel is drawn BY Hammerspoon, so it dies
--      with it. Nothing can survive that, by construction.
_G.appLockCovers = {}

local function appLockRemoveCovers()
    if #_G.appLockCovers == 0 then return false end
    for _, c in ipairs(_G.appLockCovers) do
        pcall(function() c:delete() end)
    end
    _G.appLockCovers = {}
    return true
end

-- Only the screens this app actually occupies get covered. Blacking out
-- every monitor to conceal one window would be its own kind of hostile.
local function appLockScreensFor(app)
    local out, seen = {}, {}
    local ok, wins = pcall(function() return app:allWindows() end)
    if ok and wins then
        for _, w in ipairs(wins) do
            local ok2, scr = pcall(function() return w:screen() end)
            if ok2 and scr then
                local okF, f = pcall(function() return scr:frame() end)
                if okF and f then
                    local key = tostring(f.x) .. "," .. tostring(f.y)
                    if not seen[key] then seen[key] = true; table.insert(out, scr) end
                end
            end
        end
    end
    if #out == 0 then
        local okS, scr = pcall(hs.screen.mainScreen)
        if okS and scr then table.insert(out, scr) end
    end
    return out
end

local function appLockShowCovers(app, name)
    appLockRemoveCovers()
    for _, scr in ipairs(appLockScreensFor(app)) do
        local okF, f = pcall(function() return scr:frame() end)
        if okF and f then
            local ok, c = pcall(function() return hs.canvas.new(f) end)
            if ok and c then
                pcall(function()
                    c:appendElements(
                        { type = "rectangle", action = "fill",
                          fillColor = { red = 0.04, green = 0.05, blue = 0.07, alpha = 0.97 } },
                        { type = "text", text = "🔒 " .. tostring(name) .. " is locked",
                          textSize = 34, textColor = { white = 1, alpha = 0.92 },
                          textAlignment = "center",
                          frame = { x = 0, y = f.h * 0.42, w = f.w, h = 50 } },
                        { type = "text",
                          text = "Enter your PIN   ·   ⌘⇧⌃⌥K clears this if anything goes wrong",
                          textSize = 15, textColor = { white = 1, alpha = 0.55 },
                          textAlignment = "center",
                          frame = { x = 0, y = f.h * 0.42 + 56, w = f.w, h = 30 } })
                end)
                -- ⚠️ 6.30.0 — THE COVER WAS BURYING THE PIN PROMPT.
                -- This used to say `overlay`, which is level 102. An
                -- hs.chooser panel sits at popUpMenu, level 101. So the
                -- cover was painted ON TOP OF the prompt: the panel was
                -- there and focused, you simply could not see it. That
                -- is why the only way through was the panic key, and
                -- why entering the PIN worked immediately afterwards.
                -- `floating` (3) is still above every ordinary app
                -- window, so the locked app stays concealed, but is
                -- comfortably below the chooser.
                pcall(function() c:level(APPLOCK_COVER_LEVEL) end)
                pcall(function() c:show() end)
                table.insert(_G.appLockCovers, c)
            end
        end
    end
    if #_G.appLockCovers > 0 then
        appLockLog(name, "covered " .. #_G.appLockCovers .. " screen(s) — no hide, so no focus bounce")
        return true
    end
    appLockLog(name, "could not paint a cover — falling back to hiding")
    return false
end

local function appLockFocusFallback()
    if not appLockFallbackApp or appLockFallbackApp == "" then return end
    pcall(function() hs.application.launchOrFocus(appLockFallbackApp) end)
end

-- Find a running app BY NAME and hide it. One bulk enumeration rather
-- than hs.application.get(), which §3.7 proved returns stale results.
local function appLockHideApp(name)
    local okList, apps = pcall(hs.application.runningApplications)
    if not okList or not apps then return false end
    local hid = false
    for _, a in ipairs(apps) do
        local okName, n = pcall(function() return a:name() end)
        if okName and n == name then
            if appLockHideObject(a, name) then hid = true end
        end
    end
    return hid
end

-- Used by "Re-lock everything now" and the optional screen-lock hook.
appLockHideAllLocked = function()
    local count = 0
    local okList, apps = pcall(hs.application.runningApplications)
    if not okList or not apps then return 0 end
    for _, a in ipairs(apps) do
        local okName, n = pcall(function() return a:name() end)
        if okName and n and appLockData.apps[n] and not appLockNeverLock[n] then
            if appLockHideObject(a, n) then count = count + 1 end
        end
    end
    return count
end

-- ---- the PIN prompt (hs.chooser, on your active screen) -------------
-- 6.23.0 REPLACED an osascript `display dialog` with this. That dialog
-- was the wrong tool three ways at once, all from the same cause:
-- osascript is a command-line process, not an app.
--   • It could not take keyboard focus, so you had to click it.
--   • ⌘-Tab could not reach it — it has no Dock presence.
--   • Window tools (Scoot and friends) could not see or target it.
--   • It appeared wherever macOS felt like, ignoring your active monitor.
-- A chooser fixes all four for free: showPopup() already places it on the
-- screen you are working on, and it takes focus the moment it opens, so
-- you can just start typing the PIN.
--
-- MASKING: a chooser's query field shows plain text, which would defeat
-- the point. So the real digits are kept in a buffer and the field is
-- rewritten to bullets on every keystroke. pinSettingQuery guards the
-- rewrite: if :query() were ever to re-fire queryChangedCallback we would
-- recurse forever and hang Hammerspoon, so this does NOT depend on
-- assuming it doesn't.
-- ⚠️ "•" is THREE BYTES in UTF-8, and Lua's # counts BYTES. Comparing
-- #query against #pinBuffer directly therefore compares bullets-in-bytes
-- against digits-in-characters, and reconstructs the PIN as garbage
-- ("1<junk>2<junk>3"). All the length maths below is in BYTES, via
-- PIN_MASK_LEN. Swap PIN_MASK for "*" and it still works — that is the
-- point of deriving the width instead of hard-coding 1.
local PIN_MASK      = "•"
local PIN_MASK_LEN  = #PIN_MASK
local pinBuffer      = ""
local pinCallback    = nil
local pinSettingQuery = false

local function appLockPinRender()
    local dots = string.rep(PIN_MASK, #pinBuffer)
    _G.choosers.appLockPin:choices({
        {
            text    = (#pinBuffer > 0) and dots or "Type your PIN…",
            subText = (#pinBuffer > 0) and "Press Enter to submit  ·  Esc cancels"
                      or "Esc cancels",
        },
    })
end

_G.choosers.appLockPin = hs.chooser.new(function(c)
    local pin = pinBuffer
    local cb  = pinCallback
    pinBuffer, pinCallback = "", nil
    if cb then
        -- c == nil means dismissed with Esc / click-away = cancel.
        cb((c ~= nil and pin ~= "") and pin or nil)
    end
end)

_G.choosers.appLockPin:queryChangedCallback(function(q)
    if pinSettingQuery then return end
    q = q or ""
    -- The field currently holds exactly #pinBuffer mask glyphs, so this
    -- many BYTES of it are mask, and anything beyond that is new input.
    local maskBytes = #pinBuffer * PIN_MASK_LEN
    if #q > maskBytes then
        pinBuffer = pinBuffer .. q:sub(maskBytes + 1)
    elseif #q < maskBytes then
        -- Backspace removes whole glyphs, so byte count / glyph width
        -- gives the number of characters left.
        pinBuffer = pinBuffer:sub(1, math.floor(#q / PIN_MASK_LEN))
    end
    pinSettingQuery = true
    _G.choosers.appLockPin:query(string.rep(PIN_MASK, #pinBuffer))
    pinSettingQuery = false
    appLockPinRender()
end)

-- SAFETY NET. If the chooser ever disappears without its completion
-- callback running, pinCallback and promptOpen stay set forever — and
-- the watcher's `if promptOpen then return end` means App Lock silently
-- stops working until you reload Hammerspoon. That failure is invisible,
-- which is the worst kind. hideCallback fires whenever the chooser goes
-- away for ANY reason, so this checks shortly after and cleans up if the
-- completion never ran. The delay lets the normal path win the race.
_G.appLockPinHideTimer = nil
_G.choosers.appLockPin:hideCallback(function()
    _G.appLockPinHideTimer = hs.timer.doAfter(0.3, function()
        if pinCallback then
            local cb = pinCallback
            pinBuffer, pinCallback = "", nil
            print("⚠️ App Lock: the PIN prompt closed without reporting — recovering")
            cb(nil)
        end
    end)
end)

local function appLockAskPin(title, message, callback)
    if pinCallback then return end   -- one prompt at a time
    appLockOwnUIOpening()            -- our focus grab is not "switching away"
    pinBuffer   = ""
    pinCallback = callback
    _G.choosers.appLockPin:placeholderText(message)
    pinSettingQuery = true
    _G.choosers.appLockPin:query("")
    pinSettingQuery = false
    appLockPinRender()
    showPopup(_G.choosers.appLockPin)
    -- Cleared immediately: the override exists only to place THIS popup.
    -- Leaving it set would pin every other picker in the config to
    -- whatever screen App Lock last used.
    _G.popupScreenOverride = nil
end
-- ---- challenge flow -------------------------------------------------
local function appLockChallenge(name, app, screenHint)
    if promptOpen then return end

    local lo = lockoutUntil[name]
    if lo and os.time() < lo then
        local mins = math.ceil((lo - os.time()) / 60)
        hs.alert.show("🔒 " .. name .. " locked out — try again in " .. mins .. " min")
        appLockStartCooldown(name)   -- don't re-alert on every focus event
        return
    end

    -- Set BEFORE the verify timer, so events arriving in that window are
    -- ignored rather than starting a second challenge.
    promptOpen = true
    appLockPromptCount = appLockPromptCount + 1
    local left = appLockMaxAttempts - (failedCount[name] or 0)

    -- ⚠️ 6.28.2 — THIS MUST BE CAPTURED BEFORE THE APP IS HIDDEN.
    -- 6.27.1 captured it HERE, but the watcher hides the app before
    -- calling this function, and a hidden app has NO focused window — so
    -- appLockRememberScreen returned nil, no override was set, and the
    -- prompt kept following the focus bounce to the wrong monitor. The
    -- caller now captures it while the app is still on screen and passes
    -- it in; the call below is only a fallback for paths that don't.
    local promptScreen = screenHint or appLockRememberScreen(app)

    -- Let the hide settle (and undo any macOS unhide race) BEFORE the
    -- prompt appears, so the app's window is never sitting visible
    -- behind it. That leak is the whole thing this feature exists to
    -- prevent, so it is worth the 0.15s.
    --
    -- ⚠️ 6.30.0 — SKIP ALL OF THAT IN COVER-ONLY MODE. appLockVerifyHidden
    -- does not just observe: when it sees the app un-hidden it CALLS
    -- app:hide(). In cover-only mode the app is deliberately never
    -- hidden, so the verifier would have hidden it right back and
    -- silently undone the whole point of the setting. There is also
    -- nothing to verify — concealment there is the cover, and the cover
    -- is already up by the time we get here.
    local coverOnly = appLockUseCover and not appLockCoverThenHide
    local function appLockShowPrompt()
    appLockLog(name, coverOnly and "covered — showing PIN prompt"
                               or  "hidden — showing PIN prompt")
    _G.popupScreenOverride = promptScreen
    appLockAskPin("App Lock",
        "Enter your PIN to open " .. name ..
        ((left < appLockMaxAttempts) and ("\n(" .. left .. " attempts left)") or ""),
        function(pin)
            promptOpen = false
            _G.popupScreenOverride = nil   -- belt and braces
            -- Cooldown starts when the prompt CLOSES: the focus-return
            -- event lands right now, and that is the thing to absorb.
            appLockStartCooldown(name)
            appLockLog(name, pin and "PIN submitted" or "prompt cancelled")
            if pin and appLockCheckPin(pin) then
                failedCount[name] = 0
                unlocked[name] = true
                -- Restore the app BEFORE lifting the cover, so the
                -- window is already back when the panel goes away.
                pcall(function() app:unhide() end)
                pcall(function() app:activate() end)
                appLockRemoveCovers()
                hs.alert.show("🔓 " .. name .. " unlocked — stays open until you lock it")
            elseif pin then
                failedCount[name] = (failedCount[name] or 0) + 1
                if failedCount[name] >= appLockMaxAttempts then
                    lockoutUntil[name] = os.time() + appLockLockoutMinutes * 60
                    failedCount[name] = 0
                    hs.alert.show("🔒 Too many wrong PINs — " .. name ..
                        " locked out for " .. appLockLockoutMinutes .. " min")
                    print("🔒 App Lock: " .. name .. " hit the attempt limit")
                else
                    hs.alert.show("❌ Wrong PIN")
                end
            end
            -- ANY outcome that is not a successful unlock must leave the
            -- app off screen. Escape used to just close the prompt — and
            -- if the unhide race had left the app visible, you walked
            -- straight into it without a PIN.
            if not (pin and appLockCheckPin(pin)) then
                -- Wrong PIN or cancelled: the app must stay concealed,
                -- but the cover must come DOWN or you are left staring
                -- at an opaque panel with no prompt behind it.
                --
                -- 6.30.0: this is the ONE place cover-only mode still
                -- hides. Once the prompt is gone the cover cannot stay
                -- (the watchdog would clear it seconds later anyway),
                -- and an app left visible with no PIN entered is the
                -- exact leak this feature exists to prevent. So on a
                -- cancel or a wrong PIN, concealment wins over
                -- smoothness and the app is hidden.
                appLockHideObject(app, name)
                appLockRemoveCovers()
                appLockVerifyHidden(app, name, function() return unlocked[name] end, nil)
            end
        end)
    end   -- end appLockShowPrompt

    if coverOnly then
        -- Nothing was hidden, so there is nothing to wait for.
        appLockShowPrompt()
    else
        appLockVerifyHidden(app, name, function() return unlocked[name] end,
                            appLockShowPrompt)
    end
end

-- ---- the watcher ----------------------------------------------------
-- Cheap on purpose: `activated` fires constantly as you move between
-- apps, so the hot path is a handful of table lookups and nothing else.
-- Same discipline that fixed the §3.7 boot beachball.
--
-- ORDER MATTERS HERE. Every early return below happens BEFORE anything
-- that could change focus, because changing focus is what generates the
-- next event. Acting first and checking later is precisely what made
-- 6.23 strobe.
if appLockEnabled then
    _G.appLockWatcher = hs.application.watcher.new(function(name, event, app)
        -- Leaving an unlocked app re-locks it, when you have asked for
        -- that. Deliberately event-driven, not a timer: nothing expires
        -- while you are sitting in the app.
        if event == hs.application.watcher.deactivated then
            -- A cover must not outlive the app being frontmost — but NOT
            -- while we are the reason it stopped being frontmost.
            -- 6.29.0 tore the cover down here unconditionally, and since
            -- covering is immediately followed by hiding the app and
            -- focusing Finder, macOS fires `deactivated` for the locked
            -- app straight away. The cover was being destroyed about a
            -- frame after it was painted — cover mode was really just
            -- hide mode with an extra step.
            -- promptOpen means a challenge is in flight and the cover is
            -- doing its job; the watchdog still clears it if the prompt
            -- ever goes away without cleaning up.
            if not promptOpen then
                appLockRemoveCovers()
            end
            if appLockRelockOnLeave() and appLockIsLocked(name)
               and appLockIsUnlocked(name) and not appLockOwnUIActive() then
                unlocked[name] = nil
                appLockLog(name, "you switched away — re-locked")
                if app then appLockHideObject(app, name) end
            end
            return
        end
        if event ~= hs.application.watcher.launched
           and event ~= hs.application.watcher.activated then
            return
        end
        if not appLockIsLocked(name) then return end
        if appLockIsUnlocked(name) then return end
        -- A prompt is already up: the app is hidden and waiting on a PIN.
        -- Hiding it again here only bounces focus and restarts the loop.
        if promptOpen then
            appLockLog(name, "ignored — a PIN prompt is already open")
            return
        end
        if not appLockHasPin() then
            -- Locked apps but no PIN set would mean an app you can never
            -- open. Fail OPEN and say so, rather than trapping you.
            print("⚠️ App Lock: " .. name .. " is marked locked but no PIN is set — allowing it. Set one with ⇪⇧H.")
            return
        end
        if app then
            -- ⚠️ 6.24.1 — HIDE ALWAYS, PROMPT SOMETIMES.
            -- 6.24.0 put the cooldown check ABOVE this, so during the
            -- cooldown the whole handler bailed out — and a locked app
            -- clicked in the Dock within those 2 seconds came back on
            -- screen with NO PIN AT ALL. That is the "works one time,
            -- then it isn't reliable" you hit, and it was a real hole.
            --
            -- Hiding was never what looped. Hiding moves focus to some
            -- OTHER app, and that app isn't locked, so nothing re-fires.
            -- The loop was the PROMPT: chooser closes -> focus returns
            -- here -> prompt reopens. So the cooldown now gates only the
            -- prompt. The app can never be left visible.
            -- Screen FIRST — once the app is hidden or covered we can no
            -- longer ask it which monitor it was on.
            local screenHint = appLockRememberScreen(app)

            if appLockUseCover then
                -- Cover, THEN hide behind the cover, THEN send focus
                -- somewhere predictable. Order matters: covering first
                -- means the window is already concealed when it
                -- disappears, so there is no flash, and focus lands on
                -- Finder rather than on whatever macOS picks.
                local covered = appLockShowCovers(app, name)
                if appLockCoverThenHide or not covered then
                    appLockHideObject(app, name)
                    appLockFocusFallback()
                end
            else
                appLockHideObject(app, name)
            end

            if appLockCoolingDown(name) then
                appLockLog(name, "concealed; prompt suppressed (cooldown) — try again")
                return
            end
            appLockChallenge(name, app, screenHint)
        end
    end)
    _G.appLockWatcher:start()

    -- Re-lock everything the moment the screen locks or the Mac sleeps —
    -- otherwise a 15-minute grace period would outlive you walking away.
    if appLockRelockOnScreenLock then
        _G.appLockCaffeinateWatcher = hs.caffeinate.watcher.new(function(ev)
            if ev == hs.caffeinate.watcher.screensDidLock
               or ev == hs.caffeinate.watcher.systemWillSleep then
                unlocked = {}
                appLockHideAllLocked()
            end
        end)
        _G.appLockCaffeinateWatcher:start()
    end
end

-- ---- manager UI (⇪⇧H) ----------------------------------------------
-- 6.23.0 rewrote what Enter DOES, because the old behaviour produced a
-- baffling lock/unlock/lock rhythm. Every protected app had one row and
-- Enter always meant "remove from the protected list" — so right after
-- unlocking with your PIN, the natural "lock it again" keypress silently
-- STOPPED protecting the app instead. You then had to add it back (2nd
-- press) and it locked (3rd). Enter now flips the thing you are looking
-- at: locked <-> unlocked. Un-protecting is a separate, deliberate mode.
local appLockManagerMode = "main"   -- "main" | "remove"

-- ✏️ Where your real applications live. An app must sit under one of
-- these to be offered for locking. Add a folder if you keep apps
-- somewhere unusual.
local appLockAppRoots = {
    "/Applications/",         -- includes /Applications/Utilities/
    "/System/Applications/",  -- Apple's own apps (TextEdit, Notes, ...)
    (os.getenv("HOME") or "") .. "/Applications/",
}

-- 6.27.0: this used to list every running PROCESS, so the picker filled
-- with loginwindow, photolibraryd, universalaccessd, siriactionsd,
-- nbagent, printtool and friends -- none of them lockable, and they
-- buried the handful of real apps.
--
-- Two filters, both needed:
--   * kind() == 1 -- the app has a Dock icon. Verified against
--     Hammerspoon source: 1 = in the Dock, 0 = not, -1 = prohibited from
--     having any GUI. This alone removes every background daemon.
--   * path under an Applications folder -- catches helper apps bundled
--     INSIDE another app (.../Foo.app/Contents/.../Bar.app), which can
--     still report a Dock icon.
local function appLockIsRealApp(a)
    local okKind, kind = pcall(function() return a:kind() end)
    if not okKind or kind ~= 1 then return false end
    local okPath, path = pcall(function() return a:path() end)
    if not okPath or not path then return false end
    -- A real app's path contains exactly one ".app"; a helper buried
    -- inside another bundle contains two or more.
    local _, dotApps = path:gsub("%.app", "")
    if dotApps > 1 then return false end
    for _, root in ipairs(appLockAppRoots) do
        if root ~= "/" and path:sub(1, #root) == root then return true end
    end
    return false
end

local function appLockRunningNames()
    local names, seen = {}, {}
    local okList, apps = pcall(hs.application.runningApplications)
    if okList and apps then
        for _, a in ipairs(apps) do
            local okName, n = pcall(function() return a:name() end)
            if okName and n and not seen[n] and not appLockNeverLock[n]
               and appLockIsRealApp(a) then
                seen[n] = true
                table.insert(names, n)
            end
        end
    end
    table.sort(names)
    return names
end

local function appLockRenderManager()
    local choices = {}
    local protected = {}
    for n in pairs(appLockData.apps) do table.insert(protected, n) end
    table.sort(protected)

    if appLockManagerMode == "remove" then
        table.insert(choices, {
            text = "← Back", subText = "Return to the main list", action = "back",
        })
        for _, n in ipairs(protected) do
            table.insert(choices, {
                text    = "🗑 Stop protecting " .. n,
                subText = "Asks for your PIN — after this, " .. n .. " opens freely",
                action  = "unprotect", app = n,
            })
        end
        if #protected == 0 then
            table.insert(choices, {
                text = "Nothing is protected yet", subText = "Add an app from the main list",
            })
        end
        _G.choosers.appLock:choices(choices)
        return
    end

    -- First, because at the bottom of a long list it was invisible.
    -- Safe as the default row: it only opens the removal list, and
    -- removing anything still requires the PIN.
    if #protected > 0 then
        table.insert(choices, {
            text = "⚙️ Stop protecting an app...",
            subText = "Removes it from App Lock entirely (asks for your PIN)",
            action = "removemode",
        })
    end
    table.insert(choices, {
        text    = appLockHasPin() and "🔑 Change PIN" or "🔑 Set a PIN (required before locking works)",
        subText = appLockHasPin() and "Asks for your current PIN first"
                  or "Nothing is locked until a PIN exists",
        action  = "pin",
    })
    table.insert(choices, {
        text = "🔒 Lock everything now", subText = "Hides every protected app immediately",
        action = "relock",
    })
    table.insert(choices, {
        text    = appLockRelockOnLeave()
                  and "🔁 Re-lock when I switch away: ON"
                  or  "🔁 Re-lock when I switch away: OFF",
        subText = appLockRelockOnLeave()
                  and "Leaving a protected app locks it again — Enter turns this off"
                  or  "Right now a PIN unlocks it until you re-lock by hand — Enter turns this on",
        action  = "toggleRelockOnLeave",
    })

    -- Protected apps: Enter flips lock state. This is the row you reach
    -- for 95% of the time, so it gets the plain Enter.
    for _, n in ipairs(protected) do
        if appLockIsUnlocked(n) then
            table.insert(choices, {
                text = "🔓 " .. n, subText = "UNLOCKED · Enter locks it now",
                action = "lock", app = n,
            })
        else
            table.insert(choices, {
                text = "🔒 " .. n, subText = "LOCKED · Enter asks for your PIN and unlocks",
                action = "unlock", app = n,
            })
        end
    end

    -- Running apps not protected yet.
    for _, n in ipairs(appLockRunningNames()) do
        if not appLockData.apps[n] then
            table.insert(choices, {
                text = "○ " .. n, subText = "Not protected · Enter protects and locks it",
                action = "protect", app = n,
            })
        end
    end

    _G.choosers.appLock:choices(choices)
end

local function appLockReopenManager()
    appLockOwnUIOpening()   -- opening this must not re-lock what it lists
    appLockRenderManager()
    _G.choosers.appLock:query("")
    showPopup(_G.choosers.appLock)
end

_G.choosers.appLock = hs.chooser.new(function(c)
    if not c or not c.action then return end
    local name = c.app

    if c.action == "back" then
        appLockManagerMode = "main"
        appLockReopenManager()

    elseif c.action == "removemode" then
        appLockManagerMode = "remove"
        appLockReopenManager()

    elseif c.action == "toggleRelockOnLeave" then
        appLockData.relockOnDeactivate = not appLockRelockOnLeave()
        appLockSave(appLockData)
        hs.alert.show(appLockRelockOnLeave()
            and "🔁 Protected apps will re-lock when you switch away"
            or  "🔁 A PIN now unlocks until you re-lock by hand")

    elseif c.action == "relock" then
        unlocked = {}
        local n = appLockHideAllLocked()
        hs.alert.show("🔒 Re-locked and hid " .. n .. " app" .. ((n == 1) and "" or "s"))

    elseif c.action == "protect" then
        if not appLockHasPin() then
            hs.alert.show("🔑 Set a PIN first")
            return
        end
        appLockData.apps[name] = true
        unlocked[name] = nil
        appLockSave(appLockData)
        local hid = appLockHideApp(name)
        -- Deliberately NO cooldown here: locking from the manager opens
        -- no prompt, so there is no loop to damp, and a cooldown would
        -- just delay the first real PIN challenge.
        hs.alert.show("✅ " .. name .. " is protected" .. (hid and " — hidden" or ""))

    elseif c.action == "lock" then
        -- Re-locking needs no PIN: it only ever increases protection.
        -- 6.30.0: same live-state check as unlock, for the same reason —
        -- but note the ACTION still runs. Concealing something already
        -- locked is harmless and occasionally useful (it may be locked
        -- but still on screen); only the WORDING changes, so the alert
        -- never claims to have done something it did not do.
        local wasUnlocked = appLockIsUnlocked(name)
        unlocked[name] = nil
        local hid = appLockHideApp(name)
        if wasUnlocked then
            hs.alert.show("🔒 " .. name .. " locked" .. (hid and " — hidden" or ""))
        else
            hs.alert.show("🔒 " .. name .. " was already locked"
                .. (hid and " — hidden" or ""))
        end

    elseif c.action == "unlock" then
        -- ⚠️ 6.30.0 — CHECK LIVE STATE, NOT THE ROW.
        -- The rows are rendered when the manager opens and can go stale
        -- while it is on screen (an app quitting, re-lock-on-leave
        -- firing, a second window acting). Asking for a PIN to unlock
        -- something that is already unlocked is at best confusing and at
        -- worst teaches you to type your PIN when nothing asked for it.
        if appLockIsUnlocked(name) then
            hs.alert.show("🔓 " .. name .. " is already unlocked")
            return
        end
        appLockAskPin("App Lock", "Enter your PIN to unlock " .. name, function(pin)
            if not pin then return end
            if not appLockCheckPin(pin) then
                hs.alert.show("❌ Wrong PIN")
                return
            end
            unlocked[name] = true
            local okList, apps = pcall(hs.application.runningApplications)
            if okList and apps then
                for _, a in ipairs(apps) do
                    local okName, n = pcall(function() return a:name() end)
                    if okName and n == name then pcall(function() a:unhide() end) end
                end
            end
            hs.alert.show("🔓 " .. name .. " unlocked — stays open until you lock it")
        end)

    elseif c.action == "unprotect" then
        -- PIN-gated on purpose. Without this, anyone could open ⇪⇧H,
        -- remove the app from the list, and walk straight into it — the
        -- lock would be decoration.
        appLockAskPin("App Lock", "Enter your PIN to stop protecting " .. name, function(pin)
            if not pin then return end
            if not appLockCheckPin(pin) then
                hs.alert.show("❌ Wrong PIN")
                return
            end
            appLockData.apps[name] = nil
            unlocked[name] = nil
            appLockSave(appLockData)
            hs.alert.show("○ " .. name .. " is no longer protected")
        end)

    elseif c.action == "pin" then
        local function setNew()
            appLockAskPin("App Lock", "Enter a NEW PIN (4+ characters)", function(pin)
                if not pin then return end
                if #pin < 4 then
                    hs.alert.show("⚠️ PIN must be at least 4 characters")
                    return
                end
                appLockAskPin("App Lock", "Re-enter the new PIN to confirm", function(again)
                    if again ~= pin then
                        hs.alert.show("❌ PINs didn't match — nothing changed")
                        return
                    end
                    appLockData.salt = appLockNewSalt()
                    appLockData.hash = appLockHash(pin, appLockData.salt)
                    if appLockSave(appLockData) then hs.alert.show("🔑 PIN set") end
                end)
            end)
        end
        if appLockHasPin() then
            appLockAskPin("App Lock", "Enter your CURRENT PIN", function(pin)
                if not pin then return end
                if not appLockCheckPin(pin) then
                    hs.alert.show("❌ Wrong PIN")
                    return
                end
                setNew()
            end)
        else
            setNew()
        end
    end
end)
_G.choosers.appLock:placeholderText("App Lock — Enter locks or unlocks the selected app")

_G.hyperAddShortcut({"shift"}, "h", function()
    appLockManagerMode = "main"   -- always open on the main list
    appLockReopenManager()
end, "app lock manager")

-- ---- guarantees that a cover can never strand you -------------------
-- PANIC KEY. Deliberately a GLOBAL hotkey, not a hyper-modal binding:
-- if the modal is ever wedged, this still fires. ⇪K reaches it too,
-- because unclaimed hyper keys forward exactly this chord.
hs.hotkey.bind({ "cmd", "ctrl", "alt", "shift" }, "K", function()
    local had = appLockRemoveCovers()
    unlocked = unlocked or {}
    hs.alert.show(had and "🔓 App Lock covers cleared" or "No App Lock covers were up")
    if had then print("🔒 App Lock: covers cleared by the panic key (⌘⇧⌃⌥K)") end
end)

-- WATCHDOG. A cover with no PIN prompt behind it is by definition
-- orphaned — the prompt closed, or something threw before it opened.
-- Three seconds later it goes away on its own. Held in _G. so the
-- garbage collector cannot quietly cancel it (see §3.7).
_G.appLockCoverWatchdog = hs.timer.doEvery(3, function()
    if #_G.appLockCovers > 0 and not promptOpen then
        if appLockRemoveCovers() then
            print("🔒 App Lock: cleared an orphaned cover (no PIN prompt was open)")
        end
    end
end)

_G.appLockRemoveCoversForTest = appLockRemoveCovers
_G.appLockShowCoversForTest   = appLockShowCovers
_G.appLockCoverCountForTest   = function() return #_G.appLockCovers end
_G.appLockHideAppForTest    = appLockHideApp
_G.appLockCoolingDownForTest = appLockCoolingDown
_G.appLockPromptCountForTest = function() return appLockPromptCount end
_G.appLockRelockOnLeaveForTest = appLockRelockOnLeave
_G.appLockIsRealAppForTest = appLockIsRealApp
_G.appLockVerifyTimersForTest = function() return _G.appLockVerifyTimers end
_G.appLockPromptOpenForTest  = function() return promptOpen end
_G.appLockClearCooldownForTest = function() appLockCooldown = {} end
_G.appLockUnlockedForTest   = function() return unlocked end
_G.appLockRenderManagerForTest = function(mode)
    appLockManagerMode = mode or "main"
    appLockRenderManager()
    return _G.choosers.appLock.lastChoices
end
_G.appLockPinChooserForTest = function() return _G.choosers.appLockPin end
_G.appLockPinBufferForTest  = function() return pinBuffer end

_G.appLockStatusForBoot = function()
    if not appLockEnabled then return "disabled in config" end
    local n = 0
    for _ in pairs(appLockData.apps) do n = n + 1 end
    if not appLockHasPin() then
        return (n > 0) and (n .. " apps marked but NO PIN SET — not locking (⇪⇧H to set one)")
               or "no PIN set, nothing locked (⇪⇧H to set up)"
    end
    local mode = appLockRelockOnLeave() and "re-locks when you switch away"
                 or "stays unlocked until you re-lock by hand"
    mode = mode .. (appLockUseCover and " · cover mode (⌘⇧⌃⌥K clears)" or " · hide mode")
    return (n == 0) and "PIN set, no apps locked yet (⇪⇧H to add)"
           or (n .. " app" .. ((n == 1) and "" or "s") .. " protected · " .. mode)
end

_G.appLockCountForTest    = function() local n = 0; for _ in pairs(appLockData.apps) do n = n + 1 end; return n end
_G.appLockHashForTest     = appLockHash
_G.appLockCheckPinForTest = appLockCheckPin
_G.appLockIsLockedForTest = appLockIsLocked
_G.appLockNeverLockForTest = appLockNeverLock
_G.appLockFileForTest     = appLockFile

end)() -- §6.6 App Lock


-- /////////////////////////////////////////////////
-- /////////////////////////////////////////////////
-- ////////////////////////////////////////////////
-- // EXPERIMENTAL SECTION BEGIN                //

-- =====================================================================
-- X.1 DOCUMENT WATCHER — ⇪⇧W list · ⇪⇧E edit · doc_wather.csv
-- =====================================================================
-- Records every document you actually work in, with how long you spent
-- in it, and gives you a searchable list.
--
-- SELF-CONTAINED BY DESIGN. Everything lives inside the immediately
-- invoked function below: its own state, its own file, its own timers,
-- its own pickers. It reads logsDir, showPopup, csvQuote and
-- _G.hyperAddShortcut from the rest of the config and touches nothing
-- else. Deleting this whole block leaves the rest of init.lua working.
--
-- ⚠️ THREE THINGS I COULD NOT BUILD AS ASKED — hs.chooser limits, not
--    preferences. Read these before judging the result:
--
--    1. SHIFT-CLICK MULTI-SELECT does not exist. hs.chooser is a
--       single-selection list; there is no API for a second selected
--       row, and no click handler that reports modifier keys. Instead
--       there is a SELECT MODE: Enter tags a row (✓), and a "Copy N
--       tagged" row copies them all at once. Same outcome, supported
--       API.
--    2. BARE "W" INSIDE THE WINDOW cannot be an edit command. The
--       keyboard belongs to the search field, so pressing W types a "w"
--       into your search. You asked for search AND bare-letter commands
--       in the same window; those are mutually exclusive. Editing is on
--       ⇪⇧E instead, and works while the list is open.
--    3. ⇪W is the app-summon picker (6.31.3), so this list is ⇪⇧W.
--
-- HOW TIME IS MEASURED: the frontmost window is sampled every 5s. A
-- sample only counts if you are actually present (no keyboard/mouse for
-- 2 minutes stops the clock) and if the gap since the last sample is
-- sane. After sleep or a long stall the gap is discarded rather than
-- billed to whatever document happened to be open — that is the
-- "dump it if it is not accurate" rule.
;(function()

local docEnabled       = true
local docFile          = logsDir .. "/doc_wather.csv"   -- spelling as requested
local docPollSeconds   = 5      -- how often the frontmost window is sampled
local docIdleCutoff    = 120    -- no input for this long = stop the clock
local docSaveSeconds   = 60     -- how often the CSV is flushed
local docMaxRows       = 500    -- rows shown in the picker at once

if not docEnabled then return end

-- ---- state -----------------------------------------------------------
-- rows: { date=, time=, file=, secs= } — one per document per day.
local docRows      = {}
local docIndex     = {}     -- "date|file" -> row, so a sample is O(1)
local docDirty     = false
local docLastKey   = nil    -- which doc the previous sample saw
local docLastStamp = nil    -- os.time() of the previous sample
local docTagged    = {}     -- "date|file" -> true, in select mode
local docSelectMode = false

local function docKey(date, file) return date .. "|" .. file end

-- ---- time formatting -------------------------------------------------
local function docFormatSecs(secs)
    secs = math.max(0, math.floor(tonumber(secs) or 0))
    return string.format("%d:%02d:%02d", secs // 3600, (secs % 3600) // 60, secs % 60)
end

-- Strict on purpose: anything that is not exactly H:MM:SS is treated as
-- corrupt and the row is dropped rather than guessed at.
local function docParseSecs(text)
    local h, m, sec = tostring(text or ""):match("^(%d+):(%d%d):(%d%d)$")
    if not h then return nil end
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
end

-- ---- CSV -------------------------------------------------------------
-- Minimal RFC-4180 field splitter: handles quoted fields containing
-- commas, which filenames genuinely do.
local function docSplitCSV(line)
    local out, field, inQuotes, i = {}, {}, false, 1
    while i <= #line do
        local c = line:sub(i, i)
        if inQuotes then
            if c == '"' then
                if line:sub(i + 1, i + 1) == '"' then
                    table.insert(field, '"'); i = i + 1
                else
                    inQuotes = false
                end
            else
                table.insert(field, c)
            end
        elseif c == '"' then
            inQuotes = true
        elseif c == "," then
            table.insert(out, table.concat(field)); field = {}
        else
            table.insert(field, c)
        end
        i = i + 1
    end
    table.insert(out, table.concat(field))
    return out
end

local DOC_HEADER = "Date,Time of day,File name,Working time"

local function docLoad()
    docRows, docIndex = {}, {}
    local f = io.open(docFile, "r")
    if not f then return end
    local content = f:read("*a"); f:close()
    local dropped, first = 0, true
    for line in content:gmatch("[^\r\n]+") do
        if first then
            first = false
            if line:sub(1, 4):lower() == "date" then goto continue end
        end
        do
            local c = docSplitCSV(line)
            local date, time, file, worked = c[1], c[2], c[3], c[4]
            local secs = docParseSecs(worked)
            -- Every field must be present and well formed, or the row is
            -- discarded. A half-written row from a crash is worse than a
            -- missing one, because it would silently skew the totals.
            if date and date:match("^%d%d%d%d%-%d%d%-%d%d$")
               and time and time:match("^%d%d:%d%d$")
               and file and file:match("%S") and secs then
                local row = { date = date, time = time, file = file, secs = secs }
                table.insert(docRows, row)
                docIndex[docKey(date, file)] = row
            else
                dropped = dropped + 1
            end
        end
        ::continue::
    end
    if dropped > 0 then
        print("📄 Document Watcher: dropped " .. dropped
            .. " malformed row(s) from doc_wather.csv rather than trust them")
    end
end

local function docSave()
    if not docDirty then return end
    local f = io.open(docFile, "w")
    if not f then
        print("🚨 Document Watcher: cannot write " .. docFile)
        return
    end
    f:write(DOC_HEADER .. "\n")
    for _, r in ipairs(docRows) do
        f:write(r.date .. "," .. r.time .. "," .. csvQuote(r.file)
            .. "," .. docFormatSecs(r.secs) .. "\n")
    end
    f:close()
    docDirty = false
end

-- ---- what counts as a document --------------------------------------
-- Window titles look like "Report.docx — Word", "notes.md - Sublime",
-- "Untitled.txt — Edited". Take the part before the separator and insist
-- it looks like a real filename. Anything else is dumped: a wrong entry
-- is worse than a missing one in a log you are going to trust.
local docTitleSeparators = { " — ", " – ", " - ", " — " }

local function docExtractFileName(title, appName)
    if type(title) ~= "string" then return nil end
    local head = title
    for _, sep in ipairs(docTitleSeparators) do
        local cut = head:find(sep, 1, true)
        if cut then head = head:sub(1, cut - 1) end
    end
    head = head:gsub("^%s+", ""):gsub("%s+$", "")
    if head == "" then return nil end
    if appName and head == appName then return nil end
    -- Must end in a plausible extension.
    local base, ext = head:match("^(.+)%.([%a%d]+)$")
    if not base or not ext then return nil end
    if #ext < 1 or #ext > 6 then return nil end
    if base:match("^%s*$") then return nil end
    return head
end

_G.docExtractFileNameForTest = docExtractFileName
_G.docParseSecsForTest       = docParseSecs
_G.docFormatSecsForTest      = docFormatSecs
_G.docRowsForTest            = function() return docRows end
_G.docSaveForTest            = function() docDirty = true; docSave() end
_G.docFileForTest            = docFile
_G.docLoadForTest            = function() docLoad() end
_G.docResetSamplerForTest    = function() docLastKey, docLastStamp = nil, nil end

-- ---- the sampler -----------------------------------------------------
local function docSample()
    local now = os.time()

    -- Away from the keyboard? Stop the clock and forget where we were,
    -- so the idle gap is never billed to the document.
    local okIdle, idle = pcall(hs.host.idleTime)
    if okIdle and type(idle) == "number" and idle > docIdleCutoff then
        docLastKey, docLastStamp = nil, nil
        return
    end

    local okApp, app = pcall(hs.application.frontmostApplication)
    if not okApp or not app then docLastKey, docLastStamp = nil, nil; return end
    local okName, appName = pcall(function() return app:name() end)
    if not okName then appName = nil end

    local okWin, win = pcall(function() return app:focusedWindow() or app:mainWindow() end)
    if not okWin or not win then docLastKey, docLastStamp = nil, nil; return end
    local okTitle, title = pcall(function() return win:title() end)
    if not okTitle then docLastKey, docLastStamp = nil, nil; return end

    local file = docExtractFileName(title, appName)
    if not file then docLastKey, docLastStamp = nil, nil; return end

    local date = os.date("%Y-%m-%d", now)
    local key  = docKey(date, file)

    -- Bill the elapsed time only when this is the SAME document as last
    -- sample and the gap is sane. After sleep, a long stall, or a date
    -- rollover the gap is discarded — see the "dump it" rule above.
    if docLastKey == key and docLastStamp then
        local delta = now - docLastStamp
        if delta > 0 and delta <= docPollSeconds * 3 then
            local row = docIndex[key]
            if not row then
                row = { date = date, time = os.date("%H:%M", now), file = file, secs = 0 }
                table.insert(docRows, row)
                docIndex[key] = row
            end
            row.secs = row.secs + delta
            docDirty = true
        end
    else
        -- First sighting today: create the row with a 0 time so it shows
        -- up in the list (and the tally) straight away.
        if not docIndex[key] then
            local row = { date = date, time = os.date("%H:%M", now), file = file, secs = 0 }
            table.insert(docRows, row)
            docIndex[key] = row
            docDirty = true
        end
    end

    docLastKey, docLastStamp = key, now
end

_G.docSampleForTest = docSample

-- ---- the list (⇪⇧W) --------------------------------------------------
local function docTodayTally()
    -- os.date() with no time argument reads the WALL CLOCK, while every
    -- row is stamped from os.time(). Those are the same thing on a real
    -- Mac right up until they aren't — across midnight, or under a test
    -- clock — and then "documents today" silently reports zero. Same
    -- source for both, always.
    local today, count, secs = os.date("%Y-%m-%d", os.time()), 0, 0
    for _, r in ipairs(docRows) do
        if r.date == today then count = count + 1; secs = secs + r.secs end
    end
    return count, secs
end

local function docCountTagged()
    local n = 0
    for _ in pairs(docTagged) do n = n + 1 end
    return n
end

local function docRowText(r)
    return r.file .. "   ·   " .. docFormatSecs(r.secs)
end

local function docCopyRows(rows)
    local lines = {}
    for _, r in ipairs(rows) do
        table.insert(lines, r.date .. "  " .. r.time .. "  " .. r.file
            .. "  " .. docFormatSecs(r.secs))
    end
    if #lines == 0 then return 0 end
    hs.pasteboard.setContents(table.concat(lines, "\n"))
    return #lines
end

local function docRenderList(query)
    local q = tostring(query or ""):lower():match("^%s*(.-)%s*$")
    local choices = {}
    local count, secs = docTodayTally()

    -- The running tally, always the first row.
    table.insert(choices, {
        text    = "📊 " .. count .. " document" .. ((count == 1) and "" or "s")
                  .. " today   ·   " .. docFormatSecs(secs) .. " worked",
        subText = "Type to search by name, extension or date",
        action  = "noop",
    })

    if docSelectMode then
        local picked = docCountTagged()
        table.insert(choices, {
            text    = (picked == 0) and "📋 Nothing picked yet"
                      or ("📋 Copy the " .. picked .. " document"
                          .. ((picked == 1) and "" or "s") .. " I picked"),
            subText = (picked == 0)
                      and "Go down the list and press Enter on the ones you want"
                      or "Press Enter HERE when you have picked them all",
            action  = "copytagged",
        })
        table.insert(choices, {
            text = "✖️ Never mind — go back",
            subText = "Forget the picks and return to the normal list",
            action = "selectoff",
        })
    else
        table.insert(choices, {
            text    = "☑️ Copy several at once…",
            subText = "Pick rows one at a time, then copy them together",
            action  = "selecton",
        })
    end

    -- Newest first: same date order as the file, reversed.
    local shown = 0
    for i = #docRows, 1, -1 do
        local r = docRows[i]
        local hay = (r.file .. " " .. r.date .. " " .. r.time):lower()
        if q == "" or hay:find(q, 1, true) then
            local isPicked = docTagged[docKey(r.date, r.file)]
            local hint
            if not docSelectMode then
                hint = "Enter copies this one"
            elseif isPicked then
                hint = "PICKED — Enter removes it from the copy list"
            else
                hint = "Enter adds this to the copy list"
            end
            table.insert(choices, {
                text    = (isPicked and "✓ " or "") .. docRowText(r),
                subText = r.date .. "  " .. r.time .. "   ·   " .. hint,
                action  = "row", key = docKey(r.date, r.file),
            })
            shown = shown + 1
            if shown >= docMaxRows then break end
        end
    end

    if shown == 0 then
        table.insert(choices, {
            text    = (q == "") and "No documents recorded yet"
                      or ("No matches for \"" .. q .. "\""),
            subText = "Documents appear once you have worked in one for a few seconds",
            action  = "noop",
        })
    end

    _G.choosers.docWatcher:choices(choices)
end

_G.docRenderListForTest = function(q)
    docRenderList(q)
    return _G.choosers.docWatcher.lastChoices
end
_G.docSelectModeForTest = function(on) docSelectMode = on and true or false end
_G.docTaggedForTest     = function() return docTagged end

local function docFindRow(key)
    for _, r in ipairs(docRows) do
        if docKey(r.date, r.file) == key then return r end
    end
    return nil
end

_G.choosers.docWatcher = hs.chooser.new(function(c)
    if not c or not c.action or c.action == "noop" then return end

    if c.action == "selecton" then
        docSelectMode, docTagged = true, {}
        docRenderList(""); _G.choosers.docWatcher:query("")
        showPopup(_G.choosers.docWatcher)

    elseif c.action == "selectoff" then
        docSelectMode, docTagged = false, {}
        docRenderList(""); _G.choosers.docWatcher:query("")
        showPopup(_G.choosers.docWatcher)

    elseif c.action == "copytagged" then
        local rows = {}
        for _, r in ipairs(docRows) do
            if docTagged[docKey(r.date, r.file)] then table.insert(rows, r) end
        end
        local n = docCopyRows(rows)
        hs.alert.show((n > 0)
            and ("📋 Copied " .. n .. " document" .. ((n == 1) and "" or "s"))
            or "Nothing picked — press Enter on the rows you want first")

    elseif c.action == "row" then
        local row = docFindRow(c.key)
        if not row then return end
        if docSelectMode then
            -- Tag / untag, then reopen so the ✓ and the count update.
            if docTagged[c.key] then docTagged[c.key] = nil else docTagged[c.key] = true end
            docRenderList(""); _G.choosers.docWatcher:query("")
            showPopup(_G.choosers.docWatcher)
        else
            docCopyRows({ row })
            hs.alert.show("📋 Copied " .. row.file)
        end
    end
end)
_G.choosers.docWatcher:placeholderText("Documents worked on — search by name, extension or date")
_G.choosers.docWatcher:queryChangedCallback(function(query)
    local ok, err = pcall(docRenderList, query)
    if not ok then
        print("🚨 Document Watcher render error: " .. tostring(err))
        _G.choosers.docWatcher:choices({
            { text = "⚠️ Display error — see Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

-- ---- edit / delete (⇪⇧E) --------------------------------------------
local function docRenderEdit(query)
    local q = tostring(query or ""):lower():match("^%s*(.-)%s*$")
    local choices = {}
    local shown = 0
    for i = #docRows, 1, -1 do
        local r = docRows[i]
        local hay = (r.file .. " " .. r.date):lower()
        if q == "" or hay:find(q, 1, true) then
            table.insert(choices, {
                text    = "✏️ " .. docRowText(r),
                subText = r.date .. "  " .. r.time .. "  ·  Enter to rename or delete",
                action  = "edit", key = docKey(r.date, r.file),
            })
            shown = shown + 1
            if shown >= docMaxRows then break end
        end
    end
    if shown == 0 then
        table.insert(choices, { text = "Nothing to edit", subText = "No matching rows" })
    end
    _G.choosers.docWatcherEdit:choices(choices)
end

_G.choosers.docWatcherEdit = hs.chooser.new(function(c)
    if not c or c.action ~= "edit" then return end
    local row = docFindRow(c.key)
    if not row then return end
    local button, text = hs.dialog.textPrompt(
        "Edit document entry",
        "File name for this entry.\nClear the field and press OK to DELETE the row.\n\n"
            .. row.date .. "  " .. row.time .. "  ·  " .. docFormatSecs(row.secs),
        row.file, "OK", "Cancel")
    if button ~= "OK" then return end
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        for i, r in ipairs(docRows) do
            if r == row then table.remove(docRows, i); break end
        end
        docIndex[docKey(row.date, row.file)] = nil
        docDirty = true; docSave()
        hs.alert.show("🗑 Deleted " .. row.file)
    elseif text ~= row.file then
        docIndex[docKey(row.date, row.file)] = nil
        row.file = text
        docIndex[docKey(row.date, row.file)] = row
        docDirty = true; docSave()
        hs.alert.show("✏️ Renamed to " .. text)
    end
end)
_G.choosers.docWatcherEdit:placeholderText("Edit or delete a document entry")
_G.choosers.docWatcherEdit:queryChangedCallback(function(query)
    pcall(docRenderEdit, query)
end)

-- ---- wiring ----------------------------------------------------------
docLoad()

_G.hyperAddShortcut({"shift"}, "w", function()
    docSelectMode, docTagged = false, {}
    docRenderList("")
    _G.choosers.docWatcher:query("")
    showPopup(_G.choosers.docWatcher)
end, "document watcher")

_G.hyperAddShortcut({"shift"}, "e", function()
    docRenderEdit("")
    _G.choosers.docWatcherEdit:query("")
    showPopup(_G.choosers.docWatcherEdit)
end, "document watcher edit")

-- Held in _G. so the garbage collector cannot quietly cancel them —
-- the same trap that silently killed the App Monitor's timers in 6.16.
_G.docWatcherTimer = hs.timer.doEvery(docPollSeconds, function() pcall(docSample) end)
_G.docWatcherSaveTimer = hs.timer.doEvery(docSaveSeconds, function() pcall(docSave) end)

end)()


-- =====================================================================
-- X.2 QUICK NOTES → ASANA — ⇪N capture · ⇪⇧N history · ⇪⇧P panel
-- =====================================================================
-- Type a thought, forget about it. At 4:00 PM every note captured that
-- day is turned into a task on your personal Asana project.
--
--   ⇪N    capture box. Type and press Enter. That is the whole ritual.
--         Second row saves AND opens the custom-field picker.
--   ⇪⇧N   the history, searchable (note text, task title, date, status).
--   ⇪⇧P   see-through panel that STAYS on screen until you press Esc.
--         Press 1-9 to open that row's task in Asana.
--   ⇪⇧G   send everything waiting right now, without waiting for 4 PM.
--
-- SELF-CONTAINED BY DESIGN, exactly like the Document Watcher above:
-- everything lives inside the immediately invoked function below. It
-- borrows logsDir, hostTag, csvQuote, showPopup, warnWriteFailed,
-- resolveBaseScreen, requireAsana, the asana* credentials from §0.2 and
-- _G.hyperAddShortcut, and touches nothing else. Delete the whole block
-- and the rest of init.lua is unaffected.
--
-- ⚠️ NO NEW TOP-LEVEL LOCALS. The main chunk is at Lua's hard 200-local
--    ceiling (see §0.4) — one more `local` at file scope and this file
--    stops compiling. Every name below is inside the function.
--
-- 📝 WHERE THE TASK TITLE COMES FROM. A note that already reads like an
--    instruction is used as-is: "Email Dana the invoice" becomes exactly
--    that task. A note that does NOT begin with a verb cannot be honestly
--    rewritten into one — guessing produces confident nonsense — so it
--    is prefixed instead: "printer toner low" becomes
--    "Task from notes: printer toner low". You can always tell which
--    happened by looking at the title.
--
-- 🔤 QWERTY-ONLY on the way out. Smart quotes, em dashes and ellipses get
--    folded to their plain equivalents; anything still outside a standard
--    QWERTY keyboard is dropped. This is the same rule the OCR path uses,
--    for the same reason: garbage characters in a task title are noise
--    you have to clean up later, in Asana, by hand.
--
-- ⚠️ ONE HONEST TRADE-OFF — bare 1-9 while the panel is up. You asked for
--    a panel that stays on screen AND for a bare number key to open a
--    row. While the panel is visible those digits belong to the panel, so
--    typing a digit into another app does nothing until you press Esc.
--    Both requests are reasonable; they are simply not simultaneously
--    satisfiable. ⇪1-⇪9 ALWAYS work and never take a key from anything,
--    so if the bare digits bite, set qnPanelBareDigits = false below and
--    you lose nothing but the shorter keypress. A 30s watchdog disables
--    the digit keys if the panel ever disappears without releasing them —
--    a wedged panel that has eaten your number row would be far worse
--    than any bug in this file.
;(function()

local qnEnabled         = true
local qnPostTime        = "16:00"          -- when the day's notes become tasks
local qnPrefix          = "Task from notes:"
local qnProjectId       = asanaProjectId   -- §0.2 — your personal project
local qnMaxRows         = 500              -- rows rendered in a picker at once
local qnPanelRowCount   = 9                -- panel rows = digits 1-9
local qnPanelAlpha      = 0.62             -- 1.0 solid · lower = more see-through
local qnPanelBareDigits = true             -- see the trade-off note above
local qnPanelCorner     = "topRight"       -- topRight|topLeft|bottomRight|bottomLeft
local qnFieldsMaxAge    = 86400            -- re-fetch custom field defs once a day

if not qnEnabled then return end

local qnFile       = logsDir .. "/quick_notes-" .. hostTag .. ".csv"
local qnFieldsFile = logsDir .. "/quick_notes_fields-" .. hostTag .. ".json"
local QN_HEADER    = "Date,Time,Note,Task,Date statement,Status,Asana task,Asana URL,Custom fields"

-- ---- state -----------------------------------------------------------
local qnRows          = {}     -- oldest first, exactly as stored
local qnDirty         = false
local qnFields        = {}     -- custom field definitions from Asana
local qnFieldsStamp   = 0
local qnSyncing       = false
local qnSyncStarted   = 0
local qnPanelCanvas   = nil
local qnPanelKeys     = {}
local qnPanelKeysOn   = false
local qnPanelShown    = {}     -- panel row index -> row, for the digit keys

-- Mutually recursive pickers: declared here, defined further down.
local qnFieldsPickerOpen, qnPromptFieldValue, qnHistoryOpen, qnPanelRender

-- ---- text hygiene ----------------------------------------------------
-- Fold the typographic characters that arrive with any copy/paste into
-- their QWERTY equivalents, THEN drop whatever is still not on a standard
-- keyboard. Folding first matters: stripping alone would turn "don’t"
-- into "dont" and "3–4pm" into "34pm", which is worse than the garbage
-- it removes.
local qnFold = {
    ["\u{2018}"] = "'",  ["\u{2019}"] = "'",  ["\u{201A}"] = "'",  ["\u{201B}"] = "'",
    ["\u{201C}"] = '"',  ["\u{201D}"] = '"',  ["\u{201E}"] = '"',  ["\u{201F}"] = '"',
    ["\u{2013}"] = "-",  ["\u{2014}"] = "-",  ["\u{2015}"] = "-",  ["\u{2212}"] = "-",
    ["\u{2026}"] = "...", ["\u{2044}"] = "/", ["\u{00D7}"] = "x",
    ["\u{00A0}"] = " ",  ["\u{2007}"] = " ",  ["\u{2009}"] = " ",  ["\u{202F}"] = " ",
    ["\u{2028}"] = " ",  ["\u{2029}"] = " ",
    ["\u{2022}"] = "*",  ["\u{00B7}"] = "*",
    ["\u{2192}"] = "->", ["\u{2190}"] = "<-",
    ["\u{00A9}"] = "(C)", ["\u{00AE}"] = "(R)", ["\u{2122}"] = "(TM)",
    ["\u{00BC}"] = "1/4", ["\u{00BD}"] = "1/2", ["\u{00BE}"] = "3/4",
}

local function qnClean(s)
    s = tostring(s or "")
    -- UTF-8 continuation bytes are all >= 0x80 and none of Lua's pattern
    -- magic characters live up there, so these keys are safe as patterns.
    for from, to in pairs(qnFold) do s = s:gsub(from, to) end
    s = s:gsub("[^\32-\126\t\r\n]", "")   -- anything left is not on a QWERTY board
    s = s:gsub("[\t\r\n]+", " ")          -- one line: the CSV is line-oriented
    s = s:gsub("%s+", " ")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function qnClip(s, n)
    s = tostring(s or "")
    if #s <= n then return s end
    return s:sub(1, math.max(1, n - 3)) .. "..."
end

-- ---- does this note already read like an instruction? ----------------
-- A deliberately plain check: the first word, against a list of verbs
-- people actually start tasks with. No stemming, no cleverness — a wrong
-- "yes" produces a task title that reads like a fragment, and a wrong
-- "no" only adds a prefix that tells you the truth.
local qnVerbs = {}
for w in ([[
add adjust align analyze answer apply approve archive arrange ask assemble assess assign attach audit
back book brief bring budget build buy calculate call cancel capture change chase check choose circle
clarify clean clear close collect combine comment commit compare compile complete compose confirm connect
consider consolidate contact continue convert coordinate copy correct create cut debug decide define
delete deliver deploy design determine develop diagnose discuss distribute document double download draft
draw drop edit email enable ensure enter escalate establish estimate evaluate examine expand explain
explore export extend extract file fill filter finalize find finish fix follow format forward gather
generate get give go group handle help hire hold identify implement import improve include increase inform
initiate insert inspect install integrate interview introduce investigate invite invoice join keep kick
launch learn leave link list load lock log look mail maintain make manage map mark measure meet merge
message migrate monitor move name negotiate note notify obtain open optimize order organize outline
package pay perform pick pin pitch plan populate post prepare present print prioritize process produce
program promote proofread propose protect prototype provide publish pull purchase push put query question
quote raise reach read rebuild recheck recommend reconcile record recruit redesign reduce refactor refine
register reinstall relaunch release remind remove rename renew reorder repair replace reply report request
research reserve reset resolve respond restart restore retrieve return review revise revisit rewrite run
save scan schedule scope search secure select send set settle share ship show sign simplify sketch solve
sort source specify split sponsor standardize start streamline study submit subscribe summarize supply
support survey swap sync tag take talk teach tell test tidy touch track train transcribe transfer
transform translate trim troubleshoot try tune turn tweak unblock understand undo unify uninstall unlock
unpack update upgrade upload use validate verify visit wait walk watch weigh work wrap write
]]):gmatch("%a+") do qnVerbs[w] = true end

-- Returns the task title, plus whether the note stood on its own.
local function qnTitleFor(noteText)
    local t = qnClean(noteText)
    t = t:gsub("^[%-%*%+>%s]+", "")
    t = t:gsub("^[Tt][Oo][Dd][Oo]%s*[:%-]?%s*", "")
    t = t:gsub("^%s+", "")
    if t == "" then return nil, false end

    local probe = t:gsub("^[Pp]lease%s+", "")
    local first = probe:match("^(%a[%a']*)")
    local isVerb = false
    if first then
        isVerb = qnVerbs[first:lower()] or false
        if not isVerb then
            -- "re-check the invoice" — the verb is on the far side of the hyphen
            local stem = probe:match("^%a+%-(%a+)")
            if stem then isVerb = qnVerbs[stem:lower()] or false end
        end
    end

    local title = isVerb and t or (qnPrefix .. " " .. t)
    if #title > 240 then
        title = title:sub(1, 240):gsub("%s+%S*$", "") .. "..."
    end
    return title, isVerb
end

-- ---- the date statement ----------------------------------------------
-- Written out in full, on purpose: it is read inside an Asana task days
-- later, where "2026-08-03 14:22" makes you do arithmetic.
local function qnDateStatement(when)
    local d   = os.date("*t", when)
    local h12 = d.hour % 12
    if h12 == 0 then h12 = 12 end
    return string.format("%s, %s %d, %d at %d:%02d %s",
        os.date("%A", when), os.date("%B", when), d.day, d.year,
        h12, d.min, (d.hour < 12) and "AM" or "PM")
end

-- ---- CSV -------------------------------------------------------------
-- Minimal RFC-4180 splitter — notes contain commas constantly.
local function qnSplitCSV(line)
    local out, field, inQuotes, i = {}, {}, false, 1
    while i <= #line do
        local c = line:sub(i, i)
        if inQuotes then
            if c == '"' then
                if line:sub(i + 1, i + 1) == '"' then
                    table.insert(field, '"'); i = i + 1
                else
                    inQuotes = false
                end
            else
                table.insert(field, c)
            end
        elseif c == '"' then
            inQuotes = true
        elseif c == "," then
            table.insert(out, table.concat(field)); field = {}
        else
            table.insert(field, c)
        end
        i = i + 1
    end
    table.insert(out, table.concat(field))
    return out
end

-- Shape alone is not enough here. "2026-13-99" and "99:99" both satisfy
-- a %d%d%d%d-%d%d-%d%d / %d%d:%d%d check, and a row that gets through
-- does not just look odd in the list — it is POSTED to Asana as a real
-- task, carrying an impossible "Captured:" line, and a sent task cannot
-- be un-sent. So the numbers are range-checked too.
local function qnValidDate(s)
    local y, m, d = tostring(s or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then return false end
    m, d = tonumber(m), tonumber(d)
    return m >= 1 and m <= 12 and d >= 1 and d <= 31
end

local function qnValidTime(s)
    local h, m = tostring(s or ""):match("^(%d%d):(%d%d)$")
    if not h then return false end
    return tonumber(h) <= 23 and tonumber(m) <= 59
end

local function qnLoad()
    qnRows = {}
    local f = io.open(qnFile, "r")
    if not f then return end
    local content = f:read("*a"); f:close()
    local dropped, isFirst = 0, true
    for line in content:gmatch("[^\r\n]+") do
        local skip = false
        if isFirst then
            isFirst = false
            if line:sub(1, 4):lower() == "date" then skip = true end
        end
        if not skip then
            local c = qnSplitCSV(line)
            -- Every row must carry a usable date, time and note or it is
            -- dropped. A half-written row from a crash would otherwise be
            -- posted to Asana as a real task, which you cannot un-send.
            if qnValidDate(c[1]) and qnValidTime(c[2])
               and c[3] and c[3]:match("%S") then
                local sel = {}
                if c[9] and c[9] ~= "" then
                    local okD, parsed = pcall(hs.json.decode, c[9])
                    if okD and type(parsed) == "table" then sel = parsed end
                end
                local status = c[6] or "pending"
                if status ~= "posted" and status ~= "failed" then status = "pending" end
                table.insert(qnRows, {
                    date   = c[1], time = c[2], note = c[3],
                    title  = (c[4] and c[4] ~= "") and c[4] or nil,
                    stmt   = c[5] or "",
                    status = status,
                    gid    = c[7] or "", url = c[8] or "",
                    fields = sel,
                })
            else
                dropped = dropped + 1
            end
        end
    end
    if dropped > 0 then
        print("🗒 Quick Notes: dropped " .. dropped
            .. " malformed row(s) from quick_notes CSV rather than post them as tasks")
    end
end

local function qnSave()
    if not qnDirty then return end
    local f = io.open(qnFile, "w")
    if not f then warnWriteFailed("the Quick Notes CSV"); return end
    f:write(QN_HEADER .. "\n")
    for _, r in ipairs(qnRows) do
        local encoded = ""
        if r.fields and next(r.fields) then
            local okE, enc = pcall(hs.json.encode, r.fields)
            if okE and type(enc) == "string" then encoded = enc end
        end
        f:write(table.concat({
            r.date, r.time,
            csvQuote(r.note), csvQuote(r.title or ""), csvQuote(r.stmt),
            r.status, r.gid, csvQuote(r.url), csvQuote(encoded),
        }, ",") .. "\n")
    end
    f:close()
    qnDirty = false
end

-- ---- custom field definitions ----------------------------------------
local function qnFieldsSaveCache()
    local f = io.open(qnFieldsFile, "w")
    if not f then return end
    local okE, enc = pcall(hs.json.encode, { stamp = qnFieldsStamp, fields = qnFields })
    if okE and type(enc) == "string" then f:write(enc) end
    f:close()
end

local function qnFieldsLoadCache()
    local f = io.open(qnFieldsFile, "r")
    if not f then return end
    local content = f:read("*a"); f:close()
    local okD, parsed = pcall(hs.json.decode, content)
    if okD and type(parsed) == "table" and type(parsed.fields) == "table" then
        qnFields      = parsed.fields
        qnFieldsStamp = tonumber(parsed.stamp) or 0
    end
end

local function qnFieldsFetch(done)
    done = done or function() end
    if not asanaEnabled then done(false, "Asana is off on this Mac"); return end
    local url = "https://app.asana.com/api/1.0/projects/" .. tostring(qnProjectId)
        .. "/custom_field_settings?limit=100&opt_fields=custom_field.gid,custom_field.name,"
        .. "custom_field.resource_subtype,custom_field.enum_options.gid,"
        .. "custom_field.enum_options.name,custom_field.enum_options.enabled"
    hs.http.asyncGet(url, { ["Authorization"] = "Bearer " .. asanaToken },
        function(status, body)
            if status ~= 200 then
                print("🚨 Quick Notes: custom fields fetch failed (HTTP "
                    .. tostring(status) .. "): " .. tostring(body))
                done(false, "HTTP " .. tostring(status))
                return
            end
            local okD, parsed = pcall(hs.json.decode, body)
            if not okD or type(parsed) ~= "table" or type(parsed.data) ~= "table" then
                done(false, "unreadable reply from Asana"); return
            end
            local out = {}
            for _, setting in ipairs(parsed.data) do
                local cf = setting and setting.custom_field
                if type(cf) == "table" and cf.gid and cf.name then
                    local entry = {
                        gid  = tostring(cf.gid),
                        name = tostring(cf.name),
                        kind = tostring(cf.resource_subtype or "text"),
                        options = {},
                    }
                    if type(cf.enum_options) == "table" then
                        for _, o in ipairs(cf.enum_options) do
                            if type(o) == "table" and o.gid and o.enabled ~= false then
                                table.insert(entry.options,
                                    { gid = tostring(o.gid), name = tostring(o.name or "?") })
                            end
                        end
                    end
                    table.insert(out, entry)
                end
            end
            qnFields, qnFieldsStamp = out, os.time()
            qnFieldsSaveCache()
            done(true)
        end)
end

-- Turns the stored per-note selection into the shape Asana's API wants.
local function qnFieldsPayload(row)
    if not row.fields or not next(row.fields) then return nil end
    local out, n = {}, 0
    for gid, sel in pairs(row.fields) do
        if type(sel) == "table" and sel.value ~= nil then
            local v = sel.value
            if sel.kind == "number" then
                v = tonumber(v)
            elseif sel.kind == "date" then
                v = { date = tostring(v) }
            end
            if v ~= nil then out[tostring(gid)] = v; n = n + 1 end
        end
    end
    if n == 0 then return nil end
    return out
end

local function qnFieldsSummary(row)
    if not row.fields or not next(row.fields) then return "" end
    local parts = {}
    for _, def in ipairs(qnFields) do          -- definition order, so it is stable
        local sel = row.fields[def.gid]
        if type(sel) == "table" and sel.label and sel.label ~= "" then
            table.insert(parts, def.name .. ": " .. sel.label)
        end
    end
    if #parts == 0 then
        for _, sel in pairs(row.fields) do
            if type(sel) == "table" and sel.label then table.insert(parts, sel.label) end
        end
    end
    return table.concat(parts, "  ·  ")
end

local function qnCountFields(row)
    local n = 0
    if row.fields then for _ in pairs(row.fields) do n = n + 1 end end
    return n
end

-- ---- adding a note ---------------------------------------------------
local function qnAdd(text)
    local clean = qnClean(text)
    if clean == "" then return nil end
    local now   = os.time()
    local title = qnTitleFor(clean)
    local row = {
        date   = os.date("%Y-%m-%d", now),
        time   = os.date("%H:%M", now),
        note   = clean,
        title  = title,
        stmt   = qnDateStatement(now),
        status = "pending",
        gid    = "", url = "",
        fields = {},
    }
    table.insert(qnRows, row)
    qnDirty = true
    qnSave()
    return row
end

local function qnPending()
    local out = {}
    for _, r in ipairs(qnRows) do
        if r.status == "pending" then table.insert(out, r) end
    end
    return out
end

-- ---- posting to Asana ------------------------------------------------
local function qnNoteBody(row)
    return table.concat({
        row.note,
        "",
        "----------------------------------------",
        "Captured: " .. (row.stmt ~= "" and row.stmt or (row.date .. " " .. row.time)),
        "Source:   Hammerspoon Quick Notes (" .. hostTag .. ")",
    }, "\n")
end

local function qnPostRow(row, done)
    local payload = {
        name     = qnClean(row.title or row.note),
        notes    = qnNoteBody(row),
        projects = { tostring(qnProjectId) },
    }
    local cf = qnFieldsPayload(row)
    if cf then payload.custom_fields = cf end

    local okE, body = pcall(hs.json.encode, { data = payload })
    if not okE or type(body) ~= "string" then
        row.status = "failed"
        done(false, "could not encode the task")
        return
    end

    hs.http.asyncPost(
        "https://app.asana.com/api/1.0/tasks?opt_fields=gid,permalink_url",
        body,
        { ["Authorization"] = "Bearer " .. asanaToken, ["Content-Type"] = "application/json" },
        function(status, respBody)
            if status == 200 or status == 201 then
                local okD, parsed = pcall(hs.json.decode, respBody)
                local d = (okD and type(parsed) == "table") and parsed.data or nil
                row.gid = (d and d.gid) and tostring(d.gid) or ""
                row.url = (d and d.permalink_url) and tostring(d.permalink_url)
                    or ((row.gid ~= "") and ("https://app.asana.com/0/0/" .. row.gid) or "")
                row.status = "posted"
                qnDirty = true
                done(true)
            else
                row.status = "failed"
                qnDirty = true
                print("🚨 Quick Notes: Asana refused \"" .. tostring(row.title)
                    .. "\" (HTTP " .. tostring(status) .. "): " .. tostring(respBody))
                if status == 401 then
                    hs.alert.show("🔒 Asana rejected the token — check ~/.hammerspoon/secret.lua", 6)
                end
                done(false, "HTTP " .. tostring(status))
            end
        end)
end

local function qnRunSync(manual)
    if qnSyncing then
        if manual then hs.alert.show("⏳ Quick Notes: already sending — hold on") end
        return
    end
    -- Stamp the day BEFORE any early return, so a day with nothing to send
    -- still counts as "today's run happened" and the catch-up timer below
    -- stops re-asking every half hour.
    if not manual then
        pcall(function() hs.settings.set("qnLastRunDate", os.date("%Y-%m-%d")) end)
    end
    if not asanaEnabled then
        if manual then requireAsana() end
        return
    end

    local pending = qnPending()
    if #pending == 0 then
        if manual then hs.alert.show("🗒 Quick Notes: nothing waiting to send") end
        return
    end

    qnSyncing, qnSyncStarted = true, os.time()
    local i, sent, failed = 0, 0, 0

    local function step()
        i = i + 1
        if i > #pending then
            qnSyncing = false
            qnDirty = true; qnSave()
            local msg
            if failed == 0 then
                msg = "✅ Quick Notes: " .. sent .. " note" .. ((sent == 1) and "" or "s")
                    .. " sent to Asana"
            else
                msg = "⚠️ Quick Notes: " .. sent .. " sent, " .. failed
                    .. " failed — see the Hammerspoon Console"
            end
            hs.alert.show(msg, 4)
            pcall(function()
                hs.notify.new(nil, {
                    title = "Quick Notes → Asana", informativeText = msg,
                }):send()
            end)
            if qnPanelCanvas then pcall(qnPanelRender) end
            return
        end
        qnPostRow(pending[i], function(ok)
            if ok then sent = sent + 1 else failed = failed + 1 end
            -- Spaced out on purpose: Asana rate-limits bursts, and a
            -- 429 in the middle of a batch would strand the rest.
            _G.qnStepTimer = hs.timer.doAfter(0.35, function() pcall(step) end)
        end)
    end

    step()
end

-- Did today's 4 PM run already happen? Survives the Mac being asleep at
-- 4 PM, and a config reload afterwards, without ever posting twice —
-- only "pending" rows are ever sent, and posting flips them immediately.
local function qnRunIsDue()
    local last
    pcall(function() last = hs.settings.get("qnLastRunDate") end)
    if last == os.date("%Y-%m-%d") then return false end
    local hh, mm = tostring(qnPostTime):match("^(%d+):(%d+)$")
    if not hh then return false end
    local now = os.date("*t")
    return (now.hour * 60 + now.min) >= (tonumber(hh) * 60 + tonumber(mm))
end

-- ---- opening a task --------------------------------------------------
local function qnOpenRow(row, label)
    if not row then return end
    if row.url ~= "" then
        pcall(function() hs.urlevent.openURL(row.url) end)
        hs.alert.show("↗ Opening " .. qnClip(row.title or row.note, 40))
    elseif row.status == "pending" then
        hs.pasteboard.setContents(row.note)
        hs.alert.show((label or "That note") .. " has not been sent yet (goes at "
            .. qnPostTime .. ") — copied the text instead", 4)
    else
        hs.alert.show((label or "That note") .. " has no Asana link (" .. row.status .. ")", 3)
    end
end

-- =====================================================================
-- CAPTURE BOX — ⇪N
-- =====================================================================
-- Row 1 is always the save row and is always highlighted, so Enter is
-- unambiguous no matter what else is on screen. hs.chooser does NOT
-- re-filter once a queryChangedCallback is set, so this order is ours to
-- keep — the same reason the Document Watcher renders its own rows.
local function qnRenderCapture(query)
    local q       = tostring(query or "")
    local typed   = qnClean(q)
    local choices = {}

    if typed ~= "" then
        local title, isVerb = qnTitleFor(typed)
        table.insert(choices, {
            text    = "➕ " .. typed,
            subText = "Enter saves this  ·  becomes: " .. qnClip(title or typed, 90),
            qnAction = "save", qnText = typed,
        })
        table.insert(choices, {
            text    = "🏷 Save and pick custom fields…",
            subText = (#qnFields > 0)
                      and ("Choose any or all of your " .. #qnFields .. " Asana fields")
                      or "Fetches your project's custom fields from Asana first",
            qnAction = "savefields", qnText = typed,
        })
        if not isVerb then
            table.insert(choices, {
                text    = "ℹ️ Does not start with a verb — it will be prefixed",
                subText = "\"" .. qnPrefix .. "\" is added so the task still reads as one",
                qnAction = "noop",
            })
        end
    else
        local waiting = #qnPending()
        table.insert(choices, {
            text    = "🗒 Type a note, then press Enter",
            subText = (waiting > 0)
                      and (waiting .. " note" .. ((waiting == 1) and "" or "s")
                           .. " waiting — they go to Asana at " .. qnPostTime)
                      or ("Notes captured today go to Asana at " .. qnPostTime),
            qnAction = "noop",
        })
        if waiting > 0 then
            table.insert(choices, {
                text    = "📤 Send the " .. waiting .. " waiting note"
                          .. ((waiting == 1) and "" or "s") .. " now",
                subText = "Do not wait for " .. qnPostTime,
                qnAction = "sendnow",
            })
        end
        local shown = 0
        for i = #qnRows, 1, -1 do
            local r = qnRows[i]
            local mark = (r.status == "posted") and "✅"
                         or ((r.status == "failed") and "❌" or "🕓")
            table.insert(choices, {
                text    = mark .. "  " .. qnClip(r.title or r.note, 90),
                subText = r.date .. "  " .. r.time .. "   ·   " .. r.status
                          .. ((r.url ~= "") and "  ·  Enter opens it in Asana" or ""),
                qnAction = "open", qnIndex = i,
            })
            shown = shown + 1
            if shown >= 6 then break end
        end
    end

    _G.choosers.quickNote:choices(choices)
end

local function qnCaptureOpen(prefill)
    qnRenderCapture(prefill or "")
    pcall(function() _G.choosers.quickNote:query(prefill or "") end)
    showPopup(_G.choosers.quickNote)
end

_G.choosers.quickNote = hs.chooser.new(function(c)
    if not c or not c.qnAction or c.qnAction == "noop" then return end

    if c.qnAction == "sendnow" then
        qnRunSync(true)

    elseif c.qnAction == "open" then
        qnOpenRow(qnRows[c.qnIndex], "That note")

    elseif c.qnAction == "save" or c.qnAction == "savefields" then
        local row = qnAdd(c.qnText)
        if not row then hs.alert.show("Nothing to save"); return end
        if c.qnAction == "save" then
            hs.alert.show("🗒 Saved  ·  " .. qnClip(row.title or row.note, 60)
                .. "\nGoes to Asana at " .. qnPostTime, 3)
        else
            -- Chained pickers get a beat to let the first panel finish
            -- closing; opening one straight out of the other's callback
            -- can leave the second one behind the first.
            _G.qnChainTimer = hs.timer.doAfter(0.08, function()
                if #qnFields == 0 or (os.time() - qnFieldsStamp) > qnFieldsMaxAge then
                    hs.alert.show("⏳ Fetching your Asana custom fields…", 2)
                    qnFieldsFetch(function(ok, err)
                        if not ok then
                            hs.alert.show("⚠️ Could not load custom fields: "
                                .. tostring(err) .. " — the note is saved either way", 5)
                            return
                        end
                        pcall(qnFieldsPickerOpen, row)
                    end)
                else
                    pcall(qnFieldsPickerOpen, row)
                end
            end)
        end
    end
end)
_G.choosers.quickNote:placeholderText("Quick note — type it, press Enter, forget it")
pcall(function() _G.choosers.quickNote:width(60) end)
_G.choosers.quickNote:queryChangedCallback(function(query)
    local ok, err = pcall(qnRenderCapture, query)
    if not ok then
        print("🚨 Quick Notes capture render error: " .. tostring(err))
        _G.choosers.quickNote:choices({
            { text = "⚠️ Display error — see Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

-- =====================================================================
-- CUSTOM FIELD PICKER — reached from the capture box
-- =====================================================================
local function qnRenderFields(query)
    local q       = tostring(query or ""):lower():match("^%s*(.-)%s*$")
    local row     = _G.qnFieldRow
    local choices = {}
    if not row then
        _G.choosers.quickNoteFields:choices({ { text = "No note selected" } })
        return
    end

    local picked = qnCountFields(row)
    table.insert(choices, {
        text    = (picked > 0)
                  and ("✅ Done — attach " .. picked .. " field"
                       .. ((picked == 1) and "" or "s"))
                  or "✅ Done — no custom fields",
        subText = qnClip(row.title or row.note, 90),
        qnAction = "done",
    })
    table.insert(choices, {
        text    = "★ Set every field, one at a time",
        subText = "Walks all " .. #qnFields .. " fields in order",
        qnAction = "all",
    })
    if picked > 0 then
        table.insert(choices, {
            text = "✖️ Clear the values I picked", subText = qnFieldsSummary(row),
            qnAction = "clear",
        })
    end
    table.insert(choices, {
        text = "↻ Refresh the field list from Asana", subText = "If you added a field recently",
        qnAction = "refresh",
    })

    for i, def in ipairs(qnFields) do
        local hay = (def.name .. " " .. def.kind):lower()
        if q == "" or hay:find(q, 1, true) then
            local sel = row.fields[def.gid]
            local has = (type(sel) == "table" and sel.label and sel.label ~= "")
            table.insert(choices, {
                text    = (has and "✓ " or "") .. def.name,
                subText = def.kind .. (has and ("   ·   " .. sel.label) or "   ·   Enter sets a value"),
                qnAction = "field", qnField = i,
            })
        end
    end

    _G.choosers.quickNoteFields:choices(choices)
end

qnFieldsPickerOpen = function(row)
    _G.qnFieldRow = row
    qnRenderFields("")
    pcall(function() _G.choosers.quickNoteFields:query("") end)
    showPopup(_G.choosers.quickNoteFields)
end

-- Walks every field in turn for the "★ Set every field" row.
local function qnWalkFields(row, i)
    if i > #qnFields then
        _G.qnWalkTimer = hs.timer.doAfter(0.08, function() pcall(qnFieldsPickerOpen, row) end)
        return
    end
    qnPromptFieldValue(qnFields[i], row, function()
        _G.qnWalkTimer = hs.timer.doAfter(0.08, function() pcall(qnWalkFields, row, i + 1) end)
    end)
end

_G.choosers.quickNoteFields = hs.chooser.new(function(c)
    local row = _G.qnFieldRow
    if not c or not c.qnAction or not row then return end

    if c.qnAction == "done" then
        qnDirty = true; qnSave()
        local n = qnCountFields(row)
        hs.alert.show("🗒 Saved  ·  " .. qnClip(row.title or row.note, 50)
            .. ((n > 0) and ("\n🏷 " .. qnFieldsSummary(row)) or "")
            .. "\nGoes to Asana at " .. qnPostTime, 4)

    elseif c.qnAction == "clear" then
        row.fields = {}
        qnDirty = true; qnSave()
        qnFieldsPickerOpen(row)

    elseif c.qnAction == "refresh" then
        hs.alert.show("⏳ Refreshing custom fields…", 2)
        qnFieldsFetch(function(ok, err)
            if not ok then
                hs.alert.show("⚠️ Refresh failed: " .. tostring(err), 4); return
            end
            hs.alert.show("✅ " .. #qnFields .. " custom field(s) loaded", 2)
            _G.qnChainTimer = hs.timer.doAfter(0.08, function() pcall(qnFieldsPickerOpen, row) end)
        end)

    elseif c.qnAction == "all" then
        _G.qnChainTimer = hs.timer.doAfter(0.08, function() pcall(qnWalkFields, row, 1) end)

    elseif c.qnAction == "field" then
        local def = qnFields[c.qnField]
        if not def then return end
        _G.qnChainTimer = hs.timer.doAfter(0.08, function()
            qnPromptFieldValue(def, row, function()
                _G.qnChainTimer2 = hs.timer.doAfter(0.08, function()
                    pcall(qnFieldsPickerOpen, row)
                end)
            end)
        end)
    end
end)
_G.choosers.quickNoteFields:placeholderText("Custom fields for this note — Enter sets a value")
pcall(function() _G.choosers.quickNoteFields:width(60) end)
_G.choosers.quickNoteFields:queryChangedCallback(function(query)
    local ok, err = pcall(qnRenderFields, query)
    if not ok then
        print("🚨 Quick Notes field render error: " .. tostring(err))
        _G.choosers.quickNoteFields:choices({
            { text = "⚠️ Display error — see Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

-- ---- setting one field's value ---------------------------------------
local function qnRenderEnum(query)
    local q    = tostring(query or ""):lower():match("^%s*(.-)%s*$")
    local def  = _G.qnEnumDef
    local row  = _G.qnFieldRow
    if not def or not row then
        _G.choosers.quickNoteEnum:choices({ { text = "No field selected" } })
        return
    end
    local multi   = (def.kind == "multi_enum")
    local sel     = row.fields[def.gid]
    local chosen  = {}
    if multi and type(sel) == "table" and type(sel.value) == "table" then
        for _, g in ipairs(sel.value) do chosen[tostring(g)] = true end
    end

    local choices = {}
    if multi then
        local n = 0
        for _ in pairs(chosen) do n = n + 1 end
        table.insert(choices, {
            text = "✅ Done — " .. n .. " selected", subText = def.name,
            qnAction = "done",
        })
    end
    table.insert(choices, {
        text = "✖️ No value for " .. def.name, subText = "Leaves this field unset",
        qnAction = "none",
    })
    for i, o in ipairs(def.options) do
        if q == "" or o.name:lower():find(q, 1, true) then
            local isOn = multi and chosen[o.gid]
            table.insert(choices, {
                text    = (isOn and "✓ " or "") .. o.name,
                subText = multi
                          and (isOn and "Enter removes it" or "Enter adds it")
                          or "Enter picks this",
                qnAction = "pick", qnOption = i,
            })
        end
    end
    if #def.options == 0 then
        table.insert(choices, { text = "This field has no options", subText = def.name })
    end
    _G.choosers.quickNoteEnum:choices(choices)
end

local function qnEnumOpen(def, row, done)
    _G.qnEnumDef, _G.qnFieldRow, _G.qnEnumDone = def, row, done
    qnRenderEnum("")
    pcall(function() _G.choosers.quickNoteEnum:query("") end)
    showPopup(_G.choosers.quickNoteEnum)
end

_G.choosers.quickNoteEnum = hs.chooser.new(function(c)
    local def, row, done = _G.qnEnumDef, _G.qnFieldRow, _G.qnEnumDone
    if not def or not row then return end
    -- Dismissed with Esc: treat it as "leave the field alone" and hand
    -- control back, otherwise the walk-all loop would stop dead here.
    if not c or not c.qnAction then
        if done then _G.qnEnumDone = nil; pcall(done) end
        return
    end

    local multi = (def.kind == "multi_enum")

    if c.qnAction == "none" then
        row.fields[def.gid] = nil
        qnDirty = true
        if done then _G.qnEnumDone = nil; pcall(done) end

    elseif c.qnAction == "done" then
        if done then _G.qnEnumDone = nil; pcall(done) end

    elseif c.qnAction == "pick" then
        local o = def.options[c.qnOption]
        if not o then return end
        if multi then
            local sel = row.fields[def.gid]
            local values, labels = {}, {}
            if type(sel) == "table" and type(sel.value) == "table" then
                for _, g in ipairs(sel.value) do
                    if tostring(g) ~= o.gid then table.insert(values, tostring(g)) end
                end
            end
            local wasOn = (type(sel) == "table" and type(sel.value) == "table"
                           and #values < #sel.value)
            if not wasOn then table.insert(values, o.gid) end
            for _, g in ipairs(values) do
                for _, opt in ipairs(def.options) do
                    if opt.gid == g then table.insert(labels, opt.name) end
                end
            end
            if #values == 0 then
                row.fields[def.gid] = nil
            else
                row.fields[def.gid] = {
                    kind = def.kind, value = values, label = table.concat(labels, ", "),
                }
            end
            qnDirty = true
            _G.qnChainTimer = hs.timer.doAfter(0.08, function()
                qnRenderEnum("")
                pcall(function() _G.choosers.quickNoteEnum:query("") end)
                showPopup(_G.choosers.quickNoteEnum)
            end)
        else
            row.fields[def.gid] = { kind = def.kind, value = o.gid, label = o.name }
            qnDirty = true
            if done then _G.qnEnumDone = nil; pcall(done) end
        end
    end
end)
_G.choosers.quickNoteEnum:placeholderText("Pick a value")
pcall(function() _G.choosers.quickNoteEnum:width(50) end)
_G.choosers.quickNoteEnum:queryChangedCallback(function(query)
    local ok, err = pcall(qnRenderEnum, query)
    if not ok then
        print("🚨 Quick Notes enum render error: " .. tostring(err))
        _G.choosers.quickNoteEnum:choices({
            { text = "⚠️ Display error — see Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

qnPromptFieldValue = function(def, row, done)
    done = done or function() end
    if def.kind == "enum" or def.kind == "multi_enum" then
        qnEnumOpen(def, row, done)
        return
    end

    local sel     = row.fields[def.gid]
    local current = (type(sel) == "table" and sel.label) and sel.label or ""
    local hint
    if def.kind == "number" then
        hint = "Enter a number. Leave it empty to unset the field."
    elseif def.kind == "date" then
        hint = "Enter a date as YYYY-MM-DD. Leave it empty to unset the field."
        if current == "" then current = os.date("%Y-%m-%d") end
    elseif def.kind == "people" then
        hint = "Enter an Asana user GID. Leave it empty to unset the field."
    else
        hint = "Enter the text for this field. Leave it empty to unset it."
    end

    local button, text = hs.dialog.textPrompt(def.name, hint .. "\n\nField type: " .. def.kind,
        current, "OK", "Cancel")
    if button ~= "OK" then done(); return end

    text = qnClean(text)
    if text == "" then
        row.fields[def.gid] = nil
        qnDirty = true
        done(); return
    end

    if def.kind == "number" then
        local n = tonumber(text)
        if not n then
            hs.alert.show("⚠️ \"" .. text .. "\" is not a number — " .. def.name .. " left unset", 4)
            done(); return
        end
        row.fields[def.gid] = { kind = def.kind, value = n, label = tostring(n) }
    elseif def.kind == "date" then
        if not text:match("^%d%d%d%d%-%d%d%-%d%d$") then
            hs.alert.show("⚠️ \"" .. text .. "\" is not YYYY-MM-DD — " .. def.name .. " left unset", 4)
            done(); return
        end
        row.fields[def.gid] = { kind = def.kind, value = text, label = text }
    elseif def.kind == "people" then
        row.fields[def.gid] = { kind = def.kind, value = { text }, label = text }
    else
        row.fields[def.gid] = { kind = "text", value = text, label = text }
    end
    qnDirty = true
    done()
end

-- =====================================================================
-- HISTORY — ⇪⇧N · searchable across note, task title, date and status
-- =====================================================================
local function qnRenderHistory(query)
    local q       = tostring(query or ""):lower():match("^%s*(.-)%s*$")
    local choices = {}
    local waiting = #qnPending()
    local posted  = 0
    for _, r in ipairs(qnRows) do if r.status == "posted" then posted = posted + 1 end end

    table.insert(choices, {
        text    = "🗒 " .. #qnRows .. " note" .. ((#qnRows == 1) and "" or "s")
                  .. "   ·   " .. posted .. " in Asana   ·   " .. waiting .. " waiting",
        subText = "Type to search the note, the task title, a date or a status",
        qnAction = "noop",
    })
    if waiting > 0 then
        table.insert(choices, {
            text    = "📤 Send the " .. waiting .. " waiting note"
                      .. ((waiting == 1) and "" or "s") .. " to Asana now",
            subText = "They would otherwise go at " .. qnPostTime,
            qnAction = "sendnow",
        })
    end
    table.insert(choices, {
        text = "🪟 Show the floating panel", subText = "Stays on screen until Esc  ·  ⇪⇧P",
        qnAction = "panel",
    })

    local shown = 0
    for i = #qnRows, 1, -1 do
        local r   = qnRows[i]
        local hay = ((r.title or "") .. " " .. r.note .. " " .. r.date .. " "
                     .. r.time .. " " .. r.status .. " " .. qnFieldsSummary(r)):lower()
        if q == "" or hay:find(q, 1, true) then
            local mark = (r.status == "posted") and "✅"
                         or ((r.status == "failed") and "❌" or "🕓")
            local extra = qnFieldsSummary(r)
            table.insert(choices, {
                text    = mark .. "  " .. qnClip(r.title or r.note, 95),
                subText = r.date .. "  " .. r.time .. "   ·   " .. r.status
                          .. ((extra ~= "") and ("   ·   " .. extra) or "")
                          .. ((r.url ~= "") and "   ·   Enter opens it in Asana"
                              or "   ·   Enter copies the note"),
                qnAction = "open", qnIndex = i,
            })
            shown = shown + 1
            if shown >= qnMaxRows then break end
        end
    end

    if shown == 0 then
        table.insert(choices, {
            text    = (q == "") and "No notes yet" or ("No matches for \"" .. q .. "\""),
            subText = "⇪N captures one",
            qnAction = "noop",
        })
    end

    _G.choosers.quickNoteHistory:choices(choices)
end

qnHistoryOpen = function()
    qnRenderHistory("")
    pcall(function() _G.choosers.quickNoteHistory:query("") end)
    showPopup(_G.choosers.quickNoteHistory)
end

-- =====================================================================
-- FLOATING PANEL — ⇪⇧P · see-through, click-through, Esc closes
-- =====================================================================
-- A canvas, not a window: it takes no focus, and with every mouse event
-- switched off, clicks land on whatever is underneath. That is what lets
-- it sit over your work instead of in front of it.
local function qnPanelHide()
    if qnPanelKeysOn then
        for _, hk in ipairs(qnPanelKeys) do pcall(function() hk:disable() end) end
        qnPanelKeysOn = false
    end
    if qnPanelCanvas then
        pcall(function() qnPanelCanvas:delete() end)
        qnPanelCanvas = nil
    end
end

local function qnPanelOpenIndex(n)
    local r = qnPanelShown[n]
    if not r then hs.alert.show("No row " .. n .. " on the panel"); return end
    qnOpenRow(r, "Row " .. n)
end

local function qnPanelBindKeys()
    if #qnPanelKeys > 0 then return end
    table.insert(qnPanelKeys, hs.hotkey.new({}, "escape", function() qnPanelHide() end))
    for n = 1, qnPanelRowCount do
        local key = tostring(n)
        -- ⇪<n> always works: hyper forwards its chord for any key no
        -- feature has claimed, and 1-9 are unclaimed, so this catches it
        -- without permanently taking the key away from the keyspace.
        table.insert(qnPanelKeys, hs.hotkey.new(
            _G.hyperMods or { "cmd", "ctrl", "alt", "shift" }, key,
            function() qnPanelOpenIndex(n) end))
        if qnPanelBareDigits then
            table.insert(qnPanelKeys, hs.hotkey.new({}, key, function() qnPanelOpenIndex(n) end))
        end
    end
end

qnPanelRender = function()
    if not qnPanelCanvas then return end

    local pad, headH, rowH, footH, panelW = 12, 30, 26, 22, 470
    qnPanelShown = {}
    local n = 0
    for i = #qnRows, 1, -1 do
        n = n + 1
        qnPanelShown[n] = qnRows[i]
        if n >= qnPanelRowCount then break end
    end

    local bodyH  = math.max(rowH, n * rowH)
    local panelH = pad * 2 + headH + bodyH + footH

    local screen = hs.screen.mainScreen()
    pcall(function() screen = resolveBaseScreen() or screen end)
    if not screen then return end
    local sf = screen:frame()
    local margin = 16
    local x = (qnPanelCorner:find("Left")) and (sf.x + margin)
              or (sf.x + sf.w - panelW - margin)
    local y = (qnPanelCorner:find("bottom")) and (sf.y + sf.h - panelH - margin)
              or (sf.y + margin)
    pcall(function() qnPanelCanvas:frame({ x = x, y = y, w = panelW, h = panelH }) end)

    local els = {}
    table.insert(els, {
        type = "rectangle", action = "fill",
        fillColor = { red = 0.07, green = 0.08, blue = 0.10, alpha = qnPanelAlpha },
        roundedRectRadii = { xRadius = 14, yRadius = 14 },
    })
    table.insert(els, {
        type = "rectangle", action = "stroke", strokeWidth = 1,
        strokeColor = { white = 1, alpha = 0.18 },
        roundedRectRadii = { xRadius = 14, yRadius = 14 },
    })
    table.insert(els, {
        type = "text", text = "🗒  Quick Notes → Asana",
        textSize = 15, textColor = { red = 0.5, green = 0.78, blue = 1.0 },
        frame = { x = pad, y = pad, w = panelW - pad * 2, h = headH },
    })

    local waiting = #qnPending()
    table.insert(els, {
        type = "text", text = (waiting > 0) and (waiting .. " waiting") or "all sent",
        textSize = 12, textColor = { white = 0.6 }, textAlignment = "right",
        frame = { x = pad, y = pad + 3, w = panelW - pad * 2, h = headH },
    })

    if n == 0 then
        table.insert(els, {
            type = "text", text = "Nothing captured yet — press ⇪N",
            textSize = 13, textColor = { white = 0.7 },
            frame = { x = pad, y = pad + headH, w = panelW - pad * 2, h = rowH },
        })
    end

    for i = 1, n do
        local r  = qnPanelShown[i]
        local ry = pad + headH + (i - 1) * rowH
        local dot = (r.status == "posted") and { red = 0.35, green = 0.82, blue = 0.45, alpha = 1 }
                    or ((r.status == "failed") and { red = 0.95, green = 0.42, blue = 0.42, alpha = 1 }
                        or { red = 0.98, green = 0.76, blue = 0.32, alpha = 1 })
        table.insert(els, {
            type = "circle", action = "fill", fillColor = dot,
            center = { x = pad + 6, y = ry + rowH / 2 }, radius = 4,
        })
        table.insert(els, {
            type = "text", text = tostring(i),
            textSize = 12, textColor = { white = 0.55 }, textAlignment = "right",
            frame = { x = pad + 12, y = ry + 3, w = 16, h = rowH },
        })
        table.insert(els, {
            type = "text", text = qnClip(r.title or r.note, 52),
            textSize = 13, textColor = { white = (r.status == "posted") and 0.95 or 0.75 },
            frame = { x = pad + 34, y = ry + 3, w = panelW - pad * 2 - 34 - 46, h = rowH },
        })
        table.insert(els, {
            type = "text", text = r.time,
            textSize = 11, textColor = { white = 0.45 }, textAlignment = "right",
            frame = { x = panelW - pad - 46, y = ry + 4, w = 46, h = rowH },
        })
    end

    table.insert(els, {
        type = "text",
        text = (qnPanelBareDigits and "1-9" or "⇪1-⇪9") .. " opens in Asana   ·   Esc closes",
        textSize = 11, textColor = { white = 0.5 }, textAlignment = "center",
        frame = { x = pad, y = panelH - footH - 4, w = panelW - pad * 2, h = footH },
    })

    -- replaceElements with a single table is how hs.canvas is meant to be
    -- driven, but the only shape PROVEN by the rest of this file is
    -- appendElements(table) (§1.6's cheat sheet). If the first call ever
    -- stops behaving, fall back to that instead of silently drawing an
    -- empty panel — a blank rectangle floating over your work would be
    -- worse than no panel at all.
    if not pcall(function() qnPanelCanvas:replaceElements(els) end) then
        pcall(function()
            while #qnPanelCanvas > 0 do qnPanelCanvas:removeElement() end
            qnPanelCanvas:appendElements(els)
        end)
    end
end

local function qnPanelShow()
    qnPanelHide()
    local ok, canvas = pcall(function()
        return hs.canvas.new({ x = 0, y = 0, w = 470, h = 200 })
    end)
    if not ok or not canvas then
        hs.alert.show("❌ Could not draw the Quick Notes panel — see Console")
        return
    end
    qnPanelCanvas = canvas
    -- `floating` (3), NOT `overlay` (102): overlay sits ABOVE hs.chooser's
    -- popUpMenu level (101), which is exactly how the App Lock cover ended
    -- up burying its own PIN prompt in 6.30.0. Floating clears every
    -- ordinary app window and still stays under our own pickers.
    pcall(function() qnPanelCanvas:level(hs.canvas.windowLevels.floating) end)
    pcall(function()
        qnPanelCanvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary", "stationary" })
    end)
    -- Every mouse event off: the panel cannot be clicked, so clicks go
    -- straight through to the window underneath. This is the whole reason
    -- it can be left up while you work.
    pcall(function() qnPanelCanvas:canvasMouseEvents(false, false, false, false) end)
    qnPanelRender()
    pcall(function() qnPanelCanvas:show() end)

    qnPanelBindKeys()
    if not qnPanelKeysOn then
        for _, hk in ipairs(qnPanelKeys) do pcall(function() hk:enable() end) end
        qnPanelKeysOn = true
    end
end

local function qnPanelToggle()
    if qnPanelCanvas then qnPanelHide() else qnPanelShow() end
end

_G.choosers.quickNoteHistory = hs.chooser.new(function(c)
    if not c or not c.qnAction or c.qnAction == "noop" then return end
    if c.qnAction == "sendnow" then
        qnRunSync(true)
    elseif c.qnAction == "panel" then
        _G.qnChainTimer = hs.timer.doAfter(0.08, function() pcall(qnPanelShow) end)
    elseif c.qnAction == "open" then
        qnOpenRow(qnRows[c.qnIndex], "That note")
    end
end)
_G.choosers.quickNoteHistory:placeholderText("Quick notes — search text, title, date or status")
pcall(function() _G.choosers.quickNoteHistory:width(60) end)
_G.choosers.quickNoteHistory:queryChangedCallback(function(query)
    local ok, err = pcall(qnRenderHistory, query)
    if not ok then
        print("🚨 Quick Notes history render error: " .. tostring(err))
        _G.choosers.quickNoteHistory:choices({
            { text = "⚠️ Display error — see Hammerspoon Console", subText = tostring(err) },
        })
    end
end)

-- ---- wiring ----------------------------------------------------------
qnLoad()
qnFieldsLoadCache()

_G.hyperAddShortcut({}, "n", function() qnCaptureOpen("") end, "quick note capture")
_G.hyperAddShortcut({ "shift" }, "n", function() qnHistoryOpen() end, "quick note history")
_G.hyperAddShortcut({ "shift" }, "p", function() qnPanelToggle() end, "quick note panel")
_G.hyperAddShortcut({ "shift" }, "g", function() qnRunSync(true) end, "quick note send now")

-- Held in _G. so the garbage collector cannot quietly cancel them — the
-- same trap that silently killed the App Monitor's timers in 6.16.
_G.qnDailyTimer = hs.timer.doAt(qnPostTime, "1d", function() pcall(qnRunSync, false) end)

-- Backstop for the two ways doAt alone loses a day: the Mac asleep at
-- 4 PM, and a config reload after 4 PM. Posting can never double up —
-- only "pending" rows are sent, and posting flips the row immediately.
_G.qnCatchUpTimer = hs.timer.doEvery(1800, function()
    if qnRunIsDue() then pcall(qnRunSync, false) end
end)
_G.qnBootCatchUpTimer = hs.timer.doAfter(25, function()
    if qnRunIsDue() then pcall(qnRunSync, false) end
end)

-- WATCHDOG. Two things here would be genuinely bad if they wedged, so
-- neither is left to chance: a panel that vanished while still holding
-- the number keys would silently eat your digits everywhere, and a sync
-- that never called its callback would block every later send. Both are
-- released here, 30s at a time.
_G.qnWatchdog = hs.timer.doEvery(30, function()
    if qnPanelKeysOn and not qnPanelCanvas then
        for _, hk in ipairs(qnPanelKeys) do pcall(function() hk:disable() end) end
        qnPanelKeysOn = false
        print("🗒 Quick Notes: released the panel's number keys — the panel was gone")
    end
    if qnSyncing and (os.time() - qnSyncStarted) > 120 then
        qnSyncing = false
        print("🗒 Quick Notes: a send never reported back after 120s — unblocking the next one")
    end
    if qnDirty then pcall(qnSave) end
end)

-- One line for the boot report, so a Console log always says whether
-- Quick Notes actually came up and how much is queued.
_G.qnStatusForBoot = function()
    if not asanaEnabled then
        return "capture ON, sending OFF (no secret.lua) · " .. #qnRows .. " note(s)"
    end
    return #qnRows .. " note(s) · " .. #qnPending() .. " waiting · sends at " .. qnPostTime
end

-- Test hooks, in the style of the rest of this file.
_G.qnTitleForTest      = qnTitleFor
_G.qnCleanForTest      = qnClean
_G.qnDateStatementTest = qnDateStatement
_G.qnRowsForTest       = function() return qnRows end
_G.qnAddForTest        = qnAdd
_G.qnFileForTest       = qnFile
_G.qnLoadForTest       = qnLoad
_G.qnSaveForTest       = function() qnDirty = true; qnSave() end
_G.qnSplitCSVForTest   = qnSplitCSV
_G.qnValidDateForTest  = qnValidDate
_G.qnValidTimeForTest  = qnValidTime
_G.qnRunIsDueForTest   = qnRunIsDue
_G.qnFieldsForTest     = function() return qnFields end
_G.qnFieldsFetchTest   = qnFieldsFetch
_G.qnFieldsPayloadTest = qnFieldsPayload
_G.qnFieldsSummaryTest = qnFieldsSummary
_G.qnFieldsPickTest    = function(row) qnFieldsPickerOpen(row) end
_G.qnPanelShowForTest  = qnPanelShow
_G.qnPanelHideForTest  = qnPanelHide
_G.qnPendingForTest    = qnPending

end)() -- X.2 Quick Notes → Asana

-- =====================================================================
-- X.3 SEND A WINDOW TO ANOTHER DESKTOP (SPACE) — ⇪⇧[ and ⇪⇧]
-- =====================================================================
-- The bracket keys already mean "throw this window somewhere else":
--   ⇪[  ⇪]    → the next MONITOR   (physical display)
--   ⇪⇧[ ⇪⇧]   → the next DESKTOP   (macOS Space, same monitor)
-- Bare is the physical axis, shift is the virtual one.
--
-- ⚠️ READ THIS BEFORE TRUSTING IT. Everything below rides on hs.spaces,
-- which drives PRIVATE CoreGraphics calls that Apple does not support
-- and has changed between macOS releases. Hammerspoon has removed and
-- reinstated this module more than once. That is categorically shakier
-- ground than the rest of this file, all of which uses public API, so
-- it is built to fail loudly and specifically instead of silently:
-- every failure path says which step broke. If a macOS update breaks
-- it, ⇪⇧[ / ⇪⇧] will tell you so rather than doing nothing.
--
-- KNOWN LIMITS, none of which are fixable from here:
--   • A native full-screen window cannot be moved between desktops —
--     macOS gives it a space of its own. Guarded, with a message.
--   • Full-screen spaces are excluded from the ordering. Counting them
--     would make the key land on a space nothing can move into.
--   • Needs Accessibility permission (System Settings → Privacy &
--     Security → Accessibility → Hammerspoon).
--   • With "Displays have separate Spaces" OFF, macOS treats all
--     monitors as one desktop set; the count reflects whatever it says.
--
-- Self-contained: borrows focusedStandardWindow, guardNotFullScreen and
-- rememberFrame from §2 and _G.hyperAddShortcut. Delete the block and
-- nothing else changes.
(function()

-- All state in _G. — the main chunk sits at Lua's 200-local ceiling.
_G.spaceMoveAvailable = nil   -- nil = not probed yet

-- Probe once and cache. Checking on every keypress would mean a pcall
-- storm on a build that simply does not ship the module.
_G.spaceMoveProbe = function()
    if _G.spaceMoveAvailable ~= nil then return _G.spaceMoveAvailable end
    local ok = pcall(function() return hs.spaces end)
    _G.spaceMoveAvailable = ok
        and type(hs.spaces) == "table"
        and hs.spaces.focusedSpace      ~= nil
        and hs.spaces.spacesForScreen   ~= nil
        and hs.spaces.moveWindowToSpace ~= nil
        and hs.spaces.gotoSpace         ~= nil
    return _G.spaceMoveAvailable
end

-- Only ordinary desktops are valid targets.
_G.spaceUserSpaces = function(screen)
    local out = {}
    local ok, all = pcall(hs.spaces.spacesForScreen, screen)
    if not ok or type(all) ~= "table" then return out end
    for _, id in ipairs(all) do
        local t
        pcall(function() t = hs.spaces.spaceType(id) end)
        -- Older builds have no spaceType. Treating nil as "user" keeps
        -- those working; dropping them would leave an empty list and
        -- make the feature look broken on a build where it works fine.
        if t == nil or t == "user" then out[#out + 1] = id end
    end
    return out
end

_G.spaceMoveFocused = function(direction)
    if not _G.spaceMoveProbe() then
        print("🖥 Space move: hs.spaces missing on this Hammerspoon build")
        hs.alert.show("🖥 This Hammerspoon has no Spaces support")
        return
    end

    local win = focusedStandardWindow()
    if not win then hs.alert.show("🖥 No window in focus") return end
    -- Reuses §2's guard so the message matches the monitor keys.
    if not guardNotFullScreen(win) then return end

    local screen = win:screen()
    local ids = _G.spaceUserSpaces(screen)
    if #ids < 2 then
        hs.alert.show("🖥 Only one desktop — add one in Mission Control")
        return
    end

    local cur
    pcall(function() cur = hs.spaces.focusedSpace() end)
    local idx
    for i, id in ipairs(ids) do if id == cur then idx = i break end end
    if not idx then
        print("🖥 Space move: focused space " .. tostring(cur)
            .. " is not in this screen's list — likely a full-screen space")
        hs.alert.show("🖥 Can't tell which desktop this is")
        return
    end

    -- Wraps both ways, like the monitor keys do.
    local nextIdx = (direction == "next")
        and (idx % #ids) + 1
        or  ((idx - 2) % #ids) + 1
    local target = ids[nextIdx]

    rememberFrame(win)
    local ok = pcall(hs.spaces.moveWindowToSpace, win, target)
    if not ok then
        print("🖥 Space move: moveWindowToSpace failed for " .. tostring(target))
        hs.alert.show("🖥 Move failed — check Accessibility permission")
        return
    end

    pcall(hs.spaces.gotoSpace, target)
    -- Mission Control animates the switch; focusing before it settles
    -- lands on the old desktop. This delay is the animation, not a guess
    -- at how slow the machine is.
    hs.timer.doAfter(0.35, function() pcall(function() win:focus() end) end)
    hs.alert.show("🖥 → Desktop " .. nextIdx .. " of " .. #ids)
end

_G.hyperAddShortcut({"shift"}, "]",
    function() _G.spaceMoveFocused("next") end, "window to next desktop")
_G.hyperAddShortcut({"shift"}, "[",
    function() _G.spaceMoveFocused("prev") end, "window to previous desktop")

-- Test seams (same convention as X.2).
_G.spaceMoveForTest      = function(d) _G.spaceMoveFocused(d) end
_G.spaceUserSpacesForTest = function(s) return _G.spaceUserSpaces(s) end

end)() -- X.3 desktop/space mover

-- // EXPERIMENTAL SECTION END                //
-- /////////////////////////////////////////////
-- ////////////////////////////////////////////

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
if _G.hyperFinalize then _G.hyperFinalize() end

-- ---- EmmyLua: editor autocomplete for the hs.* API -----------------
-- WHAT THIS ACTUALLY IS, in plain terms: it writes out a set of files
-- describing every Hammerspoon function — its name, what arguments it
-- takes, what it hands back. A code editor that speaks the Lua language
-- server protocol reads those files and can then finish `hs.pasteboard.`
-- for you and underline a call you got wrong WHILE YOU TYPE, instead of
-- you finding out after a reload when something quietly does nothing.
--
-- That last part is why it is here. Several real bugs in this file's
-- history were exactly that shape: hs.pasteboard.readURL returning a
-- different type than assumed, and a canvas replaceElements call whose
-- signature was in doubt. Both were "wrong API usage that parses fine"
-- — invisible to luac, visible to a language server.
--
-- IT COSTS NOTHING AT RUNTIME. It generates the files and stops. No
-- hotkey, no timer, no watcher, nothing on the main thread afterwards.
-- Not installed? One console line and the config carries on, so this
-- stays portable to a Mac that has never heard of it.
--
-- ⚠️ THE GENERATED FILES ALONE DO NOTHING. They are half the setup —
-- your EDITOR has to be pointed at them. See the README's EmmyLua
-- section for that half; CotEditor cannot use them at all.
(function()
    local home = os.getenv("HOME") or ""
    local spoonPath = home .. "/.hammerspoon/Spoons/EmmyLua.spoon"
    local there = false
    pcall(function() there = hs.fs.attributes(spoonPath) ~= nil end)
    if not there then
        print("💡 EmmyLua not installed — hs.* editor autocomplete is off.")
        print("   Get it: https://www.hammerspoon.org/Spoons/EmmyLua.html")
        print("   Then point your editor at Spoons/EmmyLua.spoon/annotations")
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

-- 6.31.4 — ONE version string, not three. Three separate literals is
-- exactly how 6.31.1 shipped with a stale 6.30.0 in the tool index: two
-- got bumped, one did not. The header banners are comments and cannot
-- read this, but everything executable now derives from here.
_G.configVersion  = "6.31.4"
_G.changelogNote  = "Tracker row cap, changelog CSV, EmmyLua annotations"

-- ---- changelog.csv -------------------------------------------------
-- Date | Version | Change notes, appended once per version on first
-- boot. Never duplicated: an existing row for this version wins.
(function()
    local path = logsDir .. "/changelog.csv"
    local seen, hasHeader = {}, false
    local fh = io.open(path, "r")
    if fh then
        for line in fh:lines() do
            if line:match("^Date,") then
                hasHeader = true
            else
                local v = line:match("^[^,]*,([^,]*),")
                if v and v ~= "" then seen[v] = true end
            end
        end
        fh:close()
    end
    if seen[_G.configVersion] then return end
    local out = io.open(path, "a")
    if not out then warnWriteFailed("changelog CSV") return end
    if not hasHeader then out:write("Date,Version,Change notes\n") end
    out:write(os.date("%Y-%m-%d") .. "," .. _G.configVersion .. ","
        .. csvQuote(_G.changelogNote) .. "\n")
    out:close()
    print("📋 changelog.csv: logged " .. _G.configVersion)
end)()

print("📌 init.lua ARCHITECTURE VERSION: " .. _G.configVersion)
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
print("   App Lock: " .. (_G.appLockStatusForBoot and _G.appLockStatusForBoot() or "off"))
print("   Quick Notes: " .. (_G.qnStatusForBoot and _G.qnStatusForBoot() or "off"))
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
