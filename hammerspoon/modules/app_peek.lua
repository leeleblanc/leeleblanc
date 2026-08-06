-- =====================================================================
-- MODULE: APP PEEK (was §1.8) — ⌃⌥⌘P hides the frontmost app / brings it back
-- =====================================================================
-- The closest macOS allows to "make an app translucent so you can see
-- behind it": true window opacity of OTHER apps isn't exposed by the
-- Accessibility API (position/size/hide yes, alpha no), so instead one
-- press HIDES the frontmost app entirely — revealing everything behind
-- it — and the same press brings it back and refocuses it. 0%/100%
-- rather than 50%/100%, but the same toggle rhythm.
-- Notes:
--   • Only one app is "peeked" at a time; pressing on a different app
--     while one is hidden restores the first one instead.
--   • If you manually unhide the app (click its Dock icon), the next
--     press just resets cleanly — nothing gets stuck.

-- Moved out of init.lua in 6.36.0. Behaviour unchanged; it takes its
-- modifier combo from `core` rather than from init.lua's locals.
local M = {
    name  = "App Peek",
    order = 7,
    cheatsheet = {
        title = "👀 APP PEEK",
        entries = {
            { "⇪P", "Hide frontmost app — press again to bring back" },
        },
    },
}

function M.setup(core)
    local peekKey = "P"
    _G.peekedApp = nil

    hs.hotkey.bind(core.popupMods, peekKey, function()
        if _G.peekedApp then
            local app = _G.peekedApp
            _G.peekedApp = nil
            local name = "app"
            pcall(function() name = app:name() or name end)
            pcall(function()
                app:unhide()
                app:activate()
            end)
            hs.alert.show("👀 Restored " .. name)
            return
        end

        local ok, app = pcall(hs.application.frontmostApplication)
        if not ok or not app then return end
        local name = "app"
        pcall(function() name = app:name() or name end)
        if name == "Hammerspoon" then
            hs.alert.show("👀 Won't peek Hammerspoon itself")
            return
        end

        _G.peekedApp = app
        pcall(function() app:hide() end)
        hs.alert.show("👀 Peeking behind " .. name .. " — ⌃⌥⌘P brings it back")
    end)
end

return M
