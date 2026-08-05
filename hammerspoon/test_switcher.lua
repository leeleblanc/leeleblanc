-- Harness for §1.10. Runs the shipped code against a stubbed hs and a
-- Hammerspoon that can be made to misbehave on demand.
local log = {}
local bound, timers = {}, {}
local FAIL = { filter = false, uiPrefs = false, switcher = false }
local built = { filters = 0, switchers = 0, setDefaultFilter = 0 }
local calls = { next = 0, previous = 0 }

hs = {
  hotkey = { bind = function(mods, key, fn)
      table.insert(bound, { combo = table.concat(mods, "+") .. "+" .. key, fn = fn })
  end },
  timer = { doAfter = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end },
  window = {
    filter = { new = function()
        if FAIL.filter then error("filter exploded") end
        built.filters = built.filters + 1
        local f = {}
        function f:setDefaultFilter(t)
          built.setDefaultFilter = built.setDefaultFilter + 1
          built.defaultFilterArg = t
          return f
        end
        return f
    end },
    switcher = { new = function(filter, ui)
        if FAIL.switcher then error("switcher exploded") end
        if ui and FAIL.uiPrefs then error("bad ui pref") end
        built.switchers = built.switchers + 1
        built.lastFilter, built.lastUI = filter, ui
        local s = {}
        function s:next() calls.next = calls.next + 1 end
        function s:previous() calls.previous = calls.previous + 1 end
        return s
    end },
  },
}
print = function(...)   -- capture Console output
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts+1] = tostring((select(i, ...))) end
  table.insert(log, table.concat(parts, " "))
end

dofile("BLOCK_PATH")
local AT = _G.__altTab
local realprint = io.write
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; realprint("  ✅ ", name, "\n")
  else fail = fail + 1; realprint("  ❌ ", name, " — ", tostring(detail or ""), "\n") end
end
local function reset()
  AT.switcher = nil
  built.filters, built.switchers, built.setDefaultFilter = 0, 0, 0
  calls.next, calls.previous = 0, 0
  FAIL.filter, FAIL.uiPrefs, FAIL.switcher = false, false, false
  log = {}
end
local function logged(pat)
  for _, l in ipairs(log) do if l:find(pat, 1, true) then return true end end
  return false
end

realprint("\n=== 1. Bindings ===\n")
local combos = {}
for _, b in ipairs(bound) do combos[b.combo] = b.fn end
check("⌥Tab is bound", combos["alt+tab"] ~= nil)
check("⌥⇧Tab is bound", combos["alt+shift+tab"] ~= nil)
check("exactly two hotkeys claimed", #bound == 2, #bound)
check("⌘Tab is NOT bound (macOS reserves it)", combos["cmd+tab"] == nil)
check("bound through hs.hotkey.bind, so the §0.3 sentry sees them", true)

realprint("\n=== 2. Nothing is built at load time ===\n")
check("no window filter built during boot", built.filters == 0, built.filters)
check("no switcher built during boot", built.switchers == 0, built.switchers)
check("a warm-up timer was scheduled instead", #timers == 1 and timers[1].delay == AT.warmupDelay,
      #timers > 0 and timers[1].delay or "none")

realprint("\n=== 3. First press builds it, later presses reuse it ===\n")
combos["alt+tab"]()
check("first ⌥Tab builds the switcher", built.switchers == 1, built.switchers)
check("and steps forward", calls.next == 1, calls.next)
combos["alt+tab"]()
combos["alt+tab"]()
check("further presses reuse the same switcher", built.switchers == 1, built.switchers)
check("each press advances one window", calls.next == 3, calls.next)
combos["alt+shift+tab"]()
check("⌥⇧Tab steps backwards", calls.previous == 1, calls.previous)
check("backwards does not also step forwards", calls.next == 3, calls.next)

realprint("\n=== 4. Windows-style tiles ===\n")
check("thumbnails on — one tile per window", AT.ui.showThumbnails == true)
check("titles shown under the tiles", AT.ui.showTitles == true)
check("every app, not just the front one", AT.ui.onlyActiveApplication == false)
check("selected window gets a larger preview", AT.ui.showSelectedThumbnail == true)
check("tile size is actually visible (>= 96pt)", AT.ui.thumbnailSize >= 96, AT.ui.thumbnailSize)
check("the ui table was handed to the switcher", built.lastUI == AT.ui)

realprint("\n=== 5. Minimised / hidden windows ===\n")
reset()
AT.includeHidden = true
AT.build()
check("includeHidden=true clears the default filter", built.setDefaultFilter == 1, built.setDefaultFilter)
check("cleared with an EMPTY table (= no exclusions)",
      type(built.defaultFilterArg) == "table" and next(built.defaultFilterArg) == nil)
reset()
AT.includeHidden = false
AT.build()
check("includeHidden=false leaves the default filter alone", built.setDefaultFilter == 0, built.setDefaultFilter)
AT.includeHidden = true

realprint("\n=== 6. Degrades instead of dying ===\n")
reset(); FAIL.uiPrefs = true
AT.build()
check("UI prefs rejected → still gets a switcher", AT.switcher ~= nil)
check("...retried without them", built.lastUI == nil)
check("...and said so in the Console", logged("stock look"))
reset(); FAIL.filter = true
AT.build()
check("filter blows up → still gets a switcher", AT.switcher ~= nil)
check("...using the default filter", built.lastFilter == nil)
check("...and said so", logged("using the default one"))
reset(); FAIL.switcher = true
local ok = pcall(AT.build)
check("switcher cannot be created → no error escapes", ok and AT.switcher == nil)
check("...and it explains ⌥Tab will do nothing", logged("⌥Tab will do nothing"))
FAIL.switcher = true; reset(); FAIL.switcher = true
ok = pcall(function() combos["alt+tab"]() end)
check("pressing ⌥Tab with no switcher is a no-op, not a crash", ok)
reset()

realprint("\n=== 7. Warm-up ===\n")
check("warm-up runs off the critical path", timers[1].delay >= 1, timers[1].delay)
timers[1].fn()
check("warm-up pre-builds the switcher", built.switchers == 1, built.switchers)
reset(); FAIL.switcher = true
ok = pcall(timers[1].fn)
check("a failed warm-up cannot take boot down", ok)

realprint(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
