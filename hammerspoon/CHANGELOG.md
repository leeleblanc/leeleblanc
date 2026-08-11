# Hammerspoon config — changelog

Full version history for `init.lua`. The five most recent entries are
also kept inline at the top of the file; everything older lives only here.

```text
NEW IN 6.60.0 — THE APP MONITOR PING BECOMES A SEQUENCE, AND GETS TESTED:
  🔊 ONE SECOND, AND A DIFFERENT SOUND EVERY TIME. The waiting popup now
     pings every 1s instead of 2s, and each ping takes the next entry
     from a ten-name list: Hero, Glass, Sosumi, Submarine, Basso, Ping,
     Funk, Morse, Bottle, Blow. Ordered loudest-first so the opening
     seconds are the ones most likely to reach another room. Ten sounds
     at one second each is the ten seconds LL asked for.
  🔁 AND THEN IT WRAPS, RATHER THAN ENDING. This is the one real design
     decision in the change, and it is deliberate. The popup has waited
     INDEFINITELY since 6.16.21 — no auto-dismiss — precisely so that
     being away from the desk cannot let a closed app go unnoticed. A
     sound sequence that simply ran out after ten seconds would hand
     that failure straight back: the popup would still be there, but
     nothing would be calling you to it. So after ten seconds the list
     starts again, and the only thing that ever stops it is answering.
  🔉 WORTH KNOWING, SINCE IT IS A REAL TRADE: this is now a once-per-
     second sound that can run for hours if a Mac is left alone. Louder
     than the old 2s single ping by design. If it proves too much, the
     interval and the list are two separate constants at the top of
     modules/app_watcher.lua and either can be tuned without touching
     the other — a longer interval keeps the variety, a shorter list
     keeps the urgency.
  🧯 A MISSPELLED NAME NOW COSTS ONE SOUND, NOT ALL OF THEM. Every name
     is resolved once when the popup opens, and any that fail to resolve
     are dropped there rather than re-checked forever; the sequence
     closes the gap and carries on. The old single-constant version
     turned one typo into total silence.
  ⚠️ THE KNOWN GAP IS UNCHANGED AND STILL RECORDED: if EVERY name is
     wrong you get a silent popup and nothing explains why. That is the
     class of silent failure the notice ledger exists to abolish;
     app_watcher predates it and wiring it in was offered and declined.
     Now pinned by a test, so the behaviour is at least described rather
     than merely happening.
  ⏱ RESOLVED ONCE, NOT ON EVERY TICK. hs.sound.getByName goes out to the
     system. Calling it inside a one-second timer that may run for hours
     would be thousands of lookups for an answer that cannot change.
  🧪 AND THE PART THAT WAS MISSING: NOTHING IN THE SUITE HAD EVER
     EXECUTED THIS CODE. As one constant and one unconditional play()
     there was arguably nothing to test. As a resolve-and-filter loop
     plus a wrapping index there certainly is — an off-by-one that skips
     the first sound, a wrap that throws when the list runs out, and a
     resolution failure that takes the sequence down with it are all
     things this shape can now get wrong.
  🧪 tests/test_app_watcher DRIVES THE REAL MODULE through a stub hs —
     real setup(), real application-watcher callback, real timer
     function — rather than re-implementing the sequence and checking a
     copy of it. That distinction is not pedantry here: this config has
     already shipped a suite that passed while the real code was broken.
     27 checks: the first sound is immediate, ten seconds gives ten
     DIFFERENT sounds in the configured order, ping 11 wraps and ping 21
     wraps again, the interval is 1s, one bad name is survivable, and an
     entirely bad list fails silent rather than throwing.
  🔬 ALL SIX MUTATIONS CAUGHT: wrap removed, off-by-one on the index,
     interval reverted to 2s, a bad name aborting the whole list, the
     list reordered, and the initial pre-timer ping dropped.
  🧪 1,663 checks across sixteen Lua suites, plus 35 executed in the
     Capture Pad page JavaScript — 1,698 in total, counted from the
     runner's own output rather than added up by hand.
  🙈 AND ONE MORE INSTRUMENTATION BUG, LOGGED BECAUSE IT IS THE SAME
     FAMILY AS THE OTHERS: the first run of the new suite printed
     NOTHING and looked like a pass. The harness silences print() while
     the module runs, and swallowed its own output along with it. Test
     output goes through io.write now.

NEW IN 6.59.0 — TWO SMALL THINGS, BOTH OF THEM "IT WAS LYING TO YOU":
  🔊 APP MONITOR NOW SOUNDS "Hero" INSTEAD OF "Ping". Purely LL's
     choice, and the reasoning is worth keeping: since 6.16.21 the
     popup has had NO auto-dismiss — it waits indefinitely and pings
     every 2 seconds until answered — precisely so that being away
     from the desk cannot cause a closed app to go unnoticed. That
     design only works if the sound survives the distance. Ping does
     not always carry; Hero does.
  🎛 THE SETTING IS ONE CONSTANT, ON PURPOSE. appMonitorSoundName near
     the top of modules/app_watcher.lua feeds BOTH the initial alert
     and the repeating ping timer, so the two can never drift apart,
     and changing it again is a one-word edit plus a reload. The
     comment block above it now lists all fourteen built-in macOS
     sounds grouped by how much they carry, so the next change does
     not require going and looking them up.
  ⚠️ WHAT IS DELIBERATELY *NOT* FIXED HERE, RECORDED SO IT IS NOT
     FORGOTTEN: hs.sound.getByName is pcall-wrapped and its result is
     nil-checked, which means a MISSPELLED SOUND NAME PRODUCES NO
     SOUND AND NO ERROR — the popup still appears, silently, and
     nothing says why. That is exactly the class of silent failure the
     notice ledger exists to abolish; app_watcher predates it and was
     never wired in. Routing the miss into notices was offered for
     this release and declined in favour of the sound change alone.
     The constant's comment now warns about it in plain language
     ("if you change this and hear nothing, the spelling is the first
     suspect"), which is a smaller guarantee than the ledger but not
     nothing. Still outstanding.
  🩺 hs-doctor WAS CALLING A WORKING HYPER KEY "unexpected". Section 6
     tested for the Caps-Lock HID usage as the literal hex string
     0x700000039, but `hidutil property --get UserKeyMapping` returns
     DECIMAL on a real Mac — 30064771129, the same number written the
     other way. A correct remap therefore never matched, fell through
     to the error branch, and echoed the entire raw property list —
     once per HID device carrying the mapping, which in practice runs
     to a hundred-plus near-identical blocks scrolling past someone
     who has just been told something is wrong when nothing is.
  ✅ CONFIRMED AGAINST A REAL REPORT, not reasoned about: 30064771129
     = 0x700000039 (Caps Lock) and 30064771181 = 0x70000006D (F18) —
     exactly the remap this config installs. The diagnostic was wrong;
     the Mac was fine. Both forms are matched now, decimal first,
     since decimal is what actually appears.
  📉 AND THE ERROR BRANCH IS NOW READABLE. A genuinely wrong mapping
     prints the UNIQUE Src/Dst pairs rather than every repeated
     registry entry. A diagnostic that scrolls its own answer off the
     screen is not a diagnostic, and the repeat count is a property of
     how many HID devices are registered, not of the problem.
  🧪 Fixture-tested five ways before shipping: decimal mapping, hex
     mapping, empty output, "(null)", and a wrong mapping repeated
     four times (collapses to two lines). Full Lua suite green.

NEW IN 6.58.0 — THE INSTALLER CAUGHT WHAT THE TEST SUITE MISSED:
  🚨 REAL INSTALL, REAL FAILURE, WORKING SAFETY NET. Running
     hs-install.sh for real (not --dry-run) failed verification on
     "core/notices-not-an-initialiser" and rolled itself back
     automatically — exactly the job that check exists to do. Nothing
     on the Mac broke; it landed back on 6.54.0, untouched, with an
     explicit "do NOT reload" so there was never a moment of doubt
     about what state it was in.
  🔍 THE BUG: core/notices.lua was written as a bare `return notices`
     table and loaded with a bare `chunk()` — every one of the other
     four core/ files is `return function(core) ... end`, called as
     `chunk()(coreTable)`. It happened to run fine either way, because
     nothing inside notices.lua ever reads `core` — but "happens to
     run" and "matches the shape the installer promises to verify" are
     different claims, and the installer checks the second one on
     purpose. It refused rather than trust a file that merely worked.
  🩹 THE FIX: notices.lua now returns `function(core) ... end` like its
     siblings. Its call site in init.lua passes `{}` rather than the
     usual per-machine table, because notices loads BEFORE hostTag and
     logsDir exist as locals — deliberately, so it can report a module
     that fails to load. Moving the load point later to hand it real
     values would undo the reason it loads first. An honest empty table
     beats reordering fragile boot code to make one argument non-empty.
  🕳 THE GAP THIS EXPOSES: NOTHING IN THE TEST SUITE HAD EVER CHECKED
     THIS SHAPE. dofile()-ing a core file in a test does not care what
     it returns, so four releases shipped with this bug and every one
     of them passed the full suite. The installer's independent verify
     step was the only thing that ever looked. Closed now: an audit
     reads every file in core/ from DISK (not a retyped list — the same
     fix applied to the stale MODS list a few releases back) and checks
     it is `return function(core)`; a second pass reads init.lua's own
     load sites and checks each one calls its chunk with an argument.
     Verified by reverting notices.lua to the broken shape and by
     reverting init.lua's call site to a bare chunk() — the suite
     catches each independently.
  🧪 1,663 checks across sixteen Lua suites.

NEW IN 6.57.0 — THREE SHORTCUTS THAT WERE DYING SILENTLY, AND A LARGER PANEL:
  🚨 THE COLLISION test_integration NEVER CHECKED FOR. It loads all
     modules together and catches module-vs-module key clashes — but
     §0.4's hyper MIGRATION MAP lives in init.lua, outside that
     comparison, and three new modules had quietly claimed keys it
     already pointed somewhere else:
        ⇪F      focus_mode     vs   the FILE TRACKER (⌃⌥⇧F migrated)
        ⇪W      workspaces     vs   the SUMMON-AN-APP PICKER (⌃⌥W)
        ⇪⇧R     bulk_rename    vs   RESET NUDGE OFFSET (⌘⌃⌥⇧R)
     Each one printed a single "HYPER CONFLICT" line at boot and then
     silently killed the OLDER, working shortcut — "the later one wins"
     is correct Lua table semantics and the worst possible UX. Found
     from a real Console log, not from the suite.
  🔀 THE FIX, and a new test that makes the class impossible again:
        focus mode     → ⇪Q  ("Quiet") · ⇪⇧Q report
        workspaces     → ⇪⇧S ("Spaces")
        bulk rename    → undo moved OFF ⇪⇧R entirely, onto the picker's
                          own first row when there is a batch to undo —
                          the same pattern Workspaces already uses for
                          its reset, discovered rather than invented
     New code yields to what already works. test_diagnostics now reads
     §0.4's migration map and every module's hyperAddShortcut calls from
     the SAME source pass and fails if any two ever name the same chord
     — verified by reverting focus_mode to ⇪F and watching it catch it.
  📐 THE CHEAT SHEET IS 1024×768 BY DEFAULT, both configurable
     (cheatSheet.width / .height), both still clamped to the screen so
     neither can ever open larger than the display. Worth knowing which
     way the trade runs: WIDTH is free — a wider column means fewer
     entries wrap onto continuation lines, so 1024 shows MORE at once
     than 760 did — but HEIGHT is not: at 30pt a row, 768 shows roughly
     22 rows against the old ceiling's 36. The 86%-of-screen ceiling
     stayed, because a naive fixed clamp produced a panel covering 95%
     of a 1280×800 laptop screen, caught by the suite before shipping.
  🗓 THE HEADER DATE NOW TRACKS THE VERSION. It sat on 08-05-26 for a
     dozen releases while the version marker moved past it, so the one
     line a person reads first was quietly wrong — the same species of
     drift as this release's hyper-key bug, just in prose instead of
     code. Bumped every release from now on; asserted in the suite.
  🧪 1,655 checks. Also fixed in passing: the audit's own MODULE list
     had drifted to 18 of 26 files and was silently covering barely two
     thirds of the config — replaced with a read of init.lua's actual
     default profile, the same source test_integration already trusts.

NEW IN 6.56.0 — THE PHANTOM PANEL, AND WHY IT WAS NOT OUR CRASH:
  👻 REPORTED FROM A REAL MAC: pressing ⇪/ while Safari's address-bar
     autocomplete was open threw
        NSInternalInconsistencyException: '<NSRemoteView …
        SPCompletionListServiceViewController> notified of
        <HSCanvasWindow> but expected (null)'
     — and left a panel on screen that would not close, with the
     Console filling for minutes with alternating "Disabled / Re-enabled
     previous hotkey UP DOWN HOME END PAGEUP PAGEDOWN ESCAPE".
  🔍 THE THROW IS NOT OURS AND CANNOT BE PREVENTED. Ordering ANY window
     on screen makes AppKit post a notification that every observer
     receives — including Safari's completion list, which lives in
     ANOTHER PROCESS behind an NSRemoteView. If that view is
     mid-transition when the notification lands, its own assertion fires,
     inside Safari, about a window Safari does not own. No argument to
     :show() avoids it.
  🚨 WHAT WAS OURS WAS THE DAMAGE, and the damage was the whole symptom.
     canvas:show() was UNPROTECTED, so the throw abandoned the rest of
     the open sequence: _G.cheatSheetCanvas had already been set, and
     enableInput() never ran. The config then believed the sheet was
     open while the canvas sat half-ordered on screen — a panel you
     could see, could not scroll, and could not close, because every
     later ⇪/ took the hide() branch. Those are exactly the alternating
     hotkey lines. The phantom panel was not the exception; it was
     everything after the exception not happening.
  🩹 THE FIX, at all three canvas:show() sites: catch it, RETRY ONCE on
     the next run loop turn — this is a timing collision with another
     process, not a permanent state, so a moment later it works — and if
     it still refuses, say so through the 6.54.0 notice ledger instead
     of leaving a ghost behind. enableInput() now runs either way, so
     ⇪/ is never left toggling a panel you cannot use.
  🧪 REPRODUCED IN THE SUITE. The cheat sheet's canvas stub can now be
     told to throw exactly as AppKit did, and the test asserts the
     exception does not escape into the hotkey callback, that the input
     keys are still bound afterwards, and that the sheet reopens
     cleanly. Restoring the unprotected show() fails it.
  🧪 1,644 checks across sixteen Lua suites.

NEW IN 6.55.0 — CLIPBOARD HISTORY BECOMES A MODULE:
  📋 IT LIVED IN init.lua, IN FOUR SEPARATE PLACES: the file path in
     §0.2, load and save in §2, the dedupe buried inside the pasteboard
     watcher in §3, and two choosers in §5. Every one of those lines ran
     BEFORE the module loader — the stretch where a single error takes
     the WHOLE config down instead of costing you one feature. It is now
     modules/clipboard_history.lua, on ⇪V and ⇪⇧V. init.lua lost 190
     lines and clipboard history gained somewhere to be tested.
  🔗 ONE PIECE STAYED BEHIND, DELIBERATELY. The pasteboard watcher is
     SHARED with image OCR: one timer, one changeCount, choosing between
     copied image files, a raw image and text. Splitting it would mean
     two timers polling the same counter and racing over which handled a
     change first. So the watcher stays and calls clipboard.add through
     the service registry — and if the module is ever switched off, it
     gets no provider, says so once, and OCR carries on.
  🚨 AND THE MOVE INTRODUCED A DATA-LOSS BUG, WHICH THE NEW TESTS CAUGHT
     BEFORE IT SHIPPED. Reading the file was deferred to warm() to keep
     a possible megabyte off the boot path — correct on its own, but it
     opened a two-second window in which a copy would call save() and
     write a ONE-ITEM file straight over the real history. warm() would
     then dutifully load that back, having destroyed everything. Copies
     made before the file is in are now HELD and re-applied on top of it
     afterwards, and nothing is written until the file has been read.
     That property is exactly why the move needed its own suite rather
     than being done quickly.
  🧪 THE SOURCE AUDIT BECAME A REAL TEST. 6.52.0 could only check from
     SOURCE that an edit copies to the clipboard and that the cache is
     written before the pasteboard, because the code sat in init.lua
     with nothing to drive it. The module can be run, so those are now
     assertions about behaviour — including the one that matters most:
     the watcher waking on our own write does NOT add a second row,
     because the dedupe lifts the edited entry instead of copying it.
  🧪 The stub had to learn to fail properly, too. hs.json.decode RAISES
     on malformed input; the first version of the test's stand-in
     quietly returned an empty table, so the "unreadable file is backed
     up" branch was never reached and a working guard looked untested
     when it was merely unexercised.
  🧪 1,641 checks across sixteen Lua suites.

NEW IN 6.54.0 — NOTHING FAILS SILENTLY: THE NOTICE LEDGER (7g/7d/7e/6):
  🔔 ONE LEDGER, AND SURFACES THAT READ FROM IT. Every failure — a module
     that would not load, a runtime error, a failed shell hook — records
     into core/notices.lua, and that file alone decides whether, how and
     when you are told. Twenty-five modules each calling hs.notify would
     be twenty-five slightly different behaviours, twenty-five chances to
     forget, and nowhere that knows whether you have already been told.
     Add a surface later and every existing failure flows into it free.
  🔕 AND THE UNCOMFORTABLE PART, which is why 7d was needed at all: FOCUS
     MODE TURNS DO NOT DISTURB ON DURING MEETINGS, and macOS then
     SWALLOWS notifications WITHOUT REFUSING THEM. A hs.notify that
     "succeeded" can have shown you nothing, so a failure during a
     meeting could vanish entirely. Notices raised while Focus is on are
     now HELD and delivered when it ends — as ONE combined message, since
     coming out of a meeting to twelve stacked alerts is its own kind of
     failure. The queue is bounded and drops the OLDEST, because the
     recent ones are the ones still true when you get back.
     · WHAT CAN HONESTLY BE KNOWN about Focus: macOS has no public API.
       Two things are reliable — whether THIS config turned Focus on
       (exact, we did it), and the Do Not Disturb assertions file. When
       neither is conclusive it assumes NOT suppressed and shows you.
       That direction is deliberate: a notice shown during Focus is a
       mild annoyance, a notice silently swallowed is the whole bug.
     · hs.alert IS ALWAYS USED AS WELL, not as a nicety. Notification
       Centre can be switched off for Hammerspoon entirely and nothing
       tells us; hs.alert draws on the screen and obeys neither that nor
       Focus. It is what makes the guarantee true rather than hopeful.
  🆗 ONE SIGNAL AT LOGIN, AND ONLY WHEN IT MEANS SOMETHING. A clean boot
     gets a brief "ready" flash — the FadeLogo idea, natively, no Spoon —
     so a quiet Mac is never ambiguous between "fine" and "never
     started". A module that failed to load gets an alert NAMING it, and
     shown even during Focus, because a tool that did not load is wrong
     for the whole session. Silence means it worked; you are never asked
     to go and check.
     · ON A TIMER, NOT INLINE: an alert fired during the boot chunk can
       land before the screen is ready at login and simply not be seen,
       which would make the mechanism a lie on the one boot you most
       care about.
  🚨 THE LEDGER IS ITSELF A BOOT-PATH RISK, and is written accordingly.
     It reports other failures, so if it throws it takes the config down
     AND removes the explanation. Every macOS call is pcall'd, both
     queues are bounded, every entry point tolerates nil — and if
     core/notices.lua fails to load, THAT is announced on screen rather
     than leaving reporting quietly off.
  🩹 AND THE SUITE CAUGHT THE HALF-UPDATED INSTALL. Adding a fifth core/
     file failed four checks immediately: hs-install.sh would not have
     COPIED it (both loops name the files explicitly), and its count and
     INSTALL.md's still said four. That is the exact failure hs-doctor
     exists to catch, caught before shipping instead.
  🧪 1,603 checks across fourteen Lua suites. test_notices asserts a
     notice is never lost, never floods, that unknown Focus state means
     SHOW rather than hide, and that a clean boot stays quiet — each
     mutation-checked.

NEW IN 6.53.0 — THE CRITICAL-STOP PASS: TWO WAYS THE WHOLE CONFIG DIED:
  🚨 A BAD KEY NAME TOOK EVERYTHING DOWN. hs.hotkey.bind THROWS on a key
     macOS has no code for — a typo in an ✏️ EDIT HERE block, "esc " with
     a trailing space. A MODULE's bad key was always survivable, because
     §1.12 runs every setup() inside its own pcall. init.lua's OWN binds
     are not so lucky: they sit at top level in the 3,077 lines that run
     BEFORE the loader, so one typo meant no hotkeys, no modules, no
     cheat sheet, and the reason visible only in a Console you were not
     looking at. The sentry now catches the throw, NAMES the key, counts
     it, and hands back the same inert stub the migration path already
     returns — so that one shortcut is off and everything else boots.
     Returning nil was not an option: it only moves the crash to the
     caller's :enable() one line later.
  🚨 ERROR REPORTING DEPENDED ON A FILE THAT CAN FAIL. A Lua error inside
     a timer, an HTTP reply or a watcher CANNOT be caught by a pcall in
     whatever scheduled it — hs.uncaughtErrorHandler is the only place it
     can be seen at all. It was installed ONLY by core/diagnostics.lua,
     which loads a thousand lines into boot and is correctly pcall'd so a
     broken copy cannot stop the config. Two silent windows followed:
     every line before that file loads, and THE ENTIRE SESSION if it
     failed to load — which is precisely when you most need reporting,
     and nothing announced the loss. The earliest possible handler is now
     installed in init.lua itself, and the stand-in diag's err() RECORDS
     instead of being the no-op it was. core/diagnostics.lua still
     upgrades both, and preserves the error list, so anything caught
     during early boot still reaches ⇪⇧D.
  ✅ WHAT THE PASS CLEARED. All four core/ files load inside pcall. warm()
     is pcall'd, so a slow module cannot strand boot. 111 of 200 local
     slots free, so init.lua is not near the compile limit that would
     kill it outright. The only hs.execute calls — a LOGIN shell, which
     blocks — are in update_tracker's warm() and never on the boot path;
     setup() uses cheap io.open probes.
  🧪 TWO ROUNDS OF MY OWN TEST BUGS, both the same shape as the code bug.
     The first audit searched init.lua raw and failed on its own
     documentation: the comment explaining the fix names both
     "core/diagnostics.lua" and the old `err = function() end`, so the
     PROSE was mistaken for the code — the exact trap this suite warns
     about at the top. And the sentry audit's first draft passed with the
     guard removed, because "does pcall appear" and "does the stub
     appear" were both already true of the migration branch beside it;
     what actually distinguishes the fixed file is the ABSENCE of a bare
     `return hsHotkeyBindOriginal(...)`. Restoring the bug now fails four
     assertions instead of one.
  🧪 1,566 checks across thirteen Lua suites.

NEW IN 6.52.0 — TWO FIXES FOUND BY AUDITING init.lua:
  📋 AN EDITED CLIPBOARD ENTRY IS NOW COPIED. You edit an entry because
     you want to paste it, and the edit updated the stored history
     without touching the pasteboard — so you had to go and copy it
     again. Deleting still copies nothing, which is the asked-for split.
     · NO DUPLICATE APPEARS, and the reason is worth recording. Setting
       the pasteboard wakes the clipboard watcher, which would normally
       file a brand new entry and leave the same text twice — once
       edited in place, once fresh at the top. It does not, because the
       watcher's dedupe pass first REMOVES every entry matching the text
       that just arrived, and this entry now carries exactly that text,
       so it is LIFTED to the front instead of copied. That makes the
       ORDER load-bearing: the cache must hold the new text before the
       pasteboard does, and a test asserts that ordering specifically.
  🖥 THE CAPTURE PAD NOW OPENS OVER FULL-SCREEN APPS. It worked
     "sometimes", and the sometimes was: which Hammerspoon window you
     happened to open. LEVEL AND COLLECTION BEHAVIOUR ARE DIFFERENT
     THINGS. Level decides z-order WITHIN a Space, and bringToFront(true)
     already handled that — but a full-screen app is its OWN Space, and
     whether a window may appear over one is governed entirely by
     fullScreenAuxiliary. Every canvas popup here has set that since
     6.20. The webview never did, so it was left behind on the desktop
     Space, which looks exactly like "it opened but nothing appeared".
  🧪 THE TEST STUB WAS PART OF THE BUG CLASS. capture_pad's call is
     pcall'd, so when the webview stub lacked behaviorAsLabels the call
     failed silently and any assertion would have passed while the real
     module did nothing. The stub gained the method and a comment saying
     why it is load-bearing. Both fixes were mutation-checked by removing
     them and watching the tests fail.
  🔍 AND THE AUDIT ITSELF, which prompted both: 3,077 of init.lua's
     3,553 lines run BEFORE the module loader. Anything that throws in
     that stretch takes the WHOLE config down rather than one feature —
     so that is where fragility actually lives, and roughly 1,830 of
     those lines (§3.12 hyper key 838, §6 Asana 387, §2 OCR/clipboard
     341, §5 hotkey glue 263) are movable. Recorded here as the map for
     the next release rather than done in a hurry alongside two fixes.

NEW IN 6.51.0 — WORKSPACES (⇪W): NAME A SET OF APPS, BIND IT TO A SPACE:
  🗂 ⇪W asks which workspace this Space should be, remembers the answer,
     and sets it up: run onStart, open the apps, WAIT FOR THEM TO ACTUALLY
     APPEAR, then run onComplete. Press ⇪W on that Space again and the
     first row offers to re-apply what is already assigned.
     The format is the one that was asked for, unchanged:
        ws.workspaces = {
            DevWork = {
                onStart      = "~/.something/command.sh",
                Applications = { ["Google Chrome"] = {} },
                onComplete   = "~/.something/command.sh",
            },
        }
     ⚠️ THOSE COMMAS ARE NOT OPTIONAL. Lua separates table fields with
     `,` or `;`, so the version without them is a SYNTAX ERROR and the
     module will not load at all. Worth saying because the layout reads
     perfectly well without them. The `{}` after each app is where
     per-app options go; `{ zone = "leftHalf" }` places its window using
     the same zone names the numpad layer uses.
  ⏱ onComplete MEANS "THE APPS ARE UP", so it waits for them rather than
     firing straight after launchOrFocus, which would be a lie. It polls
     until every app answers or the budget runs out, then runs anyway —
     an app that never starts must not strand the workspace.
  🚨 THE FLAG THAT MUST NEVER STICK. ws.busy is the one-apply-at-a-time
     guard, so a failing step that leaves it set kills the feature until
     a reload with nothing saying why — the same failure shape as Focus
     Mode leaving the mic muted. Every exit goes through one finish()
     that clears it, a hook that never exits is TERMINATED after
     ws.hookTimeout, and 300 generated workspaces mixing failing
     launches, failing hooks and hooks that hang assert it always clears.
  🗺 SPACE IDs ARE NOT STABLE ACROSS LOGOUTS, which leaks straight into
     this feature: yesterday's saved binding can point at a Space that is
     now somebody else entirely. So the store is PRUNED against the
     Spaces that actually exist every time it is read, and a dead ID is
     dropped rather than guessed at — applying the wrong workspace to the
     wrong desktop is worse than forgetting. But an EMPTY answer from the
     API does not wipe the store: "told us nothing" is not "all gone".
     With no hs.spaces at all it degrades to one workspace for the Mac
     and says so once.
  🅿️ ⇪⇧W WAS ALREADY TAKEN by the Document Watcher, and quietly stealing
     a working shortcut is not a trade worth making silently. So reset
     lives on the FIRST ROW of the ⇪W picker whenever the Space already
     has a workspace, and is published as workspace.reset for one of the
     free number-pad keys:  numpad.actions["pad+"] = "workspace.reset"
  🐛 THE SUITE FOUND A REAL BUG ON ITS FIRST RUN: validate() recorded
     "Applications must be a table" and then iterated it anyway, so the
     validator CRASHED on exactly the input it had just caught — the one
     thing a validator must not do. Guarded and tested.
  🧪 1,545 checks across thirteen Lua suites. The explorer also caught a
     fault in its own clock budget: when BOTH hooks hang the chain needs
     two full timeouts to unwind, and advancing only one stopped the
     clock mid-chain and reported a working module as stuck.

NEW IN 6.50.0 — THE PAD SWAPS LAYERS, AND A POINTER RING:
  🔀 TOOLS MOVED TO THE PRIMARY HYPER KEY. 6.49.0 put windows on ⇪ + pad
     and tools on ⇪⇧ + pad. That was the wrong trade and it is now the
     other way round:
        ⇪  + pad  →  TOOLS    focus, rename, grid, menu bar, links
        ⇪⇧ + pad  →  WINDOWS  the 3×3 position map
     The argument for the old order was that the window map deserved the
     easier layer because it needs no memory. But the layer you press
     twenty times a day should be the one without the extra modifier, and
     that is the tools. The window map loses nothing by moving up one
     modifier: its mnemonic is spatial — the key's position is the
     window's position — not a fact about which modifiers are held.
  🆓 SIX KEYS LEFT DELIBERATELY FREE on the tool layer — pad+ pad- pad*
     pad/ padenter padclear — as the room for whatever comes next, with
     a test asserting they stay unclaimed so the reserve does not quietly
     get eaten.
  🖱 THE MouseCircle SPOON, DONE NATIVELY. A ring flashes at the pointer
     so you can find it on a wide desktop. Implemented as ~20 lines in
     mouse_grid.lua rather than by adding SpoonInstall, which would mean
     a second loading system running alongside the module loader, and a
     network fetch on the boot path, for one circle. Same result, in
     rebeccapurple as asked.
     · 🅿️ BOUND TO NO KEY ON PURPOSE. macOS shake-to-grow already does
       this, which is exactly why you had the Spoon disabled. It is
       published as mouseGrid.locate, so it goes on a free pad key the
       day you want it: numpad.actions["pad+"] = "mouseGrid.locate".
     · Note the Spoon bound it to hyper+M, which in this config is
       already Menu Bar Items — one more reason it did not simply drop in.
     · The ring is CLICK-THROUGH. Without that it is a disc of glass over
       whatever you were reaching for, for half a second. And a second
       press REPLACES the first ring rather than stacking canvases that
       each delete on their own schedule, which is how this leaks. Both
       are tested, and the leak guard was mutation-checked by removing it
       and watching the test fail.
  🧪 1,496 checks. The swap broke six existing assertions, which is what
     they were for — they encoded which layer was which. They now encode
     the new arrangement, including that the arithmetic keys moved to the
     window layer and that the tool layer's six free slots stay free.

NEW IN 6.49.0 — THE NUMBER PAD, SWITCHED ON, WITH TWO LAYERS:
  🔢 THE PAD IS LIVE. It shipped PARKED in 6.44.0 — a worked-out layout
     bound to nothing — and it is now on, with a second layer added:
        ⇪  + pad  →  WINDOWS   (the key's position IS the window's)
        ⇪⇧ + pad  →  TOOLS     (focus, rename, grid, menu bar, links)
     That is ~28 live shortcuts that cost ZERO letters on the main
     keyboard, because the pad sends its own key codes: pad7 is not 7,
     and ⇪pad7 is not ⇪⇧pad7.
  🪟 WINDOWS STAYED ON THE UNSHIFTED LAYER, deliberately. Its mnemonic is
     the best thing in that module — pad7 is the top-left quarter because
     7 IS the top-left key — and there is nothing to memorise. Burying it
     under a modifier to make room for tools would have traded the one
     layout that needs no memory for one that does. Tools took the
     shifted layer instead.
  🔌 THE TOOL LAYER BINDS BY SERVICE NAME, NOT BY FUNCTION. numpad_layer
     knows nothing about focus mode or renaming; it calls "focus.toggle"
     and the dispatcher resolves it. A pad key whose module is switched
     off on this Mac prints "no provider" instead of erroring. Four
     modules gained the entry-point service they had been missing —
     focus.toggle, rename.show, rename.undo, menuBar.show,
     url.cleanClipboard — because they had published only QUERIES
     (report, list, plan) and nothing a key could actually press.
  🚨 WHICH CREATED A NEW FAILURE MODE, SO IT GOT A NEW TEST. A typo in a
     service name — "focus.tggle" — binds perfectly, does nothing when
     pressed, and prints to a Console nobody is reading. The check that
     every shifted binding resolves to a real provider had to go in
     test_integration.lua and NOWHERE ELSE: every other suite loads one
     module at a time against stubs, so the registry is empty there and
     the same check would have passed vacuously while proving nothing.
     Verified by planting the typo and watching it fail.
  ✏️ ONE ECHO ACROSS THE LAYERS, on purpose: pad. undoes on both. ⇪pad.
     puts a window back where it was, ⇪⇧pad. undoes the last rename.
     The tool rows are grouped by row (meetings · pickers · clipboard)
     rather than pretending to a spatial logic they do not have.
  🧪 1,483 checks. Turning the layer on broke nine existing tests, which
     is exactly what they were for — they asserted it ships parked. They
     now assert the live two-layer contract, that parking is still
     reachable, and that the nil-key guard covers the shifted layer too.

NEW IN 6.48.0 — FOCUS MODE (⇪F) AND BULK RENAME (⇪R):
  🎯 FOCUS MODE. A Zoom or Teams MEETING WINDOW — not merely the app
     being open — mutes the mic, turns the camera off if it is provably
     on, runs your Do Not Disturb Shortcut, and dims every app that is
     not the meeting. Leaving puts back exactly what it changed.
     · IT CANNOT REVOKE CAMERA ACCESS. No macOS API exists. What it does
       instead is READ the meeting app's own menu: "Stop Video" present
       means the camera is on, so clicking it is deterministic. If only
       "Start Video" is there the camera is already off and it does
       NOTHING. Firing ⌘⇧V blindly is a coin flip that switches the
       camera ON half the time, which is worse than doing nothing.
       Teams exposes no readable camera menu, so Teams gets a muted mic
       and its camera left alone — stated rather than faked.
     · OUTLOOK'S CALENDAR IS NOT READ, deliberately. Classic Outlook had
       AppleScript; the rewritten one largely dropped it, and a detector
       that works on one build and silently fails on the next is worse
       than none. It watches the REMINDER WINDOW for a join link, which
       works on both builds and fires exactly when you care.
     · THE FAILURE THAT MATTERS IS A MIC LEFT MUTED, so the design is
       built around restoring rather than detecting: prior state is
       recorded BEFORE any change and a mic you muted yourself is never
       unmuted; every restore step is independently pcall'd and the mic
       goes first; a watchdog disengages on its own if detection dies.
  ✏️ BULK RENAME. Select files in Finder, ⇪R, pick a rule, check the
     preview, ⏎. ⇪⇧R undoes the batch and survives a restart.
     · SUBTITLES MOVE WITH THEIR VIDEO, BY CONSTRUCTION. A player finds
       captions by filename, so renaming a .mp4 and not its .srt does
       not leave a stray file — it silently kills subtitles. Rules
       rewrite the GROUP stem and extensions are reattached, so there is
       no code path that can separate them. It knows the tails that
       break naive matching too: film.en.srt, film.forced.srt.
     · IT REFUSES RATHER THAN OVERWRITES. os.rename destroys the target
       with no warning and no undo, and a bulk rename is exactly where
       two names collapse into one. Any collision aborts the WHOLE
       batch — a half-renamed folder is worse than an unrenamed one —
       and renames run in two phases through temporaries so a swap or a
       rotation works instead of eating a file.
     · The `tv` rule fixes the season that prompted this: eight episodes
       named .1080p.ATVP-[y2flix.cc] and one named .108 all become
       Dark.Matter.2024.S01E01 and siblings, subtitles included.
  🚨 THE SUITE CAUGHT TWO REAL BUGS IN THIS RELEASE BEFORE IT SHIPPED:
     · order = 13.10 IS order = 13.1 IN LUA. Trailing zeros do not
       survive, and 13.1 is the Capture Pad — so the obvious "next
       number after 13.9" was a silent cheat-sheet tie whose running
       order then depended on table iteration. Both new modules moved to
       14.x. This is why the integration suite loads all 24 modules
       together instead of testing each alone.
     · INSTALL.md's module count is asserted against disk, so 22-vs-24
       failed two suites rather than shipping a doc that lies.
  🧪 1,479 checks across twelve Lua suites. The two new ones are
     property-based: 400 random messy folders assert that no file is
     lost, no clean plan collides, every subtitle stays with its video
     and every batch undoes exactly; 500 random meeting days assert the
     mic is never stranded and never unmuted against the user's wishes.
     Three mutations were too weak to fire and had to be rewritten —
     one grouped by a rule that changed nothing, one probed a teardown
     that already guarded itself and was aimed at a step that runs
     first anyway.

NEW IN 6.47.1 — THE EXPLORER TURNED ON THE THREE NEWEST TOOLS:
  🔎 The random-sequence explorer built for the Mouse Grid now runs
     against the URL Cleaner, the Health Monitor and Menu Bar Items.
     Four findings came back. NONE was a bug in the shipped modules —
     three were faults in my own test instrumentation and one was a
     deliberate design decision the property had stated too broadly.
     That is worth recording rather than quietly fixing, because it is
     what property testing actually feels like: the properties are
     harder to state correctly than the code is to write.
  🔗 URL CLEANER, 8,000 generated URLs. Properties: never throws,
     IDEMPOTENT (cleaning a clean URL is a no-op), still a URL,
     wrapping cannot change the answer, every non-tracker survives,
     every tracker goes, the fragment is untouched.
     → Finding: it refused to unwrap a generic ?url= pointing at its
       OWN host. That is correct and now has its own test:
       example.com/login?url=example.com/dashboard is a login return
       path, not a redirect, and rewriting it sends you somewhere you
       did not ask to go. The fuzzer had generated an unrealistic
       input and asserted a naive substring match.
  🩺 HEALTH MONITOR, 600 random timelines / 36,000 events — files
     going quiet and coming back, midnight mid-outage, the lid shutting
     during a fault, modules failing and recovering, interleaved.
     → Finding: a module that FAILED TO LOAD is announced during the
       boot grace period. Deliberate: the grace period exists because
       module files do not exist yet, which says nothing about load
       status, and a certain fault should not wait twenty minutes.
     → Two of mine: the property read the clock BEFORE the action that
       changed it, and the harness let the simulated date run backward
       between timelines, visiting one calendar day twice.
     → And it added a rule nothing had checked: load failures obey the
       once-per-day limit too.
  📊 MENU BAR ITEMS, 500 random Mac populations — up to 30 apps mixing
     healthy, silent, wedged and action-refusing. The property that
     matters is that the scan returns inside its budget however bad the
     population, because that budget is your keyboard.
  🧬 EVERY PROPERTY WAS THEN MUTATION-TESTED, because a property that
     cannot fail is decoration. Breaking idempotence, the parameter
     blocklist, the once-per-day guard, the active-hours guard and the
     scan budget each fails the suite by name. Two of my first attempts
     at those mutations were too narrow to fire and had to be rewritten.
  🧪 1,410 checks across eleven suites.
  🩹 THE SHIP CHECK THEN FOUND TWO THINGS THE SUITES CANNOT SEE, both
     in what travels ALONGSIDE the code rather than in the code:
     · hs-doctor.sh's "is each module current?" markers stopped at
       6.44.4, so the four newest tools had no staleness check at all.
       Added, and menubar_items is checked for mb.axTimeout specifically
       — a copy without it is not merely old, it is the version that can
       hold the keyboard while a wedged app fails to answer.
     · GUIDE.md still said 6.44.0, "18 modules", and "five suites, 593
       checks". It now says 22, eleven and 1,410, documents core/ and
       tools/, explains why loader_test.lua is not a suite and errors if
       you run it, and stops listing §1.6 and §1.11 as work to do — they
       moved to core/ in 6.46.1. Headroom re-measured: 111 free locals,
       not 116.
     · hs-install.sh shipped WITHOUT its executable bit while the other
       two tools had theirs. Not broken — INSTALL.md invokes it as
       `sh …/hs-install.sh` throughout — but `./tools/hs-install.sh` is
       the obvious thing to type after `./tools/run-tests.sh`, and it
       answered "Permission denied". All three are 755 now.
     None is a runtime change, so the version stays 6.47.1. A manual
     three versions out of date is still a defect you ship.
  📦 THE ZIP IS VERIFIED BY EXTRACTING IT, not by trusting the file
     list: unpacked to an empty directory, its own tools/run-tests.sh
     runs all 1,410 checks green with nothing else present. That is what
     proves the archive is complete rather than merely large.

NEW IN 6.47.0 — MENU BAR ITEMS (⇪M), AND WHY IT IS NOT BARTENDER:
  🚫 THE HONEST PART FIRST. Bartender's central trick — HIDING other
     apps' menu bar icons — CANNOT be done in Hammerspoon, and the
     reason is not a gap in Hammerspoon. A menu bar icon is an
     NSStatusItem owned by the app that made it; macOS exposes no
     public API for one process to hide, move or reorder another
     process's status item. There is nothing to call. Bartender works
     around it by covering the real bar and drawing its own copies of
     the icons, which is why it needs SCREEN RECORDING — it has to
     photograph the menu bar, because it cannot ask for the images
     either. Hammerspoon could draw a black strip and nothing more.
  ✅ FOR REAL HIDING, USE ICE — free, open source, actively maintained:
     https://github.com/jordanbaird/Ice. It coexists fine with this.
  ⌨️ WHAT IS REACHABLE is the half that suits a keyboard-driven setup
     better anyway. ⇪M lists every status icon by owning app; type a
     few letters and press ⏎ to open it. No aiming at a 22-pixel glyph
     you cannot identify. ⇪⇧M prints an inventory. Accessibility only —
     no Screen Recording, nothing covered, nothing moved.
  🚨 ITS WORST FAILURE WOULD BE A FREEZE, NOT A CRASH. Reading another
     app's Accessibility tree is a SYNCHRONOUS call into that app, and
     Hammerspoon's main thread is your keyboard. Fifty apps with no
     timeout is a plausible way to lose the Mac for a minute — 6.33.0's
     ⌥Tab froze for exactly this reason. So every app element gets an
     explicit 0.1s timeout BEFORE it is asked anything, the whole scan
     is time-boxed at 2s and checked every iteration, and results are
     cached. The suite drives forty deliberately wedged apps and fails
     if the scan does not give up.
  🐛 One of mine, caught by the tests: pcall(function() el:performAction
     (a) end) DISCARDS the return value, so the success check never saw
     it and AXShowMenu fired straight after a perfectly good AXPress —
     activating every item twice. The `return` inside the wrapper is
     load-bearing.
  🧪 1,405 checks across eleven suites.

NEW IN 6.46.1 — init.lua GOES BACK TO BEING AN ORCHESTRATOR:
  📉 3,735 LINES → 3,511, AND NOT ONE LINE OF CODE WAS TOUCHED. 6.44.11
     cut this file from 6,012 to 3,376 by moving history out; within a
     few releases it was back to TWELVE inline changelog entries against
     a stated rule of five. Bloat creeps back about fifty lines a
     release and nobody notices, because each release only adds a little.
  🚨 AND IT NEARLY COST THREE VERSIONS OF HISTORY. 6.44.11, 6.44.12 and
     6.44.13 existed ONLY in this header — they were never backfilled
     into CHANGELOG.md. Trimming on the assumption that CHANGELOG.md was
     complete would have deleted them silently. They were moved across
     FIRST; CHANGELOG.md now holds all 114 versions.
  🧬 A TEST NOW ENFORCES BOTH HALVES, because a convention nothing checks
     is a convention that decays: at most five entries inline, and
     nothing inline that CHANGELOG.md is missing. The second is the one
     that matters — it makes losing history by trimming impossible.
  📐 AND THE ARCHITECTURAL CLAIM IS NOW TESTED RATHER THAN ASSERTED. A
     new tool costs init.lua its NAME in three profiles and nothing
     else. Across the whole of 6.45.0 → 6.46.0, three new tools added
     1,867 lines of module code and exactly NINE lines to init.lua.
     The suite fails if a module name ever appears here as code.
  🧪 1,358 checks across ten suites.

NEW IN 6.46.0 — A LINK CLEANER, A TOOL-HEALTH WATCHDOG, AND ⇪M → ⇪X:
  🎯 THE MOUSE GRID MOVED TO ⇪X. ⇪X opens it, ⇪⇧X clicks on arrival,
     ⌃⌥⌘⇧X is the panic key. Nothing else about it changed.
  🔗 NEW: modules/url_cleaner.lua. ⇪K rewrites the link on your
     clipboard into the one the sender actually meant — tracking
     parameters stripped, redirect wrappers unwrapped. ⇪⇧K undoes it.
     Works on a whole paragraph, cleaning every link in it.
  📧 THE WORK-INBOX CASES ARE THE POINT. Outlook Safe Links wraps
     almost every link in almost every corporate email; Proofpoint
     wraps the rest, and uses its OWN encoding where "-" means "%" and
     "_" means "/" — decode that as ordinary percent-encoding and you
     get a dead link. Both are handled, including one wrapper nested
     inside another, with a BOUNDED unwrap loop.
  🚫 IT WILL NOT EXPAND bit.ly & co, AND THAT IS THE DESIGN. A
     shortener does not contain its destination; the only way to learn
     it is to ask their server, which REGISTERS THE CLICK you were
     trying to avoid and sends a work link to a third-party host. The
     module makes NO network calls at all — a test fails the build if
     one ever appears — and says plainly why it stopped.
  🛟 BLOCKLIST, NEVER ALLOWLIST. Only known trackers are removed;
     anything unrecognised is kept. ?v= on YouTube, ?q= on a search,
     ?ref= on GitHub and ?page= everywhere are load-bearing. A cleaner
     that leaves a stray parameter is a nuisance; one that breaks the
     link is worse than not having it.
  🩺 NEW: modules/health_monitor.lua. The boot report says what LOADED.
     The capability report says what this Mac CAN do. Neither notices a
     module that loaded fine, reports no error, and stopped writing to
     its file three days ago — which you only find out by opening the
     Console you do not have open. This watches the OUTPUT of every
     tool that produces some and puts a PERSISTENT notification on
     screen when one goes quiet. ⇪⇧H for the full report.
  🧩 IT WATCHES FILES, SO NOT ONE LINE OF ANY EXISTING MODULE CHANGED.
     Twenty other modules, zero regression risk. It also catches
     HALF-broken — a watcher that silently detached still loads, still
     binds, still reports healthy, and stops writing.
  🚨 THE REAL WORK WAS NOT ALERTING. A monitor that cries wolf gets
     ignored, and an ignored monitor is worse than none: it trains you
     to dismiss the one notice that mattered. Staleness is counted in
     AWAKE TICKS, so shutting the lid for three days costs nothing;
     each check names the hours it is expected to be active; it speaks
     once per tool per day; and a boot grace period stops it judging
     modules that warm on a timer. Most of its test file is about
     staying silent.
  ⏱ hs.notify.show() WOULD HAVE BEEN THE WRONG CALL and looks like the
     right one: its notices inherit withdrawAfter = 5 seconds and
     vanish while you are looking elsewhere — the exact situation this
     module exists for. withdrawAfter = 0 makes them persist. Found by
     reading Hammerspoon's source, not by guessing.
  🔎 NEW IN THE TEST SUITE: AN EXPLORER. It writes its own test cases —
     random sequences of real actions, checking after EVERY step that
     the module is in a state it allows, then SHRINKING any failure by
     deleting steps while it still fails. Planted a broken teardown and
     it found it unaided in a 40-step sequence, then cut it to two:
     "showClick → escape". That reduction is the whole point; a 40-step
     trace is a haystack, a 2-step one is a bug report.
  🧪 1,344 checks across ten suites.

NEW IN 6.45.2 — DOES THE NEW MODULE BREAK THE OLD CONFIG?
  🔗 THE QUESTION NO OTHER SUITE HERE ASKED. Every test file proves one
     module correct IN ISOLATION, against stubs. That says nothing about
     nineteen of them sharing one keyboard, one hotkey table and one
     global namespace. NEW: tests/test_integration.lua.
  ⌨️ THE REAL RISK, AND IT IS SUBTLE. Mouse Grid binds BARE letters
     (a s d f g h j k l) while its overlay is up. The hyper key works by
     doing the same thing, and §3.12 deliberately does NOT exit the
     hyper modal when a shortcut fires — so while the grid is open BOTH
     modals have bare "a" bound. Whether that works is decided inside
     hs.hotkey's shadowing stack, which nothing here modelled.
  ✅ SO THE STACK IS NOW SIMULATED FAITHFULLY — enable()/disable()
     reimplemented from Hammerspoon's own hotkey.lua, same shadowing,
     same un-shadow scan — and the real sequence driven through it:
     ⇪ held → grid opens → grid's letters WIN → release ⇪ mid-grid and
     the grid KEEPS them → close the grid and hyper gets them BACK →
     close everything and the keyboard is clean. Both release orders,
     plus double-enter, double-exit, and the grid with no hyper at all.
  🧬 ALL 19 MODULES LOADED TOGETHER through the real §1.12 loader, then
     audited for the collisions that only appear in company: two modules
     on one ⇪ key, two on one global chord, two publishing one service
     name, two on one cheat-sheet slot, a malformed cheat-sheet row that
     would break EVERY group's rendering rather than just its own.
  🧪 4 mutations prove those checks bite: stealing ⇪N from the Capture
     Pad, Screen Veil's cheat-sheet slot, Screen Veil's panic key, and
     the Capture Pad's flush service are each caught by name.
  📣 ONE THING THIS COSTS YOU, BY DESIGN. §3.12 forwards every UNCLAIMED
     ⇪ key to the frontmost app as ⌘⇧⌃⌥+key. Claiming M means ⌘⇧⌃⌥M and
     ⌘⇧⌃⌥⇧M no longer reach Raycast, Rectangle or a browser extension.
     That is true of adding any ⇪ shortcut; it is worth knowing once.
  🧪 1,227 checks across eight suites.

NEW IN 6.45.1 — THE MOUSE GRID, AUDITED AGAINST HAMMERSPOON'S OWN SOURCE:
  🔬 THE GAP A TEST SUITE CANNOT CLOSE BY ITSELF. Every check in 6.45.0
     validated the module against MY stubs, which encode MY assumptions
     about the hs API. A wrong assumption passes the test and crashes
     the Mac. So Hammerspoon's source was read directly and every call
     this module makes was checked against it.
  ✅ CONFIRMED CORRECT: the canvas element types and every attribute
     used; center/radius on circle; coordinates on segments; frame on
     rectangle and text; roundedRectRadii; textAlignment "center";
     fillColor on closed shapes and strokeColor on primitives;
     windowLevels.screenSaver; every canvas method called; the mouse,
     eventtap and screen-watcher calls; and — the one most worth
     checking — that modal:bind is declared (mods, key, MESSAGE, fn) but
     shifts its arguments when a function arrives in the message slot.
  🐛 A HANG, WHICH IS WORSE THAN A CRASH. A display reporting height 0
     (one disconnecting mid-query, a virtual display, some
     screen-sharing sessions) makes w/h infinite; math.floor(math.huge)
     is math.huge, so the cell loop became `for c = 0, inf` and
     Hammerspoon spun forever with no error and no recovery but a
     force-quit. Frames are now sanity-filtered, and one clamp bounds
     the loop even for a frame that passes the filter and still
     overflows.
  🐛 UNREACHABLE SCREEN. Without cols <= share, an extreme aspect ratio
     on a small share produced more cells than labels; the surplus was a
     region of screen that could never be reached. The fuzzer finds it
     within ~50 layouts once the clamp is removed.
  🐛 A CRASH ON A SCALED DISPLAY. string.format("%d", x) RAISES in Lua
     5.4 for any float without an exact integer representation, and
     screen frames are not something this module controls. No "%d"
     touches a frame now.
  🐛 INVISIBLE KEY CAPTURE. If the landed badge failed to draw, the old
     one had already been destroyed — leaving the keyboard captured with
     nothing on screen saying so, the one thing this design forbids.
     Landed mode is now refused outright rather than entered blind.
  🐛 A KEY YOUR KEYBOARD CANNOT SEND. hs.hotkey RAISES on an unknown key
     name rather than returning nil, so one exotic character in
     grid.alphabet would have taken the module down at setup.
  🗑 AND ONE DELETION. A NaN/infinity guard was written, then removed on
     proof that it was UNREACHABLE — the clamp beside it already handled
     both. Untested code that looks like a safety net is worse than no
     code, because the next reader trusts it.
  🧪 4 mutations run against the NEW tests themselves; two were
     toothless and were rewritten until reverting each fix fails the
     suite. 1,500-layout geometry fuzzer. 244 checks on this module.

NEW IN 6.45.0 — MOUSE GRID (⇪M): TYPE THREE LETTERS, THE POINTER GOES THERE:
  🎯 ⇪M lays a labelled grid over EVERY display. Each cell carries three
     home-row letters; type them and the pointer jumps to that cell. ⇪⇧M
     clicks on arrival. After it lands you can stay on the keyboard —
     SPACE clicks, ⇧SPACE right-clicks, 2 double-clicks, arrows nudge 8pt
     (1pt with ⇧), ⎋ backs out — or just use the trackpad.
  📐 A COORDINATE TOOL, DELIBERATELY NOT AN ELEMENT TOOL. It knows nothing
     about what is underneath, which is exactly why it never fails: video,
     PDFs, a Photoshop canvas, a remote desktop, any pixel is reachable.
     Walking the Accessibility tree for real buttons (Vimac/Homerow style)
     is more precise where it works and returns NOTHING in Electron and
     Java apps, costs 100–500ms per invocation, and needs a permission the
     work Mac may withhold. That can be layered on later as a second stage
     sharing these keys; it must not be merged in, because the two have
     opposite failure modes.
  🚨 THE MOST DANGEROUS MODULE IN THIS CONFIG, AND BUILT LIKE IT. A
     full-screen overlay that captures keystrokes can lock you out of your
     own Mac. Four independent defences: ONE invariant (state ⟺ modal ⟺
     canvas) behind a single idempotent teardown that pcalls each step
     separately; a WATCHDOG so nothing outlives its keypress; a PANIC key
     on a plain chord (⌃⌥⌘⇧M) rather than ⇪, because if ⇪ is what broke
     then a ⇪ panic key is no panic key; and unbound keys PASS THROUGH, so
     ⌘Q and ⌘Tab keep working while the grid is up. Landed mode is never
     invisible — whenever keys are captured, a badge says so.
  🐛 THE SUITE CAUGHT THE EXACT FAILURE THAT MATTERS. hide() first walked
     `grid.cache.screens or {}` to put the overlay away. When the thing
     that broke IS the cache, `or {}` makes the teardown a no-op: the
     modal exited, the state cleared, and the sheet stayed on screen over
     everything. Teardown must never depend on the structure that just
     failed, so a flat list of what is actually on screen is now kept
     separately, and a mutation pins the regression.
  🐛 Also mine: `#chars ^ n` parses as `#(chars ^ n)` because Lua binds ^
     tighter than unary # — the same precedence family that crashed
     6.44.13's word-wrap.
  ⚡️ FAST BY ARCHITECTURE, NOT BY LUCK. 729 cells is ~1,500 canvas
     elements. Scrim and lines are one cached canvas per screen, built
     once per display layout; labels are a second canvas and the only
     thing redrawn; each keystroke shrinks 729 → 81 → 9, so every redraw
     is cheaper than the last. A screen watcher drops the cache when
     displays change, rather than drawing yesterday's grid over today's
     screens.
  🔢 CAPACITY IS ARITHMETIC, AND IT IS PUBLISHED. alphabet^length = 9³ =
     729 cells, ~45pt on one display, near Apple's own 44pt minimum
     control size. TWO DISPLAYS SPLIT THAT into ~85pt cells, coarser than
     many buttons — which is what the arrow-nudge is for, and widening
     grid.alphabet buys the fine grid back. _G.mouseGridReport() prints
     the real cell size on THIS Mac and warns when it is too coarse.
  ♿️ MOVING AND CLICKING ARE NOT THE SAME PERMISSION. Warping the pointer
     needs nothing, so the JUMP works on any Mac. Synthesising a click
     goes through hs.eventtap, which macOS gates behind Accessibility — so
     without it the grid still jumps and SPACE says why it could not
     click, instead of looking broken.
  🧪 207 new checks, 10 mutations, 1,123 across seven suites.

NEW IN 6.44.13 — "DOES IT WORK ON THIS MAC?", ANSWERED IN ONE CALL:
  🖥 ONE init.lua, TWO VERY DIFFERENT MACS. About a dozen things
     legitimately differ between the personal Air and the managed work
     MacBook. Every one was already handled, and every one printed its
     own line somewhere at boot — which is the problem. Twelve scattered
     lines is not an answer to "what works here", it is twelve things to
     go and find.
  ✅ NEW: core/capabilities.lua. _G.capabilityReport() reports OneDrive,
     backup, Asana, Accessibility, the hyper key, OCR, Homebrew and the
     module load — each with its STATE, the real REASON, and, when it is
     off, WHAT THAT COSTS YOU. "OFF" only means something if you know
     what it takes with it. Included in ⇪⇧D.
  ❔ UNKNOWN IS A REAL ANSWER. The hidutil remap and the OCR probe are
     decided asynchronously, well after boot. "Has not reported yet" and
     "this Mac cannot" need different reactions, so they are never
     folded together. A broken secret.lua is likewise distinguished from
     a missing one — broken is a typo you can fix in thirty seconds.
  🎹 The hyper remap's result is now RECORDED (_G.hyperRemapOK), not just
     printed once and lost. It is the single biggest difference between
     the two Macs, and asking you to scroll back for a line was a poor
     way to find it out.
  📄 NEW: INSTALL.md — rebuilding this config from nothing, step by step.
     Hammerspoon, Accessibility, the files, secret.lua, the machine
     profile, the OCR shortcut, no-admin Homebrew, verification, and
     what to do when a step fails. Every optional step is marked, with
     what you lose by skipping it.
  🧬 A TEST NOW KEEPS THE DOCS HONEST. Adding capabilities.lua left
     INSTALL.md saying "3 files", hs-doctor.sh checking three names and
     hs-install.sh requiring three — three places silently out of step
     with one new file, and the installer is what stands between a
     half-copied config and the primary Mac. The file list is read from
     DISK now and anything hard-coding it must agree. 7 mutations catch
     that drift, including one that only removed a name from the
     installer's PRE-CHECK loop and left the verify loop intact.
  🐛 Two of my own, both caught by running the code rather than reading
     it: a one-line conditional in the report's word-wrap relied on Lua
     binding `and` tighter than `or`, evaluated to a boolean and crashed
     on concat; and the capability load was first placed above
     `local hyperEnabled`, where a Lua local is invisible, so it
     captured nil and reported the hyper key disabled on BOTH Macs.
  🧪 940 checks across six suites.

NEW IN 6.44.12 — PROVING THIS IS SAFE ON A MANAGED WORK MAC:
  🔒 THE WORK MACBOOK IS THE PRIMARY MACHINE AND HAS NO ADMIN RIGHTS.
     That is now a tested guarantee rather than a claim. The suite fails
     if any future change adds sudo, an AppleScript admin prompt, chown,
     launchctl, a keychain write, csrutil or spctl.
  📋 EVERY EXTERNAL PROGRAM IS ON A REVIEWED LIST, and an unlisted one
     fails the build. The list: curl, shortcuts, hidutil, open, defaults,
     zsh, rsync. ALL SEVEN SHIP WITH macOS. This config installs nothing.
  🍺 HOMEBREW IS OPTIONAL AND ISOLATED. It is reached from exactly one
     module (update_tracker) and powers exactly one feature (⌃⌥⇧U). No
     brew = that feature is off and says so; nothing else notices. The
     no-admin prefixes under $HOME are searched BEFORE the admin ones,
     and a test enforces that order.
  🏠 NOTHING IS WRITTEN OUTSIDE $HOME. Every write target is built from
     logsDir or configDir; a hard-coded absolute write path fails the
     suite. /Applications and /usr/bin are READ only.
  🌐 THE ONLY HOST THIS CONFIG CONTACTS IS app.asana.com, and only with
     secret.lua present. My first version of that check failed on
     shottr.cc and was WRONG to: that is a vendor page handed to your
     browser because you selected the row and pressed Enter. A link you
     click is not network activity this config initiates. The test now
     keeps those two apart and asserts vendor URLs are never fetched.
  🧬 6 more mutations caught, including "a sudo appears in the backup
     command", "the remap becomes a launch daemon" and "a vendor page
     starts being FETCHED instead of opened".
  🛟 NEW: tools/hs-install.sh — INSTALL, VERIFIED AND REVERSIBLE. The
     risk on the work Mac was never the Lua, it was the COPY: since
     6.44.11 a bare `cp init.lua` produces a config that starts, looks
     fine, and has quietly lost ⇪/ and ⇪⇧D. This checks the download is
     complete BEFORE touching anything, backs up the current config,
     installs, verifies, and ROLLS ITSELF BACK if the verify fails. It
     refuses to run as root. --dry-run shows what it would do; --rollback
     undoes the last install. secret.lua and logs/ are never touched.
  🐛 Its own first verify checked only that each core file EXISTED — and
     a zero-byte one passed, which is the exact half-installed state the
     script exists to prevent. It checks size and content now. Found by
     testing the installer's failure paths rather than its happy path.
  🩺 hs-doctor.sh answers the question ON the work Mac: every external
     command, whether it is present there, and every path written to.
  🧪 875 checks across six suites.

NEW IN 6.44.11 — init.lua IS 44% SMALLER, AND THE CONSOLE IS TWO LINES:
  📉 6,012 LINES → 3,376. Nothing was deleted. 1,827 lines of changelog
     moved to CHANGELOG.md beside this file (all 107 versions, intact),
     and three big blocks moved into core/.
  📂 core/ IS NOT modules/. A module is loaded by the §1.12 loader,
     isolated, and configurable per machine. These three are dofile'd by
     init.lua at exactly the point they used to sit, because the loader
     runs LAST and depends on them: it logs through _G.diag, and every
     module registers a cheat sheet group as it loads. Boot order is
     unchanged. Each load is pcall'd, so a missing core file costs you
     that one feature and prints why — it does not stop the Mac.
       core/diagnostics.lua   §1.11, 287 lines   ⇪⇧D
       core/cheatsheet.lua    §1.6,  721 lines   ⇪/
       core/boot_report.lua   the Console's first impression
  🔇 A CLEAN BOOT IS NOW TWO LINES, not fourteen. Fourteen lines you have
     read a hundred times is not information; it is what you scroll past
     to reach the line you reloaded to see. The rule now: SUMMARISE WHAT
     IS RIGHT, ALWAYS PRINT WHAT IS WRONG. A failed module, a hotkey
     conflict, missing Accessibility, a broken secret.lua — each still
     prints its own full line, every time. Nothing was lost:
     _G.bootReport() prints everything on demand, and _G.bootVerbose(true)
     restores the full report at every boot. That preference is stored in
     hs.settings, so it survives the reload you set it before.
  🧪 THE TESTS STOPPED LYING. test_cheatsheet and test_diagnostics ran
     against tests/block_test.lua and tests/diag_test.lua — hand-extracted
     slices that had DRIFTED so far they were no longer even substrings of
     init.lua. Both suites now load the shipped core/ file. The drift was
     real and it was hiding things: running the real cheat sheet reached
     four hs.hotkey.bind calls and two hs.chooser pickers that the slice
     did not contain, none of which had ever been executed by a test. The
     two dead slices are deleted.
  🐛 AND THAT CAUGHT A BUG I HAD JUST WRITTEN. Lifting the boot report out
     carried its `local axOK = false; pcall(...)` along with it, where it
     shadowed the value being passed in. Effect: a Mac WITHOUT
     Accessibility would still boot to "All green" — the single most
     important thing that report has to warn about, silently dropped. The
     whole-file text audit could not see it. The test that RUNS the file
     caught it on its first execution.
  🧬 20 mutations caught. Three of them were MISSED first: the audit read
     init.lua concatenated with core/, so "init.lua loads the boot report"
     stayed green when init.lua stopped loading it — the core file names
     itself in its own header, and a comment satisfied the search. Fixed
     by auditing init.lua alone, ignoring comment lines, and matching the
     real loader expression instead of the bare filename.
  🩺 tools/run-tests.sh compiles core/ too; tools/hs-doctor.sh reports it
     and says plainly what is off if the folder never got copied across.
  🧪 855 checks across six suites.

NEW IN 6.44.10 — THE DUPLICATE "PARKED" ROW, AND A READABLE CONSOLE:
  🐛 A PARKED ROW SHOWING THE SAME NOTE AS THE QUEUED ROW BELOW IT. Two
     screenshots taken four minutes apart both showed it, and in both the
     parked text matched the queued text exactly — which is not a thing
     that happens twice by chance. The reason line gave it away: "parked
     before this pad tracked reasons" is what prints when a note has no
     parkedAt and no lastError, and a QUEUED note never has either. So a
     queued note was living in the parked list as well.
  🔒 FIXED IN THE DATA, NOT IN THE VIEW. pad.normalize() runs on every
     load: if the two lists are literally the same table it separates
     them, and any parked entry whose id is already in the queue is
     dropped. THE QUEUED COPY ALWAYS WINS — it is the one that actually
     sends, so the parked twin is stale by definition. A genuinely parked
     note, with its own id, is never touched.
  📣 AND IT SAYS SO. Both repairs print to the Console. A silent fix here
     would have left me guessing at the cause again later.
  🧬 4 mutations caught, including "one table used as both lists goes
     undetected" and "the guard eats genuinely parked notes".
  🔇 THE CONSOLE IS WORTH READING AGAIN. hs.hotkey logged every enable and
     disable at info level, and the ⌥Tab switcher binds 32 arrow hotkeys
     on open and releases them on close — 64 lines per use. Three switches
     in half a minute buried the boot report and the pad's send results
     under ~200 lines of bookkeeping. Log level is "warning" now: real
     problems still print, the chatter does not.
  🧪 374 checks in test_features.lua, 801 across all six suites.
NEW IN 6.44.9 — SEND NOW SENDS THE NOTE YOU ARE LOOKING AT, AND THE PAD
STOPS DRAGGING HAMMERSPOON TO THE FRONT:
  🐛 "NOTHING HAPPENS OTHER THAN LOCAL ACTIONS." Reported with a
     screenshot: text typed, an image attached, "0 queued", and Send now
     answering that there was nothing to send. It was telling the truth
     and it was useless. "File it" moves the compose box into the queue;
     "Send now" sends the QUEUE. So a note still sitting in front of you
     was, to the code, not a note yet. That is a distinction the pad
     invented and the person using it has no reason to care about. Send
     now files the open draft first and then sends. Whitespace is still
     not a note, and a draft that cannot be filed (queue full) stops the
     send and says so rather than sending a half-state.
  🪟 HAMMERSPOON JUMPED FORWARD ANYWAY. 6.44.6 removed this module's
     launchOrFocus, which stopped it ASKING for the app to activate — but
     macOS activates an application whenever one of its ordinary windows
     becomes key, and the pad has to become key to accept typing. Removing
     the request was never going to be enough. The one exemption is a
     panel carrying NSWindowStyleMaskNonactivatingPanel, and hs.webview
     builds its window on NSPanel, so the bit applies here.
  ✅ AND IT IS VERIFIED, NOT ASSUMED. This file already carried one
     windowStyle() call that looked handled and did nothing. So
     pad.applyNonActivating sets the mask and then READS IT BACK, because
     AppKit silently drops style bits it will not honour. It reports what
     actually happened in pad.nonActivatingApplied, and when the mask does
     not take it prints the reason and names the switch that certainly
     works (capturePad.focusOnOpen = false — the pad then opens without
     taking the keyboard at all, and you click into it).
  🧪 THE REAL CHANGE IS HOW THIS IS NOW CHECKED. Every Capture Pad bug in
     6.44.x lived in the page's JAVASCRIPT, and the suites could only read
     that JavaScript as TEXT. Grepping source for a function name proves
     the name is present; it proves nothing about what happens when you
     click. tests/dump_pad_html.lua renders the page from the REAL module
     and tests/test_pad_js.js EXECUTES it against a DOM stub, driving the
     actual onclick strings, the keydown handler and the drag. It catches
     the 6.44.7 wiped-draft bug, which no structural test could.
  🧬 12 mutations caught across the two layers, 6 Lua and 6 JavaScript,
     including "Send now stops filing the draft", "applyNonActivating
     claims success without reading the mask back", and "Send now bypasses
     say() and posts a bare message".
  🩺 NEW: tools/run-tests.sh. One command, one exit code: syntax on
     init.lua and all 18 modules, the five Lua suites, then the page
     JavaScript. It says plainly what it did NOT check — a skipped stage
     is never reported as a pass.
  🧪 366 checks in test_features.lua, 793 across all six suites.
NEW IN 6.44.8 — A STALE PARKED NOTE CAN NOW BE READ AND CLEARED:
  🕰 "PARKED · (blank) · earlier" MEANT NOTHING. A note parked BEFORE
     6.44.5 has no lastError and no parkedAt, because nothing recorded
     them yet — so its row rendered an empty gap where the reason
     belongs, which reads like a display fault rather than missing
     history. It now says which it is: "parked before this pad tracked
     reasons", or "reason not recorded" when the time is known but the
     cause is not.
  🗑 DISCARD, WITH A CONFIRMATION. Until now the only exit for a parked
     note was putting it back in the queue — which re-parks it if it
     still fails, so a note that can never send (a project you lost
     access to) sat in the banner forever and the only real fix was
     hand-editing queue.json. There is a Discard button now. It asks
     first, because this is the ONE action in the pad that destroys a
     note; it removes the note's images too rather than orphaning them
     in the images folder; and it never touches the live queue.
  🧬 Three mutations on the new destructive path are caught, including
     "discard also wipes the live queue" and "discard stops asking".
  🩺 NEW: tools/hs-doctor.sh. One read-only command that reports what
     is ACTUALLY installed — versions, per-module fix markers, file
     completeness, whether the remap is live — and works even when
     Hammerspoon will not start. Too much of 6.44's debugging went on
     guessing at the Mac's state from here.
  🧪 343 checks in test_features.lua, 735 across all five suites.
NEW IN 6.44.7 — ATTACHING AN IMAGE NO LONGER WIPES WHAT YOU TYPED:
  🐛 TWO BUTTONS SENT NO TEXT. The draft lives only in the page's DOM
     until a message carries it to Lua, which then writes it back on the
     next redraw. Every KEYBOARD path passed it (text: t.value) — but
     the "Attach clipboard image" and "Send now" BUTTONS sent bare
     {a:'image'} and {a:'flush'}. Lua kept its stale copy (empty, on a
     fresh pad) and the redraw replaced everything typed with it. That
     is exactly why ⌘⇧V worked and clicking the button did not.
  🔒 FIXED IN ONE PLACE, NOT AT SEVEN CALL SITES. say() now attaches the
     live textarea to EVERY message it sends, so a button added later
     cannot forget. All the individual `text: t.value` arguments are
     gone, and a test asserts none come back.
  ⌨️ THE CARET SURVIVES THE REDRAW TOO. Attaching an image mid-sentence
     used to dump the cursor at the end of the draft; the position now
     travels with the message and is restored. It is clamped in
     JavaScript rather than Lua on purpose — selectionStart counts
     UTF-16 units while Lua's # counts BYTES, and the two disagree the
     moment an emoji is in the note.
  ⚠️ HONEST LIMIT ON THE TESTS: this bug lived in JavaScript, which
     cannot be executed from Lua. The new checks are STRUCTURAL — they
     prove no call site omits the text and that say() always attaches
     it — plus the Lua half is exercised for real. Three mutations,
     including the original bug, are caught.
  🧪 330 checks in test_features.lua, 722 across all five suites.
NEW IN 6.44.6 — ⇪N NO LONGER DRAGS THE CONSOLE FORWARD:
  🐛 OPENING THE CAPTURE PAD ACTIVATED THE WHOLE APPLICATION. show() had
     an hs.application.launchOrFocus("Hammerspoon") in it, which I added
     to get the caret into the textarea. Wrong tool twice over: it
     activates the APP, so every Hammerspoon window came forward with
     the pad — the Console most visibly — and it was not needed at all.
     allowTextEntry(true) already sets canBecomeKeyWindow inside
     hs.webview (it defaults to NO), and bringToFront() already calls
     makeKeyAndOrderFront:. Raising one window was the job; activating
     the app was collateral damage. The call is gone.
  ⚙️ capturePad.focusOnOpen (default true) decides whether the pad takes
     the keyboard when it opens. Set it false to have the pad appear
     without stealing focus and click into it yourself. Neither setting
     activates the application.
  🔍 CHECKED THE REST OF THE CONFIG FOR THE SAME MISTAKE: nothing else
     does this. The other activate() calls (App Peek, Window Arranger,
     ⌥Tab) target the app you are switching TO, which is their whole
     purpose.
  🧪 A test asserts the app is never activated, and a mutation putting
     the old call back is caught. 317 checks in test_features.lua,
     709 across all five suites.
NEW IN 6.44.5 — A PARKED NOTE NOW EXPLAINS ITSELF:
  ⚠️ THE WARNING LOOKED LIKE A LIVE ERROR ABOUT THE WRONG NOTE. The pad
     said "1 note could not be sent after 3 tries" and then listed the
     QUEUED notes underneath — so the row you were reading was never the
     one that failed, and the banner reappeared after every successful
     send. Nothing was broken; it was just impossible to tell that from
     looking at it.
  🖥 PARKED NOTES GET THEIR OWN ROWS now, badged PARKED, dated, and
     carrying the reason the send failed — taken from Asana's own error
     message ("HTTP 403 — Not Authorized to access project") rather than
     a bare count. The banner says the note is from an EARLIER send and
     states plainly that it will NOT go out until you put it back.
  🚩 THE BEHAVIOUR THAT CAUSED THE CONFUSION IS CORRECT AND STAYS: a
     parked note is never included in a later send. That is what parking
     is for — a note that failed for a real reason must not be retried
     silently behind you. It moves only when you press the button.
  🧬 A MUTATION SURVIVED AND WAS INVESTIGATED RATHER THAN PAPERED OVER.
     Making flush() fall through to the parked list changed nothing —
     because the empty-queue guard returns before that line is ever
     reached. Proven equivalent by removing the guard as well, at which
     point the suite fails. A new test covers the real scenario: Send
     now with an empty queue and something parked must post nothing.
  🧪 312 checks in test_features.lua, 704 across all five suites.
NEW IN 6.44.4 — TEN AUDIT PASSES, AND THE ONE REAL BOTTLENECK:
  ⚡ THE SEARCH PICKERS WERE O(history) PER KEYSTROKE. ⇪F and ⇪0 both
     run from queryChangedCallback, so their filter loop fires on EVERY
     character typed — and each pass rebuilt a concatenated, lowercased
     haystack for every row of retained history (90 days of file events,
     120 days of raw activity sessions, one row per window focus change).
     Measured: 18ms per keystroke at 10,000 rows, 78ms at 40,000. That
     is typing lag on the main thread, and it grows all year.
     The search string is now built ONCE per entry and cached on it —
     about 18x faster. Cost is one string per row; both CSV writers name
     their columns explicitly, so the cache never reaches disk.
  ⚡ THE FILE-TRACKER LOG WAS PRUNED ONLY AT BOOT. Its retention cutoff
     ran once, when the module loaded, so on a Mac left logged in for
     weeks the in-memory list grew without limit until the next reload —
     and every ⇪F keystroke scanned all of it. It now prunes every 200
     recorded rows, which keeps recording O(1) amortised.
  🔬 WHAT THE OTHER PASSES FOUND: nothing. 19 files compile; no
     discarded timer or watcher; no ipairs over a literal that can hold
     nil; no unprotected hs.json.decode; no hs.window.filter; no
     accumulate-in-a-loop string building; no io.open inside a loop; no
     unresolved bare-global call. Two audits were themselves WRONG and
     were fixed before trusting them — one regex spanned newlines and
     reported a valid forward declaration as a dangling global, another
     counted a nested warm() body as boot-path cost.
  🚫 ONE OPTIMISATION MEASURED AND REJECTED. The autocorrect event tap
     runs on every keystroke system-wide and uses two Lua pattern
     matches. Replacing them with lookup tables benchmarks 2.8x and 4.1x
     faster — and saves 0.188 MICROSECONDS per keystroke. Not worth the
     churn, so it was not made. Speed-up ratios without absolute numbers
     are how pointless work gets justified.
  🧬 THE TEST SUITE IS NOW MUTATION-TESTED. 14 real invariants were
     deliberately reversed to see whether anything failed. Two survived
     the first run — both cache tests, because they grepped the source
     for a variable name instead of driving the picker, so a mutation
     that stopped READING the cache left them green. Rewritten to poison
     a cache entry and prove it is read. 14/14 caught now.
  🧪 291 checks in test_features.lua, 683 across all five suites.
NEW IN 6.44.3 — PARKED NUMPAD, CLICK-TO-COPY DATES, PERMISSION SWITCH:
  🅿️ THE NUMPAD LAYER IS NOW PARKED, NOT LIVE. numpad.enabled = false
     ships by default: the 3x3 layout is kept as a worked-out plan in
     the cheat sheet under a PARKED banner, and NOT ONE ⇪ + pad key is
     bound, so every one of them stays free for whatever you decide
     later. Not binding is a real difference, not cosmetic — a disabled
     handler that still claimed the keys would swallow each press and
     do nothing, which is indistinguishable from a dead keyboard.
     ⚠️ A MACHINE PROFILE CANNOT switch it on: profile settings are
     applied AFTER setup(), and binding happens during setup, so the
     override would arrive too late to claim anything. Edit the one
     line in modules/numpad_layer.lua and reload.
  📋 CLICKING A DATE IN THE CALENDAR COPIES IT, as 08-07-26 — every
     part zero-padded to two digits so pasted dates line up in a
     column. The alert names the weekday too ("08-07-26 (Fri) copied"),
     because the point of copying a date is usually that you are about
     to commit to it. C copies the highlighted date without the mouse,
     with no repeat handler so holding it cannot refill the clipboard
     thirty times a second. cal.copyFormat changes the shape;
     cal.copyOnClick = false goes back to click-selects-only.
  🔐 ONE SWITCH FOR THE ONE PERMISSION THIS CONFIG ACTUALLY NEEDS.
     altTab.useSnapshots = false. hs.window:snapshot() — photographing
     another app's window for the ⌥Tab tiles — is the ONLY call in the
     whole config that macOS treats as a screen capture, and therefore
     the only reason it ever asks for Screen Recording. Turn it off and
     every tile shows the app icon instead, the switcher is otherwise
     identical, and macOS is never asked. A test asserts snapshot() is
     called exactly zero times with the switch off.
  🧪 269 checks in test_features.lua, 116 in test_switcher.lua,
     661 across all five suites.
NEW IN 6.44.2 — CAPTURE PAD: DRAGGABLE, RELIABLE, AND CAPTIONED:
  🖱 THE PAD MOVES NOW. Drag it by its header bar. hs.webview builds
     its window with NSWindowStyleMaskBorderless hard-coded in the
     extension's own source and never sets movableByWindowBackground,
     so there is no native title bar and the windowStyle({"titled",…})
     call this module used to make was being ignored outright. The
     drag is driven from LUA rather than JS mousemove, and that matters:
     a WKWebView stops receiving mouse events the instant the pointer
     leaves it, so a JS-driven drag dies the moment you move faster
     than the window follows. Lua polls the real mouse position and
     the real button state instead, so a mouse-up released anywhere on
     screen still ends the drag.
  🔁 WHY SENDING WAS INCONSISTENT. 6.44.1 fixed the ordering bug that
     made attachments fail EVERY time; what was left failed only
     SOMETIMES. Feeding the auth header on curl's stdin means writing
     into a pipe that curl's own read loop is already running against —
     a race, and races do not fail consistently. The header now goes
     into a short-lived FILE: written, chmod 600, and closed before
     curl is even created, handed over as -H @<path>, and deleted the
     moment the upload's callback fires. A file curl opens after it is
     already complete on disk has nothing left to race. warm() also
     sweeps that folder at boot, so a force-quit mid-upload cannot
     leave a token sitting on disk.
  🗒 A NOTE WITH AN IMAGE KEPT ITS TEXT. The description was built only
     for notes too long for their own title, so a short note plus a
     screenshot produced a description reading "1 image attached." and
     a timestamp — the caption was dropped exactly when the image made
     it matter most. An image now always brings the note's text with it.
  ♻️ PARKED NOTES ARE RECOVERABLE. A note that failed maxRetries used
     to be reachable only by hand-editing queue.json. The pad now shows
     a button that puts them all back in the queue with their attempt
     count reset, for retrying a send that failed for a reason since
     fixed.
  🐛 CAUGHT BY ITS OWN TEST, IN MY OWN NEW CODE: beginDrag() set the
     grab offset and THEN called endDrag() to clear any previous drag —
     which wiped the offset it had just stored. The drag test failed on
     the first run and named it exactly.
  🧪 246 checks in test_features.lua, 632 across all five suites.
NEW IN 6.44.1 — CAPTURE PAD: THE IMAGE ATTACHMENT BUG, AND THE FONT:
  🐛 EVERY IMAGE ATTACHMENT WAS SILENTLY FAILING. Two bugs in
     uploadAttachment, both now covered by a test that reproduces the
     exact failure:
       1. setInput() was called AFTER t:start(). The Hammerspoon docs
          say setInput "can be called before the task has been
          started, to prepare some input for it" — for a task with no
          streaming callback (this one), stdin is wired up from
          whatever was already queued when the task starts. Called
          after, the data missed the window: curl hit EOF on stdin
          immediately, posted with NO Authorization header, Asana
          returned 401 — and curl still exits 0, because it only
          fails on a transport error, never an HTTP one. Fixed by
          calling setInput() before start(), and closeInput() is no
          longer called at all: the docs say it is only for a task
          WITH a streaming callback, and this one has none.
       2. The failure branch printed `tostring(err or out)`, meant to
          prefer stderr and fall back to the response body — except
          "" is TRUTHY in Lua, so an empty stderr string always won
          that `or`, hiding the actual 401 body behind a blank line
          in the Console every single time.
     The upload now also verifies the REAL HTTP status via curl's
     `-w "%{http_code}"` instead of guessing from whether the body
     contains the word "errors", and switched from `-K -` (a config
     file with exact quoting rules) to `-H @-` (one plain header line
     on stdin) — simpler, and nothing left to get the quoting wrong.
     A note whose task sends but whose image does not attach is no
     longer reported as a clean "N sent" — the flush summary now says
     so, names the task's gid, and the Console gives the real reason.
  🖼 EACH PINNED IMAGE NOW HAS A ✕. Pin the wrong one with ⌘⇧V and you
     can take it back off before filing, rather than wondering whether
     it is really attached to the note you are about to send.
  🔤 THE COMPOSE BOX FONT WAS NEVER ACTUALLY 14px. `font:14px inherit`
     is invalid CSS — the `font` shorthand only accepts the `inherit`
     keyword as its ENTIRE value, never mixed with an explicit size —
     and WebKit drops an invalid shorthand rule outright rather than
     applying the size and ignoring the rest. The textarea was quietly
     running on its browser default the whole time. Now set as plain
     longhand at 16px, box height raised 120px → 180px, and general
     text bumped 14px → 15px.
  🧪 227 checks in test_features.lua now drive the REAL webview path
     (a stub was added — the suite previously only exercised the
     no-webview fallback), reproducing the exact curl-exit-0/HTTP-401
     failure and asserting the Console shows the real response body.
NEW IN 6.44.0 — FIVE NEW FEATURES, AND ARROWS IN THE SWITCHER:
  ⌨️ ⌥TAB TAKES ARROW KEYS. Keep ⌥ down: ← → step one tile, ↑ ↓ jump a
     WHOLE ROW — six tiles a press on a six-column grid, which is the
     point when the list is thirty windows long. Home/End jump to the
     ends and Return switches without waiting for the ⌥ release. ↑ ↓ do
     NOT wrap: the target row has to exist, so ↑ on the top row leaves
     the highlight alone rather than teleporting it, and ↓ into a
     ragged last row lands on the nearest real tile.
  🐛 A REAL BUG FOUND WHILE BUILDING THAT: Esc has NEVER worked during
     an ⌥Tab hold. hs.hotkey matches modifier flags EXACTLY, the HUD
     only exists while ⌥ is held, and Esc was registered under the bare
     {} mask — so the cancel key could not fire during the one session
     it existed for. Every in-HUD key is now registered under all four
     live masks ({}, ⌥, ⇧, ⌥⇧), and a test asserts it.
  🌗 SCREEN VEIL (⇪G). A chrome-less, click-through sheet over EVERY
     connected display; ⇪⇧G cycles Movie 20% → Reading 40% → Dim 60% →
     Deep 75% → Max 90%, ⇪⇧= / ⇪⇧- nudge by 5%. HARD-CAPPED at 90% so
     it never reaches opaque, ⌃⌥⌘⇧G is a panic key bound OUTSIDE hyper,
     and a reload always comes back clear (the strength is remembered,
     the on-switch is not).
     ⚠️ HONEST LIMIT: this DIMS AND MUTES, it does not DESATURATE. A
     canvas composites on top and never sees the pixels underneath, and
     a gamma table is one curve per channel so it cannot average them
     either. True black-and-white lives in System Settings →
     Accessibility → Display → Color Filters → Grayscale, which runs
     inside WindowServer. The two stack.
  🗒 CAPTURE PAD (⇪N). Jot notes and pin clipboard images all day; at
     16:00 every note becomes an Asana task in your project. Titles
     follow the rule you specified: "Verb + rest of task" when the
     sentence asks for an action, "Note :: rest" otherwise, 10 words
     either way, with the overflow and the images going to the
     description. Start a note with ! to force a task or ? to force a
     note. ⇪⇧N sends now. NOTHING LEAVES THE QUEUE BEFORE ASANA
     RETURNS A GID, failures are retried and then parked, never
     dropped. 🔐 The token is fed to curl on stdin, never as an
     argument, so it is not in the process table.
  🗓 MINI CALENDAR (⇪⇧0). 1024×768, translucent black, 16px numbers,
     three months, current week banded, ±1 year and no further. Arrows
     walk days, ↑↓ weeks, [ ] months; it is clickable without stealing
     focus, and a menu-bar date opens it without Bartender.
     ⏰ Every date is built at NOON and stepped by 86400: midnight + 24h
     is 01:00 on the spring-forward day and 23:00 the SAME day in
     autumn, so a midnight-based "next day" silently stalls twice a
     year. Tested under a DST timezone, not just UTC.
  📝 QUICK APPEND (⇪J). Puts the clipboard into a text file without
     opening it — append mode, closed again before the alert. ⇪⇧J picks
     the file or offers a box to type into. Every write is checked:
     io.open returns nil rather than raising, so an unavailable OneDrive
     folder would otherwise fail in complete silence.
  🔢 NUMPAD LAYER (⇪ + number pad). YES, the number pad is a separate
     key path — pad7 is key code 89, the number-row 7 is 26, and both
     are free at the same time. The layer is a MAP, not a list: the pad
     is a 3×3 grid and so is your screen, so ⇪pad7 is the top-left
     quarter, ⇪pad4 the left half, ⇪pad5 the centre. Nothing to
     memorise. (Accessibility → Pointer Control → Mouse Keys eats the
     whole pad when it is on; that is the first thing to check.)
  🔀 ORDER NUMBERS ARE NOW GUARDED. The five new cheat-sheet groups sit
     at 13.1-13.5, and a test asserts every group's slot is unique —
     Lua's table.sort is not stable, so a tie makes the sheet reshuffle
     itself on every reload.
  🧪 593 checks across five suites, all passing.
NEW IN 6.43.1 — PROVING 6.43.0 IS SAFE ON THE OTHER MAC:
  ✅ THE PERSONAL MAC DOES NOT REGRESS, and this is tested, not
     asserted: a system install at /opt/homebrew is still found, the
     daily check is still scheduled, and warm() starts NO login shell
     when brew was already located. The shell is consulted only when
     the well-known paths miss — which on that Mac they do not.
  🔀 ONE REAL GAP THE TEST FOUND: a Mac can carry BOTH a leftover
     ~/homebrew AND a working /opt/homebrew. List order was picking
     between them blindly. Now — and ONLY in that case — the shell is
     asked which brew is actually on PATH, because that is the one
     `brew` means when you type it. The Console says which was chosen
     and which was ignored, instead of silently preferring one.
NEW IN 6.43.0 — HOMEBREW ON A MAC WITHOUT ADMIN RIGHTS:
  🍺 WHAT BROKE: the work MacBook said "Homebrew not found" while
     Homebrew was running perfectly in the next window. The tracker
     checked /opt/homebrew and /usr/local — the two places an ADMIN
     install goes. Without admin rights Homebrew installs to a custom
     prefix under your OWN HOME (~/homebrew), which neither path sees.
     That was my assumption baked in, not a broken Mac.
  🔍 DISCOVERY, IN TWO STEPS. The home-directory prefixes are checked
     first (cheap, no process). If none match, warm() asks your LOGIN
     shell with `command -v brew` — authoritative, because your shell
     profile is exactly what puts a custom prefix on PATH. It runs in
     warm() rather than setup() because starting a login shell costs
     100-300ms and that does not belong on the boot path. Finding it
     there also schedules the daily check that had been skipped.
  🗒 WHEN IT REALLY IS ABSENT, the message now LISTS EVERY PATH TRIED
     and tells you how to pin it, instead of "not found" with no
     detail on a Mac where brew is one directory away. Pin it with
     M.config.brewPath, or per machine from a profile.
  🐛 CAUGHT BY THE NEW TESTS MID-FIX — A CLASSIC LUA TRAP: the
     candidate list was written as
         ipairs({ M.config.brewPath, "~/homebrew/bin/brew", ... })
     and that first field is nil unless you set it. ipairs STOPS AT
     THE FIRST nil, so the loop body never executed once and NO path
     was ever checked on ANY Mac. Nothing errored — the search just
     silently did nothing. The list is built with table.insert now.
NEW IN 6.42.0 — DANGLING CALLS FIXED + A GUARD SO THEY CANNOT RETURN:
  💥 WHAT BROKE: ⇪0 crashed with "attempt to call a nil value (global
     'renderActivityChoices')". When §3.6 became a module its
     functions went with it, but hotkey handlers left behind in THIS
     file kept calling them by bare name. Lua turns a vanished local
     into a nil GLOBAL — no compile error, no boot error, nothing at
     all until the key is pressed. A static scan found TWO:
       · renderActivityChoices  → activity_tracker.lua   (⇪0)
       · addCommentToTask       → asana_comments.lua     (task
         creator auto-comment, and the dashboard's comment prompt)
  🔌 FIXED PROPERLY, NOT PATCHED — A SERVICE REGISTRY. A module now
     PUBLISHES what the rest of the config may call:
         core.provide("activity.renderChoices", fn)
     and anything else calls it with:
         _G.service.call("activity.renderChoices", "")
     A missing provider PRINTS which module is absent and returns nil
     instead of throwing, so an unloaded module degrades to a dead
     key with an explanation rather than a red error. The registry is
     stubbed on line one so it can never itself be nil, and ⇪⇧D lists
     every published service.
  🛡 THE GUARD THAT SHOULD HAVE EXISTED. The audit suite already
     checked that no MODULE reaches into init.lua's locals. It never
     checked the reverse — that init.lua does not call something that
     LEFT. It does now: the audit walks init.lua for calls to any
     function defined in any module file. That check is what would
     have caught this before delivery.
  🍺 HOMEBREW: ONE BREAKAGE, ONE MESSAGE. A corrupt brew API cache
     fails every cask at once, and the tracker printed "check the
     token in updateTrackerApps" fifteen times — sending you to fix
     something that was never wrong. The two causes are told apart
     now, and the brew-side one is reported ONCE per check with the
     actual repair:  rm -rf "$(brew --cache)/api" && brew update --force
NEW IN 6.41.0 — ⌥TAB: A DEADLINE, A CACHE, AND A NAMED CULPRIT:
  🧊 WHAT HAPPENED: on a real Mac, ⌥Tab took 15.90 SECONDS across 15
     apps. The per-application Accessibility sweep that 6.39.0 added
     to reach other desktops can block for a second or more PER APP
     (an app swapped out after an idle period is the usual reason),
     and fifteen of those in a row is a freeze, not a switcher. The
     6.39.0 instrumentation is what turned it into a number instead
     of a mystery — but a number is not a fix.
  ⏱ A HARD DEADLINE. altTab.listBudget (0.8s) is checked BEFORE each
     application, so it caps what gets asked for rather than
     reporting what was already spent. When it trips, the switcher
     opens with what it collected and the HUD says "list cut short",
     because a partial list you can see beats a complete one that
     arrives 16 seconds late — and a silently short list is the bug
     class this config keeps refusing to ship.
  🎯 THE CULPRIT GETS NAMED. Every application is timed individually;
     the Console and ⇪⇧D report the slowest one by name. If a single
     app is responsible, put it in altTab.skipApps and it is never
     asked again. That turns an unfixable "sometimes slow" into a
     one-line fix.
  💾 A SHORT CACHE (altTab.cacheFor, 4s) so repeated presses do not
     re-pay the cost. Short on purpose: a stale switcher missing the
     window you just opened would be worse than a slow one.
  🚫 NO BACKGROUND REFRESH, DELIBERATELY. A timer running this sweep
     every few seconds would move the freeze somewhere you cannot see
     it coming — strictly worse than a slow keypress.
NEW IN 6.40.0 — FEATURES ALL MODULAR · MACHINE PROFILES · WARM-UP:
  🧩 FOUR MORE SECTIONS OUT: Activity Tracker, App Update Tracker,
     Asana Comments, Document Watcher. THIRTEEN modules now, and this
     file is 5,377 lines — down from 9,529 at 6.35.0, a 44% cut.
     What remains here is core plus two pieces of infrastructure
     (the cheat sheet and the hyper key) that everything depends on.
  💻 MACHINE PROFILES (§1.12). The same init.lua and the same
     modules/ folder go on BOTH Macs; a table keyed by machine name
     is the only thing that differs. It lists which modules load and
     can override any module's `config` per machine, so a work Mac
     can run a lower ⌥Tab cap without editing the module. An unknown
     machine falls back to `default` and SAYS SO in the boot report
     rather than quietly loading nothing. Set your work Mac's name
     from `scutil --get ComputerName`.
  ⏱ PERFORMANCE — A WARM-UP PHASE. A module may define warm(), which
     the loader runs ~2s AFTER boot on a HELD timer. Autocorrect is
     why: parsing an 11,000-row CSV was the most expensive thing this
     config did at startup, and it bought nothing — a typo-corrector
     cannot help you before the desktop has drawn. The event tap now
     starts instantly and the dictionary arrives a moment later.
     setup() and warm() are timed separately in ⇪⇧D.
  🐛 TWO EXTRACTION BUGS, BOTH CAUGHT BY TESTS, BOTH WORTH KNOWING:
     1. Removing §3.6 deleted the ONLY definitions of csvQuote and
        splitCSVLine. Lua turns a vanished local into a GLOBAL lookup,
        so the file still COMPILED and would have crashed at boot the
        moment the changelog writer ran. Both are promoted into a new
        §1.4 — a compile that succeeds is not proof of anything.
     2. A `do` anchor matched the letters "do" inside a word in a
        comment and cut a module in half. Anchors are line-exact now.
  📖 HAMMERSPOON-GUIDE.md ships alongside: layout, install, the
     two-Mac workflow, how to write a module, and a troubleshooting
     table keyed by symptom.
NEW IN 6.39.0 — ⌥TAB NOW SEES EVERY DESKTOP, NOT JUST THIS ONE:
  🖥 THE BUG: ⌥Tab listed only the windows on the desktop you were
     looking at. hs.window.orderedWindows() and hs.window.allWindows()
     report ONLY the current Mission Control Space — a documented
     macOS limit, not a Hammerspoon bug. Hammerspoon's own documented
     answer is hs.window.filter, which is the module that froze this
     Mac for 44 seconds in 6.33.0, so that door stays shut.
  🔑 THE THIRD ROUTE: ask each APPLICATION for its own windows. The
     Accessibility API has no concept of a Space, so an app hands over
     its windows wherever they are — other desktops, other monitors,
     minimised. Only GUI apps are asked (app:kind() == 1), which skips
     exactly the background and menu-bar agents whose AX timeouts made
     window.filter unusable. The current Space is still listed FIRST,
     front-to-back, then everything else is appended and deduplicated
     by window id.
  📦 EVERY OPEN PROGRAM, not just every open window: minimised windows
     are included by default now, and a running app with NO window at
     all gets its own tile that ACTIVATES the app when selected.
     Cap raised 24 → 36. Knobs: altTab.includeOtherSpaces,
     includeApps, includeMinimized, maxWindows.
  🐛 CAUGHT BY THE TESTS MID-CHANGE: an app whose windows had all been
     picked up by the current-Space pass contributed nothing new in
     the per-app pass, so it looked like it owned no windows and got a
     second, bogus "no open window" tile — one per app on your current
     desktop. Ownership is now derived from the assembled entries.
  🔊 A failed enumeration phase PRINTS again (the rewrite had made it
     silent), and a failure on the current Space now degrades to the
     per-app list rather than to an empty switcher.
NEW IN 6.38.0 — THREE MORE OUT (nine modules, init.lua −27%):
  🧩 App Watcher (§3.7), File Tracker (§3.8) and Autocorrect (§3.9)
     are now modules. init.lua is 6,952 lines, down from 9,529 at
     6.35.0 — a 27% reduction, and every module file carries its own
     fresh 200-local budget.
  🔧 splitCSVLine MOVED INTO core. It was declared inside §3.6 but
     used by three OTHER sections — always a shared helper living in
     the wrong place. Moving it is precisely what let File Tracker
     and Autocorrect leave, and it is the pattern for the sections
     still waiting: find the helper the section is squatting on,
     promote it to core, THEN move the section.
  ✅ Autocorrect still publishes _G.autocorrectStatus and
     _G.autocorrectTap, so the boot report and ⇪⇧D read them exactly
     as before — the diagnostics did not need to know it moved.
NEW IN 6.37.0 — THREE MORE SECTIONS MOVED OUT:
  🧩 Window Arranger (§1.9), Copy-on-Select (§3.11) and Command
     History (§6.5) are now modules. Six in total; this file is down
     from 9,529 lines at 6.35.0 to 7,947.
  🔑 core.hyperAddShortcut — the supported way for a module to claim a
     ⇪ key. Wrapped rather than captured so it resolves at CALL time,
     which keeps the core table honest if §3.12 ever moves. Command
     History uses it, and carries a note that this only works because
     §1.12 loads modules BEFORE hyperFinalize drains the queue: move
     the loader earlier and that shortcut would silently never bind.
  ⚠️ Copy-on-Select declares NO cheat sheet group on purpose — its one
     entry (⇪⇧C) belongs to the 📋 CLIPBOARD & OCR group, which is
     still in this file. Splitting it out would drop a one-line group
     into the middle of the sheet for no benefit. Stated in the
     module rather than left as a silent inconsistency.
  🐛 AN EXTRACTION BUG THE TESTS CAUGHT: the old §3.11 wrapped its
     locals in a do...end block to stay under the 200-local budget.
     Moving the body into M.setup() split that `do` from its `end`
     across the function boundary — which still COMPILED, and made
     the module return nil instead of its contract table. The
     loader's "does not return a table with a setup() function"
     check is what caught it, which is precisely why it exists.
     The wrapper is gone now: a function scopes its locals already.
NEW IN 6.36.0 — MODULES: SECTIONS NOW LIVE IN THEIR OWN FILES:
  🧩 NEW §1.12 MODULE LOADER. Sections can now live in
     ~/.hammerspoon/modules/<name>.lua and are listed in moduleList.
     Three moved out first — Daily Backup (§1.7), App Peek (§1.8) and
     Window Switcher (§1.10), 464 lines out of this file. Everything
     not yet moved still works exactly as before: the two styles
     coexist on purpose so the move happens a few sections at a time
     instead of as one all-or-nothing rewrite.
  📏 WHY IT MATTERS MORE THAN TIDINESS: Lua's 200-local limit is PER
     CHUNK, and a file is a chunk. This file was measured at exactly
     200 with ZERO headroom in 6.35.0 — the next top-level `local`
     anywhere would have been a compile error taking the WHOLE config
     down. init.lua is at 12 free now, and every module file gets its
     own fresh 200.
  📖 THE CHEAT SHEET IS ASSEMBLED, NOT HARD-CODED. Each module
     registers its own group when it loads, and groups sort by an
     explicit UNIQUE order number (unique because table.sort in Lua
     is not stable — equal keys could reshuffle between reloads).
     Delete a module file and its group goes with it, instead of the
     sheet advertising a shortcut nothing binds — the exact drift the
     "hand-written snapshot" warning has apologised for since 6.10.
  🛟 FAILURE IS ISOLATED, which is the other half of the point. Every
     module is loaded, executed AND set up inside its own pcall: a
     syntax error in one costs you that module, not your hotkeys, not
     autocorrect, not the whole config. Before this, one bad line
     anywhere meant NOTHING loaded. Failures are named in the
     Console, counted in the boot report, listed in ⇪⇧D and shown as
     a ⚠️ group at the TOP of the cheat sheet.
  ☁️ MODULES LOAD FROM LOCAL DISK, DELIBERATELY. Loading them from
     the OneDrive folder would save a copy step and is the wrong
     trade: Files-On-Demand can leave a file as an online-only
     placeholder, and reading one triggers a SYNCHRONOUS download —
     a main-thread stall at every login on a slow network, the same
     failure shape as the 6.33.0 ⌥Tab freeze. Master copies live in
     OneDrive for durability and for copying to another Mac; the
     loader only ever reads local disk. The 5pm backup already
     rsyncs ~/.hammerspoon, so modules/ is covered automatically.
NEW IN 6.35.0 — APP LOCK REMOVED · DIAGNOSTICS ADDED · AUDIT FIXES:
  🗑 APP LOCK IS GONE. The whole PIN-gate feature (old §6.6, ~1150
     lines) has been deleted: the manager, the covers, the PIN
     prompts, the re-lock watcher, the panic key and its cheat sheet
     group. applock.json is STILL excluded from the backup, so a
     leftover file from an older version can never sync anywhere.
  🩺 NEW §1.11 DIAGNOSTICS — ⇪⇧D. Writes one report containing
     versions, boot timings, screens, hotkey counts, feature states,
     file paths with their write status, a LIVE window-enumeration
     timing, recent errors and the last 25 internal events — to the
     Console, your clipboard AND Logs/diagnostics-<machine>.txt.
     A 200-entry trail is recorded in memory ALWAYS, so the report
     shows what happened before a problem even though verbose was
     off at the time — which is the normal case, because nobody
     turns verbose on until after something breaks. Live verbose:
     type  _G.diag.verbose = true  in the Console, no reload.
     hs.uncaughtErrorHandler is now set, so an error thrown inside
     an async callback (HTTP reply, timer, watcher — everywhere a
     pcall in the calling function cannot reach) is captured with a
     timestamp instead of scrolling past.
  🔴 AUDIT FIX (MAJOR) — JSON OFF THE NETWORK COULD THROW. All six
     hs.json.decode calls on Asana replies ran unprotected INSIDE
     async HTTP callbacks. hs.json.decode RAISES on malformed input,
     and a corporate proxy or captive portal answering HTTP 200 with
     an HTML login page is precisely that — likelier on a work
     network than a broken API. The throw escaped every enclosing
     pcall. All six now go through _G.safeJson, which logs how many
     bytes arrived and how they start, then returns nil so the
     caller's existing "if not data" branch handles it.
  🟠 AUDIT FIX (MEDIUM) — THE FILE WAS ON THE 200-LOCAL CEILING WITH
     ZERO HEADROOM. Measured, not guessed: the main chunk of a Lua
     file IS a function, the limit is 200 locals per function, and
     this file was at exactly 200. The next `local` added ANYWHERE at
     top level would have been a compile error taking the WHOLE
     config down — a landmine for whoever edited next. §1.6's nine
     loose locals were folded into the cheatSheet table it already
     had, which buys 8 back. New sections must namespace.
  🟠 AUDIT FIX (MEDIUM) — the diagnostics API is now declared as a
     no-op stub on the FIRST line of the file and extended by §1.11.
     Sections earlier in the file log through it, so a partial load
     that never reached §1.11 would have thrown on a logging call:
     a diagnostics system causing the outage it exists to explain.
  🟠 AUDIT FIX (MEDIUM) — ⌥Tab captured thumbnails for up to 24
     windows and THEN trimmed the list to what the screen could hold,
     so a laptop captured 24 images to draw 15. Snapshots are cheap
     but not free (~5-20ms each) and that waste lands on the keypress
     you are waiting on. The grid is now worked out first, the list
     trimmed, and only the survivors captured — timed, and reported
     in the Console if it ever crosses 0.35s.
  🟡 AUDIT FIX (MINOR) — a leaked file handle: the changelog writer
     tested for the CSV with io.open(...) == nil and never closed
     what it opened, leaving it to the garbage collector.
  ⏱ Boot report now prints total load time, so a slow start is a
     number you can quote rather than a feeling.
NEW IN 6.34.0 — ⌥TAB SWITCHER REBUILT (6.33.0 FROZE THE MAC):
  🧊 WHAT WENT WRONG. 6.33.0's switcher beachballed Hammerspoon for
     44 seconds on the FIRST ⌥Tab. The Console dated it exactly:
       10:01:25  -- Loading extensions: window.filter
       10:02:09  ✏️ Autocorrect tap was disabled by macOS — revived
     macOS switches an event tap off when the owning app stops
     answering, so that second line is the main thread returning.
     CAUSE: hs.window.switcher is built on hs.window.filter, which
     enumerates and then SUBSCRIBES TO every running application over
     the Accessibility API — and clearing the default filter to get
     minimised windows pulled hidden and background apps in too. Each
     unresponsive app costs a full AX timeout, on the one thread
     Hammerspoon has. That is not tunable; the module was the wrong
     tool for a Mac with a lot of apps open.
  🔨 REBUILT WITHOUT hs.window.filter. §1.10 now lists windows with
     hs.window.orderedWindows() — one snapshot, already front-to-back,
     no watchers, GUI apps only — draws its own tile grid on hs.canvas
     and watches for the ⌥ release by POLLING
     hs.eventtap.checkKeyboardModifiers on a timer instead of adding
     another event tap macOS can switch off.
  📏 IT MEASURES ITSELF. Every enumeration is timed; anything past
     0.35s prints how long it actually took and which knob to turn.
     A slow machine now reports a number instead of a beachball.
     The list is capped (altTab.maxWindows = 24) — a bounded cost
     instead of a promise that can't be kept.
  🗑 A SECOND BUG, FOUND WHILE FIXING THE FIRST: 6.33.0's warm-up
     timer was created and its object thrown away on the same line.
     An unreferenced hs.timer is garbage-collected, so it never
     fired. Every timer here is stored.
  🛟 Esc cancels without switching · a watchdog closes a stuck HUD
     after 30s · altTab.enabled = false is a panic switch that makes
     ⌥Tab inert without touching anything else in this file.
  ⚠️ MINIMISED WINDOWS ARE OFF BY DEFAULT now (they need the slower
     hs.window.allWindows call): altTab.includeMinimized = true.
NEW IN 6.33.0 — ⌥TAB WINDOW SWITCHER (§1.10):
  🔄 WINDOWS-STYLE ALT+TAB, WHICH macOS DOES NOT HAVE. Hold ⌥ and tap
     Tab to walk every open WINDOW with a thumbnail tile each (title
     underneath), ⌥⇧Tab to walk back, release ⌥ to switch. ⌘Tab
     switches APPS and buries a five-window app behind one icon;
     this is per-window. ⌘Tab itself is untouched — macOS reserves
     it, as §0.3's own knownSystemCombos table says.
     Lists minimised windows and hidden apps too (altTab.includeHidden
     = false for visible-only), across all Spaces.
  ⚡ COSTS NOTHING AT BOOT. hs.window.filter has to subscribe to every
     running app and enumerate its windows, so it is built on the
     FIRST ⌥Tab and cached — then warmed quietly 5s after boot so
     that first press is instant anyway.
  🛟 DEGRADES INSTEAD OF DYING. Every setup step is pcall'd with a
     fallback: UI prefs rejected → stock look; custom filter fails →
     default filter. A plain-looking switcher still switches windows;
     an error during setup would have left ⌥Tab dead and silent.
  📖 CHEAT SHEET REORDERED to how you actually reach for things:
     App Monitor first, App Peek under Window Arranger, the new
     switcher after it, then App Updates → App Lock → File Tracker →
     Document Watcher, Autocorrect under Command History, Help last.
NEW IN 6.32.1:
  📖 HELP MOVED TO THE BOTTOM. The ❓ HELP group sat in the middle of
     the feature groups; it now comes last of the built-ins, directly
     after ☁️ BACKUP. Your own ⭐ entries still follow it.
NEW IN 6.32.0 — CHEAT SHEET IS ONE SCROLLING COLUMN:
  📜 IT GROWS DOWN, NOT SIDEWAYS. The sheet used to fill a column and
     then start another one to the right, so a long list spread into a
     wall of text. It is now a SINGLE column you scroll: ↑↓ a row at a
     time (hold to keep going), PgUp/PgDn a screenful, Home/End to the
     ends, or the scroll wheel / trackpad. A scrollbar and an
     "N–N of N" counter in the footer show where you are.
     The wheel is only claimed while the pointer is OVER the sheet —
     anywhere else it passes through, so the window underneath still
     scrolls normally with the sheet open beside it.
     ⚠️ Esc, the arrows, PgUp/PgDn and Home/End are captured GLOBALLY
     while the sheet is up (it takes no keyboard focus, so that is the
     only way it can hear them). Close it and they all go straight
     back to the app underneath.
  🫥 TRANSLUCENT AGAIN, BUT READABLE. The sheet now has its OWN
     see-through setting (cheatSheet.alpha = 0.75, top of §1.6) rather
     than sharing panelAlpha, and sits on a near-black panel instead
     of a grey one. That combination is the point: at the same alpha a
     darker panel holds white text at roughly 8:1 contrast, so you can
     see the window behind the sheet without the shortcuts fading into
     it. panelAlpha (0.90) still governs the legend strip and draft
     mirror — the two are now independent.
  ⚡ COST NO LONGER GROWS WITH THE LIST. Only the rows actually in
     view become canvas elements (~30), so 300 custom entries paint
     exactly as fast as 30. Scrolling changes one number and repaints
     that window of rows.
  📍 A REDRAW KEEPS YOUR PLACE. Adding, editing or deleting an entry
     while the sheet is open no longer throws you back to the top; a
     fresh ⇪/ still opens at the top. If the list gets SHORTER than
     where you were, the view clamps back into range instead of
     leaving you on blank rows.
  🧱 STRUCTURAL — the section is now one namespaced table
     (`local cheatSheet = {}`) instead of loose top-level locals.
     This file was at Lua's hard ceiling of 200 locals per chunk, and
     the main chunk IS a function: adding the scroll machinery as
     loose locals blew past it, which is a COMPILE error — the whole
     config would have refused to load, not just the cheat sheet.
     Fields on one table cost exactly one local however many are
     added later.
NEW IN 6.31.0 — CHEAT SHEET LEGIBILITY + HYPER W SWAP:
  📖 CHEAT SHEET ENTRIES NO LONGER GET CUT OFF. Every entry was one
     canvas text element in a fixed-width frame, so anything wider
     than the column was silently clipped mid-sentence — "F1-F12 —
     Not forwarded — macOS reserves some" just stopped there, with
     nothing to indicate text was missing. Long entries now wrap onto
     indented continuation lines. Width is ESTIMATED, not measured
     (hs.canvas exposes no text metrics), so the estimate is
     deliberately conservative: wrapping a word early is invisible,
     overrunning the column is the bug.
     Also fixed while in there: the width maths now counts CHARACTERS
     via utf8.len, not bytes. ⇪, ⌘ and — are multi-byte, so # would
     have over-counted them badly and wrapped far too early.
  🫥 PANELS 10% LESS TRANSLUCENT: panelAlpha 0.80 → 0.90. Affects the
     cheat sheet, the dashboard legend strip and the draft mirror.
  🖱 A CLICK NO LONGER CLOSES THE CHEAT SHEET. A stray click anywhere
     on a very wide panel used to dismiss the reference you were
     reading. It now stays up until you press Esc or ⇪/ deliberately.
     Mouse events are off entirely, so clicks pass through to whatever
     is underneath instead of being swallowed.
  ⌨️ HYPER W SWAPPED: ⇪W now summons an app to this monitor (the one
     reached for constantly) and ⇪⇧W opens the Document Watcher.
NEW IN 6.30.1:
  🧹 HOUSEKEEPING: removed the legacy "Lee additions / Be sure to
     have this added in" app list from the header (the watched-apps
     list in §3.7 IS the live list and always has been). Date stamp
     now always reads "MM-DD-YY using Claude". Added a changelog CSV
     at <logsDir>/changelog.csv — every version's verbose notes are
     written there on first boot (Excel-ready: Date | Version |
     Change notes). When the next MAJOR version lands (7.0.0), the
     in-file changelog for 6.x will be compressed to one-liners.
NEW IN 6.30.0 — APP LOCK: NEW KEY, OVERLAY-ONLY, NO REDUNDANT UNLOCK:
  ⌨️ THE MANAGER MOVED: ⇪⇧L → ⇪⇧H. (⇪H on its own is still Command
     History — hyper+H and hyper+shift+H are different combos, and the
     sentry confirms no conflict.) Nothing else about the manager
     changed. The cheat sheet and boot report were updated with it.
  🪟 OVERLAY ONLY, NO HIDING (appLockCoverThenHide now false).
     A locked app is no longer hidden and focus is no longer thrown to
     Finder — the app is left exactly where it sits and an opaque
     panel is painted over its screen. Hiding was what moved focus,
     and moving focus was the monitor-to-monitor bounce, so removing
     the hide removes the bounce by construction.
     TWO honest exceptions, both deliberate: if the cover cannot be
     painted at all it falls back to hiding rather than leaving the
     app exposed, and a CANCELLED or WRONG PIN hides it too — at that
     point the cover must come down, and an app left on screen with
     no PIN entered is exactly the leak this feature prevents.
  🔧 FIX — THE COVER WAS BURYING THE PIN PROMPT. The cover was drawn
     at canvas level `overlay` (102). An hs.chooser panel draws at
     `popUpMenu` (101). So the prompt was open and focused underneath
     a panel you could not see past — which is why the only way
     through was the panic key, and why the PIN worked immediately
     after clearing the cover. The cover now draws at `floating` (3):
     still above every ordinary app window, comfortably below the
     prompt.
  🔧 FIX — YOU COULD "UNLOCK" AN APP THAT WAS ALREADY UNLOCKED.
     Two causes, both fixed. (1) Opening the manager or a PIN prompt
     takes focus, so macOS fires `deactivated` for the app you were
     in — and with re-lock-on-leave ON that silently re-locked the app
     you had just unlocked, the moment you opened the list showing it.
     Our own popups no longer count as "you switched away". (2) The
     lock/unlock rows are rendered when the manager opens and can go
     stale while it is on screen; both actions now check LIVE state
     when you press Enter, so unlocking something already unlocked
     says so instead of asking for a PIN nothing needed.
NEW IN 6.29.1 — APP LOCK: the cover was destroying itself:
  🩹 Cover mode was really hide mode with an extra step. Covering is
     immediately followed by hiding the app and focusing Finder — and
     hiding the frontmost app makes macOS fire `deactivated` for it.
     6.29.0's deactivate handler removed covers unconditionally, so
     the panel was torn down roughly a frame after being painted, by
     our own side effect.
     The cover is now kept while a challenge is in flight. A genuine
     switch away (no prompt open) still clears it, and the 3s watchdog
     is unchanged as the backstop. Verified by restoring the old
     unconditional removal and watching the suite fail.

NEW IN 6.29.0 — APP LOCK: COVER INSTEAD OF HIDE (kills the bounce):
  🖥 The bounce was never a placement bug and could not be patched.
     HIDING an app forces macOS to hand focus to something else, and
     on two monitors that drags your view across and straight back.
     Hiding IS the bounce. 6.27.1 and 6.28.2 both aimed at the wrong
     thing; only the prompt's position improved.
     Now: an opaque panel is painted over the locked app's screen,
     the app is hidden BEHIND that panel (so there is no flash), and
     focus is sent deliberately to Finder. macOS never gets to choose
     the destination, so there is nothing to bounce to.
     Only the screens the app actually occupies are covered — blacking
     out every monitor to conceal one window would be its own problem.
  🚪 FOUR WAYS OUT, because a panel that will not clear is worse than
     any bug in this file so far:
       1. Enter the PIN.
       2. ⌘⇧⌃⌥K (or ⇪K) — panic key. A GLOBAL hotkey on purpose, so
          it fires even if the hyper modal is wedged. The panel says
          so, on screen, in the text.
       3. A watchdog every 3s clears any cover with no prompt behind
          it.
       4. Quit Hammerspoon — the panel is drawn by Hammerspoon, so it
          cannot outlive it. That one is true by construction.
     Each of the first three was verified by deleting it and watching
     the suite fail.
  ⚙️ appLockUseCover = false returns to the old hide-only behaviour;
     appLockCoverThenHide / appLockFallbackApp control the hide and
     where focus lands. All at §6.6.

NEW IN 6.28.2 — APP LOCK: the monitor bounce, actually fixed:
  🖥 6.27.1 claimed to fix this and did not. It captured the locked
     app's screen inside appLockChallenge — but the watcher HIDES the
     app before calling that function, and a hidden app has no focused
     window. appLockRememberScreen returned nil every time, no screen
     override was ever set, and the PIN prompt kept following the
     focus bounce to the monitor you came from.
     The screen is now captured in the watcher BEFORE the hide and
     passed into the challenge.
  🧪 WHY THE TEST PASSED ANYWAY: the mock returned a window for an app
     even while that app was hidden, which cannot happen on a real
     Mac. It certified code that could not work. The mock now returns
     nil for a hidden app, and the old ordering fails the test with
     "prompt opened on the FALLBACK monitor" — the same thing the real
     Mac was doing.

NEW IN 6.28.1 — DOCUMENT WATCHER: say it in plain English:
  💬 The multi-copy rows read "Copy 2 tagged / Enter here copies every
     tagged row · Enter on a row tags/untags it". "Tagged" was a word
     invented in this file — it meant nothing to anyone who had not
     read the source, and the row never said WHY it existed. Rewritten:
       ☑️ Copy several at once...   (pick rows one at a time)
       📋 Copy the 2 documents I picked
       ✖️ Never mind — go back
     and every row now states what Enter does TO THAT ROW: "Enter
     copies this one", "Enter adds this to the copy list", "PICKED —
     Enter removes it from the copy list".
     A test asserts the invented vocabulary stays out and that every
     row explains its own Enter. Confusing wording in the only
     instruction a user ever sees is a defect, not a cosmetic detail.

NEW IN 6.28.0 — DOCUMENT WATCHER (EXPERIMENTAL SECTION):
  📄 ⇪W lists every document you have worked in, with how long you
     spent in each. Searchable by name, extension or date; the first
     row is a running tally of today's documents and total time.
     Enter copies the highlighted row. ⇪⇧E edits or deletes an entry
     (clear the filename and press OK to delete it).
     Stored as Logs/doc_wather.csv — Date, Time of day, File name,
     Working time.
  🧪 It lives inside the EXPERIMENTAL SECTION banner near the end of
     this file, entirely within one immediately-invoked function. It
     borrows only logsDir, showPopup, csvQuote and hyperAddShortcut.
     Delete the whole block and nothing else breaks.
  ⚠️ THREE DEVIATIONS FROM THE REQUEST, all hs.chooser limits:
     1. Shift-click multi-select does not exist — hs.chooser is a
        single-selection list with no modifier-aware click callback.
        Replaced with a select mode: Enter tags rows (✓) and a
        "Copy N tagged" row copies them together.
     2. Bare "W" cannot be a command inside the window; the keyboard
        belongs to the search field, so it would just type "w". Edit
        moved to ⇪⇧E, which works while the list is open.
     3. ⇪W was already the app-summon picker — that moved to ⇪⇧W.
  ✅ ACCURACY: a sample counts only if you are present (2 min without
     input stops the clock) and the gap since the last sample is
     sane. Sleep, stalls and idle gaps are DISCARDED rather than
     billed to whatever document happened to be open, and any CSV row
     that is not fully well formed is dropped at load with a count in
     the Console. Wrong data is worse than missing data here.

NEW IN 6.27.1 — APP LOCK: the PIN prompt stops bouncing monitors:
  🖥 ⌘-Tab to a locked app on a second monitor and you landed on the
     app, then got thrown back to the monitor you came from. Cause:
     hiding the app makes macOS fall back to whatever was frontmost
     BEFORE — usually on the other screen — and by the time the prompt
     opened, showPopup resolved "the frontmost app" to that fallback.
     The prompt followed the bounce.
     App Lock now captures the locked app's screen BEFORE hiding it
     (once hidden it has no window and no screen to ask about) and
     pins the prompt there via a new _G.popupScreenOverride, which
     resolveBaseScreen honours ahead of everything else. The override
     is cleared the moment the prompt is placed — leaving it set would
     strand every other picker in this config on that monitor.
     Tested by asserting the actual coordinates the prompt opens at,
     not merely that a flag was set.

NEW IN 6.27.0 — APP LOCK: only real apps, and a reachable exit:
  🧹 The picker listed every running PROCESS, so it filled with
     loginwindow, photolibraryd, universalaccessd, siriactionsd,
     nbagent, printtool and dozens more — none of them lockable, and
     they buried the few apps you actually care about. It now offers
     an app only if it has a Dock icon (kind() == 1, verified against
     Hammerspoon source) AND lives under /Applications,
     /System/Applications or ~/Applications. Helper apps nested inside
     another bundle are excluded too — they can report a Dock icon.
     Edit appLockAppRoots at §6.6 if you keep apps somewhere else.
  ⬆️ "⚙️ Stop protecting an app…" is now the FIRST row. It was at the
     bottom of a long list and effectively undiscoverable. Safe as the
     default row: it only opens the removal list, and removing
     anything still asks for the PIN.

NEW IN 6.26.0 — APP LOCK: the reason it kept "working once":
  🔁 A PIN unlocked an app PERMANENTLY, until you re-locked it by hand
     from ⇪⇧L. So the first switch prompted, and every switch after it
     correctly did nothing at all — which reads exactly like the
     feature degrading. It was doing what 6.22 was told to do ("no
     time limits"), taken literally.
     New option: RE-LOCK WHEN YOU SWITCH AWAY. Leaving a protected app
     locks it again, so coming back always asks for the PIN. It is not
     a timer — nothing expires while you are sitting in the app; it
     locks on an event, the way a screen lock does.
     OFF by default (nothing automatic unless you ask), and toggleable
     straight from ⇪⇧L — "🔁 Re-lock when I switch away: ON/OFF" — so
     you can try both without editing this file. The choice is saved in
     applock.json, and the boot report says which mode you are in.

NEW IN 6.25.1 — APP LOCK: kill the flash when you click the Dock icon:
  ⚡ ⌘-Tab was already clean; the Dock was not. Your own Console log
     showed why — every Dock click logged "still visible after hide",
     and 6.25.0 only LOOKED ONCE, 150ms after hiding. So the window
     really was on screen for that whole 150ms. That is the flash.
     It now polls every 30ms and re-hides the instant it sees the
     window, so the visible moment is ~30ms instead of ~150ms.
  🐛 A single look was also just wrong: macOS can finish its unhide
     AFTER that check, and 6.25.0 would sail straight past it, leaving
     the app sitting visible behind the prompt. The poll now waits for
     the app to STAY hidden across a few consecutive checks.
  ⛔️ Bounded: it gives up after ~0.6s and prompts anyway rather than
     spinning timers at an app that refuses to stay hidden, and it is
     still ONE poll per challenge — never 6.22's per-event storm.

NEW IN 6.25.0 — APP LOCK: ESC NO LONGER HANDS YOU THE APP:
  🚪 THE HOLE: the app could be sitting VISIBLE behind the PIN prompt,
     and pressing Esc simply closed the prompt and left you in it.
     Two causes, both fixed:
     1. A RACE WITH macOS. Clicking a hidden app's Dock icon makes
        macOS unhide AND activate it. Our hide() lands in the middle
        and macOS finishes unhiding afterwards — app back on screen,
        document readable, prompt floating on top. The challenge now
        confirms the app really went away (0.15s) and re-hides if it
        didn't, BEFORE the prompt appears.
     2. CANCEL DID NOTHING. Esc, a wrong PIN, or the prompt closing
        abnormally now all re-hide the app. Any outcome that is not a
        successful unlock leaves it off screen.
  ♻️ This restores what 6.22's retry was protecting, WITHOUT the
     strobe: 6.22 queued a timer on every activation event, so a
     ⌘-Tab burst queued dozens. This fires once per challenge, behind
     promptOpen, and re-checks before acting. A test asserts a
     25-event burst queues at most one.

NEW IN 6.24.1 — APP LOCK: FIX "works once, then it's unreliable":
  🕳 SECURITY HOLE introduced by 6.24.0's own fix. Its 2-second
     cooldown check sat ABOVE the hide, so during those 2 seconds the
     handler bailed out completely — and a locked app clicked in the
     Dock inside that window came back on screen WITH NO PIN. The
     cooldown now gates only the PROMPT. Hiding happens on every
     activation, always. (Hiding was never what looped: it moves focus
     to some OTHER app, which isn't locked, so nothing re-fires. The
     loop was the prompt reopening as focus returned.)
     Locking from ⇪⇧L no longer starts a cooldown at all — it opens no
     prompt, so there is nothing to damp, and the cooldown was just
     delaying the first real PIN challenge.
  🩹 A prompt that closed WITHOUT its completion callback running left
     promptOpen stuck true, and the watcher's early return on that
     meant App Lock quietly stopped working until a reload. A
     hideCallback safety net now recovers it and says so in the
     Console. Silent death was the likeliest cause of "works one time".
  🔍 DIAGNOSTICS: App Lock now logs what it decided on every event for
     a locked app — hidden, prompt shown, suppressed by cooldown,
     ignored. Every bug in this feature so far has been invisible in
     the Console, which is why they took so many rounds to pin down.
     Set appLockDebug = false at §6.6 once you're happy with it.

NEW IN 6.24.0 — APP LOCK: FIX THE STROBE AND THE 5-SECOND BEACHBALL:
  ⚡ Both symptoms were ONE bug: a focus feedback loop. Hiding an app
     changes focus, a focus change fires another `activated` event,
     and closing the PIN chooser hands focus straight back to the app
     that was just hidden. hide -> focus -> activated -> hide -> …
     Holding ⌘-Tab feeds that loop a stream of events, so the screen
     strobed between the app and Hammerspoon (genuinely unpleasant to
     look at), and the churn pinned the main thread long enough to
     beachball for about five seconds.
  🛑 Three changes, each verified to be load-bearing by removing it
     and watching the tests fail:
     1. The watcher now returns EARLY — before hiding anything — when
        a PIN prompt is already open. 6.23 hid first and checked
        after, so every event in a ⌘-Tab burst hid again.
     2. A 2-second per-app cooldown after we act. This is what
        absorbs the focus-return event when the chooser closes, and
        stops the prompt reopening on itself.
     3. The 0.15s "hide again in case it bounced back" retry added in
        6.22 is GONE. It guarded a race that was never confirmed and
        it was the engine driving the strobe.
     A test fires 25 activation events in a burst and asserts exactly
     ONE hide results, plus a separate one for the post-close case.

NEW IN 6.23.0 — APP LOCK: PIN PROMPT IS A REAL WINDOW, AND ENTER
FINALLY DOES THE OBVIOUS THING:
  🖥 The PIN prompt was an osascript `display dialog`. osascript is a
     command-line process, not an app, and that one fact caused four
     separate complaints: it could not take keyboard focus, ⌘-Tab
     could not reach it, window tools like Scoot could not see it, and
     it ignored which monitor you were working on. It is now an
     hs.chooser like every other picker here, so showPopup() puts it
     on your ACTIVE screen, already focused — just type the PIN.
     The digits are masked: the real text is held in a buffer and the
     field is rewritten to bullets on each keystroke, behind a
     re-entrancy guard so it cannot loop.
  🔁 FIX the lock / "it says unlocked" / lock rhythm. Every protected
     app had ONE row and Enter always meant "remove from the protected
     list". So after unlocking with your PIN, pressing Enter to lock it
     again quietly UN-PROTECTED it; you then re-added it (2nd press)
     and locked it (3rd). Enter now flips exactly what the row shows:
     🔒 LOCKED + Enter asks for the PIN and unlocks · 🔓 UNLOCKED +
     Enter locks it again immediately. Re-locking needs no PIN (it only
     adds protection); unlocking always does.
  🛡 Removing an app from App Lock now REQUIRES the PIN, and lives
     behind its own "⚙️ Stop protecting an app…" row. Previously
     anyone could open ⇪⇧L and un-protect an app with one keypress and
     no PIN, which made the whole lock decorative.

NEW IN 6.22.0 — APP LOCK: NO TIMER, AND LOCKING ACTUALLY LOCKS:
  🔒 FIX: locking an app that was ALREADY OPEN did nothing visible.
     The watcher only reacted to an app launching or being switched
     to, so locking the app sitting in front of you left it fully
     usable — you could keep typing in it. Locking now hides the app
     immediately, and "Re-lock everything now" hides every locked app
     that is running.
  ⏱ REMOVED: the 15-minute unlock timer. It was never asked for and
     made the feature feel arbitrary. An unlock now lasts until YOU
     lock the app again from ⇪⇧L. The only thing that re-locks on its
     own is restarting Hammerspoon (unlocks are in memory only —
     surviving a reboot would defeat the point). If you DO want the
     screen locking to re-lock everything, flip
     appLockRelockOnScreenLock at §6.6; it ships off.
  🐛 hide() failures used to be swallowed by a bare pcall, so a lock
     that silently did nothing looked identical to one that worked.
     They now print. Hiding also verifies 0.15s later and re-hides if
     the app bounced back, which single-shot hiding raced against.

NEW IN 6.21.1 — FIX: "Set a PIN" did nothing at all:
  🔑 The PIN dialog never appeared and the Console said nothing. The
     AppleScript was written across several lines for readability, but
     AppleScript has NO implicit line continuation (it needs a literal
     ¬), so osascript failed to COMPILE. It exited non-zero with empty
     output, which the callback read as "user typed no PIN", and the
     row looked dead. The `display dialog` statement is now built on a
     single line, and a non-zero exit is now reported in the Console
     with the offending script printed — it can't fail mute again.

NEW IN 6.21.0 — APP LOCK (§6.6, ⇪⇧L):
  🔒 A PIN gate on chosen apps. A locked app is hidden the moment it
     launches or comes to the front, and a masked PIN prompt appears;
     correct PIN un-hides it and keeps it open for 15 minutes. The
     unlock ends early when the screen locks or the Mac sleeps.
     ⇪⇧L manages everything: set/change the PIN, and toggle any
     running app in or out of the locked list.

     ⚠️⚠️ THIS IS A PRIVACY SCREEN, NOT SECURITY. It stops someone
     casually opening an app on your unlocked Mac. It does NOT stop
     anyone trying: quitting Hammerspoon removes every lock, a 4-digit
     PIN is brute-forceable in an instant by anyone who copies the
     hash file, and it cannot stop reading DATA (locking Finder does
     nothing about Terminal or `cat`). For OS-enforced app locking use
     Screen Time → Content & Privacy; for data at rest use FileVault.

     SAFE BY DEFAULT: nothing is locked until you add it yourself, and
     Hammerspoon can never be locked, so the Console is always
     reachable. Locked-but-no-PIN-set fails OPEN rather than trapping
     you. Escape hatch: delete ~/.hammerspoon/applock.json.
     The PIN hash lives in ~/.hammerspoon/applock.json — local to this
     Mac, never synced to OneDrive, and now excluded from the nightly
     backup alongside secret.lua.
     NO BEACHBALL: the prompt runs as a separate osascript process via
     hs.task. hs.dialog.textPrompt / hs.osascript block the main
     thread, which would freeze all of Hammerspoon behind a dialog you
     walked away from.

NEW IN 6.20.0 — COMMAND HISTORY PICKER (§6.5, ⇪H):
  ⌨️ Clipboard History, but for your terminal. ⇪H opens a searchable
     list of every command in command_history.log; type to filter,
     Enter copies the command to the clipboard. Newest first, and
     repeated commands collapse to a single row so a wall of identical
     lines doesn't bury everything else.
     ⚠️ THIS CONFIG DOES NOT WRITE THAT LOG — your shell does. So the
     parser accepts several formats rather than assuming one: plain
     lines, zsh EXTENDED_HISTORY (": <epoch>:0;cmd"), "[timestamp] cmd",
     "2026-07-29 03:48:12  cmd", ISO timestamps, and numbered bash
     history. A line it doesn't recognise is shown as-is rather than
     dropped. If your format is none of these, tell me and I'll add it.
     The file is re-read on every open, never cached, or commands run
     after Hammerspoon started would be invisible.
     Only the last 512 KB is read (~10,000 commands): the log grows
     forever, and reading it whole on the main thread is exactly how
     the §3.7 beachball happened.
     If no log is found, the Console lists every path it checked —
     set commandHistoryPath in §6.5 and reload.
  🔑 New: _G.hyperAddShortcut(mods, key, fn, name) — the supported way
     to add a NEW hyper shortcut. It runs through the same conflict
     sentry as everything else. (§0.4's map is only for OLD shortcuts
     that moved.)

NEW IN 6.19.0 — EVERY SHORTCUT NOW LIVES ON CAPS LOCK (⇪):
  ⇪ All 33 shortcuts moved off ⌃⌥⌘ / ⌃⌥ / ⌃⌥⇧ / ⌘⌥⇧ / ⌘⌃⌥⇧ and onto
     the hyper key. One modifier to hold instead of five combos to
     remember: ⇪A, ⇪T, ⇪V, ⇪F, ⇪/ …  The full map is in §0.4 and the
     cheat sheet (⇪/) has been rewritten to match.
     TWO TIERS, because a flat map was impossible — V, C and O each
     meant three different things and F/←/→ two apiece:
       ⇪ + key   → the 25 primary tools
       ⇪⇧ + key  → edit/delete variants + popup nudging (8)
     WINDOW KEYS ARE NOW SPATIAL: ⇪←/→ halves, ⇪↑ fill, ⇪↓ put back,
     ⇪\\ split, ⇪[ / ⇪] move a monitor. That freed F for ⇪F Files.
     🗑 REMOVED: the five app launchers (Ghostty/Chrome/Outlook/Teams/
     Sublime) that 6.17.0 added. They were never asked for, and they
     were sitting on T/C/O/S/M where the real tools belong.
     SAFETY: two boot-time self-checks, because a silently dead
     shortcut is the worst outcome here — one warns if two shortcuts
     land on the same hyper combo, the other warns if a §0.4 entry
     never matched (meaning that feature quietly kept its OLD key).
     The boot report's new "Hyper:" line shows both counts.
     Keys no shortcut claims still forward raw ⌘⇧⌃⌥ to the front app.

NEW IN 6.18.1 — FIX: endless Console errors on every Caps Lock press:
  🔇 6.18.0 forwarded F1–F12 as well. Each forwarded key is registered
     as a BARE hotkey, and macOS reserves some bare function keys
     system-wide (F11 = Show Desktop), so registering them failed with
     "RegisterEventHotKey failed: -9878 ... already registered".
     Entering the modal re-enables every binding, so that error was
     re-logged on EVERY Caps Lock press — forever. The hyper key still
     worked; the Console just filled up. Function keys are now OFF by
     default. Everything else (a–z, 0–9, arrows, punctuation, editing
     keys) is unchanged. Set hyperForwardFKeys = true at §3.12 to get
     them back and accept the noise.

NEW IN 6.18.0 — HYPER KEY IS NOW A REAL ⌘⇧⌃⌥ CHORD (§3.12):
  ⌨️ Caps Lock no longer fires only the five shortcuts below — it now
     emits the actual four-modifier chord. Caps Lock + K sends ⌘⇧⌃⌥K
     to the frontmost app, exactly as if you held all four modifiers.
     That means hyper works with ANY app you can teach a ⌘⇧⌃⌥ shortcut
     to (Raycast, Alfred, Rectangle, Slack, browser extensions, app
     prefs) — the app never needs to know Hammerspoon exists.
     Covered: a–z, 0–9, F1–F12, arrows, and the usual punctuation.
     (6.19.0 note: the app launchers this version shipped have been
     removed, and the config's own shortcuts now claim most keys —
     see the 6.19.0 entry above for the current layout.)

NEW IN 6.17.0 — HYPER KEY, NO KARABINER (§3.12):
  ⌨️ Caps Lock became a 5th modifier via hidutil (see 6.19.0 above for
     how it behaves now).
     HOW, WITHOUT AN EXTRA APP: macOS's own /usr/bin/hidutil remaps
     Caps Lock to F18 (a key in the spec that no Mac keyboard has, so
     nothing else ever sends it); Hammerspoon treats F18 as hyper.
     Nothing to install — the whole thing travels in this file, which
     is the point: same config on the work Macs, no admin install.
     Re-applied at every Hammerspoon launch, so it survives reboots
     WITHOUT the LaunchDaemon plist the usual guides require (that
     route needs admin; this one does not).
     ⚠️ HONEST LIMIT: macOS Sonoma+ restricts hidutil in some
     configurations. If it's blocked on a managed Mac the boot log
     says so plainly on the 🎹 line — it will not fail silently, and
     nothing else in this config is affected.
     ⚠️ Caps Lock no longer toggles capitals while this is on. To
     revert: set hyperEnabled = false and reload, or run
     hidutil property --set '{"UserKeyMapping":[]}'
NEW IN 6.16.23:
  🧹 File Tracker no longer logs macOS's own internal churn. It was
     filling with Photos Library guts rewriting themselves every
     hour (temp-CPAnalyticsPropertiesCache.plist, store.updates,
     live.0.indexUpdates…). Now excluded: everything INSIDE media/
     document library bundles (.photoslibrary, .musiclibrary,
     .fcpbundle, .logicx…), Spotlight index folders, .noindex
     folders, OS-internal file types (.plist, .db/.sqlite + their
     -wal/-shm siblings, .log, .lock), and sandbox atomic-save
     scratch names (foo.plist.sb-9e7584f9-3sh4il).
     The bundles THEMSELVES are still tracked — move or rename your
     Photos Library and it still logs; only its internals are quiet.
     ✏️ Edit fileTrackerNoiseBundles / fileTrackerNoiseExts in §3.8
     to tune. Verified against the exact paths from the real report.
NEW IN 6.16.22:
  🥶 FIX: the reload beachball is gone. Console timestamps pinned an
     11-SECOND main-thread freeze to App Monitor's baseline scan,
     which called hs.application.get(name) once per watched app —
     20 separate NAME RESOLUTIONS (the gap opened on hs.application's
     own "alternate names / Spotlight support" line). 6.16.8's 0.1s
     deferral had only moved it off the config-LOAD path, which is
     why "-- Done." printed instantly while the UI still locked up
     right afterward — hs.timer.doAfter runs on the MAIN thread.
     Replaced with ONE hs.application.runningApplications() call plus
     a pure-Lua name match: verified 1 bulk call and 0 name lookups,
     down from 20. Old per-name path kept as a fallback if the
     enumeration ever returns empty.
NEW IN 6.16.21:
  🔔 App Monitor's popup no longer auto-dismisses after 30s — if
     you're away when a watched app quits, it now stays on screen
     (gently pinging every 2s, same "Ping" sound) until you actually
     respond, however long that takes. Esc still dismisses it and
     posts a notification either way.
NEW IN 6.16.20:
  🚨 FIX (the REAL remaining cause, found via Console instrumentation):
     6.16.18 fixed a genuine GC bug but App Monitor still never fired.
     Live Console evidence (Ghostty AND Microsoft Teams, reproduced
     twice) showed hs.application.get(name) still reporting the app
     as RUNNING even 0.3s after its own "terminated" event — re-scan-
     via-get() is unreliably stale on this Mac. The watcher itself
     handed us the correct appName directly every time in that same
     log, so the fix trusts THAT instead: no re-scan, no re-query,
     no dependency on get() ever catching up. Falls back to the old
     re-scan only if appName is ever nil (rare safety net).
NEW IN 6.16.18:
  🚨 FIX (real bug, confirmed reproducible): App Monitor never fired
     for ANY app — Teams, Ghostty, Sublime all confirmed dead — on
     both Macs. Root cause: 6.16.8's deferred boot setup used
     hs.timer.doAfter() WITHOUT storing its return value. That's a
     real, documented Hammerspoon gotcha (confirmed against
     Hammerspoon's own GitHub issues + wiki) — an unreferenced timer
     object can be silently garbage-collected before its delay
     elapses, canceling it with no error. Fixed by holding every
     such timer in a _G. variable (arrays for ones that can have
     several in flight at once, self-removing once each fires).
     Audited the WHOLE file for this same unstored-doAfter pattern
     and fixed all of them, not just App Monitor's: File Tracker's
     rename-pairing timer, Autocorrect's injection timer, and the
     three boot-time alert timers were all equally at risk.
NEW IN 6.16.17:
  🗑 Removed the §3.12 Change History picker (⌃⌥⌘H) and its
     init_changes.csv backing file, along with the 6.16.15/6.16.16
     entries proposing/backfilling it — decided it wasn't needed.
     Changelog entries resume living here as normal, same as always.
     (If <OneDrive>/Logs/init_changes.csv already got created on a
     reload, it's harmless to leave or delete by hand — nothing
     reads it anymore.)
NEW IN 6.16.14:
  🔧 FIX: typing an assignee that matched nobody showed nothing at
     all in the new inline suggestions — indistinguishable from the
     feature being broken. Now shows a clear "No team member
     matches" row (safe no-op, can't be submitted).
  🚨 FIX (the actual reported bug): a short digit string like "1"
     typed as the assignee was blindly treated as "already a valid
     GID" and sent straight to Asana, which rejected it with a raw
     API error. Real Asana GIDs are long (15+ digits); now requires
     6+ digits before trusting it as one — anything shorter falls
     through to the roster lookup and gets the same clear "no
     match" abort-and-alert as an unresolvable name.
NEW IN 6.16.13:
  👤 The Task Creator (⌃⌥⌘T) now suggests matching Asana team members
     INLINE while you're typing the Assignee field — no more leaving
     to ⌃⌥⌘B, copying a name, and coming back. Picking a suggestion
     splices the exact name into the draft and reopens; it does not
     submit the task. Suggestions only show while still in that
     field — once you're typing the attachment path, they stop.
NEW IN 6.16.12:
  ⌨️ Standardized every Asana hotkey onto the same ⌃⌥⌘ chord:
     ⌃⌥⌘A Format URL · ⌃⌥⌘B Browse Teams (was ⌃⇧⌥M) · ⌃⌥⌘C Comment
     (was ⌃⇧⌥C) · ⌃⌥⌘T Create task · ⌃⌥⌘L List tasks/Dashboard (was
     ⌃⇧⌥A). Verified zero conflicts via the file's own §0.3 Hotkey
     Conflict Sentry (still 33 bound, 0 internal conflicts) before
     shipping — not just a manual check. Cheat sheet (⌃⌥⌘/) merged
     the old separate TASKS/DASHBOARD groups into one, matching.
NEW IN 6.16.11:
  🏷️ The ⌃⇧⌥M team picker now shows which team each person is on
     (subText, e.g. "lee@x.com · SAC Library Core Projects") — cleaned
     of the "| N. ... |" formatting. Someone on both your teams shows
     once with both names, not as a duplicate row. Search now matches
     team name too (searchSubText), so typing "core" narrows to just
     that team. Doesn't touch hs.chooser's own native ⌘+number row
     shortcuts — those aren't ours to begin with.
NEW IN 6.16.10:
  🔤 FIX: 6.16.9's team names didn't match — the real Asana team names
     include the "| N. ... |" formatting (e.g. "| 1. SAC Library Core
     Projects |"), which the boot log confirmed as two straight
     "team not found" warnings. asanaTeamNames now has the exact
     literal names.
NEW IN 6.16.9:
  👥 FIX: the Asana team-member picker (⌃⇧⌥M) searched your ENTIRE
     organization (thousands of accounts on a big org) instead of
     just your team. Now scoped to specific team(s) by name — ✏️ EDIT
     asanaTeamNames near §0.2 to change which team(s) — resolved to
     their real GIDs once at boot (GET /workspaces/{gid}/teams) and
     merged from each team's own roster (GET /teams/{gid}/users).
     Falls back to the old whole-workspace roster if the list is
     empty or a name doesn't match.
NEW IN 6.16.8:
  🥶 FIX: reload beachballed every time. Timed boot checkpoints (6.16.7,
     now removed) proved it was Hammerspoon's OWN hs.application module
     taking 5-12s on its FIRST touch on this Mac, inside App Monitor's
     boot-time baseline scan — not our loop logic (everything after it,
     incl. the whole File Tracker FSEvents setup, ran in under a
     second). Ruled out Microsoft Defender file-scanning and a
     Gatekeeper network check as the cause (delay persisted with
     Defender-excluded and with Airplane Mode on) — the cost is
     apparently inherent on this machine and outside what our code
     controls. Fix: deferred App Monitor's baseline scan + watcher
     setup by 0.1s via hs.timer.doAfter, off the synchronous boot
     path — the other 32 hotkeys are live and the reload itself
     completes instantly; App Monitor's own protection comes online a
     few seconds later in the background instead of freezing the
     whole reload.
NEW IN 6.16.6:
  🚨 FIX: 6.16.4 called hideOnLostFocus() on the report chooser — NOT
     a real hs.chooser method, so it crashed the entire config on
     load. Reverted. Escape-to-close still works (it always did,
     natively) — there's no supported way to also block click-away
     dismissal.
NEW IN 6.16.5:
  🕒 FIX: Activity Tracker counted "app left frontmost" as usage, not
     actual use — leaving VLC playing or Sublime open while away from
     the keyboard for hours inflated its total. Now stops the clock
     after 5 min of no mouse/keyboard input (hs.host.idleTime), and
     credits time only up to when idling actually began.
NEW IN 6.16.4:
  📊 Activity Tracker reports now stay on screen until you press Esc —
     clicking away no longer auto-dismisses them (hideOnLostFocus off).
  🗓 Added a second weekly-recap firing: Friday 7:30 AM, alongside the
     existing Monday 7:30 AM one.
NEW IN 6.16.1:
  🔧 FIX: App Monitor's Spawn button didn't relaunch Alfred/Bartender
     — launchOrFocus(name) needs an exact bundle name, and those ship
     versioned on disk ("Alfred 5.app"), same mismatch already fixed
     in the App Update Tracker. Spawn now resolves the real bundle
     path first (shared findAppBundle) and launches via `open -a`.
NEW IN 6.16.0 — GLOBAL COPY-ON-SELECT (§3.11, ⌘⌃⌥⇧C, off by default):
  🖱️ Highlighting text anywhere — any app, any web page — copies it
     immediately, like Ghostty's terminal selection already does.
     Built on an hs.axuielement Accessibility observer watching the
     frontmost app; re-attaches on every app switch. Auto-copies
     flow through Clipboard History (⌃⌥⌘V) exactly like a manual ⌘C.
     HONEST LIMIT: only works where an app exposes standard
     Accessibility text selection — most native apps and browser
     page content do; some Electron/custom-drawn UIs don't. Password
     fields are protected by macOS and never exposed, by design.
NEW IN 6.15.4:
  📌 Boot now prints "init.lua ARCHITECTURE VERSION: X.Y.Z" as the
     very first Console line — any pasted Console log now proves
     which file is actually loaded, instead of guessing whether a
     bug report is against the latest fix or a stale copy.
NEW IN 6.15.3:
  🔧 FIX: clipboard edit/delete (⌘⌃⌥⇧V) always said "That entry is
     gone" — it matched a choice back to _G.clipboardCache by TABLE
     IDENTITY, but hs.chooser round-trips every choice through its
     Objective-C bridge, handing the completion callback a freshly
     rebuilt table, never the original object. Identity can't
     survive that. Switched to the same snapshot+index pattern the
     OCR edit picker already used successfully (a plain number
     survives the bridge by value, which is exactly why OCR worked
     and this didn't).
NEW IN 6.15.2:
  🔧 FIX: a clipboard history that failed to parse at boot ("Error
     deserialising JSON") used to fall back to an empty cache with
     no warning — and the NEXT save (any edit or copy) then wrote
     that emptiness over the broken file, permanently losing
     whatever was still in it. That's the "one edit wiped everything"
     report. Now: a bad file is backed up (clipboard_history-
     *.json.corrupt-<timestamp>) with an on-screen warning instead
     of silently starting empty, AND every save round-trips through
     decode first — if hs.json.encode ever produces something that
     doesn't parse back, the write is ABORTED (existing file left
     alone) rather than committed.
NEW IN 6.15.1:
  🔧 FIX: the team roster fetch 404'd — /projects/{gid}/users isn't
     a real Asana endpoint (not a private-project permission issue;
     that would be a 403, and this token already reads/writes this
     exact project fine elsewhere). Switched to workspace-level user
     listing, which is both correct AND a better fit: it's every
     person in the team's Asana workspace, not just whoever's
     already a member of this one project.
NEW IN 6.15.0:
  🔧 FIX: assigning a task to "Me" or a name ("Lee") failed with
     Asana's own error — "Not a valid actor ID" — because a display
     name was sent straight to the API, which only accepts "me", a
     numeric GID, or an email. resolveAssignee (§5) now resolves a
     typed name against a cached roster of the project's team before
     ever calling the API; an unresolvable name now shows a clear
     alert and ABORTS instead of guaranteeing an API error.
  👥 ⌃⇧⌥M browses that same roster — Enter copies a member's exact
     name so pasting it into the Assignee field always resolves.
NEW IN 6.14.0 — EDIT / DELETE CLIPBOARD & OCR HISTORY ENTRIES:
  ✏️ Both histories were browse-and-copy only until now. ⌘⌃⌥⇧V opens
     the clipboard history to EDIT or DELETE an entry (searchable,
     same as ⌃⌥⌘V); ⌘⌃⌥⇧O does the same for OCR history. Selecting a
     row opens a pre-filled dialog — change the text and Save to fix
     a bad OCR read or a copy you want cleaned up, or clear the text
     entirely and Save to DELETE that entry (stated plainly in the
     dialog, no separate delete hotkey needed).
     Clipboard edits match by the entry's actual identity, not a
     list position, so a new copy landing while the picker is open
     can't make an edit land on the wrong row. OCR edits work off a
     snapshot taken the moment the picker opens, same reasoning.
NEW IN 6.13.0 — APP UPDATE TRACKER ACTUALLY INSTALLS (§3.10.1):
  🍺 HOMEBREW ONE-KEY INSTALL: a row that's both "update-available"
     AND actually tracked by Homebrew as installed (checked via
     `brew list --cask --versions` — NOT the same as merely having a
     valid cask token, since most of these 18 apps were almost
     certainly installed by direct download, not brew) now installs
     the update on Enter: `brew upgrade --cask <token>`, then
     re-checks automatically so the row reflects what really
     happened. A new "⬆️ Upgrade ALL N brew-managed app(s) now" row
     appears at the top whenever more than one qualifies, batching
     them into a single brew invocation.
     HONEST LIMIT: this is deliberately conservative — an app brew
     never installed is left alone rather than force-reinstalling
     over it (which risks a conflict prompt or clobbering settings
     outside brew's view). Needs an admin-capable account; a
     locked-down managed Mac may block it entirely.
  🌐 DOWNLOAD-PAGE FALLBACK: every app now carries its vendor's
     official download/update page. Any "update-available" row that
     ISN'T brew-managed, and Microsoft Defender's permanent "no-cask"
     row, open that page on Enter instead of just copying — covering
     exactly the apps Homebrew can't touch.
NEW IN 6.12.2:
  🔧 FIX: Alfred and Bartender showed "Not installed here" despite
     being installed — both ship a VERSIONED .app bundle name on disk
     (Alfred 5.app, Bartender 5.app), not the fixed "Alfred.app" /
     "Bartender.app" this tracker assumed. findAppBundle now falls
     back to a prefix scan of /Applications when the exact name
     isn't found, the same fix Sublime already needed a one-off
     appBundle override for — this generalizes it for any app.
  🔄 FIX: the picker only auto-refreshed on the very first-ever
     check (or the 9am timer), so a corrected cask token or bundle
     path kept showing STALE cached results from before the fix
     until the next scheduled run — which is exactly what made the
     Defender fix above look like it hadn't taken effect. ⌃⌥⇧U now
     always kicks a fresh check in the background on open, the same
     pattern the Asana Dashboard already uses — cheap for something
     you trigger deliberately, not a background poll.
NEW IN 6.12.1:
  🔧 FIX: Microsoft Defender's guessed cask token ('microsoft-defender')
     doesn't exist in Homebrew — confirmed by the Console error the
     6.12.0 self-diagnosis was designed to surface: "No Cask with
     this name exists." Turns out there's no cask for Defender at
     all — it's an enterprise product distributed via Microsoft's
     installer / MDM (Intune, Jamf), not Homebrew. Rather than guess
     another token, updateTrackerApps entries can now have cask = nil
     for exactly this case: the tracker still reads the installed
     version and shows "🔍 No Homebrew cask — check manually" instead
     of hammering brew with a lookup that can only ever fail.
NEW IN 6.12.0 — APP UPDATE TRACKER (§3.10, ⌃⌥⇧U):
  📦 Answers "which of my apps are behind right now?" so updates can
     be batched into one IT ticket instead of installed piecemeal.
     For each app in updateTrackerApps, compares the version actually
     installed (read from its own Info.plist) against the latest
     version Homebrew's Cask database knows about — which tracks
     upstream releases whether or not the app was installed via
     Homebrew. Results are cached to app_updates-<Mac>.csv, refresh
     automatically once a day, and ⌃⌥⇧U opens a searchable picker
     sorted with "update available" first.
     HONEST LIMIT: no vendor here publishes a public release
     schedule (Chrome is the closest exception — a new stable
     roughly every 4 weeks), so this reports the PRESENT, not a
     forecast. Requires Homebrew on this Mac (read-only — nothing is
     installed or changed); missing → the feature reports itself off
     in the boot log. A wrong/renamed cask token is never silent:
     brew's own error is caught and named per-app in the Console.
NEW IN 6.11.3 — ACTIVITY TRACKER: REAL APPS ONLY, NO SLEEP INFLATION:
  👁 Only regular Dock apps (hs.application kind 1) are tracked now —
     loginwindow (the lock-screen process) and ScreenSaverEngine were
     being logged as "apps" because they're whatever's frontmost while
     the screen is locked. Filtering by kind is self-updating: install
     a real app tomorrow, it's tracked automatically, nothing to
     maintain. An activityIgnoredApps table lets you exclude a real
     app by name if you ever want to.
  🛌 FIX — THE 30-HOUR GHOST: a session left open across sleep/lock
     kept its original start time, and Hammerspoon's timers pause
     during sleep while the wall clock doesn't — so waking up Monday
     after locking Friday credited whatever was frontmost at lock
     time with the ENTIRE elapsed span. A new lock/sleep watcher now
     closes the open session the instant the screen locks or the
     system sleeps, so its duration stops at the real moment of lock.
     This was also quietly padding real apps' totals any time the Mac
     slept while one was frontmost — those historical numbers were
     somewhat inflated and won't be going forward.
  🧹 One-time boot cleanup purges any loginwindow / ScreenSaverEngine
     rows already sitting in your activity_history CSV from before
     this fix — harmless no-op once the CSV is already clean.
NEW IN 6.11.2 — DIAGNOSING "FILE URL(S) BUT NO IMAGE FILES MATCHED":
  🔍 That Console line said something didn't qualify but never said
     WHAT. Now it does: the first rejected candidate per copy is
     captured and printed underneath it — either its extension
     isn't in the supported list, or it is but the path didn't
     resolve to a readable local file. Non-printable bytes in the
     preview render as "?", which immediately shows if what Finder
     handed over wasn't a plain file:// string at all.
NEW IN 6.11.1:
  🔧 FIX: copying image files in Finder did nothing — the
     pasteboard file-URL reader (hs.pasteboard.readURL) returns
     nothing on some Hammerspoon versions, and every failure was
     swallowed silently. Detection rebuilt on readAllData (the raw
     pasteboard items, where Finder reliably puts a public.file-url
     per copied file), with the old readers kept as fallbacks.
     And it now NARRATES: the Console says how many image files
     were detected on every copy, says when a file URL was seen
     but unusable, and says when the OCR shortcut is missing —
     the next miss diagnoses itself instead of being silent.
NEW IN 6.11.0 — OCR TAGS THE FILE ITSELF:
  🏷 Copy image FILES in Finder (select → ⌘C, up to 15 at once) and
     each is OCR'd via your "HS OCR" shortcut; the extracted text
     is written into the file's FINDER COMMENT (Get Info →
     Comments, capped at 500 chars) — which Spotlight and Finder
     search index. A folder of screenshots with meaningless names
     becomes searchable by what's WRITTEN IN the images. The text
     also lands in the ⌃⌥⌘O OCR history as usual.
     • Files with an EXISTING comment are never clobbered — the
       OCR still goes to history; a console line notes the skip.
     • First run macOS asks "Hammerspoon wants to control Finder"
       — click OK, or comments can't be written (Automation
       permission, System Settings → Privacy & Security).
     HONEST LIMITS: raw clipboard images (screenshots, browser
     copies) have NO file behind them — they keep going to history
     only. And Finder comments are LOCAL metadata: OneDrive does
     not sync them, so a tag written on one Mac won't appear on
     the other. (Recent macOS also finds image text natively in
     Spotlight — this makes it explicit, visible, and yours.)
NEW IN 6.10.3:
  🫥 TRANSLUCENT PANELS: the cheat sheet, the dashboard's color
     legend strip, and the Task Creator's draft mirror are now 80%
     opaque (were 92–97%), so what's behind them stays visible.
     One setting controls all three: panelAlpha in §1.5 — raise it
     toward 1.0 for more solid, lower for more see-through (text
     readability suffers below ~0.65 over bright backgrounds).
     HONEST LIMIT: the PICKER LISTS (clipboard, Task Creator,
     dashboard…) are native macOS hs.chooser panels — Hammerspoon
     exposes NO opacity control for them, and they already have
     macOS's built-in slight blur. To watch something behind a
     picker: nudge it aside with ⌃⌥⌘-arrows (the offset sticks
     until ⌃⌥⌘R), or hide the front app with ⌃⌥⌘P App Peek.
NEW IN 6.10.2:
  📖 TASK CREATOR — SEE EVERYTHING YOU TYPE (⌃⌥⌘T): the popup is
     wider (60% of the screen, was 40%), and a LIVE DRAFT MIRROR
     panel appears just above the box the moment you type — your
     entire text, word-wrapped across up to 8 lines, updating on
     every keystroke. Long titles no longer vanish past the edge
     of the field. Rides along with ⌃⌥⌘-arrow nudges; disappears
     when the popup resolves.
     HONEST LIMIT: the input field itself is a native macOS
     single-line control — Hammerspoon can't make IT wrap, which
     is why the mirror exists. The field still holds the real
     text; the mirror is where you read it.
NEW IN 6.10.1:
  📝 TASK CREATOR DRAFT PERSISTENCE (⌃⌥⌘T): whatever you've typed
     in the box now survives the popup closing — click away, press
     Esc, or accidentally Enter on a history row, and the next
     ⌃⌥⌘T restores your exact text (a "Draft restored" alert says
     so). Every keystroke updates the draft, so nothing is ever
     more than one reopen away. The draft clears ONLY when a task
     is actually created (or if you delete the text yourself).
     In-memory, like window prior-positions — a Hammerspoon reload
     starts fresh.
NEW IN 6.10.0 — ONE DATA HOME (everything syncs, work-Mac ready):
  ☁️ ALL log, note & history files now live in your OneDrive Logs
     folder (~/Library/CloudStorage/OneDrive-Personal/Logs) —
     nothing data-like is stranded in ~/.hammerspoon anymore:
       PER-MACHINE (tagged with the Mac's name, so the two Macs
       never fight over a file):
         clipboard_history-<Mac>.json · asana_history-<Mac>.json ·
         file_changes-<Mac>.csv — joining activity_history-<Mac>.csv
         and image_text-<Mac>.csv, which already lived there.
       SHARED between both Macs (learned once, works everywhere):
         autocorrect.csv (your 10,970-fix dictionary + every
         exception ⌃⌥⌘Z ever learns) · custom_shortcuts.json
         (your ⭐ cheat-sheet entries).
     Existing files are ADOPTED automatically on first boot after
     this upgrade — contents copied to the new location, originals
     left untouched in ~/.hammerspoon. Nothing already recorded is
     lost.
  🗑 File Tracker's separate daily 5 PM OneDrive copy removed —
     the live CSV itself is in OneDrive now, so the copy timer
     had nothing left to do.
  🔐 secret.lua is now EXCLUDED from the nightly rsync backup —
     your Asana token never leaves this Mac, not even into your
     own OneDrive. (Each Mac keeps its own local secret.lua.)
  ⚠️ Writes to the Logs folder that fail (OneDrive quit, or the
     folder set to online-only) now warn ON SCREEN once per file
     instead of silently losing data. Keep the Logs folder set to
     "Always keep on this device" in OneDrive.
  💻 WORK MAC: no edits needed. The portability layer already
     prefers OneDrive-Personal even when a company OneDrive is
     also signed in — so both Macs read and write the same Logs
     folder. Install = copy this file + create secret.lua there.
NEW IN 6.9.2:
  ⌨️ The five core picker hotkeys (§5: format-URL A, clipboard V,
     task creator T, activity tracker 0, OCR O) moved into an
     editable coreKeys table — they were the last hardcoded keys
     in the file. Re-keying any of them is now a one-line edit,
     checked by the Hotkey Sentry at boot. No behavior change.
NEW IN 6.9.1:
  📋 Clipboard history upgraded: 100 → 1,000 items, and search now
     matches the FULL text of every item (was only the first 100
     characters a row displays — a match deep in a long copy was
     invisible). Re-copying something moves it to the front instead
     of using a second slot; items over ~1 MB are left out of
     history so the JSON file stays fast (console line notes it).
     Render armored like every other picker. Dates now include the
     day (Jul 13 09:41), since 1,000 items span weeks.
NEW IN 6.9.0:
  📖 247 classic human typos merged into autocorrect.csv (now
     10,970 fixes): teh→the, mna→man, alot→"a lot" (multi-word
     corrections work), dont→don't (apostrophes in corrections
     work), thier, recieve, seperate, libary… — the TextExpander
     export was machine-generated transpositions and had NONE of
     them. Real-word traps (wont, cant, its, wether, lets…)
     screened out by hand, then ALL 10,970 keys machine-audited:
     zero collide with another entry's correction or with the
     ~1,200 highest-frequency English words.
  🔑 HOTKEY CONFLICT SENTRY (§0.3): every hs.hotkey.bind passes
     through a registry wrapper. Binding the same combo twice
     inside this config prints a Console warning naming it (the
     later bind silently kills the earlier feature — now it
     announces itself). Combos matching known macOS defaults
     (Spotlight, Spaces, screenshots…) are also flagged. Boot
     report shows "Hotkeys: N bound, no internal conflicts".
     Honest limit: other APPS' shortcuts have no public API and
     can't be detected — the report says so.
NEW IN 6.8.1:
  📚 TWo-caps exceptions properly researched: ~80 defaults (the
     real taxonomy — two-letter initialisms with s/ed/ing suffixes
     like DMs/TAs/IDed/DJing, plus units like MHz/GPa/MWh/MBps).
     "ITs" deliberately excluded: it's a typo of "Its" far more
     often than a plural of IT.
  ↩️ ⌃⌥⌘Z — undo & learn: a wrong TWo-caps fix is rewound (if you
     haven't typed since) AND appended as a permanent "allow" row
     in autocorrect.csv — the exception list grows itself, since
     no list of acronyms is ever complete. Wrong dictionary fixes
     rewind once; the alert names the exact CSV row to delete if
     you want that permanent (dict entries are deliberate, so
     they're never silently removed).
NEW IN 6.8.0:
  ✏️ AUTOCORRECT (§3.9, ⌃⌥⌘S toggles): fixes the word you just
     finished typing, system-wide. Dictionary corrections (mna→man,
     case-preserving: Mna→Man, MNA→MAN) live EXTERNALLY in
     autocorrect.csv (~10,700 entries would bloat this file) —
     plain text, no permissions, auto-seeded with a starter list
     if missing. TWo-caps typos (MAn→Man, THe→The) are ONE RULE,
     not data: verified to reproduce all 3,597 ⇪ rows of the
     source list, and covers words not in it; real two-caps words
     (IDs, TVs, MHz…) are "allow" rows in the CSV.
     Needs Accessibility (politely off without it — boot report
     says so); passwords are protected by macOS secure input;
     pasted/existing text never touched. Excluded-apps list +
     30s watchdog (macOS silently disables slow event taps).
NEW IN 6.7.4:
  🔧 FIX: legend was invisible over native FULL-SCREEN apps (their
     own private Space) — a canvas belongs to one Space unless it
     declares canJoinAllSpaces + fullScreenAuxiliary, which the
     picker's panel does internally and ours didn't. Both the
     legend AND the cheat sheet (same latent bug) now declare them,
     so both appear everywhere, full screen included. A console
     line now logs the legend's monitor + frame on every show, so
     any future placement issue diagnoses itself.
NEW IN 6.7.3:
  🔧 FIX: legend appeared on one monitor but not the other — the
     picker and the legend each resolved "which screen?" separately,
     a moment apart, and focus shifting as the popup opens could
     make them disagree. showPopup now RECORDS the exact placement
     it used and the legend reuses it verbatim: same monitor, same
     coordinates, always.
  🔍 Legend text enlarged to 16px; pills scaled to match, and the
     strip is clamped fully on-screen at both edges (matters on
     wide-count days and on monitors left of the main display).
NEW IN 6.7.2:
  🔧 FIX: legend strip overlaid the bottom of the task list — its
     below-the-picker position relied on estimating the picker's
     height, and the estimate ran short. Now sits just ABOVE the
     search field, where placement is exact (we set the picker's
     top-left ourselves) — overlap is impossible by construction.
     Clamped so nudging the picker to the screen top can't push the
     strip off-screen.
NEW IN 6.7.1:
  🎨 Color legend strip under the dashboard picker: one pill per
     category (red Overdue, yellow Due today, blue Due this week,
     orange Due later, purple No due date) with the number of rows
     each contributed. Empty categories show no pill. Appears when
     the dashboard opens, follows ⌃⌥⌘-arrow nudges, and disappears
     when the picker resolves (pick, Esc, or click away). Built on
     hs.canvas since hs.chooser has no footer of its own — its
     position is estimated from row count, so it may sit a few px
     off if a macOS update changes row heights (cosmetic only).
NEW IN 6.7.0:
  📅 Dashboard rebuilt (drop-in Section 6 replacement): up to 100
     tasks across five capped categories, in this order —
     🔴 Overdue (max 40, newest due first), 🟡 Due today (max 10),
     🔵 Due this week (max 30, soonest first), 🟠 Due later
     (max 10, soonest first), 🟣 No due date (max 10, newest
     created first, listed last). Category names capitalize the
     first word only. Caps live in the asanaCaps config table.
     Both ⌃⇧⌥A (open) and ⌃⇧⌥C (comment) modes unchanged.
NEW IN 6.6.0:
  📅 Dashboard (⌃⇧⌥A / ⌃⇧⌥C) now shows EVERY incomplete task, not
     just dated-within-a-week ones: new ⚪️ NO DUE DATE bucket
     (newest created first — where fresh tasks live, fixing "recent
     tasks don't show") and 🟣 LATER bucket (due beyond this week,
     soonest first). Order: overdue → today → this week → no due
     date → later. Fetch limit set to 100 tasks explicitly.
NEW IN 6.5.2:
  🔧 FIX: Task Creator went BLANK when the attachment field held a
     folder path (trailing slash) — basename extraction returned nil
     and crashed the render callback, which leaves a chooser empty.
     Fixed, and ALL THREE searchable popups (tasks, activity, file
     tracker) are now armored: a render error shows an error row
     pointing at the Console instead of a silent blank window.
NEW IN 6.5.1:
  🔒 Asana token hardening: whitespace around the token in
     secret.lua is trimmed (a trailing space is invisible but causes
     a 401 identical to a revoked token), the token's shape is
     sanity-checked at boot (catches smart quotes / truncated
     pastes), and a 401 now says "revoked or mistyped — make a new
     token" instead of a bare status code.
NEW IN 6.5.0:
  🗑 All-display brightness REMOVED (§1.10, its event tap and its
     30s watchdog): unused, and only ever helped Apple/LG external
     displays. F1/F2 are now purely stock macOS. Nothing else
     touched — one less always-running listener.
NEW IN 6.4.1:
  🔧 FIX: 6.4.0 consumed F1/F2 and re-applied brightness itself —
     on Macs where setBrightness silently no-ops, that killed the
     keys entirely. Redesigned to NEVER consume: macOS handles the
     built-in display natively (keys can't break, by construction)
     and we mirror the resulting level to other supported displays
     a beat later. Headless Macs get manual stepping. Key-hold
     events coalesce into one trailing sync.
NEW IN 6.4.0:
  🔆 All-display brightness (§1.10): F1/F2 now adjust EVERY display
     macOS can control, in sync (native rebuild of the AllBrightness
     Spoon, ~50 lines). Self-healing: any failure passes the key
     back to macOS (stock behavior, never broken keys) and a 30s
     watchdog revives the listener if macOS disables it. Externals
     respond only if Apple/LG UltraFine (macOS limit — DDC monitors
     need MonitorControl/Lunar).
NEW IN 6.3.1:
  📁 ~/.hammerspoon is now TRACKED by the File Tracker despite being
     a hidden folder — init.lua swaps, secret.lua changes, and JSON
     creations all get a paper trail. Still excluded within it: the
     tracker's own CSV, hidden items, and the logs/ fallback folder.
     JSON rewrites stay silent (Modified events aren't logged).
NEW IN 6.3.0:
  📁 File Tracker now watches the ENTIRE home folder + OneDrive:
     ~/Library excluded (except OneDrive, which gets its own
     watcher), hidden folders/files excluded, own telemetry (Logs
     CSVs, Backups/Hammerspoon) excluded so it never logs itself,
     and a burst guard suppresses Created-row floods (unzips, mass
     exports) — renames/moves are never suppressed. Note: OneDrive
     sync means the other Mac's OneDrive file changes appear here
     too. Exclusion logic verified against 10 boundary cases.
NEW IN 6.2.0:
  📁 File Tracker (§3.8, ⌃⌥⇧F): logs renames, moves, renamed+moved,
     copies & created files in Desktop/Documents/Downloads (editable
     list) with old→new names & folders. Searchable picker; Enter
     copies a row. 90-day history in local Excel-ready
     ~/.hammerspoon/file_changes.csv, copied daily at 5:00 PM to
     OneDrive Logs (machine-tagged). Temp/hidden files ignored.
     Note: macOS reports a copy's destination only — sources of
     copies are unknowable via FSEvents.
NEW IN 6.1.1:
  🔍 secret.lua diagnostics: the boot report now distinguishes
     "missing" from "broken" (with the exact Lua error), and a
     broken file raises an on-screen alert instead of silently
     looking like a missing one.
NEW IN 6.1.0 — TWO MACS, ONE ONEDRIVE, NO COLLISIONS:
  🏷 Per-machine identity (hostTag from the Mac's name): activity &
     OCR CSVs are tagged per machine and backups go to
     Backups/Hammerspoon/<MachineName>/ — two Macs syncing the same
     Personal OneDrive can no longer create conflict copies or
     overwrite each other's backups. Existing untagged files are
     adopted automatically (originals left untouched).
  ♿️ Accessibility status in the boot PORTABILITY REPORT, with a
     pointer alert when not granted (window features inactive until
     then; everything else unaffected).
NEW IN 6.0.0 — PORTABLE ARCHITECTURE (work + personal Mac, one file):
  🧭 §0.1 Portability layer: OneDrive auto-detected per machine
     (OneDrive-Personal preferred, any OneDrive-* accepted, local
     ~/.hammerspoon/logs fallback). Override variables provided.
     Daily backup auto-disables where there's no cloud destination.
  🔐 §0.2 Credentials moved OUT of this file into per-machine
     ~/.hammerspoon/secret.lua — init.lua is now secret-free and
     freely copyable. No secret.lua → Asana features politely off.
  📴 Graceful degradation: Asana hotkeys gated; image OCR checks at
     boot whether this Mac's Shortcuts app has the OCR shortcut.
  🧾 Boot PORTABILITY REPORT in the Console + status in the ready
     alert. Manifest rewritten. Dead activityLogFile var removed.
(Older 4.x / 5.x changelog entries unchanged — see version history
 in your backups if ever needed.)
```
