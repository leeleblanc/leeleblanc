-- =====================================================================
-- MODULE: TASK CREATOR — ⌃⌥⌘T create · ⇪⇧S search past · ⌃⌥⌘A format URL
-- =====================================================================
-- Moved out of init.lua in 6.98.0 (it was the unnumbered section between
-- §3.12 and §5). The code is the same code, taking its shared services
-- from `core` instead of init.lua's locals — the same move asana_comments
-- made in 6.40.0. Two real changes came along, both stated below:
--
--   1. ATTACHMENT UPLOAD no longer puts the Asana token in curl's
--      argument list (visible to `ps` for the whole upload). It now uses
--      the Capture Pad's 6.44.2 pattern: the Authorization header goes in
--      a chmod-600 file under ~/.hammerspoon/.tmp (LOCAL disk on purpose
--      — never a OneDrive folder, the token must not touch anything that
--      syncs), curl reads it with `-H @file`, and the file is deleted the
--      moment curl's callback fires. warm() sweeps leftovers from a
--      killed Hammerspoon. This was the LAST place the token appeared in
--      a process argument list.
--   2. Upload success is now verified against the real HTTP status
--      (`-w "\n%{http_code}"`), not curl's exit code — curl exits 0 on a
--      401 just as readily as on a 201, so the old check could report
--      "📎 Attachment uploaded" for an upload Asana refused.
--
-- WHAT THIS MODULE OWNS: the 30-day task history, the attachment upload,
-- the pipe parser ("Title | Desc | Assignee | /path"), the live chooser
-- renderer with inline assignee autocomplete, the draft mirror panel,
-- the one shared submit path, and the pipe chooser itself.
--
-- WHAT IT PUBLISHES (all call-time, all guarded by their consumers):
--   _G.asanaSubmitTask       — task_form.lua's ⏎ lands here
--   _G.asanaNormalizePath    — task_form.lua cleans its Attachment field
--   _G.asanaOpenTaskChooser  — ⇪⇧S, and task_form's fallbacks
--   _G.taskMirrorSync        — §1.5 nudging + window_move drag ride-along
--   _G.taskDraft             — survives the popup being dismissed any way
--   _G.asanaTaskHistory      — unified_search (⇪space) reads it
--   _G.choosers.task         — the pipe chooser
--
-- WHAT IT DELIBERATELY DOES NOT OWN: the ⇪T FORM (task_form.lua — this
-- module is the submit path and the search picker), the team roster and
-- the auto-comment service (asana_comments.lua), and the dashboard (§6).
-- A missing asana_comments must cost autocomplete and the auto-comment,
-- not task creation — every use of its surface is guarded.
-- =====================================================================

local M = {
    name  = "Task Creator",
    order = 3,
    family = "capture",
    -- No cheatsheet group of its own: the static ✅ ASANA group in
    -- core/cheatsheet.lua tells the whole Asana story in one place
    -- (⇪A · ⇪B · ⇪C · ⇪T · ⇪⇧S · ⇪L), same arrangement as asana_comments.
    config = {
        -- 💬 AUTO-COMMENT — posted on every task you create. "" disables.
        -- Read at post time, so a machine profile can override it.
        autoComment   = "Sent by Hammerspoon Task Creator \"⌃⌥⌘T\", file init.lua",
        -- Attachment uploads are bounded: a curl that never returns would
        -- otherwise hold its history row at "⏳ Posting…" forever.
        uploadTimeout = 120,
        historyDays   = 30,
    },
}

function M.setup(core)

    -- ✏️ EDIT YOUR KEYS HERE ----------------------------------------------
    -- Both are §0.4-migrated combos, so they arrive on ⇪A and ⇪T; the
    -- hyper map in init.lua owns that translation.
    local keys = {
        formatAsanaURL = { {"cmd", "ctrl", "alt"}, "A" },  -- format Asana URL
        taskCreator    = { {"ctrl", "alt", "cmd"}, "T" },  -- create a task
    }
    -- ---------------------------------------------------------------------

    -- =================================================================
    -- TASK HISTORY — Persistent 30-day store (OneDrive, machine-tagged)
    -- =================================================================
    -- 6.10.0: lives in the OneDrive Logs folder, machine-tagged (both
    -- Macs write it constantly — sharing one file would mean OneDrive
    -- conflict copies). A pre-6.10.0 file in ~/.hammerspoon is adopted
    -- on first boot; the original is left in place.
    local historyFile = core.logsDir .. "/asana_history-" .. core.hostTag .. ".json"
    core.adoptLegacyFile(historyFile, core.configDir .. "/asana_history.json")

    local function loadTaskHistory()
        local f = io.open(historyFile, "r")
        if not f then return {} end
        local content = f:read("*a"); f:close()
        local ok, data = pcall(hs.json.decode, content)
        if ok and type(data) == "table" then return data end
        return {}
    end

    local function pruneTaskHistory(history)
        local cutoff = os.time() - ((M.config.historyDays or 30) * 86400)
        local pruned = {}
        for _, entry in ipairs(history) do
            if type(entry.timestamp) == "number" and entry.timestamp >= cutoff then
                table.insert(pruned, entry)
            end
        end
        return pruned
    end

    local function saveTaskHistory(history)
        local f = io.open(historyFile, "w")
        if f then f:write(hs.json.encode(history)); f:close()
        else core.warnWriteFailed("task history") end
    end

    -- Boot: load from disk, prune old entries, sync into the global that
    -- init.lua stubbed as {} (unified_search reads it whether or not
    -- this module loaded).
    local _diskHistory = pruneTaskHistory(loadTaskHistory())
    saveTaskHistory(_diskHistory)           -- persist the pruned version immediately
    _G.asanaTaskHistory = _diskHistory

    -- =================================================================
    -- ATTACHMENT UPLOAD — multipart via curl (hs.http has no multipart)
    -- =================================================================
    -- The token, on disk only as long as one upload takes — see the
    -- header of this file. Local disk deliberately: ~/.hammerspoon is
    -- never synced anywhere, which is exactly the property secret.lua
    -- itself relies on.
    local headerDir = core.configDir .. "/.tmp"
    M.headerDir = headerDir   -- warm() sweeps it; tests reach it here

    local function writeHeaderFile()
        if hs.fs.attributes(headerDir) == nil then
            pcall(hs.fs.mkdir, headerDir)
        end
        local path = string.format("%s/hdr-%d-%04d.txt", headerDir,
            math.floor(hs.timer.secondsSinceEpoch()), math.random(0, 9999))
        local f = io.open(path, "w")
        if not f then return nil end
        local okW = pcall(function()
            f:write("Authorization: Bearer " .. core.asanaToken .. "\n")
        end)
        local okC = pcall(function() return f:close() end)
        if not (okW and okC) then pcall(os.remove, path); return nil end
        pcall(function() os.execute("chmod 600 '" .. path:gsub("'", "'\\''") .. "'") end)
        return path
    end

    local function uploadAttachmentToTask(taskId, filePath, onDone)
        -- Verify the file actually exists before attempting upload
        local testF = io.open(filePath, "r")
        if not testF then
            hs.alert.show("⚠️ Attachment not found: " .. filePath)
            if onDone then onDone(false) end
            return
        end
        testF:close()

        local hdrPath = writeHeaderFile()
        if not hdrPath then
            hs.alert.show("❌ Attachment upload failed")
            print("⚠️ Task Creator: could not stage the auth header safely — "
                  .. "attachment skipped, the file is still at " .. filePath)
            if onDone then onDone(false) end
            return
        end
        local function cleanup() pcall(os.remove, hdrPath) end

        hs.alert.show("📎 Uploading attachment…")

        local okNew, t = pcall(hs.task.new, "/usr/bin/curl", function(exitCode, stdOut, stdErr)
            cleanup()
            -- `-w "\n%{http_code}"` appends the REAL HTTP status; curl's
            -- exit code alone is 0 on a 401 just like on a 201.
            local body, status = tostring(stdOut or ""), nil
            local statusStr = body:match("(%d%d%d)%s*$")
            if statusStr then status = tonumber(statusStr) end
            local ok = (exitCode == 0) and (status == 200 or status == 201)
            if ok then
                hs.alert.show("📎 Attachment uploaded")
            else
                hs.alert.show("❌ Attachment upload failed")
                print("⚠️ Task Creator: attachment failed (curl exit "
                      .. tostring(exitCode) .. ", HTTP " .. tostring(status or "?")
                      .. ") for " .. filePath
                      .. (stdErr and #tostring(stdErr) > 0 and (" — " .. tostring(stdErr)) or ""))
            end
            if onDone then onDone(ok) end
        end, {
            "-s", "-o", "/dev/null",
            "-w", "%{http_code}",
            "--max-time", tostring(M.config.uploadTimeout or 120),
            "-X", "POST",
            "https://app.asana.com/api/1.0/tasks/" .. taskId .. "/attachments",
            "-H", "@" .. hdrPath,
            "-F", "file=@" .. filePath
        })
        if not (okNew and t) then
            cleanup()
            hs.alert.show("❌ Attachment upload failed")
            print("⚠️ Task Creator: could not start curl for " .. filePath)
            if onDone then onDone(false) end
            return
        end
        pcall(function() t:start() end)
    end

    -- =================================================================
    -- PIPE PARSER — splits "Title | Desc | Assignee | /path/to/file"
    --   • All fields after Title are optional
    --   • Assignee can be a GID (numeric) or an email address
    -- =================================================================

    -- Split on "|" while PRESERVING empty fields, so "time | | | /path"
    -- and even "time|||/path" (no spaces) both land the path in field #4.
    local function splitPipes(raw)
        local parts, start = {}, 1
        while true do
            local sep = raw:find("|", start, true)
            if sep then
                table.insert(parts, raw:sub(start, sep - 1):match("^%s*(.-)%s*$"))
                start = sep + 1
            else
                table.insert(parts, raw:sub(start):match("^%s*(.-)%s*$"))
                break
            end
        end
        return parts
    end

    -- Clean up a pasted attachment path so small slips still work:
    --   • strips surrounding single/double quotes
    --   • expands  ~  and  ~/…  to your home folder
    --   • snaps to the first "/" so stray leading junk (e.g. "r /Users/…")
    --     is dropped and the path starts where the real path starts
    local function normalizeAttachmentPath(raw)
        if not raw or raw == "" then return "" end
        local s = raw:match("^%s*(.-)%s*$")             -- trim ends
        s = s:gsub("^[\"']", ""):gsub("[\"']$", "")     -- strip wrapping quotes
        s = s:match("^%s*(.-)%s*$")                      -- trim again (quotes may have hidden spaces)

        -- Expand ~ BEFORE looking for the first slash
        if s == "~" then
            s = core.homeDir
        elseif s:sub(1, 2) == "~/" then
            s = core.homeDir .. s:sub(2)
        end

        -- If anything precedes the first "/", drop it. Absolute paths
        -- start at "/", so "r /Users/…" and "  /Users/…" both become
        -- "/Users/…".
        local slashIdx = s:find("/", 1, true)
        if slashIdx and slashIdx > 1 then
            s = s:sub(slashIdx)
        end

        return s
    end

    local function parseTaskInput(raw)
        local parts = splitPipes(raw)
        return {
            title      = parts[1] or "",
            desc       = parts[2] or "",
            assignee   = parts[3] or "",
            attachment = normalizeAttachmentPath(parts[4] or ""),
        }
    end

    -- =================================================================
    -- CHOOSER RENDERER — live preview while typing
    -- =================================================================
    local function renderTaskChoices(query)
        local choices = {}
        local searchKey = ""

        if query and #query > 0 then
            local p = parseTaskInput(query)
            searchKey = p.title:lower()

            -- 6.16.13: INLINE ASSIGNEE AUTOCOMPLETE — while the cursor is
            -- still IN the Assignee segment (title | desc | <here>, i.e.
            -- exactly two pipes typed so far and no third one yet — a
            -- completed 3rd pipe means you've moved on to the attachment
            -- field), matching names from the ⌃⌥⌘B team roster show as
            -- suggestions right here. Picking one splices the exact name
            -- into the query and reopens (see the chooser callback below).
            -- `or {}`: the roster belongs to asana_comments — a profile
            -- without that module must cost autocomplete, not the picker.
            local pipeCount = select(2, query:gsub("|", "|"))
            if pipeCount == 2 and p.assignee ~= "" then
                local partial = p.assignee:lower()
                local shown = 0
                for _, m in ipairs(_G.asanaTeamMembers or {}) do
                    if m.name:lower():find(partial, 1, true) then
                        table.insert(choices, {
                            text                  = "👤 " .. m.name,
                            subText               = (m.email or "") .. "  ·  Enter fills the Assignee field",
                            isAssigneeSuggestion  = true,
                            memberName            = m.name,
                        })
                        shown = shown + 1
                        if shown >= 8 then break end
                    end
                end
                -- 6.16.14 FIX: zero matches showed NOTHING here —
                -- indistinguishable from the feature not working at all.
                -- isHistory=true makes Enter on this row a safe no-op, so
                -- it can't get submitted as a fake assignee.
                if shown == 0 then
                    table.insert(choices, {
                        text      = "👤 No team member matches \"" .. p.assignee .. "\"",
                        subText   = "Keep typing, or use their exact email instead",
                        isHistory = true,
                    })
                end
            end

            -- Build a compact summary line for the subText
            local hints = {}
            if p.desc      ~= "" then table.insert(hints, "📝 " .. p.desc:sub(1, 40)) end
            if p.assignee  ~= "" then table.insert(hints, "👤 " .. p.assignee) end
            if p.attachment~= "" then table.insert(hints, "📎 " .. (p.attachment:match("[^/]+$") or p.attachment)) end  -- folder paths (trailing /) have no basename → show the path itself
            local subTextMsg = #hints > 0 and table.concat(hints, "  ·  ") or "Press Enter to create…"

            table.insert(choices, {
                text       = "➕ Create: " .. (p.title ~= "" and p.title or "…"),
                subText    = subTextMsg,
                isAction   = true,
                rawTitle   = p.title,
                rawDesc    = p.desc,
                rawAssignee= p.assignee,
                rawAttach  = p.attachment,
            })
        end

        -- Append persisted history (newest first), FILTERED against
        -- searchKey. Matches against title, description, and assignee so
        -- you can search by any of those; empty searchKey (nothing
        -- typed) shows everything.
        local matchCount = 0
        if #_G.asanaTaskHistory > 0 then
            for i = #_G.asanaTaskHistory, 1, -1 do
                local e = _G.asanaTaskHistory[i]
                local haystack = ((e.title or "") .. " " .. (e.desc or "") .. " " .. (e.assignee or "")):lower()
                if searchKey == "" or haystack:find(searchKey, 1, true) then
                    matchCount = matchCount + 1
                    table.insert(choices, {
                        text    = e.title or "(untitled)",
                        subText = e.displaySub or "",
                        -- history rows are read-only; Enter on them is a no-op
                        isHistory = true,
                    })
                end
            end
        end

        if #_G.asanaTaskHistory == 0 and (not query or #query == 0) then
            table.insert(choices, {
                text    = "Type a task name…",
                subText = "Format: Title | Description | Assignee | /path/to/attachment"
            })
        elseif searchKey ~= "" and matchCount == 0 then
            table.insert(choices, {
                text      = "No matching past tasks",
                subText   = "Searched title, description & assignee for \"" .. searchKey .. "\"",
                isHistory = true,
            })
        end

        _G.choosers.task:choices(choices)
    end

    -- =================================================================
    -- DRAFT MIRROR — full wrapped view of what you're typing (6.10.2)
    -- =================================================================
    -- HONEST LIMIT this works around: hs.chooser's search field is a
    -- native macOS single-line input — there is no API to make the field
    -- itself wrap, so a long title scrolls out of view inside it. This
    -- companion hs.canvas panel (same tech + placement as the dashboard's
    -- legend strip, init.lua §6) sits just above the picker and mirrors
    -- the ENTIRE text, word-wrapped, live with every keystroke. Up to 8
    -- lines tall; appears the moment the box has text, vanishes when it's
    -- empty or the popup resolves, and rides along with ⌃⌥⌘-arrow nudges.
    _G.taskMirrorCanvas = nil

    local function taskMirrorHide()
        if _G.taskMirrorCanvas then
            pcall(function() _G.taskMirrorCanvas:delete() end)
            _G.taskMirrorCanvas = nil
        end
    end

    local function taskMirrorShow(text)
        taskMirrorHide()
        if not text or text == "" then return end
        local chooser = _G.choosers.task
        if not chooser then return end
        local visible = false
        pcall(function() visible = chooser:isVisible() end)
        if not visible then return end

        -- Reuse the exact placement showPopup recorded for the picker —
        -- same reasoning as the legend strip (§6): resolving the screen
        -- again could disagree and draw the mirror on the wrong monitor.
        local place = _G.lastPopupPlacement
        local screen = (place and place.screen) or core.resolveBaseScreen()
        local sf = screen:frame()
        local topLeft = (place and place.point) or core.chooserTopLeft(chooser, screen)
        local pct = 40
        local okW, w = pcall(function() return chooser:width() end)
        if okW and type(w) == "number" and w > 0 and w <= 100 then pct = w end
        local panelW = sf.w * (pct / 100)

        -- Height: estimate wrapped line count from average glyph width.
        -- The canvas wraps the text itself (textLineBreak below) — this
        -- estimate only sizes the panel, so being a little off is fine.
        local textSize, pad, maxLines = 16, 12, 8
        local charsPerLine = math.max(10, math.floor((panelW - pad * 2) / (textSize * 0.55)))
        local lines = math.min(maxLines, math.max(1, math.ceil(#text / charsPerLine)))
        local lineH = textSize + 6
        local panelH = pad * 2 + lines * lineH

        -- Just above the picker's search field, clamped on-screen — the
        -- same exact-placement trick the legend uses (§6): the picker's
        -- top-left is a position we set ourselves, so no estimation.
        local panelY = math.max(sf.y + 4, topLeft.y - panelH - 8)

        local canvas = hs.canvas.new({ x = topLeft.x, y = panelY, w = panelW, h = panelH })
        if not canvas then return end

        local sty = _G.uiStyle or {}   -- 🎨 6.90.0 shared card look
        canvas:appendElements({
            {
                type = "rectangle", action = "fill",
                fillColor = (sty.bgWith and sty.bgWith(core.panelAlpha))
                            or { red = 0.11, green = 0.11, blue = 0.13, alpha = core.panelAlpha },
                roundedRectRadii = { xRadius = 12, yRadius = 12 },
            },
            {
                type = "text", text = text,
                textSize = textSize, textColor = sty.fg or { white = 0.95 },
                textLineBreak = "wordWrap",
                frame = { x = pad, y = pad, w = panelW - pad * 2, h = panelH - pad * 2 },
            },
        })
        -- 6.148.0 — the coexist ladder, not a bare `overlay` that tied
        -- with the cheat sheet
        pcall(function()
            canvas:level((_G.panelLevel and _G.panelLevel("taskcreator"))
                         or hs.canvas.windowLevels.overlay)
        end)
        -- Same Spaces/full-screen visibility declarations as the legend
        -- and cheat sheet — without them the mirror can't appear over
        -- native full-screen apps
        pcall(function() canvas:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
        _G.showCanvasSafely(canvas, "popup panel")
        _G.taskMirrorCanvas = canvas
    end

    -- Nudging (⌃⌥⌘ arrows) repositions the picker — §1.5 calls this so
    -- the mirror rides along, exactly like the dashboard legend does.
    _G.taskMirrorSync = function()
        if _G.taskMirrorCanvas then taskMirrorShow(_G.taskDraft or "") end
    end

    -- =================================================================
    -- PROJECT CUSTOM FIELDS (6.152.0) — fetched, never hard-coded
    -- =================================================================
    -- LL: "Can we add the metadata fields I'd like to include?" — ACD
    -- Strategic Principle, SAC Values, Task Priority, Progress,
    -- Supervisor… Those are the PROJECT'S custom fields, and their GIDs
    -- and option lists belong to Asana, not to this file: hard-coding
    -- them would break the day anyone edits a dropdown in Asana. So the
    -- project's custom_field_settings are fetched once per boot (warm),
    -- cached in _G.asanaCustomFields, and the ⇪T form builds its
    -- dropdowns from whatever came back — a field added in Asana appears
    -- on the next reload with zero code changes.
    _G.asanaCustomFields = _G.asanaCustomFields or {}
    function M.fetchCustomFields()
        if not (core.asanaToken and core.asanaToken ~= ""
                and core.asanaProjectId) then return end
        local url = "https://app.asana.com/api/1.0/projects/"
            .. core.asanaProjectId
            .. "/custom_field_settings?opt_fields=custom_field.gid,"
            .. "custom_field.name,custom_field.resource_subtype,"
            .. "custom_field.enum_options.gid,custom_field.enum_options.name,"
            .. "custom_field.enum_options.enabled"
        pcall(function()
            hs.http.asyncGet(url,
                { ["Authorization"] = "Bearer " .. core.asanaToken },
                function(status, body)
                    if status ~= 200 then
                        print("✅ Task Creator: could not fetch the project's "
                              .. "custom fields (HTTP " .. tostring(status)
                              .. ") — ⇪T shows the basic fields only")
                        return
                    end
                    local parsed = core.safeJson(body, "asana/customfields")
                    local list = {}
                    for _, s in ipairs((parsed and parsed.data) or {}) do
                        local f = s.custom_field
                        if type(f) == "table" and f.gid and f.name then
                            local opts = {}
                            for _, o in ipairs(f.enum_options or {}) do
                                if o.enabled ~= false and o.gid and o.name then
                                    opts[#opts + 1] = { gid = o.gid, name = o.name }
                                end
                            end
                            list[#list + 1] = {
                                gid = f.gid, name = f.name,
                                subtype = f.resource_subtype or "text",
                                options = opts,
                            }
                        end
                    end
                    _G.asanaCustomFields = list
                    if _G.diag then
                        _G.diag.say("taskCreator",
                            "fetched " .. #list .. " project custom fields")
                    end
                end)
        end)
    end

    -- =================================================================
    -- TASK SUBMIT — shared by the chooser below AND the Task Form (6.86.0)
    -- =================================================================
    -- One submit path so the two front ends cannot drift.
    -- Returns TRUE = accepted for posting; FALSE = validation failed,
    -- AFTER alerting — callers keep their draft on false.
    -- 6.152.0 — `extra` (optional, the ⇪T form's Details section):
    --   { startDate/startTime/dueDate/dueTime = "YYYY-MM-DD"/"HH:MM",
    --     custom = { [field gid] = value } }
    -- The pipe chooser passes nothing and keeps its old four-string call.
    function _G.asanaSubmitTask(title, desc, assignee, attach, extra)
        title, desc     = title or "", desc or ""
        assignee, attach = assignee or "", attach or ""
        extra = (type(extra) == "table") and extra or {}

        if title == "" then
            hs.alert.show("⚠️ Task title cannot be empty")
            return false
        end

        -- Build display summary for history subText
        local subParts = {}
        if desc     ~= "" then table.insert(subParts, "📝 " .. desc:sub(1, 35)) end
        if assignee ~= "" then table.insert(subParts, "👤 " .. assignee) end
        if attach   ~= "" then table.insert(subParts, "📎 " .. (attach:match("[^/]+$") or attach)) end

        -- Asana's API rejects a display name outright (the actual bug:
        -- "Not a valid actor ID: Lee") — assignee must be "me", a
        -- numeric GID, or an email. Resolve a typed name against the
        -- cached team roster (asana_comments) before it ever reaches the
        -- API; an unresolvable name ABORTS instead of sending a doomed
        -- request, so the failure is a clear alert, not a Console error.
        local function resolveAssignee(raw)
            if raw == "" then return "" end
            local lower = raw:lower()
            if lower == "me" or lower == "myself" or lower == "i" then return "me" end
            -- 6.16.14 FIX: real Asana GIDs are long (15+ digits) — a
            -- short digit string like "1" isn't one, but ^%d+$ blindly
            -- accepted it and sent it straight to the API unchecked.
            -- Require 6+ digits before trusting it.
            if raw:match("^%d%d%d%d%d%d+$") then return raw end          -- already a GID
            if raw:match("^[%w.+-]+@[%w.-]+%.%a+$") then return raw end  -- email
            for _, m in ipairs(_G.asanaTeamMembers or {}) do
                if m.name:lower() == lower then return m.gid end
            end
            for _, m in ipairs(_G.asanaTeamMembers or {}) do
                if m.name:lower():find(lower, 1, true) then return m.gid end
            end
            return nil
        end

        local resolvedAssignee = resolveAssignee(assignee)
        if assignee ~= "" and not resolvedAssignee then
            hs.alert.show("⚠️ No team member matches \"" .. assignee
                .. "\" — ⌃⌥⌘B to browse names, or use their email", 5)
            return false
        end

        -- Create history entry (timestamp used for 30-day pruning)
        local historyEntry = {
            title      = title,
            timestamp  = os.time(),
            displaySub = "⏳ Posting…" .. (#subParts > 0 and "  ·  " .. table.concat(subParts, "  ·  ") or ""),
            desc       = desc,
            assignee   = assignee,
            attachment = attach,
        }
        table.insert(_G.asanaTaskHistory, historyEntry)

        -- ---- the schedule (6.152.0, all four fields optional) -----------
        -- Asana's own rules, enforced BEFORE the request so a doomed one
        -- is a clear alert, not a Console 400: a start needs an end, a
        -- time needs its date, and when both ends carry dates the times
        -- come as a pair or not at all (start_at cannot ride with due_on).
        local sd = tostring(extra.startDate or "")
        local st = tostring(extra.startTime or "")
        local ed = tostring(extra.dueDate or "")
        local et = tostring(extra.dueTime or "")
        if (st ~= "" and sd == "") or (et ~= "" and ed == "") then
            hs.alert.show("⚠️ A time needs its date — fill the date beside it", 5)
            return false
        end
        if sd ~= "" and ed == "" then
            hs.alert.show("⚠️ Asana requires an END date whenever a start "
                          .. "date is set — fill End, or clear Start", 6)
            return false
        end
        if sd ~= "" and ed ~= "" and ((st == "") ~= (et == "")) then
            hs.alert.show("⚠️ With both dates set, give BOTH times or "
                          .. "neither — Asana cannot mix a timed end with "
                          .. "an all-day start", 6)
            return false
        end
        -- "2026-09-04T14:30:00-05:00" — local offset, spelled ±hh:mm
        local function isoAt(d, t)
            local off = os.date("%z"):gsub("^([%+%-]%d%d)(%d%d)$", "%1:%2")
            return d .. "T" .. t .. ":00" .. off
        end

        -- ---- the custom fields (6.152.0) ---------------------------------
        -- Values arrive keyed by field gid; the field's SUBTYPE (from the
        -- fetched cache) decides the API shape: enum = option gid,
        -- multi_enum = array of option gids, people = array of user gids
        -- (a typed name resolves through the same roster as Assignee),
        -- number = a number, text = the string.
        local fieldMeta = {}
        for _, f in ipairs(_G.asanaCustomFields or {}) do fieldMeta[f.gid] = f end
        local customOut, customAny = {}, false
        for gid, v in pairs(extra.custom or {}) do
            local sub = (fieldMeta[gid] and fieldMeta[gid].subtype) or "text"
            if type(v) == "table" then
                if #v > 0 then customOut[gid] = v ; customAny = true end
            elseif tostring(v) ~= "" then
                v = tostring(v)
                if sub == "people" then
                    local g = resolveAssignee(v)
                    if not g then
                        hs.alert.show("⚠️ No team member matches \"" .. v
                            .. "\" for " .. (fieldMeta[gid].name or "a people field")
                            .. " — use their exact name or email", 6)
                        return false
                    end
                    customOut[gid] = { g }
                elseif sub == "number" then
                    customOut[gid] = tonumber(v) or v
                else
                    customOut[gid] = v      -- enum option gid, or plain text
                end
                customAny = true
            end
        end

        -- Build Asana task payload
        local payloadData = { name = title, projects = { core.asanaProjectId } }
        if desc ~= "" then payloadData.notes = desc end
        if resolvedAssignee ~= "" then payloadData.assignee = resolvedAssignee end
        if ed ~= "" then
            if et ~= "" then payloadData.due_at = isoAt(ed, et)
            else payloadData.due_on = ed end
        end
        if sd ~= "" then
            if st ~= "" then payloadData.start_at = isoAt(sd, st)
            else payloadData.start_on = sd end
        end
        if customAny then payloadData.custom_fields = customOut end
        local body = hs.json.encode({ data = payloadData })

        hs.http.asyncPost("https://app.asana.com/api/1.0/tasks", body, {
            ["Authorization"] = "Bearer " .. core.asanaToken,
            ["Content-Type"]  = "application/json"
        }, function(status, responseBody)
            if status == 200 or status == 201 then
                hs.alert.show("✅ Task Created: " .. title)
                historyEntry.displaySub = "✅ " .. os.date("%b %d %H:%M") ..
                    (#subParts > 0 and "  ·  " .. table.concat(subParts, "  ·  ") or "")

                -- Parse the new task's GID once — comments & attachments
                local parsed  = core.safeJson(responseBody, "asana/newtask")
                local taskGid = parsed and parsed.data and parsed.data.gid

                if taskGid then
                    -- 💬 Auto-comment (M.config.autoComment; "" disables)
                    local autoComment = M.config.autoComment or ""
                    if autoComment ~= "" then
                        core.call("asana.addComment", taskGid, autoComment)
                    end

                    -- 📎 Attachment upload
                    if attach ~= "" then
                        uploadAttachmentToTask(taskGid, attach, function(ok)
                            if ok then
                                historyEntry.displaySub = historyEntry.displaySub .. "  ·  📎 attached"
                            else
                                historyEntry.displaySub = historyEntry.displaySub .. "  ·  ⚠️ attach failed"
                            end
                            saveTaskHistory(_G.asanaTaskHistory)
                        end)
                    end
                elseif attach ~= "" then
                    hs.alert.show("⚠️ Could not parse task GID for attachment")
                end
            else
                hs.alert.show("❌ Error: " .. tostring(status))
                print("Asana API Error: ", responseBody)
                historyEntry.displaySub = "❌ Failed (HTTP " .. tostring(status) .. ")" ..
                    (#subParts > 0 and "  ·  " .. table.concat(subParts, "  ·  ") or "")
            end

            -- Always persist history after any outcome (including non-attachment path)
            if attach == "" then saveTaskHistory(_G.asanaTaskHistory) end
        end)

        return true
    end

    -- Published for task_form.lua: its Attachment field gets the same
    -- path cleanup the pipe picker's 4th segment gets (quotes, ~, junk).
    _G.asanaNormalizePath = normalizeAttachmentPath

    -- =================================================================
    -- TASK CHOOSER
    -- =================================================================
    _G.choosers.task = hs.chooser.new(function(choice)
        -- History rows are read-only; ignore selection
        if not choice or choice.isHistory then taskMirrorHide(); return end

        -- Picking an inline assignee suggestion is an AUTOCOMPLETE, not
        -- a submit: splice the exact name into the Assignee segment and
        -- reopen with it, same as the draft-restore reopen below — Enter
        -- here should never create the task.
        if choice.isAssigneeSuggestion then
            local parts = splitPipes(_G.taskDraft or "")
            parts[3] = choice.memberName
            local rebuilt = (parts[1] or "") .. " | " .. (parts[2] or "") .. " | " .. parts[3]
                .. (parts[4] and (" | " .. parts[4]) or " | ")
            _G.taskDraft = rebuilt
            _G.choosers.task:query(rebuilt)
            renderTaskChoices(rebuilt)  -- explicit: programmatic query() doesn't re-fire the callback
            core.showPopup(_G.choosers.task)
            pcall(taskMirrorShow, rebuilt)
            return
        end

        taskMirrorHide()   -- popup resolved (pick / Esc / click away)

        if choice.isAction then
            -- 6.86.0: submission lives WHOLE in _G.asanaSubmitTask above.
            -- false = validation failed (already alerted), draft
            -- survives; true = posted, draft's job is done.
            if _G.asanaSubmitTask(choice.rawTitle, choice.rawDesc,
                                  choice.rawAssignee, choice.rawAttach) then
                _G.taskDraft = ""
                _G.choosers.task:query("")
            end
        end
    end):placeholderText("Title | Description | Assignee | /path/to/attachment")

    -- 6.10.2: wider box — 60% of the screen instead of hs.chooser's 40%
    -- default, so much more of a long title stays visible before the
    -- field starts scrolling. Edit the number freely (10–100); the
    -- draft mirror and centering adapt automatically.
    pcall(function() _G.choosers.task:width(60) end)

    -- DRAFT PERSISTENCE (6.10.1): every keystroke in the box is mirrored
    -- into _G.taskDraft, so the text survives the popup being dismissed
    -- ANY way (click away, Esc, accidental Enter on a read-only history
    -- row) — the ⌃⌥⌘T binding below restores it on reopen. Cleared only
    -- on successful task creation, or by deleting the text yourself.
    -- In-memory (like window prior-positions): a reload starts fresh.
    _G.taskDraft = ""

    -- Armored: if rendering ever errors again, show the error IN the
    -- chooser instead of a silent blank window (which is what an error
    -- inside a queryChangedCallback otherwise produces).
    _G.choosers.task:queryChangedCallback(function(query)
        _G.taskDraft = query or ""
        pcall(taskMirrorShow, _G.taskDraft)   -- live wrapped mirror (6.10.2)
        local ok, err = pcall(renderTaskChoices, query)
        if not ok then
            print("🚨 Task chooser render error: " .. tostring(err))
            _G.choosers.task:choices({
                { text = "⚠️ Display error — details in Hammerspoon Console", subText = tostring(err), isHistory = true },
            })
        end
    end)

    -- =================================================================
    -- HOTKEYS — all three went through init.lua §5 before 6.98.0
    -- =================================================================

    -- Format Asana URL from clipboard (⌃⌥⌘A → arrives as ⇪A)
    hs.hotkey.bind(keys.formatAsanaURL[1], keys.formatAsanaURL[2], function()
        if not core.requireAsana() then return end
        local url = hs.pasteboard.readString()
        if url and url:match("asana%.com") then
            local id = url:match(".*/(%d+)")
            if id then
                hs.http.asyncGet("https://app.asana.com/api/1.0/tasks/" .. id,
                    { ["Authorization"] = "Bearer " .. core.asanaToken },
                    function(s, b)
                        if s == 200 then
                            local taskData = core.safeJson(b, "asana/task")
                            if taskData and taskData.data and taskData.data.name then
                                hs.pasteboard.setContents(taskData.data.name .. " | " .. url)
                                hs.alert.show("✅ Formatted")
                            else
                                hs.alert.show("❌ Failed to parse task name")
                            end
                        else
                            hs.alert.show("❌ API Error: " .. tostring(s))
                        end
                    end)
            else
                hs.alert.show("❌ No Task ID found in URL")
            end
        else
            hs.alert.show("❌ Clipboard does not contain an Asana URL")
        end
    end)

    -- The pipe chooser, openable by name — reopens with the unsent DRAFT
    -- (6.10.1). Used by ⇪⇧S, ⇪T's and task_form's fallbacks.
    _G.asanaOpenTaskChooser = function()
        local draft = _G.taskDraft or ""
        _G.choosers.task:query(draft)
        renderTaskChoices(draft)  -- render explicitly; programmatic query() alone isn't guaranteed to re-fire the callback
        core.showPopup(_G.choosers.task)
        if draft ~= "" then
            hs.alert.show("📝 Draft restored — keep typing, or delete it to start fresh")
            pcall(taskMirrorShow, draft)   -- mirror needs the popup visible, so after showPopup
        end
    end

    -- Task creator — 6.86.0: ⇪T = the labeled FORM; pipe chooser = fallback.
    hs.hotkey.bind(keys.taskCreator[1], keys.taskCreator[2], function()
        if not core.requireAsana() then return end
        if _G.taskFormShow then _G.taskFormShow() return end
        _G.asanaOpenTaskChooser()
    end)

    -- 6.86.0: past-task SEARCH on ⇪⇧S (⇪⇧T was the Text Expander's).
    core.hyperAddShortcut({ "shift" }, "s", function()
        if not core.requireAsana() then return end
        _G.asanaOpenTaskChooser()
    end, "task search — past Asana tasks")

end

function M.warm(core)
    -- 6.152.0 — the ⇪T form's dropdowns: fetch the project's custom
    -- fields once per boot. Async, pcall'd inside — a Mac with no token
    -- or no network costs the Details section, never the boot.
    if M.fetchCustomFields then pcall(M.fetchCustomFields) end
    -- Sweep any auth-header file a killed Hammerspoon left behind.
    -- Normally uploadAttachmentToTask deletes its own the moment curl's
    -- callback fires, but a crash or force-quit mid-upload skips that —
    -- and a file holding a bearer token should not outlive the process
    -- that needed it. Same sweep the Capture Pad runs on ITS folder.
    local dir = M.headerDir
    if not dir then return end
    local swept = 0
    if hs.fs.attributes(dir) ~= nil then
        local okDir, iter, dirObj = pcall(hs.fs.dir, dir)
        if okDir and iter then
            local stale = {}
            for entry in iter, dirObj do
                if entry:match("^hdr%-.*%.txt$") then
                    table.insert(stale, dir .. "/" .. entry)
                end
            end
            -- Collected first, deleted second: removing entries while the
            -- directory iterator is still walking it is undefined behaviour.
            for _, p in ipairs(stale) do
                if pcall(os.remove, p) then swept = swept + 1 end
            end
        end
    end
    if swept > 0 then
        print("✅ Task Creator: cleared " .. swept ..
              " leftover auth-header file(s) from an interrupted upload")
    end
end

return M
