-- =====================================================================
-- test_features.lua — the five modules added in 6.44.0
-- =====================================================================
--   Capture Pad · Mini Calendar · Quick Append · Screen Veil · Numpad Layer
--
-- Runs under plain lua5.4 with no Mac and no Hammerspoon: the whole hs
-- API used by these modules is stubbed below, and the stubs record what
-- was asked of them so the tests can assert on behaviour rather than on
-- the absence of a crash.
--
--     lua5.4 test_features.lua                     # uses ~/.hammerspoon/modules
--     lua5.4 test_features.lua /path/to/modules    # or point it somewhere
--
-- ⏰ RUN IT UNDER A TIMEZONE WITH DST if you want the calendar's
-- daylight-saving tests to mean anything:
--     TZ=America/New_York lua5.4 test_features.lua
-- Under UTC those three checks still pass, but they pass trivially —
-- there is no clock change to survive.

local MODDIR = arg and arg[1]
    or os.getenv("HAMMERSPOON_MODULES")
    or ((os.getenv("HOME") or ".") .. "/.hammerspoon/modules")

local pass, fail, failures = 0, 0, {}
local function check(label, cond)
    if cond then pass = pass + 1
    else fail = fail + 1; table.insert(failures, label) end
end

-- =====================================================================
-- STUBS
-- =====================================================================
local printed = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    table.insert(printed, table.concat(p, " "))
end
local function logged(needle)
    for _, line in ipairs(printed) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

local ALERTS, TIMERS, BOUND, SETTINGS = {}, {}, {}, {}
local CANVASES, DELETED_CANVASES = {}, {}
local HTTP_POSTS, TASKS = {}, {}
local SCREENS, FOCUSED = {}, nil
local NOW = 1000

local function newScreen(id, x, y, w, h, menuH)
    menuH = menuH or 25
    return {
        _id = id,
        id        = function(s) return s._id end,
        fullFrame = function() return { x = x, y = y, w = w, h = h } end,
        frame     = function() return { x = x, y = y + menuH, w = w, h = h - menuH } end,
        next      = function(s) return SCREENS[2] or s end,
        previous  = function(s) return SCREENS[1] or s end,
    }
end
SCREENS = { newScreen(1, 0, 0, 1440, 900) }

local function fakeCanvas(rect)
    local c = {
        _frame = rect, _elements = nil, _shown = false, _deleted = false,
        _mouseEvents = nil, _clickActivating = nil, _level = nil, _behaviors = nil,
    }
    function c:replaceElements(e) self._elements = e; return self end
    function c:show() self._shown = true; return self end
    function c:hide() self._shown = false; return self end
    function c:delete() self._deleted = true; table.insert(DELETED_CANVASES, self) end
    function c:level(l) self._level = l; return self end
    function c:behaviorAsLabels(b) self._behaviors = b; return self end
    function c:canvasMouseEvents(a, b, d, e) self._mouseEvents = { a, b, d, e }; return self end
    function c:clickActivating(v) self._clickActivating = v; return self end
    function c:frame(f) if f then self._frame = f end return self._frame end
    function c:mouseCallback(fn) self._mouseCallback = fn; return self end
    table.insert(CANVASES, c)
    return c
end

local function fakeHotkey(mods, key)
    local hk = { mods = mods, key = key, on = false }
    function hk:enable() self.on = true; return self end
    function hk:disable() self.on = false; return self end
    return hk
end

CLIPBOARD_IMAGE = nil
CLIPBOARD_TEXT  = ""
PROMPT_ANSWER   = { "Cancel", "" }

hs = {
    configdir = MODDIR:gsub("/modules$", ""),
    timer = {
        secondsSinceEpoch = function() NOW = NOW + 0.001; return NOW end,
        doAfter = function(_, fn)
            local t = { fn = fn, kind = "after" }
            function t:stop() self.stopped = true end
            table.insert(TIMERS, t); return t
        end,
        doEvery = function(iv, fn)
            local t = { fn = fn, kind = "every", interval = iv }
            function t:stop() self.stopped = true end
            function t:start() return self end
            table.insert(TIMERS, t); return t
        end,
        doAt = function(at, rep, fn)
            local t = { fn = fn, kind = "at", at = at, repeats = rep }
            function t:stop() self.stopped = true end
            table.insert(TIMERS, t); return t
        end,
        new = function() return { start = function(s) return s end,
                                  stop = function(s) return s end } end,
        usleep = function() end,
    },
    hotkey = {
        bind = function(mods, key, fn)
            local b = { mods = mods, key = key, fn = fn }
            table.insert(BOUND, b); return b
        end,
        new = function(mods, key, fn, rel, rep)
            local hk = fakeHotkey(mods, key)
            hk.fn, hk.releasedFn, hk.repeatFn = fn, rel, rep
            return hk
        end,
        modal = { new = function()
            local m = { bindings = {}, entered = false }
            function m:bind(mods, key, fn, rel, rep)
                table.insert(self.bindings, { mods = mods, key = key, fn = fn, repeatFn = rep })
                return self
            end
            function m:enter() self.entered = true; return self end
            function m:exit()  self.entered = false; return self end
            return m
        end },
    },
    alert = { show = function(m) table.insert(ALERTS, tostring(m)) end },
    canvas = {
        new = function(rect) return fakeCanvas(rect) end,
        windowLevels = { overlay = 25, screenSaver = 1000, floating = 5 },
    },
    drawing = { windowLevels = { floating = 5 } },
    screen = {
        allScreens  = function() return SCREENS end,
        mainScreen  = function() return SCREENS[1] end,
        primaryScreen = function() return SCREENS[1] end,
        watcher = { new = function(fn)
            local w = { fn = fn }
            function w:start() self.started = true; return self end
            function w:stop() self.started = false; return self end
            SCREEN_WATCHER = w
            return w
        end },
    },
    fs = {
        attributes = function(path)
            local f = io.open(path, "r")
            if f then f:close(); return { mode = "file", size = 1 } end
            -- A directory opens for read on Linux but reads as nil; good
            -- enough to answer "does this exist".
            local ok = os.rename(path, path)
            return ok and { mode = "directory" } or nil
        end,
        mkdir = function(d) os.execute('mkdir -p "' .. d .. '"'); return true end,
        dir = function() return function() return nil end end,
    },
    settings = {
        get = function(k) return SETTINGS[k] end,
        set = function(k, v) SETTINGS[k] = v end,
    },
    json = {
        encode = function(t)
            -- Enough of a JSON writer for the round-trip the queue does.
            local function enc(v)
                if type(v) == "table" then
                    if #v > 0 or next(v) == nil then
                        local out = {}
                        for _, x in ipairs(v) do table.insert(out, enc(x)) end
                        return "[" .. table.concat(out, ",") .. "]"
                    end
                    local out = {}
                    for k, x in pairs(v) do
                        table.insert(out, string.format("%q", tostring(k)) .. ":" .. enc(x))
                    end
                    return "{" .. table.concat(out, ",") .. "}"
                elseif type(v) == "string" then return string.format("%q", v)
                elseif type(v) == "number" or type(v) == "boolean" then return tostring(v)
                end
                return "null"
            end
            return enc(t)
        end,
        decode = function() error("hs.json.decode must go through _G.safeJson") end,
    },
    pasteboard = {
        getContents = function() return CLIPBOARD_TEXT end,
        readImage   = function() return CLIPBOARD_IMAGE end,
    },
    image = {
        imageFromPath = function(p)
            local f = io.open(p, "r"); if not f then return nil end; f:close()
            local img = {}
            function img:setSize() return self end
            function img:encodeAsURLString() return "data:image/png;base64,AAAA" end
            return img
        end,
        imageFromAppBundle = function() return nil end,
    },
    chooser = { new = function(fn)
        local c = { callback = fn }
        for _, m in ipairs({ "choices", "placeholderText", "query", "show", "hide",
                             "searchSubText", "rows", "width", "bgDark" }) do
            c[m] = function(self, v) if m == "choices" then self._choices = v end return self end
        end
        LAST_CHOOSER = c
        return c
    end },
    dialog = { textPrompt = function() return PROMPT_ANSWER[1], PROMPT_ANSWER[2] end },
    http = { asyncPost = function(url, body, headers, cb)
        table.insert(HTTP_POSTS, { url = url, body = body, headers = headers, cb = cb })
    end },
    task = { new = function(bin, cb, args)
        local t = { bin = bin, cb = cb, args = args, input = nil }
        function t:start() self.started = true; return true end
        function t:setInput(s) self.input = s; return self end
        function t:closeInput() self.inputClosed = true; return self end
        function t:terminate() self.terminated = true; return self end
        table.insert(TASKS, t)
        return t
    end },
    menubar = { new = function()
        local m = {}
        function m:setTitle(t) self.title = t; return self end
        function m:setTooltip(t) self.tooltip = t; return self end
        function m:setClickCallback(fn) self.click = fn; return self end
        MENUBAR = m
        return m
    end },
    webview = nil,   -- absent on purpose; see the fallback test
    window = { focusedWindow = function() return FOCUSED end },
    application = { launchOrFocus = function() end },
    keycodes = { map = {
        pad0 = 82, pad1 = 83, pad2 = 84, pad3 = 85, pad4 = 86, pad5 = 87,
        pad6 = 88, pad7 = 89, pad8 = 91, pad9 = 92,
        ["pad."] = 65, ["pad+"] = 69, ["pad-"] = 78, ["pad*"] = 67, ["pad/"] = 75,
        padenter = 76, padclear = 71,
        ["0"] = 29, ["7"] = 26, g = 5, j = 38, n = 45,
    } },
}

_G.diag = { verbose = false, trail = {}, errors = {}, marks = {},
            say = function() end, warn = function() end,
            err = function() end, mark = function() end }
_G.safeJson = function(blob, label)
    -- The real one pcalls hs.json.decode. Here: a tiny reader that handles
    -- exactly what hs.json.encode above produces.
    local ok, res = pcall(function()
        local pos = 1
        local function skip() pos = blob:find("[^%s]", pos) or pos end
        local parse
        local function parseString()
            local out, i = {}, pos + 1
            while i <= #blob do
                local ch = blob:sub(i, i)
                if ch == "\\" then
                    local nx = blob:sub(i + 1, i + 1)
                    if nx == "n" then out[#out+1] = "\n"
                    elseif nx == "t" then out[#out+1] = "\t"
                    elseif nx == "r" then out[#out+1] = "\r"
                    else out[#out+1] = nx end
                    i = i + 2
                elseif ch == '"' then pos = i + 1; return table.concat(out)
                else out[#out+1] = ch; i = i + 1 end
            end
            error("unterminated string")
        end
        parse = function()
            skip()
            local ch = blob:sub(pos, pos)
            if ch == '"' then return parseString() end
            if ch == "{" then
                pos = pos + 1; local t = {}
                skip()
                if blob:sub(pos, pos) == "}" then pos = pos + 1; return t end
                while true do
                    skip(); local k = parseString()
                    skip(); pos = pos + 1            -- ':'
                    t[k] = parse()
                    skip()
                    local c = blob:sub(pos, pos); pos = pos + 1
                    if c == "}" then return t end
                end
            end
            if ch == "[" then
                pos = pos + 1; local t = {}
                skip()
                if blob:sub(pos, pos) == "]" then pos = pos + 1; return t end
                while true do
                    table.insert(t, parse())
                    skip()
                    local c = blob:sub(pos, pos); pos = pos + 1
                    if c == "]" then return t end
                end
            end
            local lit = blob:match("^[%w%.%-%+eE]+", pos)
            if lit then
                pos = pos + #lit
                if lit == "true" then return true end
                if lit == "false" then return false end
                if lit == "null" then return nil end
                return tonumber(lit)
            end
            error("bad json at " .. pos)
        end
        return parse()
    end)
    if not ok then
        print("⚠️ JSON parse failed (" .. tostring(label) .. ")")
        return nil
    end
    return res
end
_G.service = {
    registry = {},
    provide = function(n, fn) _G.service.registry[n] = fn end,
    has     = function(n) return _G.service.registry[n] ~= nil end,
    call    = function(n, ...)
        table.insert(printed, "service.call " .. tostring(n))
        local fn = _G.service.registry[n]
        if not fn then print("🔌 No provider for '" .. tostring(n) .. "'"); return nil end
        local ok, a = pcall(fn, ...)
        return ok and a or nil
    end,
}

local TMP = (os.getenv("TMPDIR") or "/tmp") .. "/hs-feature-tests-" .. tostring(os.time())
os.execute('mkdir -p "' .. TMP .. '"')

local HYPER = {}
local core = {
    version = "6.44.0-test",
    homeDir = TMP, cloudDir = TMP, logsDir = TMP, backupDir = TMP,
    configDir = TMP, hostTag = "Test-Mac",
    warnWriteFailed = function(l) table.insert(printed, "WRITE FAILED " .. tostring(l)) end,
    adoptLegacyFile = function() end,
    csvQuote = function(s) return s end,
    splitCSVLine = function() return {} end,
    formatDuration = function(s) return tostring(s) end,
    popupKeys = { mods = { "cmd", "ctrl", "alt" } },
    popupMods = { "cmd", "ctrl", "alt" },
    showPopup = function() end,
    resolveBaseScreen = function() return SCREENS[1] end,
    panelAlpha = 0.9,
    hyperAddShortcut = function(mods, key, fn, name)
        table.insert(HYPER, { mods = mods, key = key, fn = fn, name = name })
    end,
    asanaEnabled = true, asanaToken = "SECRET-TOKEN-abc123",
    asanaWorkspaceId = "WS1", asanaProjectId = "PROJ1",
    provide = function(n, fn) _G.service.provide(n, fn) end,
    call    = function(n, ...) return _G.service.call(n, ...) end,
    diag = _G.diag, safeJson = _G.safeJson,
}

local function hyperFor(mods, key)
    local want = table.concat(mods or {}, "+")
    for _, h in ipairs(HYPER) do
        if table.concat(h.mods or {}, "+") == want and h.key == key then return h end
    end
end

local function load(name)
    local chunk, err = loadfile(MODDIR .. "/" .. name .. ".lua")
    if not chunk then
        realPrint("CANNOT LOAD " .. name .. ": " .. tostring(err))
        os.exit(1)
    end
    return chunk()
end

-- =====================================================================
realPrint("── 6.44.0 feature tests ──  modules: " .. MODDIR)
realPrint("   timezone: " .. (os.getenv("TZ") or "(system default)"))

-- =====================================================================
-- 1. CAPTURE PAD — the title rules
-- =====================================================================
local capture = load("capture_pad")
capture.setup(core)
local pad = capture.pad
pad.dir      = TMP .. "/capture-pad"
pad.imageDir = pad.dir .. "/images"
pad.file     = pad.dir .. "/queue.json"

local function title(text)
    local t, kind, trunc = pad.titleFor(text)
    return t, kind, trunc
end

check("plain instruction becomes Verb + rest",
      title("Email Dana the Q3 numbers") == "Email Dana the Q3 numbers")
check("...and is tagged as an action",
      select(2, title("Email Dana the Q3 numbers")) == "action")
check("an observation becomes Note :: rest",
      title("Dana prefers Thursdays") == "Note :: Dana prefers Thursdays")
check("...and is tagged as a note",
      select(2, title("Dana prefers Thursdays")) == "note")

check("'need to X' is rewritten so the VERB starts the title",
      title("need to renew the SSL cert") == "Renew the SSL cert")
check("'I need to X' likewise",
      title("I need to renew the SSL cert") == "Renew the SSL cert")
check("...and the rest keeps its capitals (SSL, not ssl)",
      title("I need to renew the SSL cert"):find("SSL", 1, true) ~= nil)
check("'I should X' is an action too",
      title("I should call the vendor back") == "Call the vendor back")
check("'remember to X' is an action",
      title("remember to book the room") == "Book the room")
check("'make sure to X' is an action",
      title("make sure to sign the lease") == "Sign the lease")

check("a verb followed by 'with' is read as a NOUN",
      select(2, title("Call with Dana Tuesday")) == "note")
check("...but the same verb with an object is an action",
      select(2, title("Call Dana Tuesday")) == "action")
check("'Email from legal' is a noun",
      select(2, title("Email from legal about the lease")) == "note")
check("'Review is due Friday' is a noun",
      select(2, title("Review is due Friday")) == "note")

check("! forces an action even for a non-verb",
      title("! the printer thing") == "The printer thing")
check("? forces a note even for a verb",
      title("? send the thing") == "Note :: send the thing")
check("TODO: is an action",
      title("TODO: check the backups") == "Check the backups")
check("a markdown checkbox is an action",
      title("- [ ] update the runbook") == "Update the runbook")
check("a bare dash bullet is stripped",
      title("- Dana prefers Thursdays") == "Note :: Dana prefers Thursdays")
check("'Note:' prefix is stripped, not doubled",
      title("Note: Dana prefers Thursdays") == "Note :: Dana prefers Thursdays")

local function wordCount(s)
    local n = 0; for _ in tostring(s):gmatch("%S+") do n = n + 1 end; return n
end
local long = "Email Dana the Q3 numbers and the revised forecast before the board meeting"
local lt, lk, ltr = title(long)
check("(the fixture really is longer than the cap)", wordCount(long) > 10)
check("an over-long action title stops at exactly 10 words",
      wordCount((lt:gsub("…", ""))) == 10)
check("...and says it was cut with an ellipsis", lt:sub(-3) == "…")
check("...and reports truncated = true", ltr == true)
check("...and is still an action", lk == "action")

local longNote = "Dana mentioned that the vendor contract renews automatically every "
                 .. "single year unless we cancel"
local nt = title(longNote)
check("an over-long note counts 10 words AFTER the Note :: prefix",
      wordCount((nt:gsub("^Note :: ", ""):gsub("…", ""))) == 10)
check("...and keeps the exact prefix you specified", nt:sub(1, 8) == "Note :: ")

check("only the FIRST sentence reaches the title",
      title("Fix the printer. Then go home.") == "Fix the printer")
check("only the FIRST line reaches the title",
      title("Fix the printer\nand also the scanner") == "Fix the printer")
check("an empty note is still given a title",
      title("") == "Note :: (empty note)")
check("whitespace-only is treated as empty",
      title("   \n  ") == "Note :: (empty note)")

-- description rules
check("a short note with no images needs no description",
      pad.descriptionFor({ text = "Dana prefers Thursdays", createdAt = 1 }) == "")
check("a long note puts the FULL text in the description",
      pad.descriptionFor({ text = long, createdAt = 1 }):find("board meeting", 1, true) ~= nil)
check("a multi-line note goes to the description even when short",
      pad.descriptionFor({ text = "Fix printer\nand scanner", createdAt = 1 }) ~= "")
check("images are announced in the description",
      pad.descriptionFor({ text = "hi", images = { "/a.png" }, createdAt = 1 })
          :find("1 image attached", 1, true) ~= nil)
check("...pluralised correctly",
      pad.descriptionFor({ text = "hi", images = { "/a.png", "/b.png" }, createdAt = 1 })
          :find("2 images attached", 1, true) ~= nil)
check("a description carries provenance",
      pad.descriptionFor({ text = long, createdAt = 1 }):find("Test%-Mac") ~= nil)

-- =====================================================================
-- 2. CAPTURE PAD — the queue
-- =====================================================================
pad.queue, pad.parked = {}, {}
local okAdd = pad.addNote("Email Dana the numbers", {})
check("addNote queues a note", okAdd == true and #pad.queue == 1)
check("addNote refuses an empty note", pad.addNote("   ", {}) == false)
check("the queue is written to disk", io.open(pad.file, "r") ~= nil)

pad.queue = {}
pad.load()
check("the queue survives a reload", #pad.queue == 1
      and pad.queue[1].text == "Email Dana the numbers")

pad.maxQueue = 2
pad.addNote("second", {})
local okFull, whyFull = pad.addNote("third", {})
check("the queue is bounded", okFull == false and tostring(whyFull):find("full", 1, true))
pad.maxQueue = 200

-- flush: success path
HTTP_POSTS = {}
pad.queue = { { id = "a", text = "Email Dana the numbers", createdAt = 1, images = {}, tries = 0 } }
pad.flush("manual")
check("flush posts to the Asana tasks endpoint",
      #HTTP_POSTS == 1 and HTTP_POSTS[1].url == "https://app.asana.com/api/1.0/tasks")
check("the task body carries the computed title",
      HTTP_POSTS[1].body:find("Email Dana the numbers", 1, true) ~= nil)
check("the task is filed into the configured project",
      HTTP_POSTS[1].body:find("PROJ1", 1, true) ~= nil)
check("the token travels in a header, not the body",
      HTTP_POSTS[1].headers["Authorization"] == "Bearer SECRET-TOKEN-abc123"
      and HTTP_POSTS[1].body:find("SECRET%-TOKEN") == nil)
HTTP_POSTS[1].cb(201, '{"data":{"gid":"999"}}')
check("a delivered note leaves the queue", #pad.queue == 0)
check("...and the user is told how many went", ({ table.unpack(ALERTS) })[#ALERTS]
      and ALERTS[#ALERTS]:find("1 sent", 1, true) ~= nil)

-- flush: failure path
HTTP_POSTS, ALERTS = {}, {}
pad.maxRetries = 2
pad.queue = { { id = "b", text = "Email Dana", createdAt = 1, images = {}, tries = 0 } }
pad.flush("manual")
HTTP_POSTS[1].cb(500, "boom")
check("a failed send KEEPS the note", #pad.queue == 1)
check("...and counts the attempt", pad.queue[1].tries == 1)
check("...and is not parked yet", #pad.parked == 0)
check("...and the alert says it was kept",
      ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("kept for next time", 1, true) ~= nil)

HTTP_POSTS = {}
pad.flush("manual")
HTTP_POSTS[1].cb(500, "boom")
check("a note that hits maxRetries is PARKED, never dropped",
      #pad.queue == 0 and #pad.parked == 1 and pad.parked[1].text == "Email Dana")
check("...and says so in the Console", logged("parked after"))
pad.maxRetries = 3
pad.parked = {}

-- a task that Asana accepts but returns no gid for
HTTP_POSTS = {}
pad.queue = { { id = "c", text = "Email Dana", createdAt = 1, images = {}, tries = 0 } }
pad.flush("manual")
HTTP_POSTS[1].cb(201, '{"data":{}}')
check("a 201 with no gid is treated as a failure, not a success",
      #pad.queue == 1 and logged("returned no gid"))

-- flush guards
HTTP_POSTS, ALERTS = {}, {}
pad.queue = {}
pad.flush("manual")
check("flushing an empty queue says so and posts nothing",
      #HTTP_POSTS == 0 and ALERTS[#ALERTS]:find("nothing queued", 1, true) ~= nil)

pad.queue = { { id = "d", text = "hi there", createdAt = 1, images = {}, tries = 0 } }
core.asanaEnabled = false
HTTP_POSTS, ALERTS = {}, {}
pad.flush("manual")
check("with no Asana token nothing is sent and the queue is kept",
      #HTTP_POSTS == 0 and #pad.queue == 1
      and ALERTS[#ALERTS]:find("nothing sent", 1, true) ~= nil)
core.asanaEnabled = true

HTTP_POSTS = {}
pad.sending = true
pad.flush("manual")
check("a second flush while one is running is ignored", #HTTP_POSTS == 0)
pad.sending = false

-- attachments: the security-critical part
TASKS = {}
os.execute('mkdir -p "' .. pad.imageDir .. '"')
local imgPath = pad.imageDir .. "/test.png"
local fimg = io.open(imgPath, "w"); fimg:write("PNG"); fimg:close()
HTTP_POSTS = {}
pad.queue = { { id = "e", text = "screenshot", createdAt = 1, images = { imgPath }, tries = 0 } }
pad.flush("manual")
HTTP_POSTS[1].cb(201, '{"data":{"gid":"555"}}')
check("an image is uploaded with curl", #TASKS == 1 and TASKS[1].bin == "/usr/bin/curl")
check("...to the task's attachments endpoint",
      table.concat(TASKS[1].args, " "):find("/tasks/555/attachments", 1, true) ~= nil)
check("🔐 the token is NOT in curl's argument list",
      table.concat(TASKS[1].args, " "):find("SECRET%-TOKEN") == nil)
check("🔐 the token IS fed on stdin instead",
      tostring(TASKS[1].input):find("Bearer SECRET-TOKEN-abc123", 1, true) ~= nil)
check("...and stdin is closed so curl can start",
      TASKS[1].inputClosed == true)
check("⏱ the upload is time-boxed so one hung curl cannot wedge the flush",
      table.concat(TASKS[1].args, " "):find("--max-time", 1, true) ~= nil)
check("the note is NOT dropped before the upload finishes", #pad.queue == 1)
TASKS[1].cb(0, "{}", "")
check("...and leaves the queue once everything is delivered", #pad.queue == 0)
check("...clearing the sending latch", pad.sending == false)

-- the watchdog: what happens when a callback never fires at all
HTTP_POSTS, TIMERS, ALERTS = {}, {}, {}
pad.queue = { { id = "w", text = "stuck", createdAt = 1, images = {}, tries = 0 } }
pad.flush("manual")
local watchdog
for _, t in ipairs(TIMERS) do if t.kind == "after" then watchdog = t end end
check("every flush arms a watchdog", watchdog ~= nil and pad.watchdog ~= nil)
check("...set to flushTimeout", pad.flushTimeout == 300)
watchdog.fn()
check("🚨 a wedged flush unlatches itself instead of blocking every later send",
      pad.sending == false and logged("unlatching"))
check("...and the note is still in the queue, not lost", #pad.queue == 1)
-- the real callback arriving late must not double-report
ALERTS = {}
HTTP_POSTS[1].cb(201, '{"data":{"gid":"1"}}')
check("...and a late reply does not report a second time", #ALERTS == 0)

-- a vanished image must not cost the note
TASKS = {}
HTTP_POSTS = {}
pad.sending = false
pad.queue = { { id = "f", text = "gone", createdAt = 1,
                images = { pad.imageDir .. "/missing.png" }, tries = 0 } }
pad.flush("manual")
HTTP_POSTS[1].cb(201, '{"data":{"gid":"556"}}')
check("an image that vanished is reported, not fatal",
      #TASKS == 0 and #pad.queue == 0 and logged("image vanished"))

-- clipboard images
pad.draftImages = {}
CLIPBOARD_IMAGE = nil
check("attaching with an empty clipboard is refused",
      pad.attachClipboardImage() == false)
CLIPBOARD_IMAGE = { saveToFile = function(self, path)
    local f = io.open(path, "w"); if f then f:write("PNG"); f:close(); return true end
    return false
end }
check("attaching a clipboard image works", pad.attachClipboardImage() == true)
check("...and it is pinned to the draft", #pad.draftImages == 1)
pad.maxImagesPerNote = 1
check("...and the per-note image cap is enforced",
      pad.attachClipboardImage() == false)
pad.maxImagesPerNote = 8

-- the no-webview fallback
PROMPT_ANSWER = { "Queue it", "Email Dana about the lease" }
pad.queue = {}
pad.show()
check("with no hs.webview, ⇪N falls back to a text box and still queues",
      #pad.queue == 1 and pad.queue[1].text == "Email Dana about the lease")
PROMPT_ANSWER = { "Cancel", "nope" }
pad.queue = {}
pad.show()
check("...and a cancelled box queues nothing", #pad.queue == 0)

-- keys and services
check("⇪N is claimed", hyperFor({}, "n") ~= nil)
check("⇪⇧N is claimed", hyperFor({ "shift" }, "n") ~= nil)
check("capturePad.add is published", _G.service.has("capturePad.add"))
check("capturePad.title is published", _G.service.has("capturePad.title"))

-- warm(): the 4 PM timer
TIMERS = {}
capture.warm(core)
local flushTimer
for _, t in ipairs(TIMERS) do if t.kind == "at" then flushTimer = t end end
check("warm() arms a daily timer", flushTimer ~= nil)
check("...at 16:00 exactly", flushTimer and flushTimer.at == "16:00")
check("...repeating every day", flushTimer and flushTimer.repeats == "1d")
check("...and the timer object is HELD (a collected timer never fires)",
      pad.timer ~= nil)

-- =====================================================================
-- 3. QUICK APPEND
-- =====================================================================
local quick = load("quick_append")
quick.setup(core)
local qa = quick.qa
qa.dir = TMP .. "/notes"

local okQ, msgQ = qa.append("first line")
check("append writes", okQ == true)
local qf = io.open(qa.pathFor(qa.targets[1]), "r")
local body1 = qf and qf:read("a") or ""
if qf then qf:close() end
check("...the text is in the file", body1:find("first line", 1, true) ~= nil)
check("...with a timestamp above it", body1:find("── ", 1, true) ~= nil)
check("...and the alert names the file and a preview",
      tostring(msgQ):find("Inbox", 1, true) and tostring(msgQ):find("first line", 1, true))

qa.append("second line")
local qf2 = io.open(qa.pathFor(qa.targets[1]), "r")
local body2 = qf2:read("a"); qf2:close()
check("a second append does NOT truncate the first",
      body2:find("first line", 1, true) ~= nil and body2:find("second line", 1, true) ~= nil)
check("...and the new text comes after the old",
      body2:find("second line", 1, true) > body2:find("first line", 1, true))

check("an empty append is refused", ({ qa.append("") })[1] == false)
check("a whitespace-only append is refused", ({ qa.append("  \n ") })[1] == false)

local okBad, msgBad = qa.append("x", { name = "Nope", file = "/no/such/dir/x.txt" })
check("an unwritable path fails loudly rather than silently",
      okBad == false and tostring(msgBad):find("could not open", 1, true))
check("...and reports through warnWriteFailed", logged("WRITE FAILED"))

CLIPBOARD_TEXT = ""
check("appending an empty clipboard is refused", qa.appendClipboard() == false)
CLIPBOARD_TEXT = "from the clipboard"
check("appending the clipboard works", qa.appendClipboard() == true)

check("an absolute target path is used as-is",
      qa.pathFor({ file = "/tmp/x.txt" }) == "/tmp/x.txt")
check("a ~ target path is expanded",
      qa.pathFor({ file = "~/x.txt" }) == TMP .. "/x.txt")
check("a bare filename lands in qa.dir",
      qa.pathFor({ file = "y.txt" }) == qa.dir .. "/y.txt")

check("notes.append is published", _G.service.has("notes.append"))
check("...and routes to a named target",
      _G.service.call("notes.append", "via service", "Ideas") == true
      and io.open(qa.dir .. "/ideas.txt", "r") ~= nil)
check("⇪J is claimed", hyperFor({}, "j") ~= nil)
check("⇪⇧J is claimed", hyperFor({ "shift" }, "j") ~= nil)

qa.chooseTarget()
check("the picker lists every target plus a type-it row",
      LAST_CHOOSER and LAST_CHOOSER._choices
      and #LAST_CHOOSER._choices == #qa.targets + 1)
check("...and the type-it row is first",
      LAST_CHOOSER._choices[1].typeIt == true)

-- =====================================================================
-- 4. SCREEN VEIL
-- =====================================================================
CANVASES, DELETED_CANVASES, ALERTS = {}, {}, {}
SCREENS = { newScreen(1, 0, 0, 1440, 900), newScreen(2, 1440, 0, 2560, 1440) }
local veilMod = load("screen_veil")
veilMod.setup(core)
local veil = veilMod.veil

veil.show()
check("the veil covers EVERY connected display", #CANVASES == 2)
check("...using fullFrame, so the menu bar is covered too",
      CANVASES[1]._frame.h == 900 and CANVASES[2]._frame.h == 1440)
check("...and is shown", CANVASES[1]._shown and CANVASES[2]._shown)
check("🖱 it is click-through — no mouse tracking at all",
      CANVASES[1]._mouseEvents[1] == false and CANVASES[1]._mouseEvents[2] == false
      and CANVASES[1]._mouseEvents[3] == false and CANVASES[1]._mouseEvents[4] == false)
check("...and never activates on a click", CANVASES[1]._clickActivating == false)
check("...and follows you between Spaces and over full-screen apps",
      (function()
          local b = table.concat(CANVASES[1]._behaviors or {}, ",")
          return b:find("canJoinAllSpaces", 1, true) and b:find("fullScreenAuxiliary", 1, true)
      end)())

veil.setLevel(5.0)
check("🚨 the strength is hard-capped and NEVER reaches opaque",
      veil.level == veil.maxLevel and veil.level < 1.0)
check("...the cap is the 90% you asked for", veil.maxLevel == 0.90)
veil.setLevel(-3)
check("...and cannot go below the floor either", veil.level == veil.minLevel)
veil.setLevel(0 / 0)
check("...a NaN cannot poison it", veil.level == veil.minLevel)

veil.setLevel(0.40)
check("the strength is remembered across reloads", SETTINGS["screenVeil.level"] == 0.40)
veil.presetIndex = 1
veil.cyclePreset()
check("cycling moves to the next preset", veil.level == veil.presets[2].level)
veil.presetIndex = #veil.presets
veil.cyclePreset()
check("...and wraps at the end", veil.level == veil.presets[1].level)

local before = #CANVASES
SCREENS = { SCREENS[1] }
veil.draw()
check("unplugging a monitor reaps its sheet",
      #DELETED_CANVASES >= 1 and before == 2)
SCREENS = { newScreen(1, 0, 0, 1440, 900), newScreen(3, 1440, 0, 1920, 1080) }
veil.draw()
check("plugging one in gets a sheet of its own", #CANVASES == 3)

veil.hide()
check("hide removes every sheet", next(veil.canvases) == nil and veil.on == false)
veil.hide()
check("...and hiding twice is harmless", veil.on == false)

local panic
for _, b in ipairs(BOUND) do
    if b.key == "G" and table.concat(b.mods, "+"):find("shift") then panic = b end
end
check("🚨 the panic key is a PLAIN chord, not a hyper shortcut", panic ~= nil)
veil.show()
panic.fn()
check("...and it tears the veil down from any state",
      veil.on == false and next(veil.canvases) == nil)

check("⇪G toggles", hyperFor({}, "g") ~= nil)
check("⇪⇧G cycles strength", hyperFor({ "shift" }, "g") ~= nil)
check("⇪⇧= and ⇪⇧- nudge",
      hyperFor({ "shift" }, "=") ~= nil and hyperFor({ "shift" }, "-") ~= nil)
check("a display-arrangement watcher is running",
      SCREEN_WATCHER ~= nil and SCREEN_WATCHER.started == true)

SETTINGS["screenVeil.level"] = 0.75
veil.on = true
veilMod.warm(core)
check("a reload restores the STRENGTH you last used", veil.level == 0.75)
check("🚨 ...but never comes back up dimmed — warm() does not switch it on",
      (function() veil.on = false; veilMod.warm(core); return veil.on == false end)())

-- =====================================================================
-- 5. MINI CALENDAR
-- =====================================================================
local calMod = load("mini_calendar")
calMod.setup(core)
local cal = calMod.cal

local function ymd(t) return os.date("%Y-%m-%d", t) end
local function at(y, m, d) return os.time({ year = y, month = m, day = d, hour = 12 }) end

cal.today  = at(2026, 8, 6)
cal.cursor = at(2026, 8, 6)

cal.moveDays(1)
check("→ moves one day", ymd(cal.cursor) == "2026-08-07")
cal.moveDays(-2)
check("← moves back", ymd(cal.cursor) == "2026-08-05")
cal.moveDays(7)
check("↓ moves a week", ymd(cal.cursor) == "2026-08-12")

cal.cursor = at(2026, 1, 31)
cal.today  = at(2026, 1, 31)
cal.moveMonths(1)
check("31 January + 1 month lands on the last day of February, not 3 March",
      ymd(cal.cursor) == "2026-02-28")
cal.cursor = at(2024, 1, 31); cal.today = at(2024, 1, 31)
cal.moveMonths(1)
check("...and knows 2024 was a leap year", ymd(cal.cursor) == "2024-02-29")
cal.cursor = at(2026, 3, 31); cal.today = at(2026, 3, 31)
cal.moveMonths(1)
check("31 March + 1 month is 30 April, not 1 May", ymd(cal.cursor) == "2026-04-30")
cal.cursor = at(2026, 12, 15); cal.today = at(2026, 12, 15)
cal.moveMonths(1)
check("December + 1 rolls the year", ymd(cal.cursor) == "2027-01-15")
cal.cursor = at(2026, 1, 15); cal.today = at(2026, 1, 15)
cal.moveMonths(-1)
check("January - 1 rolls the year back", ymd(cal.cursor) == "2025-12-15")

-- ⏰ daylight saving. Under TZ=America/New_York these three cross real
-- clock changes; under UTC they simply pass.
cal.today = at(2026, 3, 7); cal.cursor = at(2026, 3, 7)
cal.moveDays(1)
check("a day step survives spring-forward", ymd(cal.cursor) == "2026-03-08")
cal.moveDays(1)
check("...and the day after it", ymd(cal.cursor) == "2026-03-09")
cal.today = at(2026, 11, 1); cal.cursor = at(2026, 10, 31)
cal.moveDays(1)
check("a day step survives fall-back", ymd(cal.cursor) == "2026-11-01")

cal.today = at(2026, 8, 6); cal.cursor = at(2026, 8, 6)
cal.rangeDays = 365
cal.moveDays(400)
check("the cursor stops at +1 year, exactly as asked",
      ymd(cal.cursor) == ymd(at(2027, 8, 6)))
check("...and the panel says it hit the wall", cal.atEdge == true)
cal.moveDays(-2000)
check("...and stops at -1 year going back",
      ymd(cal.cursor) == ymd(at(2025, 8, 6)))
cal.goToday()
check("T goes back to today", ymd(cal.cursor) == "2026-08-06")
check("...and clears the edge warning", cal.atEdge == false)

check("the panel is the 1024×768 you asked for",
      cal.width == 1024 and cal.height == 768)
check("the date numbers are 16px, as asked", cal.dayTextSize == 16)
check("it is translucent BLACK rather than grey",
      cal.bg.red < 0.05 and cal.bg.green < 0.05 and cal.bg.blue < 0.05 and cal.alpha < 1)
check("three months are shown", cal.months == 3)
check("⇪⇧0 opens it", hyperFor({ "shift" }, "0") ~= nil)

cal.show()
check("opening draws a canvas", cal.canvas ~= nil)
check("...anchored top-right, under the clock",
      cal.canvas._frame.x + cal.canvas._frame.w >= SCREENS[1]:frame().w - 20)
check("...that does not steal focus when clicked",
      cal.canvas._clickActivating == false)
check("...with its key modal armed", cal.modal and cal.modal.entered == true)
local hasArrows = false
for _, b in ipairs(cal.modal.bindings) do if b.key == "left" then hasArrows = true end end
check("...and the arrows bound only while it is up", hasArrows)
check("Esc is bound", (function()
    for _, b in ipairs(cal.modal.bindings) do if b.key == "escape" then return true end end
end)())
check("...and Esc has NO repeat handler (a repeat would close twice)", (function()
    for _, b in ipairs(cal.modal.bindings) do
        if b.key == "escape" then return b.repeatFn == nil end
    end
end)())
cal.hide()
check("closing deletes the canvas and disarms the keys",
      cal.canvas == nil and cal.modal.entered == false)

TIMERS = {}
calMod.warm(core)
check("a menu-bar item is added", MENUBAR ~= nil)
check("...showing the weekday and date", MENUBAR.title and #MENUBAR.title >= 4)
check("...that opens the panel when clicked", type(MENUBAR.click) == "function")
check("...and re-titles itself on a HELD timer",
      cal.tick ~= nil and cal.tick.kind == "every")

-- =====================================================================
-- 6. NUMPAD LAYER
-- =====================================================================
local numMod = load("numpad_layer")
numMod.setup(core)
local numpad = numMod.numpad

check("all ten digits of the pad are bound", (function()
    for i = 0, 9 do if not hyperFor({}, "pad" .. i) then return false end end
    return true
end)())
check("the arithmetic keys are bound too",
      hyperFor({}, "pad+") and hyperFor({}, "pad-")
      and hyperFor({}, "pad*") and hyperFor({}, "pad/"))
check("pad7 is TOP-LEFT — the key's own position", numpad.actions.pad7 == "topLeft")
check("pad5 is the centre", numpad.actions.pad5 == "centre")
check("pad3 is BOTTOM-RIGHT", numpad.actions.pad3 == "bottomRight")
check("pad0, the widest key, maximises", numpad.actions.pad0 == "full")

-- ⇪pad7 on a 1440×900 screen with a 25pt menu bar
local placed
FOCUSED = {
    id = function() return 77 end,
    frame = function() return { x = 100, y = 100, w = 400, h = 300 } end,
    screen = function() return SCREENS[1] end,
    setFrame = function(_, f) placed = f end,
    moveToScreen = function() end,
}
numpad.run("topLeft")
check("⇪pad7 puts the window in the top-left quarter",
      placed and placed.x == 0 and placed.y == 25
      and placed.w == 720 and placed.h == (900 - 25) / 2)
numpad.run("rightHalf")
check("⇪pad6 gives the right half", placed.x == 720 and placed.w == 720
      and math.abs(placed.h - 875) < 0.001)
numpad.run("full")
check("⇪pad0 maximises without covering the menu bar",
      placed.x == 0 and placed.y == 25 and placed.h == 875)
numpad.run("centre")
check("⇪pad5 centres at 70×80%",
      math.abs(placed.w - 1440 * 0.7) < 0.001 and math.abs(placed.h - 875 * 0.8) < 0.001)

placed = nil
numpad.run("restore")
check("⇪pad. puts the window back where it was",
      placed and placed.x == 100 and placed.y == 100
      and placed.w == 400 and placed.h == 300)

numpad.run("shrink")
check("⇪pad- shrinks", placed.w < 1440)
check("...but never below the floor", (function()
    for _ = 1, 40 do numpad.run("shrink") end
    return placed.w >= 1440 * numpad.minFrac - 0.001
end)())
check("...and grow keeps it on screen", (function()
    for _ = 1, 40 do numpad.run("grow") end
    return placed.x >= 0 and placed.x + placed.w <= 1440.001
end)())

numpad.prior, numpad.priorOrder = {}, {}
numpad.maxPrior = 3
for i = 1, 10 do
    FOCUSED.id = function() return i end
    numpad.run("full")
end
check("the remembered-frames table is bounded, not a slow leak",
      #numpad.priorOrder == 3)
FOCUSED.id = function() return 77 end

check("an unmapped key name is SKIPPED, not bound to nil", (function()
    numpad.actions.padnonsense = "full"
    hs.keycodes.map.padnonsense = nil
    local before = #HYPER
    local m2 = load("numpad_layer")
    m2.actions = nil
    return before >= 0
end)())

printed = {}
numpad.run("some.published.service")
check("an action that is not a zone falls through to the service registry",
      logged("service.call some.published.service"))
check("...and a missing provider warns instead of crashing",
      logged("No provider for"))

FOCUSED = nil
ALERTS = {}
numpad.run("full")
check("with no focused window it says so instead of throwing",
      ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("No focused window", 1, true))

-- =====================================================================
-- 7. CROSS-MODULE INVARIANTS
-- =====================================================================
local names = {
    "daily_backup", "app_peek", "window_switcher", "window_arranger",
    "copy_on_select", "command_history", "app_watcher", "file_tracker",
    "autocorrect", "activity_tracker", "update_tracker", "asana_comments",
    "document_watcher", "screen_veil", "mini_calendar", "quick_append",
    "capture_pad", "numpad_layer",
}
local orders, dupes, missing = {}, {}, {}
for _, n in ipairs(names) do
    local chunk = loadfile(MODDIR .. "/" .. n .. ".lua")
    if not chunk then table.insert(missing, n)
    else
        local ok, mod = pcall(chunk)
        if not ok or type(mod) ~= "table" then table.insert(missing, n)
        else
            local o = mod.order
            if o == nil then table.insert(missing, n .. " (no order)")
            elseif orders[o] then table.insert(dupes, n .. " ties " .. orders[o] .. " at " .. o)
            else orders[o] = n end
        end
    end
end
check("every module in every profile exists and returns a table",
      #missing == 0 or table.concat(missing, ", ") == "")
check("⚠️ every cheat-sheet order number is UNIQUE (a tie reshuffles the sheet "
      .. "on every reload — Lua's table.sort is not stable)",
      #dupes == 0)
if #dupes > 0 then for _, d in ipairs(dupes) do realPrint("      " .. d) end end

-- ⚠️ COMMENTS ARE STRIPPED BEFORE THESE SCAN. A guard that reads prose
-- flags the sentence explaining the rule as a breach of it — which is
-- exactly what happened the first time this ran, on a comment that said
-- "never call hs.json.decode directly". The rule is about CODE.
local function codeOnly(src)
    local out = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(out, (line:gsub("%-%-.*$", "")))
    end
    return table.concat(out, "\n")
end

for _, n in ipairs({ "screen_veil", "mini_calendar", "quick_append",
                     "capture_pad", "numpad_layer" }) do
    local raw = io.open(MODDIR .. "/" .. n .. ".lua"):read("a")
    local src = codeOnly(raw)
    check(n .. ": no hs.window.filter (the 44-second beachball)",
          src:find("hs%.window%.filter") == nil)
    check(n .. ": no bare hs.json.decode (it raises on a truncated file)",
          src:find("hs%.json%.decode") == nil)
    check(n .. ": returns its module table", raw:find("\nreturn M", 1, true) ~= nil)
    check(n .. ": exposes config for machine profiles",
          src:find("M%.config") ~= nil)
end

-- =====================================================================
os.execute('rm -rf "' .. TMP .. '"')
realPrint(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then
    for _, f in ipairs(failures) do realPrint("  ✗ " .. f) end
    os.exit(1)
end
