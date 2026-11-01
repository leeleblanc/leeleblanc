# TESTING — how to score release 6.388.0

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

## 6.388.0

6.388.0 verify with LL — 🗳 IT SAYS WHAT IS DAMAGING (KNOWN GROUND)
WHAT CHANGED: App Removal now tells you, file by file, whether removing
it is safe — and lets you leave any one of them behind.
🔎 WHAT 6.384.0 WAS MISSING, because it is the whole release: it showed
you the list and then moved ALL of it on the second press. There was no
middle. Now every file is a row you can press Return on, the risky ones
are NOT selected until you say so, and ⏎ on the top row moves only what
is still selected.

A. THE HEADLINE — use something you do not mind losing.
A1. Press **⇪⇧[** — hold Caps Lock and Shift and press the **[** key,
    just right of P. Pick an app and press **Return**.
    EXPECT: the picker now lists EVERY file, one row each, and each row
    starts either **[ MOVE ]** or **[ keep ]** with a ✅ or ⚠️ after it.
    **A FAIL is the old single confirmation row with nothing under it.**
A2. Read the second line of a few rows. EXPECT: the word "safe" or
    "careful", then WHY in plain words — "a cache — rebuilt
    automatically, holds nothing of yours", or "a sandboxed app's own
    Documents live inside this".
A3. Look at which rows start **[ keep ]**.
    EXPECT: the ⚠️ ones. Nothing risky is selected until you ask.
    That is the reverse of last week and it is the point: the thing
    this tool can get wrong is moving a folder with your files in it.
A4. Read the row at the very top.
    EXPECT: "✅ Move “<app>” — the N selected row(s), <size> — to the
    Trash". **N is how many are SELECTED, not how many were found** —
    if your app has a ⚠️ row, N is smaller than the total, and that is
    the release working.
A5. Press **Return on the top row**. EXPECT: the selected files go to
    the Trash and the ⚠️ ones are STILL THERE. Check one in Finder.

B. LEAVING A FILE, AND TAKING IT ANYWAY — the iterative half.
B1. Press ⇪⇧[ again, pick an app, Return.
B2. Put the highlight on any **[ MOVE ]** row and press **Return**.
    EXPECT: it flips to **[ keep ]**, the list STAYS OPEN, and the top
    row's count goes down by one.
    **A FAIL is the list closing, or the highlight jumping back to the
    top.** That second one is what would make this unusable, so it is
    worth watching for specifically.
B3. Press Return on it again. EXPECT: back to [ MOVE ], count back up.
B4. Near the top there are three rows: "☑ Keep everything",
    "☐ Select everything" and "↺ Back to what this tool suggests".
    Try each. EXPECT: the [ MOVE ]/[ keep ] marks all change, and the
    count at the top follows.
B5. With "☑ Keep everything" chosen, read the top row.
    EXPECT: **"🚫 every row is marked KEEP — nothing is selected to
    move"** — NOT "there is nothing to move". Those are different
    facts: one is your decision, the other is an empty folder.
B6. "◂ Back to the app list" forgets the listing and moves nothing.

C. THE ONE WORTH THIRTY SECONDS — the count that is an artefact.
C1. Pick a SANDBOXED app you have actually used — something from the
    App Store, or anything that keeps documents of its own.
    EXPECT, on its Container or Application Support row: **"HOLDS N
    FILE(S) THAT LOOK LIKE YOURS"** with a real number.
    That number is why this release exists. A label saying a folder
    might hold your files is a warning you learn to ignore; a number
    saying it holds twelve is something you can act on.
C2. If a row ever says the count stopped at 50, that is deliberate —
    counting is work on the thread that carries your keyboard, so it
    stops, and the row says so rather than reporting 50 as a total.

D. MUST STILL WORK — this is the tool that moves files, so this half
   matters more than A.
D1. The first press still MOVES NOTHING. Press ⇪⇧[, pick an app, read
    the list, press Escape. Check the app is still in /Applications.
D2. Nothing is ever erased. Everything that moves goes to the **Trash**
    and Finder → Trash → **Put Back** undoes it.
D3. Try to remove an app that is OPEN. EXPECT: it refuses by name and
    tells you to quit it first. Nothing moves.
D4. A ⚠️ row's reason still says when it was matched by NAME rather
    than by the app's own id — and such a row is careful even when it
    is only a cache.
D5. 🚨 It must never touch anything outside your home folder or
    /Applications. If it ever does, stop and tell me at once.

E. THE CONSOLE, if you prefer reading to clicking.
E1. `_G.appRemove("Transmission")` — prints the whole analysis: one
    line per file, its verdict, the reason, the size, and whether it is
    selected. Moves nothing.
E2. `_G.appRemoveKeep(3)` toggles row 3 · `_G.appRemoveKeepAll()` ·
    `_G.appRemoveKeepNone()` · `_G.appRemoveSuggested()`.
E3. `_G.appRemoveGo()` moves what is selected.
E4. `_G.appRemoveReport()` — a new `select :` line says how many of how
    many are selected, whether any change was YOURS, and NAMES every
    row it thinks could be damaging. PASTE THAT after a real listing.

F. ❓ QUESTIONS — answers wanted, nothing to run.
F1. **Are the verdicts right for how you work?** I call Application
    Support "careful" because apps keep real data there, which means it
    starts kept and you have to opt in on nearly every app. If that is
    a nuisance and you would rather it were safe-by-default, say so —
    it is one line, and it is your Mac.
F2. **Is "careful" the right word?** The alternatives are "⚠️ your data
    may be in here" or just "ask me". It is what you will read dozens
    of times.
F3. **Should a ⚠️ row ever be moved without a second look?** Right now
    ☐ Select everything can take all of them in one press. That is
    deliberate — it is your call — but say if you would rather it asked
    again before moving a row that holds files.
F4. **The other half of your ask is NOT in this release**, said rather
    than left for you to notice: apps that run only off a disk image
    and are never installed. Those leave preferences behind with no app
    to point this tool at, so the scan has to work backwards — find the
    leftovers first and ask which have no app anywhere. That is its own
    release and it is next unless you redirect me.



## 6.387.0

6.387.0 verify with LL — 📝 EVERY TAB IS A REAL NOTE (KNOWN GROUND)
WHAT CHANGED: every Hamsidian tab now writes itself into your notes
folder as a real .md file, a couple of seconds after you stop typing.
Your answer, both halves: "(a) every tab is a .md IMMEDIATELY", and
"Yes" to doing it on the first PAUSE rather than the first keystroke.
🚨 THIS CHANGES WHERE YOUR WRITING LIVES, so read step E1 before you
decide you like it — it is the one thing in this release that is a
trade rather than a win.

A. THE HEADLINE — a minute.
A1. Press ⇪N to open Hamsidian. Press ⌘T for a fresh tab.
A2. Type two lines — anything, but **press Return at the end of the
    first one**. That matters, and B is where I explain why.
A3. Stop typing. Count to three.
A4. In Finder, open your notes folder and look in **Scratch**:
    <OneDrive>/Vault/Scratch.
    EXPECT: a file named after your FIRST LINE, holding what you just
    typed. You pressed nothing to make that happen.
    **A FAIL is no file at all** — go straight to D1, the report says
    which of four things happened.
A5. Type another word in the same tab, wait three seconds, and open
    the file again. EXPECT: the new word is in it.
A6. Press ⇪3 (the notes side of the same window). EXPECT: your tab is
    in the list ONCE — as the 📝 tab it still is, not twice.
    **A FAIL is the same thing appearing twice**, once with 📝 and
    once with 🕸. That is the one regression this release can have and
    I want to know at once.

B. THE RULE THAT DECIDES WHEN IT WRITES — worth two minutes, because
   it is the part you would otherwise think was broken.
B1. New tab (⌘T). Type **just a few letters of a title and stop** —
    "Buy mi" will do. Do NOT press Return.
B2. Wait five seconds and look in the Scratch folder.
    EXPECT: **nothing yet.** That is deliberate, and here is why: the
    file keeps the name it is first given, for ever — that name is how
    every [[link]] finds it, and this config never renames a note. So
    a file written two seconds after "Buy mi" would be called "Buy
    mi.md" after you had finished typing "Buy milk".
B3. Now finish the line — type "lk" — and press **Return**.
    EXPECT: within a few seconds the file appears, called "Buy
    milk.md". A finished first line is a title you have moved past.
B4. The other way it settles: new tab, type one line, press no Return,
    and **leave it alone for twenty-five seconds**.
    EXPECT: the file appears, named after that line. That is the note
    you type and walk away from.
B5. Console: `_G.scratchPadReport()` — the 📝 auto line's "waited for a
    title to settle" count goes up for B2. **That is a state, not a
    failure**, and the line under it says so.

C. MUST STILL WORK — this touched the one function every keystroke in
   Hamsidian passes through, so this half matters more than A.
C1. Type in a tab, close Hamsidian, reopen it: your words are there.
C2. ⌘T a new tab, ⌘W close one, ⌘1–⌘9 jump, ⌃Tab cycles.
C3. ⌘⇧S still exports everything on demand and still says how many.
C4. 🚨 **⌘Z IN A NOTE** — open a real note on the ⇪3 side, delete a
    paragraph, wait ten seconds for a background scan to land, then
    press ⌘Z. EXPECT: your text comes back. That is 6.323.0 and this
    release had to be careful not to break it; if undo is gone, tell
    me immediately.
C5. ⌘F filters the list; ↑↓ walk it; ⏎ opens.
C6. The ✕ on a tab row still closes the tab. The ✕ on a note row still
    deletes that note to the bin.
C7. Obsidian: open the Vault folder. EXPECT your tabs are there as
    ordinary notes in Scratch, readable and editable.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.scratchPadReport()` — the whole block. The new 📝 auto line has
    four states and I want whichever you get:
    · "N written · 0 FAILED" with a last file named — healthy;
    · "nothing typed in a tab yet this session" — not a fault;
    · "⚠️ NOT WRITTEN: …" — **paste this at once**, it names macOS's
      own reason and your words are still in the tab;
    · "OFF" — the switch is off.
D2. The "one list" line in the same block says how many open tabs have
    a file. That is the number that makes A6 answerable without a
    screenshot.
D3. If it ever says "⚠️ N write(s) went AT ONCE", paste it: that Mac
    would not arm a timer, so a half-typed title was used after all.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. **Do you want this on?** Before today a tab was one local file that
    nothing else read. Now every tab you type in becomes a note in
    OneDrive within seconds — searchable in ⇪D, open in Obsidian,
    synced to the other Mac, and still there after you ⌘W the tab.
    That is exactly what you asked for; it is also a lot more files
    than you had yesterday. `settings = { scratch_pad = { autoWrite =
    false } }` is yesterday's behaviour exactly, and if you would
    rather have that, say so and I will change the default rather than
    leave you a line to type.
E2. **Two seconds and twenty seconds** — the pause before a write, and
    the quiet before a one-line title is trusted. Both are numbers,
    not releases. If files appear while you are still thinking, the
    first wants to be longer.
E3. 📏 NAMED, NOT FIXED, so it is not a surprise: closing a tab leaves
    its file behind. Nothing deletes it, which is right — it is your
    writing — but it does mean a throwaway tab leaves a note. The ✕ on
    the note row removes it to the bin when you want it gone. Say if
    you would rather a closed tab's file went with it.
E4. While this was being built, nothing of yours was at risk and
    nothing broke — so unless A or C fails I would not log this as a
    problem at all. If a file ever fails to write and you lose words,
    that is a different matter and D1 is the evidence.



## 6.386.0

6.386.0 verify with LL — 🚪 THE ASANA DASHBOARD MOVED HOUSE (KNOWN GROUND)
WHAT CHANGED: nothing you press. 529 lines of Asana code left init.lua
for a file of its own. ⇪L, ⇪C and ⇪B do exactly what they did.
🔎 WHY IT WAS WORTH A RELEASE, since there is nothing new to use: the
gate refuses to ship init.lua over 3,800 lines and it had reached 3,795.
6.385.0 had to delete a release note from the top of the file just to
fit, which means the next thing you asked for would have cost a feature
to make room. It is 3,313 now, with 486 lines of headroom.
🚨 SO THIS BLOCK IS A REGRESSION TEST, NOT A FEATURE TOUR. The only
honest claim is "everything still works", and the only way to know is
to press the keys. If any step below behaves differently from last
week, that is the release and I want to know at once.

A. THE HEADLINE — three keys, about two minutes.
A1. Press **⇪L** (hold Caps Lock, press L).
    EXPECT: "🔄 Syncing Asana Tasks…", then your task list, searchable,
    with the colour legend strip — Overdue, Due today, Due this week,
    Due later, No due date — sitting ABOVE the search field.
    **A FAIL is nothing happening at all**, which is what a mis-moved
    key looks like. Go straight to D1 if so.
A2. Press ⏎ on a task. EXPECT: it opens in your browser.
A3. Press **⇪C**. EXPECT: the same list, but the placeholder now reads
    "💬 Pick a task to comment on…". Pick one, type a comment, Post.
    EXPECT: it lands in Asana.
A4. Press **⇪B**. EXPECT: your Asana team, searchable. Type part of a
    team name — "core" — and the list narrows, because the team is
    folded into each row's second line.
A5. Press ⏎ on a person. EXPECT: "📋 Copied <name> — paste into the
    Assignee field", and ⌘V gives you that name.

B. SELECT MODE AND THE DELETE — the one verb here that destroys
   something, so it is worth the five minutes.
B1. ⇪L, then ⏎ on the first row, "☑️ Select several to delete…".
    EXPECT: the list comes back with a "✕ Leave select mode" row.
B2. ⏎ on two or three tasks. EXPECT: each gains a ✓.
B3. ⏎ on the "🗑 Delete N selected" row at the top.
    EXPECT: a dialog NAMING the tasks and saying they go to Asana's
    trash, restorable for 30 days. **Press Cancel.**
    EXPECT: "🗑 Nothing deleted", and all of them still in Asana.
B4. Only if you have a task you really want gone: do B1–B3 and press
    Delete. EXPECT: it goes, and the list re-fetches.
B5. ⇪L, then hold ⌥ and press ⏎ on one row. EXPECT: the same
    confirmation for that one task.

C. THE LEGEND STRIP, which is the fiddliest thing in the release.
C1. With ⇪L open, hold ⌃⌥⌘ and press an arrow key to nudge the picker.
    EXPECT: the colour strip MOVES WITH IT. That is the one wire that
    crosses between this file and init.lua, and if the strip gets left
    behind, this is where it shows.
C2. ⌃⌥⌘R to clear the nudge. EXPECT: both go back.
C3. ⇪L on your OTHER monitor. EXPECT: the strip is on that monitor,
    above the picker, fully on screen.
C4. Esc. EXPECT: the picker AND the strip both go.

D. PASTE BACK, PASS OR FAIL.
D1. Console: `_G.asanaDashboardReport()` — NEW; this tool has never had
    one, which is why "did it move correctly?" could only have been
    answered by me reading the code.
    EXPECT the `keys` line to read **"3 of 3 bound in setup() — ⇪L · ⇪C
    · ⇪B"**. Two other things it can say and each is a real finding:
    "⏳ setup has NOT run" means the module did not load at all;
    "⚠️ setup ran and bound NOTHING" means macOS refused the keys and
    names why. PASTE WHICHEVER YOU GET.
D2. The `↳ seven` line should read "every helper this module moved away
    from is on the core table". A ⚠️ MISSING there is the one failure
    that would make a key die at the moment you press it.
D3. The boot line: **76 modules** now, not 75, and the same ⇪ shortcut
    count as before. A different shortcut count is a finding.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. One thing really did change, and it is a fix I found while moving
    the line past: ⇪B's "📋 Copied" used to be printed whether or not
    macOS took the clipboard write. If it ever now says "⚠️ macOS
    refused the clipboard write", that is real and I want to know —
    before this release you would simply have had nothing to paste.
E2. 🔨 Nothing was broken and nothing was lost — so unless a key below
    fails, I would not log this as a problem at all. If something DOES
    fail, tell me which letter and what happened instead; a move that
    breaks a key is the one kind of regression where the fix is
    obvious once it is named.



## 6.385.0

6.385.0 verify with LL — 🎨 THE PICKERS LOOK LIKE THE JUG PLAYER
(KNOWN GROUND)
WHAT CHANGED: every picker in this config now wears the Jug Player's
dark card instead of macOS's white one.
🔎 AND HALF YOUR ASK IS NOT POSSIBLE, said first rather than found out
later. You asked for two things: the LOOK, and an **(x) at the end of
every row**. The look is done. The ✕ is not, on these windows, and
cannot be: the ⇪⇧V window in your screenshot is an `hs.chooser` — a
list macOS draws for us from plain strings — and there is no
sub-element in a row to click and no way to put one there. The Jug
Player HAS a ✕ because it is a web page we draw ourselves, every
pixel of it. That is the whole difference between those two
screenshots.
🔬 I nearly told you the colours were impossible too, and that would
have been wrong — hs.chooser does expose bgDark, fgColor and
subTextColor, and one of your own tools (the app-quit popup) has used
all three since 6.16.21.

A. THE HEADLINE — ten seconds.
A1. Press ⇪V (clipboard) or ⇪⇧V. EXPECT: a DARK panel, white text,
    dimmer second line — the Jug Player's colours.
    **A FAIL is the white panel in your screenshot.**
A2. Now press several more: ⇪space, ⇪Y, ⇪⇧S, ⇪., ⇪⇧;, ⇪T.
    EXPECT: every one of them dark, and all of them the SAME dark.
    That sameness is the release — they read one table now.
A3. ⇪D (unified search) was already dark. EXPECT: unchanged, and the
    two now look like each other.

B. MUST STILL WORK — this touched the one door every picker opens
   through, so this half matters more than A.
B1. Type to filter in ⇪V. ↑↓ walk. ⏎ picks. Esc closes.
B2. ⌘-drag a picker somewhere, close it, open it again: it reopens
    where you put it.
B3. ⌃⌥⌘ + an arrow nudges an open picker; ⌃⌥⌘R clears the nudge.
B4. The preview pane beside ⇪⇧V and ⇪⇧S still follows the rows.
B5. ⌘⌘ still opens the clipboard; ⌥⌥ still opens the menus.

C. PASTE BACK.
C1. If ANY picker is still light, name it — that would mean it is
    opening without going through the shared door, which is a real
    finding and a different bug.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Too dark? Too much? `settings = { ui_style = { pickerDark =
    false } }` puts macOS's own light pickers back everywhere at once.
    Say the word and I change the default rather than leaving you a
    line to type.
D2. **Which windows did you mean by "my other windows"?** If you meant
    the ones that CAN have a ✕ — Hamsidian, the pads, the task form —
    say so: those are web pages, they can have anything, and that is a
    different and bigger release I did not want to guess at.
D3. On a picker the nearest thing to a ✕ is a KEY on the highlighted
    row. ⇪⇧V already deletes that way. Want that on others — and which?



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
