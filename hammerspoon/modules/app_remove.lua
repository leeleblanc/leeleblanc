-- =====================================================================
-- MODULE: APP REMOVAL (⇪⇧[) — to the Trash, never erased
-- =====================================================================
-- LL: "Build App removal: trash do not erase, home folder only and
-- applicable files, delete any temp files."
--
-- Press the key, pick an app, and see EXACTLY what would move — the
-- .app, and every leftover this Mac is keeping for it, each with its
-- size and the rule that matched it. Nothing moves on that pass. Press
-- ⏎ again and it all goes to the Trash, where you empty it yourself.
--
-- 🚨 THIS IS THE ONLY TOOL IN THIS CONFIG THAT MOVES FILES THE PERSON
-- DID NOT NAME ONE BY ONE, so its rules are written before its feature:
--
--   1. NOTHING IS ERASED. Every path goes to ~/.Trash through a rename,
--      the way vault.lua's delete does (6.280.0 — an unrecoverable
--      delete is the one failure in this config with no way back). This
--      config does not call os.remove on anything here, and a source
--      sentry fails the gate if it ever appears. "Delete the temp
--      files" is satisfied by the Trash: the caches go WITH the app
--      rather than being left behind, and emptying the Trash is his.
--
--   2. IT CANNOT REACH OUTSIDE TWO PLACES. Leftovers are looked for in
--      the HOME folder only (his words) and the app itself in
--      /Applications or ~/Applications. `ar.insideAllowed` is PURE and
--      every single path is put through it immediately before it moves,
--      not merely when the list is built — a guard that runs when a
--      list is ASSEMBLED is not a guard on what is acted on.
--
--   3. IT MATCHES ON THE BUNDLE ID, and says when it did not. An app's
--      bundle id (com.apple.Safari) is what macOS files its leftovers
--      under; a NAME match ("Chess") is a guess that can hit a folder
--      belonging to something else. Both are offered, the rule that
--      matched each row is PRINTED, and a name match is drawn with a ⚠️
--      so a wrong one is visible before it moves rather than after.
--
--   4. IT REFUSES A RUNNING APP. Moving a running app's support folder
--      out from under it is how a half-removed app rewrites the folder
--      a second later. modules/app_kill.lua already ends a process;
--      this one says so and stops.
--
--   5. THE FIRST PRESS NEVER MOVES ANYTHING. The list IS the feature:
--      what a removal tool owes is that you can see what it is about to
--      do while there is still time to say no.
--
-- 📏 WHAT IT DOES NOT DO, said rather than discovered: it does not touch
-- /Library (the system-wide one), it does not remove launch daemons, it
-- does not look for a vendor's uninstaller, and it does not chase
-- helper apps with a different bundle id. Those live outside the home
-- folder or need a password, and both are his call, not mine.
-- =====================================================================

local M = {
    name   = "app_remove",
    order  = 14.5,
    family = "files",
    cheatsheet = {
        title = "🗑 APP REMOVAL (⇪⇧[ — to the Trash, never erased)",
        entries = {
            { "⇪⇧[",    "Pick an app — ⇧ plus the [ key, right of P" },
            { "⏎",      "SHOWS what would move: the app and every leftover," },
            { "",       "each with its size and the rule that found it." },
            { "",       "Nothing moves on this press." },
            { "⏎ again","Moves all of it to the Trash. You empty the Trash." },
            { "⚠️ rows", "Matched by NAME, not by bundle id — a guess. Read" },
            { "",       "those before the second press." },
            { "where",  "Leftovers: your home folder only. The app itself:" },
            { "",       "/Applications or ~/Applications. Nowhere else." },
            { "running","It refuses to remove an app that is open — quit it" },
            { "",       "first (⇪⇧X ends a process)" },
            { "undo",   "Finder → Trash → Put Back, like any other file" },
            { "console","_G.appRemove(\"Name\") lists · _G.appRemoveGo() does it" },
            { "check",  "_G.appRemoveReport() — what it last listed or moved" },
        },
    },
}

-- ---------------------------------------------------------------------
-- PURE — every decision, provable with no Mac. On M so the gate reaches
-- them and so build-feature-list reads a table that is true before
-- setup has run (6.311.0).
-- ---------------------------------------------------------------------

-- 🔒 THE GUARD THE WHOLE MODULE RESTS ON. A path may be moved only if it
-- sits INSIDE one of the allowed roots — and "inside" is a component
-- test, never a substring: "/Users/lee-evil" starts with "/Users/lee"
-- and is a different person's folder (6.320.0 found the mirror of this
-- in the vault, where a `..` substring test refused an ordinary note).
function M.insideAllowed(path, roots)
    if type(path) ~= "string" or path == "" then return false, "no path" end
    if type(roots) ~= "table" or #roots == 0 then return false, "no allowed roots" end
    if path:sub(1, 1) ~= "/" then return false, "not an absolute path" end
    -- a path component that is exactly ".." can climb out of any root,
    -- however the text reads
    for part in path:gmatch("[^/]+") do
        if part == ".." then return false, "that path can climb out" end
    end
    local clean = path:gsub("/+$", "")
    for _, r in ipairs(roots) do
        local root = tostring(r or ""):gsub("/+$", "")
        if root ~= "" then
            -- it must be INSIDE, never the root itself: removing
            -- /Applications or the home folder is not a thing this tool
            -- may ever be asked to do, by any bug
            if clean:sub(1, #root + 1) == (root .. "/") and #clean > #root + 1 then
                return true, root
            end
        end
    end
    return false, "outside every folder this tool may touch"
end

-- 🕰 PURE — the name a path takes in the Trash. Two removals of one name
-- in the same second would collide and make the SECOND unrecoverable
-- through the very folder that exists to make it recoverable (6.321.0
-- found exactly that in the vault's bin). The stamp has second
-- resolution, so a tie-break rides on top.
function M.trashNameFor(path, now, taken)
    local base = tostring(path or ""):gsub("/+$", ""):match("[^/]+$") or "item"
    local stamp = os.date("!%Y-%m-%d %H%M%S", tonumber(now) or 0)
    local name, n = base .. "  " .. stamp, 1
    taken = type(taken) == "table" and taken or {}
    while taken[name] do
        n = n + 1
        name = base .. "  " .. stamp .. " (" .. n .. ")"
    end
    return name
end

-- 🔎 PURE — which leftovers a bundle id and an app name imply, and WHY
-- each one matched. The caller stats them; this only says where to look
-- and what rule put it on the list, so the whole map is provable with
-- no Mac and a wrong rule is visible in a test rather than on his disk.
function M.leftoverPlan(home, bundleId, appName)
    local out = {}
    local function add(path, why, sure)
        if type(path) == "string" and path ~= "" then
            out[#out + 1] = { path = path, why = why, sure = sure and true or false }
        end
    end
    home = tostring(home or ""):gsub("/+$", "")
    if home == "" then return out end
    local L = home .. "/Library"
    if type(bundleId) == "string" and bundleId ~= "" then
        -- 🪪 BY BUNDLE ID — what macOS itself files these under, so each
        -- of these is an answer rather than a guess.
        add(L .. "/Preferences/" .. bundleId .. ".plist",        "bundle id", true)
        add(L .. "/Caches/" .. bundleId,                          "bundle id", true)
        add(L .. "/Containers/" .. bundleId,                      "bundle id", true)
        add(L .. "/Application Support/" .. bundleId,             "bundle id", true)
        add(L .. "/HTTPStorages/" .. bundleId,                    "bundle id", true)
        add(L .. "/HTTPStorages/" .. bundleId .. ".binarycookies","bundle id", true)
        add(L .. "/WebKit/" .. bundleId,                          "bundle id", true)
        add(L .. "/Cookies/" .. bundleId .. ".binarycookies",     "bundle id", true)
        add(L .. "/Saved Application State/" .. bundleId .. ".savedState",
                                                                  "bundle id", true)
        add(L .. "/LaunchAgents/" .. bundleId .. ".plist",        "bundle id", true)
        add(L .. "/Group Containers/" .. bundleId,                "bundle id", true)
    end
    if type(appName) == "string" and appName ~= "" then
        -- ⚠️ BY NAME — a guess, and marked as one. Most apps really do
        -- call their support folder after themselves, and some other
        -- app's folder is called the same thing.
        add(L .. "/Application Support/" .. appName,              "the app's NAME", false)
        add(L .. "/Logs/" .. appName,                             "the app's NAME", false)
        add(L .. "/Caches/" .. appName,                           "the app's NAME", false)
    end
    -- 🔑 DE-DUPLICATE BY PATH, FIRST WINS — and that is only correct
    -- because the BUNDLE-ID rows above are added before the NAME rows,
    -- deliberately. A folder both rules reach is an answer, not a guess,
    -- and drawing it with a ⚠️ would teach him to ignore the ⚠️ — which
    -- is the only thing standing between him and a wrong folder.
    --
    -- 🗑 A "keep the surer one" branch was written here and TAKEN OUT
    -- AGAIN: with the order above it can never run, so no mutation could
    -- kill it and no test could fail it. A guard no test can fail is
    -- dead code with a comment on it (6.199.0, eighth time). What
    -- replaces it is a check on the ORDER, which is the invariant this
    -- really rests on and which a reordering WILL break.
    local seen, keep = {}, {}
    for _, e in ipairs(out) do
        if not seen[e.path] then seen[e.path] = true ; keep[#keep + 1] = e end
    end
    return keep
end

-- 📏 PURE — a size in words, for a list a person reads before saying yes
function M.prettySize(n)
    n = tonumber(n) or 0
    if n >= 1024 * 1024 * 1024 then return ("%.1f GB"):format(n / 1024 / 1024 / 1024) end
    if n >= 1024 * 1024       then return ("%.1f MB"):format(n / 1024 / 1024) end
    if n >= 1024              then return ("%.0f KB"):format(n / 1024) end
    return tostring(n) .. " B"
end

-- 🗳 PURE — may this removal go ahead? Answers the verdict AND the
-- reason, because "nothing was found" and "it is running" and "you have
-- not looked yet" send him to three different places (6.196.1).
function M.goVerdict(plan)
    if type(plan) ~= "table" or not plan.app then
        return false, "nothing has been listed yet — press the key and pick an app first"
    end
    if plan.running then
        return false, "“" .. tostring(plan.name) .. "” is open — quit it first"
    end
    if (tonumber(plan.count) or 0) == 0 then
        return false, "there is nothing to move"
    end
    return true, "ready"
end

function M.setup(core)
    local ar = {}
    M.ar = ar

    ar.enabled   = true
    ar.mods      = { "shift" }
    ar.key       = "["
    ar.maxRows   = 60          -- leftovers listed; a bound, and a state
    ar.plan      = nil         -- what the last listing found
    ar.moved     = { runs = 0, items = 0, bytes = 0, last = nil, fails = 0, why = nil }

    local home = tostring(core.homeDir or os.getenv("HOME") or ""):gsub("/+$", "")

    -- 🔒 THE TWO ROOTS, AND NOTHING ELSE. Leftovers: the home folder,
    -- his word. The app itself: the two places an app legitimately
    -- lives. /Library and /System are deliberately absent — they need a
    -- password and they are not his to hand to a script.
    ar.appRoots  = { "/Applications", home .. "/Applications" }
    ar.allowed   = { home, "/Applications" }

    local function stat(p) return hs.fs.attributes(p) end

    -- how big is it, bounded — a `du` over a huge cache is main-thread
    -- work (6.228.0), so a folder is reported by its own entry count
    -- rather than walked to the bottom
    local function sizeOf(p)
        local a = stat(p)
        if not a then return nil end
        if a.mode ~= "directory" then return a.size or 0 end
        local total, n = 0, 0
        local ok = pcall(function()
            for e in hs.fs.dir(p) do
                if e ~= "." and e ~= ".." then
                    n = n + 1
                    if n > 400 then break end
                    local b = hs.fs.attributes(p .. "/" .. e)
                    if b and b.mode ~= "directory" then total = total + (b.size or 0) end
                end
            end
        end)
        if not ok then return 0 end
        return total
    end

    local function appPath(name)
        for _, root in ipairs(ar.appRoots) do
            local p = root .. "/" .. name .. ".app"
            if stat(p) then return p end
        end
        return nil
    end

    local function bundleOf(p)
        local id
        pcall(function()
            local info = hs.application.infoForBundlePath(p)
            id = info and info.CFBundleIdentifier
        end)
        return (type(id) == "string" and id ~= "") and id or nil
    end

    local function isRunning(name, bundleId)
        local running = false
        pcall(function()
            for _, a in ipairs(hs.application.runningApplications() or {}) do
                local ok1 = (a.name and a:name() == name)
                local ok2 = (bundleId and a.bundleID and a:bundleID() == bundleId)
                if ok1 or ok2 then running = true end
            end
        end)
        return running
    end

    -- 📋 BUILD THE LIST. Nothing is moved here, ever.
    function ar.list(name)
        if type(name) ~= "string" or name == "" then
            return nil, "no app named"
        end
        local app = appPath(name)
        if not app then
            return nil, "no “" .. name .. ".app” in /Applications or ~/Applications"
        end
        local bundleId = bundleOf(app)
        local items = { { path = app, why = "the app itself", sure = true,
                          size = sizeOf(app) } }
        local capped = false
        for _, e in ipairs(M.leftoverPlan(home, bundleId, name)) do
            if #items >= ar.maxRows then capped = true break end
            local a = stat(e.path)
            if a then
                items[#items + 1] = { path = e.path, why = e.why, sure = e.sure,
                                      size = sizeOf(e.path) }
            end
        end
        local bytes = 0
        for _, it in ipairs(items) do bytes = bytes + (tonumber(it.size) or 0) end
        ar.plan = { name = name, app = app, bundleId = bundleId,
                    items = items, count = #items, bytes = bytes,
                    capped = capped, running = isRunning(name, bundleId),
                    at = os.time(), guesses = 0 }
        for _, it in ipairs(items) do
            if not it.sure then ar.plan.guesses = ar.plan.guesses + 1 end
        end
        return ar.plan
    end

    -- 🗑 AND THIS IS THE ONLY THING THAT MOVES ANYTHING.
    function ar.go()
        local ok, why = M.goVerdict(ar.plan)
        if not ok then return false, why end
        local plan = ar.plan
        local trash = home .. "/.Trash"
        -- the Trash has to exist and be ours before anything is renamed
        if not stat(trash) then
            pcall(function() hs.fs.mkdir(trash) end)
        end
        if not stat(trash) then
            return false, "there is no ~/.Trash to move anything into"
        end
        local taken, done, failed, bytes = {}, {}, {}, 0
        for _, it in ipairs(plan.items) do
            -- 🔒 THE GUARD RUNS HERE, immediately before the move, over
            -- the path that is ACTUALLY about to be renamed — not when
            -- the list was built. A check on a list is not a check on
            -- what is acted on.
            local allowed, aWhy = M.insideAllowed(it.path, ar.allowed)
            if not allowed then
                failed[#failed + 1] = { path = it.path, why = aWhy }
            else
                local name = M.trashNameFor(it.path, os.time(), taken)
                taken[name] = true
                local dest = trash .. "/" .. name
                local okR, rWhy = os.rename(it.path, dest)
                if okR then
                    done[#done + 1] = { path = it.path, to = dest }
                    bytes = bytes + (tonumber(it.size) or 0)
                else
                    failed[#failed + 1] = { path = it.path,
                                            why = tostring(rWhy or "the move was refused") }
                end
            end
        end
        ar.moved.runs  = ar.moved.runs + 1
        ar.moved.items = ar.moved.items + #done
        ar.moved.bytes = ar.moved.bytes + bytes
        ar.moved.fails = ar.moved.fails + #failed
        ar.moved.last  = { name = plan.name, moved = #done, failed = #failed,
                           bytes = bytes, at = os.time() }
        if #failed > 0 then
            ar.moved.why = tostring(failed[1].why)
            core.degrade("App removal",
                         #failed .. " of " .. plan.count .. " item(s) could NOT be moved — "
                         .. tostring(failed[1].path) .. ": " .. tostring(failed[1].why))
        end
        -- the plan is SPENT: a second ⏎ must not try to move paths that
        -- are already in the Trash, and a stale plan is how a later
        -- press acts on a listing he has forgotten making
        ar.plan = nil
        return true, { moved = #done, failed = #failed, bytes = bytes }
    end

    -- ---- the picker ---------------------------------------------------
    local function describe(plan)
        local L = {}
        L[#L + 1] = "🗑 " .. plan.name .. " — " .. plan.count .. " item(s), "
                    .. M.prettySize(plan.bytes) .. " → the Trash"
        L[#L + 1] = plan.bundleId and ("   bundle : " .. plan.bundleId)
                    or "   bundle : ⚠️ this Mac would not say — every row below is a NAME guess"
        for _, it in ipairs(plan.items) do
            L[#L + 1] = "   " .. (it.sure and "·" or "⚠️") .. " " .. it.path
                        .. "   (" .. it.why .. ", " .. M.prettySize(it.size) .. ")"
        end
        if plan.capped then
            L[#L + 1] = "   ⚠️ STOPPED AT " .. ar.maxRows .. " ROWS — there may be more"
        end
        if plan.running then
            L[#L + 1] = "   ⚠️ " .. plan.name .. " IS OPEN — quit it first; nothing will move"
        elseif plan.guesses > 0 then
            L[#L + 1] = "   ⚠️ " .. plan.guesses .. " row(s) matched by NAME, not by bundle"
                        .. " id — read those before you say yes"
        end
        L[#L + 1] = "   Nothing has moved. Press ⇪⇧[ again and pick “✅ Move it all to"
                    .. " the Trash” — or _G.appRemoveGo()"
        return table.concat(L, "\n")
    end

    function ar.show()
        -- a plan already in hand → offer the confirmation first
        local rows = {}
        if ar.plan then
            local can, why = M.goVerdict(ar.plan)
            rows[#rows + 1] = {
                text    = can and ("✅ Move “" .. ar.plan.name .. "” to the Trash — "
                                   .. ar.plan.count .. " item(s), "
                                   .. M.prettySize(ar.plan.bytes))
                            or ("🚫 " .. tostring(why)),
                subText = can and "Nothing is erased. Finder → Trash → Put Back undoes it."
                            or "Pick another app below",
                go      = can and true or false,
            }
        end
        local apps, seen = {}, {}
        for _, root in ipairs(ar.appRoots) do
            pcall(function()
                for e in hs.fs.dir(root) do
                    local n = e:match("^(.+)%.app$")
                    if n and not seen[n] then
                        seen[n] = true ; apps[#apps + 1] = n
                    end
                end
            end)
        end
        table.sort(apps)
        for _, n in ipairs(apps) do
            rows[#rows + 1] = { text = n, subText = "⏎ shows what would move — nothing moves yet",
                                app = n }
        end
        if #rows == 0 then
            core.degrade("App removal", "no applications could be listed")
            return false, "no applications could be listed"
        end
        -- 🚨 core.showPopup SHOWS the picker and answers true/false — it
        -- does NOT hand the chooser back. Building it, filling it and
        -- only then asking showPopup to place it is the shape every
        -- other picker in this config uses, and the one the placement
        -- record depends on (6.127.0).
        local ch = hs.chooser.new(function(row)
            _G.choosers.appRemove = nil
            if not row then return end
            if row.go then
                local okG, res = ar.go()
                if okG then
                    hs.alert.show("🗑 Moved " .. res.moved .. " item(s) to the Trash"
                                  .. (res.failed > 0 and (" · ⚠️ " .. res.failed .. " refused") or "")
                                  .. "\nFinder → Trash → Put Back undoes it", 5)
                else
                    hs.alert.show("🚫 " .. tostring(res), 4)
                end
                return
            end
            if row.app then
                local plan, why = ar.list(row.app)
                if not plan then
                    hs.alert.show("🗑 " .. tostring(why), 4)
                    return
                end
                print(describe(plan))
                hs.alert.show("🗑 " .. plan.name .. " — " .. plan.count .. " item(s), "
                              .. M.prettySize(plan.bytes)
                              .. "\nNOTHING HAS MOVED. The Console lists every one."
                              .. "\n⇪⇧[ again to confirm.", 7)
            end
        end)
        if not ch then return false, "macOS would not open the picker" end
        ch:choices(rows)
        ch:placeholderText("Remove an app — to the Trash, never erased")
        _G.choosers.appRemove = ch
        -- 🧊 AND THE ANSWER IS READ. A refused show leaves a picker that
        -- is not on screen while this module thinks one is open
        -- (6.265.0 · 6.326.0 — a published handle is a claim about the
        -- world, written after the world agrees).
        local shown = false
        if core.showPopup then shown = core.showPopup(ch) ~= false
        else shown = pcall(function() ch:show() end) end
        if not shown then
            _G.choosers.appRemove = nil
            core.degrade("App removal", "macOS would not put the picker on screen")
            return false, "macOS would not put the picker on screen"
        end
        return true
    end

    _G.appRemove = function(name)
        if type(name) ~= "string" then return ar.show() end
        local plan, why = ar.list(name)
        if not plan then print("🗑 " .. tostring(why)) ; return false, why end
        print(describe(plan))
        return plan
    end
    _G.appRemoveGo = function()
        local ok, res = ar.go()
        if not ok then print("🗑 " .. tostring(res)) ; return false, res end
        print("🗑 Moved " .. res.moved .. " item(s), " .. M.prettySize(res.bytes)
              .. " to the Trash" .. (res.failed > 0 and (" · ⚠️ " .. res.failed .. " refused") or "")
              .. "\n   Nothing was erased — Finder → Trash → Put Back undoes it.")
        return true, res
    end

    function _G.appRemoveReport()
        local L = { "🗑 APP REMOVAL " .. tostring(_G.configVersion or "") }
        L[#L + 1] = "   switch : " .. (ar.enabled and "on" or "OFF")
                    .. " · ⇪⇧[ · leftovers are looked for in " .. home .. " ONLY"
        L[#L + 1] = "   apps   : " .. table.concat(ar.appRoots, " · ")
        if not ar.plan then
            L[#L + 1] = "   listed : nothing is listed right now — press ⇪⇧[ and pick an app"
        else
            L[#L + 1] = "   listed : " .. ar.plan.name .. " — " .. ar.plan.count
                        .. " item(s), " .. M.prettySize(ar.plan.bytes)
                        .. (ar.plan.running and "  ⚠️ IT IS OPEN" or "")
            L[#L + 1] = "   ↳ " .. (ar.plan.bundleId or "⚠️ no bundle id — every row is a guess")
            if ar.plan.guesses > 0 then
                L[#L + 1] = "   ↳ ⚠️ " .. ar.plan.guesses .. " row(s) matched by NAME"
            end
        end
        if ar.moved.runs == 0 then
            L[#L + 1] = "   moved  : nothing has been removed this session"
        else
            L[#L + 1] = "   moved  : " .. ar.moved.items .. " item(s) across "
                        .. ar.moved.runs .. " removal(s) · " .. M.prettySize(ar.moved.bytes)
            local lm = ar.moved.last
            if lm then
                L[#L + 1] = "   ↳ last  : " .. lm.name .. " — " .. lm.moved .. " moved"
                            .. (lm.failed > 0 and (" · " .. lm.failed .. " REFUSED") or "")
                            .. " at " .. os.date("%H:%M:%S", lm.at)
            end
            if ar.moved.fails > 0 then
                L[#L + 1] = "   ↳ ⚠️ " .. ar.moved.fails .. " refused — " .. tostring(ar.moved.why)
            end
        end
        L[#L + 1] = "   🔒 nothing is ever erased: every path is RENAMED into "
                    .. home .. "/.Trash"
        local out = table.concat(L, "\n")
        print(out)
        return out
    end

    if ar.enabled then
        core.hyperAddShortcut(ar.mods, ar.key, function() ar.show() end, "remove an app")
    end
end

return M
