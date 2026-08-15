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
-- @file @pad. Tags ride in each row's haystack, so they cost nothing.
--
-- The JSON for the page is built BY HAND here rather than with
-- hs.json.encode: the encoder escapes `</` as well (a raw "</script>"
-- inside a clipboard entry would end the page's script tag mid-data),
-- and hand-building keeps this testable under plain Lua with no hs.

local M = {
    name  = "Unified Search",
    order = 14.4,
    cheatsheet = {
        title = "🔎 UNIFIED SEARCH (⇪space — everything, one search)",
        entries = {
            { "⇪space",  "Search EVERY store: clipboard · commands · screenshots · notes · Asana · OCR · docs · file moves · pad" },
            { "⇪⇧space", "Same panel opened as the BIG-thumbnail screenshot browser (@shots)" },
            { "type",    "Every word must match · a @tag word pins one source (@clip @cmd @shots @note @asana @ocr @doc @file @pad)" },
            { "⏎",       "COPY the row — text rows their full text, screenshot rows the image" },
            { "⌘⏎",      "Copy the file PATH instead (rows that have one)" },
            { "↑↓ · click", "Move the selection · pick — 19px rows, 84px thumbnails" },
            { "drag",    "The header bar moves the panel (⌘-drag works anywhere on it)" },
            { "Esc",     "Close" },
        },
    },
}

function M.setup(core)
    local uni = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    uni.enabled = true
    uni.key     = "space"    -- ⇪space search · ⇪⇧space = screenshots view
    uni.width, uni.height = 840, 700
    uni.thumbH  = 84         -- px — a chooser row renders ≈40; this is >2×
    uni.preview = 240        -- characters of each row shown / searched
    uni.pageCap = 60         -- rows the page lists at once ("+N more" after)
    uni.groupCap = 8         -- rows per source in the nothing-typed view
    uni.maxPer  = { clip = 400, cmd = 400, shots = 30, note = 120,
                    asana = 200, ocr = 200, doc = 200, file = 200, pad = 60 }
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

    local function srcDocs(add)
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
        local added = 0
        for i = #collected, 1, -1 do
            local c = collected[i]
            add{ tag = "doc", icon = "📄", src = "Document",
                 text = oneLine(c[3]):sub(1, uni.preview),
                 sub  = c[1] .. " " .. (c[2] or "")
                        .. ((c[4] and c[4] ~= "") and (" · worked " .. c[4]) or ""),
                 full = c[3] }
            added = added + 1
            if added >= uni.maxPer.doc then break end
        end
    end

    local function srcFiles(add)
        local content = tailRead((core.logsDir or "") .. "/file_changes-"
                                 .. tostring(core.hostTag) .. ".csv", 256 * 1024)
        if not content then return end
        local collected = {}
        for line in content:gmatch("[^\r\n]+") do
            local c = csvSplit(line)
            -- fileName,newName,presentLoc,movedLoc,timestamp,event — the
            -- header row and any half-written line fail this shape check.
            if c[6] and c[6] ~= "" and c[1] and c[1] ~= ""
               and c[5] and c[5]:match("%d") then
                collected[#collected + 1] = c
            end
        end
        local added = 0
        for i = #collected, 1, -1 do
            local c = collected[i]
            local fileName, newName = c[1], c[2] or ""
            local loc = (c[4] and c[4] ~= "") and c[4] or (c[3] or "")
            local label = (newName ~= "" and newName ~= fileName)
                          and (fileName .. " → " .. newName) or fileName
            local path = loc ~= ""
                         and (loc .. "/" .. (newName ~= "" and newName or fileName))
                         or nil
            add{ tag = "file", icon = "📁", src = "File move",
                 text = oneLine(label):sub(1, uni.preview),
                 sub  = (c[6] or "") .. " · " .. (c[5] or ""),
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
<input id="q" placeholder="Search everything — every word must match · @clip @cmd @shots @note @asana @ocr @doc @file @pad">
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
              esc(SRCS[s].label) + ' — ' + SRCS[s].n + '</div>';
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
    end

    -- Draggable like everything else — ⌘-drag anywhere on it, and the
    -- header's bare drag arrives through the dragStart message above.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "unified search",
        frame = function() return uni.webview and uni.webview:frame() end,
        move  = function(x, y)
            local f = uni.webview and uni.webview:frame()
            if f then uni.webview:frame({ x = x, y = y, w = f.w, h = f.h }) end
        end,
    })

    core.provide("unified.show", function(prefill) return uni.show(prefill) end)

    _G.unifiedSearch = uni
    M.uni    = uni
    M.config = uni
end

return M
