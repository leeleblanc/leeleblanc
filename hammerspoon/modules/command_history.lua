-- =====================================================================
-- MODULE: COMMAND HISTORY (was §6.5) — ⇪H, searchable shell history, Enter copies
-- =====================================================================
-- Clipboard History for your terminal: search every command you've run
-- and press Enter to copy it back to the clipboard.
--
-- ⚠️ THIS CONFIG DOES NOT WRITE command_history.log — your shell does.
-- That means two things. First, the format is whatever your shell wrote,
-- so the parser below deliberately accepts several shapes rather than
-- assuming one (see commandHistoryParse). Second, the file is re-read
-- every time you open the picker rather than cached at boot — otherwise
-- commands run after Hammerspoon started would be invisible.
--
-- If nothing shows up, the picker tells you exactly which paths it
-- looked in instead of just showing an empty list — set
-- commandHistoryPath below to the real one and reload.
--
-- Wrapped in an immediately-invoked function, NOT a do...end block: the
-- main chunk sits at Lua's hard ceiling of 200 locals, and a do block's
-- locals still count against it. A function body gets its own budget.
-- The leading semicolon is REQUIRED, not style: without it Lua reads
-- `end)()` on the previous section followed by `(function()` here as ONE
-- expression — calling the previous section's return value with this
-- function as its argument. It compiles clean and fails at runtime with
-- "attempt to call a nil value". Every IIFE section below starts with one.

-- ⚠️ ORDERING NOTE: this module claims its key through
-- core.hyperAddShortcut, which QUEUES it for §3.12's hyperFinalize().
-- That works because §1.12 loads modules BEFORE hyperFinalize runs. If
-- the loader is ever moved earlier in init.lua, this shortcut would be
-- queued after the queue had already been drained and would silently
-- never bind — hence this note rather than a silent assumption.

-- Moved out of init.lua in 6.37.0. The code is unchanged apart from
-- taking its shared services from `core` instead of init.lua's locals.
local M = {
    name  = "Command History",
    order = 12,
    family = "find",
    cheatsheet = {
        title = "⌨️ COMMAND HISTORY",
        entries = {
            { "⇪H", "Search your shell history — Enter copies the command" },
            { "type: anything", "Matches anywhere in the command" },
            { "note", "Read from command_history.log, written by your shell" }
        },
    },
}

function M.setup(core)
    ;(function()

    -- ✏️ EDIT THIS if auto-detection doesn't find your file. nil = search
    -- the candidates below, in order, and use the first that exists.
    local commandHistoryPath = nil

    local commandHistoryCandidates = {
        core.logsDir .. "/Terminal+Ghostty/command_history.log",
        core.logsDir .. "/command_history.log",
        hs.configdir .. "/logs/Terminal+Ghostty/command_history.log",
        os.getenv("HOME") .. "/Library/CloudStorage/OneDrive-Personal/Logs/Terminal+Ghostty/command_history.log",
    }

    local commandHistoryMaxRows = 400   -- rows shown in the picker at once

    -- Never read an unbounded file on the main thread — that is precisely
    -- how the §3.7 boot beachball happened. The log only ever grows, so read
    -- at most the last 512 KB (roughly 10,000 commands). Measured: a 1.8 MB
    -- read cost ~0.26s, which is long enough to feel like a stall on a
    -- keypress; 512 KB keeps it comfortably imperceptible.
    local COMMAND_HISTORY_MAX_BYTES = 512 * 1024

    local function commandHistoryResolvePath()
        if commandHistoryPath then return commandHistoryPath end
        for _, p in ipairs(commandHistoryCandidates) do
            local f = io.open(p, "r")
            if f then f:close(); return p end
        end
        return nil
    end

    -- Accepts every common shell-history shape, because this config didn't
    -- write the file and can't dictate its format:
    --   git status                        plain
    --   : 1690000000:0;git status         zsh EXTENDED_HISTORY
    --   [2026-07-29 03:48:12] git status  bracketed timestamp
    --   2026-07-29 03:48:12  git status   plain timestamp (space or tab)
    --   2026-07-29T03:48:12Z git status   ISO timestamp
    --     42  git status                  numbered (bash history output)
    -- Returns command, timestamp-or-nil. Anything unrecognised is treated as
    -- a plain command rather than dropped — losing lines silently would be
    -- worse than showing one with no date.
    local function commandHistoryParse(line)
        local when, cmd

        -- zsh EXTENDED_HISTORY: ": <epoch>:<elapsed>;<command>"
        local epoch, rest = line:match("^:%s*(%d+):%d+;(.*)$")
        if epoch and rest then
            return rest, os.date("%Y-%m-%d %H:%M", tonumber(epoch))
        end

        -- "[2026-07-29 03:48:12] command"
        when, cmd = line:match("^%[([^%]]+)%]%s+(.*)$")
        if when and cmd ~= "" then return cmd, when end

        -- "2026-07-29 03:48:12  command" / "2026-07-29T03:48:12Z command"
        when, cmd = line:match("^(%d%d%d%d%-%d%d%-%d%d[T ]%d%d:%d%d:?%d*Z?)%s+(.*)$")
        if when and cmd ~= "" then return cmd, (when:gsub("T", " "):gsub("Z$", "")) end

        -- "  42  command" (numbered history)
        cmd = line:match("^%s*%d+%s+(.*)$")
        if cmd and cmd ~= "" then return cmd, nil end

        return line, nil
    end

    -- Newest first, consecutive duplicates collapsed. Shell history is full
    -- of the same command repeated; showing 30 identical rows would bury
    -- everything else.
    local function commandHistoryLoad()
        local path = commandHistoryResolvePath()
        if not path then return nil, nil end

        local f = io.open(path, "rb")
        if not f then return nil, path end
        local size = f:seek("end") or 0
        if size > COMMAND_HISTORY_MAX_BYTES then
            f:seek("set", size - COMMAND_HISTORY_MAX_BYTES)
            f:read("*l")   -- drop the partial line we landed in the middle of
        else
            f:seek("set", 0)
        end
        local content = f:read("*a") or ""
        f:close()

        local entries, lastCmd = {}, nil
        for line in content:gmatch("[^\r\n]+") do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed ~= "" and not trimmed:match("^#") then
                local cmd, when = commandHistoryParse(trimmed)
                cmd = cmd and cmd:match("^%s*(.-)%s*$")
                if cmd and cmd ~= "" and cmd ~= lastCmd then
                    table.insert(entries, { cmd = cmd, when = when })
                    lastCmd = cmd
                end
            end
        end

        -- Reverse in place: file order is oldest-first, the picker wants the
        -- newest thing you ran sitting at the top.
        for i = 1, #entries // 2 do
            entries[i], entries[#entries - i + 1] = entries[#entries - i + 1], entries[i]
        end
        return entries, path
    end

    _G.commandHistoryEntries = {}

    local function renderCommandHistory(query)
        local q = (query or ""):lower():match("^%s*(.-)%s*$")
        local choices = {}
        for _, e in ipairs(_G.commandHistoryEntries) do
            if q == "" or e.cmd:lower():find(q, 1, true) then
                table.insert(choices, {
                    text    = e.cmd:gsub("%s+", " "):sub(1, 160),
                    subText = e.when or "",
                    rawText = e.cmd,
                })
                if #choices >= commandHistoryMaxRows then break end
            end
        end
        if #choices == 0 then
            table.insert(choices, {
                text    = (q == "") and "No commands found"
                          or ("No matches for \"" .. q .. "\""),
                subText = "Searches every command in the log",
            })
        end
        _G.choosers.commandHistory:choices(choices)
    end

    _G.choosers.commandHistory = hs.chooser.new(function(c)
        if c and c.rawText then
            hs.pasteboard.setContents(c.rawText)
            hs.alert.show("📋 Copied command")
        end
    end)
    _G.choosers.commandHistory:placeholderText(
        "Search your shell history — Enter copies the command")
    _G.choosers.commandHistory:queryChangedCallback(function(query)
        local ok, err = pcall(renderCommandHistory, query)
        if not ok then
            print("🚨 Command History render error: " .. tostring(err))
            _G.choosers.commandHistory:choices({
                { text = "⚠️ Display error — details in Hammerspoon Console",
                  subText = tostring(err) },
            })
        end
    end)

    core.hyperAddShortcut({}, "h", function()
        local entries, path = commandHistoryLoad()
        if not path then
            -- Say WHERE we looked. An empty picker with no explanation is
            -- the thing that makes a feature feel broken rather than
            -- misconfigured.
            print("⚠️ Command History: no log found. Looked in:")
            for _, p in ipairs(commandHistoryCandidates) do print("     " .. p) end
            print("   Set commandHistoryPath in §6.5 to the real path and reload.")
            hs.alert.show("⌨️ No command_history.log found — see Console")
            return
        end
        _G.commandHistoryEntries = entries or {}
        if #_G.commandHistoryEntries == 0 then
            print("⚠️ Command History: " .. path .. " has no parseable commands.")
        end
        renderCommandHistory("")
        _G.choosers.commandHistory:query("")
        core.showPopup(_G.choosers.commandHistory)
    end, "command history")

    _G.commandHistoryLoadForTest = commandHistoryLoad
    _G.commandHistoryParseForTest = commandHistoryParse

    -- 6.89.0 — Unified Search (⇪space) reads the same log through this,
    -- so the two pickers can never disagree about what you ran.
    core.provide("commands.entries", function()
        local entries = commandHistoryLoad()
        return entries or {}
    end)

    end)() -- §6.5 Command History

    -- /////////////////////////////////////////////////
    -- /////////////////////////////////////////////////
    -- ////////////////////////////////////////////////
    -- // EXPERIMENTAL SECTION BEGIN                //
end

return M
