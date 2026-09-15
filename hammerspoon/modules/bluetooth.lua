-- =====================================================================
-- 📶 BLUETOOTH — CONNECT OR DISCONNECT ANY PAIRED DEVICE (⇪⇧7)
-- =====================================================================
-- 6.216.0 — LL: "Bluetooth: connect/disconnect AirPods or any device,
-- reliably." ⇪⇧7 lists every device this Mac has paired, says which
-- are connected, and ⏎ on a row flips it. It sits beside ⇪6 (network)
-- and ⇪7 (the Mac panel) in the This Mac group.
--
-- TWO ENGINES, BECAUSE THE WORK MAC MAY HAVE ONLY ONE. macOS ships no
-- command that connects a Bluetooth device; `blueutil` (Homebrew) is
-- the one that does, and it may not exist on a managed Mac. So:
--   · blueutil present → `--paired` lists (name, address, connected),
--     `--connect ADDR` / `--disconnect ADDR` act; the exit code and
--     stderr are the verdict, and a failure names both.
--   · blueutil absent → /usr/sbin/system_profiler SPBluetoothDataType
--     still lists the paired devices and their state (it is on every
--     Mac), the picker opens with the same rows, and ⏎ opens System
--     Settings › Bluetooth — one click from the device — while the
--     top row copies `brew install blueutil`. The absence goes through
--     the degrade door (6.215.0) once per ten minutes, never silently.
-- Every command is an hs.task with an ARGUMENT ARRAY (no shell; the
-- address comes from the tool's own output, never from typing), held
-- in its own slot (`bt.tasks.list` / `bt.tasks.act` / `bt.tasks.open`)
-- with its own killer timer — 6.196.1's rule — and nothing here ever
-- starts a task from inside another task's callback. The parsers are
-- PURE (`bt.parseBlueutil`, `bt.parseProfiler`), so the gate proves
-- them against real output shapes with no Mac: "not connected"
-- contains "connected", and the first parser written read it as
-- connected — that row is in the suite. Nothing runs at boot; the
-- binary is looked up at PRESS time, so a brew install mid-session is
-- seen on the next ⇪⇧7 with no reload.
-- Off: settings = { bluetooth = { on = false } }. Pin the binary:
-- settings = { bluetooth = { blueutil = "/opt/homebrew/bin/blueutil" } }.
-- =====================================================================
local M = {
    name    = "Bluetooth",
    order   = 14.08,
    family  = "config",
    summary = "⇪⇧7 lists every paired Bluetooth device — ⏎ connects or disconnects it",
    cheatsheet = {
        title = "📶 BLUETOOTH (⇪⇧7 — connect · disconnect AirPods or any paired device)",
        entries = {
            { "⇪⇧7",     "Every paired device, 🟢 connected or ⚪ not — ⏎ flips it" },
            { "engine",  "blueutil (brew) connects and disconnects; without it the list still" },
            { "",        "works and ⏎ opens System Settings › Bluetooth — the top row copies the install" },
            { "verdict", "a connect that fails says the exit code and blueutil's own words" },
            { "check",   "_G.bluetoothReport() — the engine, the devices, the last action" },
            { "off",     "settings = { bluetooth = { on = false } }" },
        },
    },
}

function M.setup(core)
    core = core or {}
    local bt = {
        on          = true,
        key         = "7",
        keyMods     = { "shift" },
        blueutil    = nil,          -- settings pin; nil = look in `candidates`
        candidates  = { "/opt/homebrew/bin/blueutil", "/usr/local/bin/blueutil" },
        PROFILER    = "/usr/sbin/system_profiler",
        OPEN        = "/usr/bin/open",
        SETTINGS_URL = "x-apple.systempreferences:com.apple.BluetoothSettings",
        BREW        = "brew install blueutil",
        listSecs    = 20,           -- system_profiler can take a while on a cold Mac
        actSecs     = 15,           -- blueutil --connect blocks until the device answers
        -- state
        bin         = nil,          -- resolved blueutil path, or nil
        binWhy      = nil,
        devices     = {},           -- { name, addr, connected }
        listedAt    = nil,
        listedVia   = nil,
        listWhy     = nil,
        tasks       = {},           -- slot → hs.task (list / act / open)
        timers      = {},           -- slot → killer timer
        running     = nil,          -- label of the task in flight
        runs        = 0,
        lastMs      = nil,
        lastAction  = nil,          -- { what, name, code, err, at }
        lastNote    = nil,
        degrades    = 0,
        chooser     = nil,
    }
    M.config = bt
    _G.bluetooth = bt

    local function now() return hs.timer.secondsSinceEpoch() end
    local function clock() return os.date("%H:%M:%S") end
    local function alert(m, secs) pcall(function() hs.alert.show(m, secs or 3) end) end
    local function firstLine(s)
        s = tostring(s or ""):gsub("^%s+", "")
        return (s:match("^([^\n]*)") or ""):gsub("%s+$", "")
    end
    -- 6.215.0's door: an alert, a ⚠️ Console line, a ledger row, false, why.
    function bt.degrade(why)
        bt.degrades = bt.degrades + 1
        bt.lastNote = why
        if type(core.degrade) == "function" then return core.degrade("Bluetooth", why) end
        print("⚠️ Bluetooth: " .. tostring(why))
        return false, why
    end

    -- ---- the binary, looked up at press time -----------------------------
    function bt.resolve()
        local function exists(p)
            local ok, a = pcall(hs.fs.attributes, p)
            return ok and type(a) == "table" and a.mode == "file"
        end
        if type(bt.blueutil) == "string" and bt.blueutil ~= "" then
            if exists(bt.blueutil) then bt.bin, bt.binWhy = bt.blueutil, nil; return bt.bin end
            bt.bin, bt.binWhy = nil, "settings pin " .. bt.blueutil .. " is not a file"
            return nil, bt.binWhy
        end
        for _, p in ipairs(bt.candidates) do
            if exists(p) then bt.bin, bt.binWhy = p, nil; return p end
        end
        bt.bin, bt.binWhy = nil, "blueutil not installed (" .. bt.BREW .. ")"
        return nil, bt.binWhy
    end

    -- ---- the parsers, pure -----------------------------------------------
    -- blueutil --paired, one device per line:
    --   address: 94-16-25-aa-bb-cc, connected (master, -49 dBm), not favourite, paired, name: "AirPods Pro", recent access date: …
    --   address: 5c-e9-1e-aa-bb-cc, not connected, not favourite, paired, name: "Magic Keyboard", …
    function bt.parseBlueutil(text)
        local list = {}
        for line in tostring(text or ""):gmatch("[^\n]+") do
            local addr = line:match("address:%s*([%x][%x%-:]+)")
            if addr then
                local name = line:match('name:%s*"([^"]*)"') or line:match("name:%s*([^,]+)")
                if not name or name:gsub("%s", "") == "" then name = addr end
                -- "not connected" contains "connected": ask for the comma-bounded field
                local connected = line:find(",%s*connected", 1) ~= nil
                                  and line:find(",%s*not connected", 1) == nil
                list[#list + 1] = { name = name, addr = addr, connected = connected }
            end
        end
        if #list == 0 then return list, "blueutil listed no paired devices" end
        return list
    end

    -- system_profiler SPBluetoothDataType (text). Two shapes, both kept:
    --   Monterey and later:   Connected: / Not Connected: sections, each
    --                          device a header under it, "Address:" inside.
    --   Catalina and earlier: Devices (Paired, Configured, etc.): with a
    --                          "Connected: Yes|No" line inside each device.
    function bt.parseProfiler(text)
        local list, byAddr = {}, {}
        local section, sectionIndent = nil, nil
        local dev, devIndent = nil, nil
        for line in tostring(text or ""):gmatch("[^\n]+") do
            local indent, head = line:match("^(%s*)([^:]+):%s*$")
            local kIndent, k, v = line:match("^(%s*)([^:]+):%s*(.-)%s*$")
            if head then
                local h = head:gsub("^%s+", "")
                if h == "Connected" or h == "Not Connected" then
                    section, sectionIndent, dev = h, #indent, nil
                elseif section and #indent > sectionIndent then
                    dev = { name = h, connected = (section == "Connected") }
                    devIndent = #indent
                    list[#list + 1] = dev
                elseif #indent > 0 and not section then
                    -- the old shape: any device header under "Devices …"
                    if h ~= "Bluetooth" and not h:find("^Devices") and not h:find("Controller") then
                        dev = { name = h, connected = false }
                        devIndent = #indent
                        list[#list + 1] = dev
                    end
                elseif section and #indent <= sectionIndent then
                    section, dev = nil, nil
                end
            elseif k and dev and #kIndent > (devIndent or 0) then
                k = k:gsub("^%s+", "")
                if k == "Address" or k == "Device Address" then dev.addr = v
                elseif k == "Connected" then dev.connected = (v == "Yes") end
            end
        end
        local kept = {}
        for _, d in ipairs(list) do
            d.addr = d.addr or ""
            if d.addr == "" or not byAddr[d.addr] then
                byAddr[d.addr] = true
                kept[#kept + 1] = d
            end
        end
        if #kept == 0 then return kept, "system_profiler listed no paired devices" end
        return kept
    end

    -- ---- one bounded task per slot ---------------------------------------
    function bt.run(slot, bin, args, label, secs, done)
        if bt.running then
            alert("📶 " .. tostring(bt.running) .. " is still running — wait for it or press Esc", 3)
            return false, "busy"
        end
        local t0 = now()
        local t
        local okNew = pcall(function()
            t = hs.task.new(bin, function(code, out, err)
                bt.tasks[slot] = nil
                bt.running = nil
                if bt.timers[slot] then
                    pcall(function() bt.timers[slot]:stop() end)
                    bt.timers[slot] = nil
                end
                bt.lastMs = math.floor((now() - t0) * 1000)
                bt.runs = bt.runs + 1
                pcall(done, tonumber(code) or -1, tostring(out or ""), tostring(err or ""))
            end, args)
        end)
        if not (okNew and t) then
            return bt.degrade("could not start " .. bin .. " for " .. label)
        end
        bt.tasks[slot] = t
        bt.running = label
        local okStart = pcall(function() t:start() end)
        if not okStart then
            bt.tasks[slot], bt.running = nil, nil
            return bt.degrade(bin .. " refused to start for " .. label)
        end
        bt.timers[slot] = hs.timer.doAfter(secs, function()
            bt.timers[slot] = nil
            if bt.tasks[slot] ~= t then return end
            pcall(function() t:terminate() end)
            bt.tasks[slot], bt.running = nil, nil
            bt.degrade(label .. " did not finish within " .. secs .. " s")
        end)
        return true
    end

    -- ---- the picker ------------------------------------------------------
    local function rowsFor()
        local rows = {}
        if not bt.bin then
            rows[#rows + 1] = { text = "🍺 " .. bt.BREW, act = "install", addr = "",
                subText = "⏎ copies the command — with blueutil installed, ⏎ on a device connects or disconnects it" }
        end
        for _, d in ipairs(bt.devices) do
            local state = d.connected and "🟢 " or "⚪ "
            local sub
            if bt.bin then
                sub = d.connected and "connected · ⏎ disconnects" or "not connected · ⏎ connects"
            else
                sub = (d.connected and "connected" or "not connected")
                      .. " · ⏎ opens System Settings › Bluetooth (blueutil not installed)"
            end
            rows[#rows + 1] = { text = state .. d.name, subText = sub,
                                addr = d.addr or "", act = bt.bin and "toggle" or "open" }
        end
        return rows
    end

    function bt.deviceFor(addr)
        for _, d in ipairs(bt.devices) do if d.addr == addr then return d end end
        return nil
    end

    function bt.pick(row)
        if not row then return false, "cancelled" end
        if row.act == "install" then
            local put = false
            pcall(function() put = hs.pasteboard.setContents(bt.BREW) end)
            if put then alert("📶 Copied: " .. bt.BREW .. " — paste it into Terminal", 4); return true end
            return bt.degrade("could not put '" .. bt.BREW .. "' on the clipboard")
        end
        if row.act == "open" then
            local ok = bt.run("open", bt.OPEN, { bt.SETTINGS_URL }, "System Settings › Bluetooth", 8,
                function(code, _, err)
                    if code ~= 0 then bt.degrade("System Settings did not open — open exit " .. code .. ": " .. firstLine(err)) end
                end)
            if ok then alert("📶 Opening System Settings › Bluetooth — blueutil would do this from here", 3) end
            return ok
        end
        local d = bt.deviceFor(row.addr)
        if not d then return bt.degrade("that device is no longer in the list — press ⇪⇧7 again") end
        return bt.toggle(d)
    end

    function bt.toggle(d)
        if not bt.bin then return bt.degrade("cannot connect without blueutil (" .. bt.BREW .. ")") end
        local what = d.connected and "disconnect" or "connect"
        local args = { "--" .. what, d.addr }
        local ok = bt.run("act", bt.bin, args, what .. " " .. d.name, bt.actSecs,
            function(code, out, err)
                bt.lastAction = { what = what, name = d.name, code = code,
                                  err = firstLine(err ~= "" and err or out), at = clock() }
                if code == 0 then
                    d.connected = (what == "connect")
                    alert("📶 " .. (d.connected and "Connected — " or "Disconnected — ") .. d.name, 3)
                else
                    bt.degrade(what .. " " .. d.name .. " failed — blueutil exit " .. code
                        .. (bt.lastAction.err ~= "" and (": " .. bt.lastAction.err) or ""))
                end
            end)
        if ok then alert("📶 " .. (what == "connect" and "Connecting " or "Disconnecting ") .. d.name .. "…", 2) end
        return ok
    end

    function bt.open()
        if not bt.chooser then
            bt.chooser = hs.chooser.new(function(row) bt.pick(row) end)
            _G.choosers = _G.choosers or {}
            _G.choosers.bluetooth = bt.chooser
            pcall(function()
                bt.chooser:searchSubText(true)
                bt.chooser:width(50)
            end)
        end
        local rows = rowsFor()
        bt.chooser:choices(rows)
        local n = #bt.devices
        bt.chooser:placeholderText(string.format("%d paired device%s · via %s · ⏎ %s", n, n == 1 and "" or "s",
            bt.listedVia or "?", bt.bin and "connects or disconnects" or "opens System Settings"))
        bt.chooser:query("")
        -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
        -- last picker's coordinates standing (6.127.0).
        if core.showPopup then core.showPopup(bt.chooser) else bt.chooser:show() end
        return true
    end

    function bt.list(cb)
        local bin, args, via
        if bt.bin then bin, args, via = bt.bin, { "--paired" }, "blueutil"
        else bin, args, via = bt.PROFILER, { "SPBluetoothDataType" }, "system_profiler" end
        return bt.run("list", bin, args, "listing Bluetooth devices", bt.listSecs,
            function(code, out, err)
                if code ~= 0 then
                    bt.listWhy = via .. " exit " .. code .. ": " .. firstLine(err ~= "" and err or out)
                    return bt.degrade("could not list devices — " .. bt.listWhy)
                end
                local list, why = via == "blueutil" and bt.parseBlueutil(out) or bt.parseProfiler(out)
                bt.devices, bt.listedAt, bt.listedVia, bt.listWhy = list, clock(), via, why
                if cb then pcall(cb, list, why) end
            end)
    end

    function bt.show()
        if bt.on == false then alert("📶 Bluetooth is off in settings", 2); return false, "off" end
        bt.resolve()
        if not bt.bin then bt.degrade(bt.binWhy .. " — listing only; ⏎ opens System Settings") end
        return bt.list(function(list, why)
            if #list == 0 then alert("📶 No paired Bluetooth devices — " .. tostring(why), 4); return end
            bt.open()
        end)
    end

    -- ---- the report, ONE string -------------------------------------------
    function _G.bluetoothReport()
        local L = {}
        L[#L + 1] = "📶 BLUETOOTH — ⇪⇧7 · " .. (bt.on == false and "OFF (settings)" or "on")
        bt.resolve()
        if bt.bin then L[#L + 1] = "   engine  : " .. bt.bin .. " — connects and disconnects"
        elseif type(bt.blueutil) == "string" and bt.blueutil ~= "" then
            L[#L + 1] = "   engine  : ⚠️ " .. tostring(bt.binWhy) .. " — listing via system_profiler only"
        else
            L[#L + 1] = "   engine  : blueutil not installed — listing via system_profiler; ⏎ opens System Settings (" .. bt.BREW .. ")"
        end
        if bt.listedAt then
            L[#L + 1] = string.format("   devices : %d via %s at %s%s", #bt.devices, bt.listedVia, bt.listedAt,
                bt.listWhy and (" — " .. bt.listWhy) or "")
            for _, d in ipairs(bt.devices) do
                L[#L + 1] = string.format("      %s %-28s %s", d.connected and "🟢" or "⚪", d.name, d.addr or "")
            end
        elseif bt.listWhy then
            L[#L + 1] = "   devices : ⚠️ list failed — " .. bt.listWhy
        else
            L[#L + 1] = "   devices : not listed yet — press ⇪⇧7"
        end
        local a = bt.lastAction
        if a then
            L[#L + 1] = string.format("   last    : %s %s at %s — %s", a.what, a.name, a.at,
                a.code == 0 and "ok" or ("⚠️ exit " .. a.code .. (a.err ~= "" and (": " .. a.err) or "")))
        else
            L[#L + 1] = "   last    : no connect or disconnect this session"
        end
        L[#L + 1] = string.format("   runs    : %d · last %s ms · %d degrade(s)%s", bt.runs,
            bt.lastMs and tostring(bt.lastMs) or "—", bt.degrades,
            bt.running and (" · running: " .. bt.running) or "")
        if bt.lastNote then L[#L + 1] = "   note    : " .. bt.lastNote end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    if core.hyperAddShortcut then
        core.hyperAddShortcut(bt.keyMods, bt.key, function() return bt.show() end, "bluetooth")
    end
    if core.provide then
        core.provide("bluetooth.show",   function() return bt.show() end)
        core.provide("bluetooth.report", function() return _G.bluetoothReport() end)
    end
end

return M
