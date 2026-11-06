# TESTING — how to score release 6.413.0

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



## 6.410.0

6.410.0 verify with LL — 🪪 THE FIRST ⇪⇧. OF A SESSION (KNOWN GROUND)
WHAT CHANGED: when macOS refuses to put the Jug Player on screen, the
key tries once more a beat later instead of giving up — and the two
library loads that made that beat expensive are paid off the keypress.
🔎 THIS IS FROM YOUR OWN CONSOLE, four seconds into the 06:17 boot:
`-- Loading extension: mouse` · `⚠️ Jug Player: macOS raised while
ordering the window on screen` · `-- Loading extension: notify` ·
`⚠️ Jug Player: macOS would not put the player on screen`. The first
press of a session was loading two of Hammerspoon's libraries on the
main thread and then asking AppKit to order a window on screen in the
same turn. **6.348.0 fixed exactly this in the Mug Player and named
the Jug Player as not swept.** It is swept now.

A. THE HEADLINE — and the case that matters is the FIRST press.
A1. Reload Hammerspoon (⌘⌃R). Wait ten seconds, pressing nothing.
A2. Press **⇪⇧.** — hold Caps Lock and Shift, press the full stop.
    EXPECT: the player card appears. **A FAIL is nothing happening.**
A3. Watch the Console while you do A2. EXPECT NO
    `-- Loading extension: mouse` or `notify` line at that moment —
    they should have loaded a few seconds after boot instead.
A4. Close and open it several times. EXPECT: every time.

B. THE RETRY, WHICH YOU MAY NEVER SEE.
B1. If a press seems to do nothing and the card appears a moment
    later, that IS the retry, and it is normal.
B2. If you get "macOS would not put the player on screen, **twice**",
    paste it: two refusals in a row is a real no and something bigger
    than a busy turn.

C. PASTE BACK.
C1. `_G.musicReport()` — the `opens :` line, and the new `↳ retry :`
    line under it when anything was refused. Three facts, never summed:
    came up on the retry · refused twice · could not arm a retry.

D. MUST STILL WORK.
D1. Drop an mp3 on the card — it queues and plays.
D2. space, ↑↓, ⏎, ⌘1–9, ← →, ⌫, the ✕ on a history row.
D3. Drag the card by its title strip; close and reopen — it is where
    you left it.
D4. ⇪⇧, the Mug Player still opens (different module, same shape).



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
