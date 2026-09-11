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
local DEFER_TIMERS = false   -- §12 turns this on to hold the debounce
local PENDING       = {}     -- timers queued while DEFER_TIMERS is true
local CLIP  = { kind = "empty" }
local COPIES, HYPERREL = {}, {}
_G.hyperExpectRelease = function(secs, who) HYPERREL[#HYPERREL + 1] = { secs = secs, who = who } end
local MODS  = {}       -- what checkKeyboardModifiers answers
local WATCHERS = {}    -- 6.155.0: every hs.pathwatcher asked for
NODECODE, NOWRITE = nil, false   -- 6.206.0: a slice that will not decode; a save refused

hs = {
    pathwatcher = {
        new = function(path, fn)
            local w = { path = path, fn = fn, started = false }
            function w:start() self.started = true; return self end
            function w:stop()  self.started = false; return self end
            WATCHERS[#WATCHERS + 1] = w
            return w
        end,
    },
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
            -- 6.170.3: the clipboard copy is an osascript task; the stub
            -- completes it the moment it starts and keeps it OUT of TASKS
            -- (those count screencapture / OCR runs).
            if cmd == "/usr/bin/osascript" and args and args[1] == "-e"
               and (args[2] or ""):find("set the clipboard", 1, true) then
                local t = { cmd = cmd, cb = cb, args = args }
                function t:start()
                    COPIES[#COPIES + 1] = args[2]
                    CLIP = { kind = "image", v = { __path = args[2]:match('POSIX file "(.-)"') } }
                    cb(0, "", "")
                    return true
                end
                return t
            end
            local t = { cmd = cmd, cb = cb, args = args, started = false,
                        terminated = false }
            function t:start() self.started = true; return true end
            function t:terminate() self.terminated = true; return true end
            table.insert(TASKS, t)
            return t
        end,
    },
    image = {
        imageFromPath = function(p)
            IMG_DECODED = IMG_DECODED or {}; IMG_DECODED[p] = (IMG_DECODED[p] or 0) + 1
            if not FILES[p] then return nil end
            if NODECODE and NODECODE[p] then return nil end   -- 6.206.0: on disk, not an image
            local img = { __path = p }
            function img:setSize() return self end
            function img:size() return { w = FILES[p].w or 200, h = FILES[p].h or 100 } end
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
            -- 6.206.0 — the stitch renders the stacked slices; the fake
            -- image remembers what it was made of and saveToFile writes
            -- a fake file whose size is the pixel total
            mt.imageFromCanvas = function(self)
                local h = 0
                for _, e in ipairs(self.elements) do h = h + ((e.frame or {}).h or 0) end
                local img = { __stitched = #self.elements, __h = h }
                function img:saveToFile(path)
                    if NOWRITE then return false end
                    FILES[path] = { size = 1000 + h, modification = 1000 }
                    return true
                end
                return img
            end
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
    -- ⏱ FIRES IMMEDIATELY BY DEFAULT, which is what every section written
    -- before 6.122.0 assumes. §12 sets DEFER_TIMERS to queue them instead,
    -- because a debounce that fires instantly is not a debounce and a test
    -- that cannot hold the timer cannot tell the difference.
    timer = { secondsSinceEpoch = function() return 1000 end,
              doAfter = function(secs, fn)
                  local t = { secs = secs, fn = fn, stopped = false }
                  function t:stop() self.stopped = true end
                  if DEFER_TIMERS then
                      PENDING[#PENDING + 1] = t
                  else
                      fn()
                  end
                  return t
              end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.ocrShortcutAvailable = true
_G.typingInjection = function() return false end
_G.showCanvasSafely = function(c) c.shown = true; return true end

local HYPER, PROVIDED, POPUPS, EDITOR_OPENS = {}, {}, {}, {}
local UNIFIED_OPENS = {}      -- 6.89.0: what ⌘8 hands to unified.show
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
        if n == "unified.show" then
            UNIFIED_OPENS[#UNIFIED_OPENS + 1] = (...)
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
check("⇪4 is claimed (area capture)", type(HYPER["|4"]) == "function")
check("⇪⇧5 is claimed (the ⌘1–⌘9 panel)", type(HYPER["shift|5"]) == "function")
-- 📸 6.194.0 — LL'S MAP, asserted key by key. These are the keys he
-- wrote out, and a typo in the table would otherwise only show up under
-- his fingers.
check("⇪⇧1 is the screenshot editor", type(HYPER["shift|1"]) == "function")
check("⇪⇧2 is capture active window", type(HYPER["shift|2"]) == "function")
check("⇪⇧3 is the delayed capture", type(HYPER["shift|3"]) == "function")
check("⇪⇧4 is text capture", type(HYPER["shift|4"]) == "function")
check("⇪5 is the scrolling capture", type(HYPER["|5"]) == "function")
check("…and nothing else is", (function()
    local n = 0
    for _ in pairs(HYPER) do n = n + 1 end
    return n == 7, n
end)(), nil)
-- 🚨 THE TWO-SIDED JOIN, per the 6.114.0 ⇪⇧R incident: a key whose act
-- runAction does not know is a key that does nothing, and an act that no
-- key reaches is a row LL cannot get to. Both directions, off the SOURCE
-- — the table and the dispatcher must agree or this fails.
check("every toolKeys act is one runAction really handles", (function()
    local src = io.open(HS .. "/modules/screenshots.lua"):read("a")
    local body = src:match("function shots%.runAction%(act%)(.-)\n    end")
    if not body then return false, "runAction not found" end
    for _, t in ipairs(S.toolKeys or {}) do
        if not body:find('act == "' .. t[3] .. '"', 1, true) then
            return false, t[3] .. " is bound to a key but runAction has no branch"
        end
    end
    return #(S.toolKeys or {}) == 5, #(S.toolKeys or {})
end)())
check("…and every row carries a source label for the hint card and the trail",
      (function()
    for _, t in ipairs(S.toolKeys or {}) do
        if type(t[4]) ~= "string" or t[4] == "" then return false, t[3] end
    end
    return true
end)())
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
-- 6.170.3 — the copy left the main thread and ⇪ was told to let go
check("6.170.3: the copy is ONE osascript task reading the PNG onto the pasteboard",
      #COPIES == 1 and COPIES[1]:find(shot1, 1, true) ~= nil
      and COPIES[1]:find("«class PNGf»", 1, true) ~= nil, COPIES[1])
check("…the clipboard poll was asked to sit the change out",
      type(_G.pasteboardSuppressUntil) == "number" and _G.pasteboardSuppressUntil > 0,
      tostring(_G.pasteboardSuppressUntil))
check("…and the interactive capture told the hyper hold to expect a release (1.5 s)",
      #HYPERREL == 1 and HYPERREL[1].secs == 1.5 and HYPERREL[1].who == "the screenshot tool",
      HYPERREL[1] and HYPERREL[1].who)
check("…no sync decode of the shot: hs.image was not asked for it",
      not IMG_DECODED or IMG_DECODED[shot1] == nil)

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
check("…and no copy task was started for a cancelled capture", #COPIES == 1, #COPIES)

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
check("the panel leads with the EIGHT action rows", (function()
    local acts = {}
    for i = 1, 9 do acts[#acts + 1] = choices[i] and choices[i].act end
    return acts[1] == "area" and acts[2] == "scroll" and acts[3] == "recognize"
       and acts[4] == "editNewest" and acts[5] == "repeat"
       and acts[6] == "window" and acts[7] == "delayed"
       and acts[8] == "bigBrowse"          -- 6.89.0: ⌘8 = BIG thumbnails
       and acts[9] == "nameSweep"          -- 6.147.0: ⌘9 = name by content
end)())
check("…then one row per screenshot, path attached", #choices == 9 + 4
      and choices[10].path == shot1, #choices)
check("history subText carries date, size and the modifier hints",
      (choices[11].subText or ""):find("MB") ~= nil
      and (choices[10].subText or ""):find("⌥⏎") ~= nil,
      choices[11].subText)
check("the cap is respected", (function()
    local old = S.maxList
    S.maxList = 2
    local c = S.choicesFrom(list)
    S.maxList = old
    return #c == 9 + 2
end)())

-- 6.194.0 — the panel moved to ⇪⇧5; ⇪⇧4 is text capture now.
HYPER["shift|5"]()   -- open the panel
check("⇪⇧5 shows the panel through showPopup", #POPUPS == 1 and POPUPS[1].shown)
check("…with actions + history loaded", type(CHOICES_SET) == "table"
      and #CHOICES_SET == 9 + 4, CHOICES_SET and #CHOICES_SET)
check("…action rows carry no thumbnail", CHOICES_SET[1].image == nil)
check("…and thumbnails attached to the history rows",
      CHOICES_SET[10].image ~= nil and CHOICES_SET[10].image.__path == shot1)
-- 6.88.0 — LL: "I don't see the image history." The panel must be TALL
-- enough that history rows are visible UNDER the action rows.
check("the panel sizes itself past the 9 actions (history above the fold)",
      type(POPUPS[1].nrows) == "number" and POPUPS[1].nrows == 9 + 4,
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
      #CHOICES_SET == 9 + 4 and CHOICES_SET[1].act == "area", #CHOICES_SET)

-- 6.89.0 — ⌘8 hands the folder to Unified Search, pre-filtered to
-- @shots, where thumbnails render at 84px instead of a chooser row.
S.onPick({ act = "bigBrowse" })
check("⌘8 opens Unified Search filtered to screenshots",
      #UNIFIED_OPENS == 1 and (UNIFIED_OPENS[1] or ""):find("@shots") == 1,
      UNIFIED_OPENS[1])

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
      #c == 10 and c[10].path == nil and (c[10].text or ""):find("No screenshots") ~= nil,
      c[10] and c[10].text)
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
out("10b. 🧻 6.206.0 — the scrolling run keeps its receipts\n")
-- =====================================================================
-- LL's ⇪5: "Stitch failed — slices discarded (screenshots.lua:664: no
-- slices decoded)". That alert said every slice failed and nothing about
-- why: the slice capture never read screencapture's exit code or stderr,
-- appended the path whether a file existed or not, and deleted the
-- slices before anyone could look. Every branch below is that run,
-- driven through the real selector, the real task callbacks and the real
-- stitch, against a fake screencapture that can succeed, fail, or write
-- something that is not an image.
do
    local mine = 0
    local function ck(label, cond, extra) mine = mine + 1 ; check(label, cond, extra) end
    local function runSelector()
        HYPER["|5"]()
        local sel = _G.__lastCanvas
        sel.cb(sel, "mouseDown", nil, 100, 200)
        sel.cb(sel, "mouseUp",   nil, 340, 700)      -- 240 × 500
        return sel
    end
    local savedH = S.scroll.height
    S.scroll.height = 1500                             -- 500 tall → 3 slices
    -- the slices are removed with os.remove, which this fake filesystem
    -- never sees — route it through FILES for the section
    local realRemove = os.remove
    os.remove = function(path) local had = FILES[path] ~= nil ; FILES[path] = nil ; return had end
    -- ---- the happy path ----------------------------------------------
    local t0, c0, a0 = #TASKS, #COPIES, #ALERTS
    S.scrollLast = nil
    runSelector()
    ck("⇪5 + a drag starts slice 1 as a non-interactive -R capture",
       #TASKS == t0 + 1 and TASKS[#TASKS].args[1] == "-x"
       and TASKS[#TASKS].args[2] == "-R100,200,240,500",
       TASKS[#TASKS] and table.concat(TASKS[#TASKS].args, " "))
    ck("…into a dot-file the history panel never lists",
       (TASKS[#TASKS].args[3] or ""):find("/%.scroll%-slice%-01%.png$") ~= nil,
       TASKS[#TASKS].args[3])
    ck("the run is recorded as running, 3 slices planned",
       S.scrollLast and S.scrollLast.outcome == "running" and S.scrollLast.planned == 3,
       S.scrollLast and S.scrollLast.planned)
    -- screencapture writes each slice and exits 0; the settle timer fires
    -- at once in this harness, so each callback starts the next slice
    for n = 1, 3 do
        local t = TASKS[#TASKS]
        FILES[t.args[3]] = { size = 50000, modification = 1000, w = 480, h = 1000 }
        t.cb(0, "", "")
    end
    local run = S.scrollLast
    ck("three slices shot, three decoded, outcome ok",
       run.shot == 3 and run.decoded == 3 and run.outcome == "ok",
       run.shot .. "/" .. run.decoded .. "/" .. tostring(run.outcome))
    ck("🚨 the stitched file was written as “… (scrolling).png”",
       run.out and run.out:find(" %(scrolling%)%.png$") and FILES[run.out] ~= nil, run.out)
    ck("🚨 …and it is ON THE CLIPBOARD — the copy task read that exact file",
       #COPIES == c0 + 1 and COPIES[#COPIES]:find(run.out, 1, true) ~= nil,
       COPIES[#COPIES])
    ck("…and then the editor opens on the stitched file (⇪5 edits after capture,"
       .. " like every panel capture) — the copy came FIRST",
       EDITOR_OPENS[#EDITOR_OPENS] == run.out, EDITOR_OPENS[#EDITOR_OPENS])
    ck("the slices were removed after a good stitch",
       FILES[DIR .. "/.scroll-slice-01.png"] == nil and FILES[DIR .. "/.scroll-slice-03.png"] == nil)
    ck("the stack was 3 images tall", _G.__lastCanvas.__stitchedCount == nil
       and #_G.__lastCanvas.elements == 3, #_G.__lastCanvas.elements)
    ck("…and each slice was placed under the one before it",
       _G.__lastCanvas.elements[2].frame.y == 1000
       and _G.__lastCanvas.elements[3].frame.y == 2000,
       _G.__lastCanvas.elements[2].frame.y)
    ck("the report names the run: planned, shot, decoded, ok, the file",
       (function()
           local r = _G.screenshotsReport()
           return r:find("3 planned · 3 shot · 3 decoded · ok", 1, true) ~= nil
              and r:find("(scrolling).png", 1, true) ~= nil
              and r:find("slice 01: exit 0 · 50000 bytes", 1, true) ~= nil
       end)(), _G.screenshotsReport())

    -- ---- screencapture fails on slice 1: exit 1, stderr, no file ------
    local a1 = #ALERTS
    runSelector()
    local t1 = TASKS[#TASKS]
    t1.cb(1, "", "screencapture: could not create image from display\n")
    run = S.scrollLast
    ck("🚨 a failed slice STOPS the run and says so — no 'no slices decoded'",
       run.outcome == "failed" and run.shot == 0
       and (ALERTS[#ALERTS] or ""):find("stopped", 1, true) ~= nil
       and (ALERTS[#ALERTS] or ""):find("no slices decoded", 1, true) == nil,
       ALERTS[#ALERTS])
    ck("🚨 …naming the slice, the exit code and screencapture's own words",
       (run.why or ""):find("slice 1 of 3", 1, true) and (run.why or ""):find("exit 1", 1, true)
       and (run.why or ""):find("could not create image from display", 1, true),
       run.why)
    ck("…and that no file was written", (run.why or ""):find("no file was written", 1, true) ~= nil, run.why)
    ck("…and points at Screen Recording when the words say the display refused",
       (run.why or ""):find("Screen Recording", 1, true) ~= nil, run.why)
    ck("…and no second slice was started", #TASKS == t0 + 4, #TASKS - t0)
    ck("the report repeats it slice by slice",
       _G.screenshotsReport():find("slice 01: exit 1 · no file · screencapture: could not create image", 1, true) ~= nil,
       _G.screenshotsReport())

    -- ---- exit 0 but the file is empty ----------------------------------
    runSelector()
    local t2 = TASKS[#TASKS]
    FILES[t2.args[3]] = { size = 0, modification = 1000 }
    t2.cb(0, "", "")
    ck("an empty file is a failure even with exit 0",
       S.scrollLast.outcome == "failed" and (S.scrollLast.why or ""):find("the file is empty", 1, true) ~= nil,
       S.scrollLast.why)

    -- ---- the file is there and is not an image ------------------------
    runSelector()
    for n = 1, 3 do
        local t = TASKS[#TASKS]
        FILES[t.args[3]] = { size = 777, modification = 1000, w = 480, h = 1000 }
        NODECODE = NODECODE or {} ; NODECODE[t.args[3]] = (n == 2) or nil
        t.cb(0, "", "")
    end
    run = S.scrollLast
    ck("🚨 a slice on disk that will not decode names ITSELF and its size",
       run.outcome == "failed" and (run.why or ""):find("slice 2 of 3", 1, true)
       and (run.why or ""):find("777 bytes", 1, true) and (run.why or ""):find("did not decode", 1, true),
       run.why)
    ck("🚨 …and the slices are KEPT for a look, not discarded",
       FILES[DIR .. "/.scroll-slice-01.png"] ~= nil and FILES[DIR .. "/.scroll-slice-02.png"] ~= nil
       and _G.screenshotsReport():find("KEPT", 1, true) ~= nil)
    ck("…and nothing reached the clipboard", #COPIES == c0 + 1, #COPIES - c0)
    NODECODE = nil
    for n = 1, 3 do FILES[DIR .. ("/.scroll-slice-%02d.png"):format(n)] = nil end

    -- ---- the finished task is not dropped inside its own callback ------
    ck("🚨 6.196.1: the finished screencapture task stays referenced after"
       .. " its callback (shots.lastCaptureTask), never nil'd mid-frame",
       S.lastCaptureTask ~= nil and S.captureTask == nil)
    ck("…and the stitch steps off the task callback through a HELD timer", (function()
        local src = io.open(HS .. "/modules/screenshots.lua"):read("a")
        local body = src:match("function shots%.scrollingCapture%(thenEdit%)(.-)\n    end\n")
        return body and body:find("shots.stitchTimer = hs.timer.doAfter(0,", 1, true) ~= nil
    end)())
    ck("the decode helper is reachable and pure enough to prove the three failures", (function()
        local a, b = S.decodeSlice(DIR .. "/nope.png")
        local c = (function() FILES[DIR .. "/z.png"] = { size = 0 } ; local _, w = S.decodeSlice(DIR .. "/z.png") ; FILES[DIR .. "/z.png"] = nil ; return w end)()
        return a == nil and b == "no file was written" and c:find("empty", 1, true) ~= nil
    end)())
    ck("the cheat sheet says the result is on the clipboard and names the report", (function()
        local hasClip, hasRep = false, false
        for _, e in ipairs(M.cheatsheet.entries) do
            if e[1] == "⇪5" and e[2]:find("clipboard", 1, true) then hasClip = true end
            if e[2]:find("_G.screenshotsReport", 1, true) then hasRep = true end
        end
        return hasClip and hasRep
    end)())
    S.scroll.height = savedH
    os.remove = realRemove
    check("§10b ran every one of its checks", mine == 25, mine)
end

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
-- 6.173.1 — whatever lands on the clipboard here lands in ⇪O's log too
-- 6.187.0 — and WHICH IMAGE the words came from: the second argument is
-- what makes ⇪space's @images able to show the picture, so it is captured
-- here beside the text.
local REC, RECPATH, savedSvc11 = {}, {}, _G.service
_G.service = { has = function(n) return n == "ocr.record" end,
               call = function(n, t, pth)
                   if n == "ocr.record" then
                       REC[#REC + 1] = t
                       RECPATH[#RECPATH + 1] = pth or false
                   end
                   return true
               end }
tBefore = #TASKS
S.recognizeFile(rp)
check("with zbar present the QR decode runs FIRST", #TASKS == tBefore + 1
      and TASKS[#TASKS].cmd == "/opt/homebrew/bin/zbarimg",
      TASKS[#TASKS].cmd)
TASKS[#TASKS].cb(0, "https://example.com/qr-payload\n")
check("a decoded code lands on the clipboard, verbatim",
      CLIP.kind == "text" and CLIP.v == "https://example.com/qr-payload",
      tostring(CLIP.v))
check("6.173.1: …and in the OCR log (ocr.record)", REC[1] == "https://example.com/qr-payload", REC[1])
check("6.187.0: …WITH the image it was read from, so @images can show it",
      RECPATH[1] == rp, tostring(RECPATH[1]))

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
check("6.173.1: ⇪4's recognized text reaches ocr.record — ⇪O has what ⇪V has",
      REC[2] == "Hello from OCR", REC[2])
check("6.187.0: …and so does the file, on the OCR route as well as the QR one",
      RECPATH[2] == rp, tostring(RECPATH[2]))
_G.service = savedSvc11
FILES["/opt/homebrew/bin/zbarimg"] = nil
S._zbar = nil

-- =====================================================================
out("\n12. 🔎 the search: the WHOLE folder, and the text inside it\n")
-- =====================================================================
-- LL: "How do I search and bring up an image that is stored in the
-- screenshots folder?" You could — over the newest thirty files, by
-- filename, and a screenshot's filename is a timestamp. These are the
-- checks for the two halves that were missing.

-- A folder with more files than the panel will ever draw at once.
for p in pairs(FILES) do
    if p:sub(1, #DIR) == DIR then FILES[p] = nil end
end
local BASE = 1700000000
for i = 1, 45 do
    FILES[string.format("%s/Screenshot 2026-08-%02d at 09.%02d.00.png", DIR,
                        (i % 28) + 1, i)] =
        { size = 1000 * i, modification = BASE + i }
end
-- One with a distinctive name, deliberately OLDEST so the thirty-row cap
-- would have hidden it.
local OLD = DIR .. "/Screenshot 2026-01-02 at 08.00.00 invoice.png"
FILES[OLD] = { size = 4242, modification = BASE - 99999 }
-- And one whose name says nothing at all — the Spotlight-only case.
local MUTE = DIR .. "/Screenshot 2026-03-03 at 07.00.00.png"
FILES[MUTE] = { size = 777, modification = BASE - 88888 }

S.thumbCache = {}
S.show()
local full = S.fullList
check("show() keeps the WHOLE folder for the search to work over",
      #full == 47, #full)
check("…while the idle view stays capped", (function()
    local n = 0
    for _, c in ipairs(S.allChoices) do if c.path then n = n + 1 end end
    return n == S.maxList
end)())
check("🚨 the cap is a drawing limit, not a search limit",
      S.maxList < #full and S.searchMax > S.maxList,
      S.maxList .. "/" .. S.searchMax)

-- 🚨 THE FILE THE OLD SEARCH COULD NOT FIND. It is the oldest in the
-- folder, so it was never among the thirty the filter looked at.
local hits = S.filterChoices("invoice")
check("🚨 a match older than the cap is found now", #hits == 1, #hits)
check("…and it is the right file", hits[1] and hits[1].path == OLD,
      hits[1] and hits[1].path)
check("…and the row says the NAME is what matched",
      hits[1] and hits[1].subText:find("name", 1, true) ~= nil,
      hits[1] and hits[1].subText)
check("…and it carries a thumbnail", hits[1] and hits[1].image ~= nil)

check("every word has to match, not any of them",
      #S.filterChoices("invoice zzzz") == 1
      and S.filterChoices("invoice zzzz")[1].path == nil,
      #S.filterChoices("invoice zzzz"))
check("a date works as a query", #S.filterChoices("aug 05") > 0,
      #S.filterChoices("aug 05"))
check("an empty query gives the idle view back",
      #S.filterChoices("") == #S.allChoices)

out("\n12b. asking Spotlight for the text inside the image\n")
DEFER_TIMERS = true
PENDING, TASKS = {}, {}
S.spotlightQuery, S.spotlightResults = nil, nil
S.liveQuery = ""

S.onQuery("acme corp")
check("the name matches are drawn before anything is spawned",
      #TASKS == 0, #TASKS)
check("🚨 …and mdfind is DEBOUNCED, not run per keystroke",
      #PENDING == 1, #PENDING)
-- 🚨 A TIMER EXISTING IS NOT A DEBOUNCE. doAfter(0, …) queues a timer too
-- and spawns a process per keystroke all the same; the delay has to be
-- real, and it has to be the setting rather than a number typed inline.
check("🚨 …with a real delay, taken from the setting",
      S.findDelay > 0 and PENDING[1].secs == S.findDelay,
      tostring(PENDING[1].secs) .. " vs " .. tostring(S.findDelay))
-- Two more keystrokes while the first is still waiting.
S.onQuery("acme corpo")
S.onQuery("acme corporation")
check("…each keystroke replaces the pending run rather than adding one",
      (function()
          local live = 0
          for _, t in ipairs(PENDING) do if not t.stopped then live = live + 1 end end
          return live == 1
      end)(), #PENDING)

local armed
for _, t in ipairs(PENDING) do if not t.stopped then armed = t end end
armed.fn()
check("mdfind was started once the typing stopped", #TASKS == 1, #TASKS)
check("…and it is the real binary", TASKS[1].cmd == "/usr/bin/mdfind", TASKS[1].cmd)
check("🚨 …restricted to the screenshots folder, not the whole Mac",
      TASKS[1].args[1] == "-onlyin" and TASKS[1].args[2] == DIR,
      table.concat(TASKS[1].args, " "))
check("…passed as arguments, never through a shell",
      TASKS[1].args[3] == "acme corporation", TASKS[1].args[3])
check("…and started", TASKS[1].started)

TASKS[1].cb(0, MUTE .. "\n" .. OLD .. "\n/some/deleted/file.png\n")
local merged = S.filterChoices("acme corporation")
check("a Spotlight hit becomes a row", (function()
    for _, r in ipairs(merged) do if r.path == MUTE then return true end end
end)())
check("🚨 …and says the TEXT is what matched, not the name",
      (function()
          for _, r in ipairs(merged) do
              if r.path == MUTE then
                  return r.subText:find("text inside it", 1, true) ~= nil
              end
          end
      end)())
check("🚨 a Spotlight hit for a file no longer in the folder is dropped",
      (function()
          for _, r in ipairs(merged) do
              if r.path == "/some/deleted/file.png" then return false end
          end
          return true
      end)())
check("…and no row appears twice", (function()
    local seen = {}
    for _, r in ipairs(merged) do
        if r.path then
            if seen[r.path] then return false end
            seen[r.path] = true
        end
    end
    return true
end)())

-- 🚨 THE RACE. An answer to a query you have finished typing must not
-- replace the list under the query you are now on.
PENDING, TASKS = {}, {}
S.spotlightQuery, S.spotlightResults = nil, nil
S.onQuery("first")
for _, t in ipairs(PENDING) do if not t.stopped then t.fn() end end
local staleTask = TASKS[#TASKS]
S.liveQuery = "second"        -- you have typed on
staleTask.cb(0, MUTE .. "\n")
check("🚨 a result for a query you have moved past is discarded",
      S.spotlightQuery ~= "first", tostring(S.spotlightQuery))

-- Ordering: names first, because a name match is a thing you remembered.
S.spotlightQuery, S.spotlightResults = "invoice", { MUTE }
S.liveQuery = "invoice"
local ordered = S.filterChoices("invoice")
check("🚨 name matches sort above text-only matches",
      ordered[1] and ordered[1].path == OLD
      and ordered[2] and ordered[2].path == MUTE,
      ordered[1] and ordered[1].path)

out("\n12c. an honest empty result\n")
S.spotlightQuery, S.spotlightResults = nil, nil
local none = S.filterChoices("zzzznothinghere")
check("nothing matching says so", #none == 1 and none[1].path == nil, #none)
check("🚨 …and admits Spotlight never answered, rather than implying it did",
      none[1].subText:find("Spotlight had no answer", 1, true) ~= nil,
      none[1].subText)
S.spotlightQuery, S.spotlightResults = "zzzznothinghere", {}
local none2 = S.filterChoices("zzzznothinghere")
check("…and says the text WAS searched once it has been",
      none2[1].subText:find("indexed text", 1, true) ~= nil, none2[1].subText)

check("closing and reopening cancels any run in flight", (function()
    PENDING, TASKS = {}, {}
    S.onQuery("hello")
    for _, t in ipairs(PENDING) do if not t.stopped then t.fn() end end
    local t = TASKS[#TASKS]
    S.show()
    return t.terminated == true
end)())
DEFER_TIMERS = false
PENDING = {}

-- =====================================================================
out("\n13. 🗂 the folder row (6.130.0)\n")
-- =====================================================================
-- LL: "any screenshots should be captured here, by a line entry that
-- sends me to that screenshot's folder"
DIRS[DIR] = true
do
    local before = #TASKS
    local ok = S.revealFolder()
    check("🗂 revealFolder starts exactly one task", ok == true
          and #TASKS == before + 1, #TASKS - before)
    local t = TASKS[#TASKS]
    -- 🚨 hs.task, NEVER hs.execute. hs.execute is SYNCHRONOUS and this
    -- folder lives in OneDrive, where `open` on a directory that has not
    -- finished materialising can sit for seconds — with Hammerspoon's one
    -- thread, and therefore the whole keyboard, stopped behind it.
    check("🚨 …through /usr/bin/open, out of process", t
          and t.cmd == "/usr/bin/open" and t.started, t and t.cmd)
    check("🗂 …pointed at the screenshots folder itself",
          t and t.args[1] == DIR, t and t.args[1])
    -- The callback releases the handle; an hs.task nothing references is
    -- collected, and a collected task is one that never ran.
    check("🗂 the task is HELD until it finishes", S.openTask ~= nil)
    t.cb()
    check("…and released afterwards", S.openTask == nil)
end

-- 🛟 The hostile Mac: no OneDrive, so there is no folder to open. It must
-- refuse and say so, not launch `open` at a path that is not there.
do
    DIRS[DIR] = nil
    local realMkdir = hs.fs.mkdir
    hs.fs.mkdir = function() return nil end
    local before = #TASKS
    local ok = S.revealFolder()
    check("🛟 with no folder it refuses rather than opening nothing",
          ok == false and #TASKS == before, #TASKS - before)
    check("🛟 …and the alert names the folder it looked for",
          (ALERTS[#ALERTS] or ""):find("2026 Screenshots", 1, true) ~= nil,
          ALERTS[#ALERTS])
    hs.fs.mkdir = realMkdir
    DIRS[DIR] = true
end

-- 🗂 The registration itself — the row that carries all of the above into
-- the ⌃⌃ picker. Its `show` is what ⏎ calls.
do
    local row
    for _, e in ipairs(_G.editors or {}) do
        if type(e) == "table" and e.name == "Screenshots" then row = e end
    end
    check("🗂 it registers a Screenshots row in the editor picker", row ~= nil)
    check("🗂 …whose ⏎ opens the folder", (function()
        if not row then return false end
        local before = #TASKS
        row.show()
        return #TASKS == before + 1
               and TASKS[#TASKS].cmd == "/usr/bin/open"
    end)())
    -- 🚨 NO `text`, DELIBERATELY. ⌥⏎ means "copy that editor's text" and a
    -- folder has none — the picker's own guard then says "has no text to
    -- copy" instead of putting an empty string on the clipboard over
    -- whatever was there.
    check("🚨 …and offers no text, so ⌥⏎ cannot clobber the clipboard",
          row and row.text == nil)
    check("🗂 …and counts the folder for the picker's subtitle",
          row and type(row.size) == "function" and row.size() == #S.list(),
          row and row.size and row.size())
    -- 💾 6.130.0 — and it is IN the one-file CSV export. A row in the
    -- picker that contributes no column is a hole exactly where somebody
    -- would go looking for one.
    check("💾 …and supplies csv rows, so the export is not missing a store",
          row and type(row.csv) == "function" and #row.csv() == #S.list(),
          row and row.csv and #row.csv())
    check("💾 …whose text cell is the full path, pasteable into Go-to-Folder",
          (function()
        if not (row and row.csv) then return false end
        local first = row.csv()[1]
        return first ~= nil and first.text:sub(1, #DIR) == DIR,
               first and first.text
    end)())
end

-- =====================================================================
out("\n=== 6.147.0 — content names: the shot's words become its name ===\n")
-- =====================================================================
-- LL: "Can we apply better naming conventions to the screenshot files
-- than SCR- so the OCR text is applied and searchable?"
local NDIR = "/cloud/2026 Screenshots NAMES"
DIRS[NDIR] = true
local savedDir = S.dir
S.dir = NDIR
local realRename = os.rename
local RENAMES = {}
os.rename = function(old, new)
    if FILES[old] then
        RENAMES[#RENAMES + 1] = { old = old, new = new }
        FILES[new] = FILES[old]
        FILES[old] = nil
        return true
    end
    return nil, "no such file"
end
local SVC = {}
local savedService = _G.service
_G.service = {
    has  = function(n) return n == "ocr.comment" or n == "ocr.record" end,
    call = function(n, p, txt) SVC[#SVC + 1] = { n = n, p = p, txt = txt }
           return true end,
}
_G.ocrShortcutAvailable = true

-- the slug: words of the text, short noise dropped, digits kept
check("the slug keeps words and digit-bearing shorts, drops noise",
      S.slugFrom("an Q3 of Quarterly report to be numbers final")
      == "Q3 Quarterly report numbers final",
      S.slugFrom("an Q3 of Quarterly report to be numbers final"))
check("…caps at " .. S.slugChars .. " characters on a word boundary",
      #(S.slugFrom(string.rep("wordhere ", 20)) or "") <= S.slugChars)
check("…and no text means NO slug, not an empty suffix",
      S.slugFrom("a of to") == nil and S.slugFrom("") == nil)

-- the naming rules
local mt1 = os.time({ year = 2026, month = 9, day = 1, hour = 4, min = 36, sec = 2 })
check("an SCR- file folds into the module's own convention, keeping "
      .. "its real moment",
      S.contentName("SCR-20260901-eubp.png", "words here", mt1)
      == "Screenshot 2026-09-01 at 04.36.02 — words here.png",
      S.contentName("SCR-20260901-eubp.png", "words here", mt1))
check("a word-less capture of our own gains its words",
      S.contentName("Screenshot 2026-09-01 at 04.48.37.png", "words here", mt1)
      == "Screenshot 2026-09-01 at 04.48.37 — words here.png")
check("a name that already carries words is FINISHED — never touched",
      S.contentName("Screenshot 2026-09-01 at 04.48.37 — done.png", "x", mt1) == nil)
check("a name a person chose is never rewritten",
      S.contentName("IMG_1234.png", "words", mt1) == nil
      and S.contentName("my design final v2.png", "words", mt1) == nil)

-- the capture hook: finish() queues one OCR, and the editor path never does
local own = NDIR .. "/Screenshot 2026-09-01 at 04.48.37.png"
FILES[own] = { mode = "file", size = 999, modification = mt1 }
local before = #TASKS
S.finish(own, false)
check("a finished capture queues ONE background OCR of itself",
      #TASKS == before + 1 and TASKS[#TASKS].cmd == "/usr/bin/shortcuts",
      TASKS[#TASKS] and TASKS[#TASKS].cmd)
TASKS[#TASKS].cb(0, "Quarterly report Q3 numbers final\n", "")
check("…and the file now carries its words",
      FILES[NDIR .. "/Screenshot 2026-09-01 at 04.48.37 — Quarterly report "
            .. "Q3 numbers final.png"] ~= nil, RENAMES[#RENAMES]
            and RENAMES[#RENAMES].new)
check("…with the text handed to the OCR engine for the Finder comment",
      #SVC == 2 and SVC[1].n == "ocr.comment"
      and SVC[1].txt:find("Quarterly", 1, true) ~= nil)
check("6.172.1: …and handed to ocr.record so ⇪O's log has the words too",
      SVC[2] and SVC[2].n == "ocr.record" and tostring(SVC[2].p):find("Quarterly", 1, true) ~= nil,
      SVC[2] and SVC[2].n)
local edited = NDIR .. "/Screenshot 2026-09-01 at 04.50.00.png"
FILES[edited] = { mode = "file", size = 999, modification = mt1 }
before = #TASKS
S.finish(edited, true)
check("a capture headed for the blur editor is NOT renamed under it",
      #TASKS == before)

-- the ⌘9 sweep: the SCR- backlog, one OCR at a time. The editor-bound
-- fixture above is still word-less and WOULD be a legitimate candidate
-- — cleared first so the batch below is exactly the two files staged.
FILES[edited] = nil
FILES[NDIR .. "/SCR-20260901-eyjg.png"] = { mode = "file", size = 500,
                                            modification = mt1 }
FILES[NDIR .. "/Screenshot 2026-08-30 at 10.00.00.png"] =
      { mode = "file", size = 500, modification = mt1 }
FILES[NDIR .. "/IMG_9999.png"] = { mode = "file", size = 500, modification = mt1 }
ALERTS = {}
before = #TASKS
S.renameSweep()
check("the sweep announces its batch — two candidates, the person's "
      .. "file excluded", (ALERTS[1] or ""):find("Naming 2", 1, true) ~= nil,
      ALERTS[1])
check("…and runs ONE shortcuts process, not two at once",
      #TASKS == before + 1)
TASKS[#TASKS].cb(0, "Lees MacBook Air Model", "")
check("the second starts only when the first finishes",
      #TASKS == before + 2)
TASKS[#TASKS].cb(0, "", "")   -- a blank image: no text
check("the closing alert counts renames AND the text-free honestly",
      (ALERTS[#ALERTS] or ""):find("Named 1 of 2 — 1 had no readable text",
                                   1, true) ~= nil, ALERTS[#ALERTS])
check("…the SCR- file now wears the words it contained", (function()
    for p in pairs(FILES) do
        if p:find("Lees MacBook Air Model", 1, true) then return true end
    end
    return false
end)())
check("a second sweep while one runs is refused", (function()
    S.nameBusy = true
    ALERTS = {}
    S.renameSweep()
    S.nameBusy = false
    return (ALERTS[1] or ""):find("already running", 1, true) ~= nil
end)())

-- =====================================================================
out("\n=== 6.155.0 — 👀 arrivals from other tools are named as they land ===\n")
-- =====================================================================
-- LL, looking at the panel: "some of the screenshots have OCR'd
-- thumbnails and others don't have words in the title? Is there a better
-- way we can put words in the title along with the other information?"
-- The word-less row was SCR-20260902-rkdn.png — another tool's capture,
-- which nothing named until ⌘9 was pressed.
check("the folder is watched from its first use — ONE watcher, started, held",
      #WATCHERS == 1 and WATCHERS[1].path == DIR and WATCHERS[1].started
      and S.watcher == WATCHERS[1], #WATCHERS)
local W = WATCHERS[1]
S.nameBusy = false
S.queue, S.pending = {}, {}
DEFER_TIMERS = true ; PENDING = {}
local mtScr = os.time({ year = 2026, month = 9, day = 2, hour = 20, min = 0, sec = 12 })
local scr = NDIR .. "/SCR-20260902-rkdn.png"
FILES[scr] = { mode = "file", size = 885000, modification = mtScr }
before = #TASKS
W.fn({ scr })
check("LL's exact file — SCR-20260902-rkdn.png from another tool — is NOT "
      .. "OCR'd on sight: it must sit still first",
      #TASKS == before and #PENDING == 1 and PENDING[1].secs == S.watchSettle,
      #PENDING)
W.fn({ scr })
check("…a second write restarts the clock", #PENDING == 2 and PENDING[1].stopped)
PENDING[2].fn()
check("…settled: ONE shortcuts OCR, of that file",
      #TASKS == before + 1 and TASKS[#TASKS].cmd == "/usr/bin/shortcuts"
      and TASKS[#TASKS].args[4] == scr, TASKS[#TASKS] and TASKS[#TASKS].args[4])
TASKS[#TASKS].cb(0, "Numpad window map\n", "")
check("…and it now carries its words, in this module's own shape, keeping "
      .. "its real moment",
      FILES[NDIR .. "/Screenshot 2026-09-02 at 20.00.12 — Numpad window map.png"] ~= nil,
      RENAMES[#RENAMES] and RENAMES[#RENAMES].new)
check("…counted as named on arrival", S.namedOnArrival == 1 and S.nameBusy == false)
-- 🖼 6.187.0 — THE DEAD-LINK TRAP. This path RENAMES the shot to match its
-- own words and only then logs them, so logging `path` would file every
-- arrival against a name that no longer exists — and nothing ever re-OCRs
-- it, because a file already carrying " — " is not a candidate again. The
-- @images row would then have no thumbnail, say "the file has moved", and
-- fail to open: broken on exactly the captures it was built for.
check("6.187.0: the words are logged against the file's NEW name, not the one it just lost",
      (function()
          local newPath = NDIR .. "/Screenshot 2026-09-02 at 20.00.12 — Numpad window map.png"
          local last
          for _, c in ipairs(SVC) do if c.n == "ocr.record" then last = c end end
          if not last then return false end
          -- the path logged must be a file that EXISTS: that is the whole point
          return last.p == "Numpad window map" and last.txt == newPath
                 and FILES[last.txt] ~= nil
      end)(),
      (function()
          local last
          for _, c in ipairs(SVC) do if c.n == "ocr.record" then last = c end end
          return last and tostring(last.txt) or "no ocr.record call at all"
      end)())

out("   -- what the watcher leaves alone --\n")
PENDING = {}
HYPER["|4"]()                                  -- a capture of our own
local ownp = TASKS[#TASKS].args[2]
TASKS[#TASKS].cb()                             -- Esc — no file written
check("a capture of our own is registered as ours", S.own[ownp] == true, ownp)
W.fn({ ownp })
check("…and the watcher leaves it alone — finish() names those", #PENDING == 0)
W.fn({ NDIR .. "/Screenshot 2026-09-02 at 19.52.07 — ACD Strategic (edited).jpg" })
check("a name that already carries words is finished", #PENDING == 0)
W.fn({ NDIR .. "/IMG_1234.png", NDIR .. "/notes.txt",
       "/elsewhere/SCR-20260902-abcd.png", NDIR .. "/sub/SCR-20260902-deep.png" })
check("a person's name, a non-image, a file outside the folder or below "
      .. "it: nothing queued", #PENDING == 0)
local held = NDIR .. "/SCR-20260902-held.png"
FILES[held] = { mode = "file", size = 100, modification = mtScr }
_G.screenshotEditor = { currentPath = held }
before = #TASKS
W.fn({ held }) ; PENDING[#PENDING].fn()
check("a file the blur editor has open is NOT renamed under it", #TASKS == before)
_G.screenshotEditor = nil
local gone = NDIR .. "/SCR-20260902-gone.png"
W.fn({ gone }) ; PENDING[#PENDING].fn()     -- never written to disk
check("a file that vanished before it settled is skipped", #TASKS == before)

out("   -- one at a time, and a cap --\n")
local a, b = NDIR .. "/SCR-20260902-aaaa.png", NDIR .. "/SCR-20260902-bbbb.png"
FILES[a] = { mode = "file", size = 100, modification = mtScr }
FILES[b] = { mode = "file", size = 100, modification = mtScr }
before = #TASKS
W.fn({ a, b })
local n = #PENDING
PENDING[n - 1].fn() ; PENDING[n].fn()
check("two arrivals settle into ONE shortcuts process at a time",
      #TASKS == before + 1 and #S.queue == 1, #TASKS - before)
TASKS[#TASKS].cb(0, "", "")                    -- a blank image
check("the second starts when the first finishes",
      #TASKS == before + 2 and #S.queue == 0 and TASKS[#TASKS].args[4] == b)
TASKS[#TASKS].cb(0, "second words", "")
check("…and the queue is empty and idle afterwards", S.nameBusy == false)
S.watchCap = 1
S.nameBusy = true                              -- hold the drain so the queue fills
local c1, c2 = NDIR .. "/SCR-20260902-cap1.png", NDIR .. "/SCR-20260902-cap2.png"
FILES[c1] = { mode = "file", size = 100, modification = mtScr }
FILES[c2] = { mode = "file", size = 100, modification = mtScr }
W.fn({ c1, c2 })
n = #PENDING
PENDING[n - 1].fn() ; PENDING[n].fn()
check("beyond watchCap the rest are left for ⌘9 — and counted",
      #S.queue == 1 and S.leftForSweep == 1, S.leftForSweep)
S.queue, S.nameBusy, S.watchCap, S.leftForSweep = {}, false, 20, 0

out("   -- the ⌘9 row, the switch, and a Mac without the Shortcut --\n")
local rows = S.actionRows({ { name = "SCR-20260902-zzzz.png" },
                            { name = "Screenshot 2026-09-02 at 10.00.00 — done.png" } })
check("the ⌘9 row counts what is WAITING",
      (rows[9].subText or ""):find("1 waiting", 1, true) ~= nil, rows[9].subText)
check("…says 'nothing waiting' when every file carries its words",
      (S.actionRows({})[9].subText or ""):find("nothing waiting", 1, true) ~= nil)
check("…and reads as before when no list is to hand",
      (S.actionRows()[9].subText or ""):find("SCR-/word-less", 1, true) ~= nil)
S.watchFolder = false
n = #PENDING
W.fn({ NDIR .. "/SCR-20260902-offx.png" })
check("shots.watchFolder = false: the watcher is inert", #PENDING == n)
S.watchFolder = true
_G.ocrShortcutAvailable = false
local d = NDIR .. "/SCR-20260902-dddd.png"
FILES[d] = { mode = "file", size = 100, modification = mtScr }
before = #TASKS
W.fn({ d }) ; PENDING[#PENDING].fn()
check("no OCR Shortcut on this Mac: nothing spawned, nothing left queued",
      #TASKS == before and #S.queue == 0 and S.leftForSweep == 1)
_G.ocrShortcutAvailable = true
DEFER_TIMERS = false
S.leftForSweep = 0

os.rename = realRename
_G.service = savedService
_G.ocrShortcutAvailable = nil
S.dir = savedDir

-- =====================================================================
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("    ❌ " .. f .. "\n") end
out("\n")
os.exit(fail == 0 and 0 or 1)
