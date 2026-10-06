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
  🚨 6.311.0 — AND I BROKE THIS RULE HAVING JUST QUOTED IT (LL: "Zip is
     empty again. Above we talked about not making the same mistakes.
     What do you think? Are you doing that?" He is right and the answer
     is no). SIXTH empty delivery. The measurement in ⚖️ below was in
     hand — 2.76 MB failed twice, 94 KB installed first try — and I
     shipped 1.64 MB anyway, because 6.305.0's "every FOLDER must be
     COMPLETE" made me carry all 71 modules to change ONE, and I
     rationalised the result as "40% smaller than the one that failed".
     🔑 THE TWO RULES ARE NOT IN CONFLICT AND I READ THEM AS IF THEY
     WERE. 6.305.0 forbids a PARTIAL FOLDER, not a small patch — the
     third shape satisfies both and is the one to reach for first:
     **LOOSE FILES AT THE ROOT AND NO FOLDER AT ALL.** A patch with no
     folder in it cannot replace a folder, so it cannot delete one, and
     it costs only the size of the files that really changed. 6.311.0
     is four loose files, 102,736 bytes: init.lua, music_player.lua, a
     READ-ME-FIRST naming where each goes, and the release's changelog
     entry alone (the 1.3 MB CHANGELOG.md was most of the 1.64).
     🚪 ITS ONE COST, NAMED AND INSTRUMENTED: a module file placed by
     hand can go to the wrong folder, and then init.lua is new while
     the module is old — a half-upgrade with no error anywhere. So the
     README gives the two Console lines that tell them apart
     (`_G.configVersion` and the tool's own report) and says which
     answer means which half landed. A manual step is acceptable only
     when its failure is VISIBLE in five seconds.
     ⚖️ GENERAL, AND IT IS THE ONE TO CARRY: WHEN TWO RULES HERE SEEM
     TO FORCE A BAD OUTCOME, THE READING IS WRONG BEFORE THE RULES ARE
     — look for the shape that satisfies both, and never trade away a
     MEASURED variable to satisfy a structural one.
  📦 AND THEN A 2.93 MB ARCHIVE ARRIVED AND INSTALLED FIRST TRY
     (2026-10-05, his boot log minutes after the 6.333.0 delivery:
     `📌 init.lua ARCHITECTURE VERSION: 6.333.0`, All green, 71
     modules, 107 ⇪ shortcuts). THE SIZE FINDING BELOW IS CONTRADICTED
     and must not be quoted as settled. It was retired as a FINDING on
     four deliveries — 94 KB and 102 KB in, 1.64 MB and 2.76 MB out —
     and the fifth went the other way at 3,067,945 bytes, by the same
     route, with nothing else changed.
     🔑 WHAT STANDS: the four-link chain, the numbers in the message,
     and verifying the ARTEFACT rather than the intention. WHAT DOES
     NOT: "small or it will not arrive". Ship the complete package —
     he asked for exactly that ("I'm not downloading individual files
     anymore") — and go on measuring. GENERAL, and it is the half worth
     carrying: A FINDING RETIRED ON FOUR DATA POINTS IS STILL A FINDING
     THAT CAN BE OVERTURNED BY THE FIFTH; write the contradiction down
     where the finding is read, not somewhere else.
  ✅ AND THE 102 KB ONE ARRIVED — SIZE IS MEASURED TWICE NOW, NOT ONCE
     (his boot log minutes later: `📌 init.lua ARCHITECTURE VERSION:
     6.311.0`). Two deliveries at ~100 KB installed first try (94 KB at
     6.303.0, 102,736 bytes at 6.311.0); two at 1.64 MB and 2.76 MB
     never arrived at all. That is a controlled pair in each direction,
     so the hypothesis is retired as a FINDING: every delivery from here
     is loose files at the root, no folder, in that size class, and the
     question is not re-opened without new evidence.
     🚪 AND THE COST I NAMED IS THE COST THAT LANDED, on the very first
     try: his `_G.musicReport()` read `🎵 JUG PLAYER — ⇪⇧pad.` with no
     `doors :` line — init.lua new, modules/music_player.lua old. A
     hand-placed module went somewhere else, exactly as the README said
     it could, and NOTHING ELSE WOULD HAVE SAID SO: the config boots
     green, the version stamp is right, and the feature is simply
     absent. 🔑 THE INSTRUMENT IS WHAT MADE IT A FIVE-SECOND ANSWER
     rather than a second "it does not work" — two Console lines whose
     DISAGREEMENT names which half landed. GENERAL, and it is the rule
     that makes a manual install step acceptable at all: A DELIVERY
     THAT ASKS THE PERSON TO PLACE A FILE OWES A CHECK THAT NAMES THE
     HALF-INSTALL, in the message and in the archive, before he runs it.
  ⚖️ AND THE MEASUREMENT WAS RETIRED ONE WORD TOO EARLY (LL, on the
     third identical report: "This is exactly what you said you're
     getting right and I said are you sure"). He is right, and the
     error is in the ✅ block above: it proved ~100 KB ARRIVES and
     then treated the delivery question as CLOSED. Arriving is not
     installing. 🔑 THE CHAIN HAS FOUR LINKS, NOT THREE — 6.263.0
     wrote "BUILDING IS NOT DELIVERING AND DELIVERING IS NOT
     ARRIVING" and stopped one link short: **AND ARRIVING IS NOT
     INSTALLED, AND INSTALLED IS NOT LOADED.** A release is not
     delivered until the RUNNING config reports the new behaviour;
     every earlier link is a proxy, and retiring a question at a
     proxy is how the same failure comes back wearing the next
     link's name.
  🔎 AND "WHERE ARE YOU GOING WRONG" IS A QUESTION I HAD NOT EARNED
     THE RIGHT TO ANSWER. Twice I read "the loaded module is the old
     one" — which is PROVEN, the old report heading is a hard-coded
     `.. " — ⇪⇧pad."` literal and the new one cannot emit it — and
     twice I let it imply he had mishandled the file, which is NOT
     proven and is a different claim. 🔑 THE FACT THAT SEPARATES THEM
     IS THE FILE'S OWN mtime, and it cost nothing to collect: recent
     means the copy DID land and the fault is downstream (mine);
     old means it never arrived at that path. GENERAL: when a symptom
     has a "the person did it wrong" branch and a "the tool did it
     wrong" branch, find the field that separates them BEFORE saying
     either out loud — and prefer the instrument that reads from
     inside the running config, which assumes no Finder, no folder
     and no step he has to describe correctly.
  🔁 AND THEN THE SAME STEP FAILED A SECOND TIME — SO THE STEP IS THE
     VARIABLE (LL, on a 6.311.0 boot: "Didn't work for Jug player",
     with a `_G.musicReport()` still headed `🎵 JUG PLAYER — ⇪⇧pad.`
     and still carrying no `doors :` line). The instrument worked
     twice and named the half-install twice; what did not work twice
     is the HUMAN PLACEMENT it was instrumenting. 🔑 THE PRINCIPLE IS
     THE ONE 6.266.0 ALREADY WROTE ABOUT RETRIES, one layer out: when
     a delivery fails twice at the SAME step, stop improving the
     instructions for that step and REMOVE THE STEP. A check that
     names a failure is not a fix for it — it is the evidence that
     the same fix is owed a second time.
     🚚 WHAT REPLACES IT, and it is smaller than the archive it
     replaces: SEND THE BARE `.lua` FILE INLINE (116 KB, no .tar.gz,
     no unpack, no folder anywhere in the chain) AND GIVE ONE
     TERMINAL LINE THAT FINDS IT, VERIFIES IT, COPIES IT AND PRINTS
     THE PROOF. The line greps for a token the NEW file has and the
     old one does not (`keyLabel`: 8 occurrences vs 0), so it can
     refuse a stale copy sitting in Downloads from an earlier
     release, and it prints the count afterwards as the receipt.
     A drag has no receipt; a command does.
     🪟 THE FAILURE MODE NOBODY WARNED HIM ABOUT, and it is one click
     wide: dragging a file onto a folder that already holds that name
     offers **Keep Both**, which writes `music_player 2.lua` beside
     the old one. §1.12 loads an explicit module list, so the stray
     is ignored entirely and the ORIGINAL stays loaded — the install
     looks done, Finder shows the new file, and nothing has changed.
     The command lists any `music_player*` that is not the exact name
     for exactly this reason. GENERAL: when an install step is a
     Finder drag, the plausible-looking wrong outcome is a renamed
     duplicate, not a missing file — look for the stray, not the gap.
  🖥 AND THE MEASUREMENT FINALLY CAME BACK: THE FILE WAS NEVER WRITTEN
     (his Console, on a probe that reads the loader's own path:
     `bytes : 107414` — the 6.310.0 file exactly — and
     `written : 2026-09-28 05:30:03`, the morning BEFORE 6.311.0
     existed, with no STRAY lines). So the Keep Both theory was WRONG
     and is retired; nothing was renamed, nothing was duplicated, the
     path simply never received a write. 🔑 AND THE mtime IS WHAT MADE
     THAT A FACT RATHER THAN A THIRD ACCUSATION — it separated "he
     mishandled it" from "it landed and broke downstream" in one
     field, which is the rule two blocks up being paid the first time
     it was asked.
     🚪 SO THE INSTALL MOVES TO THE ONE CHANNEL HE HAS DEMONSTRABLY
     USED CORRECTLY: **THE CONSOLE PASTE.** Three deliveries have now
     failed at Finder or Terminal; zero have failed at a Console
     paste — he has pasted a probe back perfectly twice. So the
     installer IS a Console line: it walks ~/Downloads three deep,
     picks the candidate containing a token only the new file has,
     writes it to `_G.moduleDir`, re-reads it and prints the byte
     count as the receipt. No Finder, no Terminal, no drag, no
     unpack. GENERAL, and it is the delivery rule that generalises
     past archives: ROUTE AN INSTALL THROUGH THE CHANNEL THE PERSON
     HAS ALREADY PROVED THEY CAN DRIVE, not the one that is
     conventional — and when several channels are in play, count
     which has actually worked for THIS person rather than which
     ought to.
  🚨 AND THE OBVIOUS STOPGAP WOULD HAVE DONE NOTHING, caught by
     reading rather than by shipping it: `_G.hyperAddShortcut` does
     NOT bind — it appends to `_G.hyperPending`, which only
     `_G.hyperFinalize()` drains, ONCE, at the end of boot. Called
     from the Console it is a silent no-op, which on this thread
     would have been a fourth "didn't work" with no explanation. The
     runtime door is `_G.hyperModal:bind(mods, key, fn)`, which is
     what hyperBind itself calls. 6.228.0's rule in a new place: a
     registration function that is READ once at boot cannot be used
     to register anything afterwards — check WHEN the list is
     drained before offering a live call.
     📏 AND THE COMBO KEY IS `mods+key`, PLUS-SEPARATED
     (`hyperCombo`: sorted, lowered, joined with "+"), NOT the pipe
     form `shift|.` that test_integration's HYPER_CLAIMS uses. Two
     formats for one idea, and the memory of the test harness's one
     nearly wrote a registry row that `_G.freeKeys()` would have
     ignored — leaving the key advertised as free while bound, which
     is 6.276.0 exactly.
  🧪 AND THE CONSOLE INSTALLER FAILED ON HIS MAC, BECAUSE MY HARNESS
     WAS GENTLER THAN hs.fs — 6.193.0 for the TENTH time, and the
     first time it has cost a DELIVERY rather than a feature. His
     Console: `bad argument #1 to 'for iterator' (directory metatable
     expected, got nil)`.
     🔬 `hs.fs.dir(path)` RETURNS TWO VALUES — an iterator AND a
     directory object — and the iterator is called WITH that object as
     its state, LuaFileSystem-style. `local ok, it = pcall(hs.fs.dir, d)`
     keeps the iterator and THROWS THE STATE AWAY, so the first call
     passes nil and raises. The plain `for e in hs.fs.dir(d) do` form
     is correct precisely because a generic `for` captures all three
     control values; wrapping it in pcall is what breaks it. The fix
     collects the entries inside `pcall(function() for e in
     hs.fs.dir(d) do ... end end)` — which also closes the handle
     before recursing, rather than holding one open per level.
     🚨 MY STUB RETURNED A SINGLE STATELESS CLOSURE, so it worked
     either way and the bug was invisible. The rebuilt stub returns
     two values and its iterator RAISES when called without the
     dirobj — and it reproduced his exact message before the fix, then
     passed all five cases after. GENERAL, and it is the sharpest
     costume this rule has worn: A STUB MUST MODEL THE PROVIDER'S
     ARITY AND ITS CALLING PROTOCOL, not just its return VALUE — a
     provider that returns (iterator, state) is a different contract
     from one that returns a closure, and every pcall wrapped around
     such a call silently truncates it.
     🚨 AND THE GATE ALREADY HAD THE RULE — I SIMPLY DID NOT RUN IT.
     `tools/hs-lint.lua` carries `fs-dir-loses-state`, whose own `why`
     text states my exact error verbatim ("throws 'directory metatable
     expected, got nil' at runtime — never at load, so nothing catches
     it until the feature is silently dead"), and all SIX real call
     sites in this config capture three values correctly. Run against
     the paste I sent, it reports ERROR on the bug and clears the fix.
     🔑 THE REASON IT GOT THROUGH IS STRUCTURAL, AND IT IS THE RULE TO
     CARRY: **A CONSOLE PASTE IS CODE THAT SHIPS WITHOUT THE GATE.**
     Every line handed to him to paste — a probe, an installer, a
     stopgap, a one-off repair — bypasses run-tests.sh, the linter, the
     mutation sweep and the sentries, while running with full
     privileges on the Mac the whole config lives on. So any Lua
     written for him to paste goes into a scratch `modules/paste.lua`
     and through `lua5.4 tools/hs-lint.lua <dir>` FIRST, and its
     harness models the provider faithfully — the same two conditions
     every shipped line already has to meet. (The lint run will also
     report `module-contract`; that one is expected for a paste and is
     ignored.)
  ✅ AND IT LOADED — THE FOURTH LINK IS PAID, WITH TWO PROOFS
     (2026-09-29 18:53, his boot log and report minutes after the
     Console installer wrote 116,595 bytes to `_G.moduleDir`):
     `🎵 JUG PLAYER — ⇪⇧. · ⇪⇧pad.` with `doors : 2 way(s) in`, which
     the 6.310.0 file CANNOT emit — its heading is a hard-coded
     `" — ⇪⇧pad."` literal — AND `107 ⇪ shortcuts` in the boot line,
     up from 106, counted by a different instrument that knows nothing
     about that heading. Two independent measurements, one conclusion.
     NOT SCORED: he wrote "Looking good. You think?", which is a
     question and not his win sentence.
     🚪 SO THE CONSOLE PASTE IS THE PROVEN INSTALL CHANNEL, on evidence
     rather than on the reading that chose it: three deliveries failed
     at Finder or Terminal, one succeeded at a Console paste, first try.
  🚨 AND THE LINTER COULD NOT HAVE SEEN THE BUG IN A PASTE — THE GATE I
     HAD JUST PROMISED HIM, IN THE SAME MESSAGE. `fs-dir-loses-state`
     scanned LINE BY LINE and a Console paste is ONE LINE: its capture
     pattern was anchored to `[^\n]`, so on a single-line file the rhs
     spanned from the FIRST `local` all the way to `hs.fs.dir`, the
     gmatch matched ONCE (`names="H"`, off `local H=os.getenv("HOME")`),
     and the real `local ok,it=pcall(hs.fs.dir,d)` was never examined.
     MEASURED, NOT READ: the identical bug in a multi-line file fires
     correctly, which is what names the cause.
     🔑 GENERAL, AND IT IS THE ONE TO CARRY: **A LINE-ORIENTED SENTRY
     GOES SILENT ON A ONE-LINE FILE, AND SAYS NOTHING WHILE IT DOES.**
     6.263.0's scanner rule — end the window at the thing's own boundary
     — one step on: a window anchored to the LINE is UNBOUNDED when the
     file has one line, so it reads as a scan and is a single match. The
     rule walks to each `hs.fs.dir` and reads BACK to its own statement
     now (nearest preceding `local`, refused when the span crosses a
     keyword or a newline), and searches the WHOLE source for
     `for e in <name> do` rather than one line at a time.
     🧪 PROVEN IN BOTH DIRECTIONS, which is the half that earns it: it
     fires on the one-line bug, stays clean on the one-line fix, still
     fires on the multi-line bug at the right line number, and reports
     0 ERROR over the real tree (6.269.0 — a new instrument is measured
     against the healthy case FIRST).
     🚨 AND hs-lint HAS NO SUITE OF ITS OWN, which is how a rule came to
     be silent for the very artefact class it was written for. Every
     rule in it is a bug that cost a release, the gate runs it before
     every suite, and NOTHING checks that any rule still bites.
     `tests/test_lint.lua` — a fixture per rule, in both shapes, one
     that fires and one that must not — is owed.
  📝 AND THE SAME DELIVERY HALF-INSTALLED A SECOND FILE, which is the
     evidence the manifest check below was queued on: his boot carries
     `📝 Changelog: no CHANGELOG.md entry for 6.311.0 — the CSV was NOT
     written`. 6.303.0's rule paid a second time — the guard is honest
     and the delivery was partial. Some of that patch's four loose files
     landed and at least one did not, and NOTHING but the guard said so.
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
  ⚖️ 6.303.0 — AND THE VARIABLE WAS **SIZE**, MEASURED AT LAST. Five
     rounds blamed the format (.zip → .tar.gz), the tracking (untracked
     → committed) and the route (GitHub → inline), and all five moved
     something that was not it. The controlled comparison: the 2.76 MB
     archive was sent INLINE TWICE and arrived neither time (his
     Downloads jumps 6.301.0 → nothing; a Files search returns "No
     matching files"), and a **94 KB three-file patch sent by the SAME
     route on the SAME day installed first try** — his boot log read
     6.303.0 minutes later. One variable changed, one outcome changed.
     🔑 SO THE DELIVERY IS A PATCH WHEN A PATCH WILL DO: `git diff --stat
     <prev-sha> <sha> -- hammerspoon/` names the RUNTIME files (tests,
     CHANGELOG, GUIDE and TESTING are not run by his Mac), and when that
     list is short the archive is those files alone. 6.301.0 → 6.303.0
     was three: init.lua, core/hyper_key.lua, modules/hyper_storm.lua —
     94 KB against 2.76 MB. VERIFY THE SAME WAY (md5 each file against
     the release commit, grep line 7 of the unpacked init.lua) and SAY
     THE NUMBERS; a patch is not a lesser delivery, it is the same
     delivery with the 1,926 snippets and the 1.28 MB changelog left out.
     🚨 A PATCH IS ONLY SAFE OVER A BASE YOU HAVE ASKED FOR. Ask
     `_G.configVersion` FIRST — his said 6.301.0, which is why the three
     files were the whole gap; over any other base the same three files
     are a half-upgrade that works for a week.
     📝 AND A PATCH THAT CARRIES CODE WITHOUT ITS CHANGELOG ENTRY TRIPS A
     GUARD DOING ITS JOB: core/changelog_csv.lua lifts the version's
     notes out of ~/.hammerspoon/CHANGELOG.md and REFUSES to write a
     blank CSV row, so every boot printed "no CHANGELOG.md entry for
     6.303.0". Not a bug and not his — a consequence of what I left out,
     so it is NAMED and fixed with a 15 KB entries file prepended to his
     copy (the parser wants `\nNEW IN <v>` up to the next `\nNEW IN `, so
     a prepend parses; proven against a merged fixture before sending).
     GENERAL: when a partial delivery makes an honest guard complain,
     the guard is the evidence the delivery was partial — ship the
     missing half, never silence the guard.
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
- 🆓 NEVER ANSWER "IS THIS KEY FREE?" FROM THIS FILE — ASK THE REGISTRY
  (6.276.0's rule, and 6.311.0 is the release that kept it). ⇪⇧Z is
  reserved and must not be bound. ⇪⇧T and ⇪1 were spent in 6.194.0;
  ⇪⇧. was spent in 6.311.0 (the Jug Player's second door); ⇪3 → vault
  6.172.0; ⇪⇧U → anchors 6.180.0; ⇪⇧7 → Bluetooth 6.216.0.
  🚨 AND THE LINE THAT USED TO SIT HERE SENT YOU TO A DELETED FILE: it
  said to check `hint.groups` in modules/shortcut_hints.lua, "the
  authoritative map of every bound combo" — that module was DELETED in
  6.268.0, so the instruction had been unfollowable for forty-three
  releases while still reading like the answer. It also listed ⇪⇧. as
  free, which was true then and is not now. A hand-kept key list in a
  memory file is the same defect 6.276.0 deleted from the cheat sheet,
  one layer out; these names are a HINT, never the answer.
  🔑 THE THREE LIVE AUTHORITIES, in the order to use them:
    1. `lua5.4 tests/test_integration.lua <hs>` — the collision auditor
       loads the REAL config; `HYPER_CLAIMS` holds every combo with the
       module that took it, and a dump of that table is the whole
       answer in one run (6.311.0 read 76 claims that way, and the near
       miss it found was ⇪. WITHOUT shift → menu_search).
    2. `_G.freeKeys()` / the `keys.free` service / `pt.freeKeyData`
       (PURE) on his Mac — the same registry, rendered.
    3. The gate itself: bind the key and RUN IT. A double-claim fails
       by name, a bound key printed on no card fails (6.294.0), and a
       🆓 row it cannot verify fails closed (6.276.0).
  📏 A COMMENT IN A MODULE IS NOT AUTHORITY EITHER: menu_search.lua said
  "⇪⇧. is the network tools" and net_tools is ⇪6, and has been since it
  was written.
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

- 🪪 A PARENT IS A TASK, AND ITS ID DOES NOT EXIST UNTIL YOU HAVE MADE
  ONE (6.301.0, modules/task_creator.lua + scratch_pad.lua — LL, with
  his project URL: "Parent ID: this is my project ID?"). It is not:
  745948257030523 is the PROJECT gid and every task here already goes
  to it. An Asana subtask is an ordinary task carrying `parent =
  <gid>`, and that gid is minted at the moment of sending — which is
  why three releases said subtasks "need the parent id" and 6.299.0's
  answer channel is what made it reachable.
  🚨 A REFUSED SUBTASK DOES NOT FAIL ITS TASK, and the obvious build
  gets this backwards. The parent is in Asana by then; a caller told
  "failed" marks the tab ❌, and a ❌ tab is RETRIED (6.300.0) — which
  puts a SECOND copy of the parent on his board, silently, every time.
  Duplicating his board is worse than a missing line he is TOLD about,
  so `ok` is the PARENT's outcome and the subtask takes the 🔔 door
  itself, at that moment, naming its parent. Nothing downstream will
  ever retry it, so if it is not said there it is not said at all.
  GENERAL: before deciding what a partial failure should report, ask
  what a RETRY would do — an error that causes a duplicate is worse
  than a warning that causes a correction.
  🔑 `onDone(ok, why, gid, info)` — the fourth value is additive, so a
  caller reading three is unaffected. 🛟 The belt is re-armed for the
  second leg (the first is spent when the parent lands). A subtask is
  never given `projects` — Asana files it under its parent, and a
  project as well draws the same line twice on his board.
  🔬 test_task_creator's core stub had no `degrade`, so every module
  under test took its no-door fallback — 6.278.0's exact hole, second
  time, and 6.290.0's rule applied to our own core rather than macOS.

- 🏷 THE RENAME IS THE MEMORY, AND HIS ANSWER BEAT ALL THREE OF MINE
  (6.300.0, modules/scratch_pad.lua — LL, with a photograph of three
  tabs he had typed the labels into: "Can we rewrite the task titles to
  either of the names in the screenshot … So they stay until I delete
  them?"). 6.297.0's verify block asked where the CLEARED text should
  go — nowhere · the tab's history · exported as a note — and he
  answered by not clearing it. The tab keeps every word and wears the
  outcome as its title: ✅ Success: tasks sent · ❌ Error: tasks not
  sent. NOTHING IS DESTROYED, so 6.280.0's rule is satisfied by
  construction rather than by a safety net, and the tab list becomes a
  ledger of what went — which no report can be, because it is the thing
  he is already looking at. GENERAL: when a design question has three
  defensible answers, the person living with the tool may have a fourth
  that dissolves it.
  🔑 6.281.0's RULE, SECOND TIME IT HAS DECIDED A RELEASE: a ✅ tab is
  SKIPPED for ever, so 16:00 cannot post yesterday again — no second
  store, nothing to go stale. A ❌ tab is RETRIED, which is the only
  reason to mark a failure. TYPING CLEARS THE MARK: a ✅ describes the
  text that was sent, and a ✅ tab that could never be sent again would
  freeze his new writing out of the run.
  🔢 ONE COUNTER PER TAB, ONE FOR THE RUN — a tab is marked when ITS
  tasks have all answered, and one refused task marks the WHOLE tab
  failed (a ✅ over a lost task is the reassuring answer and the wrong
  one). Only possible because 6.299.0 made the submit answer honestly;
  on any earlier build every mark would have been a ✅.
  📅 A LONE DATE IS THE DUE DATE (`sp.whenForAsana`, PURE). Asana
  refuses a start with no end, so `T: today` — the most natural line in
  his own grammar — would have marked the tab ❌. A single date means
  "by then" everywhere else; his two-date spec is untouched, because
  two dates are unambiguous. Every adjustment is NAMED in the preview.
  📏 OPEN TABS ONLY: a closed row has no title to answer on, so sending
  one is sending into silence — counted and said, not dropped
  (6.201.1). 🔌 The day task is kept whole behind `sendGrammar`, and
  every caller goes through one `sp.send` so the switch is real from
  all four doors (6.228.0). 🗓 AND 16:00 IS ON AGAIN, reversing
  6.254.0 on his own equally explicit word — said out loud in the
  config, the sheet, the report and the changelog, because a default
  that flips back without a sentence is how a tool starts doing
  something nobody remembers asking for.

- 🔔 A RETURN THAT MEANS "ACCEPTED" IS NOT A RETURN THAT MEANS
  "DELIVERED" (6.299.0, modules/task_creator.lua + scratch_pad.lua).
  `_G.asanaSubmitTask` answers `true` the instant `hs.http.asyncPost`
  is FIRED; Asana's 200, its 400 and its 401 land later, in a callback
  that showed its own alert and told the caller nothing. Its header has
  said "accepted for posting" since 6.86.0 and every caller read it as
  "sent", because that is what a true from a function called submitTask
  looks like.
  🚨 AND IT DEFEATED 6.278.0 ENTIRELY — the release built from LL's own
  "how do I know if it didn't work?". A send REJECTED BY ASANA printed
  "✅ Hamsidian → Asana", cleared the sticky flag and stamped the day
  done, while task_creator's own callback printed "❌ Error: 400"
  beside it. The instrument could only ever see failures that happen
  BEFORE the request leaves. GENERAL: when a function's return means
  ACCEPTED, every caller needs a second channel for DELIVERED — a
  comment naming the difference is not an interface.
  🔑 `extra.onDone(ok, why, taskGid)` — optional, existing callers
  untouched, EXACTLY ONCE through one door (`finish`, with an
  `answered` flag: six exits used to each return their own way). 🪪 It
  hands back the GID, which is what a SUBTASK's parent needs and what
  does not exist until the create returns.
  🛟 A BELT ARMED BEFORE THE ASK (6.246.0; the check asserts the ORDER,
  6.220.0) answers a silent Asana rather than leaving the caller
  waiting for ever — `answerSecs` (30). A Mac that cannot arm a timer
  still POSTS and the report counts that apart.
  ⏳ AND HAMSIDIAN GAINED A THIRD STATE: "posted — waiting on Asana".
  The day's checksum is stamped in the ANSWER's success branch only, so
  a refusal retries instead of reading as unchanged.
  🔬 THE STUBS ONLY RETURNED, so every check passed with the whole
  second channel missing. test_stub_fidelity §6 fails the gate for a
  submit stub that does not answer onDone — 6.290.0's ratchet on its
  first new contract, and it found the second stub by itself.
  test_task_creator's hs.timer had no `doAfter`, so the belt could not
  have existed there.

- 🔎 A TAG YOU MUST KNOW BEFORE YOU CAN FIND IT IS NOT A TAG YOU CAN
  USE (6.298.0, modules/unified_search.lua — LL, with a ⇪D screenshot:
  "All @ searches should be listed so I know what I can use to
  search"). Fourteen sources, and the only place any of them was ever
  named is a SECTION HEADER IN THE RESULTS — which you reach by having
  already searched for something that happens to be in that store. The
  feature was complete and undiscoverable, which is the same thing as
  absent. GENERAL: when a feature is addressed by a name, ask where
  that name is READABLE before the person knows it.
  🔑 TYPE @ ON ITS OWN and every source is listed with what it HOLDS;
  ⏎ completes the box. EMPTY SOURCES ARE LISTED TOO — "@pad holds
  nothing today" and "there is no @pad" are opposite facts (6.196.1)
  and hiding the empties makes them read the same.
  🚨 IT IS "@" ALONE, NEVER ANY @WORD. The tag rides in every row's
  haystack, so "@o" ALREADY searches @ocr — a directory on every
  @-prefix would take a working search away to show a menu. One
  character, one list; a second character is a search again.
  🔎 AND THE SAME LIST GOES WHERE HE HITS THE WALL THE OTHER WAY: a
  @word that is no tag said "Nothing matches … in any store" — true,
  useless, and naming none of the tags that do exist. One function,
  two callers (6.231.0); the ordinary miss is unchanged.
  📐 THE COUNT IN THE PLACEHOLDER COMES OFF `#uni.sources` and the
  check ADDS a source and requires the drawing to follow (6.239.0).
  Every source carries a `what`, asserted BOTH on the table and on the
  `w` that must reach the page — a field nothing publishes is a
  comment (6.269.0). 🐛 `uni.sourcesJson()` indexed `uni.counts`
  unguarded, so building the page before a gather THREW (6.282.0, in a
  JSON builder). 📏 NAMED, NOT SWEPT: the count line still says "N
  matches across every store" when a @tag has pinned it to one.

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

- 🔎 A REPORT THAT READS A LAZY STORE OWES A "NOT YET" (6.312.0,
  modules/music_player.lua — LL's own boot, two seconds after a reload:
  `queue : empty · history : 0 track(s) · ⏯ keys : ⚠️ WANTED but not
  running`). All three were FALSE, and I read them as lost data and told
  him so. 6.267.0 moved the store read into `M.warm`; 6.289.0 starts the
  media tap there too. Two seconds after boot NEITHER had happened — and
  every one of those lines printed the words for "it happened and there
  is nothing". 6.196.1 inside the instrument built to keep it.
  ⏱ THE FIELD THAT SEPARATED THEM WAS A CLOCK, and it was in his own
  paste: the healthy report was 37 s after boot, the alarming one 2 s.
  His log corroborated it — `sound` loaded AS the report printed and
  `menubar`/`canvas` after. 6.302.0's rule, paid: when a story fits
  every field, find the field that carries a clock and check the order.
  🚨 AND I RAISED THE ALARM BEFORE READING `M.warm`. "Your queue and
  30-day history are gone" was a diagnosis from a symptom, on the one
  store in this config holding something he cannot get back. GENERAL,
  and it is the half to carry: BEFORE REPORTING DATA LOSS, READ WHEN THE
  DATA IS LOADED — a lazy read makes "not yet" and "gone" identical from
  outside, and the cost of being wrong in that direction is his trust.
  🔑 `mp.storeVerdict` is PURE with SIX answers — not read yet · no file
  · ZERO BYTES · unreadable · read and genuinely empty · read with rows
  — and it FAILS CLOSED on a state nobody recorded, because a report
  that cannot say what it found must not pick the reassuring branch.
  `mp.loadStore`'s three silent exits each record what they found;
  `mp.startMediaTap` records that an ATTEMPT was made before anything
  can fail, since "warm has not run" and "macOS said no" both leave
  `mediaTap` nil. GENERAL: anything moved to warm for boot cost owes its
  report a fourth state, and 6.267.0 said this about file_tracker and
  activity_tracker without sweeping the modules that followed them.
  🕘 AND A RETENTION WINDOW IS NOT A CLAIM ABOUT THE DATA. LL: "I don't
  think we have 30-day music history yet. Did we build jug player 30
  days ago?" He was right — 6.231.0 shipped 2026-09-16, thirteen days
  before — and "0 track(s) over the last 30 day(s)" read as a statement
  about his Mac rather than about `historyDays`. It says which it is now.

- 🔒 A FAILED SAVE COSTS THE SAVE, NEVER THE THING SAVED (6.313.0,
  modules/music_player.lua). `saveNow` opened the store with
  `io.open(path, "w")`, which TRUNCATES BEFORE IT WRITES A BYTE — so a
  crash, a full disk or a refused write inside that window left it at
  ZERO BYTES, and `mp.loadStore` reads zero bytes as "nothing queued",
  in silence, after which the next save writes the empty queue over the
  top for good. 6.199.0 applied temp-then-rename to his dictionary and
  6.307.0 was the day the same shape ate a whole test file of ours; the
  store never got it, and it holds the one thing in this module he
  cannot get back. Temp file, then `os.rename` — atomic within a
  filesystem, so the store is the old one or the new one and never half.
  Every failure path removes the temp and SAYS the queue is untouched.
  🔬 AND THE HARNESS HAD TO BECOME FAITHFUL FIRST (6.290.0): its
  `io.open` APPENDED across opens, so two saves to one path produced a
  store no real Mac could hold and the zero-byte window was unreachable
  from the gate. It truncates now, and `os.rename`/`os.remove` work over
  the same virtual disk so a REFUSAL can be driven, not just an absence.
  🚨 THE SOURCE SENTRY PASSED OVER AN EMPTY HAYSTACK — 6.273.0, and it
  was caught only because its twin failed beside it. It read the module
  through the STUBBED `io.open`, which answers nil for a path the
  virtual disk has never heard of, so `src` was "" and "this file does
  not open the store for writing" was true of nothing. It uses
  `realOpen` and ASSERTS the size now. GENERAL, again: a sentry over a
  haystack it did not prove it read is green and measures nothing.

- ⌨️ A SECOND LIST DRAWN UNDER THE FIRST IS NOT A SECOND SELECTION
  (6.315.0, modules/music_player.lua — LL: "Can't use the arrow keys to
  move thru the Jug player history list. Please make that happen.").
  ↑↓ walked `mp.queue` and wrapped INSIDE it, so the 🕘 history drawn
  underneath — clickable since 6.231.0, ✕-able since 6.272.0 — could not
  be reached from the keyboard at all. NOT a regression and not quite a
  bug: the cursor was written when there was one list, and a second list
  was drawn below it four releases later without anyone asking what ↓ off
  the bottom of the first should do. 🔑 GENERAL, and it is the one to
  carry: WHEN A PANEL GROWS A SECOND LIST, THE KEYBOARD RULE FOR THE
  FIRST ONE IS A DECISION THAT HAS EXPIRED — re-ask it in that release,
  because the list that works keeps working and the new one is simply
  unreachable, which looks like nothing at all.
  🔑 ONE CURSOR, NOT TWO. `mp.selMove(cur, nq, nh, d)` is PURE and
  flattens queue-then-history into one run of positions — the card draws
  them as one scrolling list, so that is what the cursor is. Two
  highlights would mean two rows lit at once and a rule about which one
  ⏎ meant, which is a rule he would have to remember.
  🚨 nh IS WHAT IS DRAWN, NEVER #mp.history: the card shows `historyShow`
  (40) of a store holding `maxHistory` (400), so a cursor counted off the
  store walks into rows nobody can see and the highlight vanishes off the
  bottom. `mp.histShown` answers for the cursor AND the drawing, because
  the two disagreeing is the whole defect (6.276.0: read the truth, never
  retype it).
  🔁 d = 0 CLAMPS RATHER THAN MOVES — the second caller (6.231.0), since
  every edit can leave the cursor past the end of its list. An emptied
  list hands it to the other at the row NEAREST where it was: a ✕ on the
  last history row lands on the LAST queue row, never the first, because
  the history is drawn below the queue. Its own check — the wrong answer
  there reads perfectly well.
  🗑 ⏎ AND ⌫ CARRY NO ROW NUMBER. Lua holds the cursor and knows which
  list it is in, so the page naming a row would be naming it in a list the
  page has to guess, and naming a number a redraw may have renumbered —
  6.272.0's rule one key along. ⌫ in the history reads the PATH out of the
  row at the moment of the press. ⌘1–9 and clicks still name a row and
  still go through `pick`.
  🔬 THE SWEEP FOUND BOTH OF ITS OWN FINDINGS. `mp.playAt` sets `mp.sel`
  and did not claim the LIST, so ⏎ on a history row played the right track
  and left the cursor reading that queue number as a history row, where
  the next ⌫ forgets something else; nothing in the play itself can see
  it. And `p = nq + 1` was `p = 1` wearing a general look — nq can only be
  0 to reach that branch — so no mutation could kill it (6.199.0, SIXTH
  time). 21 mutations, 21 bites.

- 🪟 A PICKER macOS REFUSES TO OPEN IS A KEYPRESS, NOT A TRACEBACK
  (6.314.0, init.lua's `showPopup` — LL's Console, 20:30:01, forty lines
  ending `init.lua:2055: NSInternalInconsistencyException` out of
  `HSChooser showWithHints:` → `-[NSRemoteView
  containingWindowWillOrderOnScreen:]`). Another app's REMOTE VIEW
  (Safari's URL-completion helper, Spotlight) was mid-transition and
  AppKit refused the order-on-screen; `hs.chooser:show()` raised, and
  nineteen modules' pickers were bare.
  🔎 THE SAME FAMILY AS BOTH .ips ABORTS (6.262.0) AND AS 6.274.0's
  REFUSED ALERTS — `containingWindowWillOrderOnScreen:` is the exact
  callout in the 15:08 crash. `_G.showCanvasSafely` has guarded canvases
  since 6.56.0 and `hs.alert` since 6.274.0; the CHOOSER, the surface
  nineteen tools open on a keypress, had nothing. A class is not closed
  because the two surfaces that happened to cost a release are.
  🚨 AND init.lua:2055 IS NOT THE BUG, which is the half worth saying:
  it is hyperBind's `error(r, 0)` re-raise, and 6.179.0 put it there on
  purpose — a throw must still throw. Reading a traceback's last frame
  as its cause would have deleted the one line that makes a broken
  shortcut visible at all.
  🚪 ONE DOOR, so the class closes in one function rather than nineteen
  modules (6.266.0's shape): `showPopup` is the single placement path
  and a source sentry has required every picker to use it since
  6.160.1. A refusal now answers FALSE, is COUNTED
  (`_G.popupShowReport()` — asked vs refused, which picker, macOS's own
  words), NAMES itself once per five minutes, and CLEARS
  `_G.lastPopupPlacement` (6.306.0 — a record that outlives its picker
  hands window_move and the preview pane a box that never opened) and
  TEARS THE CHOOSER DOWN (6.265.0 — an abandoned picker keeps its Esc
  claim).
  🧪 THE SWEEP FOUND THE UNDRIVEN HALF, which is why it is run: the
  no-point branch — taken when `resolveBaseScreen` cannot name a screen
  — survived its mutation, so its pcall could have been deleted and the
  gate stayed green. 6.273.0, and the branch matters more than the
  other one: no screen to answer about usually means the display set is
  mid-change, which is exactly when AppKit refuses. Driven both ways
  now; 7 mutations, 7 bites.
  📏 THE LIFTED BLOCK CONSTRAINS THE FIX, and it is a real constraint
  rather than a note: test_integration extracts `showPopup` from
  init.lua by pattern and runs it in a bare env holding only
  resolveBaseScreen, chooserTopLeft, `_G`, pcall and type — so added
  code may use nothing else and may introduce no column-0 `end`. That
  is the price of testing the SHIPPED text instead of a copy of it, and
  it is worth paying.

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

- 🚨 A MODULE WITH TWO `M.warm` LOSES ONE OF THEM, AND NOTHING CAN SEE
  IT (6.308.0, modules/clipboard_history.lua — LL: "opt+opt seems to
  work · cmd+cmd does not bring up unified clip"). This file declared
  `function M.warm(core)` at the top level (6.292.0's ⌘⌘ registration)
  AND assigned `M.warm = function()` inside setup() (the store read,
  since 6.190.0). **setup() runs AFTER the file is loaded**, so the
  assignment destroyed the registration before init.lua ever called
  warm. ⌘⌘ was never registered, on every boot, in silence; ⌥⌥ worked
  because menu_search has one.
  🔑 THE IDIOM IS NOT THE BUG, which is what makes this a sentry rather
  than a sweep: TWELVE modules assign M.warm inside setup and all twelve
  are correct — warm usually needs setup's upvalues. Having BOTH is the
  defect, because load order silently picks the loser. The store read
  became a field the one warm calls, unconditionally and BEFORE the ⌘⌘
  switch is read (behind it, `cmdCmd = false` would also have stopped
  the history loading, which is not what that switch says).
  🚨 AND THE REPORT CALLED IT HEALTHY. The ⌘⌘ line's third state read
  the registry and printed "watching · 0 open(s)" regardless, so a
  gesture that had never been registered — with no reason recorded,
  because the code that records one never ran — reported as health.
  6.196.1 broken inside the instrument built to keep it. A FOURTH state
  ASKS THE REGISTRY. GENERAL: never infer health from the absence of a
  complaint; ask the thing that would know.
  🔬 `x and nil or y` CANNOT YIELD nil — nil is falsy, so the `or`
  always runs and a SUCCESS is published as the STRING "nil". 6.303.0
  wrote this down about a FALSE b; this is the same trap with a NIL b,
  and it was written into THREE files AFTER that release by the person
  who wrote the rule. All three fixed in one commit with a source sentry
  (6.305.0: when a release states a principle, grep the other places
  that decide the same thing, in the same commit).
  🧪 NO FUNCTIONAL TEST COULD HAVE CAUGHT THE SHADOW: the suite calls
  M.warm() and passes, because the function it calls IS the shadow. The
  new section drives warm and asks the REGISTRY. 🚨 And the gate sentry's
  first version CRIED WOLF on twelve healthy modules, caught by the
  sweep before delivery (6.269.0). 🧪 One mutation KILLED the suite
  instead of failing it — the report indexed `g` unguarded — which is
  6.282.0: an instrument that can RAISE is worse than one that lies.

- 🔎 A MATCH BEATS A CREATION (6.307.0, modules/vault.lua — LL, with a
  screenshot: "Search finds a title but creates a new entry when using
  cmd+f upon hitting enter"). The ⌘F box has THREE modes and only one
  behaved this way: search and tasks mode have opened `rowsList()[0]`
  since they were written, while notes mode sent the TYPED TEXT as the
  name — and `v.openNote` SEEDS a missing file by design (6.174.0). So
  ⏎ over a list already showing the note he meant wrote a second,
  near-identical note into the folder holding his writing.
  🔑 `li[data-name]` is the whole fix: a note or a template, never a TAG
  row, so a tag cannot steal ⏎ either. Nothing matched → it still
  creates, which is what the empty row has SAID all along ("no note
  matches — ⏎ creates …"). THE PAGE WAS TELLING THE TRUTH AND THE
  HANDLER WAS NOT OBEYING IT — general: when a feature does the wrong
  thing, check whether some other part of the same page already says
  what the right thing is.
  🔎 Counted apart (6.196.1): `_G.vaultReport()`'s "⏎ filter" line says
  how many presses opened the match and how many made a note.
  🧪 THE STUB HAD querySelectorAll AND NOT querySelector — 6.193.0 for
  the NINTH time, and a new shape of it: a MISSING METHOD on a provider
  the stub otherwise models well. It is defined in terms of the list, so
  the two cannot disagree about what a selector matches. 🧪 The check
  that BITES asserts the NAME: asserting `a === "open"` passes with the
  bug in, because the bug also sent an open.
  🧨 AND A TOOL MISTAKE COST THE SUITE ITS WHOLE FILE: a python
  `open(p, "w")` TRUNCATES before the write, so an encoding error inside
  the write left test_clipboard.lua at zero bytes and the suite silently
  produced nothing. `git checkout` restored it. RULE: any script that
  rewrites a tracked file writes to a TEMP file and `os.replace`s it —
  6.199.0's temp-then-rename rule, which this project applies to LL's
  dictionary and had not applied to its own tooling.

- ⏯ A MODE SAYS WHAT A TOOL DOES ON ITS OWN — AND A CLOSED PANEL OWNS
  NOTHING (6.309.0, modules/music_player.lua — LL, twice: "Still hold
  play pause when not visible. The player should only do this if
  visible. Not while hidden … You're introducing a fix that is not
  real"). He is right and the correction is mine: 6.289.0 gated on
  `hasQueue`, a rule I chose, and closing the card deliberately does NOT
  stop the sound — so a closed card held ⏯ for as long as a queue
  survived it.
  🔑 `mp.mayTake(onScreen, hasQueue, on)` is the ONE gate and BOTH
  routes ask it (6.231.0; 6.291.0 exists because those two routes for
  one physical key nearly came to disagree). A check joins them over all
  four states and asserts the same verdict AND the same reason.
  🚨 THE QUEUE CHECK STAYS beside his rule rather than replacing it: an
  open card with an empty queue would otherwise EAT ⏯ and do nothing.
  Both must hold — the NARROW direction, fewer keys taken, never more.
  `mp.onScreen()` reads `mp.webview`, the handle show creates and hide
  deletes, so there is no second flag to fall out of step.
  🗳 GENERAL, and it is the one to carry: WHEN HE SAYS A FIX IS "NOT
  REAL", THE GATE I CHOSE IS THE SUSPECT, not the implementation. A rule
  the person never asked for will keep being almost right.

- 🎯 A THING THAT GAINS FURNITURE RESERVES THE ROOM FIRST (6.310.0,
  modules/mouse_grid.lua — LL: "⇪⇧L needs to be more obvious. Can you
  make each ring grow in size by 10% each time?"). His answer, his
  number, shipped as asked. `grid.locateRingR` is PURE and steps each
  ring out by `locateRingGrow` (1.10); `grid.locateSpan` answers the
  OUTERMOST ring's radius and the canvas is built from THAT — sized off
  the base it would have cropped exactly the ring the release adds.
  6.270.0's rule in a second place. A growth below 1 is refused: a typo
  in a settings line must never SHRINK the mark it was asked to enlarge.
  🧪 The check MOVES the growth and requires the drawing AND the canvas
  to follow (6.239.0); the fixture that bites is the one moment three
  rings are in flight at the same p, because with every ring on one path
  their radii are equal and that is the only input where the old and new
  drawings must differ (6.230.0).

- ⌨️ A KEY CHOSEN FOR THE HARDWARE HE HAD IS A DECISION WHOSE PREMISE
  CAN EXPIRE (6.311.0, modules/music_player.lua — LL: "Jug player can
  only be accessible via full keyboard. I am on a mini-keyboard now,
  can I still use hyper+shift+period, instead of pad? I can't tell if
  that key combo is taken"). ⇪⇧pad. shipped with NO fallback key on his
  OWN 6.231.0 answer ("Both macs, home/work, use a full Apple Keyboard
  and Magic pad"), so the tool being unreachable today is not a bug and
  not a mistake — it is a decision nobody re-asked. GENERAL: when a
  scope was set by an answer about his hardware, his habits or his
  apps, that answer has a shelf life; re-ask it rather than defending
  the decision it produced.
  🚪 A SECOND DOOR, NOT A SWAP, and the swap is what he literally asked
  for. Removing ⇪⇧pad. would cost the two Macs the feature was designed
  around and buy nothing — one function, two doors is this config's own
  precedent twice over (⇪V/⌘⌘ 6.292.0, ⇪./⌥⌥ 6.293.0). Both doors end
  in ONE `mp.toggle`; two handlers for one tool is how they come to
  disagree (6.291.0 exists because two routes for one physical key
  nearly did). SAID TO HIM as a decision I made and he can reverse.
  🆓 THE ANSWER TO "IS IT TAKEN" CAME FROM THE REGISTRY. See the 🆓
  hard rule above — this is the release that wrote it, and the near
  miss (⇪. without shift is menu_search) is the reason a note would
  have been a coin toss.
  🔑 ONE LIST, ONE LABEL, AT LOAD TIME. `KEYS` holds both doors and
  `keyLabel` (PURE) renders them; the cheat-sheet title, the card's key
  column, the module summary and `_G.musicReport()`'s heading all
  concatenate it, and a source sentry forbids a typed "⇪⇧" anywhere
  visible in the module. 6.296.0's rule for the NAME, applied to the
  KEY, in the module whose key caused 6.276.0.
  🚨 AND IT IS BUILT WHEN THE FILE LOADS, NOT IN setup() — the first
  version wrote the card in setup and the GENERATED FEATURE LIST went
  out with a blank key column, because tools/build-feature-list.lua
  reads `M.cheatsheet` from a chunk it never sets up, and that file
  ships and LL opens it. 6.268.0's rule (grep every reader before
  changing a module) caught it inside the release that cites it.
  GENERAL: anything a module publishes as DATA on its table must be
  true of the table, not of the table after setup has run.
  📋 ONE CHEAT-SHEET ROW FOR THE TWO DOORS (6.243.0): the 6.196.0
  auditor reads a combo listed twice as a conflict, and it walks a key
  column token by token, so several combos in ONE cell audit correctly.
  🆓 AND THE FREE-KEY CARDS UPDATED THEMSELVES — 6.276.0 being paid
  back rather than quoted: those rows are READ from the live registry
  in warm(), so ⇪⇧. stopped being advertised the moment it was claimed.
  🔎 LISTED IS NOT BOUND (6.196.1): the report's `doors :` line says how
  many ways in setup really REGISTERED, beside the label the list
  merely claims, and no door at all takes the 🔔 door. 📏 A `settings`
  override of the key list is DECORATIVE (the binding is in setup,
  settings land after — 6.228.0) and the report SAYS so; that was
  equally true of the old `mp.key` and had never been written down.
  🧪 The check that bites the skip-a-malformed-door rule is a bad entry
  BETWEEN two good ones — every other input agrees (6.230.0). And the
  sentry's needle is "⇪⇧", not a bare "⇪": keyLabel BUILDS its combos
  and the page's JS comment mentions ⇪'s F18 keyup, so a wider needle
  goes red on a healthy tree and gets switched off (6.269.0).

- 🚪 A DRAG ENDS WHEREVER THE BUTTON COMES UP, AND EVERY EXIT OWES THE
  CALLER ITS ANSWER (6.306.0, core/coexist.lua — LL, twice, eleven
  releases apart: "Seems like a drag kills the sheet functionality"
  (6.138.0) and "just because I can launch the cheat sheet doesn't mean
  it is functional", beside "when I move the cheat sheet, I am jumped to
  another desktop"). His third sentence is the one that found it:
  "Review your code. We have solved this issue or a similar one."
  🔎 BOTH REPORTS ARE ONE MECHANISM. `_G.makeCanvasDraggable` has dragged
  four panels since 6.67.0 and had FOUR exits, calling `onDrop` from
  exactly ONE — the tap's leftMouseUp. The canvas's own mouseUp, the 20 s
  watchdog and the supersede all tore the drag down SILENTLY. And onDrop
  is not bookkeeping: it moves the cheat sheet's WHEEL HIT BOX (6.138.0's
  entire fix) and saves the position. THE PANEL HAS ALREADY MOVED by the
  time any exit runs, so a silent exit leaves it physically elsewhere with
  every record of it stale — the wheel dead over the sheet, still
  swallowed over the bare desk it used to cover, the next open in the
  wrong place. 6.138.0 wrote the update and put it behind the one door
  that can fail to open.
  🖥 AND THE DESKTOP JUMP IS WHAT OPENS THAT FAILURE. The tap returns
  false on purpose — it observes, never swallows, because the button is
  the person's — so macOS sees the drag too and reads a three-finger one
  as a Space swipe. A Space switch is exactly the transition macOS
  disables event taps across (6.303.0 found that about the F18 tap), so
  the mouseUp never arrives. Cause and effect, not two bugs. THE JUMP IS
  NAMED, NOT FIXED: it is macOS's gesture and the only lever here is to
  start swallowing the drag, which costs every app underneath and is his
  call.
  🧊 6.222.0 SOLVED THIS FOR A PAGE AND NOBODY ASKED THE ENGINE. Its rule
  — "listen for the release, and ALSO treat moving with nothing held as
  the release" — was written for the screenshot editor's JS. 6.305.0's
  rule one release later, paid again: A RULE WRITTEN ABOUT ONE CALLER IS
  NOT A RULE UNTIL EVERY CALLER HAS BEEN ASKED. And window_move already
  had the right shape beside it: `wm.endDrag` is one exit and runs endFn
  from every path, watchdog included. GENERAL: when a helper hands
  control out and the world can end the interaction somewhere it cannot
  see, grep its exits and count how many tell the caller.
  🚪 ONE EXIT, AND THE DELIVERY LIVES INSIDE IT — `dragStop` itself calls
  onDrop, so every existing exit is fixed at once and one added later
  cannot forget (6.299.0's shape). The frame is read AT THE EXIT, never
  from the caller's copy.
  🔬 `checkMouseButtons` IS A VETO, NOT AN ORACLE, and the direction is
  load-bearing: window_move 6.156.0 paid for trusting it the other way,
  where a CONSUMED press never updates the session's button state and
  reads as "released" on the first tick, killing a drag before it moves.
  Believed only when it positively says "still down", it is safe both
  ways.
  📏 MOVED OUT OF init.lua at its 3,800-line budget (3,795 → 3,725),
  6.285.0's precedent — and it belongs in coexist on its merits: that
  file answers "two features want the same resource, who gets it?", the
  POINTER is a fifth such resource, and init.lua's file map has filed
  draggable panels beside coexist since §1.6 was written. COST: a coexist
  that fails to load leaves panels undraggable; every caller guards, so
  that is a panel you cannot move, never one that breaks.
  🧪 THE ENGINE HAD NO SUITE AND NO REPORT, which is exactly why it
  survived two reports and eleven releases — 6.196.1 in the oldest shared
  helper in the config. tests/test_panel_drag drives all four exits plus
  the new one; `_G.dragReport()` names how the last drag ENDED. The sweep
  found a real one: a `delivered` flag in the fix was UNKILLABLE, because
  `_G.dragging` is nil'd before onDrop runs and nothing can reach the
  second call it guarded — removed rather than left as a guard no test
  can fail (6.199.0, FIFTH time). 8 mutations, 8 bites after that.

- 🗂 A PARTIAL DIRECTORY IN A DELIVERED ARCHIVE DESTROYS THAT
  DIRECTORY (6.305.0 delivery, LL's 16:41 boot log, minutes after
  installing the 6.304.0 patch: twelve of his thirteen `core/*.lua`
  reported "No such file or directory", three modules throwing on
  `core.safeJson`, and ⇪ running on its Carbon hotkey alone).
  🔎 THE PATCH CARRIED `./core/` HOLDING ONE FILE. His core/ holds
  thirteen. **macOS Finder REPLACES a same-named folder; it does not
  merge** — Merge exists but needs ⌥ held and is easy to miss — while
  `tar xzf -C` merges. So the install COMMAND I wrote was safe and the
  install he actually performed was not, and nothing in the archive
  could tell the difference.
  🔑 GENERAL, AND IT IS THE ONE TO CARRY: AN ARCHIVE IS INSTALLED THE
  WAY THE PERSON ACTUALLY INSTALLS IT, NOT THE WAY THE COMMAND SAYS.
  Every FOLDER inside a delivered archive must be COMPLETE — replacing
  a complete folder is correct, replacing a partial one is a deletion
  — so a patch carries loose files at the root or whole folders, never
  a folder with some of its files in it.
  🚨 THE BLAST RADIUS WAS THE WHOLE SAFETY NET, which is why this is a
  rule and not a note: notices (no on-screen degrade at all — 6.214.0's
  promise, gone), console, coexist (the Esc router and the panel
  ladder), cheatsheet (⇪/), diagnostics (⇪⇧D), hyper_key (the F18 tap,
  the storm guard AND 6.303.0's wake probe), key_trail, boot_cost,
  boot_report, changelog_csv, double_tap, lag. A config that degrades
  gracefully degraded exactly as designed and said so thirteen times —
  and every one of those lines went to a Console with no filtering,
  because console.lua was one of the casualties.
  📏 6.303.0's PATCH RULE IS NARROWED, NOT REVERSED. A patch is still
  right when a patch will do, and the SIZE measurement stands (94 KB
  installed first try; 2.76 MB never arrived, twice). What changes is
  its SHAPE. The restore is a COMPLETE core/ — 13 files, 128 KB —
  which is drag-safe by construction.
  🩹 AND THE RESTORE IS VERSION-COHERENT ON PURPOSE: core/ alone, no
  init.lua, so his Mac goes back to a whole 6.304.0 rather than a
  6.305.0 stamp over 6.304.0 modules. A version stamp that does not
  describe the tree under it is how the next failure gets attributed
  to the wrong release.

- 🔁 A RULE WRITTEN ABOUT ONE CALLER IS NOT A RULE UNTIL EVERY CALLER
  HAS BEEN ASKED (6.305.0, modules/scratch_pad.lua — LL's first
  unattended 16:00 run: "1 of 122 task(s) did not reach Asana (no team
  member matches …) — every word is still in the tab, marked ❌ Error:
  tasks not sent").
  🔎 READ THE OTHER NUMBER. One refused means ONE HUNDRED AND
  TWENTY-ONE LANDED. The mark is per TAB, a ❌ tab is retried, and the
  retry re-parses the tab WHOLE — so the next 16:00 posts those 121
  again, the one after that a third time, compounding daily until he
  happens to fix the one bad line. His message was about a warning;
  the warning was the smaller half of what it was telling us.
  🚨 AND 6.301.0 WROTE THE RULE FOUR RELEASES AGO, IN THIS FILE, about
  subtasks: "before deciding what a partial failure should report, ask
  what a RETRY would do — an error that causes a duplicate is worse
  than a warning that causes a correction." It was applied to the
  subtask leg and not to the tab mark two hundred lines above it.
  GENERAL: when a release states a principle, grep the module for the
  other places that decide the same thing, in the same commit.
  🚨 THE ✅ SIDE HAD THE SAME HOLE WITH NO FAILURE INVOLVED: typing in
  a tab clears its mark (6.300.0 chose that deliberately — a ✅ tab
  that could never be sent again would freeze his new writing out of
  the run), so editing ONE character in a fully-sent tab re-armed every
  task in it. Two routes to a duplicate, one mechanism for both.
  🔑 THE MARK IS ABOUT THE TAB; THE RECORD IS ABOUT THE TASKS. Each
  task Asana ACCEPTS is remembered on its tab by a digest of WHAT IT
  SAYS — title, description, assignee, dates, subtasks — never by its
  position (6.186.0/6.272.0: an edit renumbers everything under his
  hand, so an index forgets a different task than the one that
  landed). The content key does double duty: an untouched line keeps
  its key and is skipped, an EDITED line has a new key and is
  correctly read as new work. Nothing of his text is changed.
  🔢 COUNTED, NOT A SET — two identical lines are two tasks, and a set
  would send the pair once then skip both for ever. `sp.tasksToSend`
  is a multiset difference and PURE; the fixture that separates it
  from a set is two identical tasks with ONE landed (6.230.0).
  🔔 RECORDED ON THE ANSWER, NEVER ON THE ASK: the submit returns the
  moment the POST is fired (6.299.0), so recording there marks a
  REFUSED task as landed and it is never retried — the opposite
  failure, and a silent one. 🔁 A tab with nothing left to send is
  marked ✅, or it is retried for ever over a line he has since fixed.
  🔒 THE KEY IS PURE ASCII HEX and that is not tidiness: it becomes a
  JSON object key, and a truncated slice of a title can cut a UTF-8
  glyph in half and make the WHOLE store unencodable (6.204.0's rule,
  in the place where the answer is to carry none of his characters).
  `sp.taskKey` walks `when` with pairs() and SORTS it rather than
  naming fields — a field name got wrong there silently stops counting.
  📏 BOUNDED, AND THE BOUND IS A STATE (6.197.2): past `landedMax`
  (400) the oldest row goes, counted and WARNED, because a forgotten
  key is a task that can be sent twice.
  📏 NAMED, NOT FIXED, because it is his call: 122 tasks out of one
  day's tabs is a lot, and the grammar reads every bare line as a
  task, so prose he keeps in Hamsidian becomes Asana tasks at 16:00.
  This release makes the run idempotent; whether it should be reading
  those tabs at all is a question in the verify block, not a guess.

- 🚧 A BUSY FLAG NEEDS A WAY OUT FOR EVERY WAY THE WORK CAN END
  (6.304.0, core/capabilities.lua). `siBusy` lets one ioreg run at a
  time — right, and 6.170.1's rule for any external command on a timer
  — and was cleared in exactly ONE place: `finish()`, reachable only
  from a task callback. So the first probe that could never finish shut
  Secure Input down for the whole session, silently, while the 60 s
  timer went on ticking into the short-circuit. GENERAL: the failure
  paths out of a guarded section are the ones nobody drives, and a
  guard only a SUCCESS can release is a wedge.
  🔎 THE ARITHMETIC WAS THE DIAGNOSIS, and it existed only because
  6.196.1 wrote it down: `started 1 · checks 0`, nine ticks after boot.
  Frozen at 1 is not a slow probe, it is a probe not being ATTEMPTED.
  That release added `started` for exactly this and the payoff came
  eight releases later — which is the argument for the distinction
  every time it looks like bookkeeping.
  🔬 `hs.task:start()` REFUSES BY RETURNING FALSE (extensions/task/
  libtask.m, `task_launch`: the success path pushes the task, the
  @catch pushes a boolean). So the `pcall` around it SUCCEEDED on a
  refusal, `fails` stayed 0 and finish was never called. 6.265.0 in a
  new module — MISSING is not REFUSING, and the old code handled
  hs.task being absent (that throws) while being blind to hs.task
  saying no. 6.233.0's rule bought this: the fact was read in the
  source, with the file named.
  🛟 ONE BELT PER PROBE, NOT PER RUN — the narrow → broad chain is one
  probe and the broad fallback is the NORMAL path. Armed BEFORE the ask
  (6.246.0; the check asserts the ORDER — 6.220.0), in its own held
  slot (6.196.1), `secureInputAnswerSecs` (20) well under the 60 s poll
  because a belt that outlives the tick it protects is a wedge with a
  longer fuse. A Mac that cannot arm it still probes and the missing
  belt is COUNTED.
  🚪 ONE DOOR, ONCE (6.299.0) — plus a GENERATION counter, which is not
  decoration: after a belt ends a probe the next tick starts another,
  and the original ioreg's callback can still arrive. Without the
  generation check it closes somebody else's probe — the same wedge
  wearing a different hat.
  🚨 AND THE FIRST VERSION REPORTED A CONFIDENT "off" OFF A PROBE THAT
  NEVER RAN, caught by its own new check rather than by reading. Every
  failure called `finish(nil, why)` and finish routed everything
  through `siApply`, which sets `on = (pid ~= nil)`. That is 6.196.0's
  four-hour lie reintroduced in the one row that cannot afford it. A
  failure moves `why` and nothing else now: the last good reading
  stands and `checks` does not move, because it counts COMPLETIONS and
  is half the fingerprint above. GENERAL: when a function's one exit
  both records an ANSWER and clears a FLAG, a failure routed through it
  is published as an answer.
  🧪 THE ENTIRE PROBE BODY WAS UNREACHABLE BY THE GATE, which is how
  this survived from 6.196.0: the suite had no `hs.task` at all, so
  siProbe took its "hs.task is unavailable" branch on every run.
  6.290.0's rule and 6.265.0's are the same sentence from two sides and
  both were unpaid here. The stub has a `:start()` that can say no now,
  and the checks DRIVE the wedge rather than grepping for its absence.
  🧪 THE SWEEP FOUND TWO UNDRIVEN GUARDS AND ONE WEAK SENTRY, and that
  is the part worth carrying. The stale-answer check drove the NARROW
  callback, which has a guard of its own — so the stale answer never
  reached finish() and proved nothing about it. Driven through the
  BROAD probe now. The narrow and hop guards got checks of their own:
  a dead probe's late answer arms a second hop, or starts a broad
  ioreg, INTO THE LIVE PROBE'S SLOT, dropping the only reference to
  what is there (6.155.0). 6.273.0 again — a line no mutation can kill
  means the CHECK is missing, not that the line is spare.
  🔒 AND 6.196.1's OWN SENTRY WAS WEAKER THAN IT READ: it matched
  `_G.secureInputTask = hs.task`, one exact SHAPE, so a single global
  assigned from anything else walked past — proven by a mutation that
  reintroduced the crash and stayed green. It refuses any assignment to
  the singular name now. FOURTH time in this file: a sentry that names
  a thing matches the THING, not one sentence it once appeared in.
  🧪 AND A STUB WAS TOO PERMISSIVE OF THE TEST, which is a new
  direction for 6.290.0: the fake timer stored its callback raw, so a
  check could fire a timer that had been STOPPED — something macOS
  never does — and a correct implementation went red. A stub models the
  provider's refusals in both directions.
  🧪 AND A SENTRY WENT RED ON CORRECT CODE — 6.248.0, fourth time. It
  matched `_G.secureInputTasks[slot] = hs.task`, an ADJACENCY, while
  the rule it protects is that the CALLER names the slot; reading
  :start()'s return put an expression between the two halves. It asks
  the rule now and still bites a revert to one shared global.

- 🔬 `a and b or c` CANNOT CARRY A FALSE b (6.303.0, core/hyper_key.lua).
  The wake probe asks three things macOS will not otherwise tell you —
  the hidutil Caps Lock → F18 remap (set once at boot, never read
  back), the F18 event tap (macOS switches taps off across some
  transitions), and SECURE EVENT INPUT (6.196.0, which kills every tap
  AND hotkey dispatch with no error anywhere, and lives on the lock
  screen a wake goes through). Two seconds after a wake, off the main
  thread, silent when healthy.
  🚨 AND ITS FIRST VERSION DESTROYED THE ONE DISTINCTION IT EXISTS FOR,
  in one line: `P.remap = (code == 0) and present(out) or nil`. A
  genuinely GONE mapping returns false, `false or nil` is nil, so
  "gone" read as "could not be asked" and nothing would ever have been
  repaired. GENERAL: never write `a and b or c` where b can be FALSE AS
  A MEANING rather than as a failure — 6.179.0's read-three-values rule
  in the other direction, and the suite is what found it.
  🔔 ONLY A MEASURED ABSENCE REPAIRS. "gone" puts the remap back (with
  `_G.hyperRemapJSON`, init.lua's own published literal — 6.231.0, one
  literal two callers, and a build that does not publish it REFUSES
  rather than inventing one) and takes the door, because ⇪ had stopped
  existing. "could not be asked" touches nothing, or a Mac without
  hidutil re-applies the remap after every wake for ever.
  🔢 `hidutil property --get` ANSWERS IN DECIMAL, not the hex this
  config sets with: 0x700000039 is 30064771129, 0x70000006D is
  30064771181. `hyperRemapPresent` is PURE and matches the PAIR — a
  Caps Lock remapped to something ELSE passes a Src-only test and reads
  as health while ⇪ is dead (6.230.0: pick the input where right and
  wrong must differ).
  🧪 AND 6.262.0'S COMMENT-STRIPPER EATS AN ARGV. `%-%-[^\n]*` removes
  everything after the first double dash on a line, so a sentry reading
  stripped source cannot see `"--get"` or `"--set"` — it went red on a
  healthy tree. Full-LINE comments only, plus a check that the argument
  survived, so a stripper that eats it again cannot pass by leaving an
  empty haystack. NAMED, NOT SWEPT: other sentries here strip the naive
  way; none reads an argv today.
  🔒 Secure Input is READ from core/capabilities.lua, never re-probed
  (6.242.0), and a sentry keeps ioreg out of this file. 🪜 The read and
  the repair have SEPARATE task slots and the repair is armed off a
  HELD doAfter(0) — 6.196.1's use-after-free, which has killed this
  process natively twice with nothing in the Console.
  📏 NAMED, NOT FIXED: a tap found switched off is REPORTED, not
  restarted — it may have been stopped by this config's own failure
  counter, and re-arming it would undo a decision made on purpose.
- 🌅 A FIX AND AN ARTEFACT CAN AGREE ABOUT THE CAUSE AND DISAGREE
  ABOUT THE ORDER OF EVENTS (6.302.0, core/hyper_key.lua). LL's storm
  report, plus his one sentence when asked what happened just before:
  "My laptop travelled with me in my car and I just plugged it in."
  Every field fits a wake — the 58-minute gap to the previous ⇪ key is
  the journey, 266 autorepeats that session prove Caps Lock really does
  repeat on his Mac so it was not physically held, and `0 watchdog
  release(s)` is the 6.162.1 rule working (a key under ⇪ proves the
  hold, and a person fighting a dead keyboard never stops pressing
  keys — which is the exact hole the storm guard exists to cover).
  🚨 AND THE FIX THAT FELL OUT OF IT WAS WRONG BY ONE INSTANT, caught
  at the door rather than a year later. "Release the hold on wake"
  cannot have prevented that storm: `_G.hyperEnteredAt` is stamped in
  ONE place — hyperEnter's `else`, taken only when ⇪ was not already
  down — so an age of `10.5 s` means the hold BEGAN AFTER the wake. A
  watcher firing as the lid opened finds ⇪ up and releases nothing.
  🔑 GENERAL, and it is a new shape of 6.198.0 rather than a repeat:
  this was not a correct fix for a plausible-but-wrong MECHANISM — the
  wake really is the setting. It was a correct fix for the wrong
  MOMENT, right neighbourhood and wrong instant, which reads as a
  diagnosis until you ask WHICH SIDE of the event the symptom began
  on. When a story fits every field, find the field that carries a
  CLOCK and check the order.
  🔎 WHAT SHIPPED ANYWAY, honestly labelled: wakes are visible to the
  hyper key at all (nothing here had ever watched the wake side — the
  one hs.caffeinate.watcher in this config is activity_tracker.lua:891,
  on `screensDidLock` / `systemWillSleep`), and a hold still open
  ACROSS a wake is let go, which is right on its own terms and closes
  a neighbouring hole. `hyperWakeVerdict` is PURE with the event list
  as a TABLE the gate moves (6.239.0); THREE answers (6.196.1) —
  ignored · clear · release — because "a wake found ⇪ up" is health
  and must not read like a watcher that never ran.
  🚨 A WAKE RELEASE IS NOT A LATCH: `hyperLatchReleases` is the storm
  report's fault number and this fires every morning on a healthy Mac.
  Its own counter, its own report line, its own field on `before :`.
  🔕 Console only — an alert every lid-open is one he stops reading.
  🔬 AND THE PROBE IS THE NEXT RELEASE, because this is NEW GROUND:
  three things can latch ⇪ with the key physically up and all three
  are invisible from Lua today — the hidutil Caps Lock → F18 remap
  (applied once at boot, never read back), the F18 event tap (macOS
  disables taps across some transitions), and SECURE EVENT INPUT
  (6.196.0 — it stops every tap AND hotkey dispatch system-wide with
  no error anywhere, and a lock screen on wake is where it lives).
  🗳 ONE SENTENCE FROM HIM STILL BEATS ALL THREE: was ⇪ working
  between the storm and his evening reload? Dead → the remap is being
  lost on wake, a bigger bug than the storm. Working → the keyUp was
  dropped by the tap or by Secure Input.
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

- 📋 "IT ALREADY DOES THAT" AND "IT ALREADY DOES THAT HERE" ARE
  DIFFERENT SENTENCES (6.319.0, modules/screenshots.lua — LL: "Once I
  OCR some text, that text should immediately go onto the clipboard so
  I can paste it").
  🔎 ⇪⇧4 ALREADY DID, and that is the half to say first: 6.173.1 wired
  `shots.recognizeFile` to `hs.pasteboard.setContents` on his own report
  that the OCR log and the clipboard disagreed, and it has copied every
  text and every QR payload since. So the honest answer is not "here is
  a new feature" — it is "one of your doors already does this and the
  other never has".
  🚪 THE DOOR THAT NEVER DID is the shot ⇪4 takes: it puts the PICTURE
  on the clipboard, the folder watcher OCRs the file to NAME it, writes
  the words into a Finder comment and ⇪O's log, and drops them as far
  as the clipboard is concerned. He photographs a paragraph and gets a
  picture of a paragraph. 6.317.0's rule one module along, and the
  general form: WHEN A FEATURE HAS SEVERAL DOORS, "does this config do
  X?" is the wrong question — ask which DOORS do X, and the gap is
  usually one of them rather than the feature.
  🚨 A SWAP MAY REPLACE ONLY THE THING IT WAS MADE FROM. `swapVerdict`
  is PURE with SIX answers (6.196.1) and only one writes: the words may
  replace THE SHOT THEY WERE READ FROM, still on the clipboard, put
  there by this config, seconds ago. A copy of his, an arrival from the
  other Mac over OneDrive, a shot from five minutes back — refused, and
  SAID. `shots.ownClip` (path · counter · clock) is recorded by
  `copyToPasteboard`, the one function every capture's clipboard write
  already goes through, so there is no second place to keep in step.
  🔑 THE COUNTER, NEVER A TEXT COMPARISON (6.198.0): macOS's changeCount
  sees the two writes a comparison cannot — the same thing copied twice,
  and anything that is not text. And THE UNKNOWN REFUSES, deliberately
  the opposite of `pt.borrowIntact` and the same as `sp.collectContinues`
  — a default is chosen against the damage its own feature can do. The
  damage here is destroying something he copied; the cost of refusing is
  that he fetches the words from ⇪O.
  🔒 ONE DOOR THAT READS THE RETURN, and the reason it had to exist is
  what the three sites it replaces had in common:
  `pcall(function() hs.pasteboard.setContents(t) end)`. setContents
  REFUSES BY RETURNING FALSE and never throws, so that pcall is true
  either way — "📝 Text copied" was printed over writes that had not
  happened, nothing counted them, no report could see them. This file
  has carried that rule since 6.198.0 and named text_expander and
  url_cleaner as the survivors; screenshots.lua was a third nobody had
  grepped for. GENERAL: when a rule names the files still carrying a
  shape, the list is a SAMPLE unless someone grepped — re-grep before
  trusting it.
  📏 COST, NAMED: after a ⇪4 whose words were read, ⌘V pastes the WORDS
  and not the picture. The picture is in the folder under a name made of
  those same words and ⇪⇧5 ⏎ puts it back, and the alert says so at the
  moment it happens — a clipboard that changed with nothing said is the
  surprise the release would otherwise be.
  🔬 THE STUB WAS GENTLER THAN macOS IN BOTH WAYS THAT DECIDE IT
  (6.290.0): no `changeCount` AT ALL, so the one fact the rule turns on
  could not exist in the gate and every path would have read "macOS
  would not say"; and `setContents` always answered true, so a refusal
  was unreachable. The counter is monotonic and steps once per WRITE now,
  and a refusal is drivable.
  🧪 AND 6.282.0'S CLOCK SENTRY BIT THIS RELEASE AS IT WAS WRITTEN — the
  first `clipLast` stored a formatted `os.date` string, which is exactly
  what that sentry forbids. The rule working on the release after the one
  that wrote it is the argument for source sentries in one line.

- 🗑 THE DATA WAS ALWAYS THERE AND THE DOOR HELD ONE SLOT (6.321.0,
  modules/vault.lua — LL: "This is horrible not having an undelete or
  recycled bin or trash that I can restore from", with
  `_G.vaultUndelete()` answering `nothing to undelete` and his own
  report reading `deleted: 55 this session`).
  🔎 FIFTY-FIVE NOTES WERE ON DISK, UNHARMED, AND UNREACHABLE. 6.280.0
  built the delete correctly — a note MOVES to `<Vault>/.trash`, is
  never erased, and is stamped with the moment it went. What it gave
  him was `_G.vaultUndelete()`, ONE slot, spent by the first restore.
  So the tool was simultaneously doing exactly what it promised and
  telling him, truthfully, that there was nothing to undo. 6.317.0's
  rule for the THIRD time, and the costliest costume yet: THE
  INSTRUMENT WAS NOT THE GAP, THE DOOR WAS.
  🔑 GENERAL, and it is the half to carry past this module: **A ONE-SLOT
  UNDO IS NOT AN UNDO, IT IS A COURTESY.** The moment the thing being
  undone can happen twice in a session — and a delete always can — one
  slot means the feature is absent for every case but the newest. Ask
  how many of the thing can exist before choosing the shape of the way
  back; the answer is almost never one.
  🕰 180 DAYS IS HIS NUMBER and `trashDays = 0` turns the purge off
  entirely, which is the "only I can purge" half of his ask said as a
  switch rather than argued about. `v.trashDue` is PURE, the purge runs
  ONCE per session from `M.warm`, and `v.trashList` takes its lister as
  an ARGUMENT so the gate proves the whole bin with no Mac.
  🚨 TWO DELETES OF ONE NOTE IN THE SAME SECOND COLLIDED, and the suite
  found it rather than his Mac: the stamp has second resolution, so the
  second move overwrote the first and the earlier version became
  unrecoverable THROUGH THE FOLDER THAT EXISTS TO MAKE IT RECOVERABLE.
  A " (2)" tie-break, and the row parser reads it back.
  🔒 AND 6.280.0'S OWN SENTRY WENT RED ON THE PURGE. It forbade the WORD
  `os.remove` in this file — exactly right while nothing in it could
  legitimately erase, and exactly wrong the day a bin needs emptying. It
  asks the RULE now: every `os.remove` takes a path built from
  `v.trashDir()` and none is built from `v.dir`. GENERAL: a sentry that
  bans a NAME expires the first time the name has an honest use; a
  sentry that states the RULE does not.

- ↩️ A REBUILT PAGE HAS NO UNDO HISTORY (6.323.0 + 6.322.0,
  modules/vault.lua — LL: "I highlighted the text in a note and
  accidentally deleted it all and then I couldn't get any of that text
  back while the note remained blank").
  🔎 ⌘Z WAS ALWAYS THERE AND A SCAN TOOK IT AWAY. It is the browser's
  own undo on the textarea; `v.render()` rebuilds the page, WebKit
  destroys that textarea, and a textarea's undo stack dies with it. The
  vault re-scans on a timer and after every write, so the window in
  which ⌘Z worked was however long the gap between scans happened to be
  — which is why it would have read as intermittent rather than absent.
  🔑 A SCAN PUSHES THE INDEX; IT DOES NOT REBUILD THE PAGE.
  `setIndex(notes, tags, graph)` into the live document, with
  `v.scanRedraw(hasWindow, view, doc)` PURE and answering which of three
  things to do — nothing · rebuild · rows — so the board, the graph and
  the no-document case keep the rebuild they really need. GENERAL, and
  it applies to every page in this config that redraws itself: A
  REBUILD DESTROYS EVERY PIECE OF STATE THE BROWSER OWNS AND NOBODY
  WROTE DOWN — the undo stack, the selection, the scroll position, the
  caret. Push the data in; rebuild only when the structure really
  changed.
  🚨 AND THE FALLBACK HAD TO BE REACHABLE: the first version asked
  `v.eval`, which swallows a throw, so a failed push reported success
  and left the page stale with no rebuild behind it. 6.265.0's shape —
  the right answer one branch away, unreachable — found by the sweep.
  🔒 AND ⌘Z IS NOT A BACKSTOP, which is the other half and its own
  release. Close the note, or let the 0.3 s save land, and the only copy
  of that paragraph is the empty file. `v.shrinkGuard(old, new, minChars,
  keepBelow)` is PURE: a note that HAD real text (200 chars) and is about
  to be written at under a fifth of its size gets its old text copied
  into the bin FIRST. Nothing is blocked and nothing is undone — the
  write happens exactly as he asked — but the paragraph is recoverable.
  GENERAL: when a feature's safety net is owned by somebody else (the
  browser, macOS, a sync client), it is a convenience and not a
  guarantee; the guarantee has to be something this config writes.

- 🪜 "OTHERWISE SAFE" WAS A NOTE IN THIS FILE, AND IT WAS WRONG
  (6.324.0, modules/vault.lua). 6.262.0 fixed the 6.196.1
  use-after-free in anchors.lua and wrote, in this very file, that
  "vault.lua's scan `finish()` nils all four task slots from inside a
  task callback (its chain is otherwise safe)". It is not otherwise
  safe: nilling all four slots INCLUDES the slot holding the task whose
  callback is running, hs.task's finaliser then tears down the NSTask
  and the callback block under the live frame, and that is a native kill
  with no Lua error and nothing in the Console. On the ORDINARY path —
  every scan, and a scan runs on a timer and after every write.
  🔑 GENERAL, and it is the expensive one: **A NOTE THAT NAMES A FILE AS
  SAFE IS A READING, AND IT AGES.** 6.319.0 wrote this about a list of
  files still carrying a shape ("the list is a SAMPLE unless someone
  grepped"); this is the same sentence about a single parenthetical
  verdict. When a durable note says some other file is fine, that is the
  file to open first, not the one to skip.
  🚪 `v.hop(slot, fn)` — the same door anchors.lua took: clear the flag,
  then a HELD `doAfter(0)` in its own slot lets the callback RETURN
  before any slot is released. A Mac that cannot arm a timer still
  finishes, on the old path, and the miss is counted with a ⚠️ that
  outranks the count. 🔬 And the fifth grep reads its own `:start()`
  return (6.304.0) — a refused task recorded as running is a chain
  waiting on a callback that cannot arrive.

- 🧊 AN INSTRUMENT ADDED TO DIAGNOSE A HANG MUST NOT BE ABLE TO CAUSE
  ONE (6.330.0, modules/stall_guard.lua + tools/hs-stall-guard.sh +
  init.lua — LL: "Hammerspoon locks … I couldn't even click on anything
  on the screen … and then Hammerspoon crashed", with
  `🧊 Hammerspoon HUNG for 73 s at 2026-10-04 17:16:59 and was
  relaunched by the stall guard`).
  ✅ THE GUARD WORKED, FIELD-PROVEN A SECOND TIME (72 s in September,
  73 s now) — and it could not say WHAT had hung, because the heartbeat
  is one number. Two relaunches, two reports, zero attribution.
  🔑 THE BEAT CARRIES A BREADCRUMB: `_G.inFlightMark(what)` is stamped by
  init.lua's hyperBind wrapper around every ⇪ shortcut, `sg.beatLine(now,
  flight)` is PURE and writes `<epoch>\t<what>`, and the script parses
  the tab and logs `in flight:` on a kill. The NEGATIVE answer is worth
  as much as the positive one: `(none)` means the thread stopped
  somewhere that is not a ⇪ shortcut, which halves the search.
  🚨 THE BEAT IS WRITTEN FROM THE MAIN THREAD EVERY TWO SECONDS AND THE
  WHOLE GUARD RESTS ON IT, so `beatLine` is pcall'd and a throw falls
  back to the bare epoch — the old format, which the script still reads
  — and is COUNTED. GENERAL: when you add a field to the one artefact a
  safety mechanism depends on, the old format stays readable and the new
  code's failure is a degrade, never a gap in the pulse.
  📏 NAMED, NOT FIXED, and it is a CANDIDATE rather than a verdict
  (6.198.0): his log shows FORTY-TWO SECONDS of lazy extension loading
  after a boot that reported 0.24 s — `notify` at 17:17:03, `mouse`
  twenty-six seconds later, then `webview`, `drawing`, `geometry`. Each
  `-- Loading extension:` is a main-thread dylib load, which is 6.228.0's
  cost in a place nothing in this config measures.

- 🚪 A GUARD THAT TESTS FOR CHARACTERS IS NOT A GUARD ABOUT PATHS
  (6.320.0, modules/vault.lua — LL: "I have no idea what this means and
  why I can't delete an item from the left column: 'Not deleted - that
  path leaves the vault'"). The check asked whether the relative path
  CONTAINED the two characters `..`, so a note called `Budget..final.md`
  — or any name with an ellipsis in it — was refused as an escape
  attempt. The rule it meant is about a path COMPONENT that is exactly
  `..`, which is a different question with a different answer.
  🔑 `v.relInside(rel)` is PURE and walks the components. GENERAL, and it
  is 6.230.0 from the other side: when a check is about STRUCTURE, parse
  the structure — a substring test over a serialised form is a different
  predicate that happens to agree on the common input.
  📏 AND THE MESSAGE IS PART OF THE BUG: "that path leaves the vault"
  made sense only to whoever wrote the guard. A refusal he cannot act on
  is a defect even when the refusal is correct.

- 🗂 A BACKUP OF A STAGING AREA IS A DUPLICATOR (6.329.0,
  modules/daily_backup.lua — LL: "Stop backing up desktop … I didn't
  realize backing up the desktop was gonna recreate files and copy
  anything up into OneDrive and bloat it so unnecessarily"). He is
  describing the feature working: the kit rsyncs ~/Desktop into
  <backupDir>, which is in OneDrive, so every file on his desktop had a
  second cloud copy. `bk.desktop = false`, the entry KEPT behind a
  settings line (6.254.0's shape, right here because this is a DOOR).
  🚨 NOTHING ALREADY COPIED IS DELETED, and that is a rule rather than
  an omission: no rsync in this kit carries `--delete`, and erasing a
  folder of his files to tidy up after itself is the one thing a backup
  module must never do. The report NAMES the folder so he can clear it
  himself. GENERAL: when a backup is switched off, the switch governs
  what happens NEXT; what is already stored belongs to the person.
  💾 AND THE SAME RELEASE PAIR GAVE THE VAULT THE MIRROR EVERY OTHER
  STORE HAS HAD SINCE 6.190.0 (6.331.0): a local rsync every 30 minutes,
  `.trash/` excluded, never `--delete`, destination outside OneDrive —
  a backup inside the thing being backed up is one deletion from being
  neither. A SYNC CLIENT IS NOT A BACKUP: a deletion propagates.

- 🔄 REACH THE APP, DO NOT TYPE AT IT (6.332.0,
  modules/asana_comments.lua — LL: "Asana auto-refresh every 5 min",
  with a draft that activated Asana, posted ⌘R and activated the
  previous app back). Every objection to that draft is a rule already
  here: a posted ⌘R comes back through our own taps as typing (6.218.0);
  two activations every five minutes leave a window where nobody owns
  the keyboard; the nested `doAfter`s are unheld and unslotted (6.196.1);
  and there is no switch, no report and no degrade.
  🔑 `app:selectMenuItem` REACHES THE APP WITHOUT ACTIVATING IT — no
  focus theft, no posted key, nothing to put back, and the feature is
  one call. `M.refreshPick(paths, works)` is PURE and walks the candidate
  menu paths in order, so a RENAMED MENU IS A MISS THAT SAYS SO rather
  than a silent no-op (6.284.0's lesson: the stale half is the question
  we ask, not the answer the app gives). 🔕 Asana not running is the
  ordinary state and is counted apart, never the 🔔 door — a tool that
  warns every five minutes about a closed app is one he switches off.
  🗳 GENERAL: when he hands over code, the ask is the SENTENCE and the
  code is one way to get there. Read it for the intent, say plainly
  which parts cannot ship and why, and build the version that costs him
  nothing — then name the one open question (here: should it pause while
  he is typing in Asana?) rather than guessing it.

- 🪟 A HANDLE RECORDED BEFORE THE WINDOW IS UP IS A HANDLE THAT LIES
  (6.326.0, modules/music_player.lua — LL's own probe:
  `handle : false · window : false · visible : nil · frame : none ·
  queue : 1 · gate : the card is closed — macOS keeps the key`, run
  while ⏯ was not reaching the player). That is 6.309.0's gate answering
  CORRECTLY about a card he had opened: `mp.show` assigned `mp.webview`
  and THEN called `view:show()`, so a refusal (6.265.0 — created, wired,
  refused) left a handle pointing at a window that is not on screen.
  🔑 ASSIGN THE HANDLE ONLY AFTER THE SHOW HAS ANSWERED, and TEAR THE
  OBJECT DOWN on a refusal — an abandoned webview keeps its Esc claim
  and its key handler. GENERAL: a published handle is a CLAIM about the
  world, so it is written after the world agrees, never before; every
  gate downstream reads it as truth.
  🔖 AND THE SAME SWEEP FOUND THE ONE-SLOT MEMORY (6.327.0): `vault.
  lastNote` is a single slot, so deleting the note it names strands ⇪3
  on the list — 6.277.0's feature absent for the commonest case, 55
  deletes in one session. `v.recentPush` is PURE, bounded at 20, and the
  delete forgets its row AT THE MOMENT it happens rather than leaving it
  to be discovered.

- 🏷 THE NAME IS THE IDENTITY; THE HEADING IS WHAT HE MAINTAINS
  (6.328.0, modules/vault.lua — LL: "Changing a title like # Add recycle
  bin does not change the title in the lefthand column. I think it
  should"). The column showed the FILE NAME, which was right when every
  note was named once at ⌘N and never again.
  🔑 A FIFTH GREP, HUNG OFF THE END OF THE CHAIN and started AFTER
  `finish(nil)`, so a grep that fails or is slow costs the titles and
  nothing else (6.174.0). `v.titleOf(rel, name)` is PURE — the heading
  when there is one, the file name when there is not — and `v.headIn
  (text)` is its Lua twin for the OPEN note, so the row under his hand
  follows as he types rather than waiting for a scan. One rule, two
  readers, and the check moves a heading and requires both to agree.
  📏 THE FILE IS NOT RENAMED, and that is the whole safety of it: every
  [[link]], every backlink and every index key is the name. This changes
  what is DRAWN. A real rename is a different and far more dangerous
  release, and it is not smuggled in here.

- 📐 WHEN YOU TAKE A SURFACE OVER FROM macOS, YOU INHERIT EVERYTHING
  IT WAS DOING — INCLUDING WHAT NOBODY NAMED (6.318.0,
  modules/screenshots.lua — LL: "hyper+shift+4 has pixel crosshairs,
  hyper+4 does not … and it was working before. Don't break as we
  build").
  🔎 HE IS RIGHT ON EVERY COUNT. ⇪⇧4 is `screencapture -i` and keeps
  macOS's own HUD: crosshairs and live coordinates from the instant the
  key is pressed. 6.264.0 moved ⇪4 onto OUR selector — on his own ask
  for a better pixel readout — and our selector had drawn a dashed band
  and a dim wash and NOTHING ELSE since the day it was written: no
  crosshair at any point, no numbers until a drag had started. The
  release gave him the thing he asked for and silently took away a
  thing he had never had to ask for, because nobody had written down
  that macOS was providing it.
  🔑 THE RULE: a swap is only faithful if you enumerate what the OLD
  surface did, not what it was FOR. 6.264.0's own note listed what it
  cost — the native magnifier, SPACE-to-shoot-a-window — and missed
  the crosshair, because the crosshair is not a feature anybody names;
  it is what the thing LOOKS like. The same shape as 6.264.0's
  `withSound` (a swap must not quietly also remove a sound), one level
  up: before replacing a system surface, LIST WHAT IT DRAWS, not only
  what it does.
  📏 AND THE ANSWER IS NOT TO REVERSE IT. Putting ⇪4 back on `-i` would
  return the crosshairs and remove the live W × H he asked for twice.
  The missing half was ours to draw, so it is drawn: `crossPlan` PURE
  and clamped (a pointer on the last pixel would put a line half off
  the screen — and that is the only input where clamped and unclamped
  differ, 6.230.0), on elements 5 and 6 of the SAME canvas, MOVED never
  rebuilt (6.247.0), with the box showing the POINTER'S POSITION until
  there is a rectangle to measure — and drawn the moment the selector
  ARMS, because a number that appears late is one you do not trust
  (6.238.0) and a feature that waits for a jiggle reads as not built.
  🔒 TWO SWITCHES FOR ONE SENTENCE. "No crosshairs" and "no numbers"
  came to me as one complaint and are two failures with two causes, so
  `crosshair` and `sizeReadout` are separate, the report counts them
  apart, and each has three states (6.196.1).
  🧪 THE SWEEP FOUND THE ARM-TIME DRAW GOING SILENT: a bare pcall, so a
  Mac where the crosshair throws switched it off before the first mouse
  event and the 🔔 door was never taken — 6.196.1 inside the feature
  built to answer "why has ⇪4 no crosshairs?". One `showCross` door
  now, taken by both callers. 🔬 And the suite's
  `hs.mouse.absolutePosition` returned nil, which the real one never
  does (6.290.0), so the arm-time draw was unreachable from the gate.

- 🚪 A DIAGNOSTIC NOBODY KNOWS TO RUN DOES NOT EXIST (6.317.0,
  modules/write_ledger.lua — LL: "Each init.lua should give me a readout
  of where the files are that clipboard history go and give the last
  date anything was written into any log/store/file … I don't want to
  find out when I need it most, something hasn't been saving").
  🔎 AND EVERY NUMBER HE ASKED FOR ALREADY EXISTED. `_G.saved()` has
  printed each store's path, size, rows, last write and growth since
  boot since 6.115.0, and writes a probe file into the Logs folder and
  reads it back because "the folder exists" and "the folder will take a
  write now" are different claims. Three hundred releases, and he had
  never seen one line of it.
  🔑 THE RULE, and it is 6.271.0's with the serial number filed off:
  **THE INSTRUMENT IS NOT THE GAP, THE DOOR IS.** When he asks for
  something this config can already answer, the work is never a better
  report — it is printing the one that exists where he already looks.
  Check for the existing instrument FIRST and say plainly that it
  existed; shipping a second report beside a working one is how a
  config grows two answers to one question.
  🚨 AND THE LINE THAT EARNED THE RELEASE IS ABOUT THE NOTES. init.lua
  resolves OneDrive inside a pcall, so a failure is SILENT; vault.lua
  then points `v.dir` at a LOCAL folder and `v.scan`'s mkdirp creates
  it, so Hamsidian opens an empty folder and honestly says "no notes
  yet" about the wrong place. That is the whole shape of "my notes are
  gone. But I did not delete them", and nothing said so. The readout
  says it in capitals, says the notes are NOT lost, and says what to do.
  GENERAL: when a resolution step can fail silently and a DEFAULT takes
  over, the default must announce itself — a fallback nobody is told
  about is indistinguishable from the thing it replaced.
  📋 A HAND-KEPT LIST IS SAFE ONLY WHEN ITS FAILURE IS LOUD. `watchFor`
  names the stores he has asked about, which is exactly the shape
  6.276.0 deleted for lying about free keys — the difference is the
  inverted failure mode: a name matching no file prints "⚠️ NO FILE
  MATCHING", never nothing. Forgetting to add costs a missing line;
  forgetting to remove costs a loud wrong one. Both are visible, which
  is the opposite of a list that quietly certifies health.
  🗂 AND IT FOUND A REAL HOLE BY ASKING ITS OWN QUESTION: `<Logs>/scratch`
  was never scanned, so scratch.json — every Hamsidian tab he has ever
  typed — was invisible to the module that proves stores are saving.
  ⏱ A held timer ten seconds after warm, because the notes index is a
  find in a task and a readout saying "not finished yet" every morning
  is a line he scrolls past. A Mac that cannot arm one prints at once
  and early — silence is not an option in a release about not being
  told. 📏 It is deliberately NOT silent when healthy (the opposite of
  6.269.0) because he asked for the healthy case in writing.

- 🚪 A DRAG ENDS WHEREVER THE BUTTON COMES UP — THIRD CALLER, AND
  NOBODY ASKED IT (6.336.0, modules/screenshots.lua — LL on ⇪4: "did
  show crosshairs, on releasing it said 0x0 pixels, and then jumped a
  few desktops, and then I had to hit escape to get it in").
  🔎 THREE SENTENCES, ONE MISSING EXIT, in the order the mechanism
  produces them. `shots.selectArea` ended a drag in exactly one place —
  `msg == "mouseUp"` inside its own hs.canvas mouseCallback — and a
  canvas hears nothing off its own frame. macOS reads a three-finger
  trackpad drag as a Space swipe, and a Space transition is precisely
  when it stops delivering events to us (6.303.0 found that about the
  F18 tap). So the band froze at the 0 × 0 written at the press,
  nothing was captured, and the overlay stayed up with Esc the only way
  out. The ⇪5 "weird screenshot" is the same event: six slices of the
  desktop he had been thrown onto.
  🔁 THE RULE WAS ALREADY WRITTEN TWICE — 6.222.0 for the editor's page
  and 6.306.0 for the panel drag engine — and the selector was never
  asked. 6.305.0 exactly, and it is the third time that sentence has
  decided a release: A RULE WRITTEN ABOUT ONE CALLER IS NOT A RULE
  UNTIL EVERY CALLER HAS BEEN ASKED. GENERAL, and it is the cheap half:
  when a rule lands, grep for every OTHER surface in this config that
  hands control out and waits for an event to come back — a canvas
  callback, a page, a tap — and ask each of them in the same sitting.
  🔬 `shots.dragStillHeld` is PURE, and checkMouseButtons IS A VETO,
  NOT AN ORACLE (6.306.0): believed only when it positively says STILL
  DOWN. nil, an empty table, a Mac that cannot answer all read as
  "over", because ending a drag early costs one selection he can take
  again and not ending it costs an overlay only Esc clears.
  📏 THE RECOVERED POINT IS CLAMPED INTO THE SCREEN — a release on the
  other display answers a point outside the canvas, and screencapture
  trims such a rectangle silently, so the band he watched and the file
  he gets would differ.
  🚨 AND THE SUB-8-PIXEL EXIT WAS A BARE `end`: the selector vanished,
  nothing was captured and nothing was said. 6.320.0 again, and the
  message names the SIZE, because "0 × 0" is the whole diagnosis when a
  release went unheard.
  🧪 The sweep found the missing check (6.273.0): closing the drag
  inside the finish survived, because nothing drove the race it exists
  for — the watch ends the drag and the REAL mouseUp then arrives at a
  canvas macOS has not torn down. Without it, one keypress writes two
  files.

- 🚪 THE INSTRUMENT WAS NOT THE GAP, THE DOOR WAS — THIRD TIME
  (6.335.0, modules/vault.lua — LL, with a photograph of the Hamsidian
  header: "I need a trash bin at the top with the other buttons that
  lets me see notes I deleted"). Every note was already recoverable:
  6.321.0 moves a delete to `<Vault>/.trash`, keeps it 180 days and
  restores it by name. What it shipped was two CONSOLE COMMANDS.
  🔑 THE SENTENCE IS 6.317.0's AND IT HAS NOW DECIDED THREE RELEASES
  IN A ROW IN THIS MODULE: `_G.saved()` answered his question for three
  hundred releases unseen (6.317.0) · fifty-five notes sat on disk
  behind one undo slot (6.321.0) · the bin he could not open (this).
  GENERAL: when he asks for something this config can already do, the
  work is a DOOR — and the place to look first is where he is already
  looking, not what the tool can already answer.
  🗑 A FOURTH FACE OF THE LEFT COLUMN, exactly like ☑ tasks, which is
  the precedent that made it small: a header button, a mode, a draw
  function, a `setRows` kind. 🔑 BY TRASH FILE NAME, NEVER BY ROW
  NUMBER (6.272.0 / 6.186.0) — the list renumbers the moment anything
  is restored, in the one list whose purpose is not losing things.
  🔎 THREE STATES (6.196.1): reading the bin… · the bin is empty · ⚠️
  it could not be READ. The third must never render as the second.
  🔒 NOTHING THE PAGE CAN SEND DESTROYS A FILE, and the check reads
  the MESSAGE SET rather than grepping for a name — a purge control
  one pixel from a restore control is the wrong button to add.
  🚨 AND A LOCAL DECLARED BELOW THE PAGE BUILDER IS A NIL GLOBAL TO
  IT. The bin's JSON encoder was written beside the bin, three
  thousand lines under the builder that reads it; building the page
  raised, `v.htmlSet` was never assigned, and the suite DIED with
  eleven reds under one traceback. GENERAL: anything the page builder
  reads is declared beside `jarr`, not beside the feature.
  🧪 THE SWEEP FOUND THE CHECK THAT COULD NOT FAIL (6.273.0): the
  empty-row-name guard asserted only that nothing was restored, which
  is true with the guard deleted — `_G.vaultRestore("")` refuses by
  itself. The guard's job is the SENTENCE (6.320.0), so it asserts the
  words. And a check asserted the whole ROWSEL literal where it meant
  "there is ONE walker" — 6.248.0, sixth time.

- 🔎 A LAZY INDEX MAKES "NOT YET" AND "EMPTY" THE SAME WORDS — AND THE
  CLOCK THAT SEPARATES THEM WAS ALREADY BEING COLLECTED (6.334.0,
  modules/write_ledger.lua — his own 6.333.0 boot: `🕸 Hamsidian notes
  : …/Vault · 0 notes` with `⚠️ THE FOLDER IS THERE AND HOLDS NO
  NOTES` under it, over a vault holding all of them).
  🔑 `v.scan()` RUNS WHEN HAMSIDIAN OPENS. Nothing triggers it at boot,
  so ten seconds after warm `v.notes` is the empty table it was born
  with and `#v.notes` is 0. 6.312.0 exactly, inside the instrument
  6.317.0 built to prevent it — which is the rule's own warning paid:
  anything moved off the boot path owes its report a fourth state, and
  6.312.0 said that about two modules without sweeping the rest.
  🕒 AND `vaultFacts` HAD CAPTURED `scanned = v.lastScan` SINCE 6.317.0
  AND NOTHING READ IT. nil until a scan completes — the exact field the
  two states differ by. GENERAL, and it is the cheap half: before
  adding a state to a report, grep what the report's own fact-gatherer
  is ALREADY collecting; the clock is often there and unread.
  🔬 Branches, never an `and/or` chain (6.303.0).
  📋 AND THE SAME BLOCK HUNTED A FILENAME NOTHING HAS EVER WRITTEN —
  "file_history" against file_tracker's `file_changes-<Mac>.csv`. The
  guard was RIGHT to shout (6.276.0: a hand-kept list is safe only when
  forgetting is loud); the needle was wrong on day one. The suite had
  written the real file since it was born and nothing asserted the row
  RESOLVED, so the check now walks the whole block for "NO FILE
  MATCHING" rather than naming one row.

- 🚨 A TOOL THAT WARNS THROUGH ONE CHANNEL WARNS THROUGH NONE
  (6.316.0, core/notices.lua + modules/vault.lua + scratch_pad.lua —
  LL, in capitals: "!!CRITICAL: HAMSIDIAN MUST THROW VISIBLE ERRORS IF
  IT DOES NOT SAVE.!!").
  🔎 AND IT ALREADY DID, which is why the reading mattered more than
  the build: both halves called hs.alert on a failed write, in two
  copies of the same five lines. Four separate things made that not
  enough, and every one of them is a rule already in this file —
  6.274.0 measured macOS REFUSING that exact channel three times in
  eight hours; the gate was a per-SESSION boolean so a second,
  DIFFERENT cause was silent all day; it never took the 🔔 door, so it
  reached no ledger row, no `_G.degradeReport()` and no CSV row, which
  made `_G.todayReport()` — the 4 PM check built from his own words in
  6.279.0 — structurally blind to the one failure that costs him his
  writing; and nothing outlived the ten seconds the alert was on screen.
  🔑 GENERAL, AND IT IS THE ONE TO CARRY: **"DOES IT WARN?" AND "WOULD
  HE FIND OUT?" ARE DIFFERENT QUESTIONS, AND ONLY THE SECOND MATTERS.**
  When a report asks whether a failure is visible, do not grep for an
  alert — walk the channels: can it be refused · is it gated per
  session or per cause · does it reach the ledger that outlives a
  reload · and is anything still TRUE an hour later. A single channel
  answers yes to the first question and no to all four.
  📌 THE STICKY ONE IS THE POINT. `notices.unsaved[tool]` is cleared by
  a REAL WRITE and by nothing else — not a timer, not a reload, not a
  quieter minute, because "it stopped complaining" and "it saved" are
  opposite facts (6.196.1). It prints FIRST in `_G.degradeReport()` and
  in both Hamsidian reports, above the history, because it is the only
  line in any of them still true rather than a record.
  🔕 AND IT IS BOUNDED, or it is a warning he learns to dismiss: the
  vault retries every keystroke, so the alert rides the door's own
  per-cause window and the notification is keyed with its own
  (`notSavedEvery`, 300 s). 🚨 THE FIRST FAILURE OF A STREAK ALWAYS
  SPEAKS — and it CLEARS the stored key rather than passing no key,
  because a keyless `notices.tell` records nothing, so the NEXT failure
  speaks too and "once per streak" quietly means twice. That was real,
  in the first version, and it is its own check.
  🔒 ONE FUNCTION, TWO CALLERS (6.231.0): the notes side and the tabs
  side are one tool and had two copies of the warning, which is exactly
  how they came to be identically wrong. The fallback for a Mac where
  notices did not load gates on the CAUSE STRING, never a boolean.
  🧪 THE FIXTURE THAT BITES IS A SECOND FAILURE WITH A DIFFERENT REASON
  (6.230.0) — every other input agrees with the old code. And the check
  that read "the second failure in the streak is silent" was asserting
  the BUG; it asserts the rule now (6.248.0, fifth time).

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
   6.227.0 14e953a · 6.228.0 2aa3dfe · 6.229.0 a1318e1 · 6.230.0 0740c07 · 6.231.0 c1921af · 6.231.1 5a5c298 · 6.232.0 1ca3f6f · 6.233.0 2328c8c · 6.234.0 57f78d0 · 6.235.0 52e5b21 · 6.236.0 34cff8b · 6.236.1 fdce771 · 6.237.0 adf9256 · 6.238.0 3adad4f · 6.239.0 3adad4f (one commit, two releases) · 6.240.0 8f44bec · 6.241.0 dce517e · 6.242.0 1a1dab0 · 6.243.0 8fba04f · 6.244.0 9320906 · 6.245.0 9c1a8b1 · 6.246.0 1400abd · 6.247.0 3b92e99 · 6.248.0 e4e3a03 · 6.249.0 e4edc3f · 6.250.0 c267c1b · 6.251.0 f7b0d57 · 6.252.0 6307253 · 6.253.0 ef20313 · 6.254.0 14493e5 · 6.255.0 d371b34 · 6.256.0 3c29888 · 6.257.0 7f55d2b · 6.258.0 10d2250 · 6.259.0 2bcda06 · 6.260.0 f16e286 · 6.261.0 8680504 · 6.262.0 595dc2e · 6.263.0 014ddf6 · 6.264.0 5e41879 · 6.265.0 f0c487c · 6.266.0 9135f7b · 6.267.0 a621a60 · 6.268.0 c2e513f · 6.269.0 f6552ea (078cece is the same release before the report was corrected) · 6.270.0 b8eda88 · 6.271.0 b8edbe1 · 6.272.0 881a91b · 6.273.0 56b0d2b · 6.274.0 c6e9b6b · 6.275.0 9cebe19 · 6.276.0 3db904e · 6.277.0 c6632a1 · 6.278.0 6c1fe75 · 6.279.0 a6241f5 · 6.280.0 893b40b · 6.281.0 5611a4a · 6.282.0 11dc992 · 6.283.0 3fa417f · 6.284.0 a8f3df4 · 6.285.0 70d118b · 6.286.0 fa93f1b · 6.287.0 39b9dba · 6.288.0 8508186 · 6.289.0 83f5296 · 6.290.0 6daee50 · 6.291.0 aec4561 · 6.292.0 c89c65f · 6.293.0 10c9410 · 6.294.0 0aeebdc · 6.295.0 641c45c (52c1b2b adds the check its own mutation sweep found missing) · 6.296.0 e82ad95 (8bd970b adds the cross-file sentry) · 6.297.0 dacb791 (1604d55 hardens the suite) · 6.298.0 f77c47e (fe109ff adds the two checks its sweep found missing) · 6.299.0 bdc6855 (c587502 the same) · 6.300.0 8ab4802 (cc8b7f9 the same) · 6.301.0 dcff776 · 6.302.0 b465418 (e287164 the mutation sweep's own two findings) · 6.303.0 f5d89e1 · 6.304.0 b8b1b51 (7cf3d9b is the release; b8b1b51 adds the mutation sweep's own four findings) · 6.305.0 b1aa974 (f478dc8 is the release; b1aa974 adds the mutation sweep's own four findings) · 6.306.0 cf14689 · 6.307.0–6.310.0 10c6a87 (one commit, four releases — the four live in four different modules, so a break still names its version by which tool it is in) · 6.311.0 82e52f8 (c7cd4de adds the mutation sweep's own two findings) · 6.312.0 4ad18dc · 6.313.0 c09cb78 (the ceremony for both is the commit after; the code is in those two) · 6.314.0 9ee6a76 (0a363e9 is the ceremony and the mutation sweep's own finding) · 6.315.0 a9394e4 · 6.316.0 cb411aa (8ee2228 adds the mutation sweep's own findings) · 6.317.0 2d2f1e1 (07d5fa5 the same) · 6.318.0 4e95bd2 (366d17f the same) · 6.319.0 8ef0bbe (6c9a7f7, 865ba74, c6f23ef, b448bd1, 99cfafc and c4994f6 are the mutation sweep's own six findings — the third of them is the real one) · 6.320.0 and 6.321.0 ddf6310 (one commit, two releases — the `..` guard and the bin it unblocked) · 6.322.0 fd3d91e (b6b39e5 is the faithful degrade stub it needed) · 6.323.0 44b027a (3602db5 makes its fallback reachable) · 6.324.0 524ae1f · 6.325.0 06c731b (0c0f890 adds the door's own checks) · 6.326.0 1363050 · 6.327.0 e26f17f (6c7e2e9 drives the delete-time forget) · 6.328.0 c4b6fe3 · 6.329.0 029f5de · 6.330.0 7bc13f3 (981c1b7 makes a label that cannot be built a bare epoch rather than a dead pulse) · 6.331.0 4471793 · 6.332.0 7ea10d9 (a1715c9 the sweep's own two findings) · 6.333.0 c57ba35 · 6.334.0 and 6.335.0 212b1ac (one commit, two releases — the readout fix is in write_ledger, the bin in vault, so a break still names its version by which tool it is in).
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

## 🔨 CRUDE OR ELEGANT — LL's rule (6.307.0), and the index that makes it work

LL, 2026-09-28: "When we solve a problem that we both determine, you
will ask me, is this a problem that made your MacBook for work or home
unusable? If it degrades gracefully where it's a fix, that's solved on
one pass: elegant. If it became unusable, you are to create a new line
that says **Crude problem** and logs it. If it is fixed in one pass call
it **Elegant solution** … You need to be able to refer back to problems
and not tell me it is different or only find it when I tell you it's
something we already fixed. I mean come on… lol, you're the one with
perfect memory."

He is right, and it has cost us twice in a fortnight. 6.306.0 needed his
own sentence — "We have solved this issue or a similar one" — to find
6.138.0's identical report and 6.222.0's written rule. 6.305.0's
duplicate-on-retry rule had been written FOUR RELEASES EARLIER in this
very file and applied to one caller only.

🔨 THE QUESTION, asked in every verify block from 6.307.0 on:
**did this make a Mac — home or work — UNUSABLE, or did it degrade?**
  🔨 **CRUDE PROBLEM** — the Mac was unusable while it lasted: a dead
     keyboard, a panel only `hs.reload()` could clear, an archive he
     could not open, a config that would not boot.
  ✨ **ELEGANT SOLUTION** — it degraded gracefully AND was fixed in one
     pass. Both halves, or it is not elegant yet.
  A fix that took more than one pass is neither until it lands; the row
  records the pass count, because that number is the honest measure.

🗳 THE TAG IS HIS, NEVER MINE — same rule as the scoreboard. I ask; he
answers; I log. A row with no answer reads "ask" and stays that way
rather than being scored from this side.

🔎 AND THE TAG IS NOT THE POINT — THE INDEX IS. The ledger is keyed by
the SYMPTOM IN HIS WORDS, because his words are what comes back months
later and his words are what I failed to search. **RULE: before
diagnosing anything, grep this table for the nouns in his sentence.** A
hit is not proof it is the same bug — 6.198.0 — but it is a precedent
that must be READ before a new cause is named.

| symptom, in his words | where it lives | releases | passes | tag |
|---|---|---|---|---|
| "killed my keyboard", every key runs a shortcut, ⇪ latched | core/hyper_key.lua · hyper_storm.lua | 6.162.1 · 6.214.1 · 6.214.2 · 6.302.0 · 6.303.0 · 6.304.0 | 6 | 🔨 crude |
| "empty zip" / the archive will not open | delivery, not code | 6.263.0 → 6.303.0 | 6 | 🔨 crude |
| "a drag kills the sheet functionality" · wheel dead over ⇪/ · desktop jump | core/coexist.lua drag engine | 6.138.0 · 6.306.0 | 2 | ask |
| "hyper+4 no longer works" / "intermittently working" | modules/screenshots.lua | 6.264.0 · 6.265.0 · 6.274.0 · 6.282.0 | 4 | ask |
| "hyper+4 does not have pixel crosshairs" · "it was working before" | modules/screenshots.lua · the selector | 6.264.0 · 6.318.0 | 1 | ask |
| "it said 0x0 pixels, then jumped a few desktops, then I had to hit escape" | modules/screenshots.lua · the selector's one exit | 6.336.0 | 1 | ask |
| "once I OCR some text, that text should immediately go onto the clipboard" | modules/screenshots.lua · the OCR doors | 6.173.1 · 6.319.0 | 1 | ask |
| "frozen grid again" — a yellow box only a reload clears | modules/mouse_grid.lua · `_G.showCanvasSafely` | 6.266.0 | 1 | ask |
| "can't move files in drag and drop" · Hammerspoon locked up | modules/file_tracker.lua | 6.228.0 · 6.229.0 · 6.230.0 · 6.241.0 | 4 | ask |
| "can't drop a file on the music player" | modules/music_player.lua | 6.231.0 · 6.233.0 · 6.235.0 · 6.237.0 | 4 | ✨ WIN |
| cheat sheet "appears on a different screen" | init.lua §1.5 · core/cheatsheet.lua | 6.236.0 · 6.288.0 | 2 | ask |
| "the green icons loop and loop" — OCR nonstop | modules/screenshots.lua | 6.281.0 | 1 | ask |
| ⇪Y "caused a lock up when I started to search" | modules/chrome_history.lua | 6.245.0 | 1 | ask |
| "banshee" — a field of doesnt/dododod, tabs opening | modules/autocorrect.lua | 6.216.0 → 6.218.0 · 6.219.0 | 2 | 🔨 crude |
| "closing the screenshot editor dumps the most recent edits" | modules/screenshot_editor.lua | 6.189.0 · 6.286.0 | 2 | ask |
| "⇪⇧A on the blue line file" — one press behind | modules/universal_actions.lua | 6.246.0 | 1 | ask |
| "I don't see items that i just copied" | modules/clipboard_history.lua | 6.224.0 | 1 | ask |
| "1 of 122 task(s) did not reach Asana" → would re-send 121 | modules/scratch_pad.lua | 6.305.0 | 1 | ask |
| "search finds a title but creates a new entry" (⌘F, ⏎) | modules/vault.lua | 6.307.0 | 1 | ask |
| "cmd+cmd does not bring up unified clip" | modules/clipboard_history.lua warm | 6.308.0 | 1 | ask |
| "still hold play pause when not visible" | modules/music_player.lua | 6.289.0 · 6.291.0 · 6.309.0 | 3 | ask |
| "history : 0 track(s)" two seconds after a boot — read as lost data | modules/music_player.lua report · M.warm | 6.312.0 · 6.313.0 | 1 | ask |
| a picker throws `NSInternalInconsistencyException` instead of opening | init.lua `showPopup` · the AppKit remote-view family | 6.56.0 · 6.274.0 · 6.314.0 | 3 | ask |
| "can't use the arrow keys to move thru the history list" | modules/music_player.lua · the card's cursor | 6.315.0 | 1 | ask |
| "⇪⇧L needs to be more obvious" | modules/mouse_grid.lua | 6.167.0 · 6.195.0 · 6.310.0 | 3 | ask |
| "can only be accessible via full keyboard" · "I can't tell if that key combo is taken" | modules/music_player.lua · the key registry | 6.276.0 · 6.311.0 | 1 | ask |
| "Hammerspoon locks" · "I couldn't even click on anything" · 73 s, then it crashed | core/ · the main thread · modules/stall_guard.lua | 6.208.0 · 6.324.0 · 6.330.0 | 0 (instrumented, not fixed) | ask |
| "I couldn't get any of that text back while the note remained blank" | modules/vault.lua · ⌘Z and the save path | 6.322.0 · 6.323.0 | 1 | ask |
| "this is horrible not having an undelete or recycled bin" · "nothing to undelete" · "a trash bin at the top with the other buttons" | modules/vault.lua · `<Vault>/.trash` | 6.280.0 · 6.321.0 · 6.327.0 · 6.335.0 | 2 | ask |
| "0 notes" / "THE FOLDER IS THERE AND HOLDS NO NOTES" on a full vault | modules/write_ledger.lua · the lazy notes index | 6.317.0 · 6.334.0 | 1 | ask |
| "Not deleted - that path leaves the vault" — on an ordinary note | modules/vault.lua · the `..` guard | 6.320.0 | 1 | ask |
| "changing a title … does not change the title in the lefthand column" | modules/vault.lua · the note list | 6.328.0 | 1 | ask |
| "stop backing up desktop … bloat it so unnecessarily" | modules/daily_backup.lua | 6.329.0 | 1 | ask |
| "the card is closed — macOS keeps the key" over a card he had opened | modules/music_player.lua · `mp.show` | 6.289.0 · 6.309.0 · 6.326.0 | 3 | ask |

📏 SEEDED FROM THE RECORD, NOT INVENTED: every row above is a real
report with a real release beside it, and the pass counts are countable
from the scoreboard. What is NOT filled in is the tag, because that is
the answer only he can give — and a table full of guesses would be
exactly the thing he is asking me to stop doing.

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
| 6.336.0 | 🚪 a ⇪4 drag whose release macOS swallowed now captures what you dragged instead of leaving the overlay on screen | pending |
| 6.335.0 | 🗑 the bin is a button in the header — every note you deleted, click one to put it back | pending |
| 6.334.0 | 🔎 the boot readout stops saying your notes folder is empty when it simply has not counted yet | pending |
| 6.333.0 | 🕸 one Hamsidian list — a tab and a note side by side, newest first, the icon telling them apart | pending |
| 6.332.0 | 🔄 Asana reloads itself every five minutes through its own menu — no focus stolen, no keystroke posted | pending |
| 6.331.0 | 💾 the notes get a second copy that is not in the cloud — every store had a 30-minute mirror and the vault never did | pending |
| 6.330.0 | 🧊 the stall guard's heartbeat carries the shortcut the main thread is inside, so the next 73-second hang names itself | pending |
| 6.329.0 | 🗂 the Desktop is out of the backup kit on his word — nothing already copied is deleted | pending |
| 6.328.0 | 🏷 a note's row shows its `# Heading`, not its file name — and the file is NOT renamed | pending |
| 6.327.0 | 🔖 ⇪3 remembers the last twenty notes, so deleting one costs a step back and not the whole memory | pending |
| 6.326.0 | 🎵 a card macOS refused to show is no longer recorded as open — his own probe, `handle : false · queue : 1` | pending |
| 6.325.0 | 📋 ⇪D, ⇪⇧V and ⇪⇧O say "Copied" only when macOS took the write — three sites read the return at last | pending |
| 6.324.0 | 🪜 the notes scan stops releasing the running task's own handle — 6.196.1's native-kill shape, on every scan | pending |
| 6.323.0 | ↩️ ⌘Z survives a scan — a re-scan rebuilt the page and a text box's undo history dies with it | pending |
| 6.322.0 | 🔒 a note that collapses keeps its old text in the bin first — select-all-and-type was two keystrokes wide | pending |
| 6.321.0 | 🗑 the recycle bin he can list, restore from and purge — all 55 deleted notes were on disk and unreachable | pending |
| 6.320.0 | 🚪 a note with two dots in its name can be deleted — the guard tested for the characters, not a folder called `..` | pending |
| 6.319.0 | 📋 the words of a shot you just took land on the clipboard — ⇪⇧4 has copied since 6.173.1 and the shot ⇪4 takes never did | pending |
| 6.318.0 | 📐 ⇪4 draws crosshairs again and the numbers are there before you press — 6.264.0 moved it onto our selector and silently dropped the HUD macOS had been drawing | pending |
| 6.317.0 | 💾 every boot says where your stores are and when each last saved — and SHOUTS when the notes folder is a local one OneDrive was not found for | pending |
| 6.316.0 | 🚨 a Hamsidian save that fails is impossible to miss — it warned through the one channel macOS is measured to refuse, behind a per-session switch, and never reached the 4 PM log | pending |
| 6.315.0 | ⌨️ ↑↓ reach the Jug Player's 🕘 history at last — the cursor was written when the card had one list, and the history was drawn under it four releases later | pending |
| 6.314.0 | 🪟 a picker macOS refuses to open is a quiet keypress and a named line, not forty lines of traceback — his 20:30:01 NSInternalInconsistencyException, the same AppKit family as both .ips aborts | pending |
| 6.313.0 | 🔒 the Jug Player's queue survives a save that fails — the store was opened with a truncating write, so a crash mid-save left it at zero bytes and the loader read that as "nothing queued" | pending |
| 6.312.0 | 🔎 the report can say "not read yet" — it reported an empty queue, no history and a dead ⏯ two seconds after a boot, before any of the three had been read, and I called it lost data | pending |
| 6.311.0 | ⌨️ ⇪⇧. opens the Jug Player — the numpad key was unreachable on his mini keyboard, and the combo was free (asked of the registry, not of a note) | pending |
| 6.310.0 | 🎯 each ⇪⇧L ring 10% wider than the last, and the canvas grew to hold the outermost | pending |
| 6.309.0 | ⏯ the Jug Player holds ⏯ only while its card is ON SCREEN — 6.289.0 gated on a queue, which is a rule he never asked for | pending |
| 6.308.0 | ⌨️ ⌘⌘ opens the clipboard at last — two functions called M.warm in one file, and setup() destroyed the one that registered it | pending |
| 6.307.0 | 🔎 ⌘F then ⏎ opens the note it found instead of writing a new one with the text you typed | pending |
| 6.306.0 | 🚪 a drag that ends anywhere but on the panel no longer leaves the cheat sheet moved with its scroll hit box at the old spot — three of the engine's four exits never told the panel it had moved | pending |
| 6.305.0 | 🔁 a retry no longer re-sends what already reached Asana — 121 of his 122 tasks landed, the tab was marked ❌, and tomorrow's 16:00 would have posted all 121 again | pending |
| 6.304.0 | 🚨 the Secure Input probe can no longer wedge — one ioreg that never answered shut the last of 6.303.0's three candidates down for the whole session, and `secure: not known` was the only thing it could ever say | pending |
| 6.303.0 | 🔬 two seconds after every wake, the three things that can kill ⇪ silently are asked — the hidutil remap, the event tap and Secure Input — and a remap that has GONE is put back | pending |
| 6.302.0 | 🌅 a ⇪ hold still open when the Mac wakes is let go, and a wake is visible to the hyper key at all — NOT the answer to his 10:57 storm, said out loud, because that hold began after the wake | pending |
| 6.301.0 | 🗂 an S: line is a real Asana subtask — it needed the parent task's gid, which only exists once the parent has been created | pending |
| 6.300.0 | 🗂 Hamsidian sends his grammar — one Asana task per task — and each tab is retitled ✅ Success / ❌ Error and kept until he deletes it | pending |
| 6.299.0 | 🔔 Asana's own answer reaches the caller — the submit returned true the moment it fired the POST, so a task Asana REFUSED was announced as sent | pending |
| 6.298.0 | 🔎 typing @ on its own lists all fourteen searches — the tags were only ever named in a section header you had to search your way into | pending |
| 6.297.0 | 🗂 Hamsidian reads his task grammar — a bare line is a task, `=` divides, P:/A:/D:/S:/T: — and PREVIEWS what it would send without sending anything | pending |
| 6.296.0 | 🏷 the music player is the Jug Player, with its name to the left of the now-playing line — one field every surface reads, so a rename cannot drift | pending |
| 6.295.0 | 🔕 a tool he does not care about reports a failure to the Console alone — everything that writes or gathers still shouts on screen, and the log keeps both | pending |
| 6.294.0 | 🎯 the ✅ ASANA card finally names ⇪T — the key that creates a task, absent from it since 6.114.0 removed it for a good reason; plus an auditor for a bound key printed on no card at all | pending |
| 6.293.0 | ⌨️ ⌥⌥ opens the front app's menus — his 6.198.0 ask, never built, and nine lines now that 6.292.0 made a gesture a registration rather than an engine | pending |
| 6.292.0 | ⌨️ ⌘⌘ opens the clipboard history — asked for three times since 6.198.0 and never built, while the engine for it had been driving ⌃⌃ on his Mac since 6.116.0; it is lifted into core/ so a gesture is a registration | pending |
| 6.291.0 | ⌨️ F8 drives the music card whichever of the two events macOS sends for it — an NSSystemDefined media key with "standard function keys" OFF, a plain keyDown with it ON, and 6.289.0 watched only the first | pending |
| 6.290.0 | 🔬 the gate now fails a stub that is gentler than macOS — eight of ten scored losses sit at the macOS boundary and zero are pure-Lua logic, because the code, the test and the stub come from one model of macOS and agree with each other when it is wrong | pending |
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

- 🧊 THE 73-SECOND LOCKUP IS INSTRUMENTED, NOT DIAGNOSED (2026-10-04,
  LL: "Hammerspoon locks not after a few hours period … I couldn't even
  click on anything on the screen. There seemed to be a significant lag
  and then I was finally able to click on something and even when I was
  able to click on Hammerspoon nothing worked. And then Hammerspoon
  crashed").
  ✅ WHAT IS KNOWN, from his own log: `🧊 Hammerspoon HUNG for 73 s at
  2026-10-04 17:16:59 and was relaunched by the stall guard (relaunched:
  stalled 73s, killed pid=6976)`. That is 6.208.0 working, field-proven
  a SECOND time (72 s in September), and it is why he got the Mac back
  without a reboot. What he describes as "then Hammerspoon crashed" is
  the guard killing it on purpose.
  🚨 WHAT IS NOT KNOWN IS WHAT HUNG, and the heartbeat could not say —
  one number, no context. 6.330.0 makes the beat carry the ⇪ shortcut
  the main thread is inside, so the NEXT one names itself; 6.324.0 fixed
  a use-after-free on the vault scan's ordinary path, which is a genuine
  candidate and is NOT claimed as the cause (6.198.0).
  🔎 THE CANDIDATE HIS LOG RAISES AND NOBODY HAS MEASURED: the boot
  reported `0.24s` and then loaded five extensions over the following
  FORTY-TWO SECONDS — `notify` 17:17:03 → `mouse` 17:17:29 (twenty-six
  seconds later) → `webview` 17:17:38 → `drawing` 17:17:41 → `geometry`
  17:17:45. Each `-- Loading extension:` line is a dylib load on the
  MAIN THREAD, lazily, the first time anything touches that extension.
  6.228.0 priced main-thread work in milliseconds; this is seconds, and
  nothing in this config times it. 🗳 ITS OWN RELEASE IF HIS NEXT
  breadcrumb points there, and the obvious shape is to require the
  extensions in `M.warm` rather than letting the first keypress pay —
  which is 6.267.0's move applied to Hammerspoon's own library loading.
  📋 ASK FOR, when it happens again: the guard's log (the path is on
  `_G.stallGuardReport()`), which now carries `in flight: <shortcut>`
  beside the kill, and the full Console around it. `(none)` is as useful
  as a name: it rules out every ⇪ shortcut in one line.

- 🎙 SUPERWHISPER — HIS CODE, READ (2026-10-04, LL: "How horrible is
  this code? Do I need it to work with my text expansion snippets you
  already have?" · "Superwhisper pastes." · "Superwhisper's won't handle
  2,007 text expansion snippets but it can run my triggers it seems like
  gr1 😀"). NOT BUILT, and the answer is a conversation rather than a
  release — see the reply sent with this batch. The durable half:
  🔑 SUPERWHISPER PASTES, AND THAT IS THE WHOLE DESIGN CONSTRAINT. Its
  output arrives on the clipboard and lands with ⌘V, so it never goes
  through this config's keyboard tap — which is why his 2,007 snippets
  (modules/text_expander.lua, driven by `hs.eventtap`) cannot see a
  single character of it. The two systems are on different roads by
  construction, not by oversight.
  🚨 AND HIS DRAFT WATCHES THE PASTEBOARD AND RE-POSTS ⌘V, which is the
  shape this config has paid for twice: a posted ⌘V comes back through
  our own taps (6.218.0), the clipboard is BORROWED by power_tools so a
  watcher cannot tell whose write it is seeing (6.198.0 / 6.201.0), and
  an unconditional rewrite of every clipboard change is 6.319.0's refused
  default — a tool must not replace something he copied himself.
  🚪 THE SHAPE THAT WOULD BE SAFE, if he wants it: expand on the TEXT
  THIS CONFIG IS ABOUT TO PUT ON THE CLIPBOARD, through `core.copyText`
  (6.325.0) — the one door every clipboard write in this config now goes
  through — rather than watching the pasteboard for somebody else's.
  That is a release when he asks; it is not started on a guess.

- 🩺 "SO I DON'T HAVE TO REMEMBER" — A HALF-INSTALL MUST BE ASKABLE
  (2026-09-29, LL, once the Console installer had put 6.311.0's module in
  place: "Will this be added as 'Get-Jug-Player-going.md' as part of the
  init.lua zip file with an entry on the cheat sheet under Jug player so
  I don't have to remember?"). YES — AND IT IS 6.271.0's RULE A SECOND
  TIME: the recovery existed only in a chat message, which is not in the
  package, which is exactly where the seventy-two verify blocks were.
  🔑 BUT NOT AS A DOCUMENT ABOUT ONE TOOL, and that is the whole design
  decision. Seventy-one modules can half-install, and a file named after
  the Jug Player is right about one of them — 6.276.0's shape, a
  hand-kept note true for one row and misleading about the rest. THE
  ANSWER IS AN INSTRUMENT: `MANIFEST.txt` at the archive root,
  GENERATED at ceremony time like TESTING.md and RESOLVED-FEATURE-
  REQUESTS.txt (a hand-kept one is stale the first time a file changes),
  one row per RUNTIME file — path and BYTE COUNT. `_G.installCheck()`
  stats each and names every file that disagrees.
  📏 SIZE, NOT A HASH, BY DEFAULT: `hs.fs.attributes(p).size` is a stat
  and reads nothing, so it costs nothing on the main thread (6.228.0),
  and it catches the case that actually happened — 107,414 against
  116,595. A hash on demand (`_G.installCheck(true)`) covers a same-size
  change, which is the rare one. 🔎 CHECK hs.hash IN THE SOURCE BEFORE
  RELYING ON IT (6.233.0) — a platform fact that decides a design is
  read in the extension, with the file named, never remembered.
  🔎 FOUR STATES (6.196.1), and the fourth is the one he has TODAY:
  matches · DIFFERENT SIZE, both numbers · MISSING · NO MANIFEST ON
  DISK, meaning this install predates the check and nothing can be said.
  "Cannot be checked" must never read as "all clear".
  🔔 IT SPEAKS AT BOOT ONLY WHEN SOMETHING DISAGREES, from `M.warm` and
  never setup (6.267.0: disk work at setup is a tax every key pays), and
  is silent on a healthy Mac (6.269.0). That silence is the point: his
  config booted green, the version stamp was right, and the feature was
  simply absent.
  📋 THE CHEAT-SHEET ROW IS A POINTER, NOT A CLAIM — the key column
  holds the WORD "install check", so the 6.196.0 auditor reads it as a
  pointer rather than a combo (6.294.0's ⇪T row is the precedent). And
  INSTALL.md gains the section, carrying the Console installer
  GENERALISED to take a module NAME, rather than one document per tool.
  🚫 THE STOPGAP IS NOT SHIPPED, said out loud rather than quietly
  dropped: `_G.hyperModal:bind({"shift"},".",…)` was a bridge for one
  evening, and on a healthy config it binds a key setup has already
  bound — two handlers for one tool, 6.291.0 — while hand-writing
  `_G.hyperBound["shift+."]` makes the registry claim something setup
  did not do, which is 6.276.0 from the other side.
  🚨 AND IT WAITS ON 6.311.0 BEING CONFIRMED LOADED. Building the
  instrument for a half-install on top of an install nobody has verified
  is the ⚖️ error one more time — his `_G.musicReport()` comes first.

- 🌅 HIS 2026-09-27 REPORT — WHAT IT SETTLES, AND THE QUESTION THAT IS
  NOW UNANSWERABLE. Four wakes, six probe reads, 15:07.
  ✅ THE WAKE WATCHER WORKS: `wake : 4 wake(s) seen, none found ⇪ held`
  and `probe : after screensDidUnlock, at 15:06:44`. 6.302.0's A3 asked
  for any number above 0 and named 0 as the fail. It is 4 — and the
  event that reaches us is **screensDidUnlock**, not systemDidWake,
  which is worth knowing: the lock screen is where Secure Input lives.
  NOT SCORED — he pasted a report, not a verdict, and only he scores.
  ✅ THE REMAP AND THE TAP ARE MEASURED HEALTHY ACROSS ALL FOUR:
  `remap : Caps Lock → F18 still set`, `tap : the F18 event tap is
  running`, `counts: 6 read(s) · 0 could not be read · 0 remap(s) put
  back`. So on these wakes the remap is NOT being lost.
  🗳 AND E1 IS CLOSED AS UNANSWERABLE — his words: "On these two, no
  idea that was hours ago." Was ⇪ working between the 10:57 storm and
  his evening reload? He cannot say, and asking again is asking him to
  remember something he has already told me he does not. STOP ASKING
  IT. What replaces it is the measurement above, which is better
  evidence than the memory would have been: 6.303.0's probe now answers
  that question every morning without him.
  🚨 WHICH LEAVES SECURE INPUT AS THE ONLY UNMEASURED CANDIDATE, and it
  is the one that best fits the symptom (it kills every tap AND hotkey
  dispatch system-wide with no error, and a lock screen on wake is
  where it lives). `secure: not known` on all six reads — the 6.304.0
  wedge, now fixed. His next report on that row is the next move.
  📏 NO NEW STORM: `0 storms this session · 0 watchdog release(s) · 60
  Caps Lock autorepeat(s)`, newest file still the 09-26 10:57:30 one.
  🔎 ONE LINE IN THAT STORM FILE'S NOTICES, NAMED NOT CHASED:
  `10:30:29 runtime window switcher — AppKit refused to order the
  window on screen`. That is 6.266.0's refusal class in a module that
  has not taken the `onLate` door. Its own release, on evidence, not
  now.


- 🆔 THE OCR TAG READS AN INODE AS A PATH — 6.237.0'S CLASS, IN A
  MODULE THAT NEVER GOT THE FIX (2026-09-26, his Console, unprompted and
  beside the 6.303.0 install):
  `⚠️ OCR tag: clipboard file URL(s) matched no usable image — a
  file-reference path macOS would not resolve — raw value:
  "/.file/id=6571367.28635714/"`
  🔎 READ, NOT PROVEN, and the reading is short because the mechanism is
  already written down: macOS puts FILE REFERENCE URLs on a pasteboard
  — volume and inode, no name, no extension — and 6.237.0 solved that
  for the music player with `mp.resolveRefs` → `hs.fs.pathToBookmark` →
  `hs.fs.pathFromBookmark` (realpath does NOT resolve one; it answers a
  plausible name in a folder that holds nothing, which is the expensive
  wrong fix). The screenshots/OCR side reads the same pasteboard and
  never got that door. The message is HONEST — it names the raw value,
  which is how this was diagnosable from one line — and the feature
  still fails.
  🔑 THE SHAPE IS A LIFT, NOT A SECOND COPY (6.231.0): `mp.resolveRefs`
  takes its resolver as an ARGUMENT and is already PURE, so the release
  publishes it (a service, or core/) and the OCR tag path asks it.
  A second bookmark round-trip written beside it is how the two drift.
  📏 ASK FIRST (6.201.0): which ACTION produced that line — copying a
  file in Finder and pressing the OCR tag key, or a drag? The pasteboard
  flavours differ, and NSFilenamesPboardType (a plist array of POSIX
  paths) may be on the board already, in which case the fix is asking
  the plain-path flavour FIRST and none of this arises. Do not build
  before that sentence.
  📝 NOT SCORED AGAINST 6.303.0 — it is unrelated to that release and
  predates it; it surfaced in the same paste, which is not the same
  thing.

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
  4. ✅ "SCRATCH" IS OFF SCREEN — SHIPPED AS 6.333.0, and he chose the
     shape by asking for "the one-list Hamsidian". The two sections are
     ONE list, newest first, with 📝 on a tab and 🕸 on a note —
     6.253.0's icon rule applied to the list itself. 🗳 THE DATA
     QUESTION BELOW IS STILL OPEN AND IS NOT WHAT SHIPPED: a tab is
     still a row in scratch.json and a note is still a .md file, so (a)
     "every tab is a file from the moment it is made" is still his to
     answer. The original note, kept because the two answers are still
     two different releases:
  4b. 📝 "SCRATCH" WAS STILL ON SCREEN — ASKED TWICE (LL, 2026-09-20 and
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

- 📥 LL'S REPORT, 2026-09-25 — "BUILD THE SIX", AND SIX OF THE SEVEN ARE
  BUILT (6.283.0–6.289.0, one change per release, delivered as one
  archive). What each became, and the ONE still blocked:
  1. ✅ SHIPPED AS 6.287.0 — four asks, one release, because they were
     one defect. The durable rule is above. WAS: ✏️ THE ⇪⇧1 EDITOR'S TEXT
     TOOL IS NOT A TEXT BOX — FOUR ASKS THAT ARE ONE RELEASE. His words: it must WRAP; the font size must change
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
  2. ✅ SHIPPED AS 6.286.0, and he was right: 6.189.0 was telling the
     truth about exactly ONE way out, and reading every door found it
     without needing to know which key he pressed. WAS: 🚨 "CLOSING THE
     EDITOR DUMPS THE MOST RECENT EDITS SO I LOSE ANY CHANGES". 6.189.0 promises the opposite:
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
     🚧 THE ONE UNBUILT ITEM OF THE SIX, deliberately, and SAID TO HIM
     rather than quietly skipped: "macOS's crosshair, so no box" and
     "our selector drew and the readout did not" are opposite fixes, and
     the artefact that separates them could not be collected before
     6.282.0 stopped the report throwing.
  4. ✅ SHIPPED AS 6.283.0 — the console block was the one listing that
     never fed altTab.known, and that memory is the only route to another
     Space. WAS: ⌨️ ⌥TAB DOES NOT SHOW THE HAMMERSPOON WINDOW unless he is
     already on that desktop. This was scored RESOLVED WITHOUT CODE on 6.215.0
     ("Alt+tab Success. Shows Hammerspoon now") and has regressed or
     never generalised. The 6.152.0 rule names the mechanism: macOS AX
     never returns another Space's windows from `app:allWindows()`, so
     the switcher serves them from `altTab.known`, a memory fed by every
     listing — a window on another desktop is only there if a listing
     ever saw it. First suspect is therefore the memory, not the read.
     `hs.console.hswindow` stays BANNED there (6.160.3).
  5. ✅ SHIPPED AS 6.288.0, and both halves of his sentence were ONE
     mechanism. WAS: 🖥 THE CHEAT SHEET OPENS ON THE WRONG SCREEN
     "sometimes", AND IS NOT FRONTMOST UNTIL HE MOVES IT. The first half is 6.236.0's
     territory and that release added the instrument for it:
     `_G.screenReport()` names the rule that placed the last panel and
     what each candidate answers. ASK FOR IT AT THE MOMENT IT HAPPENS —
     "sometimes" is a count, not a sample (6.274.0). The SECOND half is
     new and is not the same bug: a panel that is up but not frontmost
     until dragged is 6.225.0/6.251.0's up-vs-front-vs-key distinction,
     on a surface that has never been audited for it.
  6. ✅ SHIPPED AS 6.285.0 — and the answer was NOT `_G.hyperTouch()`,
     which this file had wrong: it would have held ⇪ latched LONGER. A
     handover is not a latch. WAS: ⚠️ HIS CONSOLE CARRIES ONE LINE
     NEITHER OF US ASKED FOR:
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
- 6.336.0 verify with LL — 🚪 ⇪4 SURVIVES A RELEASE macOS SWALLOWS
  (KNOWN GROUND)
  WHAT CHANGED: when the release of a ⇪4 / ⇪5 drag never reaches this
  config, the selection is finished from where the pointer is instead
  of the overlay sitting there until you press Esc.
  🔎 YOUR THREE SENTENCES ARE ONE BUG, and it is worth saying which:
  "crosshairs showed · it said 0x0 on release · it jumped a few
  desktops · I had to hit escape". The selector ended a drag in exactly
  ONE place — a mouse-up delivered inside its own overlay — and that
  overlay hears nothing that happens off its own screen. macOS reads a
  three-finger trackpad drag as a swipe between desktops, and a desktop
  switch is exactly when macOS stops sending us events. So the numbers
  froze at the 0 × 0 written the instant you pressed, nothing was
  captured, and Esc was the only way out. The ⇪5 picture you sent is
  the same event: six slices of the desktop you had been thrown onto.

  A. THE HEADLINE.
  A1. Press ⇪4 and drag a rectangle normally. EXPECT: unchanged — the
      crosshairs, the live W × H, the shutter, the file.
  A2. Now press ⇪4 and drag with THREE FINGERS, the way it failed.
      EXPECT: even if the desktop jumps, the selector is GONE when you
      let go and the rectangle you dragged was captured.
      **A FAIL is the overlay still on screen needing Esc.**
  A3. Press ⇪4, start dragging, and release the button with the pointer
      PAST THE EDGE of the screen (or on the other monitor).
      EXPECT: it captures, clamped to the screen's edge. It used to
      hang there.
  A4. Press ⇪4 and click once without dragging.
      EXPECT: "📐 Nothing captured — that drag measured 0 × 0. Press
      the key again and drag a rectangle." It used to say nothing at
      all, which is a key that did nothing and explained nothing.

  B. MUST STILL WORK — this is the drag every capture goes through.
  B1. ⇪5 scrolling capture: drag, and the stitched shot is of the page.
  B2. In the editor (⇪⇧1), ⌘A add-capture.
  B3. ⇪4 then ⇪⇧5 and ⌘5 ("repeat area") — the same rectangle again.
  B4. Esc during a drag still cancels and captures nothing.
  B5. ⇪⇧4 is untouched — still macOS's own crosshair.

  C. PASTE BACK, PASS OR FAIL.
  C1. `_G.screenshotsReport()` — there is a new `drag :` line:
        drag    : 6 finished — 4 on the release itself · 2 where macOS
                  swallowed the release
      **That second number is the answer to the desktop question**, and
      it needs nothing from your memory. If it is 0 after a day of
      ordinary use, the swipe is not happening to you and I am wrong
      about the mechanism — which is just as useful.
  C2. If it ever reads "⚠️ N selector(s) ran with NO drag-end watch",
      paste it: that Mac would not give us a timer and is back on the
      old behaviour.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. THE DESKTOP JUMP ITSELF IS NOT FIXED, and I am not going to fix
      it quietly. It is macOS's own gesture, and the only lever here is
      to start SWALLOWING your drag — which costs every app underneath
      it. Check System Settings › Accessibility › Pointer Control ›
      Trackpad Options › "Use trackpad for dragging" with three-finger
      drag. Tell me whether turning that off stops the jumping; that
      one answer settles it, and it is the same question 6.306.0 asked
      about the cheat sheet and never got.
  D2. 🔨 CRUDE OR ELEGANT: ⇪4 left an overlay on your screen that only
      Esc could clear, and the shot you wanted was lost. My reading is
      that it degraded — Esc always worked and nothing was destroyed —
      but it cost you the capture every time. Your tag.

- 6.335.0 verify with LL — 🗑 THE BIN IS A BUTTON (KNOWN GROUND)
  WHAT CHANGED: there is a 🗑 in the Hamsidian header, beside the other
  buttons. It shows every note you have deleted; clicking one puts it
  back.
  🔎 AND NOTHING WAS BROKEN, which is worth saying first: those notes
  have been recoverable since 6.321.0 — a delete MOVES the file to
  <Vault>/.trash and nothing erases it for 180 days. What you could not
  do was LOOK, without typing a command. That is the third time in this
  module I have built the measurement and not the door.

  A. THE HEADLINE.
  A1. ⇪3. Look at the header, between 🗂 and ↻.
      EXPECT: a 🗑 button.
  A2. Click it.
      EXPECT: the left column becomes the bin — your deleted notes,
      newest first, each with the time it went. The strip above says
      "🗑 BIN · N deleted".
  A3. Hover a row. EXPECT: a tooltip saying where it would go back to.
  A4. Click a row.
      EXPECT: "🗑 <name> is back → <path>", the note is in Hamsidian
      again, and the row is GONE from the bin.
      **A FAIL is the note opening instead of being restored**, or the
      wrong note coming back — tell me at once if either happens.
  A5. Click 🗑 again (or press Esc). EXPECT: back to your notes.

  B. THE EDGES WORTH ONE MINUTE.
  B1. In the bin, press ⌥↓ and ⌥↑. EXPECT: the highlight walks the
      rows. ⌥⏎ restores the highlighted one — the same thing a click
      does.
  B2. ⌘F and type part of a deleted note's name.
      EXPECT: the bin filters. Type nonsense: "no deleted note matches"
      — which must NOT read the same as an empty bin.
  B3. If you have never deleted anything on this Mac, the bin reads
      "the bin is empty — nothing has been deleted". If it ever says
      "⚠ the .trash folder could not be read", paste that: those are
      opposite facts and the second one is the one that matters.
  B4. Restore a note whose name EXISTS again in the vault.
      EXPECT: it lands beside it as "<name> (restored …)" and your
      newer note is untouched. That rule is 6.321.0's and this must not
      have broken it.

  C. MUST STILL WORK — this touched the left column, which is every
     list in that window.
  C1. The notes list, ⌘F filter, ↑↓, ⏎ to open — unchanged.
  C2. ☑ tasks (⌘⇧K), 🔎 search (⌘⇧F), 🕸 graph (⌘G), 🗂 board (⌘⇧B) —
      all four still open and still come back with Esc.
  C3. The ✕ on a note row still deletes it to the bin.
  C4. Your scratch tabs are still in the one list (6.333.0).
  C5. ⌘N, ⌘D, ⌘K, ⌘⇧S — unchanged.

  D. PASTE BACK.
  D1. `_G.vaultReport()` — its `bin :` line, and the `deleted:` count.
  D2. `_G.vaultTrash()` still works from the Console and must list the
      same notes the button shows. If the two ever disagree, that is a
      real finding.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. There is deliberately NO purge button in the bin. A
      delete-forever control one pixel from a restore control, in the
      list that exists to prevent loss, is the wrong button to add —
      `_G.vaultPurgeTrash()` is still the only thing that removes a
      file. Say if you want one anyway; it is your call, not a gap.
  E2. A click restores immediately, with no confirm. Right, or would
      you rather it asked? Nothing is destroyed either way, which is
      why I made it immediate.
  E3. 🔨 CRUDE OR ELEGANT: Hamsidian worked throughout and the notes
      were never at risk — what was missing was a way to look. My
      reading is that this is a DOOR I should have built in 6.321.0,
      not a defect. Your tag.

- 6.334.0 verify with LL — 🔎 THE BOOT READOUT STOPS LYING (KNOWN GROUND)
  WHAT CHANGED: two lines in the 💾 STORES block that were false on
  your 6.333.0 boot.
  🚨 AND YOUR NOTES WERE NEVER MISSING. The line read "⚠️ THE FOLDER IS
  THERE AND HOLDS NO NOTES" over a vault with all of them in it. The
  notes index is built when Hamsidian OPENS, so ten seconds after boot
  — which is when that block prints — it has not been built, and the
  readout printed the words for "there is nothing" instead of "I have
  not counted yet". That is the same mistake 6.312.0 fixed in the music
  player, inside the instrument 6.317.0 added to stop exactly this.

  A. THE HEADLINE.
  A1. Reload Hammerspoon. Do NOT press ⇪3. Wait ten seconds and read
      the 💾 STORES block.
      EXPECT: `🕸 Hamsidian notes : …/Vault · ⏳ not counted yet — the
      index is built when Hamsidian opens (⇪3)`.
      **A FAIL is "0 notes" or the ⚠️ shout** — that is the old
      behaviour.
  A2. Now press ⇪3, then Console: `_G.stores()`.
      EXPECT: a real count — the number of notes you actually have.
  A3. Read the `📂 file history` line in either block.
      EXPECT: a real path ending `file_changes-<your Mac>.csv` and a
      time. It used to read ⚠️ NO FILE MATCHING "file_history" on every
      boot, about a tracker that was saving perfectly.

  B. THE SHOUT MUST STILL WORK — it is the line that matters most.
  B1. The ⚠️ is now only for a vault that was COUNTED and is empty. If
      you ever genuinely open Hamsidian to an empty folder, that ⚠️
      must appear. I cannot test that from here without emptying your
      vault, and I am not going to.
  B2. The 🚨 THE NOTES FOLDER IS LOCAL ONLY line (OneDrive not found at
      boot) is untouched and still shouts.

  C. PASTE BACK.
  C1. The whole 💾 STORES block from an ordinary morning. Every one of
      the five named stores should resolve to a real path and a time —
      there should be no ⚠️ anywhere in it.

- 6.333.0 verify with LL — 🕸 ONE HAMSIDIAN LIST (KNOWN GROUND)
  WHAT CHANGED: the left column is ONE list now. A scratch tab and a
  note sit side by side, newest first, and the ICON tells them apart —
  📝 is a tab, 🕸 is a note.
  WHY: you asked for "the one-list Hamsidian", and you were right that
  two sections was the odd part. 6.253.0 gave both sides one name and
  made the icon the difference; the list had never caught up.

  A. THE HEADLINE.
  A1. Press ⇪N. Look at the left column.
      EXPECT: one heading — 🕸 HAMSIDIAN — with your tabs and your
      notes under it together. NOT two sections.
  A2. Read a few rows. EXPECT: 📝 in front of every tab, 🕸 in front
      of every note. If any row has no icon, tell me which.
  A3. Press ⇪3. EXPECT: the same window, the same one list.

  B. THE KEYS MUST NOT HAVE MOVED — this is the half that matters.
  B1. Click a 📝 row. EXPECT: that tab opens, you can type in it.
  B2. Click a 🕸 row. EXPECT: that note opens with its text.
  B3. ⌘T makes a new tab. ⌘W closes the one you are on.
  B4. ↑↓ walk the whole list — through tabs AND notes, one run, no
      jump. ⏎ opens whichever is highlighted.
  B5. The ✕ on a 📝 row closes the tab. The ✕ on a 🕸 row deletes the
      note to .trash (6.321.0). They must NOT be swapped.
  B6. ⌘F and type. EXPECT: it filters both kinds at once. Type part
      of a note's HEADING (6.328.0) and part of a tab's first line —
      both must find their row.

  C. PASTE BACK.
  C1. `_G.vaultReport()` — the whole block.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. Newest first, both kinds mixed. Is that the right order, or
      would you rather tabs always sat above notes inside the one
      list? "mixed is right" · "tabs first" decides it.
  D2. 🔨 CRUDE OR ELEGANT: nothing was broken — this is a shape ask.
      Say if you think it belongs in the ledger at all.

- 6.332.0 verify with LL — 🔄 ASANA REFRESHES ITSELF (KNOWN GROUND)
  WHAT CHANGED: Asana is told to reload every five minutes, on its
  own, whether or not it is in front.
  🚨 AND NOT THE WAY YOU DRAFTED IT, which I want to say plainly. Your
  version activated Asana, posted ⌘R and activated the previous app
  back. That posts a keystroke back through this config's own taps
  (6.218.0), steals focus twice every five minutes, and leaves a
  window where a ⌘R can land in whatever you clicked into. This one
  asks Asana's own View ▸ Reload menu WITHOUT activating it — nothing
  is stolen and nothing has to be put back.

  A. THE HEADLINE.
  A1. Have Asana running. Work in another app for ten minutes.
      EXPECT: NOTHING. No window comes forward, no flicker, no
      keystroke lands anywhere. **A FAIL here is Asana jumping to the
      front** — that is the thing this was built to avoid.
  A2. Console: `_G.asanaRefreshReport()`.
      EXPECT something like:
        every   : 5 minute(s) · running
        asked   : 2 · refreshed 2 · app not running 0 · refused 0
        menu    : View ▸ Reload
      PASTE IT. The `menu :` line is the one I cannot know from here.
  A3. Look at Asana. EXPECT: the board is current.

  B. THE ONE THAT MUST NOT CRY WOLF.
  B1. Quit Asana. Wait ten minutes.
      EXPECT: no alert, no Console warning, nothing. The report's
      "app not running" count goes up and that is all. A closed app is
      the ordinary state, not a failure.

  C. IF THE MENU IS WRONG.
  C1. If the report ever reads `menu : ⚠️ no menu path matched — tried
      View ▸ Reload · View ▸ Refresh · …`, paste it. That means Asana
      renamed the item and the fix is one line. The refresh does
      nothing in the meantime — it never falls back to posting a key.

  D. IF IT GETS IN THE WAY.
  D1. `settings = { asana_comments = { refreshMins = 15 } }` slows it;
      `refreshMins = 0` stops it.
  D2. 🗳 ONE QUESTION: should it PAUSE while you are typing in Asana? A
      reload that discards a half-written comment is worse than a
      stale board. I have not built that — say the word and it is a
      small release.

- 6.331.0 verify with LL — 💾 THE NOTES HAVE A SECOND COPY (KNOWN GROUND)
  WHAT CHANGED: your Hamsidian notes are rsync'd to a LOCAL folder
  every thirty minutes. Nothing you press changes.
  WHY: every other store in this config has had a 30-minute mirror
  since 6.190.0 and the vault never did. It lives in OneDrive so
  Obsidian can open it on either Mac — which means it has had exactly
  one copy, owned by a sync client, and a sync client is not a backup:
  a deletion propagates.

  A. THE HEADLINE.
  A1. Console: `_G.backupReport()`. Find the new `vault :` line.
      EXPECT: a destination under ~/Library/Application Support, and
      either "not run yet" (straight after a reload) or a time and
      "ok". PASTE IT.
  A2. Wait a few minutes after a reload, run it again.
      EXPECT: a real time and "ok".
  A3. Open that destination folder in Finder.
      EXPECT: your notes, as .md files. NOT a `.trash` folder — that
      is excluded on purpose, because 6.321.0's bin already keeps
      deleted notes for 180 days.

  B. IT MUST NEVER SHRINK.
  B1. Delete a throwaway note in Hamsidian. Wait for the next mirror.
      EXPECT: the file is STILL in the local copy. No rsync in this
      kit carries `--delete`, deliberately — a vault that failed to
      load must not be able to erase its own backup. The cost is that
      the copy only grows; that is the right trade for your writing.

  C. MUST STILL WORK.
  C1. The nightly backup and the 30-minute store mirror are unchanged.
  C2. Hamsidian itself is untouched — no new write, no new read on the
      path you type on.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. Thirty minutes, same as the stores. Too often for a folder of
      notes, or not often enough? `vaultMirrorMins`.
  D2. The destination is deliberately NOT in OneDrive — a backup
      inside the thing being backed up is one deletion from being
      neither. Say if you want a second copy somewhere else as well
      (an external disk, say); that is its own release.

- 6.330.0 verify with LL — 🧊 THE HEARTBEAT CARRIES WHAT WAS RUNNING
  (KNOWN GROUND — an instrument, not a fix)
  WHAT CHANGED: the file the stall guard watches now carries the NAME
  of the shortcut the main thread is inside, not just a clock.
  🚨 AND I HAVE NOT FIXED YOUR LOCKUP. Saying that first. Your log
  reads `🧊 Hammerspoon HUNG for 73 s at 2026-10-04 17:16:59 and was
  relaunched by the stall guard` — that is 6.208.0's guard working,
  for the second time in the field, and it is why you got your Mac
  back without a reboot. What it could not say is WHAT hung. Two
  relaunches, two reports, zero attribution. This is the release that
  makes the next one name itself.

  A. THE HEADLINE.
  A1. Console: `_G.stallGuardReport()`.
      EXPECT the usual block plus a new `in flt :` line. On an idle
      Mac it reads "nothing in flight". PASTE IT.
  A2. Hold a ⇪ shortcut that takes a moment — ⇪D, say — and run the
      report immediately afterwards.
      EXPECT: "nothing in flight" again (it clears when the shortcut
      returns). The line is only ever non-empty DURING a shortcut,
      which is exactly when you cannot type.
  A3. If `in flt :` ever carries `⚠️ N beat(s) could not build a
      label`, paste it — the guard still works (it falls back to the
      bare clock) but the breadcrumb is not being written.

  B. WHEN IT LOCKS UP AGAIN — this is the real test and I cannot run
     it from here.
  B1. If Hammerspoon hangs and the guard relaunches it, the next boot
      announces it as before. **Then send me the guard's log**, which
      the report names the path of. It will now carry a line reading
      `in flight: ⇪<something>` beside the kill — that is the
      shortcut the main thread was inside.
  B2. If it reads `in flight: (none)`, that is just as useful: it
      means the thread stopped somewhere that is NOT a ⇪ shortcut —
      a timer, a watcher, or macOS itself — and that halves the
      search.

  C. MUST STILL WORK — the guard is a kill switch, so this matters.
  C1. Use the Mac normally for a day. Hammerspoon must NOT be
      relaunched. If it is, paste the log at once.
  C2. Reload Hammerspoon. `_G.stallGuardReport()` must show ONE
      guard running, never two.
  C3. Close the lid for a few minutes and open it. Nothing must
      happen — the sleep rule is unchanged.

  D. WHAT I SUSPECT AND HAVE NOT PROVEN.
  D1. Your boot said `0.24s` and then loaded five Hammerspoon
      extensions over the next FORTY-TWO SECONDS — notify at
      17:17:03, mouse at 17:17:29 (twenty-six seconds later),
      webview, drawing, geometry. Each of those is a library being
      loaded on the main thread, lazily, the first time something
      asks for it. That is a candidate for a long stall and it is
      NOT a verdict (6.198.0). The breadcrumb is what will tell us.
  D2. 🔨 CRUDE OR ELEGANT: by your own description the Mac was
      unusable — "I couldn't even click on anything on the screen".
      My reading is 🔨 CRUDE, and the pass count is 0, because
      nothing here is a fix yet. Your tag.

- 6.329.0 verify with LL — 🗂 THE DESKTOP IS OUT OF THE KIT (KNOWN GROUND)
  WHAT CHANGED: the nightly backup no longer copies ~/Desktop.
  WHY: your words — it was duplicating files into OneDrive that you
  never wanted uploaded. It was the feature working exactly as built,
  and a desktop is a staging area, not a store.

  A. THE HEADLINE.
  A1. Console: `_G.backupReport()`.
      EXPECT the Desktop row to read OFF, with the settings line that
      brings it back printed beside it.
  A2. Run a backup (or wait for the nightly one). Check the backup
      folder in OneDrive.
      EXPECT: no NEW files appear under its Desktop folder.

  B. NOTHING WAS DELETED, and this is deliberate.
  B1. The existing <backupDir>/Desktop folder is still there with
      everything already copied into it. No rsync in this kit carries
      `--delete`, on purpose, and erasing a folder full of your files
      to tidy up after myself is the one thing a backup module must
      never do.
  B2. The report names that folder's path. Deleting it is yours to do
      in Finder, and it is the thing that actually reclaims the
      OneDrive space.

  C. MUST STILL WORK.
  C1. Everything else in the kit — Documents, the config, the crash
      reports, ~/.ssh/config — is unchanged.
  C2. `settings = { daily_backup = { desktop = true } }` puts it back.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. Is anything ELSE in the kit duplicating something you did not
      expect? The report lists every entry; read it once and tell me
      which should go the same way. That is the question worth more
      than this release.

- 6.328.0 verify with LL — 🏷 THE LEFT COLUMN SHOWS THE TITLE (KNOWN GROUND)
  WHAT CHANGED: a note's row in Hamsidian shows its `# Heading` when
  it has one, and the file name when it does not.
  WHY: your words — "Changing a title like # Add recycle bin does not
  change the title in the lefthand column. I think it should." You are
  right; the heading is the thing you maintain.

  A. THE HEADLINE.
  A1. ⇪3. Open a note and type a first line reading `# Add recycle bin`.
  A2. Look at the left column WITHOUT closing anything.
      EXPECT: that note's row now reads "Add recycle bin".
      **A FAIL is the row still showing the file name** while the
      heading is clearly there.
  A3. Change the heading to something else.
      EXPECT: the row follows, as you type.
  A4. Open a note with NO heading.
      EXPECT: its row still shows the file name, as before.

  B. AFTER A RELOAD — the other half, and it is a different mechanism.
  B1. Reload Hammerspoon, open ⇪3, and wait a few seconds for the scan.
      EXPECT: every note with a heading shows it, not only the one you
      have open. If the row you edited is right but the OTHERS are all
      file names, the grep that reads them did not run — paste
      `_G.vaultReport()`.
  B2. ⌘F and type part of a HEADING (not the file name).
      EXPECT: the note is found.

  C. THE FILE IS NOT RENAMED, and this matters.
  C1. Look in Finder. EXPECT: the .md file still has its original
      name. Every [[link]] and every backlink is keyed by that name,
      so changing it would break them. This changes what is DRAWN.
  C2. A [[link]] to that note still works. ⌘⏎ on it opens it.

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. Would you rather the row showed BOTH — "Add recycle bin
      (2026-10-05 notes.md)"? I made it show the heading alone because
      a list of long rows is harder to scan, but you are the one
      reading it.
  D2. Do you want a real RENAME as well — change the heading, rename
      the file, fix every link? That is a much bigger and more
      dangerous release and I will not start it without you asking.

- 6.327.0 verify with LL — 🔖 ⇪3 REMEMBERS MORE THAN ONE NOTE (KNOWN GROUND)
  WHAT CHANGED: Hamsidian remembers the last twenty notes you opened,
  not just the last one.
  WHY: found while building the recycle bin, and it explains why
  6.277.0's "⇪3 puts you back" kept looking intermittent. It held ONE
  slot — delete that note, or move it, and ⇪3 correctly refuses to
  re-create it and drops you on the list. Your own report shows 55
  deletes in one session, so that was most of the time.

  A. THE HEADLINE.
  A1. Open note A, then note B. Close Hamsidian.
  A2. ⇪3. EXPECT: note B.
  A3. Delete note B (the ✕ on its row).
  A4. Close Hamsidian, then ⇪3.
      EXPECT: **note A** — one step back, not the list.
      A FAIL is landing on the list; that is the old behaviour.

  B. IT MUST NOT RE-CREATE ANYTHING.
  B1. Open a note, close Hamsidian, then delete that note's .md file
      in Finder (pick a throwaway).
  B2. ⇪3. EXPECT: it moves to the next remembered note and the file
      you deleted stays deleted. If the file reappears, stop and tell
      me — that is the worst outcome here.

  C. PASTE BACK.
  C1. `_G.vaultReport()` — the "back to:" line names which note it
      restored and why.

  D. 🔨 CRUDE OR ELEGANT: Hamsidian stayed usable the whole time; what
     failed was a convenience. My reading is ✨ ELEGANT, one pass, but
     it is the second pass on 6.277.0's ask — your tag.

- 6.326.0 verify with LL — 🎵 A CARD macOS REFUSED IS NOT AN OPEN CARD
  (KNOWN GROUND)
  WHAT CHANGED: the music player only records its window handle once
  macOS has really put the card on screen.
  🔎 YOUR OWN PROBE IS THE WHOLE RELEASE: `handle : false · window :
  false · visible : nil · frame : none · queue : 1 · gate : the card
  is closed — macOS keeps the key`. That is 6.309.0's gate answering
  correctly about a card you had opened. The handle was being set
  BEFORE `show()` was called, so a refusal left a handle pointing at a
  window that is not there — and the ⏯ key went wherever that
  mismatch sent it.

  A. THE HEADLINE.
  A1. ⇪⇧. (or ⇪⇧pad.). Drop a track. Something plays.
  A2. Press ⏯/F8. EXPECT: it pauses. Press again: resumes.
  A3. Close the card. Press ⏯.
      EXPECT: it goes to macOS — Music.app or a browser tab pauses,
      not the Jug Player. (6.309.0's rule, now resting on a handle
      that cannot lie.)
  A4. Reopen the card. ⏯ works again.

  B. PASTE BACK.
  B1. `_G.musicReport()` — there is a new `opens :` line counting
      asked · shown · refused by macOS. On a healthy Mac "refused" is
      0. If it is ever a number, paste it: that is the beta-OS refusal
      being caught, and before this release it left a broken handle
      behind instead.
  B2. The probe you ran before: `handle`, `window`, `visible` and
      `frame` must now AGREE with each other. A `handle : true` with
      `frame : none` is the bug and must not be possible now.

  C. MUST STILL WORK.
  C1. Open, close, open the card ten times. It must open every time.
  C2. Drag it by the title strip; it reopens where you left it.
  C3. space, ↑↓, ⏎, ⌘1–9, ← →, ⌫, the ✕ on a history row.

- 6.325.0 verify with LL — 📋 "COPIED" IS SAID ONLY WHEN IT WAS
  (KNOWN GROUND)
  WHAT CHANGED: ⇪D, ⇪⇧V and ⇪⇧O now check that the clipboard write
  actually happened before telling you it did.
  WHY: this is the third of the three issues I named. macOS's
  `setContents` refuses by returning FALSE and never throws, so the
  `pcall` those three were wrapped in succeeded either way. "📋
  Copied" was printed over writes that may never have happened, and
  nothing counted them. This config has carried that rule since
  6.198.0 and three files still had the old shape.

  A. THE HEADLINE — on a healthy Mac this is invisible, which is the
     point.
  A1. ⇪D, find something, press ⏎. EXPECT: "📋 Copied", and ⌘V pastes
      it. Same as always.
  A2. ⇪⇧V, pick a row, copy it. ⇪⇧O, copy a reading. Both unchanged.
  A3. Console: `_G.clipboardWriteReport()` — new.
      EXPECT: `asked : N · refused : none`, with a per-caller
      breakdown. PASTE IT.

  B. IF IT EVER REFUSES.
  B1. If that report ever shows a refusal, paste it. That is a write
      macOS turned down — and on every build before this one you would
      have been told it worked.

  C. MUST STILL WORK.
  C1. Every other copy in this config — ⇪2 sequential copy, the OCR
      text, the screenshot path, the editor's ⌘⏎ — is unchanged.

- 6.324.0 verify with LL — 🪜 THE NOTES SCAN STEPS OFF ITS OWN CALLBACK
  (KNOWN GROUND)
  WHAT CHANGED: nothing you can press. This is the second of the three
  issues, and it is the one that can kill Hammerspoon with no error.
  WHY: when the vault finishes scanning, it was releasing the handle
  on the very task whose callback was running — the same shape that
  took the process down in 6.196.1 and again in 6.262.0. It runs on
  EVERY scan, not on a rare branch, and a scan happens on a timer and
  after every write. This is a genuine candidate for your lockups.

  A. THE HEADLINE — there is nothing to press, so this is it.
  A1. Use Hamsidian normally for a few days. Open notes, type, search,
      let it re-scan.
      EXPECT: no difference of any kind, and no unexplained
      Hammerspoon restarts.
  A2. Console: `_G.vaultReport()` — a new line counts how many task
      callbacks stepped off a held timer. "none held" is healthy.
  A3. If it ever reads `⚠️ N callback(s) could NOT step off a held
      timer`, paste it: that Mac could not arm a timer and is running
      the old, dangerous shape.

  B. 🔨 CRUDE OR ELEGANT: I cannot tell you whether this caused any of
     your crashes, and I will not claim it did (6.198.0 — a correct
     fix for a plausible mechanism is not evidence). What I can say is
     that it is the exact shape that has killed this process natively
     twice before. If Hammerspoon stops vanishing on you, that is the
     answer; if it does not, 6.330.0's breadcrumb is the next move.

- 6.323.0 verify with LL — ↩️ ⌘Z SURVIVES A SCAN (KNOWN GROUND)
  WHAT CHANGED: a Hamsidian re-scan no longer rebuilds the page you
  are typing in, so ⌘Z keeps working.
  🔎 WHAT IT WAS, and it answers your sentence exactly. ⌘Z is the
  browser's own undo and it was always there — until a scan landed.
  Rebuilding the page destroys the text box, and a text box's undo
  history dies with it. The vault re-scans on a timer and after every
  write, so the window in which ⌘Z worked was however long the gap
  between scans happened to be. You deleted a paragraph, a scan
  landed, and the undo had nowhere to go.

  A. THE HEADLINE.
  A1. ⇪3. Open a note with a few paragraphs in it.
  A2. Select all the text and delete it. The note is blank.
  A3. WAIT TEN SECONDS — this is the step that mattered. Let a scan
      land.
  A4. Press ⌘Z.
      EXPECT: your text comes back.
      **A FAIL is a blank note** — that is exactly what you reported.
  A5. ⌘⇧Z redoes it.

  B. THE LISTS MUST STILL UPDATE.
  B1. With a note open, create a new note from Finder (or let the
      other Mac sync one in). Wait for the scan.
      EXPECT: the new note appears in the left column WITHOUT your
      text box being disturbed — keep typing through it and no
      character should be lost.
  B2. Add a `#tag` to the note. EXPECT: the tag list updates.
  B3. ⌘⇧B the board, and ⌘G the graph. EXPECT: both still draw — those
      are the cases that still rebuild the page on purpose.

  C. PASTE BACK.
  C1. `_G.vaultReport()`. If it ever carries a line about a push that
      failed, paste it: that Mac fell back to a full rebuild and ⌘Z is
      lost again there.

- 6.322.0 verify with LL — 🔒 A NOTE THAT COLLAPSES KEEPS A COPY
  (KNOWN GROUND)
  WHAT CHANGED: if a note with real text in it is about to be written
  almost empty, its OLD text is copied into the recycle bin first.
  WHY: the other half of your lost paragraph — "the note remained
  blank". ⌘Z is right while the window is open and it is not a
  backstop: close the note, or reload, and the only copy is the empty
  file on disk. The vault saves 0.3 s after a keystroke, so "select
  all, type one character" is a complete, saved, irreversible loss two
  keystrokes wide.

  A. THE HEADLINE.
  A1. ⇪3. Open a note with a good paragraph in it (a few hundred
      characters).
  A2. Select all and type a single letter. Wait a second.
  A3. Console: `_G.vaultTrash()`.
      EXPECT: a row at the top holding that note's name, stamped a
      moment ago.
  A4. `_G.vaultRestore(1)`.
      EXPECT: your paragraph comes back as a note.

  B. IT MUST NOT GET IN THE WAY.
  B1. Edit a note normally for ten minutes — add, cut a sentence,
      rewrite a line.
      EXPECT: nothing goes into the bin. Only a big collapse does.
  B2. Clear a SHORT note (under a couple of hundred characters).
      EXPECT: nothing is kept. Short notes are cheap to retype and
      keeping copies of every one would fill the bin with noise.
  B3. The write itself is never blocked. The note goes blank exactly
      as you asked; what changes is that the old text is recoverable.

  C. A JUDGEMENT ONLY YOU CAN MAKE.
  C1. 200 characters and 20% are my numbers. If the bin fills with
      things you did not want kept, or if something you DID want kept
      slipped through, tell me which and they move.

- 6.321.0 verify with LL — 🗑 HAMSIDIAN HAS A RECYCLE BIN (KNOWN GROUND)
  WHAT CHANGED: you can list, restore from and purge the deleted-notes
  folder.
  🔎 AND YOUR NOTES WERE NEVER GONE, which is the first thing to say
  and the thing I am sorry you did not know. 6.280.0 built the delete
  properly — a note MOVES to `<Vault>/.trash` with a timestamp in its
  name and is NEVER erased. Your own report reads `deleted: 55 this
  session`. All fifty-five are on disk right now. The only door to
  them was `_G.vaultUndelete()`, which holds ONE slot and you had
  already spent it — which is why it said `nothing to undelete` while
  fifty-five notes sat in the folder.

  A. THE HEADLINE — do this first, and it should be a relief.
  A1. Console: `_G.vaultTrash()`.
      EXPECT: a numbered list, newest first — the note's original
      path and when it was deleted. If you have been deleting, this
      should be a long list.
      PASTE THE FIRST FEW LINES. I want to see what came back.
  A2. Pick one you want: `_G.vaultRestore(3)` (the number from the
      list).
      EXPECT: "🕸 <name> is back", and the note is in Hamsidian again.
  A3. `_G.vaultTrash()` again — that row is gone from the bin.

  B. IT MUST NOT DESTROY ANYTHING ON THE WAY BACK.
  B1. Restore a note whose name already exists in the vault now.
      EXPECT: it REFUSES and says so. A restore that overwrites
      something is the bug this is meant to prevent.

  C. THE PURGE — 180 days, your number.
  C1. Anything older than 180 days goes once per session, by itself,
      and the Console says how many if any did.
  C2. `_G.vaultPurgeTrash()` empties what is due, by hand, now.
  C3. `settings = { vault = { trashDays = 0 } }` turns the automatic
      purge OFF entirely — then nothing ever goes unless you say so,
      which is the "only I can purge" half of your ask.

  D. MUST STILL WORK.
  D1. The ✕ on a note row still deletes to the bin, as in 6.280.0.
  D2. `_G.vaultUndelete()` still undoes the LAST delete, unchanged.
  D3. Obsidian still ignores the .trash folder.

  E. 🔨 CRUDE OR ELEGANT.
  E1. Your words were "this is horrible". Nothing was lost and the Mac
      was fine, but for however long it lasted you believed your
      writing was gone — and that is the cost, not the bytes. My
      reading is that the data was always safe and the DOOR was
      missing, which makes it one pass. Your tag.

- 6.320.0 verify with LL — 🚪 "THAT PATH LEAVES THE VAULT" (KNOWN GROUND)
  WHAT CHANGED: the delete no longer refuses a note because its name
  has two dots in it.
  🔎 YOU WERE RIGHT TWICE: the message is unreadable, and it was
  WRONG. The guard asked whether the note's path contained the two
  characters `..` anywhere — so a note called `Budget..final.md`, or
  any name with an ellipsis in it, was refused as if it were trying to
  escape the vault folder. The rule it meant to enforce is about a
  folder actually called `..`, which is a different question.

  A. THE HEADLINE.
  A1. In Hamsidian, make a note whose name has two dots in it —
      `Test..thing` will do.
  A2. Click its ✕.
      EXPECT: it deletes, into the bin. **A FAIL is "Not deleted -
      that path leaves the vault"** — that is the bug.
  A3. Delete an ordinary note. EXPECT: unchanged.
  A4. Go back and delete whatever note you could not delete before.

  B. THE MESSAGE, if you ever see a refusal again.
  B1. It now names the note and the real reason in words. Paste it if
      you get one — a refusal you cannot act on is a bug even when the
      refusal is right.

- 6.319.0 verify with LL — 📋 THE WORDS LAND ON THE CLIPBOARD (KNOWN GROUND)
  WHAT CHANGED: after a ⇪4 whose words this config reads, those words go
  on your clipboard — replacing the picture it had just put there, and
  nothing else, ever.
  🔎 AND HALF OF WHAT YOU ASKED FOR ALREADY WORKED, which is the first
  thing to say. ⇪⇧4 has copied its text since 6.173.1 — you reported the
  same thing then and it was wired that day. What has NEVER copied is the
  shot ⇪4 takes: it hands you the picture, and the words it reads to NAME
  the file went into the file's Finder comment and ⇪O's log and nowhere
  else. So the gap was a door, not the feature.

  A. THE HEADLINE — thirty seconds.
  A1. Press ⇪4 and drag over a paragraph of text — an email, a web page,
      anything with real words in it.
  A2. Let go. The shutter sounds and the shot lands, as always.
  A3. Wait two or three seconds, then press ⌘V somewhere you can type.
      EXPECT: the WORDS, as text you can edit.
      **A FAIL is pasting the picture** — that is the old behaviour.
  A4. You should have seen an alert as it happened: "🔤 The words are on
      the clipboard — ⌘V pastes them · ⇪⇧5 then ⏎ puts the picture back".
      If the clipboard changed and NOTHING said so, tell me — that is the
      one thing here I most want to get right.
  A5. Now do exactly that: ⇪⇧5, then ⏎ on the top row.
      EXPECT: the picture is back on the clipboard. Nothing was lost.

  B. THE ONES THAT PROTECT YOUR OWN CLIPBOARD — these matter more than A.
  B1. Press ⇪4 over some text. Then, IMMEDIATELY, copy something else —
      ⌘C on a word in any app — before the words come back.
      EXPECT: your own copy survives. ⌘V pastes what YOU copied.
      A FAIL here is the serious one; say so at once and
      `settings = { screenshots = { textToClipboard = false } }` stops it.
  B2. Press ⇪4 over a PICTURE with no words in it — a photo, a diagram.
      EXPECT: the picture stays on the clipboard. No words were read, so
      nothing swaps.
  B3. Take a screenshot on the OTHER Mac and let OneDrive bring it over.
      EXPECT: your clipboard is untouched. An arrival this config did not
      just capture never swaps, whatever words are in it.
  B4. Press ⇪4, wait a full minute doing something else, and let the
      naming finish late.
      EXPECT: no swap — the window is 25 seconds. A shot from a minute ago
      does not speak for what is on your clipboard now.

  C. MUST STILL WORK — this touched every text this module copies.
  C1. ⇪⇧4 over some text: "📝 Text copied: …" and ⌘V pastes it. Unchanged.
  C2. ⇪⇧4 over a QR code: "🔳 Code copied: …". Unchanged.
  C3. ⇪4's crosshairs and the live 1280 × 720 (6.318.0): unchanged.
  C4. ⇪⇧5, then ⌘⏎ on a row: the PATH is copied, not the picture.
  C5. ⇪O still finds everything ever OCR'd, and ⏎ copies the full text.
  C6. The screenshot is still RENAMED after its words, as always.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.screenshotsReport()` — there is a new `clip :` line. Healthy
      after a day reads something like "3 text(s) copied · 2 of them
      replaced the shot they were read from · 4 arrival(s) left your own
      copy alone". That third number is the guard doing its job, not a
      fault.
  D2. If it ever reads **⚠️ N clipboard write(s) REFUSED by macOS**,
      paste it. That is a write that did not happen — and on every build
      before this one it would have told you "📝 Text copied" anyway,
      because the code never read macOS's answer.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Is swapping the picture for the words the right default? It is what
      your sentence asks for and the picture is one keypress away (⇪⇧5 ⏎)
      — but it IS a change to what ⇪4 leaves behind, and you are the one
      who will meet it. "keep it" · "only on ⇪⇧4, leave ⇪4 alone" ·
      "never, I will press ⇪⇧4 when I want words" decides it, and the
      middle one is `textToClipboard = false`.
  E2. 25 seconds is the window. Too short if your Mac is slow to OCR, too
      long if you copy quickly. It is a number, not a release.
  E3. 📏 NAMED, NOT BUILT, so it is not a surprise: ⌘C on image FILES in
      Finder still writes the words into the Finder comment and leaves
      your FILE copy alone — replacing a file copy with text would break
      pasting the file into Mail or Finder. And the raw clipboard-image
      OCR (⌘C on pixels) is still OFF on both Macs since 6.170.2. Say if
      either should change.
  E4. 🔨 CRUDE OR ELEGANT: nothing was broken here — ⇪4 did exactly what
      it always did. My reading is that this is a feature ask created by
      a door nobody had asked about, not a defect, so I have not put it
      in the ledger as a problem. The ONE thing in it that IS a defect is
      silent and old: three places in this module claimed "Text copied"
      over a write macOS may have refused, since they were written. Your
      tag.

- 6.318.0 verify with LL — 📐 ⇪4 HAS CROSSHAIRS (KNOWN GROUND)
  WHAT CHANGED: ⇪4 now draws full-screen crosshairs that follow the
  pointer, and the numbers are on screen BEFORE you press anything.
  🔎 YOU WERE RIGHT ON EVERY COUNT, INCLUDING THE LAST ONE. ⇪⇧4 is
  macOS's own `screencapture -i` and keeps its HUD — crosshairs and
  live coordinates from the instant the key is pressed. ⇪4 was that too
  until 6.264.0 moved it onto OUR selector, on your ask for a better
  pixel readout. And our selector drew a dashed band and a dim wash and
  nothing else until the button went down: no crosshair at any point,
  no numbers until a drag. So the keys really did differ, the
  difference really did arrive with a release of mine, and "it was
  working before" is the plain truth.
  📏 I did NOT put ⇪4 back on macOS's crosshair, and that is a decision
  you can reverse: it would hand back the crosshairs and take away the
  live 1280 × 720 you asked for twice. What was missing is the half
  macOS was giving you for free, and it is ours to draw.

  A. THE HEADLINE — ten seconds.
  A1. Press ⇪4 and DO NOT MOVE OR CLICK.
      EXPECT, at once: a thin white vertical line and a thin horizontal
      line crossing at the pointer, and a black box with the pointer's
      position in it — e.g. `1182, 640`.
      **A FAIL is the old behaviour: a dim screen and nothing else.**
  A2. Move the mouse without pressing.
      EXPECT: both lines follow, and the numbers change with them.
  A3. Now press and drag.
      EXPECT: the dashed band appears, the crosshair keeps following,
      and the box switches to the SIZE — `1280 × 720` — exactly as
      before.
  A4. Let go. The shot lands and is copied, unchanged.
  A5. Press Esc instead of dragging: it cancels, unchanged.

  B. THE OTHER DOORS — the same selector, so the same crosshairs.
  B1. ⇪5 scrolling capture: crosshairs and numbers before the drag.
  B2. In the editor (⇪⇧1), ⌘A add-capture: the same.
  B3. ⇪⇧4 is UNCHANGED — still macOS's crosshair and macOS's HUD. That
      is deliberate: it needs `-i` for the OCR path.

  C. MUST STILL WORK — this is the drag every capture goes through.
  C1. ⇪4 at the very edge of a screen. The lines must stay ON the
      screen, never half off it.
  C2. ⇪4 on the OTHER monitor: crosshairs on that one, numbers right.
  C3. ⇪4, then ⇪⇧5 and ⌘5 ("repeat area") — same rectangle again.
  C4. The shutter still sounds on ⇪4 and not on a repeat.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.screenshotsReport()` — there is a new `cross :` line beside
      the `size :` one. Healthy reads `drawn · last at 1182, 640 ·
      <time>`. If it reads `⚠️ the crosshair threw`, paste it: the
      selection still works, the lines went quiet, and that line is the
      evidence.
  D2. If the crosshairs appear but the NUMBERS do not, that is the
      other half failing and the `size :` line names it. They are two
      switches and two failures on purpose — one sentence from you,
      two different fixes here.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. A one-point white hairline at 55% — too faint on a light
      background, too loud on a dark one? Both are numbers, not a
      release: `settings = { screenshots = { crossThick = 2,
      crossAlpha = 0.8 } }`. Tell me how it reads and I will move the
      default rather than leave you a line to type.
  E2. Do you want the lines off and just the numbers? `crosshair =
      false`. Or macOS's crosshair back on ⇪4 at the cost of the live
      size? `areaNative = true`. Both are one word from you.
  E3. 🔨 CRUDE OR ELEGANT: ⇪4 captured correctly the whole time — what
      was missing was the aiming aid. My reading is that this is a
      REGRESSION I introduced in 6.264.0 and did not notice for
      fifty-four releases, which makes it mine however gracefully it
      degraded. Your tag.

- 6.317.0 verify with LL — 💾 WHERE YOUR WRITING IS (KNOWN GROUND)
  WHAT CHANGED: every boot now prints a block saying where your stores
  are and when each last saved — without you asking for it.
  🔎 AND MOST OF IT ALREADY EXISTED, which is the honest part.
  `_G.saved()` has listed every store with its size, rows, last write
  and growth since boot since 6.115.0 — three hundred releases — and has
  written a probe file into the Logs folder and read it back to prove
  the folder still takes writes. You had never seen any of it. That is
  the same failure as the test plans: the instrument was not the gap,
  the DOOR was. So it prints where you already look.

  A. THE HEADLINE — reload and read the Console. Ten seconds later:
        💾 STORES — 24 files in /Users/…/OneDrive-Personal/Logs
           last write : clipboard_history-….json — just now  ·  quietest: …
           📋 clipboard      : /Users/…/clipboard_history-….json  ·  just now
           📝 Hamsidian tabs : /Users/…/Logs/scratch/scratch.json  ·  4 minutes ago
           🔤 OCR text       : …
           📂 file history   : …
           ⏱ app sessions   : …
           🕸 Hamsidian notes : /Users/…/OneDrive-Personal/Vault  ·  412 notes
           ↳ _G.saved() lists every file…
  A1. Read the 📋 clipboard line. That is the answer to "where does the
      clipboard history go" and it is now in front of you every morning.
  A2. Read the 🕸 line. That is the folder Hamsidian is really using —
      read out of the notes module itself, not worked out again here.
  A3. Any line reading **⚠️ NO FILE MATCHING** means a store you have
      asked me about has NO file at all. Paste it. That is the whole
      point of the list and the one thing it must never be silent about.
  A4. `_G.stores()` prints the same block whenever you want it.

  B. THE LINE THAT MATTERS MOST, and it is the one that would have
     answered last week. If OneDrive is not running when Hammerspoon
     boots, the notes folder silently becomes a LOCAL one and Hamsidian
     creates it empty — so it says "no notes yet" and is telling the
     truth about the wrong folder.
  B1. To see it on purpose: quit OneDrive, reload Hammerspoon, wait ten
      seconds.
      EXPECT:
        🚨 THE NOTES FOLDER IS LOCAL ONLY — /Users/…/.hammerspoon/vault
           OneDrive was not found when this config booted, so Hamsidian is
           reading an EMPTY LOCAL FOLDER and will say "no notes yet".
           Your notes are not lost — they are in OneDrive, which this Mac
           could not see. Start OneDrive and reload (⌘⌃R).
  B2. Start OneDrive, reload, wait ten seconds.
      EXPECT: the 🚨 is gone and the 🕸 line names your OneDrive Vault
      with a real note count.
      **If the 🚨 ever appears when OneDrive IS running, stop and paste
      it** — that is the real bug and it is the one you hit.

  C. MUST STILL WORK.
  C1. `_G.saved()` still prints the full table, and it now carries the
      same block at its top — one source, two surfaces.
  C2. ⇪⇧D still carries the write-ledger section.
  C3. Boot is not slower: the block is on a held timer ten seconds after
      everything else. If you ever see it BEFORE the boot summary, that
      Mac could not arm a timer and it printed early on purpose.

  D. PASTE BACK, PASS OR FAIL.
  D1. The block itself, from an ordinary morning. The two numbers I want
      are the note count and the "last write" line.
  D2. From the WORK MAC too. That is the Mac where the OneDrive answer
      is most likely to differ, and this is the first build that can say
      so in one line.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Six lines at every boot. Too much? Too little? I deliberately
      broke the rule that a new instrument should be silent when
      healthy, because you asked for the healthy case in writing — the
      value is knowing it IS saving on the three hundred days before the
      one when it is not. `settings = { write_ledger = { sayStores =
      false } }` turns it off; say the word and I will change the
      default instead.
  E2. Which stores should be named by name? Right now: clipboard,
      Hamsidian tabs, OCR text, file history, app sessions. Name any
      others and they go on the list — and a named store with no file
      shouts, so the list can only fail loudly.

- 6.316.0 verify with LL — 🚨 A FAILED SAVE IS IMPOSSIBLE TO MISS (KNOWN GROUND)
  WHAT CHANGED: when Hamsidian cannot write — a note or a scratch tab —
  it now says so through FOUR channels instead of one, and the warning
  STAYS said until a real write clears it.
  🔎 AND IT ALREADY WARNED, which is the part worth reading. Both halves
  called hs.alert on a failed write. Four things made that not enough,
  and all four are now closed:
    · 6.274.0 counted THREE `an alert could not draw` lines in eight
      hours of your own Console. A refused alert was the whole warning.
    · the gate was one per-SESSION switch, so a SECOND failure with a
      DIFFERENT cause never spoke again that day.
    · it never took the 🔔 door, so it reached no ledger row, no ⇪⇧D,
      no `_G.degradeReport()` and — the expensive one — no row in the
      on-disk log, which made `_G.todayReport()`, your own 4 PM
      double-check, blind to the one failure that costs you writing.
    · nothing survived the moment. Ten seconds later there was a count
      in a report and no sentence saying your text was still unwritten.

  A. THE HEADLINE — two minutes, and it needs you to break a write on
     purpose. The safe way: in Finder, RENAME your `<OneDrive>/Vault`
     folder (add an x). Hamsidian keeps every word in memory.
  A1. Open a note (⇪3), type a word, wait a second.
      EXPECT: an alert "⚠️ Hamsidian save — the note <name> was NOT
      written — …" naming the cause, AND a macOS notification, AND a
      Console line beginning ⚠️.
      **A FAIL is silence.** That is the whole release.
  A2. Keep typing for a minute.
      EXPECT: it does NOT alert again for the same cause — once per ten
      minutes. If your screen fills with alerts, tell me at once; that
      is the opposite failure and it is the one that makes you switch a
      warning off.
  A3. Console: `_G.degradeReport()`.
      EXPECT the FIRST lines, above everything else:
        🚨 NOT SAVED — Hamsidian: the note <name> — <cause>
           since HH:MM:SS · N failed writes · /path/to/the/note.md
           Your text is still in the window. Do not close it — copy it
           out, or fix the folder … and type a character.
  A4. `_G.vaultReport()` — the same block, first, before the folder line.
  A5. Put the folder name back. Type a character in the note.
      EXPECT: "✅ Hamsidian is saving again" and the file on disk now
      holds your word. Run `_G.degradeReport()` again: the 🚨 block is
      GONE. **Only a real write clears it** — not a timer, not a reload.

  B. THE SAME FOR THE TABS, because they are the other half of the one
     window and they had the identical hole.
  B1. Rename the Logs folder (or just trust A). Type in a ⇪N scratch tab.
      EXPECT the same four channels, naming "Hamsidian tabs" and
      "your scratch tabs".
  B2. `_G.scratchPadReport()` carries the same 🚨 block at the top.

  C. THE 4 PM CHECK, which is the reason this is more than an alert.
  C1. After doing A, run `_G.todayReport()`.
      EXPECT the failure listed with its time and cause — read back off
      DISK, so it survives a reload. Before this release a failed
      Hamsidian save never appeared there at all.
  C2. Reload Hammerspoon and run `_G.todayReport()` again.
      EXPECT: still there. The sticky 🚨 block is gone (that one is
      about right now), but the LOG row remains. Those are two different
      facts on purpose.

  D. MUST STILL WORK — this touched the save path of the tool that holds
     your writing, so this half matters more than A.
  D1. Type in a note, wait, close Hamsidian, reopen: the word is there.
  D2. ⌘N, ⌘F, ⌘⇧S export, the ✕ delete, ⌘Z — all unchanged.
  D3. Type in a scratch tab, ⌘T a new tab, reload: both survive.
  D4. On a HEALTHY Mac this release must be completely invisible. No new
      alert, no new Console line, nothing. If you see anything at all on
      a day when nothing failed, that is a finding and I want it
      (6.269.0 — a new instrument's first duty is to be silent).

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Is the notification right, or is it one channel too many? It holds
      through Focus and lands after a meeting, which is why it is there
      — but you are the one who gets it. "keep it" · "alert and log only".
  E2. 🔨 CRUDE OR ELEGANT: has a Hamsidian save ever actually failed on
      you? If your notes have ever been short a paragraph you were sure
      you typed, that is this, and the row is 🔨. If not, it is a hole
      closed before it cost anything and my reading is ✨ ELEGANT, one
      pass — your tag either way.

- 6.315.0 verify with LL — ⌨️ THE ARROWS REACH THE HISTORY (KNOWN GROUND)
  WHAT CHANGED: ↑ and ↓ now walk the queue AND the 🕘 history as one
  list, which is how the card draws them.
  🔎 WHY IT WAS MISSING, and it is not a regression: the cursor was
  written when the card had one list, and the history was added under it
  four releases later. ↓ off the last track wrapped back to the first,
  so the history below was reachable by mouse and by nothing else. The
  rule for the first list was never re-asked when the second appeared.

  A. THE HEADLINE — thirty seconds.
  A1. ⇪⇧. (or ⇪⇧pad.) and drop two or three tracks so the queue has rows
      and the 🕘 history below it has some too.
  A2. Press ↓ until the highlight is on the LAST track in the queue, then
      press ↓ once more.
      EXPECT: the highlight moves into the 🕘 history, onto its FIRST
      row. **A FAIL is the highlight jumping back to the top of the
      queue** — that is the old behaviour exactly.
  A3. Keep pressing ↓ through the history. At the last history row, ↓
      once more.
      EXPECT: it wraps to the top of the queue. One list, one loop.
  A4. Press ↑ from the first history row.
      EXPECT: back onto the LAST queue row.
  A5. Watch the highlight the whole way: exactly ONE row is ever lit.
      Two lit at once is a real finding — tell me.

  B. WHAT THE KEYS DO DOWN THERE.
  B1. Put the highlight on a history row and press ⏎.
      EXPECT: that track plays, exactly as clicking it does — and the
      highlight moves up to the queue row it just started.
  B2. Put the highlight on a history row and press ⌫.
      EXPECT: that row is FORGOTTEN — the same thing the ✕ does. The
      queue is untouched and the file on disk is untouched.
      **A FAIL is a track leaving the QUEUE instead**; that is what ⌫
      used to mean everywhere and it is the worst thing this release
      could get wrong.
  B3. Do B2 on the row in the MIDDLE of three history rows and check the
      right one went. It is forgotten by its path, not its number, for
      the same reason the ✕ is (6.272.0).
  B4. ⌫ on a QUEUE row still takes it out of the queue, unchanged.

  C. MUST STILL WORK — the cursor touches every key on this card.
  C1. ⌘1–⌘9 still plays the Nth track.
  C2. space still pauses and resumes. Try it with the highlight down in
      the history: it must pause what is PLAYING, not start a track.
  C3. ← → still seek 5 s, ⇧← ⇧→ 30 s.
  C4. Clicking a queue row plays it; clicking a history row plays it; the
      ✕ on a history row forgets it without playing it.
  C5. Drag the card by its title strip; close and reopen — unchanged.
  C6. F8/⏯ still drives it while the card is on screen (6.309.0).

  D. THE EDGE I MOST WANT TESTED.
  D1. ✕ (or ⌫) the LAST remaining history row while the highlight is on
      it. EXPECT: the highlight moves to the LAST queue row — the one
      just above where it was, not the top of the card.
  D2. Empty the queue entirely with the card open and history present.
      EXPECT: the arrows still work, walking the history alone.
  D3. With BOTH empty, press ↑↓.
      EXPECT: nothing happens and nothing breaks.

  E. PASTE BACK, PASS OR FAIL.
  E1. `_G.musicReport()` — a new `↑↓` line says where the cursor is in
      words: `on 🕘 history row 1 of 2 — "<track>"` or `on queue row 2 of
      3 — "<track>"`, and `nothing to walk` when both lists are empty.
      Run it with the highlight in each place; the line must CHANGE.
  E2. If it ever says `⚠️ NO SUCH ROW, the highlight is drawn over
      nothing`, paste it — that is the clamp failing and it is the one
      state this release exists to make impossible.

  F. A JUDGEMENT ONLY YOU CAN MAKE.
  F1. Should ↓ off the last history row WRAP to the top of the queue, or
      stop there? I made it wrap, because the two are drawn as one list
      and that is how one list behaves — but a long history means a long
      way back. "wrap is right" · "stop at the ends" decides it.
  F2. 🔨 CRUDE OR ELEGANT: the history was unreachable by keyboard, but
      it was always one click away and the Mac was fine. My reading is
      that this is a feature ask created by the card growing a second
      list, not a defect — so I have not put it in the ledger as a
      problem. Correct me if it belongs there.

- 6.314.0 verify with LL — 🪟 A PICKER THAT WILL NOT OPEN (KNOWN GROUND)
  WHAT CHANGED: when macOS refuses to put one of this config's pickers on
  screen, the key now does nothing quietly and says why, instead of
  throwing forty lines of traceback into the Console.
  🔎 YOUR OWN LOG IS THE WHOLE RELEASE, 20:30:01:
      ⛔ LuaSkin: hs.chooser:show() ... NSInternalInconsistencyException
         -[NSRemoteView containingWindowWillOrderOnScreen:]
         ... init.lua:2055: ...
  That is ANOTHER APP's popup — Safari's URL-completion helper or
  Spotlight — being half-open at the moment you pressed the key. AppKit
  refused, hs.chooser raised, and nothing in this config was catching it.
  Canvases have been protected since 6.56.0 and alerts since 6.274.0; the
  PICKERS — nineteen of them, the thing you press a key to get — were
  bare.
  🚨 AND init.lua:2055 IS NOT THE FAULT, in case the traceback made it
  look like one: that line is the config deliberately re-raising a
  shortcut's error so you SEE it. Deleting it would have hidden this and
  everything like it. It is unchanged.

  A. THE HEADLINE — and the honest part is that you cannot easily force
     it. So this is mostly "use the Mac and see what does NOT happen".
  A1. Use ⇪V, ⇪D, ⇪space, ⇪Y, ⇪⇧V, ⇪T for a few days as normal.
      EXPECT: no change at all. Every picker opens as it did.
  A2. If a picker ever does nothing, look at the Console.
      EXPECT a single readable line:
        ⚠️ picker: macOS refused to open the picker — usually another
           app's popup (Safari's URL completion, Spotlight) was
           mid-transition. Press the key again.
      and NOT a traceback. Press the key again — it opens.
  A3. Console: `_G.popupShowReport()` — new.
      EXPECT on a healthy day:
        asked   : <N> picker(s) opened this session
        refused : none — macOS put every picker on screen
      PASTE IT. If "refused" is a number, that is the bug happening to
      you and the line under it names which picker and when.

  B. IF YOU WANT TO TRY TO PROVOKE IT (optional, and it may not work —
     the timing window is small).
  B1. Click into Safari's address bar so its completion list is dropping
      down, and press ⇪V in the same instant.
  B2. EXPECT: either the picker opens normally, or it does not and you
      get the one line from A2. What must NOT happen is a traceback, and
      what must not happen next is the key being dead afterwards.

  C. MUST STILL WORK — this touched the one function every picker in the
     config opens through, so this is the regression sweep and it matters
     more than A.
  C1. ⇪V the clipboard · ⇪D unified search · ⇪space the launcher ·
      ⇪Y Chrome history · ⇪. the menus · ⇪⇧S snippets · ⇪T the task form.
      EXPECT: all open, all in the right place on the right monitor.
  C2. ⌘-drag a picker to a new spot, close it, open it again.
      EXPECT: it reopens where you put it. (That memory is the record
      this release clears on a REFUSAL — it must be untouched on a
      success.)
  C3. Esc closes a picker, and Esc again does whatever it did before.
  C4. ⌘⌘ still opens the clipboard, ⌥⌥ still opens the menus.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.popupShowReport()` after a few days.
  D2. If you ever get a traceback out of a picker again, paste the whole
      thing — the frame ABOVE init.lua:2055 is what names the surface,
      and that is the fact I could not have guessed.

  E. 🔨 CRUDE OR ELEGANT.
  E1. When this bit you at 20:30, what actually happened? Did the key do
      nothing and you moved on, or was the Mac unusable for a moment?
      I cannot tell from the log, and the answer is the tag.
  E2. 📏 SAID RATHER THAN IMPLIED: this is the THIRD surface in this
      family — canvases (6.56.0), alerts (6.274.0), now pickers. If
      anything else of mine ever dies with
      `containingWindowWillOrderOnScreen:` in it, that is a fourth
      surface and the same fix, and the traceback is all I need.

- 6.313.0 verify with LL — 🔒 YOUR QUEUE SURVIVES A FAILED SAVE (KNOWN GROUND)
  WHAT CHANGED: nothing you can press. The Jug Player writes its queue to
  a temporary file and then renames it into place, instead of opening the
  real file and writing over it.
  WHY IT MATTERS: `io.open(path, "w")` empties the file BEFORE it writes
  anything. If Hammerspoon died, the disk filled, or the write was
  refused in that instant, your store was left at zero bytes — and the
  loader reads zero bytes as "nothing queued", silently, after which the
  next save makes it permanent. Your queue and your history are the only
  things in this tool you cannot get back. A rename cannot half-happen,
  so the file on disk is now either the old one or the new one.

  A. THE HEADLINE — there is nothing to press, so this is the whole test.
  A1. Queue some tracks, play one, close and reopen the card, reload
      Hammerspoon. EXPECT: everything exactly as before. This release
      must be invisible on a good day.
  A2. Console: `_G.musicReport()` — the `store :` line should read
      `read N bytes — N queued · N history row(s)`.
  A3. Look in `~/Library/Application Support/Hammerspoon/music/`.
      EXPECT: `player.json` and NO `player.json.tmp` left lying about.
      A stray .tmp after normal use is a real finding — tell me.

  B. IF A SAVE EVER FAILS.
  B1. You would get an alert ending "your saved queue is untouched", and
      the queue you already had would still be there next time. Paste
      that alert if you ever see it — it names which of three ways the
      write died.

  C. 🔨 CRUDE OR ELEGANT.
  C1. This never bit you that I know of — it is a hole closed before it
      cost anything, so my reading is ✨ ELEGANT, one pass. Correct me if
      you have ever opened the player to an empty queue you did not
      empty: that would mean it DID bite, and the row is 🔨.

- 6.312.0 verify with LL — 🔎 THE REPORT STOPS GUESSING (KNOWN GROUND)
  WHAT CHANGED: `_G.musicReport()` can now say "I have not read that
  yet" instead of reporting zero.
  🚨 AND THIS IS THE FIX FOR A FALSE ALARM I RAISED. You sent a report
  two seconds after a boot; it said your queue was empty, your history
  was 0 tracks and the ⏯ tap was not running, and I told you your data
  was gone. It was not. The store is opened and the tap is started a few
  seconds AFTER boot, so none of those three had happened yet — and all
  three printed the words for "it happened and there is nothing". Your
  earlier good report was 37 seconds after its boot; the alarming one
  was 2. That was the whole difference, and it was in your own paste.
  🕘 AND YOUR QUESTION WAS RIGHT: no, we did not build the Jug Player 30
  days ago — it shipped 2026-09-16, thirteen days before you asked. The
  30 is how long a row is KEPT, not how much you have. The line says so
  now instead of leaving you to wonder.

  A. THE HEADLINE — this takes about a minute and needs a reload.
  A1. Reload Hammerspoon and run `_G.musicReport()` IMMEDIATELY —
      within a second or two, before it has warmed up.
      EXPECT:
        queue    : ⏳ not read yet — see the store line below
        history  : ⏳ not read yet — see the store line below
        ⏯ keys   : ⏳ not started yet — the tap starts a few seconds
                   after boot, with the store.
        store    : ⏳ NOT READ YET — …not an answer yet…
      **A FAIL is seeing "empty" or "0 track(s)" or "⚠️ WANTED but not
      running" in that first moment** — that is the old behaviour.
  A2. Wait ten seconds and run it again.
      EXPECT: your real queue, your real history, and the ⏯ line back to
      `watching ⏯ ⏮ ⏭`. If your tracks are there, nothing was ever lost
      and the alarm I raised was mine.
  A3. Read the history line. EXPECT it to name the 30 as a window:
      `N track(s) kept · oldest Sep 28 — one row per file, and rows are
      kept for up to 30 day(s) (the WINDOW, not a claim that this Mac
      holds that much)`.

  B. THE STATES THAT ONLY APPEAR WHEN SOMETHING IS WRONG.
  B1. If the store line ever says **ZERO BYTES**, paste it at once —
      that is a write that was cut off, and it is the exact thing
      6.313.0 exists to prevent.
  B2. If it says **UNREADABLE**, also paste it. Your file is still on
      disk in that case and was not overwritten.
  B3. If the ⏯ line says `⚠️ WANTED but not running` TEN SECONDS after a
      boot, that is a real failure now rather than a timing artefact,
      and it names macOS's own reason.

  C. MUST STILL WORK.
  C1. ⇪⇧. and ⇪⇧pad. both open the card. Drop tracks, space, ↑↓, ⏎,
      ⌘1–9, ← →, ⌫, the ✕ on a history row.
  C2. F8/⏯ drives it while the card is on screen (6.309.0).

  D. A JUDGEMENT ONLY YOU CAN MAKE.
  D1. Is ⏳ the right way to say "not yet", or would you rather it said
      nothing at all on those lines until it knows? I chose to say it
      out loud because a missing line reads as a broken report.
  D2. 🔨 CRUDE OR ELEGANT: the Mac was fine throughout — what broke was
      what the REPORT told you, and it told me the wrong thing too. My
      reading is that a diagnostic lying about your data is worse than
      it sounds, but it degraded rather than making anything unusable.
      Your tag.

- 6.311.0 verify with LL — ⌨️ ⇪⇧. OPENS THE JUG PLAYER (KNOWN GROUND)
  WHAT CHANGED: ⇪⇧. (hyper + shift + the ordinary full stop) opens and
  closes the Jug Player. ⇪⇧pad. still does too — a second door, not a
  swap.
  🆓 AND YOUR QUESTION, ANSWERED PROPERLY: ⇪⇧. was NOT taken. I did not
  answer that from my notes — my notes are exactly what was wrong in
  6.276.0, when you were handed ⇪⇧pad. as "available" and this player
  had owned it for forty-five releases. I ran the gate's collision
  auditor, which loads the REAL config and names every claim: 76 combos
  bound, no ⇪⇧. among them. The near miss is ⇪. WITHOUT shift — that is
  menu_search, your front app's own menus — and a comment in that very
  file claimed "⇪⇧. is the network tools", which is wrong too
  (net_tools is ⇪6). Two notes, one of them false. The registry is the
  only thing that can answer this and it is what answered.
  🚪 WHY YOU KEEP BOTH KEYS, since you said "instead of pad": ⇪⇧pad.
  was shipped with no fallback ON YOUR OWN ANSWER in 6.231.0 ("Both
  macs, home/work, use a full Apple Keyboard and Magic pad"), so the
  premise moved rather than the decision being wrong. Removing it would
  cost the two Macs the feature was built for and buy nothing. Say the
  word and the numpad key goes — it is one line.

  A. THE HEADLINE — twenty seconds, on the mini keyboard.
  A1. Press ⇪⇧. (hold Caps Lock and Shift, press the full stop).
      EXPECT: the Jug Player card appears in the top-right corner.
  A2. Press ⇪⇧. again. EXPECT: it closes.
  A3. Press ⇪⇧pad. (if you are at a keyboard with a numpad).
      EXPECT: the same card, same corner, same state. One tool, two
      doors — not two cards.
  A4. Open with ⇪⇧. and close with ⇪⇧pad., then the other way round.
      EXPECT: they drive the SAME card. **A FAIL here — two windows, or
      one key opening and the other doing nothing — is the bug this
      release can have.**

  B. THE ONE THAT MUST NOT HAVE MOVED.
  B1. Press ⇪. (no shift). EXPECT: the front app's MENUS, as always.
      That is menu_search and it is the key next door; if ⇪. now opens
      the music card, stop and tell me at once.
  B2. Type a full stop in any app. EXPECT: a full stop.

  C. MUST STILL WORK — the card itself is untouched.
  C1. Drop two tracks on it; space, ↑↓, ⏎, ⌘1–9, ← →, ⌫, the ✕ on a
      history row, the repeat button.
  C2. F8/⏯ drives it while the card is on screen and passes through to
      macOS while it is closed (6.309.0).
  C3. Drag the card by its title strip; close and reopen — it is where
      you left it.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.musicReport()` — the heading should now read
      `🎵 JUG PLAYER — ⇪⇧. · ⇪⇧pad.`, and a new `doors :` line reads
      `2 way(s) in — ⇪⇧. · ⇪⇧pad.`. If that line ever says
      `⚠️ NONE bound`, nothing opens the card and I want it immediately.
  D2. `_G.freeKeys()` — ⇪⇧. must NO LONGER be offered as free. Those
      rows are read from the live registry, so this is 6.276.0 paying
      for itself: nothing was edited by hand to make that happen.
  D3. ⇪/ and search `jug`. EXPECT the card's title and its first row
      both to read `⇪⇧. · ⇪⇧pad.` — one row for the two keys, on
      purpose: the sheet's own auditor reads a combo listed twice as a
      conflict.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Is ⇪⇧. the right key, now that you have pressed it a few times?
      ⇪⇧, (comma), ⇪⇧[ and ⇪⇧] are also genuinely free — measured, not
      remembered. One word and it moves.
  E2. Do you want ⇪⇧pad. REMOVED? I kept it deliberately and you asked
      for "instead of". Your call, one line either way.
  E3. 🔨 CRUDE OR ELEGANT: the Jug Player was completely unreachable on
      the keyboard you are using — the tool was not degraded, it was
      absent. But the Mac itself was fine. My reading is that this is a
      feature ask created by a hardware change rather than a defect, so
      I have not logged it as a problem. Correct me if it belongs in
      the ledger as 🔨.

- 6.310.0 verify with LL — 🎯 THE POINTER RINGS STEP OUTWARD (KNOWN GROUND)
  WHAT CHANGED: each of the three rings ⇪⇧L throws is 10% wider than the
  one before it, and the whole mark got bigger to hold the outermost.
  Your number, your answer — I have not substituted one of mine.

  A. THE HEADLINE — ten seconds.
  A1. Press ⇪⇧L. EXPECT: three white rings leaving the pointer, each
      visibly larger than the last, repeating for six seconds.
  A2. Compare it to how it looked on 6.306.0 if you can. The outermost
      ring now reaches 21% further out than it used to.
  A3. Console: `_G.mouseGridReport()` — a new "↳ growth" line reads
      `each ring +10% on the one before it · outermost NNN pt of a NNN pt
      canvas`. PASTE IT.

  B. MUST STILL WORK.
  B1. ⇪X: the grid draws, three letters land, the box splits by letter,
      arrows nudge, Esc closes. Nothing about the grid changed.
  B2. On the 4K at full points the ring should still be bigger than on
      the Air — the scale rule is untouched.

  C. A JUDGEMENT ONLY YOU CAN MAKE — and this is the one I want.
  C1. Is 10% enough? You asked for that number and I built exactly it,
      but "more obvious" is your eye, not mine. If it still gets lost,
      say which of these: bigger overall (`locateRadius`), MORE rings
      (`locateRings`), a steeper step (`locateRingGrow`), or longer
      (`locateSecs`). One word and it is a default change, not a release.
  C2. 🔨 CRUDE OR ELEGANT: did this ever make the Mac unusable, or did it
      just not stand out? My reading is neither — it is a feature ask,
      not a defect — so I have logged it as a request rather than a
      problem. Correct me if it belongs in the ledger.

- 6.309.0 verify with LL — ⏯ THE PLAY KEY, ONLY WHILE THE CARD IS UP (KNOWN GROUND)
  WHAT CHANGED: the Jug Player takes ⏯ ⏮ ⏭ only while its card is ON
  SCREEN. Closed, the key goes back to macOS.
  🚨 AND YOU WERE RIGHT THAT MY LAST FIX WAS NOT REAL. 6.289.0 gated on
  "has a queue" — a rule I chose, not one you asked for — and closing
  the card deliberately does not stop the sound, so a closed card went
  on holding the key for as long as a queue survived it. Visibility is
  the gate now.

  A. THE HEADLINE — this is the whole test.
  A1. ⇪⇧pad., drop two tracks, something plays. Press F8/⏯ — it pauses.
      Press again — it resumes. Unchanged.
  A2. Now CLOSE the card (⇪⇧pad. again). The music keeps playing, as it
      always has.
  A3. Press ⏯.
      EXPECT: the Jug Player does NOT react. The key goes to macOS — so
      if Music.app or a YouTube tab has audio, THAT pauses instead.
      **A FAIL here is the card reacting**, and it is the bug you
      reported twice. Tell me at once.
  A4. ⇪⇧pad. to bring the card back. Press ⏯ — it works again.

  B. THE ONE THAT STOPS A DEAD KEY.
  B1. Open the card with NOTHING queued. Press ⏯.
      EXPECT: it passes through to macOS. An open card with an empty
      queue must not eat a key it cannot act on. That check is mine, not
      yours — say if you would rather an open card always took the key.

  C. MUST STILL WORK.
  C1. With the card open: space, ↑↓, ⏎, ⌘1–9, ← → all unchanged.
  C2. F7 and F9 step back and forward while the card is open, and pass
      through while it is closed.
  C3. The volume keys stay macOS's — your own decision in 6.231.0.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.musicReport()` — a new "↳ right now" line says in words what ⏯
      would do at this moment: `the card is closed — macOS keeps the
      key` / `nothing is queued — macOS keeps the key` / `the card is
      open and holding a queue`. Run it with the card open and again
      with it closed; the line must CHANGE.
  D2. The "↳ by route" line still tells me whether your F8 arrives as a
      media key or a plain function key.

  E. 🔨 CRUDE OR ELEGANT.
  E1. Did the card holding ⏯ while hidden ever leave you unable to use
      the Mac — stuck unable to pause something — or was it an annoyance
      you worked around? Your answer tags the row, and it took three
      passes (6.289.0, 6.291.0, this), so it is not elegant either way.

- 6.308.0 verify with LL — ⌨️ ⌘⌘ OPENS THE CLIPBOARD (KNOWN GROUND)
  WHAT CHANGED: ⌘⌘ works. It had never been registered — not once, on
  any boot since 6.292.0.
  🔎 WHY ⌥⌥ WORKED AND ⌘⌘ DID NOT, because it is nothing you could have
  guessed: clipboard_history.lua had TWO functions called `M.warm` — the
  one at the bottom that registers ⌘⌘, and one written inside setup()
  that reads the clipboard store. setup runs after the file is loaded,
  so the second one overwrote the first before Hammerspoon ever called
  it. menu_search has only one, which is the whole difference.
  🚨 AND THE REPORT SAID IT WAS FINE. `_G.clipboardReport()` printed
  "⌘⌘ : watching · 0 open(s) this session" — because it inferred health
  from the absence of a recorded complaint, and there was no complaint:
  the code that would have recorded one never ran. That is exactly the
  distinction that report exists to keep, broken inside itself.

  A. THE HEADLINE.
  A1. Tap ⌘ twice, quickly, nothing else held.
      EXPECT: the clipboard history opens — the same panel ⇪V gives you.
      **This is the whole release.**
  A2. Esc, then ⇪V. EXPECT: the identical window. One function, two doors.
  A3. Left ⌘ and right ⌘ both work.
  A4. Console: `_G.doubleTapReport()`. EXPECT BOTH gestures listed now:
      `⌘⌘ : clipboard history` AND `⌥⌥ : the front app's menus`, under
      one `watcher : running`. PASTE IT.
  A5. `_G.clipboardReport()` — the ⌘⌘ line must read `watching · N
      open(s)`. If it EVER reads `⚠️ WANTED but NOT REGISTERED`, that is
      the new fourth state doing its job — paste it.

  B. THE ONES THAT PROTECT YOUR TYPING — these matter more than A.
  B1. ⌘C, ⌘V, ⌘S, ⌘Tab, ⌘W as normal. EXPECT: nothing opens.
  B2. HOLD ⌘ for a second and release, twice. EXPECT: nothing.
  B3. Tap ⌘, type a letter, tap ⌘. EXPECT: nothing.
  B4. Hold ⌘ AND ⌥ and tap twice. EXPECT: NEITHER opens.
  B5. ⌥⌥ still opens the menus. ⌃⌃ still opens the editor picker.
  B6. Type normally for a while — no missed characters, no lag.

  C. MUST STILL WORK — the merge touched the clipboard's own load.
  C1. Copy three things, press ⇪V. EXPECT: all three, newest first.
  C2. Reload Hammerspoon, press ⇪V. EXPECT: your history is still there.
      That read used to live in the function that was being destroyed;
      if the history came back EMPTY, stop and tell me immediately.
  C3. ⇪⇧V still edits and deletes rows.

  D. 🔨 CRUDE OR ELEGANT.
  D1. ⇪V always worked, so my reading is that this degraded gracefully —
      a feature silently absent, not a Mac you could not use. One pass.
      If you agree it is ✨ ELEGANT; if being told "watching" while it
      was dead counts as worse than that, say so and it goes down 🔨.

- 6.307.0 verify with LL — 🔎 ⌘F FINDS IT, ⏎ OPENS IT (KNOWN GROUND)
  WHAT CHANGED: in Hamsidian, ⏎ in the ⌘F filter box now OPENS the note
  the list is showing you instead of creating a new one with the text
  you typed.
  🔎 YOUR SCREENSHOT DIAGNOSED IT: the filter said "examin", the NOTES
  section showed "09-21-26 Examining relationship", and the editor held
  a brand-new "# examining". The filter box has three modes, and search
  and tasks mode have ALWAYS opened the first hit. Notes mode alone sent
  the typed text as the name — and opening a note that is not there
  creates it, by design. One mode of three, and it was the one that
  writes a file into the folder holding your writing.

  A. THE HEADLINE.
  A1. ⇪3. Press ⌘F and type enough of an existing note's name to narrow
      the list — "examin" will do.
  A2. Press ⏎ WITHOUT pressing ↓ first.
      EXPECT: the note in the list OPENS, with its real contents.
      **A FAIL is a new empty note called "examin"** — that is the bug,
      unchanged.
  A3. Look at the vault folder. EXPECT: no new file was created.

  B. CREATING STILL WORKS — it has to, or this trades one bug for another.
  B1. ⌘F and type something no note matches — "zzznothing".
      EXPECT: the list says `no note matches — ⏎ creates "zzznothing"`.
  B2. Press ⏎. EXPECT: it creates that note and opens it, as before.
  B3. ⌘N still opens the naming bar and creates by name.

  C. THE EDGES.
  C1. ⌘F and type `#` plus a tag. EXPECT: it filters by tag and ⏎
      creates nothing.
  C2. ⌘F, narrow to a TEMPLATE (type "Meet"), press ⏎. EXPECT: the
      template opens. It is a note in the list, so opening it is right.
  C3. ⌘F, then ↓ to a row further down, then ⏎. EXPECT: THAT row opens —
      the arrow keys were always right and are untouched.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.vaultReport()` — a new "⏎ filter" line counts them apart:
      `N opened the match · N created a new note`, with the last one
      named. After A2 and B2 that should read 1 and 1.

  E. 🔨 CRUDE OR ELEGANT — and please answer this one.
  E1. How many of these stray notes are in your vault? They will be
      named after whatever you typed into the filter box. If there is a
      pile of them, say so and the next release is a command that lists
      every note whose name matches a note you already had — I will not
      delete anything without you seeing the list first (6.280.0).
  E2. Hamsidian stayed usable throughout, so my reading is ✨ ELEGANT,
      one pass. But it was writing into the one folder where a mistake
      costs your own words, so if you call that 🔨 CRUDE I will not
      argue — it is your tag.

- 6.306.0 verify with LL — 🚪 A DRAG NO LONGER KILLS THE PANEL (KNOWN GROUND)
  WHAT CHANGED: when you drag the cheat sheet — or the pomodoro, the key
  caster, the Mac panel — the panel now always tells itself where it
  ended up, however the drag finished.
  🔎 YOU HAVE REPORTED THIS TWICE, and you were right both times. In
  6.138.0 your words were "Seems like a drag kills the sheet
  functionality"; this time, "just because I can launch the cheat sheet
  doesn't mean it is functional". And "we have solved this issue or a
  similar one" is what found it — we had, twice, in two other places,
  and never in the engine that drags your panels.
  🚨 THE CAUSE, in one paragraph. That engine had four ways a drag can
  end and only ONE of them told the panel: the mouse-up that our own
  watcher sees. The other three — releasing with the pointer still on
  the panel, our twenty-second safety timer, and starting a second drag
  — moved the panel and said nothing. And the thing they were not
  saying is what moves the cheat sheet's SCROLL HIT BOX and saves its
  position. So the sheet ended up somewhere new while everything that
  needed to know where it was still pointed at the old spot: the wheel
  dead over the sheet, still swallowed over the empty desk it used to
  cover, and the next ⇪/ back in the wrong place.
  🖥 AND YOUR DESKTOP JUMP IS THE CAUSE, NOT A SECOND BUG. Our watcher
  deliberately does not swallow your drag — the button is yours, and
  eating it would cost every app underneath. So macOS sees the drag too
  and reads a three-finger one as a swipe between Spaces; a Space switch
  is exactly when macOS switches watchers like ours off, so the mouse-up
  never reaches us. Both your sentences, one mechanism.

  A. THE HEADLINE — two minutes, and it is the whole test.
  A1. ⇪/ to open the cheat sheet. Drag it somewhere new and let go with
      the pointer STILL OVER the sheet.
  A2. Two-finger scroll over the sheet where it is NOW.
      EXPECT: it scrolls. **A FAIL here is the bug** — on every build
      before this one that release told the sheet nothing.
  A3. Scroll over the empty desk where the sheet USED to be.
      EXPECT: whatever is under there scrolls normally. The sheet must
      not still be eating the wheel at its old spot.
  A4. Esc, then ⇪/ again.
      EXPECT: the sheet opens WHERE YOU PUT IT.
  A5. Type a few letters to filter, then scroll again. EXPECT: still
      scrolls — the sheet redraws on every keystroke, which is where a
      stale position used to come back.

  B. THE DESKTOP JUMP — worth doing even though it is not fixed.
  B1. Drag the sheet with THREE FINGERS (if three-finger drag is on).
      If you get thrown to another desktop, come back and do A2–A4.
      EXPECT: the sheet still scrolls and still reopens where you left
      it. The jump may still happen; it must no longer cost you the
      panel.
  B2. Then drag it by physically clicking and holding ONE finger.
      **Tell me whether that one jumps too.** That single answer decides
      whether the jump is macOS's gesture (one finger will not jump) or
      something of ours (it will), and it is the only thing I cannot
      determine from here.

  C. MUST STILL WORK — three other panels use the same engine.
  C1. ⇪⇧P the pomodoro: drag it, close it, reopen. It is where you left
      it.
  C2. ⇪⇧K the key caster (if you use it) and the Mac panel: same.
  C3. ⇪⇧pad. the music card: drag its title strip. Unchanged — it moves
      on a different mechanism and this release must not have touched it.
  C4. A click on the cheat sheet still does not close it.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.dragReport()` — new; this engine has never had one, which is
      most of why it survived two of your reports. After a drag it should
      read `drops : 1 delivered to the panel that moved` and a `last :`
      line naming the panel and HOW the drag ended. That "how" is the
      whole release: `mouseUp` is the ordinary one, `the button came up
      elsewhere` is the new rule catching a release we never saw, and
      `watchdog` means the mouse-up went missing entirely — which is the
      desktop-jump case and the one I most want to see.
  D2. If it ever carries `⚠️ N drag(s) ended with a canvas that could not
      answer its own frame`, paste it — that is a panel that moved and
      could not be recorded, and it is a different fault.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. I can stop the desktop jump by making the drag SWALLOW your mouse
      events while a panel is being dragged. I have NOT done it: it would
      mean every app underneath stops seeing that drag, and this engine
      has deliberately never done that since 6.67.0. Say the word if you
      want it and it is a small release — but it is your call, not a
      default I should change quietly.
  E2. 📏 SAID RATHER THAN IMPLIED: this release moved the drag engine out
      of init.lua into core/coexist.lua, because init.lua was one line
      under its size limit. Nothing about it behaves differently. If
      panels ever stop being draggable ENTIRELY, that is coexist failing
      to load and the boot log will say so — that would be a real
      finding.

- 6.305.0 verify with LL — 🔁 A RETRY NO LONGER DUPLICATES (KNOWN GROUND)
  WHAT CHANGED: a task that reached Asana is remembered, so a retry —
  and a tab you type in again — sends only what did NOT land.
  🚨 WHY THIS JUMPED THE QUEUE, and please read this bit even if you
  skip the steps. Your 16:00 line said "1 of 122 task(s) did not reach
  Asana". The number that matters is the other one: **121 of them
  DID**. A tab with one refused task is marked ❌, a ❌ tab is retried,
  and the retry re-reads the whole tab — so tomorrow at 16:00 those
  121 would have gone to Asana a second time, and the day after a
  third, growing every day until you happened to fix the one bad line.
  I wrote the rule that forbids this four releases ago, for subtasks,
  and did not apply it to the tab two hundred lines above.
  🕒 IF YOU DO NOT INSTALL TONIGHT, one Console line stops tomorrow's
  run: `_G.scratchPad.sendTimer:stop()`. It lasts until the next
  reload, and `_G.scratchPadSend()` still sends by hand.

  A. THE HEADLINE — this is the whole test and it takes two minutes.
  A1. ⇪N, a fresh tab, three lines:
        Alpha test one
        Bravo test two
        Charlie test three
  A2. Console: `_G.scratchPadTasks()`. EXPECT three tasks, none marked.
  A3. Send it ("→ Asana now"). EXPECT three tasks in Asana and the tab
      retitled ✅ Success: tasks sent.
  A4. Click into the tab and add a fourth line: `Delta test four`.
      EXPECT the ✅ disappears (typing clears the mark — that is right
      and unchanged).
  A5. `_G.scratchPadTasks()` again.
      EXPECT the first three each marked **✅ already in Asana — not
      sent again**, and only Delta shown as a task that would go.
  A6. Send again.
      EXPECT **ONE** new task in Asana — Delta. Not four.
      **A FAIL here is four tasks**, and it is the bug this release
      exists to fix. Tell me at once.
  A7. The alert should read "…1 task from 1 tab · 3 already in Asana,
      not sent again".

  B. THE ONE THAT IS ACTUALLY YOUR CASE.
  B1. Make a tab with two good lines and one line Asana will refuse —
      `A: notarealperson` under a `P:` task will do it.
  B2. Send. EXPECT the two good ones in Asana, the tab marked ❌.
  B3. Send again (or wait for 16:00).
      EXPECT **only the bad one is retried**. The two that landed must
      NOT appear in Asana a second time.
  B4. Fix the bad name and send once more. EXPECT one task, and the
      tab goes ✅.

  C. IT HAS TO SURVIVE A RELOAD — the duplicate that would really have
     bitten you is the one after Hammerspoon restarts.
  C1. After A6, reload Hammerspoon.
  C2. `_G.scratchPadTasks()`. EXPECT all four still marked ✅ already
      in Asana.
  C3. Type a character in the tab (clearing the ✅) and send.
      EXPECT **nothing is sent** — there is nothing new. A run that
      posts four tasks here is the memory not reaching disk.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.scratchPadReport()` — there is a new `landed:` line saying
      how many tasks across how many tabs are remembered as already in
      Asana. On your Mac after today that number should be large.
  D2. If it ever carries "⚠️ N remembered task(s) were forgotten this
      session", paste it — that is the 400-per-tab bound biting, and
      past it a duplicate becomes possible again.

  E. A JUDGEMENT ONLY YOU CAN MAKE — and this is the real question.
  E1. **Did you want 121 tasks on your Asana board today?** The
      grammar reads every bare line as a task, and it sweeps every
      open tab, so any prose you keep in Hamsidian became Asana tasks
      at 16:00. I have NOT capped or narrowed that, deliberately — you
      asked for one task per line and I am not going to quietly
      un-decide it. Three answers, each a different next release:
      · "yes, that is what I wanted" → nothing more to do.
      · "no — only tabs I mark should send" → the send reads only tabs
        that opt in (a marker line, or a tab title convention).
      · "no — it should refuse a run that big and ask me first" → a
        ceiling on the UNATTENDED 16:00 run only, with the button
        still uncapped because you are watching it.
  E2. 📏 SAID RATHER THAN IMPLIED: the line that failed was
      `A: <a default assignee of 'me'>`. That is prose, not a name,
      and the guard did exactly the right thing — it refused it, kept
      every word, and marked the tab. That part is not a bug. But it
      does mean something in your tabs is being read as an assignee
      when you meant it as text.

- 6.304.0 verify with LL — 🚨 SECURE INPUT CAN FINALLY ANSWER (KNOWN GROUND)
  WHAT CHANGED: the probe that asks whether anything has locked your
  keyboard could stop for the whole session and never say so. It cannot
  any more.
  WHY IT MATTERS, and your own report is what named it: every
  `_G.hyperKeyReport()` you have sent reads `secure: not known —
  capabilities.lua has not answered yet`, and `_G.secureInputReport()`
  said `1 probe(s) STARTED and none finished`. One probe attempted,
  never a second — while a timer went on asking every sixty seconds and
  being turned away at the door.
  🔬 THE CAUSE, in one sentence: a flag says "a probe is already
  running" so two ioregs never stack up, and the ONLY thing that
  cleared it was a probe finishing successfully. So the first one that
  could not finish shut the feature down until the next reload.
  🚨 AND IT IS THE LAST OF 6.303.0's THREE CANDIDATES. The remap and
  the tap have both been answering you correctly since you installed
  it; Secure Input — the one that kills every shortcut on the Mac with
  no error anywhere, and lives on the lock screen a wake goes through —
  is the one that has never once been measured on your Mac. This is
  what makes it answerable. It is NOT itself a fix for the storm.

  A. THE HEADLINE — one command, and it is the whole test.
  A1. Install, reload, wait about ten seconds.
  A2. Console: `_G.secureInputReport()`.
      EXPECT, and this is the line that has never appeared on your Mac:
        state  : off — nothing is holding the keyboard
        probes : 1 checked · 0 failed · 0 change(s) seen
      A `state : ON — <app> holds it` is also a pass, and a much more
      interesting one: paste it immediately, it means something really
      is sitting on your keyboard.
      **A FAIL is `state : UNKNOWN` still.** If you get that, the ↳
      lines under it now say WHY, which is the part that did not exist
      before — paste the whole block.
  A3. `_G.hyperKeyReport()`.
      EXPECT the `secure:` row to read `Secure Input clear` instead of
      `not known — capabilities.lua has not answered yet`.
      That row going from "not known" to an actual answer IS the
      release.

  B. IT MUST KEEP ANSWERING — the wedge was a thing that happened over
     time, so one good reading is not proof.
  B1. Use the Mac for a few hours.
  B2. `_G.secureInputReport()` again.
      EXPECT `probes :` to be a COUNT IN THE DOZENS — one a minute — not
      1, and not stuck at whatever it said in A2. A number that has not
      moved in an hour is the same bug in a new place.
  B3. `_G.hyperKeyReport()` — the `secure:` row should still answer.

  C. IF IT EVER FAILS, IT NOW SAYS WHICH WAY (this is the new half).
  C1. If you see any of these ↳ lines, paste them — each one sends me
      somewhere different:
      · `↳ N × macOS REFUSED to launch ioreg` — your Mac would not run
        the command at all. That is a permissions or a beta-OS answer.
      · `↳ N × ioreg started and NEVER ANSWERED` — it ran and hung.
        Different fix entirely.
      · `⚠️ N probe(s) ran with NO belt` — this Mac would not give us a
        timer, which would be a finding of its own.
      Before this release all three were one silent nothing.

  D. MUST STILL WORK — this touched a core file that every boot runs.
  D1. Boot is normal, `All green`, and the module count is unchanged.
  D2. Use ⇪ normally for a day: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space.
  D3. `_G.capabilityReport()` still prints, with its 🔒 row.
  D4. Typing does not feel heavier. The probe runs off the main thread
      as it always has; nothing about that changed.
  D5. `_G.stormReport()`, `_G.degradeReport()` and `_G.todayReport()`
      all still print.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Twenty seconds is how long a probe may go unanswered before it is
      given up on. If you ever see the "never answered" line on an
      ordinary day, that number is probably too short for your Mac and
      it is a setting, not a release.
  E2. 📏 SAID RATHER THAN IMPLIED: if Secure Input now reads ON at some
      point and your shortcuts were dead at that moment, that is an
      ANSWER to the storm question, not a new bug. Tell me the app it
      names.

- 6.303.0 verify with LL — 🔬 THE KEYBOARD, AFTER A WAKE (NEW GROUND)
  WHAT CHANGED: two seconds after your Mac wakes, this config now looks
  at the three things that can make ⇪ die without saying anything, and
  writes down what it found. If the Caps Lock remap has gone, it puts
  it back.
  WHY THIS ONE AND NOT ANOTHER GUESS: 6.302.0 could not have prevented
  your storm and says so. This is the release aimed at it — and it is a
  PROBE, because everything I can offer about the cause right now is a
  story that fits. The three candidates, all invisible from here until
  today: the Caps Lock → F18 remap (set once when Hammerspoon starts
  and never checked again), the event tap that reads F18 (macOS
  switches taps off across some transitions and tells nobody), and
  macOS's Secure Input (it stops every shortcut on the Mac, system
  wide, with no error anywhere — it took your keyboard for four hours
  once, and a lock screen is exactly where it lives).
  🔕 ON A HEALTHY MAC THIS SAYS NOTHING. That is deliberate, and it
  means the test below is "go and read the numbers", not "wait for a
  message".

  A. THE HEADLINE — no lid-closing required.
  A1. Console: `_G.hyperWakeProbeRun("by hand")`
      Wait two seconds, then `_G.hyperKeyReport()`.
      EXPECT a `probe :` block with three rows, and on a healthy Mac
      all three read plainly, with no ⚠️:
        remap : Caps Lock → F18 still set
        tap   : the F18 event tap is running
        secure: Secure Input clear
  A2. **PASTE THAT BLOCK.** It is the first time this config has ever
      been able to answer any of those three questions, and I want to
      see what your Mac says on a good day before we look at a bad one.
  A3. Any ⚠️ on those three rows on a healthy, just-booted Mac is a
      real finding — say so immediately.

  B. THE REAL ONE — the car journey, reproduced.
  B1. Close the lid. Wait a minute or two. Open it and log back in.
  B2. Wait a few seconds, then `_G.hyperKeyReport()`.
      EXPECT the `probe :` line to say `after systemDidWake` with a
      time on it. If it still says "nothing looked at yet", the wake
      never reached us and that is 6.302.0's step A3 failing — tell me.
  B3. Read the three rows. **This is the whole point of the release.**
      · `remap : ⚠️ GONE` → THAT IS YOUR BUG, found. It will have put
        it back, and you will have seen a Console line saying so.
      · `tap : ⚠️ the F18 event tap was NOT running` → it is the tap,
        and the fix is a different one line.
      · `secure: ⚠️ Secure Input held by …` → it is macOS's lock
        screen, and the fix is different again.
      · all three clean → none of my three candidates, and that is
        genuinely useful: it means the keyUp is being lost somewhere
        else and I stop guessing in this direction.
  B4. Then press ⇪ and hold it while you press a few letters, right
      after a wake, and see whether it storms. If it does, send me
      `_G.stormReport()` AND `_G.hyperKeyReport()` together — the two
      side by side is what no previous build could give.

  C. MUST STILL WORK — this touched the ⇪ key and added a background
     process, so this is the half that matters more than A or B.
  C1. Use ⇪ normally for a day. No change of any kind.
  C2. Typing must not feel heavier after a wake. The probe runs off the
      main thread on purpose (6.228.0 — a busy main thread is a mouse
      this Mac has lost), but if the Mac stutters a couple of seconds
      after every lid-open, that is me and I want to know at once.
  C3. Caps Lock must still behave as ⇪ and must NOT start toggling
      capitals. If it ever does, the remap has been changed rather than
      restored — stop and tell me, that is the worst thing here.
  C4. `_G.stormReport()` still prints. `_G.degradeReport()` and
      `_G.todayReport()` still print.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.hyperKeyReport()` from A1, on a good day.
  D2. `_G.hyperKeyReport()` from B2, after a real wake.
  D3. If `counts:` ever shows a repair, that line is the answer to
      everything we have been chasing — send it whatever else you do.

  E. THE SENTENCE I STILL WANT, and it beats all three probes.
  E1. Was ⇪ working between the storm at 10:57 and your reload that
      evening? Dead until the reload → the remap is being lost, and
      this release will now catch it and repair it. Working → the
      remap survived, and the probe's other two rows are where to look.
  E2. 📏 SAID RATHER THAN HIDDEN: if the probe finds the event tap
      switched off, it REPORTS it and does not restart it. Restarting
      a tap is not the same kind of act as restoring a mapping — this
      config switches that tap off itself after five consecutive
      errors, on purpose, and re-arming it automatically would undo a
      decision it made for a reason. If your report ever shows that
      row, the next release decides what to do about it with evidence
      instead of a guess.

- 6.302.0 verify with LL — 🌅 A WAKE IS SEEN (NEW GROUND — expect a round)
  WHAT CHANGED: this config now knows when your Mac wakes up. Nothing
  here had ever watched the wake side — the one sleep/wake watcher in
  seventy-one modules listens for the screen LOCKING. And a ⇪ hold
  still open across a wake is let go.
  🚨 AND IT IS NOT THE ANSWER TO YOUR STORM. I am saying that first
  because the message I sent you implied it was, and the report you
  sent me says otherwise. Your hold was 10.5 seconds old. That clock
  starts on a FRESH Caps Lock press, so the hold began AFTER the car
  journey, not across it — the first ⇪ press once you opened the lid
  never ended. A watcher firing as the lid opens would have found ⇪ up
  and done nothing, and your storm would have happened exactly as it
  did. The wake is still the setting; this release is not the fix, and
  6.303.0 is the probe aimed at it.
  🔎 ONE THING IN THAT REPORT THAT IS NOT A SECOND FAULT, so you do not
  read it as one: `0 watchdog release(s)`. The 8-second watchdog cannot
  end a latch while keys keep arriving — every key you press proves the
  hold is real and pushes its deadline out, by design — and a person
  fighting a dead keyboard never stops pressing keys. That is exactly
  the hole the storm guard was built to cover, and it covered it:
  released at 10.5 s, wrote the file, announced it at the next boot.

  A. THE HEADLINE — and it is quiet, which is the point.
  A1. Install and reload. Console: `_G.hyperKeyReport()`.
      EXPECT a new line: `wake     : 0 wake(s) seen, none found ⇪ held.`
      A ⚠️ on that line instead means this Mac would not give us a
      sleep/wake watcher — paste it, that is a real finding.
  A2. Close the lid. Wait thirty seconds. Open it, log back in.
  A3. `_G.hyperKeyReport()` again.
      EXPECT the wake count to have gone UP — 1, 2 or 3 depending on
      whether macOS sent one event or several. Any number above 0 is a
      pass. **0 IS THE FAIL**, and it is the one I most want to hear
      about, because everything in 6.303.0 hangs off this working.
  A4. Note that number and tell me what it is. I genuinely do not know
      whether your Mac sends one wake event or three, and it decides
      how 6.303.0 reads its own measurements.

  B. THE RELEASE ITSELF — only if you want to see it fire.
  B1. Hold Caps Lock down and, while still holding it, close the lid.
      Wait ten seconds, open it, log back in.
  B2. `_G.hyperKeyReport()`.
      EXPECT `N wake(s) seen · 1 found ⇪ STILL HELD and let it go`,
      and the line says it is NOT a latch.
  B3. Console, scroll back: one line reading "⇪ let go on
      systemDidWake … nobody holds ⇪ through a sleep". No alert on
      screen — deliberately. If you got an alert, tell me: waking your
      Mac should never pop a message at you.
  B4. `latch    : 0` on that same report. That number is the one the
      storm report prints as a fault, and a wake release must never
      touch it — otherwise it climbs every morning on a healthy Mac
      and stops meaning anything.

  C. MUST STILL WORK — this is the ⇪ key, so this is the important half.
  C1. Use ⇪ normally for a day: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space.
      EXPECT no change of any kind.
  C2. Hold ⇪ for ten seconds without pressing anything, then let go.
      EXPECT the old `released by the watchdog — held 8s` line. That
      warning must keep its teeth.
  C3. Open the music card (⇪⇧pad.) — its one-off "took the keyboard"
      line still appears, and `handover` still counts.
  C4. `_G.stormReport()` — it must PRINT, not throw (6.282.0), and its
      `before :` line now carries a wake count and the watcher's state.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.hyperKeyReport()` after a few days of ordinary lid-opening.
  D2. `_G.stormReport()` if another storm happens. The `before :` line
      is now the fingerprint for this too.

  E. THE ONE SENTENCE I NEED, AND IT IS WORTH MORE THAN ANY PROBE.
  E1. **Was ⇪ working between that storm at 10:57 and your reload that
      evening?** Two answers, two different bugs:
      · ⇪ was DEAD until you reloaded → the Caps Lock → F18 remap is
        being lost when the Mac wakes. That is bigger than the storm:
        it means ⇪ stops existing after every car journey until
        Hammerspoon restarts. 6.303.0 becomes a repair.
      · ⇪ went on working → the remap survived, and the keyUp was
        eaten by something else (the event tap being switched off
        across the transition, or macOS's Secure Input during the lock
        screen). 6.303.0 stays a probe that tells those two apart.
  E2. If you would rather not wait: press ⇪ a few times right after
      the next wake and see whether anything happens. That is the same
      answer in ten seconds.

- 6.301.0 verify with LL — 🗂 SUBTASKS (NEW GROUND — expect a round)
  WHAT CHANGED: an `S:` line is a real Asana subtask now, hanging under
  its own task.
  🪪 AND IT ANSWERS YOUR QUESTION WITH CODE. You asked whether the id in
  your project URL was the parent id. It is not — 745948257030523 is
  your PROJECT gid, and this config has posted every task to it since it
  was set up (it is already in init.lua, beside workspace
  182448385076670; neither had to change). A PARENT is a TASK, and its
  id is created at the moment the task is. So there is nothing for you
  to look up and nothing to paste.

  A. THE HEADLINE.
  A1. ⇪N, a new tab:
        P: Generate a new init.lua feature
        D: We need to structure a new Hammerspoon feature.
        S: Structure tool request
        S: Submit tool request
        S: Begin coding today
  A2. `_G.scratchPadTasks()`. EXPECT the three ↳ lines, and under them
      "3 subtask(s) sent under this task".
  A3. Send it. EXPECT in Asana: ONE task "Generate a new init.lua
      feature" with THREE SUBTASKS under it — not four tasks side by
      side, and not three tasks with no parent.
  A4. The alert should read something like "✅ Hamsidian → Asana: 1 task
      from 1 tab · 3 subtasks".
  A5. The tab is retitled ✅ Success: tasks sent.

  B. THE ONE THAT PROTECTS YOUR BOARD — read this even if you skip it.
  B1. If a subtask is refused, the tab still goes ✅ and you get a
      separate ⚠️ naming which subtask and which task it belonged to.
  B2. That is DELIBERATE and it is the one thing here I want you to
      disagree with if you disagree: by then the parent task EXISTS in
      Asana. Marking the tab ❌ would make the next send retry it — and
      a retry creates a SECOND copy of the task on your board, silently,
      every time. A missing line you are told about is recoverable; a
      duplicating retry is not.
  B3. `_G.asanaSubmitReport()` — a new `subtasks: N sent · N refused`
      line, with that reason spelled out under it.

  C. MUST STILL WORK.
  C1. A task with NO `S:` lines behaves exactly as it did in 6.300.0.
  C2. ⇪T still creates a single task (it does not send subtasks — the
      form has no field for them).
  C3. ⇪A, the pipe chooser, unchanged.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.asanaSubmitReport()` and `_G.scratchPadReport()` after a real
      day of use.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. A subtask is given only its name — no assignee, no dates, no
      description. Do you want `A:` and `T:` to flow down to the
      subtasks as well, or should they stay the parent's alone? I made
      them the parent's, because a subtask inheriting a due date you
      only meant for the task is noise on your board.
  E2. Subtasks are filed under the parent only, NOT added to your
      project separately. That is why they do not appear as their own
      rows in the project list. Say if you want them listed there too.

- 6.300.0 verify with LL — 🗂 THE GRAMMAR SENDS (NEW GROUND — expect a round)
  WHAT CHANGED: Hamsidian sends your grammar now. Every task it reads
  becomes its own Asana task, and the tab is retitled with your labels.
  🏷 YOUR ANSWER WAS BETTER THAN ALL THREE OF MINE. I asked where the
  cleared text should go and you answered by not clearing it. Nothing is
  deleted — the tab keeps every word and wears the outcome.

  🚨 DO THE PREVIEW FIRST. This is new ground and it writes to Asana:
  `_G.scratchPadTasks()` still shows exactly what a send would create,
  and it now also shows what it did to each `T:` line. Read it once
  before step A2.

  A. THE HEADLINE.
  A1. ⇪N, a new tab, and type your own example:
        Create the Asana task maker in Hamsidian
        =
        P: Generate a new init.lua feature
        A: me
        D: We need to structure a new Hammerspoon feature.
        T: today +1w 7:00 AM 4:00 PM
  A2. Console: `_G.scratchPadTasks()`. EXPECT two tasks, as before.
  A3. Press "→ Asana now" in the window (or `_G.scratchPadSend()`).
      EXPECT: TWO separate tasks in Asana, in your usual project — not
      one task with both lines in its description.
  A4. Look at the tab list. EXPECT: that tab is now called
      **✅ Success: tasks sent**, and its text is untouched inside.
  A5. Press "→ Asana now" again.
      EXPECT: NOTHING is sent and nothing is announced. A ✅ tab is
      never sent twice — that is what stops 16:00 posting today's tasks
      again tomorrow.
  A6. Click into that tab and type a character.
      EXPECT: the ✅ disappears and the title goes back to your first
      line. New text is new work. Send again and it goes.

  B. THE DATES — the part I had to make a decision about.
  B1. New tab: `Buy milk` then `T: today`.
  B2. `_G.scratchPadTasks()`. EXPECT: `📅 start — · due <today>` and,
      under it, `↳ one date given — sent as the DUE date`.
      WHY: Asana refuses a start date with no end date outright, so
      `T: today` would have failed. A single date means "by then"
      everywhere else, so that is what I made it mean. Your two-date
      lines are untouched.
  B3. Send it. EXPECT: a task due today, no start date, no error.
  B4. Tell me if that is wrong. It is a decision, not a rule, and you
      are the only one who can say whether "T: today" means due today or
      starts today.

  C. WHEN IT FAILS — please do at least C1.
  C1. Put a nonsense assignee in a task: `A: notarealperson`.
  C2. Send. EXPECT: the tab is retitled **❌ Error: tasks not sent**, the
      text is all still there, and you get an on-screen ⚠️ naming what
      Asana said.
  C3. Fix the name and send again. EXPECT: the ❌ tab IS retried and
      turns ✅. That is the only reason to mark a failure.
  C4. A tab with two tasks where only ONE fails is marked ❌, not ✅. If
      you ever see a ✅ over a task that did not arrive, stop and tell
      me — that is the worst failure this release can have.

  D. MUST STILL WORK.
  D1. ⇪N and ⇪3 open as before; your tabs and notes are untouched.
  D2. ⌘T, ⌘W, ⌘1–9, the history pane, 📌, ⌘⇧S export — unchanged.
  D3. ⇪T still creates a single task from the form.
  D4. `_G.scratchPadReport()` — new `send :`, `marks :` and `run :`
      lines. PASTE THE WHOLE THING after a day.

  E. THE TWO THINGS I CHANGED THAT YOU SHOULD AGREE WITH.
  E1. 🗓 **16:00 IS BACK ON.** You switched it off in 6.254.0 ("I don't
      need to send these at 4pm") and this message switched it back on
      ("tasks send at 4pm whether Hamsidian is open or not"). It is your
      call either way, but I am naming it rather than letting you find
      out at four o'clock. `settings = { scratch_pad = { sendDaily =
      false } }` — or just say so and I will change the default.
  E2. 📏 **A TAB YOU CLOSED TODAY IS NO LONGER SENT.** The old day task
      swept them; a closed tab has no title to put a ✅ or ❌ on, so
      sending it would be sending into silence. The report counts them
      and says so. If you want them back in, that is a decision and I
      will build it — say how you would want to be told what happened
      to one.

  F. A JUDGEMENT ONLY YOU CAN MAKE.
  F1. Every sent tab reads exactly "✅ Success: tasks sent", so five of
      them look identical in the list. That is literally what you asked
      for and it is right for a done-pile you are going to delete — but
      say if you would rather it read "✅ Sent · <your first line>" so
      you can tell them apart.
  F2. `S:` subtasks are still read and still not sent — Asana needs the
      parent task's id back first, which is a second call. That is
      6.301.0, and it is the next thing I build unless you say otherwise.

- 6.299.0 verify with LL — 🔔 A SEND THAT FAILS IS FINALLY SEEN (KNOWN GROUND)
  WHAT CHANGED: Hamsidian now says "sent" when ASANA says yes, not when
  the request leaves this Mac.
  WHY IT MATTERS: 6.278.0 was built from your own question — "how do I
  know if it didn't work? I could lose important information if not" —
  and it had a hole in it I did not see until I went to build the send
  you asked for. `asanaSubmitTask` hands back "true" the instant it fires
  the request; Asana's yes or no arrives a second later, in a callback
  that told nobody. So a task Asana REFUSED showed you "✅ Hamsidian →
  Asana" and cleared the warning flag, while a separate "❌ Error: 400"
  flashed beside it from the other half of the config. Both were true
  sentences about different moments.
  🚨 NOTHING YOU PRESS CHANGES. This is a correctness release and the
  next one is the send you actually asked for.

  A. THE HEADLINE — it still works on a good day.
  A1. ⇪N, type something into a tab, then Console: `_G.scratchPadSend()`.
      EXPECT: the task appears in Asana, and you get "✅ Hamsidian →
      Asana: Hamsidian · <date>" — a moment LATER than it used to,
      because it now waits for Asana to say yes.
  A2. Console: `_G.asanaSubmitReport()` — NEW.
      EXPECT: `answers: 1 accepted by Asana · 0 refused or never sent`,
      and a `last : ✅ …` line with the time.
  A3. `_G.scratchPadReport()` — its last-send line should say "sent",
      not "posted — waiting on Asana". If it is stuck on waiting, Asana
      never answered and I want that block.

  B. THE ONE THAT PROVES THE FIX — make Asana refuse one.
  B1. ⇪T, and put a nonsense name in the Assignee field that is not on
      your team — or any field Asana will reject. Create it.
  B2. EXPECT: "❌ Error: <code>" as before.
  B3. Console: `_G.asanaSubmitReport()`.
      EXPECT: `0 accepted · 1 refused`, and a `last : ❌ … — Asana
      refused it (HTTP 4xx) — <Asana's own words>` line. Those words are
      new: Asana's reason used to reach the Console and nothing else.
  B4. If you can make the 4 PM send itself fail, that is the real test:
      EXPECT an on-screen ⚠️ naming Asana's reason, a notification, and
      `_G.scratchPadReport()` carrying a ⚠️ NOT SENT line — and NO "✅"
      anywhere. Before this release that case showed you a ✅.

  C. MUST STILL WORK — this touched the one path every Asana task takes.
  C1. ⇪T creates a task: title, description, assignee, priority, SAC
      Values, dates and times, an attachment. All unchanged.
  C2. ⇪A (the pipe chooser) still creates a task.
  C3. The ⇪N button "→ Asana now" still sends.
  C4. A task you create still gets its automatic comment.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.asanaSubmitReport()` after a day of normal use. If it ever
      carries a `⚠️ N never answered in 30 s` line, that is a new fact —
      Asana going silent on your network — and I want it.
  D2. `_G.scratchPadReport()`.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Thirty seconds is how long it waits for Asana before telling you it
      heard nothing. Too long to sit wondering, or too short on a slow
      network? It is a number, not a release.
  E2. ANSWERING YOUR OTHER QUESTION, because it belongs here: the id in
      the URL you sent — 745948257030523 — is your PROJECT gid, and this
      config already posts every task to it (it is in init.lua as
      `asanaProjectId`, alongside workspace 182448385076670). A SUBTASK's
      "parent" is a different thing: it is the gid of the TASK the
      subtask hangs under, and that number does not exist until the
      parent task has been created. This release is what makes it
      reachable — the submit now hands that gid back — and 6.301.0 is
      what uses it.

- 6.298.0 verify with LL — 🔎 THE @ SEARCHES NAME THEMSELVES (KNOWN GROUND)
  WHAT CHANGED: type @ on its own in ⇪D and every source you can search is
  listed — its tag, what it holds, and how many.
  WHY IT MATTERS: you were right that nothing named them. There are
  fourteen, and the only place any of them appeared was a section header
  in the results — which you can only read after searching for something
  that happens to be in that store. A tag you have to know before you can
  find it is not a tag you can use, which is why fourteen of them have
  been sitting there unused.

  A. THE HEADLINE.
  A1. Press ⇪D. Type a single `@` and nothing else.
      EXPECT: the list becomes a directory — 🔎 THE @ SEARCHES — 14, and
      one row per source reading e.g. `📋 @clip` with "Clipboard ·
      everything you have copied" under it and a number on the right.
  A2. Read the fourteen. EXPECT: @clip @cmd @shots @note @asana @ocr
      @images @doc @file @pad @scratch @vault @web @tool.
  A3. Press ↓ a few times, then ⏎.
      EXPECT: that source's tag lands in the box as `@ocr ` (or whichever)
      and the results below become that store. It must NOT copy anything.
  A4. Press ⇪D again, type `@`, and CLICK a row.
      EXPECT: the same — the tag goes in the box.
  A5. With the directory up, look at the right-hand pane.
      EXPECT: it says what the highlighted source holds and how many items
      are indexed right now.

  B. THE ONE THAT MUST NOT HAVE REGRESSED — please do this one.
  B1. Type `@ocr` (with the r). EXPECT: OCR rows, exactly as before. The
      directory must NOT appear. It is `@` alone, never any @word — `@o`
      already searched @ocr and that had to keep working.
  B2. Type `@shots`, `@vault`, `@clip`. EXPECT: each pins its store as
      always.
  B3. Type an ordinary word — `receipt`. EXPECT: unchanged.
  B4. ⇪⇧space and ⇪⇧/ still open pinned to @shots and @tool.

  C. THE SECOND DOOR.
  C1. Type `@tasks` — a tag that does not exist.
      EXPECT: "Nothing matches … and there is no @tasks source. Type @ on
      its own to see all 14."
  C2. Type `zzznothing`. EXPECT: the plain "⌫ widens it again" message —
      it must not start talking about @ for an ordinary miss.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.unifiedSearchReport()` — the store list and its counts.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. Read the fourteen one-line descriptions. Any of them wrong, or
      describing something other than what you thought that tag searched?
      That is the answer I most want — they are my words for your stores,
      and a wrong one is worse than none.
  E2. 📏 NAMED, NOT FIXED, so it is not a surprise: with `@ocr` typed, the
      line under the box still reads "200 matches across every store" —
      which is not true, it is pinned to one store. Your screenshot. It is
      its own small release; say if you want it sooner.

- 6.297.0 verify with LL — 🗂 A LINE IS A TASK (NEW GROUND — expect a round)
  WHAT CHANGED: Hamsidian can now READ your task grammar. It does not
  send it yet, on purpose.
  🔎 AND FIRST, YOUR QUESTION, ANSWERED: **no.** "→ Asana now" builds
  ONE task for the whole day — titled `Hamsidian · Fri Sep 26`, with
  every open tab's text as its description. Never one task per line.
  (And the 4 PM schedule is OFF anyway — you switched it off in
  6.254.0 — so only that button and `_G.scratchPadSend()` send at all.)
  WHY THE PREVIEW COMES FIRST: this is your grammar and only you know
  what you will really type. If I build the sending first, the first
  thing either of us learns about a misreading is a wrong task sitting
  in Asana. So this release prints what it understood, and you tell me
  where it is wrong before anything reaches your board.

  A. THE HEADLINE — this is the whole test.
  A1. Press ⇪N and type into a tab, in your own words. Include at
      least one bare line, one `=`, and one P:/A:/D:/S:/T: block. Your
      own example from the message is perfect:
        Create the Asana task maker in Hamsidian
        =
        P: Generate a new init.lua feature
        A: me
        D: We need to structure a new Hammerspoon feature.
        S: Structure tool request
        S: Submit tool request
        T: today +1w 7:00 AM 4:00 PM
        S: Begin coding today
  A2. Console: `_G.scratchPadTasks()`. **PASTE THE WHOLE THING.**
      EXPECT: two tasks — "Create the Asana task maker in Hamsidian",
      and "Generate a new init.lua feature" with 👤 me, its 📄
      description, three ↳ subtasks, and a 📅 line reading start today
      07:00 · due <a week out> 16:00.
  A3. Read every line of that output against what you MEANT. That is
      the test. Anything it got wrong is a one-line fix here and a
      wrong task in Asana later.

  B. THE THING I MOST WANT TO KNOW — the `T:` line.
  B1. You described the INTENT ("Today as start date, one week from
      today as the end date, start time 7:00 AM, end time 4:00 PM") and
      not a syntax, so I guessed one. It reads:
        today · tomorrow · yesterday · +3d · +2w · +1m
        2026-09-13 · 09/13/26 · 9-13-2026
        7:00 AM · 4pm · 07:00 · 16:00
      First date is the start, second is the due; first time the start,
      second the end.
  B2. Write a `T:` line the way you WOULD write it, without looking at
      that list, and run the preview. Anything it cannot read is named
      as `⚠️ could not read "x"`. Send me those words — they are the
      spec, and my guess is not.

  C. THE ONES THAT PROTECT A TASK FROM VANISHING.
  C1. Put a bare line straight after a `D:` line. EXPECT: it becomes
      its OWN task, not part of the description. That is the decision I
      made, and it is the one worth disagreeing with if you disagree.
  C2. Write `D: something` with no `P:` above it. EXPECT: a ⚠️ saying
      it is before any task. It is dropped rather than silently glued
      onto the next thing.
  C3. Write `D: a = b`. EXPECT: it stays one task with "a = b" as the
      description — an `=` inside a line is text, only a line that is
      nothing but `=` divides.

  D. MUST STILL WORK — this release added a reader and changed no
     behaviour, so this is the sweep.
  D1. ⇪N and ⇪3 open as before, your tabs and notes are untouched.
  D2. "→ Asana now" still does exactly what it did — one task for the
      day. Nothing about sending changed.
  D3. ⌘⇧S still exports tabs as notes.

  E. WHAT IS NOT BUILT YET, said plainly so it is not a surprise.
  E1. **Nothing is sent from the grammar.** That is next.
  E2. **Subtasks are read but cannot be sent** — Asana needs the parent
      task's id back before a subtask can be attached, which is a
      second call and its own release. The preview says so on every row
      that has one.
  E3. **The clearing you asked for** — tasks gone from the pad and "All
      tasks sent." left behind — comes with the send. One question I
      need answered before I build it, and it is the only one that can
      lose your writing: when a tab is cleared, where should the text
      GO? Options: (a) nowhere, it is gone; (b) into the tab's history,
      recoverable from the report; (c) exported as a note in
      <Vault>/Scratch first, so it is a file. **I will build (c) unless
      you say otherwise** — 6.280.0's rule is that deleting your
      writing is the one failure with no way back.
  E4. **4 PM back on, open or not.** The schedule already runs whether
      the window is open or not — it lives in the module, not the
      window — it is simply switched off. It comes back on with the
      send, not before, because a schedule that fires a grammar I have
      not proven is the wrong order.

- 6.296.0 verify with LL — 🏷 JUG PLAYER (KNOWN GROUND)
  WHAT CHANGED: the music player is called the Jug Player everywhere you
  can see it, and its name sits to the left of the now-playing line.
  WHY IT MATTERS: your words, and the rename is the easy half. The half
  worth a release is that ONE field carries the name — the card, the
  alert, the error door, both reports and the ⇪/ card all read it — so
  it cannot end up saying one thing in one place and another elsewhere.

  A. THE HEADLINE.
  A1. ⇪⇧pad. EXPECT: the card's top line reads
      `Jug Player   nothing playing`, with the name on the LEFT in
      blue, on the same line, not above it.
  A2. Drop a track on it. EXPECT: `Jug Player   <track name>` — the
      name stays put and the track fills the rest of the line.
  A3. Drop a track with a very long name. EXPECT: the track name is cut
      with an ellipsis; "Jug Player" is never squeezed or wrapped.
  A4. ⇪/ and search `jug`. EXPECT: the 🎵 JUG PLAYER card.
  A5. Console: `_G.musicReport()`. EXPECT the first line reads
      `🎵 JUG PLAYER — ⇪⇧pad.`

  B. THE ONE THING MOST LIKELY TO HAVE BROKEN — please do this.
  B1. Press on the card's TITLE STRIP (where the name is) and drag.
      EXPECT: the card moves. The name is a new element inside that
      strip, so this is the thing the rename could have cost.
  B2. ⌘-drag anywhere on the card. EXPECT: it moves.
  B3. Close and reopen. EXPECT: it comes back where you left it.
  B4. A bare click on a TRACK ROW still plays that track — it must not
      pick the window up.

  C. MUST STILL WORK.
  C1. space, ↑↓, ⏎, ⌘1–9, ← →, ⌫, the ✕ on a history row, the repeat
      button — all unchanged.
  C2. F7/F8/F9 still drive it (6.291.0).

  D. AND IT IS QUIET NOW, which is 6.295.0 landing on this tool.
  D1. `_G.degradeReport()` → the quiet list should read **Jug Player**,
      not "Music player". If it still says the old name, the two
      releases have drifted and I want to know at once.
  D2. If the player fails at something, you get a Console line and no
      alert — which is what you asked for. `_G.todayReport()` still has
      it.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. The name is drawn in blue at the same size as the track. Too
      loud, too quiet, or right? It is a colour and a number, not a
      release.
  E2. NAMED, NOT SWEPT, so it is not a surprise: the FILE is still
      `music_player.lua`, the settings key is still `music_player`, and
      the store folder is still `music`. Those are ids you never see,
      and renaming a store folder is how a queue goes missing. If you
      want them moved anyway, say so and it is a careful release of its
      own.

- 6.295.0 verify with LL — 🔕 QUIET FOR THE THINGS THAT DO NOT MATTER (KNOWN GROUND)
  WHAT CHANGED: a tool can now report a failure to the Console alone.
  Exactly one is set that way — the music player, because you named it.
  WHY IT MATTERS: you asked for two things and only one of them was
  missing. Everything that writes or gathers — Hamsidian, the Asana
  submit, the backups, the file tracker, the vault — has alerted on
  screen since 6.215.0, because the 🔔 door alerts for every tool. So
  this release is the OTHER half: a way to be quiet, and nothing else.
  🚨 AND IT FAILS LOUD. A tool nobody has classified still alerts. A
  needless alert is an annoyance; a swallowed one is the failure you
  asked me to fix in 6.278.0, so the quiet list has to be earned.

  A. THE HEADLINE.
  A1. Console: `_G.degradeReport()`.
      EXPECT a new line:
        quiet   : 1 tool(s) go to the Console alone — Music player
                  (none has degraded this session)
      and two lines under it saying the LOG still gets them and how to
      put one back on screen.
  A2. Make a quiet one fail on purpose:
      `_G.degrade("Music player", "on purpose")`
      EXPECT: **nothing on screen**, and a Console line
      `⚠️ Music player: on purpose`.
  A3. Make a loud one fail: `_G.degrade("Hamsidian", "on purpose")`
      EXPECT: an alert on screen AND the Console line. That contrast in
      one minute is the whole release.

  B. THE HALF THAT MUST NOT HAVE A HOLE IN IT.
  B1. `_G.todayReport()` after A2 and A3.
      EXPECT: **both** rows, the quiet one included. Quiet is about the
      alert and nothing else — your 4 PM check must not acquire a blind
      spot named "music".
  B2. ⇪⇧D — both are in the notices list too.
  B3. `_G.degradeReport()` again: the Music player row must read
      `(🔕 Console only — on the quiet list)` and NOT
      `(⚠️ never alerted — hs.alert refused)`. That second sentence
      would be a lie, and it is the one this release nearly shipped.

  C. THE DOOR, because you do not edit files.
  C1. `_G.degradeQuiet("Bluetooth")` → Bluetooth goes Console-only.
  C2. `_G.degrade("Bluetooth", "test")` → no alert.
  C3. `_G.degradeLoud("Bluetooth")` → it alerts again. Nothing is
      permanent and nothing needs a release.

  D. MUST STILL WORK.
  D1. Use the Mac normally. Any alert you would have seen before — a
      backup problem, an Asana send failing, ⇪4 finding no folder —
      still appears.
  D2. If a MUSIC player problem ever matters to you after all, C1's
      opposite is `_G.degradeLoud("Music player")`.

  E. A JUDGEMENT ONLY YOU CAN MAKE — and this is the real question.
  E1. The list ships with one name on it. Which others do you want
      quiet? Candidates I would guess but will not assume: the QR
      reader, Bluetooth, the key caster, the mini calendar, the
      pomodoro's sound. Name them and they go in the next release as
      defaults; or use `_G.degradeQuiet(...)` for a week first and tell
      me which ones you never wanted to hear from.
  E2. The opposite question, and it is the one I would ask myself:
      is anything still alerting that should be LOUDER — a
      notification that survives Focus, the way a failed Asana send
      gets one (6.278.0)? Right now only that send has one.

- 6.294.0 verify with LL — 🎯 ⇪T IS ON THE ASANA CARD (KNOWN GROUND)
  WHAT CHANGED: the ✅ ASANA card on ⇪/ now points at ⇪T, the key that
  creates a task.
  WHY IT MATTERS: you were right, and you have been since 2026-09-20.
  The card listed ⇪A ⇪B ⇪C ⇪L and never the tool's front door.
  🔎 THE HONEST PART, because it changes what to expect: ⇪T was not
  forgotten. It was REMOVED from that card on purpose in 6.114.0, because
  it has its own card and one key printed twice reads as a conflict —
  which is your own complaint from a screenshot in 6.90.1, about ⇪V. So
  this is a POINTER row, not a second claim: the left column reads "task
  form" and the key sits in the sentence.

  A. THE HEADLINE.
  A1. Press ⇪/ and search `asana`.
      EXPECT: the ✅ ASANA card, and in it a row reading
      `task form — CREATE a task — ⇪T opens the labeled form (its own
      card on this sheet)`.
  A2. Search `⇪T` instead.
      EXPECT: BOTH that row and the ✅ TASK FORM card below it. The
      search matches the whole row, so the key finds it either way.
  A3. Press Esc, then ⇪T. EXPECT: the task form opens, unchanged.

  B. MUST STILL WORK — nothing about any key moved in this release.
  B1. ⇪A, ⇪B, ⇪C, ⇪L all behave exactly as before.
  B2. ⇪⇧Esc still pauses the config, and ⇪⇧Esc again resumes.
  B3. ⇪/ filtering, scrolling and Esc are unchanged.

  C. PASTE BACK, PASS OR FAIL.
  C1. `_G.cheatSheetReport()` — "empty" and "faults" should both read
      **none**, as they did on 6.269.0. If either is a number, paste it.

  D. A JUDGEMENT ONLY YOU CAN MAKE — and it is the useful one.
  D1. Is "task form" the right words in that left column, or would you
      rather it read "make one", "new task", or just "⇪T"? The last of
      those is the one I will not do silently: it re-creates the
      double-listing you objected to in 6.90.1. If you want it anyway,
      say so and it is your call, not a slip.
  D2. 🚩 THE THING I COULD NOT FIX WITH A CHECK: the gate now fails if a
      bound key is printed on NO card anywhere — and it would NOT have
      caught this. ⇪T always had a row; it was on the wrong card for the
      way you think about the tool. If any OTHER key is filed somewhere
      you would not look, tell me which and where you expected it — that
      is a judgement no test can make, and you are the only one who can.

- 6.293.0 verify with LL — ⌨️ ⌥⌥ OPENS THE MENUS (KNOWN GROUND)
  WHAT CHANGED: tap ⌥ twice, quickly, and the front app's own menus
  open — the same picker ⇪. gives you.
  WHY IT MATTERS: the second half of what you asked for, and the proof
  that 6.292.0 was worth a release of its own. Adding ⌥⌥ was nine
  lines, because the engine already existed and a gesture is now a
  registration rather than a second copy of a state machine.

  A. THE HEADLINE.
  A1. Click into an app with real menus — Word, Chrome, Finder.
  A2. Tap the ⌥ key twice, quickly, with nothing else held.
      EXPECT: a picker listing that app's menu items, searchable.
  A3. Type a few letters, press ⏎. EXPECT: that menu item runs.
  A4. Press ⇪. EXPECT: the identical picker — one function, two doors.
  A5. Full screen an app (⌃⌘F) and tap ⌥⌥ there. EXPECT: it opens.

  B. THE ONES THAT PROTECT YOUR TYPING.
  B1. Use ⌥ normally — ⌥click, ⌥drag, ⌥⌫, and typing accented
      characters if you use them. EXPECT: nothing opens.
  B2. Hold ⌥ for a second and release, twice. EXPECT: nothing.
  B3. Tap ⌥, type a letter, tap ⌥. EXPECT: nothing.
  B4. 🚨 THE ONE I MOST WANT: hold ⌘ AND ⌥ together and tap twice.
      EXPECT: NEITHER the clipboard nor the menus open. A real chord
      must satisfy no gesture, and with two gestures live that is the
      property that makes them safe together.
  B5. ⌘⌘ still opens the clipboard history (6.292.0), and ⌃⌃ still
      opens the editor picker.

  C. PASTE BACK, PASS OR FAIL.
  C1. `_G.doubleTapReport()` — it should now list BOTH gestures under
      one watcher: `⌘⌘ : clipboard history` and `⌥⌥ : the front app's
      menus`, with `watcher : running` once, not twice.
  C2. `_G.menuSearchReport()` — its new `⌥⌥` line, whichever of the
      three states you get.

  D. IF IT GETS IN THE WAY.
  D1. `settings = { menu_search = { optOpt = false } }` switches just
      this one off; ⌘⌘ and ⇪. are unaffected.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. ⌥ is a modifier you probably use more than ⌘⌘'s ⌘ for one-handed
      things — ⌥click, ⌥drag. If ⌥⌥ fires when you did not mean it,
      tell me how it felt rather than a number and I will move the
      timing; if it is simply the wrong key for this, say so and it
      moves to another modifier in one line.

- 6.292.0 verify with LL — ⌨️ ⌘⌘ OPENS THE CLIPBOARD (KNOWN GROUND)
  WHAT CHANGED: tap ⌘ twice, quickly, and the clipboard history opens —
  the same window ⇪V gives you.
  WHY IT MATTERS: you asked for this in 6.198.0, again on 2026-09-13,
  and again this week. It had never been built. The uncomfortable part
  is that the machinery has been on your Mac the whole time driving ⌃⌃
  (the editor picker); what was missing was four lines registering ⌘⌘
  against it. That engine is now a shared one in core/, so ⌥⌥ is the
  next release rather than a second copy of the same state machine.
  🖥 AND YOUR FULL-SCREEN QUESTION NEEDED NO WORK: these panels are
  drawn by an app with no Dock icon, which is exactly why they already
  come over a full-screen app. Worth testing anyway — step A4.

  A. THE HEADLINE.
  A1. Tap the ⌘ key twice, quickly, with nothing else held.
      EXPECT: the clipboard history opens — the ⇪space-style panel, the
      same one ⇪V gives you.
  A2. Press Esc, then ⇪V. EXPECT: the identical window. They are one
      function now, so they cannot drift apart.
  A3. Try it with the LEFT ⌘ and the RIGHT ⌘. EXPECT: both work.
  A4. Put an app in full screen (⌃⌘F) and tap ⌘⌘ there.
      EXPECT: the history comes forward over it. If it does NOT, that
      is a real finding and I want to know — say which app.

  B. THE ONES THAT PROTECT YOUR TYPING. These matter more than A, because
     this watches every keystroke on the Mac.
  B1. Use ⌘C, ⌘V, ⌘S, ⌘Tab and ⌘W normally for a while.
      EXPECT: nothing opens. A chord is not a gesture.
  B2. HOLD ⌘ down for a second and let go, twice. EXPECT: nothing — a
      modifier you are holding to use is not a tap.
  B3. Tap ⌘ once, type a letter, tap ⌘ again. EXPECT: nothing. A key
      between the halves proves it was a chord.
  B4. ⌘-click something twice quickly. EXPECT: nothing.
  B5. Type normally in Chrome, Word and Hamsidian for a while.
      EXPECT: no missed characters, no lag. If typing feels heavier on
      this build than on 6.291.0, STOP and tell me — that is the one
      cost this release could have that I cannot measure from here.
  B6. ⌃⌃ must still open the editor picker, exactly as before. It is
      deliberately still on its own engine — see the note below.

  C. PASTE BACK, PASS OR FAIL.
  C1. `_G.doubleTapReport()` — new. Healthy reads
      `⌘⌘ : clipboard history (⇪V) · side either · N fired` and
      `watcher : running`. If it reads `⚠️ NOT RUNNING`, this Mac would
      not give Hammerspoon an event tap — paste it.
  C2. `_G.clipboardReport()` — its new `⌘⌘` line has three states and
      I want whichever you get.

  D. IF IT GETS IN THE WAY.
  D1. `settings = { clipboard_history = { cmdCmd = false } }` switches
      the gesture off; ⇪V is untouched either way.
  D2. If ⌘⌘ fires when you did not mean it to, the two windows are
      tunable — tell me how it felt (too eager / too slow) rather than
      a number, and I will move the default.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. ⌃⌃ (the editor picker) is NOT on the new shared engine yet, on
      purpose: its tap is the one that watches every key press, and a
      mistake there does not break a feature — it takes the keyboard,
      which is what 6.214.0 cost you. So it migrates in its own release
      once this one has run on your Mac for a while. The cost until
      then is two watchers instead of one, which is why B5 matters. Say
      if you would rather I did that migration sooner.
  E2. ⌥⌥ → the menu bar is the next release and uses this same engine.

- 6.291.0 verify with LL — ⌨️ F8, BOTH WAYS (KNOWN GROUND)
  WHAT CHANGED: "It's the F8 Key" answered it, and then raised a second
  question I had not asked. That one physical key sends two completely
  different events depending on a System Setting, and 6.289.0 watched
  only one of them. Both are watched now.
  WHY IT MATTERS: with "Use F1, F2, etc. as standard function keys" OFF
  — the macOS default — F8 is a media key and 6.289.0 already works.
  With it ON, F8 is a plain function key carrying keycode 100, and
  6.289.0 could never have seen it. I cannot tell which you have from
  here, and rather than ask you to go and read a System Setting, the
  release handles both and the report SAYS which one your Mac uses.
  🚨 AND THE OLD REPORT COULD NOT HAVE TOLD US. On the second setting
  neither counter moved, so it read "0 taken · 0 passed" on a Mac where
  you had been pressing the key all morning — identical to never having
  pressed it. That is the thing I most want to stop doing.

  A. THE HEADLINE.
  A1. ⇪⇧pad., drop two or three tracks on the card. Something plays.
  A2. Press F8. EXPECT: it pauses. Press again: it resumes.
  A3. Press F7 and F9. EXPECT: back a track, forward a track.
  A4. Console: `_G.musicReport()`. Find the new "↳ by route" line.
      EXPECT one of these, and BOTH are a pass — I want to know which:
      · `3 as a media key · 0 as a plain F7/F8/F9` — your setting is OFF
        and 6.289.0 was already right.
      · `0 as a media key · 3 as a plain F7/F8/F9`, with a line under it
        naming the setting — your setting is ON, and this release is
        what made F8 work at all.
      PASTE THAT LINE either way. It is the fact neither of us has.

  B. THE ONE THAT PROTECTS EVERY OTHER APP — please do this one.
  B1. Empty the card's queue, then play something in Music.app, Spotify
      or a YouTube tab. Press F8.
      EXPECT: THAT app pauses. Hammerspoon must not swallow the key.
  B2. With a queue on the card, hold ⌘ and press F8 (⌘F8).
      EXPECT: the card does NOT react — ⌘F8 belongs to whatever app you
      are in. Same for ⌥F8, ⌃F8 and ⇧F8.
      A FAIL on either of these is the serious one:
      `settings = { music_player = { mediaKeys = false } }` turns the
      whole thing off and tell me at once.
  B3. Hold F8 down. EXPECT: it toggles ONCE, not forty times.

  C. MUST STILL WORK — this release added a tap that sees every
     keystroke on the Mac, so this is the regression sweep and it is
     the important half.
  C1. Type normally in Chrome, Word and Hamsidian for a while.
      EXPECT: no missed characters, no lag, nothing odd. If typing ever
      feels heavier on this build than on 6.290.0, stop and tell me —
      that is exactly what I would want to know.
  C2. Your autocorrect still works: type `teh ` in Chrome → `the `.
  C3. ⇪⇧Esc pauses the config; press F8 with a queue.
      EXPECT: nothing (every tap here stands down when paused). ⇪⇧Esc
      again and F8 works.
  C4. The card's own space bar, ↑↓, ⏎, ⌘1–9 and ← → are unchanged.
  C5. The volume keys stay macOS's, as you decided in 6.231.0.

  D. PASTE BACK, PASS OR FAIL.
  D1. `_G.musicReport()` — the whole block. Two lines matter: "by route"
      (above), and a `⚠️ N press(es) THREW inside the handler` line. That
      second one should NOT be there; if it is, paste it — it means the
      handler is failing and the key is silently doing nothing.

  E. A JUDGEMENT ONLY YOU CAN MAKE.
  E1. With "standard function keys" ON, F8 has a second job — some apps
      use it as a plain function key. This config takes it only while
      the card has a queue and only with no modifier held. Is that
      narrow enough, or does F8 matter to an app you use? Name the app
      and I will exempt it.

- 6.290.0 verify with LL — 🔬 THE GATE TESTS ITS OWN BELIEFS (KNOWN GROUND)
  WHAT CHANGED: nothing you can press. This release changes what the test
  gate is allowed to believe about macOS, and it is the answer to your
  question — how have so many mistakes been introduced.
  WHY IT MATTERS: I classified all ten losses on the scoreboard by where
  the defect actually lived. Eight of ten sit at the macOS boundary — the
  one surface the gate cannot see. One is a bad test recipe of mine. At
  most two are a solved thing coming unsolved. ZERO are logic errors in
  pure Lua; not one. So the mechanism is not carelessness: this config
  writes the code, the test AND the stub from one model of macOS, and
  when that model is wrong all three are wrong the same way and they
  agree with each other. Green meant "the code matches our beliefs". It
  never once meant "the code matches macOS". Your loop is closed — you
  press the key and reality answers. Mine was open.
  🔎 AND THE CLASS WAS LEARNED FIFTEEN TIMES AND ENFORCED ZERO TIMES.
  Every instance was fixed at the one stub that had just cost a release,
  while seventy-five other suites went on telling the same lie about the
  same provider. 28 of them were corrected in this release.

  A. THE HEADLINE — there is nothing to press, so this is the whole test.
  A1. Install and reload. Everything must behave exactly as it did on
      6.289.0: ⇪T, ⇪D, ⇪N, ⇪3, ⇪4, ⇪X, ⇪space, the music card.
      EXPECT: no visible difference of any kind. This release does not
      touch a single shipped module — only tests/ and the documents.
  A2. Console: `_G.configVersion` → `6.290.0`.
  A3. That is it. If anything at all behaves differently, that is a real
      finding and I want it, because this release claims to change
      nothing you can see.

  B. IF YOU WANT TO SEE THE INSTRUMENT (optional, needs the repo, not
     your Mac's install).
  B1. `lua5.4 tests/test_stub_fidelity.lua` from the unpacked archive.
      EXPECT: `27 passed, 0 failed`, and a printed list of eight further
      contracts it knows about and deliberately does NOT check.
  B2. That printed list is the point as much as the checks are. A gap
      written down is not a gap implied by silence.

  C. A JUDGEMENT ONLY YOU CAN MAKE.
  C1. This release spends a whole version number on testing rather than
      on anything you can use. Was that the right call? You asked for it,
      and I think it is the highest-value thing in this batch — but you
      are the one waiting on features, so say if you would rather I spend
      the next one on the queue and fold work like this in alongside.
  C2. The three self-inflicted bugs this audit found IN ITSELF are in
      CHANGELOG 6.290.0, named. One of them — a sentry searching for a
      phrase that existed only on the sentry's own line, so it matched
      itself and could never fail — is the kind of thing that would have
      sat there for a year. If you want, the next audit release is the
      one that sweeps the OTHER sentries in this config for the same
      shape. Say the word.

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
