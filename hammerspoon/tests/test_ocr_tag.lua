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

out(("\n── test_ocr_tag: %d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
