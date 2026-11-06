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
| D3 | The draft keeper | ❗❗ "Escalate and build" | ✅ **6.404.0** — shipped alone, at once, as he ordered |
| D4 | Size the Mug Player to the film | "Already said yes" | ☐ |
| D5 | ⇪7's macOS detail | "yes" | ☐ |
| D6 | Anchors' cold start, and the white box | "Escalate and build" | ✅ **6.405.0** (the surface + the service) and **6.406.0** (the blank window) |
| D7 | The screenshot editor's sizing, then the crop tool | "Escalate and build" | ✅ **6.407.0** the SIZING · **6.414.0** the CROP TOOL |
| D8 | The public sanitised config | "Build it and I'll review" | ☐ |
| ~~D9~~ | ~~System volume + output-device switching + a mute toggle~~ | **DROPPED ON HIS WORD, 2026-11-04: "I already said drop this. I am not developing this."** My row was wrong — see J5 | ✅ struck |
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
| F2 | The 73-second lockup: time every lazy extension load in `M.warm` (his 04:15 boot shows six of them AFTER the summary, and `762 ms — this Mac usually takes 220`) ☐ · **and H3 is the same class with bigger numbers** — ⇪space and ⇪⇧. at ~1.6 s each, main-thread, which also feeds the storm rule's five-second clock. Time them together. |
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

---

## H — HIS 2026-11-04 CONSOLE (6.399.0 then 6.389.0 then 6.399.0)

He pasted a full Console with a `/compact`. It is not a request; it is
**evidence**, and four things in it are not in the message that went with
the 6.402.0 archive.

### H1 ✅ THE INSTALL CHECK ANSWERED — and it is the first measured one

```
🩺 INSTALL CHECK — 6.399.0
   version : 6.399.0 — the manifest is for this release
   files   : ✅ all 92 runtime file(s) are here at the size the release carried
   strays  : none — core/ and modules/ hold only what shipped
   last    : 05:00:59 · run 2 time(s) this session
```
Green on the first run. NOT SCORED — he pasted output, not a verdict.
📏 AND THE TWO FAILURES BEFORE IT ARE THE RELEASE WORKING, not a bug: at
04:52 and earlier he ran `_G.installCheck()` on **6.389.0 and 6.385.0**
and got `attempt to call a nil value`. An error is the only honest answer
a build without the module can give (6.261.0's rule).

### H2 🚨 ⇪ LATCHED TWICE IN FORTY-FIVE SECONDS, AND THE CONFIG PAUSED

```
05:14:39  🌩 ⇪ STORM CAUGHT — Caps Lock was stuck 7 s and 7 different keys ran ⇪ shortcuts
05:15:24  🌩 ⇪ STORM CAUGHT — Caps Lock was stuck 14 s and 6 different keys ran ⇪ shortcuts
          — 2 storms in 10 min: PAUSED, ⇪⇧escape resumes
```
**His config may still be paused.** Nothing after 05:16:07 says he
resumed. That is the first sentence of the reply, ahead of everything.

🔎 **IT IS A GENUINE LATCH, BOTH TIMES**, and the arithmetic is his:
`88 Caps Lock autorepeat(s)` that session proves the key autorepeats on
that Mac, and the rule requires none within 2 s of the storm — so Caps
Lock was **not under his finger** at either moment. Every key he pressed
was running a ⇪ shortcut instead of typing, for 7 s and then 14.4 s. The
guard caught it, released it and wrote both files. 6.214.1 paying for
itself, in the field, for the third and fourth time.

🚨 **AND THE NEAR-MISS IS THE THING TO REMEMBER.** The storm file carries
`asked : unified search` — a panel had declared a handover inside the
hold — and `st.judge` has four conditions, none of them that fact, while
`_G.hyperEndVerdict` in the file next door already answers exactly that
question and 6.302.0's wake release already refuses to count itself a
latch for that very reason. Every signpost in this repo said *6.305.0: a
rule written about one caller*, and the fix it suggests is to stop
calling such a hold a storm.
**The key trail's own timestamps refuse it.** Storm #2's hold began
14.4 s before 05:15:24 = 05:15:10; the trail's first key in that window
is ⇪⇧, at 05:15:11; and ⇪O — which has opened unified search since
6.190.0 — is the **fifth of the six**. The panel opened as a
**consequence** of the latch. And in 6.214.0's original storm every
letter ran its own shortcut, several of which open panels, so that line
would be set in a genuine latch too. **Exonerating that hold would have
disarmed the guard for the one case it exists for** — 6.337.0's lesson,
almost paid a second time.
🔑 What stopped it was reconstructing the timeline from the artefact
rather than reasoning from the line that looked like an answer. That is
now a hard rule (🔬 in CLAUDE.md).

✅ **BUILT AS 6.403.0** — the storm now asks which of the three things
latched ⇪ and appends the answer to its own file. An instrument, not a
fix, and labelled as one everywhere.

### H3 📏 THREE SHORTCUTS ARE TAKING A SECOND AND A HALF — named, not fixed

From his own key trail:
```
⇪space   app launcher   1571 ms  ⚠️ slow     (twice)
⇪shift+. jug player     1620 ms  ⚠️ slow     (1669 ms the other time)
⇪d       unified search  298 ms  ⚠️ slow
```
That is 1.5 seconds of **main-thread** time per press — 6.228.0's cost,
which is what took his drag and drop — and it is also what makes a run of
six shortcuts last the five seconds the storm rule measures. Six keys at
1.5 s each is nine seconds of hold with no effort at all.
🚨 NOT FIXED AND NOT GUESSED: "⇪space is slow" names a KEY, not a cause.
The candidates are the **121,453-path search index** (`🗂 Search Index:
rebuilt — 121453 paths` at 04:52:44, moments before), the app list, and
the window show. Each is a different release. The verify block asks him
the one question that narrows it: does ⇪space *feel* slow when he presses
it, or only in the number?

### H4 ❔ SECURE INPUT STILL WILL NOT ANSWER — the one unmeasured candidate

```
❔ Secure Input   UNKNOWN   ioreg was asked and never answered in 20s
```
6.304.0's belt is working (it gives up rather than wedging the feature
for the session) and the probe is **still not answering on his Mac**.
That is the one of 6.303.0's three candidates that has never once been
measured there, it is the one that kills every tap AND every hotkey
system-wide with no error anywhere, and it is now the likeliest
explanation for H2. 6.403.0 puts the question where the fault is; if the
answer keeps coming back unreadable, **the next release is the ioreg
probe itself**, not another consumer of it.

### H5 ✅ TWO WARNINGS IN IT ARE ALREADY FIXED IN WHAT HE NOW HAS

- `⚠️ OCR tag: clipboard file URL(s) matched no usable image — a
  file-reference path macOS would not resolve — raw value:
  "/.file/id=6571367.39717200/"` at 04:55:46 — on **6.389.0**. That is
  exactly 6.392.0's bug and 6.392.0 is in the archive he has.
- `⚠️ an alert could not draw` at 23:24:51 — 6.274.0's counted refusal,
  working as designed.
- `⚠️ focus: detection budget exhausted` (2026-11-03 16:46, open for an
  hour): focus_mode's own budget. Not ours to chase without a report.

### H6 📋 AND HIS 6.399.0 BOOT CARRIES A FACT WORTH KEEPING

```
🎹 ⇪ IS RUNNING WITHOUT CARBON on this Mac — and it works.
   The event-tap dispatcher has taken over all 111 ⇪ shortcuts.
```
On this Mac Carbon does **not** dispatch F18; the tap does everything. So
the keyUp depends entirely on the tap seeing it — which makes "the F18
event tap was NOT running" a far more plausible storm cause here than on
a Mac where Carbon is carrying the keys. 6.403.0's `tap :` row is the one
that answers it.

## I — HIS 2026-11-04 ANSWERS AND THE 11:13 CONSOLE (6.403.0)

### I1 🚨 THE OCR FILE-REFERENCE WARNING IS LIVE ON 6.403.0 — AND I TOLD
###    HIM IT WAS FIXED

```
2026-11-04 11:14:51  (boot 11:13:10, version 6.403.0)
⚠️ OCR tag: clipboard file URL(s) matched no usable image — a
   file-reference path macOS would not resolve — raw value:
   "/.file/id=6571367.39722786"
```
H5 filed this as "already fixed in what he has — that is 6.392.0's bug".
**That was wrong.** 6.392.0 is installed and this is a 6.403.0 boot. The
warning is honest and the feature is still failing.
🔎 WHAT THE MESSAGE'S OWN SHAPE SAYS, read rather than guessed: the line
carries NO "(the filesystem calls it a …)" clause, which that branch adds
whenever `hs.fs.attributes(ref, "mode")` answers. So the filesystem would
not stat the reference AT ALL — all three resolvers (bookmark, realpath,
pathFromURL) correctly refused, and the folder exemption could not fire.
🔑 AND THE FIX IS A RULE THIS REPO ALREADY OWNS, UNPORTED. 6.237.0 settled
this in the music player and wrote down BOTH halves: **the plain-path
flavour is asked FIRST** (`NSFilenamesPboardType` is a plist array of real
POSIX paths, "so where macOS still offers it none of this arises"), and
**the pasteboard's FLAVOURS ride into the report** ("a second 'it did not
work' is not an artefact"). Measured: `NSFilenames` appears in
music_player.lua and **zero times** in ocr_engine.lua, and
`pasteboardTypes` likewise. 6.392.0 ported the RESOLVER and never the
READER ORDER.
🔑 GENERAL, and it is 6.231.0 · 6.305.0 · 6.319.0 for the fourth time in
this pair: when two modules read the same platform surface and one of them
learns a lesson, the port is the WHOLE lesson — the order it asks in and
what it records, not only the function that does the arithmetic. A rule
ported halfway reads as a closed class.
📏 BOUNDED, not a loop: the caller is init.lua's clipboard CHANGE handler
(`_G.clipboardPollStats` is in the same block), so one unresolvable copy
warns once. Not 6.281.0's shape.
🗳 NEW GROUND for this surface — whether Finder still offers the plain
flavour on his macOS is a platform fact this container cannot read, so the
release ships the reader AND the flavour list, and the next occurrence
names its own cause.

### I2 📏 FOUR EXTENSIONS ARE STILL PAID ON A KEYPRESS — F2, with names

His 11:13 boot, measured off the Console's own timestamps:
```
11:13:11  🧭 boot complete — 0.64s
11:13:12  sound · menubar                    ← warm, ~2 s after boot
11:13:13  webview · drawing · base64 · canvas · pathwatcher   ← warm
11:13:58  axuielement · mouse               ← 48 s AFTER boot
11:16:22  image · geometry                   ← 3 m 12 s AFTER boot
```
The 11:13:12–13 group is 6.348.0's warm touch working — `vid.warmed`
deliberately pays webview, drawing and base64. The two LATE groups are
paid by whatever keypress first touched them, on the main thread.
🔑 So F2 is no longer "time the lazy loads"; it is four named extensions
and 6.348.0's move applied to them. Likely first-touchers: `mouse` and
`geometry` → mouse_grid / mouse_follows / window_move (⇪X, ⇪⇧L);
`axuielement` → doc_memory / anchors / focus_mode / the selection read;
`image` → any picker drawing app icons, which is ⇪space.
📏 AND IT IS NOT THE WHOLE OF ⇪space. His trail has ⇪space at 1567 ms AND
1571 ms in one session, so the second press paid no dylib load. A dylib
load explains the FIRST press of a key, never every press.

### I3 ✅ ⇪space IS PERCEPTIBLY SLOW — CONFIRMED, AND PARKED ON HIS WORD

LL: "hyper+space did feel slow, and it seems ok, seems that is, ok for
now." So the symptom is real and FELT, not only a number — which rules out
"the clock is lying" and leaves the three candidates standing. He has
deprioritised it; it is not built next.
📏 THE MEASUREMENT STILL MATTERS, because it is arithmetic in the storm:
six shortcuts at ~1.5 s is nine seconds of hold on their own, and the
storm rule needs five. Slowness did not CAUSE the latch (no keyUp arrived
— that is the latch) but it does make both storm conditions cheaper to
reach. Keep that beside any future storm file.

### I4 📋 `__G.stormReport()` — HIS TYPO, AND MEASURED AS NOT OURS

```
> __G.stormReport()
[string "..."]:1: attempt to index a nil value (global '__G')
```
Grepped: `__G.` appears **nowhere** in any shipped file, so no message of
ours prints a doubled underscore. The boot line was correct
(`_G.stormReport() prints it`).
✅ AND THE BELT IS WHAT SAVED IT: that same boot line names the FILE and
says "(send that file)", and he sent the file. A command that fails and an
artefact that arrives anyway is the design working.
🗳 WORTH ASKING, NOT BUILDING: a command he must retype is a command that
can be mistyped, and a Lua traceback is a refusal he cannot act on
(6.320.0). Putting the command on the CLIPBOARD when the storm boot line
prints would make it a paste. One line, his call.

### I5 📂 Saved_URLs.txt IS AN ORPHAN — 116 days quiet, written by nothing

`_G.stores()` names it as the quietest file in the Logs folder. Grepped:
nothing in this config writes or reads `Saved_URLs`. So it is either a
leftover from a deleted tool or a file he keeps by hand.
🚨 IT IS NOT DELETED AND WILL NOT BE: 6.280.0 — nothing here erases
something of his without him asking. Reported, and the question is his.

### I6 🖱 VLC REFUSED AN ACCESSIBILITY WATCHER — working as designed

`🖱 Mouse Follows Focus: VLC didn't accept an Accessibility watcher (said
once per app per session)`. A degrade, named once per app, exactly as
6.215.0's door requires. No action.

### I7 🗳 THE FOCUS-DOOR QUESTION IS UNANSWERABLE BY HIM — SO I DECIDE

LL: "I don't remember what picker or window did this. But it did happen."
Asking again would be asking him to remember something he has told me he
does not (6.364.0's lesson about ⌥↓/⌥⌫, and 6.312.0's about E1).
🔑 SO IT IS CHOSEN FROM HIS OWN KEY TRAIL rather than from taste:
`⇪n scratch pad` appears THREE times in 24 presses, more than any other
panel, and Hamsidian is the one panel in this config he TYPES PARAGRAPHS
in — which is where losing the caret costs most. **Hamsidian takes the
focus door next**, and the remaining four (the task form, the screenshot
editor, both players) follow one per release.

### I8 ✅ G2 IS CLOSED ON HIS WORD

LL: "Nevermind, I forgot about the @tools. We're good." So `@tool` in ⇪D
plus ⇪⇧/ is the picker, no key is owed, and the row is struck. 6.317.0's
shape confirmed for the sixth time — the instrument existed and the DOOR
was what he could not find.

---

## J — HIS 2026-11-04 ANSWERS AND ORDERS

He read the list and gave orders rather than preferences. Logged here so
none of it is re-asked, and so the two I got wrong are visible.

### J1 ❗❗ D3 IS THE RELEASE, ALONE, AT ONCE

His words: "❗❗ Escalate and build ❗❗ and give me this in an immediate
release when it is ready. Do not wait to give me the rest. This is one
that will be its own release ASAP. Then after that delivery, do not
wait. Go immediately into the rest below."

**Shipped as 6.404.0**, alone. 172 checks, gate 91 stages / 14,309.
The design decision that is MINE and is named in the release: it reads
the FIELD'S VALUE on a timer rather than watching keystrokes, because a
keystroke tap never sees a paste and holds a transcript rather than the
paragraph. And it is the narrower instrument — one element in seven
named apps instead of every key pressed on the Mac.

The second decision that is mine, because he escalated without answering
the open question: **60 characters, settled 10 seconds**. Keeping every
field would make the file a log of every search box he has typed in, and
6.267.0 forbids leaving that answer in a settings line. Both numbers are
in the report and the verify block asks him to move them.

### J2 D6 AND D7 ESCALATED — AND D6 HAS A NEW BUG ON IT

"D6: Escalate and build. D7: Escalate and build." Both are next, in that
order, after this delivery.

🚨 AND HE REPORTED A NEW FAULT ON D6's PATH, which changes what D6 is:

> "D6 or Hamsidian caused an overlay to stay on the screen. I had a white
> box that was Hamsidian. I ⇪⇧U in first, then got Hamsidian. Then was
> left with that box. I don't know if it's saying 'create a note first'
> over a full vault. Is this so obvious I'm missing it."

READ, NOT PROVEN, and it is NOT the cold-start message — which is what
makes his question the right one to ask. Two separate things in one
sentence:
1. **A WHITE BOX LEFT ON SCREEN.** ⇪⇧U opens a picker; picking the
   "📁 Link it into an existing note…" row opens HAMSIDIAN. So a panel
   was reached THROUGH another panel of ours — which is the exact shape
   6.401.0's focus door was built around, and the shape 6.266.0's
   frozen-grid orphan lives in: a window shown on a caller's behalf that
   the caller has since stopped tracking. A white box means the webview
   is on screen with NO page drawn in it, which is different from both
   of those and is its own finding.
2. **"create a note first" over a full vault** is D6 (6.340.0's shape in
   ⇪⇧U — the notes index is built when Hamsidian OPENS, so before the
   first open anchors has no rows to offer). He is NOT sure he saw it.

So D6 grows a second half, and the artefact decides which: the next time
it happens I need `_G.vaultReport()` and `_G.anchorsReport()` TOGETHER,
with the box still on screen. Asked in the 6.404.0 message.
📏 And the answer to "is this so obvious I'm missing it" is NO — a
webview that is up and blank is not a message he failed to read.

✅ **BOTH HALVES SHIPPED, AND THE ARTEFACT WAS NOT NEEDED — BOTH WERE
READABLE.** The second half took ten minutes of reading rather than a
round trip, which is the half worth writing down:
  · **6.405.0, the cold start.** `pickNote` asked `vault.names`, got an
    empty table, and said "No notes to pick yet". The index is built
    when Hamsidian OPENS (6.267.0, on purpose), so before the first ⇪3
    of a session it is empty — and 6.340.0 had already taught the PAGE
    to tell "not yet" from "nothing" and swept no other reader. The fix
    is in the SERVICE: `v.indexState` is PURE, four answers (scanning ·
    unread · read · failed), and `vault.names` returns it as an
    additive second and third value (6.299.0), so no caller can read an
    empty answer as an answer. `pickNote` waits through ONE held slot,
    bounded, with the bound as a sentence (6.197.2), asking for the read
    once rather than once per turn (6.304.0).
  · **6.406.0, the white box.** `v.render()` was
    `pcall(function() v.webview:html(v.buildHtml()) end)` — so when
    buildHtml RAISES, which 6.335.0 proved it can in that very file, the
    pcall swallowed it, `html()` was never called, render() returned
    looking like a success, and open() SHOWED a webview that had never
    been given a document. An hs.webview with no document draws BLANK,
    with nothing in the Console. 6.391.0's rule about a webview refusing
    in two directions, applied to `html()` rather than `show()` — and
    the costlier of the two: a refused show draws nothing, a refused
    DRAW draws a window.
    🚨 And 6.326.0 was unpaid here, which explains "left with that
    box": the handle was assigned ABOVE the show, and this module's own
    toggle reads `if v.webview then v.hide() return end` — so a refusal
    left the next ⇪3 hiding a window there was nothing to hide. The
    order is the fix: write the page, THEN show the window, and tear
    down anything that refuses.
  🔎 And the page's own handshake had never been recorded. A HELD belt
    names "the window is up and its page never ran" and does NOT close
    it — a slow Mac is a slow Mac (6.198.0).

### J3 THE 16 "Fix:" ROWS ARE APPROVED

"16 'Fix:' rows, yes go ahead." E1–E16 are cleared to build, in the
order they are listed in section E. E16 stays blocked on a per-app
AXBoundsForRange reading only he can take (6.221.0).

### J4 F1 IS A FAIR COMPLAINT ABOUT MY WORDS

"F1: fix this as I don't understand what you're saying -too cryptic."

He is right and the defect is in the ASKING, not the item — ⌨️'s rule
(6.377.0): when somebody says they do not understand an instruction, the
instruction is wrong, never the reader. What F1 said was "`tests/
test_lint.lua` — hs-lint has no suite and every rule in it is a bug that
cost a release", which is three pieces of private shorthand in one line.

**F1, in plain words, as it now reads:** before every test run, this
config checks its own source for about thirty mistakes it has made
before — things like "this function throws away a value it needs" or
"this sentry can never fire". Each of those checks exists because that
exact mistake once broke a release. **Nothing checks that those checks
still work.** One of them went silently dead for a whole class of file
and nobody noticed. F1 is a test for the tests: one deliberately broken
example per rule, so a rule that stops catching anything fails the gate
instead of going quiet.

### J5 D9 WAS LOGGED WRONG, AND IT IS MINE

"D9: I already said drop this. I am not developing this. Please log it
correctly."

He is right. He said "Disregard hyper+Q. It's fine." on 2026-10-31, and
2026-10-29's "Ignore hyper+q, not needed" before that — and I read both
as being about ⇪Q's microphone mute while keeping the VOLUME trio on the
list as something he still wanted. That was my inference, not his words,
and the row has been carrying it since. **Struck in the table above.**

🔑 THE RULE THIS BREAKS, and it is one this file already carries twice:
6.360.0 says a past "no" narrows the search and never ends it — and the
mirror of that is the one I got wrong here. **A DECLINE THAT I SPLIT
INTO "THE PART HE MEANT" AND "THE PART HE DID NOT" IS AN INFERENCE
WEARING HIS WORDS.** When he declines something, log the decline against
the thing he named and nothing adjacent to it; if the scope is unclear,
the question is "did you mean the whole of it?" — asked once — not a
surviving row he has to decline a third time.

### J6 HIS FOUR ANSWERS

**Q1 — what was he copying when the OCR tag warned?** "No idea. Maybe a
powerpoint file. Maybe the Hammerspoon files. I'm working on other
things while you work."
→ So the artefact-first route is closed on this one and it is NOT
re-asked. What that answer does rule out is the OneDrive-placeholder
hypothesis as anything more than a guess: a PowerPoint and a .lua file
have nothing in common but being FILES. So the fix is the one the
reading already named — ask the plain-path pasteboard flavour FIRST, and
make the warning name every flavour it saw, so the NEXT one carries its
own evidence and needs nothing from his memory.

**Q2 — is `Saved_URLs.txt` yours?** "Yes."
→ It stays. `_G.stores()` goes on naming it, and the "quietest file"
line is correct rather than a leftover. Nothing to build; the row is
struck.

**Q3 — should the storm line put `_G.stormReport()` on the clipboard?**
"Yes. And Tell me it was. Other reports for other issues should tell me
that same, copied and 'hey you have a report to give to Claude.' Those
should be searchable by @reports"
→ THIS IS BIGGER THAN THE QUESTION I ASKED and is its own release. Three
parts, and the third is the one that makes it a feature rather than a
convenience:
  1. a report that matters is COPIED to the clipboard automatically;
  2. it SAYS so — "copied · hey you have a report to give to Claude";
  3. **`@reports` in ⇪D** — every report this config has generated,
     searchable, so one he did not paste at the time is not lost.
📏 (3) means reports have to be WRITTEN somewhere, which they are not
today — they are printed. So this is a store, a source and a door, and
it goes in the queue right behind D6 and D7 rather than being smuggled
into the storm line.

**Q4 — Hamsidian for the focus door?** "Wait until this is displayed in
the Console or I can tell you or you can tell me how."
→ So my own pick is NOT taken, and the right answer is to make the panel
NAME ITSELF. 6.401.0's door already knows which panel borrowed the
keyboard; what it does not do is say so when one gives it back WITHOUT
returning the focus. One line in `_G.focusReport()` and one Console line
at the moment it happens turns "which panel?" into something he reads
rather than remembers. That is the release, and it comes before picking
a panel — which is the whole point of his answer.

### J7 D7's FIRST HALF SHIPPED; THE CROP TOOL IS STILL OWED

**6.407.0** is the sizing. His two sentences were one function and one of
them was ALREADY BUILT, which is said rather than rebuilt (6.317.0):
"not shrink down so much that the tools are not usable" is 6.270.0's
floor, untouched. What was missing is the other end — the window was
capped at 85% of the screen, and 80% of his LG at full points is a
window over three thousand points wide, so his own number alone was not
an answer. TWO ceilings now and the smaller wins: `maxFrac` (0.80, his
number) and an absolute `maxW × maxH` (1600 × 1100, MINE and named as
mine in the verify block, because there is no measurement for "big
enough to work in, small enough to see at once").
🚨 AND THE FLOOR-VERSUS-CEILING CASE HAD NEVER BEEN DECIDED: on a short
screen the rails need more height than the display has. The SCREEN wins
and the rails SCROLL, which 6.270.0 already built — a window taller
than the display is buttons he cannot click.
📏 STILL OWED: **the crop tool.** New drawing, a new saved rectangle,
and its own release.

---

## K. HIS 2026-11-06 REPORT — "PLEASE DO A SOLID PASS OF DEBUGGING"

Six items, one escalation, three screenshots and a Console. Everything
in it is now built; what each turned out to be is below, because three
of the six were not what the sentence said.

| # | His words | What it was | Shipped |
|---|---|---|---|
| 0 | ESCALATE: "Draft keeper doesn't seem to be working. How do I know?" | Chromium does not publish its page until asked — six of seven watched apps are Chromium | ✅ **6.411.0** + `_G.draftCheck()` |
| 1 | "Right-click actuates where the mouse is but not on the current highlighted file" | A decision in the module's own header, expired | ✅ **6.409.0** |
| 2 | "Menu search is not filtering … somewhat filters when typing a question mark" | A queryChangedCallback replaces the chooser's own filter; dead since 6.196.0 | ✅ **6.408.0** |
| 3 | "Can it do a set of checks for most important functions?" | Never built | ✅ **6.413.0** `_G.selfTest()` |
| 4 | "11-27-26 should be 11-27-2026 on hyper+shift+0" | A default — and the expansion half already worked while its counter lied | ✅ **6.412.0** |
| — | His Console: two Jug Player refusals at 06:17:19 | 6.348.0's finding in the other player, named-not-swept | ✅ **6.410.0** |

### K1. 🩺 THE ESCALATION, AND WHY IT COULD NEVER HAVE WORKED
`AXFocusedUIElement` on a Chromium app answers about the window chrome
until something asks the app to build its accessibility tree. The watch
list is Chrome, Chromium, Safari, Edge, Firefox, Brave, Arc, Vivaldi,
Opera and Outlook — **six of those are Chromium**, so the module read
nothing in exactly the apps it was written for and recorded "nothing is
focused" about a field he was typing into.
🚨 NEW GROUND: whether his build honours `AXManualAccessibility` or
`AXEnhancedUserInterface` is a fact about HIS Mac (6.233.0), so it asks,
records which was accepted, and names a refusal as the APP saying no.
🩺 AND "HOW DO I KNOW?" IS THE BIGGER HALF — 6.317.0 for the sixth
time. The report describes a SESSION and he is asking about THIS field;
"0 kept" is true of a quiet morning and of a feature that can never read
anything. `_G.draftCheck()` reads the focused field at the moment it is
called. It never prints the text.

### K2. 🔎 THE ONE THAT WAS WRITTEN DOWN AND NEVER SWEPT
`default_apps.lua` carries the rule in its own comment — "a chooser with
a queryChangedCallback stops filtering for itself". **Twenty pickers set
one and nineteen rebuild their rows from the query.** menu_search was
the twentieth. 6.305.0 again, and the sweep is measured rather than
asserted.

### K3. 🗿 AND ONE OF THEM WAS A DECISION, NOT A BUG
right_click.lua's header says in writing that it never asks what is
selected. That is a year old and he has been pressing the key at files
he had already clicked. Narrowed by SHAPE (does the focused element have
selected rows?) rather than by a list of apps, so Finder, a message list
and a sidebar all work and a text field is untouched.

### K4. 📅 AND ONE WAS ALREADY TRUE, WITH A LIAR IN FRONT OF IT
6.371.0 expands `11-06-26 ` → `11-06-2026 `. `_G.acDateCount` was
defined forty-four lines above the locals it reads, so the report said
"no two-digit date typed this session" on every Mac, for ever. The
feature was alive; the only line that could say so said no. The
calendar half is a default changed and shipped (6.267.0).

### K5. ❓ WHAT IT ASKS HIM
1. Is the self-test block at boot welcome, or noise? (`sayBoot`)
2. Dashes or slashes for the calendar's copy? He gave both.
3. If `_G.draftCheck()` says an app REFUSED its tree — which app?
4. Does ⇪⇧F aiming at the selection ever get in his way? (`useSelection`)

### K6. 📏 STILL OWED, UNCHANGED BY THIS BATCH
D7's second half (the crop tool) · the @reports release (his Q3) · the
focus-door naming (his Q4) · E1–E16 · F1 (`tests/test_lint.lua`) · D1
⌘Space · D4 the Mug Player's size · D5 ⇪7's detail · D8 the public
config · D10 ⌥Tab lists every panel.

### K7 D7 IS CLOSED — THE CROP TOOL SHIPPED AS 6.414.0

**6.414.0.** The half that was owed since 6.407.0, and it is a SMALL
release for a reason worth writing down: the rectangle is an ordinary box
note, so the corner drag, the hit test, the move, the size handle, ⌘Z and
6.189.0's keep-across-a-close all served it with no new code. What a crop
actually cost is the three things no existing mark needed — **how it is
drawn before it acts** (the spotlight's veil inverted, so what would GO
is what is dim), **what committing it does to everything else** (every
mark shifts, arrow ends included, and the undo row carries the whole old
canvas AND the shift), and **what it refuses**.
🚨 THE REFUSAL THAT EARNED ITS CHECK is the whole-shot rectangle — the
one input a naive implementation agrees with everywhere else (6.230.0):
obeying it spends an undo row, resizes nothing and reads as a key that
did not work. The floor names the SIZE (6.336.0).
🔒 AND THE DIM IS DRAWN FOR THE SCREEN AND NEVER FOR THE FILE, with two
belts, because a dark border baked into a saved screenshot cannot be
recovered from the file.
🗑 One guard was written and taken out again (6.199.0, ninth time): ⏎'s
`(!sel || sel.kind === 'crop')` was unkillable because the text-box
branch above already claims the only case that matters — the ORDER is
the rule — and it was an invisible predicate besides.
🔬 AND THE JS HARNESS FROZE THE PIXEL BUFFER'S ROW STRIDE at birth.
Nothing noticed, because every resize in the suite until now was a GROW,
which changes the HEIGHT; a crop changes the WIDTH. 6.290.0 in a new
costume, and the general half is that a stub's DERIVED geometry is part
of its fidelity.
📏 WHAT IS STILL OPEN after this: the @reports release (his Q3), the
focus-door naming (his Q4, which he may have deferred), E1–E16, F1
(tests/test_lint.lua), and the standing D queue — D1 the ⌘Space
launcher, D4 size the Mug Player to the film, D5 ⇪7's macOS detail, D8
the public sanitised config, D10 ⌥Tab lists every panel.
