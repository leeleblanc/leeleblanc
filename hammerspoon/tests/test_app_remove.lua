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
ok = M.goVerdict({ app = "/Applications/X.app", name = "X",
                   running = false, count = 3 })
check("a quit app with items → yes", ok == true)

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
        attributes = function(p) local e = FS[p]
            if not e then return nil end
            return { mode = e.dir and "directory" or "file", size = e.size or 0 } end,
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

local okG, res = ar.go()
check("the second press moves them", okG == true and res.moved == 4,
      okG and res.moved or tostring(res))
check("…into ~/.Trash and nowhere else", (function()
          for _, r in ipairs(RENAMES) do
              if r.to:sub(1, #(HOME .. "/.Trash/")) ~= HOME .. "/.Trash/" then return false end
          end
          return #RENAMES == 4
      end)(), #RENAMES)
check("…and the app really is gone from /Applications",
      FS["/Applications/Thing.app"] == nil)
check("…and is sitting in the Trash, not erased", (function()
          for k in pairs(FS) do
              if k:find(HOME .. "/.Trash/Thing.app", 1, true) == 1 then return true end
          end
          return false
      end)())

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
check("…and says what it is about to move, in words",
      tostring(row1("text")):find("Thing", 1, true) ~= nil
      and tostring(row1("text")):find("Trash", 1, true) ~= nil, row1("text"))
check("…and says it is undoable",
      tostring(row1("subText")):find("Put Back", 1, true) ~= nil, row1("subText"))
if type(ch2.rows_[1]) == "table" then ch2.cb(ch2.rows_[1]) end
check("…and choosing it moves them", #RENAMES == 4, #RENAMES)

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
