-- ⚠️ ONE TABLE, NOT NINE LOCALS. The main chunk of this file sits ON
-- Lua's hard ceiling of 200 locals — measured, not estimated — and the
-- main chunk IS a function, so every top-level `local` counts. Going one
-- over is a COMPILE error and the WHOLE config fails to load, not just
-- the section that added it. Everything §1.6 needs therefore hangs off
-- one table. Do the same in any new section.
local cheatSheet = {}
cheatSheet.key       = "/"   -- toggle key; same mods as everything above
cheatSheet.addKey    = "="   -- add-a-custom-entry key ("+" without shift)

cheatSheet.customFile = logsDir .. "/custom_shortcuts.json"
adoptLegacyFile(cheatSheet.customFile, hs.configdir .. "/custom_shortcuts.json")

function cheatSheet.loadCustom()
    local f = io.open(cheatSheet.customFile, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local ok, data = pcall(hs.json.decode, content)
    if ok and type(data) == "table" then return data end
    return {}
end

function cheatSheet.saveCustom(list)
    local f = io.open(cheatSheet.customFile, "w")
    if f then f:write(hs.json.encode(list)); f:close()
    else warnWriteFailed("custom_shortcuts.json") end
end

_G.customShortcuts = cheatSheet.loadCustom()

-- Built-ins + custom entries, as ordered groups of {keys, description}.
function cheatSheet.groups()
    local groups = {
        { title = "✅ ASANA — TASKS & DASHBOARD", order = 2, entries = {
            { "⇪A", "Format Asana URL from clipboard" },
            { "⇪B", "Browse Asana Teams — Enter copies a name for Assignee" },
            { "⇪C", "Comment on a task" },
            { "⇪T", "Create a task — type in the Assignee field for inline suggestions" },
            { "⇪L", "List tasks — Today / Week / Overdue" },
            { "auto", "Color legend strip under the list" },
        }},
        { title = "📋 CLIPBOARD & OCR", order = 3, entries = {
            { "⇪V", "Clipboard history" },
            { "⇪⇧V", "Edit or delete a clipboard entry" },
            { "⇪O", "OCR text search" },
            { "⇪⇧O", "Edit or delete an OCR entry" },
            { "⌘C files", "OCR image files → Finder comment tag" },
            { "⇪⇧C", "Toggle copy-on-select (off by default)" },
        }},
        { title = "🕹 POPUP POSITION", order = 5, entries = {
            { "⇪⇧ ↑↓←→", "Nudge popup (hold to repeat)" },
            { "⇪⇧R", "Reset nudge offset" },
        }},
        { title = "⌨️ ⇪ = CAPS LOCK (hold it, tap a key)", order = 14, entries = {
            { "⇪ + key", "Every shortcut on this sheet — hold Caps Lock" },
            { "⇪⇧ + key", "The few second-level ones (edit/delete, nudging)" },
            { "unassigned key", "Sends ⌘⇧⌃⌥+that key to the front app" },
            { "so: Raycast etc.", "Bind them to ⌘⇧⌃⌥ and ⇪ drives them too" },
            { "Caps Lock alone", "No longer toggles capitals (§3.12 reverts)" },
            { "F1–F12", "Not forwarded — macOS reserves some (see 6.18.1)" },
        }},
        { title = "❓ HELP", order = 16, entries = {
            { "⇪/", "Toggle this cheat sheet" },
            { "↑ ↓", "Scroll it a row at a time — hold to keep going" },
            { "PgUp / PgDn", "Scroll a screenful  ·  Home / End jump to the ends" },
            { "scroll wheel", "Scrolls it too, while the pointer is over the sheet" },
            { "⇪=", "Add your own entry to this sheet" },
            { "⇪E", "Edit a custom entry (picker)" },
            { "⇪-", "Remove a custom entry (picker)" },
            { "⇪⇧D", "Diagnostic report — Console + clipboard + Logs file" },
            { "Esc", "Closes this sheet — a click does not" },
        }},
    }

    -- 6.36.0 — GROUPS COME FROM MODULES TOO. A section that has moved
    -- into its own file registers its cheat sheet group when it loads
    -- (§1.12), so this sheet is ASSEMBLED rather than hard-coded.
    -- Delete a module file and its group disappears with it, instead of
    -- the sheet advertising a shortcut that nothing binds any more —
    -- exactly the drift the "hand-written snapshot" warning at the top
    -- of this section has been apologising for since 6.10.
    for _, g in ipairs(_G.moduleCheatsheets or {}) do
        table.insert(groups, { title = g.title, entries = g.entries, order = g.order })
    end

    -- A module that FAILED to load is announced AT THE TOP, not quietly
    -- omitted. A feature that vanishes without explanation is the worst
    -- of both worlds: you reach for the shortcut, nothing happens, and
    -- nothing anywhere tells you why.
    local broken = {}
    for _, rec in ipairs(_G.moduleStatus or {}) do
        if not rec.ok then
            table.insert(broken, { rec.name, tostring(rec.err):sub(1, 64) })
        end
    end
    if #broken > 0 then
        table.insert(groups, { title = "⚠️ MODULES THAT FAILED TO LOAD (⇪⇧D for detail)",
                               entries = broken, order = 0 })
    end

    -- User-added entries, grouped by their group name (default CUSTOM),
    -- in the order groups were first used. They sort last.
    local custOrder, byGroup = {}, {}
    for _, c in ipairs(_G.customShortcuts) do
        local g = (type(c.group) == "string" and c.group ~= "" and c.group or "CUSTOM"):upper()
        if not byGroup[g] then byGroup[g] = {}; table.insert(custOrder, g) end
        table.insert(byGroup[g], { tostring(c.keys or "?"), tostring(c.desc or "") })
    end
    for i, g in ipairs(custOrder) do
        table.insert(groups, { title = "⭐ " .. g, entries = byGroup[g], order = 900 + i })
    end

    -- Assemble. Every group carries a UNIQUE order number, which matters
    -- because table.sort in Lua is NOT stable — equal keys could shuffle
    -- between reloads and the sheet would quietly reorder itself.
    table.sort(groups, function(a, b) return (a.order or 500) < (b.order or 500) end)
    return groups
end

-- ONE NAMESPACE INSTEAD OF NINE TOP-LEVEL LOCALS. This file sits close
-- to Lua's hard ceiling of 200 locals per chunk — and the main chunk IS
-- a function, so every top-level `local` counts against it. Adding the
-- scroll machinery as loose locals went straight past the limit, which
-- is a COMPILE error ("too many local variables"): the entire config
-- would have failed to load, not just the cheat sheet. Fields on one
-- table cost exactly one local no matter how many get added later.

-- ✏️ SEE-THROUGH, this panel only (§1.5's panelAlpha covers the other
-- canvas panels). 1.0 = solid, lower = more see-through. 0.75 shows the
-- window behind the sheet clearly while white text on the near-black
-- panel still reads at roughly 8:1 contrast. Below ~0.6 the shortcuts
-- start losing the fight against a bright background.
cheatSheet.alpha = 0.75

-- ---- The sheet: one tall column you scroll -------------------------
-- 6.32.0 — the sheet used to fill a column, then start ANOTHER column
-- to the right, so on a long list it grew sideways into a wall of text.
-- It is now a single column that grows DOWNWARD and scrolls.
--
-- hs.canvas has no scroll view: a canvas clips to its frame but has no
-- viewport, so "scrolling" here means painting a DIFFERENT WINDOW OF
-- ROWS. That is why layout and render are separate below —
-- cheatSheet.show() works out the rows and the panel once, and
-- cheatSheet.render() paints only the rows currently in view (~30 canvas
-- elements no matter how long the list gets). Scrolling changes one
-- number and repaints, so a fast trackpad flick can't get expensive.
--
-- EVERY ROW IS THE SAME HEIGHT, headers included (blank spacer rows do
-- the separating instead of a variable gap). That is a deliberate
-- constraint, not a simplification: it means the view is always a whole
-- number of rows, so no row is ever half-drawn at the top or bottom
-- edge, and the scroll maths is exact rather than approximate.
--
-- THREE ways to close it, unchanged: ⇪/ again, Esc, or the panic route
-- of reloading. A CLICK STILL DOES NOT CLOSE IT (6.31.0) and mouse
-- events stay off, so clicks pass through to whatever is underneath.
--
-- ⚠️ While the sheet is up it claims Esc, the arrows, PgUp/PgDn and
-- Home/End GLOBALLY — it takes no keyboard focus, so that is the only
-- way it can hear them. Close the sheet and every one of those keys
-- goes straight back to the app underneath. The wheel is different: it
-- is only claimed while the pointer is actually over the panel.
_G.cheatSheetCanvas     = nil   -- the panel itself, while it is up
_G.cheatSheetState      = nil   -- layout + scroll position for that panel
_G.cheatSheetEscHotkey  = nil   -- Esc closes         (enabled only while up)
_G.cheatSheetScrollKeys = nil   -- ↑↓ PgUp/PgDn Home/End    (same)
_G.cheatSheetWheelTap   = nil   -- trackpad / mouse wheel    (same)

function cheatSheet.hide()
    if _G.cheatSheetEscHotkey then
        pcall(function() _G.cheatSheetEscHotkey:disable() end)
    end
    for _, hk in ipairs(_G.cheatSheetScrollKeys or {}) do
        pcall(function() hk:disable() end)
    end
    if _G.cheatSheetWheelTap then
        pcall(function() _G.cheatSheetWheelTap:stop() end)
    end
    if _G.cheatSheetCanvas then
        pcall(function() _G.cheatSheetCanvas:delete() end)
        _G.cheatSheetCanvas = nil
    end
    _G.cheatSheetState = nil
end

-- Paint the rows currently in view. Safe to call any time: with no
-- sheet up it does nothing.
function cheatSheet.render()
    local st, canvas = _G.cheatSheetState, _G.cheatSheetCanvas
    if not (st and canvas) then return end

    local els = {}

    -- The panel. Near-black rather than grey ON PURPOSE: at the same
    -- alpha a darker panel keeps white text readable over a bright
    -- window behind it, which is the whole trade being made here.
    -- Tune the see-through with cheatSheet.alpha at the top of §1.6.
    table.insert(els, {
        type = "rectangle", action = "strokeAndFill",
        fillColor   = { red = 0.06, green = 0.06, blue = 0.08, alpha = cheatSheet.alpha },
        strokeColor = { white = 1, alpha = 0.22 },
        strokeWidth = 1,
        roundedRectRadii = { xRadius = 16, yRadius = 16 },
    })

    table.insert(els, {
        type = "text", text = "⌨️  Hammerspoon Shortcuts",
        textSize = st.titleSize, textColor = { white = 1 }, textAlignment = "center",
        frame = { x = 0, y = st.pad * 0.55, w = st.panelW, h = st.titleH },
    })

    local last = math.min(#st.lines, st.first + st.visible - 1)
    local y = st.contentTop
    for i = st.first, last do
        local line = st.lines[i]
        if line.kind == "header" then
            table.insert(els, {
                type = "text", text = line.text,
                textSize = st.headerSize,
                textColor = { red = 0.55, green = 0.83, blue = 1.0 },
                frame = { x = st.contentX, y = y, w = st.contentW, h = st.lineH },
            })
        elseif line.kind == "entry" then
            table.insert(els, {
                type = "text", text = line.text,
                textSize = st.entrySize, textColor = { white = 1.0 },
                frame = { x = st.contentX, y = y, w = st.contentW, h = st.lineH },
            })
        end   -- a "spacer" row draws nothing; it just holds the gap open
        y = y + st.lineH
    end

    -- Scrollbar, only when there is actually something to scroll. It is
    -- the only thing telling you more text exists below the fold, so it
    -- is drawn even though nothing can drag it.
    if st.maxFirst > 1 then
        local trackY, trackH = st.contentTop, st.visible * st.lineH
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { white = 1, alpha = 0.10 },
            roundedRectRadii = { xRadius = 3, yRadius = 3 },
            frame = { x = st.sbX, y = trackY, w = st.sbW, h = trackH },
        })
        local thumbH = math.max(30, trackH * (st.visible / #st.lines))
        local thumbY = trackY + (trackH - thumbH) * ((st.first - 1) / (st.maxFirst - 1))
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { white = 1, alpha = 0.50 },
            roundedRectRadii = { xRadius = 3, yRadius = 3 },
            frame = { x = st.sbX, y = thumbY, w = st.sbW, h = thumbH },
        })
    end

    local footer
    if st.maxFirst > 1 then
        footer = string.format(
            "%d–%d of %d   ·   ↑↓ PgUp/PgDn or scroll   ·   Esc or ⇪/ closes   ·   ⇪= adds",
            st.first, last, #st.lines)
    else
        footer = "Esc or ⇪/ closes   ·   ⇪= adds an entry"
    end
    table.insert(els, {
        type = "text", text = footer,
        textSize = 13, textColor = { white = 0.62 }, textAlignment = "center",
        frame = { x = 0, y = st.panelH - st.footerH - 4, w = st.panelW, h = st.footerH },
    })

    local ok, err = pcall(function() canvas:replaceElements(els) end)
    if not ok then
        print("⌨️ Cheat sheet: render failed — " .. tostring(err))
    end
end

-- Scrolling is CLAMPED, never wrapped: you cannot scroll past either
-- end, and a redraw that shortens the list (deleting a custom entry
-- while the sheet is open) pulls the view back into range instead of
-- leaving you staring at blank rows.
function cheatSheet.scrollTo(index)
    local st = _G.cheatSheetState
    if not st then return end
    local target = math.floor(math.max(1, math.min(st.maxFirst, index)))
    if target ~= st.first then
        st.first = target
        cheatSheet.render()
    end
end

function cheatSheet.scrollBy(delta)
    local st = _G.cheatSheetState
    if not st then return end
    cheatSheet.scrollTo(st.first + delta)
end

-- A page keeps two rows of overlap so you don't lose your place.
function cheatSheet.pageStep()
    local st = _G.cheatSheetState
    return st and math.max(1, st.visible - 2) or 1
end

function cheatSheet.wheelHandler(e)
    local st = _G.cheatSheetState
    if not st then return false end

    -- Only claim the wheel when the pointer is over the sheet. Anywhere
    -- else the event passes straight through, so the window underneath
    -- scrolls normally while the sheet sits open beside it.
    local okPos, pos = pcall(hs.mouse.absolutePosition)
    if not (okPos and pos) then return false end
    local r = st.rect
    if pos.x < r.x or pos.x > r.x + r.w or pos.y < r.y or pos.y > r.y + r.h then
        return false
    end
    if st.maxFirst <= 1 then return true end   -- nothing to scroll, but the
                                               -- sheet still swallows it

    local props = hs.eventtap.event.properties
    local rows = 0
    local continuous = e:getProperty(props.scrollWheelEventIsContinuous)
    if continuous and continuous ~= 0 then
        -- Trackpads report PIXELS, mice report LINES. The pixels are
        -- accumulated across events, otherwise a slow two-finger drag
        -- rounds to zero every time and the sheet never moves.
        local px = e:getProperty(props.scrollWheelEventPointDeltaAxis1) or 0
        st.wheelAccum = (st.wheelAccum or 0) + px
        rows = st.wheelAccum / st.lineH
        rows = (rows >= 0) and math.floor(rows) or math.ceil(rows)
        st.wheelAccum = st.wheelAccum - rows * st.lineH
    else
        local d = e:getProperty(props.scrollWheelEventDeltaAxis1) or 0
        rows = (d >= 0) and math.floor(d) or math.ceil(d)
    end

    if rows ~= 0 then
        -- A POSITIVE delta always means "move the view toward the top",
        -- under natural AND legacy scrolling — macOS flips the sign
        -- itself — so this needs no preference check. Capped so one
        -- violent flick can't teleport you to the end.
        cheatSheet.scrollBy(-math.max(-10, math.min(10, rows)))
    end
    return true
end

-- Built once, then enabled/disabled with the sheet. Every step is
-- individually pcall'd: if one key can't be bound the sheet still opens
-- and still scrolls by the other routes, and the Console says which one
-- was lost rather than the whole feature dying.
function cheatSheet.enableInput()
    if not _G.cheatSheetEscHotkey then
        local ok, hk = pcall(hs.hotkey.new, {}, "escape", cheatSheet.hide)
        if ok then _G.cheatSheetEscHotkey = hk end
    end
    if not _G.cheatSheetScrollKeys then
        local defs = {
            { "up",       function() cheatSheet.scrollBy(-1) end },
            { "down",     function() cheatSheet.scrollBy(1) end },
            { "pageup",   function() cheatSheet.scrollBy(-cheatSheet.pageStep()) end },
            { "pagedown", function() cheatSheet.scrollBy(cheatSheet.pageStep()) end },
            { "home",     function() cheatSheet.scrollTo(1) end },
            { "end",      function() cheatSheet.scrollTo(math.maxinteger) end },
        }
        local keys = {}
        for _, d in ipairs(defs) do
            -- Same function as pressedfn AND repeatfn, so holding the
            -- key keeps scrolling instead of moving exactly one row.
            local ok, hk = pcall(hs.hotkey.new, {}, d[1], d[2], nil, d[2])
            if ok and hk then
                table.insert(keys, hk)
            else
                print("⌨️ Cheat sheet: couldn't bind " .. d[1] .. " for scrolling")
            end
        end
        _G.cheatSheetScrollKeys = keys
    end
    if not _G.cheatSheetWheelTap then
        local ok, tap = pcall(hs.eventtap.new,
            { hs.eventtap.event.types.scrollWheel }, cheatSheet.wheelHandler)
        if ok then _G.cheatSheetWheelTap = tap end
    end

    if _G.cheatSheetEscHotkey then
        pcall(function() _G.cheatSheetEscHotkey:enable() end)
    end
    for _, hk in ipairs(_G.cheatSheetScrollKeys or {}) do
        pcall(function() hk:enable() end)
    end
    if _G.cheatSheetWheelTap then
        pcall(function() _G.cheatSheetWheelTap:start() end)
    end
end

-- preserveScroll: redraws triggered by adding/editing/deleting an entry
-- keep your place in the list. A fresh ⇪/ always starts at the top.
function cheatSheet.show(preserveScroll)
    local keepFirst = (preserveScroll and _G.cheatSheetState
                       and _G.cheatSheetState.first) or 1
    cheatSheet.hide()  -- never stack two

    -- ---- layout metrics (20pt text as originally requested) ----
    local entrySize, headerSize, titleSize = 20, 20, 24
    local lineH = 30                          -- uniform row height, see above
    local pad, titleH, footerH = 26, 46, 34
    local sbW = 6                             -- scrollbar width

    local screen = resolveBaseScreen()
    local sf = screen:frame()

    -- ONE COLUMN, ALWAYS. Wide enough to read comfortably, capped so it
    -- stays a panel instead of a wall on a 4K monitor, and shrunk to fit
    -- a laptop display. It never grows sideways — length goes downward
    -- and you scroll it.
    local panelW   = math.max(360, math.min(760, sf.w * 0.55))
    local contentX = pad
    local contentW = panelW - pad * 2 - sbW - 10

    -- ⚠️ 6.31.0 — ENTRIES WRAP INSTEAD OF BEING CLIPPED.
    -- Each entry was one canvas text element in a fixed-width frame, so
    -- anything longer than the column was silently CUT OFF mid-sentence
    -- ("F1-F12 — Not forwarded — macOS reserves some"). Nothing warned;
    -- the text just stopped. Long entries are now split across
    -- continuation lines, indented under the key so the column still
    -- reads cleanly.
    --
    -- Width is estimated, not measured: hs.canvas has no text-metrics
    -- call, so this uses an average glyph width for the font size. The
    -- estimate is deliberately CONSERVATIVE (0.52 of the point size) —
    -- wrapping a line one word early is invisible, running past the
    -- column edge is the bug we are fixing.
    local wrapChars = math.max(20, math.floor(contentW / (entrySize * 0.52)))

    -- All widths are in CHARACTERS, and every string here can contain
    -- multi-byte glyphs (⇪, ⌘, —, emoji), so length must be measured
    -- with utf8.len — Lua's # counts BYTES and would over-count these
    -- badly, wrapping far too early. utf8.len returns nil on malformed
    -- input, hence the fallback.
    local function ulen(str)
        return (utf8 and utf8.len(str)) or #str
    end

    local INDENT = "      "   -- continuation lines sit under the key
    local function wrapEntry(keys, desc)
        local out  = {}
        local head = keys .. "  —  "
        local headLen = ulen(head)

        -- If the key label alone eats most of the column there is no
        -- room to start the description beside it, so the key gets its
        -- own line and the whole description wraps underneath. The old
        -- fallback kept writing beside a long key and simply overran the
        -- column, which is the clipping this function exists to prevent.
        local sameLine = (wrapChars - headLen) >= 12
        local budget   = sameLine and (wrapChars - headLen)
                                   or (wrapChars - ulen(INDENT))
        if not sameLine then table.insert(out, head) end

        local line, first = "", sameLine
        local function flush()
            if line == "" then return end
            table.insert(out, (first and head or INDENT) .. line)
            first = false
            budget = wrapChars - ulen(INDENT)
            line = ""
        end
        for word in tostring(desc):gmatch("%S+") do
            local candidate = (line == "") and word or (line .. " " .. word)
            if ulen(candidate) > budget and line ~= "" then
                flush()
                line = word
            else
                line = candidate
            end
        end
        if line ~= "" then
            flush()
        elseif #out == 0 then
            table.insert(out, head)
        end
        return out
    end

    -- Flatten every group into one flat list of rows. A blank spacer row
    -- separates groups, which keeps every row the same height.
    local lines = {}
    for gi, g in ipairs(cheatSheet.groups()) do
        if gi > 1 then table.insert(lines, { kind = "spacer", text = "" }) end
        table.insert(lines, { kind = "header", text = g.title })
        for _, e in ipairs(g.entries) do
            for _, seg in ipairs(wrapEntry(tostring(e[1]), tostring(e[2]))) do
                table.insert(lines, { kind = "entry", text = seg })
            end
        end
    end

    -- Height: as tall as the content needs, up to 86% of the screen.
    -- A SHORT list gets a short panel (no dead space); a long one fills
    -- the height and scrolls.
    local contentTop = pad + titleH
    local chromeH    = contentTop + footerH + 8
    local panelH     = math.min(sf.h * 0.86, chromeH + #lines * lineH)
    local visible    = math.max(1, math.floor((panelH - chromeH) / lineH))
    -- Snap to a whole number of rows so there is never a half-row strip
    -- of dead space above the footer.
    panelH = chromeH + visible * lineH
    local maxFirst = math.max(1, #lines - visible + 1)

    local rect = {
        x = sf.x + (sf.w - panelW) / 2,
        y = sf.y + (sf.h - panelH) / 2,
        w = panelW,
        h = panelH,
    }

    local canvas = hs.canvas.new(rect)
    if not canvas then
        hs.alert.show("❌ Couldn't create cheat sheet — check Hammerspoon Console")
        return
    end

    _G.cheatSheetCanvas = canvas
    _G.cheatSheetState  = {
        lines      = lines,
        first      = math.max(1, math.min(maxFirst, keepFirst)),
        visible    = visible,
        maxFirst   = maxFirst,
        lineH      = lineH,
        entrySize  = entrySize,
        headerSize = headerSize,
        titleSize  = titleSize,
        pad        = pad,
        titleH     = titleH,
        footerH    = footerH,
        panelW     = panelW,
        panelH     = panelH,
        rect       = rect,
        contentX   = contentX,
        contentW   = contentW,
        contentTop = contentTop,
        sbX        = panelW - pad * 0.6 - sbW,
        sbW        = sbW,
        wheelAccum = 0,
    }

    cheatSheet.render()
    _G.diag.say("cheatSheet", string.format("opened: %d rows, %d visible, panel %dx%d",
        #lines, visible, panelW, panelH))

    pcall(function() canvas:level(hs.canvas.windowLevels.overlay) end)
    -- Same Spaces/full-screen visibility fix as the dashboard legend:
    -- without these, the sheet can't appear over full-screen apps.
    pcall(function() canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
    -- 6.31.0 — CLICK NO LONGER CLOSES THE SHEET. It used to, and a
    -- stray click anywhere on the panel dismissed the reference you were
    -- reading mid-lookup. Mouse events are left OFF entirely so clicks
    -- pass through to whatever is underneath instead of being swallowed
    -- (the wheel is handled by an eventtap, not by the canvas).
    canvas:show()

    cheatSheet.enableInput()
end

function cheatSheet.toggle()
    if _G.cheatSheetCanvas then
        cheatSheet.hide()
    else
        cheatSheet.show()
    end
end


_G.__cheatSheet = cheatSheet
