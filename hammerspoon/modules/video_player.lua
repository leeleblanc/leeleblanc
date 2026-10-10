-- =====================================================================
-- MODULE: 🎬 MUG PLAYER (⇪⇧,) — the Jug Player, for films
-- =====================================================================
-- LL, 2026-10-10: "Right now, give me something that is Mug Player. So a
-- Jug Player but for movies. Once it's stable we will merge the players."
-- And, the night before, the scope: "Build the video player to handle
-- .mp4. I'll deal with the rest on my own." So: .mp4, a separate tool, a
-- separate key, a separate store — and a merge later, on his word, once
-- this one has run on his Mac for a while.
--
-- 🪟 NEW GROUND, AND IT IS SAID RATHER THAN DISCOVERED. Seventy-one
-- modules draw webviews and not one of them has ever played VIDEO in
-- one, so the single fact this whole tool rests on — whether a WKWebView
-- Hammerspoon opened will load a film off the local disk — is a fact
-- nothing in this project has measured. 6.233.0's rule forbids designing
-- on a belief about a platform, and the honest answer to "I do not know"
-- is not a guess, it is a MEASUREMENT: `vid.sourceDoors` lists the ways
-- in, the page reports which one the film actually loaded through, and
-- `_G.mugReport()` names it. A Mac where none of them works gets a
-- sentence saying so and ⌘O into QuickTime, never a black rectangle.
--
-- 🔑 AND THE WINNING DOOR IS REMEMBERED (`vid.doorStart`), so the second
-- film opens straight through the one that worked. A tool that
-- rediscovers the same platform fact on every file is a tool that
-- flickers.
--
-- 🎛 NATIVE CONTROLS, WHICH IS WHAT HE ASKED FOR: the stage is one
-- `<video controls>` element, so the scrubber, the clock, the volume
-- slider, full screen and picture-in-picture are WebKit's own — the same
-- chrome Safari puts under a film. Nothing here reimplements a transport
-- bar, and nothing here can get one wrong.
--
-- 🔌 ONE THING IS BORROWED AND ONE THING DELIBERATELY IS NOT, and the
-- line between them is worth the paragraph. The DRAG READER is borrowed:
-- `drag.paths` is music_player's own `mp.dropPaths`, published as a
-- service in this release — five pasteboard readers, in order, plus the
-- bookmark round trip that turns Finder's `file:///.file/id=…` inode URLs
-- back into files. That is four releases of hard-won macOS knowledge
-- (6.233.0, 6.235.0, 6.236.1, 6.237.0) and a second copy of it would be a
-- second copy to get wrong — 6.231.0, one function, two callers. Its
-- failure mode is also the mild one: no service, no DROP, and the report
-- says so; nothing of his is lost.
-- 🚫 THE HISTORY ARITHMETIC IS NOT BORROWED, on purpose. It is fifteen
-- lines of list rules with its own fixtures, and hanging this module's
-- DATA path off another module's load order would mean a film history
-- that prunes at thirty days on a good boot and never on a bad one. A
-- shared helper is right when the knowledge is expensive and the failure
-- is mild; it is wrong when the failure silently changes what is kept.
--
-- ⏯ THE MEDIA KEYS ARE NOT CLAIMED, and that is a decision rather than
-- an omission. The Jug Player takes F7/F8/F9 while its card is on screen
-- (6.289.0, narrowed in 6.309.0), and two tools reaching for one physical
-- key is exactly the shape 6.291.0 exists because of. With the stage
-- focused macOS routes them to the film anyway. When the players merge,
-- ONE gate decides for both; until then this one does not reach.
--
-- 📏 SCOPE, HIS: .mp4 only. `vid.exts` is the list and the report prints
-- it, so widening it to .m4v or .mov is one word from him and not a
-- release — but it ships as he asked for it, not as I would have guessed.
-- =====================================================================

local BRAND = "Mug Player"

-- ⌨️ ONE DOOR, and it is next to the other player's. ⇪⇧. is the Jug
-- Player (6.311.0); ⇪⇧, is this one — adjacent keys for adjacent tools,
-- which is the mnemonic that survives the merge he has already named.
-- 🆓 ASKED OF THE REGISTRY, NEVER OF A NOTE (6.276.0's rule, which this
-- project's own key caused): every `hyperAddShortcut` call in modules/,
-- core/ and init.lua was extracted and resolved before this was chosen,
-- and the gate's collision auditor — which loads the REAL config and
-- fails by name on a double claim — is what proves it rather than this
-- comment.
local KEYS = {
    { mods = { "shift" }, key = "," },      -- ⇪⇧,   6.344.0
}

local MODGLYPH = { shift = "⇧", cmd = "⌘", command = "⌘", alt = "⌥",
                   option = "⌥", ctrl = "⌃", control = "⌃" }

-- 🔑 PURE: the doors in, the human label out. 6.311.0's rule, which is
-- that no combo is ever TYPED into a visible string — the cheat-sheet
-- title, the card, the summary and the report all print this, so the
-- sheet cannot promise a key nothing bound. An empty list SAYS so rather
-- than drawing a blank key column (6.196.1).
local function keyLabel(keys)
    local out = {}
    for _, d in ipairs(type(keys) == "table" and keys or {}) do
        local key = (type(d) == "table") and d.key or nil
        if type(key) == "string" and key ~= "" then
            local g = ""
            for _, m in ipairs((type(d) == "table"
                                and type(d.mods) == "table") and d.mods or {}) do
                g = g .. (MODGLYPH[tostring(m):lower()] or "")
            end
            out[#out + 1] = "⇪" .. g .. key
        end
    end
    if #out == 0 then return "(no key bound)" end
    return table.concat(out, " · ")
end
local KEYLABEL = keyLabel(KEYS)

local OPEN_CLOSE  = "Open / close the " .. BRAND
local SUMMARY_TAIL = "— drop .mp4 films on it; the first plays, the rest queue"
local CARD_TAIL   = "films, with the Mac's own controls"

local M = {
    name    = BRAND,
    order   = 13.67,                -- beside the Jug Player (13.66)
    family  = "time",
    summary = KEYLABEL .. " " .. SUMMARY_TAIL,
    cheatsheet = {
        title = "🎬 " .. BRAND:upper() .. " (" .. KEYLABEL
                .. " — " .. CARD_TAIL .. ")",
        entries = {
            { KEYLABEL,  OPEN_CLOSE },
            { "drop",    "Drag .mp4 films onto the window: the first plays, the rest queue" },
            { "controls","The scrubber, clock, volume, full screen and PiP are macOS's own" },
            { "space",   "Play / pause, wherever the keyboard is in the window" },
            { "← →",     "Seek, and ⇧ with them seeks further — the film's own keys" },
            { "↑ ↓ · ⏎", "Walk the queue AND the 🕘 history as one list · ⏎ plays" },
            { "⌘1–⌘9",   "Play the Nth film in the queue" },
            { "⌫",       "On a queue row: take it out · on a 🕘 history row: forget it" },
            { "✕",       "On a 🕘 history row: forget that film (the file is not touched)" },
            { "⌘O",      "Open the film playing now in QuickTime — the way out when" },
            { "",        "macOS will not let this window read it" },
            { "drag",    "Move the window: grab its title strip — or ⌘-drag anywhere on it" },
            { "⏯ ⏮ ⏭",   "NOT taken here, deliberately: the Jug Player holds them, and two" },
            { "",        "tools on one physical key is how they come to disagree (6.291.0)" },
            { "format",  ".mp4 only — his scope; the report names the list" },
            { "Console", "_G.mugReport()" },
        },
    },
}

function M.setup(core)
    local vid = {
        enabled    = true,
        keys       = KEYS,
        brand      = BRAND,
        -- 📐 A FILM NEEDS A WINDOW, NOT A CARD. The Jug Player is 340×430
        -- in a corner because a track is a line of text; a film is the
        -- thing you are looking at, so the stage gets the room and the
        -- deck underneath is a strip.
        width      = 880,
        height     = 660,
        deckHeight = 176,            -- the queue + history strip under the stage
        headerHeight = 34,           -- the title strip you drag it by
        anchor     = "center",
        gap        = 12,
        alpha      = 1,              -- a film is not decoration; no translucency
        fontSize   = 13,
        -- 📏 HIS SCOPE, VERBATIM: "Build the video player to handle .mp4."
        -- The list is a knob so widening it is a word from him rather
        -- than a release, and the report PRINTS it so the refusal he
        -- meets is traceable to the list rather than to a mystery.
        exts       = { mp4 = true },
        maxQueue   = 200,
        maxHistory = 400,            -- the BOUND; days decide what is kept
        historyDays = 30,
        historyShow = 20,            -- how many rows the deck draws
        saveDelay  = 0.3,
        takeKeyboard = true,
        focusTries = 4,
        focusEvery = 0.08,
        focusTimer = nil,            -- HELD, its own slot (6.196.1)
        -- state
        queue      = {},             -- { path=, title= }
        history    = {},             -- { path=, title=, at= }
        index      = 0,              -- the film playing
        sel        = 1,              -- the row the keyboard is on
        selList    = "queue",
        gen        = 0,              -- 6.304.0 — which load a page message is about
        door       = 1,              -- which way in is being tried right now
        doorStart  = 1,              -- the one that worked last time
        doorWorked = nil,            -- its name, once a film has really loaded
        doorFailed = {},             -- names of the ones macOS refused
        loaded     = false,
        storeState = "notread",
        storeBytes = 0,
        pos        = nil,
        posWhy     = "not opened yet",
        catcher    = nil,
        dropWhy    = "not opened yet",
        dragSeen   = "no drag yet this session",
        dropReader = nil,
        refused    = {},             -- { path=, why= } — named, never silent
        plays      = 0,
        externals  = 0,              -- how many went out to QuickTime
        forgotten  = 0,
        pageReady  = false,
        draws      = { landed = 0, early = 0 },
        lastWhy    = "nothing has been asked of it yet",
    }

    -- 🔔 The degrade door (6.215.0). A break is SEEN, never only logged.
    local function degrade(why)
        vid.lastWhy = why
        if core and core.degrade then
            local ok, r = pcall(core.degrade, BRAND, why)
            if ok then return false, why end
        end
        pcall(function() hs.alert.show("⚠️ " .. BRAND .. " — " .. why, 3) end)
        print("⚠️ " .. BRAND .. ": " .. why)
        return false, why
    end

    local function say(msg)
        pcall(function() hs.alert.show("🎬 " .. msg, 2) end)
    end

    -- =================================================================
    -- PURE. Every rule about WHAT PLAYS, HOW IT IS REACHED and WHAT IS
    -- KEPT lives here, so the gate proves all of it with no Mac, no
    -- window and no films on disk.
    -- =================================================================

    -- The name a row shows: the file's own, without its extension.
    function vid.titleOf(path)
        local p = tostring(path or "")
        local base = p:match("([^/]+)$") or p
        return (base:gsub("%.[^.]+$", ""))
    end

    function vid.extOf(path)
        local e = tostring(path or ""):match("%.([%w]+)$")
        return e and e:lower() or ""
    end

    -- 🎬 PURE: can this window play it? Answers ok AND WHY, because a
    -- film refused with no reason is 6.320.0's complaint exactly — a
    -- refusal he cannot act on is a defect even when it is correct.
    function vid.playable(path, exts)
        local list = type(exts) == "table" and exts or { mp4 = true }
        local p = tostring(path or "")
        if p == "" then return false, "there is no path" end
        local e = vid.extOf(p)
        if e == "" then
            return false, "no file extension — " .. BRAND .. " cannot tell "
                          .. "what this is"
        end
        if not list[e] then
            local names = {}
            for k in pairs(list) do names[#names + 1] = "." .. k end
            table.sort(names)
            return false, "." .. e .. " is not played here — " .. BRAND
                          .. " plays " .. table.concat(names, " ")
                          .. " (your scope); ⌘O opens it in QuickTime"
        end
        return true, "." .. e
    end

    -- 🔑 PURE: a POSIX path, percent-encoded for a URL.
    -- 🚨 ONE PASS, AND THAT IS THE WHOLE RULE — found by this module's own
    -- suite, which is why it is written down rather than assumed. The
    -- first version encoded "%" in its own gsub and then ran the general
    -- one, which re-encoded the "%" of the "%25" it had just written:
    -- "50% off.mp4" came out as "50%2525%20off.mp4" and no file could
    -- load. ANY two-pass encoder has that defect, because the second pass
    -- cannot tell an escape it wrote from a character it must escape. So
    -- every byte that needs escaping, including "%", is escaped exactly
    -- once, here. The fixture that bites holds BOTH a percent and a
    -- space, because either alone passes under the wrong order (6.230.0:
    -- pick the input where the two implementations must differ).
    -- 🚨 AND "#" MUST BE ESCAPED, which is the one that costs a whole
    -- film rather than a character: an unescaped # begins a URL FRAGMENT,
    -- so "Pt 2 #final.mp4" asks macOS for "Pt 2 " and nothing else.
    -- The separators are left alone: encoding "/" would flatten the path
    -- into one impossible name.
    function vid.encodePath(path)
        local p = tostring(path or "")
        return (p:gsub("([^%w%-%._~/])", function(c)
            return string.format("%%%02X", string.byte(c))
        end))
    end

    -- 🪟 PURE: THE WAYS IN, IN ORDER — the heart of this release.
    -- Neither is known to work on his Mac, which is why there are two and
    -- why the page reports which one carried the film.
    --   1. The page's BASE URL is the film's own folder and the <video>
    --      src is just its name. Most likely to work, because the page's
    --      origin and the film are then the same directory — the case
    --      WebKit's file-URL rules are least hostile to.
    --   2. An absolute file:// URL on a page with no base.
    -- A build of Hammerspoon whose :html() ignores a second argument
    -- simply makes door 1 behave as door 2, falls through, and the report
    -- says door 2 carried it. Nothing breaks either way, which is the
    -- point of not guessing.
    function vid.sourceDoors(path)
        local p = tostring(path or "")
        if p == "" then return {} end
        local dir  = p:match("^(.*)/[^/]*$") or ""
        local base = p:match("([^/]+)$") or p
        return {
            { how = "relative to the film's own folder",
              base = "file://" .. vid.encodePath(dir) .. "/",
              src  = vid.encodePath(base) },
            { how = "the absolute file URL",
              base = nil,
              src  = "file://" .. vid.encodePath(p) },
        }
    end

    -- 🕘 PURE: thirty days, ONE ROW PER FILE, newest first. The cap is a
    -- BOUND and not the rule — days decide what is kept, and the cap only
    -- stops a runaway list, keeping the NEWEST (its own check, because
    -- keeping the oldest is the easy way to write it wrong).
    function vid.noteHistory(list, row, now, days, max)
        local out = {}
        local t   = tonumber(now) or 0
        local win = (tonumber(days) or 30) * 86400
        local cap = tonumber(max) or 400
        if type(row) == "table" and type(row.path) == "string" and row.path ~= "" then
            out[#out + 1] = { path = row.path, title = row.title
                              or vid.titleOf(row.path), at = t }
        end
        for _, r in ipairs(type(list) == "table" and list or {}) do
            if type(r) == "table" and type(r.path) == "string" and r.path ~= "" then
                local at = tonumber(r.at) or 0
                local dup = (type(row) == "table" and r.path == row.path)
                if (not dup) and (t - at) < win and #out < cap then
                    out[#out + 1] = { path = r.path,
                                      title = r.title or vid.titleOf(r.path),
                                      at = at }
                end
            end
        end
        return out
    end

    -- 🗑 PURE: forget a row BY PATH, never by index (6.272.0 / 6.186.0 —
    -- the deck renumbers under his hand, so an index forgets a different
    -- film than the one he clicked). An EMPTY path is refused: a blank
    -- message must never empty the list. EVERY match goes, or a duplicate
    -- survives a command that said it removed the film.
    function vid.forgetHistory(list, path)
        local p = tostring(path or "")
        if p == "" then return list, 0 end
        local out, gone = {}, 0
        for _, r in ipairs(type(list) == "table" and list or {}) do
            if type(r) == "table" and r.path == p then gone = gone + 1
            else out[#out + 1] = r end
        end
        return out, gone
    end

    -- 🕘 PURE: how many history rows are DRAWN. The cursor must count off
    -- what is on screen, never off the store — a cursor counted off 400
    -- rows walks into rows nobody can see (6.315.0).
    function vid.histShown(n, show)
        return math.min(tonumber(n) or 0, tonumber(show) or 20)
    end

    -- ⌨️ PURE: one cursor over queue-then-history as ONE run, because the
    -- deck draws them as one scrolling list. d = 0 CLAMPS rather than
    -- moves — every edit can leave the cursor past the end of its list.
    -- An emptied list hands the cursor to the other at the row NEAREST
    -- where it was, so a ⌫ on the last history row lands on the LAST
    -- queue row and never the first.
    function vid.selMove(cur, nq, nh, d)
        nq, nh = tonumber(nq) or 0, tonumber(nh) or 0
        local total = nq + nh
        if total <= 0 then return { list = "queue", row = 1 } end
        local list = (type(cur) == "table" and cur.list == "history")
                     and "history" or "queue"
        local row  = tonumber(type(cur) == "table" and cur.row) or 1
        local p = (list == "history") and (nq + row) or row
        p = p + (tonumber(d) or 0)
        if p < 1 then p = total end
        if p > total then p = 1 end
        if p <= nq then return { list = "queue", row = p } end
        return { list = "history", row = p - nq }
    end

    -- 📐 PURE: where the window opens, and WHY (6.196.1 — four answers).
    function vid.frameFor(sf)
        local w = math.min(tonumber(vid.width) or 880, (sf.w or 1440) - 40)
        local h = math.min(tonumber(vid.height) or 660, (sf.h or 900) - 40)
        local g = tonumber(vid.gap) or 12
        if vid.anchor == "topRight" then
            return { x = sf.x + sf.w - w - g, y = sf.y + g, w = w, h = h }
        end
        return { x = sf.x + math.floor((sf.w - w) / 2),
                 y = sf.y + math.floor((sf.h - h) / 2), w = w, h = h }
    end

    function vid.placeFor(pos, sf, screens)
        local base = vid.frameFor(sf)
        if type(pos) ~= "table" then return base, "centred" end
        local x, y = tonumber(pos.x), tonumber(pos.y)
        if not (x and y) then return base, "centred" end
        for _, f in ipairs(screens or {}) do
            if type(f) == "table" and tonumber(f.x) and tonumber(f.w)
               and x >= f.x and x < f.x + f.w
               and y >= f.y and y < f.y + f.h then
                local cx = math.max(f.x, math.min(x, f.x + f.w - base.w))
                local cy = math.max(f.y, math.min(y, f.y + f.h - base.h))
                return { x = cx, y = cy, w = base.w, h = base.h },
                       (cx == x and cy == y) and "where you put it"
                       or "nudged back onto the screen"
            end
        end
        -- A spot on a screen he is not on is DROPPED, never dragged onto
        -- one it was never on (6.196.0's rule for the cheat sheet).
        return base, "centred — the remembered spot is on no screen now"
    end

    -- 🔎 PURE: WHAT THE STORE IS, IN WORDS, and "not yet" is one of them
    -- (6.312.0). The store is read in warm(), seconds after boot, so
    -- "nothing queued" and "not read yet" are opposite facts that printed
    -- the same sentence until that release said so. FAILS CLOSED on a
    -- state nobody recorded: a report that cannot say what it found must
    -- not pick the reassuring branch.
    function vid.storeVerdict(state, bytes, nq, nh)
        if state == "notread" then
            return "⏳ NOT READ YET — the store is opened a few seconds "
                   .. "after boot; this is not an answer yet"
        elseif state == "none" then
            return "no store file yet — nothing has been queued on this Mac"
        elseif state == "zero" then
            return "⚠️ ZERO BYTES — a write was cut off; nothing was queued"
        elseif state == "unreadable" then
            return "⚠️ UNREADABLE — the file is there and could not be "
                   .. "decoded; it was left alone"
        elseif state == "read" then
            return "read " .. (tonumber(bytes) or 0) .. " bytes — "
                   .. (tonumber(nq) or 0) .. " queued · "
                   .. (tonumber(nh) or 0) .. " history row(s)"
        end
        return "⚠️ the store is in a state nothing recorded — treat it as "
               .. "unknown, never as empty"
    end

    -- =================================================================
    -- STORE — LOCAL, never OneDrive. A half-played film queue is not
    -- cross-Mac data, and 6.229.0 priced a write into a watched cloud
    -- folder in main-thread wake-ups.
    -- =================================================================

    vid.dir = (core.homeDir or os.getenv("HOME") or "")
              .. "/Library/Application Support/Hammerspoon/mug"
    vid.storeFile = vid.dir .. "/player.json"

    function vid.loadStore()
        vid.loaded = true
        local f = io.open(vid.storeFile, "r")
        -- Every exit records WHAT IT FOUND (6.312.0): "there is no file",
        -- "the file is empty" and "you have nothing queued" were one
        -- silence in the module this one is modelled on.
        if not f then vid.storeState = "none" ; return end
        local raw = f:read("*a") ; f:close()
        if not raw or raw == "" then vid.storeState = "zero" ; return end
        vid.storeBytes = #raw
        local ok, data = pcall(function() return hs.json.decode(raw) end)
        -- 6.198.1 — "it is a table" is not "it is MY table". Shape-checked
        -- at the LOADER, once, rather than guarded at each reader — one of
        -- which is the report, so a bad store would otherwise take out the
        -- diagnostic that names it.
        if not (ok and type(data) == "table") then
            vid.storeState = "unreadable"
            say("the saved queue could not be read — starting empty")
            return
        end
        local q = {}
        for _, t in ipairs(type(data.queue) == "table" and data.queue or {}) do
            if type(t) == "table" and type(t.path) == "string" and t.path ~= "" then
                q[#q + 1] = { path = t.path, title = vid.titleOf(t.path) }
            end
        end
        local h = {}
        for _, t in ipairs(type(data.history) == "table" and data.history or {}) do
            if type(t) == "table" and type(t.path) == "string" and t.path ~= "" then
                h[#h + 1] = { path = t.path, title = vid.titleOf(t.path),
                              at = tonumber(t.at) or 0 }
            end
        end
        vid.queue = q
        -- Pruned at the LOADER as well as at the insert: a Mac left off
        -- six weeks must not come back holding six weeks.
        vid.history = vid.noteHistory(h, nil, os.time(),
                                      vid.historyDays, vid.maxHistory)
        if type(data.pos) == "table" then vid.pos = data.pos end
        -- 🔑 THE DOOR THAT WORKED IS REMEMBERED ACROSS BOOTS, so a Mac
        -- that needs the second way in never flickers through the first.
        local d = tonumber(data.doorStart)
        if d and d >= 1 then vid.doorStart = math.floor(d) end
        vid.storeState = "read"
    end

    local function saveNow()
        pcall(function() hs.fs.mkdir(vid.dir) end)
        local q = {}
        for _, t in ipairs(vid.queue) do q[#q + 1] = { path = t.path } end
        local h = {}
        for i = 1, math.min(#vid.history, tonumber(vid.maxHistory) or 400) do
            h[#h + 1] = { path = vid.history[i].path, at = vid.history[i].at }
        end
        local ok, raw = pcall(function()
            return hs.json.encode({ queue = q, history = h, pos = vid.pos,
                                    doorStart = vid.doorStart })
        end)
        if not (ok and type(raw) == "string") then
            say("could not encode the queue — nothing was written")
            return false
        end
        -- 🔒 6.313.0 — A TEMP FILE, THEN A RENAME. io.open(path, "w")
        -- TRUNCATES BEFORE IT WRITES A BYTE, so a crash or a refused
        -- write inside that window leaves the store at ZERO BYTES, which
        -- the loader reads as "nothing queued". A failed save must cost
        -- the SAVE, never the thing saved.
        local tmp = vid.storeFile .. ".tmp"
        local f = io.open(tmp, "w")
        if not f then say("could not write " .. vid.storeFile) return false end
        local wrote = pcall(function() f:write(raw) ; f:close() end)
        if not wrote then
            pcall(function() os.remove(tmp) end)
            say("the queue could not be written — your saved queue is untouched")
            return false
        end
        local moved, why = os.rename(tmp, vid.storeFile)
        if not moved then
            pcall(function() os.remove(tmp) end)
            say("could not replace " .. vid.storeFile .. " — " .. tostring(why)
                .. "; your saved queue is untouched")
            return false
        end
        return true
    end

    -- HELD in its own slot (6.196.1): a timer nothing references is
    -- collected, and a collected timer never fires.
    local function saveSoon()
        if vid.saveTimer then pcall(function() vid.saveTimer:stop() end) end
        local ok, t = pcall(hs.timer.doAfter, tonumber(vid.saveDelay) or 0.3,
                            function() pcall(saveNow) end)
        if ok and t then vid.saveTimer = t else pcall(saveNow) end
    end
    vid.save = saveSoon

    -- =================================================================
    -- THE PAGE
    -- =================================================================

    -- 🔤 A FILM IS NAMED BY ITS FILE, AND A FILE MAY BE CALLED ANYTHING
    -- (6.231.1). Every name reaches the page as JSON and is written with
    -- textContent in the deck, so nothing here can inject markup — but
    -- the JSON itself must survive an apostrophe, a quote and a <.
    local function jstr(s)
        local ok, out = pcall(function() return hs.json.encode(tostring(s or "")) end)
        if ok and type(out) == "string" then return out end
        return '""'
    end

    -- 🔎 The rows the deck draws, as the page's own payload. A name the
    -- card cannot ENCODE is not an empty queue (6.231.1) — the refusal
    -- takes the door rather than drawing an empty deck over a film that
    -- is still playing.
    function vid.rowsJson()
        local q = {}
        for i, t in ipairs(vid.queue) do
            q[#q + 1] = "{i:" .. i .. ",t:" .. jstr(t.title or vid.titleOf(t.path))
                        .. ",p:" .. jstr(t.path) .. "}"
        end
        local h = {}
        local show = vid.histShown(#vid.history, vid.historyShow)
        for i = 1, show do
            local r = vid.history[i]
            h[#h + 1] = "{i:" .. i .. ",t:" .. jstr(r.title or vid.titleOf(r.path))
                        .. ",p:" .. jstr(r.path) .. "}"
        end
        local cur = vid.queue[vid.index]
        local src, how = "", ""
        if cur then
            local doors = vid.sourceDoors(cur.path)
            local d = doors[vid.door]
            if d then src, how = d.src, d.how end
        end
        return "{q:[" .. table.concat(q, ",") .. "],h:[" .. table.concat(h, ",")
               .. "],ix:" .. tostring(vid.index)
               .. ",sl:" .. jstr(vid.selList) .. ",sr:" .. tostring(vid.sel)
               .. ",src:" .. jstr(src) .. ",how:" .. jstr(how)
               .. ",door:" .. tostring(vid.door)
               .. ",gen:" .. tostring(vid.gen)
               .. ",name:" .. jstr(cur and (cur.title or vid.titleOf(cur.path)) or "")
               .. ",brand:" .. jstr(vid.brand) .. "}"
    end

    local function buildHtml()
        local fs   = tonumber(vid.fontSize) or 13
        local deck = tonumber(vid.deckHeight) or 176
        local head = tonumber(vid.headerHeight) or 34
        local rows = vid.rowsJson()
        return table.concat({
[[<!DOCTYPE html><html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%;background:#0b0c0e;color:#e8e9ec;overflow:hidden;
 font:]] .. fs .. [[px -apple-system,BlinkMacSystemFont,sans-serif;
 -webkit-user-select:none;user-select:none}
#head{height:]] .. head .. [[px;display:flex;align-items:center;gap:8px;
 padding:0 10px;background:#15161a;border-bottom:1px solid #26282e;
 cursor:grab;white-space:nowrap;overflow:hidden}
#brand{color:#6ea8fe;font-weight:600;flex:0 0 auto}
#now{color:#b9bcc4;overflow:hidden;text-overflow:ellipsis;flex:1 1 auto}
#stage{height:calc(100% - ]] .. (head + deck) .. [[px);background:#000;
 display:flex;align-items:center;justify-content:center;position:relative}
video{width:100%;height:100%;object-fit:contain;background:#000}
#msg{position:absolute;inset:0;display:none;align-items:center;
 justify-content:center;text-align:center;padding:24px;color:#d9a8a8;
 line-height:1.5}
#deck{height:]] .. deck .. [[px;overflow-y:auto;background:#0f1013;
 border-top:1px solid #26282e}
.sec{padding:5px 10px 2px;color:#7c818c;font-size:]] .. (fs - 2) .. [[px;
 letter-spacing:.04em}
.row{display:flex;align-items:center;gap:8px;padding:3px 10px;cursor:pointer}
.row:hover{background:#1a1c21}
.row.on{background:#23262e}
.row.play{color:#6ea8fe}
.num{color:#5d626c;flex:0 0 22px;text-align:right}
.nm{flex:1 1 auto;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.x{flex:0 0 auto;color:#5d626c;padding:0 4px}
.x:hover{color:#e06c6c}
#drop{position:absolute;inset:0;display:none;align-items:center;
 justify-content:center;background:rgba(110,168,254,.18);
 border:2px dashed #6ea8fe;color:#cfe0ff;font-size:16px}
</style></head><body>
<div id="head"><span id="brand"></span><span id="now"></span></div>
<div id="stage"><video id="v" controls playsinline preload="metadata"
 spellcheck="false" autocorrect="off" autocapitalize="off"></video>
 <div id="msg"></div><div id="drop">drop .mp4 films here</div></div>
<div id="deck"></div>
<script>
var S=]], rows, [[;
function say(m){try{webkit.messageHandlers.mugPlayer.postMessage(m)}catch(e){}}
function el(i){return document.getElementById(i)}
function dropShow(on){el('drop').style.display=on?'flex':'none'}
function fail(t){var m=el('msg');m.textContent=t;m.style.display='flex';
 el('v').style.visibility='hidden'}
function clearFail(){el('msg').style.display='none';
 el('v').style.visibility='visible'}
function draw(s){
 if(s&&typeof s==='object')S=s;
 var q=(S&&S.q)||[],h=(S&&S.h)||[];
 el('brand').textContent=(S&&S.brand)||'';
 el('now').textContent=(S&&S.name)||'nothing playing';
 var v=el('v');
 var want=(S&&S.src)||'';
 if(want){ if(v.getAttribute('data-src')!==want){
    clearFail(); v.setAttribute('data-src',want); v.src=want;
    try{v.load()}catch(e){} } }
 else { v.removeAttribute('data-src'); v.removeAttribute('src');
    try{v.load()}catch(e){} }
 var d=el('deck'),out='';
 out+='<div class="sec">QUEUE — '+q.length+'</div>';
 if(!q.length)out+='<div class="row"><span class="nm">nothing queued — drop .mp4 films on the window</span></div>';
 for(var i=0;i<q.length;i++){
   var on=(S.sl==='queue'&&S.sr===q[i].i),pl=(S.ix===q[i].i);
   out+='<div class="row'+(on?' on':'')+(pl?' play':'')+'" data-k="q" data-i="'+q[i].i+'">'
      +'<span class="num">'+q[i].i+'</span><span class="nm"></span></div>';
 }
 out+='<div class="sec">🕘 HISTORY — '+h.length+'</div>';
 for(var j=0;j<h.length;j++){
   var on2=(S.sl==='history'&&S.sr===h[j].i);
   out+='<div class="row'+(on2?' on':'')+'" data-k="h" data-i="'+h[j].i+'">'
      +'<span class="num"></span><span class="nm"></span><span class="x" data-x="1">✕</span></div>';
 }
 d.innerHTML=out;
 // 🔤 NAMES ARE WRITTEN WITH textContent, never innerHTML: a film called
 // "A & B <2>.mp4" must read as itself, and nothing a file name holds
 // may become markup (6.231.1).
 var rows=d.querySelectorAll('.row[data-k]');
 for(var r=0;r<rows.length;r++){
   var k=rows[r].getAttribute('data-k'),ix=+rows[r].getAttribute('data-i');
   var src=(k==='q')?q:h, rec=null;
   for(var z=0;z<src.length;z++){if(src[z].i===ix){rec=src[z];break}}
   if(rec)rows[r].querySelector('.nm').textContent=rec.t;
 }
 var sel=d.querySelector('.row.on');
 if(sel&&sel.scrollIntoView)sel.scrollIntoView({block:'nearest'});
}
el('deck').addEventListener('click',function(e){
 // 🚨 THE ✕ IS ASKED BEFORE THE ROW IT SITS INSIDE (6.272.0), or the
 // shared handler PLAYS the film on its way to forgetting it.
 var x=e.target.closest('[data-x]');
 var row=e.target.closest('.row[data-k]');
 if(!row)return;
 var k=row.getAttribute('data-k'),i=+row.getAttribute('data-i');
 if(x){say({a:'forget',k:k,i:i});return}
 say({a:'play',k:k,i:i});
});
el('head').addEventListener('mousedown',function(e){
 if(e.button===0&&!e.metaKey)say({a:'dragStart'});
});
document.addEventListener('keydown',function(e){
 var v=el('v');
 if(e.metaKey&&e.key>='1'&&e.key<='9'){e.preventDefault();
   say({a:'play',k:'q',i:+e.key});return}
 if(e.metaKey&&(e.key==='o'||e.key==='O')){e.preventDefault();
   say({a:'external'});return}
 if(e.metaKey)return;
 if(e.key===' '){e.preventDefault();
   try{v.paused?v.play():v.pause()}catch(err){} return}
 if(e.key==='ArrowDown'){e.preventDefault();say({a:'sel',d:1});return}
 if(e.key==='ArrowUp'){e.preventDefault();say({a:'sel',d:-1});return}
 if(e.key==='Enter'){e.preventDefault();say({a:'enter'});return}
 if(e.key==='Backspace'){e.preventDefault();say({a:'drop'});return}
 // ← → are the film's own: WebKit seeks with them, and ⇧ seeks further.
});
(function(){
 var v=el('v');
 // 🪟 THE DOOR REPORTS ITSELF. A film that loads says which way in
 // carried it; one that fails says so, and Lua tries the next.
 v.addEventListener('loadeddata',function(){
   say({a:'srcok',d:S.door,gen:S.gen});
 });
 v.addEventListener('error',function(){
   say({a:'srcfail',d:S.door,gen:S.gen});
 });
 v.addEventListener('ended',function(){say({a:'ended',gen:S.gen})});
 draw();
 // 🪟 THE PAGE SAYS WHEN IT EXISTS (6.238.0): view:html() returns BEFORE
 // WebKit has parsed the document, so a draw pushed on the next line of
 // show() finds no draw function and goes nowhere. This is the LAST line
 // of the script — sent any earlier it promises something that is not
 // there yet.
 say({a:'ready'});
})();
</script></body></html>]] })
    end

    -- =================================================================
    -- THE WINDOW
    -- =================================================================

    -- 🪟 6.326.0 — the handle is a CLAIM about the world, so it is read
    -- rather than trusted: vid.webview is assigned only after macOS has
    -- agreed to put the window on screen.
    function vid.onScreen() return vid.webview ~= nil end

    local function baseOf()
        local cur = vid.queue[vid.index]
        if not cur then return nil end
        local d = vid.sourceDoors(cur.path)[vid.door]
        return d and d.base or nil
    end

    -- `full` rebuilds the document, which is the ONLY way the page's base
    -- URL can change — and the base URL is the film's own folder, so a
    -- new film and a new door both need one. Everything else (a queue
    -- edit, the cursor moving) is PUSHED into the live page, because a
    -- rebuild would restart the film under his hand.
    function vid.paint(full)
        local view = vid.webview
        if not view then return false end
        if full then
            vid.pageReady = false
            local base = baseOf()
            -- 🚪 DOOR 1 PASSES A BASE URL. A Hammerspoon whose :html()
            -- takes one argument ignores it, the relative src fails, and
            -- door 2 carries the film — which is the fallthrough this
            -- design exists to have rather than a belief about the API.
            pcall(function()
                if base then view:html(buildHtml(), base)
                else view:html(buildHtml()) end
            end)
            return true
        end
        local ok = pcall(function()
            view:evaluateJavaScript("draw(" .. vid.rowsJson() .. ");")
        end)
        if ok and vid.pageReady then vid.draws.landed = vid.draws.landed + 1
        elseif ok then vid.draws.early = vid.draws.early + 1 end
        return ok
    end

    function vid.render() return vid.paint(false) end

    -- ⌨️ 6.251.0 — taking the keyboard activates Hammerspoon, and that is
    -- the price, named here as it is there: an open Console comes forward
    -- with the window. `takeKeyboard = false` is the switch.
    local function stopFocusChase()
        if vid.focusTimer then
            pcall(function() vid.focusTimer:stop() end)
            vid.focusTimer = nil
        end
    end

    local function chaseFocus()
        stopFocusChase()
        if not vid.takeKeyboard then
            vid.focus = { tries = 0, why = "not wanted" } ; return
        end
        local win = vid.webview and vid.webview:hswindow()
        if not win then
            vid.focus = { tries = 1, why = "no window to focus — click it once" }
            pcall(function() vid.webview:bringToFront(true) end)
            return
        end
        local tries = 0
        local okT, t = pcall(hs.timer.doEvery, tonumber(vid.focusEvery) or 0.08,
            function()
                tries = tries + 1
                local w = vid.webview and vid.webview:hswindow()
                if not w then stopFocusChase() return end
                local okF = pcall(function() w:focus() end)
                -- 🔬 BY ID, NEVER BY IDENTITY. hs.window hands back a
                -- FRESH wrapper on every call, so `focusedWindow() == w`
                -- compares two different objects and is false even when
                -- the window really is key — the chase would then run
                -- its four tries and report "gave up" on a healthy Mac.
                -- Found by the suite, because its stub models the
                -- provider's identity behaviour rather than its value.
                local isKey = false
                pcall(function()
                    local front = hs.window.focusedWindow()
                    isKey = (front ~= nil) and (front:id() == w:id())
                end)
                if (okF and isKey) or tries >= (tonumber(vid.focusTries) or 4) then
                    vid.focus = { tries = tries,
                                  why = isKey and ("took the keys on try " .. tries)
                                        or ("gave up after " .. tries
                                            .. " tries — click the window once") }
                    stopFocusChase()
                end
            end)
        if okT and t then vid.focusTimer = t
        else vid.focus = { tries = 0, why = "no timer — click the window once" } end
    end

    function vid.show()
        if vid.webview then vid.hide() return true end
        if not vid.enabled then
            say("off — settings = { video_player = { enabled = false } }")
            return false
        end
        if not vid.loaded then pcall(vid.loadStore) end
        if not (hs.webview and hs.webview.usercontent) then
            return degrade("this Hammerspoon has no hs.webview — " .. BRAND
                           .. " needs a window that can draw a film")
        end
        local screen = (core.resolveBaseScreen and core.resolveBaseScreen())
                       or hs.screen.mainScreen()
        local sf = (screen and screen:frame())
                   or { x = 0, y = 0, w = 1440, h = 900 }
        local all = {}
        local okS, list = pcall(function() return hs.screen.allScreens() end)
        for _, sc in ipairs((okS and list) or {}) do
            local okF, f = pcall(function() return sc:frame() end)
            if okF and type(f) == "table" then all[#all + 1] = f end
        end
        if #all == 0 then all = { sf } end
        local rect, why = vid.placeFor(vid.pos, sf, all)
        vid.posWhy = why

        local okUc, uc = pcall(hs.webview.usercontent.new, "mugPlayer")
        if not (okUc and uc) then return degrade("could not open the page bridge") end
        vid.uc = uc          -- HELD: collect this and the JS bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(vid.handleMessage, msg and msg.body)
                if not ok then
                    print("🎬 " .. BRAND .. ": message handler — " .. tostring(err))
                end
            end)
        end)
        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then
            vid.uc = nil
            return degrade("could not open the player window")
        end
        pcall(function() view:windowTitle(BRAND) end)
        -- Without allowTextEntry the window draws perfectly and swallows
        -- every keystroke — space, ↑↓ and ⌘1–9 would all be dead.
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        pcall(function()
            view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        if (tonumber(vid.alpha) or 1) < 1 then
            pcall(function() view:alpha(tonumber(vid.alpha)) end)
        end
        vid.pageReady = false
        vid.draws = { landed = 0, early = 0 }
        vid.door  = math.max(1, tonumber(vid.doorStart) or 1)
        local base = baseOf()
        pcall(function()
            if base then view:html(buildHtml(), base) else view:html(buildHtml()) end
        end)
        -- 🪟 6.326.0 — AND THE SHOW'S ANSWER IS READ. macOS refuses to
        -- order a window on screen while another process's remote view is
        -- mid-transition (6.265.0 · 6.266.0 · 6.274.0 · 6.314.0). The
        -- handle is recorded only once it has agreed; a refusal TEARS THE
        -- OBJECT DOWN, because an abandoned webview keeps its Esc claim
        -- and its key handler.
        -- 🔬 6.304.0's RULE, AND I BROKE IT HERE FIRST: a refusal that
        -- RETURNS FALSE is not caught by a pcall — the call succeeded, it
        -- simply said no. The first version wrote `pcall(function()
        -- view:show() ; shown = true end)`, which sets the flag on a
        -- refusal just as happily as on a success, so the teardown below
        -- was unreachable and a refused window would have been recorded
        -- as open. The suite's stub refuses by RETURNING FALSE, exactly
        -- as macOS does, which is what made it visible.
        local shown = false
        pcall(function() shown = view:show() ~= false end)
        if not shown then
            pcall(function() view:delete() end)
            vid.uc = nil
            return degrade("macOS would not put the window on screen — "
                           .. "press " .. KEYLABEL .. " again")
        end
        vid.webview = view
        pcall(function() view:bringToFront(true) end)
        chaseFocus()
        vid.startCatcher(rect)
        if _G.hyperExpectRelease then
            pcall(_G.hyperExpectRelease, 1.5, "mugPlayer")
        end
        return true
    end

    function vid.hide()
        stopFocusChase()
        vid.stopCatcher()
        if vid.webview then
            pcall(function() vid.webview:delete() end)
            vid.webview = nil
        end
        vid.uc = nil
        vid.pageReady = false
        return true
    end

    function vid.toggle()
        if vid.webview then vid.hide() return false end
        return vid.show()
    end

    -- =================================================================
    -- THE DROP — a canvas under the window, because hs.webview has no
    -- drag-and-drop of any kind and hs.canvas is the only thing in
    -- Hammerspoon that can accept a dragged file (6.233.0, checked in
    -- extensions/canvas/libcanvas.m rather than remembered).
    -- =================================================================

    function vid.stopCatcher()
        if vid.catcher then
            pcall(function() vid.catcher:delete() end)
            vid.catcher = nil
        end
    end

    function vid.moveCatcher(f)
        if vid.catcher and type(f) == "table" then
            pcall(function() vid.catcher:frame(f) end)
        end
    end

    function vid.startCatcher(rect)
        vid.stopCatcher()
        if not (hs.canvas and hs.canvas.new) then
            vid.dropWhy = "this Hammerspoon has no hs.canvas — nothing can "
                          .. "catch a dragged film"
            return degrade(vid.dropWhy)
        end
        local okC, cv = pcall(hs.canvas.new, rect)
        if not (okC and cv) then
            vid.dropWhy = "the drop catcher could not be created"
            return degrade(vid.dropWhy)
        end
        pcall(function()
            cv[1] = { type = "rectangle", action = "fill",
                      fillColor = { red = 0, green = 0, blue = 0, alpha = 0 } }
        end)
        -- Both REQUIRED by hs.canvas, and neither is visible in the
        -- result when missing — a window that has not registered dragged
        -- types is SKIPPED by the drag, which reads as the file landing
        -- behind the player.
        pcall(function() cv:mouseCallback(function() end) end)
        local okL = pcall(function() cv:level(hs.canvas.windowLevels.dragging) end)
        if not okL then
            vid.dropWhy = "this Hammerspoon has no dragging window level"
            pcall(function() cv:delete() end)
            return degrade(vid.dropWhy)
        end
        local okD = pcall(function()
            cv:draggingCallback(function(_, msg, details)
                if msg == "enter" then
                    vid.dragSeen = "a drag came over the window"
                    pcall(function()
                        vid.webview:evaluateJavaScript("dropShow(true);")
                    end)
                    return true
                elseif msg == "exit" then
                    pcall(function()
                        vid.webview:evaluateJavaScript("dropShow(false);")
                    end)
                    return true
                elseif msg == "receive" then
                    pcall(function()
                        vid.webview:evaluateJavaScript("dropShow(false);")
                    end)
                    -- 🔒 THE WHOLE RECEIVE IS WRAPPED (6.235.0): a
                    -- dragging callback that throws does nothing and says
                    -- nothing, which is indistinguishable from a drop
                    -- macOS never delivered.
                    local okR, err = pcall(function()
                        local pb = type(details) == "table"
                                   and details.pasteboard or nil
                        local paths, how = vid.readDrag(pb)
                        vid.dropReader = how
                        vid.dragSeen = #paths .. " file(s) dropped on the window"
                        vid.takeDrop(paths)
                    end)
                    if not okR then
                        vid.dragSeen = "a drop arrived and the handler threw"
                        degrade("the drop could not be read — " .. tostring(err))
                    end
                    return true
                end
                return true
            end)
        end)
        if not okD then
            vid.dropWhy = "this Hammerspoon's hs.canvas cannot accept drags"
            pcall(function() cv:delete() end)
            return degrade(vid.dropWhy)
        end
        pcall(function() cv:show() end)
        vid.catcher = cv
        vid.dropWhy = "ready"
        return true
    end

    -- 🔌 ONE READER, TWO CALLERS (6.231.0). `drag.paths` is music_player's
    -- own pasteboard reader, published as a service in this release — the
    -- five readers it asks in order, and the bookmark round trip that
    -- turns Finder's inode URLs back into files, are four releases of
    -- knowledge this module must not re-learn.
    -- 🔎 AND ITS ABSENCE IS AN ANSWER, not a crash: no provider means no
    -- DROP, said in the report, with every other door into this tool
    -- still working. IT DEGRADES, IT NEVER BREAKS.
    function vid.readDrag(pb)
        if not (_G.service and _G.service.has and _G.service.has("drag.paths")) then
            vid.dropWhy = "the shared drag reader is not loaded (it lives in "
                          .. "the Jug Player's module) — drops cannot be read"
            degrade(vid.dropWhy)
            return {}, "no reader"
        end
        local paths, how = _G.service.call("drag.paths", pb)
        if type(paths) ~= "table" then return {}, tostring(how or "nothing readable") end
        return paths, tostring(how or "?")
    end

    -- =================================================================
    -- PLAYBACK
    -- =================================================================

    local function noteHistoryNow(path)
        if type(path) ~= "string" or path == "" then return end
        vid.history = vid.noteHistory(vid.history,
                                      { path = path, title = vid.titleOf(path) },
                                      os.time(), vid.historyDays, vid.maxHistory)
    end

    -- 🚨 BOTH THE ROW AND ITS LIST ARE CLAIMED (6.315.0's own sweep
    -- finding): setting the row and leaving the list behind makes the
    -- cursor read a queue number as a history row, and the next ⌫
    -- forgets something else entirely.
    function vid.playIndex(i)
        local t = vid.queue[tonumber(i) or 0]
        if not t then return false, "there is no film at that row" end
        vid.index    = i
        vid.sel      = i
        vid.selList  = "queue"
        -- 6.304.0 — a GENERATION, so a late message about the film that
        -- was playing a moment ago cannot bump the door for this one.
        vid.gen      = vid.gen + 1
        vid.door     = math.max(1, tonumber(vid.doorStart) or 1)
        vid.plays    = vid.plays + 1
        noteHistoryNow(t.path)
        vid.save()
        -- A new film means a new folder, which means a new base URL —
        -- and only a rebuilt document can carry one.
        vid.paint(true)
        return true
    end

    function vid.playPath(path)
        for i, t in ipairs(vid.queue) do
            if t.path == path then return vid.playIndex(i) end
        end
        if #vid.queue >= (tonumber(vid.maxQueue) or 200) then
            return false, "the queue is full"
        end
        vid.queue[#vid.queue + 1] = { path = path, title = vid.titleOf(path) }
        return vid.playIndex(#vid.queue)
    end

    function vid.takeDrop(paths)
        local added, refused = 0, {}
        for _, p in ipairs(type(paths) == "table" and paths or {}) do
            local ok, why = vid.playable(p, vid.exts)
            if ok then
                if #vid.queue < (tonumber(vid.maxQueue) or 200) then
                    vid.queue[#vid.queue + 1] = { path = p, title = vid.titleOf(p) }
                    added = added + 1
                end
            else
                -- 🔎 NAMED, NEVER SILENT: a file this tool will not play
                -- is listed with the reason, because a drop that half
                -- works and says nothing is the bug 6.235.0 cost.
                refused[#refused + 1] = { path = p, why = why }
            end
        end
        vid.refused = refused
        if added == 0 and #refused == 0 then
            say("nothing in that drop was a file")
            return false
        end
        if #refused > 0 then
            local first = refused[1]
            say(#refused .. " not played — " .. vid.titleOf(first.path)
                .. ": " .. first.why)
        end
        if added > 0 then
            vid.save()
            if vid.index == 0 or not vid.queue[vid.index] then
                vid.playIndex(#vid.queue - added + 1)
            else
                vid.render()
            end
        end
        return added > 0
    end

    -- 🚪 THE WAY OUT, and it is not a consolation prize: a film macOS
    -- will not let this window read is still a film he wants to watch.
    function vid.openExternal()
        local t = vid.queue[vid.index]
        if not t then say("nothing is playing") return false end
        vid.externals = vid.externals + 1
        local ok = pcall(function()
            hs.task.new("/usr/bin/open", nil, { t.path }):start()
        end)
        if not ok then return degrade("could not hand the film to macOS") end
        say("opened in your default player — " .. (t.title or ""))
        return true
    end

    -- =================================================================
    -- WHAT THE PAGE SAYS
    -- =================================================================

    local function jsEscape(s)
        return tostring(s or ""):gsub("\\", "\\\\"):gsub('"', '\\"')
                                :gsub("\n", " ")
    end

    local function tellPage(fn, text)
        pcall(function()
            vid.webview:evaluateJavaScript(fn .. '("' .. jsEscape(text) .. '");')
        end)
    end

    function vid.handleMessage(body)
        if type(body) ~= "table" then return end
        local a = body.a

        if a == "ready" then
            -- 🪟 6.238.0 — the page has parsed and its script has run, so
            -- the state it was BUILT with is real. Counted apart from the
            -- blind pushes, because a page that has never spoken reads as
            -- a fault, not as health.
            vid.pageReady = true
            return

        elseif a == "srcok" then
            -- 🔑 THE DOOR THAT WORKED, recorded and REMEMBERED. The
            -- generation check is 6.304.0's: a late answer about the film
            -- that was playing a moment ago must not speak for this one.
            if tonumber(body.gen) ~= vid.gen then return end
            local d = tonumber(body.d) or vid.door
            local doors = vid.sourceDoors((vid.queue[vid.index] or {}).path)
            vid.doorWorked = (doors[d] and doors[d].how) or ("door " .. d)
            vid.doorStart  = d
            vid.save()
            return

        elseif a == "srcfail" then
            if tonumber(body.gen) ~= vid.gen then return end
            local d = tonumber(body.d) or vid.door
            if d ~= vid.door then return end
            local cur = vid.queue[vid.index]
            if not cur then return end
            local doors = vid.sourceDoors(cur.path)
            local name = (doors[d] and doors[d].how) or ("door " .. d)
            vid.doorFailed[name] = (tonumber(vid.doorFailed[name]) or 0) + 1
            if d < #doors then
                -- Try the next way in. A new base URL needs a new
                -- document, so this is a full rebuild — nothing is
                -- playing at this moment, so nothing is lost.
                vid.door = d + 1
                vid.paint(true)
                return
            end
            -- 🚨 EVERY WAY IN REFUSED, AND IT SAYS SO IN WORDS. This is
            -- the state this release exists to make legible rather than
            -- a black rectangle: it names the film, says macOS refused
            -- the window read access, and gives the key that opens it
            -- anyway.
            vid.lastWhy = "macOS would not let this window read "
                          .. tostring(cur.path)
            tellPage("fail", "⚠️ macOS would not let this window read "
                     .. (cur.title or "") .. ".  Every way in was refused."
                     .. "  Press ⌘O to open it in QuickTime — and send me"
                     .. " _G.mugReport(), which names what was tried.")
            return

        elseif a == "ended" then
            if tonumber(body.gen) ~= vid.gen then return end
            local nxt = (tonumber(vid.index) or 0) + 1
            if vid.queue[nxt] then vid.playIndex(nxt) end
            return

        elseif a == "play" then
            local i = tonumber(body.i) or 0
            if body.k == "h" then
                local r = vid.history[i]
                if r then vid.playPath(r.path) end
            else
                vid.playIndex(i)
            end
            return

        elseif a == "forget" then
            -- 🗑 BY PATH, NEVER BY INDEX (6.272.0). The row number is
            -- resolved to a path HERE, at the instant of the press, from
            -- the same list the page drew — and then EVERY row with that
            -- path goes, or a duplicate survives a command that said it
            -- removed the film.
            local r = vid.history[tonumber(body.i) or 0]
            if not r then return end
            local list, gone = vid.forgetHistory(vid.history, r.path)
            vid.history = list
            vid.forgotten = vid.forgotten + gone
            vid.save() ; vid.render()
            return

        elseif a == "sel" then
            local nq = #vid.queue
            local nh = vid.histShown(#vid.history, vid.historyShow)
            local s = vid.selMove({ list = vid.selList, row = vid.sel },
                                  nq, nh, tonumber(body.d) or 0)
            vid.selList, vid.sel = s.list, s.row
            vid.render()
            return

        elseif a == "enter" then
            if vid.selList == "history" then
                local r = vid.history[vid.sel]
                if r then vid.playPath(r.path) end
            else
                vid.playIndex(vid.sel)
            end
            return

        elseif a == "drop" then
            -- ⌫ — on a queue row it leaves the queue; on a history row it
            -- is forgotten. The file on disk is never touched by either.
            if vid.selList == "history" then
                local r = vid.history[vid.sel]
                if r then
                    local list, gone = vid.forgetHistory(vid.history, r.path)
                    vid.history = list
                    vid.forgotten = vid.forgotten + gone
                end
            else
                local i = tonumber(vid.sel) or 0
                if vid.queue[i] then
                    table.remove(vid.queue, i)
                    if vid.index == i then vid.index = 0
                    elseif vid.index > i then vid.index = vid.index - 1 end
                end
            end
            local s = vid.selMove({ list = vid.selList, row = vid.sel },
                                  #vid.queue,
                                  vid.histShown(#vid.history, vid.historyShow), 0)
            vid.selList, vid.sel = s.list, s.row
            vid.save() ; vid.render()
            return

        elseif a == "external" then
            vid.openExternal()
            return

        elseif a == "dragStart" then
            -- A page cannot move the window it is drawn in; this is the
            -- bare-press grip on the title strip (6.232.0's two grips).
            if _G.beginPanelDrag then pcall(_G.beginPanelDrag, "mug player") end
            return
        end
    end

    -- =================================================================
    -- WIRING
    -- =================================================================

    -- ⌨️ Every door ends in ONE vid.toggle — two handlers for one tool is
    -- how they come to disagree (6.291.0).
    -- 📏 SAID RATHER THAN IMPLIED: a `settings` override of this list is
    -- DECORATIVE, because the binding happens in setup() and profile
    -- settings land after it (6.228.0). The report says so.
    local bound = 0
    for _, d in ipairs(vid.keys) do
        if type(d) == "table" and type(d.key) == "string" and d.key ~= "" then
            core.hyperAddShortcut(d.mods or {}, d.key,
                                  function() vid.toggle() end, OPEN_CLOSE)
            bound = bound + 1
        end
    end
    vid.doors = bound

    core.provide("video.show",   function() return vid.show() end)
    core.provide("video.hide",   function() vid.hide() return true end)
    core.provide("video.toggle", function() return vid.toggle() end)

    -- ⎋ In the escape router, so the cheat sheet still closes LAST.
    if _G.claimEscape then
        _G.claimEscape("mugplayer", nil,
            function() return vid.webview ~= nil end,
            function() vid.hide() end)
    end

    -- 🪟 A PANEL THIS CONFIG DRAWS IS A PANEL `_G.movablePanels` KNOWS
    -- ABOUT (6.232.0): that table is the ONLY register window_move reads,
    -- and a panel absent from it is movable by NO means. The id is a
    -- PAIR — this name and the beginPanelDrag() argument in the message
    -- handler — and renaming one half is how a window silently stops
    -- being draggable, so a check joins them.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "mug player",
        frame = function() return vid.webview and vid.webview:frame() end,
        move  = function(x, y)
            local f = vid.webview and vid.webview:frame()
            if not f then return end
            vid.webview:frame({ x = x, y = y, w = f.w, h = f.h })
            -- The catcher IS the drop area, so it goes where the window
            -- goes — one left behind is a dead zone over the old spot
            -- and no drop at the new one.
            vid.moveCatcher({ x = x, y = y, w = f.w, h = f.h })
            vid.pos = { x = x, y = y }
            vid.posWhy = "where you put it"
            saveSoon()
        end,
    })

    -- 🗑 The bulk doors, beside the per-row ✕. Named after what they do
    -- to the LIST, never to the files: nothing here deletes a film.
    function _G.mugForgetHistory(path)
        local list, gone = vid.forgetHistory(vid.history, path)
        if gone == 0 then
            print("🎬 no history row for " .. tostring(path)) ; return false
        end
        vid.history = list
        vid.forgotten = vid.forgotten + gone
        vid.save() ; vid.render()
        print("🎬 forgot " .. gone .. " history row(s) for " .. tostring(path))
        return true
    end

    function _G.mugClearHistory()
        local n = #vid.history
        vid.history = {}
        vid.forgotten = vid.forgotten + n
        vid.save() ; vid.render()
        print("🎬 history cleared — " .. n .. " row(s) forgotten. The films "
              .. "themselves are untouched.")
        return n
    end

    -- 🔎 THE REPORT. A report PRINTS AS ONE STRING (6.179.1): the console
    -- gate silences a repeated short line and splices banners through a
    -- row-by-row print.
    function _G.mugReport()
        local L = {}
        L[#L + 1] = "🎬 " .. BRAND:upper() .. " — " .. KEYLABEL
        L[#L + 1] = "   doors  : " .. (vid.doors or 0) .. " way(s) in registered"
                    .. ((vid.doors or 0) == 0
                        and "  ⚠️ NONE — nothing opens this window" or "")
        L[#L + 1] = "   window : " .. (vid.webview and "open" or "closed")
                    .. " · " .. tostring(vid.posWhy)
        L[#L + 1] = "   format : plays " .. (function()
            local n = {} ; for k in pairs(vid.exts) do n[#n + 1] = "." .. k end
            table.sort(n) ; return table.concat(n, " ")
        end)() .. "  (his scope — widening it is a settings line, not a release)"
        L[#L + 1] = "   queue  : " .. #vid.queue .. " film(s)"
                    .. (vid.queue[vid.index]
                        and (" · playing #" .. vid.index .. " "
                             .. (vid.queue[vid.index].title or "")) or " · nothing playing")
        L[#L + 1] = "   history: " .. #vid.history .. " film(s) kept — one row per"
                    .. " file, rows are kept for up to " .. vid.historyDays
                    .. " day(s) (the WINDOW, not a claim about this Mac)"
        if vid.forgotten > 0 then
            L[#L + 1] = "   forgot : " .. vid.forgotten .. " history row(s) removed"
                        .. " this session"
        end
        -- 🪟 THE LINE THIS RELEASE EXISTS FOR. Three states, and the
        -- third is not the second (6.196.1): a film that has never been
        -- tried is not a film macOS refused.
        L[#L + 1] = "   way in : " .. (vid.doorWorked
            and (vid.doorWorked .. " — this is the one that carried a film")
            or "⏳ no film has loaded yet, so nothing has been measured")
        local failed = {}
        for k, n in pairs(vid.doorFailed) do failed[#failed + 1] = k .. " ×" .. n end
        table.sort(failed)
        if #failed > 0 then
            L[#L + 1] = "   refused: " .. table.concat(failed, " · ")
        end
        L[#L + 1] = "   store  : " .. vid.storeVerdict(vid.storeState, vid.storeBytes,
                                                       #vid.queue, #vid.history)
        L[#L + 1] = "   ↳ " .. vid.storeFile .. "  (LOCAL — never OneDrive)"
        L[#L + 1] = "   drop   : " .. tostring(vid.dropWhy)
                    .. " · " .. tostring(vid.dragSeen)
                    .. (vid.dropReader and (" · read by " .. vid.dropReader) or "")
        if #vid.refused > 0 then
            L[#L + 1] = "   not played:"
            for i = 1, math.min(#vid.refused, 5) do
                L[#L + 1] = "      " .. vid.titleOf(vid.refused[i].path)
                            .. " — " .. vid.refused[i].why
            end
        end
        L[#L + 1] = "   page   : " .. (vid.pageReady and "ready" or "⚠️ has NOT said"
                    .. " it is ready") .. " · " .. vid.draws.landed
                    .. " draw(s) landed · " .. vid.draws.early .. " pushed early"
        L[#L + 1] = "   keyboard: " .. tostring((vid.focus or {}).why or "not asked")
        L[#L + 1] = "   ⏯ keys : NOT taken here, deliberately — the Jug Player"
                    .. " holds F7/F8/F9 while its card is up, and two tools on"
        L[#L + 1] = "            one physical key is how they come to disagree."
                    .. "  With the film focused macOS routes them to it anyway."
        L[#L + 1] = "   played : " .. vid.plays .. " this session · "
                    .. vid.externals .. " handed to QuickTime"
        L[#L + 1] = "   last   : " .. tostring(vid.lastWhy)
        print(table.concat(L, "\n"))
        return true
    end

    _G.mugPlayer = vid
    M.vid    = vid
    M.config = vid
end

-- The store is read in warm(), not setup(): boot is measured, and a JSON
-- read is not needed to answer a keypress (6.267.0). Nothing is STARTED
-- here either — there is no tap and no timer to switch off, which is the
-- whole reason this module has no ⏯ claim.
function M.warm(core)
    local vid = M.vid
    if not vid then return end
    if not vid.enabled then return end
    if not vid.loaded then pcall(vid.loadStore) end
end

return M
