# Hammerspoon config — 6.31.4

## What's new in 6.31.4 — the two deferred items, and EmmyLua

- **Hard 50,000-row cap on both tracker CSVs.** This was the one with teeth.
  Chunked loading (6.11.3) stopped a huge history from *blocking* boot, but
  nothing stopped the file growing back to the ~400,000 rows that caused the
  original 13-second beachball. It keeps the **newest** rows and prints what
  it trimmed.
- **`changelog.csv`** in your Logs folder — Date | Version | Change notes,
  appended once per version, never duplicated.
- **One version string instead of three.** Three separate literals is exactly
  how 6.31.1 shipped a stale `6.30.0` in the tool index: two got bumped, one
  didn't. Everything executable now reads `_G.configVersion`, so that class of
  mistake can't recur. The header banners are comments and still need a manual
  bump — that's the one copy the code can't reach.

## EmmyLua — what it is, and the half you have to do

**In plain terms:** Hammerspoon has hundreds of functions (`hs.pasteboard.…`,
`hs.canvas.…`). EmmyLua writes out a set of files describing every one of them
— its name, what arguments it takes, what it gives back. A code editor that
can read those files will then finish your typing and **underline a call you
got wrong as you write it**, instead of you finding out after a reload when
something quietly does nothing.

That's why it's worth having here specifically. Several real bugs in this
file's history were exactly that shape: `hs.pasteboard.readURL` returning a
different type than assumed, and a canvas `replaceElements` call whose
signature was in doubt. Both *parse fine* — `luac` can't see them. A language
server can.

**It costs nothing at runtime.** It writes the files and stops. No hotkey, no
timer, no watcher. If it isn't installed, boot prints one line and carries on,
so the config stays portable to your work Mac.

### Setup — two halves, and the second is the one people miss

**Half 1 — install the Spoon** (once per Mac):

1. Download from <https://www.hammerspoon.org/Spoons/EmmyLua.html>
2. Double-click `EmmyLua.spoon` — it installs into `~/.hammerspoon/Spoons/`
3. Reload Hammerspoon. The console should say
   `💡 EmmyLua: hs.* annotations refreshed for your editor`

That generates the files into
`~/.hammerspoon/Spoons/EmmyLua.spoon/annotations/`.

**Half 2 — point your editor at them.** Until you do this, half 1 has
accomplished nothing visible.

| Editor | What to do |
| --- | --- |
| **VS Code** | Install the **Lua** extension by *sumneko*, then add the `annotations` path above to the `Lua.workspace.library` setting. Easiest path by a wide margin. |
| **Sublime Text** | Package Control → install `LSP` and `LSP-lua`, then add the same path to `LSP-lua`'s library setting. |
| **CotEditor** | **Won't work.** No language-server support at all. It's a fine editor, it just can't do this. |

Since you use CotEditor and Sublime, Sublime is where you'd see the benefit —
or VS Code if you'd rather take the easy road.

---

# Hammerspoon config — 6.31.3

## What's new in 6.31.3 — desktops, the W swap, and a reconciliation

### Move a window to another desktop — `⇪⇧[` / `⇪⇧]`

The bracket keys now cover both axes:

| Key | Moves the focused window |
| --- | --- |
| `⇪[` / `⇪]` | one **monitor** left / right (wraps) |
| `⇪⇧[` / `⇪⇧]` | one **desktop** (Space) back / forward (wraps) |

Bare is physical, shift is virtual.

**This is the least trustworthy code in the file, and you should know that
going in.** It rides on `hs.spaces`, which drives private CoreGraphics calls
Apple doesn't support and has changed between macOS releases; Hammerspoon has
removed and reinstated the module more than once. Everything else in this
config uses public API. So X.3 is built to fail *loudly and specifically* —
every failure path names the step that broke. If a macOS update kills it,
the key tells you rather than doing nothing.

Known limits, none fixable from here: native full-screen windows can't move
between desktops (macOS gives them their own space); full-screen spaces are
excluded from the ordering; it needs Accessibility permission.

### The `⇪W` fix

`⇪W` summons an app to your monitor again, and the Document Watcher moved to
`⇪⇧W`. This was promised in a delivery that never reached this file — which
is exactly why pressing `⇪W` kept opening the wrong thing.

### Other

- **OCR failures are no longer silent.** A file that isn't an image stays
  quiet (console only). An image we *tried* and failed on now alerts, naming
  why: shortcut error, no text found, or nothing typeable. All three were
  bare `return`s.
- **`panelAlpha` 0.80 → 0.90** — your "10% less translucent," also from the
  missed delivery.
- **Hammerspoon is in the update tracker** (§3.10).

### Reconciliation — why these kept surfacing one at a time

This file descends from **6.30.0** and silently missed everything delivered
after it. Rather than keep finding that one item at a time, I audited every
feature promised across the whole history against what's actually here.

Two things were still missing at 6.31.3 and were deferred rather than rushed
in at the end of a long session — **both landed in 6.31.4 above**: the
50,000-row cap on the tracker CSVs, and the `changelog.csv` writer.

## Tests

```sh
cd hammerspoon
lua5.4 tests/quick_notes_test.lua    # 135 checks
lua5.4 tests/cheat_sheet_test.lua    #  82 checks
lua5.4 tests/spaces_test.lua         #  33 checks
lua5.4 tests/retention_test.lua      #  27 checks
```

The retention suite guards the one destructive operation in the config: the
row cap deletes rows from your real history on every boot, so keeping the
*oldest* 50,000 instead of the newest would quietly discard everything recent
while looking like it worked. Verified it catches exactly that — reversing the
direction turns it red (24/27, exit 1).

The spaces suite is mostly about **failure** paths, because that's where a
private-API feature actually lives: missing `hs.spaces`, full-screen windows,
a single desktop, an unrecognised current space, a failed move, and
`spacesForScreen` throwing. Verified it can fail — breaking the full-screen
filter turns it red (31/33, exit 1).

---

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
