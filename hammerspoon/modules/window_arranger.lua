-- =====================================================================
-- MODULE: WINDOW ARRANGER (was §1.9) — halves, fill, split, monitor jumps, app summon
-- =====================================================================
-- ✏️ EDIT YOUR KEYS HERE — every binding below reads from this table.
-- Note the spec assigned ⌃⌥F to BOTH "50% halves" and "fill screen";
-- resolved as F = fill, arrow keys = halves. Swap any of these freely.


-- Moved out of init.lua in 6.37.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "Window Arranger",
    order = 6,
    cheatsheet = {
        title = "🪟 WINDOW ARRANGER",
        entries = {
            { "⇪← / ⇪→", "Left / right half of screen" },
            { "⇪↑", "Fill screen (not full-screen mode)" },
            { "⇪\\", "Split two most recent windows side-by-side" },
            { "⇪W", "Summon an app to this monitor (picker)" },
            { "⇪↓", "Return window to prior spot (toggles)" },
            { "⇪[ / ⇪]", "Move window left / right a monitor" }
        },
    },
}

function M.setup(core)
    local windowKeys = {
        halfMods     = {"ctrl", "alt"},        -- modifiers for the five keys below
        halfLeft     = "Left",                 -- ⌃⌥←  left half of screen
        halfRight    = "Right",                -- ⌃⌥→  right half of screen
        maximize     = "F",                    -- ⌃⌥F  fill screen (NOT native full screen)
        split        = "V",                    -- ⌃⌥V  two most recent windows side-by-side
        appJump      = "W",                    -- ⌃⌥W  summon-an-app picker
        restore      = "M",                    -- ⌃⌥M  return window to prior position/monitor (toggles)
        monitorMods  = {"ctrl", "alt", "cmd"}, -- modifiers for the two keys below
        monitorLeft  = "[",                    -- ⌃⌥⌘[  move window one monitor LEFT (wraps) — [ sits left of ] on the keyboard
        monitorRight = "]",                    -- ⌃⌥⌘]  move window one monitor RIGHT (wraps)
    }

    hs.window.animationDuration = 0  -- window moves snap instantly, no slide

    local function focusedStandardWindow()
        local ok, win = pcall(hs.window.focusedWindow)
        if not ok or not win then return nil end
        return win
    end

    -- Native macOS full-screen windows live on their own Space and can't
    -- be resized/moved by frame-setting — every action below guards for
    -- that and tells you instead of silently doing nothing.
    local function guardNotFullScreen(win)
        local fs = false
        pcall(function() fs = win:isFullScreen() end)
        if fs then
            hs.alert.show("🪟 Exit full screen first (green button / ⌃⌘F)")
            return false
        end
        return true
    end

    -- PRIOR-POSITION MEMORY: every arrangement action below saves the
    -- window's frame (position + size + monitor, since frames are absolute
    -- screen coordinates) BEFORE moving it. ⌃⌥M restores it — and saves
    -- where the window is now, so pressing ⌃⌥M again toggles back. One
    -- memory slot per window, in-memory only (cleared on config reload).
    _G.windowPriorFrames = {}

    local function rememberFrame(win)
        local id, f = nil, nil
        pcall(function() id = win:id() end)
        pcall(function() f = win:frame() end)
        if id and f then _G.windowPriorFrames[id] = f end
    end

    -- ⌃⌥M — return the focused window to its remembered prior position
    local function restorePriorFrame()
        local win = focusedStandardWindow()
        if not win then hs.alert.show("🪟 No window in focus") return end
        if not guardNotFullScreen(win) then return end

        local id = nil
        pcall(function() id = win:id() end)
        local prior = id and _G.windowPriorFrames[id]
        if not prior then
            hs.alert.show("🪟 No prior position remembered for this window")
            return
        end

        -- If the prior position was on a monitor that's since been
        -- unplugged, restoring would strand the window off-screen — check
        -- the frame still overlaps some connected screen first.
        local visible = false
        for _, s in ipairs(hs.screen.allScreens()) do
            local ok, inter = pcall(function() return prior:intersect(s:frame()) end)
            if ok and inter and inter.w > 0 and inter.h > 0 then
                visible = true
                break
            end
        end
        if not visible then
            hs.alert.show("🪟 Prior position was on a monitor that's no longer connected")
            return
        end

        -- Swap: remember where it is NOW, so ⌃⌥M toggles back and forth
        local current = nil
        pcall(function() current = win:frame() end)
        win:setFrame(prior)
        if current then _G.windowPriorFrames[id] = current end
        win:focus()
        hs.alert.show("🪟 Returned to prior position — ⌃⌥M again toggles back")
    end

    -- ⌃⌥← / ⌃⌥→ — snap the focused window to the left/right half
    local function setHalf(side)
        local win = focusedStandardWindow()
        if not win then hs.alert.show("🪟 No window in focus") return end
        if not guardNotFullScreen(win) then return end
        rememberFrame(win)
        local f = win:screen():frame()
        if side == "left" then
            win:setFrame({ x = f.x, y = f.y, w = f.w / 2, h = f.h })
        else
            win:setFrame({ x = f.x + f.w / 2, y = f.y, w = f.w / 2, h = f.h })
        end
    end

    -- ⌃⌥F — fill the screen's usable area (menu bar & Dock stay visible;
    -- this is NOT the green-button full-screen mode)
    local function maximizeFocused()
        local win = focusedStandardWindow()
        if not win then hs.alert.show("🪟 No window in focus") return end
        if not guardNotFullScreen(win) then return end
        rememberFrame(win)
        win:maximize()
    end

    -- ⌃⌥V — split the two most recently used windows side-by-side on the
    -- focused window's screen: current window LEFT half, previous RIGHT.
    local function splitTopTwo()
        local wins = {}
        for _, w in ipairs(hs.window.orderedWindows()) do
            local ok, std = pcall(function() return w:isStandard() end)
            if ok and std then table.insert(wins, w) end
            if #wins == 2 then break end
        end
        if #wins < 2 then
            hs.alert.show("🪟 Need two visible windows to split")
            return
        end
        if not guardNotFullScreen(wins[1]) or not guardNotFullScreen(wins[2]) then return end
        rememberFrame(wins[1])
        rememberFrame(wins[2])

        local scr = wins[1]:screen()
        local f = scr:frame()
        if wins[2]:screen() ~= scr then
            pcall(function() wins[2]:moveToScreen(scr, false, true) end)
        end
        wins[1]:setFrame({ x = f.x,           y = f.y, w = f.w / 2, h = f.h })
        wins[2]:setFrame({ x = f.x + f.w / 2, y = f.y, w = f.w / 2, h = f.h })
        wins[1]:focus()

        local n1, n2 = "window", "window"
        pcall(function() n1 = wins[1]:application():name() or n1 end)
        pcall(function() n2 = wins[2]:application():name() or n2 end)
        hs.alert.show("🪟 " .. n1 .. "  ⇤⇥  " .. n2)
    end

    -- ⌃⌥⌘[ / ⌃⌥⌘] — throw the focused window to the next monitor right/
    -- left. Wraps around: past the rightmost monitor lands on the leftmost,
    -- and vice versa, so it cycles among ALL monitors.
    local function moveFocusedToMonitor(direction)
        local win = focusedStandardWindow()
        if not win then hs.alert.show("🪟 No window in focus") return end
        if #hs.screen.allScreens() < 2 then
            hs.alert.show("🪟 Only one monitor connected")
            return
        end
        if not guardNotFullScreen(win) then return end
        rememberFrame(win)

        local scr = win:screen()
        local target = (direction == "east") and scr:toEast() or scr:toWest()
        if not target then
            -- wrap around the edge
            local screens = hs.screen.allScreens()
            table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
            target = (direction == "east") and screens[1] or screens[#screens]
        end
        if target == scr then return end

        pcall(function() win:moveToScreen(target, false, true) end)
        win:focus()
        local name = "monitor"
        pcall(function() name = target:name() or name end)
        hs.alert.show("🪟 → " .. name, target)
    end

    -- ⌃⌥W — summon picker: type an app's name, select it, and its window
    -- jumps to the ACTIVE monitor (captured at the moment you press the
    -- hotkey) in front of other apps. If the app is in native full screen
    -- it can't be moved across monitors, so it's focused where it lives.
    _G.appJumpTargetScreen = nil

    _G.choosers.appJump = hs.chooser.new(function(choice)
        if not (choice and choice.pid) then return end
        local app = hs.application.applicationForPID(choice.pid)
        if not app then
            hs.alert.show("❌ " .. (choice.text or "App") .. " is no longer running")
            return
        end

        local target = _G.appJumpTargetScreen or core.resolveBaseScreen()
        local win = nil
        pcall(function() win = app:mainWindow() or app:focusedWindow() end)

        if win then
            local fs = false
            pcall(function() fs = win:isFullScreen() end)
            if fs then
                app:activate(true)
                hs.alert.show("🪟 " .. choice.text .. " is full screen — switched to it")
                return
            end
            pcall(function()
                rememberFrame(win)
                win:moveToScreen(target, false, true)
                win:raise()
            end)
        end
        app:activate(true)
        hs.alert.show("🪟 Summoned " .. choice.text)
    end)
    _G.choosers.appJump:placeholderText("Summon an app to this monitor…")

    hs.hotkey.bind(windowKeys.halfMods, windowKeys.appJump, function()
        -- Capture the target BEFORE the picker opens, so "active monitor"
        -- means the one you were working on, not wherever the picker lands
        _G.appJumpTargetScreen = core.resolveBaseScreen()

        local choices = {}
        for _, app in ipairs(hs.application.runningApplications()) do
            local okK, kind = pcall(function() return app:kind() end)
            if okK and kind == 1 then  -- regular Dock apps only
                local okN, name = pcall(function() return app:name() end)
                if okN and name and name ~= "" and name ~= "Hammerspoon" then
                    table.insert(choices, {
                        text    = name,
                        subText = "Jump to this monitor, in front of other apps",
                        pid     = app:pid(),
                    })
                end
            end
        end
        table.sort(choices, function(a, b) return a.text:lower() < b.text:lower() end)
        _G.choosers.appJump:choices(choices)
        core.showPopup(_G.choosers.appJump)
    end)

    hs.hotkey.bind(windowKeys.halfMods, windowKeys.halfLeft,  function() setHalf("left")  end)
    hs.hotkey.bind(windowKeys.halfMods, windowKeys.halfRight, function() setHalf("right") end)
    hs.hotkey.bind(windowKeys.halfMods, windowKeys.maximize,  maximizeFocused)
    hs.hotkey.bind(windowKeys.halfMods, windowKeys.split,     splitTopTwo)
    hs.hotkey.bind(windowKeys.halfMods, windowKeys.restore,   restorePriorFrame)
    hs.hotkey.bind(windowKeys.monitorMods, windowKeys.monitorRight, function() moveFocusedToMonitor("east") end)
    hs.hotkey.bind(windowKeys.monitorMods, windowKeys.monitorLeft,  function() moveFocusedToMonitor("west") end)
end

return M
