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

_G.notices = notices
return notices
