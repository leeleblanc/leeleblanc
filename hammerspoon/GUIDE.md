# Hammerspoon config — how the new design works

Version 6.49.0. Keep this next to the config; it is the manual for the
structure, not for the shortcuts (⇪/ is the shortcut list).

---

## 1. What lives where

```
~/.hammerspoon/
├── init.lua          the orchestrator (3,479 lines)
├── secret.lua        Asana token. NEVER backed up, never in the cloud
├── core/             dofile'd at a fixed point, NOT loader-managed (4 files)
├── modules/          one file per feature (24 files, ~10,700 lines)
├── tests/            run on any machine with lua5.4; no Mac required
└── tools/            hs-install.sh · hs-doctor.sh · run-tests.sh
```

`core/` is the part that is easy to get wrong when updating by hand.
Those four files are **not** modules — the loader never sees them;
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
M.name  = "My Feature"            -- (`local M = { setup = function() M.x = 1 end }`
M.order = 20                      --  leaves M nil inside the closure.)

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
| ⇪ + number pad does nothing | Accessibility → Pointer Control → **Mouse Keys** eats the whole pad |
| The Capture Pad queue is not emptying at 4 PM | `⇪⇧N` sends by hand; the Console names the HTTP status. Nothing is deleted before Asana returns a gid |
| Capture Pad says a note was "parked" | it failed `maxRetries` sends. It is still in `<logs>/capture-pad/queue.json` |
| Calendar arrows do nothing | the panel has to be open — its keys are a modal, armed only while it is up |
| Something silently wrong | `_G.diag.verbose = true` in the Console, no reload needed |

**A broken module costs you that module only.** Everything else still
loads. That is the main reason this structure exists.

**Panic switches:** `altTab.enabled = false` (⌥Tab), ⌘⇧⌃⌥K, or remove
the module's name from your profile and reload.

---

## 6. Tests

Twelve Lua suites, 1,483 checks, plus 35 more that run the Capture Pad's
page JavaScript under `node`. All of it runs with `lua5.4` on any
machine — no Mac required, they stub the `hs` API:

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
tests/test_focus.lua         ⇪F, over 500 generated meeting days — the mic is never stranded
tests/test_rename.lua        ⇪R, over 400 generated messy folders — no file is ever lost
tests/test_integration.lua   🚨 all 24 modules loaded TOGETHER: shortcut, service and
                             cheat-sheet-slot collisions — the only suite that can
                             catch two modules quietly claiming the same key
tests/test_pad_js.js         the Capture Pad's in-page JavaScript, actually executed
```

**Run them with `tools/run-tests.sh`, not by hand.** It compiles every
file first, runs all thirteen suites in order, and is the thing to trust
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

Yes — the pad is a **separate key path**, and since 6.49.0 it is **live
on two layers**: `⇪ + pad` drives windows, `⇪⇧ + pad` drives tools. It
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
