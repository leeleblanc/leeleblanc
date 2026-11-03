# WORKLOG — what is being built, in order

LL, 2026-11-03: "Create a log to track these requests and work all until
completion in the best order for fixes or improvements."

This file is the queue. It is updated IN THE SAME COMMIT as the release that
moves a row, the way GUIDE.md's counts are — a stale worklog is worse than
none, because it is what gets read when deciding what to build next
(6.319.0: a list of what is left is a SAMPLE until somebody greps).

## 🚨 BEFORE ANYTHING: HE IS FOUR RELEASES BEHIND

His boot log, 2026-11-03 04:15:10:

    📌 init.lua ARCHITECTURE VERSION: 6.385.0
    🧭 Lees-MacBook-Air · 75 modules · 111 ⇪ shortcuts · 0.85s

The repo is at 6.389.0 (76 modules). So **6.386.0, 6.387.0, 6.388.0 and
6.389.0 are built, gated, committed and not installed.** The archive
`hammerspoon6.389.0.tar.gz` was delivered inline on 2026-11-02 and his Mac
has never run it.

WHAT THAT EXPLAINS, so neither of us chases it as a bug:
  · `_G.appOrphans()` → nil. It is 6.389.0 code.
  · `_G.appRemoveReport()` → "🗑 APP REMOVAL 6.385.0" — the version IS the
    diagnosis, and it is why that report has no `orphans:` line.
  · Hamsidian tabs last written 13 days ago — 6.387.0's auto-write is not
    running there.

THE ONE-LINE CHECK, and it is the first thing in every delivery from here:

    sed -n 7p ~/.hammerspoon/init.lua

NOT A BUG, measured: `_G.installCheck()` returning nil is correct on every
build ever shipped. It has never been written. It is row F3 below.

## 📋 THE QUEUE

Columns: the ask · where it lives · state. "his word" means he has already
said yes and it is not to be re-asked.

### A — BUGS (his own rule, 6.198.0: bugs before features while he tests)

| # | what | where | state |
|---|---|---|---|
| A1 | The Jug Player's catcher throws away its own `:show()` answer — 6.352.0's bug verbatim in the other player | `music_player.lua:1745-1746` | ☐ |
| A2 | Five bare webview shows — a refused window is recorded as open | `vault.lua:4663,5453` · `scratch_pad.lua:2399,2609` · `capture_pad.lua:1402` · `note_pad.lua:689` · `screenshot_editor.lua:1722,2315` | ☐ |
| A3 | The OCR tag resolves a file reference with realpath, not the bookmark round trip 6.237.0 proved | `ocr_engine.lua:514-525` | ☐ |
| A4 | `nameByText` has no killer timer — a hung `shortcuts` wedges the OCR queue for the session | `screenshots.lua:2801-2929` | ☐ |
| A5 | `screenshots.lua` has no `M.warm`, so `watchFolder = false` cannot stop the FSEvents wake-up | `screenshots.lua` | ☐ |

### B — THE TWO WINDOWS HE IS LOOKING AT (screenshots, 2026-11-03)

| # | what | state |
|---|---|---|
| B1 | "I can't drag that window" — the `editor.open` window (⇪⇧V's edit box) is not movable | ☐ |
| B2 | "Make the edit window like the edit window for clipboard entries" — ⇪⇧E's document-entry edit is still the tiny macOS dialog | ☐ |

### C — ANSWERS HE HAS JUST GIVEN (one line each, no design left)

| # | what | his word | state |
|---|---|---|---|
| C1 | App removal's risky-row label | "⚠️ Attention: your data may be in here ⚠️" | ☐ |
| C2 | Does a closed Hamsidian tab's `.md` go with it? | "How do I know?" — so I decide and say why | ☐ |

### D — FEATURES HE HAS SAID YES TO

| # | what | his word | state |
|---|---|---|---|
| D1 | ⌘Space launcher | "I already said yes" | ☐ |
| D2 | MANIFEST.txt + `_G.installCheck()` | ran it four times, got nil | ☐ |
| D3 | The draft keeper | "Already said yes" | ☐ |
| D4 | Size the Mug Player to the film | "Already said yes" | ☐ |
| D5 | ⇪7's macOS detail | "yes" | ☐ |
| D6 | Anchors' cold start — ⇪⇧U "create a new note first" | "Yes" | ☐ |
| D7 | The screenshot editor's sizing, then the crop tool | "Yes build it" | ☐ |
| D8 | The public sanitised config | "Build it and I'll review" | ☐ |
| D9 | System volume + output-device switching + a mute toggle | "Ignore hyper+q, not needed" — read as: ⇪Q stays, build the trio | ☐ |
| D10 | ⌥Tab lists every panel | his answer, 6.374.0 batch | ☐ |

### E — THE "FIX:" LIST, verbatim

| # | what | state |
|---|---|---|
| E1 | The Chrome tab scan (diagnosed — check Automation permission before any code) | ☐ |
| E2 | Writing into any .csv / .txt (not scoped — needs a shape decision) | ☐ |
| E3 | The ⌘1–9 screenshot panel reflowed like ⇪space | ☐ |
| E4 | A snippets window in that style | ☐ |
| E5 | Sequential screenshots to the clipboard | ☐ |
| E6 | Widening `uni.runnable` | ☐ |
| E7 | Vault front-matter completion | ☐ |
| E8 | ⌘⇧N / ⌘⇧E onto the `editor.open` window (exists since 6.213.5) | ☐ |
| E9 | The ⇪⇧O image-history beach ball | ☐ |
| E10 | Canvas — JSON Canvas (read/arrange first, authoring later) | ☐ |
| E11 | Bookmarks CSV searched from ⇪D | ☐ |
| E12 | The dictionary synced to GitHub | ☐ |
| E13 | The Claude door | ☐ |
| E14 | The website (Jekyll on GitHub Pages, personal only) | ☐ |
| E15 | One combined log of every URL through a window | ☐ |
| E16 | The doubled-word pink underline — blocked on a per-app AXBoundsForRange reading only he can take | ☐ blocked |

### F — OWED, FROM EARLIER BLOCKS

| # | what | state |
|---|---|---|
| F1 | `tests/test_lint.lua` — hs-lint has no suite and every rule in it is a bug that cost a release | ☐ |
| F2 | The 73-second lockup: time every lazy extension load in `M.warm` (his 04:15 boot shows six of them AFTER the summary, and `762 ms — this Mac usually takes 220`) | ☐ |
| F3 | (see D2 — MANIFEST/installCheck) | — |

## ✅ DONE

(nothing yet in this run — rows move here with the release that closed them)
