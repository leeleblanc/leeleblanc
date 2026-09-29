# TESTING — how to score release 6.311.0

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



## 6.310.0

6.310.0 verify with LL — 🎯 THE POINTER RINGS STEP OUTWARD (KNOWN GROUND)
WHAT CHANGED: each of the three rings ⇪⇧L throws is 10% wider than the
one before it, and the whole mark got bigger to hold the outermost.
Your number, your answer — I have not substituted one of mine.

A. THE HEADLINE — ten seconds.
A1. Press ⇪⇧L. EXPECT: three white rings leaving the pointer, each
    visibly larger than the last, repeating for six seconds.
A2. Compare it to how it looked on 6.306.0 if you can. The outermost
    ring now reaches 21% further out than it used to.
A3. Console: `_G.mouseGridReport()` — a new "↳ growth" line reads
    `each ring +10% on the one before it · outermost NNN pt of a NNN pt
    canvas`. PASTE IT.

B. MUST STILL WORK.
B1. ⇪X: the grid draws, three letters land, the box splits by letter,
    arrows nudge, Esc closes. Nothing about the grid changed.
B2. On the 4K at full points the ring should still be bigger than on
    the Air — the scale rule is untouched.

C. A JUDGEMENT ONLY YOU CAN MAKE — and this is the one I want.
C1. Is 10% enough? You asked for that number and I built exactly it,
    but "more obvious" is your eye, not mine. If it still gets lost,
    say which of these: bigger overall (`locateRadius`), MORE rings
    (`locateRings`), a steeper step (`locateRingGrow`), or longer
    (`locateSecs`). One word and it is a default change, not a release.
C2. 🔨 CRUDE OR ELEGANT: did this ever make the Mac unusable, or did it
    just not stand out? My reading is neither — it is a feature ask,
    not a defect — so I have logged it as a request rather than a
    problem. Correct me if it belongs in the ledger.



## 6.309.0

6.309.0 verify with LL — ⏯ THE PLAY KEY, ONLY WHILE THE CARD IS UP (KNOWN GROUND)
WHAT CHANGED: the Jug Player takes ⏯ ⏮ ⏭ only while its card is ON
SCREEN. Closed, the key goes back to macOS.
🚨 AND YOU WERE RIGHT THAT MY LAST FIX WAS NOT REAL. 6.289.0 gated on
"has a queue" — a rule I chose, not one you asked for — and closing
the card deliberately does not stop the sound, so a closed card went
on holding the key for as long as a queue survived it. Visibility is
the gate now.

A. THE HEADLINE — this is the whole test.
A1. ⇪⇧pad., drop two tracks, something plays. Press F8/⏯ — it pauses.
    Press again — it resumes. Unchanged.
A2. Now CLOSE the card (⇪⇧pad. again). The music keeps playing, as it
    always has.
A3. Press ⏯.
    EXPECT: the Jug Player does NOT react. The key goes to macOS — so
    if Music.app or a YouTube tab has audio, THAT pauses instead.
    **A FAIL here is the card reacting**, and it is the bug you
    reported twice. Tell me at once.
A4. ⇪⇧pad. to bring the card back. Press ⏯ — it works again.

B. THE ONE THAT STOPS A DEAD KEY.
B1. Open the card with NOTHING queued. Press ⏯.
    EXPECT: it passes through to macOS. An open card with an empty
    queue must not eat a key it cannot act on. That check is mine, not
    yours — say if you would rather an open card always took the key.

C. MUST STILL WORK.
C1. With the card open: space, ↑↓, ⏎, ⌘1–9, ← → all unchanged.
C2. F7 and F9 step back and forward while the card is open, and pass
    through while it is closed.
C3. The volume keys stay macOS's — your own decision in 6.231.0.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.musicReport()` — a new "↳ right now" line says in words what ⏯
    would do at this moment: `the card is closed — macOS keeps the
    key` / `nothing is queued — macOS keeps the key` / `the card is
    open and holding a queue`. Run it with the card open and again
    with it closed; the line must CHANGE.
D2. The "↳ by route" line still tells me whether your F8 arrives as a
    media key or a plain function key.

E. 🔨 CRUDE OR ELEGANT.
E1. Did the card holding ⏯ while hidden ever leave you unable to use
    the Mac — stuck unable to pause something — or was it an annoyance
    you worked around? Your answer tags the row, and it took three
    passes (6.289.0, 6.291.0, this), so it is not elegant either way.



## 6.308.0

6.308.0 verify with LL — ⌨️ ⌘⌘ OPENS THE CLIPBOARD (KNOWN GROUND)
WHAT CHANGED: ⌘⌘ works. It had never been registered — not once, on
any boot since 6.292.0.
🔎 WHY ⌥⌥ WORKED AND ⌘⌘ DID NOT, because it is nothing you could have
guessed: clipboard_history.lua had TWO functions called `M.warm` — the
one at the bottom that registers ⌘⌘, and one written inside setup()
that reads the clipboard store. setup runs after the file is loaded,
so the second one overwrote the first before Hammerspoon ever called
it. menu_search has only one, which is the whole difference.
🚨 AND THE REPORT SAID IT WAS FINE. `_G.clipboardReport()` printed
"⌘⌘ : watching · 0 open(s) this session" — because it inferred health
from the absence of a recorded complaint, and there was no complaint:
the code that would have recorded one never ran. That is exactly the
distinction that report exists to keep, broken inside itself.

A. THE HEADLINE.
A1. Tap ⌘ twice, quickly, nothing else held.
    EXPECT: the clipboard history opens — the same panel ⇪V gives you.
    **This is the whole release.**
A2. Esc, then ⇪V. EXPECT: the identical window. One function, two doors.
A3. Left ⌘ and right ⌘ both work.
A4. Console: `_G.doubleTapReport()`. EXPECT BOTH gestures listed now:
    `⌘⌘ : clipboard history` AND `⌥⌥ : the front app's menus`, under
    one `watcher : running`. PASTE IT.
A5. `_G.clipboardReport()` — the ⌘⌘ line must read `watching · N
    open(s)`. If it EVER reads `⚠️ WANTED but NOT REGISTERED`, that is
    the new fourth state doing its job — paste it.

B. THE ONES THAT PROTECT YOUR TYPING — these matter more than A.
B1. ⌘C, ⌘V, ⌘S, ⌘Tab, ⌘W as normal. EXPECT: nothing opens.
B2. HOLD ⌘ for a second and release, twice. EXPECT: nothing.
B3. Tap ⌘, type a letter, tap ⌘. EXPECT: nothing.
B4. Hold ⌘ AND ⌥ and tap twice. EXPECT: NEITHER opens.
B5. ⌥⌥ still opens the menus. ⌃⌃ still opens the editor picker.
B6. Type normally for a while — no missed characters, no lag.

C. MUST STILL WORK — the merge touched the clipboard's own load.
C1. Copy three things, press ⇪V. EXPECT: all three, newest first.
C2. Reload Hammerspoon, press ⇪V. EXPECT: your history is still there.
    That read used to live in the function that was being destroyed;
    if the history came back EMPTY, stop and tell me immediately.
C3. ⇪⇧V still edits and deletes rows.

D. 🔨 CRUDE OR ELEGANT.
D1. ⇪V always worked, so my reading is that this degraded gracefully —
    a feature silently absent, not a Mac you could not use. One pass.
    If you agree it is ✨ ELEGANT; if being told "watching" while it
    was dead counts as worse than that, say so and it goes down 🔨.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
