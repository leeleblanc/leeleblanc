-- =====================================================================
-- CORE: CONSOLE GATE — the errors get a section, and the repeats get a
-- count instead of a scroll. 6.95.0
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
--   "I see a lot of key press announcements when I use my shortcut
--    keys ... can we reduce that number but still make the console
--    output useful"
--
-- ---------------------------------------------------------------------
-- WHAT THIS IS
-- ---------------------------------------------------------------------
-- One wrapper around `print`. Every line the config (or hs.logger)
-- prints passes through it, and the gate does exactly two things:
--
--   1. THE ERRORS SECTION. A console is an append-only stream, so a
--      "section" has to be drawn inline: the first error line after
--      normal output opens a  ::::::: ⛔ ERRORS :::::::  banner, the
--      errors print inside it, and the first normal line after them
--      closes it. Consecutive errors share one banner instead of each
--      getting its own.
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
-- this session with its count, first time and last time.
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
    -- Lines carrying any of these are filed under the ERRORS banner.
    -- Substrings, checked case-insensitively for the words — editable.
    con.errorMarks = { "⚠️", "🚨", "💥", "❌", "⛔" }
    con.errorWords = { "error", "fail", "uncaught", "traceback" }
    -- ------------------------------------------------------------------

    con.tracked  = {}     -- normalized line -> its record
    con.order    = {}     -- normalized lines, first-seen order
    con.inErrors = false  -- is the ⛔ banner currently open?

    local function now()
        local ok, t = pcall(function() return hs.timer.secondsSinceEpoch() end)
        if ok and type(t) == "number" then return t end
        return os.time()
    end
    local function clock() return os.date("%H:%M:%S") end

    function con.isError(line)
        for _, m in ipairs(con.errorMarks) do
            if line:find(m, 1, true) then return true end
        end
        local low = line:lower()
        for _, w in ipairs(con.errorWords) do
            if low:find(w, 1, true) then return true end
        end
        return false
    end

    -- One line, into or out of the banner. The banner opens when an
    -- error follows normal output and closes when normal output follows
    -- an error — so a BURST of errors reads as one boxed section.
    function con.say(isErr, text)
        if isErr and not con.inErrors then
            con.raw(con.headline)
            con.inErrors = true
        elseif not isErr and con.inErrors then
            con.raw(con.footline)
            con.inErrors = false
        end
        con.raw(text)
    end

    -- "The same line" ignores digits: counters, sizes, timestamps and
    -- ids vary on every repeat of what a person would call one message.
    local function keyOf(line) return (line:gsub("%d+", "#")) end

    function con.decide(line)
        local t, isErr = now(), con.isError(line)
        local key = keyOf(line)
        local e = con.tracked[key]

        if not e then
            e = { sample = line, firstClock = clock(),
                  shown = 0, hidden = 0, total = 0, isErr = isErr }
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
                con.say(e.isErr, "   ↻ ×" .. e.hidden
                        .. " more were hidden of: " .. e.sample:sub(1, 70))
            end
            e.shown, e.hidden = 0, 0
        end

        e.total   = e.total + 1
        e.lastAt  = t
        e.lastClock = clock()
        e.isErr   = e.isErr or isErr

        if e.shown >= con.repeatLimit then
            e.hidden = e.hidden + 1
            if e.hidden == 1 then
                con.say(e.isErr, "   ↻ that line is repeating — further "
                        .. "repeats are counted, not printed "
                        .. "(_G.errorsReport() has the totals)")
            end
            return
        end
        e.shown = e.shown + 1
        con.say(isErr, line)
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
            -- inside an open ⛔ section, so the banner closes first.
            if con.inErrors then con.raw(con.footline); con.inErrors = false end
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
    -- Every UNIQUE error this session, one line each with its count —
    -- the suppressed copies land here instead of in the scroll. Printed
    -- through con.raw so the report itself is never gated.
    function _G.errorsReport()
        if con.inErrors then con.raw(con.footline); con.inErrors = false end
        local L = { con.headline,
                    "   every unique error this session — ×count, first–last seen" }
        local found = 0
        for _, key in ipairs(con.order) do
            local e = con.tracked[key]
            if e and e.isErr then
                found = found + 1
                L[#L + 1] = string.format("   ×%-4d %s–%s  %s", e.total,
                            e.firstClock, e.lastClock or e.firstClock,
                            e.sample)
            end
        end
        if found == 0 then
            L[#L + 1] = "   none — nothing has errored since load"
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
