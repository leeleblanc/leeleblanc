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
6. 🚨 THE CEREMONY SCRIPT RUNS IN THE FOREGROUND AND ASSERTS EVERY
   REPLACE (6.212.0): three releases shipped code without their words
   because the script died inside a backgrounded gate command. Grep the
   three stamps and the NEW IN order back before starting the gate; the
   gate now fails on a wrong header (test_diagnostics 11b) and on a
   GUIDE total it did not count (run-tests.sh's 📏 line).

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
| 6.216.0 | 📶 Bluetooth ⇪⇧7: paired devices, ⏎ connects/disconnects via blueutil; without it system_profiler lists and ⏎ opens System Settings | pending |

Running total: 14 wins · 4 losses · 2 pending (6.215.0, 6.216.0). LL is on
6.214.2 on the home Mac (scored 2026-09-12: "6.214.2 home ✓ ·
6.213.4 ✓ · 6.213.5 ✓ · work Mac later"), then "Go ahead" → 6.215.0
built. The work Mac's storm report is still owed, on 6.215.0 now.

## Open items — update as they move

- 🧭 THE SEQUENCE (LL, 2026-09-13: "Do bluetooth then the best
  sequence you determine" — his seven asks, my order, one per
  release, each scored by him before the next ships): 6.216.0 (d)
  Bluetooth ✔ built; NEXT 6.217.0 (c) init.lua comment trim — it
  MUST be next, init.lua is 3,796 of 3,800 lines and every release
  needs its NEW IN block (no behaviour change, so cheap to score);
  then (e) ⌘Space → the ⇪space launcher as a plain hs.hotkey with an
  off switch (he turns Spotlight's own shortcut off himself); (a)
  ⌥Tab shows the Hammerspoon Console window (window_switcher;
  hs.console.hswindow is BANNED there — go through
  applicationForPID(own pid)); (g) a copied image is the first paste
  candidate in the clipboard history (read what clipboard_history
  does with images FIRST — 6.190.0 sends them to OCR); then the old
  queue's head, click hints (⇪X, Chrome + Finder); (b) the 💾 draft
  keeper LAST of his seven — the least scoped (which fields, where
  the draft goes, how it comes back) and the only one that watches
  his typing; (f) the public sanitised config waits on his strings
  list ("I will after you build"). After those: OCR gibberish, the
  4 PM review, bookmarks CSV, website, Claude door.
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
