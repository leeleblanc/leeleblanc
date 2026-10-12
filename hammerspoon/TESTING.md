# TESTING — how to score release 6.359.0

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

## 6.359.0

6.359.0 verify with LL — 🕘 THE SNIPPET PICKER REMEMBERS (NEW GROUND)
WHAT CHANGED: the snippets you PICK from ⇪⇧S now come back at the top
of it, newest first, under a 🕘 RECENT heading. You asked for this
twice. Nothing was recording picks before — I grepped the module for
five different names for a recency store and found none of them, so
this is a build and not a setting I had missed.
🔑 THE ONE RULE, AND IT IS YOUR ANSWER: a snippet counts as used when
you PICK it from the picker. A trigger you TYPE is not counted, on
purpose — you fire thousands of those a day and they would bury the
handful you choose by hand within the hour.

A. THE HEADLINE — a minute.
A1. ⇪⇧S. EXPECT: no 🕘 section yet — nothing has been picked on this
    Mac. An empty queue draws no heading rather than an empty one.
A2. Pick any snippet. ⇪⇧S again.
    EXPECT: 🕘 RECENT at the very top, that snippet under it.
A3. Pick a different one. ⇪⇧S again.
    EXPECT: the NEW one is first, the previous one second.
A4. Pick the FIRST one again. ⇪⇧S again.
    EXPECT: it moves back to the top and there is still only ONE of
    it. **A FAIL is two copies.**
A5. Now TYPE one of your triggers (`;bd`, `gg1` — whatever you use).
    ⇪⇧S. EXPECT: the queue has NOT changed. That is the rule above
    working. If a typed trigger shows up here, tell me — it means the
    recorder is on the wrong road.

B. MUST STILL WORK.
B1. The pause row is still the first row, above the 🕘 heading.
B2. Your pinned collection (textpanders) is still the first of the
    LIBRARY's sections, under the queue.
B3. ⏎ on a collection heading still narrows to that collection, and
    ◂ All snippets still comes back.
B4. ⏎ on the 🕘 heading narrows to the recent list alone.
B5. Type to search. EXPECT: ONE row per snippet — the 🕘 copy steps
    out of the way while you are searching. Clear the box and both
    are back.
B6. A snippet picked from the 🕘 section inserts exactly what its
    twin lower down inserts.
B7. The ⇪V preview pane still follows the rows, 🕘 rows included.

C. PASTE BACK.
C1. `_G.snippetsReport()` — it EXISTS now. Last time you ran it your
    Console said "attempt to call a nil value". I want the whole
    block: the library line, the `recent :` line, the numbered rows
    and the `store  :` path.
C2. Run it once BEFORE you pick anything. EXPECT: `no store yet —
    nothing has been picked on this Mac`. That wording is deliberate:
    an empty queue has to say WHICH empty.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. NINE rows. I took that number from your own words about ⇪\ ("the
    most recent nine documents"). Too many? Too few? It is one line:
    `settings = { expander = { recentShow = 5 } }`.
D2. The queue keeps 200 and never forgets by AGE — a snippet you
    reach for once a quarter stays. Is that right, or would you
    rather it aged out?
D3. Should the 🕘 rows be a COPY (what they are — the snippet is also
    still in its own collection) or should picking one MOVE it out of
    its collection? Copy is what I built, so your packs stay complete.



## 6.358.0

6.358.0 verify with LL — 🖥 ⌃⌘F FILLS THE SCREEN (KNOWN GROUND)
WHAT CHANGED: ⌃⌘F in the Mug Player fills the screen, and pressing it
again puts the window back exactly where and how big it was.
🔬 AND macOS'S OWN FULL SCREEN IS NOT REACHABLE, said plainly rather
than half-built: Hammerspoon's webview has no fullScreen window mask
at all (I read the list — libwebview.m:2533-2562) and this window is
borderless. So ⌃⌘F resizes it. It looks the same; it is not the same
thing, and the report says which.

A. THE HEADLINE — twenty seconds.
A1. ⇪⇧, then ⌃⌘F. EXPECT: the window fills the screen.
A2. ⌃⌘F again. EXPECT: back to the size AND the spot you had it.
A3. Move the window somewhere odd first, then A1 and A2.
    EXPECT: it comes back to THAT spot, not to the middle.
A4. Fill it, then drag a film onto it. EXPECT: the drop still works
    anywhere on the window — the drop area moves with it.
A5. Fill it, close it, reopen it, press ⌃⌘F.
    EXPECT: it FILLS. **A FAIL is it shrinking** to last session's
    frame.

B. MUST STILL WORK.
B1. Plain ⌘F does whatever it did before — this key asks for ⌃ too.
B2. ⌘O, space, ↑↓, ⏎, ⌘1–9, ⌫, Escape, the ✕ on a history row.
B3. The film's own full-screen button in the controls is macOS's and
    is untouched; Escape leaves it with the window still up.

C. PASTE BACK.
C1. `_G.mugReport()` — a new `size   :` line and a `↳ ⌃⌘F  :` count.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Filled means edge to edge with no gap. Want a margin? It is a
    number: `settings = { video_player = { fillGap = 20 } }`.
D2. Is ⌃⌘F the right key, now that it is not macOS's full screen?



## 6.357.0

6.357.0 verify with LL — ☁️ A FILM STILL IN THE CLOUD (KNOWN GROUND)
WHAT CHANGED: the Mug Player checks that a film's bytes are actually
on this Mac before it reads them, and refuses with a clear message if
they are not.
🔎 YOUR READING WAS RIGHT AND YOU PROVED IT YOURSELF. Robin Hood from
the Desktop played; Black Hawk Down from OneDrive beach-balled. Same
build, same key, one difference. Your Console has the rest: `🧊
Hammerspoon HUNG for 72 s at 2026-10-12 04:05:48 and was relaunched
by the stall guard`. Reading a OneDrive placeholder makes macOS
download it first, and this loader reads on the main thread — so the
first read froze everything until the download caught up.

A. THE HEADLINE — needs a film that is in OneDrive and NOT downloaded.
   In Finder a cloud-only file shows a ☁ next to it.
A1. ⇪⇧, and press ⏎ on that film.
    EXPECT: no freeze. A message naming the film, saying the bytes
    are not here yet, how much of it is, and that nothing is wrong
    with the film or the player.
    **A FAIL is a beach ball.** If you get one, that is the guard not
    firing and I want `_G.mugReport()` the moment you have the Mac
    back.
A2. Right-click that film in Finder → Download Now. Wait for the ☁
    to go.
A3. ⏎ on it again. EXPECT: it reads and plays, as Robin Hood did.

B. MUST STILL WORK — the guard must not cost you a film.
B1. Play a film from the Desktop. EXPECT: unchanged.
B2. Play a film from OneDrive that IS fully downloaded.
    EXPECT: it plays. **A refusal here is the serious failure** —
    paste the report, the line names both numbers.

C. PASTE BACK.
C1. `_G.mugReport()` — a new `on disk:` line with three states, and a
    `↳ cloud :` count when anything was refused.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Right now a cloud film is handed to your usual player, which
    streams it while OneDrive downloads. Is that what you want, or
    should it just refuse and wait? `settings = { video_player =
    { handOff = false } }` is the second.
D2. 90% of the file has to be local before it reads. If a film you
    know is downloaded gets refused, send me the line — the numbers
    in it are the evidence and the threshold is one value.



## 6.356.0

6.356.0 verify with LL — 🗑 WINDOW RETURN IS OFF (KNOWN GROUND)
WHAT CHANGED: nothing watches your monitors and nothing moves your
windows. Your word, done.

A. THE HEADLINE.
A1. Use the Mac normally for a day — dock, undock, move windows.
    EXPECT: NOTHING of yours ever moves on its own. That is the
    whole release.
A2. Console: `_G.windowReturnReport()`. EXPECT:
      switch : OFF — the shipped default since 6.356.0, on your own word
      running: no — switched off …
      holding: nothing — no watcher, no timer
      layouts: N monitor setup(s) remembered — kept, never cleared …
    **If `holding:` ever names a watcher or a timer, paste it** —
    that is off-but-still-running, which is the thing this had to
    avoid.
A3. ⇪/ and search `window return`. EXPECT the card title says OFF.

B. NOTHING WAS LOST.
B1. That `layouts:` count is what it captured before today. It is
    still in hs.settings and switching this off did not touch it.
B2. `settings = { window_return = { enabled = true } }` brings it
    back — and it really does start, which is the part that needed
    building: it used to be startable only at boot.
B3. `_G.windowsBack()` still puts windows back by hand if you ever
    want it once.

C. A JUDGEMENT ONLY YOU CAN MAKE.
C1. If windows are STILL jumping with this off, that is a different
    tool and I want to know — the candidates are window_move (⌘-drag)
    and mouse_follows. One sentence about when it happens is enough.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
