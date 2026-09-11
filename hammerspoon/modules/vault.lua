-- =====================================================================
-- 🕸 VAULT — ⇪3: LINKED MARKDOWN NOTES IN ONEDRIVE, WITH A GRAPH
-- =====================================================================
-- 6.172.0 — LL: "I'd like to try for an Obsidian-like note taking app …
-- build into this tool so that the ideas can be turned into writing and
-- link/reference the files in their OneDrive location … run both on my
-- work mac and my personal mac using onedrive as the repository … a
-- deeply interconnected, text-based personal knowledge base stored
-- locally as future-proof plain text files … local Markdown (.md) files
-- in OneDrive. Bidirectional linking: typing [[Note Name]] instantly
-- creates a link between thoughts … Graph view … visualizes the web of
-- connections."
--
-- WHAT IT IS. A folder of plain .md files — <OneDrive>/Vault by default
-- (`settings = { vault = { dir = "…" } }` moves it) — and one window
-- over it on the Scorp Pad recipe (borderless webview, allowTextEntry,
-- read-back-verified non-activating mask, held usercontent port,
-- Lua-driven header drag). Left: every note, with a filter box. Middle:
-- the note's text. Right: LINKS OUT of this note and BACKLINKS into it.
-- ⌘G swaps the editor for the GRAPH: every note a dot, every [[link]]
-- a line, a force layout in the page's own canvas; click a dot to open
-- it, drag to untangle. A name you link to that has no file yet is a
-- hollow dot — ⌘⏎ on the link (or a click on the dot) creates it.
--
-- THE FOLDER IS THE DATABASE. Nothing here is stored anywhere but the
-- .md files themselves — no index file, no sidecar. That is what makes
-- it OBSIDIAN-COMPATIBLE: open the same folder in Obsidian ("Open folder
-- as vault") on either Mac and every note, link and backlink is there,
-- with Obsidian's plug-ins on top; Obsidian keeps its own settings in a
-- .obsidian/ subfolder, which this module ignores. OneDrive carries the
-- folder between the two Macs; this module never syncs anything itself.
--
-- LINKS. `[[Note Name]]` (and `[[Note Name|shown text]]`,
-- `[[Note#Heading]]`) is a link to <vault>/<Note Name>.md, found
-- case-insensitively anywhere under the vault. Typing `[[` pops a list
-- of note names to pick from (↑↓ ⏎ / Tab; Esc dismisses). ⌘⏎ with the
-- caret on a link follows it, creating the note if it is missing. A
-- FILE elsewhere in OneDrive is linked with ⌘K: a picker, then a
-- Markdown link `[name](../relative/path.pdf)` relative to the note —
-- the same relative link Obsidian writes, so it survives the different
-- home folder on the other Mac. ⌘⏎ on it opens the file in its app.
--
-- THE INDEX IS BUILT OFF THE MAIN THREAD. OneDrive keeps files as
-- placeholders until read, and a read of one that is not on this Mac
-- BLOCKS until it downloads (the Sep 6 Finder drag lag was VLC doing
-- exactly that). So the module never reads every note. Names come from
-- `/usr/bin/find` and links from `/usr/bin/grep -o '\[\[…\]\]'`, both
-- in hs.task (held), and their output is parsed in Lua. Only the note
-- you OPEN is read on the main thread — one file, at your request, the
-- way Obsidian would read it. Every save re-parses that one note's
-- links in Lua so the panes and graph are live without a rescan;
-- a rescan runs at open and every v.rescanEvery seconds while open.
--
-- WHERE THE TEXT LIVES. v.doc.text in Lua on EVERY keystroke (the page
-- posts the whole textarea, the pad's recipe); the .md file v.saveDelay
-- seconds after the last one (held doAfter, re-armed per key, tmp +
-- rename), and at once on switching notes, closing and reload. A failed
-- write is said once and retried on the next key; the text is never
-- only in the page.
--
-- 📝 THE SCORP PAD LIVES HERE TOO (6.173.0). LL: "Can I combine my
-- Scorp Pad and this Vault Pad?" ⇪1 and ⇪3 open this one window. The
-- note list starts with a 📝 SCRATCH section — every scratch tab
-- (Capture / Append tabs too), × to close one, + for a new one — and
-- the text box edits a tab exactly as it edits a note: every key lands
-- in scratch_pad's sp.tabs, its store 0.3 s later. With a tab open the
-- right pane shows its [[links]] and the HISTORY of closed tabs (click
-- to bring one back). ⌘T / ⌘W / ⌘1–9 / ⌃Tab work the tabs from
-- anywhere in the window; "→ Asana now" and the 4 PM task are the
-- pad's own, untouched. 📌 pins the window (Esc only hands the keys
-- back). scratch_pad keeps every brain; v.sp() is the only bridge, and
-- with `scratch_pad.viaVault = false` the pad's own window returns.
--
-- 🏷 6.174.0 — TAGS, TEMPLATES, SEARCH INSIDE NOTES, TASKS, MENTIONS.
-- LL wanted the rest of what a daily Obsidian user reaches for, without
-- giving up the one rule above (the folder is the database, nothing is
-- read that is not open). Every new key is a ⌘ key INSIDE the page —
-- no hyper key was spent. What arrived, in Obsidian's own grammar so a
-- user of both tools notices nothing: `#tag` anywhere (letters, digits,
-- _ - /, at least one non-digit; `#2024` is a number, `#y2024` a tag;
-- trailing punctuation dropped; `# Heading`, `[[Note#h]]` and a URL's
-- `#frag` are not tags) and `tags: a, b` / `tags: [a, b]` / a YAML
-- list in a note's front matter; nested `#a/b` counts under `#a` too.
-- Templates are the .md files in <vault>/Templates — ordinary notes,
-- listed under 📄 TEMPLATES, inserted at the caret (⌘⇧T) or used for a
-- new note (⌘⇧N) with Obsidian's core variables `{{title}}` `{{date}}`
-- `{{time}}` `{{date:FMT}}` (moment tokens, case-sensitive: MM month,
-- mm minute; `dd`/`d` alone are NOT supported — `D` is the day) and
-- Templater's `{{cursor}}` for the caret; Templater's `<% %>` is left
-- verbatim and said in the Console. ⌘D seeds a NEW daily note from
-- Templates/Daily.md when it exists (`{{title}}` = the date); ⌘⇧[ ⌘⇧]
-- step a day. ⌘⇧F searches every note's TEXT (words, "a phrase",
-- tag:x, path:x — every word required, plain text, no regex); ⌘⇧K
-- lists every open `- [ ]` task; ≈ UNLINKED MENTIONS names the notes
-- that say this note's name without linking it; ⌘⇧E extracts the
-- selection into a new note, leaving [[Name]] behind; ⌘⇧R opens a
-- random note.
--
-- HOW, WITHOUT READING THE VAULT. The scan became FOUR held tasks in a
-- chain: find (names) → grep links → grep `#tags` → grep front-matter
-- `tags:` lines (-m 1 -A 12). The two tag greps are OPTIONAL: a failure
-- warns and finishes the scan with the links intact, and a half-built
-- tag index is never assigned (the pending table lands only at the end
-- of the chain). Search, tasks and mentions are one held grep each
-- (`v.searchTask`, `v.tasksTask`, `v.mentionTask`); a superseded one is
-- terminated before its field is reused, and every callback begins with
-- a staleness guard (a sequence number, the query, the open note's key,
-- the mode), so a late answer can never overwrite newer state. A
-- template's body comes through `/bin/cat` in a held task with a held
-- 10 s timer that terminates it and says so — a OneDrive placeholder
-- would otherwise stall Hammerspoon on the main thread. Line targets
-- travel to the page as LINE NUMBERS and template carets as a HEAD
-- STRING, so no byte-vs-UTF-16 arithmetic crosses the bridge. The
-- vault-wide tag grep sees one line at a time and cannot tell a code
-- fence (the open note's own tags are exact, parsed in Lua).
--
-- 🔎 6.183.0 — LIVE QUERIES. LL: "I want to make notes clearly
-- meaningful and see the relationships to jog my memory." A ```dataview
-- block in a note LISTS the notes it describes, in a 🔎 QUERY section of
-- the right pane, redrawn 150 ms after a keystroke like the outline is.
-- The grammar is Obsidian's own Dataview — the useful corner of it — so
-- the SAME block renders in Obsidian if that plug-in is ever installed,
-- and reads as English either way:
--     LIST FROM #project AND -#done
--     SORT name
-- FROM takes `#tag` (a nested #a/b counts under #a), `[[Note]]` (the
-- notes that link TO it) and `"Folder"`, joined with AND / OR (AND binds
-- tighter, as in Dataview) and negated with `-` or `!`; SORT takes name
-- or path, ASC or DESC; LIMIT caps the rows. A template never appears in
-- a result — it is a stencil, not content. The "/" menu writes the whole
-- block with the caret on the tag, so the grammar never has to be typed,
-- and the footer names the line you are on.
--
-- 🔎 6.185.0 — WHERE, TABLE COLUMNS AND SORT OVER THE FRONT MATTER.
-- The front-matter grep in the scan chain used to ask for `^tags?:` and
-- read only that. It now asks for the opening `---` and reads the WHOLE
-- block (-A `fmLines`), so ONE grep builds both the tag index and
-- `v.fmOf` — every note's fields. Front matter must start at line 1 or
-- it is not front matter, which is stricter and more correct than the
-- line-2-to-60 guess it replaced. Bounded on purpose (`fmMaxFields`,
-- `fmMaxLen`) because the index lives in memory and rides into the page
-- on every render. `v.fmIn(text)` is the Lua twin for the OPEN note, so
-- its own fields are exact and live the way its tags are; tags are NOT
-- copied into the fields (they already travel as `g:`).
--     TABLE status, rating FROM #book
--     WHERE status != "done" AND rating >= 4
--     SORT rating DESC
-- WHERE takes `field` (has it), `field = "x"` / `!= > < >= <=`,
-- `contains(field, "x")`, AND / OR (AND tighter) and `!` to negate;
-- several WHERE lines are ANDed. A comparison is NUMERIC when both sides
-- are numbers, so 10 beats 3 rather than sorting under it. A note that
-- has not got the field never satisfies a comparison and sorts LAST — it
-- is missing, not zero. `file.name`, `file.path`, `file.folder` and
-- `tags` ask about the file itself. A TABLE's columns are drawn as a
-- second line under each name (the pane is narrow; a real grid there
-- would be unreadable) and `field AS Label` renames one.
-- `_G.vaultReport()`'s "fields :" line names what a query can ask about.
--
-- 🚨 NOTHING IS WRITTEN, AND NO NOTE IS READ. The answer is drawn BESIDE
-- the note, never into it: the file keeps only the text you typed, so it
-- cannot drift under you and Dataview cannot end up rendering a second
-- copy of a table this one already wrote. And the query itself runs in
-- the PAGE, off the note rows it already holds (name, path, tags,
-- 6.183.0's `l:` link keys and 6.185.0's `f:` fields) — no file read, no
-- extra grep, no scan, no message to Lua. IT DEGRADES: a clause it
-- cannot READ (a mistyped operator, a computed column) is NAMED in the
-- pane and the rest of the query still runs; a ```dataviewjs block is
-- refused by name and never executed; and a front-matter grep that
-- FAILED leaves the fields empty and says so on the report line rather
-- than reading as "this vault has no fields".
--
-- 🚨 WHAT THIS MODULE DELIBERATELY DOES NOT DO. No eventtap (the page's
-- own keydown handles ⌘N/⌘D/⌘G/⌘K/⌘⏎/Esc). No AX or hs.window read. No
-- timer that is not held. No read of a note that is not open. No read
-- of a template on the main thread. No write of any note but the open
-- one (a NEW note is created, never another rewritten — so no rename,
-- no link rewrite, no "link it" on a mention, no ticking a task that
-- lives in another note) — a query answer is drawn, never written. No `✅` stamps, no `📅` due dates (the Tasks
-- plug-in's syntax, not Obsidian's). No fence awareness in the
-- vault-wide grep. No file delete or rename — Finder and Obsidian do
-- those better. No Markdown preview. Without a webview it falls back to
-- hs.dialog and still saves.
-- =====================================================================

local M = {
    name    = "Vault",
    order   = 13.38,
    family  = "capture",
    summary = "⇪3 linked Markdown notes in OneDrive: [[wikilinks]], backlinks, "
              .. "a graph of the connections, Obsidian-compatible files, tags, templates, full-text search, tasks, "
              .. "live queries and a Kanban board you can drag cards on",
    cheatsheet = {
        title = "🕸 VAULT (⇪3 / ⇪1 — Markdown notes that link to each other, in OneDrive; the Scorp Pad's tabs too)",
        entries = {
            { "⇪3 · ⇪N",    "Open / close the window — ⇪3 on your last note, ⇪N on your scratch tabs" },
            { "📝 SCRATCH NOTES", "Top of the list: every scratch tab, plain or 🗒 Capture or ➕ Append · ⌘T new · the + rows make the other two · ⌘W close · ⌘1–9 · ⌃Tab · history on the right" },
            { "🕸 NOTES", "Under the scratch tabs: every .md note in the vault · the + new note row and ⌘N both name it in the window · typing a name and ⏎ creates it too" },
            { "[[",         "Type [[ and pick a note — [[Name]] links to Name.md, creating it on follow" },
            { "⌘⏎",         "Follow the link under the caret (a note, or a file link opens the file)" },
            { "⌘N · ⌘D",    "New note · today's daily note (Daily/YYYY-MM-DD.md, from Templates/Daily.md when it exists) · ⌘⇧[ ⌘⇧] the day before / after" },
            { "⌘G",         "Graph: every note a dot, every link a line; click a dot, drag to untangle" },
            { "⌘K",         "Link a file from anywhere in OneDrive (a relative Markdown link)" },
            -- 6.174.0
            { "⌘⇧N · ⌘⇧T",  "New note FROM a template · insert a template at the caret — Templates/*.md with {{title}} {{date}} {{time}} {{date:FMT}} {{cursor}}" },
            { "#tag",       "Type #word anywhere (or tags: a, b up top): 🏷 TAGS counts them, click one to filter, # in the box lists them all; chips on the right" },
            { "⌘⇧F",        "Search INSIDE every note — words, \"a phrase\", tag:x, path:x; rows are note · line · text, ⏎ opens at that line, Esc back" },
            { "⌘⇧K · ⌘L",   "Every open - [ ] task in the vault (⏎ opens it there) · tick / untick the task on this line; ⏎ continues a list" },
            { "OUTLINE · ≈", "Right pane: the note's headings (click to jump) · ≈ notes that mention this name without linking it" },
            -- 6.183.0 / 6.185.0 / 6.186.0
            { "```dataview", "A live list: LIST or TABLE, FROM #tag / [[note]] / \"Folder\", WHERE status != \"done\", SORT, LIMIT — drawn in 🔎 QUERY, never written into the note. \"/\" writes the block for you" },
            { "⌘⇧B",        "🗂 Board: your notes as Kanban columns, grouped by a front-matter field (```kanban BY status). DRAGGING A CARD REWRITES that note's status: line — the one view here that writes" },
            { "⌘⇧E · ⌘⇧R",  "Extract the selection into a new note, leaving [[Name]] behind · open a random note" },
            { "⌘⇧S",       "Export the Scorp Pad's tabs into <Vault>/Scratch as .md notes" },
            { "⌘F · ⌘O · ↑↓ ⏎", "Filter the list · walk it (⌥↑/⌥↓ ⌥⏎ from inside the text)" },
            { "📌",          "Pin: the window stays up beside the app; Esc only hands the keys back" },
            { "Obsidian",   "Open the same folder as a vault in Obsidian — plug-ins and all" },
            { "Console",    "_G.vaultReport() · _G.vaultRescan()" },
        },
    },
}

function M.setup(core)
    local v = {
        enabled       = true,
        key           = "3",
        -- 6.181.0 — BIGGER, because the text got smaller. LL asked for
        -- 13pt text "and increase the size of the pad to account for all
        -- text". Smaller glyphs in the same box would have been half the
        -- ask: the point is MORE text on screen at once, so the window
        -- grows with the type going down.
        width         = 1560,
        height        = 1010,
        -- 6.175.2 — SOLID, and back where it started. The window went
        -- 1 → 0.9 in 6.173.2 ("slightly less opaque"), 0.9 → 0.97 in
        -- 6.175.1 ("make the pad more opaque"), and then LL said "make
        -- it fully solid". Three readings of the same window, and the
        -- answer is that translucency was never worth anything here:
        -- this is a window you WRITE in. Any 0–1 number still works as
        -- a settings override for anyone who wants the old feel.
        -- 6.181.1 — 0.97. LL asked for "90% black", saw 0.9, and said
        -- "make it only 10% translucent, so much less transparent —
        -- still too see through". Those two numbers are the same number,
        -- which is the tell: what LL is judging is how much of the app
        -- BEHIND comes through, and over a bright window 0.9 shows a lot
        -- of it. So this is not a rounding of his words, it is the next
        -- step in the direction he pointed: 3% instead of 10%.
        -- This window has now been 1 → 0.9 → 0.97 → 1 → 0.9 → 0.97, and
        -- 6.175.1 was here before. If 0.97 still reads as see-through
        -- the answer is 1, and one word does it:
        --     settings = { vault = { alpha = 1 } }
        -- The GUARD is the durable part, not the number: at exactly 1
        -- the module must never call view:alpha() at all, and below 1 it
        -- must really set it. Both are asserted.
        alpha         = 0.97,
        fontSize      = 14,
        dir           = nil,          -- set below; a settings override replaces it
        dailyDir      = "Daily",      -- subfolder for ⌘D notes
        -- 6.203.0 — the longest a note NAME may be, in BYTES. macOS holds
        -- one path component to 255 bytes, and the longest component this
        -- module ever writes is "<name>.md.tmp" (saveNow writes the temp
        -- file beside the note and renames it), so the name itself gets
        -- 255 - 7 = 248. BYTES, not characters, because that is what the
        -- filesystem counts: one emoji is four of them, and a name cut to
        -- 248 CHARACTERS is a write that still fails.
        nameMaxBytes  = 248,
        saveDelay     = 0.3,
        rescanEvery   = 300,          -- seconds between background rescans while open
        maxNotes      = 5000,         -- rows embedded in the page
        maxLinkLines  = 40000,        -- grep lines parsed (past this the graph is partial and says so)
        focusOnOpen   = true,
        nonActivating = true,
        skipDirs      = { ".obsidian", ".trash", ".git" },
        FIND          = "/usr/bin/find",
        GREP          = "/usr/bin/grep",
        -- 6.174.0 — tags, templates, search, tasks, mentions (settings overrides land here)
        templatesDir    = "Templates",   -- subfolder of the vault; its .md files are the templates
        dailyTemplate   = "Daily",       -- Templates/<this>.md seeds a NEW daily note when it exists
        linkSection     = "## Linked",   -- 6.180.0 — where ⇪⇧U puts an anchor
        templateTimeout = 10,            -- seconds to wait for /bin/cat before giving up (OneDrive)
        searchDelay     = 0.3,           -- ⌘⇧F: seconds of silence before the grep runs
        searchMax       = 200,           -- rows kept from one search
        searchPerFile   = 20,            -- grep -m: lines kept per note
        tasksMax        = 300,           -- rows kept in the ☑ view
        mentionsMax     = 50,            -- ≈ rows under BACKLINKS
        mentionsMinLen  = 3,             -- a shorter name is not searched for
        tagRows         = 15,            -- 🏷 rows shown before "… N more"
        maxTagLines     = 40000,         -- like maxLinkLines, for the tag + frontmatter greps together
        -- 6.185.0 — a note's front matter is read for QUERY fields as well
        -- as tags. Bounded on purpose: the whole index lives in memory and
        -- travels into the page on every render, so a note with a hundred
        -- keys or a paragraph-long value cannot bloat either.
        fmLines         = 30,            -- grep -A: front-matter lines read per note
        fmMaxFields     = 16,            -- keys kept per note (the rest are dropped)
        fmMaxLen        = 120,           -- characters kept per value
        -- 6.186.0 — 🗂 BOARD. The one place in the vault where a rendered
        -- view WRITES: a card dragged to another column rewrites that
        -- note's front-matter field, one line, never the body. A board you
        -- cannot move a card on is a report, not a Kanban.
        boardField      = "status",      -- the field a ```kanban block groups by when it does not say
        boardCols       = 8,             -- columns drawn before the rest are folded into "… N more"
        boardMax        = 300,           -- cards drawn in total
        smartLists      = true,          -- ⏎ continues a list line (page-side)
        -- 6.175.0 — LL: "I don't write markdown. Are there tool tips or
        -- autocompletes that will teach and help me." The format bar
        -- above the text types the syntax and its tooltips name it;
        -- false hides the bar (⌘B, "/" and the footer hint stay).
        formatBar       = true,
        CAT             = "/bin/cat",    -- template bodies, off the main thread

        -- state
        notes = {}, byKey = {}, links = {}, backlinks = {}, unresolved = {},
        doc = nil, dirty = false, saves = 0, saveFails = 0, lastSaveErr = nil,
        webview = nil, uc = nil, saveTimer = nil, rescanTimer = nil,
        findTask = nil, grepTask = nil, scanning = false, scans = 0, lastScan = nil,
        scanErr = nil, linkLines = 0, partial = false,
        dragTimer = nil, dragOffset = nil, opens = 0,
        nonActivatingApplied = false, nonActivatingWhy = "not requested",
        caret = 0, filter = "", view = "edit", pos = nil, pinned = false,
        -- 6.174.0
        tags = {}, tagsOf = {}, tagList = {}, tagLines = 0, tagsPartial = false, tagTask = nil, fmTask = nil,
        -- 6.185.0 — front-matter FIELDS: rel → { key = value }, from the
        -- same grep the tags come from. fmFields is every key seen, by
        -- count then name, for the report and the query hints.
        fmOf = {}, fmFields = {}, fmPending = nil, fmErr = nil,
        -- 6.186.0
        moves = 0, moveFails = 0, lastMove = nil, moveErr = nil,
        mode = "notes",
        searchQuery = "", searchRows = {}, searchMore = false, searchTask = nil, searchTimer = nil, searchSeq = 0,
        searching = false, searchErr = nil, lastSearch = nil, searches = 0,
        taskRows = {}, taskMore = false, tasksTask = nil, tasksSeq = 0, tasksListing = false, tasksErr = nil, lastTasks = nil,
        unlinked = { key = nil, rels = {}, pending = false, why = nil, more = false }, mentionTask = nil, mentionSeq = 0,
        catTask = nil, catTimer = nil, tplSeq = 0,
        caretLine = nil, caretHead = nil, extracts = 0, randoms = 0,
    }
    M.config = v
    _G.vault = v

    if core.cloudDir then v.dir = core.cloudDir .. "/Vault"
    else v.dir = (core.logsDir or core.homeDir or ".") .. "/vault" end
    v.cloudDir = core.cloudDir

    local function say(m) if _G.diag and _G.diag.say then _G.diag.say("vault", m) end end
    local function warn(m) if _G.diag and _G.diag.warn then _G.diag.warn("vault", m) end end
    local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    local function escapeHtml(s)
        return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
    end
    local function jstr(s)
        s = tostring(s or "")
        s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", ""):gsub("</", "<\\/")
        return '"' .. s .. '"'
    end
    local function mkdirp(path)
        local acc = path:sub(1, 1) == "/" and "" or "."
        for part in path:gmatch("[^/]+") do
            acc = acc .. "/" .. part
            pcall(function() hs.fs.mkdir(acc) end)
        end
    end
    local function keyOf(name) return trim(name):lower() end
    local function alert(m, secs) pcall(function() hs.alert.show(m, secs or 2) end) end

    -- ---- 6.174.0 — the small shared pieces ------------------------------------
    -- Everything Lua says to the page without a rebuild goes through here
    -- (rows, mentions, hints) — a full render would wipe what LL is typing.
    function v.eval(js)
        if v.webview then pcall(function() v.webview:evaluateJavaScript(js) end) end
    end
    -- rows → a JS array literal, keys n r l x only, in that order (no JSON library).
    local function jarr(rows)
        local out = {}
        for _, r in ipairs(rows or {}) do
            local f = {}
            if r.n ~= nil then f[#f + 1] = "n:" .. jstr(r.n) end
            if r.r ~= nil then f[#f + 1] = "r:" .. jstr(r.r) end
            if r.l ~= nil then f[#f + 1] = "l:" .. tostring(math.floor(tonumber(r.l) or 0)) end
            if r.x ~= nil then f[#f + 1] = "x:" .. jstr(r.x) end
            out[#out + 1] = "{" .. table.concat(f, ",") .. "}"
        end
        return "[" .. table.concat(out, ",") .. "]"
    end
    -- an absolute path under the vault → its rel; anything else → nil
    local function relOf(path)
        path = tostring(path or "")
        if path:sub(1, #v.dir + 1) == v.dir .. "/" then return path:sub(#v.dir + 2) end
        return nil
    end
    -- the flags every NEW grep shares (the link grep keeps its own literal args)
    local function grepBase(flags)
        local args = { flags, "--include=*.md" }
        for _, d in ipairs(v.skipDirs) do args[#args + 1] = "--exclude-dir=" .. d end
        return args
    end
    -- A superseded task is terminated before its field is reused; a task
    -- that outlived its purpose (the window closed) the same way.
    -- 6.174.0 — A KILLED RUN EXITS TOO (the 6.148.0 lesson in
    -- chrome_history): terminate() still delivers the callback, with the
    -- signal's exit code. Every kill marks its task here, and the wrapper
    -- below drops that late answer — so closing the window mid-grep never
    -- writes "grep exited 15" into the report or the panes.
    local dead = setmetatable({}, { __mode = "k" })
    local function stopTask(field)
        if v[field] then
            dead[v[field]] = true
            pcall(function() v[field]:terminate() end); v[field] = nil
        end
    end
    -- One held hs.task on a named field. The callback clears the field
    -- (only if it is still ours) and never lets an error escape to the
    -- event loop.
    local function startTask(field, bin, args, cb)
        if not (hs.task and hs.task.new) then return false, "no hs.task" end
        local t
        local ok, made = pcall(hs.task.new, bin, function(...)
            if t and dead[t] then dead[t] = nil; return end   -- 6.174.0 — we killed it
            if v[field] == t then v[field] = nil end
            local okC, err = pcall(cb, ...)
            if not okC then warn(field .. ": " .. tostring(err)) end
        end, args)
        if not (ok and made) then return false, tostring(made) end
        t = made
        v[field] = t     -- HELD
        local okS, started = pcall(t.start, t)
        if not (okS and started) then v[field] = nil; return false, bin .. " would not start" end
        return true
    end

    -- ---- 6.173.0 — the Scorp Pad's tabs, shown and edited here ------------
    -- The pad module owns the tabs, the store, the history, the filing
    -- and the 4 PM task; this is the only way this module reaches them.
    function v.sp()
        local sp = _G.scratchPad
        if type(sp) == "table" and sp.viaVault ~= false and type(sp.tabs) == "table"
           and type(sp.setText) == "function" then return sp end
        return nil
    end
    local function scratchRel(id) return "scratch:" .. tostring(id) end

    -- Make a scratch tab the open document. nil = the pad's active tab
    -- (a blank one is made if there are none).
    function v.openScratch(id)
        local sp = v.sp()
        if not sp then return false, "the Scorp Pad is not loaded" end
        if v.doc and v.dirty then v.saveNow() end
        local t = id and sp.findTab(tostring(id)) or nil
        if not t then t = sp.activeTab() end
        if not t then t = sp.newTab("") end
        if not t then return false, "no tab" end
        sp.active = t.id
        v.doc = { scratch = t.id, name = sp.titleOf(t), rel = scratchRel(t.id), text = tostring(t.text or ""),
                  kind = t.kind }
        v.dirty = false
        v.caret = #v.doc.text
        v.view = "edit"
        say("scratch tab " .. tostring(t.id))
        return true
    end
    function v.showScratch(id)
        local ok, why = v.openScratch(id)
        if not ok then return false, why end
        if v.webview then v.render() else v.open() end
        return true
    end
    -- ⇪1: closed → open on the tabs; open on a note → jump to the tabs;
    -- open on a tab → close (the pad's open/close feel).
    function v.toggleScratch()
        if v.webview and v.doc and v.doc.scratch then v.hide() return true end
        return v.showScratch(nil)
    end

    -- ---- names and paths -----------------------------------------------------
    -- A note is known by its file name without .md, case-insensitively.
    -- `rel` is the path under the vault; `path` is absolute.
    function v.noteFromRel(rel)
        local name = rel:match("([^/]+)%.md$") or rel
        return { name = name, rel = rel, path = v.dir .. "/" .. rel, key = keyOf(name) }
    end
    function v.find(name) return v.byKey[keyOf(name)] end

    -- [[Target|alias]] / [[Target#Heading]] → "Target"
    function v.linkTarget(inner)
        inner = tostring(inner or ""):gsub("|.*$", ""):gsub("#.*$", "")
        return trim(inner)
    end
    -- every [[link]] target in a text, deduplicated, in order
    function v.linksIn(text)
        local seen, out = {}, {}
        for inner in tostring(text or ""):gmatch("%[%[([^%]]+)%]%]") do
            local t = v.linkTarget(inner)
            if t ~= "" and not seen[keyOf(t)] then seen[keyOf(t)] = true; out[#out + 1] = t end
        end
        return out
    end

    local function safeName(name)
        name = trim(name):gsub("[/\\:]", "-"):gsub("%.md$", "")
        return name
    end

    -- 6.174.0 — a name that a [[link]] must address: linkTarget stops at
    -- "|" and "#", and linksIn's own match stops at "]". A note called
    -- "Fix #42" would be created, linked, and never found again — Obsidian
    -- refuses the same characters in a file name.
    local function linkSafe(name)
        return trim((safeName(name):gsub("[%[%]|#%^]", " "):gsub("%s+", " ")))
    end

    -- 6.203.0 — 🚨 A NAME THAT CANNOT BECOME A FILE IS REFUSED, AND THE
    -- REFUSAL IS SHOWN WHERE LL IS LOOKING. He pasted a whole block into
    -- ⌘N's "Name of the note" bar. safeName took it — it only maps "/"
    -- ":" "\\" and strips a trailing .md, and has never had a length —
    -- openNote "created" the note in memory and returned TRUE, and
    -- saveNow then failed on a path macOS cannot hold:
    --     🚨 Write failed: vault note Collect
    --     cannot open …/Vault/Collect<thousands of characters>.md
    -- Nothing was written. And he saw NOTHING: saveNow's hs.alert draws
    -- at the alert level, this window is at bringToFront(true), so the
    -- one message that existed was BEHIND the window he was typing in.
    -- LL: "I enter a title and … I don't see that anything was created."
    --
    -- Returns name, why:
    --   name ~= ""  → usable; why is nil, or a sentence if it was cleaned
    --   name == ""  → REFUSED; why says so in words LL can act on
    -- PURE — no file, no window, no clock — so the gate proves every rule
    -- here with no Mac, which is what safeName's missing length never was.
    --
    -- It REFUSES an over-long name rather than TRUNCATING it. A 3,000
    -- character paste clamped to 248 is a note named after its own first
    -- paragraph, silently, which is not what anyone asked for — and the
    -- paste is only safe while it is still in the box he can copy it from.
    function v.nameCheck(typed)
        local raw = tostring(typed or "")
        -- newlines, tabs and every other control character become spaces.
        -- A file name may legally hold them, which is the trap: the note
        -- would be created and then be untypeable and unlinkable for ever.
        local flat, ctrl = raw:gsub("%c", " ")
        local name = trim((safeName(flat):gsub("%s+", " ")))
        name = trim((name:gsub("^%.+", "")))   -- a leading dot hides it from find
        if name == "" then
            if trim(raw) == "" then return "", "a note needs a name" end
            return "", "there is nothing usable in that name"
        end
        local max = tonumber(v.nameMaxBytes) or 248
        if #name > max then
            -- say it in the unit LL can count, and in bytes too when the
            -- two differ — "247 characters is too long for 248" reads as
            -- a lie to anyone whose note name has an emoji in it
            local chars = utf8 and utf8.len and utf8.len(name) or nil
            local how = (chars and chars ~= #name)
                        and (chars .. " characters (" .. #name .. " bytes)")
                        or (#name .. " characters")
            return "", "that name is " .. how .. " long — a file name holds " .. max
                       .. ". Shorten it, or press esc and paste it into the note itself."
        end
        if ctrl > 0 then return name, "the line breaks became spaces" end
        return name
    end

    -- ---- 6.174.0 — templates: the .md files under <vault>/Templates ----------
    local function isTemplateRel(rel)
        local td = v.templatesDir
        if type(td) ~= "string" or td == "" then return false end
        return tostring(rel or ""):lower():sub(1, #td + 1) == td:lower() .. "/"
    end
    v.isTemplateRel = isTemplateRel
    -- the template records, from the name index (no file is read)
    function v.templates()
        local out = {}
        for _, n in ipairs(v.notes) do if isTemplateRel(n.rel) then out[#out + 1] = n end end
        return out
    end
    function v.templatesJson()
        local rows = {}
        for _, n in ipairs(v.templates()) do rows[#rows + 1] = "{n:" .. jstr(n.name) .. ",r:" .. jstr(n.rel) .. "}" end
        return "[" .. table.concat(rows, ",") .. "]"
    end
    -- By REL under Templates/ only — a root note named "Daily" never
    -- shadows Templates/Daily.md (and is never read for it).
    function v.templateByName(name)
        local td = v.templatesDir
        if type(td) ~= "string" or td == "" then return nil end
        local want = td:lower() .. "/" .. safeName(name):lower() .. ".md"
        for _, n in ipairs(v.notes) do if n.rel:lower() == want then return n end end
        return nil
    end
    -- Daily/YYYY-MM-DD.md → that day at noon (DST-safe); anything else → nil
    function v.dailyEpochOf(rel)
        local dd = tostring(v.dailyDir or ""):lower()
        rel = tostring(rel or ""):lower()
        if dd == "" or rel:sub(1, #dd + 1) ~= dd .. "/" then return nil end
        local y, m, d = rel:sub(#dd + 2):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%.md$")
        if not y then return nil end
        return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    end
    function v.dayOf(rel)
        local e = v.dailyEpochOf(rel)
        return e and os.date("%Y-%m-%d", e) or nil
    end

    -- ---- 6.174.0 — tags: Obsidian's grammar, validated in Lua ------------------
    -- (the grep only finds the wide shape `#[^space#]+`; Lua decides)
    function v.tagOk(s)
        s = tostring(s or ""):gsub("[%.,;:!%?%)%]}'\"/]+$", "")
        if s == "" then return nil end
        if not s:match("^[%w_/%-\128-\255]+$") then return nil end
        if not s:find("[^%d]") then return nil end
        return s
    end
    local function collectTag(list, seen, cand)
        local t = v.tagOk(cand)
        if t and not seen[t:lower()] then seen[t:lower()] = true; list[#list + 1] = t end
    end
    -- a front-matter value: quotes and a leading # off, then the grammar
    local function fmValue(raw)
        raw = trim(raw):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
        raw = trim(raw):gsub("^#", "")
        return trim(raw)
    end
    local function fmInlineValues(list, seen, value)
        value = trim(value)
        if value == "" then return end
        local items = {}
        if value:sub(1, 1) == "[" then
            for item in value:gsub("^%[", ""):gsub("%]$", ""):gmatch("[^,]+") do items[#items + 1] = item end
        else
            for item in value:gmatch("[^,%s]+") do items[#items + 1] = item end
        end
        for _, item in ipairs(items) do collectTag(list, seen, fmValue(item)) end
    end
    -- every tag in a text: the front-matter forms (F2) then #tags in the
    -- body outside ``` / ~~~ fences; display case, deduped by lowercase
    function v.tagsIn(text)
        text = tostring(text or "")
        local list, seen = {}, {}
        local lines = {}
        for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = (line:gsub("\r$", "")) end
        local i = 1
        if lines[1] == "---" then
            i = 2
            local inList, fm, fmSeen = false, {}, {}
            while lines[i] and lines[i] ~= "---" do
                local value = lines[i]:match("^tags?:%s*(.*)$")
                if value then
                    fmInlineValues(fm, fmSeen, value); inList = true
                else
                    local item = inList and lines[i]:match("^%s*%-%s+(.+)$")
                    if item then collectTag(fm, fmSeen, fmValue(item)) else inList = false end
                end
                i = i + 1
            end
            if lines[i] == "---" then
                for _, t in ipairs(fm) do collectTag(list, seen, t) end
                i = i + 1
            else i = 2 end   -- no closing ---: not front matter, the lines are body
        end
        local inFence = false
        while lines[i] do
            local line = lines[i]
            if line:match("^%s*```") or line:match("^%s*~~~") then inFence = not inFence
            elseif not inFence then
                for cand in (" " .. line):gmatch("%s#([^%s#]+)") do collectTag(list, seen, cand) end
            end
            i = i + 1
        end
        return list
    end
    -- open task lines of a text: `- [ ] x`, `* [ ] x`, `+ [ ] x`, `1. [ ] x`
    function v.tasksIn(text)
        local out, n = {}, 0
        for line in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            local x = line:match("^%s*[%-%*%+]%s+%[ %]%s?(.*)$") or line:match("^%s*%d+%.%s+%[ %]%s?(.*)$")
            if x then out[#out + 1] = { line = n, text = (x:gsub("\r$", "")) } end
        end
        return out
    end

    -- ---- 6.174.0 — search: Obsidian's query grammar (F5) --------------------------
    -- terms (every one required), "a phrase", tag:x, path:x / file:x
    function v.searchTerms(q)
        q = tostring(q or ""):gsub("[\r\n]", " ")
        local T = { terms = {}, tag = nil, path = nil }
        local i, n = 1, #q
        while i <= n do
            local c = q:sub(i, i)
            if c:match("%s") then i = i + 1
            elseif c == '"' then
                local j = q:find('"', i + 1, true)
                local tok = q:sub(i + 1, (j or (n + 1)) - 1)
                if trim(tok) ~= "" then T.terms[#T.terms + 1] = tok end
                i = (j or n) + 1
            else
                local tok = q:match("^%S+", i)
                local op, val = tok:match("^(%a+):(.*)$")
                if op == "tag" and val ~= "" then T.tag = val:gsub("^#", ""):lower()
                elseif (op == "path" or op == "file") and val ~= "" then T.path = val:lower()
                else T.terms[#T.terms + 1] = tok end
                i = i + #tok
            end
        end
        return T
    end
    -- the line trimmed, a window of ≤120 bytes starting ≤30 before the term,
    -- never cut inside a UTF-8 sequence, … where it was cut
    local function cutSnippet(text, term)
        text = trim(text)
        local at = term ~= "" and text:lower():find(term:lower(), 1, true) or nil
        local start = 1
        if at and at > 31 then
            start = at - 30
            while start > 1 and text:byte(start) >= 128 and text:byte(start) < 192 do start = start - 1 end
        end
        local cut = text:sub(start, start + 119)
        if utf8.len(cut) == nil then cut = cut:gsub("[\192-\255][\128-\191]*$", "") end
        if start > 1 then cut = "…" .. cut end
        if start + 119 < #text then cut = cut .. "…" end
        return cut
    end
    v.cutSnippet = cutSnippet

    -- ---- 6.174.0 — the template engine (Obsidian core variables, F7) -----------
    -- moment tokens, longest first at each position; [literal] copied
    -- without the brackets; anything else (dd, d, Q, -, :) copies through.
    local MOMENT = {
        { "YYYY", "%Y" }, { "MMMM", "%B" }, { "dddd", "%A" }, { "YY", "%y" }, { "MMM", "%b" }, { "ddd", "%a" },
        { "DD", "%d" }, { "HH", "%H" }, { "hh", "%I" }, { "MM", "%m" }, { "mm", "%M" }, { "ss", "%S" },
        { "D", "%d", true }, { "M", "%m", true }, { "H", "%H", true }, { "h", "%I", true }, { "m", "%M", true }, { "s", "%S", true },
        { "A", "%p", "upper" }, { "a", "%p", "lower" },
    }
    function v.momentFormat(fmt, when)
        fmt, when = tostring(fmt or ""), when or os.time()
        local out, i, n = {}, 1, #fmt
        while i <= n do
            local c = fmt:sub(i, i)
            if c == "[" then
                local j = fmt:find("]", i + 1, true)
                if j then out[#out + 1] = fmt:sub(i + 1, j - 1); i = j + 1
                else out[#out + 1] = fmt:sub(i); i = n + 1 end
            else
                local hit = nil
                for _, tk in ipairs(MOMENT) do
                    if fmt:sub(i, i + #tk[1] - 1) == tk[1] then hit = tk break end
                end
                if hit then
                    local s = os.date(hit[2], when)
                    if hit[3] == true then s = tostring(tonumber(s) or s)
                    elseif hit[3] == "upper" then s = s:upper()
                    elseif hit[3] == "lower" then s = s:lower() end
                    out[#out + 1] = s
                    i = i + #hit[1]
                else
                    out[#out + 1] = c; i = i + 1
                end
            end
        end
        return table.concat(out)
    end
    -- {{title}} {{date}} {{time}} {{date:FMT}} {{time:FMT}} {{cursor}}; any
    -- other {{x}} and an unclosed {{ stay literal. Hand scanner, output by
    -- table.concat — a % in the template or a value is never a pattern.
    -- Returns the filled text and the byte offset of the FIRST {{cursor}}.
    function v.fillTemplate(text, ctx)
        text, ctx = tostring(text or ""), ctx or {}
        local when = ctx.when or os.time()
        if text:find("<%", 1, true) then
            print("📄 Vault: Templater syntax (<% … %>) left as-is in " .. (ctx.name or "the template") .. " — it runs only in Obsidian")
        end
        local out, len, caret, pos = {}, 0, nil, 1
        local function put(s) out[#out + 1] = s; len = len + #s end
        while true do
            local i = text:find("{{", pos, true)
            if not i then put(text:sub(pos)) break end
            local j = text:find("}}", i + 2, true)
            if not j then put(text:sub(pos)) break end
            local k = text:find("{{", i + 2, true)
            if k and k < j then put(text:sub(pos, k - 1)); pos = k
            else
                put(text:sub(pos, i - 1))
                local inner = text:sub(i + 2, j - 1)
                local key, fmt = inner:match("^%s*(%a+)%s*:%s*(.-)%s*$")
                if not key then key, fmt = trim(inner), nil end
                if fmt == "" then fmt = nil end
                if key == "title" then put(tostring(ctx.title or ""))
                elseif key == "date" then put(fmt and v.momentFormat(fmt, when) or os.date("%Y-%m-%d", when))
                elseif key == "time" then put(fmt and v.momentFormat(fmt, when) or os.date("%H:%M", when))
                elseif key == "cursor" then if not caret then caret = len end
                else put(text:sub(i, j + 1)) end
                pos = j + 2
            end
        end
        return table.concat(out), caret
    end

    -- ---- the index ---------------------------------------------------------------
    local function rebuildBacklinks()
        v.backlinks, v.unresolved = {}, {}
        for rel, targets in pairs(v.links) do
            for _, t in ipairs(targets) do
                local k = keyOf(t)
                if v.byKey[k] then
                    v.backlinks[k] = v.backlinks[k] or {}
                    table.insert(v.backlinks[k], rel)
                else
                    v.unresolved[k] = v.unresolved[k] or { name = t, from = {} }
                    table.insert(v.unresolved[k].from, rel)
                end
            end
        end
        for _, list in pairs(v.backlinks) do table.sort(list) end
    end

    -- 6.174.0 — v.tagsOf (rel → display tags) → v.tags (key → name, rels,
    -- count; a nested #a/b/c also counts under a/b and a) and v.tagList
    -- (by count, then name). Memory only; the folder is still the database.
    local rebuildFields   -- 6.185.0 — declared here, defined below; the
                          -- field index is refreshed wherever the tag index is
    local function rebuildTags()
        local tags, rels = {}, {}
        for rel in pairs(v.tagsOf) do rels[#rels + 1] = rel end
        table.sort(rels)
        local function add(key, name, rel)
            local e = tags[key]
            if not e then e = { name = name, rels = {}, seen = {}, count = 0 }; tags[key] = e end
            if not e.seen[rel] then e.seen[rel] = true; e.rels[#e.rels + 1] = rel; e.count = e.count + 1 end
        end
        for _, rel in ipairs(rels) do
            for _, t in ipairs(v.tagsOf[rel]) do add(t:lower(), t, rel) end
        end
        for _, rel in ipairs(rels) do
            for _, t in ipairs(v.tagsOf[rel]) do
                local parent = t:match("^(.*)/[^/]+$")
                while parent and parent ~= "" do
                    add(parent:lower(), parent, rel)
                    parent = parent:match("^(.*)/[^/]+$")
                end
            end
        end
        local list = {}
        for key, e in pairs(tags) do
            e.seen = nil
            table.sort(e.rels)
            list[#list + 1] = { key = key, name = e.name, count = e.count }
        end
        table.sort(list, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.key < b.key end)
        v.tags, v.tagList = tags, list
    end
    v.rebuildTags = rebuildTags
    function v.tagsJson()
        local rows = {}
        for _, t in ipairs(v.tagList) do
            rows[#rows + 1] = "{k:" .. jstr(t.key) .. ",n:" .. jstr(t.name) .. ",c:" .. tostring(t.count) .. "}"
        end
        return "[" .. table.concat(rows, ",") .. "]"
    end

    function v.setNotes(rels)
        local notes, byKey = {}, {}
        for _, rel in ipairs(rels) do
            if #notes >= v.maxNotes then v.partial = true break end
            local n = v.noteFromRel(rel)
            if not byKey[n.key] then notes[#notes + 1] = n; byKey[n.key] = n end
        end
        table.sort(notes, function(a, b) return a.key < b.key end)
        v.notes, v.byKey = notes, byKey
        -- links (and 6.174.0: tags) of notes that vanished go with them
        local have = {}
        for _, n in ipairs(notes) do have[n.rel] = true end
        for rel in pairs(v.links) do if not have[rel] then v.links[rel] = nil end end
        for rel in pairs(v.tagsOf) do if not have[rel] then v.tagsOf[rel] = nil end end
        rebuildBacklinks()
        rebuildTags()
        rebuildFields()
    end

    -- "path:[[Target|x]]" lines from grep → v.links
    function v.setLinkLines(out)
        local links, count = {}, 0
        for line in tostring(out or ""):gmatch("[^\n]+") do
            count = count + 1
            if count > v.maxLinkLines then v.partial = true break end
            local path, inner = line:match("^(.-):%[%[(.-)%]%]$")
            if path and inner then
                local rel = relOf(path) or path
                local t = v.linkTarget(inner)
                if t ~= "" then
                    links[rel] = links[rel] or {}
                    local dup = false
                    for _, x in ipairs(links[rel]) do if keyOf(x) == keyOf(t) then dup = true break end end
                    if not dup then table.insert(links[rel], t) end
                end
            end
        end
        v.linkLines = count
        -- the open note's own links are always the live ones
        if v.doc and not v.doc.scratch then links[v.doc.rel] = v.linksIn(v.doc.text) end
        v.links = links
        rebuildBacklinks()
    end

    -- 6.174.0 — "path: #tag" / "path:#tag" lines from the tag grep (-o) →
    -- a PENDING rel → tags table. It becomes v.tagsOf only at the end of
    -- the chain (assignTags), so a failed later step never leaves half an
    -- index. Lines over maxTagLines are dropped and said in the report.
    local function addTag(inline, rel, cand)
        local t = v.tagOk(cand)
        if not t then return end
        inline[rel] = inline[rel] or {}
        for _, x in ipairs(inline[rel]) do if x:lower() == t:lower() then return end end
        table.insert(inline[rel], t)
    end
    function v.setTagLines(out)
        local inline, count = {}, 0
        v.tagsPartial = false
        for line in tostring(out or ""):gmatch("[^\n]+") do
            count = count + 1
            if count > v.maxTagLines then v.tagsPartial = true break end
            local path, rest = line:match("^(.-):(%s?#[^%s#]+)$")
            local rel = path and relOf(path)
            if rel then addTag(inline, rel, rest:match("^%s?#(.+)$")) end
        end
        v.tagLines = count
        return inline
    end
    -- 6.185.0 — ONE PASS OVER THE FRONT MATTER, TWO ANSWERS.
    -- Until 6.184.0 this grep asked for `^tags?:` and read only that. It
    -- now asks for the opening `---` and reads the WHOLE block, so the
    -- same task that builds the tag index also builds v.fmOf — the
    -- fields a ```dataview WHERE and a TABLE's columns need. No second
    -- grep, no second pass over the vault, and no note is read.
    --
    -- Lines from `grep -rHnIE -m 1 -A <fmLines> -e "^---[[:space:]]*$"`:
    --   "path:1:---"        opens a block — ONLY at line 1, which is the
    --                       one place Markdown front matter can begin
    --   "path-N-key: value" a field
    --   "path-N-  - item"   another item of the field above it
    --   "path-N----"        the closing --- ends the block
    -- Anything else, "--", or another path closes it. Without -A (no
    -- context lines) nothing is read and nothing breaks — the fields are
    -- simply absent and the pane says so.
    -- A LIST becomes its items joined with ", ", so `contains(genre, "x")`
    -- works on it the way it works on a plain string.
    local function fmPut(fm, rel, key, value)
        key = tostring(key or ""):lower()
        -- tags already travel to the page as g:[…]; a second copy in the
        -- fields would be payload for nothing
        if key == "" or key == "tag" or key == "tags" then return end
        fm[rel] = fm[rel] or {}
        local t = fm[rel]
        if t[key] == nil then
            local n = 0
            for _ in pairs(t) do n = n + 1 end
            if n >= (tonumber(v.fmMaxFields) or 16) then return end
        end
        value = tostring(value or "")
        local cap = tonumber(v.fmMaxLen) or 120
        if #value > cap then value = value:sub(1, cap) end
        t[key] = value
    end
    function v.setFrontmatterLines(out, inline)
        inline = inline or {}
        local fm = {}
        local cur, curRel, open, lastKey, list = nil, nil, false, nil, nil
        local count = v.tagLines or 0
        local function flush()
            if curRel and lastKey and list and #list > 0 then
                fmPut(fm, curRel, lastKey, table.concat(list, ", "))
            end
            lastKey, list = nil, nil
        end
        local function close() flush(); cur, curRel, open = nil, nil, false end
        for line in tostring(out or ""):gmatch("[^\n]+") do
            count = count + 1
            if count > v.maxTagLines then v.tagsPartial = true break end
            local path, n = line:match("^(.-):(%d+):%-%-%-%s*$")
            if path then
                close()
                local rel = relOf(path)
                -- front matter starts at line 1 or it is not front matter;
                -- a --- further down is a divider in someone's prose
                if rel and tonumber(n) == 1 then cur, curRel, open = path, rel, true end
            elseif open and cur and line:sub(1, #cur + 1) == cur .. "-" then
                local body = line:sub(#cur + 2):match("^%d+%-(.*)$")
                if body == nil then close()
                elseif body:match("^%-%-%-%s*$") then close()
                else
                    local item = body:match("^%s+%-%s+(.+)$")
                    if item and lastKey then
                        list = list or {}
                        local val = fmValue(item)
                        list[#list + 1] = val
                        if lastKey == "tag" or lastKey == "tags" then addTag(inline, curRel, val) end
                    else
                        local key, value = body:match("^([%w_][%w_%-%.]*):%s*(.*)$")
                        if key then
                            flush()
                            lastKey = key:lower()
                            if lastKey == "tag" or lastKey == "tags" then
                                local got, seen = {}, {}
                                fmInlineValues(got, seen, value)
                                for _, t in ipairs(got) do addTag(inline, curRel, t) end
                            end
                            local plain = fmValue(value)
                            if plain ~= "" then fmPut(fm, curRel, lastKey, plain); lastKey, list = lastKey, nil
                            else list = {} end
                        else
                            flush()
                        end
                    end
                end
            else
                close()
            end
        end
        close()
        v.tagLines = count
        v.fmPending = fm
        return inline
    end
    -- every front-matter field of ONE text, parsed in Lua — the open note's
    -- own fields are exact and live, the way its tags are
    function v.fmIn(text)
        local lines = {}
        for line in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = (line:gsub("\r$", "")) end
        if lines[1] ~= "---" then return {} end
        local fm, rel = {}, "_"
        local i, lastKey, list = 2, nil, nil
        local function flush()
            if lastKey and list and #list > 0 then fmPut(fm, rel, lastKey, table.concat(list, ", ")) end
            lastKey, list = nil, nil
        end
        while lines[i] and lines[i] ~= "---" do
            local item = lines[i]:match("^%s+%-%s+(.+)$")
            if item and lastKey then
                list = list or {}; list[#list + 1] = fmValue(item)
            else
                local key, value = lines[i]:match("^([%w_][%w_%-%.]*):%s*(.*)$")
                if key then
                    flush()
                    lastKey = key:lower()
                    local plain = fmValue(value)
                    if plain ~= "" then fmPut(fm, rel, lastKey, plain); list = nil
                    else list = {} end
                else flush() end
            end
            i = i + 1
        end
        if lines[i] ~= "---" then return {} end   -- no closing ---: not front matter
        flush()
        return fm[rel] or {}
    end
    -- v.fmOf → v.fmFields (name, count), by count then name — what the
    -- report prints and what a query can actually ask about
    function rebuildFields()
        local seen, list = {}, {}
        for _, t in pairs(v.fmOf) do
            for k in pairs(t) do
                if not seen[k] then seen[k] = { name = k, count = 0 }; list[#list + 1] = seen[k] end
                seen[k].count = seen[k].count + 1
            end
        end
        table.sort(list, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.name < b.name
        end)
        v.fmFields = list
    end
    -- the end of the chain: the open note is reinstated live, then the
    -- pending tables ARE the index. `fm` is nil when the front-matter grep
    -- never answered — the fields go EMPTY rather than stale, and the
    -- pane says the fields are unavailable instead of quietly lying.
    local function assignTags(inline, fm)
        if v.doc and not v.doc.scratch then inline[v.doc.rel] = v.tagsIn(v.doc.text) end
        v.tagsOf = inline
        v.fmOf = fm or {}
        if v.doc and not v.doc.scratch then v.fmOf[v.doc.rel] = v.fmIn(v.doc.text) end
        rebuildTags()
        rebuildFields()
    end

    -- Four hs.tasks, held, one after the other (6.174.0: the two tag greps
    -- joined find and the link grep). Nothing on the main thread touches
    -- a note file here — that is the whole point (see the header).
    function v.scan(reason)
        if v.scanning then return false, "already scanning" end
        if not (hs.task and hs.task.new) then v.scanErr = "no hs.task"; return false, v.scanErr end
        mkdirp(v.dir)
        v.scanning, v.partial = true, false
        local prune = {}
        for _, d in ipairs(v.skipDirs) do
            prune[#prune + 1] = "-name"; prune[#prune + 1] = d
            prune[#prune + 1] = "-o"
        end
        prune[#prune] = nil
        local findArgs = { v.dir, "(", "-type", "d", "(" }
        for _, a in ipairs(prune) do findArgs[#findArgs + 1] = a end
        for _, a in ipairs({ ")", "-prune", ")", "-o", "-type", "f", "-name", "*.md", "-print" }) do
            findArgs[#findArgs + 1] = a
        end
        local function finish(err)
            v.scanning, v.findTask, v.grepTask, v.tagTask, v.fmTask = false, nil, nil, nil, nil
            v.scanErr, v.lastScan, v.scans = err, os.time(), v.scans + 1
            if err then warn("scan: " .. err)
            else say("scan: " .. #v.notes .. " notes, " .. v.linkLines .. " link lines, " .. #v.tagList .. " tags (" .. tostring(reason) .. ")") end
            if v.webview then v.render() end
        end
        -- 6.174.0 — the tag half of the chain. OPTIONAL: any failure here
        -- warns, keeps what exists and finishes the scan with the links
        -- intact. Exit 1 is "no match", a clean empty answer.
        local function tagsFailed(what, inline)
            warn("tags: " .. what)
            v.fmErr, v.fmPending = what, nil
            if inline then assignTags(inline, nil) end
            finish(nil)
        end
        local function scanTags()
            local tagArgs = grepBase("-rHoIE")
            for _, a in ipairs({ "-e", "(^|[[:space:]])#[^[:space:]#]+", v.dir }) do tagArgs[#tagArgs + 1] = a end
            local okT, tt = pcall(hs.task.new, v.GREP, function(tcode, tout, terr)
                if tcode ~= 0 and tcode ~= 1 then tagsFailed("grep exited " .. tostring(tcode) .. ": " .. trim(terr or "")) return end
                local inline = v.setTagLines(tout)
                local fmArgs = grepBase("-rHnIE")
                -- 6.185.0 — the WHOLE front-matter block, not just its tags line
                for _, a in ipairs({ "-m", "1", "-A", tostring(math.floor(tonumber(v.fmLines) or 30)),
                                     "-e", "^---[[:space:]]*$", v.dir }) do fmArgs[#fmArgs + 1] = a end
                local okF2, ft2 = pcall(hs.task.new, v.GREP, function(fcode, fout, ferr)
                    if fcode ~= 0 and fcode ~= 1 then tagsFailed("frontmatter grep exited " .. tostring(fcode) .. ": " .. trim(ferr or ""), inline) return end
                    v.fmPending, v.fmErr = nil, nil
                    v.setFrontmatterLines(fout, inline)
                    assignTags(inline, v.fmPending)
                    v.fmPending = nil
                    finish(nil)
                end, fmArgs)
                if not (okF2 and ft2) then tagsFailed("frontmatter grep task: " .. tostring(ft2), inline) return end
                v.fmTask = ft2     -- HELD
                local okS2, started2 = pcall(function() return ft2:start() end)
                if not okS2 or started2 == false then v.fmTask = nil; tagsFailed("frontmatter grep would not start", inline) end
            end, tagArgs)
            if not (okT and tt) then tagsFailed("grep task: " .. tostring(tt)) return end
            v.tagTask = tt     -- HELD
            local okS, started = pcall(function() return tt:start() end)
            if not okS or started == false then v.tagTask = nil; tagsFailed("grep would not start") end
        end
        local okF, ft = pcall(hs.task.new, v.FIND, function(code, out, serr)
            local rels = {}
            for line in tostring(out or ""):gmatch("[^\n]+") do
                local rel = relOf(line)
                if rel then rels[#rels + 1] = rel end
            end
            v.setNotes(rels)
            if code ~= 0 and #rels == 0 then finish("find exited " .. tostring(code) .. ": " .. trim(serr or "")) return end
            local grepArgs = { "-rHo", "--include=*.md" }
            for _, d in ipairs(v.skipDirs) do grepArgs[#grepArgs + 1] = "--exclude-dir=" .. d end
            grepArgs[#grepArgs + 1] = "-e"; grepArgs[#grepArgs + 1] = "\\[\\[[^]]*\\]\\]"
            grepArgs[#grepArgs + 1] = v.dir
            local okG, gt = pcall(hs.task.new, v.GREP, function(gcode, gout, gerr)
                -- grep exits 1 when nothing matched: a vault with no links yet
                if gcode ~= 0 and gcode ~= 1 then finish("grep exited " .. tostring(gcode) .. ": " .. trim(gerr or "")) return end
                v.setLinkLines(gout)
                scanTags()     -- 6.174.0 — the links are in; the tags follow, optional
            end, grepArgs)
            if not (okG and gt) then finish("grep task: " .. tostring(gt)) return end
            v.grepTask = gt     -- HELD
            local okS = pcall(function() return gt:start() end)
            if not okS then finish("grep would not start") end
        end, findArgs)
        if not (okF and ft) then v.scanning = false; v.scanErr = "find task: " .. tostring(ft); return false, v.scanErr end
        v.findTask = ft         -- HELD
        local okS, started = pcall(function() return ft:start() end)
        if not okS or started == false then v.scanning = false; v.findTask = nil; v.scanErr = "find would not start"; return false, v.scanErr end
        return true
    end

    -- ---- the open note -----------------------------------------------------------
    local function readFile(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local s = f:read("a") or f:read("*a") or ""
        f:close()
        return s
    end

    function v.saveNow()
        if v.saveTimer then pcall(function() v.saveTimer:stop() end); v.saveTimer = nil end
        local d = v.doc
        if not d then return true end
        if d.scratch then v.dirty = false; return true end     -- the pad's store, on the pad's timer
        local function failed(why)
            v.lastSaveErr = why
            v.saveFails = v.saveFails + 1
            if core.warnWriteFailed then core.warnWriteFailed("vault note " .. d.name) end
            if not v.saveErrSaid then
                v.saveErrSaid = true
                pcall(function() hs.alert.show("🕸 NOT SAVED — " .. why .. "\nYour text is safe in memory; every keystroke retries.", 5) end)
                print("🕸 Vault: note not written — " .. why .. " (" .. d.path .. ")")
            end
            return false
        end
        mkdirp(d.path:match("^(.*)/[^/]*$") or v.dir)
        local tmp = d.path .. ".tmp"
        local f = io.open(tmp, "w")
        if not f then return failed("cannot open " .. tmp) end
        local okW = f:write(d.text or "")
        f:close()
        if not okW then return failed("write failed") end
        if not os.rename(tmp, d.path) then return failed("rename failed") end
        if v.saveErrSaid then v.saveErrSaid = false; pcall(function() hs.alert.show("🕸 Saving again", 2) end) end
        v.dirty, v.lastSaveErr = false, nil
        v.saves = v.saves + 1
        -- a note that did not exist until now joins the index
        if not v.byKey[d.key] then
            local rels = {}
            for _, n in ipairs(v.notes) do rels[#rels + 1] = n.rel end
            rels[#rels + 1] = d.rel
            v.setNotes(rels)
        end
        v.links[d.rel] = v.linksIn(d.text)
        rebuildBacklinks()
        v.tagsOf[d.rel] = v.tagsIn(d.text)     -- 6.174.0
        v.fmOf[d.rel]   = v.fmIn(d.text)       -- 6.185.0 — its fields too
        rebuildTags()
        rebuildFields()
        v.refreshOpenTasks()
        return true
    end

    function v.scheduleSave()
        if v.saveTimer then pcall(function() v.saveTimer:stop() end) end
        local ok, t = pcall(hs.timer.doAfter, v.saveDelay, function() v.saveTimer = nil; v.saveNow() end)
        v.saveTimer = ok and t or nil     -- HELD
    end

    function v.setText(text)
        if not v.doc then return end
        text = tostring(text or "")
        if v.doc.scratch then
            -- a tab: the pad's copy is the truth, its 0.3 s timer writes the store
            local sp = v.sp()
            if sp and text ~= v.doc.text then sp.setText(v.doc.scratch, text) end
            v.doc.text = text
            return
        end
        if text ~= v.doc.text then
            v.doc.text = text
            v.dirty = true
            v.links[v.doc.rel] = v.linksIn(text)
            v.tagsOf[v.doc.rel] = v.tagsIn(text)     -- 6.174.0 — the open note's tags are live too
            v.fmOf[v.doc.rel]   = v.fmIn(text)       -- 6.185.0 — and its fields, per key
            v.scheduleSave()
        end
    end

    -- ---- 6.186.0 — writing ONE front-matter field ---------------------------
    -- 🚨 This is the only place the vault rewrites a note it is not editing,
    -- and it is deliberate: a Kanban board you cannot move a card on is a
    -- report. The blast radius is one line of one file. withField is PURE —
    -- text in, text out — so every shape it must survive (no front matter, a
    -- block with the key, a block without it, a `---` that is really a
    -- divider) is provable without a disk.
    local function fmQuote(value)
        value = tostring(value or ""):gsub("[\r\n]", " ")
        value = value:gsub("^%s+", ""):gsub("%s+$", "")
        local cap = tonumber(v.fmMaxLen) or 120
        if #value > cap then value = value:sub(1, cap) end
        -- a plain word needs no quotes; anything YAML would read as
        -- structure gets them, and fmValue strips them again on the way back
        if value == "" then return "" end
        if value:find('^[%w][%w%s%-_%./]*$') then return value end
        return '"' .. value:gsub('"', '\\"') .. '"'
    end
    -- Set (or, with an empty value, REMOVE) one key in `text`'s front matter.
    -- Returns the new text. Everything else in the file is byte-identical.
    function v.withField(text, key, value)
        text = tostring(text or "")
        key = tostring(key or ""):lower()
        if not key:find("^[%w_][%w_%-%.]*$") then return text end
        local nl = text:find("\r\n") and "\r\n" or "\n"
        -- split so that a text ending in a newline does NOT gain a phantom
        -- empty line (that is one newline added to the file per drag), and a
        -- text that does not end in one does not lose its last line
        local ending = text:sub(-1) == "\n"
        local lines, body = {}, ending and text:sub(1, -2) or text
        for line in (body .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = (line:gsub("\r$", "")) end
        local quoted = fmQuote(value)
        if lines[1] ~= "---" then
            -- no front matter at all. Removing a field it has not got changes
            -- nothing — never write a block just to delete from it.
            if quoted == "" then return text end
            return "---" .. nl .. key .. ": " .. quoted .. nl .. "---" .. nl .. nl .. text
        end
        local close = nil
        for i = 2, #lines do if lines[i] == "---" then close = i break end end
        if not close then return text end          -- an opening --- with no closing one is not front matter
        local at = nil
        for i = 2, close - 1 do
            local k = lines[i]:match("^([%w_][%w_%-%.]*):")
            if k and k:lower() == key then at = i break end
        end
        if quoted == "" then
            if not at then return text end
            -- drop the key AND the indented list items that belong to it
            local last = at
            while lines[last + 1] and last + 1 < close and lines[last + 1]:find("^%s+%-%s") do last = last + 1 end
            for _ = at, last do table.remove(lines, at) end
            close = close - (last - at + 1)
            if close == 2 then                      -- nothing left: the block goes too
                table.remove(lines, 1); table.remove(lines, 1)
                while lines[1] == "" do table.remove(lines, 1) end
            end
        elseif at then
            local last = at
            while lines[last + 1] and last + 1 < close and lines[last + 1]:find("^%s+%-%s") do last = last + 1 end
            for _ = at + 1, last do table.remove(lines, at + 1) end
            lines[at] = key .. ": " .. quoted
        else
            table.insert(lines, close, key .. ": " .. quoted)
        end
        local out = table.concat(lines, nl)
        if ending then out = out .. nl end
        return out
    end

    -- One field, one note, named by its rel. The note may be the open one
    -- (then it goes through setText and the editor stays true), any indexed
    -- note (read, rewrite, atomic rename — the same one-file read openNote
    -- makes, because you asked for this file), or neither (refused, named).
    function v.setField(rel, key, value)
        rel = tostring(rel or "")
        key = tostring(key or ""):lower()
        if rel == "" or not key:find("^[%w_][%w_%-%.]*$") then return false, "no note or no field" end
        if key == "tag" or key == "tags" then return false, "tags are written in the note, not here" end
        if rel:find("%.%.") or rel:sub(1, 1) == "/" or not rel:find("%.md$") then return false, "not a note in the vault" end
        local function fail(why)
            v.moveFails, v.moveErr = v.moveFails + 1, why
            return false, why
        end
        if v.doc and not v.doc.scratch and v.doc.rel == rel then
            v.setText(v.withField(v.doc.text or "", key, value))
            if not v.saveNow() then return fail(tostring(v.lastSaveErr or "not saved")) end
        else
            local n = v.noteFromRel(rel)
            local text = readFile(n.path)
            if text == nil then return fail("could not read " .. rel) end
            local out = v.withField(text, key, value)
            if out == text then
                v.fmOf[rel] = v.fmIn(out); rebuildFields()
                return true, "already there"
            end
            mkdirp(n.path:match("^(.*)/[^/]*$") or v.dir)
            local tmp = n.path .. ".tmp"
            local f = io.open(tmp, "w")
            if not f then return fail("cannot open " .. tmp) end
            local okW = f:write(out)
            f:close()
            if not okW then return fail("write failed for " .. rel) end
            if not os.rename(tmp, n.path) then return fail("rename failed for " .. rel) end
            -- the index knows at once: the board redraws without a rescan
            v.fmOf[rel] = v.fmIn(out)
            v.tagsOf[rel] = v.tagsIn(out)
            rebuildTags()
            rebuildFields()
        end
        v.moves = v.moves + 1
        v.lastMove = rel .. " · " .. key .. " = " .. ((tostring(value or "") ~= "") and tostring(value) or "(cleared)")
        v.moveErr = nil
        return true
    end

    -- Open a note by name. A missing one is CREATED (in the vault root,
    -- or under `sub` — "Daily" for ⌘D) with a heading of its name. The
    -- only main-thread file read in the module happens here, for one
    -- file, because you asked for it.
    function v.openNote(name, sub, seed)
        -- 6.203.0 — the guard lives at the DOOR, never in the callers:
        -- ⌘N, ⌘D, ⌘⇧N, a [[link]] follow and a search row all arrive
        -- here, and a check in one of them is a check the other five
        -- quietly stop matching (6.198.0's rule, this module's turn).
        local why
        name, why = v.nameCheck(name)
        if name == "" then return false, why or "no name" end
        if v.doc and v.dirty then v.saveNow() end
        local n = v.find(name)
        if not n then
            -- 6.174.0 — the index is asynchronous (empty after a reload,
            -- stale for anything OneDrive delivered since the last scan).
            -- Look on disk before deciding this note is new: ⌘⇧[ on a day
            -- written by the other Mac must OPEN it, never seed over it.
            -- Reading the file we are about to open is the one read this
            -- module makes.
            local rel = (sub and sub ~= "") and (sub .. "/" .. name .. ".md") or (name .. ".md")
            n = v.noteFromRel(rel)
            local onDisk = readFile(n.path)
            if onDisk ~= nil then
                n.text = onDisk
            else
                n.text = seed or ("# " .. name .. "\n\n")
                n.created = true
            end
        else
            n = { name = n.name, rel = n.rel, path = n.path, key = n.key }
            local s = readFile(n.path)
            if s == nil then
                n.text, n.created = seed or ("# " .. n.name .. "\n\n"), true
                warn("could not read " .. n.path .. " — editing a fresh copy; the first save writes it")
            else
                n.text = s
            end
        end
        v.doc = n
        v.dirty = n.created == true
        v.caret = #n.text
        v.view = "edit"
        v.links[n.rel] = v.linksIn(n.text)
        rebuildBacklinks()
        v.tagsOf[n.rel] = v.tagsIn(n.text)     -- 6.174.0
        v.fmOf[n.rel]   = v.fmIn(n.text)       -- 6.185.0
        rebuildTags()
        rebuildFields()
        v.caretLine, v.caretHead = nil, nil    -- callers set them AFTER a successful open
        if v.dirty then v.saveNow() end
        pcall(function() hs.settings.set("vault.lastNote", n.rel) end)
        say("opened " .. n.rel)
        v.findMentions()                       -- 6.174.0 — ≈ notes that say this name without linking it
        return true
    end

    -- 6.174.0 — a daily note for ANY day. An existing one simply opens
    -- (never re-templated); a new one is seeded from Templates/Daily.md
    -- when it exists ({{title}} = the date, {{date}}/{{time}} for THAT
    -- day; the body arrives from /bin/cat, so the open is "pending"),
    -- else with the old weekday heading, at once.
    function v.openDailyFor(epoch)
        epoch = epoch or os.time()
        local day = os.date("%Y-%m-%d", epoch)
        if v.find(day) then return v.openNote(day, v.dailyDir) end
        local rec = v.templateByName(v.dailyTemplate or "")
        if not rec then return v.openNote(day, v.dailyDir, "# " .. os.date("%A %d %B %Y", epoch) .. "\n\n") end
        v.readTemplate(rec, function(text)
            local body, caret = v.fillTemplate(text, { title = day, when = epoch, name = rec.rel })
            if v.openNote(day, v.dailyDir, body) then
                v.caretHead = caret and body:sub(1, caret) or nil
                v.render()
            end
        end)
        return true, "pending"
    end
    function v.openDaily() return v.openDailyFor(os.time()) end
    -- ⌘⇧[ / ⌘⇧]: the day before / after the OPEN daily note
    function v.openDailyOffset(days)
        local e = v.doc and not v.doc.scratch and v.dailyEpochOf(v.doc.rel) or nil
        if not e then alert("📅 open a daily note first (⌘D)", 1) return false end
        return v.openDailyFor(e + ((tonumber(days) or 1) < 0 and -1 or 1) * 86400)
    end

    -- Follow what the page found under the caret: a [[note]] or a
    -- Markdown (target). http(s) opens in the browser; anything else is
    -- a path relative to the note's folder (Obsidian's convention).
    function v.follow(target, isMd)
        target = trim(target)
        if target == "" then return false end
        if not isMd then return v.openNote(v.linkTarget(target)) end
        if target:match("^https?://") then
            pcall(function() hs.urlevent.openURL(target) end)
            return true
        end
        -- 6.180.0 — a ⇪⇧U anchor writes an ABSOLUTE link: file:// for a
        -- document, or a scheme only its own app understands (message://
        -- for a Mail message, asana:// …). Before this, "file:///Users/…"
        -- did not match https, did not start with "/", and was therefore
        -- joined onto the note's folder as if it were relative — it could
        -- never open. Schemes we do not know are handed to macOS, which
        -- does know.
        local scheme = target:match("^([%a][%w+.-]*)://")
        if scheme and scheme ~= "file" then
            pcall(function() hs.urlevent.openURL(target) end)
            return true
        end
        local decoded = target:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        if scheme == "file" then decoded = decoded:gsub("^file://", "") end
        local path = decoded
        if path:sub(1, 1) ~= "/" then
            local base = (v.doc and v.doc.path:match("^(.*)/[^/]*$")) or v.dir
            path = base .. "/" .. decoded
        end
        -- fold "a/b/../c" so the vault test and hs.open both see one path
        local parts = {}
        for seg in path:gmatch("[^/]+") do
            if seg == ".." then parts[#parts] = nil elseif seg ~= "." then parts[#parts + 1] = seg end
        end
        path = "/" .. table.concat(parts, "/")
        if path:match("%.md$") then
            local rel = path:sub(1, #v.dir + 1) == v.dir .. "/" and path:sub(#v.dir + 2) or nil
            if rel then return v.openNote(rel:gsub("%.md$", ""):match("([^/]+)$"), rel:match("^(.*)/[^/]*$")) end
        end
        -- 🔎 MOVE SURVIVAL (6.180.0). A path breaks the moment the file is
        -- renamed or filed somewhere else, which is the one thing a link
        -- to a document has to survive. If the path has gone, the anchors
        -- module is asked to find the file by NAME (it uses the file index
        -- that ⇪D already builds). It is asked through the service
        -- registry, so a Mac without that module simply gets the honest
        -- "it has moved" message instead of a silent failure.
        local gone = false
        if type(hs.fs) == "table" and type(hs.fs.attributes) == "function" then
            local okA, a = pcall(hs.fs.attributes, path)
            gone = not (okA and type(a) == "table")
        end
        if gone then
            local found = nil
            if _G.service and _G.service.has and _G.service.has("anchors.resolve") then
                local okS, res = _G.service.call("anchors.resolve", path)
                if okS and type(res) == "string" and res ~= "" then found = res end
            end
            if found then
                path = found
                pcall(function() hs.alert.show("🕸 Moved — opening " .. found:match("[^/]+$"), 2) end)
            else
                pcall(function() hs.alert.show("🕸 " .. (path:match("[^/]+$") or path)
                      .. " is not where the link says.\nIt may have moved or be offline.", 4) end)
                return false
            end
        end
        local ok = pcall(function() return hs.open(path) end)
        if not ok then pcall(function() hs.alert.show("🕸 Could not open " .. decoded, 2) end) end
        return ok
    end

    -- ⌘K: pick a file anywhere (OneDrive by default) and write the
    -- relative Markdown link at the caret. Relative to the NOTE, so it
    -- resolves on both Macs whatever the home folder is called.
    local function relativeTo(fromDir, path)
        local a, b = {}, {}
        for p in fromDir:gmatch("[^/]+") do a[#a + 1] = p end
        for p in path:gmatch("[^/]+") do b[#b + 1] = p end
        local i = 1
        while a[i] and b[i] and a[i] == b[i] do i = i + 1 end
        local out = {}
        for _ = i, #a do out[#out + 1] = ".." end
        for j = i, #b do out[#out + 1] = b[j] end
        return table.concat(out, "/")
    end
    function v.linkFile()
        if not (hs.dialog and hs.dialog.chooseFileOrFolder) then return nil, "no file picker" end
        local start = (v.cloudDir or v.dir)
        local ok, picked = pcall(hs.dialog.chooseFileOrFolder, "Link a file", start, true, false, false)
        if not (ok and type(picked) == "table") then return nil, "cancelled" end
        local path
        for _, p in pairs(picked) do path = tostring(p) break end
        if not path then return nil, "cancelled" end
        path = path:gsub("^file://", ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        local base = (v.doc and v.doc.path:match("^(.*)/[^/]*$")) or v.dir
        local rel = relativeTo(base, path)
        local name = path:match("([^/]+)$") or path
        local enc = rel:gsub("[ %(%)]", function(c) return string.format("%%%02X", c:byte()) end)
        return "[" .. name .. "](" .. enc .. ")"
    end

    -- ---- 6.174.0 — templates: read through /bin/cat, never io.open ----------
    -- A template is a note in OneDrive like any other, so its body can be
    -- a placeholder that BLOCKS on read. The body arrives from a held
    -- task; a held timer gives up after templateTimeout and says so. A
    -- second request supersedes the first (sequence number + terminate).
    local function stopCatTimer()
        if v.catTimer then pcall(function() v.catTimer:stop() end); v.catTimer = nil end
    end
    function v.readTemplate(rec, fn)
        stopTask("catTask"); stopCatTimer()
        v.tplSeq = v.tplSeq + 1
        local seq = v.tplSeq
        v.eval("vaultHint(" .. jstr("fetching " .. rec.rel .. "…") .. ")")
        local ok, why = startTask("catTask", v.CAT, { rec.path }, function(code, out, err)
            if seq ~= v.tplSeq then return end
            stopCatTimer()
            v.eval('vaultHint("")')
            if code ~= 0 then alert("📄 could not read " .. rec.rel .. " — " .. trim(err), 3) return end
            fn(tostring(out or ""))
        end)
        if not ok then
            v.eval('vaultHint("")')
            alert(why == "no hs.task" and "📄 templates need hs.task" or ("📄 could not start " .. v.CAT .. " — " .. tostring(why)), 3)
            return false, why
        end
        local okT, tm = pcall(hs.timer.doAfter, v.templateTimeout, function()
            v.catTimer = nil
            if v.catTask then
                stopTask("catTask")
                v.eval('vaultHint("")')
                alert("📄 " .. rec.rel .. " did not arrive — is OneDrive online?", 3)
            end
        end)
        v.catTimer = okT and tm or nil     -- HELD
        return true
    end
    -- ⌘⇧T: the template's text lands at the caret as head + tail around
    -- {{cursor}} — two strings, no offset crosses the bridge.
    function v.insertTemplate(name)
        if not v.doc then alert("📄 open a note first") return false end
        local rec = v.templateByName(name)
        if not rec then alert("📄 no template named \"" .. tostring(name) .. "\"") return false end
        local forRel = v.doc.rel
        return v.readTemplate(rec, function(text)
            if not (v.doc and v.doc.rel == forRel) then say("template arrived after you switched — not inserted") return end
            local body, caret = v.fillTemplate(text, { title = v.doc.name, name = rec.rel })
            local head = caret and body:sub(1, caret) or body
            local tail = caret and body:sub(caret + 1) or ""
            v.eval("insertAtCaret(" .. jstr(head) .. "," .. jstr(tail) .. ")")
        end)
    end
    -- ⌘N (and ⌘⇧N's "— blank —" row)
    --
    -- 6.190.0 — LL: "Can I get a window that is larger than this? I can't
    -- see what I'm typing?" He was looking at hs.dialog.textPrompt, which
    -- is a stock macOS NSAlert: its width is AppKit's and Hammerspoon
    -- exposes no size for it, so there is no bigger version of that box.
    -- The answer is to ask in the WINDOW, where the field is the window's
    -- width and the text is the window's 13 pt.
    --
    -- The dialog stays as the DEGRADE, not as the default: on a
    -- Hammerspoon with no web view there is no page to ask in, and ⌘N
    -- still has to work.
    function v.askName(kind, label, value)
        if not v.webview then return false end
        local ok = pcall(function()
            v.eval("askName(" .. jstr(kind) .. "," .. jstr(label) .. ","
                   .. jstr(value or "") .. ")")
        end)
        return ok
    end

    -- The half that actually makes the note, split out so the page and the
    -- fallback dialog reach the SAME code — two creation paths is how one
    -- of them quietly stops matching the other.
    function v.createNamed(typed)
        -- 6.203.0 — it asks the SAME v.nameCheck openNote will ask, for
        -- one reason: to have the WHY in its hand. openNote returns it
        -- too, so this is belt and braces, not a second rule.
        local name, why = v.nameCheck(typed)
        if name == "" then return false, why end
        local ok, oWhy = v.openNote(name)
        if not ok then return false, oWhy or "that note could not be opened" end
        v.render()
        return true, why       -- why ~= nil here means the name was CLEANED, not refused
    end

    function v.newNote()
        if v.askName("new", "Name of the note:", "") then return true end
        local okP, button, typed = pcall(hs.dialog.textPrompt, "New note", "Name of the note:", "", "Create", "Cancel")
        if okP and button == "Create" then
            local ok, why = v.createNamed(typed)
            -- 6.203.0 — there is no page to say it in on this path (that
            -- is what makes it the degrade), so the alert IS the right
            -- channel here: no window of ours is over it.
            if not ok and why then alert("🕸 " .. why, 5) end
            return ok
        end
        return false
    end
    -- ⌘⇧N: a new note from a template ({{title}} = the typed name)
    function v.newFromTemplate(name)
        if name == "" then return v.newNote() end
        local rec = v.templateByName(name)
        if not rec then alert("📄 no template named \"" .. tostring(name) .. "\"") return false end
        local okP, button, typed = pcall(hs.dialog.textPrompt, "New note from " .. rec.name, "Name of the note:", "", "Create", "Cancel")
        if not (okP and button == "Create") then return false end
        -- 6.203.0 — the same rule, said out loud. This path has no page
        -- to say it in (it is a system dialog), so the alert is right here.
        local want, whyW = v.nameCheck(typed)
        if want == "" then
            if whyW and trim(tostring(typed or "")) ~= "" then alert("📄 " .. whyW, 5) end
            return false
        end
        if v.find(want) then
            alert("📄 a note named \"" .. want .. "\" already exists — opening it", 2)
            if v.openNote(want) then v.render() end
            return false
        end
        return v.readTemplate(rec, function(text)
            local body, caret = v.fillTemplate(text, { title = want, name = rec.rel })
            if v.openNote(want, nil, body) then
                v.caretHead = caret and body:sub(1, caret) or nil
                v.render()
            end
        end)
    end

    -- ---- 6.174.0 — the left column's modes: notes / search / tasks ------------
    local function leaveSearch()
        stopTask("searchTask")
        if v.searchTimer then pcall(function() v.searchTimer:stop() end); v.searchTimer = nil end
        v.searchQuery, v.searchRows, v.searchMore, v.searching = "", {}, false, false
    end
    function v.setMode(m)
        if m ~= "search" and m ~= "tasks" then m = "notes" end
        if v.mode == "search" and m ~= "search" then leaveSearch() end
        v.mode = m
        if m == "tasks" then v.listTasks() end
        if m == "notes" then v.filter = "" end
        return m
    end

    -- ⌘⇧F: one held grep after searchDelay of silence; the longest term
    -- goes to grep (-F, plain), the rest are checked in Lua.
    function v.search(q)
        q = tostring(q or "")
        v.searchQuery = q
        if v.searchTimer then pcall(function() v.searchTimer:stop() end); v.searchTimer = nil end
        if trim(q) == "" then
            stopTask("searchTask")
            v.searchRows, v.searchMore, v.searching = {}, false, false
            v.eval('setRows("search", [], false, "")')
            return false
        end
        local ok, tm = pcall(hs.timer.doAfter, v.searchDelay, function() v.searchTimer = nil; v.runSearch() end)
        v.searchTimer = ok and tm or nil     -- HELD
        return true
    end
    local function taggedWith(rel, tag)
        for _, t in ipairs(v.tagsOf[rel] or {}) do
            local k = t:lower()
            if k == tag or k:sub(1, #tag + 1) == tag .. "/" then return true end
        end
        return false
    end
    local function pushSearch(rows, more, q)
        v.eval("setRows(\"search\", " .. jarr(rows) .. ", " .. tostring(more) .. ", " .. jstr(q) .. ")")
    end
    function v.runSearch()
        local q = v.searchQuery
        if trim(q) == "" then return false end
        stopTask("searchTask")
        v.searchSeq = v.searchSeq + 1
        local seq = v.searchSeq
        local T = v.searchTerms(q)
        if #T.terms == 0 then
            -- operators only: the NOTE NAMES that pass, no grep
            local rows, more = {}, false
            for _, n in ipairs(v.notes) do
                if (not T.tag or taggedWith(n.rel, T.tag)) and (not T.path or n.rel:lower():find(T.path, 1, true)) then
                    if #rows >= v.searchMax then more = true break end
                    rows[#rows + 1] = { n = n.name, r = n.rel, l = 0, x = "" }
                end
            end
            v.searchRows, v.searchMore, v.searching, v.searchErr = rows, more, false, nil
            v.lastSearch = { q = q, hits = #rows, files = #rows, when = os.time() }
            pushSearch(rows, more, q)
            return true
        end
        local first = T.terms[1]
        for _, t in ipairs(T.terms) do if #t > #first then first = t end end
        v.searching = true
        v.searches = v.searches + 1
        local args = grepBase("-rniIHF")
        for _, a in ipairs({ "-m", tostring(v.searchPerFile), "-e", first, v.dir }) do args[#args + 1] = a end
        local ok, why = startTask("searchTask", v.GREP, args, function(code, out, err)
            if seq ~= v.searchSeq or v.searchQuery ~= q or v.mode ~= "search" then return end
            local rows, more, files = {}, false, {}
            if code ~= 0 and code ~= 1 then
                v.searchErr = "grep exited " .. tostring(code) .. ": " .. trim(err)
            else
                v.searchErr = nil
                for line in tostring(out or ""):gmatch("[^\n]+") do
                    local path, ln, text = line:match("^(.-):(%d+):(.*)$")
                    local rel = path and relOf(path)
                    if rel then
                        local low, keep = text:lower(), true
                        for _, t in ipairs(T.terms) do
                            if not low:find(t:lower(), 1, true) then keep = false break end
                        end
                        if keep and T.tag and not taggedWith(rel, T.tag) then keep = false end
                        if keep and T.path and not rel:lower():find(T.path, 1, true) then keep = false end
                        if keep then
                            if #rows >= v.searchMax then more = true break end
                            rows[#rows + 1] = { n = rel:match("([^/]+)%.md$") or rel, r = rel, l = tonumber(ln), x = cutSnippet(text, first) }
                            files[rel] = true
                        end
                    end
                end
            end
            local nf = 0
            for _ in pairs(files) do nf = nf + 1 end
            v.searchRows, v.searchMore, v.searching = rows, more, false
            v.lastSearch = { q = q, hits = #rows, files = nf, when = os.time() }
            pushSearch(rows, more, q)
        end)
        if not ok then
            v.searching, v.searchErr = false, why
            pushSearch({}, false, q)
            return false, why
        end
        return true
    end

    -- ⌘⇧K: every open task line in the vault, one held grep. Templates
    -- are skipped; rows sort by note then line.
    local function sortTaskRows(rows)
        table.sort(rows, function(a, b)
            local ar, br = a.r:lower(), b.r:lower()
            if ar ~= br then return ar < br end
            return (a.l or 0) < (b.l or 0)
        end)
    end
    local function taskText(text)
        text = text:gsub("^%s*[%-%*%+]%s+%[ %]%s?", "")
        text = text:gsub("^%s*%d+%.%s+%[ %]%s?", "")
        return (text:gsub("\r$", ""))
    end
    function v.parseTaskLines(out)
        local rows, more = {}, false
        for line in tostring(out or ""):gmatch("[^\n]+") do
            local path, ln, text = line:match("^(.-):(%d+):(.*)$")
            local rel = path and relOf(path)
            if rel and not isTemplateRel(rel) then
                rows[#rows + 1] = { n = rel:match("([^/]+)%.md$") or rel, r = rel, l = tonumber(ln), x = taskText(text) }
            end
        end
        sortTaskRows(rows)
        if #rows > v.tasksMax then
            more = true
            for i = #rows, v.tasksMax + 1, -1 do rows[i] = nil end
        end
        return rows, more
    end
    local function pushTasks()
        v.eval("setRows(\"tasks\", " .. jarr(v.taskRows) .. ", " .. tostring(v.taskMore) .. ", \"\")")
    end
    function v.listTasks()
        stopTask("tasksTask")
        v.tasksSeq = v.tasksSeq + 1
        local seq = v.tasksSeq
        v.tasksListing = true
        local args = grepBase("-rnHIE")
        for _, a in ipairs({ "-e", "^[[:space:]]*([-*+]|[0-9]+\\.) \\[ \\]", v.dir }) do args[#args + 1] = a end
        local ok, why = startTask("tasksTask", v.GREP, args, function(code, out, err)
            if seq ~= v.tasksSeq then return end
            local rows, more = {}, false
            if code ~= 0 and code ~= 1 then v.tasksErr = "grep exited " .. tostring(code) .. ": " .. trim(err)
            else v.tasksErr = nil; rows, more = v.parseTaskLines(out) end
            v.taskRows, v.taskMore, v.tasksListing, v.lastTasks = rows, more, false, os.time()
            if v.mode == "tasks" then pushTasks() end
        end)
        if not ok then
            v.tasksErr, v.tasksListing = why, false
            v.eval('setRows("tasks", [], false, "")')
            return false, why
        end
        return true
    end
    -- after a save while ☑ is up: the OPEN note's rows come from its text — no grep
    function v.refreshOpenTasks()
        local d = v.doc
        if not (d and not d.scratch and v.mode == "tasks" and v.lastTasks) then return false end
        local rows = {}
        for _, r in ipairs(v.taskRows) do if r.r ~= d.rel then rows[#rows + 1] = r end end
        if not isTemplateRel(d.rel) then
            for _, t in ipairs(v.tasksIn(d.text)) do rows[#rows + 1] = { n = d.name, r = d.rel, l = t.line, x = t.text } end
        end
        sortTaskRows(rows)
        v.taskRows = rows
        pushTasks()
        return true
    end

    -- ---- 6.174.0 — ≈ unlinked mentions: files that say this note's name -----
    -- (whole word, case-insensitive, -l) minus itself, its backlinkers and
    -- the templates. A note created this instant starts no grep; an answer
    -- for a note that is no longer open is dropped.
    function v.findMentions()
        local d = v.doc
        if not d or d.scratch or d.created then return false end
        stopTask("mentionTask")
        v.mentionSeq = v.mentionSeq + 1
        local seq = v.mentionSeq
        v.unlinked = { key = d.key, rels = {}, pending = true, why = nil, more = false }
        if #d.name < (tonumber(v.mentionsMinLen) or 3) then
            v.unlinked.pending, v.unlinked.why = false, "too short"
            return false
        end
        local args = grepBase("-rliwIF")
        for _, a in ipairs({ "-e", d.name, v.dir }) do args[#args + 1] = a end
        local ok = startTask("mentionTask", v.GREP, args, function(code, out, err)
            if seq ~= v.mentionSeq or not (v.doc and v.doc.key == d.key) then return end
            local rels, more, why = {}, false, nil
            if code ~= 0 and code ~= 1 then why = "grep exited " .. tostring(code) .. ": " .. trim(err)
            else
                local linked = {}
                for _, r in ipairs(v.backlinks[d.key] or {}) do linked[r] = true end
                for line in tostring(out or ""):gmatch("[^\n]+") do
                    local rel = relOf(line)
                    if rel and rel ~= d.rel and not linked[rel] and not isTemplateRel(rel) then rels[#rels + 1] = rel end
                end
                table.sort(rels)
                if #rels > v.mentionsMax then
                    more = true
                    for i = #rels, v.mentionsMax + 1, -1 do rels[i] = nil end
                end
            end
            v.unlinked = { key = d.key, rels = rels, pending = false, why = why, more = more }
            local rows = {}
            for _, rel in ipairs(rels) do rows[#rows + 1] = { n = rel:match("([^/]+)%.md$") or rel, r = rel } end
            v.pushMentions()
        end)
        if not ok then v.unlinked.pending, v.unlinked.why = false, "unavailable" end
        return ok
    end

    -- 6.174.0 — hand the page the mentions answer Lua already holds. The
    -- grep usually finishes BEFORE the new page has run its script, so the
    -- answer lands in the old page (dropped by its key guard) or before
    -- setMentions exists; the page says "ready" when its load sequence
    -- ends and gets the answer then.
    function v.pushMentions()
        local u = v.unlinked
        if u.pending or not u.key then return false end
        local rows = {}
        for _, rel in ipairs(u.rels or {}) do rows[#rows + 1] = { n = rel:match("([^/]+)%.md$") or rel, r = rel } end
        v.eval("setMentions(" .. jarr(rows) .. ", " .. jstr(u.key) .. ", " .. jstr(u.why or (u.more and "more" or "")) .. ")")
        return true
    end

    -- ---- 6.174.0 — ⌘⇧E: the selection becomes a new note, [[Name]] stays --
    -- The page sends the text BEFORE the selection and the selection; Lua
    -- checks both against its own copy and refuses when they disagree, so
    -- nothing is written on a stale page.
    local function cutChars(s, n)
        local out, count = {}, 0
        for _, c in utf8.codes(s) do
            count = count + 1
            if count > n then break end
            out[#out + 1] = utf8.char(c)
        end
        return table.concat(out)
    end
    function v.extract(head, selText)
        head, selText = tostring(head or ""), tostring(selText or "")
        if not v.doc or v.doc.scratch then alert("✂️ extract works in a note, not a scratch tab") return false end
        if trim(selText) == "" then alert("✂️ select some text first") return false end
        if v.doc.text:sub(#head + 1, #head + #selText) ~= selText then alert("✂️ the text changed — try again") return false end
        local firstLine = selText:match("[^\n]*[^%s\n][^\n]*") or ""
        -- the box comes off only as a whole: "%[?[ xX]?%]?" would eat the
        -- leading X of "Xcode tips"
        local default = firstLine:gsub("^[#>%-%*%+%s]*", ""):gsub("^%[[ xX]%]%s*", "")
        default = linkSafe(default)
        default = utf8.len(default) and cutChars(default, 60) or default:sub(1, 60)
        local okP, button, typed = pcall(hs.dialog.textPrompt, "Extract to a new note", "Name of the new note:", default, "Create", "Cancel")
        if not (okP and button == "Create") then return false end
        local name = linkSafe(typed)
        if name == "" then name = default end     -- the untouched default field
        if name == "" then return false end
        -- 6.203.0 — ask BEFORE the link goes in. This door writes the name
        -- into the note that is ALREADY FINE and saves it, and only then
        -- opens the new one: an impossible name used to leave a 3,000
        -- character [[link]] behind in the note LL was working in, with
        -- the new note never created. Same rule, same words, one door on.
        local okN, whyN = v.nameCheck(name)
        if okN == "" then alert("✂️ " .. (whyN or "that name cannot be used"), 5) return false end
        name = okN
        if v.find(name) then alert("✂️ a note named \"" .. name .. "\" already exists — pick another name", 3) return false end
        v.setText(head .. "[[" .. name .. "]]" .. v.doc.text:sub(#head + #selText + 1))
        v.saveNow()
        v.openNote(name, nil, "# " .. name .. "\n\n" .. selText .. (selText:sub(-1) == "\n" and "" or "\n"))
        v.extracts = v.extracts + 1
        v.render()
        return true
    end

    -- ---- 6.174.0 — ⌘⇧R: a random note (not a template, not this one) ------
    function v.openRandom()
        local c = {}
        for _, n in ipairs(v.notes) do
            if not isTemplateRel(n.rel) and not (v.doc and v.doc.rel == n.rel) then c[#c + 1] = n end
        end
        if #c == 0 then alert("🎲 nothing else to open") return false end
        local pick = c[math.random(#c)]
        if not v.openNote(pick.name) then return false end
        v.randoms = v.randoms + 1
        return true
    end

    -- ---- the page ------------------------------------------------------------------
    function v.notesJson()
        local rows = {}
        for _, n in ipairs(v.notes) do
            -- 6.174.0 — g: the note's tag keys (the page filters on them), tpl: a template
            local g = {}
            for _, t in ipairs(v.tagsOf[n.rel] or {}) do g[#g + 1] = jstr(t:lower()) end
            -- 6.183.0 — l: the KEYS this note links out to, so a query's
            -- FROM [[Note]] is answered in the page with no round trip
            local l = {}
            for _, target in ipairs(v.links[n.rel] or {}) do l[#l + 1] = jstr(keyOf(target)) end
            -- 6.185.0 — f: the note's front-matter FIELDS, so a query's WHERE
            -- and a TABLE's columns are answered in the page. Keys sorted, so
            -- the same index always renders the same page.
            local keys = {}
            for k in pairs(v.fmOf[n.rel] or {}) do keys[#keys + 1] = k end
            table.sort(keys)
            local f = {}
            for _, k in ipairs(keys) do f[#f + 1] = jstr(k) .. ":" .. jstr(v.fmOf[n.rel][k]) end
            rows[#rows + 1] = "{n:" .. jstr(n.name) .. ",r:" .. jstr(n.rel) .. ",g:[" .. table.concat(g, ",") .. "]"
                .. ",l:[" .. table.concat(l, ",") .. "]"
                .. (#f > 0 and (",f:{" .. table.concat(f, ",") .. "}") or "")
                .. (isTemplateRel(n.rel) and ",tpl:1" or "") .. "}"
        end
        return "[" .. table.concat(rows, ",") .. "]"
    end
    function v.graphJson()
        local nodes, idx, edges = {}, {}, {}
        for _, n in ipairs(v.notes) do
            idx[n.key] = #nodes
            nodes[#nodes + 1] = "{n:" .. jstr(n.name) .. ",r:" .. jstr(n.rel) .. ",k:" .. jstr(n.key) .. "}"
        end
        for k, u in pairs(v.unresolved) do
            idx[k] = #nodes
            nodes[#nodes + 1] = "{n:" .. jstr(u.name) .. ",r:\"\",k:" .. jstr(k) .. ",ghost:1}"
        end
        local relKey = {}
        for _, n in ipairs(v.notes) do relKey[n.rel] = n.key end
        for rel, targets in pairs(v.links) do
            local a = relKey[rel] and idx[relKey[rel]]
            if a then
                for _, t in ipairs(targets) do
                    local b = idx[keyOf(t)]
                    if b and b ~= a then edges[#edges + 1] = "[" .. a .. "," .. b .. "]" end
                end
            end
        end
        return "{nodes:[" .. table.concat(nodes, ",") .. "],edges:[" .. table.concat(edges, ",") .. "]}"
    end

    function v.buildHtml()
        local d = v.doc
        local outs, backs = {}, {}
        local sp = v.sp()
        if d then
            for _, t in ipairs(d.scratch and v.linksIn(d.text) or v.links[d.rel] or {}) do
                local n = v.byKey[keyOf(t)]
                outs[#outs + 1] = '<li class="lnk' .. (n and "" or " ghost") .. '" data-name="' .. escapeHtml(t) .. '">'
                    .. (n and "→ " or "→ ✚ ") .. escapeHtml(t) .. '</li>'
            end
            for _, rel in ipairs(v.backlinks[d.key] or {}) do
                local name = rel:match("([^/]+)%.md$") or rel
                backs[#backs + 1] = '<li class="lnk" data-name="' .. escapeHtml(name) .. '">← ' .. escapeHtml(name) .. '</li>'
            end
        end
        -- 6.174.0 — ≈ UNLINKED MENTIONS pre-filled from Lua when the answer is
        -- for THIS note, so a rebuild does not lose it; later answers arrive
        -- through setMentions without a rebuild.
        local unlHtml, unlCount = '<div class="none">looking…</div>', nil
        if d and not d.scratch then
            local u = v.unlinked
            if u.key == d.key and not u.pending then
                if u.why == "too short" then unlHtml = '<div class="none">too short a name to search</div>'
                elseif u.why == "unavailable" then unlHtml = '<div class="none">unavailable on this Hammerspoon</div>'
                elseif u.why then unlHtml = '<div class="none">⚠ ' .. escapeHtml(u.why) .. '</div>'
                elseif #u.rels == 0 then unlHtml = '<div class="none">no other note mentions "' .. escapeHtml(d.name) .. '"</div>'
                else
                    local rows = {}
                    for _, rel in ipairs(u.rels) do
                        local name = rel:match("([^/]+)%.md$") or rel
                        rows[#rows + 1] = '<li class="lnk" data-name="' .. escapeHtml(name) .. '" title="' .. escapeHtml(rel) .. '">≈ ' .. escapeHtml(name) .. '</li>'
                    end
                    if u.more then rows[#rows + 1] = '<div class="none">(first ' .. #u.rels .. ')</div>' end
                    unlHtml, unlCount = table.concat(rows), #u.rels
                end
            elseif u.key == d.key and u.pending then unlHtml = '<div class="none">looking…</div>'
            elseif d.created then unlHtml = '<div class="none">a new note — nothing mentions it yet</div>' end
        end
        local unlBlock = '<h4 id="unlh">UNLINKED MENTIONS' .. (unlCount and (" · " .. unlCount) or "") .. '</h4><ul id="unl">' .. unlHtml .. '</ul>'
        -- DAILY ‹ ›: the days either side of an open daily note
        local dailyJs, dailyBtns = "null", ""
        if d and not d.scratch then
            local e = v.dailyEpochOf(d.rel)
            if e then
                local prev, nxt = os.date("%Y-%m-%d", e - 86400), os.date("%Y-%m-%d", e + 86400)
                dailyJs = "{prev:" .. jstr(prev) .. ",next:" .. jstr(nxt) .. "}"
                -- the header's ‹ › live only on a daily note (⌘⇧[ ⌘⇧] always send; Lua says no otherwise)
                dailyBtns = '<button onclick="say({a:\'dayshift\',d:-1})" title="Previous day ⌘⇧[">‹ ' .. prev .. '</button>'
                         .. '<button onclick="say({a:\'dayshift\',d:1})" title="Next day ⌘⇧]">' .. nxt .. ' ›</button>'
            end
        end
        local u = v.unlinked
        local unlRows = {}
        for _, rel in ipairs(u.rels or {}) do unlRows[#unlRows + 1] = { n = rel:match("([^/]+)%.md$") or rel, r = rel } end
        local fs = tonumber(v.fontSize) or 16
        if fs < 8 then fs = 8 end
        local status = v.scanning and "scanning…" or (v.scanErr and ("⚠ " .. v.scanErr) or (#v.notes .. " notes"))
        if v.partial then status = status .. " (partial)" end
        -- 6.173.0 — the pad's tabs and closed tabs, for the page
        local tabsJs, histJs, hist = {}, {}, {}
        if sp then
            for _, t in ipairs(sp.tabs) do
                local k = sp.kindOf and sp.kindOf(t)
                tabsJs[#tabsJs + 1] = "{id:" .. jstr(t.id) .. ",t:" .. jstr(sp.titleOf(t)) .. ",b:" .. jstr(k and k.badge or "")
                    .. ",k:" .. jstr(t.kind or "") .. "}"
            end
            for i = 1, math.min(#(sp.history or {}), tonumber(sp.historyRows) or 200) do
                local h = sp.history[i]
                local k = h.kind and sp.kinds and sp.kinds[h.kind]
                hist[#hist + 1] = '<li class="hist" data-hist="' .. escapeHtml(h.id) .. '" title="' .. escapeHtml(os.date("%b %d %H:%M", h.closedAt or 0)) .. '">'
                    .. escapeHtml((k and (k.badge .. " ") or "") .. (h.title or "Untitled")) .. '</li>'
            end
        end
        local isTab = d and d.scratch and true or false
        local kindHint = isTab and sp and sp.kindOf and d.kind and sp.kinds[d.kind] and sp.kinds[d.kind].hint or nil
        if kindHint then status = kindHint .. " · " .. status end
        local theme = (_G.uiStyle and _G.uiStyle.cssOverride and _G.uiStyle.cssOverride()) or ""
        local html = [==[<!doctype html><html><head><meta charset="utf-8"><style>
:root{color-scheme:dark}
html,body{margin:0;height:100%;background:#141418;color:#e8e8ec;font-family:-apple-system,Helvetica,sans-serif;font-size:FSpx;overflow:hidden}
#wrap{display:flex;flex-direction:column;height:100%}
header{display:flex;align-items:center;gap:8px;padding:6px 10px;background:#1c1c22;cursor:grab;user-select:none;-webkit-user-select:none}
header.dragging{cursor:grabbing}
header .name{font-weight:600}
header .doc{flex:1;opacity:.85;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
header .hint{opacity:.55;font-size:FS2px}
header button{background:#2a2a33;color:#e8e8ec;border:0;border-radius:6px;padding:3px 9px;font-size:FS1px;cursor:pointer}
header button.on{background:#4a7fe0;color:#fff}
header .bad{background:#7a2a2a;color:#ffd9d9;border-radius:6px;padding:3px 8px;font-size:FS2px}
#main{display:flex;flex:1;min-height:0}
#side{width:24%;min-width:180px;display:flex;flex-direction:column;border-right:1px solid #26262e;background:#17171c}
#side input{margin:8px;background:#202027;border:1px solid #2a2a33;border-radius:6px;color:#e8e8ec;padding:5px 8px;font-size:FS1px;outline:0}
#rows{flex:1;overflow:auto;list-style:none;margin:0;padding:0 0 8px}
#rows li{padding:5px 12px;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#rows li:hover{background:#22222a}
#rows li.sel,#rows li.cur{background:#2c3a5a}
#rows li.cur{font-weight:600}
#ed{flex:1;display:flex;flex-direction:column;min-width:0;position:relative}
textarea{flex:1;width:100%;box-sizing:border-box;resize:none;border:0;outline:0;background:#141418;color:#e8e8ec;padding:12px 14px;
  font-family:Menlo,monospace;font-size:FSpx;line-height:1.5}
#ac{position:absolute;display:none;background:#22222a;border:1px solid #3a3a46;border-radius:8px;padding:4px 0;min-width:220px;max-height:260px;overflow:auto;box-shadow:0 8px 24px rgba(0,0,0,.5);z-index:5}
#ac div{padding:4px 12px;cursor:pointer;white-space:nowrap}
#ac div.sel{background:#4a7fe0;color:#fff}
#links{width:22%;min-width:170px;border-left:1px solid #26262e;background:#17171c;overflow:auto;padding:8px 0}
#links h4{margin:6px 12px 4px;opacity:.55;font-size:FS2px;letter-spacing:.05em;font-weight:600}
#links ul{list-style:none;margin:0;padding:0}
#links li{padding:4px 12px;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#links li:hover{background:#22222a}
#links li.ghost{opacity:.6}
#links .none{opacity:.4;padding:2px 12px;font-size:FS2px}
#qres .qcols{display:block;opacity:.55;font-size:FS2px;padding-left:2px}
#rows li.sec{opacity:.55;font-size:FS2px;letter-spacing:.05em;font-weight:600;cursor:default;padding:8px 12px 3px}
#rows li.tab{display:flex;align-items:center;gap:6px}
#rows li.tab .tt{flex:1;overflow:hidden;text-overflow:ellipsis}
#rows li.tab .x{opacity:.45;padding:0 3px}
#rows li.tab .x:hover{opacity:1}
#rows li.tab.capture{box-shadow:inset 3px 0 0 #4fb3d9}
#rows li.tab.append{box-shadow:inset 3px 0 0 #e0b04a}
#rows li.add{opacity:.6;font-size:FS1px}
#links li.hist{opacity:.8}
#graph{flex:1;display:none;position:relative;background:#101014}
#graph canvas{width:100%;height:100%;display:block}
#gtip{position:absolute;left:12px;bottom:10px;opacity:.55;font-size:FS2px;pointer-events:none}
body.graph #ed,body.graph #links{display:none}
body.graph #graph{display:block}
/* 6.186.0 — the board takes the WHOLE window. Columns need width and the
   right pane has none; the notes list would only halve what is left. */
#board{flex:1;display:none;flex-direction:column;background:#141419;min-width:0}
body.board #ed,body.board #links,body.board #side{display:none}
body.board #board{display:flex}
#bcols{flex:1;display:flex;gap:10px;overflow-x:auto;padding:10px 12px;align-items:flex-start}
#bcols .col{flex:0 0 240px;max-height:100%;display:flex;flex-direction:column;background:#1b1b22;
  border:1px solid #2b2b35;border-radius:8px;min-height:80px}
#bcols .col.over{border-color:#5a7fd0;background:#20242f}
#bcols .col.more{opacity:.6;flex:0 0 200px}
#bcols .ch{padding:7px 10px;font-size:FS2px;font-weight:600;letter-spacing:.04em;border-bottom:1px solid #2b2b35;
  display:flex;gap:6px;align-items:center}
#bcols .ch .cn{opacity:.5;margin-left:auto;font-weight:400}
#bcols .col.empty .ch{opacity:.55}
#bcols .cards{overflow-y:auto;padding:6px;display:flex;flex-direction:column;gap:6px}
#bcols .card{background:#23232c;border:1px solid #33333f;border-radius:6px;padding:6px 8px;cursor:grab;
  font-size:FS1px;line-height:1.35;user-select:none}
#bcols .card:hover{background:#2c3a5a;border-color:#4a5c86}
#bcols .card .cf{display:block;opacity:.55;font-size:FS2px;padding-top:2px}
#bcols .card.ghost{opacity:.3}
#bdrag{position:fixed;z-index:98;pointer-events:none;background:#2c3a5a;border:1px solid #6a83bd;border-radius:6px;
  padding:6px 8px;font-size:FS1px;max-width:230px;box-shadow:0 8px 22px rgba(0,0,0,.6);display:none}
#btip{padding:5px 14px;font-size:FS2px;opacity:.55;border-top:1px solid #26262e}
#btip .bad{color:#e0b04a;opacity:1}
[hidden]{display:none!important}
#mode{padding:6px 12px 0;font-size:FS2px;opacity:.7}
#mode.search{color:#8fb4ff}
#mode.tasks{color:#e0b04a}
#rows li.tag{display:flex}
#rows li.tag .ct{opacity:.5;margin-left:auto}
#rows li.tpl{opacity:.75}
#rows li.hit,#rows li.task{white-space:normal;font-size:FS1px}
.hn{font-weight:600}
.hl{opacity:.5;margin:0 6px}
.hx{opacity:.8}
#foot{padding:3px 14px;font-size:FS2px;opacity:.5;border-top:1px solid #26262e}
#foot .tip{opacity:1;color:#9fb6e8}
/* 6.175.0 — the format bar. LL: "I don't write markdown." Every button
   types the syntax for you AND its tooltip shows what it typed, so the
   bar teaches itself out of a job. */
#fmt{display:flex;gap:2px;padding:4px 10px;border-bottom:1px solid #26262e;background:#191920;flex-wrap:wrap}
#fmt button{background:#22222a;border:1px solid #32323c;color:#c8c8d4;border-radius:6px;padding:2px 8px;font-size:FS2px;cursor:pointer;font-family:inherit}
#fmt button:hover{background:#2c3a5a;color:#fff}
#fmt .gap{width:8px}
#fmt b{font-weight:700}#fmt i{font-style:italic}
#ac .md{opacity:.55;margin-left:10px;font-family:Menlo,monospace}
#chips{padding:2px 12px 6px}
.chip{display:inline-block;background:#2c3a5a;border-radius:10px;padding:1px 8px;margin:2px 4px 2px 0;cursor:pointer;font-size:FS2px}
#outline li.l2{padding-left:24px}
#outline li.l3{padding-left:36px}
#outline li.l4{padding-left:48px}
#outline li.l5{padding-left:60px}
#outline li.l6{padding-left:72px}
#unl li{opacity:.85}
#ac div.sec{opacity:.55;font-size:FS2px;cursor:default}
/* 6.190.0 — LL: "Can I get a window that is larger than this? I can't
   see what I'm typing?" That was hs.dialog.textPrompt, a stock macOS
   alert whose size is fixed by AppKit — Hammerspoon exposes no width for
   it, so the answer is not a bigger alert, it is not an alert. This is a
   naming bar drawn IN the window, at the window's own width and the
   window's own font. */
#pr{position:absolute;left:6%;right:6%;top:22%;display:none;background:#22222a;
    border:1px solid #4a7fe0;border-radius:10px;padding:16px 18px;
    box-shadow:0 12px 36px rgba(0,0,0,.6);z-index:8}
#pr .lab{opacity:.75;margin-bottom:8px}
#pr input{width:100%;box-sizing:border-box;font-size:FS1px;padding:10px 12px;
    background:#16161c;color:#e8e8ee;border:1px solid #4a7fe0;border-radius:8px}
#pr .hint{opacity:.5;margin-top:8px;font-size:FS2px}
/* 6.203.0 — the refusal, under the field it is about. An hs.alert draws
   UNDER this window, so this is the only place LL can actually read one
   while he is typing in the bar. */
#pr .warn{display:none;margin-top:10px;color:#ffb4b4;font-size:FS2px;line-height:1.45}
/* 6.181.0 — OUR OWN TOOLTIPS. Every button in this window already
   carried a title="", and LL still asked for tool tips — because a
   WKWebView panel that never activates does not reliably raise the
   native yellow box. So the page reads each title into data-tip on
   first hover, removes the attribute (no double tooltip if macOS does
   draw one) and paints its own. It degrades: if the script never runs
   the titles are simply left where they were. */
#tip{position:fixed;display:none;z-index:99;background:#2a2a33;color:#f0f0f4;border:1px solid #3f3f4c;
  border-radius:6px;padding:4px 9px;font-size:FS2px;max-width:340px;pointer-events:none;
  box-shadow:0 6px 18px rgba(0,0,0,.55)}
]==] .. theme .. [==[
</style></head><body class="]==] .. ((v.view == "graph" or v.view == "board") and v.view or "") .. [==["><div id="wrap">
<header id="hdr"><span class="name">]==] .. (isTab and "📝 Scorp Pad" or "🕸 Vault") .. [==[</span><span class="doc" title="]==] .. escapeHtml(d and d.rel or "") .. [==[">]==] .. escapeHtml(d and d.name or "no note open") .. [==[</span>
<span class="hint" id="hint">]==] .. escapeHtml(status) .. [==[</span>
]==] .. (v.lastSaveErr and ('<span class="bad" title="' .. escapeHtml(v.lastSaveErr) .. '">⚠ not saved</span>') or "") .. [==[
]==] .. (sp and '<button onclick="say({a:\'tabnew\'})" title="New scratch tab ⌘T">📝+</button>' or "") .. [==[
]==] .. (isTab and '<button onclick="say({a:\'tabclose\', tid: CUR.slice(8)})" title="Close this tab ⌘W (its text goes to the history)">⌘W</button><button onclick="say({a:\'send\'})" title="Create today\'s Asana task now instead of waiting for 16:00">→ Asana now</button>' or "") .. [==[
<button onclick="say({a:'new'})" title="New note ⌘N">✚</button>
<button onclick="say({a:'daily'})" title="Today ⌘D">📅</button>]==] .. dailyBtns .. [==[<button onclick="tplPick('insert')" title="Insert a template ⌘⇧T">📄</button>
<button onclick="say({a:'linkfile'})" title="Link a file ⌘K">📎</button>
<button id="sbtn" onclick="setMode('search')" title="Search inside every note ⌘⇧F">🔎</button><button id="kbtn" class="]==] .. (v.mode == "tasks" and "on" or "") .. [==[" onclick="setMode(MODE==='tasks'?'notes':'tasks')" title="Every open task ⌘⇧K">☑</button>
<button id="gbtn" class="]==] .. (v.view == "graph" and "on" or "") .. [==[" onclick="say({a:'graph'})" title="Graph ⌘G">🕸</button>
<button id="bbtn" class="]==] .. (v.view == "board" and "on" or "") .. [==[" onclick="say({a:'board'})" title="Board ⌘⇧B — your notes as Kanban columns, grouped by a front-matter field. Drag a card and it rewrites that note's field.">🗂</button>
<button onclick="say({a:'rescan'})" title="Rescan the folder">↻</button>
<button id="pin" class="]==] .. (v.pinned and "on" or "") .. [==[" onclick="say({a:'pin'})" title="Pin: the window stays up beside the app; Esc only hands the keyboard back">📌</button>
<button onclick="say({a:'hide'})" title="Close ⇪3 / ⇪1 / Esc">✕</button></header>
<div id="tip"></div>
<div id="main">
<div id="side"><div id="mode" hidden></div><input id="q" placeholder="filter notes… ⌘F" value="]==] .. escapeHtml(v.mode == "notes" and v.filter or "") .. [==["><ul id="rows"></ul></div>
<div id="ed">]==] .. (v.formatBar == false and "" or [==[<div id="fmt">
<button onclick="blockAt('# ')" title="Heading 1 — types &quot;# &quot; at the start of the line">H1</button>
<button onclick="blockAt('## ')" title="Heading 2 — types &quot;## &quot;">H2</button>
<span class="gap"></span>
<button onclick="wrapSel('**')" title="Bold ⌘B — wraps the words in **stars**"><b>B</b></button>
<button onclick="wrapSel('*')" title="Italic ⌘I — wraps the words in *one star*"><i>I</i></button>
<button onclick="wrapSel('`')" title="Code ⌘E — wraps the words in `back ticks`">&lt;/&gt;</button>
<span class="gap"></span>
<button onclick="blockAt('- ')" title="Bullet list — types &quot;- &quot;; ⏎ keeps the list going">•</button>
<button onclick="blockAt('1. ')" title="Numbered list — types &quot;1. &quot;; ⏎ counts on for you">1.</button>
<button onclick="toggleTask()" title="Task ⌘L — types &quot;- [ ] &quot;, and ⌘L again ticks it">☑</button>
<button onclick="blockAt('&gt; ')" title="Quote — types &quot;&gt; &quot; at the start of the line">&#10077;</button>
<span class="gap"></span>
<button onclick="insertAtCaret('[[', ']]')" title="Link to another note — types [[ ]] and lists your notes to pick from">[[ ]]</button>
<button onclick="insertAtCaret('#')" title="Tag — type a word after the # and it joins the 🏷 TAGS list">#</button>
<button onclick="slashMenu()" title="Every block, in a list — or just type / at the start of an empty line">/ …</button>
</div>]==]) .. [==[<textarea id="t" spellcheck="true" ]==] .. (d and "" or "disabled placeholder=\"⌘N a new note · ⌘D today · click a note on the left\"") .. [==[>]==] .. "\n" .. escapeHtml(d and d.text or "") .. [==[</textarea><div id="ac"></div><div id="pr"><div class="lab" id="prlab"></div><input id="prin" spellcheck="false"><div class="warn" id="prwarn"></div><div class="hint">⏎ create · esc cancel</div></div><div id="foot"></div></div>
<div id="links">]==] .. (isTab and "" or '<div id="chips" hidden></div>') .. [==[<h4>LINKS OUT</h4><ul id="outs">]==] .. (#outs > 0 and table.concat(outs) or '<div class="none">type [[ to link</div>') .. [==[</ul>
]==] .. (isTab and ('<h4>HISTORY · closed tabs</h4><ul id="hist">' .. (#hist > 0 and table.concat(hist) or '<div class="none">closed tabs land here — ⌘W</div>') .. '</ul>')
             or ('<h4>BACKLINKS</h4><ul id="backs">' .. (#backs > 0 and table.concat(backs) or '<div class="none">nothing links here yet</div>') .. '</ul>' .. unlBlock .. '<div id="qbox" hidden><h4 id="qh">\240\159\148\142 QUERY</h4><ul id="qres"></ul></div><h4>OUTLINE</h4><ul id="outline"></ul>')) .. [==[</div>
<div id="graph"><canvas id="cv"></canvas><div id="gtip">click a dot to open · drag to untangle · hollow = not written yet · ⌘G back</div></div>
<div id="board"><div id="bcols"></div><div id="btip"></div></div><div id="bdrag"></div>
</div></div>
<script>
// 6.181.0 — the tooltip layer. Delegated, so buttons drawn later (the
// day-shift pair, the format bar, a row with a title) get it too.
(function(){
  var tip = null, TIPGAP = TIPGAPPX;
  function box(){ if (!tip) tip = document.getElementById('tip'); return tip; }
  // 6.191.0 — returns the ELEMENT that carries the tip, not just its text.
  // The tip is anchored to that element (see below); anchoring it to the
  // POINTER put it under the mouse cursor's own arrow, which is what LL
  // was looking at: "my mouse cursor blacks the icon tool tip".
  function tipEl(el){
    while (el && el !== document.body) {
      if (el.getAttribute) {
        var t = el.getAttribute('data-tip');
        if (t === null) {
          var native = el.getAttribute('title');
          if (native) { el.setAttribute('data-tip', native); el.removeAttribute('title'); t = native; }
        }
        if (t) return el;
      }
      el = el.parentNode;
    }
    return null;
  }
  document.addEventListener('mouseover', function(e){
    var b = box(); if (!b) return;
    var el = tipEl(e.target);
    if (!el) { b.style.display = 'none'; return; }
    b.textContent = el.getAttribute('data-tip');
    b.style.display = 'block';
    // Measured only once it is VISIBLE, so the size is the real one,
    // then folded back inside the window rather than off its edge.
    var r = b.getBoundingClientRect(), a = el.getBoundingClientRect();
    // 6.191.0 — BELOW the button by TIPGAP, centred on it. Below and not
    // above because these buttons live in the header and the format bar,
    // both at the TOP of the window: above them is off the edge. The gap
    // clears the pointer arrow, which is what used to sit on the tip.
    var x = a.left + (a.width - r.width) / 2, y = a.bottom + TIPGAP;
    if (y + r.height > window.innerHeight - 6) y = a.top - r.height - TIPGAP;
    if (x + r.width  > window.innerWidth  - 6) x = window.innerWidth - r.width - 6;
    b.style.left = Math.max(4, x) + 'px';
    b.style.top  = Math.max(4, y) + 'px';
  }, true);
  document.addEventListener('mouseout', function(){ var b = box(); if (b) b.style.display = 'none'; }, true);
  window.addEventListener('blur', function(){ var b = box(); if (b) b.style.display = 'none'; });
})();
var NOTES = ]==] .. v.notesJson() .. [==[;
var GRAPH = ]==] .. v.graphJson() .. [==[;
var CUR = ]==] .. jstr(d and d.rel or "") .. [==[;
var CURKEY = ]==] .. jstr(d and d.key or "") .. [==[, CURNAME = ]==] .. jstr(d and d.name or "") .. [==[;
var CARET = ]==] .. tostring(tonumber(v.caret) or 0) .. [==[;
var VIEW = ]==] .. jstr(v.view) .. [==[;
var TABS = []==] .. table.concat(tabsJs, ",") .. [==[], HASPAD = ]==] .. (sp and "true" or "false") .. [==[;
// 6.174.0 — Lua's state for the page (page: setMode/drawRows/setRows/setMentions/vaultHint/gotoLine read these)
var MODE = ]==] .. jstr(v.mode) .. [==[;
var TAGS = ]==] .. v.tagsJson() .. [==[;
var TAGROWS = ]==] .. tostring(math.floor(tonumber(v.tagRows) or 15)) .. [==[;
var TEMPLATES = ]==] .. v.templatesJson() .. [==[;
var TPLDIR = ]==] .. jstr(v.templatesDir or "") .. [==[;
var SEARCH = {q:]==] .. jstr(v.searchQuery) .. [==[, rows:]==] .. jarr(v.searchRows) .. [==[, more:]==] .. tostring(v.searchMore == true) .. [==[, err:]==] .. jstr(v.searchErr or "") .. [==[, busy:]==] .. tostring(v.searching == true) .. [==[};
var TASKS = {rows:]==] .. jarr(v.taskRows) .. [==[, more:]==] .. tostring(v.taskMore == true) .. [==[, err:]==] .. jstr(v.tasksErr or "") .. [==[, listed:]==] .. tostring(v.lastTasks ~= nil) .. [==[};
var UNL = {key:]==] .. jstr(u.key or "") .. [==[, rows:]==] .. jarr(unlRows) .. [==[, pending:]==] .. tostring(u.pending == true) .. [==[, why:]==] .. jstr(u.why or (u.more and "more" or "")) .. [==[};
var CARETLINE = ]==] .. tostring(math.floor(tonumber(v.caretLine) or 0)) .. [==[;
var CARETHEAD = ]==] .. (v.caretHead and jstr(v.caretHead) or "null") .. [==[;
var DAILY = ]==] .. dailyJs .. [==[;
var SMARTLISTS = ]==] .. tostring(v.smartLists ~= false) .. [==[;
var BOARDFIELD = ]==] .. jstr(tostring(v.boardField or "status"):lower()) .. [==[;
var BOARDCOLS = ]==] .. tostring(math.floor(tonumber(v.boardCols) or 8)) .. [==[, BMAX = ]==] .. tostring(math.floor(tonumber(v.boardMax) or 300)) .. [==[;
var LINEH = FSNUM * 1.5;
var t = document.getElementById('t'), q = document.getElementById('q'), hdr = document.getElementById('hdr');
var ac = document.getElementById('ac'), rowsEl = document.getElementById('rows');
// 🚨 6.203.0 — THREE RESERVED KEYS. say() stamps the live note onto EVERY
// message, on purpose: that is how the draft reaches Lua ahead of the save
// (handleMessage's first line is v.setText(body.text)). The cost is that
// `text`, `sel` and `rel` are say's, not yours — set one and it is silently
// replaced, with nothing to see. That cost went unpaid for thirteen
// releases and TWO features were quietly wrong the whole time:
//   · ⌘N sent {text: the typed name} and Lua got the WHOLE OPEN NOTE
//     instead, so the vault created a note named after its own body and
//     the name LL typed was never used at all. With no note open it sent
//     "" and did nothing — his "I enter a title and I don't see that
//     anything was created", exactly.
//   · the board (6.186.0) sent {rel: the dragged card} and Lua got CUR,
//     so a drag rewrote a field of whichever note was OPEN. The one view
//     that writes, writing to the wrong file.
// A message that carries its own value uses ITS OWN key — `name`, `card` —
// and test_vault_js asserts against this source that no say({…}) ever
// names one of the three again.
function say(m){ m.text = t.value; m.sel = t.selectionStart; m.rel = CUR;
  try { window.webkit.messageHandlers.vault.postMessage(m); } catch(e){} }
t.addEventListener('input', function(){ say({a:'edit'}); autocomplete(); paneSoon(); });
hdr.addEventListener('mousedown', function(e){ if (e.button !== 0 || e.target.tagName === 'BUTTON') return;
  e.preventDefault(); hdr.classList.add('dragging'); say({a:'dragStart'}); });
window.addEventListener('mouseup', function(){ hdr.classList.remove('dragging'); });
document.addEventListener('keyup', function(e){
  if (e.key === 'F18' || e.keyCode === 79) say({a:'f18up'}); });

// ---- 6.174.0 — the page's other elements (looked up once, every use guarded) ----
var modeEl = document.getElementById('mode'), foot = document.getElementById('foot'), chips = document.getElementById('chips');
var outlineEl = document.getElementById('outline'), unl = document.getElementById('unl'), unlh = document.getElementById('unlh');
var hint = document.getElementById('hint'), kbtn = document.getElementById('kbtn');
var qbox = document.getElementById('qbox'), qres = document.getElementById('qres'), qh = document.getElementById('qh');
var bcols = document.getElementById('bcols'), btip = document.getElementById('btip'), bdrag = document.getElementById('bdrag');
var HINT0 = (hint && hint.textContent) || '', PANE_T = null;
var PLACEHOLDER = { notes: 'filter notes… ⌘F', search: 'words… ("a phrase", tag:x, path:x) — ⏎ opens at the line', tasks: 'filter the tasks…' };

// ---- the note list (filtered) ----
function esc(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;'); }
// "#work" in the box → "work"; a plain filter → null
function tagFilter(){ var f = (q.value || '').trim(); return f.charAt(0) === '#' ? f.slice(1).toLowerCase() : null; }
// tagged x, or x/…; while typing (no tag equals x yet) a prefix counts too
function noteHasTag(x, tag, exact){
  var g = x.g || [];
  for (var i = 0; i < g.length; i++) { var tg = g[i]; if (tg === tag || tg.indexOf(tag + '/') === 0 || (!exact && tg.indexOf(tag) === 0)) return true; }
  return false;
}
function drawRows(){
  if (MODE === 'search') { drawSearchRows(); return; }
  if (MODE === 'tasks') { drawTaskRows(); return; }
  var f = (q.value || '').toLowerCase().trim(), h = [], n = 0, s = [], tag = tagFilter();
  if (tag !== null) f = '';
  // 6.173.0 — the Scorp Pad's tabs first, a section of their own (hidden under a # filter)
  if (HASPAD && tag === null) {
    for (var j = 0; j < TABS.length; j++) {
      var tb = TABS[j];
      if (f && tb.t.toLowerCase().indexOf(f) < 0) continue;
      s.push('<li class="tab' + (tb.k ? ' ' + esc(tb.k) : '') + ('scratch:' + tb.id === CUR ? ' cur' : '') + '" data-tab="' + esc(tb.id) + '"><span class="tt">' + (tb.b ? esc(tb.b) + ' ' : '') + esc(tb.t) + '</span><span class="x" title="Close ⌘W">×</span></li>');
    }
    // 6.182.0 — ONE section, and the two old doors are rows in it. LL:
    // "can we remove Scratch and Capture, and have a combined section
    // called Scratch notes?" They were already one section of tabs — what
    // made them feel separate was that 🗒 Capture and ➕ Append each had
    // their own hyper key. These rows call the same openKind those keys
    // called, so both pads keep their brains and neither keeps a key.
    s.unshift('<li class="sec">📝 SCRATCH NOTES</li>');
    if (!f) { s.push('<li class="add" data-tab="+">+ new tab ⌘T</li>');
              s.push('<li class="add" data-tab="+capture">+ 🗒 Capture — ⌘W queues it for the 4 PM Asana send</li>');
              s.push('<li class="add" data-tab="+append">+ ➕ Append — * idea · + log · ! task · ? note</li>'); }
    s.push('<li class="sec">🕸 NOTES</li>');
  } else if (HASPAD) s.push('<li class="sec">🕸 NOTES</li>');
  var exact = false;
  if (tag !== null) for (var e2 = 0; e2 < TAGS.length; e2++) if (TAGS[e2].k === tag) { exact = true; break; }
  for (var i = 0; i < NOTES.length; i++) {
    var x = NOTES[i];
    if (x.tpl) continue;                                   // 6.174.0 — templates sit in their own section below
    if (tag !== null) { if (!noteHasTag(x, tag, exact)) continue; }
    else if (f && x.n.toLowerCase().indexOf(f) < 0 && x.r.toLowerCase().indexOf(f) < 0) continue;
    h.push('<li class="note' + (x.r === CUR ? ' cur' : '') + '" data-name="' + esc(x.n) + '" title="' + esc(x.r) + '">' + esc(x.n) + '</li>');
    if (++n >= 400) break;
  }
  if (!h.length) h.push('<li style="opacity:.4;cursor:default">' + (tag !== null ? 'no note carries #' + esc(tag) : (f ? 'no note matches — ⏎ creates &quot;' + esc(q.value.trim()) + '&quot;' : 'no notes yet — ⌘N')) + '</li>');
  // 6.195.0 — LL: "can I have a way to quickly create a Hammer-sidian note
  // like I do with the notepad section where I can click a +/plus". The
  // same shape as the pad's "+ new tab ⌘T", one section down, and it goes
  // to the SAME v.newNote() ⌘N calls — not a second creation path.
  // Hidden under a filter or a #tag, exactly like the pad's + rows: with
  // a filter typed, ⏎ already creates that name.
  // 🚨 data-new, NOT data-tab: the row walker's ROWSEL matches data-name /
  // data-tab / data-tag, and a + row at the TOP of the notes would make
  // ⌥↓ land on "new note" instead of the first note. It is a CLICK target
  // — which is what LL asked for — and ⌘N is the keyboard path it calls.
  if (tag === null && !f) h.unshift('<li class="add" data-new="1">+ new note ⌘N</li>');
  // 6.174.0 — 📄 TEMPLATES (never under a # filter), then 🏷 TAGS
  var tp = [];
  if (tag === null) for (var k = 0; k < NOTES.length; k++) {
    var y = NOTES[k];
    if (!y.tpl || (f && y.n.toLowerCase().indexOf(f) < 0 && y.r.toLowerCase().indexOf(f) < 0)) continue;
    tp.push('<li class="tpl' + (y.r === CUR ? ' cur' : '') + '" data-name="' + esc(y.n) + '" title="' + esc(y.r) + '">📄 ' + esc(y.n) + '</li>');
  }
  if (tp.length) tp.unshift('<li class="sec">📄 TEMPLATES</li>');
  var tg = [];
  if (TAGS.length) {
    var list = TAGS, more = 0;
    if (tag !== null) list = TAGS.filter(function(z){ return z.k.indexOf(tag) >= 0; }).sort(function(a, b){ return a.k < b.k ? -1 : (a.k > b.k ? 1 : 0); });
    else if (TAGS.length > TAGROWS) { list = TAGS.slice(0, TAGROWS); more = TAGS.length - TAGROWS; }
    if (list.length) {
      tg.push('<li class="sec">🏷 TAGS · ' + (tag !== null ? list.length : TAGS.length) + '</li>');
      for (var m2 = 0; m2 < list.length; m2++) tg.push('<li class="tag" data-tag="' + esc(list[m2].k) + '"><span class="tt">#' + esc(list[m2].n) + '</span><span class="ct">' + list[m2].c + '</span></li>');
      if (more) tg.push('<li class="sec">… ' + more + ' more — type # in the box</li>');
    }
  }
  rowsEl.innerHTML = s.join('') + h.join('') + tp.join('') + tg.join('');
  SEL = -1;
}
// 6.174.0 — 🔎 SEARCH: the rows Lua sent (note · line · snippet), the status in the strip
function drawSearchRows(){
  var h = [], rows = SEARCH.rows || [], files = {}, nf = 0, st;
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i];
    if (!files[r.r]) { files[r.r] = true; nf++; }
    h.push('<li class="hit" data-name="' + esc(r.n) + '" data-line="' + (r.l || 0) + '" title="' + esc(r.r) + '"><span class="hn">' + esc(r.n) + '</span>' + (r.l ? '<span class="hl">' + r.l + '</span>' : '') + '<span class="hx">' + esc(r.x || '') + '</span></li>');
  }
  if (SEARCH.more) h.push('<li class="sec">… more than ' + rows.length + ' hits — narrow the words</li>');
  if (!(q.value || '').trim()) st = 'type words — every note is searched';
  else if (SEARCH.busy) st = 'searching…';
  else if (SEARCH.err) st = '⚠ ' + SEARCH.err;
  else st = rows.length ? rows.length + ' hit' + (rows.length === 1 ? '' : 's') + ' in ' + nf + ' note' + (nf === 1 ? '' : 's') : 'no hit';
  if (modeEl) modeEl.textContent = '🔎 SEARCH every note · Esc back · ' + st;
  rowsEl.innerHTML = h.join('');
  SEL = -1;
}
// 6.174.0 — ☑ TASKS: every open task Lua listed, the box filters them here
function drawTaskRows(){
  var f = (q.value || '').toLowerCase().trim(), h = [], rows = TASKS.rows || [];
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i];
    if (f && r.n.toLowerCase().indexOf(f) < 0 && (r.x || '').toLowerCase().indexOf(f) < 0) continue;
    h.push('<li class="task" data-name="' + esc(r.n) + '" data-line="' + (r.l || 0) + '" title="' + esc(r.r) + '">☐ ' + esc(r.x || '') + '<span class="hl">' + esc(r.n) + '</span></li>');
  }
  if (TASKS.more) h.push('<li class="sec">… more than ' + rows.length + ' tasks</li>');
  if (!h.length) h.push('<li style="opacity:.4;cursor:default">' + (!TASKS.listed ? 'loading…' : (rows.length ? 'no task matches' : 'no open task — ⌘L makes one')) + '</li>');
  if (modeEl) modeEl.textContent = '☑ TASKS · ' + rows.length + (TASKS.more ? '+' : '') + ' open · Esc back' + (TASKS.err ? ' · ⚠ ' + TASKS.err : '');
  rowsEl.innerHTML = h.join('');
  SEL = -1;
}
rowsEl.addEventListener('click', function(e){
  var li = e.target.closest ? e.target.closest('li[data-name],li[data-tab],li[data-tag],li[data-new]') : null; if (!li) return;
  if (li.getAttribute('data-new')) { say({a:'newnote'}); return; }
  var tid = li.getAttribute('data-tab');
  if (tid && tid.charAt(0) !== '+' && e.target.closest && e.target.closest('.x')) say({a:'tabclose', tid: tid});
  else rowAct(li); });
document.getElementById('links').addEventListener('click', function(e){
  var li = e.target.closest ? e.target.closest('li[data-name],li[data-hist]') : null; if (!li) return;
  if (li.getAttribute('data-hist')) say({a:'restore', rid: li.getAttribute('data-hist')});
  else say({a:'open', name: li.getAttribute('data-name')}); });
if (outlineEl) outlineEl.addEventListener('click', function(e){
  var li = e.target.closest ? e.target.closest('li[data-line]') : null; if (li) gotoLine(+li.getAttribute('data-line')); });
if (chips) chips.addEventListener('click', function(e){
  var c = e.target.closest ? e.target.closest('[data-tag]') : null; if (c) setFilter('#' + c.getAttribute('data-tag')); });
q.addEventListener('input', function(){
  if (MODE === 'search') { SEARCH.q = q.value; SEARCH.busy = !!q.value.trim(); SEARCH.err = ''; say({a:'search', q: q.value}); drawRows(); }
  else if (MODE === 'tasks') drawRows();
  else { say({a:'filter', f: q.value}); drawRows(); } });
q.addEventListener('keydown', function(e){
  if (e.key !== 'Enter' || SEL >= 0) return;
  // notes: ⏎ creates the typed name — never one called "#x"; search / tasks: the first hit
  if (MODE === 'notes') { var f = q.value.trim(); if (f && f.charAt(0) !== '#') { e.preventDefault(); say({a:'open', name: f}); } return; }
  var r = rowsList()[0]; if (r) { e.preventDefault(); rowAct(r); }
});
// a tag row / chip → the notes list narrowed to that tag
function setFilter(s){
  if (MODE !== 'notes') setMode('notes');
  q.value = s; say({a:'filter', f: s}); drawRows();
}
// the left column's three faces; Lua is told unless `quiet` (the load sequence)
function setMode(m, quiet){
  if (m !== 'search' && m !== 'tasks') m = 'notes';
  var was = MODE; MODE = m;
  if (was === 'search' && m !== 'search') { SEARCH.q = ''; SEARCH.rows = []; SEARCH.more = false; SEARCH.busy = false; SEARCH.err = ''; }
  if (m === 'search') q.value = SEARCH.q || ''; else if (was !== m) q.value = '';
  q.placeholder = PLACEHOLDER[m];
  if (modeEl) { modeEl.hidden = (m === 'notes'); modeEl.className = m; }
  if (kbtn) kbtn.classList.toggle('on', m === 'tasks');
  if (!quiet) say({a:'mode', m: m});
  drawRows();
  q.focus();
}
// ---- Lua → page, without a rebuild (v.eval) ----
function setRows(kind, rows, more, qq){
  if (kind === 'search') { if (MODE !== 'search' || qq !== SEARCH.q) return; SEARCH.rows = rows || []; SEARCH.more = !!more; SEARCH.busy = false; drawRows(); }
  else if (kind === 'tasks') { TASKS.rows = rows || []; TASKS.more = !!more; TASKS.listed = true; if (MODE === 'tasks') drawRows(); }
}
function setMentions(rows, key, why){ if (key !== UNL.key) return; UNL.rows = rows || []; UNL.pending = false; UNL.why = why || ''; drawUnlinked(); }
function vaultHint(s){ if (hint) hint.textContent = s || HINT0; }

// ⌨️ 6.170.0 — ARROW THROUGH THE ROWS. ⌥↑/⌥↓ always; plain ↑/↓ when the
// caret is not in the text; ⏎ / ⌥⏎ acts on the highlighted row.
// 6.174.0 — tag rows, template rows, search hits and tasks are rows too.
var SEL = -1, ROWSEL = '#rows li[data-name],#rows li[data-tab],#rows li[data-tag]';
function rowsList(){ try { return Array.prototype.slice.call(document.querySelectorAll(ROWSEL)); } catch(e){ return []; } }
function inText(){ var a = null; try { a = document.activeElement; } catch(e){} return !!(a && a.tagName === 'TEXTAREA'); }
function moveSel(d){
  var rows = rowsList(); if (!rows.length) return false;
  var from = SEL < 0 ? (d > 0 ? -1 : rows.length) : SEL;
  SEL = Math.max(0, Math.min(rows.length - 1, from + d));
  for (var i = 0; i < rows.length; i++) { try { if (i === SEL) rows[i].classList.add('sel'); else rows[i].classList.remove('sel'); } catch(e){} }
  try { rows[SEL].scrollIntoView({ block: 'nearest' }); } catch(e){}
  return true;
}
function selRow(){ var rows = rowsList(); return (SEL >= 0 && SEL < rows.length) ? rows[SEL] : null; }
function rowKey(e){
  if (acOpen()) return false;
  var arrow = e.key === 'ArrowDown' ? 1 : (e.key === 'ArrowUp' ? -1 : 0);
  if (arrow && (e.altKey || !inText())) { e.preventDefault(); moveSel(arrow); return true; }
  if (e.key === 'Enter' && !e.metaKey && (e.altKey || !inText())) {
    var r = selRow(); if (r) { e.preventDefault(); rowAct(r); return true; }
  }
  return false;
}
function rowAct(r){
  var tid = r.getAttribute('data-tab'), tag = r.getAttribute('data-tag');
  if (tid === '+') say({a:'tabnew'});

  else if (tid === '+capture' || tid === '+append') say({a:'tabkind', kind: tid.slice(1)});
  else if (tid) say({a:'tab', tid: tid});
  else if (tag) setFilter('#' + tag);
  else { var l = +(r.getAttribute('data-line') || 0), name = r.getAttribute('data-name'); say(l ? {a:'open', name: name, line: l} : {a:'open', name: name}); } }
function isTab(){ return CUR.indexOf('scratch:') === 0; }

// ---- the right pane (notes only): chips, outline, ≈ mentions; the footer for every doc ----
// the JS twin of Lua's v.tagsIn: front matter, fences skipped, Obsidian's grammar
function tagOk(s){
  s = s.replace(/[.,;:!?)\]}'"\/]+$/, '');
  if (!s || !/^[\w\/\-\u0080-\uffff]+$/.test(s) || !/[^\d]/.test(s)) return null;
  return s;
}
function tagsOf(text){
  var lines = String(text || '').split('\n').map(function(l){ return l.replace(/\r$/, ''); }), list = [], seen = {}, i = 0;
  function add(c){ var tg = tagOk(c); if (tg && !seen[tg.toLowerCase()]) { seen[tg.toLowerCase()] = true; list.push(tg); } }
  function fmValue(raw){ raw = raw.trim().replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1'); return raw.trim().replace(/^#/, '').trim(); }
  if (lines[0] === '---') {
    var j = 1; while (j < lines.length && lines[j] !== '---') j++;
    if (j < lines.length) {
      var inList = false;
      for (var f = 1; f < j; f++) {
        var m = lines[f].match(/^tags?:\s*(.*)$/);
        if (m) {
          var value = m[1].trim(); inList = true;
          if (value) {
            var items = value.charAt(0) === '[' ? value.replace(/^\[/, '').replace(/\]$/, '').split(',') : value.split(/[,\s]+/);
            for (var k = 0; k < items.length; k++) if (items[k].trim()) add(fmValue(items[k]));
          }
        } else { var it = inList && lines[f].match(/^\s*-\s+(.+)$/); if (it) add(fmValue(it[1])); else inList = false; }
      }
      i = j + 1;
    }
  }
  var fence = false, re = /(^|\s)#([^\s#]+)/g, mm;
  for (; i < lines.length; i++) {
    var L = lines[i];
    if (/^\s*(```|~~~)/.test(L)) { fence = !fence; continue; }
    if (fence) continue;
    re.lastIndex = 0;
    while ((mm = re.exec(L))) add(mm[2]);
  }
  return list;
}
function drawChips(){
  if (!chips || isTab()) return;
  var tags = tagsOf(t.value || ''), h = [];
  for (var i = 0; i < tags.length; i++) h.push('<span class="chip" data-tag="' + esc(tags[i].toLowerCase()) + '">#' + esc(tags[i]) + '</span>');
  chips.innerHTML = h.join(''); chips.hidden = !h.length;
}
// headings, one row each; fenced code and a leading front-matter block skipped
function outlineOf(v){
  var lines = v.split('\n'), out = [], fence = false, i = 0;
  if (lines[0] === '---') { var j = 1; while (j < lines.length && lines[j] !== '---') j++; if (j < lines.length) i = j + 1; }
  for (; i < lines.length; i++) {
    var L = lines[i];
    if (/^\s*(```|~~~)/.test(L)) { fence = !fence; continue; }
    if (fence) continue;
    var m = L.match(/^(#{1,6})\s+(.+?)\s*#*\s*$/);
    if (m) out.push({ line: i + 1, level: m[1].length, text: m[2] });
  }
  return out;
}
function drawOutline(){
  if (!outlineEl || isTab()) return;
  var hd = outlineOf(t.value || ''), h = [];
  for (var i = 0; i < hd.length; i++) h.push('<li class="hd l' + hd[i].level + '" data-line="' + hd[i].line + '" title="line ' + hd[i].line + '">' + esc(hd[i].text) + '</li>');
  outlineEl.innerHTML = h.length ? h.join('') : '<div class="none">no headings — start a line with #</div>';
}
// the caret to the start of line n (1-based), scrolled a third from the top
function gotoLine(n){
  var lines = t.value.split('\n'), pos = 0;
  for (var i = 0; i < n - 1 && i < lines.length; i++) pos += lines[i].length + 1;
  try { t.setSelectionRange(pos, pos); } catch(e){}
  try { t.scrollTop = Math.max(0, (n - 1) * LINEH - (t.clientHeight || 0) / 3); } catch(e){}
  t.focus();
}
// ≈ UNLINKED MENTIONS — drawn only for the open note's own answer (Lua's
// pre-fill stands otherwise)
function drawUnlinked(){
  if (!unl || isTab() || UNL.key !== CURKEY) return;
  var h = [], rows = UNL.rows || [], why = UNL.why || '', listed = false;
  if (UNL.pending) h.push('<div class="none">looking…</div>');
  else if (why === 'too short') h.push('<div class="none">too short a name to search</div>');
  else if (why === 'unavailable') h.push('<div class="none">unavailable on this Hammerspoon</div>');
  else if (why.indexOf('grep exited') === 0) h.push('<div class="none">⚠ ' + esc(why) + '</div>');
  else if (!rows.length) h.push('<div class="none">no other note mentions "' + esc(CURNAME) + '"</div>');
  else {
    listed = true;
    for (var i = 0; i < rows.length; i++) h.push('<li class="lnk" data-name="' + esc(rows[i].n) + '" title="' + esc(rows[i].r) + '">≈ ' + esc(rows[i].n) + '</li>');
    if (why === 'more') h.push('<div class="none">(first ' + rows.length + ')</div>');
  }
  unl.innerHTML = h.join('');
  if (unlh) unlh.textContent = 'UNLINKED MENTIONS' + (listed ? ' · ' + rows.length : '');
}
// ---- 6.183.0 — 🔎 LIVE QUERIES ------------------------------------------
// LL: "I want to make notes clearly meaningful and see the relationships
// to jog my memory." A ```dataview block in a note LISTS the notes it
// describes, live, in the pane beside the backlinks — written in Obsidian's
// own Dataview grammar (the useful corner of it) so the SAME block renders
// in Obsidian if that plug-in is ever installed, and reads as English
// either way. The "/" menu writes the block, so LL never types it.
//
// 🚨 NOTHING IS WRITTEN. The answer is drawn beside the note, never into
// it: the block stays the only text in the file, so the file cannot drift
// from what you typed and Dataview cannot end up rendering a second copy
// of a table this already wrote. And it reads ONLY what the page already
// holds — name, path, tags, links out — so it costs no file read, no
// grep and no scan, and it redraws 150 ms after a keystroke like the
// outline does. A clause it does not understand is NAMED in the pane and
// the rest of the query still runs; it never fails the note.
var QMAX = 50;
// every fenced block in the text, in order, consuming plain fences too so a
// look-alike line INSIDE ordinary code is never read as a query
function queryBlocks(text){
  var lines = String(text || '').split('\n'), out = [], i = 0;
  while (i < lines.length) {
    var m = lines[i].match(/^\s*(?:```|~~~)\s*([A-Za-z]*)\s*$/);
    if (!m) { i++; continue; }
    var info = (m[1] || '').toLowerCase(), body = [];
    i++;
    while (i < lines.length && !/^\s*(?:```|~~~)\s*$/.test(lines[i])) { body.push(lines[i]); i++; }
    i++;                                   // past the closing fence
    if (info.indexOf('dataview') === 0 || info === 'kanban') out.push({ kind: info, body: body });
  }
  return out;
}
// FROM: OR of AND-groups (Dataview's own precedence), each term a #tag, a
// [[link]] or a "folder", any of them negated with - or !
function parseFrom(src){
  var groups = [], ors = String(src || '').trim();
  if (!ors) return groups;
  ors = ors.split(/\s+or\s+/i);
  for (var i = 0; i < ors.length; i++) {
    var terms = [], ands = ors[i].split(/\s+and\s+/i);
    for (var j = 0; j < ands.length; j++) {
      var s = ands[j].trim(), neg = false;
      while (s.charAt(0) === '-' || s.charAt(0) === '!') { neg = !neg; s = s.slice(1).trim(); }
      s = s.replace(/^\(+/, '').replace(/\)+$/, '').trim();
      var t = null;
      if (!s) continue;
      if (s.charAt(0) === '#') t = { k: 'tag', v: s.slice(1).toLowerCase() };
      else if (/^\[\[[\s\S]*\]\]$/.test(s)) t = { k: 'link', v: s.slice(2, -2).split('|')[0].split('#')[0].trim().toLowerCase() };
      else t = { k: 'folder', v: s.replace(/["']/g, '').trim().toLowerCase() };
      if (t && t.v) { t.neg = neg; terms.push(t); }
    }
    if (terms.length) groups.push(terms);
  }
  return groups;
}
// 6.185.0 — WHERE and a TABLE's columns, off the note's FRONT MATTER.
// The f: on each row is what 6.185.0's widened front-matter grep found;
// four pseudo-fields let a query ask about the file itself, the way
// Dataview's file.* does. A field a note has not got reads as "", which
// is falsy — so `WHERE status` means "has a status", not "errors".
function fieldOf(x, name){
  name = String(name || '').toLowerCase();
  if (name === 'file.name') return String(x.n || '');
  if (name === 'file.path') return String(x.r || '');
  if (name === 'file.folder') { var p = String(x.r || ''), i = p.lastIndexOf('/'); return i < 0 ? '' : p.slice(0, i); }
  if (name === 'file.tags' || name === 'tags' || name === 'tag') return (x.g || []).join(', ');
  return (x.f && x.f[name] != null) ? String(x.f[name]) : '';
}
function unq(s){
  s = String(s || '').trim();
  var a = s.charAt(0), b = s.charAt(s.length - 1);
  if (s.length > 1 && (a === '"' || a === "'") && b === a) return s.slice(1, -1);
  return s;
}
var NUMRE = /^-?\d+(?:\.\d+)?$/;
function qCmp(a, op, b){
  a = String(a); b = String(b);
  if (NUMRE.test(a.trim()) && NUMRE.test(b.trim())) { a = +a; b = +b; }
  else { a = a.toLowerCase(); b = b.toLowerCase(); }
  if (op === '=' || op === '==') return a === b;
  if (op === '!=') return a !== b;
  if (op === '>')  return a > b;
  if (op === '<')  return a < b;
  if (op === '>=') return a >= b;
  if (op === '<=') return a <= b;
  return false;
}
function parseWhereTerm(s){
  s = String(s || '').trim();
  var neg = false, m;
  while (s.charAt(0) === '!' && s.charAt(1) !== '=') { neg = !neg; s = s.slice(1).trim(); }
  if (!s) return null;
  // contains() FIRST — its own closing bracket must not be mistaken for a
  // wrapping one and stripped off (that is how contains() silently died)
  if ((m = s.match(/^contains\s*\(\s*([A-Za-z_][\w.\-]*)\s*,\s*([\s\S]+?)\s*\)$/i)))
    return { k: 'contains', f: m[1], v: unq(m[2]), neg: neg };
  s = s.replace(/^\(+/, '').replace(/\)+$/, '').trim();
  if (!s) return null;
  if ((m = s.match(/^([A-Za-z_][\w.\-]*)\s*(>=|<=|!=|==|=|>|<)\s*([\s\S]+)$/))) {
    // a value that starts with another operator means the operator itself
    // was mistyped (">< 3"); say so rather than comparing against nonsense
    if (/^[<>=!]/.test(m[3].trim())) return null;
    return { k: 'cmp', f: m[1], op: m[2], v: unq(m[3]), neg: neg };
  }
  if ((m = s.match(/^([A-Za-z_][\w.\-]*)$/)))
    return { k: 'has', f: m[1], neg: neg };
  return null;
}
// OR of AND-groups, exactly as FROM does it. A term it cannot read is
// handed back so the pane can NAME it rather than swallow the clause.
function parseWhere(src, bad){
  var groups = [], ors = String(src || '').trim();
  if (!ors) return groups;
  ors = ors.split(/\s+or\s+/i);
  for (var i = 0; i < ors.length; i++) {
    var terms = [], ands = ors[i].split(/\s+and\s+/i);
    for (var j = 0; j < ands.length; j++) {
      var t = parseWhereTerm(ands[j]);
      if (t) terms.push(t); else if (bad && ands[j].trim()) bad.push(ands[j].trim());
    }
    if (terms.length) groups.push(terms);
  }
  return groups;
}
function whereTermOk(x, t){
  var val = fieldOf(x, t.f);
  if (t.k === 'has') return val !== '';
  if (t.k === 'contains') return val.toLowerCase().indexOf(String(t.v).toLowerCase()) >= 0;
  if (val === '' && t.op !== '!=') return false;   // absent is not greater, smaller or equal
  return qCmp(val, t.op, t.v);
}
function whereOk(x, groups){
  if (!groups.length) return true;
  for (var g = 0; g < groups.length; g++) {
    var terms = groups[g], all = true;
    for (var j = 0; j < terms.length; j++) { if (whereTermOk(x, terms[j]) === !!terms[j].neg) { all = false; break; } }
    if (all) return true;
  }
  return false;
}
// TABLE's columns: bare field names, optionally "field AS Alias". Anything
// with a function or an operator in it is handed back to be named.
function parseCols(src, bad){
  var out = [], parts = String(src || '').split(',');
  for (var i = 0; i < parts.length; i++) {
    var p = parts[i].trim();
    if (!p) continue;
    var m = p.match(/^([A-Za-z_][\w.\-]*)(?:\s+as\s+([\s\S]+))?$/i);
    if (m) out.push({ f: m[1], label: unq(m[2] || m[1]) });
    else if (bad) bad.push(p);
  }
  return out;
}
function parseQuery(body, board){
  var cap = board ? BMAX : QMAX;
  var spec = { kind: board ? 'board' : 'list', from: '', groups: [], wheres: [], cols: [], sort: 'name', dir: 1,
               limit: cap, by: BOARDFIELD, columns: null, ignored: [] };
  for (var i = 0; i < body.length; i++) {
    var line = String(body[i] || '').trim(), m;
    if (!line || line.charAt(0) === '/' && line.charAt(1) === '/') continue;
    if ((m = line.match(/^(list|table)\b\s*([\s\S]*)$/i))) {
      spec.kind = m[1].toLowerCase();
      var parts = (m[2] || '').split(/\bfrom\b/i), cols = (parts[0] || '').trim();
      if (parts.length > 1) spec.from = parts.slice(1).join(' from ').trim();
      if (cols) { var badc = []; spec.cols = parseCols(cols, badc);
                  for (var c = 0; c < badc.length; c++) spec.ignored.push('the column "' + badc[c] + '" — a plain field name, or "field AS Label"'); }
      continue;
    }
    // 6.186.0 — the board's own two clauses. BY names the front-matter
    // field the columns ARE; COLUMNS fixes their order (a value it does
    // not name still gets a column after them — nothing vanishes quietly).
    if (board && (m = line.match(/^by\s+([A-Za-z_][\w.\-]*)$/i))) { spec.by = m[1].toLowerCase(); continue; }
    if (board && (m = line.match(/^columns\s+([\s\S]+)$/i))) {
      var cs = m[1].split(','), keep = [];
      for (var y = 0; y < cs.length; y++) { var cv = unq(cs[y].trim()); if (cv) keep.push(cv); }
      spec.columns = keep.length ? keep : null;
      continue;
    }
    if ((m = line.match(/^from\s+([\s\S]+)$/i))) { spec.from = m[1].trim(); continue; }
    if ((m = line.match(/^where\s+([\s\S]+)$/i))) {
      var badw = [], g = parseWhere(m[1], badw);
      for (var w = 0; w < badw.length; w++) spec.ignored.push('WHERE ' + badw[w] + ' — try field, field = "x", field > 3 or contains(field, "x")');
      if (g.length) spec.wheres.push(g);
      continue;
    }
    if ((m = line.match(/^sort\s+([\s\S]+)$/i))) {
      var sv = m[1].trim().split(/\s+/), f0 = (sv[0] || '').toLowerCase();
      // 6.185.0 — name and path stay shorthands; anything else is a
      // front-matter field, sorted numerically when both sides are numbers
      if (f0 === 'name' || f0 === 'file.name') spec.sort = 'name';
      else if (f0 === 'path' || f0 === 'file.path' || f0 === 'folder') spec.sort = 'path';
      else if (/^[A-Za-z_][\w.\-]*$/.test(f0)) spec.sort = f0;
      else spec.ignored.push('SORT ' + sv[0] + ' — a field name, or name / path');
      if (/^desc/i.test(sv[1] || '')) spec.dir = -1;
      continue;
    }
    if ((m = line.match(/^limit\s+(\d+)$/i))) { spec.limit = Math.max(1, Math.min(cap, +m[1])); continue; }
    spec.ignored.push(line);
  }
  spec.groups = parseFrom(spec.from);
  return spec;
}
function qMatch(x, t){
  if (t.k === 'tag') return noteHasTag(x, t.v, true);
  if (t.k === 'link') { var l = x.l || []; for (var i = 0; i < l.length; i++) if (l[i] === t.v) return true; return false; }
  var p = String(x.r || '').toLowerCase(), f = t.v.replace(/\/+$/, '');
  return p.indexOf(f + '/') === 0;
}
function runQuery(spec){
  var out = [];
  for (var i = 0; i < NOTES.length; i++) {
    var x = NOTES[i];
    if (x.tpl) continue;                       // a template is a stencil, not content
    var ok = !spec.groups.length;              // no FROM at all: every note
    for (var g = 0; g < spec.groups.length && !ok; g++) {
      var terms = spec.groups[g], all = true;
      for (var j = 0; j < terms.length; j++) { if (qMatch(x, terms[j]) === !!terms[j].neg) { all = false; break; } }
      if (all) ok = true;
    }
    if (ok) { for (var w = 0; w < spec.wheres.length && ok; w++) ok = whereOk(x, spec.wheres[w]); }
    if (ok) out.push(x);
  }
  var sortKey = function(x){
    if (spec.sort === 'name') return String(x.n || '');
    if (spec.sort === 'path') return String(x.r || '');
    return fieldOf(x, spec.sort);
  };
  out.sort(function(a, b){
    var ka = sortKey(a), kb = sortKey(b);
    if (NUMRE.test(ka.trim()) && NUMRE.test(kb.trim())) { ka = +ka; kb = +kb; }
    else { ka = ka.toLowerCase(); kb = kb.toLowerCase(); }
    // a note without the field sorts LAST either way — it is missing, not smallest
    if (ka === '' && kb !== '') return 1;
    if (kb === '' && ka !== '') return -1;
    return ka < kb ? -spec.dir : (ka > kb ? spec.dir : 0);
  });
  return out;
}
function drawQueries(){
  if (!qbox || !qres) return;
  var all = isTab() ? [] : queryBlocks(t.value || ''), blocks = [];
  // 6.186.0 — a ```kanban block belongs to the BOARD (⌘⇧B). It is not an
  // unsupported query and must not be reported as one.
  for (var z = 0; z < all.length; z++) if (all[z].kind !== 'kanban') blocks.push(all[z]);
  if (!blocks.length) { qres.innerHTML = ''; qbox.hidden = true; return; }
  var h = [], total = 0;
  for (var b = 0; b < blocks.length; b++) {
    if (blocks[b].kind !== 'dataview') {
      h.push('<div class="none">⚠ ' + esc(blocks[b].kind) + ' is JavaScript — never run here</div>');
      continue;
    }
    var spec = parseQuery(blocks[b].body), rows = runQuery(spec), shown = rows.slice(0, spec.limit);
    total += shown.length;
    h.push('<li class="sec">' + esc(spec.kind.toUpperCase() + (spec.from ? ' FROM ' + spec.from : ' — every note')) + ' · ' + rows.length + '</li>');
    for (var i = 0; i < shown.length; i++) {
      // 6.185.0 — a TABLE's columns as a second line under the name: the
      // pane is narrow, and a real grid there would be unreadable
      var extra = '';
      for (var c = 0; c < spec.cols.length; c++) {
        var val = fieldOf(shown[i], spec.cols[c].f);
        if (val !== '') extra += (extra ? ' · ' : '') + esc(spec.cols[c].label) + ': ' + esc(val);
      }
      h.push('<li class="lnk" data-name="' + esc(shown[i].n) + '" title="' + esc(shown[i].r) + '">' + esc(shown[i].n)
             + (extra ? '<span class="qcols">' + extra + '</span>' : '') + '</li>');
    }
    if (!rows.length) h.push('<div class="none">nothing matches yet</div>');
    else if (rows.length > shown.length) h.push('<div class="none">(first ' + shown.length + ' of ' + rows.length + ')</div>');
    for (var k = 0; k < spec.ignored.length; k++) h.push('<div class="none">⚠ ignored: ' + esc(spec.ignored[k]) + '</div>');
  }
  qres.innerHTML = h.join('');
  if (qh) qh.textContent = '🔎 QUERY · ' + total;
  qbox.hidden = false;
}
// ---- 6.186.0 — 🗂 THE BOARD ------------------------------------------------
// A Kanban of the notes themselves: every distinct value of one front-matter
// field is a COLUMN and every note carrying it is a CARD. It runs in the page
// off the same index the queries use, so it costs no file read, no grep and
// no scan — and it is live: change status: in a note and the card has moved
// by the time you look.
//
// 🚨 AND IT WRITES. This is the ONE view in the vault that does, deliberately:
// dragging a card sends Lua the note, the field and the column it landed in,
// and Lua rewrites THAT ONE LINE of that one file. The body is never touched.
// The page does not write anything itself and does not assume the move took —
// Lua re-renders, so a refused move puts the card back where it was.
function boardSpec(){
  var blocks = isTab() ? [] : queryBlocks(t.value || '');
  for (var i = 0; i < blocks.length; i++) if (blocks[i].kind === 'kanban') return parseQuery(blocks[i].body, true);
  return null;
}
// the columns, in order: the ones COLUMNS names, then any other value that
// actually exists, then the notes that have not got the field at all
function boardColumns(spec, rows){
  var out = [], seen = {}, counts = {}, order = [], none = 0;
  for (var i = 0; i < rows.length; i++) {
    var val = fieldOf(rows[i], spec.by);
    if (val === '') { none++; continue; }
    var k = val.toLowerCase();
    if (counts[k] === undefined) { counts[k] = 0; order.push({ k: k, label: val }); }
    counts[k]++;
  }
  if (spec.columns) {
    for (var c = 0; c < spec.columns.length; c++) {
      var ck = String(spec.columns[c]).toLowerCase();
      if (seen[ck]) continue;
      seen[ck] = 1;
      out.push({ k: ck, label: spec.columns[c], n: counts[ck] || 0 });
    }
  } else {
    order.sort(function(a, b){ return counts[b.k] - counts[a.k] || (a.k < b.k ? -1 : a.k > b.k ? 1 : 0); });
  }
  for (var j = 0; j < order.length; j++) if (!seen[order[j].k]) {
    seen[order[j].k] = 1;
    out.push({ k: order[j].k, label: order[j].label, n: counts[order[j].k] });
  }
  // last, always: missing is missing. Dropping a card here CLEARS the field.
  out.push({ k: '', label: 'no ' + spec.by, n: none, none: true });
  return out;
}
function boardCard(x, spec){
  var extra = '';
  for (var c = 0; c < spec.cols.length; c++) {
    if (spec.cols[c].f.toLowerCase() === spec.by) continue;   // that is the column it is in
    var val = fieldOf(x, spec.cols[c].f);
    if (val !== '') extra += (extra ? ' · ' : '') + esc(spec.cols[c].label) + ': ' + esc(val);
  }
  return '<div class="card" data-rel="' + esc(x.r) + '" data-name="' + esc(x.n) + '" title="' + esc(x.r) + '">'
       + esc(x.n) + (extra ? '<span class="cf">' + extra + '</span>' : '') + '</div>';
}
function drawBoard(){
  if (!bcols || !btip) return;
  var spec = boardSpec(), why = '';
  if (!spec) {
    // no block in this note: show every note by the default field and SAY so,
    // rather than an empty window that looks broken
    spec = parseQuery(['BY ' + BOARDFIELD], true);
    why = 'no ```kanban block in this note — showing every note by ' + BOARDFIELD + '. Press / for a Board row that writes one.';
  }
  var rows = runQuery(spec).slice(0, spec.limit), cols = boardColumns(spec, rows), h = [], drawn = 0;
  var shown = cols.slice(0, Math.max(1, BOARDCOLS)), hidden = cols.slice(Math.max(1, BOARDCOLS));
  for (var c = 0; c < shown.length; c++) {
    var col = shown[c], cards = [];
    for (var i = 0; i < rows.length; i++) {
      if (fieldOf(rows[i], spec.by).toLowerCase() === col.k) { cards.push(boardCard(rows[i], spec)); drawn++; }
    }
    h.push('<div class="col' + (cards.length ? '' : ' empty') + '" data-val="' + esc(col.label) + '" data-none="'
           + (col.none ? '1' : '') + '"><div class="ch">' + esc(col.label)
           + '<span class="cn">' + cards.length + '</span></div><div class="cards">' + cards.join('') + '</div></div>');
  }
  if (hidden.length) {
    var names = [];
    for (var k = 0; k < hidden.length; k++) names.push(esc(hidden[k].label) + ' ' + hidden[k].n);
    h.push('<div class="col more"><div class="ch">… ' + hidden.length + ' more</div><div class="cards">'
           + '<div class="card" style="cursor:default">' + names.join('<br>') + '</div></div></div>');
  }
  bcols.innerHTML = h.join('');
  var tips = [];
  if (why) tips.push('<span class="bad">⚠ ' + esc(why) + '</span>');
  for (var g = 0; g < spec.ignored.length; g++) tips.push('<span class="bad">⚠ ignored: ' + esc(spec.ignored[g]) + '</span>');
  tips.push(drawn + ' card' + (drawn === 1 ? '' : 's') + ' · grouped by ' + esc(spec.by)
            + (spec.from ? ' · FROM ' + esc(spec.from) : ''));
  tips.push('drag a card to another column and that note’s <b>' + esc(spec.by)
            + ':</b> line is rewritten · click to open it · ⌘⇧B back to the note');
  btip.innerHTML = tips.join(' · ');
  BSPEC = spec;
}
// ---- the drag. Pointer events, not native drag-and-drop: this panel never
// activates and a WKWebView's own DnD is not dependable in one. A press that
// never moves 4 px is a CLICK and opens the note.
var BSPEC = null, BDRAG = null;
function colUnder(x, y){
  if (bdrag) bdrag.style.display = 'none';
  var el = document.elementFromPoint(x, y);
  if (bdrag && BDRAG) bdrag.style.display = 'block';
  while (el && el !== document.body) {
    if (el.className && String(el.className).indexOf('col') === 0) return el.className.indexOf('more') >= 0 ? null : el;
    el = el.parentNode;
  }
  return null;
}
// the VALUE a column stands for — '' for the last one, which clears the field.
// The drop compares values, never element identity: a board that re-drew
// between the press and the release must not turn "back where it was" into
// a rewrite.
function colVal(col){
  if (!col) return null;
  return col.getAttribute('data-none') ? '' : col.getAttribute('data-val');
}
function bClear(){
  var cs = bcols ? bcols.getElementsByClassName('col') : [];
  for (var i = 0; i < cs.length; i++) cs[i].classList.remove('over');
}
if (bcols) {
  bcols.addEventListener('mousedown', function(e){
    if (e.button !== 0) return;
    var el = e.target;
    while (el && el !== bcols && !(el.className && String(el.className).indexOf('card') === 0)) el = el.parentNode;
    if (!el || el === bcols || !el.getAttribute('data-rel')) return;
    e.preventDefault();
    BDRAG = { el: el, rel: el.getAttribute('data-rel'), name: el.getAttribute('data-name'),
              fromVal: colVal(el.parentNode.parentNode), x0: e.clientX, y0: e.clientY, moved: false };
  });
  window.addEventListener('mousemove', function(e){
    if (!BDRAG) return;
    if (!BDRAG.moved) {
      if (Math.abs(e.clientX - BDRAG.x0) < 4 && Math.abs(e.clientY - BDRAG.y0) < 4) return;
      BDRAG.moved = true;
      BDRAG.el.classList.add('ghost');
      if (bdrag) { bdrag.textContent = BDRAG.name; bdrag.style.display = 'block'; }
    }
    if (bdrag) { bdrag.style.left = (e.clientX + 10) + 'px'; bdrag.style.top = (e.clientY + 10) + 'px'; }
    bClear();
    var col = colUnder(e.clientX, e.clientY);
    if (col && colVal(col) !== BDRAG.fromVal) col.classList.add('over');
  });
  window.addEventListener('mouseup', function(e){
    if (!BDRAG) return;
    var d = BDRAG;
    BDRAG = null;
    if (bdrag) bdrag.style.display = 'none';
    d.el.classList.remove('ghost');
    bClear();
    if (!d.moved) { say({ a: 'open', name: d.name }); return; }     // a press that never moved is a click
    var col = colUnder(e.clientX, e.clientY), to = colVal(col);
    // dropped nowhere, or back where it started: nothing written, nothing said
    if (col === null || to === d.fromVal) return;
    // the column tells Lua the value; an empty one CLEARS the field
    say({ a: 'kmove', card: d.rel, field: (BSPEC && BSPEC.by) || BOARDFIELD, value: to })   // `card`, never `rel`: see say();
  });
}
function thou(n){ return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '\u2009'); }
function drawFoot(){
  if (!foot) return;
  var v = t.value || '', s = thou((v.match(/\S+/g) || []).length) + ' words · ' + thou(v.length) + ' chars · ' + thou(v.split('\n').length) + ' lines';
  var a = t.selectionStart, b = t.selectionEnd;
  if (b > a) s += ' · ' + thou((v.slice(a, b).match(/\S+/g) || []).length) + ' words selected';
  // 6.175.0 — and what the caret's line is doing, in words. This is the
  // quiet half of the teaching: no click, it is just always there.
  var ls = a > 0 ? v.lastIndexOf('\n', a - 1) + 1 : 0;
  var le = v.indexOf('\n', a); if (le < 0) le = v.length;
  var hint = t.disabled ? '' : mdHint(v.slice(ls, le));
  foot.innerHTML = esc(s) + (hint ? ' · <span class="tip">' + esc(hint) + '</span>'
                                  : ' · <span class="tip">/ for a list of blocks</span>');
}
// the panes follow the typing a beat later (the page's own timer, not an hs.timer)
function paneSoon(){
  try { clearTimeout(PANE_T); } catch(e){}
  PANE_T = setTimeout(function(){ if (!isTab()) { drawOutline(); drawChips(); drawQueries(); if (VIEW === 'board') drawBoard(); } drawFoot(); }, 150);
}
t.addEventListener('select', drawFoot); t.addEventListener('keyup', drawFoot); t.addEventListener('mouseup', drawFoot);

// ---- one popup, three kinds: [[ links, #tags, 📄 templates ----
var ACSEL = 0, ACITEMS = [], ACSTART = -1, ACKIND = 'link', ACDONE = null;
var ACBLOCKS = [];   // 6.175.0 — the / menu's rows, parallel to ACITEMS
function acOpen(){ return ac.style.display === 'block'; }
function acClose(){ ac.style.display = 'none'; ACITEMS = []; ACBLOCKS = []; ACSTART = -1; ACKIND = 'link'; ACDONE = null; }
// 6.190.0 — the naming bar. PRKIND remembers what the answer is FOR, so
// one bar serves every "name this" the vault has instead of one dialog
// each. It is never open at the same time as the autocomplete: both own
// Enter and Escape, and two owners of a key is a bug waiting.
var PRKIND = null;
function prOpen(){ var p = document.getElementById('pr'); return p && p.style.display === 'block'; }
function prWarn(msg){
  var w = document.getElementById('prwarn');
  if (!w) return;
  if (msg) { w.textContent = msg; w.style.display = 'block'; }
  else { w.textContent = ''; w.style.display = 'none'; }
}
// 6.203.0 — Lua's answer to a name it will not take. The bar STAYS OPEN
// with the text still in the box: that text is the only copy of what LL
// just pasted, and closing the bar on ⏎ is how the first one was lost.
function prSay(msg){
  prWarn(msg);
  var i = document.getElementById('prin');
  if (i && i.focus) i.focus();
}
function prClose(){
  var p = document.getElementById('pr');
  if (p) p.style.display = 'none';
  prWarn('');
  PRKIND = null;
  var t = document.getElementById('t');
  if (t && !t.disabled && t.focus) t.focus();
}
function askName(kind, label, value){
  acClose();
  var p = document.getElementById('pr'), l = document.getElementById('prlab'),
      i = document.getElementById('prin');
  if (!(p && l && i)) { say({ a: 'namefail', kind: kind }); return; }
  PRKIND = kind;
  l.textContent = label || 'Name:';
  i.value = value || '';
  prWarn('');                      // 6.203.0 — a fresh bar carries no old refusal
  p.style.display = 'block';
  if (i.focus) i.focus();
  if (i.select) i.select();
}
function prKey(e){
  if (!prOpen()) return false;
  if (e.key === 'Enter'){
    e.preventDefault();
    var i = document.getElementById('prin'), k = PRKIND;
    var val = i ? i.value : '';
    // 6.203.0 — do NOT close here. Lua decides: a name it takes re-renders
    // the whole page and the bar goes with it; a name it refuses comes
    // back through prSay and the bar stays up, text and all.
    prWarn('');
    say({ a: 'named', kind: k, name: val });   // `name`, never `text`: see say()
    return true;
  }
  if (e.key === 'Escape'){ e.preventDefault(); prClose(); return true; }
  return false;
}

function acShow(kind, items, start, header){
  ACKIND = kind; ACITEMS = items; ACSEL = 0; ACSTART = start;
  var h = header ? ['<div class="sec">' + esc(header) + '</div>'] : [];
  for (var j = 0; j < items.length; j++) {
    // 6.175.0 — a block row shows the NAME and, greyed beside it, the raw
    // markdown it will type. Reading the list is how LL learns the syntax.
    var body = (kind === 'block' && items[j] && items[j].n)
      ? esc(items[j].n) + '<span class="md">' + esc(items[j].md) + '</span>'
      : esc(items[j]);
    h.push('<div class="' + (j === 0 ? 'sel' : '') + '" data-i="' + j + '">' + body + '</div>');
  }
  ac.innerHTML = h.join('');
  ac.style.display = 'block';
  ac.style.left = '20px';
  var line = t.disabled ? 0 : t.value.slice(0, t.selectionStart).split('\n').length;
  ac.style.top = (t.disabled ? 40 : Math.min(t.clientHeight - 80, 40 + 24 * line)) + 'px';
}
function autocomplete(){
  var pos = t.selectionStart, head = t.value.slice(0, pos);
  // the caret INSIDE a finished link (its ]] is ahead on this line): no list of any kind
  var tail = t.value.slice(pos).split('\n')[0], c2 = tail.indexOf(']]'), o2 = tail.indexOf('[[');
  var inLink = c2 >= 0 && (o2 < 0 || c2 < o2);
  var i = head.lastIndexOf('[[');
  if (i >= 0 && head.indexOf(']]', i) < 0 && head.slice(i).indexOf('\n') < 0) {
    if (inLink) { acClose(); return; }
    var typed = head.slice(i + 2).toLowerCase(), items = [];
    for (var k = 0; k < NOTES.length && items.length < 8; k++) {
      if (!typed || NOTES[k].n.toLowerCase().indexOf(typed) >= 0) items.push(NOTES[k].n);
    }
    if (!items.length) { acClose(); return; }
    acShow('link', items, i + 2);
    return;
  }
  // 6.175.0 — "/" on an otherwise EMPTY line opens the block menu. Only
  // an empty line, because a slash is an ordinary character in a date, a
  // path or and/or, and a menu that opens over those is a menu LL turns
  // off. Typing after it filters by name.
  var sl = head.match(/(^|\n)[ \t]*\/([a-zA-Z ]*)$/);
  if (sl && !inLink) {
    var tail1 = t.value.slice(pos).split('\n')[0];
    if (/^\s*$/.test(tail1)) {
      if (slashMenu(sl[2], pos - sl[2].length - 1)) return;
    }
  }
  // 6.174.0 — #wo (a # at the line start or after a space, at least one character) → known tags
  var m = head.match(/(^|\s)#([^\s#\[\]]+)$/);
  if (m && !inLink) {
    var typed2 = m[2].toLowerCase(), items2 = [];
    for (var k2 = 0; k2 < TAGS.length && items2.length < 8; k2++) if (TAGS[k2].k.indexOf(typed2) >= 0) items2.push(TAGS[k2].n);
    if (items2.length) { acShow('tag', items2, head.length - m[2].length); return; }
  }
  acClose();
}
function acDraw(){ var ds = ac.children; for (var i = 0; i < ds.length; i++) { var k = ds[i].getAttribute ? ds[i].getAttribute('data-i') : null; if (k != null) ds[i].className = (+k === ACSEL) ? 'sel' : ''; } }
function acAccept(i){
  var name = ACITEMS[i]; if (name == null) return;
  if (ACKIND === 'tpl') { var fn = ACDONE; acClose(); if (fn) fn(name); return; }
  // 6.175.0 — the / menu. The "/" (and anything typed after it to filter)
  // is removed FIRST, then the block is applied to the clean line, or the
  // marker would land after a stray slash.
  if (ACKIND === 'block') {
    var x = ACBLOCKS[i];
    if (ACSTART >= 0) {
      var pos0 = t.selectionStart;
      t.value = t.value.slice(0, ACSTART) + t.value.slice(pos0);
      try { t.setSelectionRange(ACSTART, ACSTART); } catch(e){}
    }
    acClose(); blockApply(x); return;
  }
  var pos = t.selectionStart, after = t.value.slice(pos), np;
  if (ACKIND === 'tag') {
    t.value = t.value.slice(0, ACSTART) + name + after;
    np = ACSTART + name.length;
  } else {
    var close = after.indexOf(']]') === 0 ? '' : ']]';
    t.value = t.value.slice(0, ACSTART) + name + close + after;
    np = ACSTART + name.length + 2;
  }
  try { t.setSelectionRange(np, np); } catch(e){}
  acClose(); say({a:'edit'}); paneSoon();
}
ac.addEventListener('mousedown', function(e){ var d = e.target; if (d && d.getAttribute && d.getAttribute('data-i') != null) { e.preventDefault(); acAccept(+d.getAttribute('data-i')); } });
// 📄 ⌘⇧T inserts at the caret, ⌘⇧N makes a new note ("— blank —" = ⌘N)
function tplPick(what){
  if (!TEMPLATES.length) { say({a:'tplnone'}); return; }
  var items = what === 'new' ? ['— blank —'] : [];
  for (var i = 0; i < TEMPLATES.length; i++) items.push(TEMPLATES[i].n);
  ACDONE = function(name){ var nm = name === '— blank —' ? '' : name; if (what === 'new') say({a:'tplnew', name: nm}); else say({a:'tplinsert', name: nm}); };
  acShow('tpl', items, -1, what === 'new' ? '📄 New note from…' : '📄 Insert at the caret…');
}

// ---- the link under the caret: [[wiki]] first, then [text](target) ----
function linkAtCaret(){
  var pos = t.selectionStart, s = t.value, re = /\[\[([^\]]+)\]\]/g, m;
  while ((m = re.exec(s))) { if (pos >= m.index && pos <= m.index + m[0].length) return { target: m[1], md: false }; }
  re = /\[([^\]]*)\]\(([^)]+)\)/g;
  while ((m = re.exec(s))) { if (pos >= m.index && pos <= m.index + m[0].length) return { target: m[2], md: true }; }
  return null;
}
// 6.174.0 — a second string lands AFTER the caret (a template's {{cursor}} split)
function insertAtCaret(str, tail){
  tail = tail || '';
  var a = t.selectionStart, b = t.selectionEnd;
  t.value = t.value.slice(0, a) + str + tail + t.value.slice(b);
  try { t.setSelectionRange(a + str.length, a + str.length); } catch(e){}
  say({a:'edit'}); paneSoon(); drawFoot();
}
// =====================================================================
// 6.175.0 — THE MARKDOWN TEACHER. LL: "I don't write markdown. Are there
// tool tips or autocompletes that will teach and help me."
//
// Three ways in, and every one of them SHOWS the syntax rather than
// hiding it — the point is that LL stops needing them:
//   · the format bar above the text, each button's tooltip naming the
//     characters it is about to type and the shortcut for it;
//   · "/" at the start of an empty line: a list of every block, each row
//     with its plain-English name AND its raw markdown beside it;
//   · the footer, which names the line the caret is on ("Heading 1 —
//     the # does that") so the syntax gets explained as it is used.
// =====================================================================

// Wrap the selection in a marker — or UNWRAP it, so the same button (and
// ⌘B) is also how you take bold off. With nothing selected it types the
// pair and puts the caret between them, which is how a person expects a
// bold button to behave in an empty line.
function wrapSel(mark){
  var a = t.selectionStart, b = t.selectionEnd, v = t.value, n = mark.length;
  var sel = v.slice(a, b);
  if (sel && sel.slice(0, n) === mark && sel.slice(-n) === mark && sel.length >= n * 2) {
    t.value = v.slice(0, a) + sel.slice(n, sel.length - n) + v.slice(b);
    try { t.setSelectionRange(a, b - n * 2); } catch(e){}
  } else if (v.slice(a - n, a) === mark && v.slice(b, b + n) === mark) {
    // the markers are just OUTSIDE the selection — the common case after
    // double-clicking a word that is already bold
    t.value = v.slice(0, a - n) + sel + v.slice(b + n);
    try { t.setSelectionRange(a - n, b - n); } catch(e){}
  } else {
    t.value = v.slice(0, a) + mark + sel + mark + v.slice(b);
    try { t.setSelectionRange(a + n, a + n + sel.length); } catch(e){}
  }
  say({a:'edit'}); paneSoon(); drawFoot();
}

// Put a marker at the START of the caret's line (or of every line of the
// selection). Pressing the same one again takes it off, and a line that
// already carries a DIFFERENT block marker swaps rather than stacking —
// "# > - hello" is nobody's intention.
var BLOCKRE = /^(\s*)(#{1,6} |> |- \[[ xX]\] |- |\* |\+ |\d+\. )?/;
function blockAt(mark){
  var v = t.value, a = t.selectionStart, b = t.selectionEnd;
  var ls = a > 0 ? v.lastIndexOf('\n', a - 1) + 1 : 0;
  var le = v.indexOf('\n', b); if (le < 0) le = v.length;
  var lines = v.slice(ls, le).split('\n'), off = 0, first = null;
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(BLOCKRE), had = m[2] || '';
    if (first === null) first = (had === mark);
    var put = first ? '' : mark;      // every line follows the first one
    lines[i] = m[1] + put + lines[i].slice(m[0].length);
    if (i === 0) off = put.length - had.length;
  }
  t.value = v.slice(0, ls) + lines.join('\n') + v.slice(le);
  var na = Math.max(ls, a + off);
  try { t.setSelectionRange(na, na); } catch(e){}
  say({a:'edit'}); paneSoon(); drawFoot();
}

// ---- the / menu ------------------------------------------------------
// Name first, syntax second, on every row: read the list once and you
// have learned the syntax, which is the whole point.
var BLOCKS = [
  { n: 'Heading 1',      md: '# ',        kind: 'line' },
  { n: 'Heading 2',      md: '## ',       kind: 'line' },
  { n: 'Heading 3',      md: '### ',      kind: 'line' },
  { n: 'Bullet list',    md: '- ',        kind: 'line' },
  { n: 'Numbered list',  md: '1. ',       kind: 'line' },
  { n: 'Task',           md: '- [ ] ',    kind: 'line' },
  { n: 'Quote',          md: '> ',        kind: 'line' },
  { n: 'Bold',           md: '**',        kind: 'wrap' },
  { n: 'Italic',         md: '*',         kind: 'wrap' },
  { n: 'Code',           md: '`',         kind: 'wrap' },
  { n: 'Link to a note', md: '[[ ]]',     kind: 'link' },
  { n: 'Tag',            md: '#',         kind: 'type' },
  { n: 'Divider',        md: '---',       kind: 'rule' },
  { n: 'Code block',     md: '``` ```',   kind: 'fence' },
  { n: 'Query — a live list of notes', md: '```dataview LIST FROM #tag```', kind: 'query' },
  { n: 'Query — filtered by a field', md: '```dataview TABLE … WHERE …```', kind: 'queryw' },
  { n: 'Board — a Kanban of your notes', md: '```kanban BY status```', kind: 'board' },
];
function blockRows(typed){
  var out = [];
  typed = (typed || '').toLowerCase();
  for (var i = 0; i < BLOCKS.length; i++) {
    var x = BLOCKS[i];
    if (!typed || x.n.toLowerCase().indexOf(typed) >= 0) out.push(x);
  }
  return out;
}
// Applying one is deliberately shared with the buttons above: whatever
// the / menu does, the bar does the same, so there is one behaviour to
// learn and one to test.
function blockApply(x){
  if (!x) return;
  if (x.kind === 'line')  { blockAt(x.md); return; }
  if (x.kind === 'wrap')  { wrapSel(x.md); return; }
  if (x.kind === 'link')  { insertAtCaret('[[', ']]'); autocomplete(); return; }
  if (x.kind === 'type')  { insertAtCaret('#'); return; }
  if (x.kind === 'rule')  { insertAtCaret('---\n'); return; }
  if (x.kind === 'fence') { insertAtCaret('```\n', '\n```\n'); return; }
  // 6.183.0 — a WORKING query with the caret on the tag, so the first
  // thing LL does is name it rather than learn the grammar
  if (x.kind === 'query') { insertAtCaret('```dataview\nLIST FROM #', '\nSORT name\n```\n'); return; }
  // 6.185.0 — the WHERE shape, filled in and working, caret on the tag
  // 6.186.0 — a working board, caret on the tag. COLUMNS is written in so
  // the empty ones are there to drag INTO from the first press: a board
  // whose columns only appear once a note already has that value is no use.
  if (x.kind === 'board') { insertAtCaret('```kanban\nBY status\nFROM #',
                                          '\nCOLUMNS todo, doing, done\nSORT name\n```\n'); return; }
  if (x.kind === 'queryw') { insertAtCaret('```dataview\nTABLE status FROM #',
                                           '\nWHERE status != "done"\nSORT status\n```\n'); return; }
}
function slashMenu(typed, start){
  var rows = blockRows(typed);
  if (!rows.length) { acClose(); return false; }
  ACBLOCKS = rows;
  var items = [];
  for (var i = 0; i < rows.length; i++) items.push(rows[i]);
  acShow('block', items, start == null ? -1 : start, 'Insert…  (the grey part is the markdown it types)');
  return true;
}

// ---- what line am I on? the footer explains it ----------------------
// Passive teaching: no click, no menu, it just says what the characters
// at the start of this line are doing.
function mdHint(line){
  line = line || '';
  var m = line.match(/^\s*(#{1,6}) /);
  if (m) return 'Heading ' + m[1].length + ' — the ' + m[1] + ' does that';
  if (/^\s*- \[[xX]\] /.test(line)) return 'Task, ticked — ⌘L unticks it';
  if (/^\s*- \[ \] /.test(line))    return 'Task — ⌘L ticks it, ⏎ starts the next one';
  if (/^\s*\d+\. /.test(line))      return 'Numbered list — ⏎ counts on for you';
  if (/^\s*[-*+] /.test(line))      return 'Bullet list — ⏎ keeps it going, ⏎ on an empty one ends it';
  if (/^\s*> /.test(line))          return 'Quote — the > does that';
  if (/^\s*(---|\*\*\*|___)\s*$/.test(line)) return 'Divider — a line across the page';
  if (/^\s*(?:```|~~~)\s*dataview/i.test(line)) return 'Query — the notes it names are listed in \ud83d\udd0e QUERY, never written here';
  if (/^\s*(list|table)\b.*\bfrom\b/i.test(line)) return 'Query — FROM #tag, [[a note]] or "a folder", joined with AND / OR';
  if (/^\s*where\b/i.test(line)) return 'Query filter — field, field = "x", field > 3, contains(field, "x"), AND / OR';
  if (/^\s*(?:```|~~~)\s*kanban/i.test(line)) return 'Board — press ⌘⇧B to see it; dragging a card rewrites that note\u2019s field';
  if (/^\s*by\s+[A-Za-z_][\w.\-]*\s*$/i.test(line)) return 'Board — BY names the front-matter field the columns are (status, stage, priority…)';
  if (/^\s*columns\s+[A-Za-z_"'][^|]*$/i.test(line)) return 'Board — COLUMNS fixes the order; a value it does not name still gets a column after them';
  if (/^\s*(sort|limit)\b/i.test(line)) return 'Query — SORT by name, path or any front-matter field; LIMIT caps the rows';
  if (/^\s*```/.test(line))         return 'Code block — everything until the next ``` is left alone';
  if (/^\s*(tags|title|date):/i.test(line)) return 'Front matter — tags: here join the 🏷 list';
  if (/\[\[[^\]]*\]\]/.test(line))  return 'Links to another note — ⌘⏎ opens it';
  if (/`[^`]+`/.test(line))         return 'Code — the `back ticks` do that';
  if (/\*\*[^*]+\*\*/.test(line))   return 'Bold — the **stars** do that';
  if (/(^|\s)#[^\s#]/.test(line))   return 'Tagged — the #word joins the 🏷 TAGS list';
  if (/\*[^*]+\*/.test(line))       return 'Italic — one *star* each side';
  return '';
}

// ⌘L — the caret line (or every line of the selection): - [ ] ↔ - [x]; a
// list line gets a box; a plain line becomes an item. Marker and indent
// stay, the caret keeps its place in the text, native ⌘Z undoes it.
function toggleTask(){
  if (t.disabled) return;
  var v = t.value, a = t.selectionStart, b = t.selectionEnd;
  var ls = a > 0 ? v.lastIndexOf('\n', a - 1) + 1 : 0, le = v.indexOf('\n', b); if (le < 0) le = v.length;
  var lines = v.slice(ls, le).split('\n'), out = [], delta0 = 0, total = 0;
  for (var i = 0; i < lines.length; i++) {
    var L = lines[i], m = L.match(/^(\s*)([-*+]|\d+\.)\s+\[( |x|X)\]\s?(.*)$/), n;
    if (m) n = m[1] + m[2] + ' [' + (m[3] === ' ' ? 'x' : ' ') + '] ' + m[4];
    else if ((m = L.match(/^(\s*)([-*+]|\d+\.)\s+(.*)$/))) n = m[1] + m[2] + ' [ ] ' + m[3];
    else { m = L.match(/^(\s*)(.*)$/); n = m[1] + '- [ ] ' + m[2]; }
    if (i === 0) delta0 = n.length - L.length;
    total += n.length - L.length;
    out.push(n);
  }
  t.value = v.slice(0, ls) + out.join('\n') + v.slice(le);
  var na = Math.max(ls, a + delta0), nb = Math.max(na, b + total);
  try { t.setSelectionRange(na, nb); } catch(e){}
  say({a:'edit'}); paneSoon(); drawFoot();
}
// ⏎ on a list line continues it (- * + 1. and their boxes); on an EMPTY
// item it drops the marker; any other line keeps the native ⏎
function smartEnter(e){
  if (!SMARTLISTS || t.disabled) return false;
  var v = t.value, a = t.selectionStart, ls = a > 0 ? v.lastIndexOf('\n', a - 1) + 1 : 0, le = v.indexOf('\n', a); if (le < 0) le = v.length;
  var m = v.slice(ls, le).match(/^(\s*)([-*+]|\d+\.)(\s+\[[ xX]\])?\s+(.*)$/);
  if (!m) return false;
  var np;
  if (m[4] === '') { t.value = v.slice(0, ls) + m[1] + v.slice(le); np = ls + m[1].length; }
  else {
    var mk = /^\d+\.$/.test(m[2]) ? (parseInt(m[2], 10) + 1) + '.' : m[2];
    var ins = '\n' + m[1] + mk + ' ' + (m[3] ? '[ ] ' : '');
    t.value = v.slice(0, a) + ins + v.slice(t.selectionEnd); np = a + ins.length;
  }
  try { t.setSelectionRange(np, np); } catch(e2){}
  e.preventDefault(); say({a:'edit'}); paneSoon();
  return true;
}

document.addEventListener('keydown', function(e){
  var meta = e.metaKey || e.ctrlKey, kk = (e.key || '').toLowerCase();
  // FIRST, before anything else can claim them: while the naming bar is
  // up it owns Enter and Escape, and every other key is just typing into
  // it. Esc must close the BAR, never the window.
  if (prOpen()) { if (prKey(e)) return; if (!meta) return; }
  if (acOpen() && !meta) {
    if (e.key === 'ArrowDown') { e.preventDefault(); ACSEL = (ACSEL + 1) % ACITEMS.length; acDraw(); return; }
    if (e.key === 'ArrowUp') { e.preventDefault(); ACSEL = (ACSEL + ACITEMS.length - 1) % ACITEMS.length; acDraw(); return; }
    if (e.key === 'Enter' || e.key === 'Tab') { e.preventDefault(); acAccept(ACSEL); return; }
    if (e.key === 'Escape') { e.preventDefault(); acClose(); return; }
  }
  // Esc: a search / task view goes back to the notes first; then the window
  if (e.key === 'Escape') { e.preventDefault(); if (MODE !== 'notes') setMode('notes'); else say({a:'esc'}); return; }
  if (rowKey(e)) return;
  // 6.174.0 — the ⌘⇧ chords sit BEFORE the plain ⌘ letters (⌘⇧T is not ⌘T)
  if (meta && e.shiftKey) {
    if (kk === 'f') { e.preventDefault(); setMode('search'); return; }
    if (kk === 'k') { e.preventDefault(); setMode(MODE === 'tasks' ? 'notes' : 'tasks'); return; }
    if (kk === 't') { e.preventDefault(); tplPick('insert'); return; }
    if (kk === 'n') { e.preventDefault(); tplPick('new'); return; }
    if (kk === 'e') { e.preventDefault(); say({a:'extract', head: t.value.slice(0, t.selectionStart), selText: t.value.slice(t.selectionStart, t.selectionEnd)}); return; }
    if (kk === 'r') { e.preventDefault(); say({a:'random'}); return; }
    if (kk === 'b') { e.preventDefault(); say({a:'board'}); return; }
    // 6.177.0 — the Scorp Pad's way out: every tab as a .md note
    if (kk === 's') { e.preventDefault(); say({a:'export'}); return; }
    if (e.code === 'BracketLeft' || e.key === '[' || e.key === '{') { e.preventDefault(); say({a:'dayshift', d: -1}); return; }
    if (e.code === 'BracketRight' || e.key === ']' || e.key === '}') { e.preventDefault(); say({a:'dayshift', d: 1}); return; }
  }
  // 6.173.0 — the Scorp Pad's tab keys, from anywhere in the window
  if (e.ctrlKey && e.key === 'Tab') { e.preventDefault(); if (HASPAD) say({a:'tabcycle', d: e.shiftKey ? -1 : 1}); return; }
  if (meta && !e.shiftKey && kk === 't') { e.preventDefault(); if (HASPAD) say({a:'tabnew'}); return; }
  if (meta && !e.shiftKey && kk === 'w') { e.preventDefault(); if (isTab()) say({a:'tabclose', tid: CUR.slice(8)}); return; }
  if (meta && e.key >= '1' && e.key <= '9') { e.preventDefault(); if (HASPAD) say({a:'tabnth', n: e.key}); return; }
  if (meta && e.key === 'Enter') { e.preventDefault(); var l = linkAtCaret(); if (l) say({a:'follow', target: l.target, md: l.md}); return; }
  if (meta && !e.shiftKey && kk === 'n') { e.preventDefault(); say({a:'new'}); return; }
  if (meta && !e.shiftKey && kk === 'd') { e.preventDefault(); say({a:'daily'}); return; }
  if (meta && !e.shiftKey && kk === 'g') { e.preventDefault(); say({a:'graph'}); return; }
  if (meta && !e.shiftKey && kk === 'k') { e.preventDefault(); say({a:'linkfile'}); return; }
  if (meta && !e.shiftKey && kk === 'l') { e.preventDefault(); toggleTask(); return; }
  // 6.175.0 — the three every word processor has, so LL never has to
  // type a star. They wrap the selection and unwrap it again.
  if (meta && !e.shiftKey && kk === 'b') { e.preventDefault(); wrapSel('**'); return; }
  if (meta && !e.shiftKey && kk === 'i') { e.preventDefault(); wrapSel('*'); return; }
  if (meta && !e.shiftKey && kk === 'e') { e.preventDefault(); wrapSel('`'); return; }
  // ⌘F · ⌘O (Obsidian's quick switcher): the notes list, the box selected
  if (meta && !e.shiftKey && (kk === 'f' || kk === 'o')) { e.preventDefault(); if (MODE !== 'notes') setMode('notes'); q.focus(); q.select(); return; }
  if (e.key === 'Enter' && !meta && !e.altKey && !e.shiftKey && inText() && !acOpen()) { smartEnter(e); return; }
});

// ---- the graph: a small force layout in a canvas ----
var G = null;
function graphStart(){
  var cv = document.getElementById('cv'), ctx = cv.getContext ? cv.getContext('2d') : null;
  if (!ctx) return;
  var W = cv.clientWidth || 800, H = cv.clientHeight || 600;
  cv.width = W * (window.devicePixelRatio || 1); cv.height = H * (window.devicePixelRatio || 1);
  ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);
  var nodes = GRAPH.nodes.map(function(n, i){
    var a = i * 2.399963, r = 0.35 * Math.min(W, H) * Math.sqrt((i + 1) / GRAPH.nodes.length);
    return { n: n.n, r: n.r, ghost: !!n.ghost, x: W / 2 + r * Math.cos(a), y: H / 2 + r * Math.sin(a), vx: 0, vy: 0, deg: 0 };
  });
  GRAPH.edges.forEach(function(e){ nodes[e[0]].deg++; nodes[e[1]].deg++; });
  G = { nodes: nodes, edges: GRAPH.edges, W: W, H: H, ctx: ctx, cv: cv, drag: null, ticks: 0, hover: -1 };
  function step(){
    var ns = G.nodes, k = 0.02;
    for (var i = 0; i < ns.length; i++) for (var j = i + 1; j < ns.length; j++) {
      var dx = ns[j].x - ns[i].x, dy = ns[j].y - ns[i].y, d2 = dx * dx + dy * dy + 0.01, f = 1800 / d2;
      var fx = dx * f / Math.sqrt(d2), fy = dy * f / Math.sqrt(d2);
      ns[i].vx -= fx; ns[i].vy -= fy; ns[j].vx += fx; ns[j].vy += fy;
    }
    G.edges.forEach(function(e){
      var a = ns[e[0]], b = ns[e[1]], dx = b.x - a.x, dy = b.y - a.y, d = Math.sqrt(dx * dx + dy * dy) + 0.01, f = (d - 90) * k;
      a.vx += dx / d * f; a.vy += dy / d * f; b.vx -= dx / d * f; b.vy -= dy / d * f;
    });
    ns.forEach(function(n){
      if (G.drag === n) { n.vx = n.vy = 0; return; }
      n.vx += (G.W / 2 - n.x) * 0.003; n.vy += (G.H / 2 - n.y) * 0.003;
      n.vx *= 0.85; n.vy *= 0.85; n.x += n.vx; n.y += n.vy;
      n.x = Math.max(12, Math.min(G.W - 12, n.x)); n.y = Math.max(12, Math.min(G.H - 12, n.y));
    });
  }
  function draw(){
    var c = G.ctx; c.clearRect(0, 0, G.W, G.H);
    c.strokeStyle = 'rgba(160,170,200,.35)'; c.lineWidth = 1;
    G.edges.forEach(function(e){ var a = G.nodes[e[0]], b = G.nodes[e[1]]; c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(b.x, b.y); c.stroke(); });
    G.nodes.forEach(function(n, i){
      var rad = 5 + Math.min(10, n.deg * 1.5), cur = n.r && n.r === CUR;
      c.beginPath(); c.arc(n.x, n.y, rad, 0, Math.PI * 2);
      if (n.ghost) { c.strokeStyle = '#9aa3c0'; c.lineWidth = 1.5; c.stroke(); }
      else { c.fillStyle = cur ? '#ffb347' : (i === G.hover ? '#8fb4ff' : '#4a7fe0'); c.fill(); }
      if (G.nodes.length <= 150 || n.deg > 2 || i === G.hover || cur) {
        c.fillStyle = 'rgba(232,232,236,.85)'; c.font = (FSLABEL) + 'px -apple-system,Helvetica,sans-serif';
        c.fillText(n.n, n.x + rad + 4, n.y + 4);
      }
    });
  }
  function tick(){ if (!G || VIEW !== 'graph') return; if (G.ticks++ < 400 || G.drag) step(); draw(); requestAnimationFrame(tick); }
  function at(e){ var r = cv.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; }
  function hit(p){ for (var i = G.nodes.length - 1; i >= 0; i--) { var n = G.nodes[i], dx = n.x - p.x, dy = n.y - p.y; if (dx * dx + dy * dy < 144) return i; } return -1; }
  cv.onmousedown = function(e){ var i = hit(at(e)); if (i >= 0) { G.drag = G.nodes[i]; G.moved = false; G.ticks = 0; } };
  cv.onmousemove = function(e){ var p = at(e); if (G.drag) { G.drag.x = p.x; G.drag.y = p.y; G.moved = true; } else { G.hover = hit(p); cv.style.cursor = G.hover >= 0 ? 'pointer' : 'default'; } };
  cv.onmouseup = function(e){ if (G.drag && !G.moved) say({a:'open', name: G.drag.n}); G.drag = null; };
  cv.onmouseleave = function(){ G.drag = null; };
  tick();
}
// 6.174.0 — the load sequence: the list in its mode, the panes, then the caret
// (a line from a search / task row, a template's {{cursor}} head, else where it was)
setMode(MODE, true);
if (VIEW === 'graph') { graphStart(); }
if (VIEW === 'board') { drawBoard(); }
else {
  if (!isTab()) { drawChips(); drawOutline(); drawUnlinked(); drawQueries(); }
  drawFoot();
  if (CARETLINE > 0) gotoLine(CARETLINE);
  else if (CARETHEAD !== null) { var p0 = CARETHEAD.length; t.focus(); try { t.setSelectionRange(p0, p0); } catch(e){} }
  else if (MODE !== 'notes') { q.focus(); try { q.selectionStart = q.selectionEnd = q.value.length; } catch(e){} }
  else { t.focus(); try { t.setSelectionRange(CARET, CARET); } catch(e){} }
  say({a:'ready'});   /* 6.174.0 — answers that arrived while this page loaded */
}
</script></body></html>]==]
        v.caretLine, v.caretHead = nil, nil     -- 6.174.0 — emitted once; a later render never re-selects
        -- 6.191.0 — LL: "Make all font 14pt". The window has THREE sizes,
        -- not one: FSpx the body, FS1px the controls, FS2px the labels.
        -- They used to step 13/11/10 and the labels were the complaint.
        -- Now they step by ONE each and FLOOR at fs - 2, so at fs = 14
        -- the whole window is 14/13/12 and nothing in it is small.
        local fs1 = math.max(10, math.floor(fs) - 1)
        local fs2 = math.max(10, math.floor(fs) - 2)
        return (html:gsub("TIPGAPPX", tostring(math.floor(fs) + 8))
                    :gsub("FSLABEL", tostring(fs2)):gsub("FSNUM", tostring(math.floor(fs)))
                    :gsub("FS1px", fs1 .. "px")
                    :gsub("FS2px", fs2 .. "px"):gsub("FSpx", math.floor(fs) .. "px"))
    end

    function v.render()
        if not v.webview then return end
        pcall(function() v.webview:html(v.buildHtml()) end)
    end

    -- ---- messages from the page ----------------------------------------------
    local function handleMessage(body)
        if type(body) ~= "table" then return end
        -- the text rides on every message: the draft is in Lua first
        if v.doc and body.rel == v.doc.rel and body.text ~= nil then v.setText(body.text) end
        v.caret = tonumber(body.sel) or 0
        local a = body.a
        if a == "edit" then
            return
        elseif a == "filter" then
            v.filter = tostring(body.f or "")
        elseif a == "open" then
            if v.openNote(tostring(body.name or "")) then
                -- 6.174.0 — a search / task row names the line; the filter is only the notes list's
                if body.line then v.caretLine = tonumber(body.line) end
                if v.mode == "notes" then v.filter = "" end
                v.render()
            end
        elseif a == "named" then
            -- The naming bar answered. Every kind lands here so there is
            -- ONE place that decides what a typed name does.
            -- 6.203.0 — and ONE place that answers it. On success
            -- createNamed has already re-rendered and the bar went with
            -- the page; only a refusal needs a voice, and it belongs in
            -- the bar rather than in an hs.alert that draws UNDER this
            -- window. A CONSEQUENCE YOU DECIDE NOT TO ACT ON IS ONE YOU
            -- ARE OBLIGED TO NAME — so nothing here is allowed to fail
            -- in silence the way the long name did.
            local ok, why
            -- 6.203.0 — body.NAME. `text` belongs to say() and arrives
            -- holding the open note, which is what this read for years.
            if body.kind == "new" then ok, why = v.createNamed(body.name)
            else why = "the naming bar answered with a kind nothing handles" end
            if not ok then
                pcall(function()
                    v.eval("prSay(" .. jstr(why or "that name cannot be used") .. ")")
                end)
            end
        elseif a == "namefail" then
            -- The page could not draw the bar (an old page still loaded,
            -- say). Say so and fall back rather than leaving ⌘N dead.
            warn("the naming bar did not draw — using the system dialog")
            local okP, button, typed = pcall(hs.dialog.textPrompt, "New note",
                "Name of the note:", "", "Create", "Cancel")
            if okP and button == "Create" then v.createNamed(typed) end
        elseif a == "new" then
            v.newNote()
        elseif a == "daily" then
            local ok, why = v.openDaily()
            if ok and why ~= "pending" then v.render() end     -- 6.174.0 — a templated day renders when /bin/cat answers
        elseif a == "follow" then
            if v.follow(tostring(body.target or ""), body.md == true) and not body.md then v.render()
            elseif body.md then say("opened " .. tostring(body.target)) end
        elseif a == "graph" then
            v.view = (v.view == "graph") and "edit" or "graph"
            v.render()
        -- 6.186.0 — 🗂 the board takes the whole window (columns need width)
        elseif a == "board" then
            v.view = (v.view == "board") and "edit" or "board"
            v.render()
        -- 6.186.0 — a card was dragged into another column. ONE field of ONE
        -- note; the page tells us where it landed and Lua decides whether
        -- that is allowed. A refusal is said out loud and the board redraws
        -- from the index, so a card that did not move snaps back.
        elseif a == "kmove" then
            -- 6.203.0 — body.CARD: `rel` is say()'s and always arrives as
            -- the OPEN note, so every drag rewrote the wrong file.
            local ok, why = v.setField(body.card, body.field, body.value)
            if not ok then
                pcall(function() hs.alert.show("🗂 Not moved — " .. tostring(why), 3) end)
                print("🕸 Vault: card not moved — " .. tostring(why))
            end
            v.render()
        elseif a == "linkfile" then
            local link, why = v.linkFile()
            if link then
                v.eval("insertAtCaret(" .. jstr(link) .. ")")
            elseif why ~= "cancelled" then
                pcall(function() hs.alert.show("🕸 " .. tostring(why), 2) end)
            end
        -- 6.174.0 — the page finished loading: hand it anything that
        -- arrived while it was still being built.
        elseif a == "ready" then
            if v.doc and not v.doc.scratch and v.unlinked.key == v.doc.key then v.pushMentions() end
            if v.mode == "tasks" and v.lastTasks then
                v.eval("setRows(\"tasks\", " .. jarr(v.taskRows) .. ", " .. tostring(v.taskMore) .. ", \"\")")
            end
        elseif a == "rescan" then
            v.scan("button")
            if v.mode == "tasks" then v.listTasks() end     -- 6.174.0 — ↻ refreshes the ☑ list too
            v.render()
        -- 6.174.0 — modes, search, tasks, templates, daily ‹ ›, extract, random
        elseif a == "mode" then
            v.setMode(tostring(body.m or "notes"))
        elseif a == "search" then
            v.search(tostring(body.q or ""))
        elseif a == "tasks" then
            v.listTasks()
        elseif a == "tplinsert" then
            v.insertTemplate(tostring(body.name or ""))
        elseif a == "tplnew" then
            v.newFromTemplate(tostring(body.name or ""))
        elseif a == "tplnone" then
            alert("📄 No templates yet — put .md files in " .. v.dir .. "/" .. tostring(v.templatesDir), 3)
        elseif a == "dayshift" then
            local ok, why = v.openDailyOffset(tonumber(body.d) or 1)
            if ok and why ~= "pending" then v.render() end
        elseif a == "extract" then
            v.extract(body.head, body.selText)
        elseif a == "random" then
            if v.openRandom() then v.render() end
        -- 6.173.0 — the Scorp Pad's tabs (its module does the work)
        elseif a == "tab" then
            if v.openScratch(tostring(body.tid or "")) then v.render() end
        -- 6.195.0 — the "+ new note ⌘N" row. ONE creation path: this is
        -- the same v.newNote() the key calls, so the in-page naming bar
        -- (and its hs.dialog degrade) serve both.
        elseif a == "newnote" then
            v.newNote()
        elseif a == "tabnew" then
            local sp = v.sp()
            local t = sp and sp.newTab("")
            if t and v.openScratch(t.id) then v.render() end
        -- 6.182.0 — the "+ 🗒 Capture" / "+ ➕ Append" rows. openKind is
        -- the SAME call ⇪N and ⇪2 made until 6.182.0, so the two pads'
        -- filing brains are reached exactly as they always were. It shows
        -- the tab itself, hence no openScratch here.
        elseif a == "tabkind" then
            local sp = v.sp()
            local kind = tostring(body.kind or "")
            if not (sp and sp.openKind and sp.kinds and sp.kinds[kind]) then
                pcall(function() hs.alert.show("📝 that tab kind is not loaded", 2) end)
            else
                pcall(sp.openKind, kind)
            end
        elseif a == "tabclose" then
            local sp = v.sp()
            local tid = tostring(body.tid or "")
            if sp and sp.closeTab(tid) then
                if v.doc and v.doc.scratch == tid then v.openScratch(sp.active) end
                v.render()
            end
        elseif a == "tabnth" then
            local sp = v.sp()
            local t = sp and sp.tabs[tonumber(body.n) or 0]
            if t and v.openScratch(t.id) then v.render() end
        elseif a == "tabcycle" then
            local sp = v.sp()
            local n = sp and #sp.tabs or 0
            if n > 0 then
                local _, i = sp.findTab(sp.active)
                local d = (tonumber(body.d) or 1) < 0 and -1 or 1
                local j = (v.doc and v.doc.scratch) and (((i or 1) - 1 + d) % n + 1) or (i or 1)
                if v.openScratch(sp.tabs[j].id) then v.render() end
            end
        -- 6.177.0 — ⌘⇧S exports the pad's tabs as .md notes. The pad owns
        -- the work; if it is not loaded this says so and changes nothing.
        elseif a == "export" then
            local sp = v.sp()
            local ok, summary = false, "the Scorp Pad is not loaded"
            if sp and type(sp.exportAll) == "function" then ok, summary = sp.exportAll("⌘⇧S") end
            pcall(function() hs.alert.show((ok and "📤 Exported — " or "📤 ") .. tostring(summary), 4) end)
            if ok then v.scan("export") end
        elseif a == "restore" then
            local sp = v.sp()
            if sp and sp.restore(tostring(body.rid or "")) and v.openScratch(sp.active) then v.render() end
        elseif a == "send" then
            local sp = v.sp()
            local ok, why = false, "the Scorp Pad is not loaded"
            if sp then ok, why = sp.send("button") end
            if not ok then pcall(function() hs.alert.show("📝 Not sent — " .. tostring(why), 2) end) end
        elseif a == "pin" then
            v.pinned = not v.pinned
            pcall(function() hs.settings.set("vault.pinned", v.pinned) end)
            v.render()
            pcall(function() hs.alert.show(v.pinned and "📌 Pinned — Esc hands the keys back, ⇪3 / ⇪1 closes" or "📌 Unpinned", 1.5) end)
        elseif a == "esc" then
            if v.pinned then v.blur() else v.hide() end
        elseif a == "hide" then
            v.hide()
        elseif a == "dragStart" then
            v.beginDrag()
        elseif a == "f18up" then
            if _G.hyperReleaseSeen then pcall(_G.hyperReleaseSeen, "the vault") end
        end
    end
    v.handleMessage = handleMessage

    -- ---- dragging (the pad's recipe: Lua polls the mouse) ----------------------
    local function mousePosition()
        if type(hs.mouse) ~= "table" then return nil end
        for _, name in ipairs({ "absolutePosition", "getAbsolutePosition" }) do
            local fn = hs.mouse[name]
            if type(fn) == "function" then
                local ok, p = pcall(fn)
                if ok and type(p) == "table" and p.x and p.y then return p end
            end
        end
    end
    local function leftButtonDown()
        local ok, btns = pcall(hs.eventtap.checkMouseButtons)
        if not ok or type(btns) ~= "table" then return false end
        return btns.left == true or btns[1] == true
    end
    function v.endDrag()
        if v.dragTimer then pcall(function() v.dragTimer:stop() end); v.dragTimer = nil end
        v.dragOffset = nil
    end
    function v.beginDrag()
        if not v.webview then return end
        local okF, f = pcall(function() return v.webview:frame() end)
        if not (okF and type(f) == "table") then return end
        local m = mousePosition()
        if not m then return end
        v.endDrag()
        v.dragOffset = { x = m.x - f.x, y = m.y - f.y }
        v.dragTimer = hs.timer.doEvery(0.016, function()
            if not (v.webview and v.dragOffset) then v.endDrag() return end
            if not leftButtonDown() then v.endDrag() return end
            local p = mousePosition()
            if not p then v.endDrag() return end
            pcall(function()
                local cur = v.webview:frame()
                v.webview:frame({ x = p.x - v.dragOffset.x, y = p.y - v.dragOffset.y, w = cur.w, h = cur.h })
                v.pos = { x = p.x - v.dragOffset.x, y = p.y - v.dragOffset.y }
            end)
        end)
    end

    -- ---- the window --------------------------------------------------------------
    function v.applyNonActivating(view)
        if not view then return false, "there is no window" end
        local masks = hs.webview and hs.webview.windowMasks
        local bit   = type(masks) == "table" and masks.nonactivating or nil
        if type(bit) ~= "number" or bit < 1 then return false, "this Hammerspoon has no nonactivating window mask" end
        local function isSet(x) return (math.floor(x / bit) % 2) == 1 end
        local okGet, cur = pcall(function() return view:windowStyle() end)
        if not (okGet and type(cur) == "number") then return false, "the window style could not be read" end
        if not isSet(cur) then
            if not pcall(function() view:windowStyle(cur + bit) end) then return false, "the window style was rejected" end
        end
        local okRe, now = pcall(function() return view:windowStyle() end)
        if not (okRe and type(now) == "number") then return false, "the window style could not be read back" end
        if not isSet(now) then return false, "macOS dropped the mask" end
        return true, "applied"
    end

    function v.isOpen() return v.webview ~= nil end

    -- Pinned + Esc: the window stays, the keyboard goes back to the app
    -- (hide + show is the only hand-off a non-activating panel has).
    function v.blur()
        if not v.webview then return end
        pcall(function() v.webview:hide() end)
        pcall(function() v.webview:show() end)
    end

    function v.hide()
        v.endDrag()
        -- 6.174.0 — back to the notes list; every task but the index scan
        -- goes (a search, the ☑ list, a mentions probe, a template fetch)
        if v.mode == "search" then leaveSearch() end
        v.mode = "notes"
        stopCatTimer()
        for _, f in ipairs({ "searchTask", "tasksTask", "mentionTask", "catTask" }) do stopTask(f) end
        local sp = v.sp()
        if sp and type(sp.onHostClose) == "function" then pcall(sp.onHostClose) end
        if v.doc and v.doc.scratch and sp and not sp.findTab(v.doc.scratch) then v.doc = nil end
        if v.rescanTimer then pcall(function() v.rescanTimer:stop() end); v.rescanTimer = nil end
        if v.webview then pcall(function() v.webview:delete() end); v.webview = nil end
        v.uc = nil
        if v.dirty then v.saveNow() end
        say("closed")
    end

    local function promptFallback()
        if not v.doc then
            local okN, b, typed = pcall(hs.dialog.textPrompt, "Vault", "No web view on this Hammerspoon. Name of the note to edit:", "", "Open", "Cancel")
            if not (okN and b == "Open" and trim(typed) ~= "") then return end
            -- 6.203.0 — openNote can now REFUSE, and the next line reads
            -- v.doc.name: a refusal here used to be impossible and would
            -- otherwise have become a throw on this Hammerspoon-without-a
            -- -web-view, which is the one that cannot show a page error.
            local okO, whyO = v.openNote(typed)
            if not okO then alert("🕸 " .. tostring(whyO or "that name cannot be used"), 5) return end
        end
        local okP, button, typed = pcall(hs.dialog.textPrompt, "Vault — " .. v.doc.name,
            "No web view on this Hammerspoon — this box edits the note.", v.doc.text or "", "Save", "Cancel")
        if not okP or button ~= "Save" then return end
        v.setText(typed)
        v.saveNow()
    end

    function v.show()
        if not v.enabled then return end
        if v.webview then v.hide() return end
        return v.open()
    end

    function v.open()
        if not v.enabled then return end
        if v.webview then return end
        mkdirp(v.dir)
        if not v.doc then
            local okL, last = pcall(function() return hs.settings.get("vault.lastNote") end)
            if okL and type(last) == "string" and last ~= "" then
                local name, sub = last:match("([^/]+)%.md$"), last:match("^(.*)/[^/]*$")
                if name and readFile(v.dir .. "/" .. last) ~= nil then v.openNote(name, sub) end
            end
        end
        if not (hs.webview and hs.webview.usercontent) then promptFallback() return end

        local screen = hs.screen.mainScreen and hs.screen.mainScreen()
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(v.width, sf.w - 40)
        local h = math.min(v.height, sf.h - 40)
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 2, w = w, h = h }
        if v.pos and _G.clampToScreen then
            local okC, p = pcall(_G.clampToScreen, v.pos, w, h)
            if okC and type(p) == "table" then rect.x, rect.y = p.x, p.y end
        end

        local okUc, uc = pcall(hs.webview.usercontent.new, "vault")
        if not (okUc and uc) then promptFallback() return end
        v.uc = uc     -- HELD
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then print("🕸 Vault: message handler — " .. tostring(err)) end
            end)
        end)
        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then v.uc = nil; promptFallback() return end
        v.webview = view
        pcall(function() view:windowTitle("Vault") end)
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:closeOnEscape(false) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        if type(v.alpha) == "number" and v.alpha > 0 and v.alpha < 1 then pcall(function() view:alpha(v.alpha) end) end
        pcall(function() view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
        v.nonActivatingApplied, v.nonActivatingWhy = false, "not requested"
        if v.nonActivating then
            v.nonActivatingApplied, v.nonActivatingWhy = v.applyNonActivating(view)
            if not v.nonActivatingApplied then
                print("🕸 Vault: non-activating panel unavailable — " .. tostring(v.nonActivatingWhy))
            end
        end
        v.render()
        pcall(function() view:show() end)
        if v.focusOnOpen then pcall(function() view:bringToFront(true) end) end
        if _G.hyperExpectRelease then pcall(_G.hyperExpectRelease, 1.5, "the vault") end
        v.opens = v.opens + 1
        v.scan("open")
        local okT, rt = pcall(hs.timer.doEvery, v.rescanEvery, function() if v.webview then v.scan("timer") end end)
        v.rescanTimer = okT and rt or nil     -- HELD
        say("opened — " .. #v.notes .. " notes")
    end
    v.toggle = v.show

    -- ---- registrations --------------------------------------------------------------
    core.hyperAddShortcut({}, v.key, function() v.toggle() end, "vault")

    if _G.claimEscape then
        _G.claimEscape("vault", nil, function() return v.webview ~= nil and not v.pinned end, function() v.hide() end)
    end
    pcall(function() v.pinned = hs.settings.get("vault.pinned") == true end)

    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "vault",
        frame = function() return v.webview and v.webview:frame() end,
        move  = function(x, y)
            if not v.webview then return end
            local f = v.webview:frame()
            v.webview:frame({ x = x, y = y, w = f.w, h = f.h })
            v.pos = { x = x, y = y }
        end,
    })

    _G.editors = _G.editors or {}
    table.insert(_G.editors, {
        name  = "Vault",
        key   = "⇪" .. v.key,
        what  = "linked Markdown notes in OneDrive",
        order = 23,
        view  = function() return v.webview end,
        show  = function() if not v.webview then v.show() end end,
        size  = function() return v.doc and #(v.doc.text or "") or 0 end,
        text  = function() return v.doc and v.doc.text or "" end,
    })

    core.provide("vault.show",   function() v.show() return true end)
    core.provide("vault.open",   function(name) return v.openNote(tostring(name or "")) end)
    core.provide("vault.rescan", function() return v.scan("service") end)
    core.provide("vault.report", function() return _G.vaultReport() end)
    -- 6.174.0
    core.provide("vault.search", function(q) v.mode = "search"; v.searchQuery = tostring(q or ""); return v.runSearch() end)
    core.provide("vault.tasks",  function() v.mode = "tasks"; return v.listTasks() end)
    -- 6.180.0 — what ⇪⇧U needs from the vault, and nothing more.
    -- vault.names() lists the notes the index knows (for "put it in an
    -- existing note"); vault.link(note, line) appends ONE line under a
    -- heading, creating the note if it is new, and never twice.
    core.provide("vault.names", function()
        local names = {}
        for _, n in ipairs(v.notes or {}) do names[#names + 1] = n.name end
        table.sort(names)
        return names
    end)
    core.provide("vault.link", function(name, line, sub)
        name, line = tostring(name or ""), tostring(line or "")
        if name == "" or line == "" then return false, "nothing to link" end
        local ok, why = v.openNote(name, sub)
        if not ok then return false, tostring(why or "could not open the note") end
        local text = (v.doc and v.doc.text) or ""
        if text:find(line, 1, true) then
            return true, "already linked"     -- idempotent: press it twice, one line
        end
        local head = tostring(v.linkSection or "## Linked")
        if not text:find(head, 1, true) then
            if text ~= "" and text:sub(-1) ~= "\n" then text = text .. "\n" end
            text = text .. "\n" .. head .. "\n"
        end
        -- put the line directly under the heading, so the newest is first
        local at = text:find(head, 1, true) + #head
        local before, after = text:sub(1, at), text:sub(at + 1)
        if before:sub(-1) ~= "\n" then before = before .. "\n" end
        v.setText(before .. line .. "\n" .. after)
        v.saveNow()
        return true, "linked"
    end)

    function _G.vaultRescan() return v.scan("console") end
    function _G.vaultReport()
        local L = {}
        L[#L + 1] = "🕸 Vault — ⇪" .. v.key .. (v.enabled and "" or " (disabled)")
        L[#L + 1] = "   folder : " .. v.dir .. (v.cloudDir and "" or "  (no OneDrive found — local only)")
        L[#L + 1] = "   notes  : " .. #v.notes .. " · link lines: " .. v.linkLines .. (v.partial and " (PARTIAL — over the cap)" or "")
        local nb, nu = 0, 0
        for _ in pairs(v.backlinks) do nb = nb + 1 end
        for _ in pairs(v.unresolved) do nu = nu + 1 end
        L[#L + 1] = "   links  : " .. nb .. " notes linked to · " .. nu .. " linked names with no file yet"
        -- 6.174.0 — tags, templates, search, tasks, mentions
        if #v.tagList == 0 then
            L[#L + 1] = "   tags   : none yet — type #word in a note"
        else
            local tagged, top = 0, {}
            for _, list in pairs(v.tagsOf) do if #list > 0 then tagged = tagged + 1 end end
            for i = 1, math.min(3, #v.tagList) do top[#top + 1] = "#" .. v.tagList[i].key .. " " .. v.tagList[i].count end
            L[#L + 1] = "   tags   : " .. #v.tagList .. " tags on " .. tagged .. " notes · top " .. table.concat(top, " · ")
                        .. (v.tagsPartial and " (PARTIAL — over the cap)" or "")
        end
        -- 6.185.0 — the FIELDS a ```dataview WHERE can ask about. Says the
        -- degraded state honestly: a front-matter grep that failed leaves no
        -- fields at all, and the reason belongs on the line, not in a log.
        if v.fmErr then
            L[#L + 1] = "   fields : none — the front-matter grep failed (" .. tostring(v.fmErr) .. ")"
        elseif #v.fmFields == 0 then
            L[#L + 1] = "   fields : none yet — put `status: reading` under a --- line at the top of a note"
        else
            local withFm, top = 0, {}
            for _, t in pairs(v.fmOf) do if next(t) then withFm = withFm + 1 end end
            for i = 1, math.min(4, #v.fmFields) do top[#top + 1] = v.fmFields[i].name .. " " .. v.fmFields[i].count end
            L[#L + 1] = "   fields : " .. #v.fmFields .. " on " .. withFm .. " notes · " .. table.concat(top, " · ")
                        .. " — a query can WHERE on any of them"
        end
        -- 6.186.0 — the board is the one view that WRITES, so it says so:
        -- how many cards it has moved and what the last one was. A refused
        -- move is named here too, not only in an alert that has gone.
        L[#L + 1] = "   board  : groups by " .. tostring(v.boardField) .. " · " .. v.moves .. " card"
                    .. (v.moves == 1 and "" or "s") .. " moved"
                    .. (v.lastMove and (" · last: " .. v.lastMove) or "")
                    .. (v.moveFails > 0 and ("  ⚠️ " .. v.moveFails .. " refused" .. (v.moveErr and (" — " .. v.moveErr) or "")) or "")
        local tpls, dailyT = v.templates(), v.templateByName(v.dailyTemplate or "")
        L[#L + 1] = "   templates: " .. (#tpls > 0 and (#tpls .. " in " .. tostring(v.templatesDir) .. "/")
                        or ("none — put .md files in " .. tostring(v.templatesDir) .. "/"))
                    .. " · daily template: " .. (dailyT and dailyT.rel or "none")
        local ls = v.lastSearch
        L[#L + 1] = "   search : " .. (ls and ("\"" .. ls.q .. "\" → " .. ls.hits .. " hits in " .. ls.files .. " notes · "
                        .. os.date("%b %d %H:%M", ls.when) .. " · " .. v.searches .. " searches") or "never (⌘⇧F)")
                    .. (v.searchErr and ("  ⚠️ " .. v.searchErr) or "")
        if v.lastTasks then
            local files = {}
            for _, r in ipairs(v.taskRows) do files[r.r] = true end
            local nf = 0
            for _ in pairs(files) do nf = nf + 1 end
            L[#L + 1] = "   tasks  : " .. #v.taskRows .. (v.taskMore and "+" or "") .. " open in " .. nf .. " notes · listed "
                        .. os.date("%b %d %H:%M", v.lastTasks) .. (v.tasksErr and ("  ⚠️ " .. v.tasksErr) or "")
        else
            L[#L + 1] = "   tasks  : not listed yet (⌘⇧K)" .. (v.tasksErr and ("  ⚠️ " .. v.tasksErr) or "")
        end
        local m, u = "no note open", v.unlinked
        if v.doc and v.doc.scratch then m = "not for a scratch tab"
        elseif v.doc and u.key ~= v.doc.key then m = "not searched for " .. v.doc.rel .. (v.doc.created and " (new note)" or "")
        elseif v.doc and u.pending then m = "looking for " .. v.doc.rel
        elseif v.doc and u.why == "too short" then m = "not searched for " .. v.doc.rel .. " (name too short)"
        elseif v.doc and u.why then m = "not searched for " .. v.doc.rel .. " (" .. u.why .. ")"
        elseif v.doc then m = (#u.rels == 0 and "none" or tostring(#u.rels) .. " unlinked") .. " for " .. v.doc.rel end
        L[#L + 1] = "   mentions: " .. m .. " · extracts: " .. v.extracts .. " · random: " .. v.randoms
        L[#L + 1] = "   scan   : " .. (v.scanning and "running" or (v.lastScan and os.date("%b %d %H:%M", v.lastScan) or "never"))
                    .. " · " .. v.scans .. " so far" .. (v.scanErr and ("  ⚠️ " .. v.scanErr) or "")
        L[#L + 1] = "   open   : " .. (v.doc and (v.doc.rel .. " · " .. #(v.doc.text or "") .. " chars") or "no note")
                    .. (v.mode ~= "notes" and (" · mode: " .. v.mode) or "")
                    .. (v.dirty and " · unsaved keystrokes pending" or "") .. " · saves: " .. v.saves
                    .. " · failed writes: " .. v.saveFails .. (v.lastSaveErr and ("  ⚠️ " .. v.lastSaveErr) or "")
        L[#L + 1] = "   help   : format bar " .. (v.formatBar == false and "off (formatBar)" or "on")
                    .. " · \"/\" on an empty line lists every block · ⌘B ⌘I ⌘E "
                    .. "· the footer names the line you are on"
        L[#L + 1] = "   window : " .. (v.webview and "open" or "closed") .. (v.pinned and " · 📌 pinned" or "") .. " · opens: " .. v.opens
            -- 6.175.2 — solid is the default now, so the hint points the
            -- other way: a report that tells you how to get what you
            -- already have is a report nobody reads twice.
            .. string.format(" · alpha %.2f%s", v.alpha,
                   v.alpha >= 1 and " (solid; vault = { alpha = 0.95 } to see through it)"
                                 or " (see-through; vault = { alpha = 1 } for solid)")
                    .. " · non-activating: " .. tostring(v.nonActivatingWhy)
        local sp = v.sp()
        L[#L + 1] = "   scratch: " .. (sp and (#sp.tabs .. " tab" .. (#sp.tabs == 1 and "" or "s") .. " of the Scorp Pad shown here (⇪1)"
                    .. ((v.doc and v.doc.scratch) and " · one is open" or "")) or "not hosted (the Scorp Pad is off or has its own window)")
        L[#L + 1] = "   Obsidian: open this folder as a vault in Obsidian on either Mac — same files, its plug-ins on top"
        local out = table.concat(L, "\n")
        print(out)
        return out
    end
end

return M
