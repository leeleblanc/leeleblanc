-- =====================================================================
-- test_rename.lua — the module whose worst failure DESTROYS YOUR FILES
-- =====================================================================
--     lua5.4 test_rename.lua [/path/to/hammerspoon]
--
-- Every other module in this config fails by not working. This one can
-- fail by renaming `a.mp4` onto `b.mp4` and deleting `b` forever, or by
-- moving a video and orphaning its subtitle so playback silently loses
-- captions. os.rename() gives no warning and no undo for either.
--
-- So the properties here are not "does the rule produce a nice name".
-- They are:
--
--   P1  NO FILE IS EVER LOST — every input path appears exactly once as
--       a rename source or is left alone. Count in == count out.
--   P2  NO TWO FILES EVER LAND ON ONE NAME, and if they would, the plan
--       reports a problem instead of returning a destructive plan.
--   P3  SIDECARS FOLLOW THEIR VIDEO. If a.mp4 and a.srt go in, they come
--       out sharing a stem. This is the whole point of the module.
--   P4  APPLY IS REVERSIBLE — the undo plan restores every original path.
--   P5  NO RULE EVER THROWS, and no rule ever produces an empty name.
--
-- The generator builds messy real-world folders: mixed quality tags,
-- release groups, subtitle language tails, files that already collide,
-- names with pattern metacharacters, and the exact inconsistent season
-- from the screenshot that prompted the module.

local HS = (arg and arg[1]) or os.getenv("HAMMERSPOON_DIR")
           or ((os.getenv("HOME") or ".") .. "/.hammerspoon")

local pass, fail, failures = 0, 0, {}
local function check(label, cond, extra)
    if cond then pass = pass + 1
    else fail = fail + 1
         failures[#failures + 1] = label .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end
local function out(s) io.write(s) end

-- ---- a filesystem that lives in a table ------------------------------
-- br.exists is overridden per-test, so planning can be exercised against
-- any world without touching a real disk.
local DISK = {}
local printed, ALERTS = {}, {}
print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(p, " ")
end

local HYPER, PROVIDED, WROTE = {}, {}, {}
hs = {
    fs = { attributes = function(p) return DISK[p] and { mode = "file" } or nil end },
    alert = { show = function(m) ALERTS[#ALERTS + 1] = tostring(m) end },
    chooser = { new = function(fn)
        local c = { fn = fn }
        for _, m in ipairs({ "searchSubText", "width", "placeholderText",
                             "choices", "show" }) do
            c[m] = function(self) return self end
        end
        return c end },
    dialog = { textPrompt = function() return "Cancel", "" end },
    osascript = { applescript = function() return false, nil end },
    json = { encode = function(t)
                 -- Enough of a serialiser for the undo round-trip test.
                 local parts = {}
                 for _, it in ipairs(t.items or {}) do
                     parts[#parts + 1] = it.from .. "\1" .. it.to
                 end
                 return table.concat(parts, "\2") end,
             decode = function(s)
                 local items = {}
                 for chunk in tostring(s):gmatch("[^\2]+") do
                     local f, t = chunk:match("^(.-)\1(.*)$")
                     if f then items[#items + 1] = { from = f, to = t } end
                 end
                 return { items = items } end },
    pasteboard = { setContents = function() return true end },
    timer = { secondsSinceEpoch = function() return 1000 end },
}
_G.diag = { say = function() end, warn = function() end,
            err = function() end, mark = function() end }

local CORE = {
    hostTag = "Test-Mac", logsDir = "/tmp/brtest",
    warnWriteFailed = function() end,
    hyperAddShortcut = function(mods, key, fn)
        local ms = {} ; for _, x in ipairs(mods or {}) do ms[#ms + 1] = x end
        table.sort(ms) ; HYPER[table.concat(ms, "+") .. "|" .. key] = fn end,
    provide = function(n, f) PROVIDED[n] = f end,
}

local M = dofile(HS .. "/modules/bulk_rename.lua")
M.setup(CORE)
local BR = _G.bulkRename
BR.exists = function(p) return DISK[p] == true end

-- =====================================================================
out("\n=== 1. Contract ===\n")
-- =====================================================================
check("the module returns name, order and a cheatsheet",
      M.name == "Bulk Rename" and type(M.order) == "number"
      and type(M.cheatsheet) == "table")
check("it claims ⇪R but NOT ⇪⇧R — ⇪⇧R already resets the nudge offset "
      .. "via §0.4's migration map; undo lives on the picker's first row "
      .. "instead, see §3", HYPER["|r"] ~= nil and HYPER["shift|r"] == nil)
check("it publishes its planner rather than exposing a global",
      PROVIDED["rename.plan"] ~= nil and PROVIDED["rename.groups"] ~= nil)
check("its cheat-sheet order does not collide with menubar_items (13.9)",
      M.order ~= 13.9)

-- =====================================================================
out("\n=== 2. Splitting names — where subtitles are won or lost ===\n")
-- =====================================================================
local d, s, e = BR.splitPath("/a/b/Dark.Matter.2024.S01E01.108.mp4")
check("splitPath finds dir, stem and extension",
      d == "/a/b" and s == "Dark.Matter.2024.S01E01.108" and e == "mp4",
      d .. " | " .. s .. " | " .. e)

local base, tail = BR.splitTail("Dark.Matter.S01E01.en")
check("a known language tail is split off a subtitle stem",
      base == "Dark.Matter.S01E01" and tail == "en", base .. " | " .. tail)

base, tail = BR.splitTail("Dark.Matter.2024")
check("🚨 A YEAR IS NOT A LANGUAGE TAIL — splitting it would silently "
      .. "delete the year from every name in the batch",
      base == "Dark.Matter.2024" and tail == "", base .. " | " .. tail)

base, tail = BR.splitTail("Movie.forced")
check("'forced' is recognised as a subtitle tail",
      base == "Movie" and tail == "forced")

-- =====================================================================
out("\n=== 3. Grouping — the subtitle guarantee ===\n")
-- =====================================================================
local g = BR.group({
    "/v/Show.S01E01.mp4", "/v/Show.S01E01.srt", "/v/Show.S01E01.en.srt",
    "/v/Show.S01E02.mp4", "/v/Show.S01E02.srt",
})
check("five files collapse into two groups", #g == 2, #g)
check("the first group carries all three of its members", #g[1].members == 3,
      #g[1].members)
check("the language tail is preserved on the member, not the group",
      (function()
          for _, m in ipairs(g[1].members) do
              if m.tail == "en" and m.ext == "srt" then return true end
          end
      end)())

-- =====================================================================
out("\n=== 4. The screenshot, exactly ===\n")
-- =====================================================================
-- One episode named differently from the other eight. This is the folder
-- that prompted the module, and it is the test that matters most.
local SHOT = {
    "/tv/Dark.Matter.2024.S01E01.108.mp4",
    "/tv/Dark.Matter.2024.S01E01.108.srt",
}
for i = 2, 9 do
    SHOT[#SHOT + 1] = string.format(
        "/tv/Dark.Matter.2024.S01E%02d.1080p.ATVP-[y2flix.cc].mp4", i)
    SHOT[#SHOT + 1] = string.format(
        "/tv/Dark.Matter.2024.S01E%02d.1080p.ATVP-[y2flix.cc].srt", i)
end
DISK = {} ; for _, p in ipairs(SHOT) do DISK[p] = true end

local plan, problems = BR.plan(SHOT, "tv")
check("the tv rule plans without a single problem", #problems == 0,
      problems[1])
local byName = {}
for _, it in ipairs(plan) do byName[it.from] = it.name end
check("🚨 THE ODD EPISODE OUT LANDS ON THE SAME SHAPE AS ITS SIBLINGS — "
      .. "E01 was named '.108' and every other episode "
      .. "'.1080p.ATVP-[y2flix.cc]'",
      byName["/tv/Dark.Matter.2024.S01E01.108.mp4"]
        == "Dark.Matter.2024.S01E01.mp4",
      byName["/tv/Dark.Matter.2024.S01E01.108.mp4"])
check("and E09 lands on the matching name",
      byName["/tv/Dark.Matter.2024.S01E09.1080p.ATVP-[y2flix.cc].mp4"]
        == "Dark.Matter.2024.S01E09.mp4",
      byName["/tv/Dark.Matter.2024.S01E09.1080p.ATVP-[y2flix.cc].mp4"])
check("🚨 EVERY SUBTITLE ENDS UP MATCHING ITS VIDEO — the failure here is "
      .. "silent: playback simply loses captions",
      (function()
          local stems = {}
          for _, it in ipairs(plan) do
              local st = it.name:match("^(.*)%.[^.]+$")
              stems[st] = (stems[st] or 0) + 1
          end
          for st, n in pairs(stems) do
              if n ~= 2 then return false, st .. " has " .. n end
          end
          return true
      end)())
check("the year survives — it is not mistaken for a language tail",
      (byName["/tv/Dark.Matter.2024.S01E01.108.mp4"] or ""):find("2024", 1, true) ~= nil)
check("all 18 files are accounted for", #plan == 18, #plan)

-- =====================================================================
out("\n=== 5. Refusing to destroy things ===\n")
-- =====================================================================
DISK = { ["/v/a.1080p.mp4"] = true, ["/v/a.mp4"] = true }
local p2, prob2 = BR.plan({ "/v/a.1080p.mp4" }, "junk")
check("🚨 STRIPPING A TAG ONTO AN EXISTING FILE IS REFUSED — os.rename "
      .. "would have destroyed the bystander with no warning",
      #prob2 > 0, prob2[1] or "no problem reported")

DISK = { ["/v/x.1080p.mp4"] = true, ["/v/x.720p.mp4"] = true }
local p3, prob3 = BR.plan({ "/v/x.1080p.mp4", "/v/x.720p.mp4" }, "junk")
check("two files in the batch collapsing onto one name is refused too",
      #prob3 > 0, prob3[1] or "no problem reported")

DISK = {}
local p4, prob4 = BR.plan({ "/v/clean.mp4" }, "junk")
check("a file the rule does not change produces an empty plan, not a "
      .. "rename-to-itself", #p4 == 0 and #prob4 == 0, #p4)

-- =====================================================================
out("\n=== 6. Two-phase apply survives a swap ===\n")
-- =====================================================================
-- A real filesystem, in a table. os.rename is replaced so the test can
-- assert on ordering without touching a disk.
local FS, RENAMES
local realRename = os.rename
os.rename = function(from, to)
    if not FS[from] then return nil, "no such file: " .. from end
    if FS[to] then return nil, "exists: " .. to end   -- a real fs would clobber
    FS[to] = FS[from] ; FS[from] = nil
    RENAMES[#RENAMES + 1] = from .. " -> " .. to
    return true
end

FS = { ["/v/a"] = "A", ["/v/b"] = "B" } ; RENAMES = {}
local done = BR.apply({ { from = "/v/a", to = "/v/b", name = "b" },
                        { from = "/v/b", to = "/v/a", name = "a" } })
check("🚨 A STRAIGHT SWAP COMPLETES — a one-pass rename destroys one of "
      .. "the two files here, which is why apply goes through temporaries",
      done == 2 and FS["/v/a"] == "B" and FS["/v/b"] == "A",
      tostring(FS["/v/a"]) .. "/" .. tostring(FS["/v/b"]))

FS = { ["/v/1"] = "1", ["/v/2"] = "2", ["/v/3"] = "3" } ; RENAMES = {}
done = BR.apply({ { from = "/v/1", to = "/v/2" }, { from = "/v/2", to = "/v/3" },
                  { from = "/v/3", to = "/v/1" } })
check("a three-way rotation completes and loses nothing",
      done == 3 and FS["/v/1"] == "3" and FS["/v/2"] == "1"
      and FS["/v/3"] == "2")

-- =====================================================================
out("\n=== 7. Rules do not throw, and never produce an empty name ===\n")
-- =====================================================================
local NASTY = {
    "/v/.mp4", "/v/a.mp4", "/v/[].mp4", "/v/%.mp4", "/v/(2024).mp4",
    "/v/1080p.mp4", "/v/....mp4", "/v/-.mp4", "/v/S01E01.mp4",
    "/v/a%1b.mp4", "/v/x.-y.mp4", "/v/    .mp4",
}
DISK = {}
local threw, blank = nil, nil
for name in pairs(BR.rules) do
    for _, p in ipairs(NASTY) do
        local ok, pl = pcall(BR.plan, { p }, name,
                             { find = "%", repl = "%1", prefix = "F", pad = 3 })
        if not ok then threw = name .. " on " .. p break end
        for _, it in ipairs(pl or {}) do
            local stem = it.name:match("^(.*)%.[^.]+$") or it.name
            if it.name == "" or it.name:sub(1, 1) == "." and stem == "" then
                blank = name .. " on " .. p .. " -> '" .. it.name .. "'"
            end
        end
    end
    if threw then break end
end
check("no rule throws on pathological names, including pattern "
      .. "metacharacters that would break an unescaped gsub", threw == nil, threw)
check("no rule produces an empty filename", blank == nil, blank)

-- A rule declining to act must return the name unchanged, not "".
DISK = {}
local pl = BR.plan({ "/v/NotAnEpisode.mp4" }, "tv")
check("the tv rule leaves a non-episode alone rather than blanking it",
      #pl == 0, pl[1] and pl[1].name)

-- =====================================================================
out("\n=== 8. THE EXPLORER — 400 random messy folders ===\n")
-- =====================================================================
-- Properties P1–P5 asserted over generated input. The generator mixes the
-- shapes that break naive renamers: duplicate stems, language tails,
-- already-colliding names, metacharacters, and episodes that disagree
-- about how they are named.
do
    math.randomseed(20260810)
    local SHOWS = { "Dark.Matter", "The Bear", "Foundation.2021", "Severance" }
    local TAGS  = { "1080p", "1080p.ATVP-[y2flix.cc]", "108", "720p.WEBRip",
                    "2160p.NF.x265", "", "REPACK.1080p" }
    local TAILS = { "", "", "", "en", "forced", "sdh" }
    local RULES = { "tv", "junk", "dots", "spaces", "lower", "title",
                    "seq", "replace", "regex" }

    local bad, worst = nil, 0
    for iter = 1, 400 do
        local show = SHOWS[math.random(#SHOWS)]
        local n = math.random(2, 40)
        local paths, seenPath = {}, {}
        for i = 1, n do
            local ep  = math.random(1, 12)
            local tag = TAGS[math.random(#TAGS)]
            local stem = string.format("%s.S01E%02d%s", show, ep,
                                       tag ~= "" and ("." .. tag) or "")
            local vid = "/tv/" .. stem .. ".mp4"
            if not seenPath[vid] then
                seenPath[vid] = true ; paths[#paths + 1] = vid
            end
            -- Most videos get a subtitle. That pairing is what P3 checks.
            if math.random() < 0.8 then
                local tl = TAILS[math.random(#TAILS)]
                local sub = "/tv/" .. stem .. (tl ~= "" and ("." .. tl) or "")
                            .. ".srt"
                if not seenPath[sub] then
                    seenPath[sub] = true ; paths[#paths + 1] = sub
                end
            end
        end
        worst = math.max(worst, #paths)
        DISK = {} ; for _, p in ipairs(paths) do DISK[p] = true end

        local rule = RULES[math.random(#RULES)]
        local ok, plan, problems = pcall(BR.plan, paths, rule,
                                   { find = ".", repl = "_", prefix = "Ep", pad = 3 })
        -- P5: planning never throws, whatever went in.
        if not ok then bad = "plan threw: " .. tostring(plan) break end
        problems = problems or {}

        -- P1: no path is ever a source twice, and no source is outside input.
        local srcSeen, inInput = {}, {}
        for _, p in ipairs(paths) do inInput[p] = true end
        for _, it in ipairs(plan or {}) do
            if srcSeen[it.from] then bad = "path renamed twice: " .. it.from break end
            if not inInput[it.from] then bad = "invented a source: " .. it.from break end
            srcSeen[it.from] = true
        end
        if bad then break end

        -- P2: if the plan was returned clean, no two files may share a target.
        if #problems == 0 then
            local tgt = {}
            for _, it in ipairs(plan or {}) do
                if tgt[it.to] then
                    bad = "clean plan collides on " .. it.to break
                end
                tgt[it.to] = true
            end
            if bad then break end
        end

        -- P3: THE SUBTITLE GUARANTEE. For every renamed video, its
        -- subtitle must be renamed to a matching stem — or neither moves.
        --
        -- ⚠️ THE PAIRING RULE HAS TO BE EXACT, and getting it wrong is how
        -- this property first failed. Matching "any .srt whose path starts
        -- with the video's stem" over-matches: `Show.S01E01` is a prefix of
        -- `Show.S01E01.1080p`, so a naive prefix test pairs a video with a
        -- DIFFERENT group's subtitle and then reports the module for
        -- renaming them differently — which is correct behaviour. A
        -- subtitle belongs to a video only when the stems are EQUAL after
        -- a known language tail is removed. Implemented independently of
        -- the module here on purpose: a property that reuses the code it
        -- is checking cannot catch that code being wrong.
        if #problems == 0 then
            local KNOWN_TAILS = { en = true, forced = true, sdh = true }
            local function videoStemFor(subPath)
                local stem = subPath:sub(1, -5)          -- drop ".srt"
                local head, last = stem:match("^(.*)%.([^.]+)$")
                if head and KNOWN_TAILS[(last or ""):lower()] then return head end
                return stem
            end
            local moved, isVideo = {}, {}
            for _, it in ipairs(plan or {}) do moved[it.from] = it.to end
            for _, p in ipairs(paths) do
                if p:sub(-4) == ".mp4" then isVideo[p:sub(1, -5)] = p end
            end
            for _, q in ipairs(paths) do
                if q:sub(-4) == ".srt" then
                    local p = isVideo[videoStemFor(q)]
                    if p then
                        local vTo, sTo = moved[p], moved[q]
                        if (vTo == nil) ~= (sTo == nil) then
                            bad = "video and subtitle disagree: " .. p .. " / " .. q
                            break
                        end
                        if vTo and sTo then
                            -- After the rename the subtitle's own stem,
                            -- tail removed, must equal the video's stem.
                            if videoStemFor(sTo) ~= vTo:sub(1, -5) then
                                bad = "subtitle orphaned: " .. sTo
                                      .. " no longer matches " .. vTo
                                break
                            end
                        end
                    end
                end
            end
            if bad then break end
        end

        -- P4: apply then undo restores every original path exactly.
        if #problems == 0 and #(plan or {}) > 0 then
            FS = {} ; for _, p in ipairs(paths) do FS[p] = p end
            RENAMES = {}
            local okA, didN = pcall(BR.apply, plan)
            if not okA then bad = "apply threw: " .. tostring(didN) break end
            local back = {}
            for _, it in ipairs(plan) do
                back[#back + 1] = { from = it.to, to = it.from }
            end
            local okU = pcall(BR.apply, back)
            if not okU then bad = "undo threw" break end
            for _, p in ipairs(paths) do
                if FS[p] ~= p then
                    bad = "undo did not restore " .. p .. " (rule " .. rule .. ")"
                    break
                end
            end
            local extra = 0
            for _ in pairs(FS) do extra = extra + 1 end
            if not bad and extra ~= #paths then
                bad = "file count changed: " .. extra .. " vs " .. #paths
            end
            if bad then break end
        end
    end
    check(string.format("400 random messy folders (largest %d files): no file "
          .. "lost, no clean plan collided, EVERY subtitle stayed with its "
          .. "video, every batch undid exactly, nothing threw", worst),
          bad == nil, bad)
end

-- =====================================================================
out("\n=== 8b. The undo row on the picker — where ⇪⇧R went ===\n")
-- =====================================================================
do
    -- ⇪⇧R was removed because it collided with a working migrated
    -- shortcut (see modules/bulk_rename.lua's wiring note). Undo instead
    -- surfaces as the FIRST ROW of ⇪R's own picker, exactly the pattern
    -- Workspaces uses for its reset — and hasUndo() is what decides
    -- whether that row appears, read from disk so it survives a restart.
    local realOpen = io.open
    local files = {}
    io.open = function(path, mode)
        if (mode or "r"):find("w") then
            local buf = {}
            return { write = function(_, s) buf[#buf + 1] = s end,
                     close = function() files[path] = table.concat(buf) end }
        end
        if files[path] == nil then return realOpen(path, mode) end
        local content, done = files[path], false
        return { read = function() if done then return nil end done = true return content end,
                 close = function() end }
    end

    files = {}
    check("with nothing to undo, hasUndo is false", BR.hasUndo() == false)

    files[BR.undoFile] = '{}'
    check("an empty '{}' undo file (2 bytes) is treated as nothing to "
          .. "undo, not as a real batch", BR.hasUndo() == false)

    files = {}
    files[BR.undoFile] = '{"items":[{"from":"/v/a","to":"/v/b"}]}'
    check("🚨 with a real undo log on disk, hasUndo is true — this is what "
          .. "puts the undo row on the picker, and it is read from DISK so "
          .. "it survives a Hammerspoon restart the same way undo() does",
          BR.hasUndo() == true)

    io.open = realOpen
end

out("\n=== 9. Mutation — are these properties actually load-bearing? ===\n")
-- =====================================================================
-- A property that cannot fail is decoration. Each mutation below breaks
-- the module on purpose; the matching property must catch it.
do
    -- Mutation 1: group by full stem including the language tail. This is
    -- the naive implementation, and it orphans every `.en.srt`.
    local realSplitTail = BR.splitTail
    BR.splitTail = function(stem) return stem, "" end
    DISK = {}
    local paths = { "/v/Show.S01E01.mp4", "/v/Show.S01E01.en.srt" }
    -- ⚠️ THE RULE HERE MUST REWRITE THE STEM WHOLESALE. The first version
    -- of this mutation used `junk`, which leaves both of these names
    -- untouched — so the plan came back EMPTY and the probe caught
    -- nothing, reporting a working guard as broken. `seq` numbers by
    -- group, so a wrong grouping immediately shows up as two different
    -- numbers where there should be one.
    local pl2 = BR.plan(paths, "seq", { prefix = "File", pad = 3 }) or {}
    local moved = {}
    for _, it in ipairs(pl2) do moved[it.from] = it.to end
    local caught = false
    -- With the mutation, the .en.srt is its own group and gets its own
    -- sequence number, so its new stem no longer matches the video's.
    local vTo, sTo = moved["/v/Show.S01E01.mp4"], moved["/v/Show.S01E01.en.srt"]
    if vTo and sTo then
        local vs = vTo:sub(1, -5)
        if sTo:sub(1, #vs + 1) ~= (vs .. ".") then caught = true end
    elseif (vTo == nil) ~= (sTo == nil) then caught = true
    end
    BR.splitTail = realSplitTail
    -- And the same rule with grouping intact must NOT trip it — otherwise
    -- the mutation proves nothing about splitTail specifically.
    local pl3 = BR.plan(paths, "seq", { prefix = "File", pad = 3 }) or {}
    local m3 = {}
    for _, it in ipairs(pl3) do m3[it.from] = it.to end
    check("…and with splitTail intact the pair stays together, so the "
          .. "mutation isolates grouping rather than the seq rule",
          m3["/v/Show.S01E01.mp4"] == "/v/File 001.mp4"
          and m3["/v/Show.S01E01.en.srt"] == "/v/File 001.en.srt",
          tostring(m3["/v/Show.S01E01.en.srt"]))
    check("MUTATION: grouping that ignores language tails orphans the "
          .. "subtitle — and P3 catches it", caught)

    -- Mutation 2: single-phase apply. The swap must now lose a file.
    FS = { ["/v/a"] = "A", ["/v/b"] = "B" } ; RENAMES = {}
    local lost = false
    for _, it in ipairs({ { from = "/v/a", to = "/v/b" },
                          { from = "/v/b", to = "/v/a" } }) do
        os.rename(it.from, it.to)
    end
    if FS["/v/a"] ~= "B" or FS["/v/b"] ~= "A" then lost = true end
    check("MUTATION: a one-pass rename fails the swap that the two-phase "
          .. "apply survives — the temporaries are load-bearing", lost)

    -- Mutation 3: drop the overwrite check. The plan must then return a
    -- destructive rename that the real check refuses.
    local realExists = BR.exists
    BR.exists = function() return false end
    DISK = { ["/v/a.1080p.mp4"] = true, ["/v/a.mp4"] = true }
    local _, probs = BR.plan({ "/v/a.1080p.mp4" }, "junk")
    BR.exists = realExists
    check("MUTATION: without the exists() check the overwrite is planned "
          .. "silently — the check is what stands between a bulk rename "
          .. "and a deleted file", #probs == 0)
end

os.rename = realRename

out("\n")
if fail > 0 then
    out("FAILURES:\n")
    for _, f in ipairs(failures) do out("   ❌ " .. f .. "\n") end
end
out(("\n%d passed, %d failed\n\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
