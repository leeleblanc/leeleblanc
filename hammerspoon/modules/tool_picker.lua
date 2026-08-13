-- =====================================================================
-- MODULE: TOOL PICKER (⇪⇧/) — type what you want, get the tool
-- =====================================================================
-- THE PROBLEM THIS SOLVES, in LL's own words: "oh I need a URL tool" …
-- and then what? The cheat sheet (⇪/) is a beautiful thing to READ, but
-- reading is the wrong verb when you already know roughly what you want
-- and only need the name of it. Thirty-odd groups of entries is a lot of
-- scrolling to answer "what was the key for the link cleaner again".
--
-- So this is the other half of the same content: the SAME entries the
-- cheat sheet draws, in a search box, filtered as you type.
--
--        type "url"   → every URL tool in the config
--        type "clean" → the link cleaner, by its description
--        type "grid"  → the mouse grid
--
-- ⏎ RUNS IT if it can, rather than just telling you the shortcut. An
-- entry whose key maps to a published service is invoked directly; one
-- that does not is copied to the clipboard so the next thing you do is
-- press it. Both are useful; being told "⇪K" and left to press it
-- yourself is the least useful of the three, so it is the fallback.
--
-- 🔍 WHY NOT A SEARCH BOX ON THE CHEAT SHEET ITSELF? Because that sheet
-- is drawn on hs.canvas, and a canvas cannot take keyboard focus without
-- giving up the two things that make the sheet good: it floats WITHOUT
-- stealing focus (so it never interrupts typing) and it closes on Esc
-- without capturing Esc globally. A canvas with a text field is a
-- contradiction — this config already learned that in 6.31.1 on the other
-- branch, where adding search cost exactly those two properties.
-- hs.chooser is a native panel that is BUILT to be typed into. So: ⇪/ to
-- browse, ⇪⇧/ to search. Same data, two doors, neither one compromised.
--
-- ⚠️ WHAT IT CANNOT DO: hs.chooser picks its own row font and offers no
-- opacity API, so this window does not inherit the cheat sheet's 20pt
-- text or its translucency. That is a macOS limitation, not a decision —
-- the same one noted at §1.5 for every other picker in this config.

local M = {
    name  = "Tool Picker",
    order = 13.55,          -- next to the numpad layer and the grid
    cheatsheet = {
        title = "🔎 TOOL PICKER (⇪⇧/ — search every shortcut)",
        entries = {
            { "⇪⇧/",  "Search every tool by name, key or description" },
            { "type",  "Words match in any order — 'clean url' finds it" },
            { "⏎",     "Runs the tool if it can be run, else copies its key" },
            { "⇪/",    "The full cheat sheet, for reading rather than searching" },
        },
    },
}

function M.setup(core)
    local tp = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    tp.enabled = true
    tp.key     = "/"          -- ⇪⇧/ — the shifted twin of the cheat sheet
    tp.rows    = 12           -- visible rows before it scrolls
    tp.width   = 40           -- percent of screen width
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("toolPicker", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("toolPicker", m) end end

    -- ---- WHICH ENTRIES CAN ACTUALLY BE RUN -------------------------------
    -- A cheat sheet entry is two strings; it carries no idea of what it
    -- does. The service registry, on the other hand, is a table of things
    -- that CAN be done. This table is the join between them, and it is
    -- written by hand on purpose: guessing a service name from a
    -- description is exactly the kind of clever inference that works for
    -- twenty entries and then silently runs the wrong tool on the
    -- twenty-first.
    --
    -- Keyed by the cheat sheet's own key string, so adding a row here is
    -- how you make a newly published service runnable from this picker.
    -- ⚠️ EVERY VALUE HERE MUST BE A REAL SERVICE NAME. A typo does not
    -- throw — _G.service.call warns and returns — so a wrong name would
    -- make this picker report "ran it" while doing nothing at all. The
    -- names are checked against the live registry at first use (see
    -- tp.verify) and a bad one is reported once, loudly, rather than
    -- discovered the day you rely on it.
    tp.runnable = {
        ["⇪X"]    = "mouseGrid.show",
        ["⇪K"]    = "url.cleanClipboard",
        ["⇪⇧K"]   = "url.undo",
        ["⇪R"]    = "rename.show",
        ["⇪⇧R"]   = "rename.undo",
        ["⇪M"]    = "menuBar.show",
        ["⇪Q"]    = "focus.toggle",
        ["⇪⇧Q"]   = "focus.report",
        ["⇪⇧H"]   = "health.report",
        ["⇪⇧A"]   = "universalActions.show",
        ["⇪pad+"] = "pomodoro.toggle",
        ["⇪pad*"] = "mouseGrid.locate",
    }

    -- Run once, on the first press — not at setup(), because modules load
    -- in order and half the registry does not exist yet while this one is
    -- being set up. Reported through the ledger so a stale name shows up
    -- in the combined report instead of only in a console nobody has open.
    tp.verified = false
    function tp.verify()
        if tp.verified then return end
        if not (_G.service and _G.service.has) then return end
        tp.verified = true
        local missing = {}
        for keys, svc in pairs(tp.runnable) do
            if not _G.service.has(svc) then
                missing[#missing + 1] = keys .. " → " .. svc
            end
        end
        if #missing > 0 then
            table.sort(missing)   -- pairs() has no order; the report needs one
            local msg = table.concat(missing, ", ")
            warn("runnable entries name services that do not exist: " .. msg)
            if _G.notices then
                _G.notices.record("toolPicker", "unknown service in the run map", msg)
            end
        end
    end

    -- ---- BUILD THE CHOICES ----------------------------------------------
    -- Rebuilt on every press rather than cached at boot. The cheat sheet
    -- is assembled from whichever modules actually LOADED, and a module
    -- can fail to load — so a cached list would keep offering a tool that
    -- is not there this session. It is a few hundred string copies; the
    -- press is not measurably slower and the list cannot go stale.
    function tp.choices()
        local out = {}
        local okGroups, groups = pcall(function()
            return _G.cheatSheet and _G.cheatSheet.groups and _G.cheatSheet.groups() or nil
        end)
        if not (okGroups and groups) then
            warn("cheat sheet groups unavailable — the picker has nothing to list")
            return out
        end
        for _, g in ipairs(groups) do
            -- Strip the leading emoji and any trailing parenthetical so the
            -- subtitle reads as a plain group name.
            local gname = tostring(g.title or "")
                :gsub("^[^%w]*", "")
                :gsub("%s*%b()%s*$", "")
            for _, e in ipairs(g.entries or {}) do
                local keys = tostring(e[1] or "")
                local desc = tostring(e[2] or "")
                if keys ~= "" or desc ~= "" then
                    out[#out + 1] = {
                        text        = desc ~= "" and desc or keys,
                        subText     = keys .. "   ·   " .. gname,
                        keys        = keys,
                        service     = tp.runnable[keys],
                        -- The haystack the filter runs against. Lowercased
                        -- once here rather than per keystroke per row.
                        hay = (keys .. " " .. desc .. " " .. gname):lower(),
                    }
                end
            end
        end
        return out
    end

    -- ---- THE FILTER ------------------------------------------------------
    -- 🧨 PLAIN TEXT, NEVER A PATTERN. This config's shortcuts are written
    -- in ⇪[ ⇪\ ⇪- ⇪/ ⇪= and typing any of those into a box that fed Lua's
    -- pattern engine hands it a malformed pattern — "%" and "-" and "["
    -- are all operators there. Every find() below passes `true` as the
    -- fourth argument, which is what turns pattern matching off.
    --
    -- Words match in ANY ORDER and ALL must match, so "clean url" and
    -- "url clean" both find the link cleaner. That is the behaviour people
    -- expect from a search box and it costs one loop.
    function tp.filter(rows, query)
        query = tostring(query or ""):lower()
        if query:match("^%s*$") then return rows end
        local words = {}
        for w in query:gmatch("%S+") do words[#words + 1] = w end
        local keep = {}
        for _, r in ipairs(rows) do
            local all = true
            for _, w in ipairs(words) do
                if not r.hay:find(w, 1, true) then all = false break end
            end
            if all then keep[#keep + 1] = r end
        end
        return keep
    end

    -- ---- THE PICKER ------------------------------------------------------
    tp.chooser = nil     -- HELD: an unreferenced chooser is collected
    tp.rowsAll = {}

    function tp.show()
        if not tp.enabled then return false end
        -- Already up? Put it away. Same toggle contract as ⇪/ and ⇪X, so
        -- the key you opened it with is the key that closes it.
        if tp.chooser then
            local okVis, vis = pcall(function() return tp.chooser:isVisible() end)
            if okVis and vis then pcall(function() tp.chooser:hide() end) return true end
        end

        tp.verify()
        tp.rowsAll = tp.choices()
        if #tp.rowsAll == 0 then
            hs.alert.show("🔎 Tool Picker: nothing to list — see the Console")
            return false
        end

        if not tp.chooser then
            local okNew, c = pcall(hs.chooser.new, function(pick)
                if not pick then return end          -- Esc, and that is fine
                tp.run(pick)
            end)
            if not (okNew and c) then
                hs.alert.show("🔎 Tool Picker could not open — see the Console")
                warn("hs.chooser.new failed")
                return false
            end
            tp.chooser = c
            pcall(function()
                c:placeholderText("Search every tool — try 'url', 'grid', 'rename'")
                c:rows(tp.rows)
                c:width(tp.width)
                c:searchSubText(true)
                -- Our own filter, so multi-word-any-order works and so the
                -- query is never handed to Lua's pattern engine.
                c:queryChangedCallback(function(q)
                    pcall(function() c:choices(tp.filter(tp.rowsAll, q)) end)
                end)
            end)
        end

        pcall(function()
            tp.chooser:query("")
            tp.chooser:choices(tp.rowsAll)
            tp.chooser:show()
        end)
        say(string.format("opened with %d entries", #tp.rowsAll))
        return true
    end

    -- ⏎ — run it if we can, otherwise put the key where you can use it.
    function tp.run(pick)
        local keys = tostring(pick.keys or "")
        -- 🚨 has() BEFORE call(). _G.service.call does NOT throw on a
        -- missing provider — it prints and returns nil — so a pcall around
        -- it succeeds whether the service ran or never existed, and this
        -- picker would cheerfully report "ran it" while doing nothing.
        -- Checking first is the difference between a tool that works and
        -- one that only looks like it does.
        if pick.service and _G.service and _G.service.has
           and _G.service.has(pick.service) then
            local ok = pcall(function() _G.service.call(pick.service) end)
            if ok then
                say("ran " .. pick.service .. " (" .. keys .. ")")
                return true
            end
            -- A service that is registered but throws is a real failure and
            -- is reported as one — falling through to "here is the key"
            -- would look like the picker simply chose not to run it.
            warn("service '" .. pick.service .. "' failed when run from the picker")
            if _G.notices then
                _G.notices.record("toolPicker", "service failed", pick.service)
            end
        end
        if keys ~= "" then
            pcall(function() hs.pasteboard.setContents(keys) end)
            hs.alert.show("🔎 " .. keys .. "  (copied — press it)", 1.5)
        end
        return false
    end

    -- ---- wiring ----------------------------------------------------------
    if tp.enabled then
        core.hyperAddShortcut({ "shift" }, tp.key, function() tp.show() end,
                              "tool picker")
    end

    core.provide("toolPicker.show", function() return tp.show() end)

    _G.toolPicker = tp
    M.picker = tp
    M.config = tp
end

return M
