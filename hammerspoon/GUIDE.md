# Hammerspoon config — how the new design works

Version 6.42.0. Keep this next to the config; it is the manual for the
structure, not for the shortcuts (⇪/ is the shortcut list).

---

## 1. What lives where

```
~/.hammerspoon/
├── init.lua          the orchestrator + core services (5,400 lines)
├── secret.lua        Asana token. NEVER backed up, never in the cloud
└── modules/          one file per feature (13 files, ~4,000 lines)
```

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

Everything else is a module.

---

## 2. Installing / updating

```bash
mkdir -p ~/.hammerspoon/modules
cp ~/Downloads/*.lua ~/.hammerspoon/modules/     # module files
cp ~/Downloads/init-6.42.0.lua ~/.hammerspoon/init.lua
```

Modules first, then `init.lua`. Reload Hammerspoon and check two lines in
the Console:

```
Modules:  13 loaded, 0 failed  ·  profile: Lees-MacBook-Air  ·  /Users/…/modules
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
| Something silently wrong | `_G.diag.verbose = true` in the Console, no reload needed |

**A broken module costs you that module only.** Everything else still
loads. That is the main reason this structure exists.

**Panic switches:** `altTab.enabled = false` (⌥Tab), ⌘⇧⌃⌥K, or remove
the module's name from your profile and reload.

---

## 6. Tests

Four suites, 322 checks, run with `lua5.4` — no Mac required, they stub
the `hs` API:

```
test_modules.lua      loader, profiles, warm phase, failure isolation
test_switcher.lua     ⌥Tab: Spaces, minimised, apps, degradation
test_cheatsheet.lua   layout, scrolling, assembled group order
test_diagnostics.lua  ⇪⇧D report + a whole-file audit of init.lua and every module
```

The audit suite is the one to run after any edit: it re-checks that
`init.lua` compiles, every module returns a valid contract, no module
reaches into init.lua's locals, no unprotected `hs.json.decode`, no
discarded timers, and no `hs.window.filter`.

---

## 7. What is left to modularize

| Section | Lines | Note |
|---|---|---|
| 1.6 Cheat Sheet | 746 | infrastructure — consumes module registrations |
| 3.12 Hyper Key | 797 | infrastructure — must run last |
| 2 OCR/clipboard | 341 | shared utilities; splitting means promoting them to core first |
| 5 Hotkey integrations | 263 | small glue |
| 6 Asana dashboard | 387 | pairs with `asana_comments` |

None of these is urgent. The rule for each: **find the helper the
section is squatting on, promote it to core, then move the section** —
that is how `splitCSVLine`, `csvQuote` and `formatDuration` were freed.
