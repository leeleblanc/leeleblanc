# TESTING — how to score release 6.407.0

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

## 6.407.0

6.407.0 verify with LL — 📐 THE EDITOR'S WINDOW SIZE (KNOWN GROUND)
WHAT CHANGED: the screenshot editor's window has a ceiling that means
something on a big display, and when the ceiling and the tool rails
disagree the SCREEN wins.
📏 AND HALF OF WHAT YOU ASKED FOR WAS ALREADY THERE, said first. "Not
shrink down so much that the tools are not usable" was built in
6.270.0: the window's floor is the taller rail's height plus the
header, so nine stacked tools always fit. Nothing about that changed.
🔑 WHAT WAS MISSING is the other end. The window was capped at 85% of
the screen — fine on the Air, and on your LG at full points that is a
window over three thousand points wide. Moving 85 to your 80 alone
would have taken it from 3264 to 3072, which is not an answer. So
there are TWO ceilings now and the smaller wins: 80% of the screen
(your number), and never more than 1600 × 1100 points however big the
display is.

A. THE HEADLINE — a minute, and do it on BOTH screens if you can.
A1. Take a screenshot of something big — a whole window, or the whole
    screen (⇪⇧2 or ⇪⇧3). Then ⇪⇧1 to open the editor on it.
    EXPECT: a window you can see all of at once, comfortably inside
    the screen, with the picture scaled to fit it.
    **A FAIL is a window that runs off the screen, or one you have to
    move your head to read.**
A2. Do the same on the OTHER display. EXPECT: on the Air the window is
    about 80% of the screen; on the LG it is noticeably SMALLER than
    80% of that screen, because the absolute cap binds there. That
    difference is the release.
A3. Open the editor on a SMALL screenshot — a button, a dialog.
    EXPECT: the window does NOT shrink to the picture. All nine tools
    down the left rail are visible without scrolling, and the six on
    the right are too. That is 6.270.0's floor, unchanged.
A4. Console: `_G.screenshotEditorReport()`. **PASTE THE WHOLE THING.**
    Two lines are new:
      ceiling : 80% of the screen (1152 × 720 here), and never more
                than 1600 × 1100 points
      sized   : 1100 × 682 pt for a 800 × 600 shot — fitted to the
                picture × fitted to the picture
    That `sized` line names WHICH RULE decided, and it is the whole
    point: "it is growing too big" and "it shrank until the tools were
    unusable" are opposite complaints about one function, and a size
    on its own cannot say which bound produced it.

B. THE RULE THAT HAD NEVER BEEN DECIDED.
B1. If you ever work on a SHORT screen — a projector, a small external,
    a display mirrored down — the tool rails need more height than the
    whole screen has. EXPECT: the window fits the SCREEN and the rails
    SCROLL, rather than a window taller than the display whose buttons
    you cannot click.
B2. The report says so when it happens: the `sized` line reads
    "clamped to the screen — the rails will scroll". Paste it if you
    see it; it means that screen cannot hold the full toolbar and you
    scroll the rail instead.

C. MUST STILL WORK — this touched the function that opens the window.
C1. The nine drawing tools (B T A L O H C S M), ⌘Z, ⌘⏎ Save & copy,
    Esc. All unchanged.
C2. ⌘O load a shot — the canvas GROWS and the window follows. EXPECT:
    it still grows, and it still stops at the ceiling rather than
    walking off the screen.
C3. ⌘A add capture, ⌘D delayed, ⌘F full screen, ⌘V paste image.
C4. ⌘-drag the title strip to move the window; it still moves.
C5. Open the editor on a 4K screenshot. EXPECT: a window you can see
    all of, with the shot scaled down inside it — and every mark you
    draw still lands exactly where you put it.

D. A JUDGEMENT ONLY YOU CAN MAKE — and this is the real question.
D1. **1600 × 1100 is MY number and it is the one I most want you to
    overrule.** It is a guess at "big enough to work in, small enough
    to see at once", and there is no measurement for that — it is your
    eyes on your displays. If the editor now feels cramped on the LG,
    say a bigger number; if it is still too big, say a smaller one. It
    is `settings = { screenshot_editor = { maxW = 1900, maxH = 1200 } }`,
    and say the word and I will change the DEFAULT rather than leave
    you a line to type.
D2. And 80% — is that right, or did you mean 80% of the SHOT rather
    than of the screen? I read it as the screen, because "the window is
    growing too big" can only be measured against the display. If you
    meant the shot, that is a different one-line change.
D3. 🔨 Nothing was broken and nothing was lost — the window was the
    wrong size. My reading is that this is a shape ask rather than a
    defect, except for the floor-versus-ceiling case in B1, which
    could have put a window off your screen. Your tag.



## 6.406.0

6.406.0 verify with LL — 🪟 THE WHITE BOX (KNOWN GROUND)
WHAT CHANGED: Hamsidian can no longer open a window with nothing in it.
🔎 AND IT IS YOUR OWN REPORT, FOUND BY READING: "I had a white box that
was Hamsidian … then was left with that box." A white window is a
window with no PAGE in it, and there were two lines that could cause
one. The first: the code that writes the page threw away the one value
that says whether the page was written — so if building it failed, the
failure was swallowed, the window was shown anyway, and an empty
webview draws blank. Nothing in the Console, no alert, no record.
🚨 AND THE SECOND LINE EXPLAINS "LEFT WITH THAT BOX": the window handle
was recorded BEFORE the window was really on screen. ⇪3's first line is
"if the window is open, close it" — so the next press closed a window
there was nothing to close, and the box stayed.

A. THE HEADLINE — and on a healthy Mac this release is INVISIBLE,
   which is the point. So this is "go and look", not "wait for it".
A1. Press ⇪3. EXPECT: Hamsidian opens with your notes, exactly as
    always. Press ⇪3 again: it closes.
A2. Do that five or six times in a row, briskly.
    EXPECT: it opens every time and closes every time. **A FAIL is a
    press that does nothing** — and if you get one, that is the thing
    this release is about and I want step D1 immediately.
A3. Press ⇪N, then ⇪3, then ⇪N again. EXPECT: the same window, the
    tabs and the notes sides, as before.
A4. The route you reported: press **⇪⇧U**, pick a note row with ⏎.
    EXPECT: Hamsidian comes up ON that note, with its text in it.
    NOT a blank white window.

B. THE INSTRUMENT — this is what I need from you.
B1. With Hamsidian OPEN, Console: `_G.vaultReport()`.
    EXPECT a new line:
      page   : up · the page is running · 3 draw(s)
    **PASTE IT.** Three other things that line can say, and each is a
    different fact:
    · `⚠️ THE WINDOW IS UP WITH NO DOCUMENT IN IT — that is a blank
      white box` — the window has nothing in it. This should now be
      impossible, because such a window is never shown.
    · `⚠️ the window is up and its page has NOT said it is ready` —
      the document is there and the page did not run. That is the
      other half of a white box, and it is the one I most want to see
      if it happens.
    · `closed · the page drew N time(s) while it was open` — you ran
      the report after closing the window. That is NOT a fault, and
      the line says so rather than reading like a page that never ran.
B2. Close Hamsidian and run it again. EXPECT the `closed ·` wording.
    That distinction exists because you will run this report after
    shutting the window, which is exactly how the last round cost us a
    release on the Mug Player.

C. MUST STILL WORK — this touched the one function that draws every
   screen in the tool that holds your writing. This half matters more
   than A.
C1. Type in a note, wait a second, close Hamsidian, reopen it.
    EXPECT: your words are there.
C2. 🚨 **⌘Z IN A NOTE** — open a note, delete a paragraph, wait ten
    seconds for a background scan to land, then ⌘Z. EXPECT: your text
    comes back. That is 6.323.0 and if undo is gone, tell me at once.
C3. ⌘N a new note · ⌘F the filter · ↑↓ and ⏎ · the ✕ delete · 🗑 the
    bin · ⌘⇧K tasks · ⌘⇧F search · ⌘G the graph · ⌘⇧B the board.
    Every one of those redraws the page, so every one of them is a
    path through the line that changed.
C4. ⌘⇧S export · 📌 pin · Esc.
C5. Drag the window somewhere, close it, reopen: it is where you left
    it.

D. IF IT EVER HAPPENS AGAIN.
D1. If you get a white box, or a ⇪3 press that does nothing, run
    `_G.vaultReport()` **with the box still on screen** and paste the
    whole thing. The `page` line now names which of the four states
    you are in, and the lines under it count pages that could not be
    written, blank windows caught before they were shown, and shows
    macOS refused. Before this release none of that existed.
D2. If a page ever fails to build you will now SEE it: an alert
    reading "🕸 Hamsidian could not draw its page — …", naming the
    reason, and you get the old one-line dialog instead so you can
    still reach the note. Paste that alert if you ever see it — it is
    the exact failure that was silent.
D3. 🔨 CRUDE OR ELEGANT: you were left with a window only a reload
    could clear, in the tool that holds your writing. My reading is
    that the Mac stayed usable and this one tool did not — but the tag
    is yours, and the honest pass count is 1.



## 6.405.0

6.405.0 verify with LL — 🔎 ⇪⇧U'S "PICK A NOTE" ROW (KNOWN GROUND)
WHAT CHANGED: ⇪⇧U's "📁 Link it into an existing note…" row no longer
tells you that you have no notes when you have twenty.
🔎 YOU WERE RIGHT, AND THE ANSWER TO "is this so obvious I'm missing
it" IS NO. Hamsidian builds its list of notes when you OPEN it — on
purpose, because reading that folder at boot is a tax every key pays.
So before your first ⇪3 of a session the list is EMPTY, and ⇪⇧U read
an empty list as "you have no notes" and said so. An empty list cannot
say which empty it is, and nothing anywhere could tell you.

A. THE HEADLINE — and it has to be done on a FRESH Hammerspoon, which
   is the whole case that failed.
A1. Reload Hammerspoon (⌘⌃R). Do NOT press ⇪3 — that is the step that
    used to hide the bug.
A2. Click into a Word document or a Chrome tab. Press **⇪⇧U**.
A3. Press ⌘2, or pick the row reading "📁 Link it into an existing
    note…".
    EXPECT: a short "🔗 Reading your notes…", and then a picker
    listing your notes.
    **A FAIL is "🔗 No notes to pick yet — make one with the first
    row"** — that is the bug, unchanged, and I want to know.
A4. Pick one. EXPECT: "🔗 Linked into <note>", Hamsidian opens on it,
    and the note has the link under `## Linked`.
A5. Now press ⇪⇧U and ⌘2 again. EXPECT: the picker, instantly — the
    list has been read by now and there is nothing to wait for.

B. THE ONE CASE THE OLD MESSAGE WAS RIGHT ABOUT.
B1. If Hamsidian genuinely has no notes, that row now says
    "🔗 Hamsidian has no notes yet — the first row makes one". Which
    is the same fact in better words, and it is the only state that
    sentence was ever true of.

C. PASTE BACK, PASS OR FAIL.
C1. Console: `_G.anchorsReport()`. Two new lines:
      index  : 412 note(s) the index knows · read — read
      pick   : 2 asked · 2 opened the picker · 1 waited for the index ·
               0 found Hamsidian genuinely empty
    **PASTE BOTH.** The `index` line is the artefact: run it right
    after a reload and it should read `0 note(s) … unread — no scan
    has completed yet`, and after a ⇪3 it should read a real count and
    `read`. Those two readings, a minute apart, are the whole release.
C2. If `pick` ever shows a ⚠️ line about giving up waiting, paste it —
    an index that never arrives is a fault rather than a cold start,
    and that line is the difference.
C3. `_G.vaultReport()` has a matching line:
      index  : 412 note(s) · read — read
    The two read the same renderer, so if they ever DISAGREE that is a
    real finding.

D. MUST STILL WORK.
D1. ⇪⇧U still names what is in front: a Word document by its file
    name, a Chrome tab by its page title, anything else by its app.
D2. The rows at the TOP are still the notes that already mention it,
    and ⏎ on one still opens that note. **That leg never used the
    index** — it is a grep over the folder — so it has always worked
    cold, and it must still.
D3. The first row still makes a note named after the thing and links
    it.
D4. ⇪3 and ⇪N open Hamsidian as before.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. The wait is about three seconds before it gives up and asks you to
    press the key again. Too short on a vault in OneDrive? Too long to
    sit there? It is a number, not a release.
E2. 🔨 Nothing was broken and nothing was lost — the tool told you
    something false about your own notes, on the one press where it
    mattered. The Mac was fine. Your tag.



## 6.404.0

6.404.0 verify with LL — 💾 THE DRAFT KEEPER (NEW GROUND — expect a round)
WHAT CHANGED: there is a new tool, and it has no key. While you type
into a text box in a BROWSER or in Outlook, this config keeps what the
box holds. If the page loses it, it is in ⇪D under **@draft**, and ⏎
copies it back to your clipboard.
🔑 IT READS THE FIELD, IT DOES NOT WATCH YOUR KEYBOARD, and that is
the whole design rather than a detail. The obvious build is a tap on
every keystroke; it would never see a PASTE, and after you move the
cursor and rewrite a sentence it would hold a transcript of your
typing rather than the paragraph on the screen. So it asks the field
what is in it — which also means it watches one box in seven named
apps instead of every key you press anywhere on the Mac.
🪟 AND IT IS NEW GROUND, SAID UP FRONT: nothing in this config has
ever read what is inside somebody else's text box. Whether Chrome and
Outlook will answer that question on YOUR Mac is a thing only your Mac
can say, so step A4 is the most useful line you can send back whether
it works or not.

A. THE HEADLINE — two minutes, and do it in Chrome.
A1. Click into a text box you can type a paragraph in — a Gmail or
    Outlook compose window, an Asana comment, a long web form.
A2. Type **at least two or three sentences** — more than sixty
    characters; a short line is deliberately NOT a draft, or the file
    would fill with every search box you ever typed in.
A3. Now STOP TYPING and wait about fifteen seconds. Then click into a
    different tab, or just click somewhere else on the page.
A4. Console: `_G.draftKeeperReport()`. **PASTE THE WHOLE THING.**
    EXPECT, and this is the release:
      kept   : 1 draft(s) this session · 1 row(s) written
               ↳ last: 212 character(s) from Google Chrome — the first
                 draft of this field
      rows   : 1 kept · newest first, 1 shown · ⇪D @draft searches them
        1. 2026-11-05 09:14:02 · Google Chrome · 212 chars
           The paragraph you just typed…
    **A FAIL is `kept : nothing yet this session`** with a `cost :`
    line showing reads. If that is what you get, the `refused:` and
    `skipped:` lines under it name which of five reasons, and that is
    exactly what I need — go to D1.
A5. You should also have seen ONE line in the Console the first time it
    kept anything: `💾 Draft keeper: kept a 212-character draft from
    Google Chrome`. It says that ONCE a session, deliberately — an
    alert every time you write an email is a tool you switch off.

B. THE DOOR — ⇪D, which is where you will actually use it.
B1. Press **⇪D** (hold Caps Lock, press D). Type a single **@**.
    EXPECT **16 sources** now, and **💾 @draft** among them, described
    as "the text a web form lost".
B2. ⏎ on that row. EXPECT your draft listed, newest first, with the
    app and the window underneath it.
B3. Highlight it and look at the pane on the right. EXPECT the WHOLE
    draft, not the one-line preview.
B4. Press **⏎**. EXPECT "📋 Copied", and ⌘V pastes the whole draft.
    **It must NOT type anything back into the page** — that is your own
    scope and it is the one thing here I would want to hear about
    immediately if it is wrong.
B5. Type `@draft` plus a word from your draft. EXPECT it filters.

C. THE CASE IT EXISTS FOR — the one worth doing on purpose.
C1. Type a long paragraph into a web form. Do NOT wait.
C2. Within a second or two, navigate the page away — hit Back, close
    the tab, or follow a link. The sort of thing that loses a draft.
C3. ⇪D, `@draft`. EXPECT your paragraph is there.
    WHY IT WORKS: the next time it looks and finds a DIFFERENT field,
    it writes whatever it was holding at once. A timer alone would
    have missed it.
C4. 📏 THE LIMIT, named rather than discovered: up to about ten
    seconds of your NEWEST typing is not on disk at any instant. If
    Hammerspoon reloads or the Mac crashes inside that window, those
    last few words are gone. Making that zero means a write per
    keystroke into OneDrive, which is what took your drag and drop in
    6.228.0.

D. 🔒 WHAT IT MUST REFUSE — please do D1 and D2 at least.
D1. Click into a PASSWORD field — a login page, 1Password's unlock.
    Type something. Wait twenty seconds. Click away.
D2. `_G.draftKeeperReport()`.
    EXPECT `refused: 1 password field(s) …`, and **NOTHING from that
    field anywhere in the rows list**.
    **A FAIL here is a password in that list.** Stop and tell me at
    once; `_G.draftForgetAll()` empties the file and
    `settings = { draft_keeper = { enabled = false } }` stops it.
D3. A field macOS will not describe is refused too, counted on its own
    line. "I cannot tell what this is" must never read as "safe to
    read", which is why it refuses rather than guessing.
D4. Press **⇪⇧Esc** to pause the config, type a paragraph in a browser,
    then ⇪⇧Esc again. EXPECT: nothing was kept while it was paused.
D5. Type a long paragraph in **Word**, or in Terminal, or in
    Hamsidian. EXPECT: nothing is kept. It watches browsers and
    Outlook and nothing else, by your own scope.

E. MUST STILL WORK — this added a watcher that reads the focused
   element, so this half matters more than A.
E1. 🚨 **DOES THE MAC FEEL NORMAL?** Use Chrome and Outlook heavily for
    an hour. Typing must not feel heavier, the pointer must not
    stutter, and drag and drop must still work. If ANY of that changes
    on this build, stop and tell me — that is the one cost I cannot
    measure from here, and it is the cost that has bitten you before.
E2. `_G.draftKeeperReport()` and read the `cost :` line:
      cost   : 412 sample(s) · 180 reached a read · worst 8 ms · last 3 ms
             ↳ yield: 60 read(s) for every draft kept
    **PASTE THAT.** `worst` is the number that matters. If it ever
    carries `⚠️ N read(s) over the 60 ms budget`, it has BACKED OFF by
    itself and you will have had one alert naming the app and the
    milliseconds — paste that too.
E3. ⇪D still searches everything: @clip, @ocr, @vault, @shots, @logs.
    ⏎ on a @clip row still PASTES (6.402.0); ⏎ on every other row
    still only copies.
E4. A spread of ⇪ keys across different tools: ⇪T, ⇪N, ⇪3, ⇪X, ⇪4,
    ⇪space, ⇪V, ⇪/, ⇪⇧[.
E5. Boot: All green, **78 modules** (was 77 — this release adds one),
    and the same ⇪ shortcut count as before. A different shortcut count
    is a finding: this module binds no key at all.
E6. `_G.installCheck()` — 93 runtime files now, not 92.

F. THE WAYS OUT, worth knowing before you need them.
F1. `_G.draftForget(n)` removes one row — n is the number from the
    report, 1 being the newest. `_G.draftForgetAll()` empties the file.
F2. The file is named in the report. It is in your **Logs folder**, by
    your own scope, which means it **SYNCS through OneDrive** — right
    for a draft you want back, and worth knowing, because it holds text
    you typed into other people's forms. `settings = { draft_keeper =
    { local_ = true } }` keeps it on this Mac only. Say the word and I
    will change the default instead of leaving you a line to type.
F3. Ninety days, your number. Pruned once a session; nothing else ever
    removes a row.

G. ❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN.
G1. **Sixty characters and ten seconds** are MY numbers, not yours. The
    6.213.x note asked whether it should keep every draft or only ones
    over some length after a pause, you escalated the feature without
    answering, and I will not leave that in a settings line for you to
    type. If the file fills with things you did not want kept, say so
    and sixty goes up; if a paragraph you lost was not kept, say so and
    ten seconds comes down.
G2. **Which apps?** Chrome, Chromium, Safari, Edge, Firefox, Brave,
    Arc, Vivaldi, Opera and Outlook. Name any others — Teams, Slack,
    Asana's desktop app — and they go in one line.
G3. **The floppy disc is NOT built**, and that is the half of your
    original drawing I did not ship. A disc beside the field has to
    follow that field as you type and as the page scrolls, which is
    work on the thread that carries your keyboard — the exact cost that
    took your drag and drop. If you want it anyway, the next release
    there is a MEASUREMENT of what drawing it costs, not the disc.
G4. 🔨 Nothing was broken and nothing was lost — this is a tool you
    asked for three times and never had. If it turns out to cost you
    anything on the Mac (E1), that is a different answer and I want it.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
