-- =====================================================================
-- MODULE: DRAFT KEEPER (@draft) — the text a web form loses
-- =====================================================================
-- LL, 2026-09-13, with a drawing: "a translucent floppy-disc beside a
-- text field in Chrome/Safari that has no save, watching the typing."
-- Scoped by him on 2026-10-09: "browser fields AND Microsoft Outlook
-- fields · ⏎ on a row COPIES it · stored as a .csv in the Logs folder ·
-- @draft is the ⇪D source", and "ONLY 90 DAYS". Escalated by name on
-- 2026-10-10 ("Escalate draft keeper.") and again on 2026-11-04
-- ("❗❗ Escalate and build ❗❗ … its own release ASAP").
--
--        (nothing to press)   it watches while you type in a browser
--        ⇪D  @draft           every draft it kept, newest first
--        ⏎                    COPIES the draft. It never types it back.
--        _G.draftKeeperReport()
--
-- ---- 🔑 IT READS THE FIELD, IT DOES NOT WATCH THE KEYBOARD ----------
-- The obvious build is an hs.eventtap that accumulates keystrokes, the
-- way modules/autocorrect.lua does, and it is wrong here for a reason
-- that has nothing to do with cost: A KEYSTROKE TAP RECONSTRUCTS, IT
-- DOES NOT READ. It never sees a paste, and after he moves the caret
-- and rewrites a sentence what it holds is a mangled transcript of the
-- typing rather than the paragraph on screen. The thing he wants back
-- is THE FIELD'S VALUE, so the field is what is asked.
--
-- 🔑 GENERAL, and it is the half to carry: when a feature's subject is
-- the STATE of something, ask the thing; a stream of the EVENTS that
-- built that state is a different object that merely usually agrees.
--
-- And it is the narrower instrument of the two, which matters here more
-- than anywhere else in this config: a keystroke tap sees every
-- character typed anywhere on the Mac, and this reads one element in
-- seven named apps.
--
-- ---- 📏 WHAT ONE SAMPLE COSTS, AND THE ORDER THAT MAKES IT CHEAP ----
-- An Accessibility read is MAIN-THREAD work, and a busy main thread is
-- a mouse this Mac has lost (6.228.0). So the watch list is asked
-- FIRST, off `hs.application.frontmostApplication():name()` — a string
-- compare — and a Mac in Terminal, Finder, Word or Xcode pays exactly
-- that and nothing else. Only a watched app reaches the AX read at all.
--
-- Every read is TIMED. Past `dk.slowMs` it takes the 🔔 door ONCE and
-- BACKS OFF — the interval doubles up to `dk.sampleMaxSecs` — rather
-- than going on costing him the thread it is slow on. 6.229.0's rule:
-- when a cost is paid per wake-up, count the wake-ups and print what
-- they bought beside what they cost.
--
-- ---- 🔒 WHAT IT REFUSES, AND IT FAILS CLOSED ------------------------
-- · `AXSecureTextField` — a password field. Refused by name, counted.
-- · A role it could not READ AT ALL. "I cannot tell what this is" and
--   "this is safe to read" are opposite facts (6.196.1), and the second
--   is the one that costs him a password in a CSV, so an unreadable
--   role refuses. 6.200.0's rule in the place where it earns its keep.
-- · Secure Input held by any app — read from core/capabilities.lua,
--   never re-probed (6.242.0). While something has locked the keyboard
--   system-wide, this stands down entirely.
-- · `_G.hsPaused` — the pause switch (⇪⇧Esc). Everything that watches
--   anything in this config stands down on it (6.152.0).
--
-- 📏 THE COST IT CANNOT SEE, named rather than discovered: a site that
-- puts a password in a PLAIN text field — a "show password" toggle — is
-- a field macOS calls ordinary, and nothing here can know better. That
-- is the one case where a draft row could hold something he would not
-- want kept, and `_G.draftForget(n)` is the way out.
--
-- ---- 🕰 WHEN IT WRITES: WHEN THE DRAFT HAS SETTLED ------------------
-- A row per sample would make the CSV a transcript of his typing. A row
-- per FINISHED thought is what is useful, so a draft is written when it
-- has stopped changing for `dk.settleSecs` — 6.387.0's rule, which was
-- about minting a file name and is just as true of a log: ask whether
-- the thing is FINISHED, not whether you may write yet.
--
-- 🚪 AND THE CASE THE WHOLE FEATURE EXISTS FOR IS THE FLUSH. When the
-- next sample finds a DIFFERENT field — he tabbed away, the page
-- navigated, the form went — whatever was pending is written at once.
-- That is the moment a web form loses a draft, and a settle timer alone
-- would miss it.
--
-- 📏 COST, NAMED AND REAL: up to `dk.settleSecs` of the newest typing
-- is not on disk at any instant, so a crash or a reload inside that
-- window loses it. Making that zero means a write per keystroke into a
-- cloud folder, which is 6.229.0's bill.
--
-- ---- ✂️ dk.keepVerdict — PURE, and the shrink is the interesting half
-- · under `minChars`            → no. A search box is not a draft.
-- · the first row for a field   → yes.
-- · unchanged                   → no.
-- · SHORTER than the row already saved → NO, and this is an economy
--   rather than an oversight: the longer row is already on disk and
--   still holds every word of it, so a shrink needs no row to protect
--   him. Writing on one would fill the file as he edits. 6.281.0's
--   "the rename is the memory", one tool along — the LONGER ROW IS THE
--   MEMORY, and the store this feature needs is the one it already has.
-- · EDITED rather than merely added to (the saved row is no longer a
--   prefix of it) → yes, whatever the length. A 500-character draft
--   rewritten into a different 500 characters is new writing, and a
--   rule that compared only LENGTHS would call it unchanged. The
--   fixture that bites is exactly that pair (6.230.0).
-- · grew by at least `minGrowth` → yes.
-- · otherwise                   → no, and the report says by how little.
--
-- ---- 🧵 A ROW IS ONE LINE, OR A TAIL READ CANNOT FIND A ROW ---------
-- A draft has newlines in it — it is an email — and `core.csvQuote`
-- turns every one of them into a space, deliberately, because every
-- other store in this config holds single-line values. So the text is
-- ENCODED first (`\` → `\\`, newline → `\n`, tab → `\t`) and decoded on
-- read: one row is one line, which is what lets the reader seek to the
-- END of the file and read a bounded tail instead of a file that grows
-- for ninety days. `dk.encode`/`dk.decode` are PURE and round-trip.
--
-- ---- 🕘 NINETY DAYS, HIS NUMBER ------------------------------------
-- Append-only, because an append cannot shrink a file (6.279.0), and
-- pruned ONCE per session from `M.warm` — temp file then rename
-- (6.313.0), so the store is the old one or the new one and never half.
-- `dk.pruneRows` is PURE with the clock as an argument.
--
-- ---- 🗳 THE DEFAULT I CHOSE, AND WHY IT IS NOT "EVERYTHING" --------
-- 6.213.x's note asked whether it keeps EVERY draft or only ones over
-- some length after some pause, and said the first makes the file a log
-- of every search box he has ever typed in. He escalated the feature
-- without answering, and 6.267.0 forbids leaving the answer in a
-- settings line for him to type: so the default is the SECOND —
-- 60 characters, settled for 10 seconds — and both numbers are in the
-- report where he can read them and say they are wrong.
--
-- ---- 📏 WHERE IT IS STORED, AND THE COST OF THAT ------------------
-- The Logs folder, by his own scope, which on a healthy Mac is inside
-- OneDrive — so these rows SYNC. That is right for a draft (a thing you
-- want back) and it is worth saying out loud, because the file holds
-- text he typed into other people's forms. `settings = { draft_keeper =
-- { local_ = true } }` puts it under ~/Library/Application Support
-- instead, and the report names which folder it is using.
--
-- ---- 🚫 WHAT IS NOT BUILT, said rather than left to be found -------
-- THE FLOPPY DISC. His first drawing had a translucent disc beside the
-- field. It needs the element's own rectangle, re-read and redrawn as
-- he types and as the page scrolls — per-event main-thread work, which
-- is 6.228.0's bill on the thread that carries his keyboard, and
-- 6.247.0 priced a redraw on a path that runs per event. The report and
-- @draft are the surfaces instead, plus ONE Console line the first time
-- a draft is kept in a session so it is visibly alive. If he wants the
-- disc it is its own release and it starts with a measurement.
-- =====================================================================

local M = {
    name  = "Draft Keeper",
    -- 13.33 sits between Quick Append (13.3) and the Capture Pad's
    -- neighbours (13.34), beside the other tools that catch text he
    -- would otherwise lose. A TIE makes the cheat sheet's running order
    -- depend on table iteration, which is not stable, and
    -- test_integration fails the gate for one.
    order = 13.33,
    family = "capture",
    cheatsheet = {
        title = "💾 DRAFT KEEPER (the text a web form loses)",
        entries = {
            { "@draft",      "Every draft it kept, newest first — type it in ⇪D" },
            { "⏎",           "COPIES the draft. It never types it back into a page" },
            { "watches",     "Chrome · Safari · Edge · Firefox · Brave · Arc · Outlook" },
            { "keeps",       "A field's own text, once it has settled — not your keystrokes" },
            { "refuses",     "A password field · a field macOS will not describe ·" },
            { "",            "anything while Secure Input is held · while ⇪⇧Esc has paused" },
            { "90 days",     "Pruned once a session; nothing else ever removes a row" },
            { "forget",      "_G.draftForget(n) removes one · _G.draftForgetAll()" },
            { "report",      "_G.draftKeeperReport() — what it kept and what it refused" },
            { "is it on?",    "_G.draftCheck() — click into a box and run it: it says what" },
            { "",             "it can see in that field right now, and what would happen" },
        },
    },
}

function M.setup(core)
    local dk = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    dk.enabled      = true
    dk.minChars     = 60      -- shorter than this is a search box, not a draft
    dk.minGrowth    = 40      -- characters of growth before a second row
    dk.settleSecs   = 10      -- quiet before a draft counts as finished
    dk.sampleSecs   = 5       -- between reads, while a watched app is in front
    dk.sampleMaxSecs = 60     -- the slowest it backs off to
    dk.slowMs       = 60      -- a read past this takes the door and backs off
    dk.axTimeout    = 0.20    -- seconds a single AX question may take
    dk.maxChars     = 8000    -- characters of a draft kept in a row
    dk.days         = 90      -- his number
    dk.tailBytes    = 256 * 1024   -- read back from the end of the file
    dk.maxRows      = 400     -- rows a reader hands back
    dk.local_       = false   -- true: keep the CSV out of OneDrive
    dk.apps = {               -- matched as WHOLE WORDS of the app's name
        "chrome", "chromium", "safari", "edge", "firefox", "brave",
        "arc", "vivaldi", "opera", "outlook",
    }
    -- 🪟 6.411.0 — ask a Chromium app to build its accessibility tree.
    -- In order; the first one accepted is the one recorded. Setting
    -- askTree = false leaves every app exactly as it was before this
    -- release, which is the way back if it ever costs anything.
    dk.askTree      = true
    dk.treeAttrs    = { "AXManualAccessibility", "AXEnhancedUserInterface" }
    dk.roles = {              -- the only roles a draft is read from
        AXTextArea  = true,
        AXTextField = true,
        AXComboBox  = false,  -- a chooser with a text field in it; its own value is the SELECTION
    }
    -- ----------------------------------------------------------------------

    -- ---- state ----------------------------------------------------------
    dk.asked      = {}    -- app name -> { how, at, ok } (6.411.0, per session)
    dk.woke       = 0     -- apps that accepted one of the attributes
    dk.wokeRefused = 0    -- apps that accepted neither
    dk.pending    = nil   -- { key, app, title, role, text, changedAt, wrote }
    dk.samples    = 0
    dk.reads      = 0     -- samples that reached the AX read
    dk.kept       = 0
    dk.failedWrites = 0
    dk.lastKeptAt = nil
    dk.lastKept   = nil
    dk.lastWhy    = nil
    dk.slow       = 0
    dk.worstMs    = 0
    dk.lastMs     = nil
    dk.saidSlow   = false
    dk.saidAlive  = false
    dk.everySecs  = nil   -- the interval in force; nil until warm arms it
    dk.timer      = nil   -- HELD (6.196.1)
    dk.refused    = { secure = 0, role = 0, secureInput = 0, paused = 0 }
    dk.skipped    = { app = 0, nothing = 0, notText = 0 }
    dk.lastRefusal = nil
    dk.pruned     = nil   -- nil: not pruned yet this session
    dk.pruneWhy   = nil
    dk.wrote      = 0

    -- ---- where the file lives -------------------------------------------
    function dk.dir()
        if dk.local_ then
            return (os.getenv("HOME") or "")
                   .. "/Library/Application Support/Hammerspoon/drafts"
        end
        return core.logsDir or ""
    end

    function dk.path()
        return dk.dir() .. "/draft_keeper-" .. tostring(core.hostTag or "mac") .. ".csv"
    end

    -- ---- PURE: is this an app we watch? --------------------------------
    -- 🚨 WHOLE WORDS, never a substring. "Archive Utility" contains "arc"
    -- and is not a browser; "Arc" is. The fixture that bites is that
    -- pair, because every other input agrees (6.230.0).
    function dk.appWatched(name, list)
        if type(name) ~= "string" or name == "" then return false end
        list = list or dk.apps
        local want = {}
        for _, w in ipairs(list) do want[tostring(w):lower()] = true end
        for word in name:lower():gmatch("[%a]+") do
            if want[word] then return true, word end
        end
        return false
    end


    -- ---- 🪟 6.411.0 — A CHROMIUM APP DOES NOT PUBLISH ITS PAGE ---------
    -- LL: "Draft keeper doesn't seem to be working. How do I know?"
    --
    -- 🔎 SIX OF THE SEVEN WATCHED APPS ARE CHROMIUM, and Chromium builds
    -- its accessibility tree ONLY when something asks for it. Until it
    -- is asked, `AXFocusedUIElement` answers about the window chrome and
    -- the textarea inside the page is not in the tree at all — so the
    -- one module whose whole job is reading that textarea read nothing,
    -- in exactly the apps it was written for, and said "nothing is
    -- focused" about a field he was typing into.
    --
    -- 🚨 NEW GROUND, SAID RATHER THAN ASSUMED. Whether a given build of
    -- Chrome, Edge, Brave, Arc, Vivaldi or Opera honours either attribute
    -- is a fact about HIS Mac that this container cannot read in any
    -- source (6.233.0). So this ASKS and RECORDS: per app, per session,
    -- which attribute was accepted and whether a field became readable
    -- afterwards. A refusal costs one attribute write and is named.
    --
    -- 🔒 ASKED ONCE PER APP PER SESSION, and only for an app already on
    -- the watch list — so nothing is asked of Word, Terminal or Finder,
    -- and the narrow reach 6.404.0 chose is unchanged.
    -- PURE given the setter: the gate drives an app that accepts the
    -- first attribute, one that accepts only the second, and one that
    -- accepts neither (6.230.0 — the fixture where they must differ).
    function dk.wakeVerdict(appName, setter, attrs, seen)
        if type(appName) ~= "string" or appName == "" then
            return "no-app", "no application to ask"
        end
        seen = seen or dk.asked
        local had = seen[appName]
        if had then return "already", had.how end
        attrs = attrs or dk.treeAttrs
        for _, a in ipairs(attrs) do
            local ok, answered = pcall(setter, a)
            if ok and answered ~= false then
                seen[appName] = { how = a, at = os.time(), ok = true }
                return "asked", a
            end
        end
        seen[appName] = { how = nil, at = os.time(), ok = false }
        return "refused", "neither " .. table.concat(attrs, " nor ")
                          .. " was accepted"
    end

    -- ---- PURE: may this field be read at all? --------------------------
    -- FIVE answers, and the two refusals that are not about the field
    -- are counted apart from the ones that are: "a password field" and
    -- "something has locked the whole keyboard" send me to different
    -- places (6.196.1).
    function dk.fieldVerdict(role, secureHeld, paused)
        if paused then return "paused", "⇪⇧Esc has paused this config" end
        if secureHeld then
            return "secure-input", "Secure Input is held — nothing is read while it is"
        end
        if role == "AXSecureTextField" then
            return "secure", "a password field — never read, never stored"
        end
        if type(role) ~= "string" or role == "" then
            return "unknown", "macOS would not say what this field is — refused,"
                              .. " because 'I cannot tell' must not read as 'safe'"
        end
        if not dk.roles[role] then
            return "not-text", "a " .. role .. " — not a text field"
        end
        return "watch", "a " .. role
    end

    -- ---- PURE: should this settled text become a row? ------------------
    function dk.keepVerdict(text, last, minChars, minGrowth)
        minChars  = tonumber(minChars)  or dk.minChars
        minGrowth = tonumber(minGrowth) or dk.minGrowth
        local n = dk.len(text)
        if n < minChars then
            return false, "under " .. minChars .. " characters — too short to be a draft"
        end
        if last == nil then return true, "the first draft of this field" end
        if text == last then return false, "unchanged since the last row" end
        local ln = dk.len(last)
        if n < ln then
            return false, "shorter than the row already saved — that row still holds it"
        end
        -- 🚨 EDITED, NOT MERELY ADDED TO. A same-length rewrite is new
        -- writing and a length-only rule calls it nothing.
        if last ~= "" and text:sub(1, #last) ~= last then
            return true, "edited, not just added to"
        end
        if n >= ln + minGrowth then
            return true, "grew by " .. (n - ln) .. " character(s)"
        end
        return false, "only " .. (n - ln) .. " more character(s) since the last row"
    end

    -- ---- PURE: characters, never bytes (6.226.0) ----------------------
    function dk.len(s)
        if type(s) ~= "string" then return 0 end
        local ok, n = pcall(function() return utf8.len(s) end)
        if ok and type(n) == "number" then return n end
        return #s                     -- not valid UTF-8; bytes is the floor
    end

    -- ---- PURE: cut to N characters, never mid-glyph -------------------
    function dk.clip(s, maxChars)
        s = tostring(s or "")
        maxChars = tonumber(maxChars) or dk.maxChars
        local n = dk.len(s)
        if n <= maxChars then return s, n, false end
        local okO, off = pcall(function() return utf8.offset(s, maxChars + 1) end)
        if okO and type(off) == "number" and off > 1 then
            return s:sub(1, off - 1), n, true
        end
        return s:sub(1, maxChars), n, true
    end

    -- ---- PURE: one row is one line -----------------------------------
    function dk.encode(s)
        s = tostring(s or "")
        s = s:gsub("\\", "\\\\")
        s = s:gsub("\r\n", "\\n"):gsub("\n", "\\n"):gsub("\r", "\\n")
        s = s:gsub("\t", "\\t")
        return s
    end

    function dk.decode(s)
        s = tostring(s or "")
        return (s:gsub("\\(.)", function(c)
            if c == "n" then return "\n" end
            if c == "t" then return "\t" end
            if c == "\\" then return "\\" end
            return "\\" .. c          -- an escape nobody wrote: keep it literal
        end))
    end

    -- ---- PURE: the field's identity -----------------------------------
    -- app ‖ window title ‖ role. The role is what separates a subject
    -- line (AXTextField) from a body (AXTextArea) in one Outlook window.
    -- Two text AREAS in one window do share a slot; the cost of that is
    -- one extra row, never a lost draft.
    function dk.fieldKey(app, title, role)
        return table.concat({ tostring(app or "?"), tostring(title or ""),
                              tostring(role or "?") }, "\0")
    end

    -- ---- PURE: one CSV row, and the one reader for it -----------------
    function dk.csvRow(r)
        local q = core.csvQuote
        local at = tonumber(r.at) or os.time()
        return table.concat({
            q(os.date("%Y-%m-%d", at)), q(os.date("%H:%M:%S", at)), tostring(at),
            q(r.app), q(r.title), q(r.role),
            tostring(tonumber(r.chars) or 0), tostring(r.cut and 1 or 0),
            q(dk.encode(r.text)),
        }, ",")
    end

    function dk.parseRow(line)
        if type(line) ~= "string" or line == "" then return nil end
        local f = core.splitCSVLine(line)
        if type(f) ~= "table" or #f < 9 then return nil end
        local at = tonumber(f[3])
        if not at then return nil end          -- a half-row from a tail read
        return { date = f[1], clock = f[2], at = at,
                 app = f[4], title = f[5], role = f[6],
                 chars = tonumber(f[7]) or 0, cut = (f[8] == "1"),
                 text = dk.decode(f[9]) }
    end

    -- ---- PURE: the ninety days ---------------------------------------
    function dk.pruneRows(rows, now, days)
        now  = tonumber(now)  or os.time()
        days = tonumber(days) or dk.days
        local keep, dropped = {}, 0
        local floor = now - (days * 86400)
        for _, r in ipairs(rows or {}) do
            if (tonumber(r.at) or 0) >= floor then keep[#keep + 1] = r
            else dropped = dropped + 1 end
        end
        return keep, dropped
    end

    -- ---- the file: append ---------------------------------------------
    local function ensureDir()
        local d = dk.dir()
        if d == "" then return false, "no folder to write to" end
        local okA = hs.fs.attributes(d, "mode")
        if okA == "directory" then return true end
        local okM = pcall(function() hs.fs.mkdir(d) end)
        if hs.fs.attributes(d, "mode") == "directory" then return true end
        return false, "could not make " .. d .. (okM and "" or " (mkdir refused)")
    end

    function dk.append(r)
        local okD, whyD = ensureDir()
        if not okD then
            dk.failedWrites = dk.failedWrites + 1
            dk.lastWhy = whyD
            return false, whyD
        end
        local f, err = io.open(dk.path(), "a")
        if not f then
            dk.failedWrites = dk.failedWrites + 1
            dk.lastWhy = tostring(err or "could not open the file")
            return false, dk.lastWhy
        end
        -- 🔒 io.write's return is READ (6.325.0): a refused write that
        -- reports success is a draft he believes is kept.
        local wrote, werr = f:write(dk.csvRow(r) .. "\n")
        pcall(function() f:close() end)
        if not wrote then
            dk.failedWrites = dk.failedWrites + 1
            dk.lastWhy = "the write was refused — " .. tostring(werr)
            return false, dk.lastWhy
        end
        dk.wrote = dk.wrote + 1
        return true
    end

    -- ---- the file: read a bounded tail --------------------------------
    -- 🔎 IT ANSWERS rows, err — never a bare empty list. "nothing has
    -- been kept" and "the file could not be read" are opposite facts
    -- and a reader that cannot tell them apart prints the reassuring
    -- one (6.196.1).
    function dk.rows(opts)
        opts = type(opts) == "table" and opts or {}
        local max = tonumber(opts.max) or dk.maxRows
        local p = dk.path()
        if hs.fs.attributes(p, "mode") ~= "file" then
            return nil, "no draft file yet — nothing has been kept on this Mac"
        end
        local f = io.open(p, "r")
        if not f then return nil, "the draft file is there and could not be read" end
        local okR, text = pcall(function()
            local size = f:seek("end")
            f:seek("set", math.max(0, size - (tonumber(opts.tail) or dk.tailBytes)))
            return f:read("a") or ""
        end)
        pcall(function() f:close() end)
        if not okR then return nil, "the draft file could not be read" end
        local rows = {}
        for line in tostring(text or ""):gmatch("[^\n]+") do
            local r = dk.parseRow(line)
            if r then rows[#rows + 1] = r end
        end
        -- newest first; the tail is in write order, so reverse rather
        -- than sort — equal seconds must keep the order they happened in
        local out, n = {}, #rows
        for i = n, math.max(1, n - max + 1), -1 do out[#out + 1] = rows[i] end
        return out
    end

    -- ---- the file: rewrite (prune, forget) ---------------------------
    -- 🔒 TEMP THEN RENAME (6.313.0). `io.open(p, "w")` truncates before
    -- it writes a byte, so a crash in that window leaves the file at
    -- zero bytes — and zero bytes reads as "nothing kept", in silence,
    -- after which the next append makes it permanent.
    function dk.rewrite(rows)
        local okD, whyD = ensureDir()
        if not okD then return false, whyD end
        local p   = dk.path()
        local tmp = p .. ".tmp"
        local f, err = io.open(tmp, "w")
        if not f then return false, tostring(err or "could not open the temp file") end
        local okW = true
        for _, r in ipairs(rows or {}) do
            local wrote = f:write(dk.csvRow(r) .. "\n")
            if not wrote then okW = false ; break end
        end
        pcall(function() f:close() end)
        if not okW then
            pcall(function() os.remove(tmp) end)
            return false, "the rewrite was refused — the old file is untouched"
        end
        local okR, rerr = os.rename(tmp, p)
        if not okR then
            pcall(function() os.remove(tmp) end)
            return false, "the rename was refused (" .. tostring(rerr)
                          .. ") — the old file is untouched"
        end
        if _G.rewrittenFiles then _G.rewrittenFiles[p] = os.time() end
        return true
    end

    -- ---- the prune, once per session ---------------------------------
    function dk.prune()
        local p = dk.path()
        if hs.fs.attributes(p, "mode") ~= "file" then
            dk.pruned, dk.pruneWhy = 0, "no file yet"
            return 0
        end
        local f = io.open(p, "r")
        if not f then
            dk.pruneWhy = "the file could not be read, so nothing was pruned"
            return nil, dk.pruneWhy
        end
        local okR, text = pcall(function() return f:read("a") or "" end)
        pcall(function() f:close() end)
        if not okR then
            dk.pruneWhy = "the file could not be read, so nothing was pruned"
            return nil, dk.pruneWhy
        end
        local all = {}
        for line in tostring(text):gmatch("[^\n]+") do
            local r = dk.parseRow(line)
            if r then all[#all + 1] = r end
        end
        local keep, dropped = dk.pruneRows(all, os.time(), dk.days)
        if dropped == 0 then
            dk.pruned, dk.pruneWhy = 0, nil
            return 0
        end
        local okW, whyW = dk.rewrite(keep)
        if not okW then
            dk.pruneWhy = whyW
            return nil, whyW
        end
        dk.pruned, dk.pruneWhy = dropped, nil
        return dropped
    end

    -- ---- the AX read, timed ------------------------------------------
    local function nowMs() return hs.timer.secondsSinceEpoch() * 1000 end

    function dk.readFocused()
        local out = { app = nil, role = nil, title = nil, value = nil, why = nil }
        if type(hs.axuielement) ~= "table" then
            out.why = "hs.axuielement is not available in this Hammerspoon"
            return out
        end
        local app
        pcall(function() app = hs.application.frontmostApplication() end)
        if not app then out.why = "no front application" ; return out end
        pcall(function() out.app = app:name() end)
        -- 🔑 THE WATCH LIST IS ASKED BEFORE ANY AX WORK. This is the line
        -- that makes the feature free on the apps he spends his day in.
        if not dk.appWatched(out.app) then
            out.why = "not a watched app"
            out.unwatched = true
            return out
        end
        local okAx, axApp = pcall(hs.axuielement.applicationElement, app)
        if not (okAx and axApp) then
            out.why = "no AX element for " .. tostring(out.app) ; return out
        end
        pcall(function() axApp:setTimeout(dk.axTimeout) end)
        -- 🪟 6.411.0 — BEFORE the focused element is asked for, because a
        -- Chromium app has no page in its tree until it has been asked.
        -- Once per app per session; the answer rides into the report.
        if dk.askTree then
            local kind, how = dk.wakeVerdict(out.app, function(attr)
                local ok, answered = pcall(function()
                    return axApp:setAttributeValue(attr, true)
                end)
                return ok and answered
            end)
            if kind == "asked" then
                dk.woke = dk.woke + 1
                -- 🔕 Console only, and once per app: this happens the
                -- first time he clicks into a browser every morning, and
                -- a line on screen for it is one he stops reading
                -- (6.269.0). The report carries it after that.
                pcall(function()
                    if _G.diag and _G.diag.say then
                        _G.diag.say("draftKeeper",
                            ("asked %s for its accessibility tree (%s)")
                            :format(tostring(out.app), tostring(how)))
                    end
                end)
            elseif kind == "refused" then
                dk.wokeRefused = dk.wokeRefused + 1
            end
        end
        local el
        pcall(function() el = axApp:attributeValue("AXFocusedUIElement") end)
        if not el then out.why = "nothing is focused" ; return out end
        pcall(function() el:setTimeout(dk.axTimeout) end)
        pcall(function() out.role = el:attributeValue("AXRole") end)
        pcall(function() out.value = el:attributeValue("AXValue") end)
        pcall(function()
            local win = axApp:attributeValue("AXFocusedWindow")
            if win then
                win:setTimeout(dk.axTimeout)
                out.title = win:attributeValue("AXTitle")
            end
        end)
        return out
    end

    -- ---- flush: write whatever is pending ----------------------------
    function dk.flush(why)
        local p = dk.pending
        dk.pending = nil
        if not p then return false, "nothing pending" end
        local keep, kwhy = dk.keepVerdict(p.text, p.wrote, dk.minChars, dk.minGrowth)
        if not keep then return false, kwhy end
        local text, chars, cut = dk.clip(p.text, dk.maxChars)
        local okW, wwhy = dk.append({ at = os.time(), app = p.app, title = p.title,
                                      role = p.role, chars = chars, cut = cut,
                                      text = text })
        if not okW then
            -- 🔔 A BREAK IS SEEN, NEVER ONLY LOGGED (6.214.0). A draft
            -- this tool believed it kept and did not is the one failure
            -- here that costs him writing.
            if core.degrade then
                pcall(core.degrade, "Draft keeper",
                      "a draft from " .. tostring(p.app) .. " was NOT kept — "
                      .. tostring(wwhy))
            end
            return false, wwhy
        end
        dk.kept       = dk.kept + 1
        dk.lastKeptAt = os.time()
        dk.lastKept   = { app = p.app, title = p.title, role = p.role,
                          chars = chars, why = (why or "settled"), keep = kwhy }
        -- 💾 ONE CONSOLE LINE PER SESSION, so it is visibly alive without
        -- being a tool that talks. An alert per draft is a tool he
        -- switches off (6.269.0).
        if not dk.saidAlive then
            dk.saidAlive = true
            print(("💾 Draft keeper: kept a %d-character draft from %s — ⇪D @draft"
                   .. " finds it, _G.draftKeeperReport() for the rest.")
                  :format(chars, tostring(p.app)))
        end
        return true, kwhy
    end

    -- ---- one sample ---------------------------------------------------
    function dk.sample()
        dk.samples = dk.samples + 1

        if _G.hsPaused then
            dk.refused.paused = dk.refused.paused + 1
            dk.lastRefusal = "⇪⇧Esc has paused this config"
            dk.flush("paused")
            return
        end

        local t0 = nowMs()
        local f  = dk.readFocused()
        local ms = math.floor(nowMs() - t0 + 0.5)
        dk.lastMs = ms

        if f.unwatched then
            dk.skipped.app = dk.skipped.app + 1
            dk.flush("the front app is not watched")
            return
        end

        dk.reads = dk.reads + 1
        if ms > dk.worstMs then dk.worstMs = ms end
        if ms > dk.slowMs then
            dk.slow = dk.slow + 1
            -- 🚨 BACK OFF RATHER THAN GO ON COSTING HIM THE THREAD.
            dk.everySecs = math.min((dk.everySecs or dk.sampleSecs) * 2,
                                    dk.sampleMaxSecs)
            if not dk.saidSlow then
                dk.saidSlow = true
                if core.degrade then
                    pcall(core.degrade, "Draft keeper",
                          ("asking %s what is in the focused field took %d ms —"
                           .. " slower than the %d ms budget, so it is sampling"
                           .. " every %d s now. settings = { draft_keeper ="
                           .. " { enabled = false } } stops it.")
                          :format(tostring(f.app or "that app"), ms, dk.slowMs,
                                  dk.everySecs))
                end
            end
        end

        if not f.role and not f.value then
            -- nothing focused, or the app would not answer at all
            dk.skipped.nothing = dk.skipped.nothing + 1
            dk.flush("nothing is focused")
            return
        end

        local secureHeld = false
        local si = _G.secureInput
        if type(si) == "table" and si.on == true then secureHeld = true end

        local kind, why = dk.fieldVerdict(f.role, secureHeld, false)
        if kind ~= "watch" then
            if kind == "secure" then
                dk.refused.secure = dk.refused.secure + 1
            elseif kind == "unknown" then
                dk.refused.role = dk.refused.role + 1
            elseif kind == "secure-input" then
                dk.refused.secureInput = dk.refused.secureInput + 1
            else
                dk.skipped.notText = dk.skipped.notText + 1
            end
            dk.lastRefusal = why
            -- 🚨 A REFUSAL STILL FLUSHES WHAT WAS PENDING: he tabbed from
            -- a body he was writing into a password field, and that body
            -- is the draft. What is refused is READING the new field.
            dk.flush(why)
            return
        end

        local text = type(f.value) == "string" and f.value or ""
        local key  = dk.fieldKey(f.app, f.title, f.role)
        local p    = dk.pending

        if not p or p.key ~= key then
            dk.flush("the focus moved to another field")
            dk.pending = { key = key, app = f.app, title = f.title, role = f.role,
                           text = text, changedAt = os.time(), wrote = nil }
            return
        end

        if text ~= p.text then
            p.text = text
            p.changedAt = os.time()
            return
        end

        -- unchanged: has it settled?
        if os.time() - (p.changedAt or 0) < dk.settleSecs then return end
        local keep, kwhy = dk.keepVerdict(text, p.wrote, dk.minChars, dk.minGrowth)
        if not keep then return end
        local clipped, chars, cut = dk.clip(text, dk.maxChars)
        local okW, wwhy = dk.append({ at = os.time(), app = p.app, title = p.title,
                                      role = p.role, chars = chars, cut = cut,
                                      text = clipped })
        if not okW then
            if core.degrade then
                pcall(core.degrade, "Draft keeper",
                      "a draft from " .. tostring(p.app) .. " was NOT kept — "
                      .. tostring(wwhy))
            end
            return
        end
        p.wrote = text                   -- what is on disk for THIS field
        dk.kept = dk.kept + 1
        dk.lastKeptAt = os.time()
        dk.lastKept = { app = p.app, title = p.title, role = p.role,
                        chars = chars, why = "settled", keep = kwhy }
        if not dk.saidAlive then
            dk.saidAlive = true
            print(("💾 Draft keeper: kept a %d-character draft from %s — ⇪D @draft"
                   .. " finds it, _G.draftKeeperReport() for the rest.")
                  :format(chars, tostring(p.app)))
        end
    end

    -- ---- the one door that arms the next sample ----------------------
    -- 🔁 A RE-ARM GOES THROUGH THE DOOR THAT ARMED IT (6.387.0): one
    -- slot, one function, so a changed interval cannot leave a second
    -- timer running beside the first.
    function dk.arm()
        if dk.timer then pcall(function() dk.timer:stop() end) ; dk.timer = nil end
        if not dk.enabled then return false, "switched off" end
        local every = dk.everySecs or dk.sampleSecs
        local okT, t = pcall(hs.timer.doAfter, every, function()
            dk.timer = nil
            local ok, err = pcall(dk.sample)
            if not ok then
                dk.lastRefusal = "the sample threw — " .. tostring(err)
            end
            dk.arm()
        end)
        dk.timer = okT and t or nil          -- HELD (6.196.1)
        if not okT then
            dk.noTimer = (dk.noTimer or 0) + 1
            return false, "this Mac would not arm a timer"
        end
        return true
    end

    function dk.stop()
        if dk.timer then pcall(function() dk.timer:stop() end) ; dk.timer = nil end
        dk.flush("stopped")
        dk.enabled = false
        return true
    end

    function dk.start()
        dk.enabled = true
        dk.everySecs = dk.sampleSecs
        dk.saidSlow = false
        return dk.arm()
    end

    -- ---- the doors ----------------------------------------------------
    function _G.draftForget(n)
        n = tonumber(n)
        local rows, err = dk.rows({ max = 100000, tail = 64 * 1024 * 1024 })
        if not rows then print("💾 " .. tostring(err)) ; return false end
        if not n or n < 1 or n > #rows then
            print("💾 _G.draftForget(n) — n is a row number from _G.draftKeeperReport()"
                  .. " (1 is the newest). There are " .. #rows .. ".")
            return false
        end
        local gone = rows[n]
        -- rows came back NEWEST FIRST; the file is oldest first
        local keep = {}
        for i = #rows, 1, -1 do
            if i ~= n then keep[#keep + 1] = rows[i] end
        end
        local okW, whyW = dk.rewrite(keep)
        if not okW then print("💾 Not forgotten — " .. tostring(whyW)) ; return false end
        print(("💾 Forgotten: the %d-character draft from %s at %s %s.")
              :format(gone.chars or 0, tostring(gone.app), tostring(gone.date),
                      tostring(gone.clock)))
        return true
    end

    function _G.draftForgetAll()
        local okW, whyW = dk.rewrite({})
        if not okW then print("💾 Not emptied — " .. tostring(whyW)) ; return false end
        print("💾 Every kept draft is forgotten. The file is "
              .. dk.path() .. " and it is empty.")
        return true
    end

    -- ---- the report ---------------------------------------------------
    -- ---- 🩺 6.411.0 — "IS IT WORKING RIGHT NOW?" ----------------------
    -- LL: "Draft keeper doesn't seem to be working. How do I know?"
    --
    -- 🔑 THE INSTRUMENT WAS NOT THE GAP, THE DOOR WAS (6.317.0, sixth
    -- time). _G.draftKeeperReport() has counted every refusal since
    -- 6.404.0 — but it describes a SESSION, and the question he is
    -- actually asking is about THIS field, the one the caret is in,
    -- right now. A session total cannot answer that: "0 kept" is true
    -- of a quiet morning and of a feature that can never read anything,
    -- and those are opposite facts (6.196.1).
    --
    -- So this reads the focused field at the moment it is called and
    -- says, in words, what it found and what would happen to it. Click
    -- into the box, run it, read one block.
    --
    -- 🔒 IT NEVER PRINTS THE TEXT. The character count is the answer;
    -- the words are his, and a diagnostic that puts a half-written email
    -- in the Console is a worse tool than the one that said nothing.
    -- ONE RENDERER, TWO READERS (6.231.0): the report calls it too, so
    -- the two cannot drift about what a refusal is called.
    function dk.checkLines()
        local L = {}
        local function line(s) L[#L + 1] = s end

        if not dk.enabled then
            line("switch : OFF — settings = { draft_keeper = { enabled = true } }")
            return L
        end

        local f = dk.readFocused()
        line("app    : " .. tostring(f.app or "could not be read"))

        if f.unwatched then
            line("        ↳ NOT a watched app, so nothing here is read at all.")
            line("          Watched: " .. table.concat(dk.apps, " · "))
            line("          Click into a text box in one of those and run this again.")
            return L
        end

        local a = dk.asked[f.app or ""]
        if a == nil then
            line("tree   : not asked yet")
        elseif a.ok then
            line("tree   : asked, and " .. tostring(f.app) .. " accepted "
                 .. tostring(a.how))
        else
            line("tree   : ⚠️ ASKED AND REFUSED — this app would not build its"
                 .. " accessibility tree,")
            line("          so the text inside its pages cannot be read here."
                 .. " That is the app's")
            line("          answer, not a fault in this config — paste this block.")
        end

        if not f.role and not f.value then
            line("field  : ⚠️ NOTHING IS FOCUSED — macOS named no field.")
            line("          Click INTO a text box first, then run this again."
                 .. " If the caret")
            line("          really is in one, that is the finding: paste this block.")
            return L
        end

        local secureHeld = false
        local si = _G.secureInput
        if type(si) == "table" and si.on == true then secureHeld = true end
        local kind, why = dk.fieldVerdict(f.role, secureHeld, _G.hsPaused == true)
        line("field  : " .. tostring(f.role or "unnamed") .. " — " .. tostring(why))
        if kind ~= "watch" then
            line("        ↳ refused, and that is the rule working.")
            return L
        end

        local text = type(f.value) == "string" and f.value or ""
        local n    = dk.len(text)
        line(("holds  : %d character(s)  (the text itself is never printed)")
             :format(n))

        local p    = dk.pending
        local last = (p and p.key == dk.fieldKey(f.app, f.title, f.role))
                     and p.wrote or nil
        local keep, kwhy = dk.keepVerdict(text, last, dk.minChars, dk.minGrowth)
        if keep then
            line("verdict: ✅ THIS WOULD BE KEPT — " .. tostring(kwhy))
            line(("         after %d s of not typing. Wait that long, then"):format(dk.settleSecs))
            line("         run _G.draftKeeperReport() — the kept count goes up.")
        else
            line("verdict: nothing to keep — " .. tostring(kwhy))
            if n < dk.minChars then
                line(("         type %d more character(s) and run this again.")
                     :format(dk.minChars - n))
            end
        end
        line("cost   : " .. (dk.lastMs and (dk.lastMs .. " ms to ask") or "not timed yet"))
        return L
    end

    function _G.draftCheck()
        local L = { "💾 DRAFT KEEPER — what it can see RIGHT NOW" }
        for _, s in ipairs(dk.checkLines()) do L[#L + 1] = "   " .. s end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    function _G.draftKeeperReport()
        local L = { "💾 DRAFT KEEPER — the text a web form loses" }
        local function line(s) L[#L + 1] = "   " .. s end

        if not dk.enabled then
            line("switch : OFF — settings = { draft_keeper = { enabled = true } }"
                 .. " turns it on, or _G.draftKeeper.start() right now")
        elseif dk.timer then
            line(("watch  : every %d s while one of %d app(s) is in front")
                 :format(dk.everySecs or dk.sampleSecs, #dk.apps))
        else
            line("watch  : ⚠️ ON and NOT RUNNING — no timer is armed."
                 .. " _G.draftKeeper.start() arms one.")
            if (dk.noTimer or 0) > 0 then
                line("         ↳ " .. dk.noTimer .. " × this Mac would not arm a timer")
            end
        end
        line("apps   : " .. table.concat(dk.apps, " · "))
        -- 🪟 6.411.0 — THREE STATES, and the middle one is the finding.
        -- "not asked yet" is an ordinary morning; "accepted" is the
        -- release working; "REFUSED" is that app saying no, which is a
        -- fact about the app and not a fault here (6.196.1).
        do
            local names, refused = {}, {}
            for app, a in pairs(dk.asked) do
                if a.ok then names[#names + 1] = app .. " (" .. tostring(a.how) .. ")"
                else refused[#refused + 1] = app end
            end
            table.sort(names) ; table.sort(refused)
            if #names == 0 and #refused == 0 then
                line("tree   : no watched app has been in front yet this session")
            else
                line("tree   : " .. (#names > 0 and table.concat(names, " · ")
                                     or "none accepted"))
                if #refused > 0 then
                    line("         ↳ ⚠️ REFUSED by " .. table.concat(refused, " · ")
                         .. " — their pages cannot be read")
                end
            end
        end
        line("rule   : " .. dk.minChars .. "+ characters, unchanged for "
             .. dk.settleSecs .. " s — then a row")
        line("file   : " .. dk.path()
             .. (dk.local_ and "  (local, never synced)" or "  (it SYNCS — it is in your"
                 .. " Logs folder; settings = { draft_keeper = { local_ = true } })"))

        -- what it kept
        if dk.kept == 0 then
            line("kept   : nothing yet this session")
        else
            line(("kept   : %d draft(s) this session · %d row(s) written")
                 :format(dk.kept, dk.wrote))
            local k = dk.lastKept
            if k then
                line(("         ↳ last: %d character(s) from %s — %s")
                     :format(k.chars or 0, tostring(k.app), tostring(k.keep)))
                if k.title and k.title ~= "" then
                    line("           " .. tostring(k.title))
                end
            end
        end
        if dk.failedWrites > 0 then
            line("         ⚠️ " .. dk.failedWrites .. " draft(s) could NOT be written — "
                 .. tostring(dk.lastWhy))
            line("           Those words were never kept. Check the folder above.")
        end

        -- what it cost
        if dk.reads == 0 then
            line("cost   : " .. dk.samples .. " sample(s), none reached an AX read"
                 .. " (no watched app has been in front)")
        else
            line(("cost   : %d sample(s) · %d reached a read · worst %d ms · last %s ms")
                 :format(dk.samples, dk.reads, dk.worstMs, tostring(dk.lastMs)))
            -- 📏 WHAT THE WAKE-UPS BOUGHT, beside what they cost (6.229.0).
            if dk.kept > 0 then
                line(("         ↳ yield: %d read(s) for every draft kept")
                     :format(math.floor(dk.reads / dk.kept)))
            end
            if dk.slow > 0 then
                line("         ⚠️ " .. dk.slow .. " read(s) over the " .. dk.slowMs
                     .. " ms budget — it is sampling every "
                     .. (dk.everySecs or dk.sampleSecs) .. " s now")
            end
        end

        -- what it refused, and the two kinds are apart
        local r, s = dk.refused, dk.skipped
        local anyR = (r.secure + r.role + r.secureInput + r.paused) > 0
        if anyR then
            line(("refused: %d password field(s) · %d field(s) macOS would not describe"
                  .. " · %d while Secure Input was held · %d while paused")
                 :format(r.secure, r.role, r.secureInput, r.paused))
        else
            line("refused: none — no password field and no unreadable field was met")
        end
        line(("skipped: %d not a watched app · %d nothing focused · %d not a text field")
             :format(s.app, s.nothing, s.notText))
        if dk.lastRefusal then
            line("         ↳ last: " .. tostring(dk.lastRefusal))
        end

        -- the pending draft, which is the one not yet on disk
        local p = dk.pending
        if p then
            local n = dk.len(p.text)
            line(("pending: %d character(s) from %s — %s")
                 :format(n, tostring(p.app),
                         (n < dk.minChars)
                             and ("under " .. dk.minChars .. ", so it is not a draft yet")
                             or  ("on disk within " .. dk.settleSecs .. " s of you stopping")))
        else
            line("pending: nothing — no watched field is being typed in right now")
        end

        -- the store
        if dk.pruned == nil then
            line("90 days: ⏳ not pruned yet this session")
        elseif dk.pruneWhy then
            line("90 days: ⚠️ " .. tostring(dk.pruneWhy))
        elseif dk.pruned == 0 then
            line("90 days: nothing was older than " .. dk.days .. " days")
        else
            line("90 days: " .. dk.pruned .. " row(s) older than " .. dk.days
                 .. " days were removed this session")
        end

        local rows, rerr = dk.rows({ max = 12 })
        if not rows then
            line("rows   : ⚠️ " .. tostring(rerr))
            line("         This is NOT 'nothing was kept'.")
        elseif #rows == 0 then
            line("rows   : the file was read and holds nothing")
        else
            local all = dk.rows({ max = 100000 })
            line("rows   : " .. #(all or rows) .. " kept · newest first, "
                 .. math.min(#rows, 12) .. " shown"
                 .. " · ⇪D @draft searches them · ⏎ copies")
            for i = 1, math.min(#rows, 12) do
                local x = rows[i]
                local one = tostring(x.text):gsub("%s+", " "):sub(1, 64)
                L[#L + 1] = ("   %2d. %s %s · %s · %d chars%s")
                            :format(i, tostring(x.date), tostring(x.clock),
                                    tostring(x.app), x.chars or 0,
                                    x.cut and " (cut)" or "")
                L[#L + 1] = "       " .. one
            end
            line("forget : _G.draftForget(n) removes one · _G.draftForgetAll() empties it")
        -- 🩺 THE SAME RENDERER _G.draftCheck() USES (6.231.0) — so the
        -- report and the check cannot answer differently about the field
        -- the caret is in.
        line("now    : what it can see at this moment —")
        for _, c in ipairs(dk.checkLines()) do L[#L + 1] = "            " .. c end
        line("        ↳ _G.draftCheck() prints just that block, on its own")
        end

        local out = table.concat(L, "\n")
        print(out)
        return out
    end

    -- ---- services, for ⇪D --------------------------------------------
    -- 🔗 ONE PARSER, TWO READERS (6.231.0): @draft and the report read
    -- the same rows through the same function, so they cannot drift
    -- about what a column means.
    if core.provide then
        core.provide("draft.rows", function(opts) return dk.rows(opts) end)
        core.provide("draft.path", function() return dk.path() end)
        core.provide("draft.check", function() return dk.checkLines() end)
    end

    _G.draftKeeper = dk
    return dk
end

-- 🕰 THE WATCH STARTS IN warm, NEVER setup (6.228.0): init.lua applies a
-- profile's `settings` AFTER setup returns, so anything started inside
-- setup can never be stopped by an override — the flag is written and
-- nobody reads it again. With a watcher that reads what he types, a
-- switch that cannot switch it off is the wrong way round.
M.warm = function()
    local dk = _G.draftKeeper
    if not dk then return end
    if not dk.enabled then return end
    dk.everySecs = dk.sampleSecs
    dk.arm()
    -- ⏱ The prune is a WHOLE-FILE read, so it waits until the Mac is
    -- quiet rather than riding the warm phase with everything else.
    local okT, t = pcall(hs.timer.doAfter, 12, function()
        dk.pruneTimer = nil
        pcall(dk.prune)
    end)
    dk.pruneTimer = okT and t or nil         -- HELD (6.196.1)
    if not okT then pcall(dk.prune) end
end

return M
