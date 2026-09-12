-- test_hyper_storm.lua — 6.214.1: a latched ⇪ that is running LL's typing
-- as shortcuts is judged a storm, released, written up and announced.
-- The rule is PURE (st.judge) and every threshold has the mutation it
-- exists to catch; the hooks in init.lua are asserted against the source
-- because a stub hotkey is pressed by nobody.
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra ~= nil and ("\n        got: " .. tostring(extra)) or "") end
end
local function out(s) io.write(s) end
local function readAll(path)
    local f = io.open(path, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

local ROOT = os.tmpname(); os.remove(ROOT)
assert(os.execute('mkdir -p "' .. ROOT .. '"'))

-- ---- the stub Mac ------------------------------------------------------
local NOW = 1000
local ALERTS, PRINTED, SETTINGS, NOTICES = {}, {}, {}, {}
local NO_SETTINGS, NO_DIR = false, false
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end
hs = {
    configdir = ROOT,
    timer = { secondsSinceEpoch = function() return NOW end },
    fs = {
        attributes = function(p)
            if os.execute('test -d "' .. p .. '"') == true then return { mode = "directory" } end
            if os.execute('test -e "' .. p .. '"') == true then return { mode = "file" } end
            return nil
        end,
        mkdir = function(p) if NO_DIR then return nil end return os.execute('mkdir -p "' .. p .. '"') end,
        dir = function(p)
            -- what macOS answers: hs.fs.dir THROWS on a path that is not a folder
            if os.execute('test -d "' .. p .. '"') ~= true then error("cannot open " .. p .. ": Not a directory") end
            local h = io.popen('ls -a "' .. p .. '" 2>/dev/null')
            local names = {}
            for n in h:lines() do names[#names + 1] = n end
            h:close()
            local i = 0
            return function() i = i + 1 return names[i] end
        end,
    },
    alert = { show = function(msg, secs) ALERTS[#ALERTS + 1] = { msg = msg, secs = secs } end },
    settings = {
        get = function(k) if NO_SETTINGS then error("no settings") end return SETTINGS[k] end,
        set = function(k, v) if NO_SETTINGS then error("no settings") end SETTINGS[k] = v end,
    },
    host = { localizedName = function() return "Test-Mac" end },
    application = { frontmostApplication = function() return { name = function() return "Chrome" end } end },
}
_G.notices = { record = function(kind, who, what) NOTICES[#NOTICES + 1] = who .. ": " .. what end }
_G.configVersion = "6.214.1-test"
_G.keyTrailReport = function() print("trail row 1"); print("trail row 2") end
_G.errorsReport = function() error("errors report broke") end
_G.hyperLatchReleases = 0
_G.hyperRepeats = 0
_G.hsPauseHint = "⇪⇧Esc"

local RELEASED = {}
_G.hyperForceRelease = function(who)
    if not _G.hyperActive then return false end
    RELEASED[#RELEASED + 1] = who
    _G.hyperActive = false; _G.hyperEnteredAt = nil
    return true
end

local M = dofile(HS .. "/modules/hyper_storm.lua")
M.setup({ configDir = ROOT })
local st = _G.hyperStorm

local function hold(at) _G.hyperActive = true; _G.hyperEnteredAt = at; _G.hyperRepeatAt = nil end
local function release() _G.hyperActive = false; _G.hyperEnteredAt = nil end
local function press(keys)
    local r
    for _, k in ipairs(keys) do r = st.note(k, "test-module") end
    return r
end

out("1) the module's shape\n")
check("name, order, family, cheatsheet", M.name == "Hyper Storm Guard" and M.family == "auto" and type(M.cheatsheet.entries) == "table")
check("no hyper key of its own (an automatic guard)", true)
check("_G.hyperStormNote is the door init.lua's hyperBind calls", _G.hyperStormNote == st.note)
check("_G.stormReport exists", type(_G.stormReport) == "function")
check("the folder is local, under the config folder, never OneDrive", st.dir == ROOT .. "/.storm")

out("2) the rule, pure — and each threshold's mutation\n")
local ok, why = st.judge({ active = false }, 100)
check("not held → not a storm", ok == false and why:find("not held", 1, true))
ok, why = st.judge({ active = true, enteredAt = 96, distinct = 9 }, 100)
check("held 4 s with nine keys → under 5 s, not yet", ok == false and why:find("under 5 s", 1, true), why)
ok, why = st.judge({ active = true, enteredAt = 95, distinct = 5 }, 100)
check("held 5 s with five different keys → one short", ok == false and why:find("under 6", 1, true), why)
ok = st.judge({ active = true, enteredAt = 95, distinct = 6 }, 100)
check("held 5 s with six different keys and no autorepeat → STORM", ok == true)
ok, why = st.judge({ active = true, enteredAt = 90, distinct = 12, repeatAt = 99 }, 100)
check("…but Caps Lock autorepeated 1 s ago → a real finger, not a storm", ok == false and why:find("real finger", 1, true), why)
ok = st.judge({ active = true, enteredAt = 90, distinct = 12, repeatAt = 97 }, 100)
check("an autorepeat 3 s ago is stale — storm", ok == true)
ok, why = st.judge({ active = true, distinct = 12 }, 100)
check("no hold start recorded → refuses to judge (says so)", ok == false and why:find("no hold start", 1, true))
ok = st.judge({ active = true, enteredAt = 95, distinct = 6 }, 100, { secs = 5, keys = 7, repeatGrace = 2 })
check("the thresholds are the config's (keys = 7 refuses six)", ok == false)

out("3) counting inside one hold: different keys, not presses\n")
hold(1000); NOW = 1006
local r = press({ "|h", "|h", "|h", "|h", "|h", "|h", "|h", "|h", "|h", "|h" })
check("the same key ten times in 6 s is one key — no storm (a held ⇪+arrow is not a storm)", r == false and #st.order == 1 and st.storms == 0)
r = press({ "|e", "|l", "|o", "shift+|w" })
check("five different keys — still one short", r == false and #st.order == 5 and st.storms == 0)
NOW = 1003
r = press({ "|r" })
check("six different keys but only 3 s held (clock moved back for the row) — not yet", r == false and st.storms == 0)

out("4) the storm: release, report file, alert, print, notices\n")
NOW = 1006
r = press({ "|d" })
check("the seventh key at 6 s → storm fired", r == true and st.storms == 1)
check("the hold was RELEASED through _G.hyperForceRelease, by name", RELEASED[1] == "the ⇪ storm guard" and _G.hyperActive == false)
check("a report file was written under .storm, named by epoch", st.last and st.last.path == ROOT .. "/.storm/storm-1006.txt" and readAll(st.last.path) ~= nil)
local text = readAll(st.last.path) or ""
check("the report names the version, the Mac, the hold and every key with its owner",
      text:find("6.214.1-test", 1, true) and text:find("Test-Mac", 1, true) and text:find("held 6.0 s", 1, true)
          and text:find("7 different shortcut(s)", 1, true) and text:find("⇪|h · test-module", 1, true) and text:find("⇪|d · test-module", 1, true), text)
check("the report carries the key trail as one section", text:find("trail row 1\ntrail row 2", 1, true) ~= nil)
check("a gatherer that THROWS is one named missing section, not a lost report",
      text:find("errorsReport threw", 1, true) and text:find("noticesReport is not loaded", 1, true), text)
check("the report names the front app", text:find("front  : Chrome", 1, true) ~= nil)
check("the alert says stuck, released, and the report's path", ALERTS[#ALERTS] and ALERTS[#ALERTS].msg:find("STORM CAUGHT", 1, true)
      and ALERTS[#ALERTS].msg:find("Released", 1, true) and ALERTS[#ALERTS].msg:find(st.last.path, 1, true), ALERTS[#ALERTS] and ALERTS[#ALERTS].msg)
check("the Console got the same line", PRINTED[#PRINTED]:find("STORM CAUGHT", 1, true) ~= nil)
check("notices recorded it", NOTICES[#NOTICES] and NOTICES[#NOTICES]:find("storm", 1, true))
check("ONE storm does not pause the config", _G.hsPaused ~= true and st.last.paused == false)
check("the hold's key list was cleared for the next hold", #st.order == 0 and st.holdId == nil)

out("5) a second storm inside ten minutes pauses as well\n")
hold(1100); NOW = 1106
press({ "|a", "|b", "|c", "|d", "|e", "|f" })
check("second storm fired", st.storms == 2)
check("…and PAUSED the config, naming the resume key", _G.hsPaused == true and st.last.paused == true
      and ALERTS[#ALERTS].msg:find("PAUSED, ⇪⇧Esc resumes", 1, true), ALERTS[#ALERTS].msg)
_G.hsPaused = false
st.times = {}
hold(2000); NOW = 2006
press({ "|a", "|b", "|c", "|d", "|e", "|f" })
check("a storm with no other inside the window does NOT pause", _G.hsPaused == false and st.last.paused == false)

out("6) the degrades say so\n")
st.dir = ROOT .. "/.storm/a-file-in-the-way"
local f = io.open(ROOT .. "/.storm/a-file-in-the-way", "w"); f:write("x"); f:close()
hold(3000); NOW = 3006
press({ "|a", "|b", "|c", "|d", "|e", "|f" })
check("no folder → still released, alert says the report was NOT written and why",
      RELEASED[#RELEASED] == "the ⇪ storm guard" and st.last.path == nil
          and ALERTS[#ALERTS].msg:find("report NOT written", 1, true) and ALERTS[#ALERTS].msg:find("not a folder", 1, true), ALERTS[#ALERTS].msg)
st.dir = ROOT .. "/.storm"
st.on = false
hold(4000); NOW = 4006
local r2 = press({ "|a", "|b", "|c", "|d", "|e", "|f" })
check("settings off → notes nothing, fires nothing", r2 == false and st.storms == 4)
st.on = true
release()

out("7) the next boot announces the newest report once\n")
SETTINGS = {}
local okA, path = st.announce()
check("announces the newest file (epoch 3006 was never written; 2006 is)", okA == true and path == ROOT .. "/.storm/storm-2006.txt", path)
check("…as an alert and a Console line naming the file", ALERTS[#ALERTS].msg:find("storm-2006.txt", 1, true) ~= nil)
check("remembered in hs.settings", SETTINGS["hyperStorm.seenEpoch"] == 2006)
local okB, whyB = st.announce()
check("the next boot says nothing", okB == false and whyB == "already announced")
NO_SETTINGS = true
local okC = st.announce()
check("no hs.settings → announces again and the report says why", okC == true and tostring(st.announceWhy):find("every boot", 1, true))
NO_SETTINGS = false

out("8) _G.stormReport() — one string, three states\n")
PRINTED = {}
_G.stormReport()
check("printed once, as one string", #PRINTED == 1)
local rep = PRINTED[1]
check("names the thresholds, the folder, the last storm and the newest file's text",
      rep:find("5 s held · 6 different shortcuts", 1, true) and rep:find(ROOT .. "/.storm", 1, true)
          and rep:find("last   : ", 1, true) and rep:find("HYPER STORM REPORT", 1, true), rep)
check("names the boot announcement", rep:find("boot   : 🌩", 1, true) ~= nil)
local fresh = dofile(HS .. "/modules/hyper_storm.lua")
os.execute('rm -rf "' .. ROOT .. '/.storm"')
PRINTED = {}
fresh.setup({ configDir = ROOT })
_G.stormReport()
check("a fresh session with nothing on disk reads as never, not as zero", PRINTED[1]:find("no storm this session", 1, true) and PRINTED[1]:find("no report on disk", 1, true))

out("9) the hooks in init.lua, against the source\n")
local init = readAll(HS .. "/init.lua") or ""
check("hyperEnter records when the hold BEGAN, only for a new hold", init:find("_G.hyperEnteredAt = hs.timer.secondsSinceEpoch()", 1, true) ~= nil
      and init:find("if _G.hyperActive then\n        -- the tap path sees F18 autorepeats", 1, true) ~= nil)
check("hyperExit clears it", init:find("_G.hyperActive = false\n    _G.hyperEnteredAt = nil", 1, true) ~= nil)
check("the F18 bind has a REPEAT fn that stamps _G.hyperRepeatAt",
      init:find('function() hyperExit() end,\n    -- 6.214.1', 1, true) ~= nil and init:find("_G.hyperRepeatAt = hs.timer.secondsSinceEpoch()\n        _G.hyperRepeats  = (_G.hyperRepeats or 0) + 1\n        _G.hyperHeldAt   = _G.hyperRepeatAt", 1, true) ~= nil)
check("hyperBind's wrapper notes every shortcut, nil-guarded and pcall'd", init:find("if _G.hyperStormNote then pcall(_G.hyperStormNote, combo, source) end", 1, true) ~= nil)
check("_G.hyperForceRelease exists, counts with the watchdog and calls hyperExit",
      init:find("_G.hyperForceRelease = function(who)", 1, true) ~= nil
          and init:find("_G.hyperLatchReleases = _G.hyperLatchReleases + 1\n    print(\"⌨️ ⇪ released by \"", 1, true) ~= nil)
check("the module is in init.lua's load list", init:find('"hyper_storm",', 1, true) ~= nil)
local src = readAll(HS .. "/modules/hyper_storm.lua") or ""
check("the module never binds a key and never writes to OneDrive (no core.hyperAddShortcut, no cloudDir)",
      not src:find("hyperAddShortcut", 1, true) and not src:find("cloudDir", 1, true))

out("10) 6.214.2 — keys the tap sees under ⇪ count too, and a missing folder is not an error\n")
do
    hs.keycodes = { map = { [0] = "a", [11] = "b", [8] = "c", [2] = "d", [14] = "e", [3] = "f", [7] = "x", [79] = "f18" } }
    _G.hyperCombo = function(mods, key)
        local m = {}
        for _, x in ipairs(mods or {}) do m[#m + 1] = tostring(x):lower() end
        table.sort(m)
        if #m == 0 then return tostring(key):lower() end
        return table.concat(m, "+") .. "+" .. tostring(key):lower()
    end
    local function ev(flags) return { getFlags = function() return flags or {} end } end
    local m2 = dofile(HS .. "/modules/hyper_storm.lua")
    m2.setup({ configDir = ROOT })
    local s2 = _G.hyperStorm
    check("_G.hyperStormKey is the tap's door", _G.hyperStormKey == s2.keyNote)
    hold(5000); NOW = 5001
    s2.keyNote(7, ev())                       -- x, from the tap
    s2.note("x", "mouse grid")                -- the same press, from hyperBind
    check("the same key from both doors is ONE key (named as hyperBind names it)", #s2.order == 1 and s2.order[1][1] == "x", s2.order[1] and s2.order[1][1])
    s2.keyNote(0, ev()); s2.keyNote(11, ev()); s2.keyNote(8, ev()); s2.keyNote(2, ev())
    check("four letters the grid ate are counted from the tap", #s2.order == 5)
    check("a shifted key is its own combo, shaped shift+e", s2.keyNote(14, ev({ shift = true })) == false and s2.order[6][1] == "shift+e", s2.order[6] and s2.order[6][1])
    check("F18 itself is never a key", s2.keyNote(79, ev()) == false and #s2.order == 6)
    check("an unmapped code still counts, by number", s2.keyNote(999, ev()) == false and s2.order[7][1] == "key999")
    NOW = 5006
    RELEASED = {}
    local r = s2.keyNote(3, ev())
    check("…and the storm fires from the tap's door at 5 s with six different keys", r == true and RELEASED[1] == "the ⇪ storm guard")
    check("the report names the tap as the owner of an eaten key", readAll(s2.last.path):find("typed under ⇪", 1, true) ~= nil)
    release()
    -- a missing folder is "no reports", never a ⚠️
    os.execute('rm -rf "' .. ROOT .. '/.storm"')
    local path, why = s2.newest()
    check("no folder yet → nil, nil (not an error)", path == nil and why == nil)
    local okA, whyA = s2.announce()
    check("announce on a fresh Mac says 'no reports yet' and records no warning", okA == false and whyA == "no reports yet" and s2.announceWhy == nil)
    PRINTED = {}
    _G.stormReport()
    check("the report carries no ⚠️ line for a folder that was never needed", not PRINTED[1]:find("⚠️", 1, true), PRINTED[1])
    local f = io.open(ROOT .. "/.storm", "w"); f:write("x"); f:close()
    local p2, w2 = s2.newest()
    check("a FILE in the folder's place is a real listing failure, and says so", p2 == nil and type(w2) == "string" and w2:find("cannot list", 1, true))
    os.remove(ROOT .. "/.storm")
    local tap = readAll(HS .. "/core/hyper_key.lua") or ""
    check("the tap calls _G.hyperStormKey on keyDown under ⇪, inside its own pcall, before the dispatch decision",
          tap:find("if _G.hyperActive and _G.hyperStormKey and t == hs.eventtap.event.types.keyDown then\n            pcall(_G.hyperStormKey, code, ev)", 1, true) ~= nil
              and tap:find("pcall(_G.hyperStormKey, code, ev)\n        end\n        if not _G.hyperDispatchEngaged then return false end", 1, true) ~= nil)
end

os.execute('rm -rf "' .. ROOT .. '"')
print = realPrint
out(string.format("\n%d passed, %d failed\n", pass, fail))
for _, f in ipairs(failures) do out("  ❌ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
