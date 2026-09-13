# CLAUDE-archive.md — superseded open items (NOT auto-loaded)

Verify blocks and notes moved out of CLAUDE.md's "Open items" on
6.213.1 because that file loads into every context window and these
had been answered, superseded, or aged past the 6.204.0 scoreboard.
Nothing here is deleted; a block returns to CLAUDE.md if LL reopens it.
Newest first, exactly as they read there.

- 6.203.0 verify with LL: ⇪3, then ⌘N. Type a name — ANY name — and
  press ⏎. The note that appears must be called what he typed: until
  now the vault used the whole text of the note he had open instead,
  and with no note open ⌘N did nothing at all. Then the one he
  reported: paste a huge block into the same bar and press ⏎ — a red
  line appears UNDER the field saying how long it is and what the
  limit is, the bar stays open, and his paste is still in the box to
  copy out. Nothing is created and nothing is lost. Then ⌘⇧E (extract)
  with a silly long name: it must refuse and leave the note he was in
  byte-for-byte unchanged. AND THE ONE HE NEVER REPORTED: ⇪3 → ⌘⇧B,
  open a note, drag a card in another column — the note whose CARD he
  dragged must change, and the note he has OPEN must not. That was
  writing to the wrong file since 6.186.0. Nothing else changed in
  this release, on purpose.
- 6.202.0 verify with LL: ⇪⇧V, then move the mouse over any entry — the
  pane on the right must show THAT entry, the one the list highlights,
  with "🖱 under the pointer" in its header. Arrow up and down: it
  follows the arrows. Then the one that was impossible before: scroll
  the list with the wheel or the trackpad, hover an entry — still the
  right one. Same in ⇪⇧O and ⇪Y (every picker with a pane shares this
  code, so all of them got the fix). If the pane and the highlight EVER
  differ again that is a new bug — the pane no longer has a guess of
  its own to be wrong with — and the Console lines from that moment are
  what to paste. Nothing else changed in this release, on purpose.
- 6.201.0 verify with LL — THE ONE HE IS WAITING ON: in Chrome, select
  a sentence, ⇪2, select another, ⇪2 again, then ⌘V. It must paste those
  TWO and nothing else — no "Collect" line on top, no old text. Then the
  rule he chose: ⌘C something normally, then ⇪2 on a fresh selection —
  that must start a NEW sequence (one grab, just that text). Then ⇪N:
  his 📎 Collect tab must still be there with everything it always had,
  and NOTHING new added to it. `_G.scratchPadReport()`'s new "📎 ⇪2:"
  line says how many grabs are in the live sequence and how many
  characters ⌘V would paste; under it, the old tab is named with its
  size, "nothing writes to it now", and — 6.201.1 — a ⚠️ line saying it
  STILL rides the 4 PM Asana task until he presses ⌘W on it. Check his
  next 4 PM task actually sheds it once he does. The live sequence is
  session-scoped and the report says so. If the join is wrong for him:
  `settings = { scratch_pad = { collectJoin = "\n" } }`, no release.
  KNOWN AND UNCHANGED, stated not hidden: the block still does NOT
  appear in ⇪V's clipboard history, because power_tools suppresses the
  pasteboard watcher across the whole borrow — a SHARED global that
  screenshots also sets, so it is not being changed inside a bug fix.
- 🐞 REPORTED 6.201.0, NOT YET FIXED — LL's own words, in his order:
  (1) ✅ FIXED 6.203.0 — and the reported half was the smaller half:
  ⌘N never used the name he typed at all (the page's say() overwrites
  `text` on every message, so Lua got the whole open note). See the
  🚨 say() paragraph above. The length guard he asked for shipped too,
  in BYTES, refusing rather than truncating, said in the bar. HIS
  ORIGINAL REPORT, kept because the wording is what solved it:
  THE VAULT'S ⌘N NAMING BAR ACCEPTS AN IMPOSSIBLE NAME. He pasted a
  huge multi-line block into "Name of the note"; the name became the
  filename and the Console said "🚨 Write failed: vault note Collect" /
  "cannot open …/Vault/Collect<thousands of chars>.md". Nothing was
  created and he saw NO error on screen — "I enter a title and … I don't
  see that anything was created." Needs: refuse or clamp (length in
  BYTES, newlines, "/" and ":"), say so where he is looking, never lose
  the note. He also saw the window cover the whole screen once.
  (2) ✅ FIXED 6.202.0 — ⇪⇧V's preview pane one row off. It was NOT an
  index off-by-one: the pane's own geometric guess (56/44 vs ~89/42)
  overruled the chooser's highlight, which macOS had already put under
  the pointer. See 👁 above; the guess is deleted.
  (3) ✅ FIXED 6.204.0 — UNIFIED SEARCH TAKES NO MOUSE AND HAS NO DETAIL
  PANE — "I can only use the arrow keys. There also is no side window
  that shows the full entry." The chooser it replaced had both. The
  page listened for clicks and nothing else; a mousemove selects the
  row now and a pane asks Lua for that row's full text. See 👁 ⇪D
  below. ALL THREE of the 6.201.0 reports are closed; the next thing
  queued, alone, is 6.202.0's `_G.clipboardReport()` for the chooser
  pane.
- Chrome export (⇪Y): the 6.152.0 pipe fix WORKED — and the first completing
  export then beachballed the Mac (~30s after every boot: taps "disabled by
  macOS" in Console = main-thread stall; that parse path had never run with
  real data). 6.152.1 slices ALL ingestion under chrome.sliceBudget (40ms per
  event-loop turn), rows travel as one json_object per line, loadCsv is
  sliced too, exportTimeout 45→120s (a real export measures ~29s on the Air —
  DB copies dominate). Verify with LL: no beachball post-boot, ⇪Y populated,
  report's "last parse: N rows in K slices" row.
- Tab search: the real fault was an AppleScript COMPILE error (Safari branch
  lacked `using terms from`; "osascript exited 1: 577") — fixed 6.152.0. It
  never ran far enough to ask for Automation, so expect the macOS grant
  prompts on LL's first real press (once per browser); then verify.
- ⌥Tab: 6.153.0 budgets the memory probes (a still-slow "listing took" line
  names its phase: "memory: N probed in X.XXs"; `_G.altTabLastListing` has
  remembered/probed/probeSecs). 6.154.0 draws it as a ROLODEX
  (`altTab.layout`, "grid" = the old wall); snapshots are lazy per card.
  Verify: feel + speed; every window reachable; ↑↓ turn five.
- 6.153.0 verify with LL: ⇪T takes typing the moment it opens (non-activating
  mask, read-back verified), drags by its header, SAC Values are checkbox
  chips; ⇪Y ⌘⏎ copies the URL, ⌥⏎ opens in Safari (chrome.altBrowser).
- 6.154.0 verify with LL: ⇪V/⇪⇧V preview pane follows arrows AND the mouse
  (6.160.4's moved-hand rule and scroll estimate are SUPERSEDED by
  6.202.0 — the pane shows the chooser's highlight, which the chooser
  itself moves under the pointer; no estimate, no wheel blind spot); ⇪X
  lands on a button/tab inside the typed cell (needs
  Accessibility; the badge names it; `_G.mouseGridReport()` has a snap
  line); ⇪6 🩺 report's verdict reads right on both Macs (work Mac: the
  mDNS flush half needs admin, said honestly), 🚀 speed row finds
  speedtest-cli under ~/homebrew; ⇪Y reaches 180 days only OVER TIME
  (Chrome's 90 is the export ceiling; the archive carries the rest —
  status line says "N kept from the archive"); pomodoro translucency to
  taste (pom.alphaAlert / cardAlpha / inkAlpha).
- Write ledger: a store rewritten whole (⇪I cache, .json, chrome/clipboard
  files, `_G.rewrittenFiles` registry) may shrink silently; >50% loss is
  still reported once. Any NEW rewritten store must register itself.
- 6.156.0 verify with LL: ⌘-drag on a picker moves it (if not: the Console
  "ended before anything moved" line + `_G.windowMoveReport()` "last drag"
  line say why — engine tap vs timer); ⇪Y shows no login pages and the
  empty box scrolls ~30 days; ⇪⇧S (was ⇪⇧T) pane shows a snippet's text / a
  heading's contents, ⏎ on a heading narrows; ⇪L select mode + ⌥⏎ delete
  (asks first; Asana trash 30 days); ⌥Tab slow line names the phase.
  Preview pane is a SERVICE (preview.open/suspend/close from
  clipboard_history). 6.157.0: it reads rows via
  chooser:selectedRowContents(r), so any chooser gets a pane with three
  lines — `rawText` (+ optional `head`/`when`) on each row, hideCallback →
  preview.suspend, preview.open after showPopup. Hand a rowsFn only when
  the module filters for itself. Action/app-list pickers stay without one.
- 6.155.0 verify with LL: an SCR- capture from another tool gets its words
  within seconds of landing (Console: "named on arrival"; ⌘9 row says
  "nothing waiting"); ⇪V pane survives a ⇪⇧-arrow nudge and rides a
  ⌘-drag; no ⚠️ OCR-tag line after ⌘C on a folder; a trackpad click
  after ⇪X lands leaves no watchdog line. Screenshots contract: every path
  the module writes goes in `shots.own` (the watcher skips those);
  `shots.nameTasks` is a SET (one slot dropped concurrent OCRs); any
  `hs.timer.do*` result must be HELD (test_diagnostics sentry).
- Pomodoro weekly report currently fires with the Friday 4:30 tally; LL may
  want a different day/shape once seen.
- 6.158.0 verify with LL: ⇪⇧2 types the clipboard (let go of ⇧ after the
  press — it waits up to 0.6s); `{date:DD/MM/YYYY}` / `{date:DD-MM-YYYY}`
  in a snippet; the three `_G.snippetAdd` Console lines in the NEW IN
  block, once (Mine syncs through OneDrive). `{date:…}` knows D, M and Y
  only — no time letters, by design (M would mean minutes too).
- 6.159.0 verify with LL: ;d/ ;d- ;mp3 expand on a fresh install (they are
  `exp.builtin`; a pack snippet with the same trigger wins and the Console
  says "stands aside" — then rename the built-in); ⇪⇧; rows wear 🖥 ⚙️ 🔁
  🔒 and the 🔒 reason reads right on the work Mac (no admin: root's rows
  say so). Tiers come from owner + path (`ak.systemPaths`,
  `ak.relaunches`), never a name list alone — keep it that way.
- 🚨 6.160.0 mouse_follows HUNG LL's MAC (hs.window reads with no timeout
  inside the AX callback; taps "disabled by macOS"). 6.160.2: every window
  read via hs.axuielement + setTimeout, callback hands off to a held
  timer. 6.161.0 ("MouseFocus no longer works"): ⇪⇧3 is REMEMBERED in
  hs.settings (mouseFollows.active) so it survives a reload; the watchdog
  RESTS 5 min after 2 slow jumps within 60s and returns by itself (held
  mf.restTimer; ⇪⇧3 wakes it sooner); ⇪⇧3 is bound even with
  Accessibility off. Rule for ANY future AX-callback code: no hs.window
  calls, no untimed AX reads, no work in the callback. Verify with LL:
  still ON after a reload, no strikes in `_G.mouseFollowsReport()`, no
  tap-disabled lines.
- 6.179.0 KNOWN LIMIT (stated in core/boot_cost.lua, not hidden): the
  history step does a 16 KB tail read + ~90 byte append on the OneDrive
  CSV, main thread, 4 s AFTER boot. Bounded and off the boot path, and
  the file is written every boot so OneDrive is unlikely to dehydrate
  it — but if a post-boot stall is ever traced there, move the read and
  the append into an hs.task (/bin/cat, /usr/bin/tail). Never move it
  back onto the boot line.
- 6.196.0 verify with LL: FIRST the swap — ⇪space is the app launcher
  now, ⇪D is the big search panel. ⇪⇧D must STILL be the diagnostic
  report (it is deliberately unclaimed so it forwards), and ⇪⇧space is
  still the screenshot browser. Then ⇪. in any app and press "?" — the
  list narrows to only the menu items that have a keyboard shortcut,
  which is the "what can I press in this app" LL asked for. Then drag
  the ⇪/ sheet somewhere on one monitor, click into an app on the OTHER
  monitor, and press ⇪/: it should open THERE, at the same offset. And
  the one that cost four hours: `_G.secureInputReport()` should say
  "off — nothing is holding the keyboard". To see it work, put the caret
  in a password field in Chrome, wait a minute, and run it again — it
  should name Chrome, and the Console should have said so by itself.
  A boot with it held prints a line naming the app; a healthy boot
  prints NOTHING about it, which is deliberate.
  KNOWN AND NOT FIXED, deliberately: LL reported "⇪O is not on the cheat
  sheet pop-up". It IS there — ocr_engine's rows are ⇪O and ⇪⇧O and the
  new gate audit confirms both are the keys actually bound. What LL's
  screenshot appeared to show was "⇧O" and "⇧⇧O", i.e. the ⇪ glyph
  (U+21EA) rendering as ⇧ (U+21E7). ✅ CLOSED 6.198.0 — ASKED AND
  ANSWERED: LL looked at the live sheet and the bar IS there. The sheet
  was right, the screenshot just read small, and no font was touched.
  Keep this as the worked example: a "fix" for a misread screenshot is
  a change with no bug under it.
- 6.200.0 verify — ANSWERED BY LL ON 6.203.0, and the answer was a bug: the
  rule rewrote starts→starets, allows→gallows, convinced→? (inflections are
  not in the base-word list). FIXED 6.205.0; verify that instead. The
  original item, kept for the shape of the ask:
  6.200.0 verify with LL — NOT YET DELIVERED. LL's decision, in his
  words the sequencing question was answered "after you confirm
  6.199.0": build it now, hold the zip until the four already delivered
  are confirmed behaving. When it does go: type somethingg, somethinng,
  somethng, somtething and somethgni — all five become "something" with
  no row written. Then check it leaves alone what it should: an ALL CAPS
  acronym, a camelCase name, anything with a digit, and any word under
  five letters. `_G.autocorrectReport()` gains a "word list" line (ready
  / reading / no word list at …), a count of what it corrected and the
  last dozen changes — that list is how an app that misfires gets added
  to `settings = { autocorrect = { offIn = {…} } }` from evidence rather
  than guessed at. ⇪Z undoes any of it permanently, same as before.
  Rollback for all of it: `settings = { autocorrect = { on = false } }`.
- 6.199.0 verify with LL: `_G.autocorrectReport()` in the Console —
  the one this module never had. Its "⇪Z learned" block should list
  HOw and anything else he has taught it over the years, each with a
  line number and the command that removes it. Then
  `_G.autocorrectForget("HOw")` and type HOw somewhere: it should be
  corrected to How again, with no reload and no text editor. Check the
  report again — HOw is gone from the list, and everything else he had
  learned is still there. If the report shows a "⚠️ dead rows" block,
  those are `fix` rows whose two sides are the same word: they are being
  SKIPPED (obeyed, they turn IDs into Ids), his file is untouched, and
  the line numbers are there so he can delete them if he wants to.
- 6.198.1 verify with LL: the Console error at doc_memory.lua:363 —
  which appeared whenever he quit Word — should be gone. To be sure,
  `_G.docMemoryReport()` has a new "store" line: "read — every row the
  shape it should be" is the healthy answer, and "⚠️ N row(s) DROPPED"
  means his open_documents-<Mac>.json had junk in it and has been
  repaired in memory. Either is fine; "not read yet" this long after
  boot would not be. Then quit Word with a document open and check the
  App Monitor panel still offers "📄 Reopen …" and that ⏎ brings the
  document back — the repair must not have thrown the good rows out
  with the bad.
- 6.198.0 verify with LL — ⇪2 HALF CLOSED, ANSWERED 6.201.0: he tested
  it in Chrome and it still failed, then pasted the result. The borrow
  guard was NOT the bug (his report showed it working: 11 borrows, 10
  left alone, 0 put back) — ⇪2 was writing the whole Scorp Pad Collect
  tab. Rebuilt in 6.201.0; do not re-test the borrow theory.
  Still worth checking from this release: ⇪; → the count row
  that copies, in Chrome, and ⌘V — "N words · N characters" should
  paste. Then check the borrow did not cost him anything: copy
  something, press ⇪8 (define, which reads a selection and writes
  nothing), and ⌘V should still paste what he copied.
  `_G.powerReport()` grows a "⌘C borrow" line — put back / left alone /
  refused — and "last borrow". "Left alone" is the guard WORKING, not a
  failure. Rollback if it ever misbehaves:
  `settings = { power_tools = { restoreGuard = false } }`.
  KNOWN AND NOT FIXED, stated not hidden: the pasteboard watcher is
  suppressed across the whole loan (restoreAfter + 1.0 s), so ⇪2's
  block does NOT appear in ⇪V's clipboard history even though it is a
  copy made on purpose — which is the opposite of what showStats' own
  comment says the rule is. Left alone deliberately: it needs the
  suppression to end at `done` and restart around the restore, and that
  is a change to a SHARED global (screenshots sets it too), which is
  not something to bundle into a bug fix LL is installing blind.
- 6.197.0 verify with LL: `_G.crashReport()` in the Console. It should
  name ~/Library/Logs/DiagnosticReports and, if 6.196.0 ever crashed on
  that Mac, print the FULL PATH of the newest .ips — that is the file to
  send. Then `_G.backupNow()` and look in
  <OneDrive>/Backups/Hammerspoon/<Mac>/RebuildKit/CrashReports: the
  reports should be there. `_G.backupReport()` grows a "crashes :" line
  saying how many are kept and how many are on the Mac. THE ONE TO WATCH:
  if it says "CANNOT READ … grant Hammerspoon Full Disk Access", that is
  the honest answer, not a failure — macOS guards that folder, and the
  ⇪, settings pane is where the grant lives. On a Mac with no crashes it
  says so plainly; the entry is also allowed to report "partial — some
  files unreadable" on the run, which is the same permission, and the
  rest of the kit still copies. Nothing else changed in this release, on
  purpose.
- 6.196.1 verify with LL: THE CRASH. Install it and just use the Mac —
  6.196.0 died natively (no Console line, no Lua error) at boot and
  potentially every minute after, so the test is simply that it stops.
  If it EVER crashes again, the file to send is the newest
  ~/Library/Logs/DiagnosticReports/Hammerspoon-*.ips — its crashing
  thread names the framework, which is the fact that ends the hunt.
  Then `_G.secureInputReport()` should now say "off — nothing is
  holding the keyboard" rather than UNKNOWN, and ⇪⇧D's Secure Input
  capability row should be ✅ within a minute of boot (it read ❔ "not
  probed yet" for eleven minutes on 6.196.0 — that was the crash, not
  patience). And `_G.unifiedSearchReport()` — which is the name I gave
  LL for 6.196.0 and which did not exist then — now lists all fourteen
  stores. His boot said "13 store(s)"; the report names which one is
  empty, and would say FAILED instead if it were broken.
- 6.195.0 verify with LL: ⇪3 — the 🕸 NOTES section opens with a
  "+ new note ⌘N" row; clicking it brings up the same in-window naming
  bar ⌘N does. Then ⇪X, land, and HOLD an arrow: it should cover four
  taps' worth at once and keep speeding up; a single TAP must still be
  the old small step. Then the one that was invisible: press ⌥+arrow
  while the grid labels are still up (two letters in) — it now tells
  you to type the third letter first, instead of doing nothing. Halving
  itself is unchanged and still only works after a landing.
  ASKED, NOT ANSWERED: LL's screenshot of a dark preview popup much
  bigger than the image inside it — "can you make the screenshot pop-up
  the same size as the screenshot?" NOTHING IN THIS CONFIG DRAWS THAT
  POPUP (grepped: no module has that ✕ / drag-dots / 5-glyph toolbar
  chrome); it looks like CleanShot X or similar. Confirm the app with
  LL before changing anything here.
- 6.194.0 verify with LL: the new screenshot keys, in order — ⇪⇧1 blur/
  edit the newest shot · ⇪⇧2 the active window · ⇪⇧3 the 10 s delay ·
  ⇪4 area (unchanged) · ⇪⇧4 text/QR · ⇪5 scrolling · ⇪⇧5 the ⌘1–⌘9
  panel. Then the four that moved out of the way: ⇪⇧Esc pauses
  Hammerspoon (the ⏸ menu bar item and ⌃⌥⌘⇧Esc still do too), ⇪⇧T types
  the clipboard, ⇪1 toggles mouse-follows-focus, ⇪⇧8 reads a QR code.
  ⇪/ should show all of this correctly — if any row still names an old
  key, say so, because the gate cannot check the sheets.
  STILL OPEN, and asked by LL in the same message as this remap: fold
  the Scorp Pad's SCRATCH NOTES into the vault properly ("can we turn
  the Scorp note pad section into a part of the Hammer-sidian? I don't
  think I need something external"), and a "+" to create a new vault
  note the way the pad's + makes a new tab. LL also said the one
  external thing he still needs is "the ability to write into any .csv
  or .txt". NOT yet scoped — the pad's store is JSON and its 4 PM Asana
  task rides on it, so this is a data-shape decision, not a UI one.
  Also open: the ⌘1–⌘9 panel reflowed to read like the ⇪space panel;
  a SNIPPETS window in the ⇪space style; sequential screenshots to the
  clipboard; the Chrome tab scan; @ source discoverability; widening
  `uni.runnable`; vault front-matter completion; ⌘⇧N / ⌘⇧E on the small
  dialog; the ⇪⇧O beach ball; and CANVAS.
- 6.193.0 verify with LL: ⇪V — the ⇪space panel, filtered to @clip.
  That is the one that was dead. ⇪O likewise on @ocr. Then the thing to
  watch for over a day: ⇪space (and ⇪V, ⇪O) should stop STICKING, and
  the Console should stop printing "⇪ released by the watchdog — held
  8s". If it sticks again, paste the Console lines from that moment —
  a "⇪ keyUp seen by unified search" line means the new handshake fired
  and something else is holding it.
  AGREED WITH LL, NOT YET BUILT (next, in this order): the screenshot
  shortcut REMAP — ⇪⇧1 editor · ⇪⇧2 active window · ⇪⇧3 delay · ⇪4 area
  · ⇪⇧4 text · ⇪5 scrolling, exactly as LL wrote it. He chose to MOVE
  the three current owners rather than bend the map: the PAUSE switch
  off ⇪⇧1 (to ⇪⇧0; it stays reachable from the ⏸ menu bar item and the
  ⌃⌥⌘⇧Esc panic chord regardless), type-the-clipboard off ⇪⇧2 and
  mouse-follows off ⇪⇧3, both to keys named in that release. Then: the
  ⌘1–⌘9 screenshot list reflowed to read like the Unified Search panel;
  and a SNIPPETS window in the ⇪space style (⇪⇧S is a chooser today).
  STILL OPEN: sequential screenshots to the clipboard (needs LL's
  go-ahead); the Chrome tab scan; @ source discoverability; widening
  `uni.runnable`; vault front-matter property completion; ⌘⇧N and ⌘⇧E
  on the small dialog; the ⇪⇧O image history beach ball; and CANVAS.
- 6.192.0 verify with LL: ⇪X, type a cell, and when it lands press
  ⌥↓ (or ⌥↑ ⌥← ⌥→). An amber box should appear — the half of the cell on
  that side — with the pointer in the middle of it. Press again and it
  halves again. Do that two or three times onto a small button and then
  space to click: that is the whole feature, and it replaces a lot of
  arrowing. Keep pressing and it will stop at 8 pt and SAY so rather
  than going smaller — that is the floor, not a fault. A plain arrow
  still nudges 8 pt and the box comes with it, so nudge-then-halve
  works. If it is in the way: `settings = { mouse_grid = { halve = false } }`,
  and `_G.mouseGridReport()`'s new "halve :" line says which state it is
  in and how deep the live box is.
  STATED, NOT HIDDEN: LL's diagram put a letter on each half. Landed
  mode may capture no letter (so typing after landing reaches the app),
  so the arrows carry the meaning instead — if LL wants labels anyway,
  that is a NEW decision about that rule, not a tweak.
  Also: after a SNAP the first halve moves the pointer off the control
  it snapped to, into the half's centre. Deliberate — the reason to
  press it is that the snap did not land where he wanted.
  STILL OPEN: sequential screenshots to the clipboard (⇪2 is TEXT only
  and the pasteboard holds one image at a time — the honest shape is a
  multi-select in ⇪space @shots writing FILE URLs; NOT built, needs LL's
  go-ahead); the Chrome tab scan (Automation permission first); @ source
  discoverability; widening `uni.runnable`; vault front-matter property
  completion; ⌘⇧N and ⌘⇧E still on the small dialog; the ⇪⇧O image
  history beach ball; and CANVAS.
- 6.191.0 verify with LL: ⇪N (or ⇪3) — everything in the window should
  read a size bigger, and the SMALL stuff (the ▸ section headings, the
  footer line, the format bar's buttons, the chips) is what to look at:
  nothing in there should be under 12 pt now. The window is wider and
  taller to carry it. If 14 is wrong in either direction it needs NO
  release — `settings = { vault = { fontSize = 16 } }` (or 13 to go
  back), and all three sizes follow it.
  Then HOVER any icon in the header or the format bar: the yellow-ish
  tip should appear centred UNDER the button with a clear gap, and the
  mouse cursor should never be sitting on it. That was the bug.
  STILL OPEN, unchanged by this release: ⇪X SUBDIVIDE (LL's diagram —
  split the landed cell into an upper/lower half, four characters each;
  next up); sequential screenshots to the clipboard (⇪2 is TEXT only and
  the pasteboard holds one image at a time — the honest shape is a
  multi-select in ⇪space @shots writing FILE URLs; NOT built, needs LL's
  go-ahead); the Chrome tab scan (Automation permission first); @ source
  discoverability; widening `uni.runnable`; vault front-matter property
  completion; ⌘⇧N and ⌘⇧E still on the small dialog; the ⇪⇧O image
  history beach ball; and CANVAS.
- 6.190.0 verify with LL: ⇪V and ⇪O — the big ⇪space panel, already
  filtered to the clipboard / OCR log, instead of the old grey chooser.
  ⇪⇧V and ⇪⇧O must be UNCHANGED (they delete and edit rows). If either
  new one is worse: `settings = { clipboard_history = { panel = false } }`
  or `{ ocr_engine = { panel = false } }`, one at a time.
  Then ⇪3 and ⌘N — the naming box is now IN the window, full width, in
  the window's own text size. ⏎ creates, esc cancels the bar and leaves
  the window up.
  Then `_G.backupReport()`: new "stores :" and "mirror :" lines. The
  mirror runs 2 min after boot and every 30 min after — the "last …" line
  should say ok. On a Mac with no OneDrive it must say "nowhere to mirror
  to" rather than going quiet.
  THE LOCAL SWITCH IS OFF. To try it: set `localFirst = true` in
  init.lua (~line 448) and reload. The FIRST boot deliberately keeps
  using OneDrive and says "copying in the background"; when the alert
  says it is copied, RELOAD and the local copy is live. Nothing is moved
  or deleted at any point, and switching back is the same line. Check
  `_G.backupReport()`'s "stores :" line after each reload — it names
  which of the four states it is in.
  STILL OPEN (LL's list): ⇪X SUBDIVIDE — LL asked whether the grid splits
  a cell after landing. It does NOT; that is unbuilt (6.191.0, and LL has
  sent a diagram: after landing, split the cell into an upper/lower half
  each labelled with four characters). Also: selecting several prior
  screenshots and putting them on the clipboard IN SEQUENCE — ⇪2 collects
  TEXT only (`sp.collect`), and the macOS pasteboard holds one image at a
  time, so the honest shape is a multi-select in ⇪space @shots that
  writes FILE URLs (Finder-style), which pastes as several images. NOT
  built, needs LL's go-ahead. Also still open: the Chrome tab scan
  (Automation permission — check System Settings first); @ source
  discoverability (FOURTEEN of them); widening `uni.runnable` so every
  @tool row RUNS (~45 of 99 — through `verifyTools`' two-sided join, per
  the 6.114.0 ⇪⇧R incident); vault front-matter property completion;
  the ⇪⇧O image history beach ball; and CANVAS.
- 6.189.0 verify with LL: ⇪⇧4 a shot, blur something, add a text note
  and an arrow, then press Esc. Press ⇪⇧4 on the SAME image again — an
  alert says the edits are back and they are, blur included, where you
  left them. Then the honest parts: SAVE one (⌘⏎) and reopen it — you
  get the file, not the old session, which is deliberate. Open a
  DIFFERENT screenshot and it opens clean; the slot holds one shot only,
  as LL asked. Nothing here survives a reload and nothing is written to
  disk. If it ever misbehaves:
  `settings = { screenshot_editor = { keepOnClose = false } }`.
  Then the cheat sheet: ⇪/ with a panel over it — ONE Esc must still
  close the panel and leave the sheet up (unchanged). The new half only
  shows itself when something is STUCK: press Esc twice at a panel that
  will not go and the sheet closes with an alert naming it. Run
  `_G.escapeReport()` in the Console at any time — every claimant, who
  wants Esc now, and the last refusal by name. That is the line to paste
  if ⇪/ ever refuses to close again.
  KNOWN, stated not hidden: a PINNED vault legitimately survives Esc, so
  two presses there will also close the sheet under it —
  `settings = { cheatsheet = { escInsist = 3 } }` trades it back.
  STILL OPEN (LL's list): the histories as webview panels matching ⇪space
  with a per-panel rollback flag; the Chrome tab scan (diagnosed —
  `osascript exited 15` is our own 6 s kill of a BLOCKED script, empty
  stderr; check System Settings → Privacy & Security → Automation →
  Hammerspoon before any code change); @ source discoverability (there
  are FOURTEEN, `uni.sourcesJson()` already ships their counts);
  widening `uni.runnable` so every @tool row RUNS (~45 of 99 do — and
  the 6.114.0 ⇪⇧R incident is why each new row goes through
  `verifyTools`' two-sided join); vault front-matter property/value
  completion (nearly free — `f:` is already in the page); the ⇪⇧O image
  history beach ball (a stall — diagnose before touching); and CANVAS.
  ASKED AND ANSWERED, awaiting LL's go-ahead: moving the stores off
  OneDrive to a local folder via init.lua's existing `forceLogsDir` hook
  plus an HOURLY daily_backup push to OneDrive. Finder ALIASES cannot do
  this (io.open/rsync/grep do not follow one) and OneDrive does not sync
  reliably through a symlink. The Vault stays in OneDrive regardless —
  Obsidian opens that exact folder on both Macs.
- 6.188.0 verify with LL: ⇪⇧4, add a text note, click it — a blue dot
  sits at its bottom-right. DRAG THAT DOT: the text grows and shrinks,
  and ⌘Z puts the size back. Then the thing that was actually broken:
  click just OUTSIDE a small label, down its side — it should still
  take, where before it did nothing. Handles should feel the same size
  whatever screenshot is loaded; that is the whole fix (they used to
  shrink as the image grew). Bigger targets if wanted, no release:
  `settings = { screenshot_editor = { handlePx = 16 } }`.
  STILL OPEN (LL's list): the ⇪⇧O image history beach ball (a stall —
  diagnose before touching; the Console lines straight after it happens
  are what is needed), and CANVAS (LL's Obsidian screenshot, 6.188.0 —
  scoped and NOT yet started; see the note below). Judged already
  covered, do not build without LL asking again: Templater (6.174.0
  templates), QuickAdd (⇪N + ⇪2), Linter (the format bar), Folder Note
  (outline + backlinks).
- 6.187.0 verify with LL: ⇪space, then type `@images` — every picture
  the Mac has OCR'd, newest first, with a thumbnail. Type a word that
  is IN one of them (not in its file name) and it should come up: that
  is the whole feature. ⏎ copies the image, ⌥⏎ opens it, ⌘⏎ copies its
  path. Then the honest bits to look for: an image that has been moved
  or deleted still shows its words with "⚠️ the file has moved" and no
  thumbnail; only the newest two dozen get pictures (a thumbnail is a
  main-thread decode, and on a OneDrive-evicted file that is a
  download), so older rows are deliberately picture-less. ⇪O itself now
  names the image beside each timestamp. WORTH TRYING ON PURPOSE: edit
  an entry in ⇪⇧O and check another entry still knows its image — that
  path rewrites the whole file and used to be able to strip every one.
  Note only NEW readings carry an image; everything OCR'd before
  6.187.0 has words and no picture, and that is permanent, not a bug.
  STILL OPEN (LL's list, in his priority order after this): the
  screenshot editor's text-box handles; and the ⇪⇧O image history beach
  ball (a stall — diagnose before touching; the Console lines straight
  after it happens are what is needed). Judged already covered, do not
  build without LL asking again: Templater (6.174.0 templates),
  QuickAdd (⇪N + ⇪2), Linter (the format bar), Folder Note (outline +
  backlinks).
  KNOWN LIMIT, stated not hidden: a shot OCR'd by ⇪4 and later renamed
  by the ⌘9 sweep leaves its first row pointing at the old name. The
  row keeps its words and is marked as moved; the newer row is the live
  one. Fixing it means changing the sweep's naming, which is where the
  6.170.x beachballs lived — not in the same release that moved the
  column.
- 6.186.0 verify with LL: ⇪3, then ⌘⇧B — the board. With no ```kanban
  block in the note it shows every note by `status` and SAYS so under
  the columns; that is the degrade, not a bug. Then "/" on an empty
  line has a "Board — a Kanban of your notes" row: choose it, change
  the tag to one you use, ⌘⇧B. The columns todo / doing / done are
  drawn EMPTY on purpose so there is somewhere to drag to. Now the
  thing to actually try: DRAG A CARD to another column and open that
  note — its `status:` line has been rewritten. Drag one to the last
  column ("no status") and the field is gone from the note entirely.
  A click that does not drag opens the note; a card dropped on nothing,
  or back where it started, writes nothing at all.
  `_G.vaultReport()`'s new "board  :" line counts the moves and names
  the last one — and names any refusal, which is where to look if a
  drag ever appears to do nothing. Worth knowing: the board writes ONE
  line of ONE file and never the body, and it is the only view here
  that writes at all — the queries still never touch a note.
  STILL OPEN (LL's list, in his priority order after this): @images /
  @shots in ⇪space; the screenshot editor's text-box handles; and the
  ⇪⇧O image history beach ball (a stall — diagnose before touching).
  Judged already covered, do not build without LL asking again:
  Templater (6.174.0 templates), QuickAdd (⇪N + ⇪2), Linter (the
  format bar), Folder Note (outline + backlinks).
- 6.185.0 verify with LL: ⇪3 — put a front matter block at the top of a
  couple of notes (--- on line 1, then `status: reading`, `rating: 5`,
  then ---). `_G.vaultReport()`'s new "fields :" line should name them
  within a scan. Then "/" on an empty line has a SECOND query row,
  "Query — filtered by a field": choosing it writes a working
  TABLE + WHERE + SORT block. Change the tag to one you use and the
  matching notes appear with their fields on a second line under each
  name. Worth trying on purpose: `WHERE rating > 3` must find a rating
  of 10 (numeric, not text); `WHERE status` means "has a status";
  `WHERE !status` the ones without; `contains(genre, "x")` looks inside
  a value; `WHERE file.folder = "Projects"` asks about the file itself.
  A note with no `rating:` must NOT appear in `WHERE rating > 3` and
  must sort LAST under `SORT rating`. And the standing promise: the
  note's own text is never touched, no note is read, and a mistyped
  clause is NAMED in the pane while the rest of the query still runs.
  STILL OPEN (LL's list, in his priority order after this): Kanban
  columns; @images / @shots in ⇪space; the screenshot editor's text-box
  handles; and the ⇪⇧O image history beach ball (a stall — diagnose
  before touching). Judged already covered, do not build without LL
  asking again: Templater (6.174.0 templates), QuickAdd (⇪N + ⇪2),
  Linter (the format bar), Folder Note (outline + backlinks).
- 6.184.0 verify with LL: ⇪X — the grid is the nine home-row keys
  again (729 cells, ~70 pt on the 4K), labels readable at a glance and
  no finger off the home row. Land on a toolbar button, a tab, a Save
  button: 6.181.0's second-chance snap should still put the pointer ON
  it even though the cell is now wider than the button —
  `_G.mouseGridReport()` "snap :" says the second chance is on and the
  trail says "wider than the cell" when it fires. If a landing is ever
  off, read that line BEFORE touching the cell size: in 6.181.0 the
  fault was the snap refusing what it had found, not the grid.
  Fine again is one line, no release:
  `settings = { mouse_grid = { alphabet = "asdfghjklzxcvbnm" } }`
  (the 4,096-cell 6.176.0 grid) or `{ labelLength = 4 }` (6,561, four
  keystrokes). RULE, now twice learned: the grid's job is to get you
  CLOSE and the snap's job is to land you — do not buy with cell size
  what the snap already gives free.
- 6.183.0 verify with LL: ⇪3, open a note, put the caret on an empty
  line and press "/" — a new row reads "Query — a live list of notes".
  Choose it: a working block is typed with the caret on the tag. Type a
  tag you actually use and the notes carrying it appear at once in a 🔎
  QUERY section on the right, under the mentions; a click on one opens
  it. Then the things worth trying on purpose: `LIST FROM [[Some Note]]`
  lists everything that LINKS to that note; `LIST FROM "Projects"` lists
  a folder; `-#done` drops the finished ones; add `WHERE rating > 3` and
  the pane must SAY it ignored that line and still show the list. Check
  the note's own text afterwards — nothing was written into it, and that
  is the promise. A note with no query block must look exactly as it did.
  STILL OPEN (LL's list, in his priority order after this): front-matter
  FIELDS in a query (status:, rating: — what WHERE and a TABLE's columns
  need); Kanban columns; @images / @shots in ⇪space; the screenshot
  editor's text-box handles; and the ⇪⇧O image history beach ball (a
  stall — diagnose before touching). Judged already covered, do not build
  without LL asking again: Templater (6.174.0 templates), QuickAdd (⇪N +
  ⇪2), Linter (the format bar), Folder Note (outline + backlinks).
- 6.182.0 verify with LL: ⇪N opens the pad (⇪1 does nothing now — that
  is deliberate, it is free); the section reads 📝 SCRATCH NOTES with
  "+ 🗒 Capture" and "+ ➕ Append" rows under "+ new tab ⌘T", and ⌘W on
  each still files where it always did (the 4 PM Asana task must still
  land, and * idea / + log / ! task / ? note must still sort). Then the
  ⚠️ ITS ⇪2 HALF IS SUPERSEDED BY 6.201.0 — DO NOT RE-VERIFY IT. It
  read: "⌘V pastes BOTH, and ⇪N shows them stacked in a 📎 Collect tab.
  Reload and grab a third: it must join the same block." That surviving
  block IS the bug LL reported — the tab was never emptied and the whole
  tab went to the clipboard. ⇪2 files nothing in the pad now and the
  sequence is session-scoped, both deliberately.
  STILL OPEN (LL's list, in his priority order after this): Dataview-style
  live queries in the vault — a ```query block that builds a list/table
  from tags and front matter, which is the one that serves "see the
  relationships to jog my memory"; then Kanban columns; @images / @shots
  in ⇪space; the screenshot editor's text-box handles; and the ⇪⇧O image
  history beach ball (a stall — diagnose before touching). Judged already
  covered, do not build without LL asking again: Templater (6.174.0
  templates), QuickAdd (⇪N + ⇪2), Linter (the format bar), Folder Note
  (outline + backlinks).
- 6.181.0 verify with LL: ⇪/ — the sheet is 1,024 wide and no entry
  ends mid-sentence any more (the old "…screenshots it. For real" row
  under MENU BAR ITEMS is the one to look at). begone's row says ⇪⇧S,
  which is where the snippet panel has been since 6.161.0 — if the
  banners still do not clear from there, `_G.begone()` in the Console
  says what it found and pressed and `_G.begoneProbe()` maps the window
  for the next address. ⇪3 / ⇪1 — 13 pt text in a 1440×940 window, 90%
  opaque, and HOVERING any icon in the header or the format bar shows
  what it does (that is the new tooltip layer; the titles were always
  there, macOS just never drew them in a non-activating panel). ⇪X —
  land on a wide button (a toolbar button, a tab, a Save button) and the
  pointer should now be ON it rather than beside it; `_G.mouseGridReport()`
  "snap :" line says the second chance is on and the trail says "wider
  than the cell" when it fires.
  RULE from 6.181.0: a cheat sheet entry is written as ONE long string —
  core/cheatsheet.lua joins a blank-key continuation row onto the entry
  above it before wrapping, so hand-splitting is never needed again. And
  a stale key on the cheat sheet IS a broken feature: when a shortcut
  moves, grep the sheets.
  STILL OPEN from that message, NOT built: merging 🗒 Capture and 📝
  Scratch into one "Scratch notes" section inside the vault with the
  other tools' histories reachable from a row; @images / @shots in ⇪space;
  the screenshot editor's text-box handles being hard to grab; and the
  ⇪⇧O image history beach ball (a stall — diagnose before touching).
- 6.180.0 verify with LL: open a Word document, press ⇪⇧U — the picker
  names the document and offers a new note; ⏎ writes `## Linked` +
  a Markdown link into it and opens the Vault there. Press ⇪⇧U on the
  same document again: the note is now the FIRST row. In a browser it
  anchors the front tab (the first press per browser may raise the macOS
  Automation prompt). Then MOVE or rename the file in Finder and ⌘⏎ the
  link in the note — it should say "Moved — opening <name>" and open it
  (that needs the ⇪D index; `_G.anchorsReport()` says whether it is
  loaded). Obsidian must open the same link from the same note.
- 6.179.1 verify with LL: `_G.keyTrailReport()` and
  `_G.bootCostReport()` print WHOLE in the real Console — no
  "↻ that line is repeating" swallowing a row, no ⛔/⚠️ banner spliced
  through the middle. Press the same shortcut three times first; all
  three rows (or one merged ×3 row) must be there.
- 6.179.0 verify with LL: press a few ⇪ shortcuts, then
  `_G.keyTrailReport()` — the last two dozen, newest first, with how
  long each took; ⇪⇧1 (pause) then any shortcut shows a ⏸ row rather
  than nothing. After a few reloads, `_G.bootCostReport()` grows a
  "history:" line comparing this boot with the usual, and
  Logs/boot_cost-<Mac>.csv opens in Excel. Nothing about the trail is
  ever written to disk — if a future ask is "keep the trail across a
  reload", that is a NEW decision (a file), not a tweak.
- 6.178.0 verify with LL: reload and read the Console — most likely
  NOTHING new appears (that means the boot was under 1.5 s and no module
  over 150 ms, which is the good outcome). Then run
  `_G.bootCostReport()`: the ranking, slowest first. If one module is a
  large share of the total, that is the evidence for moving its work
  into warm() or off the work Mac's profile — that decision is LL's, not
  a silent change.
- 6.177.0 verify with LL: ⇪1, then ⌘⇧S — an alert says how many notes
  went to <OneDrive>/Vault/Scratch; open that folder in Obsidian (or
  Finder) and the tabs are there as .md files, front matter on top.
  Type into a tab, ⌘⇧S again — the SAME file updates, no copy appears.
  `_G.scratchPadReport()` "export:" / "last  :" lines say where and
  when. On a Mac without OneDrive the summary says "no OneDrive found —
  local folder" and writes to Logs/vault/Scratch instead.
- 6.176.0 (SUPERSEDED by 6.184.0 — the home row is back; 16 keys was
  "way too small"). ⇪X — the grid was much finer (16-key alphabet,
  4,096 cells, ~30 pt on the 4K where it was ~70); typing three letters
  lands ON a button more often than beside it. Read
  `_G.mouseGridReport()` for the real cols × rows and cell size per
  display. If the first ⇪X after a reload stalls, the Console says so
  once with the fix (`settings = { mouse_grid = { alphabet =
  "asdfghjkl" } }` = the old 729-cell grid); RULE: the grid alphabet and
  labelLength are ONE decision — capacity is alphabet^labelLength, and
  two displays split it by area.
- VAULT/PAD ALPHA — SIX PASSES: 1 → 0.9 → 0.97 → 1 → 0.9 → 0.97
  (6.181.1). LL asked for "90% black", saw 0.9, then said "only 10%
  translucent, much less transparent — still too see through": the same
  number, described as its opposite. What LL judges is how much of the
  app BEHIND shows, not a percentage. If 0.97 is still too much the
  answer is 1 and it needs NO release — `settings = { vault = { alpha =
  1 } }`. Do not spend another release on this number; offer the
  setting. The GUARD is the durable part: at exactly 1 the module must
  never call view:alpha() at all, and below 1 it must really set it —
  both directions are asserted.
- 6.175.0 verify with LL: ⇪3 — the bar over the text (H1 B I • ☑ …),
  hovering a button explains what it types; ⌘B on a selected word bolds
  and ⌘B again unbolds; "/" on an empty line lists the blocks with the
  markdown beside each; the footer names the line you are on. If the bar
  is in the way: `settings = { vault = { formatBar = false } }`.
- 6.174.0 verify with LL: ⇪3 — a `#tag` typed in a note shows in the 🏷
  TAGS list within a scan; ⌘⇧T offers the files in <Vault>/Templates and
  ⌘D uses Templates/Daily.md; ⌘⇧F finds words INSIDE notes and ⏎ lands
  on the line; ⌘⇧K lists open tasks and ⌘L ticks one. 🚨 And the one to
  try on purpose: ⌃⌥⌘⇧Esc with the vault open — everything closes, an
  alert lists what was released, and ⇪⇧1 (or the ⏸ HS menu flag) brings
  Hammerspoon back. `_G.panicReport()` says what it let go of.
- 6.173.2 verify with LL: the Vault window (⇪3 / ⇪1) shows the app
  behind it faintly; if 0.9 is not enough, a lower number in the vault
  alpha override (0.85 = the old pad feel); 1 = solid.
- 6.173.1 verify with LL: ⇪4, select text, then ⇪O — the words are the
  newest row (RULE, now complete: every text screenshots.lua puts on the
  pasteboard goes through `shots.recordText` → `ocr.record`; a new
  clipboard write there must call it). If ⇪O is still empty after this,
  paste the Console lines after ⇪4 — the Shortcut may be failing before
  any text exists.
- 6.173.0 verify with LL: ⇪1 opens the Vault window on the scratch
  tabs (📝 SCRATCH section on top, 🕸 NOTES under); typing into a tab
  survives close + reopen + reload (store unchanged:
  Logs/scratch/scratch.json); ⌘W sends a tab to HISTORY on the right
  and a click brings it back; ⇪N / ⇪2 open Capture / Append tabs there
  and ⌘W files them; the 4 PM task still lands ("Scorp pad · <day>");
  ⇪1 with a note open jumps to the tabs, ⇪1 on a tab closes; 📌 pins;
  no "released by the watchdog" line. If LL wants the old separate pad:
  `settings = { scratch_pad = { viaVault = false } }`.
- 6.172.1 verify with LL: ⇪X, land, HOLD ↓ — the pointer speeds up
  (8→64 pt); a tap still moves 8. ⇪4 a shot, then ⇪O — its words are the
  newest row (rule: OCR done outside ocr_engine calls `ocr.record`; that
  is the only writer of the log). Scorp Pad solid. (The pad/vault MERGE LL asked for shipped as
  6.173.0 — the vault absorbed the pad.)
- 6.172.0 verify with LL: ⇪3 opens the Vault (1240×820) and creates
  <OneDrive>/Vault on first use (Console `_G.vaultReport()` "folder :"
  line; "no OneDrive found — local only" on a Mac without it); ⌘N a
  note, type `[[` and pick, ⌘⏎ follows/creates, backlinks show on the
  target; ⌘G draws the graph; ⌘K picks a file and inserts a relative
  link that ⌘⏎ opens; ⌘D makes Daily/<date>.md; the same folder opened
  in Obsidian shows the notes and links (Obsidian's .obsidian/ folder
  is ignored here); no "released by the watchdog" line after ⇪3.
  Not built yet, on purpose: Markdown preview, rename/delete (Finder or
  Obsidian), tags/#hashtags, full-text search of note bodies (⇪space
  has names only — bodies would mean reading every file).
- 6.171.2 verify with LL: ⇪1 opens a portrait 768×1024 "Scorp Pad", 5%
  translucent (alpha 0.95; `settings = { scratch_pad = { alpha = 1 } }` =
  solid) with 16 px text (`fontSize = 18` etc. in the same override);
  the 4 PM task reads "Scorp pad · <day>". The Sep 6 Finder
  drag lag was VLC streaming from OneDrive, not this config (lag probe is
  DISARMED by default — `_G.lagOn()` + reload to measure).
- 🚨 6.170.3 verify with LL: ⇪4 then type — no "released by the
  watchdog" line (or one saying "the screenshot tool had taken the
  keyboard" after ≤2 s), no "disabled by macOS" tap lines, no beach
  ball; the shot is on the clipboard (paste it). ROOT CAUSE of the
  ⇪4 lock-ups (Console 00:54:53 Sep 6): `screencapture -i` eats the
  F18 keyUp (⇪ latched) AND finish() decoded + re-encoded the 4K shot
  on the main thread (8 s watchdog fired at 29 s). Rules: any path
  that hands the screen to screencapture -i or the area selector
  calls shots.expectHyperRelease(); a screenshot reaches the
  pasteboard via shots.copyToPasteboard (osascript hs.task), never a
  sync writeObjects of a decoded image; the poll asks
  `ocr.imageWanted` before readImage(). Panel ⏎ copies (screenshots
  1180/1358, unified_search) still use writeObjects — next if they
  stall.
- 🚨 6.170.2 verify with LL: after installing, no lock-up; the Console
  after a few minutes shows no "⚠️ clipboard: the pasteboard changed on
  N ticks in a row" line (one = something rewrites the pasteboard
  nonstop — `_G.clipboardPollReport()` has the counts; find the app).
  Raw clipboard image OCR is OFF (`ocr.autoImage`); switch it back on
  per machine (`settings = { ocr_engine = { autoImage = true } }`) only
  once the thrash source is known. Rule: the clipboard poll never
  decodes the pasteboard without typesAvailable() first, and the breaker
  stays.
- 6.170.1 verify with LL: the "HS OCR · Zero-dimensioned image"
  notification stops; if it still shows, `_G.ocrReport()` — "empty N"
  climbing with no notification = the guard works and some app keeps
  an undecodable image on the pasteboard (find it: what was copied /
  which app was front). Rule for ANY caller of the HS OCR Shortcut:
  never hand it an image without a size check, one process at a time,
  hold the task, back off after a failure (screenshots' arrival queue
  already does all four; ocr.image does since 6.170.1).
- 6.170.0 verify with LL: ⇪N / ⇪⇧N / ⇪1 — ⌥↓ highlights a row, ⌥⏎
  acts on it (scratch: restores; note pad: → Task; capture: a parked
  row goes back); plain ↓ inside the text box still moves the caret;
  in ⇪1, ⌘F then ↓/⏎ restores a tab. The hint card now reads 810 wide ·
  30 pt on the Air ("scale 1.50 (pinned…)" in the boot line) — number
  to taste in the Air profile. 6.167.0's two-outcome check is CLOSED:
  outcome (b), the LG is 2560×1440@2x.
- 6.169.0 verify with LL: after ~2 min a "master_log-<Mac>.csv" appears
  in Logs (Excel opens it; newest first) and `_G.masterLogReport()` says
  "index : built …" — if it says "unavailable"/"failed", paste that line
  (the work Mac may lack FTS5 or block ~/Library writes; the CSV still
  builds either way). `_G.masterLogSearch("some words")` prints hits.
  Open Word with a document, then `_G.docMemoryReport()` lists it under
  "open now"; quit Word → the App Monitor panel shows "📂 Spawn with its
  documents" + "📄 Reopen …" rows and ⏎ brings the document back. If the
  report says "no window list (slow or silent app)" for Word, AXWindows
  timed out — raise dm.axTimeout via settings. Gemini's other ideas were
  judged duplicates or refused (renice, screen-flash nag, hs.focus panels).
- 6.168.0 verify with LL: mouse follows focus no longer jumps after a
  click on another window / a Dock click / dropping a dragged window,
  and no longer snaps back to a centre LL moved away from; ⌘Tab / ⌘` /
  a numpad-layer window warp still follow (~0.1 s later).
  `_G.mouseFollowsReport()` "your hand :" shows clicks seen (0 forever =
  the click tap is not running) and "stood still :" names the guard.
  Rule for mouse_follows: the HAND outranks every rule — click grace
  (mf.clickGrace), settle + hand distance (mf.settle/mf.handPx), a centre
  stays yours (mf.repeatGrace); keep any new warp path behind them.
  NOTE: LL's 17:23 Console read init.lua 6.166.0 — 6.167.0 was never
  installed; its two-outcome check below still waits.
- 🚨 6.167.0 verify with LL — TWO OUTCOMES, read the Console either way:
  the boot line "💡 shortcut hints 6.167.0 — card … scale … (… tall ·
  <display> · WxH@1x|@2x)". (a) "@1x", scale 1.50, card 810 wide · 30 pt:
  the 4K-at-full-points theory held and the card is visibly bigger.
  (b) "@2x" / scale 1.00 / 540 wide: the screen was NOT the reason —
  ship `settings = { shortcut_hints = { scale = 1.5 } }` (works either
  way) and keep looking. No such line at all after a reload = an older
  shortcut_hints.lua is still installed (hs-install.sh copies modules/;
  a hand copy of init.lua alone does not) — `_G.shortcutHintsReport()`
  "file :" names the loaded file and its mtime. Twice LL saw no change
  from a size bump (6.165.1, 6.166.0); nothing is proven yet.
  ⇪⇧L: a bigger ring (165 pt radius on the 4K @1x), three rings pulsing
  five times over 6 s with a flashing centre dot; `_G.mouseGridReport()`
  "ring :" line has the radius here and what the last press drew.
- 6.166.0 verify with LL: ⌃Tab cycles the pad's tabs; ⇪⇧U does nothing
  (win_pin gone; any old pins in hs.settings are inert); boot prints no
  EmmyLua lines. (Card size and ring: superseded by 6.167.0.)
- 🚨 6.165.1 verify with LL: after ⇪1 no "released by the watchdog"
  line — or one that says "the scratch pad had taken the keyboard" after
  ≤2 s, or "⇪ keyUp seen by the scratch pad"; typing goes into the pad
  from the first key. WHY the F18 keyUp is lost when the pad opens on
  the home Mac is UNPROVEN (the old ⇪N pad opened the same way; the
  6.162.0 haywire may have been this). Tab names read "Scratch 1" /
  "Capture" / "Append"; the hint card sits top-right.
- 6.165.0 verify with LL: ⇪N opens the scratch pad on a 🗒 Capture tab
  (again = same tab); ⇪2 / ⇪pad2 a ➕ Append tab ("* " seeded by ⇪pad*);
  ⌘W on each files it (Console/alert says where) and the history row
  wears the badge; closing the pad with such tabs open files them and
  keeps plain tabs; the 16:00 Capture flush and 16:01 review still run
  from their own modules; the scratch task never carries kind tabs.
- 6.164.0 verify with LL: ⇪1 opens the pad with typing at once and ⇪1 /
  Esc closes it as fast; text typed then closed is there on reopen and
  after a reload (store Logs/scratch/scratch.json); ⌘T/⌘W/⌘1–9 work from
  the page; a closed tab shows under the text and a click restores it;
  📌 keeps it up across Esc; ⇪space finds pad text; at 16:00 ONE task
  "Scratch pad · <day>" lands in the personal project, assignee LL,
  07:30 → 16:00, with the "Sent by Hammerspoon Scratch Pad" comment
  (`_G.scratchPadSend()` to try now); no "not armed" Console line;
  nothing about it ever holds a key (no tap exists to do so).
- 6.163.0 verify with LL: after ⇪T the card bottom-right reads ASANA · also
  with ⇪A ⇪B ⇪C ⇪L, gone on the first key/click (Esc still closes the
  form), fades by itself at 10s; ⇪V's card sits over the picker without
  stealing typing; ⇪⇧F (right-click) and ⇪⇧2 keep their card (grace
  window); the group filings read right to LL (hint.groups is a settings
  override); `_G.shortcutHintsReport()` shows no "no group" row.
- 🚨 6.162.1 verify with LL: rollback had left the home Mac on 6.160.0
  (the version that hung it; mouse follows starts ON there — LL was told
  ⇪⇧3 off). After installing 6.162.1: no "released by the watchdog" line
  during normal use (one means a keyUp was lost and the guard worked);
  holding ⇪ for a shortcut never drops mid-hold. What stalled at 21:44 on
  Sep 4 is UNPROVEN — suspects: first ⇪⇧S icon pre-render on that Mac.
- 6.162.0 verify with LL: after installing, ⇪⇧S shows ▸ TEXTPANDERS · 80 ·
  yours — pinned first (the 80 files MUST sit in a subfolder named
  `textpanders` inside OneDrive Logs/snippets, beside Mine/ — loose files
  get the top-level label and sort under SNIPPETS unpinned); a textpander
  trigger expands; the work Mac shows the same once OneDrive syncs.
- 6.161.0 verify with LL: ⇪⇧S opens the SNIPPETS (not Asana) with icons —
  an emoji as itself, ✂️/📄/⚙️/⚡ marks; the first open right after a boot
  may show a few rows without icons (pre-render still running; Console
  "icons: N glyphs drawn in K slices"); icon size/placement to taste
  (`exp.iconSize`, the 0.72/0.02 factors in exp.renderIcon); memory on
  the work Mac (`exp.icons = false` if it hurts). ⇪⇧T is FREE — do not
  spend it without LL. Past-task picker: ⇪T's fallback, ⇪space @asana,
  `_G.asanaOpenTaskChooser()`.
- 6.160.4 verify with LL (SUPERSEDED 6.202.0 — the symptom it chased was
  the geometric guess itself, now deleted; verify 6.202.0 instead): with
  ⇪⇧3 on, ⇪Y's pane matches the highlight as the arrows move; moving the
  mouse over a row shows that row with "🖱 under the pointer" in the
  header; 6.161.0: typing a query with the pointer resting on a row puts
  the pane back on the highlight (row 1).
- 6.160.1 verify with LL: ⇪Y (and every picker) opens fully ON the
  screen with the pane beside it; first open after install prints one
  "placement was off the screen … clamped" Console line (the runaway
  offset folding back), then none. showPopup runs in test_integration's
  bare env — no `math`, no `print` inside that block.
