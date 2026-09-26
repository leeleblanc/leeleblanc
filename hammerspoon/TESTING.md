# TESTING — how to score release 6.286.0

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

## 6.286.0

6.286.0 verify with LL — 🚪 CLOSING THE EDITOR KEEPS YOUR MARKS (KNOWN GROUND)
WHAT CHANGED: every way out of the screenshot editor now asks the page
for your work before the window goes. Until this release only the
Cancel button did.
WHY IT MATTERS: your screenshot said "closing the editor dumps the most
recent edits so I lose any changes", and you were right — even though
6.189.0 was built for exactly that complaint and its tests are green.
Your marks live inside the editor's page; the only thing that hands
them back is the page itself, and only the Cancel button was asking.
Esc deleted the window, and opening a second screenshot deleted the
first one's work without a word.

A. THE HEADLINE — the door you press.
A1. ⇪⇧1 on a screenshot. Draw an arrow, add a text box, blur something.
A2. Press Esc.
A3. ⇪⇧1 on the SAME screenshot again.
    EXPECT: an alert "🖌 Your last edits on this shot are back", and
    every mark where you left it.
    A FAIL here is the bug you reported, unchanged — say so at once.
A4. Same again, but close with the Cancel button instead of Esc.
    EXPECT: identical. (This is the one that always worked.)

B. THE OTHER DOOR, and the one I think you were actually using.
B1. ⇪⇧1 on shot A. Draw something.
B2. Without closing it, press ⇪⇧1 on a DIFFERENT shot B.
    EXPECT: B opens clean.
B3. Now ⇪⇧1 on shot A again.
    EXPECT: A's marks are back. Before this release they were gone,
    silently, and nothing said so.

C. MUST STILL WORK — this release changed how the window closes, so
   this is the regression sweep.
C1. ⌘⏎ saves "… (edited).png" beside the original and copies it.
C2. After a SAVE, reopen the same shot: it opens CLEAN, not with the
    saved marks drawn again. (A saved session is not a lost one.)
C3. Esc while a text box is open closes the BOX, not the editor. Press
    Esc twice to leave.
C4. ⌘Z undo, ⌘V paste an image, ⌘A add capture, ⌘D delayed, ⌘F full
    screen, ⌘O load a shot — all unchanged.
C5. The editor must always close when you ask it to. If it ever hangs
    open for half a second and then goes, that is the belt working and
    it is worth telling me about.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.screenshotEditorReport()` — a new "closing :" line counts the
    doors apart: asked · handed work back · closed on the belt ⚠️ ·
    closed at once. A belt close means the page did not answer in time
    and those marks were NOT kept — if that number is anything but 0,
    that is the next bug and I want the block.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. 0.4 seconds is how long the editor waits for its page before
    closing anyway. If closing ever feels sticky, say so and I will
    shorten it; if you ever lose marks with the report showing a belt
    close, I will lengthen it.
E2. Your four text-box asks — wrap, font size separate from the box,
    Return for a new line, and shrink-to-rewrap — are ONE release and
    they are next. Confirm the shape before I build it: plain drag on
    the corner handle RE-WRAPS the text to the new width, and ⇧drag
    scales the letters. That is your own "hold shift" suggestion; say
    if you would rather have it the other way round.



## 6.285.0

6.285.0 verify with LL — 🔔 THE ⇪ WATCHDOG STOPS CRYING WOLF (KNOWN GROUND)
WHAT CHANGED: nothing about how ⇪ works. What changed is what the
Console says when a panel takes the keyboard.
WHY IT MATTERS: your last paste carried this line —
    ⌨️ ⇪ released by the watchdog — held 8s with no key event and no
    F18 keyUp (release #1) — musicPlayer had taken the keyboard.
Nothing was wrong. The music card takes the keyboard on purpose, so
the Caps Lock release goes to ITS window, and a guard ends the hold
1.5 seconds later exactly as designed. But that is the sentence this
config prints when ⇪ is genuinely STUCK — the thing that killed your
keyboard in 6.214.0 — and it was also adding to the count the storm
report calls a fault. A warning you see every time you play music is
a warning you stop reading.
🚨 AND I HAD THE FIX WRONG IN MY OWN NOTES: I had written that the
card should call `_G.hyperTouch()`. It should not — that call means
"this hold is real, keep it", which would have held ⇪ latched LONGER.

A. THE HEADLINE.
A1. Press ⇪⇧pad. to open the music card. Watch the Console.
    EXPECT, the FIRST time this session: `⌨️ ⇪ hold ended on schedule
    — musicPlayer took the keyboard, so the F18 keyUp went to it.
    Normal, not a stuck ⇪`.
    EXPECT NOT: "released by the watchdog".
A2. Close it and open it again, twice more.
    EXPECT: NOTHING in the Console. It is explained once per panel and
    counted after that.
A3. Console: `_G.hyperKeyReport()`.
    EXPECT three lines — relay · handover · latch — with handover at
    3 and `latch : 0 — ⇪ has not stuck this session`.
    THAT ZERO is the release. Paste the block.

B. MUST STILL WORK — this is the ⇪ key, so it is the important half.
B1. Use ⇪ normally for a day: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space.
    EXPECT: no change of any kind.
B2. Hold ⇪ down for ten seconds without pressing anything, then let go.
    EXPECT: `released by the watchdog — held 8s … (release #1)`, with
    no panel named. THAT one must still appear — it is the real
    warning and it has to keep its teeth.
B3. `_G.hyperKeyReport()` again: `latch : ⚠️ 1`. The ⚠️ is the point.
B4. `_G.stormReport()` — its "before :" line now reads LATCH releases,
    panel handovers and keyUp relays separately instead of summing
    them.
B5. Open Hamsidian (⇪N) and type. The pad does the same handshake, so
    you should see its one-off line too, and typing must be typing —
    no letter should run a shortcut.

C. A JUDGEMENT ONLY YOU CAN MAKE.
C1. Is once per panel per session the right amount of talking, or
    would you rather it never said anything and only counted? "once is
    fine" · "say nothing" decides it.



## 6.284.0

6.284.0 verify with LL — 🏷 THE ASANA TEAM NAME (KNOWN GROUND)
WHAT CHANGED: the team name in the config is corrected to the one you
sent me, and — the actual release — a team's GID is remembered the
first time it resolves, so renaming it in Asana no longer breaks
anything.
WHY IT MATTERS: you asked why you have to hard code team names. You
don't, and you were right to ask. The honest finding is that the half
everyone would suspect was never stale: this config asks Asana for the
team list on EVERY boot, so its answer is always current. What was
stale is the question — the name it searches for, typed into a file.
A fresh answer to a stale question, which is why the warning was
correct and useless at the same time.

A. THE HEADLINE.
A1. Install and reload. Watch the Console during boot.
    EXPECT: the `⚠️ Asana team not found by name: "| 2. SAC Library
    Team Member Projects & Tasks |"` line is GONE.
A2. Console: `_G.asanaTeams()`.
    EXPECT: an "asked" block with your two team names, an "answer"
    block listing every team Asana holds WITH ITS GID, and two ✅
    lines. Paste it — this is the artefact I have been asking for and
    it is the first build that can produce it.
A3. Press ⇪T and start typing a colleague's name from that team.
    EXPECT: they are suggested. That is the thing the warning was
    costing you, and nothing else.

B. THE REAL TEST — RENAME IT ON PURPOSE. Worth five minutes, because
   it is the whole release and you are the only one who can run it.
B1. In Asana, rename that team — add a word, take one away, anything.
B2. Reload Hammerspoon.
    EXPECT in the Console: `🏷 Asana team renamed — "| 2. SAC Library
    Team Member Projects |" is called "<the new name>" now; matched by
    its GID, nothing to edit`. NO ⚠️.
B3. ⇪T again: the same colleagues are still suggested.
B4. Reload once more. EXPECT the same 🏷 line, not a ⚠️ — the pin has
    to be re-written every boot or it would survive exactly one.
B5. Rename it back if you like. Either way it keeps working.

C. MUST STILL WORK.
C1. ⇪T creates a task, with a priority and SAC Values, as ever.
C2. A name that is NOT in the list still submits — that was true
    before and must stay true.
C3. Hamsidian's `_G.scratchPadSend()` still posts to Asana.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Team 1 is "| 1. SAC Library Core Projects |" and I have not
    touched it. If that one has also been renamed, `_G.asanaTeams()`
    will now show you Asana's real name for it — send me the output
    rather than editing the file.
D2. Should the config stop naming teams altogether and just use the
    whole workspace? I have NOT done that: 6.16.9 found the workspace
    is a college with thousands of student accounts, which made the
    picker useless. Say if that has changed.



## 6.283.0

6.283.0 verify with LL — 🧠 ⌥Tab SEES THE CONSOLE (KNOWN GROUND)
WHAT CHANGED: the Hammerspoon Console is remembered by ⌥Tab now, so it
is on the wheel from every desktop instead of only the one it is on.
WHY IT MATTERS: you have told me this twice. You were right twice, and
so was your own explanation — "unless I switch to that desktop I can't
see it". macOS will not tell us about another desktop's windows at
all, so this switcher keeps a memory of every window it has ever
listed. The console was the one thing that never went into it.

A. THE HEADLINE.
A1. Open the Hammerspoon Console. On THAT desktop, press ⌥Tab once.
    EXPECT: a Hammerspoon Console card, as before.
A2. Switch to another desktop. Press ⌥Tab.
    EXPECT: the Console card is STILL THERE, captioned
    "· remembered (another desktop?)".
    THIS is the step that failed before. If it is missing, stop and
    paste `_G.switcherReport()`.
A3. Turn the wheel to it and release ⌥.
    EXPECT: macOS carries you to that desktop with the Console front.
A4. Close the Console, then ⌥Tab and choose the card again.
    EXPECT: the Console OPENS. A card that does nothing is the failure
    this release exists to avoid — tell me if you get one.

B. PASTE BACK, PASS OR FAIL.
B1. `_G.switcherReport()` — new; this module had no report at all.
    The "console:" line has three states and I want whichever you get.
    "not seen yet this session" is HEALTHY on a boot where you have
    not opened the Console — it is not a fault, and it tells you the
    one thing to do (open it, press ⌥Tab once on that desktop).

C. MUST STILL WORK — the memory is shared with every window, so this
   is the regression sweep and it is the important half.
C1. Park a Chrome window on another desktop, ⌥Tab there once, come
    back, ⌥Tab. EXPECT: that window is still offered, as before.
C2. ⌥⇧Tab backwards, ← →, ↑ ↓, Home/End, Return, Esc — unchanged.
C3. A minimised window is still listed; switching to it un-minimises.
C4. ⌥Tab must not feel slower. If it does, B1's "last :" line names
    the phase and the app — paste it.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. The Console now stays on the wheel once you have opened it, for
    the rest of the session. Is that right, or is it clutter on the
    days you open the Console once and never want it again? "keep it"
    · "only while it is open" decides it — the second is a smaller
    wheel and brings back exactly the bug you reported.
D2. Should the MUSIC CARD be on ⌥Tab too? You asked in September and
    I have not built it. It is the one panel that keeps playing when
    it is not in front, which is the argument for doing it alone
    rather than adding every panel this config draws.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
