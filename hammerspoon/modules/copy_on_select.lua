-- =====================================================================
-- MODULE: GLOBAL COPY-ON-SELECT (was §3.11) — ⌘⌃⌥⇧C toggles · OFF by default
-- =====================================================================
-- CORRECTED: AXSelectedTextChanged is posted by the specific FOCUSED
-- TEXT ELEMENT, not the application as a whole — watching the app root
-- for it (the previous version of this block) essentially never
-- fires. Fix: watch the app for AXFocusedUIElementChanged (a real,
-- reliable per-app notification), and each time focus lands on a new
-- element, attach a SEPARATE watcher to THAT element for
-- AXSelectedTextChanged.
-- HONEST LIMITS: reliability depends entirely on how well each app
-- implements Accessibility. Native Cocoa apps (TextEdit, Notes, Mail)
-- and browser page text generally expose this correctly. Electron apps
-- (Chrome, Slack, VS Code, Discord) have historically inconsistent AX
-- support — expect hit-or-miss there, not a guarantee. Test in TextEdit
-- or Notes first — that's the best-case, most reliable case.
-- (The original §3.11 wrapped its locals in a do...end block to keep
-- them out of init.lua's 200-local budget. That wrapper is gone: the
-- body now lives inside M.setup(), which is a function and scopes
-- them already. Leaving it in split the `do` from its `end` across
-- the function boundary — which still COMPILED, and made the module
-- return nil instead of its contract table.)

-- ⚠️ THIS MODULE DECLARES NO CHEAT SHEET GROUP, on purpose. Its one
-- entry (⇪⇧C) lives in the 📋 CLIPBOARD & OCR group, which belongs to a
-- section still inside init.lua. Splitting it out would drop a
-- one-line group into the middle of your sheet and change the layout
-- for no benefit. The honest cost: that entry is still hard-coded, so
-- if THIS module fails to load the sheet still lists ⇪⇧C. What covers
-- you is the ⚠️ MODULES THAT FAILED group the loader puts at the TOP of
-- the sheet — the dead key is explained, just not on its own line.
-- When the clipboard section moves out, its group and this entry should
-- be reunited in that module.

-- Moved out of init.lua in 6.37.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "Copy-on-Select",
    order = 350,
    -- no cheatsheet group — see the note above
}

function M.setup(core)
    local cosExcludedApps = {}
    local cosFocusObserver, cosSelectionObserver = nil, nil

    local function cosIsExcluded(name)
        for _, ex in ipairs(cosExcludedApps) do if name == ex then return true end end
        return false
    end

    -- Debounced: a drag-selection fires AXSelectedTextChanged on every
    -- intermediate change, not just the final one. Each call restarts a
    -- short timer instead of copying immediately; only the LAST call
    -- (selection has stopped changing) actually reads AXSelectedText and
    -- copies — reading it fresh at fire time, not a stale snapshot.
    local cosDebounce = nil
    local function cosCopyFrom(element)
        if cosDebounce then cosDebounce:stop() end
        cosDebounce = hs.timer.doAfter(0.35, function()
            local ok, text = pcall(function() return element:attributeValue("AXSelectedText") end)
            if ok and type(text) == "string" and #text > 0 then
                hs.pasteboard.setContents(text)
            end
        end)
    end

    local function cosStopSelectionWatch()
        if cosDebounce then cosDebounce:stop(); cosDebounce = nil end
        if cosSelectionObserver then
            pcall(function() cosSelectionObserver:stop() end)
            cosSelectionObserver = nil
        end
    end

    local function cosWatchFocusedElement(pid, element)
        cosStopSelectionWatch()
        if not (_G.copyOnSelectEnabled and element) then return end
        local ok, obs = pcall(hs.axuielement.observer.new, pid)
        if not ok or not obs then return end
        local okWatch = pcall(function()
            obs:callback(function(_, el) cosCopyFrom(el) end)
            obs:addWatcher(element, "AXSelectedTextChanged")
            obs:start()
        end)
        if okWatch then cosSelectionObserver = obs end
    end

    local function cosStopAll()
        cosStopSelectionWatch()
        if cosFocusObserver then
            pcall(function() cosFocusObserver:stop() end)
            cosFocusObserver = nil
        end
    end

    local function cosStartForApp(app)
        cosStopAll()
        if not (_G.copyOnSelectEnabled and app) then return end
        local okName, name = pcall(function() return app:name() end)
        if not okName or not name or name == "Hammerspoon" or cosIsExcluded(name) then return end
        local okPid, pid = pcall(function() return app:pid() end)
        if not okPid or not pid then return end
        local okAx, axApp = pcall(hs.axuielement.applicationElement, app)
        if not okAx or not axApp then return end

        local okObs, obs = pcall(hs.axuielement.observer.new, pid)
        if not okObs or not obs then return end
        local okWatch = pcall(function()
            obs:callback(function(_, element) cosWatchFocusedElement(pid, element) end)
            obs:addWatcher(axApp, "AXFocusedUIElementChanged")
            obs:start()
        end)
        if okWatch then
            cosFocusObserver = obs
            -- Also catch whatever's ALREADY focused right now, not just
            -- the next focus change.
            local okFocused, focused = pcall(function() return axApp:attributeValue("AXFocusedUIElement") end)
            if okFocused and focused then cosWatchFocusedElement(pid, focused) end
        else
            print("⚠️ Copy-on-select: " .. name .. " didn't accept an Accessibility watcher")
        end
    end

    _G.copyOnSelectWatcher = hs.application.watcher.new(function(_, eventType, app)
        if eventType == hs.application.watcher.activated then
            cosStartForApp(app)
        end
    end)
    _G.copyOnSelectWatcher:start()

    _G.copyOnSelectEnabled = false
    hs.hotkey.bind({"cmd", "ctrl", "alt", "shift"}, "C", function()
        _G.copyOnSelectEnabled = not _G.copyOnSelectEnabled
        if _G.copyOnSelectEnabled then
            local ok, app = pcall(hs.application.frontmostApplication)
            if ok then cosStartForApp(app) end
            hs.alert.show("🖱️ Copy-on-select ON")
        else
            cosStopAll()
            hs.alert.show("🖱️ Copy-on-select OFF")
        end
    end)

end

return M
