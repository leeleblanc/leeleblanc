-- =====================================================================
-- test_settings_panes.lua — ⇪, opens the right System Settings page
-- =====================================================================
--     lua5.4 test_settings_panes.lua [/path/to/hammerspoon]
--
-- Executes modules/settings_panes.lua against a stubbed hs.
--
-- TWO SECTIONS HAVE TEETH:
--
--   §2 THE TWO URL SHAPES. Ventura renamed nearly every pane identifier,
--      and the LEGACY anchors (com.apple.preference.security?Privacy_X)
--      are both still working and more stable across releases than the
--      new names — so the table holds both. A value that already carries
--      a SCHEME is used as written; everything else is an identifier and
--      gets the x-apple.systempreferences: prefix.
--
--      ⚠️ THE LEGACY ANCHORS FALL ON THE IDENTIFIER SIDE. Their "?" is a
--      query, not a scheme — there is no colon in them — so they need
--      the prefix like everything else. Reading the "?" as a marker for
--      "already a URL" leaves the five Privacy rows unprefixed and dead,
--      and macOS does not refuse a URL it cannot route: Settings opens
--      at some page, `open` exits 0, and nothing says the trip failed.
--
--   §4 hs.fs.dir NEEDS BOTH RETURN VALUES. Capturing one and writing
--      `for e in iter do` throws "directory metatable expected, got nil"
--      at RUNTIME, never at load — so the scan is silently dead and
--      nothing says so. hs-lint caught this before it shipped; the stub
--      below REFUSES to iterate without its directory object, so it
--      cannot come back.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label
             .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end

print = function() end

-- ---- the stub Mac ------------------------------------------------------
local OPENED_URLS = {}    -- hs.urlevent.openURL
local EXECUTED    = {}    -- hs.execute
local ALERTS      = {}
local CHOOSERS    = {}
local SHOWS       = 0
local TIMERS      = {}
local URLEVENT_OK = true

-- What each scanned directory contains.
local DIRS = {
    ["/System/Library/PreferencePanes"] = { "Profiles.prefPane", "Displays.prefPane" },
    ["/Library/PreferencePanes"]        = { "Flash Player.prefPane", "notes.txt" },
    ["/Users/test/Library/PreferencePanes"] = {},
}

hs = {
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    execute = function(cmd) EXECUTED[#EXECUTED + 1] = cmd ; return "" end,
    urlevent = {
        openURL = function(u)
            if not URLEVENT_OK then error("no url handler") end
            OPENED_URLS[#OPENED_URLS + 1] = u
        end,
    },
    timer = {
        secondsSinceEpoch = function() return 1000 end,
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn }
            function t:stop() end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    fs = {
        attributes = function(p, what)
            if DIRS[p] then
                if what == "mode" then return "directory" end
                return { mode = "directory" }
            end
            return nil
        end,
        -- 🚨 THE ITERATOR REFUSES TO WORK WITHOUT ITS DIRECTORY OBJECT,
        -- exactly as the real one does. A module that captures only the
        -- first return value gets the error here rather than a silently
        -- empty scan on a Mac.
        dir = function(path)
            local entries = DIRS[path]
            if not entries then error("no such directory: " .. tostring(path)) end
            local dirObj = { path = path, i = 0 }
            local function iter(d)
                if d ~= dirObj then
                    error("directory metatable expected, got " .. type(d))
                end
                d.i = d.i + 1
                return entries[d.i]
            end
            return iter, dirObj
        end,
    },
    chooser = {
        new = function(cb)
            local c = { cb = cb, choices_ = {}, placeholder = "", query_ = nil }
            function c:choices(x) self.choices_ = x ; return self end
            function c:placeholderText(x) self.placeholder = x ; return self end
            function c:query(x) self.query_ = x ; return self end
            function c:show() SHOWS = SHOWS + 1 ; return self end
            function c:width(n) return self end
            function c:searchSubText(b) return self end
            CHOOSERS[#CHOOSERS + 1] = c
            return c
        end,
    },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }

local BOUND, PROVIDED = {}, {}
local CORE = {
    homeDir = "/Users/test",
    hyperAddShortcut = function(mods, key, fn, src)
        BOUND[(mods and mods[1] or "") .. "+" .. key] = { fn = fn, src = src }
    end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local chunk = assert(loadfile(HS .. "/modules/settings_panes.lua"))
local M = chunk()
M.setup(CORE)
local sp = _G.settingsPanes

local function reset()
    OPENED_URLS, EXECUTED, ALERTS = {}, {}, {}
    sp.lastNote = nil
end

local function paneNamed(rows, name)
    for _, r in ipairs(rows) do if r.name == name then return r end end
    return nil
end

-- =====================================================================
out("\n=== 1. it loads and binds ===\n")
-- =====================================================================
check("the module returns a table with a name", M.name == "Settings Panes")
check("it declares a family", M.family == "config")
check("⇪, is bound", BOUND["+,"] ~= nil)
check("the binding is attributed to this module",
      BOUND["+,"] and BOUND["+,"].src == "settings panes")
check("it publishes _G.settingsPanes", type(sp) == "table")
check("three services are published", PROVIDED["settings.show"]
      and PROVIDED["settings.open"] and PROVIDED["settings.report"])
check("the cheat sheet key cell is exactly ⇪,", (function()
    for _, e in ipairs(M.cheatsheet.entries) do
        if e[1] == "⇪," then return true end
    end
    return false
end)())

-- =====================================================================
out("\n=== 2. 🚨 THE TWO URL SHAPES ===\n")
-- =====================================================================
check("a bare identifier gets the scheme prefix",
      sp.urlFor("com.apple.Sound-Settings.extension")
      == "x-apple.systempreferences:com.apple.Sound-Settings.extension",
      sp.urlFor("com.apple.Sound-Settings.extension"))
-- 🚨 A LEGACY ANCHOR IS AN IDENTIFIER WITH A QUERY, NOT A URL. There is
-- no colon in "com.apple.preference.security?Privacy_Accessibility", so
-- it takes the prefix like every other identifier — and the finished URL
-- is the form that actually works. Reading the "?" as a scheme marker
-- would leave these five unprefixed and dead, and macOS does not refuse
-- a URL it cannot route: Settings opens somewhere, `open` exits 0, and
-- nothing anywhere says the trip went to the wrong page.
check("🚨 a legacy ?Privacy_ anchor is prefixed, not mistaken for a URL",
      sp.urlFor("com.apple.preference.security?Privacy_Accessibility")
      == "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
      sp.urlFor("com.apple.preference.security?Privacy_Accessibility"))
check("a value that ALREADY carries a scheme is left exactly as written",
      sp.urlFor("https://example.com") == "https://example.com")
check("…including one already in the settings scheme, so it is never doubled",
      sp.urlFor("x-apple.systempreferences:com.apple.foo")
      == "x-apple.systempreferences:com.apple.foo",
      sp.urlFor("x-apple.systempreferences:com.apple.foo"))
check("an empty value is nil, not a bare scheme", sp.urlFor("") == nil)
check("nil is nil", sp.urlFor(nil) == nil)

-- =====================================================================
out("\n=== 3. every destination this config's alerts name is present ===\n")
-- =====================================================================
-- This config tells you to visit these in nine different alerts. If a
-- row goes missing, ⇪, stops being the shortcut for the trip the alerts
-- describe — which is the entire reason the module exists.
local rows = sp.build()
for _, needed in ipairs({
    "Accessibility (privacy)", "Screen Recording", "Automation",
    "Input Monitoring", "Full Disk Access",
}) do
    check("the table carries: " .. needed, paneNamed(rows, needed) ~= nil)
end
check("…and each of them uses the LEGACY anchor, which is the stable one",
      (function()
    for _, n in ipairs({ "Accessibility (privacy)", "Screen Recording",
                         "Automation", "Input Monitoring", "Full Disk Access" }) do
        local r = paneNamed(rows, n)
        if not (r and r.url:find("com.apple.preference.security?Privacy_", 1, true)) then
            return false
        end
    end
    return true
end)())
check("…each one carrying the scheme, so macOS can actually route it",
      (function()
    for _, n in ipairs({ "Accessibility (privacy)", "Screen Recording",
                         "Automation", "Input Monitoring", "Full Disk Access" }) do
        local r = paneNamed(rows, n)
        if not (r and r.url:find("x-apple.systempreferences:", 1, true) == 1) then
            return false
        end
    end
    return true
end)())
check("the everyday panes are there too", paneNamed(rows, "Wi-Fi")
      and paneNamed(rows, "Displays") and paneNamed(rows, "Keyboard")
      and paneNamed(rows, "Sound"))
check("every curated row has a group", (function()
    for _, r in ipairs(rows) do
        if r.from == "table" and (not r.group or r.group == "") then return false end
    end
    return true
end)())
check("every curated row produces a usable URL", (function()
    for _, r in ipairs(rows) do
        if r.from == "table" and (type(r.url) ~= "string" or r.url == "") then
            return false
        end
    end
    return true
end)())
check("no two curated rows share a name", (function()
    local seen = {}
    for _, r in ipairs(rows) do
        if r.from == "table" then
            if seen[r.name] then return false end
            seen[r.name] = true
        end
    end
    return true
end)())

-- =====================================================================
out("\n=== 4. 🚨 THE .prefPane SCAN, WITH BOTH RETURN VALUES ===\n")
-- =====================================================================
-- The stub's iterator throws unless it is handed its directory object,
-- so a module that dropped it would fail here rather than scanning
-- nothing and calling that success.
local scanned = sp.scan()
check("🚨 the scan iterated at all — the directory object survived",
      #scanned > 0, #scanned)
check("…finding the .prefPane bundles", (function()
    local names = {}
    for _, r in ipairs(scanned) do names[r.name] = true end
    return names["Profiles"] and names["Flash Player"]
end)())
check("…and nothing that is not one", (function()
    for _, r in ipairs(scanned) do
        if r.name == "notes" or r.name == "notes.txt" then return false end
    end
    return true
end)())
-- Guarded: a build that dropped the directory object scans NOTHING, and
-- dereferencing scanned[1] would take the file down before it could
-- report the failure above.
check("a scanned pane records where it came from",
      scanned[1] ~= nil and scanned[1].from == "disk")
check("…and carries a real path, not a URL",
      scanned[1] ~= nil and scanned[1].url:find("^/") ~= nil,
      scanned[1] and scanned[1].url)

-- 🚨 ADDITIVE ONLY. /System/Library/PreferencePanes has Displays.prefPane
-- on it, and the curated table already has a Displays row with the modern
-- URL. The scan must not replace it with the .prefPane bundle.
check("🚨 a scanned pane never displaces a curated row of the same name",
      (function()
    for _, r in ipairs(scanned) do
        if r.name == "Displays" then return false end
    end
    return true
end)())
local disp = paneNamed(sp.build(), "Displays")
check("…so Displays still opens through its modern URL",
      disp and disp.from == "table"
      and disp.url:find("x-apple.systempreferences:", 1, true) == 1, disp and disp.url)

-- =====================================================================
out("\n=== 5. opening: a URL and a bundle are not the same thing ===\n")
-- =====================================================================
reset()
local wifi = paneNamed(sp.build(), "Wi-Fi")
check("a curated pane opens through hs.urlevent",
      sp.open(wifi) == true and #OPENED_URLS == 1, #OPENED_URLS)
check("…with the prefixed URL", OPENED_URLS[1]
      and OPENED_URLS[1]:find("x-apple.systempreferences:", 1, true) == 1,
      OPENED_URLS[1])
check("…and nothing was shelled out", #EXECUTED == 0, #EXECUTED)

reset()
local prof = nil
for _, r in ipairs(sp.build()) do if r.from == "disk" then prof = r break end end
check("a .prefPane on DISK is a file, so it goes through `open`",
      prof and sp.open(prof) == true and #EXECUTED == 1, #EXECUTED)
check("…and not through the URL handler", #OPENED_URLS == 0, #OPENED_URLS)
check("…with the path quoted, because paths have spaces in them",
      EXECUTED[1] and EXECUTED[1]:find('"') ~= nil, EXECUTED[1])

-- A Mac with no URL handler must still open the pane.
reset()
URLEVENT_OK = false
check("if hs.urlevent throws, it falls back to `open`",
      sp.open(wifi) == true and #EXECUTED == 1, #EXECUTED)
URLEVENT_OK = true

reset()
check("opening nothing is false, not a throw", sp.open(nil) == false)

-- The service opens by name, case-insensitively.
reset()
check("the settings.open service finds a pane by name",
      PROVIDED["settings.open"]("wi-fi") == true, #OPENED_URLS)
check("…and returns false for a name that is not there",
      PROVIDED["settings.open"]("Nonexistent Pane") == false)

-- =====================================================================
out("\n=== 6. 🚨 A ROW CARRIES A NUMBER, NOT A TABLE ===\n")
-- =====================================================================
reset()
sp.show()
local c = CHOOSERS[#CHOOSERS]
check("the panel opened with every pane", #c.choices_ == #sp.rows, #c.choices_)
check("every row value is a string, number or boolean", (function()
    for _, ch in ipairs(c.choices_) do
        for k, v in pairs(ch) do
            local t = type(v)
            if t ~= "string" and t ~= "number" and t ~= "boolean" then
                return false, k .. " is a " .. t
            end
        end
    end
    return true
end)())
check("…and every payload resolves to a real pane", (function()
    for _, ch in ipairs(c.choices_) do
        if sp.rows[ch.idx] == nil then return false end
    end
    return true
end)())
check("the group rides in the subtitle, so ‘privacy’ filters", (function()
    for _, ch in ipairs(c.choices_) do
        if ch.text == "Screen Recording" then
            return ch.subText:find("Privacy", 1, true) ~= nil
        end
    end
    return false
end)())
check("⏎ opens the pane that row names", (function()
    OPENED_URLS = {}
    local idx
    for _, ch in ipairs(c.choices_) do
        if ch.text == "Screen Recording" then idx = ch.idx end
    end
    c.cb({ idx = idx })
    return OPENED_URLS[1] ==
        "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
end)(), OPENED_URLS[1])

-- =====================================================================
out("\n=== 7. the probe and the report are honest about the limit ===\n")
-- =====================================================================
reset()
_G.settingsProbe("Network")
check("the probe opened the first pane immediately", #OPENED_URLS == 1, #OPENED_URLS)
check("…and scheduled the next rather than firing them all at once",
      #TIMERS >= 1, #TIMERS)
TIMERS[#TIMERS].fn()
check("…the next one follows on the timer", #OPENED_URLS == 2, #OPENED_URLS)

local rep = _G.settingsReport()
check("the report names the module", rep:find("SETTINGS PANES", 1, true) ~= nil)
check("…counts the curated table", rep:find("curated", 1, true) ~= nil)
check("…counts what was found on disk", rep:find(".prefPane", 1, true) ~= nil)
-- 🚨 The honesty line. macOS opens Settings at SOME page for an anchor it
-- no longer knows and still exits 0, so this module cannot verify a
-- destination — and the report has to say so rather than implying it did.
check("🚨 …and states plainly that a retired identifier fails silently",
      rep:find("still exits 0", 1, true) ~= nil, rep)
check("…and points at the probe as the only real test",
      rep:find("settingsProbe", 1, true) ~= nil, rep)

-- =====================================================================
out(("\n── test_settings_panes: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
