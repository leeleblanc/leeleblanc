# TESTING — how to score release 6.434.0

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

## 6.434.0

6.434.0 verify with LL — 🔧 THE FOUR YOU NAMED (KNOWN GROUND) — this
block covers 6.431.0, 6.432.0, 6.433.0 AND 6.434.0: they shipped in one
archive, in four different files, and share one test plan.
📏 FILED UNDER THE NEWEST ON PURPOSE: tools/build-test-plan.lua reads
one version per heading, so a batch goes under its newest and names the
others in its own section headings (6.423.0's note).
🔑 FOUR RELEASES IN FOUR FILES, so a break still names its version by
which thing fails: a truncated @report or a short @shots is 6.431.0
(unified_search) · Escape not closing a panel is 6.432.0 (hyper_key +
coexist + five panels) · no Hammerspoon in ⌥Tab is 6.433.0
(window_switcher) · none in ⇪M is 6.434.0 (menubar_items).

── 1. 📌 ALL THE REPORTS, LISTED (6.431.0) ─────────────────────────
1a. Press ⇪D and type `@report` — exactly that, no other word.
    EXPECT: every report, scrollable, and NO "…and 41 more — keep
    typing to narrow" at the bottom.
    **A FAIL is the "…and N more" line.** That is the bug.
1b. Read the line under the search box.
    EXPECT: **"97 in @report — every one of them, listed"**, not "101
    matches across every store". Those are different facts and only one
    of them is what you asked for.
    RETURN: that line. The number is the one thing I cannot see.
1c. Scroll to the bottom and count roughly. Then press ↑ from the top —
    the highlight walks the whole list.
1d. Press ⏎ on any row. EXPECT: it runs, and the answer is in the
    Console. ⌘⏎ copies the command instead.
1e. Now type `@report draft`. EXPECT: it NARROWS to the draft keeper's
    rows. The other words still filter inside a pinned store.
1f. Type `@o` (just those two characters).
    EXPECT: it still SEARCHES @ocr the way it always has — a prefix is
    not a pin. If `@o` ever starts listing one whole store, tell me.
1g. 🔎 FOUR NEW ROWS, which no name ending in "Report" could ever have
    found: `_G.begoneProbe()`, `_G.padProbe()`, `_G.oneDriveProbe()`
    and `_G.healthCheckNow()`. Search `@report probe` to see them.
    RETURN: anything else you expected to find in that list and did
    not — that is the one gap I cannot measure from here.

── 2. 📸 THE SCREENSHOTS (6.431.0) ─────────────────────────────────
2a. ⇪D, type `@shots`.
    EXPECT: hundreds of rows, not 33.
    **A FAIL is a number near 30.**
2b. Scroll down past the first two dozen.
    EXPECT: the rows keep going, and the ones further down have NO
    thumbnail. That is deliberate and it is the whole fix: a thumbnail
    is a full PNG decode on the main thread, and on a OneDrive-evicted
    file that means downloading it first — the thing that froze your
    Mac for 72 seconds on 2026-10-12. So the budget is on DECODES, not
    on rows. A row with no picture still has its name, its date, its
    size and its path, and ⏎ and ⌘⏎ work on it exactly the same.
2c. Console: `_G.unifiedSearchReport()` — there are two new lines:
      caps   : an exact @tag lists that whole store · a free-text
               search draws 60 rows at once
      📸 shots : 488 in the folder · 300 listed (cap 300) · 24
               thumbnail(s) decoded (budget 24)
    **PASTE THOSE.** The first number is your folder; if a line under
    them says N older captures are on disk and not in the box, that is
    honest rather than a fault — and it says so.
2d. 🚨 THE ONE THAT MATTERS MORE THAN THE COUNT: use ⇪D normally for a
    day. Opening it must not feel slower, and the Mac must not stutter
    when it opens. If it does, that is this release and I want to know
    at once — `maxPer.shots` is a number I can move.

── 3. ⎋ ESCAPE DROPS A PANEL YOU HAVE MOVED OFF (6.432.0) ──────────
3a. Press ⇪D. Now click into Chrome, or anywhere else, so the search
    panel is no longer the window you are typing in.
3b. Press **Escape**.
    EXPECT: the panel closes.
    **A FAIL is the panel staying up** — that is your report exactly.
3c. Do the same with ⇪V, ⇪space and ⇪Y.
3d. 🚨 THE COST, NAMED, so it is not a surprise: while one of our
    panels really is on screen, a bare Escape pressed in ANOTHER app
    now closes the panel instead of reaching that app. That is what you
    asked for. With NO panel of ours open, Escape belongs to your app
    exactly as before — check that: press Escape in Chrome with nothing
    of ours up and it must behave normally.
    If the trade is wrong, `settings` is not needed —
    `_G.escapeGlobal = false` in the Console puts 6.430.0 back for the
    session, and say so and I will change the default.
3e. Console: `_G.escapeReport()`.
    EXPECT the `unified` row to read **· idle** with nothing open.
    **The row you pasted last time read `unified 55 🟢 wants esc now`
    with no panel on screen** — that is the bug, and it was starving
    everything below it of Escape: the window switcher, both players,
    the calendar and the cheat sheet.
    EXPECT two new lines at the bottom:
      stuck   : none — the last claimant to handle an Esc stood down
      global  : on — a bare Escape is routed from the ⇪ tap in any app
    RETURN that block.
3f. If `stuck` ever names something, paste it: that is a panel whose
    handler ran and closed nothing, and it will be skipped on the next
    press so it cannot eat Escape everywhere.

── 4. 🪟 HAMMERSPOON IN ⌥TAB (6.433.0) ─────────────────────────────
4a. Open the Hammerspoon Console. Press **⌥Tab** on that desktop.
    EXPECT: a Hammerspoon card.
4b. Switch to another desktop and press ⌥Tab.
    EXPECT: it is still there, captioned "remembered".
4c. Console: `_G.switcherReport()`.
    EXPECT a new **`ours :`** line naming the windows it really saw —
    something like `1 window(s) answered: Hammerspoon Console`.
    **PASTE IT.** That line is the release: before it, five different
    facts printed the same "not seen yet this session", and one of them
    (allWindows() answering an EMPTY LIST on a Dock-less app) is the
    first suspect 6.152.0 named for exactly your symptom.
4d. If `ours :` says **EMPTY LIST**, that is the answer and it is a
    different fix — paste it and stop there.
4e. Open Hammerspoon's Preferences and press ⌥Tab.
    EXPECT: that window is a card too, under its own name. It never was
    before — only a window titled exactly "Hammerspoon Console" could
    be listed, which is a string Hammerspoon owns and we do not.

── 5. 🔎 HAMMERSPOON IN THE MENU-BAR PICKER (6.434.0) ───────────────
5a. Press **⇪M**.
    EXPECT: **Hammerspoon** in the list, with its own items under it —
    🩺 tool health, the mini calendar, and the pause indicator if the
    config is paused.
    **A FAIL is Hammerspoon still missing.**
5b. Press ⏎ on one. EXPECT: it opens, like anybody else's.
5c. EXPECT: Control Center, MenuBarAgent and the other Apple agents are
    still NOT in the list. This is a name taken out, not a filter
    switched off — if the list suddenly has twenty system rows in it,
    that is the opposite failure and I want to know.
5d. Console: `_G.menuBarReport()`.
    EXPECT Hammerspoon among the nine you pasted before.

── 6. MUST STILL WORK — this batch touched the ⇪ tap, the escape
──    router and five panels, so this half matters more than 1–5 ───
6a. A spread of keys: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space, ⇪V, ⇪/, ⇪⇧S.
6b. ⇪⇧Esc pauses the config and ⇪⇧Esc resumes it. ⌃⌥⌘⇧Esc still
    releases everything.
6c. Escape closes ⇪/ the cheat sheet, the mouse grid (⇪X), the music
    card (⇪⇧.), the Mug player (⇪⇧,) and the calendar (⇪⇧0) — one press
    each. Those are the panels that were being starved.
6d. ⇪N and ⇪3: type in a tab, Escape, reopen — your words are there.
    ⌘Z in a note still undoes.
6e. ⇪T: open the task form, press Escape, reopen — the draft is kept.
6f. ⇪I (recent documents) and ⇪⇧W: open, Escape, reopen.
6g. Type normally in Chrome and Word for a while. No missed keys, no
    lag. If typing ever feels heavier on this build, stop and tell me:
    this release added one branch to the tap that sees every keystroke.
6h. Boot: All green, 79 modules, 112 ⇪ shortcuts.
6i. `_G.installCheck()` — the manifest should match.

❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN
Q1. **Is the Escape trade right?** Step 3d. A bare Escape now closes an
    open panel of ours even when you are typing in another app. You
    asked for it; it is still a change to a key you use in every app,
    and it is one word to reverse.
Q2. **Is 300 the right number of screenshots in @shots?** You have 488.
    All of them is one line; the cost is that every ⇪D open walks the
    whole folder. Say "all of them" and it is 500.
Q3. **Which other reports should @report name?** Step 1g. It holds 97
    plus the four probes. Three that ACT are deliberately out.
Q4. **The work MacBook's name** — `scutil --get ComputerName`. Still
    the one thing that gives that Mac a profile of its own instead of
    the fallback.



## 6.430.0

6.430.0 verify with LL — 🔗 WHAT THE CLEANER LEFT (KNOWN GROUND)
WHAT CHANGED: ⇪K stops saying "Already clean" about a link it simply
did not recognise, and Credit Karma's tracking is now stripped.
📏 YOUR LINK, MEASURED: 851 characters, SEVEN parameters. `ctPayload`
decodes to an analytics beacon carrying an event code, the screen and
section you were on, a hash and a timestamp. The cleaner removed 0 of 7
— which was CORRECT, it only drops names it knows — and then called
that clean, which was not.

A. THE HEADLINE — ten seconds.
A1. Copy that Credit Karma link again and press **⇪K**.
    EXPECT: `https://www.creditkarma.com/u/cards/shop` and nothing else.
    851 characters down to 40. **A FAIL is "Already clean".**
A2. Press **⇪⇧K**. EXPECT: the original back, exactly.

B. THE HALF THAT WAS LYING — this is the real release.
B1. Copy any ordinary link with a parameter the cleaner does not know —
    `https://example.com/x?notificationId=abc&channel=email` will do.
B2. Press ⇪K. EXPECT: the link is UNCHANGED (correct — those names are
    load-bearing on other sites), and the alert now reads
    **"🔗 Nothing removed — 2 parameter(s) left, none recognised as
    tracking"**, NAMES them, and tells you `cleaner.dropForHost` is how
    to add a rule for that site.
    **A FAIL is "Already clean".**
B3. Copy a link with no parameters at all — `https://example.com/page`.
    EXPECT: **"🔗 Nothing to remove — no parameters on this link"**.
    Those two messages must differ. That difference IS the release.

C. IT MUST NOT BREAK OTHER SITES — more important than A.
C1. Copy a courier link: `https://www.ups.com/track?trackingId=1Z999AA1`.
    Press ⇪K. EXPECT: **UNTOUCHED.** `trackingId` is dropped on Credit
    Karma and nowhere else, because on a courier's page it is the whole
    point of the link.
C2. `https://app.example.com/i?notificationId=abc` — untouched.
C3. A lookalike: `https://notcreditkarma.com/x?channel=email` —
    untouched. The rule matches the apex and real subdomains only.

D. MUST STILL WORK.
D1. `https://news.com/a?utm_source=x&utm_medium=y&id=5` → keeps `id=5`,
    drops both utm_. ⇪⇧K undoes.
D2. An Outlook safelink unwraps to the real URL.
D3. A shortener (bit.ly, t.co) is NOT expanded, and says why —
    expanding it would register the click.
D4. ⇪K on a paragraph with several links cleans each and leaves the
    prose alone.

E. PASTE BACK.
E1. If you meet another link it calls "Nothing removed" that you think
    SHOULD be cleaned, paste the link. That is now a one-line host rule
    rather than a diagnosis — and the alert naming the parameters is
    what makes it a thirty-second fix.

❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN
Q1. **Which other senders do this to you?** Each is one line in
    `dropForHost` and I would rather add five than have you meet them
    one at a time. Banks, airlines, retailers — whoever fills your
    inbox.
Q2. **Is the new message the right length?** It names up to four
    parameters and then "…". Too chatty for something you press often?



## 6.429.0

6.429.0 verify with LL — 📐 BIGGER BOXES, TWO LETTERS (KNOWN GROUND)
WHAT CHANGED: the grid is back to TWO letters, the boxes are four times
the area they were, and nothing is divided before you type. The a/s/d/f
quartering you said is fine does the precision.
🚨 AND 6.428.0 WAS MINE. It shipped a three-letter label over 4,096
cells and divided every one of those 2 × 2 on top — which is 6.176.0
reproduced exactly, the build you called "insane. Way too small." Its
own comment four lines above that line said a two-character label was
the entire point and quoted your verdict back at me. The prose and the
code disagreed on adjacent lines and I read the prose.

A. THE HEADLINE — twenty seconds.
A1. Press **⇪X**. EXPECT: the codes are **two letters**, not three, and
    the boxes are noticeably bigger — about four times the area of what
    you photographed.
    **A FAIL is three-letter codes.**
A2. 🔎 THE ONE YOU REPORTED: can you SEE THROUGH the grid now? You
    should be able to read the window underneath between the labels.
    That is the whole release and it is the thing I cannot judge from
    here.
A3. Type the two letters. EXPECT: the pointer lands, one keystroke
    sooner than last week.
A4. The letters are still the Timer's yellow — you said that is right
    and nothing about the colour changed.

B. PRECISION IS STILL THERE, and this is the half that makes A safe.
B1. ⇪X, type two letters to land. EXPECT: the yellow box divided into
    four with a letter in each quarter.
B2. Press **a** (top-left), **s**, **d**, **f**. EXPECT: each keeps
    that quarter and divides again. Two presses puts you on a small
    button.
B3. Press **⌫**. EXPECT: it steps back up one.
B4. Keep going until it refuses. EXPECT: it SAYS why — there is a 16 pt
    floor, because a box below that is not something you can aim with.
B5. **COUNT THE KEYSTROKES** on something small — a Finder toolbar
    button. Two letters plus one or two quarters. **Return that number.**
    Last week it was three letters plus quarters for the same target.

C. THE PLATES — the dark patch behind each label.
C1. Look at one closely. EXPECT: it hugs the letters rather than
    filling the cell. It covers 41% of a cell, measured.
C2. 📏 IT IS THERE FOR A REASON AND I DID NOT TRADE IT AWAY: without it
    this yellow measures 1.00:1 over a white window — invisible. The
    obvious fix was to make the plate more transparent, and at 0.55 the
    contrast drops to 3.25:1, under the 4.5 the suite requires. So the
    occlusion came out of SIZE and CELL COUNT instead.
C3. If the plates still bother you: `settings = { mouse_grid =
    { labelBackplates = false } }` removes them entirely, and the
    letters sit on the dim wash alone. Say the word and I will change
    the default rather than leave you a line to type.

D. MUST STILL WORK — this is a full-screen overlay that eats keys, so
   this half matters more than A.
D1. ⇪X then ⎋, six times briskly. EXPECT: opens and closes every time.
    **An overlay left on screen with nothing closing it is the serious
    failure** — ⌃⌥⌘⇧X is the panic key and I want to know at once.
D2. ⇪X, land, then the **arrow keys**: 8 pt a press, 1 pt with ⇧ held,
    and a HELD arrow crawls steadily rather than taking off (6.360.0).
D3. ⇪⇧X — same grid, clicks the moment you finish typing.
D4. ⇪⇧L — the pointer rings. Separate tool, untouched.
D5. While the grid is up, ⌘Q and ⌘Tab still work.
D6. Both screens: the Air's panel and the LG.

E. PASTE BACK, PASS OR FAIL.
E1. Console: `_G.mouseGridReport()`. Three lines:
    · `cells :` — the REAL cell size in points. I have been reasoning
      about that number from arithmetic and want it from your display.
    · `layout:` — should say no pre-draw division.
    · `split :` — a s d f, four parts, and where the keys came from.
E2. If the grid ever DECLINES to open with a sentence about the labels
    being too small, paste it. That is the refusal working — the
    overlay stays off your screen rather than taking the keyboard
    behind letters you cannot read.

❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN
Q1. **Is 676 the right starting size, or do you want fewer still?**
    This is the density you scored "The grid is so much better" in
    6.360.0, with quartering added on top. Fewer letters makes the
    boxes bigger again and costs nothing in typing — `alphabet =
    "asdfghjklqwertyui"` is 289 cells, half as dense again. One line,
    and I would rather ship your answer than leave you the line.
Q2. **Do the plates need to go?** Step C. They buy readability over
    white windows and they are the only thing still drawn over your
    screen.
Q3. **The work MacBook's name** — `scutil --get ComputerName`, whenever
    you next have it. Still the one thing that gives that Mac a profile
    of its own instead of the fallback.



## 6.428.0

6.428.0 verify with LL — ✂️ FOUR BOXES WHERE THERE WAS ONE, IN THE
TIMER'S YELLOW (KNOWN GROUND for the grid; the install is new)
WHAT CHANGED: every grid cell is split into four, so the box you land
in is a quarter of the size it was — and the letters are the Timer
card's yellow instead of white.
📐 YOUR TWO SENTENCES WERE ONE NUMBER, which is why this is one
release. 26 letters squared is 676 cells, which is about 45 points on
the Air against a toolbar button of 28–40 — so the box really was
about twice the size of the thing you were aiming at. Quartering fixes
that WITHOUT making you type a fourth letter: 6.176.0 tried that and
your verdict was "HOLY SHIT! The grid is insane. Way too small."
🟡 AND THE YELLOW IS THE SAME FOUR NUMBERS THE TIMER FLASHES, read out
of one table rather than copied — so it cannot drift from it.

A. THE HEADLINE — a minute, and do A4 even if A1–A3 look right.
A1. Press **⇪X**. EXPECT: the grid, and the cells are visibly SMALLER
    than you are used to — four where there was one.
    **A FAIL is cells the same size as last week**, or a press that
    does nothing at all.
A2. Look at the letters. EXPECT: translucent YELLOW, the same colour
    the ⏱ card flashes when a timer ends, each on a small dark patch
    so it reads over a white window as well as a dark one.
    **A FAIL is white letters** — that is the old behaviour.
A3. Type the three letters of a cell. EXPECT: the pointer lands there,
    exactly as it always has. The code is the SAME LENGTH as before —
    if you are typing a fourth letter, tell me, because that is not
    what this release does.
A4. 🔎 Open something with small controls — a Finder toolbar, a
    dialog's buttons — and aim at one. EXPECT: the box you land in is
    close to the size of the button. That is the whole point of the
    release and it is the one thing I cannot see from here.

B. THE FOUR QUARTERS — this is the "again" half of your ask.
B1. ⇪X, type three letters to land. EXPECT: the yellow box is drawn
    divided into FOUR, with a letter in each quarter.
B2. Press **a** — top-left. EXPECT: that quarter is kept, the pointer
    goes to its middle, and it divides into four again.
    Then **s** is top-right, **d** is bottom-left, **f** is
    bottom-right. Two or three presses put you on a small button.
B3. Press **⌫** (Backspace). EXPECT: the box goes back UP one — the
    quarter you just took is undone.
B4. Keep refining until it refuses. EXPECT: it SAYS why rather than
    doing nothing — there is a 16-point floor, because a box smaller
    than that is not something you can aim with.
B5. Press **space**. EXPECT: it clicks where the pointer is.
B6. Press **⎋** (Escape). EXPECT: the grid goes away and the keyboard
    is yours.

C. MUST STILL WORK — this is a full-screen overlay that captures
   keys, so this half matters more than A and B.
C1. ⇪X then ⎋, five or six times briskly. EXPECT: it opens every time
    and closes every time. **If an overlay is ever left on screen with
    nothing closing it, that is the serious failure** — ⌃⌥⌘⇧X is the
    panic key (hold Control, Option, Command and Shift, press X) and
    I want to know at once.
C2. ⇪X, land, then nudge with the **arrow keys**. EXPECT: 8 points a
    press, 1 point with ⇧ held, and a HELD arrow crawls steadily
    rather than taking off (that is 6.360.0 and it must not have
    moved).
C3. ⇪⇧X — the same grid, but it clicks the moment you finish typing.
C4. ⇪⇧L — find the pointer. EXPECT: three coloured rings, unchanged.
    That is a separate tool and nothing here touched it.
C5. While the grid is up, press **⌘Q** or **⌘Tab**. EXPECT: they still
    work. Only the letters and a handful of control keys are claimed,
    deliberately — an overlay you cannot ⌘Q out of is the hazard.
C6. On BOTH screens if you can: the Air's panel and the LG. EXPECT: a
    readable grid on each.

D. THE INSTALL ITSELF — new in this archive, so worth two minutes.
D1. Unpack it and run, in Terminal:
        sh ~/Downloads/<the folder you unpacked>/tools/hs-install.sh \
           ~/Downloads/<that same folder> --dry-run
    EXPECT a line reading **6.427.0  →  6.428.0**.
    **A FAIL is a version that reads like a sentence** — something
    beginning "-- 📏 `_G.configVersion` is assigned HERE". That is the
    bug this release fixes: the installer was reading a COMMENT where
    the version goes, which also meant its own final check compared
    that comment with itself and could never fail. If you see it,
    this archive is not the one I built.
D2. Then the real thing, without `--dry-run`. EXPECT it to back your
    current config up first, copy, verify, and tell you to reload.
D3. Reload Hammerspoon. EXPECT the boot line to read 6.428.0, All
    green, 79 modules.
D4. Console: `_G.installCheck()`. EXPECT every runtime file present at
    the size this release carries.

E. PASTE BACK, PASS OR FAIL.
E1. Console: `_G.mouseGridReport()` — the whole block. Three lines are
    the ones I want:
    · `cells :` — the REAL cell size in points on the screen you are
      on. I have been reasoning about that number from arithmetic and
      I would rather have it from your display.
    · `split :` — it should name **a s d f**, four parts, and say
      where the keys came from.
    · `labels:` — the four numbers of the yellow, which should be the
      same ones `_G.timerReport()` shows for the flash.
E2. If the grid ever DECLINES to open with a sentence about the labels
    being too small to read, paste it. That is the new refusal working
    — the overlay stays off the screen rather than capturing your
    keyboard behind letters you cannot read — and the number in it
    tells me whether the floor is set right for your eyes.

❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN
Q1. **Is a quarter the right size, or should it go further?** This
    divides each cell 2 × 2. If the box is still bigger than the
    buttons you aim at, one line makes it 3 × 3 (nine per cell) — but
    that is a third of the label size again, so I want your eyes on
    it before I spend them. "right" · "smaller" · "too small now".
Q2. **Are a/s/d/f the right four keys?** They are the home row's left
    hand, in reading order. You had two letters for the half-split in
    6.252.0 and this replaces that habit, so say if it fights your
    fingers — and `refineParts = 2` puts the old two-way split back
    if you would rather have it.
Q3. **Is the yellow readable on YOUR screens?** It is the Timer's
    exact accent at its own alpha, on a dark backplate. White was
    measured at 1.00:1 on a white window — invisible — but I cannot
    see your displays, and if the yellow is now the thing that is
    hard to read, that is a number I will move rather than argue.
Q4. **The work MacBook's name** — `scutil --get ComputerName`. Still
    owed from 6.418.0, and it is the one thing that gives that Mac a
    profile of its own instead of the fallback.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
