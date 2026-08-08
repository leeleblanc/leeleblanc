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
MOUSE           = { x = 0, y = 0 }
MOUSE_DOWN      = false

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
        setContents = function(s) CLIPBOARD_TEXT = s; return true end,
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
                             "searchSubText", "rows", "width", "bgDark",
                             "selectedRow", "refreshChoicesCallback" }) do
            c[m] = function(self, v) if m == "choices" then self._choices = v end return self end
        end
        -- Captured, not swallowed: the search tests drive the picker
        -- through this exactly as typing a character would.
        c.queryChangedCallback = function(self, fn) self._onQuery = fn; return self end
        LAST_CHOOSER = c
        return c
    end },
    dialog = { textPrompt = function() return PROMPT_ANSWER[1], PROMPT_ANSWER[2] end },
    http = { asyncPost = function(url, body, headers, cb)
        table.insert(HTTP_POSTS, { url = url, body = body, headers = headers, cb = cb })
    end },
    task = { new = function(bin, cb, args)
        -- callOrder records method names in the sequence they were called,
        -- so a test can assert setInput happened BEFORE start — the exact
        -- ordering bug that made every 6.44.0 attachment silently fail.
        local t = { bin = bin, cb = cb, args = args, input = nil, callOrder = {} }
        function t:start() self.started = true
            table.insert(self.callOrder, "start"); return true end
        function t:setInput(s) self.input = s
            table.insert(self.callOrder, "setInput"); return self end
        function t:closeInput() self.inputClosed = true
            table.insert(self.callOrder, "closeInput"); return self end
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
    mouse = { absolutePosition = function() return MOUSE end },
    pathwatcher = { new = function()
        return { start = function(s) return s end, stop = function(s) return s end }
    end },
    axuielement = { applicationElement = function() return nil end,
                    observer = { new = function() return nil end } },
    uielement   = { watcher = { new = function() return nil end } },
    caffeinate  = { watcher = { new = function()
        return { start = function(s) return s end, stop = function(s) return s end }
    end, screensDidLock = 1, screensDidUnlock = 2,
         systemDidWake = 3, systemWillSleep = 4 } },
    eventtap = { checkMouseButtons = function() return { left = MOUSE_DOWN } end },
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
_G.choosers = {}   -- created in §1 of the real init.lua
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
-- 🐛 6.44.2 — a SHORT note with an image used to lose its own text: the
-- description held nothing but "1 image attached." and a timestamp, so a
-- screenshot arrived in Asana with no caption at all.
check("🐛 a short note WITH an image still carries its own text",
      pad.descriptionFor({ text = "Do total damage", images = { "/a.png" }, createdAt = 1 })
          :find("Do total damage", 1, true) ~= nil)
check("...and a short note with NO image still needs no description at all",
      pad.descriptionFor({ text = "Do total damage", images = {}, createdAt = 1 }) == "")
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

-- attachments: the security-critical part, AND the 6.44.0 regression
-- (every attachment silently failed — see the file header for the two
-- bugs: setInput() called after start(), and a diagnostic message that
-- hid the real response body behind Lua's "" truthiness).
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

-- 🐛 6.44.2 — the header moved OFF stdin and into a short-lived file.
-- Ordering setInput() before start() (the 6.44.1 fix) stopped attachments
-- failing every time but not reliably: a pipe written against curl's own
-- already-running read loop can still be raced. A file is written and
-- closed before curl exists, so there is nothing left to race.
local hdrArg
for i, v in ipairs(TASKS[1].args) do
    if v == "-H" then hdrArg = TASKS[1].args[i + 1] end
end
check("the header is passed as -H @<file>", hdrArg ~= nil and hdrArg:sub(1, 1) == "@")
local hdrFile = hdrArg and hdrArg:sub(2)
check("...and that file exists on disk BEFORE curl is started",
      hdrFile ~= nil and io.open(hdrFile, "r") ~= nil)
check("🔐 ...containing exactly the auth header, nothing else", (function()
    local f = io.open(hdrFile, "r"); if not f then return false end
    local c = f:read("a"); f:close()
    return c == "Authorization: Bearer SECRET-TOKEN-abc123\n"
end)())
check("...and it is written before start(), not after", (function()
    -- the file existing at all by this point proves it, since the module
    -- writes it before hs.task.new and we are inspecting post-start
    return TASKS[1].started == true
end)())
check("stdin is no longer used for the token at all", TASKS[1].input == nil)
check("⏱ the upload is time-boxed so one hung curl cannot wedge the flush",
      table.concat(TASKS[1].args, " "):find("--max-time", 1, true) ~= nil)
check("the real HTTP status is requested via -w, not guessed from the body",
      table.concat(TASKS[1].args, " "):find("%%{http_code}", 1, false) ~= nil
      or table.concat(TASKS[1].args, " "):find("http_code", 1, true) ~= nil)
check("the note is NOT dropped before the upload finishes", #pad.queue == 1)
TASKS[1].cb(0, '{"data":{"id":"1"}}\n201', "")
check("...and leaves the queue once everything is delivered", #pad.queue == 0)
check("...clearing the sending latch", pad.sending == false)
check("🔐 the header file is DELETED as soon as curl reports back — a file "
      .. "holding a bearer token must not outlive the upload that needed it",
      io.open(hdrFile, "r") == nil)

-- 🐛 THE EXACT 6.44.0 BUG, REPRODUCED: curl exits 0 (it only fails on a
-- TRANSPORT error, never an HTTP one) while Asana's response is a 401.
-- The old body-sniffing check ("does it contain the word errors") missed
-- this whenever the failure body didn't happen to say that; the new
-- status-based check cannot miss it, because 401 is never 200 or 201.
TASKS, HTTP_POSTS, ALERTS, printed = {}, {}, {}, {}
pad.queue = { { id = "g", text = "screenshot 2", createdAt = 1, images = { imgPath }, tries = 0 } }
pad.flush("manual")
HTTP_POSTS[1].cb(201, '{"data":{"gid":"777"}}')
TASKS[1].cb(0, '{"errors":[{"message":"Not Authorized"}]}\n401', "")
check("a curl exit-0/HTTP-401 response is still treated as a FAILED attachment",
      logged("attachment failed") and logged("HTTP 401"))
check("...and the actual response body reaches the Console, not a blank line",
      logged("Not Authorized"))
check("...but the note itself still counts as sent — the TASK was created",
      #pad.queue == 0)
check("...and the flush summary says the image did not attach, not just \"1 sent\"",
      ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("did not attach", 1, true) ~= nil)
check("...naming the task's gid so it can be found and fixed by hand",
      logged("gid 777"))

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

-- the REAL webview path — the one the user actually hits, and the one
-- neither the font bug nor the "image stays pinned" bug could be caught
-- on without exercising it. hs.webview is set here and cleared again
-- right after, so the no-webview fallback test below still runs under
-- the conditions it expects.
hs.webview = {
    usercontent = { new = function(name)
        local uc = { name = name }
        function uc:setCallback(fn) self.callback = fn; return self end
        return uc
    end },
    new = function(rect, opts, uc)
        local w = { rect = rect, opts = opts, uc = uc, htmlText = nil, shown = false,
                    frameRect = { x = rect.x, y = rect.y, w = rect.w, h = rect.h } }
        function w:frame(f)
            if f then self.frameRect = f; return self end
            return self.frameRect
        end
        function w:html(h) self.htmlText = h; return self end
        function w:windowTitle(t) self.title = t; return self end
        function w:windowStyle(s) self.style = s; return self end
        function w:allowTextEntry(b) self.textEntry = b; return self end
        function w:closeOnEscape(b) self.closeOnEsc = b; return self end
        function w:level(l) self.lvl = l; return self end
        function w:show() self.shown = true; return self end
        function w:bringToFront(b) self.front = b; return self end
        function w:delete() self.deleted = true; return self end
        return w
    end,
}
pad.queue, pad.draftImages, pad.draft = {}, {}, ""
pad.show()
check("pad.show() takes the real webview path when hs.webview exists",
      pad.webview ~= nil and pad.webview.htmlText ~= nil)
check("...sized to the 760x700 configured above", pad.webview.rect.w == 760
      and pad.webview.rect.h == 700)
check("🐛 6.44.1 — the textarea no longer carries the invalid `font:…px inherit` "
      .. "shorthand (WebKit silently drops the whole rule on that combination)",
      pad.webview.htmlText:find("font:14px inherit", 1, true) == nil)
check("...the textarea's font-size is set as a real, valid longhand, at least 14px",
      (function()
          local sz = pad.webview.htmlText:match('textarea[^}]-font%-size:(%d+)px')
          return sz ~= nil and tonumber(sz) >= 14
      end)())
check("...and the compose box itself is taller, not just the font",
      pad.webview.htmlText:find("height:180px", 1, true) ~= nil)

-- attach an image, then take it back off before filing — the exact
-- complaint: an image that "stays attached" with no way to detach it.
CLIPBOARD_IMAGE = { saveToFile = function(self, path)
    local f = io.open(path, "w"); if f then f:write("PNG"); f:close(); return true end
    return false
end }
pad.attachClipboardImage()
check("the draft carries the pinned image", #pad.draftImages == 1)
check("...and the pad redraws with a ✕ the user can click",
      pad.webview.htmlText:find("removeImg(1)", 1, true) ~= nil)
pad.uc.callback({ body = { a = "removeImage", index = 1, text = "" } })
check("clicking the ✕ removes JUST that image from the draft",
      #pad.draftImages == 0)
check("...and the redraw no longer shows it",
      pad.webview.htmlText:find("removeImg(1)", 1, true) == nil)

-- file a note WITH an image, and confirm the draft — and its thumbnail —
-- clears from the compose box the moment the note is queued, not later.
pad.attachClipboardImage()
pad.uc.callback({ body = { a = "add", text = "Email Dana the report" } })
check("filing a note clears the draft image immediately, at file time",
      #pad.draftImages == 0)
check("...not at send time — the compose box shows no leftover thumbnail",
      pad.webview.htmlText:find("<img", 1, true) == nil)
check("...and the note itself kept its own copy of the image path",
      #pad.queue[1].images == 1)

-- 🖱 DRAGGING. hs.webview windows are borderless with no native title bar,
-- so the header is the handle and Lua drives the move by polling the real
-- mouse — a WKWebView stops seeing the pointer the moment it leaves the
-- window, which is why JS mousemove is not used.
check("the header advertises itself as the drag handle",
      pad.webview.htmlText:find("drag here", 1, true) ~= nil
      and pad.webview.htmlText:find("cursor:grab", 1, true) ~= nil)
check("...and no longer asks for a title bar hs.webview cannot give it",
      pad.webview.htmlText ~= nil and pad.webview.style == nil)

pad.webview:frame({ x = 100, y = 100, w = 760, h = 700 })
MOUSE, MOUSE_DOWN = { x = 150, y = 120 }, true
TIMERS = {}
pad.uc.callback({ body = { a = "dragStart", text = "" } })
check("a header mousedown starts a drag", pad.dragTimer ~= nil)
check("...recording where inside the window the grab happened",
      pad.dragOffset.x == 50 and pad.dragOffset.y == 20)
local dragTick
for _, t in ipairs(TIMERS) do if t.kind == "every" then dragTick = t end end
check("...on a HELD timer", dragTick ~= nil)

MOUSE = { x = 400, y = 300 }
dragTick.fn()
check("moving the mouse moves the pad, keeping the grab offset",
      pad.webview.frameRect.x == 350 and pad.webview.frameRect.y == 280)
check("...without resizing it",
      pad.webview.frameRect.w == 760 and pad.webview.frameRect.h == 700)

MOUSE_DOWN = false
dragTick.fn()
check("🖱 releasing the button ends the drag — even released OUTSIDE the "
      .. "window, since the button state is polled, not taken from JS",
      pad.dragTimer == nil and pad.dragOffset == nil)
MOUSE = { x = 999, y = 999 }
local before = pad.webview.frameRect.x
dragTick.fn()
check("...and the pad stops following the cursor once the drag is over",
      pad.webview.frameRect.x == before)

-- parked notes must be recoverable without hand-editing queue.json
pad.queue, pad.parked = {}, {
    { id = "p1", text = "Fight 4 chan", createdAt = 1, images = {}, tries = 3, parkedAt = 5 },
    { id = "p2", text = "Snap the jet", createdAt = 2, images = {}, tries = 3, parkedAt = 5 },
}
pad.render()
check("the pad offers a button to put parked notes back",
      pad.webview.htmlText:find("retryParked()", 1, true) ~= nil)
pad.uc.callback({ body = { a = "retryParked", text = "" } })
check("retrying moves every parked note back into the queue",
      #pad.queue == 2 and #pad.parked == 0)
check("...with its attempt count reset so it gets a fresh set of tries",
      pad.queue[1].tries == 0 and pad.queue[2].tries == 0)
check("...and nothing was lost in the move", (function()
    local seen = {}
    for _, n in ipairs(pad.queue) do seen[n.text] = true end
    return seen["Fight 4 chan"] and seen["Snap the jet"]
end)())
ALERTS = {}
check("retrying with nothing parked says so instead of pretending",
      pad.retryParked() == 0 and ALERTS[#ALERTS]:find("Nothing parked", 1, true))

pad.queue = {}
pad.hide()
check("closing the pad also stops any drag in progress", pad.dragTimer == nil)
hs.webview = nil

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
-- 📋 CLICKING A DATE COPIES IT. The format is the one asked for:
-- 08-07-26, every part zero-padded to two digits so pasted dates align.
CLIPBOARD_TEXT = ""
local aug7 = at(2026, 8, 7)
check("the date format is MM-DD-YY", cal.formatDate(aug7) == "08-07-26")
check("...zero-padded, so a single-digit month still has two digits",
      cal.formatDate(at(2026, 1, 5)) == "01-05-26")
check("...and the year rolls to two digits too",
      cal.formatDate(at(2027, 12, 31)) == "12-31-27")

ALERTS = {}
local copied = cal.copyDate(aug7)
check("copyDate returns what it put on the clipboard", copied == "08-07-26")
check("...and it really reached the clipboard", CLIPBOARD_TEXT == "08-07-26")
check("...and says so, with the weekday as a sanity check",
      ALERTS[#ALERTS]:find("08-07-26", 1, true) ~= nil
      and ALERTS[#ALERTS]:find("Fri", 1, true) ~= nil)

-- through the real mouse callback, the way an actual click arrives
-- The panel is already open from the block above; re-render it on a known
-- date rather than calling show(), which toggles and would close it.
CLIPBOARD_TEXT, ALERTS = "", {}
cal.today, cal.cursor = at(2026, 8, 6), at(2026, 8, 6)
cal.render()
local dayId = "day:2026-08-20"
check("(the fixture day is on screen and clickable)",
      cal.hitboxes[dayId] ~= nil)
cal.canvas._mouseCallback(cal.canvas, "mouseDown", dayId)
check("🖱 clicking a date selects it", ymd(cal.cursor) == "2026-08-20")
check("...AND copies it in one action", CLIPBOARD_TEXT == "08-20-26")
check("C copies the highlighted date without the mouse", (function()
    CLIPBOARD_TEXT = ""
    for _, b in ipairs(cal.modal.bindings) do
        if b.key == "c" then b.fn(); return CLIPBOARD_TEXT == "08-20-26" end
    end
end)())
check("...and holding C does NOT refill the clipboard 30 times a second",
      (function()
          for _, b in ipairs(cal.modal.bindings) do
              if b.key == "c" then return b.repeatFn == nil end
          end
      end)())
check("the ‹ › and Today buttons still only navigate, never copy", (function()
    CLIPBOARD_TEXT = ""
    cal.canvas._mouseCallback(cal.canvas, "mouseDown", "nav:today")
    return CLIPBOARD_TEXT == "" and ymd(cal.cursor) == "2026-08-06"
end)())
check("copyOnClick = false makes a click select only", (function()
    cal.copyOnClick = false
    CLIPBOARD_TEXT = ""
    cal.canvas._mouseCallback(cal.canvas, "mouseDown", "day:2026-08-20")
    local quiet = (CLIPBOARD_TEXT == "")
    cal.copyOnClick = true
    return quiet and ymd(cal.cursor) == "2026-08-20"
end)())
check("calendar.format is published for other modules",
      _G.service.call("calendar.format", aug7) == "08-07-26")

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

-- 🅿️ PARKED BY DEFAULT. The layout is a plan kept on the shelf, so the
-- important assertion is the NEGATIVE one: not a single ⇪ + pad key is
-- claimed, leaving them all free.
check("the layer ships parked, not live", numpad.enabled == false)
check("🅿️ NOT ONE pad key is bound — they all stay free", (function()
    for i = 0, 9 do if hyperFor({}, "pad" .. i) then return false end end
    for _, k in ipairs({ "pad+", "pad-", "pad*", "pad/", "pad.",
                         "padenter", "padclear" }) do
        if hyperFor({}, k) then return false end
    end
    return true
end)())
check("...and it says so, rather than binding keys that do nothing",
      #numpad.bound == 0)
check("the cheat sheet carries a PARKED banner so the plan stays findable",
      numMod.cheatsheet.title:find("PARKED", 1, true) ~= nil)
check("...and the first thing it says is that nothing is bound",
      numMod.cheatsheet.entries[1][2]:find("NOTHING IS BOUND", 1, true) ~= nil)
check("...and the second is how to switch it on",
      numMod.cheatsheet.entries[2][2]:find("numpad.enabled = true", 1, true) ~= nil)

-- The layout itself is still fully defined — parked means unbound, not
-- unwritten. Everything below drives it directly, without any key.
check("pad7 is TOP-LEFT — the key's own position", numpad.actions.pad7 == "topLeft")
check("pad5 is the centre", numpad.actions.pad5 == "centre")
check("pad3 is BOTTOM-RIGHT", numpad.actions.pad3 == "bottomRight")
check("pad0, the widest key, maximises", numpad.actions.pad0 == "full")

-- ---- and now the LIVE path -------------------------------------------
-- Everything from here runs with the layer switched on, so parking it is
-- proven to be a switch rather than a way of quietly deleting the feature.
numpad.enabled = true

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

-- Switching the layer on really does claim the keys — the other half of
-- the parked test above, so "parked" is proven to be reversible.
local liveMod = load("numpad_layer")
liveMod.setup(core)
local live = liveMod.numpad
check("a parked layer binds nothing on setup", #live.bound == 0)
live.enabled = true
local boundCount = live.bindAll()
check("switching it on claims every pad key", boundCount == 17, boundCount)
check("...including all ten digits", (function()
    for i = 0, 9 do if not hyperFor({}, "pad" .. i) then return false end end
    return true
end)())
check("...and the arithmetic keys", hyperFor({}, "pad+") and hyperFor({}, "pad-")
      and hyperFor({}, "pad*") and hyperFor({}, "pad/"))
check("binding twice does not double-claim anything", live.bindAll() == boundCount)

check("an unmapped key name is SKIPPED, not bound to nil", (function()
    local m2 = load("numpad_layer")
    m2.setup(core)
    local n2 = m2.numpad
    n2.actions = { padnonsense = "full", pad1 = "bottomLeft" }
    hs.keycodes.map.padnonsense = nil     -- this macOS has no such key
    n2.enabled = true
    n2.bindAll()
    -- The real key binds, the imaginary one is skipped and NAMED rather
    -- than passed to hs.hotkey as nil, which would throw.
    return #n2.bound == 1 and n2.bound[1] == "pad1"
           and #n2.skipped == 1 and n2.skipped[1] == "padnonsense"
           and logged("no key code for")
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

-- Appended to test_features.lua: the 6.44.4 efficiency work.
-- =====================================================================
-- 8. SEARCH-INDEX CACHING AND IN-SESSION PRUNING (6.44.4)
-- =====================================================================
realPrint("\n-- 6.44.4 efficiency --")
do
  local S = MODDIR
  local ft = io.open(S .. "/file_tracker.lua"):read("a")
  local at = io.open(S .. "/activity_tracker.lua"):read("a")

  check("file tracker caches its search string on the entry",
        ft:find("e%._hay") ~= nil)
  check("...and only builds it when the cache is empty",
        ft:find("if not haystack then") ~= nil)
  check("activity tracker caches its search string too",
        at:find("e%._hay") ~= nil)

  -- The cache must never reach the CSV. Both writers name their columns.
  check("🔒 the file-tracker CSV writers name columns explicitly, so _hay "
        .. "cannot leak to disk", (function()
    for line in ft:gmatch("[^\n]+") do
      if line:find("f:write") and line:find("_hay") then return false end
    end
    return true
  end)())
  check("🔒 same for the activity CSV writer", (function()
    for line in at:gmatch("[^\n]+") do
      if line:find("f:write") and line:find("_hay") then return false end
    end
    return true
  end)())

  check("the file-tracker log is pruned DURING the session, not only at boot",
        ft:find("_ftSincePrune") ~= nil and ft:find("fileTrackerPruneEvery") ~= nil)
  check("...on a counter, so recording a row stays O(1) amortised",
        ft:find("_ftSincePrune >= fileTrackerPruneEvery") ~= nil)
  check("...and both counters are LOCALS, not accidental globals",
        ft:find("local fileTrackerPruneEvery") ~= nil
        and ft:find("local _ftSincePrune") ~= nil)

  -- Behavioural proof that caching cannot change what a search returns.
  local function build(e)
    return (e.app .. " " .. (e.title or "")):lower()
  end
  local log = {}
  for i = 1, 300 do
    log[i] = { app = (i % 3 == 0) and "Safari" or "Mail",
               title = "Message " .. i, seconds = i }
  end
  local function search(entries, q, useCache)
    local hits = {}
    for _, e in ipairs(entries) do
      local hay
      if useCache then
        hay = e._hay
        if not hay then hay = build(e); e._hay = hay end
      else
        hay = build(e)
      end
      if hay:find(q, 1, true) then table.insert(hits, e.seconds) end
    end
    return table.concat(hits, ",")
  end
  local uncached = search(log, "safari", false)
  local cachedA  = search(log, "safari", true)
  local cachedB  = search(log, "safari", true)   -- now served from cache
  check("a cached search returns exactly what an uncached one does",
        uncached == cachedA and cachedA == cachedB and #uncached > 0)
  check("...and the second call really is served from the cache",
        log[1]._hay ~= nil)
end

-- Behavioural, not textual: drive the REAL pickers and prove the cache is
-- populated and reused. The first version of these tests only grepped the
-- source for "_hay", which a mutation that stopped READING the cache
-- survived untouched — a test that cannot fail is not a test.
do
  local ftMod = load("file_tracker")
  ftMod.setup(core)
  local ftChooser = _G.choosers.fileTracker
  check("the file-tracker picker exists and is query-driven",
        ftChooser ~= nil and type(ftChooser._onQuery) == "function")

  _G.fileTrackerLog = {}
  for i = 1, 50 do
    table.insert(_G.fileTrackerLog, {
      fileName = "Report " .. i .. ".xlsx", newName = "", presentLoc = "/Finance",
      movedLoc = "", event = "Renamed", timestamp = "07/08/26 09:0" .. (i % 10),
      epoch = os.time(),
    })
  end
  check("(no entry carries a search cache before the first query)",
        _G.fileTrackerLog[1]._hay == nil)

  ftChooser._onQuery("report")
  local firstHits = #(ftChooser._choices or {})
  check("⚡ typing populates the per-entry search cache",
        _G.fileTrackerLog[1]._hay ~= nil)
  check("...and it is the lowercased haystack, built once",
        _G.fileTrackerLog[1]._hay:find("report 1.xlsx", 1, true) ~= nil)
  check("...the query actually matched rows", firstHits > 0)

  -- Poison the cache: if the second query reuses it, the row disappears.
  -- That is the only way to prove the cache is READ, not merely written.
  _G.fileTrackerLog[1]._hay = "zzz-cache-was-used-zzz"
  ftChooser._onQuery("report")
  check("⚡ a later query READS the cache instead of rebuilding it",
        #(ftChooser._choices or {}) == firstHits - 1)
  ftChooser._onQuery("zzz-cache-was-used-zzz")
  check("...proven: the poisoned entry is findable only via the cache",
        #(ftChooser._choices or {}) == 1)

  local actMod = load("activity_tracker")
  actMod.setup(core)
  _G.activityLog = {}
  for i = 1, 50 do
    table.insert(_G.activityLog, {
      date = "2026-08-07", app = (i % 2 == 0) and "Safari" or "Mail",
      title = "Message " .. i, seconds = 60,
    })
  end
  check("(the activity log has no cache before searching)",
        _G.activityLog[1]._hay == nil)
  _G.service.call("activity.renderChoices", "safari")
  check("⚡ searching activity history populates its cache too",
        _G.activityLog[2]._hay ~= nil)
  -- Poison one entry's cache with a token that appears NOWHERE in its real
  -- fields. It can only be found if the search reads the cache.
  -- Poison entry 2's cache with a token that appears NOWHERE in its real
  -- fields. It can only be found if the search reads the cache. Entry 2 is
  -- Safari / "Message 2", so a hit produces the header row plus that row.
  _G.activityLog[2]._hay = "qqq-activity-cache-qqq"
  local actChooser = _G.choosers.appTracker
  check("(the activity picker is the one being driven)", actChooser ~= nil)
  _G.service.call("activity.renderChoices", "qqq-activity-cache-qqq")
  local hit = false
  for _, c in ipairs(actChooser._choices or {}) do
      if tostring(c.text):find("Message 2", 1, true) then hit = true end
  end
  check("⚡ ...and later searches READ the cache rather than rebuilding it",
        hit, "choices=" .. #(actChooser._choices or {}))
  -- The control: with the cache honest again, the token matches nothing.
  _G.activityLog[2]._hay = nil
  _G.service.call("activity.renderChoices", "qqq-activity-cache-qqq")
  check("...and a rebuilt cache no longer contains the poison", (function()
      for _, c in ipairs(actChooser._choices or {}) do
          if tostring(c.text):find("Message 2", 1, true) then return false end
      end
      return true
  end)())
end

-- =====================================================================
-- 9. PARKED NOTES ARE VISIBLE, EXPLAINED, AND NEVER SILENTLY RESENT
-- =====================================================================
do
  hs.webview = {
    usercontent = { new = function(name)
        local uc = { name = name }
        function uc:setCallback(fn) self.callback = fn; return self end
        return uc
    end },
    new = function(rect, opts, uc)
        local w = { rect = rect, opts = opts, uc = uc, htmlText = nil,
                    frameRect = { x = rect.x, y = rect.y, w = rect.w, h = rect.h } }
        function w:frame(f) if f then self.frameRect = f; return self end return self.frameRect end
        function w:html(h) self.htmlText = h; return self end
        for _, m in ipairs({ "windowTitle","windowStyle","allowTextEntry","closeOnEscape",
                             "level","show","bringToFront","delete" }) do
          w[m] = function(self) return self end
        end
        return w
    end,
  }
  pad.queue, pad.parked, pad.draftImages, pad.draft = {}, {}, {}, ""
  pad.sending = false
  pad.maxRetries = 1          -- park on the first failure, to keep this short

  -- Fail a send and let it park, capturing Asana's own reason.
  HTTP_POSTS, ALERTS, printed = {}, {}, {}
  pad.queue = { { id = "p", text = "hamonaye jamboneya", createdAt = 1,
                  images = {}, tries = 0 } }
  pad.flush("manual")
  HTTP_POSTS[1].cb(403, '{"errors":[{"message":"Not Authorized to access project"}]}')
  check("a failed send parks the note", #pad.parked == 1 and #pad.queue == 0)
  check("🔎 ...recording WHY, from Asana's own error text",
        tostring(pad.parked[1].lastError):find("Not Authorized", 1, true) ~= nil)
  check("...and the HTTP status too",
        tostring(pad.parked[1].lastError):find("403", 1, true) ~= nil)
  check("...and when it happened", type(pad.parked[1].parkedAt) == "number")

  -- 🚩 THE BEHAVIOUR THAT CAUSED THE CONFUSION: a parked note is not part
  -- of any later send, so the warning persists through every flush until
  -- it is explicitly put back.
  HTTP_POSTS, ALERTS = {}, {}
  pad.queue = { { id = "ok", text = "a different note", createdAt = 2,
                  images = {}, tries = 0 } }
  pad.flush("manual")
  check("a later send posts ONLY the queued note, never the parked one",
        #HTTP_POSTS == 1
        and HTTP_POSTS[1].body:find("a different note", 1, true) ~= nil
        and HTTP_POSTS[1].body:find("hamonaye", 1, true) == nil)
  HTTP_POSTS[1].cb(201, '{"data":{"gid":"9"}}')
  check("...and the parked note is STILL parked afterwards", #pad.parked == 1)

  -- 🚩 AND THE CASE THAT ACTUALLY BITES: the queue is EMPTY, something is
  -- parked, and you press Send now. Nothing must go out — a parked note is
  -- parked precisely so it is not retried behind your back. (A mutation
  -- that made flush fall through to pad.parked survived until this test
  -- existed, because every earlier case still had a queued note to send.)
  HTTP_POSTS, ALERTS = {}, {}
  check("(the queue really is empty with one note parked)",
        #pad.queue == 0 and #pad.parked == 1)
  pad.flush("manual")
  check("🚩 Send now with only parked notes posts NOTHING", #HTTP_POSTS == 0)
  check("...and says the queue is empty rather than pretending it sent",
        ALERTS[#ALERTS] and ALERTS[#ALERTS]:find("nothing queued", 1, true) ~= nil)
  check("...and the parked note is untouched", #pad.parked == 1)

  -- The pad must now say which note, and why, rather than only a count.
  pad.show()
  local html = pad.webview.htmlText
  check("🖥 the parked note is shown as its own row, not just counted",
        html:find("hamonaye jamboneya", 1, true) ~= nil)
  check("...labelled PARKED so it cannot be mistaken for a queued note",
        html:find("PARKED", 1, true) ~= nil)
  check("...with the reason it failed on the row",
        html:find("Not Authorized", 1, true) ~= nil)
  check("...and the banner says it is from an EARLIER send, not a live error",
        html:find("from an earlier send", 1, true) ~= nil)
  check("...and states plainly that it will not be sent until you act",
        html:find("NOT included in the next send", 1, true) ~= nil)
  check("...and still offers the button that fixes it",
        html:find("retryParked()", 1, true) ~= nil)

  -- Putting it back clears the warning and makes it sendable again.
  pad.uc.callback({ body = { a = "retryParked", text = "" } })
  check("putting it back empties the parked list", #pad.parked == 0)
  check("...and the note is queued again with a fresh set of tries",
        #pad.queue == 1 and pad.queue[1].tries == 0)
  HTTP_POSTS = {}
  pad.flush("manual")
  check("...and NOW a send includes it",
        #HTTP_POSTS == 1 and HTTP_POSTS[1].body:find("hamonaye", 1, true) ~= nil)
  HTTP_POSTS[1].cb(201, '{"data":{"gid":"10"}}')
  check("...and it finally leaves the queue", #pad.queue == 0)
  check("...leaving the pad with no warning at all", (function()
      pad.render()
      return pad.webview.htmlText:find("PARKED", 1, true) == nil
  end)())

  pad.hide()
  hs.webview = nil
  pad.maxRetries = 3
end

-- =====================================================================
-- 10. OPENING THE PAD MUST NOT ACTIVATE THE WHOLE APPLICATION (6.44.6)
-- =====================================================================
do
  APP_ACTIVATIONS = {}
  hs.application = { launchOrFocus = function(n)
      table.insert(APP_ACTIVATIONS, n) end }
  hs.webview = {
    usercontent = { new = function(name)
        local uc = { name = name }
        function uc:setCallback(fn) self.callback = fn; return self end
        return uc
    end },
    new = function(rect, opts, uc)
        local w = { rect = rect, uc = uc, htmlText = nil, front = nil,
                    textEntry = nil,
                    frameRect = { x = rect.x, y = rect.y, w = rect.w, h = rect.h } }
        function w:frame(f) if f then self.frameRect = f; return self end return self.frameRect end
        function w:html(h) self.htmlText = h; return self end
        function w:allowTextEntry(v) self.textEntry = v; return self end
        function w:bringToFront(v) self.front = v; return self end
        for _, m in ipairs({ "windowTitle","windowStyle","closeOnEscape",
                             "level","show","delete" }) do
          w[m] = function(self) return self end
        end
        return w
    end,
  }
  pad.queue, pad.parked, pad.draftImages, pad.draft = {}, {}, {}, ""
  pad.show()
  check("🐛 6.44.6 — opening the pad does NOT activate the Hammerspoon app "
        .. "(that is what dragged the Console forward with it)",
        #APP_ACTIVATIONS == 0, table.concat(APP_ACTIVATIONS, ","))
  check("...the pad window itself is still raised", pad.webview.front == true)
  check("...and can still take the keyboard, which is what allowTextEntry does",
        pad.webview.textEntry == true)

  pad.hide()
  pad.focusOnOpen = false
  pad.show()
  check("focusOnOpen = false opens the pad without grabbing focus at all",
        pad.webview.front == nil)
  check("...and still never activates the app", #APP_ACTIVATIONS == 0)
  pad.focusOnOpen = true
  pad.hide()
  hs.webview = nil
end

-- =====================================================================
os.execute('rm -rf "' .. TMP .. '"')
realPrint(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then
    for _, f in ipairs(failures) do realPrint("  ✗ " .. f) end
    os.exit(1)
end
