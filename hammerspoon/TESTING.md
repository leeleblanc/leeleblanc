# TESTING — how to score release 6.399.0

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



## 6.398.0

6.398.0 verify with LL — 📝 A CLOSED TAB LEAVES ITS NOTE (KNOWN GROUND)
WHAT CHANGED: when you ⌘W a Hamsidian tab, the .md file it wrote stays
— and it now SAYS so, with the way to remove it.
🗳 YOU ASKED "How do I know?" and you were right to: the decision was
mine to make and I had left it silent. It stays, and the reason is not
the obvious one. ⌘W is the key you press to clear your screen. If it
deleted the note, that key would be destructive — and a key you have to
think before pressing is a key you stop pressing. A tab is a surface; a
note is a document.

A. THE HEADLINE — thirty seconds.
A1. ⇪N, ⌘T for a new tab, type two lines with a Return between them,
    wait three seconds for it to write itself.
A2. Press ⌘W to close that tab.
    EXPECT: a short message saying the note stayed, naming it, and
    telling you the ✕ on its row in ⇪3 removes it.
    **A FAIL is silence** — that is the old behaviour, and it is what
    made a correct default feel like a leak.
A3. Press ⇪3. EXPECT: that note in the list, with a 🕸 icon.
A4. Click its ✕. EXPECT: it goes to the bin, recoverable
    (`_G.vaultTrash()` lists it, and a click in the 🗑 bin restores it).

B. PASTE BACK.
B1. `_G.scratchPadReport()` — a new count of how many notes have been
    left behind this way. That number turns "how many am I
    accumulating?" into something you can read rather than guess.

C. A JUDGEMENT ONLY YOU CAN MAKE.
C1. Now that you can see it happening: is leaving the note right? If
    you would rather ⌘W took the note with it, say so — but know that
    it makes ⌘W a destructive key, which is the reason I chose the
    other way.



## 6.397.0

6.397.0 verify with LL — ✏️ THE DOCUMENT EDIT WINDOW (KNOWN GROUND)
WHAT CHANGED: editing a document's recorded time now opens the same
window the clipboard editor uses — front, big, with the caret already
in it, and draggable.
🔎 Your words, with the two side by side: "Make the edit window like the
edit window for clipboard entries." This was the LAST thing in the
config still using macOS's little one-line dialog, which opens behind
whatever is in front of it.

A. THE HEADLINE.
A1. ⇪⇧W to open the documents list. Pick a row and choose to edit it.
    EXPECT: a dark window comes to the FRONT, as big as the text, with
    the caret already blinking in the box. Type at once — no click.
A2. EXPECT a line above the box naming the date, the app and how long.
A3. Drag it by its ⠿ grip (that is 6.395.0, below — try it here too).
A4. Save. EXPECT the change lands. Then edit again and press Esc:
    EXPECT nothing changes.
A5. Empty the box completely and save. EXPECT whatever it did before —
    the rule that decides what an empty box means is written once and
    both doors ask it, so the window and the old dialog cannot disagree.

B. THE DEGRADE.
B1. On a Mac where the window cannot be built you get the old one-line
    dialog instead, and it still works. You should not see it; if you
    DO, that is a finding and I want to know.



## 6.396.0

6.396.0 verify with LL — 🗳 YOUR WORDS FOR A RISKY ROW (KNOWN GROUND)
WHAT CHANGED: App Removal says exactly what you asked it to say.
🗳 You answered 6.388.0's question with the words: "⚠️ Attention: your
data may be in here ⚠️". That is what every risky row reads now.

A. THE HEADLINE — twenty seconds.
A1. Press **⇪⇧[** — hold Caps Lock and Shift and press the **[** key,
    just right of P. Pick an app and press Return.
A2. Find a row with a ⚠️ on it.
    EXPECT its second line to read **⚠️ Attention: your data may be in
    here ⚠️** — your words, verbatim. **A FAIL is the old "careful".**
A3. Console: the same wording in the printed analysis.
A4. ⇪/ and search `app removal` — the card says it too. One table, three
    surfaces, so they cannot drift.

B. MUST STILL WORK — the wording changed and the LOGIC must not have.
B1. Risky rows still start **[ keep ]**; safe rows still start
    **[ MOVE ]**. ⏎ on a row still toggles it. The three bulk rows
    still work, and ⏎ on the top row still moves only what is selected.
B2. It still refuses an app that is OPEN, and still never touches
    anything outside your home folder or /Applications.
B3. Everything still goes to the **Trash** and Finder ▸ Put Back undoes
    it.

C. A JUDGEMENT ONLY YOU CAN MAKE.
C1. Read it a few times in the picker. Too long for the row? Too
    shouty? It is one table and one line to change — and it is pinned
    by a check now, so a later release cannot quietly reword a thing
    you were asked about and answered.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
