# TESTING — how to score release 6.402.0

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


## 6.399.0

6.399.0 verify with LL — 🩺 DID THE WHOLE RELEASE LAND? (KNOWN GROUND)
WHAT CHANGED: one new command. `_G.installCheck()` compares every file
this release carries against what is actually on your Mac, and says
which ones disagree.
🔎 WHY: your own question, from September — "so I don't have to
remember". When a release half-installs, the config boots green, the
version stamp is right, and the feature is simply ABSENT. That is what
cost you the Jug Player for three days: init.lua was new, the module
file was old, and nothing anywhere could say so. The archive now
carries a MANIFEST.txt listing every runtime file with its byte count,
and this reads it.
🔕 AND ON A HEALTHY MAC IT SAYS NOTHING, ever. That silence is the
feature, so step A is "go and look", not "wait for a message".

A. THE HEADLINE — one command, and it should be boring.
A1. Console: `_G.installCheck()`.
    EXPECT, on a clean install:
      🩺 INSTALL CHECK — 6.399.0
         version : 6.399.0 — the manifest is for this release
         files   : ✅ all 92 runtime file(s) are here at the size the
                   release carried
         strays  : none — core/ and modules/ hold only what shipped
    **PASTE THAT.** It is the first build on which that question has an
    answer, and I want to see what your Mac says on a good day.
A2. Read the `files` line. **A FAIL is a ⚠️ naming files that disagree**
    — which would mean this install is partial, and the line names
    which files and both byte counts.
A3. Read the `version` line. It must name 6.399.0 twice. If it says THE
    MANIFEST IS FOR <something else>, one half of the install did not
    land — that is the whole-archive version of the same bug.
A4. Reload Hammerspoon and watch the Console for a minute.
    EXPECT: **nothing at all** about the install check. On a matching
    install it never speaks. If you get a ⚠️ line at boot, paste it:
    that is the 🔔 door firing and it means something really did not
    land.

B. THE STATE THAT MATTERS MOST — "I cannot tell" is not "all clear".
B1. This one you can see on purpose. In Finder, open ~/.hammerspoon
    (Go ▸ Go to Folder, type `~/.hammerspoon`) and RENAME MANIFEST.txt
    to MANIFEST.old.
B2. Console: `_G.installCheck()`.
    EXPECT: `⏳ NOTHING CAN BE SAID`, and under it that this install
    predates the check and that this is **NOT** 'all clear'.
    **A FAIL is a ✅ anywhere in that block.** A check that cannot run
    must never read like a check that passed — that is the one thing
    this release had to get right, and it is the state every install
    you have today is in.
B3. Rename it back. `_G.installCheck()` is green again.

C. THE ONE A DRAG CAUSES — worth two minutes, because it is one click
   wide and you would never see it.
C1. In ~/.hammerspoon/modules, duplicate any file (⌘D in Finder). You
    get something like `music_player copy.lua`.
C2. Console: `_G.installCheck()`.
    EXPECT: a `strays` line naming it, and under it the explanation —
    the loader reads an explicit list, so a stray is IGNORED and the
    ORIGINAL stays loaded. That is why dragging a file onto a folder
    and answering Finder's "Keep Both" looks exactly like a finished
    install and changes nothing.
C3. Delete the duplicate. The line goes back to "none".

D. MUST STILL WORK — this release touched the installer and the module
   loader, so this half matters more than A.
D1. Boot: All green, **77 modules** (was 76 — this release adds one),
    and the same ⇪ shortcut count as before. A different shortcut count
    is a finding: this module binds no key at all.
D2. A spread of keys across different tools: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4,
    ⇪space, ⇪V, ⇪/, ⇪⇧[.
D3. ⇪/ and search `install` — the 🩺 card is there, filed under CONFIG.
D4. `_G.saved()` — the write ledger still prints. These two sit beside
    each other on purpose and answer different halves of "is what
    should be on disk, on disk?".

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. **Is the Console the right place?** It is a command you run when
    something feels absent. The alternative is a line at every boot
    saying "all 92 files are here", which is what `_G.saved()` does for
    the stores because you asked for the healthy case in writing — and
    I did NOT do it here, because a line you read every morning is a
    line you stop reading. Say if you would rather have it.
E2. 📏 THE LIMIT, named rather than discovered: this compares SIZES. A
    file edited to exactly the same length reads as a match. I did not
    build the hash version: it needs a platform fact I cannot check
    from here, and it guards a case that has never happened. If it ever
    does, the manifest gains a column.
E3. 📏 AND TWO FILES ARE DELIBERATELY NOT IN IT, both printed in the
    report so they are decisions rather than gaps: CHANGELOG.md, which
    already has a better instrument (it checks whether THIS version's
    entry is in it, which is what caught a half-install in 6.311.0),
    and snippets/bundled.lua, which is generated and which you can
    legitimately rebuild on your own Mac from packs the archive never
    saw. Say if you want either in anyway.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
