# TESTING — how to score release 6.278.0

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

## 6.278.0

6.278.0 verify with LL — 🔔 YOU FIND OUT WHEN A SEND FAILS (KNOWN GROUND)
WHAT CHANGED: when Hamsidian's Asana send does not go through, you now
get an alert, a macOS notification, and a line in the report that stays
there until a send actually succeeds.
WHY IT MATTERS: you asked how you would know. The honest answer was that
you would not — a rejected send wrote one line to the Console and did
nothing else. That breaks a rule you yourself set in 6.214.0 ("anything
that breaks must throw an error so I see it"), in the one place where
not knowing costs you what you captured.
🚨 NOTE THE 4 PM SEND IS STILL OFF — you switched it off in 6.254.0 and
this release does not turn it back on. Test it with the manual door.

A. THE HEADLINE — make one fail on purpose.
A1. Type something into a ⇪N tab so there is a day's worth to send.
A2. Turn Asana off for a moment: rename your token line in secret.lua,
    or just run A3 on a Mac where Asana was never configured.
A3. Console: `_G.scratchPadSend()`.
    EXPECT THREE THINGS, and all three matter:
    · an on-screen alert naming the tool and the cause;
    · a macOS NOTIFICATION saying your text is safe;
    · Console: `⚠️ Hamsidian 4 PM send: …`
A4. Console: `_G.scratchPadReport()`.
    EXPECT a line starting `⚠️ NOT SENT:` with the time, the reason, and
    "your text is still in the tabs". THAT is the line that is still
    there at 4 PM when you go looking — the alert will be long gone.
A5. Check the tab. EXPECT: every word still there.

B. THEN MAKE IT WORK.
B1. Put Asana back and run `_G.scratchPadSend()` again.
    EXPECT: a ✅ alert naming the task, and the task in Asana.
B2. `_G.scratchPadReport()` again.
    EXPECT the ⚠️ NOT SENT line is GONE, replaced by "nothing is
    waiting". A warning that never clears is one you stop reading.

C. IT MUST NOT CRY WOLF — this is the half that decides whether you
   keep the feature.
C1. With NOTHING written today, run `_G.scratchPadSend()`.
    EXPECT: no alert, no notification, nothing on screen. Just a
    Console line saying there was nothing to send. If an empty day
    warns you, tell me — I will take it out.

D. IF YOU WERE IN A MEETING (worth one try if you use Focus).
D1. Turn on a Focus mode, then make a send fail as in A3.
    EXPECT: no notification during Focus, and the Console says
    "🔕 Held until Focus ends". Turn Focus off — the notification
    arrives then. The alert still appears immediately either way.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Is a successful send saying "✅ Hamsidian → Asana: <task>" on screen
    welcome, or noise? I made success visible on purpose so that silence
    has one meaning instead of two — but you are the one who sees it
    every day. "keep it" · "failures only" decides it.
E2. Next release (6.279.0) is the log you asked for — every tool that
    failed today, in one command, so 4 PM is a single check rather than
    a memory test. Tell me if you would rather have it somewhere other
    than the Console.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
