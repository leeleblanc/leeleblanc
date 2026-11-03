-- =====================================================================
-- test_install_check.lua — "so I don't have to remember"
-- =====================================================================
--     lua5.4 test_install_check.lua [/path/to/hammerspoon]
--
-- Executes modules/install_check.lua against REAL FILES in a temporary
-- tree. The whole module is a claim about what is on disk, so a stubbed
-- filesystem would only confirm my idea of one — 6.193.0's rule, and the
-- same reason tests/test_write_ledger.lua works this way. Only hs.fs,
-- hs.timer and the degrade door are stood in for.
--
-- 🚨 THE SECTIONS WITH TEETH:
--   §2  `a..b/x.lua` must be ALLOWED. Two dots in a NAME are not a
--       parent directory, and 6.320.0 is the release where a substring
--       test over a serialised path refused `Budget..final.md` and LL
--       could not delete his own note.
--   §7  the `unknown` verdict is driven by a stat that REFUSES rather
--       than one that is MISSING (6.265.0: created, wired, refused).
--       Those two are different facts and the module says so.
--   §8  the no-manifest block must not read as health. "Cannot be
--       checked" rendering as "all clear" is 6.196.1 in the one place
--       it would be most reassuring.
--  §12  a folder read only as far as its bound must not report
--       "strays: none" (6.197.2). Found by writing this suite.

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

local printed = {}
local realPrint = print
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

-- ---- a real temporary tree ---------------------------------------------
local ROOT = os.getenv("TMPDIR") or "/tmp"
ROOT = ROOT:gsub("/$", "") .. "/hs-install-check-test-" .. tostring(os.time())
local CFG = ROOT .. "/hammerspoon"
os.execute("mkdir -p '" .. CFG .. "/core' '" .. CFG .. "/modules' '"
           .. CFG .. "/tools'")

local function put(path, body)
    local f = assert(io.open(path, "w")) ; f:write(body) ; f:close()
end
local function slurp(path)
    local f = io.open(path, "rb") ; if not f then return nil end
    local s = f:read("*a") ; f:close() ; return s
end
local function sizeOnDisk(rel)
    local s = slurp(CFG .. "/" .. rel)
    return s and #s or nil
end

-- The runtime files, written at known lengths.
local FILES = {
    ["init.lua"]                = string.rep("-- init\n", 40),
    ["core/boot_cost.lua"]      = string.rep("-- cost\n", 20),
    ["core/notices.lua"]        = string.rep("-- notices\n", 15),
    ["modules/music_player.lua"]= string.rep("-- jug\n", 30),
    ["modules/write_ledger.lua"]= string.rep("-- ledger\n", 25),
    ["tools/hs-stall-guard.sh"] = "#!/bin/sh\necho hi\n",
}
for rel, body in pairs(FILES) do put(CFG .. "/" .. rel, body) end

local VERSION = "6.399.0"
local function writeManifest(version, extraRows, omit)
    local L = { "# Hammerspoon runtime manifest — GENERATED, do not hand-edit" }
    if version then L[#L + 1] = "# version: " .. version end
    L[#L + 1] = ""
    local order = { "init.lua", "core/boot_cost.lua", "core/notices.lua",
                    "modules/music_player.lua", "modules/write_ledger.lua",
                    "tools/hs-stall-guard.sh" }
    for _, rel in ipairs(order) do
        if not (omit and omit[rel]) then
            L[#L + 1] = rel .. "\t" .. tostring(#FILES[rel])
        end
    end
    for _, extra in ipairs(extraRows or {}) do L[#L + 1] = extra end
    put(CFG .. "/MANIFEST.txt", table.concat(L, "\n") .. "\n")
end
writeManifest(VERSION)

-- ---- the stub Mac ------------------------------------------------------
local TIMERS = {}
local FS_ATTR_OVERRIDE = nil        -- set by a section to make macOS refuse

hs = {
    configdir = CFG,
    fs = {
        -- The REAL two-value contract: an iterator plus the state it reads
        -- from. A single stateless closure works either way and is exactly
        -- the forgiving stub that hid the 6.69.0 bug.
        dir = function(d)
            local p = io.popen("ls -a '" .. d .. "' 2>/dev/null")
            if not p then error("no such directory") end
            local names = {}
            for line in p:lines() do names[#names + 1] = line end
            p:close()
            if #names == 0 then error("no such directory: " .. d) end
            local state = { i = 0, names = names }
            return function(st)
                st.i = st.i + 1
                return st.names[st.i]
            end, state
        end,
        attributes = function(path)
            if FS_ATTR_OVERRIDE then return FS_ATTR_OVERRIDE(path) end
            -- GNU stat and BSD stat disagree on every flag, and `stat -f`
            -- means "filesystem status" on GNU, so it SUCCEEDS with the
            -- wrong output. Both forms are tried; the answer is accepted
            -- only if it parses.
            for _, cmd in ipairs({ "stat -c '%s %F' ", "stat -f '%z %HT' " }) do
                local p = io.popen(cmd .. "'" .. path .. "' 2>/dev/null")
                if p then
                    local line = p:read("*l") ; p:close()
                    local size, kind = tostring(line or ""):match("^(%d+)%s+(.*)$")
                    if size then
                        return { size = tonumber(size),
                                 mode = (kind:lower():find("director")
                                         and "directory" or "file") }
                    end
                end
            end
            return nil
        end,
    },
    timer = {
        doAfter = function(secs, fn)
            local t = { secs = secs, fn = fn, stopped = false }
            function t:stop() self.stopped = true end
            TIMERS[#TIMERS + 1] = t
            return t
        end,
    },
    alert = { show = function() end },
}
_G.diag = { say = function() end, warn = function() end, err = function() end }
_G.configVersion = VERSION

local DEGRADES = {}
_G.degrade = function(tool, why)
    DEGRADES[#DEGRADES + 1] = { tool = tostring(tool), why = tostring(why) }
    return false, why
end

local PROVIDED = {}
local CORE = {
    configDir = CFG,
    provide   = function(n, f) PROVIDED[n] = f end,
    degrade   = _G.degrade,
}

local chunk = assert(loadfile(HS .. "/modules/install_check.lua"))
local M = chunk()
M.setup(CORE)
local ic = _G.installCheckState
local SRC = assert(slurp(HS .. "/modules/install_check.lua"))
-- ⏱ READ BEFORE ANY CHECK CAN HAVE RUN. setup() has just returned, so
-- these two are the evidence that nothing read the disk on the boot path
-- (6.267.0). A mutation that calls ic.run() at the end of setup fails
-- here and nowhere else.
local RUNS_AT_SETUP, LAST_AT_SETUP = ic.runs, ic.last

-- 🧪 A TEST HELPER ANSWERS FALSELY RATHER THAN INDEXING A NIL (6.186.0,
-- eighth time in this project). A mutation that stops warm arming a
-- timer, or stops sizeOf catching a raise, or stops the door pcalling
-- itself, must fail a CHECK — a suite that dies mid-file prints
-- "0 failed" and reads as a pass.
local function fireTimer(n)
    local t = TIMERS[n or 1]
    if not t or type(t.fn) ~= "function" then return false, "no timer was armed" end
    local ok, err = pcall(t.fn)
    return ok, err
end
-- …and the PURE functions get the same treatment: a mutation that lets
-- relInside index a nil, or straysIn walk one, must fail a check.
local function pureSafe(fn, ...)
    local ok, a = pcall(fn, ...)
    if not ok then return "RAISED" end
    return a
end
local function straysSafe(dir, names, seen)
    local ok, a = pcall(ic.straysIn, dir, names, seen)
    if not ok then return nil, tostring(a) end
    return a
end
local function sizeOfSafe(rel)
    local ok, a, b = pcall(ic.sizeOf, rel)
    if not ok then return nil, "RAISED: " .. tostring(a) end
    return a, b
end
local function doorSafe()
    local ok, err = pcall(_G.installCheck)
    return ok, err
end

-- =====================================================================
out("\n=== 1. it loads, publishes its doors, and claims no key ===\n")
-- =====================================================================
check("the module returns a table with a name", M.name == "Install Check")
check("it declares a family", M.family == "config")
check("it carries an order so §1.12 can place it", type(M.order) == "number")
check("it sits beside write_ledger (13.36) rather than at the end",
      M.order > 13.36 and M.order < 13.4, M.order)
check("_G.installCheck is the door a human would type",
      type(_G.installCheck) == "function")
check("_G.installCheckReport is the same door under the report name",
      _G.installCheckReport == _G.installCheck)
check("_G.installCheckState is published for the gate and the report",
      type(_G.installCheckState) == "table")
check("it has an M.warm — the disk read is never on the boot path",
      type(M.warm) == "function")
check("🚨 setup() ran the check ZERO times — disk work at setup is a tax "
      .. "every key pays (6.267.0)", RUNS_AT_SETUP == 0, RUNS_AT_SETUP)
check("…and recorded no answer, so the report cannot claim one yet",
      LAST_AT_SETUP == nil)
check("it ships a cheatsheet with a title", type(M.cheatsheet) == "table"
      and type(M.cheatsheet.title) == "string")
check("…and the rows are under `entries`, which is the key the sheet reads",
      type(M.cheatsheet.entries) == "table" and #M.cheatsheet.entries > 0,
      M.cheatsheet.entries and #M.cheatsheet.entries)
-- 6.269.0: anchors.lua declared its rows under `rows =` and drew a heading
-- over empty space for eighty-nine releases. The loader coerces a missing
-- `entries` to {}, so nothing functional can see it.
check("🚨 it does NOT also carry a `rows` key — that is 6.269.0's dead card",
      M.cheatsheet.rows == nil)
-- 🚨 EVERY SHIFTED LETTER IS CLAIMED. A module that quietly took a key
-- would shadow a tool LL uses, and the source is the only honest check.
check("it never calls hyperAddShortcut",
      SRC:find("hyperAddShortcut", 1, true) == nil)
check("it never calls hs.hotkey",
      SRC:find("hs%.hotkey") == nil)
-- The key column of the cheat sheet is WORDS, so 6.196.0's auditor reads
-- the card as a pointer rather than a claim about a combo it never bound.
local keyCols = {}
for _, row in ipairs(M.cheatsheet.entries or {}) do keyCols[#keyCols + 1] = row[1] end
check("no cheat-sheet row claims a ⇪ combo",
      not table.concat(keyCols, " "):find("⇪", 1, true),
      table.concat(keyCols, " "))

-- =====================================================================
out("\n=== 2. relInside — a path read off disk is DATA, not an address ===\n")
-- =====================================================================
check("an ordinary row is inside", ic.relInside("modules/music_player.lua"))
check("a bare file name is inside", ic.relInside("init.lua"))
check("a deep path is inside", ic.relInside("tools/sub/deep/thing.sh"))
-- 🚨 THE FIXTURE THAT BITES, and it is the whole reason this is a walk
-- rather than a find(".."): 6.320.0 refused `Budget..final.md` because it
-- searched the SERIALISED path for two dots. Two dots in a NAME are not a
-- parent directory, and a manifest that legitimately holds such a file
-- must not refuse the whole install.
check("🚨 two dots INSIDE a name are allowed — 6.320.0's exact fixture",
      ic.relInside("modules/a..b/x.lua"))
check("…and a file called ..something is allowed",
      ic.relInside("core/..notes.lua"))
check("a real parent component is refused", not ic.relInside("../etc/passwd"))
check("a parent component in the middle is refused",
      not ic.relInside("modules/../../etc/passwd"))
check("a bare .. is refused", not ic.relInside(".."))
check("a . component is refused", not ic.relInside("./init.lua"))
check("an absolute path is refused", not ic.relInside("/etc/passwd"))
check("a doubled slash is refused", not ic.relInside("core//x.lua"))
check("a trailing slash is refused", not ic.relInside("core/"))
check("an empty string is refused", not ic.relInside(""))
check("🚨 a non-string is refused rather than indexed",
      pureSafe(ic.relInside, nil) == false, pureSafe(ic.relInside, nil))
check("a number is refused rather than indexed",
      pureSafe(ic.relInside, 12) == false, pureSafe(ic.relInside, 12))
check("a table is refused rather than indexed",
      pureSafe(ic.relInside, {}) == false, pureSafe(ic.relInside, {}))

-- =====================================================================
out("\n=== 3. parseManifest — it answers rows + meta, or nil + why ===\n")
-- =====================================================================
local rows, meta = ic.parseManifest(slurp(CFG .. "/MANIFEST.txt"), 400)
check("the real manifest parses", rows ~= nil, meta)
check("it found all six rows", rows and #rows == 6, rows and #rows)
check("it read the version out of the comment", meta and meta.version == VERSION,
      meta and meta.version)
check("it counted the rows in meta", meta and meta.count == 6, meta and meta.count)
check("the first row carries a path", rows and rows[1].path == "init.lua",
      rows and rows[1].path)
check("…and a NUMBER of bytes", rows and type(rows[1].bytes) == "number")
check("the byte count is the real length",
      rows and rows[1].bytes == #FILES["init.lua"], rows and rows[1].bytes)
check("no bad row on a clean manifest", meta and meta.bad == nil, meta and meta.bad)

local r2, m2 = ic.parseManifest("# version = 6.400.0\nx.lua\t5\n", 400)
check("an = instead of a : still reads the version", m2 and m2.version == "6.400.0",
      m2 and m2.version)
local r3, m3 = ic.parseManifest("a.lua\t1\n\n\n\nb.lua\t2\n", 400)
check("blank lines are skipped, not counted", r3 and #r3 == 2, r3 and #r3)
local r4, m4 = ic.parseManifest("# just a comment\n# and another\n", 400)
check("a manifest of comments alone is REFUSED", r4 == nil)
check("…and says it holds no file rows",
      tostring(m4):find("no file rows", 1, true) ~= nil, m4)
-- A row nobody can parse is COUNTED, not fatal: a future column added to
-- the generator must not make an old reader refuse the whole install.
local r5, m5 = ic.parseManifest("a.lua\t10\nthis is not a row\nb.lua\t20\n", 400)
check("an unparseable row does not refuse the file", r5 ~= nil, m5)
check("…the parseable rows either side are both kept", r5 and #r5 == 2, r5 and #r5)
check("…and the bad row is NAMED in meta rather than silently dropped",
      m5 and tostring(m5.bad):find("cannot parse", 1, true) ~= nil, m5 and m5.bad)
-- 🚨 BUT A ROW POINTING OUTSIDE THE FOLDER REFUSES THE WHOLE FILE. One
-- unparseable row is a reader that is behind; a row naming /etc/passwd is
-- a file we should not be describing at all. Fail CLOSED (6.276.0).
local r6, m6 = ic.parseManifest("a.lua\t10\n../../etc/passwd\t20\nb.lua\t30\n", 400)
check("🚨 a row outside the config folder refuses the WHOLE manifest", r6 == nil)
check("…and names the path it refused",
      tostring(m6):find("outside the config folder", 1, true) ~= nil, m6)
local r6b = ic.parseManifest("a.lua\t10\n/etc/passwd\t20\n", 400)
check("an absolute row refuses the whole manifest too", r6b == nil)
-- The bound, driven rather than grepped (a check that a budget EXISTS is
-- not a check that it BITES).
local many = {}
for i = 1, 12 do many[#many + 1] = "f" .. i .. ".lua\t1" end
local r7, m7 = ic.parseManifest(table.concat(many, "\n") .. "\n", 10)
check("more rows than the bound refuses the file", r7 == nil)
check("…and the refusal quotes the bound",
      tostring(m7):find("more than 10", 1, true) ~= nil, m7)
local r7b = ic.parseManifest(table.concat(many, "\n") .. "\n", 400)
check("…and the same rows parse under a bound that fits", r7b and #r7b == 12,
      r7b and #r7b)
-- Zero bytes is its own answer: a truncated write and an absent file are
-- opposite facts (6.313.0 is the release where a store was left at zero).
local r8, m8 = ic.parseManifest("", 400)
check("a ZERO BYTE manifest is its own refusal", r8 == nil)
check("…and says so in those words",
      tostring(m8):find("ZERO BYTES", 1, true) ~= nil, m8)
local r9, m9 = ic.parseManifest(nil, 400)
check("nothing read is its own refusal", r9 == nil)
check("…and does not read like an empty file",
      tostring(m9):find("nothing was read", 1, true) ~= nil, m9)
-- A row with no version comment at all: meta.version is nil, and §10 is
-- where the block has to say so rather than claiming a match.
local r10, m10 = ic.parseManifest("a.lua\t1\n", 400)
check("a manifest with no version comment parses, version nil",
      r10 ~= nil and m10.version == nil, m10 and m10.version)
-- Trailing whitespace is trimmed, because a generator on another platform
-- may write \r\n and a row ending in \r would never match a tab pattern.
local r11 = ic.parseManifest("a.lua\t10   \n", 400)
check("trailing whitespace on a row is trimmed", r11 and #r11 == 1, r11 and #r11)

-- =====================================================================
out("\n=== 4. verdict — four answers, and the last two differ ===\n")
-- =====================================================================
local st, words = ic.verdict(100, 100)
check("the same size is ok", st == "ok", st)
check("…and says the number", words:find("100", 1, true) ~= nil, words)
st, words = ic.verdict(116595, 107414)
check("a different size is `size`", st == "size", st)
-- 🚨 BOTH NUMBERS. "107414 against 116595" was the whole diagnosis of
-- 6.311.0's half-install; one number alone decides nothing.
check("🚨 …and carries BOTH numbers — the release's and this Mac's",
      words:find("116595", 1, true) and words:find("107414", 1, true), words)
st, words = ic.verdict(500, nil, "missing")
check("no file at all is `missing`", st == "missing", st)
check("…and says there is no file here",
      words:find("MISSING", 1, true) ~= nil, words)
st, words = ic.verdict(500, nil, "no size in the answer")
-- 6.196.1: "there is no such file" and "something is there and macOS
-- would not say how big it is" send you to different places.
check("🚨 a refused stat is `unknown`, NOT `missing`", st == "unknown", st)
check("…and quotes the reason macOS gave",
      words:find("no size in the answer", 1, true) ~= nil, words)
st = ic.verdict(500, nil, nil)
check("a refusal with no reason at all is still `unknown`", st == "unknown", st)
-- 🚨 ASSERT WHAT IS UNIQUE TO THE BRANCH (6.212.0 · 6.248.0). `st ~= "ok"`
-- survived the mutation that reads `got ~= nil` instead of
-- `type(got) == "number"`, because in Lua a string never equals a number
-- so it lands in `size` either way. The DIFFERENCE is the sentence: that
-- branch claims "this Mac has 107414", which is macOS reporting a size it
-- did not report. A plausible wrong answer in a report is worse than one
-- that says it does not know (6.338.0).
st, words = ic.verdict(500, "107414")
check("🚨 a size that is a STRING is `unknown`, not a size this Mac reported",
      st == "unknown", st)
check("…and the words do not claim a byte count macOS never gave",
      words:find("107414", 1, true) == nil, words)
check("a zero-byte file is a SIZE disagreement, never a match",
      select(1, ic.verdict(500, 0)) == "size")
check("…and a genuinely zero-byte file the release carried matches",
      select(1, ic.verdict(0, 0)) == "ok")

-- =====================================================================
out("\n=== 5. straysIn — a .lua the manifest does not name ===\n")
-- =====================================================================
local seen = { ["core/boot_cost.lua"] = true, ["core/notices.lua"] = true }
local s1 = ic.straysIn("core", { ".", "..", "boot_cost.lua", "notices.lua" }, seen)
check("a folder holding only what shipped has no strays", #s1 == 0,
      table.concat(s1, ","))
local s2 = ic.straysIn("core", { "boot_cost.lua", "boot_cost 2.lua" }, seen)
-- 🪟 Finder's Keep Both, one click wide: §1.12 loads an explicit list, so
-- the stray is ignored and the ORIGINAL stays loaded.
check("🚨 Finder's 'Keep Both' copy is a stray", #s2 == 1 and s2[1] == "core/boot_cost 2.lua",
      table.concat(s2, ","))
local s3 = ic.straysIn("core", { "notes.md", "README", "boot_cost.lua" }, seen)
check("a non-.lua file is not a stray — this is not a file browser", #s3 == 0,
      table.concat(s3, ","))
-- 🚨 THE FIXTURE WHERE THE TWO IMPLEMENTATIONS MUST DIFFER (6.230.0), and
-- the sweep is what asked for it: a test that merely CONTAINS ".lua"
-- calls a backup file a stray .lua. 6.236.0's rule — any sentry that
-- looks for a NAME looks for its boundary too, third time in this
-- project — and §1.12 would not load either of these, so reporting them
-- as runtime strays is a wrong answer about somebody's own files.
local s3b = ic.straysIn("core", { "boot_cost.lua.bak", "notes.luajit",
                                  "x.lua.orig" }, seen)
check("🚨 a name that merely CONTAINS .lua is not a stray — the test is the ending",
      #s3b == 0, table.concat(s3b, ","))
local s4 = ic.straysIn("core", { ".", "..", ".hidden.lua" }, seen)
check("a hidden .lua IS a stray — §1.12 would ignore it just the same",
      #s4 == 1, table.concat(s4, ","))
-- 🗑 `.` and `..` are turned away BY THE EXTENSION TEST, not by a guard of
-- their own: neither can end in ".lua". The sweep is what established
-- that, and the check asserts the OUTCOME rather than the mechanism.
check("…and . and .. are not among them", s4[1] == "core/.hidden.lua", s4[1])
check("a file called ..lua IS a stray — it is a real name, not a folder",
      (ic.straysIn("core", { "..lua" }, {}))[1] == "core/..lua",
      (ic.straysIn("core", { "..lua" }, {}))[1])
local s5 = ic.straysIn("modules", { "z.lua", "a.lua", "m.lua" }, {})
check("the answer is sorted, so the report reads the same every run",
      s5[1] == "modules/a.lua" and s5[3] == "modules/z.lua",
      table.concat(s5, ","))
local sNil, sErr = straysSafe("core", nil, seen)
check("🚨 nil names answer an empty list rather than raising",
      sNil ~= nil and #sNil == 0, sErr)
local sDots = straysSafe("core", { ".", ".." }, {})
check(". and .. are never strays", sDots and #sDots == 0,
      sDots and table.concat(sDots, ","))

-- =====================================================================
out("\n=== 6. sizeOf — three outcomes against a real disk ===\n")
-- =====================================================================
local got, why = sizeOfSafe("init.lua")
check("a real file answers its real size", got == #FILES["init.lua"], got or why)
got, why = sizeOfSafe("modules/no-such-file.lua")
check("a missing file answers nil", got == nil)
check("…with the reason `missing`, which verdict reads", why == "missing", why)
got, why = sizeOfSafe("core")
-- A FOLDER where a file should be is not a size, and not an absence.
check("🚨 a FOLDER in a file's place is not a size", got == nil)
check("…and says a folder is there", tostring(why):find("FOLDER", 1, true) ~= nil, why)
-- 6.265.0: driving a path with the dependency MISSING is not the same as
-- driving it with the dependency REFUSING.
FS_ATTR_OVERRIDE = function() return { mode = "file" } end       -- no size
got, why = sizeOfSafe("init.lua")
check("🚨 a stat that answers without a size is not a size", got == nil)
check("…and says there was no size in the answer",
      tostring(why):find("no size", 1, true) ~= nil, why)
FS_ATTR_OVERRIDE = function() return "not a table" end
got, why = sizeOfSafe("init.lua")
check("🚨 a stat that answers something odd is refused, not indexed",
      got == nil and tostring(why):find("odd", 1, true) ~= nil, why)
FS_ATTR_OVERRIDE = function() error("hs.fs blew up", 0) end
got, why = sizeOfSafe("init.lua")
check("🚨 a stat that RAISES is caught — a report that throws is worse than one that lies",
      got == nil and tostring(why):find("raised", 1, true) ~= nil, why)
FS_ATTR_OVERRIDE = nil
check("…and the real stat still works afterwards",
      sizeOfSafe("init.lua") == #FILES["init.lua"])
check("🚨 …and the guard is the module's, not the suite's — sizeOf itself "
      .. "never raised", select(2, sizeOfSafe("init.lua")) == nil
      or tostring(select(2, sizeOfSafe("init.lua"))):find("RAISED") == nil)

-- =====================================================================
out("\n=== 7. the whole check, on real files ===\n")
-- =====================================================================
local res = ic.run()
check("a matching install is `ok`", res.state == "ok", res.state .. " " .. tostring(res.why))
check("…all six rows matched", res.ok == 6 and #res.bad == 0, res.ok)
check("…it counted the rows", res.rows == 6, res.rows)
check("…it read the version off the manifest", res.version == VERSION, res.version)
check("…and found no strays", #res.strays == 0, table.concat(res.strays, ","))
check("…and listed both folders", #res.unread == 0, table.concat(res.unread, ","))
check("…and neither walk hit its bound", #res.capped == 0, table.concat(res.capped, ","))
-- 🔕 SILENT WHEN HEALTHY (6.269.0): the boot line is the thing that must
-- not exist on a matching install.
check("🚨 a matching install produces NO boot line", ic.bootLine(res) == nil,
      ic.bootLine(res))
local blk = ic.block(res)
check("the block names the version", blk:find(VERSION, 1, true) ~= nil)
check("the block says all files are here", blk:find("all 6 runtime file", 1, true) ~= nil, blk)
check("…and names the limit it cannot see past",
      blk:find("same LENGTH", 1, true) ~= nil, blk)
check("…and says CHANGELOG.md is deliberately not in the manifest",
      blk:find("CHANGELOG.md", 1, true) ~= nil, blk)

-- A SHRUNK file: 6.311.0's exact failure, 107,414 against 116,595.
local SHRUNK = "-- old\n"
put(CFG .. "/modules/music_player.lua", SHRUNK)
res = ic.run()
check("a file at the wrong size makes the whole check `off`", res.state == "off", res.state)
check("…one row disagrees", #res.bad == 1, #res.bad)
check("…and it is the right row", res.bad[1] and res.bad[1].path == "modules/music_player.lua",
      res.bad[1] and res.bad[1].path)
check("…with state `size`", res.bad[1] and res.bad[1].state == "size", res.bad[1] and res.bad[1].state)
check("…the other five still matched", res.ok == 5, res.ok)
blk = ic.block(res)
check("the block says 1 of 6 disagree", blk:find("1 of 6", 1, true) ~= nil, blk)
-- 🚨 BOTH NUMBERS, read off the real files rather than typed in: a
-- fixture that states the answer cannot notice the answer changing.
check("…and carries BOTH byte counts for that row",
      blk:find(tostring(#FILES["modules/music_player.lua"]) .. " bytes", 1, true)
      and blk:find("has " .. tostring(#SHRUNK), 1, true), blk)
check("…and explains that a half-install boots green",
      blk:find("boots", 1, true) ~= nil, blk)
local line = ic.bootLine(res)
check("🔔 a disagreement DOES produce a boot line", type(line) == "string", line)
check("…which names the file", line and line:find("music_player", 1, true) ~= nil, line)
check("…and says the features are absent rather than broken",
      line and line:find("absent", 1, true) ~= nil, line)
check("…and tells him the one command to run",
      line and line:find("_G.installCheck()", 1, true) ~= nil, line)
put(CFG .. "/modules/music_player.lua", FILES["modules/music_player.lua"])

-- A DELETED file: `missing`, which is not `size` and not `unknown`.
os.remove(CFG .. "/core/notices.lua")
res = ic.run()
check("a deleted file is `missing`", res.bad[1] and res.bad[1].state == "missing",
      res.bad[1] and res.bad[1].state)
check("…and the check is `off`", res.state == "off", res.state)
put(CFG .. "/core/notices.lua", FILES["core/notices.lua"])

-- A stat that REFUSES for one file only: `unknown`, end to end.
FS_ATTR_OVERRIDE = function(path)
    if path:find("boot_cost", 1, true) then return { mode = "file" } end
    for _, cmd in ipairs({ "stat -c '%s %F' ", "stat -f '%z %HT' " }) do
        local p = io.popen(cmd .. "'" .. path .. "' 2>/dev/null")
        if p then
            local l = p:read("*l") ; p:close()
            local size, kind = tostring(l or ""):match("^(%d+)%s+(.*)$")
            if size then
                return { size = tonumber(size),
                         mode = (kind:lower():find("director") and "directory" or "file") }
            end
        end
    end
    return nil
end
res = ic.run()
check("🚨 a file macOS will not size is `unknown`, end to end",
      res.bad[1] and res.bad[1].state == "unknown", res.bad[1] and res.bad[1].state)
check("…and it is NOT reported as missing — a different fact, a different fix",
      res.bad[1] and res.bad[1].words:find("MISSING", 1, true) == nil,
      res.bad[1] and res.bad[1].words)
FS_ATTR_OVERRIDE = nil

-- =====================================================================
out("\n=== 8. no manifest — and it must NOT read as health ===\n")
-- =====================================================================
os.rename(CFG .. "/MANIFEST.txt", CFG .. "/MANIFEST.kept")
res = ic.run()
check("no manifest is its own state", res.state == "none", res.state)
check("…and says where it looked", res.why:find("MANIFEST.txt", 1, true) ~= nil, res.why)
check("…and checked nothing", res.rows == 0 and #res.bad == 0)
blk = ic.block(res)
-- 🚨 THE ASSERTION IS ON THE AFFIRMATIVE WORDING, not on the phrase "all
-- clear": the block deliberately QUOTES that phrase to deny it, so a
-- grep for it is green with the explanation deleted (6.262.0's
-- comment-stripper lesson, in a check).
check("🚨 it says NOTHING CAN BE SAID", blk:find("NOTHING CAN BE SAID", 1, true) ~= nil, blk)
check("🚨 …and never draws a ✅ about an install it did not check",
      blk:find("✅", 1, true) == nil, blk)
check("🚨 …and never prints the all-files-match sentence",
      blk:find("runtime file(s) are here", 1, true) == nil, blk)
check("…and it explains that this install predates the check",
      blk:find("predates", 1, true) ~= nil, blk)
check("…and the denial of 'all clear' is still in the words",
      blk:find("all clear", 1, true) ~= nil, blk)
-- 🔕 And it stays SILENT at boot: an install from before 6.399.0 has done
-- nothing wrong, and a line every morning about it is a line he stops
-- reading (6.269.0).
check("🚨 no manifest produces NO boot line", ic.bootLine(res) == nil, ic.bootLine(res))

-- =====================================================================
out("\n=== 9. a manifest that cannot be read ===\n")
-- =====================================================================
put(CFG .. "/MANIFEST.txt", "")
res = ic.run()
check("a zero-byte manifest is `unreadable`, not `none`", res.state == "unreadable", res.state)
check("…and says ZERO BYTES", res.why:find("ZERO BYTES", 1, true) ~= nil, res.why)
blk = ic.block(res)
check("the block shouts that nothing has been checked",
      blk:find("COULD NOT BE READ", 1, true) ~= nil, blk)
check("🚨 …and draws no ✅", blk:find("✅", 1, true) == nil, blk)
check("…and names the path", blk:find(CFG, 1, true) ~= nil, blk)
line = ic.bootLine(res)
check("🔔 an unreadable manifest DOES speak at boot", type(line) == "string", line)
check("…and names the reason", line and line:find("ZERO BYTES", 1, true) ~= nil, line)
put(CFG .. "/MANIFEST.txt", "# version: 6.399.0\nnot a row at all\n")
res = ic.run()
check("a manifest with no parseable rows is `unreadable`", res.state == "unreadable", res.state)
os.rename(CFG .. "/MANIFEST.kept", CFG .. "/MANIFEST.txt")

-- =====================================================================
out("\n=== 10. the manifest's own version against the running one ===\n")
-- =====================================================================
res = ic.run()
blk = ic.block(res)
check("a matching version says so plainly",
      blk:find("the manifest is for this release", 1, true) ~= nil, blk)
-- 🏷 THE HALF-INSTALL AT THE LEVEL OF THE WHOLE ARCHIVE: a new
-- MANIFEST.txt beside an old init.lua, or the other way round.
writeManifest("6.401.0")
res = ic.run()
blk = ic.block(res)
check("🚨 a manifest for another release SHOUTS",
      blk:find("THE MANIFEST IS FOR 6.401.0", 1, true) ~= nil, blk)
check("…and names the running version beside it",
      blk:find("AND THIS CONFIG IS " .. VERSION, 1, true) ~= nil, blk)
check("…and the files themselves can still all match",
      res.state == "ok", res.state)
writeManifest(nil)
res = ic.run()
blk = ic.block(res)
check("a manifest that names no release says that, rather than claiming a match",
      blk:find("does not say which release", 1, true) ~= nil, blk)
writeManifest(VERSION)

-- =====================================================================
out("\n=== 11. strays, end to end — Finder's Keep Both ===\n")
-- =====================================================================
put(CFG .. "/modules/music_player 2.lua", "-- the copy Finder made\n")
res = ic.run()
check("the stray is found", #res.strays == 1, table.concat(res.strays, ","))
check("…and named with its folder",
      res.strays[1] == "modules/music_player 2.lua", res.strays[1])
check("🚨 …and the FILES half is still ok — the original is untouched",
      res.state == "ok", res.state)
blk = ic.block(res)
check("the block names the stray", blk:find("music_player 2.lua", 1, true) ~= nil, blk)
check("…and explains that §1.12 ignores it so the original stays loaded",
      blk:find("Keep Both", 1, true) ~= nil, blk)
-- 📏 A STRAY IS NOT A HALF-INSTALL. The boot line is for files that
-- disagree; a stray is reported in the block, where there is room to
-- explain it. Said as a decision rather than left to be discovered.
check("a stray alone produces no boot line — the files all match",
      ic.bootLine(res) == nil, ic.bootLine(res))
os.remove(CFG .. "/modules/music_player 2.lua")
res = ic.run()
check("…and it is gone again once the file is", #res.strays == 0,
      table.concat(res.strays, ","))
blk = ic.block(res)
check("a clean tree says the folders hold only what shipped",
      blk:find("only what shipped", 1, true) ~= nil, blk)

-- =====================================================================
out("\n=== 12. a folder it could not read whole ===\n")
-- =====================================================================
local keptDirs = ic.strayDirs
ic.strayDirs = { "core", "modules", "no-such-folder" }
res = ic.run()
check("a folder that cannot be listed is NAMED", #res.unread == 1
      and res.unread[1] == "no-such-folder", table.concat(res.unread, ","))
blk = ic.block(res)
check("…and the block says the stray half is silent about it",
      blk:find("could not list: no-such-folder", 1, true) ~= nil, blk)
check("🚨 …and does NOT claim the folders hold only what shipped",
      blk:find("only what shipped", 1, true) == nil, blk)
ic.strayDirs = keptDirs
-- 🚨 6.197.2, AND THE SUITE IS WHAT FOUND IT: a walk stopped at its bound
-- was reporting its stray count as a total. A folder read half way down
-- that answers "strays: none" is the most reassuring sentence this module
-- can print about a folder it did not finish.
local keptMax = ic.strayMax
ic.strayMax = 2
res = ic.run()
check("🚨 a walk stopped at its bound is recorded", #res.capped > 0,
      table.concat(res.capped, ","))
blk = ic.block(res)
check("…and the block says the count is a FLOOR, not a total",
      blk:find("FLOOR", 1, true) ~= nil, blk)
check("…and quotes the bound that bit", blk:find("STOPPED AT 2 ENTRIES", 1, true) ~= nil, blk)
check("🚨 …and never prints the clean 'only what shipped' sentence",
      blk:find("only what shipped", 1, true) == nil, blk)
ic.strayMax = keptMax
res = ic.run()
check("…and a bound that fits records nothing", #res.capped == 0,
      table.concat(res.capped, ","))

-- =====================================================================
out("\n=== 13. warm — silent when healthy, the 🔔 door when not ===\n")
-- =====================================================================
printed, DEGRADES, TIMERS = {}, {}, {}
M.warm()
check("warm arms a timer rather than reading the disk on the boot path",
      #TIMERS == 1, #TIMERS)
check("…and HOLDS it, or an unreferenced timer is collected and never fires",
      ic.bootTimer == TIMERS[1])
check("…late, off the boot path", TIMERS[1] and TIMERS[1].secs == ic.sayAfter,
      TIMERS[1] and TIMERS[1].secs)
check("…and nothing has been said yet", #printed == 0 and #DEGRADES == 0)
local fired, ferr = fireTimer()
check("the armed timer could be fired at all", fired, ferr)
check("🔕 a healthy install says NOTHING when the timer lands",
      #DEGRADES == 0 and #printed == 0,
      table.concat(printed, " | ") .. " / " .. tostring(#DEGRADES))
check("…and the held timer is released once it has fired", ic.bootTimer == nil)

-- Now make it disagree and run the same path.
put(CFG .. "/init.lua", "-- short\n")
printed, DEGRADES, TIMERS = {}, {}, {}
M.warm()
fired, ferr = fireTimer()
check("the armed timer could be fired at all (off)", fired, ferr)
check("🔔 a half-install takes the degrade door", #DEGRADES == 1, #DEGRADES)
check("…named as the Install check", DEGRADES[1] and DEGRADES[1].tool == "Install check",
      DEGRADES[1] and DEGRADES[1].tool)
check("…and the reason is the boot line, not the whole fourteen-line block",
      DEGRADES[1] and DEGRADES[1].why:find("init.lua", 1, true)
      and not DEGRADES[1].why:find("\n", 1, true),
      DEGRADES[1] and DEGRADES[1].why)
check("…and it records that it spoke", ic.saidBoot == true)
-- A Mac with no degrade door still gets the line: this is the module
-- whose whole subject is not being told (6.215.0's fallback).
local keptDegrade = _G.degrade
_G.degrade = nil
printed, TIMERS = {}, {}
M.warm()
fireTimer()
check("🚨 a Mac where notices did not load still prints the line",
      #printed == 1 and printed[1]:find("Install check", 1, true) ~= nil,
      table.concat(printed, " | "))
_G.degrade = keptDegrade
-- A Mac that cannot arm a timer checks at once rather than not at all.
local keptDoAfter = hs.timer.doAfter
hs.timer.doAfter = function() error("no timers here", 0) end
printed, DEGRADES = {}, {}
ic.noBelt = 0
M.warm()
check("🚨 a Mac that cannot arm a timer still gets the check",
      #DEGRADES == 1, #DEGRADES)
check("…and the miss is COUNTED rather than assumed away", ic.noBelt == 1, ic.noBelt)
check("…and no timer is left recorded", ic.bootTimer == nil)
hs.timer.doAfter = keptDoAfter
put(CFG .. "/init.lua", FILES["init.lua"])

-- The switch is real: off means nothing is read at all.
ic.enabled = false
printed, DEGRADES, TIMERS = {}, {}, {}
M.warm()
check("the switch is real — off arms no timer and reads no disk",
      #TIMERS == 0 and #DEGRADES == 0 and #printed == 0)
ic.enabled = true

-- =====================================================================
out("\n=== 14. the door prints, and never throws ===\n")
-- =====================================================================
printed = {}
local doorOk = doorSafe()
check("the door does not raise on a healthy install", doorOk)
check("the door prints one block, as one string", #printed == 1, #printed)
check("…headed with the tool's name",
      printed[1] and printed[1]:find("🩺 INSTALL CHECK", 1, true) == 1,
      printed[1] and printed[1]:sub(1, 40))
-- 🚨 A REPORT THAT RAISES IS EVERY ASK IN THIS PROJECT ANSWERED WITH
-- NOTHING (6.282.0). The door pcalls the whole thing.
local keptRun = ic.run
ic.run = function() error("the check itself blew up", 0) end
printed = {}
doorOk = doorSafe()
check("🚨 a check that throws does NOT take the Console with it", doorOk)
check("🚨 a check that throws still prints a line", #printed == 1, #printed)
check("…saying the check failed rather than taking the Console with it",
      printed[1] and printed[1]:find("the check itself failed", 1, true) ~= nil,
      printed[1])
ic.run = keptRun

-- =====================================================================
out("\n=== 15. source sentries — the promises no behaviour can show ===\n")
-- =====================================================================
local stripped = SRC:gsub("\n%s*%-%-[^\n]*", "\n")
-- 🔒 IT NEVER WRITES. This module exists to describe the disk; a module
-- that could change it is a module that can break an install while
-- checking one.
check("🚨 it never opens a file for writing",
      stripped:find('io%.open%s*%(%s*[^,)]+,%s*"[wa]') == nil)
check("🚨 it never calls os.remove", stripped:find("os%.remove") == nil)
check("🚨 it never calls os.rename", stripped:find("os%.rename") == nil)
check("🚨 it never writes hs.settings", stripped:find("hs%.settings%.set") == nil)
-- ⏱ THE DISK READ IS IN warm, NEVER setup (6.267.0) — and this is a
-- FUNCTIONAL check in §1, not a grep here. A grep for `ic.run` inside
-- setup() goes red on correct code: `ic.block` legitimately falls back to
-- running the check when nothing has run yet, and it is DEFINED in setup.
-- A textual sentry cannot tell "called while setup executes" from
-- "called from a function setup defined", so it would be switched off
-- inside a week (6.269.0). The counter answers it exactly.
-- 6.282.0: every clock in a report goes through something that ANSWERS
-- rather than throws, and os.date refuses a float.
check("the one os.date is pcall'd", stripped:find("pcall%(function%(%) ic%.lastAt") ~= nil)
-- 🔎 hs.hash is NOT used, deliberately: its presence is a platform fact
-- this container cannot check in the source, and 6.233.0 forbids
-- designing on a belief. The limit is named in the report instead.
check("🚨 it does not reach for hs.hash on a belief about the platform",
      stripped:find("hs%.hash") == nil)
check("…and the module SAYS that is why, so the omission is a decision",
      SRC:find("hs.hash", 1, true) ~= nil and SRC:find("6.233.0", 1, true) ~= nil)
-- 6.199.0's temp-then-rename does not apply here (nothing is written),
-- but the `..` guard does, and its explanation quotes the thing it
-- forbids — so the sentry reads STRIPPED source and the comment is
-- asserted separately (6.280.0's shape).
check("the relInside guard walks components rather than searching for ..",
      stripped:find('part == "%.%."') ~= nil)
check("…and the reason it is a walk is written down",
      SRC:find("6.320.0", 1, true) ~= nil)

-- ---- clean up ----------------------------------------------------------
os.execute("rm -rf '" .. ROOT .. "'")

print = realPrint
out(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then
    out("\nFAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
os.exit(fail == 0 and 0 or 1)
