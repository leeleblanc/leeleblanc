# UNBUILT — what is asked for, known, or owed, as of 6.293.0

Swept from CLAUDE.md and **checked against the code**, not just read off
the queue — six of the deferred defects below were re-verified in the
source today and all six are still live. Where the queue disagreed with
the repository, the repository won; those cases are marked 🚩.

Ordered by what I think matters, not by age. Nothing here is started.

---

## A. HE ASKED FOR IT AND IT WAS NEVER BUILT

The class that matters most, because it is the one where the notes and
reality have already diverged once.

| # | What | Asked | Size |
|---|---|---|---|
| A1 | 🚩 **⇪T is missing from the Asana cheat-sheet card.** Marked ✅ in the queue with **no release number, and I can find no release that did it.** ⇪T *does* have its own card ("✅ TASK FORM (⇪T — labeled Asana task entry)"), so it is on the sheet — but the Asana card lists ⇪A ⇪B ⇪C ⇪L and never points at it, which is why he did not find it. | 2026-09-20 | Small |
| A2 | **Nothing names the @ searches.** There are fourteen (`clip cmd shots note asana ocr images doc file pad scratch vault web tool`) and they appear only as section headers in results. Fix at the point of use: typing `@` alone in ⇪D lists every source. | 2026-09-20 | Small |
| A3 | **⇪7's macOS line wants more detail.** Reads `macOS 27.0 (26A5388g)`. Marketing name, "BETA", Darwin version and install date are all readable with no binary. Decide what "more" means first. | 2026-09-20 | Small |
| A4 | **⌥Tab should list the music card.** Needs his call first: just the music card, or every panel this config draws? The card is the only one that keeps *playing* when it is not in front, which is the argument for doing it alone. | 2026-09-20 | Small, after his answer |
| A5 | **⌘Space as the ⇪space launcher.** Gated on `_G.groundReport()` saying ⌘Space is FREE on both Macs — he turns Spotlight's own shortcut off. | 6.198.0 | Small |
| A6 | **Date expansion** — `09-13-26` → `09-13-2026`, and with slashes. An autocorrect rule firing on the space after `MM-DD-YY` only. | 2026-09-13 | Small |
| A7 | **A copied snippet lands on the clipboard as the newest item** and pastes at the caret. | 2026-09-13 | Small |
| A8 | **A copied image is the first paste candidate** in the clipboard history. Read what clipboard_history does with images first — 6.190.0 sends them to OCR. | 2026-09-12 | Medium |
| A9 | **🖱 Click hints on ⇪X** (Chrome + Finder), grid as the fallback. `_G.groundReport()`'s "clicks" line already measures the cost per app. | Long-standing | Medium |
| A10 | **💾 The draft keeper** — a floppy beside a text field with no save, watching the typing. The least scoped of his asks and the only one that watches him type: which fields, where the draft goes, how it comes back. | 2026-09-12 | Large, needs scoping |
| A11 | **🟥 Doubled word flagged.** Detection is free; the pink underline needs `AXBoundsForRange`, which answers **per app** — `_G.groundReport()` from Chrome, Asana and Mail decides whether it is an underline or an alert there. **One open question for him:** is the alert enough where the underline cannot be drawn, or silence? | 2026-09-14 | Medium |
| A12 | **🔄 Asana auto-refresh every 15 minutes.** His draft steals focus twice a quarter-hour and posts ⌘R through our own taps. The design that costs nothing is `app:selectMenuItem({"View","Reload"})`, which reaches the app without activating it — but whether Asana *has* that menu decides the release. Ask for `hs.inspect(hs.application.get("Asana"):getMenuItems())` first. | 2026-09-20 | Small, after the artefact |
| A13 | **A public, sanitised config** for GitHub. Waiting on his strings list ("I will after you build"). | 2026-09-12 | Medium |

---

## B. BLOCKED ON AN ANSWER FROM HIM

Building either way risks building the wrong thing.

- **B1 — "Scratch" is still on screen (asked twice).** The note list's own
  header still reads 📝 SCRATCH NOTES. The ask under the ask is a *data*
  decision, not a rename: a scratch tab lives in `scratch.json` and only
  becomes a `.md` on ⌘⇧S, so "everything a Hamsidian entry" means deciding
  when a tab becomes a file.
  **(a)** every tab is a file from birth — one list, searchable at once;
  costs a OneDrive write per throwaway and a filename the moment it exists.
  **(b)** a tab stays a tab until ⌘⇧S — only the header changes, and two
  sections remain, which is the thing he is objecting to.
  *My recommendation if he does not answer:* (a), with the file written on
  the first **pause** and auto-named from the first line.
- **B2 — The screenshot editor's pixel readout.** "Kinda worked once then
  stopped. I don't see the pixel size." Two opposite fixes ("macOS's
  crosshair, so no box" vs "our selector drew and the readout did not") and
  his `routes` line separates them. **This is the one of his six I did not
  build, deliberately.** 6.282.0 is what finally makes that line readable.
- **B3 — The Obsidian wording.** Four visible strings still tell him to use
  Obsidian. Nothing here launches or requires it; it is a file-format
  lineage. Behaviour stays either way — only the wording is in question.
- **B4 — OCR tier 2** (`lUE`, `ido`, `dic`, `characters1` → `character 1`).
  Not built on his own bound: if the method can introduce errors, singles
  only. Needs his word.
- **B5 — The screenshots folder override.** Waiting on him to name a path;
  then one settings line, zero code.
- **B6 — Canvas (JSON Canvas / Obsidian).** Architecture settled — write the
  open `.canvas` format so the same file opens in Obsidian. Open question:
  is v1 a read/arrange surface, or also an authoring one (edges, embeds)?
  The second is the expensive half.

---

## C. KNOWN DEFECTS, NAMED AND DEFERRED

**Every one of these was re-checked in the source today. All six are
still live.** They are small, and each is the kind of thing that costs a
release when it finally bites.

| # | Defect | Verified |
|---|---|---|
| C1 | The screenshot editor's ⌘⏎ writes `<name> (edited).png` into the watched folder and **never claims it in `shots.own`** — so every save of an un-named shot is one more OCR. 6.281.0's tried-set bounds it; the unclaimed write is still a bug, and it is one line. | `shots.own` appears **0 times** in screenshot_editor.lua |
| C2 | `nameByText`'s task has **no killer timer** — a hung `shortcuts` leaves `nameBusy` true and the OCR queue never drains again. | no `nameTimeout` in screenshots.lua |
| C3 | `screenshots.watchFolder = false` stops the loop but **not the FSEvents wake-up**: the pathwatcher is created in `setup()` and profile settings land after. The module has **no `M.warm`**. | confirmed, 0 hits |
| C4 | `window_move.wm.enabled` has the identical shape and is **decorative** for the same reason — named in 6.228.0 and still unfixed. | no `M.warm` in window_move.lua |
| C5 | `anchors.grepTimeout` is **a knob nobody reads**, so a hung vault grep is unbounded where the osascript read is not. | 1 hit — the definition only |
| C6 | `text_expander.lua:717` and `url_cleaner.lua:404/425` still read **two values** from a `pcall` around `hs.pasteboard.setContents`, which returns `false` on refusal rather than throwing — so a refused write reads as success. 6.198.0 named both and deliberately did not sweep them. | both confirmed live |
| C7 | `vault.lua`'s scan `finish()` nils all four task slots **from inside a task callback** — 6.196.1's use-after-free shape. Its chain is otherwise safe (every task has its own slot), which is why it was left. | named 6.262.0 |
| C8 | ⌥Tab's Chrome tab scan: `osascript exited 15` is **our own 6 s kill of a blocked script**. Check Automation permission before any code. | diagnosed, unfixed |

---

## D. OPEN DIAGNOSES — instrument shipped, cause still unnamed

These need **his report**, not more code. Each has a working instrument now.

- **D1 — ⇪4 intermittent.** 6.274.0 counts the routes apart; 6.282.0 stopped
  the report throwing, which had made that test un-runnable since it
  shipped. Needs `_G.screenshotsReport()` + `_G.alertReport()` after a day.
- **D2 — ⇪⇧V's edit window brings Finder and Chrome forward, and the pointer
  jumps between monitors.** Read as one mechanism (the caret chase fighting
  the chooser's focus restore, amplified by mouse_follows warping the
  pointer on every app switch). **One-keystroke experiment decides it:**
  `_G.mouseFollows.stop()`, then edit a clipboard entry again.
- **D3 — Trackpad hypersensitive.** Nothing here posts or scales a
  mouse-move. The test that separates us from macOS 27 beta is doing it
  with Hammerspoon *quit*.
- **D4 — Did 6.276.0–6.280.0 ever reach `~/.hammerspoon`?** His boot-cost CSV
  has no row for any of them, which may be a delivery failure rather than a
  bug. `sed -n 7p ~/.hammerspoon/init.lua` **in Terminal** answers it.
- **D5 — The work Mac's `_G.stormReport()`** — owed since 6.214.2.

---

## E. DEBT THIS BATCH CREATED, STATED RATHER THAN HIDDEN

- **E1 — ⌃⌃ is not on the shared double-tap engine.** 6.292.0 lifted the
  engine into `core/double_tap.lua` and put ⌘⌘ and ⌥⌥ on it, but
  editor_picker keeps its own copy **on purpose**: its tap is the one that
  watches keyDown globally, and a mistake there takes the keyboard rather
  than breaking a feature. Until it migrates there are two copies of the
  rule and two taps on flagsChanged. `_G.doubleTapReport()` prints this on
  its last line so it cannot be forgotten. **Migrate once 6.292.0 has run
  on his Mac for a while.**
- **E2 — The stub-fidelity audit is static.** It reads source; it cannot run
  macOS. Eight further contracts are listed as data and printed on every
  run rather than implied by silence — `keyStrokes` posts (6.218.0),
  webview has no drop target (6.233.0), a throw in a dragging callback is
  silence (6.235.0), Finder hands over an inode (6.237.0), `focus()` must
  move the focus (6.251.0), a canvas can refuse to show (6.265.0), a tap
  can refuse to start (6.289.0), `setContents` may need `changeCount`
  beside it (6.201.0).
- **E3 — A sweep of the config's other sentries** for the shape the audit
  found in itself: a sentry whose needle exists only on the sentry's own
  line, so it matches itself and can never fail. One was found today; I
  have not looked for others.

---

## F. HOUSEKEEPING

- **F1** — The verify blocks before 6.269.0 are still prose rather than
  numbered steps. A bulk rewrite of 1,451 lines nobody is about to run
  proves nothing; they get the treatment when a release touches them.
- **F2** — `_G.todayReport()`'s failure log is not yet a ⇪D source. One
  `uni.sources` row.
- **F3** — The editor's own drags (Spotlight veil, oval, highlighter) have
  no size readout. The three pure functions are `shots.*` and published
  nowhere, so that release either lifts them into a service or writes the
  editor's own.
- **F4** — Fourteen other panels go through `_G.showCanvasSafely` and none
  asks to be told when macOS refuses (6.266.0's `onLate`). They can no
  longer orphan anything; a refused panel simply does not open.
- **F5** — An app outside doc_memory's ten (Sublime, a browser) is still
  named by its window title. That is the honest answer — AXDocument is all
  there is and those apps do not give one.
