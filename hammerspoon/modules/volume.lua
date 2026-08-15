-- =====================================================================
-- MODULE: VOLUME — system volume via hyper key
-- =====================================================================
-- 6.80.0: Per-app mixing removed. Use Vorssaint for that.
--   (vorssaint/vorssaint-utils — driverless, Core Audio Process Taps,
--    System Audio Recording permission only, macOS 14.2+, Apple Silicon)
--
--   ⇪.    system volume +5%   (auto-repeats while held)
--   ⇪,    system volume -5%   (auto-repeats while held)
--   ⇪⇧,   mute / unmute  (whole Mac — the only thing macOS exposes)
--   ⇪⇧.   reset to 50%   (the "get back to normal" button)
--
-- Nothing here blocks the main thread. Every hs.audiodevice call is
-- pcall'd: a device that vanishes mid-call (Bluetooth headphones, a
-- sleeping display) surfaces an on-screen report instead of crashing.

local M = {
    name  = "Volume",
    order = 13.45,
    cheatsheet = {
        title = "🔊 VOLUME (system)",
        entries = {
            { "⇪.",     "System volume up 5% (hold to repeat)" },
            { "⇪,",     "System volume down 5% (hold to repeat)" },
            { "⇪⇧,",    "Mute / unmute (whole Mac)" },
            { "⇪⇧.",    "Reset to 50% — the \"back to normal\" button" },
            { "per-app", "Use Vorssaint — driverless, macOS 14.2+, Apple Silicon" },
        },
    },
}

M.config = {
    step       = 5,   -- percentage points per keypress / repeat tick
    resetLevel = 50,  -- ⇪⇧. sets the system volume here
    alertSecs  = 1.0,
}

function M.setup(core)
    local cfg = M.config

    local function dev()
        local ok, d = pcall(function()
            return hs.audiodevice and hs.audiodevice.defaultOutputDevice()
        end)
        return (ok and d) or nil
    end

    local function say(text)
        pcall(function()
            hs.alert.closeAll(0)
            hs.alert.show(text, cfg.alertSecs)
        end)
    end

    local function getLevel()
        local d = dev()
        if not d then return nil end
        local ok, v = pcall(function() return d:outputVolume() end)
        return (ok and type(v) == "number") and math.floor(v + 0.5) or nil
    end

    -- unmute=true only on up() and reset(): raising the volume on a muted
    -- device does nothing audible, and "I pressed up eight times and heard
    -- nothing" is a bug report. down() never unmutes — you are going quieter.
    local function setLevel(n, unmute)
        local d = dev()
        if not d then say("🔇 No output device"); return end
        n = math.max(0, math.min(100, math.floor(n + 0.5)))
        pcall(function() d:setOutputVolume(n) end)
        if unmute and n > 0 then pcall(function() d:setOutputMuted(false) end) end
        say("🔊 " .. n .. "%")
    end

    local function up()
        setLevel((getLevel() or cfg.resetLevel) + cfg.step, true)
    end

    local function down()
        setLevel((getLevel() or cfg.resetLevel) - cfg.step, false)
    end

    local function mute()
        local d = dev()
        if not d then say("🔇 No output device"); return end
        local ok, muted = pcall(function() return d:outputMuted() end)
        local target = not (ok and muted)
        pcall(function() d:setOutputMuted(target) end)
        say(target and "🔇 Muted (whole Mac)" or "🔊 Unmuted")
    end

    local function reset()
        setLevel(cfg.resetLevel, true)
    end

    core.hyperAddShortcut({}, ".", up,   "volume up",   nil, up)
    core.hyperAddShortcut({}, ",", down, "volume down", nil, down)
    core.hyperAddShortcut({"shift"}, ",", mute,  "mute / unmute (whole Mac)")
    core.hyperAddShortcut({"shift"}, ".", reset, "volume reset to " .. cfg.resetLevel .. "%")

    _G.systemVolume = { up = up, down = down, mute = mute, reset = reset,
                        level = getLevel, setLevel = setLevel }
    return _G.systemVolume
end

return M
