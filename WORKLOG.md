# WORKLOG — what is being built, in order

LL, 2026-11-03: "Create a log to track these requests and work all until
completion in the best order for fixes or improvements."

This file is the queue. It is updated IN THE SAME COMMIT as the release that
moves a row, the way GUIDE.md's counts are — a stale worklog is worse than
none, because it is what gets read when deciding what to build next
(6.319.0: a list of what is left is a SAMPLE until somebody greps).

## ✅ HE IS CURRENT, AND THE INSTALL CHECK PROVED IT

His boot log and his own `_G.installCheck()`, 2026-11-04 04:58–05:00:

    📌 init.lua ARCHITECTURE VERSION: 6.399.0
    🧭 Lees-MacBook-Air · 77 modules · 111 ⇪ shortcuts · 0.57s
    🩺 INSTALL CHECK — 6.399.0
       version : 6.399.0 — the manifest is for this release
       files   : ✅ all 92 runtime file(s) are here at the size the release carried
       strays  : none — core/ and modules/ hold only what shipped

So the ten-release archive ARRIVED, INSTALLED and LOADED — all four links
of 6.263.0's chain paid at once — and 6.399.0's own instrument says the
whole release landed rather than a boot line implying it. That is the
first time this project has been able to answer "did it ALL land?" with
a measurement, and it answered on the first run.

THE ONE-LINE CHECK stays the first thing in every delivery from here:

    _G.installCheck()

## 📋 THE QUEUE

Columns: the ask · where it lives · state. "his word" means he has already
said yes and it is not to be re-asked.

### A — BUGS (his own rule, 6.198.0: bugs before features while he tests)

| # | what | where | state |
|---|---|---|---|
| A1 | The Jug Player's catcher throws away its own `:show()` answer | `music_player.lua:1745-1746` | ✅ **6.390.0** |
| A2 | Bare webview shows — a refused window recorded as open. **The list was a sample: the grep found ELEVEN, not five** | one door in init.lua + 11 sites + a gate sentry | ✅ **6.391.0** |
| A3 | The OCR tag resolved a file reference with realpath | `ocr_engine.lua` | ✅ **6.392.0** |
| A4 | `nameByText` had no killer timer — a hung `shortcuts` wedged the queue for the session. Also `t:start()`'s answer was discarded | `screenshots.lua` | ✅ **6.393.0** |
| A5 | `screenshots.lua` had no `M.warm`, so `watchFolder = false` could not stop the pathwatcher | `screenshots.lua` | ✅ **6.394.0** |

### B — THE TWO WINDOWS HE IS LOOKING AT (screenshots, 2026-11-03)

| # | what | state |
|---|---|---|
| B1 | "I can't drag that window" — the drag was fully built and its first tick ended it: it asked `checkMouseButtons` as an ORACLE, which `core/coexist.lua:824` forbids in writing | ✅ **6.395.0** |
| B2 | ⇪⇧E's document-entry edit moved onto `editor.open`. It was the LAST picker in the config still on `hs.dialog.textPrompt` | ✅ **6.397.0** |

### C — ANSWERS HE HAS JUST GIVEN (one line each, no design left)

| # | what | his word | state |
|---|---|---|---|
| C1 | App removal's risky-row label | "⚠️ Attention: your data may be in here ⚠️" | ✅ **6.396.0** |
| C2 | Does a closed tab's `.md` go with it? | **Decided: it STAYS.** ⌘W tidies the desk; it does not throw the paper away. The defect was that the policy was SILENT — it now says so, names the file, and counts it | ✅ **6.398.0** |

### D — FEATURES HE HAS SAID YES TO

| # | what | his word | state |
|---|---|---|---|
| D1 | ⌘Space launcher | "I already said yes" | ☐ |
| D2 | MANIFEST.txt + `_G.installCheck()` | ran it four times, got nil | ✅ **6.399.0** — and it came back green on his Mac |
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

### G — HIS 2026-11-04 REPORT, all ten items

| # | his words | what it is | state |
|---|---|---|---|
| G1 | "First result from history clipboard list is not pasted when selected and it should be." | REAL. ⏎ in ⇪V has always COPIED, and row one IS the clipboard — so ⏎ there changed nothing observable. The first row was the diagnosis | ✅ **6.402.0** |
| G2 | "⌘+hyper does not actuate a picker for every single Hammerspoon tool I've created and it should." | **A DOOR, not an instrument (6.317.0, sixth time).** `@tool` in ⇪D already lists every tool and shortcut this config has, and **⇪⇧/ opens the panel pinned to it**. So the picker exists; the key he reached for does not open it. NEEDS ONE WORD FROM HIM: which key — and ⌘⇪ as a chord has to be checked against the registry first | ❓ asked |
| G3 | "Closing Hamsidian tab works." | 6.398.0 confirmed | ✅ **WIN, scored** |
| G4 | "Document edit works but window does not return cursour/ mouse to the active field… I just use my trackpad to get back here. That doesn't right as the cheat sheet doesn't do this." | REAL, and his comparison explains it: ⇪/ never takes focus. Older than 6.397.0 — the window has always activated Hammerspoon and never given it back | ✅ **6.401.0** |
| G5 | "Not sure if this happens: 🔌 watchFolder = false really stops the watcher" | **HE CANNOT SEE IT, and that is my fault for listing it as if he could.** It is invisible unless he sets the setting. The evidence is the `watch :` line in `_G.screenshotsReport()`, which has three states | ❓ answered in words |
| G6 | "Not sure if happens: ⏱ One hung OCR no longer wedges the naming queue" | Same: invisible on a healthy Mac. It only shows when a `shortcuts` run hangs, and then the queue keeps draining instead of stopping for the session | ❓ answered in words |
| G7 | "How to test? 🆔 A file reference is resolved by a bookmark" | There IS a recipe: ⌘C an image FILE in Finder (the file, not the pixels) and press the OCR tag key. Before 6.392.0 that path produced a plausible-looking path that could not be opened | ❓ answered in words |
| G8 | "Uncertain: 🪟 One door for every webview show" | Invisible on a healthy Mac by design. `_G.webviewShowReport()` is the evidence; on a good day it reads "refused : none" | ❓ answered in words |
| G9 | "🪟 The Jug Player's catcher reads its own show is for music. Mugplayer is for movies." | **He is right and nothing is wrong.** 6.390.0 IS the Jug Player (music); the Mug Player's own catcher was fixed in 6.352.0. Two tools, two releases, named correctly | ❓ confirmed |
| G10 | "please create a divider above this line so I can see where one section ends and this begins. It's not easy to find when I need to copy paste." | REAL, and cheap. Written from BOTH sides of a boot, because Hammerspoon's own first two lines are printed before any Lua of ours exists | ✅ **6.400.0** |

🔑 WHAT G5–G9 HAVE IN COMMON, and it is a method defect of mine rather
than five questions of his: I listed ten releases in a delivery message
as if each were something he could go and check. Five of them are
INVISIBLE ON A HEALTHY MAC by design — that silence is the feature
(6.269.0) — so "not sure if this happens" is the only honest thing he
could say. GENERAL, past this project: when a release's whole claim is
that something no longer goes wrong, the delivery message says HOW HE
WOULD KNOW, or it does not mention it at all. A list of fixes he cannot
verify reads as a list of promises.

## 📦 DELIVERY — 2026-11-03

**6.389.0 sent inline**, on his word ("I didn't receive build 389, send it
now"). Verified three ways before it left:

| | |
|---|---|
| integrity | `tar -tzf` reads clean |
| entries | 210 |
| bytes | 3,577,991 (3.41 MB) |
| version, grepped from the unpacked init.lua | line 7 `6.389.0`, `_G.configVersion = "6.389.0"` |
| not stale | 6.389.0's `appOrphans` present · 6.391.0's `showWebviewSafely` absent |
| gate, run from INSIDE the unpacked package | 13,708 checks · 89 stages green · GUIDE.md agrees · init.lua 3,366 lines |

🚨 AND IT DOES NOT CLAIM TO FIX HIS LOCKUP. He sent "Hammerspoon just
locked up" in the same breath as asking for it, and nothing in
6.386.0–6.389.0 touches that. Said to him plainly rather than letting the
delivery imply a fix (6.198.0).

🔑 THE INSTRUMENT IS ALREADY ON HIS MAC. 6.330.0's breadcrumb rides in the
stall guard's heartbeat (`<epoch>\t<what>\t<who>\t<since>`) and 6.385.0
carries it, so the lockup that just happened has already written its own
evidence. Asked for `_G.stallGuardReport()` and the log. `in flight:
nothing was marked` rules out all 109 ⇪ shortcuts in one line and leaves
the ONE named, unmeasured candidate: Hammerspoon's lazy extension loads
on the main thread — 42 s after a 0.24 s boot on 2026-10-04, `mouse` 18 s
after a 0.21 s boot on 2026-10-12. That is F2 below, and his report
decides whether it is built next.

**D2 was interrupted mid-file** and is committed as WIP at `8b248c7` —
module, generator and MANIFEST.txt in, suite and ceremony owed. The
commit message carries the three decisions that overturn the earlier plan
(no hash path · CHANGELOG.md out · bundled.lua out) with their reasons.

## ✅ DONE IN THIS RUN — nine releases

| release | what | commit |
|---|---|---|
| 6.390.0 | The Jug Player's catcher reads its own show | `0bf338e` |
| 6.391.0 | One door for every webview show (11 sites + sentry) | `0bf338e` |
| — | the sweep's three findings | `9a0e451` |
| 6.395.0 | The edit window drags | `641b3e4` |
| 6.396.0 | "⚠️ Attention: your data may be in here ⚠️" | `641b3e4` |
| 6.397.0 | The document edit takes the real window | `641b3e4` |
| 6.398.0 | Closing a tab leaves its note, and says so | `641b3e4` |
| 6.392.0 | A file reference is resolved by a bookmark | `cb05403` |
| 6.393.0 | A hung OCR no longer wedges the naming queue | `cb05403` |
| 6.394.0 | `watchFolder = false` really stops the watcher | `cb05403` |

Gate: **13,817 checks**, every stage green. init.lua 3,449 lines, 350 of
room. Ceremony (version stamps, CHANGELOG, GUIDE totals, feature list,
TESTING.md) is written once for the whole batch at the end.
