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
            -- 6.286.0 — recorded in EVENTS too, so a check can assert that
            -- the close belt is armed BEFORE the page is asked. Ordering is
            -- the rule; a check that only counts cannot see it.
            function v:evaluateJavaScript(js)
                JS[#JS + 1] = js; EVENTS[#EVENTS + 1] = "js"; return self
            end
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
    -- 6.258.0 — ⌘O's picker. It REMEMBERS its rows and its callback so the
    -- suite can choose a row for real rather than calling the grow by hand
    -- (6.203.0: a harness that builds the message cannot see a bug in the
    -- sending).
    chooser = { new = function(cb)
        local c = { _cb = cb, rows = {}, shown = false, hidden = false }
        function c:choices(x) if x then self.rows = x end return self.rows end
        function c:placeholderText() return self end
        function c:show() self.shown = true; return self end
        function c:hide() self.hidden = true; self.shown = false; return self end
        function c:pick(i) self._cb(self.rows[i]) end
        CHOOSER = c
        return c
    end },
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

CHOOSER = nil           -- 6.258.0: the last hs.chooser the module made
SERVICES = {}           -- 6.258.0: what core.has / core.call answer
_G.choosers = {}

local PROVIDED = {}
local CORE = {
    provide = function(n, f) PROVIDED[n] = f end,
    has  = function(n) return SERVICES[n] ~= nil end,
    call = function(n, ...) local f = SERVICES[n]; if f then return f(...) end end,
    showPopup = function(c) POPPED = c; pcall(function() c:show() end) end,
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

-- 🖼 6.270.0 — THE RAILS EXIST, AND THEY ARE SIZED FROM THE CONFIG.
-- LL, three times: the editor "has not had the tools that run across the
-- top of the editor and a column on the left-hand side and the right hand
-- side". It never had them — all eighteen buttons were in ONE wrapping
-- strip. These checks are about the STRUCTURE, because a rail that is
-- present but empty, or present but sized by a literal, is the same
-- complaint again next month.
E.open(SRC)
ck("🖼 there is a rail on the LEFT and a rail on the RIGHT",
   LAST_HTML:find('id="railL"', 1, true) ~= nil
   and LAST_HTML:find('id="railR"', 1, true) ~= nil)
-- 🚨 MATCHED WITH ITS CLOSING QUOTE, and that is not fussiness: the first
-- version of this check searched for the bare id, and `tool-blur` is a
-- PREFIX of `tool-blur-moved`, so a renamed button satisfied it and the
-- mutation that renames one passed the gate. 6.236.0's rule — a name
-- sentry matches the delimiter — in a check written to catch exactly this
-- shape of silent regression.
ck("🖼 the drawing TOOLS are in the left rail, not the top strip",
   (function()
       local l = LAST_HTML:match('<nav id="railL".-</nav>') or ""
       for _, id in ipairs({ "tool-blur", "tool-text", "tool-arrow", "tool-line",
                             "tool-oval", "tool-hl", "tool-count", "tool-spot",
                             "tool-mag" }) do
           if not l:find('id="' .. id .. '"', 1, true) then
               return false, id .. " is not in the left rail"
           end
       end
       return true
   end)())
ck("🖼 the capture and edit ACTIONS are in the right rail",
   (function()
       local r = LAST_HTML:match('<nav id="railR".-</nav>') or ""
       for _, w in ipairs({ "a:'paste'", "a:'capture'", "a:'delay'", "a:'full'",
                            "a:'loadshot'", "undoLast()" }) do
           if not r:find(w, 1, true) then return false, w .. " is not in the right rail" end
       end
       return true
   end)())
-- 🚨 THE CHECK THAT STOPS IT SILENTLY REGRESSING: a button left behind in
-- the header is a rail that only LOOKS built. The top strip keeps the
-- title, the three finish actions and the hint — and nothing else.
ck("🖼 the top strip carries ONLY the title, the finish actions and the "
   .. "hint — a tool left behind there is a rail that only looks built",
   (function()
       local h = LAST_HTML:match("<header>.-</header>") or ""
       for _, w in ipairs({ "setTool(", "a:'paste'", "a:'capture'", "a:'delay'",
                            "a:'full'", "a:'loadshot'", "undoLast()" }) do
           if h:find(w, 1, true) then return false, w .. " is still in the header" end
       end
       return h:find("saveIt('png')", 1, true) ~= nil
          and h:find("stashAndCancel()", 1, true) ~= nil
   end)())
-- 6.239.0 — the rail width is ONE number, read by the CSS and by
-- ed.windowSizeFor. Move it and the page must move with it, or the window
-- reserves 136 points for a rail drawn 200 wide.
ck("🖼 the rail's CSS width is written from ed.railW, not typed in",
   LAST_HTML:find("width:" .. E.railW .. "px", 1, true) ~= nil, E.railW)
ck("🖼 …and the canvas leaves room for BOTH rails, which is his "
   .. "'big enough to accommodate the tool buttons on each side'",
   LAST_HTML:find("max-width:calc(100vw - " .. (E.railW * 2 + 24) .. "px)", 1, true) ~= nil,
   E.railW * 2 + 24)
E.close()

-- Now MOVE it, and require the drawing to follow.
local savedRail = E.railW
E.railW = 210
E.open(SRC)
ck("🖼 moving ed.railW moves the rail AND the canvas budget together",
   LAST_HTML:find("width:210px", 1, true) ~= nil
   and LAST_HTML:find("max-width:calc(100vw - " .. (210 * 2 + 24) .. "px)", 1, true) ~= nil)
E.close()
E.railW = savedRail

check("§10 ran every one of its checks", mine == 17, mine)

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

-- =====================================================================
out("13. 6.258.0 — ⌘O: a prior shot onto this one, and the canvas grows\n")
-- =====================================================================
-- LL: "Allow me to load a prior screenshot on to the current screenshot
-- and grow the canvas so that I can see both." The geometry is PURE and
-- lives in Lua, so all of it is proven here with no Mac and no WebKit;
-- the page is given the numbers and does them (its own section is in
-- test_editor_js.js).
do
    local n13 = 0
    local function c13(label, cond, extra) n13 = n13 + 1; check(label, cond, extra) end

    -- ---- which way it grows -------------------------------------------
    local ax, why = E.growAxis(2560, 1440)
    c13("🧭 a WIDE shot grows downwards — two of them stacked is nearly "
        .. "square, side by side is a 5120-pixel strip", ax == "down", ax)
    c13("...and says why", why == "a wide shot grows downwards", why)
    c13("🧭 a TALL shot grows sideways", E.growAxis(900, 1600) == "right")
    c13("a square canvas grows sideways — the tie has to go somewhere and "
        .. "it is stated rather than accidental", E.growAxis(800, 800) == "right")
    c13("a canvas with no size is not an axis", E.growAxis(0, 100) == nil)
    c13("...and says so", select(2, E.growAxis(nil, nil)) == "the canvas has no size")

    -- ---- the plan ------------------------------------------------------
    local p = E.growPlan(2560, 1440, 2560, 1440, nil, 12)
    c13("📐 two equal wide shots: the canvas keeps its width…",
        p and p.w == 2560, p and p.w)
    c13("…and grows by the second shot plus the gap",
        p and p.h == 1440 + 12 + 1440, p and p.h)
    c13("📏 THE ORIGINAL NEVER MOVES — it keeps 0,0, because every note, "
        .. "blur and arrow on this canvas is in canvas coordinates and "
        .. "would otherwise move with it", p and p.x == 0)
    c13("…and the loaded shot lands under it, past the gap",
        p and p.y == 1440 + 12, p and p.y)

    local wide = E.growPlan(1000, 800, 1600, 400, nil, 10)
    c13("📐 a WIDER shot widens the canvas rather than being cropped",
        wide and wide.w == 1600, wide and wide.w)
    c13("…and the original is STILL at 0,0 — centring it would be tidier "
        .. "and would move every mark he has already drawn",
        wide and wide.x == 0 and wide and wide.y == 810, wide and wide.y)

    local tall = E.growPlan(600, 1600, 500, 900, nil, 12)
    c13("📐 a tall canvas puts the loaded shot BESIDE it",
        tall and tall.axis == "right" and tall.x == 612 and tall.y == 0,
        tall and (tall.axis .. " " .. tall.x .. "," .. tall.y))
    c13("…and the canvas keeps the taller of the two",
        tall and tall.h == 1600 and tall.w == 600 + 12 + 500,
        tall and (tall.w .. "x" .. tall.h))

    c13("🔌 an axis given by name WINS over the computed one",
        (E.growPlan(2560, 1440, 100, 100, "right", 0) or {}).axis == "right")
    c13("…and an axis that is not one of the two falls back to the rule",
        (E.growPlan(2560, 1440, 100, 100, "sideways-ish", 0) or {}).axis == "down")
    c13("the gap is honoured", (E.growPlan(100, 100, 50, 50, "down", 30) or {}).y == 130)
    c13("a NEGATIVE gap is clamped to nothing — it would overlap the two "
        .. "shots, which is the one thing this feature must not do",
        (E.growPlan(100, 100, 50, 50, "down", -40) or {}).y == 100)
    c13("no gap at all is 0, never an error",
        (E.growPlan(100, 100, 50, 50, "down", nil) or {}).y == 100)
    c13("a shot with no size is refused", E.growPlan(100, 100, 0, 50) == nil)
    c13("…by name", select(2, E.growPlan(100, 100, 0, 50)) == "that shot has no size")
    c13("a canvas with no size is refused, and differently",
        select(2, E.growPlan(0, 0, 50, 50)) == "the canvas has no size")
    c13("the reason names both shots, so the report reads as a measurement",
        (select(2, E.growPlan(2560, 1440, 800, 600)) or ""):find("800x600", 1, true) ~= nil)

    -- ---- the window follows -------------------------------------------
    -- 🖼 6.270.0 — THE RAILS ARE ROOM, NOT PADDING. These checks used to
    -- assert 828 and 320, which were the numbers before there was a rail
    -- to fit; asserting a constant is how a check ends up with nothing to
    -- say about the change it should be proving (6.248.0). They ask the
    -- RULE now, in terms of the config, so moving a rail moves the check.
    local SCR = { x = 0, y = 0, w = 1440, h = 900 }
    local w1, h1 = E.windowSizeFor(800, 600, SCR)
    c13("🪟 a small shot gets its own size, the chrome, AND BOTH RAILS — "
        .. "the window grows; the picture is not squeezed to make room",
        w1 == 800 + 28 + E.railW * 2 and h1 == 600 + E.dragStripH + 28,
        w1 .. "x" .. h1 .. " (railW " .. tostring(E.railW) .. ")")
    c13("🪟 …which is strictly wider than the pre-rail window, or the "
        .. "buttons would be sitting on the screenshot",
        w1 > 828, w1)
    local w2, h2 = E.windowSizeFor(3840, 2160, SCR)
    c13("🪟 a 4K shot is CLAMPED to the screen rather than opening off it, "
        .. "rails included",
        w2 <= 1440 * 0.85 + 28 and h2 <= 900 * 0.85 + 82, w2 .. "x" .. h2)
    local w3, h3 = E.windowSizeFor(10, 10, SCR)
    c13("🪟 …and the floor now fits the TOOLBAR, not just a usable window: "
        .. "a tiny shot no longer opens too short to show its own tools",
        w3 == 720 and h3 == E.railMinH + E.dragStripH, w3 .. "x" .. h3)

    -- 6.239.0 — move the config and the arithmetic must follow. Asserting
    -- the shipped 136 passes on a build where the number is typed twice.
    local wWide = E.windowSizeFor(800, 600, SCR, { railW = 200, headerH = 54,
                                                   railMinH = 344 })
    c13("🪟 a WIDER rail makes a wider window, by exactly twice the "
        .. "difference — the reservation is real arithmetic, not a constant",
        wWide == 800 + 28 + 400, wWide)
    local wNone = E.windowSizeFor(800, 600, SCR, { railW = 0, headerH = 54,
                                                   railMinH = 0 })
    c13("🪟 …and with no rails at all it is the old window exactly, which "
        .. "is what proves the rails are the whole difference",
        wNone == 828, wNone)

    -- The picture must keep the size it would have had. A screen with room
    -- to spare must not shrink the shot just because rails now exist.
    local _, hPlain = E.windowSizeFor(800, 600, SCR, { railW = 0, headerH = 54,
                                                       railMinH = 0 })
    c13("🪟 the SHOT is unchanged by the rails on a screen with room — the "
        .. "height is the picture plus chrome either way",
        h1 == hPlain, h1 .. " vs " .. hPlain)

    -- A screen narrower than its own rails must not invert the arithmetic.
    local wTiny, hTiny = E.windowSizeFor(800, 600, { x = 0, y = 0, w = 200, h = 200 },
                                         { railW = 300, headerH = 54, railMinH = 344 })
    c13("🪟 a screen narrower than the rails themselves still answers a "
        .. "positive window rather than a negative one",
        type(wTiny) == "number" and wTiny > 0 and hTiny > 0, wTiny .. "x" .. hTiny)
    local w4 = E.windowSizeFor(nil, nil, nil)
    c13("🪟 garbage in does not throw — it sizes for a default shot",
        type(w4) == "number" and w4 > 0, w4)

    -- ---- the one door --------------------------------------------------
    c13("🔒 a png data URI is usable", E.imageURIok("data:image/png;base64,AAAB") == true)
    c13("🔒 a QUOTE is not — it would end the JavaScript string literal "
        .. "this URI is pushed inside, and a script WebKit cannot parse is "
        .. "dropped in SILENCE",
        E.imageURIok("data:image/png;base64,AA'+alert(1)+'") == false)
    c13("🔒 a plain path is not an image", E.imageURIok("/x/shot.png") == false)
    c13("🔒 nil is not an image, and does not throw", E.imageURIok(nil) == false)

    -- ---- the canvas size, and WHO says so ------------------------------
    JS = {}
    check("(the editor is open for this section)", E.open(SRC) == true)
    local cw, ch, who = E.canvasSize()
    c13("📏 before the page speaks, Lua uses the size it read off the FILE",
        cw == 800 and ch == 600, tostring(cw) .. "x" .. tostring(ch))
    c13("…and says that is where the number came from — a ⌘O this early "
        .. "still works, and the report does not pretend the page answered",
        who == "read off the file at open", who)
    BRIDGE({ body = { a = "size", w = 2560, h = 1440 } })
    local cw2, _, who2 = E.canvasSize()
    c13("📏 once the page says its size, THAT is the canvas", cw2 == 2560, cw2)
    c13("…and the report can tell the two apart (6.196.1)",
        who2 == "the page said so", who2)
    BRIDGE({ body = { a = "size", w = 0, h = 0 } })
    local cw3, _, who3 = E.canvasSize()
    c13("🚨 a size of zero is not an answer — it is ignored rather than "
        .. "believed, or the next grow plans against nothing",
        cw3 == 2560 and who3 == "the page said so", tostring(cw3))

    -- ---- the grow itself ------------------------------------------------
    JS = {}
    local okG, whyG = E.growWith("data:image/png;base64,SECOND", 2560, 1440)
    c13("🖼 the grow lands", okG == true, whyG)
    local grew = JS[#JS] or ""
    c13("…and the page is GIVEN the numbers rather than working them out",
        grew:find("growTo('data:image/png;base64,SECOND', 2560, 2892, 0, 1452", 1, true) ~= nil,
        grew)
    c13("…the fill colour rides with them", grew:find("#202127", 1, true) ~= nil)
    c13("🪟 the window grew with the canvas",
        VIEW.rect.w == E.windowSizeFor(2560, 2892, { w = 1440, h = 900 }),
        VIEW.rect.w)
    -- 🚨 THE BELT, ASSERTED WHERE IT BITES. "canvasSize now reads 2892"
    -- passes with the belt deleted too, because the old number is still a
    -- number — so the check is a SECOND ⌘O with no word from the page in
    -- between, which must plan against the canvas the first one made.
    JS = {}
    local okTwice = E.growWith("data:image/png;base64,THIRD", 2560, 1440)
    local twice = JS[#JS] or ""
    c13("🚨 a second ⌘O before the page has spoken again plans against the "
        .. "canvas the FIRST one made, not the one before it — and the "
        .. "axis is recomputed, so the now-TALL canvas grows sideways",
        okTwice == true
        and twice:find("2560x1440 beside", 1, true) == nil
        and twice:find("', 5132, 2892, 2572, 0", 1, true) ~= nil, twice:sub(1, 70))

    JS = {}
    local okBad, whyBad = E.growWith("/not/a/uri.png", 100, 100)
    c13("🔒 a refused URI never reaches WebKit", okBad == false and #JS == 0, #JS)
    c13("…and says why", whyBad == "not a usable image", whyBad)

    E.close()
    local okShut = E.growWith("data:image/png;base64,X", 10, 10)
    c13("a closed editor cannot grow", okShut == false)
    local _, _, whoShut = E.canvasSize()
    c13("🚨 and closing FORGETS the canvas — a size left behind is a grow "
        .. "planned against a page that no longer exists",
        whoShut == "not known", whoShut)

    -- ---- ⌘O's picker ----------------------------------------------------
    -- Earlier sections repoint CORE.has at their own registry, so this one
    -- claims it back rather than assuming what a section three hundred
    -- lines up left behind.
    SERVICES = {}
    CORE.has  = function(n) return SERVICES[n] ~= nil end
    CORE.call = function(n, ...) local f = SERVICES[n]; if f then return f(...) end end
    E.open(SRC)
    local okNo, whyNo = E.loadPrior()
    c13("🔌 with the screenshots module absent, ⌘O says so and changes "
        .. "nothing", okNo == false and (whyNo or ""):find("screenshots module", 1, true),
        whyNo)

    SERVICES["screenshots.list"] = function()
        return {
            { name = "Later.png",  path = "/od/2026 Screenshots/Later.png",
              mtime = 200, size = 2048 },
            { name = "Screenshot demo.png", path = SRC, mtime = 150, size = 1024 },
            { name = "Older.png",  path = "/od/2026 Screenshots/Older.png",
              mtime = 100, size = 512 },
        }
    end
    READABLE["/od/2026 Screenshots/Later.png"] = "FAKE-SECOND-PNG"
    CHOOSER = nil
    local okPick, whyPick = E.loadPrior()
    c13("🖼 ⌘O opens a picker of the folder's other shots", okPick == true
        and CHOOSER ~= nil and CHOOSER.shown == true, whyPick)
    -- 6.186.0 — every read of the picker below goes through these, so a
    -- mutation that stops it being made FAILS a check rather than ending
    -- the run at an index of nil.
    local function rowCount() return CHOOSER and #CHOOSER.rows or -1 end
    local function row(i)
        return (CHOOSER and CHOOSER.rows[i]) or { text = "(no picker)", path = "" }
    end
    c13("🚨 the shot he is ALREADY editing is not offered — loading a shot "
        .. "onto itself is the one row that can only be a mistake",
        rowCount() == 2 and row(1).text == "Later.png"
        and row(2).text == "Older.png", rowCount())
    c13("…each row carries its path and when it was taken",
        row(1).path == "/od/2026 Screenshots/Later.png"
        and (row(1).subText or ""):find("KB", 1, true) ~= nil,
        row(1).subText)
    c13("…and the picker is in the Esc registry like every other chooser "
        .. "here", _G.choosers.editorLoadShot == CHOOSER)

    JS = {}
    BRIDGE({ body = { a = "size", w = 800, h = 600 } })
    -- 🔒 THE DOOR BITES ON THE REAL ROUTE, and this suite's own encoder
    -- proves it: hs.base64.encode is stubbed here to a VISIBLE transform
    -- ("B64<…>") so other sections can see it ran — and those angle
    -- brackets are exactly what `ed.imageURIok` refuses, so a shot read
    -- off disk and encoded that way never reaches WebKit.
    if CHOOSER then CHOOSER:pick(1) end
    c13("🔒 a file whose encoding is not base64 is refused on the way in, "
        .. "on the path from DISK rather than only in a unit check",
        #JS == 0, JS[1])
    c13("…and the refusal is remembered for the report",
        (E.lastGrowWhy or "") == "not a usable image", E.lastGrowWhy)

    local realEncode = hs.base64.encode
    hs.base64.encode = function(bytes) return "SEC" .. #bytes end
    JS = {}
    _G.choosers.editorLoadShot = nil
    E.loadPrior()
    if CHOOSER then CHOOSER:pick(1) end
    hs.base64.encode = realEncode
    local pushed = JS[#JS] or ""
    c13("🖼 picking a row reads that file and grows the canvas — driven "
        .. "through the chooser's own callback, not by calling the grow "
        .. "by hand (6.203.0)",
        pushed:find("growTo(", 1, true) == 1, pushed:sub(1, 40))
    c13("…with the SECOND file's bytes, not the open one's",
        pushed:find("SEC15", 1, true) ~= nil, pushed:sub(1, 60))
    c13("…and the picker lets go of the registry when it answers",
        _G.choosers.editorLoadShot == nil)

    SERVICES["screenshots.list"] = function()
        return { { name = "Screenshot demo.png", path = SRC, mtime = 1, size = 1 } }
    end
    local okEmpty, whyEmpty = E.loadPrior()
    c13("a folder holding only this shot says so rather than opening an "
        .. "empty picker", okEmpty == false
        and (whyEmpty or ""):find("no other screenshots", 1, true) ~= nil, whyEmpty)

    -- ---- the report ------------------------------------------------------
    printed = {}
    local rep = _G.screenshotEditorReport()
    c13("🔎 the report prints as ONE string (6.179.1)", #printed == 1, #printed)
    c13("…it names the canvas and who said so",
        rep:find("canvas  :", 1, true) ~= nil
        and rep:find("the page said so", 1, true) ~= nil)
    c13("…and counts the grows", rep:find("grow    :", 1, true) ~= nil
        and rep:find("asked", 1, true) ~= nil, rep)

    E.close()
    E.open(SRC)
    printed = {}
    local rep2 = _G.screenshotEditorReport()
    c13("🔎 the counts are per SESSION, not per window — closing and "
        .. "reopening the editor does not forget what this session did",
        rep2:find("grow    :", 1, true) ~= nil
        and rep2:find("never asked", 1, true) == nil)
    E.grows.asked, E.grows.landed, E.grows.failed = 0, 0, 0
    printed = {}
    local rep3 = _G.screenshotEditorReport()
    c13("🔎 …and a session with no ⌘O in it reads DIFFERENTLY from one "
        .. "where every grow failed (6.196.1)",
        rep3:find("never asked this session", 1, true) ~= nil)
    E.close()

    check("§13 ran every one of its checks", n13 == 66, n13)
end

-- =====================================================================
out("\n14. 🚪 6.286.0 — the work survives EVERY door out, not just Cancel\n")
-- =====================================================================
-- LL, with an annotated screenshot: "Closing the screenshot editor dumps
-- the most recent edits so I lose any changes." 6.189.0 promises the
-- opposite and was telling the truth about exactly ONE way out — the
-- Cancel button, which is the only thing that called the page's
-- stashAndCancel(). The Esc router called ed.close() straight out, and
-- ed.open() calls ed.close() as its first line, so opening a second shot
-- threw the first one's marks away in silence.
do
    local n14 = pass + fail
    local function c14(l, cond, extra) check(l, cond, extra) end

    -- ---- the plan is PURE ------------------------------------------------
    c14("ed.closePlan is pure and reachable", type(E.closePlan) == "function")
    local p1 = E.closePlan(false, true, true)
    c14("no editor open → close now", p1 == "now", p1)
    local p2 = E.closePlan(true, false, true)
    c14("a page that cannot be asked → close now, rather than waiting on an "
        .. "answer nothing would send", p2 == "now", p2)
    local p3 = E.closePlan(true, true, false)
    c14("🚨 no timer → ASK and close anyway. A window that will not close is "
        .. "worse than marks that were not kept", p3 == "askThenNow", p3)
    local p4 = E.closePlan(true, true, true)
    c14("otherwise: ask the page first", p4 == "ask", p4)
    c14("…and every answer carries its reason",
        select(2, E.closePlan(true, true, true)) ~= nil
        and select(2, E.closePlan(false, true, true)) ~= nil)

    -- ---- Esc through the router -----------------------------------------
    E.close()
    E.closes = { asked = 0, stashed = 0, belt = 0, atOnce = 0, last = nil }
    E.kept = nil
    TIMERS = {}
    JS = {}
    E.open(SRC)
    c14("the editor is open", E.webview ~= nil)
    EVENTS = {}          -- the ordering below is about THIS close alone
    E.requestClose("Esc")
    c14("🚨 Esc ASKS THE PAGE for its work instead of deleting the window — "
        .. "this is the whole release", JS[#JS] == "stashAndCancel()", JS[#JS])
    c14("…and the window is still open while it waits", E.webview ~= nil)
    c14("…with a belt armed BEFORE the ask (6.246.0's ordering), so a page "
        .. "that throws cannot leave a window nobody can close",
        E.closeTimer ~= nil and E.closeTimer.secs == E.closeGraceSecs)
    -- 🚨 AND THE ORDER IS THE RULE, not the presence. A check that only
    -- asserts both happened passes with the belt armed second, which is
    -- the arrangement the ordering exists to forbid (6.220.0).
    c14("🚨 …and the ORDER is asserted, not just that both happened", (function()
        local lastTimer, firstJs
        for i, e in ipairs(EVENTS) do
            if e == "timer" then lastTimer = i end
            if e == "js" and not firstJs then firstJs = i end
        end
        return lastTimer ~= nil and firstJs ~= nil and lastTimer < firstJs
    end)(), table.concat(EVENTS, ","))
    -- the page answers
    BRIDGE({ body = { a = "cancel", img = KEEPIMG, notes = NOTES } })
    c14("…the page answers, the work is kept", E.kept ~= nil and E.kept.path == SRC)
    c14("…the window closes", E.webview == nil)
    c14("…and the belt is torn down, not left to fire over the next editor",
        E.closeTimer == nil)
    c14("…counted: one ask, one stash, no belt close",
        E.closes.asked == 1 and E.closes.stashed == 1 and E.closes.belt == 0,
        E.closes.asked .. "/" .. E.closes.stashed .. "/" .. E.closes.belt)

    -- ---- the belt --------------------------------------------------------
    E.kept = nil
    TIMERS = {}
    E.open(SRC)
    E.requestClose("Esc")
    local belt = TIMERS[#TIMERS]
    c14("a page that never answers still gets closed — by the belt",
        belt ~= nil and E.webview ~= nil)
    belt.fn()
    c14("…the window really goes", E.webview == nil)
    c14("…nothing was kept, because nothing was handed back", E.kept == nil)
    c14("🔎 …and it is COUNTED APART: a belt close is the bug to report, and "
        .. "it must not read like a clean one", E.closes.belt == 1)

    -- 🚨 AND close() ITSELF TEARS THE BELT DOWN. The cancel branch cannot
    -- prove this — it calls close() on every path — so the check has to
    -- drive the door that reaches close() with a belt still running: ⌘⏎,
    -- or any direct close. A belt left armed fires over the NEXT editor,
    -- which is 6.266.0's orphan class in a timer.
    E.kept = nil
    TIMERS = {}
    E.open(SRC)
    E.requestClose("Esc")
    c14("a belt is running", E.closeTimer ~= nil)
    E.close()
    c14("🚨 …and a direct close tears it down, so it cannot fire over the "
        .. "NEXT editor", E.closeTimer == nil)

    -- ---- ⇪⇧1 on another shot --------------------------------------------
    -- 🚨 THE DOOR HE IS MOST LIKELY PRESSING. ed.open()'s first line has
    -- always been ed.close(); the slot is keyed by path, so his marks would
    -- have come back — if anything had ever put them in it.
    E.kept = nil
    JS = {}
    E.open(SRC)
    E.open(OTHER)
    c14("🚨 opening ANOTHER shot asks the first one's page for its work "
        .. "before the window goes", JS[#JS] == "stashAndCancel()", JS[#JS])
    c14("…and the new editor really opened", E.webview ~= nil
        and E.currentPath == OTHER, tostring(E.currentPath))

    -- ---- the degrades ----------------------------------------------------
    E.close()
    E.closes = { asked = 0, stashed = 0, belt = 0, atOnce = 0, last = nil }
    NO_TIMER = true
    TIMERS = {}
    JS = {}
    E.open(SRC)
    E.requestClose("Esc")
    c14("🛟 a Mac that cannot arm a timer STILL asks the page…",
        JS[#JS] == "stashAndCancel()")
    c14("🛟 …and still closes, rather than waiting on an answer nothing "
        .. "would end", E.webview == nil)
    NO_TIMER = false
    -- nothing open at all
    local before = E.closes.asked
    E.requestClose("Esc")
    c14("closing when nothing is open asks nobody and throws nothing",
        E.closes.asked == before and E.webview == nil)

    -- ---- the report ------------------------------------------------------
    local rep = E.report and E.report() or nil
    if not rep then
        local printed = {}
        local rp = print
        print = function(...) local t = {}
            for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end
            printed[#printed+1] = table.concat(t, " ") end
        _G.screenshotEditorReport()
        print = rp
        rep = table.concat(printed, "\n")
    end
    c14("🔎 the report names WHICH door and whether the work survived it — "
        .. "'closed' used to be one fact and it was four",
        rep:find("closing :", 1, true) ~= nil, rep)
    c14("…and the last close is named", rep:find("↳ last  :", 1, true) ~= nil)

    -- ---- 🚨 SOURCE: no door may call ed.close() behind the page's back ---
    do
        local fh = assert(io.open(HS .. "/modules/screenshot_editor.lua"))
        local src = fh:read("a"); fh:close()
        local code = {}
        for line in (src .. "\n"):gmatch("([^\n]*)\n") do
            code[#code + 1] = (line:gsub("%-%-.*$", ""))
        end
        code = table.concat(code, "\n")
        -- 🚨 `closeOnEscape` let WebKit close the window itself, racing the
        -- page's own Escape handler — so even the path 6.189.0 built was a
        -- coin toss. Comments stripped (6.262.0), because the comment
        -- explaining the rule quotes the call it forbids.
        c14("🚨 SOURCE: the window no longer closes itself on Escape behind "
            .. "Lua's back", code:find("closeOnEscape") == nil)
        c14("🚨 SOURCE: the Esc router asks before it closes", (function()
            local at = code:find('claimEscape%("shoteditor"')
            if not at then return false end
            local blk = code:sub(at, at + 400)
            return blk:find("requestClose", 1, true) ~= nil
                   and blk:find("function() ed.close() end", 1, true) == nil
        end)())
        c14("🚨 SOURCE: opening another shot asks first too", (function()
            local blk = code:match("function ed%.open%(path%).-ed%.close%(%)")
            return blk ~= nil and blk:find("requestClose", 1, true) ~= nil
        end)())
    end

    c14("§14 ran every one of its checks", (pass + fail) - n14 == 31,
        (pass + fail) - n14)
end

out(("\n%d passed, %d failed\n"):format(pass, fail))
for _, f in ipairs(failures) do out("    ❌ " .. f .. "\n") end
out("\n")
os.exit(fail == 0 and 0 or 1)
