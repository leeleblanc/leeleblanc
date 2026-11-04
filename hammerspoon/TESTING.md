# TESTING — how to score release 6.403.0

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

## 6.403.0

6.403.0 verify with LL — 🔬 A STORM NOW SAYS WHY (KNOWN GROUND)
🚨 FIRST, AND BEFORE ANYTHING ELSE: **YOUR CONFIG MAY STILL BE PAUSED.**
Your 05:15:24 line ends "2 storms in 10 min: PAUSED, ⇪⇧escape resumes",
and nothing after it in your Console says you resumed. If ⇪ shortcuts
are doing nothing right now, that is why: press **⇪⇧Esc** (hold Caps
Lock and Shift, press the Escape key) and they all come back. A reload
clears it too.
WHAT HAPPENED, and it is not a false alarm: ⇪ really did latch, twice,
forty-five seconds apart. Caps Lock was not under your finger — that
Mac logged 88 autorepeats that session and NONE in the last two seconds
of either hold — so every key you pressed was running a ⇪ shortcut
instead of typing. The guard caught it both times, released it both
times, and wrote both files. That is the feature working.
WHAT CHANGED: those files said how OFTEN ⇪ had latched and never WHICH
of the three things that can latch it had happened. Now a storm asks,
at the moment it fires, and the answers go in its own file.

A. THE HEADLINE — nothing to press, and I hope you never see it.
A1. If ⇪ latches again you get the same alert, with one clause added:
    "· asking WHY — the answer lands in that file in a moment".
A2. Console: `_G.stormReport()`. **PASTE THE WHOLE THING.** At the END
    of the embedded file there is now a new section:
      ── why (measured at the storm) ──
      why    : measured AT this storm (the ⇪ storm guard, 05:15:26)
         remap : Caps Lock → F18 still set
         tap   : the F18 event tap is running
         secure: Secure Input clear
    **Those three lines are the whole release.** Each one that reads
    ⚠️ names a different cause with a different fix, and one of them is
    the answer we have been missing since 6.214.0.
A3. If `remap` ever reads **⚠️ GONE**, that is the answer AND it has
    already been put back — you will have seen a Console line saying
    so. That is the only one of the three with a repair.
A4. If `secure` reads **⚠️ Secure Input held by <app>**, that app took
    your whole keyboard, system-wide, and this config was never the
    cause. It is the one your diagnostic report has been unable to read
    for two releases, so it is the row with the least evidence either
    way.
A5. 🎹 AND READ THE `tap` ROW FIRST, which your own boot explains:
    "⇪ IS RUNNING WITHOUT CARBON on this Mac — the event-tap dispatcher
    has taken over all 111 ⇪ shortcuts". On a Mac where Carbon carries
    the keys, a tap switched off costs you some shortcuts. On YOURS the
    tap carries everything, so a tap that stops is a ⇪ that stops —
    including the keyUP that ends the hold. That makes `tap : ⚠️ the
    F18 event tap was NOT running` the most plausible of the three
    here, and it is a row nothing has ever been able to print at the
    moment of a storm.

B. THE HONEST STATE OF THAT THIRD ROW — worth thirty seconds now.
B1. Console: `_G.secureInputReport()`.
    Your ⇪⇧D report says `❔ Secure Input UNKNOWN — ioreg was asked and
    never answered in 20s`. That is 6.304.0's belt working (it gives up
    instead of wedging for the session) and the probe STILL not
    answering on your Mac.
    **PASTE IT.** If it carries `N × ioreg started and NEVER ANSWERED`,
    that is a real finding of its own and it is the next release there —
    a probe that cannot answer is the one row that could be hiding the
    cause of every latch.

C. MUST STILL WORK — this touched the guard that saved your keyboard
   twice, so this half matters more than A.
C1. Use ⇪ normally for a day: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space, ⇪V, ⇪/.
    EXPECT: no change of any kind, and NO storm alerts.
C2. Hold ⇪ down for ten seconds without pressing anything, then let go.
    EXPECT: the ordinary `released by the watchdog — held 8s` line. That
    warning must keep its teeth.
C3. Open the Jug Player (⇪⇧.) — the one-off "musicPlayer took the
    keyboard" line still appears, and it is still NOT a latch.
C4. `_G.hyperKeyReport()` — the probe block is unchanged in shape, and
    its three rows now come from the same renderer the storm file uses.
    If those two ever disagree, that is a real finding.
C5. `_G.stormReport()` on a Mac that has NOT stormed: it must read
    `why    : 0 probe(s) asked at a storm · 0 answer(s) appended`. A
    number there on a quiet day is a finding.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. 🚨 **AND THREE OF YOUR SHORTCUTS ARE TAKING A SECOND AND A HALF.**
    Your key trail: `⇪space app launcher 1571 ms ⚠️ slow`, twice, and
    `⇪⇧. jug player 1620 ms ⚠️ slow`, twice. That is 1.5 seconds of
    main-thread time per press — the thing that cost you drag and drop
    in 6.228.0 — and it is also what makes a run of six shortcuts last
    the five seconds the storm rule measures. I have NOT fixed it,
    because "⇪space is slow" names a KEY and not a cause, and the
    candidates (the 121,453-path search index, the app list, the
    window) have different fixes. Tell me whether ⇪space FEELS slow
    when you press it and that is the next release.
D2. 🔨 Was the Mac unusable while this was happening, or did it just not
    do the thing? By your own log every key you pressed ran a shortcut
    for fourteen seconds and then the config paused itself, which reads
    to me as unusable — but the tag is yours.
D3. 📏 NAMED, NOT FIXED, so it is not a surprise: this release does not
    stop ⇪ latching. It makes the next one name its own cause. The
    three candidates have been unmeasurable since 6.214.0 and this is
    the first build that reads them at the moment it matters.



## 6.402.0

6.402.0 verify with LL — 📋 ⏎ PASTES A CLIPBOARD ROW (KNOWN GROUND)
WHAT CHANGED: in ⇪V (and ⇪D), pressing Return on a clipboard row now
PASTES it where you were typing, instead of only copying it.
🔎 AND YOUR FIRST-ROW REPORT WAS THE WHOLE DIAGNOSIS. ⏎ has always
copied — and the FIRST row of the clipboard history is whatever is
already on your clipboard. So ⏎ there wrote back what was already
there, pasted nothing, and changed nothing you could see. Every other
row at least leaves ⌘V carrying something different afterwards; row one
does not. The one row you would try first is the only one that looks
completely dead.

A. THE HEADLINE — thirty seconds, and it is your own test.
A1. Click into a text box you can type in — this one, a Chrome field,
    a Word document. Leave the caret there.
A2. Press ⇪V. Press **Return on the FIRST row**, without moving.
    EXPECT: the panel closes, you are back in your text box, and the
    text appears at the caret.
    **A FAIL is nothing happening** — that is the old behaviour exactly.
A3. Do it again on the third or fourth row. Same thing.
A4. ⇪V, arrow down a few rows, Return. Same.

B. THE ONES THAT PROTECT YOU — these matter more than A.
B1. Press ⇪V and then press **Escape**.
    EXPECT: nothing is pasted anywhere, AND you are back in your text
    box (that part is new too — see 6.401.0's block).
B2. Open ⇪V from the Hammerspoon **Console** (click the Console first),
    then Return on a row.
    EXPECT: it does NOT paste. You get "📋 It is on your clipboard —
    ⌘V pastes it" and a reason. That is deliberate: there was no app to
    go back to, and a ⌘V with nowhere to land is a keystroke that goes
    into whatever happens to be in front.
B3. If you ever get that message when you DID come from a real app,
    paste `_G.unifiedSearchReport()` — the ⏎ clip line names which of
    four reasons it was.

C. MUST STILL WORK — this touched the panel every ⇪D search opens.
C1. ⇪D and search for something. ↑↓ walk, the preview pane follows.
C2. ⏎ on a **non-clipboard** row — an @ocr reading, an @shots path, a
    @vault note. EXPECT: it still only COPIES and says "📋 Copied".
    It must NOT type a file path into your document; that is the check
    that keeps this change narrow.
C3. ⌘⏎ on a row still copies its path; ⌥⏎ still opens it.
C4. ⇪O and ⇪⇧space still open the panel pinned to their own source.
C5. ⌘⌘ still opens the clipboard history.
C6. ⇪⇧V (the editing picker) is untouched — it still edits and deletes.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.unifiedSearchReport()` — the new ⏎ clip line:
      ⏎ clip : 4 picked · 4 ⌘V posted · 0 left on the clipboard only
    "left on the clipboard only" is NOT a failure — the text is on your
    clipboard either way — but if that number is climbing I want to
    know, because it means the focus is not coming back.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Should ⏎ paste for OTHER sources too? I deliberately limited it to
    the clipboard, because typing a file path or a shortcut's keys into
    whatever you were writing in is not what Return means there. If you
    want @ocr readings pasted as well, say so — that is a one-line
    change and it is your call.
E2. `settings = { unified_search = { pasteOnPick = false } }` puts the
    old copy-only behaviour back. Say the word and I change the default
    instead of leaving you a line to type.



## 6.401.0

6.401.0 verify with LL — 🎯 THE FOCUS COMES BACK (KNOWN GROUND)
WHAT CHANGED: when an edit window closes, you are put back in the app —
and the field — you were in. No trackpad.
🔑 AND YOU NAMED THE COMPARISON THAT EXPLAINS IT: "the cheat sheet
doesn't do this." It does not, because ⇪/ never takes the keyboard. A
window you TYPE INTO has no such option — macOS hands the keyboard only
to an active window, and making one of ours active activates
Hammerspoon. Two earlier releases paid that price and wrote it down;
neither gave the focus back afterwards.

A. THE HEADLINE — a minute, and do it from a real text box.
A1. Click into a text box and type a word, leaving the caret there.
A2. Press **⇪⇧W** to open the documents list. Pick a row and edit it.
    Change something and save (⌘⏎), or press Escape.
A3. EXPECT: you are back in your text box, with the caret in it. Type
    immediately — you should not have to click or touch the trackpad.
    **A FAIL is the caret not being there** — that is the bug.
A4. Do the same from ⇪⇧V (Return on a row opens the editor) and from
    ⇪⇧O. All three go through the same window, so all three should
    behave the same.

B. THE ONE THAT PROTECTS YOU — worth the thirty seconds.
B1. Open an edit window (⇪⇧V, Return on a row). Now, **before closing
    it**, click into a different app yourself — Chrome, Finder,
    anything.
B2. Go back and close the edit window (Escape).
    EXPECT: you stay where YOU put yourself. It must NOT drag you back
    to the app you originally came from.
    That is deliberate: by then you have moved on, and the focus is not
    ours to move. If it yanks you somewhere, tell me at once — that is
    worse than the bug this fixes.

C. MUST STILL WORK.
C1. The edit window still comes to the front with the caret already in
    it, as it has since 6.397.0 — the new half is only what happens
    when it CLOSES.
C2. It still drags by its ⠿ grip (6.395.0).
C3. Save, delete and cancel all still do what they did.
C4. ⇪/ the cheat sheet still opens without taking the keyboard at all —
    nothing about it changed, and it is the comparison you used.

D. PASTE BACK, PASS OR FAIL.
D1. Console: `_G.focusReport()` — NEW. On a healthy Mac:
      asked   : 3 borrow(s) · returned 3 · nothing to give back 0 · already held 0
      watching: yes · last app seen: Google Chrome
      refused : none — every app asked for came back
      holding : nothing — no panel owes the focus back
    **PASTE THAT.** Three lines are worth reading:
    · `watching:` — if it ever says ⚠️ NO, this Mac would not give us an
      application watcher and a window reached through a picker cannot
      give the focus back at all. That is a real finding.
    · `refused :` — an app that quit while you were editing.
    · `moved on:` — step B. NOT a fault, and the report says so.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. 📏 NAMED, NOT SWEPT, so it is not a surprise: this release gave the
    focus back from the EDIT WINDOW (and 6.402.0 adds ⇪D). Every other
    panel that takes the keyboard — Hamsidian, the task form, the
    screenshot editor, the Mug and Jug Players — still leaves it with
    Hammerspoon when it closes. Tell me which of those annoys you most
    and it takes the same door next; one per release, as always.
    Hamsidian is my guess, because you write in it.



## 6.400.0

6.400.0 verify with LL — 🧵 A DIVIDER IN THE CONSOLE (KNOWN GROUND)
WHAT CHANGED: there is now a line across the Console at the start and
the end of every session, so you can see where one boot's output stops
and the next one begins.
🔑 WHY THERE ARE TWO. Hammerspoon prints its own first two lines —
"Lazy extension loading enabled" and "Loading ~/.hammerspoon/init.lua"
— before any of my code exists, so nothing written during a boot can
ever get above them. But something written as the PREVIOUS session ends
can. So you get a closing line when you reload or quit, which lands
exactly where you asked for it, and an opening line for the boots that
have no closing line above them (a cold start, a force quit, a crash).

A. THE HEADLINE — ten seconds.
A1. Reload Hammerspoon (⌘⌃R, or the menu).
A2. Look at the Console.
    EXPECT, in this order: a blank line, then
      ═══════ ⏹ SESSION END · 6.402.0 · 2026-11-04 05:12:33 ══════════
    then Hammerspoon's own two lines, then a blank line and
      ═══════ ▶ BOOT · 6.402.0 · 2026-11-04 05:12:35 ════════════════
    and then the boot you already know.
    **A FAIL is no line at all.**
A3. Now do the thing you asked for it for: select from the ⏹ SESSION
    END line down to the bottom and copy it. That is one whole session,
    cleanly bounded.
A4. Reload once more and check you get BOTH lines again, with the right
    version and the right time.

B. THE CASE WITH ONLY ONE LINE.
B1. Quit Hammerspoon properly (⌘Q) and start it again.
    EXPECT: a ⏹ SESSION END line from the old session, then a ▶ BOOT.
B2. If Hammerspoon is ever force-quit, killed by the stall guard, or
    crashes, there is no SESSION END — just the ▶ BOOT. That is the
    point of having both, and it also tells you something: a boot with
    no SESSION END above it means the last session did not end cleanly.

C. MUST STILL WORK — this touched the file every key passes through,
   and the shutdown path that gives Caps Lock back.
C1. 🚨 THE IMPORTANT ONE: reload, then press ⇪ and use a few shortcuts —
    ⇪T, ⇪D, ⇪N, ⇪X, ⇪4, ⇪space.
    EXPECT: all normal. The closing line shares the shutdown path with
    the code that stops Caps Lock sending F18 to nothing after
    Hammerspoon goes away, so if Caps Lock ever behaves oddly after a
    quit, that is this release and I want to know immediately.
C2. Quit Hammerspoon and then type. EXPECT: Caps Lock types capitals
    again, normally. That is the restore still running.
    If it does not: `hidutil property --set '{"UserKeyMapping":[]}'` in
    Terminal fixes it, and tell me.
C3. The boot line still reads All green, 77 modules, and the same ⇪
    shortcut count as before.
C4. ⇪⇧D still prints the diagnostic report; `_G.saved()` still prints.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Is the line the right WIDTH? It is 72 characters so it does not wrap
    in a normal Console window. If it wraps on your screen, or if it is
    too short to stand out, it is a number and not a release.
D2. Should it carry anything else — the Mac's name, the boot time? It
    has the version and the clock now, which is what I would want for
    pasting, but you are the one pasting it.
D3. `_G.consoleRules = false` silences both lines for a session.


---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
