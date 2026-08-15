-- =====================================================================
-- test_screenshots.lua — capture to OneDrive AND the clipboard (⇪4)
-- =====================================================================
--     lua5.4 test_screenshots.lua [/path/to/hammerspoon]
--
-- Executes modules/screenshots.lua against a stubbed hs. The stub keeps
-- a fake filesystem in a table and a fake clipboard in a variable, so
-- the suite can drive the REAL capture flow end to end: hotkey → task →
-- "screencapture wrote a file" → clipboard, including the two outcomes
-- macOS actually produces (a file, or Esc and no file).
--
-- THE RULE THIS SUITE ENFORCES ABOVE ALL OTHERS: the file is the half
-- that must never be lost. A capture that saved but failed to copy must
-- say so; a CANCELLED capture must do nothing at all — no alert, no
-- clipboard write, no empty file left behind.

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
local HOME  = "/home/test"
local DIR   = HOME .. "/Library/CloudStorage/OneDrive-Personal/2026 Screenshots"
local FILES = {}       -- path -> { size=, modification= }
local DIRS  = { [HOME .. "/Library/CloudStorage/OneDrive-Personal"] = true }
local ALERTS, TASKS, CHOICES_SET = {}, {}, nil
local CLIP  = { kind = "empty" }
local MODS  = {}       -- what checkKeyboardModifiers answers

hs = {
    fs = {
        attributes = function(path, key)
            if DIRS[path] then
                if key == "mode" then return "directory" end
                return { mode = "directory" }
            end
            local f = FILES[path]
            if not f then return nil end
            if key then return f[key] end
            return f
        end,
        mkdir = function(path) DIRS[path] = true; return true end,
        dir = function(path)
            if not DIRS[path] then error("no such directory: " .. path) end
            local names, i = {}, 0
            local prefix = path .. "/"
            for p in pairs(FILES) do
                if p:sub(1, #prefix) == prefix and not p:sub(#prefix + 1):find("/") then
                    names[#names + 1] = p:sub(#prefix + 1)
                end
            end
            table.sort(names)
            return function()
                i = i + 1
                return names[i]
            end
        end,
    },
    task = {
        new = function(cmd, cb, args)
            local t = { cmd = cmd, cb = cb, args = args, started = false }
            function t:start() self.started = true; return true end
            table.insert(TASKS, t)
            return t
        end,
    },
    image = {
        imageFromPath = function(p)
            if not FILES[p] then return nil end
            local img = { __path = p }
            function img:setSize() return self end
            return img
        end,
    },
    pasteboard = {
        writeObjects = function(o) CLIP = { kind = "image", v = o }; return true end,
        setContents  = function(s) CLIP = { kind = "text",  v = s }; return true end,
    },
    eventtap = { checkKeyboardModifiers = function() return MODS end,
                 new = function(types, fn)
                     return { start = function(s) return s end,
                              stop  = function(s) return s end, fn = fn }
                 end,
                 event = { types = { keyDown = 10 },
                           newScrollEvent = function()
                               return { post = function() end }
                           end } },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    chooser = {
        new = function(cb)
            local c = { cb = cb }
            function c:choices(t) CHOICES_SET = t; return self end
            function c:placeholderText(t) c.placeholder = t; return self end
            function c:rows(n) c.nrows = n; return self end
            function c:queryChangedCallback(f) c.qcb = f; return self end
            function c:show() c.shown = true; return self end
            return c
        end,
    },
    canvas = {
        windowLevels = { overlay = 1 },
        new = function(frame)
            local cv = { frame = frame, elements = {} }
            setmetatable(cv, { __index = function(t, k)
                if type(k) == "number" then return t.elements[k] end
                return rawget(getmetatable(t), k)
            end })
            local mt = getmetatable(cv)
            mt.appendElements = function(self, ...)
                for _, e in ipairs({ ... }) do
                    table.insert(self.elements, e)
                end
                return self
            end
            mt.level = function(self) return self end
            mt.behaviorAsLabels = function(self) return self end
            mt.canvasMouseEvents = function(self) return self end
            mt.mouseCallback = function(self, fn) self.cb = fn; return self end
            mt.show = function(self) self.shown = true; return self end
            mt.delete = function(self) self.deleted = true; return self end
            _G.__lastCanvas = cv
            return cv
        end,
    },
    mouse = {
        getCurrentScreen = function()
            return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
        end,
        absolutePosition = function() end,
    },
    window = {
        frontmostWindow = function()
            return { id = function() return 777 end }
        end,
    },
    timer = { secondsSinceEpoch = function() return 1000 end,
              doAfter = function(_, fn) fn(); return { stop = function() end } end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.ocrShortcutAvailable = true
_G.typingInjection = function() return false end
_G.showCanvasSafely = function(c) c.shown = true; return true end

local HYPER, PROVIDED, POPUPS, EDITOR_OPENS = {}, {}, {}, {}
local CORE = {
    homeDir = HOME,
    hyperAddShortcut = function(mods, key, fn, src)
        local ms = {}
        for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms)
        HYPER[table.concat(ms, "+") .. "|" .. key] = fn
    end,
    provide   = function(n, f) PROVIDED[n] = f end,
    call      = function(n, ...)
        if n == "screenshotEditor.open" then
            EDITOR_OPENS[#EDITOR_OPENS + 1] = (...)
            return true
        end
        return nil
    end,
    showPopup = function(c) POPUPS[#POPUPS + 1] = c; c.shown = true end,
}

local M = dofile(HS .. "/modules/screenshots.lua")
M.setup(CORE)
local S = _G.screenshots

-- =====================================================================
out("\n1. contract & wiring\n")
-- =====================================================================
check("module loads and has setup()", type(M.setup) == "function")
check("⇪4 is claimed (capture)", type(HYPER["|4"]) == "function")
check("⇪⇧4 is claimed (history)", type(HYPER["shift|4"]) == "function")
check("…and nothing else is", (function()
    local n = 0
    for _ in pairs(HYPER) do n = n + 1 end
    return n == 2
end)(), nil)
check("screenshots.latest is a service", type(PROVIDED["screenshots.latest"]) == "function")
check("screenshots.capture is a service", type(PROVIDED["screenshots.capture"]) == "function")
check("screenshots.show is a service", type(PROVIDED["screenshots.show"]) == "function")
check("the folder is the OneDrive one LL named", S.dir == DIR, S.dir)
check("cheat sheet group present with a title", type(M.cheatsheet) == "table"
      and type(M.cheatsheet.title) == "string")

-- =====================================================================
out("2. filenames\n")
-- =====================================================================
local t0 = os.time({ year = 2026, month = 8, day = 15,
                     hour = 14, min = 23, sec = 5 })
check("macOS-shaped timestamped name, dots not colons",
      S.filenameAt(t0) == "Screenshot 2026-08-15 at 14.23.05.png",
      S.filenameAt(t0))

-- =====================================================================
out("3. capture — the happy path\n")
-- =====================================================================
check("the screenshots folder does not exist yet", DIRS[DIR] == nil)
HYPER["|4"]()   -- press ⇪4
check("capture creates the folder on first use", DIRS[DIR] == true)
check("exactly one screencapture task started", #TASKS == 1 and TASKS[1].started)
check("…running the real binary", TASKS[1] and TASKS[1].cmd == "/usr/sbin/screencapture",
      TASKS[1] and TASKS[1].cmd)
check("…interactive (-i), writing into the folder", TASKS[1]
      and TASKS[1].args[1] == "-i"
      and TASKS[1].args[2]:sub(1, #DIR) == DIR,
      TASKS[1] and table.concat(TASKS[1].args, " "))

-- "screencapture" writes the file, then exits:
local shot1 = TASKS[1].args[2]
FILES[shot1] = { size = 240000, modification = 1000 }
TASKS[1].cb()
check("the image is on the clipboard", CLIP.kind == "image"
      and CLIP.v.__path == shot1, CLIP.kind)
check("…and the alert says saved AND copied",
      (ALERTS[#ALERTS] or ""):find("Saved") ~= nil
      and (ALERTS[#ALERTS] or ""):find("clipboard") ~= nil,
      ALERTS[#ALERTS])

-- =====================================================================
out("4. capture — cancelled with Esc\n")
-- =====================================================================
local alertsBefore, clipBefore = #ALERTS, CLIP
HYPER["|4"]()
-- exits WITHOUT writing the file — that is what Esc does
TASKS[#TASKS].cb()
check("no alert on a cancelled capture — a cancel is not an event",
      #ALERTS == alertsBefore, ALERTS[#ALERTS])
check("clipboard untouched", CLIP == clipBefore)

-- =====================================================================
out("5. two captures in one second\n")
-- =====================================================================
-- the first capture's file for this second already exists. base can BE
-- shot1 (this test runs inside one second), so save and restore whatever
-- record was there rather than clobbering it.
local now = os.time()
local base = DIR .. "/" .. S.filenameAt(now)
local prevRecord = FILES[base]
FILES[base] = prevRecord or { size = 1, modification = now }
HYPER["|4"]()
local second = TASKS[#TASKS].args[2]
check("the second capture gets a numbered name, never an overwrite",
      second ~= base and second:find("%(2%)%.png$") ~= nil, second)
FILES[base] = prevRecord

-- =====================================================================
out("6. listing & the picker\n")
-- =====================================================================
FILES[DIR .. "/old.png"]      = { size = 100 * 1024,  modification = 100 }
FILES[DIR .. "/newest.png"]   = { size = 2 * 1024 * 1024, modification = 900 }
FILES[DIR .. "/middle.jpg"]   = { size = 50 * 1024,   modification = 500 }
FILES[DIR .. "/.DS_Store"]    = { size = 10, modification = 999 }
FILES[DIR .. "/notes.txt"]    = { size = 10, modification = 999 }
FILES[shot1].modification     = 1000

local list = S.list()
check("only images are listed — .DS_Store and .txt are not screenshots",
      (function()
          for _, e in ipairs(list) do
              if e.name == ".DS_Store" or e.name == "notes.txt" then return false end
          end
          return #list == 4
      end)(), #list)
check("newest first", list[1] and list[1].path == shot1, list[1] and list[1].name)
check("…then by mtime all the way down", list[2] and list[2].name == "newest.png"
      and list[3].name == "middle.jpg" and list[4].name == "old.png")
check("latest() is the picker's first row", S.latest() == shot1, S.latest())
check("the service answers the same", PROVIDED["screenshots.latest"]() == shot1)

local choices = S.choicesFrom(list)
check("the panel leads with the SEVEN capture actions", (function()
    local acts = {}
    for i = 1, 7 do acts[#acts + 1] = choices[i] and choices[i].act end
    return acts[1] == "area" and acts[2] == "scroll" and acts[3] == "recognize"
       and acts[4] == "editNewest" and acts[5] == "repeat"
       and acts[6] == "window" and acts[7] == "delayed"
end)())
check("…then one row per screenshot, path attached", #choices == 7 + 4
      and choices[8].path == shot1, #choices)
check("history subText carries date, size and the modifier hints",
      (choices[9].subText or ""):find("MB") ~= nil
      and (choices[8].subText or ""):find("⌥⏎") ~= nil,
      choices[9].subText)
check("the cap is respected", (function()
    local old = S.maxList
    S.maxList = 2
    local c = S.choicesFrom(list)
    S.maxList = old
    return #c == 7 + 2
end)())

HYPER["shift|4"]()   -- open the panel
check("⇪⇧4 shows the panel through showPopup", #POPUPS == 1 and POPUPS[1].shown)
check("…with actions + history loaded", type(CHOICES_SET) == "table"
      and #CHOICES_SET == 7 + 4, CHOICES_SET and #CHOICES_SET)
check("…action rows carry no thumbnail", CHOICES_SET[1].image == nil)
check("…and thumbnails attached to the history rows",
      CHOICES_SET[8].image ~= nil and CHOICES_SET[8].image.__path == shot1)
-- 6.88.0 — LL: "I don't see the image history." The panel must be TALL
-- enough that history rows are visible UNDER the seven actions.
check("the panel sizes itself past the 7 actions (history above the fold)",
      type(POPUPS[1].nrows) == "number" and POPUPS[1].nrows == 7 + 4,
      POPUPS[1].nrows)

-- 6.88.0 — LL: "I can't tell if I can search the window." Typing filters
-- the HISTORY; the action rows step aside while a query is live.
check("a query callback is installed", type(POPUPS[1].qcb) == "function")
POPUPS[1].qcb("newest")
check("typing filters to matching screenshots — no action rows",
      #CHOICES_SET == 1 and CHOICES_SET[1].path == DIR .. "/newest.png"
      and CHOICES_SET[1].act == nil,
      #CHOICES_SET)
POPUPS[1].qcb("jan")   -- the stub mtimes are 1970 — "Jan" in every subText
check("…and the DATE text matches too", #CHOICES_SET == 4, #CHOICES_SET)
POPUPS[1].qcb("zzz-nothing-here")
check("…an unmatched query explains itself instead of going blank",
      #CHOICES_SET == 1 and CHOICES_SET[1].path == nil
      and (CHOICES_SET[1].text or ""):find("No screenshots match") ~= nil,
      CHOICES_SET[1] and CHOICES_SET[1].text)
POPUPS[1].qcb("")
check("…and an empty query brings the actions back",
      #CHOICES_SET == 7 + 4 and CHOICES_SET[1].act == "area", #CHOICES_SET)

-- =====================================================================
out("7. picking — ⏎ image, ⌘⏎ path\n")
-- =====================================================================
MODS = {}
S.onPick({ path = shot1 })
check("plain ⏎ puts the IMAGE on the clipboard", CLIP.kind == "image"
      and CLIP.v.__path == shot1, CLIP.kind)
MODS = { cmd = true }
S.onPick({ path = shot1 })
check("⌘⏎ puts the PATH on the clipboard instead", CLIP.kind == "text"
      and CLIP.v == shot1, tostring(CLIP.v))
MODS = { alt = true }
S.onPick({ path = shot1 })
check("⌥⏎ opens the blur editor on that file",
      EDITOR_OPENS[#EDITOR_OPENS] == shot1, EDITOR_OPENS[#EDITOR_OPENS])
MODS = {}
local clipNow = CLIP
S.onPick({ text = "No screenshots yet" })   -- the empty-folder row has no path
check("the empty-folder row is a safe no-op", CLIP == clipNow)

-- ⌃⏎ compress (6.88.0): sips re-encodes to a small jpg NEXT TO the png
MODS = { ctrl = true }
local tB = #TASKS
S.onPick({ path = shot1 })
check("⌃⏎ launches sips on that file", #TASKS == tB + 1
      and TASKS[#TASKS].cmd == "/usr/bin/sips" and TASKS[#TASKS].started,
      TASKS[#TASKS] and TASKS[#TASKS].cmd)
local sa = TASKS[#TASKS].args
check("…re-encoding as jpeg at the configured quality",
      sa[1] == "-s" and sa[2] == "format" and sa[3] == "jpeg"
      and sa[4] == "-s" and sa[5] == "formatOptions" and sa[6] == "70",
      table.concat(sa, " "))
local outJpg = shot1:gsub("%.png$", "") .. " (compressed).jpg"
check("…into “… (compressed).jpg”, never over the original",
      sa[7] == shot1 and sa[8] == "--out" and sa[9] == outJpg, sa[9])
FILES[outJpg] = { size = 40000, modification = 1700 }   -- sips writes it
TASKS[#TASKS].cb(0)
check("the SMALL copy goes onto the clipboard", CLIP.kind == "image"
      and CLIP.v.__path == outJpg, CLIP.kind)
check("…with an alert naming both sizes",
      (ALERTS[#ALERTS] or ""):find("→") ~= nil
      and (ALERTS[#ALERTS] or ""):find("KB") ~= nil, ALERTS[#ALERTS])
check("a second compress numbers itself instead of overwriting",
      S.compressedPathFor(shot1):find("%(compressed 2%)%.jpg$") ~= nil,
      S.compressedPathFor(shot1))
FILES[outJpg] = nil   -- keep later sections' folder listings unchanged
MODS = {}

-- =====================================================================
out("8. the empty folder & the missing folder\n")
-- =====================================================================
local saved = {}
for p, f in pairs(FILES) do saved[p] = f end
for p in pairs(saved) do FILES[p] = nil end
local c = S.choicesFrom(S.list())
check("an empty folder still shows the actions, plus one row that explains",
      #c == 8 and c[8].path == nil and (c[8].text or ""):find("No screenshots") ~= nil,
      c[8] and c[8].text)
for p, f in pairs(saved) do FILES[p] = f end

-- OneDrive not signed in: the parent folder cannot be made
DIRS[DIR] = nil
local realMkdir = hs.fs.mkdir
hs.fs.mkdir = function() return nil end
local tasksBefore = #TASKS
HYPER["|4"]()
check("no screencapture is launched at a folder that is not there",
      #TASKS == tasksBefore)
check("…and the alert names the folder it looked for",
      (ALERTS[#ALERTS] or ""):find("2026 Screenshots", 1, true) ~= nil,
      ALERTS[#ALERTS])
hs.fs.mkdir = realMkdir

-- =====================================================================
out("9. the panel's capture actions\n")
-- =====================================================================
-- window capture: -l with the frontmost window's real id
local tBefore = #TASKS
S.onPick({ act = "window" })
check("active window → screencapture -l <id>", #TASKS == tBefore + 1
      and TASKS[#TASKS].args[2] == "-l" and TASKS[#TASKS].args[3] == "777",
      TASKS[#TASKS] and table.concat(TASKS[#TASKS].args, " "))

-- delayed: -T with the configured countdown
S.onPick({ act = "delayed" })
check("delayed → screencapture -T 10", TASKS[#TASKS].args[2] == "-T"
      and TASKS[#TASKS].args[3] == "10",
      table.concat(TASKS[#TASKS].args, " "))

-- panel-initiated captures open the EDITOR when the file lands
local winPath = TASKS[#TASKS - 1].args[4]
FILES[winPath] = { size = 999, modification = 1500 }
local editorBefore = #EDITOR_OPENS
TASKS[#TASKS - 1].cb()
check("…and a finished panel capture goes straight into the editor",
      #EDITOR_OPENS == editorBefore + 1 and EDITOR_OPENS[#EDITOR_OPENS] == winPath,
      EDITOR_OPENS[#EDITOR_OPENS])
check("⇪4 stays the fast path — its captures never opened the editor for "
      .. "the plain capture in section 3", (function()
          for _, p in ipairs(EDITOR_OPENS) do
              if p == shot1 and p ~= winPath then return p == shot1 end
          end
          return true
      end)())

-- repeat area: no rect yet → the selector comes up; drag → -R capture
S.lastRect = nil
S.onPick({ act = "repeat" })
local sel = _G.__lastCanvas
check("repeat with no stored area opens the SELECTOR overlay",
      sel ~= nil and sel.shown and type(sel.cb) == "function")
tBefore = #TASKS
sel.cb(sel, "mouseDown", "_canvas_", 100, 200)
sel.cb(sel, "mouseMove", "_canvas_", 340, 420)
check("…the dashed band follows the drag", sel.elements[2].frame.w == 240
      and sel.elements[2].frame.h == 220, sel.elements[2].frame.w)
sel.cb(sel, "mouseUp", "_canvas_", 340, 420)
check("…and releasing shoots that exact rectangle with -R",
      #TASKS == tBefore + 1
      and TASKS[#TASKS].args[2] == "-R100,200,240,220",
      TASKS[#TASKS] and TASKS[#TASKS].args[2])
check("…the selector cleaned itself up", sel.deleted == true)
check("…and the rect is remembered for next time", S.lastRect
      and S.lastRect.x == 100 and S.lastRect.w == 240)
tBefore = #TASKS
S.onPick({ act = "repeat" })
check("repeat WITH a stored area re-shoots it immediately, no selector",
      #TASKS == tBefore + 1 and TASKS[#TASKS].args[2] == "-R100,200,240,220")

-- =====================================================================
out("10. the scrolling plan (pure)\n")
-- =====================================================================
local plan, covered = S.scrollPlan(500, 2000, 0)
check("500px area → 4 slices to cover 2000px", #plan == 4 and covered == 2000,
      #plan .. "/" .. covered)
check("…slice 1 never scrolls, the rest scroll one full area",
      plan[1].scroll == 0 and plan[2].scroll == 500 and plan[4].scroll == 500)
plan, covered = S.scrollPlan(500, 2000, 60)
check("a 60px sticky header shrinks every later step to 440",
      plan[2].scroll == 440 and plan[2].crop == 60 and #plan == 5,
      #plan)
plan = S.scrollPlan(100, 100000, 0)
check("the slice cap holds no matter what height asks for",
      #plan == S.scroll.maxSlices, #plan)
plan, covered = S.scrollPlan(0, 2000, 0)
check("a zero-height area is a no-op, not a loop", #plan == 0 and covered == 0)
plan = S.scrollPlan(50, 200, 80)
check("a cropTop TALLER than the area is ignored rather than obeyed",
      plan[2] and plan[2].crop == 0, plan[2] and plan[2].crop)

-- =====================================================================
out("11. recognize — QR first, text as the fallback\n")
-- =====================================================================
S._zbar = nil   -- reset the detection cache
check("no zbar on disk → zbarPath says so", S.zbarPath() == nil)
S._zbar = nil
FILES["/opt/homebrew/bin/zbarimg"] = { size = 1234 }
check("…and finds the brew install when it exists",
      S.zbarPath() == "/opt/homebrew/bin/zbarimg")

local rp = DIR .. "/recognize-me.png"
FILES[rp] = { size = 500, modification = 1600 }
tBefore = #TASKS
S.recognizeFile(rp)
check("with zbar present the QR decode runs FIRST", #TASKS == tBefore + 1
      and TASKS[#TASKS].cmd == "/opt/homebrew/bin/zbarimg",
      TASKS[#TASKS].cmd)
TASKS[#TASKS].cb(0, "https://example.com/qr-payload\n")
check("a decoded code lands on the clipboard, verbatim",
      CLIP.kind == "text" and CLIP.v == "https://example.com/qr-payload",
      tostring(CLIP.v))

tBefore = #TASKS
S.recognizeFile(rp)
TASKS[#TASKS].cb(1, "")   -- no code in the image
check("no code → falls through to the HS OCR Shortcut",
      #TASKS == tBefore + 2 and TASKS[#TASKS].cmd == "/usr/bin/shortcuts"
      and TASKS[#TASKS].args[1] == "run" and TASKS[#TASKS].args[2] == "HS OCR",
      TASKS[#TASKS].cmd)
TASKS[#TASKS].cb(0, "  Hello from OCR  ")
check("…whose text is trimmed onto the clipboard",
      CLIP.kind == "text" and CLIP.v == "Hello from OCR", tostring(CLIP.v))
FILES["/opt/homebrew/bin/zbarimg"] = nil
S._zbar = nil

-- =====================================================================
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("    ❌ " .. f .. "\n") end
out("\n")
os.exit(fail == 0 and 0 or 1)
