-- =====================================================================
-- MODULE: INSTALL CHECK (_G.installCheck) — did the whole release land?
-- =====================================================================
-- LL, 2026-09-29, after a Console installer had put one module file in
-- place by hand: "Will this be added as 'Get-Jug-Player-going.md' as
-- part of the init.lua zip file with an entry on the cheat sheet under
-- Jug player so I don't have to remember?"
--
--        _G.installCheck()   every runtime file against MANIFEST.txt
--        at boot             SILENT unless something disagrees
--
-- ---- 🚪 WHY IT IS AN INSTRUMENT AND NOT A DOCUMENT -------------------
-- The answer to his question is yes, and NOT as a file named after one
-- tool. Seventy-six modules can half-install; a document called
-- Get-Jug-Player-going.md is right about one of them and silently
-- misleading about the other seventy-five — 6.276.0's hand-kept
-- register, which is the defect this project has already deleted twice.
--
-- The failure it exists for is MEASURED, not imagined. 6.311.0 shipped
-- as four loose files to be placed by hand; his `_G.musicReport()` came
-- back reading `🎵 JUG PLAYER — ⇪⇧pad.` with no `doors :` line, which
-- the new file cannot emit. init.lua was new and modules/
-- music_player.lua was old. THE CONFIG BOOTED GREEN, the version stamp
-- was right, and the feature was simply absent. A later probe read the
-- loader's own path and answered `bytes : 107414` against the 116,595
-- the release carried — one number, and it was the whole diagnosis.
--
-- So: the archive carries MANIFEST.txt, one row per runtime file with
-- its byte count, GENERATED at ceremony time (tools/build-manifest.lua)
-- like TESTING.md and RESOLVED-FEATURE-REQUESTS.txt. A hand-kept one is
-- stale the first time a file changes.
--
-- ---- 📏 SIZE, NOT A HASH, AND THE LIMIT IS NAMED ---------------------
-- `hs.fs.attributes(p).size` is a STAT: it reads no bytes, so it costs
-- nothing on the main thread (6.228.0) and it cannot hydrate a cloud
-- placeholder. It catches the case that actually happened — 107,414
-- against 116,595 — and every one of its shape.
--
-- WHAT IT CANNOT SEE, said out loud in the report rather than left to
-- be discovered: a file edited to exactly the same LENGTH reads as a
-- match. The earlier plan for this module carried an `installCheck(true)`
-- hash path for that; it is deliberately NOT built, on two counts.
-- `hs.hash`'s presence is a platform fact this container cannot check in
-- the source, and 6.233.0 forbids designing on a belief; and every
-- release moves init.lua's version stamp, so a same-size different-
-- content file needs somebody to have hand-edited one to the byte. A
-- guard for a case that has never happened is dead code with a comment
-- on it (6.199.0). If it ever happens, the manifest gains a column.
--
-- ---- 🔎 AND THE HALF A MANIFEST WALK STRUCTURALLY CANNOT SEE ---------
-- Walking the manifest answers "is every file I shipped here, at the
-- right size?" It says NOTHING about a file on his disk that the
-- manifest does not name — and §1.12 loads an EXPLICIT module list, so a
-- stray `music_player 2.lua` (Finder's Keep Both, one click wide) is
-- ignored entirely while the ORIGINAL stays loaded. The install looks
-- done, Finder shows the new file, and nothing has changed.
--
-- That is 6.276.0's rule from the other end: when a check works by
-- joining two things, ask what it says about a row that has only ONE of
-- them. So core/ and modules/ are also LISTED, and any .lua the manifest
-- does not name is reported as a stray. One listing per folder, bounded.
--
-- ---- 🔕 SILENT WHEN HEALTHY ------------------------------------------
-- 6.269.0: a new instrument's first duty is to be silent when nothing is
-- wrong. On a matching install this module prints NOTHING, ever. It
-- speaks from M.warm only when something disagrees, and then it takes
-- the 🔔 door — because a config that boots green with a feature
-- silently absent is exactly what 6.311.0 cost, and a report line alone
-- is a break found a week later (6.214.0).
--
-- ---- 🔎 FOUR STATES FOR THE CHECK, FOUR FOR EACH FILE ----------------
-- The check: no manifest on disk (this install predates it and NOTHING
-- CAN BE SAID) · the manifest could not be read · every file matches ·
-- N disagree. "Cannot be checked" must never render as "all clear",
-- which is 6.196.1 in the one place it would be most reassuring.
-- Each file: matches · DIFFERENT SIZE, with both numbers · MISSING ·
-- macOS WOULD NOT SAY how big it is. The last two are not the same fact.
--
-- ---- 📝 WHAT IS DELIBERATELY NOT IN THE MANIFEST ---------------------
-- CHANGELOG.md, which core/changelog_csv.lua really does read at
-- runtime. It already has a BETTER instrument: that file lifts the
-- release's notes out of it and prints "no CHANGELOG.md entry for
-- <version>" when they are missing — which asks about the ENTRY, not the
-- length, and is what caught 6.311.0's second half-installed file.
-- A size row beside it would be a second answer to one question
-- (6.317.0). Named here so the omission is a decision rather than a gap.
-- The docs (GUIDE, INSTALL, HAMSIDIAN, TESTING, RESOLVED-FEATURE-
-- REQUESTS) are not run by this Mac at all, and tools/hs-install.sh has
-- never copied a .md — tests/ likewise.
-- =====================================================================

local M = {
    name  = "Install Check",
    order = 13.37,
    family = "config",
    cheatsheet = {
        title = "🩺 INSTALL CHECK (did the whole release land?)",
        entries = {
            { "_G.installCheck()", "Every runtime file against MANIFEST.txt — size by size" },
            { "at boot",     "Says NOTHING unless something disagrees" },
            { "disagrees",   "MISSING · DIFFERENT SIZE (both numbers) · macOS would not say" },
            { "strays",      "A .lua in core/ or modules/ the manifest does not name —" },
            { "",            "Finder's Keep Both writes 'music_player 2.lua' and §1.12 ignores it" },
            { "version",     "The manifest's own version against _G.configVersion" },
            { "no manifest", "An install from before 6.399.0 — says so, never 'all clear'" },
            { "size only",   "A file edited to exactly the same length reads as a match" },
        },
    },
}

function M.setup(core)
    local ic = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ic.enabled   = true
    ic.file      = "MANIFEST.txt"   -- at the config root, beside init.lua
    ic.sayAfter  = 6                -- seconds after warm, off the boot path
    ic.maxRows   = 400              -- a manifest longer than this is refused
    ic.strayDirs = { "core", "modules" }
    ic.strayMax  = 300              -- entries read per folder before the walk stops
    -- ----------------------------------------------------------------------

    ic.dir      = core.configDir or hs.configdir
    ic.last     = nil        -- the last run's answer, for the report
    ic.lastAt   = nil
    ic.runs     = 0
    ic.saidBoot = false

    -- =============================================================
    -- 📏 PURE — the whole rule, provable with no Mac
    -- =============================================================

    -- 🔒 A PATH READ OFF DISK IS DATA, NOT AN ADDRESS WE CHOSE. The rows
    -- come out of a file, and the check then stats each one — so a row
    -- reading `../../../etc/passwd` would be stat'ed and printed as a
    -- config file. A stat reads nothing and harms nothing; a REPORT that
    -- calls somebody else's file one of ours is the defect.
    -- It walks the COMPONENTS rather than searching for ".." in the
    -- string, because 6.320.0 is the release where a substring test over
    -- a serialised path refused `Budget..final.md` — a different
    -- predicate that happens to agree on the common input.
    function ic.relInside(rel)
        if type(rel) ~= "string" or rel == "" then return false end
        if rel:sub(1, 1) == "/" then return false end          -- absolute
        for part in rel:gmatch("[^/]+") do
            if part == ".." then return false end
            if part == "."  then return false end
        end
        -- an empty component means a leading, doubled or trailing slash
        if rel:find("//", 1, true) or rel:sub(-1) == "/" then return false end
        return true
    end

    -- Parse MANIFEST.txt. Answers rows + meta, or nil + why — never a
    -- half-parsed list, because a manifest we did not understand must
    -- not read as a manifest with fewer files in it.
    function ic.parseManifest(text, maxRows)
        if type(text) ~= "string" then return nil, "nothing was read" end
        if text == "" then return nil, "the file is ZERO BYTES" end
        local rows, meta, bad = {}, { version = nil }, nil
        local n = 0
        for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            local t = line:gsub("%s+$", "")
            if t == "" then                                    -- blank: skip
            elseif t:sub(1, 1) == "#" then                      -- comment
                local v = t:match("^#%s*version%s*[:=]%s*(%S+)")
                if v then meta.version = v end
            else
                local path, bytes = t:match("^([^\t]+)\t(%d+)$")
                if not path then
                    bad = bad or ("a row this reader cannot parse: " .. t:sub(1, 60))
                elseif not ic.relInside(path) then
                    -- fail CLOSED: one bad row refuses the whole file
                    return nil, "a row names a path outside the config folder: "
                                .. path:sub(1, 60)
                else
                    n = n + 1
                    if n > (maxRows or 400) then
                        return nil, "more than " .. tostring(maxRows or 400)
                                    .. " rows — this is not our manifest"
                    end
                    rows[n] = { path = path, bytes = tonumber(bytes) }
                end
            end
        end
        if n == 0 then return nil, (bad or "it holds no file rows") end
        meta.count = n
        meta.bad   = bad          -- counted, never silently dropped
        return rows, meta
    end

    -- 🔎 FOUR ANSWERS, AND THE LAST TWO ARE NOT THE SAME FACT (6.196.1).
    -- "there is no such file" and "the file is there and macOS would not
    -- say how big it is" send you to different places.
    function ic.verdict(want, got, why)
        if type(got) == "number" then
            if got == want then return "ok", "matches (" .. tostring(want) .. " bytes)" end
            return "size", "DIFFERENT SIZE — the release carried "
                   .. tostring(want) .. " bytes, this Mac has " .. tostring(got)
        end
        if why == "missing" then
            return "missing", "MISSING — the release carried "
                   .. tostring(want) .. " bytes and there is no file here"
        end
        return "unknown", "macOS would not say how big it is"
               .. (why and (" (" .. tostring(why) .. ")") or "")
    end

    -- A stray is a .lua in a watched folder that the manifest does not
    -- name. PURE: both lists are arguments, so the gate moves them.
    function ic.straysIn(dir, names, manifestPaths)
        local out = {}
        for _, name in ipairs(names or {}) do
            if name ~= "." and name ~= ".." and name:sub(-4) == ".lua" then
                local rel = dir .. "/" .. name
                if not manifestPaths[rel] then out[#out + 1] = rel end
            end
        end
        table.sort(out)
        return out
    end

    -- =============================================================
    -- THE DISK
    -- =============================================================

    -- Three outcomes, never two: a number · there is no such file ·
    -- something is there and its size cannot be read.
    function ic.sizeOf(rel)
        local p = ic.dir .. "/" .. rel
        local a
        local ok = pcall(function() a = hs.fs.attributes(p) end)
        if not ok then return nil, "hs.fs.attributes raised" end
        if a == nil then return nil, "missing" end
        if type(a) ~= "table" then return nil, "hs.fs answered something odd" end
        if a.mode == "directory" then return nil, "a FOLDER is there, not a file" end
        if type(a.size) ~= "number" then return nil, "no size in the answer" end
        return a.size
    end

    local function readAll(p)
        local f = io.open(p, "r")
        if not f then return nil end
        local s = f:read("*a")
        f:close()
        return s
    end

    local function listDir(rel)
        local names, ok = {}, false       -- declared FIRST (6.230.0's trap)
        ok = pcall(function()
            local n = 0
            for e in hs.fs.dir(ic.dir .. "/" .. rel) do
                n = n + 1
                if n > (ic.strayMax or 300) then break end
                names[#names + 1] = e
            end
        end)
        if not ok then return nil end
        return names
    end

    -- =============================================================
    -- THE CHECK
    -- =============================================================

    function ic.run()
        ic.runs = ic.runs + 1
        local res = { state = nil, why = nil, rows = 0, ok = 0,
                      bad = {}, strays = {}, version = nil, unread = {} }
        pcall(function() ic.lastAt = os.date("%H:%M:%S") end)

        local text = readAll(ic.dir .. "/" .. ic.file)
        if text == nil then
            res.state = "none"
            res.why   = "there is no " .. ic.file .. " in " .. ic.dir
            ic.last = res
            return res
        end

        local rows, meta = ic.parseManifest(text, ic.maxRows)
        if not rows then
            res.state = "unreadable"
            res.why   = tostring(meta)
            ic.last = res
            return res
        end

        res.rows    = #rows
        res.version = meta.version
        res.badRow  = meta.bad

        local seen = {}
        for _, r in ipairs(rows) do
            seen[r.path] = true
            local got, why = ic.sizeOf(r.path)
            local state, words = ic.verdict(r.bytes, got, why)
            if state == "ok" then
                res.ok = res.ok + 1
            else
                res.bad[#res.bad + 1] = { path = r.path, state = state, words = words }
            end
        end

        for _, d in ipairs(ic.strayDirs or {}) do
            local names = listDir(d)
            if names == nil then
                res.unread[#res.unread + 1] = d
            else
                for _, s in ipairs(ic.straysIn(d, names, seen)) do
                    res.strays[#res.strays + 1] = s
                end
            end
        end

        res.state = (#res.bad == 0) and "ok" or "off"
        ic.last = res
        return res
    end

    -- =============================================================
    -- THE WORDS
    -- =============================================================

    function ic.block(res)
        res = res or ic.last or ic.run()
        local L = {}
        L[#L + 1] = "🩺 INSTALL CHECK — " .. tostring(_G.configVersion or "?")

        if res.state == "none" then
            L[#L + 1] = "   ⏳ NOTHING CAN BE SAID — " .. tostring(res.why)
            L[#L + 1] = "      This install predates the check (6.399.0 is the first"
            L[#L + 1] = "      release that carries one). That is NOT 'all clear':"
            L[#L + 1] = "      install a release from 6.399.0 on and run this again."
            return table.concat(L, "\n")
        end

        if res.state == "unreadable" then
            L[#L + 1] = "   ⚠️ THE MANIFEST COULD NOT BE READ — " .. tostring(res.why)
            L[#L + 1] = "      " .. ic.dir .. "/" .. ic.file
            L[#L + 1] = "      Nothing about this install has been checked. Re-install"
            L[#L + 1] = "      the release, or delete that file to get the ⏳ state back."
            return table.concat(L, "\n")
        end

        -- 🏷 THE MANIFEST'S OWN VERSION AGAINST THE RUNNING ONE. This is
        -- the half-install at the level of the whole archive: a new
        -- MANIFEST.txt beside an old init.lua, or the other way round.
        local running = tostring(_G.configVersion or "?")
        if res.version == nil then
            L[#L + 1] = "   version : ⚠️ the manifest does not say which release it is for"
        elseif res.version ~= running then
            L[#L + 1] = "   version : ⚠️ THE MANIFEST IS FOR " .. tostring(res.version)
                        .. " AND THIS CONFIG IS " .. running
            L[#L + 1] = "             — one of the two did not land. Re-install the release."
        else
            L[#L + 1] = "   version : " .. running .. " — the manifest is for this release"
        end

        if res.state == "ok" then
            L[#L + 1] = "   files   : ✅ all " .. tostring(res.rows)
                        .. " runtime file(s) are here at the size the release carried"
        else
            L[#L + 1] = "   files   : ⚠️ " .. tostring(#res.bad) .. " of "
                        .. tostring(res.rows) .. " DISAGREE (" .. tostring(res.ok)
                        .. " match)"
            local shown = 0
            for _, b in ipairs(res.bad) do
                shown = shown + 1
                if shown > 12 then
                    L[#L + 1] = "      … and " .. tostring(#res.bad - 12) .. " more"
                    break
                end
                L[#L + 1] = "      · " .. b.path .. " — " .. b.words
            end
            L[#L + 1] = "      ↳ a file that disagrees is a HALF-INSTALL: the config boots"
            L[#L + 1] = "        green and that feature is simply absent. Re-install."
        end

        if #res.strays > 0 then
            L[#L + 1] = "   strays  : ⚠️ " .. tostring(#res.strays)
                        .. " .lua file(s) this release does not carry"
            for i, s in ipairs(res.strays) do
                if i > 8 then L[#L + 1] = "      …" ; break end
                L[#L + 1] = "      · " .. s
            end
            L[#L + 1] = "      ↳ §1.12 loads an explicit list, so a stray is IGNORED and"
            L[#L + 1] = "        the original stays loaded — a drag that answered Finder's"
            L[#L + 1] = "        'Keep Both' looks exactly like a finished install."
        else
            L[#L + 1] = "   strays  : none — core/ and modules/ hold only what shipped"
        end

        if #res.unread > 0 then
            L[#L + 1] = "      ⚠️ could not list: " .. table.concat(res.unread, ", ")
                        .. " — the stray half says nothing about those folders"
        end
        if res.badRow then
            L[#L + 1] = "      ⚠️ " .. tostring(res.badRow)
        end

        L[#L + 1] = "   📏 size only: a file edited to exactly the same LENGTH reads as a"
        L[#L + 1] = "      match, and nothing here can see that. CHANGELOG.md is not in"
        L[#L + 1] = "      the manifest — core/changelog_csv.lua checks its ENTRY instead,"
        L[#L + 1] = "      which is a better question than its length."
        L[#L + 1] = "   last    : " .. tostring(ic.lastAt or "—")
                    .. " · run " .. tostring(ic.runs) .. " time(s) this session"
        return table.concat(L, "\n")
    end

    -- 🔔 ONE SHORT SENTENCE FOR THE BOOT, never the whole block: a
    -- fourteen-line readout every morning is a readout he scrolls past
    -- (6.269.0), and this one only ever appears when something is wrong.
    function ic.bootLine(res)
        if res.state == "ok" or res.state == "none" then return nil end
        if res.state == "unreadable" then
            return "the MANIFEST.txt in " .. ic.dir .. " could not be read ("
                   .. tostring(res.why) .. ") — run _G.installCheck()"
        end
        local first = res.bad[1]
        return tostring(#res.bad) .. " runtime file(s) do not match what this release"
               .. " carried — e.g. " .. tostring(first and first.path or "?")
               .. ". The config boots green and those features are absent."
               .. " Run _G.installCheck()"
    end

    _G.installCheck = function()
        local ok, text = pcall(function() return ic.block(ic.run()) end)
        if ok then print(text)
        else print("🩺 INSTALL CHECK — the check itself failed: " .. tostring(text)) end
    end
    _G.installCheckReport = _G.installCheck

    _G.installCheckState = ic
    M.ic     = ic
    M.config = ic
end

-- ⏱ FROM warm(), NEVER setup (6.267.0): this reads the disk once per
-- boot and nothing needs the answer before a key is bound. On a held
-- timer and late, because a Mac that has just started is the slowest
-- moment to ask it for seventy-eight stats.
M.warm = function()
    local ic = _G.installCheckState
    if not (ic and ic.enabled) then return end

    local function speak()
        ic.bootTimer = nil
        local ok, res = pcall(ic.run)
        if not ok then return end
        local line = ic.bootLine(res)
        if not line then return end        -- 🔕 silent when healthy
        ic.saidBoot = true
        -- 🔔 A BREAK IS SEEN, NEVER ONLY LOGGED (6.214.0). A half-install
        -- is the one failure in this config that leaves no error anywhere
        -- — the version stamp is right and the feature is just gone.
        if _G.degrade then pcall(_G.degrade, "Install check", line)
        else pcall(print, "⚠️ Install check: " .. line) end
    end

    local okT, t = pcall(hs.timer.doAfter, ic.sayAfter or 6, speak)
    ic.bootTimer = okT and t or nil        -- HELD (6.196.1)
    if not okT then
        -- A Mac that cannot arm a timer still gets the check. It is
        -- simply early; saying nothing is not one of the options in a
        -- module whose whole subject is not being told.
        ic.noBelt = (ic.noBelt or 0) + 1
        pcall(speak)
    end
end

return M
