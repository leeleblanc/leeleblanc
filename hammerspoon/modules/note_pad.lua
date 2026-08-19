-- =====================================================================
-- MODULE: QUICK APPEND PAD (⇪2 · ⇪pad2) — one box, four destinations
-- =====================================================================
-- LL: "Can you combine the Capture Pad features & the Quick Append" —
-- so this window is the COMBINATION: it looks and feels like the
-- Capture Pad (same dark card, drag header, ⌘⏎), but every LINE you
-- type is routed by its PREFIX, and the two systems meet in one box:
--
--      * idea text     →  an Idea    (ideas.txt + a notes.csv row)
--      + log text      →  a Log      (log.txt   + a notes.csv row)
--      ! task text     →  an Asana TASK, via the Capture Pad queue
--      ? note text     →  an Asana note, same queue
--      no prefix       →  a Log — "if you can't tell, make it a Log"
--
-- ! and ? are the Capture Pad's OWN prefixes; lines carrying them are
-- handed to its queue verbatim, so its title rules, 16:00 send, retry
-- and parking all apply unchanged. This module never grows a second
-- Asana path — ⇪N still exists for image attachments and the queue UI.
--
-- A line that starts a prefix starts a NEW entry; lines without one
-- CONTINUE the entry above (so a two-line idea stays one idea). One
-- box can therefore hold a day's worth of entries at once.
--
-- 🚪 CLOSING FILES EVERYTHING. LL: "On each close of the Quick Append
-- Pad, the entries are written into the file." Esc, ⌘⏎, even the pad
-- being reopened by another key — every close routes whatever is in
-- the box. There is no way to lose a note by putting the window away;
-- the only entries not written are the ones that failed, and those
-- say so and stay in the draft.
--
-- ⏰ 16:01 REVIEW. Every day, one minute after the Capture Pad's 16:00
-- Asana send, this pad opens itself with TODAY'S notes.csv entries
-- listed and asks the question LL asked for: should any of these be
-- turned into a task? One click sends an entry into the Capture Pad
-- queue (prefixed !), where the normal machinery takes it from there.
-- Days with no entries get a two-second alert instead of a window.
--
-- WHY A SEPARATE MODULE AND NOT MORE quick_append. quick_append's whole
-- identity is "nothing opens, nothing takes focus" — the fast path. An
-- editor window is the deliberate path. This file knows nothing about
-- io.open: finished entries go to the published notes.append and
-- capturePad.add services, and each service's verdict is relayed.
--
-- THE WINDOW RULES ARE ALL INHERITED FROM THE CAPTURE PAD, deliberately:
-- non-activating panel (typing must not drag Hammerspoon forward),
-- canJoinAllSpaces + fullScreenAuxiliary (must appear over full-screen
-- apps), allowTextEntry (a webview swallows keystrokes without it), the
-- Lua-driven header drag (a WKWebView loses the mouse the moment the
-- pointer leaves it), and say() attaching the live textarea to EVERY
-- message (the 6.44.7 lesson: a button that forgets the text wipes the
-- draft). Where those notes are load-bearing they are repeated at the
-- code; the full histories live in capture_pad.lua.

local M = {
    name  = "Quick Append Pad",
    order = 13.35,
    family = "capture",       -- between Quick Append (13.3), whose files it
                         -- writes, and the numpad layer (13.5) that keys it
    cheatsheet = {
        title = "🗒 QUICK APPEND PAD (⇪2 or ⇪pad2 — one box, four destinations)",
        entries = {
            -- 🔤 6.114.0 — ⇪pad2 AND ⇪pad* NO LONGER APPEAR AS KEY CELLS HERE.
            -- numpad_layer BINDS every pad key, so under the 6.102.0 rule
            -- (one owner per ⇪ key) its layer map is where those rows live;
            -- having them in both groups put one shortcut on the sheet twice
            -- and gave ⇪space two rows for one tool. The keys are unchanged
            -- and still documented — one group over.
            { "⇪2",    "Open the pad — type entries, one per line" },
            { "* …",   "The line is an IDEA → ideas.txt + the CSV" },
            { "+ …",   "The line is a LOG → log.txt + the CSV" },
            { "! …",   "The line is an Asana TASK → the Capture Pad queue" },
            { "? …",   "The line is an Asana note → the same queue" },
            { "plain",  "No prefix = a Log. A line without a prefix continues the entry above" },
            { "close",  "⌘⏎ or Esc — CLOSING FILES EVERYTHING; failures stay in the box" },
            { "⌘⇧V",   "Insert the clipboard into the box" },
            { "16:01",  "The pad opens with today's notes — one click turns one into a task" },
            { "pre-typed", "⇪pad* opens it with * (an Idea) · ⇪pad- with + (a Log)" },
            { "no pad?",   "⇪2 opens it · ⇪space finds both pre-typed doors too" },
        },
    },
}

function M.setup(core)
    local np = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    np.enabled       = true
    np.width, np.height = 640, 380
    np.focusOnOpen   = true    -- take the keyboard on open, so typing starts
    np.nonActivating = true    -- ask for the panel that types WITHOUT
                               -- pulling Hammerspoon's other windows forward
    np.reviewAt      = "16:01" -- the daily "anything become a task?" open;
                               -- one minute AFTER the Capture Pad's send,
                               -- so today's queue has already gone out
    np.reviewEnabled = true
    -- ----------------------------------------------------------------------

    np.draft       = ""     -- survives close/reopen, lives here not in the DOM
    np.draftCaret  = 0
    np.webview     = nil    -- HELD
    np.uc          = nil    -- HELD: the JS→Lua message port
    np.reviewMode  = false
    np.reviewList  = {}     -- today's CSV entries while reviewing
    np.reviewTimer = nil    -- HELD in warm(): a collected timer never fires

    local function say(m) if _G.diag then _G.diag.say("quickAppendPad", m) end end

    local function escapeHtml(s)
        return (tostring(s or "")
            :gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            :gsub('"', "&quot;"))
    end

    local function hasService(n)
        return _G.service and _G.service.has and _G.service.has(n)
    end

    -- ---- the router ------------------------------------------------------
    -- One box, many entries. A line whose first non-space character is a
    -- prefix STARTS an entry; every following unprefixed line belongs to
    -- it. The first lines of the box, before any prefix appears, are one
    -- unprefixed entry of their own — a Log, per the "can't tell" rule.
    local PREFIX = { ["*"] = "Ideas", ["+"] = "Logs",
                     ["!"] = "task",  ["?"] = "note" }

    function np.parseEntries(text)
        local entries, cur = {}, nil
        for line in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do
            local mark, rest = line:match("^%s*([%*%+!%?])%s?(.*)$")
            if mark then
                cur = { kind = PREFIX[mark], text = rest, mark = mark }
                table.insert(entries, cur)
            elseif cur then
                cur.text = cur.text .. "\n" .. line
            elseif line:gsub("%s+", "") ~= "" then
                cur = { kind = "Logs", text = line, mark = nil }
                table.insert(entries, cur)
            end
        end
        -- An entry that is nothing but whitespace is a prefix key pressed
        -- and abandoned, not a note.
        local kept = {}
        for _, e in ipairs(entries) do
            e.text = e.text:gsub("^%s+", ""):gsub("%s+$", "")
            if e.text ~= "" then table.insert(kept, e) end
        end
        return kept
    end

    -- Routes every entry, returns ok, summary. Failures are collected and
    -- LEFT IN THE DRAFT by the caller, because an entry that failed to
    -- save exists nowhere else.
    function np.fileAll(text)
        local entries = np.parseEntries(text)
        if #entries == 0 then return true, nil, "" end

        local counts = { Ideas = 0, Logs = 0, queued = 0 }
        local failed, failedLines = {}, {}
        for _, e in ipairs(entries) do
            if e.kind == "task" or e.kind == "note" then
                -- The Capture Pad's own prefix rides along verbatim, so
                -- ITS title rules decide task-vs-note exactly as if the
                -- line had been typed into ⇪N.
                local raw = e.mark .. e.text
                if hasService("capturePad.add") then
                    local ok, res = _G.service.call("capturePad.add", raw)
                    if ok then counts.queued = counts.queued + 1
                    else
                        table.insert(failed, tostring(res))
                        table.insert(failedLines, raw)
                    end
                else
                    -- No Capture Pad on this profile: the entry is kept
                    -- as a Log rather than dropped, and the alert says
                    -- the intent was lost — a task silently demoted to a
                    -- note would be worse than a loud one.
                    local ok = hasService("notes.append")
                              and _G.service.call("notes.append", e.text, "Logs")
                    if ok then
                        counts.Logs = counts.Logs + 1
                        table.insert(failed,
                            "Capture Pad not loaded — '" .. e.text:sub(1, 30)
                            .. "…' saved as a Log instead of a task")
                    else
                        table.insert(failed, "Capture Pad not loaded and Logs unavailable")
                        table.insert(failedLines, raw)
                    end
                end
            else
                if hasService("notes.append") then
                    local ok, msg = _G.service.call("notes.append", e.text, e.kind)
                    if ok then counts[e.kind] = counts[e.kind] + 1
                    else
                        table.insert(failed, tostring(msg))
                        table.insert(failedLines, (e.mark or "") .. e.text)
                    end
                else
                    table.insert(failed, "Quick Append is not loaded on this Mac")
                    table.insert(failedLines, (e.mark or "") .. e.text)
                end
            end
        end

        local bits = {}
        if counts.Logs   > 0 then table.insert(bits, counts.Logs .. " Log" .. (counts.Logs == 1 and "" or "s")) end
        if counts.Ideas  > 0 then table.insert(bits, counts.Ideas .. " Idea" .. (counts.Ideas == 1 and "" or "s")) end
        if counts.queued > 0 then table.insert(bits, counts.queued .. " → Asana queue") end
        local summary = "📝 " .. (#bits > 0 and table.concat(bits, " · ") or "nothing written")
        if #failed > 0 then
            summary = summary .. "\n⚠️ " .. failed[1]
                      .. (#failed > 1 and (" (+" .. (#failed - 1) .. " more)") or "")
        end
        return #failed == 0, summary, table.concat(failedLines, "\n")
    end

    -- ---- today's entries, for the 16:01 review ---------------------------
    -- notes.csv quotes commas AND newlines, so this is a real CSV record
    -- reader (a tiny state machine), not a line splitter — a multi-line
    -- note is one record and must review as one.
    function np.csvRecords(text)
        local recs, cur, buf, inQ = {}, {}, {}, false
        local i, n = 1, #tostring(text or "")
        text = tostring(text or "")
        while i <= n do
            local c = text:sub(i, i)
            if inQ then
                if c == '"' then
                    if text:sub(i + 1, i + 1) == '"' then
                        buf[#buf + 1] = '"'; i = i + 1
                    else inQ = false end
                else buf[#buf + 1] = c end
            else
                if c == '"' then inQ = true
                elseif c == "," then
                    cur[#cur + 1] = table.concat(buf); buf = {}
                elseif c == "\n" then
                    cur[#cur + 1] = table.concat(buf); buf = {}
                    if #cur > 1 or cur[1] ~= "" then recs[#recs + 1] = cur end
                    cur = {}
                elseif c ~= "\r" then buf[#buf + 1] = c end
            end
            i = i + 1
        end
        if #buf > 0 or #cur > 0 then
            cur[#cur + 1] = table.concat(buf)
            recs[#recs + 1] = cur
        end
        return recs
    end

    function np.todayEntries()
        local qa = _G.quickAppend
        if not (qa and type(qa.csvPath) == "function") then return {} end
        local f = io.open(qa.csvPath(), "r")
        if not f then return {} end
        local blob = f:read("a") or ""
        f:close()
        local today, out = os.date("%Y-%m-%d"), {}
        for _, r in ipairs(np.csvRecords(blob)) do
            -- r = { Date, Note Type, Note entry }; skip the header and
            -- anything not from today.
            if r[1] and r[1]:sub(1, #today) == today and r[1] ~= "Date" then
                table.insert(out, { at = r[1], kind = r[2] or "Logs",
                                    text = r[3] or "" })
            end
        end
        return out
    end

    -- ---- the page --------------------------------------------------------
    local function firstWords(text, n)
        text = (tostring(text or ""):gsub("%s+", " "):gsub("^%s*", ""))
        if #text <= n then return text end
        return text:sub(1, n - 1) .. "…"
    end

    local function buildHtml()
        local themeCss = (_G.uiStyle and _G.uiStyle.cssOverride
                          and _G.uiStyle.cssOverride()) or ""
        local review = ""
        if np.reviewMode then
            local rows = {}
            for i, e in ipairs(np.reviewList) do
                local kindClass = e.kind == "Ideas" and "idea" or "log"
                table.insert(rows, '<li class="' .. kindClass .. '">'
                    .. '<span class="k">' .. escapeHtml(e.kind) .. '</span>'
                    .. '<span class="t">' .. escapeHtml(firstWords(e.text, 90)) .. '</span>'
                    .. (e.sent
                        and '<span class="sent">→ queued ✓</span>'
                        or ('<button type="button" class="totask" onclick="say({a:\'toTask\', idx:' .. i .. '})">→ Task</button>'))
                    .. '</li>')
            end
            review = '<h2>Today — anything worth turning into a task?</h2>'
                .. (#rows > 0 and ('<ul>' .. table.concat(rows) .. '</ul>')
                               or '<p class="empty">No notes today.</p>')
        end
        return [[
<meta charset="utf-8">
<style>
  :root { color-scheme: dark; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,sans-serif;
         font-size:15px; line-height:1.5; background:#141418; color:#e8e8ec; }
  /* The header IS the title bar — hs.webview windows are borderless. */
  header { padding:12px 18px 8px; display:flex; justify-content:space-between;
           align-items:baseline; border-bottom:1px solid #2a2a32;
           cursor:grab; user-select:none; -webkit-user-select:none; }
  header:active { cursor:grabbing; }
  header.dragging { cursor:grabbing; background:#1b1b22; }
  h1 { font-size:16px; margin:0; font-weight:600; }
  .grip { color:#4a4a56; margin-right:8px; letter-spacing:2px; }
  .hint { color:#8a8a96; font-size:13px; }
  #wrap { padding:12px 18px 16px; }
  #legend { display:flex; gap:14px; flex-wrap:wrap; margin-bottom:8px;
            font-size:13px; color:#8a8a96; }
  #legend b { color:#c8c8d2; font-weight:600; }
  /* Longhand font rules on purpose — the shorthand+keyword mix is the
     invalid combination WebKit drops whole (the 6.44.1 textarea bug). */
  textarea { width:100%; box-sizing:border-box; height:150px; resize:vertical;
             background:#1d1d24; color:#f2f2f6; border:1px solid #33333e;
             border-radius:8px; padding:12px;
             font-family:-apple-system,BlinkMacSystemFont,sans-serif;
             font-size:16px; line-height:1.5; }
  textarea:focus { outline:none; border-color:#4a7fe0; }
  textarea::placeholder { color:#5c5c68; }
  .bar { margin-top:12px; display:flex; gap:10px; align-items:center; flex-wrap:wrap; }
  button { background:#2a2a34; color:#e8e8ec; border:1px solid #3b3b47;
           border-radius:7px; padding:7px 13px; font-size:14px; cursor:pointer; }
  button:hover { filter:brightness(1.18); }
  button.go { background:#3566cc; border-color:#4a7fe0; }
  h2 { font-size:12px; text-transform:uppercase; letter-spacing:.08em;
       color:#7c7c88; margin:20px 0 8px; }
  ul { list-style:none; margin:0; padding:0; }
  li { display:flex; gap:10px; align-items:baseline; padding:8px 10px;
       border-radius:7px; background:#1b1b22; margin-bottom:5px; font-size:14px; }
  .k { font-size:10px; font-weight:700; letter-spacing:.06em; padding:2px 6px;
       border-radius:4px; flex:none; }
  li.idea .k { background:#3a3550; color:#c3b6ee; }
  li.log  .k { background:#2f5d3a; color:#9de8b0; }
  .t { flex:1; }
  .sent { color:#9de8b0; font-size:12px; flex:none; }
  button.totask { padding:3px 10px; font-size:12px; flex:none; }
  .empty { color:#6d6d78; font-style:italic; }
  ]] .. themeCss .. [[
</style>
<header id="bar">
  <h1><span class="grip">⠿</span>🗒 Quick Append</h1>
  <span class="hint">drag here · ⌘⏎ file &amp; close · ⌘⇧V clipboard · ⎋ close (files too)</span>
</header>
<div id="wrap">
  <div id="legend">
    <span><b>*</b> Idea</span><span><b>+</b> Log</span>
    <span><b>!</b> task</span><span><b>?</b> note</span>
    <span>no prefix = Log · closing files everything</span>
  </div>
  <textarea id="t" placeholder="One entry per line. * idea · + log · ! task · ? note — plain lines are Logs."
            autofocus>]] .. escapeHtml(np.draft) .. [[</textarea>
  <div class="bar">
    <button class="go" onclick="fileIt()">File it all &nbsp;⌘⏎</button>
    <button onclick="say({a:'insertClip'})">Insert clipboard &nbsp;⌘⇧V</button>
    <span class="hint">* + lines → notes files + CSV · ! ? lines → the Capture Pad queue</span>
  </div>
  ]] .. review .. [[
</div>
<script>
  var t = document.getElementById('t');
  // say() attaches the live textarea to EVERY message — the 6.44.7
  // Capture Pad lesson. A button that sends without the text makes Lua
  // keep a stale draft, and the next redraw wipes what was typed.
  function say(m){
    m = m || {};
    m.text = t.value;
    m.sel  = t.selectionStart;
    window.webkit.messageHandlers.notePad.postMessage(m);
  }
  function fileIt(){ say({a:'close'}); }
  var bar = document.getElementById('bar');
  bar.addEventListener('mousedown', function(e){
    if (e.button !== 0) return;
    e.preventDefault();
    bar.classList.add('dragging');
    say({a:'dragStart'});
  });
  window.addEventListener('mouseup', function(){ bar.classList.remove('dragging'); });
  window.addEventListener('keydown', function(e){
    if (e.metaKey && e.key === 'Enter') { e.preventDefault(); fileIt(); }
    else if (e.metaKey && e.shiftKey && (e.key === 'v' || e.key === 'V')) {
      e.preventDefault(); say({a:'insertClip'});
    }
    else if (e.key === 'Escape') { e.preventDefault(); say({a:'close'}); }
  });
  // Caret restored in JS, not Lua: selectionStart counts UTF-16 units,
  // Lua's # counts bytes — they disagree the moment an emoji appears.
  var caret = ]] .. tostring(math.floor(np.draftCaret or 0)) .. [[;
  if (caret < 0 || caret > t.value.length) caret = t.value.length;
  t.focus(); t.setSelectionRange(caret, caret);
</script>
]]
    end

    function np.render()
        if not np.webview then return end
        pcall(function() np.webview:html(buildHtml()) end)
    end

    local function handleMessage(body)
        if type(body) ~= "table" then return end
        if body.text ~= nil then np.draft = tostring(body.text) end
        if body.sel  ~= nil then np.draftCaret = tonumber(body.sel) or 0 end

        if body.a == "close" then
            np.hide()   -- hide() files — closing IS filing
        elseif body.a == "insertClip" then
            local clip
            pcall(function() clip = hs.pasteboard.getContents() end)
            if clip == nil or clip == "" then
                pcall(function()
                    hs.alert.show("🗒 The clipboard holds no text")
                end)
            else
                if np.draft ~= "" and np.draft:sub(-1) ~= "\n" then
                    np.draft = np.draft .. "\n"
                end
                np.draft = np.draft .. clip
                np.draftCaret = #np.draft
                np.render()
            end
        elseif body.a == "toTask" then
            local e = np.reviewList[tonumber(body.idx) or 0]
            if e and not e.sent then
                if hasService("capturePad.add") then
                    -- ! forces a task — the review's question is "should
                    -- this BECOME a task", so the answer is never a note.
                    local ok, res = _G.service.call("capturePad.add", "!" .. e.text)
                    if ok then
                        e.sent = true
                        pcall(function()
                            hs.alert.show("🗒 Queued for Asana — " .. tostring(res), 2)
                        end)
                    else
                        pcall(function()
                            hs.alert.show("⚠️ " .. tostring(res), 4)
                        end)
                    end
                else
                    pcall(function()
                        hs.alert.show("🗒 The Capture Pad is not loaded on this Mac")
                    end)
                end
                np.render()
            end
        elseif body.a == "dragStart" then
            np.beginDrag()
        end
    end

    -- ---- dragging --------------------------------------------------------
    -- Lua polls the real mouse; JS mousemove dies the moment the pointer
    -- outruns the window. Same machinery as the Capture Pad, same reason.
    local function mousePosition()
        local fns = {}
        if type(hs.mouse) == "table" then
            if type(hs.mouse.absolutePosition) == "function" then
                table.insert(fns, hs.mouse.absolutePosition)
            end
            if type(hs.mouse.getAbsolutePosition) == "function" then
                table.insert(fns, hs.mouse.getAbsolutePosition)
            end
        end
        for _, fn in ipairs(fns) do
            local ok, p = pcall(fn)
            if ok and type(p) == "table" and p.x and p.y then return p end
        end
        return nil
    end

    local function leftButtonDown()
        local ok, btns = pcall(hs.eventtap.checkMouseButtons)
        if not ok or type(btns) ~= "table" then return false end
        return btns.left == true or btns[1] == true
    end

    function np.endDrag()
        if np.dragTimer then
            pcall(function() np.dragTimer:stop() end)
            np.dragTimer = nil
        end
        np.dragOffset = nil
    end

    function np.beginDrag()
        if not np.webview then return end
        local okF, f = pcall(function() return np.webview:frame() end)
        if not (okF and type(f) == "table") then return end
        local m = mousePosition()
        if not m then return end
        np.endDrag()   -- BEFORE the offset is set — endDrag clears it
        np.dragOffset = { x = m.x - f.x, y = m.y - f.y }
        np.dragTimer = hs.timer.doEvery(0.016, function()
            if not (np.webview and np.dragOffset) then np.endDrag() return end
            if not leftButtonDown() then np.endDrag() return end
            local p = mousePosition()
            if not p then np.endDrag() return end
            pcall(function()
                local cur = np.webview:frame()
                np.webview:frame({
                    x = p.x - np.dragOffset.x, y = p.y - np.dragOffset.y,
                    w = cur.w, h = cur.h,
                })
            end)
        end)
    end

    -- ---- the window ------------------------------------------------------
    -- Read back and verified, never assumed — AppKit silently drops style
    -- bits it will not honour. The full story is at Capture Pad's
    -- applyNonActivating; the arithmetic (not 5.3's `&`) is because this
    -- file runs on whatever Lua the installed Hammerspoon was built with.
    function np.applyNonActivating(view)
        if not view then return false, "there is no window" end
        local masks = hs.webview and hs.webview.windowMasks
        local bit   = type(masks) == "table" and masks.nonactivating or nil
        if type(bit) ~= "number" or bit < 1 then
            return false, "this Hammerspoon has no nonactivating window mask"
        end
        local function isSet(v) return (math.floor(v / bit) % 2) == 1 end
        local okGet, cur = pcall(function() return view:windowStyle() end)
        if not (okGet and type(cur) == "number") then
            return false, "the window style could not be read"
        end
        if not isSet(cur) then
            local okSet = pcall(function() view:windowStyle(cur + bit) end)
            if not okSet then return false, "the window style was rejected" end
        end
        local okRe, now = pcall(function() return view:windowStyle() end)
        if not (okRe and type(now) == "number") then
            return false, "the window style could not be read back"
        end
        if not isSet(now) then return false, "macOS dropped the mask" end
        return true, "applied"
    end

    -- 🚪 CLOSING FILES EVERYTHING — this is the one close path, and the
    -- filing lives IN it so no close can forget. Entries that fail stay
    -- in np.draft (they exist nowhere else); everything that filed is
    -- confirmed in one alert. opts.discard skips the filing — used by
    -- nothing today, kept so a deliberate "throw this away" is possible
    -- from the Console (_G.notePad.hide({discard=true})).
    function np.hide(opts)
        np.endDrag()
        if not (opts and opts.discard) then
            if (np.draft or ""):gsub("%s+", "") ~= "" then
                local allOk, summary, leftover = np.fileAll(np.draft)
                np.draft, np.draftCaret = leftover or "", 0
                if summary then
                    pcall(function()
                        hs.alert.show(summary, allOk and 2 or 5)
                    end)
                end
                if not allOk then
                    say("some entries failed — kept in the draft")
                end
            end
        end
        np.reviewMode, np.reviewList = false, {}
        if np.webview then
            pcall(function() np.webview:delete() end)
            np.webview = nil
        end
    end

    -- No webview must not mean no capture: the plain text box routes
    -- through the same prefix parser and the same services.
    local function promptFallback()
        local okP, button, typed = pcall(hs.dialog.textPrompt, "Quick Append",
            "One entry per line. * idea · + log · ! task · ? note — "
            .. "plain lines are Logs.",
            np.draft or "", "File it", "Cancel")
        if not okP or button ~= "File it" then return end
        local allOk, summary, leftover = np.fileAll(typed)
        np.draft = leftover or ""
        if summary then
            pcall(function() hs.alert.show(summary, allOk and 2 or 5) end)
        end
    end

    -- opts.prefix = seed the box with a routing prefix ("* " / "+ ")
    -- opts.text   = replace the draft outright (the clipboard door)
    function np.show(opts)
        if not np.enabled then return end
        opts = opts or {}
        -- A pad that is already open is CLOSED FIRST — which files it,
        -- per the close rule — before the new draft is seeded. Order
        -- matters: seeding first would file the NEW text, not the old.
        if np.webview then np.hide() end
        if opts.text ~= nil then
            np.draft, np.draftCaret = tostring(opts.text), #tostring(opts.text)
        end
        if opts.prefix ~= nil and np.draft == "" then
            np.draft, np.draftCaret = tostring(opts.prefix), #tostring(opts.prefix)
        end
        if not (hs.webview and hs.webview.usercontent) then
            promptFallback()
            return
        end

        local screen = core.resolveBaseScreen and core.resolveBaseScreen()
                       or hs.screen.mainScreen()
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(np.width, sf.w - 40)
        local h = math.min(np.height, sf.h - 40)
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 3, w = w, h = h }

        local okUc, uc = pcall(hs.webview.usercontent.new, "notePad")
        if not (okUc and uc) then promptFallback() return end
        np.uc = uc     -- HELD: collect this and the JS bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then print("🗒 Quick Append Pad: message handler — " .. tostring(err)) end
            end)
        end)

        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then
            np.uc = nil
            promptFallback()
            return
        end
        np.webview = view
        pcall(function() view:windowTitle("Quick Append") end)
        -- allowTextEntry sets canBecomeKeyWindow — without it the pad
        -- draws perfectly and swallows every keystroke.
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:closeOnEscape(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        -- Level is z-order WITHIN a Space; whether the pad may appear over
        -- a full-screen app is collection behaviour, a different axis.
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        np.nonActivatingApplied, np.nonActivatingWhy = false, "not requested"
        if np.nonActivating then
            np.nonActivatingApplied, np.nonActivatingWhy = np.applyNonActivating(view)
            if not np.nonActivatingApplied then
                print("🗒 Quick Append Pad: non-activating panel unavailable — "
                      .. tostring(np.nonActivatingWhy)
                      .. "; opening the pad will bring Hammerspoon forward.")
            end
        end
        np.render()
        pcall(function() view:show() end)
        if np.focusOnOpen then
            pcall(function() view:bringToFront(true) end)
        end
        say("pad opened" .. (np.reviewMode and " (review)" or ""))
    end

    -- ---- the 16:01 review ------------------------------------------------
    function np.review()
        -- Collected BEFORE show(): show() closes any open pad first, and
        -- that close (correctly) clears review state — so the list must
        -- be re-attached after the window exists, not before.
        local list = np.todayEntries()
        if #list == 0 then
            pcall(function()
                hs.alert.show("🗒 " .. np.reviewAt .. " review — no notes today", 2)
            end)
            say("review skipped — no entries today")
            return false
        end
        np.show({})
        np.reviewMode, np.reviewList = true, list
        np.render()
        say("review opened — " .. #list .. " entr"
            .. (#list == 1 and "y" or "ies"))
        return true
    end

    -- ---- the doors in ----------------------------------------------------
    -- 💻 6.114.0 — ⇪2, BECAUSE THIS PAD HAD NO KEY ON A LAPTOP AT ALL.
    -- Every other capture path has a letter: ⇪J files the clipboard, ⇪⇧J
    -- picks the file, ⇪N is the Capture Pad. This window's only addresses
    -- were ⇪pad2, ⇪pad* and ⇪pad-, so on a MacBook with no external
    -- keyboard the most-used capture tool in the config was unreachable.
    --
    -- 🔑 WHY A DIGIT AND NOT A LETTER: there is no free ⇪ letter left.
    -- All twenty-six are claimed on the plain layer, and ⇪⇧ has only F and
    -- Z free — neither of which says "note pad" to anyone. ⇪1–⇪9 are
    -- untouched, and 2 is not an arbitrary digit: it is THE SAME DIGIT as
    -- ⇪pad2, which is what makes it one fact to remember instead of two.
    --
    -- ⚠️ AND THE CLAIM STOPS THERE. This is not "the number row mirrors
    -- the pad row" — ⇪4 is Screenshots and would break that promise on the
    -- fourth key. One key, one true statement about it. The pre-typed
    -- variants (⇪pad* / ⇪pad-) stay pad-only and are reachable from ⇪space
    -- instead, where they now appear as runnable tools.
    np.laptopKey = "2"
    core.hyperAddShortcut({}, np.laptopKey, function() np.show({}) end,
                          "quick append pad")

    core.provide("notes.openPad", function() np.show({}) return true end)
    core.provide("notes.typeIdeas", function()
        np.show({ prefix = "* " })
        return true
    end)
    core.provide("notes.typeLog", function()
        np.show({ prefix = "+ " })
        return true
    end)
    -- The clipboard, opened for EDITING — no key of its own since ⇪pad1
    -- files it directly, but published for choosers and the Console.
    core.provide("notes.editClipboard", function()
        local text
        pcall(function() text = hs.pasteboard.getContents() end)
        if text == nil or text == "" then
            pcall(function()
                hs.alert.show("🗒 The clipboard holds no text — starting blank")
            end)
            text = ""
        end
        np.show({ text = text })
        return true
    end)
    core.provide("notes.review", function() return np.review() end)
    -- 🗒 6.105.0 — what was captured today, for the rollup card. Reading,
    -- not opening: the card counts them, the review still owns the pad.
    core.provide("notes.today", function() return np.todayEntries() end)
    core.provide("notePad.show", function(opts) np.show(opts) return true end)

    -- ⌘-drag anywhere on the pad, via the shared drag layer.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "quick append pad",
        frame = function() return np.webview and np.webview:frame() end,
        move  = function(x, y)
            local f = np.webview and np.webview:frame()
            if f then np.webview:frame({ x = x, y = y, w = f.w, h = f.h }) end
        end,
    })

    -- ⎋ in the escape router, so the cheat sheet closes AFTER the pad.
    -- Closing FILES the draft (the close rule), so Esc never loses work.
    if _G.claimEscape then
        _G.claimEscape("notepad", nil,
            function() return np.webview ~= nil end,
            function() np.hide() end)
    end

    _G.notePad = np
    M.np     = np
    M.config = np
end

-- The daily review is armed in warm(), not setup() — boot is measured,
-- and a timer is not needed to answer a keypress.
function M.warm(core)
    local np = M.np
    if not (np and np.reviewEnabled) then return end
    -- HELD in np.reviewTimer: an unreferenced hs.timer is collected, and
    -- a collected timer simply never fires — no error anywhere to see.
    local ok, t = pcall(hs.timer.doAt, np.reviewAt, "1d", function()
        pcall(function() np.review() end)
    end)
    if ok and t then
        np.reviewTimer = t
        if _G.diag then
            _G.diag.say("quickAppendPad", "daily review armed for " .. np.reviewAt)
        end
    else
        print("🗒 Quick Append Pad: could not arm the " .. tostring(np.reviewAt)
              .. " review — _G.notePad.review() runs it by hand")
    end
end

return M
