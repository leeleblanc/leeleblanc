-- =====================================================================
-- MODULE: SCREENSHOTS (⇪4) — every capture saved to OneDrive AND copied
-- =====================================================================
-- ⇪4 starts the native crosshair capture (the same one ⌘⇧4 gives you;
-- press SPACE mid-selection to switch to window capture, Esc to bail).
-- The image lands in BOTH places at once:
--
--   1. A timestamped PNG in OneDrive's "2026 Screenshots" folder, so it
--      syncs and survives.
--   2. The macOS clipboard, so ⌘V pastes it immediately.
--
-- macOS itself makes you choose — ⌘⇧4 saves a file, ⌘⌃⇧4 copies to the
-- clipboard, never both. This module runs `screencapture -i` to a file
-- and then reads that file back onto the clipboard, which is the whole
-- trick.
--
-- ⇪⇧4 opens the HISTORY PICKER: past screenshots newest-first, each row
-- with a thumbnail. ↑/↓ to move, type to filter by name or date,
-- ⏎ puts the picked image back on the clipboard, ⌘⏎ copies its file
-- PATH instead (which is exactly what the Task Form's 📎 field wants).
--
-- ---------------------------------------------------------------------
-- 🚫 WHAT IT DELIBERATELY DOES NOT DO: WATCH THE CLIPBOARD
-- ---------------------------------------------------------------------
-- The other way to get "copied images end up in a folder" is a
-- pasteboard watcher that saves every image that ever crosses the
-- clipboard. That fires on every image copied out of a browser, a PDF,
-- a Slack thread — and quietly fills the folder with junk that was
-- never a screenshot. A deliberate keystroke saves exactly what you
-- meant to keep, and nothing else.
--
-- ---------------------------------------------------------------------
-- ☁️ ONEDRIVE, TWO HONEST CAVEATS
-- ---------------------------------------------------------------------
--   · WRITES are safe: the folder is inside ~/Library/CloudStorage, so
--     the file is written locally and OneDrive uploads it in its own
--     time. No capture ever waits on the network.
--   · READS can stall: Files-On-Demand may have evicted an OLD
--     screenshot to cloud-only. Picking one of those in the history
--     forces a download first — a beat of delay on ancient rows, never
--     on fresh ones. The picker's thumbnails read the files too, which
--     is why the list is capped (shots.maxList) instead of thumbnailing
--     the whole folder.
-- =====================================================================

local M = {
    name  = "Screenshots",
    order = 23,
    cheatsheet = {
        title = "📸 SCREENSHOTS (⇪4 — saved to OneDrive AND copied)",
        entries = {
            { "⇪4",   "Capture: crosshair select · SPACE = window · Esc = cancel" },
            { "",     "saves to OneDrive/2026 Screenshots + copies to clipboard" },
            { "⇪⇧4",  "History: past screenshots, newest first, with thumbnails" },
            { "⏎",    "put the picked screenshot back on the clipboard" },
            { "⌘⏎",   "copy its file PATH instead (feeds the Task Form's 📎)" },
        },
    },
}

function M.setup(core)
    local shots = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    shots.enabled   = true
    shots.key       = "4"     -- ⇪4 capture · ⇪⇧4 history (mnemonic: ⌘⇧4)
    shots.dir       = (core.homeDir or os.getenv("HOME") or "")
                      .. "/Library/CloudStorage/OneDrive-Personal/2026 Screenshots"
    shots.maxList   = 30      -- newest N screenshots shown in the picker
    shots.thumbH    = 72      -- thumbnail height in picker rows, pixels
    shots.alertSecs = 2.0
    -- ----------------------------------------------------------------------

    local function say(m)  if _G.diag then _G.diag.say("screenshots", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("screenshots", m) end end

    -- ---- folder ----------------------------------------------------------
    -- Checked at CAPTURE time, not at boot: setup() must stay cheap, and
    -- on the hostile Mac (no OneDrive, hs.fs answering nil) the module
    -- should degrade to a clear alert, not a boot error.
    function shots.ensureDir()
        local mode
        pcall(function() mode = hs.fs.attributes(shots.dir, "mode") end)
        if mode == "directory" then return shots.dir end
        local made = false
        pcall(function() made = hs.fs.mkdir(shots.dir) end)
        if made then
            say("created " .. shots.dir)
            return shots.dir
        end
        -- mkdir cannot create parents; if OneDrive-Personal itself is
        -- missing (not signed in, different account name) say WHERE it
        -- looked rather than failing into the Console.
        pcall(function()
            hs.alert.show("📸 Screenshots folder unavailable:\n" .. shots.dir, 4)
        end)
        warn("folder unavailable: " .. shots.dir)
        return nil
    end

    -- ---- filenames -------------------------------------------------------
    -- Same shape macOS uses ("Screenshot 2026-08-15 at 14.23.05.png") so
    -- the folder sorts naturally in Finder. Dots in the time, not colons:
    -- HFS+/APFS display colons as slashes and some sync targets refuse
    -- them outright.
    function shots.filenameAt(t)
        return os.date("Screenshot %Y-%m-%d at %H.%M.%S", t) .. ".png"
    end

    local function freshPath()
        local base = shots.dir .. "/" .. shots.filenameAt()
        local exists
        pcall(function() exists = hs.fs.attributes(base, "size") end)
        if not exists then return base end
        -- two captures inside one second — number the second one rather
        -- than letting screencapture overwrite the first
        for n = 2, 99 do
            local p = base:gsub("%.png$", (" (%d).png"):format(n))
            local e
            pcall(function() e = hs.fs.attributes(p, "size") end)
            if not e then return p end
        end
        return base
    end

    -- ---- capture (⇪4) ----------------------------------------------------
    function shots.finish(path)
        -- Esc during selection: screencapture exits WITHOUT writing the
        -- file. That is a cancel, not an error — stay silent.
        local size
        pcall(function() size = hs.fs.attributes(path, "size") end)
        if not size or size == 0 then
            say("capture cancelled")
            return false
        end
        local img
        pcall(function() img = hs.image.imageFromPath(path) end)
        local copied = false
        if img then
            pcall(function() copied = hs.pasteboard.writeObjects(img) and true end)
        end
        if copied then
            pcall(function()
                hs.alert.show("📸 Saved to 2026 Screenshots · on the clipboard",
                              shots.alertSecs)
            end)
        else
            -- The file is the half that must never be lost; say so
            -- plainly instead of pretending the copy worked.
            pcall(function()
                hs.alert.show("📸 Saved to 2026 Screenshots — clipboard copy failed",
                              shots.alertSecs)
            end)
        end
        say("captured " .. (path:match("[^/]+$") or path)
            .. (copied and " (copied)" or " (copy FAILED)"))
        return true
    end

    function shots.capture()
        if not shots.ensureDir() then return end
        local path = freshPath()
        local t
        local ok = pcall(function()
            t = hs.task.new("/usr/sbin/screencapture", function()
                shots.captureTask = nil    -- release only when done
                shots.finish(path)
            end, { "-i", path })
        end)
        if not (ok and t) then
            pcall(function() hs.alert.show("📸 screencapture unavailable", 3) end)
            warn("hs.task.new failed for screencapture")
            return
        end
        shots.captureTask = t   -- HELD: an unreferenced hs.task is collected
        local started = false
        pcall(function() started = t:start() end)
        if not started then
            shots.captureTask = nil
            pcall(function() hs.alert.show("📸 could not start screencapture", 3) end)
        end
    end

    -- ---- listing ---------------------------------------------------------
    local IMAGE_EXT = { png = true, jpg = true, jpeg = true, gif = true,
                        tiff = true, heic = true, webp = true }

    function shots.list()
        local out = {}
        pcall(function()
            for f in hs.fs.dir(shots.dir) do
                local ext = f:match("%.(%w+)$")
                if f:sub(1, 1) ~= "." and ext and IMAGE_EXT[ext:lower()] then
                    local p = shots.dir .. "/" .. f
                    local mt, sz
                    pcall(function()
                        mt = hs.fs.attributes(p, "modification")
                        sz = hs.fs.attributes(p, "size")
                    end)
                    out[#out + 1] = { name = f, path = p,
                                      mtime = tonumber(mt) or 0,
                                      size  = tonumber(sz) or 0 }
                end
            end
        end)
        table.sort(out, function(a, b)
            if a.mtime ~= b.mtime then return a.mtime > b.mtime end
            return a.name > b.name   -- same second: the "(2)" copy first
        end)
        return out
    end

    function shots.latest()
        local l = shots.list()
        return l[1] and l[1].path or nil
    end

    -- ---- history picker (⇪⇧4) --------------------------------------------
    -- Thumbnails are the expensive part: hs.image.imageFromPath decodes
    -- the WHOLE png just to draw a 72px row. Two defences: the list cap,
    -- and this cache — keyed by path + mtime so an edited file re-reads
    -- but an unchanged one never decodes twice in a session.
    shots.thumbCache = {}

    local function thumbFor(entry)
        local c = shots.thumbCache[entry.path]
        if c and c.mtime == entry.mtime then return c.img end
        local img
        pcall(function()
            local full = hs.image.imageFromPath(entry.path)
            if full then
                img = full:setSize({ w = shots.thumbH * 1.6, h = shots.thumbH })
            end
        end)
        if img then
            shots.thumbCache[entry.path] = { mtime = entry.mtime, img = img }
        end
        return img
    end

    local function prettySize(bytes)
        if bytes >= 1024 * 1024 then
            return string.format("%.1f MB", bytes / (1024 * 1024))
        end
        return string.format("%d KB", math.max(1, math.floor(bytes / 1024)))
    end

    function shots.choicesFrom(list)
        local choices = {}
        for i, e in ipairs(list) do
            if i > shots.maxList then break end
            choices[#choices + 1] = {
                text    = e.name,
                subText = os.date("%b %d %Y  %H:%M", e.mtime)
                          .. "  ·  " .. prettySize(e.size)
                          .. "  ·  ⏎ image on clipboard · ⌘⏎ path",
                path    = e.path,
            }
        end
        if #choices == 0 then
            choices[1] = {
                text    = "No screenshots yet",
                subText = "⇪4 takes one — it lands in " .. shots.dir,
            }
        end
        return choices
    end

    function shots.onPick(choice)
        if not choice or not choice.path then return end
        -- ⌘ held while pressing ⏎ = "give me the PATH, not the pixels".
        -- hs.chooser reports nothing about modifiers, but the keyboard
        -- state at selection time is readable — same trick the window
        -- switcher uses.
        local mods = {}
        pcall(function() mods = hs.eventtap.checkKeyboardModifiers() or {} end)
        if mods.cmd then
            local ok = false
            pcall(function() ok = hs.pasteboard.setContents(choice.path) end)
            pcall(function()
                hs.alert.show(ok and "📎 Path copied" or "⚠️ Could not copy path",
                              shots.alertSecs)
            end)
            return
        end
        -- ☁️ this read is the one that can stall on a cloud-evicted file —
        -- see the OneDrive note in the header.
        local img
        pcall(function() img = hs.image.imageFromPath(choice.path) end)
        local copied = false
        if img then
            pcall(function() copied = hs.pasteboard.writeObjects(img) and true end)
        end
        pcall(function()
            hs.alert.show(copied and "📋 Screenshot on the clipboard"
                                  or "⚠️ Could not read that screenshot",
                          shots.alertSecs)
        end)
    end

    function shots.show()
        if not shots.chooser then
            local ok = pcall(function()
                shots.chooser = hs.chooser.new(function(choice)
                    shots.onPick(choice)
                end)
            end)
            if not (ok and shots.chooser) then
                shots.chooser = nil
                pcall(function() hs.alert.show("📸 picker unavailable", 3) end)
                return
            end
            pcall(function()
                shots.chooser:placeholderText("Search screenshots by name or date…")
            end)
        end
        local list = shots.list()
        local choices = shots.choicesFrom(list)
        -- attach thumbnails AFTER choicesFrom so the pure list logic
        -- stays testable without hs.image
        for _, c in ipairs(choices) do
            if c.path then
                local mt
                for _, e in ipairs(list) do
                    if e.path == c.path then mt = e; break end
                end
                if mt then c.image = thumbFor(mt) end
            end
        end
        pcall(function() shots.chooser:choices(choices) end)
        if core.showPopup then
            core.showPopup(shots.chooser)
        else
            pcall(function() shots.chooser:show() end)
        end
    end

    -- ---- keys & services -------------------------------------------------
    if shots.enabled then
        core.hyperAddShortcut({}, shots.key, function() shots.capture() end,
                              "screenshot — save + copy")
        core.hyperAddShortcut({ "shift" }, shots.key, function() shots.show() end,
                              "screenshot history")
    end

    -- screenshots.latest is what the Task Form's 📸 button calls — one
    -- keystroke from "capture" to "attached to a task".
    core.provide("screenshots.latest",  function() return shots.latest() end)
    core.provide("screenshots.capture", function() return shots.capture() end)
    core.provide("screenshots.show",    function() return shots.show() end)

    _G.screenshots = shots
    M.shots  = shots
    M.config = shots
end

return M
