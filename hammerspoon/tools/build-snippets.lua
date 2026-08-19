#!/usr/bin/env lua
-- =====================================================================
-- BUILD-SNIPPETS — fold the shipped Alfred packs into one Lua table
-- =====================================================================
--     lua tools/build-snippets.lua .          ← writes snippets/bundled.lua
--     lua tools/build-snippets.lua . --check  ← verifies it is up to date
--
-- WHY. The bundled packs are 2,006 files of about 150 bytes of content
-- each, wrapped in JSON boilerplate, with names like
--     swords (crossed) [6914E66E-8F4A-4E9A-9D2B-FF7CD0BB0E3C].json
-- A zip pays for every one of those names in its central directory
-- whether or not the file compresses, so the packs cost 714 KB of a
-- 1.81 MB download to carry 130 KB of actual snippets. Folded into one
-- table they are 130 KB raw and 30 KB compressed — the whole download
-- goes to 1.15 MB — and the expander opens ONE file at reload instead of
-- two thousand and six.
--
-- 🚨 NEITHER THE PACKS NOR THIS OUTPUT GO INTO GIT. .gitignore excludes
-- snippets/ because textpanders holds real email addresses, phone
-- numbers, an employee ID and out-of-office text — and bundled.lua is
-- that SAME data in one file, so "it is only build output" is not a
-- reason to commit it. Both live in the working tree and travel in the
-- release zip. Run this before packaging; tests/test_expander.lua §17c
-- verifies the table matches the packs WHEREVER THE PACKS EXIST, and
-- says it skipped when they do not — a fresh clone has no snippets/ and
-- must still go green.
--
-- 🚨 THIS MIRRORS scanDir() IN modules/text_expander.lua, DELIBERATELY.
-- Same recursion, same per-directory info.plist prefix/suffix, same
-- "later one wins" collision rule, same keyword-less-means-chooser-only
-- rule. If that function changes, this one changes with it — otherwise
-- the shipped table stops matching what a directory scan would have
-- produced and nobody finds out until a trigger does nothing.

local root = arg[1] or "."
local check = false
for i = 2, #arg do if arg[i] == "--check" then check = true end end

local SRC  = root .. "/snippets"
local OUT  = SRC .. "/bundled.lua"

-- ---------------------------------------------------------------------
-- a JSON reader, because this runs under plain lua with no hs.json
-- ---------------------------------------------------------------------
-- Only what an Alfred snippet file contains: objects, arrays, strings,
-- numbers, true/false/null. Strings are decoded properly, escapes and
-- \uXXXX included — a pattern-match "parser" would mangle exactly the
-- snippets that need care (the ones with quotes and newlines in them).
local Json = {}

local escapes = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b',
                  f = '\f', n = '\n', r = '\r', t = '\t' }

local function utf8enc(cp)
    if utf8 and utf8.char then return utf8.char(cp) end
    return "?"
end

function Json.parse(s)
    local pos = 1

    local function err(m)
        error(m .. " at byte " .. pos, 0)
    end

    local function skip()
        while true do
            local c = s:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                pos = pos + 1
            else
                return
            end
        end
    end

    local value

    local function str()
        pos = pos + 1                      -- past the opening quote
        local out = {}
        while true do
            local c = s:sub(pos, pos)
            if c == "" then err("unterminated string") end
            if c == '"' then pos = pos + 1 return table.concat(out) end
            if c == "\\" then
                local e = s:sub(pos + 1, pos + 1)
                if e == "u" then
                    local hex = s:sub(pos + 2, pos + 5)
                    local cp = tonumber(hex, 16)
                    if not cp then err("bad \\u escape") end
                    pos = pos + 6
                    -- surrogate pair: the high half is meaningless alone
                    if cp >= 0xD800 and cp <= 0xDBFF
                       and s:sub(pos, pos + 1) == "\\u" then
                        local lo = tonumber(s:sub(pos + 2, pos + 5), 16)
                        if lo and lo >= 0xDC00 and lo <= 0xDFFF then
                            cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
                            pos = pos + 6
                        end
                    end
                    out[#out + 1] = utf8enc(cp)
                else
                    local m = escapes[e]
                    if not m then err("bad escape \\" .. e) end
                    out[#out + 1] = m
                    pos = pos + 2
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
    end

    local function obj()
        pos = pos + 1
        local t = {}
        skip()
        if s:sub(pos, pos) == "}" then pos = pos + 1 return t end
        while true do
            skip()
            if s:sub(pos, pos) ~= '"' then err("expected a key") end
            local k = str()
            skip()
            if s:sub(pos, pos) ~= ":" then err("expected ':'") end
            pos = pos + 1
            t[k] = value()
            skip()
            local c = s:sub(pos, pos)
            pos = pos + 1
            if c == "}" then return t end
            if c ~= "," then err("expected ',' or '}'") end
        end
    end

    local function arr()
        pos = pos + 1
        local t = {}
        skip()
        if s:sub(pos, pos) == "]" then pos = pos + 1 return t end
        while true do
            t[#t + 1] = value()
            skip()
            local c = s:sub(pos, pos)
            pos = pos + 1
            if c == "]" then return t end
            if c ~= "," then err("expected ',' or ']'") end
        end
    end

    value = function()
        skip()
        local c = s:sub(pos, pos)
        if c == "{" then return obj() end
        if c == "[" then return arr() end
        if c == '"' then return str() end
        if s:sub(pos, pos + 3) == "true"  then pos = pos + 4 return true end
        if s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false end
        if s:sub(pos, pos + 3) == "null"  then pos = pos + 4 return nil end
        local n, e = s:match("^(%-?%d+%.?%d*[eE]?[-+]?%d*)()", pos)
        if n then pos = e return tonumber(n) end
        err("unexpected character " .. string.format("%q", c))
    end

    -- a BOM is not an error, it is Windows
    if s:sub(1, 3) == "\239\187\191" then pos = 4 end
    local v = value()
    return v
end

-- ---------------------------------------------------------------------
-- the filesystem, via ls
-- ---------------------------------------------------------------------
local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local c = f:read("*a")
    f:close()
    return c
end

-- A pack name may contain spaces and brackets, so entries come back one
-- per line and are used whole. No shell glob, no word splitting.
--
-- `ls -p` marks directories with a trailing slash, which answers "is this
-- a directory" for the whole listing in ONE process. The obvious version
-- of this ran `test -d` per entry and spent two thousand subprocesses
-- learning what one `ls` already said.
local function entries(dir)
    local out = {}
    local p = io.popen('ls -A -p "' .. dir .. '" 2>/dev/null')
    if not p then return out end
    for line in p:lines() do
        if line:sub(-1) == "/" then
            out[#out + 1] = { name = line:sub(1, -2), dir = true }
        else
            out[#out + 1] = { name = line, dir = false }
        end
    end
    p:close()
    -- 🚨 SORTED: the build must not depend on the order the filesystem
    -- hands things back, or the same packs rebuild to a different file on
    -- a different Mac and --check fails for no reason at all.
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function isDir(path)
    local p = io.popen('test -d "' .. path .. '" && echo y')
    if not p then return false end
    local r = p:read("*l")
    p:close()
    return r == "y"
end

-- ---------------------------------------------------------------------
-- the same rules text_expander applies
-- ---------------------------------------------------------------------
local MAXCHARS = 2000        -- exp.maxChars

local function clen(s)
    local n = utf8 and utf8.len(s)
    return n or #s
end

local function readPlist(dir)
    local c = read(dir .. "/info.plist")
    if not c then return "", "" end
    local function val(key)
        local v = c:match("<key>" .. key .. "</key>%s*<string>(.-)</string>")
        return v or ""
    end
    return val("snippetkeywordprefix"), val("snippetkeywordsuffix")
end

local function readSnippet(path, prefix, suffix)
    local raw = read(path)
    if not raw then return nil, nil, nil, "unreadable" end
    local ok, obj = pcall(Json.parse, raw)
    if not (ok and type(obj) == "table") then
        return nil, nil, nil, "not valid JSON"
    end
    local s = obj.alfredsnippet
    if type(s) ~= "table" then return nil, nil, nil, "no alfredsnippet key" end
    local text = s.snippet
    if type(text) ~= "string" or text == "" then
        return nil, nil, nil, "empty snippet"
    end
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    if clen(text) > MAXCHARS then
        return nil, nil, nil, string.format("%d characters — over the %d limit",
                                            clen(text), MAXCHARS)
    end
    local name = s.name
    if type(name) ~= "string" or name == "" then name = nil end
    local kw = s.keyword
    if type(kw) ~= "string" or kw == "" then
        return nil, text, name, nil
    end
    return prefix .. kw .. suffix, text, name or kw, nil
end

-- ---------------------------------------------------------------------
-- the walk
-- ---------------------------------------------------------------------
local packs, packIndex = {}, {}
local triggers, order  = {}, {}     -- order keeps the output deterministic
local chooserOnly      = {}
local collisions       = {}
local problems         = {}
local fileCount        = 0

local function packFor(label)
    if not packIndex[label] then
        packs[#packs + 1]  = { label, 0 }
        packIndex[label]   = #packs
    end
    return packIndex[label]
end

local function scanDir(dir, label)
    local prefix, suffix = readPlist(dir)
    local subdirs = {}
    for _, e in ipairs(entries(dir)) do
        local entry = e.name
        local full  = dir .. "/" .. entry
        if e.dir then
            subdirs[#subdirs + 1] = { full, entry }
        elseif entry:sub(-5) == ".json" then
            fileCount = fileCount + 1
            local trigger, text, name, reason = readSnippet(full, prefix, suffix)
            local pi = packFor(label)
            if trigger then
                if triggers[trigger] then
                    collisions[#collisions + 1] = string.format(
                        "%s: trigger %s already used by %s — the later one wins",
                        label, trigger, tostring(triggers[trigger][2]))
                else
                    order[#order + 1] = trigger
                end
                triggers[trigger] = { text, name, pi }
                packs[pi][2] = packs[pi][2] + 1
            elseif text then
                chooserOnly[#chooserOnly + 1] =
                    { text, name or entry:gsub("%.json$", ""), pi }
            else
                problems[#problems + 1] = label .. "/" .. entry
                                          .. ": " .. tostring(reason)
            end
        end
    end
    for _, d in ipairs(subdirs) do scanDir(d[1], d[2]) end
end

-- 🚨 A MISSING snippets/ IS A SKIP FOR --check, NOT A FAILURE. The packs
-- are gitignored, so a fresh clone genuinely has none, and there is no
-- drift to find between a table and packs that are not there. Asked to
-- BUILD, though, this is a real error: you cannot generate a table from
-- nothing, and pretending otherwise would write an empty one over a good
-- file.
if not isDir(SRC) then
    if check then
        print("⏭  no snippets/ here — nothing to check the table against")
        os.exit(0)
    end
    io.stderr:write("no snippets directory at " .. SRC .. "\n")
    os.exit(1)
end
scanDir(SRC, "bundled")

-- 🚨 6.115.0 — AND A snippets/ THAT HOLDS ONLY THE TABLE IS ALSO A SKIP.
-- The branch above catches a fresh clone, where snippets/ does not exist
-- at all. It does NOT catch THE SHIPPED ZIP, which is the tree LL
-- actually installs from: the release packages snippets/bundled.lua and
-- deliberately leaves the source packs out, because textpanders holds
-- real email addresses, a phone number and an employee ID. So the
-- directory exists, scanDir finds nothing in it, an EMPTY table is
-- generated, and comparing that to the real one reports STALE.
--
-- Found by running the suite against the unzipped tree rather than the
-- repo — which is the only place it shows, and is why it survived from
-- 6.105.0 to here. The symptom is the worst possible one for a release:
-- "❌ 1 stage(s) failed. Do not ship this." on a tree that is correct.
--
-- ⚖️ THIS DOES NOT WEAKEN THE SENTRY. With no packs on disk there is
-- nothing to have drifted FROM; the check is unverifiable, not passed,
-- and it says so in those words. Any machine that has the packs — the
-- one place drift can actually happen, since that is where a pack gets
-- edited — still compares byte for byte.
if check and fileCount == 0 then
    local existing = read(OUT)
    if existing and #existing > 0 then
        print("⏭  snippets/ has the table but no source packs — nothing to "
              .. "check it against (this is the shipped zip; the packs are "
              .. "deliberately not distributed)")
        os.exit(0)
    end
end

-- ---------------------------------------------------------------------
-- the output
-- ---------------------------------------------------------------------
local q = function(s) return string.format("%q", s) end

local out = {}
local function w(s) out[#out + 1] = s end

w("-- =====================================================================")
w("-- BUNDLED SNIPPETS — GENERATED FILE, DO NOT EDIT BY HAND")
w("-- =====================================================================")
w("-- Built by tools/build-snippets.lua from the Alfred packs in the")
w("-- snippets/ directory, which remain the source of truth. Edit a pack,")
w("-- re-run the builder before packaging; tests/test_expander.lua checks")
w("-- that this file still matches the packs, so drift is caught.")
w("--")
w("-- Not in git. Neither are the packs — textpanders holds real email")
w("-- addresses, phone numbers and an employee ID, and this file is that")
w("-- same data in one place. It travels in the release zip only.")
w("--")
w("-- modules/text_expander.lua prefers this file when it is present and")
w("-- falls back to walking the .json files when it is not, so a build")
w("-- without it still works — it just reads two thousand files to do it.")
w("--")
w("-- Your OWN snippets do not live here. ~/.hammerspoon/Logs/snippets is")
w("-- still scanned as .json and still wins on a collision.")
w("--")
w("--   triggers[trigger] = { text, name, packIndex }")
w("--   chooserOnly[i]    = { text, name, packIndex }   -- no keyword")
w("-- =====================================================================")
w("")
w("return {")
w("    version = 1,")
w(string.format("    packs = {"))
for _, p in ipairs(packs) do
    w(string.format("        { %s, %d },", q(p[1]), p[2]))
end
w("    },")

w("    triggers = {")
table.sort(order)
for _, t in ipairs(order) do
    local v = triggers[t]
    w(string.format("        [%s] = { %s, %s, %d },",
                    q(t), q(v[1]), v[2] and q(v[2]) or "nil", v[3]))
end
w("    },")

w("    chooserOnly = {")
table.sort(chooserOnly, function(a, b)
    if a[2] ~= b[2] then return tostring(a[2]) < tostring(b[2]) end
    return a[1] < b[1]
end)
for _, c in ipairs(chooserOnly) do
    w(string.format("        { %s, %s, %d },", q(c[1]), q(c[2]), c[3]))
end
w("    },")

-- Collisions and problems travel WITH the table so the module reports
-- them exactly as a live scan would. A snippet that did not load is a
-- trigger you will type and watch do nothing, and that stays true when
-- the loading happened at build time.
w("    collisions = {")
table.sort(collisions)
for _, c in ipairs(collisions) do w(string.format("        %s,", q(c))) end
w("    },")
w("    problems = {")
table.sort(problems)
for _, p in ipairs(problems) do w(string.format("        %s,", q(p))) end
w("    },")
w("}")
w("")

local text = table.concat(out, "\n")

local nTrig = #order
if check then
    local have = read(OUT)
    if have == text then
        print(string.format("✅ snippets/bundled.lua is current — %d triggers, "
                            .. "%d chooser-only, %d files", nTrig, #chooserOnly,
                            fileCount))
        os.exit(0)
    end
    io.stderr:write("❌ snippets/bundled.lua is STALE — run: "
                    .. "lua tools/build-snippets.lua .\n")
    os.exit(1)
end

local f = io.open(OUT, "w")
if not f then
    io.stderr:write("cannot write " .. OUT .. "\n")
    os.exit(1)
end
f:write(text)
f:close()

print(string.format("📦 %s", OUT))
print(string.format("   %d files → %d triggers, %d chooser-only, %d packs",
                    fileCount, nTrig, #chooserOnly, #packs))
if #collisions > 0 then
    print(string.format("   %d collision(s) recorded", #collisions))
end
if #problems > 0 then
    print(string.format("   %d snippet(s) did not load:", #problems))
    for _, p in ipairs(problems) do print("     · " .. p) end
end
print(string.format("   %d bytes", #text))
