#!/usr/bin/env lua
-- =====================================================================
-- BUILD-FEATURE-LIST — every feature and how to use it, as plain text
-- =====================================================================
--     lua tools/build-feature-list.lua .          ← writes RESOLVED-FEATURE-REQUESTS.txt
--     lua tools/build-feature-list.lua . --check  ← verifies it is current
--
-- 6.217.0 — LL: "how about giving me a list of features and how to use
-- them in a plain text file I can reference each time you generate the
-- zip file, 'Resolved Feature Requests'." GUIDE.md is that list at
-- 900 KB; this is the one-page version, GENERATED so it can never be
-- stale: every module's own cheat sheet (the same rows ⇪/ draws),
-- grouped by family, the automatic tools as one line each, the core
-- keys init.lua still binds, then a release index read straight from
-- CHANGELOG.md's NEW IN headers — newest first, so "did I ask for that
-- and was it done?" is a search of this file. It runs with plain
-- lua5.4 (no Mac): a module is executed only far enough to return its
-- table; setup() is never called. A module that cannot be read is
-- NAMED in the file rather than silently missing.
-- =====================================================================
local HS = arg and arg[1] or "."
local CHECK = arg and arg[2] == "--check"
local OUT = HS .. "/RESOLVED-FEATURE-REQUESTS.txt"

local function readAll(p) local f = io.open(p, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s end

-- a stub hs so a module's top level (rarely) touching hs.* does not throw
local function anything() return setmetatable({}, { __call = function() return anything() end,
    __index = function() return anything() end }) end
hs = anything()
_G.diag = anything()

local init = readAll(HS .. "/init.lua") or ""
local version = init:match("ARCHITECTURE VERSION CONTROL: ([%d%.]+)") or "?"

local families = {
    { id = "windows", title = "🪟 WINDOWS & POINTER — where things sit on screen" },
    { id = "capture", title = "🗒 CAPTURE & TASKS — anything that takes something in" },
    { id = "find",    title = "🔎 FIND & OPEN — search anything, open anything" },
    { id = "files",   title = "📁 FILES & DOCUMENTS" },
    { id = "text",    title = "✂️ TEXT & CLIPBOARD — what happens to text as it moves" },
    { id = "screen",  title = "📸 SCREEN CAPTURE" },
    { id = "time",    title = "⏱ TIME & ATTENTION — the day, and what interrupts it" },
    { id = "config",  title = "🩺 THE CONFIG ITSELF" },
    { id = "misc",    title = "🧩 NOT YET FILED" },
}

-- every module, executed only to its `return M`
local names = {}
do
    local p = io.popen('ls "' .. HS .. '/modules"/*.lua 2>/dev/null')
    if p then for line in p:lines() do names[#names + 1] = line end; p:close() end
end
table.sort(names)
local groups, autos, unreadable = {}, {}, {}
for _, path in ipairs(names) do
    local id = path:match("([^/]+)%.lua$")
    local chunk, err = loadfile(path)
    local ok, M = false, nil
    if chunk then ok, M = pcall(chunk) end
    if not (ok and type(M) == "table") then
        unreadable[#unreadable + 1] = id .. " — " .. tostring(err or M)
    else
        local sheets = M.cheatsheet
        if type(sheets) == "table" and sheets.title then sheets = { sheets } end
        if M.family == "auto" then
            autos[#autos + 1] = { id = id, name = M.name or id, summary = M.summary or "" }
        elseif type(sheets) == "table" then
            for _, g in ipairs(sheets) do
                local fam = g.family or M.family or "misc"
                groups[fam] = groups[fam] or {}
                table.insert(groups[fam], { order = M.order or 999, id = id, title = g.title or M.name or id,
                                            entries = g.entries or {} })
            end
        end
    end
end

-- the keys init.lua still binds itself (the hint module's coreRows table)
local coreRows = {}
do
    local hints = readAll(HS .. "/modules/shortcut_hints.lua") or ""
    local block = hints:match("coreRows%s*=%s*{(.-)\n%s*},")
    for k, v in (block or ""):gmatch('%["([^"]+)"%]%s*=%s*"([^"]*)"') do coreRows[#coreRows + 1] = { k, v } end
end

-- the release index, newest first, from CHANGELOG.md
local releases = {}
do
    local log = readAll(HS .. "/CHANGELOG.md") or ""
    for v, title in log:gmatch("\nNEW IN ([%d%.]+) — ([^\n]*)") do releases[#releases + 1] = { v, (title:gsub(":%s*$", "")) } end
end

local L = {}
local function line(s) L[#L + 1] = s or "" end
local function rule() line(string.rep("=", 72)) end
rule()
line("RESOLVED FEATURE REQUESTS — Hammerspoon config " .. version)
line("Every feature and how to use it. Generated from the modules' own")
line("cheat sheets (the rows ⇪/ draws), so it is never out of date.")
line("⇪ = Caps Lock held (the hyper key). ⇪⇧X = Caps Lock + Shift + X.")
line("In the Console, _G.<tool>Report() prints any tool's own report.")
rule()
for _, fam in ipairs(families) do
    local list = groups[fam.id]
    if list and #list > 0 then
        table.sort(list, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.id < b.id end)
        line(); line(fam.title); line(string.rep("-", #fam.title > 72 and 72 or 72))
        for _, g in ipairs(list) do
            line(); line(g.title .. "   [modules/" .. g.id .. ".lua]")
            for _, e in ipairs(g.entries) do
                local k, d = tostring(e[1] or ""), tostring(e[2] or "")
                if k == "" then line("            " .. d) else line(string.format("  %-9s %s", k, d)) end
            end
        end
    end
end
if #autos > 0 then
    line(); line("⚙️ RUNS ITSELF — nothing to press, listed so you know it is there"); line(string.rep("-", 72))
    table.sort(autos, function(a, b) return a.id < b.id end)
    for _, a in ipairs(autos) do line(string.format("  %-22s %s", a.name, a.summary)) end
end
if #coreRows > 0 then
    line(); line("🔑 CORE KEYS — bound by init.lua itself"); line(string.rep("-", 72))
    table.sort(coreRows, function(a, b) return a[1] < b[1] end)
    for _, r in ipairs(coreRows) do line(string.format("  %-9s %s", r[1], r[2])) end
end
if #unreadable > 0 then
    line(); line("⚠️ MODULES THIS LIST COULD NOT READ (a bug in the builder or the module):")
    for _, u in ipairs(unreadable) do line("  " .. u) end
end
line(); line("📜 RELEASE INDEX — newest first, one line per release (the full story of each is in CHANGELOG.md)"); line(string.rep("-", 72))
for _, r in ipairs(releases) do line(string.format("  %-8s %s", r[1], r[2])) end
line()
local text = table.concat(L, "\n")

if CHECK then
    local have = readAll(OUT)
    if have == text then print("✅ RESOLVED-FEATURE-REQUESTS.txt is current — " .. #releases .. " releases, " .. #names .. " modules"); os.exit(0) end
    print("❌ RESOLVED-FEATURE-REQUESTS.txt is stale — run: lua5.4 tools/build-feature-list.lua ."); os.exit(1)
end
local f = assert(io.open(OUT, "w")); f:write(text); f:close()
print("✍️  wrote " .. OUT .. " — " .. #releases .. " releases, " .. #names .. " modules" .. (#unreadable > 0 and (", " .. #unreadable .. " unreadable") or ""))
