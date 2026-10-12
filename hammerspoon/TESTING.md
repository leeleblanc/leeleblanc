# TESTING — how to score release 6.355.0

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

## 6.355.0

6.355.0 verify with LL — 📏 THE CEILING THAT REFUSED YOUR FILM
WHAT CHANGED: your film was never read. The window's own message said
so — "the film is 2300.6 MB and the ceiling is 1536.0 MB" — and that
1536 was a number I typed, not anything your Mac said. It is measured
off your Mac now.
🔎 AND YOUR REPORT CLOSED THE CODEC QUESTION. It read `codecs : H.264
· MPEG-4 AAC`, which is the one combination WebKit certainly can
decode. So nothing is wrong with the film, nothing is wrong with the
format, and six releases of doors were not the problem on this one.

A. THE HEADLINE — the same film, the same key.
A1. ⇪⇧, and press ⏎ on The.Death.Of.Robin.Hood.
    EXPECT: "⏳ reading the film into the window — N%", climbing, then
    it PLAYS with the Mac's own controls.
    **A FAIL is the hand-off message again** — if you get it, read
    what it says about the ceiling now and paste that line.
A2. Time it roughly, and watch the percentage move. A film this size
    is hundreds of pieces; the number should climb steadily, not stick.
A3. While it reads, use the Mac — move a window, type somewhere.
    EXPECT: normal. This is the half I most want your word on.
A4. Once it plays: the scrubber, volume, full screen, ← → to seek.

B. PASTE BACK — three lines are new and each answers something.
B1. `_G.mugReport()`:
    · `ceiling:` — the number AND where it came from. It should name
      a share of your Mac's memory, not a number I chose.
    · `↳ pace :` — how many pieces the window CONFIRMED it took. The
      loader waits for each one now instead of firing them off blind.
    · `↳ clock :` — how long the whole read took, wall clock. That is
      the number that decides whether the pieces need to be bigger.
B2. If `↳ pace` ever carries "⚠️ N never answered", paste it — that is
    the window going silent, which used to hang the read for ever.

C. MUST STILL WORK.
C1. A small film: still plays, faster.
C2. .mkv and .mp3 still refused by name with ⌘O offered.
C3. ⌘O, Escape, ↑↓, ⏎, ⌫, the ✕ on a history row, the drop.
C4. ⇪⇧. the Jug Player — drop an mp3, it plays.

D. WHAT IS STILL TRUE, so it is not a surprise.
D1. The whole film sits in the window's memory while it plays. That is
    the one cost this way in cannot avoid, and it is why there is a
    ceiling at all — it is just your Mac's number now instead of mine.
D2. If a film is still too big, the message names both sizes and ⌘O
    opens it in a real player, as before.



## 6.354.0

6.354.0 verify with LL — 📦 THE BYTES GO THROUGH THE WINDOW (NEW GROUND)
WHAT CHANGED: the film is no longer named to the window at all. This
config reads it off the disk in pieces and hands the pieces to the
page, which puts them together and plays them.
🚨 FIRST, AND IT MATTERS MORE THAN ANY STEP BELOW: **YOU ARE STILL ON
6.351.0.** Your own boot log says so twice — `📌 init.lua ARCHITECTURE
VERSION: 6.351.0` at 14:58:36 and again at 14:59:16. So the -3001
error page you photographed is a door that 6.353.0 DELETED three days
ago and that is still live on your Mac, and ⌘O is still broken there
too. Install this one and both of those go away before you test
anything new.
🔎 WHY THIS SHAPE: both file:// doors are refused on your Mac, and
there is no third URL to try — I read hs.webview's own source and the
call that would grant a window read access to a file
(`loadFileURL:allowingReadAccessToURL:`) is not in it, at all. So the
pipeline was the problem rather than any one door, and this routes
around it. I also checked the obvious alternative (a little web server
on 127.0.0.1) and it cannot work — hs.httpserver has to hand back the
whole film as one string, in one go, on the main thread. That is
written down with line numbers so nobody builds it later.

A. THE HEADLINE — one film, and watch the stage.
A1. ⇪⇧, to open the Mug Player. Drop a film on it, or press ⏎ on one
    already in the deck.
A2. EXPECT: the stage says **"⏳ reading the film into the window —
    N%"**, the percentage climbs, and then the film PLAYS with the
    Mac's own controls under it.
    **A FAIL is the percentage sticking**, or the old "is opening in
    your usual player" message, or a black rectangle.
A3. Use the controls: the scrubber, volume, full screen,
    picture-in-picture. They are macOS's own, so they should feel
    exactly like Safari's.
A4. Press **space**, then **← →** to seek, **⇧** with them to seek
    further.
A5. 🚨 **AND IF IT STILL WILL NOT PLAY, THAT IS AN ANSWER RATHER THAN
    ANOTHER ROUND.** Go straight to D1: the report now says, in
    capitals, that the bytes were inside the window and it still would
    not play — which proves the film is one WebKit cannot decode
    (HEVC, x265, AC3) and that no further way in can ever help. That
    is the thing six releases could not establish.

B. HOW LONG IT TAKES, and the one thing to tell me.
B1. Time it, roughly: a 700 MB film should take a few seconds before
    it starts. A 2 GB one may take ten or more.
B2. **While it is reading, does the Mac feel normal?** Move the mouse,
    drag a Finder window, type somewhere. This reads the film on
    Hammerspoon's main thread, in small pieces, deliberately — but if
    the Mac stutters while a film loads, that is a number I can move
    and I want to know at once.
B3. If a read ever alerts "⚠️ reading the film is costing N ms a turn",
    paste it. That is the budget biting and the message carries the
    settings line that halves the piece size.

C. THE EDGES WORTH ONE MINUTE EACH.
C1. Close the window **while the percentage is climbing**. EXPECT: it
    closes at once and nothing is left running. Reopen: ⇪⇧, works.
C2. With one film loading, press ⏎ on a DIFFERENT film. EXPECT: the
    first read is abandoned and the second starts from 0%.
C3. Drop a film over 1.5 GB. EXPECT: it does NOT read — it goes
    straight to your usual player and says the film is bigger than the
    window can hold, with both sizes named.
C4. Drop a .mkv or an .mp3. EXPECT: refused by name with ⌘O offered,
    exactly as on 6.351.0.
C5. ⌘O on a film with nothing playing. EXPECT: it opens the row you
    have SELECTED. That is the 6.353.0 fix you have never run.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.mugReport()` with the window OPEN. Four lines are new and each
    answers something that could not be asked before:
      way in : the bytes through the window, not a URL — this is the
               one that carried a film
      bytes  : 1 film(s) read into the window · 1 played · 0 refused
      ↳ turns: 358 turn(s) carrying 698.4 MB · worst 31 ms
      ↳ last : read 698.4 MB in 358 turn(s)
    **`way in` is the whole release.** If it names the bytes door, it
    works. If `bytes` shows a refusal, `↳ last` says which of five
    reasons.
D2. Run it again WHILE a film is loading: the last line becomes
    `↳ now : reading <film> — 142.0 MB of 698.4 MB in 71 turn(s) so
    far`, which is how a stalled read is told from a finished one.
D3. The `codecs :` line, if it appears. See A5.

E. MUST STILL WORK — this touched the stage and the door walker.
E1. The drop (both ways in), the blue veil, films queuing BY NAME.
E2. ↑↓, ⏎, ⌫ on a queue row, ⌘1–9, the ✕ on a history row, Escape,
    and Escape out of full screen leaving the window up.
E3. Drag the window by its title strip; close and reopen — it is where
    you left it.
E4. 🚨 **⇪⇧. the Jug Player** — drop an mp3, it plays. Different
    module, shared drag reader, and I would want to know immediately.
E5. Boot: All green, 72 modules. Boot time unchanged.

F. ONE QUESTION, IN PLAIN WORDS.
F1. While the Mug Player was not working, was your MAC unusable — keys
    dead, nothing clickable — or did the Mac stay fine and just this
    one tool not do its job? That is all I need; I keep the record
    from your answer. (And I am sorry about the 🔨/✨ business — that
    was private shorthand of mine that I should never have been asking
    you to decode, especially days apart. It is gone.)



## 6.353.0

6.353.0 verify with LL — 🚪 THE WINDOW HANDS THE FILM OUT (KNOWN GROUND)
WHAT CHANGED: the Mug Player stops trying to play films it cannot read
and hands them to a player that can. And ⌘O works.
✅ FIRST, WHAT YOUR SCREENSHOTS SETTLED, because two questions closed
without another round. The DROP WORKS — the veil appears, six films
are in your deck BY NAME, two are in the history. And "there's
nothing now" is answered: your own screenshot shows "Mug Player" in
blue, "nothing playing" beside it and every film named. The page was
never the fault. "Nothing" was the black stage, because nothing
would play.
🚪 AND YOUR OTHER SCREENSHOT IS THE ANSWER TO THE WHOLE TOOL. That
error page is not mine — it is WebKit's: "Error code: -3001 in
NSURLErrorDomain … Cannot open file". That is a NAVIGATION error on a
file this config had JUST WRITTEN, so unlike the earlier code 4 it is
not ambiguous: the file was there and WebKit would not read it.
6.351.0 said in writing that a third refusal decides this. It did.
🚨 AND IT WAS WORSE THAN A FAILURE: a refused navigation REPLACES the
page, so the deck, the queue and every key went with it and you were
left looking at an error page. That is why the window seemed to die.
Door 3 is deleted — it cannot work, and it could destroy the window.

A. THE HEADLINE — a minute, and it should just play now.
A1. ⇪⇧, and drop a film, or press ⏎ on one already in the deck.
    EXPECT: a moment of black, then **the film opens in your usual
    player** (IINA/QuickTime/VLC — whatever .mp4 opens with), and the
    Mug Player says so on the stage.
    **A FAIL is the error page coming back**, or nothing happening.
A2. Read what the window says while it hands over. It should name
    the film and the -3001 error, so the claim is checkable.
A3. **⌘O on a film with nothing playing.** EXPECT: it opens the row
    you have SELECTED. It used to say "nothing is playing" — that is
    the bug you reported.
A4. ⌘O with the queue EMPTY. EXPECT: "there is nothing in the queue
    to open". That is the case that should still refuse.

B. MUST STILL WORK — this touched the queue's own window.
B1. The drop, both ways: the veil, films queuing by name.
B2. .mkv and .mp3 still refused BY NAME with ⌘O offered — you
    confirmed both on 6.352.0 and neither may have moved.
B3. ↑↓, ⏎, ⌫ on a queue row, the ✕ on a history row, Escape.
B4. 🚨 **⇪⇧. the Jug Player** — drop an mp3, it plays. You asked for
    exactly this and I am asking you to check it again, because this
    release touched the module beside it.
B5. Check your film folders: there must be NO hidden `.mug-stage.html`
    anywhere (⌘⇧. shows hidden files). That file is gone, and so is
    every line that could delete one.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.mugReport()` with the window OPEN. Two new lines:
      exits  : 2 handed out because no way in worked · 1 you opened
               yourself
      ↳ ⌘O would open: <film> — the row you have selected
    That second line says what ⌘O would do RIGHT NOW, so a wrong
    answer is visible before you press it.
C2. The `refused:` line should now name TWO ways in, never three.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. **Is the automatic hand-off right?** A film that will not play in
    the window now opens in your player WITHOUT you pressing
    anything. The alternative is it stops and waits for ⌘O, which is
    `settings = { video_player = { handOff = false } }`. I shipped
    automatic because a window whose only answer is "it would not
    play" does not work — but it is your taste and I will change the
    default on one word.
D2. **Is this still the tool you want?** It is now a queue, a
    history and a drop target that hands films to a real player. If
    what you wanted was a window that PLAYS them, three ways in have
    been refused and the honest answer is that a Hammerspoon webview
    cannot — the next step would be a different surface entirely, and
    that is a much bigger release I will not start unasked.
D3. 🔨 CRUDE OR ELEGANT: pass six on this tool. Your tag.



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

C. "BUT THERE'S NOTHING NOW" — AND I MEASURED IT RATHER THAN GUESSING.
🔎 THE PAGE IS BYTE-FOR-BYTE IDENTICAL between 6.348.0 and 6.351.0 —
6,936 bytes, pulled out of both commits and compared. And 6.348.0 is
the build whose screenshot showed the brand, the film's name and three
NAMED rows. So the window is drawing the same page that drew
correctly, and everything 6.351.0 added is Lua-side.
🔑 WHICH READS YOUR TWO SENTENCES AS ONE: the window appears, the
stage is black because nothing is playing, and nothing is playing
because you could not drop a film onto it. Your report agrees — 3
films queued, nothing playing, 0 played this session, not one way in
even attempted. So I expect the drop fixing this to fix both halves.
C1. Open it with films queued and nothing playing, and tell me which
    of these four you can see: "Mug Player" top left · "nothing
    playing" beside it · your films listed BY NAME in the deck ·
    anything at all on the black stage.
    If the first three are there, "nothing" was the stage and the drop
    is the whole story. If they are NOT there, the page's script is
    dying on your Mac and that is a different and bigger release — so
    this one answer decides the next one.
C2. The report you sent was taken after you closed the window, which
    wiped the two lines that would have answered this. That is mine,
    not yours, and it is fixed here: the `page` line now tells
    "closed, and its page HAD run" apart from "its page never once
    spoke". **One report with the window open** settles it.

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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
