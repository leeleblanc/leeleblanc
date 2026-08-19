# Rebuilding this config from nothing

A new Mac, a wiped Mac, or a second one. Follow this top to bottom and you
get an identical working setup — same shortcuts, same behaviour, same data.

**Time:** about 15 minutes, most of it waiting for downloads.
**Admin rights:** not required. Every step below works on a managed Mac
with no admin password. The two steps that *can* use admin are marked
**[optional]** and the config works without them.

---

## What you end up with

```
~/.hammerspoon/
├── init.lua              the orchestrator — profiles, hyper key, pickers
├── secret.lua            YOUR Asana token. Per-machine. Never synced.
├── core/                 9 files, loaded directly by init.lua
│   ├── diagnostics.lua       ⇪⇧D
│   ├── cheatsheet.lua        ⇪/
│   ├── boot_report.lua       the Console's first two lines
│   ├── capabilities.lua      what works on THIS Mac
│   ├── coexist.lua           who gets Esc, the screen, the keyboard
│   ├── hyper_key.lua         ⇪'s second way in, and the proof it works
│   ├── changelog_csv.lua     one Excel-ready row per version
│   ├── console.lua           the ⛔ ERRORS + ⚠️ NONBREAKING sections + repeat limiter
│   └── notices.lua           the failure ledger — nothing fails silently
├── modules/              49 files, loaded by the §1.12 loader
├── tools/                hs-doctor.sh · hs-install.sh · run-tests.sh
└── logs/                 only if there is no OneDrive on this Mac
```

Everything lives under your home folder. Nothing is installed system-wide.

---

## Step 1 — Install Hammerspoon

Download from **https://www.hammerspoon.org** and drag it to
`/Applications`. If you cannot write to `/Applications` on a managed Mac,
put it in `~/Applications` instead — it works identically from there.

Launch it once. It will appear in the menu bar as a hammer icon.

**Set it to start at login:** menu bar hammer → *Preferences* → tick
*Launch Hammerspoon at login*.

> **Why not `brew install hammerspoon`?** Because you do not need Homebrew
> for any of this, and on the work Mac you may not have it. The direct
> download is the same application.

---

## Step 2 — Grant Accessibility

Menu bar hammer → *Preferences* → it will prompt, or:

**System Settings → Privacy & Security → Accessibility → enable Hammerspoon**

**If IT blocks this, keep going.** You lose only the features that move or
hide *other apps'* windows — Window Arranger, App Peek, app summon, Window
Return, Window Pin. Every hotkey, picker, tracker and Asana feature still works. The
config detects this and tells you.

---

## Step 3 — Put the files in place

Download the latest release zip, then (the zip has `init.lua` at its
root — no wrapper folder — so the unzip folder IS the source folder):

```sh
unzip ~/Downloads/hammerspoon-*.zip -d ~/Downloads/hs-new
sh ~/Downloads/hs-new/tools/hs-install.sh ~/Downloads/hs-new  --dry-run
sh ~/Downloads/hs-new/tools/hs-install.sh ~/Downloads/hs-new
```

`--dry-run` shows what it would do and changes nothing. The real run backs
up whatever is already there, installs, verifies, and **rolls itself back
if the verify fails**. It refuses to run as root.

> **Do not just `cp init.lua`.** `init.lua` alone produces a config that
> starts, looks fine, and has silently lost ⇪/ and ⇪⇧D, because `core/` is
> missing. That is the single most common way to break this install, which
> is exactly why the script exists.

**Undo any install:** `sh ~/.hammerspoon/tools/hs-install.sh --rollback`

---

## Step 4 — Create `secret.lua`

This file is **per-machine and deliberately never synced or backed up**. It
does not come in the zip. Create it by hand:

```sh
cat > ~/.hammerspoon/secret.lua <<'EOF'
return {
    asanaToken       = "PASTE_YOUR_PERSONAL_ACCESS_TOKEN_HERE",
    -- Both below are optional. They are IDs, not secrets — leave them out
    -- and the defaults in init.lua are used.
    asanaWorkspaceId = "182448385076670",
    asanaProjectId   = "745948257030523",
}
EOF
chmod 600 ~/.hammerspoon/secret.lua
```

Get a token at **https://app.asana.com/0/my-apps** → *Personal access
tokens* → *Create new token*.

**The file must start with the word `return`.** If it does not, the config
reports `broken: file doesn't return a table` rather than failing silently
— that message means the file exists and has a typo, which is a
thirty-second fix.

**No `secret.lua`?** Every Asana feature turns itself off and says so.
Nothing else is affected.

---

## Step 5 — Tell the config this machine's name

Find the name:

```sh
scutil --get ComputerName
```

Open `~/.hammerspoon/init.lua`, search for `_G.moduleProfiles`, and make
sure there is an entry matching that name exactly (spaces become hyphens —
`Lee's MacBook Air` becomes `Lees-MacBook-Air`).

If there is no matching entry the config uses the `default` profile, which
loads everything. **Nothing breaks either way** — a profile only exists so
you can turn modules *off* on a particular machine.

---

## Step 6 — [optional] The OCR shortcut

Only needed if you want copied images read for text.

1. Open **Shortcuts.app**
2. New shortcut, named exactly **`HS OCR`**
3. Add one action: **Extract Text from Image**, input = *Shortcut Input*
4. Set *Receive: Images* in the shortcut's details

Skip it and image OCR reports itself off. Nothing else changes.

---

## Step 7 — [optional] Homebrew, without admin

Only powers ⌃⌥⇧U update checks. **Nothing else in this config uses brew.**

On a Mac where you have no admin rights, install it into your home folder:

```sh
mkdir -p ~/homebrew
curl -L https://github.com/Homebrew/brew/tarball/master \
  | tar xz --strip 1 -C ~/homebrew
echo 'export PATH="$HOME/homebrew/bin:$PATH"' >> ~/.zprofile
```

The config searches `~/homebrew`, `~/.homebrew`, `~/.local/homebrew`
*before* the admin locations, then asks your login shell. Skip this
entirely and update checks turn themselves off.

---

## Step 8 — Reload and verify

Menu bar hammer → **Reload Config**.

A healthy boot is two lines:

```
🧭 Lees-MacBook-Air  ·  49 modules  ·  95 ⇪ shortcuts  ·  0.43s
   All green.  ⇪⇧D diagnostic report  ·  _G.bootReport() for the full detail
```

(The counts track the config, so yours may read higher — what matters is
the machine name, "All green", and a boot under a second.)

Anything wrong prints its own line instead. Then run the two checks:

**In the Hammerspoon Console:**
```lua
_G.capabilityReport()
```
Prints every capability on this Mac, whether it is on, why, and — when it
is off — exactly what that costs you.

**In Terminal:**
```sh
sh ~/.hammerspoon/tools/hs-doctor.sh
```
Reports what is actually on disk, every external command the config will
run and whether it exists here, and every path it writes to. Read-only.

---

## Step 9 — Confirm it works

| Press | Expect |
|---|---|
| ⇪/ | the cheat sheet — eight family bands, tools A–Z inside each |
| ⇪⇧D | a diagnostic report, also copied to your clipboard |
| ⌥Tab | the window switcher |
| drag any picker's search band | the picker moves — the next one opens where you dropped it (⌘-drag grabs it anywhere) |
| ⇪N | the Capture Pad |
| ⇪X | the mouse grid — type a cell's 3 letters, the pointer jumps there |
| ⇪K | paste a link with `?utm_source=…` first — it should come back clean |
| ⇪⇧H | the tool-health report |
| ⇪M | menu bar icons by name — type to filter, ⏎ opens one |
| ⇪D | every installed app — type its name, ⏎ launches (or focuses) it |
| ⇪Y | 90 days of Chrome history, fuzzy-searched — ⏎ reopens the page |
| ⇪I | the 9 last-opened documents (⌘1–9 opens), then every type you use |
| type `begone` | every notification banner on screen closes; the word deletes itself |
| ⇪Q | focus mode (Quiet) — mutes the mic and dims everything but the meeting |
| ⇪R | bulk rename the Finder selection · undo is the picker's first row |
| ⇪⇧S | search your past Asana tasks — 30 days, ⏎ reopens one |
| ⇪⇧U | pin a note to the window in front — it follows that window |
| ⇪⇧/ | the same ⇪space box, opened on the tools — ⏎ runs one |
| ⇪⇧W | the documents you worked in · ⇪⇧E edits or deletes an entry |
| ⇪O | search everything ever OCR'd · ⇪⇧O edits or deletes an entry |
| 16:01 | a card appears in the corner with the day on it, then fades |
| unplug the dock, replug it | scattered windows return to their docked positions within seconds |
| ⇪pad1 | clipboard → log.txt as a Log note, confirmed with a preview |
| ⇪2 or ⇪pad2 | the Quick Append Pad — lines route by prefix: * idea + log ! task ? note |
| ⇪pad* | the pad pre-typed with * (an Idea) · ⇪pad- with + (a Log) |
| ⇪⇧pad7 | number pad, shifted → window to the top-left quarter |
| ⇪⇧7 | **no number pad?** same zone, number row — 4, 6 and 0 are ⇪← ⇪→ ⇪↑ |
| ⌃⌥⌘V | clipboard history |

If **⇪ does nothing at all**, the Caps Lock remap was refused — check
`_G.capabilityReport()`, which will say so and why. Everything not on ⇪
still works.

---

## Troubleshooting

**Hammerspoon will not start / red errors on reload**
```sh
sh ~/.hammerspoon/tools/hs-doctor.sh
```
Works even when Hammerspoon does not. Check §2 (`init.lua` complete?) and
§4b (`core/` present?).

**Something worked before this install**
```sh
sh ~/.hammerspoon/tools/hs-install.sh --rollback
```
Restores the previous version. Then reload.

**A shortcut does nothing**
`_G.capabilityReport()` in the Console. Most dead shortcuts are one of:
Accessibility not granted, the hyper remap refused, or no `secret.lua`.

**An empty rounded window is stuck on screen**
A half-drawn alert: another app's popup made macOS throw mid-draw ("an
alert could not draw" in the Console). The config sweeps and retries
these itself; for one that got through, run `_G.phantom()` in the
Console — and Reload Config clears it for certain.

**I want the old fourteen-line boot report back**
```lua
_G.bootVerbose(true)     -- persists across reloads
_G.bootReport()          -- or just print it once, right now
```

**I need more detail while reproducing a bug**
```lua
_G.diag.verbose = true   -- until the next reload
```
Everything is recorded to the trail either way — ⇪⇧D includes the last 25
events whether verbose was on or not.

---

## Moving to a second Mac

1. Steps 1–3 exactly as above.
2. Create a **new** `secret.lua` on that machine — do not copy it, it is
   deliberately per-machine.
3. Add that machine's name to `_G.moduleProfiles` (Step 5).
4. Sign into the same OneDrive if you want shared history. Per-machine
   files are tagged with the computer name so the two never overwrite each
   other; `autocorrect.csv` and `custom_shortcuts.json` are shared on
   purpose.

No OneDrive on that Mac is fine — logs fall back to
`~/.hammerspoon/logs` and the daily backup turns itself off.

---

## Before you ship a change

```sh
sh ~/.hammerspoon/tools/run-tests.sh ~/.hammerspoon
```

Syntax on `init.lua`, `core/` and all 49 modules, forty-one Lua suites, then the
Capture Pad's page JavaScript **executed** against a DOM stub. One exit
code. A skipped stage is reported as a skip, never as a pass.

Needs `lua` and `node`, neither of which ships with macOS — so this is a
personal-Mac tool (`brew install lua node`). On the work Mac use
`hs-doctor.sh`, which needs nothing.
