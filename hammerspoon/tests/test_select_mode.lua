-- =====================================================================
-- test_select_mode.lua — ☑️ select mode in the entry editors. 6.97.0
-- =====================================================================
--     lua5.4 test_select_mode.lua [/path/to/hammerspoon]
--
-- LL: "can we make anything that has an editor, a multi-select tool?"
-- The config has three entry editors. ⇪⇧V (clipboard) is covered in
-- test_clipboard §8; this suite holds the other two:
--
--   E1  ⇪⇧E (documents — the Activity Tracker's since 6.104.0, the
--       Document Watcher's before it): pick rows with Enter, delete them
--       TOGETHER, and the deletion is saved — not just displayed.
--   E2  ⇪⇧O (OCR history — modules/ocr_engine.lua since 6.105.0, init.lua
--       §5 before that): the same pattern, proven against the REAL
--       module through the real setup(core), so the shipped file and this
--       suite cannot drift apart.
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
              doAt    = function() return { stop = function() end } end,
              secondsSinceEpoch = function() return 1000 end },
    json = { decode = function() return nil end },
    caffeinate = { watcher = {
        screensDidLock = "lock", systemWillSleep = "sleep",
        new = function() return { start = function(self) return self end } end,
    } },
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
hs.configdir = "/config"
_G.choosers = {}
_G.diag = { say = function() end, warn = function() end }

local HYPER = {}
local CORE = {
    logsDir = "/logs",
    hostTag = "Test",
    adoptLegacyFile = function() end,
    warnWriteFailed = function() end,
    formatDuration = function(s)
        if s < 60 then return s .. "s" end
        local m = math.floor(s / 60)
        if m < 60 then return m .. "m " .. (s % 60) .. "s" end
        return math.floor(m / 60) .. "h " .. (m % 60) .. "m"
    end,
    -- Quote-aware, because one of the fixture titles below carries a comma
    -- of its own — a splitter that ignores quotes would file half a title
    -- as the seconds column and the row would silently vanish.
    splitCSVLine = function(line)
        local outF, field, i, inQ = {}, {}, 1, false
        while i <= #line do
            local ch = line:sub(i, i)
            if inQ then
                if ch == '"' then
                    if line:sub(i + 1, i + 1) == '"' then
                        field[#field + 1] = '"'; i = i + 1
                    else inQ = false end
                else field[#field + 1] = ch end
            elseif ch == '"' then inQ = true
            elseif ch == "," then outF[#outF + 1] = table.concat(field); field = {}
            else field[#field + 1] = ch end
            i = i + 1
        end
        outF[#outF + 1] = table.concat(field)
        return outF
    end,
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

-- ---- 1. ⇪⇧E — the document editor, now the Activity Tracker's (E1) ---
-- 6.104.0: this used to drive modules/document_watcher.lua, which was
-- retired into activity_tracker — the SAME select-mode contract, now over
-- rows DERIVED from the sessions the tracker already records rather than
-- a second CSV. Everything below is the old suite's expectations, pointed
-- at the surviving module: if the merge lost a behaviour, this fails.
out("   1. ⇪⇧E: pick several document rows, delete them together\n")
local ACTFILE = "/logs/activity_history-Test.csv"
FILES[ACTFILE] = "date,app,title,seconds\n"
    .. "2026-08-14,Excel,Budget.xlsx — Excel,720\n"
    .. "2026-08-15,Word,Report Q3.docx — Word,3930\n"
    .. '2026-08-15,Sublime Text,"Notes.md - Sublime Text",190\n'
    .. "2026-08-15,Slack,#general,600\n"
local M = dofile(HS .. "/modules/activity_tracker.lua")
M.setup(CORE)
local ed = _G.choosers.activityDocsEdit
local docs = _G.activityDocsForTest
check("three documents are derived from the sessions", #docs() == 3, #docs())
check("...and a window title that is not a filename is NOT one of them — "
      .. "a wrong entry is worse than a missing one", (function()
          for _, r in ipairs(docs()) do
              if r.file:find("general", 1, true) then return false end
          end
          return true
      end)())

HYPER["shift|e"]()
check("a fresh ⇪⇧E leads with ONE action row: ☑️ Delete several at once…",
      ed.rows[1] and ed.rows[1].action == "editselecton"
      and ed.rows[1].text:find("Delete several", 1, true) ~= nil)
check("...rows are newest first, longest first inside a day, and keep "
      .. "their one-at-a-time hint",
      ed.rows[2] and ed.rows[2].text:find("Report Q3.docx", 1, true) ~= nil
      and ed.rows[3].text:find("Notes.md", 1, true) ~= nil
      and ed.rows[4].text:find("Budget.xlsx", 1, true) ~= nil
      and ed.rows[2].subText:find("rename or delete", 1, true) ~= nil,
      ed.rows[2] and ed.rows[2].text)

ed.fn({ action = "editselecton" })
check("select mode re-renders: delete row + never-mind row, nothing picked",
      ed.rows[1].action == "deletetagged"
      and ed.rows[1].text:find("Nothing picked yet", 1, true) ~= nil
      and ed.rows[2].action == "editselectoff"
      and ed.shown == true)

ed.fn({ action = "edit", key = ed.rows[4].key })      -- Notes.md
ed.fn({ action = "edit", key = ed.rows[5].key })      -- Budget.xlsx
check("two picked: rows wear ✓ and the action row counts them",
      ed.rows[1].text:find("Delete the 2", 1, true) ~= nil
      and ed.rows[4].text:find("✓ ", 1, true) == 1
      and ed.rows[5].text:find("✓ ", 1, true) == 1,
      ed.rows[1].text)
ed.fn({ action = "edit", key = ed.rows[4].key })      -- unpick Notes.md
check("Enter on a picked row UNPICKS it",
      ed.rows[1].text:find("Delete the 1", 1, true) ~= nil)

ed.fn({ action = "edit", key = ed.rows[4].key })      -- pick it again
FILES[ACTFILE] = nil
ed.fn({ action = "deletetagged" })
check("🗑 deleting the picked rows removes exactly those documents",
      #docs() == 1 and docs()[1].file == "Report Q3.docx", #docs())
check("...and the deletion is SAVED, not just displayed",
      FILES[ACTFILE] ~= nil
      and FILES[ACTFILE]:find("Report Q3.docx", 1, true) ~= nil
      and FILES[ACTFILE]:find("Notes.md", 1, true) == nil
      and FILES[ACTFILE]:find("Budget.xlsx", 1, true) == nil)
check("...and a NON-document session is left completely alone by it — "
      .. "deleting a document must not quietly eat unrelated app time",
      FILES[ACTFILE]:find("#general", 1, true) ~= nil)
check("...announced with the count", alerted("Deleted 2"))

HYPER["shift|e"]()
ed.fn({ action = "editselecton" })
ed.fn({ action = "deletetagged" })
check("deleting with NOTHING picked deletes nothing and says so",
      #docs() == 1 and alerted("Nothing picked"))
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
      docs()[1].file == "Renamed.docx" and alerted("Renamed"), docs()[1].file)
check("...by rewriting the underlying session, so it survives a reload",
      FILES[ACTFILE]:find("Renamed.docx", 1, true) ~= nil)

-- ---- 1b. ⇪⇧W — the same rows, read-only, with COPY select mode ------
out("   1b. ⇪⇧W: the documents list, copying several together\n")
local lst = _G.choosers.activityDocs
HYPER["shift|w"]()
check("⇪⇧W leads with a tally, then the copy-several action row",
      lst.rows[1] and lst.rows[1].text:find("document", 1, true) ~= nil
      and lst.rows[2].action == "selecton", lst.rows[1] and lst.rows[1].text)
lst.fn({ action = "selecton" })
lst.fn({ action = "row", key = lst.rows[4].key })
check("picking a row counts it", lst.rows[2].text:find("Copy the 1", 1, true) ~= nil,
      lst.rows[2].text)
lst.fn({ action = "copytagged" })
check("copying the picked rows puts them on the clipboard, one per line",
      PASTEBOARD and PASTEBOARD:find("Renamed.docx", 1, true) ~= nil
      and alerted("Copied 1"), PASTEBOARD)

-- ---- 2. ⇪⇧O — the OCR editor, now its own module (E2) ---------------
-- 6.105.0: this used to LIFT a do...end block out of init.lua and compile
-- it with csvFile/warnWriteFailed/showPopup injected as upvalues, because
-- that block had no other way in. The engine is modules/ocr_engine.lua
-- now, so the suite loads the module the way Hammerspoon does and drives
-- the real setup(core). Same picker, same contract, no text surgery —
-- and no marker comment in init.lua that a tidy-up could silently break.
out("   2. ⇪⇧O: the OCR editor runs the REAL module\n")

local CSV = "/logs/image_text-Test.csv"
local OCRM = dofile(HS .. "/modules/ocr_engine.lua")
check("the OCR engine is a module with the standard contract",
      type(OCRM) == "table" and OCRM.name and OCRM.order
      and type(OCRM.setup) == "function" and OCRM.cheatsheet, OCRM and OCRM.name)
OCRM.setup(CORE)
check("...and it built its log path from logsDir + hostTag",
      _G.ocrEngine and _G.ocrEngine.csvFile == CSV,
      _G.ocrEngine and _G.ocrEngine.csvFile)

local oc = _G.choosers.ocrEdit
-- ⇪⇧O, claimed DIRECTLY now rather than through the chord map — the
-- same move clipboard_history made in 6.57.0.
local ocrEdit = HYPER["shift|o"]
check("the module built the picker and claimed ⇪⇧O",
      oc ~= nil and ocrEdit ~= nil)
check("...and ⇪O, the search, alongside it", HYPER["|o"] ~= nil)

ALERTS = {}
FILES[CSV] = nil
ocrEdit()
check("an empty history says so instead of opening an empty picker",
      alerted("OCR history is empty") and oc.rows == nil)

FILES[CSV] = '2026-08-14 09:00:00,"oldest text"\n'
          .. '2026-08-15 10:00:00,"middle text"\n'
          .. '2026-08-15 11:00:00,"newest text"\n'
ocrEdit()
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

ocrEdit()
check("a fresh ⇪⇧O starts UNPICKED with the remaining row (E3)",
      oc.rows[1].action == "selecton"
      and oc.rows[2].text:find("middle", 1, true) ~= nil)
PROMPT = { "Save", "middle text, corrected" }
oc.fn({ idx = oc.rows[2].idx })
check("one-at-a-time editing still works on the lifted source (E3)",
      FILES[CSV]:find("middle text, corrected", 1, true) ~= nil
      and alerted("OCR entry updated"))
PROMPT = { "Save", "" }
ocrEdit()
oc.fn({ idx = oc.rows[2].idx })
check("...and save-empty still deletes",
      FILES[CSV]:find("corrected", 1, true) == nil and alerted("OCR entry deleted"))

-- ---- 3. the OCR console is errors-only now (6.97.0) ------------------
out("   3. OCR success prints NOTHING — errors only\n")
-- LL: "Can't we reduce the OCR indexed to errors only?" A search of the
-- CODE (comments stripped — a comment quoting the old line must not
-- satisfy this) proves the success print is gone and the failure
-- warning is not. 6.105.0: read from the module, which is where that
-- code lives now.
local osrc = realIoOpen(HS .. "/modules/ocr_engine.lua", "r")
local OCR_SRC = osrc and osrc:read("*a") or "" ; if osrc then osrc:close() end
local code = OCR_SRC:gsub("\n%s*%-%-[^\n]*", "\n")
check("the OCR engine source was found at all", #OCR_SRC > 2000, #OCR_SRC)
check("the 'OCR indexed N chars' success line is gone",
      code:find("OCR indexed", 1, true) == nil)
check("...while a failed OCR-log write still warns",
      code:find('warnWriteFailed%("OCR log"%)') ~= nil)
-- 🚨 AND init.lua NO LONGER CARRIES ANY OF IT. A migration that leaves a
-- copy behind is two copies that drift, which is the failure 6.104.0's
-- Document Watcher merge existed to end.
local isrc = realIoOpen(HS .. "/init.lua", "r")
local INIT_SRC = isrc and isrc:read("*a") or "" ; if isrc then isrc:close() end
local iCode = INIT_SRC:gsub("\n%s*%-%-[^\n]*", "\n")
check("init.lua kept no OCR engine code — only the service calls",
      iCode:find("ocrWriteFinderComment", 1, true) == nil
      and iCode:find("clipboardImageFilePaths", 1, true) == nil
      and iCode:find("processAutomaticImageOCR", 1, true) == nil
      and iCode:find("loadOCRHistory", 1, true) == nil)
check("...and it reaches the engine through the registry instead",
      iCode:find('ocr%.clipboardFiles') ~= nil
      and iCode:find('ocr%.tagFiles') ~= nil
      and iCode:find('ocr%.image') ~= nil)

-- =====================================================================
io.open = realIoOpen
out(string.format("\n── test_select_mode: %d passed, %d failed\n", pass, fail))
if fail > 0 then
    for _, x in ipairs(failures) do out("   ❌ " .. x .. "\n") end
    os.exit(1)
end
os.exit(0)
