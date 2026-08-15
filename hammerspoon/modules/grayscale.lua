-- =====================================================================
-- MODULE: GRAYSCALE — toggle display grayscale, bare numpad 9
-- =====================================================================
-- One key: pad9 (the physical numpad key labelled 9, no modifier).
-- ⇪⇧ + pad9 is still the window top-right quarter from numpad_layer.
-- ⇪  + pad9 is still free for future use.
--
-- HOW IMMEDIATE EFFECT WORKS: macOS stores grayscale in the
-- com.apple.accessibility preferences domain. Writing there with
-- `defaults write` alone is not enough — the running accessibility
-- agent still holds the old value. `launchctl kickstart -k` restarts
-- the AXVisualSupportAgent so it re-reads the pref and applies the
-- filter right away. On macOS 12+ this is the documented way to make
-- display-filter changes take effect without opening System Settings.

local M = {
    name  = "Grayscale",
    order = 13.46,          -- between screen_veil (13.4) and numpad (13.5)
    cheatsheet = {
        title = "⬛️ GRAYSCALE (pad9)",
        entries = {
            { "pad9",      "Toggle grayscale on / off — bare numpad 9, no modifier" },
            { "⇪⇧ pad9",   "Still window → top-right quarter (numpad_layer)" },
            { "⇪  pad9",   "Still free" },
        },
    },
}

local DOMAIN = "com.apple.accessibility"
local KEY    = "GrayscaleEnabled"

function M.setup(core)
    -- Read the current state ONCE at load so we never block a keypress.
    -- hs.execute is synchronous; fine here because it runs at boot, not
    -- in a callback, and the shell command takes ~5ms.
    local state = false
    local out = hs.execute("defaults read " .. DOMAIN .. " " .. KEY .. " 2>/dev/null")
    if type(out) == "string" then
        state = out:match("^%s*1%s*$") ~= nil
    end

    local function toggle()
        state = not state
        hs.alert.show(state and "⬛️ Grayscale ON" or "🎨 Colour ON", 1.5)
        hs.task.new("/bin/bash", function(code, _, err)
            if code ~= 0 then
                -- Roll back so the next press retries from the right side.
                state = not state
                print("⬛️ Grayscale toggle failed — " .. tostring(err))
                if _G.notices then
                    pcall(_G.notices.record, "grayscale", "toggle", tostring(err))
                end
                pcall(hs.alert.show, "⬛️ Grayscale toggle failed", 2)
            end
        end, { "-c",
            "defaults write " .. DOMAIN .. " " .. KEY
            .. " -bool " .. (state and "true" or "false")
            .. " && launchctl kickstart -k"
            .. " gui/$(id -u)/com.apple.accessibility.AXVisualSupportAgent"
            .. " 2>/dev/null; true"
        }):start()
    end

    -- Bare pad9: no hyper, no modifier, just the physical numpad key.
    -- Goes through the §0.3 collision sentry like every global bind.
    hs.hotkey.bind({}, "pad9", toggle)

    -- Also available as a service and a global for the Console / other modules.
    core.provide("grayscale.toggle", toggle)
    _G.grayscaleToggle = toggle
    return toggle
end

return M
