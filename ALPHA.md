# ALPHA — everything still open

2026-10-17 · against 6.363.0 · built by measuring the source, not by
remembering. Where something turned out to be already built, it says so
and names the release.

---

## THE HEADLINE NUMBERS

| | |
|---|---|
| Releases on the scoreboard | 173 |
| **Scored by you** | **35** — 23 wins, 12 losses |
| **Never scored** | **137** |
| Open bugs below | 5 (four were shipped today as 6.364.0–6.367.0) |
| Asks built but never delivered to you | 3 (6.356.0 · 6.357.0 · 6.358.0) |
| Asks waiting on one word from you | 11 |

**133 unscored rows is the real state of this config, and it is the
thing your week actually changes.** Everything below is a guess about
what matters until you run it. A release I think is fine and you have
never pressed is not evidence of anything.

---

## 1 · BUGS — wrong right now, nobody has fixed them

Ordered by what they cost you.

### 1.1 🧊 The 73-second lockup — INSTRUMENTED, NOT DIAGNOSED
Twice now: 2026-10-04 and 2026-10-12, both exactly 73 seconds, both
killed and relaunched by the stall guard. 6.330.0 made the heartbeat
carry what was running, and on 10-12 it answered **"nothing was
marked"** — which rules out all 109 ⇪ shortcuts and nothing else.
Timers, watchers, taps and Hammerspoon's own library loading are all
still standing.
**The one unmeasured candidate**: your Console shows five Hammerspoon
extensions loading over 18–42 SECONDS after a boot that reported 0.2 s.
Each is a main-thread library load. Nothing times them.
**Next**: time the requires in `M.warm` and pay them there. Measurement
first, fix second. A duration that repeats to the second smells like a
timeout, not a random hang.

### 1.2 🔒 The first Secure Input reading is never announced
`_G.secureInput` is born unknown, and the announcement only fires on a
CHANGE. So a Mac where Secure Input is already held when the first probe
lands reports it **to nobody, for ever** — and Secure Input kills every
shortcut on the Mac with no error anywhere (it took your keyboard for
four hours once).
**Fix**: one asymmetry — a first reading of ON speaks, a first reading
of OFF stays silent. Small, and it is in the highest-stakes row here.

### 1.3 🆔 The OCR tag reads an inode as a path
Your Console, unprompted: `⚠️ OCR tag: clipboard file URL(s) matched no
usable image — "/.file/id=6571367.28635714/"`. That is 6.237.0's bug,
solved for the Jug Player and never carried to the OCR side. The fix is
to publish the function that already works rather than write a second
one. **Blocked on one sentence from you** — see §3.

### 1.4 🪟 ⇪⇧V's edit window brings Finder and Chrome forward, and the
pointer jumps monitors
Two sentences, probably one mechanism: the picker's focus restore
fights the editor's caret chase, and every app switch makes
mouse_follows warp the pointer. **Not diagnosed.** The experiment is one
Console line and it decides it outright — see §3.

### 1.5 🖱 Trackpad hypersensitive
Nothing in this config posts or scales a mouse-move or scroll event, so
on a read this is not ours. But you are on a beta OS that has aborted
Hammerspoon twice from inside AppKit. **Needs the quit test** — see §3.

### 1.6 ⚙️ Two of your four deliberate misspellings should have corrected
`rihgt` → right and `Mispellings` → Misspellings both answer correctly
when I run the real rule against the real word list. `donw` and `wiht`
are correctly silent (4 letters, below the measured floor). So something
on your Mac is stopping the other two — the app you typed them in, or
the word list still loading. **Needs the report and the app name.**

### 1.7 🧊 Ice.app settings will not open
Not ours as far as anything can tell, and unresolved since September.
**Needs the one test**: does Ice's Settings open with Hammerspoon QUIT?

### 1.8 🔢 The selection count counts punctuation
`end.` is one word and four characters plus a full stop. That may be
correct. **Needs one sentence** on what you expected.

### 1.9 📝 A closed Hamsidian tab cannot be forgotten  ← **your ask today**
See §5.1. Confirmed by reading: the history rows carry no ✕ and there is
no forget path anywhere in the module.

---

## 2 · ASKS OF YOURS WITH NOTHING SHIPPED

### 2.1 💾 The draft keeper — **you escalated this by name**
A floppy beside a text field in Chrome and Outlook that watches the
typing and keeps it. Your scope is already decided: browser AND Outlook
fields · ⏎ on a row **copies** it, never types back into the page · a
`draft_keeper-<Mac>.csv` in the Logs folder · `@draft` in ⇪D.
**One question before it is built** — §3.
It is the only tool here that would watch your typing into somebody
else's form, so it has rules to meet that nothing else does: stands down
on pause, never posts a key, refuses password and secure fields, and
treats "cannot tell if this is secure" as secure.

### 2.2 🪟 Size the Mug Player to the film (your answer: "like VLC")
Was blocked on a film actually loading. 6.355.0 played one from your
Desktop, so it is unblocked. **One question** — §3.

### 2.3 🖱 Click hints over the real controls
The honest answer to "too much work to get to a specific element". 1–2
keystrokes, landing ON the button rather than near it. NEW GROUND and
main-thread Accessibility work, so the first release is a probe that
measures the cost per app and falls back to the grid when it is slow.
The measurement IS the feature, so you never have to run anything.

### 2.4 🖼 Screenshot editor — a CROP tool
New drawing, a new saved rectangle. Its own release.
**Note**: the SIZING half of that ask is already built and I had it
listed as open — `ed.windowSizeFor` has clamped at **85% of the screen**
with a floor at the rail height since 6.270.0. If the window is still
too big, that is the number 0.85, not a release.

### 2.5 🟥 The doubled-word pink underline
Detection is free. The MARK is the problem: nothing can draw inside
another app's text field, so it depends on whether the app answers
`AXBoundsForRange` — which is **per app**, and the ground probe
(`_G.groundReport()`) answers it in one line from inside Chrome, Asana
and Mail. **Blocked on those three runs** — §4.

### 2.6 📅 Date expansion
`09-13-26 ` → `09-13-2026`, slashes too. An autocorrect rule, fires on
the space after a date shaped MM-DD-YY only. Small and unbuilt.

### 2.7 📋 A copied IMAGE as the first paste candidate
Asked 2026-09-13. Needs reading what clipboard_history does with images
first — 6.190.0 sends them to the OCR engine.

### 2.8 ⌥Tab should list the Mug and Jug Players
You asked on 2026-09-20. It is small. **One question**: just the
players, or every panel this config draws? The players are the only ones
that keep PLAYING when they are not in front, which is the argument for
doing them alone.

### 2.9 🖥 ⇪7's macOS line wants more detail
"macOS 27.0 (26A5388g)" today. Marketing name, that it is a BETA, the
Darwin version and the install date are all readable. Needs scoping.

### 2.10 🔗 Anchors says "create a new note first" on a cold start
6.340.0 fixed exactly this on Hamsidian's own surface and did not sweep
the modules that READ its index. ⇪⇧U has the same "not yet" vs "there is
nothing" collision. Its own release, small.

### 2.11 🩺 MANIFEST.txt and `_G.installCheck()`
You asked: "so I don't have to remember." A generated manifest at the
archive root — every runtime file and its byte count — and one command
that names any file that disagrees. It catches the half-install that
cost us 6.311.0, and it is silent on a healthy Mac.
**This one is worth more during your two-Mac week than anything else in
this section**, because it answers "did it install correctly" without
you having to describe anything.

### 2.12 ☁️ The OneDrive check  ← **your ask today**
See §5.4.

### 2.13 Long-standing, unscoped
- The 4 PM review you said "Make" to
- Bookmarks as a per-Mac CSV searched from ⇪D
- The public sanitised config (you said "I will after you build")
- The website, and the Claude door
- OCR gibberish tier 2 — **deliberately NOT built**, on your own bound:
  "if the method can introduce errors, singles only"
- Canvas (the Obsidian-compatible JSON Canvas format) — read-only
  surface or authoring surface is the open question
- A SNIPPETS window in the ⇪space style
- Folding Hamsidian's scratch tabs and notes into one data shape
  (6.333.0 did the LIST; the data question is still open — §3)

---

## 3 · WAITING ON ONE WORD FROM YOU

These are not work. They are answers that unblock work, and some have
been waiting weeks.

1. **The grid's two-keystroke labels.** 26 letters, label length 2 =
   676 cells — within 4% of today's 729, so the boxes stay the size you
   have accepted, but it is **two keystrokes instead of three**. A third
   of the typing gone for no loss. Yes or no.
2. **Hamsidian's data shape.** Should a scratch tab become a real .md
   note the moment you make it (one list, everything a file, searchable
   everywhere, but every keystroke eventually writes to OneDrive), or
   stay a tab until ⌘⇧S? This is the whole release either way.
3. **The draft keeper's bound.** Every draft, or only ones over some
   length and after a pause? Keeping everything makes the CSV a log of
   every search box you have ever typed in.
4. **Mug Player sizing.** A 21:9 film on the Air is a very wide window.
   Does the aspect ratio win, or a maximum width?
5. **⇪J on an image.** "Nothing to append" is honest — the clipboard
   held a picture. Should ⇪J append the image's PATH, or its OCR text?
   Both exist in this config.
6. **⌥Tab**: the two players only, or every panel?
7. **The Obsidian wording.** Four visible strings still tell you to use
   Obsidian. Nothing in this config launches or requires it — it is a
   file-format lineage so your notes stay portable. Leave it, call it
   Markdown, or call it Hamsidian?
8. **The selection count** — what did you expect it to count?
9. **The OCR inode bug** — which action produced that line: copying a
   file in Finder and pressing the OCR tag key, or a drag? The
   pasteboard flavours differ and one of them makes the fix trivial.
10. **The ⇪⇧V focus fight** — run `_G.mouseFollows.stop()` and then edit
    a clipboard entry again. If the monitor-jumping and the app flapping
    both stop, that names it in one test.
11. **Ice.app** — does its Settings open with Hammerspoon quit?

---

## 4 · ONLY YOUR WEEK CAN ANSWER

Nothing I can do from here moves these. They are why the two-Mac run is
worth doing.

- **133 unscored releases.** Not all of them matter, but the ones that
  touch what you use daily do.
- **The work Mac has never been measured on most of this.** Its
  `_G.stormReport()` has been owed since 6.214.2. Its `_G.groundReport()`
  would answer the Accessibility, Secure Input and ⌘⌘/⌥⌥ rows that
  decide three features.
- **`_G.groundReport()` from inside Chrome, Asana and Mail** — the
  `bounds :` line decides whether the doubled-word underline can exist in
  that app at all.
- **Is ⇪4 still intermittent?** 6.337.0 put it back on macOS's own
  crosshair, which removed six releases of our own code from that path.
  If it has been solid since, that thread closes.
- **Does the 73-second hang come back**, and what does the guard's
  `in flight:` line say this time.

---

## 5 · YOUR FOUR ASKS FROM TODAY — measured

### 5.1 📝 Delete a closed Hamsidian tab — **REAL, not built**
Confirmed by reading the page: a history row is drawn as
`<div class="row" data-id=…>` with a time, a title and a preview, and
**no ✕**. The only thing that removes a row from `sp.history` is
restoring it. There is no forget path in the module at all.
This is exactly 6.272.0 — the ✕ on a Jug Player history row — one module
along, including its trap: the ✕ must be asked BEFORE the row it sits
inside, or the shared click handler RESTORES the tab on its way to
forgetting it. And it must forget by id, never by row number, because
the list renumbers under your hand.

### 5.2 ❌ A more verbose Asana failure — **REAL, and the detail already
exists in the wrong place**
Asana's own refusal IS captured: `Asana refused it (HTTP 400) — <first
200 characters of Asana's answer>`. It reaches an alert that is gone in
ten seconds, a notification, and a sticky line in
`_G.scratchPadReport()`.
**What it never reaches is the tab** — and the tab is what you are
looking at. Its title is a fixed literal, `❌ Error: tasks not sent`,
identical for every cause. Worse, a tab with five tasks where one fails
wears that mark and cannot tell you WHICH one.
That is the fourth time this config has built the measurement and not
the door. The fix: the mark carries the reason, the failure is recorded
**per task**, and Asana's own words are reachable from the thing you are
already looking at.

### 5.3 🎬 Mug Player — the two asks split cleanly
**← → to seek: REAL, not built.** The page's key handler claims ⌘1–9,
⌘O, ⌃⌘F, Escape, space, ↑↓, ⏎ and ⌫ — and deliberately does NOT claim
← →, with a comment saying they are "the film's own keys". That is only
true while the `<video>` element itself has keyboard focus. The document
has focus (that is how space and ↑↓ work), so the arrows reach nothing.
**Which is exactly your report**: you have to mouse over and press the
±15 s buttons. The Jug Player solved this in 6.239.0 by binding them in
code rather than delegating.

**⌃⌘F full screen: ALREADY BUILT — 6.358.0 — and you have never had it.**
It is in the page's key handler, read before the ⌘ bail on purpose. The
reason you have never seen it is the link rot: 6.356.0, 6.357.0 and
6.358.0 were built, gated, committed — and the download links died when
the next release shipped, which is why your Downloads folder stopped at
6.355.0. 6.360.0 fixed that by pinning every link to a commit.
**It fills the screen rather than entering macOS full screen**, and that
is a platform limit rather than a shortcut: hs.webview exposes no
fullScreen window mask (I read the list). If you meant the film going
properly full screen, the film's own control bar does that today, and
putting it on ⌃⌘F is one line.

### 5.4 ☁️ The OneDrive check — **buildable, and it is NEW GROUND**
What is already proven: `hs.fs.attributes` answers **`blocks`** as well
as `size`, and a dehydrated placeholder carries the full logical size
with almost nothing allocated. That is how 6.357.0 stops the Mug Player
freezing your Mac on a cloud film, and it is the same measurement that
can answer "is this file actually here".
So **detecting an offloaded file is solved**. What is NOT known is
whether the "Always keep on device" PIN is readable at all — it belongs
to macOS's File Provider and may or may not be in an extended attribute.
I will not design on a belief about that (it has cost this project a
whole feature before), so the first release is a probe that prints what
your Mac actually answers for a pinned file and an unpinned one.
Then the tool: walk the folders that matter — your vault, the stores,
whatever you name — and report what is not really here. Re-downloading
is possible, but it must happen outside the main thread, because reading
a placeholder is precisely what caused your 72-second freeze.

---

## 6 · WHAT SHIPPED TODAY, AND WHAT IS LEFT

Four of the six I recommended are **built, gated and in 6.367.0**:

| | release | state |
|---|---|---|
| The closed-tab ✕ | 6.364.0 | ✅ shipped |
| Mug Player ← → | 6.365.0 | ✅ shipped |
| The verbose Asana refusal | 6.366.0 | ✅ shipped |
| The OneDrive check | 6.367.0 | ✅ shipped (the probe half) |
| ⌃⌘F on the Mug Player | 6.358.0 | ✅ already built — you have never had it |

Two I recommended and did NOT build, deliberately, because each is a
release of its own and today already carried four:

1. **`_G.installCheck()` + MANIFEST** (§2.11) — so "did it install
   correctly" is a five-second answer on both Macs instead of a
   conversation. **This is the one I would do next**, because it is
   worth more during your two-Mac week than any feature.
2. **The first Secure Input reading** (§1.2) — one asymmetry, in the row
   that can silently kill every shortcut you have.

Everything else in §1–§4 parks until you come back with the week's data.
The eleven questions in §3 are still the cheapest thing you can give me:
each one unblocks a release that is otherwise a guess.
