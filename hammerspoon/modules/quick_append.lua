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
--
-- 🧾 6.99.0 (columns re-cut 6.100.0) — EVERY APPEND ALSO LANDS AS ONE
-- CSV ROW in notes.csv, next to the text files, in LL's three columns:
-- | Date | Note Type | Note entry |. Note Type is Ideas or Logs, never
-- anything else — a target the spec doesn't know is recorded as Logs
-- ("if you can't tell, make it a Log entry"). The text file stays the
-- thing you read; the CSV is the thing you SEARCH and sort — Excel
-- opens it by double-click, exactly like chrome_history's archive. A
-- note that reaches its text file but misses the CSV says so in the
-- alert instead of letting the two files drift apart silently.
--
-- 🔢 ALSO 6.99.0 — the number pad's bottom row drives this module:
-- ⇪pad1 appends the clipboard as a Log, ⇪pad2 opens the Quick Append
-- Pad, ⇪pad3 asks which file. The bindings live in numpad_layer.lua
-- (by service name); the services live here.

local M = {
    name  = "Quick Append",
    order = 13.3,
    family = "capture",
    cheatsheet = {
        title = "📝 QUICK APPEND (⇪J / ⇪pad1 — clipboard into a file, no editor)",
        entries = {
            -- 🔤 6.114.0 — THE TWO PAD ROWS LOST THEIR KEY CELLS. They read
            -- "⇪pad1" and "⇪pad3" here and "⇪ pad1"/"⇪ pad3" in the numpad
            -- layer's group, so one shortcut appeared on the sheet twice
            -- under two spellings and ⇪space listed it twice. numpad_layer
            -- BINDS those keys, so under the 6.102.0 one-owner rule its
            -- group keeps them. Nothing about the keys changed.
            { "⇪J",  "Append the clipboard to log.txt — a Log note, instantly" },
            { "⇪⇧J", "Pick Logs or Ideas — or type a line instead of pasting" },
            { "on a pad", "⇪pad1 does ⇪J · ⇪pad3 does ⇪⇧J — see the numpad group" },
            { "adds", "A timestamp line, then your text, then a blank line" },
            { "shows", "The file, the line count, and the first words it wrote" },
            { "files", "Live in <logs>/notes/ — edit quickAppend.targets to change" },
            { "csv",  "Every append is one notes.csv row — Date · Note Type · Note entry" },
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
    -- 6.100.0 — TWO note types, on request: "Note type would be either
    -- 'Ideas' or 'Logs'. If you can't tell, make it a 'Log' entry." So
    -- Logs is FIRST and DEFAULT — ⇪J and ⇪pad1 file the clipboard as a
    -- Log — and Ideas is the other. Scratch is REMOVED (6.99.0 had
    -- already folded it into Ideas) and Inbox stops being offered; an
    -- old inbox.txt or scratch.txt on disk keeps its text untouched.
    qa.targets = {
        { name = "Logs",  file = "log.txt",   note = "what happened — the default" },
        { name = "Ideas", file = "ideas.txt", note = "half-formed thoughts" },
    }
    qa.defaultTarget = 1        -- index into qa.targets, used by ⇪J/⇪pad1
    qa.stamp         = true     -- write a "── 2026-08-07 20:41 ──" line first
    qa.stampFormat   = "%Y-%m-%d %H:%M"
    qa.trailingBlank = true     -- blank line after each entry
    qa.maxPreview    = 60       -- characters of the entry shown in the alert
    qa.key           = "j"
    qa.csv           = true     -- one row per append in <qa.dir>/notes.csv
    qa.csvName       = "notes.csv"
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

    -- Standard CSV quoting, the same convention chrome_history uses: a
    -- field is wrapped only when it needs to be, and a quote inside it
    -- is doubled. Newlines stay real newlines inside the quotes — that
    -- IS valid CSV, and Excel reads a quoted multi-line note correctly.
    local function csvField(s)
        s = tostring(s or "")
        if s:find('[",\n]') then s = '"' .. s:gsub('"', '""') .. '"' end
        return s
    end

    function qa.csvPath() return qa.dir .. "/" .. qa.csvName end

    -- The Note Type column holds EXACTLY two values, per the spec: Ideas
    -- or Logs — "If you can't tell, make it a 'Log' entry." Any target
    -- whose name is neither (a custom target added by hand, say) is
    -- therefore recorded as Logs rather than inventing a third type the
    -- spec forbids; its text still goes to its own file.
    function qa.noteType(name)
        if name == "Ideas" or name == "Logs" then return name end
        return "Logs"
    end

    -- 6.99.0 shipped a four-column format (date,time,category,note) that
    -- lived exactly one release. Appending three-column rows to such a
    -- file would misalign silently — every read after that lies — so an
    -- old-format file is moved whole to notes-v1.csv, once, and said so.
    -- Checked on the first append per boot, not per row.
    local csvFormatChecked = false
    local function csvEnsureFormat(path)
        if csvFormatChecked then return end
        csvFormatChecked = true
        local f = io.open(path, "r")
        if not f then return end
        local first = f:read("l") or ""
        f:close()
        if first == "date,time,category,note" then
            local moved = path:gsub("%.csv$", "") .. "-v1.csv"
            pcall(os.rename, path, moved)
            print("📝 Quick Append: notes.csv was in the one-release 6.99.0 "
                  .. "format — moved to " .. moved
                  .. "; starting fresh as Date / Note Type / Note entry")
        end
    end

    -- One row per append: | Date | Note Type | Note entry | — LL's
    -- columns, verbatim. Date carries the time too ("2026-08-18 14:32"):
    -- still ONE dated column, still sorts chronologically as text.
    -- Called only AFTER the text file took the entry — the CSV is an
    -- index of what was written, so it must never say more than the
    -- files do. Returns false rather than raising; the caller folds the
    -- failure into the alert, because a CSV that quietly stops growing
    -- is a search that quietly starts lying.
    local function csvRecord(target, text)
        if not qa.csv then return true end
        local path = qa.csvPath()
        csvEnsureFormat(path)
        local fresh = hs.fs.attributes(path) == nil
        local f = io.open(path, "a")
        if not f then
            if core.warnWriteFailed then core.warnWriteFailed("notes csv " .. path) end
            return false
        end
        local okWrite = pcall(function()
            if fresh then f:write("Date,Note Type,Note entry\n") end
            f:write(os.date("%Y-%m-%d %H:%M") .. ","
                    .. csvField(qa.noteType(target.name)) .. ","
                    .. csvField(text) .. "\n")
        end)
        local okClose = pcall(function() return f:close() end)
        return okWrite and okClose
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

        local csvOk = csvRecord(target, text)
        if not csvOk and _G.notices then
            _G.notices.record("quickAppend", "csv row failed",
                qa.csvPath() .. " — the note IS in " .. target.name
                .. "'s text file; only the searchable index missed it")
        end

        _G.diag.say("quickAppend", string.format("wrote %d chars to %s", #chunk, path))
        local msg = string.format("📝 %s ← %d line%s: %s",
            target.name, countLines(text), countLines(text) == 1 and "" or "s",
            firstWords(text, qa.maxPreview))
        if not csvOk then msg = msg .. " (⚠️ the notes.csv row was not written)" end
        return true, msg
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

    -- 👁 6.157.0 — the preview pane shows the END of the file: the last
    -- lines, read from the tail exactly as tailOf does, so a 40 MB log
    -- still costs one seek and a few KB.
    local function tailText(path, bytes)
        local f = io.open(path, "r")
        if not f then return "(empty — the first append creates it)" end
        local size = f:seek("end")
        f:seek("set", math.max(0, size - bytes))
        local blob = f:read("a") or ""
        f:close()
        if size > bytes then blob = blob:gsub("^[^\n]*\n", "", 1) end   -- drop the cut line
        blob = blob:gsub("%s+$", "")
        if blob == "" then return string.format("(%d bytes, nothing readable at the end)", size) end
        return blob
    end
    qa.tailText = tailText

    function qa.chooseTarget()
        local choices = {
            { text = "✏️  Type a line instead…",
              subText = "Opens a box; what you type is appended to the default file",
              typeIt = true },
        }
        for i, t in ipairs(qa.targets) do
            local path = qa.pathFor(t)
            table.insert(choices, {
                text    = t.name .. (i == qa.defaultTarget and "   (default)" or ""),
                subText = (t.note and (t.note .. " · ") or "") .. tailOf(path, 4096),
                index   = i,
                rawText = tailText(path, 4096),
                head    = "📝 " .. t.name .. "  ·  " .. (t.file or "") .. "  ·  the last lines",
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
        -- 👁 6.157.0 — the preview pane goes down with the picker
        pcall(function()
            chooser:hideCallback(function()
                if core.call then pcall(core.call, "preview.suspend") end
            end)
        end)
        -- 🚨 core.showPopup, NOT :show() — an unplaced picker leaves the
        -- LAST picker's coordinates standing in _G.lastPopupPlacement,
        -- and window_move computes its grab box from that record. It
        -- could not be dragged at all until 6.127.0.
        if core.showPopup then core.showPopup(chooser)
        else chooser:show() end
        if core.call then pcall(core.call, "preview.open", chooser) end
        qa.chooser = chooser   -- held: a collected chooser closes itself
        -- ⎋ 6.93.0: filed in _G.choosers so Esc closes it before the cheat sheet
        _G.choosers = _G.choosers or {}
        _G.choosers.quickAppend = chooser
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
    -- 6.99.0 — the two keyed entry points, published for the numpad
    -- layer: ⇪pad1 → the clipboard into the default file, ⇪pad3 → the
    -- clipboard into a PICKED file. The pad binds by service name so a
    -- profile without this module gets "no provider", not a dead key.
    core.provide("notes.appendClipboard", function() return qa.appendClipboard() end)
    core.provide("notes.pickTarget",      function() return qa.chooseTarget() end)

    _G.quickAppend = qa
    M.qa     = qa
    M.config = qa
end

return M
