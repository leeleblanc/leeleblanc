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
lua5.4 tests/quick_notes_test.lua
```

135 checks, no Hammerspoon and no network required — the suite reads the `X.2`
block straight out of `init.lua`, so it always tests the shipped code rather
than a copy that has drifted. Exit status is 0 only if everything passes.

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
