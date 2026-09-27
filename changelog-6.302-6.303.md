
NEW IN 6.303.0 — 🔬 WHAT THE KEYBOARD LOOKS LIKE THE MOMENT AFTER A WAKE
(core/hyper_key.lua + init.lua §3.12):

  The release aimed at LL's 10:57 storm, and a PROBE rather than a fix,
  because this is NEW GROUND and the habit written down after the music
  drop says so: on a macOS surface this config has never touched, the
  first release prints what macOS actually answered, never a fix built
  on a belief.

  🔎 THREE THINGS CAN LATCH ⇪ WITH THE KEY PHYSICALLY UP, and until now
  not one of them could be seen from Lua:

    1. THE hidutil REMAP. Caps Lock → F18 is applied ONCE at boot and
       never read back. Drop it between a keyDown and a keyUp and this
       config sees a press it recognises and a release it does not —
       which is the latch, exactly.
    2. THE F18 EVENT TAP. macOS switches taps off across some
       transitions and tells nobody. A dead tap loses the keyUp with
       Carbon as the only remaining path.
    3. SECURE EVENT INPUT (6.196.0). It stops every tap AND hotkey
       dispatch system-wide with no error anywhere — and the lock
       screen on wake is precisely where it lives. It already took his
       keyboard for four hours once, under a boot line reading
       "All green · 104 ⇪ shortcuts".

  Two seconds after every wake, all three are asked. The beat is the
  point: macOS re-enumerates the keyboard asynchronously, so asking
  inside the wake callback measures the moment BEFORE the one that
  matters. HELD in its own slot — a collected timer never fires, which
  would remove the whole measurement.

  🔕 SILENT WHEN HEALTHY (6.269.0). It writes numbers and says nothing.

  🔔 THE ONE THING IT SHOUTS ABOUT IS A REMAP THAT WAS GONE, because
  that means ⇪ had stopped existing — and it puts it back. That is not
  a fix built on a belief: it acts on a MEASURED absence, and the
  alternative is a Mac whose hyper key is dead until Hammerspoon is
  restarted.

  🔎 "GONE" AND "COULD NOT BE ASKED" ARE OPPOSITE FACTS, and only the
  first repairs. A Mac that cannot run hidutil would otherwise re-apply
  the remap after every wake, for ever, on no evidence at all.

  🚨 AND THE FIRST VERSION COLLAPSED EXACTLY THOSE TWO STATES, in one
  line, caught by the suite: `P.remap = (code == 0) and present(out) or
  nil`. That idiom CANNOT RETURN false — `false or nil` is nil — so a
  mapping that was genuinely gone would have read as "could not be
  asked" and nothing would ever have been repaired. The two states this
  release exists to separate, destroyed by a ternary. 6.179.0's family
  (read three values; two makes a refusal look like success), in a new
  costume: A LUA `a and b or c` CANNOT CARRY A FALSE `b`, so it must
  never be used where false is a MEANING rather than a failure.

  🔑 ONE LITERAL, TWO CALLERS (6.231.0): init.lua now publishes
  `_G.hyperRemapJSON`, the exact mapping it applies at boot, and the
  repair uses that. Two copies of that JSON is how a repair comes to
  restore something subtly different from what was there. A build whose
  init.lua does not publish it REFUSES to repair and says why, rather
  than inventing a literal of its own.

  🔢 AND THE ANSWER COMES BACK IN DECIMAL. `hidutil property --get`
  prints the usage codes as plain integers, not as the hex this config
  SETS them with: 0x700000039 is 30064771129 and 0x70000006D is
  30064771181. A parser written for the hex would read "no remap" on
  every healthy Mac and repair a keyboard that was never broken.
  `hyperRemapPresent` is PURE and matches the PAIR, never the source
  alone — a Caps Lock remapped to something ELSE satisfies a Src-only
  test and reads as health while ⇪ is dead, which is the plausible
  wrong implementation and therefore the fixture kept (6.230.0: pick
  the input where right and wrong must differ).

  🪜 6.196.1 / 6.262.0 PAID IN FULL: the read and the repair have
  SEPARATE task slots, so starting one never drops the other, and the
  repair is armed off a HELD doAfter(0) so the read's callback has
  RETURNED before another task starts. That shape has killed this
  process natively twice, with nothing in the Console.

  🔒 SECURE INPUT IS READ, NEVER RE-PROBED. core/capabilities.lua owns
  that ioreg and asks it on its own clock (6.242.0: a probe reads what
  other modules already know and asks only what nobody has asked). A
  source sentry keeps ioreg out of this file.

  🧪 AND A SENTRY WENT RED ON A HEALTHY TREE BEFORE IT WENT GREEN,
  twice over, both worth keeping. It first forbade the string
  `HIDKeyboardModifierMappingSrc` — which is exactly what the PARSER
  must match on, so it could not tell the thing from the thing that
  reads it (6.269.0: an instrument that warns on day one is switched
  off before it ever sees the fault). And 6.262.0's comment-stripper
  ATE THE ARGUMENT: a naive `%-%-[^\n]*` removes everything after the
  first double dash on a line, and hidutil's argv is `{ "property",
  "--get", "UserKeyMapping" }`, so the stripped source lost the one
  occurrence the sentry needed. Full-line comments only now, with a
  second check proving the argument survived — so a stripper that eats
  it again cannot pass by leaving an empty haystack. NAMED, NOT SWEPT:
  other sentries here strip the naive way; none reads an argv today,
  and the one that does next inherits this.

  🧪 The suite DIED instead of failing under two of its own mutations —
  the probe timer's slot is nil when the probe fires inline, and
  indexing it ends the run with "0 failed" never printed. 6.186.0,
  tenth time: a test HELPER answers falsely rather than dying.

  🔬 `_G.hyperWakeProbeRun("by hand")` is public ON PURPOSE. An
  instrument that only runs when the lid opens is one he cannot be
  asked for by name — 6.267.0's lesson, where a verify block asked him
  to paste a line that a WORKING release guarantees will not exist.

  📏 NAMED, NOT FIXED: a tap found switched off is REPORTED, not
  restarted. Restarting a tap is not the same kind of act as restoring
  a mapping — the tap may have been stopped by this config's own
  failure counter, and re-arming it would undo a decision made on
  purpose. Its own release, once his report says whether it ever
  happens.

NEW IN 6.302.0 — 🌅 A WAKE IS A RELEASE
(core/hyper_key.lua + modules/hyper_storm.lua):

  LL's ⇪ storm report, written at 10:57, and his own sentence beside
  it when asked what had happened just before: "My laptop travelled
  with me in my car and I just plugged it in."

  🔎 THAT FITS EVERY NUMBER IN THE FILE, and one of them decides it.
  The report says `⇪ held 10.5 s`, and that age is measured from
  `_G.hyperEnteredAt` — so if the hold had survived the journey it
  would have read 58 minutes, which is the gap to the previous ⇪ key
  in the trail. It read ten seconds. The hold BEGAN AFTER THE WAKE:
  he opened the lid, pressed Caps Lock for the first time in an hour,
  and that press never ended. Six different shortcuts fired under it
  while he typed at ten keys a second — ⇪⇧P into the pomodoro, ⇪p and
  ⇪a forwarded into Chrome — and at 10.5 s the 6.214.1 storm guard
  judged it a phantom, released it and wrote the file.

  🚨 AND `0 watchdog release(s)` IN THAT FILE IS CORRECT, not a second
  fault. The 6.162.1 watchdog cannot end a latch while keys keep
  arriving: its own rule is that a key under ⇪ proves the hold, so
  every keystroke pushed the deadline out. A person fighting a dead
  keyboard never stops pressing keys. That is the exact hole the storm
  guard was built to cover, and it covered it.

  🔎 THE GAP WAS PRECISE, AND IT WAS READ RATHER THAN GUESSED: NOTHING
  IN THIS CONFIG WATCHED THE WAKE. The only `hs.caffeinate.watcher`
  anywhere here is activity_tracker.lua's, and it listens for
  `screensDidLock` and `systemWillSleep` — the SLEEP side. Not one
  line in seventy-one modules handled `systemDidWake`,
  `screensDidUnlock` or `sessionDidBecomeActive`.


  🚨 AND HERE IS THE THING THIS RELEASE HAS TO SAY ABOUT ITSELF,
  BECAUSE IT WAS ONE COMMIT FROM SHIPPING THE OPPOSITE: **RELEASING
  ON WAKE DOES NOT EXPLAIN THAT STORM, AND COULD NOT HAVE PREVENTED
  IT.** The reasoning that proposed this fix and the reasoning that
  read the artefact contradict each other, and the artefact wins.
  `_G.hyperEnteredAt` is stamped in ONE place — hyperEnter's `else`
  branch, the one taken only when ⇪ was NOT already down — so an age
  of 10.5 s means the hold started 10.5 s before the guard fired,
  which is AFTER the wake, not across it. A watcher firing at the
  moment the lid opened would have found ⇪ up, answered "clear", and
  released nothing. The storm would have happened exactly as it did.

  🔎 6.198.0, CAUGHT ON THE WAY OUT OF THE DOOR RATHER THAN A YEAR
  LATER, and the mechanism is worth writing down because it is not
  the usual shape of that mistake. This was not a correct fix for a
  plausible-but-wrong mechanism; the WAKE really is the setting, and
  every number in the file still points at it. It is a correct fix
  for the wrong MOMENT — right neighbourhood, wrong instant — and
  that reads as a diagnosis right up until you ask which side of the
  wake the hold began on. GENERAL: WHEN A FIX AND AN ARTEFACT AGREE
  ABOUT THE CAUSE, CHECK THAT THEY ALSO AGREE ABOUT THE ORDER OF
  EVENTS. A timestamp in the report is worth more than a story that
  fits every other field.

  🔑 SO WHAT THIS RELEASE IS, honestly: wakes are now VISIBLE to the
  hyper key at all, which they have never been, and a hold that IS
  still open across one is let go. That second half is right on its
  own terms — nobody holds Caps Lock through a sleep, so such a hold
  is stale by definition and the cost of being wrong is one more ⇪
  press — but it closes a NEIGHBOURING hole, not his. The first half
  is the one that matters, because it is the precondition for
  6.303.0: until something in this config knew a wake had happened,
  nothing could look at the keyboard the moment after one.

  🔬 6.303.0 IS THE PROBE AIMED AT THE STORM, and this is NEW GROUND,
  so it is a probe and not a fix built on a belief. Three things can
  make a ⇪ press latch with the key physically up, all three are
  invisible from Lua today, and all three are cheap to ask after a
  wake: the hidutil Caps Lock → F18 remap (applied once at boot by
  §3.12 and never read back), the F18 event tap (macOS disables taps
  across some transitions), and SECURE EVENT INPUT (6.196.0 — it
  stops every tap AND hotkey dispatch system-wide, with no error
  anywhere, and a lock screen on wake is exactly where it lives).

  🚨 AND A WAKE RELEASE IS NOT A LATCH. `_G.hyperLatchReleases` is the
  number the storm report prints as a fault. A wake release happens
  every morning on a perfectly healthy Mac, so counting it there would
  make the fault counter climb on health — which is 6.285.0's lesson
  verbatim, one release later, and the reason that release exists at
  all. It gets its own counter (`_G.hyperWakeReleases`), its own line
  in `_G.hyperKeyReport()`, and its own field on the storm report's
  `before :` line.

  🔕 IT IS SILENT: a Console line, no alert. An alert every time he
  opens the lid is a warning he stops reading (6.269.0).

  🔎 THREE ANSWERS, NEVER TWO (6.196.1), and here it is load-bearing
  rather than decorative: `hyperWakeVerdict` answers *ignored* (not an
  event we watch — the sleep side is not counted as a wake, or the
  number becomes "caffeinate events" and says nothing on a Mac that
  locks its screen all day), *clear* (a wake found ⇪ up — this is what
  health looks like, and it is NOT the same fact as no wake at all),
  and *release*. The report keeps them apart, so "4 wake(s) seen, none
  found ⇪ held" can never be confused with a watcher that was never
  running.

  PURE, with the event list as a TABLE the gate can move and require
  the verdict to follow (6.239.0) — asserting the three literals would
  pass against a verdict that spells them out a second time.

  🚪 IT TAKES `core.exit`, THE SAME DOOR EVERY OTHER ENDING USES, and
  deliberately NOT `_G.hyperForceRelease`: that door counts a latch,
  which is the one thing this release refuses to do.

  🔒 THE GUARD GOES AROUND THE WHOLE CALLBACK BODY (6.235.0) — inside
  a platform callback a throw is a silence, and evaluating the event
  lookup as an argument to `pcall` would put it outside. Its own check.

  🛟 TWO REFUSAL SHAPES, and the limit is said rather than hoped past:
  `hs.caffeinate.watcher` exposes no `isEnabled`, so unlike hs.eventtap
  "created and then refused to run" (6.265.0's beta-OS shape) cannot be
  detected here. What can be — `new` throwing, `new` answering nothing,
  `start` throwing, and hs.caffeinate being absent — each leaves the
  state NAMING it, takes the 🔔 door once at boot, and puts a ⚠️ on the
  report line rather than a count of zero.

  🌩 THE STORM REPORT'S `before :` LINE carries the wake count AND the
  watcher's state, because 0 releases on a Mac that was watching and 0
  on a Mac that was not are opposite facts — and that line is the
  fingerprint that named 6.282.0 as the build he was running.

  📏 AND ONE SENTENCE FROM HIM STILL NARROWS IT FASTER THAN ANY
  PROBE: was ⇪ working between that storm at 10:57 and his reload
  that evening? If it was DEAD until the reload, the remap really is
  being lost on wake and that is a bigger bug than the storm. If it
  went on working, the remap survived and the keyUp was dropped by
  the tap or by Secure Input. The artefact comes first (6.201.0).

  🧪 A SECOND FINDING, IN THE GATE ITSELF, and it had nothing to do
  with this feature: test_scratch_pad's task-grammar section pinned its
  clock to 26 September 2026 and then compared the answers against
  `os.date("%Y-%m-%d")` with NO argument — the real today. The two
  agreed on exactly one calendar day. Those checks passed when 6.300.0
  shipped and turned the whole gate red at the next midnight, blaming
  code that had not changed. GENERAL: 6.230.0's rule, in a clock — a
  fixture whose right and wrong answers AGREE proves nothing, and one
  that agrees for a day is worse, because it reports the disagreement
  as a bug in the thing it was meant to check.

  🚨 A THIRD, AND IT IS 6.269.0's OWN RULE TURNED ON THIS PROJECT:
  CLAUDE.md has said for releases that the gate fails at 3,800 lines of
  init.lua as well as at 4,000. It did not. Only the 4,000 check
  existed — found by writing this release's header, pushing the file to
  3,802, and watching nothing go red. WHEN A COMMENT CLAIMS A CHECK,
  GREP FOR THE CHECK: the 3,800 check is written now, the header was
  trimmed to 3,799, and the working budget is a gate rather than a
  habit.
