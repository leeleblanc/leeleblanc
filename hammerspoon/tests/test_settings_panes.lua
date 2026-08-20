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
local LAUNCHED    = {}    -- bundle IDs handed to launchOrFocusByBundleID
local TYPED       = {}    -- what reached hs.eventtap.keyStrokes
local APP_RUNNING = true  -- is System Settings up yet
local AX_APP      = nil   -- the stub accessibility tree, built in §8

-- 🚨 THE INJECTION GUARD IS PART OF THE CONTRACT, NOT DECORATION. This
-- module types into another application, and autocorrect, the expander
-- and the Key Caster all read _G.typingInjection() to decide whether a
-- keystroke was yours. Typing outside the guard would make this config's
-- own search query look like something you wrote.
local INJECTED = 0
_G.withInjection = function(fn) INJECTED = INJECTED + 1 ; return pcall(fn) end

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
        -- 🚨 A STOPPED TIMER STAYS STOPPED, exactly as the real one does.
        -- Without this the poll below would keep firing after it found the
        -- field and the "types once" check would pass for the wrong reason.
        doEvery = function(secs, fn)
            local t = { secs = secs, fn = fn, every = true, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    application = {
        launchOrFocusByBundleID = function(b) LAUNCHED[#LAUNCHED + 1] = b ; return true end,
        get = function(b) return APP_RUNNING and { bundle = b } or nil end,
    },
    axuielement = {
        applicationElement = function() return AX_APP end,
    },
    eventtap = {
        keyStrokes = function(t) TYPED[#TYPED + 1] = tostring(t) end,
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
            function c:searchSubText(b) self.subText_ = b ; return self end
            function c:queryChangedCallback(fn) self.onQuery = fn ; return self end
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
check("the report names the module", rep:find("SETTINGS SEARCH", 1, true) ~= nil)
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
out("\n=== 8. 🚨 THE SETTINGS INSIDE THE PANES ===\n")
-- =====================================================================
-- 6.119.0 searched the ~58 destinations in the sidebar. Nobody thinks "I
-- need the Displays pane"; they think "where is Night Shift". These are
-- the checks that say the second question now has an answer.
local rows8 = sp.build()

-- 🚨 THE ONE THAT CANNOT BE ALLOWED TO SLIDE. A term naming a pane that
-- is not in the table is a row that looks perfect in the picker and does
-- nothing at all on ⏎.
check("🚨 every named setting points at a pane that exists",
      #sp.orphans == 0,
      #sp.orphans > 0 and table.concat(sp.orphans, ", ") or nil)
-- 🚨 AND EXISTING IS NOT ENOUGH — IT HAS TO GO SOMEWHERE. A row with no
-- URL is the same dead row as an orphan wearing a different hat: it lists
-- perfectly and does nothing on ⏎. Counting orphans alone missed this.
check("🚨 …and every row, pane or setting, has somewhere to go", (function()
    for _, r in ipairs(rows8) do
        if type(r.url) ~= "string" or r.url == "" then
            return false, r.name
        end
    end
    return true
end)())
check("there are enough of them to be worth the name",
      #sp.terms >= 150, #sp.terms)

local function termNamed(name)
    for _, r in ipairs(rows8) do
        if r.kind == "term" and r.name == name then return r end
    end
end
-- ⚠️ GUARDED, because this section is where a broken table shows up and a
-- break test that CRASHES tells you nothing. Everything below reads
-- through `night`, so a missing one has to fail loudly and carry on.
local night = termNamed("Night Shift")
                or { name = "Night Shift", url = "", where = "", pane = "" }
check("Night Shift is one of them", termNamed("Night Shift") ~= nil)
check("…and it borrows the URL of the pane that holds it",
      night and night.url == "x-apple.systempreferences:com.apple.Displays-Settings.extension",
      night and night.url)
check("…and says where in that pane to look",
      night and night.where ~= "" and night.where:find("Night Shift", 1, true) ~= nil,
      night and night.where)
check("a term row names its pane in the subtitle, not just itself",
      (function()
          for i, r in ipairs(rows8) do
              if r.kind == "term" and r.name == "Night Shift" then
                  local c = sp.rowChoice(r, i)
                  return c.subText:find("Displays", 1, true) ~= nil
              end
          end
      end)())
-- Terms with no pane of their own must not have quietly become panes.
local paneCount = 0
for _, r in ipairs(rows8) do if r.kind == "pane" then paneCount = paneCount + 1 end end
check("panes and terms stay separable",
      paneCount == #sp.panes + sp.scanned, paneCount)

-- A term opens exactly as its pane does — same URL, same code path.
reset()
sp.open(night)
check("⏎ on a setting opens the pane that holds it",
      night.url ~= "" and OPENED_URLS[1] == night.url, OPENED_URLS[1])

out("\n=== 8b. the filter, and the row that is always last ===\n")
local f = sp.filter("night shift")
check("typing the setting's name finds it", f[1] and f[1].text == "Night Shift",
      f[1] and f[1].text)
check("🚨 the ask row is ALWAYS last, even on a hit",
      f[#f].idx == 0 and f[#f].ask == "night shift", f[#f].text)
check("…and it quotes back what you typed",
      f[#f].text:find("night shift", 1, true) ~= nil, f[#f].text)

local none = sp.filter("zzzznothingmatchesthis")
check("a query that matches nothing still offers Apple's search",
      #none == 1 and none[1].idx == 0, #none)
check("…and says why that row is the only one",
      none[1].subText:find("Apple", 1, true) ~= nil, none[1].subText)

-- Every word has to appear, and the pane name counts as part of the row —
-- which is what makes "night dis" work at all.
check("all words must match, not any of them",
      #sp.filter("night zzzz") == 1, #sp.filter("night zzzz"))
check("the pane name is searchable from the term's row",
      (function()
          for _, c in ipairs(sp.filter("night dis")) do
              if c.text == "Night Shift" then return true end
          end
      end)())
check("an empty query lists everything and adds no ask row",
      #sp.filter("") == #rows8, #sp.filter(""))
check("…and a whitespace-only query counts as empty",
      #sp.filter("   ") == #rows8, #sp.filter("   "))

-- 🚨 idx 0 is the ask row and no real row may collide with it: the
-- callback tells them apart by that number alone.
check("🚨 no real row carries idx 0", (function()
    for _, c in ipairs(sp.filter("s")) do
        if c.idx == 0 and not c.ask then return false end
    end
    return true
end)())

-- The chooser must do NO filtering of its own. Left on, searchSubText
-- would filter the list sp.filter already built — and the ask row, whose
-- subtitle says nothing about your query, would vanish from its own list.
sp.show()
local ch = CHOOSERS[#CHOOSERS]
check("🚨 the chooser's own sub-text search is switched OFF",
      ch.subText_ == false, tostring(ch.subText_))
check("the picker filters on every keystroke", type(ch.onQuery) == "function")
ch.onQuery("hot corners")
check("…and typing rebuilds the list",
      ch.choices_[1] and ch.choices_[1].text == "hot corners",
      ch.choices_[1] and ch.choices_[1].text)
check("…down to the match and the ask row, nothing else",
      #ch.choices_ == 2, #ch.choices_)
check("the placeholder counts both halves",
      ch.placeholder:find("panes", 1, true) ~= nil
      and ch.placeholder:find("settings", 1, true) ~= nil, ch.placeholder)

out("\n=== 8c. 🔎 handing the query to Apple's own search ===\n")
-- The stub accessibility tree: a window, a toolbar, and a search field
-- three levels down — deeper than a fixed path would reach, which is the
-- reason the module walks instead of indexing.
local FIELD = {
    role = "AXTextField", subrole = "AXSearchField",
    value = "leftover", focused = false, kids = {},
}
local function node(role, kids, subrole)
    return { role = role, subrole = subrole, kids = kids or {} }
end
local function axNode(n)
    local o = {}
    function o:setTimeout(t) n.timeout = t ; return self end
    function o:attributeValue(a)
        if a == "AXRole" then return n.role end
        if a == "AXSubrole" then return n.subrole end
        if a == "AXChildren" then
            local out = {}
            for _, k in ipairs(n.kids or {}) do out[#out + 1] = axNode(k) end
            return out
        end
        return nil
    end
    function o:setAttributeValue(a, v)
        if a == "AXFocused" then n.focused = v end
        if a == "AXValue" then n.value = v end
        return self
    end
    return o
end
local WINDOW = node("AXWindow", { node("AXGroup", { node("AXToolbar", { FIELD }) }) })
local TIMEOUTS = {}
AX_APP = {
    setTimeout = function(self, t) TIMEOUTS[#TIMEOUTS + 1] = t ; return self end,
    attributeValue = function(self, a)
        if a == "AXFocusedWindow" then return axNode(WINDOW) end
        return nil
    end,
}

reset()
TIMERS, LAUNCHED, TYPED, INJECTED = {}, {}, {}, 0
APP_RUNNING = true
check("askApple refuses an empty query", sp.askApple("  ") == false)
check("…and touched nothing", #LAUNCHED == 0 and #TIMERS == 0)

check("askApple opens System Settings", sp.askApple("night shift") == true)
check("…by bundle id", LAUNCHED[1] == "com.apple.systempreferences", LAUNCHED[1])
check("…and polls rather than sleeping a fixed time",
      TIMERS[#TIMERS] and TIMERS[#TIMERS].every == true)
check("nothing has been typed before the field is found", #TYPED == 0, #TYPED)

local poll = TIMERS[#TIMERS]
poll.fn()
check("🚨 the field is found by walking, not by a fixed path", #TYPED == 1, #TYPED)
check("…and what was typed is what was asked for",
      TYPED[1] == "night shift", TYPED[1])
check("…into a field that was focused first", FIELD.focused == true)
check("…with the stale query cleared out of it", FIELD.value == "", FIELD.value)
check("🚨 …inside the injection guard, so this config's typing is not yours",
      INJECTED == 1, INJECTED)
check("an AX timeout was set before anything was asked", #TIMEOUTS >= 1, #TIMEOUTS)
check("the poll stopped once it succeeded", poll.stopped == true)
check("the report counts the hand-off", _G.settingsReport():find("handed off", 1, true) ~= nil)

-- 🚨 THE FAILURE THAT MATTERS: no field, no blind typing. Keystrokes into
-- whatever happens to have focus is how a search query lands in a
-- document.
TIMERS, TYPED = {}, {}
APP_RUNNING = false
sp.askApple("hot corners")
local poll2 = TIMERS[#TIMERS]
local guard = 0
while not poll2.stopped and guard < 100 do poll2.fn() ; guard = guard + 1 end
check("🚨 a search field it never found is never typed into", #TYPED == 0, #TYPED)
check("…and it gives up rather than polling forever", poll2.stopped == true)
check("…and says so, with the query, so the trip is not wasted",
      (function()
          for _, a in ipairs(ALERTS) do
              if a:find("hot corners", 1, true) then return true end
          end
      end)(), table.concat(ALERTS, " | "))
check("…and records it as a problem rather than a success",
      sp.lastNote ~= nil and sp.lastNote:find("search field", 1, true) ~= nil,
      sp.lastNote)
APP_RUNNING = true

-- The fallback: a plain text field is taken only when no search field is
-- there, because a pane with a text box open would otherwise win.
local PLAIN = { role = "AXTextField", kids = {} }
local W2 = node("AXWindow", { node("AXGroup", { PLAIN }) })
local found = sp.findSearchField(axNode(W2))
check("a plain text field is the fallback when there is no search field",
      found ~= nil)
local W3 = node("AXWindow", { node("AXGroup", { PLAIN, FIELD }) })
local found3 = sp.findSearchField(axNode(W3))
check("🚨 …but the search field wins when both are present",
      found3 and found3:attributeValue("AXSubrole") == "AXSearchField",
      found3 and found3:attributeValue("AXSubrole"))
check("a tree with nothing in it returns nothing rather than throwing",
      sp.findSearchField(axNode(node("AXWindow"))) == nil)
-- 🚨 AN EMPTY STRING IS NOT A URL, AND `not ""` IS TRUE OF NOTHING IN
-- LUA. A row carrying "" used to walk straight past the guard, into
-- openURL("") and then into a concatenation of a name it did not have.
reset()
check("a row with an empty url is refused, not opened",
      sp.open({ name = "Nowhere", url = "" }) == false)
check("…and nothing was asked to open", #OPENED_URLS == 0, #OPENED_URLS)
check("…and it said why, without needing a name to do it",
      sp.open({ url = "" }) == false and sp.lastNote ~= nil
      and sp.lastNote:find("no destination", 1, true) ~= nil, sp.lastNote)
check("…and a nil root is answered, not thrown at",
      sp.findSearchField(nil) == nil)

-- =====================================================================
out(("\n── test_settings_panes: %d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
