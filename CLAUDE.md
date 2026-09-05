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
- The hyper hold is TIMED (6.162.1, init.lua §3.12): a lost F18 keyUp
  latched ⇪ and took LL's Mac. Any new path that enters the modal must go
  through hyperEnter (it arms `_G.hyperLatchTimer`); any tap that sees keys
  under ⇪ must call `_G.hyperTouch()`. Never add an untimed way in.

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

Scratch pad (6.164.0, modules/scratch_pad.lua, ⇪1): a webview on the
Capture Pad recipe — NO eventtap, NO AX/window reads, every timer held.
Keystrokes land in `sp.tabs` at once, the store (Logs/scratch/scratch.json,
write ledger) 0.3 s later. The 16:00 task goes through `_G.asanaSubmitTask`
with `extra.comment` (the only Asana path); keep it that way.
6.165.0: ⇪N and ⇪2 open as 🗒 Capture / ➕ Append TABS in it (`sp.openKind`);
closing such a tab files through capturePad.add / notePad.fileAll — the old
modules keep their brains, `pad.viaScratch` / `np.viaScratch` restore their
windows. Kind tabs never enter the pad's own 4 PM task.

Pause switch (6.152.0): ⇪⇧1 toggles `_G.hsPaused` (power_tools). Hyper
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
2. Five most recent NEW IN blocks stay inline in init.lua; older ones drop
   into the trailing "see CHANGELOG.md" note. Full narrative entry goes at
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
  (6.160.4: only a hand that MOVED has the pane — a resting pointer never
  overrules the highlight; the scroll is estimated from the arrows, a
  wheel scroll stays invisible — hs.chooser has no scroll getter); ⇪X
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
- 6.160.4 verify with LL: with ⇪⇧3 on, ⇪Y's pane matches the highlight as
  the arrows move; moving the mouse over a row shows that row with "🖱 under
  the pointer" in the header; after arrowing past the bottom, hovering the
  top visible row shows the right entry; 6.161.0: typing a query with the
  pointer resting on a row puts the pane back on the highlight (row 1).
- 6.160.1 verify with LL: ⇪Y (and every picker) opens fully ON the
  screen with the pane beside it; first open after install prints one
  "placement was off the screen … clamped" Console line (the runaway
  offset folding back), then none. showPopup runs in test_integration's
  bare env — no `math`, no `print` inside that block.
