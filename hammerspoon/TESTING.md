# TESTING — how to score release 6.367.0

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

## 6.367.0

6.367.0 verify with LL — ☁️ IS THE FILE REALLY HERE? (NEW GROUND)
WHAT CHANGED: one new command. `_G.oneDriveCheck()` walks the folders
that hold your data and names every file whose BYTES are not on this
Mac — whatever Finder says about it.
🔬 AND IT IS HONEST ABOUT WHICH HALF IS PROVEN. Telling a real file
from a placeholder is solved: macOS reports the file's full size AND
how much of it is actually allocated, and that difference is the only
thing that can answer the question WITHOUT READING THE FILE. What is
NOT known is whether "Always keep on device" is readable at all — the
pin belongs to macOS, not to us, and it may not be visible from here.
So this release ASKS your Mac and prints the answer rather than
guessing. **That is the thing I need back from you.**
🚨 IT NEVER READS A FILE, deliberately: reading a placeholder
downloads it, and a download on the main thread is the 72-second
freeze that killed Hammerspoon on 2026-10-12.

A. THE HEADLINE — one command.
A1. Console: `_G.oneDriveCheck()`.
    EXPECT: the folders it walked, how many files, how many are here,
    and — the line you asked for — **☁️ NOT HERE**, naming every
    offloaded file biggest first.
A2. If it says "NOT HERE: none", everything in those folders is really
    on this Mac right now. That is a pass, and worth running again in a
    few days — the whole complaint is that it CHANGES.
A3. If it names files, check one in Finder: it should show the cloud
    icon. **If Finder shows it as downloaded and this says it is not,
    tell me at once** — that is the tool being wrong, which is worse
    than the problem.
A4. PASTE THE WHOLE BLOCK either way.

B. THE PROBE — this is the half only your Mac can answer.
B1. Console: `_G.oneDriveProbe()`.
    It asks macOS for the extended attributes on a file that IS here
    and on one that is NOT, then prints the report again with three
    new lines: what BOTH kinds carry, what only a local file carries,
    and what only a placeholder carries.
B2. **PASTE THOSE THREE LINES.** An attribute in one of the last two
    is what a "keep on device" flag would look like. Nothing in this
    release decides what any of those names MEAN — I want to read them
    before anything is built on them.
B3. If it says ⚠️ with a reason, paste that instead: "xattr did not
    answer", "macOS refused to start xattr" and "no hs.task" are three
    different findings.

C. IT MUST NOT CRY WOLF.
C1. Run it a few times over a few days.
    EXPECT: no alert, no boot line, nothing on screen. It is a command
    you run, not a tool that talks.
C2. If the ☁️ NOT HERE list includes hundreds of ordinary notes, that
    is the tool being wrong rather than OneDrive being wrong — tell me
    and paste a few of the paths.
C3. If it says "⚠️ STOPPED AT THE 4000-FILE BOUND", every number is a
    floor and not a total. Say so when you paste it.

D. MUST STILL WORK.
D1. Boot: All green, **73 modules** (was 72 — this release adds one).
D2. ⇪3 Hamsidian, ⇪N, ⇪D, ⇪⇧, the Mug Player — nothing else changed.
D3. ⇪/ and search `onedrive` — the card is there, filed under FILES.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. **Which folders should it watch?** Right now: your Vault, the Logs
    folder and the OneDrive root. Name any others and they go in one
    line: `settings = { onedrive_check = { folderList = { "/full/path" } } }`.
E2. **Should it bring files back by itself?** I have NOT built that,
    on purpose — downloading is a READ, and a read is the thing that
    froze your Mac. Doing it safely means one file at a time, outside
    Hammerspoon. Say the word and it is its own release.
E3. **Should it check on a schedule and tell you when something slips
    out?** That is the version that would actually catch OneDrive
    doing it — but it is a tool that talks, and this one deliberately
    does not. Your call.



## 6.366.0

6.366.0 verify with LL — ❌ THE REFUSAL SAYS WHY (KNOWN GROUND)
WHAT CHANGED: when a task does not reach Asana, the TAB now says why.
🔎 AND THE REASON ALREADY EXISTED, which is worth knowing: the submit
has handed back Asana's own words since 6.299.0 — "Asana refused it
(HTTP 400) — <Asana's reason>". It went to an alert that is gone in
ten seconds and a report you had to know to run. What it never
reached is the tab, which is the thing you are looking at. Fifth time
I have built the measurement and not the door.

A. THE HEADLINE — make one fail on purpose.
A1. ⇪N, a new tab, two lines:
      Buy milk
      P: Send the thing
      A: notarealperson
A2. Press "→ Asana now".
    EXPECT: the FIRST task lands in Asana, the second is refused.
A3. Look at the tab's title in the list.
    EXPECT: **❌ Error: 1 of 2 — <Asana's own sentence>** — not the
    old "❌ Error: tasks not sent".
    **A FAIL is the old flat wording.**
A4. Console: `_G.scratchPadReport()`. There is a new block:
      ❌ WHY  : the refusals, by task — this is what to troubleshoot from
                "❌ Error: 1 of 2 — …" — 1 refused
                  · Send the thing
                    ↳ no team member matches "notarealperson"
    EXPECT the TASK named, Asana's sentence under it, and — when they
    differ — the RAW body on a third line.

B. IT MUST NOT LIE ABOUT WHAT LANDED.
B1. Check Asana: "Buy milk" IS there and "Send the thing" is not. The
    tab says 1 of 2, which is the number that matters.
B2. Fix the assignee and send again.
    EXPECT: only the refused one is sent (6.305.0, unchanged), the tab
    goes ✅, and the ❌ WHY block is GONE from the report.
    **A ✅ tab that still lists a refusal is the bug** — tell me.
B3. Type a character in a ❌ tab.
    EXPECT: the mark clears AND the refusals clear with it.

C. MUST STILL WORK.
C1. A tab where everything lands still goes ✅ and is never re-sent.
C2. ⇪T creates a task; ⇪A still works.
C3. The 4 PM run is still OFF (your 6.254.0 switch) — only the button
    and `_G.scratchPadSend()` send.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Is the reason on the TAB the right length? It is cut at ~54
    characters so the strip stays readable. Too short to be useful, or
    already too long for the list?
D2. If Asana's sentence is still not enough to troubleshoot from, send
    me the raw line from the report — that is Asana's whole answer, and
    if it is unhelpful the next step is asking Asana for more fields.



## 6.365.0

6.365.0 verify with LL — ⏪ ← → SEEK (KNOWN GROUND)
WHAT CHANGED: the arrow keys seek in the Mug Player — 15 seconds a
press, 60 with ⇧ — so you no longer have to mouse over and press the
±15 s buttons.
🔎 WHY THEY DID NOTHING: the page left them to WebKit, which seeks with
them only while the FILM ITSELF has the keyboard. The window's document
has it — that is how space and ↑↓ work — so the arrows reached nothing.
🖥 AND ⌃⌘F ALREADY EXISTED. You asked for it and it shipped in 6.358.0,
which is one of the three releases that never reached your Downloads
because the link died when the next release shipped (6.360.0 fixed
that). Test it below; if it is not what you meant by full screen, say
so — see D2.

A. THE HEADLINE.
A1. ⇪⇧, and play a film. Press **→**.
    EXPECT: it jumps forward 15 seconds. **←** goes back 15.
A2. **⇧→** and **⇧←**: 60 seconds.
A3. Do it with the keyboard focus anywhere in the window — on the deck,
    on the film, after clicking a row. It must work from all of them;
    that is the whole fix.
A4. Press → near the END of the film. EXPECT: it parks at the end, not
    past it. ← at the start parks at 0.

B. ⌃⌘F — the one you have never had.
B1. Press **⌃⌘F**. EXPECT: the window fills the screen.
B2. Press it again. EXPECT: back to the size AND the spot you had it.
B3. 📏 It FILLS the window rather than entering macOS full screen, and
    that is a platform limit, not a shortcut: Hammerspoon's webview has
    no full-screen window mask at all. The film's own control bar has a
    real full-screen button if that is what you want.

C. MUST STILL WORK.
C1. space pauses and resumes · ↑↓ walk the deck · ⏎ plays · ⌘1–9 ·
    ⌫ removes from the queue · Escape closes.
C2. Escape out of the film's OWN full screen leaves the window up.
C3. Drop films on the window; ⌘O opens one in your usual player.
C4. ⇪⇧. the Jug Player — its ← → are 5 s and 30 s and are unchanged.

D. PASTE BACK, AND A JUDGEMENT.
D1. `_G.mugReport()` — a new `seek :` line names both steps and counts
    the presses. If it ever reads **⚠️ N REFUSED**, paste it: that is a
    film whose length macOS never answered, and → is deliberately
    refused there because seeking forward into an unknown length lands
    in silence with no way back.
D2. **Is 15 s right?** I took it from the buttons you named. 10 or 30
    is one number: `settings = { video_player = { seekStep = 10 } }`.
    Say a number and I will change the default instead.
D3. **Did you mean ⌃⌘F to make the FILM full screen** rather than the
    window? That is a different one-line change and I did not guess it.



## 6.364.0

6.364.0 verify with LL — 🗑 A CLOSED TAB CAN BE FORGOTTEN (KNOWN GROUND)
WHAT CHANGED: every row in Hamsidian's HISTORY strip — the closed tabs
— now has a ✕ at its right-hand end. It forgets that tab for good.
🔎 You were right that it was missing: restoring a row was the ONLY
thing that could take one out of the history, so a tab you closed by
mistake came back for ever and the only way to be rid of it was to
restore it and close it again, which puts it straight back.

A. THE HEADLINE.
A1. ⇪N. Look at the HISTORY strip (the closed tabs, lower right).
    EXPECT: a dim ✕ at the end of every row, brighter under the
    pointer and red when you are on it.
A2. Click the ✕ on one.
    EXPECT: the row disappears and **NOTHING OPENS**.
    **A FAIL is the tab reopening** — that is the one bad outcome
    here, and I want to know at once.
A3. Click a row on its TITLE instead.
    EXPECT: it still restores as a tab, exactly as before.
A4. Close and reopen the window. EXPECT: the forgotten row is still
    gone — it was saved, not just hidden.

B. THE KEYBOARD, AND THE ONE THAT PROTECTS YOUR TYPING.
B1. Press ⌥↓ to highlight a history row, then **⌥⌫**.
    EXPECT: that row is forgotten.
B2. Click into the filter box, type something, press **⌫** on its own.
    EXPECT: it deletes a CHARACTER. It must not forget a row — that is
    why the key needs ⌥.
B3. Type in the main text box and press ⌫. EXPECT: ordinary deleting.

C. THE ONE WORTH THIRTY SECONDS.
C1. Type something in a tab. WITHOUT clicking away, click the ✕ on a
    history row, then press **⌘Z** in the text box.
    EXPECT: your undo still works. The page removes the row itself
    rather than letting Lua rebuild the whole window, because a
    rebuild destroys the text box's undo history (6.323.0).
C2. Use the filter to narrow the history, then ✕ a row.
    EXPECT: the row you clicked goes — not the first one in the store.

D. THE BULK DOORS.
D1. `_G.scratchPadForgetHistory("<id>")` — from the report's own list.
D2. `_G.scratchPadClearHistory()` empties the whole strip. Your OPEN
    tabs and every exported note are untouched. Only run it if you do
    not want the list.
D3. `_G.scratchPadReport()` — a new `🗑 forgot:` line counts them and
    names the last one.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. The ✕ forgets immediately, with no confirm. Right, or would you
    rather it asked? Nothing is recoverable afterwards, which is the
    argument for asking — but the tab's TEXT is already gone from the
    pad by then, and the strip is a list you are trying to shorten.
E2. The strip keeps 2,000 closed tabs and draws 200. Is that right?



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
