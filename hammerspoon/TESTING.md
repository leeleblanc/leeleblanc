# TESTING — how to score release 6.318.0

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

## 6.318.0

6.318.0 verify with LL — 📐 ⇪4 HAS CROSSHAIRS (KNOWN GROUND)
WHAT CHANGED: ⇪4 now draws full-screen crosshairs that follow the
pointer, and the numbers are on screen BEFORE you press anything.
🔎 YOU WERE RIGHT ON EVERY COUNT, INCLUDING THE LAST ONE. ⇪⇧4 is
macOS's own `screencapture -i` and keeps its HUD — crosshairs and
live coordinates from the instant the key is pressed. ⇪4 was that too
until 6.264.0 moved it onto OUR selector, on your ask for a better
pixel readout. And our selector drew a dashed band and a dim wash and
nothing else until the button went down: no crosshair at any point,
no numbers until a drag. So the keys really did differ, the
difference really did arrive with a release of mine, and "it was
working before" is the plain truth.
📏 I did NOT put ⇪4 back on macOS's crosshair, and that is a decision
you can reverse: it would hand back the crosshairs and take away the
live 1280 × 720 you asked for twice. What was missing is the half
macOS was giving you for free, and it is ours to draw.

A. THE HEADLINE — ten seconds.
A1. Press ⇪4 and DO NOT MOVE OR CLICK.
    EXPECT, at once: a thin white vertical line and a thin horizontal
    line crossing at the pointer, and a black box with the pointer's
    position in it — e.g. `1182, 640`.
    **A FAIL is the old behaviour: a dim screen and nothing else.**
A2. Move the mouse without pressing.
    EXPECT: both lines follow, and the numbers change with them.
A3. Now press and drag.
    EXPECT: the dashed band appears, the crosshair keeps following,
    and the box switches to the SIZE — `1280 × 720` — exactly as
    before.
A4. Let go. The shot lands and is copied, unchanged.
A5. Press Esc instead of dragging: it cancels, unchanged.

B. THE OTHER DOORS — the same selector, so the same crosshairs.
B1. ⇪5 scrolling capture: crosshairs and numbers before the drag.
B2. In the editor (⇪⇧1), ⌘A add-capture: the same.
B3. ⇪⇧4 is UNCHANGED — still macOS's crosshair and macOS's HUD. That
    is deliberate: it needs `-i` for the OCR path.

C. MUST STILL WORK — this is the drag every capture goes through.
C1. ⇪4 at the very edge of a screen. The lines must stay ON the
    screen, never half off it.
C2. ⇪4 on the OTHER monitor: crosshairs on that one, numbers right.
C3. ⇪4, then ⇪⇧5 and ⌘5 ("repeat area") — same rectangle again.
C4. The shutter still sounds on ⇪4 and not on a repeat.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.screenshotsReport()` — there is a new `cross :` line beside
    the `size :` one. Healthy reads `drawn · last at 1182, 640 ·
    <time>`. If it reads `⚠️ the crosshair threw`, paste it: the
    selection still works, the lines went quiet, and that line is the
    evidence.
D2. If the crosshairs appear but the NUMBERS do not, that is the
    other half failing and the `size :` line names it. They are two
    switches and two failures on purpose — one sentence from you,
    two different fixes here.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. A one-point white hairline at 55% — too faint on a light
    background, too loud on a dark one? Both are numbers, not a
    release: `settings = { screenshots = { crossThick = 2,
    crossAlpha = 0.8 } }`. Tell me how it reads and I will move the
    default rather than leave you a line to type.
E2. Do you want the lines off and just the numbers? `crosshair =
    false`. Or macOS's crosshair back on ⇪4 at the cost of the live
    size? `areaNative = true`. Both are one word from you.
E3. 🔨 CRUDE OR ELEGANT: ⇪4 captured correctly the whole time — what
    was missing was the aiming aid. My reading is that this is a
    REGRESSION I introduced in 6.264.0 and did not notice for
    fifty-four releases, which makes it mine however gracefully it
    degraded. Your tag.



## 6.317.0

6.317.0 verify with LL — 💾 WHERE YOUR WRITING IS (KNOWN GROUND)
WHAT CHANGED: every boot now prints a block saying where your stores
are and when each last saved — without you asking for it.
🔎 AND MOST OF IT ALREADY EXISTED, which is the honest part.
`_G.saved()` has listed every store with its size, rows, last write
and growth since boot since 6.115.0 — three hundred releases — and has
written a probe file into the Logs folder and read it back to prove
the folder still takes writes. You had never seen any of it. That is
the same failure as the test plans: the instrument was not the gap,
the DOOR was. So it prints where you already look.

A. THE HEADLINE — reload and read the Console. Ten seconds later:
      💾 STORES — 24 files in /Users/…/OneDrive-Personal/Logs
         last write : clipboard_history-….json — just now  ·  quietest: …
         📋 clipboard      : /Users/…/clipboard_history-….json  ·  just now
         📝 Hamsidian tabs : /Users/…/Logs/scratch/scratch.json  ·  4 minutes ago
         🔤 OCR text       : …
         📂 file history   : …
         ⏱ app sessions   : …
         🕸 Hamsidian notes : /Users/…/OneDrive-Personal/Vault  ·  412 notes
         ↳ _G.saved() lists every file…
A1. Read the 📋 clipboard line. That is the answer to "where does the
    clipboard history go" and it is now in front of you every morning.
A2. Read the 🕸 line. That is the folder Hamsidian is really using —
    read out of the notes module itself, not worked out again here.
A3. Any line reading **⚠️ NO FILE MATCHING** means a store you have
    asked me about has NO file at all. Paste it. That is the whole
    point of the list and the one thing it must never be silent about.
A4. `_G.stores()` prints the same block whenever you want it.

B. THE LINE THAT MATTERS MOST, and it is the one that would have
   answered last week. If OneDrive is not running when Hammerspoon
   boots, the notes folder silently becomes a LOCAL one and Hamsidian
   creates it empty — so it says "no notes yet" and is telling the
   truth about the wrong folder.
B1. To see it on purpose: quit OneDrive, reload Hammerspoon, wait ten
    seconds.
    EXPECT:
      🚨 THE NOTES FOLDER IS LOCAL ONLY — /Users/…/.hammerspoon/vault
         OneDrive was not found when this config booted, so Hamsidian is
         reading an EMPTY LOCAL FOLDER and will say "no notes yet".
         Your notes are not lost — they are in OneDrive, which this Mac
         could not see. Start OneDrive and reload (⌘⌃R).
B2. Start OneDrive, reload, wait ten seconds.
    EXPECT: the 🚨 is gone and the 🕸 line names your OneDrive Vault
    with a real note count.
    **If the 🚨 ever appears when OneDrive IS running, stop and paste
    it** — that is the real bug and it is the one you hit.

C. MUST STILL WORK.
C1. `_G.saved()` still prints the full table, and it now carries the
    same block at its top — one source, two surfaces.
C2. ⇪⇧D still carries the write-ledger section.
C3. Boot is not slower: the block is on a held timer ten seconds after
    everything else. If you ever see it BEFORE the boot summary, that
    Mac could not arm a timer and it printed early on purpose.

D. PASTE BACK, PASS OR FAIL.
D1. The block itself, from an ordinary morning. The two numbers I want
    are the note count and the "last write" line.
D2. From the WORK MAC too. That is the Mac where the OneDrive answer
    is most likely to differ, and this is the first build that can say
    so in one line.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Six lines at every boot. Too much? Too little? I deliberately
    broke the rule that a new instrument should be silent when
    healthy, because you asked for the healthy case in writing — the
    value is knowing it IS saving on the three hundred days before the
    one when it is not. `settings = { write_ledger = { sayStores =
    false } }` turns it off; say the word and I will change the
    default instead.
E2. Which stores should be named by name? Right now: clipboard,
    Hamsidian tabs, OCR text, file history, app sessions. Name any
    others and they go on the list — and a named store with no file
    shouts, so the list can only fail loudly.



## 6.316.0

6.316.0 verify with LL — 🚨 A FAILED SAVE IS IMPOSSIBLE TO MISS (KNOWN GROUND)
WHAT CHANGED: when Hamsidian cannot write — a note or a scratch tab —
it now says so through FOUR channels instead of one, and the warning
STAYS said until a real write clears it.
🔎 AND IT ALREADY WARNED, which is the part worth reading. Both halves
called hs.alert on a failed write. Four things made that not enough,
and all four are now closed:
  · 6.274.0 counted THREE `an alert could not draw` lines in eight
    hours of your own Console. A refused alert was the whole warning.
  · the gate was one per-SESSION switch, so a SECOND failure with a
    DIFFERENT cause never spoke again that day.
  · it never took the 🔔 door, so it reached no ledger row, no ⇪⇧D,
    no `_G.degradeReport()` and — the expensive one — no row in the
    on-disk log, which made `_G.todayReport()`, your own 4 PM
    double-check, blind to the one failure that costs you writing.
  · nothing survived the moment. Ten seconds later there was a count
    in a report and no sentence saying your text was still unwritten.

A. THE HEADLINE — two minutes, and it needs you to break a write on
   purpose. The safe way: in Finder, RENAME your `<OneDrive>/Vault`
   folder (add an x). Hamsidian keeps every word in memory.
A1. Open a note (⇪3), type a word, wait a second.
    EXPECT: an alert "⚠️ Hamsidian save — the note <name> was NOT
    written — …" naming the cause, AND a macOS notification, AND a
    Console line beginning ⚠️.
    **A FAIL is silence.** That is the whole release.
A2. Keep typing for a minute.
    EXPECT: it does NOT alert again for the same cause — once per ten
    minutes. If your screen fills with alerts, tell me at once; that
    is the opposite failure and it is the one that makes you switch a
    warning off.
A3. Console: `_G.degradeReport()`.
    EXPECT the FIRST lines, above everything else:
      🚨 NOT SAVED — Hamsidian: the note <name> — <cause>
         since HH:MM:SS · N failed writes · /path/to/the/note.md
         Your text is still in the window. Do not close it — copy it
         out, or fix the folder … and type a character.
A4. `_G.vaultReport()` — the same block, first, before the folder line.
A5. Put the folder name back. Type a character in the note.
    EXPECT: "✅ Hamsidian is saving again" and the file on disk now
    holds your word. Run `_G.degradeReport()` again: the 🚨 block is
    GONE. **Only a real write clears it** — not a timer, not a reload.

B. THE SAME FOR THE TABS, because they are the other half of the one
   window and they had the identical hole.
B1. Rename the Logs folder (or just trust A). Type in a ⇪N scratch tab.
    EXPECT the same four channels, naming "Hamsidian tabs" and
    "your scratch tabs".
B2. `_G.scratchPadReport()` carries the same 🚨 block at the top.

C. THE 4 PM CHECK, which is the reason this is more than an alert.
C1. After doing A, run `_G.todayReport()`.
    EXPECT the failure listed with its time and cause — read back off
    DISK, so it survives a reload. Before this release a failed
    Hamsidian save never appeared there at all.
C2. Reload Hammerspoon and run `_G.todayReport()` again.
    EXPECT: still there. The sticky 🚨 block is gone (that one is
    about right now), but the LOG row remains. Those are two different
    facts on purpose.

D. MUST STILL WORK — this touched the save path of the tool that holds
   your writing, so this half matters more than A.
D1. Type in a note, wait, close Hamsidian, reopen: the word is there.
D2. ⌘N, ⌘F, ⌘⇧S export, the ✕ delete, ⌘Z — all unchanged.
D3. Type in a scratch tab, ⌘T a new tab, reload: both survive.
D4. On a HEALTHY Mac this release must be completely invisible. No new
    alert, no new Console line, nothing. If you see anything at all on
    a day when nothing failed, that is a finding and I want it
    (6.269.0 — a new instrument's first duty is to be silent).

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Is the notification right, or is it one channel too many? It holds
    through Focus and lands after a meeting, which is why it is there
    — but you are the one who gets it. "keep it" · "alert and log only".
E2. 🔨 CRUDE OR ELEGANT: has a Hamsidian save ever actually failed on
    you? If your notes have ever been short a paragraph you were sure
    you typed, that is this, and the row is 🔨. If not, it is a hole
    closed before it cost anything and my reading is ✨ ELEGANT, one
    pass — your tag either way.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
