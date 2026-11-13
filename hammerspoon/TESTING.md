# TESTING — how to score release 6.429.0

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

## 6.429.0

6.429.0 verify with LL — 📐 BIGGER BOXES, TWO LETTERS (KNOWN GROUND)
WHAT CHANGED: the grid is back to TWO letters, the boxes are four times
the area they were, and nothing is divided before you type. The a/s/d/f
quartering you said is fine does the precision.
🚨 AND 6.428.0 WAS MINE. It shipped a three-letter label over 4,096
cells and divided every one of those 2 × 2 on top — which is 6.176.0
reproduced exactly, the build you called "insane. Way too small." Its
own comment four lines above that line said a two-character label was
the entire point and quoted your verdict back at me. The prose and the
code disagreed on adjacent lines and I read the prose.

A. THE HEADLINE — twenty seconds.
A1. Press **⇪X**. EXPECT: the codes are **two letters**, not three, and
    the boxes are noticeably bigger — about four times the area of what
    you photographed.
    **A FAIL is three-letter codes.**
A2. 🔎 THE ONE YOU REPORTED: can you SEE THROUGH the grid now? You
    should be able to read the window underneath between the labels.
    That is the whole release and it is the thing I cannot judge from
    here.
A3. Type the two letters. EXPECT: the pointer lands, one keystroke
    sooner than last week.
A4. The letters are still the Timer's yellow — you said that is right
    and nothing about the colour changed.

B. PRECISION IS STILL THERE, and this is the half that makes A safe.
B1. ⇪X, type two letters to land. EXPECT: the yellow box divided into
    four with a letter in each quarter.
B2. Press **a** (top-left), **s**, **d**, **f**. EXPECT: each keeps
    that quarter and divides again. Two presses puts you on a small
    button.
B3. Press **⌫**. EXPECT: it steps back up one.
B4. Keep going until it refuses. EXPECT: it SAYS why — there is a 16 pt
    floor, because a box below that is not something you can aim with.
B5. **COUNT THE KEYSTROKES** on something small — a Finder toolbar
    button. Two letters plus one or two quarters. **Return that number.**
    Last week it was three letters plus quarters for the same target.

C. THE PLATES — the dark patch behind each label.
C1. Look at one closely. EXPECT: it hugs the letters rather than
    filling the cell. It covers 41% of a cell, measured.
C2. 📏 IT IS THERE FOR A REASON AND I DID NOT TRADE IT AWAY: without it
    this yellow measures 1.00:1 over a white window — invisible. The
    obvious fix was to make the plate more transparent, and at 0.55 the
    contrast drops to 3.25:1, under the 4.5 the suite requires. So the
    occlusion came out of SIZE and CELL COUNT instead.
C3. If the plates still bother you: `settings = { mouse_grid =
    { labelBackplates = false } }` removes them entirely, and the
    letters sit on the dim wash alone. Say the word and I will change
    the default rather than leave you a line to type.

D. MUST STILL WORK — this is a full-screen overlay that eats keys, so
   this half matters more than A.
D1. ⇪X then ⎋, six times briskly. EXPECT: opens and closes every time.
    **An overlay left on screen with nothing closing it is the serious
    failure** — ⌃⌥⌘⇧X is the panic key and I want to know at once.
D2. ⇪X, land, then the **arrow keys**: 8 pt a press, 1 pt with ⇧ held,
    and a HELD arrow crawls steadily rather than taking off (6.360.0).
D3. ⇪⇧X — same grid, clicks the moment you finish typing.
D4. ⇪⇧L — the pointer rings. Separate tool, untouched.
D5. While the grid is up, ⌘Q and ⌘Tab still work.
D6. Both screens: the Air's panel and the LG.

E. PASTE BACK, PASS OR FAIL.
E1. Console: `_G.mouseGridReport()`. Three lines:
    · `cells :` — the REAL cell size in points. I have been reasoning
      about that number from arithmetic and want it from your display.
    · `layout:` — should say no pre-draw division.
    · `split :` — a s d f, four parts, and where the keys came from.
E2. If the grid ever DECLINES to open with a sentence about the labels
    being too small, paste it. That is the refusal working — the
    overlay stays off your screen rather than taking the keyboard
    behind letters you cannot read.

❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN
Q1. **Is 676 the right starting size, or do you want fewer still?**
    This is the density you scored "The grid is so much better" in
    6.360.0, with quartering added on top. Fewer letters makes the
    boxes bigger again and costs nothing in typing — `alphabet =
    "asdfghjklqwertyui"` is 289 cells, half as dense again. One line,
    and I would rather ship your answer than leave you the line.
Q2. **Do the plates need to go?** Step C. They buy readability over
    white windows and they are the only thing still drawn over your
    screen.
Q3. **The work MacBook's name** — `scutil --get ComputerName`, whenever
    you next have it. Still the one thing that gives that Mac a profile
    of its own instead of the fallback.



## 6.428.0

6.428.0 verify with LL — ✂️ FOUR BOXES WHERE THERE WAS ONE, IN THE
TIMER'S YELLOW (KNOWN GROUND for the grid; the install is new)
WHAT CHANGED: every grid cell is split into four, so the box you land
in is a quarter of the size it was — and the letters are the Timer
card's yellow instead of white.
📐 YOUR TWO SENTENCES WERE ONE NUMBER, which is why this is one
release. 26 letters squared is 676 cells, which is about 45 points on
the Air against a toolbar button of 28–40 — so the box really was
about twice the size of the thing you were aiming at. Quartering fixes
that WITHOUT making you type a fourth letter: 6.176.0 tried that and
your verdict was "HOLY SHIT! The grid is insane. Way too small."
🟡 AND THE YELLOW IS THE SAME FOUR NUMBERS THE TIMER FLASHES, read out
of one table rather than copied — so it cannot drift from it.

A. THE HEADLINE — a minute, and do A4 even if A1–A3 look right.
A1. Press **⇪X**. EXPECT: the grid, and the cells are visibly SMALLER
    than you are used to — four where there was one.
    **A FAIL is cells the same size as last week**, or a press that
    does nothing at all.
A2. Look at the letters. EXPECT: translucent YELLOW, the same colour
    the ⏱ card flashes when a timer ends, each on a small dark patch
    so it reads over a white window as well as a dark one.
    **A FAIL is white letters** — that is the old behaviour.
A3. Type the three letters of a cell. EXPECT: the pointer lands there,
    exactly as it always has. The code is the SAME LENGTH as before —
    if you are typing a fourth letter, tell me, because that is not
    what this release does.
A4. 🔎 Open something with small controls — a Finder toolbar, a
    dialog's buttons — and aim at one. EXPECT: the box you land in is
    close to the size of the button. That is the whole point of the
    release and it is the one thing I cannot see from here.

B. THE FOUR QUARTERS — this is the "again" half of your ask.
B1. ⇪X, type three letters to land. EXPECT: the yellow box is drawn
    divided into FOUR, with a letter in each quarter.
B2. Press **a** — top-left. EXPECT: that quarter is kept, the pointer
    goes to its middle, and it divides into four again.
    Then **s** is top-right, **d** is bottom-left, **f** is
    bottom-right. Two or three presses put you on a small button.
B3. Press **⌫** (Backspace). EXPECT: the box goes back UP one — the
    quarter you just took is undone.
B4. Keep refining until it refuses. EXPECT: it SAYS why rather than
    doing nothing — there is a 16-point floor, because a box smaller
    than that is not something you can aim with.
B5. Press **space**. EXPECT: it clicks where the pointer is.
B6. Press **⎋** (Escape). EXPECT: the grid goes away and the keyboard
    is yours.

C. MUST STILL WORK — this is a full-screen overlay that captures
   keys, so this half matters more than A and B.
C1. ⇪X then ⎋, five or six times briskly. EXPECT: it opens every time
    and closes every time. **If an overlay is ever left on screen with
    nothing closing it, that is the serious failure** — ⌃⌥⌘⇧X is the
    panic key (hold Control, Option, Command and Shift, press X) and
    I want to know at once.
C2. ⇪X, land, then nudge with the **arrow keys**. EXPECT: 8 points a
    press, 1 point with ⇧ held, and a HELD arrow crawls steadily
    rather than taking off (that is 6.360.0 and it must not have
    moved).
C3. ⇪⇧X — the same grid, but it clicks the moment you finish typing.
C4. ⇪⇧L — find the pointer. EXPECT: three coloured rings, unchanged.
    That is a separate tool and nothing here touched it.
C5. While the grid is up, press **⌘Q** or **⌘Tab**. EXPECT: they still
    work. Only the letters and a handful of control keys are claimed,
    deliberately — an overlay you cannot ⌘Q out of is the hazard.
C6. On BOTH screens if you can: the Air's panel and the LG. EXPECT: a
    readable grid on each.

D. THE INSTALL ITSELF — new in this archive, so worth two minutes.
D1. Unpack it and run, in Terminal:
        sh ~/Downloads/<the folder you unpacked>/tools/hs-install.sh \
           ~/Downloads/<that same folder> --dry-run
    EXPECT a line reading **6.427.0  →  6.428.0**.
    **A FAIL is a version that reads like a sentence** — something
    beginning "-- 📏 `_G.configVersion` is assigned HERE". That is the
    bug this release fixes: the installer was reading a COMMENT where
    the version goes, which also meant its own final check compared
    that comment with itself and could never fail. If you see it,
    this archive is not the one I built.
D2. Then the real thing, without `--dry-run`. EXPECT it to back your
    current config up first, copy, verify, and tell you to reload.
D3. Reload Hammerspoon. EXPECT the boot line to read 6.428.0, All
    green, 79 modules.
D4. Console: `_G.installCheck()`. EXPECT every runtime file present at
    the size this release carries.

E. PASTE BACK, PASS OR FAIL.
E1. Console: `_G.mouseGridReport()` — the whole block. Three lines are
    the ones I want:
    · `cells :` — the REAL cell size in points on the screen you are
      on. I have been reasoning about that number from arithmetic and
      I would rather have it from your display.
    · `split :` — it should name **a s d f**, four parts, and say
      where the keys came from.
    · `labels:` — the four numbers of the yellow, which should be the
      same ones `_G.timerReport()` shows for the flash.
E2. If the grid ever DECLINES to open with a sentence about the labels
    being too small to read, paste it. That is the new refusal working
    — the overlay stays off the screen rather than capturing your
    keyboard behind letters you cannot read — and the number in it
    tells me whether the floor is set right for your eyes.

❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN
Q1. **Is a quarter the right size, or should it go further?** This
    divides each cell 2 × 2. If the box is still bigger than the
    buttons you aim at, one line makes it 3 × 3 (nine per cell) — but
    that is a third of the label size again, so I want your eyes on
    it before I spend them. "right" · "smaller" · "too small now".
Q2. **Are a/s/d/f the right four keys?** They are the home row's left
    hand, in reading order. You had two letters for the half-split in
    6.252.0 and this replaces that habit, so say if it fights your
    fingers — and `refineParts = 2` puts the old two-way split back
    if you would rather have it.
Q3. **Is the yellow readable on YOUR screens?** It is the Timer's
    exact accent at its own alpha, on a dark backplate. White was
    measured at 1.00:1 on a white window — invisible — but I cannot
    see your displays, and if the yellow is now the thing that is
    hard to read, that is a number I will move rather than argue.
Q4. **The work MacBook's name** — `scutil --get ComputerName`. Still
    owed from 6.418.0, and it is the one thing that gives that Mac a
    profile of its own instead of the fallback.



## 6.427.0

6.427.0 verify with LL — 📋 EVERY REPORT, THE WHITE BOX, THE WHOLE
DRAFT (KNOWN GROUND) — this block covers 6.424.0, 6.425.0, 6.426.0 AND
6.427.0: they shipped in one archive and share one test plan.
📏 FILED UNDER THE NEWEST ON PURPOSE: tools/build-test-plan.lua reads
one version per heading, so a batch goes under its newest and names
the others in its own section headings.

🚑 BEFORE ANYTHING ELSE — THE WHITE BOX ON YOUR SCREEN RIGHT NOW.
Any one of these clears it, in the order I would try them:
  1. **⌃⌥⌘⇧Esc** — the panic chord. On 6.424.0 it closes the editor;
     on the build you are running it will not, so go to 2.
  2. Console: `_G.screenshotEditor.close()`
  3. Console: `hs.reload()`
Then install 6.427.0, which is what stops it happening again.

── 1. 🪟 THE WHITE BOX (6.424.0) ───────────────────────────────────
1a. ⇪4 a screenshot, then ⇪⇧1 to open the editor. Do it five or six
    times, closing with Esc between.
    EXPECT: it opens every time, with your shot in it.
    **A FAIL is a white box, or a press that does nothing.**
1b. If a press ever does nothing now, that is the release WORKING —
    you should get an alert reading "macOS would not put the editor on
    screen, so nothing was left behind — press ⇪⇧1 again". Press it
    again; it opens.
    RETURN: that alert's wording, if you ever see it.
1c. Console: `_G.screenshotEditorReport()`.
    RETURN: the whole block. There is a new `opens :` line — on a good
    day it reads "N — macOS put every editor window on screen". If it
    ever reads a ⚠️, that line names which of two faults it was
    (macOS refusing, or a page that could not be built) and says
    nothing was left on screen either way.
1d. With the editor OPEN, press **⌃⌥⌘⇧Esc**.
    EXPECT: the editor closes along with everything else, and the
    panic alert lists "screenshot editor closed".
    RETURN: that list.
1e. Open the editor, draw an arrow, press ⌃⌥⌘⇧Esc, then ⇪⇧1 on the
    SAME shot. EXPECT: your arrow is back. The chord asks the page for
    your marks on the way out rather than throwing them away.

── 2. 💾 THE WHOLE DRAFT (6.426.0) ─────────────────────────────────
2a. Console: `_G.draftKeeperReport()`.
    RETURN: the whole block. Two things are new — a `whole  :` line
    naming the ceiling, and `already kept, unchanged` on the skipped
    line.
2b. Look at your two 23,603-character rows from this morning. They
    will still say CUT, because they were written under the old
    ceiling — that is honest, not a bug.
2c. Now type (or paste) something long into a Chrome box — more than
    ten thousand characters; a Console dump is ideal. Stop typing and
    wait fifteen seconds.
2d. `_G.draftKeeperReport()` again.
    EXPECT: the new row's character count is the REAL length with no
    "⚠️ CUT" after it.
    RETURN: that row's line. **A CUT marker on anything under 120,000
    characters is a FAIL.**
2e. Press ⇪D, type `@draft`, ⏎ on that row, then ⌘V somewhere.
    EXPECT: the WHOLE thing comes back, in order, with its newlines.
    That is the release.
2f. THE DUPLICATE. With that draft still in the box, click into
    another tab or app, then click back into it and leave it alone for
    fifteen seconds.
    EXPECT: `_G.draftKeeperReport()` shows **no new row** and the
    `already kept, unchanged` count has gone UP.
    **A FAIL is a second identical row** — that is the bug you have
    two of in today's file.
2g. Now ADD a sentence to it and wait again.
    EXPECT: a new row IS written. The guard is about unchanged text,
    not about the field.
    RETURN: whether 2f and 2g both behaved.

── 3. 📋 @report (6.427.0) ─────────────────────────────────────────
3a. Press ⇪D and type a single `@`.
    EXPECT **16 sources** now, and **📋 @report** among them.
3b. ⏎ on it. EXPECT a long list, each row a plain sentence saying what
    that report answers, with `_G.somethingReport()` underneath it.
3c. Type `@report draft` — it narrows. Put the highlight on the draft
    keeper's row and read the pane on the right.
3d. Press **⏎**.
    EXPECT: the panel closes, an alert says "the answer is in the
    Console", and the report is printed there.
    RETURN: confirmation, and tell me whether having to open the
    Console yourself is a nuisance (see Q3).
3e. Press ⇪D, `@report`, highlight any row and press **⌘⏎**.
    EXPECT: "📋 _G.xReport() copied" — the command on your clipboard
    instead of running it.
3f. Scroll the list for any **⚠️** rows.
    RETURN: paste them. Two kinds, and both are findings:
    · "_G.xReport() is NOT published this session" — that module did
      not load, or I renamed something. Those rows deliberately do
      NOT run.
    · "no description written yet" — a report I have not described.
      Those DO run.
    On a healthy Mac I expect none of the first kind.
3g. Read a dozen of the sentences.
    RETURN: any that are WRONG about what that report does. That is
    the one thing I cannot check from here, and a wrong sentence is
    worse than none.

── 4. 🔎 THE SEARCH THAT FOUND NOTHING (6.425.0) ───────────────────
4a. ⇪3, press ⌘F and type `draftkeeper` — spelled with two Es in the
    middle, which your screenshot did not have.
    EXPECT: still no note, because this box searches NAMES, not the
    words inside a note. The empty row now SAYS so: "no note NAMED
    "draftkeeper" — this box searches names and headings, never the
    words inside a note. Press ⌘⇧F to search inside every note."
4b. Press **⌘⇧F** and type `draftkeeper`.
    EXPECT: the note you were looking at, with the line it is on. ⏎
    opens it there.
    RETURN: whether it found it. **That is the answer to "cannot be
    searched" — it could, by a key nothing had ever named.**
4c. 📏 AND THE OTHER HALF, which no release fixes: your filter box in
    the screenshot read **draftkepper**. The note says draftkeeper.
    One letter. The row echoes what you typed now, so the two sit
    side by side.

── 5. MUST STILL WORK — this batch touched the editor, the panic
──    chord, Hamsidian and ⇪D, so this half matters more than 1–4 ──
5a. ⇪⇧1: the nine drawing tools, ⌘Z, ⌘⏎ save, Esc, and Esc-then-reopen
    keeping your marks. ⌘O load a shot. ⌘-drag the title strip.
5b. ⌃⌥⌘⇧Esc with nothing open: it still pauses Hammerspoon and says
    how to come back. ⇪⇧Esc resumes.
5c. ⇪3 and ⇪N: your notes and tabs, ⌘F, ↑↓, ⏎, ⌘N, the ✕ delete, and
    **⌘Z inside a note after a scan lands** (that is 6.323.0 and this
    batch touched that file).
5d. ⇪D: @clip, @ocr, @shots, @vault, @logs all still search. ⏎ on a
    @clip row still PASTES.
5e. ⇪V, ⇪space, ⇪Y, ⇪⇧S all open.
5f. Boot: All green, 79 modules, 111 ⇪ shortcuts.
5g. `_G.installCheck()` — the manifest should match.
    RETURN: anything in 5a–5g that behaves differently from today.

❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN
Q1. **The mouse jumping in full screen is NOT fixed, and I want one
    sentence before I touch it.** It is ⇪1, mouse-follows, doing
    exactly what it was built to do: your Console shows it warping on
    every app activation, and ⌥Tab into a full-screen app on another
    desktop is an activation. Press **⇪1** to turn it off and see
    whether that is the whole of it. Then tell me which you want —
    (a) leave it off, (b) never jump onto a FULL-SCREEN window but
    keep it elsewhere, or (c) never jump when the switch came from
    ⌥Tab. I did not pick one because (b) and (c) each cost you the
    jump in a case you may want it.
Q2. **60 characters and 10 seconds** are still MY numbers for the
    draft keeper — the floor a draft must pass, and the pause before
    it is written. "Start to save as a sentence is typed" may mean
    you want that pause shorter. Say a number; writing on every
    keystroke into OneDrive is the thing that cost you drag-and-drop
    in 6.228.0, so there is a real floor, but 10 s is not it.
Q3. **Should ⏎ on an @report row bring the Console forward?** It
    prints there and says so. Opening it would activate Hammerspoon
    and take your focus for something you did not ask for (6.251.0's
    named price), so I did not. One word and it does.
Q4. **Are any of the @report sentences wrong?** Step 3g. Ninety-seven
    of them are my words for your tools.
Q5. **The work MacBook's name** — `scutil --get ComputerName`. Still
    owed, and it is what gives that Mac a profile of its own.



## 6.423.0

6.423.0 verify with LL — 📋 THE KEYBOARD'S OWN REPORT, ON YOUR
CLIPBOARD (KNOWN GROUND) — this block covers 6.421.0, 6.422.0 AND
6.423.0: they shipped in one archive and share one test plan.
📏 FILED UNDER THE NEWEST ON PURPOSE: tools/build-test-plan.lua reads
one version per heading (`- 6.X.Y verify with LL`), so a batch of
releases goes under its newest and names the others in its own
section headers. A heading listing three versions is silently skipped
by the generator and the steps never reach TESTING.md — which is
6.271.0's whole finding, so it is written down here rather than left
to be rediscovered.
🔎 THIS BATCH CAME OUT OF YOUR OWN QUESTION, which is worth saying
first: you asked whether the Console automatically generates a report
for anything that kills your keyboard and automatically pastes it to
the clipboard. Going to answer it found THREE defects, and all three
are mine.

DO THESE IN ORDER. Each step says what to send back.

── 1. THE ONE THAT PAYS WHEN THE KEYBOARD DIES (6.421.0) ──────────
1a. Nothing to press. If ⇪ ever latches again, you now get the same
    alert with one clause added: "the whole report is on your
    clipboard — ⌘V sends it (whatever you had copied is still in ⇪V)".
    RETURN: ⌘V it into a message to me. That is the whole release —
    you no longer have to remember `_G.stormReport()` while your
    keyboard is misbehaving.
1b. Console: `_G.clipboardWriteReport()`.
    RETURN: the whole block. Its new `hand-off:` line reads "nothing
    has asked — no ⇪ storm and no Secure Input lock this session" on a
    good day. That sentence is deliberate: it says what it MEASURED
    rather than that all is well.
1c. If macOS ever refuses the clipboard, the sentence changes to
    "macOS would not take the clipboard — the report is in the
    Console" and does NOT say ⌘V.
    RETURN: that line if you ever see it.

── 2. THE REPORT I ASKED YOU TO PASTE TWICE AND YOU COULD NOT (6.422.0) ──
2a. Console: `_G.focusDoorReport()`.
    RETURN: the whole block — asked / returned / watching / refused /
    holding.
    WHY IT IS A NEW NAME: `_G.focusReport` was defined in TWO files,
    and core/ loads first, so ⇪Q's focus-mode report overwrote the
    focus door's on every boot since 6.401.0. Every time you typed
    `_G.focusReport()` you got focus mode's block. My 6.401.0 and
    6.402.0 steps both told you to paste the door's — which could not
    be reached.
2b. Console: `_G.focusReport()`.
    EXPECT: focus MODE's block (⇪Q), unchanged. The two are separate
    tools and now have separate names.
    RETURN: nothing unless it looks wrong.

── 3. THE DRAFT KEEPER, CHECKABLE WHERE YOU ARE (6.423.0) ──────────
3a. Click into a text box in Chrome and type two or three sentences —
    more than sixty characters. LEAVE THE CARET THERE.
3b. Press **⇪⇧]** — hold Caps Lock and Shift and press the **]** key,
    right of **[**.
    EXPECT: an alert like "💾 Google Chrome · AXTextArea · 212
    character(s) — THIS WOULD BE KEPT", and the full block in the
    Console.
    RETURN: the alert's wording and the Console block.
    🚨 WHY THIS KEY EXISTS AND WHY MY OLD STEP WAS IMPOSSIBLE:
    `_G.draftCheck()` reads the focused field at the moment it runs,
    so TYPING the command focuses the Console — the only field it can
    ever see is the Console's own box. 6.411.0's step said "leave the
    caret in that box and run, in the Console", which cannot be done.
    A hyper key moves no focus.
3c. Now type `_G.draftCheck()` in the Console instead.
    EXPECT: "💾 That is the Console — press ⇪⇧] with the caret in your
    text box". It names itself rather than reporting an empty field.
    RETURN: confirmation that it says that.
3d. Press ⇪⇧] with the caret in Word, or Terminal, or anything not
    watched.
    EXPECT: "💾 Microsoft Word is NOT watched — nothing here is kept",
    naming the app.
    RETURN: which apps you tried and what each said. That list is what
    tells me whether the watch list is the right one.
3e. Console: `_G.draftKeeperReport()`.
    RETURN: the whole block. Three lines are new — `where :` (the
    unwatched apps you have had the caret in, busiest first), `check :`
    and `last :`.
    🔒 NOTE WHAT IS NOT IN IT: your words. It says the app, the role
    and the character COUNT and never the text.

── 4. MUST STILL WORK — this touched the ⇪ guard and the clipboard,
──    so this half matters more than 1–3 ────────────────────────────
4a. A spread of keys: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space, ⇪V, ⇪/, ⇪⇧S.
4b. ⇪⇧Esc pauses and resumes. ⌃⌥⌘⇧Esc still releases everything.
4c. Copy three things and press ⇪V — your history is unchanged.
4d. ⇪Q engages focus mode; ⇪⇧Q prints focus mode's report.
4e. Boot: All green, 79 modules, the usual ⇪ shortcut count.
4f. `_G.installCheck()` — the manifest should match.
    RETURN: anything in 4a–4f that behaves differently from last week.

❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN
Q1. **Is taking your clipboard on a storm the right trade?** It only
    happens on the way into a state where you cannot type, what it
    overwrites is still in ⇪V, and the alert says so. If you would
    rather it never touched the clipboard, say so and it is one line.
Q2. **Is ⇪⇧] a key you will remember for the draft check?** It is the
    last genuinely free shifted key. Say if you want it somewhere else.
Q3. **Which apps should the draft keeper watch?** Step 3d's list is the
    answer. Right now: Chrome, Chromium, Safari, Edge, Firefox, Brave,
    Arc, Vivaldi, Opera and Outlook.
Q4. **Sixty characters and ten seconds** are still MY numbers, not
    yours — the floor a draft has to pass and the pause before it is
    written. You escalated the feature without answering that, and I
    will not leave it in a settings line for you to type. Say whether
    anything is being kept that you did not want, or anything missed.
Q5. **The work MacBook's name** — `scutil --get ComputerName`. Still
    owed, and it is what gives that Mac a profile of its own.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
