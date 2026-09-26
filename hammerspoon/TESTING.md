# TESTING — how to score release 6.288.0

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

## 6.288.0

6.288.0 verify with LL — 🖥 THE SHEET OPENS WHERE YOU ARE (KNOWN GROUND)
WHAT CHANGED: ⇪/ is placed on the screen this config resolved, and can
no longer be pulled onto another monitor by a spot you saved there.
WHY IT MATTERS: your two sentences are ONE bug, which is why I want to
say the mechanism plainly. Your saved spot is stored as an offset into
the screen you dragged it on. Dragged to the right-hand side of the 4K
that offset is about 2000 points. Applied to the Air's top-left, 2000
points to the right is physically ON the 4K — and the helper that was
supposed to keep the panel on a screen kept it on THAT one, throwing
away the screen every line above it had just worked out. And a sheet on
the other monitor is a sheet that is not in front of you: you drag it
back, and it appears. Second sentence, same event.

A. THE HEADLINE — this needs both monitors.
A1. On the LG, press ⇪/ and drag the sheet to its right-hand side.
    Close it.
A2. Click into an app on the AIR. Press ⇪/.
    EXPECT: the sheet is on the AIR, fully on screen, over toward its
    right-hand edge. It must NOT be on the LG.
A3. Console: `_G.cheatSheetReport()`. The new "place :" line should
    read `nudged back onto this screen — the spot you saved was on a
    bigger one`, with the screen it used underneath.
A4. Now back on the LG: press ⇪/.
    EXPECT: your spot, exactly — it fits there, so it is obeyed, and
    the report reads `where you put it`.

B. IS IT IN FRONT?
B1. Each time it opens, is it readable without you touching it?
    EXPECT: yes. If it EVER opens and is not in front on the monitor
    you are looking at, that is a second bug and I have not found it —
    run `_G.cheatSheetReport()` and `_G.screenReport()` at that moment
    and paste both. Those two together name the screen, the rule that
    chose it, and where the panel went.

C. MUST STILL WORK.
C1. Drag the sheet anywhere and reopen: it is where you left it.
C2. Type to filter, scroll with the wheel, Esc to close — unchanged.
C3. `_G.cheatSheetCenter()` still forgets the spot and re-centres.
C4. Unplug the LG, then ⇪/. EXPECT: it opens on the Air, on screen.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. When your saved spot does not fit the smaller screen, I nudge it to
    the nearest edge rather than re-centring — so a sheet you like on
    the right stays on the right. Is that what you want, or would you
    rather it centred on a screen it does not fit? "nudge" · "centre".



## 6.287.0

6.287.0 verify with LL — ✏️ THE TEXT TOOL IS A TEXT BOX (KNOWN GROUND)
WHAT CHANGED: all four of your text-box asks, in one release, because
they were one defect seen from four sides.
WHY IT MATTERS: a text note had never had a WIDTH — only a font size.
6.188.0 made the corner handle scale the letters, so there was nothing
to wrap at, nothing for Return to make a second line of, and the one
control on the box did the one thing you did not want it to.

A. THE HEADLINE. ⇪⇧1 on a screenshot, press T, click.
A1. Type a sentence long enough to be worth wrapping, then press ⏎.
    EXPECT: a NEW LINE inside the box. It must NOT finish the box.
A2. Type a second line. Press ⇧⏎.
    EXPECT: done, and the note shows BOTH lines on the shot.
A3. Drag the corner handle to the LEFT (no modifier).
    EXPECT: the box gets narrower and the words RE-WRAP. The letters
    stay exactly the same size. That is asks 2, 3 and 5 at once.
A4. Hold ⇧ and drag the same corner.
    EXPECT: the letters grow and shrink, the way they always did.
A5. ⌘Z. EXPECT: the last of those goes back — a re-wrap undoes like
    a move.

B. THE ONES THAT PROTECT WHAT YOU ALREADY HAVE.
B1. Make a box, close the editor with Esc, reopen the SAME shot.
    EXPECT: the box comes back with its lines and its width intact.
    (6.286.0 is what makes Esc keep it at all — do that block first.)
B2. Open a shot you annotated on an OLDER build, if you have one.
    EXPECT: the old text notes look exactly as they did. They have no
    width stored, so they stay one line until you drag one.
B3. Type a very long single word with no spaces — a URL will do — in a
    narrow box. EXPECT: it breaks across lines rather than running out
    of the box.
B4. Make a two-line note ON something (an arrow tip, a button).
    EXPECT: it grows DOWNWARD. The first line stays where you clicked,
    so the note never walks off the thing it points at.

C. MUST STILL WORK — every tool shares this canvas.
C1. ⌘click a text box: its words open, pre-filled.
C2. Drag a text box by its middle: it moves.
C3. Esc with the box open cancels the BOX; Esc again closes the editor.
C4. ⌘⏎ saves, and the saved PNG has the wrapped lines in it exactly as
    they looked on screen.
C5. Blur, arrow, line, oval, highlighter, counter, spotlight,
    magnifier — unchanged.

D. A JUDGEMENT ONLY YOU CAN MAKE — and this is the one I most want.
D1. ⇧⏎ to finish. Is that the right key? The alternatives are ⌘⏎
    (which is Save & copy everywhere else in the editor, so it would
    be two meanings for one chord) or "click away", which already
    works. "⇧⏎ is fine" · "make it something else" decides it.
D2. Plain drag re-wraps, ⇧drag scales — your suggestion. If it feels
    backwards in the hand, say so and I will swap them; it is one line.
D3. A new box is born as wide as the words you typed. Would you rather
    it started at a fixed width — say a quarter of the shot — so it
    wraps from the first sentence? That is a default, not a release.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
