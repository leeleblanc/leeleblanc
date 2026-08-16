-- =====================================================================
-- MODULE: MENU BAR ITEMS (⇪M) — every status icon, by name, from the keyboard
-- =====================================================================
-- ⇪M lists every icon in the right-hand menu bar. Type a few letters,
-- press Return, and that icon's menu opens — without aiming a pointer at
-- a 22-pixel glyph you cannot always identify. ⇪⇧M prints an inventory.
--
-- ---------------------------------------------------------------------
-- 🚫 READ THIS FIRST: THIS IS NOT BARTENDER, AND IT CANNOT BE
-- ---------------------------------------------------------------------
-- You asked for Bartender. Bartender's central trick — HIDING other
-- apps' menu bar icons and showing them in a second bar — is not
-- something Hammerspoon can do, and the reason is not a missing feature
-- in Hammerspoon:
--
--   · A menu bar icon is an NSStatusItem owned by the app that created
--     it, laid out by the system. macOS exposes NO public API for one
--     process to hide, move or reorder another process's status item.
--     There is nothing to call.
--   · Bartender gets around this by covering the real menu bar with its
--     own view and drawing its own copies of the icons — which is why it
--     asks for SCREEN RECORDING permission. It has to photograph the
--     menu bar, because it cannot ask for the icon images either.
--
-- Hammerspoon could draw a black strip over part of the menu bar, and
-- that is all it would be: a black strip. It could not redraw the icons
-- it covered, could not know when their positions shifted, and would
-- either swallow every click in that region or let them fall through to
-- icons you can no longer see. That is not worth shipping.
--
-- ✅ IF YOU WANT ACTUAL HIDING, the honest answer is a dedicated app.
--    ICE is free, open source and actively maintained:
--    https://github.com/jordanbaird/Ice   — it does what Bartender does,
--    it costs nothing, and it coexists fine with everything here.
--
-- ---------------------------------------------------------------------
-- SO WHAT THIS DOES, AND WHY IT MAY SUIT YOU BETTER
-- ---------------------------------------------------------------------
-- The half of Bartender that IS reachable through Accessibility is the
-- useful half for a keyboard-driven setup: every status item's name, and
-- the ability to open it. A searchable list beats a tidy row of
-- unlabelled glyphs when what you actually want is "open the VPN one".
-- It needs no Screen Recording, covers nothing, and moves nothing.
--
-- ---------------------------------------------------------------------
-- ⚠️ THE REAL RISK IN THIS FILE IS A FREEZE, NOT A CRASH
-- ---------------------------------------------------------------------
-- Reading another app's Accessibility tree is a SYNCHRONOUS call into
-- that app. If it is busy, wedged, or mid-beachball, the call blocks
-- Hammerspoon's main thread — and Hammerspoon's main thread is your
-- keyboard. Scanning fifty apps with no timeout is a plausible way to
-- freeze the Mac for a minute. This config has met that failure before:
-- 6.33.0's ⌥Tab froze for the same reason, snapshotting windows.
--
-- So: EVERY app element gets an explicit short timeout before it is
-- asked anything, the whole scan is time-boxed, and the result is cached
-- so repeated presses cost nothing. A slow scan prints how slow it was
-- rather than leaving you to wonder.

local M = {
    name  = "Menu Bar Items",
    order = 13.9,
    cheatsheet = {
        title = "📊 MENU BAR ITEMS (⇪M — status icons by name, from the keyboard)",
        entries = {
            { "⇪M",     "List every menu bar icon — type to filter, ⏎ opens it" },
            { "⇪⇧M",    "Inventory: what is up there, and which app owns each" },
            { "why",    "Beats aiming at a 22px glyph you cannot always identify" },
            { "NOT",    "This does NOT hide icons. macOS has no API for that —" },
            { "",       "Bartender covers the bar and screenshots it. For real" },
            { "",       "hiding use Ice (free): github.com/jordanbaird/Ice" },
            { "needs",  "Accessibility. Without it, it says so and does nothing." },
        },
    },
}

function M.setup(core)
    local mb = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    mb.enabled     = true
    mb.key         = "m"          -- ⇪M list · ⇪⇧M inventory
    -- 🚨 Per-app Accessibility timeout, in seconds. This is the freeze
    -- guard, not a tuning knob. Raise it and a single wedged app can hold
    -- your keyboard for that long, times however many apps are running.
    mb.axTimeout   = 0.10
    mb.scanBudget  = 2.0          -- hard stop for the whole scan, seconds
    mb.cacheSecs   = 10           -- repeated presses reuse the last scan
    mb.slowWarn    = 0.75         -- print a warning if a scan exceeds this
    -- ✏️ OWNERS NEVER WORTH LISTING. 6.65.0 — this was one entry, and the
    -- picker was consequently full of things that are not applications.
    -- macOS runs a fleet of faceless background agents that each own a
    -- menu bar extra: the clock, Control Center, the input-source menu,
    -- Stage Manager, the Wi-Fi and battery and volume items. They ARE
    -- status items, so the scan is right to find them — but none of them
    -- can be usefully driven by "pick it from a list and click it", and
    -- together they crowd out the real apps you opened this picker for.
    --
    -- ⚠️ THIS IS A DENY LIST, NOT A RULE. There is no reliable flag that
    -- says "agent, not app" — LSUIElement is set by plenty of legitimate
    -- menu-bar-only apps you DO want here (1Password, Bartender, Ice,
    -- NordVPN), so filtering on it would throw away the good with the
    -- bad. Names it is, and a name that is not on this list still shows
    -- up, which is the failure direction that costs you nothing.
    --
    -- To bring one back, delete its line. To hide something else, add it
    -- by the exact name the picker shows in its left column.
    mb.skipApps    = {
        ["Hammerspoon"]         = true,  -- our own 🩺 and calendar items
        -- 🎯 THE ONE LL ACTUALLY SAW, named from his own screenshot:
        --      MenuBarAgent
        --      3.5% CPU @ /System/Library/CoreServices/MenuBarAgent.app/…
        -- New in macOS 26 (Tahoe): MenuBarAgent is the system process that
        -- now draws the menu bar itself. It owns status items the way a
        -- landlord owns a building — the scan is right to find it, and
        -- there is nothing behind it to click.
        ["MenuBarAgent"]        = true,
        ["Menu Bar Agent"]      = true,   -- display-name form, just in case
        ["Control Center"]      = true,  -- clock, Wi-Fi, battery, volume…
        ["ControlCenter"]       = true,  -- the bundle name, on some builds
        ["SystemUIServer"]      = true,  -- the legacy extras host
        ["TextInputMenuAgent"]  = true,  -- the input-source / emoji menu
        ["Spotlight"]           = true,  -- ⌘space already opens it
        ["WindowManager"]       = true,  -- Stage Manager
        ["Window Manager"]      = true,
        ["Dock"]                = true,  -- owns several invisible extras
        ["NotificationCenter"]  = true,
        ["universalaccessd"]    = true,
        ["talagent"]            = true,
        ["AirPlayUIAgent"]      = true,
        ["ScreenSaverEngine"]   = true,
    }
    -- 🚨 AND A RULE ON TOP OF THE LIST, because a list of names can only
    -- ever be as current as the last macOS release I have seen. Anything
    -- living in /System/Library/CoreServices is an Apple background agent
    -- by definition — MenuBarAgent, SystemUIServer, Dock, Spotlight and
    -- whatever Apple adds next all sit there. Filtering on the PATH catches
    -- the ones nobody has told me about yet.
    --
    -- ⚠️ THIS IS NOT LSUIElement, deliberately. Plenty of legitimate
    -- menu-bar-only apps set that flag — 1Password, Bartender, Ice,
    -- NordVPN — and filtering on it would throw away exactly the apps you
    -- opened this picker to reach. Path is the honest signal: a real
    -- application you installed does not live in CoreServices.
    mb.skipSystemPaths = { "/System/Library/CoreServices/" }
    -- ----------------------------------------------------------------------

    mb.cache, mb.cacheAt, mb.lastScanMs = nil, 0, 0

    local function say(m)  if _G.diag then _G.diag.say("menuBar", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("menuBar", m) end end

    local function axOK()
        local ok, granted = pcall(hs.accessibilityState)
        return ok and granted == true
    end

    -- Reading one attribute, defensively. Every call here crosses a process
    -- boundary and can fail, return nil, or return something of the wrong
    -- shape depending on how the owning app implements accessibility.
    local function attr(el, name)
        if not el then return nil end
        local ok, v = pcall(function() return el:attributeValue(name) end)
        if ok then return v end
        return nil
    end

    -- A menu bar extra rarely has a title. What identifies it, when
    -- anything does, is AXDescription — and plenty of apps set neither, so
    -- the owning app's name is the reliable label and the description is a
    -- bonus.
    local function labelFor(appName, el)
        local desc  = attr(el, "AXDescription")
        local title = attr(el, "AXTitle")
        local extra = nil
        for _, v in ipairs({ desc, title }) do
            if type(v) == "string" and v ~= "" and v ~= appName then extra = v break end
        end
        return appName, extra
    end

    -- ---- the scan --------------------------------------------------------
    function mb.scan(force)
        if not axOK() then return nil, "Accessibility is not granted" end
        local now = hs.timer.secondsSinceEpoch()
        if not force and mb.cache and (now - mb.cacheAt) < mb.cacheSecs then
            return mb.cache
        end

        local t0, found, scanned, timedOut = now, {}, 0, 0
        local okApps, apps = pcall(hs.application.runningApplications)
        if not okApps or not apps then return nil, "could not list running apps" end

        for _, app in ipairs(apps) do
            -- 🚨 THE BUDGET IS CHECKED EVERY ITERATION, not just at the end.
            -- Stopping early with a partial list is strictly better than
            -- holding the keyboard while the last few apps time out.
            if hs.timer.secondsSinceEpoch() - t0 > mb.scanBudget then
                warn("scan budget exhausted after " .. scanned .. " apps")
                break
            end
            local name = "?"
            pcall(function() name = app:name() or "?" end)
            -- Path check second, and only when the name did not already
            -- settle it: app:path() crosses a process boundary like every
            -- other question here, so it is asked once per app and only
            -- when it can change the answer.
            local skip = mb.skipApps[name] == true
            if not skip then
                local p
                pcall(function() p = app:path() end)
                if type(p) == "string" then
                    for _, prefix in ipairs(mb.skipSystemPaths) do
                        if p:sub(1, #prefix) == prefix then skip = true break end
                    end
                end
            end
            if not skip then
                local okEl, el = pcall(hs.axuielement.applicationElement, app)
                if okEl and el then
                    -- ⚠️ SET THE TIMEOUT BEFORE ASKING ANYTHING. This is the
                    -- single line standing between a wedged app and a frozen
                    -- keyboard, and it has to come first.
                    pcall(function() el:setTimeout(mb.axTimeout) end)
                    scanned = scanned + 1
                    local extras = attr(el, "AXExtrasMenuBar")
                    if extras == nil then
                        -- Indistinguishable from "this app has no status
                        -- item", which is the common case, so it is counted
                        -- rather than reported.
                        timedOut = timedOut + 1
                    else
                        for _, item in ipairs(attr(extras, "AXChildren") or {}) do
                            local appName, extra = labelFor(name, item)
                            found[#found + 1] = {
                                app = appName, detail = extra, el = item,
                            }
                        end
                    end
                end
            end
        end

        table.sort(found, function(a, b)
            if a.app == b.app then return (a.detail or "") < (b.detail or "") end
            return a.app:lower() < b.app:lower()
        end)

        mb.lastScanMs = (hs.timer.secondsSinceEpoch() - t0) * 1000
        mb.cache, mb.cacheAt = found, hs.timer.secondsSinceEpoch()
        say(string.format("scanned %d apps in %.0fms, %d menu bar items",
            scanned, mb.lastScanMs, #found))
        if mb.lastScanMs > mb.slowWarn * 1000 then
            print(string.format("📊 Menu Bar Items: that scan took %.2fs. An app "
                .. "is slow to answer Accessibility; lower mb.scanBudget if it "
                .. "becomes a nuisance.", mb.lastScanMs / 1000))
        end
        return found
    end

    -- ---- activating one --------------------------------------------------
    -- Three ways, in order of how well they behave. AXPress is correct and
    -- most apps implement it; AXShowMenu is the documented alternative; a
    -- synthetic click at the item's own coordinates is the last resort for
    -- an app that implements neither, and is why the position is read.
    local function tryActions(entry)
        local el = entry.el
        for _, action in ipairs({ "AXPress", "AXShowMenu" }) do
            -- ⚠️ `return` INSIDE THE WRAPPER IS LOAD-BEARING. Without it the
            -- anonymous function discards performAction's result, pcall
            -- reports success with a nil value, the "did it work" test
            -- fails, and AXShowMenu fires immediately after a perfectly
            -- good AXPress — activating every item twice.
            local ok, res = pcall(function() return el:performAction(action) end)
            if ok and res then
                say("activated " .. entry.app .. " via " .. action)
                return true
            end
        end
        return false
    end

    local function tryClick(entry)
        local pos  = attr(entry.el, "AXPosition")
        local size = attr(entry.el, "AXSize")
        if type(pos) == "table" and type(size) == "table"
           and pos.x and size.w then
            local point = { x = pos.x + size.w / 2, y = pos.y + size.h / 2 }
            local ok = pcall(function()
                hs.mouse.absolutePosition(point)
                hs.eventtap.leftClick(point)
            end)
            if ok then
                say("activated " .. entry.app .. " by clicking its position")
                return true
            end
        end
        return false
    end

    -- 6.90.1 — PLURAL ON PURPOSE. A merged picker row (see mb.show) hands
    -- several indistinguishable items here, and the row activates the FIRST
    -- one that actually responds — Bartender's real icon answers AXPress,
    -- its invisible spacers answer nothing. Actions across ALL of them
    -- before any click: a synthetic click on a zero-width spacer is a
    -- click on whatever happens to be drawn behind it.
    function mb.activateFirst(entries)
        local first = nil
        for _, e in ipairs(entries or {}) do
            if e and e.el then
                first = first or e
                if tryActions(e) then return true end
            end
        end
        for _, e in ipairs(entries or {}) do
            if e and e.el and tryClick(e) then return true end
        end
        if not first then return false end
        hs.alert.show("📊 " .. first.app .. " would not respond")
        warn(first.app .. ": AXPress, AXShowMenu and a click all failed")
        return false
    end

    function mb.activate(entry)
        if not entry or not entry.el then return false end
        return mb.activateFirst({ entry })
    end

    -- ---- the picker ------------------------------------------------------
    mb.chooser = nil     -- HELD: an unreferenced hs.chooser is collected

    function mb.show()
        if not mb.enabled then return end
        if not axOK() then
            hs.alert.show("📊 Menu bar items need Accessibility —\nSystem "
                .. "Settings → Privacy & Security → Accessibility", 4)
            return
        end
        local items, err = mb.scan(false)
        if not items then
            hs.alert.show("📊 " .. tostring(err))
            return
        end
        if #items == 0 then
            hs.alert.show("📊 No menu bar items found. Apps that draw their "
                .. "icon without Accessibility support are invisible to this.", 4)
            return
        end

        -- 6.90.1 — rows the picker cannot tell apart become ONE row. An app
        -- may own several unnamed status items (Bartender 6 shows up four
        -- times: one real icon plus the invisible spacers it hides other
        -- icons behind). The scan stays honest — ⇪⇧M still lists every
        -- item — but four identical rows help nobody pick anything. The
        -- list is sorted by (app, detail), so equal rows are adjacent.
        local choices = {}
        for i, e in ipairs(items) do
            local prev = choices[#choices]
            if prev and prev.text == e.app and prev.detail == e.detail then
                table.insert(prev.idxs, i)
                prev.subText = (e.detail or "menu bar item")
                             .. " ×" .. #prev.idxs
            else
                choices[#choices + 1] = {
                    text    = e.app,
                    detail  = e.detail,
                    subText = e.detail or "menu bar item",
                    idxs    = { i },
                }
            end
        end

        if not mb.chooser then
            mb.chooser = hs.chooser.new(function(pick)
                if not pick then return end
                local cached, picked = mb.cache or {}, {}
                for _, i in ipairs(pick.idxs or {}) do
                    picked[#picked + 1] = cached[i]
                end
                if #picked > 0 then mb.activateFirst(picked) end
            end)
            -- ⎋ 6.93.0: filed in _G.choosers so Esc closes it before the cheat sheet
            _G.choosers = _G.choosers or {}
            _G.choosers.menubarItems = mb.chooser
            pcall(function()
                mb.chooser:searchSubText(true)
                mb.chooser:width(30)
            end)
        end
        mb.chooser:choices(choices)
        mb.chooser:placeholderText(#choices == #items
            and (#items .. " menu bar items — type to filter")
            or  (#items .. " items in " .. #choices .. " rows — type to filter"))
        -- Placed by the same rule as every other popup in this config, so it
        -- lands on the screen you are looking at rather than the main one.
        local okScr, scr = pcall(core.resolveBaseScreen)
        if okScr and scr then pcall(function() _G.popupScreenOverride = nil end) end
        mb.chooser:show()
    end

    function _G.menuBarReport()
        if not axOK() then
            print("📊 Menu Bar Items: Accessibility is not granted, so nothing "
                  .. "up there is readable.")
            return
        end
        local items = mb.scan(true) or {}
        local L = { string.format("📊 MENU BAR ITEMS on %s — %d found in %.0fms",
                    tostring(core.hostTag), #items, mb.lastScanMs) }
        local byApp = {}
        for _, e in ipairs(items) do
            byApp[e.app] = (byApp[e.app] or 0) + 1
        end
        for _, e in ipairs(items) do
            L[#L + 1] = string.format("   %-28s %s", e.app, e.detail or "")
        end
        L[#L + 1] = "   ⚠️ This module CANNOT hide or reorder these — macOS has"
        L[#L + 1] = "      no API for it. For real hiding use Ice (free):"
        L[#L + 1] = "      https://github.com/jordanbaird/Ice"
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if mb.enabled then
        core.hyperAddShortcut({}, mb.key, mb.show, "menu bar items")
        core.hyperAddShortcut({ "shift" }, mb.key, function()
            local r = _G.menuBarReport()
            if r then
                pcall(function() hs.pasteboard.setContents(r) end)
                hs.alert.show("📊 Menu bar inventory printed and copied", 2)
            end
        end, "menu bar inventory")
    end

    core.provide("menuBar.show",   function() return mb.show()      end)
    core.provide("menuBar.list",   function() return mb.scan(false) end)
    core.provide("menuBar.report", function() return _G.menuBarReport() end)

    if not axOK() then
        print("📊 Menu Bar Items: Accessibility is OFF — ⇪M will explain "
              .. "rather than doing nothing.")
    end

    _G.menuBarItems = mb
    M.mb     = mb
    M.config = mb
end

return M
