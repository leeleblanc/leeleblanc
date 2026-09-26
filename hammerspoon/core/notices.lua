-- hs-lint: allow service-call-unchecked — the only call in this file is
-- service.call("focus.engaged"), and nil is a MEANINGFUL answer there:
-- no focus module loaded means nothing is holding notices back, which is
-- exactly the conclusion we want. No outcome is reported to the user that
-- could be wrong, so has() would add a branch and change no behaviour.
-- =====================================================================
-- CORE: NOTICES — nothing fails silently, and you are not made to watch
-- =====================================================================
-- One ledger every failure records into, and a small set of surfaces
-- that read from it. The requirement this exists for, in your words:
--
--   "All configurations and additions must not fail silently. Please
--    develop a way to let me know. I will not always have the console
--    open. I need to go there only when we fail."
--
-- ---------------------------------------------------------------------
-- WHY A LEDGER RATHER THAN AN ALERT AT EACH SITE
-- ---------------------------------------------------------------------
-- Every module could call hs.notify itself. Twenty-five modules doing
-- that gives twenty-five slightly different behaviours, twenty-five
-- chances to forget, and no single place that knows whether you have
-- already been told. The ledger inverts it: modules RECORD, and this
-- file decides whether, how and when to show anything. Add a surface
-- later and every existing failure flows into it for free.
--
-- ---------------------------------------------------------------------
-- 🚨 A NOTICE SYSTEM THAT CAN CRASH IS WORSE THAN NONE
-- ---------------------------------------------------------------------
-- This runs on the boot path, before the modules, and it is the thing
-- that reports other failures. If it throws it takes the config with it
-- AND removes the mechanism that would have told you why. So: no
-- module-level work beyond building tables, every macOS call is pcall'd,
-- the queue is bounded, and every public function tolerates nil.
--
-- ---------------------------------------------------------------------
-- ⚠️ DO NOT DISTURB, AND WHAT CAN HONESTLY BE KNOWN ABOUT IT
-- ---------------------------------------------------------------------
-- macOS gives no public API for "is Focus on right now". So this does
-- not pretend to know in general. It knows TWO things reliably:
--   1. Whether THIS config turned Focus on — Focus Mode publishes
--      focus.engaged, which is exact, because we did it.
--   2. Whether the Do Not Disturb assertions file says so — present on
--      Monterey and later. Read defensively; absence proves nothing.
-- When neither is conclusive it assumes NOT suppressed and shows the
-- notice. That direction is deliberate: a notice shown during Focus is
-- a mild annoyance, a notice silently swallowed is the bug this file
-- exists to prevent.
--
-- The reason this matters at all is uncomfortable: Focus Mode turns Do
-- Not Disturb ON during meetings, and macOS then swallows notifications
-- WITHOUT REFUSING THEM — so a hs.notify that "succeeded" can still have
-- shown you nothing. A failure during a meeting could vanish entirely.
--
-- 6.58.0 — WRAPPED TO MATCH THE OTHER FOUR core/ FILES. Every one of
-- them is `return function(core) ... end`, called as chunk()(coreTable)
-- by init.lua. This file was written as a bare `return notices` table
-- instead, called as a bare chunk() with no argument — it happened to
-- work at runtime (nothing here reads `core`), but it broke the one
-- invariant tools/hs-install.sh actually verifies: that every core/
-- file IS an initialiser in the shape init.lua expects to call. The
-- installer refused the install and rolled back rather than leave a
-- half-matching file in place — exactly what it exists to do.
return function(core)
    local notices = {}

    -- ✏️ EDIT HERE -----------------------------------------------------------
    notices.maxLedger    = 200    -- entries kept; oldest dropped
    notices.maxQueue     = 20     -- notices held while Focus is on
    notices.holdRecheck  = 30     -- seconds between "has Focus ended yet?"
    notices.bootSignal   = true   -- 🆗 brief "config loaded" flash on a clean boot
    notices.bootAlert    = true   -- 🚨 alert at boot if a module failed to load
    notices.signalSecs   = 0.9    -- how long the clean-boot flash stays
    -- ------------------------------------------------------------------------

    notices.ledger  = {}     -- every recorded event, newest last
    notices.queue   = {}     -- notices waiting for Focus to end
    notices.timer   = nil    -- HELD: an unreferenced hs.timer is collected
    notices.shown   = {}     -- de-dupe: key -> last shown time

    local function now()
        local ok, t = pcall(hs.timer.secondsSinceEpoch)
        return ok and t or os.time()
    end

    -- ---- the ledger --------------------------------------------------------
    -- kind:   "load" | "runtime" | "hook" | "task" | "info"
    -- source: which module or file
    -- msg:    what went wrong, in a sentence
    function notices.record(kind, source, msg)
        local e = {
            at     = now(),
            clock  = os.date("%H:%M:%S"),
            kind   = tostring(kind or "runtime"),
            source = tostring(source or "?"),
            msg    = tostring(msg or ""),
        }
        local L = notices.ledger
        L[#L + 1] = e
        while #L > notices.maxLedger do table.remove(L, 1) end
        -- Mirrored into the diagnostics trail so ⇪⇧D shows it too, rather
        -- than being a second place you have to know to look.
        pcall(function()
            if _G.diag and _G.diag.err and e.kind ~= "info" then
                _G.diag.err(e.source .. ": " .. e.msg)
            end
        end)
        return e
    end

    function notices.count(kind)
        local n = 0
        for _, e in ipairs(notices.ledger) do
            if not kind or e.kind == kind then n = n + 1 end
        end
        return n
    end

    -- ---- is a notification going to be swallowed? --------------------------
    function notices.focusIsOn()
        -- 1. Our own Focus Mode. Exact, because this config set it.
        local ok, engaged = pcall(function()
            return _G.service and _G.service.call("focus.engaged")
        end)
        if ok and engaged == true then return true, "this config's Focus Mode" end

        -- 2. The DND assertions file. Present since Monterey; its ABSENCE
        -- proves nothing, so absence is never read as "Focus is off".
        local okFile, on = pcall(function()
            local p = (os.getenv("HOME") or "")
                      .. "/Library/DoNotDisturb/DB/Assertions.json"
            local f = io.open(p, "r")
            if not f then return nil end
            local body = f:read("*a") or ""
            f:close()
            if body:find("storeAssertionRecords", 1, true)
               and body:find("assertionDetails", 1, true) then
                return true
            end
            return false
        end)
        if okFile and on == true then return true, "macOS Do Not Disturb" end

        return false, nil
    end

    -- ---- showing something -------------------------------------------------
    -- 🚨 hs.alert IS THE FALLBACK, AND IT IS NOT OPTIONAL. hs.notify goes to
    -- Notification Centre, which Focus silences and which can also be turned
    -- off for Hammerspoon entirely in System Settings without telling us.
    -- hs.alert draws straight onto the screen and obeys neither, so it is
    -- what guarantees the message is seen.
    local function present(title, text, seconds)
        local sent = false
        pcall(function()
            local n = hs.notify.new({
                title = title, informativeText = text, withdrawAfter = 0,
            })
            if n then n:send() ; sent = true end
        end)
        pcall(function()
            hs.alert.show("⚠️ " .. title .. "\n" .. text, seconds or 5)
        end)
        return sent
    end

    -- Public: tell the user, honouring Focus.
    -- key is optional; when given, the same key is not repeated within
    -- `every` seconds. A module failing in a repeating timer would otherwise
    -- paint the screen.
    function notices.tell(title, text, opts)
        opts = opts or {}
        local key = opts.key
        if key then
            local last = notices.shown[key]
            if last and (now() - last) < (opts.every or 3600) then return false end
        end

        local suppressed, why = notices.focusIsOn()
        if suppressed and not opts.force then
            local q = notices.queue
            -- Bounded, and the OLDEST is dropped rather than the newest: if
            -- twenty things broke during a meeting, the recent ones are the
            -- ones still true when it ends.
            q[#q + 1] = { title = title, text = text, key = key, at = now() }
            while #q > notices.maxQueue do table.remove(q, 1) end
            print("🔕 Held until Focus ends (" .. tostring(why) .. "): " .. title)
            notices.startHoldTimer()
            return false
        end

        if key then notices.shown[key] = now() end
        present(title, text, opts.seconds)
        return true
    end

    -- ---- 7d: hold while Focus is on, deliver when it ends -------------------
    function notices.startHoldTimer()
        if notices.timer then return end
        local okT, t = pcall(hs.timer.doEvery, notices.holdRecheck, function()
            if #notices.queue == 0 then
                pcall(function() notices.timer:stop() end)
                notices.timer = nil
                return
            end
            local stillOn = notices.focusIsOn()
            if stillOn then return end
            notices.flush()
        end)
        if okT and t then notices.timer = t end
    end

    function notices.flush()
        local q = notices.queue
        if #q == 0 then return 0 end
        local n = #q
        -- One combined notice rather than n separate ones. Coming out of a
        -- meeting to twelve stacked alerts is its own kind of failure.
        local first = q[1]
        local text = first.title .. " — " .. first.text
        if n > 1 then text = text .. "\n(+" .. (n - 1) .. " more, ⇪⇧D for all)" end
        notices.queue = {}
        for _, item in ipairs(q) do
            if item.key then notices.shown[item.key] = now() end
        end
        present("While you were in Focus", text, 8)
        pcall(function()
            if notices.timer then notices.timer:stop() end
        end)
        notices.timer = nil
        return n
    end

    -- ---- 7e + 6: the one thing you see at login ----------------------------
    -- A clean boot gets a brief flash and nothing else. A boot with a failed
    -- module gets an alert naming it. You are never asked to check anything;
    -- silence means it worked.
    function notices.bootFinished(loaded, failed, failures)
        failed = tonumber(failed) or 0
        if failed > 0 then
            local names = {}
            for _, f in ipairs(failures or {}) do
                names[#names + 1] = tostring(f)
                notices.record("load", tostring(f), "failed to load at boot")
            end
            if notices.bootAlert then
                local list = #names > 0 and table.concat(names, ", ") or "see ⇪⇧D"
                -- force = true: this one is shown even during Focus. A tool
                -- that did not load is wrong for the whole session, and
                -- holding it for a meeting to end is holding it too long.
                notices.tell("Hammerspoon: " .. failed .. " module"
                             .. (failed == 1 and "" or "s") .. " did not load",
                             list .. "\n⇪⇧D for the report",
                             { seconds = 8, force = true })
            end
            return false
        end

        if notices.bootSignal then
            -- The FadeLogo idea, natively and without a Spoon: a short,
            -- unmissable-but-brief "it loaded" so a silent Mac is not
            -- ambiguous between "fine" and "did not start".
            pcall(function()
                hs.alert.show("🔨 Hammerspoon ready · " .. tostring(loaded or 0)
                              .. " tools", notices.signalSecs)
            end)
        end
        return true
    end

    -- ---- 6.215.0 — 🔔 THE DEGRADE DOOR ---------------------------------------
    -- LL, 6.214.0: "I also must have anything here that breaks to throw an
    -- error so I see it, know about it, and can fix it with you." IT
    -- DEGRADES, IT NEVER BREAKS (6.177.0) says a missing folder, binary
    -- or module costs one feature and never the config — this says WHERE
    -- that degraded state goes. Before this door it went to a `return
    -- false, why` and, on a good day, a print — a line he finds a week
    -- later, if he opens the Console at all. One call now does all three
    -- at the moment it happens: an hs.alert naming the TOOL and the CAUSE
    -- (hs.alert draws on the screen whatever Focus says — this is the one
    -- surface here that deliberately does not go through tell()), a ⚠️
    -- Console line, and a row in the ledger so ⇪⇧D, _G.noticesReport()
    -- and _G.degradeReport() all list it. It returns `false, why`, so a
    -- function that already ends in `return false, why` takes the door
    -- by writing `return core.degrade("Tool", why)` and nothing else
    -- changes. P2 still holds: the same tool + cause alerts once per
    -- `degradeEvery`, and every call still counts and still prints, so
    -- a degrade inside a repeating timer is seen once and counted forty
    -- times, never painted forty times. P4 too: nil-tolerant, every
    -- macOS call pcall'd, the tool table bounded.
    -- =================================================================
    -- 🔕 6.295.0 — LOUD BY DEFAULT, QUIET ONLY WHERE HE SAID SO
    -- =================================================================
    -- LL: "Ensure we have visible warnings on-screen for anything that
    -- writes or gathers information like Hamsidian or Asana tools or
    -- backups. Essentially anything that affects my productivity.
    -- Another example for items I do not care which only report in the
    -- console that a failure occurred, would be Music Player. Those
    -- items only need to post messages in the console."
    --
    -- 🔑 THE TIER BELONGS TO THE TOOL, NOT THE CALL SITE. `opts.alert =
    -- false` has existed here since the door was built and nothing has
    -- ever used it, which is the right outcome: music_player takes this
    -- door from fourteen places, and fourteen call sites each deciding
    -- how loud to be is exactly how one of them comes to be silent when
    -- it should not (6.278.0, where six exits each printed their own
    -- sentence and one printed nothing). One list decides.
    --
    -- 🚨 AND IT FAILS LOUD. A tool nobody has classified ALERTS. The
    -- damage from getting this wrong is asymmetric — a needless alert
    -- is an annoyance, a swallowed one is the failure he asked for
    -- 6.278.0 to stop — so the quiet list is an allowlist that has to
    -- be earned, never a guess at what matters (6.276.0: fail closed).
    -- Everything he named as productivity is already loud and stays so
    -- without appearing anywhere below.
    --
    -- 📓 QUIET IS ABOUT THE ALERT AND NOTHING ELSE. The ⚠️ Console line,
    -- the ledger row, the CSV and therefore `_G.todayReport()` all get
    -- every degrade regardless — the 4 PM double-check he asked for in
    -- 6.279.0 must not have a hole in it named "music".
    --
    -- 🔤 MATCHED AT A BOUNDARY, which is 6.236.0's rule for the fourth
    -- time: one entry, "Music player", covers both "Music player" and
    -- "Music player media keys" without also covering a future "Music
    -- playerX". Exact, or the entry followed by a space.
    --
    -- 📏 COST, NAMED: a NEW tool that degrades noisily is loud until it
    -- is named here. That is the direction to be wrong in, and the
    -- door is a Console line rather than a release —
    -- `_G.degradeQuiet("Some tool")` / `_G.degradeLoud("Some tool")`.
    notices.quietTools = { "Music player" }
    notices.quietCount = 0       -- degrades that went to the Console alone

    -- PURE. Answers whether this tool's degrades alert, and WHY, so the
    -- report can say which rule decided rather than printing a verdict
    -- with no reasoning behind it.
    function notices.degradeVoice(tool, quiet)
        tool = tostring(tool or "")
        local folded = tool:lower()
        for _, q in ipairs(quiet or {}) do
            local e = tostring(q or ""):lower()
            if e ~= "" and (folded == e or folded:sub(1, #e + 1) == e .. " ") then
                return "console", "\"" .. q .. "\" is on the quiet list"
            end
        end
        return "alert", "not on the quiet list — loud is the default"
    end

    function _G.degradeQuiet(tool)
        tool = tostring(tool or "")
        if tool == "" then return false, "name a tool" end
        if notices.degradeVoice(tool, notices.quietTools) == "console" then
            return false, tool .. " is already quiet"
        end
        notices.quietTools[#notices.quietTools + 1] = tool
        print("🔕 " .. tool .. " degrades go to the Console only now "
              .. "(the log and _G.todayReport() still get them) — "
              .. "_G.degradeLoud(\"" .. tool .. "\") undoes it")
        return true
    end

    function _G.degradeLoud(tool)
        tool = tostring(tool or "")
        local hit
        for i = #notices.quietTools, 1, -1 do
            if notices.quietTools[i]:lower() == tool:lower() then
                table.remove(notices.quietTools, i) ; hit = true
            end
        end
        print(hit and ("🔔 " .. tool .. " alerts on screen again")
                   or ("🔔 " .. tool .. " was not on the quiet list — it already alerts"))
        return hit == true
    end

    notices.degradeEvery = 600   -- the same tool + cause alerts again after this many seconds
    notices.degradeMax   = 60    -- tools remembered; the oldest is dropped past it
    notices.degradeCauses = 8    -- causes remembered per tool for the alert gate
    notices.degrades     = {}    -- tool -> { n, first, last, why, clock, alerts, seen = { cause -> at } }
    notices.degradeOrder = {}    -- tools, oldest first
    notices.degradeTotal = 0

    -- =================================================================
    -- 📓 6.279.0 — THE FAILURE LOG: WHAT BROKE TODAY, AFTER A RELOAD
    -- =================================================================
    -- LL: "Can you also create an error message log for any of my tools
    -- that fail? I can check this log at 4pm for a double verification
    -- that anything I was using today that should capture information
    -- worked."
    --
    -- 🚨 THE LEDGER ABOVE IS MEMORY ONLY. `notices.degrades` is a Lua
    -- table: every reload empties it, and this config reloads whenever a
    -- file is saved. So "what failed today" was only ever answerable for
    -- as long as Hammerspoon had been running — which is the opposite of
    -- what a 4 PM check needs, and it is also exactly when a reload is
    -- most likely (something broke, so something got edited).
    --
    -- 📎 APPEND-ONLY, and that is a rule rather than a convenience: an
    -- append cannot shrink a file, so there is no write-ledger row to
    -- keep and no rewrite that can lose yesterday while saving today.
    -- 6.179.0's boot_cost CSV is the same shape for the same reason.
    --
    -- 🔁 IT NEVER TAKES THE DOOR ITSELF. A logger that reported its own
    -- failure through core.degrade would call itself, for ever, on the
    -- first unwritable disk. It counts its failures and the report names
    -- them — that is the whole of its complaint.
    --
    -- ⏳ AND IT BUFFERS UNTIL IT KNOWS WHERE TO WRITE. This file loads
    -- before §0.1 exists (deliberately — it has to be able to report a
    -- module-load failure), so it is handed an EMPTY core table and
    -- cannot know logsDir. init.lua calls notices.logTo() once the path
    -- is real. Without the buffer every BOOT-TIME degrade would be
    -- missing from the log, and those are the ones worth having.
    notices.logPath   = nil
    notices.logQueue  = {}
    notices.logMax    = 200     -- pending rows held before the path is known
    notices.logWrote  = 0
    notices.logFails  = 0
    notices.logWhy    = nil

    -- ✏️ PURE — one CSV row. Commas, quotes and newlines all appear in a
    -- real "why" (a path, a shell error, macOS's own words), and a row
    -- the reader cannot parse vanishes in silence (6.179.0).
    function notices.logRow(tool, why, at)
        local function q(v)
            v = tostring(v or ""):gsub("\r", " "):gsub("\n", " ")
            return '"' .. v:gsub('"', '""') .. '"'
        end
        at = tonumber(at) or os.time()
        return table.concat({ q(os.date("%Y-%m-%d", at)), q(os.date("%H:%M:%S", at)),
                              tostring(at), q(tool), q(why) }, ",")
    end

    local function appendRow(row)
        local f, err = io.open(notices.logPath, "a")
        if not f then
            notices.logFails = notices.logFails + 1
            notices.logWhy   = tostring(err or "could not open the log")
            return false
        end
        local okW = pcall(function() f:write(row .. "\n") end)
        pcall(function() f:close() end)
        if okW then notices.logWrote = notices.logWrote + 1
        else notices.logFails = notices.logFails + 1
             notices.logWhy = "the write itself failed" end
        return okW
    end

    function notices.logDegrade(tool, why, at)
        local row = notices.logRow(tool, why, at)
        if not notices.logPath then
            local q = notices.logQueue
            -- bounded, NEWEST kept: if a boot degrades two hundred times
            -- the recent ones are the ones still true when it settles
            q[#q + 1] = row
            while #q > notices.logMax do table.remove(q, 1) end
            return false
        end
        return appendRow(row)
    end

    function notices.logTo(path)
        if type(path) ~= "string" or path == "" then return false end
        notices.logPath = path
        local q = notices.logQueue
        notices.logQueue = {}
        for _, row in ipairs(q) do appendRow(row) end
        return true
    end

    -- 📓 `_G.todayReport()` — LL's 4 PM double-check, in one command.
    -- 🔎 THREE STATES, NEVER TWO (6.196.1), and here it is the whole
    -- point: "no log to read" must NOT print as "nothing failed today".
    -- The second is the most reassuring sentence this config can say and
    -- it would be a lie on exactly the day the disk is full.
    function _G.todayReport(day)
        day = day or os.date("%Y-%m-%d")
        local L = { "📓 WHAT FAILED " .. (day == os.date("%Y-%m-%d") and "TODAY" or "ON " .. day)
                    .. " — " .. day }
        -- 🚨 EVERY EXIT CARRIES THE WRITE FAILURES. The first version
        -- returned early on an unreadable log and skipped them — in the
        -- one situation where failing writes are all but guaranteed,
        -- which is the same disk. The suite caught it, which is what a
        -- check on an instrument is for.
        local function finish()
            if notices.logFails > 0 then
                L[#L + 1] = "   ⚠️ " .. notices.logFails .. " row(s) could not be written this"
                L[#L + 1] = "      session — " .. tostring(notices.logWhy)
                L[#L + 1] = "      so this report may be missing failures it never saw."
            end
            L[#L + 1] = "   wrote  : " .. notices.logWrote .. " row(s) this session"
            local out = table.concat(L, "\n")
            print(out)
            return out
        end
        if not notices.logPath then
            L[#L + 1] = "   ⚠️ no log file yet — notices.logTo() has not been called."
            L[#L + 1] = "      This is NOT 'nothing failed'. " .. #notices.logQueue
                        .. " row(s) are waiting in memory."
            return finish()
        end
        L[#L + 1] = "   log    : " .. notices.logPath
        local f = io.open(notices.logPath, "r")
        if not f then
            L[#L + 1] = "   ⚠️ COULD NOT READ IT — so this report cannot say whether"
            L[#L + 1] = "      anything failed today. Treat it as unknown, not as clear."
            return finish()
        end
        -- the tail only: this file is uncapped by design (6.179.0)
        local size = f:seek("end")
        local want = notices.logTail or 64 * 1024
        f:seek("set", math.max(0, size - want))
        local text = f:read("a") or ""
        f:close()
        local tools, order, n = {}, {}, 0
        for line in text:gmatch("[^\n]+") do
            local d, clock, _, rest = line:match('^"([^"]*)","([^"]*)",(%d+),(.*)$')
            if d == day and rest then
                local tool, why = rest:match('^"(.-)",?"?(.*)"?$')
                tool = (tool or "?"):gsub('""', '"')
                why  = (why  or ""):gsub('^"', ""):gsub('"$', ""):gsub('""', '"')
                local e = tools[tool]
                if not e then e = { n = 0, first = clock, causes = {}, order = {} }
                             tools[tool] = e; order[#order + 1] = tool end
                e.n, e.last, n = e.n + 1, clock, n + 1
                if not e.causes[why] then
                    e.causes[why] = 0; e.order[#e.order + 1] = why
                end
                e.causes[why] = e.causes[why] + 1
            end
        end
        if n == 0 then
            L[#L + 1] = "   ✅ nothing failed " .. (day == os.date("%Y-%m-%d") and "today" or "that day")
                        .. " — the log was read and holds no row for " .. day .. "."
        else
            L[#L + 1] = "   ⚠️ " .. n .. " failure(s) across " .. #order .. " tool(s):"
            for _, tool in ipairs(order) do
                local e = tools[tool]
                L[#L + 1] = "      " .. tool .. " ×" .. e.n
                            .. "  (" .. e.first .. (e.n > 1 and (" → " .. e.last) or "") .. ")"
                for _, why in ipairs(e.order) do
                    L[#L + 1] = "         ↳ " .. why
                                .. (e.causes[why] > 1 and ("  ×" .. e.causes[why]) or "")
                end
            end
        end
        return finish()
    end

    function notices.degrade(tool, why, opts)
        opts = type(opts) == "table" and opts or {}
        tool = tostring(tool or "?")
        why  = tostring(why or "no reason given")
        local t = now()
        local d = notices.degrades[tool]
        if not d then
            d = { n = 0, first = t, alerts = 0, seen = {}, seenOrder = {} }
            notices.degrades[tool] = d
            local O = notices.degradeOrder
            O[#O + 1] = tool
            while #O > notices.degradeMax do
                local old = table.remove(O, 1)
                notices.degrades[old] = nil
            end
        end
        d.n, d.last, d.why, d.clock = d.n + 1, t, why, os.date("%H:%M:%S")
        notices.degradeTotal = notices.degradeTotal + 1
        -- 📓 6.279.0 — AND IT OUTLIVES THE RELOAD (see below).
        notices.logDegrade(tool, why)
        -- 1. the ledger — ⇪⇧D, _G.noticesReport(), the storm report's notices section
        notices.record("degrade", tool, why)
        -- 2. the Console line, every time
        pcall(print, "⚠️ " .. tool .. ": " .. why)
        -- 3. the alert, at the moment — once per tool + cause per degradeEvery,
        --    and only for a tool the quiet list has not spoken for (6.295.0).
        local voice = notices.degradeVoice(tool, notices.quietTools)
        if voice == "console" then
            d.quiet = (d.quiet or 0) + 1
            notices.quietCount = notices.quietCount + 1
        end
        local last = d.seen[why]
        if voice == "alert" and opts.alert ~= false
           and (not last or (t - last) >= notices.degradeEvery) then
            if not last then
                local S = d.seenOrder
                S[#S + 1] = why
                while #S > notices.degradeCauses do d.seen[table.remove(S, 1)] = nil end
            end
            d.seen[why] = t
            local shown = pcall(function()
                hs.alert.show("⚠️ " .. tool .. " — " .. why, opts.seconds or 6)
            end)
            if shown then d.alerts = d.alerts + 1 end
        end
        return false, why
    end
    _G.degrade = notices.degrade
    if type(core) == "table" then core.degrade = notices.degrade end

    function _G.degradeReport()
        local tools = #notices.degradeOrder
        local L = { string.format("🔔 DEGRADED — %d time(s) across %d tool(s) this session · "
                                  .. "the same cause alerts once per %d min",
                                  notices.degradeTotal, tools, math.floor(notices.degradeEvery / 60)) }
        if tools == 0 then
            L[#L + 1] = "   nothing has degraded this session — every tool that took the door had what it needed."
        else
            for _, tool in ipairs(notices.degradeOrder) do
                local d = notices.degrades[tool]
                if d then
                    -- 🔕 6.295.0 — A QUIET TOOL IS NOT A REFUSED ALERT.
                    -- This line has read "⚠️ never alerted — hs.alert
                    -- refused" whenever d.alerts was 0, which would now
                    -- be a false warning on every tool the quiet list
                    -- speaks for — a new rule breaking the instrument
                    -- built to watch it (6.269.0). Three states.
                    local tail = ""
                    if (d.quiet or 0) > 0 then
                        tail = "  (🔕 Console only — on the quiet list)"
                    elseif d.alerts == 0 then
                        tail = "  (⚠️ never alerted — hs.alert refused)"
                    end
                    L[#L + 1] = string.format("   %s  %-22s ×%-4d %s%s", d.clock or "--:--:--", tool, d.n, d.why, tail)
                end
            end
        end
        L[#L + 1] = "   the door : core.degrade(tool, why) → alert · ⚠️ Console line · this list · ⇪⇧D"
        -- 🔕 6.295.0 — and WHICH tools are quiet, always, because a policy
        -- you cannot read is a policy you cannot correct. Three states:
        -- nothing quiet · quiet and nothing has used it · quiet and used.
        if #notices.quietTools == 0 then
            L[#L + 1] = "   quiet   : none — every tool alerts on screen"
        else
            L[#L + 1] = string.format(
                "   quiet   : %d tool(s) go to the Console alone — %s%s",
                #notices.quietTools, table.concat(notices.quietTools, " · "),
                notices.quietCount == 0
                    and " (none has degraded this session)"
                    or (" · " .. notices.quietCount .. " degrade(s) took that route"))
            L[#L + 1] = "   ↳ the LOG still gets them: _G.todayReport() and ⇪⇧D are unchanged"
            L[#L + 1] = "   ↳ _G.degradeLoud(\"Music player\") puts one back on screen"
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    -- ---- the report --------------------------------------------------------
    function _G.noticesReport()
        local L = { string.format("🔔 NOTICES — %d recorded", #notices.ledger) }
        local focusOn, why = notices.focusIsOn()
        L[#L + 1] = "   Focus right now : " .. (focusOn and ("ON (" .. tostring(why) .. ")")
                                                or "off")
        L[#L + 1] = "   held for later  : " .. #notices.queue
        if #notices.ledger == 0 then
            L[#L + 1] = "   nothing has failed this session."
        else
            for _, e in ipairs(notices.ledger) do
                L[#L + 1] = string.format("   %s  %-8s %-18s %s",
                            e.clock, e.kind, e.source, e.msg)
            end
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    -- ---- 🔔 the channel every other tool reports through (6.274.0) ---------
    -- LL, 2026-09-20, reporting "hyper+4 is intermittently working" and
    -- pasting eight hours of Console with THREE of these in it:
    --
    --     ⚠️ an alert could not draw — another app's popup was
    --        mid-transition. Sweeping the half-drawn frame and retrying…
    --
    -- 🚨 A REFUSED ALERT IS THE FAILURE OF THE THING THAT REPORTS
    -- FAILURES, and it was the one break this config never counted. Every
    -- rule here — 🔔 A BREAK IS SEEN NEVER ONLY LOGGED, the degrade door,
    -- every "it says so rather than failing silently" — ends in an
    -- hs.alert. When AppKit refuses one, the tool did its job, the message
    -- was written, and he saw nothing. Worse, the line above does not say
    -- WHAT the alert said, so an alert explaining why ⇪4 captured nothing
    -- is indistinguishable from one about the weather.
    --
    -- init.lua's wrapper counts the four outcomes now (it has owned the
    -- retry since 6.88.0 and must stay there — it wraps before any module
    -- loads); the words and the report live here, where the degrade door
    -- already lives.

    -- ✂️ PURE. hs.alert takes a string OR a table of styled text, so this
    -- never assumes either, and it flattens newlines because a report line
    -- is one line. nil-tolerant by design: it is called from inside a
    -- failure path and must not add a second one.
    function _G.alertWords(v, max)
        local s
        if type(v) == "table" then s = tostring(v.text or v[1] or "styled text")
        else s = tostring(v == nil and "(no text)" or v) end
        s = s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
        if s == "" then s = "(empty)" end
        max = tonumber(max) or 70
        if utf8 and utf8.len and (utf8.len(s) or 0) > max then
            local cut = utf8.offset(s, max) or (max + 1)
            s = s:sub(1, cut - 1) .. "…"
        elseif not (utf8 and utf8.len) and #s > max then
            s = s:sub(1, max - 1) .. "…"
        end
        return s
    end

    -- 🔎 THREE STATES, NEVER TWO (6.196.1). "macOS has drawn every alert"
    -- and "one never reached the screen" are opposite facts, and a
    -- RECOVERED alert (drawn a moment later by the retry) is a third —
    -- he saw it, just late, which is not a lost message.
    function _G.alertReport()
        local a = _G.alertLate or {}
        local L = { "🔔 ALERTS — the channel every other tool reports through" }
        L[#L + 1] = "   asked     : " .. tostring(a.asked or 0) .. " this session"
        if (tonumber(a.refused) or 0) == 0 then
            L[#L + 1] = "   refused   : none — macOS drew every alert it was asked for"
        else
            L[#L + 1] = "   refused   : ⚠️ " .. tostring(a.refused)
                        .. " could not draw at the first attempt"
            L[#L + 1] = "   recovered : " .. tostring(a.recovered or 0)
                        .. " drew on the retry a moment later (you saw those, late)"
            L[#L + 1] = "   lost      : " .. tostring(a.lost or 0)
                        .. " never reached the screen at all"
            L[#L + 1] = "   ↳ last refused said: \"" .. tostring(a.last or "?") .. "\""
                        .. (a.lastAt and ("  at " .. tostring(a.lastAt)) or "")
            if (tonumber(a.lost) or 0) > 0 then
                L[#L + 1] = "   🚨 A LOST ALERT IS A TOOL THAT REPORTED A FAULT YOU NEVER SAW."
                L[#L + 1] = "      Read this beside _G.degradeReport() and _G.canvasShowReport()"
                L[#L + 1] = "      — the fault itself is recorded in one of those."
            end
        end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    _G.notices = notices
    return notices
end
