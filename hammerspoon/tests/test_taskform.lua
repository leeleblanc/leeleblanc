-- =====================================================================
-- test_taskform.lua — the labeled Asana task form (⇪T)
-- =====================================================================
--     lua5.4 test_taskform.lua [/path/to/hammerspoon]
--
-- Executes modules/task_form.lua against a stubbed hs whose webview
-- records the HTML it is given and hands back the JS bridge, so the
-- suite can drive the REAL message handler: open → type → submit /
-- close / 📸-latest, and read what the page would actually show.
--
-- THE RULES THIS SUITE ENFORCES ABOVE ALL OTHERS:
--   · The four labels are IN the page — they are the entire feature.
--   · The draft survives everything except a successful send. Esc, a
--     failed validation, a reopen: what was typed comes back.
--   · Submission goes through _G.asanaSubmitTask and NOWHERE else —
--     one submit path shared with the pipe picker, so they can't drift.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- ---- the fake Mac -----------------------------------------------------
local ALERTS = {}
local LAST_HTML, BRIDGE, VIEW = nil, nil, nil
local TEXT_ENTRY_ALLOWED = false

hs = {
    webview = {
        usercontent = {
            new = function(name)
                local uc = { name = name }
                function uc:setCallback(fn) BRIDGE = fn; return self end
                return uc
            end,
        },
        new = function(rect, opts, uc)
            local v = { rect = rect, uc = uc, deleted = false, shown = false,
                        style = 0 }
            function v:html(s) LAST_HTML = s; return self end
            function v:show() self.shown = true; return self end
            function v:delete() self.deleted = true; return self end
            function v:windowTitle() return self end
            function v:allowTextEntry(b) TEXT_ENTRY_ALLOWED = b; return self end
            function v:closeOnEscape() return self end
            function v:level() return self end
            function v:behaviorAsLabels() return self end
            function v:bringToFront() return self end
            -- 6.153.0 — the non-activating mask is applied arithmetically
            -- and read back; the stub keeps an honest style number.
            function v:windowStyle(s)
                if s ~= nil then self.style = s end
                return self.style
            end
            function v:frame(f) if f then self.rect = f end return self.rect end
            VIEW = v
            return v
        end,
        windowMasks = { nonactivating = 128 },
    },
    drawing = { windowLevels = { floating = 5 } },
    screen = { mainScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
    end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    timer = { secondsSinceEpoch = function() return 1000.4231 end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

-- the globals init.lua §4 publishes for this module
local SUBMITS, SUBMIT_OK = {}, true
_G.asanaSubmitTask = function(title, desc, assignee, attach, extra)
    SUBMITS[#SUBMITS + 1] = { title = title, desc = desc,
                              assignee = assignee, attach = attach,
                              extra = extra }
    return SUBMIT_OK
end
_G.asanaNormalizePath = function(s)
    -- a visible transformation, so the suite can PROVE it was applied
    return (tostring(s or ""):gsub("^[\"']", ""):gsub("[\"']$", ""))
end
local FALLBACKS = 0
_G.asanaOpenTaskChooser = function() FALLBACKS = FALLBACKS + 1 end
_G.asanaTeamMembers = {
    { name = "Sarah Chen",  email = "sarah@example.com", gid = "123456789012345" },
    { name = "Dana <Ops>",  email = "dana@example.com",  gid = "234567890123456" },
}

local HYPER, PROVIDED, SERVICE_ANSWERS = {}, {}, {}
local CORE = {
    hyperAddShortcut = function(mods, key)
        local ms = {}
        for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms)
        HYPER[table.concat(ms, "+") .. "|" .. key] = true
    end,
    provide = function(n, f) PROVIDED[n] = f end,
    call    = function(n) return SERVICE_ANSWERS[n] end,
    resolveBaseScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
    end,
}

local M = dofile(HS .. "/modules/task_form.lua")
M.setup(CORE)
local F = _G.taskForm

-- a page message, the way the JS bridge delivers one: every field rides
-- along with every message (say() collects them in one place)
local function msg(action, fields)
    fields = fields or {}
    BRIDGE({ body = {
        a        = action,
        title    = fields.title    or "",
        desc     = fields.desc     or "",
        assignee = fields.assignee or "",
        attach   = fields.attach   or "",
    } })
end

-- =====================================================================
out("\n1. contract & wiring\n")
-- =====================================================================
check("module loads and has setup()", type(M.setup) == "function")
check("🚨 claims NO ⇪ shortcut of its own — ⇪T is a migrated combo bound "
      .. "in init.lua §5, and a claim here would be the double-claim the "
      .. "hyper sentry warns about", next(HYPER) == nil)
check("_G.taskFormShow is published for §5's ⇪T binding",
      type(_G.taskFormShow) == "function")
check("taskform.show is a service", type(PROVIDED["taskform.show"]) == "function")
check("taskform.toggle is a service", type(PROVIDED["taskform.toggle"]) == "function")
check("cheat sheet group present with a title", type(M.cheatsheet) == "table"
      and type(M.cheatsheet.title) == "string")

-- =====================================================================
out("2. the page — labels that never disappear\n")
-- =====================================================================
_G.taskFormShow()
check("the form opened a webview and rendered", VIEW ~= nil and VIEW.shown
      and type(LAST_HTML) == "string")
check("🚨 allowTextEntry(true) was called — without it the form draws and "
      .. "swallows every keystroke (Capture Pad, 6.44.x)",
      TEXT_ENTRY_ALLOWED == true)
for _, label in ipairs({ "Title:", "Description:", "Assignee:", "Attachment:" }) do
    check("the page shows the label “" .. label .. "”",
          LAST_HTML:find(label, 1, true) ~= nil)
end
check("Title has focus on open", LAST_HTML:find("autofocus") ~= nil)
check("the team roster feeds the Assignee datalist",
      LAST_HTML:find("Sarah Chen", 1, true) ~= nil)
check("…with HTML in a member name ESCAPED, not injected",
      LAST_HTML:find("Dana &lt;Ops&gt;", 1, true) ~= nil
      and LAST_HTML:find("Dana <Ops>", 1, true) == nil)

-- the JS contract, checked in the page source
check("say() collects ALL FOUR fields in one place (the Capture Pad's "
      .. "6.44.7 lesson)", LAST_HTML:find("m.title", 1, true) ~= nil
      and LAST_HTML:find("m.desc", 1, true) ~= nil
      and LAST_HTML:find("m.assignee", 1, true) ~= nil
      and LAST_HTML:find("m.attach", 1, true) ~= nil)
check("⏎ submits", LAST_HTML:find("submitIt", 1, true) ~= nil
      and LAST_HTML:find("'Enter'", 1, true) ~= nil)
check("⌥⏎ makes a newline in the Description", LAST_HTML:find("altKey", 1, true) ~= nil)
check("Esc closes via the bridge (so the draft travels with it)",
      LAST_HTML:find("'Escape'", 1, true) ~= nil
      and LAST_HTML:find("a:'close'", 1, true) ~= nil)
check("⌘L asks for the newest screenshot", LAST_HTML:find("metaKey", 1, true) ~= nil
      and LAST_HTML:find("a:'latest'", 1, true) ~= nil)

-- =====================================================================
out("3. submit — one shared path\n")
-- =====================================================================
SUBMIT_OK = true
msg("submit", { title = "Fix the printer", desc = "toner low",
                assignee = "Sarah Chen", attach = "\"/tmp/shot.png\"" })
check("submission goes through _G.asanaSubmitTask", #SUBMITS == 1)
check("…with the four fields intact", SUBMITS[1]
      and SUBMITS[1].title == "Fix the printer"
      and SUBMITS[1].desc == "toner low"
      and SUBMITS[1].assignee == "Sarah Chen")
check("…and the attachment path NORMALIZED first (quotes stripped, same "
      .. "cleanup the pipe picker's 4th field gets)",
      SUBMITS[1] and SUBMITS[1].attach == "/tmp/shot.png", SUBMITS[1] and SUBMITS[1].attach)
check("a sent task closes the form", F.webview == nil and VIEW.deleted)
check("…and clears the draft — its job is done", F.draft.title == ""
      and F.draft.desc == "" and F.draft.assignee == "" and F.draft.attach == "")

-- =====================================================================
out("4. validation failure — the draft survives\n")
-- =====================================================================
_G.taskFormShow()
SUBMIT_OK = false     -- asanaSubmitTask alerted and said no (empty title,
                      -- unknown assignee — its decision, not the form's)
msg("submit", { title = "", desc = "kept", assignee = "nobody" })
check("the form STAYS OPEN so the one bad field can be fixed",
      F.webview ~= nil and not F.webview.deleted)
check("…with everything typed still in the draft", F.draft.desc == "kept"
      and F.draft.assignee == "nobody")
SUBMIT_OK = true

-- =====================================================================
out("5. Esc — close but keep the draft\n")
-- =====================================================================
msg("close", { title = "half-typed title", desc = "half-typed desc" })
check("Esc closes the form", F.webview == nil)
check("…keeping the draft (the old picker's 6.10.1 guarantee)",
      F.draft.title == "half-typed title")
_G.taskFormShow()
check("reopening brings the typed text back into the page",
      LAST_HTML:find("half%-typed title") ~= nil)
msg("close", {})   -- clean up for the next section (also clears the draft
                   -- fields, since every message carries every field)
check("closing after clearing the fields leaves an empty draft",
      F.draft.title == "")

-- =====================================================================
out("5b. 6.152.0 — the Details section: schedule + the project's fields\n")
-- =====================================================================
_G.asanaCustomFields = {
    { gid = "F1", name = "Task Priority", subtype = "enum",
      options = { { gid = "O1", name = "High" },
                  { gid = "O2", name = "Low & <odd>" } } },
    { gid = "F2", name = "SAC Values", subtype = "multi_enum",
      options = { { gid = "M1", name = "Students First" },
                  { gid = "M2", name = "Respect" } } },
    { gid = "F3", name = "Supervisor", subtype = "people", options = {} },
    { gid = "F9", name = "Some Formula", subtype = "formula", options = {} },
}
_G.taskFormShow()
-- 🧪 ASK THE TAG, NOT THE ADJACENCY (6.263.0). These four read
-- `id="sd" type="date"` as one literal string, so adding ANY attribute
-- between them failed a check that has nothing to say about attribute
-- order — which is what happened the day every box in this config
-- stopped asking macOS to spell-check it. `tagWith` pulls out the one
-- <...> that carries the id and asks THAT for the type, which is the
-- thing the check was always about.
local function tagWith(html, needle)
    local at = html and html:find(needle, 1, true)
    if not at then return nil end
    local open = html:sub(1, at):match(".*()<")
    local shut = html:find(">", at, true)
    if not (open and shut) then return nil end
    return html:sub(open, shut)
end
local function tagHas(html, needle, want)
    local t = tagWith(html, needle)
    return t ~= nil and t:find(want, 1, true) ~= nil
end
check("the schedule is on the page: date AND time inputs for both ends",
      tagHas(LAST_HTML, 'id="sd"', 'type="date"')
      and tagHas(LAST_HTML, 'id="st"', 'type="time"')
      and tagHas(LAST_HTML, 'id="ed"', 'type="date"')
      and tagHas(LAST_HTML, 'id="et"', 'type="time"'))
check("✏️ …and every one of this form's boxes refuses macOS's spell "
      .. "checker — its correction panel aborted the process on 2026-09-19",
      (function()
          for _, id in ipairs({ 'id="sd"', 'id="st"', 'id="ed"', 'id="et"',
                                'id="title"', 'id="desc"', 'id="assignee"',
                                'id="attach"' }) do
              if not tagHas(LAST_HTML, id, 'spellcheck="false"') then return false, id end
          end
          return true
      end)())
check("each project field renders under its own permanent label",
      LAST_HTML:find("Task Priority:", 1, true) ~= nil
      and LAST_HTML:find("SAC Values:", 1, true) ~= nil
      and LAST_HTML:find("Supervisor:", 1, true) ~= nil)
check("enum options carry their Asana gids as values",
      LAST_HTML:find('value="O1"', 1, true) ~= nil)
check("…option names are ESCAPED, not injected",
      LAST_HTML:find("Low &amp; &lt;odd&gt;", 1, true) ~= nil)
check("🚨 6.153.0 — a multi_enum renders as CHECKBOX CHIPS, and the old "
   .. "system list box is gone (LL: “the SAC Values selector doesn't "
   .. "look right”)",
      LAST_HTML:find('class="cf chips" data-gid="F2"', 1, true) ~= nil
      and LAST_HTML:find("multiple", 1, true) == nil)
check("…each option is one labelled chip carrying its Asana gid",
      LAST_HTML:find('<label class="chip"><input', 1, true) ~= nil
      and tagHas(LAST_HTML, 'value="M1"', 'type="checkbox"'))
check("a people field types against the same team datalist as Assignee",
      LAST_HTML:find('data-gid="F3" list="team"', 1, true) ~= nil)
check("an unsupported subtype is SKIPPED whole, not half-drawn",
      LAST_HTML:find("Some Formula", 1, true) == nil)
check("say() carries the details on every message — same one-place rule",
      LAST_HTML:find("m.startDate", 1, true) ~= nil
      and LAST_HTML:find("m.custom", 1, true) ~= nil)

BRIDGE({ body = { a = "submit", title = "Planned", desc = "", assignee = "",
    attach = "", startDate = "2026-09-08", startTime = "09:00",
    dueDate = "2026-09-08", dueTime = "10:30",
    custom = { F1 = "O1", F2 = { "M1" } } } })
local last = SUBMITS[#SUBMITS]
check("submit hands asanaSubmitTask a FIFTH argument with the schedule",
      last and last.extra and last.extra.startDate == "2026-09-08"
      and last.extra.dueTime == "10:30")
check("…and the custom picks, keyed by field gid (arrays survive)",
      last.extra.custom and last.extra.custom.F1 == "O1"
      and type(last.extra.custom.F2) == "table"
      and last.extra.custom.F2[1] == "M1")
check("a sent task clears the details with the rest of the draft",
      F.draft.startDate == "" and F.draft.dueTime == ""
      and next(F.draft.custom or {}) == nil)

_G.taskFormShow()
BRIDGE({ body = { a = "close", title = "x", desc = "", assignee = "",
    attach = "", startDate = "2026-12-01", startTime = "", dueDate = "",
    dueTime = "", custom = { F1 = "O2", F2 = { "M2" } } } })
_G.taskFormShow()
check("Esc keeps the details; reopening restores the pick as SELECTED",
      F.draft.startDate == "2026-12-01"
      and LAST_HTML:find('value="O2" selected', 1, true) ~= nil)
check("…and a kept multi-pick comes back as a CHECKED chip",
      LAST_HTML:find('value="M2" checked', 1, true) ~= nil
      and LAST_HTML:find('value="M1" checked', 1, true) == nil)
msg("close", {})
F.draft = { title = "", desc = "", assignee = "", attach = "",
            startDate = "", startTime = "", dueDate = "", dueTime = "",
            custom = {} }
_G.asanaCustomFields = {}

-- =====================================================================
out("5c. 6.153.0 — the window: a drag handle, and it types without a click\n")
-- =====================================================================
-- LL, same message: "I can't move this window. And it doesn't seem
-- active, I have to click on it." Two fixes, both borrowed whole from
-- panels that already had them: the header reports mousedown and
-- window_move drives the drag (⇪space's recipe), and the window asks
-- for the non-activating panel mask so it can take the keyboard from a
-- background app (the Capture Pad's recipe, verified by read-back).
_G.taskFormShow()
check("the header reports mousedown as dragStart (the page side of the drag)",
      LAST_HTML:find("dragStart", 1, true) ~= nil
      and LAST_HTML:find("mousedown", 1, true) ~= nil)
local DRAGGED = {}
_G.beginPanelDrag = function(name) DRAGGED[#DRAGGED + 1] = name; return true end
msg("dragStart", { title = "mid-drag" })
check("…and Lua hands the drag to Window Move BY NAME — the same entry "
   .. "the module filed in _G.movablePanels at setup",
      DRAGGED[#DRAGGED] == "task form")
check("…a drag message still carries every field (the one-place rule), so "
   .. "nothing typed is lost to a grab", F.draft.title == "mid-drag")
_G.beginPanelDrag = nil
check("the movablePanels entry is there for ⌘-drag too", (function()
    for _, e in ipairs(_G.movablePanels or {}) do
        if e.name == "task form" then return true end
    end
end)())
check("🚨 the non-activating panel mask was requested, applied, and "
   .. "VERIFIED by read-back — what lets ⇪T take typing the moment it "
   .. "opens instead of after a click",
      F.nonActivatingApplied == true, tostring(F.nonActivatingWhy))
check("…the mask really is on the window",
      VIEW.style and (math.floor(VIEW.style / 128) % 2) == 1,
      tostring(VIEW.style))
msg("close", {})

-- a build whose hs.webview has no nonactivating mask must still open
-- the form — and say what was lost, not pretend
local savedMasks = hs.webview.windowMasks
hs.webview.windowMasks = nil
_G.taskFormShow()
check("no mask on this build → the form still opens, honestly reported",
      F.webview ~= nil and F.nonActivatingApplied == false
      and (printed[#printed] or ""):find("non%-activating") ~= nil,
      printed[#printed])
hs.webview.windowMasks = savedMasks
msg("close", {})

-- =====================================================================
out("6. the 📸 newest-screenshot button\n")
-- =====================================================================
_G.taskFormShow()
SERVICE_ANSWERS["screenshots.latest"] = "/od/2026 Screenshots/Screenshot X.png"
msg("latest", { title = "with a shot" })
check("the newest screenshot lands in the Attachment field",
      F.draft.attach == "/od/2026 Screenshots/Screenshot X.png", F.draft.attach)
check("…without losing the other fields", F.draft.title == "with a shot")
check("…and the page re-rendered showing it",
      LAST_HTML:find("Screenshot X.png", 1, true) ~= nil)

SERVICE_ANSWERS["screenshots.latest"] = nil
local alertsBefore = #ALERTS
msg("latest", { title = "with a shot" })
check("no screenshots yet → a clear alert, not a silent nothing",
      #ALERTS == alertsBefore + 1
      and (ALERTS[#ALERTS] or ""):find("creenshot") ~= nil, ALERTS[#ALERTS])
msg("close", {})

-- =====================================================================
out("7. drafts with hostile characters\n")
-- =====================================================================
F.draft.title = 'He said "hi" & <script>alert(1)</script>'
_G.taskFormShow()
check("quotes in the draft are escaped into the value attribute",
      LAST_HTML:find("&quot;hi&quot;", 1, true) ~= nil)
check("…and markup is neutralized", LAST_HTML:find("<script>alert", 1, true) == nil
      and LAST_HTML:find("&lt;script&gt;", 1, true) ~= nil)
msg("close", {})

-- =====================================================================
out("8. degrading — no submit, no webview\n")
-- =====================================================================
_G.taskFormShow()
local savedSubmit = _G.asanaSubmitTask
_G.asanaSubmitTask = nil
alertsBefore = #ALERTS
msg("submit", { title = "goes nowhere" })
check("submit with no _G.asanaSubmitTask alerts instead of crashing",
      #ALERTS == alertsBefore + 1)
check("…and keeps the form open with the draft", F.webview ~= nil
      and F.draft.title == "goes nowhere")
_G.asanaSubmitTask = savedSubmit
msg("close", {})

-- an old Hammerspoon with no WKWebView: task creation must still work
local savedWebview = hs.webview
hs.webview = nil
FALLBACKS = 0
_G.taskFormShow()
check("no webview → falls back to the pipe chooser, so a stripped build "
      .. "costs the form, not task creation", FALLBACKS == 1)
hs.webview = savedWebview

-- =====================================================================
out("9. 6.220.0 — the form FITS: two columns, and a pinned Create button\n")
-- =====================================================================
-- LL, with a screenshot of a form running off the bottom of his screen:
-- "Can you put the contents of this window hyper+t, so that the items
-- do not run down one long list and we can see the blue create task
-- button?" His project has a dozen custom fields; each one added 44 pt
-- to the window and the clamp was the SCREEN, so the button sat below
-- the bottom edge with no way to reach it.
local mine = 0
local function ck(label, cond, extra) mine = mine + 1; check(label, cond, extra) end

local SCREEN = { x = 0, y = 0, w = 1440, h = 900 }
local function enums(n)
    local t = {}
    for i = 1, n do
        t[#t + 1] = { gid = "E" .. i, name = "Field " .. i, subtype = "enum",
                      options = { { gid = "o", name = "one" } } }
    end
    return t
end

local w0, h0, c0 = F.sizeFor({}, SCREEN)
ck("no project fields: one column, the old 560 width", c0 == 1 and w0 == 560, w0)

local wN, hN, cN = F.sizeFor(enums(12), SCREEN)
ck("twelve project fields: TWO columns", cN == 2, cN)
ck("…and the wider window to carry them", wN == F.wideWidth, wN)
ck("🚨 THE HEIGHT NEVER PASSES form.maxHeight — the whole bug",
   hN <= F.maxHeight, hN)
ck("…and never comes within form.screenGap of the screen's own height",
   hN <= SCREEN.h - F.screenGap, hN)
local _, hShort = F.sizeFor(enums(12), { x = 0, y = 0, w = 1440, h = 700 })
ck("…on a SHORT screen the screen wins over maxHeight",
   hShort <= 700 - F.screenGap, hShort)
-- 6.223.0 — LL, on 6.220.0: "the canvas needs to be bigger so I don't
-- have to scroll". His eleven fields want ~1,090 pt; the old 760-pt
-- ceiling drew them behind a scroller on a screen with room to spare.
local _, hTall = F.sizeFor(enums(11), { x = 0, y = 0, w = 1800, h = 1440 })
ck("🚨 on a TALL screen eleven project fields are drawn WHOLE — the "
   .. "ceiling no longer cuts a form the display could hold",
   hTall >= F.height + 100 + math.ceil(11 / 2) * F.fieldH, hTall)
ck("…and the ceiling is still a number, not the whole display",
   hTall <= F.maxHeight and F.maxHeight < 1440, hTall)

-- the grid arithmetic, with the cap lifted out of the way: four fields
-- are TWO rows, not four. A mutation that lays them one per row makes
-- the two heights differ by 2 x fieldH and this fails.
local savedMax = F.maxHeight
F.maxHeight = 100000
local tall = { x = 0, y = 0, w = 1440, h = 100000 }
local _, h2 = F.sizeFor(enums(2), tall)
local _, h4 = F.sizeFor(enums(4), tall)
local _, h5 = F.sizeFor(enums(5), tall)
ck("two columns HALVE the rows: 4 fields cost exactly one row more than 2",
   h4 - h2 == F.fieldH, h4 - h2)
ck("…an odd count rounds up, never down (5 fields = 3 rows)",
   h5 - h4 == F.fieldH, h5 - h4)
local _, hSkip = F.sizeFor({ { gid = "X", name = "Formula",
                              subtype = "formula", options = {} } }, tall)
local _, hNone = F.sizeFor({}, tall)
ck("an unsupported subtype costs no height — it is not drawn",
   hSkip == hNone, hSkip .. " vs " .. hNone)
F.maxHeight = savedMax

-- the window actually opens at that size
_G.asanaCustomFields = enums(12)
_G.taskFormShow()
local wantW, wantH = F.sizeFor(_G.asanaCustomFields, SCREEN)
ck("the window opens at exactly the size sizeFor decided",
   VIEW.rect.w == wantW and VIEW.rect.h == wantH,
   VIEW.rect.w .. "x" .. VIEW.rect.h)

-- the page: three bands
local wrapCss = LAST_HTML:find("#wrap { flex:1 1 auto; min%-height:0; overflow%-y:auto")
ck("#wrap is the SCROLLER (flex:1, min-height:0, overflow-y:auto)",
   wrapCss ~= nil)
local footAt = LAST_HTML:find('<footer class="bar">', 1, true)
local btnAt  = LAST_HTML:find("Create task", 1, true)
local wrapAt = LAST_HTML:find('<div id="wrap">', 1, true)
-- OUTSIDE means the <div id="wrap"> is CLOSED before the footer opens,
-- which is a counting question, not an ordering one: a footer moved
-- back inside the scroller still comes after the wrap's opening tag.
local opens, closes = 0, 0
if footAt and wrapAt then
    local slice = LAST_HTML:sub(wrapAt, footAt)
    for _ in slice:gmatch("<div") do opens = opens + 1 end
    for _ in slice:gmatch("</div>") do closes = closes + 1 end
end
ck("🚨 THE CREATE BUTTON IS OUTSIDE THE SCROLLER — #wrap is closed "
   .. "before the footer opens, so a project with a dozen fields can "
   .. "never push the button off the bottom (LL's screenshot)",
   footAt ~= nil and btnAt ~= nil and wrapAt ~= nil
   and btnAt > footAt and opens == closes and opens > 0,
   opens .. " <div vs " .. closes .. " </div>")
ck("…and the footer is flex:none, so the scroller yields to it, not it "
   .. "to the scroller",
   LAST_HTML:find("footer.bar { flex:none", 1, true) ~= nil)
ck("the project fields sit in a two-column grid",
   LAST_HTML:find('<div class="cols">', 1, true) ~= nil
   and LAST_HTML:find("grid%-template%-columns:repeat%(2") ~= nil)
ck("…each cell puts its label ABOVE its control (an Asana field name is "
   .. "long and a 104-pt right gutter wrapped it over four lines)",
   LAST_HTML:find(".cols label { display:block; width:auto", 1, true) ~= nil)

_G.asanaCustomFields = {
    { gid = "M", name = "SAC Values", subtype = "multi_enum",
      options = { { gid = "a", name = "One" }, { gid = "b", name = "Two" } } },
    { gid = "E", name = "Priority", subtype = "enum",
      options = { { gid = "o", name = "High" } } },
}
msg("close", {})
_G.taskFormShow()
ck("a chips field SPANS both columns; an ordinary field does not",
   LAST_HTML:find('class="row cf%-row wide"') ~= nil
   and LAST_HTML:find('class="row cf%-row"') ~= nil)

msg("close", {})
_G.asanaCustomFields = {}
_G.taskFormShow()
ck("with no project fields there is no grid at all — the hint row stays",
   LAST_HTML:find('<div class="cols">', 1, true) == nil
   and LAST_HTML:find("project fields load shortly after boot", 1, true) ~= nil)

printed = {}
_G.taskFormReport()
local rep = table.concat(printed, "\n")
ck("_G.taskFormReport() names the window it drew and the pinned button",
   rep:find("TASK FORM", 1, true) ~= nil
   and rep:find("column", 1, true) ~= nil
   and rep:find("pinned in a footer", 1, true) ~= nil, rep)
msg("close", {})

check("§9 ran every one of its checks", mine == 20, mine)

-- =====================================================================
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("    ❌ " .. f .. "\n") end
out("\n")
os.exit(fail == 0 and 0 or 1)
