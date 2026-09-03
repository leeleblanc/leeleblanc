-- =====================================================================
-- MODULE: TASK FORM (⇪T) — Asana task entry where every field keeps its label
-- =====================================================================
-- The old ⇪T picker was one Spotlight-style line with a placeholder:
--     Title | Description | Assignee | /path/to/attachment
-- and the placeholder vanishes on the first keystroke — that is how the
-- native search field works, there is no API to keep it visible. LL:
-- "The minute I start typing the prompt words go away. That's a lot to
-- remember." Correct, and unfixable inside hs.chooser.
--
-- So creating a task is now a small FORM instead — four fields, each
-- with its label permanently on screen:
--
--     Title:        [                    ]
--     Description:  [                    ]
--     Assignee:     [                    ]
--     Attachment:   [                    ]  (📸 newest screenshot)
--
--   ⏎      send the task, from any field
--   ⇥ / ⇧⇥ next / previous field
--   ⌥⏎     newline inside the Description box (⏎ there still SENDS —
--          one key means one thing everywhere)
--   ⌘L     fill Attachment with the newest screenshot (same as the 📸
--          button; asks the Screenshots module, ⇪4's folder)
--   Esc    close — the draft is KEPT and comes back on the next ⇪T,
--          same guarantee the old picker made in 6.10.1
--
-- The pipe picker did a second job too: SEARCHING past tasks. A form
-- cannot search, so that job moved whole to ⇪⇧S ("S for Search") — the
-- same chooser as before, now used only for looking things up.
-- (⇪⇧T was the plan, but the Text Expander has held it since 6.68.0.)
--
-- ---------------------------------------------------------------------
-- WHAT THIS MODULE DELIBERATELY DOES NOT OWN
-- ---------------------------------------------------------------------
-- Submission. Validating the title, resolving "sarah" to an Asana GID,
-- posting, history, the attachment upload — all of that stayed in
-- init.lua §4 where it always lived, published as _G.asanaSubmitTask.
-- This module is ONLY the front end: it collects four strings and hands
-- them over. Both entry paths (this form, and the pipe chooser on ⇪⇧S)
-- go through the exact same submit code, so they cannot drift apart.
--
-- The ⇪T key itself is also bound in init.lua (it is a migrated combo,
-- ⌃⌥⌘T → ⇪T, routed through the hyperKeyMap) — init calls
-- _G.taskFormShow when this module loaded, and falls back to the pipe
-- chooser when it did not. A missing module must cost the form, not
-- task creation.
--
-- The webview recipe (allowTextEntry, fullScreenAuxiliary, the say()
-- rule that every message carries every field) is the Capture Pad's,
-- copied deliberately — see that module's 6.44.x history for why each
-- line is there.
-- =====================================================================

local M = {
    name  = "Task Form",
    order = 24,
    family = "capture",
    cheatsheet = {
        title = "✅ TASK FORM (⇪T — labeled Asana task entry)",
        entries = {
            { "⇪T",   "Open the form: Title · Description · Assignee · Attachment" },
            { "dates", "Start/End date & time — all optional (a start needs an end)" },
            { "fields","The PROJECT'S dropdowns — Priority, Progress… fetched live" },
            { "⏎",    "send the task (from any field)" },
            { "⇥",    "next field · ⇧⇥ previous" },
            { "⌥⏎",   "newline inside the Description box" },
            { "📸",   "button (or ⌘L): newest screenshot into Attachment" },
            { "esc",  "close — the draft is kept for next time" },
            { "⇪⇧S",  "search PAST tasks (the old pipe picker, search-only)" },
        },
    },
}

function M.setup(core)
    local form = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    form.enabled     = true
    form.width       = 560
    form.height      = 480
    form.focusOnOpen = true
    -- ----------------------------------------------------------------------

    -- The draft survives Esc, a stray click, and reopening — cleared only
    -- when a task is actually sent. In-memory, like the old _G.taskDraft:
    -- a config reload starts fresh. 6.152.0 adds the schedule fields and
    -- `custom` (field gid → chosen value) for the project dropdowns.
    local function freshDraft()
        return { title = "", desc = "", assignee = "", attach = "",
                 startDate = "", startTime = "", dueDate = "", dueTime = "",
                 custom = {} }
    end
    form.draft = freshDraft()

    local function say(m)  if _G.diag then _G.diag.say("taskForm", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("taskForm", m) end end

    local function escapeHtml(s)
        return (tostring(s or "")
            :gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            :gsub('"', "&quot;"))
    end

    -- ---- the page --------------------------------------------------------
    function form.buildHtml()
        -- Assignee autocomplete: a native <datalist> fed from the same
        -- team roster the pipe picker's inline suggestions used (§3.5's
        -- cache). Typing filters it; picking fills the field; a name not
        -- on the list still submits (email / GID / "me" are all valid)
        -- and is validated properly by _G.asanaSubmitTask.
        local opts = {}
        if type(_G.asanaTeamMembers) == "table" then
            for _, m in ipairs(_G.asanaTeamMembers) do
                if type(m) == "table" and m.name then
                    opts[#opts + 1] = '<option value="' .. escapeHtml(m.name)
                        .. '">' .. escapeHtml(m.email or "") .. '</option>'
                end
            end
        end
        local d = form.draft
        -- 🎨 6.90.0 — shared card colors (ui_style.lua), cascade-last.
        local themeCss = (_G.uiStyle and _G.uiStyle.cssOverride
                          and _G.uiStyle.cssOverride()) or ""

        -- 📋 6.152.0 — THE DETAILS SECTION: the schedule (start/end date
        -- and time, all optional) and the PROJECT'S OWN custom fields,
        -- built from _G.asanaCustomFields (fetched from Asana at boot —
        -- task_creator.lua) so a dropdown edited in Asana appears here on
        -- the next reload with no code change. Unsupported subtypes
        -- (formula, date fields…) are skipped rather than half-drawn.
        local cfRows = {}
        for _, f in ipairs(_G.asanaCustomFields or {}) do
            local cur = d.custom and d.custom[f.gid]
            local label = '<div class="row"><label>' .. escapeHtml(f.name)
                          .. ':</label>'
            if f.subtype == "enum" or f.subtype == "multi_enum" then
                local multi = (f.subtype == "multi_enum")
                local sel = {}
                if type(cur) == "table" then
                    for _, g in ipairs(cur) do sel[g] = true end
                elseif cur then sel[tostring(cur)] = true end
                local o = { '<select class="cf" data-gid="'
                            .. escapeHtml(f.gid) .. '"'
                            .. (multi and (' multiple size="'
                                .. math.min(4, math.max(2, #(f.options or {})))
                                .. '" title="⌘-click for more than one"') or "")
                            .. '>' }
                if not multi then o[#o + 1] = '<option value="">—</option>' end
                for _, opt in ipairs(f.options or {}) do
                    o[#o + 1] = '<option value="' .. escapeHtml(opt.gid) .. '"'
                                .. (sel[opt.gid] and " selected" or "") .. '>'
                                .. escapeHtml(opt.name) .. '</option>'
                end
                o[#o + 1] = '</select></div>'
                cfRows[#cfRows + 1] = label .. table.concat(o)
            elseif f.subtype == "people" then
                cfRows[#cfRows + 1] = label .. '<input class="cf" data-gid="'
                    .. escapeHtml(f.gid) .. '" list="team" value="'
                    .. escapeHtml(type(cur) == "string" and cur or "")
                    .. '" placeholder="name or email — optional"></div>'
            elseif f.subtype == "number" or f.subtype == "text" then
                cfRows[#cfRows + 1] = label .. '<input class="cf"'
                    .. (f.subtype == "number" and ' type="number"' or "")
                    .. ' data-gid="' .. escapeHtml(f.gid) .. '" value="'
                    .. escapeHtml(type(cur) ~= "table" and cur or "")
                    .. '"></div>'
            end
        end
        local cfHtml = table.concat(cfRows)
        if cfHtml == "" then
            cfHtml = '<div class="row"><label></label><span class="hint">'
                .. 'project fields load shortly after boot — reopen ⇪T '
                .. 'if this stays empty</span></div>'
        end
        local detailsHtml = [[
  <div class="sect">Schedule — optional (a start needs an end)</div>
  <div class="row"><label for="sd">Start:</label>
    <input id="sd" type="date" value="]] .. escapeHtml(d.startDate) .. [[">
    <input id="st" type="time" value="]] .. escapeHtml(d.startTime) .. [["></div>
  <div class="row"><label for="ed">End:</label>
    <input id="ed" type="date" value="]] .. escapeHtml(d.dueDate) .. [[">
    <input id="et" type="time" value="]] .. escapeHtml(d.dueTime) .. [["></div>
  <div class="sect">Project fields — optional</div>
]] .. cfHtml

        return [[
<meta charset="utf-8">
<style>
  :root { color-scheme: dark; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,sans-serif;
         font-size:15px; line-height:1.5; background:#141418; color:#e8e8ec; }
  header { padding:14px 18px 8px; display:flex; justify-content:space-between;
           align-items:baseline; border-bottom:1px solid #2a2a32;
           user-select:none; -webkit-user-select:none; }
  h1 { font-size:16px; margin:0; font-weight:600; }
  .hint { color:#8a8a96; font-size:13px; }
  #wrap { padding:14px 18px; }
  .row { display:flex; gap:12px; align-items:flex-start; margin-bottom:12px; }
  /* THE LABELS ARE THE FEATURE — a fixed column that never goes away,
     which is the entire reason this form exists. */
  label { flex:none; width:104px; text-align:right; padding-top:8px;
          color:#a9a9b4; font-size:14px; user-select:none;
          -webkit-user-select:none; }
  input, textarea { flex:1; box-sizing:border-box;
          background:#1d1d24; color:#f2f2f6; border:1px solid #33333e;
          border-radius:8px; padding:8px 12px;
          font-family:-apple-system,BlinkMacSystemFont,sans-serif;
          font-size:15px; line-height:1.4; }
  textarea { height:84px; resize:vertical; }
  #attach { font-size:13px; }
  input:focus, textarea:focus { outline:none; border-color:#4a7fe0; }
  ::placeholder { color:#5c5c68; }
  .after { flex:none; padding-top:4px; }
  button { background:#2a2a34; color:#e8e8ec; border:1px solid #3b3b47;
           border-radius:7px; padding:6px 11px; font-size:13px; cursor:pointer; }
  button.go { background:#3566cc; border-color:#4a7fe0; font-size:14px;
              padding:7px 14px; }
  button:hover { filter:brightness(1.18); }
  .bar { margin-top:6px; display:flex; gap:10px; align-items:center; }
  .bar .hint { margin-left:auto; }
  .sect { color:#8a8a96; font-size:11px; letter-spacing:.5px;
          text-transform:uppercase; margin:12px 0 8px 116px;
          user-select:none; -webkit-user-select:none; }
  select { flex:1; box-sizing:border-box; background:#1d1d24; color:#f2f2f6;
           border:1px solid #33333e; border-radius:8px; padding:7px 10px;
           font-size:14px; }
  select[multiple] { padding:4px 6px; }
  select:focus { outline:none; border-color:#4a7fe0; }
  input[type=date], input[type=time] { color-scheme: dark; }
  ]] .. themeCss .. [[
</style>
<header>
  <h1>✅ New Asana Task</h1>
  <span class="hint">⏎ send · ⇥ next field · esc keeps the draft</span>
</header>
<div id="wrap">
  <div class="row"><label for="title">Title:</label>
    <input id="title" value="]] .. escapeHtml(d.title) .. [[" autofocus></div>
  <div class="row"><label for="desc">Description:</label>
    <textarea id="desc" placeholder="optional — ⌥⏎ for a new line">]]
      .. escapeHtml(d.desc) .. [[</textarea></div>
  <div class="row"><label for="assignee">Assignee:</label>
    <input id="assignee" list="team" value="]] .. escapeHtml(d.assignee)
      .. [[" placeholder="name, email, GID, or “me”"></div>
  <datalist id="team">]] .. table.concat(opts) .. [[</datalist>
  <div class="row"><label for="attach">Attachment:</label>
    <input id="attach" value="]] .. escapeHtml(d.attach)
      .. [[" placeholder="/path/to/file — or use the 📸 button">
    <span class="after"><button type="button" onclick="say({a:'latest'})"
      title="Newest file from the ⇪4 screenshots folder (⌘L)">📸 newest</button></span></div>
]] .. detailsHtml .. [[
  <div class="bar">
    <button class="go" onclick="submitIt()">Create task&nbsp;&nbsp;⏎</button>
    <span class="hint">only Title is required</span>
  </div>
</div>
<script>
  // Every message carries every field — the Capture Pad's 6.44.7 lesson,
  // applied from day one: values collected in ONE place, so no button or
  // key path can forget them and cost a redraw the draft.
  function val(id){ var el = document.getElementById(id); return el ? el.value : ''; }
  function say(m){
    m = m || {};
    m.title    = val('title');
    m.desc     = val('desc');
    m.assignee = val('assignee');
    m.attach   = val('attach');
    // 6.152.0 — the Details section rides on every message, same rule
    m.startDate = val('sd'); m.startTime = val('st');
    m.dueDate   = val('ed'); m.dueTime   = val('et');
    var cf = {};
    document.querySelectorAll('.cf').forEach(function(el){
      var g = el.getAttribute('data-gid');
      if (!g) return;
      if (el.tagName === 'SELECT' && el.multiple) {
        var vals = [];
        for (var i = 0; i < el.options.length; i++) {
          if (el.options[i].selected && el.options[i].value) vals.push(el.options[i].value);
        }
        cf[g] = vals;
      } else {
        cf[g] = el.value || '';
      }
    });
    m.custom = cf;
    window.webkit.messageHandlers.taskForm.postMessage(m);
  }
  function submitIt(){ say({a:'submit'}); }
  window.addEventListener('keydown', function(e){
    if (e.key === 'Escape') { e.preventDefault(); say({a:'close'}); return; }
    if (e.metaKey && (e.key === 'l' || e.key === 'L')) {
      e.preventDefault(); say({a:'latest'}); return;
    }
    if (e.key === 'Enter') {
      // ⏎ SENDS — everywhere, including the Description box, because
      // that is the promise the form makes ("then I hit enter and the
      // task is sent"). ⌥⏎ is the newline, inserted by hand since the
      // textarea's native newline is the un-modified Enter we just took.
      if (e.altKey && e.target && e.target.id === 'desc') {
        e.preventDefault();
        var t = e.target, s = t.selectionStart, en = t.selectionEnd;
        t.value = t.value.slice(0, s) + '\n' + t.value.slice(en);
        t.selectionStart = t.selectionEnd = s + 1;
        return;
      }
      e.preventDefault(); submitIt();
    }
  });
</script>
]]
    end

    -- ---- messages from the page ------------------------------------------
    local function handleMessage(body)
        if type(body) ~= "table" then return end
        local d = form.draft
        if body.title    ~= nil then d.title    = tostring(body.title)    end
        if body.desc     ~= nil then d.desc     = tostring(body.desc)     end
        if body.assignee ~= nil then d.assignee = tostring(body.assignee) end
        if body.attach   ~= nil then d.attach   = tostring(body.attach)   end
        -- 6.152.0 — the Details section is part of the draft too
        if body.startDate ~= nil then d.startDate = tostring(body.startDate) end
        if body.startTime ~= nil then d.startTime = tostring(body.startTime) end
        if body.dueDate   ~= nil then d.dueDate   = tostring(body.dueDate)   end
        if body.dueTime   ~= nil then d.dueTime   = tostring(body.dueTime)   end
        if type(body.custom) == "table" then d.custom = body.custom end

        if body.a == "submit" then
            if not _G.asanaSubmitTask then
                pcall(function()
                    hs.alert.show("⚠️ Task submit unavailable — is Asana configured?", 4)
                end)
                warn("submit requested but _G.asanaSubmitTask is missing")
                return
            end
            -- Same path cleanup the pipe picker's 4th field gets — quotes
            -- stripped, ~ expanded — published by §4 for exactly this call.
            local attach = d.attach
            if _G.asanaNormalizePath then attach = _G.asanaNormalizePath(attach) end
            local ok = _G.asanaSubmitTask(d.title, d.desc, d.assignee, attach, {
                startDate = d.startDate, startTime = d.startTime,
                dueDate   = d.dueDate,   dueTime   = d.dueTime,
                custom    = d.custom,
            })
            if ok then
                -- Sent: the draft's job is done. Validation failures
                -- (empty title, unknown assignee, a start without an
                -- end) return false AFTER alerting, and the form stays
                -- up with everything typed still in it — fix the one
                -- field and hit ⏎ again.
                form.draft = freshDraft()
                form.hide()
            end
        elseif body.a == "latest" then
            local path = core.call("screenshots.latest")
            if type(path) == "string" and path ~= "" then
                d.attach = path
                form.render()
            else
                pcall(function()
                    hs.alert.show("📸 No screenshots yet — ⇪4 takes one", 3)
                end)
            end
        elseif body.a == "close" then
            form.hide()   -- draft already captured above — kept for reopen
        end
    end

    -- ---- window ----------------------------------------------------------
    function form.render()
        if not form.webview then return end
        pcall(function() form.webview:html(form.buildHtml()) end)
    end

    function form.hide()
        if form.webview then
            pcall(function() form.webview:delete() end)
            form.webview = nil
        end
        form.uc = nil
        say("form closed")
    end

    function form.show()
        if form.webview then form.hide() return end
        if not (hs.webview and hs.webview.usercontent) then
            -- No WKWebView (old Hammerspoon, stripped build): fall back
            -- to the pipe chooser rather than costing task creation.
            if _G.asanaOpenTaskChooser then _G.asanaOpenTaskChooser() end
            return
        end

        local screen = core.resolveBaseScreen and core.resolveBaseScreen()
                       or (hs.screen and hs.screen.mainScreen and hs.screen.mainScreen())
        local sf = { x = 0, y = 0, w = 1440, h = 900 }
        pcall(function() if screen then sf = screen:frame() end end)
        -- 6.152.0 — the window grows with the Details section: two
        -- schedule rows plus one row per supported project field (a
        -- multi-select is taller), clamped to the screen as before.
        local extra = 100
        for _, f in ipairs(_G.asanaCustomFields or {}) do
            if f.subtype == "multi_enum" then
                extra = extra + 28
                       + math.min(4, math.max(2, #(f.options or {}))) * 18
            elseif f.subtype == "enum" or f.subtype == "people"
                or f.subtype == "number" or f.subtype == "text" then
                extra = extra + 44
            end
        end
        local w = math.min(form.width,  sf.w - 40)
        local h = math.min(form.height + extra, sf.h - 40)
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 3,
                       w = w, h = h }

        local okUc, uc = pcall(hs.webview.usercontent.new, "taskForm")
        if not (okUc and uc) then
            if _G.asanaOpenTaskChooser then _G.asanaOpenTaskChooser() end
            return
        end
        form.uc = uc    -- HELD: collect this and the JS bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then warn("message handler — " .. tostring(err)) end
            end)
        end)

        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then
            form.uc = nil
            if _G.asanaOpenTaskChooser then _G.asanaOpenTaskChooser() end
            return
        end
        form.webview = view
        pcall(function() view:windowTitle("New Asana Task") end)
        -- allowTextEntry = canBecomeKeyWindow; without it the form draws
        -- and swallows every keystroke (Capture Pad, 6.44.x).
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:closeOnEscape(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        form.render()
        pcall(function() view:show() end)
        if form.focusOnOpen then
            pcall(function() view:bringToFront(true) end)
        end
        say("form opened")
    end

    function form.toggle()
        if form.webview then form.hide() else form.show() end
    end

    -- ---- wiring ----------------------------------------------------------
    -- No hyperAddShortcut here, deliberately: ⇪T is a MIGRATED combo
    -- (⌃⌥⌘T routed through init.lua's hyperKeyMap) and its binding lives
    -- in §5, which calls _G.taskFormShow when it exists. Claiming ⇪T
    -- here as well would be the double-claim the hyper sentry warns about.
    if form.enabled then
        _G.taskFormShow = function() form.show() end
    end

    core.provide("taskform.show",   function() return form.show() end)
    core.provide("taskform.toggle", function() return form.toggle() end)

    -- 6.89.0 — listed for Window Move: ⌘-drag anywhere on the form moves
    -- it (bare clicks belong to its fields and buttons).
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "task form",
        frame = function() return form.webview and form.webview:frame() end,
        move  = function(x, y)
            local f = form.webview and form.webview:frame()
            if f then form.webview:frame({ x = x, y = y, w = f.w, h = f.h }) end
        end,
    })

    -- ⎋ 6.93.0 — in the escape router, so the cheat sheet closes AFTER the
    -- form; its own page already treats Escape as close when focused.
    if _G.claimEscape then
        _G.claimEscape("taskform", nil,
            function() return form.webview ~= nil end,
            function() form.hide() end)
    end

    _G.taskForm = form
    M.form   = form
    M.config = form
end

return M
