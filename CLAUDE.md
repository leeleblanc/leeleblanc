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
  never in the repo, never in a zip. Release zips are never committed.
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

Scratch pad — named the SCORP PAD to LL since 6.171.0 (visible strings only;
file, store, `_G.scratchPad` and service ids unchanged; 768×1024 portrait, window
alpha 1 via `sp.alpha`, 16 px text via `sp.fontSize`) — (6.164.0, modules/scratch_pad.lua, ⇪1): a webview on the
Capture Pad recipe — NO eventtap, NO AX/window reads, every timer held.
Keystrokes land in `sp.tabs` at once, the store (Logs/scratch/scratch.json,
write ledger) 0.3 s later. The 16:00 task goes through `_G.asanaSubmitTask`
with `extra.comment` (the only Asana path); keep it that way.
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
✂️ HALVE THE LANDED BOX (6.192.0, mouse_grid): after ⇪X lands, ⌥+arrow
keeps that HALF of the cell and puts the pointer at its centre; press
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
   6.227.0 14e953a · 6.228.0 2aa3dfe · 6.229.0 a1318e1 · 6.230.0 0740c07 · 6.231.0 c1921af · 6.231.1 5a5c298 · 6.232.0 1ca3f6f · 6.233.0 2328c8c · 6.234.0 57f78d0 · 6.235.0 52e5b21 · 6.236.0 34cff8b · 6.236.1 fdce771 · 6.237.0 adf9256 · 6.238.0 3adad4f · 6.239.0 3adad4f (one commit, two releases) · 6.240.0 8f44bec · 6.241.0 dce517e · 6.242.0 1a1dab0 · 6.243.0 8fba04f · 6.244.0 9320906 · 6.245.0 9c1a8b1 · 6.246.0 1400abd.
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

Running total: 15 wins · 8 losses · 22 pending (6.215.0, 6.217.0, 6.218.0,
6.219.0, 6.220.0, 6.221.0, 6.222.0, 6.223.0, 6.224.0, 6.225.0, 6.226.0,
6.227.0, 6.228.0, 6.229.0, 6.230.0, 6.231.1, 6.232.0, 6.234.0, 6.236.0,
6.236.1, 6.238.0, 6.239.0).
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

- 🧭 THE NINE (LL, 2026-09-18, on the batch he reported after 6.245.0:
  "go & build in that order. Prep each item to roll out as I come back
  and say next"). ONE CHANGE PER RELEASE, built back to back, and he
  installs ONE ZIP AT A TIME — the zip for release N is built from N's
  commit and carries everything before it, so a break still names its
  version. THE ORDER, his: 1 ⇪⇧A on the current selection ✔ 6.246.0 ·
  2 grid arrow cadence · 3 grid translucency · 4 the calendar header ·
  5 cheat-sheet punctuation search · 6 the music card takes the
  keyboard · 7 the yellow box splits by letter (and ⌥halve goes) ·
  8 the Scorp Pad renamed Hamsidian · 9 the three removals (the 4 PM
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
  `_G.begoneProbe()` with Notification Center open, and what "Doc
  watcher;;" was going to say.

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

- 🟡 FROZEN GRID BOX, SUSPECT ONLY (2026-09-12, LL: "Frozen grid
  again." with a screenshot of the yellow landed-box outline over a
  Finder replace dialog while installing 6.215.0, then "disregard").
  NOT diagnosed, NOT built. Read, not proven: init.lua's
  `_G.showCanvasSafely` returns false on the first refused :show()
  and then RETRIES 50 ms later and shows the canvas anyway, telling
  nobody; mouse_grid's `showBox` / `showCrosshair` are the callers
  that ACT on false (grid.hide, boxDraw never assigned) — so a box
  refused once while another app's popup was mid-transition (a
  Finder sheet appearing is exactly 6.56.0's trigger) can come up a
  turn later with NO owner, kept alive by the retry timer's closure
  in `_G.canvasShowTimers`, and nothing can delete it but a reload.
  `_G.mouseGrid.hide()` cannot clear such a box; `hs.reload()` can.
  The first refusal prints nothing — a 🔔 gap too. If LL reopens it:
  the artefact first (was ⇪X / ⌥+arrow pressed just before; any
  "grid halved box" Console line; did `_G.mouseGrid.hide("stuck")`
  clear it — if not, that is the orphan). Fix shape: the retry hands
  the canvas back (callback) or deletes it when the caller already
  gave up; never a second owner-less show.
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
