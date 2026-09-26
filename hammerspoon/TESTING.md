# TESTING — how to score release 6.283.0

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

## 6.283.0

6.283.0 verify with LL — 🧠 ⌥Tab SEES THE CONSOLE (KNOWN GROUND)
WHAT CHANGED: the Hammerspoon Console is remembered by ⌥Tab now, so it
is on the wheel from every desktop instead of only the one it is on.
WHY IT MATTERS: you have told me this twice. You were right twice, and
so was your own explanation — "unless I switch to that desktop I can't
see it". macOS will not tell us about another desktop's windows at
all, so this switcher keeps a memory of every window it has ever
listed. The console was the one thing that never went into it.

A. THE HEADLINE.
A1. Open the Hammerspoon Console. On THAT desktop, press ⌥Tab once.
    EXPECT: a Hammerspoon Console card, as before.
A2. Switch to another desktop. Press ⌥Tab.
    EXPECT: the Console card is STILL THERE, captioned
    "· remembered (another desktop?)".
    THIS is the step that failed before. If it is missing, stop and
    paste `_G.switcherReport()`.
A3. Turn the wheel to it and release ⌥.
    EXPECT: macOS carries you to that desktop with the Console front.
A4. Close the Console, then ⌥Tab and choose the card again.
    EXPECT: the Console OPENS. A card that does nothing is the failure
    this release exists to avoid — tell me if you get one.

B. PASTE BACK, PASS OR FAIL.
B1. `_G.switcherReport()` — new; this module had no report at all.
    The "console:" line has three states and I want whichever you get.
    "not seen yet this session" is HEALTHY on a boot where you have
    not opened the Console — it is not a fault, and it tells you the
    one thing to do (open it, press ⌥Tab once on that desktop).

C. MUST STILL WORK — the memory is shared with every window, so this
   is the regression sweep and it is the important half.
C1. Park a Chrome window on another desktop, ⌥Tab there once, come
    back, ⌥Tab. EXPECT: that window is still offered, as before.
C2. ⌥⇧Tab backwards, ← →, ↑ ↓, Home/End, Return, Esc — unchanged.
C3. A minimised window is still listed; switching to it un-minimises.
C4. ⌥Tab must not feel slower. If it does, B1's "last :" line names
    the phase and the app — paste it.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. The Console now stays on the wheel once you have opened it, for
    the rest of the session. Is that right, or is it clutter on the
    days you open the Console once and never want it again? "keep it"
    · "only while it is open" decides it — the second is a smaller
    wheel and brings back exactly the bug you reported.
D2. Should the MUSIC CARD be on ⌥Tab too? You asked in September and
    I have not built it. It is the one panel that keeps playing when
    it is not in front, which is the argument for doing it alone
    rather than adding every panel this config draws.



## 6.282.0

6.282.0 verify with LL — 🕒 THE REPORT ANSWERS AGAIN (KNOWN GROUND)
WHAT CHANGED: `_G.screenshotsReport()` no longer throws. Nothing about
capturing, naming or OCR moved.
WHY IT MATTERS: you ran the command I asked for and got a traceback.
`hs.timer.secondsSinceEpoch()` hands back 1758769234.8231 and Lua's
os.date refuses a fraction outright, so the `area` line did not print
something wrong — it took the whole report down. Since 6.264.0, in
every session where you had pressed ⇪4 even once. A fresh boot printed
fine, which is why neither of us saw it until you used the key first.
🚨 AND IT IS MY METHOD THAT BROKE, not just a line: almost every ask
I make of you ends in "paste the report". 6.274.0's steps literally say
press ⇪4, then run this command — so that test has been impossible to
run since the day it shipped, and I did not notice.

A. THE HEADLINE. Two commands.
A1. Console: `_G.screenshotsReport()`.
    EXPECT: a report. Not a traceback.
A2. Press ⇪4 and drag a rectangle. Then run it AGAIN.
    EXPECT: still a report, and the `area` line ends with a real
    clock — `· last pressed 21:14:07`.
    THIS is the step that failed before. If you get
    "bad argument #2 to 'date'" again, stop and paste it.

B. THE ARTEFACTS I HAVE BEEN ASKING FOR AND COULD NOT GET.
B1. Use the Mac for a day, then `_G.screenshotsReport()` and PASTE IT.
    Three lines answer three open questions at once:
    · `OCR` and `tried` — whether 6.281.0 stopped the green pills.
    · `routes` and the ⚠️ under it — your intermittent ⇪4.
    · `area` — which selector the last press used.
B2. `_G.alertReport()` as well. Together those are the whole ⇪4
    question, and this is the first build on which you can collect them.

C. MUST STILL WORK — this release touched only how a time is printed,
   so this is a short sweep.
C1. ⇪4 captures, with the live size readout and the shutter.
C2. ⇪5 scrolling capture. Its report line carries a clock too.
C3. A screenshot with words in it still gets renamed — your Console
    already shows this working ("🏷 OCR → Finder comment: …").

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. When a clock cannot be read, the line now says "time not recorded"
    rather than printing 1970. Is that the right wording, or would you
    rather it said nothing at all there? Either is one line.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
