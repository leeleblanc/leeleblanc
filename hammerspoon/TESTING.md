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
B2. `_G.snippetsList()` WAS the firehose, deliberately: one line per
    trigger. That is what flooded your Console, and it was my message
    that sent you there. ⚠️ SUPERSEDED BY 6.419.0 — it answers with a
    summary and twenty rows now, and the firehose is
    `_G.snippetsList(true)`. Score this step from 6.419.0's plan, not
    this one.

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
