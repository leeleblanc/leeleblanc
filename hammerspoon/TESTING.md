# TESTING — how to score release 6.439.0

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

## 6.439.0

6.439.0 verify with LL — 🪪 THE WORK MAC, THE KEYBOARD PROBE AND THE
SLOW TIMER — this block covers 6.435.0, 6.436.0, 6.437.0, 6.438.0 AND
6.439.0: they shipped in one archive, in five different files, and
share one test plan.
📏 FILED UNDER THE NEWEST ON PURPOSE: tools/build-test-plan.lua reads
one version per heading, so a batch goes under its newest and names
the others in its own section headings.
🔑 FIVE RELEASES IN FIVE PLACES, so a break still names its version by
which thing fails: no profile line or no scan is 6.435.0 (init.lua +
a new module) · Secure Input still UNKNOWN is 6.436.0 (capabilities) ·
⇪Q or the Mac feeling slower is 6.437.0 (focus_mode) · the grid
looking wrong is 6.438.0 (mouse_grid) · ⇪⇧' finding no tabs is
6.439.0 (tab_search).

── 1. 🪪 THE WORK MAC (6.435.0) ─────────────────────────────
1a. ON THE AIR, reload and read the 🧭 block.
    EXPECT: exactly what you see today, and NOTHING new about profiles.
    **An ℹ️ or ⚠️ profile line on the Air is a FAIL** — it would mean
    its own profile stopped matching.
1b. ON THE WORK MACBOOK, install and reload.
    EXPECT: **no profile line at all.** It has a profile now
    (MLC409N-153212), so the "No profile for …" line should be gone.
    If it still appears, PASTE IT — the name in the quotes is what
    that Mac really calls itself and the key needs to match it.
1c. Console, on EITHER Mac: `_G.workmacbookScan()`.
    EXPECT a block in seven parts: 🪪 this Mac · 🔑 permissions ·
    🧰 binaries · 📁 folders · ✂️ snippets · 🧩 modules ·
    📋 what to run next.
    **PASTE THE WHOLE THING FROM THE WORK MAC.** That is the release
    — it is the first build on which one command describes a Mac I
    cannot see.
1d. Read the `profile :` line. EXPECT "matched by name".
    "⚠️ DEFAULT — N keys match this name" would mean two profile keys
    collide; "ℹ️ DEFAULT" means the name still does not match.
1e. Read the 🧰 binaries block.
    EXPECT ✅ for osascript, ioreg, screencapture, sqlite3, rsync, find,
    mdfind, hidutil and the rest; ⚠️ for blueutil, brew, zbarimg and wn
    unless you have installed them. **Every ⚠️ names every path it
    looked in** — that is the line that makes one installable.
    RETURN: which are missing on the work Mac. Each is one feature
    that degrades and says so, and that list is what I cannot guess.
1f. 🚨 Look for a 🚨 NO CLOUD FOLDER line. On the work Mac this is
    the one that matters most: it means Hamsidian is reading a LOCAL
    folder and will honestly say "no notes yet" about the wrong place.
    PASTE IT IF YOU SEE IT.

── 2. 🔒 SECURE INPUT, AT LAST (6.436.0) ─────────────────────
2a. Reload, wait a minute, then Console: `_G.secureInputReport()`.
    EXPECT `state  : off — nothing is holding the keyboard`.
    **A FAIL is `state : UNKNOWN` again** — which is what it has said
    on your Mac since 6.196.0, in every report you have ever sent.
2b. **PASTE THE `legs   :` BLOCK.** Four rows, cheapest first:
          ✅ root         12 ms  ·      180 bytes  · exit 0
          ✅ resources    14 ms  ·      240 bytes  · exit 0
          ✅ keyed        95 ms  ·      310 bytes  · exit 0
          ⏳ full         did not run
    That block is the whole release. The old chain's second leg was a
    dump of your entire IO registry — megabytes through a pipe, every
    sixty seconds — and it is why this has never answered.
2c. Read the BYTES on the `keyed` row. A few hundred proves the narrow
    flag works on your macOS and the `full` leg can be deleted next
    release. Megabytes, or a non-zero exit with words after it, proves
    it does not. **Neither is guessable from here.**
2d. If any row reads ⏳ "did not run" AND there is a timeout line
    above, that row NAMES the leg that hung. Paste it.
2e. Console: `_G.hyperKeyReport()`. EXPECT its `secure:` row to read a
    real answer instead of "capabilities.lua has not answered yet" —
    the line your 2026-11-13 storm file carries at the one moment it
    mattered.

── 3. ⏱ THE SLOW TIMER (6.437.0) ─────────────────────────
3a. Use the Mac normally for a few hours.
3b. Console: `_G.lagReport()`. Find the focus_mode row.
    EXPECT the "slow" count to be a small fraction of the fires. On
    6.434.0 it was **242 slow out of 260**, 13 ms each, every four
    seconds, on the thread your keyboard waits on.
    **PASTE THAT ROW.** It is the measurement, and it is yours.
3c. Console: `_G.focusReport()`. Two new lines:
          app list      : 4 full sweep(s) · 892 tick(s) from the cache
             ↳ yield: 892 of 896 tick(s) (99%) skipped the enumeration
    EXPECT the yield to be high. If `full sweep` climbs in step with
    `cached`, the cache is not holding and this release did nothing.
3d. 🚨 If it reads **⚠️ NO APP WATCHER**, paste it: macOS refused the
    watcher on that Mac, so a 60-second re-sweep is the only thing
    keeping the list current. Detection still works; a meeting app
    launched mid-session can take up to a minute to be seen.
3e. ⇪Q must still engage and disengage focus mode by hand.
3f. Join a Teams or Zoom meeting. EXPECT focus mode to engage as
    always. LEAVE it. EXPECT it to disengage within the watchdog
    window. **That is the behaviour this release must not have cost**,
    and it is the one thing only you can test.

── 4. ✒️ THE GRID LINES (6.438.0) ───────────────────────
4a. Press ⇪X. EXPECT the cell lines noticeably fainter and the yellow
    letters unchanged — the letters should now be the first thing you
    see. **A FAIL is lines as strong as before.**
4b. EXPECT you can still SEE where each cell ends. If the geometry has
    gone, that is the opposite failure and it is one line to move.
4c. Type the two letters; a/s/d/f refine; ⌫ steps back; ⎋ closes.
    All unchanged.

── 5. 🗂 THE TAB SCAN (6.439.0) ───────────────────────
5a. With Chrome open, press **⇪⇧'** — hold Caps Lock and Shift and
    press the apostrophe key, right of the semicolon.
    EXPECT your open tabs, searchable. **A FAIL is "No browser
    answered".**
5b. Console: `_G.tabReport()`. **PASTE IT.** One row per browser:
          Google Chrome            ✅ 143 tab(s)  · 2140 ms
          Safari                   ⏳ not running, so never named
    EXPECT the milliseconds. If Chrome takes more than six seconds,
    THAT is your bug and the number is the fix — it is one setting.
5c. If a row ever reads ⚠️, it now names the browser and what happened
    to it. It must NOT mention an Automation prompt: your screenshot
    shows every grant already on, and blaming one was the old
    message's whole defect.
5d. Press ⏎ on a tab. EXPECT it jumps to that tab.
5e. Press ⇪⇧' twice and compare the list order. EXPECT the SAME order
    both times. The browsers are asked in parallel now and answer in
    whatever order they finish, so if rows move between presses, ⌘1–⌘9
    would jump to the wrong tab — tell me at once.
5f. Quit every browser and press ⇪⇧'.
    EXPECT "no browser is running", NOT "none answered". Those are
    different facts and only the second is a fault.

── 6. MUST STILL WORK — this batch touched init.lua's boot, a core
──    file and three modules, so this half matters more than 1–5 ──
6a. Boot: All green, **80 modules** (was 79 — machine_scan is new),
    and the same ⇪ shortcut count as before. A different shortcut
    count is a finding: the new module binds no key at all.
6b. A spread of keys: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space, ⇪V, ⇪/,
    ⇪⇧S, ⇪I, ⇪⇧..
6c. `_G.installCheck()` — EXPECT 93 runtime files now, all matching.
6d. `_G.selfTest()` — every row still answers.
6e. ⇪/ and search `machine scan` — the 🪪 card is there, under CONFIG.
6f. Type normally for a while in Chrome and Word. No missed keys, no
    lag. If anything feels HEAVIER on this build, stop and tell me:
    6.437.0 changed a timer that runs every four seconds.

❓ QUESTIONS — ANSWERS WANTED, NOTHING TO RUN
Q1. **The `legs :` block from step 2b.** It decides whether the next
    release deletes the expensive leg or keeps it — and whether Secure
    Input can finally be ruled in or out as the thing latching ⇪.
Q2. **The focus_mode row from `_G.lagReport()` after a day** (3b).
    That is the before-and-after on the worst offender in the config.
Q3. **`_G.workmacbookScan()` from the work MacBook** (1c), and which
    binaries are missing there (1e).
Q4. **Does ⇪⇧' work now, and how many milliseconds does Chrome
    take?** (5b). If it is over six seconds the fix is a number.
Q5. **Are the grid lines right?** (4a–4b). Fainter is the ask;
    invisible is a different bug and it is one value either way.



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



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
