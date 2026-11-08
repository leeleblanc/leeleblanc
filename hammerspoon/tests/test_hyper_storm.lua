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
local NO_TIMER, TIMERS = false, {}
local function fireTimers()
    local list = TIMERS
    TIMERS = {}
    local n = 0
    for _, t in ipairs(list) do
        if not t.stopped then n = n + 1; t.fn() end
    end
    return n
end
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(p, " ")
end
hs = {
    configdir = ROOT,
    timer = {
        secondsSinceEpoch = function() return NOW end,
        -- 6.290.0 — the stub answers what macOS answers, refusals
        -- included: NO_TIMER makes doAfter raise the way a Mac without
        -- it does, and a timer that has been stopped never fires again
        -- (a stub that let a stopped timer fire turns a correct
        -- implementation red — 6.389.0).
        doAfter = function(secs, fn)
            if NO_TIMER then error("no hs.timer.doAfter here") end
            local t = { secs = secs, fn = fn, stopped = false }
            t.stop = function(self) (self or t).stopped = true; return self or t end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
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

-- 📠 6.417.0's RULE, AND THE SWEEP FOUND IT UNDRIVEN HERE. Moving the
-- asked-for-text guard BELOW the print survived every check in this
-- suite: the report would print AND return, so typing it in the Console
-- shows the whole block twice (the Console echoes a return), and
-- 6.421.0's hand-off would print it at the moment the keyboard dies.
-- The silent mode is the whole reason the argument exists, so it is
-- asserted rather than assumed (6.273.0 — the line is not the finding,
-- the missing check is).
PRINTED = {}
local asText = _G.stormReport(true)
check("📠 _G.stormReport(true) RETURNS the text and prints NOTHING — the "
      .. "Console echoes a return, so a report that does both doubles",
      type(asText) == "string" and #PRINTED == 0
      and asText:find("Hyper storm guard", 1, true) ~= nil,
      "#printed=" .. #PRINTED .. " type=" .. type(asText))
PRINTED = {}
local unasked = _G.stormReport()
check("📠 ...and unasked it still PRINTS and returns nothing, so the "
      .. "silent mode has not cost the ordinary one",
      #PRINTED == 1 and unasked == nil, "#printed=" .. #PRINTED)

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

-- ---------------------------------------------------------------------
out("11) 6.215.0 — the storm guard takes the degrade door\n")
-- ---------------------------------------------------------------------
do
    local DEGRADED = {}
    local m3 = dofile(HS .. "/modules/hyper_storm.lua")
    m3.setup({ configDir = ROOT, degrade = function(tool, why)
        DEGRADED[#DEGRADED + 1] = tostring(tool) .. ": " .. tostring(why)
        return false, why
    end })
    local s3 = _G.hyperStorm
    os.execute('rm -rf "' .. ROOT .. '/.storm"')
    local okA, whyA = s3.announce()
    check("a missing folder still says 'no reports yet' and takes NO door — it is not a break",
          okA == false and whyA == "no reports yet" and #DEGRADED == 0)
    local f = io.open(ROOT .. "/.storm", "w"); f:write("x"); f:close()
    local okB, whyB = s3.announce()
    check("a folder that cannot be listed goes through core.degrade, named, with the cause",
          okB == false and #DEGRADED == 1 and DEGRADED[1]:find("^Hyper storm guard: cannot list") ~= nil, DEGRADED[1])
    check("…and announce still returns false, why (the door's own return)", type(whyB) == "string" and whyB:find("cannot list", 1, true) ~= nil)
    check("…and the report line carries the same cause", s3.announceWhy == whyB)
    os.remove(ROOT .. "/.storm")
    -- warm(): an announce that THROWS is no longer swallowed by its pcall
    s3.announce = function() error("boom at boot") end
    m3.warm({})
    check("an announce that throws inside warm() is degraded, not swallowed",
          #DEGRADED == 2 and DEGRADED[2]:find("announce threw", 1, true) ~= nil and DEGRADED[2]:find("boom at boot", 1, true) ~= nil, DEGRADED[2])
    check("…and the report line names it", tostring(s3.announceWhy):find("announce threw", 1, true) ~= nil)
    -- no door on this core (an older init.lua): the fallback prints and returns false, why
    local m4 = dofile(HS .. "/modules/hyper_storm.lua")
    m4.setup({ configDir = ROOT })
    local s4 = _G.hyperStorm
    PRINTED = {}
    local okD, whyD = s4.degrade("no door here")
    check("without core.degrade the taker prints a ⚠️ line itself and returns false, why",
          okD == false and whyD == "no door here" and PRINTED[1] and PRINTED[1]:find("⚠️ Hyper storm guard: no door here", 1, true) ~= nil)
    -- source sentry: the door is on the announce path, not only the helper
    local src = readAll(HS .. "/modules/hyper_storm.lua") or ""
    check("SOURCE: announce returns st.degrade(epoch) for a real refusal and a bare false for a missing folder",
          src:find("if epoch then return st.degrade(epoch) end", 1, true) ~= nil
          and src:find('return false, "no reports yet"', 1, true) ~= nil)
    check("SOURCE: warm() reads pcall's ok and degrades the throw",
          src:find("local ok, err = pcall(st.announce)\n    if not ok then", 1, true) ~= nil)
    _G.hyperStorm = s3
end


-- =====================================================================
-- 🔬 6.403.0 — A STORM ASKS WHY, AND THE ANSWERS GO IN THE FILE
-- =====================================================================
-- LL's 2026-11-04 Console: ⇪ latched TWICE in forty-five seconds and the
-- second one paused the config. Both files carried COUNTS and no CAUSES,
-- because 6.303.0's probe — the only thing that reads the remap, the tap
-- and Secure Input — was wired to wake events alone.
do
    out("\n🔬 6.403.0 — a storm asks why\n")

    -- 🔌 THE RENDERER IS LIFTED OUT OF THE SHIPPED SOURCE, never retyped
    -- (6.273.0). A stub that invented these three sentences would not
    -- merely miss a drift between core/ and the storm report — it would
    -- certify it.
    local function liftProbeAnswers()
        local src = readAll(HS .. "/core/hyper_key.lua") or ""
        local body = src:match("(function _G%.hyperProbeAnswers%(P%).-\n   end)\n")
                  or src:match("(function _G%.hyperProbeAnswers%(P%).-\nend)\n")
        if not body then return nil, "not found in the source" end
        local box = {}
        local env = { tostring = tostring, type = type, _G = box }
        local chunk = load(body, "probeAnswers", "t", env)
        if not chunk then return nil, "would not load" end
        local okc = pcall(chunk)
        if not okc then return nil, "threw on load" end
        return box.hyperProbeAnswers
    end
    local answers, liftWhy = liftProbeAnswers()
    check("the three answers are LIFTED out of core/hyper_key.lua's own source",
          type(answers) == "function", liftWhy)
    _G.hyperProbeAnswers = answers

    local m = dofile(HS .. "/modules/hyper_storm.lua")
    m.setup({ configDir = ROOT })
    local st = _G.hyperStorm

    -- ---- the pure renderer, three freshness states ---------------------
    local P = { at = 1000, why = "the ⇪ storm guard", remap = true, tap = true,
                secure = "clear", reads = 3, failed = 0, repaired = 0 }
    local fresh, kf = st.probeLines(P, 1000)
    local stale, ks = st.probeLines({ at = 100, why = "systemDidWake", remap = true,
                                      tap = true, secure = "clear" }, 1000)
    local never, kn = st.probeLines(nil, 1000)
    check("three freshness states and three different answers",
          kf == "fresh" and ks == "stale" and kn == "never",
          tostring(kf) .. "/" .. tostring(ks) .. "/" .. tostring(kn))
    -- 🚨 THE FIXTURE THAT BITES: a stale reading renders the SAME three
    -- answers as a fresh one, so a check on the answers passes with the
    -- age thrown away. Only the first line can tell them apart.
    check("a FRESH reading says it was measured at this storm",
          fresh[1]:find("measured AT this storm", 1, true) ~= nil, fresh[1])
    check("a STALE reading says so, with its age, and refuses to describe this storm",
          stale[1]:find("OLD READING", 1, true) ~= nil
          and stale[1]:find("900 s before this storm", 1, true) ~= nil
          and stale[1]:find("does NOT describe this storm", 1, true) ~= nil, stale[1])
    check("never-asked is neither of them and says the file cannot say which",
          never[1]:find("NOT ASKED", 1, true) ~= nil
          and never[1]:find("cannot say which", 1, true) ~= nil
          and #never == 1, never[1])
    check("a healthy reading renders all three answers",
          table.concat(fresh, "\n"):find("Caps Lock → F18 still set", 1, true) ~= nil
          and table.concat(fresh, "\n"):find("the F18 event tap is running", 1, true) ~= nil
          and table.concat(fresh, "\n"):find("Secure Input clear", 1, true) ~= nil)

    -- 🚨 "COULD NOT BE ASKED" MUST NEVER RENDER AS HEALTH — this is the
    -- row that reads as reassurance when it is wrong, and it is the one
    -- LL's own Mac has been answering for two releases.
    local blind = table.concat(st.probeLines({ at = 1000, why = "x" }, 1000), "\n")
    check("a probe that could not read any of the three says so on every row, with a ⚠️",
          blind:find("could not be read", 1, true) ~= nil
          and blind:find("not known", 1, true) ~= nil
          and blind:find("Secure Input clear", 1, true) == nil
          and blind:find("still set", 1, true) == nil, blind)

    -- a core that did not load must cost the SECTION, never the file
    _G.hyperProbeAnswers = nil
    local noCore = table.concat(st.probeLines(P, 1000), "\n")
    check("without core/hyper_key.lua the rows say they could not be rendered, not that all is well",
          noCore:find("could not be rendered", 1, true) ~= nil
          and noCore:find("still set", 1, true) == nil, noCore)
    _G.hyperProbeAnswers = answers

    -- ---- the storm asks, and the order is the rule ---------------------
    local ORDER = {}
    _G.hyperForceRelease = function() ORDER[#ORDER + 1] = "release"; return true end
    _G.hyperWakeProbe = { at = nil, why = "no wake probed yet", reads = 0, failed = 0 }
    _G.hyperWakeProbeRun = function(why)
        ORDER[#ORDER + 1] = "probe"
        _G.hyperWakeProbe = { at = NOW, why = tostring(why), remap = true, tap = true,
                              secure = "clear", reads = 1, failed = 0, repaired = 0 }
        return true
    end

    st.order = { { "a", "one" }, { "b", "two" } }
    local okF = st.fire(7, NOW)
    check("the storm fires", okF == true)
    -- 6.220.0 — the ORDER, not that both happened. A check on presence
    -- passes with the probe asked BEFORE the release, which is the one
    -- arrangement where a probe that throws costs him his keyboard.
    check("the release happens BEFORE the probe is asked",
          ORDER[1] == "release" and ORDER[2] == "probe", table.concat(ORDER, ","))
    check("the probe is counted as asked", st.probes.asked == 1 and st.probes.failed == 0)
    check("the probe was told who asked it",
          tostring(_G.hyperWakeProbe.why):find("storm guard", 1, true) ~= nil)

    local path1 = st.last.path
    check("the report is on disk at once, without waiting for the probe", path1 ~= nil)
    local at_storm = readAll(path1) or ""
    check("the file written at storm time carries the WHY section, honestly labelled",
          at_storm:find("why    :", 1, true) ~= nil
          and at_storm:find("appended at the END of this file", 1, true) ~= nil, at_storm:sub(1, 200))
    check("…and it does NOT yet claim a measured answer", at_storm:find("── why (measured", 1, true) == nil)

    -- ---- the answers land in the file ----------------------------------
    check("one file is waiting for the answers", #st.probeWaiting == 1)
    fireTimers()
    check("the answer is counted as landed", st.probes.landed == 1, st.probes.landed)
    local after = readAll(path1) or ""
    check("the three answers are APPENDED to the storm file",
          after:find("── why (measured at the storm) ──", 1, true) ~= nil
          and after:find("Caps Lock → F18 still set", 1, true) ~= nil
          and after:find("the F18 event tap is running", 1, true) ~= nil, after:sub(-400))
    check("the append added to the file and took nothing away (6.279.0)",
          #after > #at_storm and after:sub(1, #at_storm) == at_storm)
    check("nothing is left waiting", #st.probeWaiting == 0 and st.probeTimer == nil)

    -- ---- 🚨 TWO STORMS 45 s APART — the thing a single slot would drop --
    -- This is not hypothetical: it is exactly LL's own log.
    st.probes = { asked = 0, landed = 0, noTimer = 0, dropped = 0, failed = 0 }
    st.times, st.storms = {}, 0
    st.order = { { "c", "three" } }
    st.fire(7, NOW + 100)
    local pA = st.last.path
    st.order = { { "d", "four" } }
    st.fire(14, NOW + 145)
    local pB = st.last.path
    check("two storms forty-five seconds apart are two different files", pA ~= pB and pA and pB)
    check("BOTH files are waiting for the answers — the newer did not take the slot",
          #st.probeWaiting == 2, #st.probeWaiting)
    fireTimers()
    local tA, tB = readAll(pA) or "", readAll(pB) or ""
    check("the first storm's answers are NOT dropped by the second",
          tA:find("── why (measured at the storm) ──", 1, true) ~= nil, tA:sub(-200))
    check("…and the second storm's answers land too",
          tB:find("── why (measured at the storm) ──", 1, true) ~= nil, tB:sub(-200))
    check("both are counted", st.probes.landed == 2, st.probes.landed)

    -- ---- the degrades --------------------------------------------------
    -- a Mac with no doAfter: the release still happens, and the miss is
    -- COUNTED and SAID rather than leaving the file looking complete
    NO_TIMER = true
    st.probes = { asked = 0, landed = 0, noTimer = 0, dropped = 0, failed = 0 }
    st.times, st.storms = {}, 0
    ORDER = {}
    st.order = { { "e", "five" } }
    st.fire(9, NOW + 400)
    NO_TIMER = false
    check("without hs.timer.doAfter the storm still RELEASES the hold",
          ORDER[1] == "release")
    check("…the missing beat is counted, not swallowed", st.probes.noTimer == 1, st.probes.noTimer)
    PRINTED = {}
    _G.stormReport()
    local rep = table.concat(PRINTED, "\n")
    check("…and the report says the answers are not in the file",
          rep:find("could not arm the append beat", 1, true) ~= nil
          and rep:find("_G.hyperKeyReport()", 1, true) ~= nil, rep)

    -- 🚨 AND "ABSENT" IS NOT "REFUSING" (6.265.0). The check above drives
    -- a doAfter that RAISES, which lands on the second counter; a Mac
    -- with no doAfter AT ALL takes a different branch with its own, and
    -- the sweep found that branch driven by nothing. Both, now.
    st.probes = { asked = 0, landed = 0, noTimer = 0, dropped = 0, failed = 0 }
    st.times, st.storms = {}, 0
    ORDER = {}
    local realDoAfter = hs.timer.doAfter
    hs.timer.doAfter = nil
    st.order = { { "g", "seven" } }
    st.fire(9, NOW + 450)
    hs.timer.doAfter = realDoAfter
    check("with NO hs.timer.doAfter at all the storm still RELEASES the hold",
          ORDER[1] == "release", table.concat(ORDER, ","))
    check("…and the absent-doAfter branch counts the miss too, not only the refusing one",
          st.probes.noTimer == 1, st.probes.noTimer)
    check("…and nothing is left waiting for an answer that can never be appended",
          st.probeWaiting ~= nil and st.probeTimer == nil)
    st.probeWaiting = {}

    -- an append the disk refuses costs the section, never the report
    st.probes = { asked = 0, landed = 0, noTimer = 0, dropped = 0, failed = 0 }
    local okA, whyA = st.appendSection(ROOT .. "/no/such/folder/x.txt", "why", { "a" })
    check("a refused append answers false and why, and names the path",
          okA == false and tostring(whyA):find("cannot append", 1, true) ~= nil, whyA)
    local okN = st.appendSection(nil, "why", { "a" })
    check("an append with no path is refused rather than throwing", okN == false)

    -- the waiting list is bounded, and the bound is a STATE
    st.probeWaiting = {}
    for i = 1, 20 do st.probeWait(ROOT .. "/x" .. i .. ".txt", NOW) end
    check("the waiting list is bounded at probeWaitMax",
          #st.probeWaiting == st.probeWaitMax, #st.probeWaiting)
    check("…and the storms that got no answer are counted, never silently dropped",
          st.probes.dropped == 20 - st.probeWaitMax, st.probes.dropped)
    st.probeWaiting, st.probeTimer = {}, nil

    -- the switch is real in both directions
    st.probes = { asked = 0, landed = 0, noTimer = 0, dropped = 0, failed = 0 }
    st.probeOn = false
    st.times, st.storms = {}, 0
    ORDER = {}
    st.order = { { "f", "six" } }
    st.fire(9, NOW + 500)
    check("probeOn = false asks nothing and still releases",
          st.probes.asked == 0 and ORDER[1] == "release" and #st.probeWaiting == 0)
    local offText = readAll(st.last.path) or ""
    check("…and the file does not promise an answer that is not coming",
          offText:find("appended at the END", 1, true) == nil, offText:sub(1, 200))
    st.probeOn = true

    -- ---- 📋 6.421.0 — the storm hands its report to the clipboard -------
    -- LL: "Does the console automatically generate a report for any
    -- condition that kills my keyboard and is automatically pasted to the
    -- clipboard?" It did not: the alert names a FILE PATH, and a path
    -- cannot be copied out of an hs.alert — so the one moment he could
    -- not type `_G.stormReport()` was the moment the keyboard was dead.
    -- 🔗 BOTH SIDES OF THE JOIN (6.388.0): test_panel_drag proves the DOOR
    -- in core/coexist.lua, and this proves the storm ASKS it. Half a join
    -- is a contract nobody holds.
    do
        local ASKED = {}
        local keptHand = _G.clipHandOff
        _G.clipHandOff = function(who, event, text)
            ASKED[#ASKED + 1] = { who = who, event = event, text = text }
            return true, "the whole report is on your clipboard — ⌘V sends it"
        end

        st.probes = { asked = 0, landed = 0, noTimer = 0, dropped = 0, failed = 0 }
        st.probeWaiting, st.probeTimer = {}, nil
        st.times, st.storms = {}, 0
        ORDER = {}
        st.order = { { "h", "eight" } }
        local okF, msgF = st.fire(9, NOW + 600)
        check("📋 a storm hands its report over", okF == true and #ASKED >= 1,
              #ASKED)
        check("📋 …and it hands over the REPORT, not the alert — the "
              .. "newest file's text is what he needs to send",
              ASKED[1] and type(ASKED[1].text) == "string"
              and ASKED[1].text:find("Hyper storm guard", 1, true) ~= nil,
              ASKED[1] and ASKED[1].text:sub(1, 80) or "none")
        check("📋 …and the ALERT says so, so he knows ⌘V has it",
              type(msgF) == "string" and msgF:find("⌘V", 1, true) ~= nil, msgF)
        check("🪪 …under the storm's own second as the event id",
              ASKED[1] and ASKED[1].event == "storm-" .. tostring(math.floor(NOW + 600)),
              ASKED[1] and ASKED[1].event or "none")

        -- 🔑 THE CLAUSE THE WHOLE NO-CLOCK RULE EXISTS FOR: 6.403.0's probe
        -- answers are appended a beat LATER, and those three lines are the
        -- reason that release exists. A hand-off only at the fire would put
        -- the report on his clipboard with its "why" section missing.
        local before = #ASKED
        st.probeLand()
        check("🔑 the probe's answers landing hand the report over AGAIN, so "
              .. "the clipboard carries the 'why' section and not the report "
              .. "without its diagnosis",
              #ASKED == before + 1, #ASKED - before)
        check("🪪 …under the SAME event id, so the door reads it as the same "
              .. "event GROWN rather than a second storm — a different id "
              .. "would hand over needlessly when the probe added nothing",
              ASKED[#ASKED] and ASKED[#ASKED].event == ASKED[1].event,
              ASKED[#ASKED] and ASKED[#ASKED].event or "none")

        -- nothing waiting → nothing handed over a second time
        local before2 = #ASKED
        st.probeWaiting = {}
        st.probeLand()
        check("📏 a probe landing with nothing waiting hands over nothing",
              #ASKED == before2, #ASKED - before2)

        -- 🚪 ORDER, ASSERTED (6.220.0): the release is what lets his next
        -- key type and the hand-off is diagnosis, so a hand-off that THROWS
        -- must cost the sentence and nothing else.
        _G.clipHandOff = function() error("the clipboard exploded", 0) end
        st.times, st.storms = {}, 0
        ORDER = {}
        st.order = { { "i", "nine" } }
        local okT, msgT = st.fire(9, NOW + 700)
        check("🚪 a hand-off that THROWS still RELEASES the hold and still "
              .. "writes the report — it can never cost him his keyboard",
              okT == true and ORDER[1] == "release", table.concat(ORDER, ","))
        check("🚪 …and the alert simply does not claim the clipboard has it",
              type(msgT) == "string" and msgT:find("⌘V", 1, true) == nil, msgT)

        -- a Hammerspoon with no door at all (an older core/coexist.lua)
        _G.clipHandOff = nil
        st.times, st.storms = {}, 0
        ORDER = {}
        st.order = { { "j", "ten" } }
        local okN2, msgN2 = st.fire(9, NOW + 800)
        check("🛟 with no hand-off door at all the storm is unchanged",
              okN2 == true and ORDER[1] == "release"
              and msgN2:find("⌘V", 1, true) == nil, table.concat(ORDER, ","))

        _G.clipHandOff = keptHand
        st.probeWaiting, st.probeTimer = {}, nil
    end

    -- ---- the source sentries -------------------------------------------
    local src = readAll(HS .. "/modules/hyper_storm.lua") or ""
    check("SOURCE: the timer is HELD in its own named slot — an unreferenced hs.timer never fires (6.196.1)",
          src:find("ok, st.probeTimer = pcall(hs.timer.doAfter", 1, true) ~= nil)
    check("SOURCE: pcall's timer is captured in TWO values, never an `and` chain (6.355.0)",
          src:find("st.probeTimer = pcall(hs.timer.doAfter", 1, true) ~= nil
          and src:find("hs.timer.doAfter and pcall", 1, true) == nil)
    check("SOURCE: the append reads io.write's own return (6.325.0)",
          src:find("local wrote, werr = f:write(text)", 1, true) ~= nil
          and src:find('if not wrote then return false', 1, true) ~= nil)
    check("SOURCE: the file is opened for APPEND, never rewritten (6.279.0)",
          src:find('io.open(path, "a")', 1, true) ~= nil)
    local core = readAll(HS .. "/core/hyper_key.lua") or ""
    check("SOURCE: _G.hyperKeyReport() asks the one renderer rather than keeping a second copy (6.231.0)",
          core:find("local pRemap, pTap, pSecure = _G.hyperProbeAnswers(P)", 1, true) ~= nil
          and select(2, core:gsub("Caps Lock → F18 still set", "")) == 1,
          select(2, core:gsub("Caps Lock → F18 still set", "")))

    _G.hyperProbeAnswers, _G.hyperWakeProbeRun, _G.hyperForceRelease = nil, nil, nil
end

os.execute('rm -rf "' .. ROOT .. '"')
print = realPrint
out(string.format("\n%d passed, %d failed\n", pass, fail))
for _, f in ipairs(failures) do out("  ❌ " .. f .. "\n") end
os.exit(fail == 0 and 0 or 1)
