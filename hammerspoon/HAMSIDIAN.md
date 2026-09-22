---
tags: hamsidian, howto
status: doing
---

# Hamsidian — how it works

One window. Two doors.

- **⇪3** opens it on your last **note**.
- **⇪N** opens the same window on your **scratch tabs**.

Same window, same keys. Only where it lands differs.

The notes are plain `.md` files in `<OneDrive>/Vault`. **The folder IS the
database.** No index file, no sidecar. Obsidian opens the same folder and
sees the same notes.

---

## 1. The left column

Three sections, top to bottom.

### 📝 SCRATCH NOTES — tabs, not files

Live text. Held in a JSON store, **not** as `.md` files. These are the
**Hamsidian tabs** — the same window, the other kind of writing (6.253.0
renamed them; they were the Scorp Pad).

| Row | What it is |
|---|---|
| `Scratch 1` | A plain tab. Type in it. Saved 0.3 s after you stop. |
| `+ new tab ⌘T` | Makes another plain tab. |
| `+ 🗒 Capture` | A tab that, when you **⌘W** it, queues its text for the 4 PM Asana send. |
| `+ ➕ Append` | A tab that files line-by-line when you ⌘W it. |

**Append line prefixes**, one entry per line:

```
* an idea          → ideas.txt + a notes.csv row
+ a log line       → logs
! do this thing    → an Asana TASK
? some note        → an Asana note
plain text         → a log
```

Tab keys: **⌘T** new · **⌘W** close (and file) · **⌘1**–**⌘9** jump to
the Nth · **⌃Tab** / **⌃⇧Tab** cycle.

**⌘⇧S** writes every tab out as a real `.md` note in `<Vault>/Scratch`.
Re-exporting the same tab updates its file — it does not duplicate.

### 🕸 NOTES — the `.md` files

Every note in the vault. This is where `09-07-2026`, `danh`, `slapjacks`,
`TODOO`, `yooooooooooooo` came from — see §7.

| Row | What it does |
|---|---|
| `+ new note ⌘N` | Names a note in a bar at the top of this window, then creates and opens it. |
| any name | Click it, or walk to it and ⏎. |

### 🏷 TAGS

Every tag in the vault with a count. `#project · 2` means two notes carry
that tag. **Click it** and the notes list narrows to those two. Type `#`
alone in the filter box to list every tag.

### The filter box

`filter notes… ⌘F` at the very top. **⌘F** or **⌘O** puts the caret in it
and selects what is there.

🚨 **In the notes list, ⏎ on text that matches nothing CREATES a note
with that name.** That is the one thing to know about this box, and it is
where your junk notes came from.

---

## 2. Notes that link to each other

Type `[[` — a picker opens on your note names. Pick one, or type a new
name.

```
See [[09-15-26 blenjab]] for the numbers.
```

- **⌘⏎** with the caret on a link → opens that note. If no file exists,
  it is created at that moment.
- `[[Name|what you want it to say]]` — an alias.
- `[[Name#Heading]]` — a spot inside it.
- **BACKLINKS** in the right pane lists every note pointing at this one.
- **UNLINKED MENTIONS** (`≈`) lists notes that say this name in plain text
  without linking it.
- **⌘G** — the graph. Every note a dot, every link a line. Click a dot to
  open it, drag to untangle. ⌘G again to come back.
- **⌘K** — link a file from anywhere in OneDrive. Lands as a relative
  Markdown link; ⌘⏎ opens the file itself.

---

## 3. Tags

Two ways to tag, and they are the same tag.

**Inline**, anywhere in the text:

```
Ordered the parts today. #project #acd
```

**Front matter**, and it must start on **LINE 1** of the note:

```
---
tags: project, acd
status: doing
---
```

Nested tags work: `#acd/policies` files under `acd`.

**To create a new tag: type it.** There is no list to add to. `#budget`
typed once in one note is a tag with a count of 1 the next time the list
redraws.

---

## 4. Front matter is where fields live

Anything above the first `---` is a field.

```
---
status: doing
owner: Lee
due: 2026-09-30
tags: project
---
```

Those fields are what queries filter on and what the **board** groups by.
Rules worth knowing:

- Line 1 or it is not front matter.
- A note **without** a field never matches a comparison, and sorts **last**
  — missing is missing, never zero.
- Numbers compare as numbers (so `10` sorts above `3`, not under it).

---

## 5. Live queries — a list that keeps itself right

Press **`/`** on an empty line → pick **Query**. Or type it:

````
```dataview
LIST
FROM #project
WHERE status != "done"
SORT name ASC
LIMIT 20
```
````

The answer is drawn in the **🔎 QUERY** box in the right pane. It is
**never written into your note** — the note keeps just the four lines you
typed.

| Clause | Takes |
|---|---|
| `LIST` / `TABLE a, b` | shape; TABLE adds columns off the front matter |
| `FROM` | `#tag` · `[[Note]]` (notes linking TO it) · `"Folder"` · `AND` `OR` `-` |
| `WHERE` | `field`, `= != > < >= <=`, `contains(f,"x")`, `AND` `OR` `!` |
| `SORT` | `name` · `path` · any field · `ASC` / `DESC` |
| `LIMIT` | a number |

`file.name`, `file.path`, `file.folder` and `tags` ask about the file
itself. A clause it does not understand is **named in the pane** and the
rest of the query still runs.

---

## 6. 🗂 The board — and your columns question

**⌘⇧B** shows it. **⌘⇧B** again goes back to the note.

**The columns ARE the values of one front-matter field.** Nothing else.
That is the whole model.

Right now every note of yours has no `status:` line, so there is exactly
one column — `no status` — with all 11 cards in it. That is not a bug; it
is the picture of a vault with no statuses in it yet.

### Make columns, way 1 — give a note a status

Open `TODOO`. Put this at the very top, line 1:

```
---
status: doing
---
```

**⌘⇧B.** There is now a `doing` column with that card in it, and a
`no status` column with the other ten.

Do it again on another note with `status: done` and you have three
columns. **The column exists because a note has that value.**

### Make columns, way 2 — declare them, so they are there to drag into

In any note, press **`/`** → **Board**. It writes this, caret sitting right
after `FROM #`:

````
```kanban
BY status
FROM #project
COLUMNS todo, doing, done
SORT name
```
````

Type your tag where the caret is — or **delete the `FROM #` line** to take
every note in the vault.

- `BY` names the field. It does not have to be `status` — `BY stage`,
  `BY priority`, `BY owner` all work.
- `COLUMNS` fixes the **order**, and draws them **even when empty** — so
  there is somewhere to drag a card on day one.
- A value `COLUMNS` does not name still gets a column, after them.
  Nothing ever vanishes.
- Eight columns are drawn; the rest fold into "… N more".

### Dragging

**This is the one view in Hamsidian that writes.** Drag a card to another
column and that note's `status:` line is rewritten on disk. The note you
have open is not touched.

Drag a card to the last column (`no status`) and the field is **removed**
from the note.

If a write is refused, the card goes back where it was and the reason is
alerted, printed, and counted on `_G.vaultReport()`'s `board :` line. The
card never moves without the file moving.

---

## 7. Your junk notes

`09-07-2026` · `1.` · `11-09-2026` · `2026-09-07` · `danh` · `slapjacks` ·
`tinoyab` · `TODOO` · `yooooooooooooo` · `⌘⇧B, open a note, drag a card…`

Every one of those is a **real `.md` file** in `<OneDrive>/Vault`. They
were made by typing into the filter box and pressing ⏎ (§1).

🚨 **Hamsidian cannot delete or rename a note.** That is deliberate, not an
oversight — this tool never removes your files. Delete them in **Finder**
or in **Obsidian**, in `<OneDrive>/Vault`. They disappear from the list at
the next rescan (or `_G.vaultRescan()` in the Console).

---

## 7b. 🔗 Linking to things OUTSIDE Hamsidian

Notes link to each other with `[[double brackets]]` (§2). This section is
the other direction: linking a note to a **document, a screenshot, a
browser tab or a file in OneDrive**.

There are two doors, and they do different jobs.

---

### ⇪⇧U — "link what I am looking at RIGHT NOW to a note"

Use this when the thing is already open in front of you. You do not have
to find it, name it, or know where it lives.

**How to use it, step by step:**

1. Put the thing in front. A Word document, an Excel sheet, a PDF in
   Preview, a Chrome tab — anything.
2. Press **⇪⇧U**.
3. The panel's title names what it found:
   - `🔗 document: Strategies of the Directors.docx` — it read the file
     the app has open.
   - `🔗 tab: <the page title>` — it read the browser's front tab.
   - `🔗 app: Transmission  (no document or tab — the app only)` — that
     app has no document to name. **This is correct, not a failure.**
4. Any note that **already** links this thing is listed at the top.
   Press ⏎ on one to open it in Hamsidian.
5. Otherwise pick one of the two bottom rows:
   - **⌘1 — ➕ New note: `<name>`** — makes a note named after the thing
     and writes the link into it.
   - **⌘2 — 📁 Link it into an existing note…** — a picker of all your
     notes; choose one and the link is written there.

**What it actually writes** — plain Markdown, under a `## Linked`
heading, at the top of that section:

```markdown
## Linked
- [Strategies of the Directors.docx](file:///Users/leeleblanc/Library/CloudStorage/OneDrive-Personal/Docs/Strategies%20of%20the%20Directors.docx)
- [Q4 planning board](https://app.asana.com/0/12345/67890)
```

Nothing proprietary, no database, no sidecar file. Any Markdown editor
opens those links, and so does ⌘⏎ inside Hamsidian.

**Linking the same thing twice** is one line, not two — press ⇪⇧U again
on the same document and it says *"Already in `<note>`"*.

**🚚 If the file later moves or is renamed**, ⌘⏎ on that link asks the ⇪D
file index for the same filename and opens it where it is now, saying
*"🕸 Moved — opening …"*. If it cannot find it, it says the link is
broken rather than opening the wrong thing.

---

### ⌘K — "link a file I have to go and find"

Use this when the file is **not** open — an old screenshot, a
spreadsheet three folders deep, a PDF somebody sent you.

1. Open Hamsidian (**⇪3**) and put the caret where you want the link.
2. Press **⌘K** (or click the 📎 button).
3. A file picker opens, **starting in your OneDrive folder**.
4. Pick a file. A Markdown link is written **at the caret**, relative to
   the note.

Because it is written relative to the note, the pair keeps working if you
move the whole Vault folder to another Mac — which is the reason it is
relative rather than absolute.

---

### 📸 Linking a screenshot

Screenshots land in your OneDrive screenshots folder, so all three of
these work:

**The one I would use** — you took it a moment ago:
1. ⇪3 to open Hamsidian, caret where you want it.
2. ⌘K, navigate to the screenshots folder, pick the file.

**If the screenshot is open in Preview:** put Preview in front and press
**⇪⇧U**. It names the file and offers to write the link.

**If you cannot remember which screenshot it was:** press **⇪space** and
type `@images`. Every screenshot this config has ever read text out of is
there, searchable **by the words inside the picture**, with a thumbnail.
⌥⏎ opens the file; then use ⇪⇧U on it, or note the name and use ⌘K.

> ⚠️ **A link is a link, not a copy.** The note points at the file where
> it lives. Move the file out of OneDrive and the link goes looking for
> it (see 🚚 above); delete the file and the link is dead. If you want the
> picture *inside* the note, that is a different thing and Hamsidian does
> not do it yet — say the word and it is a release.

---

### Which door, in one line

| You are… | Use |
|---|---|
| looking at the thing right now | **⇪⇧U** |
| writing a note and need to point at a file | **⌘K** |
| pointing at another note | `[[double brackets]]` |
| pointing at a screenshot you cannot name | **⇪space** `@images`, then ⇪⇧U or ⌘K |

---

## 8. The rest, briefly

| Key | What |
|---|---|
| **⌘D** | Today's daily note (`Daily/YYYY-MM-DD.md`) |
| **⌘⇧[** / **⌘⇧]** | The day before / after |
| **⌘⇧N** | New note from a template (`Templates/*.md`) |
| **⌘⇧T** | Insert a template at the caret |
| **⌘⇧F** | Search **inside** every note — `words`, `"a phrase"`, `tag:x`, `path:x`. ⏎ opens at that line. Esc back. |
| **⌘⇧K** | Every open `- [ ]` task in the vault; ⏎ opens it where it lives |
| **⌘L** | Tick / untick the task on this line |
| **⌘⇧E** | Turn the selection into a new note, leaving `[[Name]]` behind |
| **⌘⇧R** | Open a random note |
| **⌘B** / **⌘I** / **⌘E** | Bold · italic · code (they unwrap again) |
| **`/`** | On an empty line: the block menu — headings, lists, tasks, quote, divider, code, query, board |
| **↑ ↓ ⏎** | Walk the list. From inside the text: **⌥↑ ⌥↓ ⌥⏎** |
| **📌** | Pin: the window stays up beside the app; Esc only hands the keys back |
| **Esc** | Search or task view → back to notes. Again → closes the window. |

Templates understand `{{title}}`, `{{date}}`, `{{time}}`, `{{date:FMT}}`
and `{{cursor}}`.

Console: `_G.vaultReport()` · `_G.vaultRescan()` · `_G.scorpPadReport()`

---

## 9. A test run — do these in order

Twenty minutes, every feature touched. Where a step fails, note the number
and the exact words of any alert.

**Scratch tabs**

1. **⇪N** — the window opens on your tabs.
2. **⌘T** — a new tab. Type `hello`. Wait two seconds.
3. **⌃Tab**, **⌃Tab** — it cycles. **⌘1** — first tab.
4. Click **`+ ➕ Append`**. Type these three lines:
   ```
   * an idea I had
   ! call the vendor
   a plain log line
   ```
   **⌘W**. The idea, the task and the log each file to their own place.
5. **⌘⇧S** — every tab lands in `<Vault>/Scratch` as `.md`. Check the
   NOTES section: they are there.

**Notes and links**

6. **⇪3** — the notes side.
7. **⌘N**, name it `Tutorial A`, ⏎.
8. Type: `This links to [[Tutorial B]].` — pick or type the name in the
   picker.
9. Caret on the link, **⌘⏎** — `Tutorial B` is created and opens.
10. In `Tutorial B` type `Back to Tutorial A` — no brackets.
11. Open `Tutorial A`. Right pane: **BACKLINKS** shows nothing yet;
    **UNLINKED MENTIONS** shows `Tutorial B`. That is the difference.
12. **⌘G** — the graph. Your two dots have a line between them. Click one.
    **⌘G** back.

**Tags**

13. In `Tutorial A`, type `#tutorial` on its own line.
14. Left column, 🏷 TAGS: `#tutorial · 1`. Click it — the list narrows.
15. Clear the filter box. Type `#` alone — every tag you have.

**Fields and the board**

16. In `Tutorial A`, go to line 1 and put this above everything:
    ```
    ---
    status: doing
    ---
    ```
17. Do the same in `Tutorial B` with `status: todo`.
18. **⌘⇧B** — three columns: `doing`, `todo`, `no status` (with your
    other eleven notes in the last one).
19. **Drag `Tutorial B` from `todo` into `doing`.** ⌘⇧B back, open
    `Tutorial B` — its `status:` line now reads `doing`. **On disk.**
20. Drag it into `no status` — the `status:` line is **gone** from the
    file.

**Queries**

21. In `Tutorial A`, on an empty line press **`/`**, pick **Query**.
22. Make it read:
    ````
    ```dataview
    LIST
    FROM #tutorial
    ```
    ````
23. Right pane, **🔎 QUERY**: `Tutorial A`. Add `#tutorial` to
    `Tutorial B` and it appears there too. **Nothing was written into
    your note** — check the text, it is still four lines.

**Search, tasks, templates**

24. **⌘⇧F**, type `vendor` — the line from step 4 (if it landed in a
    note). ⏎ opens at that line. Esc back.
25. In `Tutorial A` type `- [ ] finish the tutorial`. **⌘⇧K** — it is in
    the list. Esc back, caret on the line, **⌘L** — it ticks.
26. **⌘⇧R** — a random note. **⌘D** — today's daily note. **⌘⇧[** —
    yesterday's.

**Housekeeping**

27. In Finder, open `<OneDrive>/Vault` and delete `danh`, `slapjacks`,
    `tinoyab`, `yooooooooooooo`, `1.` and `TODOO.md` if you do not want
    them. Console: `_G.vaultRescan()`. They are gone from the list.
28. Console: `_G.vaultReport()` — paste it if anything above misbehaved.
    Its `board :`, `fields :` and `notes :` lines name what this window
    could and could not read.
