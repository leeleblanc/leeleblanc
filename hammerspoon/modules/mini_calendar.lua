-- =====================================================================
-- MODULE: MINI CALENDAR (⇪⇧0) — three months, and a menu-bar date
-- =====================================================================
-- ⇪⇧0 drops a 1024×768 translucent panel under the clock showing THREE
-- months at once: the one you are in and the two after it. Arrows walk a
-- day at a time, ↑↓ a week, [ ] a month. The week you are in now is
-- banded, today is ringed, the day under the cursor is filled. Esc
-- closes it. A menu-bar item shows the date and opens the same panel.
--
-- 🗓 WHY THE RANGE STOPS AT A YEAR. You asked for a full year and
-- nothing larger, so the cursor is CLAMPED to ±365 days and says so when
-- it hits the wall. That is not a limitation dressed up as a feature: a
-- calendar you can scroll forever is a calendar you get lost in, and the
-- panel always shows you where the edge is.
--
-- ⏰ WHY EVERY DATE IS BUILT AT NOON. os.time{...} with hour = 12 and
-- then ±86400 is the only arithmetic here. Adding a day to midnight is
-- wrong twice a year: on the spring-forward day midnight + 24h is 01:00
-- the next day, and on the fall-back day it is 23:00 the SAME day — so a
-- "next day" key would silently do nothing every October. Starting from
-- noon leaves twelve hours of slack in both directions, which no DST
-- shift on earth comes close to.
--
-- 🖱 THE PANEL IS CLICKABLE BUT NEVER TAKES FOCUS. clickActivating(false)
-- means clicking a date does not pull Hammerspoon in front of whatever
-- you were reading. Keys arrive through an hs.hotkey.modal instead,
-- which is armed only while the panel is up.

local M = {
    name  = "Mini Calendar",
    order = 13.2,
    family = "time",
    cheatsheet = {
        title = "🗓 MINI CALENDAR (⇪⇧0 — three months)",
        entries = {
            { "⇪⇧0",   "Open / close the three-month panel" },
            { "menu bar", "The date next to the clock opens the same panel" },
            { "← →",   "A day at a time" },
            { "↑ ↓",   "A week at a time" },
            { "[ ]",   "A month at a time (⇧← ⇧→ do the same)" },
            { "T / Home", "Back to today" },
            { "click",  "A date COPIES it as 08-07-26 · ‹ › change month · Today" },
            { "C",      "Copy the highlighted date without reaching for the mouse" },
            { "R",      "Copy a “Date report:” — every format at once, time included" },
            { "clock",  "The panel shows the time NOW, live to the second" },
            { "range",  "±1 year from today, then it stops and tells you" },
            { "Esc",    "Close" },
        },
    },
}

function M.setup(core)
    local cal = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    cal.enabled     = true
    cal.width       = 1024
    -- 🗓 6.244.0 — NIL MEANS "AS TALL AS WHAT IS IN IT". LL: "I don't
    -- know why we made such a large empty space below the dates" and
    -- "There's a lot of space below the calendar. Why do we have that?"
    -- Because the height was a LITERAL 768 while the content needed about
    -- 490, and the readout under the months was stretched to fill whatever
    -- was left over (the window's height, less the footer's top, less the
    -- padding) — so the emptier
    -- the panel, the bigger the empty box drawn around the date. The
    -- height is worked out from the parts now. A NUMBER here is still
    -- taken at its word, the way ft.folders is (6.230.0's rule: nil means
    -- work it out, anything else is obeyed).
    --   settings = { mini_calendar = { height = 700 } }
    cal.height      = nil
    cal.months      = 3         -- panels across. 3 fits 1024 comfortably.
    cal.dayTextSize = 16        -- the date numbers, as asked
    cal.alpha       = 0.94      -- translucent BLACK, not grey (see bg below)
    -- 🎨 6.244.0 — THE MUSIC PLAYER'S CARD, on LL's ask ("Can you
    -- please make this look like the music player window?"). The player is
    -- a WEBVIEW and is the one panel ui_style.lua does not reach, so its
    -- numbers are written here rather than read from there: #15161a card,
    -- #1b1d23 header strip, #22242b buttons with a #33353e hairline,
    -- #9a9aa4 and #7d7f89 for the two receded greys.
    -- 🚨 NAMED, NOT FIXED (6.201.1's rule): that makes the calendar the
    -- SECOND panel wearing the player's look while nine others still wear
    -- ui_style's. The right end state is the player's palette folded INTO
    -- ui_style so one edit moves all eleven — but that restyles eleven
    -- panels in one go, which is a sweep, and the rule here is one change
    -- per release. It waits for its own.
    local st = _G.uiStyle or {}
    cal.bg          = { red = 0.082, green = 0.086, blue = 0.102 }  -- #15161a
    cal.headerBg    = { red = 0.106, green = 0.114, blue = 0.137 }  -- #1b1d23
    cal.btnBg       = { red = 0.133, green = 0.141, blue = 0.169 }  -- #22242b
    cal.btnStroke   = { red = 0.200, green = 0.208, blue = 0.243 }  -- #33353e
    cal.ink         = { red = 0.906, green = 0.906, blue = 0.918 }  -- #e7e7ea
    cal.inkDim      = { red = 0.604, green = 0.604, blue = 0.643 }  -- #9a9aa4
    cal.inkFaint    = { red = 0.490, green = 0.498, blue = 0.537 }  -- #7d7f89
    cal.weekStart   = 2         -- 1 = Sunday, 2 = Monday (matches Itsycal)
    cal.rangeDays   = 365       -- how far the cursor may travel either way
    cal.menuBar     = true      -- show the date next to the clock
    cal.menuFormat  = "%a %-d"  -- "Thu 6" — %-d is handled below for portability
    cal.anchor      = "topRight"-- "topRight" (under the clock) or "center"
    cal.margin      = 12        -- gap from the screen edge when anchored
    -- Clicking a date copies it in this format. %m-%d-%y is 08-07-26 —
    -- all three parts zero-padded and two digits, so pasted dates line up.
    -- %Y for a four-digit year, %d-%m-%y for day-first, etc.
    cal.copyFormat  = "%m-%d-%y"
    cal.copyOnClick = true      -- false = clicking only selects, never copies
    -- 🕐 6.147.0 — the clock and the report, both LL's ask, verbatim:
    -- "give all as a 'Date report:'" and "a time display: 2:00:00 PM so
    -- I can see what time it is". The clock is drawn live while the
    -- panel is open; R copies the report — the highlighted date in
    -- EVERY format below, the week/day line, and the time now.
    cal.timeFormat    = "%I:%M:%S %p"   -- 02:00:00 PM; the zero is shaved
    cal.reportFormats = {
        "%m-%d-%y",          -- 09-01-26 · the click-to-copy shape
        "%Y-%m-%d",          -- 2026-09-01 · ISO, sorts everywhere
        "%m/%d/%Y",          -- 09/01/2026
        "%B %d, %Y",         -- September 01, 2026
        "%A, %B %d, %Y",     -- Tuesday, September 01, 2026
        "%a, %b %d",         -- Tue, Sep 01
        "%d %B %Y",          -- 01 September 2026
    }
    -- ----------------------------------------------------------------------

    cal.canvas = nil    -- HELD. A collected canvas takes the panel with it.
    cal.clock  = nil    -- HELD: the 1s re-render while the panel is open
    cal.modal  = nil    -- HELD, same reason, and it owns the arrow keys
    cal.menu   = nil    -- HELD
    cal.tick   = nil    -- HELD: the timer that refreshes the menu-bar date
    cal.cursor = nil    -- the selected day, as an os.time value at noon
    cal.today  = nil
    cal.hitboxes = {}   -- element id -> what clicking it means

    local WEEKDAYS = { "S", "M", "T", "W", "T", "F", "S" }
    local MONTHS = { "January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December" }

    -- ---- date arithmetic -------------------------------------------------
    local function noon(y, m, d)
        return os.time({ year = y, month = m, day = d, hour = 12, min = 0, sec = 0 })
    end

    local function todayNoon()
        local t = os.date("*t")
        return noon(t.year, t.month, t.day)
    end

    local function daysInMonth(y, m)
        -- Day 0 of the next month IS the last day of this one, and os.time
        -- normalises month 13 into January of the next year, so this needs
        -- no leap-year rule of its own — the C library already has one.
        return tonumber(os.date("%d", os.time({ year = y, month = m + 1, day = 0, hour = 12 })))
    end

    local function addDays(t, n) return t + n * 86400 end

    local function addMonths(t, n)
        local d = os.date("*t", t)
        local m = d.month + n
        local y = d.year + math.floor((m - 1) / 12)
        m = ((m - 1) % 12) + 1
        -- 31 January plus one month has no answer, so take the last day of
        -- the month you landed in. Without this, os.time would roll March
        -- 31st over into "April 31st" = May 1st, and the cursor would skip a
        -- month every time it passed a short one.
        return noon(y, m, math.min(d.day, daysInMonth(y, m)))
    end

    local function sameDay(a, b)
        return os.date("%Y-%m-%d", a) == os.date("%Y-%m-%d", b)
    end

    -- Which column (1..7) a date sits in, honouring cal.weekStart.
    local function colOf(t)
        local wday = os.date("*t", t).wday          -- 1 = Sunday
        return ((wday - cal.weekStart) % 7) + 1
    end

    local function startOfWeek(t)
        return addDays(t, -(colOf(t) - 1))
    end

    local function clampToRange(t)
        local lo = addDays(cal.today, -cal.rangeDays)
        local hi = addDays(cal.today,  cal.rangeDays)
        if t < lo then return lo, true end
        if t > hi then return hi, true end
        return t, false
    end

    -- ---- geometry --------------------------------------------------------
    -- 🗓 6.244.0 — PURE, AND IT ANSWERS THE PANEL'S OWN HEIGHT. Every
    -- band is stacked in the order it is drawn and the total falls out of
    -- the sum, so there is no number anywhere that has to be kept in step
    -- with the layout by hand — which is exactly what 768 was.
    --
    -- THE ORDER IS THE RELEASE (LL: "The date and time should be above the
    -- months, same as large"):
    --      header strip   the month range, and ‹ Today ›
    --      the readout    the big date and the live clock, then the
    --                     week/day line  — ABOVE the months now
    --      the months     always SIX rows, so the panel does not change
    --                     height between a five-row month and a six-row one
    --      the footer     the key hints, immediately under the months
    function cal.layout(width, months)
        width  = tonumber(width) or 1024
        months = math.max(1, math.floor(tonumber(months) or 3))
        local L = {}
        L.pad      = 22
        L.headerH  = 56
        L.gap      = 22
        L.colW     = (width - L.pad * 2 - L.gap * (months - 1)) / months
        L.cellW    = math.floor((L.colW - 8) / 7)
        L.cellH    = 36
        L.titleH   = 32
        L.dowH     = 22
        L.monthH   = L.titleH + L.dowH + 6 * L.cellH
        L.readY    = L.headerH + 10
        L.readH    = 88
        L.monthY   = L.readY + L.readH + 14
        L.footY    = L.monthY + L.monthH + 12
        L.footH    = 22
        -- The panel is the sum of its bands and the bottom padding. Nothing
        -- is stretched to reach an edge, which is the whole fix.
        L.height   = L.footY + L.footH + L.pad
        return L
    end

    local function layout()
        return cal.layout(cal.drawW or cal.width, cal.months)
    end

    -- The height the panel ASKS FOR: his override if he set one, else the
    -- content's own. `cal.drawH` is what it actually GOT after the screen
    -- clamped it, and the two are deliberately different fields — writing
    -- the clamped number back over the knob is how the old code lost the
    -- ability to work the height out ever again.
    function cal.panelHeight()
        return tonumber(cal.height) or cal.layout(cal.width, cal.months).height
    end

    -- ---- drawing ---------------------------------------------------------
    local function drawMonth(els, L, originX, y, anchorTime)
        local d = os.date("*t", anchorTime)
        local y0, m0 = d.year, d.month
        local first  = noon(y0, m0, 1)
        local lead   = colOf(first) - 1          -- blank cells before the 1st
        local count  = daysInMonth(y0, m0)
        local gridX  = originX + (L.colW - L.cellW * 7) / 2

        table.insert(els, {
            type = "text", text = MONTHS[m0] .. " " .. y0,
            textSize = 18, textAlignment = "center",
            textColor = st.fg or { white = 0.98 },
            frame = { x = originX, y = y, w = L.colW, h = L.titleH },
        })

        for c = 1, 7 do
            -- WEEKDAYS is Sunday-first; rotate it by whatever weekStart says
            -- rather than keeping a second table in the other order.
            local idx = ((c - 1 + cal.weekStart - 1) % 7) + 1
            table.insert(els, {
                type = "text", text = WEEKDAYS[idx],
                textSize = 11, textAlignment = "center",
                textColor = { white = 0.45 },
                frame = { x = gridX + (c - 1) * L.cellW, y = y + L.titleH,
                          w = L.cellW, h = L.dowH },
            })
        end

        local weekOfToday = startOfWeek(cal.today)
        local gridTop = y + L.titleH + L.dowH

        for day = 1, count do
            local t    = noon(y0, m0, day)
            local slot = lead + day - 1
            local row  = math.floor(slot / 7)
            local col  = slot % 7
            local cx   = gridX + col * L.cellW
            local cy   = gridTop + row * L.cellH

            -- The band for the week you are in NOW. Drawn once per row, from
            -- the first cell of that row, so it reads as one bar rather than
            -- seven adjacent rectangles with seams between them.
            if col == 0 or day == 1 then
                if sameDay(startOfWeek(t), weekOfToday) then
                    table.insert(els, {
                        type = "rectangle", action = "fill",
                        fillColor = st.selectSoft
                                    or { red = 0.30, green = 0.55, blue = 0.95, alpha = 0.16 },
                        roundedRectRadii = { xRadius = 6, yRadius = 6 },
                        frame = { x = gridX, y = cy, w = L.cellW * 7, h = L.cellH },
                    })
                end
            end

            local isToday    = sameDay(t, cal.today)
            local isSelected = sameDay(t, cal.cursor)

            if isSelected then
                table.insert(els, {
                    type = "rectangle", action = "fill",
                    fillColor = st.select
                                or { red = 0.32, green = 0.58, blue = 0.98, alpha = 0.85 },
                    roundedRectRadii = { xRadius = 7, yRadius = 7 },
                    frame = { x = cx + 2, y = cy + 2, w = L.cellW - 4, h = L.cellH - 4 },
                })
            elseif isToday then
                table.insert(els, {
                    type = "rectangle", action = "stroke",
                    strokeColor = st.selectLine
                                  or { red = 0.45, green = 0.72, blue = 1.0, alpha = 0.95 },
                    strokeWidth = 1.5,
                    roundedRectRadii = { xRadius = 7, yRadius = 7 },
                    frame = { x = cx + 2, y = cy + 2, w = L.cellW - 4, h = L.cellH - 4 },
                })
            end

            local weekendCol = colOf(t)
            local wd = os.date("*t", t).wday
            local isWeekend = (wd == 1 or wd == 7)
            table.insert(els, {
                type = "text", text = tostring(day),
                textSize = cal.dayTextSize, textAlignment = "center",
                textColor = isSelected and { white = 1 }
                            or (isWeekend and { white = 0.55 } or { white = 0.90 }),
                -- Nudged down by a third of the line so the digits sit on the
                -- optical centre of the cell instead of its arithmetic top.
                frame = { x = cx, y = cy + (L.cellH - cal.dayTextSize) / 2 - 2,
                          w = L.cellW, h = cal.dayTextSize + 8 },
                trackMouseDown = true,
                id = "day:" .. os.date("%Y-%m-%d", t),
            })
            cal.hitboxes["day:" .. os.date("%Y-%m-%d", t)] = t
            -- weekendCol is computed above only to keep the column maths in
            -- one place; nothing else needs it.
            local _ = weekendCol
        end
    end

    local function relativeWords(t)
        local days = math.floor((t - cal.today) / 86400 + 0.5)
        if days == 0  then return "today" end
        if days == 1  then return "tomorrow" end
        if days == -1 then return "yesterday" end
        local n = math.abs(days)
        local unit
        if n < 14 then unit = n .. " days"
        elseif n < 60 then unit = math.floor(n / 7 + 0.5) .. " weeks"
        else unit = string.format("%.1f months", n / 30.44) end
        return days > 0 and ("in " .. unit) or (unit .. " ago")
    end

    function cal.render()
        if not cal.canvas then return end
        cal.hitboxes = {}
        local L = layout()
        local els = {}

        local W = cal.drawW or cal.width
        local H = cal.drawH or cal.panelHeight()
        local R = st.radius or 12

        table.insert(els, {
            type = "rectangle", action = "strokeAndFill",
            fillColor = { red = cal.bg.red, green = cal.bg.green,
                          blue = cal.bg.blue, alpha = cal.alpha },
            strokeColor = st.stroke or { white = 1, alpha = 0.16 }, strokeWidth = 1,
            roundedRectRadii = { xRadius = R, yRadius = R },
            frame = { x = 0.5, y = 0.5, w = W - 1, h = H - 1 },
        })

        -- 🎨 6.244.0 — the music player's HEADER STRIP: a slightly
        -- lighter band across the top with a hairline under it, so the
        -- title and the nav read as chrome rather than as content.
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { red = cal.headerBg.red, green = cal.headerBg.green,
                          blue = cal.headerBg.blue, alpha = cal.alpha },
            roundedRectRadii = { xRadius = R, yRadius = R },
            frame = { x = 0.5, y = 0.5, w = W - 1, h = L.headerH },
        })
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { white = 1, alpha = 0.10 },
            frame = { x = 0, y = L.headerH - 1, w = W, h = 1 },
        })

        local c = os.date("*t", cal.cursor)
        local lastShown = addMonths(cal.cursor, cal.months - 1)
        table.insert(els, {
            type = "text",
            text = MONTHS[c.month] .. " " .. c.year .. "  →  " ..
                   MONTHS[os.date("*t", lastShown).month] .. " " ..
                   os.date("*t", lastShown).year,
            textSize = 20, textAlignment = "left",
            textColor = cal.ink,
            frame = { x = L.pad, y = 16, w = W * 0.6, h = 28 },
        })

        -- ‹ Today › — the mouse alternative to [ ] and T.
        -- The player's buttons: #22242b on a #33353e hairline, radius 6.
        local btnY, btnH = 14, 28
        local buttons = {
            { id = "nav:-1",    label = "‹",     x = W - L.pad - 216, w = 40 },
            { id = "nav:today", label = "Today", x = W - L.pad - 170, w = 90 },
            { id = "nav:1",     label = "›",     x = W - L.pad - 74,  w = 40 },
        }
        for _, b in ipairs(buttons) do
            table.insert(els, {
                type = "rectangle", action = "strokeAndFill",
                fillColor = cal.btnBg,
                strokeColor = cal.btnStroke, strokeWidth = 1,
                roundedRectRadii = { xRadius = 6, yRadius = 6 },
                frame = { x = b.x, y = btnY, w = b.w, h = btnH },
                trackMouseDown = true, id = b.id,
            })
            table.insert(els, {
                type = "text", text = b.label, textSize = 13,
                textAlignment = "center", textColor = cal.ink,
                frame = { x = b.x, y = btnY + 5, w = b.w, h = 22 },
            })
            cal.hitboxes[b.id] = b.id
        end

        -- ---- the readout, ABOVE the months (6.244.0) ---------------------
        -- LL: "The date and time should be above the months, same as
        -- large." Same 34 pt as before — the size was never the problem,
        -- the POSITION and the box around it were.
        -- 🚨 AND ITS HEIGHT IS ITS CONTENT'S. It used to be drawn to
        -- whatever the window had left over, which on a 768-pt panel over
        -- 94 pt of text is 362 pt of empty box — his "large empty space
        -- below the dates", drawn on purpose by arithmetic nobody reread.
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { white = 1, alpha = 0.05 },
            roundedRectRadii = { xRadius = 10, yRadius = 10 },
            frame = { x = L.pad, y = L.readY, w = W - L.pad * 2, h = L.readH },
        })
        table.insert(els, {
            type = "text",
            text = os.date("%A, %d %B %Y", cal.cursor):gsub(" 0", " "),
            textSize = 34, textAlignment = "left",
            textColor = cal.ink,
            frame = { x = L.pad + 18, y = L.readY + 12, w = W - L.pad * 2 - 36, h = 44 },
        })
        -- 🕐 6.147.0 — the time, as big as the date and live to the
        -- second (cal.clock re-renders while the panel is up). Same frame
        -- as the date line, right-aligned, so the row reads date on the
        -- left, NOW on the right.
        table.insert(els, {
            type = "text", text = cal.timeNow(),
            textSize = 34, textAlignment = "right",
            textColor = cal.ink,
            frame = { x = L.pad + 18, y = L.readY + 12, w = W - L.pad * 2 - 36, h = 44 },
        })

        local doy   = tonumber(os.date("%j", cal.cursor))
        local yr    = tonumber(os.date("%Y", cal.cursor))
        local total = tonumber(os.date("%j", noon(yr, 12, 31)))
        table.insert(els, {
            type = "text",
            text = string.format("%s  ·  week %s  ·  day %d of %d  ·  %d left in %d",
                relativeWords(cal.cursor), os.date("%V", cal.cursor),
                doy, total, total - doy, yr),
            textSize = 14, textAlignment = "left",
            textColor = cal.inkDim,
            frame = { x = L.pad + 18, y = L.readY + 58, w = W - L.pad * 2 - 36, h = 22 },
        })

        for i = 1, cal.months do
            drawMonth(els, L, L.pad + (i - 1) * (L.colW + L.gap), L.monthY,
                      addMonths(cal.cursor, i - 1))
        end

        -- 📐 The footer sits under the MONTHS, not against the bottom of
        -- the window. Pinned to the window's own height it floated away from the
        -- calendar by however much slack the panel happened to have — the
        -- second half of "there's a lot of space below the calendar".
        local edgeNote = ""
        if cal.atEdge then
            edgeNote = "   ⛔ that is as far as this goes — ±" .. cal.rangeDays .. " days"
        end
        table.insert(els, {
            type = "text",
            text = "←→ day   ↑↓ week   [ ] month   T today   click or C copies "
                   .. os.date(cal.copyFormat, cal.cursor)
                   .. "   R the Date report   Esc close" .. edgeNote,
            textSize = 13, textAlignment = "left",
            textColor = cal.atEdge and { red = 1, green = 0.72, blue = 0.4 }
                                    or cal.inkFaint,
            frame = { x = L.pad, y = L.footY, w = W - L.pad * 2, h = L.footH },
        })

        local ok, err = pcall(function() cal.canvas:replaceElements(els) end)
        if not ok then print("🗓 Mini calendar: render failed — " .. tostring(err)) end
    end

    -- ---- movement --------------------------------------------------------
    function cal.moveTo(t)
        local clamped, hitEdge = clampToRange(t)
        cal.cursor = clamped
        cal.atEdge = hitEdge
        cal.render()
    end

    function cal.moveDays(n)   cal.moveTo(addDays(cal.cursor, n))   end
    function cal.moveMonths(n) cal.moveTo(addMonths(cal.cursor, n)) end
    function cal.goToday()     cal.moveTo(cal.today)                end

    -- ---- copying a date --------------------------------------------------
    -- Clicking a date puts it on the clipboard in cal.copyFormat and says
    -- what it copied. Returns the string so a test — and any other module,
    -- via the published service — can check it without a clipboard.
    --
    -- The whole point is pasting it somewhere immediately, so the format is
    -- one setting (cal.copyFormat) rather than something spread through the
    -- drawing code. os.date's %m/%d/%y are all zero-padded and 2-digit,
    -- which is what makes "08-07-26" line up in a column.
    function cal.formatDate(t)
        return os.date(cal.copyFormat, t or cal.cursor)
    end

    function cal.copyDate(t)
        t = t or cal.cursor
        local text = cal.formatDate(t)
        local ok = false
        pcall(function() ok = hs.pasteboard.setContents(text) ~= false end)
        if not ok then
            hs.alert.show("🗓 Could not reach the clipboard")
            print("🗓 Mini calendar: hs.pasteboard.setContents failed for " .. text)
            return nil
        end
        -- Named day as well as the digits: the point of copying 08-07-26 is
        -- usually that you are about to commit to it, and "Fri" is the part
        -- worth double-checking before you paste.
        hs.alert.show("🗓 " .. text .. "   (" .. os.date("%a", t) .. ")  copied", 1.6)
        _G.diag.say("calendar", "copied " .. text)
        return text
    end

    -- ---- the Date report (6.147.0) ---------------------------------------
    -- "02:00:00 PM" → "2:00:00 PM". %-I would skip the zero, but the
    -- no-padding flag is a GNU extension BSD strftime does not have (the
    -- menu-bar title below builds %-d by hand for the same reason).
    function cal.timeNow(now)
        return (os.date(cal.timeFormat, now):gsub("^0", ""))
    end

    -- Every format at once, under one heading — so one copy answers
    -- however the receiving field wants its date spelled. The time rides
    -- along at the bottom because the report is a snapshot, and a
    -- snapshot should say when it was taken.
    function cal.buildReport(t, now)
        cal.today = cal.today or todayNoon()
        t = t or cal.cursor or cal.today
        local L = { "Date report: " .. os.date("%A, %B %d, %Y", t):gsub(" 0", " ") }
        for _, fmt in ipairs(cal.reportFormats) do
            L[#L + 1] = "  " .. os.date(fmt, t)
        end
        local doy   = tonumber(os.date("%j", t))
        local yr    = tonumber(os.date("%Y", t))
        local total = tonumber(os.date("%j", noon(yr, 12, 31)))
        L[#L + 1] = "  week " .. os.date("%V", t) .. " · day " .. doy
                    .. " of " .. total .. " · " .. relativeWords(t)
        L[#L + 1] = "  Time now: " .. cal.timeNow(now)
        return table.concat(L, "\n")
    end

    function cal.copyReport(t)
        local text = cal.buildReport(t)
        local ok = false
        pcall(function() ok = hs.pasteboard.setContents(text) ~= false end)
        if not ok then
            hs.alert.show("🗓 Could not reach the clipboard")
            print("🗓 Mini calendar: hs.pasteboard.setContents failed for the report")
            return nil
        end
        hs.alert.show("🗓 Date report copied — every format, time included", 1.8)
        _G.diag.say("calendar", "report copied for "
                    .. os.date("%Y-%m-%d", t or cal.cursor or cal.today))
        return text
    end

    -- ---- show / hide -----------------------------------------------------
    local function frameFor()
        local screen = core.resolveBaseScreen and core.resolveBaseScreen()
                       or hs.screen.mainScreen()
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(cal.width, sf.w - cal.margin * 2)
        local h = math.min(cal.panelHeight(), sf.h - cal.margin * 2)
        if cal.anchor == "center" then
            return { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 2, w = w, h = h }
        end
        -- Under the clock: hard against the right edge, just below the menu
        -- bar. sf (not fullFrame) already excludes the menu bar, so sf.y is
        -- the first pixel a window may use.
        return { x = sf.x + sf.w - w - cal.margin, y = sf.y + cal.margin, w = w, h = h }
    end

    function cal.hide()
        if cal.modal then pcall(function() cal.modal:exit() end) end
        -- 🍅 6.211.0 — the pomodoro card goes back to its own spot FIRST,
        -- while this frame still exists to have been beside.
        pcall(function()
            if _G.service and _G.service.has and _G.service.has("pomodoro.undock") then
                _G.service.call("pomodoro.undock")
            end
        end)
        if cal.clock then
            pcall(function() cal.clock:stop() end)
            cal.clock = nil
        end
        if cal.canvas then
            pcall(function() cal.canvas:delete() end)
            cal.canvas = nil
        end
        -- 6.244.0 — forget what the LAST screen clamped it to, so the next
        -- open works its size out again rather than inheriting a squeeze
        -- from a monitor that is no longer there.
        cal.drawW, cal.drawH = nil, nil
        _G.diag.say("calendar", "closed")
    end

    function cal.show()
        if not cal.enabled then return end
        if cal.canvas then cal.hide() return end

        cal.today  = todayNoon()          -- refreshed on every open, so a
        cal.cursor = cal.cursor or cal.today   -- panel left alone overnight
        cal.atEdge = false                -- comes back on the right day
        if not sameDay(cal.cursor, cal.today) then
            local within = math.abs(cal.cursor - cal.today) <= cal.rangeDays * 86400
            if not within then cal.cursor = cal.today end
        end

        local f = frameFor()
        -- 🗓 6.244.0 — what it GOT, in its own fields. The clamped size
        -- used to be written back over cal.width/cal.height, which meant a
        -- panel the screen had squeezed could never work its height out
        -- again: the knob and the outcome were the same variable.
        cal.drawW, cal.drawH = f.w, f.h
        local okNew, made = pcall(hs.canvas.new, f)
        if not (okNew and made) then
            hs.alert.show("🗓 Mini calendar: couldn't draw — check the Console")
            return
        end
        cal.canvas = made
        -- 6.148.0 — on the coexist ladder: above the cheat sheet, below
        -- the choosers. Bare `overlay` TIED it with the sheet, and a tie
        -- stacks by whichever was shown last.
        pcall(function()
            cal.canvas:level((_G.panelLevel and _G.panelLevel("calendar"))
                             or hs.canvas.windowLevels.overlay)
        end)
        pcall(function()
            cal.canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        -- Clicks are wanted; stealing focus is not.
        pcall(function() cal.canvas:clickActivating(false) end)
        pcall(function()
            cal.canvas:mouseCallback(function(_, event, id)
                if event ~= "mouseDown" then return end
                if id == "nav:-1"    then cal.moveMonths(-1) return end
                if id == "nav:1"     then cal.moveMonths(1)  return end
                if id == "nav:today" then cal.goToday()      return end
                local t = cal.hitboxes[id]
                if type(t) == "number" then
                    -- Select AND copy. moveTo first so the highlight has
                    -- already landed on the date the alert is about to name.
                    cal.moveTo(t)
                    if cal.copyOnClick then cal.copyDate(t) end
                end
            end)
        end)

        cal.render()
        -- See _G.showCanvasSafely in init.lua — a bare :show() can throw
        -- when another app's popup is mid-transition, and then the rest of
        -- this open sequence never runs.
        if _G.showCanvasSafely then _G.showCanvasSafely(cal.canvas, "mini calendar")
        else pcall(function() cal.canvas:show() end) end
        if cal.modal then pcall(function() cal.modal:enter() end) end
        -- 🕐 the live clock: one render a second, ONLY while the panel
        -- is up — hide() stops it, and the timer stops itself if the
        -- canvas vanished some other way. Not eco-registered: it exists
        -- only while a panel you opened is on screen.
        if cal.clock then pcall(function() cal.clock:stop() end) end
        local okTick, tick = pcall(hs.timer.doEvery, 1, function()
            if cal.canvas then
                cal.render()
            elseif cal.clock then
                pcall(function() cal.clock:stop() end)
                cal.clock = nil
            end
        end)
        cal.clock = (okTick and tick) or nil
        -- 🍅 6.211.0 — LL: "include the pomodoro temporarily in the
        -- mini-calendar? Then come back to its own window when the
        -- mini-calendar closes?" The card docks beside this frame; a
        -- pomodoro that is not running answers false and nothing happens.
        pcall(function()
            if _G.service and _G.service.has and _G.service.has("pomodoro.dock") then
                _G.service.call("pomodoro.dock", f)
            end
        end)
        _G.diag.say("calendar", "opened on " .. os.date("%Y-%m-%d", cal.cursor))
    end

    function cal.toggle()
        if cal.canvas then cal.hide() else cal.show() end
    end

    -- ---- the keys, armed only while the panel is up ----------------------
    -- An hs.hotkey.modal owns these keys outright while it is entered, so
    -- they are NOT registered globally and the arrow keys behave normally
    -- the rest of the time.
    local okModal, modal = pcall(hs.hotkey.modal.new)
    if okModal and modal then
        cal.modal = modal
        local bindings = {
            { {}, "left",   function() cal.moveDays(-1) end },
            { {}, "right",  function() cal.moveDays(1)  end },
            { {}, "up",     function() cal.moveDays(-7) end },
            { {}, "down",   function() cal.moveDays(7)  end },
            { {}, "[",      function() cal.moveMonths(-1) end },
            { {}, "]",      function() cal.moveMonths(1)  end },
            { { "shift" }, "left",  function() cal.moveMonths(-1) end },
            { { "shift" }, "right", function() cal.moveMonths(1)  end },
            { {}, "pageup",   function() cal.moveMonths(-1) end },
            { {}, "pagedown", function() cal.moveMonths(1)  end },
            { {}, "home",   function() cal.goToday() end },
            { {}, "t",      function() cal.goToday() end },
            { {}, "c",      function() cal.copyDate() end },
            { {}, "r",      function() cal.copyReport() end },
            { {}, "escape", function() cal.hide() end },
            { {}, "return", function() cal.hide() end },
            { {}, "q",      function() cal.hide() end },
        }
        for _, b in ipairs(bindings) do
            -- The third and fifth arguments are pressed and repeated: holding
            -- → walks forward, which is how you get across a month quickly.
            -- The one-shot keys get NO repeat handler: a held Esc would close
            -- twice, and a held C would refill the clipboard and stack an
            -- alert thirty times a second.
            local noRepeat = { escape = true, ["return"] = true, q = true, c = true,
                               r = true }
            local repeatFn = (not noRepeat[b[2]]) and b[3] or nil
            pcall(function() cal.modal:bind(b[1], b[2], b[3], nil, repeatFn) end)
        end
    else
        print("🗓 Mini calendar: could not create its key modal — arrows will not work")
    end

    core.hyperAddShortcut({ "shift" }, "0", function() cal.toggle() end, "mini calendar")

    -- Published so anything else can ask for a formatted date without
    -- opening the panel:  _G.service.call("calendar.format", os.time())
    core.provide("calendar.format", function(t) return cal.formatDate(t) end)
    core.provide("calendar.copyToday", function() return cal.copyDate(todayNoon()) end)
    core.provide("calendar.report", function(t) return cal.copyReport(t) end)
    -- 🍅 6.211.0 — the panel's frame while it is up, nil otherwise, so a
    -- pomodoro STARTED under an open calendar can dock at once.
    core.provide("calendar.frame", function()
        if not cal.canvas then return nil end
        local fr
        pcall(function() fr = cal.canvas:frame() end)
        return fr
    end)

    -- ⎋ 6.78.0 — CLAIMED, so the cheat sheet knows the calendar is up.
    -- The panel's own Esc is a MODAL binding and the sheet's is a plain
    -- hotkey; both are Carbon, so which one won was decided by enable
    -- order — an implementation detail, which is why LL saw the sheet
    -- close instead of the calendar. Priority comes from coexist's one
    -- table. See core/coexist.lua.
    if _G.claimEscape then
        _G.claimEscape("calendar", nil,
            function() return cal.canvas ~= nil end,
            function() cal.hide() end)
    end

    -- 6.89.0 — listed for Window Move: ⌘-drag moves the calendar. ⌘ is
    -- required here because bare clicks belong to the panel's own buttons.
    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "mini calendar",
        frame = function() return cal.canvas and cal.canvas:frame() end,
        move  = function(x, y)
            if cal.canvas then cal.canvas:topLeft({ x = x, y = y }) end
        end,
    })

    _G.miniCalendar = cal
    M.cal    = cal
    M.config = cal
end

-- The menu-bar item is built in warm() rather than setup(): it is the one
-- part of this module that touches the system UI, and boot is not the
-- place for that. Everything above works whether or not this succeeds.
function M.warm(core)
    local cal = M.cal
    if not cal or not cal.menuBar then return end

    local function title()
        -- "%-d" (no leading zero) is a GNU extension that BSD date, and
        -- therefore macOS, does not have. Build it instead of hoping.
        local d = os.date("*t")
        return os.date("%a", os.time(d)) .. " " .. tostring(d.day)
    end

    local okNew, item = pcall(hs.menubar.new)
    if not (okNew and item) then
        print("🗓 Mini calendar: no menu-bar slot available")
        return
    end
    cal.menu = item                 -- HELD: a collected menubar item disappears
    pcall(function() cal.menu:setTitle(title()) end)
    pcall(function() cal.menu:setTooltip("Click for a three-month calendar (⇪⇧0)") end)
    pcall(function() cal.menu:setClickCallback(function() cal.toggle() end) end)

    -- Re-title every 60s. Checked against the day rather than blindly set,
    -- so this is a string compare 1439 times a day and a redraw once.
    cal.tick = hs.timer.doEvery(60, function()
        local t = title()
        if t ~= cal.menuTitle then
            cal.menuTitle = t
            pcall(function() cal.menu:setTitle(t) end)
        end
    end)
    cal.menuTitle = title()
    _G.diag.say("calendar", "menu-bar item added: " .. cal.menuTitle)
end

return M
