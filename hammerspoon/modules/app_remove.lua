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
            { "⏎",      "SHOWS every file it would move, one row each, with" },
            { "",       "its size and whether removing it is safe. Nothing" },
            { "",       "moves on this press, or on any press but the last." },
            { "verdict","✅ safe — a cache, its settings, the app itself." },
            { "",       "⚠️ careful — it may hold YOUR OWN files, or it was" },
            { "",       "matched by name rather than by the app\'s id." },
            { "",       "A row that holds files of yours SAYS HOW MANY." },
            { "start",  "✅ rows start selected · ⚠️ rows start KEPT, so" },
            { "",       "nothing risky moves unless you ask for it" },
            { "⏎ a row","Toggles that one between [ MOVE ] and [ keep ]." },
            { "",       "The list stays open — change as many as you like." },
            { "bulk",   "Rows at the top: keep everything · keep nothing ·" },
            { "",       "back to what this tool suggests" },
            { "✅ Move","The row at the top of the list does it, for the" },
            { "",       "selected rows only. Everything kept stays put." },
            { "where",  "Leftovers: your home folder only. The app itself:" },
            { "",       "/Applications or ~/Applications. Nowhere else." },
            { "running","It refuses to remove an app that is open — quit it" },
            { "",       "first (⇪⇧X ends a process)" },
            { "undo",   "Finder → Trash → Put Back, like any other file" },
            { "console","_G.appRemove(\"Name\") lists · _G.appRemoveKeep(3)" },
            { "",       "toggles row 3 · _G.appRemoveGo() moves the rest" },
            { "",       "_G.appRemoveKeepAll() · ...KeepNone() · ...Suggested()" },
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
    -- 🗳 6.388.0 — EVERY ROW CARRIES WHAT KIND OF THING IT IS, and the
    -- kind is what M.riskOf reads to say whether removing it is safe. It
    -- is recorded here, where the path is chosen and the answer is known,
    -- rather than inferred from the path later: a verdict worked out by
    -- pattern-matching a string is a guess about a thing we already knew.
    local function add(path, why, sure, kind)
        if type(path) == "string" and path ~= "" then
            out[#out + 1] = { path = path, why = why, sure = sure and true or false,
                              kind = kind }
        end
    end
    home = tostring(home or ""):gsub("/+$", "")
    if home == "" then return out end
    local L = home .. "/Library"
    if type(bundleId) == "string" and bundleId ~= "" then
        -- 🪪 BY BUNDLE ID — what macOS itself files these under, so each
        -- of these is an answer rather than a guess.
        add(L .. "/Preferences/" .. bundleId .. ".plist",        "bundle id", true, "prefs")
        add(L .. "/Caches/" .. bundleId,                          "bundle id", true, "caches")
        add(L .. "/Containers/" .. bundleId,                      "bundle id", true, "containers")
        add(L .. "/Application Support/" .. bundleId,             "bundle id", true, "appsupport")
        add(L .. "/HTTPStorages/" .. bundleId,                    "bundle id", true, "httpstorages")
        add(L .. "/HTTPStorages/" .. bundleId .. ".binarycookies","bundle id", true, "httpstorages")
        add(L .. "/WebKit/" .. bundleId,                          "bundle id", true, "webkit")
        add(L .. "/Cookies/" .. bundleId .. ".binarycookies",     "bundle id", true, "cookies")
        add(L .. "/Saved Application State/" .. bundleId .. ".savedState",
                                                                  "bundle id", true, "savedstate")
        add(L .. "/LaunchAgents/" .. bundleId .. ".plist",        "bundle id", true, "launchagents")
        add(L .. "/Group Containers/" .. bundleId,                "bundle id", true, "groupcontainers")
    end
    if type(appName) == "string" and appName ~= "" then
        -- ⚠️ BY NAME — a guess, and marked as one. Most apps really do
        -- call their support folder after themselves, and some other
        -- app's folder is called the same thing.
        add(L .. "/Application Support/" .. appName,              "the app's NAME", false, "appsupport")
        add(L .. "/Logs/" .. appName,                             "the app's NAME", false, "logs")
        add(L .. "/Caches/" .. appName,                           "the app's NAME", false, "caches")
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
    -- 🗳 6.388.0 — AND "you have kept every row" IS A DIFFERENT ANSWER
    -- from "there is nothing to move". One is his decision and one is an
    -- empty folder; a shared sentence would read as a fault (6.196.1).
    local moving = M.selectedItems(plan.items, plan.keep)
    if #moving == 0 then
        return false, "every row is marked KEEP — nothing is selected to move"
    end
    return true, "ready"
end

-- =====================================================================
-- 🗳 6.388.0 — IS IT DAMAGING? AND MAY I LEAVE THAT ONE?
-- =====================================================================
-- LL: "this tool should be present me with a list of all files that are
-- going to be removed, and it should say, if it is damaging or not, it
-- should give me the option to leave files, so it should be a very
-- iterative process … the ultimate outcome is a solid analysis of what
-- can be removed. And then give me an option for what to remove safely."
--
-- 6.384.0 showed the list and then moved ALL of it. What was missing is
-- the middle: a verdict per file, and a way to say no to one row without
-- saying no to the removal.
--
-- 🔑 AND THE VERDICT IS COMPUTED FROM WHAT THE THING IS, never guessed.
-- Every row already carries the RULE that found it; this adds what KIND
-- of thing it is, and the kind is what decides the risk. A cache is
-- rebuilt the next time the app runs. A preferences plist is settings he
-- is removing on purpose. A CONTAINER is where a sandboxed app keeps its
-- own Documents — that is the one row in this list that can take his
-- files with it, and it is the reason the question needed answering.
local RISK = {
    -- kind                 verdict    why, in his words
    app              = { "safe",    "the app itself — re-downloadable" },
    prefs            = { "safe",    "its settings — losing them is the point of removing it" },
    caches           = { "safe",    "a cache — rebuilt automatically, holds nothing of yours" },
    logs             = { "safe",    "its own log files" },
    savedstate       = { "safe",    "which windows were open last time" },
    webkit           = { "safe",    "web data it cached" },
    httpstorages     = { "safe",    "cookies and web storage" },
    cookies          = { "safe",    "cookies" },
    launchagents     = { "safe",    "what starts it automatically — removing it stops that" },
    appsupport       = { "careful", "APPS KEEP YOUR OWN DATA HERE as well as settings" },
    containers       = { "careful", "a sandboxed app's own Documents live inside this" },
    groupcontainers  = { "careful", "SHARED with the vendor's other apps — removing it can "
                                 .. "break one you still have" },
}

-- 🗳 PURE — the verdict and the reason for one row. Two things can make a
-- row risky and they are different risks, so both are said:
--   · WHAT it is (a container may hold his documents);
--   · HOW it was found (a NAME match may be another app's folder).
-- A row that is risky on both counts gets both sentences, because "this
-- might be your data" and "this might not even be this app's" send him
-- to two different places (6.196.1).
function M.riskOf(entry)
    if type(entry) ~= "table" then return "careful", "nothing is known about this row" end
    local r = RISK[tostring(entry.kind or "")]
    local verdict, why = "careful", "this tool does not know what kind of file this is"
    if r then verdict, why = r[1], r[2] end
    -- ⚠️ A GUESS IS NEVER SAFE, whatever it is a guess ABOUT. The bundle
    -- id is what macOS files a leftover under; a name match is this
    -- config's own inference and can land on another app's folder.
    if entry.sure == false then
        verdict = "careful"
        why = "matched by its NAME, not by the bundle id — this folder may belong to "
              .. "another app · " .. why
    end
    -- 🚨 AND THE EVIDENCE OUTRANKS THE LABEL. A container is "careful"
    -- because it MIGHT hold his files; one that demonstrably holds twelve
    -- of them is not a maybe, and saying the number is the difference
    -- between a warning and an artefact (6.229.0's yield line, in a
    -- verdict).
    local own = tonumber(entry.ownFiles) or 0
    if own > 0 then
        verdict = "careful"
        why = "HOLDS " .. own .. " FILE(S) THAT LOOK LIKE YOURS — " .. why
    end
    return verdict, why
end

-- 🗳 PURE — which rows start out selected for removal. SAFE rows do;
-- CAREFUL rows do NOT, and he opts in.
--
-- 🔑 THAT DIRECTION IS THE WHOLE SAFETY OF THE RELEASE, and it is
-- 6.319.0's rule: a default is chosen against the damage its own feature
-- can do. The damage here is moving a folder with his documents in it;
-- the cost of defaulting it off is that he presses ⏎ on one row. 6.384.0
-- moved everything, which is the other choice, and it is the wrong one
-- now that the tool can tell the two apart.
function M.defaultKeep(items)
    local keep = {}
    if type(items) ~= "table" then return keep end
    for i, it in ipairs(items) do
        local verdict = M.riskOf(it)
        if verdict ~= "safe" then keep[i] = true end
    end
    return keep
end

-- 🗳 PURE — the rows that would actually move, and what they weigh.
-- Counted apart: what he left alone, and what was left alone FOR him.
-- A number that summed the two would make his decision read as the
-- tool's (6.378.0 — a first reading is not a change).
function M.selectedItems(items, keep)
    local out, bytes, keptSafe, keptCareful = {}, 0, 0, 0
    if type(items) ~= "table" then return out, 0, 0, 0 end
    keep = type(keep) == "table" and keep or {}
    for i, it in ipairs(items) do
        if keep[i] then
            if M.riskOf(it) == "safe" then keptSafe = keptSafe + 1
            else keptCareful = keptCareful + 1 end
        else
            out[#out + 1] = it
            bytes = bytes + (tonumber(it.size) or 0)
        end
    end
    return out, bytes, keptSafe, keptCareful
end

-- 🔎 PURE given a lister — HOW MANY OF HIS OWN FILES ARE IN THERE. A
-- sandboxed app keeps its documents at <container>/Data/Documents, and an
-- unsandboxed one sometimes at <folder>/Documents. A label saying a
-- folder MIGHT hold his files is a warning; a number saying it holds
-- twelve is an artefact, and he can act on the second.
--
-- 📏 BOUNDED, and the bound is a STATE rather than a footnote (6.197.2):
-- counting is a directory read on the main thread (6.228.0), so it stops
-- at `cap` and the caller is told it stopped. A count taken under a bound
-- is a FLOOR, and the row says "N or more".
function M.ownDataIn(path, lister, cap)
    cap = tonumber(cap) or 50
    if type(path) ~= "string" or path == "" then return 0, false end
    if type(lister) ~= "function" then return 0, false end
    local n, capped = 0, false
    for _, sub in ipairs({ "/Data/Documents", "/Documents", "/Data/Desktop" }) do
        local ok, entries = pcall(lister, path .. sub)
        if ok and type(entries) == "table" then
            for _, e in ipairs(entries) do
                if e ~= "." and e ~= ".." then
                    n = n + 1
                    if n >= cap then capped = true break end
                end
            end
        end
        if capped then break end
    end
    return n, capped
end

-- 📏 PURE — which row a picker lands on after its own list was rebuilt.
-- hs.chooser DROPS the selection on every :choices() (6.227.0), and this
-- list is rebuilt on EVERY toggle — so without this the highlight goes
-- back to the top each time and "a very iterative process" is a list he
-- cannot walk. Asked of clipboard_history's own copy when that module is
-- up (one function, two callers — 6.231.0); this is the floor for a Mac
-- where it did not load, and the gate JOINS the two so they cannot drift.
function M.rowAfterRebuild(want, total)
    total = tonumber(total) or 0
    if total <= 0 then return nil end
    want = tonumber(want) or 0
    if want < 1 then return 1 end
    if want > total then return total end
    return want
end

function M.setup(core)
    local ar = {}
    M.ar = ar

    ar.enabled   = true
    ar.mods      = { "shift" }
    ar.key       = "["
    ar.maxRows   = 60          -- leftovers listed; a bound, and a state
    ar.ownCap    = 50          -- files counted inside a risky folder before the count is a FLOOR
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
                          size = sizeOf(app), kind = "app" } }
        local capped = false
        for _, e in ipairs(M.leftoverPlan(home, bundleId, name)) do
            if #items >= ar.maxRows then capped = true break end
            local a = stat(e.path)
            if a then
                items[#items + 1] = { path = e.path, why = e.why, sure = e.sure,
                                      kind = e.kind, size = sizeOf(e.path) }
            end
        end
        -- 🔎 6.388.0 — ASK THE RISKY ROWS WHAT THEY ARE HOLDING. Only the
        -- two kinds that can hold his own files are walked, so the cost
        -- is two directory reads for a typical app rather than one per
        -- row (6.228.0 — a busy main thread is a mouse this Mac has
        -- lost), and the answer turns a label into a number.
        local function listDir(d)
            local out = {}
            local ok = pcall(function()
                for e in hs.fs.dir(d) do out[#out + 1] = e end
            end)
            if not ok then return nil end
            return out
        end
        for _, it in ipairs(items) do
            if it.kind == "containers" or it.kind == "appsupport" then
                local n, cappedOwn = M.ownDataIn(it.path, listDir, ar.ownCap)
                it.ownFiles, it.ownCapped = n, cappedOwn
            end
            it.verdict, it.risk = M.riskOf(it)
        end
        local bytes = 0
        for _, it in ipairs(items) do bytes = bytes + (tonumber(it.size) or 0) end
        ar.plan = { name = name, app = app, bundleId = bundleId,
                    items = items, count = #items, bytes = bytes,
                    capped = capped, running = isRunning(name, bundleId),
                    at = os.time(), guesses = 0, careful = 0,
                    -- 🗳 6.388.0 — SAFE rows start selected, CAREFUL rows
                    -- start KEPT, and he opts in. 6.319.0: a default is
                    -- chosen against the damage its own feature can do,
                    -- and the damage here is a folder with his documents
                    -- in it. 6.384.0 moved everything; that was the other
                    -- choice, and it was the wrong one once the tool
                    -- could tell the two apart.
                    keep = M.defaultKeep(items),
                    touched = 0 }
        for _, it in ipairs(items) do
            if not it.sure then ar.plan.guesses = ar.plan.guesses + 1 end
            if it.verdict ~= "safe" then ar.plan.careful = ar.plan.careful + 1 end
        end
        return ar.plan
    end

    -- 🔁 6.388.0 — THE ITERATIVE HALF, and it is one line of state. His
    -- words: "it should give me the option to leave files, so it should
    -- be a very iterative process". A row is kept or not; ⏎ flips it;
    -- the list is drawn again. `touched` counts HIS decisions apart from
    -- the tool's defaults, so a report can say which is which.
    function ar.toggle(i)
        if not ar.plan then return false, "nothing is listed" end
        i = tonumber(i)
        local it = i and ar.plan.items[i]
        if not it then return false, "there is no row " .. tostring(i) end
        ar.plan.keep[i] = (not ar.plan.keep[i]) or nil
        ar.plan.touched = ar.plan.touched + 1
        return true, ar.plan.keep[i] and "kept" or "will move"
    end

    -- 🗳 Keep every row, or keep only the risky ones — the two bulk
    -- answers, so a long list does not need sixty presses.
    function ar.keepAll()
        if not ar.plan then return false, "nothing is listed" end
        for i in ipairs(ar.plan.items) do ar.plan.keep[i] = true end
        ar.plan.touched = ar.plan.touched + 1
        return true
    end
    function ar.keepNone()
        if not ar.plan then return false, "nothing is listed" end
        ar.plan.keep = {}
        ar.plan.touched = ar.plan.touched + 1
        return true
    end
    function ar.keepDefaults()
        if not ar.plan then return false, "nothing is listed" end
        ar.plan.keep = M.defaultKeep(ar.plan.items)
        ar.plan.touched = ar.plan.touched + 1
        return true
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
        -- 🗳 6.388.0 — ONLY WHAT IS SELECTED. The rows he kept are not
        -- failures and are not skipped silently: they are counted and
        -- named in the answer, because "I left that one" and "it would
        -- not move" are opposite facts (6.196.1).
        local moving, _, keptSafe, keptCareful = M.selectedItems(plan.items, plan.keep)
        for _, it in ipairs(moving) do
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
        ar.moved.kept  = (ar.moved.kept or 0) + keptSafe + keptCareful
        ar.moved.last  = { name = plan.name, moved = #done, failed = #failed,
                           bytes = bytes, at = os.time(),
                           keptSafe = keptSafe, keptCareful = keptCareful,
                           touched = plan.touched }
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
        -- 🔎 THE ANSWER CARRIES WHAT WAS LEFT, counted apart: a row HE
        -- kept and a row kept FOR him are different facts, and a caller
        -- that only hears "moved 3" cannot tell either from "3 is all
        -- there was" (6.196.1).
        return true, { moved = #done, failed = #failed, bytes = bytes,
                       keptSafe = keptSafe, keptCareful = keptCareful }
    end

    -- ---- the analysis, in words ---------------------------------------
    -- 🔎 "the ultimate outcome is a solid analysis of what can be
    -- removed" — his words, so the Console carries the whole thing: one
    -- line per file, its verdict, WHY, its size, and whether it is
    -- selected. The picker is where he acts; this is where he reads.
    local MARK = { safe = "✅", careful = "⚠️" }
    local function describe(plan)
        local L = {}
        local moving, movBytes, keptSafe, keptCareful =
            M.selectedItems(plan.items, plan.keep)
        L[#L + 1] = "🗑 " .. plan.name .. " — " .. plan.count .. " item(s) found, "
                    .. #moving .. " selected (" .. M.prettySize(movBytes) .. ")"
        L[#L + 1] = plan.bundleId and ("   bundle : " .. plan.bundleId)
                    or "   bundle : ⚠️ this Mac would not say — every row below is a NAME guess"
        L[#L + 1] = "   NOTHING HAS MOVED. ⏎ on a row keeps it or selects it again."
        for i, it in ipairs(plan.items) do
            local keep = plan.keep[i] and true or false
            L[#L + 1] = "   " .. (keep and "[ keep ]" or "[ MOVE ]") .. " "
                        .. (MARK[it.verdict] or "⚠️") .. " " .. it.path
            L[#L + 1] = "            " .. tostring(it.verdict) .. " — " .. tostring(it.risk)
                        .. " · " .. M.prettySize(it.size)
                        .. (it.ownCapped and " · the count stopped at " .. ar.ownCap
                                           .. ", so it is a FLOOR" or "")
        end
        if plan.capped then
            L[#L + 1] = "   ⚠️ STOPPED AT " .. ar.maxRows .. " ROWS — there may be more"
        end
        if plan.running then
            L[#L + 1] = "   ⚠️ " .. plan.name .. " IS OPEN — quit it first; nothing will move"
        end
        if keptSafe + keptCareful > 0 then
            L[#L + 1] = "   kept   : " .. keptCareful .. " risky row(s) and " .. keptSafe
                        .. " safe row(s) are NOT selected"
        end
        if plan.careful > 0 then
            L[#L + 1] = "   ⚠️ " .. plan.careful .. " row(s) need reading before you say yes."
                        .. " They are NOT selected by default."
        end
        L[#L + 1] = "   ⏎ on “✅ Move the selected…” does it · _G.appRemoveGo()"
        return table.concat(L, "\n")
    end

    -- 🔁 6.388.0 — THE REVIEW IS THE PICKER. With a plan in hand every
    -- file is a row he can press ⏎ on, so "leave that one" is one
    -- keystroke rather than a settings line. Without one it is the app
    -- list, exactly as before.
    local function reviewRows()
        local plan = ar.plan
        local rows = {}
        local moving, movBytes = M.selectedItems(plan.items, plan.keep)
        local can, why = M.goVerdict(plan)
        rows[#rows + 1] = {
            text    = can and ("✅ Move “" .. tostring(plan.name) .. "” — the "
                               .. #moving .. " selected row(s), "
                               .. M.prettySize(movBytes) .. " — to the Trash")
                        or ("🚫 " .. tostring(why)),
            subText = can and ("Nothing is erased. Finder → Trash → Put Back undoes it."
                               .. (plan.careful > 0 and ("  ⚠️ " .. plan.careful
                                   .. " risky row(s) found — read them first") or ""))
                        or "⏎ a row below to select it, or go back",
            go      = can and true or false,
        }
        rows[#rows + 1] = { text = "◂ Back to the app list",
                            subText = "Forget this listing — nothing moves", back = true }
        rows[#rows + 1] = { text = "☑ Keep everything (select nothing)",
                            subText = "Then pick the rows you DO want moved", bulk = "all" }
        rows[#rows + 1] = { text = "☐ Select everything (keep nothing)",
                            subText = "⚠️ including the rows that may hold your own files",
                            bulk = "none" }
        rows[#rows + 1] = { text = "↺ Back to what this tool suggests",
                            subText = "Safe rows selected, risky rows kept", bulk = "default" }
        for i, it in ipairs(plan.items) do
            local keep = plan.keep[i] and true or false
            rows[#rows + 1] = {
                text    = (keep and "[ keep ] " or "[ MOVE ] ")
                          .. (MARK[it.verdict] or "⚠️") .. " " .. it.path,
                subText = tostring(it.verdict) .. " — " .. tostring(it.risk)
                          .. " · " .. M.prettySize(it.size)
                          .. "   ·   ⏎ " .. (keep and "selects it" or "keeps it"),
                toggle  = i,
            }
        end
        return rows
    end

    local function appRows()
        local rows = {}
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
        return rows
    end

    -- 📏 hs.chooser DROPS the selection on every :choices() (6.227.0),
    -- and this list is rebuilt on EVERY toggle — so without putting the
    -- row back he is bounced to the top each time and "a very iterative
    -- process" is a list he cannot walk. clipboard_history has done this
    -- arithmetic since 6.227.0; ask IT when it is loaded (one function,
    -- two callers — 6.231.0) and fall back to our own copy, which the
    -- gate joins to it so the two cannot drift.
    local function rowAfter(want, total)
        if _G.service and _G.service.has and _G.service.has("clipboard.rowAfterRebuild") then
            local r = _G.service.call("clipboard.rowAfterRebuild", want, total)
            if r ~= nil then return r end
        end
        return M.rowAfterRebuild(want, total)
    end

    function ar.show(wantRow)
        local rows = ar.plan and reviewRows() or appRows()
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
            -- 🔁 the iterative rows: each one re-opens the review with
            -- the highlight where he left it.
            if row.toggle then
                local ok, what = ar.toggle(row.toggle)
                if ok then ar.show(row.toggle + 5) end
                return
            end
            if row.bulk then
                if row.bulk == "all"  then ar.keepAll()
                elseif row.bulk == "none" then ar.keepNone()
                else ar.keepDefaults() end
                ar.show(1)
                return
            end
            if row.back then
                ar.plan = nil
                ar.show()
                return
            end
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
                local moving = M.selectedItems(plan.items, plan.keep)
                hs.alert.show("🗑 " .. plan.name .. " — " .. plan.count .. " item(s) found, "
                              .. #moving .. " selected"
                              .. (plan.careful > 0 and ("\n⚠️ " .. plan.careful
                                  .. " need reading — they are NOT selected") or "")
                              .. "\nNOTHING HAS MOVED. Read the list, press ⏎ on a row"
                              .. " to keep or select it.", 7)
                -- 🔁 straight into the review, so the list he was just
                -- told to read is the thing in front of him
                ar.show(1)
            end
        end)
        if not ch then return false, "macOS would not open the picker" end
        ch:choices(rows)
        ch:placeholderText(ar.plan
            and ("Review " .. ar.plan.name .. " — ⏎ a row to keep or select it")
            or "Remove an app — to the Trash, never erased")
        _G.choosers.appRemove = ch
        -- put the highlight back where he was (6.227.0)
        if wantRow then
            local r = rowAfter(wantRow, #rows)
            ar.lastRow = r
            if r then pcall(function() ch:selectedRow(r) end) end
        end
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
    -- 🔁 the same decisions from the Console, for a long list
    _G.appRemoveKeep = function(i)
        local ok, why = ar.toggle(i)
        print("🗑 " .. (ok and ("row " .. tostring(i) .. " — " .. tostring(why))
                        or tostring(why)))
        if ok then print(describe(ar.plan)) end
        return ok, why
    end
    _G.appRemoveKeepAll   = function() local ok = ar.keepAll()
        if ok then print(describe(ar.plan)) end return ok end
    _G.appRemoveKeepNone  = function() local ok = ar.keepNone()
        if ok then print(describe(ar.plan)) end return ok end
    _G.appRemoveSuggested = function() local ok = ar.keepDefaults()
        if ok then print(describe(ar.plan)) end return ok end

    _G.appRemoveGo = function()
        local ok, res = ar.go()
        if not ok then print("🗑 " .. tostring(res)) ; return false, res end
        print("🗑 Moved " .. res.moved .. " item(s), " .. M.prettySize(res.bytes)
              .. " to the Trash" .. (res.failed > 0 and (" · ⚠️ " .. res.failed .. " refused") or "")
              .. ((res.kept or 0) > 0 and ("\n   " .. res.kept .. " row(s) were KEPT — they are "
                  .. "still where they were") or "")
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
            -- 🗳 6.388.0 — THE SELECTION, AND WHOSE IT IS. "he kept that
            -- row" and "this tool never offered it" are different facts
            -- and a single number would read as the tool's decision
            -- (6.378.0 — a first reading is not a change).
            local moving, movBytes, keptSafe, keptCareful =
                M.selectedItems(ar.plan.items, ar.plan.keep)
            L[#L + 1] = "   select : " .. #moving .. " of " .. ar.plan.count
                        .. " selected to move (" .. M.prettySize(movBytes) .. ") · "
                        .. keptCareful .. " risky and " .. keptSafe .. " safe row(s) kept"
            L[#L + 1] = "   ↳ " .. (ar.plan.touched > 0
                        and (ar.plan.touched .. " change(s) of YOURS — the rest is what this "
                             .. "tool suggested")
                        or "untouched — this is what this tool suggests, not what you chose")
            if ar.plan.careful > 0 then
                L[#L + 1] = "   ⚠️ " .. ar.plan.careful .. " row(s) could be damaging and are "
                            .. "NOT selected by default:"
                for _, it in ipairs(ar.plan.items) do
                    if it.verdict ~= "safe" then
                        L[#L + 1] = "        " .. it.path
                        L[#L + 1] = "          ↳ " .. tostring(it.risk)
                    end
                end
            else
                L[#L + 1] = "   ✅ every row is SAFE — a cache, a plist or the app itself; "
                            .. "nothing here holds your own files"
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
