# TESTING — how to score release 6.305.0

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

## 6.305.0

6.305.0 verify with LL — 🔁 A RETRY NO LONGER DUPLICATES (KNOWN GROUND)
WHAT CHANGED: a task that reached Asana is remembered, so a retry —
and a tab you type in again — sends only what did NOT land.
🚨 WHY THIS JUMPED THE QUEUE, and please read this bit even if you
skip the steps. Your 16:00 line said "1 of 122 task(s) did not reach
Asana". The number that matters is the other one: **121 of them
DID**. A tab with one refused task is marked ❌, a ❌ tab is retried,
and the retry re-reads the whole tab — so tomorrow at 16:00 those
121 would have gone to Asana a second time, and the day after a
third, growing every day until you happened to fix the one bad line.
I wrote the rule that forbids this four releases ago, for subtasks,
and did not apply it to the tab two hundred lines above.
🕒 IF YOU DO NOT INSTALL TONIGHT, one Console line stops tomorrow's
run: `_G.scratchPad.sendTimer:stop()`. It lasts until the next
reload, and `_G.scratchPadSend()` still sends by hand.

A. THE HEADLINE — this is the whole test and it takes two minutes.
A1. ⇪N, a fresh tab, three lines:
      Alpha test one
      Bravo test two
      Charlie test three
A2. Console: `_G.scratchPadTasks()`. EXPECT three tasks, none marked.
A3. Send it ("→ Asana now"). EXPECT three tasks in Asana and the tab
    retitled ✅ Success: tasks sent.
A4. Click into the tab and add a fourth line: `Delta test four`.
    EXPECT the ✅ disappears (typing clears the mark — that is right
    and unchanged).
A5. `_G.scratchPadTasks()` again.
    EXPECT the first three each marked **✅ already in Asana — not
    sent again**, and only Delta shown as a task that would go.
A6. Send again.
    EXPECT **ONE** new task in Asana — Delta. Not four.
    **A FAIL here is four tasks**, and it is the bug this release
    exists to fix. Tell me at once.
A7. The alert should read "…1 task from 1 tab · 3 already in Asana,
    not sent again".

B. THE ONE THAT IS ACTUALLY YOUR CASE.
B1. Make a tab with two good lines and one line Asana will refuse —
    `A: notarealperson` under a `P:` task will do it.
B2. Send. EXPECT the two good ones in Asana, the tab marked ❌.
B3. Send again (or wait for 16:00).
    EXPECT **only the bad one is retried**. The two that landed must
    NOT appear in Asana a second time.
B4. Fix the bad name and send once more. EXPECT one task, and the
    tab goes ✅.

C. IT HAS TO SURVIVE A RELOAD — the duplicate that would really have
   bitten you is the one after Hammerspoon restarts.
C1. After A6, reload Hammerspoon.
C2. `_G.scratchPadTasks()`. EXPECT all four still marked ✅ already
    in Asana.
C3. Type a character in the tab (clearing the ✅) and send.
    EXPECT **nothing is sent** — there is nothing new. A run that
    posts four tasks here is the memory not reaching disk.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.scratchPadReport()` — there is a new `landed:` line saying
    how many tasks across how many tabs are remembered as already in
    Asana. On your Mac after today that number should be large.
D2. If it ever carries "⚠️ N remembered task(s) were forgotten this
    session", paste it — that is the 400-per-tab bound biting, and
    past it a duplicate becomes possible again.

E. A JUDGEMENT ONLY YOU CAN MAKE — and this is the real question.
E1. **Did you want 121 tasks on your Asana board today?** The
    grammar reads every bare line as a task, and it sweeps every
    open tab, so any prose you keep in Hamsidian became Asana tasks
    at 16:00. I have NOT capped or narrowed that, deliberately — you
    asked for one task per line and I am not going to quietly
    un-decide it. Three answers, each a different next release:
    · "yes, that is what I wanted" → nothing more to do.
    · "no — only tabs I mark should send" → the send reads only tabs
      that opt in (a marker line, or a tab title convention).
    · "no — it should refuse a run that big and ask me first" → a
      ceiling on the UNATTENDED 16:00 run only, with the button
      still uncapped because you are watching it.
E2. 📏 SAID RATHER THAN IMPLIED: the line that failed was
    `A: <a default assignee of 'me'>`. That is prose, not a name,
    and the guard did exactly the right thing — it refused it, kept
    every word, and marked the tab. That part is not a bug. But it
    does mean something in your tabs is being read as an assignee
    when you meant it as text.



## 6.304.0

6.304.0 verify with LL — 🚨 SECURE INPUT CAN FINALLY ANSWER (KNOWN GROUND)
WHAT CHANGED: the probe that asks whether anything has locked your
keyboard could stop for the whole session and never say so. It cannot
any more.
WHY IT MATTERS, and your own report is what named it: every
`_G.hyperKeyReport()` you have sent reads `secure: not known —
capabilities.lua has not answered yet`, and `_G.secureInputReport()`
said `1 probe(s) STARTED and none finished`. One probe attempted,
never a second — while a timer went on asking every sixty seconds and
being turned away at the door.
🔬 THE CAUSE, in one sentence: a flag says "a probe is already
running" so two ioregs never stack up, and the ONLY thing that
cleared it was a probe finishing successfully. So the first one that
could not finish shut the feature down until the next reload.
🚨 AND IT IS THE LAST OF 6.303.0's THREE CANDIDATES. The remap and
the tap have both been answering you correctly since you installed
it; Secure Input — the one that kills every shortcut on the Mac with
no error anywhere, and lives on the lock screen a wake goes through —
is the one that has never once been measured on your Mac. This is
what makes it answerable. It is NOT itself a fix for the storm.

A. THE HEADLINE — one command, and it is the whole test.
A1. Install, reload, wait about ten seconds.
A2. Console: `_G.secureInputReport()`.
    EXPECT, and this is the line that has never appeared on your Mac:
      state  : off — nothing is holding the keyboard
      probes : 1 checked · 0 failed · 0 change(s) seen
    A `state : ON — <app> holds it` is also a pass, and a much more
    interesting one: paste it immediately, it means something really
    is sitting on your keyboard.
    **A FAIL is `state : UNKNOWN` still.** If you get that, the ↳
    lines under it now say WHY, which is the part that did not exist
    before — paste the whole block.
A3. `_G.hyperKeyReport()`.
    EXPECT the `secure:` row to read `Secure Input clear` instead of
    `not known — capabilities.lua has not answered yet`.
    That row going from "not known" to an actual answer IS the
    release.

B. IT MUST KEEP ANSWERING — the wedge was a thing that happened over
   time, so one good reading is not proof.
B1. Use the Mac for a few hours.
B2. `_G.secureInputReport()` again.
    EXPECT `probes :` to be a COUNT IN THE DOZENS — one a minute — not
    1, and not stuck at whatever it said in A2. A number that has not
    moved in an hour is the same bug in a new place.
B3. `_G.hyperKeyReport()` — the `secure:` row should still answer.

C. IF IT EVER FAILS, IT NOW SAYS WHICH WAY (this is the new half).
C1. If you see any of these ↳ lines, paste them — each one sends me
    somewhere different:
    · `↳ N × macOS REFUSED to launch ioreg` — your Mac would not run
      the command at all. That is a permissions or a beta-OS answer.
    · `↳ N × ioreg started and NEVER ANSWERED` — it ran and hung.
      Different fix entirely.
    · `⚠️ N probe(s) ran with NO belt` — this Mac would not give us a
      timer, which would be a finding of its own.
    Before this release all three were one silent nothing.

D. MUST STILL WORK — this touched a core file that every boot runs.
D1. Boot is normal, `All green`, and the module count is unchanged.
D2. Use ⇪ normally for a day: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space.
D3. `_G.capabilityReport()` still prints, with its 🔒 row.
D4. Typing does not feel heavier. The probe runs off the main thread
    as it always has; nothing about that changed.
D5. `_G.stormReport()`, `_G.degradeReport()` and `_G.todayReport()`
    all still print.

E. A JUDGEMENT ONLY YOU CAN MAKE.
E1. Twenty seconds is how long a probe may go unanswered before it is
    given up on. If you ever see the "never answered" line on an
    ordinary day, that number is probably too short for your Mac and
    it is a setting, not a release.
E2. 📏 SAID RATHER THAN IMPLIED: if Secure Input now reads ON at some
    point and your shortcuts were dead at that moment, that is an
    ANSWER to the storm question, not a new bug. Tell me the app it
    names.



## 6.303.0

6.303.0 verify with LL — 🔬 THE KEYBOARD, AFTER A WAKE (NEW GROUND)
WHAT CHANGED: two seconds after your Mac wakes, this config now looks
at the three things that can make ⇪ die without saying anything, and
writes down what it found. If the Caps Lock remap has gone, it puts
it back.
WHY THIS ONE AND NOT ANOTHER GUESS: 6.302.0 could not have prevented
your storm and says so. This is the release aimed at it — and it is a
PROBE, because everything I can offer about the cause right now is a
story that fits. The three candidates, all invisible from here until
today: the Caps Lock → F18 remap (set once when Hammerspoon starts
and never checked again), the event tap that reads F18 (macOS
switches taps off across some transitions and tells nobody), and
macOS's Secure Input (it stops every shortcut on the Mac, system
wide, with no error anywhere — it took your keyboard for four hours
once, and a lock screen is exactly where it lives).
🔕 ON A HEALTHY MAC THIS SAYS NOTHING. That is deliberate, and it
means the test below is "go and read the numbers", not "wait for a
message".

A. THE HEADLINE — no lid-closing required.
A1. Console: `_G.hyperWakeProbeRun("by hand")`
    Wait two seconds, then `_G.hyperKeyReport()`.
    EXPECT a `probe :` block with three rows, and on a healthy Mac
    all three read plainly, with no ⚠️:
      remap : Caps Lock → F18 still set
      tap   : the F18 event tap is running
      secure: Secure Input clear
A2. **PASTE THAT BLOCK.** It is the first time this config has ever
    been able to answer any of those three questions, and I want to
    see what your Mac says on a good day before we look at a bad one.
A3. Any ⚠️ on those three rows on a healthy, just-booted Mac is a
    real finding — say so immediately.

B. THE REAL ONE — the car journey, reproduced.
B1. Close the lid. Wait a minute or two. Open it and log back in.
B2. Wait a few seconds, then `_G.hyperKeyReport()`.
    EXPECT the `probe :` line to say `after systemDidWake` with a
    time on it. If it still says "nothing looked at yet", the wake
    never reached us and that is 6.302.0's step A3 failing — tell me.
B3. Read the three rows. **This is the whole point of the release.**
    · `remap : ⚠️ GONE` → THAT IS YOUR BUG, found. It will have put
      it back, and you will have seen a Console line saying so.
    · `tap : ⚠️ the F18 event tap was NOT running` → it is the tap,
      and the fix is a different one line.
    · `secure: ⚠️ Secure Input held by …` → it is macOS's lock
      screen, and the fix is different again.
    · all three clean → none of my three candidates, and that is
      genuinely useful: it means the keyUp is being lost somewhere
      else and I stop guessing in this direction.
B4. Then press ⇪ and hold it while you press a few letters, right
    after a wake, and see whether it storms. If it does, send me
    `_G.stormReport()` AND `_G.hyperKeyReport()` together — the two
    side by side is what no previous build could give.

C. MUST STILL WORK — this touched the ⇪ key and added a background
   process, so this is the half that matters more than A or B.
C1. Use ⇪ normally for a day. No change of any kind.
C2. Typing must not feel heavier after a wake. The probe runs off the
    main thread on purpose (6.228.0 — a busy main thread is a mouse
    this Mac has lost), but if the Mac stutters a couple of seconds
    after every lid-open, that is me and I want to know at once.
C3. Caps Lock must still behave as ⇪ and must NOT start toggling
    capitals. If it ever does, the remap has been changed rather than
    restored — stop and tell me, that is the worst thing here.
C4. `_G.stormReport()` still prints. `_G.degradeReport()` and
    `_G.todayReport()` still print.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.hyperKeyReport()` from A1, on a good day.
D2. `_G.hyperKeyReport()` from B2, after a real wake.
D3. If `counts:` ever shows a repair, that line is the answer to
    everything we have been chasing — send it whatever else you do.

E. THE SENTENCE I STILL WANT, and it beats all three probes.
E1. Was ⇪ working between the storm at 10:57 and your reload that
    evening? Dead until the reload → the remap is being lost, and
    this release will now catch it and repair it. Working → the
    remap survived, and the probe's other two rows are where to look.
E2. 📏 SAID RATHER THAN HIDDEN: if the probe finds the event tap
    switched off, it REPORTS it and does not restart it. Restarting
    a tap is not the same kind of act as restoring a mapping — this
    config switches that tap off itself after five consecutive
    errors, on purpose, and re-arming it automatically would undo a
    decision it made for a reason. If your report ever shows that
    row, the next release decides what to do about it with evidence
    instead of a guess.



## 6.302.0

6.302.0 verify with LL — 🌅 A WAKE IS SEEN (NEW GROUND — expect a round)
WHAT CHANGED: this config now knows when your Mac wakes up. Nothing
here had ever watched the wake side — the one sleep/wake watcher in
seventy-one modules listens for the screen LOCKING. And a ⇪ hold
still open across a wake is let go.
🚨 AND IT IS NOT THE ANSWER TO YOUR STORM. I am saying that first
because the message I sent you implied it was, and the report you
sent me says otherwise. Your hold was 10.5 seconds old. That clock
starts on a FRESH Caps Lock press, so the hold began AFTER the car
journey, not across it — the first ⇪ press once you opened the lid
never ended. A watcher firing as the lid opens would have found ⇪ up
and done nothing, and your storm would have happened exactly as it
did. The wake is still the setting; this release is not the fix, and
6.303.0 is the probe aimed at it.
🔎 ONE THING IN THAT REPORT THAT IS NOT A SECOND FAULT, so you do not
read it as one: `0 watchdog release(s)`. The 8-second watchdog cannot
end a latch while keys keep arriving — every key you press proves the
hold is real and pushes its deadline out, by design — and a person
fighting a dead keyboard never stops pressing keys. That is exactly
the hole the storm guard was built to cover, and it covered it:
released at 10.5 s, wrote the file, announced it at the next boot.

A. THE HEADLINE — and it is quiet, which is the point.
A1. Install and reload. Console: `_G.hyperKeyReport()`.
    EXPECT a new line: `wake     : 0 wake(s) seen, none found ⇪ held.`
    A ⚠️ on that line instead means this Mac would not give us a
    sleep/wake watcher — paste it, that is a real finding.
A2. Close the lid. Wait thirty seconds. Open it, log back in.
A3. `_G.hyperKeyReport()` again.
    EXPECT the wake count to have gone UP — 1, 2 or 3 depending on
    whether macOS sent one event or several. Any number above 0 is a
    pass. **0 IS THE FAIL**, and it is the one I most want to hear
    about, because everything in 6.303.0 hangs off this working.
A4. Note that number and tell me what it is. I genuinely do not know
    whether your Mac sends one wake event or three, and it decides
    how 6.303.0 reads its own measurements.

B. THE RELEASE ITSELF — only if you want to see it fire.
B1. Hold Caps Lock down and, while still holding it, close the lid.
    Wait ten seconds, open it, log back in.
B2. `_G.hyperKeyReport()`.
    EXPECT `N wake(s) seen · 1 found ⇪ STILL HELD and let it go`,
    and the line says it is NOT a latch.
B3. Console, scroll back: one line reading "⇪ let go on
    systemDidWake … nobody holds ⇪ through a sleep". No alert on
    screen — deliberately. If you got an alert, tell me: waking your
    Mac should never pop a message at you.
B4. `latch    : 0` on that same report. That number is the one the
    storm report prints as a fault, and a wake release must never
    touch it — otherwise it climbs every morning on a healthy Mac
    and stops meaning anything.

C. MUST STILL WORK — this is the ⇪ key, so this is the important half.
C1. Use ⇪ normally for a day: ⇪T, ⇪D, ⇪N, ⇪3, ⇪X, ⇪4, ⇪space.
    EXPECT no change of any kind.
C2. Hold ⇪ for ten seconds without pressing anything, then let go.
    EXPECT the old `released by the watchdog — held 8s` line. That
    warning must keep its teeth.
C3. Open the music card (⇪⇧pad.) — its one-off "took the keyboard"
    line still appears, and `handover` still counts.
C4. `_G.stormReport()` — it must PRINT, not throw (6.282.0), and its
    `before :` line now carries a wake count and the watcher's state.

D. PASTE BACK, PASS OR FAIL.
D1. `_G.hyperKeyReport()` after a few days of ordinary lid-opening.
D2. `_G.stormReport()` if another storm happens. The `before :` line
    is now the fingerprint for this too.

E. THE ONE SENTENCE I NEED, AND IT IS WORTH MORE THAN ANY PROBE.
E1. **Was ⇪ working between that storm at 10:57 and your reload that
    evening?** Two answers, two different bugs:
    · ⇪ was DEAD until you reloaded → the Caps Lock → F18 remap is
      being lost when the Mac wakes. That is bigger than the storm:
      it means ⇪ stops existing after every car journey until
      Hammerspoon restarts. 6.303.0 becomes a repair.
    · ⇪ went on working → the remap survived, and the keyUp was
      eaten by something else (the event tap being switched off
      across the transition, or macOS's Secure Input during the lock
      screen). 6.303.0 stays a probe that tells those two apart.
E2. If you would rather not wait: press ⇪ a few times right after
    the next wake and see whether anything happens. That is the same
    answer in ten seconds.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
