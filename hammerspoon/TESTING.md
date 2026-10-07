# TESTING — how to score release 6.338.0

You install ONE archive and it carries several releases. Below are the
steps for each release this archive is new for, newest first. Run the
newest one first: if it passes, the ones under it were carried along
and are worth a quick pass rather than a full one.

## How to report back, so the answer is data rather than a verdict

For every numbered step, send me one of these three:

  * **PASS** — it did what the step says it should.
  * **FAIL** — plus what happened INSTEAD, in your words. A screenshot
    of the wrong thing is worth more than a sentence about it; three
    releases this year were diagnosed by a photograph and nothing else.
  * **BLOCKED** — you could not run the step at all. That is a
    different fact from a failure and it changes what I look at.

Then paste the Console lines the steps ask for **whether or not
anything failed**. A report from a working Mac is what tells me what
a broken one is missing — without it I am comparing a failure against
nothing.

A release is a WIN when every step in its section passes. Anything
else is a LOSS and I fix it before building further. You are the only
scorer; I never mark my own.

---

## 6.338.0

6.338.0 verify with LL — ⏰ THE BACKUP CATCHES UP (KNOWN GROUND)
WHAT CHANGED: the rebuild kit refreshes itself without you running
anything.
🔎 AND THE ANSWER TO YOUR QUESTION IS "it already was", which is why
this is a bug and not a feature. The backup has run on a daily timer
since the config had sections — 17:00, every day. What that kind of
timer does is fire at an INSTANT: if the Mac is asleep at five o'clock,
or Hammerspoon is not running then, that day is skipped and nothing
ever goes back for it. Twelve days old means twelve missed 5 PMs, and
from where you were sitting that looks exactly like a backup nobody
set up.
🔑 WHAT IT DOES NOW: once an hour it asks "is the kit more than a day
old?" and runs one if it is. That covers a wake, a late boot, a reload
and a Mac that was simply off at five — one mechanism, not three.

A. THE HEADLINE — and the first run may happen on its own.
A1. Install and reload. Watch the Console for about two minutes.
    EXPECT, because your kit is overdue right now:
      ☁️ Rebuild kit catch-up — the kit is 12 day(s) old — past the
         1-day window; running one now
    **That line IS the release.** Paste it.
A2. Console: `_G.backupReport()`. Find the new `catch-up:` line.
    EXPECT: `every 60 min · 1 started this session · the kit is 12
    day(s) old — past the 1-day window`, and a `↳ last catch-up` line
    under it with the time.
A3. The `last run:` line above it should now be TODAY, with its usual
    per-entry rows. That is the kit being fresh again.
A4. Reload once more and read the boot note. EXPECT it is GONE — the
    kit is a few minutes old. If it is still there, paste it.

B. THE NOTE NO LONGER HANDS YOU A CHORE.
B1. If you ever do see "☁️ The rebuild kit is N days old" again, read
    the rest of the line: it now says **"a catch-up run is due within
    60 min"** instead of giving you `_G.backupNow()`.
B2. 🚨 AND THAT MAKES IT WORTH READING: with the catch-up working,
    that note surviving means the catch-up ITSELF is failing. Before
    this release it just meant your Mac had been asleep at five. If
    you see it twice on different days, paste it — that is a fault now.

C. MUST STILL WORK — this touched the thing that copies your files.
C1. `_G.backupNow()` still runs one by hand, immediately.
C2. The 17:00 timer is unchanged — nothing about it moved.
C3. `_G.backupReport()` still lists every entry with its status, the
    app manifest count, and the crash-report lines.
C4. The half-hourly store mirror and the hourly notes mirror are
    untouched: check their lines still read `ok` with a recent time.
C5. Nothing in the backup folder is ever deleted. Still true — no
    rsync here carries `--delete`.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.backupReport()` after a day of normal use. Two lines matter:
    `catch-up:` and `last run:`. If `catch-up:` ever still reads
    **"not asked yet this session"** an hour after boot, the timer is
    not firing and I want to know — that is the one state this
    release exists to make impossible.
D2. From the WORK MAC too, when you next install there. A work laptop
    is shut at 5 PM far more often than a home one, so that is where
    this should show the biggest difference.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. **A backup can now start at any hour of your day**, not only at
    five. It is an incremental copy running outside Hammerspoon, so
    after the first one it should be unnoticeable — but if you ever
    feel the Mac get busy and find a catch-up in the report at that
    moment, tell me. `settings = { daily_backup = { catchUpDays = 0 } }`
    puts it back to 5 PM only, and `catchUpMins` changes how often it
    asks.
E2. One day is the threshold — the kit has to be more than a day old
    before a catch-up runs, which restores the daily rhythm rather
    than adding a second one. Too eager? Too slack? It is a number.
E3. 🔨 CRUDE OR ELEGANT: nothing was broken and nothing was lost —
    the kit was simply stale, and you would have found out the day you
    needed it. My reading is that this is a defect in a SCHEDULE
    rather than a feature ask, because the config was promising a
    daily backup it was not delivering. Your tag.



## 6.337.0

6.337.0 verify with LL — 🚪 ⇪4 IS macOS'S CROSSHAIR AGAIN (KNOWN GROUND)
WHAT CHANGED: ⇪4 drags the way ⇪⇧4 drags — macOS's own crosshair, its
own numbers, its magnifier, and SPACE to shoot a whole window.
🔎 WHY, AND IT IS THE ANSWER TO YOUR QUESTION. Both keys ask for the
same folder first and write into it, so the folder was never the
difference. ⇪⇧4 hands the whole drag to `screencapture -i` — a
SEPARATE PROCESS whose grab on the mouse belongs to the window server.
⇪4, since 6.264.0, did the drag ITSELF inside this config. And macOS
reads a three-finger trackpad drag as a swipe between desktops: the
gesture is taken away from us before our code is ever asked, and a
desktop switch is exactly when macOS stops sending us events. The same
hand motion works on one key and cannot work on the other.
🔑 SO I STOPPED FIXING THE SELECTOR. ⇪4 on it cost six releases —
6.264.0 built it, 6.265.0, 6.274.0, 6.282.0, 6.318.0 and 6.336.0 each
repaired a different part — and every one of them moved a piece of the
same thing. Your working key was pointing at the answer the whole
time.
🚨 AND 6.336.0 MADE IT WORSE, which you should know before you test.
Its drag-end watch quoted a rule from this project — ask macOS whether
a button is down, and believe it ONLY when it says yes — and then did
the opposite: it ended the drag whenever macOS did not say yes. A
three-finger drag presses no button at all, so it ended every one of
them 0.2 seconds in, a few pixels wide, with "📐 Nothing captured".
That is mine, it is fixed, and "still does not" was the correct report
of it.

A. THE HEADLINE — thirty seconds.
A1. Press ⇪4 and drag a rectangle THE WAY YOU NORMALLY DO, three
    fingers and all.
    EXPECT: macOS's crosshair with its own live coordinates, the
    shutter, and the file in your screenshots folder — exactly like
    ⇪⇧4, because it is the same drag.
    **A FAIL is anything that is not a captured rectangle.**
A2. Press ⇪4 and hover WITHOUT dragging, over something small.
    EXPECT: the native MAGNIFIER — the loupe showing individual
    pixels. 6.264.0 took that away; it is back.
A3. Press ⇪4 and tap the SPACE BAR, then click a window.
    EXPECT: that whole window is captured. Also back.
A4. Press ⇪4 and press Esc. EXPECT: nothing captured, no overlay left.
A5. ⇪⇧4 (OCR) — unchanged, and now it should FEEL identical to ⇪4 up
    to the moment of release, because it is.

B. WHAT YOU LOSE, so it is not a surprise in a week.
B1. ⇪4 no longer has OUR live `1280 × 720` box or our white
    crosshairs. macOS's HUD carries its own numbers instead.
B2. ⇪4 then ⇪⇧5 and ⌘5 ("repeat area") no longer re-shoots the same
    rectangle, because `-i` will not tell us where you dragged. A
    rectangle you select with ⇪5 or the editor's ⌘A still repeats.
B3. **OUR SELECTOR IS NOT GONE.** ⇪5 scrolling capture and the
    editor's ⌘A still drag on it, crosshairs and live size and all —
    try ⇪5 and you will see them. If you prefer ours on ⇪4 and will
    live with the gesture problem, ONE WORD and I change the default
    back; it is `settings = { screenshots = { areaNative = false } }`
    and I would rather ship the answer than leave you a line to type.

C. MUST STILL WORK — ⇪4 feeds half this module.
C1. The shot still lands in the screenshots folder and still goes on
    the clipboard (⌘V pastes it).
C2. It is still RENAMED after the words in it a few seconds later.
C3. ⇪⇧1 on it opens the editor. ⇪⇧5 lists it. ⇪⇧2 window, ⇪⇧3
    delayed, ⇪5 scrolling — all unchanged.
C4. ⇪5: drag over a scrolling page. EXPECT our crosshairs and live
    size, and a stitched shot. **This is the key that still uses our
    selector, so it is the one that proves the belt fix.**

D. PASTE BACK, PASS OR FAIL.
D1. `_G.screenshotsReport()` — the whole block. Three lines matter:
    · `area    :` should read "macOS's own crosshair and HUD — the
      shipped default since 6.337.0…". It must NOT say "your settings
      line asked for it", because you did not.
    · `routes  :` counts ⇪4's presses; `refused` must be 0, because a
      default is not a failure.
    · `drag    :` now only moves for ⇪5 and ⌘A. If it ever carries
      "N drag(s) ran with no held-button signal at all", paste it —
      that line is the 6.336.0 regression being refused rather than
      acted on, and on a trackpad I expect to see it.
D2. If ⇪4 ever does nothing again, `_G.alertReport()` as well. With
    ⇪4 back on `-i` there is almost nothing of ours left in that path,
    so a failure now points at the folder or at macOS.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. **The one question, and it is the whole release:** which do you
    want on ⇪4 — macOS's crosshair that always captures, or our live
    W × H that cannot survive a three-finger drag? I have shipped the
    first because a readout on a key that does not capture is worth
    nothing. Say the word and the default goes back.
E2. THE WAY TO HAVE BOTH, and I will not build it on a guess: draw our
    W × H on a see-through overlay ON TOP of macOS's crosshair, so
    macOS keeps the drag and we only draw the numbers. I do not know
    whether anything we can draw sits above macOS's own screenshot
    layer, and that is a fact only your Mac can answer. If you want
    it, the next release is a probe that tries it and reports what
    happened — not a fix.
E3. 🔨 CRUDE OR ELEGANT: ⇪4 is the key you press most, and it has been
    unreliable since 6.264.0. My reading is 🔨 CRUDE for the stretch
    where 6.336.0 killed every drag 0.2 s in — that is a key that did
    not work, from a release of mine — and the pass count is 6. Your
    tag either way.



## 6.336.0

6.336.0 verify with LL — 🚪 ⇪4 SURVIVES A RELEASE macOS SWALLOWS
(KNOWN GROUND)
WHAT CHANGED: when the release of a ⇪4 / ⇪5 drag never reaches this
config, the selection is finished from where the pointer is instead
of the overlay sitting there until you press Esc.
🔎 YOUR THREE SENTENCES ARE ONE BUG, and it is worth saying which:
"crosshairs showed · it said 0x0 on release · it jumped a few
desktops · I had to hit escape". The selector ended a drag in exactly
ONE place — a mouse-up delivered inside its own overlay — and that
overlay hears nothing that happens off its own screen. macOS reads a
three-finger trackpad drag as a swipe between desktops, and a desktop
switch is exactly when macOS stops sending us events. So the numbers
froze at the 0 × 0 written the instant you pressed, nothing was
captured, and Esc was the only way out. The ⇪5 picture you sent is
the same event: six slices of the desktop you had been thrown onto.

A. THE HEADLINE.
A1. Press ⇪4 and drag a rectangle normally. EXPECT: unchanged — the
    crosshairs, the live W × H, the shutter, the file.
A2. Now press ⇪4 and drag with THREE FINGERS, the way it failed.
    EXPECT: even if the desktop jumps, the selector is GONE when you
    let go and the rectangle you dragged was captured.
    **A FAIL is the overlay still on screen needing Esc.**
A3. Press ⇪4, start dragging, and release the button with the pointer
    PAST THE EDGE of the screen (or on the other monitor).
    EXPECT: it captures, clamped to the screen's edge. It used to
    hang there.
A4. Press ⇪4 and click once without dragging.
    EXPECT: "📐 Nothing captured — that drag measured 0 × 0. Press
    the key again and drag a rectangle." It used to say nothing at
    all, which is a key that did nothing and explained nothing.

B. MUST STILL WORK — this is the drag every capture goes through.
B1. ⇪5 scrolling capture: drag, and the stitched shot is of the page.
B2. In the editor (⇪⇧1), ⌘A add-capture.
B3. ⇪4 then ⇪⇧5 and ⌘5 ("repeat area") — the same rectangle again.
B4. Esc during a drag still cancels and captures nothing.
B5. ⇪⇧4 is untouched — still macOS's own crosshair.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.screenshotsReport()` — there is a new `drag :` line:
      drag    : 6 finished — 4 on the release itself · 2 where macOS
                swallowed the release
    **That second number is the answer to the desktop question**, and
    it needs nothing from your memory. If it is 0 after a day of
    ordinary use, the swipe is not happening to you and I am wrong
    about the mechanism — which is just as useful.
C2. If it ever reads "⚠️ N selector(s) ran with NO drag-end watch",
    paste it: that Mac would not give us a timer and is back on the
    old behaviour.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. THE DESKTOP JUMP ITSELF IS NOT FIXED, and I am not going to fix
    it quietly. It is macOS's own gesture, and the only lever here is
    to start SWALLOWING your drag — which costs every app underneath
    it. Check System Settings › Accessibility › Pointer Control ›
    Trackpad Options › "Use trackpad for dragging" with three-finger
    drag. Tell me whether turning that off stops the jumping; that
    one answer settles it, and it is the same question 6.306.0 asked
    about the cheat sheet and never got.
D2. 🔨 CRUDE OR ELEGANT: ⇪4 left an overlay on your screen that only
    Esc could clear, and the shot you wanted was lost. My reading is
    that it degraded — Esc always worked and nothing was destroyed —
    but it cost you the capture every time. Your tag.



## 6.335.0

6.335.0 verify with LL — 🗑 THE BIN IS A BUTTON (KNOWN GROUND)
WHAT CHANGED: there is a 🗑 in the Hamsidian header, beside the other
buttons. It shows every note you have deleted; clicking one puts it
back.
🔎 AND NOTHING WAS BROKEN, which is worth saying first: those notes
have been recoverable since 6.321.0 — a delete MOVES the file to
<Vault>/.trash and nothing erases it for 180 days. What you could not
do was LOOK, without typing a command. That is the third time in this
module I have built the measurement and not the door.

A. THE HEADLINE.
A1. ⇪3. Look at the header, between 🗂 and ↻.
    EXPECT: a 🗑 button.
A2. Click it.
    EXPECT: the left column becomes the bin — your deleted notes,
    newest first, each with the time it went. The strip above says
    "🗑 BIN · N deleted".
A3. Hover a row. EXPECT: a tooltip saying where it would go back to.
A4. Click a row.
    EXPECT: "🗑 <name> is back → <path>", the note is in Hamsidian
    again, and the row is GONE from the bin.
    **A FAIL is the note opening instead of being restored**, or the
    wrong note coming back — tell me at once if either happens.
A5. Click 🗑 again (or press Esc). EXPECT: back to your notes.

B. THE EDGES WORTH ONE MINUTE.
B1. In the bin, press ⌥↓ and ⌥↑. EXPECT: the highlight walks the
    rows. ⌥⏎ restores the highlighted one — the same thing a click
    does.
B2. ⌘F and type part of a deleted note's name.
    EXPECT: the bin filters. Type nonsense: "no deleted note matches"
    — which must NOT read the same as an empty bin.
B3. If you have never deleted anything on this Mac, the bin reads
    "the bin is empty — nothing has been deleted". If it ever says
    "⚠ the .trash folder could not be read", paste that: those are
    opposite facts and the second one is the one that matters.
B4. Restore a note whose name EXISTS again in the vault.
    EXPECT: it lands beside it as "<name> (restored …)" and your
    newer note is untouched. That rule is 6.321.0's and this must not
    have broken it.

C. MUST STILL WORK — this touched the left column, which is every
   list in that window.
C1. The notes list, ⌘F filter, ↑↓, ⏎ to open — unchanged.
C2. ☑ tasks (⌘⇧K), 🔎 search (⌘⇧F), 🕸 graph (⌘G), 🗂 board (⌘⇧B) —
    all four still open and still come back with Esc.
C3. The ✕ on a note row still deletes it to the bin.
C4. Your scratch tabs are still in the one list (6.333.0).
C5. ⌘N, ⌘D, ⌘K, ⌘⇧S — unchanged.

D. PASTE BACK.
D1. `_G.vaultReport()` — its `bin :` line, and the `deleted:` count.
D2. `_G.vaultTrash()` still works from the Console and must list the
    same notes the button shows. If the two ever disagree, that is a
    real finding.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. There is deliberately NO purge button in the bin. A
    delete-forever control one pixel from a restore control, in the
    list that exists to prevent loss, is the wrong button to add —
    `_G.vaultPurgeTrash()` is still the only thing that removes a
    file. Say if you want one anyway; it is your call, not a gap.
E2. A click restores immediately, with no confirm. Right, or would
    you rather it asked? Nothing is destroyed either way, which is
    why I made it immediate.
E3. 🔨 CRUDE OR ELEGANT: Hamsidian worked throughout and the notes
    were never at risk — what was missing was a way to look. My
    reading is that this is a DOOR I should have built in 6.321.0,
    not a defect. Your tag.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
