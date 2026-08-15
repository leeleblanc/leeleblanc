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
    cal.height      = 768
    cal.months      = 3         -- panels across. 3 fits 1024 comfortably.
    cal.dayTextSize = 16        -- the date numbers, as asked
    cal.alpha       = 0.90      -- translucent BLACK, not grey (see bg below)
    cal.bg          = { red = 0.02, green = 0.02, blue = 0.035 }
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
    -- ----------------------------------------------------------------------

    cal.canvas = nil    -- HELD. A collected canvas takes the panel with it.
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
    -- Worked out once per draw from cal.width/cal.height so changing the
    -- panel size in the settings above does not need any other edit.
    local function layout()
        local L = {}
        L.pad      = 26
        L.headerH  = 74
        L.gap      = 22
        L.colW     = (cal.width - L.pad * 2 - L.gap * (cal.months - 1)) / cal.months
        L.cellW    = math.floor((L.colW - 8) / 7)
        L.cellH    = 36
        L.titleH   = 32
        L.dowH     = 22
        L.monthH   = L.titleH + L.dowH + 6 * L.cellH
        L.monthY   = L.headerH + 10
        L.footY    = L.monthY + L.monthH + 26
        return L
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
            textColor = { white = 0.98 },
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
                        fillColor = { red = 0.30, green = 0.55, blue = 0.95, alpha = 0.16 },
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
                    fillColor = { red = 0.32, green = 0.58, blue = 0.98, alpha = 0.85 },
                    roundedRectRadii = { xRadius = 7, yRadius = 7 },
                    frame = { x = cx + 2, y = cy + 2, w = L.cellW - 4, h = L.cellH - 4 },
                })
            elseif isToday then
                table.insert(els, {
                    type = "rectangle", action = "stroke",
                    strokeColor = { red = 0.45, green = 0.72, blue = 1.0, alpha = 0.95 },
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

        table.insert(els, {
            type = "rectangle", action = "strokeAndFill",
            fillColor = { red = cal.bg.red, green = cal.bg.green,
                          blue = cal.bg.blue, alpha = cal.alpha },
            strokeColor = { white = 1, alpha = 0.16 }, strokeWidth = 1,
            roundedRectRadii = { xRadius = 16, yRadius = 16 },
            frame = { x = 0.5, y = 0.5, w = cal.width - 1, h = cal.height - 1 },
        })

        local c = os.date("*t", cal.cursor)
        local lastShown = addMonths(cal.cursor, cal.months - 1)
        table.insert(els, {
            type = "text",
            text = MONTHS[c.month] .. " " .. c.year .. "  →  " ..
                   MONTHS[os.date("*t", lastShown).month] .. " " ..
                   os.date("*t", lastShown).year,
            textSize = 24, textAlignment = "left", textColor = { white = 0.97 },
            frame = { x = L.pad + 4, y = 22, w = cal.width * 0.6, h = 34 },
        })

        -- ‹ Today › — the mouse alternative to [ ] and T.
        local btnY, btnH = 24, 30
        local buttons = {
            { id = "nav:-1",    label = "‹",     x = cal.width - L.pad - 236, w = 44 },
            { id = "nav:today", label = "Today", x = cal.width - L.pad - 184, w = 96 },
            { id = "nav:1",     label = "›",     x = cal.width - L.pad - 80,  w = 44 },
        }
        for _, b in ipairs(buttons) do
            table.insert(els, {
                type = "rectangle", action = "strokeAndFill",
                fillColor = { white = 1, alpha = 0.08 },
                strokeColor = { white = 1, alpha = 0.16 }, strokeWidth = 1,
                roundedRectRadii = { xRadius = 8, yRadius = 8 },
                frame = { x = b.x, y = btnY, w = b.w, h = btnH },
                trackMouseDown = true, id = b.id,
            })
            table.insert(els, {
                type = "text", text = b.label, textSize = 14,
                textAlignment = "center", textColor = { white = 0.92 },
                frame = { x = b.x, y = btnY + 6, w = b.w, h = 22 },
            })
            cal.hitboxes[b.id] = b.id
        end

        for i = 1, cal.months do
            drawMonth(els, L, L.pad + (i - 1) * (L.colW + L.gap), L.monthY,
                      addMonths(cal.cursor, i - 1))
        end

        -- ---- the readout under the months --------------------------------
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { white = 1, alpha = 0.05 },
            roundedRectRadii = { xRadius = 12, yRadius = 12 },
            frame = { x = L.pad, y = L.footY, w = cal.width - L.pad * 2,
                      h = cal.height - L.footY - L.pad },
        })
        table.insert(els, {
            type = "text",
            text = os.date("%A, %d %B %Y", cal.cursor):gsub(" 0", " "),
            textSize = 34, textAlignment = "left", textColor = { white = 0.98 },
            frame = { x = L.pad + 22, y = L.footY + 20, w = cal.width - L.pad * 2 - 44, h = 46 },
        })

        local doy   = tonumber(os.date("%j", cal.cursor))
        local yr    = tonumber(os.date("%Y", cal.cursor))
        local total = tonumber(os.date("%j", noon(yr, 12, 31)))
        table.insert(els, {
            type = "text",
            text = string.format("%s  ·  week %s  ·  day %d of %d  ·  %d left in %d",
                relativeWords(cal.cursor), os.date("%V", cal.cursor),
                doy, total, total - doy, yr),
            textSize = 15, textAlignment = "left", textColor = { white = 0.62 },
            frame = { x = L.pad + 22, y = L.footY + 70, w = cal.width - L.pad * 2 - 44, h = 24 },
        })

        local edgeNote = ""
        if cal.atEdge then
            edgeNote = "   ⛔ that is as far as this goes — ±" .. cal.rangeDays .. " days"
        end
        table.insert(els, {
            type = "text",
            text = "←→ day   ↑↓ week   [ ] month   T today   click or C copies "
                   .. os.date(cal.copyFormat, cal.cursor) .. "   Esc close" .. edgeNote,
            textSize = 13, textAlignment = "left",
            textColor = cal.atEdge and { red = 1, green = 0.72, blue = 0.4 }
                                    or { white = 0.42 },
            frame = { x = L.pad + 22, y = cal.height - L.pad - 30,
                      w = cal.width - L.pad * 2 - 44, h = 22 },
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

    -- ---- show / hide -----------------------------------------------------
    local function frameFor()
        local screen = core.resolveBaseScreen and core.resolveBaseScreen()
                       or hs.screen.mainScreen()
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(cal.width, sf.w - cal.margin * 2)
        local h = math.min(cal.height, sf.h - cal.margin * 2)
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
        if cal.canvas then
            pcall(function() cal.canvas:delete() end)
            cal.canvas = nil
        end
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
        cal.width, cal.height = f.w, f.h
        local okNew, made = pcall(hs.canvas.new, f)
        if not (okNew and made) then
            hs.alert.show("🗓 Mini calendar: couldn't draw — check the Console")
            return
        end
        cal.canvas = made
        pcall(function() cal.canvas:level(hs.canvas.windowLevels.overlay) end)
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
            local noRepeat = { escape = true, ["return"] = true, q = true, c = true }
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
