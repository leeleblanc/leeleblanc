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
JS = {}                 -- 6.213.0: every evaluateJavaScript the module pushes
PB_IMAGE = nil          -- what hs.pasteboard.readImage answers

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
            function v:evaluateJavaScript(js) JS[#JS + 1] = js; return self end
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
        readImage = function() return PB_IMAGE end,
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
check("…as .jpg when the small-JPEG save asks for it",
      E.editedPathFor("/x/Shot.png", "jpg") == "/x/Shot (edited).jpg",
      E.editedPathFor("/x/Shot.png", "jpg"))

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
check("…and the text/arrow tools the node suite drives (6.88.0)",
      LAST_HTML:find("function drawNote", 1, true) ~= nil
      and LAST_HTML:find("function setTool", 1, true) ~= nil
      and LAST_HTML:find("'arrow'", 1, true) ~= nil)

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

-- the "Small JPEG" path (6.88.0): same rules, .jpg extension
E.open(SRC)
BRIDGE({ body = { a = "save", data = "data:image/jpeg;base64,EDITJPG", ext = "jpg" } })
check("a JPEG save writes “… (edited).jpg” next to the original",
      WRITTEN["/od/2026 Screenshots/Screenshot demo (edited).jpg"]
      == "DECODED<EDITJPG>",
      WRITTEN["/od/2026 Screenshots/Screenshot demo (edited).jpg"])
check("🚨 …and the ORIGINAL is still untouched", WRITTEN[SRC] == nil)

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
out("5. the work survives an accidental Esc (6.189.0)\n")
-- =====================================================================
-- LL: "I hit escape 2 times and all my screenshot work wasn't saved as I
-- accidentally hit escape." The page hands its state back on the way out
-- and it is held in ONE slot, keyed by the image path.
local KEEPIMG = "data:image/png;base64,BLURREDPIXELS+/="
local NOTES   = '[{"kind":"text","x":1,"y":2,"text":"hi"}]'
local keptSection0 = 0
for _ in pairs(WRITTEN) do keptSection0 = keptSection0 + 1 end

E.open(SRC)
BRIDGE({ body = { a = "cancel", img = KEEPIMG, notes = NOTES } })
check("Esc still writes NOTHING, even carrying the work out", (function()
          local n = 0; for _ in pairs(WRITTEN) do n = n + 1 end
          return n == keptSection0
      end)())
check("…and the work is held against the image path",
      E.kept ~= nil and E.kept.path == SRC and E.kept.img == KEEPIMG,
      E.kept and E.kept.path)

E.open(SRC)
check("reopening the SAME shot hands the kept image back to the page",
      LAST_HTML:find("RESTOREIMG   = '" .. KEEPIMG .. "'", 1, true) ~= nil)
check("…and the notes with it",
      LAST_HTML:find("RESTORENOTES = ''", 1, true) == nil
      and LAST_HTML:find("RESTORENOTES = 'B64<", 1, true) ~= nil)
check("…and LL is told his edits came back",
      (ALERTS[#ALERTS] or ""):find("back") ~= nil, ALERTS[#ALERTS])
BRIDGE({ body = { a = "cancel", img = KEEPIMG, notes = NOTES } })

-- 🚨 THE INJECTION RULE. A note's text is LL's typing and rides into a
-- <script> block; it must never arrive as markup. The notes go as base64
-- for exactly this reason, so the raw string must be absent from the page.
E.open(SRC)
BRIDGE({ body = { a = "cancel", img = KEEPIMG,
                  notes = '[{"kind":"text","text":"</script><b>x"}]' } })
E.open(SRC)
-- The stub encoder is deliberately VISIBLE (B64<…>), so the payload can
-- still be read inside its own literal. What must be true is that it went
-- THROUGH the encoder and that no second, unencoded copy was injected —
-- with the real hs.base64 that is exactly "arrives inert".
local restLit = LAST_HTML:match("RESTORENOTES = '([^']*)'") or ""
local restOf  = LAST_HTML:gsub("RESTORENOTES = '[^']*'", "", 1)
check("🚨 a note carrying </script> is ENCODED on the way into the page",
      restLit:sub(1, 4) == "B64<" and restLit:find("</script>", 1, true) ~= nil,
      restLit:sub(1, 40))
check("🚨 …and no unencoded copy of it is injected anywhere else",
      restOf:find("</script><b>x", 1, true) == nil)

-- keyed by PATH: a second screenshot opens clean (LL: "that's fine")
local OTHER = "/od/2026 Screenshots/Another shot.png"
READABLE[OTHER] = "FAKE-PNG-TWO"
E.open(OTHER)
check("a DIFFERENT shot opens clean — the slot does not follow it",
      LAST_HTML:find("RESTOREIMG   = ''", 1, true) ~= nil)
BRIDGE({ body = { a = "cancel" } })

-- a cancel with nothing usable keeps NOTHING rather than half a session
E.open(SRC)
BRIDGE({ body = { a = "cancel", img = "data:text/html;base64,NOPE", notes = NOTES } })
check("a cancel without a usable png keeps nothing at all", E.kept == nil)
E.open(SRC)
check("…so the next open restores the FILE, not a fragment",
      LAST_HTML:find("RESTOREIMG   = ''", 1, true) ~= nil)
BRIDGE({ body = { a = "cancel", img = KEEPIMG, notes = NOTES } })

-- the notes budget costs the annotations, never the whole rescue
E.keepMaxNoteBytes = 8
E.open(SRC)
BRIDGE({ body = { a = "cancel", img = KEEPIMG, notes = NOTES } })
check("oversized notes are dropped but the image is still kept",
      E.kept ~= nil and E.kept.img == KEEPIMG and E.kept.notes == "[]",
      E.kept and E.kept.notes)
E.keepMaxNoteBytes = 256 * 1024

-- and the image budget refuses the lot rather than keeping a fragment
E.keepMaxBytes = 4
E.open(SRC)
BRIDGE({ body = { a = "cancel", img = KEEPIMG, notes = NOTES } })
check("an image over the keep budget is refused outright", E.kept == nil)
E.keepMaxBytes = 40 * 1024 * 1024

-- SAVED work is not lost work — a slot left standing would restore a
-- stale state over the next open of the same shot
E.open(SRC)
BRIDGE({ body = { a = "cancel", img = KEEPIMG, notes = NOTES } })
E.open(SRC)
BRIDGE({ body = { a = "save", data = "data:image/png;base64,SAVEDPNG" } })
check("a save clears the slot", E.kept == nil)
E.open(SRC)
check("…so reopening after a save shows the file, not the old session",
      LAST_HTML:find("RESTOREIMG   = ''", 1, true) ~= nil)
BRIDGE({ body = { a = "cancel" } })

-- the switch LL can throw if any of this ever misbehaves
E.keepOnClose = false
E.open(SRC)
BRIDGE({ body = { a = "cancel", img = KEEPIMG, notes = NOTES } })
check("settings { screenshot_editor = { keepOnClose = false } } keeps nothing",
      E.kept == nil)
E.keepOnClose = true

-- =====================================================================
-- =====================================================================
out("\n9. 6.213.0 — ⌘V and ⌘A: an image INTO the page, through Lua\n")
-- =====================================================================
do
    local function open()
        JS, ALERTS = {}, {}
        READABLE["/x/Shot.png"] = "PNGBYTES"
        E.open("/x/Shot.png")
    end
    open()
    -- ⌘V with nothing usable on the clipboard
    PB_IMAGE = nil
    BRIDGE({ body = { a = "paste" } })
    check("⌘V with no image on the clipboard: an alert, nothing pushed",
          #JS == 0 and ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("Nothing to paste", 1, true) ~= nil, ALERTS[#ALERTS])
    -- ⌘V with an image
    PB_IMAGE = { encodeAsURLString = function() return "data:image/png;base64,PASTEDB64==" end,
                 size = function() return { w = 800, h = 600 } end }
    BRIDGE({ body = { a = "paste" } })
    check("🚨 ⌘V with an image: the page gets addImage(<data URI>, w, h) through evaluateJavaScript",
          JS[#JS] == "addImage('data:image/png;base64,PASTEDB64==', 800, 600)", JS[#JS])
    -- a URI the page could not parse never reaches WebKit
    PB_IMAGE = { encodeAsURLString = function() return "data:image/png;base64,bad'; alert(1); //" end,
                 size = function() return { w = 8, h = 8 } end }
    local before = #JS
    BRIDGE({ body = { a = "paste" } })
    check("a URI that is not pure base64 is REFUSED, never pushed into a script",
          #JS == before and ALERTS[#ALERTS]:find("not a usable image", 1, true) ~= nil, ALERTS[#ALERTS])
    PB_IMAGE = { encodeAsURLString = function() return "data:image/png;base64,AAAA" end,
                 size = function() return { w = 0, h = 0 } end }
    BRIDGE({ body = { a = "paste" } })
    check("an image with no size is refused, named", ALERTS[#ALERTS]:find("no size", 1, true) ~= nil)
    check("pushImage returns ok, why and never throws", (function()
        local ok, why = E.pushImage("junk", 1, 1)
        return ok == false and why == "not a usable image"
    end)())

    -- ⌘A with no screenshots module
    CORE.has  = function(n) return PROVIDED[n] ~= nil end
    CORE.call = function(n, ...) return PROVIDED[n](...) end
    PROVIDED["screenshots.captureAreaTo"] = nil
    BRIDGE({ body = { a = "capture" } })
    check("⌘A without the screenshots module: says so, pushes nothing",
          ALERTS[#ALERTS]:find("screenshots module", 1, true) ~= nil and #JS == before, ALERTS[#ALERTS])
    -- ⌘A with the service: the callback with a path reads the file and pushes it
    local CAPTURE_CB
    PROVIDED["screenshots.captureAreaTo"] = function(cb) CAPTURE_CB = cb return true end
    BRIDGE({ body = { a = "capture" } })
    check("⌘A asks screenshots.captureAreaTo and waits", type(CAPTURE_CB) == "function" and #JS == before)
    READABLE["/x/Cap.png"] = "CAPTUREBYTES"
    -- this suite's base64 stub writes visible markers (B64<…>), which a
    -- data URI can never carry; for the door that pushes a URI the stub
    -- answers the REAL shape — base64 characters, line-wrapped at 76 as
    -- hs.base64.encode does
    local markerEncode = hs.base64.encode
    hs.base64.encode = function() return "Q0FQVFVSRUJZVEVT\nQkFTRTY0" end
    CAPTURE_CB("/x/Cap.png")
    hs.base64.encode = markerEncode
    check("🚨 …the capture that lands is read, encoded and pushed as addImage(...) with its size",
          JS[#JS] == "addImage('data:image/png;base64,Q0FQVFVSRUJZVEVTQkFTRTY0', 800, 600)", JS[#JS])
    check("…with hs.base64's line-wrap stripped (a broken data URI is a silent nothing in WebKit)",
          JS[#JS] and not JS[#JS]:find("\n", 1, true))
    check("…and a wrap that survived would have been REFUSED, not pushed (the shape is checked at the door)",
          select(2, E.pushImage("data:image/png;base64,QUJD\nREVG", 8, 8)) == "not a usable image")
    before = #JS
    CAPTURE_CB(nil, "screencapture exit 1 — could not create image")
    check("a capture that did not land: the reason is alerted, nothing pushed",
          #JS == before and ALERTS[#ALERTS]:find("Capture did not land — screencapture exit 1", 1, true) ~= nil, ALERTS[#ALERTS])
    CAPTURE_CB("/x/missing.png")
    check("a path that cannot be read: alerted, nothing pushed",
          #JS == before and ALERTS[#ALERTS]:find("could not be read", 1, true) ~= nil, ALERTS[#ALERTS])
    -- the buttons and keys are in the page
    check("the page has the Spotlight and Magnifier tools and the two doors",
          LAST_HTML:find("id=\"tool-spot\"", 1, true) ~= nil and LAST_HTML:find("id=\"tool-mag\"", 1, true) ~= nil
          and LAST_HTML:find("say({a:'paste'})", 1, true) ~= nil and LAST_HTML:find("say({a:'capture'})", 1, true) ~= nil
          and LAST_HTML:find("function addImage(", 1, true) ~= nil)
    check("…and the zoom / veil knobs reach it", LAST_HTML:find("var MAGZOOM = 2;", 1, true) ~= nil
          and LAST_HTML:find("var VEIL = 0.55;", 1, true) ~= nil)
    E.close()
end

out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("    ❌ " .. f .. "\n") end
out("\n")
os.exit(fail == 0 and 0 or 1)
