# TESTING — how to score release 6.423.0

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



## 6.420.0

6.420.0 verify with LL — ⏱ ⇪ LETS GO WHEN A PANEL SAYS SO (KNOWN GROUND)
WHAT CHANGED: when a panel tells this config it has taken the keyboard,
⇪ now lets go at the deadline that panel asked for — and typing into
the panel can no longer push that deadline out.
🔎 YOUR OWN STORM REPORT IS THE DIAGNOSIS, and you did nothing wrong:
an 18.4-SECOND ⇪ hold, Chrome in front, a Unified Search handoff
pending, while you typed into that panel. Every letter you typed
called the "this hold is real" stamp, which wiped the 1.5-second
deadline and bought the hold EIGHT MORE SECONDS. So it only ended when
you stopped touching the keyboard for a full eight seconds. Measured
against the build you are on: typing every 0.4 s, it NEVER let go.

A. FIRST — GET BACK TO WORK. Do this before any test.
A1. Install and reload. If ⇪ is latched at that moment, press
    **⇪⇧Esc** (Caps Lock + Shift + the Escape key) — it pauses this
    config and your keyboard is yours. ⇪⇧Esc again resumes.
A2. If the keyboard is so far gone that a shortcut cannot be pressed:
    quit Hammerspoon from the menu bar, then in Terminal
        hidutil property --set '{"UserKeyMapping":[]}'
    which gives Caps Lock back to macOS. Relaunching Hammerspoon
    re-applies it.
A3. Use the Mac normally for a while before doing B. If ⇪ feels
    ordinary — shortcuts fire, typing types — that is the headline.

B. THE HEADLINE — the case that was costing you 18 seconds.
B1. Press **⇪D** (unified search) or **⇪N**, and TYPE INTO IT for
    several seconds, as you would normally.
B2. Let go of Caps Lock whenever you like and carry on typing.
    EXPECT: your letters go into the panel as text, throughout.
    **A FAIL is letters running shortcuts instead of typing**, which
    is the bug — and if it happens, note roughly how long for.
B3. Console: `_G.hyperKeyReport()`.
    EXPECT the `latch :` line to read **0** — ⇪ has not stuck. A
    number there is the fault and I want the whole block.
    EXPECT `handover :` to have climbed, which is the normal ending.

C. THE HALF THAT MUST NOT HAVE MOVED — please do this one.
C1. Hold Caps Lock DOWN, with no panel open, and keep pressing letter
    keys for ten or fifteen seconds (they will run shortcuts — do it
    somewhere harmless, like the Desktop).
    EXPECT: ⇪ stays held for as long as your finger is down. It must
    NOT let go under you.
    **A FAIL here is ⇪ releasing while you are still holding it** —
    that would be worse than the bug and I want to know at once.
C2. Let go. The next ⇪ press works as ever.

D. MUST STILL WORK — this is the key every shortcut goes through, so
   this half matters more than B.
D1. A spread of keys across different tools: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4,
    ⇪space, ⇪V, ⇪/, ⇪⇧S.
D2. ⇪⇧. the Jug Player, ⇪⇧, the Mug Player — both take the keyboard,
    so both exercise the new deadline.
D3. ⇪⇧Esc pauses and resumes.
D4. ⌃⌥⌘⇧Esc, the panic chord, still releases everything.
D5. Boot: All green, 79 modules, the usual ⇪ shortcut count.

E. PASTE BACK, PASS OR FAIL.
E1. `_G.hyperKeyReport()` after a day — `latch`, `handover` and
    `relay` are three different endings and only `latch` is a fault.
E2. If another storm ever happens, `_G.stormReport()` and the file it
    names. The `asked :` line will show the panel handoff and, now,
    the deadline it was given.

F. A JUDGEMENT ONLY YOU CAN MAKE.
F1. 1.5 seconds is the panel's own number and I have not changed it.
    If ⇪ now lets go while you are still mid-chord in a panel, say so
    and it goes up; if 18 seconds became 2 and that still feels long,
    it goes down. It is a number, not a release.
F2. 📏 NAMED, NOT FIXED, so it is not a surprise: your Nov 6 report
    also shows two shortcuts taking about 1.1 and 1.5 SECONDS each
    (⇪space and ⇪⇧.). That is main-thread work and it is a separate
    fault — it is why a run of six shortcuts can span the five seconds
    the storm rule measures. Tell me whether ⇪space FEELS slow when
    you press it and that is the next release.
F3. 🔨 While this was happening the Mac was unusable — every key ran a
    shortcut and nothing typed. My reading is that it is the same
    class as 6.214.0, and the honest pass count is 1. Your tag.



## 6.419.0

6.419.0 verify with LL — 📋 A GOOD REPORT FROM `_G.snippetsList()` (YOUR ASK)
WHAT CHANGED: you said it was way too much in the Console and asked for
a good report. It printed **1,937 lines** over your 1,926 snippets, and
the count you wanted was on the FIRST of them — so it had scrolled off
the top before the dump finished. It now prints the SUMMARY first and
in full, then at most twenty rows. **32 lines by default instead of
1,937.**
🚨 AND I AM CORRECTING MYSELF: 6.415.0's test plan told you this door
was "still the firehose, deliberately". That was my call and it was the
wrong one for the command you reach for by name. The firehose still
exists — you just have to ask for it now.

A. THE HEADLINE — Console, ten seconds.
A1. `_G.snippetsList()`
    EXPECT: about thirty lines, not two thousand. In order: a ✂️ line
    with the trigger count, where your own snippets live, 📦 the file
    the packs came from, a `collections` block with a count per pack
    (ComposeKey, Emoji_Pack, Ghostty_or_Terminal, Mac_symbols and
    whatever else you have), then `rows / more / set`, then twenty
    rows, then "… N more row(s) not shown".
    **A FAIL is any version of this that floods the pane.**
A2. Read the `more :` line. It names a collection of YOUR library — the
    biggest one — not an example I typed in.

B. THE THREE STATES — this is the part I want your opinion on.
B1. `_G.snippetsList(0)`  → the summary ALONE, no rows at all (11 lines).
B2. `_G.snippetsList(60)` → sixty rows under the same summary.
B3. `_G.snippetsList(true)` → every row, all 1,937 lines. The old
    behaviour, still there, now something you ask for.
B4. `_G.snippetsList("emoji")` → only Emoji_Pack's rows, still capped at
    twenty. Part of a name is enough and case does not matter.
B5. `_G.snippetsList("banana")` → it says no collection matches, and the
    `collections` block above it is the list of what it could have
    matched. **A FAIL is a silent empty list**, which would read as
    "you have no snippets".

C. THE DEFAULT IS YOURS TO SET. Twenty is my guess at "a screenful
   without the headline scrolling away". One line in your profile:
       settings = { expander = { listShow = 40 } }
   0 means "always just the summary"; true means "always everything".
C1. Set it to something, reload, and run `_G.snippetsList()` — the
    `set :` line should read back the value you chose.

D. MUST STILL WORK — this is the module that watches every keystroke.
D1. ⇪⇧S still opens the picker, and your recent picks are still at the
    top.
D2. A trigger you TYPE still expands — `;bd`, `gg1`, whatever you use.
D3. `_G.snippetsReport()` is unchanged: the library, the recent queue
    and its store.
D4. `_G.snippetsImport()` and `_G.snippetAdd("gg1", "text")` still work.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. The twenty rows are the alphabetical FIRST twenty, so on your Mac
    they will all be `!!`-prefixed Mac_symbols. That is honest (the line
    says "A–Z") but it is not a representative sample. If you would
    rather the tail showed a few from EACH collection, say so and it
    becomes that.
E2. Is the `collections` breakdown the answer you wanted, or were you
    after something else entirely when you said "a good report"?



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
