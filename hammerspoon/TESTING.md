# TESTING — how to score release 6.378.0

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

## 6.378.0

6.378.0 verify with LL — 🔒 THE KEYBOARD LOCK THAT NEVER SPOKE
(KNOWN GROUND)
WHAT CHANGED: if macOS's Secure Input is already on when Hammerspoon
starts, you are told. It used to be told to nobody, for ever.
🔎 WHY IT MATTERS MORE THAN ITS SIZE: Secure Input is a password
field's lock, and while it is held NOTHING in this config works —
every snippet, autocorrect, and most ⇪ shortcuts, with no error
anywhere. In 6.196.0 Chrome left it on and took your keyboard for
four hours while the Console said "All green · 104 ⇪ shortcuts". The
announcement only fired on a CHANGE, and the first reading is not a
change — so a Mac that BOOTED into that state said nothing at all.

A. THE HEADLINE — and the happy path is silence.
A1. Reload. Wait a minute. Console: `_G.secureInputReport()`.
    EXPECT `state  : off — nothing is holding the keyboard`, and NO
    new line in the Console about Secure Input. That silence is the
    release working on a healthy Mac.
A2. To see the other half, click into a password field (1Password's
    unlock, a login page) and leave it there. Then reload
    Hammerspoon.
    EXPECT, within a minute: `🔒 SECURE INPUT IS ON — <app> has
    locked the keyboard …  (ALREADY held when this config started —
    it did not just happen)`.
    **That parenthesis is the whole release.** On every build before
    this one you would have got nothing.
A3. `_G.secureInputReport()` while it is held.
    EXPECT a `when   : ALREADY HELD when this config started` line
    under the state. Leave the field and the next probe says
    "🔓 Secure Input released".

B. MUST STILL WORK.
B1. Make it change WHILE running: with Hammerspoon up and quiet,
    click into a password field.
    EXPECT the same 🔒 line but WITHOUT the "ALREADY held" wording —
    that one really did just happen.
B2. `probes :` must show a `change(s) seen` count that goes up for
    B1 and NOT for A2. A boot into a held keyboard is not a change.
B3. Normal use for a day: no new Console noise, no alerts.

C. PASTE BACK.
C1. `_G.secureInputReport()` from an ordinary morning, and again if
    you ever meet A2 by accident. If a ⇪ key ever goes dead for no
    reason, that command is now the first thing to run.



## 6.377.0

6.377.0 verify with LL — ⌨️ WHAT HAPPENS WHEN YOU PICK A SNIPPET
(KNOWN GROUND)
WHAT CHANGED: nothing about what ⏎ does. What changed is that you can
now see what it did.
🔎 AND YOUR SENTENCE IS ALREADY TRUE — "when I select a snippet 99% of
the time I want it to instantly paste". It does, and it has since the
picker was built: a short snippet is TYPED straight at the caret, and
anything with a newline in it is put on the clipboard, ⌘V'd, and your
clipboard put straight back (a synthetic Return in a Teams or Asana
box SENDS the message, which is why multi-line is never typed). What
was missing is any way to tell that from "it did nothing": not one of
nineteen hundred snippets counted an insert.

A. THE HEADLINE — two minutes.
A1. ⇪⇧S, pick a short snippet (an email address, an emoji).
    EXPECT it appears at your caret, instantly, as always.
A2. ⇪⇧S, pick a MULTI-LINE one (the out-of-office, a signature).
    EXPECT it appears, and your clipboard is back to what it was a
    second later — ⌘V somewhere and check.
A3. Console: `_G.snippetsReport()`. Two new lines:
      ⏎ pick: 2 — 1 typed at the caret · 1 pasted (⌘V, clipboard put
              back) · 0 REFUSED
      typed : 7 — 7 typed at the caret · 0 pasted · 0 REFUSED
    PASTE THOSE. The first number is the answer to your sentence, and
    it is the first time it has been askable.
A4. The `↳ last in :` line names the most recent one and HOW it went.

B. THE HALF THAT PROTECTS YOU.
B1. If a pick ever inserts NOTHING, you now get an alert naming the
    snippet and macOS's own reason — it used to go to the Console and
    nowhere else. Paste it if you ever see it; the report keeps the
    last one on a `↳ ⚠️ last REFUSED` line.
B2. Type a trigger normally for a day. EXPECT no change at all, and
    the `typed :` count climbing while `⏎ pick:` does not.

C. A JUDGEMENT ONLY YOU CAN MAKE.
C1. If a pick ever feels like it goes nowhere — into the picker
    instead of your document — say so with the report. That is the
    one failure I cannot see from here, and the counts are what would
    prove it.



## 6.376.0

6.376.0 verify with LL — 📅 A SCRATCH NOTE IS NAMED FOR TODAY
(KNOWN GROUND)
WHAT CHANGED: a new Hamsidian tab is called by the day you made it
instead of "Scratch 1".
🔎 Your ask: "Scratch not should be prefixed with Today's date." And
"Scratch 1" is the name 6.165.1 gave an empty tab, on your own
complaint then — "Untitled ×2 told me nothing". A number tells you
nothing either.

A. THE HEADLINE — twenty seconds.
A1. ⇪N, then ⌘T for a new tab.
    EXPECT the tab reads **Mon Oct 20** (today), not "Scratch 2".
A2. ⌘T again. EXPECT **Mon Oct 20 · 3** — the date plus its place, so
    two empty tabs made today can still be told apart.
A3. Type a line in one. EXPECT the title becomes YOUR LINE, as it
    always has. That is the pad's whole design and it is unchanged.
A4. Close and reopen ⇪N. EXPECT the dates survive.

B. THE OTHER READING, IF I CHOSE WRONG.
B1. I read your sentence as "the DEFAULT name", because putting the
    same six characters in front of every typed row is noise rather
    than a journal. If you meant every title:
    `settings = { scratch_pad = { titleDate = "always" } }` → every
    tab reads "Mon Oct 20 · Buy milk".
    **Say which and I will change the default rather than leave you a
    line to type.**
B2. `titleDate = "off"` is the old "Scratch N" exactly.

C. PASTE BACK.
C1. `_G.scratchPadReport()` — a new `📅 dates:` line says which
    reading is on and counts any tabs that carry no date stamp (those
    keep their old name rather than claiming a date nobody recorded).



## 6.375.0

6.375.0 verify with LL — 🎓 AN OBSCURE FILE TYPE HAS TO EARN ITS PLACE
(KNOWN GROUND)
WHAT CHANGED: a file type joins ⇪I only once you have opened TWO
different files of it. One open is no longer enough.
🔎 Your ask: catch the common types down to the least common, "but
files types like .nfo or .edm shouldn't" turn up. And the cost was not
only clutter: the learned list keeps 24 types and evicts the OLDEST,
so a handful of one-off opens could push out .key, .sql or .sketch —
the types you really work in — quietly.

A. THE HEADLINE.
A1. Console: `_G.recentDocsReport()`. Two lines to read:
      learned : (unlearn with _G.recentDocs.unlearn("ext"))
      waiting : N type(s) opened in fewer than 2 file(s) — join one
                with _G.recentDocs.learn("ext")
    PASTE BOTH. The `waiting :` list is the one-off types being held
    back, by name, with their counts — so .nfo and .edm should be
    sitting there rather than in the list above.
A2. Press ⇪⇧I to re-scan, then run it again.
A3. If a type you DO work in is being held back (you keep one file of
    it), `_G.recentDocs.learn("ipynb")` joins it by hand, for good.

B. WHAT IS STILL THERE, so it is not a surprise.
B1. A single .nfo you opened still shows as a ROW in ⇪I, because
    macOS says you opened it and the nine-shelf has to stay honest.
    What is gone is the TYPE — its own section, its @tag, its place in
    the learned list.
    **Tell me if you want the row gone too.** That is a bigger change
    and I did not guess it.
B2. `settings = { recent_docs = { learnFloor = 1 } }` is the old rule
    exactly, if two feels wrong.



## 6.374.0

6.374.0 verify with LL — 📁 ⇪I STOPS SHOWING YOUR APPS' OWN FILES
(KNOWN GROUND)
WHAT CHANGED: Recent Documents no longer lists the files your apps
keep for themselves.
🔎 AND YOUR LIST OF THIRTY-FOUR APPS IS WHAT NAMED IT. 1Password,
Activity Monitor, App Store, Audio MIDI, Calculator, Chess, ColorSync,
Digital Color Meter, Disk Utility, DisplayLink, … System Settings,
Tips, TV, … Weather — **every single one keeps a folder under
~/Library**, and not one of the five you said you WOULD work in does.
Word, Chrome, Sublime, Script Editor and Shortcuts keep their
documents in Documents, Desktop, Downloads and OneDrive. So the fix is
a folder, not a list of names you would have to maintain for ever.

A. THE HEADLINE.
A1. Press ⇪⇧I to force a fresh scan, then ⇪I.
    EXPECT: no rows from 1Password, Notes, Weather, NordVPN, Ice or
    anything else on your list. **A row from any of them is a FAIL** —
    tell me which.
A2. 🚨 AND THE CHECK THAT MATTERS MORE: your real documents must all
    still be there — the Vault, the screenshots, anything in OneDrive.
    OneDrive lives INSIDE ~/Library
    (~/Library/CloudStorage/OneDrive-Personal), so skipping ~/Library
    without naming it back would have emptied the list of everything
    you actually work on. Search ⇪I for a note name and a screenshot
    name. **If your OneDrive files are missing, stop and tell me at
    once** — that is the one bad outcome this release can have.
A3. Open something in Word, then ⇪I. It is at the top, as ever.

B. PASTE BACK.
B1. `_G.recentDocsReport()` — a new `folders :` line says how many
    hits it turned away and why ("an app's own folder under
    ~/Library"), with the line under it naming the cloud exception. On
    your Mac I expect that number to be large.
B2. The `entries :` line — compare it to what you remember. It should
    be SMALLER and every row should be something you would call a
    document.

C. THE OTHER HALF, free.
C1. ⇪I's scan used to take the first 400 hits BEFORE filtering, so on
    a Mac whose ~/Library churns a lot your real documents could never
    be reached at all. The filter runs first now. If ⇪I feels like it
    has MORE of your work in it rather than less, that is this.



## 6.373.0

6.373.0 verify with LL — ⌨️ TWO KEYSTROKES INSTEAD OF THREE
(KNOWN GROUND)
WHAT CHANGED: the mouse grid's cells are labelled with TWO letters,
not three. Your YES.
🔎 THE ARITHMETIC, which nobody had written down: cells = letters ^
label length. Nine home-row keys three deep is 729 cells. Twenty-six
letters two deep is 676 — **within 4% of the same cell size**, so the
boxes stay the size you have already accepted, for a third of the
typing removed.

A. THE HEADLINE.
A1. ⇪X. EXPECT each cell shows TWO letters, and the boxes look about
    the same size as before.
A2. Type the two letters. EXPECT the pointer lands, as always.
A3. Read the letters. They are now the WHOLE alphabet rather than the
    home row — that is the cost, and it is two reaches instead of
    three taps. **Tell me if it feels worse in the hand**; it is one
    line either way.
A4. The two-letter split after landing, the arrows (8 pt a repeat,
    no acceleration since 6.360.0), ⌫, ⎋ and space are unchanged.

B. PASTE BACK.
B1. `_G.mouseGridReport()` — the `cells   :` line gives the real cell
    size on the screen you are on. I have been reasoning about that
    number from arithmetic; I would like it from your display.



## 6.372.0

6.372.0 verify with LL — 🎯 THE RINGS, BIGGER AND VISIBLE
(KNOWN GROUND)
WHAT CHANGED: ⇪⇧L's rings are bigger AND they change colour, because
"more colorful" turned out to be a defect rather than a preference.
🔎 THE MEASUREMENT: the ring shipped WHITE. On a white background —
a Finder window, a Word document, a browser page — that is **1.00:1
contrast. Literally invisible**, on most of what is on your screen at
the moment you have lost the pointer.

A. THE HEADLINE.
A1. Put a white Finder window or a Word document in front. Press ⇪⇧L.
    EXPECT: you can see it. Three rings, each a different colour,
    stepping outward.
A2. Do it over a DARK window too. EXPECT: still visible — the three
    colours cycle so one of them stands out whatever is underneath.
A3. The rings are 180 pt now rather than 150, and each is 10% wider
    than the last (your number, 6.310.0).

B. A JUDGEMENT ONLY YOU CAN MAKE.
B1. Magenta, orange and violet are my choice, picked by contrast
    arithmetic rather than taste (3.06:1, 6.86:1 on black, 4.22:1 on
    white). If you want different colours, say so —
    `settings = { mouse_grid = { locateColors = {...} } }`, or just
    name them and I will change the default.
B2. Still not obvious enough? `locateRadius` and `locateSecs` are
    numbers, not releases.



## 6.371.0

6.371.0 verify with LL — 📅 A TWO-DIGIT YEAR IS WRITTEN OUT
(KNOWN GROUND)
WHAT CHANGED: typing `10-20-26 ` gives you `10-20-2026 `. Your ask,
both separators.

A. THE HEADLINE — ten seconds, in Chrome or Word.
A1. Type `10-20-26` and then a SPACE.
    EXPECT: `10-20-2026 `.
A2. Type `10/20/26` and a space. EXPECT: `10/20/2026 `.
A3. Type `10-20-2026` and a space. EXPECT: unchanged — a four-digit
    year is already right.
A4. Type `13-45-26` and a space. EXPECT: unchanged. There is no month
    13 and no day 45, so it is not a date.
A5. Type `10-20/26` and a space. EXPECT: unchanged — mismatched
    separators are a typo, not a date.

B. MUST STILL WORK — this touched the tap that watches your typing.
B1. Type normally for a while. No missed characters, no stray
    corrections.
B2. `teh ` still becomes `the `. `somethingg ` still becomes
    `something`.
B3. ⇪Z still undoes a correction and refuses it for good.
B4. In Terminal, Ghostty or Sublime: nothing is corrected, as before.

C. PASTE BACK.
C1. `_G.autocorrectReport()` — a new `dates :` line counts them.
C2. 📏 KNOWN: a date typed mid-word is not corrected, and the buffer
    is capped at 12 characters.



## 6.370.0

6.370.0 verify with LL — 🎬 ⌃⌘F, THE FADING CHROME, AND RESUMING
(NEW GROUND for the full-screen half)
WHAT CHANGED: all three of your Mug Player asks.
🚨 AND ⌃⌘F IS DIFFERENT NOW: in 6.358.0 it filled the WINDOW. You
said "⌃⌘F is to make the FILM full screen", so it asks the FILM to go
full screen and only falls back to filling the window when macOS
refuses — which it can, and the report says which happened.

A. THE HEADLINE.
A1. ⇪⇧, and play a film. Press **⌃⌘F**.
    EXPECT: the FILM fills the whole screen — no window edges, no
    deck, nothing but the picture.
A2. Press **Escape**. EXPECT: out of full screen, window still up.
    Press Escape again to close the window.
A3. Press ⌃⌘F again and read what the window says if it could NOT go
    full screen. EXPECT either real full screen, or the window filled
    with a line saying macOS refused. Both are a pass; tell me which.

B. THE CHROME FADES.
B1. In full screen (or filled), EXPECT the header and the film deck
    to fade out of sight. Move the mouse: they come back.

C. IT REMEMBERS WHERE YOU WERE — the one you asked for by name.
C1. Play a film, let it run two minutes, press ⇪⇧, to close.
C2. ⇪⇧, again and press ⏎ on the same film.
    EXPECT: it resumes at about two minutes, not at zero.
    **A FAIL is starting from the beginning** — that is the bug.
C3. Let a film play to the END, then play it again.
    EXPECT: it starts from the beginning. A finished film has no
    place to resume to.

D. PASTE BACK.
D1. `_G.mugReport()` — new `cinema :` and `resume :` lines. If
    `resume` ever says the Mac would not say how long the film is,
    paste it: nothing is moved in that case, deliberately.



## 6.369.0

6.369.0 verify with LL — 🔤 THE ✕ YOU COULD NOT SEE (KNOWN GROUND)
WHAT CHANGED: the ✕ that removes a row in Hamsidian is visible.
🔎 AND IT WAS THERE ALL ALONG, since 6.364.0 — which is the same thing
as absent, and that is my fault rather than yours. It drew at 0.28 and
0.30 opacity over that sidebar: **2.30:1 and 2.44:1 contrast, against
the 3:1 floor a control is supposed to meet.** Measured, not argued.

A. THE HEADLINE — ten seconds.
A1. ⇪N. Look at the right-hand end of a HISTORY row (a closed tab).
    EXPECT: a ✕ you can see WITHOUT hovering.
A2. Hover it. EXPECT: brighter. Move onto it: red.
A3. Click it. EXPECT: the row is forgotten and nothing reopens.
A4. ⇪3, look at a note row's ✕. Same.

B. A JUDGEMENT ONLY YOU CAN MAKE.
B1. Too loud now? It is 0.55, which measures 4.5:1 — one number:
    `settings = { ui_style = { controlAlpha = 0.45 } }`. Say so and I
    will move the default.
B2. 📏 NAMED: this fixed the two places you reported. Every other
    panel in this config still draws its own dim controls at whatever
    number it typed in. If anything else has a control you have to
    hunt for, tell me where and it gets the same arithmetic.



## 6.368.0

6.368.0 verify with LL — ☁️ ONEDRIVE IS WATCHED (NEW GROUND)
WHAT CHANGED: this config now notices when OneDrive takes a file's
bytes back off your Mac, and names the files.
🔬 AND YOUR OWN PROBE DECIDED THE DESIGN. `_G.oneDriveProbe()` came
back with **(none)** on both kinds of file: a local file carries
`com.apple.macl` and `com.apple.provenance`, a placeholder carries
`com.apple.FinderInfo`, and there is NO File Provider attribute
anywhere. So "Always keep on device" is NOT readable from here — that
question is answered and closed. What IS readable is how much of a
file is actually allocated, so this watches and compares.

A. THE HEADLINE.
A1. Console: `_G.oneDriveSweep()`.
    EXPECT the folders it walked, the counts, and — the line you asked
    for — **☁️ NOT HERE**, naming every offloaded file, biggest first.
A2. Wait a day or two of normal use and run it again.
    EXPECT: if OneDrive has taken anything back since the first
    sweep, it is named as **TAKEN BACK since <when>** rather than
    just listed. That difference is the whole release: "it was never
    here" and "it was here this morning" are opposite facts.
A3. Reload Hammerspoon and run it again.
    EXPECT: the comparison still works. The record of what was local
    is written to disk, so a reload does not blind it.

B. IT MUST NOT COST YOU ANYTHING.
B1. It never READS a file — reading a placeholder downloads it, and a
    download on the main thread is the 72-second freeze from
    2026-10-12. The sweep runs out of process.
B2. Use the Mac normally while a sweep runs. EXPECT: nothing
    noticeable. If the Mac ever stutters at the moment a sweep runs,
    tell me and the interval is a number.

C. PASTE BACK.
C1. `_G.oneDriveSweep()` after a few days — the ☁️ NOT HERE list and
    the TAKEN BACK list.
C2. If it says it stopped at a bound, every number is a floor rather
    than a total; say so when you paste it.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Should it bring files BACK by itself? I have not built that on
    purpose: downloading is a READ, and a read is the thing that
    froze your Mac. Doing it safely means one file at a time, outside
    Hammerspoon. Say the word and it is its own release.
D2. Which folders should it watch? Right now the Vault, the Logs
    folder and the OneDrive root. Name any others.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
