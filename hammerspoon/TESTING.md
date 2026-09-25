# TESTING — how to score release 6.281.0

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

## 6.281.0

6.281.0 verify with LL — 🔁 THE GREEN PILLS STOP (KNOWN GROUND)
WHAT CHANGED: a screenshot that OCRs to nothing is now remembered as
tried, and the folder watcher stops offering it after three goes. ⌘9 is
unchanged and still OCRs anything you point it at.
WHY IT MATTERS: you said the green icons "loop and loop and loop like
it's running OCR nonstop." Each green pill in your menu bar is one
`shortcuts run "HS OCR"` process. A word-less image was never renamed,
so it never stopped qualifying, so it was re-OCR'd on every folder
event — for ever. And because reading a OneDrive placeholder HYDRATES
it, and a hydration is a write, the OCR was re-triggering the watcher
for the file it had just OCR'd. No outside input needed.
🚨 THIS IS ALSO IN 6.275.0, the build you rolled back to — the watcher
is 6.155.0 code. The rollback did not remove this; only this does.

A. THE HEADLINE. Do this FIRST.
A1. Install, then Console: `_G.screenshotsReport()`.
    EXPECT a new block, and on a fresh boot it should read:
      OCR     : 0 run · 0 named · 0 read no text · …
      yield   : no OCR has run this session
      tried   : nothing has OCR'd to nothing yet
A2. Use the Mac for an hour, normally. Watch the menu bar.
    EXPECT: pills appear when a screenshot arrives and GO AWAY. What
    must not happen is a pill that is always there, or pills that
    reappear the moment they vanish.
A3. `_G.screenshotsReport()` again. This is the artefact I want.
    EXPECT "OCR : N run" to be a small number — roughly the number of
    screenshots that actually arrived — and "tried : N file(s)
    remembered · M at the 3-try cap".
    A FAIL is "run" in the hundreds or thousands. Paste it either way.

B. PROVE IT ON PURPOSE, if you want to see the rule work.
B1. Put an image with NO words in it — a photo, a plain colour — into
    the screenshots folder, named like `Screenshot 2026-09-26 at
    10.00.00.png`.
    EXPECT: three OCRs (three brief pills), then silence. Before this
    release it would have gone on for as long as Hammerspoon ran.
B2. `_G.screenshotsReport()` — the "tried" line names it, and says the
    watcher no longer offers it while ⌘9 still does.

C. MUST STILL WORK. This release touched the naming path, so this is
   the regression sweep and it is the important half.
C1. ⇪4, drag, let go. The shot lands and is named from its words as
    ever.
C2. Drop a screenshot WITH text into the folder from the other Mac (or
    just take one). EXPECT: it is renamed to "… — <its words>.png"
    within a few seconds, exactly as before.
C3. ⇪⇧5 then ⌘9 (the naming sweep). EXPECT: it still names everything
    it can, and still reports "N had no readable text". ⌘9 must never
    refuse a file — if it ever says it is skipping something, that is a
    real failure and I want to know at once.
C4. ⇪5 scrolling capture, and ⇪⇧1 the editor. Unchanged.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.screenshotsReport()` after a full day. The "OCR" and "tried"
    lines are the whole answer, and they are the numbers that could not
    be asked for before: through the entire runaway the old report read
    "named on arrival 0 · left for ⌘9 0", because it counted only
    successes and only cap overflow. A word-less image incremented
    neither.
D2. If a pill is ever stuck on screen with nothing else happening,
    paste the report then too — that would be a hung `shortcuts`
    process, which is a DIFFERENT bug I have named and not fixed (there
    is no timeout on that task yet).

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Three tries per file — right? A file gets three OCRs before the
    watcher gives up on it. Fewer is quieter; more is more forgiving of
    a OneDrive file that had not finished downloading the first time.
    "three is fine" · "make it two" · "make it five" decides it.
E2. The memory is in RAM, not on disk, on purpose — writing it would
    mean a main-thread write into the very folder this watcher watches.
    The cost is that a reload or a reboot gives every word-less image
    three fresh tries, once. If you reload often and notice a small
    burst of pills after each one, tell me and I will move it to disk
    properly, with the write off the main thread.
E3. How many word-less screenshots do you actually have? One line:
    `ls "$HOME/Library/CloudStorage/OneDrive-Personal/2026 Screenshots" | grep -E '^(Screenshot |SCR-[0-9]{8}-)' | grep -vc ' — '`
    That number is how big the burst in E2 is, and it also decides
    whether ⌘9's 40-file cap needs raising — a separate release.



## 6.280.0

6.280.0 verify with LL — 🗑 DELETE A NOTE (KNOWN GROUND)
WHAT CHANGED: every note row in Hamsidian has a ✕ at its right-hand end.
It deletes the note — to <Vault>/.trash, never erased.
WHY IT MATTERS: you asked twice. It was not a bug: vault.lua has said
"No file delete — Finder and Obsidian do" since the vault was built,
when that was how you opened it. That stopped being true and nobody
re-asked the question.

A. THE HEADLINE.
A1. Press ⇪3. Look at the right-hand end of any note row.
    EXPECT: a dim ✕, visible WITHOUT hovering, brighter under the
    pointer and red when you are on it.
A2. Make a throwaway note (⌘N, call it "Delete me") and type a word.
A3. Click its ✕.
    EXPECT: the row disappears, and an alert reads
    "🗑 Delete me → .trash · _G.vaultUndelete() puts it back".
    A FAIL — and the most important one here — is the note OPENING
    instead of being deleted. Tell me immediately if that happens.
A4. In Finder, open <OneDrive>/Vault and press ⌘⇧. to show hidden
    files. EXPECT: a .trash folder with "Delete me  <date> <time>.md"
    in it, holding your word. NOTHING IS EVER ERASED.
A5. Console: `_G.vaultUndelete()`.
    EXPECT: "🕸 Delete me is back", and the note is in the list again.

B. THE ONE THAT PROTECTS YOUR WRITING.
B1. Delete a note that OTHER notes link to with [[Name]].
    EXPECT: the alert also says "⚠️ N notes link to it". That number is
    the thing you cannot see from the row you are clicking.
B2. Delete the note you currently have OPEN.
    EXPECT: the editor moves off it rather than sitting on a file that
    no longer exists. It goes back to your last note (6.277.0).
B3. Delete two notes with the SAME name from different folders.
    EXPECT: both are in .trash, as two separate files. If the second
    overwrote the first, that is a real failure — say so.

C. MUST STILL WORK.
C1. Click a note row on its NAME (not the ✕). EXPECT: it opens, as ever.
C2. ⌘F filter, ↑↓, ⏎ — unchanged.
C3. A scratch tab's own ✕ still closes the tab, not a note.
C4. Obsidian: open the Vault folder. EXPECT: the deleted note is gone
    from its list too, and .trash is ignored there.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.vaultReport()` — the new "deleted:" line names the count, the
    trash folder and the last note deleted.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Should a delete ASK first? I made it immediate, like the music
    history's ✕ you already use, because nothing is destroyed and
    `_G.vaultUndelete()` is one command. If you would rather have a
    confirm, say so — "ask me first" and it is a small release.
E2. .trash keeps everything for ever. Do you want it emptied on a
    schedule — 30 days, say — or left alone? I left it alone on
    purpose: a trash that empties itself is a trash that can lose the
    thing you go back for.
E3. Rename is the obvious next thing and I have NOT built it. Say if
    you want it.



## 6.279.0

6.279.0 verify with LL — 📓 WHAT FAILED TODAY (KNOWN GROUND)
WHAT CHANGED: one command, `_G.todayReport()`, names every tool that
failed today with the time and the reason — read back off a file, so it
survives a reload.
WHY IT MATTERS: your 4 PM double-check. The old ledger was in memory
only, so every reload wiped it — and a reload is likeliest exactly when
something has broken and you have just edited something.

A. THE HEADLINE.
A1. Console: `_G.todayReport()`.
    EXPECT on a healthy Mac, and it should be BORING:
      📓 WHAT FAILED TODAY — 2026-09-23
         log    : …/Logs/degrades-<your Mac>.csv
         ✅ nothing failed today — the log was read and holds no row…
         wrote  : 0 row(s) this session
A2. Make something fail on purpose: `_G.degrade("Test tool", "on purpose")`.
A3. `_G.todayReport()` again.
    EXPECT: "⚠️ 1 failure(s) across 1 tool(s)" and a line naming Test
    tool, the time, and "on purpose".

B. THE ONE THAT MATTERS — it has to survive a reload.
B1. Reload Hammerspoon (⌘⌃R, or the menu).
B2. `_G.todayReport()`.
    EXPECT: the Test tool row is STILL THERE. On every build before
    this one it would be gone. That is the whole release.
B3. `_G.degradeReport()` for contrast.
    EXPECT: it says nothing has degraded THIS SESSION — correct, and
    the difference between the two is the point.

C. IT MUST NOT LIE TO YOU WHEN IT CANNOT READ.
C1. Look at the "log :" path in A1 and confirm the file exists in your
    Logs folder. Open it — it is plain CSV, one row per failure:
    date, time, epoch, tool, reason.
C2. You do not need to break it on purpose, but know the rule: if that
    file ever cannot be read, the report says "COULD NOT READ IT …
    treat it as unknown, not as clear". It will never print "nothing
    failed today" about a log it could not open.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.todayReport()` at the end of a normal day. That is the artefact
    I want from now on whenever anything feels off — it turns "I think
    something didn't work" into a list with times on it.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Is the Console the right place, or do you want this somewhere you
    will actually look at 4 PM? The obvious next step is making it a
    ⇪D source (`@fails`) so it is in the search you already use. Say
    the word and it is one line plus a release.
E2. The file grows for ever, one short line per failure. On a healthy
    Mac that is a few rows a week. Tell me if you would rather it kept
    only the last N days — I left it uncapped deliberately, because a
    log that prunes itself is a log that can lose the thing you are
    looking for.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
