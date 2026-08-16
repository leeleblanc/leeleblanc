-- =====================================================================
-- test_select_mode.lua — ☑️ select mode in the entry editors. 6.97.0
-- =====================================================================
--     lua5.4 test_select_mode.lua [/path/to/hammerspoon]
--
-- LL: "can we make anything that has an editor, a multi-select tool?"
-- The config has three entry editors. ⇪⇧V (clipboard) is covered in
-- test_clipboard §8; this suite holds the other two:
--
--   E1  ⇪⇧E (Document Watcher): pick rows with Enter, delete them
--       TOGETHER, and the deletion is saved — not just displayed.
--   E2  ⇪⇧O (OCR history, init.lua §5): the same pattern, proven on the
--       REAL source lifted out of init.lua the way test_hyper_key does,
--       so init.lua and this suite cannot drift apart.
--   E3  ONE-AT-A-TIME STILL WORKS in both: select mode is an extra
--       gear, not a replacement, and a fresh open always starts
--       unpicked — stale ✓ marks delete the wrong rows.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        io.write("   ❌ " .. failures[#failures] .. "\n")
    end
end
local function out(s) io.write(s) end

-- ---- a Mac in tables --------------------------------------------------
local FILES, ALERTS, PASTEBOARD, printed = {}, {}, nil, {}
local PROMPT = { "Cancel", "" }        -- what hs.dialog.textPrompt answers
local BOUND = {}                       -- "mods|key" -> fn (hotkey stub)
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function alerted(needle)
    for _, a in ipairs(ALERTS) do if a:find(needle, 1, true) then return true end end
end

local realIoOpen = io.open
io.open = function(path, mode)
    mode = mode or "r"
    if mode:find("w") then
        local buf = {}
        return { write = function(_, s) buf[#buf + 1] = s end,
                 close = function() FILES[path] = table.concat(buf) end }
    end
    if FILES[path] == nil then return nil end
    local content, done = FILES[path], false
    return { read = function() if done then return nil end done = true return content end,
             close = function() end }
end

local function newChooserStub(fn)
    local c = { fn = fn }
    for _, m in ipairs({ "placeholderText", "show", "width", "searchSubText",
                         "query", "hide" }) do
        c[m] = function(self) return self end
    end
    function c:choices(x) self.rows = x ; return self end
    function c:queryChangedCallback(f) self.qcb = f ; return self end
    return c
end

hs = {
    chooser = { new = newChooserStub },
    dialog = { textPrompt = function() return PROMPT[1], PROMPT[2] end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    timer = { doEvery = function() return { stop = function() end } end,
              secondsSinceEpoch = function() return 1000 end },
    pasteboard = { setContents = function(t) PASTEBOARD = t ; return true end },
    application = { frontmostApplication = function() return nil end },
    host = { idleTime = function() return 0 end },
    hotkey = { bind = function(mods, key, fn)
        local ms = {}
        for _, m in ipairs(mods or {}) do ms[#ms + 1] = m end
        table.sort(ms)
        BOUND[table.concat(ms, "+") .. "|" .. key] = fn
    end },
}
_G.choosers = {}
_G.diag = { say = function() end, warn = function() end }

local HYPER = {}
local CORE = {
    logsDir = "/logs",
    showPopup = function(c) c.shown = true end,
    csvQuote = function(s)
        if s:find('[,"]') then return '"' .. s:gsub('"', '""') .. '"' end
        return s
    end,
    hyperAddShortcut = function(mods, key, fn)
        local ms = {}
        for _, m in ipairs(mods or {}) do ms[#ms + 1] = m end
        table.sort(ms)
        HYPER[table.concat(ms, "+") .. "|" .. key] = fn
    end,
    provide = function() end,
}

-- =====================================================================
out("── test_select_mode (config at " .. HS .. ")\n")

-- ---- 1. ⇪⇧E — the Document Watcher editor (E1) ----------------------
out("   1. ⇪⇧E: pick several document rows, delete them together\n")
local DOCFILE = "/logs/doc_wather.csv"
FILES[DOCFILE] = "Date,Time of day,File name,Working time\n"
    .. "2026-08-14,09:10,Budget.xlsx,0:12:00\n"
    .. "2026-08-15,10:20,Report Q3.docx,1:05:30\n"
    .. "2026-08-15,14:40,Notes.md,0:03:10\n"
local M = dofile(HS .. "/modules/document_watcher.lua")
M.setup(CORE)
local ed = _G.choosers.docWatcherEdit
check("the module loaded its three rows", #_G.docRowsForTest() == 3,
      #_G.docRowsForTest())

HYPER["shift|e"]()
check("a fresh ⇪⇧E leads with ONE action row: ☑️ Delete several at once…",
      ed.rows[1] and ed.rows[1].action == "editselecton"
      and ed.rows[1].text:find("Delete several", 1, true) ~= nil)
check("...rows are newest first and keep their one-at-a-time hint",
      ed.rows[2] and ed.rows[2].text:find("Notes.md", 1, true) ~= nil
      and ed.rows[2].subText:find("rename or delete", 1, true) ~= nil,
      ed.rows[2] and ed.rows[2].text)

ed.fn({ action = "editselecton" })
check("select mode re-renders: delete row + never-mind row, nothing picked",
      ed.rows[1].action == "deletetagged"
      and ed.rows[1].text:find("Nothing picked yet", 1, true) ~= nil
      and ed.rows[2].action == "editselectoff"
      and ed.shown == true)

ed.fn({ action = "edit", key = ed.rows[3].key })      -- Notes.md
ed.fn({ action = "edit", key = ed.rows[5].key })      -- Budget.xlsx
check("two picked: rows wear ✓ and the action row counts them",
      ed.rows[1].text:find("Delete the 2", 1, true) ~= nil
      and ed.rows[3].text:find("✓ ", 1, true) == 1
      and ed.rows[5].text:find("✓ ", 1, true) == 1,
      ed.rows[1].text)
ed.fn({ action = "edit", key = ed.rows[3].key })      -- unpick Notes.md
check("Enter on a picked row UNPICKS it",
      ed.rows[1].text:find("Delete the 1", 1, true) ~= nil)

ed.fn({ action = "edit", key = ed.rows[3].key })      -- pick it again
FILES[DOCFILE] = nil
ed.fn({ action = "deletetagged" })
check("🗑 deleting the picked rows removes exactly those from the log",
      #_G.docRowsForTest() == 1
      and _G.docRowsForTest()[1].file == "Report Q3.docx",
      #_G.docRowsForTest())
check("...and the deletion is SAVED, not just displayed",
      FILES[DOCFILE] ~= nil
      and FILES[DOCFILE]:find("Report Q3.docx", 1, true) ~= nil
      and FILES[DOCFILE]:find("Notes.md", 1, true) == nil
      and FILES[DOCFILE]:find("Budget.xlsx", 1, true) == nil)
check("...announced with the count", alerted("Deleted 2"))

HYPER["shift|e"]()
ed.fn({ action = "editselecton" })
ed.fn({ action = "deletetagged" })
check("deleting with NOTHING picked deletes nothing and says so",
      #_G.docRowsForTest() == 1 and alerted("Nothing picked"))
ed.fn({ action = "editselecton" })
ed.fn({ action = "edit", key = ed.rows[3].key })
ed.fn({ action = "editselectoff" })
check("✖️ never mind forgets the picks and returns to one-at-a-time",
      ed.rows[1].action == "editselecton")
ed.fn({ action = "editselecton" })
ed.fn({ action = "edit", key = ed.rows[3].key })
HYPER["shift|e"]()
check("🚨 a fresh ⇪⇧E always starts UNPICKED (E3)",
      ed.rows[1].action == "editselecton"
      and ed.rows[2].text:find("✓ ", 1, true) ~= 1,
      ed.rows[1].action)

PROMPT = { "OK", "Renamed.docx" }
ed.fn({ action = "edit", key = ed.rows[2].key })
check("one-at-a-time renaming still works (E3)",
      _G.docRowsForTest()[1].file == "Renamed.docx" and alerted("Renamed"))

-- ---- 2. ⇪⇧O — the OCR editor, lifted from init.lua (E2) -------------
out("   2. ⇪⇧O: the OCR editor runs the REAL init.lua source\n")
local f = realIoOpen(HS .. "/init.lua", "r")
local INIT_SRC = f and f:read("*a") or "" ; if f then f:close() end
local marker = "end -- do...end (⌘⌃⌥⇧O OCR edit/delete picker locals)"
local head = INIT_SRC:find("EDIT or DELETE an OCR history entry", 1, true)
local tail = INIT_SRC:find(marker, 1, true)
check("the ⇪⇧O block can be lifted out of init.lua", head and tail and head < tail)

local CSV = "/logs/image_text.csv"
if head and tail then
    local s = INIT_SRC:find("\ndo\n", head, true)
    local block = INIT_SRC:sub(s, tail + #marker)
    local chunk, err = load(
        "local csvFile, warnWriteFailed, showPopup = ...\n" .. block,
        "ocr-edit-block")
    check("...and it compiles as a chunk", chunk ~= nil, err)
    if chunk then
        chunk(CSV, function() printed[#printed + 1] = "writeFailed" end,
              function(c) c.shown = true end)
    end
end
local oc = _G.choosers.ocrEdit
check("the lifted block built the picker and bound ⌘⌃⌥⇧O",
      oc ~= nil and BOUND["alt+cmd+ctrl+shift|O"] ~= nil)

ALERTS = {}
FILES[CSV] = nil
BOUND["alt+cmd+ctrl+shift|O"]()
check("an empty history says so instead of opening an empty picker",
      alerted("OCR history is empty") and oc.rows == nil)

FILES[CSV] = '2026-08-14 09:00:00,"oldest text"\n'
          .. '2026-08-15 10:00:00,"middle text"\n'
          .. '2026-08-15 11:00:00,"newest text"\n'
BOUND["alt+cmd+ctrl+shift|O"]()
check("⇪⇧O leads with the select-mode offer, then rows NEWEST FIRST",
      oc.rows[1].action == "selecton"
      and oc.rows[2].text:find("newest", 1, true) ~= nil
      and oc.rows[4].text:find("oldest", 1, true) ~= nil,
      oc.rows[2] and oc.rows[2].text)

oc.fn({ action = "selecton" })
check("select mode: delete + never-mind rows, reopened for the next pick",
      oc.rows[1].action == "deletetagged"
      and oc.rows[2].action == "selectoff" and oc.shown == true)
oc.fn({ idx = oc.rows[3].idx })                        -- newest
oc.fn({ idx = oc.rows[5].idx })                        -- oldest
check("two picked, counted, wearing ✓",
      oc.rows[1].text:find("Delete the 2", 1, true) ~= nil
      and oc.rows[3].text:find("✓ ", 1, true) == 1)

FILES[CSV] = nil
oc.fn({ action = "deletetagged" })
check("🗑 the bulk delete REWRITES the CSV without the picked rows",
      FILES[CSV] ~= nil
      and FILES[CSV]:find("middle text", 1, true) ~= nil
      and FILES[CSV]:find("newest text", 1, true) == nil
      and FILES[CSV]:find("oldest text", 1, true) == nil, FILES[CSV])
check("...announced with the count", alerted("Deleted 2 OCR entries"))

BOUND["alt+cmd+ctrl+shift|O"]()
check("a fresh ⇪⇧O starts UNPICKED with the remaining row (E3)",
      oc.rows[1].action == "selecton"
      and oc.rows[2].text:find("middle", 1, true) ~= nil)
PROMPT = { "Save", "middle text, corrected" }
oc.fn({ idx = oc.rows[2].idx })
check("one-at-a-time editing still works on the lifted source (E3)",
      FILES[CSV]:find("middle text, corrected", 1, true) ~= nil
      and alerted("OCR entry updated"))
PROMPT = { "Save", "" }
BOUND["alt+cmd+ctrl+shift|O"]()
oc.fn({ idx = oc.rows[2].idx })
check("...and save-empty still deletes",
      FILES[CSV]:find("corrected", 1, true) == nil and alerted("OCR entry deleted"))

-- ---- 3. the OCR console is errors-only now (6.97.0) ------------------
out("   3. OCR success prints NOTHING — errors only\n")
-- LL: "Can't we reduce the OCR indexed to errors only?" A search of the
-- CODE (comments stripped — a comment quoting the old line must not
-- satisfy this) proves the success print is gone and the failure
-- warning is not.
local code = INIT_SRC:gsub("\n%s*%-%-[^\n]*", "\n")
check("the 'OCR indexed N chars' success line is gone from init.lua",
      code:find("OCR indexed", 1, true) == nil)
check("...while a failed OCR-log write still warns",
      code:find('warnWriteFailed%("OCR log"%)') ~= nil)

-- =====================================================================
io.open = realIoOpen
out(string.format("\n── test_select_mode: %d passed, %d failed\n", pass, fail))
if fail > 0 then
    for _, x in ipairs(failures) do out("   ❌ " .. x .. "\n") end
    os.exit(1)
end
os.exit(0)
