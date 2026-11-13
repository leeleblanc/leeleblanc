# TESTING — how to score release 6.419.0

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

## 6.419.0

6.419.0 verify with LL — 📋 ⏎ ON A CLIPBOARD ROW PASTES (KNOWN GROUND)
WHAT CHANGED: pressing Return on a clipboard row in ⇪D now PASTES it
where you were typing. It has only ever copied.
🔎 AND THE ALERT YOU PHOTOGRAPHED IS THE DIAGNOSIS — "the app you were
in could not be brought back" is not the message for something going
wrong, it is the message for the paste REFUSING, and it was refusing
every single time. ⇪D takes the keyboard WITHOUT bringing Hammerspoon
to the front — deliberately, so the panel does not yank you out of your
app. So when the paste asked "am I still the front app?", the honest
answer was always no, and it read that as "you have moved on
yourself" and stood down. 6.402.0 built the paste correctly and proved
it against the EDIT window, which DOES come to the front. The one door
it could never work on is the one it was written for.

A. THE HEADLINE — thirty seconds, and it is the whole release.
A1. Click into a text box you can type in — a Chrome field, a Word
    document, this one. Leave the caret there.
A2. Press ⇪V (or ⇪D and type `@clip`). Press **Return on any row**.
    EXPECT: the panel closes and the text appears AT THE CARET.
    **A FAIL is the alert you photographed** — "📋 It is on your
    clipboard — ⌘V pastes it / the app you were in could not be brought
    back". That sentence should now be impossible on an ordinary press.
A3. Do it again on the FIRST row, which is the one you reported in
    6.402.0. EXPECT: it pastes. (Row one is whatever is already on your
    clipboard, so a copy there changes nothing you can see — which is
    why it was the row that looked deadest.)
A4. Three or four more rows, in two different apps.

B. THE ONES THAT PROTECT YOU — these matter more than A.
B1. Press ⇪V and then press **Escape**.
    EXPECT: nothing is pasted anywhere.
B2. Press ⇪V, then — before pressing Return — **click into a different
    app yourself**. Then come back and press Return on a row.
    EXPECT: it does NOT paste. You get "📋 It is on your clipboard —
    ⌘V pastes it / you had already moved on". That is the guard still
    doing its job: a ⌘V posted into something you moved to yourself
    could type into a document you did not mean to touch.
    **A FAIL here is it pasting anyway**, and it is the serious one —
    tell me at once.
B3. ⏎ on a **non-clipboard** row — an @ocr reading, an @shots path, an
    @vault note. EXPECT: it still only COPIES and says "📋 Copied".
    A file path typed into your document is not what Return means
    there, and that line has not moved.

C. MUST STILL WORK — this touched the door every panel uses to give the
   focus back, so this half matters more than A.
C1. ⇪⇧V, Return on a row to open the edit window, change something and
    save (or Escape). EXPECT: you are back in your text box with the
    caret in it, as in 6.401.0. That window ACTIVATES, so it takes the
    other path through the same door — if the focus stops coming back
    there, this release did it.
C2. ⇪⇧W the documents list, and ⇪⇧O — same thing.
C3. ⇪D still searches everything; ↑↓ walk, the preview pane follows.
C4. ⌘⏎ on a row still copies its path; ⌥⏎ still opens it.
C5. ⌘⌘ still opens the clipboard history.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.focusReport()` — there is a NEW line and it is the artefact:
      already : 4 — the app was ALREADY in front, so there was nothing
                to bring back. A success, and what a non-activating
                panel (⇪D) does every time.
    **That number climbing is the release working.** Before today every
    one of those presses was counted as "moved on" and refused.
D2. `_G.unifiedSearchReport()` — the `⏎ clip :` line:
      ⏎ clip : 4 picked · 4 ⌘V posted · 0 left on the clipboard only
    If "left on the clipboard only" is still climbing on ordinary
    presses, paste both reports — that would mean a second cause I have
    not found, and the two lines together name which half.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. `settings = { unified_search = { pasteOnPick = false } }` goes back
    to copy-only, if a paste ever lands somewhere you did not want.
E2. Should ⏎ paste for OTHER sources too — @ocr readings, say? It is
    deliberately clipboard-only (B3). Your call, and it is one line.
E3. 🔨 This one is yours to tag: nothing broke and nothing was lost —
    the text was always on the clipboard and ⌘V always worked. What it
    cost is the feature you asked for not existing for eleven releases
    while reporting itself as working. My reading is that it degraded
    gracefully and said something true but useless; the pass count is 2.



## 6.418.0

6.418.0 verify with LL — ℹ️ WHICH MAC IS THIS? (KNOWN GROUND)
WHAT CHANGED: if a Mac has no profile of its own, the boot line now
SAYS so and names the machine. On the Air you should see nothing new.
🚨 AND THIS IS THE ANSWER TO YOUR QUESTION about the work MacBook, with
the uncomfortable half first. Every path in this config degrades and
says so, and the whole gate runs on Linux with the Mac API stubbed out
— which IS a Mac with nothing — so no-OneDrive, no-blueutil,
no-Accessibility and no-permission are exercised on every release.
What is NOT true is that anything has ever been verified ON that Mac.
And there is a concrete hole: the work-Mac entry in the profile table
is **a name I invented** — "Lees-Work-MacBook" — over a comment saying
"put your work machine's name here". If your work Mac is called
anything else, it silently takes the DEFAULT and gets none of its
tuning.

A. THE HEADLINE — on the Air, ten seconds.
A1. Reload. Read the 🧭 line and the line under it.
    EXPECT: exactly what you see today — "All green…" and NOTHING about
    profiles. The Air matches its own profile, so this release is
    invisible there. **A FAIL is an ℹ️ line on the Air**, which would
    mean its profile stopped matching.

B. ON THE WORK MACBOOK — this is the one that matters.
B1. Install and reload. Read the 🧭 block.
    EXPECT, if that Mac has no profile:
      ℹ️ No profile for "<its name>" — running the DEFAULT. Nothing is
         broken; this Mac has no tuning of its own.
         this build knows: Lees-MacBook-Air · Lees-Work-MacBook
B2. **PASTE THAT LINE.** The name in the quotes is the one thing I
    cannot get from here, and it is all I need to give that Mac a real
    profile. `scutil --get ComputerName` in Terminal is the same answer.
B3. If you see NO ℹ️ line there, that Mac already matches a profile and
    nothing is owed — tell me which name the boot reports.

C. MUST STILL WORK — this touched the file that prints every boot.
C1. The 🧭 line still names the host, the module count, the ⇪ shortcut
    count and the boot time.
C2. `_G.bootReport()` still prints the full block, and its Modules row
    still names the profile.
C3. A boot with a real problem still prints its ⚠️ rows instead of
    "All green".

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. It is ℹ️, not ⚠️, on purpose — a Mac with no profile is untuned, not
    broken, and a warning over a healthy state is one you scroll past.
    If you would rather it shouted, say so.
D2. 📏 NAMED, NOT FIXED: this does not prove the config RUNS well on the
    work Mac. The honest next step there is you installing it and
    sending `_G.selfTest()` and `_G.stormReport()` from that machine —
    the storm report has been owed since 6.214.2.



## 6.417.0

6.417.0 verify with LL — 📠 A REPORT PRINTS ONCE (KNOWN GROUND)
WHAT CHANGED: every report in this config printed itself TWICE in the
Console. Now once.
🔎 YOUR OWN PASTE WAS THE ARTEFACT: `_G.draftCheck()` gave you the whole
block, then the whole block again. The Console ECHOES whatever an
expression returns, and thirty-five reports ended by both printing the
text and returning it.

A. THE HEADLINE — ten seconds.
A1. Console: `_G.draftCheck()`.
    EXPECT: the block ONCE. **A FAIL is seeing it twice.**
A2. Three or four others: `_G.screenshotsReport()`, `_G.musicReport()`,
    `_G.autocorrectReport()`, `_G.selfTest()`.
    EXPECT: each prints once, and reads exactly as it did before.
A3. `_G.draftCheck(true)`.
    EXPECT: the text comes back ONCE as the Console's echo, with no
    timestamp in front of it. That is the "give it to me as text" form.

B. THE THREE THAT COPY — these are what made this more than one line.
B1. ⇪⇧ and the focus-mode key (the report chord). EXPECT: the report
    prints, AND an alert says it was copied. ⌘V somewhere: you get it.
B2. Same for the menu-bar inventory and the health report.
B3. 🚨 If any of those three ever says "— macOS refused the copy", paste
    it. That is NEW and it is honest: those three used to claim
    "printed and copied" whether or not the clipboard write happened.

C. MUST STILL WORK.
C1. ⇪⇧D's diagnostic report still prints in full.
C2. The boot blocks (🩺 self test, 💾 stores) still print at boot.
C3. `_G.todayReport()`, `_G.degradeReport()`, `_G.saved()`.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Is the Console noticeably quieter now? That was the point. If any
    report STILL doubles, name it — the sentry says that should be
    impossible, and an exception would mean it is reaching the Console
    by a route I have not found.



## 6.416.0

6.416.0 verify with LL — 🩺 THE SELF TEST TELLS THE TRUTH (KNOWN GROUND)
WHAT CHANGED: your word was "6.413.0: do better". Three faults in the
block you read every morning, all mine.
🚨 AND YOUR SNIPPETS WERE NEVER MISSING. The row asked a global this
config has never published, so it counted zero and said "NO snippets
are loaded" — on every Mac, for ever, over your nineteen hundred. The
gate certified it because my own test file invented that global.

A. THE HEADLINE — reload and read the 🩺 block.
A1. EXPECT the Snippets row to read a REAL NUMBER:
      ✅ Snippets  1926 loaded · the tap is running · _G.snippetsReport()
    **A FAIL is "NO snippets are loaded"** — that is the old row.
A2. EXPECT the ⇪ shortcuts row to read **111**, the same number as the
    🧭 line above it. It used to say 119.
A3. EXPECT the summary to read "every tool answered" with no ⚠️.
    PASTE THE WHOLE BLOCK.

B. THE RIGHT DOOR FOR SNIPPETS — and this is the "good report" you
   asked for, which already existed and I had never pointed you at.
B1. Console: `_G.snippetsReport()`.
    EXPECT: a short block — how many triggers, how long they took to
    load, where the packs came from, any problems, and your recent
    picks. NOT two thousand lines.
B2. `_G.snippetsList()` is still the firehose, deliberately: one line
    per trigger. That is what flooded your Console, and it was my
    message that sent you there.

C. MUST STILL WORK.
C1. ⇪⇧S opens the picker; a trigger you type still expands.
C2. The other seven 🩺 rows are unchanged.
C3. `_G.selfTest()` still runs the block on demand.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Now that the block is not lying, is it WELCOME at every boot, or
    noise? That question was worth nothing while one row was wrong, so
    I am asking it again. `settings = { self_test = { sayBoot = false } }`
    makes it quiet and leaves the command.
D2. Which other tools belong on it? Candidates not added: Hamsidian's
    notes folder, the clipboard poll, the backup, OneDrive.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
