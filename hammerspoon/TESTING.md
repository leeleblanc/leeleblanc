# TESTING — how to score release 6.295.0

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

## 6.295.0

6.295.0 verify with LL — 🔕 QUIET FOR THE THINGS THAT DO NOT MATTER (KNOWN GROUND)
WHAT CHANGED: a tool can now report a failure to the Console alone.
Exactly one is set that way — the music player, because you named it.
WHY IT MATTERS: you asked for two things and only one of them was
missing. Everything that writes or gathers — Hamsidian, the Asana
submit, the backups, the file tracker, the vault — has alerted on
screen since 6.215.0, because the 🔔 door alerts for every tool. So
this release is the OTHER half: a way to be quiet, and nothing else.
🚨 AND IT FAILS LOUD. A tool nobody has classified still alerts. A
needless alert is an annoyance; a swallowed one is the failure you
asked me to fix in 6.278.0, so the quiet list has to be earned.

A. THE HEADLINE.
A1. Console: `_G.degradeReport()`.
    EXPECT a new line:
      quiet   : 1 tool(s) go to the Console alone — Music player
                (none has degraded this session)
    and two lines under it saying the LOG still gets them and how to
    put one back on screen.
A2. Make a quiet one fail on purpose:
    `_G.degrade("Music player", "on purpose")`
    EXPECT: **nothing on screen**, and a Console line
    `⚠️ Music player: on purpose`.
A3. Make a loud one fail: `_G.degrade("Hamsidian", "on purpose")`
    EXPECT: an alert on screen AND the Console line. That contrast in
    one minute is the whole release.

B. THE HALF THAT MUST NOT HAVE A HOLE IN IT.
B1. `_G.todayReport()` after A2 and A3.
    EXPECT: **both** rows, the quiet one included. Quiet is about the
    alert and nothing else — your 4 PM check must not acquire a blind
    spot named "music".
B2. ⇪⇧D — both are in the notices list too.
B3. `_G.degradeReport()` again: the Music player row must read
    `(🔕 Console only — on the quiet list)` and NOT
    `(⚠️ never alerted — hs.alert refused)`. That second sentence
    would be a lie, and it is the one this release nearly shipped.

C. THE DOOR, because you do not edit files.
C1. `_G.degradeQuiet("Bluetooth")` → Bluetooth goes Console-only.
C2. `_G.degrade("Bluetooth", "test")` → no alert.
C3. `_G.degradeLoud("Bluetooth")` → it alerts again. Nothing is
    permanent and nothing needs a release.

D. MUST STILL WORK.
D1. Use the Mac normally. Any alert you would have seen before — a
    backup problem, an Asana send failing, ⇪4 finding no folder —
    still appears.
D2. If a MUSIC player problem ever matters to you after all, C1's
    opposite is `_G.degradeLoud("Music player")`.

E. A JUDGEMENT ONLY YOU CAN MAKE — and this is the real question.
E1. The list ships with one name on it. Which others do you want
    quiet? Candidates I would guess but will not assume: the QR
    reader, Bluetooth, the key caster, the mini calendar, the
    pomodoro's sound. Name them and they go in the next release as
    defaults; or use `_G.degradeQuiet(...)` for a week first and tell
    me which ones you never wanted to hear from.
E2. The opposite question, and it is the one I would ask myself:
    is anything still alerting that should be LOUDER — a
    notification that survives Focus, the way a failed Asana send
    gets one (6.278.0)? Right now only that send has one.



## 6.294.0

6.294.0 verify with LL — 🎯 ⇪T IS ON THE ASANA CARD (KNOWN GROUND)
WHAT CHANGED: the ✅ ASANA card on ⇪/ now points at ⇪T, the key that
creates a task.
WHY IT MATTERS: you were right, and you have been since 2026-09-20.
The card listed ⇪A ⇪B ⇪C ⇪L and never the tool's front door.
🔎 THE HONEST PART, because it changes what to expect: ⇪T was not
forgotten. It was REMOVED from that card on purpose in 6.114.0, because
it has its own card and one key printed twice reads as a conflict —
which is your own complaint from a screenshot in 6.90.1, about ⇪V. So
this is a POINTER row, not a second claim: the left column reads "task
form" and the key sits in the sentence.

A. THE HEADLINE.
A1. Press ⇪/ and search `asana`.
    EXPECT: the ✅ ASANA card, and in it a row reading
    `task form — CREATE a task — ⇪T opens the labeled form (its own
    card on this sheet)`.
A2. Search `⇪T` instead.
    EXPECT: BOTH that row and the ✅ TASK FORM card below it. The
    search matches the whole row, so the key finds it either way.
A3. Press Esc, then ⇪T. EXPECT: the task form opens, unchanged.

B. MUST STILL WORK — nothing about any key moved in this release.
B1. ⇪A, ⇪B, ⇪C, ⇪L all behave exactly as before.
B2. ⇪⇧Esc still pauses the config, and ⇪⇧Esc again resumes.
B3. ⇪/ filtering, scrolling and Esc are unchanged.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.cheatSheetReport()` — "empty" and "faults" should both read
    **none**, as they did on 6.269.0. If either is a number, paste it.

D. A JUDGEMENT ONLY YOU CAN MAKE — and it is the useful one.
D1. Is "task form" the right words in that left column, or would you
    rather it read "make one", "new task", or just "⇪T"? The last of
    those is the one I will not do silently: it re-creates the
    double-listing you objected to in 6.90.1. If you want it anyway,
    say so and it is your call, not a slip.
D2. 🚩 THE THING I COULD NOT FIX WITH A CHECK: the gate now fails if a
    bound key is printed on NO card anywhere — and it would NOT have
    caught this. ⇪T always had a row; it was on the wrong card for the
    way you think about the tool. If any OTHER key is filed somewhere
    you would not look, tell me which and where you expected it — that
    is a judgement no test can make, and you are the only one who can.



## 6.293.0

6.293.0 verify with LL — ⌨️ ⌥⌥ OPENS THE MENUS (KNOWN GROUND)
WHAT CHANGED: tap ⌥ twice, quickly, and the front app's own menus
open — the same picker ⇪. gives you.
WHY IT MATTERS: the second half of what you asked for, and the proof
that 6.292.0 was worth a release of its own. Adding ⌥⌥ was nine
lines, because the engine already existed and a gesture is now a
registration rather than a second copy of a state machine.

A. THE HEADLINE.
A1. Click into an app with real menus — Word, Chrome, Finder.
A2. Tap the ⌥ key twice, quickly, with nothing else held.
    EXPECT: a picker listing that app's menu items, searchable.
A3. Type a few letters, press ⏎. EXPECT: that menu item runs.
A4. Press ⇪. EXPECT: the identical picker — one function, two doors.
A5. Full screen an app (⌃⌘F) and tap ⌥⌥ there. EXPECT: it opens.

B. THE ONES THAT PROTECT YOUR TYPING.
B1. Use ⌥ normally — ⌥click, ⌥drag, ⌥⌫, and typing accented
    characters if you use them. EXPECT: nothing opens.
B2. Hold ⌥ for a second and release, twice. EXPECT: nothing.
B3. Tap ⌥, type a letter, tap ⌥. EXPECT: nothing.
B4. 🚨 THE ONE I MOST WANT: hold ⌘ AND ⌥ together and tap twice.
    EXPECT: NEITHER the clipboard nor the menus open. A real chord
    must satisfy no gesture, and with two gestures live that is the
    property that makes them safe together.
B5. ⌘⌘ still opens the clipboard history (6.292.0), and ⌃⌃ still
    opens the editor picker.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.doubleTapReport()` — it should now list BOTH gestures under
    one watcher: `⌘⌘ : clipboard history` and `⌥⌥ : the front app's
    menus`, with `watcher : running` once, not twice.
C2. `_G.menuSearchReport()` — its new `⌥⌥` line, whichever of the
    three states you get.

D. IF IT GETS IN THE WAY.
D1. `settings = { menu_search = { optOpt = false } }` switches just
    this one off; ⌘⌘ and ⇪. are unaffected.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. ⌥ is a modifier you probably use more than ⌘⌘'s ⌘ for one-handed
    things — ⌥click, ⌥drag. If ⌥⌥ fires when you did not mean it,
    tell me how it felt rather than a number and I will move the
    timing; if it is simply the wrong key for this, say so and it
    moves to another modifier in one line.



## 6.292.0

6.292.0 verify with LL — ⌨️ ⌘⌘ OPENS THE CLIPBOARD (KNOWN GROUND)
WHAT CHANGED: tap ⌘ twice, quickly, and the clipboard history opens —
the same window ⇪V gives you.
WHY IT MATTERS: you asked for this in 6.198.0, again on 2026-09-13,
and again this week. It had never been built. The uncomfortable part
is that the machinery has been on your Mac the whole time driving ⌃⌃
(the editor picker); what was missing was four lines registering ⌘⌘
against it. That engine is now a shared one in core/, so ⌥⌥ is the
next release rather than a second copy of the same state machine.
🖥 AND YOUR FULL-SCREEN QUESTION NEEDED NO WORK: these panels are
drawn by an app with no Dock icon, which is exactly why they already
come over a full-screen app. Worth testing anyway — step A4.

A. THE HEADLINE.
A1. Tap the ⌘ key twice, quickly, with nothing else held.
    EXPECT: the clipboard history opens — the ⇪space-style panel, the
    same one ⇪V gives you.
A2. Press Esc, then ⇪V. EXPECT: the identical window. They are one
    function now, so they cannot drift apart.
A3. Try it with the LEFT ⌘ and the RIGHT ⌘. EXPECT: both work.
A4. Put an app in full screen (⌃⌘F) and tap ⌘⌘ there.
    EXPECT: the history comes forward over it. If it does NOT, that
    is a real finding and I want to know — say which app.

B. THE ONES THAT PROTECT YOUR TYPING. These matter more than A, because
   this watches every keystroke on the Mac.
B1. Use ⌘C, ⌘V, ⌘S, ⌘Tab and ⌘W normally for a while.
    EXPECT: nothing opens. A chord is not a gesture.
B2. HOLD ⌘ down for a second and let go, twice. EXPECT: nothing — a
    modifier you are holding to use is not a tap.
B3. Tap ⌘ once, type a letter, tap ⌘ again. EXPECT: nothing. A key
    between the halves proves it was a chord.
B4. ⌘-click something twice quickly. EXPECT: nothing.
B5. Type normally in Chrome, Word and Hamsidian for a while.
    EXPECT: no missed characters, no lag. If typing feels heavier on
    this build than on 6.291.0, STOP and tell me — that is the one
    cost this release could have that I cannot measure from here.
B6. ⌃⌃ must still open the editor picker, exactly as before. It is
    deliberately still on its own engine — see the note below.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.doubleTapReport()` — new. Healthy reads
    `⌘⌘ : clipboard history (⇪V) · side either · N fired` and
    `watcher : running`. If it reads `⚠️ NOT RUNNING`, this Mac would
    not give Hammerspoon an event tap — paste it.
C2. `_G.clipboardReport()` — its new `⌘⌘` line has three states and
    I want whichever you get.

D. IF IT GETS IN THE WAY.
D1. `settings = { clipboard_history = { cmdCmd = false } }` switches
    the gesture off; ⇪V is untouched either way.
D2. If ⌘⌘ fires when you did not mean it to, the two windows are
    tunable — tell me how it felt (too eager / too slow) rather than
    a number, and I will move the default.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. ⌃⌃ (the editor picker) is NOT on the new shared engine yet, on
    purpose: its tap is the one that watches every key press, and a
    mistake there does not break a feature — it takes the keyboard,
    which is what 6.214.0 cost you. So it migrates in its own release
    once this one has run on your Mac for a while. The cost until
    then is two watchers instead of one, which is why B5 matters. Say
    if you would rather I did that migration sooner.
E2. ⌥⌥ → the menu bar is the next release and uses this same engine.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
