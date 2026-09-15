-- =====================================================================
-- MODULE: DAILY ROLLUP — one card at 16:01, over the stores that already
-- exist
-- =====================================================================
-- 📊 WHAT IT IS. At 16:01 a card appears in the corner with the day on
-- it: how long the Mac was in use and where, which documents you were
-- actually in, and what you captured to the note pad. It fades by
-- itself. Click it to dismiss it early. It never takes the keyboard.
--
-- 🚨 IT STORES NOTHING. Not one byte is written by this module and no
-- new file is created. Every number on the card is read, at the moment
-- of drawing, from a store another module already keeps:
--
--     activity.dayTotals   ← activity_tracker's sessions (activity_history)
--     activity.docs        ← the same sessions, grouped by document
--     notes.today          ← note_pad's notes.csv
--
-- That is the whole design. A rollup that kept its own daily totals
-- would be a fourth thing that can disagree with the other three, and
-- this config has already retired one module for exactly that (the
-- Document Watcher, 6.104.0). Derived, not duplicated.
--
-- 🚨 IT REPLACED A POPUP RATHER THAN ADDING ONE. Until 6.105.0 the
-- activity tracker opened a chooser at 16:00 and the Quick Append Pad
-- opened its review at 16:01 — two panels, a minute apart, both taking
-- the keyboard, both arriving mid-sentence. The 16:00 chooser is now off
-- (activity_tracker still has the flag, and ⇪0 and the 🔧 rows still
-- reach the full report). What is left is one card that cannot interrupt
-- typing, and the pad review, which is the one of the two you act on.
--
-- 🚨 AND IT STAYS AWAY ON AN EMPTY DAY. If every section comes back
-- empty — a weekend, a day off, a Mac that was asleep — the timer draws
-- nothing at all. A card that says "nothing to report" is a card you
-- learn to dismiss without reading, and then you dismiss the one that
-- mattered too. On demand it always draws, and says plainly that the day
-- is empty.
--
-- WHERE THE SECTIONS COME FROM. Each one asks the service registry
-- whether its provider exists before calling it, and a section whose
-- store is missing is left off the card WITH A LINE SAYING SO rather
-- than silently reported as zero. "You did no work today" and "the
-- module that counts your work did not load" must never look the same.
--
--   _G.rollup()        show it now
--   _G.rollup(true)    show it now and print the same thing to the Console

local M = {
    name  = "Daily Rollup",
    order = 13.95,      -- 13.9 is the Menu Bar Items module; ties make the
                        -- sheet's running order depend on table iteration
    family = "time",
    summary = "One card at 16:01 — the day's time, documents and notes",
    cheatsheet = {
        title = "📊 DAILY ROLLUP (one card at 16:01 — no key, no store)",
        entries = {
            { "16:01",   "A card in the corner: time, documents, notes" },
            -- 🚨 THE 📊 KEY IS LOAD-BEARING. unified_search's run map has
            -- an entry keyed "📊" so ⇪space can open this on demand, and
            -- it verifies at boot that a cheat sheet row uses that exact
            -- key — a run map pointing at a key nothing draws is a row
            -- that silently never fires (⇪pad+ sat like that for three
            -- versions). Rename this and the tool row dies with it.
            { "📊",      "Show today's card now — ⇪space, then @tool" },
            { "fades",   "Goes by itself after 25s · click it to dismiss" },
            { "quiet",   "Takes no keyboard focus · silent on an empty day" },
            { "console", "_G.rollup() any time · _G.rollup(true) also prints" },
            { "derived", "Reads the tracker and the pad — stores nothing itself" },
            { "was",     "Replaces the 16:00 activity popup, which is now off" },
        },
    },
}

function M.setup(core)
    local roll = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    roll.enabled       = true
    roll.at            = "16:01"   -- same minute as the pad review, on purpose
    roll.holdSecs      = 25        -- how long the card stays before fading
    roll.anchor        = "topRight"
    roll.offsetX       = 16
    roll.offsetY       = 44
    roll.width         = 430
    roll.fontName      = "Menlo"
    roll.fontSize      = 12
    roll.padding       = 14
    roll.maxApps       = 5
    roll.maxDocs       = 5
    roll.maxNoteChars  = 46
    roll.skipWhenEmpty = true      -- see the 🚨 above
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("rollup", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("rollup", m) end end

    local function style()
        local s = _G.uiStyle
        return {
            bg     = (s and s.bg)     or { red = 0.09, green = 0.10, blue = 0.13, alpha = 0.92 },
            fg     = (s and s.fg)     or { white = 1.00, alpha = 0.97 },
            stroke = (s and s.stroke) or { white = 1.00, alpha = 0.18 },
            radius = (s and s.radius) or 12,
        }
    end

    -- has() before call(), every time. A service that is not there is a
    -- module that did not load, and that is a different fact from zero.
    local function ask(name, ...)
        if not (_G.service and _G.service.has and _G.service.has(name)) then
            return nil, "no provider"
        end
        local ok, res = pcall(_G.service.call, name, ...)
        if not ok then return nil, tostring(res) end
        return res
    end

    local function mins(seconds)
        seconds = tonumber(seconds) or 0
        if core and core.formatDuration then
            local ok, s = pcall(core.formatDuration, math.floor(seconds))
            if ok and s then return s end
        end
        local m = math.floor(seconds / 60 + 0.5)
        if m < 60 then return m .. "m" end
        return math.floor(m / 60) .. "h " .. (m % 60) .. "m"
    end

    local function clip(s, n)
        s = tostring(s or ""):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
        if #s <= n then return s end
        return s:sub(1, n - 1) .. "…"
    end

    -- ---- the sections ----------------------------------------------------
    -- Each returns { title, lines, empty }. `empty` is what decides the
    -- skip-an-empty-day rule, and a section that could not ask its store
    -- is NOT empty — it has something to say.
    local function sectionTime(today)
        local d, why = ask("activity.dayTotals", today)
        if not d then
            return { title = "⏱  TIME", empty = false,
                     lines = { "   the activity tracker is not answering ("
                               .. tostring(why) .. ")" } }
        end
        if (tonumber(d.total) or 0) <= 0 then
            return { title = "⏱  TIME", empty = true,
                     lines = { "   nothing tracked yet today" } }
        end
        local lines = { "   " .. mins(d.total) .. " tracked" }
        for i, a in ipairs(d.apps or {}) do
            if i > roll.maxApps then break end
            lines[#lines + 1] = string.format("     %-26s %s",
                                              clip(a.name, 26), mins(a.seconds))
        end
        return { title = "⏱  TIME", lines = lines, empty = false }
    end

    local function sectionDocs(today)
        local rows, why = ask("activity.docs")
        if not rows then
            return { title = "📄 DOCUMENTS", empty = false,
                     lines = { "   the document list is not answering ("
                               .. tostring(why) .. ")" } }
        end
        -- docRows() is every day, newest first. Today's are the ones that
        -- belong on a card about today.
        local mine = {}
        for _, r in ipairs(rows) do
            if r.date == today then mine[#mine + 1] = r end
        end
        if #mine == 0 then
            return { title = "📄 DOCUMENTS", empty = true,
                     lines = { "   none opened today" } }
        end
        local lines = {}
        for i, r in ipairs(mine) do
            if i > roll.maxDocs then
                lines[#lines + 1] = string.format("     … and %d more (⇪⇧W)",
                                                  #mine - roll.maxDocs)
                break
            end
            lines[#lines + 1] = string.format("     %-26s %s",
                                              clip(r.file, 26), mins(r.secs))
        end
        return { title = "📄 DOCUMENTS", lines = lines, empty = false }
    end

    local function sectionNotes()
        local rows, why = ask("notes.today")
        if not rows then
            return { title = "🗒  CAPTURED", empty = false,
                     lines = { "   the note pad is not answering ("
                               .. tostring(why) .. ")" } }
        end
        if #rows == 0 then
            return { title = "🗒  CAPTURED", empty = true,
                     lines = { "   nothing captured today" } }
        end
        local byKind, order = {}, {}
        for _, r in ipairs(rows) do
            local k = r.kind ~= "" and r.kind or "Logs"
            if not byKind[k] then byKind[k] = 0 order[#order + 1] = k end
            byKind[k] = byKind[k] + 1
        end
        table.sort(order)
        local counts = {}
        for _, k in ipairs(order) do
            counts[#counts + 1] = byKind[k] .. " " .. k
        end
        local lines = { "   " .. table.concat(counts, " · ") }
        -- The last thing you wrote, because that is the one you are most
        -- likely to still be deciding what to do with.
        local last = rows[#rows]
        if last and last.text and last.text ~= "" then
            lines[#lines + 1] = "     ↳ " .. clip(last.text, roll.maxNoteChars)
        end
        return { title = "🗒  CAPTURED", lines = lines, empty = false }
    end

    function roll.gather(today)
        today = today or os.date("%Y-%m-%d")
        local secs = { sectionTime(today), sectionDocs(today), sectionNotes() }
        local anything = false
        for _, s in ipairs(secs) do
            if not s.empty then anything = true end
        end
        return secs, anything, today
    end

    function roll.text(today)
        local secs, anything, day = roll.gather(today)
        local out = { "📊  " .. os.date("%A %d %B", os.time()) .. "   ·   " .. day }
        if not anything then
            out[#out + 1] = ""
            out[#out + 1] = "   A quiet one — nothing tracked, opened or captured."
            return table.concat(out, "\n"), false
        end
        for _, s in ipairs(secs) do
            out[#out + 1] = ""
            out[#out + 1] = s.title
            for _, l in ipairs(s.lines) do out[#out + 1] = l end
        end
        out[#out + 1] = ""
        out[#out + 1] = "   ⇪0 full report · ⇪⇧W documents · ⇪pad2 the pad"
        return table.concat(out, "\n"), true
    end

    -- ---- the card --------------------------------------------------------
    function roll.hide()
        -- 🚨 THE FADE TIMER IS CANCELLED HERE TOO. Without this, showing
        -- the card twice inside holdSecs leaves the first timer running,
        -- and it hides the SECOND card early — a card that vanishes after
        -- four seconds with no explanation.
        if roll.hideTimer then
            pcall(function() roll.hideTimer:stop() end)
            roll.hideTimer = nil
        end
        if roll.card then
            pcall(function() roll.card:delete() end)
            roll.card = nil
        end
    end

    local function frameFor(w, h)
        local scr = hs.screen.primaryScreen and hs.screen.primaryScreen()
        local f
        pcall(function() f = scr and scr:frame() end)
        f = f or { x = 0, y = 0, w = 1440, h = 900 }
        local a = roll.anchor
        local x = (a == "topLeft" or a == "bottomLeft")
                  and (f.x + roll.offsetX) or (f.x + f.w - w - roll.offsetX)
        local y = (a == "bottomLeft" or a == "bottomRight")
                  and (f.y + f.h - h - roll.offsetY) or (f.y + roll.offsetY)
        return { x = x, y = y, w = w, h = h }
    end

    function roll.show(alsoPrint, today)
        if not roll.enabled then return false end
        local text = roll.text(today)
        if alsoPrint then print("\n" .. text .. "\n") end

        roll.hide()
        local st = style()
        local c
        local okNew = pcall(function()
            c = hs.canvas.new({ x = 0, y = 0, w = roll.width, h = 200 })
        end)
        if not (okNew and c) then
            warn("hs.canvas.new failed — the rollup could not be drawn")
            -- Not silent: the numbers still exist, so say them somewhere.
            print("\n" .. text .. "\n")
            return false
        end

        c[1] = {
            type             = "rectangle",
            action           = "strokeAndFill",
            fillColor        = st.bg,
            strokeColor      = st.stroke,
            strokeWidth      = 1,
            roundedRectRadii = { xRadius = st.radius, yRadius = st.radius },
        }
        c[2] = {
            type      = "text",
            text      = text,
            textFont  = roll.fontName,
            textSize  = roll.fontSize,
            textColor = st.fg,
            frame     = { x = 0, y = 0, w = roll.width, h = 200 },
        }

        local h = 200
        pcall(function()
            local size = c:minimumTextSize(2, text)
            if size and size.h then h = math.ceil(size.h) + roll.padding * 2 end
        end)
        pcall(function()
            c:frame(frameFor(roll.width, h))
            c[2].frame = { x = roll.padding, y = roll.padding,
                           w = roll.width - roll.padding * 2,
                           h = h - roll.padding * 2 }
            -- 6.148.0 — the coexist ladder, not a bare "overlay" that
            -- tied with the cheat sheet
            c:level((_G.panelLevel and _G.panelLevel("rollup")) or "overlay")
            -- 🚨 NO FOCUS, EVER. clickActivating(false) is the whole reason
            -- this is a canvas and not a chooser: the card can appear while
            -- you are typing a sentence and the sentence keeps going into
            -- the app you were typing it in.
            c:clickActivating(false)
            c:canvasMouseEvents(true, false, false, false)
            c:mouseCallback(function() roll.hide() end)
        end)

        roll.card = c
        if _G.showCanvasSafely then
            _G.showCanvasSafely(c, "daily rollup")
        else
            pcall(function() c:show() end)
        end

        -- HELD in roll.hideTimer. An unreferenced hs.timer is collected,
        -- and a collected timer never fires — which here means a card that
        -- stays on the screen until the next reload.
        if roll.holdSecs and roll.holdSecs > 0 then
            local okT, t = pcall(hs.timer.doAfter, roll.holdSecs,
                                 function() pcall(roll.hide) end)
            roll.hideTimer = okT and t or nil
        end
        return true
    end

    -- ---- the daily fire --------------------------------------------------
    function roll.fire()
        local _, anything = roll.gather()
        if roll.skipWhenEmpty and not anything then
            say("16:01 — nothing to report, no card drawn")
            return false
        end
        return roll.show(false)
    end

    if roll.enabled then
        -- HELD in _G, like every other doAt in this config, for the same
        -- reason: a collected timer is a feature that silently stops.
        local okT, t = pcall(hs.timer.doAt, roll.at, "1d", function()
            pcall(roll.fire)
        end)
        if okT and t then
            _G.dailyRollupTimer = t
            say("armed for " .. roll.at)
        else
            warn("could not arm the " .. tostring(roll.at) .. " rollup: "
                 .. tostring(t))
            if _G.notices then
                _G.notices.record("rollup", "daily card not armed", tostring(t))
            end
        end
    end

    _G.rollup = function(alsoPrint) return roll.show(alsoPrint) end
    core.provide("rollup.show", function() return roll.show(false) end)
    core.provide("rollup.text", function(day) return roll.text(day) end)

    _G.dailyRollup = roll
    M.config = roll
end

return M
