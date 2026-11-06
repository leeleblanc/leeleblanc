-- =====================================================================
-- test_self_test.lua — do the big tools ANSWER?
-- =====================================================================
--     lua5.4 test_self_test.lua [/path/to/hammerspoon]
--
-- LL, 2026-11-06: "After Hammerspoon runs the first time, can it do a
-- set of checks for most important functions? Screenshot tool, snippets
-- tool, autocorrect, draft keeper, right-click."
--
-- 🚨 THE SECTIONS WITH TEETH:
--   §2  A CHECK THAT RAISES MUST BE ❔, NEVER A PASS. An instrument that
--       can raise is worse than one that lies (6.282.0), and in THIS
--       module printing the reassuring answer for a question that could
--       not be asked would be the worst version of 6.196.1 in the
--       config — it is the block he will read instead of testing.
--   §3  A TAP THAT EXISTS IS NOT A TAP THAT IS RUNNING. macOS switches
--       taps off across some transitions and tells nobody (6.303.0), so
--       "the object is there" is the reassuring half and isEnabled() is
--       the half that matters.
--   §5  THE SUMMARY MUST COUNT ⚠️ AND ❔ — a block that ends "every tool
--       answered" over a fault is the one outcome this must never have.
-- =====================================================================

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
local realPrint = print
local PRINTED = {}
print = function(s) PRINTED[#PRINTED + 1] = tostring(s) end

-- ---- the stub Mac ------------------------------------------------------
local AX        = true
local SECURE    = false
local TIMERS    = {}
local DIRMODE   = "directory"

local function mkTap(enabled)
    local t = { on = enabled }
    function t:isEnabled() return self.on end
    return t
end

hs = {
    accessibilityState = function() return AX end,
    eventtap = { isSecureInputEnabled = function() return SECURE end },
    fs = { attributes = function(_, what)
               if what == "mode" then return DIRMODE end
               return { mode = DIRMODE }
           end },
    timer = {
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
}

-- the live things the module reads, in a healthy shape
_G.hyperBoundCount, _G.hyperConflictCount = 111, 0
_G.screenshots   = { dir = "/Users/x/OneDrive/2026 Screenshots" }
_G.expanderTap   = mkTap(true)
_G.expander      = { snippets = { [";bd"] = 1, ["gg1"] = 2 } }
_G.autocorrectTap = mkTap(true)
_G.draftKeeper   = { enabled = true, timer = {}, everySecs = 5,
                     sampleSecs = 5, apps = { "chrome", "safari" } }
_G.rightClick    = { enabled = true, useSelection = true }

local PROVIDED = {}
local CORE = { provide = function(n, f) PROVIDED[n] = f end }

local chunk = assert(loadfile(HS .. "/modules/self_test.lua"))
local M = chunk()
M.setup(CORE)
local st = _G.selfTestState

local function byName(rows, name)
    for _, r in ipairs(rows) do if r.name == name then return r end end
end
local function stateOf(name) return (byName(st.rows(), name) or {}).state end
local function detailOf(name) return (byName(st.rows(), name) or {}).detail or "" end

-- =====================================================================
out("\n=== 1. a healthy Mac answers on every row ===\n")
-- =====================================================================
do
    local rows = st.rows()
    check("every tool he named has a row", (function()
        for _, n in ipairs({ "Screenshots", "Snippets", "Autocorrect",
                             "Draft keeper", "Right-click" }) do
            if not byName(rows, n) then return false, n end
        end
        return true
    end)())
    check("...and so do the three that make every one of them dead",
          byName(rows, "Accessibility") and byName(rows, "Secure Input")
          and byName(rows, "⇪ shortcuts"))
    check("a healthy Mac is ✅ all the way down", (function()
        for _, r in ipairs(rows) do
            if r.state ~= "✅" then return false, r.name .. "=" .. r.state end
        end
        return true
    end)(), (function()
        for _, r in ipairs(rows) do
            if r.state ~= "✅" then return r.name .. " = " .. r.state .. " " .. r.detail end
        end
    end)())
    local block = st.render(rows)
    check("...and the block says so in one line",
          block:find("every tool answered", 1, true) ~= nil, block)
    check("...and points at the OTHER question rather than answering it",
          block:find("installCheck", 1, true) ~= nil)
end

-- =====================================================================
out("\n=== 2. 🚨 A CHECK THAT CANNOT BE ASKED IS NEVER A PASS ===\n")
-- =====================================================================
do
    local r = st.ask("Boom", function() error("the tool exploded") end)
    check("a check that RAISES is ❔, not ✅ — this is the module where "
          .. "printing the reassuring answer would be worst",
          r.state == "❔", r.state)
    check("...and it says the CHECK failed, not that the tool did",
          r.detail:find("the check itself failed", 1, true) ~= nil, r.detail)
    r = st.ask("Odd", function() return "fine" end)
    check("a check that answers something that is not a state is ❔ too",
          r.state == "❔", r.state)
    r = st.ask("Good", function() return "✅", "all well" end)
    check("...and an honest answer comes through untouched",
          r.state == "✅" and r.detail == "all well")

    -- the whole block must survive one exploding row
    local saved = _G.screenshots
    _G.screenshots = setmetatable({}, { __index = function() error("boom") end })
    local ok = pcall(st.rows)
    _G.screenshots = saved
    check("🚨 one exploding row does not take the whole block down", ok)
end

-- =====================================================================
out("\n=== 3. 🚨 EXISTS IS NOT RUNNING ===\n")
-- =====================================================================
do
    local s = st.tapState(nil)
    check("no tap at all is ⚠️", s == "⚠️", s)
    s = st.tapState(mkTap(true))
    check("a running tap is ✅", s == "✅", s)
    -- 🚨 THE FIXTURE THAT BITES: the object is there and macOS has
    -- switched it off. A check that asked only "is the tap table there"
    -- passes every other input here and fails this one (6.230.0).
    local s2, d2 = st.tapState(mkTap(false))
    check("🚨 a tap that EXISTS and is NOT RUNNING is ⚠️ — the object being "
          .. "there is the reassuring half",
          s2 == "⚠️" and d2:find("NOT running", 1, true) ~= nil, s2 .. " " .. d2)
    local s3 = st.tapState(setmetatable({}, { __index = function()
        return function() error("no") end end }))
    check("a tap that will not say is ❔, never ✅", s3 == "❔", s3)

    _G.autocorrectTap = mkTap(false)
    check("...and autocorrect reads it through the same door",
          stateOf("Autocorrect") == "⚠️", stateOf("Autocorrect"))
    _G.autocorrectTap = mkTap(true)
end

-- =====================================================================
out("\n=== 4. each row reads the LIVE thing ===\n")
-- =====================================================================
do
    AX = false
    check("Accessibility off is ⚠️, and it says to QUIT and relaunch — a "
          .. "grant is read at launch and nothing else explains that",
          stateOf("Accessibility") == "⚠️"
          and detailOf("Accessibility"):find("relaunch", 1, true) ~= nil)
    check("...and right-click says it is bound but cannot click",
          stateOf("Right-click") == "⚠️", stateOf("Right-click"))
    AX = true

    SECURE = true
    check("Secure Input held is ⚠️ and names the report that finds it",
          stateOf("Secure Input") == "⚠️"
          and detailOf("Secure Input"):find("secureInputReport", 1, true) ~= nil)
    SECURE = false

    _G.hyperConflictCount = 2
    check("a key claimed twice is a fault, not a count",
          stateOf("⇪ shortcuts") == "⚠️", stateOf("⇪ shortcuts"))
    _G.hyperConflictCount = 0
    _G.hyperBoundCount = 0
    check("nothing bound at all is a fault", stateOf("⇪ shortcuts") == "⚠️")
    _G.hyperBoundCount = 111

    DIRMODE = nil
    check("🚨 a screenshots folder that is NOT THERE is ⚠️ — ⇪4 has nowhere "
          .. "to write, and that folder is in OneDrive",
          stateOf("Screenshots") == "⚠️", stateOf("Screenshots"))
    DIRMODE = "directory"

    _G.expander = { snippets = {} }
    check("no snippets loaded is ⚠️ and names the way to load them",
          stateOf("Snippets") == "⚠️"
          and detailOf("Snippets"):find("snippetsImport", 1, true) ~= nil)
    _G.expander = { snippets = { a = 1, b = 2 } }
    check("...and a healthy one names HOW MANY, read off the table",
          detailOf("Snippets"):find("2 loaded", 1, true) ~= nil,
          detailOf("Snippets"))

    -- ⏳ IS NOT ⚠️: switched off on purpose is not a fault (6.196.1)
    _G.draftKeeper.enabled = false
    check("⏳ a tool switched off ON PURPOSE is ⏳, never ⚠️",
          stateOf("Draft keeper") == "⏳", stateOf("Draft keeper"))
    _G.draftKeeper.enabled = true
    _G.draftKeeper.timer = nil
    check("🚨 …but ON with no timer armed IS a fault — that is the state "
          .. "where it is silently doing nothing",
          stateOf("Draft keeper") == "⚠️", stateOf("Draft keeper"))
    _G.draftKeeper.timer = {}
    check("...and a healthy one names _G.draftCheck(), which is what he "
          .. "asked for by name",
          detailOf("Draft keeper"):find("draftCheck", 1, true) ~= nil,
          detailOf("Draft keeper"))

    local saved = _G.draftKeeper
    _G.draftKeeper = nil
    check("a module that did not load at all is ❔ — 'it is not there' and "
          .. "'it is fine' are opposite facts",
          stateOf("Draft keeper") == "❔", stateOf("Draft keeper"))
    _G.draftKeeper = saved
end

-- =====================================================================
out("\n=== 5. 🚨 THE SUMMARY CANNOT SAY 'ALL WELL' OVER A FAULT ===\n")
-- =====================================================================
do
    local block, bad = st.render({
        { name = "A", state = "✅", detail = "" },
        { name = "B", state = "⚠️", detail = "" },
    })
    check("one ⚠️ and the summary is a fault count, not 'every tool answered'",
          bad == 1 and block:find("every tool answered", 1, true) == nil
          and block:find("1 fault", 1, true) ~= nil, block)
    local b2, bad2, unk2 = st.render({
        { name = "A", state = "✅", detail = "" },
        { name = "B", state = "❔", detail = "" },
    })
    check("🚨 …and a row that could not be ASKED also stops it, counted "
          .. "apart from a fault",
          bad2 == 0 and unk2 == 1
          and b2:find("every tool answered", 1, true) == nil
          and b2:find("could not be asked", 1, true) ~= nil, b2)
    local b3, bad3 = st.render({
        { name = "A", state = "✅", detail = "" },
        { name = "B", state = "⏳", detail = "" },
    })
    check("...and ⏳ alone is still a clean bill, with the number said",
          bad3 == 0 and b3:find("every tool answered", 1, true) ~= nil
          and b3:find("switched off on purpose", 1, true) ~= nil, b3)
end

-- =====================================================================
out("\n=== 6. the door, and warm ===\n")
-- =====================================================================
do
    PRINTED = {}
    local s = _G.selfTest()
    check("_G.selfTest() prints the block and hands it back",
          type(s) == "string" and #PRINTED == 1 and PRINTED[1] == s)
    check("...and it is counted, so 'has it ever run' has an answer",
          st.runs >= 1 and st.lastAt ~= nil)
    check("the rows are published as a service for anything else that asks",
          type(PROVIDED["selfTest.rows"]) == "function"
          and #PROVIDED["selfTest.rows"]() > 0)

    -- 🕰 FROM warm, NEVER setup (6.267.0): every tool it asks about is
    -- started in ITS warm, so a check during setup reports half of them
    -- as not running and is a liar on a healthy Mac.
    TIMERS, PRINTED = {}, {}
    M.warm()
    check("🕰 warm does not run it immediately — it arms a held timer",
          #TIMERS == 1 and #PRINTED == 0, #TIMERS .. "/" .. #PRINTED)
    check("...and it is held in its own slot, not dropped on the floor",
          st.bootTimer ~= nil)
    check("...and it waits longer than install_check, so the two blocks "
          .. "do not arrive on top of each other",
          TIMERS[1].secs > 6, TIMERS[1].secs)
    TIMERS[1].fn()
    check("...and when it fires, the block is printed", #PRINTED == 1)

    -- 🛟 a Mac that cannot arm a timer still gets the block
    local realDoAfter = hs.timer.doAfter
    hs.timer.doAfter = function() error("no timers on this Mac") end
    TIMERS, PRINTED = {}, {}
    st.noBelt = 0
    M.warm()
    hs.timer.doAfter = realDoAfter
    check("🛟 a Mac that cannot arm a timer is printed EARLY rather than "
          .. "never — saying nothing is not one of the options in the "
          .. "module whose subject is being told",
          #PRINTED == 1 and st.noBelt == 1, #PRINTED .. "/" .. st.noBelt)

    -- 🔌 and the switch is real
    TIMERS, PRINTED = {}, {}
    st.sayBoot = false
    M.warm()
    check("🔌 sayBoot = false arms nothing and prints nothing",
          #TIMERS == 0 and #PRINTED == 0)
    st.sayBoot = true
end

-- ---- results -----------------------------------------------------------
print = realPrint
io.write(("\n   %s test_self_test — %d passed, %d failed\n")
         :format(fail == 0 and "✅" or "❌", pass, fail))
for _, l in ipairs(failures) do io.write("      ✗ " .. l .. "\n") end
os.exit(fail == 0 and 0 or 1)
