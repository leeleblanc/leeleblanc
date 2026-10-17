# TESTING — how to score release 6.363.0

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

## 6.363.0

6.363.0 verify with LL — ✂️ THE TRIM (KNOWN GROUND)
WHAT CHANGED: nothing you press. init.lua went 3,797 → 3,748 lines, and
hunting the scruft found two things that were WRONG.
🚨 THE ONE THAT MATTERS: `_G.screenReport()` — the command I ask you for
whenever a panel opens on the wrong monitor — printed "a screen" about a
screen it could NOT read. Two of its lines handed `select(2, pcall(f))`
to a helper, and that is the ERROR MESSAGE when the read raises, so a
failed read fell through to the reassuring branch. In the one instrument
built because you reported a wrong monitor TWICE.
🚨 AND THE SCREEN ORDER WAS WRITTEN TWICE, both copies wrong since
6.236.0 — the release that made the POINTER outrank the front app's
main window. Two comments went on reciting the old order for 126
releases, fifteen lines above the code that is the order.

A. THE HEADLINE — one command, and it should be boring.
A1. Console: `_G.screenReport()`.
    EXPECT: a block naming the last rule that placed a panel, the front
    app, and what each candidate answers right now — `focused`,
    `pointer`, `main`, and a `rule :` line.
    EXPECT the `rule :` line to read "focused window · then the POINTER
    · then the front app's main window · then the main screen". That is
    the real order and it has been since 6.236.0.
A2. Read the `focused`, `pointer` and `main` lines.
    EXPECT each to name a real display or an em dash. **A FAIL is the
    bare words "a screen" with nothing after them** — that is the lie
    this release fixes, and it means a read failed.
A3. Press ⇪/ on each monitor in turn, then run it again.
    EXPECT the `last :` line to change and to name the monitor you were
    looking at.

B. MUST STILL WORK — this touched a file every key passes through, so
   this half matters more than A.
B1. A spread of ⇪ keys across different tools: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4,
    ⇪space, ⇪V, ⇪/, ⇪⇧,.
B2. ⇪V, ⇪space and ⇪Y all open on the monitor you are working on.
B3. ⌃⌥⌘L — the Asana dashboard, with its colour legend strip ABOVE the
    search field. Then ⌃⌥⌘C. Those are the §6 keys and §6 is the part
    of the file this release read most closely.
B4. ⌃⌥⌘ + an arrow key nudges an open picker; ⌃⌥⌘R clears the nudge.
B5. Copy three things and press ⇪V — the clipboard poll and its history
    are untouched, and `_G.clipboardPollReport()` still prints.
B6. Boot: All green, 72 modules, the usual ⇪ shortcut count.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.screenReport()` — the whole block, from whichever Mac.
C2. The boot line. The module and shortcut counts must be unchanged
    from 6.362.0; this release removed no feature.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. **§6, the Asana dashboard, is 537 lines of a feature living inside
    the orchestrator**, and moving it to a module would take init.lua
    from 3,748 to about 3,200 — which ends this ceiling instead of
    postponing it. I measured it rather than guessing: it reaches only
    seven things from the main file and every one of them is already
    published to modules, so the move is mechanical. I did NOT do it
    here, because it is a second change in a release you told me not to
    break anything in, and because it needs a test suite of its own.
    Want it as the next release?
D2. 🔨 Nothing was broken and nothing was lost — what was wrong is that
    a diagnostic answered confidently about a read that failed, which
    cost us a round the two times you reported the wrong monitor. My
    reading is that it degraded; your tag.



## 6.362.0

6.362.0 verify with LL — 🔤 THE SHEET HAS A FONT (KNOWN GROUND)
WHAT CHANGED: ⇪/ draws in Menlo now, where a capital I, a lowercase l,
a digit 1 and a pipe are four different shapes.
🔎 WHY: your own answer — "And the fonts". `textFont` appeared ZERO
times in that file, so every row had been drawing in the system face
since the sheet was written. That is the thing that cost you ⇪I for
267 releases, and it would have cost the next one too.

A. THE HEADLINE — ten seconds.
A1. Press ⇪/ and search `recent`.
    EXPECT the row's key to read ⇪I with a capital I you can TELL from
    a pipe — crossbars top and bottom.
A2. Search `\` (the backslash). EXPECT the arranger's split row, and
    its key to look nothing like the I above.
A3. Look at the sheet generally. It is monospaced now — that is the
    trade, and it is the whole point: every key name lines up.

B. MUST STILL WORK — the font changed the WIDTH of everything, so the
   wrapping is what to watch.
B1. Scroll the whole sheet. EXPECT no row running off the right edge
    and no row clipped. **A row that overflows is the one real failure
    mode here** — tell me and paste the row.
B2. Type to filter, ⌫ to edit, Esc to clear then close.
B3. Scroll with the wheel over the sheet; drag it somewhere and reopen.
B4. ⇪= to add an entry, ⇪- to remove one.

C. PASTE BACK.
C1. `_G.cheatSheetReport()` — empty and faults should both read none.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. **Do you want the whole sheet monospaced?** It is the honest trade:
    every key is unambiguous, and the prose beside it is wider and
    plainer. If you hate it: `settings = { cheatsheet = { face = false } }`
    puts the old face back exactly — and say so, because then the right
    answer is a second face for the key column only, which is a bigger
    change I did not want to make on a guess.
D2. Menlo vs something else — it is one table:
    `cheatsheet = { face = { name = "Courier", width = 1.20 } }`. The
    width must move WITH the name or the rows run off the column.
D3. 📏 Only ⇪/ got this. The webview panels, the pickers and the
    canvases still draw in whatever they used. Say if any of them has
    a key you have had to squint at.



## 6.361.0

6.361.0 verify with LL — 🔤 THE KEY YOU COULD NOT READ (KNOWN GROUND)
WHAT CHANGED: the Recent Documents card now tells you which key it
means, in words, where you are already looking.
🔎 AND YOU WERE RIGHT TO PUSH BACK — just not about the key. The card
says **⇪I, the LETTER I**, and it has opened Recent Documents since
6.93.0. I asked the registry rather than my notes this time: the
collision auditor loads the real config and answers `|i → recent
documents`. So the tool was there the whole time.
🔤 WHAT WAS WRONG IS THE FONT. core/cheatsheet.lua sets no typeface at
all, so every row draws in the system face — and a capital I there has
no serifs. It is a bare vertical stroke, identical to a pipe. You read
"⇪|", and the only vertical bar on a Mac keyboard is the backslash key,
which §0.4 maps to the window arranger's split. Both cards were telling
the truth and you still could not get there. 267 releases, lost to a
letter.

A. THE HEADLINE — twenty seconds.
A1. Press ⇪/ and search `recent`.
    EXPECT the card title to read **📂 RECENT DOCUMENTS (⇪I — the LETTER
    I, between U and O)** and the first row to say, in words, that it is
    the letter I and NOT the \| key beside Return.
    **A FAIL is the bare "(⇪I)" you photographed.**
A2. Now press it: Caps Lock + the **I** key, between U and O.
    EXPECT a panel of your nine most recently opened documents, then
    everything else you actually work on, searchable by name, folder,
    date and extension.
    This is almost certainly the first time you have seen it.
A3. ⇪⇧I (same key, add shift). EXPECT a re-scan and what it has learned.
A4. In the panel: ⏎ opens · ⌘⏎ reveals in Finder · ⌥⏎ copies the path
    · ⌘1–⌘9 open a numbered recent · type to search · Esc closes.

B. MUST STILL WORK — the key you actually pressed is untouched.
B1. ⇪\ (Caps Lock + the \| key). EXPECT two recent windows side by side,
    exactly as before. It did nothing wrong and nothing changed.
B2. ⇪⇧W — still the activity tracker's documents list. That is a
    different tool and both keys stay.
B3. ⇪/ still filters, scrolls and closes on Esc.

C. PASTE BACK.
C1. `_G.recentDocsReport()` — there is a new first line:
      key     : ⇪I — the LETTER I, between U and O  ·  ⇪⇧I re-scans
    so the Console answers "which key is this?" without the card.
C2. The `entries :` line under it. If it reads "cache only — no scan
    finished yet" more than a minute after a boot, Spotlight is not
    answering and THAT is a real finding — paste it.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. **Is ⇪I the right key at all?** You have never been able to use it,
    so you have no habit to protect. I did NOT move it on a guess. If
    you would rather it were somewhere you will reach for — ⇪⇧\ (the
    pipe, which is genuinely unclaimed) or a letter — say which and it
    moves in one line.
D2. **Should I set a font on the whole cheat sheet?** That closes this
    at the source for every row at once — no card could ever print an
    unreadable key again — and it restyles the sheet you already like.
    Your taste, and its own release. I have NOT done it.
D3. 🔨 While this was broken, was the Mac unusable, or did it just not
    do the thing? My reading is the second — nothing failed, a tool was
    simply unreachable — but the tag is yours.



## 6.360.0

6.360.0 verify with LL — 🗑 THE GRID ARROWS STOP ACCELERATING (KNOWN GROUND)
WHAT CHANGED: holding an arrow after the grid lands no longer speeds
up. Every repeat is the same 8 pt, like holding an arrow in a text box.
🗑 AND IT IS DELETED, NOT SWITCHED OFF — there is no setting to turn it
back on, because a knob nobody reads is a line that silently does
nothing. One word and it comes back as a release.

A. THE HEADLINE — twenty seconds.
A1. ⇪X, type three letters to land. Now HOLD an arrow for two seconds.
    EXPECT: a steady crawl at one speed. **A FAIL is it taking off**
    after the first repeat — that is the old behaviour.
A2. Hold it long enough to cross a good part of the screen, then stop.
    EXPECT: the pointer is where you expected, not past it. That
    overshoot is my guess at WHY you wanted this gone — if it was a
    different reason, D1.
A3. TAP an arrow once. EXPECT: 8 pt, exactly as before — unchanged.
A4. ⇧+arrow. EXPECT: 1 pt, unchanged.

B. MUST STILL WORK — this touched the handler every arrow goes through.
B1. Land, then nudge with all four arrows. The yellow box and the
    crosshair badge follow the pointer.
B2. Land near a screen EDGE and hold an arrow into it. EXPECT: it stops
    at the edge and the overlay is still drawn correctly.
B3. Land, nudge, then press space. EXPECT: it clicks where you NUDGED
    to, not the original cell centre.
B4. The two-letter split after landing, ⌫, ⎋, and ⇪⇧X's
    click-on-arrival are all untouched — worth one pass each.
B5. ⇪⇧L (find the pointer) is unchanged.

C. PASTE BACK.
C1. `_G.mouseGridReport()` — the `nudge   :` line now reads
    `tap 8 pt · ⇧ 1 pt · HOLD repeats at 8 pt — no acceleration, on his
    word (6.360.0)`. If it still mentions a climb, the release did not
    take.
C2. The `cells   :` line in the same report — the REAL cell size on the
    Mac you are sitting at. I want that number from BOTH screens; it is
    the input to D2 and I have been reasoning about it from arithmetic
    rather than from your display.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. WHY did you want it gone? "It overshot" and "it was erratic" and "I
    never hold the key" are three different answers and only the first
    means `nudgeStep` could safely go UP (12 or 16 pt a repeat) to get
    the distance back. I did NOT raise it on a guess.
D2. See the 🖱 MOUSE GRID item in Open items for the two-keystroke
    proposal and its arithmetic. It needs one word from you, not a
    report.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
