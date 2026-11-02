-- =====================================================================
-- test_app_remove.lua — 🗑 to the Trash, never erased
-- =====================================================================
-- LL: "Build App removal: trash do not erase, home folder only and
-- applicable files, delete any temp files."
--
-- This is the only tool in this config that moves files he did not name
-- one by one, so the checks are weighted the way the risk is: most of
-- them are about what it must REFUSE to touch, and the one that matters
-- most puts a forbidden path INTO a plan and requires the move to turn
-- it away — because a guard that runs when a list is assembled is not a
-- guard on what is acted on.
local HS = arg[1] or "."
local pass, fail = 0, 0
local failures = {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
        failures[#failures + 1] = label
            .. (extra ~= nil and ("  — " .. tostring(extra)) or "") end
end
local function out(s) io.write(tostring(s), "\n") end

local MOD = HS .. "/modules/app_remove.lua"
local M = assert(loadfile(MOD))()

-- =====================================================================
out("\n=== 1. THE GUARD THE WHOLE MODULE RESTS ON ===")
-- =====================================================================
local HOME  = "/Users/lee"
local ROOTS = { HOME, "/Applications" }
local function inside(p) return M.insideAllowed(p, ROOTS) end

check("a file in the home folder may be touched",
      inside(HOME .. "/Library/Caches/com.x.y") == true)
check("an app in /Applications may be touched",
      inside("/Applications/Chess.app") == true)

-- 🚨 EVERYTHING ELSE IS REFUSED, and each of these is a disk this tool
-- must never be able to reach however it is called.
check("🚫 /etc is refused", inside("/etc/passwd") == false)
check("🚫 /System is refused", inside("/System/Library/Fonts") == false)
check("🚫 /Library — the SYSTEM one — is refused (his words: home only)",
      inside("/Library/Application Support/Adobe") == false)
check("🚫 another user's folder is refused", inside("/Users/someoneelse/x") == false)
check("🚫 a relative path is refused", inside("Library/Caches/x") == false)
check("🚫 an empty path is refused", inside("") == false)
check("🚫 nil is refused", inside(nil) == false)
check("🚫 with no allowed roots at all, nothing is allowed",
      M.insideAllowed(HOME .. "/x", {}) == false)

-- 🚨 THE ROOT ITSELF IS NOT INSIDE ITSELF. Renaming /Applications or the
-- whole home folder into the Trash is not a thing any bug may ask for.
check("🚨 the home folder ITSELF can never be moved", inside(HOME) == false)
check("🚨 /Applications ITSELF can never be moved", inside("/Applications") == false)
check("🚨 …nor with a trailing slash", inside("/Applications/") == false)

-- 🚨 THE PREFIX TRAP, and it is the fixture where a substring test and a
-- component test MUST differ (6.230.0): "/Users/lee-evil" starts with
-- "/Users/lee" and belongs to somebody else. 6.320.0 found the mirror of
-- this in the vault, where a `..` SUBSTRING refused an ordinary note.
check("🚨 a folder whose name merely STARTS with the home folder is refused",
      inside("/Users/lee-evil/Documents") == false)
check("🚨 …and so is one that only shares a prefix with /Applications",
      inside("/ApplicationsOld/Chess.app") == false)

-- a path that can climb out, however it reads
check("🚫 a `..` component is refused",
      inside(HOME .. "/Library/../../etc/passwd") == false)
check("…and an ordinary name with two dots in it is NOT refused — that is",
      inside(HOME .. "/Library/Caches/Budget..final") == true)

-- =====================================================================
out("\n=== 2. WHAT IT LOOKS FOR, AND WHAT IT CALLS A GUESS ===")
-- =====================================================================
local plan = M.leftoverPlan(HOME, "com.vendor.Thing", "Thing")
local byPath = {}
for _, e in ipairs(plan) do byPath[e.path] = e end
-- 🚨 A HELPER THAT ANSWERS FALSELY, NEVER ONE THAT INDEXES A NIL
-- (6.186.0). A mutation that stops the bundle-id rows being added leaves
-- these lookups nil, and `.sure` on nil ENDS THE RUN with "0 failed"
-- never printed — which in a gate that reads the tail looks like a pass.
-- It did, on the first sweep of this release.
-- 🔬 AND IT IS A BRANCH, NOT AN `and/or` CHAIN. `(type(e)=="table")
-- and e[k] or nil` CANNOT CARRY A FALSE VALUE — `true and false or nil`
-- is nil — so the row whose `sure` is FALSE, which is the whole point of
-- this section, read as "not there". 6.303.0's rule, written down by
-- this project and re-broken here one release later; the check it exists
-- for failed against correct code.
local function field(path, k)
    local e = byPath[path]
    if type(e) ~= "table" then return nil end
    return e[k]
end

check("it looks under the bundle id for preferences",
      byPath[HOME .. "/Library/Preferences/com.vendor.Thing.plist"] ~= nil)
check("…caches", byPath[HOME .. "/Library/Caches/com.vendor.Thing"] ~= nil)
check("…containers", byPath[HOME .. "/Library/Containers/com.vendor.Thing"] ~= nil)
check("…saved application state",
      byPath[HOME .. "/Library/Saved Application State/com.vendor.Thing.savedState"] ~= nil)
check("…and the login item it may have installed",
      byPath[HOME .. "/Library/LaunchAgents/com.vendor.Thing.plist"] ~= nil)

-- 🚨 EVERY ROW IS INSIDE THE HOME FOLDER. His instruction, asserted
-- against the whole plan rather than trusted row by row.
local allHome = true
for _, e in ipairs(plan) do
    if not M.insideAllowed(e.path, { HOME }) then allHome = false end
end
check("🚨 every leftover it would look for is inside the home folder", allHome)

-- a bundle-id row is an ANSWER; a name row is a GUESS, and says so
check("a bundle-id match is not marked as a guess",
      field(HOME .. "/Library/Caches/com.vendor.Thing", "sure") == true)
check("⚠️ a NAME match IS marked as a guess — another app's folder can be"
      .. " called the same thing",
      field(HOME .. "/Library/Logs/Thing", "sure") == false)
check("…and the row says which rule found it",
      tostring(field(HOME .. "/Library/Logs/Thing", "why")):find("NAME", 1, true) ~= nil,
      field(HOME .. "/Library/Logs/Thing", "why"))

-- 🚨 REACHED BY BOTH RULES → IT IS AN ANSWER, NOT A GUESS. Drawing a
-- certain row with a ⚠️ teaches him to ignore the ⚠️, which is the only
-- thing standing between him and a wrong folder (6.269.0).
local both = M.leftoverPlan(HOME, "Thing", "Thing")
local sup = nil
for _, e in ipairs(both) do
    if e.path == HOME .. "/Library/Application Support/Thing" then sup = e end
end
check("a path both rules reach is listed ONCE", (function()
          local n = 0
          for _, e in ipairs(both) do
              if e.path == HOME .. "/Library/Application Support/Thing" then n = n + 1 end
          end
          return n == 1
      end)())
check("…and kept as the SURER of the two", sup and sup.sure == true)
-- 🚨 AND THE INVARIANT THAT MAKES "first wins" CORRECT: every bundle-id
-- row is added BEFORE every name row. A "keep the surer one" branch was
-- written for this and taken out again — with the order below it could
-- never run, so nothing could fail it (6.199.0). This check CAN fail,
-- and it is what a reordering breaks.
check("🚨 every bundle-id row comes before every NAME row", (function()
          local seenGuess = false
          for _, e in ipairs(both) do
              if not e.sure then seenGuess = true
              elseif seenGuess then return false end
          end
          return true
      end)())

-- no bundle id at all → name rows only, every one of them a guess
local nameOnly = M.leftoverPlan(HOME, nil, "Thing")
local anySure = false
for _, e in ipairs(nameOnly) do if e.sure then anySure = true end end
check("with no bundle id every row is a guess", #nameOnly > 0 and not anySure)
check("no home folder → it looks nowhere at all",
      #M.leftoverPlan("", "com.x.y", "Thing") == 0)
check("no app and no bundle id → nothing", #M.leftoverPlan(HOME, nil, nil) == 0)

-- =====================================================================
out("\n=== 3. THE TRASH NAME, AND THE COLLISION THAT WOULD UNDO IT ===")
-- =====================================================================
local n1 = M.trashNameFor("/Users/lee/Library/Caches/Thing", 1790000000, {})
check("the trash name keeps the file's own name", n1:find("Thing", 1, true) == 1, n1)
check("…and stamps it, so two removals of one app are told apart",
      n1:find("2026") ~= nil, n1)

-- 🚨 TWO ITEMS WITH THE SAME NAME IN THE SAME SECOND. The stamp has
-- second resolution, so without a tie-break the SECOND rename lands on
-- the first and makes it unrecoverable through the very folder that
-- exists to make it recoverable (6.321.0, found in the vault's bin).
local taken = { [n1] = true }
local n2 = M.trashNameFor("/Users/lee/Library/Logs/Thing", 1790000000, taken)
check("🚨 a second item of the same name in the same second does NOT collide",
      n2 ~= n1, n1 .. " vs " .. n2)
taken[n2] = true
local n3 = M.trashNameFor("/Users/lee/Library/Caches/Thing", 1790000000, taken)
check("…and a third is different again", n3 ~= n1 and n3 ~= n2, n3)

-- =====================================================================
out("\n=== 4. MAY IT GO? FOUR ANSWERS, NOT TWO ===")
-- =====================================================================
local ok, why = M.goVerdict(nil)
check("nothing listed yet → no, and it says to list first",
      ok == false and why:find("listed", 1, true) ~= nil, why)
ok, why = M.goVerdict({ app = "/Applications/X.app", name = "X",
                        running = true, count = 3 })
check("🚨 a RUNNING app → no, and it names the app",
      ok == false and why:find("X", 1, true) ~= nil, why)
ok, why = M.goVerdict({ app = "/Applications/X.app", name = "X",
                        running = false, count = 0 })
check("nothing to move → no, and that is a different sentence",
      ok == false and why:find("nothing to move", 1, true) ~= nil, why)
ok = M.goVerdict({ app = "/Applications/X.app", name = "X", running = false,
                   count = 3, items = { { kind = "caches" }, { kind = "prefs" } },
                   keep = {} })
check("a quit app with rows selected → yes", ok == true)

-- 🗳 6.388.0 — AND A FIFTH ANSWER, because he can now keep every row:
-- "you have kept all of them" is his decision and "the folder is empty"
-- is a fact about the disk. One sentence for both would read as a fault.
ok, why = M.goVerdict({ app = "/Applications/X.app", name = "X", running = false,
                        count = 2, items = { { kind = "caches" }, { kind = "prefs" } },
                        keep = { true, true } })
check("every row kept → no, and it is NOT the 'nothing to move' sentence",
      ok == false and why:find("marked KEEP", 1, true) ~= nil
      and why:find("nothing to move", 1, true) == nil, why)

-- =====================================================================
out("\n=== 5. SIZES IN WORDS ===")
-- =====================================================================
check("bytes", M.prettySize(512) == "512 B", M.prettySize(512))
check("kilobytes", M.prettySize(2048) == "2 KB", M.prettySize(2048))
check("megabytes", M.prettySize(5 * 1024 * 1024) == "5.0 MB", M.prettySize(5*1024*1024))
check("gigabytes", M.prettySize(3 * 1024^3) == "3.0 GB", M.prettySize(3*1024^3))
check("nothing is not a crash", M.prettySize(nil) == "0 B")

-- =====================================================================
out("\n=== 6. THE MOVE ITSELF — against a disk that can refuse ===")
-- =====================================================================
-- A virtual filesystem. 🔬 It can REFUSE a rename the way a real one
-- does (a locked file, a different volume) rather than always saying
-- yes, or the failure path could not be driven at all (6.290.0).
local FS, RENAMES, REFUSE = {}, {}, {}
local realRename = os.rename
os.rename = function(a, b)
    RENAMES[#RENAMES + 1] = { from = a, to = b }
    if REFUSE[a] then return nil, "the move was refused" end
    if FS[a] == nil then return nil, "no such file" end
    FS[b], FS[a] = FS[a], nil
    return true
end

local DEGRADED, COPYREFUSE = {}, false
local TASKS, BELTS = {}, {}
local TASKREFUSE, TASKNIL, TIMERNIL = false, false, false
local BELTREFUSESTOP = false
local SHOWN, POPUPREFUSE = {}, false
local core = {
    homeDir = HOME,
    hyperAddShortcut = function() end,
    -- 🔬 THE REAL showPopup SHOWS the picker and answers true/false; it
    -- does NOT hand the chooser back. A stub that returned the chooser
    -- let this module's picker ship calling `:choices()` on a BOOLEAN —
    -- 6.290.0, caught by reading init.lua rather than by any check here.
    -- It can refuse, too, because macOS can (6.265.0).
    showPopup = function(c)
        if POPUPREFUSE then return false end
        SHOWN[#SHOWN + 1] = c
        return true
    end,
    degrade = function(tool, w) DEGRADED[#DEGRADED + 1] = tostring(tool) .. ": " .. tostring(w) end,
    -- 🔬 IT CAN REFUSE, as macOS can — setContents answers false and
    -- never throws, and test_stub_fidelity fails the gate for a stub
    -- that cannot say no (6.290.0's ratchet, which caught this one).
    copyText = function(t)
        if COPYREFUSE then return false, "macOS refused the write" end
        return true
    end,
}

_G.choosers = {}
_G.hs = {
    fs = {
        -- 🔬 macOS ANSWERS A MODIFICATION TIME, and 6.389.0's verdict
        -- reads it: a stub without one makes every orphan row say "nothing
        -- could be read about when it was last used" and the age branches
        -- are unreachable from the gate (6.290.0).
        attributes = function(p) local e = FS[p]
            if not e then return nil end
            return { mode = e.dir and "directory" or "file", size = e.size or 0,
                     modification = e.mtime } end,
        dir = function(p)
            local names = {}
            for k in pairs(FS) do
                local rest = k:sub(#p + 2)
                if k:sub(1, #p + 1) == p .. "/" and rest ~= "" and not rest:find("/") then
                    names[#names + 1] = rest
                end
            end
            local i = 0
            return function() i = i + 1 ; return names[i] end
        end,
        mkdir = function(p) FS[p] = { dir = true } ; return true end,
    },
    application = {
        infoForBundlePath = function(p)
            local e = FS[p] ; return e and e.bundle and { CFBundleIdentifier = e.bundle } or nil
        end,
        runningApplications = function()
            local l = {}
            for _, n in ipairs(FS.__running or {}) do
                l[#l + 1] = { name = function() return n end,
                              bundleID = function() return nil end }
            end
            return l
        end,
    },
    alert = { show = function() end },
    -- 🔬 hs.task:start() REFUSES BY RETURNING FALSE and never throws
    -- (6.304.0, read in libtask.m), so the stub can say no; and the
    -- callback is held rather than fired, so a test decides WHEN the
    -- search answers and the belt can win the race.
    task = { new = function(bin, cb, args)
        TASKS[#TASKS + 1] = { bin = bin, cb = cb, args = args }
        local t = TASKS[#TASKS]
        function t:start()
            if TASKREFUSE then return false end
            self.started = true ; return true
        end
        function t:terminate() self.killed = true ; return true end
        if TASKNIL then TASKS[#TASKS] = nil ; return nil end
        return t
    end },
    timer = { doAfter = function(secs, fn)
        if TIMERNIL then return nil end
        BELTS[#BELTS + 1] = { secs = secs, raw = fn }
        local b = BELTS[#BELTS]
        -- 🔬 A STOPPED TIMER DOES NOT FIRE, and the stub has to refuse in
        -- THAT direction too (6.304.0 — a stub models the provider's
        -- refusals both ways) or a check can drive something macOS never
        -- does. The one honest exception is a stop macOS REFUSED: the
        -- module pcalls `:stop()` and swallows a throw, so that belt is
        -- still armed. BELTREFUSESTOP is that Mac, and it is the only way
        -- to reach the belt-after-the-answer order.
        function b.fn(...) if b.stopped then return end ; return b.raw(...) end
        function b:stop()
            if BELTREFUSESTOP then error("macOS refused to stop the timer", 0) end
            self.stopped = true ; return self
        end
        return b
    end },
    chooser = { new = function(cb)
        local c = { cb = cb }
        function c:choices(x) self.rows_ = x ; return c end
        function c:placeholderText(p) self.ph = p ; return c end
        function c:show() self.shown = true ; return c end
        return c
    end },
}
local PRINTED = {}
local realPrint = print
print = function(...) local t = {}
    for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(t, " ") end

M.setup(core)
local ar = M.ar
print = realPrint

local function freshDisk()
    FS = {
        ["/Applications"] = { dir = true },
        ["/Applications/Thing.app"] = { dir = true, size = 100, bundle = "com.vendor.Thing" },
        [HOME] = { dir = true },
        [HOME .. "/.Trash"] = { dir = true },
        [HOME .. "/Library/Caches/com.vendor.Thing"] = { dir = true, size = 2048 },
        [HOME .. "/Library/Preferences/com.vendor.Thing.plist"] = { size = 512 },
        [HOME .. "/Library/Logs/Thing"] = { dir = true, size = 10 },
        __running = {},
    }
    RENAMES, REFUSE, DEGRADED = {}, {}, {}
    ar.plan = nil
    ar.moved = { runs = 0, items = 0, bytes = 0, last = nil, fails = 0, why = nil }
end

freshDisk()
local p, lwhy = ar.list("Thing")
check("it finds the app and its leftovers", p ~= nil and p.count == 4,
      p and p.count or lwhy)
check("…and reads the bundle id off the app itself",
      p and p.bundleId == "com.vendor.Thing", p and p.bundleId)
check("…counting the ones that are only a NAME guess", p and p.guesses == 1, p and p.guesses)

-- 🚨 THE FIRST PRESS MOVES NOTHING. The list IS the feature.
check("🚨 LISTING MOVES NOTHING — not one rename", #RENAMES == 0, #RENAMES)
check("…and every file is still exactly where it was",
      FS["/Applications/Thing.app"] ~= nil
      and FS[HOME .. "/Library/Caches/com.vendor.Thing"] ~= nil)

-- 🗳 6.388.0 CHANGED WHAT THE SECOND PRESS MOVES, and this is the check
-- that states it rather than a count from before the change (6.248.0).
-- Three of these four rows are safe and start selected; the fourth —
-- ~/Library/Logs/Thing — was found by NAME rather than by the bundle id,
-- so it is ⚠️ careful and starts KEPT. It must survive the move.
local okG, res = ar.go()
check("the second press moves the SELECTED rows", okG == true and res.moved == 3,
      okG and res.moved or tostring(res))
check("🚨 …and the row matched only by NAME is still on disk",
      FS[HOME .. "/Library/Logs/Thing"] ~= nil)
check("…and the report counts it as kept FOR him, not by him",
      res.keptCareful == 1 and res.keptSafe == 0,
      tostring(res.keptCareful) .. "/" .. tostring(res.keptSafe))
check("…into ~/.Trash and nowhere else", (function()
          for _, r in ipairs(RENAMES) do
              if r.to:sub(1, #(HOME .. "/.Trash/")) ~= HOME .. "/.Trash/" then return false end
          end
          return #RENAMES == 3
      end)(), #RENAMES)
check("…and the app really is gone from /Applications",
      FS["/Applications/Thing.app"] == nil)
check("…and is sitting in the Trash, not erased", (function()
          for k in pairs(FS) do
              if k:find(HOME .. "/.Trash/Thing.app", 1, true) == 1 then return true end
          end
          return false
      end)())

-- 🗳 AND HE CAN TAKE IT ANYWAY — that is the other half of the ask. One
-- call selects every row, including the risky one, and then all four go.
freshDisk()
ar.list("Thing")
ar.keepNone()
local okAll, resAll = ar.go()
check("selecting everything moves all four", okAll == true and resAll.moved == 4,
      okAll and resAll.moved or tostring(resAll))
check("…and nothing is reported as kept", resAll.keptCareful == 0 and resAll.keptSafe == 0)

freshDisk()
ar.list("Thing")
ar.go()
-- 🚨 THE PLAN IS SPENT. A second confirmation must not try to move paths
-- that are already in the Trash, and a stale plan is how a later press
-- acts on a listing he has forgotten making.
local again, aWhy = ar.go()
check("🚨 a second confirmation does nothing — the plan is spent",
      again == false and aWhy:find("listed", 1, true) ~= nil, tostring(aWhy))

-- a running app is refused, and nothing moves
freshDisk()
FS.__running = { "Thing" }
ar.list("Thing")
local rOK, rWhy = ar.go()
check("🚨 a RUNNING app is refused", rOK == false, tostring(rWhy))
check("…and NOTHING was renamed", #RENAMES == 0, #RENAMES)

-- an app that is not there
freshDisk()
local miss, mWhy = ar.list("NoSuchApp")
check("an app that is not installed says so rather than guessing",
      miss == nil and mWhy:find("NoSuchApp", 1, true) ~= nil, tostring(mWhy))

-- =====================================================================
out("\n=== 7. 🚨 THE ONE THAT MATTERS MOST ===")
-- =====================================================================
-- A forbidden path is put INTO the plan by hand, the way a bug in the
-- listing would. The MOVE has to turn it away: a guard that runs when a
-- list is assembled is not a guard on what is acted on, and this is the
-- only line between a wrong path and his disk.
freshDisk()
FS["/etc/passwd"] = { size = 1 }
FS["/Library/Application Support/Adobe"] = { dir = true, size = 1 }
ar.list("Thing")
table.insert(ar.plan.items, { path = "/etc/passwd", why = "injected", sure = true, size = 1 })
table.insert(ar.plan.items, { path = "/Library/Application Support/Adobe",
                              why = "injected", sure = true, size = 1 })
table.insert(ar.plan.items, { path = "/Users/lee-evil/Documents",
                              why = "injected", sure = true, size = 1 })
ar.plan.count = #ar.plan.items
-- 🗳 SELECT EVERY ROW, deliberately: this section is about the guard on
-- the move, not about which rows 6.388.0 selects by default. Leaving the
-- default in would couple the one check that stands between a wrong path
-- and his disk to a number that moves whenever a risk verdict does.
ar.keepNone()
local gOK, gRes = ar.go()
check("the legitimate items still moved", gOK == true and gRes.moved == 4, gRes and gRes.moved)
check("🚨 /etc/passwd was REFUSED", FS["/etc/passwd"] ~= nil)
check("🚨 the system /Library folder was REFUSED",
      FS["/Library/Application Support/Adobe"] ~= nil)
check("🚨 the prefix-trap path was REFUSED", (function()
          for _, r in ipairs(RENAMES) do
              if r.from:find("lee%-evil") then return false end
          end
          return true
      end)())
check("…and no rename was even ATTEMPTED on any of the three",
      #RENAMES == 4, #RENAMES)
check("…they are counted as failed, not quietly dropped", gRes.failed == 3, gRes.failed)
check("🔔 …and he is TOLD, rather than reading about it in a log",
      #DEGRADED > 0, #DEGRADED)

-- a disk that refuses a legitimate move is reported too
freshDisk()
ar.list("Thing")
REFUSE[HOME .. "/Library/Caches/com.vendor.Thing"] = true
ar.keepNone()
local fOK, fRes = ar.go()
check("a refused rename is counted, not announced as moved",
      fOK == true and fRes.moved == 3 and fRes.failed == 1,
      tostring(fRes and fRes.moved) .. "/" .. tostring(fRes and fRes.failed))
check("…and the file is still there", FS[HOME .. "/Library/Caches/com.vendor.Thing"] ~= nil)
check("🔔 …and it takes the door", #DEGRADED > 0, #DEGRADED)

-- =====================================================================
out("\n=== 7b. THE PICKER ITSELF — the path nothing was driving ===")
-- =====================================================================
-- 🚨 THIS SECTION EXISTS BECAUSE A REAL BUG SHIPPED WITHOUT IT. The
-- module called `core.showPopup(hs.chooser.new(...))` and then
-- `:choices()` on what came back — but showPopup SHOWS the picker and
-- answers true/false; it does not hand the chooser back. The harness's
-- stub returned the chooser, so the whole picker path was certified by
-- a stub gentler than init.lua (6.290.0, thirteenth time). Nothing here
-- drove ar.show() at all, which is why no check could fail.
freshDisk()
SHOWN, POPUPREFUSE = {}, false
local sOK = ar.show()
check("the picker opens", sOK == true, tostring(sOK))
check("…and it was PLACED through core.showPopup, never a bare :show()",
      #SHOWN == 1, #SHOWN)
-- 🚨 ANSWER FALSELY, NEVER INDEX A NIL (6.186.0). A mutation that
-- stops the picker being shown leaves SHOWN empty, and `ch.rows_` then
-- ENDS THE RUN with "0 failed" never printed — a pass, to a gate that
-- reads the tail. It did, on this release's sweep.
local ch = SHOWN[1] or { rows_ = {}, cb = function() end }
check("…with its rows already in it before it was shown",
      type(ch.rows_) == "table" and #ch.rows_ > 0, type(ch.rows_))
check("…listing the apps it found", (function()
          for _, r in ipairs(ch.rows_ or {}) do
              if r.app == "Thing" then return true end
          end
          return false
      end)())
check("…and every app row says the first press moves nothing", (function()
          for _, r in ipairs(ch.rows_ or {}) do
              if r.app and not tostring(r.subText):find("nothing moves", 1, true) then
                  return false
              end
          end
          return true
      end)())
check("…and it is filed in _G.choosers so Esc closes it first",
      _G.choosers.appRemove ~= nil)

-- picking an app LISTS it and still moves nothing
ch.cb({ app = "Thing" })
check("picking an app builds a plan", ar.plan ~= nil and ar.plan.name == "Thing")
check("🚨 …and STILL moves nothing", #RENAMES == 0, #RENAMES)

-- now the confirmation row is offered first
SHOWN = {}
ar.show()
local ch2 = SHOWN[1] or { rows_ = {}, cb = function() end }
local function row1(k)
    local r = ch2.rows_[1]
    if type(r) ~= "table" then return nil end
    return r[k]
end
check("with a plan in hand the picker offers the confirmation FIRST",
      row1("go") == true, row1("text"))
check("…and it says how many rows are SELECTED, not how many were found",
      tostring(row1("text")):find("3 selected row", 1, true) ~= nil, row1("text"))
check("…and says what it is about to move, in words",
      tostring(row1("text")):find("Thing", 1, true) ~= nil
      and tostring(row1("text")):find("Trash", 1, true) ~= nil, row1("text"))
check("…and says it is undoable",
      tostring(row1("subText")):find("Put Back", 1, true) ~= nil, row1("subText"))
-- 🔁 6.388.0 — EVERY FILE IS A ROW HE CAN PRESS ⏎ ON, which is what
-- "the option to leave files" means at the keyboard rather than in a
-- settings line.
check("…and every leftover is its own row", (function()
          local n = 0
          for _, r in ipairs(ch2.rows_ or {}) do if r.toggle then n = n + 1 end end
          return n == 4
      end)(), #(ch2.rows_ or {}))
check("…each saying whether it is safe and why", (function()
          for _, r in ipairs(ch2.rows_ or {}) do
              if r.toggle and not (tostring(r.subText):find("safe", 1, true)
                                   or tostring(r.subText):find("careful", 1, true)) then
                  return false
              end
          end
          return true
      end)())
check("…and whether ⏎ would move it or keep it", (function()
          for _, r in ipairs(ch2.rows_ or {}) do
              if r.toggle and not (tostring(r.text):find("[ MOVE ]", 1, true)
                                   or tostring(r.text):find("[ keep ]", 1, true)) then
                  return false
              end
          end
          return true
      end)())
check("…and the three bulk rows are offered", (function()
          local seen = {}
          for _, r in ipairs(ch2.rows_ or {}) do if r.bulk then seen[r.bulk] = true end end
          return seen.all and seen.none and seen["default"]
      end)())
check("…and a way back to the app list that moves nothing", (function()
          for _, r in ipairs(ch2.rows_ or {}) do if r.back then return true end end
          return false
      end)())
if type(ch2.rows_[1]) == "table" then ch2.cb(ch2.rows_[1]) end
check("…and choosing the confirmation moves the selected rows",
      #RENAMES == 3, #RENAMES)

-- 🧊 A REFUSED SHOW IS NOT RECORDED AS AN OPEN PICKER (6.265.0 · 6.326.0)
freshDisk()
SHOWN, POPUPREFUSE = {}, true
_G.choosers.appRemove = nil
local rOK2, rWhy2 = ar.show()
check("🧊 a picker macOS refuses answers false", rOK2 == false, tostring(rOK2))
check("…and is NOT left recorded as open", _G.choosers.appRemove == nil)
check("🔔 …and he is told", #DEGRADED > 0, #DEGRADED)
POPUPREFUSE = false

-- =====================================================================
out("\n=== 9. 6.388.0 — IS IT DAMAGING, AND MAY I LEAVE THAT ONE? ===")
-- =====================================================================
-- LL: "it should say, if it is damaging or not, it should give me the
-- option to leave files, so it should be a very iterative process …
-- the ultimate outcome is a solid analysis of what can be removed. And
-- then give me an option for what to remove safely."

-- ---- the verdict is read off WHAT THE THING IS ----------------------
local function verdictOf(k, extra)
    local e = { kind = k, sure = true }
    if extra then for a, b in pairs(extra) do e[a] = b end end
    return M.riskOf(e)
end
check("the app itself is safe — it is re-downloadable", verdictOf("app") == "safe")
check("a cache is safe", verdictOf("caches") == "safe")
check("its settings are safe — losing them is the point", verdictOf("prefs") == "safe")
check("saved window state is safe", verdictOf("savedstate") == "safe")
check("cookies are safe", verdictOf("cookies") == "safe")
check("what starts it at login is safe", verdictOf("launchagents") == "safe")

-- 🚨 THE THREE THAT CAN TAKE HIS OWN FILES WITH THEM. These are the
-- reason the question needed answering at all.
check("🚨 a sandboxed app's CONTAINER is careful — its Documents live in it",
      verdictOf("containers") == "careful")
check("🚨 Application Support is careful — apps keep his data there too",
      verdictOf("appsupport") == "careful")
check("🚨 a GROUP container is careful — it is shared with the vendor's other apps",
      verdictOf("groupcontainers") == "careful")
local _, gcWhy = verdictOf("groupcontainers")
check("…and the reason says it could break an app he still has",
      gcWhy:find("still have", 1, true) ~= nil, gcWhy)

-- 🚨 AND A KIND NOBODY TAUGHT IT FAILS CLOSED. An unknown row is the
-- shape a future leftover arrives in, and guessing "safe" there is the
-- one wrong default (6.276.0 — an unverifiable promise fails closed).
local uv, uw = verdictOf("something_new")
check("🚨 an unknown kind is CAREFUL, never safe", uv == "careful", uv)
check("…and says plainly that it does not know",
      uw:find("does not know", 1, true) ~= nil, uw)
check("🚨 a row with no kind at all is careful", M.riskOf({ sure = true }) == "careful")
check("🚨 …and so is something that is not a row", M.riskOf(nil) == "careful")

-- 🚨 A GUESS IS NEVER SAFE, WHATEVER IT IS A GUESS ABOUT. This is the
-- fixture where the kind and the matching rule disagree, which is the
-- only input where "read the kind" and "read both" must differ (6.230.0).
local nv, nw = M.riskOf({ kind = "caches", sure = false })
check("🚨 a cache matched by NAME is careful, though a cache is safe",
      nv == "careful", nv)
check("…and the reason names the guess BEFORE the kind",
      nw:find("NAME", 1, true) ~= nil
      and nw:find("NAME", 1, true) < (nw:find("cache", 1, true) or 1e9), nw)

-- 🚨 AND THE EVIDENCE OUTRANKS THE LABEL. A folder that demonstrably
-- holds twelve of his files is not a maybe, and the number is what he
-- can act on (6.229.0's yield line, in a verdict).
local ov, ow = M.riskOf({ kind = "caches", sure = true, ownFiles = 12 })
check("🚨 a row holding his own files is careful whatever its kind",
      ov == "careful", ov)
check("…and SAYS HOW MANY rather than warning in the abstract",
      ow:find("12 FILE", 1, true) ~= nil, ow)
check("zero files found does not make a safe row careful",
      M.riskOf({ kind = "caches", sure = true, ownFiles = 0 }) == "safe")

-- ---- how many of his files are in there ----------------------------
local DIRS = {
    ["/c/Data/Documents"] = { "a.pages", "b.pages", "c.pages" },
    ["/c/Documents"]      = { ".", "..", "d.txt" },
}
local function lister(d)
    local v = DIRS[d]
    if not v then error("no such directory") end
    return v
end
local n, capped = M.ownDataIn("/c", lister, 50)
check("it counts his documents inside a container", n == 4, n)
check("…and does not count . and ..", n == 4, n)
check("…and says it did not stop early", capped == false)
check("a folder with none answers zero, not a crash",
      select(1, M.ownDataIn("/nothing", lister, 50)) == 0)
check("no lister at all answers zero rather than guessing",
      select(1, M.ownDataIn("/c", nil, 50)) == 0)
-- 🧪 THE TEST PCALLS ITS OWN CALL (6.186.0). Without the guard inside
-- ownDataIn this raises, and a raise inside a check's expression ends the
-- run with "0 failed" never printed — a PASS, to a gate that reads the
-- tail. A test helper answers falsely; it does not die.
local tOK2, tN2 = pcall(M.ownDataIn, "/c", function() error("refused") end, 50)
check("🔔 a lister that THROWS answers zero rather than taking the run with it",
      tOK2 == true and tN2 == 0, tostring(tOK2) .. "/" .. tostring(tN2))

-- 📏 THE BOUND IS A STATE, NOT A FOOTNOTE (6.197.2). Counting is a
-- directory read on the main thread, so it stops — and a count taken
-- under a bound is a FLOOR, which the row has to say.
local n2, capped2 = M.ownDataIn("/c", lister, 2)
check("📏 it stops at the bound", n2 == 2, n2)
check("📏 …and SAYS it stopped, so the number reads as 'or more'", capped2 == true)

-- 🚨 AND THE CALL SITE IS DRIVEN, not just the function. The sweep found
-- this: every check above proves M.ownDataIn, and deleting the WALK in
-- ar.list passed all of them, because the fixture's container does not
-- exist on the virtual disk so the walk never ran with an answer in it.
-- Proving a pure function is not proving that anything calls it with the
-- values that matter (6.273.0).
freshDisk()
FS[HOME .. "/Library/Containers/com.vendor.Thing"] = { dir = true, size = 4096 }
FS[HOME .. "/Library/Containers/com.vendor.Thing/Data"] = { dir = true }
FS[HOME .. "/Library/Containers/com.vendor.Thing/Data/Documents"] = { dir = true }
for _, n in ipairs({ "letter.pages", "tax.numbers", "notes.txt" }) do
    FS[HOME .. "/Library/Containers/com.vendor.Thing/Data/Documents/" .. n] = { size = 9 }
end
local cp = ar.list("Thing")
local crow
for _, it in ipairs(cp.items) do
    if it.path == HOME .. "/Library/Containers/com.vendor.Thing" then crow = it end
end
check("the container is on the list", crow ~= nil)
check("🚨 …and ar.list really WALKED it", crow and crow.ownFiles == 3,
      crow and tostring(crow.ownFiles))
check("…so the row's own reason carries the NUMBER, not a maybe",
      crow and tostring(crow.risk):find("3 FILE", 1, true) ~= nil, crow and crow.risk)
check("…and it is careful, so it starts kept", crow and crow.verdict == "careful")
check("🚨 …and a press does NOT take his documents", (function()
          ar.go()
          return FS[HOME .. "/Library/Containers/com.vendor.Thing"] ~= nil
      end)())
-- 📏 and a row that CANNOT hold his files is not walked at all, which is
-- what keeps this to two directory reads rather than one per row
freshDisk()
local pp = ar.list("Thing")
for _, it in ipairs(pp.items) do
    if it.kind == "prefs" or it.kind == "caches" then
        check("📏 a " .. it.kind .. " row is not walked for documents",
              it.ownFiles == nil, tostring(it.ownFiles))
    end
end

-- ---- which rows start selected -------------------------------------
-- 🔑 THE DIRECTION IS THE WHOLE SAFETY OF THE RELEASE (6.319.0), and
-- 6.384.0 made the other choice, so this is the check that would catch a
-- revert to it.
local ITEMS = {
    { kind = "app",        sure = true },               -- 1 safe
    { kind = "caches",     sure = true },               -- 2 safe
    { kind = "containers", sure = true },               -- 3 careful
    { kind = "logs",       sure = false },              -- 4 careful: a NAME guess
}
local K = M.defaultKeep(ITEMS)
check("✅ a safe row starts SELECTED for removal", K[1] == nil and K[2] == nil)
check("🚨 a risky row starts KEPT — he opts in", K[3] == true)
check("🚨 …and so does a row that is only a name guess", K[4] == true)
check("🚨 NOTHING risky is selected by default", (function()
          for i, it in ipairs(ITEMS) do
              if M.riskOf(it) ~= "safe" and not K[i] then return false end
          end
          return true
      end)())

-- ---- what would actually move --------------------------------------
local mv, mb, ks, kc = M.selectedItems(
    { { kind = "app", sure = true, size = 100 },
      { kind = "caches", sure = true, size = 50 },
      { kind = "containers", sure = true, size = 9 } },
    { [2] = true, [3] = true })
check("only the unkept rows move", #mv == 1 and mv[1].kind == "app", #mv)
check("…and the size is the size of THOSE rows", mb == 100, mb)
check("🔎 a row HE kept is counted apart from one kept FOR him",
      ks == 1 and kc == 1, tostring(ks) .. "/" .. tostring(kc))
check("…and summing them would hide his own decision", ks + kc == 2)
check("with no keep table at all everything moves",
      #(M.selectedItems({ { kind = "app" }, { kind = "app" } }, nil)) == 2)
check("nothing is not a crash", #(M.selectedItems(nil, nil)) == 0)

-- ---- the iterative part: ⏎ on one row ------------------------------
freshDisk()
ar.list("Thing")
local before = #(M.selectedItems(ar.plan.items, ar.plan.keep))
local tOK, tWhat = ar.toggle(4)          -- the ⚠️ NAME-matched Logs row
check("⏎ on a kept row selects it", tOK == true and tWhat == "will move", tWhat)
check("…and one more row would now move",
      #(M.selectedItems(ar.plan.items, ar.plan.keep)) == before + 1)
ar.toggle(4)
check("⏎ again keeps it", #(M.selectedItems(ar.plan.items, ar.plan.keep)) == before)
check("🔎 and his own changes are counted, so the report can tell them from mine",
      ar.plan.touched == 2, ar.plan.touched)
check("a row number that is not there is refused rather than inventing one",
      select(1, ar.toggle(99)) == false)
check("…and so is nothing at all", select(1, ar.toggle(nil)) == false)

-- the three bulk doors
ar.keepAll()
check("☑ keep everything selects nothing",
      #(M.selectedItems(ar.plan.items, ar.plan.keep)) == 0)
local bOK, bWhy = M.goVerdict(ar.plan)
check("…and the move then refuses, with HIS reason rather than 'nothing found'",
      bOK == false and bWhy:find("marked KEEP", 1, true) ~= nil, bWhy)
ar.keepNone()
check("☐ select everything selects every row",
      #(M.selectedItems(ar.plan.items, ar.plan.keep)) == ar.plan.count)
ar.keepDefaults()
check("↺ back to suggested restores safe-selected, risky-kept",
      #(M.selectedItems(ar.plan.items, ar.plan.keep)) == before)

-- ---- the analysis, in words ----------------------------------------
freshDisk()
ar.list("Thing")
PRINTED = {}
local realP = print
print = function(...) local t = {}
    for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(t, " ") end
_G.appRemove("Thing")
print = realP
local analysis = table.concat(PRINTED, "\n")
check("the analysis names every file", (function()
          for _, it in ipairs(ar.plan.items) do
              if not analysis:find(it.path, 1, true) then return false end
          end
          return true
      end)())
check("…and says of each whether it is safe or careful",
      select(2, analysis:gsub("safe", "")) >= 3
      and analysis:find("careful", 1, true) ~= nil)
check("…and whether it is selected or kept",
      analysis:find("[ MOVE ]", 1, true) ~= nil
      and analysis:find("[ keep ]", 1, true) ~= nil)
check("…and that nothing has moved", analysis:find("NOTHING HAS MOVED", 1, true) ~= nil)
check("🚨 …and it really had not", #RENAMES == 0, #RENAMES)

-- ---- the clamp, joined to the module that owns it -------------------
-- 🔗 6.231.0 — ONE FUNCTION, TWO CALLERS. clipboard_history has done
-- this arithmetic since 6.227.0 and this module asks IT at run time;
-- what follows is the floor for a Mac where that module did not load,
-- and the two must not drift. Lifted from the real source rather than
-- retyped, so no copy of the rule lives in this file (6.273.0).
local cf = io.open(HS .. "/modules/clipboard_history.lua", "r")
local CSRC = cf and cf:read("*a") or ""
if cf then cf:close() end
check("the join below really read clipboard_history", #CSRC > 10000, #CSRC)
local lifted = CSRC:match("(function clip%.rowAfterRebuild.-\n    end)")
check("…and found its clamp to compare against", lifted ~= nil)
if lifted then
    local env = { tonumber = tonumber, clip = {} }
    local chunk = load(lifted, "clip.rowAfterRebuild", "t", env)
    check("…and it loads on its own", chunk ~= nil)
    if chunk then
        chunk()
        local same = true
        for _, pair in ipairs({ {0,0}, {1,0}, {1,1}, {2,1}, {3,5}, {9,5},
                                {-4,5}, {nil,5}, {1,-1} }) do
            local a = M.rowAfterRebuild(pair[1], pair[2])
            local b = env.clip.rowAfterRebuild(pair[1], pair[2])
            if a ~= b then same = false end
        end
        check("🔗 our floor answers exactly what clipboard_history answers", same)
    end
end
check("an empty list has no row at all", M.rowAfterRebuild(3, 0) == nil)
check("a row past the end lands on the LAST one, not the top",
      M.rowAfterRebuild(99, 4) == 4)
check("…and below the first lands on the first", M.rowAfterRebuild(0, 4) == 1)

-- 🔗 AND THE PICKER ASKS THE OTHER MODULE WHEN IT IS THERE. A service
-- that answers must be preferred over our own copy, or the join above
-- proves two functions agree while the shipped path uses neither.
freshDisk()
local ASKED = {}
_G.service = {
    has  = function(n) return n == "clipboard.rowAfterRebuild" end,
    call = function(n, want, total) ASKED[#ASKED + 1] = n ; return 2 end,
}
ar.list("Thing")
SHOWN = {}
ar.show(3)
check("🔗 the picker ASKS clipboard_history where to land", #ASKED == 1, #ASKED)
_G.service = nil
SHOWN = {}
ar.show(3)
check("…and a Mac without it still lands somewhere", #SHOWN == 1, #SHOWN)

-- ---- the report ----------------------------------------------------
freshDisk()
ar.list("Thing")
local rep = _G.appRemoveReport()
check("the report says how many rows are selected",
      rep:find("selected", 1, true) ~= nil, rep:match("[^\n]*selected[^\n]*"))
check("…and NAMES the rows that could be damaging rather than counting them",
      rep:find("Logs/Thing", 1, true) ~= nil)
check("…and says they are not selected", rep:find("NOT selected", 1, true) ~= nil)
ar.toggle(4)
local rep2 = _G.appRemoveReport()
check("🔎 …and once he changes one, it says the change was HIS",
      rep2:find("of YOURS", 1, true) ~= nil, rep2:match("[^\n]*YOURS[^\n]*"))

-- =====================================================================
-- =====================================================================
out("\n=== 10. 6.389.0 — LEFTOVERS FROM AN APP THAT WAS NEVER INSTALLED ===")
-- =====================================================================
-- LL, in the same breath as the review: "this is both for applications
-- that are installed in the applications folder, and applications that
-- are run anywhere else that I install, and also applications that run
-- only off of a disk image that are never installed." That third
-- population has no .app, so the scan goes the other way.

-- ---- what looks like a bundle id ------------------------------------
local function idOK(n) return (M.looksLikeBundleId(n)) end
check("a reverse-DNS name looks like a bundle id", idOK("com.vendor.Thing") == true)
check("…two components are enough", idOK("io.thing") == true)
check("a single word is not one", idOK("Backblaze") == false)
check("a name with a space is not one", idOK("Google Chrome") == false)
check("a hidden file is not one", idOK(".DS_Store") == false)
check("a path is not one", idOK("com.x/../../etc") == false)
check("nothing is not one", idOK(nil) == false and idOK("") == false)
check("a dot with nothing either side is not one", idOK(".x") == false)
-- 🚨 AND BOTH OF THOSE GUARDS NEEDED A FIXTURE WHERE THEY ARE THE ONLY
-- THING SAYING NO (6.230.0, and the sweep found it): "Google Chrome"
-- has no dot either, so the reverse-DNS rule turns it away whether or
-- not the space rule exists. A name with a dot AND a space is the only
-- input where the two implementations must differ.
check("🏷 a name with a dot AND a space is still not one",
      idOK("com.vendor.My App") == false)
local _, spWhy = M.looksLikeBundleId("com.vendor.My App")
check("…and it is the SPACE it names, not the dot",
      tostring(spWhy):find("no spaces", 1, true) ~= nil, spWhy)
-- 🔑 AND THE HIDDEN-FILE RULE CANNOT BE KILLED BY A VERDICT, ever: a
-- name starting with a dot has its first dot at position 1, so the
-- dot-with-nothing-either-side rule always catches it too. What the
-- branch earns its place with is the TRUE REASON (6.243.0) — ".DS_Store
-- is a hidden file" is actionable and "a dot with nothing either side"
-- is a lie about what it is.
local _, hidWhy = M.looksLikeBundleId(".DS_Store")
check("🏷 a hidden file is refused for being HIDDEN, not for its dot",
      tostring(hidWhy):find("hidden file", 1, true) ~= nil, hidWhy)

-- 🚨 APPLE'S OWN ARE REFUSED, and this one is load-bearing rather than
-- tidy: ~/Library/Preferences is mostly com.apple.* — the Dock, the
-- Finder, the keyboard — and offering those is how a removal tool
-- deletes the way his Mac works.
check("🚨 com.apple.dock is REFUSED", idOK("com.apple.dock") == false)
check("🚨 …whatever its case", idOK("COM.APPLE.Dock") == false)
local _, aWhy2 = M.looksLikeBundleId("com.apple.finder")
check("…and it says WHY, in words he can read",
      aWhy2:find("your Mac is set up", 1, true) ~= nil, aWhy2)
check("🚨 this config's own settings are refused too",
      idOK("org.hammerspoon.Hammerspoon") == false)
-- but a vendor that merely CONTAINS the word is not Apple
check("…and a vendor called something-apple is NOT refused",
      idOK("com.appleseed.Thing") == true)

-- ---- the verdict, and the state of the search ------------------------
-- 🚨 "NO APP FOUND" IS NOT "SAFE TO REMOVE". These three fixtures are
-- the whole safety of this half.
local v1, w1 = M.orphanVerdict({ days = 200 }, "everywhere")
check("🚨 an orphan is CAREFUL even when the whole disk was searched",
      v1 == "careful", v1)
check("…and says the whole disk was asked",
      w1:find("anywhere on this Mac", 1, true) ~= nil, w1)
local v2, w2 = M.orphanVerdict({ days = 200 }, "folders")
check("🚨 …and a NARROW search says so in capitals, in the row's own reason",
      v2 == "careful" and w2:find("THAT IS ALL THAT WAS ASKED", 1, true) ~= nil, w2)
check("…because an app he keeps elsewhere looks exactly like this",
      w2:find("anywhere else looks like this too", 1, true) ~= nil, w2)
local v3, w3 = M.orphanVerdict({ days = 200 }, nil)
check("🚨 a search that did not happen is an UNANSWERED QUESTION, not an orphan",
      v3 == "careful" and w3:find("unanswered question", 1, true) ~= nil, w3)
check("…and it does not claim nothing answers for the id",
      w3:find("no application", 1, true) == nil, w3)

-- 🕰 THE AGE IS THE EVIDENCE. "Nothing answers for it" is true of an app
-- he removed last year and of one on a disk he unplugged this morning.
local _, wNew = M.orphanVerdict({ days = 2 }, "everywhere")
check("🕰 something touched in the last week SHOUTS",
      wNew:find("IN THE LAST WEEK", 1, true) ~= nil, wNew)
check("…and names the disk-image case, which is the one he asked about",
      wNew:find("disk image", 1, true) ~= nil, wNew)
local _, wMid = M.orphanVerdict({ days = 30 }, "everywhere")
check("🕰 a month is said in days", wMid:find("30 days ago", 1, true) ~= nil, wMid)
local _, wOld = M.orphanVerdict({ days = 400 }, "everywhere")
check("🕰 a year is said in months", wOld:find("13 month", 1, true) ~= nil, wOld)
local _, wNone = M.orphanVerdict({}, "everywhere")
check("🕰 and an age that could not be read says so rather than reading as old",
      wNone:find("could be read about when", 1, true) ~= nil, wNone)

-- ---- the rows -------------------------------------------------------
local FOUND = {
    ["com.a.one"]   = { paths = { "/p/1" }, size = 300, days = 100 },
    ["com.b.two"]   = { paths = { "/p/2" }, size = 900, days = 100 },
    ["com.c.three"] = { paths = { "/p/3" }, size = 100, days = 100 },
}
local rows = M.orphanRows(FOUND, { ["com.c.three"] = true }, "everywhere")
check("an id that IS installed never appears", #rows == 2, #rows)
check("…and it is the installed one that is gone", (function()
          for _, r in ipairs(rows) do if r.id == "com.c.three" then return false end end
          return true
      end)())
check("the biggest is first, because that is what he is deciding about",
      rows[1].id == "com.b.two", rows[1] and rows[1].id)
check("…and every row carries its verdict and reason",
      rows[1].verdict == "careful" and type(rows[1].risk) == "string")
check("a case-different installed id still counts as installed",
      #(M.orphanRows({ ["Com.A.One"] = { size = 1 } },
                     { ["com.a.one"] = true }, "everywhere")) == 0)
local capRows, capped = M.orphanRows(FOUND, {}, "everywhere", 2)
check("📏 the list is bounded", #capRows == 2, #capRows)
check("📏 …and SAYS it stopped, so it reads as the top and not the whole", capped == true)
check("…keeping the BIGGEST, which is what a bound is for here",
      capRows[1].id == "com.b.two" and capRows[2].id == "com.a.one")
check("nothing found is not a crash", #(M.orphanRows(nil, nil, "everywhere")) == 0)

-- ---- reading Spotlight's answer --------------------------------------
local MD = table.concat({
  "/Applications/Thing.app    kMDItemCFBundleIdentifier = com.vendor.Thing",
  "/Users/lee/Downloads/Other.app\tkMDItemCFBundleIdentifier = com.other.Other",
  "/Volumes/DiskImage/Live.app    kMDItemCFBundleIdentifier = com.live.Live",
  "/Applications/Broken.app    kMDItemCFBundleIdentifier = (null)",
  "a line with no attribute at all",
}, "\n")
local ids, nIds = M.idsInMdfind(MD)
check("it reads an id per line", nIds == 3, nIds)
check("…including one in Downloads — 'anywhere else that I install'",
      ids["com.other.Other"] == true)
check("…and one on a mounted disk image, which is the case he named",
      ids["com.live.Live"] == true)
check("🚨 an app Spotlight indexed with NO id is skipped, not guessed at",
      ids["(null)"] == nil)
check("…and a line that is not an answer is skipped", nIds == 3)
check("nothing is not a crash", select(2, M.idsInMdfind(nil)) == 0)
-- 🚨 A PATH CAN HOLD ANYTHING, including the separator itself, so the id
-- is taken from the LAST occurrence (6.187.0 — a splitter a value can
-- defeat is not a splitter).
local tricky = M.idsInMdfind(
    "/Users/lee/kMDItemCFBundleIdentifier = evil/App.app    "
    .. "kMDItemCFBundleIdentifier = com.real.Real")
check("🚨 a path containing the separator does not fool it",
      tricky["com.real.Real"] == true and tricky["evil/App.app"] == nil)
-- 🚨 THE LOWER-CASE TWIN IS LOAD-BEARING IN ONE DIRECTION ONLY, and
-- only the two halves together show it. `orphanRows` lowers the id it
-- FOUND, so Spotlight answering in lower case over a mixed-case folder
-- is already covered. The case that needs the twin is the other way
-- round: Spotlight answers MIXED and the folder on disk is lower. Join
-- the two functions over that pair or the twin reads as spare (6.352.0
-- — a cross-file join needs both sides driven).
local mixed = M.idsInMdfind("/Applications/T.app  kMDItemCFBundleIdentifier = com.Vendor.Thing")
check("🚨 an app Spotlight names in MIXED case still covers its lower-case folder",
      #(M.orphanRows({ ["com.vendor.thing"] = { size = 1 } }, mixed, "everywhere")) == 0)

-- ---- the scan, end to end -------------------------------------------
local function orphanDisk()
    FS = {
        ["/Applications"] = { dir = true },
        ["/Applications/Thing.app"] = { dir = true, size = 100, bundle = "com.vendor.Thing" },
        [HOME] = { dir = true },
        [HOME .. "/.Trash"] = { dir = true },
        -- an app he still has: its leftovers must NOT be offered
        [HOME .. "/Library/Preferences/com.vendor.Thing.plist"] = { size = 10, mtime = os.time() },
        -- an app that is gone: two folders, one id
        [HOME .. "/Library/Preferences/com.gone.Gone.plist"] = { size = 20,
                                                 mtime = os.time() - 200 * 86400 },
        [HOME .. "/Library/Containers/com.gone.Gone"] = { dir = true, size = 4000,
                                                 mtime = os.time() - 200 * 86400 },
        -- Apple's own, which must never be offered
        [HOME .. "/Library/Preferences/com.apple.dock.plist"] = { size = 5, mtime = os.time() },
        -- and something that is not an id at all
        [HOME .. "/Library/Preferences/ByHost"] = { dir = true, size = 1 },
        __running = {},
    }
    RENAMES, REFUSE, DEGRADED = {}, {}, {}
    TASKS, BELTS = {}, {}
    TASKREFUSE, TASKNIL, TIMERNIL = false, false, false
    BELTREFUSESTOP = false
    ar.plan, ar.orphan = nil, nil
    ar.orphanBusy, ar.orphanTask, ar.orphanBelt, ar.orphanIds = false, nil, nil, nil
    ar.moved = { runs = 0, items = 0, bytes = 0, last = nil, fails = 0, why = nil }
end

orphanDisk()
local started = ar.orphans()
check("the scan starts", started == true, tostring(started))
check("…by asking macOS, off the main thread", #TASKS == 1, #TASKS)
check("…with mdfind and the attribute it needs", (function()
          local t = TASKS[1]
          if not t then return false end
          return t.bin == "/usr/bin/mdfind"
                 and table.concat(t.args or {}, " "):find("kMDItemCFBundleIdentifier", 1, true)
      end)())
check("🛟 …and a belt armed BEFORE the ask, in its own slot",
      #BELTS == 1 and ar.orphanBelt ~= nil, #BELTS)
check("🚨 and NOTHING has been scanned or moved yet",
      ar.orphan == nil and #RENAMES == 0)

-- Spotlight answers
TASKS[1].cb(0, "/Applications/Thing.app  kMDItemCFBundleIdentifier = com.vendor.Thing")
local o = ar.orphan
check("the scan finishes when macOS answers", o ~= nil)
check("…and knows it asked the whole disk", o and o.searched == "everywhere", o and o.searched)
check("the app he STILL HAS is not offered", (function()
          for _, r in ipairs(o.rows) do
              if r.id == "com.vendor.Thing" then return false end
          end
          return true
      end)())
check("🚨 Apple's own is not offered", (function()
          for _, r in ipairs(o.rows) do if r.id:find("apple") then return false end end
          return true
      end)())
check("…and it was COUNTED as refused rather than silently dropped",
      o.refused >= 2, o.refused)
check("the app that is GONE is offered, once, with both its folders", (function()
          for _, r in ipairs(o.rows) do
              if r.id == "com.gone.Gone" then return #r.paths == 2 end
          end
          return false
      end)())
check("🚨 NOTHING IS SELECTED — nothing starts selected in this half",
      (function()
          for i in ipairs(o.rows) do if not o.keep[i] then return false end end
          return #o.rows > 0
      end)())
local gOK3, gWhy3 = ar.orphanGo()
check("🚨 …so a press moves nothing, and says why that is not a fault",
      gOK3 == false and gWhy3:find("not", 1, true) ~= nil, tostring(gWhy3))
check("…and the sentence says WHY nothing starts selected, not just that it did not",
      gWhy3:find("safe to remove", 1, true) ~= nil
      and gWhy3:find("on a row selects it", 1, true) ~= nil, tostring(gWhy3))
check("…and really moved nothing", #RENAMES == 0, #RENAMES)
check("🛟 the belt was stopped when the answer landed",
      ar.orphanBelt == nil and BELTS[1].stopped == true)

-- ⏎ selects, and then it moves BOTH folders of that one id
local which
for i, r in ipairs(o.rows) do if r.id == "com.gone.Gone" then which = i end end
check("the gone app has a row", which ~= nil)
ar.orphanToggle(which)
local gOK4, res4 = ar.orphanGo()
check("⏎ then the top row moves it", gOK4 == true and res4.moved == 2,
      gOK4 and res4.moved or tostring(res4))
check("…both of its folders", FS[HOME .. "/Library/Preferences/com.gone.Gone.plist"] == nil
      and FS[HOME .. "/Library/Containers/com.gone.Gone"] == nil)
check("…into the Trash, not erased", (function()
          for _, r in ipairs(RENAMES) do
              if r.to:sub(1, #(HOME .. "/.Trash/")) ~= HOME .. "/.Trash/" then return false end
          end
          return #RENAMES == 2
      end)(), #RENAMES)
check("🚨 and the app he still has was NOT touched",
      FS[HOME .. "/Library/Preferences/com.vendor.Thing.plist"] ~= nil)
check("🚨 …nor Apple's", FS[HOME .. "/Library/Preferences/com.apple.dock.plist"] ~= nil)
check("the scan is SPENT, like a plan", ar.orphan == nil)
check("…and a second press says so rather than acting on a stale list",
      select(1, ar.orphanGo()) == false)

-- 🚨 THE NARROW SEARCH, which is the state that must never read like the
-- wide one. Every one of these is a Mac where Spotlight says nothing.
orphanDisk()
TASKREFUSE = true
ar.orphans()
check("🚨 macOS refusing to RUN the search still produces an answer",
      ar.orphan ~= nil)
check("…marked as the NARROW search", ar.orphan and ar.orphan.searched == "folders")
check("…and every row's own reason says so", (function()
          for _, r in ipairs(ar.orphan.rows) do
              if not tostring(r.risk):find("THAT IS ALL THAT WAS ASKED", 1, true) then
                  return false
              end
          end
          return #ar.orphan.rows > 0
      end)())
check("…and it says WHY it was narrow", ar.orphan
      and tostring(ar.orphan.why):find("refused", 1, true) ~= nil, ar.orphan and ar.orphan.why)

orphanDisk()
TASKNIL = true
ar.orphans()
check("🚨 a Mac that cannot CREATE the search still answers, narrowly",
      ar.orphan ~= nil and ar.orphan.searched == "folders")

orphanDisk()
ar.orphans()
TASKS[1].cb(1, "")
check("🚨 mdfind answering non-zero is the narrow search, not a crash",
      ar.orphan ~= nil and ar.orphan.searched == "folders")
check("…and it quotes the code", ar.orphan
      and tostring(ar.orphan.why):find("1", 1, true) ~= nil, ar.orphan and ar.orphan.why)

-- 🛟 THE BELT: a search that never answers must not leave the tool busy
-- for the session (6.304.0's wedge, in a new place).
orphanDisk()
ar.orphans()
check("the tool is busy while it waits", ar.orphanBusy == true)
BELTS[1].fn()
check("🛟 the belt finishes it", ar.orphan ~= nil and ar.orphanBusy == false)
check("…narrowly, and saying the search did not answer", ar.orphan
      and tostring(ar.orphan.why):find("did not answer", 1, true) ~= nil,
      ar.orphan and ar.orphan.why)
check("🚨 …and the task it gave up on was KILLED", TASKS[1].killed == true)
-- and a late answer after the belt must not reopen a finished scan
local rowsBefore = #ar.orphan.rows
local oAfterBelt = ar.orphan
TASKS[1].cb(0, "/x.app  kMDItemCFBundleIdentifier = com.gone.Gone")
check("🚨 an answer arriving after the belt is DROPPED", #ar.orphan.rows == rowsBefore)
check("🚨 …and the finished scan is the SAME answer, not a fresh one",
      ar.orphan == oAfterBelt)
check("…still marked NARROW, because the belt is what ended it",
      ar.orphan.searched == "folders", ar.orphan.searched)
check("…and still saying the search never answered", ar.orphan
      and tostring(ar.orphan.why):find("did not answer", 1, true) ~= nil,
      ar.orphan and ar.orphan.why)

-- 🚪 AND THE SAME ONE EXIT IN THE OPPOSITE ORDER, which is the half the
-- callback's own guard cannot cover: the ANSWER lands first and the BELT
-- fires afterwards. On a real Mac `:stop()` ends it — but that stop is
-- pcall'd, so a Mac that refuses it leaves the belt armed over a scan
-- that has already finished. Without the one-exit guard that belt
-- replaces a WIDE answer with a NARROW one, which turns a good scan into
-- "ONLY your two app folders were searched" — the exact lie this half of
-- the release exists to avoid.
orphanDisk()
BELTREFUSESTOP = true
ar.orphans()
TASKS[1].cb(0, "/Applications/Thing.app  kMDItemCFBundleIdentifier = com.vendor.Thing")
local oWide = ar.orphan
check("the wide answer landed", oWide ~= nil and oWide.searched == "everywhere",
      oWide and oWide.searched)
check("…and this Mac refused to stop the belt, so it is still armed",
      BELTS[1].stopped ~= true)
BELTS[1].fn()
check("🚨 a belt firing AFTER the answer does not replace a wide scan with a narrow one",
      ar.orphan == oWide and ar.orphan.searched == "everywhere",
      ar.orphan and ar.orphan.searched)
check("…and the reason is not overwritten either", ar.orphan.why == nil,
      tostring(ar.orphan and ar.orphan.why))
BELTREFUSESTOP = false

orphanDisk()
TIMERNIL = true
ar.orphans()
check("a Mac with no timer still asks", #TASKS == 1)
TASKS[1].cb(0, "")
check("…and still answers", ar.orphan ~= nil)

-- two scans at once
orphanDisk()
ar.orphans()
check("a second scan while one is running is refused rather than stacking",
      select(1, ar.orphans()) == false)

-- 🚨 AND SPOTLIGHT'S ANSWER HAS TO BE MERGED, which only an app the
-- FOLDER WALK CANNOT SEE can prove. com.vendor.Thing is in
-- /Applications, so the two folders find it with or without the merge
-- (6.230.0, again). com.else.Elsewhere lives in Downloads — which is
-- his own second population, "applications that are run anywhere else
-- that I install" — so Spotlight is the ONLY thing that can know it is
-- installed, and without the merge its settings are offered for removal
-- while the app is sitting there working.
orphanDisk()
FS[HOME .. "/Library/Preferences/com.else.Elsewhere.plist"] =
    { size = 30, mtime = os.time() - 300 * 86400 }
ar.orphans()
TASKS[1].cb(0, table.concat({
    "/Applications/Thing.app  kMDItemCFBundleIdentifier = com.vendor.Thing",
    "/Users/lee/Downloads/Elsewhere.app  kMDItemCFBundleIdentifier = com.else.Elsewhere",
}, "\n"))
check("🚨 an app installed OUTSIDE the two folders is not offered as an orphan",
      (function()
          for _, r in ipairs(ar.orphan.rows) do
              if r.id == "com.else.Elsewhere" then return false end
          end
          return #ar.orphan.rows > 0
      end)(), (function()
          local n = {}
          for _, r in ipairs(ar.orphan.rows) do n[#n + 1] = r.id end
          return table.concat(n, ", ")
      end)())
check("…and the one that really is gone is still offered beside it", (function()
          for _, r in ipairs(ar.orphan.rows) do
              if r.id == "com.gone.Gone" then return true end
          end
          return false
      end)())

-- ---- the picker's third face ----------------------------------------
orphanDisk()
SHOWN, POPUPREFUSE = {}, false
ar.show()
local chA = SHOWN[1] or { rows_ = {} }
check("the app list offers the scan", (function()
          for _, r in ipairs(chA.rows_ or {}) do if r.scan then return true end end
          return false
      end)())
check("…by NAME, so a row he cannot read is not an offer", (function()
          for _, r in ipairs(chA.rows_ or {}) do
              if r.scan then
                  return tostring(r.text):find("Leftovers with no app", 1, true) ~= nil
              end
          end
          return false
      end)())
check("…and says nothing moves", (function()
          for _, r in ipairs(chA.rows_ or {}) do
              if r.scan then return tostring(r.subText):find("nothing moves", 1, true) ~= nil end
          end
          return false
      end)())
check("…and names the disk-image case he asked about", (function()
          for _, r in ipairs(chA.rows_ or {}) do
              if r.scan then return tostring(r.subText):find("disk image", 1, true) ~= nil end
          end
          return false
      end)())

ar.orphans()
TASKS[1].cb(0, "")
SHOWN = {}
ar.show()
local chB = SHOWN[1] or { rows_ = {} }
check("with a scan in hand the picker shows the orphan rows", (function()
          local n = 0
          for _, r in ipairs(chB.rows_ or {}) do if r.otoggle then n = n + 1 end end
          return n == #ar.orphan.rows and n > 0
      end)())
check("…the top row refuses while nothing is selected",
      chB.rows_[1] and chB.rows_[1].orphanGo == false, chB.rows_[1] and chB.rows_[1].text)
check("…and a way back that moves nothing", (function()
          for _, r in ipairs(chB.rows_ or {}) do if r.back then return true end end
          return false
      end)())
check("…each one saying which way ⏎ goes, because nothing starts selected", (function()
          local n = 0
          for _, r in ipairs(chB.rows_ or {}) do
              if r.otoggle then
                  if tostring(r.text):sub(1, 9) ~= "[ keep ] " then return false end
                  n = n + 1
              end
          end
          return n > 0
      end)(), chB.rows_[2] and chB.rows_[2].text)
check("…and the mark FOLLOWS the selection rather than being decoration", (function()
          local i
          for k, r in ipairs(ar.orphan.rows) do if r.id == "com.gone.Gone" then i = k end end
          if not i then return false end
          ar.orphanToggle(i)
          SHOWN = {}
          ar.show()
          for _, r in ipairs(SHOWN[1].rows_ or {}) do
              if r.otoggle == i then
                  return tostring(r.text):sub(1, 9) == "[ MOVE ] "
              end
          end
          return false
      end)())

-- ---- the report, and its four states --------------------------------
orphanDisk()
local r1 = _G.appRemoveReport()
check("with no scan the report says NOT SCANNED, not 'none found'",
      r1:find("not scanned", 1, true) ~= nil, r1:match("[^\n]*orphans[^\n]*"))
ar.orphans()
TASKS[1].cb(0, "")
local r2 = _G.appRemoveReport()
check("after a wide scan it says the whole Mac was asked",
      r2:find("asked every app", 1, true) ~= nil, r2:match("[^\n]*asked[^\n]*"))
orphanDisk()
TASKREFUSE = true
ar.orphans()
local r3 = _G.appRemoveReport()
check("🚨 after a NARROW scan it says so, in capitals",
      r3:find("ONLY your two app folders", 1, true) ~= nil, r3:match("[^\n]*ONLY[^\n]*"))
check("…and warns that an app kept elsewhere looks like an orphan",
      r3:find("looks like an orphan", 1, true) ~= nil)

-- 🗳 AND THE ANALYSIS SAYS NOTHING IS SELECTED, in the block he reads
-- before deciding anything. "nothing has moved" and "nothing is
-- selected" are two different facts and he needs both: the first is
-- about what this press did, the second about what the NEXT press would
-- do (6.384.0's first-press rule, said where the list is).
orphanDisk()
PRINTED = {}
local realP2 = print
print = function(...) local t = {}
    for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end
    PRINTED[#PRINTED + 1] = table.concat(t, " ") end
_G.appOrphans()
TASKS[1].cb(0, "")
print = realP2
local oAnalysis = table.concat(PRINTED, "\n")
check("the analysis is printed for him to read", oAnalysis:find("LEFTOVERS", 1, true) ~= nil
      or oAnalysis:find("orphan", 1, true) ~= nil, oAnalysis:sub(1, 120))
check("🗳 …and it says NOTHING IS SELECTED, not only that nothing has moved",
      oAnalysis:find("nothing is selected", 1, true) ~= nil,
      oAnalysis:match("[^\n]*NOTHING HAS MOVED[^\n]*"))
check("…and names every folder of every row, so the list is the artefact",
      (function()
          for _, r in ipairs(ar.orphan.rows) do
              for _, p in ipairs(r.paths) do
                  if not oAnalysis:find(p, 1, true) then return false end
              end
          end
          return #ar.orphan.rows > 0
      end)())

out("\n=== 8. THE REPORT, AND THE SOURCE PROMISE ===")
-- =====================================================================
freshDisk()
local r0 = _G.appRemoveReport()
check("with nothing listed the report says so, not '0 items'",
      r0:find("nothing is listed", 1, true) ~= nil, r0:match("listed[^\n]*"))
check("…and it says nothing has been removed this session",
      r0:find("nothing has been removed", 1, true) ~= nil)
check("…and it names the ONLY folder leftovers are looked for in",
      r0:find(HOME, 1, true) ~= nil and r0:find("ONLY", 1, true) ~= nil)
ar.list("Thing")
local r1 = _G.appRemoveReport()
check("once listed it names the app, the count and the bundle id",
      r1:find("Thing", 1, true) ~= nil and r1:find("com.vendor.Thing", 1, true) ~= nil)
check("…and warns about the rows that are only a name guess",
      r1:find("matched by NAME", 1, true) ~= nil, r1:match("NAME[^\n]*"))
ar.go()
local r2 = _G.appRemoveReport()
check("after a removal it says what moved and when",
      r2:find("item(s) across", 1, true) ~= nil, r2:match("moved[^\n]*"))

-- 🔒 THE PROMISE THIS WHOLE MODULE MAKES, asserted against the source:
-- nothing here erases anything. 6.321.0's rule — a sentry that bans a
-- NAME expires the first time the name has an honest use, so this one
-- states the RULE: there is no erase call in this file at all, and the
-- only thing that removes a path from where it was is a rename INTO the
-- Trash. Comments are stripped (6.262.0) because the header quotes the
-- very call it forbids.
local f = io.open(MOD, "r")
local SRC = f and f:read("*a") or ""
if f then f:close() end
check("the sentry below really read the module", #SRC > 9000, #SRC)
local bare = SRC:gsub("\n%s*%-%-[^\n]*", "\n")
check("the strip left something to read", #bare > 6000, #bare)
check("🔒 NOTHING IN THIS FILE ERASES ANYTHING — no os.remove",
      bare:find("os%.remove") == nil, tostring(bare:match("[^\n]*os%.remove[^\n]*")))
check("🔒 …no rm, no unlink, no trash-emptying shell call",
      bare:find("hs%.execute") == nil and bare:find("osascript") == nil
      and bare:find("io%.popen") == nil)
check("🔒 the ONE thing that moves a path is a rename into the Trash",
      select(2, bare:gsub("os%.rename", "")) == 1,
      select(2, bare:gsub("os%.rename", "")))
check("🔒 …and every move is guarded immediately before it",
      bare:find("M%.insideAllowed%(it%.path, ar%.allowed%)") ~= nil)
-- and the comment explaining the rule is still there, so the sentry
-- cannot be satisfied by deleting the explanation (6.280.0)
check("…and the file still explains why, in words",
      SRC:find("NOTHING IS ERASED", 1, true) ~= nil)

os.rename = realRename

out(("\n%d passed, %d failed\n"):format(pass, fail))
if fail > 0 then
    out("FAILURES:")
    for _, x in ipairs(failures) do out("   ❌ " .. x) end
    os.exit(1)
end
