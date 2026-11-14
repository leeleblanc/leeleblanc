-- =====================================================================
-- MODULE: UNIFIED SEARCH (⇪D) — one typed search over EVERY store
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
--   ✅ asana tasks          (the task creator's 30-day history; its pipe
--                            picker lost ⇪⇧S to the snippets in 6.161.0)
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
-- 👁 6.204.0 — THE POINTER MOVES THE HIGHLIGHT AND A PANE SHOWS THE FULL
-- ENTRY. LL: "I can only use the arrow keys. There also is no side window
-- that shows the full entry." A DOM mousemove over a row selects it (on
-- movement only, like the chooser's tracking area); the pane on the right
-- asks Lua for that one row's full text and Lua answers through
-- evaluateJavaScript — the full text never rides into the page for every
-- row. `uni.pane = false` is the list alone, as before.
--
-- 🔎 EVERY WORD MUST MATCH ("aug receipt" finds August receipts), and a
-- @tag word pins the source: @clip @cmd @shots @images @note @asana @ocr @doc
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
        title = "🔎 UNIFIED SEARCH (⇪D — everything, one search)",
        entries = {
            { "⇪D",      "Search EVERY store: clipboard · commands · screenshots · notes · Asana · OCR · docs · file moves · pad · Chrome · every TOOL" },
            { "⇪⇧space", "Same panel opened as the BIG-thumbnail screenshot browser (@shots)" },
            { "⇪⇧/",     "Same panel opened on the TOOLS (@tool) — every shortcut, searchable" },
            { "type",    "Every word must match · a @tag word pins one source — each section header shows its tag" },
            { "@",       "Type @ ON ITS OWN and every source is listed — its tag, what it holds and how many. ⏎ on one puts that @tag in the box (6.298.0)" },
            { "@images", "🖼 Find a PICTURE by the words inside it — every image the OCR log has read, thumbnail and all. ⏎ copies the image, ⌥⏎ opens it, ⌘⏎ copies its path" },
            { "⏎",       "COPY the row — text its full text, a screenshot the image, a Chrome page its URL (⇪Y reopens)" },
            { "⏎ on 🔧", "RUNS the tool instead — the one row kind that acts (else copies its key)" },
            { "⌘⏎",      "Copy the file PATH instead (rows that have one)" },
            { "↑↓ · hover", "Move the highlight — the pointer moves it too, as a chooser's does · click picks (19px rows, 84px thumbnails)" },
            { "pane",    "The right-hand pane shows the FULL entry of the highlighted row (first 12,000 characters; ⏎ copies all of it) — settings = { unified_search = { pane = false } } hides it" },
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
    -- 6.196.0 — LL: "swap hyper+space as app launcher, hyper+d Unified
    -- search." ⇪space is the key a hand reaches for without deciding, so
    -- it goes to the launcher (the most-pressed thing here) and search
    -- moves to ⇪D, which it takes over from the launcher.
    --
    -- 🚨 THE SHIFTED HALF DOES NOT FOLLOW IT, and that is deliberate:
    -- ⇪⇧D IS THE DIAGNOSTIC REPORT. It is unclaimed on purpose so it
    -- forwards as ⌘⇧⌃⌥D to the plain hotkey in core/diagnostics.lua —
    -- every boot line in this config tells LL to press it. Binding the
    -- screenshots view there would have taken it silently, because a
    -- forwarded chord is not a bind and the collision auditor cannot see
    -- one being stolen. So the screenshots view keeps ⇪⇧space, which the
    -- launcher's arrival leaves free. Two keys for one box is the smaller
    -- price.
    uni.key      = "d"        -- ⇪D  search everything
    uni.shotsKey = "space"    -- ⇪⇧space  the same box, pinned to @shots
    uni.toolKey = "/"        -- ⇪⇧/ opens the same box pinned to @tool
    uni.width, uni.height = 840, 700
    uni.thumbH  = 84         -- px — a chooser row renders ≈40; this is >2×
    uni.preview = 240        -- characters of each row shown / searched
    uni.pageCap = 60         -- rows the page lists at once ("+N more" after)
    uni.groupCap = 8         -- rows per source in the nothing-typed view
    -- 📸 6.431.0 — `shots` was 30 and every other source is 120–400.
    -- LL: "Why do I only have 33 screenshots when I use @shots?" Because
    -- 30 of them were listed; the other three rows were incidental matches
    -- from other stores. He has 488 captures.
    -- 🔑 AND 30 WAS BOUNDING THE WRONG THING. The comment it was written
    -- under says so: "capped at maxPer.shots" appears under *thumbnails*,
    -- because every shots row asks uni.thumbFor() and a thumbnail is a
    -- full PNG decode on the main thread (6.187.0 priced that, and a
    -- OneDrive-evicted file decodes by downloading it). So the number was
    -- a DECODE budget wearing a row cap's clothes — and the source right
    -- next door, @images, already keeps those two apart: it lists
    -- maxPer.images rows and decodes only uni.thumbMax of them. srcShots
    -- does the same now, so the rows are a list and the budget is a
    -- budget. GENERAL: when one number bounds two costs, the cheaper one
    -- is the one being starved.
    uni.maxPer  = { clip = 400, cmd = 400, shots = 300, note = 120,
                    asana = 200, ocr = 200, doc = 200, file = 200, pad = 60,
                    web = 300, scratch = 200, vault = 300, images = 150,
                    logs = 300, draft = 300 }
    -- 6.187.0 — how many @images rows get a real picture. A thumbnail is a
    -- full decode on the main thread, so this is a budget, not a preference.
    uni.thumbMax = 24
    -- 6.187.0 — how much of a row's FULL text joins the haystack. Until now
    -- only the truncated preview was searchable, so a word in the middle of
    -- an OCR'd page could not be found — which is most of the point of
    -- having OCR'd the page. Bounded because the haystack ships to the page.
    uni.hayFull = 1500
    -- 👁 6.204.0 — THE MOUSE, AND THE DETAIL PANE. LL, bug (3) of the
    -- three he reported against 6.201.0: "I can only use the arrow keys.
    -- There also is no side window that shows the full entry." The
    -- chooser this panel replaced for ⇪V/⇪O in 6.190.0 had both — macOS
    -- hover-selects a chooser row by itself (6.202.0), and the preview
    -- pane rode beside it. This page listened for clicks and nothing
    -- else, so the pointer was dead until it pressed, and the only view
    -- of a row was the 240-character line the list shows.
    --   uni.pane      — false = the list alone, exactly as before.
    --   uni.paneW     — px of the window given to the pane (the window
    --                   grows by it; the chooser's pane is 420 pt).
    --   uni.detailMax — characters of the full entry laid out; the
    --                   chooser pane's own number. ⏎ still copies ALL of it.
    -- The full text stays on the Lua side of the bridge (it always has):
    -- the page ASKS for one row's detail when the highlight lands on it
    -- and Lua answers through evaluateJavaScript — so a row costs nothing
    -- until it is looked at, and the page never grows by a store's size.
    --   settings = { unified_search = { pane = false } }   is the rollback.
    uni.pane      = true
    uni.paneW     = 400
    uni.detailMax = 12000
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("unified", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("unified", m) end end

    -- ---- tiny shared helpers ----------------------------------------------
    local function oneLine(s) return (tostring(s or ""):gsub("%s+", " ")) end

    -- a stat, never a read: an mtime does not fetch a cloud-evicted file
    local function mtimeOf(path)
        local mt
        pcall(function() mt = hs.fs.attributes(path, "modification") end)
        return tonumber(mt) or 0
    end

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
    uni.thumbCount = 0
    uni.thumbCacheMax = 200
    function uni.thumbFor(entry)
        local c = uni.thumbCache[entry.path]
        if c and c.mtime == entry.mtime then return c.uri end
        -- 6.187.0 — the cache had no ceiling. One entry is a whole encoded
        -- PNG as a string, and @images feeds it images from anywhere on
        -- disk rather than one folder, so an unbounded cache is a session
        -- that grows all day. Past the cap it is emptied rather than
        -- pruned by age: the next gather re-decodes what is still on
        -- screen, which is bounded work, and nothing has to remember an
        -- order that would itself need keeping.
        if uni.thumbCount >= uni.thumbCacheMax then
            uni.thumbCache, uni.thumbCount = {}, 0
        end
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
        if uri then
            uni.thumbCache[entry.path] = { mtime = entry.mtime, uri = uri }
            uni.thumbCount = uni.thumbCount + 1
        end
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

    -- PURE: does this row hold more than the preview shows? The pane
    -- calls itself a preview only when the row says it does (6.204.0).
    local function dk_more(r)
        return #tostring(r.text or "") > uni.preview
    end

    -- 💾 6.404.0 — @draft. LL, escalated by name twice: the text a web
    -- form loses. The rows come from draft_keeper through ONE reader
    -- (6.231.0) — a second copy of that CSV parsing here is the OCR
    -- log's defect exactly, two readers over one file that drift.
    --
    -- ⏎ on one of these COPIES it, which is what every source but
    -- @clip does already (6.402.0) and is his own scope: this config
    -- never types a draft back into somebody else's page.
    local function srcDraft(add)
        if not (_G.service and _G.service.has
                and _G.service.has("draft.rows")) then return end
        local rows, err = _G.service.call("draft.rows", { max = uni.maxPer.draft })
        -- 🔎 THREE STATES, AND THE MIDDLE ONE IS THE POINT (6.196.1). A
        -- file that could not be READ must not come back as an empty
        -- store: "no draft was ever kept" is the reassuring sentence and
        -- it would be a lie on exactly the day the disk is full.
        if type(rows) ~= "table" then
            uni.draftWhy = tostring(err or "the draft file could not be read")
            add{ tag = "draft", icon = "💾", src = "Drafts",
                 text = "⚠️ the kept drafts could not be read — " .. uni.draftWhy,
                 sub  = "this is NOT 'nothing was kept'",
                 full = "The draft keeper's file could not be read, so ⇪D cannot"
                        .. " say what it has kept. " .. uni.draftWhy
                        .. "\n\n_G.draftKeeperReport() names the file." }
            return
        end
        uni.draftWhy = nil
        for i = 1, #rows do
            local r = rows[i]
            local where = tostring(r.app or "?")
            if r.title and r.title ~= "" then
                where = where .. " — " .. tostring(r.title)
            end
            add{ tag = "draft", icon = "💾", src = "Drafts",
                 text = oneLine(tostring(r.text)):sub(1, uni.preview),
                 sub  = tostring(r.date) .. " " .. tostring(r.clock)
                        .. " · " .. where .. " · " .. tostring(r.chars or 0)
                        .. " chars" .. (r.cut and " (cut)" or ""),
                 -- the WHOLE draft in the pane, and ⏎ copies the whole of it
                 full = tostring(r.text),
                 m    = (dk_more(r) and true or nil) }
        end
    end

    -- 📓 6.383.0 — @logs. LL: "I don't have at @ search for Logs."
    -- He is right, and 6.279.0 named this exact gap when it built the
    -- ledger — "the log is not yet a ⇪D source. One uni.sources row, its
    -- own release" — and then never built it. Everything that has
    -- degraded on this Mac, searchable from the panel he already uses.
    --
    -- 🔁 ONE PARSER. The rows come from notices.logRows, the same reader
    -- _G.todayReport() asks; a second copy of that CSV parsing here is
    -- how two readers over one file come to disagree about a column.
    local function srcLogs(add)
        local n = _G.notices
        if not (n and type(n.logRows) == "function") then return end
        local ok, rows, err = pcall(n.logRows, { max = uni.maxPer.logs })
        if not ok then return end
        -- 🔎 THREE STATES, AND THE MIDDLE ONE IS THE POINT (6.196.1). A
        -- log that could not be READ must not come back as an empty
        -- store: "nothing has failed" is the most reassuring sentence
        -- this config can print and would be a lie on exactly the day
        -- the disk is full. It becomes a ROW he can see instead.
        if not rows then
            uni.logsWhy = tostring(err or "the log could not be read")
            add{ tag = "logs", icon = "📓", src = "Tool failures",
                 text = "⚠️ the failure log could not be read — " .. uni.logsWhy,
                 sub  = "this is NOT 'nothing failed'",
                 full = "The degrade log could not be read, so ⇪D cannot say"
                        .. " whether anything has failed. " .. uni.logsWhy }
            return
        end
        uni.logsWhy = nil
        for i = 1, #rows do
            local r = rows[i]
            add{ tag = "logs", icon = "📓", src = "Tool failures",
                 text = oneLine(tostring(r.tool) .. " — " .. tostring(r.why))
                            :sub(1, uni.preview),
                 sub  = tostring(r.date) .. " " .. tostring(r.clock),
                 full = tostring(r.tool) .. " failed at " .. tostring(r.date)
                        .. " " .. tostring(r.clock) .. "\n\n" .. tostring(r.why) }
        end
    end

    local function srcShots(add)
        local shots = _G.screenshots
        if not (shots and type(shots.list) == "function") then return end
        local ok, l = pcall(shots.list)
        if not (ok and type(l) == "table") then return end
        -- DECODES, not rows (6.431.0, srcImages' rule since 6.187.0): the
        -- newest `uni.thumbMax` rows get a picture and the rest are rows
        -- without one. A row with no thumbnail still carries its name, its
        -- date, its size and its path, which is everything ⏎ and ⌘⏎ use.
        local drawn = 0
        for i = 1, math.min(#l, uni.maxPer.shots) do
            local e = l[i]
            local thumb
            if drawn < uni.thumbMax then
                thumb = uni.thumbFor(e)
                -- Counted whether or not a URI came back: the COST was
                -- paid either way, and that is what the budget is about.
                drawn = drawn + 1
            end
            add{ tag = "shots", icon = "📸", src = "Screenshot",
                 text = e.name or "",
                 sub  = os.date("%b %d %H:%M", e.mtime or 0)
                        .. " · " .. prettySize(e.size),
                 full = e.name or "", path = e.path,
                 kind = "image", img = thumb }
        end
        uni.shotThumbs = drawn
        uni.shotRows   = math.min(#l, uni.maxPer.shots)
        uni.shotsOnDisk = #l
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

    -- 6.187.0 — ONE ROW OF THE OCR LOG. The log gained a third column in
    -- 6.187.0 — the image the words were read from — and the old
    -- two-column rows are still on disk and still valid. Both shapes parse
    -- here.
    -- 🔗 This is the TWIN of ocr.parseRow in modules/ocr_engine.lua. Two
    -- modules must read this file (⇪space cannot depend on the OCR engine
    -- being loaded), so there are two readers by necessity — but each now
    -- goes through the quote-aware splitter its own file already had,
    -- rather than a pattern of its own, and the gate runs BOTH over the
    -- same fixtures and fails if they ever disagree. The greedy `(.*)`
    -- this replaced would have swallowed the new column into the text and
    -- shown LL a path glued to the end of every entry.
    function uni.parseOcrRow(line)
        line = tostring(line or "")
        if line == "" then return nil end
        local f = csvSplit(line)
        local ts = f and f[1]
        if not ts or ts == "" then return nil end
        local text = (f[2] or ""):gsub('\\n', '\n')
        local path = f[3]
        if path == "" then path = nil end
        return ts, text, path
    end

    -- the log, oldest first, as the file has it. A tail read of a file
    -- that is APPENDED to can begin mid-row, so the first line is dropped
    -- unless the read started at the beginning of the file.
    local function ocrEntries()
        local file = (core.logsDir or "") .. "/image_text-"
                     .. tostring(core.hostTag) .. ".csv"
        local content = tailRead(file, 256 * 1024)
        if not content then return {} end
        local out = {}
        for line in content:gmatch("[^\r\n]+") do
            local when, text, path = uni.parseOcrRow(line)
            if when and text then out[#out + 1] = { when = when, text = text, path = path } end
        end
        return out
    end

    local function srcOCR(add)
        local collected = ocrEntries()
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

    -- 🖼 6.187.0 — @images. LL: "@images / @shots in ⇪space". @shots has
    -- always listed the screenshots FOLDER by file name, and ⇪O has always
    -- searched OCR'd words with no way back to the picture. This is the
    -- half that was missing: every image we have READ, found by the words
    -- inside it, with the picture beside the row.
    --
    -- It is not a new scan of anything. The words and now the path are
    -- already in the OCR log, so this costs one tail read of a file
    -- ⇪space already reads — and NOT a second one, because @ocr and
    -- @images share `ocrEntries`.
    --
    -- ☁️ THE ONE COST IT MUST NOT PAY: a thumbnail is a full decode on the
    -- main thread, and a OneDrive-evicted file decodes by downloading it
    -- (the 6.152.x / 6.170.3 beachball class). So only the newest
    -- `uni.thumbMax` rows are ever decoded; the rest are rows without a
    -- picture, which is a fair trade and is said in the report. An image
    -- that has been deleted or moved keeps its words and loses its
    -- thumbnail — the row still finds the text, and ⏎ says the file is gone.
    local function srcImages(add)
        local collected = ocrEntries()
        local seen, rows = {}, {}
        for i = #collected, 1, -1 do              -- newest first
            local e = collected[i]
            if e.path and e.path ~= "" and not seen[e.path] then
                seen[e.path] = true               -- one row per image, its newest reading
                rows[#rows + 1] = e
                if #rows >= uni.maxPer.images then break end
            end
        end
        local drawn = 0        -- DECODES, not rows: an image that has moved
                               -- costs nothing, so it must not spend the budget
        for i = 1, #rows do
            local e = rows[i]
            local name = e.path:match("[^/]+$") or e.path
            local words = oneLine(e.text)
            local exists = false
            pcall(function() exists = hs.fs.attributes(e.path, "mode") ~= nil end)
            local thumb
            if exists and drawn < uni.thumbMax then
                thumb = uni.thumbFor({ path = e.path, mtime = mtimeOf(e.path) })
                drawn = drawn + 1
            end
            add{ tag = "images", icon = "🖼", src = "Images",
                 text = name,
                 sub  = e.when .. " · " .. words:sub(1, uni.preview)
                        .. (exists and "" or " · ⚠️ the file has moved"),
                 full = e.text, path = e.path, kind = "image", img = thumb }
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

    -- 📝 6.164.0 — the ⇪1 scratch pad: open tabs first, then closed ones.
    local function srcScratch(add)
        local sp = _G.scratchPad
        if not (sp and type(sp.tabs) == "table") then return end
        local added = 0
        local function one(t, label, when)
            if type(t) ~= "table" or type(t.text) ~= "string" or t.text:match("^%s*$") then return end
            add{ tag = "scratch", icon = "📝", src = "Hamsidian tabs",
                 text = oneLine(t.text):sub(1, uni.preview),
                 sub  = label .. " · " .. os.date("%b %d %H:%M", when or 0),
                 full = t.text }
            added = added + 1
        end
        for _, t in ipairs(sp.tabs) do
            if added >= uni.maxPer.scratch then return end
            one(t, "open tab", t.updatedAt)
        end
        for _, h in ipairs(type(sp.history) == "table" and sp.history or {}) do
            if added >= uni.maxPer.scratch then return end
            one(h, "closed", h.closedAt)
        end
    end

    -- 🕸 6.172.0 — the ⇪3 vault: note NAMES (the folder is the index;
    -- contents are never read here — OneDrive placeholders block on read).
    local function srcVault(add)
        local v = _G.vault
        if not (v and type(v.notes) == "table") then return end
        local added = 0
        for _, n in ipairs(v.notes) do
            if added >= uni.maxPer.vault then return end
            add{ tag = "vault", icon = "🕸", src = "Hamsidian", text = n.name,
                 sub = n.rel, full = n.name, vaultNote = n.name }
            added = added + 1
        end
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
        ["⇪⇧S"]   = "expander.show",   -- 6.161.0: was ⇪⇧T
        -- 6.105.0
        ["⇪O"]    = "ocr.show",
        ["⇪⇧O"]   = "ocr.edit",
        -- 📊 The rollup has NO KEY — every ⇪⇧ letter was spoken for when it
        -- arrived (⇪⇧T came free in 6.161.0 and was spent again in 6.194.0,
        -- then by the ⏱ timer in 6.379.0 — ask the registry, not this
        -- comment, which read "stays free on purpose" for 185 releases
        -- after it stopped being true). That
        -- makes this row the only way to open it by hand short of the
        -- Console, which is exactly what a tool list is for.
        ["📊"]    = "rollup.show",
        -- 🗂 6.125.0 — AND NOW THE EDITOR PICKER, for the same reason and
        -- one more. It had ⇪⇧Z, LL asked for the key back, and there was
        -- no letter left to move it to. But the picker is not the rollup:
        -- its main way in is a DOUBLE TAP OF ⌃, an hs.eventtap, and taps
        -- die when macOS revokes Accessibility. Its own header forbids the
        -- tap being the only way in. So this row is not a convenience
        -- here, it is the second route the picker is required to have —
        -- and ⇪ is Caps Lock through hs.hotkey, which fails for entirely
        -- different reasons than an event tap does.
        ["🗂"]    = "editors.show",
        -- 📎 6.146.0 — DEFAULT APPS, keyless like the rollup: every ⇪
        -- letter is long gone, and a tool used a few times a year has no
        -- claim on one anyway. This row IS its front door.
        ["📎"]    = "defaultApps.show",
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
        ["⇪⇧6"]   = "netwatch.show",
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

    -- 📋 6.427.0 — EVERY REPORT THIS CONFIG PUBLISHES, WITH WHAT IT
    -- ANSWERS. LL: "I'd like an @report so I can pick and run different
    -- items like _G.draftKeeperReport() and each of those reports should
    -- give me a description of what it does."
    --
    -- 🔎 THERE ARE EIGHTY-ODD OF THEM and they have never been listed
    -- anywhere. Nearly every rule in this project ends in "paste the
    -- report", and the only way to learn a report's NAME was to be told
    -- it in a message — which is 6.317.0 for the Nth time: the
    -- instruments were not the gap, the DOOR was.
    --
    -- 🚨 THE LIST IS READ FROM `_G`, THE SENTENCES ARE WRITTEN (6.276.0).
    -- A hand-kept list of what exists is the defect this project has
    -- deleted twice — it was wrong about ⇪⇧pad. for five releases. So the
    -- rows come from the live globals, and this table only says what each
    -- one is FOR. Both directions of drift are LOUD rather than silent:
    --   · a report that exists with no sentence here → a ⚠️ row, so a new
    --     report added next year is visible the day it ships;
    --   · a sentence here naming a report that does not exist → a ⚠️ row,
    --     so a rename or a module that failed to load is visible too.
    -- That is `watchFor`'s shape (6.317.0): forgetting is loud in both
    -- directions, which is the only thing that makes a hand-kept half
    -- safe.
    uni.reportDocs = {
        -- the keyboard, and the three things that can take it away
        hyperKeyReport      = "⇪ — how each hold ended: a keyUp relay, a panel handover, or a real latch",
        stormReport         = "⇪ storms — every time Caps Lock latched, and what the probe measured at the moment it did",
        secureInputReport   = "whether anything has locked the keyboard — the state that kills every shortcut and snippet at once",
        keyTrailReport      = "the last 24 ⇪ shortcuts, with how long each took and whether it threw",
        chordAudit          = "⇪ keys whose forward lands on a real chord — an unclaimed key firing something else",
        freeKeys            = "which ⇪ keys are still unclaimed — asked of the live registry, never a list",
        doubleTapReport     = "⌘⌘ and ⌥⌥ — the double-tap gestures and whether their watcher is running",
        -- is it saving?
        saved               = "every store: its size, rows, last write and growth since boot",
        stores              = "where your stores are and when each last saved — the boot block, again",
        writeLedgerReport   = "the same ledger, with the probe write that proves the folder still takes one",
        todayReport         = "what failed today, read back off disk so it survives a reload — the 4 PM check",
        degradeReport       = "every tool that has degraded this session, and any sticky NOT SAVED warning",
        noticesReport       = "the notices ledger — what was alerted, held through Focus, or recorded",
        errorsReport        = "errors recorded since this config loaded",
        -- did the release land, and is the Mac well?
        installCheck        = "are all of this release's files here, at the size it shipped — and any stray",
        selfTest            = "do the big tools answer — one row per tool, the block printed after every boot",
        bootReport          = "the full portability block: storage, data, backup, Asana, hotkeys, modules",
        bootCostReport      = "what each module cost at boot, ranked, against the median of the last ten",
        capabilityReport    = "what this Mac can do — OneDrive, Accessibility, Secure Input, OCR, the package manager",
        groundReport        = "what this Mac answers about six platform surfaces, and the release each answer decides",
        healthReport        = "⇪⇧H — disk, memory, uptime and the rest",
        lagReport           = "main-thread lag — how often this config was slow to answer",
        stallGuardReport    = "the outside watchdog: its heartbeat, its log, and any relaunch it has made",
        -- windows and panels that can refuse to open
        webviewShowReport   = "webview panels macOS refused to put on screen — Hamsidian, the editor, the players",
        canvasShowReport    = "canvas panels macOS refused, and which were handed back for a retry",
        popupShowReport     = "pickers macOS refused to open, and which one",
        screenReport        = "which monitor placed the last panel, and which rule chose it",
        dragReport          = "how the last panel drag ended — the release, a late button-up, or the watchdog",
        escapeReport        = "who claims Esc, in order, and who refused to let go of it",
        cheatSheetReport    = "the ⇪/ cards — how many, any drawn empty, and any module that registered none",
        alertReport         = "alerts macOS refused to draw, and what the last refused one said",
        windowMoveReport    = "⌘-drag — the panels it can move and the last drag it handled",
        switcherReport      = "⌥Tab — what it listed, what it remembered, and how long the sweep took",
        -- what you typed, copied, read or lost
        draftKeeperReport   = "the drafts a web form would have lost — what was kept, refused, and what it costs",
        draftCheck          = "what the draft keeper can see RIGHT NOW — press ⇪⇧] with the caret in the field",
        clipboardPollReport = "the clipboard watcher — changes seen, and any rest the thrash breaker took",
        clipboardWriteReport= "every clipboard write this config made, and every one macOS refused",
        autocorrectReport   = "the correction rules, what ⇪Z has taught, and the dates written out in full",
        snippetsReport      = "the snippet library, the tap, and your recent picks",
        snippetsList        = "the snippets themselves — a summary first, then rows (true for all of them)",
        ocrReport           = "the OCR engine — what it has read and from where",
        screenshotsReport   = "⇪4 and ⇪5 — the routes, the OCR naming, the clipboard, the folder",
        screenshotEditorReport = "⇪⇧1 — the window, its size rule, the captures and the closes",
        -- the notes, the tabs, the search
        vaultReport         = "Hamsidian notes — the index, the page, the bin, the board, the saves",
        vaultTrash          = "the notes in the bin, newest first, with when each was deleted",
        scratchPadReport    = "Hamsidian tabs — what is open, what was sent, what was written as a note",
        unifiedSearchReport = "⇪D itself — every store it gathered, its counts, and any that failed",
        fileIndexReport     = "the file index ⇪D searches — how many paths and when it was built",
        masterLogReport     = "the combined searchable log and its database",
        recentDocsReport    = "⇪I — the documents, the learned file types, and what was held back",
        docMemoryReport     = "which document each app has open, asked through Accessibility",
        activityDocsReport  = "the documents your app-time was recorded against",
        fileTrackerReport   = "the file-move watcher — the folders watched, the wake-ups and what they bought",
        -- the tools
        musicReport         = "the Jug Player — the queue, the history, ⏯, the drop and the window",
        mugReport           = "the Mug Player — the deck, the way in, the codecs and full screen",
        mouseGridReport     = "⇪X — the cells, the split, the arrows and the rings",
        mouseFollowsReport  = "⇪1 — every pointer jump and, as usefully, every one it skipped and why",
        pomodoroReport      = "⇪⇧P — the phase, the count today, the tone and the dock",
        timerReport         = "⇪⇧T — what is running, whether the card is hidden, and whose Esc it is",
        focusReport         = "⇪Q focus mode — what it engages and what it mutes",
        focusDoorReport     = "the focus borrow-and-return door — who took the keyboard and whether it came back",
        rightClickReport    = "⇪⇧F — whether it aimed at the selection or at the pointer",
        universalActionsReport = "⇪⇧A — the selection it acted on and whether it re-read it in time",
        powerReport         = "⇪; — the power tools, and the borrowed-clipboard guard",
        killReport          = "⇪⇧K — what it has quit",
        renameReport        = "⇪R bulk rename — the last plan and what can be undone",
        caseReport          = "⇪⇧C — the text case conversions",
        defineReport        = "the dictionary lookups",
        urlReport           = "the URL cleaner — what it stripped and what can be undone",
        menuSearchReport    = "⇪. — the front app's menus and how they were read",
        menuBarReport       = "the menu-bar inventory and what the scan cost",
        appLauncherReport   = "⇪space — the app list and how it was built",
        appRemoveReport     = "⇪⇧[ — what App Removal last listed, what it judged risky, and what it moved",
        tabReport           = "⇪⇧B — the browser tabs it found",
        editorPickerReport  = "⌃⌃ — the editors it offers and how they were learned",
        defaultAppsReport   = "the 📎 default-apps tool",
        settingsReport      = "the settings panes",
        macReport           = "⇪7 — this Mac's own details",
        netReport           = "⇪6 — the network tools",
        netWatchReport      = "⇪⇧6 — what is talking to the network",
        bluetoothReport     = "⇪⇧7 — the paired devices and which engine answered",
        battReport          = "the battery saver — what it has done and what it never touches",
        docKeywordsReport   = "the document keyword tagging",
        panicReport         = "⌃⌥⌘⇧Esc — what the panic chord released the last time it was pressed",
        -- Asana and the backups
        asanaSubmitReport   = "whether Asana ACCEPTED each task, not just whether it was sent",
        asanaDashboardReport= "⇪L · ⇪C · ⇪B — the dashboard's keys and its fetches",
        asanaRefreshReport  = "the five-minute Asana reload and which menu path it used",
        asanaTeams          = "what Asana answered about your teams, beside the names this config asks for",
        oneDriveCheck       = "which files OneDrive has taken the bytes of back off this Mac",
        backupReport        = "the nightly rebuild kit, the half-hourly store mirror and the catch-up run",
        crashReport         = "the newest Hammerspoon crash report on this Mac, and its full path",
        -- 🔎 THESE EIGHT WERE FOUND BY THE CHECK BELOW, not by reading:
        -- the first run of the both-directions join named every report
        -- this table had missed. That is the design paying for itself
        -- before it shipped, and it is why the ⚠️ rows exist at all.
        anchorsReport       = "⇪⇧U — what it named in front, and which of its four legs answered",
        chromeHistoryReport = "⇪Y — the archive, the export, and what a keystroke costs to search",
        clipboardReport     = "⇪V — the newest item, how many are stored, and every refusal by reason",
        taskFormReport      = "⇪T — the form's size, its fields and the last task it created",
        monoReport          = "the screen veil's mono and invert",
        windowReturnReport  = "window return — switched OFF on your word, and the layouts it still holds",
        -- 🔎 6.431.0 — THE PROBES THE EXTRAS SWEEP STRUCTURALLY CANNOT SEE.
        -- That sweep (below) walks _G for names ending in "Report", which
        -- is why a report added next year appears here on the day it
        -- ships. A diagnostic called `…Probe` or `…CheckNow` ends in
        -- neither, so it was invisible to this list however long it had
        -- existed — four of them, every one read-only, every one asked for
        -- by name in a verify block at some point.
        -- 🚨 AND THREE MORE ARE DELIBERATELY NOT HERE: ⏎ on a row RUNS the
        -- thing, so `_G.vaultPurgeTrash` (it erases notes), `_G.hyperSelfTest`
        -- and `_G.hyperWakeProbeRun` (they act on the keyboard) stay out. A
        -- list whose ⏎ runs things may only hold things that read
        -- (6.335.0's rule about a purge control beside a restore control).
        -- `_G.settingsProbe` and `_G.urlCleanTest` take an ARGUMENT, so a
        -- row that pressed them with none would be a row that misfires.
        begoneProbe         = "the begone sweep — what it would close, and what it refuses to",
        padProbe            = "the numpad layer — which keys it holds and which are free",
        oneDriveProbe       = "OneDrive — what this Mac answers about a file that is really here",
        healthCheckNow      = "tool health — re-reads every watched store's last write, now",
    }

    -- 📋 6.427.0 — the rows. The LIST comes from `_G`; the table above
    -- only says what each one is for.
    local function srcReports(add)
        local seen, names = {}, {}
        for k in pairs(uni.reportDocs) do names[#names + 1] = k end
        -- 🔤 SORTED. pairs() hands back a different order every run, and a
        -- picker whose rows reshuffle under your hand is one you cannot
        -- aim at (6.410.0's rule about ties, in a list).
        table.sort(names)
        for _, name in ipairs(names) do
            seen[name] = true
            local what = uni.reportDocs[name]
            local fn   = rawget(_G, name)
            if type(fn) == "function" then
                add{ tag = "report", icon = "📋", src = "Reports",
                     text = what,
                     sub  = "_G." .. name .. "()",
                     full = "_G." .. name .. "()\n\n" .. what
                            .. "\n\n⏎ runs it — the answer prints in the Console."
                            .. "\n⌘⏎ copies the command instead.",
                     kind = "report", report = name }
            else
                -- 🚨 A SENTENCE WITH NO REPORT BEHIND IT: either that
                -- module did not load this session or the global was
                -- renamed. Opposite facts, both worth seeing, and neither
                -- of them is "nothing to report" (6.196.1).
                add{ tag = "report", icon = "📋", src = "Reports",
                     text = "⚠️ _G." .. name .. "() is NOT published this session",
                     sub  = "its module did not load, or it was renamed",
                     full = "This list names _G." .. name .. "() and nothing"
                            .. " published it this session.\n\n" .. what
                            .. "\n\n_G.bootReport() says which modules loaded.",
                     -- the NAME, but no `kind`: this row is readable and
                     -- deliberately not runnable. Offering to run a
                     -- report that is not there would be the list lying
                     -- about what exists, which is the whole defect
                     -- 6.276.0 deleted.
                     report = name }
            end
        end
        -- …then every published report nobody has described. A new one
        -- added next year shows up here on the day it ships rather than
        -- being quietly absent from the list for a year.
        local extra = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and not seen[k] and type(v) == "function"
               and k:match("Report$") then extra[#extra + 1] = k end
        end
        table.sort(extra)
        for _, name in ipairs(extra) do
            add{ tag = "report", icon = "📋", src = "Reports",
                 text = "⚠️ _G." .. name .. "() — no description written yet",
                 sub  = "_G." .. name .. "()",
                 full = "_G." .. name .. "() is published and this list does not"
                        .. " say what it answers.\n\n⏎ still runs it.",
                 kind = "report", report = name }
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
    -- 🔎 6.298.0 — EVERY SOURCE SAYS WHAT IT HOLDS (`what`). LL: "All @
    -- searches should be listed so I know what I can use to search."
    -- There are fourteen and the only place any of them was ever named
    -- is a section header in the results — which you can only read
    -- AFTER you have searched for something that happens to be in that
    -- store. A tag you have to already know is not a tag you can use.
    uni.sources = {
        { tag = "clip",  icon = "📋", label = "Clipboard",    fn = srcClipboard,
          what = "everything you have copied — ⇪V opens the panel here" },
        { tag = "cmd",   icon = "⌨️", label = "Commands",     fn = srcCommands,
          what = "the shell and Console commands ⇪H remembers" },
        -- 💾 UP NEAR THE CLIPBOARD on purpose: those are the stores you
        -- reach for when something you wrote has gone, and rows are
        -- gathered in this order and listed in it.
        { tag = "draft", icon = "💾", label = "Drafts",       fn = srcDraft,
          what = "the text a web form lost — kept while you typed in a"
                 .. " browser or Outlook; ⏎ copies it" },
        { tag = "logs",  icon = "📓", label = "Tool failures", fn = srcLogs,
          what = "every tool that has failed on this Mac — the 4 PM check,"
                 .. " searchable (_G.todayReport() is today alone)" },
        { tag = "shots", icon = "📸", label = "Screenshots",  fn = srcShots,
          what = "every file in the screenshots folder — ⇪⇧space opens here" },
        { tag = "note",  icon = "🗒", label = "Notes",        fn = srcNotes,
          what = "the notes ➕ Append has filed" },
        { tag = "asana", icon = "✅", label = "Asana tasks",  fn = srcAsana,
          what = "the tasks ⇪T has created" },
        { tag = "ocr",   icon = "🔤", label = "OCR",          fn = srcOCR,
          what = "words read out of your screenshots — ⇪O opens here" },
        { tag = "images", icon = "🖼", label = "Images",       fn = srcImages,
          what = "one card per image, found by the words inside it" },
        { tag = "doc",   icon = "📄", label = "Documents",    fn = srcDocs,
          what = "the documents and files you have worked in" },
        { tag = "file",  icon = "📁", label = "File moves",   fn = srcFiles,
          what = "every file this Mac has moved or renamed — ⇪F's 90 days" },
        { tag = "pad",   icon = "🗒", label = "Capture Pad",  fn = srcPad,
          what = "the captures still waiting in the Capture Pad" },
        { tag = "scratch", icon = "📝", label = "Hamsidian tabs", fn = srcScratch,
          what = "your Hamsidian tabs, open and closed" },
        { tag = "vault", icon = "🕸", label = "Hamsidian",    fn = srcVault,
          what = "your Hamsidian notes, by name" },
        { tag = "web",   icon = "🕘", label = "Chrome",       fn = srcWeb,
          what = "your Chrome history — ⇪Y's 90 days" },
        -- 📋 6.427.0 — beside @tool and above it, for the same reason both
        -- are at the bottom: these rows are always there, so they stay
        -- under the things you actually saved. @report puts them on top.
        { tag = "report", icon = "📋", label = "Reports",     fn = srcReports,
          what = "every report this config can print and what each one"
                 .. " answers — ⏎ runs it, ⌘⏎ copies the command" },
        -- 🔧 LAST ON PURPOSE. Rows are gathered in this order and the page
        -- lists them in it, so the things you SAVED stay above the tools
        -- that are always there. @tool (or ⇪⇧/) puts them on top instead.
        { tag = "tool",  icon = "🔧", label = "Tools",        fn = srcTools,
          what = "every tool and shortcut this config has — ⇪⇧/ opens here" },
    }

    function uni.gather()
        uni.rows, uni.counts = {}, {}
        -- 🚨 A FAILED SOURCE IS REMEMBERED, NOT JUST PRINTED (6.196.1).
        -- Before this, a source that threw said so once at gather time
        -- and then scrolled out of the Console, so a store that had been
        -- silently missing for weeks looked exactly like a store that
        -- was simply empty. The report below names both, differently.
        uni.failed = {}
        uni.lastGather = os.time()
        local function add(o)
            o.id = #uni.rows + 1
            uni.rows[o.id] = o
            uni.counts[o.tag] = (uni.counts[o.tag] or 0) + 1
        end
        for _, s in ipairs(uni.sources) do
            local ok, err = pcall(s.fn, add)
            if not ok then
                uni.failed[s.tag] = tostring(err)
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
            -- 6.187.0 — the FULL text joins the haystack, bounded. Before
            -- this only the preview did, so a word buried in an OCR'd page
            -- or a long clipboard entry was in the index and unfindable.
            local full = tostring(r.full or "")
            if full == (r.text or "") then full = "" end
            local hay = string.lower((r.text or "") .. " " .. (r.sub or "")
                        .. " @" .. r.tag .. " " .. (r.src or "")
                        .. " " .. full:sub(1, uni.hayFull))
            parts[#parts + 1] = "{\"id\":" .. r.id
                .. ",\"tag\":" .. jstr(r.tag)
                .. ",\"icon\":" .. jstr(r.icon)
                .. ",\"src\":" .. jstr(r.src)
                .. ",\"t\":" .. jstr(r.text)
                .. ",\"s\":" .. jstr(r.sub)
                .. ",\"h\":" .. jstr(hay)
                .. (r.img and (",\"img\":" .. jstr(r.img)) or "")
                .. (r.path and ",\"p\":1" or "")
                -- 6.204.0 — `m` says the row holds MORE than its preview
                -- line, so the pane can call the line a preview until
                -- Lua's answer lands, and never for a row that is whole.
                .. (full ~= "" and ",\"m\":1" or "")
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
                -- 6.298.0 — `w` is what the source HOLDS, drawn in the
                -- @ directory. A source with no `what` is a row the
                -- directory cannot explain, so the gate asserts every
                -- one carries it rather than letting it print blank.
                .. ",\"w\":" .. jstr(s.what)
                -- `or {}` — this is asked while building the page and
                -- the page may be built before a gather (a test, a
                -- rebuild after a failure). A JSON builder that RAISES
                -- takes the whole panel with it (6.282.0).
                .. ",\"n\":" .. tostring((uni.counts or {})[s.tag] or 0) .. "}"
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
  #list{position:absolute;top:124px;bottom:0;left:0;right:]] .. tostring(uni.pane and uni.paneW or 0) .. [[px;overflow-y:auto}
  #pane{position:absolute;top:124px;bottom:0;right:0;width:]] .. tostring(uni.paneW) .. [[px;
        box-sizing:border-box;padding:12px 14px;overflow-y:auto;
        border-left:1px solid #1c1c29;background:#0d0d14}
  #pane .ph{font-size:11px;font-weight:700;letter-spacing:.5px;
        text-transform:uppercase;color:#9db4ff;margin-bottom:4px}
  #pane .pw{font-size:12px;color:#8a8aa2;margin-bottom:10px;line-height:1.4}
  #pane .pt{font-size:15px;line-height:1.45;white-space:pre-wrap;
        word-break:break-word;color:#e9e9f2;
        -webkit-user-select:text;user-select:text}
  #pane .pf{font-size:12px;color:#8a8aa2;margin-top:12px;word-break:break-all}
  #pane img.big{display:block;max-width:100%;border-radius:6px;
        background:#000;margin-bottom:10px}
  #pane .empty{color:#6a6a82;font-size:13px;margin-top:8px}
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
<span class="hint">drag here · hover or ↑↓ · ⏎ copy · ⌘⏎ path · Esc</span></div>
<input id="q" spellcheck="false" autocorrect="off" placeholder="Search everything — every word must match · type @ to see all ]] .. tostring(#uni.sources) .. [[ sources">
<div id="count"></div>
<div id="list"></div>]] .. (uni.pane and '\n<div id="pane"></div>' or "") .. [[

<script>
var ROWS = ]] .. uni.rowsJson() .. [[;
var SRCS = ]] .. uni.sourcesJson() .. [[;
var PREFILL = ]] .. jstr(prefill or "") .. [[;
var CAP = ]] .. tostring(uni.pageCap) .. [[;
var GROUP = ]] .. tostring(uni.groupCap) .. [[;
var PANE = ]] .. (uni.pane and "true" or "false") .. [[;

function say(m){ try { webkit.messageHandlers.unifiedSearch.postMessage(m); }
                 catch (e) {} }
function el(id){ return document.getElementById(id); }
var q = el('q'), list = el('list'), count = el('count');
var pane = PANE ? el('pane') : null;
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
// 🔎 6.298.0 — WHAT `visible` HOLDS: 'rows' (row ids, as it always has)
// or 'tags' (source tags, in the @ directory). One variable rather than
// a second list, so ↑↓ and ⏎ stay one code path for both views.
var mode = 'rows';
// 6.431.0 — the source an exact @tag pinned on the last rebuild, or null.
// It decides the count line as well as the rows: "97 reports" and "101
// matches across every store" are different facts, and only one of them
// is what you asked for.
var pin = null;
// 👁 6.204.0 — which hand moved the highlight last. It decides ONE thing,
// the "🖱 under the pointer" tag in the pane's header — a label, never a
// row (6.202.0's rule: the highlight is the answer for both hands).
var hand = 'keys';
// The row id the pane has asked Lua about. One ask per LANDING: a rebuild
// that keeps the same row highlighted (a keystroke that changes no token,
// a hover that lands where the highlight already is) asks nothing more,
// or every such keystroke would have Lua push the whole entry again.
var detailFor = null;

function paneHtml(row, full, path, total, cut){
  var h = '<div class="ph">' + row.icon + ' ' + esc(row.src) +
          (hand === 'mouse' ? ' · 🖱 under the pointer' : ' · ⌨️ ↑↓') + '</div>';
  var when = row.s ? esc(row.s) : '';
  if (full == null) {
    // Nothing back from Lua yet (or ever, on a Hammerspoon whose webview
    // cannot be written to): the list's own line, and CALLED a preview
    // when the row holds more than it — never for a row that is whole.
    if (row.m) when += (when ? ' · ' : '') + 'preview — first ' +
                       String(row.t).length + ' characters';
  } else {
    when += (when ? ' · ' : '') + total + ' character' + (total === 1 ? '' : 's');
    if (cut) when += ' — first ' + cut + ' shown · ⏎ copies all of it';
  }
  h += '<div class="pw">' + when + '</div>';
  if (row.img) h += '<img class="big" src="' + row.img + '">';
  h += '<div class="pt">' + esc(full == null ? row.t : full) + '</div>';
  if (path) h += '<div class="pf">' + esc(path) + '</div>';
  if (row.p) h += '<div class="pf">⌘⏎ copies the path · ⌥⏎ opens it</div>';
  return h;
}
// Draw the pane for the highlighted row. The list's line goes up at once,
// so the pane is never blank; the full entry follows when Lua answers.
function showPane(){
  if (!pane) return;
  if (mode === 'tags') {
    var src = SRCS[sel];
    pane.innerHTML = src
      ? '<div class="ph">' + src.icon + ' ' + esc(src.label) + '</div>' +
        '<div class="pw">' + src.n + ' item' + (src.n === 1 ? '' : 's') +
        ' indexed right now</div>' +
        '<div class="pt">' + esc(src.w) + '</div>' +
        '<div class="pf">⏎ puts @' + esc(src.tag) + ' in the box</div>'
      : '<div class="empty">No sources</div>';
    // Nothing to ask Lua about: a source is not a row, and leaving the
    // last row's id here would drop the NEXT answer for that row.
    detailFor = null;
    return;
  }
  var id = visible[sel], row = byId[id];
  if (!row) {
    pane.innerHTML = '<div class="empty">Nothing highlighted — type, or ' +
                     'move the pointer over a row</div>';
    detailFor = null;
    return;
  }
  pane.innerHTML = paneHtml(row, null, null, 0, 0);
  if (detailFor !== id) { detailFor = id; say({ a: 'detail', id: id }); }
}
// Lua's answer: uniDetail(id, fullText, path, totalChars, shownChars-if-cut-else-0).
// Counted by LUA in characters, both numbers — a JS .length counts an
// emoji as two and would say "first 12,050 shown" over a 12,000 cut. Drawn ONLY
// if the pane is still on that row — an answer for a row you have already
// left is dropped, never painted over the row you are on now.
function uniDetail(id, full, path, total, cut){
  if (!pane) return;
  if (id !== visible[sel]) return;
  var row = byId[id];
  if (!row) return;
  pane.innerHTML = paneHtml(row, full, path, total, cut);
}

// 🔎 6.298.0 — IS THE BOX ASKING WHAT THE @ SEARCHES ARE? PURE, and
// deliberately ONE case: the whole box is "@" and nothing else.
// 🚨 IT IS NOT "any query starting with @", and that is the decision
// worth keeping: "@o" ALREADY searches — it matches @ocr's rows through
// the haystack — so a directory on every @-prefix would take a working
// search away to show a menu. One character, one list; a second
// character is a search again.
function asksForTags(s){
  return String(s == null ? '' : s).trim() === '@';
}
// The @word in a query that is no source's tag. Asked ONLY when a
// search found nothing — where the panel has always said "nothing
// matches" about a tag that does not exist while naming none of the
// ones that do, which is the same wall as not knowing the tags at all.
function unknownTag(toks){
  for (var i = 0; i < toks.length; i++) {
    var t = toks[i];
    if (t.charAt(0) !== '@' || t.length < 2) continue;
    var name = t.slice(1), hit = false;
    for (var s = 0; s < SRCS.length; s++)
      if (String(SRCS[s].tag).indexOf(name) === 0) { hit = true; break; }
    if (!hit) return t;
  }
  return null;
}
// 📌 6.431.0 — AN EXACT @tag PINS THE VIEW TO THAT ONE SOURCE, and
// every row of it is drawn. LL, of @report: "Give me the 41 reports I
// can run in the list instead of saying type to filter."
//
// 🔎 WHY 41 WENT MISSING: the page draws at most CAP rows
// (uni.pageCap, 60) and said "…and N more — keep typing to narrow" for
// the rest. 6.298.0 put the tag in every row's haystack so a PARTIAL
// @word still searches, which is right — and it also means @report is
// just another search term, subject to a cap chosen for searches across
// every store at once.
//
// 🔑 AND NARROWING IS NOT AN ANSWER HERE, which is the half that makes
// this a defect rather than a number: every report has a different
// name, so narrowing requires already knowing which one you want — and
// finding that out is the entire job of the list. That is 6.298.0's own
// rule one layer down: a directory you must narrow before you can read
// it is not a directory.
//
// 📏 THE BOUND IS STILL THERE, it is just the honest one: every source
// is capped at gather time by uni.maxPer, so "all of this store" can
// never be more rows than that — the page is not being handed an
// unbounded list. The CAP stays for a free-text search, where a single
// letter really can match thousands.
//
// An exact tag only: '@o' must go on searching @ocr the way it always
// has, so a prefix is NOT a pin.
function pinnedTag(toks){
  for (var i = 0; i < toks.length; i++) {
    if (toks[i].charAt(0) !== '@') continue;
    var name = toks[i].slice(1);
    for (var s = 0; s < SRCS.length; s++)
      if (String(SRCS[s].tag) === name) return name;
  }
  return null;
}
// The tokens left once the pin is taken out — they still filter INSIDE
// the pinned store, so "@report draft" works exactly as it reads.
function withoutTag(toks, tag){
  var out = [];
  for (var i = 0; i < toks.length; i++)
    if (toks[i] !== '@' + tag) out.push(toks[i]);
  return out;
}
// The directory itself. EVERY source, including the empty ones: "@pad
// holds nothing today" and "there is no @pad" are opposite facts
// (6.196.1), and hiding the empty ones would make them read the same.
function tagsHtml(){
  var h = '<div class="sec">🔎 THE @ SEARCHES — ' + SRCS.length +
          ' <span class="tag">⏎ on one to search it</span></div>';
  for (var s = 0; s < SRCS.length; s++) {
    var src = SRCS[s];
    h += '<div class="row' + (s === sel ? ' sel' : '') +
         '" data-tag="' + esc(src.tag) + '">' +
         '<div class="mid"><div class="t">' + src.icon + ' @' + esc(src.tag) +
         '</div><div class="s"><span class="src">' + esc(src.label) +
         '</span> · ' + esc(src.w) + '</div></div>' +
         '<span class="pp">' + src.n + '</span></div>';
    visible.push(src.tag);
  }
  return h;
}
// ⏎ or a click on a directory row COMPLETES THE BOX — it never posts to
// Lua. The panel is a reader; this row is a word you were about to type.
function pickTag(tag){
  if (tag == null) return;
  q.value = '@' + tag + ' ';
  sel = 0; hand = 'keys';
  rebuild();
}

function rowHtml(row, visIndex){
  var cls = 'row' + (visIndex === sel ? ' sel' : '');
  var h = '<div class="' + cls + '" data-id="' + row.id + '">';
  if (row.img) h += '<img class="th" src="' + row.img + '">';
  h += '<div class="mid"><div class="t">' + esc(row.t) + '</div>' +
       '<div class="s"><span class="src">' + row.icon + ' ' + esc(row.src) +
       '</span>' + (row.s ? ' · ' + esc(row.s) : '') + '</div></div>';
  if (row.p) h += '<span class="pp">⌘⏎ path · ⌥⏎ open</span>';
  return h + '</div>';
}

function rebuild(){
  var toks = tokens(q.value);
  visible = []; total = 0;
  var html = '';
  mode = asksForTags(q.value) ? 'tags' : 'rows';
  if (mode === 'tags') {
    html = tagsHtml();
    total = SRCS.length;
  } else if (!toks.length) {
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
    pin = pinnedTag(toks);
    var ftoks = pin ? withoutTag(toks, pin) : toks;
    for (var j = 0; j < ROWS.length; j++) {
      if (pin && ROWS[j].tag !== pin) continue;
      if (!matches(ROWS[j], ftoks)) continue;
      total++;
      if (pin || visible.length < CAP) {
        html += rowHtml(ROWS[j], visible.length);
        visible.push(ROWS[j].id);
      }
    }
    if (total > visible.length)
      html += '<div class="more">…and ' + (total - visible.length) +
              ' more — keep typing to narrow</div>';
    if (!total) {
      var bad = unknownTag(toks);
      html += '<div class="more">Nothing matches "' + esc(q.value) +
              '" in any store' + (bad
                ? ' — and there is no ' + esc(bad) + ' source. Type @ on its ' +
                  'own to see all ' + SRCS.length + '.'
                : ' — ⌫ widens it again') + '</div>';
    }
  }
  list.innerHTML = html;
  count.textContent = (mode === 'tags')
    ? (SRCS.length + ' sources — ⏎ on one to search it, or keep typing')
    : (toks.length
       ? (pin
          ? (total + ' in @' + pin + (total ? ' — every one of them, listed'
                                           : ' — nothing in that store matches'))
          : (total + ' match' + (total === 1 ? '' : 'es') + ' across every store'))
       : (ROWS.length + ' items indexed — newest of each store below'));
  showPane();
}

function render(){ rebuild(); var n = document.querySelector('.row.sel');
                   if (n && n.scrollIntoView) n.scrollIntoView({block:'nearest'}); }
function move(d){
  if (!visible.length) return;
  sel = Math.max(0, Math.min(visible.length - 1, sel + d));
  hand = 'keys';
  render();
}
// The row id under an event target — the same walk the click has always
// done, shared now so the click and the hover cannot name different rows.
function attrAt(n, name){
  while (n && n !== list && !(n.getAttribute && n.getAttribute(name)))
    n = n.parentNode;
  if (n && n !== list && n.getAttribute) return n.getAttribute(name);
  return null;
}
function rowIdAt(n){
  var v = attrAt(n, 'data-id');
  return v == null ? null : parseInt(v, 10);
}
function pick(id, wantPath, wantOpen){
  if (id == null) return;
  // 6.187.0 — ⌥⏎ OPENS the thing. For an image that is the whole point:
  // a 40 px thumbnail tells you which picture it is, not what is in it.
  say({ a: wantOpen ? 'open' : (wantPath ? 'path' : 'pick'), id: id });
}

q.addEventListener('input', function(){ sel = 0; hand = 'keys'; rebuild(); });
// 🖱 6.204.0 — THE POINTER MOVES THE HIGHLIGHT, the way a chooser's does:
// on MOVEMENT only (a DOM mousemove never fires for a parked pointer, so
// the arrows scrolling the list under a resting hand steal nothing), and
// with no scrollIntoView — the pointer is already on the row, and
// scrolling the list under it would put a different row there.
list.addEventListener('mousemove', function(ev){
  var id = (mode === 'tags') ? attrAt(ev.target, 'data-tag')
                             : rowIdAt(ev.target);
  if (id == null) return;
  var i = visible.indexOf(id);
  if (i < 0 || i === sel) return;
  sel = i; hand = 'mouse';
  rebuild();
});
// ⌨️ 6.193.0 — forward the ⇪ (F18) keyUp to Lua. WebKit sees it even
// when the Carbon release never reaches the hotkey, and without this the
// hold sat latched for 8 s and the panel felt stuck. Same two lines the
// vault and the Scorp Pad carry.
document.addEventListener('keyup', function(e){
  if (e.key === 'F18' || e.keyCode === 79) say({a:'f18up'}); });
window.addEventListener('keydown', function(ev){
  if (ev.key === 'ArrowDown') { if (ev.preventDefault) ev.preventDefault(); move(1); }
  else if (ev.key === 'ArrowUp') { if (ev.preventDefault) ev.preventDefault(); move(-1); }
  else if (ev.key === 'Enter') {
    if (ev.preventDefault) ev.preventDefault();
    if (mode === 'tags') pickTag(visible[sel]);
    else pick(visible[sel], ev.metaKey === true, ev.altKey === true);
  }
  else if (ev.key === 'Escape') { say({ a: 'close' }); }
});
list.addEventListener('click', function(ev){
  if (mode === 'tags') { pickTag(attrAt(ev.target, 'data-tag')); return; }
  var id = rowIdAt(ev.target);
  if (id != null) pick(id, ev.metaKey === true, ev.altKey === true);
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
                -- 📋 6.325.0 — the one door, and the sentence is
                -- CONDITIONAL on the write it describes.
                if core.copyText(keys, "⇪D (a shortcut)") then
                    hs.alert.show("🔧 " .. keys .. "  (copied — press it)", 1.5)
                end
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

    -- 📋 6.427.0 — ⏎ ON A REPORT ROW RUNS IT. Same shape as a tool row
    -- and for the same reason: the panel goes away FIRST and the call is
    -- a run-loop turn later, because several of these open a window or a
    -- picker of their own and this webview is holding the keyboard.
    function uni.runReport(row)
        local name = tostring(row.report or "")
        uni.hide()
        local fn = rawget(_G, name)
        if type(fn) ~= "function" then
            -- Not published this session. Being handed the command is the
            -- fallback, not a lie about having run it.
            if core.copyText("_G." .. name .. "()", "⇪D (a report)") then
                hs.alert.show("📋 _G." .. name .. "()  — not published this"
                              .. " session; the command is copied", 3)
            end
            return
        end
        local t = hs.timer.doAfter(0.05, function()
            local ok, err = pcall(fn)
            if ok then
                hs.alert.show("📋 _G." .. name .. "() — the answer is in the Console", 2)
                say("ran _G." .. name .. "()")
                return
            end
            -- 🚨 A REPORT THAT RAISES IS WORSE THAN ONE THAT LIES
            -- (6.282.0): it takes itself down and says nothing, in the
            -- one place this config goes to find out what is wrong. So a
            -- throw is named on screen, in the Console AND in the ledger.
            warn("_G." .. name .. "() threw: " .. tostring(err))
            hs.alert.show("⚠️ _G." .. name .. "() threw — see the Console", 4)
            if _G.notices then
                pcall(_G.notices.record, "unified", "a report threw",
                      name .. " — " .. tostring(err))
            end
        end)
        uni.runTimers[#uni.runTimers + 1] = t
        while #uni.runTimers > 8 do table.remove(uni.runTimers, 1) end
    end

    -- ---- the detail pane's answer (6.204.0) ----------------------------------
    -- The full text is cut to uni.detailMax CHARACTERS, never mid-glyph:
    -- a byte cut can split a UTF-8 sequence, and a Lua string that is
    -- not valid UTF-8 does not survive the trip into WebKit at all — the
    -- script is dropped and the pane sits on its preview with no error
    -- anywhere. utf8.len says how many characters the whole entry holds
    -- (bytes if the text is not valid UTF-8, so a bad store still answers).
    uni.detailAsked, uni.detailDrawn, uni.detailRefused = 0, 0, 0
    uni.detailLast = nil
    function uni.detailCut(text, maxChars)
        text = tostring(text or "")
        local total = utf8.len(text) or #text
        if total <= maxChars then return text, total, false end
        local okOff, off = pcall(utf8.offset, text, maxChars + 1)
        if not (okOff and off) then
            -- not valid UTF-8: cut on bytes, then step back off any
            -- continuation byte so the slice is still decodable
            off = maxChars + 1
            while off > 1 and text:byte(off) and text:byte(off) >= 0x80
                  and text:byte(off) < 0xC0 do
                off = off - 1
            end
        end
        return text:sub(1, off - 1), total, true
    end
    function uni.answerDetail(row)
        uni.detailAsked = uni.detailAsked + 1
        local shown, total, cut = uni.detailCut(row.full or row.text or "",
                                                uni.detailMax)
        -- the fifth value is the CHARACTERS shown when cut (0 = whole):
        -- both numbers counted here, in the same unit, by the same hand
        local shownN = cut and (utf8.len(shown) or #shown) or 0
        local js = "uniDetail(" .. tostring(row.id) .. "," .. jstr(shown)
                   .. "," .. jstr(row.path or "") .. "," .. tostring(total)
                   .. "," .. tostring(shownN) .. ")"
        local view = uni.webview
        local ok = false
        if view and type(view.evaluateJavaScript) == "function" then
            ok = pcall(function() view:evaluateJavaScript(js) end)
        end
        if ok then
            uni.detailDrawn = uni.detailDrawn + 1
            uni.detailLast = row.id
        else
            -- the window went away before Lua answered, or this
            -- Hammerspoon's webview cannot be written to: the page keeps
            -- the preview it drew itself, and the report counts this.
            uni.detailRefused = uni.detailRefused + 1
        end
        return ok
    end

    -- ---- the Lua side of the bridge ----------------------------------------
    local function handleMessage(body)
        if type(body) ~= "table" then return end
        local a = body.a
        if a == "close" then uni.hide() return end
        -- The page saw the F18 keyUp itself — that IS the release
        -- (6.165.1's contract, now honoured here too).
        if a == "f18up" then
            if _G.hyperReleaseSeen then
                pcall(_G.hyperReleaseSeen, "unified search")
            end
            return
        end
        if a == "dragStart" then
            if _G.beginPanelDrag then _G.beginPanelDrag("unified search")
            else print("🔎 Unified Search: window_move is off — the header cannot drag") end
            return
        end
        local row = uni.rows and uni.rows[tonumber(body.id or 0)]
        if not row then return end
        -- 👁 6.204.0 — the pane asks for ONE row's full entry; the answer
        -- goes back through the page's uniDetail(). Nothing here copies,
        -- opens, or closes — it is a read, and the panel stays up.
        if a == "detail" then uni.answerDetail(row) return end
        -- 6.187.0 — ⌥⏎ hands the file to macOS and gets out of the way.
        -- /usr/bin/open in a task: never a decode, never a main-thread read,
        -- so a cloud-evicted file is OneDrive's problem and not a stall here.
        -- guarded on `path`, and DELIBERATELY not an else: a row with no
        -- file (a tool, a vault note) falls through and ⌥⏎ does what ⏎ does,
        -- rather than dead-ending on "nothing to open".
        if a == "open" and row.path then
            local ok = false
            pcall(function()
                local t = hs.task.new("/usr/bin/open", nil, { row.path })
                ok = t and t:start() and true or false
                uni.openTask = t          -- HELD
            end)
            hs.alert.show(ok and ("📂 Opening " .. (row.path:match("[^/]+$") or row.path))
                          or "⚠️ Could not open that file", ok and 2 or 3)
            uni.hide()
            return
        end
        -- 🔧 A TOOL ROW RUNS. Everything else on this panel copies; this one
        -- kind acts, which is why it is checked before the copy paths and
        -- not folded into them.
        if row.kind == "tool" then uni.runTool(row) return end
        -- 📋 6.427.0 — a report row ACTS too, so it is checked here with
        -- the tool rows and not folded into the copy paths below.
        if row.kind == "report" then
            if a == "path" then
                local cmd = "_G." .. tostring(row.report) .. "()"
                if core.copyText(cmd, "⇪D (a report)") then
                    hs.alert.show("📋 " .. cmd .. " copied", 2)
                end
                uni.hide()
                return
            end
            uni.runReport(row)
            return
        end
        -- 🕸 6.172.0 — a vault row OPENS the note in the ⇪3 window.
        if row.vaultNote and _G.vault and _G.vault.openNote then
            uni.hide()
            pcall(function()
                _G.vault.openNote(row.vaultNote)
                if _G.vault.webview then _G.vault.render() else _G.vault.open() end
            end)
            return
        end
        if a == "path" and row.path then
            if core.copyText(row.path, "⇪D (a path)") then
                hs.alert.show("📋 Path copied — " .. (row.path:match("[^/]+$") or row.path))
            end
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
                -- 🚨 6.325.0 — this said "📋 Copied" whatever happened.
                -- hs.pasteboard.setContents refuses by RETURNING FALSE and
                -- never throws, so the pcall was true either way and a
                -- refused write was announced as a copy (6.198.0).
                -- 📋 6.402.0 — a CLIPBOARD row is pasted at the caret
                -- rather than only copied; everything else keeps copying,
                -- because pasting a file path or a shortcut's keys into
                -- whatever he was typing in is not what ⏎ means there.
                if row.tag == "clip" then
                    uni.pasteRow(row.full or row.text or "", row.src or "Clipboard")
                    return                 -- pasteRow closes the panel itself
                elseif core.copyText(row.full or row.text or "", "⇪D") then
                    hs.alert.show("📋 Copied — " .. (row.src or "text"))
                end
            end
            uni.hide()
        end
    end
    uni.handleMessage = handleMessage   -- exposed for the test suite

    -- ---- window -------------------------------------------------------------
    -- 🎯 6.402.0 — CLOSING THIS PANEL PUTS YOU BACK WHERE YOU WERE.
    -- It takes the keyboard (it is typed into), which activates
    -- Hammerspoon — 6.251.0's price, unpaid here as it was in the edit
    -- window. `keepFocus` is passed by the two callers that are about to
    -- take the keyboard again themselves (show's "never two at once",
    -- and the paste below, which hands the focus back itself and then
    -- needs to know whether it really came back).
    function uni.hide(keepFocus)
        if uni.webview then
            pcall(function() uni.webview:delete() end)
            uni.webview = nil
        end
        -- AFTER the window is gone, never before: a window still on
        -- screen takes the focus straight back off the app we activated.
        if not keepFocus and _G.focusReturn then
            pcall(_G.focusReturn, "⇪D")
        end
    end

    -- =================================================================
    -- 📋 6.402.0 — ⏎ ON A CLIPBOARD ROW PASTES IT
    -- =================================================================
    -- LL: "First result from history clipboard list is not pasted when
    -- selected and it should be."
    --
    -- 🔎 AND THE FIRST ROW IS WHY IT READ AS BROKEN RATHER THAN AS A
    -- MISSING FEATURE. ⏎ has always COPIED, and the first row of the
    -- clipboard history IS whatever is already on the clipboard — so ⏎
    -- there wrote back what was already there, pasted nothing, and
    -- changed nothing observable. Every other row at least leaves ⌘V
    -- carrying something different afterwards; row one does not, so the
    -- one row he would try first is the one that looks dead. GENERAL:
    -- when a tool is reported broken for one particular item, ask what
    -- is unique about that item before looking at the mechanism.
    --
    -- 🚨 A ⌘V IS ONLY POSTED ONCE THE FOCUS IS PROVEN BACK. Posted while
    -- this panel still has the keyboard it goes nowhere; posted after he
    -- has moved on himself it lands in whatever he moved to, which could
    -- be a document he did not mean to type into. Both are worse than
    -- leaving the text on the clipboard — which 6.325.0's door has
    -- already done by the time we get here — so a focus that did not
    -- come back means COPY ONLY, said out loud, never a blind paste.
    uni.pasteOnPick    = true    -- ✏️ false = ⏎ copies, as before 6.402.0
    uni.pasteSettleSecs = 0.12   -- macOS activates an app on its own turn
    uni.pastes = { asked = 0, posted = 0, copiedOnly = 0, last = nil }
    uni.pasteTimer = nil

    function uni.pasteRow(text, src)
        local st = uni.pastes
        st.asked = st.asked + 1
        local function copiedOnly(why)
            st.copiedOnly = st.copiedOnly + 1
            st.last = { ok = false, why = why, src = src }
            hs.alert.show("📋 It is on your clipboard — ⌘V pastes it\n"
                          .. why, 4)
            return false
        end
        -- The write comes first and through the one door, so a refusal is
        -- announced by it and nothing below pretends otherwise (6.325.0).
        if not core.copyText(text, "⇪D") then
            st.copiedOnly = st.copiedOnly + 1
            st.last = { ok = false, src = src,
                        why = "macOS refused the clipboard write" }
            return false
        end
        uni.hide(true)                 -- keep the loan; we return it below
        if not uni.pasteOnPick then
            st.last = { ok = false, src = src, why = "pasteOnPick is off" }
            hs.alert.show("📋 Copied — " .. tostring(src or "text"), 3)
            return false
        end
        local back = false
        if _G.focusReturn then
            back = (_G.focusReturn("⇪D") == true)
        end
        if not back then
            return copiedOnly("the app you were in could not be brought back")
        end
        if not (hs.timer and hs.timer.doAfter) then
            return copiedOnly("this Mac would not arm a timer")
        end
        -- 🪜 A HELD TIMER IN ITS OWN SLOT (6.196.1): activating an app
        -- happens on macOS's own turn, so a ⌘V posted on this line
        -- arrives before the app is in front.
        if uni.pasteTimer then pcall(function() uni.pasteTimer:stop() end) end
        uni.pasteTimer = hs.timer.doAfter(uni.pasteSettleSecs, function()
            uni.pasteTimer = nil
            -- 🚨 THROUGH THE SHARED INJECTION GUARD (6.218.0): a posted
            -- ⌘V comes back through this config's own taps as typing, and
            -- autocorrect is watching the same keystrokes.
            local ok = (_G.withInjection or pcall)(function()
                hs.eventtap.keyStroke({ "cmd" }, "v", 0)
            end)
            if ok then
                st.posted = st.posted + 1
                -- POSTED, not "pasted": 6.299.0 — a return that means
                -- accepted is not a return that means delivered, and
                -- nothing here can see where the keystroke landed.
                st.last = { ok = true, src = src }
            else
                st.copiedOnly = st.copiedOnly + 1
                st.last = { ok = false, src = src,
                            why = "macOS refused the ⌘V" }
                pcall(function()
                    hs.alert.show("📋 It is on your clipboard — ⌘V pastes it\n"
                                  .. "macOS refused the keystroke", 4)
                end)
            end
        end)
        return true
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

    -- 🔎 THE REPORT (6.196.1). ⇪space had no `_G.<tool>Report()` — the
    -- one tool in this config without one, and the module contract says
    -- every tool has one. LL asked "2372 items indexed — does this seem
    -- right?" and there was no way to answer it: the boot line gives a
    -- total and a store COUNT, so a store that has quietly stopped
    -- contributing is invisible inside a number that still looks large.
    -- A source with zero rows and a source that FAILED read identically
    -- from outside, which is the whole reason this exists.
    --
    -- Prints as ONE string — 6.179.1, the console gate eats a report
    -- printed row by row.
    function _G.unifiedSearchReport()
        local L = { "🔎 UNIFIED SEARCH — what is actually in the box" }
        local total, live, empty, broke = 0, 0, 0, 0
        for _, src in ipairs(uni.sources) do
            local n   = (uni.counts and uni.counts[src.tag]) or 0
            local err = uni.failed and uni.failed[src.tag]
            total = total + n
            local state
            if err then
                broke = broke + 1
                state = "FAILED — " .. tostring(err)
            elseif n == 0 then
                empty = empty + 1
                state = "0 — nothing in this store yet"
            else
                live = live + 1
                state = tostring(n)
            end
            L[#L + 1] = string.format("   %-2s @%-8s %s", src.icon or "",
                                      src.tag, state)
        end
        L[#L + 1] = "   ─────"
        L[#L + 1] = "   total  : " .. total .. " rows from " .. live
                    .. " of " .. #uni.sources .. " stores"
                    .. (empty > 0 and (" · " .. empty .. " empty") or "")
                    .. (broke > 0 and (" · " .. broke .. " FAILED") or "")
        if uni.rows and #uni.rows ~= total then
            L[#L + 1] = "   ⚠️ the row list holds " .. #uni.rows
                        .. " — it disagrees with the per-store counts"
        end
        -- 📏 6.431.0 — THE CAPS, SAID OUT LOUD. "Why do I only have 33
        -- screenshots" could only be answered by reading the source,
        -- because the numbers that decide how much of a store you can
        -- see were nowhere in the report that describes the store.
        L[#L + 1] = "   caps   : an exact @tag lists that whole store · a"
                    .. " free-text search draws " .. tostring(uni.pageCap)
                    .. " rows at once"
        L[#L + 1] = "   📸 shots : " .. tostring(uni.shotsOnDisk or 0)
                    .. " in the folder · " .. tostring(uni.shotRows or 0)
                    .. " listed (cap " .. tostring(uni.maxPer.shots) .. ") · "
                    .. tostring(uni.shotThumbs or 0) .. " thumbnail(s) decoded"
                    .. " (budget " .. tostring(uni.thumbMax) .. ")"
        if (uni.shotsOnDisk or 0) > (uni.shotRows or 0) then
            L[#L + 1] = "             ↳ " .. ((uni.shotsOnDisk or 0) - (uni.shotRows or 0))
                        .. " older capture(s) are on disk and NOT in the box —"
                        .. " settings = { unified_search = { maxPer = … } } or ⇪⇧5"
        end
        L[#L + 1] = "   built  : " .. (uni.lastGather
            and (os.date("%H:%M:%S", uni.lastGather) .. " ("
                 .. (os.time() - uni.lastGather) .. "s ago)")
            or "not gathered yet — press ⇪D once")
        -- 👁 6.204.0 — the pane's state. "never asked" and "0 drawn" must
        -- not read the same (6.196.1): the first is a panel nobody has
        -- hovered yet, the second is a pane that asked and got nothing.
        if not uni.pane then
            L[#L + 1] = "   pane   : off — settings = { unified_search = { pane = true } } brings it back"
        else
            local asked = uni.detailAsked or 0
            local line = "   pane   : on · " .. tostring(uni.paneW) .. " px · first "
                         .. tostring(uni.detailMax) .. " characters of the entry"
            if asked == 0 then
                line = line .. " · never asked — open ⇪D and move the pointer over a row"
            else
                line = line .. " · " .. asked .. " asked · "
                       .. tostring(uni.detailDrawn or 0) .. " drawn · "
                       .. tostring(uni.detailRefused or 0) .. " refused"
                local last = uni.detailLast and uni.rows and uni.rows[uni.detailLast]
                if last then
                    line = line .. " · last row " .. tostring(uni.detailLast)
                           .. " (" .. tostring(last.icon or "") .. " "
                           .. tostring(last.src or "") .. ")"
                end
            end
            L[#L + 1] = line
            if (uni.detailRefused or 0) > 0 then
                L[#L + 1] = "   ↳ a refused answer is the window gone before Lua replied,"
                            .. " or a webview with no evaluateJavaScript —"
                            .. " the pane shows the row's preview line instead"
            end
        end
        if broke > 0 then
            L[#L + 1] = "   ↳ a FAILED store is a bug to chase, not an empty one:"
                        .. " its rows are missing from every search until it loads."
        end
        -- 📋 6.402.0 — THREE STATES, because "nothing has been picked"
        -- and "every pick only made it to the clipboard" are different
        -- facts and the second is the one worth chasing (6.196.1).
        do
            local ps = uni.pastes or {}
            if not uni.pasteOnPick then
                L[#L + 1] = "   ⏎ clip : OFF — ⏎ copies rather than pasting"
                            .. "  (settings = { unified_search = { pasteOnPick = true } })"
            elseif (ps.asked or 0) == 0 then
                L[#L + 1] = "   ⏎ clip : no clipboard row has been picked this session"
            else
                L[#L + 1] = "   ⏎ clip : " .. ps.asked .. " picked · "
                            .. tostring(ps.posted or 0) .. " ⌘V posted · "
                            .. tostring(ps.copiedOnly or 0) .. " left on the clipboard only"
                if (ps.copiedOnly or 0) > 0 then
                    L[#L + 1] = "   ↳ NOT A FAILURE: the text is on the clipboard either"
                                .. " way. A ⌘V is only posted once the app you came from"
                                .. " is really back, because a blind one lands anywhere."
                end
                if ps.last then
                    L[#L + 1] = "   ↳ last  : " .. (ps.last.ok and "✅ posted ⌘V"
                                                    or "📋 clipboard only")
                                .. " · " .. tostring(ps.last.src or "?")
                                .. (ps.last.why and (" — " .. ps.last.why) or "")
                end
            end
        end
        print(table.concat(L, "\n"))
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
        uni.hide(true)                     -- never two at once; keep the loan
        if not (hs.webview and hs.webview.usercontent) then
            hs.alert.show("🔎 Unified Search needs hs.webview, which this "
                          .. "Hammerspoon does not have")
            return false
        end
        uni.gather()

        local screen = core.resolveBaseScreen and core.resolveBaseScreen()
                       or (hs.screen and hs.screen.mainScreen())
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        -- 6.204.0 — the pane is ADDED to the width, so the list keeps the
        -- 840 it has always had; a narrow screen clamps the whole.
        local w = math.min(uni.width + (uni.pane and uni.paneW or 0), sf.w - 60)
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
        -- 🚨 6.432.0 — `closeOnEscape(false)`, not true. WebKit's own
        -- handler closes the WINDOW behind Lua's back, leaving this
        -- module's handle assigned: the toggle then hides a window that
        -- is not there, and the escape claim stays live for the rest of
        -- the session — which starves every lower-priority panel of Esc
        -- and, from 6.432.0, would eat Escape in every app. 6.286.0 found
        -- this in the screenshot editor and swept only that file.
        -- 📏 MEASURED BEFORE IT WAS REMOVED: this page already sends
        -- {a:'close'} on Escape, and so do the other four that carried
        -- this line. So it was never THE closer — it was a second one
        -- that races the page's own handler and wins silently. Nothing
        -- is lost: with focus, the page closes through Lua; without it,
        -- the escape router does (core/hyper_key.lua).
        pcall(function() view:closeOnEscape(false) end)
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
        -- 🪟 6.391.0 — the shared door reads BOTH refusals (a throw and
        -- a false return). Guarded, so a build without it still opens.
        if _G.showWebviewSafely then
            _G.showWebviewSafely(view, "Unified search")
        else
            pcall(function() view:show() end)
        end
        -- 🎯 6.402.0 — BORROW THE FOCUS BEFORE TAKING IT, so closing
        -- gives it back and ⏎ on a clipboard row can paste into the app
        -- he came from rather than into nothing.
        if _G.focusBorrow then pcall(_G.focusBorrow, "⇪D") end
        pcall(function() view:bringToFront(true) end)

        -- ⌨️ 6.193.0 — THE ⇪ RELEASE HANDSHAKE, which this panel never had.
        -- LL: "For some reasons Unified Search is stuck on the screen
        -- sometimes", and his Console carries the matching line —
        -- "⇪ released by the watchdog — held 8s with no key event and no
        -- F18 keyUp". Every other text panel here (the vault, the Scorp
        -- Pad, the screenshot tool) has called hyperExpectRelease since
        -- 6.165.1; this one opens the same way and was simply missed.
        -- The cost of missing it is the 8 s latch: ⇪ stays held, the
        -- panel has the keyboard, and nothing behaves until the watchdog
        -- lets go. Both halves are needed — the shortened deadline here,
        -- and the page telling us when it sees the keyUp itself (WebKit
        -- gets that keyup even when the Carbon release never fires).
        if _G.hyperExpectRelease then
            pcall(_G.hyperExpectRelease, 1.5, "unified search")
        end

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
        core.hyperAddShortcut({ "shift" }, uni.shotsKey,
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
    -- 🚨 6.432.0 — AND THE CLAIM ASKS THE WORLD, not just the handle.
    -- His own `_G.escapeReport()` read `unified 55 🟢 wants esc now` with
    -- nothing on screen: `closeOnEscape(true)` had let WebKit close the
    -- window and `uni.webview` stayed assigned, so this claim was live
    -- for the rest of the session — which is what starved the switcher,
    -- both players, the calendar and the cheat sheet of Esc. That line is
    -- gone, which makes the handle truthful again: nothing else closes
    -- one of these windows without going through uni.hide().
    --
    -- 🚫 AND A LIVENESS BELT WAS WRITTEN HERE AND TAKEN OUT AGAIN. Asking
    -- `uni.webview:hswindow()` reads like the obvious second opinion and
    -- fails in the WRONG DIRECTION: this config has already recorded,
    -- twice and in two files, that hswindow() "answers nothing" on some
    -- builds for a window that is perfectly fine (editor_picker.lua:651,
    -- ocr_engine.lua:1446). A belt built on it would report this claim
    -- dead while the panel was on screen, and then Escape would not close
    -- it at all — a guard that fails on correct code, switched off inside
    -- a week (6.269.0). 6.395.0's rule decides it: an instrument that has
    -- never positively said "gone" is UNINFORMATIVE, never a refusal. The
    -- belt that IS safe is in the router, where it is a fact about
    -- BEHAVIOUR (a handler that ran and did not stand down) rather than a
    -- platform answer — see `_G.routeEscape` in core/coexist.lua.
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
