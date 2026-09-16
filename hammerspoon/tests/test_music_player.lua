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
    screen = { mainScreen = function()
        return { frame = function() return { x = 0, y = 0, w = 1440, h = 900 } end }
    end },
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
        function v:frame() return self.rect end
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
                   history = { { path = "/m/h.mp3", at = 5 }, 7 },
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

-- 🚨 The section asserts its own check count (6.186.0): a throw would
-- delete every check after it while the run still said "0 failed".
check("🚨 the suite asserted every check it was written to make",
      (pass + fail) >= 94, pass + fail)

os.execute("true")
realPrint(table.concat(PRINTED, "\n"))
out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
