-- =====================================================================
-- test_profiles.lua — the SHIPPED profileFrom helper and the SHIPPED
-- per-machine declarations, driven in isolation
-- =====================================================================
--     lua5.4 tests/test_profiles.lua [/path/to/hammerspoon]
--
-- 🚨 WHY IT EXISTS. `profileFrom` decides which modules each Mac loads
-- and which settings each one gets, and until 6.428.0 nothing drove it.
-- The failure it can have is silent in the worst way: a profile that
-- SHARES a table with another, or with BASE, turns one machine's
-- override into both machines' — and the symptom is a work Mac quietly
-- behaving like the Air, which looks like nothing at all.
--
-- 📏 IT LIFTS THE REAL BLOCK out of init.lua rather than retyping it
-- (6.273.0): a suite that hand-builds the declarations proves only that
-- the copy in the suite is self-consistent.
--
-- 🗳 AND WHAT IT DELIBERATELY DOES NOT ASSERT, said rather than left to
-- look like an omission: nothing here requires any module to be ON or
-- OFF in any profile. A suite that demands `file_tracker.enabled =
-- false` in every profile is not testing the helper, it is choosing for
-- LL — and ⌃⌥⇧F's file history is a tool he uses, whose COST was fixed
-- in 6.229.0/6.230.0/6.241.0 rather than by switching it off. A check
-- that encodes a policy nobody asked for fails on correct code and gets
-- switched off inside a week (6.269.0).
-- =====================================================================
local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR") or "."

local pass, fail = 0, 0
local function check(label, ok, got)
    if ok then pass = pass + 1; print("  ✅ " .. label)
    else fail = fail + 1
         print("  ❌ " .. label .. (got and (" — " .. tostring(got)) or "")) end
end

local function readAll(p)
    local f = io.open(p, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

local source = readAll(HS .. "/init.lua")
check("init.lua was read", source ~= nil and #source > 10000,
      source and #source or "nil")
if not source then print("0 passed, 1 failed"); os.exit(1) end

-- ---------------------------------------------------------------- lift it
-- From the helper's own definition to the line that ends the profile
-- declarations. Everything in between needs only BASE and plain Lua.
local first = source:find("local function profileFrom(opts)", 1, true)
local last  = first and source:find("_G.moduleWarmDelay", first, true)
check("the profileFrom helper is where this suite lifts it from", first ~= nil)
check("the profile declarations end at _G.moduleWarmDelay", last ~= nil)
if not (first and last) then print(("%d passed, %d failed"):format(pass, fail + 1)); os.exit(1) end

local BASE = { "file_tracker", "pomodoro", "window_switcher" }
local env = { BASE = BASE, ipairs = ipairs, pairs = pairs, tostring = tostring }
env._G = env
local chunk, err = load(source:sub(first, last - 1) .. "\nreturn profileFrom",
                        "init.lua:profiles", "t", env)
check("the lifted block loads", chunk ~= nil, err)
if not chunk then print(("%d passed, %d failed"):format(pass, fail)); os.exit(1) end

local ok, profileFrom = pcall(chunk)
check("the lifted block runs", ok and type(profileFrom) == "function", profileFrom)
if not ok then print(("%d passed, %d failed"):format(pass, fail)); os.exit(1) end

local profiles = env.moduleProfiles
check("the shipped declarations produced a profile table",
      type(profiles) == "table")

-- --------------------------------------------------- the shipped profiles
local n = 0
for _ in pairs(profiles or {}) do n = n + 1 end
check("three profiles ship: the Air, the work Mac and the fallback", n == 3, n)
check("the fallback profile is present", (profiles or {}).default ~= nil)

local air  = (profiles or {})["Lees-MacBook-Air"]
local work = (profiles or {})["Lees-Work-MacBook"]
check("the Air has a profile", air ~= nil)
check("the work Mac has a profile", work ~= nil)

if air and work then
    -- 6.213.2, on LL's own words: "solid when I go over, about 30% when
    -- I move off". Both Macs. If an edit ever drops one, the pomodoro
    -- goes back to a default he overruled and nothing says so.
    check("the Air keeps its pomodoro opacity overrides",
          air.settings and air.settings.pomodoro
          and air.settings.pomodoro.alphaIdle == 0.30
          and air.settings.pomodoro.alphaAlert == 1)
    check("the work Mac keeps its pomodoro opacity overrides",
          work.settings and work.settings.pomodoro
          and work.settings.pomodoro.alphaIdle == 0.30
          and work.settings.pomodoro.alphaAlert == 1)
    check("the work Mac keeps its lower cross-Space window cap",
          work.settings and work.settings.window_switcher
          and work.settings.window_switcher.maxWindows == 24)

    -- 🚨 THE ONE THAT MATTERS: two machines must not share one table.
    check("the two named profiles own SEPARATE settings tables",
          air.settings ~= work.settings)
    check("one Mac's pomodoro table is not the other Mac's",
          air.settings.pomodoro ~= work.settings.pomodoro)
    -- drive it, rather than asserting identity and hoping (6.230.0)
    air.settings.pomodoro.alphaIdle = 0.99
    check("changing one Mac's override cannot reach the other",
          work.settings.pomodoro.alphaIdle == 0.30,
          work.settings.pomodoro.alphaIdle)
    air.settings.pomodoro.alphaIdle = 0.30
end

-- 📏 `default = profileFrom()` carries NO settings, on purpose: any other
-- Mac runs every module's own defaults. That is a decision, so it is
-- asserted rather than left for a later edit to change by accident.
check("the fallback profile carries no settings of its own",
      (profiles or {}).default and (profiles or {}).default.settings == nil)

-- ------------------------------------------------- the helper's own rules
local reduced = profileFrom{ without = { "pomodoro" }, plus = { "recent_docs" } }
check("`without` drops a BASE module and `plus` appends one",
      table.concat(reduced.modules, ",") == "file_tracker,window_switcher,recent_docs",
      table.concat(reduced.modules, ","))
check("BASE itself is never changed by generating a profile",
      table.concat(BASE, ",") == "file_tracker,pomodoro,window_switcher",
      table.concat(BASE, ","))
check("a generated module list is a NEW table, never BASE itself",
      reduced.modules ~= BASE)
check("two generated profiles do not share one module list",
      profileFrom().modules ~= profileFrom().modules)
check("an empty call still carries every BASE module",
      table.concat(profileFrom().modules, ",") == table.concat(BASE, ","))
check("dropping a name that is not in BASE changes nothing",
      table.concat(profileFrom{ without = { "nothing_like_this" } }.modules, ",")
      == table.concat(BASE, ","))
check("`plus` keeps the order it was given",
      table.concat(profileFrom{ plus = { "a", "b" } }.modules, ",")
      == table.concat(BASE, ",") .. ",a,b")

-- 📏 settings are passed THROUGH, by reference, and that is the shipped
-- behaviour: every declaration above hands over a fresh literal, so
-- there is nothing to share. Asserted so that a later change to copying
-- is a deliberate one with a check to update, not a silent one.
do
    local given = { pomodoro = { alphaIdle = 0.42 } }
    check("the helper hands the caller's settings table straight through",
          profileFrom{ settings = given }.settings == given)
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
