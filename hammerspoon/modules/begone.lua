-- =====================================================================
-- MODULE: BEGONE (type `begone`) — notification banners, dismissed
-- =====================================================================
-- LL: "Clear visible macOS notification banners via the begone keyword."
--
-- Type the word anywhere — mid-sentence in an email, in a chat box, in
-- a code editor — and every notification banner on screen closes at
-- once. The word never lands in your document: it fires through the
-- Text Expander's machinery, which removes the characters it took to
-- type exactly the way a snippet trigger disappears into its expansion.
--
-- WHY A TYPED WORD AND NOT A HOTKEY. Banners arrive precisely when you
-- are typing — that is what makes them maddening — so the dismissal
-- lives where your hands already are. No reaching for ⇪, no mouse trip
-- to hover each ✕. (It is in the ⇪⇧T chooser too, and _G.begone() runs
-- it from the Console.)
--
-- HOW THE CLOSING WORKS. Every banner on screen lives inside one
-- accessibility window owned by the NotificationCenter process, and
-- each banner carries a "Close" action — stacks carry "Clear All".
-- Performing those actions IS the dismissal, exactly as if the pointer
-- had hovered and clicked. System Events is asked politely, in FOUR
-- dialects, because Apple rearranges this furniture: Big Sur gave each
-- banner its own window, Monterey/Ventura kept the groups in a scroll
-- area, Sonoma nested them one group deeper — and macOS 26 moved them
-- again, which is why 6.99.0 added the fourth address: when no fixed
-- path answers, the ENTIRE CONTENTS of every NotificationCenter window
-- is walked and anything carrying a Clear All or Close action is
-- pressed, wherever Apple parked it. The pass repeats until nothing
-- more closes, because dismissing a stack reveals the banners under it.
-- When even the deep walk finds nothing actionable, the alert says so
-- and points at _G.begoneProbe() — the map needed for the NEXT address.
--
-- 🗂 THIS ALSO CLEARS NOTIFICATION CENTER'S HISTORY — the list behind
-- the clock — but ONLY while that list is open on screen. A closed
-- drawer has no UI elements to press; open it (click the clock), type
-- the word, watch it empty. The alert tells you exactly that when it
-- finds nothing else to do.
--
-- OFF THE MAIN THREAD. The script runs through /usr/bin/osascript as an
-- hs.task, not hs.osascript — the multi-pass sweep can take a second or
-- two, and blocking Hammerspoon's only thread for that long would stall
-- the very typing that triggered it.
--
-- NEEDS ACCESSIBILITY. The same permission the window tools use.
-- Without it, System Events answers with an error and this module says
-- so in an alert rather than pretending it worked.

local M = {
    name  = "Begone",
    order = 13.59,
    family = "time",        -- beside the Text Expander (13.58), whose
                          -- machinery fires the keyword
    cheatsheet = {
        title = "🔕 BEGONE (type it — banners vanish)",
        entries = {
            { "begone",  "Type it anywhere — every notification banner closes" },
            { "typed",   "The word deletes itself; nothing lands in your document" },
            { "history", "Open Notification Center (click the clock) first and it empties that too" },
            { "via ⇪⇧T", "It is in the snippet chooser too — pick it to run it" },
            { "console", "_G.begone() runs it · _G.begoneProbe() maps the banner window" },
            { "needs",   "Accessibility — the same permission the window tools use" },
        },
    },
}

function M.setup(core)
    local bg = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    bg.enabled   = true
    bg.word      = "begone"     -- the trigger. A word you never otherwise type.
    bg.passes    = 6            -- sweep repeats — a cleared stack reveals more
    bg.osascript = "/usr/bin/osascript"
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("begone", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("begone", m) end end

    bg.status   = "off"
    bg.lastRun  = nil     -- { at, closed, how } — for ⇪⇧D
    bg.running  = false

    -- ---- the sweep -------------------------------------------------------
    -- One script, four addresses, many passes. Each pass walks whatever
    -- container answered, performs the first Clear All or Close action on
    -- every element that has one, and goes around again while progress is
    -- being made — `delay` gives the dismiss animation time to land, and
    -- the pass cap keeps a misbehaving banner from looping forever.
    --
    -- 🚨 6.100.0 — MATCH THE DESCRIPTION TOO, NOT ONLY THE NAME. An AX
    -- action has BOTH: on the macOS builds where the old script worked,
    -- the action's NAME read "Close"/"Clear All"; on LL's macOS 26 the
    -- name is the AX-style identifier and "Close"/"Clear All" live in
    -- the action's DESCRIPTION — so `whose name is "Close"` matched
    -- nothing and the sweep closed zero while seeing plenty. Every
    -- action is now checked by name OR description; and as a third way
    -- in, an AXButton whose own description says Clear/Close (the
    -- hover-revealed ✕ the deep walk surfaces) is pressed directly.
    --
    -- The fourth address (6.99.0) is the one that survives Apple moving
    -- the furniture: `entire contents` flattens EVERY element in every
    -- NotificationCenter window, wherever the groups are nested this
    -- year, and the try blocks skip everything that has no Close/Clear
    -- All to press. Slower than a fixed path — which is why the fixed
    -- paths are still tried first, and why this runs off the main thread.
    --
    -- Returns TWO numbers on stdout, "closed seen": how many actions
    -- were performed, and how many elements were examined at all. The
    -- difference matters at zero — zero-closed with zero-seen means
    -- nothing was on screen; zero-closed with plenty seen means Apple
    -- moved the furniture AGAIN and the probe is the next step. One
    -- number cannot say which, and 6.92.0–6.98.0 proved a bare zero
    -- reads as "broken" from the outside.
    bg.script = [[
on run
	tell application "System Events"
		if not (exists application process "NotificationCenter") then return "0 0"
		tell application process "NotificationCenter"
			set closed to 0
			set seen to 0
			repeat @PASSES@ times
				set els to {}
				try
					set els to UI elements of UI element 1 of scroll area 1 of ¬
						group 1 of window "Notification Center"
				end try
				if (count of els) = 0 then
					try
						set els to UI elements of scroll area 1 of group 1 of ¬
							window "Notification Center"
					end try
				end if
				if (count of els) = 0 then
					try
						repeat with w in windows
							try
								set els to els & (entire contents of w)
							end try
						end repeat
					end try
				end if
				if (count of els) = 0 then
					try
						set els to windows
					end try
				end if
				set seen to seen + (count of els)
				set did to false
				repeat with el in els
					set pressed to false
					try
						repeat with a in (actions of el)
							set an to ""
							set ad to ""
							try
								set an to name of a as text
							end try
							try
								set ad to description of a as text
							end try
							if an is "Clear All" or ad is "Clear All" then
								perform a
								set pressed to true
								exit repeat
							end if
						end repeat
					end try
					if not pressed then
						try
							repeat with a in (actions of el)
								set an to ""
								set ad to ""
								try
									set an to name of a as text
								end try
								try
									set ad to description of a as text
								end try
								if an is "Close" or ad is "Close" then
									perform a
									set pressed to true
									exit repeat
								end if
							end repeat
						end try
					end if
					if not pressed then
						try
							if (role of el as text) is "AXButton" then
								set bd to ""
								try
									set bd to description of el as text
								end try
								if bd contains "Clear" or bd contains "Close" then
									perform action "AXPress" of el
									set pressed to true
								end if
							end if
						end try
					end if
					if pressed then
						set closed to closed + 1
						set did to true
					end if
				end repeat
				if not did then exit repeat
				delay 0.2
			end repeat
			return (closed as text) & " " & (seen as text)
		end tell
	end tell
end run
]]

    function bg.run(how)
        if bg.running then return false end
        local script = bg.script:gsub("@PASSES@", tostring(bg.passes))
        local okNew, t = pcall(function()
            return hs.task.new(bg.osascript, function(code, sout, serr)
                bg.running = false
                if code ~= 0 then
                    -- Almost always one thing: macOS has not let Hammerspoon
                    -- drive System Events. Say which door to knock on.
                    warn("osascript failed: " .. tostring(serr):sub(1, 120))
                    pcall(function()
                        hs.alert.show("🔕 Begone could not reach Notification "
                                      .. "Center — check Accessibility")
                    end)
                    if _G.notices then
                        _G.notices.record("begone", "sweep failed",
                                          tostring(serr):sub(1, 200))
                    end
                    return
                end
                -- "closed seen" — see the note above bg.script for why
                -- zero needs the second number to mean anything.
                local nums = {}
                for d in (sout or ""):gmatch("%d+") do nums[#nums + 1] = tonumber(d) end
                local n, seen = nums[1] or 0, nums[2] or 0
                bg.lastRun = { at = os.date("%H:%M:%S"), closed = n,
                               seen = seen, how = how }
                say(n .. " dismissed, " .. seen .. " examined ("
                    .. tostring(how) .. ")")
                local msg
                if n > 0 then
                    msg = "🔕 " .. n .. " begone"
                elseif seen == 0 then
                    msg = "🔕 nothing to dismiss — no banners on screen.\n"
                          .. "(To also empty Notification Center's history, "
                          .. "open it from the clock first, then run again.)"
                else
                    -- The furniture moved: things were THERE, none offered
                    -- a Close. Silence here would be the 6.66.0 sin.
                    msg = "🔕 saw " .. seen .. " element(s) but macOS offered "
                          .. "no Close action — run _G.begoneProbe() in the "
                          .. "Console and send me its output"
                    if _G.notices then
                        _G.notices.record("begone", "layout unrecognised",
                            seen .. " elements, no Close/Clear All action — "
                            .. "_G.begoneProbe() maps the new layout")
                    end
                end
                pcall(function() hs.alert.show(msg, n > 0 and 2 or 4) end)
            end, { "-e", script })
        end)
        if not (okNew and t) then
            warn("could not start osascript")
            return false
        end
        bg.task    = t          -- held: an unreferenced task is collected mid-run
        bg.running = true
        local started = false
        pcall(function() started = t:start() end)
        if not started then
            bg.running = false
            warn("osascript would not start")
            return false
        end
        return true
    end

    -- ---- the probe -------------------------------------------------------
    -- Prints role, description and available actions for everything in the
    -- banner window. Run it WHILE a banner is on screen; when a macOS
    -- update moves the containers, its output is the new address.
    bg.probeScript = [[
on run
	tell application "System Events"
		if not (exists application process "NotificationCenter") then ¬
			return "no NotificationCenter process is running"
		tell application process "NotificationCenter"
			set out to ""
			repeat with w in windows
				set out to out & "window" & linefeed
				try
					repeat with el in entire contents of w
						try
							set ln to "  " & (role of el as text)
							try
								set ln to ln & "  " & (description of el as text)
							end try
							try
								repeat with a in actions of el
									set ln to ln & "  [" & (name of a as text) & "]"
								end repeat
							end try
							set out to out & ln & linefeed
						end try
					end repeat
				end try
			end repeat
			if out is "" then return "no banner windows — nothing on screen right now"
			return out
		end tell
	end tell
end run
]]

    function bg.probe()
        local okNew, t = pcall(function()
            return hs.task.new(bg.osascript, function(code, sout, serr)
                if code ~= 0 then
                    print("🔕 begoneProbe failed — " .. tostring(serr))
                    return
                end
                print("🔕 The NotificationCenter window, as System Events sees it:")
                print(sout or "(nothing)")
            end, { "-e", bg.probeScript })
        end)
        if okNew and t then
            bg.probeTask = t
            pcall(function() t:start() end)
            print("🔕 probing — put a banner on screen first; result prints here")
            return true
        end
        return false
    end

    -- ---- wiring ----------------------------------------------------------
    -- The keyword goes through the expander so the typed characters are
    -- removed. Registered via the service registry rather than core.call:
    -- if the expander module is off on this profile there is no provider,
    -- and that is a fact to report, not a warning to spray.
    local registry  = _G.service and _G.service.registry or {}
    local addAction = registry["expander.addAction"]
    if bg.enabled and type(addAction) == "function" then
        local ok = pcall(addAction, bg.word,
                         function() bg.run("typed") end,
                         "Begone — dismiss every notification banner")
        bg.status = ok and ("ready — type " .. bg.word)
                        or "broken: the expander refused the keyword"
    elseif bg.enabled then
        bg.status = "keyword off — Text Expander not loaded; _G.begone() still works"
        if _G.notices then
            _G.notices.record("begone", "keyword unavailable",
                "the Text Expander module is off on this profile — "
                .. "_G.begone() still works from the Console")
        end
    else
        bg.status = "off (begone.enabled = false)"
    end

    core.provide("banners.begone", function() return bg.run("service") end)
    _G.begone      = function() return bg.run("console") end
    _G.begoneProbe = function() return bg.probe() end

    _G.begoneMod = bg
    M.bg     = bg
    M.config = bg
end

return M
