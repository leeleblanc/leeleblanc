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
-- 🚨 WHAT THIS MODULE DELIBERATELY DOES NOT DO. No eventtap (the page's
-- own keydown handles ⌘N/⌘D/⌘G/⌘K/⌘⏎/Esc). No AX or hs.window read. No
-- timer that is not held. No read of a note that is not open. No file
-- delete or rename — Finder and Obsidian do those better. Without a
-- webview it falls back to hs.dialog and still saves.
-- =====================================================================

local M = {
    name    = "Vault",
    order   = 13.38,
    family  = "capture",
    summary = "⇪3 linked Markdown notes in OneDrive: [[wikilinks]], backlinks, "
              .. "a graph of the connections, Obsidian-compatible files",
    cheatsheet = {
        title = "🕸 VAULT (⇪3 / ⇪1 — Markdown notes that link to each other, in OneDrive; the Scorp Pad's tabs too)",
        entries = {
            { "⇪3 · ⇪1",    "Open / close the window — ⇪3 on your last note, ⇪1 on your scratch tabs" },
            { "📝 SCRATCH",  "Top of the list: the Scorp Pad's tabs · ⌘T new · ⌘W close · ⌘1–9 · ⌃Tab · history on the right" },
            { "[[",         "Type [[ and pick a note — [[Name]] links to Name.md, creating it on follow" },
            { "⌘⏎",         "Follow the link under the caret (a note, or a file link opens the file)" },
            { "⌘N · ⌘D",    "New note · today's daily note (Daily/YYYY-MM-DD.md)" },
            { "⌘G",         "Graph: every note a dot, every link a line; click a dot, drag to untangle" },
            { "⌘K",         "Link a file from anywhere in OneDrive (a relative Markdown link)" },
            { "⌘F · ↑↓ ⏎",  "Filter the list · walk it (⌥↑/⌥↓ from inside the text)" },
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
        width         = 1240,
        height        = 820,
        alpha         = 1,
        fontSize      = 16,
        dir           = nil,          -- set below; a settings override replaces it
        dailyDir      = "Daily",      -- subfolder for ⌘D notes
        saveDelay     = 0.3,
        rescanEvery   = 300,          -- seconds between background rescans while open
        maxNotes      = 5000,         -- rows embedded in the page
        maxLinkLines  = 40000,        -- grep lines parsed (past this the graph is partial and says so)
        focusOnOpen   = true,
        nonActivating = true,
        skipDirs      = { ".obsidian", ".trash", ".git" },
        FIND          = "/usr/bin/find",
        GREP          = "/usr/bin/grep",

        -- state
        notes = {}, byKey = {}, links = {}, backlinks = {}, unresolved = {},
        doc = nil, dirty = false, saves = 0, saveFails = 0, lastSaveErr = nil,
        webview = nil, uc = nil, saveTimer = nil, rescanTimer = nil,
        findTask = nil, grepTask = nil, scanning = false, scans = 0, lastScan = nil,
        scanErr = nil, linkLines = 0, partial = false,
        dragTimer = nil, dragOffset = nil, opens = 0,
        nonActivatingApplied = false, nonActivatingWhy = "not requested",
        caret = 0, filter = "", view = "edit", pos = nil, pinned = false,
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

    function v.setNotes(rels)
        local notes, byKey = {}, {}
        for _, rel in ipairs(rels) do
            if #notes >= v.maxNotes then v.partial = true break end
            local n = v.noteFromRel(rel)
            if not byKey[n.key] then notes[#notes + 1] = n; byKey[n.key] = n end
        end
        table.sort(notes, function(a, b) return a.key < b.key end)
        v.notes, v.byKey = notes, byKey
        -- links of notes that vanished go with them
        for rel in pairs(v.links) do
            local keep = false
            for _, n in ipairs(notes) do if n.rel == rel then keep = true break end end
            if not keep then v.links[rel] = nil end
        end
        rebuildBacklinks()
    end

    -- "path:[[Target|x]]" lines from grep → v.links
    function v.setLinkLines(out)
        local links, count = {}, 0
        local prefix = v.dir .. "/"
        for line in tostring(out or ""):gmatch("[^\n]+") do
            count = count + 1
            if count > v.maxLinkLines then v.partial = true break end
            local path, inner = line:match("^(.-):%[%[(.-)%]%]$")
            if path and inner then
                local rel = path:sub(1, #prefix) == prefix and path:sub(#prefix + 1) or path
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

    -- Two hs.tasks, held, one after the other. Nothing on the main thread
    -- touches a note file here — that is the whole point (see the header).
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
            v.scanning, v.findTask, v.grepTask = false, nil, nil
            v.scanErr, v.lastScan, v.scans = err, os.time(), v.scans + 1
            if err then warn("scan: " .. err) else say("scan: " .. #v.notes .. " notes, " .. v.linkLines .. " link lines (" .. tostring(reason) .. ")") end
            if v.webview then v.render() end
        end
        local okF, ft = pcall(hs.task.new, v.FIND, function(code, out, serr)
            local rels = {}
            local prefix = v.dir .. "/"
            for line in tostring(out or ""):gmatch("[^\n]+") do
                if line:sub(1, #prefix) == prefix then rels[#rels + 1] = line:sub(#prefix + 1) end
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
                finish(nil)
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
            v.scheduleSave()
        end
    end

    -- Open a note by name. A missing one is CREATED (in the vault root,
    -- or under `sub` — "Daily" for ⌘D) with a heading of its name. The
    -- only main-thread file read in the module happens here, for one
    -- file, because you asked for it.
    function v.openNote(name, sub, seed)
        name = safeName(name)
        if name == "" then return false, "no name" end
        if v.doc and v.dirty then v.saveNow() end
        local n = v.find(name)
        if not n then
            local rel = (sub and sub ~= "") and (sub .. "/" .. name .. ".md") or (name .. ".md")
            n = v.noteFromRel(rel)
            n.text = seed or ("# " .. name .. "\n\n")
            n.created = true
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
        if v.dirty then v.saveNow() end
        pcall(function() hs.settings.set("vault.lastNote", n.rel) end)
        say("opened " .. n.rel)
        return true
    end

    function v.openDaily()
        local day = os.date("%Y-%m-%d")
        return v.openNote(day, v.dailyDir, "# " .. os.date("%A %d %B %Y") .. "\n\n")
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
        local decoded = target:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
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

    -- ---- the page ------------------------------------------------------------------
    function v.notesJson()
        local rows = {}
        for _, n in ipairs(v.notes) do rows[#rows + 1] = "{n:" .. jstr(n.name) .. ",r:" .. jstr(n.rel) .. "}" end
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
]==] .. theme .. [==[
</style></head><body class="]==] .. (v.view == "graph" and "graph" or "") .. [==["><div id="wrap">
<header id="hdr"><span class="name">]==] .. (isTab and "📝 Scorp Pad" or "🕸 Vault") .. [==[</span><span class="doc" title="]==] .. escapeHtml(d and d.rel or "") .. [==[">]==] .. escapeHtml(d and d.name or "no note open") .. [==[</span>
<span class="hint">]==] .. escapeHtml(status) .. [==[</span>
]==] .. (v.lastSaveErr and ('<span class="bad" title="' .. escapeHtml(v.lastSaveErr) .. '">⚠ not saved</span>') or "") .. [==[
]==] .. (sp and '<button onclick="say({a:\'tabnew\'})" title="New scratch tab ⌘T">📝+</button>' or "") .. [==[
]==] .. (isTab and '<button onclick="say({a:\'tabclose\', tid: CUR.slice(8)})" title="Close this tab ⌘W (its text goes to the history)">⌘W</button><button onclick="say({a:\'send\'})" title="Create today\'s Asana task now instead of waiting for 16:00">→ Asana now</button>' or "") .. [==[
<button onclick="say({a:'new'})" title="New note ⌘N">✚</button>
<button onclick="say({a:'daily'})" title="Today ⌘D">📅</button>
<button onclick="say({a:'linkfile'})" title="Link a file ⌘K">📎</button>
<button id="gbtn" class="]==] .. (v.view == "graph" and "on" or "") .. [==[" onclick="say({a:'graph'})" title="Graph ⌘G">🕸</button>
<button onclick="say({a:'rescan'})" title="Rescan the folder">↻</button>
<button id="pin" class="]==] .. (v.pinned and "on" or "") .. [==[" onclick="say({a:'pin'})" title="Pin: the window stays up beside the app; Esc only hands the keyboard back">📌</button>
<button onclick="say({a:'hide'})" title="Close ⇪3 / ⇪1 / Esc">✕</button></header>
<div id="main">
<div id="side"><input id="q" placeholder="filter notes… ⌘F" value="]==] .. escapeHtml(v.filter) .. [==["><ul id="rows"></ul></div>
<div id="ed"><textarea id="t" spellcheck="true" ]==] .. (d and "" or "disabled placeholder=\"⌘N a new note · ⌘D today · click a note on the left\"") .. [==[>]==] .. escapeHtml(d and d.text or "") .. [==[</textarea><div id="ac"></div></div>
<div id="links"><h4>LINKS OUT</h4><ul id="outs">]==] .. (#outs > 0 and table.concat(outs) or '<div class="none">type [[ to link</div>') .. [==[</ul>
]==] .. (isTab and ('<h4>HISTORY · closed tabs</h4><ul id="hist">' .. (#hist > 0 and table.concat(hist) or '<div class="none">closed tabs land here — ⌘W</div>') .. '</ul>')
             or ('<h4>BACKLINKS</h4><ul id="backs">' .. (#backs > 0 and table.concat(backs) or '<div class="none">nothing links here yet</div>') .. '</ul>')) .. [==[</div>
<div id="graph"><canvas id="cv"></canvas><div id="gtip">click a dot to open · drag to untangle · hollow = not written yet · ⌘G back</div></div>
</div></div>
<script>
var NOTES = ]==] .. v.notesJson() .. [==[;
var GRAPH = ]==] .. v.graphJson() .. [==[;
var CUR = ]==] .. jstr(d and d.rel or "") .. [==[;
var CARET = ]==] .. tostring(tonumber(v.caret) or 0) .. [==[;
var VIEW = ]==] .. jstr(v.view) .. [==[;
var TABS = []==] .. table.concat(tabsJs, ",") .. [==[], HASPAD = ]==] .. (sp and "true" or "false") .. [==[;
var t = document.getElementById('t'), q = document.getElementById('q'), hdr = document.getElementById('hdr');
var ac = document.getElementById('ac'), rowsEl = document.getElementById('rows');
function say(m){ m.text = t.value; m.sel = t.selectionStart; m.rel = CUR;
  try { window.webkit.messageHandlers.vault.postMessage(m); } catch(e){} }
t.addEventListener('input', function(){ say({a:'edit'}); autocomplete(); });
hdr.addEventListener('mousedown', function(e){ if (e.button !== 0 || e.target.tagName === 'BUTTON') return;
  e.preventDefault(); hdr.classList.add('dragging'); say({a:'dragStart'}); });
window.addEventListener('mouseup', function(){ hdr.classList.remove('dragging'); });
document.addEventListener('keyup', function(e){
  if (e.key === 'F18' || e.keyCode === 79) say({a:'f18up'}); });

// ---- the note list (filtered) ----
function esc(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;'); }
function drawRows(){
  var f = (q.value || '').toLowerCase().trim(), h = [], n = 0, s = [];
  // 6.173.0 — the Scorp Pad's tabs first, a section of their own
  for (var j = 0; j < TABS.length; j++) {
    var tb = TABS[j];
    if (f && tb.t.toLowerCase().indexOf(f) < 0) continue;
    s.push('<li class="tab' + (tb.k ? ' ' + esc(tb.k) : '') + ('scratch:' + tb.id === CUR ? ' cur' : '') + '" data-tab="' + esc(tb.id) + '"><span class="tt">' + (tb.b ? esc(tb.b) + ' ' : '') + esc(tb.t) + '</span><span class="x" title="Close ⌘W">×</span></li>');
  }
  if (HASPAD) { s.unshift('<li class="sec">📝 SCRATCH</li>'); if (!f) s.push('<li class="add" data-tab="+">+ new tab ⌘T</li>'); s.push('<li class="sec">🕸 NOTES</li>'); }
  for (var i = 0; i < NOTES.length; i++) {
    var x = NOTES[i];
    if (f && x.n.toLowerCase().indexOf(f) < 0 && x.r.toLowerCase().indexOf(f) < 0) continue;
    h.push('<li class="note' + (x.r === CUR ? ' cur' : '') + '" data-name="' + esc(x.n) + '" title="' + esc(x.r) + '">' + esc(x.n) + '</li>');
    if (++n >= 400) break;
  }
  if (!h.length) h.push('<li style="opacity:.4;cursor:default">' + (f ? 'no note matches — ⏎ creates &quot;' + esc(q.value.trim()) + '&quot;' : 'no notes yet — ⌘N') + '</li>');
  rowsEl.innerHTML = s.join('') + h.join('');
  SEL = -1;
}
rowsEl.addEventListener('click', function(e){
  var li = e.target.closest ? e.target.closest('li[data-name],li[data-tab]') : null; if (!li) return;
  var tid = li.getAttribute('data-tab');
  if (tid === '+') say({a:'tabnew'});
  else if (tid) { if (e.target.closest && e.target.closest('.x')) say({a:'tabclose', tid: tid}); else say({a:'tab', tid: tid}); }
  else say({a:'open', name: li.getAttribute('data-name')}); });
document.getElementById('links').addEventListener('click', function(e){
  var li = e.target.closest ? e.target.closest('li[data-name],li[data-hist]') : null; if (!li) return;
  if (li.getAttribute('data-hist')) say({a:'restore', rid: li.getAttribute('data-hist')});
  else say({a:'open', name: li.getAttribute('data-name')}); });
q.addEventListener('input', function(){ say({a:'filter', f: q.value}); drawRows(); });
q.addEventListener('keydown', function(e){
  if (e.key === 'Enter' && SEL < 0 && q.value.trim()) { e.preventDefault(); say({a:'open', name: q.value.trim()}); }
});

// ⌨️ 6.170.0 — ARROW THROUGH THE ROWS. ⌥↑/⌥↓ always; plain ↑/↓ when the
// caret is not in the text; ⏎ / ⌥⏎ acts on the highlighted row.
var SEL = -1, ROWSEL = '#rows li[data-name],#rows li[data-tab]';
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
  var tid = r.getAttribute('data-tab');
  if (tid === '+') say({a:'tabnew'}); else if (tid) say({a:'tab', tid: tid});
  else say({a:'open', name: r.getAttribute('data-name')}); }
function isTab(){ return CUR.indexOf('scratch:') === 0; }

// ---- [[ autocomplete ----
var ACSEL = 0, ACITEMS = [], ACSTART = -1;
function acOpen(){ return ac.style.display === 'block'; }
function acClose(){ ac.style.display = 'none'; ACITEMS = []; ACSTART = -1; }
function autocomplete(){
  var pos = t.selectionStart, head = t.value.slice(0, pos);
  var i = head.lastIndexOf('[[');
  if (i < 0 || head.indexOf(']]', i) >= 0 || head.slice(i).indexOf('\n') >= 0) { acClose(); return; }
  // the caret is INSIDE a finished link (its ]] is ahead on this line): no list
  var tail = t.value.slice(pos).split('\n')[0], c2 = tail.indexOf(']]'), o2 = tail.indexOf('[[');
  if (c2 >= 0 && (o2 < 0 || c2 < o2)) { acClose(); return; }
  var typed = head.slice(i + 2).toLowerCase(), items = [];
  for (var k = 0; k < NOTES.length && items.length < 8; k++) {
    if (!typed || NOTES[k].n.toLowerCase().indexOf(typed) >= 0) items.push(NOTES[k].n);
  }
  if (!items.length) { acClose(); return; }
  ACITEMS = items; ACSEL = 0; ACSTART = i + 2;
  var h = [];
  for (var j = 0; j < items.length; j++) h.push('<div class="' + (j === 0 ? 'sel' : '') + '" data-i="' + j + '">' + esc(items[j]) + '</div>');
  ac.innerHTML = h.join('');
  ac.style.display = 'block';
  ac.style.left = '20px'; ac.style.top = Math.min(t.clientHeight - 80, 40 + 24 * (head.split('\n').length)) + 'px';
}
function acDraw(){ var ds = ac.children; for (var i = 0; i < ds.length; i++) ds[i].className = i === ACSEL ? 'sel' : ''; }
function acAccept(i){
  var name = ACITEMS[i]; if (name == null) return;
  var pos = t.selectionStart, after = t.value.slice(pos);
  var close = after.indexOf(']]') === 0 ? '' : ']]';
  t.value = t.value.slice(0, ACSTART) + name + close + after;
  var np = ACSTART + name.length + 2;
  try { t.setSelectionRange(np, np); } catch(e){}
  acClose(); say({a:'edit'});
}
ac.addEventListener('mousedown', function(e){ var d = e.target; if (d && d.getAttribute && d.getAttribute('data-i') != null) { e.preventDefault(); acAccept(+d.getAttribute('data-i')); } });

// ---- the link under the caret: [[wiki]] first, then [text](target) ----
function linkAtCaret(){
  var pos = t.selectionStart, s = t.value, re = /\[\[([^\]]+)\]\]/g, m;
  while ((m = re.exec(s))) { if (pos >= m.index && pos <= m.index + m[0].length) return { target: m[1], md: false }; }
  re = /\[([^\]]*)\]\(([^)]+)\)/g;
  while ((m = re.exec(s))) { if (pos >= m.index && pos <= m.index + m[0].length) return { target: m[2], md: true }; }
  return null;
}
function insertAtCaret(str){
  var a = t.selectionStart, b = t.selectionEnd;
  t.value = t.value.slice(0, a) + str + t.value.slice(b);
  try { t.setSelectionRange(a + str.length, a + str.length); } catch(e){}
  say({a:'edit'});
}

document.addEventListener('keydown', function(e){
  var meta = e.metaKey || e.ctrlKey;
  if (acOpen() && !meta) {
    if (e.key === 'ArrowDown') { e.preventDefault(); ACSEL = (ACSEL + 1) % ACITEMS.length; acDraw(); return; }
    if (e.key === 'ArrowUp') { e.preventDefault(); ACSEL = (ACSEL + ACITEMS.length - 1) % ACITEMS.length; acDraw(); return; }
    if (e.key === 'Enter' || e.key === 'Tab') { e.preventDefault(); acAccept(ACSEL); return; }
    if (e.key === 'Escape') { e.preventDefault(); acClose(); return; }
  }
  if (e.key === 'Escape') { e.preventDefault(); say({a:'esc'}); return; }
  if (rowKey(e)) return;
  // 6.173.0 — the Scorp Pad's tab keys, from anywhere in the window
  if (e.ctrlKey && e.key === 'Tab') { e.preventDefault(); if (HASPAD) say({a:'tabcycle', d: e.shiftKey ? -1 : 1}); return; }
  if (meta && (e.key === 't' || e.key === 'T')) { e.preventDefault(); if (HASPAD) say({a:'tabnew'}); return; }
  if (meta && (e.key === 'w' || e.key === 'W')) { e.preventDefault(); if (isTab()) say({a:'tabclose', tid: CUR.slice(8)}); return; }
  if (meta && e.key >= '1' && e.key <= '9') { e.preventDefault(); if (HASPAD) say({a:'tabnth', n: e.key}); return; }
  if (meta && e.key === 'Enter') { e.preventDefault(); var l = linkAtCaret(); if (l) say({a:'follow', target: l.target, md: l.md}); return; }
  if (meta && (e.key === 'n' || e.key === 'N')) { e.preventDefault(); say({a:'new'}); return; }
  if (meta && (e.key === 'd' || e.key === 'D')) { e.preventDefault(); say({a:'daily'}); return; }
  if (meta && (e.key === 'g' || e.key === 'G')) { e.preventDefault(); say({a:'graph'}); return; }
  if (meta && (e.key === 'k' || e.key === 'K')) { e.preventDefault(); say({a:'linkfile'}); return; }
  if (meta && (e.key === 'f' || e.key === 'F')) { e.preventDefault(); q.focus(); q.select(); return; }
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
drawRows();
if (VIEW === 'graph') { graphStart(); } else { t.focus(); try { t.setSelectionRange(CARET, CARET); } catch(e){} }
</script></body></html>]==]
        return (html:gsub("FSLABEL", tostring(math.floor(fs - 3))):gsub("FS1px", math.floor(fs - 2) .. "px")
                    :gsub("FS2px", math.floor(fs - 3) .. "px"):gsub("FSpx", math.floor(fs) .. "px"))
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
            if v.openNote(tostring(body.name or "")) then v.filter = ""; v.render() end
        elseif a == "new" then
            local okP, button, typed = pcall(hs.dialog.textPrompt, "New note", "Name of the note:", "", "Create", "Cancel")
            if okP and button == "Create" and trim(typed) ~= "" then
                if v.openNote(typed) then v.render() end
            end
        elseif a == "daily" then
            if v.openDaily() then v.render() end
        elseif a == "follow" then
            if v.follow(tostring(body.target or ""), body.md == true) and not body.md then v.render()
            elseif body.md then say("opened " .. tostring(body.target)) end
        elseif a == "graph" then
            v.view = (v.view == "graph") and "edit" or "graph"
            v.render()
        elseif a == "linkfile" then
            local link, why = v.linkFile()
            if link then
                if v.webview then
                    pcall(function() v.webview:evaluateJavaScript("insertAtCaret(" .. jstr(link) .. ")") end)
                end
            elseif why ~= "cancelled" then
                pcall(function() hs.alert.show("🕸 " .. tostring(why), 2) end)
            end
        elseif a == "rescan" then
            v.scan("button"); v.render()
        -- 6.173.0 — the Scorp Pad's tabs (its module does the work)
        elseif a == "tab" then
            if v.openScratch(tostring(body.tid or "")) then v.render() end
        elseif a == "tabnew" then
            local sp = v.sp()
            local t = sp and sp.newTab("")
            if t and v.openScratch(t.id) then v.render() end
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
            v.openNote(typed)
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
        L[#L + 1] = "   scan   : " .. (v.scanning and "running" or (v.lastScan and os.date("%b %d %H:%M", v.lastScan) or "never"))
                    .. " · " .. v.scans .. " so far" .. (v.scanErr and ("  ⚠️ " .. v.scanErr) or "")
        L[#L + 1] = "   open   : " .. (v.doc and (v.doc.rel .. " · " .. #(v.doc.text or "") .. " chars") or "no note")
                    .. (v.dirty and " · unsaved keystrokes pending" or "") .. " · saves: " .. v.saves
                    .. " · failed writes: " .. v.saveFails .. (v.lastSaveErr and ("  ⚠️ " .. v.lastSaveErr) or "")
        L[#L + 1] = "   window : " .. (v.webview and "open" or "closed") .. (v.pinned and " · 📌 pinned" or "") .. " · opens: " .. v.opens
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
