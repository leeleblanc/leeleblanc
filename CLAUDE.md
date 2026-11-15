# CLAUDE.md — project summary

LL's Hammerspoon config (macOS automation, Lua). All real code is under
`hammerspoon/`. It must run on LL's home Mac AND degrade gracefully on the
more constrained work Mac. Keep this file under 150 lines: build commands,
architecture rules, conventions. The full history — every rule's story, the
per-release verify blocks, rollback SHAs, scoreboard, symptom index and open
items — is in `docs/archive-notes.md` (not auto-loaded; **grep it for the
nouns in LL's sentence before diagnosing anything**). Older notes:
`CLAUDE-archive.md`, `WORKLOG.md`, `UNBUILT.md`, `ALPHA.md`.

## Hard rules — never violate

- `secret.lua` is per-machine, never synced, backed up or deleted. The Asana
  token lives only there — never in the repo, never in a process argument.
- `hammerspoon/packs/` (public) is in git; `snippets/` is gitignored and an
  archive carries ONLY `snippets/bundled.lua`. LL's private textpanders
  (addresses, phone, employee ID) never enter the repo or an archive.
- Backups copy only `~/.ssh/config` — never keys, never the Keychain;
  `secret.lua` and `applock.json` are excluded from every rsync. No rsync
  carries `--delete`. Nothing deletes LL's writing: move to a trash folder.
- `hs.window.filter` is banned. ⇪⇧Z is reserved — do not bind it. Battery
  saver never touches pmset/sudo/brightness; nothing kills or renices apps.
- Tools that read LL's typing (draft keeper, key trail) report COUNTS, never
  text. LL's email and personal details never go to an outside service.
- LL does not edit init.lua: a wrong default is CHANGED AND SHIPPED, never
  handed over as a settings line. Declined features stay declined (see archive).
- Git: commit and push only to the session's assigned branch; no PR unless
  asked; no model identifier in commits, code or docs.

## Build and test

Run from `hammerspoon/` (container may need `apt-get install -y lua5.4`):

```bash
lua5.4 tools/build-snippets.lua .          # packs/ → snippets/bundled.lua (not in git)
bash tools/run-tests.sh .                  # THE GATE: lint + every Lua and JS suite
lua5.4 tests/test_<name>.lua .             # one suite
lua5.4 tests/dump_editor_html.lua modules > /tmp/e.html && node tests/test_editor_js.js /tmp/e.html
lua5.4 tools/hs-lint.lua .                 # also run on any Lua handed to LL to paste
```

A new `tests/test_*.lua` must be named in `tools/run-tests.sh` (a sentry fails
otherwise). Page JS suites take a dumped HTML (`tests/dump_*_html.lua`).

## Architecture

- `init.lua` — the orchestrator only (hard budget: under 3,800 lines). It
  builds the `core` table, the ⇪ (Caps Lock → F18) hyper modal, the service
  registry (`_G.service`), `showPopup`, and loads modules from an EXPLICIT
  list (§1.12). Features belong in `modules/` or `core/`, never init.lua.
- `core/` — shared infrastructure (notices/degrade door, coexist: panel
  ladder, Esc router, drag engine, focus door; hyper_key; capabilities;
  cheatsheet; console; diagnostics). A new core file is added to
  hs-doctor.sh, hs-install.sh (both loops) and INSTALL.md.
- `modules/` — one tool per file. Contract: `M = {name, order, family,
  cheatsheet}` + `M.setup(core)`; optional `M.warm(core)` runs seconds after
  boot. Exactly ONE `M.warm` per module.
- Boot order: setup → profile `settings` applied to `mod.config` → warm →
  `hyperFinalize`. So anything a setting must govern STARTS IN warm, and disk
  reads / watchers / taps belong in warm, never setup.
- Stores live in `<OneDrive>/Logs` (per-Mac CSV/JSON); the notes vault is the
  folder `<OneDrive>/Vault` of plain .md files. Player stores are local.
- `tests/` and `tools/` never reach LL's Mac; `MANIFEST.txt`, `TESTING.md` and
  `RESOLVED-FEATURE-REQUESTS.txt` are GENERATED at ceremony time.

## Coding conventions

- **It degrades, it never breaks.** Assume nothing is installed, loaded,
  writable or granted. Return `ok, why` — do not throw. A break is SEEN:
  `return core.degrade("Tool", why)` (alert + Console + ledger + log).
- Every tool has a `_G.<tool>Report()` that prints ONE string and does not
  also return it. Reports distinguish "not yet" / "none" / "could not ask".
- Hotkeys via `core.hyperAddShortcut`; never answer "is this key free?" from
  notes — run `tests/test_integration.lua` (collision auditor) or
  `_G.freeKeys()`. Move the cheat-sheet row in the same commit as a key.
- Panels: pickers only through `core.showPopup`; webviews through
  `_G.showWebviewSafely`; canvases through `_G.showCanvasSafely`. READ the
  show's answer; assign the handle only after it succeeds; tear down on refusal.
- A text panel calls `_G.hyperExpectRelease(1.5, who)` and forwards F18 keyup
  to `_G.hyperReleaseSeen(who)`. Keyboard taps start with
  `if _G.hsPaused then return false end`. Posted keys go through
  `_G.withInjection`; a tap must never read its own retype.
- Main thread is sacred: no file reads of cloud paths, no `hs.execute`, no
  full app/window enumeration on timers. External commands run in a HELD
  `hs.task` with its own slot and killer timer; never start a task or clear
  its slot from inside a task callback without a held `doAfter(0)` hop.
- Timers are held in a named slot (an unreferenced timer is collected).
- `pcall(f)` where f returns `false, why`: read all three values.
  `a and b or c` cannot carry a false/nil b. `hs.pasteboard.setContents`
  and `hs.task:start()` refuse by RETURNING false — use `core.copyText`.
- Writes to a store: temp file then `os.rename`. Rows identified by path/id,
  never by index. Bounded scans report the bound as a state.
- Pure decision functions (clock, resolver, lister passed as arguments) so the
  gate proves the rule without a Mac. Stubs must be as strict as macOS (arity,
  types, refusals). Assert the RULE, not a literal; mutate to prove a check bites.
- One function, two callers — never two copies of a rule. A list of what
  exists is READ from the registry, not hand-kept.
- Comments carry the WHY and stay; trim on milliseconds, never kilobytes.
- Web pages: `spellcheck="false" autocorrect="off" autocapitalize="off"` on
  every text field; the page says `{a:'ready'}`; push data in, do not rebuild
  the page (a rebuild destroys undo history).

## Release ceremony (every release, one change per release)

1. Three version stamps in init.lua (line 7, the header, `_G.configVersion`);
   the TWO newest NEW IN blocks inline; full entry at the top of CHANGELOG.md.
2. Verify block `- 6.X.Y verify with LL` inserted above the newest one in
   `docs/archive-notes.md` — numbered steps, purpose in plain words, physical
   key names, an EXPECT each. Also there: scoreboard row (only LL scores),
   symptom-index row, rollback SHA line.
3. GUIDE.md counts MEASURED off the gate; then `tools/build-feature-list.lua`,
   `tools/build-test-plan.lua`, and regenerate MANIFEST.txt.
4. Archive per the recipe in root `.gitignore`: build to `/tmp/pkg`, run the
   gate INSIDE it, `hammerspoonX.Y.Z.tar.gz` at repo root, verify (entry count,
   bytes, line 7 of the unpacked init.lua), move the `.gitignore` un-ignore
   line, delete the previous archive in the same commit.
5. Run ceremony scripts in the FOREGROUND with asserted (count == 1) replaces.
   Commit before running mutation sweeps; verify the tree restore by SHA.
6. Deliver the archive INLINE (never a GitHub link) and say entries, bytes,
   the grepped version and the archive commit SHA.

## Working with LL

- Ask for the artefact (a report, a screenshot) before theorising. On NEW
  GROUND (a macOS surface untouched here) ship a probe first and say so.
- Every question for him goes in ONE numbered ❓ QUESTIONS block at the end,
  each saying what the answer decides. Recommend; do not cite his old words back.

## Current state (update or delete when it moves)

- Shipped and installed: **6.441.0** (`hammerspoon6.441.0.tar.gz`).
- Commit d1ba1df holds 6.442.0 (editor: lines drag, canvas grows to fit),
  6.443.0 (Jug Player queue drag-reorder) and 6.444.0 (mouse grid: box at the
  pointer, Return lands) — code and suites green, **ceremony not done**
  (stamps still 6.441.0).
- Not started: 6.445.0 sequential screenshots in `unified_search.lua` (⌘K
  marks rows, ⌘⇧C copies the marked files; file-URL pasteboard write is new
  ground — verify by read-back, fall back to newline-joined paths, say which).
- Owed to LL in words: the OneDrive question for the Chrome archive (leave it,
  or move it and repoint `_G.saved()` and master_log together).
