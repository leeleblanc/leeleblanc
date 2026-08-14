-- =====================================================================
-- core/cheatsheet.lua — §1.6, lifted out of init.lua in 6.44.11
-- =====================================================================
-- A CORE FILE, NOT A MODULE. Every module registers its cheat sheet group
-- while the §1.12 loader runs, so _G.__cheatSheet has to exist BEFORE the
-- loader starts. A loader-managed module could not guarantee that. This
-- file is dofile'd by init.lua at exactly the point §1.6 used to sit, so
-- the boot order is unchanged; only the 721 lines moved.
--
-- The seven values below were upvalues from init.lua. Every one is
-- assigned before this point and none is reassigned after it, so passing
-- them by value is equivalent to the closure this replaces. That was
-- checked, not assumed.
-- =====================================================================

return function(core)
    local logsDir = core.logsDir
    local panelAlpha = core.panelAlpha
    local popupScreenKeys = core.popupScreenKeys
    local resolveBaseScreen = core.resolveBaseScreen
    local showPopup = core.showPopup
    local warnWriteFailed = core.warnWriteFailed
    local adoptLegacyFile = core.adoptLegacyFile

    -- =====================================================================
    -- 1.6 SHORTCUT CHEAT SHEET — ⇪/ to toggle · ⇪= to add entries
    -- =====================================================================
    -- A single-column 20pt reference panel of every shortcut in this config,
    -- plus any entries YOU add on the fly (⇪=), which persist in
    -- custom_shortcuts.json and survive reloads. 6.10.0: that file now
    -- lives in the OneDrive Logs folder and is SHARED between both Macs —
    -- it changes only when you deliberately add/edit an entry, so the two
    -- machines won't fight over it, and a ⭐ entry added on one Mac shows
    -- up on the other after its next Hammerspoon reload.
    --
    -- 6.32.0 — ONE VERTICAL COLUMN THAT SCROLLS. It grows DOWNWARD only:
    -- the column is a fixed, readable width (never wider than 760pt or 55%
    -- of the screen), as tall as the content needs up to 86% of the screen,
    -- and everything past that is reached by scrolling — ↑↓, PgUp/PgDn,
    -- Home/End, or the wheel while the pointer is over it. Always sized to
    -- the monitor holding the frontmost app (resolveBaseScreen), never
    -- spilling off it.
    --
    -- Built on hs.canvas (Hammerspoon's drawing layer), which is what allows
    -- literal 20pt text and a real translucent panel — hs.chooser (the
    -- version before that) could do neither. Lessons applied from the
    -- webview incident — TWO independent ways to close it:
    --   1. ⇪/ again (our own hotkey — always works)
    --   2. Esc (captured only while the sheet is visible)
    -- A CLICK DOES NOT CLOSE IT (6.31.0): a stray click used to dismiss the
    -- reference mid-lookup. Mouse events are off, so clicks pass through.
    -- Note: the sheet does NOT take keyboard focus, so it never interrupts
    -- typing — but that is also why Esc AND the scroll keys are captured
    -- globally while it's up. Close the sheet and they all return to the
    -- app underneath.
    --
    -- ⚠️ The BUILT-IN list is a hand-written snapshot, not auto-generated —
    -- if we add/change a hotkey later, ask and I'll keep it in sync.
    -- YOUR custom entries never need that; they live in the JSON file.
    -- To remove a custom entry, use ⇪- (or edit the JSON directly).
    -- ⚠️ ONE TABLE, NOT NINE LOCALS. The main chunk of this file sits ON
    -- Lua's hard ceiling of 200 locals — measured, not estimated — and the
    -- main chunk IS a function, so every top-level `local` counts. Going one
    -- over is a COMPILE error and the WHOLE config fails to load, not just
    -- the section that added it. Everything §1.6 needs therefore hangs off
    -- one table. Do the same in any new section.
    local cheatSheet = {}
    -- ✏️ PANEL SIZE. 6.57.0 — was a fixed 760 wide and up to 86% of the
    -- screen tall. Both are now yours to set.
    --
    -- ⚠️ THE TRADE-OFF IS REAL AND WORTH KNOWING. WIDTH is free: a wider
    -- column means fewer entries have to wrap onto continuation lines, so
    -- 1024 actually shows MORE shortcuts than 760 did, not fewer. HEIGHT
    -- is not free: at 30pt per row, 768 shows about 22 rows where 1194
    -- showed 36. If you would rather see more at once, raise this — it is
    -- clamped to the screen either way, so it can never open a panel
    -- taller than the display it lands on.
    cheatSheet.width     = 1024
    cheatSheet.height    = 768
    cheatSheet.key       = "/"   -- toggle key; same mods as everything above
    -- ✏️ SECTIONS PINNED ABOVE THE A–Z RUN. Empty = pure alphabetical,
    -- which is what LL asked for in 6.66.1. Add words from a group title
    -- to pin it; matching is case-insensitive substring, and pinned
    -- sections keep the order listed here rather than sorting among
    -- themselves. A module that FAILED to load still outranks any pin.
    cheatSheet.pinned    = { }
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

        -- ---- ORDER ON THE PAGE (6.65.0) ---------------------------------
        -- 🚨 THE MODULE'S `order` FIELD IS NOT THE ANSWER HERE, and this is
        -- the trap worth naming: that number is the module LOAD order, and
        -- the sheet was piggybacking on it. Renumbering modules to move a
        -- section up the page would reorder the boot, which is how a module
        -- ends up running before something it depends on. So the sheet
        -- sorts for ITSELF, and load order is left alone entirely.
        --
        -- Three bands, and the reasoning for each:
        --   0  BROKEN MODULES — always first. A feature that vanished
        --      without explanation is the worst possible thing to bury.
        --   1  PINNED — the sections you reach for most, in the order you
        --      named them. Alphabetical is a fine default and a poor top
        --      of the page; the first screenful should be what you use.
        --   2  EVERYTHING ELSE, A–Z by title. Alphabetical is the only
        --      order you can PREDICT without having read the file: you
        --      know where "File Tracker" is before you look.
        --   3  YOUR OWN ⭐ entries, last, as before.
        --
        -- ✏️ To pin another section, add the words that appear in its
        -- title. Matching is case-insensitive and on a substring, so
        -- "MOUSE GRID" catches "🎯 MOUSE GRID (⇪X — type 3 letters …)"
        -- without anyone having to keep the full title in two places.
        -- 🔤 6.66.1 — EMPTY, ON REQUEST: "Alphabetize my shortcut list".
        -- 6.65.0 pinned Mouse Grid and Tool Picker above the A–Z run,
        -- which was also asked for at the time ("put the grid first, then
        -- alphabetize the rest"). Those two instructions do not agree, and
        -- the later one wins. Pure A–Z is also the more defensible answer:
        -- alphabetical is the only order you can PREDICT without having
        -- read the file, and a pinned section is one you have to remember
        -- is pinned before you can find anything else.
        --
        -- ✏️ TO PIN ONE BACK: put words from its title in here. Matching is
        -- case-insensitive and on a substring, so "MOUSE GRID" catches
        -- "🎯 MOUSE GRID (⇪X — type 3 letters …)". Pinned sections keep the
        -- order they are listed in, not alphabetical among themselves.
        -- Read from the namespace so a test (and you, from the Console)
        -- can set it without editing this file.
        local pinned = cheatSheet.pinned or { }

        -- The title carries a leading emoji and, usually, a parenthetical
        -- naming the key. Neither should decide alphabetical position —
        -- sorting on the raw string files most of the sheet under whatever
        -- emoji happens to lead, which is not an order anyone can predict.
        local function sortKey(title)
            return (tostring(title or "")
                :gsub("^[^%a]*", "")          -- drop leading emoji/spaces
                :gsub("%s*%b()%s*$", "")      -- drop a trailing (⇪X — …)
                :upper())
        end

        for _, g in ipairs(groups) do
            if (g.order or 500) == 0 then
                g.band, g.key = 0, ""                    -- broken modules
            elseif (g.order or 500) >= 900 then
                g.band, g.key = 3, sortKey(g.title)      -- ⭐ custom
            else
                g.band, g.key = 2, sortKey(g.title)
                local up = tostring(g.title or ""):upper()
                for i, p in ipairs(pinned) do
                    if up:find(p, 1, true) then
                        -- The pin's own index is the sort key, so pinned
                        -- sections keep the order they are listed in above
                        -- rather than falling back to alphabetical.
                        g.band, g.key = 1, string.format("%03d", i)
                        break
                    end
                end
            end
        end

        -- Assemble. table.sort in Lua is NOT stable, so equal keys could
        -- shuffle between reloads and the sheet would quietly reorder
        -- itself. The tie-break on `order` is what makes this total: two
        -- groups can share a title band and a sort key, but their load
        -- order is unique.
        table.sort(groups, function(a, b)
            if a.band ~= b.band then return a.band < b.band end
            if a.key  ~= b.key  then return a.key  <  b.key  end
            return (a.order or 500) < (b.order or 500)
        end)
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

    -- =====================================================================
    -- 🔎 SEARCH (6.66.0) — type while the sheet is open
    -- =====================================================================
    -- LL asked for this twice, and the first answer was a separate
    -- hs.chooser window (⇪⇧/) with the reasoning that "a canvas cannot take
    -- keyboard focus". That reasoning was too quick. A canvas cannot take
    -- FOCUS, true — but it does not need to. Mouse Grid has captured bare
    -- letters over a canvas overlay since 6.45.0: bind the keys, keep the
    -- typed string yourself, and draw it. Same technique, and it keeps the
    -- 20pt text and the translucency that made this sheet worth having.
    --
    -- 🚨 THE TRADE, AND IT IS A REAL ONE: while the sheet is open it now
    -- CAPTURES LETTERS. You cannot type into another window without
    -- closing it first. That is the same bargain Mouse Grid makes, with
    -- the same safety property behind it — whenever keys are being taken
    -- there is something on screen saying so, and this panel is about as
    -- visible as an overlay gets. Two ways out, unchanged: ⇪/ and Esc.
    --
    -- Esc CLEARS the query before it closes the sheet, so a search you did
    -- not mean costs one keypress rather than a close-and-reopen.
    cheatSheet.query = ""

    -- 🧨 PLAIN TEXT, NEVER A PATTERN — the same rule the Tool Picker
    -- documents, and it matters more here: this sheet is a wall of ⇪[ ⇪\
    -- ⇪- ⇪/ ⇪= and every one of those is an operator in Lua's pattern
    -- engine. Typing one into a box that fed the pattern engine would hand
    -- it a malformed pattern and throw. Every find() below passes `true`.
    -- Words match in ANY ORDER and ALL must match.
    function cheatSheet.matches(hay, query)
        if query == nil or query:match("^%s*$") then return true end
        hay = hay:lower()
        for word in query:lower():gmatch("%S+") do
            if not hay:find(word, 1, true) then return false end
        end
        return true
    end

    -- Groups filtered to the entries that match. A group whose TITLE
    -- matches keeps all of its entries — searching "grid" should show you
    -- the whole Mouse Grid section, not just the rows with "grid" in them.
    function cheatSheet.filtered()
        local all = cheatSheet.groups()
        if cheatSheet.query == "" then return all, nil end
        local out, shown = {}, 0
        for _, g in ipairs(all) do
            local title = tostring(g.title or "")
            if cheatSheet.matches(title, cheatSheet.query) then
                out[#out + 1] = g
                shown = shown + #(g.entries or {})
            else
                local keep = {}
                for _, e in ipairs(g.entries or {}) do
                    if cheatSheet.matches(tostring(e[1] or "") .. " "
                                          .. tostring(e[2] or ""), cheatSheet.query) then
                        keep[#keep + 1] = e
                    end
                end
                if #keep > 0 then
                    out[#out + 1] = { title = title, entries = keep, order = g.order }
                    shown = shown + #keep
                end
            end
        end
        return out, shown
    end

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

    -- 🚨 6.66.5 — keepInput: TEAR DOWN THE CANVAS, NOT THE KEYBOARD.
    --
    -- LL's Console, seventeen times in two seconds:
    --      hs.hotkey system callback for an eventUID we don't know about: 0
    -- That is Hammerspoon receiving a key event for a hotkey it has just
    -- been told to forget. The cause was mine: typing into the sheet calls
    -- show() to rebuild the filtered rows, show() calls hide() first so it
    -- can never stack two panels, and hide() disabled all THIRTY-EIGHT
    -- search keys — which enableInput() then immediately re-enabled.
    --
    -- SEVENTY-SIX hotkey operations per character typed, with real key
    -- events arriving in the middle of them. Nothing broke, but the churn
    -- is absurd and the warnings are the system telling us so.
    --
    -- A redraw now passes keepInput = true: the canvas is rebuilt, the
    -- keyboard is left exactly as it is. Only a real close touches it.
    function cheatSheet.hide(keepInput)
        if keepInput then
            -- Canvas only. Every key stays bound, because the sheet is not
            -- going away — it is being repainted with fewer rows.
            if _G.cheatSheetCanvas then
                pcall(function() _G.cheatSheetCanvas:delete() end)
                _G.cheatSheetCanvas = nil
            end
            _G.cheatSheetState = nil
            return
        end
        if _G.cheatSheetEscHotkey then
            pcall(function() _G.cheatSheetEscHotkey:disable() end)
        end
        for _, hk in ipairs(_G.cheatSheetScrollKeys or {}) do
            pcall(function() hk:disable() end)
        end
        -- 🚨 GIVE THE ALPHABET BACK. These are BARE letter keys, so leaving
        -- one enabled after the sheet is gone means a keyboard that types
        -- into nothing — the single worst failure this file could have, and
        -- the reason every disable here is its own pcall: one that throws
        -- must not stop the next thirty-six from running.
        for _, hk in ipairs(_G.cheatSheetSearchKeys or {}) do
            pcall(function() hk:disable() end)
        end
        -- Cleared on close, so ⇪/ always opens on the full list. A sheet
        -- that reopened still filtered by yesterday's search would look
        -- like most of your shortcuts had disappeared.
        cheatSheet.query = ""
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

        -- 🔎 The title doubles as the search box. A separate field would
        -- mean re-laying out the panel and a second thing that can be out
        -- of step with the rows below it; the title is already centred,
        -- already the right size, and already redrawn on every keystroke.
        -- The ▏ is a caret, so it is obvious the sheet is taking your keys.
        local titleText, titleColor = "⌨️  Hammerspoon Shortcuts", { white = 1 }
        if cheatSheet.query ~= "" then
            titleText = "🔎  " .. cheatSheet.query .. "▏"
            if cheatSheet.matchCount then
                titleText = titleText .. "   ·   " .. cheatSheet.matchCount
                    .. (cheatSheet.matchCount == 1 and " match" or " matches")
            end
            -- Amber while filtering: the same colour the Mouse Grid uses to
            -- say "you are narrowing something", for the same reason.
            titleColor = { red = 1.00, green = 0.84, blue = 0.00 }
        end
        table.insert(els, {
            type = "text", text = titleText,
            textSize = st.titleSize, textColor = titleColor, textAlignment = "center",
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
    -- ---- typing into the sheet ------------------------------------------
    -- Scroll position resets to the top on every keystroke: after filtering
    -- you are looking at a different, shorter list, and keeping row 40 of
    -- the old one would leave you staring at blank space wondering whether
    -- the search found nothing.
    function cheatSheet.typeChar(ch)
        if not _G.cheatSheetCanvas then return end
        cheatSheet.query = cheatSheet.query .. ch
        -- show(), not render(): the ROWS are built in show(), so render()
        -- alone would repaint a new title over an unfiltered list.
        cheatSheet.show(false)
    end

    function cheatSheet.backspace()
        if not _G.cheatSheetCanvas then return end
        if cheatSheet.query == "" then return end
        -- ⚠️ BYTES ARE NOT CHARACTERS. A query can contain a multi-byte
        -- glyph, and lopping one byte off the end of a UTF-8 sequence
        -- leaves a malformed string that hs.canvas will not draw. Step back
        -- to the previous CHARACTER boundary instead.
        local q = cheatSheet.query
        local cut = #q
        if utf8 and utf8.offset then
            local n = utf8.len(q)
            if n and n > 0 then cut = (utf8.offset(q, n) or #q) - 1 end
        end
        cheatSheet.query = q:sub(1, math.max(0, cut))
        cheatSheet.show(false)
    end

    -- Esc CLEARS before it CLOSES. A mistyped search costing a
    -- close-and-reopen is the kind of small friction that stops people
    -- using a feature at all.
    function cheatSheet.escape()
        if cheatSheet.query ~= "" then
            cheatSheet.query = ""
            cheatSheet.show(false)
            return
        end
        cheatSheet.hide()
    end

    function cheatSheet.enableInput()
        if not _G.cheatSheetEscHotkey then
            local ok, hk = pcall(hs.hotkey.new, {}, "escape", cheatSheet.escape)
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

        -- 🔎 THE SEARCH KEYS. Built once and reused, like everything else
        -- here: rebuilding hotkeys per open is how a config ends up with
        -- two objects bound to one key, one of which nothing can disable.
        --
        -- 🚨 THIS IS WHAT CAPTURES YOUR KEYBOARD. Letters, digits, space
        -- and backspace are taken while the sheet is visible and given
        -- back the moment it closes. Bare keys, no modifier — which is
        -- exactly what makes it a search box and exactly what makes it a
        -- thing that must never be left enabled. disableInput() is called
        -- from hide(), which every exit path goes through.
        if not _G.cheatSheetSearchKeys then
            local keys = {}
            local function claim(k, fn)
                local ok, hk = pcall(hs.hotkey.new, {}, k, fn, nil, fn)
                if ok and hk then keys[#keys + 1] = hk end
            end
            for c in ("abcdefghijklmnopqrstuvwxyz0123456789"):gmatch(".") do
                claim(c, function() cheatSheet.typeChar(c) end)
            end
            claim("space",  function() cheatSheet.typeChar(" ") end)
            claim("delete", cheatSheet.backspace)
            _G.cheatSheetSearchKeys = keys
        end
        for _, hk in ipairs(_G.cheatSheetSearchKeys or {}) do
            pcall(function() hk:enable() end)
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
        -- 🚨 SAVE THE QUERY ACROSS OUR OWN hide(). hide() clears it — which
        -- is right for closing the sheet and wrong for redrawing it, and
        -- show() begins by calling hide() so it can never stack two panels.
        -- Without this, typing one letter filtered the list and then
        -- immediately unfiltered it, which reads as "the search does
        -- nothing" rather than as a bug.
        local keepQuery = cheatSheet.query
        -- keepInput: this hide() is a REDRAW, not a close. See the 🚨 on
        -- hide() — tearing down 38 hotkeys per keystroke is what produced
        -- the "eventUID we don't know about" warnings.
        cheatSheet.hide(true)
        cheatSheet.query = keepQuery

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
        -- Clamped to the screen, never beyond it: a 1024-wide panel on a
        -- 1280-wide laptop is fine, on a 900-wide one it would hang off.
        local wantW    = cheatSheet.width  or 1024
        local panelW   = math.max(360, math.min(wantW, sf.w * 0.90))
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
        -- ⚠️ ON THE NAMESPACE, NOT ON `st`. This block runs inside show(),
        -- which BUILDS the state table further down — `st` does not exist
        -- yet here. render() reads it back on every keystroke, and it
        -- outlives any one state table, which is what we want anyway.
        local groupList, matchCount = cheatSheet.filtered()
        cheatSheet.matchCount = matchCount
        if #groupList == 0 then
            table.insert(lines, { kind = "header",
                                  text = "no shortcut matches \"" .. cheatSheet.query .. "\"" })
            table.insert(lines, { kind = "entry",
                                  text = "      ⌫ to edit  ·  esc to clear" })
        end
        for gi, g in ipairs(groupList) do
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
        -- ⚠️ THE 86% CEILING STAYS, and it is not decoration. The first
        -- version of this clamped to sf.h - 40, which on a 1280x800
        -- laptop produced a 760pt panel — 95% of the usable screen, a
        -- wall rather than a panel, pressed against both edges. The
        -- suite caught it. On a big display 768 is well under the
        -- ceiling and wins; on a small one the ceiling wins. Neither
        -- ever exceeds the screen.
        local wantH      = math.min(cheatSheet.height or 768, sf.h * 0.86)
        local panelH     = math.min(wantH, chromeH + #lines * lineH)
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
        -- 🚨 GUARDED, AND enableInput() RUNS EITHER WAY. An unprotected
        -- show() that throws (see _G.showCanvasSafely in init.lua — an
        -- AppKit assertion raised inside ANOTHER app's remote view)
        -- abandoned the rest of this function, leaving _G.cheatSheetCanvas
        -- set, the panel half-ordered on screen, and the scroll keys
        -- unbound. ⇪/ then only ever called hide(). The phantom panel was
        -- not the throw; it was everything after the throw not happening.
        if _G.showCanvasSafely then
            _G.showCanvasSafely(canvas, "cheat sheet")
        else
            pcall(function() canvas:show() end)
        end

        cheatSheet.enableInput()
    end

    function cheatSheet.toggle()
        if _G.cheatSheetCanvas then
            cheatSheet.hide()
        else
            cheatSheet.show()
        end
    end

    hs.hotkey.bind(popupScreenKeys.mods, cheatSheet.key, cheatSheet.toggle)

    -- ⌃⌥⌘= — add a custom entry to the sheet, persisted across reloads.
    -- Same pipe format as the task creator: Keys | Description | Group
    -- (group optional, defaults to CUSTOM). Example:
    --   ⌘⇧5 | Screenshot & recording menu | MACOS
    hs.hotkey.bind(popupScreenKeys.mods, cheatSheet.addKey, function()
        local button, text = hs.dialog.textPrompt(
            "⭐ Add cheat sheet entry",
            "Format:  Keys | Description | Group     (Group is optional)\nExample:  ⌘⇧5 | Screenshot menu | MACOS",
            "", "Add", "Cancel")
        if button ~= "Add" or not text or #text == 0 then return end

        local parts = {}
        for seg in text:gmatch("([^|]+)") do
            table.insert(parts, seg:match("^%s*(.-)%s*$"))
        end
        local keys, desc, group = parts[1] or "", parts[2] or "", parts[3] or ""
        if keys == "" or desc == "" then
            hs.alert.show("⚠️ Need at least: Keys | Description")
            return
        end

        table.insert(_G.customShortcuts, { keys = keys, desc = desc, group = group })
        cheatSheet.saveCustom(_G.customShortcuts)
        hs.alert.show("⭐ Added to cheat sheet")

        -- If the sheet is open right now, redraw it with the new entry
        if _G.cheatSheetCanvas then cheatSheet.show(true) end
    end)

    -- ⌃⌥⌘- — remove a custom entry: opens a picker of everything you've
    -- added; selecting one deletes it from custom_shortcuts.json. Built-in
    -- entries never appear here — they can't be deleted this way.
    cheatSheet.removeKey = "-"

    _G.choosers.removeShortcut = hs.chooser.new(function(choice)
        if not (choice and choice.idx) then return end
        local removed = table.remove(_G.customShortcuts, choice.idx)
        cheatSheet.saveCustom(_G.customShortcuts)
        hs.alert.show("🗑 Removed: " .. (removed and removed.keys or "entry"))
        if _G.cheatSheetCanvas then cheatSheet.show(true) end
    end)
    _G.choosers.removeShortcut:placeholderText("Select a custom entry to DELETE — Esc cancels")

    hs.hotkey.bind(popupScreenKeys.mods, cheatSheet.removeKey, function()
        if #_G.customShortcuts == 0 then
            hs.alert.show("⭐ No custom entries yet — add one with ⌃⌥⌘=")
            return
        end
        local choices = {}
        for i, c in ipairs(_G.customShortcuts) do
            table.insert(choices, {
                text    = (c.keys or "?") .. "  —  " .. (c.desc or ""),
                subText = "🗑 Deletes on select  ·  group: " .. ((c.group and c.group ~= "") and c.group or "CUSTOM"),
                idx     = i,
            })
        end
        _G.choosers.removeShortcut:choices(choices)
        showPopup(_G.choosers.removeShortcut)
    end)

    -- ⌃⌥⌘E — edit a custom entry: opens the same style of picker, but
    -- selecting an entry re-opens the add dialog PRE-FILLED with its
    -- current values. Change what you want, keep the pipe format, hit
    -- Save — the entry is updated in place (same position, same file).
    -- Esc at either step cancels without changing anything.
    cheatSheet.editKey = "E"

    _G.choosers.editShortcut = hs.chooser.new(function(choice)
        if not (choice and choice.idx) then return end
        local c = _G.customShortcuts[choice.idx]
        if not c then return end

        local current = (c.keys or "") .. " | " .. (c.desc or "")
        if c.group and c.group ~= "" then
            current = current .. " | " .. c.group
        end

        local button, text = hs.dialog.textPrompt(
            "✏️ Edit cheat sheet entry",
            "Format:  Keys | Description | Group     (Group is optional)",
            current, "Save", "Cancel")
        if button ~= "Save" or not text or #text == 0 then return end

        local parts = {}
        for seg in text:gmatch("([^|]+)") do
            table.insert(parts, seg:match("^%s*(.-)%s*$"))
        end
        local keys, desc, group = parts[1] or "", parts[2] or "", parts[3] or ""
        if keys == "" or desc == "" then
            hs.alert.show("⚠️ Need at least: Keys | Description — entry unchanged")
            return
        end

        _G.customShortcuts[choice.idx] = { keys = keys, desc = desc, group = group }
        cheatSheet.saveCustom(_G.customShortcuts)
        hs.alert.show("✏️ Updated: " .. keys)
        if _G.cheatSheetCanvas then cheatSheet.show(true) end
    end)
    _G.choosers.editShortcut:placeholderText("Select a custom entry to EDIT — Esc cancels")

    hs.hotkey.bind(popupScreenKeys.mods, cheatSheet.editKey, function()
        if #_G.customShortcuts == 0 then
            hs.alert.show("⭐ No custom entries yet — add one with ⌃⌥⌘=")
            return
        end
        local choices = {}
        for i, c in ipairs(_G.customShortcuts) do
            table.insert(choices, {
                text    = (c.keys or "?") .. "  —  " .. (c.desc or ""),
                subText = "✏️ Opens pre-filled editor  ·  group: " .. ((c.group and c.group ~= "") and c.group or "CUSTOM"),
                idx     = i,
            })
        end
        _G.choosers.editShortcut:choices(choices)
        showPopup(_G.choosers.editShortcut)
    end)

    -- Handed back so a test can drive the real namespace without this
    -- file having to publish a global purely for testing. init.lua
    -- ignores it; tests/test_cheatsheet.lua runs against it.
    return cheatSheet
end
