-- =====================================================================
-- MODULE: QUICK APPEND (⇪J) — put text into a file without opening it
-- =====================================================================
-- ⇪J appends whatever is on the clipboard to your default notes file and
-- shows you what it wrote. ⇪⇧J asks WHICH file first, and offers a
-- "type a line" box if the thing you want to save was never on the
-- clipboard at all. Nothing opens, nothing takes focus, the file is
-- closed again before the alert appears.
--
-- WHY io.open AND NOT AN EDITOR. Opening a file to add a line to it is
-- the slow path for a reason that has nothing to do with typing speed:
-- an editor holds the file, so two appends a second apart can race, and
-- a file left open in an editor loses whatever this writes underneath
-- it. Append mode ("a") is a single positioned write handled by the
-- filesystem — concurrent appends of a short line do not interleave.
--
-- ⚠️ EVERY WRITE IS CHECKED. io.open returns nil on failure and Lua does
-- not raise; a write to an unavailable OneDrive folder therefore fails
-- SILENTLY unless you look. Every path here checks, and reports through
-- core.warnWriteFailed so a missing folder says so once rather than
-- once per keystroke.

local M = {
    name  = "Quick Append",
    order = 13.3,
    cheatsheet = {
        title = "📝 QUICK APPEND (⇪J — clipboard into a file, no editor)",
        entries = {
            { "⇪J",  "Append the clipboard to the default notes file" },
            { "⇪⇧J", "Pick which file — or type a line instead of pasting" },
            { "adds", "A timestamp line, then your text, then a blank line" },
            { "shows", "The file, the line count, and the first words it wrote" },
            { "files", "Live in <logs>/notes/ — edit quickAppend.targets to change" },
            { "safe", "Append mode: never truncates, never holds the file open" },
        },
    },
}

function M.setup(core)
    local qa = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    qa.enabled = true
    -- Where a bare filename below resolves to. An absolute path or one
    -- starting with ~ is used exactly as written and ignores this.
    qa.dir = (core.logsDir or core.homeDir) .. "/notes"
    qa.targets = {
        { name = "Inbox",   file = "inbox.txt",   note = "anything, sorted later" },
        { name = "Ideas",   file = "ideas.txt",   note = "half-formed thoughts" },
        { name = "Scratch", file = "scratch.txt", note = "throwaway" },
        { name = "Log",     file = "log.txt",     note = "what happened today" },
    }
    qa.defaultTarget = 1        -- index into qa.targets, used by ⇪J
    qa.stamp         = true     -- write a "── 2026-08-07 20:41 ──" line first
    qa.stampFormat   = "%Y-%m-%d %H:%M"
    qa.trailingBlank = true     -- blank line after each entry
    qa.maxPreview    = 60       -- characters of the entry shown in the alert
    qa.key           = "j"
    -- ----------------------------------------------------------------------

    local function expand(path)
        if path:sub(1, 1) == "~" then
            return (core.homeDir or os.getenv("HOME") or "~") .. path:sub(2)
        end
        return path
    end

    function qa.pathFor(target)
        local f = target and target.file or ""
        if f:sub(1, 1) == "/" or f:sub(1, 1) == "~" then return expand(f) end
        return qa.dir .. "/" .. f
    end

    -- mkdir is not recursive here, and it does not need to be: qa.dir is one
    -- level under logsDir, which the portability layer has already created.
    -- Called before every write rather than once at setup, because the
    -- folder can go away underneath us (an unmounted drive, a OneDrive
    -- folder that went online-only) long after boot.
    local function ensureDir()
        if hs.fs.attributes(qa.dir) == nil then pcall(hs.fs.mkdir, qa.dir) end
    end

    local function firstWords(text, n)
        text = (tostring(text or ""):gsub("%s+", " "):gsub("^%s*", ""))
        if #text <= n then return text end
        return text:sub(1, n - 1) .. "…"
    end

    local function countLines(text)
        local n = 0
        for _ in tostring(text or ""):gmatch("\n") do n = n + 1 end
        -- A final line with no newline after it still counts.
        if #text > 0 and text:sub(-1) ~= "\n" then n = n + 1 end
        return n
    end

    -- The one function that writes. Returns ok, message — never throws and
    -- never shows anything itself, so it is callable from a hotkey, from a
    -- chooser, and from another module through the service registry.
    function qa.append(text, target)
        target = target or qa.targets[qa.defaultTarget] or qa.targets[1]
        if not target then return false, "no target file is configured" end
        text = tostring(text or "")
        -- Trailing whitespace only means an empty entry, and an empty entry
        -- in a notes file is worse than nothing: it is a timestamp with a
        -- hole under it that you cannot tell from a lost note.
        if text:gsub("%s+", "") == "" then return false, "nothing to write — the text was empty" end

        ensureDir()
        local path = qa.pathFor(target)
        local f, err = io.open(path, "a")
        if not f then
            if core.warnWriteFailed then core.warnWriteFailed("notes file " .. path) end
            return false, "could not open " .. path .. " — " .. tostring(err)
        end

        local chunk = ""
        if qa.stamp then
            chunk = chunk .. "── " .. os.date(qa.stampFormat) .. " ──\n"
        end
        chunk = chunk .. text
        if text:sub(-1) ~= "\n" then chunk = chunk .. "\n" end
        if qa.trailingBlank then chunk = chunk .. "\n" end

        local okWrite, writeErr = pcall(function() f:write(chunk) end)
        -- close() is where a full disk actually surfaces: write() buffers,
        -- close() flushes. Checking only write() would call a failed save a
        -- success.
        local okClose = pcall(function() return f:close() end)
        if not okWrite or not okClose then
            if core.warnWriteFailed then core.warnWriteFailed("notes file " .. path) end
            return false, "write failed — " .. tostring(writeErr)
        end

        _G.diag.say("quickAppend", string.format("wrote %d chars to %s", #chunk, path))
        return true, string.format("📝 %s ← %d line%s: %s",
            target.name, countLines(text), countLines(text) == 1 and "" or "s",
            firstWords(text, qa.maxPreview))
    end

    -- ---- the two keys ----------------------------------------------------
    function qa.appendClipboard(target)
        local text = hs.pasteboard.getContents()
        if text == nil or text == "" then
            -- An image on the clipboard is the common reason for this, and
            -- "clipboard is empty" would be a lie in that case.
            hs.alert.show("📝 Nothing to append — the clipboard holds no text")
            return false
        end
        local ok, msg = qa.append(text, target)
        hs.alert.show(ok and msg or ("⚠️ " .. msg), ok and 2 or 5)
        if not ok then print("📝 Quick Append: " .. msg) end
        return ok
    end

    -- The tail of the file, for the chooser subtext. Read from the END:
    -- these files grow without limit and reading a 40MB log to show one
    -- line in a picker is the kind of thing that turns a keypress into a
    -- pause.
    local function tailOf(path, bytes)
        local f = io.open(path, "r")
        if not f then return "empty — this will create it" end
        local size = f:seek("end")
        f:seek("set", math.max(0, size - bytes))
        local blob = f:read("a") or ""
        f:close()
        local last
        for line in blob:gmatch("[^\n]+") do
            if line:gsub("%s+", "") ~= "" and not line:match("^──") then last = line end
        end
        if not last then return string.format("%d bytes", size) end
        return string.format("%.1f KB · last: %s", size / 1024, firstWords(last, 44))
    end

    function qa.chooseTarget()
        local choices = {
            { text = "✏️  Type a line instead…",
              subText = "Opens a box; what you type is appended to the default file",
              typeIt = true },
        }
        for i, t in ipairs(qa.targets) do
            table.insert(choices, {
                text    = t.name .. (i == qa.defaultTarget and "   (default)" or ""),
                subText = (t.note and (t.note .. " · ") or "") .. tailOf(qa.pathFor(t), 4096),
                index   = i,
            })
        end

        local chooser
        chooser = hs.chooser.new(function(choice)
            if not choice then return end
            if choice.typeIt then
                -- textPrompt is modal and returns the button that was used,
                -- so a cancelled box does not write an empty entry.
                local button, typed = hs.dialog.textPrompt(
                    "Quick Append",
                    "This is appended to " ..
                    (qa.targets[qa.defaultTarget] or {}).name .. ".",
                    "", "Append", "Cancel")
                if button == "Append" then
                    local ok, msg = qa.append(typed)
                    hs.alert.show(ok and msg or ("⚠️ " .. msg), ok and 2 or 5)
                end
                return
            end
            qa.appendClipboard(qa.targets[choice.index])
        end)
        chooser:choices(choices)
        chooser:placeholderText("Append the clipboard to…")
        chooser:searchSubText(true)
        chooser:rows(math.min(8, #choices))
        chooser:show()
        qa.chooser = chooser   -- held: a collected chooser closes itself
    end

    if qa.enabled then
        core.hyperAddShortcut({}, qa.key, function() qa.appendClipboard() end, "quick append")
        core.hyperAddShortcut({ "shift" }, qa.key, function() qa.chooseTarget() end,
                              "quick append — pick file")
    end

    -- Published so anything else can drop a line in a notes file without
    -- knowing where they live:  _G.service.call("notes.append", "text")
    core.provide("notes.append", function(text, targetName)
        local target
        for _, t in ipairs(qa.targets) do
            if t.name == targetName then target = t end
        end
        return qa.append(text, target)
    end)

    _G.quickAppend = qa
    M.qa     = qa
    M.config = qa
end

return M
