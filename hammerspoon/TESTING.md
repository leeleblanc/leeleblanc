# TESTING — how to score release 6.346.0

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

## 6.346.0

6.346.0 verify with LL — 🗑 TRANSMISSION IS OFF THE MONITOR (KNOWN GROUND)
WHAT CHANGED: Transmission quitting no longer pops the app monitor.
Your words, one line, 18 apps watched instead of 19.
🚨 AND THE REAL WORK IS THAT THE REMOVAL IS PROVABLE. The suite had
nineteen tests and every one of them quit a WATCHED app — so a list
with one name taken out and a list nobody consults looked the same to
the gate. Two checks drive the negative case now, and putting the
name back fails them.

A. THE HEADLINE — needs a download to finish, or just quit it.
A1. Quit Transmission (⌘Q, or let a download finish and let it go).
    EXPECT: NOTHING. No popup, no ping, no sound.
    **A FAIL is the panel appearing** — that is the bug, unchanged.
A2. Quit a watched app — Shottr, CotEditor, Ghostty, Word.
    EXPECT: the popup, pinging as always, with Spawn / End and Esc.
    That half must be untouched; if it is gone, this release broke
    the monitor rather than trimming it.
A3. Answer that popup (Esc, or a button). EXPECT: unchanged.

B. MUST STILL WORK.
B1. Quit two watched apps in a row. EXPECT: one popup, then the next
    behind it — the queue is unchanged.
B2. ⇪R to reload, then quit a watched app again. EXPECT: the popup.
B3. Nothing else in this release touches anything else.

C. A JUDGEMENT ONLY YOU CAN MAKE.
C1. **Is anything else on that list quitting by itself?** The other
    eighteen are 1Password, Alfred, Bartender, CotEditor, Ghostty,
    Google Chrome, IINA, OneDrive, Microsoft Defender, Excel,
    PowerPoint, Word, Outlook, Teams, NordVPN, Rectangle, Shottr,
    Sublime. IINA is the one I would ask about — it is a film player
    and you have a film player now. Name any others and they go in
    one line.
C2. 📏 THE LIST CARRIES "Microsoft Excel" TWICE. It is harmless — the
    second pass finds the app already recorded as gone, so there is
    no second popup — and it is your list, so I have reported it
    rather than tidying it. Say the word and it goes.
C3. 📏 AND IT IS NOT A SETTINGS LINE: that list is a local inside the
    module, so putting an app BACK is a one-line release rather than
    something you could type. Said plainly rather than pretending
    there is a knob.
C4. 🔨 CRUDE OR ELEGANT: nothing was broken — this is a list you
    wanted shorter. My reading is that it does not belong in the
    ledger as a problem at all. Correct me if the popup was actually
    getting in your way.



## 6.345.0

6.345.0 verify with LL — 🚨 THE MUG PLAYER PLAYS (KNOWN GROUND now)
WHAT CHANGED: films play. ⎋ closes the window. And the deck shows the
films' NAMES.
🔎 ONE FUNCTION DID ALL OF IT, and your screenshot is what named it.
Four things in that picture were blank: no "Mug Player" in the title
strip, "nothing playing" over a film that was queued, rows reading
"1" and "2" with no names, and a black stage. Four blanks is not four
bugs — it is one function that returns a blank. Every string the page
is handed went through `hs.json.encode`, which on a Mac REFUSES
anything that is not a table and raises; the error was caught and
turned into an empty string. The `<video>` was therefore never given
a film to play, which is the black rectangle, with WebKit's own play
button sitting on it.
🔬 AND THE GATE COULD NOT SEE IT: the test harness's fake encoder
took a bare string happily, so 174 checks and 44 page checks were
green over a payload no Mac could produce. The harness refuses it now
exactly as macOS does — and with that one change, the build you
installed fails ELEVEN checks.

A. THE HEADLINE — a minute.
A1. Press **⇪⇧,**. EXPECT: the window, and "Mug Player" in blue at
    the top left. **A FAIL is a blank title strip** — that alone says
    the fix did not take and nothing below will work.
A2. Drag two or three .mp4 films onto it.
    EXPECT: the deck lists them BY NAME — not "1" and "2" — and the
    header names the one that is playing.
A3. EXPECT a picture. **This is the step that could not happen
    before.** If you get a black rectangle with a play button, press
    it once, then go to D1 — that is new ground answering, and the
    report now carries macOS's own reason.
A4. Native controls underneath: scrubber, clock, volume, full screen,
    picture-in-picture.
A5. Press **Escape**. EXPECT: the window closes.
A6. Open it again, put the film FULL SCREEN, press Escape.
    EXPECT: it leaves full screen and the window STAYS — WebKit owns
    Esc there, deliberately, or you would be stuck in a full-screen
    film with no way out. Press Esc again: now it closes.

B. THE REST OF THE DECK.
B1. ↑ ↓ walk, ⏎ plays, ⌘1–⌘9 play the Nth, ⌫ removes from the queue.
B2. **space** plays and pauses; **← →** seek, ⇧ with them seeks more.
B3. ✕ on a 🕘 history row: it vanishes and NOTHING starts playing.
B4. Let a film run to its end: the next one starts by itself.
B5. Drag a .mkv or a .mov: refused BY NAME, with ⌘O offered.
B6. ⌘O on a playing film: it opens in QuickTime.
B7. A film whose name has an & or an apostrophe in it — those are the
    characters the escaper exists for. The name must read as itself.

C. MUST STILL WORK.
C1. **⇪⇧. the Jug Player** — drop an mp3, it plays. Same drag reader.
C2. ⇪Esc with nothing open still says "⎋ nothing open to close".
C3. A spread of ⇪ keys: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space, ⇪V, ⇪/.
C4. Type a comma in any app. EXPECT: a comma.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.mugReport()` — the whole block. Three lines have changed and
    each answers something your last report could not:
    · **way in** — "relative to the film's own folder" or "the
      absolute file URL" tells me WHICH way in carried the film, and
      that decides everything built on this next.
    · **refused** + "↳ macOS said:" — if no door worked, this now
      carries macOS's own MediaError. "the file is not there" and
      "WebKit would not let this window read it" are opposite facts
      and that line is the only thing that can tell them apart.
    · **store** — should now say "written N bytes", not "no store
      file yet". It was describing the disk as it was at boot.
D2. The **queue** line should read "playing #1", not "#1.0".

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. **Your answer on sizing is logged and is the NEXT release**: size
    the window to the film's own shape, like VLC. It needs the page
    to report the film's dimensions, which it can only do once a film
    actually loads — so it waits on A3, not on a decision.
E2. 🔨 CRUDE OR ELEGANT: a brand-new tool that opened a window and
    played nothing. My reading is that it degraded honestly — the
    window opened, the queue filled, nothing was lost, and ⌘O always
    worked — but the tool did not do its one job, and this is its
    second pass. Your tag.
E3. Still unanswered from last time, and still only yours: .mp4 only,
    or add .m4v and .mov? And 🔨/✨ for 6.343.0 and 6.344.0.



## 6.344.0

6.344.0 verify with LL — 🎬 THE MUG PLAYER (NEW GROUND — expect a round)
WHAT CHANGED: there is a new tool. **⇪⇧,** opens the Mug Player — a
Jug Player for films. Drop .mp4 files on it, the first plays, the
rest queue under it, and the controls are macOS's own.
🪟 AND IT IS NEW GROUND, SAID UP FRONT: nothing in this config has
ever played video in one of its windows, so whether macOS will let
that window read a film off your disk is a thing NOBODY HAS
MEASURED — not me, not a previous release. The player tries two ways
in, reports which one worked, and if neither does it says so in
words and gives you ⌘O into QuickTime. So the most useful thing you
can send back is one line of `_G.mugReport()`, whether it works or
not.

A. THE HEADLINE — a minute.
A1. Press **⇪⇧,** (hold Caps Lock and Shift, press the comma).
    EXPECT: a dark window opens in the middle of the screen with
    "Mug Player" along the top and an empty deck underneath.
    Press it again: it closes.
A2. Drag two or three **.mp4** films onto that window from Finder.
    EXPECT: the window goes blue as the drag crosses it, and on the
    drop the first film STARTS PLAYING with a control bar under it —
    play/pause, a scrubber, a clock, volume, full screen.
    **A FAIL is a black rectangle with no picture** — that is the
    case this release exists to make legible, so go straight to D1.
A3. Use the control bar. It is macOS's own, not mine: the scrubber,
    the volume slider, the full-screen button and picture-in-picture
    should all behave exactly as they do in Safari.
A4. Press **space**. It plays and pauses, wherever the keyboard is in
    the window. **← and →** seek; **⇧** with them seeks further.
A5. ↑ ↓ walk the deck, **⏎** plays the highlighted row, **⌘1–⌘9**
    plays the Nth film, **⌫** takes a film out of the queue.
A6. Let a film run to its END. EXPECT: the next one starts by itself.

B. THE BITS THAT PROTECT YOU.
B1. Drag something that is NOT an .mp4 — a .mkv, a .mov, a photo.
    EXPECT: it is NOT queued, and an alert names the file and says
    "Mug Player plays .mp4 (your scope); ⌘O opens it in QuickTime".
    That is your own scope answering, not a bug. Say the word and
    .mov and .m4v join the list — one line, not a release.
B2. With a film playing, press **⌘O**.
    EXPECT: it opens in QuickTime (or whatever your default player
    is). That is the way out when this window cannot read a film.
B3. Click the **✕** at the end of a 🕘 history row.
    EXPECT: the row disappears and NOTHING starts playing. A film
    starting there is the worst thing this release can do — tell me
    at once.
B4. Check the file is still on disk. Nothing here ever deletes one.
B5. Drag the window by its **title strip**, close it, reopen it.
    EXPECT: it comes back where you left it. ⌘-drag anywhere on it
    works too.
B6. **Esc** closes it. Then ⇪/ — the cheat sheet still closes last.

C. MUST STILL WORK — this release published one of the Jug Player's
   own functions as a shared service, so that is what to check.
C1. **⇪⇧.** — the Jug Player opens, drop an mp3 on it, it plays.
    That drop now goes through the same reader the Mug Player uses,
    so if music drops stop working, this release did it and I want
    to know immediately.
C2. With the Jug Player's card up and a queue in it, press **F8**.
    EXPECT: the Jug Player pauses, as always. The Mug Player
    deliberately does NOT take that key — see E2.
C3. A spread of ⇪ keys: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space, ⇪V, ⇪/.
C4. Type a **comma** in any app. EXPECT: a comma.

D. PASTE BACK, PASS OR FAIL. These matter more than usual.
D1. `_G.mugReport()` — the whole block. The line I need is **way in**:
    · "relative to the film's own folder — this is the one that
      carried a film" or "the absolute file URL — …" → it WORKS, and
      now I know which way, which decides everything built on it.
    · "⏳ no film has loaded yet" → nothing has been tried.
    · a **refused** line listing both ways → macOS will not let the
      window read local files at all, and the next release is a
      different mechanism rather than a tweak to this one.
D2. `_G.musicReport()` — unchanged, and it proves C1.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. **The window is 880 × 660 and fixed.** A film player probably
    wants to be resizable, and I did not build that — say what size
    you actually want, or whether it should remember a size the way
    it remembers a position.
E2. **⏯ / F7 / F9 are NOT taken by the Mug Player**, deliberately:
    the Jug Player holds them while its card is up, and two tools on
    one physical key is how they come to disagree. With the film
    focused macOS routes them to it anyway. Is that right until the
    merge, or do you want the film to win whenever its window is up?
E3. **.mp4 only.** Confirm, or name the formats to add. Anything
    WebKit can play will work (.m4v and .mov almost certainly will;
    .mkv almost certainly will not, whatever I put in the list).
E4. 🔨 CRUDE OR ELEGANT: this is a new tool, so there was nothing to
    break — but if it opens a black rectangle and nothing plays, it
    is a tool that does not work, and I would log that as 🔨 with a
    pass count of 1. Your tag, as always.



## 6.343.0

6.343.0 verify with LL — 🚨 ⇪Esc WAS PAUSING YOUR CONFIG (KNOWN GROUND)
WHAT CHANGED: Caps Lock + Escape no longer fires the panic chord. And
the Secure Input probe kills the `ioreg` it gives up on.
🔎 WHAT IT WAS, and your own words found it: "I did not mean to hit
panic." You didn't. Nothing claimed ⇪Esc, so an unclaimed hyper key
was FORWARDED — re-posted as ⌘⇧⌃⌥ plus the key — and ⌘⇧⌃⌥Esc IS the
panic chord. One guard stood between them and it was a 0.25-second
window around an event that arrives late on a busy Mac. Your 14:52:10
line, `🚨 panic (panic chord) — 2 released, 0 threw`, is it happening.
🔑 AND "Console shows nothing weird" WAS THE EVIDENCE, not a dead end:
nothing went wrong. Every step was a feature working.

A. THE HEADLINE — ten seconds, and it is the whole release.
A1. Press **Caps Lock + Escape** with nothing open.
    EXPECT: a small "⎋ nothing open to close" and NOTHING else.
    **A FAIL is the panic alert** — Released / hold released / card
    closed / Hammerspoon paused. That is the bug, unchanged.
A2. Open any panel — ⇪/ the cheat sheet will do — and press
    **Caps Lock + Escape**. EXPECT: the panel closes. That is ⇪Esc's
    new job.
A3. Press **⇪⇧Esc**. EXPECT: Hammerspoon pauses, as it always has.
    Press it again to come back. That key is unchanged.
A4. Press **⌃⌥⌘⇧Esc** on purpose. EXPECT: the panic alert. The real
    chord still works — only the accidental route is closed.

B. THE 93 PROCESSES.
B1. Terminal: `pgrep -fl ioreg | wc -l`. Note the number.
B2. Use the Mac for a few hours. Run it again.
    EXPECT: it has NOT climbed into the dozens. Before this it grew
    by one a minute.
B3. Console: `_G.secureInputReport()`. If the timeout count is
    climbing, a new "abandoned ioreg process(es) KILLED" line should
    be climbing with it. **A timeout count climbing with no kill line
    is the leak back** — paste it.

C. MUST STILL WORK — this touched the keyboard, so this half matters
   more than A.
C1. A spread of ⇪ keys: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space, ⇪V, ⇪/.
C2. Escape still closes every panel it closed before, on its own.
C3. ⇪⇧D still opens the diagnostic report — that one RELIES on the
    forwarding this release did not touch, so it is the check that
    proves I narrowed the fix rather than breaking the mechanism.
C4. Type normally for a while. No missed characters, no stray Escape.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.chordAudit()` — new. On a healthy Mac it finds nothing. If it
    names a chord, that is a SECOND key with the same hazard and I
    want it immediately.
D2. `_G.secureInputReport()` after a day.
D3. `_G.hyperKeyReport()` — the latch/handover/relay counts.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. ⇪Esc now closes the front panel, and says "nothing open to close"
    when there is none. Is that little message useful or noise? It is
    one line either way.
E2. 🔨 CRUDE OR ELEGANT: by your own account the Mac was unusable —
    keys doing weird things, the keyboard dead, and no explanation
    anywhere. My reading is 🔨 CRUDE, and the honest pass count is 1
    (found and fixed in one pass, from your artefacts). Your tag.
E3. 📏 The arrow keys moving windows is NOT explained by this and I am
    not claiming it. ⌃⌥← and ⌃⌥→ are two-modifier chords and the
    forward makes four, so a forward cannot reach them. If it happens
    again, the one thing I need is whether the WINDOW moved or the
    MOUSE POINTER moved — they are different bugs.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
