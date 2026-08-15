-- Run from anywhere:  lua5.4 <this file> [path to ~/.hammerspoon]
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

-- =====================================================================
-- VOLUME — two mechanisms that must never be mistaken for each other
-- =====================================================================
-- macOS has no per-app output volume, so this module does the two things
-- that ARE possible and labels which one it just did. That label is the
-- whole safety story: a tool that sometimes moves one app and sometimes
-- moves the entire Mac, and looks identical doing both, is worse than no
-- tool. So most of this file is about the ROUTING — which path a given
-- app takes — rather than about arithmetic.
-- =====================================================================

local pass, fail = 0, 0
local function out(s) io.write(s) end
local function check(label, ok, detail)
  if ok then pass = pass + 1; out("  ✅ " .. label .. "\n")
  else
    fail = fail + 1
    out("  ❌ " .. label .. (detail ~= nil and ("  [" .. tostring(detail) .. "]") or "") .. "\n")
  end
end
local function section(s) out("\n" .. s .. "\n") end

local TMP = os.tmpname(); os.remove(TMP); os.execute("mkdir -p '" .. TMP .. "'")

-- ---- the Mac ---------------------------------------------------------
local W

local function newWorld(opts)
  opts = opts or {}
  local w = {
    front = (opts.front == nil) and "Slack" or (opts.front or nil),
    hasDevice = opts.hasDevice ~= false,
    setVolumeThrows = opts.setVolumeThrows == true,
    taskExit = opts.taskExit or 0,
    sysVolume = opts.sysVolume or 50,
    muted = false,
    alerts = {}, printed = {}, recorded = {}, tasks = {},
    watcherStarted = false, watcherFn = nil,
    setSystemCalls = 0, setMutedCalls = {},
  }

  local device = {
    outputVolume    = function() return w.sysVolume end,
    setOutputVolume = function(_, v)
      if w.setVolumeThrows then error("device is gone", 0) end
      w.sysVolume = v; w.setSystemCalls = w.setSystemCalls + 1
    end,
    outputMuted     = function() return w.muted end,
    setOutputMuted  = function(_, m) w.muted = m; w.setMutedCalls[#w.setMutedCalls + 1] = m end,
  }
  -- method-call shape: dev:outputVolume()
  local dev = setmetatable({}, { __index = function(_, k)
    local f = device[k]
    if f then return function(self, ...) return f(self, ...) end end
  end })

  local hs = {
    audiodevice = {
      defaultOutputDevice = function() return w.hasDevice and dev or nil end,
    },
    application = {
      frontmostApplication = function()
        return w.front and { name = function() return w.front end } or nil
      end,
      watcher = {
        activated = "activated",
        new = function(fn)
          w.watcherFn = fn
          return { start = function(s) w.watcherStarted = true; return s end,
                   stop  = function(s) return s end }
        end,
      },
    },
    task = {
      new = function(bin, cb, args)
        local t = { bin = bin, args = args, cb = cb }
        function t:start()
          w.tasks[#w.tasks + 1] = { bin = t.bin, args = t.args }
          -- The callback arrives later on a real Mac; run it when the
          -- test asks, so a scenario can hold a failing app open.
          w.pendingCb = function() t.cb(w.taskExit, "", "not authorised") end
          if not w.holdTask then w.pendingCb() end
          return t
        end
        return t
      end,
    },
    alert = {
      show = function(text) w.alerts[#w.alerts + 1] = tostring(text) end,
      closeAll = function() end,
    },
    chooser = { new = function(fn)
      local c = { fn = fn }
      function c:choices(r) c.rows = r; return c end
      function c:placeholderText() return c end
      function c:show() c.shown = true; return c end
      function c:isVisible() return c.shown == true end
      function c:hide() c.shown = false; return c end
      w.chooser = c
      return c
    end },
    json = {
      encode = function(t)
        local parts = {}
        for k, v in pairs(t) do parts[#parts + 1] = ('"%s":%d'):format(k, v) end
        table.sort(parts)
        return "{" .. table.concat(parts, ",") .. "}"
      end,
      decode = function(s)
        local t = {}
        for k, v in s:gmatch('"([^"]+)":(%-?%d+)') do t[k] = tonumber(v) end
        return t
      end,
    },
  }
  w.hs = hs
  return w
end

local realPrint = print

-- 🚨 A CLEAN FILE PER SCENARIO UNLESS ASKED OTHERWISE. The levels are
-- persisted, so without this every scenario inherits the last one's
-- state — which is exactly how the first run of this suite "proved" that
-- ⇪. steps by 0. Pass keep = true where persistence IS the subject.
local function load(opts)
  opts = opts or {}
  if not opts.keep then os.remove(TMP .. "/volume-TestMac.json") end
  W = newWorld(opts)
  _G.hs = W.hs
  _G.notices = { record = function(_, _, m) W.recorded[#W.recorded + 1] = tostring(m) end,
                 tell = function() end }
  _G.choosers = {}
  print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    W.printed[#W.printed + 1] = table.concat(p, " ")
  end
  local M = assert(loadfile(HS .. "/modules/volume.lua"))()
  W.provided = {}
  local vol = M.setup({
    logsDir = TMP, hostTag = "TestMac",
    hyperAddShortcut = function(mods, key, fn, src, rel, rep)
      W.keys = W.keys or {}
      W.keys[((mods and mods[1]) and "shift+" or "") .. key] = { fn = fn, repeated = rep }
    end,
    provide = function(name, fn) W.provided[name] = fn end,
    showPopup = function(c) c:show() end,
    warnWriteFailed = function(p) W.printed[#W.printed + 1] = "WRITEFAIL " .. p end,
  })
  W.M, W.vol = M, vol
  return vol
end

local function lastAlert() return W.alerts[#W.alerts] end
local function printedFinding(needle)
  for _, l in ipairs(W.printed) do if l:find(needle, 1, true) then return l end end
end

out("\n=== VOLUME ==============================================\n")

-- =====================================================================
section("1. THE ROUTING — which mechanism a given app gets")
-- =====================================================================
do
  local vol = load{ front = "Slack" }

  local ok, how = vol.apply("Slack", 30, true)
  check("an ordinary app moves the SYSTEM volume", ok and how == "system", how)
  check("...and the alert says so, with 🌐",
        (lastAlert() or ""):find("🌐", 1, true) ~= nil and
        (lastAlert() or ""):find("Slack  30%", 1, true) ~= nil, lastAlert())
  check("...and the device really moved", W.sysVolume == 30, W.sysVolume)
  check("...without spawning an AppleScript for an app that has none",
        #W.tasks == 0, #W.tasks)

  local ok2, how2 = vol.apply("Spotify", 70, true)
  check("🚨 a SCRIPTABLE app moves its OWN volume instead",
        ok2 and how2 == "app", how2)
  check("...and the alert says so, with 🎯",
        (lastAlert() or ""):find("🎯", 1, true) ~= nil and
        (lastAlert() or ""):find("Spotify  70%", 1, true) ~= nil, lastAlert())
  check("🚨 ...and the SYSTEM volume is left exactly where it was — this "
     .. "is the whole difference between the two mechanisms",
        W.sysVolume == 30, W.sysVolume)
  check("...through osascript, one task", #W.tasks == 1, #W.tasks)
end

-- =====================================================================
section("2. THE APPLESCRIPT IS ASYNC AND BOUNDED")
-- =====================================================================
-- ⏱ 6.75.0 was an entire pass about synchronous calls freezing the
-- keyboard, and a volume key is held down and repeated. A blocking
-- osascript here would be that bug, reintroduced on the fastest path in
-- the config.
do
  local vol = load{}
  vol.apply("Music", 40, false)
  local t = W.tasks[1]
  check("it is spoken through hs.task, not a blocking call",
        t ~= nil and t.bin == "/usr/bin/osascript", t and t.bin)
  local script = t and t.args and t.args[2] or ""
  check("🚨 ...and the script carries `with timeout`, or a wedged app "
     .. "inherits AppleScript's 120-second default",
        script:find("with timeout of", 1, true) ~= nil, script)
  check("...naming the app and an absolute level",
        script:find('tell application "Music"', 1, true) ~= nil
        and script:find("set sound volume to 40", 1, true) ~= nil, script)

  local src = (function()
    local f = io.open(HS .. "/modules/volume.lua", "r")
    local s = f:read("*a"); f:close(); return s
  end)()
  local code = {}
  for line in (src .. "\n"):gmatch("([^\n]*)\n") do
    code[#code + 1] = line:match("^%s*%-%-") and "" or line
  end
  check("🚨 ...and hs.osascript appears NOWHERE in the module, comments "
     .. "excluded — the guarantee is the absence, not the intention",
        table.concat(code, "\n"):find("hs.osascript", 1, true) == nil)
end

do
  -- An app that refuses. Reported, because the 🎯 label would otherwise
  -- be a claim about something that did not happen.
  local vol = load{ taskExit = 1 }
  vol.apply("Spotify", 55, true)
  check("🚨 an app that REFUSES the volume change says so",
        printedFinding("refused a volume change") ~= nil, W.printed[1])
  check("...and it reaches the notices ledger, not just the Console",
        #W.recorded > 0, #W.recorded)
end

-- =====================================================================
section("3. NO OUTPUT DEVICE — the branch that must never be silent")
-- =====================================================================
do
  local vol = load{ hasDevice = false }
  check("the system level is unknown rather than a guess",
        vol.systemLevel() == nil, tostring(vol.systemLevel()))
  local ok, how = vol.apply("Slack", 40, true)
  check("applying reports failure instead of pretending", ok == false, how)
  check("🚨 ...and SAYS so on screen — a volume key that does nothing and "
     .. "says nothing is indistinguishable from one you pressed wrong",
        (lastAlert() or ""):find("No output device", 1, true) ~= nil, lastAlert())
  check("...in the Console too", printedFinding("no usable output device") ~= nil)
  check("...and in the ledger", #W.recorded > 0)

  W.front = "Slack"
  local okN = pcall(vol.nudge, 5)
  check("🛟 and nudging in that state does not throw", okN)
end

do
  local vol = load{ setVolumeThrows = true }
  local ok = vol.apply("Slack", 40, true)
  check("🛟 a device that throws mid-set is caught, not fatal", ok == false)
end

do
  local vol = load{ front = false }
  vol.nudge(5)
  check("nothing frontmost is reported rather than guessed at",
        (lastAlert() or ""):find("Nothing is frontmost", 1, true) ~= nil, lastAlert())
end

-- =====================================================================
section("4. STEPPING, CLAMPING, UNMUTING")
-- =====================================================================
do
  local vol = load{ front = "Slack", sysVolume = 50 }
  vol.nudge(vol.config.step)
  check("⇪. steps up by the configured amount", W.sysVolume == 55, W.sysVolume)
  vol.nudge(-vol.config.step)
  check("⇪, steps back down", W.sysVolume == 50, W.sysVolume)

  for _ = 1, 30 do vol.nudge(vol.config.step) end
  check("🚨 it clamps at 100 rather than storing a number macOS rejects",
        W.sysVolume == 100 and vol.levels["Slack"] == 100, W.sysVolume)
  for _ = 1, 40 do vol.nudge(-vol.config.step) end
  check("...and at 0 on the way down", W.sysVolume == 0 and vol.levels["Slack"] == 0,
        W.sysVolume)

  W.muted = true
  vol.nudge(vol.config.step)
  check("🚨 turning it UP unmutes — otherwise you press the key eight "
     .. "times, hear nothing, and file a bug",
        W.muted == false, W.muted)

  W.muted = true
  vol.apply("Slack", 0, false)
  check("...but going to zero does not helpfully unmute you", W.muted == true)
end

-- =====================================================================
section("5. MUTE IS ALWAYS SYSTEM-WIDE, AND SAYS SO")
-- =====================================================================
do
  local vol = load{ front = "Spotify" }
  vol.toggleMute()
  check("mute toggles the device", W.muted == true)
  check("🚨 ...and is labelled 🌐 EVEN FOR A SCRIPTABLE APP, because this "
     .. "is the one place the two mechanisms do not line up",
        (lastAlert() or ""):find("🌐", 1, true) ~= nil
        and (lastAlert() or ""):find("whole Mac", 1, true) ~= nil, lastAlert())
  vol.toggleMute()
  check("...and toggles back", W.muted == false)
  check("...saying which way it went",
        (lastAlert() or ""):find("Unmuted", 1, true) ~= nil, lastAlert())
end

do
  local vol = load{ hasDevice = false }
  vol.toggleMute()
  check("mute with no device is reported, not silent",
        (lastAlert() or ""):find("No output device", 1, true) ~= nil, lastAlert())
end

-- =====================================================================
section("6. FOLLOWING THE FRONTMOST APP")
-- =====================================================================
do
  local vol = load{ front = "Slack", sysVolume = 50 }
  check("the watcher is started and HELD in _G, or it is collected and "
     .. "never fires", W.watcherStarted == true and _G.volumeWatcher ~= nil)

  vol.apply("Slack", 20, false)
  W.sysVolume = 80
  W.watcherFn("Slack", "activated")
  check("switching to a known app restores its level", W.sysVolume == 20, W.sysVolume)

  W.sysVolume = 80
  W.watcherFn("Preview", "activated")
  check("🚨 an app we have NEVER been told about is left completely "
     .. "alone — a module that reset your volume on every window switch "
     .. "would be unusable, and \"helpful\" is not a defence",
        W.sysVolume == 80, W.sysVolume)

  W.sysVolume = 80
  W.watcherFn("Slack", "deactivated")
  check("...and only activation counts", W.sysVolume == 80, W.sysVolume)

  local tasksBefore = #W.tasks
  vol.apply("Spotify", 65, false)
  W.sysVolume = 80
  W.watcherFn("Spotify", "activated")
  check("🚨 following a SCRIPTABLE app uses its own mixer, and still does "
     .. "not touch the system volume",
        W.sysVolume == 80 and #W.tasks == tasksBefore + 2,
        W.sysVolume .. "/" .. #W.tasks)
  check("...and following is silent — it is not something you asked for",
        (lastAlert() or ""):find("Spotify", 1, true) == nil, lastAlert())

  W.front = "Slack"
  local okThrow = pcall(W.watcherFn, nil, "activated")
  check("🛟 a nil app name from the watcher does not throw", okThrow)
end

-- =====================================================================
section("7. LEVELS SURVIVE A RELOAD")
-- =====================================================================
do
  local vol = load{ front = "Slack" }
  vol.apply("Slack", 35, false)
  vol.apply("Spotify", 75, false)

  local vol2 = load{ front = "Slack", keep = true }
  check("levels are read back after a reload",
        vol2.levels["Slack"] == 35 and vol2.levels["Spotify"] == 75,
        tostring(vol2.levels["Slack"]) .. "/" .. tostring(vol2.levels["Spotify"]))
  check("...from a PER-MACHINE file, since two Macs have different speakers",
        vol2.file:find("TestMac", 1, true) ~= nil, vol2.file)

  local f = io.open(vol2.file, "w"); f:write('{"Slack":9999,"Bad":-40}'); f:close()
  local vol3 = load{ keep = true }
  check("🚨 a corrupt or out-of-range file is clamped, not trusted — this "
     .. "value goes straight to a system API",
        vol3.levels["Slack"] == 100 and vol3.levels["Bad"] == 0,
        tostring(vol3.levels["Slack"]) .. "/" .. tostring(vol3.levels["Bad"]))

  os.remove(vol3.file)
  local okLoad = pcall(load, { keep = true })
  check("🛟 a missing file is a first run, not an error", okLoad)
end

-- =====================================================================
section("8. THE KEYS AND THE SERVICES")
-- =====================================================================
do
  local vol = load{ front = "Slack", sysVolume = 50 }
  check("⇪. and ⇪, are claimed", W.keys["."] ~= nil and W.keys[","] ~= nil)
  check("🚨 ...and BOTH repeat, or holding the key does nothing after the "
     .. "first press — which is how volume keys are actually used",
        type(W.keys["."].repeated) == "function"
        and type(W.keys[","].repeated) == "function")
  check("⇪⇧, mutes and ⇪⇧. opens the panel",
        W.keys["shift+,"] ~= nil and W.keys["shift+."] ~= nil)

  W.keys["."].fn()
  check("...and the up key really steps up", W.sysVolume == 55, W.sysVolume)
  W.keys["shift+."].fn()
  check("the panel opens", W.chooser ~= nil and W.chooser.shown == true)
  check("...listing the system row and the app, each with its own label",
    (function()
      local sys, app = false, false
      for _, r in ipairs(W.chooser.rows or {}) do
        if r.kind == "system" and r.text:find("🌐", 1, true) then sys = true end
        if r.kind == "app" and r.app == "Slack" then app = true end
      end
      return sys and app
    end)())
  check("...and it registers as a chooser, so Esc reaches it before the "
     .. "cheat sheet", _G.choosers.volume ~= nil)

  check("services are published for other modules",
        type(W.provided["volume.set"]) == "function"
        and type(W.provided["volume.get"]) == "function"
        and type(W.provided["volume.system"]) == "function")
  W.provided["volume.set"]("Slack", 12)
  check("...and volume.set really sets", W.sysVolume == 12, W.sysVolume)
end

-- =====================================================================
section("9. THE HOSTILE MAC — every API answers nil")
-- =====================================================================
do
  local ok = pcall(function()
    local M = assert(loadfile(HS .. "/modules/volume.lua"))()
    _G.hs = setmetatable({}, { __index = function() return
      setmetatable({}, { __index = function() return function() return nil end end }) end })
    M.setup({ logsDir = TMP, hostTag = "Nil",
              hyperAddShortcut = function() end, provide = function() end })
  end)
  check("🚨 it sets up on a Mac that answers nil to everything", ok)
end

print = realPrint
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.execute("rm -rf '" .. TMP .. "'")
os.exit(fail == 0 and 0 or 1)
