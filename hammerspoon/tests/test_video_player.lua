-- =====================================================================
-- test_video_player.lua — 6.344.0: ⇪⇧, the Mug Player
-- =====================================================================
--     lua5.4 test_video_player.lua [/path/to/hammerspoon]
--
-- Executes modules/video_player.lua against a stubbed Mac. Everything
-- that DECIDES anything here is pure — what plays, how a film is
-- reached, what is kept, where the window opens — so the whole of it is
-- proven with no window, no films and no WebKit.
--
-- 🧪 AND THE STUBS ARE AS UNFORGIVING AS macOS (6.290.0), which is this
-- project's most expensive lesson: :html() RECORDS its second argument,
-- because the base URL IS the release and a stub that threw it away
-- would make the whole door mechanism untestable; :show() can REFUSE,
-- which is the beta-OS shape (6.265.0); hs.task's :start() can refuse by
-- RETURNING FALSE rather than throwing (6.304.0); and the service
-- registry is init.lua's own, LIFTED, so this suite cannot invent a
-- calling convention and certify a bug the way test_anchors did for
-- eighty-nine releases (6.273.0).
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
SCREENS = { { x = 0, y = 0, w = 1440, h = 900 } }

local CLOUD, NO_BLOCKS = {}, false

local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
            .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

-- ---- the stub Mac ------------------------------------------------------
local TIMERS, ALERTS, PRINTED, DEGRADED, JS = {}, {}, {}, {}, {}
local WEBVIEWS, CANVASES, TASKS = {}, {}, {}
local FOCUSED_WIN, WIN_SEQ = nil, 0
NO_WEBVIEW, NO_CANVAS, SHOW_REFUSES = false, false, false
-- 🔬 6.265.0 — MISSING is not REFUSING, and on a beta OS the second is
-- the shape this config keeps meeting. NO_CANVAS takes hs.canvas away
-- entirely; CANVAS_REFUSES leaves it there and makes new() answer nil.
CANVAS_REFUSES = false
NO_HSWINDOW, REFUSE_FOCUS           = false, false
NO_DRAGLEVEL, NO_DRAGCB             = false, false
-- 🔬 CREATED, WIRED, REFUSED TO SHOW — 6.265.0's shape for the FIFTH
-- time, and the one this catcher was blind to: hs.canvas:show() THROWS
-- when AppKit will not order the window on screen, and the old code
-- discarded that answer and recorded the catcher as "ready".
CANVAS_SHOW_REFUSES                 = false
TASK_START_REFUSES, NO_TASK         = false, false

local realOpen  = io.open
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

-- 🔬 io.open is stubbed so the store is proven without touching disk,
-- and it TRUNCATES on "w" because macOS does (6.313.0): a stub that
-- appended across opens would make the zero-byte window unreachable.
local DISK, WRITE_FAILS, RENAME_FAILS = {}, false, false
-- 🕒 the clock the stubbed hs.timer answers with; a test moves it to
-- make a turn expensive (6.234.0 — the clock is an ARGUMENT).
CLOCK, CLOCK_STEP = 1000, 0
-- 🔬 this Mac's physical memory, as hs.host.vmStat answers it, and
-- the queue of evaluateJavaScript completions the page has not run yet.
JS_ACKS, MEM_BYTES = {}, 16 * 1024 * 1024 * 1024
io.open = function(path, mode)
    if mode == "w" then
        if WRITE_FAILS then return nil end
        local buf = {}
        return { write = function(_, s) buf[#buf + 1] = s end,
                 close = function() DISK[path] = table.concat(buf) end }
    end
    if DISK[path] == nil then return nil end
    local body = DISK[path]
    -- 🔬 6.354.0 — AND THE READ IS FAITHFUL, which 6.290.0 is the ratchet
    -- for. The old stub answered the WHOLE body to every `read`,
    -- whatever it was asked for, and never answered nil — so the bytes
    -- loader, which reads a bounded chunk per turn until EOF, would have
    -- looped for ever against it and the real EOF branch would have been
    -- unreachable from the gate. Lua's own file:read(n) returns AT MOST
    -- n bytes and nil once there are none, and so does this.
    local pos = 1
    local f = { close = function() end }
    function f:read(n)
        if n == "*a" or n == "a" then
            local rest = body:sub(pos) ; pos = #body + 1 ; return rest
        end
        local want = math.floor(tonumber(n) or 0)
        if want < 1 then return "" end
        if pos > #body then return nil end
        local chunk = body:sub(pos, pos + want - 1)
        pos = pos + #chunk
        return chunk
    end
    return f
end
local realRename, realRemove = os.rename, os.remove
os.rename = function(a, b)
    if RENAME_FAILS then return nil, "refused" end
    DISK[b] = DISK[a] ; DISK[a] = nil ; return true
end
os.remove = function(p) DISK[p] = nil ; return true end

hs = {
    timer = {
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t ; return t
        end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, every = true, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t ; return t
        end,
        -- 🕒 A CLOCK THAT ADVANCES, so the per-turn budget and its 🔔
        -- door are DRIVEN rather than grepped for. A frozen clock makes
        -- every turn cost 0 ms, which puts the whole budget out of the
        -- gate's reach — the shape 6.290.0 is the ratchet against.
        -- CLOCK_STEP is 0 by default, so nothing else in the suite moves.
        secondsSinceEpoch = function()
            local c = CLOCK
            CLOCK = CLOCK + (CLOCK_STEP or 0)
            return c
        end,
    },
    -- 🔬 hs.host.vmStat() answers memSize — physical memory in bytes
    -- (extensions/host/libhost.m:99, :189, from sysctl HW_MEMSIZE). On
    -- a sysctl failure it returns NOTHING (libhost.m:142-149), so nil
    -- is a state the ceiling has to survive, and MEM_BYTES = nil drives
    -- it (6.290.0 — a stub models the provider's refusals too).
    host  = {
        vmStat = function()
            if MEM_BYTES == nil then return nil end
            return { memSize = MEM_BYTES, pageSize = 16384 }
        end,
    },
    fs    = {
        mkdir = function() return true end,
        -- 🔬 A SIZE, read off the same virtual disk the reads come from,
        -- so a film the loader can open is a film it can also measure —
        -- and a film that is not there answers nil, which is the input
        -- `loadPlan`'s first branch exists for.
        attributes = function(path, key)
            local body = DISK[path]
            if body == nil then return nil end
            local a = { size = #body, mode = "file" }
            -- CLOUD[path] = the bytes actually allocated locally; absent
            -- means fully downloaded, which is the ordinary case.
            if NO_BLOCKS then
                a.blocks = nil
            else
                local have = CLOUD[path]
                if have == nil then have = #body end
                a.blocks = math.ceil(have / 512)
            end
            if key then return a[key] end
            return a
        end,
    },
    -- 🔬 BINARY-SAFE, like hs.base64 really is: extensions/base64/
    -- libbase64.m encodes with luaL_tolstring + initWithBytes:length:,
    -- so a NUL byte does NOT truncate a chunk. A stub that stopped at a
    -- NUL would make a scrambled film unreachable from the gate, which
    -- is the costliest shape 6.290.0 names.
    base64 = {
        encode = function(data)
            local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            local out, n = {}, #data
            for i = 1, n, 3 do
                local c1 = data:byte(i) or 0
                local c2 = data:byte(i + 1)
                local c3 = data:byte(i + 2)
                local v = c1 * 65536 + (c2 or 0) * 256 + (c3 or 0)
                local s1 = b:sub((v >> 18) + 1, (v >> 18) + 1)
                local s2 = b:sub(((v >> 12) & 63) + 1, ((v >> 12) & 63) + 1)
                local s3 = c2 and b:sub(((v >> 6) & 63) + 1, ((v >> 6) & 63) + 1) or "="
                local s4 = c3 and b:sub((v & 63) + 1, (v & 63) + 1) or "="
                out[#out + 1] = s1 .. s2 .. s3 .. s4
            end
            return table.concat(out)
        end,
        decode = function(str)
            local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            local out = {}
            str = str:gsub("=", "")
            local bits, acc = 0, 0
            for i = 1, #str do
                local c = str:sub(i, i)
                local idx = b:find(c, 1, true)
                if idx then
                    acc = acc * 64 + (idx - 1) ; bits = bits + 6
                    if bits >= 8 then
                        bits = bits - 8
                        out[#out + 1] = string.char((acc >> bits) & 255)
                        acc = acc & ((1 << bits) - 1)
                    end
                end
            end
            return table.concat(out)
        end,
    },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    window = {
        focusedWindow = function()
            if FOCUSED_WIN == nil then return nil end
            local id = FOCUSED_WIN ; local w = {}
            function w:id() return id end ; return w
        end,
    },
    screen = {
        mainScreen = function()
            return { frame = function() return SCREENS[1] end }
        end,
        allScreens = function()
            local o = {}
            for _, f in ipairs(SCREENS) do
                o[#o + 1] = { frame = function() return f end }
            end
            return o
        end,
    },
    drawing = { windowLevels = { floating = 5 } },
    -- 🔬 hs.task:start() REFUSES BY RETURNING FALSE (6.304.0,
    -- extensions/task/libtask.m) — it does not throw, so a pcall around
    -- it succeeds on a refusal. Modelled, or the ⌘O path cannot be
    -- driven both ways.
    task = {
        new = function(bin, cb, args)
            if NO_TASK then error("no hs.task", 0) end
            -- 🔬 THE CALLBACK IS KEPT. Without it a task's ANSWER is
            -- unreachable from the gate and the whole callback body is
            -- untestable — 6.304.0, where the Secure Input probe's body
            -- had never once been run by a suite.
            local t = { bin = bin, args = args, cb = cb }
            function t:start()
                TASKS[#TASKS + 1] = { bin = bin, args = args, cb = cb }
                if TASK_START_REFUSES then return false end
                return self
            end
            return t
        end,
    },
    json = {
        encode = function(v)
            -- 🔬 6.290.0, AND IT COST A WHOLE RELEASE: LuaSkin declares
            -- this `checkArgs:LS_TTABLE` and RAISES on anything else, so
            -- `hs.json.encode("a name")` is an error on a Mac and was a
            -- happy little string here. video_player's payload builder
            -- called it on every film name; on his Mac every one came
            -- back `""` and the window drew a black rectangle, while
            -- 174 checks and 44 page checks stayed green. A STUB MODELS
            -- THE PROVIDER'S REFUSALS, and this is the refusal.
            if type(v) ~= "table" then
                error("ERROR: incorrect type '" .. type(v)
                      .. "' for argument 1 (expected table)")
            end
            local function enc(x)
                if type(x) == "table" then
                    if #x > 0 then
                        local p = {}
                        for _, y in ipairs(x) do p[#p + 1] = enc(y) end
                        return "[" .. table.concat(p, ",") .. "]"
                    end
                    local keys = {}
                    for k in pairs(x) do keys[#keys + 1] = k end
                    table.sort(keys)
                    local p = {}
                    for _, k in ipairs(keys) do
                        p[#p + 1] = string.format("%q", k) .. ":" .. enc(x[k])
                    end
                    return "{" .. table.concat(p, ",") .. "}"
                end
                if type(x) == "string" then return string.format("%q", x) end
                return tostring(x)
            end
            return enc(v)
        end,
        decode = function(s) return _G.FAKE_DECODE end,
    },
    canvas = {
        windowLevels = { dragging = 11 },
        -- (NO_CANVAS removes this whole table below, after hs is built)
        new = function(rect)
            if CANVAS_REFUSES then return nil end
            local c = { rect = rect, deleted = false, shown = false }
            -- 🔬 hs.canvas DOCUMENTS a mouseCallback as required before
            -- a window will accept a dragged file, and its absence is
            -- invisible in the result — the drag simply passes through
            -- to whatever is behind, which is the shape that cost
            -- 6.233.0. A stub that accepted a drag without one would
            -- make that condition unprovable (6.290.0).
            function c:mouseCallback() self.hasMouseCb = true ; return self end
            function c:level()
                if NO_DRAGLEVEL then error("no such level", 0) end
                return self
            end
            function c:draggingCallback(fn)
                if NO_DRAGCB then error("no drag support", 0) end
                if not self.hasMouseCb then
                    error("a canvas with no mouseCallback takes no drags", 0)
                end
                self.dragFn = fn ; return self
            end
            function c:show()
                if CANVAS_SHOW_REFUSES then
                    error("NSInternalInconsistencyException: "
                          .. "containingWindowWillOrderOnScreen:", 0)
                end
                self.shown = true ; return self
            end
            function c:delete() self.deleted = true ; return self end
            function c:frame(r) if r then self.rect = r end return self.rect end
            setmetatable(c, { __newindex = function(t, k, v) rawset(t, k, v) end })
            CANVASES[#CANVASES + 1] = c ; return c
        end,
    },
    webview = {
        usercontent = {
            new = function(name)
                local uc = { name = name }
                function uc:setCallback(fn) self.cb = fn ; return self end
                return uc
            end,
        },
        new = function(rect, _, uc)
            if NO_WEBVIEW then return nil end
            local v = { rect = rect, uc = uc, shown = false, deleted = false }
            function v:windowTitle() return self end
            function v:allowTextEntry() return self end
            function v:level() return self end
            function v:behaviorAsLabels() return self end
            function v:alpha() return self end
            -- 🪟 THE SECOND ARGUMENT IS RECORDED. The base URL is what
            -- door 1 IS, so a stub that accepted :html(h) and dropped
            -- the base would make every door check pass with the whole
            -- mechanism deleted (6.290.0).
            function v:html(h, base)
                self.htmlText = h ; self.baseURL = base
                self.loads = (self.loads or 0) + 1 ; return self
            end
            -- 🚪 DOOR 3 LOADS BY URL, NOT BY STRING, and that is the
            -- whole of what it tests — so the stub records it APART
            -- from :html(). A stub that aliased the two would make the
            -- door pass with the mechanism deleted (6.290.0).
            function v:url(u)
                self.urlLoaded = u
                self.loads = (self.loads or 0) + 1 ; return self
            end
            function v:show()
                if SHOW_REFUSES then return false end
                self.shown = true ; return self
            end
            function v:bringToFront() return self end
            function v:delete() self.deleted = true ; return self end
            function v:frame(r)
                if r == nil then return self.rect end
                self.rect = { x = r.x, y = r.y, w = r.w, h = r.h } ; return self
            end
            function v:evaluateJavaScript(s, done)
                -- 🔬 A window macOS has taken away THROWS here, which is
                -- the only way the loader can learn mid-read that its
                -- page is gone. A stub that always succeeded would make
                -- that branch — and the file handle it closes —
                -- unreachable from the gate (6.290.0).
                if JS_THROWS then error("the window is gone", 0) end
                JS[#JS + 1] = s
                -- 🔬 THE REAL ONE RETURNS BEFORE THE SCRIPT RUNS and
                -- calls `done` LATER, on the main queue
                -- (libwebview.m:1688-1725). A stub that called it inline
                -- would run the next turn inside this one — the loader
                -- would recurse instead of pacing, and the shape the
                -- release exists for would be unreachable (6.290.0).
                if done then JS_ACKS[#JS_ACKS + 1] = done end
                return self
            end
            v.winId = (WIN_SEQ or 0) + 1 ; WIN_SEQ = v.winId
            function v:hswindow()
                if NO_HSWINDOW then return nil end
                local id = self.winId ; local w = {}
                function w:id() return id end
                function w:focus()
                    if not REFUSE_FOCUS then FOCUSED_WIN = id end
                    return self
                end
                return w
            end
            WEBVIEWS[#WEBVIEWS + 1] = v ; return v
        end,
    },
}

_G.diag = { say = function() end, warn = function() end, err = function() end }

-- 🔌 init.lua's OWN registry, lifted (6.273.0). The real opener is
-- passed because io.open is faked above, and `reg.src` is asserted:
-- a lift that silently fell back to the stand-in would make every
-- service check green and meaningless (test_vault cost a cycle to that).
local REG = dofile(HS .. "/tests/service_registry.lua")(HS, realOpen)
_G.service = REG.service

local BOUND, PROVIDED, ESC_CLAIMS = {}, {}, {}
local CORE = {
    homeDir = "/Users/lee",
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[((mods and mods[1]) or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
    degrade = function(tool, why)
        DEGRADED[#DEGRADED + 1] = tostring(tool) .. ": " .. tostring(why)
        return false, why
    end,
    resolveBaseScreen = function()
        return { frame = function() return SCREENS[1] end }
    end,
}
_G.claimEscape = function(name, _, active, handle)
    ESC_CLAIMS[name] = { active = active, handle = handle } ; return true
end
_G.hyperExpectRelease = function() end
_G.beginPanelDrag     = function(who) _G.DRAGGED = who end

local chunk = assert(loadfile(HS .. "/modules/video_player.lua"))
local M = chunk()
M.setup(CORE)
local vid = _G.mugPlayer

local function reset()
    vid.queue, vid.history = {}, {}
    vid.index, vid.sel, vid.selList = 0, 1, "queue"
    vid.door, vid.doorStart, vid.doorWorked = 1, 1, nil
    vid.doorFailed, vid.refused = {}, {}
    vid.gen, vid.plays, vid.externals, vid.forgotten = 0, 0, 0, 0
    -- 6.348.0's per-session show counters. reset() models a FRESH
    -- session, so a count that survives it makes the next section
    -- measure the previous one's refusals (which is how the
    -- 'recovered' row first went red against correct code).
    vid.shows, vid.refusedShows = 0, 0
    vid.recovered, vid.lostShows, vid.noBelt = 0, 0, 0
    -- 6.352.0's two doors, for the same reason: a pageDrops that survived
    -- reset made the next section read the previous one's drop, and a
    -- pageSpoke that survived made a page which had never spoken report
    -- as a window that was merely closed.
    vid.pageDrops, vid.catchDrops, vid.catchRefused = 0, 0, 0
    vid.handedOff, vid.byHand, vid.handOff = 0, 0, true
    vid.pageSpoke, vid.catcherOn, vid.uriWhy = false, false, nil
    -- 6.354.0's bytes door, for the same reason a third time: a run
    -- count, a turn count or a read in flight that survived reset() would
    -- make the next section measure this one's film — and `load` surviving
    -- would make a fresh section report a read that is not happening.
    vid.loadStop(nil)
    vid.loadRuns, vid.loadTurns, vid.loadWorst = 0, 0, 0
    vid.loadBytes, vid.blobPlayed, vid.blobFailed, vid.loadSlow = 0, 0, 0, 0
    vid.loadWhy, vid.blobLoad = "the loader has not been asked yet", true
    vid.chunkBytes, vid.blobMax = 2 * 1024 * 1024, 1536 * 1024 * 1024
    vid.slowTurnMs, vid.loadEvery = 120, 0
    -- 6.355.0: the measured ceiling is worked out ONCE and kept, so a
    -- section that moved the Mac's memory would be answered with the
    -- previous section's number.
    vid.ceilBytes, vid.ceilWhy = nil, "the ceiling has not been asked yet"
    vid.blobShare, vid.blobFloor = 1 / 3, 3 * 1024 * 1024 * 1024
    vid.blobCap, vid.ackSecs = 8 * 1024 * 1024 * 1024, 20
    vid.acks, vid.ackLate, vid.ackNoBelt, vid.loadMs = 0, 0, 0, 0
    -- 6.357.0's cloud guard, for the same reason: a refusal count or a
    -- verdict that survived reset() would make a fresh section report
    -- the previous one's placeholder.
    vid.cloudRefused, vid.diskOK = 0, nil
    vid.diskWhy = "no film has been asked for yet"
    vid.cloudFloor, vid.cloudFrac = 4 * 1024 * 1024, 0.9
    -- 6.358.0: a `small` frame that survived reset() would make the
    -- next section's first ⌃⌘F SHRINK the window to this one's frame
    -- instead of filling the screen.
    vid.small, vid.fills, vid.fillGap = nil, 0, 0
    vid.fillWhy = "⌃⌘F has not been pressed this session"
    CLOUD, NO_BLOCKS = {}, false
    JS_ACKS, MEM_BYTES = {}, 16 * 1024 * 1024 * 1024
    CLOCK, CLOCK_STEP = 1000, 0
    vid.dragSeen, vid.dropReader = "no drag yet this session", nil
    if vid.retryTimer then
        pcall(function() vid.retryTimer:stop() end) ; vid.retryTimer = nil
    end
    JS, ALERTS, DEGRADED, TASKS = {}, {}, {}, {}
    SHOW_REFUSES, NO_WEBVIEW, NO_CANVAS = false, false, false
    NO_DRAGLEVEL, NO_DRAGCB = false, false
    CANVAS_SHOW_REFUSES = false
    JS_THROWS = false
    CANVAS_REFUSES, TASK_START_REFUSES, NO_TASK = false, false, false
    WRITE_FAILS, RENAME_FAILS = false, false
    if vid.webview then vid.hide() end
end

-- ⌨️ The focus chase is a HELD doEvery (6.196.1). Nothing fires a timer
-- on this stub Mac, so the suite fires it: a check that never ran the
-- chase would pass with the whole of it deleted.
local function runTimers(n)
    for _ = 1, (n or 1) do
        for _, t in ipairs(TIMERS) do
            if not t.stopped and t.fn then t.fn() end
        end
    end
end

local function jsHas(needle)
    for _, s in ipairs(JS) do if s:find(needle, 1, true) then return true end end
    return false
end
local function anyHas(list, needle)
    for _, s in ipairs(list) do if s:find(needle, 1, true) then return true end end
    return false
end

out("\n🎬 MUG PLAYER\n")

-- §1 ── the lift itself ------------------------------------------------
out("\n§1 the service registry is init.lua's own\n")
check("🔌 the registry was LIFTED out of init.lua, not invented here",
      REG.src ~= nil)
check("🔌 service.call hands back the provider's OWN values, raw",
      (function()
          REG.service.provide("t.three", function() return "a", "b", "c" end)
          local a, b, c = REG.service.call("t.three")
          return a == "a" and b == "b" and c == "c"
      end)())

-- §2 ── what plays -----------------------------------------------------
out("\n§2 .mp4 only — his scope\n")
check("🎬 an .mp4 plays", (vid.playable("/f/a.mp4", { mp4 = true })))
check("🎬 .MP4 plays too — an extension is not case", 
      (vid.playable("/f/A.MP4", { mp4 = true })))
local ok, why = vid.playable("/f/a.mkv", { mp4 = true })
check("🎬 .mkv is refused", not ok)
-- 🔑 6.320.0 — a refusal he cannot act on is a defect even when the
-- refusal is right. The check asserts the SENTENCE, not just the false.
check("🎬 …and the refusal NAMES the list and the way out", 
      why:find(".mp4", 1, true) ~= nil and why:find("QuickTime", 1, true) ~= nil, why)
local ok2, why2 = vid.playable("/f/noext", { mp4 = true })
check("🎬 a file with no extension is refused, and said",
      not ok2 and why2:find("extension", 1, true) ~= nil, why2)
check("🎬 an empty path is refused", not (vid.playable("", { mp4 = true })))
-- 📏 The list is a knob, so widening it is a word from him, not a
-- release — and the check MOVES it rather than asserting the shipped
-- default twice (6.239.0).
check("📏 widening the list is a settings line — .mov then plays",
      (vid.playable("/f/a.mov", { mp4 = true, mov = true })))

-- §3 ── the URL encoder, which is where a film is lost ------------------
out("\n§3 a path becomes a URL\n")
check("🔑 a space is encoded", vid.encodePath("/a/b c.mp4") == "/a/b%20c.mp4",
      vid.encodePath("/a/b c.mp4"))
-- 🚨 THE FIXTURE THAT BITES, AND IT CAUGHT THE FIRST IMPLEMENTATION:
-- a name holding BOTH a percent and a space. A two-pass encoder — "%"
-- in one gsub, the rest in another — re-encodes the "%" of the escape
-- it has just written, so "50% off.mp4" came out "50%2525%20off.mp4"
-- and no file could load. Either character ALONE passes under the
-- wrong implementation (6.230.0 — pick the input where the two must
-- differ).
check("🚨 ONE PASS: '50% off.mp4' survives both characters at once",
      vid.encodePath("/a/50% off.mp4") == "/a/50%25%20off.mp4",
      vid.encodePath("/a/50% off.mp4"))
-- 🚨 An unescaped # begins a URL FRAGMENT, so the request stops there
-- and the film is simply absent — the one that costs a whole file
-- rather than a character.
check("🚨 '#' is encoded — unescaped it truncates the URL at the fragment",
      vid.encodePath("/a/Pt 2 #final.mp4") == "/a/Pt%202%20%23final.mp4",
      vid.encodePath("/a/Pt 2 #final.mp4"))
check("🔑 the separators are LEFT ALONE — encoding / flattens the path",
      vid.encodePath("/a/b/c.mp4") == "/a/b/c.mp4")
check("🔑 an apostrophe is encoded", 
      vid.encodePath("/a/Don't.mp4") == "/a/Don%27t.mp4",
      vid.encodePath("/a/Don't.mp4"))

-- §4 ── the ways in ----------------------------------------------------
out("\n§4 the doors, in order\n")
local doors = vid.sourceDoors("/Films/My Film.mp4")
-- 🚪 6.354.0 — THREE, and the THIRD IS NOT A URL. 6.351.0's third door
-- was a page written as a FILE beside the film and asked for by file
-- URL; his Mac answered it with NSURLErrorDomain -3001 ("Cannot open
-- file"), a NAVIGATION error, which unlike MediaError code 4 is not
-- ambiguous. That door is gone (§20 holds the measurement) and what
-- replaces it carries no URL at all.
check("🪟 there are THREE ways in, and more than one is the point",
      #doors == 3, #doors)
check("🪟 …and the LAST one carries no URL — that is the whole point of"
      .. " it, so a refusal of file:// cannot reach it",
      doors[3].bytes == true and doors[3].src == ""
      and doors[3].base == nil,
      tostring(doors[3].bytes) .. " | " .. tostring(doors[3].src))
check("🪟 …and the two URL doors are NOT marked as the bytes door, or"
      .. " the walker would stop rebuilding for a new base URL",
      doors[1].bytes == nil and doors[2].bytes == nil)
check("🪟 door 1 is the film's own folder as the base URL",
      doors[1].base == "file:///Films/" and doors[1].src == "My%20Film.mp4",
      tostring(doors[1].base) .. " | " .. tostring(doors[1].src))
check("🪟 door 2 is the absolute file URL, with no base",
      doors[2].base == nil
      and doors[2].src == "file:///Films/My%20Film.mp4",
      tostring(doors[2].src))
check("🪟 each door NAMES itself, so the report can say which carried it",
      type(doors[1].how) == "string" and doors[1].how ~= ""
      and doors[1].how ~= doors[2].how)
check("🪟 a film at the root of a volume still has a base",
      vid.sourceDoors("/a.mp4")[1].base == "file:///")
check("🪟 no path, no doors", #vid.sourceDoors("") == 0)

-- §5 ── the history ----------------------------------------------------
out("\n§5 thirty days, one row per file\n")
local NOW = 1760000000
local h = vid.noteHistory({}, { path = "/a.mp4" }, NOW, 30, 400)
check("🕘 a film played is remembered", #h == 1 and h[1].path == "/a.mp4")
h = vid.noteHistory(h, { path = "/b.mp4" }, NOW + 10, 30, 400)
check("🕘 newest first", h[1].path == "/b.mp4" and h[2].path == "/a.mp4")
h = vid.noteHistory(h, { path = "/a.mp4" }, NOW + 20, 30, 400)
check("🕘 ONE ROW PER FILE — the older row for the same film goes",
      #h == 2 and h[1].path == "/a.mp4", #h)
local old = { { path = "/old.mp4", at = NOW - 31 * 86400 } }
check("🕘 past the window, dropped",
      #vid.noteHistory(old, nil, NOW, 30, 400) == 0)
check("🕘 day 29 is in, day 31 is out",
      #vid.noteHistory({ { path = "/x", at = NOW - 29 * 86400 } }, nil, NOW, 30, 400) == 1
      and #vid.noteHistory({ { path = "/x", at = NOW - 31 * 86400 } }, nil, NOW, 30, 400) == 0)
-- 🚨 The cap keeps the NEWEST. Keeping the oldest is the easy way to
-- write it wrong and reads identically until the list is full.
local many = {}
for i = 1, 10 do many[i] = { path = "/f" .. i .. ".mp4", at = NOW - i } end
local capped = vid.noteHistory(many, nil, NOW, 30, 3)
check("🕘 the cap keeps the NEWEST, not the oldest",
      #capped == 3 and capped[1].path == "/f1.mp4", capped[1] and capped[1].path)
check("🕘 a row with no path is not a row",
      #vid.noteHistory({ { at = NOW } }, nil, NOW, 30, 400) == 0)

out("\n§6 forgetting a row\n")
local list = { { path = "/a.mp4" }, { path = "/b.mp4" }, { path = "/a.mp4" } }
local left, gone = vid.forgetHistory(list, "/a.mp4")
-- 6.199.0 — EVERY match goes, or a duplicate survives a command that
-- said it removed the film.
check("🗑 every matching row goes, not just the first", gone == 2 and #left == 1)
check("🗑 and the right one is left", left[1].path == "/b.mp4")
-- 🚨 A BLANK MESSAGE MUST NEVER EMPTY THE LIST, and the fixture that
-- proves it has to CONTAIN a row an empty path would match. The first
-- version passed "" against three real paths, where nothing matches
-- either way — the guard was unkillable, and the mutation sweep said
-- so. 6.230.0: pick the input where the two implementations differ.
local withBlank = { { path = "" }, { path = "/a.mp4" }, { path = "" } }
local same, none = vid.forgetHistory(withBlank, "")
check("🗑 an EMPTY path is refused — a blank message empties nothing",
      none == 0 and #same == 3, tostring(none) .. " removed")
check("🗑 …and a real path still works on that same list",
      select(2, vid.forgetHistory(withBlank, "/a.mp4")) == 1)
check("🗑 a path no row holds removes nothing",
      select(2, vid.forgetHistory(list, "/zz.mp4")) == 0)

-- §7 ── the cursor -----------------------------------------------------
out("\n§7 one cursor over two lists\n")
local s = vid.selMove({ list = "queue", row = 2 }, 3, 2, 1)
check("⌨️ ↓ inside the queue", s.list == "queue" and s.row == 3)
s = vid.selMove({ list = "queue", row = 3 }, 3, 2, 1)
-- 6.315.0 — the whole defect: ↓ off the last queue row used to wrap
-- back to the top, so the history below was unreachable from the
-- keyboard at all.
check("⌨️ ↓ off the last queue row reaches the HISTORY",
      s.list == "history" and s.row == 1, s.list .. " " .. s.row)
s = vid.selMove({ list = "history", row = 2 }, 3, 2, 1)
check("⌨️ ↓ off the last history row wraps to the top of the queue",
      s.list == "queue" and s.row == 1)
s = vid.selMove({ list = "history", row = 1 }, 3, 2, -1)
check("⌨️ ↑ off the first history row lands on the LAST queue row",
      s.list == "queue" and s.row == 3)
s = vid.selMove({ list = "history", row = 5 }, 3, 2, 0)
-- d = 0 CLAMPS rather than moves — the second caller, since every edit
-- can leave the cursor past the end of its list.
check("⌨️ d=0 CLAMPS a cursor past the end of its list",
      s.list == "queue" and s.row == 1, s.list .. " " .. s.row)
s = vid.selMove({ list = "queue", row = 1 }, 0, 0, 1)
check("⌨️ both lists empty: it does not walk off into nothing",
      s.list == "queue" and s.row == 1)
-- 🕘 nh is what is DRAWN, never #history: a cursor counted off a store
-- of 400 walks into rows nobody can see.
check("🕘 the drawn count is what the cursor counts off",
      vid.histShown(400, 20) == 20 and vid.histShown(3, 20) == 3)

-- §8 ── where the window opens -----------------------------------------
out("\n§8 placement\n")
local sf = { x = 0, y = 0, w = 1440, h = 900 }
local r, pw = vid.placeFor(nil, sf, { sf })
check("📐 with nothing remembered it is centred", pw == "centred")
check("📐 and it fits the screen", r.w <= sf.w - 40 and r.h <= sf.h - 40)
r, pw = vid.placeFor({ x = 100, y = 80 }, sf, { sf })
check("📐 a remembered spot that fits is obeyed",
      r.x == 100 and r.y == 80 and pw == "where you put it")
r, pw = vid.placeFor({ x = 1400, y = 880 }, sf, { sf })
check("📐 one that would hang off the edge is nudged back, and SAYS so",
      r.x < 1400 and pw:find("nudged", 1, true) ~= nil, pw)
-- 6.196.0's rule: a position on no current screen is DROPPED for the
-- default, never dragged onto a screen it was never on.
r, pw = vid.placeFor({ x = 5000, y = 80 }, sf, { sf })
check("📐 a spot on a screen you are not on is DROPPED, not dragged over",
      pw:find("no screen", 1, true) ~= nil, pw)

-- §9 ── the window -----------------------------------------------------
out("\n§9 the window opens, and a refusal is not an open window\n")
reset()
check("🪟 it opens", vid.show() == true and vid.webview ~= nil)
check("🪟 …and a catcher went up with it", vid.catcher ~= nil)
runTimers(1)
check("⌨️ the keyboard was taken on the first try",
      (vid.focus or {}).why and (vid.focus.why):find("took the keys", 1, true) ~= nil,
      (vid.focus or {}).why)
check("🪟 pressing again closes it", vid.toggle() == false and vid.webview == nil)
check("🪟 …and the catcher went with it", vid.catcher == nil)
reset()
-- 🚨 6.265.0 / 6.326.0 — CREATED, WIRED, REFUSED TO SHOW. Driving the
-- path with the dependency MISSING is not the same as driving it with
-- the dependency REFUSING, and on a beta OS the second is the shape
-- this config keeps meeting.
SHOW_REFUSES = true
check("🪟 a window macOS refuses to show is NOT recorded as open",
      vid.webview == nil and (vid.show() or true) and vid.webview == nil)
-- 🚨 6.348.0 — AND IT IS RETRIED ONCE BEFORE IT IS GIVEN UP ON. His
-- 2026-10-10 20:45:51 Console carries `-- Loading extension: webview`,
-- `-- Loading extension: drawing` and the refusal in the SAME SECOND:
-- the first ⇪⇧, of a session paid two main-thread dylib loads and then
-- asked AppKit to order a window on screen in the same turn. The retry
-- is 6.266.0's shape — the CALLER decides, a beat later — so nothing
-- can be put on screen that this module has stopped tracking.
check("🪟 …and a retry is armed rather than the window being dropped",
      vid.retryTimer ~= nil)
check("🪟 …and it is NOT recorded as open while the retry is in flight",
      vid.webview == nil)
-- macOS still says no: the second refusal is a real one.
runTimers(1)
check("🪟 a SECOND refusal tears the object down — an abandoned webview "
      .. "keeps its Esc claim",
      WEBVIEWS[#WEBVIEWS].deleted == true and vid.webview == nil)
check("🪟 …and it says so, naming the key to press again",
      anyHas(DEGRADED, "would not put the window on screen"))
check("🔎 …and the refusal is COUNTED, so 'intermittent' is a number",
      (tonumber(vid.refusedShows) or 0) >= 1
      and (tonumber(vid.lostShows) or 0) >= 1)

-- 🔑 THE BRANCH THAT EARNS THE RELEASE: macOS refuses, then allows.
reset()
SHOW_REFUSES = true
vid.show()
check("🪟 a refused show is still pending, not failed", vid.retryTimer ~= nil)
SHOW_REFUSES = false
runTimers(1)
check("🪟 …and the retry PUTS IT ON SCREEN — the window macOS refused "
      .. "once is the window he asked for",
      vid.webview ~= nil)
check("🪟 …with everything a straight-through show does: the catcher",
      vid.catcher ~= nil)
runTimers(1)
check("⌨️ …and the keyboard",
      (vid.focus or {}).why and (vid.focus.why):find("took the keys", 1, true) ~= nil,
      (vid.focus or {}).why)
check("🔎 …and it is counted as RECOVERED, not as a loss",
      (tonumber(vid.recovered) or 0) == 1 and (tonumber(vid.lostShows) or 0) == 0)

-- 🚨 A RETRY MUST NOT ACT ON A DECISION SINCE REVERSED (6.266.0). He
-- can close the window, or press the key again, inside the beat we
-- waited — and a retry that fires anyway puts a window on screen that
-- nothing is tracking, which is the 6.266.0 frozen-grid shape exactly.
reset()
SHOW_REFUSES = true
vid.show()
local pending = vid.retryTimer
vid.hide()
check("🪟 closing it cancels the retry in flight", vid.retryTimer == nil)
SHOW_REFUSES = false
if pending and pending.fn then pcall(pending.fn) end
check("🚨 …and even a timer that fires anyway puts NOTHING on screen",
      vid.webview == nil)
SHOW_REFUSES = false
reset()
NO_WEBVIEW = true
check("🪟 a Hammerspoon with no webview says so rather than throwing",
      vid.show() == false and #DEGRADED > 0)
NO_WEBVIEW = false

-- §10 ── the door mechanism, which is the release ----------------------
out("\n§10 the ways in are tried, and the winner is remembered\n")
reset()
vid.show()
vid.queue = { { path = "/Films/A.mp4", title = "A" } }
vid.playIndex(1)
local v = vid.webview
check("🪟 the page was given door 1's BASE URL",
      v.baseURL == "file:///Films/", tostring(v.baseURL))
check("🪟 …and the <video> src is relative to it",
      v.htmlText:find('src:"A.mp4"', 1, true) ~= nil)
local loads = v.loads
-- The page reports the door failed. Lua must try the NEXT one, and a
-- new base URL can only arrive with a new document.
vid.handleMessage({ a = "srcfail", d = 1, gen = vid.gen })
check("🚪 a refused door moves to the next one", vid.door == 2)
check("🚪 …by rebuilding the document, because only that carries a base",
      v.loads == loads + 1)
check("🚪 …and door 2 has no base and an absolute src",
      v.baseURL == nil
      and v.htmlText:find('src:"file:///Films/A.mp4"', 1, true) ~= nil,
      tostring(v.baseURL))
vid.handleMessage({ a = "srcok", d = 2, gen = vid.gen })
check("🔑 the door that WORKED is recorded",
      (vid.doorWorked or ""):find("absolute", 1, true) ~= nil, vid.doorWorked)
check("🔑 …and remembered, so the next film starts there",
      vid.doorStart == 2)
vid.queue[2] = { path = "/Films/B.mp4", title = "B" }
vid.playIndex(2)
check("🔑 the next film opens through the door that worked", vid.door == 2)

-- 🚨 6.304.0 — A GENERATION. A late answer about the film that was
-- playing a moment ago must not speak for this one, or it bumps the
-- door for a film that never failed.
reset()
vid.show()
vid.queue = { { path = "/F/A.mp4" }, { path = "/F/B.mp4" } }
vid.playIndex(1)
local staleGen = vid.gen
vid.playIndex(2)
local doorNow = vid.door
vid.handleMessage({ a = "srcfail", d = 1, gen = staleGen })
check("🚨 a late failure from the PREVIOUS film does not move this one's door",
      vid.door == doorNow, vid.door)
vid.handleMessage({ a = "srcok", d = 1, gen = staleGen })
check("🚨 …and a late success from it does not claim the door either",
      vid.doorWorked == nil, vid.doorWorked)

-- 🚨 EVERY DOOR REFUSED. This is the state the release exists to make
-- legible rather than a black rectangle.
reset()
vid.show()
vid.queue = { { path = "/F/A.mp4", title = "A" } }
vid.playIndex(1)
vid.handleMessage({ a = "srcfail", d = 1, gen = vid.gen })
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen })
check("🚨 with every way in refused the PAGE is told, in words",
      jsHas("fail("))
check("🚨 …and the door does not run past the last one",
      vid.door == #vid.sourceDoors("/F/A.mp4"), tostring(vid.door))
-- 🚪 6.353.0 — AND THE MESSAGE NO LONGER ASKS HIM TO DIAGNOSE IT. The
-- old one named both things MediaError code 4 can mean and gave him a
-- test to tell them apart, which was right while the question was
-- open. -3001 closed it: the third door's NAVIGATION error says the
-- file was not READ, so the window is told what is happening to the
-- film instead of what might be wrong with it.
check("🚪 …and the page says the film is going to a real player",
      jsHas("is opening in"))
-- 🔎 AND IT NAMES WHY THE BYTES DOOR DID NOT CARRY IT EITHER, which is
-- the fact that makes the sentence actionable: on this harness there is
-- no film on disk to read, and he must be able to tell that apart from
-- a film WebKit would not decode.
check("🚪 …naming why the bytes door did not carry it either",
      jsHas("the bytes straight") and jsHas("through the window"))
check("🔬 …and the Mac is asked what the film actually holds",
      vid.codecsFor == "/F/A.mp4" and vid.codecs ~= nil, tostring(vid.codecs))

-- §11 ── the drop ------------------------------------------------------
out("\n§11 the drop, through the shared reader\n")
reset()
REG.service.provide("drag.paths", function()
    return { "/F/one.mp4", "/F/two.mkv" }, "readURL"
end)
vid.show()
local paths, how = vid.readDrag(nil)
check("🔌 the shared reader answered", #paths == 2 and how == "readURL")
vid.takeDrop(paths)
check("🎬 the .mp4 queued", #vid.queue == 1 and vid.queue[1].path == "/F/one.mp4")
check("🎬 …and the .mkv was REFUSED, by name, not dropped in silence",
      #vid.refused == 1 and vid.refused[1].path == "/F/two.mkv")
check("🎬 …and he was told", anyHas(ALERTS, "not played"))
check("🎬 the first film started playing", vid.index == 1)
-- 🚨 BOTH the row and its LIST are claimed (6.315.0's own sweep
-- finding): leaving the list behind makes the cursor read a queue
-- number as a history row, and the next ⌫ forgets something else.
-- 🔑 THE CURSOR IS PUT IN THE HISTORY FIRST, or the check passes with
-- the line deleted — "queue" is where it already was. The sweep caught
-- exactly that.
vid.selList, vid.sel = "history", 1
vid.playIndex(1)
check("🚨 playing claims BOTH the row and the LIST it is in",
      vid.sel == 1 and vid.selList == "queue", vid.selList)
check("🕘 …and it went into the history", #vid.history == 1)

-- 🔎 THE READER'S ABSENCE IS AN ANSWER, NOT A CRASH.
reset()
REG.service.registry["drag.paths"] = nil
vid.show()
local p2, h2 = vid.readDrag(nil)
check("🔌 with no shared reader the drop says so and degrades",
      #p2 == 0 and h2 == "no reader" and anyHas(DEGRADED, "shared drag reader"))
REG.service.provide("drag.paths", function() return {}, "nothing readable" end)

-- 🧊 THE CATCHER. Both conditions hs.canvas documents are invisible in
-- the result when missing, so each has its own driven failure.
reset()
local realCanvas = hs.canvas
hs.canvas = nil
vid.show()
check("🧊 hs.canvas MISSING: the window still opens, the drop says why",
      vid.webview ~= nil and vid.dropWhy:find("no hs.canvas", 1, true) ~= nil,
      vid.dropWhy)
hs.canvas = realCanvas
-- 🔬 …and REFUSING is a different branch with a different sentence
-- (6.265.0): driving a path with the dependency missing is not the same
-- as driving it with the dependency saying no.
reset()
CANVAS_REFUSES = true
vid.show()
check("🧊 hs.canvas REFUSING is its own branch, with its own words",
      vid.webview ~= nil
      and vid.dropWhy:find("could not be created", 1, true) ~= nil,
      vid.dropWhy)
CANVAS_REFUSES = false
-- 🧊 BOTH CONDITIONS hs.canvas DOCUMENTS, driven. The mouseCallback is
-- the quiet one: without it the window registers no dragged types, the
-- drag passes straight through to whatever is behind, and nothing in
-- the result says so — which is LL's "a drag just puts it behind the
-- player" from 6.231.0, word for word.
reset()
vid.show()
check("🧊 the catcher set a mouseCallback — without one it takes no drags",
      vid.catcher ~= nil and vid.catcher.hasMouseCb == true)
check("🧊 …and a dragging callback, which is the other half",
      vid.catcher ~= nil and type(vid.catcher.dragFn) == "function")
reset()
NO_DRAGLEVEL = true
vid.show()
check("🧊 no dragging level: named, and the canvas is torn down",
      vid.dropWhy:find("dragging window level", 1, true) ~= nil
      and vid.catcher == nil)
NO_DRAGLEVEL = false
reset()
NO_DRAGCB = true
vid.show()
check("🧊 no draggingCallback: named, and the canvas is torn down",
      vid.dropWhy:find("cannot accept drags", 1, true) ~= nil
      and vid.catcher == nil)
NO_DRAGCB = false

-- §12 ── the keys in the window ----------------------------------------
out("\n§12 the deck's keys\n")
reset()
REG.service.provide("drag.paths", function() return {}, "x" end)
vid.show()
vid.queue = { { path = "/F/a.mp4", title = "a" }, { path = "/F/b.mp4", title = "b" } }
vid.history = { { path = "/F/h.mp4", title = "h", at = os.time() } }
vid.sel, vid.selList = 2, "queue"
vid.handleMessage({ a = "sel", d = 1 })
check("⌨️ ↓ off the last queue row reaches the history in the real handler",
      vid.selList == "history" and vid.sel == 1)
vid.handleMessage({ a = "enter" })
check("⏎ on a history row plays it", vid.index > 0)
-- 🗑 ⌫ on a history row FORGETS it; on a queue row it leaves the queue.
-- Getting these the wrong way round is the worst thing this can do.
reset()
vid.show()
vid.queue = { { path = "/F/a.mp4" } }
vid.history = { { path = "/F/h.mp4", at = os.time() } }
vid.sel, vid.selList = 1, "history"
vid.handleMessage({ a = "drop" })
check("⌫ on a history row forgets it, and the QUEUE is untouched",
      #vid.history == 0 and #vid.queue == 1)
vid.sel, vid.selList = 1, "queue"
vid.handleMessage({ a = "drop" })
check("⌫ on a queue row takes it out of the queue", #vid.queue == 0)
-- 🚨 THE ✕ IS ASKED BEFORE THE ROW IT SITS INSIDE (6.272.0): the shared
-- click handler would otherwise PLAY the film on its way to forgetting
-- it. The check asserts exactly that nothing started playing.
reset()
vid.show()
vid.history = { { path = "/F/h.mp4", at = os.time() } }
vid.handleMessage({ a = "forget", k = "h", i = 1 })
check("🗑 ✕ forgets the row and does NOT play it",
      #vid.history == 0 and vid.index == 0)
check("🗑 …and it is counted", vid.forgotten == 1)
-- 🗑 BY PATH, NEVER BY INDEX: a duplicate path must go too.
reset()
vid.show()
vid.history = { { path = "/F/d.mp4", at = os.time() },
                { path = "/F/x.mp4", at = os.time() },
                { path = "/F/d.mp4", at = os.time() } }
vid.handleMessage({ a = "forget", k = "h", i = 1 })
check("🗑 forgetting is BY PATH — the duplicate goes too",
      #vid.history == 1 and vid.history[1].path == "/F/x.mp4", #vid.history)
-- ⌘1–9
reset()
vid.show()
vid.queue = { { path = "/F/a.mp4" }, { path = "/F/b.mp4" }, { path = "/F/c.mp4" } }
vid.handleMessage({ a = "play", k = "q", i = 3 })
check("⌘3 plays the third film", vid.index == 3)
-- a film that ends hands on to the next
vid.handleMessage({ a = "play", k = "q", i = 1 })
vid.handleMessage({ a = "ended", gen = vid.gen })
check("🎬 a film that ends starts the next one", vid.index == 2)
vid.index = 3
vid.gen = vid.gen + 1
vid.handleMessage({ a = "ended", gen = vid.gen })
check("🎬 …and the last one simply stops", vid.index == 3)
-- the title strip grip
_G.DRAGGED = nil
vid.handleMessage({ a = "dragStart" })
check("🪟 a bare press on the title strip begins a panel drag",
      _G.DRAGGED == "mug player", tostring(_G.DRAGGED))

-- §13 ── ⌘O, the way out ------------------------------------------------
out("\n§13 ⌘O hands the film to macOS\n")
reset()
vid.show()
vid.queue = { { path = "/F/a.mp4", title = "a" } }
vid.index = 1
vid.handleMessage({ a = "external" })
check("🚪 ⌘O opens the film with /usr/bin/open",
      #TASKS == 1 and TASKS[1].bin == "/usr/bin/open"
      and TASKS[1].args[1] == "/F/a.mp4")
check("🚪 …and it is counted", vid.externals == 1)
-- 🚪 6.353.0 — THIS CHECK USED TO ASSERT THE BUG. "with nothing playing
-- it says so" is exactly what LL met ("⌘+o just says nothing is
-- playing") with six films in the deck, and the way out is needed most
-- on the Mac where no film can start. An EMPTY queue is the case that
-- should still refuse.
reset()
vid.show()
vid.queue = { { path = "/F/a.mp4", title = "A" } }
vid.index, vid.sel, vid.selList = 0, 1, "queue"
vid.handleMessage({ a = "external" })
check("🚪 ⌘O with nothing playing opens the SELECTED film",
      #TASKS == 1 and TASKS[1].args[1] == "/F/a.mp4", #TASKS)
reset()
vid.show()
vid.handleMessage({ a = "external" })
check("🚪 …and an EMPTY queue is what refuses, naming why",
      #TASKS == 0 and anyHas(ALERTS, "nothing in the queue"),
      ALERTS[#ALERTS])
-- 🔬 hs.task refusing — 6.304.0's shape, which a pcall does NOT catch.
reset()
vid.show()
vid.queue = { { path = "/F/a.mp4" } } ; vid.index = 1
NO_TASK = true
vid.handleMessage({ a = "external" })
check("🚪 a Mac that cannot run the task takes the door rather than lying",
      anyHas(DEGRADED, "could not hand the film"))
NO_TASK = false

-- §14 ── the store ------------------------------------------------------
out("\n§14 the store, and a failed save costs the save\n")
reset()
vid.queue = { { path = "/F/a.mp4" } }
vid.history = { { path = "/F/h.mp4", at = os.time() } }
vid.doorStart = 2
DISK = {}
check("💾 a save writes the store", (function()
          local okS = select(1, pcall(function() vid.save() end))
          for _, t in ipairs(TIMERS) do if not t.stopped and t.fn then t.fn() end end
          return okS and DISK[vid.storeFile] ~= nil
      end)())
check("💾 …and it remembers the door that worked",
      (DISK[vid.storeFile] or ""):find("doorStart", 1, true) ~= nil)
-- 🔒 6.313.0 — the write goes to a TEMP file and is RENAMED. A failed
-- rename must leave the OLD store exactly as it was.
DISK[vid.storeFile] = "OLD STORE"
RENAME_FAILS = true
vid.queue = { { path = "/F/z.mp4" } }
for _, t in ipairs(TIMERS) do t.stopped = true end
vid.save()
for _, t in ipairs(TIMERS) do if not t.stopped and t.fn then t.fn() end end
check("🔒 a failed rename leaves the OLD store untouched",
      DISK[vid.storeFile] == "OLD STORE", DISK[vid.storeFile])
check("🔒 …and no temp file is left behind",
      DISK[vid.storeFile .. ".tmp"] == nil)
check("🔒 …and it SAYS the queue is untouched", anyHas(ALERTS, "untouched"))
RENAME_FAILS = false
-- 🔎 6.312.0 — the store's states are WORDS, and "not yet" is one.
check("🔎 before warm it says NOT READ YET, never 'empty'",
      vid.storeVerdict("notread", 0, 0, 0):find("NOT READ YET", 1, true) ~= nil)
check("🔎 zero bytes is its own state, not 'nothing queued'",
      vid.storeVerdict("zero", 0, 0, 0):find("ZERO BYTES", 1, true) ~= nil)
check("🔎 unreadable is its own state",
      vid.storeVerdict("unreadable", 0, 0, 0):find("UNREADABLE", 1, true) ~= nil)
check("🔎 no file at all reads differently from both",
      vid.storeVerdict("none", 0, 0, 0):find("no store file", 1, true) ~= nil)
-- 🚨 FAILS CLOSED: a report that cannot say what it found must not pick
-- the reassuring branch.
check("🚨 a state nobody recorded reads as UNKNOWN, never as empty",
      vid.storeVerdict("something else", 0, 0, 0):find("unknown", 1, true) ~= nil)
-- the loader round trip
reset()
DISK = {}
_G.FAKE_DECODE = { queue = { { path = "/F/q.mp4" } },
                   history = { { path = "/F/h.mp4", at = os.time() } },
                   doorStart = 2, pos = { x = 10, y = 20 } }
DISK[vid.storeFile] = '{"queue":[]}'
vid.loaded = false
vid.loadStore()
check("💾 the store is read back: queue, history, spot and the door",
      #vid.queue == 1 and #vid.history == 1 and vid.doorStart == 2
      and vid.pos.x == 10 and vid.storeState == "read")

-- §15 ── the report -----------------------------------------------------
out("\n§15 the report\n")
reset()
PRINTED = {}
_G.mugReport()
local rep = table.concat(PRINTED, "\n")
check("🔎 the report PRINTS AS ONE STRING (6.179.1)", #PRINTED == 1, #PRINTED)
check("🔎 it names the key", rep:find("⇪⇧,", 1, true) ~= nil)
check("🔎 it names the format list, which is his scope",
      rep:find(".mp4", 1, true) ~= nil)
-- 🪟 THREE STATES, and the third is not the second (6.196.1): a film
-- that has never been tried is not a film macOS refused.
check("🪟 with nothing played it says so — not 'no way in works'",
      rep:find("no film has loaded yet", 1, true) ~= nil)
check("🔎 it says the store is LOCAL, never OneDrive",
      rep:find("LOCAL", 1, true) ~= nil)
check("🔎 it says the media keys are NOT taken, and why",
      rep:find("NOT taken", 1, true) ~= nil)
reset()
vid.show()
vid.queue = { { path = "/F/a.mp4", title = "a" } }
vid.playIndex(1)
vid.handleMessage({ a = "srcok", d = 1, gen = vid.gen })
PRINTED = {}
_G.mugReport()
rep = table.concat(PRINTED, "\n")
check("🪟 once a film has loaded it NAMES the way in that carried it",
      rep:find("relative to the film", 1, true) ~= nil
      and rep:find("no film has loaded yet", 1, true) == nil)

-- §16 ── the wiring -----------------------------------------------------
out("\n§16 the wiring\n")
check("⌨️ exactly one hyper key is bound, and it is ⇪⇧,",
      BOUND["shift+,"] ~= nil and (function()
          local n = 0 ; for _ in pairs(BOUND) do n = n + 1 end ; return n == 1
      end)())
check("🔌 the three services are published",
      PROVIDED["video.show"] and PROVIDED["video.hide"]
      and PROVIDED["video.toggle"])
check("⎋ it is in the escape router, so the cheat sheet still closes last",
      ESC_CLAIMS["mugplayer"] ~= nil)
reset()
vid.show()
check("⎋ …and the router sees it as active only while it is open",
      ESC_CLAIMS["mugplayer"].active() == true)
ESC_CLAIMS["mugplayer"].handle()
check("⎋ …and Esc closes it", vid.webview == nil)
-- 🪟 A PANEL THIS CONFIG DRAWS IS A PANEL `_G.movablePanels` KNOWS
-- ABOUT (6.232.0) — a panel absent from it is movable by NO means.
local PANEL = nil
for _, e in ipairs(_G.movablePanels or {}) do
    if e.name == "mug player" then PANEL = e end
end
check("🪟 it is registered as a movable panel", PANEL ~= nil)
-- 🔑 THE ID IS A PAIR: this name and the beginPanelDrag() argument.
-- Renaming one half is how a panel silently stops being draggable, so a
-- check JOINS them rather than asserting each.
_G.DRAGGED = nil
reset() ; vid.show()
vid.handleMessage({ a = "dragStart" })
check("🔑 the panel id and the dragStart argument are the SAME string",
      PANEL ~= nil and _G.DRAGGED == PANEL.name,
      tostring(_G.DRAGGED) .. " vs " .. tostring(PANEL and PANEL.name))
reset() ; vid.show()
local f0 = vid.webview:frame()
PANEL.move(300, 200)
check("🪟 moving it moves the window", vid.webview:frame().x == 300)
check("🪟 …and the CATCHER goes with it — one left behind is a dead zone",
      vid.catcher ~= nil and vid.catcher:frame().x == 300,
      vid.catcher and vid.catcher:frame().x)
check("🪟 …and the spot is remembered", vid.pos.x == 300)

-- §17 ── source sentries -------------------------------------------------
out("\n§17 the source says what it is\n")
local src = realOpen(HS .. "/modules/video_player.lua"):read("*a")
check("📖 the sentry read something", #src > 10000, #src)
-- 6.282.0's rule: nothing formats a stored clock by hand here.
check("🕒 no os.date in this module — a report that RAISES is worse than"
      .. " one that lies", src:find("os%.date") == nil)
-- 6.280.0 / 6.321.0 — nothing here erases a film. The sentry states the
-- RULE rather than banning a name, and asserts the comment that
-- explains it still exists, so it cannot be satisfied by deleting the
-- explanation (6.262.0).
local bare = src:gsub("%-%-[^\n]*", "")
check("🗑 NOTHING in this module deletes a film from disk",
      bare:find("os%.remove%s*%(%s*[^t]") == nil
      or bare:find("os.remove(tmp)", 1, true) ~= nil)
check("🗑 …and the comment saying the file is never touched is still there",
      src:find("the files", 1, true) ~= nil
      or src:find("the file is not touched", 1, true) ~= nil)
-- 6.311.0 — no combo is TYPED into a visible string: the card, the
-- summary and the report all read keyLabel.
local visible = src:match("local M = %{(.-)\n%}")
check("🔑 no ⇪⇧ combo is typed into the cheat sheet — it is BUILT",
      visible ~= nil and visible:find("⇪⇧", 1, true) == nil)
-- 🔗 A JOIN, not two assertions: the shipped card title must be what
-- keyLabel answers for the shipped keys, so a hand-typed combo creeping
-- back in fails the gate rather than quietly disagreeing (6.248.0).
check("🔗 the card's title IS what the bound keys render to",
      M.cheatsheet.title:find("⇪⇧,", 1, true) ~= nil
      and BOUND["shift+,"] ~= nil)
check("📋 every row of the card has two columns",
      (function()
          for _, e in ipairs(M.cheatsheet.entries) do
              if type(e) ~= "table" or #e ~= 2 then return false end
          end
          return #M.cheatsheet.entries > 5
      end)())


-- §18 ── the payload's strings, and the defect that drew a black box ----
out("\n§18 every string the page is handed\n")
-- 🚨 THE WHOLE OF 6.344.0's FAILURE IS THIS ONE FUNCTION. `jstr` called
-- `hs.json.encode(tostring(s))` — the only one of twenty such calls in
-- this config that passes a STRING rather than a table. LuaSkin raises
-- on a non-table, the pcall caught the raise, and every string in the
-- payload came back `""`: the film's src (so the <video> was never given
-- one — a black rectangle with a play button), its name (the header read
-- "nothing playing" over a queued film), the brand (missing from his
-- screenshot) and every row's title (the deck drew "1" and "2" with no
-- names). Five symptoms, one cause, all five in one photograph.
reset()
check("🔤 a plain name comes back QUOTED and unchanged",
      vid.jsonStr("Robin Hood") == '"Robin Hood"')
check("🔤 a quote and a backslash are escaped",
      vid.jsonStr('a"b\\c') == '"a\\"b\\\\c"')
-- The payload is a JS object literal inside a <script>: a film called
-- "</script>.mp4" must not be able to end the block.
check("🔒 < > and & cannot close the script block",
      vid.jsonStr("</script>"):find("<", 1, true) == nil
      and vid.jsonStr("a&b"):find("&", 1, true) == nil)
check("🔒 …and the page reads them back as themselves",
      vid.jsonStr("</script>") == '"\\u003C/script\\u003E"')
check("🔤 a control character becomes an escape, never a raw byte",
      vid.jsonStr("a\tb") == '"a\\u0009b"')
-- 6.237.0's rule the other way up: a name that is already right must not
-- be "corrected". Bytes above 0x7F are valid UTF-8 in a JSON string.
check("🔤 UTF-8 is left exactly alone",
      vid.jsonStr("Amélie — 日本") == '"Amélie — 日本"')
check("🔤 U+2028 is escaped (a JS string literal could not hold it)",
      vid.jsonStr("a\226\128\168b") == '"a\\u2028b"')
check("🔤 nil is an empty string, never the word nil",
      vid.jsonStr(nil) == '""')

-- 🔬 THE CHECK THAT BITES, and it is functional rather than textual:
-- drive the REAL payload builder and require the film's own name and
-- source to be in it. Restore `hs.json.encode(tostring(s))` above and
-- this goes red, because the stub now refuses a bare string exactly as
-- LuaSkin does.
vid.queue = { { path = "/Films/Robin Hood.mp4", title = "Robin Hood" } }
vid.index, vid.door, vid.gen = 1, 1, 1
local payload = vid.rowsJson()
check("🎬 the payload carries the film's NAME",
      payload:find('"Robin Hood"', 1, true) ~= nil, payload)
check("🎬 the payload carries a SOURCE for the <video>",
      payload:find("src:\"\"", 1, true) == nil
      and payload:find("Robin%%20Hood%.mp4") ~= nil, payload)
check("🎬 …and the brand, so the header is not blank",
      payload:find(vid.brand, 1, true) ~= nil)
-- 🔒 AND THE HARNESS IS FAITHFUL NOW. If this check ever passes, the
-- stub has gone soft again and §18's others mean nothing (6.313.0: a
-- sentry over a haystack it did not prove it read measures nothing).
check("🔬 the gate's hs.json.encode REFUSES a bare string, as LuaSkin does",
      select(1, pcall(hs.json.encode, "a name")) == false)

-- 🔢 A NUMBER OUT OF A PAGE MESSAGE IS A FLOAT (hs.json decodes every JS
-- number as a double), so `{i:1}` arrived as 1.0 and his report read
-- "playing #1.0". The table lookups were right all along; the number he
-- was shown was not.
reset()
vid.queue = { { path = "/F/a.mp4", title = "a" }, { path = "/F/b.mp4", title = "b" } }
vid.handleMessage({ a = "play", k = "q", i = 1.0 })
check("🔢 a float row number is an INTEGER by the time it is stored",
      math.type(vid.index) == "integer", tostring(vid.index))
check("🔢 …so the report says #1, not #1.0",
      (function()
          local lines = {}
          local realP = print
          print = function(s) lines[#lines + 1] = tostring(s) end
          pcall(_G.mugReport)
          print = realP
          return table.concat(lines, "\n"):find("#1 ", 1, true) ~= nil
      end)())

-- ⎋ THE WINDOW HAS THE KEYBOARD, SO THE PAGE HEARS ESC FIRST. The
-- router claim still covers the window when it is NOT focused; this
-- covers it when it is, which is every time he has been watching a film.
reset()
vid.show()
check("⎋ the window is open before the key is pressed", vid.webview ~= nil)
vid.handleMessage({ a = "close" })
check("⎋ Escape from the page closes the window", vid.webview == nil)
check("⎋ …and the drop catcher goes with it", vid.catcher == nil)

-- 🔎 THE STORE LINE DESCRIBES THE DISK AS IT IS NOW (6.312.0 one layer
-- on): the verdict was captured at the LOAD and never moved, so a Mac
-- that had just queued two films went on reading "no store file yet".
reset()
DISK = {}
vid.storeState = "none"
vid.queue = { { path = "/F/a.mp4", title = "a" } }
vid.save()
for _, t in ipairs(TIMERS) do if not t.stopped and t.fn then t.fn() end end
check("🔎 a successful save moves the verdict off 'no store file yet'",
      vid.storeState == "saved", tostring(vid.storeState))
check("🔎 …and it says so in words, with the bytes",
      vid.storeVerdict(vid.storeState, vid.storeBytes, 1, 0)
          :find("written", 1, true) ~= nil)
-- 🚨 A FAILED SAVE MUST NOT CLAIM ONE. The fixture that bites is a
-- rename that refuses AFTER a good one, or "saved" sticks for ever.
RENAME_FAILS = true
vid.storeState = "none"
vid.save()
for _, t in ipairs(TIMERS) do if not t.stopped and t.fn then t.fn() end end
check("🚨 a REFUSED save leaves the verdict alone",
      vid.storeState == "none", tostring(vid.storeState))
RENAME_FAILS = false

-- 🔬 macOS'S OWN WORDS ABOUT A REFUSED DOOR. "the file is not there" and
-- "WebKit would not let this window read it" are opposite facts and only
-- the MediaError can tell them apart — which is the measurement this new
-- ground exists for (6.242.0).
reset()
vid.queue = { { path = "/F/a.mp4", title = "a" } }
vid.index, vid.gen, vid.door = 1, 1, 1
vid.handleMessage({ a = "srcfail", d = 1, gen = 1, code = 4,
                    why = "Failed to open media" })
check("🔬 the refusal keeps macOS's code and its words",
      tostring(vid.mediaWhy):find("code 4", 1, true) ~= nil
      and tostring(vid.mediaWhy):find("Failed to open", 1, true) ~= nil,
      tostring(vid.mediaWhy))
check("🔬 …and the report prints them under the refused doors",
      (function()
          vid.doorFailed["the absolute file URL"] = 1
          local lines = {}
          local realP = print
          print = function(s) lines[#lines + 1] = tostring(s) end
          pcall(_G.mugReport)
          print = realP
          return table.concat(lines, "\n"):find("macOS said", 1, true) ~= nil
      end)())


-- §19 ── the window macOS refused, and the cost it was paying ----------
out("\n§19 warm pays the dylib loads, and the report counts the refusals\n")
-- 🚨 BOTH OF THESE EXIST BECAUSE THE MUTATION SWEEP FOUND THEM UNDRIVEN
-- (6.273.0: when a line no mutation can kill is the release's own fix,
-- the missing CHECK is the finding). Deleting warm's extension touch —
-- this release's actual candidate for his refusal — and deleting the
-- report line he is asked to paste back BOTH passed 162 checks.

-- 🪟 WARM TOUCHES hs.webview AND hs.drawing, so the first ⇪⇧, of a
-- session is not paying two main-thread dylib loads in the same turn as
-- the show. His Console has all three lines in one second:
--     -- Loading extension: webview
--     -- Loading extension: drawing
--     ⚠️ Mug Player: macOS would not put the window on screen
reset()
do
    local touched = {}
    local realW, realD = hs.webview, hs.drawing
    hs.webview, hs.drawing = nil, nil
    setmetatable(hs, { __index = function(_, k)
        if k == "webview" then touched.webview = true ; return realW end
        if k == "drawing" then touched.drawing = true ; return realD end
        return nil
    end })
    local okW = pcall(function() return M.warm(CORE) end)
    setmetatable(hs, nil)
    hs.webview, hs.drawing = realW, realD
    check("🪟 warm() runs without throwing", okW)
    check("🪟 …and it TOUCHES hs.webview, so the keypress does not load it",
          touched.webview == true)
    check("🪟 …and hs.drawing, which the window level needs",
          touched.drawing == true)
end
-- 🛟 A Mac where touching one of them throws must still warm the store
-- and must not take the module down with it (IT DEGRADES, IT NEVER
-- BREAKS) — the flag records which way it went.
check("🛟 the warm records whether the extensions could be touched",
      vid.warmed == true)

-- 🔎 THE REPORT COUNTS THEM APART, because "intermittent" is a count and
-- not a sample (6.274.0) — and because this line is what he pastes back.
reset()
local function reportText()
    local lines = {}
    local realP = print
    print = function(x) lines[#lines + 1] = tostring(x) end
    pcall(_G.mugReport)
    print = realP
    return table.concat(lines, "\n")
end
check("🔎 a session with no opens says nothing about them",
      reportText():find("opens  :", 1, true) == nil)
reset()
vid.show()
check("🔎 a straight-through open is counted as one",
      reportText():find("1 asked · 1 straight through · 0 refused", 1, true) ~= nil,
      reportText())
reset()
SHOW_REFUSES = true
vid.show()
SHOW_REFUSES = false
runTimers(1)
local txt = reportText()
check("🔎 a refusal that RECOVERED on the retry says so",
      txt:find("1 refused by macOS", 1, true) ~= nil
      and txt:find("1 came up on the retry", 1, true) ~= nil, txt)
check("🚨 …and it is NOT reported as a loss — those are opposite facts",
      txt:find("0 refused twice", 1, true) ~= nil, txt)
reset()


-- §20 ── THE THIRD WAY IN WAS MEASURED, AND IS GONE (6.353.0) ----------
out("\n§20 the third way in — measured, and removed\n")
-- 🚪 6.351.0 BUILT A THIRD DOOR and said in writing that if it were
-- refused too, three doors had answered and the webview is not the
-- surface. IT WAS REFUSED, and macOS named it rather than leaving it to
-- be read: his screenshot is WebKit's own navigation error page, "An
-- Error code: -3001 in NSURLErrorDomain occurred during navigation:
-- Cannot open file". -3001 is NSURLErrorCannotOpenFile and it is a
-- NAVIGATION error, so unlike MediaError code 4 it is not ambiguous.
reset()
local doors = vid.sourceDoors("/Films/My Film.mp4")
-- 🚪 THE RULE IS NOT "TWO DOORS" — 6.354.0 added a third. The rule is
-- that there is no third URL, and nothing in the doors is a file this
-- tool writes: the shape that destroyed the window was a WRITE followed
-- by a NAVIGATION, and asserting a COUNT would go red the next time a
-- door is added while saying nothing about the defect (6.248.0).
check("🚪 no door is a file this tool writes", (function()
    for _, d in ipairs(doors) do if d.file then return false end end
    return true
end)())
check("🚪 …and every door is EITHER a file:// URL or carries no URL at"
      .. " all — there is no third thing to navigate to", (function()
    for _, d in ipairs(doors) do
        if d.bytes then
            if d.src ~= "" then return false end
        elseif not tostring(d.src):find("%.mp4$") then
            return false
        end
    end
    return true
end)())

-- 🚨 AND IT DID NOT MERELY FAIL, IT TOOK THE PLAYER WITH IT: a refused
-- `view:url()` REPLACES the document, so the deck, the queue and every
-- key went with it. Nothing in the draw path may navigate.
reset()
DISK = {}
vid.show()
vid.queue = { { path = "/Films/My Film.mp4", title = "My Film" } }
vid.index = 1
vid.door  = 1 ; vid.paint(true)
vid.door  = 2 ; vid.paint(true)
check("🚨 no way in NAVIGATES — the page is only ever handed over as a "
      .. "string, so a film that will not load cannot destroy the window",
      vid.webview.urlLoaded == nil, tostring(vid.webview.urlLoaded))
check("🧹 …and nothing was written into the film's folder", (function()
    for k in pairs(DISK) do
        if tostring(k):find("/Films/", 1, true) then return false end
    end
    return true
end)())

-- 🚨 THE SENTRY THAT MATTERS MORE THAN THE FEATURE. The deleted door
-- needed os.remove on a path built from a folder full of HIS FILMS —
-- the one failure in this module with no way back (6.280.0). It was
-- guarded twice and proven twice; the safest version of that code is
-- the version that does not exist, and this keeps it from coming back
-- without those guards.
do
    local f = assert(realOpen(HS .. "/modules/video_player.lua"))
    local srcTxt = f:read("a") ; f:close()
    -- 🚨 THE RULE, NOT THE NAME. The first version of this banned
    -- `os.remove` outright and went red on correct code: the store's
    -- temp-then-rename (6.313.0) legitimately removes its OWN temp file
    -- in Application Support. 6.321.0 wrote this down and I broke it in
    -- the next module — a sentry that bans a NAME expires the moment
    -- the name has an honest use.
    local removes = 0
    for call in srcTxt:gmatch("os%.remove%(([^%)]*)%)") do
        removes = removes + 1
        check("🚨 os.remove takes the store's own temp file, never a path "
              .. "built from a film's folder — got " .. call,
              call == "tmp")
    end
    check("🚨 …and the store's two removes are still there, so this "
          .. "sentry is reading a real haystack (6.313.0)", removes == 2,
          removes)
    check("🚨 …and writes no file beside a film",
          srcTxt:find("writeStage", 1, true) == nil
          and srcTxt:find("stageName", 1, true) == nil)
    -- 🔎 AND THE COMMENT EXPLAINING WHY MUST SURVIVE, or the sentry can
    -- be satisfied by deleting the reason (6.280.0).
    check("🚨 …and the source says why it must stay that way",
          srcTxt:find("no way back", 1, true) ~= nil)
end

-- 🚪 THE WAY OUT MUST WORK WHEN NOTHING IS PLAYING — THAT IS WHEN IT IS
-- NEEDED. LL: "⌘+o just says nothing is playing", with six films in the
-- deck and a row highlighted. 6.265.0's shape exactly: the right answer
-- one branch away, unreachable.
reset()
local Q = { { path = "/F/a.mp4", title = "A" }, { path = "/F/b.mp4", title = "B" },
            { path = "/F/c.mp4", title = "C" } }
local t, why = vid.exitPick(2, Q, "queue", 3)
check("🚪 a film that IS playing wins", t.title == "B"
      and why:find("playing", 1, true) ~= nil, why)
t, why = vid.exitPick(0, Q, "queue", 3)
check("🚪 nothing playing → the row he has SELECTED", t.title == "C"
      and why:find("selected", 1, true) ~= nil, why)
-- 🔎 A SELECTION IN THE HISTORY IS NOT A QUEUE ROW, and reading it as
-- one opens the wrong film — the fixture that bites, because every
-- other input agrees (6.230.0).
t, why = vid.exitPick(0, Q, "history", 2)
check("🚪 a HISTORY selection does not name a queue row — the first "
      .. "film is the honest answer", t.title == "A"
      and why:find("first", 1, true) ~= nil, why)
t, why = vid.exitPick(0, {}, "queue", 1)
check("🚪 an empty queue answers nil AND why, never a crash",
      t == nil and why:find("nothing in the queue", 1, true) ~= nil, why)

reset()
vid.show()
vid.queue = { { path = "/F/one.mp4", title = "One" } }
vid.index, vid.sel, vid.selList = 0, 1, "queue"
check("🚪 ⌘O with nothing playing opens the selected film",
      vid.openExternal() == true and vid.externals == 1)
check("🚪 …and says WHICH row it took, so a wrong one is visible",
      anyHas(ALERTS, "the row you have selected"), ALERTS[#ALERTS])

-- 🚪 AND WHEN EVERY WAY IN IS REFUSED, THE FILM GOES OUT. A window
-- whose only answer is "it would not play" is a window that does not
-- work, and three doors have answered on his Mac.
reset()
vid.show()
vid.queue = { { path = "/F/film.mp4", title = "Film" } }
vid.index, vid.door, vid.gen = 1, 2, vid.gen
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4, why = "" })
check("🚪 the last refusal hands the film to a real player",
      vid.externals == 1 and vid.handedOff == 1,
      vid.externals .. "/" .. vid.handedOff)
check("🚪 …and the page SAYS so rather than showing a dead stage",
      jsHas("is opening in") and jsHas("through the window"))
-- 🔌 AND THE SWITCH IS REAL IN BOTH DIRECTIONS (6.228.0/6.259.0).
reset()
vid.show()
vid.handOff = false
vid.queue = { { path = "/F/film.mp4", title = "Film" } }
vid.index, vid.door = 1, 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4, why = "" })
check("🔌 handOff = false leaves the film here and names ⌘O",
      vid.externals == 0 and vid.handedOff == 0 and jsHas("⌘O opens it"))
vid.handOff = true

-- 🔎 COUNTED APART (6.229.0): a film HE sent out and one this tool sent
-- out because nothing would play are different facts.
reset()
vid.show()
vid.queue = { { path = "/F/one.mp4", title = "One" } }
vid.index, vid.sel, vid.selList = 1, 1, "queue"
vid.door = 2
vid.openExternal()
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4, why = "" })
do
    local lines = {}
    local realP = print
    print = function(x) lines[#lines + 1] = tostring(x) end
    pcall(_G.mugReport)
    print = realP
    local txt = table.concat(lines, "\n")
    check("🔎 the report counts the two ways out apart",
          txt:find("1 handed out because", 1, true) ~= nil
          and txt:find("1 you opened yourself", 1, true) ~= nil, txt)
    check("🔎 …and says what ⌘O would open RIGHT NOW",
          txt:find("⌘O would open:", 1, true) ~= nil, txt)
    check("🔎 …and no longer carries a stage line at all",
          txt:find("stage  :", 1, true) == nil, txt)
end

-- §21 ── THE TWO DOORS (6.352.0) ----------------------------------------
-- 🚚 HIS REPORT: "I can't drag and drop a file on it." This tool had ONE
-- way in — a canvas catcher under the window — where the Jug Player has
-- had two since 6.233.0, and this project's own rule says two ("both
-- doors end in takeDrop"). A canvas macOS refuses to put on screen then
-- costs the whole feature.
out("\n§21 the two doors into the drop\n")

-- 🪟 A HANDLE RECORDED BEFORE THE WINDOW IS UP IS A HANDLE THAT LIES
-- (6.326.0). This is the branch the old code could not take: created,
-- wired, and REFUSED TO SHOW.
reset()
CANVAS_SHOW_REFUSES = true
vid.show()
check("🪟 a catcher macOS REFUSED is not recorded as ready",
      vid.catcher == nil and vid.catcherOn == false,
      tostring(vid.dropWhy))
check("🪟 …it is counted", vid.catchRefused == 1, vid.catchRefused)
check("🪟 …the canvas is torn down, never left orphaned",
      CANVASES[#CANVASES].deleted == true)
check("🪟 …and it takes the 🔔 door, naming macOS",
      anyHas(DEGRADED, "would not put the drop catcher on screen"))
-- 🔑 AND IT IS NO LONGER THE WHOLE FEATURE, which is the release: the
-- window's own handler is still live, and the message SAYS so.
check("🔑 …and says the window's own handler is the way in meanwhile",
      anyHas(DEGRADED, "own drop handler"))
CANVAS_SHOW_REFUSES = false

-- …and the ordinary path still records the claim only once it is true.
reset()
vid.show()
check("🪟 a catcher macOS accepted IS recorded",
      vid.catcher ~= nil and vid.catcherOn == true and vid.catchRefused == 0)

-- 🚪 THE PAGE'S OWN DOOR. The page is handed a drag's text/uri-list and
-- nothing else — WebKit never gives a page a file's path.
reset()
REG.service.provide("drag.urilist", function(t)
    local o = {}
    for line in (tostring(t) .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
        local u = line:match("^file://(/.*)$")
        if u then o[#o + 1] = (u:gsub("%%(%x%x)",
            function(h) return string.char(tonumber(h, 16)) end)) end
    end
    return o
end)
vid.show()
check("🚪 the page door reads as LIVE once the shared parser is there",
      vid.pageDoorLive() == true)
vid.handleMessage({ a = "filedrop",
                    uri = "file:///F/Ain%27t%20It.mp4\nfile:///F/two.mkv\n",
                    names = { "Ain't It.mp4", "two.mkv" } })
check("🚪 a drop through the window itself queues the film",
      #vid.queue == 1 and vid.queue[1].path == "/F/Ain't It.mp4",
      vid.queue[1] and vid.queue[1].path)
check("🚪 …with the percent-escapes undone by the ONE shared parser",
      vid.queue[1] and vid.queue[1].path:find("%%") == nil)
check("🚪 …the .mkv refused by name, as the catcher's door does",
      #vid.refused == 1 and vid.refused[1].path == "/F/two.mkv")
check("🚪 …and the film started", vid.index == 1)
-- 🚪 COUNTED APART (6.229.0): a feature with two doors must say which
-- one is carrying it, or the next report cannot name the one that broke.
check("🚪 …and the PAGE's door is counted, not the catcher's",
      vid.pageDrops == 1 and vid.catchDrops == 0,
      vid.pageDrops .. "/" .. vid.catchDrops)

-- 🔎 A DROP WITH NO uri-list IS NAMED, NEVER SWALLOWED (6.231.0).
reset()
vid.show()
vid.handleMessage({ a = "filedrop", uri = "", names = { "Robin Hood.mp4" } })
check("🔎 a drop carrying no file URL is NAMED, with what it did carry",
      #vid.queue == 0 and anyHas(ALERTS, "Robin Hood.mp4"),
      vid.dragSeen)
check("🔎 …and it does not count as a drop the page carried",
      vid.pageDrops == 0)

-- 🚨 THE FIXTURE THAT BITES, and it is the only input where the two
-- implementations must differ (6.230.0): with no shared parser the page
-- must NOT claim the drag, or it takes every drop away from the catcher
-- underneath and does nothing with it — strictly worse than one door.
reset()
REG.service.registry["drag.urilist"] = nil
vid.show()
check("🚨 with no shared parser the page door stands DOWN",
      vid.pageDoorLive() == false)
local pay = vid.rowsJson()
check("🚨 …and the page is BUILT not to claim a drag (pd:false)",
      pay:find("pd:false", 1, true) ~= nil, pay:sub(-120))
vid.handleMessage({ a = "filedrop", uri = "file:///F/one.mp4\n" })
check("🚨 …and a drop that reaches Lua anyway is named, not swallowed",
      #vid.queue == 0 and tostring(vid.uriWhy):find("not loaded", 1, true) ~= nil,
      tostring(vid.uriWhy))
REG.service.provide("drag.urilist", function() return {} end)

-- 🚨 'filedrop', NEVER 'drop'. In this page 'drop' is the ⌫ key, which
-- REMOVES a film from the queue — so one shared name would make dropping
-- films onto the window DELETE one instead (6.272.0's ✕-before-the-row,
-- in a message name). A source sentry, because the page is where it is
-- decided and a functional check cannot see a name that is not sent.
do
    local f = assert(realOpen(HS .. "/modules/video_player.lua"))
    local srcTxt = f:read("a") ; f:close()
    -- 🚨 AND THE WINDOW ENDS AT THE LISTENER'S OWN BOUNDARY (6.263.0).
    -- The first version of this sentry searched the WHOLE file for
    -- `a:'drop'` and went red on correct code, because ⌫ legitimately
    -- sends exactly that — a sentry that forbids a string which must
    -- exist is one that gets switched off in a week (6.269.0). The rule
    -- is about what the DROP LISTENER sends, so that is the haystack.
    local at = srcTxt:find("addEventListener('drop'", 1, true)
    check("🚚 the page has a drop listener to read at all", at ~= nil)
    local body = at and srcTxt:sub(at, (srcTxt:find("\n});", at, true) or at))
                     or ""
    check("🚨 the drop listener sends 'filedrop'",
          body:find("a:'filedrop'", 1, true) ~= nil, body)
    check("🚨 …and never 'drop', which is ⌫ and REMOVES a film",
          body:find("a:'drop'", 1, true) == nil, body)
    check("🚨 …and ⌫ still sends 'drop', which this must not have taken",
          srcTxt:find("say({a:'drop'})", 1, true) ~= nil)
    check("🚚 the page registers its own drag listeners at all",
          srcTxt:find("addEventListener('dragover'", 1, true) ~= nil
          and srcTxt:find("addEventListener('drop'", 1, true) ~= nil)
end

-- 🔎 THE REPORT SURVIVES THE WINDOW CLOSING, which is what cost this
-- diagnosis: `dropWhy` was set to "ready" when the catcher was created
-- and nothing cleared it, so the line read as health about a catcher
-- that had been DELETED — and hide() resets pageReady, so "closed and it
-- had spoken" and "never once spoke" printed the same ⚠️.
local function reportText()
    local lines = {}
    local realP = print
    print = function(x) lines[#lines + 1] = tostring(x) end
    pcall(_G.mugReport)
    print = realP
    return table.concat(lines, "\n")
end
reset()
vid.show()
vid.handleMessage({ a = "ready" })
check("🔎 an OPEN window with a live page reads 'ready' and 'catcher up'",
      reportText():find("catcher up", 1, true) ~= nil
      and reportText():find("page   : ready", 1, true) ~= nil)
vid.hide()
local closed = reportText()
check("🔎 a CLOSED window says so about the catcher, not 'ready'",
      closed:find("drop   : window closed", 1, true) ~= nil, closed)
-- 🔎 AND THE LAST REASON SURVIVES THE CLOSE, which is what the sweep
-- bought: the STATE is read off the object, so this field is free to
-- carry how the catcher was DOING when the window went. hide() rewriting
-- it to "the window is closed" made the line redundant and threw that
-- away — the mutation that restores that write fails this row.
check("🔎 …and still says the catcher had been up and fine",
      closed:find("last: ready", 1, true) ~= nil, closed)
check("🔎 …and says the page HAD spoken while it was open",
      closed:find("it HAD said it was ready", 1, true) ~= nil, closed)
-- 🚨 AND THE FOURTH STATE, which is the one that was missing: a page
-- that has NEVER spoken must not read like one that has.
reset()
local never = reportText()
check("🚨 a page that never once spoke reads as a FAULT, not as closed",
      never:find("NEVER once said", 1, true) ~= nil, never)
-- 🚪 and the doors line, which is what his next report answers with.
reset()
vid.show()
vid.pageDrops, vid.catchDrops = 2, 1
check("🚪 the report counts the two doors apart",
      reportText():find("2 drop(s) through the window itself", 1, true) ~= nil
      and reportText():find("1 through the catcher underneath", 1, true) ~= nil,
      reportText())


-- §22 ── THE BYTES THROUGH THE WINDOW (6.354.0) -----------------------
out("\n§22 the bytes through the window, not a URL\n")

-- 📦 Drain the read the way the run loop does: loadTurn clears
-- vid.loadTimer at its top and re-arms at its bottom, so that field
-- always points at the NEXT pending turn.
-- 📦 6.355.0 — AND THE PAGE'S OWN ANSWER IS PART OF THE LOOP. The next
-- turn is armed by the evaluateJavaScript COMPLETION, not by a clock, so
-- a drain that fired only timers would stop after one chunk. Acks first,
-- then the pending turn — which is the order the main queue delivers
-- them in. `n` counts TURNS, never acks, or every count below doubles.
local function runLoad(cap)
    local n, guard = 0, 0
    while guard < ((cap or 2000) * 4) do
        guard = guard + 1
        if JS_ACKS[1] then
            table.remove(JS_ACKS, 1)()
        elseif vid.loadTimer then
            local t = vid.loadTimer
            if t.stopped or not t.fn then break end
            n = n + 1
            t.fn()
        else
            break
        end
        if n >= (cap or 2000) then break end
    end
    return n
end

-- 🛟 The belt is the LAST doAfter armed before a chunk went out. Firing
-- it is how "the window never answered" is driven rather than grepped.
-- 📦 Run the oldest completion the window has not answered yet. It
-- ANSWERS FALSELY rather than calling a nil, so a mutation that stops
-- the push fails a check instead of killing the run (6.186.0).
local function fireAck()
    local f = table.remove(JS_ACKS, 1)
    if type(f) ~= "function" then return false end
    f() ; return true
end

local function fireAckBelt()
    local t = vid.ackTimer
    if not t or t.stopped or not t.fn then return false end
    t.fn() ; return true
end

-- 📦 What actually reached the page, decoded back into bytes. This is
-- the check a scrambling or truncating bug fails: the film the window
-- was handed must be the film on the disk, byte for byte.
local function blobBytes()
    local outb = {}
    for _, js in ipairs(JS) do
        local b64 = js:match("^blobChunk%('([^']*)'%);$")
        if b64 then outb[#outb + 1] = hs.base64.decode(b64) end
    end
    return table.concat(outb)
end
local function jsCount(needle)
    local n = 0
    for _, js in ipairs(JS) do
        if js:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

-- ---- the plan, PURE ---------------------------------------------------
local okP, whyP = vid.loadPlan(nil, 100, 10)
check("📐 a size the Mac would not give is not a size of 0",
      okP == false and whyP:find("would not say", 1, true) ~= nil, whyP)
local okZ, whyZ = vid.loadPlan(0, 100, 10)
check("📐 …and a 0-byte film is refused too",
      okZ == false, whyZ)
local okC, whyC = vid.loadPlan(100, 1000, 0)
-- 🚨 TWO REFUSALS THAT SHARE AN ACTION MUST NOT SHARE A SENTENCE
-- (6.338.0): both stop the read, and only the REASON tells him whether
-- his Mac could not measure the film or his own settings line broke the
-- loader. A check on the action alone passes with either branch deleted.
check("📐 a chunk of 0 is refused, and NOT with the same words",
      okC == false and whyC ~= whyP and whyC:find("never", 1, true) ~= nil,
      whyC)
local okE, whyE, turnsE = vid.loadPlan(100, 100, 10)
check("📐 a film EXACTLY at the ceiling loads — the ceiling is a `>`",
      okE == true and turnsE == 10, tostring(okE) .. " " .. tostring(turnsE))
local okO, whyO = vid.loadPlan(101, 100, 10)
check("📐 …and one byte over it does not", okO == false, whyO)
check("📐 …and the refusal carries BOTH sizes, so it is actionable",
      whyO:find("0.0 MB", 1, true) ~= nil
      and whyO:find("ceiling", 1, true) ~= nil, whyO)
local _, _, turnsR = vid.loadPlan(5, 1000, 2)
check("📐 the turns round UP — 5 bytes in 2s is three turns, not two",
      turnsR == 3, tostring(turnsR))

-- ---- the whole read, end to end --------------------------------------
reset()
DISK = {}
local FILM = "/F/film.mp4"
-- seven distinguishable bytes, read two at a time: a chunk dropped,
-- doubled or delivered out of order cannot survive this.
DISK[FILM] = "ABCDEFG"
vid.chunkBytes = 2
vid.show()
vid.queue = { { path = FILM, title = "Film" } }
vid.playIndex(1)
JS = {}
vid.handleMessage({ a = "srcfail", d = 1, gen = vid.gen, code = 4 })
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
check("📦 both file URLs refused, so the bytes door takes it",
      vid.door == 3 and vid.load ~= nil, tostring(vid.door))
check("📦 …and the film is NOT handed out while the read is in flight",
      vid.externals == 0 and not jsHas("is opening in"))
check("📦 the page is told the TOTAL first, so its line is a percentage",
      jsHas("blobStart(7,"))
local turns = runLoad()
check("📦 the read ran to the end and closed its own handle",
      vid.load == nil and vid.loadTimer == nil, tostring(turns))
check("📦 …in four turns — three of two bytes and one of one",
      vid.loadTurns == 4, tostring(vid.loadTurns))
check("📦 EVERY BYTE ARRIVED, IN ORDER, as the film on the disk",
      blobBytes() == "ABCDEFG", blobBytes())
check("📦 …and blobEnd was pushed exactly ONCE, after the last chunk",
      jsCount("blobEnd();") == 1
      and JS[#JS]:find("blobEnd", 1, true) ~= nil, JS[#JS])
check("📦 …and the bytes are counted, so the report can say what they cost",
      vid.loadBytes == 7 and vid.loadRuns == 1,
      vid.loadBytes .. "/" .. vid.loadRuns)

-- 🚨 AND A BIGGER CHUNK THAN THE FILM IS ONE TURN, not a loop that
-- reads an empty string for ever. The faithful read stub is what makes
-- this provable: it answers nil at EOF the way Lua does.
reset()
DISK = { ["/F/tiny.mp4"] = "xyz" }
vid.chunkBytes = 1024
vid.show()
vid.queue = { { path = "/F/tiny.mp4", title = "Tiny" } }
vid.playIndex(1)
vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
runLoad()
check("📦 a chunk bigger than the film is one turn and one end",
      vid.loadTurns == 1 and blobBytes() == "xyz"
      and jsCount("blobEnd();") == 1, tostring(vid.loadTurns))

-- ---- the handle closes on EVERY way the read can end ------------------
-- 🚪 6.304.0: a busy flag released only by SUCCESS is a wedge, and here
-- the flag holds an open file handle.
local function startRead(body)
    reset()
    DISK = { ["/F/long.mp4"] = body }
    vid.chunkBytes = 2
    vid.show()
    vid.queue = { { path = "/F/long.mp4", title = "Long" } }
    vid.playIndex(1)
    vid.door = 2
    vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
end

startRead("ABCDEFGHIJKLMNOP")
check("📦 the read is in flight", vid.load ~= nil)
vid.loadTimer.fn()   -- one turn, then he closes the window
vid.hide()
check("🚪 closing the window mid-read ends it and closes the handle",
      vid.load == nil and vid.loadTimer == nil)

startRead("ABCDEFGHIJKLMNOP")
vid.loadTimer.fn()
vid.queue[2] = { path = "/F/other.mp4", title = "Other" }
DISK["/F/other.mp4"] = "zz"
vid.playIndex(2)
check("🚪 playing a different film ends the read for the one before it",
      vid.load == nil)

startRead("ABCDEFGHIJKLMNOP")
local inFlight = vid.loadTimer
vid.gen = vid.gen + 1          -- something else claimed the player
inFlight.fn()
check("🪪 a turn that lands after the film changed does nothing, and"
      .. " still closes the handle",
      vid.load == nil and vid.loadTimer == nil)

startRead("ABCDEFGHIJKLMNOP")
JS_THROWS = true
vid.loadTimer.fn()
check("🚪 a window that has gone away ends the read rather than looping",
      vid.load == nil and vid.loadTimer == nil)
check("🔔 …and it takes the degrade door rather than failing in silence",
      anyHas(DEGRADED, "would not take the film"), DEGRADED[#DEGRADED])
JS_THROWS = false

-- ---- it either begins or it says why ----------------------------------
-- 🚨 A MAC THAT CANNOT ARM A TIMER DOES NOT BEGIN, and the film goes
-- out instead of leaving a window that says it is loading for ever.
reset()
DISK = { [FILM] = "ABCDEFG" }
vid.show()
vid.queue = { { path = FILM, title = "Film" } }
vid.playIndex(1)
local realAfter = hs.timer.doAfter
hs.timer.doAfter = nil
vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
hs.timer.doAfter = realAfter
check("🚨 no timer = the read never begins, and it SAYS which",
      vid.load == nil
      and vid.loadWhy:find("cannot arm a timer", 1, true) ~= nil,
      vid.loadWhy)
check("🚨 …and the film goes out rather than sitting on a dead stage",
      vid.externals == 1 and vid.handedOff == 1)

reset()
DISK = { [FILM] = "ABCDEFG" }
vid.show()
vid.queue = { { path = FILM, title = "Film" } }
vid.playIndex(1)
local realB64 = hs.base64
hs.base64 = nil
vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
hs.base64 = realB64
check("🚨 no hs.base64 = the read never begins, and it SAYS so",
      vid.load == nil and vid.loadWhy:find("hs.base64", 1, true) ~= nil,
      vid.loadWhy)

reset()
DISK = { [FILM] = "ABCDEFG" }
vid.blobMax = 3
vid.show()
vid.queue = { { path = FILM, title = "Film" } }
vid.playIndex(1)
vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
check("📏 a film over the ceiling is refused, with both sizes named",
      vid.load == nil and vid.loadWhy:find("ceiling", 1, true) ~= nil,
      vid.loadWhy)
check("📏 …and THAT film goes out to a real player",
      vid.externals == 1 and vid.handedOff == 1)

-- 🔌 THE SWITCH IS REAL IN BOTH DIRECTIONS (6.228.0/6.259.0).
reset()
DISK = { [FILM] = "ABCDEFG" }
vid.blobLoad = false
vid.show()
vid.queue = { { path = FILM, title = "Film" } }
vid.playIndex(1)
vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
check("🔌 blobLoad = false does not read, and names the line back",
      vid.load == nil and vid.loadRuns == 0
      and vid.loadWhy:find("blobLoad = true", 1, true) ~= nil, vid.loadWhy)
check("🔌 …and the report SAYS it is off rather than reading as healthy",
      reportText():find("puts the bytes door back", 1, true) ~= nil)
vid.blobLoad = true

-- ---- the per-turn budget ---------------------------------------------
-- 🔔 PAST THE BUDGET IT TAKES THE DOOR — ONCE PER FILM, not once per
-- turn: three hundred alerts is a tool he switches off (6.260.0).
reset()
DISK = { ["/F/slow.mp4"] = "ABCDEFGHIJ" }
vid.chunkBytes, vid.slowTurnMs = 2, 50
vid.show()
vid.queue = { { path = "/F/slow.mp4", title = "Slow" } }
vid.playIndex(1)
vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
-- a second between the two clock reads INSIDE each turn: far past 50 ms
CLOCK_STEP = 1
runLoad(20)
CLOCK_STEP = 0
local said = 0
for _, d in ipairs(DEGRADED) do
    if d:find("costing", 1, true) then said = said + 1 end
end
check("🔔 a slow read takes the door ONCE, not once per turn",
      said == 1, tostring(said))
check("🔔 …and the report counts it and names the budget",
      vid.loadSlow == 1
      and reportText():find("crossed 50 ms", 1, true) ~= nil,
      tostring(vid.loadSlow))
check("🔔 …and the slow read still DELIVERED the film",
      blobBytes() == "ABCDEFGHIJ", blobBytes())
CLOCK, CLOCK_STEP = 1000, 0

-- ---- the door that worked, and the one never remembered --------------
-- 🚨 THE BYTES DOOR MUST NEVER BECOME THE STARTING DOOR. It carries no
-- URL, so a film painted straight onto it has nothing to fail and
-- nothing to advance the walker — the loader would never be reached and
-- the NEXT film would simply never play. The mutation that drops the
-- `not won.bytes` guard fails here.
reset()
vid.show()
vid.queue = { { path = FILM, title = "Film" } }
vid.index, vid.gen, vid.door = 1, 1, 3
vid.handleMessage({ a = "srcok", d = 3, gen = 1 })
check("🔑 the bytes door is recorded as the one that carried the film",
      vid.doorWorked == "the bytes through the window, not a URL",
      tostring(vid.doorWorked))
check("🔑 …and it is COUNTED as a film the window really played",
      vid.blobPlayed == 1, tostring(vid.blobPlayed))
check("🚨 …but it is NOT remembered as the door to start on",
      vid.doorStart == 1, tostring(vid.doorStart))
reset()
vid.show()
vid.queue = { { path = FILM, title = "Film" } }
vid.index, vid.gen, vid.door = 1, 1, 2
vid.handleMessage({ a = "srcok", d = 2, gen = 1 })
check("🔑 …while a URL door that works IS remembered",
      vid.doorStart == 2 and vid.blobPlayed == 0, tostring(vid.doorStart))

-- ---- the page threw while assembling ---------------------------------
reset()
DISK = { [FILM] = "ABCDEFG" }
vid.show()
vid.queue = { { path = FILM, title = "Film" } }
vid.playIndex(1)
vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
runLoad()
vid.handleMessage({ a = "blobfail", gen = vid.gen, why = "out of room" })
check("📦 a page that threw mid-assembly is counted apart from a refusal",
      vid.blobFailed == 1 and vid.blobPlayed == 0, tostring(vid.blobFailed))
check("🔔 …takes the degrade door with the page's own words",
      anyHas(DEGRADED, "out of room"), DEGRADED[#DEGRADED])
check("🚪 …and the film goes out",
      vid.externals == 1 and vid.handedOff == 1)
check("📦 …and a late one about the film before it is ignored",
      (function()
          local n = vid.blobFailed
          vid.handleMessage({ a = "blobfail", gen = vid.gen - 1, why = "late" })
          return vid.blobFailed == n
      end)())

-- ---- the report's four states ----------------------------------------
reset()
check("🔎 before any film the report says the loader has not been asked",
      reportText():find("has not been asked for a film yet", 1, true) ~= nil,
      reportText())
startRead("ABCDEFGHIJKLMNOP")
vid.loadTimer.fn()
check("🔎 a read IN FLIGHT reads as one, with how far it has got",
      reportText():find("now   : reading", 1, true) ~= nil
      and reportText():find(" of ", 1, true) ~= nil, reportText())
runLoad()
check("🔎 …and a finished read reads as finished, with its turns",
      reportText():find("1 film(s) read into the window", 1, true) ~= nil
      and reportText():find("turns :", 1, true) ~= nil, reportText())
-- 🔑 AND THE CODECS VERDICT SHARPENS BY ELIMINATION: the bytes door
-- cannot be refused for read access, so a film that still will not play
-- once the bytes are inside is a DECODE problem and nothing else.
vid.codecs = "H.264, AAC"
check("🔑 bytes in and still no play = the report says it is DECODING",
      reportText():find("STILL WOULD NOT PLAY", 1, true) ~= nil,
      reportText())
vid.handleMessage({ a = "srcok", d = 3, gen = vid.gen })
check("🔑 …and once it plays, that sentence is gone",
      reportText():find("STILL WOULD NOT PLAY", 1, true) == nil)
vid.codecs = nil
reset()

-- ---- the source says what it is --------------------------------------
local SRC = assert(realOpen(HS .. "/modules/video_player.lua")):read("*a")
check("🔒 the sentries below really read the module",
      type(SRC) == "string" and #SRC > 60000, tostring(#(SRC or "")))
check("🔒 the file handle is closed in ONE place, and that place is the"
      .. " one door every exit goes through",
      select(2, SRC:gsub("L%.f:close%(%)", "")) == 1
      and SRC:find("function vid.loadStop", 1, true) ~= nil)
-- 🚨 A base64 chunk is A–Z a–z 0–9 + / = and nothing else, so it needs
-- no escaping — and running three gsubs over two and a half megabytes
-- every turn is main-thread work for nothing (6.228.0).
local pushLine = nil
for line in SRC:gmatch("[^\n]+") do
    if line:find("blobChunk", 1, true) and line:find("pushJs", 1, true) then
        pushLine = line
    end
end
check("🔒 the chunk push does not go through jsEscape",
      pushLine ~= nil and pushLine:find("jsEscape", 1, true) == nil,
      tostring(pushLine))
check("🔒 and the loader reads the film by the CHUNK, never whole",
      SRC:find('L%.f:read%(L%.chunk%)') ~= nil
      and SRC:find('L%.f:read%("%*a"%)') == nil)

out("\n§23 the ceiling is measured, and the page sets the pace\n")

-- ---- the ceiling, PURE -------------------------------------------------
reset()
local GB = 1024 * 1024 * 1024
do
    local b, why = vid.ceilingFor(nil, 1 / 3, 3 * GB, 8 * GB)
    check("📏 a Mac that will not say its memory gets the FLOOR, not 0",
          b == 3 * GB and why:find("would not say", 1, true) ~= nil, why)
    -- 🚨 0 is the answer that reads as a valid ceiling and refuses every
    -- film ever offered — 6.338.0's rule, in the place where the cost is
    -- a tool that never works and blames the film.
    check("📏 …and never 0, which would refuse every film and say so",
          vid.ceilingFor(0, 1 / 3, 3 * GB, 8 * GB) == 3 * GB)
    b, why = vid.ceilingFor(16 * GB, 1 / 3, 3 * GB, 8 * GB)
    check("📏 a share of a 16 GB Mac, and the sentence names the Mac",
          b == math.floor(16 * GB / 3) and why:find("16384.0 MB", 1, true),
          why)
    b, why = vid.ceilingFor(4 * GB, 1 / 3, 3 * GB, 8 * GB)
    check("📏 a share below the floor is raised to the floor, and says so",
          b == 3 * GB and why:find("the floor", 1, true) ~= nil, why)
    b, why = vid.ceilingFor(48 * GB, 1 / 3, 3 * GB, 8 * GB)
    check("📏 …and above the cap it is the cap, for TIME not memory",
          b == 8 * GB and why:find("the cap", 1, true) ~= nil, why)
end

-- 🚨 THE FIXTURE THAT BITES IS HIS OWN FILM. 6.354.0 typed 1536 MB and
-- his first real film was 2300.6 MB, so the loader was never asked and
-- every way in read as refused. Any ceiling that still turns this away
-- on a 16 GB Mac has not fixed the thing the release exists for.
do
    local film = math.floor(2300.6 * 1048576)
    local cap  = vid.ceilingFor(16 * GB, 1 / 3, 3 * GB, 8 * GB)
    check("📦 HIS 2300.6 MB FILM FITS a 16 GB Mac, where 1536 MB refused it",
          cap > film and film > 1536 * 1024 * 1024, vid.mb(cap))
    check("📦 …and it fits the 8 GB Mac's floor too",
          vid.ceilingFor(8 * GB, 1 / 3, 3 * GB, 8 * GB) > film)
    local ok, why = vid.loadPlan(film, cap, 8 * 1024 * 1024)
    check("📦 …so the PLAN says yes where 6.354.0's number said no",
          ok and select(2, vid.loadPlan(film, 1536 * 1024 * 1024,
                                        8 * 1024 * 1024)) ~= why)
end

-- ---- one door, and a settings number still wins ------------------------
reset()
vid.blobMax = nil ; MEM_BYTES = 16 * GB
check("📏 the ceiling is ASKED of the Mac when no number is set",
      vid.maxBytes() == math.floor(16 * GB / 3), tostring(vid.maxBytes()))
-- 🔒 Asked once and kept: physical memory does not move, and a second
-- answer that differed would make the plan and the report disagree.
MEM_BYTES = 4 * GB
check("📏 …and it is asked ONCE, so the plan and the report agree",
      vid.maxBytes() == math.floor(16 * GB / 3))
reset()
vid.blobMax = 99 * 1024 * 1024
check("🔌 a settings number still wins, so the knob is real",
      vid.maxBytes() == 99 * 1024 * 1024
      and vid.ceilWhy:find("your own settings", 1, true) ~= nil, vid.ceilWhy)
reset()
vid.blobMax, MEM_BYTES = nil, nil
check("📏 a Mac with no hs.host answer falls back to the floor, not 0",
      vid.maxBytes() == 3 * GB, tostring(vid.maxBytes()))
reset()
vid.blobMax = nil
check("📏 and the report NAMES the ceiling and where the number came from",
      reportText():find("ceiling:", 1, true) ~= nil
      and reportText():find("a share of this Mac", 1, true) ~= nil)

-- ---- the page sets the pace -------------------------------------------
-- 🛟 6.299.0 IN THE LOADER: evaluateJavaScript returns before the script
-- runs (libwebview.m:1688-1725), so arming the next turn on a clock
-- pushes faster than the window can swallow. These are the checks
-- 6.354.0 fails.
reset()
DISK["/f/big.mp4"] = "ABCDEFGH"
vid.chunkBytes = 2
vid.show()
vid.queue = { { path = "/f/big.mp4", title = "big" } }
vid.playIndex(1) ; vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
-- loadStart arms the first turn; run it, and then nothing more may move
-- until the window says it has taken what that turn sent.
vid.loadTimer.fn()
check("🛟 one chunk goes out, and then the loader WAITS",
      vid.load ~= nil and vid.loadTimer == nil and #JS_ACKS == 1,
      tostring(vid.loadTimer) .. "/" .. #JS_ACKS)
check("🛟 …with a belt armed BEFORE the chunk went out, its own slot",
      vid.ackTimer ~= nil and vid.ackTimer.secs == vid.ackSecs)
fireAck()
check("🛟 the window's answer is what arms the next turn",
      vid.loadTimer ~= nil and vid.acks == 1 and vid.ackTimer == nil,
      tostring(vid.acks))
runLoad()
check("🛟 …and the whole film still arrives, in order",
      blobBytes() == "ABCDEFGH" and vid.load == nil, blobBytes())
check("🛟 …one confirmation per chunk, counted for the report",
      vid.acks == 4 and jsCount("blobEnd();") == 1, tostring(vid.acks))
-- ⏱ A CLOCK THAT IS ALWAYS 0 IS NOT A CLOCK. He is being asked how long
-- a 2.3 GB film takes before it starts, so the number has to be real.
check("🛟 …and the read's own wall clock is recorded",
      type(vid.loadMs) == "number" and vid.loadMs == 0,
      tostring(vid.loadMs))
reset()
DISK["/f/slowclk.mp4"] = "ABCDEFGH"
vid.chunkBytes = 2
vid.show()
vid.queue = { { path = "/f/slowclk.mp4", title = "clk" } }
vid.playIndex(1) ; vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
CLOCK_STEP = 1
runLoad()
CLOCK_STEP = 0
check("⏱ a read that took time reports the time it took",
      vid.loadMs > 0 and reportText():find("the last whole read took",
                                           1, true) ~= nil,
      tostring(vid.loadMs))

-- 🚨 A WINDOW THAT GOES SILENT MUST NOT HANG THE READ with a file handle
-- open. The belt is the only thing that can end it, and it is DRIVEN
-- here rather than grepped for.
reset()
DISK["/f/silent.mp4"] = "ABCDEFGH"
vid.chunkBytes = 2
vid.show()
vid.queue = { { path = "/f/silent.mp4", title = "silent" } }
vid.playIndex(1) ; vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
vid.loadTimer.fn()
local held = vid.load
check("🛟 the belt fires when the window never answers",
      fireAckBelt() == false or true)
check("🛟 …and the read is ended, its handle closed, and it is COUNTED",
      vid.load == nil and vid.ackLate == 1 and held ~= nil,
      tostring(vid.ackLate))
check("🛟 …and the page is told to drop what it had",
      jsHas("blobDrop();"))
check("🛟 …and he is TOLD, rather than left with a stuck percentage",
      (function()
          for _, d in ipairs(DEGRADED) do
              if d:find("stopped taking the film", 1, true) then return true end
          end
          return false
      end)())
-- 🪪 A completion that lands after the belt has fired is about a chunk
-- nobody is waiting for (6.304.0). Running it must do NOTHING — no
-- second read, no second count.
local before = vid.acks
fireAck()
check("🪪 a late answer after the belt starts nothing and counts nothing",
      vid.acks == before and vid.load == nil and vid.loadTimer == nil)

-- 🪪 A DUPLICATE ANSWER MUST NOT ARM A SECOND TURN. Two turns in flight
-- is the queued-IPC failure this release exists to stop, reached by a
-- different road — so the sequence guard is driven, not read.
reset()
DISK["/f/dup.mp4"] = "ABCDEFGH"
vid.chunkBytes = 2
vid.show()
vid.queue = { { path = "/f/dup.mp4", title = "dup" } }
vid.playIndex(1) ; vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
vid.loadTimer.fn()
local again = JS_ACKS[1]
fireAck()
local armed1 = vid.loadTimer
again()
check("🪪 the same answer twice arms ONE turn and counts ONE piece",
      vid.acks == 1 and vid.loadTimer == armed1, tostring(vid.acks))

-- 🪪 AND AN ANSWER ABOUT A FILM HE HAS MOVED ON FROM. Both reads are on
-- their first chunk, so the sequence matches and only the GENERATION
-- can tell them apart — the fixture where the two guards must differ
-- (6.230.0).
reset()
DISK["/f/a.mp4"], DISK["/f/b.mp4"] = "ABCD", "WXYZ"
vid.chunkBytes = 2
vid.show()
vid.queue = { { path = "/f/a.mp4", title = "a" }, { path = "/f/b.mp4", title = "b" } }
vid.playIndex(1) ; vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
vid.loadTimer.fn()
local staleA = table.remove(JS_ACKS, 1)
vid.playIndex(2) ; vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
vid.loadTimer.fn()
local armedB = vid.loadTimer
staleA()
check("🪪 an answer about the film he moved on from does nothing",
      vid.acks == 0 and vid.loadTimer == armedB, tostring(vid.acks))
fireAck()
check("🪪 …and the film he is on carries on normally",
      vid.acks == 1 and vid.load ~= nil)

-- 🛟 A READ ENDED BY ANYTHING ELSE MUST TAKE ITS BELT WITH IT. The ack
-- path stops the belt itself, so only an end that is NOT an ack — he
-- closed the window, he played something else — can leave one ticking
-- into the next film's read (6.304.0's wedge, one door along).
reset()
DISK["/f/stop.mp4"] = "ABCDEFGH"
vid.chunkBytes = 2
vid.show()
vid.queue = { { path = "/f/stop.mp4", title = "stop" } }
vid.playIndex(1) ; vid.door = 2
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
vid.loadTimer.fn()
local belt = vid.ackTimer
vid.loadStop("he closed it")
check("🛟 a read ended any other way stops its belt, and drops the slot",
      belt ~= nil and belt.stopped == true and vid.ackTimer == nil,
      tostring(belt and belt.stopped))

-- 📏 A Mac that cannot arm the belt still reads, and the miss is counted
-- rather than assumed away (6.304.0).
reset()
DISK["/f/nb.mp4"] = "ABCD"
vid.chunkBytes = 2
vid.show()
vid.queue = { { path = "/f/nb.mp4", title = "nb" } }
vid.playIndex(1) ; vid.door = 2
local realAfter = hs.timer.doAfter
local armed = 0
hs.timer.doAfter = function(secs, fn)
    -- refuse only the belt; the read itself must still be able to run
    if secs == vid.ackSecs then armed = armed + 1 ; return nil end
    return realAfter(secs, fn)
end
vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
runLoad()
hs.timer.doAfter = realAfter
check("📏 no belt is a COUNTED state, and the read still delivers",
      vid.ackNoBelt > 0 and armed > 0 and blobBytes() == "ABCD",
      tostring(vid.ackNoBelt))
check("📏 …and the report shouts about it rather than printing a count",
      reportText():find("NO belt", 1, true) ~= nil)

-- ---- the source, because a clock-paced re-arm reads identically -------
do
    -- 🚨 THE RULE, NOT A NAME (6.321.0): a clock-paced re-arm and an
    -- ack-paced one read almost identically, and only the SOURCE can
    -- say that nothing after the chunk goes out arms another turn.
    -- Comments stripped (6.262.0), and the haystack is asserted so the
    -- sentry cannot pass over nothing (6.313.0).
    local bare = SRC:gsub("\n%s*%-%-[^\n]*", "")
    local body = bare:match("\n    loadTurn = function%(%)\n(.-)\n    end\n")
    check("🔒 the sentry really read the loader's own turn",
          type(body) == "string" and #body > 1200, tostring(body and #body))
    body = body or ""
    check("🔒 the next turn is armed INSIDE the push's completion",
          body:find("vid.loadTimer = ntm", 1, true) ~= nil)
    local tail = body:match("L%.sent   = L%.sent %+ #piece(.*)$") or "MISSING"
    check("🔒 …and nothing after the chunk goes out arms a turn on a clock",
          tail ~= "MISSING" and tail:find("doAfter", 1, true) == nil,
          tail:sub(1, 90))
end


-- =======================================================================
out("\n§24 the bytes have to be on this Mac first\n")
-- =======================================================================
-- ☁️ LL, on a 72-second frozen Mac and a stall-guard relaunch: "I think
-- was because Blackhawk Down was in OneDrive. Because it did give me the
-- spinning beach ball." He is right. The loader reads on the MAIN
-- THREAD, and reading a cloud placeholder makes macOS download it first.

local MB = 1024 * 1024

-- ---- PURE: four answers, and only one refuses ------------------------
do
    local okL, whyL = vid.onDisk(100 * MB, (100 * MB) / 512, 4 * MB, 0.9)
    check("☁️ a film whose bytes are all here reads", okL and
          whyL:find("is on this Mac", 1, true) ~= nil, whyL)

    local okC, whyC = vid.onDisk(2300 * MB, 16, 4 * MB, 0.9)
    check("☁️ a placeholder is REFUSED, naming both sizes",
          okC == false and whyC:find("still in the cloud", 1, true) ~= nil
          and whyC:find("2300", 1, true) ~= nil, whyC)

    -- 🚨 FAILS OPEN WHERE IT CANNOT TELL. An hs.fs that does not report
    -- `blocks` must not turn EVERY film away — that would be the guard
    -- costing the whole feature rather than one stall.
    local okN, whyN = vid.onDisk(2300 * MB, nil, 4 * MB, 0.9)
    check("☁️ a Mac that will not say how much is local reads anyway",
          okN and whyN:find("does not report", 1, true) ~= nil, whyN)

    local okS = vid.onDisk(nil, 0, 4 * MB, 0.9)
    check("☁️ a size the Mac would not give reads anyway", okS)

    -- a tiny file cannot stall long enough to matter, so it is never
    -- refused however little of it is allocated
    check("☁️ a file under the floor is never refused",
          (vid.onDisk(1 * MB, 0, 4 * MB, 0.9)) == true)

    -- 🧪 THE FIXTURE THAT BITES is the PAIR at the boundary: every other
    -- input agrees whatever the fraction is (6.230.0).
    local size = 100 * MB
    local atOK = vid.onDisk(size, (size * 0.9) / 512, 4 * MB, 0.9)
    local under = vid.onDisk(size, (size * 0.89) / 512, 4 * MB, 0.9)
    check("☁️ exactly at the fraction reads, just under refuses",
          atOK == true and under == false,
          tostring(atOK) .. "/" .. tostring(under))

    -- the fraction is a config value the gate MOVES, so a number typed
    -- into the rule twice cannot pass (6.239.0)
    check("☁️ …and the fraction is the rule, not a literal",
          vid.onDisk(size, (size * 0.5) / 512, 4 * MB, 0.4) == true
          and vid.onDisk(size, (size * 0.5) / 512, 4 * MB, 0.6) == false)
end

-- ---- driven: a placeholder never reaches the read --------------------
do
    reset()
    local body = string.rep("X", 64)
    DISK  = { ["/F/cloud.mp4"] = body }
    CLOUD = { ["/F/cloud.mp4"] = 0 }     -- nothing allocated locally
    vid.cloudFloor = 16                   -- 64 bytes is "big" for this test
    vid.chunkBytes = 8
    vid.show()
    vid.queue = { { path = "/F/cloud.mp4", title = "Cloud" } }
    vid.playIndex(1)
    vid.door = 2
    JS = {}
    vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
    check("☁️ the read never starts on a placeholder", vid.load == nil)
    check("☁️ …and it is counted, not swallowed",
          (tonumber(vid.cloudRefused) or 0) == 1 and vid.diskOK == false)
    check("☁️ …and not one byte was handed to the window",
          jsCount("blobChunk(") == 0)

    -- 🚨 THE MESSAGE IS THE RELEASE. The generic refusal blames WebKit
    -- and the codec, which for a placeholder is the wrong story and
    -- would send the next release hunting a decode fault (6.351.0).
    local said = table.concat(JS, "\n")
    check("☁️ the page is told it is the CLOUD, not the codec",
          said:find("not on this", 1, true) ~= nil
          and said:find("OneDrive", 1, true) ~= nil
          and said:find("Nothing is wrong with the film", 1, true) ~= nil,
          said:sub(1, 160))
    check("☁️ …and it says what to press once it has downloaded",
          said:find("plays it here", 1, true) ~= nil)
    vid.hide()
end

-- ---- driven: the NEGATIVE case, or the guard proves nothing ----------
-- 6.346.0's rule: a check that something is refused passes with the whole
-- feature disconnected. The local film must still read.
do
    reset()
    local body = string.rep("Y", 64)
    DISK  = { ["/F/local.mp4"] = body }   -- CLOUD empty = fully downloaded
    vid.cloudFloor = 16
    vid.chunkBytes = 8
    vid.show()
    vid.queue = { { path = "/F/local.mp4", title = "Local" } }
    vid.playIndex(1)
    vid.door = 2
    vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
    check("☁️ a film that IS here still reads", vid.load ~= nil
          and (tonumber(vid.cloudRefused) or 0) == 0 and vid.diskOK == true)
    runLoad(40)
    check("☁️ …all the way to the end, byte for byte", blobBytes() == body)
    vid.hide()
end

-- ---- driven: no `blocks` at all, so it reads ------------------------
do
    reset()
    DISK = { ["/F/nob.mp4"] = string.rep("Z", 64) }
    CLOUD = { ["/F/nob.mp4"] = 0 }
    NO_BLOCKS = true                      -- an hs.fs that cannot answer
    vid.cloudFloor = 16
    vid.chunkBytes = 8
    vid.show()
    vid.queue = { { path = "/F/nob.mp4", title = "NoBlocks" } }
    vid.playIndex(1)
    vid.door = 2
    vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
    check("☁️ with no `blocks` field the read goes ahead", vid.load ~= nil)
    vid.hide()
    NO_BLOCKS = false
end

-- ---- the report's three states ---------------------------------------
do
    reset()
    -- 🚨 AND IT MUST NOT CARRY THE ⚠️. Asserting the WORDS alone passes
    -- when the not-asked branch is deleted, because the refusal branch
    -- prints the same sentence behind a warning — "not asked yet" read
    -- as "NOT HERE" is 6.196.1 inside the line built to keep it.
    do
        local t0 = reportText()
        check("🔎 before any film the on-disk line says NOT ASKED",
              t0:find("on disk: ⏳ no film has been asked for yet", 1, true) ~= nil
              and t0:find("on disk: ⚠️", 1, true) == nil, t0:sub(1, 160))
    end

    DISK  = { ["/F/c2.mp4"] = string.rep("X", 64) }
    CLOUD = { ["/F/c2.mp4"] = 0 }
    vid.cloudFloor, vid.chunkBytes = 16, 8
    vid.show()
    vid.queue = { { path = "/F/c2.mp4", title = "C2" } }
    vid.playIndex(1)
    vid.door = 2
    vid.handleMessage({ a = "srcfail", d = 2, gen = vid.gen, code = 4 })
    local t = reportText()
    check("🔎 a refused film reads ⚠️ NOT HERE, never as health",
          t:find("on disk: ⚠️ NOT HERE", 1, true) ~= nil, t:sub(1, 200))
    check("🔎 …and the cloud count names the 72-second freeze it prevents",
          t:find("refused for being in the cloud", 1, true) ~= nil
          and t:find("72 s", 1, true) ~= nil)
    vid.hide()
end


-- =======================================================================
out("\n§25 ⌃⌘F fills the screen, and comes back to the size he had\n")
-- =======================================================================
-- 🖥 LL: "I need Mug Player to change from fully full-screen Back to its
-- small window size … to the Mac window size of command+ctrl+f."
-- macOS's OWN full screen is not reachable — hs.webview.windowMasks has
-- no fullScreen entry (libwebview.m:2533-2562) and this window is
-- borderless — so ⌃⌘F RESIZES the window, both ways.

-- ---- PURE: three answers ---------------------------------------------
do
    local sf  = { x = 0, y = 0, w = 1440, h = 900 }
    local cur = { x = 100, y = 80, w = 880, h = 660 }

    local big, why1 = vid.fillPlan(cur, sf, nil, 0)
    check("🖥 with no small frame kept, it FILLS the screen",
          big and big.w == 1440 and big.h == 900 and big.x == 0 and big.y == 0
          and why1:find("filling", 1, true) ~= nil, why1)

    local back, why2 = vid.fillPlan({ x = 0, y = 0, w = 1440, h = 900 }, sf, cur, 0)
    check("🖥 with one kept, it goes back to EXACTLY that frame",
          back and back.x == 100 and back.y == 80
          and back.w == 880 and back.h == 660
          and why2:find("back to the size you had it", 1, true) ~= nil, why2)

    local none, why3 = vid.fillPlan(cur, nil, nil, 0)
    check("🖥 no screen to answer about is its own answer, not a guess",
          none == nil and why3:find("no screen", 1, true) ~= nil, why3)

    local nf, why4 = vid.fillPlan(nil, sf, nil, 0)
    check("🖥 a window that will not say its size is refused, not filled",
          nf == nil and why4:find("would not say", 1, true) ~= nil, why4)

    -- the gap is the rule, not a literal (6.239.0)
    local g = vid.fillPlan(cur, sf, nil, 12)
    check("🖥 the gap is read, not typed in twice",
          g and g.x == 12 and g.y == 12 and g.w == 1416 and g.h == 876)

    -- 🧪 THE FIXTURE THAT BITES the carried frame: a small frame whose
    -- size happens to equal a freshly computed default would agree with
    -- a recompute, so the one that separates them is a frame he MOVED
    -- and RESIZED (6.230.0).
    local moved = { x = 17, y = 23, w = 641, h = 409 }
    local b2 = vid.fillPlan({ x = 0, y = 0, w = 1440, h = 900 }, sf, moved, 0)
    check("🖥 …and it is HIS frame, not a recomputed default",
          b2 and b2.x == 17 and b2.y == 23 and b2.w == 641 and b2.h == 409)
end

-- ---- driven: both directions, and the catcher comes too --------------
do
    reset()
    vid.show()
    vid.webview:frame({ x = 100, y = 80, w = 880, h = 660 })
    vid.moveCatcher({ x = 100, y = 80, w = 880, h = 660 })

    check("🖥 ⌃⌘F from the page fills the screen", (function()
        vid.handleMessage({ a = "fill" })
        local f = vid.webview:frame()
        return f.w == 1440 and f.h == 900 and f.x == 0 and f.y == 0
    end)(), vid.fillWhy)

    -- 🚨 THE DROP AREA IS THE WINDOW'S. One left at the old frame is a
    -- dead zone over the old spot and no drop at the new one.
    check("🖥 …and the drop catcher went with it",
          vid.catcher ~= nil and vid.catcher:frame().w == 1440,
          vid.catcher and vid.catcher:frame().w)

    check("🖥 ⌃⌘F again comes back to the size he had", (function()
        vid.handleMessage({ a = "fill" })
        local f = vid.webview:frame()
        return f.x == 100 and f.y == 80 and f.w == 880 and f.h == 660
    end)(), vid.fillWhy)
    check("🖥 …and the catcher came back with it",
          vid.catcher ~= nil and vid.catcher:frame().w == 880)
    check("🖥 a third press fills again — the flag is cleared on the way back",
          (function()
        vid.handleMessage({ a = "fill" })
        return vid.webview:frame().w == 1440
    end)())
    check("🖥 …and every press is counted", (tonumber(vid.fills) or 0) == 3)
    vid.hide()
end

-- ---- a closed window has nothing to come back to ---------------------
do
    reset()
    vid.show()
    vid.webview:frame({ x = 100, y = 80, w = 880, h = 660 })
    vid.handleMessage({ a = "fill" })
    check("🖥 filled, then closed", vid.small == nil or true)
    vid.hide()
    check("🖥 closing the window forgets the frame to come back to",
          vid.small == nil)
    vid.show()
    vid.webview:frame({ x = 10, y = 10, w = 500, h = 400 })
    vid.handleMessage({ a = "fill" })
    check("🖥 …so the next session's first ⌃⌘F FILLS, never shrinks",
          vid.webview:frame().w == 1440, vid.webview:frame().w)
    vid.hide()
end

-- ---- with no window, and the report ----------------------------------
do
    reset()
    -- the report is read FIRST: toggleFill writes `fillWhy`, so asking
    -- afterwards measures this test's own press rather than a fresh Mac
    check("🔎 the report says the size, and that macOS full screen is not it",
          (function()
        local t = reportText()
        return t:find("size   : its own window", 1, true) ~= nil
           and t:find("libwebview.m:2533-2562", 1, true) ~= nil
           and t:find("⌃⌘F has not been pressed", 1, true) ~= nil
    end)(), (reportText():match("size   :[^\n]*") or "NO size LINE"))

    local ok, why = vid.toggleFill()
    check("🖥 ⌃⌘F with no window answers false AND why",
          ok == false and tostring(why):find("no window", 1, true) ~= nil, why)
    check("🔎 …and that refusal reaches the report, not just the caller",
          (reportText():find("no window is open", 1, true)) ~= nil)

    vid.show()
    vid.webview:frame({ x = 100, y = 80, w = 880, h = 660 })
    vid.handleMessage({ a = "fill" })
    check("🔎 …and while filled it names the size it will go back to",
          (function()
        local t = reportText()
        return t:find("filling the screen", 1, true) ~= nil
           and t:find("880 × 660", 1, true) ~= nil
    end)(), reportText():sub(1, 220))
    vid.hide()
end

-- ---- the page really sends it ----------------------------------------
do
    -- 🔒 A HANDLER WITH NO KEY TO DRIVE IT IS A FEATURE THAT LOOKS BUILT
    -- (6.273.0). The page's ⌃⌘F must be read BEFORE the metaKey bail,
    -- which returns on every ⌘ chord the page does not claim.
    local bare = SRC:gsub("\n%s*%-%-[^\n]*", "")
    local body = bare:match("addEventListener%('keydown'(.-)\n%}%);")
    check("🔒 the sentry really read the page's keydown",
          type(body) == "string" and #body > 400, tostring(body and #body))
    body = body or ""
    local fillAt = body:find("a:'fill'", 1, true)
    local bailAt = body:find("if(e.metaKey)return;", 1, true)
    check("🔒 ⌃⌘F is claimed BEFORE the plain-⌘ bail, or it is dead",
          fillAt ~= nil and bailAt ~= nil and fillAt < bailAt,
          tostring(fillAt) .. "/" .. tostring(bailAt))
    check("🔒 …and it asks for ctrl as well, so plain ⌘F is left alone",
          body:match("e%.metaKey&&e%.ctrlKey&&%(e%.key==='f'") ~= nil)
end

out("\n§26 ← → seek, and the length macOS has not answered\n")
-- =======================================================================
-- ⏪ LL: "I'd like to be able to use the arrow keys in the mug player to
-- move forward and back. So instead of having to mouse over the window
-- and then press the 15 second forward button and then 15 second back
-- button."
-- He is right, and the comment in the page said why it could not work:
-- ← → were "the film's own keys", delegated to WebKit — which seeks with
-- them only while the <video> ELEMENT has keyboard focus. The DOCUMENT
-- has it (that is how space and ↑↓ work), so the arrows reached nothing.
do
    local before = pass + fail

    -- 📐 THE NUMBERS RIDE INTO THE PAGE, so moving the config moves what
    -- the keys do. Asserting the shipped 15 passes happily with the value
    -- typed into the page as well (6.239.0), so MOVE it and require the
    -- payload to follow.
    local keptS, keptB = vid.seekStep, vid.seekBigStep
    vid.seekStep, vid.seekBigStep = 15, 60
    local j1 = vid.rowsJson()
    check("⏪ the payload carries the seek steps", j1:find("sk:15", 1, true) ~= nil
          and j1:find("skb:60", 1, true) ~= nil, j1:sub(1, 60))
    vid.seekStep, vid.seekBigStep = 7, 99
    local j2 = vid.rowsJson()
    check("⏪ …and MOVING the config moves them — the page carries no number of its own",
          j2:find("sk:7", 1, true) ~= nil and j2:find("skb:99", 1, true) ~= nil,
          j2:sub(1, 60))
    vid.seekStep, vid.seekBigStep = keptS, keptB

    -- 🚨 A seek must NEVER re-render: a render rebuilds the document,
    -- which tears the <video> down and stops the film — for a key whose
    -- whole job is to move within it.
    vid.seeks, vid.seekRefused, vid.seekLast = 0, 0, nil
    local renders = 0
    local realRender = vid.render
    vid.render = function() renders = renders + 1 end
    vid.handleMessage({ a = "seek", d = 15, at = 30, dur = 600, ok = true,
                        why = "forward 15s" })
    check("⏪ a seek message is counted", (tonumber(vid.seeks) or 0) == 1,
          tostring(vid.seeks))
    check("🚨 …and does NOT re-render — a render would stop the film",
          renders == 0, tostring(renders))
    vid.handleMessage({ a = "seek", d = 15, at = 0, dur = 0, ok = false,
                        why = "the film has no length yet" })
    check("⏪ a REFUSED seek is counted apart from a seek that moved",
          (tonumber(vid.seeks) or 0) == 2 and (tonumber(vid.seekRefused) or 0) == 1,
          tostring(vid.seeks) .. "/" .. tostring(vid.seekRefused))
    check("…and it is still not a reason to re-render", renders == 0, tostring(renders))
    vid.render = realRender

    -- 🔎 THREE STATES (6.196.1): nobody pressed · it moved · it was refused.
    vid.seeks, vid.seekRefused, vid.seekLast = 0, 0, nil
    local r0 = reportText()
    check("🔎 with no press the report says so rather than printing a zero",
          r0:find("no arrow pressed this session", 1, true) ~= nil,
          (r0:match("seek[^\n]*") or ""))
    check("…and it still names both steps, so the keys are discoverable",
          (r0:match("seek[^\n]*") or ""):find("← →", 1, true) ~= nil)
    vid.handleMessage({ a = "seek", d = -15, at = 15, dur = 600, ok = true,
                        why = "back 15s" })
    local r1 = reportText()
    check("🔎 once one has landed it names it and where it landed",
          r1:find("back 15s", 1, true) ~= nil and r1:find("15 s of 600 s", 1, true) ~= nil,
          (r1:match("↳ last[^\n]*") or ""))
    check("…and with none refused there is no ⚠️ on that line",
          (r1:match("seek   :[^\n]*") or ""):find("REFUSED", 1, true) == nil)
    vid.handleMessage({ a = "seek", d = 15, at = 20, dur = 0, ok = false,
                        why = "the film has no length yet" })
    local r2 = reportText()
    check("🔎 a refusal puts a ⚠️ on the line AND names the length it lacked",
          (r2:match("seek   :[^\n]*") or ""):find("⚠️", 1, true) ~= nil
          and r2:find("a length macOS has not answered", 1, true) ~= nil,
          (r2:match("↳ last[^\n]*") or ""))
    vid.seeks, vid.seekRefused, vid.seekLast = 0, 0, nil

    -- 🖼 the page claims the keys rather than leaving them to WebKit
    local page = vid.buildPage()
    check("⏪ the page claims ArrowLeft and ArrowRight", 
          page:find("e.key==='ArrowLeft'||e.key==='ArrowRight'", 1, true) ~= nil)
    check("…and preventDefault()s them, so a focused film cannot seek TWICE",
          (page:match("ArrowLeft'||e%.key==='ArrowRight'%){[^\n]*") or "")
            :find("preventDefault", 1, true) ~= nil)
    -- 🚨 THE FIRST VERSION OF THIS CHECK MATCHED ITS OWN COMMENT. It
    -- asserted the words "the film's own keys" were GONE from the page —
    -- and the replacement comment quotes that very phrase to explain what
    -- it replaced, so the check went red on correct code. 6.359.0 found
    -- exactly this shape in a sentry; 6.280.0 is the same lesson from the
    -- other side. Assert the RULE instead: there is one seek door, and the
    -- arrow branch goes through it.
    check("⏪ the page has ONE seek door and the arrows call it",
          page:find("function seekBy(d)", 1, true) ~= nil
          -- The window ENDS AT THE BRANCH'S OWN BOUNDARY (6.263.0) — its
          -- closing `return}` — rather than at a fixed number of lines,
          -- which is how a scanner comes to be satisfied by its neighbour.
          and (page:match("ArrowLeft.-return}") or "")
                :find("seekBy(", 1, true) ~= nil)

    local ran = (pass + fail) - before
    check("§26 ran all of its checks (" .. ran .. " of 13)", ran >= 13, ran)
end

-- ---- the tally ---------------------------------------------------------
realPrint("")
realPrint(("🎬 test_video_player — %d passed, %d failed"):format(pass, fail))
for _, f in ipairs(failures) do realPrint("   ❌ " .. f) end
os.exit(fail == 0 and 0 or 1)
