-- =====================================================================
-- test_music_player.lua — 6.231.0: ⇪⇧pad. a card you drop music on
-- =====================================================================
--     lua5.4 test_music_player.lua [/path/to/hammerspoon]
--
-- Executes modules/music_player.lua against a stubbed Mac. Everything
-- that DECIDES anything here is pure — what plays, what comes next, what
-- a drop yielded, how long a track has run — so the whole of it is proven
-- with no sound card, no files and no window.
--
-- 🧪 AND THE STUBS ARE AS UNFORGIVING AS macOS, which is this project's
-- most expensive lesson (6.193.0, and four costumes since): hs.sound's
-- end-of-track callback can be made NOT to fire, a file can be made to
-- vanish between the drop and the play, getByFile can refuse, and
-- setContents-style "returns false rather than throwing" refusals are
-- answered rather than raised. A stub gentler than the real provider is
-- a hole with a tick beside it.
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
-- The screens this stub Mac has. §15 changes it.
SCREENS = { { x = 0, y = 0, w = 1440, h = 900 } }

local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
            .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

-- ---- the stub Mac ------------------------------------------------------
local FILES     = {}     -- path → true when the file "is there"
local OPENABLE  = {}     -- path → false when macOS refuses to decode it
local DURATION  = {}     -- path → seconds
local SOUNDS    = {}     -- every hs.sound handed out
local TIMERS    = {}
local ALERTS, PRINTED, DEGRADED = {}, {}, {}
local JS        = {}     -- every script pushed into the page
local WEBVIEWS  = {}
local NO_WEBVIEW, NO_SOUND = false, false
local WRITES    = {}     -- path → the bytes written
local READABLE  = {}     -- path → the bytes a read returns

local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end

-- io.open is stubbed so the store can be proven without touching disk.
local realOpen = io.open
io.open = function(path, mode)
    if (mode or "r"):find("w") then
        return {
            write = function(_, s) WRITES[path] = (WRITES[path] or "") .. s end,
            close = function() READABLE[path] = WRITES[path] end,
        }
    end
    local body = READABLE[path]
    if not body then return nil end
    local done = false
    return {
        read  = function() if done then return nil end done = true return body end,
        close = function() end,
    }
end

hs = {
    timer = {
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, every = false, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, every = true, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    fs = {
        attributes = function(p, what)
            if not FILES[p] then return nil end
            if what == "mode" then return "file" end
            return { mode = "file" }
        end,
        mkdir = function() return true end,
    },
    alert  = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    screen = {
        mainScreen = function()
            return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
        end,
        -- Two screens on purpose: the second is where a remembered spot
        -- that belongs to an unplugged monitor is proven to be refused.
        allScreens = function()
            local out = {}
            for _, f in ipairs(SCREENS) do
                out[#out + 1] = { frame = function() return f end }
            end
            return out
        end,
    },
    drawing = { windowLevels = { floating = 5 } },
    json = {
        encode = function(t)
            -- Deliberately a real round-trip, not a pretty printer: the
            -- store must survive encode → decode with its shape intact.
            local function enc(v)
                if type(v) == "table" then
                    local isArr = (#v > 0)
                    local parts = {}
                    if isArr then
                        for _, x in ipairs(v) do parts[#parts + 1] = enc(x) end
                        return "[" .. table.concat(parts, ",") .. "]"
                    end
                    local keys = {}
                    for k in pairs(v) do keys[#keys + 1] = k end
                    table.sort(keys)
                    for _, k in ipairs(keys) do
                        parts[#parts + 1] = string.format("%q", k) .. ":" .. enc(v[k])
                    end
                    return "{" .. table.concat(parts, ",") .. "}"
                end
                if type(v) == "string" then return string.format("%q", v) end
                if type(v) == "boolean" then return tostring(v) end
                return tostring(v)
            end
            return enc(t)
        end,
        decode = function(s) return _G.FAKE_DECODE end,
    },
}

-- 🚚 hs.canvas — the ONE thing on this Mac that can accept a dragged
-- file (checked in libcanvas.m, not remembered). The stub can be made to
-- be an older Hammerspoon that has no draggingCallback at all, or one
-- whose canvas refuses to show, because both are real Macs.
CANVASES, NO_CANVAS, NO_DRAGCB = {}, false, false
hs.canvas = {
    windowLevels = { dragging = 500, screenSaver = 1000, floating = 3 },
    new = function(rect)
        if NO_CANVAS then return nil end
        local c = { rect = rect, elements = {} }
        function c:level(l) if l == nil then return self.lvl end self.lvl = l return self end
        function c:mouseCallback(f) self.mouseCb = f return self end
        function c:show() self.shown = true return self end
        function c:hide() self.shown = false return self end
        function c:delete() self.deleted = true return self end
        function c:frame(f) if f == nil then return self.rect end self.rect = f return self end
        if not NO_DRAGCB then
            function c:draggingCallback(f) self.dragCb = f return self end
        end
        setmetatable(c, { __newindex = function(t, k, v) rawset(t, k, v) end })
        CANVASES[#CANVASES + 1] = c
        return c
    end,
}
-- The drag pasteboard. macOS answers on whichever reader it feels like,
-- so each can be silenced independently and the ORDER is what is proven.
PB = { url = nil, str = nil, contents = nil }
hs.pasteboard = {
    readURL = function(name, all)
        if PB.url == nil then return nil end
        return all and PB.url or PB.url[1]
    end,
    readString = function(name, all)
        if PB.str == nil then return nil end
        return all and PB.str or PB.str[1]
    end,
    getContents = function(name) return PB.contents end,
}

-- 🔊 hs.sound, and it can be made to behave badly on purpose.
hs.sound = {
    getByFile = function(path)
        if NO_SOUND then error("no sound on this Mac") end
        if OPENABLE[path] == false then return nil end
        local s = {
            path = path, playing = false, plays = 0, stops = 0,
            cb = nil, t = 0,
        }
        function s:play() self.playing = true ; self.plays = self.plays + 1 ; return true end
        function s:pause() self.playing = false ; return true end
        function s:resume() self.playing = true ; return true end
        function s:stop() self.playing = false ; self.stops = self.stops + 1 ; return true end
        function s:isPlaying() return self.playing end
        function s:currentTime() return self.t end
        function s:duration() return DURATION[path] or 180 end
        function s:setCallback(fn) self.cb = fn ; return self end
        SOUNDS[#SOUNDS + 1] = s
        return s
    end,
}

hs.webview = {
    usercontent = {
        new = function(name)
            local uc = { name = name, cb = nil }
            function uc:setCallback(fn) self.cb = fn ; return self end
            return uc
        end,
    },
    new = function(rect, _, uc)
        if NO_WEBVIEW then return nil end
        local v = { rect = rect, uc = uc, shown = false, deleted = false, html = "" }
        function v:windowTitle() return self end
        function v:allowTextEntry() return self end
        function v:level() return self end
        function v:behaviorAsLabels() return self end
        function v:alpha() return self end
        function v:html(h) self.htmlText = h ; return self end
        function v:show() self.shown = true ; return self end
        function v:bringToFront() return self end
        function v:delete() self.deleted = true ; return self end
        -- 🧪 A REAL GETTER *AND* SETTER, because hs.webview's frame() is
        -- both: a getter-only stub lets every move succeed while moving
        -- nothing, and no mutation of the drag could ever be caught
        -- (6.227.0's selectedRow, in a new costume).
        function v:frame(r)
            if r == nil then return self.rect end
            self.rect = { x = r.x, y = r.y, w = r.w, h = r.h }
            return self
        end
        function v:evaluateJavaScript(s) JS[#JS + 1] = s ; return self end
        WEBVIEWS[#WEBVIEWS + 1] = v
        return v
    end,
}

_G.diag = { say = function() end, warn = function() end, err = function() end }

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
}
_G.claimEscape = function(name, _, active, handle)
    ESC_CLAIMS[name] = { active = active, handle = handle }
    return true
end
_G.hyperExpectRelease = function() end
_G.hyperReleaseSeen   = function(who) _G.RELEASED = who end

local chunk = assert(loadfile(HS .. "/modules/music_player.lua"))
local M = chunk()
M.setup(CORE)
local mp = _G.musicPlayer

local function reset()
    FILES, OPENABLE, DURATION = {}, {}, {}
    SOUNDS, TIMERS, ALERTS, PRINTED, DEGRADED, JS, WEBVIEWS = {}, {}, {}, {}, {}, {}, {}
    WRITES, READABLE = {}, {}
    NO_WEBVIEW, NO_SOUND = false, false
    _G.FAKE_DECODE, _G.RELEASED = nil, nil
    if mp.webview then pcall(mp.hide) end
    mp.queue, mp.history, mp.refused = {}, {}, {}
    mp.index, mp.sel, mp.mode = 0, 1, "off"
    mp.playing, mp.sound, mp.elapsed, mp.duration = false, nil, 0, 0
    mp.advances = { callback = 0, belt = 0, manual = 0 }
    mp.loaded, mp.enabled = true, true
    mp.tickTimer, mp.saveTimer = nil, nil
    mp.pos, mp.posWhy = nil, "not opened yet"
    SCREENS = { { x = 0, y = 0, w = 1440, h = 900 } }
    CANVASES, NO_CANVAS, NO_DRAGCB = {}, false, false
    PB = { url = nil, str = nil, contents = nil }
    mp.catcher, mp.dropReader = nil, nil
    mp.dropWhy, mp.dragSeen = "not opened yet", "no drag yet this session"
end

-- 🧪 The catcher, and the drag that reaches it. Both answer falsely
-- rather than indexing a nil (6.186.0), so a mutation FAILS a check.
local function catcher()
    return CANVASES[#CANVASES] or { lvl = nil, rect = nil, mouseCb = nil }
end
local function drag(msg, pb)
    local c = CANVASES[#CANVASES]
    if not (c and c.dragCb) then return false end
    return c.dragCb(c, msg, { pasteboard = pb or "drag-pb", sequence = 1 })
end

local function drop(uri, names)
    local view = WEBVIEWS[#WEBVIEWS]
    local uc = view and view.uc
    if not (uc and uc.cb) then return false end
    uc.cb({ body = { a = "drop", uri = uri, names = names } })
    return true
end
local function post(body)
    local view = WEBVIEWS[#WEBVIEWS]
    local uc = view and view.uc
    if not (uc and uc.cb) then return false end
    uc.cb({ body = body })
    return true
end
-- 🚨 6.186.0 / 6.225.0's rule, applied to this suite's own helpers: a
-- mutation must make a check FAIL, never make the run DIE. Every one of
-- these answers falsely rather than indexing a nil sound.
local function lastSound() return SOUNDS[#SOUNDS] end
local function fireEnd()
    local s = lastSound()
    if not (s and s.cb) then return false end
    s.cb(s, true)
    return true
end
local function muteCallback()
    local s = lastSound()
    if not s then return false end
    s.cb = nil
    return true
end
local function setSound(field, value)
    local s = lastSound()
    if not s then return false end
    s[field] = value
    return true
end

local function tickOnce()
    for _, t in ipairs(TIMERS) do
        if t.every and not t.stopped then t.fn() return true end
    end
    return false
end
local function has(list, needle)
    for _, s in ipairs(list) do
        if tostring(s):find(needle, 1, true) then return true end
    end
    return false
end
local function report()
    PRINTED = {}
    _G.musicReport()
    return table.concat(PRINTED, "\n")
end

out("\n=== 🎵 6.231.0 — what plays, and what comes next (PURE) ===\n")

-- ---- §1 the file rule --------------------------------------------------
check("🎧 mp3 and m4a play — the two formats he named",
      (mp.playableFor("/m/a.mp3")) and (mp.playableFor("/m/b.m4a")))
check("...and wav / aiff, which NSSound also decodes",
      (mp.playableFor("/m/a.wav")) and (mp.playableFor("/m/b.aiff")))
check("🚨 .flac is REFUSED, and the reason names the format and the way out",
      (function()
           local ok, why = mp.playableFor("/m/a.flac")
           return ok == false and why:find("flac", 1, true)
                  and why:find("m4a", 1, true) ~= nil
       end)(), select(2, mp.playableFor("/m/a.flac")))
check("...and so is .ogg — both named, neither silently skipped",
      select(1, mp.playableFor("/m/a.ogg")) == false)
check("a .pdf dropped by accident is refused BY NAME, never 'nothing happened'",
      (function()
           local ok, why = mp.playableFor("/m/a.pdf")
           return ok == false and why:find("pdf", 1, true) ~= nil
       end)())
check("a file with no extension is refused and says so",
      select(2, mp.playableFor("/m/noext")) == "no file extension")
check("EXTENSION MATCHING IS CASE-BLIND — Finder hands over .MP3 too",
      mp.playableFor("/m/A.MP3") == true)
check("a nil path does not throw", select(1, mp.playableFor(nil)) == false)

check("📛 the title is the file name with the extension off",
      mp.titleOf("/Users/lee/Music/Bad Blood.mp3") == "Bad Blood",
      mp.titleOf("/Users/lee/Music/Bad Blood.mp3"))
check("...and a dot inside the NAME survives it",
      mp.titleOf("/m/Mr. Blue Sky.m4a") == "Mr. Blue Sky",
      mp.titleOf("/m/Mr. Blue Sky.m4a"))

-- ---- §2 the clock ------------------------------------------------------
check("🕐 the clock reads m:ss", mp.clock(0) == "0:00" and mp.clock(65) == "1:05",
      mp.clock(65))
check("...and h:mm:ss ONLY once there are hours — no '0:' on every track",
      mp.clock(3725) == "1:02:05" and mp.clock(599) == "9:59",
      mp.clock(3725) .. " / " .. mp.clock(599))
check("...and a negative or absent time is 0:00, never a minus sign",
      mp.clock(-5) == "0:00" and mp.clock(nil) == "0:00")

-- ---- §3 the repeat rule, and the half that is the whole point ----------
check("🔁 repeat OFF walks to the end and then stops",
      mp.nextIndex(1, 3, "off") == 2 and mp.nextIndex(3, 3, "off") == nil)
check("🔁 repeat ALL wraps round", mp.nextIndex(3, 3, "all") == 1)
check("🔂 repeat ONE plays the same track again when it ENDS",
      mp.nextIndex(2, 3, "one") == 2)
-- 🚨 THE ROW THIS FUNCTION EXISTS FOR. A mode is about what the player
-- does on its own; it never refuses an instruction.
check("🚨 ...but ⏭ under repeat ONE moves ON — a person asking for the "
      .. "next track is asking for the next track",
      mp.nextIndex(2, 3, "one", true) == 3, mp.nextIndex(2, 3, "one", true))
check("...and ⏭ on the LAST track under repeat one wraps, it does not stop",
      mp.nextIndex(3, 3, "one", true) == 1)
check("an empty queue has no next, in any mode",
      mp.nextIndex(1, 0, "all") == nil and mp.nextIndex(1, 0, "one") == nil)
check("an index off the end of the queue lands on the first track",
      mp.nextIndex(99, 3, "off") == 1)
check("⏮ wraps to the last track from the first",
      mp.prevIndex(1, 4) == 4 and mp.prevIndex(3, 4) == 2)

-- ---- §4 the drop, which is where the paths come from -------------------
check("🚚 a Finder drag's uri-list becomes paths",
      (function()
           local p = mp.pathsFromURIList("file:///m/a.mp3\r\nfile:///m/b.m4a\r\n")
           return #p == 2 and p[1] == "/m/a.mp3" and p[2] == "/m/b.m4a"
       end)())
check("🚨 ...and the percent-escapes are undone, or a track with a space "
      .. "or an apostrophe in its name can never be opened",
      mp.pathsFromURIList("file:///m/Ain%27t%20It%20Fun.mp3")[1]
      == "/m/Ain't It Fun.mp3",
      mp.pathsFromURIList("file:///m/Ain%27t%20It%20Fun.mp3")[1])
check("the format's own # comment lines are not files",
      #mp.pathsFromURIList("# a comment\nfile:///m/a.mp3") == 1)
check("blank lines are not files either",
      #mp.pathsFromURIList("\n\nfile:///m/a.mp3\n\n") == 1)
check("a bare absolute path (a plain-text drag) is taken too",
      mp.pathsFromURIList("/m/a.mp3")[1] == "/m/a.mp3")
check("something that is neither is ignored rather than guessed at",
      #mp.pathsFromURIList("https://example.com/a.mp3") == 0)
check("a nil drop does not throw", #mp.pathsFromURIList(nil) == 0)

-- ---- §5 building the queue --------------------------------------------
check("➕ adding keeps the order he dropped them in",
      (function()
           local q = mp.addPaths({}, { "/m/a.mp3", "/m/b.mp3", "/m/c.mp3" })
           return #q == 3 and q[1].title == "a" and q[3].title == "c"
       end)())
check("🚨 the same file dropped twice is ONE row — dropping a folder "
      .. "again must not double the list",
      (function()
           local q = mp.addPaths({}, { "/m/a.mp3" })
           local q2, added, refused = mp.addPaths(q, { "/m/a.mp3" })
           return #q2 == 1 and #added == 0 and #refused == 1
                  and refused[1].why:find("already", 1, true) ~= nil
       end)())
check("🚨 ONE UNPLAYABLE FILE LOSES ITS OWN ROW, NEVER THE BATCH — the "
      .. "mp3s in a mixed drop still queue",
      (function()
           local q, added, refused =
               mp.addPaths({}, { "/m/a.mp3", "/m/b.flac", "/m/c.mp3" })
           return #q == 2 and #added == 2 and #refused == 1
       end)())
check("...and the refusal carries the file AND the reason, for the card",
      (function()
           local _, _, r = mp.addPaths({}, { "/m/b.flac" })
           return r[1].path == "/m/b.flac" and r[1].why:find("flac", 1, true) ~= nil
       end)())
check("the queue has a ceiling, and the overflow says which",
      (function()
           mp.maxQueue = 2
           local q, _, r = mp.addPaths({}, { "/m/a.mp3", "/m/b.mp3", "/m/c.mp3" })
           mp.maxQueue = 200
           return #q == 2 and #r == 1 and r[1].why:find("full", 1, true) ~= nil
       end)())

out("\n=== 🔊 the player itself, through the window ===\n")

-- ---- §6 opening -------------------------------------------------------
reset()
check("⇪⇧pad. is the key, and it is bound", BOUND["shift+pad."] ~= nil)
BOUND["shift+pad."].fn()
check("...and it opens the card", mp.webview ~= nil and #WEBVIEWS == 1)
check("...in the TOP-RIGHT corner, like the calendar he compared it to",
      (function()
           local r = WEBVIEWS[1].rect
           return r.x > 1000 and r.y < 40
       end)(), WEBVIEWS[1] and (WEBVIEWS[1].rect.x .. "," .. WEBVIEWS[1].rect.y))
check("...and the elapsed clock is ticking on a HELD timer (6.196.1 — a "
      .. "timer nothing references is collected and simply never fires)",
      mp.tickTimer ~= nil and mp.tickTimer.every == true)
check("...and it claimed Esc, so the cheat sheet still closes LAST",
      ESC_CLAIMS["musicplayer"] ~= nil and ESC_CLAIMS["musicplayer"].active())
BOUND["shift+pad."].fn()
check("the same key closes it again", mp.webview == nil)
check("...and the tick stops with the window — nothing keeps beating at a "
      .. "card that is not there", mp.tickTimer == nil)

-- ---- §7 the drop, end to end ------------------------------------------
reset()
FILES["/m/one.mp3"], FILES["/m/two.mp3"], FILES["/m/three.mp3"] = true, true, true
mp.show()
drop("file:///m/one.mp3\nfile:///m/two.mp3\nfile:///m/three.mp3")
check("🎵 three files dropped, three tracks queued", #mp.queue == 3, #mp.queue)
check("🚨 ...and THE FIRST ONE PLAYS, which is exactly what he asked for",
      mp.playing == true and mp.index == 1 and #SOUNDS == 1,
      tostring(mp.index) .. " sounds=" .. #SOUNDS)
check("...the rest are the playlist under it, untouched",
      mp.queue[2].title == "two" and mp.queue[3].title == "three")
check("...and the page was redrawn with them", has(JS, "draw("))

check("⌘3 plays the third track",
      (function() post({ a = "pick", i = 3 }) return mp.index == 3 end)(), mp.index)
check("...and the one that was playing was STOPPED, not left running under it",
      SOUNDS[1] ~= nil and SOUNDS[1].stops >= 1)
check("↓ moves the highlight without playing anything",
      (function()
           local before = #SOUNDS
           mp.sel = 1
           post({ a = "sel", d = 1 })
           return mp.sel == 2 and #SOUNDS == before
       end)(), mp.sel)
check("⏎ plays the highlighted row",
      (function() post({ a = "pick", i = mp.sel }) return mp.index == 2 end)())
check("space pauses, and space again resumes",
      (function()
           post({ a = "play" })
           local paused = (mp.playing == false)
           post({ a = "play" })
           return paused and mp.playing == true
       end)())
check("⌫ takes the highlighted track out",
      (function()
           local n = #mp.queue
           mp.sel = 3
           post({ a = "remove", i = 3 })
           return #mp.queue == n - 1
       end)(), #mp.queue)

-- ---- §8 the two ways a track ends -------------------------------------
reset()
FILES["/m/a.mp3"], FILES["/m/b.mp3"] = true, true
mp.show()
drop("file:///m/a.mp3\nfile:///m/b.mp3")
check("track 1 is playing", mp.index == 1)
check("a sound was actually handed out to end", fireEnd())
check("🔔 hs.sound's callback ends the track and the next one starts",
      mp.index == 2, mp.index)
check("...and it is COUNTED as a callback advance",
      mp.advances.callback == 1 and mp.advances.belt == 0)

-- 🚨 THE BELT, AND WHY IT EXISTS. A callback this module cannot prove
-- fires is a playlist that stops after one song with no error anywhere.
-- Here the callback is simply deleted, exactly as a Hammerspoon that does
-- not deliver it would behave.
reset()
FILES["/m/a.mp3"], FILES["/m/b.mp3"] = true, true
DURATION["/m/a.mp3"] = 10
mp.show()
drop("file:///m/a.mp3\nfile:///m/b.mp3")
check("a sound was handed out before the belt is tested", muteCallback())
setSound("playing", false)             -- macOS never tells us, but it HAS stopped
setSound("t", 10)
tickOnce()
check("🔔 THE BELT: with no callback at all, the tick notices the track "
      .. "stopped and moves on — the playlist does not die after one song",
      mp.index == 2, mp.index)
check("...and it is counted SEPARATELY, so the report can say which half "
      .. "this Mac is actually using",
      mp.advances.belt == 1 and mp.advances.callback == 0,
      mp.advances.belt .. "/" .. mp.advances.callback)

-- 🚨 AND THE BELT MUST NOT FIRE EARLY. A paused track has stopped too.
reset()
FILES["/m/a.mp3"], FILES["/m/b.mp3"] = true, true
DURATION["/m/a.mp3"] = 200
mp.show()
drop("file:///m/a.mp3\nfile:///m/b.mp3")
setSound("playing", false)
setSound("t", 4)                        -- four seconds into a 200 s track
tickOnce()
check("🚨 ...and a track stopped FOUR SECONDS into two hundred is not a "
      .. "track that ended — the belt does not skip on a pause",
      mp.index == 1 and mp.advances.belt == 0, mp.index)

-- ---- §9 repeat, through the window ------------------------------------
reset()
FILES["/m/a.mp3"], FILES["/m/b.mp3"] = true, true
mp.show()
drop("file:///m/a.mp3\nfile:///m/b.mp3")
post({ a = "repeat" }) ; post({ a = "repeat" })
check("🔂 two clicks of the repeat button reach 'one' (off → all → one)",
      mp.mode == "one", mp.mode)
mp.playAt(1, "test")
check("a sound is playing before the repeat rule is asked", fireEnd())
check("🔂 a track that ENDS under repeat one plays again",
      mp.index == 1, mp.index)
post({ a = "next" })
check("🚨 ...and ⏭ under repeat one moves ON — the window proves the same "
      .. "rule the pure function does",
      mp.index == 2, mp.index)
check("...and the asked-for advance is counted apart from the automatic ones",
      mp.advances.manual >= 1)

-- ---- §10 the degrades, every one of them ------------------------------
reset()
mp.show()
drop("", { "Song.mp3", "Other.mp3" })
check("🚚 A DROP macOS GAVE NO PATH FOR IS NOT SILENT — the names are "
      .. "named and the reason is said, because a card that ignored the "
      .. "drop reads as broken",
      #mp.refused == 1 and mp.refused[1] ~= nil
      and mp.refused[1].why:find("Song.mp3", 1, true) ~= nil
      and mp.refused[1].why:find("path", 1, true) ~= nil,
      mp.refused[1] and mp.refused[1].why)
check("...and it reaches the page, not just the log", has(JS, "draw("))

reset()
FILES["/m/a.mp3"] = true
mp.show()
drop("file:///m/a.mp3")
FILES["/m/a.mp3"] = nil                 -- deleted between the drop and the play
local okGone = mp.playAt(1, "test")
check("🗑 a file that has GONE is a stat, never a read — no cloud download "
      .. "on the main thread to find out",
      okGone == false and mp.queue[1] ~= nil and mp.queue[1].bad ~= nil,
      mp.queue[1] and mp.queue[1].bad)
check("...and the row says so where he is looking",
      mp.queue[1] ~= nil
      and tostring(mp.queue[1].bad):find("not there", 1, true) ~= nil)

reset()
FILES["/m/a.mp3"], FILES["/m/b.mp3"] = true, true
OPENABLE["/m/a.mp3"] = false            -- macOS refuses this one file
mp.show()
drop("file:///m/a.mp3\nfile:///m/b.mp3")
check("🚨 a file macOS refuses to DECODE marks its own row and leaves the "
      .. "rest of the queue alone — one failed item, never the batch",
      #mp.queue == 2 and mp.queue[1] ~= nil and mp.queue[1].bad ~= nil
      and mp.queue[2] ~= nil and mp.queue[2].bad == nil, #mp.queue)

-- 🔔 TWO DIFFERENT NO-WINDOW FACTS, AND THEY MUST NOT READ ALIKE: a
-- Hammerspoon built without hs.webview at all, and a Mac that has the API
-- and still refuses to make the window. Both take the door; each says its
-- own thing, so the Console line names which one happened.
reset()
local SAVED_WEBVIEW = hs.webview
hs.webview = nil
local okApi, whyApi = mp.show()
check("🔔 no hs.webview AT ALL → the card refuses, says so, and TAKES THE "
      .. "DOOR rather than failing in silence",
      okApi == false and #DEGRADED == 1
      and DEGRADED[1]:find("hs.webview", 1, true) ~= nil,
      DEGRADED[1] or whyApi)
hs.webview = SAVED_WEBVIEW

reset()
NO_WEBVIEW = true
local okShow, whyShow = mp.show()
check("🔔 ...and a Mac that HAS the API but will not open the window says "
      .. "a DIFFERENT thing — two facts, two sentences",
      okShow == false and #DEGRADED == 1
      and DEGRADED[1]:find("could not open the player window", 1, true) ~= nil
      and DEGRADED[1]:find("hs.webview", 1, true) == nil,
      DEGRADED[1] or whyShow)
check("...and it does not leave the page bridge held behind it",
      mp.uc == nil and mp.webview == nil)
NO_WEBVIEW = false

reset()
FILES["/m/a.mp3"] = true
mp.show()
drop("file:///m/a.mp3")
NO_SOUND = true
mp.index = 0
local okNo = mp.playAt(1, "test")
check("🔔 an hs.sound that throws is caught, named and degraded — never a "
      .. "traceback into the config",
      okNo == false, okNo)
NO_SOUND = false

reset()
mp.enabled = false
local okOff = mp.show()
check("🔌 the off switch is real, and it is read at the PRESS — not "
      .. "latched at setup where a settings override could never reach it",
      okOff == false and mp.webview == nil)
mp.enabled = true

-- ---- §11 the store -----------------------------------------------------
reset()
FILES["/m/a.mp3"], FILES["/m/b.mp3"] = true, true
mp.show()
drop("file:///m/a.mp3\nfile:///m/b.mp3")
for _, t in ipairs(TIMERS) do if not t.every then t.fn() end end
check("💾 the queue is written",
      WRITES[mp.storeFile] ~= nil
      and WRITES[mp.storeFile]:find("a.mp3", 1, true) ~= nil,
      WRITES[mp.storeFile])
check("🚨 ...LOCALLY. Not into OneDrive — a cloud write costs a main-thread "
      .. "wake-up (6.229.0) and a half-played queue is not cross-Mac data",
      mp.storeFile:find("Application Support", 1, true) ~= nil
      and mp.storeFile:find("OneDrive", 1, true) == nil,
      mp.storeFile)

-- 🗂 6.198.1's rule, in the loader: "it is a table" is not "it is MY
-- table". A store written by an older build, truncated by a crash, or
-- hand-edited must not reach a single reader — and the REPORT reads the
-- same structure the feature does, so a bad store would otherwise take
-- out the diagnostic that names it.
reset()
READABLE[mp.storeFile] = "{}"
_G.FAKE_DECODE = { queue = { { path = "/m/good.mp3" }, "not a table",
                             { nope = true }, { path = 42 } },
                   -- 🧪 `at` is RECENT on purpose: 6.234.0 prunes by age at
                   -- the loader, so a 1970 timestamp here would make this
                   -- check pass for the wrong reason (6.219.0's rule — a
                   -- test built on one behaviour is retired by a change to
                   -- it, so re-arm it in the same release).
                   history = { { path = "/m/h.mp3", at = os.time() }, 7 },
                   mode = "all" }
mp.loaded = false
mp.loadStore()
check("🗂 the loader keeps the rows that are the right SHAPE",
      #mp.queue == 1 and mp.queue[1] ~= nil
      and mp.queue[1].path == "/m/good.mp3", #mp.queue)
check("...and drops the ones that are not, without throwing", #mp.history == 1)
check("...and a remembered repeat mode comes back", mp.mode == "all")
check("...and the report still works over the cleaned store — the "
      .. "diagnostic must survive the thing it diagnoses",
      report():find("MUSIC PLAYER", 1, true) ~= nil)

reset()
READABLE[mp.storeFile] = "{{{ not json"
_G.FAKE_DECODE = nil
mp.loaded = false
mp.loadStore()
check("🚨 a store that cannot be decoded starts EMPTY and says so — it "
      .. "never throws on the way to a keypress",
      #mp.queue == 0 and tostring(mp.lastWhy):find("could not be read", 1, true) ~= nil,
      mp.lastWhy)

-- ---- §12 the report ----------------------------------------------------
reset()
local r0 = report()
check("📋 the report opens with the tool and its key",
      r0:find("🎵 MUSIC PLAYER — ⇪⇧pad.", 1, true) ~= nil)
check("...and an empty queue reads as EMPTY, not as a silent zero",
      r0:find("empty", 1, true) ~= nil)
check("...and it names the local store and why it is local",
      r0:find("LOCAL, never OneDrive", 1, true) ~= nil)
check("...and it says there is no volume control, on purpose",
      r0:find("volume", 1, true) ~= nil)
check("🚨 ...and it prints as ONE string (6.179.1 — a report printed row "
      .. "by row loses rows to the console gate)", #PRINTED == 1, #PRINTED)

FILES["/m/a.mp3"], FILES["/m/b.mp3"] = true, true
mp.show()
drop("file:///m/a.mp3\nfile:///m/b.flac")
local r1 = report()
check("📋 the queue is listed with the playing track marked",
      r1:find("← playing", 1, true) ~= nil, r1)
check("🚨 ...and the REFUSED file is named with its reason — a drop that "
      .. "half worked must say which half",
      r1:find("flac", 1, true) ~= nil)
check("...and the two advance counters are printed side by side, so "
      .. "nobody deletes the belt for looking redundant",
      r1:find("by callback", 1, true) and r1:find("by the belt", 1, true))

-- ---- §13 the handshake and the housekeeping ---------------------------
reset()
mp.show()
post({ a = "f18" })
check("⇪ THE HANDSHAKE: the page forwards F18's keyup so the hold can end "
      .. "while the card is up (6.165.1)", _G.RELEASED == "musicPlayer",
      tostring(_G.RELEASED))
check("...and Esc from the page closes the card",
      (function() post({ a = "esc" }) return mp.webview == nil end)())

reset()
FILES["/m/a.mp3"] = true
mp.show()
drop("file:///m/a.mp3")
mp.hide()
check("🎶 closing the card does NOT stop the music — putting a window away "
      .. "is not an instruction to stop playing",
      mp.playing == true and mp.sound ~= nil)

reset()
check("🔌 the services are published for other modules",
      PROVIDED["music.show"] and PROVIDED["music.toggle"] and PROVIDED["music.hide"])

-- ---- §14 a name the card cannot draw ----------------------------------
-- 🔔 6.231.1. `rowsJson` used to answer "{}" when hs.json refused the
-- queue. That drew an EMPTY CARD over a queue that was still playing and
-- told nobody — 6.196.1's rule ("not yet" and "never" must not read
-- alike), in the one function every redraw goes through.
reset()
FILES["/m/a.mp3"] = true
mp.show()
drop("file:///m/a.mp3")
local goodEncode = hs.json.encode
hs.json.encode = function() error("not text") end
local payload = mp.rowsJson()
hs.json.encode = goodEncode
check("🔔 a queue that cannot be encoded takes the degrade door",
      #DEGRADED > 0 and DEGRADED[#DEGRADED]:find("could not be turned into text",
                                                 1, true) ~= nil,
      table.concat(DEGRADED, " | "))
check("🚨 ...and the answer is NOT a bare {} — an empty card over a "
      .. "playing queue is a lie the page cannot tell from an empty queue",
      payload ~= "{}" and payload:find("refused", 1, true) ~= nil, payload)
check("...and what it does answer still carries the fields the page reads",
      payload:find('"rows"', 1, true) and payload:find('"hist"', 1, true)
      and payload:find('"mode"', 1, true), payload)
check("...and the queue itself is untouched — the drawing failed, "
      .. "not the music", #mp.queue == 1 and mp.playing == true)

-- ---- §15 the window moves ----------------------------------------------
-- 🪟 6.232.0. The card was the one panel this config draws that never
-- registered itself in _G.movablePanels, so neither grip reached it: not
-- window_move's ⌘-drag, and not the bare drag on a title strip.

-- PURE first, with no Mac: where does it open?
local SF = { x = 0, y = 0, w = 1440, h = 900 }
local ONE = { SF }
local TWO = { SF, { x = 1440, y = 0, w = 1920, h = 1080 } }

local corner = mp.frameFor(SF)
local r, why = mp.placeFor(nil, SF, ONE)
check("🪟 a card that has never been moved opens in the corner",
      r.x == corner.x and r.y == corner.y and why == "corner", why)

r, why = mp.placeFor({ x = 200, y = 300 }, SF, ONE)
check("...and one he moved opens where he left it",
      r.x == 200 and r.y == 300 and why == "moved", why)
check("...at the same size as ever", r.w == corner.w and r.h == corner.h)

r, why = mp.placeFor({ x = 2000, y = 200 }, SF, ONE)
check("🚨 a spot on a monitor that is NOT attached now is refused for the "
      .. "corner — never clamped onto the edge of a screen it was never on",
      r.x == corner.x and r.y == corner.y
      and why:find("no screen now", 1, true) ~= nil, why)

r, why = mp.placeFor({ x = 2000, y = 200 }, SF, TWO)
check("...and the same spot is kept once that monitor is back",
      r.x == 2000 and r.y == 200 and why == "moved", why)

r, why = mp.placeFor({ x = 1430, y = 880 }, SF, ONE)
check("a card remembered three-quarters off the bottom right is nudged "
      .. "back on, because a grip you cannot reach is the bug this fixes",
      r.x == SF.w - corner.w and r.y == SF.h - corner.h
      and why:find("nudged", 1, true) ~= nil, why)
check("...and the nudge SAYS so rather than reading as an exact restore",
      why ~= "moved")

r = mp.placeFor({ x = "over there" }, SF, ONE)
check("a store holding nonsense for a position opens in the corner",
      r.x == corner.x and r.y == corner.y)

-- the registration, and the two grips
reset()
local entry
for _, e in ipairs(_G.movablePanels or {}) do
    if e.name == "music player" then entry = e end
end
check("🪟 the card is listed in _G.movablePanels, which is the ONLY way "
      .. "window_move can reach it", entry ~= nil)
-- 🧪 6.186.0, and this suite has now paid it twice: the mutation that
-- deletes the registration must FAIL these checks, not kill the run on
-- `entry.frame`. The stand-in answers falsely instead.
local grip = entry or { frame = function() return nil end,
                        move  = function() end }
check("...with a frame and a move, the two things window_move calls",
      entry and type(entry.frame) == "function"
            and type(entry.move) == "function")
check("🚨 ...and NOT as plain — a bare click on this card picks a track, "
      .. "so only the title strip may take one",
      entry and not entry.plain)

mp.show()
local view = WEBVIEWS[#WEBVIEWS]
check("the frame it reports is the window's own",
      grip.frame() ~= nil and grip.frame().w == view.rect.w)

grip.move(120, 240)
check("🪟 moving it moves the WINDOW",
      view.rect.x == 120 and view.rect.y == 240,
      view.rect.x .. "," .. view.rect.y)
check("...and keeps its size", view.rect.w == corner.w and view.rect.h == corner.h)
check("...and remembers the spot", mp.pos and mp.pos.x == 120 and mp.pos.y == 240)

-- it comes back where he put it
mp.hide()
mp.show()
local v2 = WEBVIEWS[#WEBVIEWS]
check("🚨 ...so ⇪⇧pad. opens it where he left it, not back in the corner",
      v2.rect.x == 120 and v2.rect.y == 240,
      v2.rect.x .. "," .. v2.rect.y)

-- and the spot survives a reload, through the store — both ways
for _, t in ipairs(TIMERS) do if not t.every then t.fn() end end
check("💾 the spot is written to the store",
      (WRITES[mp.storeFile] or ""):find("120", 1, true) ~= nil,
      WRITES[mp.storeFile])

reset()
READABLE[mp.storeFile] = "{}"
_G.FAKE_DECODE = { queue = {}, history = {}, mode = "off",
                   pos = { x = 300, y = 400 } }
mp.loaded = false
mp.loadStore()
check("...and read back on the next boot",
      mp.pos and mp.pos.x == 300 and mp.pos.y == 400,
      mp.pos and (mp.pos.x .. "," .. mp.pos.y) or "nil")

reset()
READABLE[mp.storeFile] = "{}"
_G.FAKE_DECODE = { queue = {}, history = {}, pos = "somewhere" }
mp.loaded = false
mp.loadStore()
check("🗂 ...and a store whose position is not a position is DROPPED at "
      .. "the loader, never handed to the window",
      mp.pos == nil, tostring(mp.pos))
_G.FAKE_DECODE = nil

-- the header's bare drag
reset()
mp.show()
_G.PICKED_UP = nil
_G.beginPanelDrag = function(n) _G.PICKED_UP = n ; return true end
post({ a = "dragStart" })
check("🪟 a press on the title strip asks window_move to pick the card up",
      _G.PICKED_UP == "music player", tostring(_G.PICKED_UP))

-- 🔔 and with window_move absent it says so instead of doing nothing
reset()
mp.show()
_G.beginPanelDrag = nil
local okDrag = pcall(post, { a = "dragStart" })
check("🚨 with window_move not loaded the press does not throw",
      okDrag == true)
check("...and the reason is recorded rather than swallowed",
      tostring(mp.lastWhy):find("window_move", 1, true) ~= nil,
      tostring(mp.lastWhy))
_G.beginPanelDrag = function(n) _G.PICKED_UP = n ; return true end

-- the page carries the grip
reset()
mp.show()
local page = WEBVIEWS[#WEBVIEWS].htmlText or ""
check("🚨 ...and it is the HEADER that listens, not the whole card — a "
      .. "press on a row must still pick a track",
      page:find("hd.addEventListener('mousedown'", 1, true) ~= nil)

-- the report
reset()
mp.show()
grip.move(75, 85)
local rw = report()
check("📋 the report says where the card is and why it is there",
      rw:find("window", 1, true) and rw:find("75,85", 1, true), rw)
check("...and names both grips, because neither is discoverable",
      rw:find("⌘-drag", 1, true) ~= nil)

-- ---- §16 a dragged file lands on the card ------------------------------
-- 🚚 6.233.0, and it is the release that made the feature exist. hs.webview
-- has NO drag-and-drop (checked in libwebview.m: the string "dragg" appears
-- zero times), so the drop LL was told to test could never have worked — the
-- drag fell through to whatever was behind the card, which is his report.
-- hs.canvas is the one that can, under two conditions its own docs state.

reset()
FILES["/m/a.mp3"], FILES["/m/b.mp3"] = true, true
mp.show()
local cat = catcher()
check("🚚 opening the card puts a drop catcher up — without it nothing "
      .. "can accept a dragged file at all", CANVASES[1] ~= nil)
check("...at the card's own frame, or the drop lands somewhere else",
      cat.rect and cat.rect.w == mp.frameFor(SF).w, cat.rect and cat.rect.w)
check("🚨 ...at the DRAGGING window level, which hs.canvas REQUIRES — "
      .. "anything higher and macOS never offers it the drag",
      cat.lvl == hs.canvas.windowLevels.dragging, tostring(cat.lvl))
check("🚨 ...and with a mouseCallback, the second documented condition — "
      .. "a canvas that takes no mouse events takes no drags either",
      type(cat.mouseCb) == "function")

-- the drag itself
JS = {}
drag("enter")
check("a drag coming over the card shows the drop veil",
      table.concat(JS, " "):find("dropShow(true)", 1, true) ~= nil,
      table.concat(JS, " "))
JS = {}
drag("exit")
check("...and taking it away again hides it",
      table.concat(JS, " "):find("dropShow(false)", 1, true) ~= nil)

JS = {}
PB.url = { "file:///m/a.mp3", "file:///m/b.mp3" }
drag("receive")
check("🚚 DROPPING TWO FILES PUTS THEM IN THE QUEUE — the whole feature",
      #mp.queue == 2 and mp.queue[1].path == "/m/a.mp3",
      #mp.queue)
check("...and the first one starts playing, as he described it",
      mp.playing == true and mp.index == 1)
check("...and the veil is taken down", 
      table.concat(JS, " "):find("dropShow(false)", 1, true) ~= nil)
check("...and the report names which reader macOS answered on",
      mp.dropReader == "readURL", tostring(mp.dropReader))

-- the readers, in order, because macOS answers on whichever it likes
reset() ; mp.show()
PB.url = nil
PB.str = { "file:///m/c.mp3" }
FILES["/m/c.mp3"] = true
drag("receive")
check("a Mac that answers on readString instead is still read",
      #mp.queue == 1 and mp.dropReader == "readString", tostring(mp.dropReader))

reset() ; mp.show()
PB.url, PB.str = nil, nil
PB.contents = "file:///m/d.mp3"
FILES["/m/d.mp3"] = true
drag("receive")
check("...and one that only answers on getContents too",
      #mp.queue == 1 and mp.dropReader == "getContents", tostring(mp.dropReader))

reset() ; mp.show()
PB.url = { "file:///m/first.mp3" }
PB.str = { "file:///m/second.mp3" }
FILES["/m/first.mp3"], FILES["/m/second.mp3"] = true, true
drag("receive")
check("🚨 the FIRST reader that answers decides — the order is the rule, "
      .. "not a preference", mp.queue[1] and mp.queue[1].path == "/m/first.mp3",
      mp.queue[1] and mp.queue[1].path)

-- a drop that carries nothing is NAMED
reset() ; mp.show()
PB.url, PB.str, PB.contents = nil, nil, nil
drag("receive")
check("🔔 a drop macOS hands over with no path in it is NAMED, never "
      .. "swallowed", #mp.refused == 1 and mp.refused[1].why ~= "",
      mp.refused[1] and mp.refused[1].why)
check("...and the queue is untouched", #mp.queue == 0)

-- the catcher follows the card, and goes with it
reset() ; mp.show()
local entry2
for _, e in ipairs(_G.movablePanels or {}) do
    if e.name == "music player" then entry2 = e end
end
;(entry2 or { move = function() end }).move(400, 500)
check("🪟 moving the card moves the catcher with it — a catcher left "
      .. "behind is a dead zone over the old spot",
      catcher().rect and catcher().rect.x == 400,
      catcher().rect and catcher().rect.x)
local was = catcher()
mp.hide()
check("...and closing the card takes the catcher down",
      was.deleted == true and mp.catcher == nil)

-- 🔔 the degrades, both of them, and they must not read alike
reset()
local realCanvas = hs.canvas
hs.canvas = nil
local okNoCv = mp.show()
check("🔔 a Hammerspoon with NO hs.canvas at all still OPENS the card",
      okNoCv == true and mp.webview ~= nil)
check("...and says so, rather than the card looking broken",
      tostring(mp.dropWhy):find("no hs.canvas", 1, true) ~= nil,
      tostring(mp.dropWhy))
check("...through the 🔔 door, so he sees it at the moment it happens",
      #DEGRADED > 0, table.concat(DEGRADED, " | "))
check("...and the report names that state, never 'ready'",
      report():find("⚠️", 1, true) ~= nil and mp.catcher == nil)
hs.canvas = realCanvas

reset()
NO_CANVAS = true
mp.show()
check("🔔 ...and a Mac whose hs.canvas REFUSES to make the window is a "
      .. "DIFFERENT state, which must not read the same (6.196.1)",
      tostring(mp.dropWhy):find("could not be created", 1, true) ~= nil
      and tostring(mp.dropWhy):find("no hs.canvas", 1, true) == nil,
      tostring(mp.dropWhy))
check("🔔 ...and THAT one takes the door too — every way the drop can "
      .. "fail is a break he is shown, not one he finds later",
      #DEGRADED > 0, table.concat(DEGRADED, " | "))

reset()
NO_DRAGCB = true
mp.show()
check("🔔 a Hammerspoon whose canvas cannot take drags is its OWN state",
      mp.catcher == nil and tostring(mp.dropWhy):find("cannot accept drags",
                                                      1, true) ~= nil,
      tostring(mp.dropWhy))
check("...and the canvas it made is cleaned up, not left on screen",
      catcher().deleted == true)

-- the page's own door still reaches the same function
reset() ; mp.show()
FILES["/m/z.mp3"] = true
drop("file:///m/z.mp3")
check("🚚 the page's own drop handler goes through the SAME door, so the "
      .. "two can never drift", #mp.queue == 1)

-- the report
reset() ; mp.show()
PB.url = { "file:///m/a.mp3" }
drag("receive")
local rd = report()
check("📋 the report says the catcher is up and what it last saw",
      rd:find("catcher up", 1, true) and rd:find("dropped", 1, true), rd)

-- ---- §17 thirty days, one row per file ---------------------------------
-- 🕘 6.234.0. PURE, so the clock is an argument and nothing here waits.
local NOW = 1000000000
local DAY = 86400
-- 🧪 6.186.0, third time in this suite: a mutation that empties the list
-- must FAIL these checks, not die on h[1].path.
local function row(list, i)
    return (type(list) == "table" and type(list[i]) == "table") and list[i]
           or { path = "<none>", at = -1 }
end

local h = mp.noteHistory({}, { path = "/m/a.mp3", title = "a" }, NOW, 30, 400)
check("🕘 a track played goes into the history", #h == 1 and h[1].path == "/m/a.mp3")
check("...stamped with when it played", row(h, 1).at == NOW)

h = mp.noteHistory(h, { path = "/m/b.mp3", title = "b" }, NOW + 10, 30, 400)
check("...and the newest is FIRST, which is the order the card draws",
      row(h, 1).path == "/m/b.mp3" and row(h, 2).path == "/m/a.mp3", #h)

-- 🚨 THE ROW HE ASKED FOR
h = mp.noteHistory(h, { path = "/m/a.mp3", title = "a" }, NOW + 20, 30, 400)
check("🚨 THE SAME FILE IS LISTED ONCE — playing it again MOVES it up "
      .. "rather than adding a second row (his ask, word for word)",
      #h == 2, #h)
check("...at the top, with the new time",
      row(h, 1).path == "/m/a.mp3" and row(h, 1).at == NOW + 20)
check("...and the other track is still there, not lost to the de-duplicate",
      row(h, 2).path == "/m/b.mp3")

-- the window
local old30 = {
    { path = "/m/yesterday.mp3", title = "y", at = NOW - DAY },
    { path = "/m/lastweek.mp3",  title = "w", at = NOW - (7 * DAY) },
    { path = "/m/day29.mp3",     title = "n", at = NOW - (29 * DAY) },
    { path = "/m/day31.mp3",     title = "o", at = NOW - (31 * DAY) },
    { path = "/m/lastyear.mp3",  title = "l", at = NOW - (400 * DAY) },
}
h = mp.noteHistory(old30, nil, NOW, 30, 400)
check("🕘 thirty days is the rule: everything inside the window stays",
      #h == 3, #h)
check("...and day 29 is INSIDE it", row(h, 3).path == "/m/day29.mp3",
      row(h, 3).path)
check("🚨 ...and day 31 is not — the edge is a real edge, not a rounding",
      (function()
          for _, t in ipairs(h) do if t.path == "/m/day31.mp3" then return false end end
          return true
      end)())
check("...nor is last year", #h == 3)

h = mp.noteHistory(old30, nil, NOW, 365, 400)
check("...and the window is a NUMBER, not a hard-coded thirty — at 365 "
      .. "days the day-31 row comes back, and last year's still does not",
      #h == 4 and row(h, 4).path == "/m/day31.mp3",
      #h .. " " .. row(h, 4).path)

-- the bound is still a bound
local many = {}
for i = 1, 50 do many[i] = { path = "/m/t" .. i .. ".mp3", at = NOW - i } end
h = mp.noteHistory(many, nil, NOW, 30, 10)
check("🔒 the cap is still a bound — days decide, but a runaway list is "
      .. "still a runaway list", #h == 10, #h)
check("...and it keeps the NEWEST ten, never the oldest",
      row(h, 1).path == "/m/t1.mp3")

-- it never throws on a store somebody else wrote
check("🗂 a history list full of nonsense is dropped, not fatal",
      #mp.noteHistory({ "x", 7, { nope = true }, { path = "" } }, nil,
                      NOW, 30, 400) == 0)
check("...and a nil list is an empty history",
      #mp.noteHistory(nil, nil, NOW, 30, 400) == 0)

-- 🕘 AND THE LOADER PRUNES, which is its own branch: a Mac left off for
-- six weeks must not come back with six weeks of rows and lose them one
-- play at a time.
reset()
READABLE[mp.storeFile] = "{}"
_G.FAKE_DECODE = { queue = {}, mode = "off", history = {
    { path = "/m/fresh.mp3", at = os.time() - DAY },
    { path = "/m/stale.mp3", at = os.time() - (60 * DAY) },
} }
mp.loaded = false
mp.loadStore()
check("🕘 a store holding a row older than the window is pruned AT THE "
      .. "LOADER, not on the next play",
      #mp.history == 1 and row(mp.history, 1).path == "/m/fresh.mp3",
      #mp.history .. " " .. row(mp.history, 1).path)
_G.FAKE_DECODE = nil

-- through the real player
reset()
FILES["/m/one.mp3"], FILES["/m/two.mp3"] = true, true
mp.show()
drop("file:///m/one.mp3\nfile:///m/two.mp3")
mp.playAt(2, "test") ; mp.playAt(1, "test") ; mp.playAt(2, "test")
check("🕘 four plays over two files leave TWO history rows",
      #mp.history == 2, #mp.history)
check("...the most recent play at the top",
      row(mp.history, 1).path == "/m/two.mp3", row(mp.history, 1).path)

local rh = report()
check("📋 the report says the window, not just a count",
      rh:find("30 day", 1, true) and rh:find("one row per file", 1, true), rh)

-- 🚨 The section asserts its own check count (6.186.0): a throw would
-- delete every check after it while the run still said "0 failed".
check("🚨 the suite asserted every check it was written to make",
      (pass + fail) >= 165, pass + fail)

os.execute("true")
realPrint(table.concat(PRINTED, "\n"))
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
