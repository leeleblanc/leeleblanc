# TESTING — how to score release 6.333.0

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

## 6.333.0

6.333.0 verify with LL — 🕸 ONE HAMSIDIAN LIST (KNOWN GROUND)
WHAT CHANGED: the left column is ONE list now. A scratch tab and a
note sit side by side, newest first, and the ICON tells them apart —
📝 is a tab, 🕸 is a note.
WHY: you asked for "the one-list Hamsidian", and you were right that
two sections was the odd part. 6.253.0 gave both sides one name and
made the icon the difference; the list had never caught up.

A. THE HEADLINE.
A1. Press ⇪N. Look at the left column.
    EXPECT: one heading — 🕸 HAMSIDIAN — with your tabs and your
    notes under it together. NOT two sections.
A2. Read a few rows. EXPECT: 📝 in front of every tab, 🕸 in front
    of every note. If any row has no icon, tell me which.
A3. Press ⇪3. EXPECT: the same window, the same one list.

B. THE KEYS MUST NOT HAVE MOVED — this is the half that matters.
B1. Click a 📝 row. EXPECT: that tab opens, you can type in it.
B2. Click a 🕸 row. EXPECT: that note opens with its text.
B3. ⌘T makes a new tab. ⌘W closes the one you are on.
B4. ↑↓ walk the whole list — through tabs AND notes, one run, no
    jump. ⏎ opens whichever is highlighted.
B5. The ✕ on a 📝 row closes the tab. The ✕ on a 🕸 row deletes the
    note to .trash (6.321.0). They must NOT be swapped.
B6. ⌘F and type. EXPECT: it filters both kinds at once. Type part
    of a note's HEADING (6.328.0) and part of a tab's first line —
    both must find their row.

C. PASTE BACK.
C1. `_G.vaultReport()` — the whole block.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Newest first, both kinds mixed. Is that the right order, or
    would you rather tabs always sat above notes inside the one
    list? "mixed is right" · "tabs first" decides it.
D2. 🔨 CRUDE OR ELEGANT: nothing was broken — this is a shape ask.
    Say if you think it belongs in the ledger at all.



## 6.332.0

6.332.0 verify with LL — 🔄 ASANA REFRESHES ITSELF (KNOWN GROUND)
WHAT CHANGED: Asana is told to reload every five minutes, on its
own, whether or not it is in front.
🚨 AND NOT THE WAY YOU DRAFTED IT, which I want to say plainly. Your
version activated Asana, posted ⌘R and activated the previous app
back. That posts a keystroke back through this config's own taps
(6.218.0), steals focus twice every five minutes, and leaves a
window where a ⌘R can land in whatever you clicked into. This one
asks Asana's own View ▸ Reload menu WITHOUT activating it — nothing
is stolen and nothing has to be put back.

A. THE HEADLINE.
A1. Have Asana running. Work in another app for ten minutes.
    EXPECT: NOTHING. No window comes forward, no flicker, no
    keystroke lands anywhere. **A FAIL here is Asana jumping to the
    front** — that is the thing this was built to avoid.
A2. Console: `_G.asanaRefreshReport()`.
    EXPECT something like:
      every   : 5 minute(s) · running
      asked   : 2 · refreshed 2 · app not running 0 · refused 0
      menu    : View ▸ Reload
    PASTE IT. The `menu :` line is the one I cannot know from here.
A3. Look at Asana. EXPECT: the board is current.

B. THE ONE THAT MUST NOT CRY WOLF.
B1. Quit Asana. Wait ten minutes.
    EXPECT: no alert, no Console warning, nothing. The report's
    "app not running" count goes up and that is all. A closed app is
    the ordinary state, not a failure.

C. IF THE MENU IS WRONG.
C1. If the report ever reads `menu : ⚠️ no menu path matched — tried
    View ▸ Reload · View ▸ Refresh · …`, paste it. That means Asana
    renamed the item and the fix is one line. The refresh does
    nothing in the meantime — it never falls back to posting a key.

D. IF IT GETS IN THE WAY.
D1. `settings = { asana_comments = { refreshMins = 15 } }` slows it;
    `refreshMins = 0` stops it.
D2. 🗳 ONE QUESTION: should it PAUSE while you are typing in Asana? A
    reload that discards a half-written comment is worse than a
    stale board. I have not built that — say the word and it is a
    small release.



## 6.331.0

6.331.0 verify with LL — 💾 THE NOTES HAVE A SECOND COPY (KNOWN GROUND)
WHAT CHANGED: your Hamsidian notes are rsync'd to a LOCAL folder
every thirty minutes. Nothing you press changes.
WHY: every other store in this config has had a 30-minute mirror
since 6.190.0 and the vault never did. It lives in OneDrive so
Obsidian can open it on either Mac — which means it has had exactly
one copy, owned by a sync client, and a sync client is not a backup:
a deletion propagates.

A. THE HEADLINE.
A1. Console: `_G.backupReport()`. Find the new `vault :` line.
    EXPECT: a destination under ~/Library/Application Support, and
    either "not run yet" (straight after a reload) or a time and
    "ok". PASTE IT.
A2. Wait a few minutes after a reload, run it again.
    EXPECT: a real time and "ok".
A3. Open that destination folder in Finder.
    EXPECT: your notes, as .md files. NOT a `.trash` folder — that
    is excluded on purpose, because 6.321.0's bin already keeps
    deleted notes for 180 days.

B. IT MUST NEVER SHRINK.
B1. Delete a throwaway note in Hamsidian. Wait for the next mirror.
    EXPECT: the file is STILL in the local copy. No rsync in this
    kit carries `--delete`, deliberately — a vault that failed to
    load must not be able to erase its own backup. The cost is that
    the copy only grows; that is the right trade for your writing.

C. MUST STILL WORK.
C1. The nightly backup and the 30-minute store mirror are unchanged.
C2. Hamsidian itself is untouched — no new write, no new read on the
    path you type on.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Thirty minutes, same as the stores. Too often for a folder of
    notes, or not often enough? `vaultMirrorMins`.
D2. The destination is deliberately NOT in OneDrive — a backup
    inside the thing being backed up is one deletion from being
    neither. Say if you want a second copy somewhere else as well
    (an external disk, say); that is its own release.



## 6.330.0

6.330.0 verify with LL — 🧊 THE HEARTBEAT CARRIES WHAT WAS RUNNING
(KNOWN GROUND — an instrument, not a fix)
WHAT CHANGED: the file the stall guard watches now carries the NAME
of the shortcut the main thread is inside, not just a clock.
🚨 AND I HAVE NOT FIXED YOUR LOCKUP. Saying that first. Your log
reads `🧊 Hammerspoon HUNG for 73 s at 2026-10-04 17:16:59 and was
relaunched by the stall guard` — that is 6.208.0's guard working,
for the second time in the field, and it is why you got your Mac
back without a reboot. What it could not say is WHAT hung. Two
relaunches, two reports, zero attribution. This is the release that
makes the next one name itself.

A. THE HEADLINE.
A1. Console: `_G.stallGuardReport()`.
    EXPECT the usual block plus a new `in flt :` line. On an idle
    Mac it reads "nothing in flight". PASTE IT.
A2. Hold a ⇪ shortcut that takes a moment — ⇪D, say — and run the
    report immediately afterwards.
    EXPECT: "nothing in flight" again (it clears when the shortcut
    returns). The line is only ever non-empty DURING a shortcut,
    which is exactly when you cannot type.
A3. If `in flt :` ever carries `⚠️ N beat(s) could not build a
    label`, paste it — the guard still works (it falls back to the
    bare clock) but the breadcrumb is not being written.

B. WHEN IT LOCKS UP AGAIN — this is the real test and I cannot run
   it from here.
B1. If Hammerspoon hangs and the guard relaunches it, the next boot
    announces it as before. **Then send me the guard's log**, which
    the report names the path of. It will now carry a line reading
    `in flight: ⇪<something>` beside the kill — that is the
    shortcut the main thread was inside.
B2. If it reads `in flight: (none)`, that is just as useful: it
    means the thread stopped somewhere that is NOT a ⇪ shortcut —
    a timer, a watcher, or macOS itself — and that halves the
    search.

C. MUST STILL WORK — the guard is a kill switch, so this matters.
C1. Use the Mac normally for a day. Hammerspoon must NOT be
    relaunched. If it is, paste the log at once.
C2. Reload Hammerspoon. `_G.stallGuardReport()` must show ONE
    guard running, never two.
C3. Close the lid for a few minutes and open it. Nothing must
    happen — the sleep rule is unchanged.

D. WHAT I SUSPECT AND HAVE NOT PROVEN.
D1. Your boot said `0.24s` and then loaded five Hammerspoon
    extensions over the next FORTY-TWO SECONDS — notify at
    17:17:03, mouse at 17:17:29 (twenty-six seconds later),
    webview, drawing, geometry. Each of those is a library being
    loaded on the main thread, lazily, the first time something
    asks for it. That is a candidate for a long stall and it is
    NOT a verdict (6.198.0). The breadcrumb is what will tell us.
D2. 🔨 CRUDE OR ELEGANT: by your own description the Mac was
    unusable — "I couldn't even click on anything on the screen".
    My reading is 🔨 CRUDE, and the pass count is 0, because
    nothing here is a fix yet. Your tag.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
