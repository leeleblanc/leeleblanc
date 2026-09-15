-- =====================================================================
-- core/key_trail.lua — what did I just press? 6.179.0
-- =====================================================================
-- The hardest bugs in this config's history have all had the same shape:
-- something stalled or locked the Mac, and by the time the Console was
-- open nobody could say what the last few keystrokes had been. 6.160.0's
-- hang, the ⇪4 lock-ups, the 6.162.0 latched ⇪ — every one of them was
-- reconstructed from memory, days later, from a Console log that recorded
-- the CONSEQUENCE and not the sequence.
--
-- So: a ring buffer of the last few ⇪ shortcuts, with how long each one
-- took. `_G.keyTrailReport()` prints it newest-first. That turns "it
-- froze at some point" into "these five keys, in this order, and the
-- last one took four seconds."
--
-- 🔒 WHAT IT NEVER RECORDS. Typed text. Not one character of it. The
-- trail holds COMBOS ONLY — the name a shortcut was filed under
-- (hyperCombo's string), the module that claimed it, how many
-- milliseconds it ran and whether it threw. The expander, autocorrect
-- and the key caster all see real keystrokes; this deliberately does
-- not, and it must stay that way — a troubleshooting aid that becomes a
-- keylogger is not a trade worth making.
--
-- 💾 AND IT NEVER WRITES ANYTHING. Memory only, gone on reload. There is
-- no file, no store, no ledger row, nothing to sync and nothing to
-- leak. If a future version wants the trail on disk it is a new
-- decision, made once, in the open.
--
-- IT WATCHES, IT NEVER INTERVENES. init.lua's hyperBind calls
-- _G.keyTrailRecord() AFTER the shortcut has run, nil-guarded and
-- pcall'd, exactly as it calls _G.shortcutHint. This file cannot make a
-- shortcut fail, slow one down measurably (one table write per press),
-- or change what any key does.
-- =====================================================================

return function(core)
    core = type(core) == "table" and core or {}

    local trail = {
        keep    = 24,     -- presses remembered; the oldest drops off the end
        slowMs  = 250,    -- a press over this wears ⚠️ in the report
        mergeSecs = 2,    -- the same key again within this window is ×N, not a new row
        rows    = {},     -- newest FIRST
        seen    = 0, slow = 0, threw = 0, paused = 0,
    }
    _G.keyTrail = trail

    local function now()
        if type(hs) == "table" and type(hs.timer) == "table"
           and type(hs.timer.secondsSinceEpoch) == "function" then
            local ok, t = pcall(hs.timer.secondsSinceEpoch)
            if ok and type(t) == "number" then return t end
        end
        return os.time()
    end
    trail.now = now

    -- combo, who claimed it, how long it ran, and why it did not run if
    -- it did not. Every argument is optional: a caller that knows less
    -- still gets a row rather than an error.
    -- `plain` marks a row that is NOT a ⇪ shortcut (the panic chord is
    -- bound with hs.hotkey directly): the report must not print it with a
    -- ⇪ in front, because that is precisely what it is not.
    function _G.keyTrailRecord(combo, source, ms, why, plain)
        -- 6.179.0 review — the caller times with the WALL clock, and macOS
        -- steps that at login and on wake. A shortcut that "took -1200 ms"
        -- would sort wrong, dodge the slow count and poison the ×N merge's
        -- worst-of-the-run. A duration is never negative: clamp it here,
        -- where every caller passes.
        ms = tonumber(ms) or 0
        if ms ~= ms or ms == math.huge or ms < 0 then ms = 0 end
        local row = {
            combo = tostring(combo or "?"),
            source = tostring(source or "?"),
            ms = ms,
            why = why and tostring(why) or nil,
            plain = plain == true or nil,
            at = now(),
        }
        trail.seen = trail.seen + 1
        if ms >= (tonumber(trail.slowMs) or 250) then trail.slow = trail.slow + 1 end
        if row.why == "threw" then trail.threw = trail.threw + 1 end
        if row.why == "paused" then trail.paused = trail.paused + 1 end
        -- 🚨 6.179.0 review — THE SAME KEY AGAIN IS ×N, NOT A NEW ROW. A
        -- held key on a repeating path can fire fifteen times a second,
        -- and twenty-four of those would evict everything that led up to
        -- the incident: the trail would erase exactly the evidence it
        -- exists to keep, at exactly the moment it is needed.
        local head = trail.rows[1]
        if head and head.combo == row.combo and head.why == row.why
           and (row.at - (head.at or 0)) <= (tonumber(trail.mergeSecs) or 2) then
            head.times = (head.times or 1) + 1
            head.at = row.at
            if ms > (head.ms or 0) then head.ms = ms end   -- the worst of the run
            return head
        end
        row.times = 1
        table.insert(trail.rows, 1, row)
        while #trail.rows > (tonumber(trail.keep) or 24) do table.remove(trail.rows) end
        return row
    end

    -- "2m 14s ago" reads better than a timestamp when the question is
    -- "what did I press just before it happened".
    local function ago(secs)
        secs = math.max(0, math.floor(tonumber(secs) or 0))
        if secs < 60 then return secs .. "s ago" end
        if secs < 3600 then return string.format("%dm %02ds ago", secs // 60, secs % 60) end
        return string.format("%dh %02dm ago", secs // 3600, (secs % 3600) // 60)
    end
    trail.ago = ago

    -- 🚨 ONE print, not one per row (6.179.1). core/console.lua's gate
    -- de-duplicates short single lines after two showings and opens ⛔ /
    -- ⚠️ banners around any line carrying those marks — so a report
    -- printed row by row loses its repeated rows (the third slow press of
    -- the same key: exactly the row LL would be hunting) and gets banners
    -- spliced through the middle of it. A string containing newlines
    -- passes the gate untouched, which is why _G.noticesReport() has
    -- always been built this way. Any report added here does the same.
    -- %-15s counts BYTES, and ⇪ (and the panic chord's glyphs) are three
    -- bytes each, so string.format alone leaves the columns ragged.
    local function pad(str, w)
        str = tostring(str or "")
        local n = (type(utf8) == "table" and utf8.len and utf8.len(str)) or #str
        if not n or n >= w then return str end
        return str .. string.rep(" ", w - n)
    end

    function _G.keyTrailReport()
        local L = { "⌨️  KEY TRAIL — the last " .. tostring(trail.keep)
                    .. " ⇪ shortcuts (combos only; no typed text is ever recorded)" }
        if #trail.rows == 0 then
            L[#L + 1] = "   nothing pressed yet this session"
            local s = table.concat(L, "\n")
            print(s)
            return 0
        end
        local t = now()
        for _, r in ipairs(trail.rows) do
            L[#L + 1] = string.format("   %s %s %s %6.0f ms%s%s",
                  pad(ago(t - r.at), 12), pad((r.plain and "" or "⇪") .. r.combo, 15),
                  pad(r.source, 20), r.ms,
                  (r.times or 1) > 1 and ("  ×" .. r.times) or "",
                  r.why == "paused" and "  ⏸ paused — it did nothing"
                  or (r.why == "threw" and "  ⛔ THREW"
                  or (r.ms >= trail.slowMs and "  ⚠️ slow" or "")))
        end
        L[#L + 1] = string.format("   %d press%s this session · %d over %d ms · %d threw · %d while paused",
              trail.seen, trail.seen == 1 and "" or "es", trail.slow,
              trail.slowMs, trail.threw, trail.paused)
        print(table.concat(L, "\n"))
        return #trail.rows
    end

    return trail
end
