# TESTING — how to score release 6.344.0

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



## 6.342.0

6.342.0 verify with LL — 📐 ⌘D DRAGS THE AREA FIRST (KNOWN GROUND)
WHAT CHANGED: ⌘D in the screenshot editor is macOS's ⇧⌘5 order now —
the editor gets out of the way, you DRAG the area you want, then you
get five seconds to arrange the screen, then THAT rectangle lands on
the shot. Your ask, in your words.
🔎 AND 6.255.0 WAS NOT BROKEN, which is worth saying first: hide ·
count five seconds · shoot the WHOLE screen · land it on the shot is
exactly what that release built, with no selector and no crosshairs by
design. What you described is a different ORDER, and you were right
that it is the better one.
🚪 OUR SELECTOR, NOT macOS's — so you get the crosshairs and the live
W × H, and ⌘5 "repeat area" gets the rectangle for free. macOS's own
`-i` crosshair cannot tell us where you dragged, which is why ⇪4 lost
"repeat area" in 6.337.0 and why this one could not use it.

A. THE HEADLINE — thirty seconds.
A1. ⇪⇧1 on any screenshot to open the editor.
A2. Press ⌘D (or the ⏲ Area +5s button in the right rail).
    EXPECT: the editor DISAPPEARS, and a moment later the crosshairs
    and the live size box appear over your desktop.
    **A FAIL is the old behaviour — no crosshairs, five seconds, and
    then the whole desktop landing on the shot.**
A3. Drag a rectangle around something and let go.
    EXPECT: an alert reading "📐 1280 × 720 in 5 seconds — set it
    up…", naming the rectangle you just dragged.
A4. Use those five seconds: open a menu, hover something, put a
    dialog up.
    EXPECT: after five seconds the editor comes back with THAT
    rectangle on the shot as a movable image. Drag it, scale it by its
    corner, ⌘Z takes it off.
A5. 🔎 LOOK AT THE PICTURE: the editor must NOT be in it, even though
    you dragged over where it was sitting. If it IS in there, the
    settle beat is too short on your Mac and that is a number, not a
    release — tell me.

B. THE ONE THAT PROTECTS YOU FROM A LOST WINDOW.
B1. Press ⌘D and then press Esc on the selector instead of dragging.
    EXPECT: the editor comes straight back, with an alert reading
    "📐 Nothing captured — the selection was cancelled. The editor is
    back." No warning, no error, nothing in the Console.
    **A FAIL is the editor staying hidden** — that is the thing this
    release had to build a second belt for, and I want to know at once.
B2. Press ⌘D and then click once without dragging (a tiny drag).
    EXPECT: "📐 Nothing captured — that drag measured 0 × 0", and the
    editor is back.
B3. Press ⌘D and then just leave it. Walk away for two minutes.
    EXPECT: the selector goes by itself and the editor comes back.
    That is the long belt, and ninety seconds is deliberately generous
    — if it feels too long, say so and it is a number.

C. MUST STILL WORK — this touched the window that hides itself, so
   this half matters more than A.
C1. ⌘F (🖥 Full screen) — unchanged: the editor blinks out, the whole
    screen is taken, the editor comes back with it on the shot.
C2. ⌘A (📸 Add capture) — unchanged: drag an area and it lands AT
    ONCE, no countdown. That is what ⌘A is for.
C3. ⌘O (🖼 Load shot) and ⌘V (📋 Paste image) — unchanged.
C4. ⇪4 — unchanged: macOS's own crosshair, as of 6.337.0.
C5. ⇪5 scrolling capture — our selector, with crosshairs and the live
    size. This is the OTHER caller of the thing I changed, so it is the
    one most likely to have broken: drag over a scrolling page and
    check you get a stitched shot.
C6. The nine drawing tools, ⌘Z, Esc, ⌘⏎ Save & copy.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.screenshotEditorReport()` — there is a new `⌘D :` line saying
    what the key does now, with a cancel count beside it. If it does
    NOT say "drag an area", the release did not take.
D2. `_G.screenshotsReport()` — a new `region :` line:
      region  : 3 asked — 2 your rectangle · 1 cancelled · 0 fell back
                to the whole screen
    **If "fell back to the whole screen" is ever a number**, paste it:
    that Mac could not draw our selector, you got the old shape, and
    the line under it names macOS's reason.
D3. If it ever says "⚠️ N of them shot AT ONCE", paste that too — that
    Mac would not arm the countdown, so you had no time to set up.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Five seconds, between the drag and the shot. Right for what you
    use it for, or should it be longer now that you have already spent
    time choosing the rectangle? It is `delaySecs`, a number, not a
    release — say a number and I will change the default.
E2. Ninety seconds is how long the selector may sit open before the
    editor comes back by itself. Too long? Too short?
E3. "⏲ Area +5s" is the button's new label, with the order spelled out
    on hover. Does the label read right to you, or would you rather it
    said something else?
E4. 🔨 CRUDE OR ELEGANT: nothing was broken and nothing was lost —
    ⌘D did exactly what it was built to do and the editor always came
    back. My reading is that this is a SHAPE you had never been asked
    about, not a defect, so I have logged it as one pass and your
    sentence as the symptom. Your tag.
E5. 📏 AND THE OTHER THREE: you said "those four screenshot tools run
    weird". ⌘A, ⌘F and ⌘O were all unreachable until 6.339.0 — a guard
    asked `core.has`, which the core table has never carried — so if
    any of them still behaves oddly on this build, that is new
    information and I want it named one at a time.


## 6.341.0

6.341.0 verify with LL — 🔁 THE SHOT KEEPS THE CLIPBOARD (KNOWN GROUND)
WHAT CHANGED: ⇪4 leaves the PICTURE on the clipboard. Always. ⇪⇧4 is
the OCR door and is untouched.
🔎 AND "SOMETIMES" WAS THE FEATURE, which is why it felt like a fault.
6.319.0 put the words of a ⇪4 shot on the clipboard — but only when
the OCR that NAMES the file happened to find words, only while the
shot was still the thing on the clipboard, and only within 25
seconds. A photograph, a diagram, a ⌘C of your own in between: the
picture stayed. One key, two outcomes, nothing on screen beforehand
to say which. Your sentence is the whole bug report.
🚨 AND THE OCR STILL RUNS IN THE BACKGROUND — you asked for that by
name and nothing about it changed. The shot is still renamed after
its words, the words still go into the Finder comment and into ⇪O.
What stops is only the clipboard write.

A. THE HEADLINE — thirty seconds.
A1. Press ⇪4 and drag over a paragraph of real text.
A2. Wait five seconds (longer than the OCR takes), then ⌘V somewhere.
    EXPECT: the PICTURE. **A FAIL is pasting the words** — that is the
    old behaviour.
A3. Do it four or five more times over different things — a photo, a
    dark panel, a page of text, a screenshot of a screenshot.
    EXPECT: the picture, every single time. The whole point is that
    it no longer depends on what was in the shot.
A4. Look at the file in the screenshots folder a few seconds later.
    EXPECT: it is still RENAMED after its words. If it is not, the
    reading has been switched off with the writing and that is a real
    break — tell me at once.

B. THE OTHER DOOR — the one you named.
B1. Press ⇪⇧4 and drag over some text. EXPECT: "📝 Text copied: …"
    and ⌘V pastes the WORDS. Unchanged.
B2. ⇪⇧4 over a QR code. EXPECT: "🔳 Code copied: …". Unchanged.
B3. ⇪O. EXPECT: the words of the ⇪4 shots from step A are all in the
    log, and ⏎ on a row copies the full text. That is where the words
    live now, and it is one keypress.

C. MUST STILL WORK.
C1. ⇪4's macOS crosshair, the magnifier, SPACE for a window (6.337.0).
C2. The shot lands in the folder AND on the clipboard, as always.
C3. ⇪⇧1 opens the editor on it; ⇪⇧5 lists it; ⌘9 sweeps the backlog.
C4. ⇪5 scrolling capture, ⇪⇧2 window, ⇪⇧3 delayed — all unchanged.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.screenshotsReport()` — the `clip :` line. Healthy reads
    "the shot keeps the clipboard — ⇪⇧4 is the OCR door (shipped
    default since 6.341.0) · N arrival(s) kept the picture this
    session". **That N is the release working**, not a tally of
    failures: it counts the shots that would have been swapped before.
D2. If that line ever says anything about a REFUSED write, paste it.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Is the picture always right, or do you want the words on SOME ⇪4
    shots? There is a middle I did not build and will not guess at:
    swap only when the shot is MOSTLY text. That is a condition
    again — a sixth invisible predicate — which is the thing this
    release exists to remove, so say the word if you want it anyway.
E2. `settings = { screenshots = { textToClipboard = true } }` puts
    6.319.0's behaviour back exactly. Say so and I change the default
    rather than leaving you a line to type.
E3. 🔨 CRUDE OR ELEGANT: nothing broke and nothing was lost — the
    words were always in ⇪O and in the file name. What it cost was
    trust in what the key does. My reading is that it degraded, one
    pass, but it is the second pass on 6.319.0's ask. Your tag.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
