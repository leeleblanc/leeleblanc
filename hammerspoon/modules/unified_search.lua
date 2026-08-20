-- =====================================================================
-- MODULE: UNIFIED SEARCH (⇪space) — one typed search over EVERY store
-- this config keeps. 6.89.0
-- =====================================================================
-- LL: "I need one unified clipboard picker where I can type and search
-- all my sources combined from command history to the screenshot
-- history folder. If there is a stored history in other words, we want
-- to search that. We even want to look at my notes and asana tasks. So
-- yes, everything."  And: "Thumbnails on image and this new tool must
-- be 50% larger, I can't read them."
--
-- WHAT IT SEARCHES — every store, read the same way its own picker
-- reads it, so this can never disagree with ⇪V or ⇪H about what exists:
--   📋 clipboard history   (⇪V's list, _G.clipboardCache)
--   ⌨️ command history      (⇪H's log, via the commands.entries service)
--   📸 the screenshot folder (⇪⇧4's listing, WITH thumbnails)
--   🗒 notes                (⇪J's files under <logs>/notes/)
--   ✅ asana tasks          (⇪⇧S's 30-day history)
--   🔤 OCR log              (⇪O's image_text CSV)
--   📄 documents            (⇪⇧W's doc_wather.csv)
--   📁 file moves           (⇪F's file_changes CSV)
--   🗒 capture pad          (⇪N's queue + parked notes)
--   🕘 chrome history       (⇪Y's 90-day export, every Chrome profile)
--   🔧 every TOOL           (⇪/'s own entries — 6.104.0, see below)
-- Every source is read inside its OWN pcall at open time: a corrupt CSV
-- costs that one source a console line, never the picker.
--
-- 🖼 WHY THIS IS A WEBVIEW AND NOT AN hs.chooser, stated bluntly because
-- it is the whole answer to "I can't read them": an hs.chooser is a
-- native NSTableView with a FIXED row height baked into Hammerspoon
-- itself (HSChooser.m sizes the panel as rowHeight × rows; there is no
-- API to change rowHeight). A thumbnail in a chooser row can NEVER
-- render taller than that row, no matter what size image we hand it —
-- which is why the ⇪⇧4 panel's thumbnails are small and stay small.
-- A webview row is ours: 19px titles (a chooser's are 13), 84px
-- thumbnails (a chooser's render ≈ 40) — both comfortably past the 50%
-- LL asked for. ⇪⇧space opens straight into "@shots", which makes THIS
-- the big-thumbnail screenshot browser the ⇪⇧4 panel cannot be.
--
-- ⏎ COPIES — it is "one unified CLIPBOARD picker": every row's Enter
-- puts the useful thing on the clipboard (text rows their full text, a
-- screenshot row the image itself). ⌘⏎ copies the file PATH instead on
-- rows that have one — the same convention the ⇪⇧4 panel taught.
--
-- 🔎 EVERY WORD MUST MATCH ("aug receipt" finds August receipts), and a
-- @tag word pins the source: @clip @cmd @shots @note @asana @ocr @doc
-- @file @pad @web @tool. Tags ride in each row's haystack, so they cost
-- nothing.
--
-- 🔧 6.104.0 — THE TOOL PICKER (⇪⇧/) MOVED IN HERE AND WAS DELETED.
-- LL: "merging ⇪space with ⇪⇧/". It was a second search box over a
-- second kind of thing, and the cost was not the code — it was having to
-- decide WHICH box before you could start typing. ⇪⇧/ still works and
-- opens this panel on "@tool ", exactly as ⇪⇧space opens it on "@shots".
-- ⏎ on a 🔧 row RUNS the tool; every other row still copies.
--
-- The JSON for the page is built BY HAND here rather than with
-- hs.json.encode: the encoder escapes `</` as well (a raw "</script>"
-- inside a clipboard entry would end the page's script tag mid-data),
-- and hand-building keeps this testable under plain Lua with no hs.

local M = {
    name  = "Unified Search",
    order = 14.4,
    family = "find",
    cheatsheet = {
        title = "🔎 UNIFIED SEARCH (⇪space — everything, one search)",
        entries = {
            { "⇪space",  "Search EVERY store: clipboard · commands · screenshots · notes · Asana · OCR · docs · file moves · pad · Chrome · every TOOL" },
            { "⇪⇧space", "Same panel opened as the BIG-thumbnail screenshot browser (@shots)" },
            { "⇪⇧/",     "Same panel opened on the TOOLS (@tool) — every shortcut, searchable" },
            { "type",    "Every word must match · a @tag word pins one source — each section header shows its tag" },
            { "⏎",       "COPY the row — text its full text, a screenshot the image, a Chrome page its URL (⇪Y reopens)" },
            { "⏎ on 🔧", "RUNS the tool instead — the one row kind that acts (else copies its key)" },
            { "⌘⏎",      "Copy the file PATH instead (rows that have one)" },
            { "↑↓ · click", "Move the selection · pick — 19px rows, 84px thumbnails" },
            { "drag",    "The header bar moves it (⌘-drag anywhere) — and it REOPENS where you left it, across reloads too" },
            { "re-centre", "_G.unifiedCenter() puts it back in the middle" },
            { "Esc",     "Close (the cheat sheet always closes after it)" },
        },
    },
}

function M.setup(core)
    local uni = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    uni.enabled = true
    uni.key     = "space"    -- ⇪space search · ⇪⇧space = screenshots view
    uni.toolKey = "/"        -- ⇪⇧/ opens the same box pinned to @tool
    uni.width, uni.height = 840, 700
    uni.thumbH  = 84         -- px — a chooser row renders ≈40; this is >2×
    uni.preview = 240        -- characters of each row shown / searched
    uni.pageCap = 60         -- rows the page lists at once ("+N more" after)
    uni.groupCap = 8         -- rows per source in the nothing-typed view
    uni.maxPer  = { clip = 400, cmd = 400, shots = 30, note = 120,
                    asana = 200, ocr = 200, doc = 200, file = 200, pad = 60,
                    web = 300 }
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("unified", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("unified", m) end end

    -- ---- tiny shared helpers ----------------------------------------------
    local function oneLine(s) return (tostring(s or ""):gsub("%s+", " ")) end

    local function prettySize(bytes)
        bytes = tonumber(bytes) or 0
        if bytes >= 1024 * 1024 then
            return string.format("%.1f MB", bytes / (1024 * 1024))
        end
        return string.format("%d KB", math.floor(bytes / 1024 + 0.5))
    end

    -- Read at most the LAST maxBytes of a file — same defence as ⇪H's
    -- loader: these logs only grow, and a keypress must never pay for a
    -- 40 MB read. Returns nil (not "") for a missing file.
    local function tailRead(path, maxBytes)
        local f = io.open(path, "rb")
        if not f then return nil end
        local size = f:seek("end") or 0
        if maxBytes and size > maxBytes then
            f:seek("set", size - maxBytes)
            f:read("*l")            -- drop the partial line we landed in
        else
            f:seek("set", 0)
        end
        local content = f:read("*a") or ""
        f:close()
        return content
    end

    -- Quote-aware CSV split (same shape as the Document Watcher's): a
    -- quoted field may contain commas and doubled quotes.
    local function csvSplit(line)
        local out, field, i, inQ = {}, {}, 1, false
        local n = #line
        while i <= n do
            local c = line:sub(i, i)
            if inQ then
                if c == '"' then
                    if line:sub(i + 1, i + 1) == '"' then
                        field[#field + 1] = '"'; i = i + 1
                    else inQ = false end
                else field[#field + 1] = c end
            elseif c == '"' then inQ = true
            elseif c == "," then
                out[#out + 1] = table.concat(field); field = {}
            else field[#field + 1] = c end
            i = i + 1
        end
        out[#out + 1] = table.concat(field)
        return out
    end

    -- ---- thumbnails ---------------------------------------------------------
    -- Decoding a 3 MB PNG to draw an 84px row is the expensive part, so:
    -- capped at maxPer.shots, and cached by path+mtime exactly like the
    -- ⇪⇧4 panel's cache — an edited file re-reads, an unchanged one never
    -- decodes twice in a session.
    uni.thumbCache = {}
    function uni.thumbFor(entry)
        local c = uni.thumbCache[entry.path]
        if c and c.mtime == entry.mtime then return c.uri end
        local uri
        pcall(function()
            local full = hs.image.imageFromPath(entry.path)
            if full then
                local small = full:setSize({ w = uni.thumbH * 1.7, h = uni.thumbH })
                if small and small.encodeAsURLString then
                    uri = small:encodeAsURLString()
                end
            end
        end)
        if type(uri) ~= "string" or not uri:find("^data:image") then uri = nil end
        if uri then uni.thumbCache[entry.path] = { mtime = entry.mtime, uri = uri } end
        return uri
    end

    -- ---- the sources --------------------------------------------------------
    -- Each takes `add` and feeds it rows:
    --   { tag, icon, src, text, sub, full, path, kind, img }
    -- text/sub are what the page SHOWS (bounded); full is what ⏎ copies
    -- (unbounded, stays on the Lua side of the bridge).

    local function srcClipboard(add)
        local cache = _G.clipboardCache
        if type(cache) ~= "table" then return end
        for i = 1, math.min(#cache, uni.maxPer.clip) do
            local it = cache[i]
            if type(it) == "table" and type(it.text) == "string" then
                add{ tag = "clip", icon = "📋", src = "Clipboard",
                     text = oneLine(it.text):sub(1, uni.preview),
                     sub  = it.date or "", full = it.text }
            end
        end
    end

    local function srcCommands(add)
        -- ⇪H's own loader, via the service registry — the log is re-read
        -- so commands run a minute ago are already here.
        local entries = core.call and core.call("commands.entries")
        if type(entries) ~= "table" then return end
        for i = 1, math.min(#entries, uni.maxPer.cmd) do
            local e = entries[i]
            if type(e) == "table" and e.cmd then
                add{ tag = "cmd", icon = "⌨️", src = "Command",
                     text = oneLine(e.cmd):sub(1, uni.preview),
                     sub  = e.when or "shell history", full = e.cmd }
            end
        end
    end

    local function srcShots(add)
        local shots = _G.screenshots
        if not (shots and type(shots.list) == "function") then return end
        local ok, l = pcall(shots.list)
        if not (ok and type(l) == "table") then return end
        for i = 1, math.min(#l, uni.maxPer.shots) do
            local e = l[i]
            add{ tag = "shots", icon = "📸", src = "Screenshot",
                 text = e.name or "",
                 sub  = os.date("%b %d %H:%M", e.mtime or 0)
                        .. " · " .. prettySize(e.size),
                 full = e.name or "", path = e.path,
                 kind = "image", img = uni.thumbFor(e) }
        end
    end

    local function srcNotes(add)
        local qa = _G.quickAppend
        if not (qa and type(qa.targets) == "table"
                and type(qa.pathFor) == "function") then return end
        local collected = {}
        for _, t in ipairs(qa.targets) do
            local okP, path = pcall(qa.pathFor, t)
            local content = okP and path and tailRead(path, 64 * 1024)
            if content then
                local cur = nil
                for line in content:gmatch("[^\r\n]*") do
                    local stamp = line:match("^──%s*(.-)%s*──$")
                    if stamp then
                        cur = { stamp = stamp, body = {},
                                name = t.name, path = path }
                        collected[#collected + 1] = cur
                    elseif cur and line ~= "" then
                        cur.body[#cur.body + 1] = line
                    end
                end
            end
        end
        -- Files are append-only, so within each file newest is LAST.
        local added = 0
        for i = #collected, 1, -1 do
            local e = collected[i]
            local body = table.concat(e.body, "\n")
            if body:gsub("%s+", "") ~= "" then
                add{ tag = "note", icon = "🗒", src = "Note",
                     text = oneLine(body):sub(1, uni.preview),
                     sub  = e.name .. " · " .. e.stamp,
                     full = body, path = e.path }
                added = added + 1
                if added >= uni.maxPer.note then break end
            end
        end
    end

    local function srcAsana(add)
        local hist = _G.asanaTaskHistory
        if type(hist) ~= "table" then return end
        local added = 0
        for i = #hist, 1, -1 do            -- appended in order → newest last
            local e = hist[i]
            if type(e) == "table" and e.title then
                local bits = {}
                if type(e.timestamp) == "number" then
                    bits[#bits + 1] = os.date("%b %d %H:%M", e.timestamp)
                end
                if e.assignee and e.assignee ~= "" then
                    bits[#bits + 1] = e.assignee
                end
                add{ tag = "asana", icon = "✅", src = "Asana task",
                     text = oneLine(e.title):sub(1, uni.preview),
                     sub  = table.concat(bits, " · "),
                     full = e.title .. ((e.desc and e.desc ~= "")
                                        and ("\n" .. e.desc) or "") }
                added = added + 1
                if added >= uni.maxPer.asana then break end
            end
        end
    end

    local function srcOCR(add)
        local file = (core.logsDir or "") .. "/image_text-"
                     .. tostring(core.hostTag) .. ".csv"
        local content = tailRead(file, 256 * 1024)
        if not content then return end
        local collected = {}
        for line in content:gmatch("[^\r\n]+") do
            local when, raw = line:match("^([^,]+),(.*)$")
            if when and raw then
                local clean = raw:gsub('^"', ''):gsub('"$', '')
                                 :gsub('""', '"'):gsub('\\n', '\n')
                collected[#collected + 1] = { when = when, text = clean }
            end
        end
        local added = 0
        for i = #collected, 1, -1 do       -- appended → newest last
            local e = collected[i]
            add{ tag = "ocr", icon = "🔤", src = "OCR",
                 text = oneLine(e.text):sub(1, uni.preview),
                 sub  = e.when, full = e.text }
            added = added + 1
            if added >= uni.maxPer.ocr then break end
        end
    end

    -- 📄 6.104.0 — TWO PLACES, ON PURPOSE, AND ONLY ONE OF THEM GROWS.
    -- The live documents now come from the Activity Tracker, which derives
    -- them from the sessions it already records (document_watcher and its
    -- doc_wather.csv were retired into it). The old CSV is still READ, so
    -- everything logged before the merge stays searchable here — it is
    -- simply never written again. Live rows go first and claim their
    -- date|file, so a day both modules saw is listed once, not twice.
    local function srcDocs(add)
        local seen, added = {}, 0

        local live
        pcall(function()
            if _G.service and _G.service.has and _G.service.has("activity.docs") then
                live = _G.service.call("activity.docs")
            end
        end)
        for _, r in ipairs(live or {}) do
            if added >= uni.maxPer.doc then break end
            if type(r) == "table" and r.file and r.date then
                seen[r.date .. "|" .. r.file] = true
                add{ tag = "doc", icon = "📄", src = "Document",
                     text = oneLine(r.file):sub(1, uni.preview),
                     sub  = r.date .. "  ·  " .. tostring(r.app or "?")
                            .. "  ·  worked " .. core.formatDuration(r.secs or 0),
                     full = r.file }
                added = added + 1
            end
        end

        local content = tailRead((core.logsDir or "") .. "/doc_wather.csv",
                                 128 * 1024)
        if not content then return end
        local collected = {}
        for line in content:gmatch("[^\r\n]+") do
            local c = csvSplit(line)
            if c[1] and c[1]:match("^%d%d%d%d%-%d%d%-%d%d$") and c[3] then
                collected[#collected + 1] = c
            end
        end
        for i = #collected, 1, -1 do
            if added >= uni.maxPer.doc then break end
            local c = collected[i]
            if not seen[c[1] .. "|" .. c[3]] then
                add{ tag = "doc", icon = "📄", src = "Document",
                     text = oneLine(c[3]):sub(1, uni.preview),
                     sub  = c[1] .. " " .. (c[2] or "")
                            .. ((c[4] and c[4] ~= "") and (" · worked " .. c[4]) or "")
                            .. "  ·  archived",
                     full = c[3] }
                added = added + 1
            end
        end
    end

    local function srcFiles(add)
        local content = tailRead((core.logsDir or "") .. "/file_changes-"
                                 .. tostring(core.hostTag) .. ".csv", 256 * 1024)
        if not content then return end
        -- 📅 6.115.0 — TWO LAYOUTS, TOLD APART PER ROW.
        --   6.115.0+ : timestamp,file_name,new_name,present,moved,event,epoch
        --   earlier  : file_name,new_name,present,moved,timestamp,event,epoch
        --
        -- 🚨 IT CANNOT READ THE HEADER TO DECIDE, and that is not laziness:
        -- tailRead deliberately reads only the LAST 256 KB of the file, so
        -- on any history worth searching the header is not in what we were
        -- handed. Sniffing the first field is the only thing available —
        -- and it is exact, because an ISO date in column one is a shape a
        -- file name cannot accidentally take while ALSO leaving an integer
        -- epoch in column seven.
        --
        -- Reading a 6.114.0 row with 6.115.0 indices would not error. It
        -- would list the file's OLD FOLDER as its name and the word
        -- "Renamed" as its date — wrong, plausible-looking, and silent.
        -- That is the whole reason this is a mapper and not a re-index.
        local function ftFields(c)
            if (c[1] or ""):match("^%d%d%d%d%-%d%d%-%d%d") then
                return { when = c[1], name = c[2] or "", newName = c[3] or "",
                         present = c[4] or "", moved = c[5] or "", event = c[6] or "" }
            end
            return { when = c[5] or "", name = c[1] or "", newName = c[2] or "",
                     present = c[3] or "", moved = c[4] or "", event = c[6] or "" }
        end

        local collected = {}
        for line in content:gmatch("[^\r\n]+") do
            local c = csvSplit(line)
            -- Either header row and any half-written line fail this shape
            -- check: an event, a name, and a date carrying at least one
            -- digit, wherever those three currently live.
            local r = ftFields(c)
            if r.event ~= "" and r.name ~= "" and r.when:match("%d") then
                collected[#collected + 1] = r
            end
        end
        local added = 0
        for i = #collected, 1, -1 do
            local r = collected[i]
            local fileName, newName = r.name, r.newName
            local loc = (r.moved ~= "") and r.moved or r.present
            local label = (newName ~= "" and newName ~= fileName)
                          and (fileName .. " → " .. newName) or fileName
            local path = loc ~= ""
                         and (loc .. "/" .. (newName ~= "" and newName or fileName))
                         or nil
            add{ tag = "file", icon = "📁", src = "File move",
                 text = oneLine(label):sub(1, uni.preview),
                 sub  = r.event .. " · " .. r.when,
                 full = path or label, path = path }
            added = added + 1
            if added >= uni.maxPer.file then break end
        end
    end

    local function srcPad(add)
        local pad = _G.capturePad
        if not (pad and type(pad.queue) == "table") then return end
        local added = 0
        local function batch(list, label)
            for i = #list, 1, -1 do
                local n2 = list[i]
                if type(n2) == "table" and n2.text and n2.text ~= "" then
                    add{ tag = "pad", icon = "🗒", src = "Capture Pad",
                         text = oneLine(n2.text):sub(1, uni.preview),
                         sub  = label .. " · "
                                .. os.date("%b %d %H:%M", n2.createdAt or 0),
                         full = n2.text }
                    added = added + 1
                    if added >= uni.maxPer.pad then return end
                end
            end
        end
        batch(pad.queue, "queued")
        if type(pad.parked) == "table" then batch(pad.parked, "parked") end
    end

    local function srcWeb(add)
        -- ⇪Y's 90-day Chrome export, already sorted newest first. ⏎ here
        -- COPIES the URL — this is the clipboard picker's contract — and
        -- ⇪Y is the control that reopens pages.
        local hist = _G.chromeHistory
        if not (hist and type(hist.entries) == "table") then return end
        for i = 1, math.min(#hist.entries, uni.maxPer.web) do
            local e = hist.entries[i]
            if type(e) == "table" and type(e.url) == "string" then
                add{ tag = "web", icon = "🕘", src = "Chrome",
                     text = oneLine((e.title and e.title ~= "") and e.title
                                    or e.url):sub(1, uni.preview),
                     sub  = (e.when or "") .. " · " .. e.url:sub(1, 90),
                     full = e.url }
            end
        end
    end

    -- ---- 🔧 THE TOOLS THEMSELVES (6.104.0 — absorbed from tool_picker) ------
    -- LL: "merging ⇪space with ⇪⇧/". They were two search boxes over two
    -- kinds of thing you look for the same way — "where did I put that"
    -- and "what was that key again" — and keeping them apart meant
    -- remembering WHICH box before you could search at all. Now the tools
    -- are just another source: @tool pins them, ⇪⇧/ opens straight into
    -- that, and typing "url" in the one box finds both the link cleaner
    -- and the URLs you copied.
    --
    -- ⏎ ON A TOOL ROW RUNS IT. That is the one row kind whose Enter is not
    -- a copy, and it is deliberate: being told "⇪K" and left to press it
    -- yourself is the least useful of the three outcomes, so it is the
    -- FALLBACK — a tool with no runnable service copies its key instead.
    --
    -- ⚠️ EVERY VALUE HERE MUST BE A REAL SERVICE NAME. _G.service.call does
    -- NOT throw on a missing provider — it prints and returns — so a typo
    -- would make this report "ran it" while doing nothing. Names are
    -- checked against the live registry AND against the live cheat sheet
    -- at first use (uni.verifyTools), because a run map is a join between
    -- two tables that both change and checking one side catches half the
    -- drift. Written by hand on purpose: inferring a service name from a
    -- description works for twenty entries and silently runs the wrong
    -- tool on the twenty-first.
    uni.runnable = {
        ["⇪X"]    = "mouseGrid.show",
        ["⇪K"]    = "url.cleanClipboard",
        ["⇪⇧K"]   = "url.undo",
        ["⇪R"]    = "rename.show",
        -- 🚨 6.114.0 — ["⇪⇧R"] = "rename.undo" WAS REMOVED FROM HERE, and
        -- it was not a dead entry, it was a WRONG one. ⇪⇧R belongs to the
        -- popup nudge reset (§0.4 maps ⌥⌘⌃R onto it), so the only cheat
        -- sheet row whose key cell says ⇪⇧R is "Reset nudge offset" — and
        -- srcTools attaches a service to a row BY ITS KEY CELL. Pressing ⏎
        -- on a row about where popups appear therefore ran a bulk rename
        -- undo, which MOVES FILES ON DISK. verifyTools could not see it:
        -- the service existed and the key matched a live row, so both
        -- halves of the join passed while joining the wrong two things.
        -- The undo has no key of its own by design — it is the first row
        -- of ⇪R whenever there is a batch to undo (see bulk_rename.lua).
        ["⇪M"]    = "menuBar.show",
        ["⇪Q"]    = "focus.toggle",
        ["⇪⇧Q"]   = "focus.report",
        ["⇪⇧H"]   = "health.report",
        ["⇪⇧A"]   = "universalActions.show",
        ["⇪⇧P"]   = "pomodoro.toggle",
        ["⇪⇧L"]   = "mouseGrid.locate",
        ["⇪⇧T"]   = "expander.show",
        ["⇪⇧U"]   = "winPin.pin",
        -- 6.105.0
        ["⇪O"]    = "ocr.show",
        ["⇪⇧O"]   = "ocr.edit",
        -- 📊 The rollup has NO KEY — every ⇪⇧ letter is spoken for. That
        -- makes this row the only way to open it by hand short of the
        -- Console, which is exactly what a tool list is for.
        ["📊"]    = "rollup.show",
        -- 💻 6.114.0 — THE NUMBER PAD ROW, RUNNABLE WITHOUT A NUMBER PAD.
        -- These six were already listed here — srcTools lists EVERY cheat
        -- sheet row — and ⏎ on one of them copied the key string instead
        -- of running it, because uni.runnable had no entry. So ⇪space
        -- showed a MacBook user a tool they could see, name, and not use.
        -- The actions were already published service names; this is the
        -- join that was missing, and it costs six lines and no key.
        --
        -- ⚠️ THE KEY CELLS MUST MATCH numpad_layer.lua EXACTLY. They read
        -- "⇪ pad1" with a space there until 6.114.0 and "⇪pad1" without
        -- one in quick_append — the same shortcut, twice, and a run map
        -- can only ever point at one spelling. verifyTools fails the join
        -- if either side drifts again.
        -- 6.119.0 — THE PUNCTUATION TIER. Four tools whose keys are ⇪. ⇪,
        -- ⇪; and ⇪⇧;, because every ⇪ letter and every ⇪⇧ letter was gone
        -- before they were written. A key nobody can guess is a key nobody
        -- presses, so the join matters more for these four than for any
        -- row above: ⇪⇧/ then "kill" is how they will actually be reached
        -- until the punctuation is in the fingers.
        ["⇪."]    = "menuSearch.show",
        ["⇪,"]    = "settings.show",
        ["⇪;"]    = "power.show",
        ["⇪⇧;"]   = "kill.show",
        -- 6.120.0 — the rest of the punctuation-and-digits tier. ⇪6 and
        -- ⇪7 are digits with NO mnemonic behind them, which is exactly
        -- why these two rows matter more than most: "network" and "mac"
        -- in this box is how they will be found.
        ["⇪6"]    = "net.show",
        ["⇪7"]    = "mac.toggle",
        ["⇪⇧'"]   = "tabs.show",
        ["⇪'"]    = "power.pause",
        ["⇪`"]    = "power.ghostty",
        ["⇪⇧`"]   = "power.reveal",
        ["⇪5"]    = "power.qr",
        ["⇪pad1"] = "notes.appendClipboard",
        ["⇪pad2"] = "notes.openPad",
        ["⇪pad3"] = "notes.pickTarget",
        ["⇪pad4"] = "windows.splitTwo",
        ["⇪pad*"] = "notes.typeIdeas",
        ["⇪pad-"] = "notes.typeLog",
    }

    uni.toolsVerified = false
    function uni.verifyTools(rows)
        if uni.toolsVerified then return end
        if not (_G.service and _G.service.has) then return end
        uni.toolsVerified = true
        local missing = {}
        for keys, svc in pairs(uni.runnable) do
            if not _G.service.has(svc) then
                missing[#missing + 1] = keys .. " → " .. svc .. " (no such service)"
            end
        end
        -- …and that the KEY still exists. ⇪pad+ sat in this map for three
        -- versions after the pomodoro moved to ⇪⇧P: the service resolved
        -- perfectly, the key matched nothing the cheat sheet draws, and the
        -- row was simply never runnable. Nothing said a word.
        local live = {}
        for _, r in ipairs(rows or {}) do
            if r.tag == "tool" then live[r.keys] = true end
        end
        if next(live) then
            for keys in pairs(uni.runnable) do
                if not live[keys] then
                    missing[#missing + 1] = keys .. " (no cheat sheet entry uses that key)"
                end
            end
        end
        if #missing > 0 then
            table.sort(missing)      -- pairs() has no order; the report needs one
            local msg = table.concat(missing, ", ")
            warn("run map entries that cannot fire: " .. msg)
            if _G.notices then
                _G.notices.record("unified", "stale entries in the tool run map", msg)
            end
        end
    end

    -- Rebuilt on every open rather than cached at boot, exactly as the
    -- standalone picker did: the cheat sheet is assembled from whichever
    -- modules actually LOADED, and a module can fail to load — a cached
    -- list would keep offering a tool that is not there this session.
    local function srcTools(add)
        local groups
        local ok = pcall(function()
            groups = _G.cheatSheet and _G.cheatSheet.groups and _G.cheatSheet.groups()
        end)
        if not (ok and groups) then
            warn("cheat sheet groups unavailable — no tools to list")
            return
        end
        for _, g in ipairs(groups) do
            -- Strip the leading emoji and any trailing parenthetical so the
            -- group reads as a plain name.
            local gname = tostring(g.title or "")
                :gsub("^[^%w]*", "")
                :gsub("%s*%b()%s*$", "")
            for _, e in ipairs(g.entries or {}) do
                local keys = tostring(e[1] or "")
                local desc = tostring(e[2] or "")
                if keys ~= "" or desc ~= "" then
                    add{ tag = "tool", icon = "🔧", src = gname ~= "" and gname or "Tools",
                         text = desc ~= "" and desc or keys,
                         sub  = keys,
                         full = keys,
                         kind = "tool",
                         keys = keys,
                         service = uni.runnable[keys] }
                end
            end
        end
    end

    -- ---- gather -------------------------------------------------------------
    uni.sources = {
        { tag = "clip",  icon = "📋", label = "Clipboard",    fn = srcClipboard },
        { tag = "cmd",   icon = "⌨️", label = "Commands",     fn = srcCommands  },
        { tag = "shots", icon = "📸", label = "Screenshots",  fn = srcShots     },
        { tag = "note",  icon = "🗒", label = "Notes",        fn = srcNotes     },
        { tag = "asana", icon = "✅", label = "Asana tasks",  fn = srcAsana     },
        { tag = "ocr",   icon = "🔤", label = "OCR",          fn = srcOCR       },
        { tag = "doc",   icon = "📄", label = "Documents",    fn = srcDocs      },
        { tag = "file",  icon = "📁", label = "File moves",   fn = srcFiles     },
        { tag = "pad",   icon = "🗒", label = "Capture Pad",  fn = srcPad       },
        { tag = "web",   icon = "🕘", label = "Chrome",       fn = srcWeb       },
        -- 🔧 LAST ON PURPOSE. Rows are gathered in this order and the page
        -- lists them in it, so the things you SAVED stay above the tools
        -- that are always there. @tool (or ⇪⇧/) puts them on top instead.
        { tag = "tool",  icon = "🔧", label = "Tools",        fn = srcTools     },
    }

    function uni.gather()
        uni.rows, uni.counts = {}, {}
        local function add(o)
            o.id = #uni.rows + 1
            uni.rows[o.id] = o
            uni.counts[o.tag] = (uni.counts[o.tag] or 0) + 1
        end
        for _, s in ipairs(uni.sources) do
            local ok, err = pcall(s.fn, add)
            if not ok then
                warn(s.label .. " source failed: " .. tostring(err))
                print("🔎 Unified Search: the " .. s.label
                      .. " source failed and was skipped — " .. tostring(err))
            end
        end
        -- Run map checked on the first gather, not at setup(): modules load
        -- in order and half the service registry does not exist yet while
        -- this one is being set up.
        pcall(uni.verifyTools, uni.rows)
        return uni.rows
    end

    -- ---- the page -----------------------------------------------------------
    -- Hand-built JSON string: see the header for why not hs.json.encode.
    local function jstr(s)
        s = tostring(s or "")
        s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
             :gsub("\r", "\\r"):gsub("\n", "\\n"):gsub("\t", "\\t")
             :gsub("</", "<\\/")
        s = s:gsub("%c", function(ch)
            return string.format("\\u%04x", ch:byte())
        end)
        return '"' .. s .. '"'
    end

    function uni.rowsJson()
        local parts = {}
        for _, r in ipairs(uni.rows) do
            local hay = string.lower((r.text or "") .. " " .. (r.sub or "")
                        .. " @" .. r.tag .. " " .. (r.src or ""))
            parts[#parts + 1] = "{\"id\":" .. r.id
                .. ",\"tag\":" .. jstr(r.tag)
                .. ",\"icon\":" .. jstr(r.icon)
                .. ",\"src\":" .. jstr(r.src)
                .. ",\"t\":" .. jstr(r.text)
                .. ",\"s\":" .. jstr(r.sub)
                .. ",\"h\":" .. jstr(hay)
                .. (r.img and (",\"img\":" .. jstr(r.img)) or "")
                .. (r.path and ",\"p\":1" or "")
                .. "}"
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    function uni.sourcesJson()
        local parts = {}
        for _, s in ipairs(uni.sources) do
            parts[#parts + 1] = "{\"tag\":" .. jstr(s.tag)
                .. ",\"icon\":" .. jstr(s.icon)
                .. ",\"label\":" .. jstr(s.label)
                .. ",\"n\":" .. tostring(uni.counts[s.tag] or 0) .. "}"
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    function uni.buildHtml(prefill)
        -- 🎨 6.90.0 — shared card colors (ui_style.lua), cascade-last.
        local themeCss = (_G.uiStyle and _G.uiStyle.cssOverride
                          and _G.uiStyle.cssOverride()) or ""
        return [[<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{margin:0;height:100%;overflow:hidden}
  body{background:#101018;color:#e9e9f2;
       font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
       -webkit-user-select:none;user-select:none}
  #bar{display:flex;justify-content:space-between;align-items:center;
       padding:10px 14px;background:#15151f;cursor:grab}
  #bar.dragging{cursor:grabbing;background:#1b1b26}
  #bar .ttl{font-weight:600;font-size:15px}
  #bar .hint{color:#8a8aa2;font-size:12px}
  #q{display:block;width:calc(100% - 28px);margin:10px 14px 6px;
     padding:12px 14px;font-size:19px;background:#1b1b28;color:#fff;
     border:1px solid #34344a;border-radius:8px;outline:none;
     -webkit-user-select:text;user-select:text}
  #count{padding:0 16px 6px;color:#8a8aa2;font-size:12px;min-height:15px}
  #list{position:absolute;top:124px;bottom:0;left:0;right:0;overflow-y:auto}
  .sec{padding:12px 16px 4px;color:#9db4ff;font-size:13px;font-weight:700;
       letter-spacing:.4px}
  .sec .tag{color:#8a8aa2;font-weight:400}
  .row{display:flex;gap:12px;align-items:center;padding:10px 16px;
       border-bottom:1px solid #1c1c29;cursor:pointer}
  .row.sel{background:#232338;box-shadow:inset 3px 0 0 #7a9bff}
  .mid{min-width:0;flex:1}
  .t{font-size:19px;line-height:1.3;max-height:2.6em;overflow:hidden;
     word-break:break-word}
  .s{font-size:14px;color:#9a9ab2;margin-top:3px}
  .src{font-weight:700;font-size:11px;letter-spacing:.5px;
       text-transform:uppercase;color:#9db4ff}
  img.th{height:]] .. tostring(uni.thumbH) .. [[px;max-width:160px;
     object-fit:cover;border-radius:6px;flex:none;background:#000}
  .pp{flex:none;color:#6a6a82;font-size:11px}
  .more{padding:12px 16px;color:#8a8aa2;font-size:13px}
  ]] .. themeCss .. [[
</style></head><body>
<div id="bar"><span class="ttl">🔎 Unified Search</span>
<span class="hint">drag here · ⏎ copy · ⌘⏎ path · Esc</span></div>
<input id="q" placeholder="Search everything — every word must match · a @tag pins one source">
<div id="count"></div>
<div id="list"></div>
<script>
var ROWS = ]] .. uni.rowsJson() .. [[;
var SRCS = ]] .. uni.sourcesJson() .. [[;
var PREFILL = ]] .. jstr(prefill or "") .. [[;
var CAP = ]] .. tostring(uni.pageCap) .. [[;
var GROUP = ]] .. tostring(uni.groupCap) .. [[;

function say(m){ try { webkit.messageHandlers.unifiedSearch.postMessage(m); }
                 catch (e) {} }
function el(id){ return document.getElementById(id); }
var q = el('q'), list = el('list'), count = el('count');
var byId = {};
for (var i = 0; i < ROWS.length; i++) byId[ROWS[i].id] = ROWS[i];

function esc(s){
  return String(s == null ? '' : s).replace(/&/g, '&amp;')
    .replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
function tokens(s){
  var out = [], parts = String(s || '').toLowerCase().split(/\s+/);
  for (var i = 0; i < parts.length; i++) if (parts[i]) out.push(parts[i]);
  return out;
}
function matches(row, toks){
  for (var i = 0; i < toks.length; i++)
    if (row.h.indexOf(toks[i]) === -1) return false;
  return true;
}

// visible = the pickable rows in display order (both views), so the
// arrow keys and Enter never care which view built the list.
var visible = [], sel = 0, total = 0;

function rowHtml(row, visIndex){
  var cls = 'row' + (visIndex === sel ? ' sel' : '');
  var h = '<div class="' + cls + '" data-id="' + row.id + '">';
  if (row.img) h += '<img class="th" src="' + row.img + '">';
  h += '<div class="mid"><div class="t">' + esc(row.t) + '</div>' +
       '<div class="s"><span class="src">' + row.icon + ' ' + esc(row.src) +
       '</span>' + (row.s ? ' · ' + esc(row.s) : '') + '</div></div>';
  if (row.p) h += '<span class="pp">⌘⏎ path</span>';
  return h + '</div>';
}

function rebuild(){
  var toks = tokens(q.value);
  visible = []; total = 0;
  var html = '';
  if (!toks.length) {
    // Nothing typed: the newest few of every source, under its name.
    for (var s = 0; s < SRCS.length; s++) {
      if (!SRCS[s].n) continue;
      html += '<div class="sec">' + SRCS[s].icon + ' ' +
              esc(SRCS[s].label) + ' — ' + SRCS[s].n +
              ' <span class="tag">@' + esc(SRCS[s].tag) + '</span></div>';
      var shown = 0;
      for (var i = 0; i < ROWS.length && shown < GROUP; i++) {
        if (ROWS[i].tag !== SRCS[s].tag) continue;
        html += rowHtml(ROWS[i], visible.length);
        visible.push(ROWS[i].id);
        shown++;
      }
      total += SRCS[s].n;
    }
  } else {
    for (var j = 0; j < ROWS.length; j++) {
      if (!matches(ROWS[j], toks)) continue;
      total++;
      if (visible.length < CAP) {
        html += rowHtml(ROWS[j], visible.length);
        visible.push(ROWS[j].id);
      }
    }
    if (total > visible.length)
      html += '<div class="more">…and ' + (total - visible.length) +
              ' more — keep typing to narrow</div>';
    if (!total)
      html += '<div class="more">Nothing matches "' + esc(q.value) +
              '" in any store — ⌫ widens it again</div>';
  }
  list.innerHTML = html;
  count.textContent = toks.length
    ? (total + ' match' + (total === 1 ? '' : 'es') + ' across every store')
    : (ROWS.length + ' items indexed — newest of each store below');
}

function render(){ rebuild(); var n = document.querySelector('.row.sel');
                   if (n && n.scrollIntoView) n.scrollIntoView({block:'nearest'}); }
function move(d){
  if (!visible.length) return;
  sel = Math.max(0, Math.min(visible.length - 1, sel + d));
  render();
}
function pick(id, wantPath){
  if (id == null) return;
  say({ a: wantPath ? 'path' : 'pick', id: id });
}

q.addEventListener('input', function(){ sel = 0; rebuild(); });
window.addEventListener('keydown', function(ev){
  if (ev.key === 'ArrowDown') { if (ev.preventDefault) ev.preventDefault(); move(1); }
  else if (ev.key === 'ArrowUp') { if (ev.preventDefault) ev.preventDefault(); move(-1); }
  else if (ev.key === 'Enter') {
    if (ev.preventDefault) ev.preventDefault();
    pick(visible[sel], ev.metaKey === true);
  }
  else if (ev.key === 'Escape') { say({ a: 'close' }); }
});
list.addEventListener('click', function(ev){
  var n = ev.target;
  while (n && n !== list && !(n.getAttribute && n.getAttribute('data-id')))
    n = n.parentNode;
  if (n && n !== list && n.getAttribute)
    pick(parseInt(n.getAttribute('data-id'), 10), ev.metaKey === true);
});
var bar = el('bar');
bar.addEventListener('mousedown', function(ev){
  if (ev.preventDefault) ev.preventDefault();
  bar.classList.add('dragging');
  say({ a: 'dragStart' });
});
window.addEventListener('mouseup', function(){
  bar.classList.remove('dragging');
});
q.value = PREFILL;
rebuild();
if (q.focus) q.focus();
</script></body></html>]]
    end

    -- 🔧 ⏎ on a tool row. Run it if we can; otherwise put the key where you
    -- can use it.
    --
    -- 🚨 THE PANEL GOES AWAY FIRST, AND THE RUN IS ONE RUN-LOOP TURN LATER.
    -- Most of these tools open a picker of their own, and this webview
    -- holds keyboard focus — running while it is still up means two panels
    -- racing for the keyboard, and the one that loses eats your first
    -- keystroke. Hiding first is not cosmetic.
    uni.runTimers = uni.runTimers or {}
    function uni.runTool(row)
        local keys = tostring(row.keys or "")
        local svc  = row.service
        uni.hide()

        local runnable = svc and _G.service and _G.service.has
                         and _G.service.has(svc)
        if not runnable then
            -- Being handed the key is the fallback, not a failure: plenty of
            -- entries are descriptions of behaviour, not commands.
            if keys ~= "" then
                pcall(function() hs.pasteboard.setContents(keys) end)
                hs.alert.show("🔧 " .. keys .. "  (copied — press it)", 1.5)
            end
            return false
        end

        -- HELD: an unreferenced hs.timer is collected, and a collected timer
        -- never fires — this one carries the whole action.
        local t = hs.timer.doAfter(0.05, function()
            -- has() BEFORE call(): _G.service.call does NOT throw on a
            -- missing provider, so a pcall around it succeeds whether the
            -- service ran or never existed at all.
            local ok = pcall(function() _G.service.call(svc) end)
            if ok then
                say("ran " .. svc .. " (" .. keys .. ")")
                return
            end
            -- A service that IS registered and throws is a real failure and
            -- is reported as one. Falling back to "here is the key" would
            -- look like the picker simply chose not to run it.
            warn("service '" .. svc .. "' failed when run from ⇪space")
            hs.alert.show("⚠️ " .. keys .. " failed — see the Console", 3)
            if _G.notices then
                _G.notices.record("unified", "tool failed when run", svc)
            end
        end)
        uni.runTimers[#uni.runTimers + 1] = t
        while #uni.runTimers > 8 do table.remove(uni.runTimers, 1) end
        return true
    end

    -- ---- the Lua side of the bridge ----------------------------------------
    local function handleMessage(body)
        if type(body) ~= "table" then return end
        local a = body.a
        if a == "close" then uni.hide() return end
        if a == "dragStart" then
            if _G.beginPanelDrag then _G.beginPanelDrag("unified search")
            else print("🔎 Unified Search: window_move is off — the header cannot drag") end
            return
        end
        local row = uni.rows and uni.rows[tonumber(body.id or 0)]
        if not row then return end
        -- 🔧 A TOOL ROW RUNS. Everything else on this panel copies; this one
        -- kind acts, which is why it is checked before the copy paths and
        -- not folded into them.
        if row.kind == "tool" then uni.runTool(row) return end
        if a == "path" and row.path then
            pcall(function() hs.pasteboard.setContents(row.path) end)
            hs.alert.show("📋 Path copied — " .. (row.path:match("[^/]+$") or row.path))
            uni.hide()
            return
        end
        if a == "pick" or a == "path" then
            if row.kind == "image" and row.path then
                -- ☁️ the one read that can stall on a cloud-evicted file —
                -- same OneDrive caveat as the ⇪⇧4 panel.
                local img, copied
                pcall(function() img = hs.image.imageFromPath(row.path) end)
                if img then
                    pcall(function()
                        copied = hs.pasteboard.writeObjects(img) and true
                    end)
                end
                hs.alert.show(copied and "📋 Screenshot on the clipboard"
                              or "⚠️ Could not read that screenshot", 3)
            else
                pcall(function()
                    hs.pasteboard.setContents(row.full or row.text or "")
                end)
                hs.alert.show("📋 Copied — " .. (row.src or "text"))
            end
            uni.hide()
        end
    end
    uni.handleMessage = handleMessage   -- exposed for the test suite

    -- ---- window -------------------------------------------------------------
    function uni.hide()
        if uni.webview then
            pcall(function() uni.webview:delete() end)
            uni.webview = nil
        end
    end

    -- 🖐 WHERE YOU LEFT IT, ACROSS RELOADS (6.107.0) ----------------------
    -- 6.93.0 taught this panel to reopen where you dragged it, for the
    -- session. Same gap the cheat sheet had in 6.106.0: uni is rebuilt on
    -- every reload, so the position went with it and the box came back in
    -- the middle. One hs.settings key fixes it.
    local POS_KEY = "unifiedSearch.pos"
    uni.rememberPos = true        -- ✏️ false = always centred, as before
    -- 🚨 HOW LONG AFTER YOU STOP MOVING IT THE POSITION IS WRITTEN. This
    -- is not a nicety. The drag layer calls move() from a repeating timer
    -- for the WHOLE drag (window_move's beginDrag), not once when you let
    -- go — so saving inside move() would write to the settings plist tens
    -- of times a second for as long as you hold the mouse down. The live
    -- uni.pos still updates on every tick, so the panel tracks the pointer
    -- exactly as before; only the WRITE waits for you to settle.
    uni.posSaveDelay = 0.4

    uni.pos = nil     -- where you dragged it; restored below at load

    -- Validated on the way in, the same rule win_pin's notes and the cheat
    -- sheet follow: hs.settings is a plist on disk and can hand back a
    -- string, a nil or a NaN. Two finite numbers or it is not a position.
    local function validPos(p)
        if type(p) ~= "table" then return nil end
        local x, y = tonumber(p.x), tonumber(p.y)
        if not x or not y then return nil end
        if x ~= x or y ~= y then return nil end          -- NaN
        if math.abs(x) > 100000 or math.abs(y) > 100000 then return nil end
        return { x = x, y = y }
    end

    function uni.loadPos()
        if not uni.rememberPos then return nil end
        local saved
        pcall(function() saved = hs.settings.get(POS_KEY) end)
        return validPos(saved)
    end

    -- HELD in uni.posTimer: an unreferenced hs.timer is collected, and a
    -- collected timer never fires — which here means the last thing you
    -- did with the panel is the one thing that never gets saved.
    function uni.savePos(p)
        if not uni.rememberPos then return false end
        local ok = validPos(p)
        if not ok then return false end
        if uni.posTimer then pcall(function() uni.posTimer:stop() end) end
        local okT, t = pcall(hs.timer.doAfter, uni.posSaveDelay, function()
            uni.posTimer = nil
            pcall(function() hs.settings.set(POS_KEY, ok) end)
        end)
        uni.posTimer = okT and t or nil
        -- No timer available (a harness, a stripped build): write it now
        -- rather than lose it. Debouncing is an optimisation, not a rule.
        if not uni.posTimer then
            pcall(function() hs.settings.set(POS_KEY, ok) end)
        end
        return true
    end

    -- The way out, when a remembered position is somewhere you cannot get
    -- at it. posStillOnScreen already refuses an unplugged monitor; this
    -- handles the rest.
    _G.unifiedCenter = function()
        uni.pos = nil
        if uni.posTimer then
            pcall(function() uni.posTimer:stop() end)
            uni.posTimer = nil
        end
        pcall(function() hs.settings.set(POS_KEY, nil) end)
        print("🔎 ⇪space re-centred, and the stored position forgotten")
        return true
    end

    function uni.posStillOnScreen(pos)
        local onIt = false
        pcall(function()
            for _, s in ipairs(hs.screen.allScreens() or {}) do
                local f = s:frame()
                if pos.x >= f.x - 40 and pos.x < f.x + f.w - 60
                   and pos.y >= f.y and pos.y < f.y + f.h - 60 then
                    onIt = true
                end
            end
        end)
        return onIt
    end

    function uni.show(prefill)
        if not uni.enabled then return end
        uni.hide()
        if not (hs.webview and hs.webview.usercontent) then
            hs.alert.show("🔎 Unified Search needs hs.webview, which this "
                          .. "Hammerspoon does not have")
            return false
        end
        uni.gather()

        local screen = core.resolveBaseScreen and core.resolveBaseScreen()
                       or (hs.screen and hs.screen.mainScreen())
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(uni.width,  sf.w - 60)
        local h = math.min(uni.height, sf.h - 80)
        local rect = { x = sf.x + (sf.w - w) / 2,
                       y = sf.y + (sf.h - h) / 2.6, w = w, h = h }
        -- 🖐 6.93.0 — A REMEMBERED POSITION WINS (the pomodoro's 6.67.0
        -- rule, finally taught to this panel too): drag it once and it
        -- reopens there — unless that screen was unplugged, in which case
        -- re-centering beats opening somewhere you can't see.
        if uni.pos and uni.posStillOnScreen(uni.pos) then
            rect.x, rect.y = uni.pos.x, uni.pos.y
        end

        local okUc, uc = pcall(hs.webview.usercontent.new, "unifiedSearch")
        if not (okUc and uc) then
            hs.alert.show("🔎 Unified Search could not build its page bridge")
            return false
        end
        uni.uc = uc            -- HELD: collect this and the bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then
                    print("🔎 Unified Search: message handler — " .. tostring(err))
                end
            end)
        end)

        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then
            uni.uc = nil
            hs.alert.show("🔎 Unified Search could not open its window")
            return false
        end
        uni.webview = view
        pcall(function() view:windowTitle("Unified Search") end)
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:closeOnEscape(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        -- The pad's proven non-activating plumbing, borrowed when present:
        -- keyboard focus without yanking Hammerspoon in front of your app.
        if _G.capturePad and _G.capturePad.applyNonActivating then
            pcall(_G.capturePad.applyNonActivating, view)
        end
        pcall(function() view:html(uni.buildHtml(prefill or "")) end)
        pcall(function() view:show() end)
        pcall(function() view:bringToFront(true) end)

        local n = 0
        for _, c in pairs(uni.counts) do n = n + (c > 0 and 1 or 0) end
        say(#uni.rows .. " rows from " .. n .. " store(s)")
        return true
    end

    function uni.toggle(prefill)
        if uni.webview then uni.hide() else uni.show(prefill) end
    end

    -- ---- wiring -------------------------------------------------------------
    if uni.enabled then
        core.hyperAddShortcut({}, uni.key, function() uni.toggle() end,
                              "unified search")
        core.hyperAddShortcut({ "shift" }, uni.key,
                              function() uni.toggle("@shots ") end,
                              "unified search — screenshots")
        -- ⇪⇧/ KEPT AS A DOOR, NOT A SECOND BOX (6.104.0). The standalone
        -- Tool Picker is gone; the key it taught your fingers still works
        -- and lands where its content moved to. Same shape as ⇪⇧space.
        core.hyperAddShortcut({ "shift" }, uni.toolKey,
                              function() uni.toggle("@tool ") end,
                              "unified search — tools")
    end

    -- Draggable like everything else — ⌘-drag anywhere on it, and the
    -- header's bare drag arrives through the dragStart message above.
    -- move() is also where the remembered position is written down, so
    -- BOTH grips remember (6.93.0).
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "unified search",
        frame = function() return uni.webview and uni.webview:frame() end,
        move  = function(x, y)
            local f = uni.webview and uni.webview:frame()
            if f then uni.webview:frame({ x = x, y = y, w = f.w, h = f.h }) end
            uni.pos = { x = x, y = y }
            -- Debounced — see uni.posSaveDelay. This runs on every tick of
            -- the drag timer, not once when you drop.
            uni.savePos(uni.pos)
        end,
    })

    -- Restored at load, not at first show: uni.show() reads uni.pos
    -- directly and a lazy restore would have to be threaded through every
    -- caller of it.
    uni.pos = uni.loadPos()

    -- ⎋ 6.93.0 — in the escape router, so the cheat sheet closes AFTER
    -- this panel instead of vanishing underneath it.
    if _G.claimEscape then
        _G.claimEscape("unified", nil,
            function() return uni.webview ~= nil end,
            function() uni.hide() end)
    end

    core.provide("unified.show", function(prefill) return uni.show(prefill) end)

    _G.unifiedSearch = uni
    M.uni    = uni
    M.config = uni
end

return M
