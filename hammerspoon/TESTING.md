# TESTING — how to score release 6.300.0

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

## 6.300.0

6.300.0 verify with LL — 🗂 THE GRAMMAR SENDS (NEW GROUND — expect a round)
WHAT CHANGED: Hamsidian sends your grammar now. Every task it reads
becomes its own Asana task, and the tab is retitled with your labels.
🏷 YOUR ANSWER WAS BETTER THAN ALL THREE OF MINE. I asked where the
cleared text should go and you answered by not clearing it. Nothing is
deleted — the tab keeps every word and wears the outcome.

🚨 DO THE PREVIEW FIRST. This is new ground and it writes to Asana:
`_G.scratchPadTasks()` still shows exactly what a send would create,
and it now also shows what it did to each `T:` line. Read it once
before step A2.

A. THE HEADLINE.
A1. ⇪N, a new tab, and type your own example:
      Create the Asana task maker in Hamsidian
      =
      P: Generate a new init.lua feature
      A: me
      D: We need to structure a new Hammerspoon feature.
      T: today +1w 7:00 AM 4:00 PM
A2. Console: `_G.scratchPadTasks()`. EXPECT two tasks, as before.
A3. Press "→ Asana now" in the window (or `_G.scratchPadSend()`).
    EXPECT: TWO separate tasks in Asana, in your usual project — not
    one task with both lines in its description.
A4. Look at the tab list. EXPECT: that tab is now called
    **✅ Success: tasks sent**, and its text is untouched inside.
A5. Press "→ Asana now" again.
    EXPECT: NOTHING is sent and nothing is announced. A ✅ tab is
    never sent twice — that is what stops 16:00 posting today's tasks
    again tomorrow.
A6. Click into that tab and type a character.
    EXPECT: the ✅ disappears and the title goes back to your first
    line. New text is new work. Send again and it goes.

B. THE DATES — the part I had to make a decision about.
B1. New tab: `Buy milk` then `T: today`.
B2. `_G.scratchPadTasks()`. EXPECT: `📅 start — · due <today>` and,
    under it, `↳ one date given — sent as the DUE date`.
    WHY: Asana refuses a start date with no end date outright, so
    `T: today` would have failed. A single date means "by then"
    everywhere else, so that is what I made it mean. Your two-date
    lines are untouched.
B3. Send it. EXPECT: a task due today, no start date, no error.
B4. Tell me if that is wrong. It is a decision, not a rule, and you
    are the only one who can say whether "T: today" means due today or
    starts today.

C. WHEN IT FAILS — please do at least C1.
C1. Put a nonsense assignee in a task: `A: notarealperson`.
C2. Send. EXPECT: the tab is retitled **❌ Error: tasks not sent**, the
    text is all still there, and you get an on-screen ⚠️ naming what
    Asana said.
C3. Fix the name and send again. EXPECT: the ❌ tab IS retried and
    turns ✅. That is the only reason to mark a failure.
C4. A tab with two tasks where only ONE fails is marked ❌, not ✅. If
    you ever see a ✅ over a task that did not arrive, stop and tell
    me — that is the worst failure this release can have.

D. MUST STILL WORK.
D1. ⇪N and ⇪3 open as before; your tabs and notes are untouched.
D2. ⌘T, ⌘W, ⌘1–9, the history pane, 📌, ⌘⇧S export — unchanged.
D3. ⇪T still creates a single task from the form.
D4. `_G.scratchPadReport()` — new `send :`, `marks :` and `run :`
    lines. PASTE THE WHOLE THING after a day.

E. THE TWO THINGS I CHANGED THAT YOU SHOULD AGREE WITH.
E1. 🗓 **16:00 IS BACK ON.** You switched it off in 6.254.0 ("I don't
    need to send these at 4pm") and this message switched it back on
    ("tasks send at 4pm whether Hamsidian is open or not"). It is your
    call either way, but I am naming it rather than letting you find
    out at four o'clock. `settings = { scratch_pad = { sendDaily =
    false } }` — or just say so and I will change the default.
E2. 📏 **A TAB YOU CLOSED TODAY IS NO LONGER SENT.** The old day task
    swept them; a closed tab has no title to put a ✅ or ❌ on, so
    sending it would be sending into silence. The report counts them
    and says so. If you want them back in, that is a decision and I
    will build it — say how you would want to be told what happened
    to one.

F. A JUDGEMENT ONLY YOU CAN MAKE.
F1. Every sent tab reads exactly "✅ Success: tasks sent", so five of
    them look identical in the list. That is literally what you asked
    for and it is right for a done-pile you are going to delete — but
    say if you would rather it read "✅ Sent · <your first line>" so
    you can tell them apart.
F2. `S:` subtasks are still read and still not sent — Asana needs the
    parent task's id back first, which is a second call. That is
    6.301.0, and it is the next thing I build unless you say otherwise.



## 6.299.0

6.299.0 verify with LL — 🔔 A SEND THAT FAILS IS FINALLY SEEN (KNOWN GROUND)
WHAT CHANGED: Hamsidian now says "sent" when ASANA says yes, not when
the request leaves this Mac.
WHY IT MATTERS: 6.278.0 was built from your own question — "how do I
know if it didn't work? I could lose important information if not" —
and it had a hole in it I did not see until I went to build the send
you asked for. `asanaSubmitTask` hands back "true" the instant it fires
the request; Asana's yes or no arrives a second later, in a callback
that told nobody. So a task Asana REFUSED showed you "✅ Hamsidian →
Asana" and cleared the warning flag, while a separate "❌ Error: 400"
flashed beside it from the other half of the config. Both were true
sentences about different moments.
🚨 NOTHING YOU PRESS CHANGES. This is a correctness release and the
next one is the send you actually asked for.

A. THE HEADLINE — it still works on a good day.
A1. ⇪N, type something into a tab, then Console: `_G.scratchPadSend()`.
    EXPECT: the task appears in Asana, and you get "✅ Hamsidian →
    Asana: Hamsidian · <date>" — a moment LATER than it used to,
    because it now waits for Asana to say yes.
A2. Console: `_G.asanaSubmitReport()` — NEW.
    EXPECT: `answers: 1 accepted by Asana · 0 refused or never sent`,
    and a `last : ✅ …` line with the time.
A3. `_G.scratchPadReport()` — its last-send line should say "sent",
    not "posted — waiting on Asana". If it is stuck on waiting, Asana
    never answered and I want that block.

B. THE ONE THAT PROVES THE FIX — make Asana refuse one.
B1. ⇪T, and put a nonsense name in the Assignee field that is not on
    your team — or any field Asana will reject. Create it.
B2. EXPECT: "❌ Error: <code>" as before.
B3. Console: `_G.asanaSubmitReport()`.
    EXPECT: `0 accepted · 1 refused`, and a `last : ❌ … — Asana
    refused it (HTTP 4xx) — <Asana's own words>` line. Those words are
    new: Asana's reason used to reach the Console and nothing else.
B4. If you can make the 4 PM send itself fail, that is the real test:
    EXPECT an on-screen ⚠️ naming Asana's reason, a notification, and
    `_G.scratchPadReport()` carrying a ⚠️ NOT SENT line — and NO "✅"
    anywhere. Before this release that case showed you a ✅.

C. MUST STILL WORK — this touched the one path every Asana task takes.
C1. ⇪T creates a task: title, description, assignee, priority, SAC
    Values, dates and times, an attachment. All unchanged.
C2. ⇪A (the pipe chooser) still creates a task.
C3. The ⇪N button "→ Asana now" still sends.
C4. A task you create still gets its automatic comment.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.asanaSubmitReport()` after a day of normal use. If it ever
    carries a `⚠️ N never answered in 30 s` line, that is a new fact —
    Asana going silent on your network — and I want it.
D2. `_G.scratchPadReport()`.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Thirty seconds is how long it waits for Asana before telling you it
    heard nothing. Too long to sit wondering, or too short on a slow
    network? It is a number, not a release.
E2. ANSWERING YOUR OTHER QUESTION, because it belongs here: the id in
    the URL you sent — 745948257030523 — is your PROJECT gid, and this
    config already posts every task to it (it is in init.lua as
    `asanaProjectId`, alongside workspace 182448385076670). A SUBTASK's
    "parent" is a different thing: it is the gid of the TASK the
    subtask hangs under, and that number does not exist until the
    parent task has been created. This release is what makes it
    reachable — the submit now hands that gid back — and 6.301.0 is
    what uses it.



## 6.298.0

6.298.0 verify with LL — 🔎 THE @ SEARCHES NAME THEMSELVES (KNOWN GROUND)
WHAT CHANGED: type @ on its own in ⇪D and every source you can search is
listed — its tag, what it holds, and how many.
WHY IT MATTERS: you were right that nothing named them. There are
fourteen, and the only place any of them appeared was a section header
in the results — which you can only read after searching for something
that happens to be in that store. A tag you have to know before you can
find it is not a tag you can use, which is why fourteen of them have
been sitting there unused.

A. THE HEADLINE.
A1. Press ⇪D. Type a single `@` and nothing else.
    EXPECT: the list becomes a directory — 🔎 THE @ SEARCHES — 14, and
    one row per source reading e.g. `📋 @clip` with "Clipboard ·
    everything you have copied" under it and a number on the right.
A2. Read the fourteen. EXPECT: @clip @cmd @shots @note @asana @ocr
    @images @doc @file @pad @scratch @vault @web @tool.
A3. Press ↓ a few times, then ⏎.
    EXPECT: that source's tag lands in the box as `@ocr ` (or whichever)
    and the results below become that store. It must NOT copy anything.
A4. Press ⇪D again, type `@`, and CLICK a row.
    EXPECT: the same — the tag goes in the box.
A5. With the directory up, look at the right-hand pane.
    EXPECT: it says what the highlighted source holds and how many items
    are indexed right now.

B. THE ONE THAT MUST NOT HAVE REGRESSED — please do this one.
B1. Type `@ocr` (with the r). EXPECT: OCR rows, exactly as before. The
    directory must NOT appear. It is `@` alone, never any @word — `@o`
    already searched @ocr and that had to keep working.
B2. Type `@shots`, `@vault`, `@clip`. EXPECT: each pins its store as
    always.
B3. Type an ordinary word — `receipt`. EXPECT: unchanged.
B4. ⇪⇧space and ⇪⇧/ still open pinned to @shots and @tool.

C. THE SECOND DOOR.
C1. Type `@tasks` — a tag that does not exist.
    EXPECT: "Nothing matches … and there is no @tasks source. Type @ on
    its own to see all 14."
C2. Type `zzznothing`. EXPECT: the plain "⌫ widens it again" message —
    it must not start talking about @ for an ordinary miss.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.unifiedSearchReport()` — the store list and its counts.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Read the fourteen one-line descriptions. Any of them wrong, or
    describing something other than what you thought that tag searched?
    That is the answer I most want — they are my words for your stores,
    and a wrong one is worse than none.
E2. 📏 NAMED, NOT FIXED, so it is not a surprise: with `@ocr` typed, the
    line under the box still reads "200 matches across every store" —
    which is not true, it is pinned to one store. Your screenshot. It is
    its own small release; say if you want it sooner.



## 6.297.0

6.297.0 verify with LL — 🗂 A LINE IS A TASK (NEW GROUND — expect a round)
WHAT CHANGED: Hamsidian can now READ your task grammar. It does not
send it yet, on purpose.
🔎 AND FIRST, YOUR QUESTION, ANSWERED: **no.** "→ Asana now" builds
ONE task for the whole day — titled `Hamsidian · Fri Sep 26`, with
every open tab's text as its description. Never one task per line.
(And the 4 PM schedule is OFF anyway — you switched it off in
6.254.0 — so only that button and `_G.scratchPadSend()` send at all.)
WHY THE PREVIEW COMES FIRST: this is your grammar and only you know
what you will really type. If I build the sending first, the first
thing either of us learns about a misreading is a wrong task sitting
in Asana. So this release prints what it understood, and you tell me
where it is wrong before anything reaches your board.

A. THE HEADLINE — this is the whole test.
A1. Press ⇪N and type into a tab, in your own words. Include at
    least one bare line, one `=`, and one P:/A:/D:/S:/T: block. Your
    own example from the message is perfect:
      Create the Asana task maker in Hamsidian
      =
      P: Generate a new init.lua feature
      A: me
      D: We need to structure a new Hammerspoon feature.
      S: Structure tool request
      S: Submit tool request
      T: today +1w 7:00 AM 4:00 PM
      S: Begin coding today
A2. Console: `_G.scratchPadTasks()`. **PASTE THE WHOLE THING.**
    EXPECT: two tasks — "Create the Asana task maker in Hamsidian",
    and "Generate a new init.lua feature" with 👤 me, its 📄
    description, three ↳ subtasks, and a 📅 line reading start today
    07:00 · due <a week out> 16:00.
A3. Read every line of that output against what you MEANT. That is
    the test. Anything it got wrong is a one-line fix here and a
    wrong task in Asana later.

B. THE THING I MOST WANT TO KNOW — the `T:` line.
B1. You described the INTENT ("Today as start date, one week from
    today as the end date, start time 7:00 AM, end time 4:00 PM") and
    not a syntax, so I guessed one. It reads:
      today · tomorrow · yesterday · +3d · +2w · +1m
      2026-09-13 · 09/13/26 · 9-13-2026
      7:00 AM · 4pm · 07:00 · 16:00
    First date is the start, second is the due; first time the start,
    second the end.
B2. Write a `T:` line the way you WOULD write it, without looking at
    that list, and run the preview. Anything it cannot read is named
    as `⚠️ could not read "x"`. Send me those words — they are the
    spec, and my guess is not.

C. THE ONES THAT PROTECT A TASK FROM VANISHING.
C1. Put a bare line straight after a `D:` line. EXPECT: it becomes
    its OWN task, not part of the description. That is the decision I
    made, and it is the one worth disagreeing with if you disagree.
C2. Write `D: something` with no `P:` above it. EXPECT: a ⚠️ saying
    it is before any task. It is dropped rather than silently glued
    onto the next thing.
C3. Write `D: a = b`. EXPECT: it stays one task with "a = b" as the
    description — an `=` inside a line is text, only a line that is
    nothing but `=` divides.

D. MUST STILL WORK — this release added a reader and changed no
   behaviour, so this is the sweep.
D1. ⇪N and ⇪3 open as before, your tabs and notes are untouched.
D2. "→ Asana now" still does exactly what it did — one task for the
    day. Nothing about sending changed.
D3. ⌘⇧S still exports tabs as notes.

E. WHAT IS NOT BUILT YET, said plainly so it is not a surprise.
E1. **Nothing is sent from the grammar.** That is next.
E2. **Subtasks are read but cannot be sent** — Asana needs the parent
    task's id back before a subtask can be attached, which is a
    second call and its own release. The preview says so on every row
    that has one.
E3. **The clearing you asked for** — tasks gone from the pad and "All
    tasks sent." left behind — comes with the send. One question I
    need answered before I build it, and it is the only one that can
    lose your writing: when a tab is cleared, where should the text
    GO? Options: (a) nowhere, it is gone; (b) into the tab's history,
    recoverable from the report; (c) exported as a note in
    <Vault>/Scratch first, so it is a file. **I will build (c) unless
    you say otherwise** — 6.280.0's rule is that deleting your
    writing is the one failure with no way back.
E4. **4 PM back on, open or not.** The schedule already runs whether
    the window is open or not — it lives in the module, not the
    window — it is simply switched off. It comes back on with the
    send, not before, because a schedule that fires a grammar I have
    not proven is the wrong order.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
