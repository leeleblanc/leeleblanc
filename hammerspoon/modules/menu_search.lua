-- =====================================================================
-- MODULE: MENU SEARCH (⇪.) — every menu of the front app, by typing
-- =====================================================================
-- LL: "For the focused application, can you create something to search
-- through menu options for front-most application"
--
-- Press ⇪. and every menu item the frontmost app publishes is one flat
-- list you can type into. "pdf" finds File ▸ Export As ▸ PDF… without
-- knowing it was under Export. ⏎ picks it exactly as the pointer would.
--
--        ⇪.         search the front app's menus
--        ⇪⇧.        is NOT this — that is the network tools
--
-- 🔎 THE POINT IS THE ITEMS YOU CANNOT FIND. Every Mac app has a command
-- you use twice a year and can never remember the menu for, and the
-- macOS Help menu's own search is the only general answer — which opens
-- Help, hovers a blue arrow at the item, and is slower than giving up.
-- This is that, without the theatre: the same accessibility tree Help
-- reads, flattened once, filtered as you type.
--
-- ---------------------------------------------------------------------
-- 🚨 WHY THE SCAN IS ASYNCHRONOUS, AND WHY THAT IS NOT OPTIONAL
-- ---------------------------------------------------------------------
-- hs.application:getMenuItems() has two forms. The one that returns a
-- table BLOCKS until every menu and submenu of the app has answered over
-- the accessibility bridge — and Hammerspoon's own documentation warns
-- that this "can take a very long time". On an app with deep menus
-- (Word, Excel, anything with a Scripts menu enumerating a folder) the
-- blocking form freezes the keyboard for as long as it takes, and a
-- keyboard that stops answering is indistinguishable from a crash.
--
-- So the callback form is what runs, and the panel opens when the answer
-- arrives. If nothing has arrived by ms.scanTimeout the press is
-- abandoned with a line saying which app did not answer — a named
-- refusal, rather than a key that sometimes does nothing.
--
-- ⚠️ THE SYNC FORM IS STILL USED, in exactly one place: when the async
-- call is not available at all (older Hammerspoon), where a slow answer
-- beats no feature. It is wrapped in the same timeout accounting so the
-- report can say which path ran.
--
-- ---------------------------------------------------------------------
-- 🚫 DISABLED ITEMS ARE SHOWN, AND REFUSE TO RUN
-- ---------------------------------------------------------------------
-- A greyed-out menu item is still the item you were looking for, and
-- hiding it answers "where is Paste Special?" with an empty list —
-- which reads as "this app has no Paste Special" rather than "not right
-- now". So they stay, marked · unavailable right now, and picking one
-- says why instead of pretending. Set ms.hideDisabled = true to drop
-- them if you disagree.
--
-- ⚠️ AXEnabled IS THE APP'S OPINION, and some apps never set it. An item
-- that reports nothing is treated as ENABLED, because refusing to run a
-- working item is the worse of the two mistakes.
--
-- ---------------------------------------------------------------------
-- WHAT IT DOES NOT DO
-- ---------------------------------------------------------------------
-- It does not reach into another app's windows, buttons or toolbars —
-- only its menu bar, which is the one surface every Mac app publishes in
-- a standard shape. It cannot see menus an app builds lazily when you
-- click them (a few apps populate a submenu only on open); those show as
-- the parent item with no children, and picking the parent opens it.
-- =====================================================================

local M = {
    name  = "Menu Search",
    order = 13.91,
    family = "find",
    cheatsheet = {
        title = "🔎 MENU SEARCH (⇪. — the front app's menus, by typing)",
        entries = {
            { "⇪.",     "Every menu item of the front app — type to filter, ⏎ picks it" },
            { "finds",  "The path too: “pdf” matches File ▸ Export As ▸ PDF…" },
            { "shows",  "The keyboard shortcut for each item, where one exists" },
            { "greyed", "Unavailable items still listed, marked, and refuse to run" },
            { "needs",  "Accessibility. Without it, it says so and does nothing." },
            { "check",  "_G.menuSearchReport() — last scan, its app, and how long" },
        },
    },
}

function M.setup(core)
    local ms = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ms.enabled      = true
    ms.key          = "."          -- ⇪.  (⇪⇧. is the network tools)
    ms.keyMods      = {}
    -- 🚨 How long to wait for an app to describe its menus before giving
    -- up on the press. This is the freeze guard, not a tuning knob: the
    -- scan itself is asynchronous, so this only decides how long the
    -- "reading the menus…" state lasts before it becomes a refusal.
    ms.scanTimeout  = 4.0
    ms.scanTick     = 0.05
    -- Repeated presses inside this window reuse the last scan of the SAME
    -- app. Menus change with selection (Undo becomes "Undo Typing"), so
    -- this is deliberately short — long enough to cover reopening the
    -- panel you just closed, too short to show you a stale Undo.
    ms.cacheSecs    = 3
    ms.maxDepth     = 6            -- submenu nesting to follow
    ms.maxItems     = 4000         -- hard cap, so a pathological app cannot
                                   -- build a list nothing can render
    ms.hideDisabled = false        -- true = drop greyed-out items entirely
    ms.sep          = "  ▸  "      -- how a menu path is drawn
    -- ----------------------------------------------------------------------

    ms.chooser   = nil    -- HELD: an unreferenced hs.chooser is collected
    ms.timer     = nil    -- HELD: ditto an hs.timer
    ms.rows      = {}     -- index -> { path = {...}, enabled = bool }
    ms.cache     = nil    -- { app = pid, at = t, rows = {...}, choices = {...} }
    ms.pending   = false
    ms.lastApp   = nil
    ms.lastMs    = 0
    ms.lastCount = 0
    ms.lastPath  = "async"
    ms.lastNote  = nil
    ms.scans     = 0

    local function say(m)  if _G.diag then _G.diag.say("menuSearch", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("menuSearch", m) end end

    local function axOK()
        local ok, granted = pcall(hs.accessibilityState)
        return ok and granted == true
    end

    -- ---- the shortcut column ---------------------------------------------
    -- AXMenuItemCmdModifiers is a bitmask and its ZERO VALUE MEANS ⌘, not
    -- "no modifiers" — bit 3 is the flag that says "no command key". Get
    -- that backwards and every ⌘-shortcut in the list renders bare, which
    -- is worse than showing nothing: it teaches you a key that does not
    -- work. The bits, from Apple's NSMenuItem carbon mapping:
    --      1 = ⇧      2 = ⌥      4 = ⌃      8 = NO ⌘
    local function modString(mask)
        if type(mask) ~= "number" then return "" end
        local out = {}
        if mask % 16 >= 8 then
            -- bit 3 set: no command key at all
        else
            out[#out + 1] = "⌘"
        end
        if mask % 8 >= 4 then table.insert(out, 1, "⌃") end
        if mask % 4 >= 2 then table.insert(out, 1, "⌥") end
        if mask % 2 >= 1 then table.insert(out, 1, "⇧") end
        return table.concat(out)
    end

    -- The character itself. Apps report either a printable char
    -- (AXMenuItemCmdChar) or a virtual keycode for the keys that have no
    -- character — the arrows, ⌫, ⇥, ⏎. Only the ones worth drawing are
    -- named; anything else is left blank rather than guessed at, because a
    -- wrong key in this column is a lie you act on.
    ms.glyphs = {
        [0x7F] = "⌫", [0x0D] = "⏎", [0x03] = "⌤", [0x09] = "⇥",
        [0x1B] = "⎋", [0x20] = "space",
        [0x1C] = "←", [0x1D] = "→", [0x1E] = "↑", [0x1F] = "↓",
    }

    local function shortcutFor(item)
        local ch = item.AXMenuItemCmdChar
        local gl = item.AXMenuItemCmdGlyph
        local key = nil
        if type(ch) == "string" and ch ~= "" then
            key = ch:upper()
        elseif type(gl) == "number" and ms.glyphs[gl] then
            key = ms.glyphs[gl]
        end
        if not key then return "" end
        return modString(item.AXMenuItemCmdModifiers) .. key
    end

    -- ---- flattening ------------------------------------------------------
    -- getMenuItems() hands back a tree whose shape is: a list of menus,
    -- each with AXChildren = { <the list of its items> }. Note the extra
    -- level — AXChildren is a table CONTAINING the item list, not the item
    -- list itself. Walking it as if it were the list directly finds zero
    -- items and reports success, which is the exact failure this comment
    -- exists to stop somebody re-introducing.
    local function childList(node)
        local c = node and node.AXChildren
        if type(c) ~= "table" then return nil end
        if type(c[1]) == "table" and c[1].AXTitle ~= nil then
            -- already the item list (some apps flatten one level)
            return c
        end
        if type(c[1]) == "table" then return c[1] end
        return nil
    end

    -- An item with children is a SUBMENU HEADING. It is listed too — some
    -- submenus are worth opening by hand, and an app that fills a submenu
    -- lazily reports it as childless until you do — but it is listed after
    -- its children have been walked, so the leaf you actually want ranks
    -- alongside it rather than under it.
    function ms.flatten(menus)
        local rows = {}
        local function walk(items, trail, depth)
            if depth > ms.maxDepth then return end
            for _, item in ipairs(items or {}) do
                if #rows >= ms.maxItems then return end
                local title = item.AXTitle
                if type(title) == "string" and title ~= "" then
                    local path = {}
                    for _, t in ipairs(trail) do path[#path + 1] = t end
                    path[#path + 1] = title
                    local kids = childList(item)
                    -- AXEnabled unset is treated as enabled — see the header.
                    local enabled = (item.AXEnabled ~= false)
                    rows[#rows + 1] = {
                        path     = path,
                        enabled  = enabled,
                        submenu  = kids ~= nil,
                        shortcut = shortcutFor(item),
                        mark     = type(item.AXMenuItemMarkChar) == "string"
                                   and item.AXMenuItemMarkChar ~= "" or false,
                    }
                    if kids then walk(kids, path, depth + 1) end
                end
            end
        end
        for _, menu in ipairs(menus or {}) do
            local title = menu.AXTitle
            local kids  = childList(menu)
            if type(title) == "string" and title ~= "" and kids then
                walk(kids, { title }, 1)
            end
        end
        return rows
    end

    -- ---- rows the chooser can carry --------------------------------------
    -- ⚠️ EVERY VALUE IN A CHOOSER ROW CROSSES INTO OBJECTIVE-C. A nested
    -- table does not survive that trip, and when one fails LuaSkin discards
    -- the WHOLE list and logs to the Console rather than throwing — so the
    -- panel opens empty and the pcall around :choices() sees nothing wrong.
    -- The menu PATH is a table, so it stays here in Lua and the row carries
    -- a plain integer index into ms.rows. Same rule, same reason, as the
    -- snippet chooser (text_expander 6.109.0).
    function ms.choicesFrom(rows)
        local choices = {}
        for i, r in ipairs(rows) do
            if r.enabled or not ms.hideDisabled then
                local leaf = r.path[#r.path]
                local trail = {}
                for n = 1, #r.path - 1 do trail[#trail + 1] = r.path[n] end
                local sub = #trail > 0 and table.concat(trail, ms.sep) or "menu bar"
                if r.shortcut ~= "" then sub = sub .. "   ·   " .. r.shortcut end
                if r.mark            then sub = sub .. "   ·   ✓ on" end
                if r.submenu         then sub = sub .. "   ·   submenu" end
                if not r.enabled     then sub = sub .. "   ·   unavailable right now" end
                choices[#choices + 1] = {
                    text    = (r.enabled and "" or "🚫  ") .. leaf,
                    subText = sub,
                    idx     = i,
                }
            end
        end
        return choices
    end

    -- ---- picking ---------------------------------------------------------
    function ms.pick(idx, app)
        local r = ms.rows[idx]
        if not r then return false end
        if not r.enabled then
            hs.alert.show("🔎 “" .. r.path[#r.path]
                .. "” is greyed out right now — the app is refusing it,\n"
                .. "not this list", 4)
            return false
        end
        if not app then return false end
        local ok, done = pcall(function() return app:selectMenuItem(r.path) end)
        if ok and done then
            say("selected " .. table.concat(r.path, " ▸ "))
            return true
        end
        ms.lastNote = "selectMenuItem refused " .. table.concat(r.path, " ▸ ")
        warn(ms.lastNote)
        hs.alert.show("🔎 “" .. r.path[#r.path] .. "” did not respond", 3)
        return false
    end

    -- ---- opening ---------------------------------------------------------
    local function frontApp()
        local ok, app = pcall(hs.application.frontmostApplication)
        if ok and app then return app end
        return nil
    end

    function ms.present(app, rows, choices)
        ms.rows = rows
        if #choices == 0 then
            hs.alert.show("🔎 " .. app:name()
                .. " published no menu items this list can read", 3.5)
            return
        end
        if not ms.chooser then
            ms.chooser = hs.chooser.new(function(pick)
                if not pick then return end
                ms.pick(pick.idx, ms.pickApp)
            end)
            -- ⎋ filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.menuSearch = ms.chooser
            pcall(function()
                ms.chooser:searchSubText(true)
                ms.chooser:width(40)
            end)
        end
        ms.pickApp = app
        ms.chooser:choices(choices)
        ms.chooser:placeholderText(("%s — %d menu items, type to filter")
                                   :format(app:name(), #choices))
        ms.chooser:query("")
        ms.chooser:show()
    end

    function ms.show()
        if not ms.enabled then return end
        if not axOK() then
            hs.alert.show("🔎 Menu search needs Accessibility —\nSystem "
                .. "Settings → Privacy & Security → Accessibility", 4)
            return
        end
        if ms.pending then return end
        local app = frontApp()
        if not app then
            hs.alert.show("🔎 No frontmost application", 2.5)
            return
        end
        ms.lastApp = app:name()

        -- Same app, seconds ago: reuse it rather than making the bridge
        -- describe an unchanged menu bar again.
        local now = hs.timer.secondsSinceEpoch()
        if ms.cache and ms.cache.pid == app:pid()
           and (now - ms.cache.at) < ms.cacheSecs then
            ms.present(app, ms.cache.rows, ms.cache.choices)
            return
        end

        local t0 = now
        local function finish(menus, path)
            ms.pending = false
            if ms.timer then pcall(function() ms.timer:stop() end) ms.timer = nil end
            ms.lastMs   = math.floor((hs.timer.secondsSinceEpoch() - t0) * 1000)
            ms.lastPath = path
            ms.scans    = ms.scans + 1
            if type(menus) ~= "table" then
                ms.lastNote = app:name() .. " returned no menu tree"
                warn(ms.lastNote)
                hs.alert.show("🔎 " .. app:name() .. " did not describe its menus", 3.5)
                return
            end
            local rows    = ms.flatten(menus)
            local choices = ms.choicesFrom(rows)
            ms.lastCount  = #rows
            ms.cache = { pid = app:pid(), at = hs.timer.secondsSinceEpoch(),
                         rows = rows, choices = choices }
            ms.present(app, rows, choices)
        end

        -- The asynchronous form, which is the one that matters. See the
        -- header: the blocking form can hold the keyboard for seconds.
        local started = false
        if type(app.getMenuItems) == "function" then
            started = pcall(function()
                app:getMenuItems(function(menus) finish(menus, "async") end)
            end)
        end
        if not started then
            -- No callback form available. Take the slow road rather than
            -- refusing the feature, and record that we did.
            local ok, menus = pcall(function() return app:getMenuItems() end)
            finish(ok and menus or nil, "sync")
            return
        end

        ms.pending = true
        hs.alert.show("🔎 Reading " .. app:name() .. "’s menus…", ms.scanTimeout)
        ms.timer = hs.timer.doAfter(ms.scanTimeout, function()
            if not ms.pending then return end
            ms.pending  = false
            ms.timer    = nil
            ms.lastNote = app:name() .. " did not answer within "
                          .. ms.scanTimeout .. "s"
            warn(ms.lastNote)
            if _G.notices then
                _G.notices.record("menuSearch", "menu scan timed out", ms.lastNote)
            end
            hs.alert.show("🔎 " .. app:name() .. " did not answer in "
                .. ms.scanTimeout .. "s — its menus are too deep, or it is busy", 4)
        end)
    end

    -- ---- the report ------------------------------------------------------
    function _G.menuSearchReport()
        local L = { "🔎 MENU SEARCH" }
        L[#L + 1] = "   accessibility : " ..
            (axOK() and "granted" or "OFF — nothing can be read")
        L[#L + 1] = "   scans         : " .. ms.scans .. " this session"
        if ms.lastApp then
            L[#L + 1] = "   last app      : " .. ms.lastApp
            L[#L + 1] = string.format("   last scan     : %d items in %dms (%s)",
                ms.lastCount, ms.lastMs, ms.lastPath)
        else
            L[#L + 1] = "   last app      : never — ⇪. has not been pressed"
        end
        if ms.lastNote then
            L[#L + 1] = "   last problem  : " .. ms.lastNote
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if ms.enabled then
        core.hyperAddShortcut(ms.keyMods, ms.key, function() ms.show() end,
                              "menu search")
    end
    core.provide("menuSearch.show",   function() return ms.show() end)
    core.provide("menuSearch.report", function() return _G.menuSearchReport() end)

    _G.menuSearch = ms
    M.ms     = ms
    M.config = ms
end

return M
