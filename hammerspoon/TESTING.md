# TESTING — how to score release 6.315.0

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

## 6.315.0

6.315.0 verify with LL — ⌨️ THE ARROWS REACH THE HISTORY (KNOWN GROUND)
WHAT CHANGED: ↑ and ↓ now walk the queue AND the 🕘 history as one
list, which is how the card draws them.
🔎 WHY IT WAS MISSING, and it is not a regression: the cursor was
written when the card had one list, and the history was added under it
four releases later. ↓ off the last track wrapped back to the first,
so the history below was reachable by mouse and by nothing else. The
rule for the first list was never re-asked when the second appeared.

A. THE HEADLINE — thirty seconds.
A1. ⇪⇧. (or ⇪⇧pad.) and drop two or three tracks so the queue has rows
    and the 🕘 history below it has some too.
A2. Press ↓ until the highlight is on the LAST track in the queue, then
    press ↓ once more.
    EXPECT: the highlight moves into the 🕘 history, onto its FIRST
    row. **A FAIL is the highlight jumping back to the top of the
    queue** — that is the old behaviour exactly.
A3. Keep pressing ↓ through the history. At the last history row, ↓
    once more.
    EXPECT: it wraps to the top of the queue. One list, one loop.
A4. Press ↑ from the first history row.
    EXPECT: back onto the LAST queue row.
A5. Watch the highlight the whole way: exactly ONE row is ever lit.
    Two lit at once is a real finding — tell me.

B. WHAT THE KEYS DO DOWN THERE.
B1. Put the highlight on a history row and press ⏎.
    EXPECT: that track plays, exactly as clicking it does — and the
    highlight moves up to the queue row it just started.
B2. Put the highlight on a history row and press ⌫.
    EXPECT: that row is FORGOTTEN — the same thing the ✕ does. The
    queue is untouched and the file on disk is untouched.
    **A FAIL is a track leaving the QUEUE instead**; that is what ⌫
    used to mean everywhere and it is the worst thing this release
    could get wrong.
B3. Do B2 on the row in the MIDDLE of three history rows and check the
    right one went. It is forgotten by its path, not its number, for
    the same reason the ✕ is (6.272.0).
B4. ⌫ on a QUEUE row still takes it out of the queue, unchanged.

C. MUST STILL WORK — the cursor touches every key on this card.
C1. ⌘1–⌘9 still plays the Nth track.
C2. space still pauses and resumes. Try it with the highlight down in
    the history: it must pause what is PLAYING, not start a track.
C3. ← → still seek 5 s, ⇧← ⇧→ 30 s.
C4. Clicking a queue row plays it; clicking a history row plays it; the
    ✕ on a history row forgets it without playing it.
C5. Drag the card by its title strip; close and reopen — unchanged.
C6. F8/⏯ still drives it while the card is on screen (6.309.0).

D. THE EDGE I MOST WANT TESTED.
D1. ✕ (or ⌫) the LAST remaining history row while the highlight is on
    it. EXPECT: the highlight moves to the LAST queue row — the one
    just above where it was, not the top of the card.
D2. Empty the queue entirely with the card open and history present.
    EXPECT: the arrows still work, walking the history alone.
D3. With BOTH empty, press ↑↓.
    EXPECT: nothing happens and nothing breaks.

E. PASTE BACK, PASS OR FAIL.
E1. `_G.musicReport()` — a new `↑↓` line says where the cursor is in
    words: `on 🕘 history row 1 of 2 — "<track>"` or `on queue row 2 of
    3 — "<track>"`, and `nothing to walk` when both lists are empty.
    Run it with the highlight in each place; the line must CHANGE.
E2. If it ever says `⚠️ NO SUCH ROW, the highlight is drawn over
    nothing`, paste it — that is the clamp failing and it is the one
    state this release exists to make impossible.

F. A JUDGEMENT ONLY YOU CAN MAKE.
F1. Should ↓ off the last history row WRAP to the top of the queue, or
    stop there? I made it wrap, because the two are drawn as one list
    and that is how one list behaves — but a long history means a long
    way back. "wrap is right" · "stop at the ends" decides it.
F2. 🔨 CRUDE OR ELEGANT: the history was unreachable by keyboard, but
    it was always one click away and the Mac was fine. My reading is
    that this is a feature ask created by the card growing a second
    list, not a defect — so I have not put it in the ledger as a
    problem. Correct me if it belongs there.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
