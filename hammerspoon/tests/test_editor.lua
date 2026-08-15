-- =====================================================================
-- test_editor.lua — the blur editor's Lua half
-- =====================================================================
--     lua5.4 test_editor.lua [/path/to/hammerspoon]
--
-- Executes modules/screenshot_editor.lua against a stubbed hs (webview
-- records HTML, io.open serves a fake PNG) and drives the real message
-- handler: open → save / cancel. The page's JavaScript half — the blur
-- itself — is executed for real by tests/test_editor_js.js under node;
-- this suite covers everything on the Lua side of the bridge.
--
-- THE RULES THIS SUITE ENFORCES ABOVE ALL OTHERS:
--   · The ORIGINAL FILE IS NEVER TOUCHED. Saving writes "… (edited).png"
--     next to it; cancelling writes nothing at all.
--   · A save that cannot be decoded alerts and keeps the editor open —
--     it never half-writes a file.

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

-- ---- fake filesystem: readable sources, recorded writes ---------------
local SRC = "/od/2026 Screenshots/Screenshot demo.png"
local READABLE = { [SRC] = "FAKE-PNG-BYTES" }
local WRITTEN  = {}     -- path -> bytes
local realOpen = io.open
io.open = function(path, mode)
    if mode == "rb" then
        local bytes = READABLE[path]
        if not bytes then return nil end
        return { read = function() return bytes end, close = function() end }
    elseif mode == "wb" then
        local buf = {}
        return {
            write = function(_, s) buf[#buf + 1] = s end,
            close = function() WRITTEN[path] = table.concat(buf) end,
        }
    end
    return realOpen(path, mode)
end

local ALERTS = {}
local LAST_HTML, BRIDGE, VIEW = nil, nil, nil
local CLIP = { kind = "empty" }

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
            local v = { rect = rect, deleted = false, shown = false }
            function v:html(s) LAST_HTML = s; return self end
            function v:show() self.shown = true; return self end
            function v:delete() self.deleted = true; return self end
            function v:windowTitle(t) self.title = t; return self end
            function v:allowTextEntry() return self end
            function v:closeOnEscape() return self end
            function v:level() return self end
            function v:behaviorAsLabels() return self end
            function v:bringToFront() return self end
            VIEW = v
            return v
        end,
    },
    drawing = { windowLevels = { floating = 5 } },
    screen = { mainScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
    end },
    base64 = {
        -- visible transformations, so the suite can PROVE they ran.
        -- encode wraps lines the way the real one does — the module must
        -- strip that or the data: URI dies inside WKWebView.
        encode = function(s) return "B64<" .. s:sub(1, 8) .. "\n" .. s:sub(9) .. ">" end,
        decode = function(s) return "DECODED<" .. s .. ">" end,
    },
    image = {
        imageFromPath = function(p)
            if not (READABLE[p] or WRITTEN[p]) then return nil end
            return { __path = p,
                     size = function() return { w = 800, h = 600 } end }
        end,
    },
    pasteboard = {
        writeObjects = function(o) CLIP = { kind = "image", v = o }; return true end,
    },
    fs = { attributes = function(p, k)
        if WRITTEN[p] then return k and #WRITTEN[p] or { size = #WRITTEN[p] } end
        return nil
    end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    timer = { secondsSinceEpoch = function() return 1000 end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local PROVIDED = {}
local CORE = {
    provide = function(n, f) PROVIDED[n] = f end,
    resolveBaseScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
    end,
}

local M = dofile(HS .. "/modules/screenshot_editor.lua")
M.setup(CORE)
local E = _G.screenshotEditor

-- =====================================================================
out("\n1. contract & wiring\n")
-- =====================================================================
check("module loads and has setup()", type(M.setup) == "function")
check("screenshotEditor.open is a service", type(PROVIDED["screenshotEditor.open"]) == "function")
check("cheat sheet group present with a title", type(M.cheatsheet) == "table"
      and type(M.cheatsheet.title) == "string")
check("edited files land NEXT TO the original",
      E.editedPathFor("/x/Shot.png") == "/x/Shot (edited).png",
      E.editedPathFor("/x/Shot.png"))

-- =====================================================================
out("2. open — the image travels INTO the page\n")
-- =====================================================================
check("open() on a readable file succeeds", E.open(SRC) == true)
check("a webview came up", VIEW ~= nil and VIEW.shown)
check("the window is named after the file",
      (VIEW.title or ""):find("Screenshot demo.png", 1, true) ~= nil, VIEW.title)
check("the page embeds the image as a base64 data: URI",
      LAST_HTML:find("data:image/png;base64,B64&lt;", 1, true) == nil
      and LAST_HTML:find("data:image/png;base64,B64<", 1, true) ~= nil)
check("🚨 the base64 is ONE UNBROKEN RUN — hs.base64.encode line-wraps, "
      .. "and a wrapped data: URI dies inside WKWebView without a word",
      LAST_HTML:find("base64,B64<FAKE%-PNG\n") == nil)
check("the page carries the blur core the node suite executes",
      LAST_HTML:find("function boxBlurRGBA", 1, true) ~= nil)
check("…and the undo stack", LAST_HTML:find("undoStack", 1, true) ~= nil)
check("…and the ⌘Z / ⌘⏎ / esc key handlers", LAST_HTML:find("'Escape'", 1, true) ~= nil
      and LAST_HTML:find("'Enter'", 1, true) ~= nil)

-- =====================================================================
out("3. save — an edited copy, never the original\n")
-- =====================================================================
BRIDGE({ body = { a = "save", data = "data:image/png;base64,EDITEDPNG" } })
local outPath = "/od/2026 Screenshots/Screenshot demo (edited).png"
check("the edited file is written next to the original",
      WRITTEN[outPath] ~= nil, next(WRITTEN))
check("…containing the DECODED bytes from the page",
      WRITTEN[outPath] == "DECODED<EDITEDPNG>", WRITTEN[outPath])
check("🚨 the ORIGINAL was not touched", WRITTEN[SRC] == nil)
check("the edited image went onto the clipboard", CLIP.kind == "image"
      and CLIP.v.__path == outPath)
check("…with an alert that says so", (ALERTS[#ALERTS] or ""):find("Saved") ~= nil,
      ALERTS[#ALERTS])
check("and the editor closed", E.webview == nil and VIEW.deleted)

-- a second save of the same screenshot numbers itself instead of
-- overwriting the first edit
E.open(SRC)
BRIDGE({ body = { a = "save", data = "data:image/png;base64,EDIT2" } })
check("a second edit becomes “… (edited 2).png”",
      WRITTEN["/od/2026 Screenshots/Screenshot demo (edited 2).png"] ~= nil)

-- =====================================================================
out("4. cancel & bad input\n")
-- =====================================================================
local writesBefore = 0
for _ in pairs(WRITTEN) do writesBefore = writesBefore + 1 end
E.open(SRC)
BRIDGE({ body = { a = "cancel" } })
local writesAfter = 0
for _ in pairs(WRITTEN) do writesAfter = writesAfter + 1 end
check("cancel writes NOTHING", writesAfter == writesBefore)
check("…and closes the editor", E.webview == nil)

E.open(SRC)
local alertsBefore = #ALERTS
BRIDGE({ body = { a = "save", data = "data:text/html;base64,NOTPNG" } })
check("a non-png save payload alerts instead of writing",
      #ALERTS == alertsBefore + 1 and (ALERTS[#ALERTS] or ""):find("failed") ~= nil,
      ALERTS[#ALERTS])
check("…and the editor STAYS OPEN so the work is not lost", E.webview ~= nil)
BRIDGE({ body = { a = "cancel" } })

check("open() on an unreadable file fails with an alert, no window",
      E.open("/nowhere/gone.png") == false
      and (ALERTS[#ALERTS] or ""):find("Could not read") ~= nil)

-- =====================================================================
out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("    ❌ " .. f .. "\n") end
out("\n")
os.exit(fail == 0 and 0 or 1)
