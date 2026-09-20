# TESTING — how to score release 6.272.0

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

## 6.272.0

6.272.0 verify with LL — 🗑 FORGET A TRACK FROM THE HISTORY (KNOWN GROUND)
WHAT CHANGED: you could not remove anything from the 🕘 history list —
⌫ took a track out of the QUEUE, and clicking a history row PLAYED it.
Every history row now has a ✕ on its right. It forgets the row; it never
touches the file.
WHY IT MATTERS: you asked whether this existed and did not want to have
to ask again. It did not. It does now.

A. THE HEADLINE.
A1. Press ⇪⇧pad. to open the player. Play two or three tracks so the
    🕘 history at the bottom has rows in it.
    EXPECT: a history section with one row per file.
A2. Look at the right-hand end of any history row.
    EXPECT: a ✕, visible WITHOUT hovering (dim grey), brightening when
    the pointer is over it.
A3. Click the ✕ on a history row.
    EXPECT: that row disappears from the list, AND NOTHING STARTS
    PLAYING. If the track begins playing, that is a FAIL and the most
    important one in this release — tell me immediately.
A4. Check the track that WAS playing is still playing, and the queue
    above is unchanged.
    EXPECT: the ✕ touched the history list and nothing else.
A5. Close the card (⇪⇧pad.) and reopen it.
    EXPECT: the row you forgot is still gone — it was saved, not just
    hidden.
A6. In Finder, confirm the actual audio FILE is still on disk.
    EXPECT: it is. This forgets a row, never a file.

B. MUST STILL WORK.
B1. Click a history row on its NAME (not the ✕).
    EXPECT: it plays again, exactly as before.
B2. Select a row in the QUEUE with ↑↓ and press ⌫.
    EXPECT: it leaves the queue. This is the old behaviour and must be
    unchanged.
B3. Drop two or three files on the card.
    EXPECT: they queue and the first plays.
B4. Press space, then → and ←.
    EXPECT: pause/resume, then seek forward and back 5 s.

C. PASTE BACK, PASS OR FAIL.
C1. Console: `_G.musicReport()` — the whole block. The new "forgot :"
    line counts the rows you removed this session.
C2. After step A3, the "history :" line should show one fewer track.

D. THE BULK DOORS, worth one try each.
D1. Console: `_G.musicForgetHistory("/full/path/to/a/track.mp3")`
    EXPECT: it names how many rows it removed, or says there was no row
    for that path.
D2. Console: `_G.musicClearHistory()`
    EXPECT: the list empties, and the message says the files themselves
    are untouched. Only run this if you do not mind losing the list.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Is a ✕ per row the right control, or would you rather select a
    history row and press ⌫ the way the queue works? The second is a
    bigger change — the history rows are not keyboard-selectable today
    — so I did the simpler one. "✕ is fine" or "I want ⌫" decides it.



## 6.271.0

6.271.0 verify with LL — 🧪 THE TEST PLAN IS IN THE ARCHIVE (KNOWN GROUND)
WHAT CHANGED: there is a TESTING.md at the root of the archive with the
steps for each release it carries. You asked for it; the honest finding
is that I had been writing these for every release since June and filing
them in CLAUDE.md, which is not in the package — so none ever reached
you and you were left inventing your own testing off the cheat sheet.
WHY IT MATTERS: it is the thing that turns "that worked" into data.

A. THE HEADLINE.
A1. Unpack the archive and list what is at its root.
    EXPECT: TESTING.md is there, beside GUIDE.md and INSTALL.md.
A2. Open TESTING.md. Read the first line.
    EXPECT: "# TESTING — how to score release 6.271.0" — THIS version.
    Any older number is a FAIL and means the plan describes a build you
    are not holding.
A3. Scroll to the "How to report back" section.
    EXPECT: it names three answers — PASS, FAIL, BLOCKED — and says to
    paste the Console reports whether or not anything failed.
A4. Count the release sections (## 6.2xx.0 headings).
    EXPECT: four, newest first, starting with 6.271.0.
A5. Read the 6.270.0 section.
    EXPECT: numbered steps with an EXPECT on each, grouped A/B/C/D —
    not the paragraphs the older sections are still written in.

B. THE REAL TEST OF THIS RELEASE IS THE NEXT ONE. There is nothing to
   exercise in the config: no key, no panel, no behaviour changed.
B1. Run the 6.270.0 section of TESTING.md end to end and send me the
    results in its format.
    EXPECT: you get through it without having to ask me what a step
    means. If a step is ambiguous, THAT is the bug in this release —
    tell me which number and what was unclear.
B2. Then the 6.269.0 section the same way.

C. PASTE BACK.
C1. Nothing new. The reports the two sections above ask for are the
    whole of it — which is the point: this release adds instructions,
    not instruments.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Is four releases per plan the right depth, or do you want only the
    newest? "four is right" · "just the newest" · "all of them".
D2. Are the steps at the right grain? Too coarse and they miss things;
    too fine and you will not run them. Tell me which way to move, on
    the 6.270.0 section specifically, since that is the one with the
    most steps.
D3. Anything you routinely check that I have NOT asked for — that is
    the most valuable answer here, because it is a test I do not know
    to write.



## 6.270.0

6.270.0 verify with LL — 🖼 THE EDITOR'S TWO RAILS (KNOWN GROUND)
WHAT CHANGED: the screenshot editor's eighteen buttons were all in one
wrapping strip across the top. Nine drawing tools now run down the LEFT
edge, six capture/edit actions down the RIGHT, and the window is wider
by exactly the two rails so the picture is not squeezed to make room.
WHY IT MATTERS: this is the thing you asked for three times and were
right about every time — it had never been built.

A. THE HEADLINE. If any step in A fails, stop and tell me; the rest
   tells me nothing until this works.
A1. Press ⇪⇧1 on any screenshot (or ⌥⏎ on a row in ⇪space @shots).
    EXPECT: the editor opens with a column of buttons down the LEFT
    edge AND a column down the RIGHT edge.
A2. Read the LEFT column top to bottom.
    EXPECT exactly nine, in this order, under a "TOOLS" label: Blur,
    Text, Arrow, Line, Oval, Highlight, Counter, Spotlight, Magnifier.
A3. Read the RIGHT column top to bottom.
    EXPECT six, under "ADD" then "EDIT": Paste image, Add capture,
    Delayed 5s, Full screen, Load shot, then Undo.
A4. Read the strip across the TOP.
    EXPECT four things only: 🖌 Edit, Save & copy, Small JPEG, Cancel.
    A drawing tool still up there is a FAIL — say which one.
A5. Look at where the screenshot itself is drawn.
    EXPECT: neither rail overlaps the picture, and the picture is not
    cropped. The buttons sit BESIDE the shot, never on top of it.
A6. Close it, then open the editor on a much SMALLER screenshot.
    EXPECT: same nine and six buttons, none cut off at the bottom, and
    still no rail over the picture.

B. MUST STILL WORK. Not new — but this release moved every button, so
   it is the most likely thing to have broken.
B1. Press the letters B, T, A, L, O, H, C, S, M one at a time.
    EXPECT: the armed tool changes each time and the matching button
    in the LEFT rail highlights.
B2. Drag on the picture with Blur armed. EXPECT: the area blurs.
B3. Press T, click the picture, type a word, press ⏎.
    EXPECT: the text lands where you clicked.
B4. Hold ⌘ and click that text box. EXPECT: its words open for editing.
B5. Press ⌘Z. EXPECT: the last mark is undone.
B6. Hold ⌘ and drag the TOP strip. EXPECT: the window moves.
B7. Hold ⌘ and drag the PICTURE. EXPECT: the window does NOT move
    (⌘ on the picture means "edit this mark" — 6.221.0).
B8. Press ⌘⏎. EXPECT: it saves "… (edited).png" beside the original
    and puts it on the clipboard; ⌘V pastes it.

C. PASTE THESE BACK, pass or fail. A report from a working Mac is what
   tells me what a broken one is missing.
C1. Console: `_G.screenshotEditorReport()` — the whole block. The new
    "layout :" line names the rail width and what the window reserves.
C2. Console: `_G.screenReport()` — which monitor placed the last panel.

D. A JUDGEMENT ONLY YOU CAN MAKE, and the one number I could not
   determine from here.
D1. Is 136 points the right rail width on YOUR display? The longest
    labels are "🖍 Highlight", "📸 Add capture" and "⏲ Delayed 5s".
    Answer one of: "right" · "too narrow, <label> is cut off" · "too
    wide, it steals room from the shot". If it is wrong it is a number
    and not a release — I will move the default rather than hand you
    `settings = { screenshot_editor = { railW = 160 } }` to type.
D2. On a very small screenshot the window is now taller than the
    picture needs, deliberately, so the nine tools fit. Is that
    annoying enough to change? "fine" or "annoying" is the whole answer.



## 6.269.0

6.269.0 verify with LL — 🔗 THE ANCHORS CARD HAS ROWS (KNOWN GROUND)
WHAT CHANGED: ⇪⇧U's card on the cheat sheet has been a heading over
empty space since 6.180.0 — its eight rows were written under the wrong
key and the loader silently turned them into nothing. They are back. And
a card that ever registers with no rows now says so out loud instead of
drawing a blank space.
WHY IT MATTERS: it was invisible for eighty-nine releases and only
surfaced because you asked me to read the cheat sheet.

A. THE HEADLINE.
A1. Press ⇪/ and type `anchors` in the search box.
    EXPECT: the 🔗 ANCHORS card, with EIGHT rows under it.
A2. Read the eight key-column entries.
    EXPECT: ⇪⇧U · again · ⏎ · new · pick · in a note · moved · Console.
    On every release you have installed, that card had none of these.
A3. Open RESOLVED-FEATURE-REQUESTS.txt at the root of the archive and
    search for "Link the front document".
    EXPECT: it is there. It never has been — the same bug hid those
    rows from that file too, so this is a second, independent proof.

B. THE NEW INSTRUMENT.
B1. Console: `_G.cheatSheetReport()`.
    EXPECT four lines, and this is the shape of a healthy answer:
      cards  : <N> card(s) · <N> row(s) from 71 module(s)
      empty  : none — every card that should have rows has them
      listed : 1 card(s) are a heading alone ON PURPOSE … Copy-on-Select
      faults : none — no module registered a card with no rows
B2. Check that "empty" reads **none** and "faults" reads **none**.
    A number on either is a real finding — paste it.
    The "listed" line is NOT a warning: Copy-on-Select has no cheat
    sheet of its own and is listed so the tool appears at all.

C. MUST STILL WORK.
C1. Press ⇪⇧U with a document or browser tab in front.
    EXPECT: it identifies what is in front and offers notes that
    mention it, exactly as before. Nothing about ⇪⇧U's behaviour moved
    — only its cheat-sheet card.
C2. Press ⇪/ and search for a punctuation key, e.g. `\`.
    EXPECT: the sheet filters (6.250.0 — still working).

D. PASTE BACK, pass or fail.
D1. `_G.cheatSheetReport()` — the whole block.
D2. `_G.anchorsReport()` — the "tasks :" line should say callbacks
    stepped off a held timer, with no ⚠️.

E. FOR YOUR EYES, not a test: one of the eight rows now visible says
   the link is "plain Markdown under '## Linked' — Obsidian opens it".
   That is the Obsidian wording you asked about, and fixing this card
   has SURFACED it rather than changed it. Rewording those strings is
   your call and its own release — say the word.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
