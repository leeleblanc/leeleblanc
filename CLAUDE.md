# CLAUDE.md — durable project memory

This file is the long-term memory for Claude sessions on this repo. Chat
threads get compacted; this file does not. Keep it LEAN — it loads into every
context window. When a durable fact changes (a rule, a ritual, a contract),
update this file in the same commit that changes it.

## What this is

LL's Hammerspoon config. All real code lives under `hammerspoon/`. Everything
must run on LL's home Mac AND run as well as possible on the more constrained
work Mac.

## Hard rules — never violate

- `secret.lua` is per-machine, deliberately never synced or backed up, and
  never deleted. The Asana token lives only there — never in the repo, never
  in a process argument list.
- `hammerspoon/packs/` (6.162.0) holds the four PUBLIC packs and IS in git;
  `snippets/` stays gitignored (output + any private extras) and delivered
  zips carry ONLY `snippets/bundled.lua`. textpanders (real addresses, a
  phone number, an employee ID) lives in LL's OneDrive snippets folder —
  never in the repo, never in a zip.
- 📦 A ZIP IS NOT SHIPPED UNTIL HE CAN OPEN IT, AND IT IS VERIFIED BEFORE
  IT IS SENT (6.263.0, LL: "The zip is empty again. Why is that
  happening?" — twice now, 6.260.0 and 6.262.0). BUILDING IS NOT
  DELIVERING AND DELIVERING IS NOT ARRIVING; a release he cannot unpack
  is a release that did not ship, however green the gate was. THE ORDER,
  every time, no step skipped:
  1. Build to `/tmp/pkg` by the recipe in repo-root `.gitignore`, run
     `tools/run-tests.sh` from INSIDE it, zip at the repo root.
  2. 🔍 VERIFY THE ARTEFACT, never the intention: `unzip -t` (integrity),
     `unzip -l | tail -1` (entry count and bytes), and `init.lua` present
     AT THE ROOT carrying THIS release's version stamp — unzip it to a
     scratch folder and grep line 7. A zip built from a stale `/tmp/pkg`
     is the failure mode that looks exactly like success.
  3. 📣 SAY THE NUMBERS IN THE MESSAGE — entry count, megabytes, the
     version grepped out of the unpacked init.lua. That turns "it's
     empty" from a mood into an artefact: if he opens it and sees none of
     what was named, the TRANSPORT dropped it and nothing about the build
     is in question. Without the numbers there is no way to tell a bad
     build from a bad delivery, which is why this went two rounds.
  4. 🗂 THE ZIP IS COMMITTED. This reverses "release zips are never
     committed", on evidence: it has been delivered twice with the file
     untracked — once gitignored, once un-ignored — and both times he got
     nothing openable. Tracked is the one variable never tried, and repo
     tidiness does not outrank him being able to install the release.
     ONE AT A TIME: the previous release's zip is deleted in the same
     commit, so the working tree carries exactly one. COST, NAMED, and it
     is real: git history keeps every blob for ever, so this is ~3 MB per
     release that never comes back. That is the price of a delivery that
     works.
  🚚 AND IT STILL ARRIVED EMPTY — SO THE FORMAT CHANGED (6.266.0, LL
     on the committed 6.265.0 zip: "265 was an empty zip. I'm honestly
     tired of fixing that. Not mad at you. Just tired."). THIRD TIME.
     The clause that used to sit here said that if a COMMITTED zip still
     arrived empty the cause was not git and the format was next; that
     condition is met, so it is spent and this is what replaced it.
     BOTH THE FORMAT AND THE TRANSPORT CHANGE, because each earlier fix
     changed something INSIDE the same pipeline:
       · The delivered archive is a **.tar.gz**, never a .zip. macOS
         opens one on a double-click exactly as it opens the other, and
         it is written by a different tool and unpacked by a different
         code path on his Mac — every layer that could be eating the
         bytes is a layer that is no longer in the way.
       · AND IT IS COMMITTED AND LINKED, so there is a SECOND and
         entirely separate way to get it: his browser → GitHub → his
         Downloads folder, with nothing in the chat touching the bytes.
         The message carries that URL every time, not only on request.
       · SAY THE NUMBERS FOR WHAT HE ACTUALLY RECEIVES (entries, MB,
         the version grepped out of an unpacked init.lua), so a bad
         delivery stays distinguishable from a bad build.
     🔑 THE PRINCIPLE, and it generalises past archives: when a
     delivery fails three times and every fix so far changed something
     inside the SAME pipeline, the pipeline IS the variable — stop
     refining it and route around it.
  📎 6.281.0 — AND HE NAMED THE ROUTE THAT WORKS: **INLINE, NOT GITHUB**
     (LL, on the 6.281.0 GitHub page: "Empty zip again. When you put it
     inline, it was perfect. Put it inline again and not to github.").
     So the delivery is the file attached in the conversation, and the
     GitHub URL is NOT offered — not as a second route, not as a
     footnote. The clause that used to sit here said the GitHub link
     becomes the delivery if the tar.gz also arrived empty; he has
     answered that question the other way and his answer wins.
     🔎 AND THE FACT WORTH KEEPING, because it is the opposite of the
     three that came before: that page was NOT an empty file. It read
     `2.61 MB` and "Sorry about that, but we can't show files that are
     this big right now" — GitHub REFUSING TO PREVIEW a 2.6 MB binary,
     which is a viewer limit and says nothing about the bytes. Four
     "empty archive" reports, and the fourth one is a rendering message.
     GENERAL: when a delivery is reported broken for the Nth time, check
     whether the evidence is about the ARTEFACT or about the VIEWER —
     they look identical from the person's side and have opposite fixes.
     📣 The numbers still go in the message (entries, MB, the version
     grepped out of an unpacked init.lua), because they are what tells a
     bad build from a bad delivery. The archive is still committed — the
     repo is the archive and a rollback needs it — it is simply not the
     route he is pointed at.
- ✍️ LL DOES NOT EDIT init.lua AND A SETTINGS LINE IS NOT AN ANSWER
  (6.267.0, LL: "I do not edit the init.lua so I don't cause simple
  errors. You are to generate and test a new init.lua."). Every
  `settings = { ... }` line handed to him as the fix for something he
  reported is work he has said he will not do, and a knob nobody turns
  is a default that is wrong. So: when a default is wrong, CHANGE THE
  DEFAULT AND SHIP IT. Knobs are still written — they are how a release
  stays reversible and how the gate proves a switch is real — but they
  are documented, never prescribed. The one exception is a decision that
  is genuinely his taste and has two defensible answers; there, ask him
  which he wants and ship the answer, rather than leaving the line in a
  message for him to type.
- Backups copy only `~/.ssh/config` — never the keys beside it, never the
  Keychain. daily_backup excludes `secret.lua` and `applock.json` from every
  rsync.
- `hs.window.filter` is banned in the config (sentries enforce it).
- Battery saver never dims the screen, never touches pmset/sudo; the hog
  caller-out never kills/pauses/renices apps.
- ⇪⇧Z is reserved for later — do not bind it.
- ⇪⇧Z is the ONLY unspent key left — do not bind it. ⇪⇧T and ⇪1 were
  spent in 6.194.0 (type-the-clipboard and mouse-follows). Free combos
  after 6.216.0: ⇪⇧[, ⇪⇧], ⇪⇧, and ⇪⇧. (⇪⇧7 → Bluetooth 6.216.0;
  test_shortcut_hints' unmapped fixture key is ⇪⇧] now) — check `hint.groups` in
  modules/shortcut_hints.lua, which is the authoritative map of every
  bound combo, BEFORE promising LL a key. (⇪3 → vault 6.172.0; ⇪⇧U →
  anchors 6.180.0.)
- IT DEGRADES, IT NEVER BREAKS (6.177.0, LL: "build it so it degrades
  gracefully and nothing breaks — and that's the same for all our code
  going forward. It must work on my home Mac and my work Mac."). Every
  new path assumes NOTHING: not that another module is loaded, not that
  OneDrive exists, not that a folder is writable, not that a binary is
  installed. Missing dependency → the feature says so and the rest still
  works; one failed item → that item, never the batch; a failure never
  touches the user's text, a store or a keystroke. Return ok, why — do
  not throw. And SAY the degraded state in the report, honestly (the
  export's "no OneDrive found — local only" line is the shape).
- The hyper hold is TIMED (6.162.1, init.lua §3.12): a lost F18 keyUp
  latched ⇪ and took LL's Mac. Any new path that enters the modal must go
  through hyperEnter (it arms `_G.hyperLatchTimer`); any tap that sees keys
  under ⇪ must call `_G.hyperTouch()`. Never add an untimed way in.
  6.165.1: a shortcut that opens a TEXT PANEL calls
  `_G.hyperExpectRelease(1.5, who)` after show (deadline 8 s → 1.5 s of
  silence) and its page forwards an F18 keyup to `_G.hyperReleaseSeen(who)`.
  Do the same in any new text panel.
- 🔔 A BREAK IS SEEN, NEVER ONLY LOGGED (6.214.0, LL: "I also must have
  anything here that breaks to throw an error so I see it, know about
  it, and can fix it with you"). This does not undo IT DEGRADES, IT
  NEVER BREAKS — it says where the degraded state goes: an hs.alert
  naming the tool and the cause AT THE MOMENT it happens, a ⚠️ Console
  line, AND the report line; a report line alone is a break he finds a
  week later. 🚪 THE DOOR EXISTS (6.215.0, core/notices.lua):
  `return core.degrade("Tool", why)` — alert (a DIRECT hs.alert, never
  notices.tell: Focus must not hold it), ⚠️ Console line, ledger row,
  returns false, why. Same tool + cause alerts once per
  `notices.degradeEvery` (600 s), counted and printed every time; the
  tool table and the per-tool causes are bounded; nil-tolerant;
  init.lua's core table carries a fallback if notices did not load.
  `_G.degradeReport()`. A module TAKES the door when it is next opened
  — one per release, never a sweep (LL's one-change rule); the storm
  guard took it first (cannot-list, announce threw in warm). Until a
  module has taken it, its NEW degrade path alerts and prints itself.
  Never a throw that stops the rest of the config — the alert is the
  error he asked for.
- 🌩 A LATCHED ⇪ IS A STORM AND ENDS ITSELF (6.214.1, modules/
  hyper_storm.lua, LL on 6.214.0: "killed my keyboard and made every
  key execute some hammerspoon action … can't hammerspoon catch
  itself, stop the execution after 5 seconds of this error condition
  and generate an error report I can give you?"). The 6.162.1
  watchdog CANNOT end a latch while keys keep arriving — its own rule
  says a key under ⇪ proves the hold — and a person fighting a dead
  keyboard never stops pressing keys; ⇧Esc alone pausing it proved ⇪
  was "held". The storm rule (`st.judge`, PURE): held ≥ 5 s, ≥ 6
  DIFFERENT shortcuts fired inside the hold, no Caps Lock autorepeat
  in 2 s (the F18 bind has a repeatfn now; `_G.hyperEnteredAt` /
  `_G.hyperRepeatAt` are the facts, stamped in hyperEnter and the
  repeatfn) → `_G.hyperForceRelease`, a report file in
  ~/.hammerspoon/.storm/ (LOCAL), alert + Console + notices; a second
  storm in 10 min pauses (⇪⇧Esc); next boot announces once. NOT
  found by reading: the 6.213.3→6.214.0 diff has no hotkey/tap/hold/
  panel change, so the trigger is unnamed until a storm file says
  which panel had asked for a release (`asked :` line) and which
  keys ran. LL'S GATE ON SHIPPING was: nothing after 6.214.1 ships
  until it held on BOTH Macs. He scored 6.214.2 on the home Mac
  ("6.214.2 home ✓ · work Mac later") and then said "Go ahead" —
  his call, so 6.215.0 shipped on the home ✓ alone; the work Mac
  installs 6.215.0 (it carries 6.214.2) and its `_G.stormReport()`
  is still owed.
- 🔤 ⇪Z LEARNS THE CORRECTION LL JUST MADE HIMSELF (6.243.0,
  modules/autocorrect.lua). LL: "I wanted a quick way to use the last
  correction I makee and then I type make to fix it, is either added by
  you catching it, or me adding it via shortcut key." HIS CALL on the one
  open decision was ARM, not write: backspacing over a word and retyping
  a near-twin of it ARMS the pair silently, and ⇪Z within `selfSecs` (30)
  writes the row through _G.autocorrectAdd. A pair nobody presses ⇪Z on
  is never written. That is his own OCR rule ("if the method can
  introduce errors, singles only") in the right place — a similarity
  test is a guess, a keypress is not.
  🔑 NO NEW KEY: ⇪Z undoes OURS when there is one (unchanged, and it
  wins) and learns HIS when there is not. 6.199.0’s test for whether a
  rule belongs here at all. ONE cheat-sheet row for the two states — the
  6.196.0 auditor reads a combo listed twice as a conflict.
  🚨 THE DETECTOR SITS BELOW THE INJECTION GUARD, and a source sentry
  holds it there. 6.218.0: a retype comes back through the tap, so this
  module’s own corrections are indistinguishable from LL’s unless that
  guard separates them — get it wrong and the dictionary teaches itself
  its own rules, on both Macs, for ever. The sentry exists because the
  functional check would still pass on the day the guard broke.
  🔎 `acEditsOne` is PURE (Damerau–Levenshtein capped at one, three
  branches not a matrix — the answer is only ever "one or not one" and a
  matrix per keystroke is main-thread work). cat → dog is a REWRITE and
  is never offered; three letters is the floor because teh → the IS the
  typo. A NEW RETYPE REPLACES THE OFFER whether or not it qualifies (⇪Z
  means "the last correction you made"), while typing an ordinary word
  does not — or the 30 seconds last until the next space.
  ↩️ A ROW A KEYPRESS WROTE OWES A WAY BACK, which is 6.199.0’s rule in
  the other column. There is no shipped list to set-difference eleven
  thousand fix rows against, so THE ROW SAYS SO ITSELF: a FOURTH column,
  `fix,makee,make,⇪Z`. The loader has always read c[1..3] and ignored the
  rest, so old rows load here and these load in older builds.
  `_G.autocorrectReport()`’s "⇪Z taught" block names each with its line;
  `_G.autocorrectForgetFix("makee")` removes EVERY matching row, tagged
  or not (leaving a hand-written one behind means the word goes on being
  corrected after a command that said it would stop).
  🧪 TWO CHECKS PASSED FOR THE WRONG REASON: the capitalisation refusal
  passed with its branch deleted, because "The"/"the" are ZERO edits
  apart once lowered and the edit rule turns them away by itself — the
  branch earns its place by giving the TRUE reason (a dead row, 6.199.0)
  rather than a lie about an edit count, so the check asserts the REASON.
  And the suite’s ⇪Z helper had to deliver the undo’s posted keys back
  into the tap, or the guard stayed up and swallowed every later
  keystroke in the section — a test measuring its own stub.
- ✏️ AN APOSTROPHE INSIDE A WORD IS NOT A WORD ENDING (6.219.0,
  modules/autocorrect.lua — LL on 6.218.0: "Doesnt't kinda works").
  The typing watcher ends a word on punctuation, and an apostrophe is
  punctuation, so "Doesn't" hands "Doesn" to the rules — and Webster's
  Second HOLDS the apostrophe-less contractions. Measured on web2:
  doesn → doesnt, wouldn → wouldnt, mightn → mightnt, oughtn → oughtnt,
  and nothing else (couldn/shouldn/mustn/needn/weren have no single
  answer, haven is a word, can't/won't/isn't/didn't are under minLen 5)
  — which is why exactly one contraction ever reached him. THE WORD
  LIST IS NOT ASKED WHEN THE BOUNDARY IS AN APOSTROPHE; the dictionary
  rows and TWo-caps still are. `acSpellHereOK` is asked in ONE place
  and a source sentry keeps it there. COST, NAMED: a typo immediately
  before an apostrophe (somethign's) is silent now. 🧪 And §9's storm
  test had been built ON this bug (doesn' → doesnt'), so fixing it
  would have disarmed the 6.218.0 drain check — §9 proves the drain
  with two dictionary rows that answer each other (aaaa ⇄ bbbb) now.
  RULE: when a test uses one bug to demonstrate another, fixing the
  first silently retires the second — re-arm it in the same release.
- 🖱 A MAIN THREAD THIS CONFIG IS BUSY ON IS A MOUSE THIS MAC HAS LOST
  (6.228.0, modules/file_tracker.lua — LL: "I can't move files in drag
  and drop again … caps lock stays on and Hammerspoon seems locked up").
  Every hs.eventtap on the Mac is queued behind the main thread, so work
  done there does not merely make Hammerspoon slow: it DELAYS other
  apps' input. A mouse-down delayed past Finder's drag threshold is a
  drag that never starts — the symptom lands in FINDER, with no error,
  no throw and no beach ball long enough for the 60 s stall guard.
  🔎 FOUR REPORTS NAMED NOTHING AND ALL FOUR WERE TRUE: boot 480 ms vs a
  usual 467; 0 storms and ⇪ not held; the stall guard watching and
  beating; window_move with all twelve panels closed and "no click at
  all". THE MISSING REPORT WAS THE ANSWER — file_tracker had none, so
  the one module woken by the exact action he was complaining about was
  the one module that could not be asked. 6.196.1's rule, and it cost
  the same thing twice.
  📋 IT WAS MEASURED, NOT REPAIRED, ON PURPOSE: "the file tracker is
  slow" names a MODULE, not a cause. The FSEvents WAKE-UP (it watches
  the whole HOME FOLDER) and the synchronous CSV WRITE (into OneDrive)
  are two different repairs with two different costs, so they are timed
  APART and printed side by side with their own worst cases. 6.224.0's
  rule, second time it has decided a release: when a diagnostic still
  decides nothing, the missing half is a CLOCK. Past `ft.slowMs`
  (120 ms) it takes the 🔔 door naming which half.
  🔌 A SWITCH IS ONLY REAL IF THE THING IT GOVERNS STARTS AFTER setup:
  init.lua applies a profile's `settings` AFTER setup returns, so
  anything a module STARTS inside setup can never be stopped by an
  override — the flag is written and nobody reads it again. The
  watchers moved to `M.warm`. window_move's `wm.enabled` has exactly
  that shape today and is decorative because of it; fix it when that
  module is next opened. `settings = { file_tracker = { enabled =
  false } }`, `_G.fileTracker.stopWatching()`, `_G.fileTrackerReport()`.
  🎯 6.229.0 — AND THE ANSWER WAS NEITHER HALF: it was HOW OFTEN. LL's
  day-long report read 60,115 wake-up(s) · 204,662 path(s) seen · 49
  row(s) written · 16,597 ms total · worst 58 ms · none over 120 ms. Four
  thousand paths woke the module for every row that survived, and the
  alert never fired because no single event was expensive. THE INSTRUMENT
  MEASURED THE WRONG DIMENSION — `ft.slowMs` budgets ONE event and the
  damage was FREQUENCY. RULE, general: a budget on the size of one event
  is not a budget on the cost of a feature; when a cost is paid per
  wake-up, COUNT THE WAKE-UPS, and print what they BOUGHT beside what they
  cost (the report's "yield :" line).
  🚨 THE FILTERING WAS IN THE WRONG PLACE. fileTrackerExcludedPath had
  always discarded everything under ~/Library — in LUA, which is AFTER
  macOS woke the main thread and built the path array. The work was always
  wasted; only the wake-up was not. It moved to the WATCH: one
  pathwatcher per folder inside the home folder, ~/Library not among them,
  so FSEvents never wakes us for it. WHICH LOSES HIM NOTHING, provable
  from his own numbers rather than promised — the rows that stop arriving
  are the rows already being discarded. GENERAL: an exclusion that runs
  after the expensive thing has happened is not a filter, it is a receipt.
  `ft.watchRoots` is PURE and carries three rules with their own
  mutations: OneDrive is added back BY NAME (it lives inside ~/Library);
  ~/.hammerspoon survives the hidden rule because the exclusions keep it
  on purpose (narrowing a watch must not quietly un-decide something the
  exclusions decided); and a cloud folder a kept folder already contains
  is never watched twice (`ft.covers`) — two watchers over one tree is two
  wake-ups per event. `ft.homeDirs` returns nil, NEVER {}, when the Mac
  cannot list: an empty answer would watch nothing and read as normal, so
  nil falls back to the whole home folder and takes the 🔔 door. COST
  NAMED: a loose file at the top of ~ is unwatched, a new folder there
  waits for a reload; `settings = { file_tracker = { folders = {...} } }`.
  🔗 6.230.0 — AND A SYMLINK WALKS STRAIGHT PAST ALL OF IT. LL's first
  report on 6.229.0 listed BOTH `/Users/leeleblanc/OneDrive` and
  `/Users/leeleblanc/Library/CloudStorage/OneDrive-Personal` as watched;
  `hs.fs.symlinkAttributes(p, "mode")` → `link` (his Console, asked for
  before theorising). ONE tree, two watchers, two wake-ups for every file
  event in the busiest folder on the Mac — inside the release whose whole
  purpose was to cut wake-ups. `ft.covers` could not catch it because it
  compares TEXT and neither path is a prefix of the other; `ft.homeDirs`
  could not see it because `hs.fs.attributes` FOLLOWS a link and answered
  "directory". GENERAL RULE: a check that identifies a thing by its PATH
  is not a check about the thing — resolve before you compare, and ask
  symlinkAttributes when the question is "what IS this", because
  attributes answers about the DESTINATION. THE FIX IS RESOLVE THEN
  DE-DUPLICATE, never "skip every symlink" — a link to a folder he really
  does keep elsewhere is a folder he wants watched; what is wrong is
  watching one tree twice. `ft.realOf` (realpath → symlinkAttributes as
  the belt → the path itself as the floor; a RELATIVE answer is refused;
  it degrades, never throws) and `ft.dedupeRoots` (PURE given a resolver).
  👁 THE REAL PATH WINS THE SLOT, never whichever name the listing
  returned first — `hs.fs.dir` gives filesystem order and on his Mac the
  link comes first, so "first wins" would watch the tree under its link
  name and report the REAL path as redundant, contradicting the watching
  list two lines above. The dropped root is NAMED in a "linked :" line: a
  root that vanishes with no explanation is indistinguishable from a
  folder that stopped being watched, and those are opposite facts.
  🚨 AND THE YIELD LINE DIVIDED BY A ROW THAT WAS NOT THERE — `max(rows,
  1)` printed "65 path(s) for every row kept" over a session that kept
  none. A division that did not happen, dressed as a measurement, in the
  line 6.229.0 added to stop exactly that.
  🧪 THE STUB ANSWERED nil FOR A SYMLINK instead of following it, so the
  bug was untestable (6.193.0, again). And the belt's check passed with
  the belt deleted, because over a ONE-HOP link realpath and
  symlinkAttributes agree — a CHAIN (A → B → C: realpath says C, the belt
  says B) is the only thing that tells the two halves apart. 6.221.0's
  rule in a new costume. 🐛 `abs = abs or default` cannot be switched off
  by a caller passing false — `false or default` IS the default — so the
  gate could not exercise the halves independently; nil means "work it
  out", anything else is taken at its word.
  🐛 `local names, ok = {}, pcall(function() … names … end)` is NOT what it
  looks like — Lua evaluates the whole right-hand side before the locals
  exist, so the closure took a nil GLOBAL `names`, threw, and reported a
  healthy Mac as unable to list its own home folder. Declare first.
  🧪 THE DOOR'S FIRST TWO CHECKS PASSED WITH THE WRITE'S OWN ALERT
  DELETED — a slow write is INSIDE the wake-up containing it, so the
  wake-up alerts on the same event with the same tool name and the same
  words. 6.212.0's stroke-counting row and 6.220.0's ordering check are
  the same family: assert what is UNIQUE to the branch. And the fixture
  could not make a row at all until its home folder stopped being its
  logs folder — the module excludes the whole Logs folder, so it never
  feeds itself.
- 🎵 A MODE SAYS WHAT A TOOL DOES ON ITS OWN — IT NEVER REFUSES AN
  INSTRUCTION (6.231.0, modules/music_player.lua, LL's ⇪⇧pad. player).
  `mp.nextIndex(i, n, mode, manual)` is PURE and carries the whole rule: a
  track that ENDS under repeat-one plays again, and pressing ⏭ under
  repeat-one moves ON. Two callers, one function, its own mutation (which
  fails three rows). Generalises to any toggle that governs automatic
  behaviour — shuffle, auto-advance, a re-try — where a person's explicit
  ask must still win.
  🔔 AND A CALLBACK YOU CANNOT PROVE FIRES GETS A BELT THAT READS THE
  STATE. hs.sound's end-of-track callback is the documented way to hear a
  track finish; if it does not arrive the playlist stops after one song
  with no error anywhere to see. The held tick is running regardless (it
  draws the clock), so it also asks whether the sound stopped. COUNT THE
  TWO APART (`mp.advances.callback` / `.belt`, printed side by side): if
  the callback stays 0 while the belt climbs, the belt is carrying the
  feature — which is what stops someone deleting it for looking
  redundant. 🚨 And the belt must not fire EARLY: a PAUSED track has also
  stopped, so "ended" is stopped AND at its duration. Its own row.
  🚚 A DROPPED FILE'S PATH DOES NOT COME FROM `dataTransfer.files` —
  WebKit never hands a page a File's path, so `.name` is a name and
  nothing openable. It comes from the drag's `text/uri-list` (Finder
  fills it with file:// URLs), percent-escapes UNDONE or every track with
  a space or an apostrophe in its name is silently unopenable. A drop
  with no uri-list is NAMED, never swallowed.
  🚨 AND THE LINE THAT USED TO SIT HERE WAS BACKWARDS, WHICH COST THE
  WHOLE FEATURE (corrected 6.233.0). It read "hs.canvas has NO drop
  target at all — anything droppable in this config must be a webview".
  The truth, checked in the source rather than remembered:
  extensions/webview/libwebview.m contains the string "dragg" ZERO times
  — **hs.webview has no drag-and-drop of any kind** — while
  extensions/canvas/libcanvas.m has `hs.canvas:draggingCallback`, the
  NSDraggingDestination methods and registerForDraggedTypes. **hs.canvas
  is the ONLY thing in Hammerspoon that can accept a dragged file.** The
  card was made a webview BECAUSE of the false line, so LL's drop could
  never have worked on any Mac and he was handed a verify block for it
  twice. GENERAL RULE, and it is the expensive one: A PLATFORM FACT THAT
  DECIDES AN ARCHITECTURE IS CHECKED IN THE SOURCE, WITH THE FILE NAMED
  — 6.202.0 said "checked, not assumed names the file" about a bug; this
  says it about a design.
  🎯 THE CATCHER SITS UNDER THE CARD (6.233.0): an invisible canvas at
  the card's frame, at `windowLevels.dragging` with a placeholder
  `mouseCallback` — BOTH conditions hs.canvas documents, and neither is
  visible in the result when missing, so both have their own mutation. A
  window that has not registered dragged types is SKIPPED by the drag
  (which is exactly LL's "a drag just puts it behind the player"), so the
  only thing reaching the catcher is a drag the card refused — clicks,
  keys and the wheel still belong to the page. It moves with the card and
  dies with it. The pasteboard is asked three ways (readURL → readString
  → getContents), first answer wins, and the report NAMES which: a drop
  that works on one Mac and not the other is otherwise unanswerable. Both
  doors — the catcher and the page's own handler — end in `mp.takeDrop`.
  🔒 AND A CALLBACK THAT THROWS DOES NOTHING AND SAYS NOTHING (6.235.0,
  LL: "Turns highlighted blue so it seems to see the file but drop doesn't
  work"). The blue is EVIDENCE and it cleared half the feature: the veil is
  drawn from "enter", so the catcher, its level, its mouseCallback and its
  registration are all confirmed right. What remained could THROW —
  `table.concat(u, "\n")` raises on a list holding anything that is not a
  string or a number, hs.pasteboard's readers answer with whatever LuaSkin
  made of the objects on the pasteboard, and the concat sat OUTSIDE the
  pcall that wrapped the read, inside a dragging callback where a raise is
  invisible. `mp.joinLines` is PURE and takes a string, strings, numbers or
  objects carrying a url; every reader is wrapped WHOLE and so is the
  receive. GENERAL: inside any platform callback — dragging, tap, timer,
  task — a throw is a silence, so the guard goes around the WHOLE body, and
  the check that proves it makes something throw that is not already
  guarded on its own.
  🚨 AND `select(2, pcall(f))` IS THE ERROR MESSAGE WHEN f RAISES
  (6.236.1) — the same value slot as the result. A Lua error begins with
  its CHUNK NAME, so on a Mac it starts with "/Users/…", which
  `pathsFromURIList` accepts as a plain-text drag: a reader that FAILED
  handed its own traceback back as a file to play. 6.179.0's read-THREE-
  values rule, broken in new code by the person who wrote it down, and
  caught only because the gate runs suites from an ABSOLUTE path.
  🧪 The check on it first passed for the wrong reason: `error(msg)`
  PREPENDS "file:line:" unless raised at LEVEL 0, so the fake failure did
  not have the shape the real one has and the check bit or not depending
  on how the suite was invoked. RULE: a stub that fakes a failure raises
  at level 0, and a check that only bites under one invocation does not
  bite.
  🔎 AND WHEN NOTHING READS, NAME WHAT WAS THERE: `pasteboardTypes` rides
  into the report, because a second "it did not work" is not an artefact.
  🆔 AND WHAT IT WAS CARRYING WAS NOT A PATH (6.237.0, LL's card: "⚠️
  .15194583 is not an audio file this can play" over an empty queue). By
  6.235.0 the READING worked; macOS puts FILE REFERENCE URLs on a drag
  pasteboard — `file:///.file/id=6571367.15194583` — which name a file by
  VOLUME AND INODE and carry no name and no extension, so `extOf` read the
  inode as a file type and said something true and useless. TWO SHOTS, TWO
  DIFFERENT NUMBERS is what named it: a number that changes per file is an
  inode or a clock, never a bug in one file.
  🔗 A BOOKMARK RESOLVES ONE AND realpath DOES NOT — checked in Libc's own
  source (stdlib/FreeBSD/realpath.c), which walks a path a component at a
  time and REPLACES each with the real NAME getattrlist answers: it hands
  back "/.file/Max McNown - A Lot More Free.mp3", the right name in a
  folder that holds nothing, ENDING IN .mp3 — so the obvious fix would
  have filled the queue with rows that look perfect and cannot open. That
  answer has its own check, because the plausible wrong answer is the one
  worth a row. `hs.fs.pathToBookmark` → `hs.fs.pathFromBookmark` is the
  round trip that works. `mp.resolveRefs(paths, resolve)` is PURE (the
  resolver is an ARGUMENT); an answer counts only if it is ABSOLUTE and is
  not itself a reference; a resolver that throws keeps the path.
  📁 THE PLAIN-PATH FLAVOUR IS ASKED FIRST — NSFilenamesPboardType is a
  plist ARRAY OF POSIX PATHS, so where macOS still offers it none of this
  arises; the report names the reader AND what became of the references.
  🔑 ESCAPES BELONG TO THE URL, NOT THE PATH: percent-decode only a line
  that came from `file://`. "50%25 off.mp3" is a real file name and
  decoding it makes a path that is not there.
  🧪 TWO CHECKS WERE PAID FOR TWICE, both old rules in new costumes: the
  throwing-resolver check KILLED the suite instead of failing it until the
  test pcall'd its own call (6.186.0), and the "no hs.fs" check passed
  with the guard deleted because `pcall(nil, p)` is already false — it
  takes hs.fs away ENTIRELY now, which is what the guard is for.
  🪟 A PUSH INTO A PAGE THAT HAS NOT LOADED IS DROPPED IN SILENCE (6.238.0,
  LL: "I was playing a song … I closed the window and it didn't show but
  then opened again it did"). `view:html()` RETURNS BEFORE WEBKIT HAS
  PARSED THE DOCUMENT, so the `draw(...)` pushed on the next line of show()
  finds no `draw` function and goes nowhere; the page then runs its own
  `draw(S)` over the empty default and nothing redraws until the next state
  change. HIS PHOTOGRAPH CARRIED THE DIAGNOSIS: the card said QUEUE EMPTY
  with the progress bar nearly FULL — the clock kept landing because the
  tick pushes one every half second, by which time the page is up. Two
  pushes into one page, one lost and one not, half a second apart.
  🔑 THE PAGE ASKS: `say({a:'ready'})` as the LAST line of its script (sent
  any earlier it promises something that is not there yet), Lua answers
  with a render, and the blind push stays as the BELT. COUNT THEM APART —
  the report says how many draws landed since the page spoke and how many
  were pushed before it existed, and a page that has never spoken reads as
  a fault, not as health. GENERAL, and it applies to every panel in this
  config that pushes state into a page it has just created: a page tells
  Lua when it exists; Lua does not guess.
  ⏪ ← → SEEK (6.239.0, LL asking with the win: "I need an arrow keys
  left/right as seek" — v1 shipped without it on his own answers). ← →
  5 s, ⇧← ⇧→ 30 s, both from the config (the page is GIVEN the numbers; a
  check moves the config and requires the page to move with it, because
  asserting the shipped default passes when the number is typed in twice).
  `hs.sound:currentTime(n)` IS a setter — extensions/sound/libsound.m,
  [NSSound setCurrentTime:]. `mp.seekTo(cur, delta, dur)` is PURE and
  answers the position AND why: never below 0, never past the end, and a
  duration of 0 means MACOS DID NOT ANSWER, not a zero-length track — so ←
  works there and → does not, because seeking forward into a length nobody
  knows lands in silence with no way back.
  🚨 AND THE BELT CLOCK IS RE-ANCHORED (`mp.startedAt`), or the next tick
  drags the time back to where it was. Any state a fallback derives from a
  START TIME moves when the thing it measures is moved.
  🧪 The test sound's currentTime was a GETTER ONLY, so every seek would
  have "succeeded" while moving nothing — 6.227.0's selectedRow exactly,
  THIRD time a getter-only stub has hidden a whole feature.
  🧪 AND THE MUTATION HARNESS LEFT A MUTATION IN THE TREE mid-release,
  which produced a suite that passed standalone and failed under the gate
  — a symptom with no honest explanation, and forty minutes spent
  diagnosing code nobody had written. RULE: a harness that edits the
  working tree VERIFIES the restore (a SHA) rather than assuming it.
  📁 Its store is LOCAL (~/Library/Application Support/Hammerspoon/music),
  never OneDrive: a half-played queue is not cross-Mac data and 6.229.0
  priced a write into a watched cloud folder. Mutation-proven.
  🔌 SCOPE SET BY HIS ANSWERS, NOT BY TASTE: "just mp3, m4a" → hs.sound,
  no binary, identical on the work Mac; "a full Apple Keyboard" on both →
  ⇪⇧pad. needs no fallback; "native volume keys work" → NO volume and NO
  seek in the player, stated as a decision rather than left as a gap.
  🗑 6.272.0 — AND A ROW CAN BE FORGOTTEN (LL: "did you make it so I
  could delete entries from my music history list? … I don't wanna have
  to ask a second time or third time"). He could not: ⌫ was the QUEUE
  and a history row only PLAYED. A ✕ per row, plus
  `_G.musicForgetHistory(path)` / `_G.musicClearHistory()`.
  🔑 BY PATH, NEVER BY INDEX — 6.186.0's rule: the card draws 40 rows of
  a store holding 400, and any redraw renumbers them under his hand, so
  an index forgets a DIFFERENT track than the one clicked, silently, in
  the one list whose purpose is remembering. `mp.forgetHistory` is PURE;
  an EMPTY path is refused (a blank message must never empty the list)
  and EVERY match goes (6.199.0 — a duplicate left behind after a
  command that said it removed the track).
  🚨 THE ✕ IS ASKED BEFORE THE ROW IT SITS INSIDE, or the shared click
  handler PLAYS the track on its way to forgetting it. Its own check,
  which asserts exactly ONE message was posted.
  🧪 The DOM stub's `closest` ignored its selector, so `[data-x]` matched
  a plain row and three existing checks went red — 6.193.0 in a stub, and
  the fix is that it matches the selector now, as the real one does.
  🕘 THIRTY DAYS, ONE ROW PER FILE (6.234.0, LL: "remember 30 days of
  music track history. But, if it's the same file it should only be listed
  once"). `mp.noteHistory(list, row, now, days, max)` is PURE and carries
  all of it, so the clock is an ARGUMENT and every edge is proven without
  waiting: to the front, stamped; an older row for the same PATH removed
  rather than left behind; past the window dropped; day 29 in, day 31 out.
  THE CAP IS A BOUND NOW, NOT THE RULE — 60 rows WAS the memory and is why
  he could not have a month; `historyDays` (30) decides and `maxHistory`
  (400) only stops a runaway list, keeping the NEWEST (its own check,
  because keeping the oldest is the easy way to write it wrong). Pruned at
  the LOADER too, its own branch and its own check: a Mac left off six
  weeks must not come back holding six weeks. The card draws 40, not 12 —
  a month it cannot show is a month it may as well not remember.
  🔤 A TRACK IS NAMED BY ITS FILE, AND A FILE MAY BE CALLED ANYTHING
  (6.231.1). Every name went into `innerHTML` unescaped and a Lua `esc()`
  written for exactly that was NEVER CALLED. THE ESCAPING BELONGS IN THE
  PAGE, and that is arithmetic not taste: the row draws the name with
  innerHTML and the header draws THE SAME STRING with textContent, where
  an entity is read out literally — one source, two destinations, opposite
  rules. 🔔 And a name the card cannot ENCODE is not an empty queue:
  `rowsJson`'s `or "{}"` drew an empty card over music that was still
  playing (6.196.1's rule, in the one function every redraw passes
  through) and the page then threw on `S.rows.length` and never redrew
  again. The refusal takes the door; `draw()` reads every list by length
  off a payload that may be missing anything.
  🪟 A PANEL THIS CONFIG DRAWS IS A PANEL `_G.movablePanels` KNOWS ABOUT
  (6.232.0, LL: "I need to be able to move the music player like any other
  window"). That table is the ONLY register window_move reads, and a panel
  absent from it is movable by NO means — not ⌘-drag, not a header grip.
  The card was the twelfth panel and the only one missing, and nothing
  could see it because the table is a global other modules fill in; there
  is a check in this module's suite now. TWO GRIPS, neither new: ⌘-drag
  anywhere (window_move's tap, no page involvement) and a BARE press on the
  title strip, which posts `dragStart` → `_G.beginPanelDrag` because a page
  cannot move the window it is drawn in. The strip is safe by construction
  (6.89.0's header rule); the card is deliberately NOT `plain`, which would
  give the bare click to the whole panel where a press on a row picks a
  track. 📍 BOTH GRIPS REMEMBER (6.93.0): the spot rides in the player's
  own local store and `mp.placeFor` is PURE, answering the rect AND why —
  moved · nudged back onto the screen · corner, the remembered spot is on
  no screen now. 6.196.0's cheat-sheet rule decides the third (a position
  on no current screen is DROPPED for the default, never clamped onto a
  screen it was never on) and the nudge exists because a grip you cannot
  reach is the bug being fixed.
  🧪 THE SUITE DIED INSTEAD OF FAILING, AGAIN, two releases running: the
  mutation that deletes the registration left `entry.frame()` indexing a
  nil. And a check that searched the page for "cursor:grab" passed with
  `cursor:default` written after it — the LAST declaration in a CSS rule
  wins, so assert the RULE, never the presence of a string in it.
  🧪 AND THE PAGE HAD NO SUITE AT ALL, which is why none of that was
  known: 6.231.0's 93 Lua checks prove what PLAYS, and the drawing, the
  drop and ↑↓/⏎/space live in the page. tests/dump_music_html.lua +
  tests/test_music_js.js, stage 3e — and the rows it draws are
  `mp.rowsJson()`'s OWN output over names a music folder really holds
  (6.203.0: a harness that hand-builds the message cannot see a bug in
  the sending). RULE, general: A PAGE THIS CONFIG DRAWS IS A PAGE THE
  GATE RUNS — four pages had a suite and the fifth did not, and asking
  for it found the bug in a minute.
  🧪 THE SUITE DIED INSTEAD OF FAILING under one of its own mutations —
  `SOUNDS[#SOUNDS]` was nil and the run ended mid-file with "0 failed"
  never printed. 6.186.0's rule in a new place: a test HELPER answers
  falsely rather than indexing a nil, so a mutation fails a check instead
  of killing the run. Fifteen mutations, fifteen bites.
- 📄 A DOCUMENT IS NAMED BY THE APP, NOT BY ITS TITLE BAR (6.257.0,
  modules/activity_tracker.lua + doc_memory.lua — LL: "It's not showing
  the documents I just worked on. Look at the search window and the
  Finder timestamps. Am I misunderstanding how this works?").
  🔎 HIS ARTEFACT NAMED IT IN ONE LINE and nothing else could have: ⇪0,
  typing "Word", answered `Microsoft Word — 5m 40s`. A search row is
  keyed `app — title`, so a row reading the app ALONE means the title
  was EMPTY for every one of those sessions — not mis-parsed, ABSENT.
  Every document name in that module was read out of the title
  (docFileFromTitle cuts at a dash and insists on a filename), so a Word
  document could not appear in ⇪⇧W on any Mac, ever, and the list was
  honestly reporting "0 documents today" about a day spent in Word. The
  file's own header has said "window title is the closest thing that
  generalizes" since 3.6; it was true when it was written. 6.201.0's
  rule again — ASK FOR THE ARTEFACT: two screenshots said "it's not
  working" and one row said what.
  🔑 THE ANSWER WAS ALREADY HERE. doc_memory reads AXDocument for the ten
  apps that answer it and is the ONLY AXDocument reader in this config,
  so the tracker grows no Accessibility reader of its own: it asks
  `docs.front` when a session OPENS and writes the answer as a SIXTH
  column (`date,app,title,seconds,url,doc`). 6.123.0's url column is the
  precedent in every particular — a column on the row this module
  already writes, never a second observer with a second timer and a
  second CSV, which is the design 6.104.0 DELETED. GENERAL: when one
  module already knows a fact, the second module asks for it.
  ⏱ BOUNDED THREE WAYS, because an AX read is main-thread work and a
  busy main thread is a mouse this Mac has lost (6.228.0): once per
  SESSION not once per tick, only for an app doc_memory says can answer,
  and TIMED — past `ad.slowMs` (60) it takes the 🔔 door naming the app
  and the ms. 🔑 THE APP LIST LIVES IN doc_memory (`dm.watches` →
  `docs.watches`); a copy in the tracker is a list that drifts the day
  LL edits `dm.apps`, and a source sentry fails if one appears.
  🔎 THREE STATES, NEVER TWO (6.196.1): a window with no document
  ANSWERED and said so; a read that came back with nothing at all
  FAILED. `_G.activityDocsReport()` — the tool had none, which is why a
  photograph had to do the diagnosing — counts them apart and names what
  the asking BOUGHT beside what it cost (6.229.0's yield line).
  ✂️ `ad.docName(entry, fromTitle)` is PURE with the title reader handed
  in as an ARGUMENT (6.230.0): the file the app NAMED beats the filename
  read out of a title bar, because one is an answer and the other is a
  guess. `ad.rowLabel` is its twin for ⇪0's rows — the title still wins
  where there is one, and the document is what a session with no title
  is called instead of being called nothing at all. 🗑 AND ⇪⇧E'S JOIN
  ASKS THE SAME FUNCTION, or it shows him a Word document and deletes
  nothing when he asks it to — worse than not showing it (6.231.0, one
  function two callers, its own mutation).
  📏 IT CANNOT LOOK BACKWARDS, and that is said rather than hoped past:
  rows already on disk have no doc column and, for Word, no title
  either. Yesterday's Word time stays a total with no name on it.
  🧪 AND THE STUB WAS GENTLER THAN init.lua, AGAIN (6.193.0): the
  suite's `service.call` returned a provider's values raw while the real
  one pcalls every provider — so the check asking whether a provider
  that DIES takes the poller with it KILLED the suite instead of failing
  (6.186.0 on top). It pcalls now and returns three values, which is the
  whole reason "no document" can be told from "could not be asked".

- 📐 A THING YOU WERE ASKED TO RESTYLE MAY BELONG TO macOS (6.260.0,
  modules/screenshots.lua — LL: "show a live 1280 × 720 in white on a
  90 %-opaque black box", with his earlier "Change the pixel measurement
  tool numbers to solid white in a black box that is 10% translucent").
  One ask written twice, and the two percentages are the SAME number:
  `sizeAlpha = 0.9`. 🚨 BUT THERE WERE NO NUMBERS TO CHANGE. Nothing in
  this config has ever drawn a pixel readout: what he had been looking at
  is `screencapture -i`'s OWN HUD, which Hammerspoon can neither
  restyle, move nor read — while OUR selector (`shots.selectArea`, what
  ⇪5, the editor's ⌘A and "repeat area" drag on) had drawn a dashed band
  and NOTHING ELSE since it was written. 6.233.0's rule in a gentler
  costume: before designing around what a surface does, check WHOSE
  surface it is.
  📏 NAMED, NOT FIXED: ⇪4 is still `screencapture -i` and keeps macOS's
  HUD. Routing ⇪4 through our selector would give it the readout and
  would cost the native magnifier and SPACE-to-capture-a-window — his
  call, its own release, and the report's "size :" line says so where he
  would be reading it to find out why ⇪4 looks unchanged.
  ✏️ THREE PURE FUNCTIONS, so the whole rule is proven with no Mac:
  `sizeText` (his ×, both numbers floored — a fractional pixel is not
  actionable); `sizeBox`, which counts CHARACTERS because "×" is two
  bytes and one glyph and `#` would make every box a glyph too wide
  (6.226.0 in a new place; the check that bites is "1280 × 720" and
  "1280 x 720" measuring the same); and `sizePlan`, which answers the
  frame AND WHY with THREE placements — below the band, ABOVE it against
  the bottom of the screen, INSIDE it when a drag is as tall as the
  display — plus an x clamp that is SAID, because a box moved sideways
  no longer describes the band's centre. A READOUT YOU CANNOT SEE IS THE
  BUG THIS RELEASE EXISTS TO AVOID.
  🔒 IT IS DECORATION ON A LOAD-BEARING DRAG, SO IT IS GUARDED APART
  FROM IT. The selector's mouse callback pcalls its whole body and
  CANCELS THE SELECTION on a throw — right for a per-event path, wrong
  for the numbers. The draw has its own guard, goes quiet for the rest
  of that drag rather than shouting per mouse event, takes the 🔔 door
  ONCE, and the report's ⚠️ outranks the last size (a healthy-looking
  number over a dead feature is 6.196.1's exact failure). GENERAL: when
  a decorative layer shares a guarded, per-event path with the thing it
  decorates, it gets its own guard — the shared one is tuned for the
  load-bearing half.
  📐 6.264.0 — AND ⇪4 DRAGS ON OUR SELECTOR NOW, so the readout is on the
  key he actually presses (LL: "The screenshot crosshairs, yes I get it
  that's Mac, but I wanted a visual that shows the pixels measurements
  better"). 6.260.0 named this as HIS call and he made it. ONE FUNCTION,
  TWO CALLERS — ⇪4 and the ⇪⇧5 panel's 📐 row both go through
  shots.capture. 🚨 `shots.selectArea` ANSWERS true / false, why NOW:
  every failure in it was a bare `return` with the callback never firing,
  which was survivable while its callers had nowhere else to go and is
  not now that ⇪4 does — a ⇪4 that captures nothing is worse than a ⇪4
  with Apple's HUD, so a Mac that cannot draw ours takes `-i` instead.
  🧪 AND ALL THREE OF `areaPlan`'s PURE BRANCH CHECKS PASSED WITH THAT
  FALLBACK DISCONNECTED — the mutation restoring the bare `return` bit
  nothing until a check TOOK hs.canvas AWAY and pressed the key. GENERAL,
  and it is the one to carry: proving a pure decision function is not
  proving that anything CALLS it with the values that matter; the check
  that earns its place drives the whole path with the dependency removed.
  🔔 A SWAP MUST NOT QUIETLY TAKE A SOUND AWAY: captureRect has always
  passed `-x`, right for "repeat that rectangle" and wrong for ⇪4, where
  the shutter has been the confirmation since it was bound —
  `withSound`, existing callers unchanged. 🔎 THREE STATES on the
  report's "area :" line, because his settings line and a fallback look
  identical on screen and are opposite facts; the ⚠️ goes on the fallback
  only. 📋 The cheat sheet moved in the same commit (its ⇪4 row promised
  "SPACE = window"). 📏 COST: no native magnifier, no SPACE-to-shoot-a-
  window on ⇪4; `settings = { screenshots = { areaNative = true } }`.
  🚨 6.265.0 — AND THAT RELEASE THREW ⇪4 AWAY FOR A DAY (LL: "Hyper+4 no
  longer works to screenshot"). `_G.showCanvasSafely` returns FALSE when
  macOS refuses the first `:show()`, and selectArea called it for EFFECT
  and answered `true` regardless — so on a refusal ⇪4 drew nothing, shot
  nothing and said nothing, with the correct fallback one branch away.
  THE FALLBACK EXISTED AND WAS UNREACHABLE. A second door had the same
  silence: the show sat inside `if _G.showCanvasSafely then`, so a
  Hammerspoon without that global never showed the selector and still
  reported success; it shows the canvas itself now. A refused canvas is
  TORN DOWN (an abandoned one keeps its Esc tap and the retry timer that
  can order an owner-less overlay on screen a turn later — the 🟡
  frozen-grid-box shape). 🧪 GENERAL, AND IT IS THE ONE TO CARRY: 6.264.0's
  degrade check took `hs.canvas.new` AWAY, and the real failure is
  "created, wired, REFUSED TO SHOW" — driving a path with the dependency
  MISSING is not the same as driving it with the dependency REFUSING, and
  on a beta OS the second is the shape this config keeps meeting. When a
  helper answers true/false, the check that earns its place makes it
  answer FALSE. (6.193.0, fourth time.)
  🏃 AND IT MOVES, NEVER REBUILDS: two elements on the selector's
  existing canvas, appended once. 6.247.0 priced a rebuild on a path
  that runs per event. 🧪 The suite DIED instead of failing under its
  own first mutation — deleting the floor makes `("%d"):format(240.7)`
  RAISE, and a raise inside a check's expression ends the run with "0
  failed" never printed. 6.186.0, fifth time: a test HELPER answers
  falsely.
- 🧊 A PANEL THE CALLER HAS GIVEN UP ON IS NEVER PUT BACK ON SCREEN
  (6.266.0, init.lua `_G.showCanvasSafely` + modules/mouse_grid.lua — LL:
  "Frozen grid again", with the yellow landed-box outline over a Finder
  dialog). A SUSPECT in this file for eight releases, and the reading
  was right: the retry that has caught AppKit's mid-transition assertion
  since 6.56.0 called `canvas:show()` ITSELF a run-loop turn later,
  telling nobody. mouse_grid records what it shows in `grid.shown`, and
  `hideAllShown()` hides that list and EMPTIES it — so an Esc inside
  those 50 ms hid the box, threw away the only handle to it, and the
  retry put it back with nothing able to reach it. Not `grid.hide()`,
  not `_G.mouseGrid.hide()`. Only `hs.reload()`.
  🔑 `onLate` — THE RETRY HANDS THE CANVAS BACK AND THE CALLER DECIDES.
  A caller that passes nothing gets NO second show at all, which is the
  safe default and the one all fifteen callers but mouse_grid take
  today, so the class closes in ONE change instead of fifteen modules.
  `_G.canvasRetryPlan(hasLate, canTimer)` is PURE (give up · give up, no
  timer · hand back, each with its reason) and the helper ASKS it —
  6.264.0 priced proving a pure decision nothing drives.
  🚨 AND THE RE-RECORD IS NOT DECORATION: `enterLanded()` calls
  `hideAllShown()` while `grid.state` is still non-nil, so a retry
  landing after the three letters are typed is the SAME orphan one turn
  on. Its check first passed with the line deleted (showCanvas records
  every canvas on the way out anyway) and had to move to the landed grid
  — 6.199.0, fourth time.
  📏 COST, NAMED: a panel refused once no longer reappears by itself;
  press the key again, which the message has said since 6.56.0, and it
  is said on the FIRST refusal now because there is no second one to
  wait for. The hs.alert retry beside it is deliberately untouched — an
  alert owns itself and expires in two seconds.
  🧪 The canvas stub THROWS the real NSInternalInconsistencyException
  now: 6.265.0 was a loss for driving a path with the dependency MISSING
  when the shape that happens on a beta OS is "created, wired, REFUSED".
  `_G.canvasShowReport()` — refused / handed back / dropped, three
  different facts.
  🚨 GENERAL, and it is the one to carry: ANY HELPER IN THIS CONFIG THAT
  RETRIES SOMETHING ON A CALLER'S BEHALF MUST ASK THE CALLER FIRST. A
  retry that acts a turn later is acting on a decision that may have
  been reversed, and it holds the only reference to the thing it acts
  on — which makes it unreachable by the code that owns it.
- ⏱ A STORE IS READ WHEN IT IS FIRST NEEDED, NEVER DURING BOOT
  (6.267.0, modules/file_tracker.lua + activity_tracker.lua — LL, with
  his own ⏱ line: "How can I wrap the file_tracker and activity_tracker
  initialization in an asynchronous timer to speed up the boot?" 453 ms
  across 72 modules, 350 of them in those two). Each setup() opened a CSV
  in OneDrive, parsed it whole, pruned it and sometimes REWROTE it — on
  the main thread, before a single ⇪ shortcut was bound.
  🔑 THE TIMER ALREADY EXISTS AND A BARE doAfter IS THE WRONG ONE.
  `M.warm` runs seconds after boot in its own pcall and a warm that
  throws is NAMED (6.33.0); a second unheld timer beside it is 6.196.1's
  shape. And a blind timer leaves the published list EMPTY until it
  lands, so ⇪F in that window draws a 90-day history with nothing in it
  — "not read yet" and "you have no history" reading the same, which is
  exactly what 6.196.1 forbids.
  🚪 SO: LAZY, THROUGH ONE DOOR. The first caller pays; warm() is that
  caller on an ordinary Mac, so no keypress waits; a keypress that
  arrives first gets the read rather than an empty answer. `M.warmAfter`
  (3.0 · 4.5) puts the two reads on DIFFERENT turns — two OneDrive CSVs
  parsed in one turn is one long stall wearing two names (6.228.0).
  🔒 A SOURCE SENTRY PER MODULE: the published global is WRITTEN where
  it is published and READ nowhere. One caller left on the bare global
  sees nil before the read and nothing functional would notice.
  🧪 AND THE SUITES BOOT THE WAY init.lua BOOTS — setup, THEN warm
  (6.259.0). Three suites installed fixtures by ASSIGNING the published
  global, which is now the module's OUTPUT, not its input; they write a
  CSV and let the loader parse it (6.203.0). Two mutations killed a
  suite instead of failing it until the helpers answered falsely rather
  than indexing a nil — 6.186.0, sixth time.
  📏 COST, NAMED: the read is still synchronous and still on the main
  thread when it happens. What moved is WHEN. Taking the parse off the
  thread is a different release with a different mechanism (/bin/cat in
  an hs.task, 6.170.3's shape) and was not smuggled in here.
  🚨 GENERAL: anything a module reads from DISK at setup is a tax every
  other module and every key pays. Ask whether the first keypress could
  pay it instead — and if it could, the answer is a door, not a timer.
- 🎯 A TOOL THAT ANNOUNCES ITSELF IN THE MIDDLE OF SOMETHING ELSE IS A
  TOOL YOU SWITCH OFF (6.259.0, modules/dialog_home.lua — LL, with a
  photograph of its own capture toast, "🎯 Dialogs will open here now —
  _G.dialogHome.reset() undoes it", sitting over a film he was
  watching: "Turn off this feature in all future releases").
  `dh.enabled` ships FALSE. 🗑 NOTHING IS DELETED (6.254.0's shape):
  every line is here, the spot he captured is still in hs.settings and
  the OFF status SAYS so rather than leaving him to wonder, and one
  settings line brings it back.
  🔌 THE RELEASE'S REAL WORK IS THAT THE SWITCH IS REAL IN BOTH
  DIRECTIONS: the wiring moved out of setup() into `M.warm`, because
  init.lua applies a profile's `settings` AFTER setup returns — a module
  that STARTS its watchers in setup can only ever be stopped by an
  override, never started (6.228.0 named this module's shape and said to
  fix it when it was next opened). With OFF as the default the broken
  direction is the useful one, so a removal that did not move the wiring
  would have been a removal with no way back.
  🔎 OFF IS OFF, NOT MADE-AND-HIDDEN — no app watcher, no AX observer, no
  held timer, asserted rather than claimed; and "enabled" is not
  "running", so a Mac that turned it on and never warmed reads as a
  FAULT (6.196.1). 📋 The ⇪/ sheet says OFF in its title and carries the
  settings line (6.181.0: a sheet promising behaviour that no longer
  happens is a broken feature).
  🧪 AND THE SUITE DIED INSTEAD OF FAILING, fourth time: the mutation
  that stops the app watcher being registered left `WATCH_FN(...)`
  calling a nil and the run ended with "0 failed" never printed. A test
  HELPER answers falsely (6.186.0). GENERAL: a suite that boots a module
  must boot it the way init.lua does — setup, THEN settings, THEN warm —
  or it cannot tell a real switch from a decorative one.
  🗑 6.261.0 — AND THEN HE ASKED FOR THE ROOM, NOT THE DOOR (LL, with a
  photograph of the ⇪/ card the switched-OFF tool was still drawing:
  "Remove this feature from future releases"). modules/dialog_home.lua,
  tests/test_dialog_home.lua, the §1.12 loader line, the ⇪/ card,
  `_G.dialogs()` and `_G.dialogHome` are DELETED — 73 modules → 72, 73
  Lua suites → 72, and the counts in hs-doctor.sh, INSTALL.md and
  GUIDE.md moved in the same commit (a count printed to a human is a lie
  the moment a file goes). GENERAL, and it is the correction to 6.254.0's
  shape rather than a reversal of it: KEEPING EVERYTHING IS RIGHT FOR A
  DOOR AND WRONG FOR A TOOL HE DOES NOT WANT. A switched-off feature
  still loads, still draws its sheet card and still answers its report,
  so the only thing it does is describe itself. 🔑 A REMOVAL IS CHEAP
  BECAUSE THE ARCHIVE IS GIT: every line is at 6.260.0 f16e286 and the
  whole story is in CHANGELOG.md, so a deletion never needs hedging with
  a flag nobody will set — "bring it back" is a checkout, not a rewrite.
  🧪 AND A DELETION MUST NOT QUIETLY RETIRE A GUARD: test_features names
  six modules in its hs.window.filter sweep and dialog_home was one of
  them ON PURPOSE (watching windows appear is that ban's textbook
  temptation), so removing it would have left five names and a comment
  explaining why a sixth mattered. mouse_follows inherits the slot — the
  same application-watcher plus AX-observer shape, by its own header —
  and the pin was mutation-proven on its new module. When you delete a
  module a sentry names, the sentry gets a new name in the SAME commit or
  it is weaker than it reads.
  📏 NAMED, NOT SWEPT: the captured spot stays in hs.settings under
  "dialogHome.pos", inert, because the code that could clear it is the
  code deleted; `hs.settings.clear("dialogHome.pos")` removes it.
  🗑 6.268.0 — SECOND TIME, AND THE RULE HELD: modules/shortcut_hints.lua
  is deleted (LL, with a photograph of its ⇪/ card: "this should be
  completely gone"). 6.240.0 had switched the card OFF in both profiles
  and the tool went on loading, printing its own boot line and drawing
  its own cheat-sheet card about a thing that no longer happened. 72
  modules → 71, 72 suites → 71, counts moved in the same commit.
  🔑 THE NEW HALF, AND IT IS THE ONE TO CARRY: **A DELETED MODULE MAY BE
  HOLDING DATA THAT IS NOT ITS FEATURE.** Three files read this module as
  a DATA SOURCE, none of them for the card. `hint.coreRows` — the sixteen
  keys init.lua and core/ bind THEMSELVES, which no module's cheatsheet
  claims — was read by tools/build-feature-list.lua and printed into
  RESOLVED-FEATURE-REQUESTS.txt, a file that ships and that LL opens. A
  plain `rm` would have dropped those rows in SILENCE, and no gate could
  have caught it: the generator reads with `readAll(...) or ""`, so a
  missing file is an empty table, never an error.
  🗳 THE TEST THAT DECIDES: is this data ABOUT the feature, or data the
  feature happened to hold? `coreRows` documents keys that exist whether
  or not a card is ever drawn → it MOVED, to its ONE reader, as a literal
  list (a Lua table with string keys has no order, and those rows are
  printed for a human to scan). `hint.groups` was the card's own layout →
  it went WITH the card, and the two suites asserting "this key is filed
  in it" were left asserting a fact about a table nothing draws, so both
  now rest on the real binding and the real cheat sheet. GENERAL: before
  deleting a module, grep every reader of it and sort them into the two
  piles — the ones that wanted the FEATURE die with it, the ones that
  wanted a FACT get rehomed to whoever still needs the fact.
  🧪 SIX SENTRIES ABOUT THE CLASS, not the file: the module, the suite,
  the loader line, any profile settings key, run-tests.sh's list, and the
  CALL SITE. The call site is the quiet one — `if _G.shortcutHint then …`
  is nil-guarded, so the config boots green for ever calling a hook
  nothing can set. Two of the six READ THE SOURCE WITH COMMENTS STRIPPED
  (6.262.0), because the comments left behind deliberately quote the very
  lines they forbid; the profile check was written WITHOUT the strip and
  went red on the first gate run.
  📏 NAMED, NOT SWEPT: core/coexist.lua keeps the ladder rung `hint = 4`
  with a note, following `pinbadge`'s precedent (win_pin, removed
  6.166.0) — the rungs are literals, not offsets, so removing one buys
  nothing and risks a silent re-levelling of every panel above it.

- 🖼 A CHROME YOU HAVE NOT RESERVED IS A CHROME THAT SITS ON THE WORK
  (6.270.0, modules/screenshot_editor.lua — LL, THIRD time: the editor
  "has not had the tools that run across the top of the editor and a
  column on the left-hand side and the right hand side so at a minimum,
  the canvas that the screenshot is placed on would be big enough to
  accommodate the tool buttons on each side").
  🚨 IT WAS NEVER BUILT, and that is the first thing to say. All
  eighteen buttons sat in ONE `<header>` with flex-wrap; there was no
  rail anywhere in the page. Queued as 6.261.0, displaced by the
  dialog-home deletion, never rebuilt — and the queue note reading "HE
  IS NOT doing something wrong" sat there for nine releases while he
  installed build after build and checked for it. A queue item that
  records its own displacement still has to be REQUEUED; writing down
  why it slipped is not the same as putting it back.
  📏 HIS SENTENCE NAMED THE ARITHMETIC, not the decoration:
  `ed.windowSizeFor` reserved 28 points of chrome — twelve a side — so
  there was no ROOM for a rail even in principle. The rails are reserved
  BEFORE the picture is measured now; the shot keeps the size it would
  have had and the WINDOW grows. GENERAL: when a panel gains furniture
  down its sides, the reservation goes in the sizing function first —
  add the furniture first and it either covers the content or squeezes
  it, and both read as "the new thing is broken".
  📐 A FLOOR, NOT PADDING, in the other axis: nine stacked tools need
  `railMinH` + the header, so a tiny shot cannot open a window too short
  to show its own toolbar. Past that the rails SCROLL and never clip — a
  button you cannot reach is the complaint being fixed.
  🔑 ONE NUMBER, TWO READERS: the CSS is written from `ed.railW` and the
  arithmetic reserves the same field, so a rail drawn 200 wide in a
  window reserving 136 cannot happen. The check moves the config to a
  width this Mac has never shipped (6.239.0).
  🧪 THE CHECKS ARE ABOUT STRUCTURE: a tool left behind in the header is
  a rail that only LOOKS built and is the same complaint next month, so
  the header is asserted to carry NOTHING but the title, the finish
  actions and the hint.
  🚨 AND THE FIRST VERSION OF THAT CHECK PASSED ITS OWN MUTATION: it
  searched for the bare id, and `tool-blur` is a PREFIX of
  `tool-blur-moved`, so renaming a button satisfied a check written to
  notice a button going missing. 6.236.0's rule — a name sentry matches
  the DELIMITER — broken in a check built to catch that very shape, and
  found only because the mutation was run. It matches `id="tool-blur"`
  with its closing quote now. GENERAL, third time in this file: any
  sentry that looks for a NAME looks for its boundary too.
  🪜 AND THE HARNESS ORDER IS A RULE NOW, not a habit: COMMIT FIRST,
  THEN MUTATE. A sweep that edits the working tree before the work is
  committed leaves a window in which any commit captures a deliberately
  broken file, and it cost this session three stalls. Once the release
  is committed a stray mutation is a `git checkout` away (which is the
  one moment that command is safe — 6.268.0 learned the other half). And the two old size checks asserted 828 and 320
  — the numbers from before there was a rail to fit — which is 6.248.0
  again: they would have gone red with nothing to say about the change
  they existed to prove. Assert the RULE in terms of the config.

- 🔔 A REFUSED ALERT IS THE FAILURE OF THE THING THAT REPORTS FAILURES
  (6.274.0, init.lua's alert wrap + core/notices.lua + screenshots.lua —
  LL: "hyper+4 is intermittently working", with eight hours of Console
  carrying THREE `⚠️ an alert could not draw` lines). EVERY rule in this
  file ends in an hs.alert — the 🔔 degrade door, A BREAK IS SEEN NEVER
  ONLY LOGGED, every "it says so rather than failing silently". When
  AppKit refuses one, the tool did its job, the message was written and
  he saw nothing; and the line that printed did not even say WHAT the
  alert had been about, so a message explaining a dead ⇪4 is
  indistinguishable from one about the weather. `_G.alertReport()`:
  asked · refused · RECOVERED on the retry · LOST outright, with the last
  refusal's own words. "Seen late" and "never seen" are different facts
  (6.196.1), and a retry that could never be ARMED counts as LOST — else
  a Mac with no hs.timer reads as "still in flight" for ever, which is
  6.196.1's exact failure inside the instrument built to keep it.
  `_G.alertWords` is PURE, takes a string OR a styled table, flattens to
  one line and cuts in CHARACTERS (utf8), never bytes.
  🔎 AND "INTERMITTENT" IS A COUNT, NOT A SAMPLE (6.229.0's rule, second
  time it has decided a release): `shots.areaLast` named only the LAST
  ⇪4, which can never answer a question about a key that works most of
  the time. `shots.areaRuns` counts the routes apart — and the REFUSAL is
  counted apart from his own `areaNative` settings line deliberately,
  because those look identical on screen and are opposite facts; a count
  that summed them would be as useless as the line it replaced.
  🚪 `ensureDir` TAKES THE DOOR: a ⇪4 with nowhere to write said so in an
  hs.alert and nothing else — exactly the channel macOS was refusing.
  🚨 THE CAUSE OF HIS ⇪4 IS STILL NOT NAMED, and this release does not
  guess it: every silent exit on that path was read and all of them
  already answer `false, why` (6.265.0 closed that class). 6.198.0's rule
  — a correct fix for a plausible mechanism is not evidence — so the
  release is the instrument, and the next one is whatever his report
  names. GENERAL: when a symptom is INTERMITTENT, the missing half is
  never a better guess, it is a per-outcome COUNT.
  🧪 Two existing checks asserted the old alert's WORDING and went red on
  the move; the rule they were written for (the refusal names the folder
  it looked for) is unchanged, so they ask the door (6.248.0). And one
  NEW check was wrong before the code was — it measured a
  character-budgeted answer with `:len()`, which is bytes, so a correct
  answer failed a check written to prove it (6.226.0, in the test).
  🧪 AND THE GLYPH CHECK PASSED ITS OWN MUTATION at first: it asked only
  "is the answer still valid UTF-8" at a budget of 5, and a BYTE cut
  there takes `s:sub(1, 4)` — exactly one whole four-byte emoji, valid by
  luck. It asserts the character COUNT as well now, which a byte cut
  cannot get right. GENERAL, and it is the same shape as 6.230.0's
  one-hop symlink: a fixture where the right and wrong implementations
  AGREE proves nothing — pick the input where they must differ.

- ⏯ A KEY NOBODY CLAIMED IS NOT A BROKEN KEY (6.289.0,
  modules/music_player.lua — LL: "Pressing play/pause doesn't work. But
  volume keys do"). Both sentences are about the same row of keys: the
  volume keys are macOS's own and work everywhere, and ⏯ was going
  wherever macOS thinks the music is. Nothing was broken; the key had
  never been claimed. GENERAL: when a report contrasts two things that
  "work" and "don't", check whether the working one is even ours.
  🚨 AND A TAP MUST NOT STEAL A SYSTEM KEY. Swallowing ⏯ whenever this
  config is loaded would cost him Music.app and every browser tab
  playing audio, silently, from boot — worse than the bug, and far
  harder to attribute. `mp.mediaVerdict` is PURE and narrow: TAKEN only
  when this player has a queue; otherwise passed straight through. The
  check that bites is the empty queue.
  ⏭ `mp.step` is ONE function, two callers (6.231.0). The tap starts in
  warm(), never setup (6.228.0); stands down on `_G.hsPaused` (6.152.0);
  and a key UP or an autorepeat is not a press — acting on the release
  toggles twice per press, which reads as "the key does nothing".
  🛟 TWO REFUSAL SHAPES: `hs.eventtap.new` throwing, and a tap CREATED
  AND THEN REFUSING TO START (6.265.0 — the beta-OS shape). Only the
  second leaves `mediaTap` assigned, so only there does nilling it
  matter, and its mutation survived until the stub modelled it.
  📏 NAMED: this reads his sentence as the HARDWARE key. If he meant the
  ▶︎ button or the space bar, 6.251.0's `keyboard :` line names that
  instead — the verify block asks him which, in one sentence.
  🔕 The volume keys stay macOS's on purpose: 6.231.0 shipped without
  volume on his own answer, and taking them now would undo his decision.

- 🖥 A HELPER THAT PICKS A SCREEN FOR YOU MUST NOT BE HANDED A POINT BY
  CODE THAT HAS ALREADY PICKED ONE (6.288.0, core/cheatsheet.lua — LL:
  "Appears on a different screen sometimes — and when it does it seems
  to not be the frontmost window until I move it").
  🔎 BOTH SENTENCES ARE ONE MECHANISM, and it is readable rather than
  guessed — which matters, because this is the third wrong-monitor
  report and 6.198.0 says a correct fix for a plausible mechanism is not
  evidence. 6.196.0 stores the spot as an OFFSET into its screen and
  6.236.0 resolves the right screen; both correct. Then the last line
  handed the answer to `_G.clampToScreen`, which walks allScreens() and
  clamps to the FIRST screen the point overlaps — so an offset saved on
  the 4K, applied to the Air's origin, lands on the 4K and is KEPT
  there. And a sheet on the other monitor is a sheet that is not in
  front of him: he drags it back and it appears. Reading those as two
  bugs would have sent the release hunting a window-level fault that is
  not there.
  🔑 `cheatSheet.placeIn` is PURE and clamps into the RESOLVED screen
  and nothing else, with four answers (6.196.1): centred · where you put
  it · nudged back from a bigger screen · a legacy absolute spot on a
  screen you are not on is DROPPED, never dragged onto one it was never
  on. A source sentry keeps clampToScreen out of the file; the helper is
  right for a caller with no resolved screen and wrong for one that has
  worked it out. `_G.cheatSheetReport()` names which rule placed it.

- ✏️ A TEXT NOTE IS A BOX, NOT A LINE (6.287.0,
  modules/screenshot_editor.lua — LL's four asks in one breath: wrap ·
  font size independent of the box · RETURN drops a line · dragging the
  box smaller re-wraps instead of growing the letters).
  🔎 ONE DEFECT FROM FOUR SIDES: 6.188.0 built the corner handle as a
  glyph SCALE, so the only thing a text note ever had was a font size —
  no width to wrap at, nothing for Return to make a line of, and the one
  control doing the one thing he did not want.
  🔑 ONE NEW FIELD, `w`, the width it wraps at, and all four fall out of
  it. snapNote already carries every numeric field, so ⌘Z undoes a
  re-wrap through the same generic op as a move. 🕰 A note WITHOUT it
  (every older kept session) lays out exactly as before — one line — and
  the first plain drag turns it into a box. Its own check.
  ✏️ HIS SUGGESTION WAS THE RIGHT SHAPE and is credited: plain corner
  drag re-wraps, ⇧drag scales. Two jobs on one control with a modifier
  deciding (6.248.0) — and the check asserts BOTH halves, because one
  alone passes with the modifier ignored, which hands the bug back.
  ⏎ is a NEW LINE, ⇧⏎ is done: the input had to become a <textarea>,
  since an <input> cannot hold a newline at all. The PLACEHOLDER says
  both, because a key that used to finish and now does not reads as a
  bug (6.203.0 — say it where he is looking).
  🚨 A word wider than the box is broken by character, or it runs out of
  the rectangle it is meant to be inside. 🚨 The ANCHOR does not move
  when a note gains a line — it grows downward, or the mark stops
  pointing at the thing it was put there for.
  📏 `textW` is the ONE function that answers the right edge (its own
  width, else the longest line's measurement); the box, the draw and the
  handle all ask it. Its mutation: always measuring makes a box he
  dragged WIDER snap back to the words — a box he cannot widen.

- 🚪 A PROMISE KEPT BY ONE DOOR IS NOT KEPT (6.286.0,
  modules/screenshot_editor.lua — LL, on an annotated screenshot:
  "Closing the screenshot editor dumps the most recent edits so I lose
  any changes"). 6.189.0 promises the OPPOSITE, its checks are green,
  and it was telling the truth about exactly ONE way out.
  🔎 THE WORK LIVES IN THE PAGE, and only its `stashAndCancel()` hands
  it back. The Cancel button called it; nothing else did. The Esc
  ROUTER called ed.close() straight out, ed.open()'s first line is
  ed.close() (so ⇪⇧1 on another shot threw the first shot's marks away
  in silence), and `closeOnEscape(true)` let WebKit close the window
  behind Lua's back, racing the page's own handler — so even the built
  path was a coin toss. GENERAL: when a feature's promise depends on
  asking a page, GREP EVERY DOOR that ends the page; the one the person
  actually presses is rarely the one the feature was written against.
  🔑 THE CLOSE IS ASYNCHRONOUS NOW. `ed.requestClose` asks and closes on
  the reply; a HELD belt in its own slot closes anyway after
  `closeGraceSecs`. Armed BEFORE the ask (6.246.0), and the check
  asserts the ORDER, not that both happened (6.220.0).
  🚨 A doAfter THAT ANSWERS nil IS NOT A BELT — the first version tested
  that the function EXISTED, armed nothing and left the window open for
  ever (6.265.0's "created, wired, REFUSED", found by the sweep). No
  belt → close at once: a window that will not close is worse than
  marks that were not kept.
  🗑 And a duplicate stopCloseBelt in the cancel branch was written and
  taken out again — close() does it on every path that reaches there
  (6.199.0, fourth time).

- 🔔 A HANDOVER IS NOT A LATCH, AND THEY WERE PRINTED IDENTICALLY
  (6.285.0, init.lua §3.12 + core/hyper_key.lua — LL's Console, on an
  ordinary ⇪⇧pad.: "⇪ released by the watchdog — held 8s … musicPlayer
  had taken the keyboard").
  🔎 NOTHING WAS WRONG. The card takes the keys on purpose (6.251.0), so
  the keyUp goes to ITS window; 6.165.1's handshake ends the hold 1.5 s
  later by design. Both halves worked — and produced the sentence this
  config prints when ⇪ is genuinely STUCK, plus an increment of
  `hyperLatchReleases`, the number the storm report calls a fault. A
  healthy Mac accumulating fault counts, and the line that should make
  him look twice became the one he sees whenever he plays music.
  6.269.0's rule, in an instrument that predates it.
  🚨 AND `_G.hyperTouch()` WAS THE WRONG ANSWER — THIS FILE SAID IT FOR
  A RELEASE. hyperTouch means "a key proves this hold is real" and
  pushes the deadline OUT: a card calling it would hold ⇪ latched
  LONGER. The card already does both correct halves. What was missing
  was not a call, it was a DISTINCTION. GENERAL: before adding a call to
  a guard, read what the guard's own vocabulary means — "alive" and
  "ending cleanly" are opposite instructions.
  🔑 THREE ENDINGS (6.196.1), only the third a fault: relay (a page saw
  the keyUp) · handover (a panel declared itself) · latch. Relays were
  counted as latches too. `_G.hyperEndVerdict` is PURE and answers kind
  AND words so the callers cannot drift; it lives in core/hyper_key.lua
  because init.lua is at its 3,800-line budget, and §3.12 falls back to
  the old sentence when it is absent. 🔕 A handover is explained ONCE
  per panel per session and counted every time. `_G.hyperKeyReport()`.

- 🏷 A LIVE ANSWER TO A STALE QUESTION IS STILL STALE (6.284.0,
  modules/asana_comments.lua — LL: "Why do I have to hard code team
  names", with the team's real name beside it, two words shorter than
  the literal the config was hunting for).
  🔎 THE FETCH WAS NEVER THE STALE HALF. The team list is asked of
  Asana LIVE on every boot; the literal in the file is the question.
  So renaming a team is exactly what breaks it, and the warning is
  CORRECT — which is why it survived in a boot log for months.
  🔑 `M.teamKey` and `M.matchTeam` are PURE and live OUTSIDE setup(),
  so the gate proves the rule with no Mac and no network and they cost
  nothing from this file's near-the-ceiling local budget. A resolved
  gid is PINNED in hs.settings, so the NEXT rename costs nothing:
  three answers — by name · by pinned gid (SAYING what the team is
  called now) · not found.
  🚨 IT RE-PINS THE KEY WE ASKED WITH, not only the current name.
  Pinning only the new name reads tidier and makes the pin DECAY — the
  config still asks the old name, so the rename would survive exactly
  one boot. Its own mutation, and a second boot drives it.
  🚨 AND A STALE PIN MUST NOT INVENT A TEAM: a pinned gid Asana no
  longer holds is "none", or the roster fetch is handed a gid that
  404s and the picker shortens with nothing saying why.
  🔎 THE ⚠️ NAMES WHAT ASANA ANSWERED. The old line advised "check
  spelling/spacing" — which the comparison had already ruled out, being
  case-folded and trimmed on both sides — and named no real team, so a
  WRONG rename warned identically. `_G.asanaTeams()`.
  📏 COST OF A MISS: a shortened ⇪T picker; a name not on the list
  still submits. GENERAL: when a lookup joins something we ASK with
  something a service ANSWERS, check which side is the one going stale
  — and pin the service's own identifier, which cannot be renamed.
  🧪 The module had NO SUITE, which is how a hand-rolled :lower()
  comparison sat in it for a hundred releases. 13 mutations, 13 bites.

- 🧠 A WINDOW THAT IS NEVER REMEMBERED CAN ONLY BE SEEN FROM ITS OWN
  DESKTOP (6.283.0, modules/window_switcher.lua — LL, twice: "Still
  can't see Hammerspoon window using Alt+tab … unless I switch to that
  desktop I can't see it." His second sentence IS the diagnosis).
  🔎 `altTab.known` is the ONLY route to another Space (6.152.0 — AX
  does not report other desktops and hs.window.filter is banned). The
  per-app sweep fed it; §1b's console block built its tile and recorded
  NOTHING. So the Console was listable only from the Space it was on,
  and no press could teach it — which is why 6.215.0 scored "Alt+tab
  Success. Shows Hammerspoon now" and it has looked like a regression
  ever since. Both reports were true, taken on different desktops.
  🔑 ONE DOOR, `altTab.remember` — 6.231.0 in its ABSENT form: two
  copies of "remember this window", one of them simply missing. A source
  sentry allows exactly one `altTab.known[…] = {` and it is inside that
  function; the prune's `= nil` is still allowed, or it could not forget.
  🖥 AND THE ANSWER WAS THE ACTION, NOT A BETTER PROBE. Nothing cheap
  tells "on another desktop" from "closed": allWindows() answers absent
  for both, an ordered-out window's AX handle can still answer role(),
  isVisible() never reads the Space, and hswindow() is banned (6.160.3).
  `hs.openConsole(true)` is correct in BOTH, so a console card always
  works — which retires 6.147.0's "a closed console is not a tile" by
  removing the dead card that rule existed to prevent (6.280.0: re-ask
  the decision, do not drop it). GENERAL: when two states cannot be told
  apart cheaply, ask whether the ACTION can be made right in both before
  building an instrument to separate them.
  🔎 `_G.switcherReport()` — the module had none, so this could only be
  answered by reading the source. The console line has three states
  (6.196.1): on this desktop · remembered · never seen this session.

- 🕒 A REPORT THAT RAISES IS EVERY ASK IN THIS FILE, ANSWERED WITH
  NOTHING (6.282.0, modules/screenshots.lua — LL pasted a traceback
  where a report belongs: `screenshots.lua:1398: bad argument #2 to
  'date' (number has no integer representation)`).
  🔎 `hs.timer.secondsSinceEpoch()` RETURNS A FLOAT and os.date REFUSES
  one. `shots.areaLast.at` is written from it, so the report's `area`
  line did not print something wrong — it THREW, and took the whole
  report with it, in every session in which ⇪4 had been pressed even
  once. Live since 6.264.0 and invisible because a FRESH boot takes the
  `or` branch and prints happily, so the only Mac that could see it was
  one that had used the key.
  🚨 AND IT DISARMED THE METHOD, WHICH IS WHY IT JUMPED THE QUEUE:
  nearly every rule here ends in "ask him for the report" (6.201.0), and
  6.274.0's own verify block asks him to press ⇪4 and then run this
  exact command — so that block had been un-runnable since it shipped.
  GENERAL: an instrument that can RAISE is worse than one that lies,
  because a lie still leaves a line to read; every report in this config
  formats its values through something that answers rather than throws.
  🔑 THE FIX IS AT THE READER, NOT THE WRITER, and that is the whole
  judgement. THREE report lines read a stored clock — size, area,
  scroll — and only ONE is fed a float; the other two are integers by
  luck, because their writers happen to call os.time(). Flooring the one
  float writer fixes the instance and leaves the class exactly as
  fragile, so `shots.clockText` is PURE and is the one door all three
  ask. 0 (what the writer leaves when the clock could not be read) reads
  as "time not recorded", never as 1970 — a plausible wrong time in a
  report is worse than a sentence saying there is none.
  🧪 AND THE STUB WAS GENTLER IN A VALUE'S TYPE — 6.193.0 for the
  EIGHTH time and a genuinely new shape of it. The suite's
  `secondsSinceEpoch` answered the INTEGER 1000, which os.date accepts,
  so the check that renders THIS VERY LINE was green for eighteen
  releases. Every earlier instance was a missing method, a swallowed
  side effect or a wrong return VALUE; this is a number of the right
  value in the wrong REPRESENTATION. GENERAL: a stub must answer the
  provider's TYPE, not merely its value — int where macOS gives float is
  a hole with a tick beside it. Making the stub a float turned 23 checks
  red at once, which is the evidence this release rests on.
  🔒 A SOURCE SENTRY CLOSES THE CLASS (nothing in the module formats a
  clock by hand, comments stripped per 6.262.0) — and its FIRST version
  could never have matched, because the needle carried doubled percent
  signs into a plain find. The mutation is what said so: a sentry is not
  a check until a mutation has failed it.
  📏 NAMED, NOT SWEPT: 142 sites in this config store a
  secondsSinceEpoch value and 110 pass something other than os.time() to
  os.date; cross-referencing the two found exactly ONE live crash (this)
  and one false positive. The other modules are not swept — one change
  per release — but the cross-reference is the tool if a second appears.

- 🔁 A QUALIFIER THAT ONLY STOPS ON SUCCESS IS A LOOP (6.281.0,
  modules/screenshots.lua — LL, of two green pills in his menu bar:
  "those green icons just do something like loop and loop and loop like
  it's running OCR nonstop"). `shots.wantsName` refuses a file only once
  its NAME holds " — ", and `nameByText` writes a name only when OCR
  answers `code == 0 and text ~= ""`. There was no else. So an image
  with no readable words — a photo, a dark panel, a diagram — was never
  renamed, never remembered, and re-qualified on EVERY folder event, for
  ever, one `/usr/bin/shortcuts run "HS OCR"` process each time.
  🍏 EACH GREEN PILL IS A PROCESS, and the first answer was wrong because
  of it: a grep for `hs.menubar` found three text-only items of ours and
  said "neither pill is ours" — TRUE, and the wrong question. macOS draws
  one indicator per running `shortcuts` process. GENERAL, and it is the
  half to carry: **"not created by this config" is not "not caused by
  this config."** Ask what the SURFACE means before asking who drew it.
  ☁️ AND ONEDRIVE CLOSED THE CIRCUIT: reading a dehydrated placeholder to
  OCR it HYDRATES the file, a hydration is a write, and a write is
  another FSEvents event on the same file — the OCR re-triggering the
  watcher for the file it just OCR'd, with no outside input at all.
  🚨 THE ONE GUARD THAT COULD HAVE STOPPED IT ANSWERS A DIFFERENT
  QUESTION: `shots.own` is "did I WRITE this", not "have I HANDLED this",
  and it is set in four places, all files this module wrote. A OneDrive
  arrival can never be in it — so the guard could never fire for the
  exact population the watcher exists to serve. And `shots.watchCap` (20)
  bounds the QUEUE, not the work: 6.229.0's rule in a second module.
  🔑 THE FIX REMEMBERS FAILURES ONLY, and that is an economy rather than
  an oversight: a SUCCESS renames the file, the new name carries " — ",
  and wantsName refuses it for ever — THE RENAME IS THE MEMORY. Recording
  successes would spend a bounded table on keys that can never be looked
  up again and evict the word-less ones it exists to hold. GENERAL:
  before putting something in a bounded store, ask whether the system
  already remembers it somewhere that cannot be evicted.
  🚨 NOTHING RAN IS NOT EVIDENCE. `nameByText` answers `onDone(nil)` at
  TWO exits without spawning anything (no Shortcut on this Mac;
  `hs.task.new` refusing), and recording an attempt on either would mean
  one OCR outage permanently blacklists every file it touched, silently,
  for ever. The callback hands back a REASON now — named · no text · no
  name · failed · NOT RUN — and only a process that really ran counts.
  🧪 AND THAT CHECK PASSED WITH THE GUARD DELETED at first, because
  drainQueue turns an absent Shortcut away BEFORE nameByText is reached;
  the branch the guard really covers is a failed SPAWN, and only a check
  that makes `hs.task.new` answer nil bites (6.273.0 — when a fix lands
  on a line no mutation can kill, the line is not the finding, the
  missing check is). Same sweep: `ocrStarted` was asserted only against a
  number the test had set by hand, so deleting the increment passed. It
  is counted after `t:start()`, where a process really exists.
  🔎 AND THE REPORT COULD NOT SEE THE RUNAWAY, which is why "I don't
  know" was the only honest answer to "is it looping?" and why no number
  on his Mac could have proved it: `namedOnArrival` counts only SUCCESSES
  and `leftForSweep` only cap OVERFLOW, so a word-less image incremented
  NEITHER and the line read "named on arrival 0 · left for ⌘9 0" for as
  long as the loop ran. 6.196.1 broken inside the report built to keep
  it. It counts the OCRs themselves now, with a yield line (6.229.0) that
  never divides by a run that did not happen (6.230.0).
  🎵 ⌘9 records what it learns and is NEVER refused (6.231.0) — which
  also makes it the escape hatch for a file the watcher has given up on.
  📏 COST, NAMED: the set is in MEMORY. hs.settings writes the whole
  Hammerspoon domain on the main thread (6.228.0) and this folder is the
  one the watcher watches (6.229.0), so persisting it would put the
  burst-problem's fix inside the burst. A reload gives every word-less
  file `triedMax` fresh tries, once — finite, where what it replaces was
  not.
  📏 NAMED, NOT FIXED, each its own release: the screenshot editor's ⌘⏎
  writes "<name> (edited).png" into this folder and never claims it in
  `shots.own`, so every save of an un-named shot is one more OCR (the
  tried-set BOUNDS it, which is the test of whether a fix closes a class
  rather than an instance — but the unclaimed write is still a bug, and
  it is one line); `nameByText`'s task has no killer timer, so a hung
  `shortcuts` leaves `nameBusy` true and the queue never drains again;
  and `shots.watchFolder = false` does stop this loop (onFolderEvent
  returns) but not the FSEvents wake-up, because the pathwatcher is
  created inside setup() and profile settings land after — 6.228.0's
  `wm.enabled` shape, in a second module, and this module has no M.warm.

- 🗑 A DECISION THAT WAS RIGHT TWO HUNDRED RELEASES AGO IS NOT
  SELF-RENEWING (6.280.0, modules/vault.lua — LL, twice: "I don't
  understand why there is no delete. Can you fix this?" and "I have an
  ever growing entries list in Hamsidian … I don't have an x at the end
  of the line"). vault.lua's header has said "No file delete or rename —
  Finder and Obsidian do" since 6.172.0, when that was true of how he
  opened it. It is not a bug and it is not a gap — it is a decision, and
  nobody re-asked it.
  🚨 NEVER os.remove. An unrecoverable delete of his writing is the one
  failure in this config with no way back: every other rule here is about
  a tool degrading, this is the only one that can destroy what the tool
  exists to hold. The note MOVES to <Vault>/.trash — no permission (so
  the work Mac behaves the same; an osascript Finder delete is the
  obvious build and needs Automation permission IT may refuse, and a
  delete that works at home and fails silently at work is worse), already
  in `skipDirs` so it leaves every index at once, and ignored by Obsidian
  too. ↩️ `_G.vaultUndelete()`, ONE slot (6.199.0).
  🕰 `v.trashNameFor` is PURE and stamps the time and flattens folders:
  two deletes of one name colliding in the trash would make the delete
  unrecoverable again through the back door.
  🚨 THE ✕ IS ASKED BEFORE THE ROW IT SITS INSIDE — one shared handler,
  so testing the row first OPENS the note on the way to deleting it
  (6.272.0 exactly, where it PLAYED the track it was forgetting). By REL,
  never index.
  🔗 THE LINK COUNT COMES OFF v.links, NOT THE BACKLINK INDEX: that one
  is rebuilt from the scan and lists only targets the find has seen, so a
  freshly linked note reads as linked by nobody — the reassuring answer,
  wrong in the one direction that matters. GENERAL: when a count is a
  warning, take it from the ground truth, not from a cache that lags.
  🧪 Two checks could not bite until the FIXTURE changed: the escaping
  path was refused by "no such note" rather than by the bound (6.230.0 —
  pick the input where the two implementations must differ), and the
  "never os.remove" sentry went red on a healthy tree because the comment
  explaining the rule quotes the call it forbids (6.262.0 — strip
  comments, and assert the comment still exists so the sentry cannot be
  satisfied by deleting the explanation).

- 📓 A LEDGER THAT LIVES IN MEMORY CANNOT ANSWER "WHAT FAILED TODAY"
  (6.279.0, core/notices.lua + init.lua — LL: "Can you also create an
  error message log for any of my tools that fail? I can check this log
  at 4pm for a double verification"). `notices.degrades` is a Lua table,
  so every reload emptied it — and a reload is likeliest at exactly the
  wrong moment, because something broke and therefore something got
  edited. Each degrade appends a row to <Logs>/degrades-<Mac>.csv;
  `_G.todayReport()` reads it back.
  📎 APPEND-ONLY is a rule, not a convenience: an append cannot shrink a
  file, so no write-ledger row and no rewrite that loses yesterday while
  saving today. The reader takes the TAIL, never the whole file.
  🔁 THE LOGGER NEVER TAKES THE DOOR ITSELF — reporting its own failure
  through core.degrade calls itself for ever on the first unwritable
  disk (the mutation ends the suite in a stack overflow). It counts.
  ⏳ AND IT BUFFERS UNTIL IT KNOWS WHERE TO WRITE: notices.lua loads
  before §0.1 and is handed an EMPTY core table, so without the buffer
  every BOOT-TIME degrade — the ones worth having — would be missing.
  Bounded, NEWEST kept.
  🔎 THREE STATES (6.196.1) and it is the whole point: "✅ nothing failed
  today" is the most reassuring sentence this config can print and would
  be a lie on exactly the day the disk is full. No log yet · could not be
  READ ("unknown, not clear") · read and clean.
  🚨 EVERY EXIT CARRIES THE WRITE FAILURES — the first version returned
  early on an unreadable log and skipped them, in the one case where
  failing writes are guaranteed because it is the same disk. GENERAL: an
  early return in a report skips whatever the report appends at the end,
  and the branch that returns early is usually the broken one.
  🧪 The suite DIED instead of failing (6.186.0, seventh time): deleting
  the buffer leaves logQueue empty and indexing it ends the run with "0
  failed" never printed — which in a gate that reads the tail looks like
  a pass.
  📏 NAMED, NOT BUILT: the log is not yet a ⇪D source. One uni.sources
  row, its own release.

- 🔔 A TOOL THAT COMPLETES AN ACTION OWES YOU ITS OUTCOME, NOT ONLY ITS
  FAILURE (6.278.0, modules/scratch_pad.lua — LL: "for any tool that
  completes an action, like the 4pm send of Asana tasks from Hamsidian,
  how do I know if it didn't work? … I could lose important information
  if not"). A rejected send called `warn()` — `_G.diag.warn`, the Console
  and nothing else. 6.214.0's rule, from his own words, unpaid in the one
  place where not knowing costs him what he captured.
  🔑 ONE PLACE DECIDES WHAT IT SAYS (`sp.announce`) and the channels
  follow the OUTCOME, never the exit — six exits each printing their own
  sentence into their own channel is exactly how one came to be silent.
  sent → a short alert (SUCCESS IS VISIBLE TOO, or silence means both "it
  worked" and "it never ran" — 6.196.1 inside the instrument he relies
  on); skipped → Console only, so a quiet day never cries wolf (6.269.0);
  failed → the 🔔 door AND a notification AND a sticky flag.
  🕰 THE NOTIFICATION IS THE PERSISTENT HALF and it is the right answer
  rather than a new card: an hs.alert is gone in six seconds and a 16:00
  failure lands while he is in a meeting. notices.tell HOLDS it through
  Focus and delivers it when Focus ends. NOT forced past Focus.
  📌 AND THE FLAG OUTLIVES BOTH CHANNELS — away from the desk, Mac
  asleep, or macOS refusing the alert (6.274.0 counted three in eight
  hours). It clears only on a real send, because a flag that never clears
  is one he learns to ignore.
  🚨 THE TEXT IS NEVER DISCARDED: the day is stamped in the SUCCESS
  branch only, so a failure retries instead of reading as "unchanged".
  The mutation that stamps early fails three checks.
  🔎 AND THE QUIETEST CASE IS THE WORST: a schedule that never ARMS runs
  nothing, so there is no rejection to report and every other instrument
  stays silent while the day's captures sit looking sent. It takes the
  door too. GENERAL: when a scheduled action can fail, ask what happens
  when it never RAN — that state has no error to carry it.
  🧪 AND THE SUITE'S core STUB HAD NO `degrade`, so every module under
  test took its no-door fallback and the door was never exercised
  (6.193.0). 🧪 A section that reads a published global must drive the
  instance that PUBLISHED it: this suite loads scratch_pad five times and
  a section driving an earlier copy while reading the latest copy's
  report measures two objects and calls the disagreement a bug.

- 🔖 A MEMORY THAT IS WRITTEN AND NEVER READ IS NOT A MEMORY (6.277.0,
  modules/vault.lua — LL: "Opening and closing Hamsidian puts me back on
  Scratch 1 and not the note I was working on. If I had 1000s of notes, I
  would have to find that note each time … that's asking a lot of me").
  `openNote` has stamped `vault.lastNote` on EVERY open for releases;
  v.open() consulted it only `if not v.doc`, and v.doc SURVIVES hide()
  (the one line that clears it fires when a scratch TAB has been
  deleted). One press of ⇪N pins v.doc to a tab for the session and every
  ⇪3 after it renders that tab. 6.265.0's shape in a new module: the
  right answer one branch away, unreachable.
  🔑 EACH DOOR RESTORES ITS OWN SIDE — ⇪3 the last NOTE, ⇪N the tabs,
  unchanged. A single shared "last place" is the obvious build and is
  wrong: it puts ⇪3 back on Scratch 1 whenever the tabs were used last,
  which is the complaint. `v.goToLastNote()` is the ONE function and
  v.open()'s own restore calls it rather than holding a second copy
  (6.231.0).
  🚨 A REMEMBERED NOTE THAT IS GONE IS NOT RE-CREATED: openNote seeds a
  missing file by design, so restoring through it naively answers "you
  deleted that note" by writing it back into the folder holding his
  writing. Stat first, refuse, open on the list. Its own check, because
  the plausible wrong answer writes to disk.
  🔎 THREE STATES (6.196.1): nothing remembered yet · the note is gone ·
  restored. Until now all three looked like Scratch 1.
  GENERAL: when a feature "does not remember", check whether the write is
  happening before touching the write — a value stored correctly and
  consulted under a condition that is almost never true is the commoner
  bug and looks identical from outside.

- 🆓 A CARD THAT SAYS A KEY IS FREE IS MAKING A PROMISE, AND NOTHING WAS
  CHECKING IT (6.276.0, modules/numpad_layer.lua + power_tools.lua — LL,
  handed ⇪⇧pad. as available: "are you saying the . on the numpad is free
  because that is the music player. I'm concerned we're not doing good
  debugging, because if we are not and I introduce problems on my work
  Mac, that is a problem"). He was right. The music player has bound
  ⇪⇧pad. since 6.231.0; the same cards called ⇪⇧7 and ⇪⇧8 unbound while
  Bluetooth (6.216.0) and the QR reader (6.194.0) held them, and
  contradicted their own "taken" row four lines below.
  🔑 THE ANSWER EXISTED TWICE AND ONE COPY WAS MAINTAINED BY HAND.
  `_G.freeKeys()` has read the live registry correctly since 6.142.0 —
  its own comment says the list "is not written, it is READ" — and the
  ⇪/ cards typed the same answer out beside it. THE COPY IS DELETED, NOT
  CORRECTED: correcting four rows by hand buys exactly until the next key
  is claimed, which is the entire history of this defect.
  `pt.freeKeyData(bound, keymap)` is PURE (both are ARGUMENTS, so the
  gate moves the registry under the card — 6.239.0), `_G.freeKeys()`
  renders it, it is the `keys.free` service, and numpad_layer fills its
  rows in **warm()** — never setup(), because the registry is filled BY
  the modules as they bind and this one is order 13.5.
  🔎 WHY NOTHING CAUGHT IT, AND IT IS THE HALF TO CARRY: 6.196.0's
  cheat-sheet auditor joins a card's KEY COLUMN to the module that BOUND
  the key, so it can only speak about a row that names an owner — a row
  claiming a key is FREE names nobody, and there is no second side to
  join it to. 6.269.0 wrote down that such an auditor is blind to a
  MISSING A; this is the same sentence about a missing B. GENERAL: when a
  check works by joining two things, ask what it says about a row that
  has only ONE of them, and put a DIFFERENT instrument on that —
  widening the join is what makes an auditor cry wolf and get switched
  off. 🚨 AND AN UNVERIFIABLE 🆓 ROW FAILS THE GATE rather than being
  skipped: the sentry knows which modifier each 🆓 label means and a
  label it has not been taught is a promise it cannot check, which is
  exactly how this hole opened. Fail closed.
  🧪 AND TWO CHECKS WERE GREEN ON EVERY RELEASE THE CARD WAS WRONG, which
  is the sharper lesson: test_features asserted the literal "⇪⇧5 7 8" and
  the literal "Key available for use" — it compared the card to the same
  stale sentence the card was made of, so it was READING THE PROMISE
  RATHER THAN THE FACT. GENERAL, and it generalises past cheat sheets: a
  check that asserts the words a thing says about itself can never notice
  those words becoming false; assert the RULE against the SOURCE OF TRUTH
  (6.248.0, third time).
  🔎 THREE STATES (6.196.1): the rows ship reading "asking the key
  registry…", which is not "every key is claimed" (what an empty list
  prints) and not the answer. `M.freeState` + `_G.padProbe()`'s ⚠️.
  🚨 A MISSING KEYMAP IS NOT AN EMPTY KEYBOARD — written the obvious way
  round, a Hammerspoon that cannot answer about keycodes marks every pad
  key dead and the card says this Mac has no numpad. Unknown means "ask
  the registry as usual"; its own check, because the old code got this
  right by luck.
  🔌 AND THE TEST REGISTRY STOPPED BEING GENTLER THAN THE REAL ONE:
  test_integration's `service.provide` threw the provider away and
  answered every call with nothing, so nothing that ASKS a service could
  be exercised. It keeps the function and dispatches RAW now (6.273.0).
  📏 NAMED, NOT FIXED: ⌘⇧pad binds through hs.hotkey, not the ⇪ modal, so
  the registry cannot answer for it — `numpad.cmdShiftActions` stays its
  own truth and the sentry skips that one row BY NAME and says why.

- 🔌 A WRAPPER WHOSE SUCCESS AND FAILURE RETURNS DIFFER IN ARITY WILL BE
  READ WRONGLY (6.273.0, modules/anchors.lua + vault.lua +
  tests/service_registry.lua — LL, scoring 6.269.0's newly visible
  anchors card BLOCKED, pasted `note   : table: 0x77fdbff940`). A Lua
  table printed where a SENTENCE belongs is a value in the wrong slot,
  and that address named the whole defect in one line.
  🔑 `_G.service.call` RETURNS THE PROVIDER'S OWN VALUES, RAW — `return
  a, b, c` after its pcall, with NO status in front. anchors.lua's own
  helper answered `false, "not loaded"` for a missing provider (a STATUS
  in slot one) and passed the registry through raw on success (DATA in
  slot one), so all four of its call sites were written to the failure
  shape — the shape you see when you write the guard first — and read
  every value a slot late. It answers nil now, as the registry does.
  🚨 THREE OF ⇪⇧U'S FOUR LEGS WERE DEAD FROM 6.180.0, each failing into
  an answer that looks deliberate, which is why nothing ever looked
  broken: the front document never named (a Word document read as "the
  app only", on both Macs, for eighty-nine releases — the tool this file
  describes as reading "the front document via `docs.front`" had never
  read one); 🚚 move survival never resolving, with vault.lua's caller
  carrying the MIRROR bug (`anchors.resolve` answers ONE value and that
  site read two, so even a working resolver could not have been heard);
  and "📁 Link it into an existing note…" — the row in his photograph —
  always answering "No notes to pick yet" over a vault holding twenty.
  Plus every failed write reported as "Hamsidian is not loaded",
  whatever the cause, in the one line he would have looked at.
  🧪 AND THE SUITE INVENTED THE CONVENTION THE MODULE WAS WRITTEN
  AGAINST: `call = function(n, ...) return true, SERVICES[n](...) end`,
  under a comment reading "the service registry, exactly as init.lua
  publishes it". Two divergences, both invisible at a call site — it
  PREPENDS a status the real one never sends, and `return true, f(...)`
  truncates f to ONE value, so it could not hand back three at all. 106
  checks green for eighty-nine releases, certifying a module that could
  do one of its four jobs. `tests/service_registry.lua` LIFTS the real
  block out of init.lua's source (6.236.0's `_G.baseScreenPick`
  technique) so no suite retypes it; the moment this suite used it, SIX
  checks went red and named all four dead legs — which is the evidence
  this release rests on rather than a reading. GENERAL, 6.193.0 for the
  SEVENTH time and the costliest: A STUB THAT INVENTS A CALLING
  CONVENTION DOES NOT MERELY MISS THE BUG, IT CERTIFIES IT. And when a
  comment claims a stub matches the real thing, DIFF IT — 6.269.0's
  grep-for-the-check, one layer out.
  🚫 NO SYNTACTIC SENTRY, written and taken out again: "no call site
  binds a leading ok" FAILED on correct code, because `vault.link`'s own
  first value IS a boolean. A grep cannot tell a status the provider
  RETURNED from one the caller IMAGINED, so it would have gone red on a
  healthy tree and been switched off inside a week (6.269.0: a new
  instrument is measured against the healthy case first). The lifted
  registry closes the class instead — a wrong-convention site now fails
  a FUNCTIONAL check, which needs no maintenance — and a gate sentry in
  test_integration refuses any suite that prepends a status again.
  🔎 THE LEGS ARE COUNTED APART ("named : N browser tab(s) · N
  document(s) · N app only · last: …"), with a THIRD state that says so
  when every press has fallen back to the app name: "the app only" is
  both a legitimate degrade and the only thing this tool could ever say,
  and no number in the old report could tell those two apart (6.196.1).
  🧪 AND THE MUTATION SWEEP FOUND A TENTH DEAD LINE. Restoring vault.lua's
  mirror bug failed NOTHING: 🚚 move survival had never been driven, because
  test_vault never stubbed `_G.service` AND its hs.fs had no `attributes`,
  so `gone` was false on every path and the branch was unreachable. 6.193.0
  twice in one branch. It is driven now, both ways — a resolver that answers
  and one that does not. GENERAL: when a fix lands on a line no mutation can
  kill, the line is not the finding, the missing check is.
  🔌 AND A SUITE WITH A FAKE io.open CANNOT LIFT ANYTHING. test_vault
  replaces io.open before loading the module, so the helper read no
  init.lua, fell back to its own stand-in — whose `has()` answers false —
  and the four new checks passed while testing NOTHING. The helper takes an
  `opener` now and every consumer asserts `reg.src ~= nil`. GENERAL, and it
  is the sharper half: A FALLBACK THAT KEEPS A TEST GREEN WHILE
  DISCONNECTING IT IS WORSE THAN A CRASH — a stand-in built so a mutation
  fails a check instead of killing the run (6.186.0) must still be ASSERTED
  against, or it silently becomes the thing under test.
  🗳 AND THE TEST PLAN'S OWN FINDING, from the same report: step C1 said
  "press ⇪⇧U with a document or browser tab in front" and he pressed it
  over Transmission, then could not score what he saw. A STEP THAT DOES
  NOT NAME ITS SETUP CANNOT BE SCORED — and a section headed "for your
  eyes, not a test" was scored anyway, because everything inside a
  numbered document reads as a step. Questions go in their own lettered
  block, marked as answers wanted rather than steps to run.

- ⏲ A WINDOW THAT HIDES ITSELF OWES A WAY BACK THAT DOES NOT DEPEND
  ON THE THING IT HID FOR (6.255.0, modules/screenshot_editor.lua +
  screenshots.lua — LL: "Add a delayed screenshot feature with a delay
  of 5 seconds"). ⌘D gives him five seconds to arrange the screen and
  lands the WHOLE screen on the shot as an image note, through the same
  door ⌘V and ⌘A use (`ed.pushImage`).
  🪟 THE EDITOR GETS OUT OF THE WAY, and that is not a nicety: a
  full-screen grab taken with this window open is a picture of this
  window. ⌘A can be worked around by moving the editor; a whole-screen
  shot cannot.
  🚨 AND A HIDDEN WINDOW THAT NEVER COMES BACK IS HIS WORK GONE — nothing
  is deleted, the page is still live, but a panel he cannot see is
  indistinguishable from one and no key reopens it. THREE RULES, each
  with its own mutation: the BELT is armed BEFORE the window hides
  (6.246.0's ordering) in its own held slot (6.196.1) and returns it at
  the countdown plus `delayGraceSecs` whatever happened; a Mac that
  cannot arm that timer DOES NOT HIDE AT ALL (a shot containing the
  editor is a bad picture, a window that cannot come back is lost work);
  and a belt return takes the 🔔 door and is COUNTED APART from a capture
  that failed — "never answered" and "answered with a failure" are
  different faults. GENERAL: any panel in this config that hides itself
  to get out of a capture's way owes the same three.
  🔑 THE PAGE IS GIVEN THE NUMBER: the button's LABEL is written from the
  same `ed.delaySecs` the capture is asked for with, so the check moves
  the config and requires both to follow (6.239.0).
  📏 ONE VERDICT, TWO CALLERS: `shots.captureVerdict` is PURE and both
  the area grab and the screen grab ask it. A zero-byte file with exit 0
  is a FAILURE — screencapture writes one (6.213.3 caught it doing exactly
  that), and a caller handed that path opens an empty image.
  🗑 A `delay < 0` clamp was written and taken out again: its only reader
  is `delay > 0`, so no mutation could fail it — 6.199.0, THIRD time.
  🔎 `_G.screenshotEditorReport()` (the module had none).
  🖥 6.256.0 — ⌘F IS THE SAME BODY WITH THE COUNTDOWN TAKEN OFF, and
  :hide() IS NOT INSTANT: macOS takes the window off screen on its own
  turn, so a screencapture asked for on the next line photographs the
  editor — the bug the feature exists to avoid, reintroduced by the fix
  for it. With a countdown screencapture's own -T covers the gap; without
  one nothing does, so `hideSettleSecs` (0.4) is a held timer in its OWN
  slot between the hide and the shutter, the belt covers the beat too,
  and a Mac that cannot arm it shoots anyway (a picture with the editor
  in it beats no picture). `ed.grabPlan` takes `needDelay` as a
  PARAMETER, never a second plan: a countdown of zero is a broken ⌘D and
  a perfectly good ⌘F.
  🚨 AND CLOSING THE EDITOR MID-CAPTURE TEARS IT DOWN — 6.255.0's wart,
  found building its sibling: ⇪⇧1 on another shot calls close(), which
  left `hidden` set, so the belt alerted "never answered" over an editor
  HE had closed. GENERAL: a feature holding two timers and a flag owes a
  teardown to every door that can end it.
  🖼 6.258.0 — ⌘O LOADS A PRIOR SHOT AND THE CANVAS GROWS (LL: "Allow me
  to load a prior screenshot on to the current screenshot and grow the
  canvas so that I can see both"). GROW, NOT PASTE: ⌘V/⌘A put an image
  ON the shot at 40% width, which is "point at this"; this makes ROOM
  and draws the loaded shot at its own size.
  📏 THE ORIGINAL NEVER MOVES — it keeps 0,0 — and that is the rule the
  feature turns on: every note, blur, arrow and counter is stored in
  CANVAS coordinates, so the origin is what stops a grow dragging his
  marks off the things they point at. Centring the narrower shot looks
  tidier and moves all of them.
  🧭 IT GROWS ALONG THE SHORTER SIDE (`ed.growAxis`, PURE): two wide
  shots stacked is nearly square, side by side is a 5120-px strip. That
  is 6.252.0's rule the other way up — there the LONGER side splits,
  because there the question is precision and here it is fit. A tie
  grows sideways, stated rather than accidental.
  📐 `ed.growPlan` is PURE and carries the edges: a WIDER shot widens the
  canvas rather than being cropped, a negative gap is clamped (overlap is
  the one thing this must never do), a named axis wins and an unknown one
  falls back to the rule. 🪟 `ed.windowSizeFor` is LIFTED out of ed.open,
  not copied — two copies of that sum is how a window that opens right
  comes to resize wrong (6.231.0).
  🪟 THE PAGE SAYS HOW BIG IT IS (6.238.0 again): Lua plans against the
  size the page reported, with the file's size at open as the fallback,
  and the report tells the two apart. The size just asked for is a BELT
  for a second ⌘O — asserted BY DOING a second ⌘O, because "the number
  is now 2892" passes with the belt deleted (6.212.0). ↩️ ⌘Z undoes a
  whole grow and the undo row carries the old PIXELS, because assigning
  a canvas's width destroys them.
  🔒 `ed.imageURIok` is the ONE door both addImage and growTo ask, and a
  grow NEVER shrinks — a plan smaller than the canvas means the two
  sides disagree about this page and obeying it throws his work away.
  🔌 The folder is listed by the module that owns it (`screenshots.list`
  is published now); the shot he is editing is not offered.
  🧪 AND THE CANVAS STUB KEPT ITS PIXELS THROUGH A RESIZE, which a real
  canvas does not — so "⌘Z put the pixels back" passed with the
  putImageData deleted. 6.193.0 in a PROPERTY rather than a method.
- ⌨️ TAKING THE KEYBOARD ACTIVATES HAMMERSPOON, AND THAT IS THE PRICE
  (6.251.0, modules/music_player.lua — LL: "I have to click on it to make
  it the focus to use the space bar … even if I hide it and bring it
  back, it's not the active window"). 6.225.0's rule, unpaid here:
  bringToFront RAISES, it does not make KEY, and only a key window is
  handed the keyboard — so the card's own ↑↓ / space / ⏎ / ⌘1–9 / ← →
  handler was there all along with nothing routed to it. The third step
  is Lua's: focus the hswindow off a HELD timer in its own slot, bounded
  by `focusTries`, stopping the moment it IS key; no hswindow → ONE
  attempt (retrying cannot make key a window that cannot be named);
  closing the card tears the chase down.
  ⚠️ THE COST IS NAMED IN THE REPORT: focusing a Hammerspoon window
  activates the APP, so an open Console comes forward with the card —
  the same mechanism as his "the Hammerspoon console jumps to the front
  and I'm not sure why". `takeKeyboard = false` is the switch. ANY panel
  in this config that wants the keyboard pays this; say so rather than
  letting it look like a second bug.
  🧪 The stub had no :hswindow(), and its focus() must MOVE the focus or
  "it took the keys" is unreachable — FIFTH getter-only stub to hide a
  feature here. And TWO mutations landed on paths that never run (hide()
  stopping a chase already over; a second stop further down), so the
  checks were rewritten against the path that RUNS: close the card
  mid-chase, and assert the timer object is GONE, not "nil or stopped".
- 🔤 A BOX THAT REFUSES A CHARACTER MAY NEVER HAVE BEEN OFFERED ONE
  (6.250.0, core/cheatsheet.lua — LL: "When I search the cheat sheet, I
  can['t] search punctuation and I should be able to do this"). The sheet
  is a wall of ⇪\ ⇪' ⇪/ ⇪; ⇪[ ⇪] ⇪- ⇪= and not one could be typed into
  its own search box: the claim loop was `a-z0-9` plus space and delete,
  full stop, so those keystrokes went to whatever was behind the sheet.
  🧨 AND THE FILTER WAS ALREADY SAFE — `cheatSheet.matches` has passed
  find()'s `true` since it was written, with a comment naming these very
  characters as pattern operators. The half that would have THROWN was
  right years before the half that would have TYPED existed. When a
  feature "rejects" an input, ask whether it ever receives it.
  📋 `cheatSheet.punctKeys` is DATA ({key, plain, shift}), so the gate
  reads the map and the loop is four lines. A DIGIT row carries only its
  shifted symbol — the bare key is claimed by the a-z0-9 loop and
  binding it twice is "two objects on one key, one of which nothing can
  disable". ⚠️ The shifted half assumes a US layout; a bind that fails is
  COUNTED and NAMED in the Console, and the plain half (what every ⇪
  combo is written with) does not depend on the layout.
  🧪 The stub's allow-list of bindable keys is deliberately NOT read from
  punctKeys — a guard that reads itself from the thing it guards cannot
  notice a new row — so a CHECK joins the two instead.
- 🗓 A LABEL THAT RESTATES WHAT IS UNDER IT IS OCCUPYING A BAND
  (6.249.0, modules/mini_calendar.lua — LL: "Doesn't need the 'September
  2026 → November 2026' label and the ‹ Today › should go there — that
  month label should be gone so that Today is right above the large date
  text"). The range line said in one 20 pt string what the three month
  titles under it already say, in the one band that could hold the
  navigation instead.
  🔑 ONE LEFT EDGE, his sentence as arithmetic: `L.textX` is where the
  big date is drawn AND where the cluster starts, so "above the large
  date text" cannot drift into two numbers kept in step by hand — and
  the check compares the DRAWN button to the DRAWN date, never the
  layout to itself.
  📐 `headerH` was 56, sized for a title that no longer exists; it is
  `btnH + 20` now and `btnY` falls out of it. 494 → 486 pt. 6.244.0's
  rule one band further in: a height that is a sum cannot go stale, and
  a height that is a literal already has.
  ✂️ `cal.navButtons(L)` is PURE and answers the buttons as DATA; the
  drawing and the hit boxes come from that one list in one loop, so they
  cannot disagree about where a button is — the mutation that lays the
  draw out by hand passes every layout check and fails the one that
  reads the canvas.
- 🌓 TWO JOBS ASKED OF ONE NUMBER CANNOT BOTH BE RIGHT (6.248.0,
  modules/mouse_grid.lua — LL: "make the boxes less translucent so I can
  read the letters easier, then on first key press make the box 100% see
  through"). The grid's scrim was ONE alpha doing two things: the first
  draw is a READING surface (three letters a cell over whatever was on
  screen) and after a keystroke it is an AIMING surface where the
  darkening is only in the way. `scrimAlpha` 0.30 → 0.55, and
  `scrimAlphaTyped` = 0, which is his "100% see through" and not a taste.
  `grid.scrimFor(typed)` is PURE, answers the alpha AND why, and BOTH
  draw sites ask it (gridElements and scrimOnly) so they cannot drift;
  backspacing out brings the reading wash back and has its own check.
  🧪 THE OLD CHECK ASSERTED THE LITERAL 0.30 — written for a real rule
  (coverage, never brightness: an opaque grey hides what you are aiming
  at) and asserting a constant instead, so moving the number failed a
  check with nothing to say about the change. It asks the RULE now, and
  the numbers are proven by MOVING the config and requiring the drawing
  to follow (6.239.0).
  🗑 AND ONE GUARD WAS WRITTEN AND TAKEN OUT AGAIN: scrimAlphaTyped in
  the layout cache's key. It affects nothing cached — both scrims are
  built inside redraw() — so the mutation removing it passed every
  check, and a guard no test can fail is dead code with a comment on it
  (6.199.0). SECOND time this project has made that call on purpose.
- 🏃 A HANDLER WIRED AS ITS OWN repeatfn PAYS FOR EVERYTHING IT DOES AT
  THE KEY-REPEAT RATE (6.247.0, modules/mouse_grid.lua — LL: "holding
  down the arrow key should repeat about the same cadence as holding
  down arrow key in a text box"). `nudge` is bound as pressedfn AND
  repeatfn, and it called showBox + showCrosshair, each of which DELETED
  its canvas and built a new one: two NSWindows created, eleven element
  tables marshalled through LuaSkin and two windows ordered in, PER
  KEYSTROKE, on the main thread — 6.228.0's cost, inside the handler for
  the key being held. `grid.accelFor` was never the bug; 6.195.0 raised
  the DISTANCE and he is describing the RATE.
  🔎 CHECKED IN THE SOURCE, FILE NAMED (6.233.0's rule about an
  IMPLEMENTATION this time): extensions/canvas/libcanvas.m's
  `canvas_topLeft` (line 2842) is a SETTER as well as a getter and does
  one thing — `[canvasWindow setFrame:display:YES animate:NO]`. It
  refuses only for a canvas used as a SUBVIEW, and that refusal is a
  THROW, so it is caught and falls back to the rebuild.
  ✂️ `grid.canMove(prev, want)` is PURE: everything but x and y must
  match, in BOTH directions — pairs() cannot see a nil, so a key in one
  table and absent from the other is a difference only the loop from
  that side can catch, and both cases are real (the badge loses a hint
  on a nudge after a snapped landing, and gains one the other way).
  🎯 THE BADGE IS NOT ALWAYS MOVABLE: it is clamped into the display, so
  at a screen EDGE its rings move INSIDE the frame while the pointer
  keeps going — rx/ry ride in the comparison and that draw rebuilds, and
  the check drives the pointer into the clamp to prove it. A RESIZE
  (⌥+arrow) rebuilds too: the elements are canvas-relative.
  🔎 COUNTED APART on the report's "canvas :" line, because a release
  that claims it stopped rebuilding must PROVE it on his Mac: moves
  climbing while rebuilds stay flat is the claim; nothing moving is this
  release doing nothing, quietly (6.241.0), and it prints a ⚠️ naming
  topLeft rather than a row of numbers that reads like health.
  🧪 The stub had no :topLeft at all, and a getter-only one would have
  passed every "it moved" check while moving nothing — FOURTH time that
  shape has hidden a whole feature here. GENERAL: a handler that is its
  own repeatfn may redraw, but it must not REBUILD; ask what actually
  changed, and move what can be moved.
- 🎯 A CACHE REFRESHED FOR THE NEXT CALLER IS A ONE-STEP DELAY LINE
  (6.246.0, modules/universal_actions.lua — LL, with a screenshot:
  "shouldn't this be working on the blue line file?"). ⇪⇧A named the
  file he had selected BEFORE, every press, and it was not a race: 
  `ua.finderSelection()` returned the LAST answer and merely STARTED a
  refresh for the NEXT press, so a cache older than `selectionSecs` (2)
  was guaranteed on any press that follows a selection. Its own comment
  said "the staleness window is one press wide" — true, and the bug
  stated as a feature. ONE PRESS WIDE IS ONE PRESS WRONG.
  ⚠️ THE OBVIOUS FIX IS THE ONE THAT ABORTED THIS MAC: an in-process
  read is 6.65.1's crash (an Objective-C exception unwinds past pcall),
  and bulk_rename's synchronous read pays a 3 s beachball ceiling. So
  THE PRESS WAITS FOR THE ANSWER — still out of process, still async,
  and the panel is BUILT IN THE CALLBACK. `ua.readPlan(now, at, secs,
  canTask)` is PURE: open · wait · blind, with why; a NEGATIVE age is a
  clock that went backwards (a Mac waking from sleep), never freshness.
  👁 WHEN IT CANNOT RE-READ, THE TITLE SAYS SO — "⚡ old.docx · could not
  re-read the selection", in the line he is already reading to decide
  whether the panel has the right file (6.203.0's rule: the refusal is
  drawn where he is looking, never in an alert under the window).
  ⏱ BOUNDED THREE WAYS, because a hyper key that opens nothing is worse
  than one that opens the wrong thing: a watchdog (`waitSecs` 1.5) in
  its OWN slot (6.196.1) armed BEFORE the read is asked for; a Mac that
  cannot arm one opens blind rather than waiting on an answer nothing
  would end; and a second press while the first waits is the SAME press.
  🚨 AN ANSWER HANDED BACK BECAUSE A READ WAS ALREADY IN FLIGHT IS NOT A
  FRESH READ — `ua.refresh` short-circuits when a task is running, so
  `done(paths, FRESH)` now, and only the real callback passes true.
  🔎 `_G.universalActionsReport()` (the module had none, which is why a
  photograph had to do the diagnosing): a REFUSED read — Finder
  scripting off, an Automation prompt unanswered — exits non-zero and
  looks EXACTLY like "nothing is selected" downstream, so it is counted
  apart with osascript's own words. GENERAL: when an answer must be
  current at the moment of a keypress, the keypress waits for it —
  bounded, and saying so when the bound bites.
- 🔖 hs.chooser DROPS THE SELECTION ON EVERY :choices() (6.227.0,
  modules/clipboard_history.lua — LL on ⇪⇧V: "I'm returned to the top
  after a selection multiple times … until I get out of the search box, I
  can't select items"). Those are ONE bug: `reopenEdit` re-rendered with
  "" (wiping his search) and the new list dropped the highlight, so after
  any tag or action the next keypress aimed at the first row of
  everything, and NOTHING was selected until he pressed an arrow. ANY
  picker in this config that rebuilds its own list under the user must
  read the QUERY back and put the ROW back. `clip.rowAfterRebuild` is
  PURE and clamps into the list; a row PAST THE END lands on the LAST one
  (a delete shortens the list and the eye expects the neighbour, never
  the top); `clip.restoreRow` never throws.
  ⤒⤓ HOME/END ARE A PLAIN hs.hotkey PAIR, ENABLED ONLY WHILE THE PICKER
  IS UP. They work in the cheat sheet because that is a webview;
  hs.chooser is an NSTableView with no key handler Hammerspoon exposes.
  Bound globally they would steal the key from every app, so they are
  enabled in showCallback and disabled in hideCallback, and they call
  `chooser:selectedRow(n)` against the list AS SHOWN.
  🧪 TWO STUB HOLES, THE SAME RULE TWICE (6.193.0): `selectedRow` was a
  GETTER ONLY so every restore call succeeded while moving nothing, and
  the stub's `:choices()` KEPT the selection the real one drops — so the
  reported bug could not be reproduced in the suite at all. A stub that
  forgets a side effect of the real provider hides the whole class.
- 🔤 "PUNCTUATION" CANNOT MEAN "NOT ASCII ALPHANUMERIC" (6.226.0,
  modules/ocr_engine.lua — the OCR junk filter, LL: "just remove single
  characters; anything two or more characters together is retained").
  Lua's `%w` is ASCII, so a Cyrillic, Greek or CJK word is nothing but
  punctuation to it and a filter written that way deletes every word of
  every non-Latin reading — while a bullet and an em dash are not ASCII
  either. `ocr.hasWordChar` strips the two UTF-8 lead bytes that carry
  ONLY punctuation and symbols — 0xC2 (U+0080–U+00BF · « » ° §) and 0xE2
  (U+2000–U+2FFF – — “ ” … • → ✓) — and calls anything still above ASCII
  a letter. And "one character" is `utf8.len`, never `#`: é is two bytes
  and one character. Both halves have their own mutation. OTHER RULES
  HERE: tokens split on SPACES ONLY (a newline is a line break — split on
  whitespace and a 40-line reading becomes one paragraph); a lone DIGIT
  is kept (a page number is data; the rule is about what OCR INVENTS);
  the filter sits at `appendRow`, the ONE door; a reading it empties is
  not written, ocr.record returns false, and it is COUNTED.
  `_G.ocrCleanHistory()` is a DRY RUN unless called with `true` and goes
  through the same rewriter ⇪⇧O uses so the image path rides through
  (6.187.0). TIER 2 (lUE, ido, dic — a dictionary vote, digit/letter
  splitting) is NOT built, on his own bound: if the method can introduce
  errors, singles only.
- 🎯 UP, IN FRONT, AND KEY ARE THREE DIFFERENT STATES (6.225.0,
  modules/ocr_engine.lua — LL on the 6.213.5 edit window: it "opens front
  but the caret is not in the box"). `bringToFront` RAISES a window; it
  does not make it key, and only key routes the keyboard — so the page's
  own `t.focus()` at load lands in a window that draws no caret and takes
  no typing until you click. THE THIRD STEP IS LUA'S:
  `ocr.focusEditorSoon()` focuses the hswindow a turn later and re-asks
  the page for the caret, in its OWN held timer slot (6.196.1), bounded
  by `editorFocusTries` (4 × 0.08 s), stopping the moment the window IS
  key; no hswindow → ask the page ONCE and stop (retrying cannot make key
  a window that does not exist); closing the box stops the chase; no
  hs.timer.doAfter → the box still opens and the state says "click the
  box once". RULE for any new panel that must be typed into: show →
  bringToFront → focus the hswindow off a held timer → ask the page
  again, and report which of those four states this Mac reached.
  🧪 The stub had no :hswindow(), no :evaluateJavaScript() and no
  doAfter, so the first version THREW and the suite DIED rather than
  failing a check. It plays a window macOS refuses to make key now.
- 📋 A COUNT WITH NO CLOCK AND NO REFUSALS BESIDE IT ANSWERS NOTHING
  (6.224.0, modules/clipboard_history.lua + init.lua §3.11).
  `_G.clipboardPollReport()` said "changes 3 · thrash rests 0" — which
  cleared the thrash breaker and told nobody anything else, because a
  poll five minutes old and one five hours old print the same line, and
  every refusal inside clip.add returned false in SILENCE.
  `_G.clipboardReport()` (queued by 6.202.0) now names the newest item
  and its time, how many are stored, how many were filed, and every
  refusal split by reason (already newest · over 1 MB · not text) with
  the last named and timed, plus saves ok/FAILED with the last failure's
  words — tellFailure alerts once per 600 s and nothing else remembered a
  failed write an hour later. THE POLL GAINED `startedAt` (so a count is
  printed with the minutes it took) and `suppressed` — the copies dropped
  by `_G.pasteboardSuppressUntil`, each one a copy he would look for in
  ⇪V and not find. THREE STATES THAT MUST NOT READ ALIKE, mutation-proven:
  no watcher running ≠ "0 changes"; a file not yet read ≠ an empty
  history; a poll that saw more changes than the module was offered says
  so with the innocent explanation (images go to OCR). RULE: when a
  diagnostic is asked for and its answer still does not decide anything,
  the missing half is a CLOCK or a REFUSAL COUNT — add both before
  theorising again.
- 🧊 A DRAG ENDS WHEN THE BUTTON COMES UP, WHEREVER THAT HAPPENS
  (6.222.0, modules/screenshot_editor.lua — LL: "if I miss a drag
  selection… the entire image looks selected by some overlay pop-up and
  no matter I can't deflect unless I escape and re-open"). A mouseup
  OUTSIDE the window is never delivered to the page — `window` is the
  right object to listen on and still not enough — so `drag` stayed set
  and every later mousemove went on resizing the shape: a Spotlight's
  veil grew to cover the whole picture and FOLLOWED the pointer with no
  button held, and the code that discards a too-small shape and pushes
  the undo row only runs when a drag ENDS. One `finishDrag(e)` is the
  only exit now, and a mousemove arriving with `e.buttons === 0` calls
  it. 📐 `buttons` IS A BITMASK; 0 is the only value meaning "nothing
  held" — `which`/`button` say WHICH button an event concerns and read 0
  for "left" on a plain move, so the same idea written with either ends
  every drag on its first move. Skipped where `buttons` is not a number,
  so a WebKit that does not send it keeps the old behaviour. RULE for any
  page in this config that drags: listen for the release, and ALSO treat
  "moving with nothing held" as the release.
- ⌘ A PANEL'S PAGE AND THE ⌘-DRAG PANEL MOVER BOTH WANT ⌘ (6.221.0,
  modules/screenshot_editor.lua + modules/window_move.lua). LL asked for
  ⌘-click to edit a mark in the ⇪⇧1 editor; ⌘ WAS ALREADY SPENT INSIDE
  THAT WINDOW and nothing would have said so — window_move's tap begins a
  window drag on a bare-⌘ left mouse-down anywhere inside a panel listed
  in `_G.movablePanels` and CONSUMES the click, so the page could never
  have seen it and the new code would have looked simply broken. THE FIX
  IS THE LISTED FRAME: `frame` in _G.movablePanels answers "where does
  ⌘-drag GRAB this panel", not "where is this window" — a panel whose
  page wants ⌘ narrows it to the strip it is happy to be dragged by
  (`ed.stripOf`, PURE and clamped; `ed.dragStripH` = 54, the same number
  the page's CSS measures #stage from, with a sentry that fails on
  drift). The editor is no less movable: its header has been the drag
  handle since 6.89.0. 🔎 RULE: there is no collision auditor for MOUSE
  modifiers the way there is for ⇪ combos — read window_move (and any
  other global tap) before promising LL a click.
  🖱 WHAT ⌘ DOES IN THE EDITOR: reaches a mark whatever tool is armed —
  a TEXT box opens its words at once, any other mark is selected — and
  A ⌘-CLICK THAT MISSES CREATES NOTHING, which is most of what "trouble
  editing the added items" actually was (aim at a box, land a pixel
  outside, draw a new arrow).
  🧪 And the check on that guard PASSED with the guard deleted: a fresh
  zero-length arrow is discarded on mouseup anyway, so counting notes
  after the RELEASE proved nothing. Assert at the mousedown. Same family
  as 6.220.0's ordering-vs-nesting: put the check where the forbidden
  thing would actually happen.
- 📐 A PANEL'S ACTION BUTTON LIVES OUTSIDE ITS SCROLLER (6.220.0,
  modules/task_form.lua — LL: "so that the items do not run down one
  long list and we can see the blue create task button"). ⇪T grew
  480 + 100 + 44 pt per Asana project field and clamped only at
  `sf.h - 40`, so eleven fields made a window taller than his screen
  with the blue Create button below its bottom edge. THREE PARTS, and
  the third closes the class: the project fields are a TWO-COLUMN grid
  with each label ABOVE its control (the 104-pt right gutter wrapped
  "| 🎯 ACD Strategic Principle |:" over four lines); `form.maxHeight`
  (760 → 1400 in 6.223.0) is a ceiling between the content and the
  screen; and the page is header / `#wrap` scroller / `<footer>`, with
  the button in the footer — no field count on any screen can push it
  away. 📐 6.223.0 RAISED THAT CEILING (maxHeight 760 → 1400, screenGap
  120 → 80) on LL's second telling — "the canvas needs to be bigger so I
  don't have to scroll. Sorry. That was what I tried to say before."
  6.220.0 read "we can see the blue create task button" as the whole ask;
  he did not want a scroller at all, and 760 was lower than his own form
  (~1,090 pt). RULE: when a fix answers the sentence and the complaint
  comes back, the NUMBER was the ask — and it is still a number, never
  "as tall as the display" (settings = { task_form = { maxHeight = 900 } }). `form.sizeFor
  (fields, screen)` is PURE (width, height, columns) and the gate proves
  all of it with no Mac; three mutations bite. `_G.taskFormReport()`.
  🧪 RULE, and it generalises: AN ASSERTION ABOUT NESTING WRITTEN AS AN
  ASSERTION ABOUT ORDER PASSES THE MUTATION IT EXISTS TO CATCH — "the
  footer comes after #wrap opens" was green with the button put straight
  back inside the scroller. Outside is a COUNTING question: the <div>
  and </div> between #wrap's opening tag and the footer must balance.
  RULE for any new panel: the send/save/confirm control is never inside
  the part that scrolls.
- 🔁 A RETYPE COMES BACK THROUGH THE TAP (6.218.0, modules/
  autocorrect.lua — LL's 6.216.0 "banshee"): hs.eventtap.keyStrokes
  and keyStroke POST their events; they reach every tap AFTER the call
  returns, as typing. A guard cleared on the line after the post
  guards nothing — core/coexist.lua's 6.76.0 comment claiming
  keyStrokes "has typed the characters by the time it returns" was
  the one wrong line, and `_G.withInjection` is still call-scoped.
  autocorrect's guard now drains BY COUNT (one keyDown per delete and
  per character, released on the last) with a held `injectHold`
  (0.3 s) timer as the belt; `acType` is the ONE place it posts keys
  (⇪Z too) and the source sentry holds it there. The text expander
  holds its own 0.08 s timer. ANY NEW TAP that posts keys does one of
  these, and its suite DELIVERS the posted keys back into the tap
  (test_autocorrect's typeWord is the shape) — a stub that swallows
  them passed this bug for 208 releases. The storm reached Chrome as
  Vimium keys: a stray "t" is a new tab, "o" the omnibar.

## Module contract

Each module: `M = {name, order, family, cheatsheet}` plus `M.setup(core)`.
Services via `core.provide`; hotkeys via `core.hyperAddShortcut`; panels via
`core.showPopup` (never a bare `:show()`); Esc handling via the
`_G.choosers.X` registry; diagnostics as `_G.<tool>Report()` globals;
binaries as UPPERCASE constants; chooser row values are scalars. Profile
`settings` overrides are applied AFTER setup into `mod.config` (init.lua's
"apply settings" block), so a settings override needs zero module changes.

Shortcut hints (6.163.0, modules/shortcut_hints.lua): hyperBind wraps every
pressed fn to call `_G.shortcutHint(combo, source)` AFTER the shortcut. A
NEW hyper key must be filed in `hint.groups` (combo → group) or the report
lists it under "no group" and it never gets a card. Ladder rung `hint`.
6.167.0: `hint.width`/`hint.fontSize` are for a screen `hint.scaleBase`
(1440) points tall; `hint.scaleFor(fullFrame)` scales the card UP on a
taller screen (LL's LG 4K at full points: ×1.5), never down; `hint.scale`
pins it (`num()`: "2" pins, 0/negative/word does not — report and drawing
share the test). The pointer ring (`grid.locateScaleFor`, mouse_grid)
follows the same rule. Any NEW fixed-size canvas gets the same treatment.
Boot lines meant for LL go through `print` (diag.say is verbose-only) and
run a turn AFTER setup if they show a settings-overridable value.

Row walker (6.170.0): any webview page that shows rows carries the
`rowKey/moveSel/rowAct` block (capture_pad, note_pad, scratch_pad —
copy it): ⌥↑/⌥↓ always, plain ↑/↓ when the caret is not in a TEXTAREA,
⏎/⌥⏎ → `rowAct(row)`. A NEW page with a list gets the same block.

Master log (6.169.0, modules/master_log.lua): READS the stores listed in
`ml.sources` and rewrites `master_log-<Mac>.csv` (fixed columns
timestamp,source,app,action,text,path,epoch) in slices; the FTS5 .db is
built by /usr/bin/sqlite3 in an hs.task and lives in ~/Library/Application
Support — NEVER in OneDrive. A new store that should be searchable adds
one `ml.sources` row (its columns mapped), nothing else. It never writes
a store. Open documents (6.169.0, modules/doc_memory.lua): AXDocument
per window, timed reads on held timers, `dm.apps` only; app_watcher's
quit panel asks `docs.openFor` / `docs.reopen` — keep that the only
reopen path.

Scratch pad — named HAMSIDIAN to LL since 6.253.0 (was the SCORP PAD from
6.171.0). ⇪N and ⇪3 open ONE window and it now carries ONE name: 📝
Hamsidian on a scratch tab, 🕸 Hamsidian on a note — THE ICON is what
tells them apart, and where a LIST must show both (⇪space's sources, the
⌃⌃ editor picker, the panic steps) the pad is "Hamsidian tabs", because
two rows reading the same word is a picker you cannot use. VISIBLE
STRINGS ONLY: the module id, settings key, `sp.*`, `_G.scratchPad*`,
`_G.scorpPadExport`, the store, the `scratch:` refs and the services are
untouched, and the COMMANDS keep their old names on purpose (6.214.0's
precedent). A source sentry in test_scratch_pad fails on any visible
"Scorp" left in the module, COMMENTS EXCLUDED — the history lives in
them. (visible strings only;
file, store, `_G.scratchPad` and service ids unchanged; 768×1024 portrait, window
alpha 1 via `sp.alpha`, 16 px text via `sp.fontSize`) — (6.164.0, modules/scratch_pad.lua, ⇪1): a webview on the
Capture Pad recipe — NO eventtap, NO AX/window reads, every timer held.
Keystrokes land in `sp.tabs` at once, the store (Logs/scratch/scratch.json,
write ledger) 0.3 s later. The 16:00 task goes through `_G.asanaSubmitTask`
with `extra.comment` (the only Asana path); keep it that way.
🗑 6.254.0 — THREE DOORS CLOSED, NOTHING DELETED (LL: "I don't need to
send these at 4pm. I don't need capture or append. I think those features
are redundant."). `sendDaily = false` (no 16:00 Asana task) and
`showKindRows = false` (no + 🗒 Capture / + ➕ Append rows in the window),
both settings-overridable. capture_pad and note_pad keep their modules,
stores and own routes; every note already written is on disk and still
found by ⇪space / ⇪D. `_G.scratchPadSend()` still sends by hand — that is
what makes it a switch and not a removal. THE SWITCH IS READ IN warm(),
the only place it can be (6.228.0: settings land after setup). 📋 6.201.1's
leak closes with it — the 📎 Collect tab rode into that task every day and
cannot now; the report says so where the old warning was read. 🚨 And the
PAGE has to ask: a `KINDROWS` flag the render ignores is 6.220.0's rule
again, so the check measures that both pushes sit INSIDE the guard.
6.165.0: 🗒 Capture / ➕ Append open as TABS in it (`sp.openKind`);
closing such a tab files through capturePad.add / notePad.fileAll — the old
modules keep their brains, `pad.viaScratch` / `np.viaScratch` restore their
windows. Kind tabs never enter the pad's own 4 PM task.
6.182.0 — 🔑 ONE DOOR: the pad is ⇪N (was ⇪1), the vault side is ⇪3, ⇪2
is the sequential copy, ⇪1 is FREE. 🗒 Capture and ➕ Append lost their
keys and became the "+ 🗒 Capture" / "+ ➕ Append" ROWS in the vault's
📝 SCRATCH NOTES section — same `openKind`, `pad.openHere()` keeps the
route for ⇪space/services, `np.laptopKey = nil`. RULE: a tool that lives
inside another tool's window does not also get its own hyper key.
📎 ⇪2 SEQUENTIAL COPY (6.182.0, REBUILT 6.201.0 — `sp.collect` /
`sp.collectFromSelection`): the grabs join into ONE block on the
CLIPBOARD and nowhere else. `sp.collect` is PURE — it appends to
`sp.collectSeq` and returns the joined block; no tab, no store, no
window, no alert, so the whole rule is provable without a Mac. It NEVER
raises the window, and the selection comes from `power.readSelection` —
do not grow a second selection reader.
🚨 WHAT IT DID UNTIL 6.201.0, because the shape recurs: it appended each
grab to a 📎 Collect TAB and put `t.text`, THE WHOLE TAB, on the
pasteboard. `sp.collectId` was remembered in the store so the tab
survived every reload and was never emptied; `sp.collectCount` was NOT,
so the alert read "1 grab" over a clipboard holding a year of them. TWO
halves hid it: a count that always looked fresh, over a block that never
was. LL, on discovering the pad had been collecting all along: "which by
the way, I had no idea was happening." His tab is NOT deleted — it is his
text; `sp.collectId` still round-trips through the store for exactly one
reason, so `_G.scratchPadReport()` can name that tab, say how big it is,
and say that nothing writes to it now.
🔑 THE RESET RULE (LL's pick of three): COPYING ANYTHING ELSE STARTS A
NEW SEQUENCE. `sp.collectContinues` asks macOS's change counter first,
CONTENTS as the degrade. DECIDED BEFORE THE SELECTION IS READ and a
source check asserts that order — power_tools BORROWS the pasteboard to
run ⌘C, so by the time the text returns the counter has moved and can no
longer say who copied last. A REFUSED WRITE DOES NOT END THE SEQUENCE (a
refusal never moves the counter, so it must read as "nobody else
copied"; the other way round, every refusal silently discards the lot).
🚨 NEITHER READABLE MEANS "NOT OURS" — the OPPOSITE default to
`pt.borrowIntact`, which treats the same unknown as "intact". Both are
right, and this is the durable half: A DEFAULT IS CHOSEN AGAINST THE
DAMAGE ITS OWN FEATURE CAN DO, never copied across as a house style.
There the last resort is 6.132.0's promise that your clipboard comes
back; here it is that ⌘V never pastes something you did not just grab.
🔎 ASK FOR THE ARTEFACT BEFORE THEORISING ABOUT THE MECHANISM. This was
blamed on the borrowed clipboard TWICE. 6.198.0 shipped a guard for it
that is real, works, and was never this bug — LL's own report proved the
guard working ("11× — 1 put back, 10 left alone") while the symptom
stood. A fifteen-agent adversarial hunt over every pasteboard writer
then returned ten candidates and ZERO survivors, which was correct: the
thief was not in the clipboard code. What nobody asked for two releases
was WHAT ⌘V ACTUALLY PASTES. One paste ended it. When a tool is accused
of producing the wrong output, get the output FIRST.
🚨 AND IT WAS IN THE 4 PM ASANA TASK TOO (6.201.1), which nobody had
looked for because nobody knew the tab was there: `sp.newTab` is called
with no `kind` (358) and `sp.dayBody` sweeps every tab with text and no
kind into the daily task (646), so the Collect tab and everything it
accumulated went to Asana every day from 6.182.0. 6.201.0 stopped
feeding the tab and CANNOT stop this without closing or deleting LL's
own text — so the report NAMES it and gives the keystroke (⌘W in ⇪N).
TWO RULES, both learned here: the fix for a leak is not to delete the
evidence, and A CONSEQUENCE YOU DECIDE NOT TO ACT ON IS ONE YOU ARE
OBLIGED TO NAME. One bug can have two outputs — LL complained about the
clipboard and never knew about the task, so "the reported symptom" is
not the same as "the blast radius": when you find what a bug wrote,
grep every reader of that store before calling it fixed.
🧪 And the test pasteboard had `setContents` alone — no `getContents`,
no `changeCount` — so the reset rule was untestable and the growing
block could not be caught by any mutation. THIRD time a stub gentler
than macOS has cost a release, SECOND in this module.

6.177.0 — ⌘⇧S in the ⇪1 / ⇪3 window EXPORTS the Scorp Pad's tabs (and
its history) as .md notes in <Vault>/Scratch, front matter + the text as
typed. `sp.exportAll` does the work; the vault only forwards the key and
says so when the pad is not loaded. The file name a tab gets is
REMEMBERED in the pad's store (`sp.exported`), so a re-export updates
instead of duplicating — and nothing on disk is ever READ to decide a
name (a OneDrive placeholder read blocks the main thread). The folder is
`_G.vault.dir` when the module is up, else the same path worked out from
core. `_G.scorpPadExport()`.

Anchors (6.180.0, modules/anchors.lua, ⇪⇧U — Hookmark's idea, natively):
identify what is in FRONT (browser tab via osascript in a held task with
a killer timer; the front document via `docs.front`, doc_memory's new
service and STILL the only AXDocument reader; else the app alone) → the
notes that already link it (grep -rlF over the vault, path then
BASENAME) → open one, or write the link into a new/chosen note through
`vault.link`. The link is PLAIN MARKDOWN under `## Linked` so Obsidian
opens it; there is no anchors store, by design. 🚚 Move survival:
`anchors.resolve` looks the basename up in ⇪D's file index; vault's
`follow` calls it when a file:// path is gone (and now handles file://
and unknown schemes at all — before 6.180.0 an absolute link was joined
onto the note's folder and could never open). It reads a title, a path
and a URL — never text, contents or the clipboard; the gate asserts that
against the source.

OCR log + ⇪space images (6.187.0): the log
`<logs>/image_text-<Mac>.csv` gained a THIRD column — the image the
words were read from — written QUOTED (`core.csvQuote`) because a
screenshot name may hold a comma. `ocr.record(text, path)`; the path is
OPTIONAL and every pre-6.187.0 row has two columns, so BOTH shapes are
valid forever and adoptLegacyFile guarantees one file holds both. FOUR
readers parse it and every one goes through a quote-aware splitter —
`ocr.parseRow` (core.splitCSVLine) serves ⇪O's `ocr.history` AND
`loadOCRHistoryRaw`; `uni.parseOcrRow` (the module's own `csvSplit`)
serves ⇪space. NEVER re-introduce `^([^,]+),(.*)$` here: it glues the
path onto the text, and `saveOCRHistoryRaw` rewrites the WHOLE file, so
one ⇪⇧O typo fix would strip the image off every row while write_ledger
reported the shrink as normal. The snapshot and the rewriter BOTH carry
the path. Two readers are unavoidable (⇪space cannot depend on the OCR
engine), so the gate runs both over shared fixtures and fails on drift
or on either being renamed away. `shots.recordText(text, path)` passes
`newPath or path` — the naming route RENAMES before it logs, and a
pre-rename path is a permanent dead link because a file carrying " — "
is never re-OCR'd. ⇪space's @images source lists one card per IMAGE
(newest reading wins), and its costs are bounded on purpose: thumbnails
are a main-thread decode (a download on an evicted file), so
`uni.thumbMax` budgets DECODES not rows, `uni.thumbCacheMax` caps a
cache that had no ceiling, a missing file is a stat never a read, and
⌥⏎ opens via /usr/bin/open in a task. `uni.hayFull` puts a bounded
slice of each row's FULL text in the haystack — before this only the
preview was searchable. RULE learned here: a check that asserts a
budget EXISTS does not assert that it BITES; two such checks passed
under the mutation they were written to catch.

Vault — named HAMSIDIAN to LL since 6.214.0 (his "Hammer-sidian"; visible
strings only: module id `vault`, settings key, `_G.vault`, `_G.vaultReport()`,
the folder <OneDrive>/Vault, the services and the `@vault` tag unchanged;
test_vault's last section holds both halves) — (6.172.0, modules/vault.lua, ⇪3): the FOLDER <OneDrive>/Vault of
plain .md files IS the database — no index file, no sidecar, so Obsidian
opens the same folder on either Mac. Index = /usr/bin/find (names) +
/usr/bin/grep (`[[links]]`) in HELD hs.tasks; the module NEVER reads a
note it is not opening (OneDrive placeholders block on read). Links:
`[[Name]]`/`[[Name|alias]]`/`[[Name#h]]` → <vault>/**/Name.md,
case-insensitive; files elsewhere as RELATIVE Markdown links (⌘K). Same
webview recipe as the Scorp Pad (no eventtap, held timers, text in Lua
per key, .md written 0.3 s later). Page JS has its own gate stage (3d,
test_vault_js — run on TWO dumps, plain and `pad`). ⇪3 is now SPENT.
6.173.0: the Vault window HOSTS the Scorp Pad — ⇪1 and ⇪3 open the same
window (`sp.host()` → `v.toggleScratch()` / `v.showScratch(id)`); a
scratch tab is `v.doc = { scratch = id, rel = "scratch:<id>" }`, its
text goes to `sp.setText` (never a file, never `v.links`), the pad keeps
tabs/store/history/filing/4 PM; `v.hide` calls `sp.onHostClose()` so
kind tabs still file. `v.sp()` is the ONLY bridge; `scratch_pad.viaVault
= false` restores the pad's own window (all its old code is intact and
still tested). 📌 pin = `v.pinned` in hs.settings "vault.pinned".
6.174.0: TAGS (`#tag` + front-matter `tags:`, nested `a/b`), TEMPLATES
(`<vault>/Templates/*.md`, `{{title}} {{date}} {{time}} {{date:FMT}}
{{cursor}}`; a body is read by /bin/cat in an hs.task, never on the main
thread), BODY SEARCH ⌘⇧F, TASKS ⌘⇧K/⌘L, outline, unlinked mentions,
⌘⇧E extract, ⌘⇧R random. The tag greps hang off the END of the scan
chain and are OPTIONAL — their failure never fails the links. A KILLED
RUN EXITS TOO: `stopTask` marks every terminate in a weak `dead` table
and `startTask`'s wrapper drops that late callback, or a kill is
recorded as a grep failure. `openNote` READS the file before deciding a
note is new — the index is asynchronous and a seed over an existing note
is data loss. A name that becomes both a file and a `[[link]]` goes
through `linkSafe`. KNOWN LIMIT: the index keys notes by NAME, so a root
`Daily.md` and `Templates/Daily.md` cannot both be indexed.
6.183.0 — 🔎 LIVE QUERIES: a ```dataview block in a note lists the
notes it describes in a 🔎 QUERY section of the right pane (`qbox` /
`qres`, hidden when the note has none), redrawn from `paneSoon` like the
outline. Obsidian's own Dataview grammar, the useful corner: FROM `#tag`
(nested a/b under a), `[[Note]]` (links TO it), `"Folder"`, AND/OR (AND
binds tighter) with `-`/`!`; SORT name|path ASC|DESC; LIMIT. It runs
ENTIRELY IN THE PAGE off the note rows — `notesJson` gained `l:` (each
note's outgoing link KEYS) for the `[[Note]]` term — so a query costs no
file read, no grep, no scan and sends Lua NOTHING. TWO RULES THE GATE
ENFORCES: the answer is drawn beside the note and NEVER written into it
(a written table would drift the file and duplicate Dataview's own
render), and an unsupported clause is NAMED in the pane while the rest of
the query still runs (`dataviewjs` is refused by name, never executed; a
query-looking line inside a plain code fence is text). A template never
appears in a result. The "/" menu writes the block with the caret on the
tag — LL does not type the grammar.
6.185.0 — WHERE, TABLE COLUMNS, SORT ON A FIELD, off the note's FRONT
MATTER. ONE GREP, TWO INDEXES: the scan chain's front-matter grep asks
for the opening `---` (not `^tags?:`) and reads the whole block, so the
same task builds the tags AND `v.fmOf` (rel → {key = value}); front
matter must start at LINE 1; bounded by `fmMaxFields`/`fmMaxLen` because
it rides into the page as `f:` on every render; tags are NOT copied in
(they are `g:`). `v.fmIn(text)` is the Lua twin for the OPEN note.
WHERE: `field`, `= != > < >= <=`, `contains(f,"x")`, AND/OR (AND
tighter), `!`; several WHERE lines AND. `file.name|path|folder` and
`tags` ask about the file. TWO RULES WITH TEETH, both mutation-proven:
a comparison is NUMERIC when both sides are numbers (else 10 sorts under
3), and a note WITHOUT the field never satisfies a comparison and sorts
LAST (missing, not zero — "" compares below everything and would join
every result). `_G.vaultReport()`'s "fields :" line has three states and
the third matters: a FAILED grep says so rather than reading as "no
fields". RULE learned here: match a function call BEFORE stripping
wrapping brackets — the negation stripper ate contains()'s own closing
bracket and the clause died silently.

6.186.0 — 🗂 THE BOARD (⌘⇧B), and THE ONE VIEW THAT WRITES. A
```kanban block (`BY <field>`, plus FROM / WHERE / SORT / LIMIT from
6.183.0-6.185.0, and `COLUMNS a, b, c`) draws the notes as Kanban
columns across the WHOLE window (`v.view == "board"`, body.board hides
#ed/#links/#side — the right pane is too narrow for columns). Columns
ARE the distinct values of the field; cards are the notes; it runs in
the PAGE off the same index, so still no read, no grep, no scan.
DRAGGING A CARD REWRITES that note's field: `v.setField(rel, key,
value)` → `v.withField(text, key, value)`, which is PURE and carries
every shape (no front matter, key present/absent, empty value =
remove, a `---` divider further down, an unclosed block, a colon or a
newline in the value). Bounds, all mutation-proven: never outside the
vault, never a non-.md file, never `tags`, never creates a missing
note, never a silent failed write — refusals are alerted, printed and
counted on `_G.vaultReport()`'s "board  :" line. The page NEVER writes
and never assumes: it posts `kmove` and Lua re-renders, so a refusal
puts the card back; the drop compares column VALUES, not element
identity (a re-draw mid-drag must not become a rewrite). The last
column is the notes WITHOUT the field and dropping there CLEARS it
(6.185.0's missing-is-missing, made draggable); COLUMNS draws empty
columns so there is somewhere to drag on day one, and a value it does
not name still gets a column — nothing vanishes. RULE learned here: a
throw inside a test section deletes the checks after it while the run
still says "0 failed" — a section that can throw wraps itself and
asserts its own check count.

6.175.0 (LL does not write Markdown): a FORMAT BAR over the editor
(`v.formatBar`), `wrapSel`/`blockAt` shared by the buttons, ⌘B/⌘I/⌘E and
the "/" menu — one behaviour, one place to test. "/" opens ONLY on an
otherwise empty line (a slash in a date or path must open nothing) and
its rows show the name AND the raw markdown. `mdHint(line)` names the
caret's line in the footer. RULE: any new syntax the vault understands
gets a row in BLOCKS, a branch in mdHint, or both — the teaching layer
is not optional decoration.

The histories ARE ⇪space (6.190.0): ⇪V and ⇪O open the unified-search
PANEL prefilled on `@clip` / `@ocr` rather than their own choosers —
⇪space already read those exact stores, so there is NO second renderer
to keep in step. ⇪⇧V and ⇪⇧O stay choosers on purpose (they EDIT and
DELETE; the panel is a reader). `clip.openInPanel` / `ocr.openInPanel`
return true only when it really opened, and ask `_G.service.has` at
PRESS time — never cached at setup, or a session where unified_search
failed to load strands both keys. Missing / refusing / throwing all fall
back to the chooser and say why (`clip.panelWhy`, `ocr.panelWhy`).
Rollback: `settings = { clipboard_history = { panel = false } }`,
`settings = { ocr_engine = { panel = false } }`.
Stores local + mirrored (6.190.0): init.lua's `localFirst` (off) moves
every store to ~/Library/Application Support/Hammerspoon/Logs — it ends
the OneDrive-placeholder main-thread stall class outright, and costs
liveness (the other Mac sees them every 30 min, not continuously).
🚨 IT NEVER SWITCHES ONTO AN EMPTY FOLDER: boot 1 stays on OneDrive,
says so, and seeds in the background; boot 2 uses the local copy —
`_G.localFirstState` is off / seeding / seeded / local and the report
names it. `bk.seedLocalStores` REFUSES a non-empty local folder (that
would overwrite this session's writes with the older cloud copy).
`bk.mirrorStores` rsyncs Logs → <backupDir>/Logs every `bk.mirrorMins`
(30) in a HELD task: a COPY, never a move, and NEVER `--delete` — a
store that failed to load must not erase its own backup. The VAULT
stays in OneDrive regardless (Obsidian opens that folder on both Macs).
NOT aliases (io.open/rsync/grep don't follow them) and NOT symlinks
(OneDrive won't sync through one).
🔒 SECURE INPUT CAN FALSIFY THE WHOLE BOOT REPORT (6.196.0,
core/capabilities.lua): macOS SECURE EVENT INPUT — a password field's
lock — stops EVERY event tap receiving keys and stops hotkeys
dispatching, system-wide, with no error anywhere. Chrome left it on and
took LL's keyboard for four hours while the Console said "All green ·
104 ⇪ shortcuts": the shortcuts WERE bound, Carbon WAS counting every
F18, the tap WAS enabled with 0 failures. The tell that it is not ours:
OTHER APPS break too (LL's ⇧Return died in Asana). Read at
kCGSSessionSecureInputPID via ioreg in a HELD hs.task (`-k IOConsoleUsers`
first, the multi-megabyte `-l` dump only as a fallback), NEVER on the
main thread. `_G.secureInputParse` is PURE and gate-proven against LL's
own ioreg line; **PID 0 means NOBODY** and must read as clear or it cries
wolf on every healthy Mac. Only a CHANGE is printed. The capability row
is INVERTED on purpose (a held lock = capability OFF) and both directions
are mutation-proven. `_G.secureInputReport()`, `_G.secureInputEvery` (60).
🚨 NEVER START A TASK FROM INSIDE ANOTHER TASK'S CALLBACK (6.196.1,
core/capabilities.lua) — not without stepping off it first. 6.196.0's
Secure Input probe held BOTH its ioreg runs in one global; the broad
fallback starts from inside the narrow probe's callback, so that
assignment dropped the last reference to the task whose callback was
RUNNING. hs.task's finaliser then tore down the NSTask and the callback
block underneath the live frame — a use-after-free that killed
Hammerspoon natively, with NO Lua error and NOTHING in the Console,
whenever a GC landed in that window. And it was not a rare path: on a
healthy Mac the narrow probe finds nothing EVERY time. Fix is both
sides — `_G.secureInputTasks[slot]` (separate slots, so starting one
never releases the other) and a HELD `_G.secureInputHop` timer so the
callback has RETURNED first. Asserted against the SOURCE, deliberately:
a stub hs.task is collected by nobody, so a functional test of this
passes just as happily with the bug in. Any new held-task chain gets
the same two rules.
🪜 6.262.0 — AND ⇪⇧U HAD BOTH HALVES, IN THE KEY LL NAMED (modules/
anchors.lua; LL: "Hammerspoon just crashed while I was using the
Hyper+shift+U feature I think... I'm not sure"). His log was the
RELAUNCH and carried no 🧊 stall-guard line, so the process went down on
its own rather than being killed for hanging. `anc.notesFor`'s grep
callback set `anc.grepTask = nil` AND started the next grep from inside
itself; `anc.identify`'s finish() cleared the osascript task's slot from
inside that task's callback. 🔎 THE DANGEROUS BRANCH IS THE ORDINARY
ONE, exactly as in 6.196.1: the second grep is the BASENAME needle and
runs only when the first found nothing — every ⇪⇧U on a document with no
note yet. 🪜 `anc.hop(slot, fn)` carries both halves: separate slots
(`anc.tasks.tab` / `.grep`) so starting one never releases another, and a
HELD doAfter(0) in `anc.hops[slot]` so the callback has RETURNED before
the next task starts or the slot is let go — nothing inside a callback
clears its own slot now. A Mac that cannot arm the timer still answers,
on the old path, and the report's ⚠️ OUTRANKS its count and stays there
afterwards (a missed hop is not forgotten the moment the next one
works). 🧪 The sentries read the CODE with comments stripped, because a
comment quotes the banned line (test_scratch_pad's rename sentry, same
reason). 📏 NAMED, NOT FIXED: vault.lua's scan `finish()` nils all four
task slots from inside a task callback (its chain is otherwise safe —
every task there has its own slot); and `anchors.grepTimeout` is a knob
nobody reads, so a hung grep is unbounded where the osascript read is
not. 🔎 A SUSPECT, NOT A VERDICT (6.198.0) — the `.ips` decides it; this
shipped anyway, because it breaks a rule we wrote after a native crash.
🚨 AND THE `.ips` ANSWERED: NO. BOTH OF HIS CRASHES ARE APPLE'S, AND
NEITHER IS ⇪⇧U (2026-09-19, two reports, 15:08:27 and 15:58:26 — the
second is the one whose relaunch boot log he pasted). NOT ONE Lua,
LuaSkin, NSTask or hs.task frame appears anywhere in either, on any of
36 threads. Both are UNCAUGHT OBJECTIVE-C EXCEPTIONS — EXC_CRASH /
SIGABRT, `abort() called`, through Hammerspoon's OWN SentryCrash
uncaught-exception handler — on macOS 27.0 BETA (26A5388g).
  🍫 15:08:27 IS THE MENU BAR: `-[NSStatusItemVariantSceneDelegate
  scene:willConnectToSession:]` → `-[NSSceneStatusItem _wakeStatusItem]`
  → `orderWindowFrontInAppKitOnly` → `_doWindowWillBeVisibleAsSheet:` →
  a notification into `-[NSRemoteView containingWindowWillOrderOnScreen:]`
  → `_CFBundleGetValueForInfoKey` throws. macOS connecting the app's own
  status-item scene, in AppKit's new scene machinery. Nothing of ours is
  on the stack and nothing of ours can be: we do not drive that callout.
  ✏️ 15:58:26 IS macOS'S OWN "DID YOU MEAN" BUBBLE INSIDE ONE OF OUR
  WEBVIEWS: `WebPageProxy::showCorrectionPanel` → `-[NSSpellChecker
  showCorrectionIndicatorOfType:…]` → `-[NSCorrectionPanel
  showPanelAtRect:inView:…]` → `NSPerformVisuallyAtomicChange` → rethrow,
  uncaught. The throwing code is Apple's; THE SURFACE IS OURS. Every
  textarea and contenteditable in every page this config draws asks for
  spell checking by DEFAULT, and our own autocorrect is already running
  over the same box — two correctors on one field, one of which is a
  beta-OS panel that aborts the process. `spellcheck="false"
  autocorrect="off" autocapitalize="off"` takes it out of the process
  entirely and costs nothing we want. Its own release.
  📏 SO 6.262.0 IS A CORRECT FIX FOR A REAL BUG AND IS NOT HIS CRASH —
  6.198.0's rule, third time, and this is the costly direction of it: the
  fix is right, both use-after-free shapes were real, and none of that is
  evidence. Its scoreboard row is NOT scored on this; the verify block's
  ⇪⇧U step is a regression test now, not a diagnosis.
  🔑 GENERAL, AND IT IS WHY THE ARTEFACT RULE HAS TEETH: READ THE CRASHED
  THREAD BEFORE BELIEVING A SYMPTOM'S NAME. "I was using ⇪⇧U I think…
  I'm not sure" names WHEN, never WHAT — and a guess offered with a
  hedge is still the thing a diagnosis will bend towards. Two crashes,
  two entirely different Apple subsystems, fifty minutes apart.
  🔕 AND NEITHER COULD EVER HAVE REACHED THE ⛔/⚠️ CONSOLE GATE, the
  error report or `_G.degradeReport()`: an uncaught ObjC exception aborts
  the process from inside AppKit. 6.208.0's rule ("a stall is not an
  error and can never reach them — which is why this lives outside")
  extends to this whole class, and the outside instrument here is the
  `.ips`, which is why 6.197.0 backs it up. Ask for it FIRST.
✏️ 6.263.0 — AND NO PAGE THIS CONFIG DRAWS ASKS macOS TO SPELL-CHECK IT
(nine modules, one attribute each; the rule lives in test_integration).
The 15:58 crash above is Apple's code on OUR surface: a `<textarea>` or a
text `<input>` asks to be text-checked BY DEFAULT, so every box in every
page here had it on, and vault.lua's note editor — the one he writes
paragraphs in — said `spellcheck="true"` outright. 🔑 IT COSTS HIM
NOTHING, which is what makes it a removal rather than a trade:
autocorrect.lua already corrects his typing in those boxes through the
tap, so two correctors were running on one field and one of them ends the
process. What goes is the red squiggle, which no rule here ever promised.
🚨 THE SENTRY READS THE CLASS, NOT THE TWENTY-TWO TAGS — a new input
added in six months brings the panel back and NOTHING FUNCTIONAL WOULD
NOTICE, because the page looks identical until macOS decides to correct a
word. Every file in modules/ and core/ is walked; any text-entry tag
without the attribute fails the gate. 🚨 AND THE FIRST SENTRY PASSED ITS
OWN MUTATION: a flat 200-character window let ⇪T's NEXT form field cover
for a bare one — a check about one tag satisfied by a different tag
(6.221.0, in a scanner). The window stops at the tag's own `>`, and the
fixture that bites is two ADJACENT boxes where only the second is
covered. GENERAL: a scanner with a fixed-width window is a scanner that
can be satisfied by its neighbour — end the window at the thing's own
boundary. 🧪 AND THREE CHECKS ASSERTED ADJACENCY WHERE THEY MEANT
STRUCTURE (`id="sd" type="date"` as one literal string) and went red on
an attribute inserted between two others; they pull out the tag carrying
the id and ask THAT for the type now. 📏 NO SWITCH BACK, and that is
stated rather than omitted: its only effect would be to re-arm a panel
that aborts the process, and 6.254.0's "one settings line brings it back"
is right for a door and wrong for a loaded gun.
🧪 AND THE GATE'S ONE WALL-CLOCK SUITE WAS PUT ON FIRM GROUND in the
same release, because it is what held 6.261.0's zip back: one package
gate run read `9993 checks (partial) · 1 stage failed` and every run
after was green. 10,079 − 9,993 = 86 = test_stall_guard's exact count —
a failed suite is not tallied, so ARITHMETIC NAMED THE SUITE. Eight
copies at once reproduced it (1 in 8) and its own log named the cause:
ON A LOADED MACHINE A FORK COSTS SECONDS — one log line's two timestamps
were FOUR SECONDS APART, and log() forks twice — and the script writes
guard.pid BEFORE `last=$(now)`, so a kill -STOP in that window is
invisible. Section H waits for the "started" line and one whole check,
then stops it and makes the beat stale while it is stopped; the pid poll
is 10 s, not 2, and says so where it fails. GENERAL: a test that drives
a REAL process against REAL seconds waits for it to be READY and puts it
into the state under test deliberately — and "it passed the second
time" is never the answer; the missing checks are an arithmetic
fingerprint that names the suite.
🔎 "NOT YET" AND "NEVER" MUST NOT READ THE SAME (6.196.1). The crash
above shipped because `checks` only rose when a probe COMPLETED, so a
probe that started and died read as "not probed yet, checks 0" —
identical to one never attempted, eleven minutes after boot. Count
ATTEMPTS separately from completions and say so when they disagree.
Any async probe reporting a state it has never successfully read owes
the same distinction.
👁 ⇪D HAS THE MOUSE AND A DETAIL PANE (6.204.0, modules/unified_search.lua):
a DOM mousemove over a row selects it (on MOVEMENT — a parked pointer
fires nothing, so the arrows scrolling under a resting hand steal
nothing; no scrollIntoView under the pointer), and the pane on the right
shows the highlighted row. THE FULL TEXT STAYS ON THE LUA SIDE: the page
sends `{a:'detail', id}` ONCE PER LANDING (`detailFor` — a rebuild that
keeps the same row asks nothing more) and `uni.answerDetail` pushes
`uniDetail(id, text, path, total, cut)` through evaluateJavaScript; the
page draws it only if that row is still the highlight. `uni.detailCut`
is PURE: `uni.detailMax` (12000, the chooser pane's number) in
CHARACTERS via utf8.offset, never mid-glyph — a Lua string that is not
valid UTF-8 never reaches WebKit, the script is dropped silently. A push
that fails (window gone, no evaluateJavaScript) is COUNTED as refused,
never thrown in the bridge callback, and the pane keeps the list's line,
which it calls a preview only when the row's `m` flag says it holds
more. `_G.unifiedSearchReport()`'s "pane :" line: never asked ≠ 0 drawn.
Window width = `uni.width + uni.paneW`; `settings = { unified_search =
{ pane = false } }` is the list alone. RULE learned here: one guard (one
ask per landing) had a check that passed WITHOUT it — a same-row
mousemove returns before the guard — until a mutation said so; the row
that bites is a keystroke that leaves the top match where it was.
🔦 AN IMAGE ENTERS THE EDITOR PAGE THROUGH ONE DOOR, AND THE DOOR
CHECKS THE SHAPE (6.213.0, modules/screenshot_editor.lua): ⌘V and ⌘A
both end in `ed.pushImage(url, w, h)` → evaluateJavaScript("addImage
(...)"), which refuses anything that is not `^data:image/%w+;base64,
[A-Za-z0-9+/=]+$` with a positive size — a script WebKit cannot parse
is dropped in SILENCE (6.204.0's rule, applied to a URI), and a quote
in a data URI would end the string literal. The screenshots module's
`captureAreaTo(cb)` answers by PATH, once, never the clipboard and
never the editor. Drawing ORDER is a rule: magnifiers (clean pixels) →
the one even-odd veil → every mark; redraw() and saveIt() both go
through `drawAll`, so the save cannot differ from the screen. Any
future thing that reads pixels goes before the veil; anything that
must stay readable goes after it.
🖌 A NEW EDITOR MARK IS A NOTE KIND, NOTHING ELSE (6.212.0,
modules/screenshot_editor.lua): line/oval/hl/count joined text and
arrow as entries in the ONE `notes` list — drawn in drawNote, hit in
hitAt, boxed in noteBox, snapshotted by the now-generic `snapNote`
(every numeric field), so move/undo/delete/save/Esc-keep need no new
code per kind. A box kind is drawn by a 'corner' drag that NORMALISES
x/y/w/h as it goes. Counter numbers are max+1, never count+1. The JS
harness's `load(shownW, {w, h})` exists because grab radii are image
pixels and a 40-px canvas cannot hold three badges apart — and the
line's "no arrowhead" row had to name the line's OWN lineTo, because a
mutation drawing it as text passed a row that counted any stroke (the
selection ring strokes too). A check that counts calls of a kind the
selection also makes is not a check on the note.
🚨 THE CEREMONY SCRIPT RUNS IN THE FOREGROUND, ASSERTS EVERY REPLACE,
AND THE GATE CHECKS THE HEADER (6.212.0, learned the hard way): the
6.210.0 and 6.211.0 release notes, init.lua stamps and GUIDE totals
were never written. The 6.209.0 script inserted its NEW IN block with a
bare `str.replace` whose anchor was already gone (the same script had
cut BOTH older blocks because 6.208.0's block had been placed under
6.207.0's instead of above it), so nothing was inserted and nothing
said so; the next two scripts then died on `s.index` of that missing
block — inside a `run_in_background` gate command, so the traceback
went to a task log and the gate, which never read the header, went
green. Three commits shipped code without words. RULES: a ceremony
edit is an ASSERTED replace (count == 1) and runs in the foreground
with its stamps grepped back before any gate starts; NEW IN blocks are
newest-first and the trailer names the third; and test_diagnostics now
enforces the header shape, so the gate fails instead of the reader.
🗓 TWO PANELS THAT SHARE A CORNER TALK THROUGH SERVICES (6.211.0,
pomodoro + mini_calendar): pomodoro.dock(rect) / pomodoro.undock and
calendar.frame, each side asking `_G.service.has` first so either
module alone is unchanged. The pre-dock spot lives on the pomodoro's
STATE (s.undockPos), never in pom.pos; undock refuses a second time
rather than moving twice; the calendar undocks BEFORE deleting its
canvas. Beside, not inside — the calendar's footer cannot hold the
card without a layout change of its own. A cheat-sheet row that
mentions ANOTHER tool's key uses a WORD in the key column ("calendar"),
never the bare combo — the 6.196.0 audit reads a bare combo as a claim.
🔊 THE POMODORO'S TONE IS PLAYED FROM THE TICK AND RESOLVED ON THE
KEYPRESS (6.210.0, modules/pomodoro.lua): `pom.toneTick` runs inside the
ticker's own pcall, at most once per `toneEvery`, only in the last
`toneSecs` of FOCUS, volume from `pom.toneVolume(left)` (PURE, clamped);
`pom.resolveTone()` is called in start() and remembers `false` — a Mac
without Submarine is silent and the report's "tone :" line says so.
The knobs are FLAT (toneOn/Name/File/Secs/Every/From/To/Break) because
the settings block assigns `mod.config[k] = v` — a nested table override
would replace the whole table and lose the rest. Any new sound in this
config follows the same shape: resolve once off a keypress, never in a
timer; `false` after a failed lookup; a report line with three states.
🍅 THE POMODORO CARD'S COUNT IS READ ONCE, ON THE KEYPRESS (6.209.0,
modules/pomodoro.lua): pomodoro_log-<Mac>.csv is in OneDrive and the
ticker paints every second, so `pom.todayCount()` reads via dayCounts
on ⇪⇧P only, keeps `pom.today = { key, completed, readAt }`, phaseEnded
adds one in MEMORY as it writes the row, and a new date re-reads once
— the suite counts io.open on the log across thirty ticks and wants
zero. The alpha is 0.90 idle AND alert on LL's word ("go 90% opaque"),
superseding 6.152.0/6.154.0; the vault's 6.181.1 rule applies — any
further "more/less see-through" is the settings line, not a release.
6.213.2 did exactly that: both machine profiles carry pomodoro =
{ alphaIdle = 0.30, alphaAlert = 1 } on LL's word ("solid when I go
over, about 30% when I move off") — the hover poll switches them.
🧊 A BEACH BALL IS WATCHED FROM OUTSIDE (6.208.0, modules/stall_guard.lua
+ tools/hs-stall-guard.sh): Hammerspoon writes the epoch second to
~/.hammerspoon/.stall-guard/heartbeat every 2 s FROM THE MAIN THREAD (a
held timer — that is the point: a stalled thread stops beating), and
warm() starts the script as a SECOND PROCESS (`nohup /bin/sh … &` via
hs.task; as LL, from LL's folder, NO sudo, NO launchctl, NO LaunchAgent —
the work Mac rule). Two readings in a row ≥ `sg.stallSecs` (60) stale,
checked every `sg.checkSecs` (10) — 20/5 until 6.213.1: a kill cannot
be undone, and this config is KNOWN to hold the main thread 29 s (the
4K stitch, the first Chrome export) and to open modal
hs.dialog.textPrompt dialogs whose effect on hs.timer is unproven, so
the rescue sits at ~70–80 s and a real beach ball is minutes — while
pgrep finds Hammerspoon → log,
kill -9, the hidutil UserKeyMapping reset (a hard kill leaves ⇪ sending
F18 with nothing listening — init.lua's own comment), `open -a
Hammerspoon`. THE NEXT BOOT ANNOUNCES IT ONCE (alert · notification ·
Console · notices), newest epoch remembered in hs.settings. RULES WITH
TEETH, each mutation-proven by running the REAL script on the gate's
Linux with kill/pgrep/open/hidutil stubbed through the SG_* overrides:
a wall-clock gap > 3 checks is SKIPPED (sleep, not a hang); a clean
quit/reload writes .stall-guard/quit — the module WRAPS
hs.shutdownCallback (init's ⇪ cleanup still runs) — and the guard exits
on it, the new boot's guard removing the marker; a newer guard's pid in
guard.pid retires the old one; three relaunches in ten minutes (counted
from the log's epochs, old lines do not count) → "gave up" + exit, and
the announcement names the fix; NOT RUNNING IS NOT STALLED and it never
launches Hammerspoon on its own. Setup writes the FIRST beat before any
guard can exist and the script sleeps a full stall after relaunching,
so a boot is never the next stall. A NEW hs.task-spawned helper follows
the same shape: absolute binaries, SG_*-style overrides so the suite
can run the real file, a pid file, a quit marker, a limit. The Console
question ("is it set to report accurate errors?") is ANSWERED, no code:
the ⛔/⚠️ gate, errorsReport and the early uncaught handler already do;
a stall is not an error and can never reach them — which is why this
lives outside.
🧻 ⇪5 SCROLLING CAPTURE KEEPS ITS RECEIPTS (6.206.0, modules/screenshots.lua):
LL's "Stitch failed — no slices decoded" was an assert at the END of the
run with no evidence behind it — the slice capture ignored screencapture's
exit code and stderr, appended the path file-or-not, and deleted the
slices. Now every slice records exit / first stderr line / file size in
`shots.scrollLast.slices`, the run stops at the first failure naming it,
failed slices are KEPT (dot-files), `_G.screenshotsReport()` repeats it
all, and the finished task stays in `shots.lastCaptureTask` while the
stitch runs off a held timer (6.196.1). THE CAUSE (6.213.3, named by
that report on its first run): "slice 1 of 4: screencapture exit 0 —
screencapture: cannot write file to intended destination, /Users/…/
OneDrive-Personal/2026 Screenshots/…". The slice was a DOT-FILE
(.scroll-slice-NN.png since 6.87.0) in the folder OneDrive's File
Provider owns, and screencapture would not write it there while every
plain-named capture into the same folder lands — so ⇪5 had never worked
with the folder in OneDrive, and "no slices decoded" was four files
never written. Slices go to `shots.sliceDir` now (~/Library/Application
Support/Hammerspoon/scroll-slices, plain names), decided once per run by
`shots.sliceFolder()`: exists → mkdir one level → the temporary folder →
stop before slice 1 and say so; a file in the way is refused. The
report's "slices :" line has three states. RULES: a temporary file this
config writes goes to a LOCAL folder, never a cloud-owned one and never
as a dot-file there; and the receipts paid for themselves on the first
run — an assert that names its evidence is the whole difference between
"no slices decoded" (three releases) and a fix (one evening).
🔎 ⇪space HAS `_G.unifiedSearchReport()` (6.196.1) — it was the one tool
here without one, which is why "2372 items indexed — does this seem
right?" had no answer. It names every store and its count, and a store
that FAILED to load reads differently from one that is EMPTY; `gather()`
REMEMBERS a failure in `uni.failed` rather than only printing it once,
so a source that broke at boot can be named an hour later. A total with
a store count beside it hides a store that quietly stopped contributing.
🚨 CRASH REPORTS ARE BACKED UP NOW (6.197.0, modules/daily_backup.lua):
the kit's `crashes` entry copies ~/Library/Logs/DiagnosticReports/
Hammerspoon* into RebuildKit/CrashReports — LL: "if my work Mac or my
home Mac get wiped, I will lose this information for you", and he was
right: that folder was the only copy, macOS prunes it, and the backup
took only LaunchAgents and Fonts out of ~/Library. No rsync here carries
--delete, so a pruned report survives in the backup. THREE RULES WITH
TEETH, all mutation-proven: the entry is FILTERED (`entry.only` →
`--include */`, `--include Hammerspoon*`, then a catch-all `--exclude *`,
IN THAT ORDER — rsync takes the FIRST filter that matches, so a catch-all
in front copies nothing, silently) and is never widened to the bare
folder (it holds every app's diagnostics and the destination syncs to
OneDrive); that filter is SCOPED to the one entry, because the same three
arguments in the SHARED list empty every other rsync in the kit; and
`bk.crashScan` returns ok / missing / unreadable, never a bare count —
DiagnosticReports needs FULL DISK ACCESS, and a refused listing reported
as 0 makes the report say "none anywhere — Hammerspoon has not crashed on
this Mac", the most reassuring line in the file and a lie (6.196.1's rule,
applied to the folder that earns it) — and that holds for the BACKUP
folder too, which may hold every report macOS has already pruned, so
neither report describes a folder it just said it could not read. Newest
is the DIGITS in the name, and a DATED name always beats an undated one:
TWO KEY SPACES, NEVER COMPARED — `Hammerspoon_<date>_<Mac>.crash`
predates `Hammerspoon-<date>.ips` ("_" sorts after "-"), and a letter
sorts above a digit, so one stray `Hammerspoon.crash` would outrank every
real report. `_G.crashReport()` prints the FULL PATH of the newest — the
file LL sends. 🔒 6.197.1: THE FILTER FAILS CLOSED — an unset
`bk.crashGlob` DROPS the entry (it used to make `only` falsy, which
skipped rsyncArgs' whole filter block and copied every app's diagnostics
to OneDrive), and `mustFilter` makes rsyncStep refuse such an entry at
the point of use, the way secret.lua is excluded twice. The scan walks
ONE LEVEL DOWN because `--include */` does (macOS's Retired/ folder is
where the reports most at risk live), keyed by basename, budgeted by
`bk.crashScanMax`. 🔎 6.197.2: THAT BUDGET IS A STATE ("partial"), NOT A
FOOTNOTE — it first shipped as a ⚠️ line beside the totals, which left
"↳ THAT is the file to send", "Hammerspoon has not crashed here" and the
✅/⏳ backed-up verdict stated flat above it. The budget counts every name
walked, that folder is shared with every process on the Mac, and
`hs.fs.dir` returns filesystem order, so the walk can stop before it
reaches ours. As a state it switches all of them off by itself, because
each already asks for "ok". GENERAL RULE: any bounded scan that reports a
state it did not finish reading owes the same distinction, and a fixture
whose wanted rows come FIRST proves the caveat exists, never that it
bites. AND "is today's crash safe?" is answered BY NAME, never by
subtracting two counts: the folders diverge by design (macOS prunes one,
nothing prunes the other), so once the backup holds more than the Mac
does a count difference can never notice a fresh report that was not
copied. `crashScan` returns the NAMES it saw for exactly that. The scan
matches the same glob rsync is given (`bk.globPattern`) so the count and
the copy cannot disagree — and an unmatchable glob is its own state, not
one of the two reassuring ones.
📐 THE FIXTURE SHARED THE CODE'S BLIND SPOT, AGAIN (6.213.2,
modules/autocorrect.lua): 6.205.0's own test proved statrs → starts
against twelve words, and the real list has stater AND stator — so on
LL's Mac starts was one of three answers and the rule stayed silent,
which is the decided rule working. The same measurement (web2, 236,007
lines, fetched to the scratchpad — /usr/share/dict/words does not exist
on the gate's Linux) found plugin → pluging, backend → backened and
signin → signing: right words rewritten by the CANDIDATE side of the
inflection rule. `acSpellEnding(w)` is PURE and names the ending
family; an answer that is only a word by inflection must carry the
family LL typed. Cost stated: a typo inside the ending (convincd) is
silent. RULE, third time: a check on a rule that edits text runs
against the real corpus or a fixture holding the real words that bit —
§8b holds plug, backen, sign, stater, stator by name.
✏️ TWO TIERS, THE KIND OF EDIT ORDERS ONLY THE SECOND (6.213.4, LL:
"statrs is still not corrected" — his call on the decided rule). The
plain kind order (swap, doubled, missing, rotated; first kind with an
answer decides) was measured before it was built and turned adress into
daress (dares+s by a swap, over address) and sceen into scene (over
screen) — the guess the rule exists to refuse. So `acSpellCorrection`
runs `sweep(listed, false)` — every kind, words the list holds outright,
exactly one — and only when that finds NOTHING `sweep(byEnding, true)`
— words by an ending, in kind order, first kind that answers decides.
On an 84-word scored corpus against the real list: 52 right, 1 wrong
(seperate → sperate, since 6.200.0), 31 silent — four more right than
6.213.3, nothing newly wrong. A listed word beats a by-ending word
(allways → always over hallways); two listed words are still silence
(sceen, wierd, adress). Three mutations, each with its own row.
🚨 AN INFLECTION OF A WORD IS A WORD (6.205.0, modules/autocorrect.lua).
The Mac's /usr/share/dict/words is Webster's Second — BASE words, almost
no plurals, past tenses or -ing forms — so 6.200.0's rule read starts,
allows and convinced as "not a word" and rewrote them into starets and
gallows (the list has both). `acSpellStems` is PURE and names the stems
(s/es/ies, ed/d/ied, ing, er/est/ier/iest, ly/ily, ness/iness, doubled
consonant undone, dropped e restored; a stem keeps ≥2 letters); "is that
a word" asks the word AND its stems on BOTH sides of the rule (starts is
left alone; statrs → starts still corrects). `_G.autocorrectAdd(wrong,
right)` appends one fix row (refuses a dead row, a comma, an empty side).
RULE learned here: 6.200.0's "measured against the real word list" was
measured against base words, so the fixture shared the code's blind spot
— the sample for a rule that edits text must include INFLECTED words.
Sublime Text is on the word list's offIn list by design; the CSV rows
and the TWo-caps rule still speak there.
📖 THE WORD LIST IS THE LAST THING ASKED, AND ITS NUMBERS WERE MEASURED
(6.200.0, modules/autocorrect.lua). LL: "The actual word is somethgni,
somethingg, somethinng, somethng, somtething" — five spellings of one
word, listed to say he should not keep adding rows. So after the CSV
dictionary and the TWo-caps rule, macOS's own /usr/share/dict/words is
asked: on every Mac, synced by nobody. It fires only for a word of 5+
letters, letters ONLY with at most one leading capital (which is what
keeps IDs, iPhone, camelCase and SKU7 out), not itself a word, not one
of ⇪Z's learned exceptions, and with EXACTLY ONE real word a single edit
away — two candidates is a guess and does nothing.
📏 THE TWO NUMBERS ARE MEASUREMENTS, NOT CHOICES, and that is the durable
part: against the REAL word list, deleting ANY letter turned rsync into
sync, backend into backed and frontend into fronted — three of 104
ordinary words. Restricting a deletion to a letter that REPEATS within
the next two positions (doubled: somethingg; typed early: somtething)
caught MORE typos (17 of 18, all five of LL's) and changed NONE of the
104. minLen is 5 because at 4, "repo" became "rope". RULE: a rule that
edits LL's text is tuned against the real corpus, never against the
fixture — a 13-word fixture agreed with every variant tried.
The four edits are swap-two-neighbours, a-letter-already-coming,
a-letter-missing, three-neighbours-turned-round. The fourth exists
because "somethgni" is TWO adjacent swaps and a single-swap rule cannot
see a word LL named. Substitution is deliberately absent.
🤫 IT FAILS CLOSED, EVERY WAY: `spellOK` must be exactly true (a caller
that forgets gets no check at all), an app it cannot name is not
trusted, a Mac that cannot answer about secure input is treated as
locked, and a word list missing or still loading means silence. The
list is folded in `acSpell.slice` words per turn on a HELD timer —
235,000 lines in one go is a hitch on the thread that reads the
keyboard — and a failed reload CLEARS the old set first, or the report
says "no word list" while the old one is still answering.
🔁 ⇪Z ALREADY GOVERNS IT: a word-list fix is undone and permanently
refused by the same key, listed in the same 6.199.0 report block, and
removed by the same `_G.autocorrectForget`. Nothing new to learn — which
is the test for whether a new rule belongs in this module at all.
✏️ WHAT ⇪Z LEARNS IS PERMANENT, CROSS-MACHINE — AND MUST BE VISIBLE
(6.199.0, modules/autocorrect.lua). One ⇪Z press appends
`allow,<the exact word>,` to autocorrect.csv, which syncs through
OneDrive, switching the TWo-caps rule off for that word on BOTH Macs for
ever. LL found his by grepping 11,000 lines of his own dictionary
(`11052:allow,HOw,`) because this module had NO REPORT AT ALL and no way
to unlearn anything. Permanent stays; invisible does not.
`_G.autocorrectReport()` lists what ⇪Z has learned — set-differenced
against the ~85 exceptions we SHIP, so the list is only ever his — with
each row's line number and the exact `_G.autocorrectForget("HOw")` that
removes it; ⇪Z's alert names that command as it learns. RULE: anything
this config LEARNS about LL's typing owes a report that names it and a
one-liner that undoes it — a rule you can only find with grep is a rule
you cannot govern.
🔒 forget() is the ONLY thing that rewrites that dictionary whole: temp
file then rename (a half-written CSV beats no CSV is FALSE — it is 11,000
lines of his work), registered in `_G.rewrittenFiles`, case-SENSITIVE
like the rule itself (HOw and How are two exceptions), and it removes
EVERY matching row — which is what handles the duplicate the other Mac
appends before it has reloaded. An in-memory duplicate guard was written
and then REMOVED: no mutation could catch it, because once a word is
allowed the rule stops firing and ⇪Z has nothing to undo. A guard no test
can fail is dead code with a comment on it.
🗂 A `fix` ROW WHOSE SIDES MATCH ONCE LOWERED IS DEAD AND IS SKIPPED
(`fix,IDs,IDs`, `fix,TVs,tvs`): the dictionary stores both sides
lowercased and re-applies sentence case, so obeying it turns IDs into
Ids, and the TWo-caps rule never gets its turn because a dictionary hit
returns first. Skipped at load, named in the report WITH ITS LINE NUMBER,
and the CSV is never edited — his file, his call.
🔎 AND THE DIAGNOSIS THAT WAS WRONG, kept because the method matters:
that short-circuit was blamed for HOw first. It cannot cause it — a
dictionary hit is re-cased from an all-lowercase stored value, so it can
never hand back a TWo-caps-shaped word. `allow,HOw,` was the whole cause.
Read the source before naming a second cause; two plausible mechanisms
are not two mechanisms.
🗂 A STORE IS A FILE, AND THE LOADER VALIDATES THE SHAPE IT READ
(6.198.1, modules/doc_memory.lua). `dm.load()` took `data.open` whole on
the strength of its OUTER type alone — "it is a table" is not the same
as "it is MY table". dm.open is { app = { path = { title=, seen= } } },
so ONE value a level down that was not a table reached every reader and
threw at doc_memory.lua:363 (`d.title`) from the app_watcher quit panel
— every time LL quit Word. A store is written by an older build,
truncated by a crash mid-write, merged by OneDrive, or hand-edited; any
store this config LOADS gets its shape checked, not just its type.
🔑 CLEANED ONCE AT THE LOADER, NEVER GUARDED AT EVERY READ: openFor,
onQuit, diff, reopen and the report all walk that structure, so five
guards is five places for one to drift — and the REPORT is why it must
be the loader, because it walks dm.open with pairs() too, so a bad store
also took out the diagnostic that would have named the bad store. Any
tool whose report reads the same structure its feature reads owes the
repair to the loader. `dm.cleanOpen`/`dm.cleanLastOpen` are PURE and
gate-proven; the report distinguishes never-read / read-and-sound /
read-with-N-dropped, and says what a drop costs (a reopen the quit panel
can no longer offer, never anything on disk).
🚨 A HELPER THAT STAMPS A FIELD ONTO EVERY MESSAGE OWNS THAT NAME
(6.203.0, modules/vault.lua). The page's `say(m)` sets `m.text`,
`m.sel` and `m.rel` on EVERY message before posting it — deliberately,
because that is how the draft reaches Lua ahead of the save
(handleMessage's first line is `v.setText(body.text)`). The cost is
that those three keys are say's, not the caller's: set one and it is
silently replaced. TWO features paid it, unnoticed, for thirteen
releases. ⌘N sent `{a:'named', text: the typed name}` and Lua created
a note named after THE WHOLE OPEN NOTE — which is why LL's failing
name was multi-line when the bar is a single-line <input> that strips
newlines on paste, and why it began "Collect": it was the note he had
open, not the box he typed in. With no note open ⌘N sent "" and did
nothing, which is his report word for word ("I enter a title and I
don't see that anything was created"). And 6.186.0's BOARD sent
`{a:'kmove', rel: the dragged card}`, so `v.setField(body.rel, …)`
rewrote a field of whichever note was OPEN — the one view here that
WRITES, writing to the wrong file since it shipped, reported by
nobody and found by grepping every `say({…})` that names a key say()
owns (6.201.1's "one bug can have two outputs", applied). THE FIX IS
NAMES: a message carrying its own value uses its own key — `name`,
`card` — and a SENTRY in test_vault_js reads the page source and
fails if any say({…}) ever names text/sel/rel again, so the CLASS is
closed, not the two instances. 🧪 And both suites were green
throughout because both hand-built the message: the Lua tests called
handleMessage with `{text = "a name"}`, and the JS stub had no
#pr/#prin elements at all, so askName() took its namefail branch on
every run and the bar was never once exercised. A stub that BUILDS
the message the page sends, instead of letting the page send it,
cannot see a bug in the sending — 6.193.0's rule, third costume.
📏 A NAME THAT CANNOT BECOME A FILE IS REFUSED, IN BYTES, AND SAID
WHERE HE IS LOOKING (6.203.0). `v.nameCheck` is PURE and gate-proven:
newlines and tabs become spaces (macOS WILL take a file name with a
newline in it, and that note can never be typed or linked again), a
leading dot is stripped, "/" and ":" keep mapping to "-", and a name
over `v.nameMaxBytes` is REFUSED, never truncated — a 3,000 character
paste clamped to 248 is a note silently named after its own first
paragraph, and the paste is only safe while it is still in the box he
can copy it from. 248 is ARITHMETIC: macOS holds one path component
to 255 bytes and the longest thing saveNow writes beside a note is
`<name>.md.tmp`, so 255 - 7. BYTES, not characters — one emoji is
four, and a budget counted in characters waves 100 emoji (400 bytes)
straight through to the write that fails. The guard lives at
`openNote`, the ONE door ⌘N, ⌘D, ⌘⇧N, ⌘⇧E, a [[link]] follow and a
search row all arrive through; ⌘⇧E needed it most, because that door
writes the [[link]] into the note you are ALREADY IN and saves it
before creating anything. 👁 And the refusal is drawn in the BAR: an
hs.alert draws UNDER this window (the vault is at bringToFront(true)),
which is exactly why LL saw nothing, so ⏎ no longer closes the bar —
Lua's answer does. The system dialog stays the degrade and alerts the
same sentence, because on that path no window of ours is over it.
🖥 ASKED AND ANSWERED, no code: "the window covered the whole screen
once" is the documented size doing what it says — 1560x1010 clamped to
the screen less 40 pt, which on the Air's own display is very nearly
full screen. `settings = { vault = { width = 1200, height = 800 } }`.

👁 THE PREVIEW PANE SHOWS THE HIGHLIGHT, FULL STOP (6.202.0,
modules/clipboard_history.lua — the pane every picker gets through
preview.open). hs.chooser FOLLOWS THE POINTER BY ITSELF:
HSChooserTableView.m installs a tracking area and its mouseMoved:
selects the row under the pointer (rowAtPoint → selectRowIndexes →
scrollRowToVisible), and libchooser.m's selectedRow() returns that same
selection — so selectedRow() is the mouse answer AND the keyboard
answer. 6.154.0 wrote "HSChooser.m has no mouseMoved and no tracking
area (checked, not assumed)" — checked in the WRONG FILE — and computed
a second, geometric row from window_move's 56/44 constants where the
chooser is ~89/42; that guess named the row BENEATH over the top half of
every list and won the tie: LL's "one entry beneath", 6.160.4's ⇪Y
symptom before it, and forty-eight releases of a suite whose pointer
positions were built from the module's own constants, so it could not
tell them wrong. RULES: a second opinion about something the platform
already answers is DELETED, not tuned; "checked, not assumed" names the
file; a stub's geometry is the PROVIDER's, never the module's.
`previewRow` never reads pv.rowH / pv.top / math.floor (asserted against
the source); pv.headH/pv.rowH are the CHOOSER's 89/42 now
(HSChooserWindow.xib) and their only job is the band that names the
"🖱 under the pointer" tag — the tag is the one thing the pointer still
decides, and it is a label, never a row; a pointer crossing the query
field earns none. A wheel scroll is no longer a blind spot. NEXT, ALONE (one change at a time):
the pane has no report — `_G.clipboardReport()` naming the row, the
highlight and the hand, with "closed — last showed…" distinct from
"never" (the verifier's shape).
📋 THE BORROWED CLIPBOARD IS PUT BACK ONLY IF IT IS STILL OURS
(6.198.0, modules/power_tools.lua). Reading a selection costs a ⌘C in
any app that will not answer AXSelectedText, so pt.copySelection BORROWS
the pasteboard — save, clear, ⌘C, read, hand over — and restores 0.6 s
later. LL: "⇪2 says it's copying but the clipboard does not have the
content I sequentially copied. ⌘+c works." It DID have it, for 0.6 s:
the caller wrote its block inside the loan and the restore landed on
top. An alert that is true when shown and false when acted on, with
nothing to see in between, is the worst shape a message can have. The
restore stands down when the pasteboard has been written since the
borrow — `pt.borrowIntact` asks macOS's CHANGE COUNTER first (it sees
the two writes a comparison never can: the same text written again, and
anything that is not text), the CONTENTS as the degrade for a
Hammerspoon without it, and NEITHER READABLE means intact so the last
resort stays 6.132.0's promise that your clipboard comes back.
🔎 AND IT WAS NOT LL'S BUG — see 6.201.0 above. The guard is right and
it works; the block ⌘V pasted was wrong before the borrow ever ran. A
correct fix for a real bug is not evidence that you found THE bug.
🔑 THE GUARD LIVES AT THE BORROW, NEVER IN THE CALLER: a second caller
had the identical bug unnoticed (the 🔢 count row's "N words · N
characters"), and only the borrow can see the case no caller owns — an
APP copying during the loan. GENERAL RULE: code that saves shared state,
hands control out, and restores it later must check the state is still
what it left before writing; "I put it back" is only honest if nobody
else got there. `settings = { power_tools = { restoreGuard = false } }`
is the rollback and `_G.powerReport()`'s "⌘C borrow" / "last borrow"
lines are the state — a state with no report is what hid this. STATED,
NOT SPECIAL-CASED: an app answering ⌘C LATE moves the counter too, so
that clipboard is left alone as well; a second rule keyed on "did we
hand anything over" would be a second rule to keep in step.
📋 hs.pasteboard.setContents REFUSES BY RETURNING FALSE, NOT BY THROWING
— so `local ok = pcall(function() hs.pasteboard.setContents(x) end)` is
true either way. That is 6.179.0's read-THREE-values rule and three
places here broke it: ⇪2 promised "⌘V pastes the block", the 🔢 row
said the counts were copied, ⇪; announced formatting stripped. The
same two-value shape is still live in text_expander.lua and
url_cleaner.lua — deliberately NOT swept in 6.198.0 (LL: "only do them
one-by-one"), so fix them when either module is next opened.
🧪 AND BOTH TEST STUBS WERE GENTLER THAN macOS: setContents returned nil
and there was no changeCount at all, so the bug ran green for six
releases. The refusal checks that existed made setContents THROW, which
is the half pcall catches. A stub answers exactly what the real
provider answers, refusals included — 6.193.0's rule, and this is the
second time it has cost a release.
🚨 AND THE RESTORE TIMER WAS ARMED INTO THE RUNNING TIMER'S OWN SLOT
(pt.copyTimer, from inside pt.copyTimer's callback) — 6.196.1's
use-after-free shape in hs.timer instead of hs.task, pre-dating that
release. `pt.restoreTimer` is its own slot, asserted against the SOURCE
because a stub timer is collected by nobody.
🔍 THE GATE AUDITS THE CHEAT SHEETS (6.196.0, test_integration):
"a stale key on the sheet IS a broken feature" (6.181.0) is a check now,
not a promise kept by hand. Every module's own cheatsheet KEY COLUMN is
joined to the module that claimed the key (`HYPER_OWNER`, filled from
`_G.moduleLoading` — the `src` string is prose and cannot be matched to a
file). TWO RULES THAT MAKE IT TRUSTWORTHY: a key column that is ONLY
combos is a promise and is audited, one with a word in it ("via ⇪R",
"vs ⇪X", "in ⇪;") is a POINTER at another tool and is not; and it flags
MISATTRIBUTION, never absence — §0.4's migration map binds a dozen keys
outside hyperAddShortcut, so "is it bound at all" would report every one
as dead and the check would be switched off within a week. Shared windows
get a PAIR exemption (`AUDIT_SHARED["Vault||n"]`), never a bare combo —
exempting "|n" would blind it to every future misprint of ⇪N. It caught
a live one on its first run: the Vault's sheet still offered ⇪1 after
6.194.0 moved ⇪1 to mouse-follows.
🔗 6.269.0 — AND WHAT IT CANNOT SEE IS A CARD WITH NO ROWS AT ALL
  (modules/anchors.lua + init.lua's §1.12 loader). anchors.lua declared
  its eight rows under `rows =` from the day it was written (6.180.0);
  the loader reads `g.entries` and coerces a missing one to `{}`, so ⇪⇧U
  drew the heading "🔗 ANCHORS (⇪⇧U …)" over empty space for eighty-nine
  releases with the eight correct rows sitting in the file. ONE KEY was
  the whole fix.
  🔑 THE GENERAL RULE, and it is the expensive half: AN AUDITOR THAT
  JOINS TWO THINGS CAN ONLY EVER SPEAK ABOUT ROWS THAT EXIST. The audit
  above joins a card's KEY COLUMN to the module that bound the key, so
  it is structurally blind to a card with no key columns — it flags
  MISATTRIBUTION, never ABSENCE, and that is the right call for the
  reason stated above. The shape that got through was therefore the one
  nobody was looking for: not a wrong row, not a stale row, NO rows.
  When a check works by joining A to B, ask what it says about a
  MISSING A — and put a different instrument on that, because widening
  the join is what makes an auditor cry wolf and get switched off.
  🔔 THE LOADER NAMES IT NOW: a titled group registering with no usable
  `entries` is recorded in `_G.cheatsheetFaults` and takes the 🔔 door,
  and the message DOES THE DIAGNOSIS rather than reporting the symptom —
  it names the key the rows are hiding under and the count ("8 row(s)
  are under `rows`, and the sheet only reads `entries`"). Had that
  sentence existed in 6.180.0 this was a five-minute fix on day one.
  📏 THE COERCION STAYS: `g.entries or {}` is what stops one malformed
  group taking the WHOLE sheet down (cheatsheet.lua walks
  `ipairs(g.entries)` unguarded). IT DEGRADES, IT NEVER BREAKS is
  unchanged; what this release pays is A BREAK IS SEEN, NEVER ONLY
  LOGGED, which every silent `or {}` in this config is quietly exempt
  from. GENERAL: a nil-coercion that converts a STRUCTURAL defect into a
  plausible-looking empty answer owes a line that says it happened.
  `family = "auto"` cards are empty on purpose and are exempt.
  🔎 `_G.cheatSheetReport()` — the sheet was the last big surface with no
  report at all, which is exactly why nothing could be ASKED about this.
  "empty" (what he can see) is printed before "faults" (why), because a
  card can be empty without the loader having caught a reason.
  🚨 AND ITS FIRST VERSION CRIED WOLF ON A HEALTHY MAC, which is the
  sharper lesson and was caught by the mutation sweep before delivery.
  `family = "auto"` registers a card for a tool with no cheat sheet of
  its own so the tool is LISTED at all; copy_on_select is the one such
  card in this config, and the report counted it beside a broken one and
  printed "⚠️ 1 card(s) draw a title over nothing" next to "faults :
  none". 6.196.1's rule broken BY THE INSTRUMENT BUILT TO KEEP IT.
  THREE STATES: "empty" (broken) · "listed" (a heading alone on purpose,
  NAMED rather than hidden — hiding it would be the same silence one
  layer up) · "faults" (why). GENERAL, and it applies to every report
  this project adds: A NEW INSTRUMENT IS MEASURED AGAINST THE HEALTHY
  CASE FIRST. Its first duty is to be SILENT when nothing is wrong; one
  that warns on day one is switched off long before it ever sees the
  fault it was built for — and then the next defect is invisible again,
  with a report sitting beside it saying so.
  🚨 AND A COMMENT CLAIMED A GUARD THAT HAS NEVER EXISTED:
  tests/loader_test.lua — the hand-kept copy of §1.12 that the whole
  gate runs on — has said since 6.101.0 that "test_tools asserts the two
  blocks agree". It does not, and never did. That is 6.199.0's rule
  inverted and worse than the case it was written for: a guard no test
  can fail is dead code with a comment on it; a comment describing a
  guard that does not exist is an invitation to edit one copy and trust
  the other — which is precisely what this release had to do. The drift
  sentry is written now (both blocks, comments stripped, whitespace
  flattened) and the comment is true. GENERAL: when a comment claims a
  check, grep for the check.
🔁 ⇪space = APP LAUNCHER, ⇪D = UNIFIED SEARCH (6.196.0, LL's swap).
🚨 The SHIFTED half did NOT follow: ⇪⇧D must stay UNCLAIMED so it forwards
as ⌘⇧⌃⌥D to core/diagnostics.lua's plain hotkey — every boot line names
it, and a bind there takes it SILENTLY because a forwarded chord is not a
bind and the collision auditor cannot see one stolen. The screenshot view
keeps ⇪⇧space (`uni.shotsKey`). Asserted by name in test_unified.
🎹 "ACCESSIBILITY OFF" IS NOT A FOOTNOTE (6.196.0, core/boot_report.lua):
without it hs.eventtap cannot be CREATED, so snippets, autocorrect, the
key caster and ⇪'s fallback are all gone — the row said "window features
inactive" and LL read straight past it on a boot where most of the config
was dead. It also says QUIT AND RELAUNCH, not reload: taps are built at
launch, so re-granting mid-session changes nothing.
🖥 A PANEL OPENS WHERE YOU ARE LOOKING — AND `mainWindow` IS NOT THAT
(6.236.0, init.lua §1.5, LL for the SECOND time: "the cheat sheet appears
on the monitor that was active and not the monitor where the mouse/active
app resides, entirely on a different desktop"). 6.196.0 below answered the
POSITION half and I read it as the whole sentence; the half that picks the
SCREEN was never touched — 6.198.0's rule again, a correct fix for a real
bug is not evidence that you found THE bug. The order was
`frontApp:focusedWindow() or frontApp:mainWindow()`, and mainWindow() is
the window the APP calls primary: on two monitors routinely the other one,
on another Space one he cannot see — a STALE monitor, his word. THE
POINTER OUTRANKS IT NOW: a focused window still wins, then the MOUSE (it
is where the person is looking and is never ambiguous about the display),
then mainWindow, then mainScreen. `_G.baseScreenPick(facts)` is PURE and
answers the screen AND WHICH RULE decided; the gate LIFTS it out of
init.lua's source rather than retyping the order. Eighteen modules plus the
cheat sheet place panels through resolveBaseScreen — one rule, one place.
`_G.screenReport()` names the rule that placed the last panel and what each
candidate answers now.
🧪 TWO SOURCE SENTRIES PASSED THE MUTATION THEY EXIST TO CATCH: one
grepped the WHOLE function for `if not facts.focused` while a second such
guard exists further down (it reads the 140 chars before the mainWindow
call now), and one looked for "function _G.screenReport" and passed on
"screenReportRenamed" because the old name is a PREFIX of the new. RULE:
a name sentry matches the parens, and a guard sentry reads the text
AROUND the thing it guards, never the function it lives in.
🖥 A REMEMBERED PANEL POSITION IS AN OFFSET INTO ITS SCREEN (6.196.0,
core/cheatsheet.lua): stored as dx/dy from the resolved screen's origin,
so the sheet stays where LL put it ON THE MONITOR HE IS WORKING ON.
Absolute x/y is still written beside it (an older build must find a
position it understands) — which is exactly why the check moves the
SCREEN out from under a fixed offset rather than asserting "it opened
somewhere sensible". A legacy absolute position that does not fall on the
current screen is DROPPED for the centre, not clamped onto an edge of it.
⌨️ ⇪. TAKES "?" FOR THE SHORTCUTS ONLY (6.196.0, menu_search): the
shortcut column was always on every row; `ms.choicesFrom(rows, onlyShortcuts)`
is a PARAMETER, not a second row builder, so the two views cannot drift.
No second hyper key — 6.182.0's rule.
➕ A + ROW IS A CLICK TARGET, NOT A WALKER ROW (6.195.0): the vault's
"+ new note ⌘N" heads the 🕸 NOTES section and posts `newnote` →
`v.newNote()` — the SAME call ⌘N makes, so the naming bar and its
dialog degrade serve both. It carries `data-new`; ROWSEL matches
data-name/data-tab/data-tag, so a + row at the TOP of the notes with
any of those steals ⌥↓ from the first note. A filter hides it (⏎
already creates the typed name). Any new + row at the head of a list
gets the same treatment.
🏃 A HELD ARROW JUMPS FOUR (6.195.0, mouse_grid): `nudgeAccelFirst`
(4) is the multiplier on the FIRST repeat of a hold — 32 pt — rising
to nudgeAccelMax. A TAP stays 1× (`if r.n <= 0 then return 1 end` is
load-bearing: apply first to the tap and fine placement is gone) and
⇧+arrow stays 1 pt. The report's "nudge  :" line names all four
numbers — LL reported "too slow" twice while they lived nowhere
readable.
🎯 ⌥+ARROW HALVES ONLY AFTER LANDING, AND SAYS SO (6.195.0): LL's
"the cells are not dividing in half when I get two keys in" was two
SILENT `return`s in halveTo (not landed / halve off). Both now alert,
and pickModal binds ⌥+arrows purely to say "type the three letters
first". OPEN AND NOT DECIDED: whether halving should work mid-typing,
where a prefix names a BLOCK of cells rather than one box.
📸 SCREENSHOT KEYS (6.194.0, LL's own map): ⇪⇧1 editor · ⇪⇧2 active
window · ⇪⇧3 delayed · ⇪4 area (unchanged) · ⇪⇧4 text/QR · ⇪5 scrolling
· ⇪⇧5 the ⌘1–⌘9 panel. They are a TABLE (`shots.toolKeys` = {mods, key,
act, label}) bound in one loop against the existing `shots.runAction` —
a key and its panel row are the SAME action and cannot drift. The gate
JOINS the table to runAction's branches BOTH ways (6.114.0's ⇪⇧R rule,
applied to keys). A new screenshot key = one row here, nothing else.
DISPLACED BY IT: pause ⇪⇧1→⇪⇧Esc, type-clipboard ⇪⇧2→⇪⇧T, mouse-follows
⇪⇧3→⇪1 (mods went EMPTY — assert mods, not just the key, or it binds
⇪⇧1), QR ⇪5→⇪⇧8. Pause is Esc because every mnemonic letter was spent
(⇪⇧P is the pomodoro) and it belongs beside the ⌃⌥⌘⇧Esc panic chord.
🚨 test_integration's collision auditor loads the REAL config and names
both sides of any double-claim — that is what makes a remap safe; run
the gate before believing a key is free. And move the CHEAT SHEETS,
report strings and `hint.groups` in the same commit: a stale key on the
sheet IS a broken feature and the gate cannot see it.
🚨 EVERY TEXT PANEL DOES THE ⇪ HANDSHAKE (6.165.1, enforced 6.193.0):
`_G.hyperExpectRelease(1.5, who)` after show AND the page forwarding its
F18 keyUp to `_G.hyperReleaseSeen(who)`. unified_search had NEITHER
until 6.193.0 — that is LL's "stuck on the screen sometimes" and the
Console's "released by the watchdog — held 8s". The page listens for
`e.key === 'F18' || e.keyCode === 79` ONLY; reporting every keyup ends
the hold while LL is still holding it. A release is NOT a dismissal —
it must not close the panel. Both halves have mutation-proven checks.
🚨 ANY FALSY RETURN IS A REFUSAL (6.193.0): `clip.openInPanel` /
`ocr.openInPanel` read `opened == false`, and `uni.show` returns NIL
when unified search is off — so ⇪V opened neither panel nor chooser and
did NOTHING. Use `not opened`. RULE LEARNED, the durable half: the test
STUBS returned nothing while the real service returns true, so the
suite ran the failing input on every green run and passed. A stub more
forgiving than the thing it stands in for is a hole with a tick beside
it — make a stub return exactly what the real provider returns.
✂️ SPLIT THE LANDED BOX (6.192.0, REPLACED BY LETTERS IN 6.252.0 —
mouse_grid). ⌥+arrow is GONE (LL: "Remove the ⌥halve option as I don't
use that. Too convoluted."). After ⇪X lands, the box is DRAWN split
along its LONGER side with one letter in each half; pressing that letter
keeps it, puts the pointer at its centre and splits again.
🔒 THE 6.192.0 RULE IS NARROWED, NOT DELETED: landed mode captures
EXACTLY TWO alphabet keys — the pair drawn in the box — and the suite
still walks the whole alphabet and fails on any other letter and any
⌥+letter. COST, named: typing one of those two right after landing
splits instead of reaching the app; the badge shows the pair.
🔌 BOUND ON THE FIRST LANDING, never at setup — `settings` are applied
AFTER setup returns (6.228.0), so binding early would draw one pair and
bind another; hs.hotkey.modal has no unbind, so it happens once
(`grid.ensureSplitKeys`). `grid.splitOf` and `grid.halvePair` are PURE:
the LONGER side is the one worth splitting (a 200x20 strip halved top to
bottom adds no precision where it is missing), and two DIFFERENT
characters or nothing (one letter cannot name two halves).
THE ORIGINAL RULE, kept because its arithmetic still stands: ⌥+arrow
kept that HALF of the cell and put the pointer at its centre; press
again to halve again. `grid.halfOf(box, dir, minPt)` is PURE (the gate
proves the geometry with no screen) and the floor is measured on the
HALF, not the box — 16 pt halves, 15 refuses, each dimension asked
separately. A refusal SAYS so and moves nothing; it never falls back to
a nudge. A plain nudge CARRIES the box (same size, pointer at centre) so
nudge-then-halve works. ⌥+arrow is deliberately NOT repeatfn'd — each
press is a decision. 🔒 It is ⌥+ARROWS because landed mode may capture
NO alphabet key (LL's diagram wanted letter labels; the rule wins, and
the test now also forbids ⌥+letter). The outline is its own canvas,
mouse-transparent (it must not eat the click it helps aim), and a canvas
it cannot draw tears landed mode down rather than capturing keys
invisibly. Rollback `settings = { mouse_grid = { halve = false } }`;
report line "halve :".
THREE FONT SIZES, NOT ONE (6.191.0): the vault/pad page derives FSpx
(body), FS1px (controls) and FS2px (labels — headings, footer, chips,
format bar, the tool tip) from `v.fontSize`. They step by ONE and FLOOR
at 10 px; the old fs / fs-2 / fs-3 step is what made LL's labels 10 px
at a 13 pt base. A check walks EVERY font-size in the built page and
refuses any more than 2 under the base, so the old shape cannot return.
Window 1560x1010 carries 14 pt. One knob: `settings = { vault =
{ fontSize = 16 } }`. A NEW size in this page comes off fs — never a
literal px.
THE TOOL TIP IS ANCHORED TO THE ELEMENT (6.191.0), never to the pointer:
at pointer+18 it sat inside the mouse arrow's own tail and LL could not
read it. `tipEl()` returns the ELEMENT carrying the tip so there is a
rect; the tip is centred UNDER it (these buttons live at the TOP of the
window, so "above" is off the edge) and folds back above only when the
bottom would clip. Any new tip layer does the same.
`hs.dialog.textPrompt` CANNOT BE RESIZED (6.190.0): it is a stock
NSAlert and Hammerspoon exposes no width — LL could not see what he was
typing. ⌘N asks in the vault PAGE instead (`v.askName` → `askName()` →
`{a:'named'}` → `v.createNamed`); the bar owns Enter and Escape while
up, and esc closes the BAR not the window. The dialog is the DEGRADE
(no web view) and BOTH paths reach `v.createNamed` — two creation paths
is how one stops matching the other. ⌘⇧N and ⌘⇧E still use the dialog:
same treatment when they come up.
✍️ 6.213.5 — THE DOOR EXISTS NOW: `editor.open` (ocr_engine's
`ocr.openTextEditor(opts)` — title/sub/text/rows/placeholder/deleteLabel
+ onSave(text)/onDelete/onCancel hooks; the box closes BEFORE a hook
runs; false, why with no webview and never a prompt of its own) is the
window every remaining textPrompt caller should take, one per release,
asked at PRESS time with the prompt kept as the degrade. ⇪⇧V took it
first, on LL's report ("does not come to the front… the edit field is
very small" — 6.115.0's two complaints, in the module that kept the
prompt). Remaining callers: quick_append, bulk_rename (3), capture_pad,
note_pad, scratch_pad, activity_tracker, cheatsheet (2), vault (⌘⇧N /
⌘⇧E). RULE learned: when one module's complaint has already been
answered in another, the answer is a SERVICE, not a second copy.

Nothing lost to an Esc (6.189.0): the ⇪⇧4 editor hands its state
back on cancel and takes it in on the next open of the SAME path —
`ed.kept` is ONE in-memory slot { path, img, notes }, never disk, never
across a reload. The split is the design: BLURS are baked into `cv`,
TEXT/ARROWS live on the `ov` overlay, so canvas + notes is the whole
state with nothing counted twice — paint the notes in before handing
back and every annotation returns drawn twice (the JS suite asserts it).
Notes ride BASE64 (a note is LL's typing going into a <script> block)
and the image is refused unless it matches
`^data:image/png;base64,[A-Za-z0-9+/=]+$` — that pattern in
`ed.rememberWork` and the one in `ed.buildHtml` are ONE rule, keep them
in step. A SAVE clears the slot (a stale slot restores over the next
open and reads as a lost save). `ed.keepOnClose` is the rollback.
The cheat sheet cannot get stuck (6.189.0): ⇪/ closing LAST rests on
every other claimant's active() going false again, and one that never
does made the sheet unclosable. `cheatSheet.noteEscRefusal(who, why,
now)` counts consecutive refusals from the SAME claimant inside
`escInsistWindow` (2 s); at `escInsist` (2) the sheet closes anyway and
NAMES who. One press still defers — that is 6.78.0 and it is unchanged.
The 0.5 s shadow is deliberately NOT counted (it expires on its own, so
it can never be the thing that sticks; two presses that fast are the
double-tap it exists to absorb). KNOWN: a PINNED vault survives Esc, so
two presses there close the sheet under it — `settings = { cheatsheet =
{ escInsist = 3 } }`. `_G.escapeReport()` (core/coexist.lua) lists every
claim, its priority, whether it wants Esc NOW, and the last refusal;
a claimant whose active() throws is NAMED there, never fatal — it is the
likeliest suspect. test_integration's lifted router block was widened to
reach it; widen it again for anything added after `escapeReport`.

Screenshot editor handles (6.188.0, modules/screenshot_editor.lua):
the canvas is DISPLAYED scaled to fit the window, so a hit target sized
in IMAGE pixels shrinks as the screenshot grows (a 4K shot in a 1,000 pt
window is 4:1 — a 35 px handle was a 9 px target). `viewScale()` is
image px per screen px; `handleR()` floors at `ed.handlePx` (12) SCREEN
points converted through it; `handleRFor(n)` then CLAMPS that against
the object's own size, because a handle bigger than its object is the
opposite bug (a short arrow's two ends become one target). Handles are
DRAWN at the radius they are HIT — 0.6× taught the eye to aim small. A
text note's box is padded by the handle radius and its bottom-right
corner is a SIZE handle; `snapNote` carries `size` so ⌘Z undoes a
resize through the existing generic 'set' op. RULE for any new hit
target in a scaled canvas: measure it in screen points, convert at hit
time, and clamp it against what it belongs to.

🚨 Panic chord (6.174.0, power_tools): ⌃⌥⌘⇧Esc = `pt.panic()` /
`_G.hsPanic()` — releases the ⇪ hold FIRST, then the vault window (even
pinned), the Scorp Pad, the mouse grid, the screen veil, any visible
chooser, and finally flips `_G.hsPaused` on (never off — panic does not
toggle). Bound with hs.hotkey DIRECTLY, never hyperAddShortcut: a hyper
escape hatch is worthless when hyper is what stuck. Every step runs in
its OWN pcall and failures are named, not swallowed. ANY new panel that
can take the screen or the keyboard adds a row to `pt.panicSteps`.
Report: `_G.panicReport()`.

Pause switch (6.152.0; ⇪⇧Esc since 6.194.0): toggles `_G.hsPaused` (power_tools). Hyper
shortcuts are suppressed CENTRALLY in init.lua's hyperBind (the pause key
itself is exempt via `_G.hsPauseCombo`, published before binding); every
keyboard TAP handler must start with `if _G.hsPaused then return false end`
(autocorrect, expander, key caster do). Taps stay running while paused.

⌥Tab (6.152.0): macOS AX never returns another desktop's windows from
`app:allWindows()` (minimised yes, other-Space no) — the switcher serves
them from `altTab.known`, a memory fed by every listing; z-order comes from
`hs.window._orderedwinids()`. `hs.window.orderedWindows()` is banned there
(it re-runs the whole sweep internally; the test counts calls), and so is
`hs.console.hswindow()` since 6.160.3 (it is hs.window.get → allWindows,
a second full sweep; the console comes from applicationForPID(own pid)).

RULE (6.179.1, learned the hard way): a REPORT PRINTS AS ONE STRING —
build the lines in a table and `print(table.concat(L, "\n"))` once, like
`_G.noticesReport()`. core/console.lua's gate silences a short single
line after two showings (digits normalised, so near-identical rows share
a key) and opens ⛔/⚠️ banners around marked lines, so a report printed
row by row loses rows and gets banners spliced through it. Assert it in
test_console against the REAL gate; a print stub cannot see suppression.

Key trail (6.179.0, core/key_trail.lua): a ring of the last
`trail.keep` (24) ⇪ shortcuts — combo, source, ms, why ("threw" /
"paused"). `_G.keyTrailReport()`. init.lua's hyperBind TIMES the pressed
fn (pcall + re-raise; a throw must still throw) and calls
`_G.keyTrailRecord` nil-guarded, as it does `_G.shortcutHint`; the pause
wrap records a swallowed press; power_tools' panic chord records itself
(hyperBind never sees it — it records `plain = true`, so the report does
not draw a ⇪ in front of a hs.hotkey chord). 🔒 TWO PROMISES THE GATE
ENFORCES AGAINST THE SOURCE: combos only — never typed text (no
eventtap/keycodes/pasteboard) — and it never writes (no
io.open/hs.settings). Do not break either. 6.179.1: the duration, the
re-raise and the xpcall branch each have a check that FAILS against the
mutation it exists to catch — keep them that way; "a number ≥ 0" passed
with the timing deleted.

Boot cost (6.178.0, core/boot_cost.lua): `_G.bootCostReport()` ranks
every module by load ms (with warm ms and file size); a boot line names
the total and the worst three ONLY when a module took >150 ms or the
load >1.5 s — a fast boot is silent. It MEASURES, never decides: no
loadfile/dofile/loadModules in it (the test asserts that), read from
`_G.moduleStatus` after the fact, loaded in its own pcall. RULE for the
size question, settled 6.178.0: trim on the milliseconds, never on the
kilobytes — comments are discarded at parse and are the project's
memory; tests/ and CHANGELOG.md never reach ~/.hammerspoon. A NEW core
file must be added to hs-doctor.sh, hs-install.sh (BOTH loops) and
INSTALL.md, counts included — three sentries in test_diagnostics enforce
it. 6.179.0: one CSV row per boot in Logs/boot_cost-<Mac>.csv, APPENDED
(an append cannot shrink, so no write-ledger row), written on a held
timer after the warm phase, read only for the report; the report and the
boot line compare against the MEDIAN of the last ten and say "slower
than usual" past `driftFactor` (2×) even when under the absolute
thresholds — that comparison runs with the WRITE, seconds after boot,
never on the boot path (a main-thread read of a OneDrive file is the
6.152.x/6.160.0 stall). The file is uncapped, so `readHistory` seeks to
the END and reads `historyTail` (16 KB) into a ring — never the whole
file, never `table.remove(rows, 1)`. The writer flattens quotes, commas
and newlines and clamps negative/non-finite numbers, because the reader
is a pattern and a row it cannot parse vanishes in silence. RULE for any
`pcall(fn)` where fn returns `false, why`: read THREE values — reading
two makes a refusal look like success (that is how the report came to
claim "first boot recorded" on a Mac that could not write at all). EmmyLua was deleted from init.lua in 6.179.0 — never
configured, no dependents; the story is CHANGELOG 6.64.0.

## Panel ladder (core/coexist.lua)

`hs.chooser` is PINNED by macOS at mainMenu+3 and exposes no level API — the
one rung that cannot move. So the cheat sheet sits at mainMenu-2 (THE FLOOR)
and every other canvas panel is placed relative to it via `_G.panelLevels` /
`_G.panelLevel(name)`. All webview panels call `bringToFront(true)`
(≈screenSaver level) and are deliberately NOT in the table. Esc order
mirrors draw order: "closes last" IS "drawn under".

## 🧪 THE TEST PLAN SHIPS (6.271.0) — how LL scores a release

LL: "if we want to score each release, I need a set of directions that's
explicitly state the steps that you want me to take to test each
release … that is a basic level of tests … that way I can return to you
with robust data rather than me just saying that worked or that didn't
work fix it."
🚨 THEY ALREADY EXISTED AND HE HAD NEVER SEEN ONE. Seventy-two "verify
with LL" blocks, 1,451 lines, one per release for months — in THIS file,
which is not in the package. The archive root has six files and none is
a test plan. He was walking the cheat sheet inventing his own testing
because the instructions never shipped, and 47 pending rows out of 76 is
what that looks like from his side.
🔑 `tools/build-test-plan.lua` lifts the blocks out of here into
TESTING.md at the archive root (newest four; he installs one archive
carrying several). GENERATED, like the feature list: a stale plan is
worse than none, because he runs the wrong steps and reports a pass on
something that was not built. Four gate checks hold it.
📋 A VERIFY BLOCK IS STEPS, NOT PROSE, from 6.269.0 onward — numbered,
each with its own EXPECT, grouped: **THE HEADLINE** (this release; if it
fails, stop) · **MUST STILL WORK** (what this release could have broken)
· **PASTE BACK, PASS OR FAIL** (a report from a WORKING Mac is what says
what a broken one is missing) · **A JUDGEMENT ONLY HE CAN MAKE** (the
numbers no gate on Linux can answer).
🔎 THREE ANSWERS, NEVER TWO (6.196.1, applied to reporting): PASS · FAIL
with what happened INSTEAD · BLOCKED, meaning the step could not be run
at all. Blocked and failed send me to different places.
📏 NAMED, NOT DONE: the older blocks are still prose. They get the step
treatment when a release touches them — a bulk rewrite of 1,451 lines
nobody is about to run proves nothing.

## Release ceremony — every release, no exceptions

1. Version stamps ×3 in init.lua: line 7, the WHAT EACH TOOL DOES header,
   and `_G.configVersion`.
2. TWO most recent NEW IN blocks stay inline in init.lua (was five until
   6.180.0 — five had grown to 135 lines and the file was two lines under
   its budget); older ones drop into the trailing "see CHANGELOG.md" note.
   Prose that is not orchestration belongs in GUIDE.md, not init.lua: the
   WHAT EACH TOOL DOES catalogue moved there (§5b) in 6.180.0. init.lua
   must stay under 3,800 lines — the gate fails below 4,000 AND at 3,800,
   so there is real headroom rather than a ceiling to fight. 6.217.0
   trimmed twenty pre-6.15x story blocks to their rules (3,796 → 3,534);
   the stories are in CHANGELOG.md, so a trim never loses one. Full narrative entry goes at
   the top of CHANGELOG.md's text block.
3. GUIDE.md's numbers (init.lua line count, suite/check totals) are MEASURED
   off the test gate, never guessed or remembered.
4. The zip recipe is documented in repo-root `.gitignore`. Non-negotiables:
   build then `--check` with `tools/build-snippets.lua hammerspoon`
   first; init.lua sits at the zip ROOT (no wrapper folder); snippets pruned
   to bundled.lua only; re-run `tools/run-tests.sh` from INSIDE the unpacked
   package; zip named `hammerspoonX.Y.Z.zip` at repo root, gitignored.
   `hammerspoon/snippets/` is NOT in git: run the builder WITHOUT --check
   first (`lua5.4 hammerspoon/tools/build-snippets.lua hammerspoon`) to
   fold the committed `packs/` into `snippets/bundled.lua` — it exists on
   every machine since 6.162.0, so a zip never ships without snippets.
   The container also lacks `lua5.4` after a rebuild: `apt-get install -y
   lua5.4` (root, no sudo needed) before the gate.
5. Current version and check counts: read them off init.lua line 7 and the
   top CHANGELOG entry — do not trust numbers remembered from chat.
7. 📜 `lua5.4 hammerspoon/tools/build-feature-list.lua hammerspoon` AFTER
   the stamps and the CHANGELOG entry (6.217.0): RESOLVED-FEATURE-
   REQUESTS.txt is committed and rides in the zip; test_diagnostics
   fails a list stamped with another version. Generated from the cheat
   sheets — never hand-edit it.
6. 🚨 THE CEREMONY SCRIPT RUNS IN THE FOREGROUND AND ASSERTS EVERY
   REPLACE (6.212.0): three releases shipped code without their words
   because the script died inside a backgrounded gate command. Grep the
   three stamps and the NEW IN order back before starting the gate; the
   gate now fails on a wrong header (test_diagnostics 11b) and on a
   GUIDE total it did not count (run-tests.sh's 📏 line).

## 🪜 ROLLBACK — any release can be rebuilt, and a late-surfacing bug
## is stepped back through them

LL, 2026-09-14, agreeing to back-to-back releases in one zip: "ensure
though, you're ready to troubleshoot the most current issue and then
also think about stepping back through the other zip releases if we
encounter a problem. Because … they didn't present itself until we were
several releases higher." He is right and it has happened twice —
6.216.0's "banshee" was an autocorrect loop live since 6.10.0, and
6.206.0's stitch failure had been broken since 6.87.0.

THE METHOD, when something breaks after a stacked zip:
1. ASK WHICH SYMPTOM, then read the scoreboard DOWNWARDS from the
   installed version. Each row names one change; the first row that
   touches the symptom's module is the first suspect, NOT the newest row.
2. A symptom that no row touches is an OLD bug the new release merely
   exposed — say so and diagnose it on its own, never by reverting.
3. REBUILD ANY VERSION from its commit (the recipe is in repo-root
   .gitignore): `git checkout <sha>` → build snippets → copy → zip. The
   zips are gitignored build artifacts; the COMMITS are the archive.
   6.216.0 6f06071 · 6.217.0 a475bef · 6.218.0 41b002b · 6.219.0 862c177
   · 6.220.0 ac3975e · 6.221.0 ead07d9 · 6.222.0 1842ca7 · 6.223.0
   86ac82b · 6.224.0 67957ea · 6.225.0 98434fe · 6.226.0 304f1f9 ·
   6.227.0 14e953a · 6.228.0 2aa3dfe · 6.229.0 a1318e1 · 6.230.0 0740c07 · 6.231.0 c1921af · 6.231.1 5a5c298 · 6.232.0 1ca3f6f · 6.233.0 2328c8c · 6.234.0 57f78d0 · 6.235.0 52e5b21 · 6.236.0 34cff8b · 6.236.1 fdce771 · 6.237.0 adf9256 · 6.238.0 3adad4f · 6.239.0 3adad4f (one commit, two releases) · 6.240.0 8f44bec · 6.241.0 dce517e · 6.242.0 1a1dab0 · 6.243.0 8fba04f · 6.244.0 9320906 · 6.245.0 9c1a8b1 · 6.246.0 1400abd · 6.247.0 3b92e99 · 6.248.0 e4e3a03 · 6.249.0 e4edc3f · 6.250.0 c267c1b · 6.251.0 f7b0d57 · 6.252.0 6307253 · 6.253.0 ef20313 · 6.254.0 14493e5 · 6.255.0 d371b34 · 6.256.0 3c29888 · 6.257.0 7f55d2b · 6.258.0 10d2250 · 6.259.0 2bcda06 · 6.260.0 f16e286 · 6.261.0 8680504 · 6.262.0 595dc2e · 6.263.0 014ddf6 · 6.264.0 5e41879 · 6.265.0 f0c487c · 6.266.0 9135f7b · 6.267.0 a621a60 · 6.268.0 c2e513f · 6.269.0 f6552ea (078cece is the same release before the report was corrected) · 6.270.0 b8eda88 · 6.271.0 b8edbe1 · 6.272.0 881a91b · 6.273.0 56b0d2b · 6.274.0 c6e9b6b · 6.275.0 9cebe19 · 6.276.0 3db904e · 6.277.0 c6632a1 · 6.278.0 6c1fe75 · 6.279.0 a6241f5 · 6.280.0 893b40b · 6.281.0 5611a4a · 6.282.0 11dc992 · 6.283.0 3fa417f · 6.284.0 a8f3df4 · 6.285.0 70d118b · 6.286.0 fa93f1b · 6.287.0 39b9dba · 6.288.0 8508186.
   Keep this list current: one line per release, appended at ceremony
   time.
4. A BISECT IS AN OPTION, NOT THE FIRST MOVE — it costs him an install
   per step. The artefact first (6.201.0), the scoreboard second, a
   rebuilt older zip only when both fail to name it.
5. EVERY RELEASE IN A STACK KEEPS ITS OWN VERIFY BLOCK below, so a
   failure can be attributed by which test fails, without reinstalling.

## Known-stale docs — deliberate, do not "fix"

- run-tests.sh's "forty-one suites" comment.
- GUIDE.md's "all 58 modules" wording (near line 679).

## Scoreboard — LL's rule, kept here (6.204.0 onward)

LL, on delivering this batch: "success for you is easily measured by
code we do not have to iterate. You give it to me; and I apply it. I
report back that there is no errors, you log this for yourself as win
to loss, or 1 to 0, and on up so we can track our joint winning streak.
So for each feature we solve, a win is defined by me returning to you
telling you the code just worked." THE RULE: one row per release; a
WIN is LL saying it just worked; a LOSS is any report that needed a
fix; a row stays PENDING until he says either. Never score a row from
this side — the only scorer is LL. Update the row in the same commit
as the fix when a loss lands.

| release | what it was | result |
|---|---|---|
| 6.204.0 | ⇪D takes the mouse; a detail pane | WIN |
| 6.205.0 | autocorrect: an inflection is a word (starts/allows/convinced) + `_G.autocorrectAdd` | LOSS — LL: starts/allows/convinced stayed, somethingg and `_G.autocorrectAdd` worked, statrs stayed statrs → fix 6.213.2 |
| 6.206.0 | ⇪5 scrolling capture keeps receipts; result on the clipboard | LOSS — the receipts worked and named it: slice 1 of 4 exit 0, "cannot write file to intended destination" (a dot-file in OneDrive, since 6.87.0) → fix 6.213.3 |
| 6.207.0 | an existing text box can be edited again | WIN |
| 6.208.0 | stall guard: a beach ball no longer costs the keyboard | WIN — forced stalls relaunched at 77 s and 73 s; one guard after every reload; no sudo |
| 6.209.0 | pomodoro 90% opaque + 🍅 done today | WIN |
| 6.210.0 | Submarine, soft to loud, over the last 30 s | WIN |
| 6.211.0 | the pomodoro sits beside the mini calendar | WIN |
| 6.212.0 | editor: line · oval · highlighter · counter | WIN |
| 6.213.0 | editor: spotlight · magnifier · paste image · add capture | WIN |
| 6.213.1 | stability pass: the stall guard's threshold 60 s / 10 s (was 20 / 5) | WIN |
| 6.213.2 | autocorrect: an inflected answer carries the typed ending (plugin/backend/signin) · pomodoro 30%/solid profile line | WIN — and LL chose statrs → starts anyway → 6.213.4 |
| 6.213.3 | ⇪5 slices go to a local folder, plain names (the OneDrive dot-file cause) | WIN |
| 6.213.4 | autocorrect: listed words first, then by-ending words in kind order (statrs → starts, adress/sceen stay) | WIN |
| 6.213.5 | ⇪⇧V edits in the OCR editor's window via `editor.open` (front, big, multi-line); the prompt is the degrade | WIN |
| 6.214.0 | 🕸 Hamsidian: the ⇪3 notes renamed in every visible string; ids, folder, services unchanged | LOSS — LL: "killed my keyboard and made every key execute some hammerspoon action. I was able to pause it." A latched ⇪ (6.162.1's class); he went back to 6.213.3 → 6.214.1 |
| 6.214.1 | 🌩 hyper storm guard: a latched ⇪ releases itself after 5 s and writes ~/.hammerspoon/.storm/storm-<epoch>.txt | LOSS — the test itself worked (released, file, report), but the report carried a stale ⚠️ and LL's bad test recipe (mine) exposed the count stalling behind a key-eating tool → 6.214.2 |
| 6.214.2 | 🌩 the storm guard counts keys from the ⇪ tap too (a tool that eats keys no longer hides them); a missing folder is no warning | WIN on the home Mac (LL: "6.214.2 home ✓", 184 autorepeats measured, no ⚠️) — the work Mac still owed; LL said "Go ahead" |
| 6.215.0 | 🔔 the degrade door: `core.degrade(tool, why)` → alert + ⚠️ line + ledger + `_G.degradeReport()`; the storm guard takes it first | pending |
| 6.216.0 | 📶 Bluetooth ⇪⇧7: paired devices, ⏎ connects/disconnects via blueutil; without it system_profiler lists and ⏎ opens System Settings | LOSS — LL: "locked the keyboard & took off like a banshee … wouldn't stop creating tabs", a field of "dododod…doesnt". NOT bluetooth: the autocorrect retype loop (doesnt ⇄ doesn), live since 6.10.0, reproduced on 6.215.0 by typing "doesnt " → fix 6.218.0. ⇪⇧7 itself is unscored |
| 6.217.0 | ✂️ init.lua trimmed 3,796 → 3,534 (no behaviour change) + RESOLVED-FEATURE-REQUESTS.txt generated into every zip | pending — never installed; 6.218.0 carries it |
| 6.218.0 | 🌩 autocorrect no longer reads its own retype: the guard drains by count, a 0.3 s held timer as the belt; ⇪Z shares the door; the suite plays macOS | pending — the storm IS gone (LL's report: "retype guard : 3 retype(s) · released by count 3 · by timer 0", teh → the, no tabs), but his words were "Doesnt't kinda works", which is the half 6.218.0 named and did not fix → 6.219.0. Asked him for the clean yes/no |
| 6.219.0 | ✏️ an apostrophe inside a word is not a word ending: the word list is not asked on a ' (doesn't, wouldn't, mightn't, oughtn't) | pending |
| 6.220.0 | 📐 the ⇪T task form fits: project fields two-up, a 760-pt ceiling, and the blue Create button pinned in a footer outside the scroller | pending — his screenshot shows it rendering: two columns, the Create button visible. Not scored |
| 6.221.0 | ⌘ in the ⇪⇧1 editor edits any mark whatever tool is armed (and a ⌘-click that misses creates nothing); the window's ⌘-drag narrows to its title bar | pending |
| 6.222.0 | 🧊 a drag whose release happened outside the editor window no longer sticks (the overlay that covered the whole image) | pending |
| 6.223.0 | 📐 the ⇪T form is drawn whole — the ceiling raised from 760 to 1400 pt so his eleven project fields need no scrolling | pending |
| 6.224.0 | 📋 `_G.clipboardReport()` — the newest item, every refusal by reason, saves ok/FAILED, and the poll with a clock and a suppressed count | pending |
| 6.225.0 | 🎯 the ⇪⇧V / ⇪⇧O edit window takes the caret — Lua focuses the hswindow a turn after bringToFront, bounded and reported | pending |
| 6.226.0 | 🔤 the OCR junk filter, tier 1: single characters and punctuation-only tokens dropped at the one door, plus `_G.ocrCleanHistory()` for the log he already has | pending |
| 6.227.0 | 🔖 ⇪⇧V keeps its query and its highlighted row across a rebuild; Home/End jump to first/last while the picker is up | pending |
| 6.228.0 | 🕵️ the file tracker is timed (wake-up vs write, apart), alerts past 120 ms, and can be switched off | pending |
| 6.229.0 | 🎯 the file tracker watches the folders inside his home folder, one watcher each — ~/Library is not one of them (60,115 wake-ups a day to keep 49 rows) | pending |
| 6.230.0 | 🔗 a symlink is not a second folder: ~/OneDrive and the CloudStorage folder are one tree and one watcher (his 6.229.0 report named it in 47 seconds) | pending |
| 6.231.0 | 🎵 the mini music player, ⇪⇧pad. — drop files on a corner card, ↑↓ / ⌘1–9 / space, repeat one or all, elapsed time, history | LOSS — LL: "Can't drop a file on the music player, a drag just puts it behind the player window." The drop — the whole feature — could never have worked: hs.webview has no drag-and-drop at all, and the card was built as a webview because a durable note said the opposite → fix 6.233.0 |
| 6.231.1 | 🔤 the player's page is RUN by the gate now (stage 3e, 55 checks, 12 mutations) — and it found a track name with an & or a < in it losing half of itself | pending |
| 6.232.0 | 🪟 the music card moves: ⌘-drag anywhere or a bare drag on its title strip, and it reopens where he left it (it was never in `_G.movablePanels`) | pending — LL: "Shortcuts fixed", which is not his win sentence and does not name the drag; ask |
| 6.233.0 | 🚚 a dragged file lands on the card — a canvas catcher under it, because hs.webview cannot take a drop and hs.canvas can (the opposite of what 6.231.0 believed) | LOSS — LL: "Turns highlighted blue so it seems to see the file but drop doesn't work." The catcher was right; the read after it threw → fix 6.235.0 |
| 6.234.0 | 🕘 thirty days of history, one row per file — the 60-row cap was the memory; days decide now, and the card shows 40 | pending |
| 6.236.1 | 🚨 a reader's error message is not a file — `select(2, pcall(f))` is the error when it raises, and a Lua error begins with a path (caught by the gate, never reached him) | pending |
| 6.236.0 | 🖥 a panel opens on the monitor you are looking at — the pointer outranks the front app's `mainWindow`, which is routinely the other display | pending |
| 6.235.0 | 🔒 the drop lit up blue and did nothing: a `table.concat` on a list of objects threw inside the dragging callback, where a throw is a silence — plus a `public.file-url` reader and a report that names what the drag carried | LOSS — LL: "Same results on music player", with the card reading "⚠️ .15194583 is not an audio file this can play". The reading WORKED; what it read was a file reference URL, not a path → fix 6.237.0 |
| 6.237.0 | 🆔 a Finder drag hands back `file:///.file/id=6571367.15194583` — a volume and an inode, no name and no extension — and a bookmark turns it back into the file (realpath does not) | **WIN** — LL: "Music player works!" (2026-09-17). Seven releases and three losses to get the drop working; the artefact that ended it was his own card |
| 6.238.0 | 🪟 the card reopens showing what is playing — the page says when it is ready instead of Lua pushing into a document WebKit has not parsed | pending |
| 6.239.0 | ⏪ ← → seek 5 s, ⇧← ⇧→ 30 s — his ask, in the same message as the win | pending |
| 6.240.0 | 💡 the shortcut hint card off on both Macs — two settings lines, no module code | pending |
| 6.241.0 | 🎯 the cloud folder is watched by its children — this config's own Logs folder was waking the module that writes to it | pending |
| 6.242.0 | 🧭 `_G.groundReport()` — what THIS Mac answers about the six surfaces the next releases need, with the release each answer decides | pending |
| 6.243.0 | 🔤 ⇪Z learns the correction HE just made — backspace over a typo, retype it, press ⇪Z | pending |
| 6.244.0 | 🗓 the ⇪⇧0 calendar is as tall as its content (768 → 494), the date and clock sit above the months, and it wears the music player's card | pending |
| 6.245.0 | 🔎 ⇪Y stopped sorting the whole archive to draw forty rows — the first keystroke of a search was building and sorting 60,000 entries on the main thread | pending |
| 6.246.0 | 🎯 ⇪⇧A acts on the file selected NOW — the panel had been one press behind since 6.65.1, and the title says so when it cannot re-read | pending |
| 6.247.0 | 🏃 a held arrow MOVES the grid overlay instead of rebuilding two NSWindows per keystroke — the cadence was the work | pending |
| 6.248.0 | 🌓 two scrims: 0.55 to read the letters on, 0 the moment you type — one number had been doing both jobs | pending |
| 6.249.0 | 🗓 the calendar's month-range label is gone and ‹ Today › sits where it was, at the big date's own left edge | pending |
| 6.250.0 | 🔤 ⇪/ can be searched for punctuation — the keys that name half this config were the keys its search box ignored | pending |
| 6.251.0 | ⌨️ the music card takes the keyboard when it opens — space works without a click, and the Console coming forward is the price | pending |
| 6.252.0 | ✂️ the landed grid box splits by letter (one in each half, longer side first) and ⌥halve is gone | pending |
| 6.253.0 | ✏️ the Scorp Pad is Hamsidian — one window, one name, the icon telling the two sides apart | pending |
| 6.254.0 | 🗑 the 4 PM Asana send and the + Capture / + Append rows are off — three switches, nothing deleted | pending |
| 6.255.0 | ⏲ ⌘D in the editor: five seconds to arrange the screen, then the whole screen lands on the shot — and the editor hides, with a belt that brings it back | pending |
| 6.256.0 | 🖥 ⌘F: the whole screen, now, with the editor out of the picture — and it waits a beat for the window to actually go | pending |
| 6.257.0 | 📄 the documents list finally names Word's documents — the file the app has open, asked of doc_memory once per session, written as a sixth column | pending |
| 6.258.0 | 🖼 ⌘O loads a prior shot onto this one and the canvas grows to hold both — the original stays at 0,0 so nothing already drawn moves | pending |
| 6.259.0 | 🎯 the dialog home is OFF on his word — nothing watches, nothing moves, nothing announces itself, and one settings line brings it back | pending |
| 6.260.0 | 📐 a live 1280 × 720 while you drag — white on 90%-opaque black, on the one selector this config owns (there was no readout to restyle; those numbers were macOS's) | pending |
| 6.261.0 | 🗑 the dialog home is deleted, not switched off — the module, its suite, its ⇪/ card and its two globals are gone on his word | pending |
| 6.289.0 | ⏯ the keyboard's own play/pause, ⏮ and ⏭ keys drive the music card while it has a queue, and pass through to macOS when it does not | pending |
| 6.288.0 | 🖥 the cheat sheet opens on the screen it resolved — a spot saved on the 4K was being clamped back onto the 4K by a helper that picks its own screen | pending |
| 6.287.0 | ✏️ the editor's text tool is a real text box — it wraps, ⏎ drops a line, the corner re-wraps and ⇧corner scales; it had only ever been a single line with a font size | pending |
| 6.286.0 | 🚪 the screenshot editor's marks survive EVERY way out — Esc, Cancel and ⇪⇧1 on another shot; only the Cancel button ever asked the page for them | pending |
| 6.285.0 | 🔔 the ⇪ watchdog stops crying wolf — a panel that says it is taking the keyboard is a handover, not a stuck ⇪, and only a real latch counts as one | pending |
| 6.284.0 | 🏷 an Asana team is pinned by its GID, so renaming it no longer costs the ⇪T picker — the fetch was always live, the stale half was the name we searched FOR | pending |
| 6.283.0 | 🧠 ⌥Tab offers the Hammerspoon Console from any desktop — the console block was the one listing that never fed the memory, and the memory is the only route to another Space | pending |
| 6.282.0 | 🕒 `_G.screenshotsReport()` stopped throwing — os.date refuses a float and `hs.timer.secondsSinceEpoch()` is one, so the report died at the `area` line in any session where ⇪4 had been pressed (since 6.264.0) | pending |
| 6.281.0 | 🔁 the green OCR pills stop: a screenshot that OCRs to nothing is remembered and not re-OCR'd for ever — the watcher had no way to stop offering a word-less image, and the report counted only successes so it read 0 through the whole runaway | pending |
| 6.280.0 | 🗑 a ✕ on every Hamsidian note deletes it to <Vault>/.trash — never erased, undoable, and it says how many notes still link to it | pending |
| 6.279.0 | 📓 `_G.todayReport()` — every tool that failed today, read back off disk so it survives a reload; the ledger had only ever been in memory | pending |
| 6.278.0 | 🔔 a 4 PM Asana send that fails is seen — an alert, a notification that survives Focus, and a sticky line in the report; it had only ever been a Console line | pending |
| 6.277.0 | 🔖 ⇪3 reopens the note you were writing in — the last note has been recorded on every open for releases and was read only when nothing was open | pending |
| 6.276.0 | 🆓 a cheat-sheet row that says a key is free now ASKS the live registry — ⇪⇧pad. had been advertised as available since the music player took it in 6.231.0 | pending |
| 6.275.0 | 📘 the install guide says what FAILURE looks like at every step, has a section to hand to IT, and HAMSIDIAN.md gains §7b on linking out (docs only) | pending |
| 6.274.0 | 🔔 ⇪4 can no longer fail without leaving a number behind — a refused alert is counted and its words kept, and ⇪4's routes are counted apart | pending |
| 6.273.0 | 🔌 ⇪⇧U can finally do all four things its card promises — `_G.service.call` hands back the provider's own values and all four call sites read one a slot late, since 6.180.0 | pending |
| 6.272.0 | 🗑 a ✕ on every 🕘 music history row forgets that track — by path, never by index, and it never plays the row it is removing | **WIN** — LL, 2026-09-20: "Pass on music player", and his report carried the proof: `forgot : 2 history row(s) removed with ✕ this session` |
| 6.271.0 | 🧪 the steps to test a release ship IN the archive as TESTING.md — seventy-two verify blocks existed and none of them was in the package | **WIN** — LL: "TESTING.MD · Pass", and he ran it: the first report in its own PASS/BLOCKED vocabulary, which found 6.180.0's bug |
| 6.270.0 | 🖼 the screenshot editor's tools move into two vertical rails — nine left, six right — and the window reserves their width so the shot is never squeezed to make room | **WIN** — LL: "Screenshot · Pass", on his third telling of an ask that had never been built |
| 6.269.0 | 🔗 the ⇪⇧U anchors card draws its eight rows — one key was misspelled since 6.180.0 — and a card with a title and no rows now names itself, with `_G.cheatSheetReport()` to ask | BLOCKED — LL: "Anchor · Blocked/Uncertain", with a screenshot. NOT a fail: `_G.cheatSheetReport()` came back clean on every line, and the card's rows sent him to ⇪⇧U, where he found that three of its four legs have never worked → 6.273.0. A release whose only claim was the CARD, scoring blocked because the TOOL behind it was broken |
| 6.268.0 | 🗑 the shortcut hint card is deleted, not switched off — the module, its suite, its ⇪/ card, its boot line and both profiles' settings lines are gone | pending |
| 6.267.0 | ⏱ the boot stops reading two OneDrive CSVs — the 90-day file history and the four months of sessions are read when they are first needed (350 ms of a 453 ms boot) | pending |
| 6.266.0 | 🧊 the frozen grid box: a panel the caller gave up on is never put back on screen — the retry hands the canvas back instead of showing it itself | pending |
| 6.265.0 | 🚨 ⇪4 captures again — 6.264.0's fallback to macOS's crosshair existed and was unreachable, because selectArea discarded the one value saying whether it drew | **LOSS** — LL, 2026-09-20: "hyper+4 is intermittently working". Not dead, INTERMITTENT — and his Console carries three `⚠️ an alert could not draw — another app's popup was mid-transition` lines, which is the same refusal class 6.265.0/6.266.0 are about → 6.274.0 |
| 6.264.0 | 📐 ⇪4 drags on our own selector, so the live 1280 × 720 is on the key he actually presses — the native magnifier and SPACE-to-shoot-a-window are the price | **LOSS** — LL: "Hyper+4 no longer works to screenshot." The selector's canvas can be refused by macOS and selectArea reported success anyway, so the key did nothing at all → fix 6.265.0 |
| 6.263.0 | ✏️ no box in any page this config draws asks macOS to spell-check it — its correction panel threw an uncaught exception inside one of our webviews and aborted the process (his own `.ips`) | pending |
| 6.262.0 | 🚨 ⇪⇧U no longer starts a task from inside another task's callback — the 6.196.1 use-after-free, twice, on the key he named | pending — and his two `.ips` files say it is NOT his crash: both are uncaught ObjC exceptions in Apple's code on macOS 27 beta (the menu-bar status-item scene; macOS's correction bubble in one of our webviews), with no Lua frame anywhere. The fix is real and stays; it is not the answer to what he saw |

Running total: 18 wins · 10 losses · 1 blocked — count the rows; from
6.215.0 on except the fifteen wins and eight losses named in the table
above. (The enumeration that used to sit here stopped at 6.239.0 and was
seventeen releases stale, which is a scoreboard that cannot be read;
count the rows instead.)
🏁 6.237.0 CLOSED THE MUSIC DROP: 6.231.0 → 6.237.0, three losses, and
every one of them at the boundary with macOS where the gate is blind
(webview cannot take a drop · a throw in a dragging callback is silent ·
Finder hands over an inode). THE METHOD THAT ENDED IT, both times it was
used: ask for the artefact and put the cause IN THE CARD. His screenshot
named the inode; his screenshot named the empty redraw. NEW HABIT, owed to
him and stated to him (2026-09-17): every release is labelled KNOWN GROUND
(the gate can see it — expect it to work) or NEW GROUND (a macOS surface
this config has not touched — expect a round), and on new ground the FIRST
release is the probe that prints what macOS actually answered, never a fix
built on a belief.
6.208.0's stall guard was FIELD-PROVEN 2026-09-13: a ⇪Y Chrome-history
search beachballed the Air 72 s, the guard killed and relaunched it, the
next boot announced it (LL: "fortunately hammerspoon caught itself"). LL is on
6.214.2 on the home Mac (scored 2026-09-12: "6.214.2 home ✓ ·
6.213.4 ✓ · 6.213.5 ✓ · work Mac later"), then "Go ahead" → 6.215.0
built. The work Mac's storm report is still owed, on 6.215.0 now.

## Open items — update as they move

- 🔗 THE CHEAT-SHEET PASS, 2026-09-20 (LL: "please make a good pass down
  the cheat sheet"). WHAT IT FOUND, and what is left:
  1. ✅ THE 🔗 ANCHORS CARD WAS EMPTY — SHIPPED AS 6.269.0. The durable
     rule is above. Eight rows under `rows =` instead of `entries =`,
     invisible to the 6.196.0 auditor by design.
  2. 📏 MEASURED AND CLEAN, so it is not re-asked: 106 ⇪ combos bound
     across every route; ZERO dead key promises (every key printed on a
     card is really bound); zero misattributed; 71 Console commands
     named on cards and all 71 real. ⇪⇧Z is the only free combo left —
     the keyboard is genuinely full.
  3. 🗳 OPEN, HIS CALL: four visible strings still tell him to use
     Obsidian — ⇪3's card row whose KEY COLUMN is the word "Obsidian",
     ⇪N's ⌘⇧S row ("Obsidian opens them"), `_G.vaultReport()`, and the
     vault summary — plus the ⇪⇧U row 6.269.0 has just made visible.
     Nothing in this config launches, links to or requires Obsidian
     (grep for `obsidian://|open -a Obsidian|md.obsidian`: zero hits);
     it is a FILE-FORMAT lineage so his notes stay portable. The
     behaviour stays either way; the question is only the wording, and
     it is one release when he answers.
  4. ❌ DIALOG HOME FREED NO KEYS, asked and answered: at its last commit
     (f16e286) it had no `hyperAddShortcut`, no `hs.hotkey` and no
     `hyperBind` — its card's left column held WORDS (off, back on,
     auto, capture, default, scope, sheets, reset), not combos. If he is
     remembering a key for "make a window stay put", the candidate is
     win_pin, removed 6.166.0, which held ⇪⇧U — freed then and spent
     again by anchors in 6.180.0. Ask before building.

- 📥 LL'S QUEUE, 2026-09-20 (asked in two messages; NONE built yet,
  and the order below is MINE until he says otherwise — removals and
  bugs first, features after, one change per release):
  1. ✅ SHORTCUT HINTS DELETED — SHIPPED AS 6.268.0. The durable rule is
     above (6.261.0's block). The one thing that was NOT foreseen when
     this was queued: `hint.coreRows` fed sixteen rows of
     RESOLVED-FEATURE-REQUESTS.txt, so the module was holding data that
     was not its feature — it moved to build-feature-list.lua, its only
     reader, and the generated file is byte-for-byte identical to
     6.267.0's in that section.
  2. ✅ ⇪T IS MISSING FROM THE ASANA CARD. His screenshot: the ⇪/ card
     lists ⇪A ⇪B ⇪C ⇪L and NOT ⇪T, which is the key that CREATES a
     task — the tool's main door, undocumented on its own card.
     🔎 AND THE AUDITOR CANNOT SEE IT: 6.196.0's cheat-sheet audit flags
     MISATTRIBUTION, never ABSENCE, on purpose (§0.4's migration map binds
     a dozen keys outside hyperAddShortcut, so "is it bound at all" would
     report every one as dead). So a key with no row is invisible to the
     gate. The release adds the row AND asks whether the audit can now be
     run the other way for keys bound through hyperAddShortcut ALONE,
     where the owner IS known — a bound key with no cheat-sheet row is a
     feature he cannot find.
  3. 🗑 HAMSIDIAN HAS NO DELETE. LL: "I don't understand why there is no
     delete. Can you fix this?" It is not a bug, it is a DECISION nobody
     revisited: vault.lua's header says "No file delete or rename —
     Finder and Obsidian do", written when the vault was new. He is
     asking for it now. Design answer owed with the release: a note goes
     to the TRASH (hs.fs has no trash; /usr/bin/osascript tell Finder to
     delete, or a move into <Vault>/.trash which Obsidian already
     ignores), never os.remove — an unrecoverable delete of his writing
     is the one failure with no way back.
  4. 📝 "SCRATCH" IS STILL ON SCREEN — ASKED TWICE NOW (LL, 2026-09-20 and
     again 2026-09-22: "I still want to remove the scratch note and
     consider any entry as an entry into Hamsidian"). 6.253.0 renamed
     every visible string BUT the note list's own section header, which
     still reads 📝 SCRATCH NOTES (vault.lua's drawRows).
     🔎 THE ASK UNDER THE ASK IS A DATA DECISION, not a rename: a scratch
     TAB is not a .md note — it lives in scratch.json and only becomes a
     file on ⌘⇧S. "Everything a Hamsidian entry" means the two sections
     become ONE, which means deciding when a tab becomes a file.
     🗳 THE ONE QUESTION, put to him in 6.275.0's verify block E2, because
     the two answers are different releases and both are defensible:
       (a) EVERY TAB IS A FILE FROM THE MOMENT IT IS MADE. One list, one
           kind of thing, searchable by ⇪D and openable in any Markdown
           editor immediately. COST: every keystroke eventually writes a
           .md into OneDrive (today it is one local JSON), an untitled
           scratch needs a filename the second it exists, and ⌘W on a
           throwaway leaves a file behind rather than nothing.
       (b) A TAB STAYS A TAB UNTIL ⌘⇧S, and only the HEADER and the
           wording change. COST: two sections remain, which is the thing
           he is objecting to — so this is the cheap answer, not the one
           he asked for.
     📏 MY RECOMMENDATION IF HE DOES NOT ANSWER: (a), but with the file
     written on the FIRST PAUSE rather than the first keystroke, and an
     auto-name from the first line (the pad already names exports that
     way), so a throwaway is a file he can delete rather than a prompt he
     has to answer. Do NOT build it before he says which — 6.201.1's rule
     about what a store already holds applies to scratch.json, which has
     his text in it.
  5. ✅ THE EDITOR'S TOOLS DOWN THE SIDES — SHIPPED AS 6.270.0, on his
     THIRD telling ("Ever release that I've installed, has not had...").
     He was right every time: all eighteen buttons were in ONE wrapping
     header strip and there was no rail in the page at all. The durable
     rule is above, and the half worth carrying is that the sizing was
     the ask — the window reserved 28 points of chrome, so there was no
     ROOM for a rail even in principle.
  6. 🔎 NOTHING NAMES THE @ SEARCHES. LL: "there's nothing that tells me
     what @ searches there are." There are FOURTEEN (clip · cmd · shots ·
     note · asana · ocr · images · doc · file · pad · scratch · vault ·
     web · tool) and the only place they appear is as section headers in
     the results. The fix is at the point of use: typing "@" alone in
     ⇪D lists every source with its tag and what it holds.
  7. ⌘ ⌥⌥ TO THE MENU BAR. LL: "doesn't option+option move me to the
     application bar? I made this request several releases back." He is
     right that he asked — it is the ⌘⌘ / ⌥⌥ pair from 6.198.0 and it was
     NEVER BUILT. 🔑 THE MACHINERY EXISTS AND IS PROVEN ON HIS MAC:
     editor_picker.lua has a full double-tap-modifier engine (⌃⌃, with
     per-side keycodes, intruder types and a flagsChanged tap). ⌥⌥ opens
     menu_search (⇪., the front app's own menus); ⌘⌘ opens the clipboard
     history. One release each, the tap engine LIFTED out of
     editor_picker rather than written twice.
  9. 🎵 ⌥TAB SHOULD LIST THE MUSIC CARD (LL, 2026-09-20, with his
     6.272.0 pass: "Can I add it to Opt+Tab?"). Yes, and it is small:
     window_switcher serves its rows from `altTab.known`, and the card is
     a real webview window, so it is a question of whether our own panels
     are offered at all — today they are not, deliberately (a picker you
     ⌥Tab into is a picker you cannot ⌥Tab out of). 🗳 HIS CALL, and ASK
     BEFORE BUILDING: just the music card, or every panel this config
     draws? The music card is the only one that keeps PLAYING when it is
     not in front, which is the argument for doing it alone.
  8. 🖥 ⇪7'S macOS LINE WANTS MORE DETAIL. His screenshot reads
     "macOS 27.0 (26A5388g)". Decide what "more" is before building:
     the marketing name, that it is a BETA, the Darwin kernel version,
     and the install date are all readable without a binary.

- ⚙️ HIS FOUR MISSPELLINGS, MEASURED AGAINST THE REAL WORD LIST
  (2026-09-20, he typed them on purpose: "I have deliberately missed
  what I thought were common Mispellings and the two of down and right").
  Run against web2 (236,007 lines) through the module's own lifted
  `acSpellCorrection`, so this is measurement, not reading:
    · donw  (4 letters) — SILENT. Below `acSpell.minLen` (5). At 4 it
      would answer "down"; 5 is a MEASURED floor (6.200.0: at 4, "repo"
      became "rope"), so this is the rule working as decided.
    · wiht  (4 letters) — SILENT, and silent at ANY floor: "whit" and
      "with" are both one swap away and both are words. Two candidates
      is a guess and this rule never guesses.
    · rihgt (5 letters) — ANSWERS "right". It should have corrected.
    · Mispellings — ANSWERS "Misspellings", capital kept. Should have
      corrected.
  🔎 SO TWO OF THE FOUR ARE EXPLAINED AND TWO ARE NOT, and the missing
  fact is WHICH APP he typed them in — `acSpell.offIn` holds every
  terminal and code editor, and the word list is also silent while it is
  still loading, in a password field, and on a Mac that cannot answer
  about Secure Input. ASK FOR `_G.autocorrectReport()` and the app name
  before theorising further (6.201.0). "Sometimes it does work" is the
  5-letter floor, exactly.


- ✏️ macOS'S CORRECTION BUBBLE ABORTS THE PROCESS INSIDE OUR WEBVIEWS —
  NEXT RELEASE, and it is the only half of his two crashes that is on a
  surface we own. His 15:58:26 `.ips`: `showCorrectionPanel` →
  `NSSpellChecker` → `NSCorrectionPanel` → uncaught ObjC exception →
  abort. THE FIX IS ONE ATTRIBUTE SET, in every page this config draws:
  `spellcheck="false" autocorrect="off" autocapitalize="off"` on every
  textarea, input and contenteditable — Hamsidian/vault, capture pad,
  note pad, the screenshot editor's text notes, the OCR/`editor.open`
  box, the task form, unified search, the music card. It costs him
  nothing he uses: our OWN autocorrect already runs over those boxes
  (two correctors on one field was the state before), and macOS's red
  squiggle is not a thing he has ever asked for. 🔎 COUNT WHAT IS LEFT:
  a source sentry per page, because a NEW input added later brings the
  panel back — that is the whole class, not the eight boxes. 📏 NAMED:
  the 15:08 crash (the menu bar status item) has NO fix from here; it is
  AppKit connecting its own scene and nothing of ours is on the stack.
  Say so rather than shipping something that looks like an answer.
- 🪟 ⇪⇧V'S EDIT WINDOW BRINGS FINDER AND CHROME FORWARD, ALTERNATELY, AND
  THE POINTER JUMPS AMONG MONITORS (LL, 2026-09-20: "When I use the edit
  function of the copy history, finder and Chrome will alternately be
  brought forward, as examples. Also it jumps among monitors"). NOT
  DIAGNOSED, NO CODE — the artefact first, and this one has a
  one-keystroke experiment that decides it outright.
  🔎 READ, NOT PROVEN, and it is a TWO-MODULE interaction where each
  module is correct alone (6.221.0's rule: read the other global watcher
  before blaming the one you are looking at):
    1. ⏎ on a row hides the chooser, and macOS restores focus to whatever
       was frontmost BEFORE it — Finder, or Chrome.
    2. `editor.open` shows the webview and starts 6.225.0's caret chase:
       `win:focus()`, up to `editorFocusTries` (4) × `editorFocusDelay`
       (0.08 s).
    3. FOCUSING A HAMMERSPOON WINDOW ACTIVATES THE HAMMERSPOON APP —
       6.251.0 named that price in the music card and it is unpaid here,
       because this module's report never mentions it.
    4. Each activation and each bounce back is an APPLICATION SWITCH, and
       modules/mouse_follows.lua is ON by default (`mf.enabled = true`)
       with an app watcher plus an AXFocusedWindowChanged observer: it
       WARPS THE POINTER to the newly focused window every time.
  So a focus fight between the chooser's restore and our chase reads
  exactly as "Finder and Chrome alternately brought forward", and because
  those two live on different displays, the pointer warping after each
  switch is "it jumps among monitors". Both halves of his sentence, from
  one mechanism.
  🧪 THE EXPERIMENT, and it is binary: `_G.mouseFollows.stop()` (or
  `settings = { mouse_follows = { enabled = false } }`), then edit a
  clipboard entry again. If the monitor-jumping stops and the app
  flapping stops, mouse_follows is the amplifier and 6.225.0's chase is
  the trigger — two releases, in that order. If the apps STILL flap with
  it off, the chase alone is the whole bug and mouse_follows is
  innocent.
  📋 THE ARTEFACTS: `_G.ocrReport()`'s "edit box :" line names which of
  the four states the chase reached ("caret placed on try 1" is healthy;
  a high try count or "gave up" is the fight); `_G.mouseFollowsReport()`
  gives "jumped : N time(s)" and a "last : <app> → <app>" line, so a
  BURST of jumps at the moment of one edit is the proof.
  🗳 THE FIX SHAPE IS NOT DECIDED and must not be guessed: candidates are
  (a) the chase stops the moment the window IS key AND does not re-ask
  after a bounce, (b) the chooser is hidden and its focus restore allowed
  to settle BEFORE the editor is shown (an ordering change, 6.246.0's
  shape), (c) mouse_follows stands down for a short grace after any
  Hammerspoon activation, the way it already stands down on a mousedown.
  (c) is the widest and is NOT the first move. 🚨 AND DO NOT BUILD ON
  THIS PARAGRAPH: it is a reading, not a verdict — 6.262.0 is what a
  correct fix for a plausible mechanism costs when nobody asked for the
  artefact first.
- 🔔 ⇪4 INTERMITTENT — THE INSTRUMENT SHIPPED AS 6.274.0, THE CAUSE IS
  STILL OPEN (LL, 2026-09-20: "hyper+4 is intermittently working"). NOT
  diagnosed, and deliberately not guessed: every silent exit on that path
  was read and all of them already answer `false, why` (6.265.0 closed
  that class), so nothing in the source names it. What was missing is a
  per-outcome COUNT, which is what 6.274.0 adds.
  🔎 THE THREE CANDIDATES, in the order his report will rank them:
  (1) macOS REFUSING the selector canvas — his beta does this, and the
  fallback to `screencapture -i` then gives him a crosshair with no size
  box, which could read as "it worked" or as "it did something odd";
  (2) the SCREENSHOTS FOLDER missing at that moment — it is in OneDrive,
  `ensureDir` returns with a message and nothing else, and that message
  is an alert, which his Mac is demonstrably refusing sometimes;
  (3) something on the path that is not visible from the source at all.
  📋 ASK FOR: `_G.screenshotsReport()`'s "routes :" line and its ⚠️
  follow-ups, and `_G.alertReport()`, after a full day — plus the one
  sentence in D1 of the verify block (what he actually SEES when it
  fails), because "nothing happened" and "macOS's crosshair appeared"
  are opposite answers and the fix differs for each.
- 🖱 TRACKPAD HYPERSENSITIVE (LL, 2026-09-20: "Something is making my
  trackpad hypersensitive"). NOT diagnosed, NO code — the artefact first
  (6.201.0). Read, not proven, and the reason it is NOT obviously ours:
  nothing in this config posts, scales or re-posts a mouse-MOVE or
  scroll event. The only pointer WRITES are absolute jumps at a keypress
  (mouse_grid's landing and nudges, mouse_follows ⇪1, menubar_items,
  screenshots' selector centre); window_move taps leftMouseDragged but
  moves a WINDOW, not the pointer; the cheat sheet reads scroll deltas
  and never posts one. So a config that makes the pointer JUMP is
  plausible and a config that makes it FASTER is not, on a read.
  ASK, in this order: is it the pointer speed or three-finger drag
  behaviour · does it happen with Hammerspoon QUIT (the one test that
  separates us from macOS 27 beta) · System Settings › Trackpad ›
  Tracking speed, and Accessibility › Pointer Control › Trackpad Options
  › three-finger drag (still unanswered from 6.232.0, and still the
  desktop-jumping suspect) · `_G.mouseFollowsReport()` and
  `_G.mouseGridReport()`. He is on a BETA OS that has already aborted
  his process twice from inside AppKit.
- 📈 THE BOOT TIMELINE CAME BACK, AND 6.276.0–6.280.0 ARE NOT IN IT
  (2026-09-25, LL's own `boot_cost-*.csv`, the artefact asked for since
  the rollback). One row per version change, his Mac:
      6.266.0 453ms · 6.272.0 105ms · 6.275.0 590ms · 6.281.0 190ms
  🚨 THE GAP IS THE FINDING: between 6.275.0 (09-23 04:04) and 6.281.0
  (09-24 20:38) there is NO ROW AT ALL. 6.276.0, 6.277.0, 6.278.0,
  6.279.0 and 6.280.0 never recorded a boot on this Mac. A rollback
  shows up in this file when it happens — 09-19 has 6.264.0 → 6.246.0 →
  6.264.0, three rows — so "he installed them and went back" would be
  visible and is not.
  🔎 WHICH REFRAMES "I purposely rolled back so I could use Hammerspoon".
  It cannot mean he rolled back FROM 6.276.0–6.280.0 on this Mac,
  because none of them ever ran here. The likeliest reading, and it fits
  the dates exactly, is the DELIVERY: those are the releases delivered
  during the empty-archive run, so there may have been nothing
  installable to install. ONE ALTERNATIVE, and it must not be waved
  away: boot_cost writes its row on a HELD TIMER AFTER the warm phase,
  so a build that died or hung BEFORE warm would leave no row and would
  also be "unusable". Those two are opposite facts and the timeline
  alone cannot separate them.
  🗳 SO ASK, DO NOT GUESS (6.201.0): did 6.276–6.280 ever get as far as
  ~/.hammerspoon on this Mac? `sed -n 7p ~/.hammerspoon/init.lua` after
  an install is the check, and it is in INSTALL.md already. Until that
  is answered, "what made 6.276–6.280 unusable" is not an open BUG — it
  may be an open DELIVERY.
  📏 AND THE NUMBERS ARE NOISY, so no release is scored off them: one
  boot each, 105 ms and 590 ms on either side of the same lazy-store
  code. What the series does support is the 6.267.0 step — every boot
  from 6.228.0 to 6.266.0 sits in a 359–478 ms band, and both post-6.267
  builds that recorded a row are far under it.

- 📥 LL'S REPORT, 2026-09-25 — SIX THINGS, NONE BUILT, and the order
  below is MINE (the crashing report jumped them all as 6.282.0):
  1. ✏️ THE  ⇪⇧1 EDITOR'S TEXT TOOL IS NOT A TEXT BOX — FOUR ASKS THAT
     ARE ONE RELEASE. His words: it must WRAP; the font size must change
     independently of the box and the box independently of the font;
     RETURN must drop a line instead of resizing; and dragging the box
     SMALLER must re-wrap the text rather than grow it ("so I may need
     to hold shift down or some other solution"). Today a text note is a
     single line whose SIZE handle scales the glyphs — 6.188.0 built the
     handle as a scale, which is why every one of those four is the same
     defect seen from four sides. THE DESIGN QUESTION TO SETTLE FIRST,
     because it decides the data: a wrapped box needs a WIDTH stored per
     note and a font size stored apart from it, so `snapNote`, the undo
     rows and the saved-file draw all change together. His "hold shift"
     suggestion is the right shape for the corner handle — plain drag
     re-wraps, ⇧drag scales — and it is worth asking him to confirm.
  2. 🚨 "CLOSING THE EDITOR DUMPS THE MOST RECENT EDITS SO I LOSE ANY
     CHANGES" (his annotated screenshot). 6.189.0 promises the opposite:
     `ed.kept` holds { path, img, notes } on cancel and restores them on
     the next open of the SAME path. So either that slot is not being
     filled, or it is not being READ, or he means Cancel should SAVE.
     NOT DIAGNOSED — ask which key he pressed (Esc, ⌘W, the Cancel
     button, or ⇪⇧1 on another shot, which 6.256.0 showed tears the
     editor down) and whether reopening the same screenshot brings the
     marks back. Those are three different bugs and one is not a bug.
  3. 📐 "Screenshot editor kinda worked once then stopped. I don't see
     the pixel size but it does seem to be taking the screenshots."
     TWO CLAIMS IN ONE LINE and they may be one fault: the size readout
     is drawn by `shots.drawSize` on OUR selector, and a Mac that fell
     back to `screencapture -i` gets a crosshair with no box — which is
     exactly "taking the screenshot, no pixel size". 6.274.0 built the
     count that separates a refusal from his own settings line, and
     6.282.0 is what makes that count readable. HIS `routes` LINE
     DECIDES IT; do not guess before it arrives.
  4. ⌨️ ⌥TAB DOES NOT SHOW THE HAMMERSPOON WINDOW unless he is already on
     that desktop. This was scored RESOLVED WITHOUT CODE on 6.215.0
     ("Alt+tab Success. Shows Hammerspoon now") and has regressed or
     never generalised. The 6.152.0 rule names the mechanism: macOS AX
     never returns another Space's windows from `app:allWindows()`, so
     the switcher serves them from `altTab.known`, a memory fed by every
     listing — a window on another desktop is only there if a listing
     ever saw it. First suspect is therefore the memory, not the read.
     `hs.console.hswindow` stays BANNED there (6.160.3).
  5. 🖥 THE CHEAT SHEET OPENS ON THE WRONG SCREEN "sometimes", AND IS
     NOT FRONTMOST UNTIL HE MOVES IT. The first half is 6.236.0's
     territory and that release added the instrument for it:
     `_G.screenReport()` names the rule that placed the last panel and
     what each candidate answers. ASK FOR IT AT THE MOMENT IT HAPPENS —
     "sometimes" is a count, not a sample (6.274.0). The SECOND half is
     new and is not the same bug: a panel that is up but not frontmost
     until dragged is 6.225.0/6.251.0's up-vs-front-vs-key distinction,
     on a surface that has never been audited for it.
  6. ⚠️ AND HIS CONSOLE CARRIES ONE LINE NEITHER OF US ASKED FOR:
     `⌨️ ⇪ released by the watchdog — held 8s with no key event and no
     F18 keyUp (release #1) — musicPlayer had taken the keyboard.` That
     is 6.251.0's price (taking the keyboard activates Hammerspoon)
     colliding with the 6.162.1 timed hold: the card took the keys, so
     no key event reached the ⇪ tap, so the watchdog judged the hold
     abandoned. It RECOVERED, which is the guard working — but a panel
     that takes the keyboard should be telling the hold it is alive
     (`_G.hyperTouch()`), the way every text panel does the 6.165.1
     handshake. Its own release; the music card is the only panel that
     takes the keys today, so the class is one module wide.

- ⚠️ THE ASANA TEAM NAME DOES NOT MATCH, AND IT IS BOTH MACS
  (2026-09-24, the home Mac's own boot log; it was in the work Mac's
  before that, and was filed here as a work-Mac thing). The NONBREAKING
  block carries `⚠️ Asana team not found by name: "| 2. SAC Library Team
  Member Projects & Tasks |"`. Lees-MacBook-Air prints it too, so it is
  NOT per-machine drift — the string in the config does not match the
  string Asana holds, anywhere.
  🔎 READ, NOT GUESSED, and it narrows the suspects sharply:
  asana_comments.lua:69 configures TWO names and only the SECOND warned,
  so team 1 matched and `#asanaTeamGids > 0` — which means the
  whole-workspace FALLBACK at :122 never fires. The comparison at :97 is
  already `:lower()` AND trimmed at both ends on BOTH sides, so the
  warning's own advice ("check spelling/spacing") is partly stale: outer
  whitespace and case CANNOT be the cause. What is left is the inside of
  the string — the `&` (Asana may hold "and"), a doubled or
  non-breaking space, the pipes, the number — or a team his token
  cannot see.
  📏 WHAT IT COSTS, exactly, so it is not over- or under-sold: that
  team's members are absent from `_G.asanaTeamMembers`, whose one
  consumer is ⇪T's assignee suggestions (task_form.lua:148). A name
  that is not on the list STILL SUBMITS — the module says so in its own
  comment and `_G.asanaSubmitTask` validates properly. So it is a
  shortened picker, not a broken door, which is why it has survived in a
  boot log for this long.
  🗳 AND HE ASKED THE RIGHT QUESTION — "I think I changed the Team
  name. But why wouldn't it pull that change?" — so here is the answer,
  because it decides the fix. IT DOES PULL. `fetchAsanaTeamGids` asks
  Asana's live API for `/teams?opt_fields=name` on every boot; the list
  it compares against is always current. What is STALE is the other
  side: the name it is LOOKING FOR is a literal in asana_comments.lua:69.
  Asana's answer is fresh and our question is not, so renaming the team
  in Asana is exactly what breaks it — the config goes on hunting for
  the old name and says, correctly, that no team has it.
  🔑 WHICH MAKES THE REAL FIX NOT A RENAME. A hardcoded name that only
  he can change, in a file he has said he will not edit (6.267.0), is a
  default that is wrong the next time he reorganises Asana. The
  release-shaped answer is to stop asking by name where it can: match on
  the TEAM GID once resolved, or fall back to the whole workspace with a
  line that SAYS so, rather than silently shipping a shortened picker.
  🔎 ASK FOR THE ARTEFACT BEFORE CHANGING A STRING (6.201.0): the fix
  is a one-line rename and a WRONG rename is silent — it would warn
  identically. So it waits on Asana's OWN name for that team (his Asana
  sidebar, copied exactly). 🔒 NOT by a curl with his token: the token
  lives only in secret.lua and never in a process argument list. 📋 THE
  RELEASE-SHAPED ANSWER, when its turn comes, is `_G.asanaTeams()` — the
  module already fetches `/teams?opt_fields=name` and throws the list
  away; printing what Asana ANSWERED beside what we asked for is the
  instrument, and it makes the rename unguessable.

- 🔄 ASANA AUTO-REFRESH EVERY 15 MINUTES (LL, 2026-09-20, with a draft:
  a `hs.timer.doEvery(900)` that activates Asana, posts ⌘R and activates
  the previous app back). WANTED — but not as written, and the design
  question goes to him before any code. WHAT IS WRONG WITH THE DRAFT,
  each a rule this project already has: (1) `hs.eventtap.keyStroke`
  POSTS, so that ⌘R arrives back through our own taps as typing —
  6.218.0, and it needs `_G.withInjection` or it is a keystroke our
  autocorrect and key trail both see; (2) it STEALS FOCUS twice every
  fifteen minutes with 0.6 s of nobody-owns-the-keyboard in between, so
  a ⌘R can land in whatever he clicked into mid-flight; (3) the nested
  `doAfter`s are unheld and unslotted — 6.196.1's shape in hs.timer,
  which is exactly what 6.198.0 found in power_tools; (4) no switch, no
  report, no degrade when Asana is not running or refuses.
  🔑 THE DESIGN THAT COSTS HIM NOTHING is `app:selectMenuItem({"View",
  "Reload"})` — it reaches the app WITHOUT activating it, so no focus
  theft, no posted key, no injection guard, nothing to put back. ASK FOR
  THE ARTEFACT FIRST (6.201.0): `hs.inspect(hs.application.get("Asana")
  :getMenuItems())` in the Console names the real menu path, and whether
  that app has one at all decides the release. Fall back to the
  activate-and-⌘R shape only if it does not, and then say the cost out
  loud. Also ask: PAUSE IT WHILE HE IS TYPING? A reload that discards a
  half-written comment is worse than a stale board.

- ✅ DOCUMENTS YOU WORKED IN — NAMED AND SHIPPED AS 6.257.0. LL, with two
  screenshots: "It's not showing the documents I just worked on … Am I
  misunderstanding how this works?" He was not: ⇪0 typing "Word" answered
  `Microsoft Word — 5m 40s`, an app with no title beside it, and the whole
  documents view was derived from that title. The durable rule is above.
  STILL OPEN AND ITS OWN RELEASE WHEN HE ASKS: an app OUTSIDE doc_memory's
  ten (Sublime, a browser) is still named by its title, which is right —
  AXDocument is the only honest answer and those apps do not give one.

- ✅ A LIVE SIZE READOUT — SHIPPED AS 6.260.0 (LL, 2026-09-19, under a
  heading reading "Doc watcher:"): "show a live 1280 × 720 in white on a
  90 %-opaque black box", read with his screenshot-editor item 4
  ("Change the pixel measurement tool numbers to solid white in a black
  box that is 10% translucent"). The durable rule is above; the short
  version is that there was nothing to restyle and it had to be built.
  ✅ ⇪4 IS ON OUR SELECTOR — SHIPPED AS 6.264.0 on his word ("I wanted a
  visual that shows the pixels measurements better"), with the native
  magnifier and SPACE-to-capture-a-window given up and named.
  STILL OPEN, EACH ITS OWN RELEASE WHEN HE ASKS: the SCREENSHOT EDITOR'S
  own drags (the Spotlight veil, the oval, the highlighter) have no
  readout either and should get the same one — the three pure functions
  are `shots.*` and published nowhere, so that release either lifts them
  into a service or writes the editor's own; and ⇪4 keeps macOS's HUD
  until he says he would rather have ours than the native magnifier and
  SPACE-to-capture-a-window.

- 🧭 THE NINE (LL, 2026-09-18, on the batch he reported after 6.245.0:
  "go & build in that order. Prep each item to roll out as I come back
  and say next"). ONE CHANGE PER RELEASE, built back to back, and he
  installs ONE ZIP AT A TIME — the zip for release N is built from N's
  commit and carries everything before it, so a break still names its
  version. THE ORDER, his: 1 ⇪⇧A on the current selection ✔ 6.246.0 ·
  2 grid arrow cadence ✔ 6.247.0 · 3 grid translucency ✔ 6.248.0 ·
  4 the calendar header ✔ 6.249.0 ·
  5 cheat-sheet punctuation search ✔ 6.250.0 · 6 the music card takes the
  keyboard ✔ 6.251.0 —
  keyboard · 7 the yellow box splits by letter (⌥halve gone) ✔ 6.252.0 ·
  8 the Scorp Pad renamed Hamsidian ✔ 6.253.0 · 9 the three removals ✔ 6.254.0
  (the 4 PM
  Asana send, the Capture row, the Append row).
  🗳 DECIDED BY ME, STATED TO HIM, because he said go rather than
  answering: (7) halves along the box's LONGER side, two letters, and
  it re-splits so it repeats like ⌥+arrow did — the cost is two
  alphabet keys captured while the landed badge is up, which is the
  6.192.0 rule's price, named. (9) nothing is deleted: the stores stay,
  ⇪space still searches them, only the DOORS go, each behind a settings
  knob. (6) the card takes the keyboard on its own key and hands it
  back on Esc — and that makes Hammerspoon the active app, which is the
  same mechanism as the console jumping forward.
  ❓ STILL ANSWERED BY NOBODY, asked twice now: the three-finger-drag
  setting (the desktop-jumping suspect), how he unpauses after ⇪',
  `_G.begoneProbe()` with Notification Center open. ("Doc watcher;;" came
  back on 2026-09-19 as a HEADING over the live-size-readout ask — see
  📐 A LIVE SIZE READOUT above — so it is no longer an open question, and
  what it heads is being built rather than asked about again.)

- 🧭 THE GROUND PROBE IS THE INSTRUMENT FOR THE NEW-GROUND HABIT
  (6.242.0, modules/ground_probe.lua, no key). `_G.groundReport()` asks
  what THIS Mac answers about six surfaces and writes the RELEASE each
  answer decides beside it — Accessibility · Secure Input · the focused
  element's role / AXSelectedTextRange / AXBoundsForRange · a bounded
  walk of the front window's clickable elements · whether Spotlight
  still holds ⌘Space · whether a flagsChanged tap can be made. It
  changes nothing: no key, no store, no tap left running, and the only
  boot work is one `defaults read` in a task on a held timer.
  🟥 THE ROW THAT DECIDES A FEATURE OUTRIGHT is AXBoundsForRange, and
  ITS ANSWER IS PER APP: no rectangle means a pink underline cannot be
  painted in that app and the alert is the whole feature there. Ask for
  the report from Chrome, Asana and Mail before building the doubled
  word — one answer is not the answer.
  🚨 AN ABSENT HOTKEY IS NOT A DISABLED ONE: macOS writes a shortcut
  into com.apple.symbolichotkeys only when it is CHANGED, so a Mac
  nobody has touched has no 64 block and Spotlight still owns ⌘Space.
  Three answers, not two. `gp.parseSpotlight` is PURE and reads 64's OWN
  block, stopping at the next key — and the first check on that used a
  fixture where both implementations agree, passed, and proved nothing
  (6.230.0's one-hop chain, in a parser). A 64 entry with no flag of its
  own is the only fixture that tells them apart.
  📏 `gp.axCount` is bounded four ways (elements · depth · ms · children
  per element) and NAMES which bound bit, because it walks the AX tree
  on the main thread; a count taken under a bound prints as a FLOOR
  (6.197.2). Every bound is driven in the suite by a tree bigger than it
  — a check that a budget EXISTS is not a check that it BITES.
  🔒 It never re-probes Secure Input: core/capabilities.lua owns that and
  asks in a held task, and a source sentry fails if this module ever
  grows its own ioreg. GENERAL: a probe module reads what other modules
  already know and asks only what nobody has asked.

- 🧭 THE SEQUENCE (LL, 2026-09-13: "Do bluetooth then the best
  sequence you determine" — his seven asks, my order, one per
  release, each scored by him before the next ships): 6.216.0 (d)
  Bluetooth ✔ built; 6.217.0 (c) the trim ✔ built (+ the feature
  list). REVISED 2026-09-13 with his second batch: (a) ⌥Tab — RESOLVED
  WITHOUT CODE (LL, 6.215.0 rollback: "Alt+tab Success. Shows
  Hammerspoon now."; if it goes missing again, the dock icon being
  HIDDEN is the first suspect — `me:allWindows()` on an accessory app;
  hs.console.hswindow stays banned). ✏️ "doesn't" BY HAND ✔ shipped as 6.219.0 (measured: four
  contractions, not four hundred). 📋 THE CLIPBOARD's first artefact is in
  and ruled the breaker out (see below). 📐 The ⇪T form's layout
  jumped the queue on LL's own ask, shipped as 6.220.0; ⌘ editing a
  mark in the ⇪⇧1 editor did the same, shipped as 6.221.0. 📋 `_G.clipboardReport()` shipped as 6.224.0,
  🧊 the stuck editor overlay as 6.222.0 and the ⇪T height as 6.223.0.
  🚨 LL ASKED FOR NINE AT ONCE (2026-09-14: "If you think we can handle
  it, do all these in the next release: clipboard report → OCR edit
  caret → OCR junk filter → ⌘Space launcher → ⌘⌘ clipboard picker →
  date expansion → music player → click hints → draft keeper") — the
  answer given, and the method now in use: one change per RELEASE, but
  several releases back to back in one sitting, and he installs the
  latest zip once. His own isolation rule is kept (a break names its
  version) and he still gets the batch. NEXT, in his order:
  ✏️ the Edit OCR caret ✔ 6.225.0, 🔤 the OCR junk filter ✔ 6.226.0,
  🎵 the music player ✔ 6.231.0 — REMAINING, in his order: ⌘Space, ⌘⌘ (+
  ⌥⌥), 📅 date expansion, 🖱 click hints, 💾 the draft keeper. Then 🟥 the doubled word (see below). Also ✏️ the Edit OCR
  entry window does not take the caret (the page calls t.focus() but
  the webview window is not key — after bringToFront, focus the
  hswindow on a held timer and re-run t.focus()); then the OCR junk
  filter (his rule below); then (e) ⌘Space → the ⇪space launcher as a plain hs.hotkey with an
  off switch (he turns Spotlight's own shortcut off himself); (a)
  ⌥Tab shows the Hammerspoon Console window (window_switcher;
  hs.console.hswindow is BANNED there — go through
  applicationForPID(own pid)); (g) a copied image is the first paste
  candidate in the clipboard history (read what clipboard_history
  does with images FIRST — 6.190.0 sends them to OCR); ⌘⌘ clipboard
  picker + ⌥⌥ menu bar (the 6.198.0 features, NEVER BUILT — asked
  again 2026-09-13: ⌘⌘ opens the history, ↑↓ walk, fn+⌫ deletes a
  row, then ⇪V / ⇪⇧V could go); date expansion (09-13-26 → 09-13-2026,
  and with slashes); a copied SNIPPET lands on the clipboard as the
  newest item and pastes at the caret; the 🎵 mini music player (spec
  below, questions asked); then the old
  queue's head, click hints (⇪X, Chrome + Finder); (b) the 💾 draft
  keeper LAST of his seven — the least scoped (which fields, where
  the draft goes, how it comes back) and the only one that watches
  his typing; (f) the public sanitised config waits on his strings
  list ("I will after you build"). After those: OCR gibberish, the
  4 PM review, bookmarks CSV, website, Claude door.
- 📋 COPY / HISTORY NOT SHOWING RECENT COPIES (LL, 2026-09-13: "I'm
  not sure my copy and history is working. I don't see items that i
  just copied."). NOT diagnosed, NO code — the artefact comes first
  (6.201.0's rule). 🔎 HIS ARTEFACT CAME BACK (2026-09-14, on 6.219.0):
  "📋 clipboard poll — changes 3 · thrash rests 0 · longest run 1
  ticks · breaker 6 ticks / 60s". THAT CLEARS SUSPECT #1 OUTRIGHT —
  the breaker never rested the poll, not once, and the longest run of
  changed ticks all session was ONE. The poll IS running and IS seeing
  changes; it saw exactly three. So the question moved: three changes
  is either a poll that started late in the session (the report does
  not say WHEN it started, and should), or copies that moved the
  pasteboard and were not FILED (suspect #2, or clip.save refusing —
  suspect #4), or a session in which he genuinely copied three times.
  A change COUNT cannot tell those apart, and that is the gap.
  ✅ THE INSTRUMENT SHIPPED AS 6.224.0: `_G.clipboardReport()` names the
  newest item and its time, the stored count, every refusal by reason,
  saves ok/FAILED — and the poll line now carries the MINUTES and the
  count SUPPRESSED by the borrowed-clipboard guard. Nothing about
  storing a copy changed; the next release is whatever the report names.
  ASK HIM FOR IT: copy three distinct strings, then run
  `_G.clipboardReport()` and paste the whole thing. Ask alongside it: copy three distinct strings, then
  run both reports, so "changes" and "stored" are compared on known
  input. Read, not proven: (1) ❌ RULED OUT BY HIS REPORT — the
  THRASH BREAKER
  (6.170.2) rests the poll `_G.clipboardThrashRest` (60 s) after
  `_G.clipboardThrashTicks` (6) changed ticks in a row and prints ONE
  ⚠️ line — every copy inside that window is never filed; the report's
  "thrash rests" count answers it outright. (2) `_G.pasteboardSuppress
  Until` held in the future (screenshots sets it; core/coexist owns
  it). (3) `_G.clipboardTimer` stopped, or the eco registry's saver
  rebuild leaving it stopped. (4) clip.save() refused — a full disk or
  a OneDrive-owned Logs folder; tellFailure alerts, so ask whether he
  saw one. NOTE the gap this exposes: there is no `_G.clipboardReport()`
  naming the newest item, its time and the last refusal — 6.202.0
  queued exactly that and this is the report that would have answered
  him in one line. Own release once the poll report names the cause.
- 🖱 DRAG AND DROP DIES WHILE HAMMERSPOON RUNS (LL, 2026-09-14: "I
  can't move files in drag and drop again … caps lock stays on and
  Hammerspoon seems locked up"). ✅ MODULE NAMED: file_tracker. Proven
  live, not theorised — `_G.windowMove.tap:stop()` changed nothing, and
  `for _, w in ipairs(_G.fileTrackerWatchers) do w:stop() end` brought
  the drag straight back with every other tap still running ("Stable
  now"). ❌ HALF NOT NAMED: the FSEvents wake-up over the whole home
  folder, or the synchronous OneDrive CSV write. 6.228.0 is the
  instrument that separates them — his report decides 6.229.0. THE TWO
  CANDIDATE FIXES, so the choice is ready: (a) the write leaves the main
  thread (batch the rows, flush from a HELD timer through an hs.task —
  the 6.170.3 shape) and/or leaves OneDrive (`localFirst` already
  exists and does exactly this for every store); (b) the watch narrows
  off `core.homeDir` to the folders he actually wants a paper trail of
  — HIS CALL, because that is the feature's reach. Do not do both in
  one release, and do not start either before the report.
  📋 HIS FIRST 6.228.0 REPORT NAMED NEITHER HALF (2026-09-14 20:50):
  162 wake-up(s) · 1131 path(s) seen · 0 row(s) written · wake-ups 53 ms
  total, worst 3 ms · writes 0 · "⚠️ slow : none over 120 ms". That is
  the third state the release deliberately built in and it must NOT be
  spun as a confirmation. TWO THINGS IT PROVES AND ONE IT DOES NOT:
  the watch IS the whole home folder and the CSV IS inside OneDrive
  (both ⚠️ lines fired); and 0 ROWS OVER 1,131 PATHS means the write
  half was never exercised, so that session probably holds no file move
  at all — ask whether he moved the files before running it BEFORE
  reading anything else into it.
  🔬 THE UNTIMED THIRD CANDIDATE, found by reading: `ft.nowMs()` starts
  AFTER Hammerspoon has marshalled every path and flag table into Lua.
  A whole-home FSEvents storm during a Finder move costs that
  marshalling on the main thread and the clock cannot see it — which
  fits every fact (Lua body cheap, write never reached, stopping the
  watchers fixed the drag instantly). `paths seen` is the only proxy
  for it, so the cheap next test is the SAME report before and after a
  move: if paths jumps by thousands while ms stays small, the wake-up
  volume is the cost and the fix is (b), narrowing the watch.
  🕳 AND THE REPORT HAS NO REFUSAL COUNTS — 6.224.0's own rule, unpaid
  here: 1,131 paths and 0 rows cannot say whether they were ignored,
  excluded, non-file, or burst-limited. Add them with whatever ships.
  ✅ NAMED BY HIS SECOND REPORT (2026-09-15, a full day): 60,115 wake-ups ·
  204,662 paths · 49 rows · 16,597 ms · worst 58 ms · none over 120 ms.
  NEITHER of the two candidate halves — it is the NUMBER of wake-ups, and
  the durable rule above carries what that cost and why the alert was
  right to stay quiet. SHIPPED AS 6.229.0 (fix (b), narrowing the watch,
  which was his call and which he made by asking). STILL NOT DONE, and
  each is its own release when its turn comes: (a) the write off the main
  thread / out of OneDrive is UNTOUCHED and still correct (49 writes and
  42 ms is not his problem today, so it waits for evidence); and the
  refusal counts above. DO NOT SCORE 6.229.0 from this side; if his drag
  is still slow on it, the next artefact is the same report, and the
  wake-up count is the number to compare.
  🔗 HIS FIRST 6.229.0 REPORT (2026-09-15 20:51, 47 s into the session)
  PROVED THE NARROWING AND FOUND THE NEXT BUG: 11 folders one watcher
  each, Library refused by name, 14 names in "not :" — and TWO rows for
  one tree (~/OneDrive is a symlink into CloudStorage; he confirmed it
  with symlinkAttributes). SHIPPED AS 6.230.0, see the durable rule above.
  The session was too young to measure anything else (61 wake-ups, 65
  paths, 0 rows — a boot, not a day), so the hours-later report is STILL
  THE TEST and still owed.
  🎯 6.241.0 — AND THAT ONE WAS THE CLOUD FOLDER'S CHILDREN, not a store
  move. The CSV and every other store live in <OneDrive>/Logs, which
  6.229.0 added back as a watched root, so this config's own writes woke
  this module and were then excluded in LUA, after the wake-up: 6.229.0's
  class exactly, one level down and in the same file. The cloud folder is
  watched by its CHILDREN now, minus `ft.cloudSkip` ({ "Logs" }), bounded
  by `ft.maxCloudRoots` (40); `ft.cloudRoots` is PURE and answers nil AND
  A REASON rather than an empty list, so a Mac that cannot list the folder
  keeps the old whole-folder watch and takes the 🔔 door.
  🚨 AND THE EXPANSION RUNS AFTER THE DEDUPE. ~/OneDrive is a link to that
  folder, so while the list is being built there are two names for one
  tree and only `ft.dedupeRoots` knows it; expanding first would add the
  children and then have the dedupe drop every one as "inside" the link's
  own whole-tree watcher — the release doing nothing, quietly, on the Mac
  it was written for. `ft.expandCloud` swaps the slot afterwards, both
  halves PURE. GENERAL: when a fix and a de-duplication rewrite the same
  list, the one that RESOLVES NAMES goes first — otherwise the other is
  working on names that do not mean what it thinks they mean.
  🔒 `Logs` AND NOTHING MORE: the exclusions drop <cloud>/Backups/
  Hammerspoon/ but KEEP the rest of Backups, so skipping the whole Backups
  folder would un-decide what the exclusions decided. NAMED NOT FIXED: the
  nightly backup and the 30-minute mirror still wake it.
  🔎 THE CSV LINE IS READ, NOT CLAIMED — the report walks the watch list to
  decide whether this module's own folder is still under a watcher, so a
  `folders` override that puts Logs back is reported honestly. A release
  that asserts its own outcome cannot notice being overridden.
  🚫 `localFirst` (6.190.0) WAS THE OBVIOUS FIX AND IS THE WRONG ONE, and
  this is why: it moves EVERY store local, and the 30-minute mirror pushes
  to <backupDir>/Logs, which is PER-HOST — so after the seed the two Macs
  never read each other's stores again. autocorrect.csv is one of them, and
  "what ⇪Z learns is permanent, CROSS-MACHINE" is a promise this config
  makes in writing. Do not flip that flag to fix a wake-up problem.
- ✅ ⇪Y CHROME HISTORY BEACHBALL — NAMED AND FIXED AS 6.245.0. His
  second report (2026-09-17) carried the half that decided it: "caused a
  lock up when I STARTED TO SEARCH" — it froze on TYPING, not on the
  keypress, which clears the export, the sqlite3 task and the CSV read
  and leaves the per-keystroke search alone as the suspect. The cause was
  then READABLE (6.199.0's rule — read the source before naming a second
  cause): `chrome.search` scored every row, built a table for every
  MATCH, and handed the lot to table.sort before taking the first 40. A
  one-letter query is inside nearly every URL, so the FIRST keystroke of
  any search built ~60,000 tables and sorted them — about a million Lua
  comparator calls plus that much garbage — on the main thread inside a
  queryChangedCallback, per key. 6.228.0's rule names the cost.
  🚨 SELECT, DO NOT SORT: `chrome.keepBest` holds the best `showRows` and
  refuses anything that cannot beat the worst kept row, without
  allocating; `chrome.better` is the ordering rule (score DESC, pool
  index ASC) in ONE place and PURE. THE CHECK THAT MATTERS runs the OLD
  algorithm beside the new one over seven queries and wants identical
  rows in identical order — speed bought with his results is not a fix,
  and a check that only asserted "the answer looks right" passes with
  table.sort put back. A second check counts the rows actually KEPT
  while a one-letter query matches most of the pool: a few dozen, never a
  few thousand. GENERAL: when only the top N is shown, selecting is the
  fix and sorting is the bug — and the check is "same answer as the sort"
  PLUS "nowhere near as much work".
  🔎 `_G.chromeHistoryReport()` has a CLOCK now (last keystroke: ms, rows
  scanned, matched, kept; the worst of the session beside it) and past
  `chrome.slowMs` (150) a keystroke takes the 🔔 door naming the ms AND
  the row count. NOT FIXED, named: the scan is still O(archive) per
  keystroke and still on the main thread.
- 🎵 MINI MUSIC PLAYER (LL, 2026-09-13, NOT built; questions asked):
  ⇪⇧numpad. opens a lightweight player in the top-right corner like
  the 3-month calendar. Repeat one / repeat all; history (click an
  item → plays); elapsed time; drag-and-drop N files → the first
  plays, the rest form a playlist under it, picked by click, ↑↓, or
  ⌘1–9. Engine: hs.sound (NSSound) plays mp3/m4a/aac/wav/aiff
  natively — no binary, works on the work Mac; FLAC/ogg do NOT play
  through it (say so per file, never throw). Drag-and-drop needs a
  webview (canvas has no drop target).
  ✅ BUILT AS 6.231.0 — see the durable rule above. v1 ships without
  volume and without seek, on his own answers. NOT built and each its own
  release when he asks: volume, seek, a watched music FOLDER, and reading
  tags (artist/album) out of a file. ✅ ALL THREE ANSWERED (LL,
  2026-09-14): "just mp3, m4a" — so hs.sound covers his whole library
  and the FLAC/ogg degrade is a message he will never see; "Both macs,
  home/work/ use a full Apple Keyboard and Magic pad" — a NUMPAD EXISTS
  ON BOTH, so ⇪⇧numpad. needs no fallback key (check hint.groups before
  binding); "Native volume keys work" — NO volume keys in the player,
  and seek was not asked for, so v1 ships without either and they are
  his call afterwards. NOTHING ELSE IS BLOCKING IT — it is a build when
  its turn comes.
- ✅ 6.225.0 + 6.226.0 FIELD REPORT (LL, 2026-09-14): "OCR seems to be
  working." `edit box : caret placed on try 1 — window focused` — the
  caret chase lands on the FIRST try on his Mac. And the junk filter on
  his real log: 1,088 rows read, 656 held junk, 6,200 single/punctuation
  tokens, 12 rows were nothing but junk; the dry run said it and
  `_G.ocrCleanHistory(true)` rewrote it — "1076 row(s) kept, 12 removed".
  Both worked on the first install. NOT SCORED — "seems to be working" is
  not his win sentence and only he scores.
- ✅ EDIT OCR ENTRY HAS NO CARET — SHIPPED AS 6.225.0 (LL, 2026-09-13).
  Diagnosed exactly as read: bringToFront ≠ key. See the durable rule
  above. Unscored until he says.
- ✅ OCR JUNK RULE — TIER 1 SHIPPED AS 6.226.0. See the durable rule
  above. STILL OPEN, and only on his word: TIER 2 (his 🤔 rows — lUE,
  ido, dic, "characters1" → "character 1") is a dictionary vote per
  line plus digit/letter splitting, NOT built, because he said if the
  method can introduce errors then singles only. Ask before building.
- 🟥 DOUBLE WORD FLAGGED (LL, 2026-09-14: "See that double 'edit edit',
  can you add to my autocorrect flagging down any double words with a
  pink squiggle line beneath."). NOT built — NEXT after the clipboard
  report, and the shape is decided but the last step needs his word.
  🚨 A SQUIGGLE UNDER THE TEXT IS NOT POSSIBLE and saying otherwise
  would be a promise this config cannot keep: macOS gives no way to
  paint inside another app's editing surface, so nothing can draw
  beneath a word in Chrome's or Asana's text field. What IS possible,
  in three parts: (1) DETECTION is free — autocorrect's tap already
  ends a word on a boundary, so "the piece just typed equals the piece
  before it, case-insensitively" is one comparison in a place that
  already runs (the ⇪Z exception list and the pause switch govern it
  like every other rule); (2) THE MARK is a pink underline drawn ON TOP
  of the words as its own mouse-transparent canvas, positioned from the
  caret's rectangle — `AXTextMarker`/`AXBoundsForRange` on the focused
  element, which Chrome and native apps answer and Electron apps mostly
  do not; (3) THE DEGRADE, where no rectangle comes back, is a brief
  pink alert naming the doubled word (notices, never a keystroke). It
  NEVER edits his text — a doubled word is sometimes right ("had had")
  and 6.200.0's rule is that this config does not guess. Report line
  and a settings switch. ASK HIM: is the alert enough where the
  underline cannot be drawn, or should it stay silent there?
- 📅 DATE EXPANSION + SNIPPET PASTE (LL, 2026-09-13): typing
  09-13-26 → 09-13-2026 (and 09/13/26 → 09/13/2026) — an autocorrect
  rule, fires on the space after a date shaped MM-DD-YY only (a
  4-digit year untouched; 26 → 2026 by 20xx); ";-d" is a SHIPPED
  expansion (in the packs / Mine — check which before answering him
  further); a snippet copied from the picker goes to the clipboard as
  the NEWEST clipboard-history item and pastes at the caret.
- 🧊 Ice.app (NOT ours, unresolved): LL: Settings "flash so fast no
  way to change", then "Settings don't open"; ⌘-drag moves icons but
  "none seem to hide". Asked and unanswered: does Settings open with
  Hammerspoon QUIT (if yes, a window tool of ours closes it — the
  window auto-position / app_watcher paths are the suspects). If it
  fails with Hammerspoon quit too: `brew reinstall --cask
  jordanbaird-ice`, and Ice needs Accessibility. No code until the
  quit test answers.
- 💾 The "TWO FILES LOOK LIKE THE SAME LOG" line (autocorrect-Lees-
  MacBook-Air.csv beside autocorrect.csv): nothing in the config
  writes the per-Mac name — a leftover. It was GONE by 18:38 on
  2026-09-13 (write ledger: "was here at boot and is GONE now");
  the line does not return. Closed.
- 6.219.0 verify with LL — THE APOSTROPHE: install (carries
  6.215.0–6.218.0). In Chrome type `doesn't ` — it stays `doesn't `,
  and so do `wouldn't `, `mightn't `. Then `doesnt ` still becomes
  `doesn't ` (his own row), and `teh ` still becomes `the `. Then
  `somethingg ` → `something` — the word list is still alive on a
  space. `_G.autocorrectReport()`: a new "apostrophe :" line counts
  the pieces a ' handed to the dictionary alone, and the "spelling :"
  block must no longer list `Doesn → Doesnt`. KNOWN AND ACCEPTED: a
  typo right before an apostrophe (somethign's) is not corrected now.
- 6.229.0 verify with LL — 🎯 THE WATCH IS NARROW NOW: install (carries
  6.228.0). FIRST, before anything else, Console:
  `_G.fileTrackerReport()`. The "watching :" line must name your folders
  one by one — Desktop, Documents, Downloads, Movies, Music, Pictures,
  .hammerspoon, and the OneDrive folder — and `/Users/leeleblanc` must NOT
  be one of them. A "not :" line names Library.
  THEN THE TEST THAT MATTERS: use the Mac normally for a few hours, then
  run it again. "events" is the whole answer. On 6.228.0 it read 60,115
  wake-up(s) · 204,662 path(s) · 49 row(s) over a day. It should now be a
  small fraction of that for the same day's work, and the row count should
  be about the SAME — that is the claim: you lose the noise, not the paper
  trail. The new "yield :" line says it in one number (4,000 paths per row
  before; a much smaller number now).
  AND THE FEATURE ITSELF MUST STILL WORK: move a file in Finder, then
  ⌃⌥⇧F — the move is in the list, as ever.
  🖱 THE DRAG: if drag and drop is still slow on this build, that is the
  answer to a different question and I want the same report — the wake-up
  count is the number to compare, not the milliseconds.
  📏 KNOWN AND ACCEPTED, so it is not a surprise later: a file sitting
  LOOSE at the top of /Users/leeleblanc (in no folder at all) is no longer
  watched, and a NEW folder you make there starts being watched at the
  next reload. If you want a folder that is not on the list, no release:
  `settings = { file_tracker = { folders = { "/Users/leeleblanc/Documents",
  "/Users/leeleblanc/Desktop" } } }` — that list is watched verbatim and
  nothing else is.
  If the report ever says "⚠️ could not list …", that Mac refused to list
  its own home folder and the watch fell back to the old wide one — paste
  the line, it is the evidence.
- 6.289.0 verify with LL — ⏯ THE PLAY/PAUSE KEY (KNOWN GROUND)
  WHAT CHANGED: the keyboard's own ⏯, ⏮ and ⏭ keys now drive the music
  card — but only while it has a queue.
  WHY IT MATTERS: you said "pressing play/pause doesn't work, but volume
  keys do", and those two sentences are about the same row of keys. The
  volume keys are macOS's own, which is why they work everywhere. ⏯ was
  going wherever macOS thinks your music is, and that was never this
  card. Nothing was broken — the key had simply never been claimed.
  🚨 AND I DELIBERATELY DID NOT TAKE IT ALWAYS. If this config ate ⏯
  whenever it was loaded, Music.app and every browser tab playing audio
  would lose the key the moment Hammerspoon booted, silently. So it is
  taken only when the card has a queue.

  A. THE HEADLINE.
  A1. ⇪⇧pad., drop two or three tracks on the card. Something plays.
  A2. Press the keyboard's ⏯ key (F8).
      EXPECT: the card pauses. Press it again: it resumes.
  A3. Press ⏭ and ⏮. EXPECT: the card steps forward and back.
  A4. Volume keys: unchanged, still macOS's. That was your own call in
      6.231.0 and I have not touched it.

  B. THE ONE THAT PROTECTS EVERY OTHER APP — please do this one.
  B1. Empty the card's queue (or just do not queue anything), then play
      something in Music.app, Spotify or a YouTube tab.
  B2. Press ⏯.
      EXPECT: THAT app pauses, exactly as it does today. Hammerspoon must
      not swallow the key.
      A FAIL here is the serious one: tell me at once and
      `settings = { music_player = { mediaKeys = false } }` turns it off.
  B3. Now queue something on the card and press ⏯ again: the card wins.
      That is the trade, and it is the narrowest one I could draw.

  C. PASTE BACK, PASS OR FAIL.
  C1. `_G.musicReport()` — a new "⏯ keys" line reads
      `watching ⏯ ⏮ ⏭ · N taken · N passed through to macOS`.
      If it reads `⚠️ WANTED but not running`, this Mac would not give
      Hammerspoon an event tap and the keys are doing nothing new —
      paste it, that is the evidence.

  D. A SENTENCE I NEED FROM YOU.
  D1. When you wrote "pressing play/pause doesn't work", did you mean
      the KEYBOARD's ⏯ key — which is what I have built — or the ▶︎
      BUTTON on the card / the space bar? If it was the button or the
      space bar, that is a different fault and the report's "keyboard :"
      line names it: paste `_G.musicReport()` right after pressing space
      on the card and I will fix that instead. One sentence is enough.

- 6.288.0 verify with LL — 🖥 THE SHEET OPENS WHERE YOU ARE (KNOWN GROUND)
  WHAT CHANGED: ⇪/ is placed on the screen this config resolved, and can
  no longer be pulled onto another monitor by a spot you saved there.
  WHY IT MATTERS: your two sentences are ONE bug, which is why I want to
  say the mechanism plainly. Your saved spot is stored as an offset into
  the screen you dragged it on. Dragged to the right-hand side of the 4K
  that offset is about 2000 points. Applied to the Air's top-left, 2000
  points to the right is physically ON the 4K — and the helper that was
  supposed to keep the panel on a screen kept it on THAT one, throwing
  away the screen every line above it had just worked out. And a sheet on
  the other monitor is a sheet that is not in front of you: you drag it
  back, and it appears. Second sentence, same event.

  A. THE HEADLINE — this needs both monitors.
  A1. On the LG, press ⇪/ and drag the sheet to its right-hand side.
      Close it.
  A2. Click into an app on the AIR. Press ⇪/.
      EXPECT: the sheet is on the AIR, fully on screen, over toward its
      right-hand edge. It must NOT be on the LG.
  A3. Console: `_G.cheatSheetReport()`. The new "place :" line should
      read `nudged back onto this screen — the spot you saved was on a
      bigger one`, with the screen it used underneath.
  A4. Now back on the LG: press ⇪/.
      EXPECT: your spot, exactly — it fits there, so it is obeyed, and
      the report reads `where you put it`.

  B. IS IT IN FRONT?
  B1. Each time it opens, is it readable without you touching it?
      EXPECT: yes. If it EVER opens and is not in front on the monitor
      you are looking at, that is a second bug and I have not found it —
      run `_G.cheatSheetReport()` and `_G.screenReport()` at that moment
      and paste both. Those two together name the screen, the rule that
      chose it, and where the panel went.

  C. MUST STILL WORK.
  C1. Drag the sheet anywhere and reopen: it is where you left it.
  C2. Type to filter, scroll with the wheel, Esc to close — unchanged.
  C3. `_G.cheatSheetCenter()` still forgets the spot and re-centres.
  C4. Unplug the LG, then ⇪/. EXPECT: it opens on the Air, on screen.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. When your saved spot does not fit the smaller screen, I nudge it to
      the nearest edge rather than re-centring — so a sheet you like on
      the right stays on the right. Is that what you want, or would you
      rather it centred on a screen it does not fit? "nudge" · "centre".

- 6.287.0 verify with LL — ✏️ THE TEXT TOOL IS A TEXT BOX (KNOWN GROUND)
  WHAT CHANGED: all four of your text-box asks, in one release, because
  they were one defect seen from four sides.
  WHY IT MATTERS: a text note had never had a WIDTH — only a font size.
  6.188.0 made the corner handle scale the letters, so there was nothing
  to wrap at, nothing for Return to make a second line of, and the one
  control on the box did the one thing you did not want it to.

  A. THE HEADLINE. ⇪⇧1 on a screenshot, press T, click.
  A1. Type a sentence long enough to be worth wrapping, then press ⏎.
      EXPECT: a NEW LINE inside the box. It must NOT finish the box.
  A2. Type a second line. Press ⇧⏎.
      EXPECT: done, and the note shows BOTH lines on the shot.
  A3. Drag the corner handle to the LEFT (no modifier).
      EXPECT: the box gets narrower and the words RE-WRAP. The letters
      stay exactly the same size. That is asks 2, 3 and 5 at once.
  A4. Hold ⇧ and drag the same corner.
      EXPECT: the letters grow and shrink, the way they always did.
  A5. ⌘Z. EXPECT: the last of those goes back — a re-wrap undoes like
      a move.

  B. THE ONES THAT PROTECT WHAT YOU ALREADY HAVE.
  B1. Make a box, close the editor with Esc, reopen the SAME shot.
      EXPECT: the box comes back with its lines and its width intact.
      (6.286.0 is what makes Esc keep it at all — do that block first.)
  B2. Open a shot you annotated on an OLDER build, if you have one.
      EXPECT: the old text notes look exactly as they did. They have no
      width stored, so they stay one line until you drag one.
  B3. Type a very long single word with no spaces — a URL will do — in a
      narrow box. EXPECT: it breaks across lines rather than running out
      of the box.
  B4. Make a two-line note ON something (an arrow tip, a button).
      EXPECT: it grows DOWNWARD. The first line stays where you clicked,
      so the note never walks off the thing it points at.

  C. MUST STILL WORK — every tool shares this canvas.
  C1. ⌘click a text box: its words open, pre-filled.
  C2. Drag a text box by its middle: it moves.
  C3. Esc with the box open cancels the BOX; Esc again closes the editor.
  C4. ⌘⏎ saves, and the saved PNG has the wrapped lines in it exactly as
      they looked on screen.
  C5. Blur, arrow, line, oval, highlighter, counter, spotlight,
      magnifier — unchanged.

  D. A JUDGEMENT ONLY YOU CAN MAKE — and this is the one I most want.
  D1. ⇧⏎ to finish. Is that the right key? The alternatives are ⌘⏎
      (which is Save & copy everywhere else in the editor, so it would
      be two meanings for one chord) or "click away", which already
      works. "⇧⏎ is fine" · "make it something else" decides it.
  D2. Plain drag re-wraps, ⇧drag scales — your suggestion. If it feels
      backwards in the hand, say so and I will swap them; it is one line.
  D3. A new box is born as wide as the words you typed. Would you rather
      it started at a fixed width — say a quarter of the shot — so it
      wraps from the first sentence? That is a default, not a release.

- 6.286.0 verify with LL — 🚪 CLOSING THE EDITOR KEEPS YOUR MARKS (KNOWN GROUND)
  WHAT CHANGED: every way out of the screenshot editor now asks the page
  for your work before the window goes. Until this release only the
  Cancel button did.
  WHY IT MATTERS: your screenshot said "closing the editor dumps the most
  recent edits so I lose any changes", and you were right — even though
  6.189.0 was built for exactly that complaint and its tests are green.
  Your marks live inside the editor's page; the only thing that hands
  them back is the page itself, and only the Cancel button was asking.
  Esc deleted the window, and opening a second screenshot deleted the
  first one's work without a word.

  A. THE HEADLINE — the door you press.
  A1. ⇪⇧1 on a screenshot. Draw an arrow, add a text box, blur something.
  A2. Press Esc.
  A3. ⇪⇧1 on the SAME screenshot again.
      EXPECT: an alert "🖌 Your last edits on this shot are back", and
      every mark where you left it.
      A FAIL here is the bug you reported, unchanged — say so at once.
  A4. Same again, but close with the Cancel button instead of Esc.
      EXPECT: identical. (This is the one that always worked.)

  B. THE OTHER DOOR, and the one I think you were actually using.
  B1. ⇪⇧1 on shot A. Draw something.
  B2. Without closing it, press ⇪⇧1 on a DIFFERENT shot B.
      EXPECT: B opens clean.
  B3. Now ⇪⇧1 on shot A again.
      EXPECT: A's marks are back. Before this release they were gone,
      silently, and nothing said so.

  C. MUST STILL WORK — this release changed how the window closes, so
     this is the regression sweep.
  C1. ⌘⏎ saves "… (edited).png" beside the original and copies it.
  C2. After a SAVE, reopen the same shot: it opens CLEAN, not with the
      saved marks drawn again. (A saved session is not a lost one.)
  C3. Esc while a text box is open closes the BOX, not the editor. Press
      Esc twice to leave.
  C4. ⌘Z undo, ⌘V paste an image, ⌘A add capture, ⌘D delayed, ⌘F full
      screen, ⌘O load a shot — all unchanged.
  C5. The editor must always close when you ask it to. If it ever hangs
      open for half a second and then goes, that is the belt working and
      it is worth telling me about.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.screenshotEditorReport()` — a new "closing :" line counts the
      doors apart: asked · handed work back · closed on the belt ⚠️ ·
      closed at once. A belt close means the page did not answer in time
      and those marks were NOT kept — if that number is anything but 0,
      that is the next bug and I want the block.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. 0.4 seconds is how long the editor waits for its page before
      closing anyway. If closing ever feels sticky, say so and I will
      shorten it; if you ever lose marks with the report showing a belt
      close, I will lengthen it.
  E2. Your four text-box asks — wrap, font size separate from the box,
      Return for a new line, and shrink-to-rewrap — are ONE release and
      they are next. Confirm the shape before I build it: plain drag on
      the corner handle RE-WRAPS the text to the new width, and ⇧drag
      scales the letters. That is your own "hold shift" suggestion; say
      if you would rather have it the other way round.

- 6.285.0 verify with LL — 🔔 THE ⇪ WATCHDOG STOPS CRYING WOLF (KNOWN GROUND)
  WHAT CHANGED: nothing about how ⇪ works. What changed is what the
  Console says when a panel takes the keyboard.
  WHY IT MATTERS: your last paste carried this line —
      ⌨️ ⇪ released by the watchdog — held 8s with no key event and no
      F18 keyUp (release #1) — musicPlayer had taken the keyboard.
  Nothing was wrong. The music card takes the keyboard on purpose, so
  the Caps Lock release goes to ITS window, and a guard ends the hold
  1.5 seconds later exactly as designed. But that is the sentence this
  config prints when ⇪ is genuinely STUCK — the thing that killed your
  keyboard in 6.214.0 — and it was also adding to the count the storm
  report calls a fault. A warning you see every time you play music is
  a warning you stop reading.
  🚨 AND I HAD THE FIX WRONG IN MY OWN NOTES: I had written that the
  card should call `_G.hyperTouch()`. It should not — that call means
  "this hold is real, keep it", which would have held ⇪ latched LONGER.

  A. THE HEADLINE.
  A1. Press ⇪⇧pad. to open the music card. Watch the Console.
      EXPECT, the FIRST time this session: `⌨️ ⇪ hold ended on schedule
      — musicPlayer took the keyboard, so the F18 keyUp went to it.
      Normal, not a stuck ⇪`.
      EXPECT NOT: "released by the watchdog".
  A2. Close it and open it again, twice more.
      EXPECT: NOTHING in the Console. It is explained once per panel and
      counted after that.
  A3. Console: `_G.hyperKeyReport()`.
      EXPECT three lines — relay · handover · latch — with handover at
      3 and `latch : 0 — ⇪ has not stuck this session`.
      THAT ZERO is the release. Paste the block.

  B. MUST STILL WORK — this is the ⇪ key, so it is the important half.
  B1. Use ⇪ normally for a day: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space.
      EXPECT: no change of any kind.
  B2. Hold ⇪ down for ten seconds without pressing anything, then let go.
      EXPECT: `released by the watchdog — held 8s … (release #1)`, with
      no panel named. THAT one must still appear — it is the real
      warning and it has to keep its teeth.
  B3. `_G.hyperKeyReport()` again: `latch : ⚠️ 1`. The ⚠️ is the point.
  B4. `_G.stormReport()` — its "before :" line now reads LATCH releases,
      panel handovers and keyUp relays separately instead of summing
      them.
  B5. Open Hamsidian (⇪N) and type. The pad does the same handshake, so
      you should see its one-off line too, and typing must be typing —
      no letter should run a shortcut.

  C. A JUDGEMENT ONLY YOU CAN MAKE.
  C1. Is once per panel per session the right amount of talking, or
      would you rather it never said anything and only counted? "once is
      fine" · "say nothing" decides it.

- 6.284.0 verify with LL — 🏷 THE ASANA TEAM NAME (KNOWN GROUND)
  WHAT CHANGED: the team name in the config is corrected to the one you
  sent me, and — the actual release — a team's GID is remembered the
  first time it resolves, so renaming it in Asana no longer breaks
  anything.
  WHY IT MATTERS: you asked why you have to hard code team names. You
  don't, and you were right to ask. The honest finding is that the half
  everyone would suspect was never stale: this config asks Asana for the
  team list on EVERY boot, so its answer is always current. What was
  stale is the question — the name it searches for, typed into a file.
  A fresh answer to a stale question, which is why the warning was
  correct and useless at the same time.

  A. THE HEADLINE.
  A1. Install and reload. Watch the Console during boot.
      EXPECT: the `⚠️ Asana team not found by name: "| 2. SAC Library
      Team Member Projects & Tasks |"` line is GONE.
  A2. Console: `_G.asanaTeams()`.
      EXPECT: an "asked" block with your two team names, an "answer"
      block listing every team Asana holds WITH ITS GID, and two ✅
      lines. Paste it — this is the artefact I have been asking for and
      it is the first build that can produce it.
  A3. Press ⇪T and start typing a colleague's name from that team.
      EXPECT: they are suggested. That is the thing the warning was
      costing you, and nothing else.

  B. THE REAL TEST — RENAME IT ON PURPOSE. Worth five minutes, because
     it is the whole release and you are the only one who can run it.
  B1. In Asana, rename that team — add a word, take one away, anything.
  B2. Reload Hammerspoon.
      EXPECT in the Console: `🏷 Asana team renamed — "| 2. SAC Library
      Team Member Projects |" is called "<the new name>" now; matched by
      its GID, nothing to edit`. NO ⚠️.
  B3. ⇪T again: the same colleagues are still suggested.
  B4. Reload once more. EXPECT the same 🏷 line, not a ⚠️ — the pin has
      to be re-written every boot or it would survive exactly one.
  B5. Rename it back if you like. Either way it keeps working.

  C. MUST STILL WORK.
  C1. ⇪T creates a task, with a priority and SAC Values, as ever.
  C2. A name that is NOT in the list still submits — that was true
      before and must stay true.
  C3. Hamsidian's `_G.scratchPadSend()` still posts to Asana.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. Team 1 is "| 1. SAC Library Core Projects |" and I have not
      touched it. If that one has also been renamed, `_G.asanaTeams()`
      will now show you Asana's real name for it — send me the output
      rather than editing the file.
  D2. Should the config stop naming teams altogether and just use the
      whole workspace? I have NOT done that: 6.16.9 found the workspace
      is a college with thousands of student accounts, which made the
      picker useless. Say if that has changed.

- 6.283.0 verify with LL — 🧠 ⌥Tab SEES THE CONSOLE (KNOWN GROUND)
  WHAT CHANGED: the Hammerspoon Console is remembered by ⌥Tab now, so it
  is on the wheel from every desktop instead of only the one it is on.
  WHY IT MATTERS: you have told me this twice. You were right twice, and
  so was your own explanation — "unless I switch to that desktop I can't
  see it". macOS will not tell us about another desktop's windows at
  all, so this switcher keeps a memory of every window it has ever
  listed. The console was the one thing that never went into it.

  A. THE HEADLINE.
  A1. Open the Hammerspoon Console. On THAT desktop, press ⌥Tab once.
      EXPECT: a Hammerspoon Console card, as before.
  A2. Switch to another desktop. Press ⌥Tab.
      EXPECT: the Console card is STILL THERE, captioned
      "· remembered (another desktop?)".
      THIS is the step that failed before. If it is missing, stop and
      paste `_G.switcherReport()`.
  A3. Turn the wheel to it and release ⌥.
      EXPECT: macOS carries you to that desktop with the Console front.
  A4. Close the Console, then ⌥Tab and choose the card again.
      EXPECT: the Console OPENS. A card that does nothing is the failure
      this release exists to avoid — tell me if you get one.

  B. PASTE BACK, PASS OR FAIL.
  B1. `_G.switcherReport()` — new; this module had no report at all.
      The "console:" line has three states and I want whichever you get.
      "not seen yet this session" is HEALTHY on a boot where you have
      not opened the Console — it is not a fault, and it tells you the
      one thing to do (open it, press ⌥Tab once on that desktop).

  C. MUST STILL WORK — the memory is shared with every window, so this
     is the regression sweep and it is the important half.
  C1. Park a Chrome window on another desktop, ⌥Tab there once, come
      back, ⌥Tab. EXPECT: that window is still offered, as before.
  C2. ⌥⇧Tab backwards, ← →, ↑ ↓, Home/End, Return, Esc — unchanged.
  C3. A minimised window is still listed; switching to it un-minimises.
  C4. ⌥Tab must not feel slower. If it does, B1's "last :" line names
      the phase and the app — paste it.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. The Console now stays on the wheel once you have opened it, for
      the rest of the session. Is that right, or is it clutter on the
      days you open the Console once and never want it again? "keep it"
      · "only while it is open" decides it — the second is a smaller
      wheel and brings back exactly the bug you reported.
  D2. Should the MUSIC CARD be on ⌥Tab too? You asked in September and
      I have not built it. It is the one panel that keeps playing when
      it is not in front, which is the argument for doing it alone
      rather than adding every panel this config draws.

- 6.282.0 verify with LL — 🕒 THE REPORT ANSWERS AGAIN (KNOWN GROUND)
  WHAT CHANGED: `_G.screenshotsReport()` no longer throws. Nothing about
  capturing, naming or OCR moved.
  WHY IT MATTERS: you ran the command I asked for and got a traceback.
  `hs.timer.secondsSinceEpoch()` hands back 1758769234.8231 and Lua's
  os.date refuses a fraction outright, so the `area` line did not print
  something wrong — it took the whole report down. Since 6.264.0, in
  every session where you had pressed ⇪4 even once. A fresh boot printed
  fine, which is why neither of us saw it until you used the key first.
  🚨 AND IT IS MY METHOD THAT BROKE, not just a line: almost every ask
  I make of you ends in "paste the report". 6.274.0's steps literally say
  press ⇪4, then run this command — so that test has been impossible to
  run since the day it shipped, and I did not notice.

  A. THE HEADLINE. Two commands.
  A1. Console: `_G.screenshotsReport()`.
      EXPECT: a report. Not a traceback.
  A2. Press ⇪4 and drag a rectangle. Then run it AGAIN.
      EXPECT: still a report, and the `area` line ends with a real
      clock — `· last pressed 21:14:07`.
      THIS is the step that failed before. If you get
      "bad argument #2 to 'date'" again, stop and paste it.

  B. THE ARTEFACTS I HAVE BEEN ASKING FOR AND COULD NOT GET.
  B1. Use the Mac for a day, then `_G.screenshotsReport()` and PASTE IT.
      Three lines answer three open questions at once:
      · `OCR` and `tried` — whether 6.281.0 stopped the green pills.
      · `routes` and the ⚠️ under it — your intermittent ⇪4.
      · `area` — which selector the last press used.
  B2. `_G.alertReport()` as well. Together those are the whole ⇪4
      question, and this is the first build on which you can collect them.

  C. MUST STILL WORK — this release touched only how a time is printed,
     so this is a short sweep.
  C1. ⇪4 captures, with the live size readout and the shutter.
  C2. ⇪5 scrolling capture. Its report line carries a clock too.
  C3. A screenshot with words in it still gets renamed — your Console
      already shows this working ("🏷 OCR → Finder comment: …").

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. When a clock cannot be read, the line now says "time not recorded"
      rather than printing 1970. Is that the right wording, or would you
      rather it said nothing at all there? Either is one line.

- 6.281.0 verify with LL — 🔁 THE GREEN PILLS STOP (KNOWN GROUND)
  WHAT CHANGED: a screenshot that OCRs to nothing is now remembered as
  tried, and the folder watcher stops offering it after three goes. ⌘9 is
  unchanged and still OCRs anything you point it at.
  WHY IT MATTERS: you said the green icons "loop and loop and loop like
  it's running OCR nonstop." Each green pill in your menu bar is one
  `shortcuts run "HS OCR"` process. A word-less image was never renamed,
  so it never stopped qualifying, so it was re-OCR'd on every folder
  event — for ever. And because reading a OneDrive placeholder HYDRATES
  it, and a hydration is a write, the OCR was re-triggering the watcher
  for the file it had just OCR'd. No outside input needed.
  🚨 THIS IS ALSO IN 6.275.0, the build you rolled back to — the watcher
  is 6.155.0 code. The rollback did not remove this; only this does.

  A. THE HEADLINE. Do this FIRST.
  A1. Install, then Console: `_G.screenshotsReport()`.
      EXPECT a new block, and on a fresh boot it should read:
        OCR     : 0 run · 0 named · 0 read no text · …
        yield   : no OCR has run this session
        tried   : nothing has OCR'd to nothing yet
  A2. Use the Mac for an hour, normally. Watch the menu bar.
      EXPECT: pills appear when a screenshot arrives and GO AWAY. What
      must not happen is a pill that is always there, or pills that
      reappear the moment they vanish.
  A3. `_G.screenshotsReport()` again. This is the artefact I want.
      EXPECT "OCR : N run" to be a small number — roughly the number of
      screenshots that actually arrived — and "tried : N file(s)
      remembered · M at the 3-try cap".
      A FAIL is "run" in the hundreds or thousands. Paste it either way.

  B. PROVE IT ON PURPOSE, if you want to see the rule work.
  B1. Put an image with NO words in it — a photo, a plain colour — into
      the screenshots folder, named like `Screenshot 2026-09-26 at
      10.00.00.png`.
      EXPECT: three OCRs (three brief pills), then silence. Before this
      release it would have gone on for as long as Hammerspoon ran.
  B2. `_G.screenshotsReport()` — the "tried" line names it, and says the
      watcher no longer offers it while ⌘9 still does.

  C. MUST STILL WORK. This release touched the naming path, so this is
     the regression sweep and it is the important half.
  C1. ⇪4, drag, let go. The shot lands and is named from its words as
      ever.
  C2. Drop a screenshot WITH text into the folder from the other Mac (or
      just take one). EXPECT: it is renamed to "… — <its words>.png"
      within a few seconds, exactly as before.
  C3. ⇪⇧5 then ⌘9 (the naming sweep). EXPECT: it still names everything
      it can, and still reports "N had no readable text". ⌘9 must never
      refuse a file — if it ever says it is skipping something, that is a
      real failure and I want to know at once.
  C4. ⇪5 scrolling capture, and ⇪⇧1 the editor. Unchanged.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.screenshotsReport()` after a full day. The "OCR" and "tried"
      lines are the whole answer, and they are the numbers that could not
      be asked for before: through the entire runaway the old report read
      "named on arrival 0 · left for ⌘9 0", because it counted only
      successes and only cap overflow. A word-less image incremented
      neither.
  D2. If a pill is ever stuck on screen with nothing else happening,
      paste the report then too — that would be a hung `shortcuts`
      process, which is a DIFFERENT bug I have named and not fixed (there
      is no timeout on that task yet).

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Three tries per file — right? A file gets three OCRs before the
      watcher gives up on it. Fewer is quieter; more is more forgiving of
      a OneDrive file that had not finished downloading the first time.
      "three is fine" · "make it two" · "make it five" decides it.
  E2. The memory is in RAM, not on disk, on purpose — writing it would
      mean a main-thread write into the very folder this watcher watches.
      The cost is that a reload or a reboot gives every word-less image
      three fresh tries, once. If you reload often and notice a small
      burst of pills after each one, tell me and I will move it to disk
      properly, with the write off the main thread.
  E3. How many word-less screenshots do you actually have? One line:
      `ls "$HOME/Library/CloudStorage/OneDrive-Personal/2026 Screenshots" | grep -E '^(Screenshot |SCR-[0-9]{8}-)' | grep -vc ' — '`
      That number is how big the burst in E2 is, and it also decides
      whether ⌘9's 40-file cap needs raising — a separate release.

- 6.280.0 verify with LL — 🗑 DELETE A NOTE (KNOWN GROUND)
  WHAT CHANGED: every note row in Hamsidian has a ✕ at its right-hand end.
  It deletes the note — to <Vault>/.trash, never erased.
  WHY IT MATTERS: you asked twice. It was not a bug: vault.lua has said
  "No file delete — Finder and Obsidian do" since the vault was built,
  when that was how you opened it. That stopped being true and nobody
  re-asked the question.

  A. THE HEADLINE.
  A1. Press ⇪3. Look at the right-hand end of any note row.
      EXPECT: a dim ✕, visible WITHOUT hovering, brighter under the
      pointer and red when you are on it.
  A2. Make a throwaway note (⌘N, call it "Delete me") and type a word.
  A3. Click its ✕.
      EXPECT: the row disappears, and an alert reads
      "🗑 Delete me → .trash · _G.vaultUndelete() puts it back".
      A FAIL — and the most important one here — is the note OPENING
      instead of being deleted. Tell me immediately if that happens.
  A4. In Finder, open <OneDrive>/Vault and press ⌘⇧. to show hidden
      files. EXPECT: a .trash folder with "Delete me  <date> <time>.md"
      in it, holding your word. NOTHING IS EVER ERASED.
  A5. Console: `_G.vaultUndelete()`.
      EXPECT: "🕸 Delete me is back", and the note is in the list again.

  B. THE ONE THAT PROTECTS YOUR WRITING.
  B1. Delete a note that OTHER notes link to with [[Name]].
      EXPECT: the alert also says "⚠️ N notes link to it". That number is
      the thing you cannot see from the row you are clicking.
  B2. Delete the note you currently have OPEN.
      EXPECT: the editor moves off it rather than sitting on a file that
      no longer exists. It goes back to your last note (6.277.0).
  B3. Delete two notes with the SAME name from different folders.
      EXPECT: both are in .trash, as two separate files. If the second
      overwrote the first, that is a real failure — say so.

  C. MUST STILL WORK.
  C1. Click a note row on its NAME (not the ✕). EXPECT: it opens, as ever.
  C2. ⌘F filter, ↑↓, ⏎ — unchanged.
  C3. A scratch tab's own ✕ still closes the tab, not a note.
  C4. Obsidian: open the Vault folder. EXPECT: the deleted note is gone
      from its list too, and .trash is ignored there.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.vaultReport()` — the new "deleted:" line names the count, the
      trash folder and the last note deleted.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Should a delete ASK first? I made it immediate, like the music
      history's ✕ you already use, because nothing is destroyed and
      `_G.vaultUndelete()` is one command. If you would rather have a
      confirm, say so — "ask me first" and it is a small release.
  E2. .trash keeps everything for ever. Do you want it emptied on a
      schedule — 30 days, say — or left alone? I left it alone on
      purpose: a trash that empties itself is a trash that can lose the
      thing you go back for.
  E3. Rename is the obvious next thing and I have NOT built it. Say if
      you want it.

- 6.279.0 verify with LL — 📓 WHAT FAILED TODAY (KNOWN GROUND)
  WHAT CHANGED: one command, `_G.todayReport()`, names every tool that
  failed today with the time and the reason — read back off a file, so it
  survives a reload.
  WHY IT MATTERS: your 4 PM double-check. The old ledger was in memory
  only, so every reload wiped it — and a reload is likeliest exactly when
  something has broken and you have just edited something.

  A. THE HEADLINE.
  A1. Console: `_G.todayReport()`.
      EXPECT on a healthy Mac, and it should be BORING:
        📓 WHAT FAILED TODAY — 2026-09-23
           log    : …/Logs/degrades-<your Mac>.csv
           ✅ nothing failed today — the log was read and holds no row…
           wrote  : 0 row(s) this session
  A2. Make something fail on purpose: `_G.degrade("Test tool", "on purpose")`.
  A3. `_G.todayReport()` again.
      EXPECT: "⚠️ 1 failure(s) across 1 tool(s)" and a line naming Test
      tool, the time, and "on purpose".

  B. THE ONE THAT MATTERS — it has to survive a reload.
  B1. Reload Hammerspoon (⌘⌃R, or the menu).
  B2. `_G.todayReport()`.
      EXPECT: the Test tool row is STILL THERE. On every build before
      this one it would be gone. That is the whole release.
  B3. `_G.degradeReport()` for contrast.
      EXPECT: it says nothing has degraded THIS SESSION — correct, and
      the difference between the two is the point.

  C. IT MUST NOT LIE TO YOU WHEN IT CANNOT READ.
  C1. Look at the "log :" path in A1 and confirm the file exists in your
      Logs folder. Open it — it is plain CSV, one row per failure:
      date, time, epoch, tool, reason.
  C2. You do not need to break it on purpose, but know the rule: if that
      file ever cannot be read, the report says "COULD NOT READ IT …
      treat it as unknown, not as clear". It will never print "nothing
      failed today" about a log it could not open.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.todayReport()` at the end of a normal day. That is the artefact
      I want from now on whenever anything feels off — it turns "I think
      something didn't work" into a list with times on it.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Is the Console the right place, or do you want this somewhere you
      will actually look at 4 PM? The obvious next step is making it a
      ⇪D source (`@fails`) so it is in the search you already use. Say
      the word and it is one line plus a release.
  E2. The file grows for ever, one short line per failure. On a healthy
      Mac that is a few rows a week. Tell me if you would rather it kept
      only the last N days — I left it uncapped deliberately, because a
      log that prunes itself is a log that can lose the thing you are
      looking for.

- 6.278.0 verify with LL — 🔔 YOU FIND OUT WHEN A SEND FAILS (KNOWN GROUND)
  WHAT CHANGED: when Hamsidian's Asana send does not go through, you now
  get an alert, a macOS notification, and a line in the report that stays
  there until a send actually succeeds.
  WHY IT MATTERS: you asked how you would know. The honest answer was that
  you would not — a rejected send wrote one line to the Console and did
  nothing else. That breaks a rule you yourself set in 6.214.0 ("anything
  that breaks must throw an error so I see it"), in the one place where
  not knowing costs you what you captured.
  🚨 NOTE THE 4 PM SEND IS STILL OFF — you switched it off in 6.254.0 and
  this release does not turn it back on. Test it with the manual door.

  A. THE HEADLINE — make one fail on purpose.
  A1. Type something into a ⇪N tab so there is a day's worth to send.
  A2. Turn Asana off for a moment: rename your token line in secret.lua,
      or just run A3 on a Mac where Asana was never configured.
  A3. Console: `_G.scratchPadSend()`.
      EXPECT THREE THINGS, and all three matter:
      · an on-screen alert naming the tool and the cause;
      · a macOS NOTIFICATION saying your text is safe;
      · Console: `⚠️ Hamsidian 4 PM send: …`
  A4. Console: `_G.scratchPadReport()`.
      EXPECT a line starting `⚠️ NOT SENT:` with the time, the reason, and
      "your text is still in the tabs". THAT is the line that is still
      there at 4 PM when you go looking — the alert will be long gone.
  A5. Check the tab. EXPECT: every word still there.

  B. THEN MAKE IT WORK.
  B1. Put Asana back and run `_G.scratchPadSend()` again.
      EXPECT: a ✅ alert naming the task, and the task in Asana.
  B2. `_G.scratchPadReport()` again.
      EXPECT the ⚠️ NOT SENT line is GONE, replaced by "nothing is
      waiting". A warning that never clears is one you stop reading.

  C. IT MUST NOT CRY WOLF — this is the half that decides whether you
     keep the feature.
  C1. With NOTHING written today, run `_G.scratchPadSend()`.
      EXPECT: no alert, no notification, nothing on screen. Just a
      Console line saying there was nothing to send. If an empty day
      warns you, tell me — I will take it out.

  D. IF YOU WERE IN A MEETING (worth one try if you use Focus).
  D1. Turn on a Focus mode, then make a send fail as in A3.
      EXPECT: no notification during Focus, and the Console says
      "🔕 Held until Focus ends". Turn Focus off — the notification
      arrives then. The alert still appears immediately either way.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Is a successful send saying "✅ Hamsidian → Asana: <task>" on screen
      welcome, or noise? I made success visible on purpose so that silence
      has one meaning instead of two — but you are the one who sees it
      every day. "keep it" · "failures only" decides it.
  E2. Next release (6.279.0) is the log you asked for — every tool that
      failed today, in one command, so 4 PM is a single check rather than
      a memory test. Tell me if you would rather have it somewhere other
      than the Console.

- 6.277.0 verify with LL — 🔖 ⇪3 PUTS YOU BACK (KNOWN GROUND)
  WHAT CHANGED: ⇪3 reopens the note you were last writing in, instead of
  whatever was left on screen. ⇪N is unchanged — it still opens the tabs.
  WHY IT MATTERS: your words. With thousands of notes, having to find the
  one you were in every time is the tool asking you to do its job.
  🔎 AND THE HONEST PART: the note was ALREADY being remembered, on every
  open, for releases. It was only ever read when nothing was open — and
  one press of ⇪N left a scratch tab "open" for the rest of the session,
  so it was almost never read. Nothing was lost; it just could not be
  reached.

  A. THE HEADLINE.
  A1. Press ⇪3, open a real note, type a word in it. Press ⇪3 to close.
  A2. Press ⇪N (the tabs), look at Scratch 1, press ⇪N to close.
  A3. Press ⇪3.
      EXPECT: the NOTE from A1, open, with your word in it.
      A FAIL is landing on Scratch 1 — that is the old behaviour exactly.
  A4. Do A1–A3 again but reload Hammerspoon between closing and reopening.
      EXPECT: the same note. This is the path that used to work, so if A3
      passes and A4 fails, tell me — that is a different bug.

  B. MUST STILL WORK.
  B1. ⇪N still opens on the tabs, never on the note. Press it twice.
  B2. ⌘F filter, ↑↓, ⏎ to open a note — all as before.
  B3. Open a note, close with ⇪3, reopen: your unsaved keystrokes are
      still there (the save-on-close path is untouched).

  C. THE ONE THAT PROTECTS YOUR WRITING — worth doing once.
  C1. Open a note, close Hamsidian, then RENAME or delete that note's .md
      file in Finder (pick something you do not mind losing).
  C2. Press ⇪3.
      EXPECT: it opens on the notes list, and it does NOT re-create the
      note you just removed. Check Finder: the file must still be gone.
      A FAIL here — the file reappearing — is the worst outcome in this
      release and I want to know immediately.
  C3. Console: `_G.vaultReport()`, the new "back to:" line.
      EXPECT: "remembered <name> — this vault no longer holds it", with a
      ⚠️ under it. In normal use it reads "reopened <name>".

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.vaultReport()` — the whole block, after doing A1–A3.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. ⇪3 now always goes back to the last NOTE, even if the last thing
      you touched was a scratch tab. Is that right, or would you rather
      it returned to whichever of the two you saw last, whatever it was?
      "notes always" · "whatever I saw last" decides it. I picked the
      first because it is what you described, and because ⇪N already
      gives you the tabs in one press.

- 6.276.0 verify with LL — 🆓 THE FREE-KEY CARDS TELL THE TRUTH (KNOWN GROUND)
  WHAT CHANGED: the ⇪/ cards that list which keys are still free no longer
  have that list typed into them. They ask the live key registry when
  Hammerspoon warms up, which is the same place `_G.freeKeys()` has been
  reading correctly since 6.142.0.
  WHY IT MATTERS: you were told ⇪⇧pad. was available. The music player has
  owned it since 6.231.0. You were right to ask whether the debugging was
  good, and the honest answer is that this one was not — the card and the
  command disagreed for five releases and nothing in the gate could see it.
  🚨 AND IT WAS WORSE THAN THE ONE KEY, which you should know before you
  trust any other row on those cards: the same cards said ⇪⇧7 and ⇪⇧8 were
  unbound while Bluetooth and the QR reader held them, and one card
  contradicted itself four lines apart.

  A. THE HEADLINE — the card that lied.
  A1. Press ⇪/ and search for `numpad`.
      EXPECT: the 🆓 NUMPAD — ⇪⇧ pad card. Its free row now reads a real
      list of key names after a 🆓, e.g. `🆓 pad0 pad1 pad2 …`.
  A2. Read that list. EXPECT: **pad. is NOT in it.** That is the whole
      release. If `pad.` is still offered, this did not take — tell me.
  A3. Look at the 🆓 THE ⇪⇧ NUMBER ROW card, the "cleared" row.
      EXPECT: a 🆓 list that does NOT contain 7 or 8.
      It used to say "⇪⇧5 7 8 · ⇪⇧, ⇪⇧. ⇪⇧⏎ — all unbound now".
  A4. If any row still reads "asking the key registry…", that is the
      THIRD state and it is honest, not broken — it means warm-up has not
      run yet (give it a few seconds after a reload) or power_tools did
      not load. Step C2 says which.

  B. THE COMMAND IS THE TRUTH, AND NOW THEY AGREE.
  B1. Console: `_G.freeKeys()`.
      EXPECT: the same keys the card shows, on the `⇪⇧ pad` line.
      That agreement is the point — before this release the two disagreed
      and only one of them was right.
  B2. Pick any key the card offers and check nothing happens when you
      press it. EXPECT: nothing. If something DOES happen, that key is
      claimed by a route the registry cannot see, and that is a real
      finding I want.

  C. PASTE BACK, PASS OR FAIL.
  C1. `_G.freeKeys()` — the whole block.
  C2. `_G.padProbe()` — there is a new "🆓 free rows:" line near the
      bottom. Healthy reads `N free-key row(s) read from the live
      registry`. If it reads "not read yet" or "did not answer" there is
      a ⚠️ under it telling you to trust the command and not the card —
      paste that, it is the evidence.

  D. MUST STILL WORK — nothing about any KEY changed in this release,
     only what the cards SAY, so this is the regression sweep.
  D1. ⇪⇧pad. still opens the music player.
  D2. ⇪⇧7 still opens Bluetooth; ⇪⇧8 still reads a QR code.
  D3. ⇪; still opens power tools, and its 🆓 row still runs the report.
  D4. The numpad capture row (⇪pad1 … ) still works as it did.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. The cards now show raw key NAMES as the registry stores them —
      `pad0 pad1 pad.` and `a b c` — rather than the prettier hand-typed
      ranges ("⇪⇧ pad0–9"). Truthful but blunter. Is that the right
      trade, or do you want me to render them back into ranges? "keep it
      plain" · "make it pretty again" decides it, and pretty is only safe
      because it is now generated rather than typed.

- 6.275.0 verify with LL — 📘 THE INSTALL GUIDE (KNOWN GROUND, docs only)
  WHAT CHANGED: INSTALL.md is rewritten and HAMSIDIAN.md has a new §7b on
  linking. NO code changed — same modules, same keys, same behaviour.
  WHY IT MATTERS: you missed the install on the work Mac, and the old
  guide made that easy. The step that matters is the one that puts files
  in ~/.hammerspoon, and skipping it looks exactly like doing nothing.

  A. THE HEADLINE — do this ON THE WORK MAC.
  A1. Open INSTALL.md from the archive root. Read the box at the very top.
      EXPECT: one command, and what ✅ and ❌ look like.
  A2. Run that command on the work Mac:
        ls ~/.hammerspoon/init.lua && sed -n 7p ~/.hammerspoon/init.lua
      EXPECT: either a version line (installed) or "No such file or
      directory" (not installed). Either answer is useful — tell me which
      you got, because it settles what happened there.
  A3. If it says not installed, follow Step 3 end to end and run 3d.
      EXPECT 3d prints: a path · the version · 12 · 71 · a path.
      If any line is missing, that is the bug and I want the output.

  B. THE SNIPPETS QUESTION, ANSWERED — check it rather than take my word.
  B1. On the work Mac: `ls ~/.hammerspoon/snippets/bundled.lua`
      EXPECT: a path. The 1,926 public snippets ship IN the archive and
      the installer places them. Nothing to install.
  B2. Press ⇪⇧S. EXPECT: the picker, with sections.
  B3. Console: `_G.snippetsList()`. EXPECT: a count in the thousands.
  B4. Type a trigger in any app. EXPECT: it expands.
      ❌ If the picker works but typing does nothing, Accessibility is off
      or was granted AFTER launch — quit and relaunch Hammerspoon.

  C. THE IT SECTION — read it before you talk to them.
  C1. Read "What IT has to say yes to". Four rows, each with what you lose
      if refused, plus the list of what they do NOT have to allow.
  C2. Tell me if anything there is wrong for YOUR employer, or if they
      ask for something the list does not cover. That is the one part I
      cannot verify from here, and it is the part that decides whether
      this runs at work at all.

  D. HAMSIDIAN §7b — linking out.
  D1. Read §7b. Then do it: open a Word document, press ⇪⇧U, press ⌘2,
      pick a note.
      EXPECT: the note gains a `## Linked` section with one Markdown line.
  D2. In Hamsidian, press ⌘K and pick a screenshot from OneDrive.
      EXPECT: a Markdown link at the caret; ⌘⏎ on it opens the image.

  E. QUESTIONS — ANSWERS WANTED, NOTHING TO RUN.
  E1. What is the work Mac's computer name (`scutil --get ComputerName`)?
      It gets its own profile in the next release, which is how we switch
      anything off there without you editing init.lua.
  E2. Scratch tabs vs notes: do you want a ⇪N tab to become a real .md
      note the moment you make it (one list, everything a file, and every
      keystroke writes to OneDrive), or to stay a tab until you press ⌘⇧S
      (fast and local, two lists)? That one answer is the whole release —
      see the queue note.
  E3. Did the archive open? Both a .tar.gz and a .zip are in this one
      because you asked for the zip by name. Tell me which you used and
      whether it worked, and the next release carries only that one.

- 6.274.0 verify with LL — 🔔 ⇪4 LEAVES A NUMBER BEHIND (KNOWN GROUND)
  WHAT CHANGED: nothing about how ⇪4 captures. This release exists so that
  the NEXT time it does not, we can tell which of four things happened
  instead of guessing.
  🚨 I HAVE NOT FIXED YOUR ⇪4, and I am saying that first rather than
  letting you find it out. I read every path that could make that key do
  nothing and they all already say why — 6.265.0 closed that class. What
  I could not do is tell, from "intermittently working", WHICH of them you
  are hitting. So: instruments, then the fix.
  🔎 AND YOUR CONSOLE CARRIED THE CLUE I COULD ACT ON: three
  "⚠️ an alert could not draw" lines in eight hours. That is macOS
  refusing to draw one of OUR messages — and every message this config
  has ever given you goes through that one channel. So an alert
  explaining why ⇪4 did nothing could itself have been refused, and
  nothing recorded that it happened or what it said.

  A. THE HEADLINE — the new reports. Nothing to break, everything to read.
  A1. Console: `_G.alertReport()`.
      EXPECT on a healthy Mac, and it should be BORING:
        asked     : <N> this session
        refused   : none — macOS drew every alert it was asked for
      If "refused" is a number, paste the whole block. The "↳ last refused
      said:" line names what you missed.
  A2. Console: `_G.screenshotsReport()` — look for the new "routes :" line.
      EXPECT, before you have pressed ⇪4: "⇪4 has not been pressed this
      session".
  A3. Press ⇪4 and drag a rectangle. Run it again.
      EXPECT: "routes : 1 press(es) — 1 on our selector · 0 on macOS's
      crosshair", and NO ⚠️ under it.

  B. THE ONE THAT MATTERS — use the Mac for a day, then read it.
  B1. After a normal day, Console: `_G.screenshotsReport()` and
      `_G.alertReport()`. PASTE BOTH.
      The three numbers that answer your report:
      · "routes" — how many ⇪4 presses went to OUR selector vs macOS's.
      · the ⚠️ line under it — how many of the macOS ones were a REFUSAL
        rather than a setting. THAT number is your "intermittently".
      · "↳ ⚠️ N press(es) found no folder to write to" — if this appears,
        your screenshots folder was missing at that moment, which would
        make ⇪4 do nothing at all. It is in OneDrive, so this is a real
        candidate and it has never been counted before.
  B2. If ⇪4 does nothing at some point in that day, note roughly WHEN and
      run both reports straight away. The clock in each line is what lets
      me line it up with your Console.

  C. MUST STILL WORK.
  C1. ⇪4 captures, with the live 1280 × 720 readout and the shutter.
  C2. ⇪5 scrolling capture still works.
  C3. In the editor (⇪⇧1), ⌘A still drags on our selector.
  C4. Any alert you normally see — ⇪Z learning a word, a copy confirmation
      — still appears. The wrapper counts; it does not gate.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. When ⇪4 "does not work", what do you actually see? Three different
      answers send me to three different places, and I cannot tell them
      apart from here:
      · nothing at all happens — no crosshair, no sound;
      · macOS's PLAIN crosshair appears (no black size box) — that is the
        fallback working, and the refusal count will prove it;
      · our dashed blue selector appears but the drag does not capture.
      One sentence is enough.

- 6.273.0 verify with LL — 🔌 ⇪⇧U CAN FINALLY DO ALL FOUR THINGS (KNOWN GROUND)
  WHAT CHANGED: your BLOCKED report on the anchors card was right, and the
  one line that proved it was `note : table: 0x77fdbff940`. A Lua table
  printed where a sentence belongs meant a value had landed in the wrong
  slot — and it had, at all four places this tool asks another module for
  an answer. Three of ⇪⇧U's four legs have never worked, on any Mac, since
  6.180.0. They work now.
  WHY IT MATTERS: you could not have found this by reading the card. You
  found it by TRYING the card, and the report did the diagnosing.
  🚨 A STEP I OWE YOU AN APOLOGY FOR: my 6.269.0 step C1 said "press ⇪⇧U
  with a document or browser tab in front" and gave you no setup, so you
  pressed it over Transmission — which genuinely has no document and no
  tab, making "the app only" both the correct answer AND indistinguishable
  from the bug. That is a defect in the STEP, not in your testing. The
  steps below name the app to use.

  A. THE HEADLINE — THE DOCUMENT LEG. This is the one that was dead.
  A1. Open a real document in Microsoft Word (or Excel, Preview, TextEdit,
      Pages, Numbers, Keynote, PowerPoint, Acrobat). Click into it so it
      is the front window. Press ⇪⇧U.
      EXPECT the title at the top of the panel to name THE FILE:
      `🔗 document: Strategies of the Directors.docx`
      A FAIL is `🔗 app: Microsoft Word  (no document or tab — the app
      only)` — that is the old behaviour and means this release did not
      take. Tell me and stop here.
  A2. Press Esc. Now click into a Chrome tab and press ⇪⇧U.
      EXPECT `🔗 tab: <the page title>`. (This leg was NOT broken — it is
      here so you can see the two named differently.)
  A3. Press Esc. Click into Transmission — or anything with no document,
      which is what you had last time — and press ⇪⇧U.
      EXPECT `🔗 app: Transmission  (no document or tab — the app only)`.
      THIS IS CORRECT, and it is what you photographed. It is only a fault
      when it happens in A1.

  B. THE PICK ROW — the row in your screenshot that could never work.
  B1. Press ⇪⇧U anywhere. Press ⌘2, or click "📁 Link it into an existing
      note…".
      EXPECT a picker listing your notes — you have about twenty.
      A FAIL is "🔗 No notes to pick yet — make one with the first row".
      That was the answer EVERY time before this release.
  B2. Pick a note. EXPECT "🔗 Linked into <note>", Hamsidian opens, and
      the note has a `## Linked` section with a plain Markdown line in it.
  B3. Press ⇪⇧U again on the SAME thing.
      EXPECT that note now listed at the TOP as already linking it, and
      ⏎ on it opens the note.
  B4. Do B2 again on the same note. EXPECT "🔗 Already in <note>" — one
      line, not two. (The "already linked" wording was also broken.)

  C. ⌘1 — the leg that DID work, so it must still.
  C1. Press ⇪⇧U in a Word document, then ⌘1 ("➕ New note: <file>").
      EXPECT a new note named after the file, with the link written in.

  D. PASTE BACK, PASS OR FAIL.
  D1. Console: `_G.anchorsReport()` — the whole block. Two things to read:
      · `note :` must be a SENTENCE now, never `table: 0x…`.
      · the new `named :` line counts the legs apart:
        `named  : 1 browser tab(s) · 1 document(s) · 1 app only  — last: …`
        After doing A1–A3 that is exactly what it should say. If
        `document(s)` is 0 after A1, this release failed.
  D2. If every press has fallen back to the app name, the report says so
      in its own line ("the shape of a fault"). That line existing is the
      point — it is what would have told us in 6.180.0.

  E. MUST STILL WORK — this release also touched Hamsidian.
  E1. In Hamsidian, open a note with a `file://` link in it and ⌘⏎ the
      link. EXPECT the file opens. (I changed the one line that handles a
      link whose file has MOVED — it had the mirror image of the same bug.)
  E2. If you have a file you have renamed or moved since linking it, try
      that link. EXPECT "🕸 Moved — opening <name>". This has never worked
      before; if it still does not, say so — it needs the ⇪D index to hold
      the new name, which is a different question from this fix.

  F. QUESTIONS — ANSWERS WANTED, NOTHING TO RUN. (Separated on purpose:
     last time a block like this sat inside the lettered steps and you
     scored it BLOCKED, which was my formatting's fault, not yours.)
  F1. Four visible strings still tell you to use Obsidian — ⇪3's card row,
      ⇪N's ⌘⇧S row, `_G.vaultReport()`, the vault summary — plus the ⇪⇧U
      row 6.269.0 made visible ("plain Markdown under '## Linked' —
      Obsidian opens it"). Nothing in this config launches or requires
      Obsidian; it is a FILE-FORMAT lineage, so your notes stay portable.
      The behaviour stays either way. Do you want the wording changed?
      "leave it" · "call it Markdown" · "call it Hamsidian" decides it.
  F2. You asked: can the music player go in ⌥Tab? Yes — it is a real
      window and ⌥Tab is ours. One release, when you want it. Say the word.

- 6.272.0 verify with LL — 🗑 FORGET A TRACK FROM THE HISTORY (KNOWN GROUND)
  WHAT CHANGED: you could not remove anything from the 🕘 history list —
  ⌫ took a track out of the QUEUE, and clicking a history row PLAYED it.
  Every history row now has a ✕ on its right. It forgets the row; it never
  touches the file.
  WHY IT MATTERS: you asked whether this existed and did not want to have
  to ask again. It did not. It does now.

  A. THE HEADLINE.
  A1. Press ⇪⇧pad. to open the player. Play two or three tracks so the
      🕘 history at the bottom has rows in it.
      EXPECT: a history section with one row per file.
  A2. Look at the right-hand end of any history row.
      EXPECT: a ✕, visible WITHOUT hovering (dim grey), brightening when
      the pointer is over it.
  A3. Click the ✕ on a history row.
      EXPECT: that row disappears from the list, AND NOTHING STARTS
      PLAYING. If the track begins playing, that is a FAIL and the most
      important one in this release — tell me immediately.
  A4. Check the track that WAS playing is still playing, and the queue
      above is unchanged.
      EXPECT: the ✕ touched the history list and nothing else.
  A5. Close the card (⇪⇧pad.) and reopen it.
      EXPECT: the row you forgot is still gone — it was saved, not just
      hidden.
  A6. In Finder, confirm the actual audio FILE is still on disk.
      EXPECT: it is. This forgets a row, never a file.

  B. MUST STILL WORK.
  B1. Click a history row on its NAME (not the ✕).
      EXPECT: it plays again, exactly as before.
  B2. Select a row in the QUEUE with ↑↓ and press ⌫.
      EXPECT: it leaves the queue. This is the old behaviour and must be
      unchanged.
  B3. Drop two or three files on the card.
      EXPECT: they queue and the first plays.
  B4. Press space, then → and ←.
      EXPECT: pause/resume, then seek forward and back 5 s.

  C. PASTE BACK, PASS OR FAIL.
  C1. Console: `_G.musicReport()` — the whole block. The new "forgot :"
      line counts the rows you removed this session.
  C2. After step A3, the "history :" line should show one fewer track.

  D. THE BULK DOORS, worth one try each.
  D1. Console: `_G.musicForgetHistory("/full/path/to/a/track.mp3")`
      EXPECT: it names how many rows it removed, or says there was no row
      for that path.
  D2. Console: `_G.musicClearHistory()`
      EXPECT: the list empties, and the message says the files themselves
      are untouched. Only run this if you do not mind losing the list.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Is a ✕ per row the right control, or would you rather select a
      history row and press ⌫ the way the queue works? The second is a
      bigger change — the history rows are not keyboard-selectable today
      — so I did the simpler one. "✕ is fine" or "I want ⌫" decides it.

- 6.271.0 verify with LL — 🧪 THE TEST PLAN IS IN THE ARCHIVE (KNOWN GROUND)
  WHAT CHANGED: there is a TESTING.md at the root of the archive with the
  steps for each release it carries. You asked for it; the honest finding
  is that I had been writing these for every release since June and filing
  them in CLAUDE.md, which is not in the package — so none ever reached
  you and you were left inventing your own testing off the cheat sheet.
  WHY IT MATTERS: it is the thing that turns "that worked" into data.

  A. THE HEADLINE.
  A1. Unpack the archive and list what is at its root.
      EXPECT: TESTING.md is there, beside GUIDE.md and INSTALL.md.
  A2. Open TESTING.md. Read the first line.
      EXPECT: "# TESTING — how to score release 6.271.0" — THIS version.
      Any older number is a FAIL and means the plan describes a build you
      are not holding.
  A3. Scroll to the "How to report back" section.
      EXPECT: it names three answers — PASS, FAIL, BLOCKED — and says to
      paste the Console reports whether or not anything failed.
  A4. Count the release sections (## 6.2xx.0 headings).
      EXPECT: four, newest first, starting with 6.271.0.
  A5. Read the 6.270.0 section.
      EXPECT: numbered steps with an EXPECT on each, grouped A/B/C/D —
      not the paragraphs the older sections are still written in.

  B. THE REAL TEST OF THIS RELEASE IS THE NEXT ONE. There is nothing to
     exercise in the config: no key, no panel, no behaviour changed.
  B1. Run the 6.270.0 section of TESTING.md end to end and send me the
      results in its format.
      EXPECT: you get through it without having to ask me what a step
      means. If a step is ambiguous, THAT is the bug in this release —
      tell me which number and what was unclear.
  B2. Then the 6.269.0 section the same way.

  C. PASTE BACK.
  C1. Nothing new. The reports the two sections above ask for are the
      whole of it — which is the point: this release adds instructions,
      not instruments.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. Is four releases per plan the right depth, or do you want only the
      newest? "four is right" · "just the newest" · "all of them".
  D2. Are the steps at the right grain? Too coarse and they miss things;
      too fine and you will not run them. Tell me which way to move, on
      the 6.270.0 section specifically, since that is the one with the
      most steps.
  D3. Anything you routinely check that I have NOT asked for — that is
      the most valuable answer here, because it is a test I do not know
      to write.

- 6.270.0 verify with LL — 🖼 THE EDITOR'S TWO RAILS (KNOWN GROUND)
  WHAT CHANGED: the screenshot editor's eighteen buttons were all in one
  wrapping strip across the top. Nine drawing tools now run down the LEFT
  edge, six capture/edit actions down the RIGHT, and the window is wider
  by exactly the two rails so the picture is not squeezed to make room.
  WHY IT MATTERS: this is the thing you asked for three times and were
  right about every time — it had never been built.

  A. THE HEADLINE. If any step in A fails, stop and tell me; the rest
     tells me nothing until this works.
  A1. Press ⇪⇧1 on any screenshot (or ⌥⏎ on a row in ⇪space @shots).
      EXPECT: the editor opens with a column of buttons down the LEFT
      edge AND a column down the RIGHT edge.
  A2. Read the LEFT column top to bottom.
      EXPECT exactly nine, in this order, under a "TOOLS" label: Blur,
      Text, Arrow, Line, Oval, Highlight, Counter, Spotlight, Magnifier.
  A3. Read the RIGHT column top to bottom.
      EXPECT six, under "ADD" then "EDIT": Paste image, Add capture,
      Delayed 5s, Full screen, Load shot, then Undo.
  A4. Read the strip across the TOP.
      EXPECT four things only: 🖌 Edit, Save & copy, Small JPEG, Cancel.
      A drawing tool still up there is a FAIL — say which one.
  A5. Look at where the screenshot itself is drawn.
      EXPECT: neither rail overlaps the picture, and the picture is not
      cropped. The buttons sit BESIDE the shot, never on top of it.
  A6. Close it, then open the editor on a much SMALLER screenshot.
      EXPECT: same nine and six buttons, none cut off at the bottom, and
      still no rail over the picture.

  B. MUST STILL WORK. Not new — but this release moved every button, so
     it is the most likely thing to have broken.
  B1. Press the letters B, T, A, L, O, H, C, S, M one at a time.
      EXPECT: the armed tool changes each time and the matching button
      in the LEFT rail highlights.
  B2. Drag on the picture with Blur armed. EXPECT: the area blurs.
  B3. Press T, click the picture, type a word, press ⏎.
      EXPECT: the text lands where you clicked.
  B4. Hold ⌘ and click that text box. EXPECT: its words open for editing.
  B5. Press ⌘Z. EXPECT: the last mark is undone.
  B6. Hold ⌘ and drag the TOP strip. EXPECT: the window moves.
  B7. Hold ⌘ and drag the PICTURE. EXPECT: the window does NOT move
      (⌘ on the picture means "edit this mark" — 6.221.0).
  B8. Press ⌘⏎. EXPECT: it saves "… (edited).png" beside the original
      and puts it on the clipboard; ⌘V pastes it.

  C. PASTE THESE BACK, pass or fail. A report from a working Mac is what
     tells me what a broken one is missing.
  C1. Console: `_G.screenshotEditorReport()` — the whole block. The new
      "layout :" line names the rail width and what the window reserves.
  C2. Console: `_G.screenReport()` — which monitor placed the last panel.

  D. A JUDGEMENT ONLY YOU CAN MAKE, and the one number I could not
     determine from here.
  D1. Is 136 points the right rail width on YOUR display? The longest
      labels are "🖍 Highlight", "📸 Add capture" and "⏲ Delayed 5s".
      Answer one of: "right" · "too narrow, <label> is cut off" · "too
      wide, it steals room from the shot". If it is wrong it is a number
      and not a release — I will move the default rather than hand you
      `settings = { screenshot_editor = { railW = 160 } }` to type.
  D2. On a very small screenshot the window is now taller than the
      picture needs, deliberately, so the nine tools fit. Is that
      annoying enough to change? "fine" or "annoying" is the whole answer.

- 6.269.0 verify with LL — 🔗 THE ANCHORS CARD HAS ROWS (KNOWN GROUND)
  WHAT CHANGED: ⇪⇧U's card on the cheat sheet has been a heading over
  empty space since 6.180.0 — its eight rows were written under the wrong
  key and the loader silently turned them into nothing. They are back. And
  a card that ever registers with no rows now says so out loud instead of
  drawing a blank space.
  WHY IT MATTERS: it was invisible for eighty-nine releases and only
  surfaced because you asked me to read the cheat sheet.

  A. THE HEADLINE.
  A1. Press ⇪/ and type `anchors` in the search box.
      EXPECT: the 🔗 ANCHORS card, with EIGHT rows under it.
  A2. Read the eight key-column entries.
      EXPECT: ⇪⇧U · again · ⏎ · new · pick · in a note · moved · Console.
      On every release you have installed, that card had none of these.
  A3. Open RESOLVED-FEATURE-REQUESTS.txt at the root of the archive and
      search for "Link the front document".
      EXPECT: it is there. It never has been — the same bug hid those
      rows from that file too, so this is a second, independent proof.

  B. THE NEW INSTRUMENT.
  B1. Console: `_G.cheatSheetReport()`.
      EXPECT four lines, and this is the shape of a healthy answer:
        cards  : <N> card(s) · <N> row(s) from 71 module(s)
        empty  : none — every card that should have rows has them
        listed : 1 card(s) are a heading alone ON PURPOSE … Copy-on-Select
        faults : none — no module registered a card with no rows
  B2. Check that "empty" reads **none** and "faults" reads **none**.
      A number on either is a real finding — paste it.
      The "listed" line is NOT a warning: Copy-on-Select has no cheat
      sheet of its own and is listed so the tool appears at all.

  C. MUST STILL WORK.
  C1. Press ⇪⇧U with a document or browser tab in front.
      EXPECT: it identifies what is in front and offers notes that
      mention it, exactly as before. Nothing about ⇪⇧U's behaviour moved
      — only its cheat-sheet card.
  C2. Press ⇪/ and search for a punctuation key, e.g. `\`.
      EXPECT: the sheet filters (6.250.0 — still working).

  D. PASTE BACK, pass or fail.
  D1. `_G.cheatSheetReport()` — the whole block.
  D2. `_G.anchorsReport()` — the "tasks :" line should say callbacks
      stepped off a held timer, with no ⚠️.

  E. FOR YOUR EYES, not a test: one of the eight rows now visible says
     the link is "plain Markdown under '## Linked' — Obsidian opens it".
     That is the Obsidian wording you asked about, and fixing this card
     has SURFACED it rather than changed it. Rewording those strings is
     your call and its own release — say the word.

- 6.268.0 verify with LL — 🗑 THE HINT CARD IS GONE (KNOWN GROUND):
  install (carries 6.267.0, so do that block's ⏱ boot-line check too).
  ⇪/ and search `hint` — the 💡 SHORTCUT HINTS card you photographed is
  NOT in the sheet, because the tool is not in the config.
  Console: `_G.shortcutHintsReport()` → "attempt to call a nil value".
  That error IS the release working; an error is the only honest proof
  that a thing is gone.
  The boot log no longer carries the `💡 shortcut hints 6.167.0 — card
  810 wide …` line, and the module count reads 71, not 72.
  🚨 EVERY ⇪ KEY MUST BEHAVE EXACTLY AS IT DID. This is the one thing to
  actually exercise, because the deleted hook was called from hyperBind —
  the single place every hyper shortcut in the config passes through. Use
  ⇪T, ⇪D, ⇪N, ⇪3, ⇪space, ⇪X, ⇪V for a day. Nothing should look or feel
  different; no card was appearing anyway, since 6.240.0.
  📏 ONE THING LEFT ON PURPOSE, so it is not a surprise: the panel ladder
  in core/coexist.lua still has a rung named `hint`, unused, with a note
  saying why. It is one line of a table and removing it would re-level
  every panel above it for no gain — the same call made when win_pin went
  in 6.166.0.
  🔑 IT IS DELETED, NOT LOST: every line is in git at 6.267.0 (a621a60)
  and the whole story is in CHANGELOG.md. If you ever want it back it is
  a checkout, not a rewrite.

- 6.267.0 verify with LL — ⏱ THE BOOT (KNOWN GROUND): install (carries
  6.266.0, so do that block's ⇪X check too). Reload, and read the ⏱ line
  in the Console. It used to say:
      ⏱  Boot cost: 453 ms across 72 modules — slowest: file_tracker
         200ms, activity_tracker 150ms, autocorrect 12ms.
  It should now be a fraction of that, with NEITHER of those two modules
  at the top. Paste the new line — that is the whole measurement, and it
  is the number to compare.
  ✅ ANSWERED ON THE HOME MAC (2026-09-24 20:38, on 6.281.0, which
  carries it): THERE IS NO ⏱ LINE, AND THAT IS THE MEASUREMENT.
  `cost.line()` returns nil unless a module crossed `slowModuleMs` (150)
  or the load crossed `slowTotalMs` (1500) — a fast boot is silent by
  design. What printed instead: `🧭 Lees-MacBook-Air · 71 modules ·
  106 ⇪ shortcuts · 0.22s`, All green. AND THE COMPARISON IS
  CONSERVATIVE: 0.22 s is the 🧭 line's WHOLE-BOOT wall clock
  (init.lua:148's `_G.diagBootStart` to the summary print), while 453 ms
  was the ⏱ line's module-load SUM alone — the superset now costs less
  than half what the subset did, so file_tracker's 200 ms and
  activity_tracker's 150 ms are provably off the boot path. NOT SCORED:
  he pasted a boot log, not a verdict, and only he scores.
  🚨 GENERAL, and it is the half to carry: AN INSTRUMENT BUILT TO BE
  SILENT ON A HEALTHY MAC CANNOT BE ASKED FOR BY NAME. This block told
  him to paste a line that a WORKING release guarantees will not exist,
  so a pass reads as "he skipped the step" — 6.196.1's two-states
  problem, inside a test plan instead of a report. When a step asks for a
  threshold-gated instrument, say what its ABSENCE means in the same
  breath.
  🔎 WHAT MOVED: both of those modules opened a CSV in OneDrive during
  boot, read it whole, parsed months of rows and sometimes rewrote the
  file — on the main thread, before any ⇪ key was bound. They read it a
  few seconds after boot now, when nothing is happening.
  🚨 THE TWO THINGS THAT MUST STILL WORK, and they are the point:
  ⇪F opens the file history with your 90 days in it, exactly as before.
  ⇪0 and ⇪⇧W show your app and document time, exactly as before. If
  either ever opens EMPTY and then has rows a moment later, that is a
  real break and I want to know — it would mean a reader got in front of
  the read, which is the one thing this release is built not to allow.
  Console: `_G.fileTrackerReport()` and `_G.activityDocsReport()` each
  have a new "history" line. Straight after a reload it reads "not read
  yet" — that is health, not a fault. A few seconds later it reads "read
  N row(s) in N ms". If it still says "not read yet" a minute after boot,
  paste it: the warm phase did not run.
  📏 NAMED, NOT FIXED: the read is still a synchronous main-thread read
  when it happens; it has moved off the boot, not off the thread. Taking
  the parse off the thread entirely is its own release.

- 6.266.0 verify with LL — 🧊 THE FROZEN GRID BOX (KNOWN GROUND):
  install (carries 6.265.0, so do THAT block's ⇪4 test first — it is the
  one I owe you). Then use ⇪X normally for a few days. Nothing about it
  should look different: the grid draws, the three letters land, the box
  splits, the arrows nudge, Esc closes it.
  🔎 WHAT THIS FIXES IS THE THING YOU TOLD ME TO DISREGARD. When you sent
  the photograph of the yellow box stuck over a Finder dialog, I wrote
  down what I thought caused it and left it as a suspect. The reading was
  right, and here it is in one sentence: when macOS refused to draw the
  grid, this config retried 50 ms later and showed the box ITSELF — and
  if you had pressed Esc in the meantime, it came up with nothing able to
  close it. Not Esc, not `_G.mouseGrid.hide()`. Only a reload, which is
  what you had to do.
  📏 THE ONE THING YOU MAY NOTICE, so it is not a surprise: if macOS
  refuses a panel, it no longer appears half a second later on its own —
  you press the key again, and the Console says so straight away
  ("⚠️ <panel>: macOS refused to show it … Press the key again"). You
  used to get that message only when it failed TWICE. If you see that
  line for a panel that used to open fine, paste it.
  Console: `_G.canvasShowReport()` — new, this helper never had one.
  "macOS has not refused a panel this session" is the healthy line.
  "refused N · handed back N · dropped N" is the story when it has: a
  hand-back means a tool was given the chance to try again, a drop means
  nothing was tried on purpose because there was no owner to hand it to.
  🚨 IF A STUCK BOX EVER HAPPENS AGAIN, it is a real finding and I want
  the report plus `_G.mouseGridReport()` — because the mechanism this
  release closes is the only one I can see from the source, and a second
  one would have to be found the same way.
  📏 NAMED, NOT FIXED: fourteen other panels go through the same helper
  and none of them asks to be told yet. They can no longer orphan
  anything — that is what this release guarantees — but a panel of theirs
  that macOS refuses simply does not open now. mouse_grid took the door
  first because it is the one that demonstrably broke. The others follow,
  one per release.

- 6.265.0 verify with LL — 🚨 ⇪4 SHOOTS AGAIN (KNOWN GROUND): install.
  Press ⇪4 and drag. It captures. That is the whole test, and it is a
  regression I caused in 6.264.0, so do it first.
  🔎 WHAT IT WAS: 6.264.0 put ⇪4 on our own selector and wrote a fallback
  to macOS's crosshair for a Mac that could not draw ours — and then
  ignored the one value that says whether it drew. When macOS refused to
  put the selector on screen (another app's popup mid-transition, which
  your beta does often), the key thought it had opened, never fell back,
  and did nothing at all — no crosshair, no shot, no message. The fallback
  was correct and unreachable.
  🔁 IF IT EVER DOES NOTHING AGAIN, it will now SAY so instead: an alert
  reads "⚠️ Screenshot area selector — our selector could not start
  (macOS would not put the selector on screen) — macOS's crosshair
  instead", and you get macOS's crosshair for that press. Paste it if you
  see it; that is the degrade working, and the shot still lands.
  Console: `_G.screenshotsReport()` — the "area :" line. "our selector,
  with the live size readout" is healthy; a "⚠️ … could not start" there
  names the refusal.
  📏 NOTHING ELSE MOVED: ⇪4 still has the live 1280 × 720, still shoots
  with the shutter, still feeds "repeat area". `settings = { screenshots =
  { areaNative = true } }` is still the way back to macOS's crosshair and
  its magnifier if you would rather have those.

- 6.264.0 verify with LL — 📐 ⇪4 CARRIES THE SIZE (KNOWN GROUND): install
  (carries 6.263.0). Press ⇪4. The crosshair you get is OURS now: a dashed
  blue band, and a black box following the drag with the size in white —
  1280 × 720, live, changing as you move. Let go and it shoots that exact
  rectangle, with the shutter sound, onto the clipboard and into the
  folder, exactly as before.
  🔎 THIS IS THE ANSWER TO "I wanted a visual that shows the pixels
  measurements better". 6.260.0 built that readout and put it on ⇪5 and
  the editor's ⌘A — not on ⇪4, which was still macOS's own crosshair.
  Now it is on the key you actually press.
  📏 WHAT YOU GIVE UP, and it is the trade I named in 6.260.0 and you took:
  the native MAGNIFIER (the loupe showing individual pixels) and SPACE to
  capture a whole window instead of dragging. Both belong to
  `screencapture -i` and neither can be rebuilt on our canvas.
  🔌 ONE LINE PUTS IT BACK, no release: `settings = { screenshots =
  { areaNative = true } }`. Say the word if you miss the magnifier more
  than you wanted the numbers — that is a decision, not a bug.
  🎁 A FREE ONE, worth trying: press ⇪4, drag something, then ⇪⇧5 and ⌘5
  ("repeat area"). It re-shoots the SAME rectangle. That never worked
  after a ⇪4 before, because macOS's crosshair cannot tell us where you
  dragged.
  Console: `_G.screenshotsReport()` — a new "area :" line. "our selector,
  with the live size readout · last pressed 21:14" is healthy. If it ever
  reads "⚠️ our selector could not start (…)", paste it: that Mac fell
  back to macOS's crosshair and the line names why. Note the difference
  that line exists for — if YOU set areaNative there is no ⚠️, because
  that is your decision and not a fault.
  🚨 EVERYTHING ELSE ON ⇪4 IS UNCHANGED: Esc still cancels, the file still
  lands in the screenshots folder with its ⇪⇧1 naming, it still goes on
  the clipboard, ⇪5 and the editor's ⌘A still behave exactly as they did.

- 6.263.0 verify with LL — ✏️ macOS STOPS CORRECTING INSIDE OUR WINDOWS
  (KNOWN GROUND): install (carries 6.262.0). THE TEST IS A MISSPELLING:
  open ⇪N (Hamsidian), type `teh recieve seperate` and look at it. NO RED
  SQUIGGLES, and — the part that matters — NO "did you mean" bubble pops
  up over the text. Same in ⇪3's note editor, ⇪T's Title and Description,
  ⇪D's search box, ⇪⇧V's edit window, the screenshot editor's text tool.
  🚨 OUR OWN CORRECTIONS MUST STILL WORK, and that is the check that says
  this took the right thing away: in CHROME (not in our window) type
  `teh ` — it still becomes `the `. This config's autocorrect is a
  keyboard tap and is untouched; what is gone is macOS's second opinion
  inside our own boxes.
  🔎 WHAT THIS WAS, and it is your own crash report that said it: your
  15:58:26 `.ips` ends in `NSCorrectionPanel` — macOS's correction bubble
  threw an exception nobody caught, inside one of our webviews, and
  killed the process. Apple's code; our surface. Every text box we draw
  had asked to be spell-checked, by default, since the day it was
  written, and the vault's note editor asked for it in writing.
  📏 WHAT YOU LOSE, so it is not a surprise in a week: the red squiggle
  under a misspelled word in OUR windows. Nowhere else — Chrome, Mail,
  Word and Asana are untouched.
  📏 AND THERE IS NO SWITCH TO TURN IT BACK ON. That is deliberate and
  it is the one place I have not given you a settings line: the only
  thing it could do is re-arm a panel that aborts Hammerspoon on your OS.
  If you decide you want the squiggle back anyway, say so and it is one
  line — but I will not leave a switch lying there whose sole effect is
  the crash you just sent me.
  🚨 THE OTHER CRASH IS NOT FIXED AND CANNOT BE FROM HERE. Your 15:08:27
  one is AppKit connecting its own menu bar status item, with nothing of
  ours anywhere on the stack. If Hammerspoon vanishes again, send the
  `.ips` — if it ends in `NSStatusItem` that is the same Apple bug and
  the answer is macOS, not this config. You are on a BETA (macOS 27.0,
  26A5388g), and two aborts from inside AppKit in fifty minutes in two
  unrelated subsystems is a fact about that build.

- 6.262.0 verify with LL — 🚨 ⇪⇧U AFTER THE CRASH (KNOWN GROUND for the
  code, and honest about the rest): install (carries 6.261.0). Use ⇪⇧U
  the way you were using it — and the case that matters is a document or
  a tab with NO note linked to it yet, because that is the path that ran
  the crashing shape every single time.
  🔎 WHAT THIS WAS, and why I fixed it before knowing it was yours: the
  module did the exact thing we wrote a rule about after the LAST native
  crash — it started the second grep from inside the first grep's own
  callback, and dropped that running task at the same time. When that
  bites, Hammerspoon dies with no error, nothing in the Console, and no
  beach ball. Your log matched all three.
  🚨 AND IT WAS A SUSPECT, NOT A VERDICT — AND THE VERDICT CAME BACK NO.
  He sent both `.ips` files and neither crash is ⇪⇧U; neither has a
  single line of this config on it. Both are Apple's, on macOS 27 beta:
  the menu bar's status-item scene at 15:08, and macOS's own "did you
  mean" correction bubble inside one of our webviews at 15:58. This
  release is still right and still ships — the two use-after-free shapes
  it fixes were real — but it is NOT the fix for what he saw, its row is
  not scored on it, and the ⇪⇧U step below is a regression test now.
  Console: `_G.anchorsReport()` — a new "tasks :" line. "N callback(s)
  stepped off a held timer before the next task started · slots: none
  held" is healthy. If it ever reads "⚠️ N callback(s) could NOT step off
  a held timer", paste it: that Mac could not arm a timer and is running
  the old shape.
  🚨 IF IT CRASHES ON ⇪⇧U AGAIN, that is a real finding and a valuable
  one — it means the cause is somewhere else and the .ips is the only
  thing that can say where. Nothing else about ⇪⇧U changed: it still
  identifies the tab, the document or the app, still greps the vault for
  notes that already mention it, and still writes plain Markdown.
  📏 NAMED, NOT FIXED, so it is not a surprise later: a vault grep that
  hangs has no time limit (the browser read does — 4 s), and vault.lua's
  own scan has one instance of the same shape. Each is its own release.

- 6.261.0 verify with LL — 🗑 THE DIALOG HOME IS GONE (KNOWN GROUND):
  install (carries 6.260.0). ⇪/ and search `dialog` — NOTHING comes back.
  The 🎯 DIALOG HOME card you photographed is not in the sheet, because the
  tool is not in the config.
  Console: `_G.dialogs()` → "attempt to call a nil value". That error IS the
  release working; an error is the only honest proof that a thing is gone.
  Copy a file over one that exists so Finder asks "Replace?": it opens where
  macOS puts it, exactly as on 6.259.0. Nothing changed there — 6.259.0
  stopped the moving, this one stops the advertising.
  The boot line says 72 modules, not 73.
  📏 ONE THING LEFT ON PURPOSE: the spot you once captured is still in
  hs.settings under "dialogHome.pos". Nothing reads it, and nothing can
  clear it any more, because the code that could is the code I deleted.
  `hs.settings.clear("dialogHome.pos")` in the Console removes it; leaving
  it costs nothing.
  🔑 IT IS DELETED, NOT LOST: every line is in git at 6.260.0 (f16e286) and
  its whole story is in CHANGELOG.md. If you ever want it back it is a
  checkout, not a rewrite — say the word.

- 6.260.0 verify with LL — 📐 THE LIVE SIZE (KNOWN GROUND): install
  (carries 6.259.0). Press ⇪5 and start dragging — or, in the editor, press
  📸 Add capture (⌘A). A black box follows the drag with the size in white:
  1280 × 720, live, changing as you move.
  🚨 ⇪4 IS NOT IT, and I want to say that before you press it and think the
  release did nothing. ⇪4 is macOS's own crosshair (`screencapture -i`), and
  the numbers beside it are macOS's own HUD — Hammerspoon cannot restyle it,
  move it, or read it. Everything that drags on OUR selector gets the new
  readout: ⇪5 scrolling capture, the editor's ⌘A, and "repeat area" the
  first time (⌘5 in the ⇪⇧5 panel, before there is a remembered rectangle).
  🔎 WHAT THIS WAS, because it changes what you can ask for next: there was
  no pixel readout anywhere in this config to restyle. Our selector has
  drawn a dashed band and nothing else since the day it was written, so
  "change the numbers" had nothing to change — it is new drawing.
  📏 THINGS TO TRY, and each is a rule with its own check: drag near the
  BOTTOM of the screen and the box flips ABOVE the selection rather than off
  the edge. Drag the full height of the display and it moves INSIDE, at the
  bottom. Drag at the far left or right and it stays on screen.
  Console: `_G.screenshotsReport()` — a new "size :" line: "240 × 180 ·
  below the selection · last drawn 21:14", and under it the line naming
  where the readout appears and that ⇪4 keeps macOS's HUD.
  🎨 Bigger digits, a different black, no release:
  `settings = { screenshots = { sizeFontSize = 20, sizeAlpha = 0.75 } }`.
  Off: `{ sizeReadout = false }`.
  🔔 If an alert ever says "⚠️ Screenshot size readout — the readout threw
  mid-drag", paste it. That is the guard working: the numbers go quiet and
  your selection still shoots — the readout is never allowed to cost the
  drag it sits on.
  🗳 SAY IF YOU WANT ⇪4 ON OUR SELECTOR TOO. It would give ⇪4 the same
  readout and would cost the native magnifier and SPACE-to-capture-a-window.
  That is your call and its own release — I did not take it for you.
  🖌 AND THE EDITOR'S OWN DRAGS (the Spotlight veil, the oval, the
  highlighter) still have no readout. Same feature, different surface, and
  its own release when you want it.

- 6.259.0 verify — 🎯 THE DIALOG HOME IS OFF: SUPERSEDED BY 6.261.0, which
  deleted the module outright on his word. Nothing to verify separately:
  if 6.261.0's block passes, this one did too (the tool cannot move a
  dialog if the tool is not there). Its steps are in git and in
  CHANGELOG.md 6.259.0.

- 6.258.0 verify with LL — 🖼 TWO SHOTS ON ONE CANVAS (KNOWN GROUND):
  install (carries 6.257.0). Open the editor on any screenshot (⇪⇧1). Beside
  🖥 Full screen there is now 🖼 Load shot — press it, or ⌘O.
  A picker lists the other screenshots in your folder, newest first. Pick
  one: the canvas GROWS and that shot is drawn in the new space, at its own
  size. Two wide shots end up one above the other; a tall one ends up beside.
  🔑 THIS IS NOT ⌘V. Paste image and Add capture drop a picture ON the shot
  at 40% of its width, to point at something. This one makes ROOM, so you can
  put a before and an after in one picture and send one file.
  📏 THE THING TO CHECK, and it is the rule the whole release turns on: draw
  an arrow or a text box on the first shot BEFORE you press ⌘O. After the
  grow it must still be exactly where you put it, on the thing it was
  pointing at. If any mark moves, that is a real break and I want the
  screenshot.
  ↩︎ ⌘Z takes the whole grow back — canvas size and pixels. ⌘⏎ saves both
  shots as one "… (edited).png" and puts it on the clipboard.
  🔎 Console: `_G.screenshotEditorReport()` — two new lines. "canvas :" says
  how big it is and WHO said so ("the page said so" is healthy; "read off the
  file at open" means the page has not spoken and is worth pasting).
  "grow :" counts them, and "↳ last:" names the last one in full.
  Wider gap between the two shots, or a different colour in the new space,
  no release: `settings = { screenshot_editor = { growGap = 24,
  growFill = "#000000" } }`.
  📏 KNOWN AND ACCEPTED: it only offers shots from your screenshots folder —
  not any file anywhere. Say if you want a Finder picker instead; that is its
  own release.

- 6.257.0 verify with LL — 📄 THE DOCUMENTS LIST NAMES THE FILE (KNOWN
  GROUND): install (carries 6.255.0 and 6.256.0). Work in Word for ten
  minutes on a real document, switch to another app, then ⇪⇧W.
  The document is in the list, by its file name, with the time beside it —
  and the "📄 N documents today" line at the top is no longer 0 on a day
  you spent in Word. Excel, PowerPoint, Preview, TextEdit, Pages, Numbers,
  Keynote and Acrobat are the same.
  🔎 WHAT IT WAS, and your own artefact is what named it: ⇪0 typing "Word"
  answered `Microsoft Word — 5m 40s`. Those rows are keyed `app — title`,
  so the app on its own means macOS handed us NO window title for Word —
  and every document name in this tool was read out of that title. The
  time was always being recorded. The name never was. So it is not that
  you misunderstood how it works; it is that this half of it could not
  have worked, in Word, on any Mac.
  Now the row reads `Microsoft Word — Strategies of the Directors.docx`,
  and typing the FILE NAME in ⇪0 finds the time you spent in it.
  📏 KNOWN AND ACCEPTED, so it is not a surprise: this cannot look
  backwards. Rows already in the CSV have no document column and, for
  Word, no title either — nothing recorded which file they were, so
  yesterday's Word time stays a total with no name on it. It fills from
  this install forward.
  Console: `_G.activityDocsReport()` — this tool had no report at all,
  which is why two screenshots had to do the diagnosing. "asked · named a
  file · had no document · could not be asked" are four different things
  and it counts them apart; "rows" says how many document rows the app
  named versus how many were still read out of a title.
  🔔 IF AN ALERT EVER SAYS "⚠️ Activity documents — asking Microsoft Word
  which document was open took N ms", paste it. That is an Accessibility
  read running slow on the main thread, which is the class of thing that
  cost you drag and drop in 6.228.0, and the switch is one line:
  `settings = { activity_tracker = { askDocs = false } }` — the title
  fallback is still there and nothing else changes.
  🚨 AND ⇪⇧E MUST STILL DELETE: pick a Word document in ⇪⇧E and delete it;
  its sessions go, and the row goes with them.

- 6.256.0 verify with LL — 🖥 THE FULL-SCREEN TOOL (KNOWN GROUND): install
  (carries 6.255.0). Open the editor on any shot. Beside ⏲ Delayed 5s there
  is now 🖥 Full screen — press it, or ⌘F.
  The editor blinks out, the whole screen is taken, and it comes straight back
  with that screen on the shot as a movable image. No countdown: this is the
  one for "put this next to that", where ⌘D is the one for a menu you have to
  open first.
  🔎 THE THING TO LOOK AT is the picture itself: the editor must NOT be in it.
  If you can see the editor window inside the capture, that is the settle beat
  being too short on your Mac and it is a number, not a release:
  `settings = { screenshot_editor = { hideSettleSecs = 0.8 } }`. Tell me and
  I will move the default.
  🚨 AND THE 6.255.0 WART IS FIXED IN PASSING: press ⌘D, and while the five
  seconds are counting down press ⇪⇧1 to open the editor on another shot. On
  6.255.0 that left a belt alerting "the delayed capture never answered" over
  an editor you had closed yourself. It says nothing now.
  Console: `_G.screenshotEditorReport()` — the "delayed :" line is called
  "capture :" from this release, because it counts both doors.

- 6.255.0 verify with LL — ⏲ THE DELAYED CAPTURE (KNOWN GROUND): install
  (carries 6.246.0–6.254.0). Open the editor on any shot (⇪⇧1, or ⌥⏎ on a
  history row). There is a new ⏲ Delayed 5s button beside 📸 Add capture —
  press it, or ⌘D.
  The editor DISAPPEARS, you get five seconds to arrange the screen (open a
  menu, hover something, put a dialog up), and then the editor comes back
  with the whole screen on it as a movable image. Drag it, scale it by its
  corner, ⌘Z takes it off.
  🪟 THE WINDOW HIDING IS THE FEATURE, not a glitch: a full-screen shot taken
  with the editor open is a picture of the editor.
  🚨 THE ONE THING TO WATCH FOR is the opposite failure. If the editor ever
  hides and does NOT come back within about eight seconds, that is a real
  break — but it is caught: an alert reads "⚠️ Screenshot editor — the delayed
  capture never answered — the window is back", and the window returns. Paste
  that alert if you see it.
  If the keyboard does not come back with the window, click the editor once
  and say so — that is 6.251.0's price in a new place and it has its own line
  in the report.
  Console: `_G.screenshotEditorReport()` — this tool had no report until now.
  "delayed : 1 asked · 1 landed · 0 failed" is healthy (the line is called
  "capture :" from 6.256.0, which counts ⌘F as well). A "brought back by the
  belt" count is the line that matters; so is "↳ last failure:".
  A different countdown, no release:
  `settings = { screenshot_editor = { delaySecs = 8 } }`.
  Keep the editor on screen through it: `{ hideForDelay = false }`.
  📏 KNOWN AND NOT CHANGED: ⇪⇧3 (the global delayed capture) is still ten
  seconds and still opens a fresh editor — this is the one INSIDE the editor,
  which is what you asked for.

- 6.254.0 verify with LL — 🗑 THE THREE DOORS (KNOWN GROUND): install
  (carries 6.253.0). ⇪N — the 📝 SCRATCH NOTES section still has "+ new tab
  ⌘T" and NOTHING else: the + 🗒 Capture and + ➕ Append rows are gone.
  At 4 PM: no Asana task. Nothing is sent, and nothing is swept — which also
  ends the 📎 Collect tab riding into it every day (6.201.1).
  🔑 NOTHING WAS DELETED, and this is the part to check if you want to be
  sure: ⇪D and ⇪space still find every Capture and Append note you have ever
  written, and any Capture tab already open still closes and files exactly as
  it did. The stores, the modules and the search rows are all untouched — only
  the doors are shut.
  Console: `_G.scratchPadReport()` — "4 PM: OFF", the settings line that puts
  it back, and "+ rows: hidden — the Capture and Append stores are untouched".
  ANY OF THE THREE COMES BACK WITH NO RELEASE:
  `settings = { scratch_pad = { sendDaily = true } }` — the 4 PM task.
  `settings = { scratch_pad = { showKindRows = true } }` — both + rows.
  And `_G.scratchPadSend()` sends one task by hand whenever you want it.
  🔎 SAY IF YOU WANT THEM GONE FOR REAL. This release closes the doors; it
  does not remove capture_pad or note_pad, because deleting a module is how
  notes you forgot you had become unreadable. That is its own release, on your
  word, and it is easier to do after a month of not missing them.

- 6.253.0 verify with LL — ✏️ ONE WINDOW, ONE NAME (KNOWN GROUND): install
  (carries 6.252.0). ⇪N — the header reads 📝 Hamsidian. ⇪3 — the same window,
  the header reads 🕸 Hamsidian. The ICON is the difference now; the name is
  the same on both sides, which is what you asked for.
  Where a LIST has to show both it says "Hamsidian tabs" for the pad: ⌃⌃ (the
  editor picker), ⇪D's source rows, and the panic chord's step list. Two rows
  reading the same word would be a list you cannot use — say if you would
  rather they were identical and I will make them so.
  🚨 NOTHING MOVED BUT THE WORDS. Same key, same window, same store, same
  tabs, same 4 PM task. The COMMANDS keep their old names on purpose, exactly
  as `_G.vaultReport()` did when the notes were renamed in 6.214.0:
  `_G.scratchPadReport()`, `_G.scratchPadSend()`, `_G.scorpPadExport()`.
  Two stale keys were corrected in passing while the rename walked over them:
  the notes' cheat sheet said ⇪3 / ⇪1 and the pad's summary said ⇪1 — both are
  ⇪N now (⇪1 has been mouse-follows since 6.194.0).
  Run the 6.214.0 HAMSIDIAN TEST LIST again if you want the whole surface
  checked; nothing in it should behave differently.

- 6.252.0 verify with LL — ✂️ THE BOX SPLITS BY LETTER (KNOWN GROUND):
  install (carries 6.251.0). ⇪X, type the three letters to land in a cell. The
  yellow box is now drawn SPLIT IN HALF with a letter in each side — the first
  two of the alphabet, and the badge under the pointer names them.
  Press one: that half is kept, the pointer goes to its middle, and it splits
  again. Two or three presses put you on a small button. It splits the LONGER
  side each time, so a wide box splits left/right and a tall one top/bottom.
  ⌥+arrow no longer does anything — that is the removal you asked for.
  ↑↓←→ still nudge, ⇧+arrow is still 1 pt, space still clicks, Esc still ends.
  🚨 THE COST, and it is worth knowing before it surprises you: while the
  landed badge is up, those TWO letters are captured — type one of them
  immediately after landing and it splits the box instead of reaching the app.
  Every OTHER letter still goes straight through, as it always did. Click, or
  press Esc, or wait 8 seconds, and the two letters are yours again.
  Different pair, no release: `settings = { mouse_grid = { halveKeys = "jk" } }`.
  Off entirely: `{ halve = false }` — then no letter is captured at all.
  Console: `_G.mouseGridReport()` — the "split :" line names the two keys, the
  floor, and where the pair came from; the line under it says whether they are
  bound yet (they are claimed on the first landing).

- 6.251.0 verify with LL — ⌨️ THE CARD TAKES THE KEYBOARD (KNOWN GROUND):
  install (carries 6.250.0). ⇪⇧pad. and press SPACE straight away — no click.
  It plays or pauses. ↑↓ walk the queue, ⏎ plays, ⌘3 plays the third, ← → seek.
  Close it and open it again: same thing, first press.
  🔎 WHAT IT WAS: opening the card RAISED the window but never made it key, and
  only a key window is handed the keyboard. The card's key handler was there
  the whole time with nothing routed to it.
  ⚠️ THE PRICE, and it answers your OTHER report: taking the keyboard activates
  Hammerspoon, and macOS brings an app's other windows forward with it — so if
  the Console is open it comes to the front when the card opens. That is the
  same mechanism as "occasionally the Hammerspoon console jumps to the front
  and I'm not sure why". If you would rather have the click back:
  `settings = { music_player = { takeKeyboard = false } }`.
  Console: `_G.musicReport()` — the new "keyboard :" line reads "took the keys
  on try 1 · right now: the card has the keys". If it ever says "gave up after
  4 tries — click the card once", paste it: that Mac will not make the window
  key and the click is still needed.

- 6.250.0 verify with LL — 🔤 SEARCHING FOR A PUNCTUATION KEY (KNOWN
  GROUND): install (carries 6.249.0). ⇪/ to open the sheet, then type a
  BACKSLASH. It lands in the search box and the sheet filters to the ⇪\ rows —
  which is how you find out what ⇪| does without asking me.
  Try the others: ' / ; [ ] - = . , and ⇧ with them (? : { } | _ + < >), and
  ⇧1…⇧0 for ! @ # $ % ^ & * ( ). Backspace still deletes, Esc still clears then
  closes, and every key is handed back to your apps the moment the sheet goes.
  🔎 WHAT IT WAS: the search box only ever claimed a-z, 0-9, space and delete.
  Punctuation was never refused — it was never offered. The FILTER has always
  handled it (it is a plain-text match, not a pattern), so only the input was
  missing.
  ⚠️ IF A SHIFTED ONE DOES NOTHING, that is a layout difference and the Console
  says which: "⌨️ Cheat sheet: N search key(s) could not be bound — …". Paste
  that line. The unshifted keys — the ones every ⇪ combo is written with — do
  not depend on the layout.

- 6.249.0 verify with LL — 🗓 THE CALENDAR HEADER (KNOWN GROUND): install
  (carries 6.248.0). ⇪⇧0. Two things, and they are the two you asked for:
  1. The "September 2026 → November 2026" line is GONE.
  2. ‹ Today › sits where it was — top left — directly above the big date,
     lined up with it exactly.
  The panel is 8 pt shorter again (486 instead of 494), because the header was
  still as tall as the title it used to hold.
  EVERYTHING ELSE IS UNCHANGED and worth ten seconds: click ‹ and › to step a
  month, Today to come back, ←→ ↑↓ [ ] T, click a date to copy it, Esc.
  🔎 Too short now? `settings = { mini_calendar = { height = 700 } }` — a
  number is still obeyed, leaving it out means "fit the content".

- 6.248.0 verify with LL — 🌓 THE GRID GETS OUT OF THE WAY (KNOWN GROUND):
  install (carries 6.247.0). ⇪X. The screen is darker than it was — 55% black
  instead of 30% — and the three letters in each cell read cleanly against it.
  Now press ONE letter: the darkening goes away completely. The screen is back,
  and only the amber boxes that still match are drawn over it. Type the second
  and third letters as usual.
  Backspace all the way out and the darker wash comes back with the full grid,
  which is the case worth a second: it is the same rule read the other way.
  Console: `_G.mouseGridReport()` — the new "scrim :" line reads
  "0.55 before you type — a reading surface · 0.00 once you type (fully
  see-through)".
  🔎 If 0.55 is too dark, or if you want a little wash left after typing, NO
  release: `settings = { mouse_grid = { scrimAlpha = 0.40,
  scrimAlphaTyped = 0.10 } }`. Either number on its own is fine.
  🚨 NOTHING ELSE CHANGED: the letters, the yellow survivors, ⌥+arrow, the
  arrows and the click are all exactly as they were.

- 6.247.0 verify with LL — 🏃 THE ARROW CADENCE (KNOWN GROUND): install
  (carries 6.246.0). ⇪X, type the three letters to land on a cell, then HOLD
  an arrow. It should now run at the same cadence as holding an arrow in a
  text box — before, every repeat was building two windows.
  🔎 WHAT IT WAS: the nudge handler is wired as its own key-repeat handler,
  and it deleted and rebuilt BOTH overlays — the yellow box and the crosshair
  badge — on every repeat. They are moved now; nothing is rebuilt unless
  something other than the position changed.
  Console: `_G.mouseGridReport()` — the new "canvas :" line. After holding an
  arrow for a second it should read something like "40 move(s) · 2
  rebuild(s)". If it ever says "⚠️ every draw was a REBUILD", paste it: that
  means hs.canvas:topLeft is refusing on your Mac and the release did
  nothing.
  🚨 TWO THINGS THAT MUST STILL WORK, and both are deliberate rebuilds:
  ⌥+arrow still halves the box (the size changes, so it redraws), and at the
  very EDGE of a screen the badge still tracks the pointer correctly — the
  crosshair rings move inside the badge there, so that draw is rebuilt on
  purpose. Nudge the pointer into a corner and watch the rings stay on the
  target.
  ⇧+arrow is still 1 pt, a tap is still 8 pt, a held arrow still accelerates.
  Nothing about the distances changed.

- 6.246.0 verify with LL — 🎯 ⇪⇧A ON THE BLUE LINE FILE (KNOWN GROUND):
  install. In Finder select a file — ANY file — and press ⇪⇧A. The title at
  the top of the panel names THAT file. Then Esc, click a DIFFERENT file, and
  press ⇪⇧A again: it names the new one, first press.
  🔎 WHAT IT WAS: the panel was built from the last selection this config had
  read, and it only ever re-read for the NEXT press. So it was one press
  behind, always — your screenshot, where the title said "And now reopen
  document two.docx" over a highlighted .mp4. Pressing ⇪⇧A twice was the only
  way to see the right name, which is why it looked intermittent.
  🚨 THE ONE THING TO WATCH FOR is the opposite failure: the press now WAITS
  for Finder to answer. It should be imperceptible. If ⇪⇧A ever feels like it
  hangs, or if the title ever reads "· could not re-read the selection", that
  is the 1.5-second watchdog biting — paste it, with Console
  `_G.universalActionsReport()`.
  📋 THE REPORT IS NEW (this tool had none): it says how many presses opened
  on a fresh read, how many waited, how many went stale, and — the row that
  matters — whether Finder ever REFUSED a read. A refusal looks exactly like
  "nothing is selected" to everything downstream, so if ⇪⇧A ever says
  "Nothing to act on" with a file clearly selected, that line is the answer
  and it will name it.
  Longer or shorter wait, no release: `settings = { universal_actions =
  { waitSecs = 3 } }`.

- 6.245.0 verify with LL — 🔎 ⇪Y SEARCHES WITHOUT THE BEACHBALL (KNOWN
  GROUND): install. ⇪Y, and TYPE — slowly at first, then normally. The first
  keystroke was the worst one and it is the one to watch: a single letter is
  in nearly every URL you have, and this config used to build a row for all
  60,000 matches and SORT them before drawing forty.
  Then Console: `_G.chromeHistoryReport()` and paste the "search :" and
  "worst :" lines. They say what the last keystroke cost, over how many
  rows, how many matched and how many were kept.
  🔔 If a keystroke ever crosses 150 ms you get an alert naming the
  milliseconds and the row count — that is the door, and the alert IS the
  evidence. Paste it.
  🚨 THE RESULTS MUST NOT HAVE CHANGED. Search something you searched
  before; the same pages in the same order. The gate runs the OLD algorithm
  beside the new one over seven queries and wants them identical, so if you
  ever see a page you expected near the top go missing, that is a real
  finding and I want the query.
  📏 KNOWN AND NOT FIXED: the scan still walks the whole archive on every
  keystroke and still on the main thread — milliseconds, not seconds, now
  that the sort is gone. The report carries the number that would say
  otherwise.

- 6.244.0 verify with LL — 🗓 THE CALENDAR, TIGHTENED (KNOWN GROUND):
  install. ⇪⇧0. Three things to look at, in this order:
  1. The DATE and the CLOCK are now ABOVE the three months, same 34 pt as
     before, in a box that is the height of the two lines in it.
  2. The big empty space below the dates is GONE. The panel is about 494 pt
     tall instead of 768 — the height is worked out from what is in it now
     rather than being a number typed in once.
  3. The key-hint line sits right under the last row of dates, not at the
     bottom of the window.
  It wears the music player's card: #15161a with a lighter header strip
  across the top, and the ‹ Today › buttons in the player's style.
  EVERYTHING ELSE MUST STILL WORK, and it is worth thirty seconds: ←→ a day,
  ↑↓ a week, [ ] a month, T back to today, click a date to copy it, C, R for
  the Date report, Esc. Then ⇪⇧P with it open — the pomodoro still docks
  against its left edge and goes back when you close it.
  🔎 If it is now too SHORT for your eye, no release:
  `settings = { mini_calendar = { height = 700 } }` — a number is still
  obeyed; leaving it out means "fit the content".
  🎨 NAMED, NOT FIXED: the calendar is now the second panel wearing the
  music player's look while nine others still wear the shared ui_style one.
  Folding them together restyles eleven panels at once, so it is its own
  release when you want it.

- 6.243.0 verify with LL — 🔤 ⇪Z LEARNS YOUR OWN CORRECTION (KNOWN
  GROUND): install. In Chrome, type `makee`, backspace over it, type `make`,
  then a space. NOTHING happens — that is the design, you chose ARM.
  Now press ⇪Z. It says `makee → make is a fix row now`. Type `makee ` again
  anywhere: it corrects, at once, no reload. It reaches the other Mac once
  OneDrive syncs and it reloads.
  ⏱ You have 30 seconds after the retype. Past that ⇪Z says so and tells you
  to retype it — it never silently does nothing.
  🚨 THE TWO THINGS THAT MUST NOT HAPPEN, one test each:
  1. Type `cat`, backspace, type `dog`, space, ⇪Z → it must REFUSE and say
     the pair was more than one edit apart. That is an ordinary edit, not a
     typo, and a row for it would rewrite the word for ever, on both Macs.
  2. Let the config correct something itself (type `teh `), then press ⇪Z →
     it must UNDO ours, exactly as it always did. Ours wins when there is
     one, and this config must never learn from its own retype.
  ↩️ THE WAY BACK, which is the half 6.199.0 made a rule: Console
  `_G.autocorrectReport()` — a new "⇪Z taught" block lists every row a
  keypress wrote, with its line number and the exact
  `_G.autocorrectForgetFix("makee")` that removes it. Run that and `makee `
  stops being corrected.
  🔎 If ⇪Z ever seems to do nothing, run the report: the "self-fix :" line
  says whether a pair is armed right now, or names the last word you
  retyped and why it was not offered.
  Off, no release: `settings = { autocorrect = { selfLearn = false } }`.
  Want it to say "⇪Z learns makee → make" as you type? `selfAlert = true` —
  off by default, because you correct typos all day and a tool that talks
  every time is a tool you switch off.

- 6.242.0 verify with LL — 🧭 THE GROUND PROBE (KNOWN GROUND — it only
  READS): install. Console: `_G.groundReport()` — PASTE THE WHOLE THING.
  It changes nothing. It binds no key, writes no file and leaves no tap
  running; it exists so the next four releases are aimed instead of guessed.
  🟥 THEN RUN IT THREE MORE TIMES, and this is the part only you can do:
  click the caret INTO a Chrome text box and run it · into an Asana task
  field and run it · into Mail and run it. Paste all three. The "bounds :"
  line is the one that matters — "AXBoundsForRange ANSWERED" means a pink
  underline can be drawn under a doubled word IN THAT APP; "⚠️ no rectangle"
  means it cannot, and there the feature is the alert. The answer is per
  app, which is why one run does not answer it.
  🖱 The "clicks :" line says how many elements the front window has and how
  many are clickable — that is how many click hints ⇪X would draw, and what
  asking cost. If it says it stopped at a bound, paste that: the number is a
  floor, not a total.
  ⌘space: it should read "Spotlight STILL HAS IT" today. Turn Spotlight's
  shortcut off (System Settings › Keyboard › Keyboard Shortcuts › Spotlight),
  run it again, and it must read FREE. That is the gate on the ⌘Space
  launcher — I will not bind it until this line says FREE on both Macs.
  WORK MAC TOO: the same report. "access", "secure" and "⌘⌘ / ⌥⌥" are the
  rows most likely to differ there, and they decide three features.

- 6.241.0 verify with LL — 🎯 IT WAS WAKING ITSELF (KNOWN GROUND):
  install. FIRST, Console: `_G.fileTrackerReport()`.
  The "watching :" list must now name folders INSIDE OneDrive —
  `…/OneDrive-Personal/<your folders>` — and `…/OneDrive-Personal/Logs` must
  NOT be one of them, nor `…/OneDrive-Personal` itself. A new "cloud :" line
  reads "by its N folder(s), not whole", and "not here : Logs" names what
  stopped waking it. The "csv :" line now ends "so the write no longer wakes
  this module".
  THEN THE MEASUREMENT, and it is the same one as 6.229.0: use the Mac for a
  few hours and run it again. Compare "events" — 6.228.0's day was 60,115
  wake-up(s) · 204,662 path(s) · 49 row(s). Every store this config writes
  lives in that Logs folder, so its own writes were part of that number.
  AND THE FEATURE MUST STILL WORK: move a file in Finder, then ⌃⌥⇧F.
  🔎 IF THE CLOUD LINE SAYS "the WHOLE folder", paste it — it names which of
  three reasons (could not list it · nothing inside it · more than 40 folders
  in it), and the fix is different for each.
  📏 KNOWN AND NOT FIXED, so it is not a surprise: the nightly backup and the
  30-minute store mirror write into <OneDrive>/Backups/Hammerspoon/, which is
  still watched and still discarded in Lua. And the CSV write is still
  synchronous on the main thread — 49 writes a day was never the cost.

- 6.240.0 verify with LL — 💡 THE HINT CARD IS OFF (KNOWN GROUND):
  install. Press any ⇪ key you use often — ⇪T, ⇪V, ⇪D. NO card appears in
  the top-right corner. Everything the key itself does is unchanged.
  Console: `_G.shortcutHintsReport()` — "enabled  : false". If a card still
  appears, paste that line; it is the whole switch.
  🔎 NOTHING IS LEFT RUNNING: with it off no canvas is built, no dismiss tap
  is created and no timer is held — the card is never made, not made and
  hidden.
  Back on, no release and no reload beyond the usual: `shortcut_hints =
  { enabled = true, scale = 1.5 }` in the Air's profile (the 1.5 is your
  own LG measurement and is kept there while the card is off, deliberately).

- 6.239.0 verify with LL — ⏪ SEEK (KNOWN GROUND): install (carries
  6.238.0). Play a track. → jumps forward 5 seconds, ← back 5, and the time
  and the bar move with it. ⇧→ and ⇧← jump 30. ↑↓ still walk the list —
  they live one line apart in the same handler.
  → held at the end parks at the end and the next track starts, which is
  the same as letting it finish. ← at the start says "already at the start"
  rather than doing nothing.
  Console: `_G.musicReport()` — "seek : ←→ 5 s · ⇧←→ 30 s · N this session".
  Both numbers are settings, no release:
  `settings = { music_player = { seekStep = 10, seekBigStep = 60 } }`.
  🔎 If a track ever seeks and then jumps BACK a second later, paste the
  line — that is the fallback clock, and it has its own check.

- 6.238.0 verify with LL — 🪟 THE CARD REOPENS ON WHAT IS PLAYING (KNOWN
  GROUND): install. Play a track, ⇪⇧pad. to close the card, ⇪⇧pad. to open
  it again — the track, the queue and the history are all there the FIRST
  time, not the second.
  🔎 WHAT IT WAS, and your photograph diagnosed it: the card said QUEUE
  EMPTY while the progress bar was nearly FULL. Opening the window hands
  the page to WebKit and returns before WebKit has read it, so the draw
  sent on the next line went nowhere — while the clock, pushed half a
  second later, landed. The page says when it is ready now and the card is
  drawn then.
  Console: `_G.musicReport()` — a new "page :" line. "N draw(s) landed
  since the page said it was ready" is healthy. If it ever reads "⚠️ the
  page has NOT said it is ready", paste it: the bridge is down and that is
  a different bug.

- 6.237.0 verify with LL — 🆔 THE DROP, AND YOUR OWN CARD NAMED IT:
  install. ⇪⇧pad. Drag the same mp3s onto the card. They play.
  🔎 WHAT IT WAS: your card said "⚠️ .15194583 is not an audio file this can
  play" — and that was this config reading an INODE as a file type. Finder
  does not hand over a path; it hands over
  `file:///.file/id=6571367.15194583`, which names a file by volume and
  inode and carries no name and no extension at all. Two of your shots, two
  different numbers — that is what named it.
  Console: `_G.musicReport()` — under "drop :" a new line reads "N file
  reference(s) turned back into files, 0 could not be". If any say "could
  not be", paste it: that Mac refused the bookmark and the report says so.
  A file called "50%25 off.mp3" — a real % in the name — must also land now.
  🚨 NOTHING ELSE CHANGED in this release, deliberately.

- 6.236.0 verify with LL — 🖥 THE RIGHT MONITOR: install (carries
  6.235.0). Work in an app on one monitor, then press ⇪/. The sheet opens
  on THAT monitor. Do it again from the other one. Then the case that was
  actually broken: click into an app that has no focused window (or one
  whose other windows live on the other display) and press ⇪/ — it now
  follows your POINTER rather than that app's main window.
  Console: `_G.screenReport()` — it names the rule that placed the last
  panel ("the focused window's screen" / "the screen the pointer is on"),
  the front app, and what each candidate would answer right now. If a
  panel still opens on the wrong monitor, paste that: it says which rule
  chose and what it chose, which neither of your two reports could.
  🚨 THIS CHANGES EVERY PANEL, not just the cheat sheet — ⇪D, ⇪space, the
  pickers, the pomodoro, all of them place through the same rule. That is
  deliberate; say if any of them now opens somewhere you did not expect.

- 6.235.0 verify with LL — 🔒 THE DROP, SECOND TRY: install (carries
  6.234.0). Drag files onto the card exactly as before. The blue is
  already proof the card SEES the drag; what changed is everything after
  it. If the tracks land, that is the whole test.
  🔎 IF IT STILL DOES NOT, one line answers it — Console:
  `_G.musicReport()`, and paste the two "drop :" lines. When no reader can
  read the drag they now NAME WHAT IT WAS CARRYING ("nothing readable —
  the drag carried: public.tiff, …"), and that list is the cause. There is
  no third guess after that.
  WHAT THIS WAS: a `table.concat` over a list of objects, which raises,
  inside a dragging callback — where a raise is a silence. The card lit up
  and the handler died on the next line.

- 6.234.0 verify with LL — 🕘 THIRTY DAYS, ONE ROW PER FILE: install
  (carries 6.233.0). Play a track, then play it AGAIN, then play a second
  one and come back to the first. The 🕘 history at the bottom of the card
  must show TWO rows, not four — each file once, most recent at the top.
  Console: `_G.musicReport()` — the "history :" line now reads "N track(s)
  over the last 30 day(s) — one row per file, oldest <date>".
  It keeps a month now rather than the last 60 plays, and the card shows
  40 of them instead of 12. Nothing you have already is lost — old rows
  simply age out at 30 days from when they played.
  `settings = { music_player = { historyDays = 90 } }` if a month is short.

- 6.233.0 verify with LL — 🚚 THE DROP, WHICH NEVER WORKED: install
  (carries 6.232.0). ⇪⇧pad. Open Finder on a music folder, select five or
  six mp3/m4a files and DRAG THEM ONTO THE CARD. As the pointer crosses it
  the card goes blue and says "drop to add"; let go and the first track
  plays with the rest queued under it. That blue veil is the tell — it
  means the window is seeing the drag at all, which it never did before.
  Console: `_G.musicReport()` — the new "drop :" line must read "catcher up"
  and the line under it names how many files and WHICH reader macOS
  answered on ("read by readURL"). If a drop still does nothing, paste
  those two lines: "⚠️" there names which of the four ways it failed.
  Then move the card (drag its title strip) and drop onto it at the new
  spot — the catcher follows the window, and this is the thing most likely
  to be wrong if the first drop works and a later one does not.
  🚨 WHAT THIS WAS: hs.webview cannot accept a dragged file at all — the
  drag passed straight through to whatever was behind, which is exactly
  what you saw. hs.canvas can, so there is now an invisible canvas at the
  card's frame, underneath it, catching only what the card refuses.
  6.231.0 is scored a LOSS: the feature you were asked to test could not
  have worked on any Mac.

- 6.232.0 verify with LL — 🪟 THE CARD MOVES: install (carries 6.231.1).
  ⇪⇧pad. Then press on the card's TITLE STRIP — the top part, where the
  track name and the time are — and drag. No ⌘. The card follows. Let go,
  press ⇪⇧pad. twice: it reopens where you put it, not back in the corner.
  Then ⌘-drag from anywhere on it, including over the track list — same
  thing. A bare press on a ROW must still play that track, not move the
  window; that is the line between the two grips.
  Console: `_G.musicReport()` — the new "window :" line reads
  "at 120,240 · moved". Drag it mostly off the bottom of the screen and
  reopen: it comes back on screen and the line says "nudged back onto the
  screen". If you move it onto a second monitor and later unplug that
  monitor, it opens in the corner and the line says why.
  🖱 THE DESKTOP JUMP, and I am guessing — nothing in this config can
  change a Space, and I wrote no code for it. Check System Settings ›
  Accessibility › Pointer Control › Trackpad Options: if "Use trackpad for
  dragging" with "Three finger drag" is ON, then three fingers on
  something that will not be dragged falls through to macOS's own
  swipe-between-Spaces. That would be exactly what you saw, and making the
  card draggable would fix it by giving the gesture something to land on.
  Tell me whether that setting is on — it decides whether there is a
  second bug here or not.

- 6.231.1 verify with LL — 🔤 A NAME WITH AN & OR A < IN IT: install
  (carries 6.231.0, so run THAT block first — it is the whole feature).
  Then the one thing this release changed that you can see: take a track
  whose file name has an "&" in it (Simon & Garfunkel, AC/DC, anything
  with an ampersand) and drop it on the card. The name in the list must
  read exactly as the file does. On 6.231.0 an "&" could swallow the rest
  of the word and a "<" swallowed everything after it.
  🚨 NOTHING ELSE CHANGED. No key, no behaviour, no new switch. The rest
  of this release is the gate: the card's page is executed by the test
  suite now, 55 checks over the drop, the arrows, ⏎, space, ⌫, ⌘1–9 and
  the buttons, where before only the Lua half was tested.
  If a name is still wrong in the list, paste the FILE NAME exactly as
  Finder shows it — the character is the evidence.

- 6.231.0 verify with LL — 🎵 THE MUSIC PLAYER: install (carries 6.230.0).
  Press ⇪⇧pad. (the numpad's decimal point). A small dark card appears in
  the TOP-RIGHT corner. Press it again — it closes.
  THE DROP, which is the whole feature: open Finder on a music folder,
  select five or six mp3/m4a files, and DRAG THEM ONTO THE CARD. The
  first one starts playing, the rest are listed under it, and the elapsed
  time counts up with a blue line under the title.
  THEN: ↑↓ moves the highlight · ⏎ plays it · ⌘3 plays the third ·
  space pauses and resumes · ⌫ takes a track out · ⏭ and ⏮ step · the
  ➜ button cycles repeat off → all → one. Let a track run to its END
  with repeat off: the next one must start by itself. That is the one
  thing only a real Mac can prove.
  🕘 HISTORY: at the bottom of the card, everything played this session.
  Click one and it plays again.
  🚨 KNOWN AND ON YOUR OWN WORD: NO volume and NO seek — you said the
  native volume keys work, so the player has none. Say if you want them;
  that is its own release. .flac and .ogg will NOT play (macOS's own
  audio cannot), and each such file is named in the card with the reason
  rather than disappearing.
  Console: `_G.musicReport()` — the queue, what is playing, the history
  count, and the "advances" line. If that line ever reads "0 by callback"
  while "by the belt" climbs, macOS is not telling us when a track ends
  and the fallback is carrying the playlist: paste it, it is the evidence.
  If a drop does nothing and the card says "macOS did not hand over the
  path", paste that line — it means the drag arrived without file URLs.
  `settings = { music_player = { enabled = false } }` turns it off.

- 6.230.0 verify with LL — 🔗 ONE TREE, ONE WATCHER: install (carries
  6.229.0). Console: `_G.fileTrackerReport()`. The "watching :" line must
  now read TEN folders, not eleven, and `/Users/leeleblanc/OneDrive` must
  NOT be one of them — `/Users/leeleblanc/Library/CloudStorage/
  OneDrive-Personal` is, and it is the same folder. A new "linked :" line
  names the one that was dropped and says why ("a link, not a second
  tree"). If ~/OneDrive is still listed as watched, paste the line.
  THEN THE MEASUREMENT THAT WAS ALWAYS THE TEST, now that it is not being
  double-counted: use the Mac for a few hours and run it again. Compare
  "events" against 6.228.0's day — 60,115 wake-up(s) · 204,662 path(s) ·
  49 row(s) — and expect the wake-ups to be a small fraction with the ROW
  count about the same. The "yield :" line says it in one number, and now
  says "NO rows kept yet" instead of dividing by a row that is not there.
  AND THE FEATURE MUST STILL WORK: move a file in Finder, then ⌃⌥⇧F.
  🖱 If drag and drop is still slow, same report, same number to compare.
  📏 KNOWN AND NOT FIXED HERE: the CSV is still written synchronously into
  OneDrive, and OneDrive is a folder this module watches, so its own
  writes still wake it. Named so it is not a surprise; its own release.

- 6.228.0 verify with LL — 🕵️ THE FILE TRACKER, MEASURED: install
  (carries 6.227.0). FIRST, because it is why this release exists: move
  six or seven large files in Finder, the way you did with the TV
  episodes — drag them from one folder to another. Then Console:
  `_G.fileTrackerReport()` — PASTE THE WHOLE THING. Read it in this
  order: "wake-ups" and "writes" each have a WORST number; whichever is
  larger is the half to fix, and that is 6.229.0. "⚠️ SLOW" counts what
  crossed 120 ms; if it is 0 while the drag still fails, this module is
  not the cost and the report says so honestly. If an alert fires
  mid-drag — "⚠️ File tracker — a CSV write took N ms …" — that is the
  🔔 door working, and the alert itself is the evidence.
  THE OFF SWITCH, and it survives a reload now (the Console line did
  not): `settings = { file_tracker = { enabled = false } }` in the
  machine profile. Then `_G.fileTrackerReport()` must read "OFF —
  settings = …" and "macOS has not woken this module once". Nothing
  else changes: ⌃⌥⇧F still opens the history, the CSV is untouched,
  the 90 days are all still there — only NEW rows stop.
  Right this second, with no reload: `_G.fileTracker.stopWatching()`,
  and `_G.fileTracker.startWatching()` puts it back.
  🚨 KNOWN AND NOT FIXED IN THIS RELEASE: it still watches your whole
  home folder and still writes into OneDrive on the main thread. This
  release exists so the next one is aimed rather than guessed.
- 6.227.0 verify with LL — 🔖 ⇪⇧V KEEPS ITS PLACE: install. THE
  SCENARIO HE ASKED FOR, and it only fails after an ACTION:
  1. Copy six things: "alpha one" … "alpha six". Then "beta one",
     "beta two", "beta three".
  2. ⇪⇧V. Type `beta` — three rows.
  3. ↓ ↓ to the SECOND beta row.
  4. ⏎ on the "☑️ Select mode" row at the top.
  BEFORE 6.227.0: the search box empties, all nine rows come back, and
  the highlight is gone until you press an arrow. NOW: `beta` is still
  typed, three rows, and the highlight is still on the second one.
  5. ⏎ tags a row — same thing: the place is kept.
  6. Home → the first row. End → the last row. Both, in the picker.
  7. Esc, then press Home in Chrome — it must still go to the top of the
     page. The binding lives only while the picker is up.
  Console: `_G.clipboardReport()` — "home/end :" says bound, "place :"
  names the row it last landed on. If Home/End do nothing, paste that
  line; `settings = { clipboard_history = { jumpKeysOn = false } }` is
  the off switch.
- 6.226.0 verify with LL — 🔤 THE JUNK FILTER: install. Take a
  screenshot of a page with bullets and rules in it (⇪⇧4 or ⇪4), then
  ⇪O and look at the newest reading: the single letters and the
  bullets are gone, every word of two characters or more is exactly as
  it was. Console: `_G.ocrReport()` — the new "junk :" line counts
  what was dropped. THEN the log you already have, in two steps:
  `_G.ocrCleanHistory()` — it changes NOTHING and tells you how many
  rows hold junk and how many would be removed entirely. If the
  numbers look right, `_G.ocrCleanHistory(true)` does it. Check ⇪O
  afterwards: the image thumbnails and paths must still be there. If a
  reading you wanted is gone, `settings = { ocr_engine = { junkFilter
  = false } }` turns it off with no release.
- 6.225.0 verify with LL — 🎯 THE CARET: install. ⇪⇧V, ⏎ on a row —
  the window comes to the front AND the caret is already blinking in
  the box, at the END of the text. Type at once, no click. ⌘⏎ saves.
  Same for ⇪⇧O. Console: `_G.ocrReport()` — the new "edit box :" line
  must read "caret placed on try 1". If it reads "gave up after 4
  tries", that Mac will not make the window key and a click is still
  needed — paste the line, it names the state.
- 6.224.0 verify with LL — 📋 THE CLIPBOARD REPORT (the instrument, not
  a fix): install. Copy three distinct strings from three different
  apps. Console: `_G.clipboardReport()` — PASTE THE WHOLE THING. Read
  it in this order: "newest" must be the third string, "filed" must say
  3, "refused" says what was turned away and why, "saves" must say
  0 FAILED, and the "poll" line says how many pasteboard changes in how
  many minutes and how many were SUPPRESSED by a borrowed clipboard. If
  filed is 3 and ⇪V still does not show them, the store is fine and the
  PICKER is the bug — a different release. If filed is 0 while the poll
  counted changes, the copies never reached this module. If suppressed
  is high, the 6.69.0 borrow guard is eating them. Each of those is its
  own next release and the report says which.
- 6.223.0 verify with LL — ⇪T DRAWN WHOLE: install. ⇪T — the form is
  taller and the project fields are all on screen with NO scrolling;
  the blue Create task button is still at the bottom. Console:
  `_G.taskFormReport()` — "window : 820 × NNN pt". If it is now too
  tall: `settings = { task_form = { maxHeight = 900 } }`, no release.
- 6.222.0 verify with LL — THE STUCK OVERLAY: install. ⇪⇧1, press S
  (Spotlight), start dragging a box and let go of the mouse OUTSIDE the
  editor window (over another app, or off the screen edge). The veil
  must STOP where you released — it must not follow the pointer, and
  moving the mouse afterwards must not resize it. ⌘Z takes it back.
  Then a tiny drag released outside: nothing is left behind at all.
  That was the "entire image looks selected by some overlay" — the drag
  never ended because the mouseup happened where the page cannot hear.
- 6.221.0 verify with LL — ⌘ EDITS A MARK: install (carries 6.220.0).
  ⇪⇧1 on any shot. Text tool, click, type a word, ⏎. Now press A (the
  Arrow tool) and HOLD ⌘ and click that text box — its words open,
  pre-filled, with the Arrow tool still armed; change them, ⏎. Then
  hold ⌘ and click EMPTY canvas with the Arrow tool armed: nothing is
  created (that is the fix — before, it drew an arrow). Then hold ⌘
  and click an arrow: it is selected, ⌫ deletes it. A bare click still
  draws, as ever. And the window still moves: drag its 🖌 Edit title
  bar, or ⌘-drag that same strip — ⌘-drag on the picture itself no
  longer moves the window, deliberately, because ⌘ down there is now
  his edit key.
- 6.220.0 verify with LL — ⇪T FITS: install (carries 6.219.0). ⇪T —
  the window is wider (820) and no taller than 760 pt, and the blue
  "Create task ⏎" button is visible at the BOTTOM from the first
  second and stays there while the middle of the form scrolls. The
  project fields are TWO TO A ROW with their names above them; SAC
  Values still runs the full width. Everything still works: pick a
  Priority, tick two SAC Values, type a Title, ⏎ — the task is created
  with those values; Esc still keeps the draft. Console:
  `_G.taskFormReport()` — "window : 820 × NNN pt · 2 column(s)". If it
  is still too tall or now too small, NO release: `settings =
  { task_form = { maxHeight = 640, wideWidth = 900 } }`.
- 6.217.0 verify with LL — THE TRIM + THE LIST: install (carries
  6.216.0). Boot line reads 6.217.0, All green, 71 modules; every ⇪
  key works as before (nothing but comments changed). At the zip root:
  RESOLVED-FEATURE-REQUESTS.txt — open it in TextEdit/CotEditor; the
  first line names 6.217.0; ⌘F "Bluetooth" finds the ⇪⇧7 rows; the
  RELEASE INDEX at the bottom lists 6.217.0 first.
- 6.216.0 verify with LL — 📶 BLUETOOTH: install (carries 6.215.0).
  HOME MAC: ⇪⇧7 → a picker of every paired device, 🟢/⚪. If the
  first press alerts "⚠️ Bluetooth — blueutil not installed (brew
  install blueutil)…", the engine is missing: ⏎ on the top row
  copies the install, run it in Terminal, press ⇪⇧7 again — no
  reload needed. With blueutil: ⏎ on the AirPods row → "📶
  Connecting AirPods Pro…" then "📶 Connected — AirPods Pro" and
  the Mac's sound output moves; ⇪⇧7, ⏎ on the same row →
  "Disconnected". A failure alerts the exit code and blueutil's
  words — paste it. `_G.bluetoothReport()`: engine path, the
  devices, "last : connect AirPods Pro at HH:MM:SS — ok". WORK MAC
  (no brew): the same ⇪⇧7 lists the devices via system_profiler, ⏎
  opens System Settings › Bluetooth, the ⚠️ alert names the missing
  engine once — that is the degrade working, say so. Also still
  owed there: `_G.stormReport()` with no ⚠️ line.

(Pruned 6.213.1: verify blocks for 6.203.0 and earlier moved to
CLAUDE-archive.md at the repo root, which is NOT auto-loaded — this
file rides into every context window. A block comes back here only if
LL reopens it.)

- ✅ FROZEN GRID BOX — NAMED AND FIXED AS 6.266.0 (2026-09-12, LL:
  "Frozen grid again." with a screenshot of the yellow landed-box
  outline over a Finder replace dialog, then "disregard"). The 6.215.0
  reading was RIGHT and sat here for eight releases because nobody put
  `_G.showCanvasSafely`'s blind retry and `hideAllShown()`'s emptying of
  `grid.shown` side by side. The durable rule is above. The original
  reading, kept because the method is the lesson: it was written from
  the source alone, on a symptom he told me to disregard, and it named
  the mechanism exactly — including that `_G.mouseGrid.hide()` could not
  clear such a box and `hs.reload()` could.
- 6.215.0 verify with LL — THE DEGRADE DOOR: install (carries
  6.214.2). Boot: no new alert on a healthy Mac (the door is silent
  until something degrades). Console: `_G.degradeReport()` reads
  "🔔 DEGRADED — 0 time(s) across 0 tool(s)… nothing has degraded this
  session". Then make one on purpose, one line: `_G.degrade("Test
  tool", "this is the door")` → an on-screen "⚠️ Test tool — this is
  the door" AT ONCE, a "⚠️ Test tool: this is the door" Console line,
  and `_G.degradeReport()` now lists "Test tool ×1". Run the same
  line five more times: the count reads ×6, the alert showed ONCE
  (the same cause is gated 10 min). `_G.noticesReport()` lists the
  row as kind "degrade". On the WORK MAC the same, plus
  `_G.stormReport()` with no ⚠️ line — the report still owed from
  6.214.2. If the alert ever fires during real use, that is a module
  naming a real break: paste the Console line, it is the evidence.
- 6.214.2 verify with LL: Air, 17:35 report — NO ⚠️ line (the stale
  cannot-list line is gone) and ✅ THE MEASUREMENT IS ANSWERED: "184
  Caps Lock autorepeat(s)" — a remapped Caps Lock DOES autorepeat on
  his Mac, so the repeatfn fires, the autorepeat clause is live, a
  real hold has its own distinguishing fact, and init.lua's "a real
  hold keeps stamping (F18 autorepeats)" comment is TRUE — nothing to
  correct. SCORED on the home Mac ("6.214.2 home ✓"). Still owed:
  the WORK MAC — install, `_G.stormReport()` must show no ⚠️ and
  "no report on disk"; his ✓ there opens the gate for 6.215.0.
- 6.214.1 verify with LL — THE STORM GUARD, and his gate for
  everything after it: install over 6.213.3 (it carries 6.213.4,
  6.213.5 and 6.214.0 too). Boot: `_G.stormReport()` reads "watching:
  5 s held · 6 different shortcuts …", "no storm this session", "no
  report on disk". Normal use for a day on each Mac: NO storm alert
  while he uses ⇪ as ever (a held ⇪+arrow is one key; a real hold
  autorepeats). If the keyboard storms again: within ~5 s of typing
  an alert "🌩 ⇪ STORM CAUGHT — Caps Lock was stuck N s and N
  different keys ran ⇪ shortcuts. Released — the next key types.
  Report: …/.storm/storm-<epoch>.txt" — SEND THAT FILE; its `asked :`
  and `keys :` lines are the evidence the diff could not give. To
  see it fire on purpose, in the Console (ONE line, no real shortcut
  runs): `_G.hyperActive = true; _G.hyperEnteredAt =
  hs.timer.secondsSinceEpoch() - 6; for _, k in ipairs({"|a","|b",
  "|c","|d","|e","|f"}) do _G.hyperStormNote(k, "test") end` — it
  must release, alert and write the file; a second run within 10 min
  must also pause, and ⇪⇧Esc must resume. 🚨 THE FIRST RECIPE WAS
  WRONG AND COST HIM A STUCK GRID: "set the two globals, then type six
  letters" faked HALF a hold — no modal entered, no watchdog armed —
  so on his Mac (tap dispatch engaged) the first letter, x, opened the
  mouse grid, whose own modal ate the rest; the count stopped at one
  and `_G.hyperActive` stayed true with nothing to clear it. Clean-up:
  `_G.mouseGrid.hide("stuck"); _G.hyperForceRelease("Console")` (or a
  Caps Lock press). LESSON FOR THE GUARD, not yet built: a stray
  letter that opens a key-eating tool (grid, a picker) stalls the
  distinct-key count — a time-only rule needs the autorepeat fact
  first. MEASURED (6.214.2 report, 184 autorepeats): a remapped Caps
  Lock autorepeats, so the repeat-based half of the rule is live on
  his Air. If the storm alert appears during REAL ⇪ use,
  that is a false positive: paste the file, and `settings =
  { hyper_storm = { keys = 8 } }` widens it, no release.
- 📥 LL'S NEW ASKS (2026-09-12, with the 6.214.0 report) — logged,
  NOT built; nothing ships until 6.214.1 is scored on both Macs; then
  the agreed order resumes with the 🔔 door and click hints, and
  these join the queue in HIS order when he says — HE SAID (2026-09-13,
  see 🧭 THE SEQUENCE above; (d) shipped as 6.216.0): (a) ⌥Tab: the
  Hammerspoon Console window back in the switcher ("that was
  awesome"); (b) 💾 a translucent floppy-disc beside a text field in
  Chrome/Safari that has no save, "watching" the typing (a draft
  keeper — scope: which fields, where the draft goes, how it is
  recovered); (c) init.lua: drop version-note comments older than
  6.15x that are not durable rules; (d) 📶 Bluetooth: connect/
  disconnect AirPods or any device, reliably (blueutil is a brew
  binary — the work Mac may not have it; degrade); (e) ⌘Space: he
  will take it from Alfred/Spotlight for the ⇪space launcher (apps +
  recent files + search) — a plain hs.hotkey, not a hyper key;
  (f) a PUBLIC init.lua/config: 100% sanitised (name, paths, Mac
  names, emails, IDs, tokens, OneDrive paths) — the GitHub audit
  item, now first-class; (g) 📋 an image just copied is the FIRST
  paste candidate in the clipboard history, text moved back one —
  check what clipboard_history does with images today before
  promising (images go to the OCR engine, 6.190.0's note).
- 🗳 LL'S ANSWERS TO THE 14 QUESTIONS (2026-09-12), as read — items
  8–14 were numbered 1–6 under "Work Mac:" and are read in order:
  1 click hints on ⇪X first, grid as the fallback — default; 2 Chrome
  and Finder — default; 3 the order — default (Hamsidian 6.214.0 —
  a LOSS, the storm guard 6.214.1 sits in front of everything now —
  then the 🔔 door 6.215.0 on his new rule, then click hints, OCR
  gibberish, the 4 PM review, bookmarks, GitHub audit + public repo,
  website, Claude door); 4 rename visible strings only — default;
  5 OCR gibberish → date + app + screenshot name, gibberish dropped —
  default; 6 the 4 PM review — "Make" (build it as described);
  7 work-Mac reach — "Skip": assume it has NOTHING (every path
  degrades and says so); 8 bookmarks — Yes: a per-Mac CSV searched
  from ⇪D; 9 dictionary sync — "Sync to GitHub instead" (item 6 of
  his list; the only place it fits — not OneDrive); 10 Anthropic API
  key — Yes; 11 Claude door output — Yes, the default; 12 work
  writing in public — "Skip": the site is PERSONAL ONLY until he says
  otherwise; 13 website — default, Jekyll on GitHub Pages; 14 audit
  strings — "I will after you build": scan with what is known, he
  sends the rest later. If any of 8–14 was meant differently he
  corrects the one line; nothing built before item 5 depends on them.
- 6.214.0 verify with LL — THE HAMSIDIAN TEST LIST (his ask: a list
  to run every function; nothing but the name changed, so any row that
  fails is an OLD bug and is reported as one):
  1 ⇪3: the window opens on your last note; its header reads
  🕸 Hamsidian; ⇪3 again closes it. 2 ⇪N: the same window on your
  scratch tabs, header 📝 Scorp Pad. 3 ⇪/: the section reads
  🕸 HAMSIDIAN (⇪3 / ⇪1 …). 4 Console `_G.vaultReport()`: first line
  "🕸 Hamsidian — ⇪3". 5 ⌘N, a name, ⏎: the note exists and opens.
  6 type [[ and pick a note; ⌘⏎ on the link opens it; on a name with
  no file it creates it. 7 ⌘D: today's daily note; ⌘⇧[ / ⌘⇧] the day
  before / after. 8 ⌘G: the graph; click a dot opens it; ⌘G back.
  9 ⌘K: pick a file in OneDrive; a link lands at the caret; ⌘⏎ on it
  opens the file. 10 ⌘⇧N: a note from a template; ⌘⇧T inserts one at
  the caret. 11 type #test: 🏷 TAGS counts it; click it filters the
  list. 12 ⌘⇧F, a word from inside a note: ⏎ opens at that line, Esc
  back. 13 ⌘⇧K: every open - [ ] task; ⌘L ticks the one on the caret's
  line. 14 right pane: OUTLINE headings jump; ≈ lists notes that name
  this one without linking it. 15 "/" on an empty line: the menu;
  pick dataview; 🔎 QUERY draws on the right, nothing written into the
  note. 16 ⌘⇧B: the board; drag a card; that note's field changes.
  17 ⌘⇧E: a selection becomes a new note with [[Name]] left behind;
  ⌘⇧R opens a random note. 18 ⌘⇧S: the Scorp Pad's tabs land in
  <Vault>/Scratch as .md. 19 ⌘F filters; ↑↓ ⏎ walk; ⌥↑/⌥↓ from inside
  the text. 20 📌: the window stays up; Esc only hands the keys back.
  21 ⇪⇧U: the row says "Open that note in Hamsidian". 22 ⇪D: the
  notes rows are labelled Hamsidian; @vault still filters to them.
  23 Obsidian: open <OneDrive>/Vault — the same notes. Report the
  numbers that fail and the alert text; each becomes its own release.
- 6.213.5 verify with LL: ⇪⇧V, Enter on a row — a dark 760×520
  window comes to the FRONT with the caret already in a multi-line
  box holding the entry. Edit, ⌘⏎: "✏️ Clipboard entry updated — and
  copied", and ⌘V pastes the edited text. Enter on another row, the
  Delete button: "🗑 Clipboard entry deleted". Esc closes without
  changing anything. If the old small prompt appears instead, that Mac
  has no hs.webview — say so; it is the degrade working.
- 6.213.4 verify with LL: in Chrome type "statrs " → starts. Then
  "adress " and "sceen " must stay as typed (two listed words each —
  the rule still never guesses), "allways " → always, "plugin " and
  "backend " still stay. If a RIGHT word is ever rewritten, paste
  `_G.autocorrectReport()`'s spelling block and ⇪Z it; that is the
  evidence for the next measurement.
- 6.213.3 verify with LL: ⇪5, drag an area over a scrolling page in
  Chrome. The stitched "… (scrolling).png" lands in the screenshots
  folder, ⌘V pastes it, the editor opens on it. `_G.screenshotsReport()`
  has a new "slices :" line — "…/Application Support/Hammerspoon/
  scroll-slices · local, never synced" is healthy; "temporary — …" is
  the degrade working (say so); "⚠️ NONE" means both folders refused and
  the run stopped before slice 1. If it still fails, paste the "scroll :"
  block again — this time the words are about a local folder.
- 6.213.2 verify with LL: in Chrome type "plugin ", "backend ",
  "signin " — all three must stay as typed (on 6.213.1 they became
  pluging, backened and signing). "somethingg " still becomes
  something. (statrs stayed statrs by design here; LL wanted it
  corrected → 6.213.4.) Then ⇪⇧P: the card is ~30% until the mouse is over
  it, solid under the mouse, solid again for the last two minutes and
  the flash.
- 6.213.0 verify with LL: ⇪⇧1 — Spotlight (S): drag a box and the rest
  of the shot goes dark, the box stays bright; drag a second box: a
  second bright hole, no darker elsewhere. Magnifier (M): drag from a
  point outward; a circle shows that spot at 2× with a white ring; drag
  the dot on its right edge to grow it. Then the two doors: copy any
  image (⌘C on a picture in a browser), ⇪⇧1, ⌘V — it lands in the
  middle at 40% width; drag its corner and it scales keeping its shape.
  ⌘A: the area selector appears — drag over something ON SCREEN (move
  the editor aside first if it covers it) and the capture lands on the
  shot the same way. ⌘⏎: all of it is in the file and on the clipboard.
  If ⌘V says "Nothing to paste", the clipboard held text, not an image
  — that is the message working. If ⌘A says "Capture did not land —
  screencapture exit 1", that is the same Screen Recording permission
  ⇪5 needs. Knobs, no release: `settings = { screenshot_editor =
  { magZoom = 3, veilAlpha = 0.7 } }`.
- 6.212.0 verify with LL: ⇪⇧1 (or ⌥⏎ on a history row) — four new
  buttons after Arrow: Line, Oval, Highlight, Counter (keys L O H C).
  Drag a line; drag an oval from the bottom-right corner UP and to the
  left (it must come out the right way round); drag the oval by its
  inside, then by its corner dot; lay a yellow highlight over a
  sentence; click three times with Counter (①②③), ⌫ the ② and click
  again — it must say ④. ⌘⏎: everything is baked into the saved file
  and on the clipboard. Esc and reopen the same shot: all of it comes
  back. NOT in this release, deliberately: Spotlight, Magnifier, Paste
  Image and Add Capture — they read pixels or reach outside the page
  and are 6.213.0's own question.
- 6.211.0 verify with LL: ⇪⇧P, then ⇪⇧0 — the card jumps to sit
  against the calendar's LEFT edge, top-aligned, still counting; close
  the calendar (esc) and it is back where it was. Drag the card
  somewhere first, then ⇪⇧0 and esc: it returns to where he dragged it.
  Then ⇪⇧0 first and ⇪⇧P second: the card must appear beside the
  calendar, never under it. STATED, NOT HIDDEN: it sits BESIDE the
  calendar, not inside it — inside means reserving a corner of the
  calendar's own layout (a 180-pt card in a 120-pt footer), which is a
  calendar decision for its own release if he wants it.
- 6.210.0 verify with LL: ⇪⇧P and wait for 0:30 — Submarine, quietly,
  then every three seconds a little louder, ten times, the last one at
  full volume, then the flash as before. The break's end stays silent
  (deliberate — `settings = { pomodoro = { toneBreak = true } }` if he
  wants it). If the first one is already too loud or the last too quiet,
  NO release: `toneFrom = 0.05` / `toneTo = 0.7` in the same settings
  table; `toneSecs = 60` for a longer run-up; `toneOn = false` for
  silence. `_G.pomodoroReport()`'s "tone :" line must read "Submarine
  every 3 s … 10 played this phase" after one — if it reads "⚠️ SILENT",
  that Mac has no Submarine under /System/Library/Sounds, which is the
  degrade working, and the name to try is in the same settings table
  (`toneName = "Sosumi"`).
- 6.209.0 verify with LL: ⇪⇧P — the card is 90% opaque from the first
  second, and stays there for the whole countdown and under the mouse.
  If that is still too see-through, or now too solid, NO release:
  `settings = { pomodoro = { alphaIdle = 1, alphaAlert = 1 } }` (or
  0.8), and `cardAlpha = 1, inkAlpha = 1` make the box and the digits
  themselves solid. Then the new bottom line: "🍅 N done today" — N must
  match `_G.pomodoroReport()`'s "today:" line; finish one and the card
  goes to N+1 by itself. The report's new "card :" line says when the
  log was read (once, on the keypress). "🍅 none yet today" first thing
  in the morning is the zero, in words.
- 6.208.0 verify with LL — THE STABILITY ONE, and it can only be
  proven by a stall: after installing, `_G.stallGuardReport()` in the
  Console must read "watching", the beat line counting up, and the
  guard line saying "started … guard.pid says N". `ps -p N` in Terminal
  shows a /bin/sh running tools/hs-stall-guard.sh — as LL, no sudo, no
  launchd; on the work Mac that is the whole point. Then reload: the
  report on the new boot must still say ONE guard (the old one logs
  "exit: Hammerspoon quit cleanly" — visible under "log :"), never two.
  To see it fire on purpose, paste into the Console:
  `hs.timer.usleep(100 * 1000000)` — a 100 s stall by hand (6.213.1
  raised the threshold: 60 s readings ten apart, so the kill comes at
  roughly 70–80 s of silence; a 40 s freeze must NOT trigger it, and
  that is worth seeing too). Hammerspoon vanishes and comes back, and
  the new boot alerts
  "🧊 Hammerspoon HUNG for N s at HH:MM:SS and was relaunched by the
  stall guard". The next reload after that must say NOTHING about it
  (remembered in hs.settings). Close the lid for a minute and open it:
  nothing must happen, and the report's log line may show "skipped a
  reading after a Ns gap (sleep?)" — that is the sleep rule working.
  If a boot ever says "GAVE UP", the config stalled at boot three times
  in ten minutes: hold ⇧ while Hammerspoon launches, fix, reload. Off
  switch, no release: `settings = { stall_guard = { on = false } }`.
  THE FALSE-POSITIVE CHECK (6.213.1): open a modal dialog — ⇪N's
  Quick Append box, or Bulk Rename's Find — and leave it open for THREE
  minutes, then cancel it. Hammerspoon must still be the same process
  (`_G.stallGuardReport()` shows no relaunch line). If it DID relaunch,
  hs.timer stops under a modal dialog on that macOS and the guard must
  go off (`on = false`) until it learns to read that; say so, that is
  the one unproven assumption in this feature.
  THE ONE THING THAT CANNOT BE PROVEN WITHOUT A MAC: that a process
  started by hs.task with `nohup … &` outlives a `kill -9` of
  Hammerspoon on macOS (it should — it is reparented to launchd, and
  nothing signals the group). If after a forced stall Hammerspoon does
  NOT come back, that is the fact to report, and the escape hatch is
  unchanged: Activity Monitor → Hammerspoon → Force Quit, then
  `hidutil property --set '{"UserKeyMapping":[]}'` in Terminal.
- 6.207.0 verify with LL: ⇪⇧1 (or ⌥⏎ on a history row), Text tool,
  click, type a word, ⏎. Now CLICK that box once with the Text tool: the
  input opens with the word in it — change it, ⏎. Then drag the box:
  it moves, no input. Then Blur tool, click the box (selects it), press
  ⏎: the input opens again. Double-click still edits in any tool. If a
  click still opens an EMPTY box, say where the box was on the shot and
  how big the shot is — that would be the hit test missing the box,
  which is the other half this release could not see from here.
- 6.206.0 verify with LL: ⇪5, drag an area over a scrolling page in
  Chrome. Either it works — the stitched "… (scrolling).png" is saved,
  ON THE CLIPBOARD (⌘V pastes it), and the editor opens on it — or it
  stops at the first slice with an alert that NAMES the slice, the exit
  code and screencapture's own words. Then `_G.screenshotsReport()` in
  the Console and paste the "scroll :" block: it lists every slice's
  exit, size and stderr. If the words say "could not create image" or
  name the display, the likeliest cause is Screen Recording: System
  Settings → Privacy & Security → Screen Recording → Hammerspoon, then
  QUIT AND RELAUNCH (a grant is read at launch). The kept slices are
  dot-files in the screenshots folder (⌘⇧. in Finder shows them). The
  cause is NOT known from here — 6.206.0 makes the next failure say it.
  6.213.1 REPORT: it stopped at slice 1 of 4 and named the destination
  — the cause, fixed in 6.213.3.
- 6.205.0 verify with LL: in Chrome, type "starts ", "allows ",
  "convinced " — all three must stay exactly as typed (on 6.203.0 they
  became starets, gallows and something else). Then "statrs " must still
  become "starts" and "somethingg " still "something". Then the door:
  `_G.autocorrectAdd("intsead", "instead")` in the Console, and type
  "intsead " anywhere — it corrects at once, no reload; the alert names
  the row to delete to take it back. `_G.autocorrectReport()`'s
  "spelling" block lists every word the list changed this session — if
  a RIGHT word ever appears there again, paste that block: it is the
  evidence, and ⇪Z right after it undoes and refuses it permanently.
  Sublime Text is deliberately not corrected by the word list (code
  editors are on offIn); the CSV rows still work there.
  6.213.1 REPORT: starts, allows, convinced stayed; somethingg and the
  door worked; statrs stayed statrs — measured, explained and the real
  bug beside it fixed in 6.213.2.
- 6.204.0 verify with LL: ⇪D, then MOVE THE MOUSE over the list. The
  highlight must follow the pointer from row to row, and the pane on the
  right must show that row — its header says "🖱 under the pointer".
  Arrow keys still work and the header switches to "⌨️ ↑↓". Then the
  one he asked for: hover a long clipboard entry — the pane shows the
  WHOLE thing (a long one says "N characters — first 12,000 shown · ⏎
  copies all of it"), and ⏎ still copies all of it. A click still
  copies and closes, as before. `_G.unifiedSearchReport()` has a new
  "pane :" line — "N asked · N drawn · 0 refused" is healthy; a
  "refused" count with the ↳ line under it means the push into the page
  failed on that Mac and the pane is showing preview lines only — say
  so, that is the degrade working, not the feature. If the pane is in
  the way: settings = { unified_search = { pane = false } }, no release.
  The window is 400 px wider than before to carry it. THE ONE THING
  THAT CANNOT BE PROVEN WITHOUT A MAC: WebKit delivers mouse-moved
  events to a window that is KEY, and this panel is key while it has
  the keyboard (it takes typing) — but it is opened non-activating. If
  the arrows work and the pane follows them while the pointer moves
  NOTHING, that is the window not receiving mouseMoved, not the page:
  say so, with the Console lines, and the click still copies meanwhile.
  Nothing else changed in this release, on purpose.
- 🗳 DECIDED BY LL 6.198.0, ASKED AND ANSWERED — do not re-ask:
  (1) BUGS BEFORE FEATURES while he tests: ⇪2 (shipped 6.198.0), then
  doc_memory.lua:363, then the autocorrect pair (the `allow,HOw` row and
  the no-op `fix` row that short-circuits the TWo-caps rule). THEN the
  agreed feature order — window positions, pomodoro sound, ⌥⌥ menu bar,
  ⌘⌘ clipboard. (2) SPELL-CHECK IS A REAL DICTIONARY CHECK, not a list
  of custom rows: check a typed word against macOS's own
  /usr/share/dict/words and correct only when EXACTLY ONE real word is a
  single transposition / doubling / omission away (somethgni, somethingg,
  somethinng, somethng, somtething and their families). Ambiguous → leave
  it alone; missing word list → the feature says so and typing is
  untouched. AMENDED 6.213.4 on LL's word: words the list holds
  outright first, exactly one; only when none is near, words by an
  ending in kind order (swap, doubled, missing, rotated). (3) THE POMODORO ESCALATION SOUND IS **Submarine**
  (/System/Library/Sounds), growing over the last 30 seconds from 24:30.
  (4) The ⇪ glyph question is CLOSED — the bar is there, no font changes.
  🚨 ONE CHANGE PER RELEASE, still: "if these changes will introduce
  issues, only do them one-by-one. We must isolate the changes so we only
  have to fix one thing." And every addition must work on the home Mac
  AND the work Mac.
- Screenshots folder override: waiting on LL to name a path; then ship a
  one-line `settings = { screenshots = { dir = "..." } }` profile override
  with full ceremony. (Verified: zero code changes needed.)
- CANVAS (asked 6.188.0, NOT built — LL sent Obsidian's Canvas page).
  The right architecture is settled and worth keeping: Obsidian Canvas
  files are the OPEN **JSON Canvas** format (jsoncanvas.org) — a
  `.canvas` file of `nodes` (text / file / link / group, each with
  x/y/width/height/color) and `edges` (fromNode/fromSide → toNode).
  Writing that format means the same file opens in Obsidian, exactly as
  the vault's .md files already do: THE FOLDER IS STILL THE DATABASE.
  Do NOT invent a private format. Open question for LL before building:
  whether v1 is a READ/arrange surface (open a .canvas, pan/zoom, move
  cards, follow a card into its note) or also an authoring surface
  (draw edges, embed images/PDF/video). The vault window already has
  the webview recipe, the note index, and 6.186.0's drag-and-write, so
  a card that IS a note is close; embeds and edge-drawing are the
  expensive half.
- STILL OPEN, older asks (their original verify blocks are in
  CLAUDE-archive.md): the Chrome tab scan (diagnosed — `osascript
  exited 15` is our own 6 s kill of a BLOCKED script; check System
  Settings → Privacy & Security → Automation → Hammerspoon before any
  code change); "the ability to write into any .csv or .txt" (LL,
  6.194.0 — NOT scoped: the pad's store is JSON and its 4 PM Asana task
  rides on it, so it is a data-shape decision, not a UI one); folding
  the Scorp Pad's SCRATCH NOTES into the vault properly; the ⌘1–⌘9
  panel reflowed like ⇪space; a SNIPPETS window in the ⇪space style;
  sequential screenshots to the clipboard (needs LL's go-ahead — the
  honest shape is a multi-select in ⇪space @shots writing FILE URLs);
  @ source discoverability; widening `uni.runnable`; vault
  front-matter completion; ⌘⇧N / ⌘⇧E on the small dialog (the
  `editor.open` window exists since 6.213.5 — take it); the ⇪⇧O
  image-history beach ball (a stall — diagnose before touching); and
  6.202.0's queued `_G.clipboardReport()` for the chooser pane (the
  one change queued next, alone).
