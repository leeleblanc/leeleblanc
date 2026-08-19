-- =====================================================================
-- test_unified.lua — Unified Search's Lua half (⇪space)
-- =====================================================================
--     lua5.4 test_unified.lua [/path/to/hammerspoon]
--
-- Executes modules/unified_search.lua against fixture STORES — a fake
-- clipboard cache, a commands service, a screenshot folder, notes files
-- with real ── stamps ──, an Asana history, OCR / document / file-move
-- CSVs, a pad queue — and checks that gather() reads every one of them
-- the way its own picker does, that the page JSON survives hostile
-- content ("</script>" included), and that the bridge's pick / path /
-- close / dragStart actions do exactly what the panel promises.
-- The page's JavaScript half is executed for real by test_unified_js.js.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- ---- a fake filesystem that honors the tail-read protocol --------------
-- tailRead opens "rb", seeks to the end for the size, seeks back, drops a
-- partial line with read("*l") and slurps read("*a") — the stub file
-- object supports exactly that.
local FILES = {}
local realOpen = io.open
io.open = function(path, mode)
    local body = FILES[path]
    if body == nil then return nil end
    local pos = 0
    return {
        seek = function(_, whence, offset)
            if whence == "end" then pos = #body
            elseif whence == "set" then pos = offset or 0 end
            return pos
        end,
        read = function(_, what)
            if what == "*l" or what == "l" then
                local nl = body:find("\n", pos + 1, true)
                if not nl then pos = #body return nil end
                local line = body:sub(pos + 1, nl - 1)
                pos = nl
                return line
            end
            local rest = body:sub(pos + 1)
            pos = #body
            return rest
        end,
        close = function() end,
    }
end

-- ---- the stub Mac -------------------------------------------------------
local ALERTS, PB, CLIPOBJ = {}, nil, nil
local TIMERS = {}
local function drain()
    local list = TIMERS
    TIMERS = {}
    for _, t in ipairs(list) do if not t.stopped then t.fn() end end
end
local LAST_HTML, BRIDGE, VIEW = nil, nil, nil
local DRAGGED = {}
_G.beginPanelDrag = function(name) DRAGGED[#DRAGGED + 1] = name return true end

hs = {
    webview = {
        usercontent = {
            new = function(name)
                local uc = { name = name }
                function uc:setCallback(fn) BRIDGE = fn return self end
                return uc
            end,
        },
        new = function(rect, opts, uc)
            local v = { rect = rect, deleted = false, flags = {} }
            function v:html(s) LAST_HTML = s return self end
            function v:show() self.shown = true return self end
            function v:delete() self.deleted = true return self end
            function v:windowTitle(t) self.title = t return self end
            function v:allowTextEntry() self.flags.text = true return self end
            function v:closeOnEscape() self.flags.esc = true return self end
            function v:level(l) self.flags.level = l return self end
            function v:behaviorAsLabels() self.flags.spaces = true return self end
            function v:bringToFront() self.flags.front = true return self end
            function v:frame(f)
                if f then self.rect = f return self end
                return self.rect
            end
            VIEW = v
            return v
        end,
    },
    drawing = { windowLevels = { floating = 5 } },
    screen = {
        mainScreen = function()
            return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
        end,
        allScreens = function()
            return { { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end } }
        end,
    },
    image = {
        imageFromPath = function(p)
            return {
                __path = p,
                setSize = function(self, sz)
                    return {
                        encodeAsURLString = function()
                            return "data:image/png;base64,THUMB-" .. p
                        end,
                    }
                end,
            }
        end,
    },
    pasteboard = {
        setContents = function(t) PB = t return true end,
        writeObjects = function(o) CLIPOBJ = o return true end,
    },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    timer = {
        secondsSinceEpoch = function() return 1000 end,
        -- runTool defers by one run-loop turn so the panel is gone before
        -- the tool opens; the suite fires the queue by hand.
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    fs = { attributes = function() return nil end },
}
-- 🖐 6.107.0 — hs.settings, where the dragged position now survives a
-- reload. A plain table stands in for the plist; what is under test is
-- that the panel writes ONE key, debounces the write, and validates
-- whatever comes back.
local SETTINGS = {}
hs.settings = {
    set = function(k, v) SETTINGS[k] = v end,
    get = function(k) return SETTINGS[k] end,
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
local CLAIMS = {}
_G.claimEscape = function(name, priority, active, handle)
    CLAIMS[name] = { priority = priority, active = active, handle = handle }
    return true
end

-- ---- the fixture stores ---------------------------------------------------
_G.clipboardCache = {
    { date = "Aug 15 10:00", text = "newest copy — receipt total" },
    { date = "Aug 14 09:00", text = "</script><b>hostile</b> copy" },
    { date = "Aug 13 08:00", text = ("long "):rep(200) },   -- 1000 chars
}
_G.screenshots = {
    list = function()
        return {
            { name = "Screenshot A.png", path = "/od/shots/Screenshot A.png",
              mtime = 100, size = 2 * 1024 * 1024 },
            { name = "receipt scan.png", path = "/od/shots/receipt scan.png",
              mtime = 90, size = 50 * 1024 },
        }
    end,
}
_G.quickAppend = {
    targets = { { name = "Inbox", file = "inbox.txt" } },
    pathFor = function(t) return "/logs/notes/" .. t.file end,
}
FILES["/logs/notes/inbox.txt"] =
    "── 2026-08-14 09:00 ──\nfirst note line\nsecond line\n\n"
    .. "── 2026-08-15 08:00 ──\nnewest note about receipts\n\n"
_G.asanaTaskHistory = {
    { title = "Old task",    timestamp = 100, desc = "",        assignee = "" },
    { title = "Newest task", timestamp = 200, desc = "the why", assignee = "Lee" },
}
FILES["/logs/image_text-TestMac.csv"] =
    '2026-08-14 10:00:00,"Hello ""OCR"" line\\nsecond"\n'
    .. '2026-08-15 09:00:00,"Receipt total 42.50"\n'
FILES["/logs/doc_wather.csv"] =
    "Date,Time of day,File name,Working time\n"
    .. '2026-08-14,09:12,"Report.docx",1h 05m\n'
    .. '2026-08-15,10:00,"notes.md",12m\n'
-- 📅 6.115.0 — DELIBERATELY MIXED. The file tracker's CSV moved its date
-- to the first column, and this reader gets only the TAIL of the file
-- (256 KB), so it can never see a header to tell it which layout it is
-- holding. Row one is the new layout, row two is the pre-6.115.0 one, and
-- both must come out right — a real file genuinely contains both when the
-- upgrade lands mid-session.
FILES["/logs/file_changes-TestMac.csv"] =
    "timestamp,file_name,new_name,present_location,moved_location,event,epoch\n"
    .. '"2026-08-15 11:00","old.txt","new.txt","/a","/b","renamed",1000\n'
    .. '"solo.png","","/c","","2026-08-15 12:00","created",1001\n'
_G.capturePad = {
    queue  = { { text = "queued pad note", createdAt = 300 } },
    parked = { { text = "parked pad note", createdAt = 200 } },
    applyNonActivating = function(v) v.nonActivating = true return true end,
}

-- 🔧 the tools source reads the ASSEMBLED cheat sheet, exactly as the
-- standalone Tool Picker did before 6.104.0 folded it in here.
_G.cheatSheet = { groups = function()
    return {
        { title = "🎯 MOUSE GRID (⇪X — type 3 letters)", entries = {
            { "⇪X", "Jump the pointer anywhere" } } },
        { title = "🔗 URL CLEANER (⇪K)", entries = {
            { "⇪K",  "Clean the copied link of trackers" },
            { "⇪⇧K", "Undo the last clean" } } },
        { title = "❓ HELP", entries = {
            { "⇪/", "Toggle this cheat sheet" },
            { "⇪=", "Add your own entry" } } },
    }
end }

local RAN, REGISTRY = {}, {}
_G.service = {
    has  = function(n) return REGISTRY[n] ~= nil end,
    call = function(n, ...) 
        if REGISTRY[n] then return REGISTRY[n](...) end
        return nil                      -- PRINTS and returns in the real one
    end,
}
local function publish(n, fn) REGISTRY[n] = fn end
publish("mouseGrid.show", function() RAN[#RAN + 1] = "grid" return true end)

local PROVIDED, HYPER = {}, {}
local CORE = {
    logsDir = "/logs", hostTag = "TestMac",
    provide = function(n, f) PROVIDED[n] = f end,
    call    = function(n, ...)
        if n == "commands.entries" then
            return {
                { cmd = "git status",          when = "2026-08-15 10:00" },
                { cmd = "grep receipt log.txt" },
            }
        end
    end,
    hyperAddShortcut = function(mods, key, fn)
        local ms = {}
        for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms)
        HYPER[table.concat(ms, "+") .. "|" .. key] = fn
    end,
    resolveBaseScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
    end,
}

-- =====================================================================
out("── Unified Search: every store, one picker ──\n")
out("\n1. contract & wiring\n")
-- =====================================================================
local M = dofile(HS .. "/modules/unified_search.lua")
check("module loads and has setup()", type(M.setup) == "function")
M.setup(CORE)
local U = _G.unifiedSearch
check("module table exported", type(U) == "table")
check("⇪space is claimed", type(HYPER["|space"]) == "function")
check("…and ⇪⇧space (the screenshot view)",
      type(HYPER["shift|space"]) == "function")
check("…and ⇪⇧/ — the Tool Picker's key still works, and lands where its "
      .. "content moved to (6.104.0)", type(HYPER["shift|/"]) == "function")
check("unified.show is provided", type(PROVIDED["unified.show"]) == "function")
check("listed for Window Move", (function()
    for _, e in ipairs(_G.movablePanels or {}) do
        if e.name == "unified search" then return true end
    end
    return false
end)())

-- =====================================================================
out("2. gather — every store, read like its own picker\n")
-- =====================================================================
U.gather()
local rows = U.rows
byTag = {}
for _, r in ipairs(rows) do
    byTag[r.tag] = byTag[r.tag] or {}
    table.insert(byTag[r.tag], r)
end
check("every store contributed", (function()
    for _, t in ipairs({ "clip", "cmd", "shots", "note", "asana",
                         "ocr", "doc", "file", "pad" }) do
        if not byTag[t] or #byTag[t] == 0 then return false, t end
    end
    return true
end)())
check("clipboard leads the list (it is the unified CLIPBOARD picker)",
      rows[1].tag == "clip" and rows[1].text:find("newest copy") == 1)
check("clipboard rows keep their FULL text for ⏎",
      byTag.clip[3].full:len() == 1000 and byTag.clip[3].text:len() <= U.preview,
      byTag.clip[3].full:len())
check("commands arrive through the ⇪H service",
      byTag.cmd[1].text == "git status" and byTag.cmd[2].full == "grep receipt log.txt")
-- 📅 6.115.0 — BOTH CSV LAYOUTS, READ FROM THE SAME FILE.
-- Getting this wrong does not raise: every field is a string, so a
-- 6.114.0 row read with 6.115.0 indices lists the folder as the file's
-- name and the word "renamed" as its date. Wrong, plausible, and silent
-- — which is exactly the kind of thing that needs asserting by value.
do
    local function fileRow(name)
        for _, r in ipairs(byTag.file or {}) do
            if (r.text or ""):find(name, 1, true) then return r end
        end
        return nil
    end
    local newRow, oldRow = fileRow("old.txt"), fileRow("solo.png")

    check("a NEW-layout row (date first) is read correctly",
          newRow ~= nil and newRow.text == "old.txt → new.txt"
          and newRow.path == "/b/new.txt",
          newRow and newRow.text)
    check("…with its event and date on the sub line, in that order",
          newRow ~= nil and newRow.sub == "renamed · 2026-08-15 11:00",
          newRow and newRow.sub)
    check("🚨 an OLD-layout row in the SAME file is still read correctly — "
          .. "this reader only ever sees the tail of the file, so it can "
          .. "never check a header to find out which layout it holds",
          oldRow ~= nil and oldRow.text == "solo.png"
          and oldRow.path == "/c/solo.png",
          oldRow and oldRow.text)
    check("🚨 …and its DATE is the date, not the word 'created' — reading "
          .. "an old row with new indices produces exactly that, without "
          .. "raising",
          oldRow ~= nil and oldRow.sub == "created · 2026-08-15 12:00",
          oldRow and oldRow.sub)
    check("neither CSV header row became a search result",
          fileRow("file_name") == nil and fileRow("File Name") == nil)
end
check("screenshots carry kind=image, a path and a thumbnail",
      byTag.shots[1].kind == "image"
      and byTag.shots[1].path == "/od/shots/Screenshot A.png"
      and (byTag.shots[1].img or ""):find("^data:image") ~= nil)
check("…and a human sub line (date · size)",
      (byTag.shots[1].sub or ""):find("MB") ~= nil
      and (byTag.shots[2].sub or ""):find("KB") ~= nil, byTag.shots[1].sub)
check("notes split on the ── stamp ── lines, newest first",
      byTag.note[1].full == "newest note about receipts"
      and byTag.note[2].full == "first note line\nsecond line",
      byTag.note[1].full)
check("…and say which file and when",
      (byTag.note[1].sub or ""):find("Inbox") ~= nil
      and (byTag.note[1].sub or ""):find("2026%-08%-15") ~= nil)
check("asana tasks newest first, description carried in full",
      byTag.asana[1].text == "Newest task"
      and byTag.asana[1].full == "Newest task\nthe why"
      and (byTag.asana[1].sub or ""):find("Lee") ~= nil)
check("OCR rows un-escape the CSV (quotes and newlines), newest first",
      byTag.ocr[1].full == "Receipt total 42.50"
      and byTag.ocr[2].full == 'Hello "OCR" line\nsecond',
      byTag.ocr[2].full)
check("documents newest first, worked time in the sub line",
      byTag.doc[1].text == "notes.md"
      and (byTag.doc[1].sub or ""):find("worked 12m") ~= nil, byTag.doc[1].sub)
-- (The rename / created rows these two checks used to assert by INDEX are
--  now asserted by name in section 2, alongside the layout they arrived
--  in. Indexing byTag.file[2] CRASHED the whole suite the moment a reader
--  change dropped a row, which reports a bug as "attempt to index a nil
--  value" three hundred lines away from the cause.)
check("…and the two file rows are the only ones — a reader that accepted "
      .. "a CSV header row would silently add a third",
      #(byTag.file or {}) == 2, #(byTag.file or {}))
check("the CSV header rows were never mistaken for data",
      #byTag.doc == 2 and #byTag.file == 2)
check("pad queue AND parked notes are searchable",
      byTag.pad[1].full == "queued pad note"
      and byTag.pad[2].full == "parked pad note")

check("caps hold — a 400-row store cannot drown the page", (function()
    local old = U.maxPer.clip
    U.maxPer.clip = 2
    U.gather()
    local n = U.counts.clip
    U.maxPer.clip = old
    U.gather()
    return n == 2
end)())

-- =====================================================================
out("2b. 🔧 the tools source — the Tool Picker, folded in (6.104.0)\n")
-- =====================================================================
U.gather()
byTag = {}
for _, r in ipairs(U.rows) do
    byTag[r.tag] = byTag[r.tag] or {}
    table.insert(byTag[r.tag], r)
end
local tools = byTag.tool or {}
check("every cheat sheet entry in every group became a tool row",
      #tools == 5, #tools)
check("🔧 tools come LAST, so what you SAVED stays above what is always "
      .. "there", U.rows[#U.rows].tag == "tool" and U.rows[1].tag ~= "tool")
check("a tool row carries its key, its description and its group",
      (function()
    for _, r in ipairs(tools) do
        if r.keys == "⇪K" then
            return r.text:find("trackers", 1, true) ~= nil
               and r.sub == "⇪K"
               and r.src:find("URL CLEANER", 1, true) ~= nil
        end
    end
end)())
check("…and the group has lost its emoji and its (key) parenthetical — it "
      .. "is a label, not a title", (function()
    for _, r in ipairs(tools) do
        if r.keys == "⇪X" then
            return r.src == "MOUSE GRID" 
        end
    end
end)(), (function()
    for _, r in ipairs(tools) do if r.keys == "⇪X" then return r.src end end
end)())
check("the @tool tag rides in the haystack, so ⇪⇧/ can pin the source",
      U.rowsJson():find("@tool", 1, true) ~= nil)
check("a runnable key is joined to its service, an ordinary row is not",
      (function()
    local grid, help
    for _, r in ipairs(tools) do
        if r.keys == "⇪X" then grid = r end
        if r.keys == "⇪=" then help = r end
    end
    return grid and grid.service == "mouseGrid.show"
           and help and help.service == nil
end)())

out("   -- ⏎ on a 🔧 row RUNS it, or hands back the key --\n")
local gridRow, helpRow
for _, r in ipairs(tools) do
    if r.keys == "⇪X" then gridRow = r end
    if r.keys == "⇪=" then helpRow = r end
end
U.show()
ALERTS = {}
BRIDGE({ body = { a = "pick", id = gridRow.id } })
check("the panel is put away BEFORE the tool runs — two panels racing for "
      .. "the keyboard is how the first keystroke gets eaten",
      U.webview == nil and #RAN == 0)
drain()
check("…and then it runs", RAN[1] == "grid", RAN[1])

U.show()
PB = nil
BRIDGE({ body = { a = "pick", id = helpRow.id } })
check("a row with no runnable service copies its key instead — being told "
      .. "the key is the FALLBACK, not the failure",
      PB == "⇪=" and U.webview == nil, tostring(PB))

check("🚨 a row naming a service nothing publishes copies the key rather "
      .. "than reporting a run — service.call does not throw on a missing "
      .. "provider, so a pcall alone would call it a success", (function()
    PB = nil
    RAN = {}
    U.show()
    U.runTool({ keys = "⇪Z", service = "nope.missing" })
    drain()
    return PB == "⇪Z" and #RAN == 0 and U.webview == nil
end)(), tostring(PB))
check("a service that IS published but THROWS is reported as the real "
      .. "failure it is, not quietly downgraded to 'here is the key'",
      (function()
    publish("boom.now", function() error("kaboom") end)
    ALERTS, PB = {}, nil
    U.show()
    U.runTool({ keys = "⇪B", service = "boom.now" })
    drain()
    for _, a in ipairs(ALERTS) do
        if a:find("failed", 1, true) then return PB == nil end
    end
    return false
end)())

out("   -- the run map is checked against BOTH tables it joins --\n")
local recorded = {}
_G.notices = { record = function(_, _, c) recorded[#recorded + 1] = tostring(c) end }
U.toolsVerified = false
U.gather()
check("a run-map entry naming a service nothing publishes is REPORTED, "
      .. "not left to be found the day you rely on it",
      #recorded == 1 and recorded[1]:find("url.cleanClipboard", 1, true) ~= nil,
      recorded[1])
check("…and an entry whose KEY no cheat sheet row uses is reported too — "
      .. "checking one side of a join catches half the drift",
      recorded[1]:find("no cheat sheet entry uses that key", 1, true) ~= nil)
check("…once, not on every open", (function()
    U.gather(); return #recorded == 1
end)())
_G.notices = nil

-- =====================================================================
out("3. the page — JSON survives hostile content, rows are BIG\n")
-- =====================================================================
local json = U.rowsJson()
check("a copied </script> cannot end the page's script tag",
      json:find("</script>", 1, true) == nil
      and json:find("<\\/script>", 1, true) ~= nil)
check("quotes are escaped and no raw control character leaks",
      json:find('\\"OCR\\"', 1, true) ~= nil
      and json:find("\n", 1, true) == nil)
check("ids are stable and 1-based",
      json:find('{"id":1,', 1, true) == 2)   -- 2: right after the [

local html = U.buildHtml("@shots ")
check("one search field, autofocused prefill",
      html:find('id="q"', 1, true) ~= nil
      and html:find('PREFILL = "@shots ', 1, true) ~= nil)
check("the rows are the 50%-larger kind — 19px titles, 84px thumbs",
      html:find("font-size:19px", 1, true) ~= nil
      and html:find("height:84px", 1, true) ~= nil)
-- 6.92.0 — the tag list OUTGREW the input box ("I can't read all the
-- tool tips"): the placeholder now teaches the RULE and each section
-- header carries its own tag, where it can never be clipped.
check("the placeholder teaches the @tag rule, short enough to read whole",
      html:find("a @tag pins one source", 1, true) ~= nil
      and html:find('placeholder="[^"]*@clip') == nil)
check("...and every section header shows its own tag instead",
      html:find("<span class=\"tag\">@' + esc(SRCS[s].tag)", 1, true) ~= nil)
check("the header advertises drag · copy · path · Esc",
      html:find("drag here", 1, true) ~= nil
      and html:find("⌘⏎ path", 1, true) ~= nil)
check("🎨 6.90.0 — the shared card colors ride in when published, last "
   .. "in the stylesheet so the cascade lets them win", (function()
    _G.uiStyle = { cssOverride = function()
        return "body{background:#171a21;color:rgba(255,255,255,0.97)}"
    end }
    local themed = U.buildHtml("")
    _G.uiStyle = nil
    local at = themed:find("body{background:#171a21", 1, true)
    return at ~= nil and at < themed:find("</style>", 1, true)
           and html:find("#171a21", 1, true) == nil   -- absent when unset
end)())

-- =====================================================================
out("4. the window\n")
-- =====================================================================
check("show() returns true and builds the panel", U.show() == true)
check("the webview can take the keyboard and Esc closes it",
      VIEW.flags.text == true and VIEW.flags.esc == true)
check("floating, on every Space, brought forward",
      VIEW.flags.level == 5 and VIEW.flags.spaces == true
      and VIEW.flags.front == true)
check("the pad's non-activating plumbing was borrowed",
      VIEW.nonActivating == true)
check("toggle closes it", (function()
    U.toggle()
    return U.webview == nil and VIEW.deleted == true
end)())
check("⇪⇧space reopens pre-filtered to screenshots", (function()
    HYPER["shift|space"]()
    return (LAST_HTML or ""):find('PREFILL = "@shots ', 1, true) ~= nil
end)())

-- =====================================================================
out("5. the bridge — pick, path, close, dragStart\n")
-- =====================================================================
U.show()
local function rowWhere(fn)
    for _, r in ipairs(U.rows) do if fn(r) then return r end end
end

local noteRow = rowWhere(function(r) return r.tag == "note" end)
BRIDGE({ body = { a = "pick", id = noteRow.id } })
check("⏎ on a text row copies its FULL text and closes",
      PB == "newest note about receipts" and U.webview == nil
      and (ALERTS[#ALERTS] or ""):find("Copied") ~= nil, PB)

U.show()
local shotRow = rowWhere(function(r) return r.kind == "image" end)
BRIDGE({ body = { a = "pick", id = shotRow.id } })
check("⏎ on a screenshot copies the IMAGE itself",
      CLIPOBJ ~= nil and CLIPOBJ.__path == shotRow.path
      and (ALERTS[#ALERTS] or ""):find("clipboard") ~= nil)

U.show()
BRIDGE({ body = { a = "path", id = shotRow.id } })
check("⌘⏎ copies the file PATH instead (the ⇪⇧4 convention)",
      PB == shotRow.path
      and (ALERTS[#ALERTS] or ""):find("Path copied") ~= nil, PB)

U.show()
local clipRow = rowWhere(function(r) return r.tag == "clip" end)
BRIDGE({ body = { a = "path", id = clipRow.id } })
check("⌘⏎ on a row with no path degrades to the copy",
      PB == clipRow.full)

U.show()
BRIDGE({ body = { a = "close" } })
check("Escape's close message closes", U.webview == nil)

U.show()
BRIDGE({ body = { a = "dragStart" } })
check("the header grab is handed to Window Move by name",
      DRAGGED[#DRAGGED] == "unified search")
BRIDGE({ body = "not-a-table" })
check("a malformed message is shrugged off", U.webview ~= nil)
U.hide()

-- =====================================================================
out("5b. 6.93.0 — the remembered position, and the escape claim\n")
-- =====================================================================
U.pos = nil
U.show()
check("first open is centered", VIEW.rect.x == (1440 - U.width) / 2)
local entry
for _, e in ipairs(_G.movablePanels or {}) do
    if e.name == "unified search" then entry = e end
end
entry.move(101, 77)
check("dragging writes the remembered position",
      U.pos and U.pos.x == 101 and U.pos.y == 77)
U.hide() ; U.show()
check("🖐 A REMEMBERED POSITION WINS — reopened where dragged",
      VIEW.rect.x == 101 and VIEW.rect.y == 77)
U.hide()
U.pos = { x = 9999, y = 9999 }
U.show()
check("an unplugged screen's memory re-centers instead",
      VIEW.rect.x == (1440 - U.width) / 2)
-- ---- 6.107.0: and it survives a RELOAD, not just a reopen ------------
-- Same gap the cheat sheet had in 6.106.0: uni is rebuilt every reload,
-- so the position went with it and the box came back centred.
U.hide()
SETTINGS = {}
U.pos = nil
local function drainTimers()
    local queued = TIMERS ; TIMERS = {}
    for _, t in ipairs(queued) do
        if not t.stopped then pcall(t.fn) end
    end
end

entry.move(101, 77)
check("🚨 the write is DEBOUNCED — a drag tick does not touch settings yet",
      SETTINGS["unifiedSearch.pos"] == nil, SETTINGS["unifiedSearch.pos"])
-- The drag layer calls move() from a repeating timer for the whole drag,
-- so saving inline would write tens of times a second for as long as the
-- mouse is down. Only the last one should land.
entry.move(150, 90)
entry.move(202, 120)
drainTimers()
check("...and after you settle, exactly one key holds the LAST position",
      SETTINGS["unifiedSearch.pos"]
      and SETTINGS["unifiedSearch.pos"].x == 202
      and SETTINGS["unifiedSearch.pos"].y == 120
      and next(SETTINGS, next(SETTINGS)) == nil,
      SETTINGS["unifiedSearch.pos"] and SETTINGS["unifiedSearch.pos"].x)

-- A fresh setup() is what a reload is.
local function reload()
    _G.movablePanels = {}
    local M2 = dofile(HS .. "/modules/unified_search.lua")
    M2.setup(CORE)
    return _G.unifiedSearch
end
local R = reload()
check("🚨 a RELOAD picks the position back up",
      R.pos and R.pos.x == 202 and R.pos.y == 120, R.pos and R.pos.x)

-- Validated on the way in: a plist can hand back anything.
for _, j in ipairs({
    { "a string",            "202,120" },
    { "a number",            42 },
    { "no coordinates",      { w = 10 } },
    { "a NaN",               { x = 0/0, y = 10 } },
    { "an infinity",         { x = math.huge, y = 10 } },
    { "coordinates as text", { x = "left", y = "top" } },
}) do
    SETTINGS["unifiedSearch.pos"] = j[2]
    local r = reload()
    check("junk in settings — " .. j[1] .. " — reads as NO position",
          r.pos == nil, r.pos and tostring(r.pos.x))
end

SETTINGS["unifiedSearch.pos"] = { x = "202", y = "120" }
check("numeric strings still count as a position",
      (function() local r = reload() return r.pos and r.pos.x == 202 end)())

SETTINGS["unifiedSearch.pos"] = { x = 202, y = 120 }
local R2 = reload()
_G.unifiedCenter()
check("_G.unifiedCenter() forgets the stored position",
      SETTINGS["unifiedSearch.pos"] == nil and R2.pos == nil)

R2.rememberPos = false
SETTINGS["unifiedSearch.pos"] = nil
R2.savePos({ x = 1, y = 2 })
drainTimers()
check("rememberPos = false stops it being saved",
      SETTINGS["unifiedSearch.pos"] == nil)
check("...and stops it being read", R2.loadPos() == nil)

-- Back to the live module for the rest of the suite.
SETTINGS = {}
U = reload()
U.show()

check("the escape claim is 'unified' and live while open",
      CLAIMS.unified ~= nil and CLAIMS.unified.active() == true)
CLAIMS.unified.handle()
check("…its handle closes the panel — the sheet closes after",
      U.webview == nil and CLAIMS.unified.active() == false)

-- =====================================================================
out("6. a hostile Monday — stores missing, files gone\n")
-- =====================================================================
_G.clipboardCache, _G.screenshots, _G.quickAppend = nil, nil, nil
_G.asanaTaskHistory, _G.capturePad = nil, nil
for p in pairs(FILES) do FILES[p] = nil end
CORE.call = function() return nil end
U.gather()
check("with every SAVED store gone, the tools are still listed — they are "
      .. "read from the live cheat sheet, not from disk", (function()
    for _, r in ipairs(U.rows) do if r.tag ~= "tool" then return false end end
    return #U.rows > 0
end)(), #U.rows)
local savedSheet = _G.cheatSheet
_G.cheatSheet = nil
U.gather()
check("no store and no cheat sheet at all still means an empty list, not "
      .. "an error", #U.rows == 0, #U.rows)
check("…and the panel still opens over it", U.show() == true and U.webview ~= nil)
U.hide()
_G.cheatSheet = savedSheet

-- =====================================================================
io.write(("\n%d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    io.write("FAILURES:\n")
    for _, f in ipairs(failures) do io.write("   ❌ " .. f .. "\n") end
    os.exit(1)
end
