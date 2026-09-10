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
  after 6.194.0: ⇪⇧7, ⇪⇧[, ⇪⇧], ⇪⇧, and ⇪⇧. — check `hint.groups` in
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

Vault (6.172.0, modules/vault.lua, ⇪3): the FOLDER <OneDrive>/Vault of
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
   so there is real headroom rather than a ceiling to fight. Full narrative entry goes at
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

## Known-stale docs — deliberate, do not "fix"

- run-tests.sh's "forty-one suites" comment.
- GUIDE.md's "all 58 modules" wording (near line 679).

## Open items — update as they move

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
  (1) THE VAULT'S ⌘N NAMING BAR ACCEPTS AN IMPOSSIBLE NAME. He pasted a
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
  (3) UNIFIED SEARCH TAKES NO MOUSE AND HAS NO DETAIL PANE — "I can only
  use the arrow keys. There also is no side window that shows the full
  entry." The chooser it replaced had both.
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
  untouched. (3) THE POMODORO ESCALATION SOUND IS **Submarine**
  (/System/Library/Sounds), growing over the last 30 seconds from 24:30.
  (4) The ⇪ glyph question is CLOSED — the bar is there, no font changes.
  🚨 ONE CHANGE PER RELEASE, still: "if these changes will introduce
  issues, only do them one-by-one. We must isolate the changes so we only
  have to fix one thing." And every addition must work on the home Mac
  AND the work Mac.

- Screenshots folder override: waiting on LL to name a path; then ship a
  one-line `settings = { screenshots = { dir = "..." } }` profile override
  with full ceremony. (Verified: zero code changes needed.)
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
- 6.200.0 verify with LL — NOT YET DELIVERED. LL's decision, in his
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
