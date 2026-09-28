# TESTING — how to score release 6.310.0

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



## 6.307.0

6.307.0 verify with LL — 🔎 ⌘F FINDS IT, ⏎ OPENS IT (KNOWN GROUND)
WHAT CHANGED: in Hamsidian, ⏎ in the ⌘F filter box now OPENS the note
the list is showing you instead of creating a new one with the text
you typed.
🔎 YOUR SCREENSHOT DIAGNOSED IT: the filter said "examin", the NOTES
section showed "09-21-26 Examining relationship", and the editor held
a brand-new "# examining". The filter box has three modes, and search
and tasks mode have ALWAYS opened the first hit. Notes mode alone sent
the typed text as the name — and opening a note that is not there
creates it, by design. One mode of three, and it was the one that
writes a file into the folder holding your writing.

A. THE HEADLINE.
A1. ⇪3. Press ⌘F and type enough of an existing note's name to narrow
    the list — "examin" will do.
A2. Press ⏎ WITHOUT pressing ↓ first.
    EXPECT: the note in the list OPENS, with its real contents.
    **A FAIL is a new empty note called "examin"** — that is the bug,
    unchanged.
A3. Look at the vault folder. EXPECT: no new file was created.

B. CREATING STILL WORKS — it has to, or this trades one bug for another.
B1. ⌘F and type something no note matches — "zzznothing".
    EXPECT: the list says `no note matches — ⏎ creates "zzznothing"`.
B2. Press ⏎. EXPECT: it creates that note and opens it, as before.
B3. ⌘N still opens the naming bar and creates by name.

C. THE EDGES.
C1. ⌘F and type `#` plus a tag. EXPECT: it filters by tag and ⏎
    creates nothing.
C2. ⌘F, narrow to a TEMPLATE (type "Meet"), press ⏎. EXPECT: the
    template opens. It is a note in the list, so opening it is right.
C3. ⌘F, then ↓ to a row further down, then ⏎. EXPECT: THAT row opens —
    the arrow keys were always right and are untouched.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.vaultReport()` — a new "⏎ filter" line counts them apart:
    `N opened the match · N created a new note`, with the last one
    named. After A2 and B2 that should read 1 and 1.

E. 🔨 CRUDE OR ELEGANT — and please answer this one.
E1. How many of these stray notes are in your vault? They will be
    named after whatever you typed into the filter box. If there is a
    pile of them, say so and the next release is a command that lists
    every note whose name matches a note you already had — I will not
    delete anything without you seeing the list first (6.280.0).
E2. Hamsidian stayed usable throughout, so my reading is ✨ ELEGANT,
    one pass. But it was writing into the one folder where a mistake
    costs your own words, so if you call that 🔨 CRUDE I will not
    argue — it is your tag.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
