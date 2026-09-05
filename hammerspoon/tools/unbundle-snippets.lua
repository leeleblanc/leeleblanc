#!/usr/bin/env lua
-- =====================================================================
-- UNBUNDLE-SNIPPETS — turn snippets/bundled.lua back into pack folders
-- =====================================================================
--     lua tools/unbundle-snippets.lua <bundled.lua> <publicDir> <privateDir>
--
-- The inverse of build-snippets.lua, for the one Mac where the folded
-- table is the ONLY copy of the packs (the .json packs were never kept
-- after 6.117.0 folded them). Every pack EXCEPT textpanders is written
-- under <publicDir>/<pack>/ (emoji, compose sequences, symbols — no
-- personal data, so they can live in git); textpanders goes under
-- <privateDir>/textpanders/ — meant to be the OneDrive snippets folder
-- (exp.dir), which is scanned as .json and follows LL to every Mac.
--
-- Runs under plain lua OR inside the Hammerspoon Console
-- (dofile with arg set — see the NEW IN block). Own JSON writer so it
-- needs no hs.json. Output files use the same shape as exp.add():
--     { alfredsnippet = { keyword, snippet, name, uid } }
-- The trigger is written WHOLE as the keyword (the original per-pack
-- prefix/suffix cannot be recovered from the table, and need not be —
-- with no info.plist beside it, scanDir uses the keyword as-is).
-- =====================================================================

local args = arg or _G.UNBUNDLE_ARGS or {}
local src, publicDir, privateDir = args[1], args[2], args[3]
if not (src and publicDir and privateDir) then
    error("usage: unbundle-snippets.lua <bundled.lua> <publicDir> <privateDir>", 0)
end

local PRIVATE = { textpanders = true }

local chunk, err = loadfile(src, "t", {})
if not chunk then error("cannot load " .. src .. ": " .. tostring(err), 0) end
local t = chunk()
if type(t) ~= "table" or t.version ~= 1 then
    error(src .. " is not a version-1 bundled table", 0)
end

local function mkdir(p)
    if os.execute(string.format('mkdir -p "%s"', p)) ~= true
       and os.execute(string.format('mkdir -p "%s"', p)) ~= 0 then
        error("cannot create " .. p, 0)
    end
end

local function jstr(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        if c == "\n" then return "\\n" end
        if c == "\r" then return "\\r" end
        if c == "\t" then return "\\t" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end

local used = {}
local function fileFor(dir, base)
    local safe = base:gsub("[^%w]", "_")
    if safe == "" then safe = "snippet" end
    local n, name = 0, safe
    while used[dir .. "/" .. name] do
        n = n + 1
        name = safe .. "_" .. n
    end
    used[dir .. "/" .. name] = true
    return dir .. "/" .. name .. ".json", name
end

local counts = {}
local function write(packIdx, keyword, text, name)
    local pack = t.packs[packIdx] and t.packs[packIdx][1] or ("pack" .. packIdx)
    local root = PRIVATE[pack] and privateDir or publicDir
    local dir  = root .. "/" .. pack
    if not counts[dir] then mkdir(dir); counts[dir] = 0 end
    local path, uid = fileFor(dir, keyword or name or "snippet")
    local body = "{\"alfredsnippet\":{"
        .. (keyword and ("\"keyword\":" .. jstr(keyword) .. ",") or "")
        .. "\"snippet\":" .. jstr(text) .. ","
        .. "\"name\":" .. jstr(name or keyword or uid) .. ","
        .. "\"uid\":" .. jstr(uid) .. "}}"
    local f = assert(io.open(path, "w"))
    f:write(body); f:close()
    counts[dir] = counts[dir] + 1
end

local keys = {}
for k in pairs(t.triggers) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do
    local v = t.triggers[k]
    write(v[3], k, v[1], v[2])
end
for _, c in ipairs(t.chooserOnly or {}) do
    write(c[3], nil, c[1], c[2])
end

local dirs = {}
for d in pairs(counts) do dirs[#dirs + 1] = d end
table.sort(dirs)
for _, d in ipairs(dirs) do print(string.format("%5d  %s", counts[d], d)) end
