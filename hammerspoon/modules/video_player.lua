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
        -- 🚚 6.352.0 — THE TWO DOORS, COUNTED APART. A drop that arrives
        -- through the page and one that arrives through the canvas
        -- underneath are different facts, and a report that sums them
        -- cannot say which door is carrying the feature (6.229.0).
        pageDrops  = 0,
        catchDrops = 0,
        uriWhy     = nil,            -- why the page's own door cannot read
        catcherOn  = false,          -- macOS AGREED to put the catcher up
        catchRefused = 0,            -- and how often it would not
        pageSpoke  = false,          -- the page said ready at least once
        refused    = {},             -- { path=, why= } — named, never silent
        plays      = 0,
        externals  = 0,              -- how many went out to a real player
        handedOff  = 0,              -- …of those, how many this tool DECIDED
        byHand     = 0,              -- …and how many he opened with ⌘O
        -- 🚪 6.353.0 — WHEN EVERY WAY IN HAS BEEN REFUSED, THE FILM GOES
        -- OUT. Three doors have answered on his Mac and the webview is
        -- not the surface, so a window that can only say "it would not
        -- play" is a window that does not work. `false` leaves the
        -- alert and waits for ⌘O.
        handOff    = true,
        -- 📦 6.354.0 — THE THIRD DOOR IS NOT A URL AT ALL. Both file://
        -- doors are refused on his Mac and `hs.webview` has no way to
        -- grant one: `loadFileURL:allowingReadAccessToURL:`,
        -- `allowFileAccessFromFileURLs` and `setURLSchemeHandler:` each
        -- appear ZERO times in extensions/webview/libwebview.m (172,646
        -- bytes, read rather than remembered — 6.233.0). So the bytes
        -- stop travelling as a URL: Lua reads the film in bounded
        -- chunks and PUSHES them into the page, which assembles a Blob
        -- and plays that. Nothing is fetched, nothing is navigated to,
        -- and there is no file for WebKit to refuse.
        blobLoad   = true,
        chunkBytes = 8 * 1024 * 1024,   -- read and pushed per turn
        loadEvery  = 0,                 -- the gap between turns, in seconds
        -- 📏 6.355.0 — THE CEILING IS ASKED OF THE MAC, NOT TYPED.
        -- 6.354.0 wrote 1536 MB and his first real film was 2300.6 MB, so
        -- the loader was never asked and every way in read as refused.
        -- The whole film ends up in WebKit's blob store, so memory IS the
        -- bound — which makes it a thing to MEASURE rather than guess.
        -- `blobMax` nil means "ask"; a number still overrides, so the
        -- knob is real and the gate drives both.
        blobMax    = nil,
        blobShare  = 1 / 3,             -- of this Mac's physical memory
        blobFloor  = 3 * 1024 * 1024 * 1024,
        blobCap    = 8 * 1024 * 1024 * 1024,
        slowTurnMs = 120,               -- past this a turn takes the 🔔 door
        -- 🛟 6.355.0 — THE PAGE SAYS WHEN IT HAS TAKEN A CHUNK.
        -- `evaluateJavaScript` RETURNS BEFORE THE SCRIPT RUNS (read in
        -- extensions/webview/libwebview.m:1688-1725 — it hands WebKit a
        -- completion handler and returns at once), so re-arming on a
        -- clock pushes faster than the window can swallow: a 2.3 GB film
        -- is 288 chunks queued into IPC buffers on top of the blob. The
        -- next turn is armed from the COMPLETION, so exactly one chunk
        -- is ever in flight. This belt covers a completion that never
        -- arrives, in its own held slot (6.196.1).
        ackSecs    = 20,
        ackTimer   = nil,
        acks       = 0,
        ackLate    = 0,
        ackNoBelt  = 0,
        loadTimer  = nil,               -- HELD, its own slot (6.196.1)
        load       = nil,               -- the read in flight
        loadRuns   = 0,                 -- films the loader was asked for
        loadTurns  = 0,
        loadWorst  = 0,
        loadBytes  = 0,
        blobPlayed = 0,
        blobFailed = 0,
        loadSlow   = 0,
        loadWhy    = "the loader has not been asked yet",
        loadMs     = 0,                 -- wall clock of the last whole read
        ceilBytes  = nil,               -- worked out once, then kept
        ceilWhy    = "the ceiling has not been asked for yet",
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
            -- 📦 AND THE THIRD DOOR IS NOT A URL — THAT IS THE WHOLE
            -- POINT OF IT. 6.351.0 built a third URL (a page written as
            -- a FILE beside the film, asked for by file URL) and macOS
            -- refused it by name: his screenshot is WebKit's own
            -- navigation error page, "An Error code: -3001 in
            -- NSURLErrorDomain occurred during navigation: Cannot open
            -- file". -3001 is NSURLErrorCannotOpenFile and it is a
            -- NAVIGATION error, so unlike MediaError code 4 it is not
            -- ambiguous: the file was not read. Worse, a refused
            -- `view:url()` REPLACES the document, so that door destroyed
            -- the deck, the queue and every key — it was deleted in
            -- 6.353.0 and is not coming back.
            -- 🔬 AND THERE IS NO FOURTH URL TO TRY, read rather than
            -- believed: `loadFileURL:allowingReadAccessToURL:`,
            -- `allowFileAccessFromFileURLs` and `setURLSchemeHandler:`
            -- appear ZERO times in extensions/webview/libwebview.m. So
            -- every way of NAMING the file is spent, which is 6.266.0's
            -- rule — when every fix so far has changed something inside
            -- the same pipeline, the pipeline IS the variable.
            -- 🚪 `src` IS DELIBERATELY EMPTY and `bytes` is what the
            -- door-walker reads: this one carries no URL, so advancing
            -- to it needs no new document and no rebuild. Lua reads the
            -- film and pushes it in.
            { how   = "the bytes through the window, not a URL",
              base  = nil,
              src   = "",
              bytes = true },
        }
    end

    -- 📏 Megabytes, for a sentence a person reads.
    function vid.mb(n)
        local b = tonumber(n) or 0
        return string.format("%.1f MB", b / 1048576)
    end

    -- 📏 THE CEILING IS A MEASUREMENT (6.355.0). PURE, four
    -- answers, and the one that matters is the FIRST: a Mac that will
    -- not say how much memory it has gets the FLOOR, never 0 — a parser
    -- that fails into a valid-looking number refuses every film and
    -- reads as "your film is too big" (6.338.0).
    function vid.ceilingFor(mem, share, floorB, capB)
        local m  = tonumber(mem)
        local sh = tonumber(share) or (1 / 3)
        local fl = math.floor(tonumber(floorB) or 0)
        local cp = math.floor(tonumber(capB) or 0)
        if not m or m <= 0 then
            return fl, "this Mac would not say how much memory it has, so"
                       .. " the floor of " .. vid.mb(fl) .. " stands"
        end
        local want = math.floor(m * sh)
        if cp > 0 and want > cp then
            return cp, vid.mb(cp) .. " — the cap, because past it the"
                       .. " reading takes longer than opening a real player"
        end
        if want < fl then
            return fl, vid.mb(fl) .. " — the floor, which is more than a"
                       .. " share of this Mac's " .. vid.mb(m)
        end
        return want, vid.mb(want) .. " — a share of this Mac's "
                     .. vid.mb(m) .. " of memory"
    end

    -- 🚪 ONE DOOR, THREE CALLERS (6.231.0): the plan, the refusal
    -- sentence and the report all ask this, so they cannot disagree about
    -- what the ceiling is. Asked once per session — physical memory does
    -- not move — and a `blobMax` number still wins, so the knob is real.
    function vid.maxBytes()
        local set = tonumber(vid.blobMax)
        if set and set > 0 then
            vid.ceilBytes = math.floor(set)
            vid.ceilWhy   = vid.mb(set) .. " — your own settings line"
            return vid.ceilBytes
        end
        if vid.ceilBytes then return vid.ceilBytes end
        local mem = nil
        if hs.host and hs.host.vmStat then
            local ok, t = pcall(hs.host.vmStat)
            if ok and type(t) == "table" then mem = tonumber(t.memSize) end
        end
        vid.ceilBytes, vid.ceilWhy =
            vid.ceilingFor(mem, vid.blobShare, vid.blobFloor, vid.blobCap)
        return vid.ceilBytes
    end

    -- 📐 FOUR ANSWERS, AND ONLY ONE LOADS (6.196.1). PURE, so the whole
    -- rule is proven with no Mac and no film: a size the Mac would not
    -- give is not a size of 0, and a chunk of 0 is a loader that never
    -- finishes rather than one that finishes instantly.
    function vid.loadPlan(size, max, chunk)
        local s = tonumber(size)
        local m = tonumber(max) or 0
        local c = math.floor(tonumber(chunk) or 0)
        if not s or s <= 0 then
            return false, "the Mac would not say how big the film is", 0
        end
        if c < 1 then
            return false, "the chunk size is 0 — a loader that never"
                          .. " finishes", 0
        end
        -- 🚨 THE CEILING IS A `>`, NOT A `>=`: a film exactly at the
        -- ceiling is a film the ceiling allows, and the fixture that
        -- bites is the pair at size == max and size == max + 1, where
        -- the two readings must differ (6.230.0).
        if m > 0 and s > m then
            return false, "the film is " .. vid.mb(s) .. " and the ceiling"
                          .. " is " .. vid.mb(m) .. " — more than this"
                          .. " window can hold", 0
        end
        local turns = math.ceil(s / c)
        return true, "reading " .. vid.mb(s) .. " in " .. turns
                     .. " turn(s) of " .. vid.mb(c), turns
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
        elseif state == "saved" then
            -- 6.312.0's rule one layer on: the verdict was captured at
            -- the LOAD and never moved, so a Mac that had queued two
            -- films went on reading "no store file yet" over a store
            -- that had just been written. A report must describe the
            -- disk as it is now, not as it was at boot.
            return "written " .. (tonumber(bytes) or 0) .. " bytes — "
                   .. (tonumber(nq) or 0) .. " queued · "
                   .. (tonumber(nh) or 0) .. " history row(s)"
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

    -- The dot-file door 3 writes into the film's own folder, and
    -- removes again the moment the window closes or the film changes.
    -- A dot-file so Finder does not show it, and ONE name so there can
    -- never be a second one left behind.

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
        vid.storeState = "saved"
        vid.storeBytes = #raw
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
    -- 🚨 `hs.json.encode` TAKES A TABLE, AND A BARE STRING IS NOT ONE
    -- (6.345.0, and it is the whole of why 6.344.0 drew a black
    -- rectangle). This function handed it `tostring(s)`: LuaSkin's
    -- checkArgs RAISES on a non-table, the pcall caught the raise, and
    -- every string in the payload came back `""` — the film's src, its
    -- name, the brand, every row in the deck. One defect, five symptoms,
    -- all five visible in one screenshot of his.
    -- 🔎 AND IT IS THE ONLY CALL OF ITS KIND: the other nineteen
    -- hs.json.encode sites in this config all pass a TABLE, which is why
    -- nothing else has ever hit it. A grep for the shape is what named
    -- it in one line.
    -- 🔑 SO THE ESCAPER IS OURS NOW, and that is the half that closes the
    -- class rather than the instance: a pure Lua function cannot be made
    -- gentler by a stub (6.290.0 — the gate's fake hs.json encoded a
    -- bare string happily, which is why 44 page checks were green over a
    -- payload no Mac could produce), and it is proven with no Mac.
    function vid.jsonStr(s)
        local out = tostring(s or "")
        out = out:gsub("[\\\"]", "\\%0")
        out = out:gsub("%c", function(c)
            return string.format("\\u%04X", string.byte(c))
        end)
        -- The payload is a JS object literal inside a <script> block, so
        -- a film called "</script>.mp4" would end it. < > & cost nothing
        -- to escape and the page reads them back identically.
        out = out:gsub("[<>&]", function(c)
            return string.format("\\u%04X", string.byte(c))
        end)
        -- U+2028 and U+2029 are legal inside a JSON string and were a
        -- syntax error inside a JS string literal until ES2019. A file
        -- may be called anything, so they are escaped rather than hoped
        -- past. Bytes above 0x7F are otherwise left alone: UTF-8 is
        -- valid in a JSON string and re-encoding it would be the
        -- 6.237.0 mistake of correcting a name that was already right.
        out = out:gsub("\226\128\168", "\\u2028")
                 :gsub("\226\128\169", "\\u2029")
        return '"' .. out .. '"'
    end
    local jstr = vid.jsonStr

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
               -- 🚪 WHETHER THE PAGE MAY CLAIM A DRAG AT ALL. The page's
               -- own handler must preventDefault() to receive a drop, and
               -- that claim TAKES the drag away from the catcher
               -- underneath — so a page whose reader is absent would
               -- swallow every drop and do nothing, which is worse than
               -- the single door this release is fixing. The decision is
               -- made from a measured fact, here, and baked into the
               -- document the page is built from.
               .. ",pd:" .. tostring(vid.pageDoorLive())
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
/* 📦 THE BYTES COME THROUGH THE WINDOW (6.354.0). Lua reads the film in
   chunks and pushes each one here; the page decodes it, hands it
   straight to the blob store and plays the assembled Blob. Nothing is
   fetched and nothing is navigated to, so there is no file for WebKit to
   refuse — which is what both file:// doors were refused for.
   🚨 THE DECODE IS SYNCHRONOUS ON PURPOSE. An async decode (fetch on a
   data: URL) is faster in C but resolves OUT OF ORDER, and two chunks
   landing the wrong way round is a scrambled film with nothing to see
   but a decode error. Order by construction beats order by bookkeeping.
   🚨 AND EACH CHUNK IS WRAPPED IN ITS OWN Blob AT ONCE, so the bytes
   leave the JS heap every turn instead of 700 MB of Uint8Array piling up
   waiting for the end. */
var BQ=null,BTOT=0,BGOT=0,BURL=null,BGEN=0;
function blobDrop(){BQ=null;
 if(BURL){try{URL.revokeObjectURL(BURL)}catch(e){}BURL=null}}
function blobStart(t,g){
 blobDrop();
 var v=el('v');
 v.removeAttribute('data-src');v.removeAttribute('src');
 try{v.load()}catch(e){}
 BQ=[];BTOT=+t||0;BGOT=0;BGEN=+g||0;
 fail('⏳ reading the film into the window — 0%');
}
function blobChunk(b64){
 if(!BQ)return;
 try{
   var s=atob(b64),n=s.length,u=new Uint8Array(n);
   for(var i=0;i<n;i++)u[i]=s.charCodeAt(i);
   BQ.push(new Blob([u]));
   BGOT+=n;
   var pc=BTOT>0?Math.floor(BGOT*100/BTOT):0;
   fail('⏳ reading the film into the window — '+pc+'%');
 }catch(e){var w=String(e);BQ=null;say({a:'blobfail',gen:BGEN,why:w})}
}
function blobEnd(){
 if(!BQ)return;
 var parts=BQ;BQ=null;
 try{
   var b=new Blob(parts,{type:'video/mp4'});
   if(BURL){try{URL.revokeObjectURL(BURL)}catch(e){}}
   BURL=URL.createObjectURL(b);
   var v=el('v');clearFail();
   v.setAttribute('data-src','blob');v.src=BURL;
   try{v.load()}catch(e){}
   try{v.play()}catch(e){}
 }catch(e){BURL=null;say({a:'blobfail',gen:BGEN,why:String(e)})}
}
function draw(s){
 if(s&&typeof s==='object')S=s;
 var q=(S&&S.q)||[],h=(S&&S.h)||[];
 el('brand').textContent=(S&&S.brand)||'';
 el('now').textContent=(S&&S.name)||'nothing playing';
 var v=el('v');
 var want=(S&&S.src)||'';
 if(want){ if(v.getAttribute('data-src')!==want){
    /* 📦 A URL DOOR MEANS A NEW FILM, so any Blob still driving the
       stage is revoked rather than left to leak an object URL and go on
       playing the film before it. */
    blobDrop();
    clearFail(); v.setAttribute('data-src',want); v.src=want;
    try{v.load()}catch(e){} } }
 /* 📦 AN EMPTY src MEANS THE BYTES DOOR, NOT AN EMPTY STAGE. Door 3
    carries no URL, so every redraw after the Blob is playing would have
    torn the film down — the guard is `BURL`, which is set only once a
    Blob really is the source. */
 else if(!BURL){ v.removeAttribute('data-src'); v.removeAttribute('src');
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
/* 🚚 THE WINDOW'S OWN DROP (6.352.0), and the Jug Player has had it since
   6.233.0. A DROPPED FILE'S PATH DOES NOT COME FROM dataTransfer.files —
   WebKit never hands a page a File's path, so .name is a name and nothing
   openable. It comes from text/uri-list, which Finder fills with file://
   URLs, and the percent-escapes are undone on the Lua side by the one
   parser both players share.
   🚨 AND THE CLAIM IS CONDITIONAL. preventDefault() is what makes this
   window accept a drag, and accepting it TAKES it from the catcher
   underneath — so with no reader in Lua this handler stands down and lets
   the canvas have it. A door that claims a drop it cannot read is worse
   than no door. */
document.addEventListener('dragover',function(e){
 if(!(S&&S.pd))return;
 e.preventDefault();dropShow(true);
});
document.addEventListener('dragleave',function(e){
 if(e.target===document||e.relatedTarget===null)dropShow(false);
});
document.addEventListener('drop',function(e){
 if(!(S&&S.pd))return;
 e.preventDefault();dropShow(false);
 var uri='';
 try{uri=e.dataTransfer.getData('text/uri-list')||''}catch(x){}
 if(!uri){try{uri=e.dataTransfer.getData('text/plain')||''}catch(x){}}
 var names=[];
 try{for(var i=0;i<(e.dataTransfer.files||[]).length;i++)
   names.push(e.dataTransfer.files[i].name)}catch(x){}
 // 🚨 'filedrop', NEVER 'drop' — in THIS page 'drop' is the ⌫ key, which
 // REMOVES a film from the queue. One shared name and dropping films onto
 // the window would delete one instead (6.272.0's ✕-before-the-row, in a
 // message name).
 say({a:'filedrop',uri:uri,names:names});
});
document.addEventListener('keydown',function(e){
 var v=el('v');
 if(e.metaKey&&e.key>='1'&&e.key<='9'){e.preventDefault();
   say({a:'play',k:'q',i:+e.key});return}
 if(e.metaKey&&(e.key==='o'||e.key==='O')){e.preventDefault();
   say({a:'external'});return}
 if(e.metaKey)return;
 if(e.key==='Escape'){
   // 🪟 WEBKIT OWNS ESC WHILE THE FILM IS FULL SCREEN. Taking it here
   // would leave him inside a full-screen film with no way out — a
   // native control this release promised and must not quietly remove
   // (6.318.0: when you take a surface over, you inherit what it did).
   if(document.fullscreenElement||document.webkitFullscreenElement)return;
   e.preventDefault();say({a:'close'});return}
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
   // The MediaError is the only thing that can say WHY a door refused,
   // and it is the fact Lua cannot get any other way.
   var er=v.error||{};
   say({a:'srcfail',d:S.door,gen:S.gen,code:(er.code||0),
        why:(er.message||'')});
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

    -- 🧪 PUBLISHED so the gate can RUN this page rather than grep it.
    -- A page this config draws is a page the gate runs (6.231.1): four
    -- pages had a suite and the fifth did not, and asking for it found
    -- the bug in a minute.
    vid.buildPage = buildHtml

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

    -- 🧹 AND THIS MODULE NO LONGER WRITES ANYTHING INTO HIS FILM
    -- FOLDERS, nor removes anything from them. 6.351.0's stage file
    -- needed `os.remove` on a path built from a folder full of his
    -- films — the one failure here with no way back (6.280.0) — and it
    -- was guarded twice and proven twice. The guards were right and the
    -- DOOR they protected is gone, so the safest version of that code
    -- is the version that does not exist. A source sentry keeps it out.

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
            -- 🚨 NOTHING HERE NAVIGATES. 6.351.0's door 3 called
            -- `view:url()`, and a refused navigation REPLACES the
            -- document — so a door that failed took the deck, the queue
            -- and every key with it and left an error page behind. The
            -- page is only ever handed to WebKit as a STRING now, which
            -- cannot destroy the room even when the film will not load.
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

        -- 🪪 ONE TOKEN PER SHOW. The retry below fires a beat later and
        -- must be able to tell ITS run from a newer one — 6.304.0's
        -- generation counter, in the smallest place it has ever been
        -- needed.
        vid.showToken = (tonumber(vid.showToken) or 0) + 1
        local token = vid.showToken

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
        -- 🪟 EVERYTHING THAT HAPPENS ONCE macOS HAS AGREED, in one place
        -- so the retry below cannot do half of it. The handle is still
        -- recorded only after the show has answered (6.326.0).
        local function landed()
            vid.webview = view
            vid.draws = { landed = 0, early = 0 }
            pcall(function() view:bringToFront(true) end)
            chaseFocus()
            vid.startCatcher(rect)
            if _G.hyperExpectRelease then
                pcall(_G.hyperExpectRelease, 1.5, "mugPlayer")
            end
        end

        vid.shows = (tonumber(vid.shows) or 0) + 1
        local shown = false
        pcall(function() shown = view:show() ~= false end)
        if shown then landed() ; return true end

        -- 🚨 macOS REFUSED TO ORDER THE WINDOW ON SCREEN, and his
        -- 2026-10-10 20:45:51 Console is why this branch grew a retry:
        --     -- Loading extension: webview
        --     -- Loading extension: drawing
        --     ⚠️ Mug Player: macOS would not put the window on screen
        -- Three lines, ONE SECOND. The first ⇪⇧, of a session pays TWO
        -- main-thread dylib loads (hs.webview when the bridge is made,
        -- hs.drawing when the level is set) and then asks AppKit to
        -- order a window on screen in the same turn. 6.330.0 named lazy
        -- extension loading as an unmeasured cost on his Mac — his own
        -- log has them twenty-six seconds apart — and M.warm now pays
        -- both off the keypress so this turn is cheap. That is aimed at
        -- a CANDIDATE and is NOT claimed as the cause (6.198.0).
        -- 🔑 THE RETRY IS THE PART THAT WORKS WHATEVER THE CAUSE, and it
        -- is 6.266.0's shape rather than 6.56.0's: the caller decides,
        -- here, so nothing can be put on screen that this module has
        -- stopped tracking. ONE retry — a second refusal is a real no.
        vid.refusedShows = (tonumber(vid.refusedShows) or 0) + 1
        local okT, t = pcall(hs.timer.doAfter, tonumber(vid.retryShowSecs) or 0.12,
            function()
                vid.retryTimer = nil
                -- He may have given up and pressed the key again, or
                -- closed it, in the beat we waited. A retry that acts on
                -- a decision since reversed is exactly what 6.266.0 is
                -- about, so the run has to still be the live one.
                if vid.webview or vid.showToken ~= token then
                    pcall(function() view:delete() end) ; return
                end
                local ok2 = false
                pcall(function() ok2 = view:show() ~= false end)
                if ok2 then
                    vid.recovered = (tonumber(vid.recovered) or 0) + 1
                    landed()
                    return
                end
                pcall(function() view:delete() end)
                vid.uc = nil
                vid.lostShows = (tonumber(vid.lostShows) or 0) + 1
                degrade("macOS would not put the window on screen, twice — "
                        .. "press " .. KEYLABEL .. " again")
            end)
        if okT and t then
            vid.retryTimer = t
            return true
        end
        -- 🛟 A Mac that cannot arm a timer gets the old behaviour rather
        -- than a window nobody will ever retry (6.255.0's rule: a belt
        -- that cannot be armed is COUNTED, never silently skipped).
        vid.noBelt = (tonumber(vid.noBelt) or 0) + 1
        pcall(function() view:delete() end)
        vid.uc = nil
        vid.lostShows = (tonumber(vid.lostShows) or 0) + 1
        return degrade("macOS would not put the window on screen — "
                       .. "press " .. KEYLABEL .. " again")
    end

    function vid.hide()
        -- A retry in flight is a window about to be put on screen that
        -- nobody asked for any more. The token moves too, so a callback
        -- already running finds its run superseded.
        vid.showToken = (tonumber(vid.showToken) or 0) + 1
        if vid.retryTimer then
            pcall(function() vid.retryTimer:stop() end)
            vid.retryTimer = nil
        end
        stopFocusChase()
        vid.stopCatcher()
        -- 📦 A READ IN FLIGHT IS A FILE HANDLE AND A HELD TIMER, and a
        -- feature holding both owes a teardown to every door that can end
        -- it (6.256.0). Without this, closing the window mid-read leaves
        -- the handle open and the next turn pushing into a webview that
        -- has been deleted.
        vid.loadStop("the window was closed mid-read")
        if vid.webview then
            pcall(function() vid.webview:delete() end)
            vid.webview = nil
        end
        vid.uc = nil
        vid.pageReady = false
        -- 🔎 `dropWhy` IS NOT OVERWRITTEN HERE, and the mutation sweep is
        -- what decided it: the report reads `vid.catcher` for the STATE
        -- now, so this field is free to carry the last REASON — "window
        -- closed · last: ready" says the catcher was up and fine when the
        -- window went, where "last: the window is closed" is redundant
        -- and throws that away. 6.199.0 from the other side: the line no
        -- mutation could kill was not spare, it was WORSE than nothing.
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
        vid.catcherOn = false
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
                        vid.dropReader  = how
                        vid.catchDrops  = vid.catchDrops + 1
                        vid.dragSeen = #paths .. " file(s) dropped — carried by"
                                       .. " the catcher underneath"
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
        -- 🪟 A HANDLE RECORDED BEFORE THE WINDOW IS UP IS A HANDLE THAT
        -- LIES (6.326.0). hs.canvas:show() THROWS when AppKit refuses to
        -- order the window on screen, and this Mac is measurably one that
        -- refuses (6.265.0 · 6.274.0 · 6.314.0 · 6.348.0) — so discarding
        -- that answer recorded a catcher which is NOT on screen as
        -- "ready", and a canvas that is not up catches nothing. The report
        -- then said the drop was fine about a door that did not exist.
        local okS = pcall(function() cv:show() end)
        if not okS then
            vid.catchRefused = vid.catchRefused + 1
            vid.catcherOn    = false
            pcall(function() cv:delete() end)
            vid.dropWhy = "macOS would not put the drop catcher on screen"
            -- 🔑 AND IT IS NO LONGER THE WHOLE FEATURE: the window's own
            -- handler is the other door, which is the point of this
            -- release rather than a consolation.
            return degrade(vid.dropWhy .. " — the window's own drop handler"
                           .. " is the way in while that lasts")
        end
        vid.catcher   = cv
        vid.catcherOn = true
        vid.dropWhy   = "ready"
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

    -- 🔌 ONE PARSER, TWO CALLERS (6.231.0). `drag.urilist` is the Jug
    -- Player's own `mp.pathsFromURIList`, published as a service in this
    -- release beside `drag.paths`: the rule that the percent-escapes
    -- belong to the URL and NOT to a plain POSIX path (which may legally
    -- hold a % — "50%25 off.mp4" is a real file name) is 6.237.0's
    -- knowledge and a second copy of it here is how the two come to
    -- disagree about the same drag.
    function vid.pageDoorLive()
        return not not (_G.service and _G.service.has
                        and _G.service.has("drag.urilist"))
    end

    -- 🔎 ITS ABSENCE IS AN ANSWER, NOT A CRASH: with no reader the page
    -- never claims the drag at all (`pd` in the payload), so the catcher
    -- underneath keeps the feature and the report says which door is
    -- carrying it. IT DEGRADES, IT NEVER BREAKS.
    function vid.uriPaths(text)
        if not vid.pageDoorLive() then
            vid.uriWhy = "the shared uri-list reader is not loaded (it lives "
                         .. "in the Jug Player's module) — the window's own "
                         .. "drop stands down and the catcher underneath takes "
                         .. "the drag"
            return {}, "no reader"
        end
        vid.uriWhy = nil
        local ok, paths = pcall(_G.service.call, "drag.urilist", text)
        if not (ok and type(paths) == "table") then
            return {}, "nothing readable"
        end
        return paths, "text/uri-list"
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
        -- 📦 AND THE READ FOR THE FILM BEFORE IT ENDS HERE. The
        -- generation already stops its next TURN, but the file handle is
        -- only closed by going through the one door (6.304.0).
        vid.loadStop("a different film was played")
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
    -- 🚪 THE WAY OUT MUST WORK WHEN NOTHING IS PLAYING — THAT IS WHEN
    -- IT IS NEEDED (6.265.0's shape: the right answer one branch away,
    -- unreachable). LL: "⌘+o just says nothing is playing", with six
    -- films in the deck and a row highlighted. It read `vid.index`
    -- alone, and `vid.index` is 0 whenever no film has started — which
    -- on a Mac where no film CAN start is always. `pick` is PURE and
    -- answers the row AND why, so the gate proves the fallback order
    -- with no window.
    function vid.exitPick(index, queue, selList, sel)
        local i = tonumber(index) or 0
        if queue[i] then return queue[i], "the film that is playing" end
        if selList == "queue" then
            local s = tonumber(sel) or 0
            if queue[s] then return queue[s], "the row you have selected" end
        end
        if queue[1] then return queue[1], "the first film in the queue" end
        return nil, "there is nothing in the queue to open"
    end

    function vid.openExternal(path, auto)
        local t, why
        if type(path) == "string" and path ~= "" then
            t, why = { path = path, title = vid.titleOf(path) }, "this film"
        else
            t, why = vid.exitPick(vid.index, vid.queue, vid.selList, vid.sel)
        end
        if not t then say(why) return false, why end
        vid.externals = vid.externals + 1
        if auto then vid.handedOff = vid.handedOff + 1
        else vid.byHand = vid.byHand + 1 end
        local ok = pcall(function()
            hs.task.new("/usr/bin/open", nil, { t.path }):start()
        end)
        if not ok then return degrade("could not hand the film to macOS") end
        say("opened in your player — " .. (t.title or "") .. " (" .. why .. ")")
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

    -- 🔢 A NUMBER OUT OF A PAGE MESSAGE IS A FLOAT. hs.json decodes
    -- every JS number as a double, so `{i:1}` arrives as 1.0 and
    -- `vid.index` printed as "#1.0" in his report. Lua normalises a
    -- float key with an integral value, so every TABLE lookup was right
    -- all along — what was wrong is the number this config shows him,
    -- which is 6.282.0's rule one step earlier: coerce where the value
    -- is BORN, not where it is printed, or the next reader gets it raw.
    local function asRow(n)
        local x = tonumber(n)
        if not x then return 0 end
        return math.tointeger(x) or math.floor(x)
    end
    vid.asRow = asRow

    -- 🔬 WHAT IS THIS FILM, ACTUALLY? Asked only when every door has
    -- refused, once per film, in a HELD task off the main thread
    -- (6.228.0). It changes nothing — it is the line that decides
    -- whether the next release is another door or a different player.
    function vid.askCodecs(path)
        if type(path) ~= "string" or path == "" then return false end
        if vid.codecsFor == path then return false end
        vid.codecsFor = path
        vid.codecs = "asking the Mac what this file holds…"
        if not (hs.task and hs.task.new) then
            vid.codecs = "could not ask — no hs.task on this Mac"
            return false
        end
        local okN, t = pcall(hs.task.new, "/usr/bin/mdls",
            function(code, out)
                local text = tostring(out or "")
                local got = {}
                for v in text:gmatch('"([^"]+)"') do got[#got + 1] = v end
                if code == 0 and #got > 0 then
                    vid.codecs = table.concat(got, " · ")
                else
                    vid.codecs = "mdls answered nothing (exit "
                                 .. tostring(code) .. ")"
                end
            end,
            { "-name", "kMDItemCodecs", "-name", "kMDItemMediaTypes", path })
        if not (okN and t) then
            vid.codecs = "could not ask — mdls would not start"
            return false
        end
        -- 🪜 HELD in its own slot (6.196.1): a task nothing references is
        -- collected, and a collected task never calls back.
        vid.codecTask = t
        local started = false
        pcall(function() started = t:start() ~= false end)
        if not started then
            vid.codecs = "could not ask — macOS refused to start mdls"
            vid.codecTask = nil
            return false
        end
        return true
    end

    -- =================================================================
    -- 📦 THE BYTES THROUGH THE WINDOW (6.354.0)
    -- =================================================================
    -- Lua reads the film in bounded chunks and pushes each one into the
    -- page, which assembles a Blob and plays that. No URL, no fetch, no
    -- navigation — so there is nothing for WebKit to refuse read access
    -- to, which is what both file:// doors were refused for.

    -- 📦 A base64 chunk needs NO escaping — it is A–Z a–z 0–9 + / = and
    -- nothing else — so it deliberately does not go through jsEscape:
    -- three gsubs over two and a half megabytes, every turn, on the main
    -- thread (6.228.0). It answers whether the push went, because
    -- evaluateJavaScript on a window macOS has taken away throws.
    -- 🛟 A PUSH THAT RETURNS IS A PUSH THAT WAS ACCEPTED, NOT ONE
    -- THAT LANDED (6.299.0, and read in libwebview.m:1688-1725). `done`
    -- is optional, so every existing caller is unchanged; the loader is
    -- the one that waits.
    local function pushJs(js, done)
        local ok = false
        pcall(function()
            if done then
                vid.webview:evaluateJavaScript(js, done)
            else
                vid.webview:evaluateJavaScript(js)
            end
            ok = true
        end)
        return ok
    end
    vid.pushJs = pushJs

    local loadTurn   -- forward: it re-arms itself

    -- 🚪 EVERY WAY THE READ CAN END COMES THROUGH HERE, and that is
    -- 6.304.0's rule: a busy flag released only by SUCCESS is a wedge.
    -- The file handle is closed on all of them — done, too big, a
    -- refused push, the window closing, a new film, a page that threw.
    function vid.loadStop(why)
        if vid.loadTimer then
            pcall(function() vid.loadTimer:stop() end)
            vid.loadTimer = nil
        end
        if vid.ackTimer then
            pcall(function() vid.ackTimer:stop() end)
            vid.ackTimer = nil
        end
        local L = vid.load
        vid.load = nil
        if L and L.f then pcall(function() L.f:close() end) end
        if why then vid.loadWhy = why end
        return L ~= nil
    end

    loadTurn = function()
        vid.loadTimer = nil
        local L = vid.load
        if not L then return end
        -- 🪪 A GENERATION, so a turn that lands after he closed the
        -- window or played something else is a turn about a film nobody
        -- is waiting for (6.304.0 · 6.348.0).
        if L.gen ~= vid.gen or not vid.webview then
            return vid.loadStop("the film changed while it was being read")
        end
        local t0 = (hs.timer and hs.timer.secondsSinceEpoch
                    and hs.timer.secondsSinceEpoch()) or 0
        local okR, piece = pcall(function() return L.f:read(L.chunk) end)
        if not okR then
            vid.loadStop("the film could not be read: " .. tostring(piece))
            vid.blobFailed = vid.blobFailed + 1
            pushJs("blobDrop();")
            return degrade("the film could not be read off the disk")
        end
        if piece == nil or #piece == 0 then
            -- 📦 EVERY BYTE IS IN. The page assembles and plays.
            local turns, sent = L.turns, L.sent
            local secs = (L.at and L.at > 0 and t0 > 0) and (t0 - L.at) or 0
            vid.loadMs = secs * 1000
            local okE = pushJs("blobEnd();")
            vid.loadStop(string.format("read %s in %d turn(s) over %.1f s",
                                       vid.mb(sent), turns, secs))
            if not okE then
                vid.blobFailed = vid.blobFailed + 1
                return degrade("the window would not take the last of the"
                               .. " film")
            end
            return true
        end
        local okB, b64 = pcall(function() return hs.base64.encode(piece) end)
        if not (okB and type(b64) == "string" and #b64 > 0) then
            vid.loadStop("this Mac could not encode the film for the window")
            vid.blobFailed = vid.blobFailed + 1
            pushJs("blobDrop();")
            return degrade("this Mac could not encode the film for the"
                           .. " window")
        end
        -- 🛟 ARMED BEFORE THE ASK (6.246.0; the check asserts the
        -- ORDER — 6.220.0), in its own held slot (6.196.1), with a
        -- SEQUENCE so a completion that lands after the belt has fired
        -- is about a chunk nobody is waiting for (6.304.0).
        local dA  = hs.timer and hs.timer.doAfter
        L.seq     = (L.seq or 0) + 1
        local seq, gen = L.seq, L.gen
        local function settle(late)
            local C = vid.load
            if not C or C.gen ~= gen or C.waiting ~= seq then return false end
            C.waiting = nil
            if vid.ackTimer then
                pcall(function() vid.ackTimer:stop() end)
                vid.ackTimer = nil
            end
            if late then
                vid.ackLate   = vid.ackLate + 1
                vid.blobFailed = vid.blobFailed + 1
                vid.loadStop("the window never said it had taken a piece of"
                             .. " the film")
                pushJs("blobDrop();")
                degrade("the window stopped taking the film")
                return false
            end
            vid.acks = vid.acks + 1
            return true
        end
        L.waiting = seq
        if dA then
            local okA, atm = pcall(dA, tonumber(vid.ackSecs) or 20,
                                   function() settle(true) end)
            vid.ackTimer = (okA and atm) or nil
        end
        -- 📏 A MAC THAT CANNOT ARM THE BELT STILL READS, and the
        -- miss is COUNTED rather than assumed away (6.304.0).
        if not vid.ackTimer then vid.ackNoBelt = (vid.ackNoBelt or 0) + 1 end
        local okP = pushJs("blobChunk('" .. b64 .. "');", function()
            if not settle(false) then return end
            -- 🚨 `dA and pcall(...)` TRUNCATES pcall TO ONE VALUE, so
            -- the timer object is thrown away and every chunk reads as
            -- "this Mac would not arm a timer" — 6.179.0, in the branch
            -- that re-arms the read. Branch, never an `and` chain.
            local okN, ntm = false, nil
            if dA then
                okN, ntm = pcall(dA, tonumber(vid.loadEvery) or 0, loadTurn)
            end
            if not (okN and ntm) then
                vid.loadStop("this Mac would not arm a timer mid-read")
                vid.blobFailed = vid.blobFailed + 1
                pushJs("blobDrop();")
                return degrade("this Mac stopped arming timers while the"
                               .. " film was being read")
            end
            vid.loadTimer = ntm
        end)
        if not okP then
            vid.loadStop("the window would not take the film")
            vid.blobFailed = vid.blobFailed + 1
            return degrade("the window would not take the film")
        end
        L.sent   = L.sent + #piece
        L.turns  = L.turns + 1
        vid.loadTurns = vid.loadTurns + 1
        vid.loadBytes = vid.loadBytes + #piece
        local ms = (t0 > 0) and
            (((hs.timer and hs.timer.secondsSinceEpoch
               and hs.timer.secondsSinceEpoch()) or t0) - t0) * 1000 or 0
        if ms > (tonumber(vid.loadWorst) or 0) then vid.loadWorst = ms end
        -- 🔔 PAST THE BUDGET IT TAKES THE DOOR, ONCE PER FILM rather than
        -- once per turn: a tool that shouts three hundred times is a tool
        -- he switches off (6.260.0).
        if ms > (tonumber(vid.slowTurnMs) or 120) and not L.said then
            L.said = true
            vid.loadSlow = vid.loadSlow + 1
            degrade(string.format("reading the film is costing %d ms a turn"
                    .. " on the main thread — settings = { video_player ="
                    .. " { chunkBytes = %d } } reads less at a time",
                    math.floor(ms), math.floor((tonumber(vid.chunkBytes)
                    or 2097152) / 2)))
        end
        -- 🚪 THE NEXT TURN IS ARMED BY THE COMPLETION ABOVE, never
        -- here: one chunk in flight, ever. A Mac with no hs.timer at all
        -- is refused at loadStart, so there is nothing to fall back to.
        if not dA then
            vid.loadStop("this Mac would not arm a timer mid-read")
            vid.blobFailed = vid.blobFailed + 1
            pushJs("blobDrop();")
            return degrade("this Mac stopped arming timers while the film"
                           .. " was being read")
        end
        return true
    end
    vid.loadTurnOnce = function() return loadTurn() end

    -- 📦 IT EITHER BEGINS OR IT SAYS WHY — never half.
    function vid.loadStart(row)
        local path = row and row.path
        if type(path) ~= "string" or path == "" then
            vid.loadWhy = "there is no film to read"
            return false
        end
        if not vid.blobLoad then
            vid.loadWhy = "switched off — settings = { video_player ="
                          .. " { blobLoad = true } } turns it back on"
            return false
        end
        vid.loadStop(nil)
        if not (hs.base64 and hs.base64.encode) then
            vid.loadWhy = "this Mac has no hs.base64, so the bytes cannot"
                          .. " be handed to the window"
            return false
        end
        -- 🚨 A MAC THAT CANNOT ARM A TIMER DOES NOT BEGIN. A read that
        -- starts and cannot continue leaves a handle open and a window
        -- claiming to be loading for ever; a film that goes straight out
        -- to a real player is the honest answer (6.255.0's rule, in the
        -- place where the cost is his film rather than a screenshot).
        if not (hs.timer and hs.timer.doAfter) then
            vid.loadWhy = "this Mac cannot arm a timer, so the film is"
                          .. " not read in pieces at all"
            return false
        end
        local size = nil
        if hs.fs and hs.fs.attributes then
            local okA, a = pcall(hs.fs.attributes, path)
            if okA and type(a) == "table" then size = tonumber(a.size) end
        end
        local ok, why, turns = vid.loadPlan(size, vid.maxBytes(),
                                            vid.chunkBytes)
        if not ok then
            vid.loadWhy = why
            return false
        end
        local okO, f = pcall(io.open, path, "rb")
        if not (okO and f) then
            vid.loadWhy = "the film would not open for reading"
            return false
        end
        vid.load = { path = path, f = f, size = size, sent = 0, turns = 0,
                     chunk = math.floor(tonumber(vid.chunkBytes) or 8388608),
                     gen = vid.gen, said = false, seq = 0, waiting = nil,
                     at = (hs.timer and hs.timer.secondsSinceEpoch
                           and hs.timer.secondsSinceEpoch()) or 0 }
        vid.loadRuns = vid.loadRuns + 1
        vid.loadWhy  = why
        -- 📣 THE PAGE IS TOLD THE TOTAL FIRST, so its progress line is a
        -- percentage rather than a spinner, and so a read that stalls is
        -- visible rather than looking like a window that does nothing.
        if not pushJs("blobStart(" .. tostring(size) .. ","
                      .. tostring(vid.gen) .. ");") then
            vid.loadStop("the window would not start the read")
            return false
        end
        local okT, tm = pcall(hs.timer.doAfter,
                              tonumber(vid.loadEvery) or 0, loadTurn)
        if not (okT and tm) then
            vid.loadStop("this Mac would not arm the read")
            pushJs("blobDrop();")
            return false
        end
        vid.loadTimer = tm
        return true
    end

    -- 🚪 EVERY WAY IN HAS BEEN REFUSED — ONE ANSWER, TWO CALLERS
    -- (6.231.0). A film whose doors all failed and a film the page threw
    -- on while assembling it are different events with the same honest
    -- ending, and two copies of this is how they come to disagree about
    -- what he is told.
    local function everyDoorRefused(cur)
        if not cur then return end
        vid.askCodecs(cur.path)
        -- 🚨 EVERY WAY IN REFUSED, AND IT SAYS SO IN WORDS. This is
        -- the state this release exists to make legible rather than
        -- a black rectangle: it names the film, says macOS refused
        -- the window read access, and gives the key that opens it
        -- anyway.
        -- 🚨 AND IT NO LONGER ASSERTS A CAUSE IT HAS NOT MEASURED.
        -- The old sentence said "macOS would not let this window
        -- read" it, which is ONE of the two things code 4 means —
        -- the other is that WebKit read it perfectly well and cannot
        -- decode what is inside. A message that picks a side is a
        -- message that sends the next release the wrong way
        -- (6.320.0: a refusal he cannot act on is a defect even when
        -- the refusal is right).
        vid.lastWhy = "no way in worked for " .. tostring(cur.path)
                      .. " — macOS said " .. tostring(vid.mediaWhy)
        -- 🚪 AND THE FILM GOES OUT RATHER THAN STOPPING HERE. Both
        -- remaining doors have been refused, there is no third (its
        -- own -3001 is why), and a window whose only answer is "it
        -- would not play" is a window that does not work. The film
        -- he asked for opens in a player that CAN read his disk.
        if vid.handOff then
            vid.openExternal(cur.path, true)
            tellPage("fail", "▶︎ " .. (cur.title or "") .. " is opening in"
                     .. " your usual player.  Every way in was refused"
                     .. " — both file URLs, and the bytes straight"
                     .. " through the window (" .. tostring(vid.loadWhy)
                     .. ").  macOS said " .. tostring(vid.mediaWhy)
                     .. ".  _G.mugReport() names what the file holds —"
                     .. " if it is HEVC or AC3, no door will ever help."
                     .. "  settings = { video_player = { handOff = false } }"
                     .. " leaves it here instead.")
            return
        end
        tellPage("fail", "⚠️ " .. (cur.title or "") .. " would not play,"
                 .. " and every way in was refused — both file URLs,"
                 .. " and the bytes straight through the window ("
                 .. tostring(vid.loadWhy) .. ").  ⌘O opens it in"
                 .. " your usual player, from the row you have"
                 .. " selected.  _G.mugReport() names the codecs.")
        return
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
            -- 🔎 AND IT IS REMEMBERED PAST THE CLOSE. hide() resets
            -- pageReady, so "closed, and it had spoken" and "never once
            -- spoke" printed the same ⚠️ — which is 6.196.1 inside the one
            -- line that says whether this window's page runs at all, and
            -- it is why a report taken after closing the window could not
            -- answer that question.
            vid.pageSpoke = true
            return

        elseif a == "srcok" then
            -- 🔑 THE DOOR THAT WORKED, recorded and REMEMBERED. The
            -- generation check is 6.304.0's: a late answer about the film
            -- that was playing a moment ago must not speak for this one.
            if tonumber(body.gen) ~= vid.gen then return end
            local d = asRow(body.d) ; if d < 1 then d = vid.door end
            local doors = vid.sourceDoors((vid.queue[vid.index] or {}).path)
            local won = doors[d]
            vid.doorWorked = (won and won.how) or ("door " .. d)
            if won and won.bytes then vid.blobPlayed = vid.blobPlayed + 1 end
            -- 🚨 ONLY A DOOR THAT CARRIES A URL IS REMEMBERED AS THE ONE
            -- TO START ON. The bytes door has no `src`, so starting
            -- there would paint an empty stage with nothing to fail and
            -- nothing to advance the walker — the loader would never be
            -- reached and the next film would simply never play. The
            -- cheap doors are tried first every time, which also means a
            -- macOS that allows file:// again is used the moment it does.
            if won and not won.bytes then vid.doorStart = d end
            vid.save()
            return

        elseif a == "blobfail" then
            -- 📦 THE PAGE THREW WHILE THE FILM WAS BEING ASSEMBLED. That
            -- is a DIFFERENT fact from a MediaError: the bytes arrived
            -- and WebKit could not make a Blob of them, or ran out of
            -- room. Counted apart, named in the report, and the film
            -- goes out the same way (6.196.1).
            if asRow(body.gen) ~= vid.gen then return end
            vid.loadStop("the window threw while assembling the film: "
                         .. tostring(body.why or "no reason given"))
            vid.blobFailed = vid.blobFailed + 1
            degrade("the window could not hold the film — "
                    .. tostring(body.why or "no reason given"))
            return everyDoorRefused(vid.queue[vid.index])

        elseif a == "srcfail" then
            if tonumber(body.gen) ~= vid.gen then return end
            local d = asRow(body.d) ; if d < 1 then d = vid.door end
            if d ~= vid.door then return end
            -- 🔬 macOS'S OWN WORDS ABOUT THE REFUSAL. A door that failed
            -- because the file is not there and one that failed because
            -- WebKit would not let this window read it are opposite
            -- facts, and only the MediaError can tell them apart — which
            -- is the measurement this new ground is for (6.242.0).
            vid.mediaWhy = "code " .. tostring(asRow(body.code))
                           .. (body.why and body.why ~= ""
                               and (" — " .. tostring(body.why)) or "")
            local cur = vid.queue[vid.index]
            if not cur then return end
            local doors = vid.sourceDoors(cur.path)
            local name = (doors[d] and doors[d].how) or ("door " .. d)
            vid.doorFailed[name] = (tonumber(vid.doorFailed[name]) or 0) + 1
            if d < #doors then
                vid.door = d + 1
                local nxt = doors[vid.door]
                if nxt and nxt.bytes then
                    -- 📦 THE BYTES DOOR CHANGES NO DOCUMENT, so it needs
                    -- no rebuild — and not rebuilding is what makes it
                    -- safe to start the read HERE: the page has just
                    -- spoken to us, so it demonstrably exists, where a
                    -- rebuild would race the read against a document
                    -- WebKit has not parsed yet (6.238.0).
                    vid.render()
                    if vid.loadStart(cur) then return end
                    -- It would not start, and `loadWhy` says which of the
                    -- five reasons. Fall through: the film goes out.
                else
                    -- A new base URL needs a new document, so this is a
                    -- full rebuild — nothing is playing at this moment,
                    -- so nothing is lost.
                    vid.paint(true)
                    return
                end
            end
            -- 🔬 AND THE REPORT ASKS THE MAC WHAT THE FILM ACTUALLY IS.
            -- MediaError code 4 is MEDIA_ERR_SRC_NOT_SUPPORTED, and it
            -- is returned BOTH when WebKit could not fetch the file and
            -- when it fetched it and cannot decode the codec. Those are
            -- opposite facts with opposite fixes — one needs a different
            -- way in, the other needs a different player and no door
            -- will ever help. `mdls` is on every Mac and answers it
            -- outright, off the main thread.
            return everyDoorRefused(cur)

        elseif a == "close" then
            -- ⎋ THE WINDOW HAS THE KEYBOARD, SO THE PAGE HEARS ESC FIRST.
            -- The escape ROUTER claim below is untouched and still covers
            -- the window when it is not focused; this covers it when it
            -- is, which is every time he has just been watching a film.
            -- Two doors, one `vid.hide` (6.231.0) — and the router's own
            -- `active()` reads `vid.webview`, so whichever fires first,
            -- the other finds nothing to close.
            vid.hide()
            return

        elseif a == "ended" then
            if tonumber(body.gen) ~= vid.gen then return end
            local nxt = (tonumber(vid.index) or 0) + 1
            if vid.queue[nxt] then vid.playIndex(nxt) end
            return

        elseif a == "play" then
            local i = asRow(body.i)
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
            local r = vid.history[asRow(body.i)]
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

        elseif a == "filedrop" then
            -- 🚚 THE WINDOW'S OWN DOOR. The page cannot read a path, so it
            -- hands over the drag's text/uri-list verbatim and Lua turns it
            -- into paths through the one parser both players share.
            local paths, how = vid.uriPaths(body.uri)
            vid.dropReader = how
            if #paths == 0 then
                -- 🔎 A DROP WITH NO uri-list IS NAMED, NEVER SWALLOWED
                -- (6.231.0): dataTransfer.files gives NAMES only, so the
                -- names are what the message can honestly report.
                local names = {}
                if type(body.names) == "table" then
                    for _, n in ipairs(body.names) do
                        names[#names + 1] = tostring(n)
                    end
                end
                vid.dragSeen = "a drop arrived with no file URLs in it"
                                .. (#names > 0 and (" — " .. table.concat(names, ", "))
                                    or "")
                say(#names > 0
                    and ("macOS did not hand over the path for "
                         .. table.concat(names, ", "))
                    or "nothing in that drop was a file")
                return
            end
            vid.pageDrops = vid.pageDrops + 1
            vid.dragSeen  = #paths .. " file(s) dropped — carried by the"
                            .. " window's own handler"
            vid.takeDrop(paths)
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
        -- 🔎 "INTERMITTENT" IS A COUNT, NOT A SAMPLE (6.274.0). A show
        -- macOS refused and then allowed is a different fact from one it
        -- refused twice, and the old report could say neither.
        do
            local asked = tonumber(vid.shows) or 0
            local ref   = tonumber(vid.refusedShows) or 0
            if asked > 0 then
                L[#L + 1] = "   opens  : " .. asked .. " asked · "
                            .. (asked - ref) .. " straight through · "
                            .. ref .. " refused by macOS"
                if ref > 0 then
                    L[#L + 1] = "   ↳ " .. (tonumber(vid.recovered) or 0)
                                .. " came up on the retry · "
                                .. (tonumber(vid.lostShows) or 0)
                                .. " refused twice and were torn down"
                end
                if (tonumber(vid.noBelt) or 0) > 0 then
                    L[#L + 1] = "   ↳ ⚠️ " .. vid.noBelt .. " refusal(s) could"
                                .. " not arm a retry — no hs.timer on this Mac"
                end
            end
        end
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
        if vid.codecs then
            L[#L + 1] = "   codecs : " .. tostring(vid.codecs)
            -- 🔑 AND THE BYTES DOOR SETTLES IT BY ELIMINATION, which is
            -- the sharper half of this release: that door carries no URL
            -- and fetches nothing, so it CANNOT be refused for read
            -- access. If the film still will not play once the bytes are
            -- inside the window, there is no reading explanation left —
            -- WebKit cannot decode it, and no further door can ever help.
            if (tonumber(vid.loadRuns) or 0) > 0
               and (tonumber(vid.blobPlayed) or 0) == 0 then
                L[#L + 1] = "   ↳ THE BYTES WERE INSIDE THE WINDOW AND IT "
                            .. "STILL WOULD NOT PLAY, so this is not about "
                            .. "reading the disk: WebKit cannot DECODE this "
                            .. "film.  HEVC, x265, AC3 or DTS is the usual "
                            .. "answer, and no way in will ever fix it."
            else
                L[#L + 1] = "   ↳ H.264/AAC and no door works = this window "
                            .. "cannot READ the file.  HEVC, x265, AC3, DTS or "
                            .. "nothing at all = WebKit cannot DECODE it, and "
                            .. "no way in will ever fix that."
            end
        end
        local failed = {}
        for k, n in pairs(vid.doorFailed) do failed[#failed + 1] = k .. " ×" .. n end
        table.sort(failed)
        if #failed > 0 then
            L[#L + 1] = "   refused: " .. table.concat(failed, " · ")
            if vid.mediaWhy then
                L[#L + 1] = "   ↳ macOS said: " .. tostring(vid.mediaWhy)
            end
        end
        -- 📦 THE BYTES DOOR, COUNTED APART FROM THE URLs (6.229.0): a
        -- film the loader READ is a different fact from one it played,
        -- and the turns it cost are printed beside what they bought.
        -- 🔎 AND A READ IN FLIGHT IS ITS OWN STATE: "nothing has been
        -- read" and "a film is being read right now" must not print the
        -- same words (6.196.1), because the second is what he is looking
        -- at while the stage says a percentage.
        -- 📏 THE CEILING, AND WHERE THE NUMBER CAME FROM (6.355.0). It
        -- is printed whether or not a film was refused, because the one
        -- time it matters is the moment a film is too big and he wants
        -- to know whether that was his Mac or my arithmetic.
        do
            local cap = vid.maxBytes()
            L[#L + 1] = "   ceiling: " .. vid.mb(cap) .. " — "
                        .. tostring(vid.ceilWhy)
        end
        do
            local runs = tonumber(vid.loadRuns) or 0
            if runs == 0 and not vid.load then
                L[#L + 1] = "   bytes  : the loader has not been asked for a"
                            .. " film yet"
            else
                L[#L + 1] = "   bytes  : " .. runs .. " film(s) read into the"
                            .. " window · " .. (tonumber(vid.blobPlayed) or 0)
                            .. " played · " .. (tonumber(vid.blobFailed) or 0)
                            .. " refused"
                if (tonumber(vid.loadTurns) or 0) > 0 then
                    L[#L + 1] = string.format(
                        "   ↳ turns : %d turn(s) carrying %s · worst %d ms",
                        vid.loadTurns, vid.mb(vid.loadBytes),
                        math.floor(tonumber(vid.loadWorst) or 0))
                end
                if (tonumber(vid.loadSlow) or 0) > 0 then
                    L[#L + 1] = "   ↳ ⚠️ " .. vid.loadSlow .. " read(s) crossed "
                                .. tostring(vid.slowTurnMs) .. " ms a turn on"
                                .. " the main thread"
                end
                -- 🔎 THE PACING, COUNTED: a chunk the window CONFIRMED is
                -- a different fact from one that was merely accepted
                -- (6.299.0), and a belt that fired is the window having
                -- stopped taking the film.
                L[#L + 1] = "   ↳ pace  : " .. (tonumber(vid.acks) or 0)
                            .. " piece(s) the window confirmed"
                            .. ((tonumber(vid.ackLate) or 0) > 0
                                and (" · ⚠️ " .. vid.ackLate
                                     .. " never answered in "
                                     .. tostring(vid.ackSecs) .. " s")
                                or "")
                if (tonumber(vid.ackNoBelt) or 0) > 0 then
                    L[#L + 1] = "   ↳ ⚠️ " .. vid.ackNoBelt .. " piece(s) went"
                                .. " out with NO belt — this Mac would not"
                                .. " arm one, so a silent window would hang"
                                .. " the read"
                end
            end
            if vid.load then
                L[#L + 1] = "   ↳ now   : reading " .. vid.titleOf(vid.load.path)
                            .. " — " .. vid.mb(vid.load.sent) .. " of "
                            .. vid.mb(vid.load.size) .. " in " .. vid.load.turns
                            .. " turn(s) so far"
            else
                L[#L + 1] = "   ↳ last  : " .. tostring(vid.loadWhy)
            end
            if (tonumber(vid.loadMs) or 0) > 0 then
                L[#L + 1] = string.format(
                    "   ↳ clock : the last whole read took %.1f s",
                    (tonumber(vid.loadMs) or 0) / 1000)
            end
            if not vid.blobLoad then
                L[#L + 1] = "   ↳ OFF   : settings = { video_player ="
                            .. " { blobLoad = true } } puts the bytes door back"
            end
        end
        L[#L + 1] = "   store  : " .. vid.storeVerdict(vid.storeState, vid.storeBytes,
                                                       #vid.queue, #vid.history)
        L[#L + 1] = "   ↳ " .. vid.storeFile .. "  (LOCAL — never OneDrive)"
        -- 🔎 IT ASKS THE OBJECT, NEVER A STRING IT WROTE EARLIER
        -- (6.308.0). `dropWhy` was set to "ready" when the catcher was
        -- created and nothing cleared it, so this line read as health
        -- about a catcher that had been deleted — which is what made a
        -- report taken after closing the window unreadable.
        local dropState
        if vid.catcher and vid.catcherOn then
            dropState = "catcher up"
        elseif vid.webview then
            dropState = "⚠️ NO catcher under an OPEN window — "
                        .. tostring(vid.dropWhy)
        else
            dropState = "window closed · last: " .. tostring(vid.dropWhy)
        end
        L[#L + 1] = "   drop   : " .. dropState
                    .. " · the window's own handler: "
                    .. (vid.pageDoorLive() and "live" or "⚠️ STOOD DOWN")
                    .. " · " .. tostring(vid.dragSeen)
                    .. (vid.dropReader and (" · read by " .. vid.dropReader) or "")
        -- 🚪 THE TWO DOORS, COUNTED APART. A feature with one door that
        -- macOS can refuse is what this release exists to end, and the
        -- only way to know which one is carrying it is to count them
        -- separately (6.229.0's rule about what a number BUYS).
        L[#L + 1] = "   ↳ doors : " .. vid.pageDrops
                    .. " drop(s) through the window itself · "
                    .. vid.catchDrops .. " through the catcher underneath"
                    .. (vid.catchRefused > 0
                        and ("  ⚠️ macOS refused the catcher "
                             .. vid.catchRefused .. " time(s)") or "")
        if vid.uriWhy then
            L[#L + 1] = "   ↳ " .. tostring(vid.uriWhy)
        end
        if #vid.refused > 0 then
            L[#L + 1] = "   not played:"
            for i = 1, math.min(#vid.refused, 5) do
                L[#L + 1] = "      " .. vid.titleOf(vid.refused[i].path)
                            .. " — " .. vid.refused[i].why
            end
        end
        -- 🔎 FOUR STATES, AND THE FOURTH IS THE ONE THAT WAS MISSING
        -- (6.196.1). hide() resets pageReady, so a report taken after
        -- closing the window printed the same ⚠️ whether the page had run
        -- perfectly or had never once spoken — and those are opposite
        -- facts about the window he is telling me is empty.
        local pageState
        if vid.pageReady then
            pageState = "ready"
        elseif vid.webview then
            pageState = "⚠️ OPEN and has NOT said it is ready — its script "
                        .. "did not reach its last line"
        elseif vid.pageSpoke then
            pageState = "window closed · it HAD said it was ready while open"
        else
            pageState = "⚠️ window closed, and it has NEVER once said it is "
                        .. "ready this session"
        end
        L[#L + 1] = "   page   : " .. pageState .. " · " .. vid.draws.landed
                    .. " draw(s) landed · " .. vid.draws.early .. " pushed early"
        L[#L + 1] = "   keyboard: " .. tostring((vid.focus or {}).why or "not asked")
        L[#L + 1] = "   ⏯ keys : NOT taken here, deliberately — the Jug Player"
                    .. " holds F7/F8/F9 while its card is up, and two tools on"
        L[#L + 1] = "            one physical key is how they come to disagree."
                    .. "  With the film focused macOS routes them to it anyway."
        L[#L + 1] = "   played : " .. vid.plays .. " this session · "
                    .. vid.externals .. " opened in a real player"
        -- 🚪 COUNTED APART (6.229.0): a film HE sent out with ⌘O and one
        -- this tool sent out because every way in was refused are
        -- different facts, and a sum of them says nothing about whether
        -- the window can play anything at all.
        L[#L + 1] = "   exits  : " .. vid.handedOff .. " handed out because"
                    .. " no way in worked · " .. vid.byHand
                    .. " you opened yourself"
                    .. (vid.handOff and "" or
                        "  ⚠️ the hand-off is OFF (settings)")
        do
            local t, pw = vid.exitPick(vid.index, vid.queue, vid.selList, vid.sel)
            L[#L + 1] = "   ↳ ⌘O would open: "
                        .. (t and ((t.title or t.path) .. " — " .. pw) or pw)
        end
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
    -- 🪟 PAY THE DYLIB LOADS HERE, NOT ON HIS KEYPRESS. Hammerspoon
    -- loads an extension the first time anything touches it, on the
    -- MAIN THREAD, and on his Mac that is seconds rather than
    -- milliseconds — his 6.330.0 boot log has `mouse` arriving
    -- twenty-six seconds after `notify`. So the first ⇪⇧, of a session
    -- was loading hs.webview (to make the bridge) AND hs.drawing (to
    -- set the window level) and THEN asking AppKit to order a window on
    -- screen, all in one turn; his 20:45:51 Console carries all three
    -- lines in the same second, the third being the refusal.
    -- 🚨 NAMED AS A CANDIDATE, NOT A CAUSE (6.198.0): this does not
    -- prove why macOS said no. What it does is take two known pieces of
    -- main-thread work out of the moment of the show — 6.267.0's move
    -- applied to Hammerspoon's own library loading, which 6.330.0 wrote
    -- down and nothing had yet paid.
    -- 📏 COST, NAMED: a Mac that never presses ⇪⇧, now loads these two
    -- extensions anyway, seconds after boot, in warm's own pcall. They
    -- are two of the commonest extensions in this config — six other
    -- modules draw webviews — so on an ordinary day this moves the cost
    -- rather than adding it.
    vid.warmed = pcall(function()
        local _ = hs.webview and hs.webview.usercontent
        local _ = hs.drawing and hs.drawing.windowLevels
        -- 📦 AND hs.base64 FOR THE SAME REASON (6.354.0): the bytes door
        -- touches it for the first time in the middle of a read, which
        -- is the one moment that must be cheap.
        local _ = hs.base64 and hs.base64.encode
        return true
    end) and true or false
end

return M
