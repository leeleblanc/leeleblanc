-- =====================================================================
-- test_ocr_tag.lua — 🏷 which files does the clipboard point at? 6.98.0
-- =====================================================================
--     lua5.4 test_ocr_tag.lua [/path/to/hammerspoon]
--
-- LL hit this in the Console:
--     🏷 OCR tag: clipboard has file URL(s) but no image files matched
--        ↳ first candidate: no file extension found — raw value:
--          "/.file/id=6571367.18736568/"
-- and asked: "Isn't this non-breaking? If not, do we even need to show
-- that line or only show when it errors?"
--
-- Two things were wrong with the old behaviour, and this suite pins the
-- fixes to the REAL init.lua source (lifted the way test_hyper_key and
-- test_select_mode do, so init.lua and this suite cannot drift):
--
--   T1  "/.file/id=…" is a macOS FILE-REFERENCE path — a file named by
--       id, not by name. It has no extension, so a REAL IMAGE copied
--       that way was skipped. Now it is resolved through the filesystem
--       (realpath) first and judged by its real name — the image OCRs.
--   T2  ERRORS ONLY. Copying non-image files is normal and prints
--       NOTHING now. A line appears only for a genuine anomaly (a
--       supported image that isn't readable, an unresolvable reference
--       path), and it carries the ⚠️ mark so core/console.lua files it
--       under NONBREAKING.

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
local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local function saidAnything() return #printed > 0 end
local function said(needle)
    for _, l in ipairs(printed) do if l:find(needle, 1, true) then return true end end
end

local CLIPBOARD_ITEMS = {}     -- what readAllData answers
local DISK       = {}          -- path -> "file" (hs.fs.attributes mode)
local REALPATHS  = {}          -- what pathToAbsolute answers
local RESOLVED_ARGS = {}       -- every arg pathToAbsolute was given

hs = {
    pasteboard = {
        readAllData = function() return CLIPBOARD_ITEMS end,
        readURL     = function() return nil end,
        readString  = function() return nil end,
    },
    fs = {
        attributes = function(path, field)
            if DISK[path] then
                if field == "mode" then return DISK[path] end
                return { mode = DISK[path] }
            end
            return nil
        end,
        pathToAbsolute = function(path)
            table.insert(RESOLVED_ARGS, path)
            return REALPATHS[path]
        end,
    },
}

-- ---- load the REAL module ---------------------------------------------
-- 6.105.0: this used to cut the block out of init.lua by string search
-- and compile it with stripToQwerty injected. The engine is a module now,
-- so it loads the way Hammerspoon loads it and the real function is
-- called by name — no marker strings, nothing a reformat can break.
-- The rest of the module needs stubs it does not get here (hs.chooser,
-- hs.task); every one of those calls is inside a pcall in the module, on
-- purpose, so setup() completes and the pasteboard reader is reachable.
hs.chooser = { new = function()
    local c = {}
    setmetatable(c, { __index = function() return function(self) return self end end })
    return c
end }
_G.choosers = {}

local CORE = {
    logsDir = "/logs",
    hostTag = "Test",
    adoptLegacyFile  = function() end,
    warnWriteFailed  = function() end,
    showPopup        = function() end,
    hyperAddShortcut = function() end,
    provide          = function() end,
}

local OCRM = dofile(HS .. "/modules/ocr_engine.lua")
check("the OCR engine module loads", type(OCRM) == "table"
      and type(OCRM.setup) == "function")
local okSetup, setupErr = pcall(OCRM.setup, CORE)
check("...and its setup() completes without a real hs", okSetup, setupErr)
local clipboardImageFilePaths = _G.ocrEngine and _G.ocrEngine.clipboardFiles
check("...and exposes the clipboard reader",
      type(clipboardImageFilePaths) == "function")
printed = {}   -- setup() may print; the checks below count lines

local function reset()
    printed, CLIPBOARD_ITEMS, RESOLVED_ARGS = {}, {}, {}
    DISK, REALPATHS = {}, {}
end

-- =====================================================================
out("\n=== T1. File-reference paths (/.file/id=…) resolve to the real file ===\n")

reset()
DISK["/Users/lee/IMG_0001.heic"] = "file"
REALPATHS["/.file/id=6571367.18736568"] = "/Users/lee/IMG_0001.heic"
CLIPBOARD_ITEMS = { { ["public.file-url"] = "file:///.file/id=6571367.18736568/" } }
local paths = clipboardImageFilePaths()
check("LL's exact case: the id-named image IS found now",
      #paths == 1 and paths[1] == "/Users/lee/IMG_0001.heic",
      paths[1] or "none")
check("the trailing slash is stripped before resolving",
      RESOLVED_ARGS[1] == "/.file/id=6571367.18736568", RESOLVED_ARGS[1])
check("...and a successful resolve prints nothing", not saidAnything(),
      printed[1])

reset()
DISK["/Users/lee/shot.png"] = "file"
REALPATHS["/.file/id=1.2"] = "/Users/lee/shot.png"
CLIPBOARD_ITEMS = {
    { ["public.file-url"] = "file:///Users/lee/shot.png" },
    { ["public.file-url"] = "file:///.file/id=1.2/" },
}
paths = clipboardImageFilePaths()
check("the same file arriving by name AND by reference is ONE path, not two",
      #paths == 1 and paths[1] == "/Users/lee/shot.png", #paths)

reset()
REALPATHS["/.file/id=9.9"] = "/Users/lee/report.docx"
DISK["/Users/lee/report.docx"] = "file"
CLIPBOARD_ITEMS = { { ["public.file-url"] = "file:///.file/id=9.9/" } }
paths = clipboardImageFilePaths()
check("a reference that resolves to a NON-image is a normal miss",
      #paths == 0)
check("...and normal misses print nothing", not saidAnything(), printed[1])

out("\n=== T2. Errors only: normal misses are silent, anomalies say so ===\n")

reset()
DISK["/Users/lee/notes.docx"] = "file"
CLIPBOARD_ITEMS = { { ["public.file-url"] = "file:///Users/lee/notes.docx" } }
paths = clipboardImageFilePaths()
check("⌘C on an ordinary non-image file prints NOTHING",
      #paths == 0 and not saidAnything(), printed[1])

reset()
CLIPBOARD_ITEMS = { { ["public.file-url"] = "file:///.file/id=404.404/" } }
paths = clipboardImageFilePaths()
check("an UNRESOLVABLE reference path is a real anomaly — one line",
      #paths == 0 and #printed == 1, #printed)
check("...the line carries the ⚠️ mark (Console files it NONBREAKING)",
      printed[1] and printed[1]:find("⚠️", 1, true) == 1, printed[1])
check("...and says the path would not resolve",
      said("would not resolve"))

reset()
CLIPBOARD_ITEMS = { { ["public.file-url"] = "file:///Users/lee/ghost.png" } }
paths = clipboardImageFilePaths()   -- .png but nothing at that path
check("a supported image that is NOT readable is also worth one line",
      #paths == 0 and #printed == 1, #printed)
check("...and names the problem", said("not a readable local file"))

reset()
DISK["/Users/lee/two words.png"] = "file"
CLIPBOARD_ITEMS = { { ["public.file-url"] = "file:///Users/lee/two%20words.png" } }
paths = clipboardImageFilePaths()
check("percent-encoded names still decode (unchanged 6.11.x behaviour)",
      #paths == 1 and paths[1] == "/Users/lee/two words.png", paths[1])

out("\n=== T3. The old chatty lines are really gone from the engine ===\n")

-- comments stripped, so a remembering comment can't fake a match
local msrc = io.open(HS .. "/modules/ocr_engine.lua", "r")
local OCR_SRC = msrc and msrc:read("*a") or "" ; if msrc then msrc:close() end
local CODE = ("\n" .. OCR_SRC):gsub("\n%s*%-%-[^\n]*", "\n")
check("the engine source was found", #OCR_SRC > 2000, #OCR_SRC)
check("the 'clipboard has file URL(s) but no image files matched' line is gone",
      CODE:find("no image files matched", 1, true) == nil)
check("the '↳ first candidate' companion line is gone",
      CODE:find("first candidate:", 1, true) == nil)
check("resolution goes through the filesystem (pathToAbsolute is wired in)",
      CODE:find("pathToAbsolute", 1, true) ~= nil)
check("failure paths still print (the errors-only rule keeps its errors)",
      CODE:find("⚠️ OCR tag:", 1, true) ~= nil)

-- =====================================================================
out("\n=== T4. ✍️ 6.115.0 — the entry editor is a WINDOW ===\n")
-- =====================================================================
-- LL: "Edit OCR is too small — give me a window like notepad", and
-- separately "it doesn't come to the front for an immediately editable
-- window, I have to click on it".
--
-- It was hs.dialog.textPrompt: a fixed-size NSAlert wrapped around a
-- ONE-LINE NSTextField. It cannot be resized, cannot scroll, and Return
-- presses the default button rather than inserting a newline — while the
-- thing being edited is OCR output, which is multi-line by nature.
--
-- 🚨 THE FALLBACK IS TESTED AS HARD AS THE WINDOW. This has to work on
-- the managed work Mac, where hs.webview is the piece most likely to be
-- absent, and a rewrite that turned ⇪⇧O into a dead key there would be a
-- worse outcome than the small box ever was.
do
    local DIR = (os.getenv("TMPDIR") or "/tmp"):gsub("/$", "")
                .. "/hs-ocred-" .. tostring(os.time()) .. "-" .. tostring(math.random(9999))
    os.execute("mkdir -p '" .. DIR .. "'")
    local CSVF = DIR .. "/image_text-Test.csv"
    local function putCsv(body)
        local h = io.open(CSVF, "w") ; if h then h:write(body); h:close() end
    end
    local function getCsv()
        local h = io.open(CSVF, "r") ; if not h then return nil end
        local s = h:read("*a"); h:close(); return s
    end

    -- Two entries, the second deliberately multi-line and quote-bearing —
    -- the exact content the one-line field could not show.
    putCsv('2026-08-18 09:00:00,"short one"\n'
           .. '2026-08-19 11:17:32,"All Snippets\\nsecond line\\nthird ""quoted"" line"\n')

    -- ---- a Mac WITH a webview ----------------------------------------
    local VIEWS, ALERTS2, PROMPTED = {}, {}, {}
    local function mkView(rect)
        local v = { shown = false, front = false, textEntry = nil, html = nil,
                    deleted = false,
                    -- The stub keeps the rect it was CONSTRUCTED with. A
                    -- stub that returned a made-up frame would report the
                    -- box as correctly sized no matter what the module
                    -- asked for, which is the one thing being checked.
                    rect = rect or { x = 0, y = 0, w = 0, h = 0 } }
        function v:windowTitle() return self end
        function v:allowTextEntry(b) self.textEntry = b; return self end
        function v:level() return self end
        function v:behaviorAsLabels() return self end
        function v:html(h) self.html = h; return self end
        function v:show() self.shown = true; return self end
        function v:bringToFront() self.front = true; return self end
        function v:frame(f) if f then self.rect = f end return self.rect end
        function v:delete() self.deleted = true; return self end
        VIEWS[#VIEWS + 1] = v
        return v
    end
    hs.webview = {
        new = function(rect) return mkView(rect) end,
        usercontent = { new = function()
            local u = {} ; function u:setCallback(fn) self.cb = fn; return self end
            return u
        end },
    }
    hs.drawing = { windowLevels = { floating = 25 } }
    hs.screen  = { mainScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1800, h = 1000 } end }
    end }
    hs.timer   = { doEvery = function() return { stop = function() end } end }
    hs.alert   = { show = function(m) ALERTS2[#ALERTS2 + 1] = tostring(m) end }
    hs.dialog  = { textPrompt = function(title, msg, deflt)
        PROMPTED[#PROMPTED + 1] = { title = title, msg = msg, deflt = deflt }
        return "Save", "typed into the small box"
    end }
    _G.movablePanels, _G.choosers = {}, {}

    local M2 = dofile(HS .. "/modules/ocr_engine.lua")
    M2.setup({
        logsDir = DIR, hostTag = "Test",
        adoptLegacyFile  = function() end,
        warnWriteFailed  = function() end,
        showPopup        = function() end,
        hyperAddShortcut = function() end,
        provide          = function() end,
    })
    local E = _G.ocrEngine
    check("the editor API is exposed", type(E.openEditor) == "function"
          and type(E.applyEdit) == "function"
          and type(E.editorHtml) == "function")

    E.edit()                     -- loads the snapshot from the CSV
    check("⇪⇧O reads both entries out of the CSV", (function()
        local okOpen = E.openEditor(2)
        return okOpen and #VIEWS == 1
    end)(), #VIEWS)

    local v = VIEWS[1]
    check("🎯 the box takes keystrokes — allowTextEntry(true) is what makes "
          .. "an hs.webview able to become the key window at all",
          v and v.textEntry == true)
    check("🎯 ...and it comes to the FRONT on open. This is the 'I have to "
          .. "click on it' report, and it is one call",
          v and v.front == true and v.shown == true)
    check("the window is a real size, not an alert", (function()
        return v and v.rect.w >= 600 and v.rect.h >= 400
    end)(), v and (v.rect.w .. "x" .. v.rect.h))

    local html = v and v.html or ""
    check("🚨 it is a multi-line TEXTAREA — the whole complaint was a "
          .. "one-line field", html:find("<textarea", 1, true) ~= nil)
    check("...with real height, not one row", (function()
        local rows = tonumber(html:match('rows="(%d+)"') or "0")
        return rows >= 8
    end)(), html:match('rows="(%d+)"'))
    check("...and it is FOCUSED by the page itself, caret at the end",
          html:find("t.focus()", 1, true) ~= nil
          and html:find("setSelectionRange", 1, true) ~= nil)
    check("the entry's text is in the box", html:find("All Snippets", 1, true) ~= nil)
    check("🚨 newlines survive into the box — the old control could not "
          .. "even accept a Return, so multi-line OCR was untouchable",
          html:find("second line", 1, true) ~= nil
          and html:find("third", 1, true) ~= nil)
    check("🚨 the text is HTML-ESCAPED — OCR output is arbitrary text off "
          .. "someone's screen, and a stray < would eat the rest of the box",
          html:find("&quot;quoted&quot;", 1, true) ~= nil)
    check("⌘⏎ saves and Esc cancels", html:find("metaKey", 1, true) ~= nil
          and html:find("Escape", 1, true) ~= nil)
    check("there is a Delete button — 'save it empty to delete' is a fine "
          .. "rule and a terrible thing to have to discover",
          html:find("a:'delete'", 1, true) ~= nil)
    check("the header is a drag handle, like every other window here",
          html:find("'drag'", 1, true) ~= nil
          and html:find("hdr", 1, true) ~= nil)
    check("the page talks back on the ocrEdit channel, not another "
          .. "window's", html:find("messageHandlers.ocrEdit", 1, true) ~= nil)

    -- Saving through the real message handler, not by calling applyEdit.
    E.handleEditorMessage({ a = "save", text = "edited text" })
    check("⌘⏎ writes the edit to the CSV",
          (getCsv() or ""):find("edited text", 1, true) ~= nil, getCsv())
    check("...and closes the window", v.deleted == true)
    check("...and the OTHER entry is untouched",
          (getCsv() or ""):find("short one", 1, true) ~= nil)

    -- Deleting through the button.
    E.edit()
    E.openEditor(1)
    E.handleEditorMessage({ a = "delete" })
    check("the Delete button removes that entry",
          (getCsv() or ""):find("short one", 1, true) == nil, getCsv())
    check("...and leaves the rest of the log alone",
          (getCsv() or ""):find("edited text", 1, true) ~= nil)

    -- Emptying the box still deletes — the documented rule, kept.
    E.edit()
    E.openEditor(1)
    E.handleEditorMessage({ a = "save", text = "   \n  " })
    check("a box emptied to whitespace still deletes the entry",
          (getCsv() or "") == "" or (getCsv() or ""):find("edited text", 1, true) == nil,
          getCsv())

    -- 🚨 The stale-index bug the non-modal window makes reachable.
    putCsv('2026-08-18 09:00:00,"first"\n2026-08-19 09:00:00,"second"\n')
    E.edit()
    E.openEditor(2)
    local staleView = VIEWS[#VIEWS]
    E.edit()          -- ⇪⇧O again: re-reads the CSV into a NEW snapshot
    check("🚨 pressing ⇪⇧O again CLOSES the open editor. It holds an index "
          .. "into the previous snapshot, and saving it after a reload "
          .. "would overwrite whatever entry now sits at that position",
          staleView.deleted == true)
    E.handleEditorMessage({ a = "save", text = "should go nowhere" })
    check("...so a save from the abandoned box writes nothing",
          (getCsv() or ""):find("should go nowhere", 1, true) == nil, getCsv())

    check("the editor is listed for ⇪⇧W, like every other panel", (function()
        for _, p in ipairs(_G.movablePanels or {}) do
            if (p.name or ""):find("OCR") then return true end
        end
        return false
    end)())

    -- ---- a Mac WITHOUT a webview (the managed work Mac) --------------
    hs.webview = nil
    _G.movablePanels, _G.choosers = {}, {}
    putCsv('2026-08-19 11:17:32,"needs the fallback"\n')
    local M3 = dofile(HS .. "/modules/ocr_engine.lua")
    M3.setup({
        logsDir = DIR, hostTag = "Test",
        adoptLegacyFile  = function() end,
        warnWriteFailed  = function() end,
        showPopup        = function() end,
        hyperAddShortcut = function() end,
        provide          = function() end,
    })
    local E2 = _G.ocrEngine
    PROMPTED = {}
    E2.edit()
    local okFall = E2.openEditor(1)
    check("🚨 no hs.webview falls back to the small prompt rather than "
          .. "doing nothing — a worse box still edits the entry, a dead "
          .. "key does not", okFall == true and #PROMPTED == 1)
    check("...pre-filled with the entry, so the fallback is the same edit",
          PROMPTED[1] and PROMPTED[1].deflt == "needs the fallback",
          PROMPTED[1] and PROMPTED[1].deflt)
    check("...and it actually saves what the prompt returned",
          (getCsv() or ""):find("typed into the small box", 1, true) ~= nil, getCsv())

    os.execute("rm -rf '" .. DIR .. "'")
end

out("\n=== T5. The one-line prompt is no longer the primary editor ===\n")
check("🚨 the chooser opens the WINDOW, not a prompt — a leftover "
      .. "textPrompt call on the Enter path would keep the old box",
      CODE:find("ocr.openEditor(choice.idx)", 1, true) ~= nil)
check("...and hs.dialog.textPrompt is INVOKED exactly once, in the "
      .. "no-webview fallback", (function()
    -- Counted as calls, not as mentions: the fallback's own failure
    -- message names the function in a string, and a check that counted
    -- occurrences would have to be loosened every time the module
    -- explains itself — which is how a real second call slips back in.
    local _, direct = CODE:gsub("hs%.dialog%.textPrompt%s*%(", "")
    local _, viaPcall = CODE:gsub("pcall%(hs%.dialog%.textPrompt", "")
    return direct == 0 and viaPcall == 1
end)())
check("the editor html is built by the module, not borrowed from another "
      .. "window's channel", CODE:find("messageHandlers.ocrEdit", 1, true) ~= nil)

out(("\n── test_ocr_tag: %d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
