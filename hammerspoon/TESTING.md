# TESTING — how to score release 6.379.0

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

## 6.379.0

6.379.0 verify with LL — ⏱ A TIMER YOU TALK TO (KNOWN GROUND)
WHAT CHANGED: there is a new tool. Hold Caps Lock and Shift and press
the letter **T** — next to R and Y — and a box asks how long. Type it
the way you would say it out loud. A card counts it down in the
top-right corner under the clock, shaped like the pomodoro.
🆓 AND ⇪⇧T WAS TAKEN, which you asked me to check: it was "type the
clipboard". I asked the registry rather than my own notes, and every
other shifted letter is spent too (⇪⇧C, ⇪⇧D and ⇪⇧R are
copy-on-select, the diagnostic report and the nudge reset; ⇪⇧Z is
reserved on your word). 🔑 I gave you T anyway and moved the other
tool, because your asking for T is itself evidence you do not reach
for it to type the clipboard — and that tool loses a shortcut, not the
feature. Step D is where you check that.

A. THE HEADLINE — two minutes.
A1. Press **⇪⇧T** (hold Caps Lock and Shift, press T).
    EXPECT: a box reading "How long? 15s · 25 · 24h and 35m · …".
A2. Type `24h and 35m` and WATCH THE ROW as you type.
    EXPECT: **"⏱ 24 hours 35 minutes"**, and under it "⏎ starts it ·
    24:35:00 on the card". That row is the point of the box: it shows
    what it understood BEFORE you commit to it.
A3. Press ⏎. EXPECT: a card top-right counting down from 24:35:00,
    with "24 hours 35 minutes" written under the digits.
A4. Try the rest, one at a time: `15s` · `15 seconds` ·
    `twenty five minutes` · `half an hour` · `an hour and a half` ·
    `5m30s` · `2 days`. All of them work.
A5. Type `25` on its own. EXPECT the row to read "25 minutes — no unit
    given, so minutes". A bare number is MINUTES and it tells you so
    rather than deciding quietly.
A6. Type `banana`. EXPECT `could not read "banana"`, and ⏎ does
    nothing. Then type `1:30`. EXPECT a refusal explaining it cannot
    tell a minute and a half from an hour and a half.

B. HIDE IS NOT STOP — your two sentences, and they are different.
B1. With a card counting down, press **⇪⇧T** again.
    EXPECT: the card goes away. **The timer is STILL RUNNING.**
B2. Wait a minute, press ⇪⇧T again.
    EXPECT: the card is back showing a minute LESS — not the length
    you asked for. That is the proof it kept counting out of sight.
B3. Console, while it is hidden: `_G.timerReport()`.
    EXPECT a line shouting **THE CARD IS HIDDEN, and it is still
    counting**. That wording exists so a timer you have forgotten
    cannot read the same as no timer at all.

C. STOPPING IT — and here I did NOT do the literal thing you asked
   for, so please read this before judging it.
C1. With the card up, put the **mouse pointer on the card** and press
    **esc** (top-left of the keyboard). EXPECT: it stops, card gone.
C2. Start another. Within ten seconds of the card appearing press
    **esc** with the pointer anywhere at all. EXPECT: it stops.
C3. Start another. Wait a minute, leave the pointer elsewhere, press
    **esc**. EXPECT: **nothing happens** — and the card's bottom line
    now reads **⇪⎋** instead of "esc stops it".
    🚨 WHY: binding esc swallows it everywhere, and this timer can run
    for days. For a day esc would not close a dialog, would not leave
    a full-screen film, would not cancel a Spotlight search, and
    nothing on screen would explain why. So esc is yours in the
    moments you actually reach for it, and the card's last line always
    says which state you are in.
C4. The one that always works: **⇪⎋** — Caps Lock and the esc key —
    from anywhere, pointer or not, card up or hidden. EXPECT: it stops.
    **If you would rather have plain esc all the time and accept
    losing it in your apps, say so and it is one line.** Your Mac.

D. WHAT MOVED, so it is not a surprise next week.
D1. "Type the clipboard" is **⇪⇧\** now — Caps Lock, Shift and the
    \| key beside Return. Press it in a field that refuses ⌘V.
    EXPECT: it types your clipboard out, exactly as ⇪⇧T used to.
D2. It is ALSO still in the ⇪; list, where it has been since 6.158.0:
    press ⇪; and look for the ⌨️ row. That is why moving its key costs
    a shortcut and not the feature.
D3. ⇪/ and search `timer`, then `power`. Both cards are right, and the
    power tools card now says where the \| key is, in words.

E. THE ALARM — worth setting a 20-second one for.
E1. Start `20s` and let it run out while you work in something else.
    EXPECT: the card FLASHES amber, an alert says TIME UP and names
    the length, a notification arrives, and you hear Submarine a few
    times. **And it stays there flashing until you answer it** — ⇪⇧T
    or esc clears it.
E2. The one that matters: start `20s`, press ⇪⇧T to HIDE the card, and
    let it run out.
    EXPECT: the card PUTS ITSELF BACK and goes off exactly as in E1.
    A timer you put away must still be able to reach you; that is what
    makes hiding safe.

F. A RELOAD DOES NOT LOSE IT — why the long durations are usable.
F1. Start `30m`, then reload Hammerspoon (⌘⌃R).
    EXPECT: a Console line saying a timer was still running, and the
    card back with about 29 minutes left — not 30.
F2. Start `2m`, reload, and keep Hammerspoon down past the two minutes
    if you can.
    EXPECT: it does NOT go off late. It says **"Your 2 minutes ended
    while Hammerspoon was not running"**. An alarm two hours late is
    indistinguishable from one going off now, so it is said rather
    than fired.

G. PASTE BACK.
G1. `_G.timerReport()` — the whole block, once with something running
    and once with nothing. Its `esc` line says whose that key is right
    now and quotes what the card is showing, which is the one thing I
    cannot see from here.

H. A JUDGEMENT ONLY YOU CAN MAKE.
H1. Is a bare number MINUTES right? `25` → 25 minutes is my call; say
    the word and I change the default.
H2. Ten seconds is how long esc stays yours after the card appears.
    Too short to be useful, or too long to be safe? It is a number.
H3. Seven days is the longest timer it will set. Enough?
H4. The card is the pomodoro's shape but NOT its code. Folding the two
    into one drawing helper is its own release, because it would touch
    a module that works. Say if you want them merged.
H5. ONE TIMER AT A TIME, and this is the one I expect to annoy you
    first: with one running, ⇪⇧T hides or shows the card — it does not
    offer to start another. So a 25-minute timer followed by a
    5-minute one means stopping the first (⇪⎋) and pressing ⇪⇧T again.
    Should the key offer to REPLACE a running timer, or should several
    run at once? The first is small; the second is a different card.



## 6.378.0

6.378.0 verify with LL — 🔒 THE KEYBOARD LOCK THAT NEVER SPOKE
(KNOWN GROUND)
WHAT CHANGED: if macOS's Secure Input is already on when Hammerspoon
starts, you are told. It used to be told to nobody, for ever.
🔎 WHY IT MATTERS MORE THAN ITS SIZE: Secure Input is a password
field's lock, and while it is held NOTHING in this config works —
every snippet, autocorrect, and most ⇪ shortcuts, with no error
anywhere. In 6.196.0 Chrome left it on and took your keyboard for
four hours while the Console said "All green · 104 ⇪ shortcuts". The
announcement only fired on a CHANGE, and the first reading is not a
change — so a Mac that BOOTED into that state said nothing at all.

A. THE HEADLINE — and the happy path is silence.
A1. Reload. Wait a minute. Console: `_G.secureInputReport()`.
    EXPECT `state  : off — nothing is holding the keyboard`, and NO
    new line in the Console about Secure Input. That silence is the
    release working on a healthy Mac.
A2. To see the other half, click into a password field (1Password's
    unlock, a login page) and leave it there. Then reload
    Hammerspoon.
    EXPECT, within a minute: `🔒 SECURE INPUT IS ON — <app> has
    locked the keyboard …  (ALREADY held when this config started —
    it did not just happen)`.
    **That parenthesis is the whole release.** On every build before
    this one you would have got nothing.
A3. `_G.secureInputReport()` while it is held.
    EXPECT a `when   : ALREADY HELD when this config started` line
    under the state. Leave the field and the next probe says
    "🔓 Secure Input released".

B. MUST STILL WORK.
B1. Make it change WHILE running: with Hammerspoon up and quiet,
    click into a password field.
    EXPECT the same 🔒 line but WITHOUT the "ALREADY held" wording —
    that one really did just happen.
B2. `probes :` must show a `change(s) seen` count that goes up for
    B1 and NOT for A2. A boot into a held keyboard is not a change.
B3. Normal use for a day: no new Console noise, no alerts.

C. PASTE BACK.
C1. `_G.secureInputReport()` from an ordinary morning, and again if
    you ever meet A2 by accident. If a ⇪ key ever goes dead for no
    reason, that command is now the first thing to run.



## 6.377.0

6.377.0 verify with LL — ⌨️ WHAT HAPPENS WHEN YOU PICK A SNIPPET
(KNOWN GROUND)
WHAT CHANGED: nothing about what ⏎ does. What changed is that you can
now see what it did.
🔎 AND YOUR SENTENCE IS ALREADY TRUE — "when I select a snippet 99% of
the time I want it to instantly paste". It does, and it has since the
picker was built: a short snippet is TYPED straight at the caret, and
anything with a newline in it is put on the clipboard, ⌘V'd, and your
clipboard put straight back (a synthetic Return in a Teams or Asana
box SENDS the message, which is why multi-line is never typed). What
was missing is any way to tell that from "it did nothing": not one of
nineteen hundred snippets counted an insert.

A. THE HEADLINE — two minutes.
A1. ⇪⇧S, pick a short snippet (an email address, an emoji).
    EXPECT it appears at your caret, instantly, as always.
A2. ⇪⇧S, pick a MULTI-LINE one (the out-of-office, a signature).
    EXPECT it appears, and your clipboard is back to what it was a
    second later — ⌘V somewhere and check.
A3. Console: `_G.snippetsReport()`. Two new lines:
      ⏎ pick: 2 — 1 typed at the caret · 1 pasted (⌘V, clipboard put
              back) · 0 REFUSED
      typed : 7 — 7 typed at the caret · 0 pasted · 0 REFUSED
    PASTE THOSE. The first number is the answer to your sentence, and
    it is the first time it has been askable.
A4. The `↳ last in :` line names the most recent one and HOW it went.

B. THE HALF THAT PROTECTS YOU.
B1. If a pick ever inserts NOTHING, you now get an alert naming the
    snippet and macOS's own reason — it used to go to the Console and
    nowhere else. Paste it if you ever see it; the report keeps the
    last one on a `↳ ⚠️ last REFUSED` line.
B2. Type a trigger normally for a day. EXPECT no change at all, and
    the `typed :` count climbing while `⏎ pick:` does not.

C. A JUDGEMENT ONLY YOU CAN MAKE.
C1. If a pick ever feels like it goes nowhere — into the picker
    instead of your document — say so with the report. That is the
    one failure I cannot see from here, and the counts are what would
    prove it.



## 6.376.0

6.376.0 verify with LL — 📅 A SCRATCH NOTE IS NAMED FOR TODAY
(KNOWN GROUND)
WHAT CHANGED: a new Hamsidian tab is called by the day you made it
instead of "Scratch 1".
🔎 Your ask: "Scratch not should be prefixed with Today's date." And
"Scratch 1" is the name 6.165.1 gave an empty tab, on your own
complaint then — "Untitled ×2 told me nothing". A number tells you
nothing either.

A. THE HEADLINE — twenty seconds.
A1. ⇪N, then ⌘T for a new tab.
    EXPECT the tab reads **Mon Oct 20** (today), not "Scratch 2".
A2. ⌘T again. EXPECT **Mon Oct 20 · 3** — the date plus its place, so
    two empty tabs made today can still be told apart.
A3. Type a line in one. EXPECT the title becomes YOUR LINE, as it
    always has. That is the pad's whole design and it is unchanged.
A4. Close and reopen ⇪N. EXPECT the dates survive.

B. THE OTHER READING, IF I CHOSE WRONG.
B1. I read your sentence as "the DEFAULT name", because putting the
    same six characters in front of every typed row is noise rather
    than a journal. If you meant every title:
    `settings = { scratch_pad = { titleDate = "always" } }` → every
    tab reads "Mon Oct 20 · Buy milk".
    **Say which and I will change the default rather than leave you a
    line to type.**
B2. `titleDate = "off"` is the old "Scratch N" exactly.

C. PASTE BACK.
C1. `_G.scratchPadReport()` — a new `📅 dates:` line says which
    reading is on and counts any tabs that carry no date stamp (those
    keep their old name rather than claiming a date nobody recorded).



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
