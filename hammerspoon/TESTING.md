# TESTING — how to score release 6.277.0

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

## 6.277.0

6.277.0 verify with LL — 🔖 ⇪3 PUTS YOU BACK (KNOWN GROUND)
WHAT CHANGED: ⇪3 reopens the note you were last writing in, instead of
whatever was left on screen. ⇪N is unchanged — it still opens the tabs.
WHY IT MATTERS: your words. With thousands of notes, having to find the
one you were in every time is the tool asking you to do its job.
🔎 AND THE HONEST PART: the note was ALREADY being remembered, on every
open, for releases. It was only ever read when nothing was open — and
one press of ⇪N left a scratch tab "open" for the rest of the session,
so it was almost never read. Nothing was lost; it just could not be
reached.

A. THE HEADLINE.
A1. Press ⇪3, open a real note, type a word in it. Press ⇪3 to close.
A2. Press ⇪N (the tabs), look at Scratch 1, press ⇪N to close.
A3. Press ⇪3.
    EXPECT: the NOTE from A1, open, with your word in it.
    A FAIL is landing on Scratch 1 — that is the old behaviour exactly.
A4. Do A1–A3 again but reload Hammerspoon between closing and reopening.
    EXPECT: the same note. This is the path that used to work, so if A3
    passes and A4 fails, tell me — that is a different bug.

B. MUST STILL WORK.
B1. ⇪N still opens on the tabs, never on the note. Press it twice.
B2. ⌘F filter, ↑↓, ⏎ to open a note — all as before.
B3. Open a note, close with ⇪3, reopen: your unsaved keystrokes are
    still there (the save-on-close path is untouched).

C. THE ONE THAT PROTECTS YOUR WRITING — worth doing once.
C1. Open a note, close Hamsidian, then RENAME or delete that note's .md
    file in Finder (pick something you do not mind losing).
C2. Press ⇪3.
    EXPECT: it opens on the notes list, and it does NOT re-create the
    note you just removed. Check Finder: the file must still be gone.
    A FAIL here — the file reappearing — is the worst outcome in this
    release and I want to know immediately.
C3. Console: `_G.vaultReport()`, the new "back to:" line.
    EXPECT: "remembered <name> — this vault no longer holds it", with a
    ⚠️ under it. In normal use it reads "reopened <name>".

D. PASTE BACK, PASS OR FAIL.
D1. `_G.vaultReport()` — the whole block, after doing A1–A3.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. ⇪3 now always goes back to the last NOTE, even if the last thing
    you touched was a scratch tab. Is that right, or would you rather
    it returned to whichever of the two you saw last, whatever it was?
    "notes always" · "whatever I saw last" decides it. I picked the
    first because it is what you described, and because ⇪N already
    gives you the tabs in one press.



## 6.276.0

6.276.0 verify with LL — 🆓 THE FREE-KEY CARDS TELL THE TRUTH (KNOWN GROUND)
WHAT CHANGED: the ⇪/ cards that list which keys are still free no longer
have that list typed into them. They ask the live key registry when
Hammerspoon warms up, which is the same place `_G.freeKeys()` has been
reading correctly since 6.142.0.
WHY IT MATTERS: you were told ⇪⇧pad. was available. The music player has
owned it since 6.231.0. You were right to ask whether the debugging was
good, and the honest answer is that this one was not — the card and the
command disagreed for five releases and nothing in the gate could see it.
🚨 AND IT WAS WORSE THAN THE ONE KEY, which you should know before you
trust any other row on those cards: the same cards said ⇪⇧7 and ⇪⇧8 were
unbound while Bluetooth and the QR reader held them, and one card
contradicted itself four lines apart.

A. THE HEADLINE — the card that lied.
A1. Press ⇪/ and search for `numpad`.
    EXPECT: the 🆓 NUMPAD — ⇪⇧ pad card. Its free row now reads a real
    list of key names after a 🆓, e.g. `🆓 pad0 pad1 pad2 …`.
A2. Read that list. EXPECT: **pad. is NOT in it.** That is the whole
    release. If `pad.` is still offered, this did not take — tell me.
A3. Look at the 🆓 THE ⇪⇧ NUMBER ROW card, the "cleared" row.
    EXPECT: a 🆓 list that does NOT contain 7 or 8.
    It used to say "⇪⇧5 7 8 · ⇪⇧, ⇪⇧. ⇪⇧⏎ — all unbound now".
A4. If any row still reads "asking the key registry…", that is the
    THIRD state and it is honest, not broken — it means warm-up has not
    run yet (give it a few seconds after a reload) or power_tools did
    not load. Step C2 says which.

B. THE COMMAND IS THE TRUTH, AND NOW THEY AGREE.
B1. Console: `_G.freeKeys()`.
    EXPECT: the same keys the card shows, on the `⇪⇧ pad` line.
    That agreement is the point — before this release the two disagreed
    and only one of them was right.
B2. Pick any key the card offers and check nothing happens when you
    press it. EXPECT: nothing. If something DOES happen, that key is
    claimed by a route the registry cannot see, and that is a real
    finding I want.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.freeKeys()` — the whole block.
C2. `_G.padProbe()` — there is a new "🆓 free rows:" line near the
    bottom. Healthy reads `N free-key row(s) read from the live
    registry`. If it reads "not read yet" or "did not answer" there is
    a ⚠️ under it telling you to trust the command and not the card —
    paste that, it is the evidence.

D. MUST STILL WORK — nothing about any KEY changed in this release,
   only what the cards SAY, so this is the regression sweep.
D1. ⇪⇧pad. still opens the music player.
D2. ⇪⇧7 still opens Bluetooth; ⇪⇧8 still reads a QR code.
D3. ⇪; still opens power tools, and its 🆓 row still runs the report.
D4. The numpad capture row (⇪pad1 … ) still works as it did.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. The cards now show raw key NAMES as the registry stores them —
    `pad0 pad1 pad.` and `a b c` — rather than the prettier hand-typed
    ranges ("⇪⇧ pad0–9"). Truthful but blunter. Is that the right
    trade, or do you want me to render them back into ranges? "keep it
    plain" · "make it pretty again" decides it, and pretty is only safe
    because it is now generated rather than typed.



## 6.275.0

6.275.0 verify with LL — 📘 THE INSTALL GUIDE (KNOWN GROUND, docs only)
WHAT CHANGED: INSTALL.md is rewritten and HAMSIDIAN.md has a new §7b on
linking. NO code changed — same modules, same keys, same behaviour.
WHY IT MATTERS: you missed the install on the work Mac, and the old
guide made that easy. The step that matters is the one that puts files
in ~/.hammerspoon, and skipping it looks exactly like doing nothing.

A. THE HEADLINE — do this ON THE WORK MAC.
A1. Open INSTALL.md from the archive root. Read the box at the very top.
    EXPECT: one command, and what ✅ and ❌ look like.
A2. Run that command on the work Mac:
      ls ~/.hammerspoon/init.lua && sed -n 7p ~/.hammerspoon/init.lua
    EXPECT: either a version line (installed) or "No such file or
    directory" (not installed). Either answer is useful — tell me which
    you got, because it settles what happened there.
A3. If it says not installed, follow Step 3 end to end and run 3d.
    EXPECT 3d prints: a path · the version · 12 · 71 · a path.
    If any line is missing, that is the bug and I want the output.

B. THE SNIPPETS QUESTION, ANSWERED — check it rather than take my word.
B1. On the work Mac: `ls ~/.hammerspoon/snippets/bundled.lua`
    EXPECT: a path. The 1,926 public snippets ship IN the archive and
    the installer places them. Nothing to install.
B2. Press ⇪⇧S. EXPECT: the picker, with sections.
B3. Console: `_G.snippetsList()`. EXPECT: a count in the thousands.
B4. Type a trigger in any app. EXPECT: it expands.
    ❌ If the picker works but typing does nothing, Accessibility is off
    or was granted AFTER launch — quit and relaunch Hammerspoon.

C. THE IT SECTION — read it before you talk to them.
C1. Read "What IT has to say yes to". Four rows, each with what you lose
    if refused, plus the list of what they do NOT have to allow.
C2. Tell me if anything there is wrong for YOUR employer, or if they
    ask for something the list does not cover. That is the one part I
    cannot verify from here, and it is the part that decides whether
    this runs at work at all.

D. HAMSIDIAN §7b — linking out.
D1. Read §7b. Then do it: open a Word document, press ⇪⇧U, press ⌘2,
    pick a note.
    EXPECT: the note gains a `## Linked` section with one Markdown line.
D2. In Hamsidian, press ⌘K and pick a screenshot from OneDrive.
    EXPECT: a Markdown link at the caret; ⌘⏎ on it opens the image.

E. QUESTIONS — ANSWERS WANTED, NOTHING TO RUN.
E1. What is the work Mac's computer name (`scutil --get ComputerName`)?
    It gets its own profile in the next release, which is how we switch
    anything off there without you editing init.lua.
E2. Scratch tabs vs notes: do you want a ⇪N tab to become a real .md
    note the moment you make it (one list, everything a file, and every
    keystroke writes to OneDrive), or to stay a tab until you press ⌘⇧S
    (fast and local, two lists)? That one answer is the whole release —
    see the queue note.
E3. Did the archive open? Both a .tar.gz and a .zip are in this one
    because you asked for the zip by name. Tell me which you used and
    whether it worked, and the next release carries only that one.



## 6.274.0

6.274.0 verify with LL — 🔔 ⇪4 LEAVES A NUMBER BEHIND (KNOWN GROUND)
WHAT CHANGED: nothing about how ⇪4 captures. This release exists so that
the NEXT time it does not, we can tell which of four things happened
instead of guessing.
🚨 I HAVE NOT FIXED YOUR ⇪4, and I am saying that first rather than
letting you find it out. I read every path that could make that key do
nothing and they all already say why — 6.265.0 closed that class. What
I could not do is tell, from "intermittently working", WHICH of them you
are hitting. So: instruments, then the fix.
🔎 AND YOUR CONSOLE CARRIED THE CLUE I COULD ACT ON: three
"⚠️ an alert could not draw" lines in eight hours. That is macOS
refusing to draw one of OUR messages — and every message this config
has ever given you goes through that one channel. So an alert
explaining why ⇪4 did nothing could itself have been refused, and
nothing recorded that it happened or what it said.

A. THE HEADLINE — the new reports. Nothing to break, everything to read.
A1. Console: `_G.alertReport()`.
    EXPECT on a healthy Mac, and it should be BORING:
      asked     : <N> this session
      refused   : none — macOS drew every alert it was asked for
    If "refused" is a number, paste the whole block. The "↳ last refused
    said:" line names what you missed.
A2. Console: `_G.screenshotsReport()` — look for the new "routes :" line.
    EXPECT, before you have pressed ⇪4: "⇪4 has not been pressed this
    session".
A3. Press ⇪4 and drag a rectangle. Run it again.
    EXPECT: "routes : 1 press(es) — 1 on our selector · 0 on macOS's
    crosshair", and NO ⚠️ under it.

B. THE ONE THAT MATTERS — use the Mac for a day, then read it.
B1. After a normal day, Console: `_G.screenshotsReport()` and
    `_G.alertReport()`. PASTE BOTH.
    The three numbers that answer your report:
    · "routes" — how many ⇪4 presses went to OUR selector vs macOS's.
    · the ⚠️ line under it — how many of the macOS ones were a REFUSAL
      rather than a setting. THAT number is your "intermittently".
    · "↳ ⚠️ N press(es) found no folder to write to" — if this appears,
      your screenshots folder was missing at that moment, which would
      make ⇪4 do nothing at all. It is in OneDrive, so this is a real
      candidate and it has never been counted before.
B2. If ⇪4 does nothing at some point in that day, note roughly WHEN and
    run both reports straight away. The clock in each line is what lets
    me line it up with your Console.

C. MUST STILL WORK.
C1. ⇪4 captures, with the live 1280 × 720 readout and the shutter.
C2. ⇪5 scrolling capture still works.
C3. In the editor (⇪⇧1), ⌘A still drags on our selector.
C4. Any alert you normally see — ⇪Z learning a word, a copy confirmation
    — still appears. The wrapper counts; it does not gate.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. When ⇪4 "does not work", what do you actually see? Three different
    answers send me to three different places, and I cannot tell them
    apart from here:
    · nothing at all happens — no crosshair, no sound;
    · macOS's PLAIN crosshair appears (no black size box) — that is the
      fallback working, and the refusal count will prove it;
    · our dashed blue selector appears but the drag does not capture.
    One sentence is enough.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
