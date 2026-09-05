-- =====================================================================
-- 📝 SCRATCH PAD — ⇪1: TABS, SAVED AS YOU TYPE, A HISTORY YOU CAN SEARCH
-- =====================================================================
-- 6.164.0 — LL: "I use the Sublime text editor to hold snippets of text
-- or code or anything you can think of as a scratch space. But it's
-- overkill. What I need is a very simple text editor that I can quickly
-- bring up using the shortcut key, type into it, have it automatically
-- saved so I don't lose any of that data, write that data to a
-- searchable database, be able to close it as fast as I can open it …
-- a running history under the main text editor area … open tabs as I
-- need more scratch space … automatically save every few milliseconds
-- … at the end of my workday, 4 PM, an Asana task should be created with
-- the contents … start time of 7:30 AM and an end time of 4 PM, make me
-- the assignee, post to my personal Asana project like any other task …
-- this tool must not lock up my keyboard or the operating system and
-- should degrade gracefully."
--
-- WHAT IT IS. One borderless webview (the Capture Pad / Task Form
-- recipe: allowTextEntry, read-back-verified non-activating mask, held
-- usercontent port, Lua-driven header drag). Inside it: a tab bar, a
-- textarea, and under the textarea a HISTORY strip — every tab you
-- closed, newest first, with a filter box. Click a history row and it
-- comes back as a tab.
--
-- WHERE THE TEXT LIVES. Three places, in this order of truth:
--   1. sp.tabs in Lua — updated on EVERY keystroke (the page posts the
--      whole textarea on each input event; the bridge is cheap and the
--      draft can never be newer than Lua's copy by more than one key).
--   2. <logsDir>/scratch/scratch.json — written sp.saveDelay seconds
--      after the last keystroke (a held hs.timer.doAfter, re-armed per
--      key), and at once on close, tab close, restore and the 4 PM send.
--      "Every few milliseconds" is met by (1); (2) keeps a plist-storm
--      off the disk — the same lesson as unified search's position key.
--   3. ⇪space — unified_search reads sp.tabs and sp.history live, so the
--      whole store is searchable from the one search everything uses.
--
-- 4 PM. sp.send() builds ONE task for the day: every open tab with text
-- under its title, then anything closed today. start 07:30 · due 16:00
-- (both on today), assignee "me", the personal project — all through
-- _G.asanaSubmitTask, the single submit path the ⇪T form uses, so this
-- module owns no Asana request of its own. The identifying comment goes
-- through the same auto-comment hook (extra.comment, 6.164.0). A day
-- with no text, or whose text has not changed since the last send, is
-- skipped and says so in the Console.
--
-- 📌 PIN. The header's pin keeps the pad up while you work in the app
-- beside it: Esc no longer closes it (it only returns the keyboard),
-- and it stays on every Space above the app. ⇪1 and ✕ always close.
-- No window is tracked, no Accessibility is read: nothing here can stall.
--
-- 🚨 WHAT THIS MODULE DELIBERATELY DOES NOT DO. No eventtap (the page's
-- own keydown handles ⌘T/⌘W/⌘1–9/Esc, so nothing can swallow a key
-- system-wide). No AX or window-object reads. No timer that is not held. No
-- write bigger than the store, and that store is registered with the
-- write ledger. Without a webview it falls back to hs.dialog and still
-- saves. Without Asana it still saves — the 4 PM send says "Asana is
-- off on this Mac" and keeps everything.
-- =====================================================================

local M = {
    name    = "Scratch Pad",
    order   = 13.37,
    family  = "capture",
    summary = "⇪1 a scratch editor: tabs, saved as you type, a searchable "
              .. "history under the text, one Asana task of the day at 4 PM",
    cheatsheet = {
        title = "📝 SCRATCH PAD (⇪1 — type, it saves; close as fast as you opened it)",
        entries = {
            { "⇪1",        "Open / close the pad (tabs, text, history under it)" },
            { "⌘T · ⌘W",   "New tab · close tab (its text goes to the history)" },
            { "⌘1…⌘9",     "Switch tab" },
            { "history",   "Under the text: every closed tab, filter box, click to reopen" },
            { "📌",        "Pin: stays up beside the app; Esc only hands the keys back" },
            { "16:00",     "One Asana task of the day: every tab, 07:30 → 16:00, you" },
            { "search",    "⇪space finds everything in the pad — tabs and history" },
            { "Console",   "_G.scratchPadReport() · _G.scratchPadSend()" },
        },
    },
}

function M.setup(core)
    local sp = {
        enabled       = true,
        key           = "1",
        width         = 720,
        height        = 540,
        saveDelay     = 0.3,      -- seconds after the last key before the disk write
        historyRows   = 200,      -- rows embedded in the page for the filter
        historyKeep   = 2000,     -- rows kept in the store (oldest drop past this)
        maxTabs       = 12,
        titleChars    = 40,
        previewChars  = 120,
        focusOnOpen   = true,
        nonActivating = true,
        pinned        = false,

        -- the 4 PM task
        sendAt        = "16:00",
        startTime     = "07:30",
        dueTime       = "16:00",
        assignee      = "me",
        titlePrefix   = "Scratch pad · ",
        comment       = "Sent by Hammerspoon Scratch Pad \"⇪1\", file init.lua",
        sendOnlyIfChanged = true,

        -- state
        tabs = {}, active = nil, history = {}, sent = {},
        webview = nil, uc = nil, saveTimer = nil, sendTimer = nil,
        dragTimer = nil, dragOffset = nil,
        dirty = false, saves = 0, lastSaveErr = nil, lastSend = nil,
        opens = 0, nonActivatingApplied = false, nonActivatingWhy = "not requested",
        caret = 0, filter = "",
    }
    M.config = sp
    _G.scratchPad = sp

    local function say(m)
        if _G.diag and _G.diag.say then _G.diag.say("scratchPad", m) end
    end
    local function warn(m)
        if _G.diag and _G.diag.warn then _G.diag.warn("scratchPad", m) end
    end

    sp.dir  = (core.logsDir or core.homeDir or ".") .. "/scratch"
    sp.file = sp.dir .. "/scratch.json"
    _G.rewrittenFiles = _G.rewrittenFiles or {}
    _G.rewrittenFiles[sp.file] = "the ⇪1 scratch pad — rewritten after every edit"

    -- ---- small helpers ----------------------------------------------------
    local counter = 0
    local function newId()
        counter = counter + 1
        return tostring(os.time()) .. "-" .. counter
    end
    local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    local function oneLine(s) return (tostring(s or ""):gsub("%s+", " ")) end

    function sp.titleOf(tab)
        local first = tostring(tab.text or ""):match("[^\r\n]*") or ""
        first = trim(first)
        if first == "" then return "Untitled" end
        if #first > sp.titleChars then first = first:sub(1, sp.titleChars - 1) .. "…" end
        return first
    end

    function sp.findTab(id)
        for i, t in ipairs(sp.tabs) do if t.id == id then return t, i end end
        return nil
    end
    function sp.activeTab()
        local t = sp.active and sp.findTab(sp.active)
        if not t then t = sp.tabs[1]; sp.active = t and t.id end
        return t
    end

    -- ---- the store ----------------------------------------------------------
    local function ensureDir()
        if type(hs.fs) == "table" and hs.fs.mkdir then
            pcall(hs.fs.mkdir, sp.dir)
        else
            pcall(os.execute, "mkdir -p '" .. sp.dir:gsub("'", "'\\''") .. "'")
        end
    end

    function sp.load()
        local f = io.open(sp.file, "r")
        if not f then return false end
        local blob = f:read("a"); f:close()
        local ok, data = pcall(hs.json.decode, blob)
        if not (ok and type(data) == "table") then
            warn("store unreadable — starting empty (the file is left in place)")
            sp.lastSaveErr = "unreadable"
            return false
        end
        sp.tabs    = type(data.tabs) == "table" and data.tabs or {}
        sp.history = type(data.history) == "table" and data.history or {}
        sp.sent    = type(data.sent) == "table" and data.sent or {}
        sp.active  = data.active
        sp.pinned  = data.pinned == true
        return true
    end

    -- Written whole, to a sibling first, then renamed over: a crash
    -- mid-write can only ever lose the write, never the store.
    function sp.saveNow()
        if sp.saveTimer then pcall(function() sp.saveTimer:stop() end); sp.saveTimer = nil end
        ensureDir()
        local okE, blob = pcall(hs.json.encode, {
            tabs = sp.tabs, history = sp.history, sent = sp.sent,
            active = sp.active, pinned = sp.pinned, savedAt = os.time(),
        }, true)
        if not (okE and type(blob) == "string") then
            sp.lastSaveErr = "encode failed"
            warn("store not written — encode failed")
            return false
        end
        local tmp = sp.file .. ".tmp"
        local f = io.open(tmp, "w")
        if not f then
            sp.lastSaveErr = "cannot open " .. tmp
            if core.warnWriteFailed then core.warnWriteFailed("scratch pad store") end
            return false
        end
        local okW = f:write(blob)
        f:close()
        if not okW then
            sp.lastSaveErr = "write failed"
            if core.warnWriteFailed then core.warnWriteFailed("scratch pad store") end
            return false
        end
        local okR = os.rename(tmp, sp.file)
        if not okR then
            sp.lastSaveErr = "rename failed"
            if core.warnWriteFailed then core.warnWriteFailed("scratch pad store") end
            return false
        end
        sp.dirty, sp.lastSaveErr = false, nil
        sp.saves = sp.saves + 1
        return true
    end

    -- Every keystroke lands here; the disk write waits sp.saveDelay after
    -- the LAST one. The timer is HELD in sp.saveTimer (test_diagnostics).
    function sp.scheduleSave()
        sp.dirty = true
        if sp.saveTimer then pcall(function() sp.saveTimer:stop() end) end
        local ok, t = pcall(hs.timer.doAfter, sp.saveDelay, function()
            sp.saveTimer = nil
            sp.saveNow()
        end)
        sp.saveTimer = ok and t or nil
        if not ok then sp.saveNow() end
    end

    -- ---- tabs ---------------------------------------------------------------
    function sp.newTab(text)
        if #sp.tabs >= sp.maxTabs then
            pcall(function() hs.alert.show("📝 " .. sp.maxTabs .. " tabs already — close one (⌘W)", 2) end)
            return nil
        end
        local t = { id = newId(), text = tostring(text or ""), createdAt = os.time(), updatedAt = os.time() }
        sp.tabs[#sp.tabs + 1] = t
        sp.active = t.id
        sp.scheduleSave()
        return t
    end

    function sp.setText(id, text)
        local t = sp.findTab(id)
        if not t then return false end
        text = tostring(text or "")
        if t.text ~= text then
            t.text, t.updatedAt = text, os.time()
            sp.scheduleSave()
        end
        return true
    end

    -- A closed tab with text becomes the newest history row; an empty
    -- one simply goes. The last tab closing leaves one blank tab.
    function sp.closeTab(id)
        local t, i = sp.findTab(id)
        if not t then return false end
        table.remove(sp.tabs, i)
        if trim(t.text) ~= "" then
            table.insert(sp.history, 1, {
                id = t.id, text = t.text, title = sp.titleOf(t),
                createdAt = t.createdAt, closedAt = os.time(),
            })
            while #sp.history > sp.historyKeep do table.remove(sp.history) end
        end
        if #sp.tabs == 0 then sp.newTab("") end
        if sp.active == id then sp.active = sp.tabs[math.min(i, #sp.tabs)].id end
        sp.saveNow()
        return true
    end

    function sp.restore(id)
        for i, h in ipairs(sp.history) do
            if h.id == id then
                local t = sp.newTab(h.text)
                if not t then return false end
                t.createdAt = h.createdAt or t.createdAt
                table.remove(sp.history, i)
                sp.saveNow()
                return true
            end
        end
        return false
    end

    -- ---- the 4 PM task --------------------------------------------------------
    local function checksum(s)
        local h = #s
        for i = 1, #s, 7 do h = (h * 31 + s:byte(i)) % 2147483647 end
        return tostring(h)
    end

    -- (title, notes, count) — every open tab with text, then today's closed
    -- rows. nil when there is nothing to send.
    function sp.dayBody(today)
        today = today or os.date("%Y-%m-%d")
        local parts, n = {}, 0
        for _, t in ipairs(sp.tabs) do
            if trim(t.text) ~= "" then
                n = n + 1
                parts[#parts + 1] = "## " .. sp.titleOf(t) .. "\n" .. trim(t.text)
            end
        end
        for _, h in ipairs(sp.history) do
            if os.date("%Y-%m-%d", h.closedAt or 0) == today and trim(h.text) ~= "" then
                n = n + 1
                parts[#parts + 1] = "## " .. (h.title or "Untitled") .. " (closed "
                    .. os.date("%H:%M", h.closedAt or 0) .. ")\n" .. trim(h.text)
            end
        end
        if n == 0 then return nil end
        local title = sp.titlePrefix .. os.date("%a %b %d", os.time())
        return title, table.concat(parts, "\n\n"), n
    end

    function sp.send(reason)
        reason = reason or "manual"
        local today = os.date("%Y-%m-%d")
        local title, notes, n = sp.dayBody(today)
        if not title then
            sp.lastSend = { at = os.time(), reason = reason, outcome = "nothing to send" }
            say(sp.sendAt .. " send skipped — nothing written today")
            return false, "nothing to send"
        end
        local sum = checksum(notes)
        if sp.sendOnlyIfChanged and sp.sent[today] == sum then
            sp.lastSend = { at = os.time(), reason = reason, outcome = "unchanged since the last send" }
            say(sp.sendAt .. " send skipped — unchanged since the last send")
            return false, "unchanged"
        end
        if not (core.asanaEnabled and _G.asanaSubmitTask) then
            sp.lastSend = { at = os.time(), reason = reason, outcome = "Asana is off on this Mac" }
            print("📝 Scratch Pad: " .. sp.sendAt .. " task not sent — Asana is off on this Mac "
                  .. "(secret.lua); the text is safe in " .. sp.file)
            return false, "asana off"
        end
        local ok, accepted = pcall(_G.asanaSubmitTask, title, notes, sp.assignee, "", {
            startDate = today, startTime = sp.startTime,
            dueDate   = today, dueTime   = sp.dueTime,
            comment   = sp.comment,
        })
        if ok and accepted then
            sp.sent[today] = sum
            sp.lastSend = { at = os.time(), reason = reason, outcome = "sent · " .. n .. " section"
                            .. (n == 1 and "" or "s"), title = title }
            sp.saveNow()
            say("task sent — " .. title)
            return true, title
        end
        sp.lastSend = { at = os.time(), reason = reason,
                        outcome = "rejected — " .. tostring(ok and "validation" or accepted) }
        warn("task not accepted (" .. tostring(ok and "validation failed" or accepted) .. ")")
        return false, "rejected"
    end
    _G.scratchPadSend = function() return sp.send("manual") end

    -- ---- the page -------------------------------------------------------------
    local function escapeHtml(s)
        return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;")
                :gsub(">", "&gt;"):gsub('"', "&quot;"))
    end
    local function jstr(s)
        s = tostring(s or "")
        s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "")
             :gsub("</", "<\\/")
        return '"' .. s .. '"'
    end

    function sp.historyJson()
        local rows = {}
        for i = 1, math.min(#sp.history, sp.historyRows) do
            local h = sp.history[i]
            rows[#rows + 1] = "{id:" .. jstr(h.id) .. ",t:" .. jstr(h.title or "Untitled")
                .. ",w:" .. jstr(os.date("%b %d %H:%M", h.closedAt or 0))
                .. ",p:" .. jstr(oneLine(h.text):sub(1, sp.previewChars)) .. "}"
        end
        return "[" .. table.concat(rows, ",") .. "]"
    end

    function sp.buildHtml()
        local cur = sp.activeTab() or sp.newTab("")
        local tabsHtml = {}
        for i, t in ipairs(sp.tabs) do
            tabsHtml[#tabsHtml + 1] = '<div class="tab' .. (t.id == cur.id and " on" or "")
                .. '" data-id="' .. escapeHtml(t.id) .. '"><span class="tt">'
                .. escapeHtml(sp.titleOf(t)) .. '</span><span class="x" title="Close ⌘W">×</span></div>'
        end
        local theme = (_G.uiStyle and _G.uiStyle.cssOverride and _G.uiStyle.cssOverride()) or ""
        return [[<!doctype html><html><head><meta charset="utf-8"><style>
:root{color-scheme:dark}
html,body{margin:0;height:100%;background:#141418;color:#e8e8ec;font-family:-apple-system,Helvetica,sans-serif;font-size:13px;overflow:hidden}
#wrap{display:flex;flex-direction:column;height:100%}
header{display:flex;align-items:center;gap:8px;padding:6px 10px;background:#1c1c22;cursor:grab;user-select:none;-webkit-user-select:none}
header.dragging{cursor:grabbing}
header .grip{opacity:.5}
header .name{font-weight:600;flex:1}
header .hint{opacity:.55;font-size:11px}
header button{background:#2a2a33;color:#e8e8ec;border:0;border-radius:6px;padding:3px 8px;font-size:12px;cursor:pointer}
header button.pin.on{background:#4a7fe0;color:#fff}
#tabs{display:flex;gap:4px;padding:6px 8px 0;background:#18181d;overflow-x:auto}
.tab{display:flex;align-items:center;gap:6px;padding:4px 8px;border-radius:6px 6px 0 0;background:#202027;max-width:180px;cursor:default}
.tab.on{background:#2b2b35}
.tab .tt{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tab .x{opacity:.5;cursor:pointer;padding:0 2px}
.tab .x:hover{opacity:1}
.tab.add{padding:4px 10px;opacity:.7;cursor:pointer}
textarea{flex:1;margin:0;padding:10px;border:0;outline:0;resize:none;background:#141418;color:#e8e8ec;
  font-family:Menlo,monospace;font-size:13px;line-height:1.45;font-weight:normal;font-style:normal}
#hist{height:34%;min-height:96px;display:flex;flex-direction:column;border-top:1px solid #2a2a33;background:#17171c}
#hist .bar{display:flex;align-items:center;gap:8px;padding:5px 10px}
#hist .bar .lab{opacity:.6;font-size:11px;letter-spacing:.04em}
#hist input{flex:1;background:#202027;border:1px solid #2a2a33;border-radius:6px;color:#e8e8ec;padding:3px 8px;font-size:12px;outline:0}
#hist input:focus{border-color:#4a7fe0}
#rows{overflow-y:auto;flex:1}
.row{display:flex;gap:10px;padding:4px 10px;cursor:pointer;border-bottom:1px solid #1f1f26}
.row:hover{background:#202027}
.row .w{opacity:.5;white-space:nowrap;font-size:11px;min-width:86px}
.row .t{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:40%}
.row .p{opacity:.65;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;flex:1}
.empty{opacity:.45;padding:8px 10px;font-size:12px}
]] .. theme .. [[</style></head><body><div id="wrap">
<header id="bar"><span class="grip">⠿</span><span class="name">📝 Scratch Pad</span>
<span class="hint">⌘T new · ⌘W close · ⌘1–9 switch · Esc</span>
<button class="pin]] .. (sp.pinned and " on" or "") .. [[" id="pin" title="Pin: stays up beside the app">📌</button>
<button id="send" title="Send today's text to Asana now">Asana</button>
<button id="close" title="Close (⇪1)">✕</button></header>
<div id="tabs">]] .. table.concat(tabsHtml) .. [[<div class="tab add" id="add" title="New tab ⌘T">+</div></div>
<textarea id="t" spellcheck="false" autofocus>]] .. escapeHtml(cur.text) .. [[</textarea>
<div id="hist"><div class="bar"><span class="lab">HISTORY</span><input id="q" placeholder="filter closed tabs…" value="]] .. escapeHtml(sp.filter) .. [["><span class="lab" id="cnt"></span></div><div id="rows"></div></div>
</div><script>
var ROWS = ]] .. sp.historyJson() .. [[;
var t = document.getElementById('t'), q = document.getElementById('q');
var ACTIVE = ]] .. jstr(cur.id) .. [[;
var CARET = ]] .. tostring(tonumber(sp.caret) or 0) .. [[;
function say(m){ m.text = t.value; m.sel = t.selectionStart; m.id = ACTIVE;
  try { window.webkit.messageHandlers.scratchPad.postMessage(m); } catch(e){} }
function esc(s){ return String(s).replace(/[&<>"]/g, function(c){ return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]; }); }
function draw(){
  var f = q.value.toLowerCase(), out = [], n = 0;
  for (var i = 0; i < ROWS.length; i++) { var r = ROWS[i];
    if (f && (r.t + ' ' + r.p).toLowerCase().indexOf(f) < 0) continue;
    n++; out.push('<div class="row" data-id="' + esc(r.id) + '"><span class="w">' + esc(r.w)
      + '</span><span class="t">' + esc(r.t) + '</span><span class="p">' + esc(r.p) + '</span></div>'); }
  document.getElementById('rows').innerHTML = out.length ? out.join('') :
    '<div class="empty">' + (ROWS.length ? 'nothing matches' : 'closed tabs land here — ⌘W') + '</div>';
  document.getElementById('cnt').textContent = n + ' / ' + ROWS.length;
}
draw();
q.addEventListener('input', function(){ draw(); });
t.addEventListener('input', function(){ say({a:'edit'}); });
document.getElementById('rows').addEventListener('click', function(e){
  var el = e.target.closest('.row'); if (el) say({a:'restore', rid: el.getAttribute('data-id')}); });
document.getElementById('tabs').addEventListener('click', function(e){
  var x = e.target.closest('.x'); var tab = e.target.closest('.tab');
  if (e.target.id === 'add' || (tab && tab.id === 'add')) { say({a:'new'}); return; }
  if (!tab) return;
  if (x) say({a:'close', tid: tab.getAttribute('data-id')});
  else if (tab.getAttribute('data-id') !== ACTIVE) say({a:'switch', tid: tab.getAttribute('data-id')}); });
document.getElementById('pin').addEventListener('click', function(){ say({a:'pin'}); });
document.getElementById('send').addEventListener('click', function(){ say({a:'send'}); });
document.getElementById('close').addEventListener('click', function(){ say({a:'hide'}); });
var hdr = document.getElementById('bar');
hdr.addEventListener('mousedown', function(e){ if (e.button !== 0 || e.target.tagName === 'BUTTON') return;
  e.preventDefault(); hdr.classList.add('dragging'); say({a:'dragStart'}); });
window.addEventListener('mouseup', function(){ hdr.classList.remove('dragging'); });
document.addEventListener('keydown', function(e){
  var meta = e.metaKey || e.ctrlKey;
  if (e.key === 'Escape') { e.preventDefault(); say({a:'esc'}); return; }
  if (meta && (e.key === 't' || e.key === 'T')) { e.preventDefault(); say({a:'new'}); return; }
  if (meta && (e.key === 'w' || e.key === 'W')) { e.preventDefault(); say({a:'close', tid: ACTIVE}); return; }
  if (meta && e.key >= '1' && e.key <= '9') { e.preventDefault(); say({a:'nth', n: e.key}); return; }
  if (meta && (e.key === 'f' || e.key === 'F')) { e.preventDefault(); q.focus(); q.select(); return; }
});
t.focus(); try { t.setSelectionRange(CARET, CARET); } catch(e){}
</script></body></html>]]
    end

    function sp.render()
        if not sp.webview then return end
        pcall(function() sp.webview:html(sp.buildHtml()) end)
    end

    -- ---- messages from the page ----------------------------------------------
    local function handleMessage(body)
        if type(body) ~= "table" then return end
        -- The text rides on EVERY message: whatever the action, the draft
        -- is in Lua before anything else happens.
        if body.id and body.text ~= nil then sp.setText(body.id, body.text) end
        sp.caret = tonumber(body.sel) or 0
        local a = body.a
        if a == "edit" then
            return
        elseif a == "new" then
            if sp.newTab("") then sp.caret = 0; sp.render() end
        elseif a == "close" then
            if sp.closeTab(tostring(body.tid or "")) then sp.caret = 0; sp.render() end
        elseif a == "switch" then
            if sp.findTab(tostring(body.tid or "")) then
                sp.active = tostring(body.tid); sp.caret = 0; sp.scheduleSave(); sp.render()
            end
        elseif a == "nth" then
            local t = sp.tabs[tonumber(body.n) or 0]
            if t and t.id ~= sp.active then sp.active = t.id; sp.caret = 0; sp.scheduleSave(); sp.render() end
        elseif a == "restore" then
            if sp.restore(tostring(body.rid or "")) then sp.caret = 0; sp.render() end
        elseif a == "pin" then
            sp.pinned = not sp.pinned
            sp.saveNow()
            sp.render()
            pcall(function() hs.alert.show(sp.pinned and "📌 Pinned — Esc hands the keys back, ⇪1 closes"
                                           or "📌 Unpinned", 1.5) end)
        elseif a == "send" then
            local ok, why = sp.send("button")
            if not ok then pcall(function() hs.alert.show("📝 Not sent — " .. tostring(why), 2) end) end
        elseif a == "esc" then
            if sp.pinned then sp.blur() else sp.hide() end
        elseif a == "hide" then
            sp.hide()
        elseif a == "dragStart" then
            sp.beginDrag()
        end
    end
    sp.handleMessage = handleMessage   -- exposed for the test suite

    -- ---- dragging (Lua polls the mouse; JS mousemove dies past the edge) ----
    local function mousePosition()
        if type(hs.mouse) ~= "table" then return nil end
        for _, name in ipairs({ "absolutePosition", "getAbsolutePosition" }) do
            local fn = hs.mouse[name]
            if type(fn) == "function" then
                local ok, p = pcall(fn)
                if ok and type(p) == "table" and p.x and p.y then return p end
            end
        end
        return nil
    end
    local function leftButtonDown()
        local ok, btns = pcall(hs.eventtap.checkMouseButtons)
        if not ok or type(btns) ~= "table" then return false end
        return btns.left == true or btns[1] == true
    end
    function sp.endDrag()
        if sp.dragTimer then pcall(function() sp.dragTimer:stop() end); sp.dragTimer = nil end
        sp.dragOffset = nil
    end
    function sp.beginDrag()
        if not sp.webview then return end
        local okF, f = pcall(function() return sp.webview:frame() end)
        if not (okF and type(f) == "table") then return end
        local m = mousePosition()
        if not m then return end
        sp.endDrag()
        sp.dragOffset = { x = m.x - f.x, y = m.y - f.y }
        sp.dragTimer = hs.timer.doEvery(0.016, function()
            if not (sp.webview and sp.dragOffset) then sp.endDrag() return end
            if not leftButtonDown() then sp.endDrag() return end
            local p = mousePosition()
            if not p then sp.endDrag() return end
            pcall(function()
                local cur = sp.webview:frame()
                sp.webview:frame({ x = p.x - sp.dragOffset.x, y = p.y - sp.dragOffset.y,
                                   w = cur.w, h = cur.h })
            end)
        end)
    end

    -- ---- the window -------------------------------------------------------------
    function sp.applyNonActivating(view)
        if not view then return false, "there is no window" end
        local masks = hs.webview and hs.webview.windowMasks
        local bit   = type(masks) == "table" and masks.nonactivating or nil
        if type(bit) ~= "number" or bit < 1 then
            return false, "this Hammerspoon has no nonactivating window mask"
        end
        local function isSet(v) return (math.floor(v / bit) % 2) == 1 end
        local okGet, cur = pcall(function() return view:windowStyle() end)
        if not (okGet and type(cur) == "number") then return false, "the window style could not be read" end
        if not isSet(cur) then
            local okSet = pcall(function() view:windowStyle(cur + bit) end)
            if not okSet then return false, "the window style was rejected" end
        end
        local okRe, now = pcall(function() return view:windowStyle() end)
        if not (okRe and type(now) == "number") then return false, "the window style could not be read back" end
        if not isSet(now) then return false, "macOS dropped the mask" end
        return true, "applied"
    end

    function sp.isOpen() return sp.webview ~= nil end

    -- Pinned + Esc: the pad stays; the keyboard goes back to the app.
    -- Hiding and re-showing the same window is the only focus hand-off a
    -- non-activating panel has that touches no other app's windows.
    function sp.blur()
        if not sp.webview then return end
        pcall(function() sp.webview:hide() end)
        pcall(function() sp.webview:show() end)
    end

    function sp.hide()
        sp.endDrag()
        if sp.webview then
            pcall(function() sp.webview:delete() end)
            sp.webview = nil
        end
        sp.uc = nil
        if sp.dirty then sp.saveNow() end
        say("pad closed")
    end

    -- No webview must not mean no scratch space: the plain prompt edits
    -- the active tab and saves it the same way.
    local function promptFallback()
        local cur = sp.activeTab() or sp.newTab("")
        local okP, button, typed = pcall(hs.dialog.textPrompt, "Scratch Pad",
            "No web view on this Hammerspoon — this box edits the current tab.",
            cur.text or "", "Save", "Cancel")
        if not okP or button ~= "Save" then return end
        sp.setText(cur.id, typed)
        sp.saveNow()
    end

    function sp.show()
        if not sp.enabled then return end
        if sp.webview then sp.hide() return end
        if not (hs.webview and hs.webview.usercontent) then promptFallback() return end
        if #sp.tabs == 0 then sp.newTab("") end

        local screen = hs.screen.mainScreen and hs.screen.mainScreen()
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(sp.width, sf.w - 40)
        local h = math.min(sp.height, sf.h - 40)
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 3, w = w, h = h }
        if sp.pos and _G.clampToScreen then
            local okC, p = pcall(_G.clampToScreen, sp.pos, w, h)
            if okC and type(p) == "table" then rect.x, rect.y = p.x, p.y end
        end

        local okUc, uc = pcall(hs.webview.usercontent.new, "scratchPad")
        if not (okUc and uc) then promptFallback() return end
        sp.uc = uc     -- HELD: collect this and the JS bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then print("📝 Scratch Pad: message handler — " .. tostring(err)) end
            end)
        end)
        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then sp.uc = nil; promptFallback() return end
        sp.webview = view
        pcall(function() view:windowTitle("Scratch Pad") end)
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:closeOnEscape(false) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pcall(function() view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
        sp.nonActivatingApplied, sp.nonActivatingWhy = false, "not requested"
        if sp.nonActivating then
            sp.nonActivatingApplied, sp.nonActivatingWhy = sp.applyNonActivating(view)
            if not sp.nonActivatingApplied then
                print("📝 Scratch Pad: non-activating panel unavailable — "
                      .. tostring(sp.nonActivatingWhy) .. "; opening the pad will bring Hammerspoon forward.")
            end
        end
        sp.render()
        pcall(function() view:show() end)
        if sp.focusOnOpen then pcall(function() view:bringToFront(true) end) end
        sp.opens = sp.opens + 1
        say("pad opened — " .. #sp.tabs .. " tab" .. (#sp.tabs == 1 and "" or "s"))
    end
    sp.toggle = sp.show

    -- ---- registrations ------------------------------------------------------------
    sp.load()
    if #sp.tabs == 0 then sp.tabs = { { id = newId(), text = "", createdAt = os.time(), updatedAt = os.time() } }; sp.active = sp.tabs[1].id end

    core.hyperAddShortcut({}, sp.key, function() sp.toggle() end, "scratch pad")

    if _G.claimEscape then
        _G.claimEscape("scratchpad", nil, function() return sp.webview ~= nil and not sp.pinned end,
                       function() sp.hide() end)
    end

    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "scratch pad",
        frame = function() return sp.webview and sp.webview:frame() end,
        move  = function(x, y)
            if not sp.webview then return end
            local f = sp.webview:frame()
            sp.webview:frame({ x = x, y = y, w = f.w, h = f.h })
            sp.pos = { x = x, y = y }
        end,
    })

    _G.editors = _G.editors or {}
    table.insert(_G.editors, {
        name  = "Scratch Pad",
        key   = "⇪" .. sp.key,
        what  = "tabs saved as you type; one Asana task at 4 PM",
        order = 22,
        view  = function() return sp.webview end,
        show  = function() if not sp.webview then sp.show() end end,
        size  = function() local t = sp.activeTab(); return t and #(t.text or "") or 0 end,
        text  = function() local t = sp.activeTab(); return t and t.text or "" end,
    })

    core.provide("scratch.show",   function() sp.show() return true end)
    core.provide("scratch.send",   function() return sp.send("service") end)
    core.provide("scratch.report", function() return _G.scratchPadReport() end)

    function _G.scratchPadReport()
        local L = {}
        L[#L + 1] = "📝 Scratch Pad — ⇪" .. sp.key .. (sp.enabled and "" or " (disabled)")
        L[#L + 1] = "   store: " .. sp.file .. (sp.lastSaveErr and ("  ⚠️ " .. sp.lastSaveErr) or "")
        L[#L + 1] = "   tabs: " .. #sp.tabs .. " · history: " .. #sp.history
                    .. " · saves: " .. sp.saves .. (sp.dirty and " · unsaved keystrokes pending" or "")
        L[#L + 1] = "   pad: " .. (sp.webview and "open" or "closed") .. (sp.pinned and " · 📌 pinned" or "")
                    .. " · opens: " .. sp.opens .. " · non-activating: " .. tostring(sp.nonActivatingWhy)
        L[#L + 1] = "   4 PM: at " .. sp.sendAt .. " · " .. sp.startTime .. " → " .. sp.dueTime
                    .. " · assignee " .. sp.assignee .. " · "
                    .. (sp.sendTimer and "armed" or "NOT armed")
                    .. " · Asana " .. (core.asanaEnabled and "on" or "off on this Mac")
        if sp.lastSend then
            L[#L + 1] = "   last send: " .. os.date("%b %d %H:%M", sp.lastSend.at) .. " (" .. sp.lastSend.reason
                        .. ") — " .. sp.lastSend.outcome
        else
            L[#L + 1] = "   last send: never this session"
        end
        local out = table.concat(L, "\n")
        print(out)
        return out
    end
end

function M.warm(core)
    local sp = M.config
    if not sp then return end
    local ok, t = pcall(hs.timer.doAt, sp.sendAt, "1d", function() pcall(sp.send, "scheduled") end)
    if ok and t then sp.sendTimer = t     -- HELD
    else
        print("📝 Scratch Pad: the " .. sp.sendAt .. " send is not armed — " .. tostring(t))
        if _G.notices and _G.notices.record then
            pcall(_G.notices.record, "scratch", "the 4 PM task is not armed", tostring(t))
        end
    end
end

return M
