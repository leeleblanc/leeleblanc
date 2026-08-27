# Hammerspoon config — how the new design works

Version 6.58.0. Keep this next to the config; it is the manual for the
structure, not for the shortcuts (⇪/ is the shortcut list).

---

## 1. What lives where

```
~/.hammerspoon/
├── init.lua          the orchestrator (3,508 lines)
├── secret.lua        Asana token. NEVER backed up, never in the cloud
├── core/             dofile'd at a fixed point, NOT loader-managed (10 files)
├── modules/          one file per feature (60 files, ~39,600 lines)
├── tests/            run on any machine with lua5.4; no Mac required
├── snippets/         bundled.lua — 2,006 shipped snippets in one table,
│                     in five collections. Since 6.117.0 the .json packs
│                     it was built from do NOT ship: the expander skips
│                     them whenever the table loads, so they were 797 KB
│                     of ignored files. 6.118.0 sections ⇪⇧T by those
│                     collections — see exp.sectionOrder
└── tools/            hs-install.sh · hs-doctor.sh · run-tests.sh ·
                      build-snippets.lua
```

`core/` is the part that is easy to get wrong when updating by hand.
Those ten files are **not** modules — the loader never sees them;
`init.lua` `dofile`s them at a fixed point during boot, so a missing or
half-copied one takes the whole config down rather than costing you one
feature. `cp init.lua ~/.hammerspoon/` on its own leaves an install
half-updated. Use `tools/hs-install.sh`, which copies all four folders
and verifies them.

`init.lua` keeps only what everything else needs:

| § | What | Why it stays |
|---|---|---|
| 0.1 | Portability layer | resolves OneDrive/paths before anything reads a file |
| 0.2 | Credentials | loads `secret.lua` |
| 0.3 | Hotkey conflict sentry | must wrap `hs.hotkey.bind` before any module binds |
| 0.4 | Hyper migration map | must exist before modules bind |
| 1.4 | CSV/text helpers | four modules and the changelog writer share them |
| 1.5 | Popup positioning | screen resolution + popup placement |
| 1.6 | Cheat sheet | assembles itself from module registrations |
| 1.11 | Diagnostics | ⇪⇧D report |
| 1.12 | **Module loader + machine profiles** | the subject of this guide |
| 2 | OCR / clipboard utilities | shared |
| 3.12 | Hyper key | must run last, after every module claims its keys |

Credentials now also carry `asanaProjectId`, so the Capture Pad and the
Task Creator file into the same project and there is one value to change,
not two.

Everything else is a module.

---

## 2. Installing / updating

```bash
mkdir -p ~/.hammerspoon/modules
cp ~/Downloads/*.lua ~/.hammerspoon/modules/     # module files
cp ~/Downloads/init-6.44.0.lua ~/.hammerspoon/init.lua
```

Modules first, then `init.lua`. Reload Hammerspoon and check two lines in
the Console:

```
Modules:  18 loaded, 0 failed  ·  profile: Lees-MacBook-Air  ·  /Users/…/modules
Boot:     N.NNs to here  ·  ⇪⇧D writes a diagnostic report
```

Anything other than `0 failed` names the file and the reason.

---

## 3. Two Macs, one config

**You may not need to do anything here.** §0.1 has always detected each
Mac automatically — hostname, OneDrive, paths — which is why one file has
always run on both. The `default` profile loads every module, so if both
Macs should behave the same, that is already what happens and the
machine-name entries are decoration.

**Profiles earn their keep only when the two Macs must DIFFER** — a
module you want on one and not the other, or a setting like a lower
⌥Tab cap on a busier work Mac. Then, and only then, name the machine:

```bash
scutil --get ComputerName      # run on the Mac you want to treat differently
```

The same `init.lua` and the same `modules/` folder go on every Mac. The
only thing that differs is the **machine profile** in §1.12:

```lua
_G.moduleProfiles = {
  ["Lees-MacBook-Air"] = { modules = { … } },
  ["Lees-Work-MacBook"] = {
      modules  = { … },
      settings = { window_switcher = { maxWindows = 24 } },
  },
  default = { modules = { … } },
}
```

- **`modules`** — which files load, in load order.
- **`settings`** — per-module overrides applied after that module's
  `setup()`, so a Mac can differ without editing the module.
- An unknown machine uses `default` and says so in the boot report.

**Publishing to the other Mac:**

```bash
# on the Mac you edited
rsync -av ~/.hammerspoon/modules/ "$ONEDRIVE/Logs/ToolConfig/hammerspoon/modules/"
# on the other Mac
rsync -av "$ONEDRIVE/Logs/ToolConfig/hammerspoon/modules/" ~/.hammerspoon/modules/
```

> **Do not** point `~/.hammerspoon/modules` at a OneDrive folder. Files-On-Demand
> can leave a file as an online-only placeholder, and reading one triggers a
> synchronous download — a stall on the boot path at every login.

---

## 4. Writing a module

```lua
local M = {}                      -- declare FIRST, then fill it in.
M.name   = "My Feature"           -- (`local M = { setup = function() M.x = 1 end }`
M.order  = 20                     --  leaves M nil inside the closure.)
M.family = "windows"              -- REQUIRED: its band on the cheat sheet

M.cheatsheet = {                  -- optional; travels with the module
    title   = "🔧 MY FEATURE",
    entries = { { "⇪J", "Does the thing" } },
}

M.config = { threshold = 5 }      -- optional; machine profiles override this

function M.setup(core)            -- REQUIRED. Cheap work only.
    hs.hotkey.bind(core.popupMods, "J", function() … end)

    function M.warm(core)         -- optional. Expensive work, after boot.
        … load a big file …
    end
end

return M                          -- forget this and the loader says so
```

Then add `"my_feature"` to each profile's `modules` list.

### `family` — where it lands on ⇪/ (6.101.0)

The cheat sheet groups its sections into **families**, each under a band,
with A–Z running inside a family rather than across the whole page. Pick
one of these ids:

| id | band |
|---|---|
| `windows` | 🪟 windows & pointer — arranging, switching, aiming |
| `capture` | 🗒 capture & tasks — anything that takes something in |
| `find` | 🔎 find & open — search anything, open anything |
| `files` | 📁 files & documents |
| `text` | ✂️ text & clipboard — what happens to text as it moves |
| `screen` | 📸 screen capture |
| `time` | ⏱ time & attention — the day, and what interrupts it |
| `config` | 🩺 the config itself |
| `auto` | ⚙️ no keys, runs by itself — see below |

The list lives in `core/cheatsheet.lua` → `cheatSheet.families`; reorder
the page by reordering it. **Declare the family in the module, never in a
list over there** — a membership list somewhere else drifts the moment a
module is added. A module that declares nothing shows up under a visible
**🧩 NOT YET FILED** band, and `test_diagnostics` fails until it picks one.

**`family = "auto"`** is for a module with no keys at all. It does not get
a section; it contributes one line to the shared **⚙️ RUNS ITSELF** box,
and that line comes from `M.summary = "…"`, which is then required. Such a
module is listed even with no `cheatsheet` at all.

**Two families in one module?** `M.cheatsheet` may be a **list** of groups,
each with its own `family` — `modules/numpad_layer.lua` does this because
`⇪ pad` captures text while `⇪⇧ pad` moves windows (and a third group: from
6.114.0 the number-row laptop layer, since 6.142.0 the freed-keys ledger that
replaced it). Each group gets its own slot automatically.

### What `core` gives you

| | |
|---|---|
| Paths | `homeDir` `cloudDir` `logsDir` `backupDir` `configDir` `hostTag` |
| Files | `warnWriteFailed` `adoptLegacyFile` `csvQuote` `splitCSVLine` `formatDuration` |
| UI | `showPopup` `resolveBaseScreen` `popupKeys` `popupMods` `panelAlpha` |
| Keys | `hyperAddShortcut(mods, key, fn, name)` |
| Services | `provide(name, fn)` — publish something other code may call |
| Asana | `asanaEnabled` `asanaToken` `asanaWorkspaceId` |
| Debug | `diag` `safeJson` |

**A module never reaches into `init.lua`'s locals.** That rule is what
makes it movable, and a test enforces it.

**`adoptLegacyFile` retires what it adopts** (6.115.0). When a data file
moves to a new path, call `core.adoptLegacyFile(newPath, legacyPath)` and
the old file is copied forward *and then renamed to* `<name>.superseded`
— but only after the copy has been read back and compared. Before this,
the original was left in place forever under a nearly identical name,
which is how `activity_history.csv` ended up existing three times with
only one of them live and nothing on disk saying which. A `.superseded`
file is still read as an adoption source, so retiring one on the machine
that boots first cannot strand the machine that boots second — which
matters because `<Logs>` is inside OneDrive and shared.

**Shared registries: a module fills them, another module reads them**
(6.116.0). There are now four, and they all work the same way — created
with `_G.x = _G.x or {}` so nothing depends on load order, and inserted
into directly so the reader names no writer:

| Registry | Filled by | Read by |
|---|---|---|
| `_G.movablePanels` | every panel and picker | `window_move` — ⌘-drag |
| `_G.escapeClaims` | every panel that Esc closes | `core/coexist` — the Esc router |
| `_G.choosers` | every `hs.chooser` | the Esc router, so pickers close first |
| `_G.editors` | every text surface | `editor_picker` — ⌃⌃ |

🚨 **A registry rots silently.** Nothing errors when a module stops
registering; the feature just quietly has one fewer row, and you find out
by not finding what you were looking for. The escape roster rotted twice
before anyone noticed (`notepad` in 6.99.0, `ocredit` in 6.115.0), so
both it and `_G.editors` now have tests that read `modules/` and fail the
build when an expected registration is missing. Add a registry, add the
scan with it.

**Moving a picker: there are exactly two paths, and only one is a
mouse** (6.129.0). `hs.chooser` exposes no frame getter — the binding
list is `show`/`hide`/`isVisible`/`choices`/`query`/`width`/`rows` and
friends, with no `frame` and no `topLeft`. So a picker cannot be asked
where it is, only told where to go, and `window_move` COMPUTES a grab
box from `_G.lastPopupPlacement` because it is forced to.

| Path | Mechanism | Depends on |
|---|---|---|
| ⇪⇧ ← → ↑ ↓ nudge | `hs.hotkey` → `hide()` then `showPopup()` | nothing in `window_move` |
| ⌘-drag / band drag | `hs.eventtap` → 60 Hz timer → `show({x,y})` | the tap, the placement record, the computed box |

The nudge is a Carbon `RegisterEventHotKey`, so it fires THROUGH a
chooser that owns the keyboard — which is the whole reason it works
where an `hs.eventtap` on a picker is delicate. It has moved pickers
since 6.30 and shares no code with the drag.

🚨 **That independence is only useful if the person can find it.**
6.126.0 through 6.128.0 were spent debugging the mouse path while the
`WINDOW MOVE` cheatsheet group — the one screen you open at the moment a
picker will not move — listed the `⌃⌥⌘R` reset for a nudge whose ARROWS
it never named. A working feature nobody can find is indistinguishable
from a broken one, and it costs more, because the hunt for the bug
happens in code that does not have one. When a fix ships three times and
the report is unchanged, go read what the user was told to press.

**Wrapping a shared constructor instruments everything that uses it**
(6.131.0). Every event tap in this config — `core/` and `modules/` alike
— is born from one function, `hs.eventtap.new`. `core/lag.lua` replaces
that function once, before anything runs, and every tap is timed from
then on. Nothing registers, no module is edited, and a tap written in a
future version is measured the day it is written. It is the same
property the `_G.editors` roster has, reached from the other end: there,
modules opt in by inserting; here, they cannot opt out, because the door
they all walk through is the thing that was changed.

🚨 **Which makes load order load-bearing, so a sentry holds it.** The
probe can only see taps created after it installs. Loaded too late it
would report a partial list that looks exactly like a complete one —
"taps seen: 4" is not visibly different from "taps seen: 9" unless you
already know the answer. `tests/test_lag.lua` §9 therefore reads
`init.lua` and fails if `core/lag.lua` is loaded after `hyper_key`,
after `cheatsheet`, after the module loader, or if any `hs.eventtap.new`
appears above it.

⚠️ **And a measuring tool must not charge for measuring.** The wrapped
callback contains no `pcall` and no `table.pack`: a pcall would swallow
the errors each module's guard counts to switch a broken tap off, and
`table.pack` would allocate on every keystroke — a probe generating the
symptom it was built to find. Two named locals carry the callback's two
return values, which is the whole documented contract.

**A gauge answers "how bad"; finding a culprit needs a switch**
(6.134.0). 6.131.0 could measure every tap and still not settle the
question, because the only control available was quitting Hammerspoon —
which changes nine taps, forty timers and every watcher at once. That
proves the config is responsible and names nothing inside it.
`_G.lagTapsOff()` makes every keyboard tap inert for ninety seconds and
`_G.lagOnly(n)` leaves exactly one running, so the experiment can be run
in steps smaller than the whole application.

🚨 **Inert, not stopped — because the config fights back.** Stopping a
tap is the obvious implementation, and `text_expander` and `autocorrect`
each run a 30-second watchdog that finds a stopped tap and restarts it.
A diagnostic that silently undoes itself half a minute in does not fail,
it *lies*, and it lies in the direction of "the taps are innocent" —
the exact conclusion under test. So the tap keeps running and the
wrapper returns `false` without calling the module's handler: nothing
can re-arm what was never disarmed. It returns `false` and never `true`
for the same class of reason — `true` means "handled", which would eat
every keystroke in the config, and this is a button pressed by someone
whose typing is already broken.

🚨 **Know what your control actually controls** (6.135.0). The inert
switch above is a good answer to the watchdog problem and was, for one
version, the *only* position on the dial — which made it a trap. An
inert tap is still a tap: still registered with macOS, still in the path
the keystroke travels, just meeting a callback that returns at once. So
it measures what the callbacks *do*, and cannot measure what *having*
five taps costs — the dispatch itself, secure input degrading all of
them at once, a stale Accessibility grant. "I ran it and nothing
changed" would therefore have been read as *the taps are innocent* in
precisely the case where the taps are the whole problem: the same
confident wrong answer the inert design was chosen to avoid, reached
from the other side. The fix is a second, stronger position
(`lagTapsGone`) that stops the taps for real and holds the watchdogs
down by name first — and a null result on the weaker one that now says
what it actually rules out. When you build a switch to isolate a
variable, write down which variable it moves; the sentence is short, and
if it does not match the question you are asking, the experiment is
already wrong.

🚨 **A tool must be able to answer whether it is itself the problem.**
The site walker steps deliberately past `core/lag.lua` so a module's tap
is blamed on the module rather than the probe — and that same rule would
have filed the probe's own 20-a-second heartbeat under `init.lua`,
whoever happened to load `core/`. It carries an explicit override so it
appears in its own table under its own name. The question is fair: the
probe shipped in 6.131.0 and the lag was reported again in 6.133.0.

🚨🚨 **Being able to ask the question is not the same as asking it**
(6.136.0). The sentence directly above this one was written in 6.131.0
and repeated in `core/lag.lua`'s own source. The coincidence was noticed,
typed into two files, and then built past — three releases of better
instruments on top of an instrument nobody tested. When you write down a
suspicion about your own work, that is not a note for later. It is the
next experiment, and it goes ahead of the feature.

🚨 **An always-on diagnostic is a permanent tax, so price it before you
levy it** (6.136.0). 6.131.0 argued the probe must always run, because
intermittent lag is not reproducible on demand and the evidence has to
already exist by the time you think to look. That reasoning is sound and
it was still the wrong call, for two reasons worth separating. The cost
was *asserted* — "two clock reads per event" — and never measured; and
the fault turned out to be constant from launch, so the tradeoff bought
nothing and charged full price. A cost you have not measured is not a
small cost, it is an unknown one.

**Know the failure mode of the layer you are standing on.** macOS
disables an event tap whose callback runs too long. Every module here
already knew that — it is the whole reason `text_expander` and
`autocorrect` run watchdogs — so a probe that adds time to every callback
was always able to push taps over that line and get them killed. The
watchdogs then revive them and they are killed again, which from the
outside is "all kinds of keys stopped working". The mechanism was
documented in this repo before the probe was written.

**An off switch must reach the expensive half.** `_G.lagQuiet()` stopped
the probe's heartbeat and left the wrapper — the part actually sitting on
the keystroke path — running. So the config's answer to "is the probe the
problem?" was a switch that could not turn off the probe. 6.135.0 spent a
whole release on the difference between a tap that is INERT and one that
is GONE and never noticed the probe offered itself only the weaker of the
two. If a switch cannot reach the costly part, it is decoration.

**Aggregate by call site when the thing measured is created in a loop.**
Taps are created once and live forever, so a record per creation is a
record per tap. Timers are not, and a record per creation would be a
table that grows for as long as Hammerspoon runs — a leak inside the
tool built to find leaks. `hs.timer.doAfter` is left unwrapped
altogether: it is the hot one-shot, and resolving a call site costs a
stack walk, so measuring it would put a real cost on a hot path in order
to measure cost.

**A shared rule belongs to neither of the tools that use it** (6.132.0).
⇪R renames files and ⇪; transforms selected text, and both needed the
same six case rules. Putting them in either module means the other one
either copies them or depends on a tool it has nothing to do with — and
the copy is the worse outcome, because it drifts SILENTLY: `snake_case`
would mean one thing for a file name and another for a sentence, and no
test, no report and no console line would ever say so.
`modules/text_case.lua` therefore owns all six and has no key, no UI and
no Mac in it at all. Both consumers call `case.apply` through the
service bus at the moment you press the key, so load order does not
matter and a sentry in `tests/test_text_case.lua` §7 reads both
consumers and fails if either grows its own `:upper()` rule again.

🚨 **A delegated rule with no provider must refuse BY NAME.** The
fallback inside `bulk_rename`'s case rules returns the original file
name, which is the safe answer for a rule that cannot run — and on its
own it is indistinguishable from a rule that ran and decided nothing
needed changing. `br.plan` therefore checks for the provider up front
and returns no plan plus "the Text Case module is not loaded", rather
than showing a preview of a rename that would change nothing. Belt is
the refusal; braces is the fallback, for the case where the service
disappears between the plan and the run.

⚠️ **`%w` is ASCII, and that deletes text.** Lua's character classes are
locale-dependent and the locale is C, so `[%w]+` treats the two bytes of
`é` as punctuation. A tokeniser built on it does not mangle café — it
returns `caf`, confidently, with nothing logged. The run class carries
`\128-\255` explicitly, and the other half of the same rule is that an
em dash is above 127 too, so the punctuation that is NOT a letter is
named in a list rather than guessed at from the byte value. Any pattern
in this config that walks user text has the same problem waiting in it.

**When no source is guaranteed, make the sources a list and say which
one answered** (6.133.0). ⇪8 wants definitions and synonyms; there is no
single place to get them that is present on every Mac, offline, free and
ours to read. There are four partial places. So `modules/define.lua`
holds a `providers` list, each with `available()` for THIS Mac and a
`why()` that names the fix, and the panel prints the source that
answered. 🚨 **The reason is not neatness — it is that the silent
failure is indistinguishable from the real one.** "No definition found"
is what a missing `wn` looks like and also what a nonsense word looks
like, and the first is fixed by one `brew install` while the second is
not fixable at all. `_G.defineReport()` is where that distinction lives.

⚠️ **A provider that is a good idea is not automatically a provider you
should ship.** Apple's own dictionary data is the best text on the
machine and already licensed to you. It sits in `Body.data` as zlib
chunks of Apple-schema XML, crackable with the Perl macOS already ships.
It is deliberately absent, because a parser that breaks on a macOS
update fails by handing you GARBLED TEXT rather than by refusing — and
refusing is the only failure this config accepts from something it
cannot verify. The provider list is what makes that a deferral rather
than a decision: it becomes provider 0 the day it is written and nothing
else changes.

🚨 **Anything asynchronous needs a generation number, not just a
callback.** Look up one word, give up, look up another; the first
reply arrives late and repaints the panel under the second word's title,
and ⏎ types the wrong word into a document with everything on screen
agreeing it was right. `d.gen` increments on each lookup AND when the
picker closes, and a reply carrying a stale generation is dropped
without being drawn. Any panel in this config that fills in from a task
or a fetch has the same hazard waiting in it.

**A registry field is the cheap way to add a capability to every
module at once** (6.130.0). `_G.editors` gained one optional field,
`csv`, and that was the whole of "write every editor to one
spreadsheet". No module list, no dispatch table, no file that has to be
edited when a store is added — the same property that makes the roster
itself work.

| Store holds | Supplies | Export gets |
|---|---|---|
| one draft (either pad) | `text` — it already did | one row, free, no change to the module |
| many items (clipboard, OCR, pins, screenshots) | `csv` → `{when, label, text}` list | one row per item |
| neither (screenshot editor, a half-loaded module) | nothing | no rows, and it is NAMED in the report |

🚨 **The fallback is the dangerous half.** `text` is the ⌥⏎ answer and is
deliberately just the newest item, so a multi-item store that forgets
`csv` exports ONE row and the spreadsheet looks finished. Nothing throws,
no count is obviously wrong, and the only way to notice is to know what
should have been there. `test_editor_picker` therefore keeps a list of
the stores that MUST declare `csv` and fails the build when one drops it
— the same shape of sentry as the roster scan above, for the same reason.

⚠️ **And this CSV overwrites, where every other CSV in the config
appends.** The others are logs: one row per event, as it happens. This
one dumps whole stores, so appending would put a thousand clipboard rows
under last time's byte-identical thousand. If you add another export
here, ask which of the two it is before picking the file mode.

**And nothing reaches into a module either.** If code outside a module
needs one of its functions, the module publishes it:

```lua
core.provide("activity.renderChoices", renderActivityChoices)   -- in the module
_G.service.call("activity.renderChoices", "")                   -- anywhere else
```

A missing provider prints which module is absent and returns nil. Calling
the function by bare name instead is what broke ⇪0 in 6.40.0: Lua turns a
vanished local into a nil global, so it fails only when the key is
pressed. The audit suite now scans for exactly that.

### setup() vs warm()

`setup()` runs during boot — bind keys, create objects. `warm()` runs
~2 seconds later on a held timer — load files, scan things. Autocorrect
is the example: the tap starts instantly, the 11,000-row dictionary
arrives in `warm()`. Both phases are timed separately in ⇪⇧D.

---

## 5. When something breaks

**Press ⇪⇧D first, before reloading.** A reload wipes the state that
explains the failure. The report goes to the Console, your clipboard,
and `<logsDir>/diagnostics-<machine>.txt`.

| Symptom | Look at |
|---|---|
| A shortcut does nothing | boot report `Modules: … failed`, and the ⚠️ group at the top of ⇪/ |
| `MODULE FAILED — not found` | the file isn't in `~/.hammerspoon/modules/` |
| `MODULE FAILED — syntax error` | the file is there and broken; the line number is in the message |
| `does not return a table with a setup()` | missing `return M`, or a `do…end` split across the function |
| Slow boot | `BOOT` section of ⇪⇧D — per-stage timings |
| ⌥Tab feels heavy | Console names the SLOWEST APP and its time; put it in `altTab.skipApps` |
| ⌥Tab says "list cut short" | the 0.8s budget tripped; raise `altTab.listBudget` or skip the slow app |
| `attempt to call a nil value (global '…')` | something calls a function that moved into a module — publish it with `core.provide` and call it with `_G.service.call` |
| `No provider for '…'` | that module didn't load; see `Modules:` in the boot report |
| brew errors on every app at once | Homebrew's cache, not your list: `rm -rf "$(brew --cache)/api" && brew update --force` |
| `Homebrew not found` but brew works in Terminal | a no-admin install in your home dir; the Console lists every path tried. Pin it: `M.config.brewPath = "…"` in `modules/update_tracker.lua` (`which brew` gives the path) |
| The screen veil will not go away | `⌃⌥⌘⇧G` — a plain chord, bound outside hyper on purpose |
| An empty rounded window is stuck on screen | a half-drawn alert — another app's popup made macOS throw mid-draw ("an alert could not draw" in the Console). Since 6.100.1 the config sweeps and retries these itself; for one that got through: `_G.phantom()` in the Console, and Reload Config clears it for certain |
| **No ⇪ shortcut works at all** | The config checks itself on your first Caps Lock press and says so. ⇪⇧D shows **hyper PROVEN** and which path carried it. If it never gets proven, F18 is not arriving — check the 🎹 line for what hidutil said, and Accessibility. `_G.hyperSelfTest()` prints what each layer saw, but a zero in its Carbon column proves nothing: a posted event does not reliably reach Carbon |
| Volume changed my whole Mac, not the app | That is the 🌐 label in the alert, and it is a Hammerspoon limit, not a bug — from Lua only Music and Spotify (🎯) can move their own volume. For a REAL mixer use [Vorssaint](https://github.com/vorssaint/vorssaint-utils): free, open source, no driver, no admin — it uses Core Audio process taps (macOS 14.2+, Apple Silicon, System Audio Recording permission). BackgroundMusic and SoundSource also work but install an audio driver |
| An app's volume keeps changing on its own | ⇪. / ⇪, remember a level per app and restore it when you switch back. Set `followFrontmost = false` in `modules/volume.lua`, or ⇪⇧. to see every level being remembered |
| ⇪ works but a NON-hyper global hotkey does not | On a Mac where Carbon is dead, the handful of plain chords in §0.3 stay dead — the fallback covers ⇪ only |
| ⇪ + number pad does nothing | Accessibility → Pointer Control → **Mouse Keys** eats the whole pad |
| The Capture Pad queue is not emptying at 4 PM | `⇪⇧N` sends by hand; the Console names the HTTP status. Nothing is deleted before Asana returns a gid |
| Capture Pad says a note was "parked" | it failed `maxRetries` sends. It is still in `<logs>/capture-pad/queue.json` |
| Calendar arrows do nothing | the panel has to be open — its keys are a modal, armed only while it is up |
| Something silently wrong | `_G.diag.verbose = true` in the Console, no reload needed |

**Reading the Console (6.95.0, split in 6.96.0).** Errors print inside
banners so they cannot hide in the scroll — **two** banners, because
"error" was hiding two situations: `:::::::  ⛔ ERRORS  :::::::` is
BREAKING (a traceback, a file that would not load — some tool is
missing until it is fixed), and `-------  ⚠️ NONBREAKING  -------` is
degraded-but-running (a folder not found, a source skipped, a
permission not granted) — the pile to work through with Claude at
leisure. A line that keeps repeating goes quiet after two showings —
one ↻ notice says so, and the copies are **counted, not lost**. Type
`_G.errorsReport()` in the Console for every unique error this session,
breaking first, nonbreaking after, each with its ×count. Reports you
ask for (⇪⇧D, `_G.bootReport()`, `_G.noticesReport()`) are never gated.
Want the firehose back? `_G.consoleGate.enabled = false` — no reload
needed.
The grey `-- Loading extension:` lines are Hammerspoon itself loading
an `hs.*` extension the first time something touches it (lazy loading);
they print once per extension and cannot be gated from Lua.

**A broken module costs you that module only.** Everything else still
loads. That is the main reason this structure exists.

**Panic switches:** `altTab.enabled = false` (⌥Tab), ⌘⇧⌃⌥K, or remove
the module's name from your profile and reload.

---

## 6. Tests

Sixty Lua suites, 5,783 checks, plus three more that run the Capture
Pad's, the screenshot editor's and unified search's page JavaScript under
`node` for a further 105 — **5,888 checks over sixty-five stages** in
all. Every Lua stage runs with `lua5.4` on any machine — no Mac required,
they stub the `hs` API:

> 🚨 **These numbers have now been wrong three times, in three different
> ways, so they are MEASURED rather than remembered.** Until 6.118.0 the
> suite count said "forty-eight Lua suites", which was the STAGE count
> wearing the wrong label — the three JavaScript suites are `.js` files
> run by `node`, not Lua. 6.118.0 fixed the label and left the stage
> figure at forty-eight, which was *also* wrong: the gate reported fifty
> at the time. And 6.121.0 found the CHECK figure adrift by 63, with no
> way to tell which of the two totals it had once been. It is written as
> both now, and the ambiguity is gone. Read them off the gate rather than
> off this paragraph. The stage count is the gate's own last line; this
> adds up every suite it ran, JavaScript included — drop the `_js` three
> to get the Lua-only figure:
> ```
> sh tools/run-tests.sh . | grep -E '^   ✅ test_' \
>   | sed -E 's/.*— (── [a-z_]+: )?([0-9]+) passed.*/\2/' \
>   | awk '{s+=$1; n+=1} END {print n" suites, "s" checks"}'
> ```

```
tests/test_modules.lua       loader, profiles, warm phase, failure isolation, slot uniqueness
tests/test_switcher.lua      ⌥Tab: Spaces, minimised, apps, degradation, arrow navigation
tests/test_cheatsheet.lua    layout, scrolling, assembled group order
tests/test_diagnostics.lua   ⇪⇧D report + a whole-file audit of init.lua and every module
tests/test_features.lua      Capture Pad · Mini Calendar · Quick Append · Screen Veil · Numpad
tests/test_mouse_grid.lua    ⇪X, and the random-sequence explorer that shrinks its own failures
tests/test_url_cleaner.lua   ⇪K, over 8,000 generated URLs
tests/test_health.lua        ⇪⇧H, over 600 generated timelines / 36,000 events
tests/test_menubar.lua       ⇪M, over 500 generated Mac populations
tests/test_app_launcher.lua  ⇪D, three roots walked one level deep, never inside a bundle
tests/test_chrome_history.lua ⇪Y, the sqlite export, the fuzzy ranking, the CSV round-trip
tests/test_begone.lua        the typed keyword, the osascript sweep, the expander action path
tests/test_recent_docs.lua   ⇪I: the Spotlight scan, learned types, ⇪F aliases, the 9-shelf
tests/test_focus.lua         ⇪Q, over 500 generated meeting days — the mic is never stranded
tests/test_rename.lua        ⇪R, over 400 generated messy folders — no file is ever lost
tests/test_workspaces.lua    ⇪⇧S, 300 generated workspaces — the busy flag never sticks
tests/test_notices.lua       the failure ledger — a notice is never lost, and never floods
tests/test_console.lua       the ⛔ ERRORS + ⚠️ NONBREAKING banners, the repeat limiter
tests/test_lag.lua           ⏱ the keystroke probe — the wrapper must be invisible to
                             the tap it wraps, and must name the file that made it
tests/test_search_index.lua  the ⇪D file index: nice'd find, atomic publish, narrowing search
tests/test_doc_keywords.lua  .docx → keywords → Finder comment; a human's comment survives
tests/test_clipboard.lua     ⇪V, and the writes that must never destroy the history file
tests/test_win_pin.lua       📌 ⇪⇧U notes that follow one window — anchors, the
                             adaptive follow timer, dead-vs-stale, rebind
tests/test_dialog_home.lua   🎯 dialogs land at your spot: the dialog-kind rule, the
                             PRIMARY-screen default, drag capture with self-move
                             suppression, and the Accessibility-off stand-down
tests/test_battery_saver.lua 🔋 on battery the config slows itself: the debounced
                             flip, exact-cadence restore, the hog caller-out's
                             once-an-hour mute, and the desktop no-op — driving
                             the eco registry EXTRACTED from init.lua's source
tests/test_rollup.lua        📊 the 16:01 card: derived from services, silent on an
                             empty day, and it must never take the keyboard
tests/test_select_mode.lua   ☑️ pick-several in the ⇪⇧V/⇪⇧E/⇪⇧O editors — ⇪⇧O drives
                             the real modules/ocr_engine.lua through setup(core)
tests/test_ocr_tag.lua       🏷 which files the clipboard points at: /.file/id= paths
                             resolve, normal misses are silent, anomalies say so —
                             plus ✍️ the ⇪⇧O editor window, and its no-webview fallback
tests/test_file_tracker.lua  📅 the file_changes CSV schema and the migration onto it,
                             against REAL files: the old date text is never parsed
tests/test_task_creator.lua  ⌃⌥⌘T as a module: history, pipe parser, submit — and the
                             token NEVER appears in curl's argument list
tests/test_editor_picker.lua 🗂 ⌃⌃: the state machine that must NOT fire on
                             ⌘C then ⌘V, nor on a ⌃-click or a ⌃-scroll, the
                             wrong-side key that must CANCEL rather
                             than be ignored, the press whose side cannot be read
                             and is refused rather than guessed, and the rule that
                             ⏎ on an open editor never calls show() — both pads
                             toggle, and one of them files
tests/test_right_click.lua   🖱 ⇪⇧F: the events it posts, and the wait for ⇧ to come
                             up before it posts them — a menu reads the modifiers
                             held when it opens
tests/test_write_ledger.lua  💾 _G.saved() against REAL files in a temp tree: the
                             round trip, the twin detector, and the silence
tests/test_keycaster.lua     ⌨️ ⇪⇧B: what earns a line, the panel that grows to fit,
                             the app header and its cache, and the expansion hook
tests/test_menu_search.lua   🔎 ⇪.: the AXMenuItemCmdModifiers bitmask, whose ZERO
                             means ⌘ and whose bit 3 means "no ⌘" — and the extra
                             AXChildren level that makes a naive walk find nothing
tests/test_settings_panes.lua ⚙️ ⇪,: which values get the x-apple.systempreferences:
                             prefix, and an hs.fs.dir stub that REFUSES to iterate
                             without its directory object
tests/test_app_kill.lua      💀 ⇪⇧;: the two-ps join over paths with spaces in them,
                             a comma decimal separator, and the four names that
                             stay refused even under ⌥
tests/test_power_tools.lua   🧰 ⇪;: secure input checked BEFORE a character is typed,
                             the clipboard typed exactly ONCE, and the borrowed
                             clipboard put back on every path
tests/test_text_case.lua     🔠 the six cases: where a word starts, why an accented
                             letter is not punctuation, and why camel/kebab/snake
                             run per line rather than over the whole selection
tests/test_define.lua        📖 ⇪8: WordNet parsed from captured output, and the
                             abandoned lookup whose late answer must never repaint
                             the panel you have moved on to
tests/test_tab_search.lua    🗂 ⇪⇧': the running-process check that stops the scan
                             LAUNCHING every browser, and the jump that verifies
                             the URL it landed on before calling it a jump
tests/test_net_tools.lua     🌐 ⇪6: the host never touches a shell, every command
                             is bounded by -c/-m/-w, and a half DNS flush is
                             reported as a half flush
tests/test_mac_panel.lua     🖥 ⇪7: df's kilobytes become bytes exactly once, and
                             the card draws on the keypress rather than waiting
                             three seconds for system_profiler
tests/test_arranger.lua      🎬 ⇪[ / ⇪]: a stub window that accepts origins and
                             refuses sizes — a VLC in miniature — proving the
                             frame is read BACK and the alert never claims a
                             move that did not happen
tests/test_activity_url.lua  🌐 the url column: the AppleScript's exact-match
                             allow-list, incognito failing closed, secrets cut
                             from the query AND the fragment, and the tab-switch
                             race driven through the real poller
tests/test_integration.lua   🚨 all 58 modules loaded TOGETHER: shortcut, service and
                             cheat-sheet-slot collisions — the only suite that can
                             catch two modules quietly claiming the same key
tests/test_pad_js.js         the Capture Pad's in-page JavaScript, actually executed
```

**Run them with `tools/run-tests.sh`, not by hand.** It compiles every
file first, runs every suite in order, and is the thing to trust
before copying anything to a Mac:

```bash
~/.hammerspoon/tools/run-tests.sh
```

Each suite also stands alone — it finds `~/.hammerspoon` on its own, or
takes the path as its first argument:

```bash
for t in ~/.hammerspoon/tests/test_*.lua; do lua5.4 "$t"; done
```

`tests/loader_test.lua` is deliberately **not** in that list and will
error if you run it directly. It is not a suite; it is §1.12's real
loader, extracted so `test_integration.lua` can `dofile` it against a
stubbed `hs` instead of testing a hand-copied imitation of it.

The six newest suites are **property-based**: rather than checking
listed cases, they generate random input and assert things that must be
true of every result — cleaning an already-clean URL changes nothing,
the menu bar scan returns inside its budget however many apps are
wedged, no staleness alert fires twice in one day. When one fails it
shrinks the failing input to the shortest version that still fails. Read
6.47.1 and 6.48.0 in `CHANGELOG.md` for what that turned up — including
the findings that were faults in the *tests* rather than the modules, and
the two real bugs the integration suite caught in 6.48.0 before it
shipped (a cheat-sheet order tie caused by `13.10 == 13.1` in Lua, and a
module count in INSTALL.md that no longer matched disk).

`tests/test_features.lua` takes the **modules** folder rather than the
config folder, and wants a real timezone:

```bash
TZ=America/New_York lua5.4 ~/.hammerspoon/tests/test_features.lua
```

The timezone is not decoration — three of its checks step a date across
a real daylight-saving change. Under UTC they pass without proving
anything.

The audit suite is the one to run after any edit: it re-checks that
`init.lua` compiles, every module returns a valid contract, no module
reaches into init.lua's locals, no unprotected `hs.json.decode`, no
discarded timers, and no `hs.window.filter`.

---

## 7. What is left to modularize

§1.6 Cheat Sheet and §1.11 Diagnostics are **done** — 6.46.1 moved them
to `core/cheatsheet.lua` and `core/diagnostics.lua`, leaving a ~30-line
`dofile` stub at each original position so the boot order is byte-for-byte
unchanged. That is the pattern for anything below that is infrastructure
rather than a feature: it cannot become a loader-managed module (the
loader runs too late), but it can leave the file.

| Section | Lines | Note |
|---|---|---|
| 3.12 Hyper Key | 838 | infrastructure — must run last, after every module claims its keys |
| 2 OCR/clipboard | 341 | shared utilities; splitting means promoting them to core first |
| 6 Asana dashboard | 387 | pairs with `asana_comments` |
| 5 Hotkey integrations | 263 | small glue |

None of these is urgent. The rule for each: **find the helper the
section is squatting on, promote it to core, then move the section** —
that is how `splitCSVLine`, `csvQuote` and `formatDuration` were freed.

Headroom in `init.lua`'s main chunk: **111 of the 200 local slots free**
(measured, not estimated — a probe that binary-searches how many extra
`local` declarations still compile). All 22 features live in modules and
spend none of them; that is the whole point of the split, since the 200
limit is per chunk and hitting it is a compile error that takes the
entire config down rather than one feature.

---

## 8. The number pad, as a second keyboard

Yes — the pad is a **separate key path**, and it is **live on two
layers**: `⇪ + pad` is the capture row (6.99.0 — see below), `⇪⇧ + pad`
drives windows. It
sends its own key codes, so `⇪7`, `⇪pad7` and `⇪⇧pad7` are three
different shortcuts and all three are free:

| | number row | number pad |
|---|---|---|
| `1` | 18 | 83 |
| `2` | 19 | 84 |
| `7` | 26 | 89 |
| `0` | 29 | 82 |

Check any of them yourself in the Console: `hs.keycodes.map["pad7"]`.
Hammerspoon knows `pad0`–`pad9`, `pad.`, `pad+`, `pad-`, `pad*`, `pad/`,
`pad=`, `padenter`, `padclear`.

The hard part is not binding them, it is remembering them. So
`numpad_layer.lua` is a **map rather than a list**: the pad is a 3×3 grid
and your screen is a 3×3 grid, so each key does what its own position
looks like.

```
   7  8  9        top-left ·  top half  · top-right
   4  5  6   →    left half ·  centre   · right half
   1  2  3        bottom-left · bottom half · bottom-right
   0              maximise        pad.  put it back
   + -            grow / shrink   / *   previous / next monitor
```

The plain `⇪ + pad` layer is the **capture row** (6.99.0, re-cut
6.100.0):

```
   ⇪pad1   clipboard → log.txt as a Log note, instantly
   ⇪pad2   the Quick Append Pad — one box, four destinations
   ⇪pad3   clipboard → pick Logs or Ideas (the ⇪⇧J picker)
   ⇪pad4   split the two most recent windows (same move as ⇪\)
   ⇪pad*   the pad, pre-typed with "* " — an Idea
   ⇪pad-   the pad, pre-typed with "+ " — a Log
```

**No number pad?** (6.114.0) `⇪2` opens the Quick Append Pad — the same digit
as `⇪pad2`, and the pad's only door until this release, since `note_pad.lua`
binds no letter. The other five are runnable from `⇪space`: they were always
listed there, and ⏎ handed you the key string instead of running them, because
`uni.runnable` had no entry. The window map had a laptop layer too — `⇪⇧` + the
number row, 6.114.0 to 6.141.0 — until LL had it cleaned and cleared in
6.142.0: those keys are **future shortcut options** now (`_G.freeKeys()`
lists them from the live registry), `⇪⇧9` went to Invert colours, and on a
laptop the halves/maximise/put-back/monitor moves remain on `⇪←` `⇪→` `⇪↑`
`⇪↓` and `⇪[` `⇪]`.

In the pad, every **line** routes by its prefix — `*` Idea, `+` Log,
`!` Asana task, `?` Asana note (the last two go into the Capture Pad
queue and ride its 16:00 send) — and a plain line is a Log. **Closing
the pad files everything in it**; at **16:01** daily it opens itself
with today's notes and asks which should become tasks.

Everything filed as an Idea or Log also lands as one row in
`<logs>/notes/notes.csv` — `Date, Note Type, Note entry` — which Excel
opens by double-click. The rest of the layer (`pad0`, `pad5`–`pad9`,
`pad.`, `pad/`, `padenter`, `padclear`) stays free.

To use the pad for something else, edit `numpad.actions` at the top of
`setup()`. A value may be a zone name, a function, or the name of a
published service:

```lua
numpad.actions.pad9 = "capturePad.flush"   -- any core.provide() name
numpad.actions.pad8 = function() hs.reload() end
```

Two things outside Hammerspoon will stop the whole layer working:
**Accessibility → Pointer Control → Mouse Keys** takes the pad for the
cursor, and a keyboard without a pad never sends the codes at all (which
is harmless — the bindings just sit there, correct again the moment the
full-size keyboard is plugged back in).
