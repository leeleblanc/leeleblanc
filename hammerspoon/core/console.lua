-- =====================================================================
-- CORE: CONSOLE GATE — the errors get a section, and the repeats get a
-- count instead of a scroll. 6.95.0 · split in two in 6.96.0
-- =====================================================================
-- The requirement, in your words:
--
--   "when there is an error, place it in a defined section in the
--    output of the console so it would almost be like a header that
--    said ERRORS with some kind of double : characters that make it
--    stand out, and if the errors are repetitive, it limits the number
--    of repeating errors ... If they are not, it would report unique
--    individual errors."
--
-- And 6.96.0: "separate a type of error, errors that don't break
--    hammerspoon operations ... nonbreaking errors, and put that in
--    its own section, that way I can work on errors with you and
--    continuously improve the code."
--
-- ---------------------------------------------------------------------
-- WHAT THIS IS
-- ---------------------------------------------------------------------
-- One wrapper around `print`. Every line the config (or hs.logger)
-- prints passes through it, and the gate does exactly two things:
--
--   1. THE ERROR SECTIONS — two of them since 6.96.0, because "error"
--      was hiding two different situations:
--        ⛔ ERRORS       something actually STOPPED: a file that would
--                        not load, a traceback, an uncaught failure.
--                        Until it is fixed, some tool is missing.
--        ⚠️ NONBREAKING  something degraded POLITELY: a source skipped,
--                        a folder not found, a permission not granted.
--                        Hammerspoon runs on; the line is a to-do, not
--                        an outage — the pile to work through together.
--      A console is an append-only stream, so a "section" is drawn
--      inline: the first classified line after normal output opens its
--      banner (:::: for breaking, ---- for nonbreaking), consecutive
--      lines of the same kind share it, and the first line of a
--      DIFFERENT kind — or of normal output — closes it.
--
--   2. THE REPEAT LIMITER. Each distinct line prints `repeatLimit`
--      times (default 2); after that a single ↻ notice says it is
--      repeating and further copies are COUNTED, not printed. When a
--      line goes quiet for `repeatWindow` seconds the count is
--      summarised and the line may print again. "Distinct" ignores
--      numbers — "attempt 3/5" and "attempt 4/5", or the same error
--      with a new timestamp in it, are the same line — which is what
--      turns a key held down, or an error inside a once-a-second
--      timer, from a wall of scroll into three lines and a total.
--
-- Nothing is ever silently lost: every suppressed copy is counted, and
-- _G.errorsReport() (type it in the Console) lists every UNIQUE error
-- this session — breaking first, nonbreaking after — with its count,
-- first time and last time.
--
-- ---------------------------------------------------------------------
-- 🔬 HOW A LINE IS CLASSIFIED, so you can trust (and edit) the split
-- ---------------------------------------------------------------------
-- BREAKING is checked first and means "a thing did not survive": the
-- 💥/⛔ marks, tracebacks, "uncaught", "failed to load"/"failed while
-- loading" (the module loader's own words), "syntax error". Everything
-- else that merely SOUNDS wrong — ⚠️ 🚨 ❌, "error", "fail" — is
-- NONBREAKING: this config's house style uses exactly those for
-- "degraded but running" lines. Both lists are plain tables below;
-- promote or demote a phrase by moving it.
--
-- ---------------------------------------------------------------------
-- 🚨 A FILTER THAT CAN EAT A LINE IS WORSE THAN NOISE
-- ---------------------------------------------------------------------
-- This wraps the one channel that reports every other failure, so it is
-- held to the notices.lua standard: no work at load beyond building
-- tables, the classifier and the bookkeeping run inside pcall, and any
-- error inside the gate falls back to printing the line RAW. The gate
-- can fail to tidy; it cannot fail to deliver.
--
-- ---------------------------------------------------------------------
-- ⚠️ WHAT IT CANNOT SEE, said plainly
-- ---------------------------------------------------------------------
-- Hammerspoon's C side writes a few lines straight into the Console
-- window without going through Lua's `print` — the grey
-- "-- Loading extension: …" lines and some internal extension errors.
-- Those cannot be gated from Lua and still appear untouched. Everything
-- this config prints, and everything hs.logger prints, comes through
-- here.
--
-- ---------------------------------------------------------------------
-- 🔬 TWO DELIBERATE PASSTHROUGHS
-- ---------------------------------------------------------------------
-- Multi-line output (the ⇪⇧D report, _G.noticesReport, _G.bootReport
-- printed as one string) and anything longer than `bigLine` bytes skip
-- the gate entirely. A report you ASKED for must never be suppressed as
-- "a repeat of the report you asked for a minute ago" — that bug would
-- be built in the same breath as the feature, so it is excluded by
-- shape, not by remembering which callers are special.
-- =====================================================================
return function(core)
    local con = {}

    -- ✏️ EDIT HERE -----------------------------------------------------
    con.enabled      = true
    con.repeatLimit  = 2      -- showings of one line before it goes quiet
    con.repeatWindow = 120    -- quiet seconds before a line may print again
    con.maxTracked   = 300    -- distinct lines remembered; oldest forgotten
    con.bigLine      = 200    -- bytes; longer lines pass through ungated
    con.headline = ":::::::::::::::::::::::::::  ⛔ ERRORS  :::::::::::::::::::::::::::"
    con.footline = ":::::::::::::::::::::::::::  end errors  ::::::::::::::::::::::::::"
    con.softHeadline = "---------------------------  ⚠️ NONBREAKING  ----------------------"
    con.softFootline = "---------------------------  end nonbreaking  ---------------------"
    -- The split, per the header note. BREAKING is matched first, so a
    -- line saying "failed while loading" lands there even though it
    -- also contains "fail". Substrings; words checked case-insensitively.
    con.hardMarks = { "💥", "⛔" }
    con.hardWords = { "traceback", "uncaught", "failed to load",
                      "failed while loading", "syntax error" }
    con.softMarks = { "⚠️", "🚨", "❌" }
    con.softWords = { "error", "fail" }
    -- ------------------------------------------------------------------

    con.tracked = {}     -- normalized line -> its record
    con.order   = {}     -- normalized lines, first-seen order
    con.section = nil    -- which banner is open: nil, "hard" or "soft"

    local function now()
        local ok, t = pcall(function() return hs.timer.secondsSinceEpoch() end)
        if ok and type(t) == "number" then return t end
        return os.time()
    end
    local function clock() return os.date("%H:%M:%S") end

    local function anyOf(line, low, marks, words)
        for _, m in ipairs(marks) do
            if line:find(m, 1, true) then return true end
        end
        for _, w in ipairs(words) do
            if low:find(w, 1, true) then return true end
        end
        return false
    end

    -- nil = normal · "hard" = breaking · "soft" = nonbreaking
    function con.kindOf(line)
        local low = line:lower()
        if anyOf(line, low, con.hardMarks, con.hardWords) then return "hard" end
        if anyOf(line, low, con.softMarks, con.softWords) then return "soft" end
        return nil
    end
    -- kept for anything (tests, the Console) that asks the old question
    function con.isError(line) return con.kindOf(line) ~= nil end

    local heads = { hard = "headline",     soft = "softHeadline" }
    local feet  = { hard = "footline",     soft = "softFootline" }

    function con.closeSection()
        if con.section then
            con.raw(con[feet[con.section]])
            con.section = nil
        end
    end

    -- One line, into, out of, or ACROSS the banners. Same kind shares
    -- the open banner; a different kind (or normal output) closes it
    -- first — so a burst reads as boxed sections, never interleaved.
    function con.say(kind, text)
        if kind ~= con.section then
            con.closeSection()
            if kind then
                con.raw(con[heads[kind]])
                con.section = kind
            end
        end
        con.raw(text)
    end

    -- "The same line" ignores digits: counters, sizes, timestamps and
    -- ids vary on every repeat of what a person would call one message.
    local function keyOf(line) return (line:gsub("%d+", "#")) end

    -- hard outranks soft: a line first seen as a warning that later
    -- shows up in a traceback is filed as breaking from then on.
    local function worse(a, b)
        if a == "hard" or b == "hard" then return "hard" end
        return a or b
    end

    function con.decide(line)
        local t, kind = now(), con.kindOf(line)
        local key = keyOf(line)
        local e = con.tracked[key]

        if not e then
            e = { sample = line, firstClock = clock(),
                  shown = 0, hidden = 0, total = 0, kind = kind }
            con.tracked[key] = e
            con.order[#con.order + 1] = key
            if #con.order > con.maxTracked then
                con.tracked[table.remove(con.order, 1)] = nil
            end
        elseif (t - (e.lastAt or 0)) > con.repeatWindow then
            -- It went quiet. Close out what the last burst hid, then
            -- let the line print again — a problem that comes BACK
            -- after two minutes deserves to be seen again.
            if e.hidden > 0 then
                con.say(e.kind, "   ↻ ×" .. e.hidden
                        .. " more were hidden of: " .. e.sample:sub(1, 70))
            end
            e.shown, e.hidden = 0, 0
        end

        e.total   = e.total + 1
        e.lastAt  = t
        e.lastClock = clock()
        e.kind    = worse(e.kind, kind)

        if e.shown >= con.repeatLimit then
            e.hidden = e.hidden + 1
            if e.hidden == 1 then
                con.say(e.kind, "   ↻ that line is repeating — further "
                        .. "repeats are counted, not printed "
                        .. "(_G.errorsReport() has the totals)")
            end
            return
        end
        e.shown = e.shown + 1
        con.say(kind, line)
    end

    -- The wrapper installed over _G.print. Joins its arguments the way
    -- print does, then either gates the line or — for report-shaped
    -- output, a disabled gate, or a bug in the gate itself — prints raw.
    function con.gate(...)
        local n, parts = select("#", ...), {}
        for i = 1, n do parts[i] = tostring(select(i, ...)) end
        local line = table.concat(parts, "\t")
        if not con.enabled
           or #line > con.bigLine
           or line:find("\n", 1, true) then
            -- A passthrough is normal output: it must not appear to sit
            -- inside an open section, so any banner closes first.
            if con.section then pcall(con.closeSection) ; con.section = nil end
            return con.raw(line)
        end
        local ok = pcall(con.decide, line)
        if not ok then con.raw(line) end
    end

    function con.install()
        -- Reload-safe: if a previous gate is already installed, take
        -- over ITS raw print rather than wrapping a wrapper — a chain
        -- of gates would print the banner once per link.
        local prev = _G.consoleGate
        con.raw = (prev and prev.raw) or _G.print
        _G.print = con.gate
    end
    function con.uninstall() _G.print = con.raw end

    -- ---- the report --------------------------------------------------
    -- Every UNIQUE error this session, breaking first and nonbreaking
    -- after, one line each with its count — the suppressed copies land
    -- here instead of in the scroll. Printed through con.raw so the
    -- report itself is never gated.
    local function listKind(L, kind)
        local found = 0
        for _, key in ipairs(con.order) do
            local e = con.tracked[key]
            if e and e.kind == kind then
                found = found + 1
                L[#L + 1] = string.format("   ×%-4d %s–%s  %s", e.total,
                            e.firstClock, e.lastClock or e.firstClock,
                            e.sample)
            end
        end
        return found
    end

    function _G.errorsReport()
        pcall(con.closeSection)
        local L = { con.headline,
                    "   breaking — something stopped; a tool is missing until fixed" }
        if listKind(L, "hard") == 0 then
            L[#L + 1] = "   none — nothing has broken since load"
        end
        L[#L + 1] = con.softHeadline
        L[#L + 1] = "   nonbreaking — degraded politely, still running; the improvement pile"
        if listKind(L, "soft") == 0 then
            L[#L + 1] = "   none — nothing nonbreaking since load"
        end
        L[#L + 1] = con.footline
        local s = table.concat(L, "\n")
        con.raw(s)
        return s
    end

    con.install()
    _G.consoleGate = con
    return con
end
