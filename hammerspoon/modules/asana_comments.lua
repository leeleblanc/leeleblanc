-- =====================================================================
-- MODULE: ASANA COMMENTS (was 3.5)
-- =====================================================================

-- Moved out of init.lua in 6.40.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "Asana Comments",
    order = 2,
    family = "capture",
    -- no cheatsheet group of its own
}

-- 🏷 6.284.0 — A TEAM IS PINNED BY ITS GID, SO A RENAME NO LONGER BREAKS
-- IT. LL: "Why do I have to hard code team names" — and the honest answer
-- is that he should not have to. `fetchAsanaTeamGids` has always fetched
-- Asana's team list LIVE on every boot; what was stale was the other side,
-- the name we search FOR, a literal in this file. Renaming a team in Asana
-- is therefore exactly what breaks it: a fresh answer to a stale question.
--
-- BOTH FUNCTIONS ARE PURE and live at the top level, outside setup(), so
-- the gate proves the whole rule with no Mac and no network — and so they
-- cost nothing from this file's near-the-ceiling local budget.

-- Team names in this org are literally formatted "| N. Name |". The key is
-- what survives the decoration drifting: the number, the pipes, the case,
-- "&" against "and", a doubled or NON-BREAKING space (U+00A0 — invisible
-- in a name copied out of a browser, and the warning's old advice to
-- "check spelling/spacing" could never have found it).
function M.teamKey(name)
    local s = tostring(name or "")
    if s == "" then return "" end
    s = s:gsub("\194\160", " ")              -- U+00A0 → a real space
    s = s:match("^|%s*%d+%.%s*(.-)%s*|$") or s  -- "| 2. Foo |" → "Foo"
    s = s:lower()
    s = s:gsub("&", " and ")
    s = s:gsub("[^%w%s]", " ")                  -- punctuation is decoration
    s = s:gsub("%s+", " ")
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- 🔎 THREE ANSWERS, NEVER TWO (6.196.1), and the middle one is the release:
--   "name"  — Asana holds a team with this name. Ordinary.
--   "gid"   — no team has this name any more, but a team we resolved on an
--             EARLIER boot still has the pinned gid. He renamed it; we
--             found it anyway, and we say what it is called now.
--   "none"  — neither. The caller names what Asana DID answer, because a
--             warning that does not is unguessable (6.201.0).
-- `pins` is key → gid, from hs.settings. Nothing is written here: each
-- result carries the pin it WANTS written, and the caller writes it. A
-- gid already claimed by an earlier want is never claimed twice.
function M.matchTeam(wants, teams, pins)
    wants, teams, pins = wants or {}, teams or {}, pins or {}
    local byKey, byGid = {}, {}
    for _, t in ipairs(teams) do
        if type(t) == "table" and t.gid then
            byGid[tostring(t.gid)] = t
            local k = M.teamKey(t.name)
            if k ~= "" and byKey[k] == nil then byKey[k] = t end
        end
    end
    local out, taken = {}, {}
    for _, want in ipairs(wants) do
        local key = M.teamKey(want)
        local r = { want = want, key = key, how = "none" }
        local t = byKey[key]
        if t and not taken[tostring(t.gid)] then
            r.how, r.gid, r.name = "name", tostring(t.gid), t.name
        else
            local pinned = pins[key]
            local pt = pinned and byGid[tostring(pinned)]
            if pt and not taken[tostring(pt.gid)] then
                r.how, r.gid, r.name = "gid", tostring(pt.gid), pt.name
            end
        end
        if r.gid then
            taken[r.gid] = true
            -- Pin the key we ASKED with, so the next rename is survivable
            -- too, and the key Asana answers with, so a config that is
            -- brought back into line still matches by name (the cheap way).
            r.pin = { [key] = r.gid }
            local nowKey = M.teamKey(r.name)
            if nowKey ~= "" then r.pin[nowKey] = r.gid end
        end
        out[#out + 1] = r
    end
    return out
end

function M.setup(core)
    -- Posts a comment on any task via the Asana "stories" endpoint —
    -- identical to typing in the "Add a comment" box in the Asana UI.
    local function addCommentToTask(taskGid, commentText, onDone)
        if not core.asanaEnabled then
            if onDone then onDone(false) end
            return
        end
        if not taskGid or not commentText or #commentText == 0 then
            if onDone then onDone(false) end
            return
        end

        local body = hs.json.encode({ data = { text = commentText } })

        hs.http.asyncPost("https://app.asana.com/api/1.0/tasks/" .. taskGid .. "/stories", body, {
            ["Authorization"] = "Bearer " .. core.asanaToken,
            ["Content-Type"]  = "application/json"
        }, function(status, responseBody)
            if status == 200 or status == 201 then
                hs.alert.show("💬 Comment added")
                if onDone then onDone(true) end
            else
                hs.alert.show("❌ Comment failed (HTTP " .. tostring(status) .. ")")
                print("Asana comment error: ", responseBody)
                if onDone then onDone(false) end
            end
        end)
    end

    -- TEAM MEMBERS — Asana's API rejects a display name outright ("Not a
    -- valid actor ID: Lee"); assignee must be "me", a numeric GID, or an
    -- email. This caches {gid=, name=, email=} so a typed name can be
    -- resolved to a real GID before it ever reaches the API (see the Task
    -- Creator's resolveAssignee below).
    -- _G. instead of local: called from two separate top-level closures
    -- (boot, and the ⌃⌥⌘B picker) without spending another slot on this
    -- already-near-the-200-local-ceiling file.
    -- 6.15.1 FIX: /projects/{gid}/users is not a real Asana endpoint (the
    -- 404 was that, not a private-project permission issue — a real
    -- permission problem would be a 403, and this token already reads/
    -- writes this exact project fine elsewhere).
    -- 6.16.9: whole-WORKSPACE listing (the 6.15.1 fix above) turned out to
    -- mean "everyone in the entire organization" on a big org (a college —
    -- thousands of student accounts), making the picker useless. ✏️ EDIT
    -- THESE — the exact team names as they appear in Asana; resolved to
    -- their real GIDs once at boot (GET /workspaces/{gid}/teams, a real,
    -- documented endpoint) and cached, then each team's own roster is
    -- fetched via GET /teams/{gid}/users and merged, deduped by gid. Leave
    -- the list empty ({}) to fall back to the old whole-workspace roster.
    -- (wrapped in do...end — these names never need to be seen outside this
    -- block — so they don't spend more of this file's already-tight 200
    -- main-chunk local-variable budget than the single _G.fetchAsanaTeamMembers
    -- entry point actually requires)
    do
    local asanaTeamNames = {
        "| 1. SAC Library Core Projects |",
        -- 6.284.0 — LL renamed this team; " & Tasks" is gone. The gid
        -- pin below is what makes the NEXT rename cost nothing.
        "| 2. SAC Library Team Member Projects |",
    }

    _G.asanaTeamMembers = {}
    local asanaTeamGidsResolved = false
    local asanaTeamGids = {}
    local asanaTeamGidNames = {}   -- gid -> clean display name (strips "| N. ... |")

    -- Team names in this org are literally formatted "| N. Name |" — strip
    -- that decoration for display (subText/search), not just the raw match.
    local function asanaCleanTeamName(name)
        return name:match("^|%s*%d+%.%s*(.-)%s*|$") or name
    end

    -- 🏷 6.284.0 — the pins live in hs.settings, so a rename survives a
    -- reload AND a reboot. Written only when they CHANGE: hs.settings
    -- writes the whole Hammerspoon domain on the main thread (6.228.0).
    local ASANA_PIN_KEY = "asana.teamGids"
    local function asanaPinsRead()
        local ok, v = pcall(function() return hs.settings.get(ASANA_PIN_KEY) end)
        return (ok and type(v) == "table") and v or {}
    end
    local function asanaPinsWrite(pins, add)
        local changed = false
        for k, gid in pairs(add or {}) do
            if pins[k] ~= gid then pins[k] = gid; changed = true end
        end
        if changed then pcall(function() hs.settings.set(ASANA_PIN_KEY, pins) end) end
        return changed
    end

    _G.asanaTeamsSeen = nil   -- what Asana last ANSWERED; the artefact

    local function resolveAsanaTeamGids(onDone)
        if asanaTeamGidsResolved or #asanaTeamNames == 0 then onDone() return end
        hs.http.asyncGet(
            "https://app.asana.com/api/1.0/workspaces/" .. core.asanaWorkspaceId .. "/teams?opt_fields=name",
            { ["Authorization"] = "Bearer " .. core.asanaToken },
            function(status, body)
                if status == 200 then
                    local data = _G.safeJson(body, "asana/teams")
                    if data and data.data then
                        _G.asanaTeamsSeen = { at = os.time(), teams = data.data }
                        local pins = asanaPinsRead()
                        local results = M.matchTeam(asanaTeamNames, data.data, pins)
                        _G.asanaTeamMatch = results
                        local add = {}
                        for _, r in ipairs(results) do
                            if r.gid then
                                table.insert(asanaTeamGids, r.gid)
                                asanaTeamGidNames[r.gid] = asanaCleanTeamName(r.name)
                                for k, v in pairs(r.pin or {}) do add[k] = v end
                            end
                            if r.how == "gid" then
                                -- 🔑 THE RELEASE, in one line: the name in the
                                -- config is stale and it did not matter.
                                print("🏷 Asana team renamed — \"" .. r.want
                                      .. "\" is called \"" .. tostring(r.name)
                                      .. "\" now; matched by its GID, nothing to edit")
                            elseif r.how == "none" then
                                -- 🔎 NAME WHAT ASANA ANSWERED. The old line said
                                -- "check spelling/spacing", which was already
                                -- stale advice (the compare was case-folded and
                                -- trimmed), and it never said what the real
                                -- names were — so it could not be acted on.
                                local names = {}
                                for _, t in ipairs(data.data) do
                                    names[#names + 1] = "\"" .. tostring(t.name) .. "\""
                                    if #names >= 12 then break end
                                end
                                print("⚠️ Asana team not found: \"" .. r.want
                                      .. "\" — Asana answered with "
                                      .. #data.data .. " team(s): "
                                      .. table.concat(names, ", ")
                                      .. (#data.data > #names and ", …" or "")
                                      .. "  ·  _G.asanaTeams() lists them all")
                            end
                        end
                        asanaPinsWrite(pins, add)
                    end
                else
                    print("⚠️ Asana team list fetch failed (HTTP " .. tostring(status) .. ")")
                end
                asanaTeamGidsResolved = true
                onDone()
            end)
    end

    -- 🔎 THE INSTRUMENT (6.201.0): what we asked for, beside what Asana
    -- answered. Renaming a team is a one-line fix and a WRONG rename is
    -- silent — it warns identically — so the list has to be readable
    -- without a curl and without his token ever leaving secret.lua.
    function _G.asanaTeams()
        local L = {}
        local function line(t) L[#L + 1] = t end
        line("🏷 ASANA TEAMS")
        if not core.asanaEnabled then
            line("   Asana is OFF on this Mac (no token in secret.lua)")
            print(table.concat(L, "\n"))
            return false
        end
        line("   asked  : " .. #asanaTeamNames .. " name(s) configured in "
             .. "modules/asana_comments.lua")
        for _, n in ipairs(asanaTeamNames) do
            line("            · " .. n .. "   [key: " .. M.teamKey(n) .. "]")
        end
        local seen = _G.asanaTeamsSeen
        if not seen then
            line("   answer : Asana has not been asked yet this session —"
                 .. " the team list is fetched once at boot")
        else
            line("   answer : " .. #seen.teams .. " team(s) at "
                 .. os.date("%H:%M:%S", seen.at))
            for _, t in ipairs(seen.teams) do
                line("            · " .. tostring(t.name)
                     .. "   [gid " .. tostring(t.gid) .. "]")
            end
        end
        local m = _G.asanaTeamMatch
        if not m then
            line("   matched: nothing resolved yet")
        else
            for _, r in ipairs(m) do
                if r.how == "name" then
                    line("   ✅ " .. r.want .. " → gid " .. r.gid .. " (by name)")
                elseif r.how == "gid" then
                    line("   🏷 " .. r.want .. " → gid " .. r.gid
                         .. " — RENAMED to \"" .. tostring(r.name)
                         .. "\"; matched by its pinned GID")
                else
                    line("   ⚠️ " .. r.want .. " → NOT FOUND. That team's members"
                         .. " are missing from ⇪T's assignee suggestions; a name"
                         .. " not on the list still submits.")
                end
            end
        end
        line("   pins   : " .. (function()
            local n = 0
            for _ in pairs(asanaPinsRead()) do n = n + 1 end
            return n .. " gid(s) remembered in hs.settings \"" .. ASANA_PIN_KEY
                   .. "\" — this is what makes a rename cost nothing"
        end)())
        print(table.concat(L, "\n"))
        return true
    end

    _G.fetchAsanaTeamMembers = function(onDone)
        if not core.asanaEnabled then if onDone then onDone() end return end

        local function fetchByGids()
            if #asanaTeamGids == 0 then
                -- fallback: whole workspace (no team names configured, or
                -- none of them matched a real team)
                hs.http.asyncGet(
                    "https://app.asana.com/api/1.0/workspaces/" .. core.asanaWorkspaceId .. "/users?opt_fields=name,email",
                    { ["Authorization"] = "Bearer " .. core.asanaToken },
                    function(status, body)
                        local members = {}
                        if status == 200 then
                            local data = _G.safeJson(body, "asana/members")
                            if data and data.data then
                                for _, u in ipairs(data.data) do
                                    table.insert(members, { gid = u.gid, name = u.name or "?", email = u.email })
                                end
                            end
                        else
                            print("⚠️ Asana team member fetch failed (HTTP " .. tostring(status) .. ")")
                        end
                        _G.asanaTeamMembers = members
                        if onDone then onDone() end
                    end)
                return
            end

            local allMembers, remaining, seen = {}, #asanaTeamGids, {}
            for _, teamGid in ipairs(asanaTeamGids) do
                local teamName = asanaTeamGidNames[teamGid] or "Team"
                hs.http.asyncGet(
                    "https://app.asana.com/api/1.0/teams/" .. teamGid .. "/users?opt_fields=name,email",
                    { ["Authorization"] = "Bearer " .. core.asanaToken },
                    function(status, body)
                        if status == 200 then
                            local data = _G.safeJson(body, "asana/members")
                            if data and data.data then
                                for _, u in ipairs(data.data) do
                                    if seen[u.gid] then
                                        -- on both teams — show both, don't duplicate the row
                                        table.insert(seen[u.gid].teams, teamName)
                                    else
                                        local m = { gid = u.gid, name = u.name or "?", email = u.email, teams = { teamName } }
                                        seen[u.gid] = m
                                        table.insert(allMembers, m)
                                    end
                                end
                            end
                        else
                            print("⚠️ Asana team member fetch failed for team " .. teamGid .. " (HTTP " .. tostring(status) .. ")")
                        end
                        remaining = remaining - 1
                        if remaining <= 0 then
                            _G.asanaTeamMembers = allMembers
                            if onDone then onDone() end
                        end
                    end)
            end
        end

        resolveAsanaTeamGids(fetchByGids)
    end
    if core.asanaEnabled then _G.fetchAsanaTeamMembers() end   -- warm the cache at boot

    end -- do...end (§0.2 Asana team-scoping locals)
    -- Published for the task creator and dashboard, which are still in
    -- init.lua and used to call addCommentToTask() as a bare global.
    core.provide("asana.addComment", addCommentToTask)
end

-- ---- 6.332.0 — 🔄 ASANA REFRESHES ITSELF, WITHOUT TAKING THE SCREEN ------
--
-- LL asked for this with a draft of his own: a timer that activates
-- Asana, posts ⌘R and activates the previous app back. The feature is
-- his; four things about that shape are not, and each is a rule this
-- config already has:
--
--   1. 🔁 hs.eventtap.keyStroke POSTS, so that ⌘R comes back through our
--      own taps as TYPING (6.218.0 — the "banshee"). Anything posting
--      keys has to drain an injection guard.
--   2. ⌨️ It steals focus twice every interval, with a window in which
--      nobody owns the keyboard — so a ⌘R can land in whatever he
--      clicked into mid-flight.
--   3. 🪜 Nested unheld doAfters are 6.196.1's shape in hs.timer.
--   4. 🔎 No switch, no report, and nothing said when Asana is not
--      running.
--
-- 🔑 SO IT DOES NOT POST A KEY AT ALL. `app:selectMenuItem` drives the
-- app's own menu WITHOUT activating it: no focus theft, no posted
-- keystroke, no injection guard, nothing to put back. His draft and
-- this do the same thing to Asana and differ entirely in what they do
-- to everything else.
--
-- 🚨 AND IT NEVER FALLS BACK TO STEALING FOCUS. If Asana has no such
-- menu item, this says so once and does NOTHING — because the
-- alternative is the activate-and-⌘R shape above, and taking his
-- keyboard every five minutes is not a thing to do on a guess
-- (6.201.0: ask for the artefact rather than theorise). The report
-- names exactly which menu path worked, or that none did, so the next
-- release is aimed instead of guessed.
M.refreshApp   = "Asana"
M.refreshMins  = 5        -- 0 disables it
M.refreshFirst = 90       -- seconds after boot before the first one
-- Several plausible paths, tried in order: Asana's Electron menu has
-- changed names before and a single hard-coded path is 6.284.0's
-- "a fresh answer to a stale question" all over again.
M.refreshPaths = {
    { "View", "Reload" },
    { "View", "Refresh" },
    { "View", "Force Reload" },
}
M.refreshStats = { tried = 0, ok = 0, notRunning = 0, noMenu = 0,
                   last = nil, path = nil, saidNoMenu = false }

-- PURE: given what the app answered for each path, which one to use and
-- why. Separated from the driving so the gate proves the whole decision
-- with no Asana and no Mac.
function M.refreshPick(paths, works)
    for _, p in ipairs(paths or {}) do
        if works(p) then return p, table.concat(p, " → ") end
    end
    return nil, "no reload item in Asana's menus"
end

function M.refreshNow()
    local st = M.refreshStats
    st.tried = st.tried + 1
    local app
    pcall(function() app = hs.application.get(M.refreshApp) end)
    if not app then
        st.notRunning = st.notRunning + 1
        st.last = { at = os.time(), ok = false, why = M.refreshApp .. " is not running" }
        return false, st.last.why
    end
    -- 🚨 selectMenuItem ANSWERS whether it found the item, and that
    -- answer is READ: a pcall alone is true whether or not the menu
    -- path exists (6.179.0 / 6.304.0), which would make a dead refresh
    -- report as a working one for ever.
    local function works(path)
        local ok, found = pcall(function() return app:selectMenuItem(path) end)
        return ok and found == true
    end
    local path, why = M.refreshPick(M.refreshPaths, works)
    if not path then
        st.noMenu = st.noMenu + 1
        st.last = { at = os.time(), ok = false, why = why }
        -- 🔕 ONCE PER SESSION for this one: it is a fact about his Asana
        -- build, not an event, and a line every five minutes is a line
        -- he stops reading (6.269.0).
        if not st.saidNoMenu then
            st.saidNoMenu = true
            pcall(print, "🔄 Asana refresh: no Reload item in Asana's menus — "
                  .. "nothing is being refreshed, and nothing will steal your "
                  .. "keyboard to try. _G.asanaRefreshReport() has the detail.")
        end
        return false, why
    end
    st.ok = st.ok + 1
    st.path = table.concat(path, " → ")
    st.last = { at = os.time(), ok = true, why = st.path }
    return true, st.path
end

function _G.asanaRefreshReport()
    local st = M.refreshStats
    local L = { "🔄 ASANA AUTO-REFRESH" }
    if (tonumber(M.refreshMins) or 0) <= 0 then
        L[#L + 1] = "   off (asana_comments = { refreshMins = 5 } turns it on)"
    else
        L[#L + 1] = "   every " .. M.refreshMins .. " min · "
                    .. st.tried .. " attempt(s) · " .. st.ok .. " refreshed"
        L[#L + 1] = "   how    : the app's own menu, never a posted ⌘R — it does "
                    .. "not activate Asana and never takes your keyboard"
        if st.path then
            L[#L + 1] = "   path   : " .. st.path
        end
        if st.noMenu > 0 then
            L[#L + 1] = "   ⚠️ NO RELOAD ITEM found in Asana's menus (" .. st.noMenu
                        .. " attempt(s)). Nothing is refreshed."
            L[#L + 1] = "      ↳ hs.inspect(hs.application.get(\"Asana\"):getMenuItems())"
            L[#L + 1] = "        in the Console names the real path; send it and this"
            L[#L + 1] = "        becomes one line."
        end
        if st.notRunning > 0 then
            L[#L + 1] = "   asleep : " .. st.notRunning
                        .. " attempt(s) found Asana not running — not a fault"
        end
        if st.last then
            L[#L + 1] = "   last   : " .. (st.last.ok and "✅ " or "· ")
                        .. os.date("%H:%M:%S", st.last.at) .. " — " .. tostring(st.last.why)
        else
            L[#L + 1] = "   last   : nothing tried yet (the first one waits "
                        .. M.refreshFirst .. " s after boot)"
        end
    end
    local out = table.concat(L, "\n")
    print(out)
    return out
end

-- 🪜 In warm, never setup (6.267.0), and HELD in their own slots
-- (6.196.1). This module had no M.warm, so there is no shadow to create
-- — 6.308.0's defect is having TWO, and the gate's sentry checks it.
function M.warm(core)
    if (tonumber(M.refreshMins) or 0) <= 0 then return false, "off" end
    local ok = pcall(function()
        _G.asanaRefreshTimer = hs.timer.doEvery(M.refreshMins * 60,
                                                function() pcall(M.refreshNow) end)
        _G.asanaRefreshFirst = hs.timer.doAfter(M.refreshFirst,
                                                function() pcall(M.refreshNow) end)
    end)
    return ok
end

return M
