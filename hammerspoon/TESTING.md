# TESTING — how to score release 6.314.0

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

## 6.314.0

6.314.0 verify with LL — 🪟 A PICKER THAT WILL NOT OPEN (KNOWN GROUND)
WHAT CHANGED: when macOS refuses to put one of this config's pickers on
screen, the key now does nothing quietly and says why, instead of
throwing forty lines of traceback into the Console.
🔎 YOUR OWN LOG IS THE WHOLE RELEASE, 20:30:01:
    ⛔ LuaSkin: hs.chooser:show() ... NSInternalInconsistencyException
       -[NSRemoteView containingWindowWillOrderOnScreen:]
       ... init.lua:2055: ...
That is ANOTHER APP's popup — Safari's URL-completion helper or
Spotlight — being half-open at the moment you pressed the key. AppKit
refused, hs.chooser raised, and nothing in this config was catching it.
Canvases have been protected since 6.56.0 and alerts since 6.274.0; the
PICKERS — nineteen of them, the thing you press a key to get — were
bare.
🚨 AND init.lua:2055 IS NOT THE FAULT, in case the traceback made it
look like one: that line is the config deliberately re-raising a
shortcut's error so you SEE it. Deleting it would have hidden this and
everything like it. It is unchanged.

A. THE HEADLINE — and the honest part is that you cannot easily force
   it. So this is mostly "use the Mac and see what does NOT happen".
A1. Use ⇪V, ⇪D, ⇪space, ⇪Y, ⇪⇧V, ⇪T for a few days as normal.
    EXPECT: no change at all. Every picker opens as it did.
A2. If a picker ever does nothing, look at the Console.
    EXPECT a single readable line:
      ⚠️ picker: macOS refused to open the picker — usually another
         app's popup (Safari's URL completion, Spotlight) was
         mid-transition. Press the key again.
    and NOT a traceback. Press the key again — it opens.
A3. Console: `_G.popupShowReport()` — new.
    EXPECT on a healthy day:
      asked   : <N> picker(s) opened this session
      refused : none — macOS put every picker on screen
    PASTE IT. If "refused" is a number, that is the bug happening to
    you and the line under it names which picker and when.

B. IF YOU WANT TO TRY TO PROVOKE IT (optional, and it may not work —
   the timing window is small).
B1. Click into Safari's address bar so its completion list is dropping
    down, and press ⇪V in the same instant.
B2. EXPECT: either the picker opens normally, or it does not and you
    get the one line from A2. What must NOT happen is a traceback, and
    what must not happen next is the key being dead afterwards.

C. MUST STILL WORK — this touched the one function every picker in the
   config opens through, so this is the regression sweep and it matters
   more than A.
C1. ⇪V the clipboard · ⇪D unified search · ⇪space the launcher ·
    ⇪Y Chrome history · ⇪. the menus · ⇪⇧S snippets · ⇪T the task form.
    EXPECT: all open, all in the right place on the right monitor.
C2. ⌘-drag a picker to a new spot, close it, open it again.
    EXPECT: it reopens where you put it. (That memory is the record
    this release clears on a REFUSAL — it must be untouched on a
    success.)
C3. Esc closes a picker, and Esc again does whatever it did before.
C4. ⌘⌘ still opens the clipboard, ⌥⌥ still opens the menus.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.popupShowReport()` after a few days.
D2. If you ever get a traceback out of a picker again, paste the whole
    thing — the frame ABOVE init.lua:2055 is what names the surface,
    and that is the fact I could not have guessed.

E. 🔨 CRUDE OR ELEGANT.
E1. When this bit you at 20:30, what actually happened? Did the key do
    nothing and you moved on, or was the Mac unusable for a moment?
    I cannot tell from the log, and the answer is the tag.
E2. 📏 SAID RATHER THAN IMPLIED: this is the THIRD surface in this
    family — canvases (6.56.0), alerts (6.274.0), now pickers. If
    anything else of mine ever dies with
    `containingWindowWillOrderOnScreen:` in it, that is a fourth
    surface and the same fix, and the traceback is all I need.



## 6.313.0

6.313.0 verify with LL — 🔒 YOUR QUEUE SURVIVES A FAILED SAVE (KNOWN GROUND)
WHAT CHANGED: nothing you can press. The Jug Player writes its queue to
a temporary file and then renames it into place, instead of opening the
real file and writing over it.
WHY IT MATTERS: `io.open(path, "w")` empties the file BEFORE it writes
anything. If Hammerspoon died, the disk filled, or the write was
refused in that instant, your store was left at zero bytes — and the
loader reads zero bytes as "nothing queued", silently, after which the
next save makes it permanent. Your queue and your history are the only
things in this tool you cannot get back. A rename cannot half-happen,
so the file on disk is now either the old one or the new one.

A. THE HEADLINE — there is nothing to press, so this is the whole test.
A1. Queue some tracks, play one, close and reopen the card, reload
    Hammerspoon. EXPECT: everything exactly as before. This release
    must be invisible on a good day.
A2. Console: `_G.musicReport()` — the `store :` line should read
    `read N bytes — N queued · N history row(s)`.
A3. Look in `~/Library/Application Support/Hammerspoon/music/`.
    EXPECT: `player.json` and NO `player.json.tmp` left lying about.
    A stray .tmp after normal use is a real finding — tell me.

B. IF A SAVE EVER FAILS.
B1. You would get an alert ending "your saved queue is untouched", and
    the queue you already had would still be there next time. Paste
    that alert if you ever see it — it names which of three ways the
    write died.

C. 🔨 CRUDE OR ELEGANT.
C1. This never bit you that I know of — it is a hole closed before it
    cost anything, so my reading is ✨ ELEGANT, one pass. Correct me if
    you have ever opened the player to an empty queue you did not
    empty: that would mean it DID bite, and the row is 🔨.



## 6.312.0

6.312.0 verify with LL — 🔎 THE REPORT STOPS GUESSING (KNOWN GROUND)
WHAT CHANGED: `_G.musicReport()` can now say "I have not read that
yet" instead of reporting zero.
🚨 AND THIS IS THE FIX FOR A FALSE ALARM I RAISED. You sent a report
two seconds after a boot; it said your queue was empty, your history
was 0 tracks and the ⏯ tap was not running, and I told you your data
was gone. It was not. The store is opened and the tap is started a few
seconds AFTER boot, so none of those three had happened yet — and all
three printed the words for "it happened and there is nothing". Your
earlier good report was 37 seconds after its boot; the alarming one
was 2. That was the whole difference, and it was in your own paste.
🕘 AND YOUR QUESTION WAS RIGHT: no, we did not build the Jug Player 30
days ago — it shipped 2026-09-16, thirteen days before you asked. The
30 is how long a row is KEPT, not how much you have. The line says so
now instead of leaving you to wonder.

A. THE HEADLINE — this takes about a minute and needs a reload.
A1. Reload Hammerspoon and run `_G.musicReport()` IMMEDIATELY —
    within a second or two, before it has warmed up.
    EXPECT:
      queue    : ⏳ not read yet — see the store line below
      history  : ⏳ not read yet — see the store line below
      ⏯ keys   : ⏳ not started yet — the tap starts a few seconds
                 after boot, with the store.
      store    : ⏳ NOT READ YET — …not an answer yet…
    **A FAIL is seeing "empty" or "0 track(s)" or "⚠️ WANTED but not
    running" in that first moment** — that is the old behaviour.
A2. Wait ten seconds and run it again.
    EXPECT: your real queue, your real history, and the ⏯ line back to
    `watching ⏯ ⏮ ⏭`. If your tracks are there, nothing was ever lost
    and the alarm I raised was mine.
A3. Read the history line. EXPECT it to name the 30 as a window:
    `N track(s) kept · oldest Sep 28 — one row per file, and rows are
    kept for up to 30 day(s) (the WINDOW, not a claim that this Mac
    holds that much)`.

B. THE STATES THAT ONLY APPEAR WHEN SOMETHING IS WRONG.
B1. If the store line ever says **ZERO BYTES**, paste it at once —
    that is a write that was cut off, and it is the exact thing
    6.313.0 exists to prevent.
B2. If it says **UNREADABLE**, also paste it. Your file is still on
    disk in that case and was not overwritten.
B3. If the ⏯ line says `⚠️ WANTED but not running` TEN SECONDS after a
    boot, that is a real failure now rather than a timing artefact,
    and it names macOS's own reason.

C. MUST STILL WORK.
C1. ⇪⇧. and ⇪⇧pad. both open the card. Drop tracks, space, ↑↓, ⏎,
    ⌘1–9, ← →, ⌫, the ✕ on a history row.
C2. F8/⏯ drives it while the card is on screen (6.309.0).

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Is ⏳ the right way to say "not yet", or would you rather it said
    nothing at all on those lines until it knows? I chose to say it
    out loud because a missing line reads as a broken report.
D2. 🔨 CRUDE OR ELEGANT: the Mac was fine throughout — what broke was
    what the REPORT told you, and it told me the wrong thing too. My
    reading is that a diagnostic lying about your data is worse than
    it sounds, but it degraded rather than making anything unusable.
    Your tag.



## 6.311.0

6.311.0 verify with LL — ⌨️ ⇪⇧. OPENS THE JUG PLAYER (KNOWN GROUND)
WHAT CHANGED: ⇪⇧. (hyper + shift + the ordinary full stop) opens and
closes the Jug Player. ⇪⇧pad. still does too — a second door, not a
swap.
🆓 AND YOUR QUESTION, ANSWERED PROPERLY: ⇪⇧. was NOT taken. I did not
answer that from my notes — my notes are exactly what was wrong in
6.276.0, when you were handed ⇪⇧pad. as "available" and this player
had owned it for forty-five releases. I ran the gate's collision
auditor, which loads the REAL config and names every claim: 76 combos
bound, no ⇪⇧. among them. The near miss is ⇪. WITHOUT shift — that is
menu_search, your front app's own menus — and a comment in that very
file claimed "⇪⇧. is the network tools", which is wrong too
(net_tools is ⇪6). Two notes, one of them false. The registry is the
only thing that can answer this and it is what answered.
🚪 WHY YOU KEEP BOTH KEYS, since you said "instead of pad": ⇪⇧pad.
was shipped with no fallback ON YOUR OWN ANSWER in 6.231.0 ("Both
macs, home/work, use a full Apple Keyboard and Magic pad"), so the
premise moved rather than the decision being wrong. Removing it would
cost the two Macs the feature was built for and buy nothing. Say the
word and the numpad key goes — it is one line.

A. THE HEADLINE — twenty seconds, on the mini keyboard.
A1. Press ⇪⇧. (hold Caps Lock and Shift, press the full stop).
    EXPECT: the Jug Player card appears in the top-right corner.
A2. Press ⇪⇧. again. EXPECT: it closes.
A3. Press ⇪⇧pad. (if you are at a keyboard with a numpad).
    EXPECT: the same card, same corner, same state. One tool, two
    doors — not two cards.
A4. Open with ⇪⇧. and close with ⇪⇧pad., then the other way round.
    EXPECT: they drive the SAME card. **A FAIL here — two windows, or
    one key opening and the other doing nothing — is the bug this
    release can have.**

B. THE ONE THAT MUST NOT HAVE MOVED.
B1. Press ⇪. (no shift). EXPECT: the front app's MENUS, as always.
    That is menu_search and it is the key next door; if ⇪. now opens
    the music card, stop and tell me at once.
B2. Type a full stop in any app. EXPECT: a full stop.

C. MUST STILL WORK — the card itself is untouched.
C1. Drop two tracks on it; space, ↑↓, ⏎, ⌘1–9, ← →, ⌫, the ✕ on a
    history row, the repeat button.
C2. F8/⏯ drives it while the card is on screen and passes through to
    macOS while it is closed (6.309.0).
C3. Drag the card by its title strip; close and reopen — it is where
    you left it.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.musicReport()` — the heading should now read
    `🎵 JUG PLAYER — ⇪⇧. · ⇪⇧pad.`, and a new `doors :` line reads
    `2 way(s) in — ⇪⇧. · ⇪⇧pad.`. If that line ever says
    `⚠️ NONE bound`, nothing opens the card and I want it immediately.
D2. `_G.freeKeys()` — ⇪⇧. must NO LONGER be offered as free. Those
    rows are read from the live registry, so this is 6.276.0 paying
    for itself: nothing was edited by hand to make that happen.
D3. ⇪/ and search `jug`. EXPECT the card's title and its first row
    both to read `⇪⇧. · ⇪⇧pad.` — one row for the two keys, on
    purpose: the sheet's own auditor reads a combo listed twice as a
    conflict.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Is ⇪⇧. the right key, now that you have pressed it a few times?
    ⇪⇧, (comma), ⇪⇧[ and ⇪⇧] are also genuinely free — measured, not
    remembered. One word and it moves.
E2. Do you want ⇪⇧pad. REMOVED? I kept it deliberately and you asked
    for "instead of". Your call, one line either way.
E3. 🔨 CRUDE OR ELEGANT: the Jug Player was completely unreachable on
    the keyboard you are using — the tool was not degraded, it was
    absent. But the Mac itself was fine. My reading is that this is a
    feature ask created by a hardware change rather than a defect, so
    I have not logged it as a problem. Correct me if it belongs in
    the ledger as 🔨.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
