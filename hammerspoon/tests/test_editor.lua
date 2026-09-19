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
EVENTS = {}             -- 6.255.0: hide / show / timer, IN ORDER
TIMERS = {}             -- 6.255.0: every hs.timer.doAfter the module holds
DEGRADES = {}           -- 6.255.0: every core.degrade the module takes
FOCUSED = false
NO_HSWINDOW = false
NO_TIMER = false

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
            function v:show() self.shown = true; self.hidden = false
                              EVENTS[#EVENTS + 1] = "show"; return self end
            -- 🧪 6.255.0 — a hide() that only returns self would let every
            -- "it got out of the way" check pass over a window that never
            -- moved: the getter-only stub, SIXTH time (6.193.0). It really
            -- hides, and the order it happens in is recorded, because the
            -- belt must be armed BEFORE the window goes.
            function v:hide() self.shown = false; self.hidden = true
                              EVENTS[#EVENTS + 1] = "hide"; return self end
            function v:hswindow()
                if NO_HSWINDOW then return nil end
                return { focus = function() FOCUSED = true; return true end }
            end
            function v:delete() self.deleted = true; return self end
            function v:windowTitle(t) self.title = t; return self end
            function v:allowTextEntry() return self end
            function v:closeOnEscape() return self end
            function v:level() return self end
            function v:behaviorAsLabels() return self end
            function v:bringToFront() return self end
            function v:evaluateJavaScript(js) JS[#JS + 1] = js; return self end
            -- 6.221.0 — the REAL webview answers :frame() and takes one;
            -- a stub without it hid a ⌘-drag strip that could not be read
            function v:frame(f) if f then self.rect = f end return self.rect end
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
    timer = {
        secondsSinceEpoch = function() return 1000 end,
        -- 6.255.0 — timers are HELD, not fired: the suite fires them by
        -- hand so the belt can be proven without waiting eight seconds.
        doAfter = function(secs, fn)
            if NO_TIMER then return nil end
            EVENTS[#EVENTS + 1] = "timer"
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true; return self end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local PROVIDED = {}
local CORE = {
    provide = function(n, f) PROVIDED[n] = f end,
    degrade = function(tool, why)
        DEGRADES[#DEGRADES + 1] = { tool = tool, why = tostring(why) }
        return false, why
    end,
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

-- =====================================================================
out("\n10. 6.221.0 — ⌘ belongs to the PAGE below the title bar\n")
-- =====================================================================
-- window_move's tap takes a bare-⌘ left-mouse-down anywhere inside a
-- listed panel's frame and begins a window drag, consuming the click. So
-- for LL's ⌘-click to reach a mark at all, this module must list only
-- the strip it is happy to be dragged by — its header.
local mine = 0
local function ck(label, cond, extra) mine = mine + 1; check(label, cond, extra) end

local F = { x = 100, y = 50, w = 900, h = 700 }
local strip = E.stripOf(F, 54)
ck("stripOf keeps the panel's x, y and WIDTH", strip and strip.x == 100
   and strip.y == 50 and strip.w == 900)
ck("🚨 …and only the header's height, so ⌘ below it reaches the canvas",
   strip and strip.h == 54, strip and strip.h)
ck("a strip taller than the window is CLAMPED to the window",
   (E.stripOf({ x = 0, y = 0, w = 10, h = 20 }, 54) or {}).h == 20)
ck("no frame → no strip (never a rectangle at 0,0)", E.stripOf(nil, 54) == nil
   and E.stripOf({ x = 1 }, 54) == nil)
ck("a zero or negative height → no strip, never the whole window",
   E.stripOf(F, 0) == nil and E.stripOf(F, -10) == nil)

local entry
for _, e in ipairs(_G.movablePanels or {}) do
    if e.name == "screenshot editor" then entry = e end
end
ck("the editor is still listed for Window Move", entry ~= nil)
E.open(SRC)
local listed = entry and entry.frame()
local win = E.webview and E.webview:frame()
ck("🚨 THE LISTED FRAME IS THE HEADER, NOT THE WINDOW — ⌘ inside the "
   .. "drawing area is the page's now, which is the whole of this fix",
   listed and win and listed.h == 54 and win.h > 54
   and listed.w == win.w and listed.y == win.y,
   listed and (listed.w .. "x" .. listed.h) or "nil")
ck("…and it still MOVES the whole window, not the strip",
   (function()
        entry.move(win.x + 40, win.y + 30)
        local f = E.webview:frame()
        return f.x == win.x + 40 and f.y == win.y + 30
               and f.w == win.w and f.h == win.h
    end)())
E.close()
ck("with the editor closed the strip is nil — nothing to ⌘-drag",
   entry.frame() == nil)

-- 🔒 the strip height and the page's own header height are ONE number.
-- If the header's CSS grows and this does not, ⌘-drag grabs part of the
-- canvas again — silently, and only on his Mac.
E.open(SRC)
ck("the page's #stage height is measured from the SAME header height the "
   .. "⌘-drag strip uses — the two cannot drift apart",
   LAST_HTML:find("height:calc(100vh - " .. E.dragStripH .. "px)", 1, true) ~= nil,
   E.dragStripH)
E.close()

check("§10 ran every one of its checks", mine == 10, mine)

-- =====================================================================
out("\n11. 6.255.0 — ⌘D: a delayed FULL-SCREEN capture, onto the shot\n")
-- =====================================================================
-- LL: "Add a delayed screenshot feature with a delay of 5 seconds."
-- The window has to get out of the way (a whole-screen shot taken with
-- the editor open is a picture of the editor) — and a window that hides
-- and does not come back is his work gone, so the belt is the half this
-- section spends most of its checks on.
do
    local n11 = 0
    local function c11(label, cond, extra) n11 = n11 + 1; check(label, cond, extra) end

    -- ---- the PURE plan ------------------------------------------------
    c11("grabPlan: open, service there, idle, 5 s → go, with the reason",
        (function()
            local ok, why = E.grabPlan(true, true, false, 5, true)
            return ok == true and tostring(why):find("5 second", 1, true) ~= nil
        end)())
    c11("grabPlan: the editor is not open → refused, named",
        select(2, E.grabPlan(false, true, false, 5, true)) == "the editor is not open")
    c11("grabPlan: no screenshots module → refused, and it names the module",
        tostring(select(2, E.grabPlan(true, false, false, 5, true)))
            :find("screenshots module", 1, true) ~= nil)
    c11("grabPlan: one already running → refused, NOT a second countdown",
        tostring(select(2, E.grabPlan(true, true, true, 5, true)))
            :find("already running", 1, true) ~= nil)
    c11("grabPlan: a ⌘D with no delay is refused and points at ⌘F — but the "
        .. "SAME zero is a perfectly good ⌘F, which is why it is one function",
        tostring(select(2, E.grabPlan(true, true, false, 0, true)))
            :find("Full screen", 1, true) ~= nil
        and E.grabPlan(true, true, false, 0, false) == true)

    -- ---- the page -----------------------------------------------------
    READABLE["/x/D.png"] = "PNGBYTES"
    E.close(); JS, ALERTS, EVENTS, TIMERS, DEGRADES = {}, {}, {}, {}, {}
    E.open("/x/D.png")
    c11("the page carries the ⏲ button, the ⌘D key and the door",
        LAST_HTML:find("say({a:'delay'})", 1, true) ~= nil
        and LAST_HTML:find("id=\"btn-delay\"", 1, true) ~= nil
        and LAST_HTML:find("e.key === 'd'", 1, true) ~= nil)
    c11("…and the button's LABEL says the configured number of seconds",
        LAST_HTML:find("⏲ Delayed 5s", 1, true) ~= nil)
    -- 6.239.0: assert the shipped default and the check passes when the
    -- number is typed in twice. Move the config; the page must follow.
    E.close(); E.delaySecs = 9; E.open("/x/D.png")
    c11("🚨 the label and the page's own DELAYSECS both come from the config "
        .. "— move it and both move, or they were two numbers",
        LAST_HTML:find("⏲ Delayed 9s", 1, true) ~= nil
        and LAST_HTML:find("var DELAYSECS = 9;", 1, true) ~= nil)
    E.delaySecs = 5

    -- ---- no service ----------------------------------------------------
    CORE.has  = function(n) return PROVIDED[n] ~= nil end
    CORE.call = function(n, ...) return PROVIDED[n](...) end
    PROVIDED["screenshots.captureScreenTo"] = nil
    E.close(); JS, ALERTS, EVENTS, TIMERS, DEGRADES = {}, {}, {}, {}, {}
    E.open("/x/D.png")
    EVENTS = {}          -- opening the window is a "show"; this is about ⌘D
    BRIDGE({ body = { a = "delay" } })
    c11("⌘D without the screenshots module: says so, and the window NEVER hides",
        (ALERTS[#ALERTS] or ""):find("screenshots module", 1, true) ~= nil
        and E.hidden == false and #EVENTS == 0, ALERTS[#ALERTS])

    -- ---- the happy path -------------------------------------------------
    local ASKED, CB = nil, nil
    PROVIDED["screenshots.captureScreenTo"] = function(secs, cb)
        ASKED = secs; CB = cb; return true
    end
    JS, ALERTS, EVENTS, TIMERS, DEGRADES = {}, {}, {}, {}, {}
    BRIDGE({ body = { a = "delay" } })
    c11("⌘D asks screenshots.captureScreenTo for the CONFIGURED seconds",
        ASKED == 5 and type(CB) == "function", ASKED)
    c11("…and the alert says how long he has to arrange the screen",
        (ALERTS[#ALERTS] or ""):find("5 seconds", 1, true) ~= nil, ALERTS[#ALERTS])
    c11("🪟 the editor HIDES — a full-screen shot taken over it is a "
        .. "picture of it", E.hidden == true)
    c11("🚨 THE BELT IS ARMED BEFORE THE WINDOW GOES (6.246.0's ordering): "
        .. "a hide with no way back is the failure this release could cause",
        EVENTS[1] == "timer" and EVENTS[2] == "hide",
        table.concat(EVENTS, ","))
    c11("…and the belt waits the countdown PLUS the grace, in its own slot",
        #TIMERS == 1 and TIMERS[1].secs == 5 + E.delayGraceSecs
        and E.delayTimer ~= nil, TIMERS[1] and TIMERS[1].secs)
    -- a second ⌘D while one is counting down
    local before = #TIMERS
    BRIDGE({ body = { a = "delay" } })
    c11("a second ⌘D mid-countdown is refused — one countdown, one shot",
        #TIMERS == before
        and (ALERTS[#ALERTS] or ""):find("already running", 1, true) ~= nil,
        ALERTS[#ALERTS])

    -- the capture lands
    local markerEncode = hs.base64.encode
    hs.base64.encode = function() return "RlVMTFNDUkVFTg==" end
    READABLE["/x/Full.png"] = "FULLSCREEN"
    FOCUSED = false
    CB("/x/Full.png")
    hs.base64.encode = markerEncode
    c11("🚨 the window comes BACK the moment the capture answers",
        E.hidden == false and VIEW.shown == true)
    c11("…and it asks for the keyboard once, rather than leaving a window "
        .. "that is up but not key (6.251.0)", FOCUSED == true)
    c11("…and the shot lands on the canvas as addImage(<data URI>, w, h)",
        JS[#JS] == "addImage('data:image/png;base64,RlVMTFNDUkVFTg==', 800, 600)",
        JS[#JS])
    c11("…counted as LANDED, and nothing degraded",
        E.delays.landed == 1 and E.delays.failed == 0 and #DEGRADES == 0)
    c11("…and the countdown is over, so ⌘D works again",
        E.delayBusy == false)

    -- ---- the capture fails ---------------------------------------------
    JS, ALERTS, EVENTS, DEGRADES = {}, {}, {}, {}
    BRIDGE({ body = { a = "delay" } })
    local pushed = #JS
    CB(nil, "screencapture exit 1 — could not create image")
    c11("a capture that did not land: the window is back, nothing pushed",
        E.hidden == false and #JS == pushed)
    c11("🔔 …and it takes the DOOR with screencapture's own words — a "
        .. "silence here is a shot he thinks he took",
        #DEGRADES == 1
        and DEGRADES[1].why:find("could not create image", 1, true) ~= nil,
        DEGRADES[1] and DEGRADES[1].why)
    c11("…counted as FAILED, apart from the ones that landed",
        E.delays.failed == 1 and E.delays.landed == 1)

    -- ---- the belt ------------------------------------------------------
    JS, ALERTS, EVENTS, DEGRADES, TIMERS = {}, {}, {}, {}, {}
    BRIDGE({ body = { a = "delay" } })
    c11("the window is hidden and waiting", E.hidden == true and #TIMERS == 1)
    TIMERS[1].fn()      -- the countdown passed and NOTHING ever answered
    c11("🚨 THE BELT BRINGS THE WINDOW BACK when the capture never answers "
        .. "— his work is in a live page he cannot see otherwise",
        E.hidden == false and VIEW.shown == true)
    c11("…and it says so rather than reading as health",
        #DEGRADES == 1 and DEGRADES[1].why:find("never answered", 1, true) ~= nil,
        DEGRADES[1] and DEGRADES[1].why)
    c11("…counted apart: a belt return means the capture answered NEVER, "
        .. "which is not the same fact as a capture that failed",
        E.delays.late == 1)
    c11("…and the busy flag is cleared, so ⌘D is not dead for the session",
        E.delayBusy == false)
    -- the late CB arriving after the belt must not hide anything again
    CB(nil, "too late")
    c11("a callback that arrives after the belt cannot re-hide the window",
        E.hidden == false)

    -- ---- a Mac that cannot arm a timer ---------------------------------
    JS, ALERTS, EVENTS, DEGRADES, TIMERS = {}, {}, {}, {}, {}
    NO_TIMER = true
    BRIDGE({ body = { a = "delay" } })
    c11("🚨 NO TIMER, NO HIDE: a shot that contains the editor is a bad "
        .. "picture; a window that cannot come back is lost work",
        E.hidden == false and #EVENTS == 0, table.concat(EVENTS, ","))
    NO_TIMER = false
    CB("/x/Full.png")

    -- ---- no hswindow ----------------------------------------------------
    JS, ALERTS, EVENTS, DEGRADES, TIMERS = {}, {}, {}, {}, {}
    NO_HSWINDOW, FOCUSED = true, false
    BRIDGE({ body = { a = "delay" } })
    CB(nil, "no")
    c11("a Mac whose window cannot be named still gets its editor back",
        E.hidden == false and FOCUSED == false)
    NO_HSWINDOW = false

    -- ---- the report ------------------------------------------------------
    local rpt = _G.screenshotEditorReport()
    c11("the report is ONE string (6.179.1) and it is returned",
        type(rpt) == "string" and rpt:find("\n", 1, true) ~= nil)
    c11("…it counts asked / landed / failed apart",
        rpt:find("capture :", 1, true) ~= nil
        and rpt:find("landed", 1, true) ~= nil
        and rpt:find("failed", 1, true) ~= nil, rpt)
    c11("…it names the belt's returns rather than printing health",
        rpt:find("brought back by the belt", 1, true) ~= nil, rpt)
    c11("…and it carries the settings line that turns the hiding off",
        rpt:find("hideForDelay", 1, true) ~= nil
        and rpt:find("delaySecs = 5", 1, true) ~= nil, rpt)
    -- 6.196.1 — never asked must not read like asked-and-nothing-happened
    E.delays = { asked = 0, landed = 0, failed = 0, late = 0 }
    local fresh = _G.screenshotEditorReport()
    c11("🔎 never asked reads differently from asked and failed",
        fresh:find("never asked", 1, true) ~= nil
        and fresh:find("0 asked", 1, true) == nil, fresh)

    E.close()
    check("§11 ran every one of its checks", n11 == 36, n11)
end

-- =====================================================================
out("\n12. 6.256.0 — ⌘F: the whole screen, NOW, with this window out of it\n")
-- =====================================================================
-- LL: "Add full screen snapshot tool." One body with ⌘D, one argument
-- apart: with a countdown screencapture's own -T covers the time the
-- window needs to leave the screen, and without one NOTHING does — so
-- the settle beat between the hide and the shutter IS this release.
do
    local n12 = 0
    local ASKED, CB    -- declared BEFORE the helpers, or `answer` closes
                       -- over a nil GLOBAL and every CB call is a no-op
    local function c12(label, cond, extra) n12 = n12 + 1; check(label, cond, extra) end
    -- 6.186.0 — a helper ANSWERS FALSELY rather than indexing a nil, or a
    -- mutation that removes a timer kills this section instead of failing
    -- a check in it.
    local function fire(i)
        local t = TIMERS[i]
        if not (t and type(t.fn) == "function") then return false end
        t.fn(); return true
    end
    local function answer(...)
        if type(CB) ~= "function" then return false end
        CB(...); return true
    end

    READABLE["/x/F.png"] = "PNGBYTES"
    CORE.has  = function(n) return PROVIDED[n] ~= nil end
    CORE.call = function(n, ...) return PROVIDED[n](...) end
    PROVIDED["screenshots.captureScreenTo"] = function(secs, cb)
        EVENTS[#EVENTS + 1] = "ask"; ASKED = secs; CB = cb; return true
    end

    E.close(); JS, ALERTS, EVENTS, TIMERS, DEGRADES = {}, {}, {}, {}, {}
    E.open("/x/F.png")
    c12("the page carries the 🖥 button, the ⌘F key and its door",
        LAST_HTML:find("say({a:'full'})", 1, true) ~= nil
        and LAST_HTML:find("id=\"btn-full\"", 1, true) ~= nil
        and LAST_HTML:find("e.key === 'f'", 1, true) ~= nil)

    EVENTS, TIMERS, ALERTS = {}, {}, {}
    BRIDGE({ body = { a = "full" } })
    c12("⌘F hides the editor and does NOT alert a countdown — there isn't one",
        E.hidden == true and #ALERTS == 0, ALERTS[1])
    c12("🚨 THE SHUTTER WAITS FOR THE WINDOW TO GO: belt, hide, settle — "
        .. "and NO ask yet. :hide() is not instant, and a screencapture on "
        .. "the next line photographs the editor",
        EVENTS[1] == "timer" and EVENTS[2] == "hide" and EVENTS[3] == "timer"
        and ASKED == nil, table.concat(EVENTS, ","))
    c12("…and the belt covers the settle as well as the countdown",
        TIMERS[1] and TIMERS[1].secs == 0 + E.hideSettleSecs + E.delayGraceSecs,
        TIMERS[1] and TIMERS[1].secs)
    c12("…the settle is its OWN held slot, never the belt's (6.196.1)",
        E.settleTimer ~= nil and E.delayTimer ~= nil
        and E.settleTimer ~= E.delayTimer)
    local beat = fire(2)   -- the window has gone; now the shutter
    c12("once the beat has passed the whole screen is asked for, no delay",
        beat and ASKED == 0 and type(CB) == "function", ASKED)

    local markerEncode = hs.base64.encode
    hs.base64.encode = function() return "V0hPTEVTQ1JFRU4=" end
    READABLE["/x/Whole.png"] = "WHOLESCREEN"
    answer("/x/Whole.png")
    hs.base64.encode = markerEncode
    c12("…and it lands on the shot as an image note, window back",
        E.hidden == false
        and JS[#JS] == "addImage('data:image/png;base64,V0hPTEVTQ1JFRU4=', 800, 600)",
        JS[#JS])

    -- a Mac that cannot arm the settle beat
    EVENTS, TIMERS, ASKED = {}, {}, nil
    NO_TIMER = true
    BRIDGE({ body = { a = "full" } })
    c12("🚨 no timer at all: it does NOT hide, and it still takes the shot — "
        .. "a picture with the editor in it beats no picture",
        E.hidden == false and ASKED == 0, table.concat(EVENTS, ","))
    NO_TIMER = false
    answer("/x/Whole.png")

    -- 🚨 6.255.0's wart, found building this one
    EVENTS, TIMERS, DEGRADES, ALERTS = {}, {}, {}, {}
    BRIDGE({ body = { a = "full" } })
    c12("a capture is running and the window is hidden",
        E.delayBusy == true and E.hidden == true)
    local belt = TIMERS[1]
    E.close()
    c12("🚨 CLOSING THE EDITOR MID-CAPTURE TEARS IT DOWN — the flags and "
        .. "BOTH timers, or the belt wakes to an editor HE closed",
        E.delayBusy == false and E.hidden == false
        and E.delayTimer == nil and E.settleTimer == nil
        and belt ~= nil and belt.stopped == true)
    fire(1)   -- even if it fires anyway, it must say nothing
    c12("…and a belt that fires anyway alerts nothing over a closed editor",
        #DEGRADES == 0, DEGRADES[1] and DEGRADES[1].why)

    check("§12 ran every one of its checks", n12 == 11, n12)
end

out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("    ❌ " .. f .. "\n") end
out("\n")
os.exit(fail == 0 and 0 or 1)
