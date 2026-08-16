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
    timer = { secondsSinceEpoch = function() return 1000 end },
    fs = { attributes = function() return nil end },
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
FILES["/logs/file_changes-TestMac.csv"] =
    "File Name,New Name,Present Location,Moved Location,Timestamp,Event\n"
    .. '"old.txt","new.txt","/a","/b","2026-08-15 11:00","renamed"\n'
    .. '"solo.png","","/c","","2026-08-15 12:00","created"\n'
_G.capturePad = {
    queue  = { { text = "queued pad note", createdAt = 300 } },
    parked = { { text = "parked pad note", createdAt = 200 } },
    applyNonActivating = function(v) v.nonActivating = true return true end,
}

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
check("unified.show is provided", type(PROVIDED["unified.show"]) == "function")
check("listed for Window Move", (function()
    for _, e in ipairs(_G.movablePanels or {}) do
        if e.name == "unified search" then return true end
    end
    return false
end)())

-- =====================================================================
out("2. gather — all nine stores, read like their own pickers\n")
-- =====================================================================
U.gather()
local rows = U.rows
local byTag = {}
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
check("a rename reads old → new and points at the NEW path",
      byTag.file[2].text == "old.txt → new.txt"
      and byTag.file[2].path == "/b/new.txt", byTag.file[2].path)
check("…a created file resolves its path too, newest event first",
      byTag.file[1].path == "/c/solo.png"
      and (byTag.file[1].sub or ""):find("created") ~= nil)
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
check("no store at all still means an empty list, not an error",
      #U.rows == 0)
check("…and the panel still opens over it", U.show() == true and U.webview ~= nil)
U.hide()

-- =====================================================================
io.write(("\n%d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    io.write("FAILURES:\n")
    for _, f in ipairs(failures) do io.write("   ❌ " .. f .. "\n") end
    os.exit(1)
end
