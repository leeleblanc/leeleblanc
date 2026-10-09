# TESTING — how to score release 6.342.0

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



## 6.340.0

6.340.0 verify with LL — 🔎 A FIRST OPEN IS NOT AN EMPTY VAULT (KNOWN GROUND)
WHAT CHANGED: Hamsidian's first open shows your notes seconds sooner,
and while it is still reading it SAYS so instead of saying you have
none.
🚨 AND YOUR NOTES WERE NEVER MISSING — that is the first thing to say,
because the words it printed were the worst possible ones. The list
is built when the window OPENS, the page is drawn BEFORE that read
starts, and the empty list said **"no notes yet — ⌘N"**. Over a vault
holding all of them. That is the fourth time this config has printed
"there is nothing" where it meant "I have not looked yet", and this
is the one place it reads as your writing being gone.
⏳ AND IT WAS SLOWER THAN IT HAD TO BE: the names are known after the
FIRST of four background greps, and the page was told after the
fourth. Escaping and reopening worked because the second open is
drawn from the list the first open had finally finished building.

A. THE HEADLINE — do this on a COLD Hammerspoon, which is the case
   that failed.
A1. Reload Hammerspoon (⌘⌃R). Do not open anything else.
A2. Press ⇪3.
    EXPECT: your notes, within about a second.
    If there is any gap at all, the left column reads
    **"reading your notes…"** in grey.
    **A FAIL is "no notes yet — ⌘N"** — that sentence should now be
    impossible unless the vault is genuinely empty.
A3. Do NOT press Escape. Just watch for two or three seconds.
    EXPECT: the notes fill in by themselves. Before this release
    that is the wait you were escaping out of.
A4. Escape, press ⇪3 again. EXPECT: instant, as it always was.

B. THE ONE THAT PROTECTS YOUR WRITING — worth the thirty seconds.
B1. Reload again, press ⇪3, and IMMEDIATELY press ⌘F and type a few
    letters of a note you know exists — before the list appears.
B2. Press ⏎ straight away.
    EXPECT: **nothing is created**, and the hint line under the box
    reads "reading your notes… — ⏎ creates once the list is in".
    Wait a second and press ⏎ again: it opens the note.
    **A FAIL is a new empty note appearing with your typed text as
    its name** — that is 6.307.0's bug reached through timing, and it
    writes into the folder with your writing in it.
B3. Once the list is in, ⌘F a name no note has and press ⏎.
    EXPECT: it still CREATES that note, exactly as before. The guard
    must not have cost you the feature.

C. MUST STILL WORK — this touched the window's whole left column.
C1. The notes list, your scratch tabs in the same list (6.333.0), the
    icons telling them apart.
C2. ⌘N, ⌘F, ↑↓, ⏎, the ✕ delete, 🗑 the bin, ⌘⇧K tasks, ⌘⇧F search,
    ⌘G graph, ⌘⇧B board.
C3. 🚨 ⌘Z IN A NOTE, which is the thing most likely to have broken:
    open a note, delete a paragraph, WAIT TEN SECONDS for a re-scan,
    press ⌘Z. EXPECT: your text comes back (6.323.0). If it does
    not, this release broke it and I want to know immediately.
C4. Add a `#tag` to a note and watch the tag list fill in a moment
    later, without your typing being disturbed.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.vaultReport()` after an ordinary morning — the `notes :` line
    and the rows/rebuilds line under it.
D2. If you ever see "reading your notes…" and it NEVER resolves,
    paste the whole report: that is the scan failing rather than
    being slow, and those are opposite facts.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. How long is the gap now, on a cold start? If it is still long
    enough to be annoying, the next step is building the index at
    BOOT instead of on first open — which costs boot time and was
    deliberately moved off it in 6.334.0's lineage. Your call, and
    it is a real trade rather than a free win.
E2. "reading your notes…" — right words? It is what you will see in
    the one second that used to look like an empty vault.
E3. 🔨 CRUDE OR ELEGANT: nothing was lost and the Mac was fine, but
    for a moment every time you opened it, the tool holding your
    writing told you it was empty. My reading is that the DEGRADE was
    graceful and the MESSAGE was a lie — the same shape as 6.339.0.
    One pass. Your tag.



## 6.339.0

6.339.0 verify with LL — 🔌 FOUR BUTTONS THAT HAVE NEVER RUN (KNOWN GROUND)
WHAT CHANGED: ⌘A, ⌘D, ⌘F and ⌘O in the screenshot editor work. Not
"work better" — work at all, for the first time since each shipped.
🔎 YOUR SCREENSHOT WAS THE WHOLE DIAGNOSIS. "Add capture needs the
screenshots module, which is not loaded" was drawn over a Console in
which `_G.screenshotsReport()` had just printed the entire SCREENSHOTS
block and ⇪4 had logged a press four minutes earlier. The module was
loaded; the report was its own proof. What was missing was the way to
ASK: the guard called `core.has`, and the `core` table every module is
handed carries `provide` and `call` and has never carried `has`. Nil,
nil-guarded, so it refused silently rather than erroring — which is
why it survived four releases and a green gate.
🚨 SO EXPECT THESE TO BE NEW TO YOU. If any of them does something you
have seen before, say so — that would mean I have the cause wrong.

A. THE HEADLINE — ⌘A, the one you photographed.
A1. ⇪⇧1 on any screenshot to open the editor.
A2. Press ⌘A (or the 📸 Add capture button in the right rail).
    EXPECT: the editor stays put and a selector appears over the
    screen — drag a rectangle over something.
    **A FAIL is the old alert**, "Add capture needs the screenshots
    module, which is not loaded". That sentence should be impossible
    now; if you see it, stop and tell me.
A3. Let go. EXPECT: what you dragged lands ON the shot as a movable
    image at about 40% width. Drag it; drag its corner to scale it.
A4. ⌘Z. EXPECT: it comes off again.
A5. 🪟 Move the editor window aside first if it covers the thing you
    want — ⌘A does NOT hide it, deliberately. ⌘F is the one that does.

B. ⌘O — LOAD SHOT (6.258.0, never run).
B1. In the editor, press ⌘O (or 🖼 Load shot).
    EXPECT: a picker listing your other screenshots, newest first.
    NOT "Load shot needs the screenshots module…".
B2. Pick one. EXPECT: the canvas GROWS and that shot is drawn in the
    new space at its own size — two wide shots stack, a tall one goes
    beside.
B3. 🚨 THE RULE WORTH CHECKING, because it is the whole design: draw
    an arrow or a text box on the FIRST shot before you press ⌘O.
    After the grow it must still be exactly on the thing it pointed
    at. If any mark moves, that is a real break and I want the
    screenshot.
B4. ⌘Z takes the whole grow back, canvas size and all.

C. ⌘D AND ⌘F — THE TWO SCREEN GRABS (6.255.0 / 6.256.0, never run).
C1. In the editor, press ⌘F (🖥 Full screen).
    EXPECT: the editor blinks out, the whole screen is taken, and the
    editor comes straight back with that screen on the shot.
C2. 🔎 LOOK AT THE PICTURE: the editor must NOT be in it. If it is,
    the settle beat is too short on your Mac and that is a number, not
    a release — tell me and I will move the default.
C3. Press ⌘D (⏲ Delayed 5s). EXPECT: the editor hides, you get five
    seconds to arrange the screen — open a menu, hover something —
    then it comes back with the screen on the shot.
C4. 🚨 THE ONE THAT MATTERS MORE THAN THE FEATURE: the editor must
    ALWAYS come back. If it ever hides and does not return within
    about eight seconds, that is a real break — and it is caught: an
    alert reads "⚠️ Screenshot editor — the delayed capture never
    answered — the window is back". Paste that if you see it.

D. MUST STILL WORK — I changed a table every module is handed.
D1. Boot: All green, 71 modules, the usual ⇪ shortcut count.
D2. A spread of keys across different tools: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4,
    ⇪space, ⇪V, ⇪/. Nothing should feel different anywhere.
D3. In the editor: the nine drawing tools (B T A L O H C S M), ⌘Z,
    ⌘-drag on the title strip, Esc, and ⌘⏎ Save & copy.
D4. ⌘⏎ specifically: it saves "… (edited).png" beside the original AND
    puts it on the clipboard, as it always has. It now takes the
    module's door to do it rather than its own fallback, so this is
    the one existing behaviour this release could plausibly have
    disturbed. ⌘V somewhere afterwards and check you get the picture.

E. PASTE BACK, PASS OR FAIL.
E1. `_G.screenshotEditorReport()` — the whole block, after doing A–C.
    The "capture :" line should show asked/landed counts that are no
    longer 0 for the first time.
E2. `_G.screenshotsReport()` — unchanged by this release, but its
    "routes :" line tells me whether ⌘A went through the same path.

F. A JUDGEMENT ONLY YOU CAN MAKE.
F1. Now that these four actually run — are they what you wanted when
    you asked for them? ⌘A and ⌘O were your asks in 6.213.0 and
    6.258.0 and you have never been able to press either. If the
    behaviour is wrong rather than absent, that is a new and much more
    useful conversation.
F2. 🔨 CRUDE OR ELEGANT: nothing broke, nothing was lost, and the
    editor stayed usable throughout — four buttons were simply absent
    while telling you something false about why. My reading is that
    the degrade was graceful and the MESSAGE was a lie, which is its
    own kind of cost; one pass. Your tag.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
