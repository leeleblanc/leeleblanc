# ALPHA — everything still open

2026-10-20 · against 6.378.0 · built by MEASURING the source, not by
remembering. Where something turned out to be already built, it says so
and names the release — that happens more often than either of us
expects, and it is the single most useful thing in this document.

---

## THE HEADLINE NUMBERS

| | |
|---|---|
| Releases on the scoreboard | 188 |
| **Scored by you** | **37** — 25 wins, 12 losses |
| **Never scored** | **151** |
| Releases built since you last installed | 11 (6.368.0 – 6.378.0) |
| Open bugs below | 6 |
| Asks waiting on one word from you | 7 |
| init.lua | 3,749 lines of a 3,800 budget |
| The gate | 77 Lua suites · 9,748 checks, plus six page suites |
| Modules | 73 in `modules/`, 13 in `core/` |

**151 unscored rows is the real state of this config.** Everything below
is a guess about what matters until you press it. A release I think is
fine and you have never run is not evidence of anything.

---

## 0 · THE ARCHAEOLOGY YOU ASKED FOR

> "Also, look back through our builds all the way to 6.00.0 and check
> for what we have not built. If you can, go even further back."

I scanned every one of the **489 release notes** in CHANGELOG.md — back
to 6.0.0, which is as far back as this file goes — for anything marked
never built, named-not-fixed, not scoped, still owed or its own release.
**84 marked lines.** Then I checked each against the code.

### The honest headline: almost nothing was quietly dropped.
Eighty of the eighty-four are this project's own discipline working —
"named, not fixed" notes written on purpose, one change per release,
with the consequence stated so it could not be forgotten. Most have
since shipped. That is the system doing its job rather than a backlog
hiding in the prose.

### 0.1 Three genuinely old asks, never built, never withdrawn

**🔊 System volume, output/input device switching, a mute toggle**
(6.68.0 – 6.70.0, *February*). The note reads: "System volume,
output/input device switching and a mute toggle ARE reachable and are
not built yet." Per-APP volume of the kind SoundSource gives you was
correctly refused then and is still impossible — it needs an audio HAL
driver, which is why those products ship a system extension. The rest is
a small release and it has sat for two hundred releases.

**🔗 One log of every URL that passed through a window** (6.119.0 ·
6.120.0). You asked for window titles AND urls in one history. The
titles half exists — activity_tracker's CSV, searched by ⇪⇧W. The urls
half does not: ⇪Y archives *Chrome's own database*, which is Chrome's
record rather than an observation of yours, and says nothing about
Safari or about a page you looked at without navigating. "A combined one
was never built, and nothing in this release builds it either." Still
true.

**🟥 The doubled-word pink underline** (6.221.0). See §2.5 — the
detection is free, the MARK is the hard part, and it is blocked on one
measurement only your Mac can make.

### 0.2 And the queue itself had gone stale — which is worse

The curated older-asks list in my own memory file still listed two
things as open that had shipped:

| listed as open | actually shipped |
|---|---|
| `@` source discoverability | **6.298.0** — type `@` alone and all fourteen sources list themselves |
| `_G.clipboardReport()` for the chooser pane | **6.224.0** — and its `pane :`, `home/end :` and `place :` lines are there now |

That list is the thing I read when deciding what to build next, so a
stale row there costs a release. It is corrected, and 6.319.0's rule now
applies to the queue as well as to the code: **a list of what is left is
a sample until somebody greps.**

---

## 1 · BUGS — wrong right now

### 1.1 🧊 The 73-second lockup — INSTRUMENTED, NOT DIAGNOSED
Twice, 2026-10-04 and 2026-10-12, both **exactly 73 seconds**, both
killed and relaunched by the stall guard. 6.330.0 made the heartbeat
carry what was running and on 10-12 it answered **"nothing was
marked"** — which rules out all 109 ⇪ shortcuts and nothing else.
**The one unmeasured candidate**: your Console shows five Hammerspoon
extensions loading over 18–42 SECONDS after a boot that reported 0.2 s.
Each is a main-thread library load and nothing times them. 6.348.0 paid
two of them off for the Mug Player; the rest are unpaid.
**Next**: time the requires in `M.warm`. Measurement first. A duration
that repeats to the second smells like a timeout, not a random hang.

### 1.2 🔒 The first Secure Input reading — **FIXED, 6.378.0**
Was: a Mac where Secure Input was already held at boot reported it to
nobody, for ever, in the row that kills every shortcut on the Mac with
no error anywhere. Now a first reading of ON speaks and says it was
already held; a first reading of OFF still says nothing.

### 1.3 🆔 The OCR tag reads an inode as a path
Your Console, unprompted: `⚠️ OCR tag: clipboard file URL(s) matched no
usable image — "/.file/id=6571367.28635714/"`. That is 6.237.0's bug,
solved for the Jug Player and never carried across. The fix publishes
the function that already works rather than writing a second one.
**One sentence from you unblocks it** — §3.

### 1.4 🪟 ⇪⇧V's edit window brings Finder and Chrome forward, and the
pointer jumps monitors
Probably one mechanism: the picker's focus restore fights the editor's
caret chase, and every app switch makes mouse_follows warp the pointer.
**Not diagnosed.** The experiment is one Console line — §3.

### 1.5 🖱 Trackpad hypersensitive
Nothing here posts or scales a mouse-move or scroll event, so on a read
this is not ours — and you are on a beta OS that has aborted Hammerspoon
twice from inside AppKit. **Needs the quit test** — §3.

### 1.6 ⚙️ Two of your four deliberate misspellings should have corrected
`rihgt` → right and `Mispellings` → Misspellings both answer correctly
when I run the real rule against the real word list. `donw` and `wiht`
are correctly silent (4 letters, below the measured floor). So something
on your Mac stopped the other two — the app, or the word list still
loading. **Needs `_G.autocorrectReport()` and the app name.**

### 1.7 🧊 Ice.app settings will not open — and your answer was "NO
SETTINGS APPEAR STILL"
Unresolved since September. Nothing in this config opens, closes or
moves Ice's windows that I can find. **The one test that settles it**:
does Ice's Settings open with **Hammerspoon quit**? If yes, it is one of
our window tools and I will find it in an hour. If no, it is Ice on a
beta OS and the answer is a reinstall.

### 1.8 🔢 The selection count counts punctuation
`end.` is one word and four characters plus a full stop. That may be
right. **One sentence on what you expected.**

---

## 2 · ASKS WITH NOTHING SHIPPED

### 2.1 💾 The draft keeper — **you escalated this by name**
A floppy beside a text field in Chrome and Outlook that watches the
typing and keeps it. Your scope is decided: browser AND Outlook fields ·
⏎ on a row **copies** it, never types back into the page ·
`draft_keeper-<Mac>.csv` in the Logs folder · `@draft` in ⇪D · and your
answer this round, **90 days**.
It is the only tool here that would watch your typing into somebody
else's form, so it has rules nothing else has: stands down on pause,
never posts a key, refuses password and secure fields, and treats
"cannot tell if this is secure" as secure. **Nothing is blocking it now.**

### 2.2 🪟 Size the Mug Player to the film ("like VLC")
Unblocked — 6.355.0 played a film. Needs the page to report
`videoWidth`/`videoHeight` on load and the window to follow, clamped
into the screen and remembered. Your answer to the one question was
"do what is best so I can test", so: **the film's aspect ratio wins, up
to 85% of the screen.**

### 2.3 🖱 Click hints over the real controls
The honest answer to "too much work to get to a specific element": 1–2
keystrokes, landing ON the button. NEW GROUND and main-thread
Accessibility work, so the first release is a probe that measures the
cost per app and falls back to the grid when it is slow. The measurement
IS the feature, so you never run anything.
**6.373.0 took the cheap half already** — two keystrokes instead of
three, same cell size — and you scored the arrows a WIN on 2026-10-15.

### 2.4 🖼 Screenshot editor — a CROP tool
New drawing and a new saved rectangle. Its own release. The SIZING half
of that ask has been built since 6.270.0 (85% of the screen, floor at
the rail height); if the window is still too big, that is the number
0.85 rather than a release.

### 2.5 🟥 The doubled-word pink underline
Detection is free. The MARK is the problem: nothing can draw inside
another app's text field, so it depends on whether the app answers
`AXBoundsForRange` — which is **per app**. `_G.groundReport()` answers
it in one line from inside Chrome, Asana and Mail. **Blocked on those
three runs** — §4.

### 2.6 📅 Date expansion — **FIXED, 6.371.0**
`10-20-26 ` → `10-20-2026`, slashes too.

### 2.7 📋 A copied IMAGE as the first paste candidate
Asked 2026-09-13. Needs reading what clipboard_history does with images
first — 6.190.0 sends them to the OCR engine.

### 2.8 ⌥Tab should list the panels — your answer: **EVERY PANEL**
Decided, unbuilt. The one real design problem: a picker you ⌥Tab INTO is
a picker you cannot ⌥Tab out of, so the Mug and Jug Players, Hamsidian
and the screenshot editor are the honest set and the pickers are not.
Its own release, and it is next unless you say otherwise.

### 2.9 🖥 ⇪7's macOS line wants more detail
"macOS 27.0 (26A5388g)" today. Marketing name, that it is a BETA, the
Darwin version and the install date are all readable without a binary.

### 2.10 🔗 Anchors says "create a new note first" on a cold start
6.340.0 fixed exactly this on Hamsidian's own surface and did not sweep
the modules that READ its index. ⇪⇧U has the same "not yet" vs "there is
nothing" collision. Small, its own release.

### 2.11 🩺 MANIFEST.txt and `_G.installCheck()` — **you ran it**
Your Console this round: `_G.installCheck()` → attempt to call a nil
value. That is mine: I described it in a verify block and never built
it. A generated manifest at the archive root — every runtime file and
its byte count — and one command that names any file that disagrees. It
catches the half-install that cost us 6.311.0 and it is silent on a
healthy Mac. **Worth more during a two-Mac week than anything else
here.**

### 2.12 ☁️ The OneDrive check — **FIXED, 6.367.0 + 6.368.0**
And your `_G.oneDriveProbe()` answered its open question: there is NO
File Provider attribute on either kind of file, so "Always keep on
device" is not readable from here. 6.368.0 is built on what IS readable
— the allocated-blocks difference — and watches for a file whose bytes
leave.

### 2.13 🗑 App removal — **NEVER BUILT, and you asked directly**
> "Did you build the App removal tool so I can remove apps that run as
> an uninstalled app?"

**No.** There has never been one, in any release. `modules/app_kill.lua`
kills a RUNNING process (⇪⇧Q); nothing in this config has ever deleted
an application or its leftovers. I did not quietly drop it either — I
can find no release where it was asked for and recorded, which means
either it was asked somewhere I am not reading or this is the first time
it has been written down. Either way it is now written down.
**It needs scoping before a line is written**, because it is the only
tool here that would delete files you did not name: what counts as an
app's leftovers (Application Support, Containers, Preferences, caches,
login items, launch agents), whether it deletes or moves to the Trash
(it should move — 6.280.0's rule, the one failure with no way back), and
whether it ever touches anything outside your home folder (it should
not). **Say the word and I will scope it as a release.**

### 2.14 Long-standing, unscoped
- The 4 PM review you said "Make" to
- Bookmarks as a per-Mac CSV searched from ⇪D
- The public sanitised config ("I will after you build")
- The website, and the Claude door
- OCR gibberish tier 2 — **deliberately NOT built**, on your own bound:
  "if the method can introduce errors, singles only"
- Canvas (Obsidian-compatible JSON Canvas) — read-only or authoring is
  the open question
- A SNIPPETS window in the ⇪space style
- The ⌘1–⌘9 screenshot panel reflowed like ⇪space
- "Write into any .csv or .txt" (6.194.0) — a data-shape decision, not a
  UI one: the pad's store is JSON and the Asana task rides on it
- Sequential screenshots to the clipboard — needs your go-ahead; the
  honest shape is a multi-select in ⇪space @shots writing FILE URLs
- Widening `uni.runnable` · vault front-matter completion · ⌘⇧N / ⌘⇧E on
  the small dialog (the `editor.open` window has existed since 6.213.5)
- The ⇪⇧O image-history beach ball — a stall; diagnose before touching
- §6, the Asana dashboard: 537 lines of a feature living inside
  init.lua. Moving it takes the file from 3,749 to about 3,200 and ends
  that ceiling instead of postponing it. Measured, not guessed — it
  reaches only seven things from the main file and all seven are already
  published to modules.

---

## 3 · WAITING ON ONE WORD FROM YOU

1. **The OCR tag inode (§1.3)** — when it happened, had you COPIED a
   file in Finder, or DRAGGED one? Different pasteboard flavours, and if
   the plain-path one is on the board none of this arises.
2. **The ⇪⇧V focus fight (§1.4)** — run `_G.mouseFollows.stop()` then
   edit a clipboard entry again. If the monitor-jumping and the app
   flapping both stop, mouse_follows is the amplifier and the caret
   chase is the trigger. If the apps still flap, the chase alone is it.
3. **The trackpad (§1.5)** — does it happen with Hammerspoon QUIT?
4. **Ice (§1.7)** — do Ice's Settings open with Hammerspoon QUIT?
5. **The selection count (§1.8)** — what did you expect `end.` to count?
6. **App removal (§2.13)** — scope it? And does it move to the Trash
   rather than delete? (I will build it that way regardless.)
7. **⌥Tab (§2.8)** — every panel is your answer; confirm the pickers are
   OUT, since a picker you ⌥Tab into cannot be ⌥Tab'd out of.

---

## 4 · ONLY YOUR WEEK CAN ANSWER

- `_G.groundReport()` from inside **Chrome**, **Asana** and **Mail** —
  the `bounds :` line decides whether §2.5 can be drawn at all, and the
  answer is per app.
- `_G.oneDriveCheck()` after a few days — whether OneDrive is still
  taking files back, and whether 6.368.0 catches it.
- The WORK Mac, on anything. 151 unscored rows, and most of what breaks
  breaks at the boundary with macOS, which is the one place the gate is
  blind.

---

## 5 · WHAT SHIPPED THIS ROUND — 6.368.0 to 6.378.0

| | |
|---|---|
| **6.368.0** | ☁️ OneDrive is WATCHED — a file whose bytes leave is named, out of process, with a ledger that survives a reload |
| **6.369.0** | 🔤 The ✕ you could not see, MEASURED — 2.30:1 against WCAG's 3:1 floor for a control, read from one place |
| **6.370.0** | 🎬 ⌃⌘F full-screens the FILM, the chrome fades, and a film resumes where you left it |
| **6.371.0** | 📅 `10-20-26 ` → `10-20-2026`, slashes too |
| **6.372.0** | 🎯 The pointer rings are bigger and visible on what they sit on — white on white was 1.00:1 |
| **6.373.0** | ⌨️ Two keystrokes land the grid instead of three, same cell size — your YES |
| **6.374.0** | 📁 ⇪I stops showing your apps' own files — your list of thirty-four named the folder |
| **6.375.0** | 🎓 An obscure file type has to be opened in TWO files before it joins |
| **6.376.0** | 📅 A new Hamsidian tab is named for the day it was made |
| **6.377.0** | ⌨️ A picked snippet's insert is counted by route, and a refusal is SEEN |
| **6.378.0** | 🔒 Secure Input already held at boot is announced — it used to be reported to nobody, for ever |

Every one has a mutation sweep behind it, and four of the eleven found a
missing CHECK rather than a missing line — which is the sweep doing the
job it is there for.
