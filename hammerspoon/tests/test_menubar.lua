-- =====================================================================
-- test_menubar.lua — the module whose worst failure is a FROZEN keyboard
-- =====================================================================
--     lua5.4 test_menubar.lua [/path/to/hammerspoon]
--
-- Reading another app's Accessibility tree is a synchronous call into
-- that app. If it is wedged, the call blocks Hammerspoon's main thread —
-- and that thread is the keyboard. This config has met that failure
-- before: 6.33.0's ⌥Tab froze for the same reason. So the centre of this
-- suite is a stubbed app that NEVER answers, and the assertion that the
-- scan gives up on it rather than waiting.
--
-- The other half is honesty: this module must never claim to do the
-- thing it cannot do (hide icons), and must say what to use instead.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end
local function out(s) io.write(s) end

-- ---- a controllable Accessibility world ------------------------------
local printed, ALERTS, CLICKS = {}, {}, {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end
local NOW, AX_OK = 1000, true
local APPS, TIMEOUTS_SET, CHOOSERS = {}, {}, {}
local HYPER, PROVIDED = {}, {}

-- Each fake app: name, a list of {desc}, and optionally hangs=<seconds it
-- burns off the clock when asked>. A hanging app is how a real wedged app
-- behaves from Hammerspoon's side.
local function mkApp(name, items, hangs)
    return { _name = name, _items = items, _hangs = hangs,
             name = function(self) return self._name end }
end

local function mkElement(kind, owner)
    local e = { kind = kind, owner = owner, actions = {} }
    function e:attributeValue(a)
        if self.kind == "app" then
            if a == "AXExtrasMenuBar" then
                if self.owner._hangs then
                    NOW = NOW + self.owner._hangs      -- the app burns clock
                    return nil                          -- ...and answers nothing
                end
                if not self.owner._items then return nil end
                return mkElement("extras", self.owner)
            end
        elseif self.kind == "extras" then
            if a == "AXChildren" then
                local kids = {}
                for _, it in ipairs(self.owner._items or {}) do
                    local k = mkElement("item", self.owner)
                    k.desc = it.desc ; k.pos = it.pos ; k.size = it.size
                    k.refuse = it.refuse
                    kids[#kids + 1] = k
                end
                return kids
            end
        elseif self.kind == "item" then
            if a == "AXDescription" then return self.desc end
            if a == "AXTitle" then return nil end
            if a == "AXPosition" then return self.pos end
            if a == "AXSize" then return self.size end
        end
        return nil
    end
    function e:setTimeout(t) TIMEOUTS_SET[self.owner._name] = t ; return self end
    function e:performAction(a)
        if self.refuse then error("refused") end
        self.actions[#self.actions + 1] = a
        ACTIONS[#ACTIONS + 1] = { app = self.owner._name, action = a }
        return true
    end
    return e
end
ACTIONS = {}

hs = {
    accessibilityState = function() return AX_OK end,
    application = { runningApplications = function() return APPS end },
    axuielement = { applicationElement = function(app)
        return mkElement("app", app) end },
    timer = { secondsSinceEpoch = function() NOW = NOW + 0.0001 ; return NOW end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    chooser = { new = function(fn)
        local c = { fn = fn, shown = false }
        for _, m in ipairs({ "searchSubText", "width", "placeholderText" }) do
            c[m] = function(self) return self end
        end
        function c:choices(x) self.rows = x ; return self end
        function c:show() self.shown = true ; return self end
        CHOOSERS[#CHOOSERS + 1] = c ; return c end },
    mouse = { absolutePosition = function(p) MOUSE = p end },
    eventtap = { leftClick = function(p) CLICKS[#CLICKS + 1] = p end },
    pasteboard = { setContents = function() return true end },
}
_G.diag = { said = {},
    say = function(_, m) _G.diag.said[#_G.diag.said + 1] = "say " .. m end,
    warn = function(_, m) _G.diag.said[#_G.diag.said + 1] = "warn " .. m end,
    err = function() end, mark = function() end }
local function warned(n)
    for _, l in ipairs(_G.diag.said) do
        if l:sub(1, 4) == "warn" and l:find(n, 1, true) then return true end
    end
end

local CORE = {
    hostTag = "Test-Mac",
    resolveBaseScreen = function() return nil end,
    hyperAddShortcut = function(mods, key, fn)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms) ; HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local M, MB
local function boot()
    printed, ALERTS, CLICKS, ACTIONS = {}, {}, {}, {}
    TIMEOUTS_SET, CHOOSERS, HYPER, PROVIDED = {}, {}, {}, {}
    _G.diag.said = {} ; AX_OK = true ; NOW = 1000
    M = dofile(HS .. "/modules/menubar_items.lua")
    M.setup(CORE)
    MB = _G.menuBarItems
    return MB
end

-- =====================================================================
out("\n=== 1. Contract and honesty ===\n")
-- =====================================================================
APPS = {} ; boot()
check("loads and sets up", M ~= nil and MB ~= nil)
check("⇪M is claimed", HYPER["|m"] ~= nil)
check("⇪⇧M is claimed", HYPER["shift|m"] ~= nil)
check("services published", PROVIDED["menuBar.list"] ~= nil)
check("nothing is scanned at load — setup() must not walk every running "
      .. "app's Accessibility tree during boot", MB.cache == nil)

do
    local f = io.open(HS .. "/modules/menubar_items.lua", "r")
    local body = f:read("*a") ; f:close()
    check("🚨 the file states plainly that it CANNOT hide icons, rather than "
          .. "implying it is a Bartender clone",
          body:find("NOT BARTENDER, AND IT CANNOT BE", 1, true) ~= nil)
    check("...and names a real alternative for the half it cannot do",
          body:find("jordanbaird/Ice", 1, true) ~= nil)
    check("the cheat sheet says so too, where you would actually read it",
          body:find("This does NOT hide icons", 1, true) ~= nil)
    check("it never draws over the menu bar — a black strip it cannot redraw "
          .. "icons into is not worth shipping",
          body:find("hs%.canvas") == nil)
    local code = body:gsub("%-%-[^\n]*", "")
    -- Comments stripped first: "snapshot" appears in the note about
    -- 6.33.0's freeze, and a scanner that reads prose as code lies.
    check("it needs no Screen Recording", code:find("snapshot") == nil)
    for _, bad in ipairs({ "sudo", "os%.execute", "io%.popen", "hs%.task", "hs%.http" }) do
        check("runs no " .. bad:gsub("%%", ""), code:find(bad) == nil)
    end
end

-- =====================================================================
out("\n=== 2. 🚨 A WEDGED APP MUST NOT FREEZE THE KEYBOARD ===\n")
-- =====================================================================
out("   -- the timeout is set BEFORE anything is asked --\n")
APPS = { mkApp("Dropbox", { { desc = "Syncing" } }) }
boot() ; MB.scan(true)
check("every app element gets an explicit Accessibility timeout — the one "
      .. "line standing between a wedged app and a frozen keyboard",
      TIMEOUTS_SET["Dropbox"] == MB.axTimeout, TIMEOUTS_SET["Dropbox"])

out("   -- one app that never answers --\n")
APPS = { mkApp("Good", { { desc = "fine" } }), mkApp("Wedged", nil, 0.5),
         mkApp("AlsoGood", { { desc = "also fine" } }) }
boot()
local items = MB.scan(true)
check("a hanging app does not stop the scan", items ~= nil)
check("...and the apps AFTER it are still found — giving up early on one "
      .. "bad app must not cost you the rest", (function()
    for _, e in ipairs(items or {}) do if e.app == "AlsoGood" then return true end end
end)(), items and #items)

out("   -- many wedged apps: the whole scan is time-boxed --\n")
APPS = {}
for i = 1, 40 do APPS[#APPS + 1] = mkApp("Wedged" .. i, nil, 1.0) end
APPS[#APPS + 1] = mkApp("Good", { { desc = "x" } })
boot()
local t0 = NOW
MB.scan(true)
local burned = NOW - t0
check("🚨 the scan STOPS at its budget instead of walking 40 wedged apps — "
      .. "the difference between a slow press and a minute of dead keyboard",
      burned <= MB.scanBudget + 1.5, string.format("%.1fs of clock burned", burned))
check("...and says the budget was hit rather than failing silently",
      warned("budget exhausted"))

out("   -- an app that throws instead of hanging --\n")
APPS = { mkApp("Exploder", { { desc = "boom" } }) }
APPS[1]._items = nil
boot()
local savedAE = hs.axuielement.applicationElement
hs.axuielement.applicationElement = function() error("AX blew up") end
local ok = pcall(MB.scan, true)
hs.axuielement.applicationElement = savedAE
check("an Accessibility call that THROWS is contained", ok)

-- =====================================================================
out("\n=== 3. Listing and activating ===\n")
-- =====================================================================
APPS = {
    mkApp("Dropbox",   { { desc = "Syncing 3 files" } }),
    mkApp("1Password", { { desc = nil } }),
    mkApp("Zoom",      { { desc = "Meeting" }, { desc = "Mute" } }),
    mkApp("Hammerspoon", { { desc = "should be skipped" } }),
}
boot()
items = MB.scan(true)
check("every app's items are found, including an app with two",
      #items == 4, #items and #items)
check("Hammerspoon's own item is skipped — listing yourself is noise",
      (function()
    for _, e in ipairs(items) do if e.app == "Hammerspoon" then return false end end
    return true
end)())
check("items are sorted by owning app, so the list is stable between presses",
      items[1].app <= items[2].app and items[2].app <= items[3].app)
check("an item with a description keeps it as the detail line", (function()
    for _, e in ipairs(items) do
        if e.app == "Dropbox" then return e.detail == "Syncing 3 files" end
    end
end)())
check("an item with NO description still appears — most menu bar extras "
      .. "set neither title nor description, so the app name has to carry it",
      (function()
    for _, e in ipairs(items) do
        if e.app == "1Password" then return e.detail == nil end
    end
end)())

out("   -- the picker --\n")
boot() ; HYPER["|m"]()
check("⇪M opens a chooser", #CHOOSERS == 1 and CHOOSERS[1].shown)
check("...listing every item", #CHOOSERS[1].rows == 4, #CHOOSERS[1].rows)
check("...with the app as the row and the description beneath",
      CHOOSERS[1].rows[1].text ~= nil and CHOOSERS[1].rows[1].subText ~= nil)
CHOOSERS[1].fn(CHOOSERS[1].rows[1])
check("picking a row activates that item", #ACTIONS == 1, #ACTIONS)
check("...via AXPress, the correct action", ACTIONS[1].action == "AXPress")
CHOOSERS[1].fn(nil)
check("dismissing the chooser does nothing at all", #ACTIONS == 1)

out("   -- an item that refuses every action --\n")
APPS = { mkApp("Stubborn", { { desc = "no", refuse = true,
                               pos = { x = 100, y = 5 }, size = { w = 20, h = 22 } } }) }
boot() ; items = MB.scan(true)
MB.activate(items[1])
check("an item that implements neither AXPress nor AXShowMenu falls back to "
      .. "clicking its own coordinates", #CLICKS == 1, #CLICKS)
check("...at the centre of the item", CLICKS[1] and CLICKS[1].x == 110)

APPS = { mkApp("Hopeless", { { desc = "no", refuse = true } }) }   -- no position either
boot() ; items = MB.scan(true)
MB.activate(items[1])
check("an item with no position either is reported, not silently ignored",
      #ALERTS > 0 and ALERTS[#ALERTS]:find("would not respond", 1, true) ~= nil)

-- =====================================================================
out("\n=== 4. No Accessibility, no pretending ===\n")
-- =====================================================================
APPS = { mkApp("Dropbox", { { desc = "x" } }) }
boot() ; AX_OK = false
HYPER["|m"]()
check("without Accessibility it explains itself instead of showing an "
      .. "empty list", #CHOOSERS == 0 and #ALERTS > 0)
check("...naming the exact setting to change",
      ALERTS[#ALERTS]:find("Privacy & Security", 1, true) ~= nil)
check("scan() refuses rather than returning a misleading empty list",
      select(1, MB.scan(true)) == nil)
AX_OK = true

APPS = {}
boot() ; HYPER["|m"]()
check("zero items found says WHY that might be, rather than looking broken",
      #ALERTS > 0 and ALERTS[#ALERTS]:find("without Accessibility support", 1, true) ~= nil)

-- =====================================================================
out("\n=== 5. Caching, and the report ===\n")
-- =====================================================================
APPS = { mkApp("Dropbox", { { desc = "x" } }) }
boot()
MB.scan(true)
local n1 = 0
for _ in pairs(TIMEOUTS_SET) do n1 = n1 + 1 end
TIMEOUTS_SET = {}
MB.scan(false) ; MB.scan(false)
local n2 = 0
for _ in pairs(TIMEOUTS_SET) do n2 = n2 + 1 end
check("repeated presses reuse the cache rather than re-walking every app's "
      .. "Accessibility tree", n2 == 0, n2)
check("...but force re-scans", (function()
    TIMEOUTS_SET = {} ; MB.scan(true)
    local n = 0 ; for _ in pairs(TIMEOUTS_SET) do n = n + 1 end
    return n > 0
end)())

APPS = { mkApp("Dropbox", { { desc = "Syncing" } }), mkApp("Zoom", { { desc = "Mute" } }) }
boot()
local r = _G.menuBarReport()
check("_G.menuBarReport() returns its text", type(r) == "string")
check("it lists each item and its owner", r:find("Dropbox", 1, true) ~= nil
      and r:find("Zoom", 1, true) ~= nil)
check("it reports how long the scan took — the number that tells you an "
      .. "app is misbehaving", r:find("ms", 1, true) ~= nil)
check("🚨 the report itself repeats that it cannot hide icons, so the "
      .. "limitation is visible where you look rather than only in a comment",
      r:find("CANNOT hide", 1, true) ~= nil)
check("...and points at Ice", r:find("Ice", 1, true) ~= nil)
AX_OK = false
r = _G.menuBarReport()
check("the report without Accessibility says so", (function()
    for _, l in ipairs(printed) do
        if l:find("not granted", 1, true) then return true end
    end
end)())
AX_OK = true

-- =====================================================================
out("\n=== 6. THE EXPLORER — 500 random Mac populations ===\n")
-- =====================================================================
-- Random mixes of well-behaved apps, apps that hang for random lengths,
-- apps that throw, and apps whose items refuse every action. The
-- property that matters is the one that keeps your keyboard: however bad
-- the population, the scan must come back inside its budget.
do
    math.randomseed(8675309)
    local names = { "Dropbox", "1Password", "Zoom", "Slack", "VPN", "Docker",
                    "Backblaze", "CleanShot", "Fantastical", "Bartender" }
    local bad = nil
    local worstBurn, worstApps = 0, 0

    for iter = 1, 500 do
        APPS = {}
        local expected = 0
        for i = 1, math.random(0, 30) do
            local nm = names[math.random(#names)] .. i
            local roll = math.random(10)
            if roll <= 5 then                       -- healthy, 1-3 items
                local items = {}
                for _ = 1, math.random(1, 3) do
                    items[#items + 1] = { desc = (math.random(2) == 1) and "d" or nil,
                                          refuse = math.random(5) == 1,
                                          pos = { x = 10, y = 5 }, size = { w = 20, h = 22 } }
                end
                APPS[#APPS + 1] = mkApp(nm, items)
                expected = expected + #items
            elseif roll <= 7 then                   -- no menu bar item at all
                APPS[#APPS + 1] = mkApp(nm, nil)
            else                                    -- wedged for a while
                APPS[#APPS + 1] = mkApp(nm, nil, math.random() * 1.5)
            end
        end
        boot()
        local t0 = NOW
        local ok, items = pcall(MB.scan, true)
        local burned = NOW - t0
        worstBurn = math.max(worstBurn, burned)
        worstApps = math.max(worstApps, #APPS)

        -- P1: never throws, whatever the population.
        if not ok then bad = "scan threw: " .. tostring(items) break end
        -- P2: 🚨 THE BUDGET HOLDS. This is the keyboard.
        if burned > MB.scanBudget + 2.0 then
            bad = string.format("scan burned %.1fs of clock against a %.1fs "
                  .. "budget with %d apps", burned, MB.scanBudget, #APPS)
            break
        end
        -- P3: a partial result is still a well-formed result.
        for _, e in ipairs(items or {}) do
            if type(e.app) ~= "string" or e.el == nil then
                bad = "malformed entry in the result" break
            end
        end
        if bad then break end
        -- P4: if nothing hung, every item is found — the budget must not
        --     silently cost results on a healthy Mac.
        local anyHang = false
        for _, a in ipairs(APPS) do if a._hangs then anyHang = true end end
        if not anyHang and #(items or {}) ~= expected then
            bad = "healthy Mac lost items: got " .. #(items or {})
               .. " expected " .. expected
            break
        end
        -- P5: activating anything, however broken, never throws.
        for _, e in ipairs(items or {}) do
            local okA = pcall(MB.activate, e)
            if not okA then bad = "activate threw on " .. e.app break end
        end
        if bad then break end
    end
    check(string.format("500 random Mac populations (up to %d apps, worst scan "
          .. "%.1fs): never threw, never blew the budget, never lost an item "
          .. "on a healthy Mac, activation never threw", worstApps, worstBurn),
          bad == nil, bad)
end

out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
