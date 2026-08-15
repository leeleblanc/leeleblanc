-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- =====================================================================
-- VOLUME — system volume control, four keys
-- =====================================================================
-- The module does four things:
--   up   → step +5 (clamped, unmutes on the way)
--   down → step -5 (clamped)
--   mute → toggle the device mute flag (always system-wide)
--   reset→ set to 50% (the "back to normal" button)
-- Everything else (per-app mixing) is Vorssaint's job.
-- =====================================================================

local pass, fail = 0, 0
local function out(s) io.write(s) end
local function check(label, ok, detail)
    if ok then pass = pass + 1; out("  ✅ " .. label .. "\n")
    else
        fail = fail + 1
        out("  ❌ " .. label .. (detail ~= nil and ("  [" .. tostring(detail) .. "]") or "") .. "\n")
    end
end
local function section(s) out("\n" .. s .. "\n") end

-- ---- minimal world ---------------------------------------------------
local W

local function newWorld(opts)
    opts = opts or {}
    local w = {
        hasDevice     = opts.hasDevice ~= false,
        sysVolume     = opts.sysVolume or 50,
        muted         = opts.muted or false,
        setThrows     = opts.setThrows == true,
        alerts        = {},
        setVolCalls   = 0,
        setMuteCalls  = {},
    }
    local device = {
        outputVolume    = function() return w.sysVolume end,
        setOutputVolume = function(_, v)
            if w.setThrows then error("device gone", 0) end
            w.sysVolume = v; w.setVolCalls = w.setVolCalls + 1
        end,
        outputMuted     = function() return w.muted end,
        setOutputMuted  = function(_, m)
            w.muted = m; w.setMuteCalls[#w.setMuteCalls + 1] = m
        end,
    }
    local dev = setmetatable({}, { __index = function(_, k)
        local f = device[k]
        if f then return function(self, ...) return f(self, ...) end end
    end })

    w.hs = {
        audiodevice = {
            defaultOutputDevice = function() return w.hasDevice and dev or nil end,
        },
        alert = {
            show     = function(text) w.alerts[#w.alerts + 1] = tostring(text) end,
            closeAll = function() end,
        },
    }
    return w
end

local function lastAlert() return W.alerts[#W.alerts] end

local function load(opts)
    W = newWorld(opts)
    _G.hs = W.hs
    local M = assert(loadfile(HS .. "/modules/volume.lua"))()
    W.keys = {}
    local sv = M.setup({
        hyperAddShortcut = function(mods, key, fn, _, _, rep)
            W.keys[((mods and mods[1]) and "shift+" or "") .. key] = { fn = fn, repeated = rep }
        end,
    })
    W.sv = sv
    return sv
end

out("\n=== VOLUME ==============================================\n")

-- =====================================================================
section("1. STEPPING UP AND DOWN")
-- =====================================================================
do
    local sv = load{ sysVolume = 50 }
    sv.up()
    check("up steps by the configured amount", W.sysVolume == 55, W.sysVolume)
    sv.down()
    check("down steps back", W.sysVolume == 50, W.sysVolume)
    check("up shows the new level", (lastAlert() or ""):find("50%", 1, true) ~= nil, lastAlert())
end

-- =====================================================================
section("2. CLAMPING")
-- =====================================================================
do
    local sv = load{ sysVolume = 98 }
    sv.up(); sv.up(); sv.up()
    check("🚨 clamps at 100 — macOS rejects numbers above it",
          W.sysVolume == 100, W.sysVolume)

    W.sysVolume = 2
    sv.down(); sv.down()
    check("🚨 clamps at 0 on the way down", W.sysVolume == 0, W.sysVolume)
end

-- =====================================================================
section("3. UNMUTING WHEN VOLUME GOES UP")
-- =====================================================================
do
    local sv = load{ sysVolume = 50, muted = true }
    sv.up()
    check("🚨 raising the volume unmutes — pressing up eight times and "
       .. "hearing nothing is a bug report, not a feature",
          W.muted == false, W.muted)
end

do
    local sv = load{ sysVolume = 50, muted = true }
    -- Going down to zero should NOT unmute you
    for _ = 1, 20 do sv.down() end
    check("...but going to zero does not helpfully unmute you",
          W.muted == true, W.muted)
end

-- =====================================================================
section("4. MUTE TOGGLE")
-- =====================================================================
do
    local sv = load{ sysVolume = 50, muted = false }
    sv.mute()
    check("mute toggles the device flag", W.muted == true)
    check("🚨 ...and says 'whole Mac' — mute is always system-wide",
          (lastAlert() or ""):find("whole Mac", 1, true) ~= nil, lastAlert())
    sv.mute()
    check("...and toggles back", W.muted == false)
    check("...saying which way", (lastAlert() or ""):find("Unmuted", 1, true) ~= nil, lastAlert())
end

-- =====================================================================
section("5. RESET")
-- =====================================================================
do
    local sv = load{ sysVolume = 12 }
    sv.reset()
    check("reset goes to resetLevel (50)", W.sysVolume == 50, W.sysVolume)
    check("...and says so on screen", (lastAlert() or ""):find("50%", 1, true) ~= nil, lastAlert())
end

do
    local sv = load{ sysVolume = 100, muted = true }
    sv.reset()
    check("🚨 reset unmutes — you pressed it to get back to normal",
          W.muted == false, W.muted)
end

-- =====================================================================
section("6. NO OUTPUT DEVICE — must never be silent")
-- =====================================================================
do
    local sv = load{ hasDevice = false }
    sv.up()
    check("🚨 up with no device says so on screen — a key that does "
       .. "nothing silently is indistinguishable from one you pressed wrong",
          (lastAlert() or ""):find("No output device", 1, true) ~= nil, lastAlert())
    sv.down()
    check("...down too", (lastAlert() or ""):find("No output device", 1, true) ~= nil)
    sv.mute()
    check("...mute too", (lastAlert() or ""):find("No output device", 1, true) ~= nil)
    sv.reset()
    check("...reset too", (lastAlert() or ""):find("No output device", 1, true) ~= nil)
end

-- =====================================================================
section("7. DEVICE THAT THROWS MID-CALL")
-- =====================================================================
do
    local sv = load{ setThrows = true }
    local ok = pcall(function() sv.up() end)
    check("🛟 a device that throws during setOutputVolume is caught, not fatal", ok)
end

-- =====================================================================
section("8. KEYS AND AUTO-REPEAT")
-- =====================================================================
do
    local sv = load{ sysVolume = 50 }
    check("⇪. and ⇪, are registered", W.keys["."] ~= nil and W.keys[","] ~= nil)
    check("🚨 ...and BOTH repeat — volume keys are held down, not just tapped",
          type(W.keys["."].repeated) == "function"
          and type(W.keys[","].repeated) == "function")
    check("⇪⇧, and ⇪⇧. are registered",
          W.keys["shift+,"] ~= nil and W.keys["shift+."] ~= nil)

    W.keys["."].fn()
    check("...and the up key really steps up via fn", W.sysVolume == 55, W.sysVolume)
    W.keys["."].repeated()
    check("...and repeated() does the same thing", W.sysVolume == 60, W.sysVolume)
    W.keys["shift+."].fn()
    check("shift+. resets to 50", W.sysVolume == 50, W.sysVolume)
end

-- =====================================================================
section("9. THE HOSTILE MAC — every API returns nil")
-- =====================================================================
do
    local ok = pcall(function()
        local M = assert(loadfile(HS .. "/modules/volume.lua"))()
        _G.hs = setmetatable({}, { __index = function()
            return setmetatable({}, { __index = function()
                return function() return nil end
            end })
        end })
        local sv = M.setup({ hyperAddShortcut = function() end })
        sv.up(); sv.down(); sv.mute(); sv.reset()
    end)
    check("🚨 it sets up and all four operations survive a Mac that answers nil",
          ok)
end

out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
