-- =====================================================================
-- MODULE: ASANA TASK DASHBOARD (was init.lua §6) — ⇪L open · ⇪C comment
-- =====================================================================
-- Moved out of init.lua in 6.386.0, on LL's word ("Yes, and make this
-- move safe-proof and non-destructive for the Asana dashboard both on my
-- home and work mac"). THE CODE IS UNCHANGED apart from taking its seven
-- shared helpers from `core` instead of init.lua's own locals, and three
-- nil-guards named in the changelog. Same keys, same panel, same fetch.
--
-- 📏 WHY IT HAD TO MOVE, and it is arithmetic rather than taste: the gate
-- fails init.lua at 3,800 lines and it stood at 3,795. 6.385.0 had to
-- drop a release note to fit. This file is 529 of those lines and is a
-- FEATURE living inside the orchestrator, which init.lua's own header
-- has forbidden since it was written.
--
-- 🪜 THE ONE ORDERING FACT THAT DECIDES THIS FILE'S SHAPE, measured in
-- init.lua rather than assumed: the three keys below are written as
-- ⌃⌥⌘L / ⌃⌥⌘C / ⌃⌥⌘B and §0.4's migration map rewrites every one of
-- them onto ⇪ (⇪L, ⇪C, ⇪B). A migrated bind does not reach macOS at
-- all — it is appended to `_G.hyperMigrations`, which `_G.hyperFinalize()`
-- DRAINS ONCE, at init.lua's last section, AFTER the module loader has
-- run. So binding in setup() lands; binding in M.warm would append to a
-- list nobody reads again and the three keys would be silently dead.
-- 6.311.0's rule, and the suite drives it rather than trusting it.
--
-- 🔑 AND THE BIND STAYS hs.hotkey.bind, NEVER core.hyperAddShortcut.
-- That looks like the modern form and would break two things: a migrated
-- combo never enters the test suite's HYPER_OWNER, so both cheat-sheet
-- auditors are blind to these keys by construction — which is what lets
-- core/cheatsheet.lua keep the ✅ ASANA card it has owned for a hundred
-- releases. Registering through hyperAddShortcut would demand a row on
-- THIS module's sheet, and printing ⇪B/⇪C/⇪L on two cards is the double
-- listing LL objected to from a screenshot in 6.90.1.
--
-- Up to 100 incomplete tasks, asked for in one fetch and then trimmed
-- to the five caps in the table below (which is the only copy of them —
-- 6.363.0 deleted a comment that listed all five again). Overdue is
-- newest due first, the dated bands soonest first, undated newest
-- created first; names capitalize the first word only, per spec. The
-- list is searchable; ⏎ opens the task in the browser (⇪L) or prompts
-- for a comment that posts to Asana (⇪C).
local M = {
    name  = "Asana Dashboard",
    order = 2,
    family = "capture",
    -- no cheatsheet group of its own: core/cheatsheet.lua's ✅ ASANA card
    -- already prints ⇪B, ⇪C and ⇪L. See the 🔑 note above.
}

-- `core` is captured in setup() rather than closed over at load, so every
-- reference below resolves at PRESS time. Nothing in this file runs before
-- setup — the only things that exist at load are the state tables and the
-- function definitions, and the one global another module reaches for
-- (_G.asanaLegendSync) checks it before using it.
local core = nil

local asanaCaps = {
    overdue = 40,   -- 🔴 Overdue
    today   = 10,   -- 🟡 Due today
    week    = 30,   -- 🔵 Due this week
    later   = 10,   -- 🟠 Due later
    undated = 10,   -- 🟣 No due date
}

local isAsanaFetching     = false
local asanaDashboardMode  = "open"   -- "open" or "comment"
-- 🗑 6.156.0 — the picker's select mode (see _G.asanaSelect.rows below).
-- It stays a GLOBAL after the move, deliberately: tests/test_select_mode
-- reads it, and the four verbs hang off it. The reason it was a global in
-- init.lua (that file's 200-local ceiling) is gone; the reason to keep it
-- one is that something else reads it.
_G.asanaSelect = { on = false, tagged = {}, master = nil }

-- 🔎 6.386.0 — THE COUNTS THE MOVE IS ANSWERABLE BY. This tool had no
-- report at all, which is why "did the move work?" could only have been
-- answered by reading the source. 6.306.0's precedent: the drag engine
-- survived two of his reports because it had no instrument.
local stats = {
    setupAt = nil, boundAt = nil, doors = 0, bindFail = {},
    opens = 0, comments = 0, teams = 0,
    fetches = 0, ok = 0, http = {}, lastErr = nil, lastAt = nil,
    legendShown = 0, legendRefused = 0,
    noMembers = 0, noFetcher = 0,
}

-- ---- COLOR LEGEND STRIP — pills above the task list ------------------
-- hs.chooser cannot draw a footer inside its own window, so the legend
-- is a slim hs.canvas strip. 🚨 IT SITS ABOVE THE SEARCH FIELD, because
-- the picker's top-left is a position we set ourselves and is therefore
-- exact — below the list meant ESTIMATING the picker's height, and the
-- first estimate ran short and overlaid the bottom rows. It appears with
-- the dashboard and goes when the picker resolves.
local asanaLegendDefs = {
    { key = "overdue", label = "Overdue",       color = { red = 0.92, green = 0.25, blue = 0.20 }, darkText = false },
    { key = "today",   label = "Due today",     color = { red = 1.00, green = 0.80, blue = 0.00 }, darkText = true  },
    { key = "week",    label = "Due this week", color = { red = 0.04, green = 0.52, blue = 1.00 }, darkText = false },
    { key = "later",   label = "Due later",     color = { red = 1.00, green = 0.58, blue = 0.00 }, darkText = false },
    { key = "undated", label = "No due date",   color = { red = 0.69, green = 0.32, blue = 0.87 }, darkText = false },
}

_G.asanaLegendCanvas = nil
local asanaLegendCounts = nil   -- set on each fetch; nil = nothing to show

local function asanaLegendHide()
    if _G.asanaLegendCanvas then
        pcall(function() _G.asanaLegendCanvas:delete() end)
        _G.asanaLegendCanvas = nil
    end
end

local function asanaLegendShow()
    asanaLegendHide()
    if not asanaLegendCounts then return end
    local chooser = _G.choosers.asana
    if not chooser then return end
    -- 🔒 6.386.0 — the one place a caller outside this module can arrive
    -- (window_move's nudge → _G.asanaLegendSync) reaches this function, so
    -- it refuses rather than indexing a nil core if setup never ran.
    if not core then return end

    -- Reuse the EXACT placement showPopup just used for the picker —
    -- resolving the screen again here could disagree (focus shifts as
    -- the popup opens) and draw the legend on a different monitor.
    local place = _G.lastPopupPlacement
    local screen  = (place and place.screen) or core.resolveBaseScreen()
    local sf = screen:frame()
    local topLeft = (place and place.point)
    if not topLeft then
        topLeft = core.chooserTopLeft(chooser, screen)
    end
    local pct = 40
    local okW, w = pcall(function() return chooser:width() end)
    if okW and type(w) == "number" and w > 0 and w <= 100 then pct = w end
    local chooserW = sf.w * (pct / 100)

    local stripH, pad, gap, pillH, textSize = 44, 12, 10, 30, 16

    -- Just above the picker's top edge — exact, no height estimation.
    -- Clamped so a picker nudged to the very top of the screen can't
    -- push the strip off-screen.
    local stripY = math.max(sf.y + 4, topLeft.y - stripH - 8)

    -- Lay pills left→right; width estimated from label length
    local pills, x = {}, pad
    for _, def in ipairs(asanaLegendDefs) do
        local n = asanaLegendCounts[def.key] or 0
        if n > 0 then
            local label = def.label .. "  " .. n
            local pillW = 20 + math.floor(#label * 9.0)
            table.insert(pills, { label = label, color = def.color, darkText = def.darkText, x = x, w = pillW })
            x = x + pillW + gap
        end
    end
    if #pills == 0 then return end

    local stripW = x - gap + pad
    -- Center under the picker, then clamp fully on-screen
    local stripX = topLeft.x + math.max(0, (chooserW - stripW) / 2)
    if stripX + stripW > sf.x + sf.w then stripX = sf.x + sf.w - stripW - 4 end
    if stripX < sf.x then stripX = sf.x + 4 end

    local canvas = hs.canvas.new({ x = stripX, y = stripY, w = stripW, h = stripH })
    if not canvas then stats.legendRefused = stats.legendRefused + 1 ; return end

    local sty = _G.uiStyle or {}   -- 🎨 6.90.0 shared card look
    local els = {}
    table.insert(els, {
        type = "rectangle", action = "fill",
        fillColor = (sty.bgWith and sty.bgWith(core.panelAlpha))
                    or { red = 0.11, green = 0.11, blue = 0.13, alpha = core.panelAlpha },
        roundedRectRadii = { xRadius = 12, yRadius = 12 },
    })
    for _, p in ipairs(pills) do
        table.insert(els, {
            type = "rectangle", action = "fill",
            fillColor = { red = p.color.red, green = p.color.green, blue = p.color.blue, alpha = 1.0 },
            roundedRectRadii = { xRadius = pillH / 2, yRadius = pillH / 2 },
            frame = { x = p.x, y = (stripH - pillH) / 2, w = p.w, h = pillH },
        })
        table.insert(els, {
            type = "text", text = p.label, textSize = textSize,
            textColor = p.darkText and { white = 0.05 } or { white = 1.0 },
            textAlignment = "center",
            frame = { x = p.x, y = (stripH - pillH) / 2 + 4, w = p.w, h = pillH },
        })
    end

    canvas:appendElements(els)
    pcall(function() canvas:level(hs.canvas.windowLevels.overlay) end)
    -- CRITICAL for Spaces/full-screen: a canvas belongs only to the
    -- Space it was created on unless told otherwise — and a native
    -- full-screen app is its own private Space, so the legend simply
    -- never appeared there. canJoinAllSpaces = visible on every Space;
    -- fullScreenAuxiliary = allowed to overlay full-screen Spaces.
    -- (hs.chooser's panel declares these internally, which is why the
    -- picker never had this problem.)
    pcall(function() canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
    _G.showCanvasSafely(canvas, "popup panel")
    _G.asanaLegendCanvas = canvas
    stats.legendShown = stats.legendShown + 1
    -- Console diagnostic (harmless; invaluable if placement misbehaves)
    local scrName = "?"
    pcall(function() scrName = screen:name() or "?" end)
    print(string.format("🎨 Legend on '%s' at x=%d y=%d w=%d h=%d",
        scrName, math.floor(stripX), math.floor(stripY), math.floor(stripW), stripH))
end

-- Nudging (⌃⌥⌘ arrows) repositions the picker — this lets init.lua §1.5
-- and modules/window_move.lua drag the legend along with it. BOTH call
-- sites are nil-guarded and were before this move; that is what makes the
-- move invisible to them.
_G.asanaLegendSync = function()
    if _G.asanaLegendCanvas then asanaLegendShow() end
end

-- Helper: parse Asana date strings safely into unix timestamps
local function parseAsanaDate(dateStr)
    -- Guard against JSON null arriving as userdata
    if type(dateStr) ~= "string" or dateStr == "" then return nil end
    local y, m, d = dateStr:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
    if y and m and d then
        return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12, min = 0, sec = 0 })
    end
    return nil
end

-- Append up to `cap` entries from src into dst (the per-category limit)
local function appendCapped(dst, src, cap)
    for i = 1, math.min(#src, cap) do
        table.insert(dst, src[i])
    end
end

local function fetchAsanaDashboard(mode)
    if not core then return end
    if not core.requireAsana() then return end
    asanaDashboardMode = mode or "open"
    _G.asanaSelect.on, _G.asanaSelect.tagged = false, {}   -- a fresh list, no stale ✓
    asanaLegendHide()   -- clear any stale strip from a previous open

    if isAsanaFetching then
        hs.alert.show("⚠️ Request pending. Please wait.")
        return
    end

    isAsanaFetching = true
    stats.fetches = stats.fetches + 1
    stats.lastAt  = os.time()
    hs.alert.show("🔄 Syncing Asana Tasks...")

    local fullUrl = "https://app.asana.com/api/1.0/tasks"
        .. "?assignee=me&completed_since=now&workspace=" .. core.asanaWorkspaceId
        .. "&opt_fields=name,due_on,due_at,created_at,permalink_url&limit=100"

    local headers = {
        ["Authorization"] = "Bearer " .. core.asanaToken,
        ["Accept"]        = "application/json"
    }

    hs.http.asyncGet(fullUrl, headers, function(status, body, resHeaders)
        isAsanaFetching = false
        stats.http[tostring(status)] = (stats.http[tostring(status)] or 0) + 1

        if status ~= 200 then
            if status == 401 then
                stats.lastErr = "Asana rejected the token (401) — it is revoked or mistyped"
                hs.alert.show("🔒 Asana rejected the token — it's revoked or mistyped. Create a new one at app.asana.com/0/my-apps and update ~/.hammerspoon/secret.lua", 8)
                print("🚨 ASANA 401 — the token in secret.lua is not valid (revoked, expired, or mistyped)")
            else
                stats.lastErr = "Asana answered HTTP " .. tostring(status)
                hs.alert.show("❌ Asana Sync Failed (Status: " .. tostring(status) .. ")")
                print("🚨 ASANA API ERROR: " .. tostring(body))
            end
            return
        end

        local response = _G.safeJson(body, "asana/list")
        if not response or not response.data then
            stats.lastErr = "Asana answered 200 with a body this config could not read"
            hs.alert.show("❌ Error reading data from Asana")
            return
        end
        stats.ok = stats.ok + 1

        local now     = os.time()
        local current = os.date("*t", now)
        local todayStart = os.time({ year = current.year, month = current.month, day = current.day, hour = 0,  min = 0,  sec = 0  })
        local todayEnd   = os.time({ year = current.year, month = current.month, day = current.day, hour = 23, min = 59, sec = 59 })
        local weekEnd    = todayEnd + (7 * 86400)

        local overdueTasks = {}   -- 🔴 Overdue
        local todayTasks   = {}   -- 🟡 Due today
        local weekTasks    = {}   -- 🔵 Due this week
        local laterTasks   = {}   -- 🟠 Due later
        local undatedTasks = {}   -- 🟣 No due date

        for _, task in ipairs(response.data) do
            local dueStr  = task.due_on or task.due_at
            local dueTime = parseAsanaDate(dueStr)

            if dueTime then
                local cleanDateStr = string.sub(dueStr, 1, 10)
                if dueTime < todayStart then
                    table.insert(overdueTasks, { text = task.name, subText = "🔴 Overdue — due: " .. cleanDateStr, url = task.permalink_url, gid = task.gid, dueTime = dueTime })
                elseif dueTime >= todayStart and dueTime <= todayEnd then
                    table.insert(todayTasks,   { text = task.name, subText = "🟡 Due today — due: " .. cleanDateStr, url = task.permalink_url, gid = task.gid, dueTime = dueTime })
                elseif dueTime > todayEnd and dueTime <= weekEnd then
                    table.insert(weekTasks,    { text = task.name, subText = "🔵 Due this week — due: " .. cleanDateStr, url = task.permalink_url, gid = task.gid, dueTime = dueTime })
                else
                    table.insert(laterTasks,   { text = task.name, subText = "🟠 Due later — due: " .. cleanDateStr, url = task.permalink_url, gid = task.gid, dueTime = dueTime })
                end
            else
                -- No due date: typically the newest tasks. created_at is
                -- ISO-8601, which sorts correctly as a plain string.
                local created = (type(task.created_at) == "string") and task.created_at or ""
                table.insert(undatedTasks, {
                    text    = task.name,
                    subText = "🟣 No due date — created: " .. (created ~= "" and created:sub(1, 10) or "unknown"),
                    url     = task.permalink_url,
                    gid     = task.gid,
                    created = created,
                })
            end
        end

        -- Per-category sorting (before caps, so the cap keeps the most
        -- relevant entries of each category):
        table.sort(overdueTasks, function(a, b) return a.dueTime > b.dueTime end)  -- newest due first
        table.sort(weekTasks,    function(a, b) return a.dueTime < b.dueTime end)  -- soonest first
        table.sort(laterTasks,   function(a, b) return a.dueTime < b.dueTime end)  -- soonest first
        table.sort(undatedTasks, function(a, b) return a.created > b.created end)  -- newest created first

        -- Assemble in display order, each category trimmed to its cap:
        -- 40 + 10 + 30 + 10 + 10 = 100 tasks maximum
        local masterChoicesList = {}
        appendCapped(masterChoicesList, overdueTasks, asanaCaps.overdue)
        appendCapped(masterChoicesList, todayTasks,   asanaCaps.today)
        appendCapped(masterChoicesList, weekTasks,    asanaCaps.week)
        appendCapped(masterChoicesList, laterTasks,   asanaCaps.later)
        appendCapped(masterChoicesList, undatedTasks, asanaCaps.undated)

        if #masterChoicesList == 0 then
            hs.alert.show("✨ Clean slate! No urgent tasks found.")
            return
        end

        -- Legend pill counts = rows each category actually contributed
        asanaLegendCounts = {
            overdue = math.min(#overdueTasks, asanaCaps.overdue),
            today   = math.min(#todayTasks,   asanaCaps.today),
            week    = math.min(#weekTasks,    asanaCaps.week),
            later   = math.min(#laterTasks,   asanaCaps.later),
            undated = math.min(#undatedTasks, asanaCaps.undated),
        }

        -- Registered in _G.choosers so it participates in popup screen routing
        if not _G.choosers.asana then
            _G.choosers.asana = hs.chooser.new(function(choice)
                asanaLegendHide()   -- picker resolved (pick / Esc / click away)
                if not choice then return end

                if asanaDashboardMode == "comment" then
                    -- 💬 COMMENT MODE: prompt for text, post it as a comment
                    if choice.gid then
                        local button, text = hs.dialog.textPrompt(
                            "💬 Comment on: " .. (choice.text or "task"),
                            "Your comment will post to Asana exactly like the 'Add a comment' box.",
                            "", "Post", "Cancel")
                        if button == "Post" and text and #text > 0 then
                            _G.service.call("asana.addComment", choice.gid, text)
                        end
                    else
                        hs.alert.show("⚠️ No task ID found for this row")
                    end
                else
                    -- 🗑 6.156.0 — SELECT MODE and the delete verbs, before
                    -- the open. The rows are the ones _G.asanaSelect.rows
                    -- built; every branch that keeps the picker up calls
                    -- reshow(), which re-opens it with the ✓ marks kept.
                    local sel = _G.asanaSelect
                    if choice.selectStart then
                        sel.on, sel.tagged = true, {}
                        sel.reshow(); return
                    elseif choice.selectStop then
                        sel.on, sel.tagged = false, {}
                        sel.reshow(); return
                    elseif choice.deleteTagged then
                        local list = {}
                        for _, c in ipairs(sel.master or {}) do
                            if sel.tagged[c.gid] then table.insert(list, c) end
                        end
                        sel.delete(list); return
                    end
                    if sel.on and choice.gid then
                        if sel.tagged[choice.gid] then sel.tagged[choice.gid] = nil
                        else sel.tagged[choice.gid] = true end
                        sel.reshow(); return
                    end
                    -- ⌥⏎ on one row: delete just that task (asks first)
                    local mods = {}
                    pcall(function() mods = hs.eventtap.checkKeyboardModifiers() or {} end)
                    if mods.alt and choice.gid then
                        sel.delete({ choice }); return
                    end
                    -- 🚀 OPEN MODE: open the task in the browser
                    if choice.url then
                        hs.urlevent.openURL(choice.url)
                        hs.alert.show("🚀 Opening task in Asana...")
                    end
                end
            end)
        end

        local placeholder = (asanaDashboardMode == "comment")
            and "💬 Pick a task to comment on…"
            or  "Filter your current priority tasks… (⌥⏎ deletes one)"

        -- 👁 6.157.0 — the preview pane: the whole task name, its due
        -- line and its link, beside the picker
        for _, c in ipairs(masterChoicesList) do
            c.rawText = tostring(c.text or "") .. "\n" .. tostring(c.subText or "")
                        .. (c.url and ("\n" .. c.url) or "")
        end
        _G.asanaSelect.master = masterChoicesList
        local rows = _G.asanaSelect.rows(masterChoicesList)
        _G.choosers.asana:choices(rows)
        _G.choosers.asana:placeholderText(placeholder)
        _G.choosers.asana:rows(math.min(#rows, 10))
        core.showPopup(_G.choosers.asana)
        asanaLegendShow()
        _G.asanaSelect.pane()
    end)
end

-- 👁 6.157.0 — the pane, through the registry (clipboard_history provides
-- it); the hideCallback is set once, the first time the picker opens.
_G.asanaSelect.pane = function()
    local svc = _G.service
    if not (svc and svc.has and svc.has("preview.open") and _G.choosers.asana) then return end
    if not _G.asanaSelect.paneWired then
        _G.asanaSelect.paneWired = true
        pcall(function()
            _G.choosers.asana:hideCallback(function() pcall(svc.call, "preview.suspend") end)
        end)
    end
    pcall(svc.call, "preview.open", _G.choosers.asana)
end

-- 🗑 6.156.0 — SELECT SEVERAL, DELETE (LL's ask): "☑️ Select several…"
-- tags rows, "🗑 Delete N selected" deletes after a confirmation naming
-- them; ⌥⏎ deletes one. DELETE /tasks/{gid} with the token in the header
-- (never a process argument), one task at a time; Asana keeps deleted
-- tasks in its trash 30 days. Hangs off _G.asanaSelect, not new locals.
_G.asanaSelect.rows = function(master)
    local sel = _G.asanaSelect
    if asanaDashboardMode ~= "open" then return master end
    local n = 0
    for _ in pairs(sel.tagged) do n = n + 1 end
    local rows = {}
    if sel.on then
        if n > 0 then
            table.insert(rows, {
                text    = ("🗑 Delete %d selected task%s"):format(n, n == 1 and "" or "s"),
                subText = "asks first · they go to Asana's trash, restorable for 30 days",
                deleteTagged = true })
        end
        table.insert(rows, { text = "✕ Leave select mode",
                             subText = "keeps everything as it is", selectStop = true })
        for _, c in ipairs(master) do
            table.insert(rows, { text = (sel.tagged[c.gid] and "✓ " or "") .. tostring(c.text),
                                 subText = c.subText, url = c.url, gid = c.gid })
        end
    else
        table.insert(rows, { text = "☑️ Select several to delete…",
                             subText = "⏎ tags rows, then 🗑 · ⌥⏎ on any row deletes just that one",
                             selectStart = true })
        for _, c in ipairs(master) do table.insert(rows, c) end
    end
    return rows
end

_G.asanaSelect.reshow = function()
    local sel = _G.asanaSelect
    if not (_G.choosers.asana and sel.master and core) then return end
    local rows = sel.rows(sel.master)
    _G.choosers.asana:choices(rows)
    pcall(function() _G.choosers.asana:rows(math.min(#rows, 10)) end)
    core.showPopup(_G.choosers.asana)
    asanaLegendShow()
    sel.pane()
end

_G.asanaSelect.delete = function(list)
    if #list == 0 then
        hs.alert.show("Nothing picked — press Enter on the rows you want first")
        return
    end
    if not core then return end
    local names = {}
    for i = 1, math.min(#list, 8) do
        names[#names + 1] = "• " .. (tostring(list[i].text):gsub("^✓ ", ""))
    end
    if #list > 8 then names[#names + 1] = ("… and %d more"):format(#list - 8) end
    local button = nil
    pcall(function()
        button = hs.dialog.blockAlert(
            ("Delete %d task%s from Asana?"):format(#list, #list == 1 and "" or "s"),
            table.concat(names, "\n")
            .. "\n\nThey go to Asana's trash — restorable from Deleted Items for 30 days.",
            "Delete", "Cancel")
    end)
    if button ~= "Delete" then hs.alert.show("🗑 Nothing deleted") return end
    local done, failed, i = 0, 0, 0
    local headers = { ["Authorization"] = "Bearer " .. core.asanaToken,
                      ["Accept"] = "application/json" }
    local function step()
        i = i + 1
        local t = list[i]
        if not t then
            hs.alert.show(("🗑 Deleted %d task%s%s"):format(done, done == 1 and "" or "s",
                failed > 0 and (" · %d failed — see the Console"):format(failed) or ""), 4)
            _G.asanaSelect.on, _G.asanaSelect.tagged = false, {}
            if done > 0 then fetchAsanaDashboard("open") end
            return
        end
        hs.http.asyncRequest("https://app.asana.com/api/1.0/tasks/" .. tostring(t.gid),
            "DELETE", nil, headers, function(status, body)
                if status == 200 then
                    done = done + 1
                else
                    failed = failed + 1
                    print("🚨 ASANA delete failed for " .. tostring(t.text) .. " — status "
                          .. tostring(status) .. ": " .. tostring(body):sub(1, 200))
                end
                step()
            end)
    end
    step()
end

-- ⇪B — browse your Asana project's team; Enter copies the exact name
-- so pasting it into the Task Creator's Assignee field always resolves.
-- 6.16.12: ⌃⇧⌥M -> ⌃⌥⌘B, standardized onto the same chord as the rest of
-- the Asana hotkeys, and §0.4 then migrates all three onto ⇪.
local function showTeamPicker()
    if not core then return end
    if not _G.choosers.asanaTeam then return end
    local choices = {}
    -- 🔒 6.386.0 — `or {}`. The list is published by modules/asana_comments
    -- and is nil until that module's setup runs; before the move this file
    -- was init.lua and the handler could only ever fire long after. It is
    -- STILL only reachable from a keypress, so this is a belt — but a
    -- module that failed to load must cost one shortcut, not a traceback
    -- out of hyperBind (6.177.0).
    for _, m in ipairs(_G.asanaTeamMembers or {}) do
        local teamLabel = (m.teams and #m.teams > 0) and table.concat(m.teams, " + ") or ""
        local sub = m.email or ""
        if teamLabel ~= "" then
            sub = (sub ~= "" and (sub .. "  ·  ") or "") .. teamLabel
        end
        table.insert(choices, { text = m.name, subText = sub, name = m.name })
    end
    _G.choosers.asanaTeam:choices(choices)
    core.showPopup(_G.choosers.asanaTeam)
end

-- 🔎 6.386.0 — the report the move is answerable by.
function _G.asanaDashboardReport()
    local L = {}
    local function add(s) L[#L + 1] = s end
    add("📋 ASANA DASHBOARD — ⇪L open · ⇪C comment · ⇪B team")
    add(string.format("   file   : modules/asana_dashboard.lua (left init.lua in 6.386.0)"))
    -- 🪜 THREE STATES, NEVER TWO (6.196.1): a module whose setup never ran
    -- and one whose binds were refused read the same from outside, and the
    -- fix for each is different.
    if not stats.setupAt then
        add("   keys   : ⏳ setup has NOT run — this module did not load. ⇪L, ⇪C and ⇪B do nothing.")
    elseif stats.doors == 0 then
        add("   keys   : ⚠️ setup ran and bound NOTHING — " ..
            (#stats.bindFail > 0 and table.concat(stats.bindFail, " · ") or "no reason recorded"))
    else
        add(string.format("   keys   : %d of 3 bound in setup() — %s", stats.doors,
            #stats.bindFail > 0 and ("⚠️ " .. table.concat(stats.bindFail, " · ")) or "⇪L · ⇪C · ⇪B"))
        add("   ↳ when : bound during setup, which is BEFORE _G.hyperFinalize() drains the")
        add("            migration list — binding in warm() would never register (6.311.0)")
    end
    add(string.format("   core   : %s", core and "handed over at setup" or "⚠️ NOT handed over"))
    if core then
        local missing = {}
        for _, k in ipairs({ "showPopup", "resolveBaseScreen", "chooserTopLeft",
                             "panelAlpha", "requireAsana", "asanaToken", "asanaWorkspaceId" }) do
            if core[k] == nil then missing[#missing + 1] = k end
        end
        add(string.format("   ↳ seven: %s", #missing == 0
            and "every helper this module moved away from is on the core table"
            or ("⚠️ MISSING from core: " .. table.concat(missing, ", "))))
    end
    add(string.format("   asana  : %s", (core and core.asanaEnabled)
        and "secret.lua loaded — the keys will fetch"
        or "no secret.lua on this Mac — every key says so and nothing is attempted"))
    add(string.format("   presses: %d open (⇪L) · %d comment (⇪C) · %d team (⇪B)",
        stats.opens, stats.comments, stats.teams))
    if stats.fetches == 0 then
        add("   fetches: none this session")
    else
        local codes = {}
        for k, v in pairs(stats.http) do codes[#codes + 1] = k .. "×" .. v end
        table.sort(codes)
        add(string.format("   fetches: %d asked · %d answered with a list · HTTP %s",
            stats.fetches, stats.ok, #codes > 0 and table.concat(codes, " ") or "none yet"))
        if stats.lastErr then
            add("   ↳ ⚠️ last: " .. tostring(stats.lastErr)
                .. (stats.lastAt and (" at " .. os.date("%H:%M:%S", stats.lastAt)) or ""))
        end
    end
    add(string.format("   legend : %d strip(s) drawn%s", stats.legendShown,
        stats.legendRefused > 0 and (" · ⚠️ " .. stats.legendRefused .. " refused by macOS") or ""))
    add(string.format("   ↳ sync : %s", _G.asanaLegendSync and "published — a nudge drags the strip with the picker"
        or "⚠️ NOT published — a nudged picker leaves the strip behind"))
    if stats.noMembers > 0 or stats.noFetcher > 0 then
        add(string.format("   ↳ team : ⚠️ %d press(es) found no team list · %d found no fetcher (asana_comments did not load)",
            stats.noMembers, stats.noFetcher))
    end
    print(table.concat(L, "\n"))
end

function M.setup(c)
    core = c
    stats.setupAt = os.time()

    -- 🪜 BOUND HERE, IN setup(), AND THAT IS LOAD-BEARING. All three combos
    -- are in §0.4's migration map, so hs.hotkey.bind appends them to
    -- _G.hyperMigrations rather than registering them; _G.hyperFinalize()
    -- drains that list once, after the module loader. setup() is therefore
    -- the last moment a migrated bind can be made. See the header.
    local function door(key, label, fn)
        local ok, err = pcall(function() hs.hotkey.bind({"cmd", "ctrl", "alt"}, key, fn) end)
        if ok then
            stats.doors = stats.doors + 1
        else
            stats.bindFail[#stats.bindFail + 1] = label .. " refused: " .. tostring(err)
            core.degrade("Asana dashboard", label .. " could not be bound: " .. tostring(err))
        end
    end

    -- Dashboard: open task in browser
    -- 6.16.12: standardized every Asana hotkey onto the same ⌃⌥⌘ chord
    -- (was ⌃⇧⌥ for this one and the two below) — ⌃⌥⌘L, "List tasks".
    door("L", "⇪L (list tasks)", function()
        stats.opens = stats.opens + 1
        fetchAsanaDashboard("open")
    end)

    -- Dashboard: add a comment to a task — 6.16.12: ⌃⇧⌥C -> ⌃⌥⌘C
    door("C", "⇪C (comment on a task)", function()
        stats.comments = stats.comments + 1
        fetchAsanaDashboard("comment")
    end)

    _G.choosers.asanaTeam = hs.chooser.new(function(choice)
        if not choice or not choice.name then return end
        local ok = core.copyText(choice.name, "asana team name")
        if ok then
            hs.alert.show("📋 Copied " .. choice.name .. " — paste into the Assignee field")
        else
            hs.alert.show("⚠️ macOS refused the clipboard write — " .. choice.name)
        end
    end)
    _G.choosers.asanaTeam:placeholderText("Search your Asana team — Enter copies the name")
    -- Team name is folded into subText (e.g. "someone@x.com  ·  SAC
    -- Library Core Projects") — searchSubText makes hs.chooser's own
    -- filtering match against it too, so typing "core" narrows to just that
    -- team. Pure display/search change — doesn't touch the native ⌘+number
    -- row-shortcut badges the chooser already shows, those aren't ours.
    pcall(function() _G.choosers.asanaTeam:searchSubText(true) end)

    door("B", "⇪B (browse the team)", function()
        stats.teams = stats.teams + 1
        if not core.requireAsana() then return end
        if #(_G.asanaTeamMembers or {}) > 0 then
            showTeamPicker()
            return
        end
        -- 🔒 6.386.0 — the fetcher belongs to modules/asana_comments. Before
        -- this move a missing one would have thrown out of the handler and
        -- hyperBind re-raises; now it says so and costs one shortcut.
        if type(_G.fetchAsanaTeamMembers) ~= "function" then
            stats.noFetcher = stats.noFetcher + 1
            core.degrade("Asana dashboard",
                "⇪B needs the Asana Comments module, which did not load")
            return
        end
        hs.alert.show("🔄 Fetching team members…")
        _G.fetchAsanaTeamMembers(function()
            if #(_G.asanaTeamMembers or {}) == 0 then
                stats.noMembers = stats.noMembers + 1
                hs.alert.show("⚠️ Couldn't load team members — check Console")
            else
                showTeamPicker()
            end
        end)
    end)

    stats.boundAt = os.time()
end

return M
