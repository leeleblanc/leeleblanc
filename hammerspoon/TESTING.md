# TESTING — how to score release 6.293.0

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

## 6.293.0

6.293.0 verify with LL — ⌨️ ⌥⌥ OPENS THE MENUS (KNOWN GROUND)
WHAT CHANGED: tap ⌥ twice, quickly, and the front app's own menus
open — the same picker ⇪. gives you.
WHY IT MATTERS: the second half of what you asked for, and the proof
that 6.292.0 was worth a release of its own. Adding ⌥⌥ was nine
lines, because the engine already existed and a gesture is now a
registration rather than a second copy of a state machine.

A. THE HEADLINE.
A1. Click into an app with real menus — Word, Chrome, Finder.
A2. Tap the ⌥ key twice, quickly, with nothing else held.
    EXPECT: a picker listing that app's menu items, searchable.
A3. Type a few letters, press ⏎. EXPECT: that menu item runs.
A4. Press ⇪. EXPECT: the identical picker — one function, two doors.
A5. Full screen an app (⌃⌘F) and tap ⌥⌥ there. EXPECT: it opens.

B. THE ONES THAT PROTECT YOUR TYPING.
B1. Use ⌥ normally — ⌥click, ⌥drag, ⌥⌫, and typing accented
    characters if you use them. EXPECT: nothing opens.
B2. Hold ⌥ for a second and release, twice. EXPECT: nothing.
B3. Tap ⌥, type a letter, tap ⌥. EXPECT: nothing.
B4. 🚨 THE ONE I MOST WANT: hold ⌘ AND ⌥ together and tap twice.
    EXPECT: NEITHER the clipboard nor the menus open. A real chord
    must satisfy no gesture, and with two gestures live that is the
    property that makes them safe together.
B5. ⌘⌘ still opens the clipboard history (6.292.0), and ⌃⌃ still
    opens the editor picker.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.doubleTapReport()` — it should now list BOTH gestures under
    one watcher: `⌘⌘ : clipboard history` and `⌥⌥ : the front app's
    menus`, with `watcher : running` once, not twice.
C2. `_G.menuSearchReport()` — its new `⌥⌥` line, whichever of the
    three states you get.

D. IF IT GETS IN THE WAY.
D1. `settings = { menu_search = { optOpt = false } }` switches just
    this one off; ⌘⌘ and ⇪. are unaffected.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. ⌥ is a modifier you probably use more than ⌘⌘'s ⌘ for one-handed
    things — ⌥click, ⌥drag. If ⌥⌥ fires when you did not mean it,
    tell me how it felt rather than a number and I will move the
    timing; if it is simply the wrong key for this, say so and it
    moves to another modifier in one line.



## 6.292.0

6.292.0 verify with LL — ⌨️ ⌘⌘ OPENS THE CLIPBOARD (KNOWN GROUND)
WHAT CHANGED: tap ⌘ twice, quickly, and the clipboard history opens —
the same window ⇪V gives you.
WHY IT MATTERS: you asked for this in 6.198.0, again on 2026-09-13,
and again this week. It had never been built. The uncomfortable part
is that the machinery has been on your Mac the whole time driving ⌃⌃
(the editor picker); what was missing was four lines registering ⌘⌘
against it. That engine is now a shared one in core/, so ⌥⌥ is the
next release rather than a second copy of the same state machine.
🖥 AND YOUR FULL-SCREEN QUESTION NEEDED NO WORK: these panels are
drawn by an app with no Dock icon, which is exactly why they already
come over a full-screen app. Worth testing anyway — step A4.

A. THE HEADLINE.
A1. Tap the ⌘ key twice, quickly, with nothing else held.
    EXPECT: the clipboard history opens — the ⇪space-style panel, the
    same one ⇪V gives you.
A2. Press Esc, then ⇪V. EXPECT: the identical window. They are one
    function now, so they cannot drift apart.
A3. Try it with the LEFT ⌘ and the RIGHT ⌘. EXPECT: both work.
A4. Put an app in full screen (⌃⌘F) and tap ⌘⌘ there.
    EXPECT: the history comes forward over it. If it does NOT, that
    is a real finding and I want to know — say which app.

B. THE ONES THAT PROTECT YOUR TYPING. These matter more than A, because
   this watches every keystroke on the Mac.
B1. Use ⌘C, ⌘V, ⌘S, ⌘Tab and ⌘W normally for a while.
    EXPECT: nothing opens. A chord is not a gesture.
B2. HOLD ⌘ down for a second and let go, twice. EXPECT: nothing — a
    modifier you are holding to use is not a tap.
B3. Tap ⌘ once, type a letter, tap ⌘ again. EXPECT: nothing. A key
    between the halves proves it was a chord.
B4. ⌘-click something twice quickly. EXPECT: nothing.
B5. Type normally in Chrome, Word and Hamsidian for a while.
    EXPECT: no missed characters, no lag. If typing feels heavier on
    this build than on 6.291.0, STOP and tell me — that is the one
    cost this release could have that I cannot measure from here.
B6. ⌃⌃ must still open the editor picker, exactly as before. It is
    deliberately still on its own engine — see the note below.

C. PASTE BACK, PASS OR FAIL.
C1. `_G.doubleTapReport()` — new. Healthy reads
    `⌘⌘ : clipboard history (⇪V) · side either · N fired` and
    `watcher : running`. If it reads `⚠️ NOT RUNNING`, this Mac would
    not give Hammerspoon an event tap — paste it.
C2. `_G.clipboardReport()` — its new `⌘⌘` line has three states and
    I want whichever you get.

D. IF IT GETS IN THE WAY.
D1. `settings = { clipboard_history = { cmdCmd = false } }` switches
    the gesture off; ⇪V is untouched either way.
D2. If ⌘⌘ fires when you did not mean it to, the two windows are
    tunable — tell me how it felt (too eager / too slow) rather than
    a number, and I will move the default.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. ⌃⌃ (the editor picker) is NOT on the new shared engine yet, on
    purpose: its tap is the one that watches every key press, and a
    mistake there does not break a feature — it takes the keyboard,
    which is what 6.214.0 cost you. So it migrates in its own release
    once this one has run on your Mac for a while. The cost until
    then is two watchers instead of one, which is why B5 matters. Say
    if you would rather I did that migration sooner.
E2. ⌥⌥ → the menu bar is the next release and uses this same engine.



## 6.291.0

6.291.0 verify with LL — ⌨️ F8, BOTH WAYS (KNOWN GROUND)
WHAT CHANGED: "It's the F8 Key" answered it, and then raised a second
question I had not asked. That one physical key sends two completely
different events depending on a System Setting, and 6.289.0 watched
only one of them. Both are watched now.
WHY IT MATTERS: with "Use F1, F2, etc. as standard function keys" OFF
— the macOS default — F8 is a media key and 6.289.0 already works.
With it ON, F8 is a plain function key carrying keycode 100, and
6.289.0 could never have seen it. I cannot tell which you have from
here, and rather than ask you to go and read a System Setting, the
release handles both and the report SAYS which one your Mac uses.
🚨 AND THE OLD REPORT COULD NOT HAVE TOLD US. On the second setting
neither counter moved, so it read "0 taken · 0 passed" on a Mac where
you had been pressing the key all morning — identical to never having
pressed it. That is the thing I most want to stop doing.

A. THE HEADLINE.
A1. ⇪⇧pad., drop two or three tracks on the card. Something plays.
A2. Press F8. EXPECT: it pauses. Press again: it resumes.
A3. Press F7 and F9. EXPECT: back a track, forward a track.
A4. Console: `_G.musicReport()`. Find the new "↳ by route" line.
    EXPECT one of these, and BOTH are a pass — I want to know which:
    · `3 as a media key · 0 as a plain F7/F8/F9` — your setting is OFF
      and 6.289.0 was already right.
    · `0 as a media key · 3 as a plain F7/F8/F9`, with a line under it
      naming the setting — your setting is ON, and this release is
      what made F8 work at all.
    PASTE THAT LINE either way. It is the fact neither of us has.

B. THE ONE THAT PROTECTS EVERY OTHER APP — please do this one.
B1. Empty the card's queue, then play something in Music.app, Spotify
    or a YouTube tab. Press F8.
    EXPECT: THAT app pauses. Hammerspoon must not swallow the key.
B2. With a queue on the card, hold ⌘ and press F8 (⌘F8).
    EXPECT: the card does NOT react — ⌘F8 belongs to whatever app you
    are in. Same for ⌥F8, ⌃F8 and ⇧F8.
    A FAIL on either of these is the serious one:
    `settings = { music_player = { mediaKeys = false } }` turns the
    whole thing off and tell me at once.
B3. Hold F8 down. EXPECT: it toggles ONCE, not forty times.

C. MUST STILL WORK — this release added a tap that sees every
   keystroke on the Mac, so this is the regression sweep and it is
   the important half.
C1. Type normally in Chrome, Word and Hamsidian for a while.
    EXPECT: no missed characters, no lag, nothing odd. If typing ever
    feels heavier on this build than on 6.290.0, stop and tell me —
    that is exactly what I would want to know.
C2. Your autocorrect still works: type `teh ` in Chrome → `the `.
C3. ⇪⇧Esc pauses the config; press F8 with a queue.
    EXPECT: nothing (every tap here stands down when paused). ⇪⇧Esc
    again and F8 works.
C4. The card's own space bar, ↑↓, ⏎, ⌘1–9 and ← → are unchanged.
C5. The volume keys stay macOS's, as you decided in 6.231.0.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.musicReport()` — the whole block. Two lines matter: "by route"
    (above), and a `⚠️ N press(es) THREW inside the handler` line. That
    second one should NOT be there; if it is, paste it — it means the
    handler is failing and the key is silently doing nothing.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. With "standard function keys" ON, F8 has a second job — some apps
    use it as a plain function key. This config takes it only while
    the card has a queue and only with no modifier held. Is that
    narrow enough, or does F8 matter to an app you use? Name the app
    and I will exempt it.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
