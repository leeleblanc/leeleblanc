# TESTING — how to score release 6.414.0

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

## 6.414.0

6.414.0 verify with LL — ✂️ THE CROP TOOL (KNOWN GROUND)
WHAT CHANGED: the screenshot editor can crop. Drag a rectangle,
everything outside it goes dim so you can SEE what would be thrown
away, and ⏎ crops to it.
🔑 WHY IT IS SMALL: the rectangle is an ordinary mark, like an oval or
a highlight — so dragging it, moving it, resizing it by its corner and
⌘Z all worked the day it was written. What this release had to build is
the dimming, what committing does to everything else on the shot, and
what it refuses.

A. THE HEADLINE — about a minute.
A1. Take a screenshot (⇪4 will do), then **⇪⇧1** to open the editor on
    it.
A2. In the left-hand column of tools, at the bottom, there is a new
    **✂︎ Crop**. Click it, or press the **K** key.
    EXPECT: the button lights up like any other tool.
A3. Drag a rectangle over the part you want to KEEP.
    EXPECT: everything OUTSIDE your rectangle goes dark, the rectangle
    has a white dashed border, and a small black label on it reads the
    size and "⏎ crops · ⌫ removes".
    **A FAIL is nothing being dimmed** — then I have the drawing wrong
    and I want to know.
A4. Press **⏎** (Return).
    EXPECT: the shot is now just your rectangle, and the WINDOW shrinks
    to fit it rather than stretching the smaller picture to fill the
    old window.
A5. Press **⌘Z**.
    EXPECT: the whole shot comes back, at its old size, with the
    rectangle back on it. Nothing was lost.
A6. Press ⏎ again, then **⌘⏎** to save.
    EXPECT: a "… (edited).png" beside the original holding the CROPPED
    picture, and it is on your clipboard — ⌘V somewhere to check.

B. THE ONE THAT MATTERS MOST — your marks must move with the picture.
B1. Open the editor on a fresh shot. Draw an **arrow** pointing at
    something, and add a **text box** beside it.
B2. Now press K and drag a rectangle that INCLUDES both of them but
    cuts a good margin off the top and the left.
B3. Press ⏎.
    EXPECT: the arrow is still pointing at exactly the same thing, and
    the text box is still beside it.
    **A FAIL is a mark that has slid** — if the arrow now points at
    empty space, stop and tell me, because that is the one failure in
    this release that quietly ruins a shot.
B4. ⌘Z. EXPECT: everything back where it was.

C. THE REFUSALS — each says what is wrong, in words.
C1. Press K and drag a TINY rectangle (a few pixels), then ⏎.
    EXPECT: nothing is cropped and an alert reads "✂️ that rectangle is
    6 × 4 — a crop is at least 32 × 32", with your actual numbers in
    it. The size being in the sentence is deliberate: it is the whole
    diagnosis of a mis-drag.
C2. Press K and drag a rectangle over the WHOLE shot, corner to corner,
    then ⏎.
    EXPECT: "✂️ that is the whole shot — there is nothing to crop
    away". It refuses rather than pretending to work.
C3. Press the **✂︎ Crop to it** button in the RIGHT-hand column without
    drawing a rectangle at all.
    EXPECT: "✂️ drag a rectangle with the Crop tool (K) first" — a
    sentence, not a button that does nothing.

D. THE EDGES WORTH ONE MINUTE EACH.
D1. Draw a rectangle, then draw a SECOND one somewhere else.
    EXPECT: only ONE rectangle, the new one. There is deliberately
    never more than one — two would need a rule about which ⏎ meant.
D2. Press ⌘Z twice after D1. EXPECT: the first ⌘Z takes the new
    rectangle off and the second brings the old one back.
D3. Draw a rectangle and press **⌫** instead of ⏎.
    EXPECT: the rectangle goes and nothing is cropped.
D4. Draw a rectangle and press **Esc** to close the editor. Reopen the
    SAME shot with ⇪⇧1.
    EXPECT: your rectangle is still there, like any other mark (6.189.0
    keeps the work across a close).
D5. 🔒 Draw a rectangle and press **⌘⏎** to save WITHOUT cropping.
    EXPECT: the saved file is the UNCROPPED shot with NO dim overlay
    and NO label burned into it. If a saved file ever has the dark
    border in it, tell me at once — that one cannot be undone from the
    file.
D6. Drag the rectangle by its middle, and drag its bottom-right dot to
    resize it, before pressing ⏎. Both should work like any other mark.

E. MUST STILL WORK — this touched the window that draws every mark, so
   this half matters more than A.
E1. The nine other tools, one at a time: B blur · T text · A arrow ·
    L line · O oval · H highlight · C counter · S spotlight ·
    M magnifier.
E2. ⌘Z after each. ⌘-click a mark to select it. ⌫ to delete one.
E3. ⌘A add capture · ⌘D delayed · ⌘F full screen · ⌘O load a shot ·
    ⌘V paste an image.
E4. ⌘-drag the title strip to move the window.
E5. 🚨 **⌘O specifically**, because it is the other thing that resizes
    the canvas: load a prior shot, check the canvas GROWS and your
    existing marks have not moved, then ⌘Z.

F. PASTE BACK, PASS OR FAIL.
F1. `_G.screenshotEditorReport()` — there is a new `crop    :` line:
      crop    : 3 asked · 1 cropped · 2 refused
      ↳ last: 1280 × 720 kept out of 2560 × 1440 (the page said so)
      ↳ last refusal: that rectangle is 6 × 4 — a crop is at least 32 × 32
      ↳ a crop is at least 32 × 32, and never the whole shot
    Paste the whole block. "never asked this session" is the healthy
    reading before you have used it, and it is deliberately different
    wording from "0 cropped".

G. A JUDGEMENT ONLY YOU CAN MAKE.
G1. **32 pixels on a side is MY floor.** It is there so a stray click
    cannot crop a 4K screenshot down to nothing — but if you ever want
    a genuinely tiny crop it is in the way. One number:
    `settings = { screenshot_editor = { cropMin = 8 } }`. Say what you
    want and I will change the default rather than leave you a line to
    type.
G2. **Is the dim the right darkness?** It is 72% black. Too dark to see
    what you are cutting off, or not dark enough to tell the two apart?
    `cropDim`, and the same offer applies.
G3. **Should ⏎ ask first?** It does not — it crops, and ⌘Z puts it
    back. I chose that because every other mark in this editor acts
    immediately and the dim already shows you the outcome. Say if you
    would rather it confirmed.
G4. 🔨 Nothing was broken and nothing was lost — this is a tool you
    asked for and did not have. If it ever loses a mark (step B) that
    is a different matter and I want it named.



## 6.413.0

6.413.0 verify with LL — 🩺 DO THE BIG TOOLS ANSWER? (KNOWN GROUND)
WHAT CHANGED: a new command, and a block that prints itself a few
seconds after every boot. One row per tool — the five you named, plus
the three that make all five dead when they are wrong.
🔑 WHY IT IS NOT THE INSTALL CHECK, since you now have two: 6.399.0
asks whether the FILES are on disk. This asks whether the TOOLS
ANSWER — and every file can be present and correct while a tap macOS
switched off, a dictionary that did not load, or a folder OneDrive
took away makes the thing you pressed do nothing. Two questions; a
report that answered both could not say which half failed.

A. THE HEADLINE — reload, wait about ten seconds, read the Console.
A1. EXPECT a block like this, and on a healthy Mac it is BORING:
      🩺 SELF TEST — do the big tools answer?
         ✅ Accessibility  granted
         ✅ Secure Input   clear
         ✅ ⇪ shortcuts    111 bound, no key claimed twice
         ✅ Screenshots    ⇪4's folder is there — /Users/…/2026 Screenshots
         ✅ Snippets       1926 loaded · the tap is running
         ✅ Autocorrect    the tap is running · _G.autocorrectReport() …
         ✅ Draft keeper   watching every 5s while one of 10 app(s) …
         ✅ Right-click    ⇪⇧F is bound · it aims at what the front app …
         ✅ every tool answered
    **PASTE THE WHOLE BLOCK.** It is the first build on which that
    question has an answer, and I want to see what your Mac says on a
    good day.
A2. Console: `_G.selfTest()` — the same block, whenever you want it.
A3. Read the ⇪ shortcuts row. EXPECT a real number and "no key claimed
    twice". **A ⚠️ there is a key two tools are fighting over** and I
    want it immediately.
A4. Read the Snippets row. EXPECT a count in the thousands. If it says
    NO snippets are loaded, that is a real finding and the row names
    the command that loads them.

B. THE FOUR STATES, so a row is readable without me.
B1. **✅** it answered and it is healthy.
B2. **⚠️** it answered and the answer is a fault — the row says what to
    do about it. Paste any you get.
B3. **⏳** switched off on purpose. NOT a fault, and the summary line
    says how many.
B4. **❔** the CHECK ITSELF could not be asked — the module did not
    load, or asking it raised. **Never a pass.** This is the block you
    will read INSTEAD of testing, so "I could not ask" must never
    print as "it is fine". Paste any ❔ row.

C. MUST STILL WORK — this added a module, so this half matters more.
C1. Boot: All green, **79 modules** (was 78), and the same ⇪ shortcut
    count as before. A different shortcut count is a finding: this
    module binds no key at all.
C2. `_G.installCheck()` — still answers the OTHER question, and should
    read 94 runtime files now.
C3. A spread of keys: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space, ⇪V, ⇪/.
C4. ⇪/ and search `self test` — the 🩺 card is there, under CONFIG.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. **Is the block at boot welcome, or noise?** I deliberately broke
    this project's own rule that a new instrument should be silent
    when healthy, because you asked for checks AFTER THE FIRST RUN and
    the value is knowing the tools DID answer on the mornings before
    the one when they do not. `settings = { self_test = { sayBoot =
    false } }` makes it quiet and leaves the command. Say the word and
    I change the default.
D2. **Which other tools should be on it?** It checks the five you
    named plus Accessibility, Secure Input and the ⇪ registry. The
    obvious candidates I did NOT add: Hamsidian's notes folder, the
    clipboard poll, the backup, OneDrive. Name any and they are one
    row each.
D3. 📏 NAMED: it never DOES the thing. It does not take a screenshot,
    type a snippet or write a file — a self-test that acts can break
    the Mac it is reassuring you about. So it can tell you a tap is
    running and cannot tell you a snippet lands in Word.



## 6.412.0

6.412.0 verify with LL — 📅 THE DATES (KNOWN GROUND)
WHAT CHANGED: ⇪⇧0 copies a four-digit year, and the autocorrect report
can finally say whether the expansion fired.
🚨 AND THE SECOND HALF OF YOUR ASK ALREADY WORKED — the instrument was
lying. 6.371.0 built `11-06-26 ` → `11-06-2026 ` and the line in the
report that counts them was written FORTY-FOUR LINES above the two
counters it reads, so it answered "no two-digit date typed this
session" on every Mac, for ever, whatever happened. The expansion was
alive and the only thing that could say so said no.

A. THE HEADLINE — twenty seconds, and do A1 first.
A1. In Chrome or Word, type `11-06-26` and then a **space**.
    EXPECT: `11-06-2026 `. Then type `11/06/26` and a space.
    EXPECT: `11/06/2026 `. **A FAIL is it staying as typed** — and if
    so, go to B1, because the report can now tell us why.
A2. Press **⇪⇧0** (hold Caps Lock and Shift, press zero). Click any
    date.
    EXPECT: `11-27-2026` on the clipboard — ⌘V it somewhere — and the
    alert says the same with the weekday beside it.
    **A FAIL is `11-27-26`**, the shape you reported.
A3. Press **C** with a date highlighted instead of clicking.
    EXPECT: the same four-digit shape.
A4. ⇪/ and search `calendar`. EXPECT the click row to read "A date
    COPIES it as 08-07-2026" — that example is BUILT from the format
    now, so a card cannot advertise a shape the tool does not produce.

B. THE INSTRUMENT THAT WAS LYING.
B1. Console: `_G.autocorrectReport()` and find the `date :` line.
    After A1 it should read something like `2 two-digit year(s)
    written out in full · last: 11-06-26 → 11-06-2026`.
    **It used to say "no two-digit date typed this session" there on
    every Mac whatever you had typed.** Paste the line.
B2. If it STILL says none after A1 worked, that is a new finding and I
    want the whole report.

C. MUST STILL WORK — the date rule rewrites text you typed, so these
   are the ones that matter.
C1. Type `10-20-2026 `. EXPECT: unchanged — the year is already right.
C2. Type `1.2.26 ` and `2026 ` and `abc26 `. EXPECT: all unchanged.
C3. Type `11-06/26 `. EXPECT: unchanged — mismatched separators are a
    part number, not a date.
C4. `teh ` still becomes `the `; ⇪Z still undoes a correction.
C5. In the calendar: ←→ a day, ↑↓ a week, [ ] a month, T back to
    today, R for the date report, Esc. The panel is unchanged.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. You gave two shapes — `11-27-2026` or `11/27/2026`. I shipped
    dashes, because that is what the panel already used and what your
    expansion tool produces. Slashes are one line:
    `settings = { mini_calendar = { copyFormat = "%m/%d/%Y" } }` —
    say which and I will change the default rather than leave you a
    line to type.
D2. 🔨 Nothing broke and nothing was lost. The calendar handed you a
    shape you did not want, and the report told us a working rule was
    dead. My reading is that the second is the real defect here.



## 6.411.0

6.411.0 verify with LL — 💾 THE DRAFT KEEPER, AND HOW YOU KNOW
(NEW GROUND — expect a round)
WHAT CHANGED: two things, and the second is the one you asked for.
🔎 FIRST, WHY IT PROBABLY WAS NOT WORKING, and it is readable rather
than guessed: **six of the seven apps it watches are Chromium**, and
Chromium does not build its accessibility tree until something asks
for it. Until it is asked, macOS answers about the window's chrome and
the text box inside the page is not there AT ALL — so the one module
whose whole job is reading that box read nothing, in exactly the apps
it was built for, and recorded "nothing is focused" about a field you
were typing into. It asks now, once per app per session.
🚨 NEW GROUND, SAID UP FRONT: whether YOUR build of Chrome honours
that request is a fact about your Mac that nothing here can read. So
it asks, records the answer, and the report says which attribute each
app accepted — or that the app refused, which is the app saying no
rather than a fault here.

A. THE HEADLINE — this is the answer to "How do I know?".
A1. Click into a text box in Chrome you can type a paragraph in — a
    Gmail or Outlook compose window, an Asana comment, a long form.
    Type two or three sentences (more than sixty characters).
A2. **Leave the caret in that box** and run, in the Console:
    `_G.draftCheck()`
    EXPECT:
      💾 DRAFT KEEPER — what it can see RIGHT NOW
         app    : Google Chrome
         tree   : asked, and Google Chrome accepted AXManualAccessibility
         field  : AXTextArea — a AXTextArea
         holds  : 212 character(s)  (the text itself is never printed)
         verdict: ✅ THIS WOULD BE KEPT — the first draft of this field
                  after 10 s of not typing. …
         cost   : 3 ms to ask
    **PASTE THAT BLOCK.** Every line answers a different half of your
    question, and this is the first build on which any of it can be
    asked about the field you are actually in.
A3. **A FAIL is `field : ⚠️ NOTHING IS FOCUSED`** with the caret
    genuinely in a text box. That is the finding — paste it.
A4. **A ⚠️ ASKED AND REFUSED on the `tree` line** is the other
    possible answer: that app would not build its accessibility tree,
    so the text inside its pages cannot be read here at all. Paste it;
    it decides whether this is buildable in that app.
A5. 🔒 Note what the block does NOT contain: your words. The character
    count is the answer — a diagnostic that puts a half-written email
    in the Console is a worse tool than the one that said nothing.

B. THEN LET IT ACTUALLY KEEP ONE.
B1. With that paragraph typed, STOP TYPING and wait about fifteen
    seconds, then click into a different tab or field.
B2. Console: `_G.draftKeeperReport()`.
    EXPECT `kept : 1 draft(s) this session · 1 row(s) written` and a
    `↳ last:` line naming the app and the character count.
    **PASTE IT.** The new `tree :` line near the top names every app
    that has been asked and what it answered.
B3. Press **⇪D**, type `@draft`, press ⏎. EXPECT your paragraph listed,
    and ⏎ on the row copies it back.

C. MUST STILL WORK — this reads what you type into other people's
   forms, so this half matters more than A.
C1. 🚨 **DOES THE MAC FEEL NORMAL?** Use Chrome and Outlook heavily for
    an hour. Typing must not feel heavier, the pointer must not
    stutter, drag and drop must still work. Read `_G.draftKeeperReport()`'s
    `cost :` line — `worst` is the number that matters. If it ever
    carries a ⚠️ about the budget, it has backed off by itself and you
    will have had one alert; paste it.
C2. 🔒 Click into a **password field** — a login page, 1Password's
    unlock — type something, wait, click away. Then
    `_G.draftKeeperReport()`: EXPECT `refused: 1 password field(s)`
    and **nothing from that field anywhere in the rows list**. A
    password in that list is a stop-and-tell-me-at-once.
C3. Type a long paragraph in **Word**, or Terminal, or Hamsidian.
    EXPECT nothing kept — the watch list is browsers and Outlook, by
    your own scope.
C4. ⇪⇧Esc to pause, type a paragraph in Chrome, ⇪⇧Esc again. EXPECT
    nothing was kept while paused.
C5. `_G.draftForget(n)` and `_G.draftForgetAll()` still work.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. **If A4 says REFUSED**, tell me which app. That is the app
    declining, and the next step there is a different mechanism rather
    than a tweak to this one.
D2. Sixty characters and ten seconds are still MY numbers (you
    escalated the feature without answering that question). If the
    file fills with things you did not want kept, sixty goes up; if a
    paragraph you lost was not kept, ten seconds comes down.
D3. 🔨 While this was not working, was the Mac unusable, or did this
    one tool just not do its job? My reading is the second — it is a
    watcher, nothing else noticed — but the tag is yours, and the
    honest pass count on D3 is now 2.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
