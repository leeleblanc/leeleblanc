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
- `snippets/` is gitignored because it holds real personal data (email
  addresses, a phone number, an employee ID). Delivered zips carry ONLY
  `snippets/bundled.lua`. Release zips are build artifacts — never committed.
- Backups copy only `~/.ssh/config` — never the keys beside it, never the
  Keychain. daily_backup excludes `secret.lua` and `applock.json` from every
  rsync.
- `hs.window.filter` is banned in the config (sentries enforce it).
- Battery saver never dims the screen, never touches pmset/sudo; the hog
  caller-out never kills/pauses/renices apps.
- ⇪⇧Z is reserved for later — do not bind it.

## Module contract

Each module: `M = {name, order, family, cheatsheet}` plus `M.setup(core)`.
Services via `core.provide`; hotkeys via `core.hyperAddShortcut`; panels via
`core.showPopup` (never a bare `:show()`); Esc handling via the
`_G.choosers.X` registry; diagnostics as `_G.<tool>Report()` globals;
binaries as UPPERCASE constants; chooser row values are scalars. Profile
`settings` overrides are applied AFTER setup into `mod.config` (init.lua's
"apply settings" block), so a settings override needs zero module changes.

Pause switch (6.152.0): ⇪⇧1 toggles `_G.hsPaused` (power_tools). Hyper
shortcuts are suppressed CENTRALLY in init.lua's hyperBind (the pause key
itself is exempt via `_G.hsPauseCombo`, published before binding); every
keyboard TAP handler must start with `if _G.hsPaused then return false end`
(autocorrect, expander, key caster do). Taps stay running while paused.

⌥Tab (6.152.0): macOS AX never returns another desktop's windows from
`app:allWindows()` (minimised yes, other-Space no) — the switcher serves
them from `altTab.known`, a memory fed by every listing; z-order comes from
`hs.window._orderedwinids()`. `hs.window.orderedWindows()` is banned there
(it re-runs the whole sweep internally; the test counts calls).

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
   run `lua5.4 hammerspoon/tools/build-snippets.lua hammerspoon --check`
   first; init.lua sits at the zip ROOT (no wrapper folder); snippets pruned
   to bundled.lua only; re-run `tools/run-tests.sh` from INSIDE the unpacked
   package; zip named `hammerspoonX.Y.Z.zip` at repo root, gitignored.
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
- ⌥Tab: 6.153.0 budgets the memory probes — LL's "very slow" console line
  (1.64s across 13 apps, slowest 0.01s) was the probe loop re-proving every
  remembered window unbudgeted. Verify: presses fast again; a still-slow
  "listing took" line now names its phase ("memory: N probed in X.XXs").
  Memory still learns one press per desktop per reload; if a learned window
  never shows, ask for `_G.altTabLastListing` (remembered/probed/probeSecs).
- 6.153.0 verify with LL: ⇪T takes typing the moment it opens (non-activating
  mask, read-back verified), drags by its header, SAC Values are checkbox
  chips; ⇪Y ⌘⏎ copies the URL, ⌥⏎ opens in Safari (chrome.altBrowser).
- Pomodoro weekly report currently fires with the Friday 4:30 tally; LL may
  want a different day/shape once seen.
