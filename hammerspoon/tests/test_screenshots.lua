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
    eventtap = { checkKeyboardModifiers = function() return MODS end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    chooser = {
        new = function(cb)
            local c = { cb = cb }
            function c:choices(t) CHOICES_SET = t; return self end
            function c:placeholderText() return self end
            function c:show() c.shown = true; return self end
            return c
        end,
    },
    timer = { secondsSinceEpoch = function() return 1000 end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local HYPER, PROVIDED, POPUPS = {}, {}, {}
local CORE = {
    homeDir = HOME,
    hyperAddShortcut = function(mods, key, fn, src)
        local ms = {}
        for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms)
        HYPER[table.concat(ms, "+") .. "|" .. key] = fn
    end,
    provide   = function(n, f) PROVIDED[n] = f end,
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
check("one choice per screenshot, path attached", #choices == 4
      and choices[1].path == shot1)
check("subText carries date and size", (choices[2].subText or ""):find("MB") ~= nil,
      choices[2].subText)
check("the cap is respected", (function()
    local old = S.maxList
    S.maxList = 2
    local c = S.choicesFrom(list)
    S.maxList = old
    return #c == 2
end)())

HYPER["shift|4"]()   -- open the history picker
check("⇪⇧4 shows the chooser through showPopup", #POPUPS == 1 and POPUPS[1].shown)
check("…with the rows loaded", type(CHOICES_SET) == "table" and #CHOICES_SET == 4)
check("…and thumbnails attached to real rows",
      CHOICES_SET[1].image ~= nil and CHOICES_SET[1].image.__path == shot1)

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
MODS = {}
local clipNow = CLIP
S.onPick({ text = "No screenshots yet" })   -- the empty-folder row has no path
check("the empty-folder row is a safe no-op", CLIP == clipNow)

-- =====================================================================
out("8. the empty folder & the missing folder\n")
-- =====================================================================
local saved = {}
for p, f in pairs(FILES) do saved[p] = f end
for p in pairs(saved) do FILES[p] = nil end
local c = S.choicesFrom(S.list())
check("an empty folder explains itself instead of showing nothing",
      #c == 1 and c[1].path == nil and (c[1].text or ""):find("No screenshots") ~= nil,
      c[1] and c[1].text)
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
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("    ❌ " .. f .. "\n") end
out("\n")
os.exit(fail == 0 and 0 or 1)
