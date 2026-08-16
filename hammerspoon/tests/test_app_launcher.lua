-- =====================================================================
-- test_app_launcher.lua — the module that promises "every installed app"
-- =====================================================================
--     lua5.4 test_app_launcher.lua [/path/to/hammerspoon]
--
-- The claim under test is COVERAGE: /Applications, ~/Applications and
-- /System/Applications, each one folder deep, on a personal Mac AND on a
-- work Mac where some of those folders do not exist. The traps are the
-- walk going where it must not (INTO an .app bundle, or two levels down
-- a vendor tree) and a missing folder being treated as an error — on the
-- work Mac a missing /Applications entry is Tuesday, not a failure.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else
        fail = fail + 1
        local line = label .. (extra and ("  [" .. tostring(extra) .. "]") or "")
        failures[#failures + 1] = line
        io.write("   ❌ " .. line .. "\n")
    end
end
local function out(s) io.write(s) end

-- ---- a controllable filesystem ---------------------------------------
local printed = {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

local NOW = 1000
local FS, FILES, HANGS = {}, {}, {}
local FSDIR, WATCHERS, CHOOSERS, ALERTS = {}, {}, {}, {}
local LAUNCHES, OPENS, HYPER, PROVIDED = {}, {}, {}, {}
local LAUNCH_RESULT, OPEN_RESULT = {}, {}

hs = {
    fs = {
        -- Real hs.fs.dir THROWS on a missing directory; the stub does the
        -- same, because "a folder that is not there" is the exact shape
        -- this module promises to survive. A HANGS entry burns clock the
        -- way a wedged network mount does.
        dir = function(path)
            FSDIR[#FSDIR + 1] = path
            local t = FS[path]
            if not t then error(path .. ": No such file or directory") end
            if HANGS[path] then NOW = NOW + HANGS[path] end
            local list = { ".", ".." }
            for _, n in ipairs(t) do list[#list + 1] = n end
            local i = 0
            return function() i = i + 1 ; return list[i] end
        end,
        attributes = function(path, what)
            if what ~= "mode" then return nil end
            if FS[path] then return "directory" end
            if FILES[path] then return "file" end
            return nil
        end,
    },
    timer = { secondsSinceEpoch = function() NOW = NOW + 0.0001 ; return NOW end },
    pathwatcher = { new = function(path, fn)
        local w = { path = path, fn = fn, started = false }
        function w:start() self.started = true ; return self end
        WATCHERS[#WATCHERS + 1] = w
        return w end },
    application = { launchOrFocus = function(path)
        LAUNCHES[#LAUNCHES + 1] = path
        local r = LAUNCH_RESULT[path]
        if r == nil then return true end
        return r end },
    open = function(path)
        OPENS[#OPENS + 1] = path
        local r = OPEN_RESULT[path]
        if r == nil then return true end
        return r end,
    image = { iconForFile = function(path) return { icon = path } end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    chooser = { new = function(fn)
        local c = { fn = fn, shown = false, q = "" }
        for _, m in ipairs({ "searchSubText", "width" }) do
            c[m] = function(self) return self end
        end
        function c:placeholderText(t) self.placeholder = t ; return self end
        function c:choices(x) self.rows = x ; return self end
        function c:show() self.shown = true ; return self end
        function c:query() return self.q end
        function c:queryChangedCallback(f) self.qcb = f ; return self end
        CHOOSERS[#CHOOSERS + 1] = c ; return c end },
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

local HOME = "/Users/lee"
local CORE = {
    hostTag = "Test-Mac",
    homeDir = HOME,
    hyperAddShortcut = function(mods, key, fn)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms) ; HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function(n, f) PROVIDED[n] = f end,
}

-- The personal-Mac tree. The traps are load-bearing:
--   · Weird.app CONTAINS Helper.app — a walk that enters bundles finds 9
--   · Adobe…/Deeper/TooDeep.app is TWO levels down — depth 1 must not
--   · README.txt is a plain file wearing no .app suit
local function personalMac()
    FS = {
        ["/Applications"] = { "Firefox.app", "VLC.app", "Weird.app",
                              "Adobe Creative Cloud", "README.txt" },
        ["/Applications/Weird.app"] = { "Helper.app" },
        ["/Applications/Adobe Creative Cloud"] = { "Adobe Photoshop.app", "Deeper" },
        ["/Applications/Adobe Creative Cloud/Deeper"] = { "TooDeep.app" },
        [HOME .. "/Applications"] = { "Firefox.app", "Chrome Apps.localized" },
        [HOME .. "/Applications/Chrome Apps.localized"] = { "Gmail.app" },
        ["/System/Applications"] = { "Safari.app", "Utilities" },
        ["/System/Applications/Utilities"] = { "Terminal.app" },
    }
    FILES = { ["/Applications/README.txt"] = true }
    HANGS = {}
end

local M, AL
local function boot(tree)
    printed, FSDIR, WATCHERS, CHOOSERS, ALERTS = {}, {}, {}, {}, {}
    LAUNCHES, OPENS, HYPER, PROVIDED = {}, {}, {}, {}
    LAUNCH_RESULT, OPEN_RESULT = {}, {}
    _G.diag.said = {} ; NOW = 1000
    _G.fileIndex = nil            -- each section states its own index
    tree()
    M = dofile(HS .. "/modules/app_launcher.lua")
    M.setup(CORE)
    AL = M.launcher
end

local function names(apps)
    local t = {}
    for _, e in ipairs(apps or {}) do t[#t + 1] = e.name end
    return table.concat(t, ",")
end

-- =====================================================================
out("── test_app_launcher (module at " .. HS .. ")\n")

-- ---- 1. contract ----------------------------------------------------
out("   1. module contract & key claims\n")
boot(personalMac)
check("module name", M.name == "App Launcher", M.name)
check("cheatsheet title names ⇪D", (M.cheatsheet.title or ""):find("⇪D", 1, true))
check("⇪D claimed", type(HYPER["|d"]) == "function")
local n = 0 ; for _ in pairs(HYPER) do n = n + 1 end
check("…and ONLY ⇪D — ⇪⇧D belongs to Diagnostics", n == 1, n)
check("service appLauncher.show provided",  type(PROVIDED["appLauncher.show"]) == "function")
check("service appLauncher.list provided",  type(PROVIDED["appLauncher.list"]) == "function")
check("warm() defined for watchers + first scan", type(M.warm) == "function")
check("config table exposed for profile overrides", M.config == AL)

-- ---- 2. the walk ----------------------------------------------------
out("   2. the walk: three roots, one level deep, never inside a bundle\n")
local apps = AL.scan(true)
check("eight apps found", #apps == 8, names(apps))
local have = {}
for _, e in ipairs(apps) do have[e.name] = (have[e.name] or 0) + 1 end
check("sublevel reached: Adobe Photoshop (vendor folder)", have["Adobe Photoshop"] == 1)
check("sublevel reached: Gmail (Chrome Apps.localized)",   have["Gmail"] == 1)
check("sublevel reached: Terminal (Utilities)",            have["Terminal"] == 1)
check("Weird.app is an app, not a folder to enter",        have["Weird"] == 1)
check("…so its inner Helper.app is NOT listed",            have["Helper"] == nil)
check("TooDeep.app (two levels down) is NOT listed",       have["TooDeep"] == nil)
check("README.txt is not an app",                          have["README"] == nil)
check("sorted: Adobe Photoshop first", apps[1] and apps[1].name == "Adobe Photoshop")
check("duplicate name keeps both rows", have["Firefox"] == 2)
local fx = {}
for _, e in ipairs(apps) do if e.name == "Firefox" then fx[#fx + 1] = e end end
check("…/Applications outranks ~/Applications on the tie",
      fx[1] and fx[1].label == "/Applications"
      and fx[2] and fx[2].label == "~/Applications",
      (fx[1] and fx[1].label or "?") .. " then " .. (fx[2] and fx[2].label or "?"))
check("labels carry the ROOT, not the subfolder",
      (function()
          for _, e in ipairs(apps) do
              if e.name == "Gmail" then return e.label == "~/Applications" end
          end
      end)())

-- ---- 3. the work Mac ------------------------------------------------
out("   3. the work Mac: missing folders are Tuesday, not an error\n")
boot(function()
    FS = {
        [HOME .. "/Applications"] = { "Firefox.app", "Chrome Apps.localized" },
        [HOME .. "/Applications/Chrome Apps.localized"] = { "Gmail.app" },
    }
    FILES, HANGS = {}, {}
end)
local okScan, workApps = pcall(AL.scan, true)
check("no /Applications, no /System/Applications: no throw", okScan, workApps)
check("the user-dir apps are all there", okScan and #workApps == 2, names(workApps))
boot(function() FS, FILES, HANGS = {}, {}, {} end)
local okEmpty, none = pcall(AL.scan, true)
check("NO folders at all: still no throw", okEmpty)
check("…and an empty list, not nil", okEmpty and type(none) == "table" and #none == 0)
AL.show()
check("show() on the empty Mac alerts instead of opening a dead picker",
      #ALERTS == 1 and ALERTS[1]:find("No applications", 1, true), ALERTS[1])
check("…and no chooser was built", #CHOOSERS == 0)

-- ---- 4. cache & invalidation ----------------------------------------
out("   4. cache: long TTL, dropped the moment a folder changes\n")
boot(personalMac)
AL.scan(true)
local reads = #FSDIR
AL.scan(false)
check("second scan inside TTL reads nothing", #FSDIR == reads, #FSDIR - reads)
NOW = NOW + AL.cacheSecs + 1
AL.scan(false)
check("TTL expiry rescans", #FSDIR > reads)
M.warm()
check("warm starts one watcher per root", #WATCHERS == 3, #WATCHERS)
check("…and they are started", WATCHERS[1].started and WATCHERS[2].started
      and WATCHERS[3].started)
reads = #FSDIR
AL.scan(false)
check("fresh cache after warm: no reads", #FSDIR == reads)
WATCHERS[1].fn()
AL.scan(false)
check("a watcher firing drops the cache: next press rescans", #FSDIR > reads)

-- ---- 5. the scan budget ---------------------------------------------
out("   5. a wedged folder stalls the walk, not the keyboard\n")
boot(personalMac)
HANGS["/Applications"] = 5          -- listing it burns 5s of a 1s budget
local slow = AL.scan(true)
check("scan still returns a list", type(slow) == "table")
check("…a partial one", #slow < 8, #slow)
check("…and says why", warned("budget"))

-- ---- 6. the picker --------------------------------------------------
out("   6. the picker: labelled rows, honest placeholder, icons capped\n")
boot(personalMac)
AL.show()
check("one chooser, shown", #CHOOSERS == 1 and CHOOSERS[1].shown)
local rows = CHOOSERS[1].rows or {}
check("eight rows", #rows == 8, #rows)
check("placeholder counts them", (CHOOSERS[1].placeholder or ""):find("8 apps", 1, true),
      CHOOSERS[1].placeholder)
check("a row carries its launch path", rows[1] and rows[1].path ~= nil)
check("subText is the source folder",
      rows[1] and rows[1].subText == "/Applications", rows[1] and rows[1].subText)
check("icons on by default", rows[1] and rows[1].image ~= nil)
AL.show()
check("second press reuses the chooser", #CHOOSERS == 1)
boot(personalMac)
AL.iconBudget = 0
AL.show()
rows = CHOOSERS[1].rows or {}
check("icon budget of zero: rows, no icons", #rows == 8 and rows[1].image == nil)

-- ---- 7. launching ---------------------------------------------------
out("   7. launching: path not name, fallback chain, one honest alert\n")
boot(personalMac)
AL.show()
rows = CHOOSERS[1].rows or {}
local userFirefox
for _, r in ipairs(rows) do
    if r.text == "Firefox" and r.subText == "~/Applications" then userFirefox = r end
end
check("the ~/Applications Firefox row exists", userFirefox ~= nil)
CHOOSERS[1].fn(userFirefox)
check("launchOrFocus got the FULL PATH of that copy",
      LAUNCHES[1] == HOME .. "/Applications/Firefox.app", LAUNCHES[1])
check("…and hs.open was not needed", #OPENS == 0)
CHOOSERS[1].fn(nil)
check("Esc (nil pick) is quiet", #LAUNCHES == 1 and #ALERTS == 0)
LAUNCH_RESULT["/Applications/VLC.app"] = false
local vlc
for _, r in ipairs(rows) do if r.text == "VLC" then vlc = r end end
CHOOSERS[1].fn(vlc)
check("launchOrFocus refused → hs.open tries the same path",
      OPENS[1] == "/Applications/VLC.app", OPENS[1])
check("…fallback worked, so no alert", #ALERTS == 0)
LAUNCH_RESULT["/Applications/Weird.app"] = false
OPEN_RESULT["/Applications/Weird.app"] = false
local weird
for _, r in ipairs(rows) do if r.text == "Weird" then weird = r end end
CHOOSERS[1].fn(weird)
check("both refused → exactly one alert", #ALERTS == 1, #ALERTS)
check("…that names the app", ALERTS[1]:find("Weird", 1, true), ALERTS[1])
check("…and the warning names both failures", warned("launchOrFocus and hs.open"))

-- ---- 8. files behind the apps (6.96.0) ------------------------------
out("   8. the file index: rows join after 3 letters, apps stay first\n")
boot(personalMac)
local ASKED = {}
_G.fileIndex = {
    search = function(q, limit)
        ASKED[#ASKED + 1] = { q = q, limit = limit }
        if #q < 3 then return {} end
        return {
            { path = "/Users/lee/Documents/Firefox notes.txt",
              name = "Firefox notes.txt", dir = "~/Documents" },
            { path = "/Users/lee/Desktop/fire drill.pdf",
              name = "fire drill.pdf", dir = "~/Desktop" },
        }
    end,
}
AL.show()
local C = CHOOSERS[1]
check("with an index present, the launcher takes over filtering",
      type(C.qcb) == "function")
check("…and the placeholder says files joined",
      (C.placeholder or ""):find("your files", 1, true), C.placeholder)
check("empty query: every app, no file rows", #C.rows == 8, #C.rows)
C.qcb("fire")
check("typing filters apps by every-word-substring", (function()
    for _, r in ipairs(C.rows) do
        if r.kind ~= "file" and not r.text:lower():find("fire", 1, true) then
            return false, r.text
        end
    end
    return true
end)())
check("app rows come FIRST, file rows after", (function()
    local sawFile = false
    for _, r in ipairs(C.rows) do
        if r.kind == "file" then sawFile = true
        elseif sawFile then return false end
    end
    return sawFile
end)())
check("file rows are 📄-labelled with their folder", (function()
    for _, r in ipairs(C.rows) do
        if r.kind == "file" then return (r.subText or ""):find("📄", 1, true) end
    end
end)())
check("the index was asked with the query and the row cap",
      ASKED[#ASKED] and ASKED[#ASKED].q == "fire"
      and ASKED[#ASKED].limit == AL.fileRows)
local fileRow
for _, r in ipairs(C.rows) do
    if r.kind == "file" and r.text == "fire drill.pdf" then fileRow = r end
end
C.fn(fileRow)
check("⏎ on a file row OPENS it (hs.open), never launchOrFocus",
      OPENS[1] == "/Users/lee/Desktop/fire drill.pdf" and #LAUNCHES == 0,
      OPENS[1])
OPEN_RESULT["/Users/lee/Desktop/fire drill.pdf"] = false
C.fn(fileRow)
check("a file that will not open gets one honest alert",
      #ALERTS == 1 and ALERTS[1]:find("would not open", 1, true), ALERTS[1])
C.qcb("fi")
check("under 3 letters the index answers empty — apps only", (function()
    for _, r in ipairs(C.rows) do if r.kind == "file" then return false end end
    return true
end)())
_G.fileIndex.search = function() error("index exploded") end
C.qcb("fire")
check("an index that throws costs the file rows, never the picker", (function()
    local apps2 = 0
    for _, r in ipairs(C.rows or {}) do
        if r.kind ~= "file" then apps2 = apps2 + 1 end
    end
    return apps2 > 0
end)())
boot(personalMac)                     -- _G.fileIndex nil again
AL.show()
check("no index module: no callback — the chooser's native filter rules",
      CHOOSERS[1].qcb == nil)
check("…and the placeholder promises apps only",
      (CHOOSERS[1].placeholder or ""):find("apps — type", 1, true),
      CHOOSERS[1].placeholder)

-- ---- 9. the report --------------------------------------------------
out("   9. the report: counts per folder, every app listed\n")
boot(personalMac)
local r = _G.appLauncherReport()
check("report returns text", type(r) == "string")
check("headline: host and count", r:find("Test%-Mac") and r:find("8 apps"))
check("per-folder counts", r:find("/Applications%s+4") and r:find("~/Applications%s+2")
      and r:find("/System/Applications%s+2"))
check("apps listed with their folder", r:find("Gmail%s+~/Applications"))
check("…and printed, not just returned", #printed > 0)

-- =====================================================================
out(string.format("\n── test_app_launcher: %d passed, %d failed\n", pass, fail))
if fail > 0 then
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
