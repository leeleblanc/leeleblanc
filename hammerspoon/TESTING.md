# TESTING — how to score release 6.351.0

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

## 6.351.0

6.351.0 verify with LL — 🚪 THE THIRD WAY IN (NEW GROUND — measured)
WHAT CHANGED: one more way to get a film into the window, and the
report now says what the film actually IS.
✅ FIRST, WHAT YOUR LAST REPORT PROVED, because two releases landed:
`opens : 2 asked · 2 straight through · 0 refused` — 6.348.0 fixed
the window being refused. And your screenshot shows the brand, the
film's name in the header and three films by name in the deck —
6.345.0 fixed the payload. What is left is the film itself.
🔬 AND THE HONEST PART: MediaError code 4 means TWO opposite things.
WebKit returns it when it could not READ the file, and when it read
it fine and cannot DECODE what is inside. My old message asserted
the first. It might be the second — a "2026 1080p" download is very
often HEVC/x265 with AC3 audio, which Safari may refuse outright.
No door will ever fix that one.

A. THE HEADLINE — and step A2 is worth more than A1.
A1. ⇪⇧, and drop the same film. EXPECT: either it plays (door 3
    worked), or the same message — but reworded, naming BOTH causes.
A2. 🚨 **DROP A FILM YOU KNOW SAFARI CAN PLAY.** Anything ordinary —
    something from a phone, a .mp4 off a website, an old h.264 file.
    **This single test decides everything.**
    · It PLAYS → the mechanism works and your Robin Hood file is a
      codec. Nothing here is broken; the fix is a different player
      or a converted file.
    · It does NOT play → the window cannot read any local film, and
      three doors have now said so. The Mug Player becomes a
      controller — the deck and queue stay, ⏎ hands the film to
      QuickTime or VLC — and I will build that instead.
A3. `_G.mugReport()` — the new **codecs** line names what the Mac
    says is inside the file, with what it means underneath. PASTE IT.

B. THE FILE IT WRITES — worth knowing about.
B1. Door 3 writes a hidden `.mug-stage.html` INTO THE FILM'S OWN
    FOLDER and deletes it when the window closes. Check your
    Desktop/new_dl folder with ⌘⇧. (show hidden files) after closing
    the player: **it must not be there.**
B2. If the folder is read-only the door says so and does not blame
    macOS for refusing the film — a different line in the report.

C. MUST STILL WORK.
C1. The deck names, Escape, ⌘O, space, ↑↓, ⏎, ⌘1–9, the ✕.
C2. ⇪⇧. the Jug Player.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. **If A2 says codecs**, what do you want? Convert on the fly with
    ffmpeg (slow, needs a binary), or make ⏎ hand anything the window
    cannot play straight to VLC/QuickTime and keep the Mug Player as
    the queue? I would build the second.
D2. Writing a hidden file into your film folders — acceptable, or
    would you rather I did not? It is removed every time, but it is
    your folder and I would rather ask.
D3. 🔨 CRUDE OR ELEGANT: pass four on this tool. Your tag.



## 6.350.0

6.350.0 verify with LL — 🗑 EXCEL LISTED ONCE (KNOWN GROUND)
A1. Nothing to press. `Microsoft Excel` was in the watched list twice
    and is now there once. Quit Excel: EXPECT the popup, exactly one.
🔑 The sentry asserts the RULE — no app twice — not the name, so the
next hand-edit that repeats something fails the gate.



## 6.349.0

6.349.0 verify with LL — 🗓 ⇪⇧0 OPENS ON TODAY (KNOWN GROUND)
WHAT CHANGED: the calendar opens on today, every time.
🔎 AND THE COMMENT BESIDE THE OLD LINE PROMISED EXACTLY THAT while
the code did the opposite — it kept whatever day you last arrowed to
and only gave up after a year's drift. You were right.
A1. ⇪⇧0. EXPECT today, filled. Esc.
A2. ⇪⇧0, press → three times (now on the 14th), Esc, ⇪⇧0 again.
    EXPECT **today** — not the 14th. That is the whole release.
A3. Look at today's date while the cursor is elsewhere: it keeps its
    ring. That part was already right and is untouched.
B1. ←→ a day, ↑↓ a week, [ ] a month, T back to today, click to copy,
    Esc — all unchanged.
C1. 🗳 If you would rather it DID reopen where you left it:
    `settings = { mini_calendar = { keepPlace = true } }`. Say the
    word and I will change the default instead of leaving you a line.
C2. 📏 NAMED: mini_calendar still has no suite of its own — these
    checks live in test_features with the calendar's others.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
