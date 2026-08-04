# Hammerspoon config — 6.31.2

## What's new in 6.31.2 — housekeeping only

No behaviour changes. Three pieces of drift against standing rules, found by
re-reading the 6.9.2 → 6.31.0 transcript:

- **The "Lee additions" app list is out of the header.** You asked for it gone
  back at 6.30.1, but that delivery never reached this file's lineage — the
  copy we've been building on is descended from 6.30.0. It was a stale
  duplicate of the live list in §3.7 (`appMonitorApps`, `init.lua:3874`),
  which is the one the code actually reads. Edit §3.7.
- **Header date is 08-04-26**, per the rule that it moves on every delivery.
  6.31.0 and 6.31.1 both went out still saying 08-03-26.
- **A stale version string.** The §1 tool index still read `6.30.0` while the
  header and the boot print said `6.31.1`. All three now agree.

### Still outstanding from that transcript

**The changelog CSV never landed here.** 6.30.1 added boot-time infrastructure
that writes `changelog.csv` (Date | Version | Change notes) into the OneDrive
Logs folder, seeded 6.10.0 → 6.30.1, append-only and de-duplicated. It is not
in this file — same lineage gap as the header block. Rebuilding it is a real
change rather than housekeeping, so it is left alone pending a decision.

The related rule it was built for still stands: at the 6.x → 7.0.0 crossing,
the verbose in-file changelog compresses to one-liners and the long-form notes
live only in the CSV.

---

# Hammerspoon config — 6.31.1

## What's new in 6.31.1 — the cheat sheet is one searchable column

`⇪/` now opens a **single scrolling column with a search box at the top**,
instead of a canvas that grew a new column every time it ran out of height.

- **Type to filter** — matches the key, the description or the group. Multiple
  words all have to match, in any order, so `asana task` finds the task creator.
- **Fixed height, scrolls.** Adding entries costs scrolling, never screen.
- **Enter copies** the highlighted key combo.
- **Spelled-out modifiers find the glyphs.** The sheet is written in
  `⇪ ⇧ ⌘ ⌥ ⌃ ← ↑ → ↓`, none of which are on the keyboard you'd search with.
  Typing `shift` now finds the `⇧` rows, `cmd` finds `⌘`, `hyper` finds `⇪`.

Two things are genuinely given up, both inherent to using a native picker:
literal 20pt text (`hs.chooser` picks its own row font) and `panelAlpha`
translucency (native macOS panels expose no opacity API — the same limit §1.5
has always noted for the picker lists).

**It takes keyboard focus now**, because a search box you can't type into isn't
a search box. The upside is real: the old sheet floated without focus and so
had to capture `Esc` *globally*, with a warning to close it before pressing Esc
in another app — that hazard is gone. The downside is that you can no longer
type into another window while it's open. Glance and dismiss, rather than leave
it up.

This reverses the 6.10 decision on purpose. That comment said canvas was chosen
*because* `hs.chooser` is single-column only. Still true — and now that's the
requirement.

---

# Hammerspoon config — 6.31.0

`init.lua` is the portable config: one file, runs unchanged on either Mac.
This directory adds nothing to it except the new section described below and
an offline test suite for that section.

## What's new in 6.31.0 — Quick Notes → Asana

A capture box for thoughts you don't want to stop and file. Everything lives in
one immediately-invoked function inside the **EXPERIMENTAL SECTION** (`X.2`),
next to the Document Watcher. Delete the block and the rest of `init.lua` is
unaffected.

| Key | What it does |
| --- | --- |
| `⇪N` | Capture box. Type, press Enter, forget it. |
| `⇪N` → row 2 | Save **and** pick custom fields (any of them, or all). |
| `⇪⇧N` | History — search note text, task title, date or status. |
| `⇪⇧P` | Floating panel. Stays up until Esc. `1`–`9` opens that task. |
| `⇪⇧G` | Send everything waiting now, instead of waiting for 4:00 PM. |

At **4:00 PM** the day's notes become tasks on your personal Asana project
(`asanaProjectId` from §0.2). Stored in `Logs/quick_notes-<mac>.csv`, one row
per note, machine-tagged like every other data file.

### How a note becomes a task title

A note that already starts with a verb is used verbatim:

    Email Dana the invoice   ->  Email Dana the invoice

A note that doesn't can't be honestly rewritten into an instruction, so it is
prefixed rather than guessed at:

    printer toner low        ->  Task from notes: printer toner low

You can always tell which happened by reading the title.

**Known limit, tested and deliberately left alone:** a noun that is also a verb
(`budget numbers for Q3`) reads as imperative and is kept as-is. First-word
detection can't separate those. The failure mode is a slightly awkward title,
never a wrong one.

### The one honest conflict in the design

A panel that *stays on screen while you work* and a *bare number key that opens
a row* cannot both be true — while the panel is up, those digits belong to it.

Bare `1`–`9` is the default because that's what was asked for. `⇪1`–`⇪9` also
always work and never take a key from anything. If the bare digits get in the
way, set `qnPanelBareDigits = false` in the block and you lose nothing but the
shorter keypress. A 30-second watchdog releases the keys if the panel ever
disappears while still holding them.

The panel itself is a canvas with every mouse event switched off, so clicks
land on whatever is underneath it, and it draws at `floating` (3) rather than
`overlay` (102) — the level mistake that had App Lock burying its own PIN
prompt in 6.30.0.

### Tuning

All at the top of the `X.2` block:

`qnPostTime` · `qnPrefix` · `qnProjectId` · `qnPanelRowCount` · `qnPanelAlpha`
· `qnPanelBareDigits` · `qnPanelCorner` · `qnFieldsMaxAge`

## Tests

```sh
cd hammerspoon
lua5.4 tests/quick_notes_test.lua    # 135 checks
lua5.4 tests/cheat_sheet_test.lua    #  82 checks
```

No Hammerspoon and no network required — each suite reads its section straight
out of `init.lua`, so they always test the shipped code rather than a copy that
has drifted. Exit status is 0 only if everything passes.

The cheat sheet suite covers single-column rendering, the search box
(including multi-word AND matching and glyph aliases), the fixed row count,
Enter-to-copy, toggle and reopen behaviour, custom entries, and — its most
useful case — that typing `[`, `\`, `-`, `%`, `(`, `^` and friends into the
search box can't crash it. A cheat sheet is *full* of those characters, and
a search that fed them to Lua's pattern engine would hand it a malformed
pattern.

It covers verb detection, QWERTY folding, CSV round-tripping, malformed-row
rejection, the 4 PM due logic, all five custom-field types end to end
(including the enum/multi-enum pickers and the exact JSON shapes Asana wants),
the sequential send queue, the 401 failure path, and the panel's key
lifecycle.

Two bugs it caught before shipping:

- **Impossible dates were accepted.** `2026-13-99` and `99:99` both satisfy the
  shape check the Document Watcher uses. Here that's not cosmetic — the row
  gets posted to Asana as a real task, and a sent task can't be un-sent. Now
  range-checked.
- **The panel's digit keys** could survive the panel itself. Now released by a
  watchdog.

Verified the suite can actually fail: reverting the date fix turns it red
(`bad rows dropped [4]`, exit 1).

## Installing

Copy `init.lua` to `~/.hammerspoon/init.lua` and reload. The boot report in the
Console gains a line:

    Quick Notes: 12 note(s) · 3 waiting · sends at 16:00

Sending needs `~/.hammerspoon/secret.lua` (see §0.2). Without it, capture and
search still work and the report says so.
