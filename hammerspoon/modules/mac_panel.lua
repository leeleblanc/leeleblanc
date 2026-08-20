-- =====================================================================
-- MODULE: MAC PANEL (⇪7) — About This Mac, as a card you can leave open
-- =====================================================================
-- LL: "Can you create windows like Pomodoro for: About This Mac"
--
-- The Pomodoro's shape — a small card in the corner of the screen you
-- are looking at, drawn on a canvas, draggable, above everything else.
-- ⇪7 opens it, ⇪7 puts it away.
--
--        ⇪7         open the card · press it again to close
--
-- It carries what Apple's own About This Mac carries, plus the four
-- things you actually go looking for that Apple's does not put on the
-- front page: uptime, free disk, battery health, and this Mac's IP
-- address on the network it is currently on.
--
-- ---------------------------------------------------------------------
-- ⚡ WHY IT DRAWS BEFORE IT KNOWS EVERYTHING
-- ---------------------------------------------------------------------
-- Almost all of this comes from sysctl, sw_vers and Hammerspoon's own
-- host and battery APIs, and all of those answer in microseconds. Two
-- things do not:
--
--   THE MARKETING NAME  ("MacBook Air (M2, 2022)"). The kernel knows
--                       only "Mac14,2". Turning that into the name on
--                       the box means asking system_profiler, which
--                       takes one to three SECONDS.
--   THE SERIAL NUMBER   ioreg has it in about a tenth of a second,
--                       which is fast for a subprocess and far too slow
--                       for a keypress.
--
-- So the card OPENS IMMEDIATELY with everything that is free, shows
-- "reading…" in those two slots, and fills them in when the answers
-- arrive. A panel that takes three seconds to appear is a panel you stop
-- pressing; one that appears instantly and completes itself is one you
-- leave open.
--
-- ---------------------------------------------------------------------
-- 🔢 WHERE EACH NUMBER COMES FROM, because "About This Mac" is not one
-- source and the differences matter
-- ---------------------------------------------------------------------
--   memory      hw.memsize — the RAM installed, not the RAM free.
--   disk        the FREE space on /, from `df -k` — kilobytes, said in
--               the command's own name, rather than hs.fs.freeSpace,
--               whose unit has differed between Hammerspoon versions in
--               a way no returned value can distinguish. See mp.freeSpace.
--               Note that on a modern Mac this is not "capacity minus
--               used": APFS shares space between volumes and counts
--               purgeable snapshots as available.
--   uptime      kern.boottime, so it survives this config reloading and
--               measures the MACHINE rather than Hammerspoon.
--   battery     percentage AND health, because a Mac that reports 100%
--               on a cycle-worn cell is the one you want to know about.
--   IP          the address on the PRIMARY interface — the one traffic
--               is actually leaving by, not the first one in a list, so
--               a VPN or a second adapter gives the answer you meant.
-- =====================================================================

local M = {
    name  = "Mac Panel",
    order = 14.06,
    family = "config",
    cheatsheet = {
        title = "🖥 MAC PANEL (⇪7 — About This Mac, as a card)",
        entries = {
            { "⇪7",     "Open the card — press it again to put it away" },
            { "shows",  "Model · chip · memory · macOS · serial, as Apple's does" },
            { "plus",   "Uptime · free disk · battery health · this Mac's IP" },
            { "drag",   "It moves, and stays where you drop it for the session" },
            { "check",  "_G.macReport() — the same figures as text, and copied" },
        },
    },
}

function M.setup(core)
    local mp = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    mp.enabled  = true
    mp.key      = "7"          -- ⇪7. A digit because there is no letter
    mp.keyMods  = {}           -- left; see the 6.119.0 note in init.lua.
    mp.width    = 340
    mp.height   = 268
    mp.margin   = 14           -- from the screen edge
    mp.slowWait = 6            -- seconds before system_profiler is abandoned
    mp.refresh  = 30           -- seconds between live-value redraws
    -- ----------------------------------------------------------------------

    -- 🎨 The shared style table, like every other panel since 6.90.0, with
    -- the literals kept as fallbacks for a boot where ui_style failed.
    local st = _G.uiStyle or {}
    mp.bg     = st.bg     or { red = 0.09, green = 0.10, blue = 0.13, alpha = 0.94 }
    mp.fg     = st.fg     or { white = 1.0, alpha = 0.97 }
    mp.dim    = { white = 1.0, alpha = 0.58 }
    mp.accent = st.accent or { red = 1.00, green = 0.84, blue = 0.00, alpha = 0.96 }

    mp.canvas   = nil     -- HELD: an unreferenced hs.canvas is collected
    mp.ticker   = nil     -- HELD
    mp.slowTask, mp.slowTimer = nil, nil   -- HELD
    mp.pos      = nil     -- where you dragged it, this session
    mp.slow     = { model = nil, serial = nil }
    mp.opens    = 0
    mp.lastNote = nil

    -- See the 🚨 note in mp.readSlow: constants so the external-binary
    -- review in test_diagnostics can see them.
    mp.SYSCTL   = "/usr/sbin/sysctl"
    mp.SWVERS   = "/usr/bin/sw_vers"
    mp.DF       = "/bin/df"
    mp.PROFILER = "/usr/sbin/system_profiler"
    mp.IOREG    = "/usr/sbin/ioreg"
    mp.GREP     = "/usr/bin/grep"

    local function say(m)  if _G.diag then _G.diag.say("macPanel", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("macPanel", m) end end
    local function note(m) mp.lastNote = m ; warn(m) end

    -- ---- the instant facts -----------------------------------------------
    local function sysctl(name)
        local out
        pcall(function() out = hs.execute(mp.SYSCTL .. " -n " .. name) end)
        if type(out) ~= "string" then return nil end
        out = out:match("^%s*(.-)%s*$")
        return out ~= "" and out or nil
    end

    function mp.humanBytes(n)
        n = tonumber(n) or 0
        if n >= 1024 ^ 4 then return ("%.2f TB"):format(n / 1024 ^ 4) end
        if n >= 1024 ^ 3 then return ("%.1f GB"):format(n / 1024 ^ 3) end
        if n >= 1024 ^ 2 then return ("%.0f MB"):format(n / 1024 ^ 2) end
        return tostring(math.floor(n)) .. " B"
    end

    -- kern.boottime prints "{ sec = 1699999999, usec = 0 } Mon Nov …".
    -- Only the sec field is parsed; the human tail is a different format
    -- on different macOS versions and is not worth depending on.
    function mp.uptimeFrom(boottime, now)
        local sec = tonumber(tostring(boottime or ""):match("sec%s*=%s*(%d+)"))
        if not sec then return nil end
        local d = math.floor((now or os.time()) - sec)
        if d < 0 then return nil end
        local days  = math.floor(d / 86400)
        local hours = math.floor((d % 86400) / 3600)
        local mins  = math.floor((d % 3600) / 60)
        if days  > 0 then return ("%dd %dh %dm"):format(days, hours, mins) end
        if hours > 0 then return ("%dh %dm"):format(hours, mins) end
        return ("%dm"):format(mins)
    end

    -- 🚨 FREE DISK COMES FROM `df -k`, WITH ITS UNIT WRITTEN ON IT.
    -- The obvious route is hs.fs.freeSpace, and it is not used here on
    -- purpose: its unit has differed between Hammerspoon versions
    -- (bytes in some, kilobytes in others), and there is no value it can
    -- return that distinguishes the two — 400 GB in bytes and 400 GB in
    -- kilobytes are both plausible readings of a real Mac. A heuristic
    -- over that is a display of free disk space that can be wrong by a
    -- factor of 1024, in the direction that makes you delete things.
    --
    -- `df -k` says kilobytes in its own name. One multiplication, no
    -- guess, and the same answer on every macOS this config runs on.
    function mp.parseDF(out)
        -- Header line, then: filesystem 1024-blocks used avail capacity …
        for line in tostring(out or ""):gmatch("[^\n]+") do
            local avail = line:match("^%S+%s+%d+%s+%d+%s+(%d+)%s")
            if avail then return tonumber(avail) * 1024 end
        end
        return nil
    end

    function mp.freeSpace()
        local out
        pcall(function() out = hs.execute(mp.DF .. " -k /") end)
        local bytes = mp.parseDF(out)
        if not bytes then return nil end
        return mp.humanBytes(bytes) .. " free"
    end

    function mp.batteryLine()
        local pct, health, cycles
        pcall(function() pct = hs.battery.percentage() end)
        if pct == nil then return nil end
        pcall(function() health = hs.battery.healthCondition() end)
        pcall(function() cycles = hs.battery.cycles() end)
        local s = ("%d%%"):format(math.floor(pct + 0.5))
        local charging
        pcall(function() charging = hs.battery.isCharging() end)
        if charging then s = s .. "  charging" end
        if cycles then s = s .. "   ·   " .. cycles .. " cycles" end
        -- healthCondition() returns nil when the battery is FINE, which
        -- reads backwards: nil means "no condition to report". Saying
        -- "Normal" is the honest rendering of that.
        s = s .. "   ·   " .. (health or "Normal")
        return s
    end

    -- The address on the interface traffic actually leaves by. The first
    -- entry of hs.network.interfaces() is not that — it is usually lo0 —
    -- and a panel that confidently shows 127.0.0.1 is worse than one that
    -- shows nothing.
    function mp.ipLine()
        local primary
        pcall(function() primary = hs.network.primaryInterfaces() end)
        local iface = type(primary) == "string" and primary or nil
        if not iface then return nil end
        local addr
        pcall(function()
            local d = hs.network.interfaceDetails(iface)
            if type(d) == "table" and type(d.IPv4) == "table"
               and type(d.IPv4.Addresses) == "table" then
                addr = d.IPv4.Addresses[1]
            end
        end)
        if not addr then return nil end
        return addr .. "   ·   " .. iface
    end

    function mp.facts()
        local f = {}
        f.host    = (hs.host and hs.host.localizedName and hs.host.localizedName())
                    or sysctl("kern.hostname") or "?"
        f.chip    = sysctl("machdep.cpu.brand_string") or "?"
        f.model   = mp.slow.model or sysctl("hw.model") or "?"
        f.serial  = mp.slow.serial
        local cores = sysctl("hw.ncpu")
        f.cores   = cores and (cores .. " cores") or nil
        f.memory  = mp.humanBytes(tonumber(sysctl("hw.memsize")))
        local ver, build
        pcall(function() ver = hs.execute(mp.SWVERS .. " -productVersion") end)
        pcall(function() build = hs.execute(mp.SWVERS .. " -buildVersion") end)
        ver   = type(ver)   == "string" and ver:match("^%s*(.-)%s*$")   or nil
        build = type(build) == "string" and build:match("^%s*(.-)%s*$") or nil
        f.os = "macOS " .. (ver or "?") .. (build and ("  (" .. build .. ")") or "")
        f.uptime = mp.uptimeFrom(sysctl("kern.boottime"), os.time())
        f.disk = mp.freeSpace()
        f.battery = mp.batteryLine()
        f.ip      = mp.ipLine()
        return f
    end

    -- ---- the two slow ones -----------------------------------------------
    function mp.readSlow()
        if mp.slowTask then return end
        local t
        local okNew = pcall(function()
            t = hs.task.new("/bin/sh", function(_, out)
                mp.slowTask = nil
                if mp.slowTimer then
                    pcall(function() mp.slowTimer:stop() end)
                    mp.slowTimer = nil
                end
                local text = tostring(out or "")
                local name = text:match("Model Name:%s*(.-)\n")
                local ident = text:match("Model Identifier:%s*(.-)\n")
                local chipLine = text:match("Chip:%s*(.-)\n")
                local serial = text:match("IOPlatformSerialNumber\"%s*=%s*\"(.-)\"")
                             or text:match("Serial Number %(system%):%s*(.-)\n")
                if name then
                    mp.slow.model = name:match("^%s*(.-)%s*$")
                    if ident then
                        mp.slow.model = mp.slow.model .. "   ("
                            .. ident:match("^%s*(.-)%s*$") .. ")"
                    end
                end
                if chipLine then mp.slow.chip = chipLine:match("^%s*(.-)%s*$") end
                if serial then mp.slow.serial = serial:match("^%s*(.-)%s*$") end
                say("slow facts in: " .. tostring(mp.slow.model))
                if mp.canvas then mp.draw() end
            end, { "-c",
                "/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null; "
                .. "/usr/sbin/ioreg -l 2>/dev/null | /usr/bin/grep -m1 IOPlatformSerialNumber" })
        end)
        if not (okNew and t) then
            note("could not read the model name or serial number")
            return
        end
        mp.slowTask = t
        pcall(function() t:start() end)
        mp.slowTimer = hs.timer.doAfter(mp.slowWait, function()
            mp.slowTimer = nil
            if mp.slowTask ~= t then return end
            pcall(function() t:terminate() end)
            mp.slowTask = nil
            note("system_profiler did not answer in " .. mp.slowWait .. "s")
            if mp.canvas then mp.draw() end
        end)
    end

    -- ---- drawing ---------------------------------------------------------
    local function panelFrame()
        local scr
        pcall(function() scr = core.resolveBaseScreen and core.resolveBaseScreen() end)
        if not scr then pcall(function() scr = hs.screen.mainScreen() end) end
        if not scr then return nil end
        local f
        pcall(function() f = scr:frame() end)
        if not f then return nil end
        if mp.pos then
            local p = _G.clampToScreen
                      and _G.clampToScreen(mp.pos, mp.width, mp.height) or mp.pos
            return { x = p.x, y = p.y, w = mp.width, h = mp.height }
        end
        return { x = f.x + f.w - mp.width - mp.margin,
                 y = f.y + mp.margin, w = mp.width, h = mp.height }
    end

    -- Every row is (label, value). A value that is not known yet reads
    -- "reading…"; a value that could not be read at all reads "—". Those
    -- are deliberately different: the first will change, the second will
    -- not, and showing one for the other is how you end up waiting for a
    -- number that is never coming.
    function mp.rows()
        local f = mp.facts()
        local function slow(v)
            if v then return v end
            return mp.slowTask and "reading…" or "—"
        end
        return {
            -- Model needs no "reading…": hw.model ("Mac14,2") is a real
            -- answer available instantly, and the marketing name replaces
            -- it in place when system_profiler lands.
            { "Model",   f.model },
            { "Chip",    mp.slow.chip or f.chip },
            { "Memory",  f.memory .. (f.cores and ("   ·   " .. f.cores) or "") },
            { "macOS",   f.os },
            { "Serial",  slow(mp.slow.serial) },
            { "Uptime",  f.uptime or "—" },
            { "Disk",    f.disk or "—" },
            { "Battery", f.battery or "no battery" },
            { "Network", f.ip or "not connected" },
        }
    end

    function mp.elements()
        local els = {
            { type = "rectangle", action = "fill", fillColor = mp.bg,
              roundedRectRadii = { xRadius = 12, yRadius = 12 } },
            { type = "text", text = "🖥  " .. ((hs.host and hs.host.localizedName
                                               and hs.host.localizedName()) or "This Mac"),
              textColor = mp.accent, textSize = 15,
              frame = { x = 16, y = 12, w = mp.width - 32, h = 20 } },
        }
        local y = 40
        for _, r in ipairs(mp.rows()) do
            els[#els + 1] = {
                type = "text", text = r[1], textColor = mp.dim, textSize = 11,
                frame = { x = 16, y = y, w = 66, h = 16 },
            }
            els[#els + 1] = {
                type = "text", text = tostring(r[2]), textColor = mp.fg,
                textSize = 11,
                frame = { x = 84, y = y, w = mp.width - 100, h = 16 },
            }
            y = y + 18
        end
        els[#els + 1] = {
            type = "text", text = "⇪7 closes  ·  drag to move",
            textColor = mp.dim, textSize = 10,
            frame = { x = 16, y = mp.height - 22, w = mp.width - 32, h = 14 },
        }
        return els
    end

    function mp.draw()
        if not mp.canvas then return false end
        return pcall(function() mp.canvas:replaceElements(mp.elements()) end)
    end

    function mp.open()
        local frame = panelFrame()
        if not frame then
            note("no screen to draw on")
            hs.alert.show("🖥 Mac panel: no screen to draw on", 3)
            return false
        end
        local okNew, c = pcall(hs.canvas.new, frame)
        if not (okNew and c) then
            note("hs.canvas.new failed")
            hs.alert.show("🖥 Mac panel could not open — see the Console", 3)
            return false
        end
        mp.canvas = c
        mp.readSlow()
        pcall(function()
            -- 🪟 Through _G.panelLevel, never a bare `overlay`. Two panels
            -- at one level stack by whichever was shown last, which makes
            -- "is it in front?" depend on the order you pressed the keys.
            c:level((_G.panelLevel and _G.panelLevel("macpanel"))
                    or (hs.canvas.windowLevels or {}).overlay)
            -- 🚨 fullScreenAuxiliary, not "stationary". Without it a canvas
            -- cannot draw over a full-screen app AT ALL — and the symptom
            -- is not a drawing bug, it is "the shortcut did nothing".
            c:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
        end)
        mp.draw()
        if _G.makeCanvasDraggable then
            _G.makeCanvasDraggable(c, "macpanel", function(f)
                mp.pos = { x = f.x, y = f.y }
            end)
        end
        -- 🚨 showCanvasSafely, not a bare :show(). AppKit asserts when our
        -- window is ordered on screen while another process's remote view
        -- is mid-transition; the shared helper retries a run loop turn
        -- later instead of throwing and leaving a half-ordered ghost.
        local okShow = (_G.showCanvasSafely and _G.showCanvasSafely(c, "macpanel"))
                       or pcall(function() c:show() end)
        if not okShow then
            mp.close()
            note("the panel could not be shown")
            hs.alert.show("🖥 Mac panel could not draw — see the Console", 3)
            return false
        end
        mp.opens = mp.opens + 1
        -- The live half — uptime, disk, battery, IP — goes stale while the
        -- card sits open, so it redraws on a slow cadence. Slow on purpose:
        -- none of these change in a way you would watch.
        mp.ticker = hs.timer.doEvery(mp.refresh, function()
            if mp.canvas then mp.draw() end
        end)
        say("opened")
        return true
    end

    function mp.close()
        if mp.ticker then
            pcall(function() mp.ticker:stop() end)
            mp.ticker = nil
        end
        if mp.canvas then
            pcall(function() mp.canvas:delete() end)
            mp.canvas = nil
        end
        return true
    end

    function mp.toggle()
        if not mp.enabled then return false end
        if mp.canvas then return mp.close() end
        return mp.open()
    end

    -- ---- the report ------------------------------------------------------
    function _G.macReport()
        local L = { "🖥 THIS MAC" }
        for _, r in ipairs(mp.rows()) do
            L[#L + 1] = ("   %-9s %s"):format(r[1], tostring(r[2]))
        end
        L[#L + 1] = "   opened  : " .. mp.opens .. " time(s) this session"
        if mp.lastNote then L[#L + 1] = "   last problem: " .. mp.lastNote end
        local s = table.concat(L, "\n")
        print(s)
        pcall(function() hs.pasteboard.setContents(s) end)
        return s
    end

    if mp.enabled then
        core.hyperAddShortcut(mp.keyMods, mp.key, function() mp.toggle() end,
                              "mac panel")
    end
    core.provide("mac.toggle", function() return mp.toggle() end)
    core.provide("mac.report", function() return _G.macReport() end)

    _G.macPanel = mp
    M.mp     = mp
    M.config = mp
end

return M
