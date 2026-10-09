# TESTING — how to score release 6.341.0

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



## 6.338.0

6.338.0 verify with LL — ⏰ THE BACKUP CATCHES UP (KNOWN GROUND)
WHAT CHANGED: the rebuild kit refreshes itself without you running
anything.
🔎 AND THE ANSWER TO YOUR QUESTION IS "it already was", which is why
this is a bug and not a feature. The backup has run on a daily timer
since the config had sections — 17:00, every day. What that kind of
timer does is fire at an INSTANT: if the Mac is asleep at five o'clock,
or Hammerspoon is not running then, that day is skipped and nothing
ever goes back for it. Twelve days old means twelve missed 5 PMs, and
from where you were sitting that looks exactly like a backup nobody
set up.
🔑 WHAT IT DOES NOW: once an hour it asks "is the kit more than a day
old?" and runs one if it is. That covers a wake, a late boot, a reload
and a Mac that was simply off at five — one mechanism, not three.

A. THE HEADLINE — and the first run may happen on its own.
A1. Install and reload. Watch the Console for about two minutes.
    EXPECT, because your kit is overdue right now:
      ☁️ Rebuild kit catch-up — the kit is 12 day(s) old — past the
         1-day window; running one now
    **That line IS the release.** Paste it.
A2. Console: `_G.backupReport()`. Find the new `catch-up:` line.
    EXPECT: `every 60 min · 1 started this session · the kit is 12
    day(s) old — past the 1-day window`, and a `↳ last catch-up` line
    under it with the time.
A3. The `last run:` line above it should now be TODAY, with its usual
    per-entry rows. That is the kit being fresh again.
A4. Reload once more and read the boot note. EXPECT it is GONE — the
    kit is a few minutes old. If it is still there, paste it.

B. THE NOTE NO LONGER HANDS YOU A CHORE.
B1. If you ever do see "☁️ The rebuild kit is N days old" again, read
    the rest of the line: it now says **"a catch-up run is due within
    60 min"** instead of giving you `_G.backupNow()`.
B2. 🚨 AND THAT MAKES IT WORTH READING: with the catch-up working,
    that note surviving means the catch-up ITSELF is failing. Before
    this release it just meant your Mac had been asleep at five. If
    you see it twice on different days, paste it — that is a fault now.

C. MUST STILL WORK — this touched the thing that copies your files.
C1. `_G.backupNow()` still runs one by hand, immediately.
C2. The 17:00 timer is unchanged — nothing about it moved.
C3. `_G.backupReport()` still lists every entry with its status, the
    app manifest count, and the crash-report lines.
C4. The half-hourly store mirror and the hourly notes mirror are
    untouched: check their lines still read `ok` with a recent time.
C5. Nothing in the backup folder is ever deleted. Still true — no
    rsync here carries `--delete`.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.backupReport()` after a day of normal use. Two lines matter:
    `catch-up:` and `last run:`. If `catch-up:` ever still reads
    **"not asked yet this session"** an hour after boot, the timer is
    not firing and I want to know — that is the one state this
    release exists to make impossible.
D2. From the WORK MAC too, when you next install there. A work laptop
    is shut at 5 PM far more often than a home one, so that is where
    this should show the biggest difference.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. **A backup can now start at any hour of your day**, not only at
    five. It is an incremental copy running outside Hammerspoon, so
    after the first one it should be unnoticeable — but if you ever
    feel the Mac get busy and find a catch-up in the report at that
    moment, tell me. `settings = { daily_backup = { catchUpDays = 0 } }`
    puts it back to 5 PM only, and `catchUpMins` changes how often it
    asks.
E2. One day is the threshold — the kit has to be more than a day old
    before a catch-up runs, which restores the daily rhythm rather
    than adding a second one. Too eager? Too slack? It is a number.
E3. 🔨 CRUDE OR ELEGANT: nothing was broken and nothing was lost —
    the kit was simply stale, and you would have found out the day you
    needed it. My reading is that this is a defect in a SCHEDULE
    rather than a feature ask, because the config was promising a
    daily backup it was not delivering. Your tag.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
