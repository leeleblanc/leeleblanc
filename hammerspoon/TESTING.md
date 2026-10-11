# TESTING — how to score release 6.348.0

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

## 6.348.0

6.348.0 verify with LL — 🪟 THE WINDOW macOS REFUSED (KNOWN GROUND)
WHAT CHANGED: a window macOS refuses to put on screen is tried ONCE
more, a beat later — and the first ⇪⇧, of a session no longer pays
two main-thread library loads in the same turn as the show.
🔎 YOUR CONSOLE NAMED THIS, and it is a DIFFERENT failure from the
black rectangle 6.345.0 fixes. Three lines, one second:
    20:45:51  -- Loading extension: webview
    20:45:51  -- Loading extension: drawing
    20:45:51  ⚠️ Mug Player: macOS would not put the window on screen
The window never opened at all. Hammerspoon loads a library the first
time anything touches it, on the main thread, and on your Mac that is
seconds — your 6.330.0 log has one arriving twenty-six seconds after
another. So the first press was loading two of them and then asking
macOS to order a window on screen in the same breath.
🚨 I AM NOT CLAIMING THAT IS THE CAUSE. The same Console has the
cheat sheet refused forty minutes earlier, so this Mac refuses window
shows generally. What this does is take two known pieces of work off
that moment, and retry once when it still happens.

A. THE HEADLINE — and the case that matters is the FIRST press.
A1. Reload Hammerspoon (⌘⌃R). Wait ten seconds, no keys.
A2. Press **⇪⇧,** — the FIRST press of the session.
    EXPECT: the window. **A FAIL is nothing happening**, and if that
    is what you get, go straight to D1 — the report now counts it.
A3. Watch the Console while you do A2.
    EXPECT: NO `-- Loading extension: webview` line at that moment.
    It should have been loaded ten seconds after boot instead. If it
    still appears on your keypress, the warm did not run and that is
    the finding.
A4. Close and open it a few times. EXPECT: every time.

B. THE RETRY, which you may never see.
B1. If a press ever seems to do nothing and then the window appears a
    moment later, that IS the retry. Normal.
B2. If you get "macOS would not put the window on screen, TWICE",
    that is two refusals in a row — paste it. It means the retry is
    working and the refusal is something bigger than a busy turn.

C. MUST STILL WORK.
C1. Everything in the 6.345.0 block — the film plays, names in the
    deck, Escape closes, ⌘O.
C2. ⇪⇧. the Jug Player, ⇪/ the cheat sheet, ⇪3 Hamsidian, ⇪N, ⇪T.
    Those all draw windows and none of them changed.
C3. Boot: All green, 72 modules. Boot time should be unchanged —
    the two libraries load in warm, seconds AFTER boot, not during.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.mugReport()` — a new line:
      opens  : 3 asked · 3 straight through · 0 refused by macOS
    and, if any were refused, one under it saying how many came up on
    the retry against how many were refused twice. **Those are
    opposite facts** and the old report could say neither.
D2. Still the one I most need: the **way in** line, once a film
    actually plays.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. 📏 COST, NAMED: your Mac now loads hs.webview and hs.drawing a few
    seconds after every boot even if you never press ⇪⇧,. Six other
    tools here draw webviews so you were almost certainly paying it
    anyway — but if boot ever FEELS slower, say so and it comes out.
E2. Every other window in this config still has the bare show this
    release fixed in one place — the music card, Hamsidian, the
    screenshot editor. If any of THEM ever does nothing on a press,
    that is the same bug and I will take the same door there.
E3. 🔨 CRUDE OR ELEGANT: for the Mug Player this is pass three. Your
    tag, and I would not argue with 🔨.



## 6.347.0

6.347.0 verify with LL — 🗑 IINA IS OFF THE MONITOR TOO (KNOWN GROUND)
WHAT CHANGED: one more name out of the same list. 17 apps watched.
A1. Quit IINA. EXPECT: nothing — no popup, no ping.
A2. Quit a watched app (Shottr, CotEditor, Word). EXPECT: the popup,
    exactly as always. That half must be untouched.
🔑 IT COST ONE LINE BECAUSE 6.346.0 BUILT THE CHECKS FIRST: the
negative case now runs once per removed name, each on its own boot,
and putting either name back fails its own row.
C1. The eighteen left: 1Password, Alfred, Bartender, CotEditor,
    Ghostty, Chrome, OneDrive, Defender, Excel, PowerPoint, Word,
    Outlook, Teams, NordVPN, Rectangle, Shottr, Sublime. Name any
    others and they go in one line each.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
