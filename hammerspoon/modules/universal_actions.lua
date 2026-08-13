-- =====================================================================
-- MODULE: UNIVERSAL ACTIONS (⇪⇧A) — do something with what is selected
-- =====================================================================
-- 🔑 WHY ⇪⇧A AND NOT ⇪U. "U for Universal" was the obvious pick and it
-- is taken: ⇪U is the update tracker, claimed in init.lua's migration
-- map rather than by a module, which is why it does not appear in any
-- module file you might grep. The collision was caught by the suite that
-- exists for exactly this ("NO MODULE CLAIMS A HYPER KEY THE MIGRATION
-- MAP ALSO CLAIMS" — the one that silently killed ⇪F, ⇪W and ⇪⇧R once).
-- ⇪A is Asana, so Actions moves one modifier up, which is also the
-- standing rule for anything added from here on.
-- Alfred's Universal Actions panel, done natively, for the actions this
-- config can actually perform: pick a file in Finder (or copy something),
-- press ⇪U, and choose what happens to it.
--
--        Reveal in Finder · Copy Path · Copy File · Open · Open With…
--        Open URL · Copy as Plain Text · Show as Large Type · Email…
--        Open Terminal Here · Get Info · Save as Snippet
--
-- 📌 THE LIST REORDERS ITSELF. The action you last used moves to the top,
-- then the one before that, and so on. After a week the three things you
-- actually do are the first three rows and this becomes ⇪U-⏎ rather than
-- ⇪U-read-choose. Persisted to the Logs folder, so it survives reloads
-- and is shared between both Macs like the rest of this config's state.
--
-- 🎯 IT ACTS ON WHAT MAKES SENSE, and says so. The panel reads the Finder
-- selection first and falls back to the clipboard; each row declares
-- which of those it needs, and rows that cannot apply right now are
-- hidden rather than offered and then failing. An action list that
-- offers "Open URL" when there is no URL is a list you stop trusting.
--
-- ⚠️ WHAT THIS IS NOT: it is not Alfred's list, and it cannot be. Alfred
-- owns its own actions, its own ordering and its own extensions; there is
-- no API to enumerate or invoke them. This is our list, performing our
-- actions, which is why it works with Alfred closed.

local M = {
    name  = "Universal Actions",
    order = 13.75,
    cheatsheet = {
        title = "⚡ UNIVERSAL ACTIONS (⇪⇧A — act on the selection)",
        entries = {
            { "⇪⇧A",  "Act on the Finder selection, or the clipboard" },
            { "⏎",    "Run the highlighted action" },
            { "auto", "The action you used last is at the top next time" },
            { "auto", "Actions that cannot apply right now are hidden" },
            { "last row", "Reset the running order back to the default" },
        },
    },
}

function M.setup(core)
    local ua = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    ua.enabled  = true
    ua.key      = "a"         -- on ⇪⇧, not ⇪ — see the 🔑 note in the header
    ua.rows     = 12
    ua.width    = 38          -- percent of screen width
    -- How long a cached Finder selection is trusted before it is re-read.
    -- The read is out of process and therefore asynchronous (see the 🚨 in
    -- ua.refresh), so "current" here means "as of the last refresh".
    ua.selectionSecs = 2
    ua.maxMRU   = 40          -- bounded: this list can only ever be as long
                              -- as the action table, but the FILE is written
                              -- by us and read back next boot, and an
                              -- unbounded read is how a corrupt file grows
    ua.store    = (core.logsDir or ".") .. "/universal_actions.json"
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("universalActions", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("universalActions", m) end end

    -- =====================================================================
    -- WHAT IS SELECTED
    -- =====================================================================
    -- Finder first, clipboard second. Both are wrapped: Finder scripting
    -- is off on a locked-down Mac and osascript simply fails there, which
    -- must degrade to "no files selected" rather than to an error dialog.
    local FINDER_SEL = [[
        tell application "Finder"
            set out to ""
            try
                repeat with f in (get selection)
                    set out to out & POSIX path of (f as alias) & linefeed
                end repeat
            end try
            return out
        end tell
    ]]

    -- 🚨 6.65.1 — OUT OF PROCESS, AND THIS IS NOT A STYLE PREFERENCE.
    --
    -- This used to call hs.osascript.applescript, which runs NSAppleScript
    -- INSIDE Hammerspoon and therefore sends Apple Events on Hammerspoon's
    -- main thread. When that machinery raises an Objective-C exception —
    -- and on a fresh macOS, or with Automation permission in an odd state,
    -- it can — the process ABORTS. LL's crash report is that, frame for
    -- frame:
    --        _NSAppleEventManagerGenericHandler
    --        handleUncaughtException
    --        -[SentryCrashExceptionApplication reportException:]
    --        abort()
    --
    -- ⚠️ AND THE pcall AROUND IT WAS WORTH NOTHING. Lua's pcall catches
    -- Lua errors. An Objective-C exception is not a Lua error: it unwinds
    -- straight past pcall to the uncaught handler and kills the app. Every
    -- "it is wrapped, so it is safe" instinct is wrong here, which is what
    -- made this worth a crash to learn.
    --
    -- /usr/bin/osascript is the SAME AppleScript in a SEPARATE PROCESS. If
    -- it throws, dies, or hangs, a child process dies and we get an exit
    -- code. Nothing can take Hammerspoon down with it.
    --
    -- The cost is that it is ASYNCHRONOUS, so the panel cannot ask for the
    -- selection and have it in the same breath. It is read on a short
    -- cadence and cached instead — see ua.refresh().
    ua.selection, ua.selectionAt, ua.selTask = {}, 0, nil

    function ua.refresh(done)
        -- One in flight at a time. Holding the reference matters twice
        -- over: an unreferenced hs.task is collected mid-run, and without
        -- the guard a held-down key would fan out a process per press.
        if ua.selTask then
            local okRun, running = pcall(function() return ua.selTask:isRunning() end)
            if okRun and running then if done then done(ua.selection) end return end
        end
        local okNew, t = pcall(hs.task.new, "/usr/bin/osascript",
            function(_, stdOut, _)
                local paths = {}
                for line in tostring(stdOut or ""):gmatch("[^\r\n]+") do
                    if line ~= "" then paths[#paths + 1] = line end
                end
                ua.selection, ua.selectionAt = paths, hs.timer.secondsSinceEpoch()
                ua.selTask = nil
                if done then pcall(done, paths) end
            end,
            { "-e", FINDER_SEL })
        if not (okNew and t) then
            -- No child process is a degraded panel, not a dead one: the
            -- clipboard actions still apply.
            warn("could not start osascript — Finder selection unavailable")
            if done then pcall(done, {}) end
            return
        end
        ua.selTask = t
        pcall(function() t:start() end)
    end

    -- What the panel uses. Never blocks: it returns the last known answer
    -- and kicks off a refresh for the next press. The staleness window is
    -- one press wide, and a wrong file would be visible in the panel's own
    -- title before you chose anything.
    function ua.finderSelection()
        local age = hs.timer.secondsSinceEpoch() - (ua.selectionAt or 0)
        if age > ua.selectionSecs then ua.refresh() end
        return ua.selection or {}
    end

    function ua.clipboardText()
        local ok, t = pcall(hs.pasteboard.getContents)
        if ok and type(t) == "string" and t ~= "" then return t end
        return nil
    end

    -- A URL is "starts with a scheme we can hand to `open`". Deliberately
    -- narrow: matching anything with a dot in it turns every filename into
    -- a URL and hands `open` something it will refuse.
    local function asURL(s)
        if type(s) ~= "string" then return nil end
        s = s:match("^%s*(.-)%s*$")
        if s:match("^https?://%S+$") or s:match("^mailto:%S+$")
           or s:match("^file://%S+$") then return s end
        return nil
    end

    -- The context every action is handed and every action is filtered on.
    -- Built once per press: one Finder round-trip, not one per row.
    function ua.context()
        local files = ua.finderSelection()
        local text  = ua.clipboardText()
        return {
            files = files,
            file  = files[1],
            dir   = files[1] and (files[1]:match("^(.*)/[^/]*$") or files[1]) or nil,
            text  = text,
            url   = asURL(text),
        }
    end

    -- =====================================================================
    -- THE ACTIONS
    -- =====================================================================
    -- Each one declares `when` (can it run at all right now) and `run`.
    -- Keeping the test in the table rather than inside run() is what lets
    -- the picker HIDE inapplicable rows instead of offering them and then
    -- reporting a failure you could have been spared.
    --
    -- ✏️ To add one: copy a row. `id` must be stable — it is what the
    -- most-recently-used file stores, so renaming an id costs you its
    -- position in the order, and reusing one silently inherits it.
    local function sh(cmd)
        return pcall(function() hs.task.new("/bin/zsh", nil, { "-lc", cmd }):start() end)
    end
    local function shq(s) return "'" .. tostring(s):gsub("'", [['\'']]) .. "'" end

    ua.actions = {
        { id = "reveal", title = "Reveal in Finder", sub = "Show the file in its folder",
          when = function(c) return c.file ~= nil end,
          run  = function(c) return sh("/usr/bin/open -R " .. shq(c.file)) end },

        { id = "open", title = "Open", sub = "Open with the default app",
          when = function(c) return c.file ~= nil end,
          run  = function(c) return sh("/usr/bin/open " .. shq(c.file)) end },

        { id = "openwith", title = "Open With…", sub = "Choose an application",
          when = function(c) return c.file ~= nil end,
          run  = function(c)
              -- There is no "show the Open With sheet" API, so this opens
              -- the Get Info window, where that menu lives. Named honestly
              -- in the subtitle rather than pretending it is the sheet.
              return sh("/usr/bin/osascript -e " .. shq(
                  'tell application "Finder" to open information window of (POSIX file "'
                  .. c.file .. '" as alias)'))
          end },

        { id = "copypath", title = "Copy Path to Clipboard", sub = "The POSIX path",
          when = function(c) return c.file ~= nil end,
          run  = function(c)
              local all = table.concat(c.files, "\n")
              return pcall(function() hs.pasteboard.setContents(all) end)
          end },

        { id = "copyfile", title = "Copy File to Clipboard", sub = "The file itself, to paste elsewhere",
          when = function(c) return c.file ~= nil end,
          run  = function(c)
              return sh("/usr/bin/osascript -e " .. shq(
                  'set the clipboard to (POSIX file "' .. c.file .. '")'))
          end },

        { id = "terminal", title = "Open Terminal Here", sub = "A shell in the containing folder",
          when = function(c) return c.dir ~= nil end,
          run  = function(c) return sh("/usr/bin/open -a Terminal " .. shq(c.dir)) end },

        { id = "getinfo", title = "Get Info", sub = "Finder's info window",
          when = function(c) return c.file ~= nil end,
          run  = function(c)
              return sh("/usr/bin/osascript -e " .. shq(
                  'tell application "Finder" to open information window of (POSIX file "'
                  .. c.file .. '" as alias)'))
          end },

        { id = "openurl", title = "Open URL", sub = "Open the copied link in your browser",
          when = function(c) return c.url ~= nil end,
          run  = function(c) return sh("/usr/bin/open " .. shq(c.url)) end },

        { id = "cleanurl", title = "Clean URL (strip trackers)", sub = "Then copy it back",
          when = function(c) return c.url ~= nil end,
          run  = function()
              if not _G.service then return false end
              return pcall(function() _G.service.call("url.cleanClipboard") end)
          end },

        { id = "plaintext", title = "Copy as Plain Text", sub = "Strip formatting from the clipboard",
          when = function(c) return c.text ~= nil end,
          run  = function(c) return pcall(function() hs.pasteboard.setContents(c.text) end) end },

        { id = "largetype", title = "Show as Large Type", sub = "Read it from across the room",
          when = function(c) return c.text ~= nil end,
          run  = function(c)
              return pcall(function() hs.alert.show(c.text:sub(1, 400), 6) end)
          end },

        { id = "email", title = "Email…", sub = "New message with this attached or pasted",
          when = function(c) return c.file ~= nil or c.text ~= nil end,
          run  = function(c)
              if c.file then
                  return sh("/usr/bin/open -a Mail " .. shq(c.file))
              end
              return sh("/usr/bin/open " .. shq("mailto:?body=" ..
                  hs.http.encodeForQuery(c.text:sub(1, 1500))))
          end },

        { id = "snippet", title = "Save as Snippet", sub = "Append to the Capture Pad",
          when = function(c) return c.text ~= nil end,
          run  = function(c)
              if not _G.service then return false end
              return pcall(function() _G.service.call("capturePad.add", c.text) end)
          end },

        { id = "rename", title = "Bulk Rename…", sub = "Open the renamer on this selection",
          when = function(c) return c.file ~= nil end,
          run  = function()
              if not _G.service then return false end
              return pcall(function() _G.service.call("rename.show") end)
          end },
    }

    -- =====================================================================
    -- MOST RECENTLY USED
    -- =====================================================================
    -- A list of ids, newest first. Anything not in it keeps its table
    -- order behind everything that is — so a fresh install reads in the
    -- order written above, and yours diverges from there.
    ua.mru = {}

    function ua.load()
        local fh = io.open(ua.store, "r")
        if not fh then return end
        local raw = fh:read("*a"); fh:close()
        local ok, decoded = pcall(function() return hs.json.decode(raw) end)
        if not (ok and type(decoded) == "table") then
            warn("could not read " .. ua.store .. " — starting from the default order")
            return
        end
        -- 🚨 OUR OWN COPY, one string at a time. Adopting the decoder's
        -- table is what left the Capture Pad with queue and parked as ONE
        -- table in 6.62.0; the fix there was to copy, and the same applies
        -- to every decoder result in this config.
        local out = {}
        for _, v in ipairs(decoded) do
            if type(v) == "string" then out[#out + 1] = v end
            if #out >= ua.maxMRU then break end
        end
        ua.mru = out
        say("restored " .. #out .. " remembered actions")
    end

    function ua.save()
        local ok, raw = pcall(function() return hs.json.encode(ua.mru) end)
        if not ok then return false end
        local fh = io.open(ua.store, "w")
        if not fh then
            if core.warnWriteFailed then core.warnWriteFailed("Universal Actions order") end
            return false
        end
        fh:write(raw); fh:close()
        return true
    end

    -- ONE PLACE that guarantees ua.mru is a list, and the only place that
    -- has to know it might not be. Everything downstream iterates it, and
    -- it ultimately comes from a FILE — truncated, hand-edited or written
    -- by an older version. A bad store must cost you the remembered order
    -- and nothing else; a panel that throws because its preferences file
    -- is odd is a worse outcome than one that opens in default order.
    local function mruList()
        if type(ua.mru) ~= "table" then ua.mru = {} end
        return ua.mru
    end

    function ua.remember(id)
        local out = { id }
        for _, v in ipairs(mruList()) do
            if v ~= id and #out < ua.maxMRU then out[#out + 1] = v end
        end
        ua.mru = out
        ua.save()
    end

    -- The order the picker draws: MRU first in MRU order, then the rest in
    -- table order. Written as a rank lookup rather than a sort comparator
    -- because a comparator over a partial order is how table.sort throws
    -- "invalid order function for sorting" on a list you cannot reproduce.
    function ua.ordered(ctx)
        local rank = {}
        for i, id in ipairs(mruList()) do
            if type(id) == "string" then rank[id] = i end
        end
        local used, rest = {}, {}
        for i, a in ipairs(ua.actions) do
            local okWhen, applies = pcall(a.when, ctx)
            if okWhen and applies then
                if rank[a.id] then used[#used + 1] = { a = a, r = rank[a.id] }
                else rest[#rest + 1] = { a = a, r = i } end
            end
        end
        table.sort(used, function(x, y) return x.r < y.r end)
        table.sort(rest, function(x, y) return x.r < y.r end)
        local out = {}
        for _, e in ipairs(used) do out[#out + 1] = e.a end
        for _, e in ipairs(rest) do out[#out + 1] = e.a end
        return out
    end

    -- =====================================================================
    -- THE PICKER
    -- =====================================================================
    ua.chooser = nil          -- HELD: an unreferenced chooser is collected

    local function describe(ctx)
        if ctx.file then
            local n = #ctx.files
            local name = ctx.file:match("[^/]+$") or ctx.file
            return n > 1 and (n .. " items selected") or name
        end
        if ctx.url  then return "clipboard: " .. ctx.url:sub(1, 60) end
        if ctx.text then return "clipboard: " .. ctx.text:sub(1, 60):gsub("%s+", " ") end
        return nil
    end

    function ua.show()
        if not ua.enabled then return false end
        local ctx = ua.context()
        local what = describe(ctx)
        if not what then
            hs.alert.show("⚡ Nothing to act on — select a file or copy something")
            return false
        end

        local list, choices = ua.ordered(ctx), {}
        for _, a in ipairs(list) do
            choices[#choices + 1] = { text = a.title, subText = a.sub, id = a.id }
        end
        if #choices == 0 then
            hs.alert.show("⚡ No action applies to that")
            return false
        end
        -- Always last, never remembered, never floated. It is housekeeping
        -- for the list itself rather than an action on your selection, and
        -- an entry that could promote ITSELF to the top would eventually
        -- sit above the things you actually use.
        choices[#choices + 1] = {
            text = "Reset action order",
            subText = "Forget what I used most and go back to the default list",
            id = "__reset",
        }

        if not ua.chooser then
            local okNew, c = pcall(hs.chooser.new, function(pick)
                if not pick then return end
                ua.run(pick.id)
            end)
            if not (okNew and c) then
                hs.alert.show("⚡ Universal Actions could not open — see the Console")
                warn("hs.chooser.new failed")
                return false
            end
            ua.chooser = c
            pcall(function() c:rows(ua.rows); c:width(ua.width); c:searchSubText(true) end)
        end

        -- The context is captured for THIS press. Re-reading it in the
        -- callback would act on whatever is selected when you finally
        -- choose, which after a few seconds of scrolling need not be what
        -- the panel said it was acting on.
        ua.ctx = ctx
        pcall(function()
            ua.chooser:placeholderText("⚡ " .. what)
            ua.chooser:query("")
            ua.chooser:choices(choices)
            ua.chooser:show()
        end)
        say("opened on " .. what .. " with " .. #choices .. " actions")
        return true
    end

    function ua.run(id)
        local ctx = ua.ctx
        if id == "__reset" then return ua.reset() end
        for _, a in ipairs(ua.actions) do
            if a.id == id then
                local ok, err = pcall(a.run, ctx)
                if ok then
                    -- Remembered only on SUCCESS. Floating an action that
                    -- just failed to the top of the list is the opposite of
                    -- helpful.
                    ua.remember(id)
                    say("ran " .. id)
                    return true
                end
                warn("action '" .. id .. "' failed: " .. tostring(err))
                hs.alert.show("⚡ " .. a.title .. " failed — see the Console")
                if _G.notices then
                    _G.notices.record("universalActions", "action failed",
                                      a.title .. " — " .. tostring(err):sub(1, 120))
                end
                return false
            end
        end
        return false
    end

    function ua.reset()
        ua.mru = {}
        ua.save()
        hs.alert.show("⚡ Action order reset to the default")
        return true
    end

    -- ---- wiring ----------------------------------------------------------
    ua.load()
    if ua.enabled then
        core.hyperAddShortcut({ "shift" }, ua.key, function() ua.show() end,
                              "universal actions")
    end
    -- Reset is a ROW in the picker, not a second shortcut. It is a
    -- once-a-year action, and a once-a-year action that costs a hyper key
    -- is a bad trade in a keyspace with three free letters left in it —
    -- it is also more discoverable there than in a chord nobody recalls.

    core.provide("universalActions.show", function() return ua.show() end)

    _G.universalActions = ua
    M.ua     = ua
    M.config = ua
end

return M
