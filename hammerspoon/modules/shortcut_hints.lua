-- =====================================================================
-- MODULE: SHORTCUT HINTS — after a ⇪ key, a card of its group's other keys
-- =====================================================================
-- 6.163.0. LL: "when I execute my hyper key plus necessary additional
-- keys, I get a window that pops up with the shortcut keys that are also
-- applicable. So the Asana section is a good example. I always use hyper
-- key plus T, I should essentially get a tool tips window that reminds
-- me what other tools I have in the Asana section. It should fade after
-- 10 seconds or I should be able to hit escape and have an instant
-- vanish."
--
-- HOW IT FIRES. init.lua §3.12's hyperBind wraps every hyper shortcut's
-- pressed function ONCE, and after the shortcut has run it calls
-- _G.shortcutHint(combo, source) — both dispatch paths (Carbon modal on
-- the home Mac, the tap dispatcher on the work Mac), never the forwarded
-- ⌘⇧⌃⌥ chords, never while paused (the pause wrap sits outside).
--
-- WHAT IT SHOWS. hint.groups maps every hyper combo (init.lua's
-- hyperCombo spelling: "t", "shift+s", "left", "pad1") to a named GROUP.
-- The card lists the OTHER keys of the pressed key's group — only those
-- actually bound on this Mac (_G.hyperBound), plus hint.extras rows that
-- are not hyper keys but belong with them (⌥Tab beside the window keys).
-- A group with nothing else to show draws nothing. Descriptions come
-- from the cheat sheet (_G.moduleCheatsheets, then hint.coreRows for the
-- keys init.lua/core own), falling back to the registry's source label.
--
-- HOW IT GOES. hint.holdSecs (10) then a fade; or the first key or click
-- of any kind, which is OBSERVED and never consumed — Esc still reaches
-- the picker the shortcut opened. The card never takes focus and never
-- catches a click (clickActivating off, no mouse events), so ⇪T's form
-- keeps your typing. Panel ladder rung "hint" (core/coexist.lua): above
-- the chooser, below the pomodoro.
--
-- OFF SWITCH. settings = { shortcut_hints = { enabled = false } } in a
-- profile; hint.groups / hint.extras are settings too, so a group can be
-- reshaped without touching this file. _G.shortcutHintsReport() says what
-- the last press resolved to and why a card did or did not show.
--
-- 🚨 CONTRACTS KEPT: the dismiss tap starts with the pause check, stands
-- down during an injection, calls _G.hyperTouch() for keys seen under ⇪
-- (6.162.1's latch rule), returns false on every path, runs only while
-- the card is up. Every timer, tap and canvas is HELD in `hint`.

local M = {
    name   = "Shortcut Hints",
    order  = 14.12,
    family = "config",
    summary = "after any ⇪ key, a small card names the other keys of its group",
    cheatsheet = {
        title = "💡 SHORTCUT HINTS (automatic — after a ⇪ key, its group's other keys)",
        entries = {
            { "any ⇪ key", "A card top-right lists the group's other keys — Asana after ⇪T, and so on" },
            { "",           "Sized to the screen: 540 wide / 20 pt on a 1440-pt-tall screen, ×1.5 on a 4K at full points; settings shortcut_hints.scale pins it" },
            { "10 s",       "It fades by itself; any key or click makes it vanish at once (Esc included, and Esc still reaches the picker)" },
            { "settings",   "settings = { shortcut_hints = { enabled = false } } turns it off; hint.groups reshapes a group" },
            { "Console",    "_G.shortcutHintsReport() — what the last press resolved to" },
        },
    },
}

local hint = {
    enabled   = true,
    holdSecs  = 10,        -- LL: "fade after 10 seconds"
    fadeSecs  = 0.6,
    maxRows   = 16,        -- Windows is the biggest group (15 + ⌥Tab)
    graceSecs = 0.35,      -- a shortcut's OWN synthetic input must not dismiss it
    width     = 540,       -- 6.166.0: 50% wider than 6.163.0's 360 — AT SCALE 1
    margin    = 18,        -- from the corner
    corner    = "top-right",   -- 6.165.1 (was bottom-right): "top-right" | "bottom-right"
    alpha     = 0.70,      -- 6.165.1: 20% more see-through (was 0.88)
    fontSize  = 20,        -- 6.166.0: 20 pt (LL: "big enough to fit 20pt font") — AT SCALE 1
    -- 🖥 6.167.0 — SIZED BY THE SCREEN. 6.165.1 and 6.166.0 each made the
    -- card bigger in POINTS and LL saw no change: "still small and does
    -- not seem to be taking new settings." The Console names the screen —
    -- an LG 4K — and at full points (3840 × 2160) a 20 pt line is 20
    -- pixels, a fifth of what it is on a Retina "looks like" setting.
    -- width and fontSize above are for a screen scaleBase points tall;
    -- a taller screen scales them up (×1.5 on that 4K), never down.
    -- A number here pins it: settings = { shortcut_hints = { scale = 2 } }.
    scale     = nil,
    scaleBase = 1440,
    scaleMax  = 2.5,
    -- combo (init.lua hyperCombo spelling) → group. Curated from the
    -- cheat sheet; a combo missing here draws no card (report says so).
    groups = {
        -- Asana
        t = "Asana", a = "Asana", b = "Asana", c = "Asana", l = "Asana",
        -- Screenshots
        ["4"] = "Screenshots", ["shift+4"] = "Screenshots", ["shift+space"] = "Screenshots",
        -- Clipboard & OCR
        v = "Clipboard & OCR", ["shift+v"] = "Clipboard & OCR",
        o = "Clipboard & OCR", ["shift+o"] = "Clipboard & OCR",
        ["shift+c"] = "Clipboard & OCR", ["shift+2"] = "Clipboard & OCR",
        -- Notes & capture
        -- 6.182.0 — "1" came OUT: ⇪1 is free (the Scorp Pad moved to ⇪N),
        -- and a group row for an unbound key is dead config. ⇪2 stays —
        -- it is the sequential copy now, which is squarely notes & capture.
        n = "Notes & capture", ["shift+n"] = "Notes & capture", ["2"] = "Notes & capture",
        ["3"] = "Notes & capture",   -- 6.172.0 the vault
        ["shift+u"] = "Notes & capture",   -- 6.180.0 the ⇪⇧U anchors
        j = "Notes & capture", ["shift+j"] = "Notes & capture",
        pad1 = "Notes & capture", pad2 = "Notes & capture", pad3 = "Notes & capture",
        ["pad*"] = "Notes & capture", ["pad-"] = "Notes & capture",
        -- Windows
        left = "Windows", right = "Windows", up = "Windows", down = "Windows",
        ["\\"] = "Windows", w = "Windows", ["["] = "Windows", ["]"] = "Windows",
        ["shift+up"] = "Windows", ["shift+down"] = "Windows",
        ["shift+left"] = "Windows", ["shift+right"] = "Windows",
        ["shift+r"] = "Windows", pad4 = "Windows", p = "Windows",
        -- Mouse
        x = "Mouse", ["shift+x"] = "Mouse", ["shift+l"] = "Mouse",   -- ⇪⇧U left with win_pin (6.166.0)
        ["shift+f"] = "Mouse", ["shift+3"] = "Mouse",
        -- Search & open
        space = "Search & open", ["shift+/"] = "Search & open", d = "Search & open",
        ["."] = "Search & open", m = "Search & open", ["shift+m"] = "Search & open",
        [","] = "Search & open", h = "Search & open",
        -- Browser & web
        y = "Browser & web", ["shift+y"] = "Browser & web", ["shift+'"] = "Browser & web",
        k = "Browser & web", ["shift+k"] = "Browser & web",
        -- Text & snippets
        ["shift+s"] = "Text & snippets", ["8"] = "Text & snippets",
        ["shift+a"] = "Text & snippets", s = "Text & snippets", z = "Text & snippets",
        -- Time & focus
        q = "Time & focus", ["shift+q"] = "Time & focus", ["shift+p"] = "Time & focus",
        ["shift+0"] = "Time & focus", ["0"] = "Time & focus",
        ["shift+w"] = "Time & focus", ["shift+e"] = "Time & focus",
        -- This Mac
        ["6"] = "This Mac", ["shift+6"] = "This Mac", ["7"] = "This Mac",
        g = "This Mac", ["shift+g"] = "This Mac", ["shift+="] = "This Mac",
        ["shift+-"] = "This Mac", ["9"] = "This Mac", ["shift+9"] = "This Mac",
        -- Power tools
        [";"] = "Power tools", ["shift+;"] = "Power tools", ["'"] = "Power tools",
        ["`"] = "Power tools", ["shift+`"] = "Power tools", ["5"] = "Power tools",
        u = "Power tools",
        -- Files
        f = "Files", i = "Files", ["shift+i"] = "Files", r = "Files",
        -- Config & help
        ["shift+d"] = "Config & help", ["shift+h"] = "Config & help",
        ["shift+b"] = "Config & help", ["/"] = "Config & help", ["="] = "Config & help",
        ["-"] = "Config & help", e = "Config & help", ["shift+1"] = "Config & help",
    },
    -- Rows that are not hyper keys but belong beside them.
    extras = {
        ["Windows"] = { { "⌥Tab", "Window switcher — the rolodex" } },
    },
    -- Keys whose rows live in init.lua / core, not a module cheat sheet.
    coreRows = {
        ["⇪A"] = "Format Asana URL from clipboard",
        ["⇪B"] = "Browse Asana Teams — Enter copies a name for Assignee",
        ["⇪C"] = "Comment on a task",
        ["⇪L"] = "List tasks — Today / Week / Overdue",
        ["⇪⇧C"] = "Toggle copy-on-select",
        ["⇪/"] = "Toggle the cheat sheet",
        ["⇪="] = "Add your own entry to the cheat sheet",
        ["⇪E"] = "Edit a custom cheat sheet entry",
        ["⇪-"] = "Remove a custom cheat sheet entry",
        ["⇪⇧D"] = "Diagnostic report — Console + clipboard + Logs file",
        ["⇪P"] = "Hide / show the front app",
        ["⇪⇧R"] = "Reset the panel nudge offset",
        ["⇪⇧↑"] = "Nudge the open picker up", ["⇪⇧↓"] = "Nudge it down",
        ["⇪⇧←"] = "Nudge it left", ["⇪⇧→"] = "Nudge it right",
    },
    -- Combos that never draw a card even though they are in a group
    -- (the pause switch, read from _G.hsPauseCombo at press time too).
    silent = { ["shift+1"] = true },
    -- state
    canvas = nil, tap = nil, holdTimer = nil, fadeTimer = nil, readyTimer = nil, shownAt = 0,
    last = nil, shows = 0, dismissed = 0, faded = 0, tapWarned = false,
}
M.config = hint
M.version = "6.167.0"
-- The file this code came from, for the report: "which file is loaded"
-- is the first question when a size change is not seen.
M.file = "?"
pcall(function() M.file = (debug.getinfo(1, "S").source:gsub("^@", "")) end)

local GLYPH = { left = "←", right = "→", up = "↑", down = "↓", space = "space",
                ["return"] = "⏎", escape = "esc", tab = "⇥", delete = "⌫" }

-- "shift+t" → "⇪⇧T"; "left" → "⇪←"; "pad1" → "⇪pad1"
local function labelOf(combo)
    local s = tostring(combo or "")
    local shift = s:find("shift+", 1, true) ~= nil
    local key = s:gsub("shift%+", ""):gsub("^%+", "")
    key = GLYPH[key] or (key:match("^pad") and key or key:upper())
    return "⇪" .. (shift and "⇧" or "") .. key
end
M.labelOf = labelOf

local function norm(s) return (tostring(s or ""):gsub("%s+", ""):lower()) end

-- "✂️ TEXT EXPANDER (Alfred snippets)" → "Text expander"
local function subjectOf(title)
    local t = tostring(title or ""):gsub("%(.*$", "")
    t = t:gsub("[%z\1-\127\194-\244][\128-\191]*", function(ch)
        return (ch:byte() < 128 or ch:match("^[\195-\197]")) and ch or "" end)
    t = t:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+—.*$", "")
    if t == "" then return nil end
    return t:sub(1, 1):upper() .. t:sub(2):lower()
end
M.subjectOf = subjectOf

-- Find the cheat sheet row whose key cell names this label. A row's ""
-- continuation lines are folded in, and a terse description gets the
-- sheet group's subject in front ("Autocorrect: Toggle on/off").
local function describe(label, source)
    local target = norm(label)
    local found, subject
    pcall(function()
        for _, g in ipairs(_G.moduleCheatsheets or {}) do
            local es = g.entries or {}
            for i, e in ipairs(es) do
                local cell = norm(e[1])
                if cell == target or cell:find(target .. "/", 1, true) == 1
                   or cell:find("/" .. target, 1, true) then
                    local parts = { tostring(e[2] or "") }
                    local j = i + 1
                    while es[j] and norm(es[j][1]) == "" do
                        parts[#parts + 1] = tostring(es[j][2] or ""); j = j + 1
                    end
                    found = table.concat(parts, " "):gsub("%s+", " ")
                    subject = subjectOf(g.title)
                    return
                end
            end
        end
    end)
    if found then
        local _, words = found:gsub("%S+", "")
        if subject and words <= 4 and not found:lower():find(subject:lower(), 1, true) then
            found = subject .. ": " .. found
        end
        return found
    end
    if hint.coreRows[label] then return hint.coreRows[label] end
    return source and tostring(source) or ""
end

function M.setup(core)
    local say  = function(m) if _G.diag and _G.diag.say  then _G.diag.say("hints", m)  else print("💡 " .. m) end end
    local warn = function(m) if _G.diag and _G.diag.warn then _G.diag.warn("hints", m) else print("💡 ⚠️ " .. m) end end

    -- ---- the rows for a press ------------------------------------------
    function hint.rowsFor(combo)
        local group = hint.groups[combo]
        if not group then return nil, "no group for ⇪" .. tostring(combo) end
        local rows = {}
        local bound = _G.hyperBound or {}
        local combos = {}
        for c, g in pairs(hint.groups) do
            -- "chord" is init.lua's forward of an UNCLAIMED key — not a tool
            if g == group and c ~= combo and bound[c] and bound[c] ~= "chord" then
                combos[#combos + 1] = c
            end
        end
        table.sort(combos, function(a, b) return labelOf(a) < labelOf(b) end)
        for _, c in ipairs(combos) do
            local lab = labelOf(c)
            rows[#rows + 1] = { lab, describe(lab, bound[c]) }
        end
        for _, ex in ipairs(hint.extras[group] or {}) do rows[#rows + 1] = { ex[1], ex[2] } end
        if #rows == 0 then return nil, group .. ": nothing else bound here" end
        local more = 0
        if #rows > hint.maxRows then more = #rows - hint.maxRows
            while #rows > hint.maxRows do table.remove(rows) end
        end
        return rows, group, more
    end

    -- ---- drawing -------------------------------------------------------
    local function style()
        local st = _G.uiStyle
        local bg = (st and st.bgWith and st.bgWith(hint.alpha))
                   or { red = 0.11, green = 0.11, blue = 0.13, alpha = hint.alpha }
        local fg = (st and st.fg) or { red = 0.95, green = 0.95, blue = 0.95, alpha = 1 }
        local dim = { red = fg.red or 1, green = fg.green or 1, blue = fg.blue or 1, alpha = 0.62 }
        return bg, fg, dim
    end

    -- hs.screen.mainScreen() only: the screen with keyboard focus, no
    -- Accessibility question — this can run inside the tap callback on
    -- the work Mac, and an untimed AX read there is the 6.160.0 hang.
    -- Returns the usable frame (placement: it clears the menu bar), the
    -- FULL frame (the scale: frame() also loses the Dock, and a Dock that
    -- hides would change the card between presses), the display's name
    -- and its mode ("3840x2160@1x 60Hz" — the @1x/@2x that decides
    -- whether points are pixels). All CoreGraphics, each read pcall'd.
    local function screenInfo()
        local scr
        pcall(function() scr = hs.screen.mainScreen() end)
        local f, full, name, mode
        pcall(function() f = scr and scr:frame() end)
        pcall(function() full = scr and scr:fullFrame() end)
        pcall(function() name = scr and scr:name() end)
        pcall(function() local m = scr and scr:currentMode(); mode = m and m.desc end)
        return f, full or f, name, mode
    end

    -- 6.167.0: the factor everything on the card is drawn by — pinned
    -- by hint.scale, else the screen's height over scaleBase, floor 1.
    local function round(n) return math.floor(n + 0.5) end
    -- A settings override is whatever LL typed: "2" is 2, and 0, a
    -- negative or a word is not a pin — one test, used by scaleFor AND
    -- the report, so the report never claims a pin the drawing ignores.
    local function num(v, default)
        v = tonumber(v)
        if v and v > 0 then return v end
        return default
    end
    function hint.pinned() return num(hint.scale, nil) end
    function hint.scaleFor(f)
        local pin = hint.pinned()
        if pin then return pin end
        local h = f and tonumber(f.h) or 0
        local s = (h > 0) and (h / num(hint.scaleBase, 1440)) or 1
        if s < 1 then s = 1 end
        local max = num(hint.scaleMax, 2.5)
        if s > max then s = max end
        return s
    end
    -- The card's size in points at scale s, for the report and the tests.
    function hint.sizeAt(s)
        return round(num(hint.width, 540) * s), round(num(hint.fontSize, 20) * s)
    end

    local function frameFor(f, h, s)
        local w = hint.sizeAt(s)
        local m = round((tonumber(hint.margin) or 18) * s)
        local y = (hint.corner == "bottom-right") and (f.y + f.h - h - m) or (f.y + m)
        return { x = f.x + f.w - w - m, y = y, w = w, h = h }
    end

    -- One line saying what THIS file draws on THIS screen; the report's
    -- "card" row and the boot line share it.
    function hint.sizeLine()
        local _, full, name, mode = screenInfo()
        local s = hint.scaleFor(full)
        local w, pt = hint.sizeAt(s)
        local why = hint.pinned() and "pinned by hint.scale"
                    or (full and (round(tonumber(full.h) or 0) .. " pt tall, base "
                                  .. tostring(hint.scaleBase)))
                    or "no screen"
        return string.format("%d wide · %d pt · %s · alpha %.2f · scale %.2f (%s%s%s)",
            w, pt, tostring(hint.corner), tonumber(hint.alpha) or 0, s, why,
            name and (" · " .. tostring(name)) or "", mode and (" · " .. tostring(mode)) or "")
    end

    local function elements(group, rows, more, s)
        local bg, fg, dim = style()
        local W, F = hint.sizeAt(s)
        local pad, line = round(12 * s), F + round(7 * s)
        local keyW, gap = round(78 * s), round(4 * s)
        local h = pad * 2 + line * (#rows + 1) + (more > 0 and line or 0)
        local els = {
            { type = "rectangle", action = "fill", fillColor = bg,
              roundedRectRadii = { xRadius = round(10 * s), yRadius = round(10 * s) } },
            { type = "text", text = group:upper() .. "  ·  also", textColor = dim,
              textSize = F - 1,
              frame = { x = pad, y = pad, w = W - pad * 2, h = line } },
        }
        local y = pad + line
        for _, r in ipairs(rows) do
            els[#els + 1] = { type = "text", text = r[1], textColor = fg,
                              textSize = F, textFont = "Menlo",
                              frame = { x = pad, y = y, w = keyW, h = line } }
            els[#els + 1] = { type = "text", text = r[2], textColor = fg,
                              textSize = F, textLineBreak = "truncateTail",
                              frame = { x = pad + keyW + gap, y = y,
                                        w = W - pad * 2 - keyW - gap, h = line } }
            y = y + line
        end
        if more > 0 then
            els[#els + 1] = { type = "text", text = "… " .. more .. " more on ⇪/",
                              textColor = dim, textSize = F - 1,
                              frame = { x = pad, y = y, w = W - pad * 2, h = line } }
        end
        return els, h
    end

    -- ---- the dismiss tap: observes, never consumes -----------------------
    local F18_CODE = 79
    local function onEvent(ev)
        if _G.hsPaused then return false end
        if _G.typingInjection and _G.typingInjection() then return false end
        if _G.hyperActive and _G.hyperTouch then _G.hyperTouch() end
        -- Not a dismissal: Caps Lock itself (F18, held for the chord that
        -- just fired), a key's auto-repeat, and anything within the grace
        -- window — the shortcut's own synthetic click or keystrokes.
        local t = ev:getType()
        if t == hs.eventtap.event.types.keyDown then
            local code
            pcall(function() code = ev:getKeyCode() end)
            if code == F18_CODE then return false end
            local rep
            pcall(function()
                rep = ev:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat)
            end)
            if rep and rep ~= 0 then return false end
        end
        if hs.timer.secondsSinceEpoch() - (hint.shownAt or 0) < hint.graceSecs then
            return false
        end
        hint.dismissed = hint.dismissed + 1
        hint.hide("a key or click")
        return false
    end
    local function tapCallback(ev)
        local ok, res = pcall(onEvent, ev)
        if not ok then hint.hide("tap error"); return false end
        return res == true
    end

    function hint.hide(why)
        if hint.holdTimer then pcall(function() hint.holdTimer:stop() end); hint.holdTimer = nil end
        if hint.fadeTimer then pcall(function() hint.fadeTimer:stop() end); hint.fadeTimer = nil end
        if hint.tap then pcall(function() hint.tap:stop() end) end
        local c = hint.canvas
        hint.canvas = nil
        if c then pcall(function() c:delete() end) end
        if why and hint.last then hint.last.ended = why end
    end

    local function armHold()
        if hint.holdTimer then pcall(function() hint.holdTimer:stop() end) end
        hint.holdTimer = hs.timer.doAfter(hint.holdSecs, function()
            hint.holdTimer = nil
            local c = hint.canvas
            if not c then return end
            hint.faded = hint.faded + 1
            local okFade = pcall(function() c:hide(hint.fadeSecs) end)
            if hint.tap then pcall(function() hint.tap:stop() end) end
            hint.fadeTimer = hs.timer.doAfter(hint.fadeSecs + 0.05, function()
                hint.fadeTimer = nil
                if hint.canvas == c then hint.hide("faded") end
            end)
            if not okFade then hint.hide("faded") end
        end)
    end

    function hint.show(combo, source)
        local rows, group, more = hint.rowsFor(combo)
        hint.last = { combo = combo, source = source, group = rows and group or nil,
                      rows = rows and #rows or 0, why = rows and "shown" or group,
                      at = os.time() }
        if not rows then return false end
        hint.hide()   -- one card at a time; a new press restarts everything
        local f, full = screenInfo()
        if not f then hint.last.why = "no screen"; return false end
        local s = hint.scaleFor(full)
        local els, h = elements(group, rows, more, s)
        local rect = frameFor(f, h, s)
        hint.last.scale, hint.last.rect = s, rect
        local okNew, c = pcall(hs.canvas.new, rect)
        if not (okNew and c) then hint.last.why = "hs.canvas.new failed"; return false end
        hint.canvas = c
        pcall(function()
            c:level((_G.panelLevel and _G.panelLevel("hint"))
                    or (hs.canvas.windowLevels or {}).overlay)
            c:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
            c:clickActivating(false)
            c:canvasMouseEvents(false, false, false, false)
            c:alpha(1.0)
        end)
        pcall(function() c:replaceElements(els) end)
        if _G.showCanvasSafely then _G.showCanvasSafely(c, "shortcut hint")
        else pcall(function() c:show() end) end
        if not hint.tap then
            local okTap, t = pcall(hs.eventtap.new,
                { hs.eventtap.event.types.keyDown, hs.eventtap.event.types.leftMouseDown,
                  hs.eventtap.event.types.rightMouseDown }, tapCallback)
            if okTap and t then hint.tap = t else warn("no dismiss tap — the card will fade on its own") end
        end
        if hint.tap then
            local okStart = pcall(function() hint.tap:start() end)
            if not okStart and not hint.tapWarned then
                hint.tapWarned = true
                warn("the dismiss tap would not start — cards will fade on their own")
            end
        end
        hint.shownAt = hs.timer.secondsSinceEpoch()
        armHold()
        hint.shows = hint.shows + 1
        return true
    end

    -- The hook init.lua's hyperBind calls after every hyper shortcut.
    _G.shortcutHint = function(combo, source)
        if not hint.enabled then return false end
        if source == "chord" or hint.silent[combo] or combo == _G.hsPauseCombo then return false end
        if _G.hsPaused then return false end
        return hint.show(combo, source)
    end

    function _G.shortcutHintsReport()
        local L = { "💡 SHORTCUT HINTS" }
        L[#L + 1] = "   enabled  : " .. tostring(hint.enabled)
        local n = 0 for _ in pairs(hint.groups) do n = n + 1 end
        L[#L + 1] = "   groups   : " .. n .. " combos mapped · " .. hint.holdSecs .. "s hold · "
                    .. hint.maxRows .. " rows max"
        L[#L + 1] = "   shown    : " .. hint.shows .. " · dismissed by a key/click " .. hint.dismissed
                    .. " · faded " .. hint.faded
        -- 6.167.0: which file, and the size IN EFFECT on the Console's
        -- screen — so "still small" is checked against what this file
        -- actually draws, and an older file still installed shows as one.
        do
            local when = ""
            pcall(function()
                local t = hs.fs.attributes(M.file, "modification")
                if t then when = " · modified " .. os.date("%Y-%m-%d %H:%M", t) end
            end)
            L[#L + 1] = "   file     : " .. tostring(M.version) .. " · " .. tostring(M.file) .. when
            L[#L + 1] = "   card     : " .. hint.sizeLine()
        end
        if hint.last then
            local r = hint.last.rect
            L[#L + 1] = string.format("   last     : ⇪%s (%s) → %s · %d rows · %s%s%s",
                tostring(hint.last.combo), tostring(hint.last.source),
                tostring(hint.last.group or "no group"), hint.last.rows or 0,
                tostring(hint.last.why), hint.last.ended and (" · ended: " .. hint.last.ended) or "",
                -- what was REALLY drawn, whatever screen the Console is on now
                r and string.format(" · drawn %d×%d at %d,%d · scale %.2f",
                                    round(r.w), round(r.h), round(r.x), round(r.y),
                                    hint.last.scale or 1) or "")
        else
            L[#L + 1] = "   last     : nothing yet — press any ⇪ key"
        end
        -- bound keys with no group: the ones that will never get a card
        local missing = {}
        for c in pairs(_G.hyperBound or {}) do
            if not hint.groups[c] and _G.hyperBound[c] ~= "chord" then missing[#missing + 1] = labelOf(c) end
        end
        table.sort(missing)
        if #missing > 0 then L[#L + 1] = "   no group : " .. table.concat(missing, " ") end
        L[#L + 1] = "   card up  : " .. tostring(hint.canvas ~= nil)
        local out = table.concat(L, "\n")
        print(out)
        return out
    end
    if core and core.provide then
        pcall(function() core.provide("shortcutHints.report", _G.shortcutHintsReport) end)
    end
    -- 6.167.0 — ONE PLAIN CONSOLE LINE, A TURN LATER. init.lua applies a
    -- profile's settings AFTER setup returns, and _G.diag.say prints
    -- only in verbose mode — so the size in effect (a pinned hint.scale
    -- included) goes through print once the overrides are in. LL reads
    -- the boot log: this is the line that says what this file draws.
    -- HELD, per the test_diagnostics sentry.
    hint.readyTimer = hs.timer.doAfter(0, function()
        hint.readyTimer = nil
        pcall(function()
            print("💡 shortcut hints " .. tostring(M.version) .. " — card " .. hint.sizeLine())
        end)
    end)
    say("ready — a card after each ⇪ key with group siblings; off with settings.shortcut_hints.enabled")
end

return M
