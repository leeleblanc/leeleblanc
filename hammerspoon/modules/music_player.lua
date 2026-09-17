-- =====================================================================
-- MODULE: 🎵 MINI MUSIC PLAYER (⇪⇧pad.) — a card in the corner
-- =====================================================================
-- LL, 2026-09-13: "a lightweight player in the top-right corner like the
-- 3-month calendar. Repeat one / repeat all; history (click an item →
-- plays); elapsed time; drag-and-drop N files → the first plays, the rest
-- form a playlist under it, picked by click, ↑↓, or ⌘1–9."
--
-- 🔊 THE ENGINE IS hs.sound, WHICH IS NSSound, AND THAT DECIDED THE SCOPE.
-- LL answered the three questions this needed (2026-09-14): "just mp3,
-- m4a" — which NSSound plays natively, with no binary to install, so this
-- works identically on the work Mac where nothing can be brewed; "Both
-- macs use a full Apple Keyboard" — so ⇪⇧pad. needs no fallback key; and
-- "Native volume keys work" — so there is NO volume control here, and no
-- seek, because he did not ask for one. Both are his to add afterwards.
--
-- 📼 WHY A WEBVIEW AND NOT A CANVAS. hs.canvas has no drop target: a
-- canvas cannot be dragged onto. Drag-and-drop was the FIRST thing he
-- described, so the card is a webview on the Scorp Pad recipe — no
-- eventtap, no AX or window reads, every timer held.
--
-- 🚚 AND A DROPPED FILE'S PATH DOES NOT COME FROM `dataTransfer.files`.
-- WebKit does not expose a File's path to a page (it is the same rule
-- that stops a website reading your disk), so `files[0].name` is a NAME
-- and nothing this module can open. The path comes from the drag's
-- `text/uri-list`, which Finder fills with file:// URLs. A drag that
-- carries no uri-list is NOT silently dropped: the names are listed with
-- "macOS did not hand over the path" beside them, because a card that
-- ignored the drop would read as broken.
--
-- 🔁 REPEAT GOVERNS AN ENDING, NOT AN ASK. `mp.nextIndex` is PURE and
-- takes `manual`: when a track ENDS under repeat-one it plays again,
-- which is the whole point of the mode — but pressing ⏭ under repeat-one
-- moves ON, because a person who asks for the next track is asking for
-- the next track. Two callers, one rule, its own mutation.
--
-- 🔔 AND THE END-OF-TRACK CALLBACK HAS A BELT. hs.sound's callback is the
-- documented way to hear a track finish, and a callback this module
-- cannot prove fires is a playlist that stops after one song with no
-- error anywhere to see. So the held tick — which is running regardless,
-- to draw the elapsed time — also asks whether the sound has stopped
-- while we still think it is playing, and advances. Whichever arrives
-- first wins; `mp.advances` counts both so the report can say which one
-- is actually doing the work on this Mac.
--
-- 📁 THE STORE IS LOCAL, DELIBERATELY. The queue and the history go to
-- ~/Library/Application Support/Hammerspoon/music/player.json and never
-- to OneDrive: a half-played queue is not cross-Mac data, and 6.229.0
-- taught this config that a file written into a watched cloud folder
-- costs a main-thread wake-up for nothing.

local M = {
    name    = "Music player",
    order   = 13.66,                -- beside the pomodoro (13.65)
    family  = "time",
    summary = "⇪⇧pad. a small player in the top-right corner: drop files on "
              .. "it, ↑↓ or ⌘1–9 to pick, repeat one / repeat all, elapsed "
              .. "time, and a history you can click back into",
    cheatsheet = {
        title = "🎵 MUSIC PLAYER (⇪⇧pad. — a card in the corner, mp3 · m4a · wav · aiff)",
        entries = {
            { "⇪⇧pad.",  "Open / close the player" },
            { "drop",    "Drag files onto the card: the first plays, the rest queue under it" },
            { "↑ ↓ · ⏎", "Walk the queue · play the highlighted track" },
            { "⌘1–⌘9",   "Play the Nth track in the queue" },
            { "space",   "Play / pause" },
            { "⏮ ⏭",     "Previous · next — ⏭ moves on even under repeat one" },
            { "🔂 · 🔁",  "Repeat one · repeat all · off — click to cycle" },
            { "🕘",       "History: the last tracks played, click one to play it again" },
            { "⌫",       "Take the highlighted track out of the queue" },
            { "drag",    "Move the card: grab its title strip — or ⌘-drag anywhere on it. It reopens where you left it" },
            { "volume",  "Use the Mac's own volume keys — this player has none, by design" },
            { "Console", "_G.musicReport()" },
        },
    },
}

function M.setup(core)
    local mp = {
        enabled   = true,
        key       = "pad.",
        mods      = { "shift" },
        width     = 340,
        height    = 430,
        anchor    = "topRight",       -- "topRight" (like the calendar) or "center"
        gap       = 12,               -- points in from the screen edge
        alpha     = 0.97,
        fontSize  = 13,
        tickEvery = 0.5,              -- how often the elapsed time redraws
        maxQueue  = 200,
        maxHistory = 400,             -- the BOUND, not the rule; days decide
        historyDays = 30,             -- LL: "remember 30 days of history"
        historyShow = 40,             -- how many the card draws
        saveDelay = 0.3,
        -- 🎧 WHAT NSSound PLAYS. Not a guess and not a wish list: these are
        -- the container/codec pairs AVFoundation decodes on a stock Mac.
        -- FLAC and Ogg are deliberately absent — they do not play through
        -- hs.sound, and a file that cannot play says so per file rather
        -- than failing the drop.
        playable  = { mp3 = true, m4a = true, aac = true, mp4 = true,
                      wav = true, aiff = true, aif = true, caf = true },
        -- state
        queue     = {},               -- { path=, title=, bad= }
        history   = {},               -- { path=, title=, at= }
        index     = 0,                -- the track playing / highlighted
        sel       = 1,                -- the row the keyboard is on
        mode      = "off",            -- off · one · all
        playing   = false,
        startedAt = nil,
        elapsed   = 0,
        duration  = 0,
        lastWhy   = "nothing has been asked of it yet",
        advances  = { callback = 0, belt = 0, manual = 0 },
        refused   = {},               -- { path=, why= } — named, never silent
        loaded    = false,
        pos       = nil,              -- where he last dragged it, or nil
        posWhy    = "not opened yet",
        catcher   = nil,              -- the canvas that takes the drop
        dropWhy   = "not opened yet",
        dragSeen  = "no drag yet this session",
        dropReader = nil,             -- which pasteboard reader answered
        dropRefs  = "nothing read yet",
    }

    -- ---- PURE. Every rule about WHAT PLAYS and WHAT COMES NEXT lives
    -- ---- here, so the gate proves the whole of it with no Mac, no sound
    -- ---- card and no files on disk.

    function mp.extOf(path)
        if type(path) ~= "string" then return "" end
        local e = path:match("%.([%a%d]+)$")
        return e and e:lower() or ""
    end

    function mp.titleOf(path)
        if type(path) ~= "string" or path == "" then return "" end
        local base = path:match("([^/]+)$") or path
        return (base:gsub("%.[%a%d]+$", ""))
    end

    -- ok, why — never a bare false. A file this cannot play is named in
    -- the card WITH THE REASON, because "nothing happened" is the one
    -- answer a person cannot act on.
    function mp.playableFor(path)
        if type(path) ~= "string" or path == "" then
            return false, "not a path"
        end
        -- 🆔 A REFERENCE macOS WOULD NOT TURN BACK INTO A FILE. Reading the
        -- inode off the end of it as a file type is how the card came to
        -- say ".15194583 is not an audio file this can play" — a true
        -- sentence about a string that was never a name.
        if mp.isRefPath(path) then
            return false, "macOS handed a file reference, not a path — this "
                          .. "Mac could not turn it back into a file"
        end
        local ext = mp.extOf(path)
        if ext == "" then return false, "no file extension" end
        if mp.playable[ext] then return true, ext end
        if ext == "flac" or ext == "ogg" or ext == "opus" or ext == "wma" then
            return false, "." .. ext .. " does not play through macOS's own "
                          .. "audio — convert it to m4a"
        end
        return false, "." .. ext .. " is not an audio file this can play"
    end

    -- 🕐 ELAPSED, and h:mm:ss only when there are hours — a leading "0:"
    -- on every track is noise on a card this small.
    function mp.clock(secs)
        secs = math.floor(tonumber(secs) or 0)
        if secs < 0 then secs = 0 end
        local h = math.floor(secs / 3600)
        local m = math.floor((secs % 3600) / 60)
        local s = secs % 60
        if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
        return string.format("%d:%02d", m, s)
    end

    -- 🔁 THE REPEAT RULE, and the `manual` half is the whole reason it is
    -- its own function. Returns the next index, or nil for "stop".
    function mp.nextIndex(i, n, mode, manual)
        i, n = math.floor(tonumber(i) or 0), math.floor(tonumber(n) or 0)
        if n <= 0 then return nil end
        if i < 1 or i > n then return 1 end
        -- A track that ENDED under repeat-one plays again. A person who
        -- pressed ⏭ under repeat-one wants the NEXT track — the mode is
        -- about what the player does on its own, never about refusing an
        -- instruction.
        if mode == "one" and not manual then return i end
        if mode == "all" or (mode == "one" and manual) then
            return (i % n) + 1
        end
        if i < n then return i + 1 end
        return nil
    end

    -- 🕘 THIRTY DAYS, AND ONE ROW PER FILE (6.234.0, LL: "it's best if we
    -- have it remember 30 days of music track history. But, if it's the
    -- same file it should only be listed once"). PURE, so the whole rule
    -- is provable with no Mac and no clock: the row goes to the FRONT, any
    -- older row for the SAME FILE is removed rather than left behind, and
    -- anything past the window is dropped. The cap stays as a bound — a
    -- runaway list is still a runaway list — but the DAYS are the rule.
    function mp.noteHistory(list, row, now, days, max)
        local out = {}
        now = tonumber(now) or 0
        days = tonumber(days) or 30
        max = math.max(1, math.floor(tonumber(max) or 400))
        local cutoff = now - (days * 86400)
        if type(row) == "table" and type(row.path) == "string" and row.path ~= "" then
            out[1] = { path = row.path, title = row.title,
                       at = tonumber(row.at) or now }
        end
        for _, t in ipairs(type(list) == "table" and list or {}) do
            if type(t) == "table" and type(t.path) == "string" and t.path ~= "" then
                local at = tonumber(t.at) or 0
                -- SAME FILE = the same row, moved up. The path is the whole
                -- of "the same file" here: the queue is built from paths and
                -- nothing renames one behind our back.
                local dup = (out[1] and out[1].path == t.path)
                if not dup and at >= cutoff then
                    out[#out + 1] = { path = t.path, title = t.title, at = at }
                end
            end
        end
        while #out > max do table.remove(out) end
        return out
    end

    function mp.prevIndex(i, n)
        i, n = math.floor(tonumber(i) or 0), math.floor(tonumber(n) or 0)
        if n <= 0 then return nil end
        if i <= 1 then return n end
        return i - 1
    end

    -- Adds paths to a queue, PURELY: returns the new queue, what was
    -- added, and what was refused with each reason. A file already in the
    -- queue is not added twice — dropping the same folder again should
    -- not double the list.
    function mp.addPaths(queue, paths)
        local out, seen, added, refused = {}, {}, {}, {}
        for _, t in ipairs(queue or {}) do
            if type(t) == "table" and type(t.path) == "string" then
                out[#out + 1] = t
                seen[t.path] = true
            end
        end
        for _, p in ipairs(paths or {}) do
            if type(p) == "string" and p ~= "" then
                local ok, why = mp.playableFor(p)
                if not ok then
                    refused[#refused + 1] = { path = p, why = why }
                elseif seen[p] then
                    refused[#refused + 1] = { path = p, why = "already in the queue" }
                elseif #out >= (tonumber(mp.maxQueue) or 200) then
                    refused[#refused + 1] = { path = p, why = "the queue is full ("
                                              .. tostring(mp.maxQueue) .. ")" }
                else
                    local row = { path = p, title = mp.titleOf(p) }
                    out[#out + 1] = row
                    seen[p] = true
                    added[#added + 1] = row
                end
            end
        end
        return out, added, refused
    end

    -- 🆔 A FINDER DRAG HANDS BACK A REFERENCE, NOT A PATH (6.237.0, LL's
    -- own artefact: the card read "⚠️ .15194583 is not an audio file this
    -- can play" over an empty queue). macOS puts FILE REFERENCE URLs on a
    -- drag pasteboard — file:///.file/id=6571367.15194583 — which name a
    -- file by volume and inode and carry no name and no extension at all.
    -- The read was working by then; what came back was never a path.
    function mp.isRefPath(p)
        return type(p) == "string" and p:sub(1, 7) == "/.file/"
    end

    -- PURE given the resolver, so every branch is proven with a table and
    -- no Mac. Answers the paths, how many references were turned back into
    -- files, and how many were NOT — a reference we could not resolve is
    -- kept and named, never dropped in silence.
    function mp.resolveRefs(paths, resolve)
        local out, fixed, stuck = {}, 0, 0
        for _, p in ipairs(type(paths) == "table" and paths or {}) do
            if mp.isRefPath(p) then
                local got
                if type(resolve) == "function" then
                    local ok, v = pcall(resolve, p)
                    -- An answer is only an answer if it is an ABSOLUTE path
                    -- that is not itself a reference — realpath hands this
                    -- one straight back (see mp.refResolver).
                    if ok and type(v) == "string" and v:sub(1, 1) == "/"
                       and not mp.isRefPath(v) then
                        got = v
                    end
                end
                if got then
                    fixed = fixed + 1
                    out[#out + 1] = got
                else
                    stuck = stuck + 1
                    out[#out + 1] = p
                end
            else
                out[#out + 1] = p
            end
        end
        return out, fixed, stuck
    end

    -- 🚚 A DROP ARRIVES AS text/uri-list, one file:// URL per line. Blank
    -- lines and the format's own "#" comment lines are skipped, and the
    -- percent-escapes are undone — a track called "Ain't  It.mp3" arrives
    -- as Ain%27t%20%20It.mp3 and must open.
    function mp.pathsFromURIList(text)
        local out = {}
        if type(text) ~= "string" then return out end
        for line in (text .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and line:sub(1, 1) ~= "#" then
                -- 🔑 THE ESCAPES BELONG TO THE URL, NOT TO THE PATH. A
                -- plain POSIX path (NSFilenamesPboardType hands those over
                -- whole) may legally hold a % and two hex digits — "50%25
                -- off.mp3" is a real file name — and decoding one makes a
                -- path that is not there.
                local u = line:match("^file://(/.*)$")
                local p = u or (line:sub(1, 1) == "/" and line or nil)
                if u then
                    p = p:gsub("%%(%x%x)", function(h)
                        return string.char(tonumber(h, 16))
                    end)
                end
                if p and p ~= "" then out[#out + 1] = p end
            end
        end
        return out
    end

    -- ---- the thin IO half ------------------------------------------------

    local function say(what)
        mp.lastWhy = tostring(what)
        if _G.diag then pcall(_G.diag.say, "musicPlayer", tostring(what)) end
    end

    local function degrade(why)
        say(why)
        if type(core.degrade) == "function" then
            local ok = pcall(core.degrade, "Music player", why)
            if ok then return false, why end
        end
        pcall(function() hs.alert.show("⚠️ Music player — " .. why, 3) end)
        print("⚠️ Music player: " .. why)
        return false, why
    end

    mp.dir = (core.homeDir or os.getenv("HOME") or "")
             .. "/Library/Application Support/Hammerspoon/music"
    mp.storeFile = mp.dir .. "/player.json"

    function mp.loadStore()
        mp.loaded = true
        local f = io.open(mp.storeFile, "r")
        if not f then return end
        local raw = f:read("*a") ; f:close()
        if not raw or raw == "" then return end
        local ok, data = pcall(function() return hs.json.decode(raw) end)
        -- 🗂 6.198.1's rule: "it is a table" is not "it is MY table". Every
        -- row is shape-checked at the LOADER, once, rather than guarded at
        -- each of the five readers — one of which is the report, so a bad
        -- store would otherwise also take out the diagnostic naming it.
        if not (ok and type(data) == "table") then
            say("the saved queue could not be read — starting empty")
            return
        end
        local q = {}
        for _, t in ipairs(type(data.queue) == "table" and data.queue or {}) do
            if type(t) == "table" and type(t.path) == "string" and t.path ~= "" then
                q[#q + 1] = { path = t.path, title = mp.titleOf(t.path) }
            end
        end
        local h = {}
        for _, t in ipairs(type(data.history) == "table" and data.history or {}) do
            if type(t) == "table" and type(t.path) == "string" and t.path ~= "" then
                h[#h + 1] = { path = t.path, title = mp.titleOf(t.path),
                              at = tonumber(t.at) or 0 }
            end
        end
        -- Pruned at the LOADER as well as at the insert: a Mac left off for
        -- six weeks would otherwise come back with six weeks of rows and
        -- lose them only one play at a time.
        mp.queue = q
        mp.history = mp.noteHistory(h, nil, os.time(),
                                    mp.historyDays, mp.maxHistory)
        -- 🗂 6.198.1: the shape is checked here, once. A store written by
        -- an older build has no pos at all, and one hand-edited may hold
        -- anything — either way the card opens in the corner rather than
        -- at a coordinate nobody can read.
        local sp = data.pos
        if type(sp) == "table" and tonumber(sp.x) and tonumber(sp.y) then
            mp.pos = { x = tonumber(sp.x), y = tonumber(sp.y) }
        end
        if type(data.mode) == "string"
           and (data.mode == "off" or data.mode == "one" or data.mode == "all") then
            mp.mode = data.mode
        end
        mp.sel = 1
    end

    local function saveNow()
        pcall(function() hs.fs.mkdir(mp.dir) end)
        local q = {}
        for _, t in ipairs(mp.queue) do q[#q + 1] = { path = t.path } end
        local h = {}
        for i = 1, math.min(#mp.history, tonumber(mp.maxHistory) or 400) do
            h[#h + 1] = { path = mp.history[i].path, at = mp.history[i].at }
        end
        local ok, raw = pcall(function()
            return hs.json.encode({ queue = q, history = h, mode = mp.mode,
                                    pos = mp.pos })
        end)
        if not (ok and type(raw) == "string") then
            say("could not encode the queue — nothing was written")
            return false
        end
        local f = io.open(mp.storeFile, "w")
        if not f then
            say("could not write " .. mp.storeFile)
            return false
        end
        f:write(raw) ; f:close()
        return true
    end

    -- HELD in its own slot (6.196.1): a timer nothing references is
    -- collected, and a collected timer simply never fires.
    local function saveSoon()
        if mp.saveTimer then pcall(function() mp.saveTimer:stop() end) end
        local ok, t = pcall(hs.timer.doAfter, tonumber(mp.saveDelay) or 0.3,
                            function() pcall(saveNow) end)
        if ok and t then mp.saveTimer = t else pcall(saveNow) end
    end

    -- ---- playback ---------------------------------------------------------

    local function stopSound()
        if mp.sound then
            pcall(function() mp.sound:stop() end)
            pcall(function() mp.sound:setCallback(nil) end)
        end
        mp.sound, mp.playing = nil, false
    end

    local advance   -- forward declaration; the callback and the belt share it

    function mp.playAt(i, why)
        i = math.floor(tonumber(i) or 0)
        if #mp.queue == 0 then
            say("nothing in the queue")
            return false, "nothing in the queue"
        end
        if i < 1 or i > #mp.queue then return false, "no such track" end
        if not hs.sound then
            return degrade("this Hammerspoon has no hs.sound — the player "
                           .. "cannot play anything")
        end
        local row = mp.queue[i]
        -- A file that has gone is a STAT, never a read: reading to find
        -- out would download an evicted cloud file on the main thread.
        local gone = not (hs.fs and hs.fs.attributes
                          and hs.fs.attributes(row.path, "mode"))
        if gone then
            row.bad = "the file is not there any more"
            mp.render()
            say(row.title .. " — " .. row.bad)
            return false, row.bad
        end
        stopSound()
        local ok, snd = pcall(hs.sound.getByFile, row.path)
        if not (ok and snd) then
            -- ONE failed item, never the batch: the track is marked and
            -- the queue plays on.
            row.bad = "macOS refused to open this file"
            mp.render()
            say(row.title .. " — " .. row.bad)
            return false, row.bad
        end
        row.bad = nil
        mp.sound   = snd
        mp.index   = i
        mp.sel     = i
        mp.elapsed = 0
        local okDur, d = pcall(function() return snd:duration() end)
        mp.duration = (okDur and tonumber(d)) or 0
        pcall(function()
            snd:setCallback(function(_, finished)
                -- Any truthy finish advances; an hs.sound that reports
                -- something else is simply ignored rather than trusted.
                if finished then
                    mp.advances.callback = mp.advances.callback + 1
                    pcall(advance, false)
                end
            end)
        end)
        local okPlay = pcall(function() return snd:play() end)
        if not okPlay then
            row.bad = "macOS would not start playback"
            mp.render()
            return false, row.bad
        end
        mp.playing, mp.startedAt = true, os.time()
        mp.history = mp.noteHistory(mp.history,
                                    { path = row.path, title = row.title },
                                    os.time(), mp.historyDays, mp.maxHistory)
        saveSoon()
        mp.render()
        say("playing " .. row.title .. (why and (" (" .. why .. ")") or ""))
        return true
    end

    advance = function(manual)
        local nxt = mp.nextIndex(mp.index, #mp.queue, mp.mode, manual and true or false)
        if manual then mp.advances.manual = mp.advances.manual + 1 end
        if not nxt then
            stopSound()
            mp.elapsed = 0
            mp.render()
            say("end of the queue")
            return false
        end
        -- Repeat-one replays the SAME index, which means playAt must be
        -- called even when the index has not changed.
        return mp.playAt(nxt, manual and "next" or "track ended")
    end

    function mp.togglePlay()
        if not mp.sound then
            if #mp.queue > 0 then return mp.playAt(mp.sel > 0 and mp.sel or 1, "space") end
            say("nothing to play")
            return false
        end
        if mp.playing then
            pcall(function() mp.sound:pause() end)
            mp.playing = false
            say("paused")
        else
            pcall(function() mp.sound:resume() end)
            mp.playing = true
            say("resumed")
        end
        mp.render()
        return true
    end

    -- 🔔 THE BELT. hs.sound's callback is the documented way to hear a
    -- track end; this is what happens when it does not arrive. The tick is
    -- running anyway to draw the clock, so the check is free — and the two
    -- counters in the report say which one this Mac is actually using.
    local function tick()
        if not mp.webview then return end
        if mp.playing and mp.sound then
            local okE, e = pcall(function() return mp.sound:currentTime() end)
            if okE and tonumber(e) then
                mp.elapsed = tonumber(e)
            elseif mp.startedAt then
                mp.elapsed = os.time() - mp.startedAt
            end
            local okP, isPlaying = pcall(function() return mp.sound:isPlaying() end)
            local ended = (okP and isPlaying == false)
                          and (mp.duration <= 0 or mp.elapsed >= mp.duration - 1)
            if ended then
                mp.advances.belt = mp.advances.belt + 1
                pcall(advance, false)
                return
            end
        end
        mp.drawClock()
    end

    function mp.startTick()
        if mp.tickTimer then return end
        local ok, t = pcall(hs.timer.doEvery, tonumber(mp.tickEvery) or 0.5,
                            function() pcall(tick) end)
        if ok and t then mp.tickTimer = t end
    end

    function mp.stopTick()
        if mp.tickTimer then pcall(function() mp.tickTimer:stop() end) end
        mp.tickTimer = nil
    end

    -- ---- the page ---------------------------------------------------------

    function mp.rowsJson()
        local rows = {}
        for i, t in ipairs(mp.queue) do
            rows[#rows + 1] = {
                i = i, n = t.title, bad = t.bad or false,
                cur = (i == mp.index),
            }
        end
        local hist = {}
        for i = 1, math.min(#mp.history, tonumber(mp.historyShow) or 40) do
            hist[#hist + 1] = { n = mp.history[i].title, p = mp.history[i].path }
        end
        local ok, raw = pcall(function()
            return hs.json.encode({ rows = rows, hist = hist, sel = mp.sel,
                                    mode = mp.mode, playing = mp.playing,
                                    refused = mp.refused })
        end)
        if ok and raw then return raw end
        -- 🔔 A NAME THIS CANNOT ENCODE IS NOT AN EMPTY QUEUE. Returning
        -- "{}" here drew a card with nothing in it over a queue that was
        -- still playing, and said so to nobody.
        degrade("a track name could not be turned into text the card can "
                .. "draw — the queue is untouched and still playing")
        return '{"rows":[],"hist":[],"sel":1,"mode":"' .. tostring(mp.mode)
               .. '","playing":' .. tostring(mp.playing and true or false)
               .. ',"refused":[{"path":"","why":"a track name could not be '
               .. 'drawn — see the Console"}]}'
    end

    function mp.drawClock()
        if not mp.webview then return end
        local line = mp.clock(mp.elapsed)
                     .. (mp.duration > 0 and (" / " .. mp.clock(mp.duration)) or "")
        local pct = (mp.duration > 0)
                    and math.max(0, math.min(100, (mp.elapsed / mp.duration) * 100))
                    or 0
        pcall(function()
            mp.webview:evaluateJavaScript(
                ("clock(%q, %f);"):format(line, pct))
        end)
    end

    function mp.render()
        if not mp.webview then return end
        pcall(function()
            mp.webview:evaluateJavaScript("draw(" .. mp.rowsJson() .. ");")
        end)
        mp.drawClock()
    end

    local function buildHtml()
        local fs  = math.max(10, math.floor(tonumber(mp.fontSize) or 13))
        local fs1 = math.max(10, fs - 1)
        local fs2 = math.max(10, fs - 2)
        return ([[<!DOCTYPE html><html><head><meta charset="utf-8"><style>
* { box-sizing: border-box; }
html, body { margin:0; padding:0; height:100%%; overflow:hidden;
  background:#15161a; color:#e7e7ea;
  font:%dpx -apple-system, "Helvetica Neue", sans-serif; }
#card { display:flex; flex-direction:column; height:100%%; }
header { padding:8px 10px 6px; -webkit-user-select:none; cursor:grab;
  border-bottom:1px solid #2a2c33; }
header.dragging { cursor:grabbing; background:#1b1d23; }
#now { font-size:%dpx; font-weight:600; white-space:nowrap;
  overflow:hidden; text-overflow:ellipsis; }
#sub { font-size:%dpx; color:#9a9aa4; margin-top:2px; }
#bar { height:3px; background:#2a2c33; border-radius:2px; margin-top:6px; }
#fill { height:3px; width:0%%; background:#6aa9ff; border-radius:2px; }
#ctl { display:flex; gap:6px; align-items:center; padding:6px 10px;
  border-bottom:1px solid #2a2c33; }
button { background:#22242b; color:#e7e7ea; border:1px solid #33353e;
  border-radius:6px; padding:3px 9px; font-size:%dpx; cursor:pointer; }
button:hover { background:#2b2e37; }
button.armed { background:#25406b; border-color:#3b5f96; }
#wrap { flex:1; overflow:auto; }
.row { display:flex; gap:6px; padding:4px 10px; font-size:%dpx;
  cursor:pointer; white-space:nowrap; }
.row:hover { background:#1e2027; }
.row.sel { background:#25406b; }
.row.cur .nm { color:#8fc0ff; font-weight:600; }
.num { color:#6e7079; width:20px; text-align:right; flex:none; }
.nm { overflow:hidden; text-overflow:ellipsis; }
.bad { color:#ff9a9a; font-size:%dpx; }
.sec { padding:6px 10px 2px; font-size:%dpx; color:#7d7f89;
  text-transform:uppercase; letter-spacing:.06em; }
#drop { position:absolute; inset:0; display:none; align-items:center;
  justify-content:center; background:rgba(37,64,107,.85); font-size:%dpx; }
#drop.show { display:flex; }
footer { padding:5px 10px; font-size:%dpx; color:#7d7f89;
  border-top:1px solid #2a2c33; white-space:nowrap;
  overflow:hidden; text-overflow:ellipsis; }
</style></head><body>
<div id="card">
  <header id="hd">
    <div id="now">nothing playing</div>
    <div id="sub">drop music here</div>
    <div id="bar"><div id="fill"></div></div>
  </header>
  <div id="ctl">
    <button id="prev" title="Previous">&#9198;</button>
    <button id="play" title="Play / pause">&#9654;</button>
    <button id="next" title="Next">&#9197;</button>
    <button id="rep" title="Repeat off / one / all">&#8594;</button>
    <span style="flex:1"></span>
    <button id="clr" title="Empty the queue">clear</button>
  </div>
  <div id="wrap"><div id="list"></div></div>
  <footer id="ft">&#8593;&#8595; pick &#183; &#8629; play &#183; space pause &#183; &#8984;1-9</footer>
</div>
<div id="drop">drop to add</div>
<script>
var S = { rows: [], hist: [], sel: 1, mode: 'off', playing: false, refused: [] };
var dz;
function say(m){ try { webkit.messageHandlers.musicPlayer.postMessage(m); } catch(e){} }
function el(id){ return document.getElementById(id); }
dz = el('drop');
/* 🔤 A TRACK IS NAMED BY ITS FILE, AND A FILE MAY BE CALLED ANYTHING.
   Every name below is written with innerHTML, so "AC/DC <Live> & More.mp3"
   would lose half of itself. The name is NOT escaped on the Lua side: the
   header writes the same string with textContent, where an entity shows. */
function esc(s){
  return String(s == null ? '' : s).replace(/&/g, '&amp;')
    .replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function draw(s){
  /* A payload that is missing a field must not stop the card drawing for
     the rest of the session — every list below is read by length. */
  if (s) S = { rows: s.rows || [], hist: s.hist || [], sel: s.sel || 1,
               mode: s.mode || 'off', playing: !!s.playing,
               refused: s.refused || [] };
  var L = [], r;
  for (var i = 0; i < S.rows.length; i++) {
    r = S.rows[i];
    L.push('<div class="row' + (r.i === S.sel ? ' sel' : '')
           + (r.cur ? ' cur' : '') + '" data-i="' + r.i + '">'
           + '<span class="num">' + r.i + '</span>'
           + '<span class="nm">' + esc(r.n) + '</span>'
           + (r.bad ? '<span class="bad">' + esc(r.bad) + '</span>' : '')
           + '</div>');
  }
  if (!S.rows.length) L.push('<div class="sec">queue empty &#183; drop files on this card</div>');
  for (var k = 0; k < (S.refused || []).length; k++) {
    L.push('<div class="row"><span class="num">&#9888;</span><span class="bad">'
           + esc(S.refused[k].why) + '</span></div>');
  }
  if ((S.hist || []).length) {
    L.push('<div class="sec">&#128336; history</div>');
    for (var h = 0; h < S.hist.length; h++) {
      L.push('<div class="row" data-h="' + h + '"><span class="num">&#183;</span>'
             + '<span class="nm">' + esc(S.hist[h].n) + '</span></div>');
    }
  }
  el('list').innerHTML = L.join('');
  el('play').innerHTML = S.playing ? '&#10073;&#10073;' : '&#9654;';
  var rp = el('rep');
  rp.innerHTML = S.mode === 'one' ? '&#128258;' : (S.mode === 'all' ? '&#128257;' : '&#8594;');
  rp.className = (S.mode === 'off') ? '' : 'armed';
  var cur = null;
  for (var j = 0; j < S.rows.length; j++) if (S.rows[j].cur) cur = S.rows[j];
  el('now').textContent = cur ? cur.n : 'nothing playing';
  el('sub').textContent = S.rows.length
      ? (S.rows.length + ' track' + (S.rows.length === 1 ? '' : 's')
         + ' · repeat ' + S.mode)
      : 'drop music here';
  var sel = document.querySelector('.row.sel');
  if (sel && sel.scrollIntoView) sel.scrollIntoView({ block: 'nearest' });
}
/* 🚚 The veil is driven from LUA now: the window's dragging callback is
   what actually sees a Finder drag (the page never does). The page's own
   dragover/drop handlers below are kept — they cost nothing and are the
   door a WebKit that CAN drop would use. */
function dropShow(on){ dz.classList[on ? 'add' : 'remove']('show'); }
function clock(text, pct){
  var b = el('sub');
  if (b && S.rows.length) {
    var cur = null;
    for (var j = 0; j < S.rows.length; j++) if (S.rows[j].cur) cur = S.rows[j];
    if (cur) b.textContent = text + '  ·  repeat ' + S.mode;
  }
  el('fill').style.width = (pct || 0) + '%%';
}

/* 🪟 The title strip is the grip: press and move, no modifier. Lua drives
   the move from here (window_move's _G.beginPanelDrag), because a page
   cannot move the window it is drawn in. ⌘-drag anywhere on the card
   works too and needs nothing from this page. */
var hd = el('hd');
hd.addEventListener('mousedown', function(ev){
  if (ev.preventDefault) ev.preventDefault();
  hd.classList.add('dragging');
  say({a:'dragStart'});
});
document.addEventListener('mouseup', function(){ hd.classList.remove('dragging'); });

el('prev').addEventListener('click', function(){ say({a:'prev'}); });
el('next').addEventListener('click', function(){ say({a:'next'}); });
el('play').addEventListener('click', function(){ say({a:'play'}); });
el('rep').addEventListener('click',  function(){ say({a:'repeat'}); });
el('clr').addEventListener('click',  function(){ say({a:'clear'}); });
el('list').addEventListener('click', function(e){
  var r = e.target.closest ? e.target.closest('[data-i],[data-h]') : null;
  if (!r) return;
  if (r.getAttribute('data-i')) say({a:'pick', i: +r.getAttribute('data-i')});
  else say({a:'hist', h: +r.getAttribute('data-h')});
});

/* 🚚 The path comes from text/uri-list. dataTransfer.files gives NAMES
   only — WebKit does not hand a page a file's path — so a drop with no
   uri-list reports the names it saw and says what is missing. */
document.addEventListener('dragover', function(e){
  e.preventDefault(); dz.classList.add('show');
});
document.addEventListener('dragleave', function(e){
  if (e.target === document || e.relatedTarget === null) dz.classList.remove('show');
});
document.addEventListener('drop', function(e){
  e.preventDefault(); dz.classList.remove('show');
  var uri = '';
  try { uri = e.dataTransfer.getData('text/uri-list') || ''; } catch (x) {}
  if (!uri) { try { uri = e.dataTransfer.getData('text/plain') || ''; } catch (x) {} }
  var names = [];
  try {
    for (var i = 0; i < (e.dataTransfer.files || []).length; i++)
      names.push(e.dataTransfer.files[i].name);
  } catch (x) {}
  say({ a: 'drop', uri: uri, names: names });
});

document.addEventListener('keydown', function(e){
  var k = e.key;
  /* ⇪'s F18 keyup is forwarded so the hold ends with the window open. */
  if (e.metaKey && k >= '1' && k <= '9') { e.preventDefault(); say({a:'pick', i:+k}); return; }
  if (k === 'ArrowDown' || (e.altKey && k === 'ArrowDown')) { e.preventDefault(); say({a:'sel', d:1}); return; }
  if (k === 'ArrowUp'   || (e.altKey && k === 'ArrowUp'))   { e.preventDefault(); say({a:'sel', d:-1}); return; }
  if (k === 'Enter') { e.preventDefault(); say({a:'pick', i: S.sel}); return; }
  if (k === ' ')     { e.preventDefault(); say({a:'play'}); return; }
  if (k === 'Backspace' || k === 'Delete') { e.preventDefault(); say({a:'remove', i:S.sel}); return; }
  if (k === 'Escape') { e.preventDefault(); say({a:'esc'}); return; }
});
document.addEventListener('keyup', function(e){
  if (e.key === 'F18' || e.keyCode === 79) say({a:'f18'});
});
draw(S);
</script></body></html>]]):format(fs, fs, fs2, fs2, fs1, fs2, fs2, fs1, fs2)
    end

    -- 🚚 ONE DOOR FOR A DROP, whichever way it arrived — the window's own
    -- dragging callback (the only one that works, 6.233.0) or the page's
    -- HTML5 handler. Two doors into one function, or the two behaviours
    -- drift and only one of them is ever tested.
    function mp.takeDrop(paths, names)
        paths = type(paths) == "table" and paths or {}
        if #paths == 0 then
            -- NOT silent. A drop that carries no path is the one case
            -- where the card looks broken and is not.
            local seen = {}
            for _, n in ipairs(type(names) == "table" and names or {}) do
                seen[#seen + 1] = tostring(n)
            end
            mp.refused = { { path = "", why = (#seen > 0)
                and ("macOS did not hand over the path for "
                     .. table.concat(seen, ", ") .. " — drag from Finder")
                or "that drop carried no files" } }
            mp.render()
            say(mp.refused[1].why)
            return false
        end
        local wasEmpty = (#mp.queue == 0)
        local q, added, refused = mp.addPaths(mp.queue, paths)
        mp.queue, mp.refused = q, refused
        saveSoon() ; mp.render()
        say(#added .. " added, " .. #refused .. " refused")
        -- "the first plays, the rest form a playlist under it" — his
        -- words, and only when nothing was already going.
        if #added > 0 and (wasEmpty or not mp.playing) then
            for i, t in ipairs(mp.queue) do
                if t.path == added[1].path then mp.playAt(i, "dropped") break end
            end
        end
        return true
    end

    -- ---- the bridge -------------------------------------------------------

    local function handleMessage(b)
        if type(b) ~= "table" then return end
        local a = b.a
        if a == "f18" then
            if _G.hyperReleaseSeen then pcall(_G.hyperReleaseSeen, "musicPlayer") end
            return
        end
        if a == "esc"    then mp.hide() return end
        -- 🪟 The title strip drags with a BARE click — the header rule
        -- (6.89.0): a header is safe by construction, because there is
        -- nothing on it a click could have meant instead.
        if a == "dragStart" then
            if _G.beginPanelDrag then
                if not _G.beginPanelDrag("music player") then
                    say("the card could not be picked up")
                end
            else
                say("window_move is off — the header cannot drag "
                    .. "(⌘-drag needs it too)")
            end
            return
        end
        if a == "play"   then mp.togglePlay() return end
        if a == "next"   then advance(true) return end
        if a == "prev"   then
            local p = mp.prevIndex(mp.index, #mp.queue)
            if p then mp.playAt(p, "previous") end
            return
        end
        if a == "repeat" then
            mp.mode = (mp.mode == "off") and "all"
                      or ((mp.mode == "all") and "one" or "off")
            saveSoon() ; mp.render()
            say("repeat " .. mp.mode)
            return
        end
        if a == "clear" then
            stopSound()
            mp.queue, mp.index, mp.sel, mp.elapsed, mp.duration = {}, 0, 1, 0, 0
            mp.refused = {}
            saveSoon() ; mp.render()
            say("queue emptied")
            return
        end
        if a == "sel" then
            local n = #mp.queue
            if n == 0 then return end
            local d = tonumber(b.d) or 1
            mp.sel = ((mp.sel - 1 + d) % n) + 1
            mp.render()
            return
        end
        if a == "pick" then
            local i = tonumber(b.i)
            if i then mp.playAt(i, "picked") end
            return
        end
        if a == "remove" then
            local i = math.floor(tonumber(b.i) or 0)
            if i >= 1 and i <= #mp.queue then
                local wasCurrent = (i == mp.index)
                table.remove(mp.queue, i)
                if wasCurrent then stopSound() ; mp.index = 0 ; mp.elapsed = 0 end
                if mp.index > i then mp.index = mp.index - 1 end
                if mp.sel > #mp.queue then mp.sel = math.max(1, #mp.queue) end
                saveSoon() ; mp.render()
            end
            return
        end
        if a == "hist" then
            local h = math.floor(tonumber(b.h) or -1) + 1
            local row = mp.history[h]
            if not row then return end
            local q, added = mp.addPaths(mp.queue, { row.path })
            mp.queue = q
            local target
            for i, t in ipairs(mp.queue) do if t.path == row.path then target = i end end
            if target then mp.playAt(target, "from history") end
            if #added == 0 and not target then say("that track has gone") end
            return
        end
        if a == "drop" then
            mp.takeDrop(mp.pathsFromURIList(b.uri), b.names)
            return
        end
    end

    -- ---- THE DROP CATCHER -------------------------------------------------
    -- 🚚 6.233.0, AND IT IS THE OPPOSITE OF WHAT 6.231.0 BELIEVED.
    -- CHECKED IN THE SOURCE, not remembered: extensions/webview/libwebview.m
    -- contains the string "dragg" exactly ZERO times — hs.webview has no
    -- drag-and-drop of any kind, so this card could never have received a
    -- file, and a drag over it fell through to whatever was behind. That
    -- is LL's report word for word. hs.canvas is the one that CAN:
    -- `hs.canvas:draggingCallback(fn)`, with two conditions its own docs
    -- state — the window must be at `windowLevels.dragging` or LOWER, and
    -- it must accept mouse events, which means a mouseCallback must exist
    -- even as a placeholder.
    --
    -- 🎯 SO THE CATCHER SITS UNDER THE CARD. An invisible canvas at the
    -- card's exact frame, at the dragging level; the webview is at
    -- bringToFront(true) (≈ screenSaver) and stays above it. A window that
    -- does not register dragged types is SKIPPED by the drag, so the only
    -- thing that ever reaches the catcher is a drag the card refused —
    -- clicks, keys and the scroll wheel still belong to the page.
    -- 🧷 JOIN WHAT A READER ANSWERED, WHATEVER IT ANSWERED WITH. This is
    -- the bug LL saw as "it turns blue but the drop does nothing": a bare
    -- `table.concat(u, "\n")` THROWS on a list holding anything that is
    -- not a string or a number, and hs.pasteboard's readers answer with
    -- whatever LuaSkin made of the objects on that pasteboard. The throw
    -- happened INSIDE a dragging callback, where there is nothing to catch
    -- it and nothing to see — the veil had already been taken down.
    function mp.joinLines(v)
        if type(v) == "string" then return v end
        if type(v) ~= "table" then return nil end
        local out = {}
        for _, item in ipairs(v) do
            if type(item) == "string" then
                out[#out + 1] = item
            elseif type(item) == "number" then
                out[#out + 1] = tostring(item)
            elseif type(item) == "table" then
                -- Some readers answer with a table per item; the url is
                -- whatever string is in it.
                for _, k in ipairs({ "url", "path", "absoluteString", 1 }) do
                    if type(item[k]) == "string" then
                        out[#out + 1] = item[k] ; break
                    end
                end
            end
        end
        if #out == 0 then return nil end
        return table.concat(out, "\n")
    end

    -- 🔗 THE ONE THING THAT RESOLVES A FILE REFERENCE, and it is NOT
    -- realpath. CHECKED IN THE SOURCE (Libc, stdlib/FreeBSD/realpath.c):
    -- realpath walks a path component by component and REPLACES each with
    -- the real NAME that getattrlist answers — so /.file/id=6571367.15194583
    -- comes back as "/.file/Max McNown - A Lot More Free.mp3", the right
    -- name in a folder that holds nothing, which would have filled the
    -- queue with plausible rows that cannot open. A BOOKMARK does resolve
    -- it: making one records where the file actually IS, and reading it
    -- back answers that path. Degrades to nil — never throws, because this
    -- runs inside a dragging callback.
    function mp.refResolver(p)
        if not (hs.fs and hs.fs.pathToBookmark and hs.fs.pathFromBookmark) then
            return nil
        end
        local okB, data = pcall(hs.fs.pathToBookmark, p)
        if not (okB and type(data) == "string" and data ~= "") then return nil end
        local okP, got = pcall(hs.fs.pathFromBookmark, data)
        if not (okP and type(got) == "string" and got ~= "") then return nil end
        return got
    end

    function mp.dropPaths(pbName)
        -- Every reader macOS might answer on, first that yields a path
        -- wins, and the report names WHICH — a drop that fails on one Mac
        -- and works on another is otherwise unanswerable.
        if pbName == false then pbName = nil end
        -- 🚨 READ THREE VALUES, NOT TWO (6.179.0, and I broke it here).
        -- `select(2, pcall(f))` is the RESULT when f returns and the ERROR
        -- MESSAGE when it raises — and a Lua error message begins with the
        -- chunk name, so on a Mac it reads "/Users/…/music_player.lua:612:
        -- …". That starts with a slash, which `pathsFromURIList` accepts as
        -- a plain-text drag, so a reader that FAILED would have handed its
        -- own traceback back as a file to play. Caught by the gate only
        -- because it runs the suite from an absolute path.
        local function ask(fn, ...)
            local args = table.pack(...)
            local ok, v = pcall(function() return fn(table.unpack(args, 1, args.n)) end)
            if not ok then return nil end
            return mp.joinLines(v)
        end
        local tries = {
            -- 📁 THE PLAIN-PATH FLAVOUR IS ASKED FIRST. NSFilenamesPboardType
            -- is a plist ARRAY OF POSIX PATHS, so where macOS still offers
            -- it the reference-URL problem below never arises at all.
            { "filenames", function()
                return ask(hs.pasteboard.readPListForUTI, pbName,
                           "NSFilenamesPboardType")
            end },
            { "readURL", function()
                return ask(hs.pasteboard.readURL, pbName, true)
            end },
            -- public.file-url is the type a Finder drag actually carries,
            -- asked for by name in case the object readers do not see it.
            { "file-url", function()
                return ask(hs.pasteboard.readDataForUTI, pbName, "public.file-url")
            end },
            { "readString", function()
                return ask(hs.pasteboard.readString, pbName, true)
            end },
            { "getContents", function()
                return ask(hs.pasteboard.getContents, pbName)
            end },
        }
        for _, t in ipairs(tries) do
            -- 🔒 EVERY READER IS WRAPPED WHOLE, not just its hs call. A
            -- throw here reaches a dragging callback, and a callback that
            -- throws does nothing and says nothing.
            local okR, raw = pcall(t[2])
            if okR and raw and raw ~= "" then
                local paths = mp.pathsFromURIList(raw)
                if #paths > 0 then
                    local fixed, stuck
                    paths, fixed, stuck = mp.resolveRefs(paths, mp.refResolver)
                    mp.dropRefs = (fixed + stuck == 0)
                        and "no file references — plain paths"
                        or (fixed .. " file reference(s) turned back into "
                            .. "files, " .. stuck .. " could not be")
                    return paths, t[1]
                end
            end
        end
        -- 🔎 NOTHING ANSWERED — so say what the drag was actually CARRYING.
        -- Without this the next report can only repeat "it did not work".
        local okT, types = pcall(hs.pasteboard.pasteboardTypes, pbName)
        local list = okT and mp.joinLines(types) or nil
        if not okT then list = nil end
        return {}, "nothing readable" .. (list
               and (" — the drag carried: " .. list:gsub("\n", ", ")) or "")
    end

    function mp.startCatcher(rect)
        mp.stopCatcher()
        if not (hs.canvas and hs.canvas.new) then
            mp.dropWhy = "this Hammerspoon has no hs.canvas — nothing can "
                         .. "catch a dragged file"
            return degrade(mp.dropWhy)
        end
        local okC, cv = pcall(hs.canvas.new, rect)
        if not (okC and cv) then
            mp.dropWhy = "the drop catcher could not be created"
            return degrade(mp.dropWhy)
        end
        -- A surface, not a picture: it lives behind an opaque card and is
        -- never seen. What matters is that the VIEW exists at this frame.
        pcall(function()
            cv[1] = { type = "rectangle", action = "fill",
                      fillColor = { red = 0, green = 0, blue = 0, alpha = 0 } }
        end)
        -- REQUIRED by hs.canvas: no mouse events, no drags. Placeholder is
        -- what the documentation itself calls for.
        pcall(function() cv:mouseCallback(function() end) end)
        local okL = pcall(function()
            cv:level(hs.canvas.windowLevels.dragging)
        end)
        if not okL then
            mp.dropWhy = "this Hammerspoon has no dragging window level"
            pcall(function() cv:delete() end)
            return degrade(mp.dropWhy)
        end
        local okD = pcall(function()
            cv:draggingCallback(function(_, msg, details)
                if msg == "enter" then
                    mp.dragSeen = "a drag came over the card"
                    pcall(function()
                        mp.webview:evaluateJavaScript("dropShow(true);")
                    end)
                    return true
                elseif msg == "exit" then
                    pcall(function()
                        mp.webview:evaluateJavaScript("dropShow(false);")
                    end)
                    return true
                elseif msg == "receive" then
                    pcall(function()
                        mp.webview:evaluateJavaScript("dropShow(false);")
                    end)
                    -- 🔒 THE WHOLE RECEIVE IS WRAPPED. A dragging callback
                    -- that throws does nothing at all and says nothing at
                    -- all, which is indistinguishable from a drop macOS
                    -- never delivered — and that is exactly the shape LL
                    -- reported: the card lit up and then nothing happened.
                    local okR, err = pcall(function()
                        local pb = type(details) == "table"
                                   and details.pasteboard or nil
                        local paths, how = mp.dropPaths(pb)
                        mp.dropReader = how
                        mp.dragSeen = #paths .. " file(s) dropped on the card"
                        mp.takeDrop(paths, nil)
                    end)
                    if not okR then
                        mp.dragSeen = "a drop arrived and the handler threw"
                        degrade("the drop could not be read — " .. tostring(err))
                    end
                    return true
                end
                return true
            end)
        end)
        if not okD then
            mp.dropWhy = "this Hammerspoon's hs.canvas cannot accept drags"
            pcall(function() cv:delete() end)
            return degrade(mp.dropWhy)
        end
        pcall(function() cv:show() end)
        mp.catcher = cv
        mp.dropWhy = "ready"
        return true
    end

    function mp.stopCatcher()
        if mp.catcher then
            pcall(function() mp.catcher:delete() end)
            mp.catcher = nil
        end
    end

    function mp.moveCatcher(f)
        if mp.catcher and type(f) == "table" then
            pcall(function() mp.catcher:frame(f) end)
        end
    end

    -- ---- the window -------------------------------------------------------

    -- 🧪 The gate DUMPS this page and runs its JavaScript for real
    -- (tests/dump_music_html.lua → tests/test_music_js.js).
    mp.buildHtml = buildHtml

    function mp.hide()
        mp.stopTick()
        mp.stopCatcher()
        if mp.webview then
            pcall(function() mp.webview:delete() end)
            mp.webview = nil
        end
        mp.uc = nil
        -- Deliberately NOT stopping the sound: closing the card is putting
        -- the card away, not stopping the music. ⇪⇧pad. brings it back
        -- with the track still going.
        say("card closed")
    end

    function mp.frameFor(sf)
        sf = sf or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(mp.width, sf.w - 40)
        local h = math.min(mp.height, sf.h - 40)
        local gap = tonumber(mp.gap) or 12
        if mp.anchor == "center" then
            return { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 3,
                     w = w, h = h }
        end
        return { x = sf.x + sf.w - w - gap, y = sf.y + gap, w = w, h = h }
    end

    -- 🪟 WHERE THE CARD GOES, AND IT IS A REMEMBERED SPOT OR THE CORNER.
    -- PURE: given a remembered top-left, the screen it must live on and
    -- every screen attached right now, it answers the rect AND why — so
    -- the report can say "you moved it here" apart from "back in the
    -- corner because that spot is on a monitor you have unplugged".
    -- 6.196.0's rule for the cheat sheet, applied: a remembered position
    -- that does not fall on a screen is DROPPED for the default, never
    -- clamped onto the edge of a screen it was never on.
    function mp.placeFor(pos, sf, screens)
        local base = mp.frameFor(sf)
        if type(pos) ~= "table" then return base, "corner" end
        local x, y = tonumber(pos.x), tonumber(pos.y)
        if not (x and y) then return base, "corner" end
        for _, f in ipairs(screens or {}) do
            if type(f) == "table" and tonumber(f.x) and tonumber(f.w)
               and x >= f.x and x < f.x + f.w
               and y >= f.y and y < f.y + f.h then
                -- Clamped to fit that screen WHOLE. A card remembered
                -- three-quarters off the bottom is a card whose header
                -- cannot be grabbed again, and the grip is the fix for
                -- the thing this release exists to fix.
                local cx = math.max(f.x, math.min(x, f.x + f.w - base.w))
                local cy = math.max(f.y, math.min(y, f.y + f.h - base.h))
                return { x = cx, y = cy, w = base.w, h = base.h },
                       (cx == x and cy == y) and "moved"
                       or "moved — nudged back onto the screen"
            end
        end
        return base, "corner — the remembered spot is on no screen now"
    end

    function mp.show()
        if mp.webview then mp.hide() return true end
        if not mp.enabled then
            say("off — settings = { music_player = { enabled = false } }")
            return false
        end
        if not mp.loaded then pcall(mp.loadStore) end
        if not (hs.webview and hs.webview.usercontent) then
            return degrade("this Hammerspoon has no hs.webview — the player "
                           .. "needs a window that files can be dropped on")
        end
        local screen = (core.resolveBaseScreen and core.resolveBaseScreen())
                       or hs.screen.mainScreen()
        local sf = (screen and screen:frame()) or { x = 0, y = 0, w = 1440, h = 900 }
        local all = {}
        local okS, list = pcall(function() return hs.screen.allScreens() end)
        for _, sc in ipairs((okS and list) or {}) do
            local okF, f = pcall(function() return sc:frame() end)
            if okF and type(f) == "table" then all[#all + 1] = f end
        end
        if #all == 0 then all = { sf } end
        local rect, why = mp.placeFor(mp.pos, sf, all)
        mp.posWhy = why

        local okUc, uc = pcall(hs.webview.usercontent.new, "musicPlayer")
        if not (okUc and uc) then
            return degrade("could not open the page bridge")
        end
        mp.uc = uc      -- HELD: collect this and the JS bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then print("🎵 Music player: message handler — " .. tostring(err)) end
            end)
        end)
        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then
            mp.uc = nil
            return degrade("could not open the player window")
        end
        mp.webview = view
        pcall(function() view:windowTitle("Music") end)
        -- Without allowTextEntry the card draws perfectly and swallows
        -- every keystroke — ↑↓, space and ⌘1–9 would all be dead.
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        if (tonumber(mp.alpha) or 1) < 1 then
            pcall(function() view:alpha(tonumber(mp.alpha)) end)
        end
        pcall(function() view:html(buildHtml()) end)
        pcall(function() view:show() end)
        pcall(function() view:bringToFront(true) end)
        -- ⇪ HANDSHAKE (6.165.1): this card takes the keyboard, so the hold
        -- must be allowed to end while it is up.
        if _G.hyperExpectRelease then
            pcall(_G.hyperExpectRelease, 1.5, "musicPlayer")
        end
        -- 🚚 The card cannot take a dragged file itself; the catcher does.
        -- Started AFTER the window exists, because it is placed at the
        -- window's frame and reports through the window's page.
        pcall(function() mp.startCatcher(rect) end)
        mp.startTick()
        mp.render()
        say("card opened")
        return true
    end

    function mp.toggle()
        if mp.webview then mp.hide() return true end
        return mp.show()
    end

    -- ---- the report -------------------------------------------------------

    function _G.musicReport()
        local L = { "🎵 MUSIC PLAYER — ⇪⇧pad." }
        local function line(t) L[#L + 1] = t end
        line("   card     : " .. (mp.webview and "open" or "closed")
             .. " · " .. tostring(mp.anchor)
             .. (mp.enabled and "" or " · OFF by settings"))
        line("   engine   : " .. (hs.sound and "hs.sound (macOS's own)"
                                          or "⚠️ NO hs.sound — nothing can play"))
        if #mp.queue == 0 then
            line("   queue    : empty — drop files on the card")
        else
            line("   queue    : " .. #mp.queue .. " track(s) · repeat " .. tostring(mp.mode))
            for i, t in ipairs(mp.queue) do
                if i <= 12 then
                    line("      " .. i .. ". " .. tostring(t.title)
                         .. (i == mp.index and "   ← playing" or "")
                         .. (t.bad and ("   ⚠️ " .. t.bad) or ""))
                end
            end
            if #mp.queue > 12 then line("      … " .. (#mp.queue - 12) .. " more") end
        end
        if mp.index > 0 and mp.queue[mp.index] then
            line("   now      : " .. tostring(mp.queue[mp.index].title)
                 .. " · " .. mp.clock(mp.elapsed)
                 .. (mp.duration > 0 and (" / " .. mp.clock(mp.duration)) or "")
                 .. (mp.playing and " · playing" or " · paused"))
        else
            line("   now      : nothing playing")
        end
        -- 🔔 WHICH HALF IS DOING THE WORK. If "callback" stays 0 while
        -- "belt" climbs, hs.sound's end-of-track callback does not arrive
        -- on this Mac and the tick is carrying the playlist — worth knowing
        -- before anyone deletes the belt for being redundant.
        line(("   advances : %d by callback · %d by the belt · %d asked for")
             :format(mp.advances.callback, mp.advances.belt, mp.advances.manual))
        if #mp.refused > 0 then
            line("   refused  : " .. #mp.refused .. " from the last drop —")
            for i, r in ipairs(mp.refused) do
                if i <= 6 then
                    line("      " .. (r.path ~= "" and mp.titleOf(r.path) or "(drop)")
                         .. " — " .. tostring(r.why))
                end
            end
        else
            line("   refused  : none from the last drop")
        end
        line("   history  : " .. #mp.history .. " track(s) over the last "
             .. tostring(mp.historyDays) .. " day(s) — one row per file"
             .. (#mp.history > 0 and (", oldest "
                 .. os.date("%b %d", tonumber(mp.history[#mp.history].at) or 0))
                 or ""))
        line("   store    : " .. tostring(mp.storeFile))
        line("   ↳ LOCAL, never OneDrive — a half-played queue is not")
        line("     cross-Mac data, and a cloud write costs a wake-up")
        line("   plays    : " .. (function()
                local e = {}
                for k in pairs(mp.playable) do e[#e + 1] = "." .. k end
                table.sort(e)
                return table.concat(e, " ")
            end)())
        line("   ↳ .flac and .ogg do NOT play through macOS's own audio —")
        line("     each refused file says so by name")
        line("   drop     : " .. (mp.catcher and "catcher up — a dragged "
             .. "file lands on the card" or ("⚠️ " .. tostring(mp.dropWhy))))
        line("   ↳ " .. tostring(mp.dragSeen)
             .. (mp.dropReader and (" · read by " .. mp.dropReader) or ""))
        line("   ↳ " .. tostring(mp.dropRefs)
             .. ((hs.fs and hs.fs.pathToBookmark) and ""
                 or " · ⚠️ this Hammerspoon has no hs.fs.pathToBookmark"))
        line("   window   : " .. (function()
                local f = mp.webview and mp.webview:frame()
                local at = f and ("at %d,%d"):format(math.floor(f.x),
                                                     math.floor(f.y))
                           or "closed"
                return at .. " · " .. tostring(mp.posWhy)
            end)())
        line("   ↳ drag the title strip, or ⌘-drag anywhere on the card")
        if not (_G.movablePanels and #_G.movablePanels > 0) then
            line("   ⚠️ window_move is not loaded — neither grip works")
        end
        line("   volume   : none here, on purpose — the Mac's own keys")
        line("   last     : " .. tostring(mp.lastWhy))
        line("   off      : settings = { music_player = { enabled = false } }")
        print(table.concat(L, "\n"))
    end

    -- ---- the doors in -----------------------------------------------------

    core.hyperAddShortcut(mp.mods, mp.key, function() mp.toggle() end,
                          "music player")

    core.provide("music.show",   function() return mp.show() end)
    core.provide("music.hide",   function() mp.hide() return true end)
    core.provide("music.toggle", function() return mp.toggle() end)

    -- ⎋ In the escape router, so the cheat sheet still closes LAST.
    if _G.claimEscape then
        _G.claimEscape("musicplayer", nil,
            function() return mp.webview ~= nil end,
            function() mp.hide() end)
    end

    -- 🪟 Movable like every other panel this config draws: ⌘-drag
    -- anywhere on the card (window_move's tap), and a bare drag on the
    -- title strip through the dragStart message above. move() is where
    -- the spot is written down, so BOTH grips remember (6.93.0).
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "music player",
        frame = function() return mp.webview and mp.webview:frame() end,
        move  = function(x, y)
            local f = mp.webview and mp.webview:frame()
            if not f then return end
            mp.webview:frame({ x = x, y = y, w = f.w, h = f.h })
            -- The catcher IS the card's drop area, so it goes where the
            -- card goes — a catcher left behind is a dead zone over the
            -- old spot and no drop at the new one.
            mp.moveCatcher({ x = x, y = y, w = f.w, h = f.h })
            mp.pos = { x = x, y = y }
            mp.posWhy = "moved"
            -- Debounced: this runs on every tick of the drag, not once
            -- when the button comes up.
            saveSoon()
        end,
    })

    _G.musicPlayer = mp
    M.mp     = mp
    M.config = mp
end

-- The store is read in warm(), not setup(): boot is measured, and a JSON
-- read is not needed to answer a keypress. 🔌 And nothing is STARTED in
-- setup either — 6.228.0's rule: a switch is only real if the thing it
-- governs starts after settings are applied.
function M.warm(core)
    local mp = M.mp
    if not mp then return end
    if not mp.enabled then return end
    if not mp.loaded then pcall(mp.loadStore) end
end

return M
