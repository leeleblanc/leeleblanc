# TESTING — how to score release 6.385.0

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

## 6.385.0

6.385.0 verify with LL — 🎨 THE PICKERS LOOK LIKE THE JUG PLAYER
(KNOWN GROUND)
WHAT CHANGED: every picker in this config now wears the Jug Player's
dark card instead of macOS's white one.
🔎 AND HALF YOUR ASK IS NOT POSSIBLE, said first rather than found out
later. You asked for two things: the LOOK, and an **(x) at the end of
every row**. The look is done. The ✕ is not, on these windows, and
cannot be: the ⇪⇧V window in your screenshot is an `hs.chooser` — a
list macOS draws for us from plain strings — and there is no
sub-element in a row to click and no way to put one there. The Jug
Player HAS a ✕ because it is a web page we draw ourselves, every
pixel of it. That is the whole difference between those two
screenshots.
🔬 I nearly told you the colours were impossible too, and that would
have been wrong — hs.chooser does expose bgDark, fgColor and
subTextColor, and one of your own tools (the app-quit popup) has used
all three since 6.16.21.

A. THE HEADLINE — ten seconds.
A1. Press ⇪V (clipboard) or ⇪⇧V. EXPECT: a DARK panel, white text,
    dimmer second line — the Jug Player's colours.
    **A FAIL is the white panel in your screenshot.**
A2. Now press several more: ⇪space, ⇪Y, ⇪⇧S, ⇪., ⇪⇧;, ⇪T.
    EXPECT: every one of them dark, and all of them the SAME dark.
    That sameness is the release — they read one table now.
A3. ⇪D (unified search) was already dark. EXPECT: unchanged, and the
    two now look like each other.

B. MUST STILL WORK — this touched the one door every picker opens
   through, so this half matters more than A.
B1. Type to filter in ⇪V. ↑↓ walk. ⏎ picks. Esc closes.
B2. ⌘-drag a picker somewhere, close it, open it again: it reopens
    where you put it.
B3. ⌃⌥⌘ + an arrow nudges an open picker; ⌃⌥⌘R clears the nudge.
B4. The preview pane beside ⇪⇧V and ⇪⇧S still follows the rows.
B5. ⌘⌘ still opens the clipboard; ⌥⌥ still opens the menus.

C. PASTE BACK.
C1. If ANY picker is still light, name it — that would mean it is
    opening without going through the shared door, which is a real
    finding and a different bug.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. Too dark? Too much? `settings = { ui_style = { pickerDark =
    false } }` puts macOS's own light pickers back everywhere at once.
    Say the word and I change the default rather than leaving you a
    line to type.
D2. **Which windows did you mean by "my other windows"?** If you meant
    the ones that CAN have a ✕ — Hamsidian, the pads, the task form —
    say so: those are web pages, they can have anything, and that is a
    different and bigger release I did not want to guess at.
D3. On a picker the nearest thing to a ✕ is a KEY on the highlighted
    row. ⇪⇧V already deletes that way. Want that on others — and which?



## 6.384.0

6.384.0 verify with LL — 🗑 REMOVE AN APP (NEW GROUND — it moves files)
WHAT CHANGED: there is a new tool. **⇪⇧[** — hold Caps Lock and Shift
and press the **[** key, just right of P — removes an app AND the
leftovers it keeps in your home folder.
🚨 NOTHING IS EVER ERASED. Everything goes to the **Trash**, and you
empty the Trash yourself. If it ever takes something you wanted,
Finder → Trash → **Put Back**.
🚨 AND THE FIRST PRESS MOVES NOTHING. It SHOWS you the list first.

A. THE HEADLINE — use something you do not mind losing.
A1. Press **⇪⇧[**. EXPECT: a picker listing your applications.
A2. Type part of an app's name and press ⏎.
    EXPECT: an alert naming the app, how many items and how big — and
    saying NOTHING HAS MOVED. **Check your Applications folder: the
    app must still be there.**
A3. Open the Console. EXPECT a list, one line per item: the .app
    itself, then each leftover, with its size and the rule that found
    it. **READ THAT LIST.** It is the whole point of the tool.
A4. Any line with a ⚠️ was matched by the app's NAME rather than its
    bundle id — a guess. Another app's folder can be called the same
    thing. Read those before step A5.
A5. Press ⇪⇧[ again. EXPECT the FIRST row now reads
    "✅ Move “<app>” to the Trash — N item(s), …". Press ⏎ on it.
    EXPECT: an alert saying how many moved, and the app is gone from
    Applications and sitting in your Trash.
A6. Open the Trash. EXPECT the .app and each leftover, each stamped
    with the date and time. Put one back to prove it works.

B. THE REFUSALS — these are the tool working, not failing.
B1. Try to remove an app that is OPEN. EXPECT it refuses and tells you
    to quit it first. Nothing moves.
B2. `_G.appRemove("NoSuchApp")` in the Console. EXPECT it says it
    cannot find it rather than guessing.
B3. 🚨 If it EVER moves something outside your home folder or
    /Applications, stop and tell me at once. It is built so it cannot:
    every path is checked immediately before it moves, and the test
    suite puts /etc/passwd into a list on purpose and requires the
    move to turn it away.

C. THE CONSOLE DOORS, if you prefer typing.
C1. `_G.appRemove("Transmission")` — lists, moves nothing.
C2. `_G.appRemoveGo()` — moves what was just listed.
C3. `_G.appRemoveReport()` — what it last listed or moved.

D. A JUDGEMENT ONLY YOU CAN MAKE.
D1. **Is ⇪⇧[ a key you will remember?** It is one of only two free
    shifted keys left (the other is ⇪⇧]), and I picked it rather than
    take one you use. Say if you want it somewhere else.
D2. **Is the Trash the right answer for the caches?** You said "delete
    any temp files" — I read that as "take the caches WITH the app"
    rather than "erase them", because erasing is the one thing with no
    way back. If you want caches erased outright rather than trashed,
    say so; it is a decision, not an oversight.
D3. **Did it miss anything?** Check ~/Library after a removal for a
    folder with that app's name still in it. The list of places it
    looks is in the module and takes one line to extend. It
    deliberately does NOT touch the system /Library or launch daemons
    — those need a password.



## 6.383.0

6.383.0 verify with LL — 📓 @logs IN ⇪D (KNOWN GROUND)
WHAT CHANGED: ⇪D has a fifteenth source. Every tool that has failed on
this Mac is now searchable from the panel you already use.
🔎 You were right that it was missing — and the uncomfortable part is
that 6.279.0 named this exact gap when it built the failure log, in
writing, and then never built it.
A1. Press ⇪D and type a single `@`.
    EXPECT **15 sources** now, and **📓 @logs** among them.
A2. ⏎ on it. EXPECT the failures, newest first, each with the tool,
    the reason and when.
A3. Type `@logs hamsidian` (or any tool name). EXPECT it filters.
A4. `_G.todayReport()` still works and still shows today alone. The
    two read the same file through the same parser now.
A5. If @logs ever shows a single row reading "⚠️ the failure log could
    not be read", paste it. That is deliberate: a log that cannot be
    read must never come back as an empty list, because "nothing has
    failed" is the most reassuring thing this config can say and would
    be a lie on exactly the day the disk is full.



## 6.382.0

6.382.0 verify with LL — 📋 A PICKED SNIPPET LANDS ON THE CLIPBOARD
(KNOWN GROUND)
WHAT CHANGED: pick a snippet from ⇪⇧S and it is now left ON the
clipboard, so ⌘V pastes it again and it is the newest row in ⇪V.
A1. ⇪⇧S, pick a SHORT snippet. It types at the caret as always.
    Now press ⌘V somewhere else. EXPECT: the same snippet again.
A2. ⇪⇧S, pick a MULTI-LINE one (a signature, the out-of-office).
    EXPECT: it inserts, and ⌘V still pastes it afterwards. Before, your
    old clipboard came back a quarter-second later and the snippet was
    gone.
A3. Press ⇪V. EXPECT the snippet is the NEWEST row.
A4. 🚨 THE ONE THAT PROTECTS YOU: copy something of your own with ⌘C,
    then TYPE a trigger (not the picker — type it). EXPECT: your copy
    is still on the clipboard. A typed trigger must never touch it —
    you fire thousands a day and they would bury everything you copy.
A5. `_G.snippetsReport()` — a new `clip :` line counts them. If it
    ever says REFUSED by macOS, paste it.
A6. Don't want it? `settings = { expander = { pickToClipboard =
    false } }`. Say so and I will change the default instead.



---

_Generated from the release notes — never hand-edited, so it cannot
describe steps for a release that was not built._
