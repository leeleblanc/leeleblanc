-- =====================================================================
-- MODULE: ASANA COMMENTS (was 3.5)
-- =====================================================================

-- Moved out of init.lua in 6.40.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "Asana Comments",
    order = 2,
    -- no cheatsheet group of its own
}

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
        "| 2. SAC Library Team Member Projects & Tasks |",
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

    local function resolveAsanaTeamGids(onDone)
        if asanaTeamGidsResolved or #asanaTeamNames == 0 then onDone() return end
        hs.http.asyncGet(
            "https://app.asana.com/api/1.0/workspaces/" .. core.asanaWorkspaceId .. "/teams?opt_fields=name",
            { ["Authorization"] = "Bearer " .. core.asanaToken },
            function(status, body)
                if status == 200 then
                    local data = _G.safeJson(body, "asana/teams")
                    if data and data.data then
                        for _, wantName in ipairs(asanaTeamNames) do
                            local wantLower = wantName:lower():match("^%s*(.-)%s*$")
                            local found = false
                            for _, t in ipairs(data.data) do
                                if t.name and t.name:lower():match("^%s*(.-)%s*$") == wantLower then
                                    table.insert(asanaTeamGids, t.gid)
                                    asanaTeamGidNames[t.gid] = asanaCleanTeamName(t.name)
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                print("⚠️ Asana team not found by name: \"" .. wantName .. "\" — check spelling/spacing against Asana")
                            end
                        end
                    end
                else
                    print("⚠️ Asana team list fetch failed (HTTP " .. tostring(status) .. ")")
                end
                asanaTeamGidsResolved = true
                onDone()
            end)
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
end

return M
