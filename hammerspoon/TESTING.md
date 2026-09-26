# TESTING — how to score release 6.290.0

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

## 6.290.0

6.290.0 verify with LL — 🔬 THE GATE TESTS ITS OWN BELIEFS (KNOWN GROUND)
WHAT CHANGED: nothing you can press. This release changes what the test
gate is allowed to believe about macOS, and it is the answer to your
question — how have so many mistakes been introduced.
WHY IT MATTERS: I classified all ten losses on the scoreboard by where
the defect actually lived. Eight of ten sit at the macOS boundary — the
one surface the gate cannot see. One is a bad test recipe of mine. At
most two are a solved thing coming unsolved. ZERO are logic errors in
pure Lua; not one. So the mechanism is not carelessness: this config
writes the code, the test AND the stub from one model of macOS, and
when that model is wrong all three are wrong the same way and they
agree with each other. Green meant "the code matches our beliefs". It
never once meant "the code matches macOS". Your loop is closed — you
press the key and reality answers. Mine was open.
🔎 AND THE CLASS WAS LEARNED FIFTEEN TIMES AND ENFORCED ZERO TIMES.
Every instance was fixed at the one stub that had just cost a release,
while seventy-five other suites went on telling the same lie about the
same provider. 28 of them were corrected in this release.

A. THE HEADLINE — there is nothing to press, so this is the whole test.
A1. Install and reload. Everything must behave exactly as it did on
    6.289.0: ⇪T, ⇪D, ⇪N, ⇪3, ⇪4, ⇪X, ⇪space, the music card.
    EXPECT: no visible difference of any kind. This release does not
    touch a single shipped module — only tests/ and the documents.
A2. Console: `_G.configVersion` → `6.290.0`.
A3. That is it. If anything at all behaves differently, that is a real
    finding and I want it, because this release claims to change
    nothing you can see.

B. IF YOU WANT TO SEE THE INSTRUMENT (optional, needs the repo, not
   your Mac's install).
B1. `lua5.4 tests/test_stub_fidelity.lua` from the unpacked archive.
    EXPECT: `27 passed, 0 failed`, and a printed list of eight further
    contracts it knows about and deliberately does NOT check.
B2. That printed list is the point as much as the checks are. A gap
    written down is not a gap implied by silence.

C. A JUDGEMENT ONLY YOU CAN MAKE.
C1. This release spends a whole version number on testing rather than
    on anything you can use. Was that the right call? You asked for it,
    and I think it is the highest-value thing in this batch — but you
    are the one waiting on features, so say if you would rather I spend
    the next one on the queue and fold work like this in alongside.
C2. The three self-inflicted bugs this audit found IN ITSELF are in
    CHANGELOG 6.290.0, named. One of them — a sentry searching for a
    phrase that existed only on the sentry's own line, so it matched
    itself and could never fail — is the kind of thing that would have
    sat there for a year. If you want, the next audit release is the
    one that sweeps the OTHER sentries in this config for the same
    shape. Say the word.



## 6.289.0

6.289.0 verify with LL — ⏯ THE PLAY/PAUSE KEY (KNOWN GROUND)
WHAT CHANGED: the keyboard's own ⏯, ⏮ and ⏭ keys now drive the music
card — but only while it has a queue.
WHY IT MATTERS: you said "pressing play/pause doesn't work, but volume
keys do", and those two sentences are about the same row of keys. The
volume keys are macOS's own, which is why they work everywhere. ⏯ was
going wherever macOS thinks your music is, and that was never this
card. Nothing was broken — the key had simply never been claimed.
🚨 AND I DELIBERATELY DID NOT TAKE IT ALWAYS. If this config ate ⏯
whenever it was loaded, Music.app and every browser tab playing audio
would lose the key the moment Hammerspoon booted, silently. So it is
taken only when the card has a queue.

A. THE HEADLINE.
A1. ⇪⇧pad., drop two or three tracks on the card. Something plays.
A2. Press the keyboard's ⏯ key (F8).
    EXPECT: the card pauses. Press it again: it resumes.
A3. Press ⏭ and ⏮. EXPECT: the card steps forward and back.
A4. Volume keys: unchanged, still macOS's. That was your own call in
    6.231.0 and I have not touched it.

B. THE ONE THAT PROTECTS EVERY OTHER APP — please do this one.
B1. Empty the card's queue (or just do not queue anything), then play
    something in Music.app, Spotify or a YouTube tab.
B2. Press ⏯.
    EXPECT: THAT app pauses, exactly as it does today. Hammerspoon must
    not swallow the key.
    A FAIL here is the serious one: tell me at once and
    `settings = { music_player = { mediaKeys = false } }` turns it off.
B3. Now queue something on the card and press ⏯ again: the card wins.
    That is the trade, and it is the narrowest one I could draw.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.musicReport()` — a new "⏯ keys" line reads
    `watching ⏯ ⏮ ⏭ · N taken · N passed through to macOS`.
    If it reads `⚠️ WANTED but not running`, this Mac would not give
    Hammerspoon an event tap and the keys are doing nothing new —
    paste it, that is the evidence.

D. A SENTENCE I NEED FROM YOU.
D1. When you wrote "pressing play/pause doesn't work", did you mean
    the KEYBOARD's ⏯ key — which is what I have built — or the ▶︎
    BUTTON on the card / the space bar? If it was the button or the
    space bar, that is a different fault and the report's "keyboard :"
    line names it: paste `_G.musicReport()` right after pressing space
    on the card and I will fix that instead. One sentence is enough.



## 6.288.0

6.288.0 verify with LL — 🖥 THE SHEET OPENS WHERE YOU ARE (KNOWN GROUND)
WHAT CHANGED: ⇪/ is placed on the screen this config resolved, and can
no longer be pulled onto another monitor by a spot you saved there.
WHY IT MATTERS: your two sentences are ONE bug, which is why I want to
say the mechanism plainly. Your saved spot is stored as an offset into
the screen you dragged it on. Dragged to the right-hand side of the 4K
that offset is about 2000 points. Applied to the Air's top-left, 2000
points to the right is physically ON the 4K — and the helper that was
supposed to keep the panel on a screen kept it on THAT one, throwing
away the screen every line above it had just worked out. And a sheet on
the other monitor is a sheet that is not in front of you: you drag it
back, and it appears. Second sentence, same event.

A. THE HEADLINE — this needs both monitors.
A1. On the LG, press ⇪/ and drag the sheet to its right-hand side.
    Close it.
A2. Click into an app on the AIR. Press ⇪/.
    EXPECT: the sheet is on the AIR, fully on screen, over toward its
    right-hand edge. It must NOT be on the LG.
A3. Console: `_G.cheatSheetReport()`. The new "place :" line should
    read `nudged back onto this screen — the spot you saved was on a
    bigger one`, with the screen it used underneath.
A4. Now back on the LG: press ⇪/.
    EXPECT: your spot, exactly — it fits there, so it is obeyed, and
    the report reads `where you put it`.

B. IS IT IN FRONT?
B1. Each time it opens, is it readable without you touching it?
    EXPECT: yes. If it EVER opens and is not in front on the monitor
    you are looking at, that is a second bug and I have not found it —
    run `_G.cheatSheetReport()` and `_G.screenReport()` at that moment
    and paste both. Those two together name the screen, the rule that
    chose it, and where the panel went.

C. MUST STILL WORK.
C1. Drag the sheet anywhere and reopen: it is where you left it.
C2. Type to filter, scroll with the wheel, Esc to close — unchanged.
C3. `_G.cheatSheetCenter()` still forgets the spot and re-centres.
C4. Unplug the LG, then ⇪/. EXPECT: it opens on the Air, on screen.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. When your saved spot does not fit the smaller screen, I nudge it to
    the nearest edge rather than re-centring — so a sheet you like on
    the right stays on the right. Is that what you want, or would you
    rather it centred on a screen it does not fit? "nudge" · "centre".



## 6.287.0

6.287.0 verify with LL — ✏️ THE TEXT TOOL IS A TEXT BOX (KNOWN GROUND)
WHAT CHANGED: all four of your text-box asks, in one release, because
they were one defect seen from four sides.
WHY IT MATTERS: a text note had never had a WIDTH — only a font size.
6.188.0 made the corner handle scale the letters, so there was nothing
to wrap at, nothing for Return to make a second line of, and the one
control on the box did the one thing you did not want it to.

A. THE HEADLINE. ⇪⇧1 on a screenshot, press T, click.
A1. Type a sentence long enough to be worth wrapping, then press ⏎.
    EXPECT: a NEW LINE inside the box. It must NOT finish the box.
A2. Type a second line. Press ⇧⏎.
    EXPECT: done, and the note shows BOTH lines on the shot.
A3. Drag the corner handle to the LEFT (no modifier).
    EXPECT: the box gets narrower and the words RE-WRAP. The letters
    stay exactly the same size. That is asks 2, 3 and 5 at once.
A4. Hold ⇧ and drag the same corner.
    EXPECT: the letters grow and shrink, the way they always did.
A5. ⌘Z. EXPECT: the last of those goes back — a re-wrap undoes like
    a move.

B. THE ONES THAT PROTECT WHAT YOU ALREADY HAVE.
B1. Make a box, close the editor with Esc, reopen the SAME shot.
    EXPECT: the box comes back with its lines and its width intact.
    (6.286.0 is what makes Esc keep it at all — do that block first.)
B2. Open a shot you annotated on an OLDER build, if you have one.
    EXPECT: the old text notes look exactly as they did. They have no
    width stored, so they stay one line until you drag one.
B3. Type a very long single word with no spaces — a URL will do — in a
    narrow box. EXPECT: it breaks across lines rather than running out
    of the box.
B4. Make a two-line note ON something (an arrow tip, a button).
    EXPECT: it grows DOWNWARD. The first line stays where you clicked,
    so the note never walks off the thing it points at.

C. MUST STILL WORK — every tool shares this canvas.
C1. ⌘click a text box: its words open, pre-filled.
C2. Drag a text box by its middle: it moves.
C3. Esc with the box open cancels the BOX; Esc again closes the editor.
C4. ⌘⏎ saves, and the saved PNG has the wrapped lines in it exactly as
    they looked on screen.
C5. Blur, arrow, line, oval, highlighter, counter, spotlight,
    magnifier — unchanged.

D. A JUDGEMENT ONLY YOU CAN MAKE — and this is the one I most want.
D1. ⇧⏎ to finish. Is that the right key? The alternatives are ⌘⏎
    (which is Save & copy everywhere else in the editor, so it would
    be two meanings for one chord) or "click away", which already
    works. "⇧⏎ is fine" · "make it something else" decides it.
D2. Plain drag re-wraps, ⇧drag scales — your suggestion. If it feels
    backwards in the hand, say so and I will swap them; it is one line.
D3. A new box is born as wide as the words you typed. Would you rather
    it started at a fixed width — say a quarter of the shot — so it
    wraps from the first sentence? That is a default, not a release.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
