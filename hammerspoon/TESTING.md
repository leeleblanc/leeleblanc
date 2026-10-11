# TESTING — how to score release 6.352.0

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

## 6.352.0

6.352.0 verify with LL — 🚚 THE DROP HAS TWO DOORS (KNOWN GROUND)
WHAT CHANGED: you can drag films onto the window again — and this time
there are TWO ways in, so one of them failing no longer costs the
feature.
🚚 AND YOU ARE RIGHT ABOUT THE RULE. What I found is not a line that
moved; it is worse. **This tool has only ever had ONE way in.** The
Jug Player's page has carried its own drag handlers since 6.233.0 and
reads the drag's file list itself; the Mug Player's page has NEVER had
one — I checked the whole history of that file and there is not a
single one. Its entire drop was a transparent canvas sitting under the
window.
🪟 AND THAT CANVAS'S "did it open?" ANSWER WAS BEING THROWN AWAY. When
macOS refuses to put it on screen — which your Mac measurably does; it
is why 6.348.0 exists — the code recorded it as "ready" anyway. A
canvas that is not on screen catches nothing. So the report told you
the drop was fine about a door that did not exist.

A. THE HEADLINE — a minute.
A1. ⇪⇧, to open the window.
A2. Drag two or three .mp4 films onto it from Finder.
    EXPECT: the window goes blue with "drop .mp4 films here" as the
    pointer crosses it, and on the drop the films queue and the first
    one starts loading.
    **A FAIL is the drag doing nothing, or the file landing behind the
    window** — that is the bug, unchanged.
A3. Drag a film with an apostrophe or an & in its name.
    EXPECT: it queues, named correctly. Those are the characters the
    shared parser exists for.
A4. Drag a .mkv or a photo.
    EXPECT: refused BY NAME, with ⌘O offered. Unchanged.

B. PASTE BACK, PASS OR FAIL — and please run this one WITH THE WINDOW
   STILL OPEN. That is the whole reason last round cost us a release.
B1. With the window open and after a drop: `_G.mugReport()`.
    Two lines are new and they are what I need:
      drop   : catcher up · the window's own handler: live · 2 file(s)
               dropped — carried by the window's own handler
      ↳ doors : 2 drop(s) through the window itself · 0 through the
               catcher underneath
    **That second line is the release.** It says which door carried
    your drop. If "through the window itself" is the number that
    moved, the new door is working; if the catcher's is, the old one
    was fine and something else was wrong — and either answer is
    useful.
B2. If it ever reads **⚠️ macOS refused the catcher N time(s)**, paste
    it. That is the refusal being caught instead of recorded as
    "ready", and it is the thing that was silent before.
B3. The `page :` line now has four states. With the window OPEN it
    should read `ready`. **If it reads "⚠️ OPEN and has NOT said it is
    ready", paste the whole report** — that means the page's script
    did not run, which is the other half of "there's nothing now" and
    I cannot see it from here.

C. "BUT THERE'S NOTHING NOW" — I have NOT fixed this and I am not
   pretending to. Saying it plainly.
C1. With three films queued and nothing playing, the window should
    draw "Mug Player" top left, "nothing playing" beside it, and a
    deck listing your films by name. Open it and tell me which of
    those four you can see.
C2. The report you sent was taken after you closed the window, and
    closing it wiped the two lines that would have answered this —
    which is mine, not yours, and is fixed in this release (the `page`
    line now tells "closed, and its page HAD run" apart from "its page
    never once spoke"). So: **one report with the window open** and I
    will know.

D. MUST STILL WORK — the drop touches the window, so this half
   matters more than A.
D1. ⇪⇧. the **Jug Player** — drop an mp3 on it, it plays. This release
    published one of its functions as a shared service, so if music
    drops break, this did it and I want to know at once.
D2. ⌫ on a queue row still REMOVES that film from the queue, and ⌫ on
    a history row still forgets it. **This is the one I would most
    like you to check**: the page's file drop and the ⌫ key had to be
    given different names, and if they had collided, dropping films
    onto the window would DELETE one instead.
D3. ↑↓, ⏎, space, ⌘1–9, ⌘O, Escape, the ✕ on a history row.
D4. Drag the window by its title strip; close and reopen — it is where
    you left it.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. The blue "drop .mp4 films here" veil — does it appear reliably now
    as the drag crosses the window? It is drawn by the page for the
    page's door and by Lua for the catcher's, so a veil that appears
    only sometimes is itself a finding.
E2. 📏 NAMED, NOT SWEPT: the **Jug Player's** catcher has the identical
    unread-show bug. It has two doors so it survives it, which is why
    it is not fixed here — one change per release, the failing one
    first. Say if you would rather I did both.
E3. 🔨 CRUDE OR ELEGANT: the window opened, nothing was lost, and ⌘O
    always worked — but the one thing you were trying to do did not,
    and this is pass five on this tool. Your tag.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
