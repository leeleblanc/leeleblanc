-- =====================================================================
-- 📝 SCORP PAD — ⇪1: TABS, SAVED AS YOU TYPE, A HISTORY YOU CAN SEARCH
-- =====================================================================
-- 6.164.0 — LL: "I use the Sublime text editor to hold snippets of text
-- or code or anything you can think of as a scratch space. But it's
-- overkill. What I need is a very simple text editor that I can quickly
-- bring up using the shortcut key, type into it, have it automatically
-- saved so I don't lose any of that data, write that data to a
-- searchable database, be able to close it as fast as I can open it …
-- a running history under the main text editor area … open tabs as I
-- need more scratch space … automatically save every few milliseconds
-- … at the end of my workday, 4 PM, an Asana task should be created with
-- the contents … start time of 7:30 AM and an end time of 4 PM, make me
-- the assignee, post to my personal Asana project like any other task …
-- this tool must not lock up my keyboard or the operating system and
-- should degrade gracefully."
--
-- WHAT IT IS. One borderless webview (the Capture Pad / Task Form
-- recipe: allowTextEntry, read-back-verified non-activating mask, held
-- usercontent port, Lua-driven header drag). Inside it: a tab bar, a
-- textarea, and under the textarea a HISTORY strip — every tab you
-- closed, newest first, with a filter box. Click a history row and it
-- comes back as a tab.
--
-- WHERE THE TEXT LIVES. Three places, in this order of truth:
--   1. sp.tabs in Lua — updated on EVERY keystroke (the page posts the
--      whole textarea on each input event; the bridge is cheap and the
--      draft can never be newer than Lua's copy by more than one key).
--   2. <logsDir>/scratch/scratch.json — written sp.saveDelay seconds
--      after the last keystroke (a held hs.timer.doAfter, re-armed per
--      key), and at once on close, tab close, restore and the 4 PM send.
--      "Every few milliseconds" is met by (1); (2) keeps a plist-storm
--      off the disk — the same lesson as unified search's position key.
--   3. ⇪space — unified_search reads sp.tabs and sp.history live, so the
--      whole store is searchable from the one search everything uses.
--
-- 4 PM. sp.send() builds ONE task for the day: every open tab with text
-- under its title, then anything closed today. start 07:30 · due 16:00
-- (both on today), assignee "me", the personal project — all through
-- _G.asanaSubmitTask, the single submit path the ⇪T form uses, so this
-- module owns no Asana request of its own. The identifying comment goes
-- through the same auto-comment hook (extra.comment, 6.164.0). A day
-- with no text, or whose text has not changed since the last send, is
-- skipped and says so in the Console.
--
-- 🗒 ⇪N AND ⇪2 OPEN HERE (6.165.0). LL: "Could I just add these to my
-- new tool? That way I am only opening one text edit tool." The Capture
-- Pad and the Quick Append Pad keep their brains (queue, router, 16:00
-- flush, 16:01 review, services); this pad is their window. ⇪N opens a
-- 🗒 Capture tab, and ⇪2 opened a ➕ Append tab until 6.182.0 took that
-- key for the sequential copy (the Append tab is a row in the vault's
-- 📝 SCRATCH NOTES now). One of each at a time. Closing
-- such a tab — ⌘W, its ×, or closing the pad — FILES its text where the
-- old pad did: capturePad.add (the 4 PM Asana queue) or notePad.fileAll
-- (* idea · + log · ! task · ? note). Failure keeps the tab and the
-- text, exactly as the old pads kept their draft. Those tabs are NOT
-- part of this pad's own 4 PM task — they have their own destinations.
-- pad.viaScratch / np.viaScratch = false in a profile restores the old
-- windows. ⇪⇧N (send now), ⇪pad2/⇪pad*/⇪pad- and the 16:01 review are
-- untouched.
--
-- 📌 PIN. The header's pin keeps the pad up while you work in the app
-- beside it: Esc no longer closes it (it only returns the keyboard),
-- and it stays on every Space above the app. ⇪1 and ✕ always close.
-- No window is tracked, no Accessibility is read: nothing here can stall.
--
-- 🕸 ONE WINDOW WITH THE VAULT (6.173.0). LL: "Can I combine my Scorp
-- Pad and this Vault Pad?" Yes: ⇪1 and ⇪3 now open the SAME window —
-- the Vault's (modules/vault.lua). Its note list carries a 📝 SCRATCH
-- section at the top with every tab here (Capture / Append tabs too),
-- its text box edits them, and closed tabs sit under HISTORY on the
-- right. This module keeps its brains: sp.tabs, the store, the history,
-- the filing of kind tabs and the 4 PM task are all still here — the
-- vault is only the window (sp.host()). `sp.viaVault = false` in a
-- profile, or a Mac without the vault module, brings this module's own
-- window back, unchanged.
--
-- 🚨 WHAT THIS MODULE DELIBERATELY DOES NOT DO. No eventtap (the page's
-- own keydown handles ⌘T/⌘W/⌘1–9/Esc, so nothing can swallow a key
-- system-wide). No AX or window-object reads. No timer that is not held. No
-- write bigger than the store, and that store is registered with the
-- write ledger. Without a webview it falls back to hs.dialog and still
-- saves. Without Asana it still saves — the 4 PM send says "Asana is
-- off on this Mac" and keeps everything.
-- =====================================================================

local M = {
    name    = "Scorp Pad",
    order   = 13.37,
    family  = "capture",
    summary = "⇪1 a scratch editor: tabs, saved as you type, a searchable "
              .. "history under the text, one Asana task of the day at 4 PM",
    cheatsheet = {
        title = "📝 SCRATCH NOTES (⇪N — type, it saves; close as fast as you opened it)",
        entries = {
            { "⇪N",        "Open the pad — inside the ⇪3 Vault window, on your SCRATCH NOTES (again closes). ⇪1 no longer opens it and is free" },
            { "⌘T · ⌘W",   "New tab · close tab (its text goes to the history)" },
            { "⌘1…⌘9",     "Switch tab · ⌃Tab / ⌃⇧Tab cycle round them" },
            { "history",   "Right pane (in the vault): every closed tab, click to reopen" },
            { "📌",        "Pin: stays up beside the app; Esc only hands the keys back" },
            { "+ 🗒 · + ➕", "New Capture / Append tabs are rows in the section now, not their own keys; ⌘W still files each where it always went" },
            { "⇪2",        "SEQUENTIAL COPY: select text, press it, select more, press again — the grabs join into ONE block on the clipboard, so ⌘V pastes the lot. Copying anything else starts a new sequence. Nothing is filed into the pad" },
            { "16:00",     "One Asana task of the day: every tab, 07:30 → 16:00, you" },
            { "search",    "⇪space finds everything in the pad — tabs and history" },
            { "own window","settings = { scratch_pad = { viaVault = false } } brings the old window back" },
            { "⌘⇧S",       "Export every tab to <Vault>/Scratch as .md — Obsidian opens them" },
            { "Console",   "_G.scratchPadReport() · _G.scratchPadSend() · _G.scorpPadExport()" },
        },
    },
}

function M.setup(core)
    local sp = {
        enabled       = true,
        -- 🔑 6.182.0 — ⇪N, was ⇪1. LL: "I think hyper+N is enough to open
        -- the Scorp Pad. Do you?" He is right: FOUR keys reached this one
        -- window (⇪1 the pad, ⇪N a Capture tab, ⇪2 an Append tab, ⇪3 the
        -- vault side of it), which is three doors too many into a room
        -- you are already in. ⇪N is the door now, ⇪3 still opens the
        -- vault side, ⇪2 became the sequential copy, and ⇪1 IS FREE — do
        -- not spend it without LL.
        key           = "n",
        width         = 768,
        height        = 1024,
        alpha         = 1,        -- 6.172.1 — SOLID (LL: 0.95 was still not opaque enough); 0–1 in a settings override makes it see-through
        fontSize      = 16,       -- 6.171.2 — pt for the text; the chrome scales off it (LL: "aim for 16pt")
        saveDelay     = 0.3,      -- seconds after the last key before the disk write
        historyRows   = 200,      -- rows embedded in the page for the filter
        historyKeep   = 2000,     -- rows kept in the store (oldest drop past this)
        maxTabs       = 12,
        titleChars    = 40,
        previewChars  = 120,
        focusOnOpen   = true,
        nonActivating = true,
        pinned        = false,
        -- 📤 6.177.0 — the way out: the tabs as .md files Obsidian opens
        exportToVault   = true,     -- ⌘⇧S (and _G.scorpPadExport()) writes them out
        exportSub       = "Scratch",-- the folder inside the vault they land in
        exportHistory   = true,     -- closed tabs too (false = open tabs only)
        exportMax       = 500,      -- most files one export writes
        exportNameChars = 60,       -- longest file name before it is cut
        exportTag       = "scorp-pad",  -- the front-matter tag every exported note wears
        exported        = {},       -- tab id → the file name it keeps forever
        lastExport      = nil,

        viaVault      = true,     -- 6.173.0 — ⇪1 opens inside the ⇪3 Vault window; false = this module's own window

        -- the 4 PM task
        sendAt        = "16:00",
        startTime     = "07:30",
        dueTime       = "16:00",
        assignee      = "me",
        titlePrefix   = "Scorp pad · ",
        comment       = "Sent by Hammerspoon Scorp Pad \"⇪1\", file init.lua",
        sendOnlyIfChanged = true,

        -- state
        tabs = {}, active = nil, history = {}, sent = {},
        webview = nil, uc = nil, saveTimer = nil, sendTimer = nil,
        dragTimer = nil, dragOffset = nil,
        dirty = false, saves = 0, lastSaveErr = nil, lastSend = nil,
        opens = 0, nonActivatingApplied = false, nonActivatingWhy = "not requested",
        caret = 0, filter = "",
    }
    M.config = sp
    _G.scratchPad = sp

    local function say(m)
        if _G.diag and _G.diag.say then _G.diag.say("scratchPad", m) end
    end
    local function warn(m)
        if _G.diag and _G.diag.warn then _G.diag.warn("scratchPad", m) end
    end

    sp.dir  = (core.logsDir or core.homeDir or ".") .. "/scratch"
    -- 6.177.0 — kept so the export can find the vault's folder even on a
    -- Mac where the vault module never loaded.
    sp.cloudDir = core.cloudDir
    sp.baseDir  = core.logsDir or core.homeDir
    sp.file = sp.dir .. "/scratch.json"
    _G.rewrittenFiles = _G.rewrittenFiles or {}
    _G.rewrittenFiles[sp.file] = "the ⇪1 Scorp Pad — rewritten after every edit"

    -- ---- small helpers ----------------------------------------------------
    local counter = 0
    local function newId()
        counter = counter + 1
        return tostring(os.time()) .. "-" .. counter
    end
    local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    local function oneLine(s) return (tostring(s or ""):gsub("%s+", " ")) end

    -- An empty tab is named for what it IS (6.165.1 — "Untitled ×2 told
    -- me nothing"): "Capture", "Append", or "Scratch N" by its place.
    function sp.titleOf(tab)
        local first = tostring(tab.text or ""):match("[^\r\n]*") or ""
        first = trim(first)
        if first == "" then
            local k = tab.kind and sp.kinds and sp.kinds[tab.kind]
            if k then return k.label end
            local _, i = sp.findTab(tab.id)
            return "Scratch " .. tostring(i or "")
        end
        if #first > sp.titleChars then first = first:sub(1, sp.titleChars - 1) .. "…" end
        return first
    end

    function sp.findTab(id)
        for i, t in ipairs(sp.tabs) do if t.id == id then return t, i end end
        return nil
    end
    function sp.activeTab()
        local t = sp.active and sp.findTab(sp.active)
        if not t then t = sp.tabs[1]; sp.active = t and t.id end
        return t
    end

    -- ---- tab kinds: the old pads' text, filed where it always went ------------
    sp.kinds = {
        capture = {
            badge = "🗒", label = "Capture", filed = "→ 4 PM Asana queue",
            hint  = "⌘W queues this for the 4 PM send",
            file  = function(text)
                if not (_G.service and _G.service.has and _G.service.has("capturePad.add")) then
                    return false, "the Capture Pad is not loaded"
                end
                local ok, res = _G.service.call("capturePad.add", text)
                if not ok then return false, tostring(res or "not queued") end
                return true, "queued for the 4 PM send", ""
            end,
        },
        append = {
            badge = "➕", label = "Append", filed = "→ Logs / Ideas / Asana",
            hint  = "* idea · + log · ! task · ? note — ⌘W files it",
            file  = function(text)
                local np = _G.notePad
                if not (np and type(np.fileAll) == "function") then
                    return false, "the Quick Append Pad is not loaded"
                end
                local allOk, summary, leftover = np.fileAll(text)
                return allOk, summary or "filed", leftover or ""
            end,
        },
    }
    function sp.kindOf(tab) return tab and tab.kind and sp.kinds[tab.kind] or nil end

    -- 6.173.0 — the window that shows the tabs: the Vault's when it is
    -- loaded and sp.viaVault is on, else this module's own (below).
    function sp.host()
        if not sp.viaVault then return nil end
        local v = _G.vault
        if type(v) == "table" and v.enabled ~= false and type(v.showScratch) == "function" then return v end
        return nil
    end
    -- The host calls this as its window closes: kind tabs file where
    -- they always did (a failure keeps the tab), the store is written.
    function sp.onHostClose()
        for i = #sp.tabs, 1, -1 do
            local t = sp.tabs[i]
            if sp.kindOf(t) then sp.closeTab(t.id) end
        end
        if sp.dirty then sp.saveNow() end
    end

    -- ---- the store ----------------------------------------------------------
    local function ensureDir()
        if type(hs.fs) == "table" and hs.fs.mkdir then
            pcall(hs.fs.mkdir, sp.dir)
        else
            pcall(os.execute, "mkdir -p '" .. sp.dir:gsub("'", "'\\''") .. "'")
        end
    end

    function sp.load()
        local f = io.open(sp.file, "r")
        if not f then return false end
        local blob = f:read("a"); f:close()
        local ok, data = pcall(hs.json.decode, blob)
        if not (ok and type(data) == "table") then
            warn("store unreadable — starting empty (the file is left in place)")
            sp.lastSaveErr = "unreadable"
            return false
        end
        sp.tabs    = type(data.tabs) == "table" and data.tabs or {}
        sp.history = type(data.history) == "table" and data.history or {}
        sp.sent    = type(data.sent) == "table" and data.sent or {}
        sp.exported = type(data.exported) == "table" and data.exported or {}
        -- 6.182.0 — which tab the ⇪2 block lives in, so a reload keeps
        -- appending to it instead of starting a second Collect tab.
        sp.collectId = type(data.collectId) == "string" and data.collectId or nil
        sp.active  = data.active
        sp.pinned  = data.pinned == true
        return true
    end

    -- Written whole, to a sibling first, then renamed over: a crash
    -- mid-write can only ever lose the write, never the store.
    function sp.saveNow()
        if sp.saveTimer then pcall(function() sp.saveTimer:stop() end); sp.saveTimer = nil end
        ensureDir()
        local okE, blob = pcall(hs.json.encode, {
            tabs = sp.tabs, history = sp.history, sent = sp.sent,
            active = sp.active, pinned = sp.pinned, savedAt = os.time(),
            exported = sp.exported, collectId = sp.collectId,
        }, true)
        if not (okE and type(blob) == "string") then
            sp.lastSaveErr = "encode failed"
            warn("store not written — encode failed")
            return false
        end
        -- A failed write is SAID, once per streak, on screen and in the
        -- Console — the text is safe in Lua and the next keystroke retries.
        local function failed(why)
            sp.lastSaveErr = why
            sp.saveFails = (sp.saveFails or 0) + 1
            if core.warnWriteFailed then core.warnWriteFailed("scratch pad store") end
            if not sp.saveErrSaid then
                sp.saveErrSaid = true
                pcall(function()
                    hs.alert.show("📝 NOT SAVED — " .. why .. "\nYour text is safe in memory; "
                                  .. "every keystroke retries the write.", 5)
                end)
                print("📝 Scorp Pad: store not written — " .. why .. " (" .. sp.file .. ")")
            end
            return false
        end
        local tmp = sp.file .. ".tmp"
        local f = io.open(tmp, "w")
        if not f then return failed("cannot open " .. tmp) end
        local okW = f:write(blob)
        f:close()
        if not okW then return failed("write failed") end
        local okR = os.rename(tmp, sp.file)
        if not okR then return failed("rename failed") end
        if sp.saveErrSaid then
            sp.saveErrSaid = false
            pcall(function() hs.alert.show("📝 Saving again", 2) end)
        end
        sp.dirty, sp.lastSaveErr = false, nil
        sp.saves = sp.saves + 1
        return true
    end

    -- Every keystroke lands here; the disk write waits sp.saveDelay after
    -- the LAST one. The timer is HELD in sp.saveTimer (test_diagnostics).
    function sp.scheduleSave()
        sp.dirty = true
        if sp.saveTimer then pcall(function() sp.saveTimer:stop() end) end
        local ok, t = pcall(hs.timer.doAfter, sp.saveDelay, function()
            sp.saveTimer = nil
            sp.saveNow()
        end)
        sp.saveTimer = ok and t or nil
        if not ok then sp.saveNow() end
    end

    -- ---- tabs ---------------------------------------------------------------
    function sp.newTab(text, kind)
        if #sp.tabs >= sp.maxTabs then
            pcall(function() hs.alert.show("📝 " .. sp.maxTabs .. " tabs already — close one (⌘W)", 2) end)
            return nil
        end
        local t = { id = newId(), text = tostring(text or ""), createdAt = os.time(), updatedAt = os.time(),
                    kind = (kind and sp.kinds[kind]) and kind or nil }
        sp.tabs[#sp.tabs + 1] = t
        sp.active = t.id
        sp.scheduleSave()
        return t
    end

    function sp.setText(id, text)
        local t = sp.findTab(id)
        if not t then return false end
        text = tostring(text or "")
        if t.text ~= text then
            t.text, t.updatedAt = text, os.time()
            sp.scheduleSave()
        end
        return true
    end

    -- A closed tab with text becomes the newest history row; an empty
    -- one simply goes. The last tab closing leaves one blank tab.
    -- A Capture / Append tab is FILED first; a failure keeps the tab.
    -- Returns ok, why. (why = the filing summary or the failure.)
    function sp.fileTab(t)
        local k = sp.kindOf(t)
        if not k then return true end
        if trim(t.text) == "" then return true, "empty" end
        local ok, why, leftover = k.file(t.text)
        if not ok then
            t.text = (leftover and leftover ~= "") and leftover or t.text
            t.updatedAt = os.time()
            pcall(function() hs.alert.show("📝 Kept in its tab — " .. tostring(why), 4) end)
            sp.scheduleSave()
            return false, why
        end
        if leftover and leftover ~= "" then
            -- Part filed, part not (the router's failed lines): keep those.
            t.text, t.updatedAt = leftover, os.time()
            pcall(function() hs.alert.show(tostring(why), 4) end)
            sp.scheduleSave()
            return false, why
        end
        return true, why
    end

    function sp.closeTab(id)
        local t, i = sp.findTab(id)
        if not t then return false end
        local k = sp.kindOf(t)
        if k then
            local ok, why = sp.fileTab(t)
            if not ok then return false end
            t.filedAs = k.filed .. (why and why ~= "" and (" · " .. tostring(why)) or "")
        end
        table.remove(sp.tabs, i)
        if trim(t.text) ~= "" then
            table.insert(sp.history, 1, {
                id = t.id, text = t.text, title = sp.titleOf(t),
                createdAt = t.createdAt, closedAt = os.time(),
                kind = t.kind, filedAs = t.filedAs,
            })
            while #sp.history > sp.historyKeep do table.remove(sp.history) end
        end
        if #sp.tabs == 0 then sp.newTab("") end
        if sp.active == id then sp.active = sp.tabs[math.min(i, #sp.tabs)].id end
        sp.saveNow()
        return true
    end

    function sp.restore(id)
        for i, h in ipairs(sp.history) do
            if h.id == id then
                local t = sp.newTab(h.text)
                if not t then return false end
                t.createdAt = h.createdAt or t.createdAt
                table.remove(sp.history, i)
                sp.saveNow()
                return true
            end
        end
        return false
    end

    -- ---- 📤 export to the vault (6.177.0) ------------------------------------
    -- LL: "Will I be able to open my Scorp pad files in Obsidian if I ever
    -- decide to move to it?" On their own the tabs are JSON inside one
    -- rewritten store, so: no. This writes every tab — and, by default, the
    -- closed-tab history — out as plain .md files in <Vault>/Scratch, the
    -- same folder Obsidian opens. The store stays the source of truth; the
    -- .md files are a copy you can walk away with.
    --
    -- IT DEGRADES, IT NEVER BREAKS. The vault module does not have to be
    -- loaded (the folder is worked out the same way it would work it out);
    -- OneDrive does not have to exist (a local folder takes its place and
    -- the summary SAYS so); a single unwritable tab costs that one file,
    -- not the export; a failed export never touches a tab, a store or a
    -- keystroke. Every path returns ok, why — nothing here ever throws.
    local BADCHARS = '[/\\:%*%?"<>|]'

    -- The vault's folder: its own if the module is up (that is the truth),
    -- else the very same path it would have chosen from core (work Mac
    -- profiles may not load vault at all).
    function sp.vaultDir()
        local v = _G.vault
        if type(v) == "table" and type(v.dir) == "string" and v.dir ~= "" then
            return v.dir, "vault"
        end
        if sp.cloudDir and sp.cloudDir ~= "" then return sp.cloudDir .. "/Vault", "cloud" end
        return (sp.baseDir or ".") .. "/vault", "local"
    end
    function sp.exportDir()
        local dir, how = sp.vaultDir()
        local sub = trim(tostring(sp.exportSub or ""))
        if sub ~= "" then dir = dir .. "/" .. sub end
        return dir, how
    end

    -- A file name Finder, OneDrive and Obsidian all accept: no slashes,
    -- no colons, no control characters, no leading dot, not endless.
    function sp.exportSafeName(title)
        local s = oneLine(tostring(title or ""))
        s = s:gsub("%c", " "):gsub(BADCHARS, "-")
        s = trim(s:gsub("%s+", " "))
        s = s:gsub("^[%.%-]+", "")
        s = trim(s)
        if #s > sp.exportNameChars then s = trim(s:sub(1, sp.exportNameChars)) end
        if s == "" then s = "Scratch" end
        return s
    end

    -- The name a tab keeps FOREVER, remembered in the store (sp.exported):
    -- a second export of the same tab updates its file instead of leaving
    -- a copy behind. Nothing on disk is ever read to decide this — a
    -- OneDrive placeholder read can block the main thread, and the pad
    -- never blocks.
    function sp.exportNameFor(id, title)
        id = tostring(id or "")
        sp.exported = type(sp.exported) == "table" and sp.exported or {}
        local had = sp.exported[id]
        if type(had) == "string" and had ~= "" then return had end
        local base, taken = sp.exportSafeName(title), {}
        for other, name in pairs(sp.exported) do
            if other ~= id and type(name) == "string" then taken[name:lower()] = true end
        end
        local name, n = base .. ".md", 1
        while taken[name:lower()] do
            n = n + 1
            name = base .. " " .. n .. ".md"
        end
        sp.exported[id] = name
        return name
    end

    -- Front matter Obsidian reads (and this vault's own tag scan reads):
    -- the title, where it came from, when it was written. Then the text,
    -- exactly as typed — no Markdown is invented for LL.
    function sp.exportBody(rec)
        local when = tonumber(rec.updatedAt or rec.closedAt or rec.createdAt) or os.time()
        local made = tonumber(rec.createdAt) or when
        local L = {
            "---",
            "title: " .. tostring(rec.title or "Scratch"),
            "source: Scorp Pad",
            "created: " .. os.date("%Y-%m-%d %H:%M", made),
            "updated: " .. os.date("%Y-%m-%d %H:%M", when),
            "tags: " .. tostring(sp.exportTag or "scorp-pad"),
            "---",
            "",
            "",
        }
        local text = tostring(rec.text or "")
        return table.concat(L, "\n") .. text .. (text:sub(-1) == "\n" and "" or "\n")
    end

    local function mkdirpFor(dir)
        local made = false
        if type(hs.fs) == "table" and type(hs.fs.mkdir) == "function" then
            local up, chain = dir, {}
            while up and up ~= "" and up ~= "/" do
                chain[#chain + 1] = up
                up = up:match("^(.*)/[^/]+$")
            end
            for i = #chain, 1, -1 do pcall(hs.fs.mkdir, chain[i]) end
            made = true
        end
        if type(hs.fs) == "table" and type(hs.fs.attributes) == "function" then
            local ok, a = pcall(hs.fs.attributes, dir)
            if ok and type(a) == "table" then return true end
        elseif made then
            return true          -- made what we could and cannot check; the write will say
        end
        pcall(os.execute, "mkdir -p '" .. dir:gsub("'", "'\\''") .. "'")
        return true
    end

    -- One file, written to a sibling and renamed over it — the same
    -- contract as the store: a crash can lose the write, never the file.
    local function writeOne(path, body)
        local tmp = path .. ".tmp"
        local f = io.open(tmp, "w")
        if not f then return false, "cannot write " .. tmp end
        local okW = f:write(body)
        f:close()
        if not okW then return false, "write failed" end
        if not os.rename(tmp, path) then
            pcall(os.remove, tmp)
            return false, "rename failed"
        end
        return true
    end

    -- Everything, in one go. Returns ok, summary — and never raises.
    function sp.exportAll(why)
        if sp.exportToVault == false then
            return false, "export is off (settings: scratch_pad.exportToVault)"
        end
        local dir, how = sp.exportDir()
        local okDir = pcall(mkdirpFor, dir)
        if not okDir then return false, "could not make " .. dir end

        local recs = {}
        for _, t in ipairs(sp.tabs) do
            if trim(t.text or "") ~= "" then
                recs[#recs + 1] = { id = t.id, title = sp.titleOf(t), text = t.text,
                                    createdAt = t.createdAt, updatedAt = t.updatedAt }
            end
        end
        if sp.exportHistory ~= false then
            for _, h in ipairs(sp.history) do
                if trim(h.text or "") ~= "" then
                    recs[#recs + 1] = { id = h.id, title = h.title or "Scratch", text = h.text,
                                        createdAt = h.createdAt, closedAt = h.closedAt }
                end
            end
        end

        local wrote, failed, firstWhy, capped = 0, 0, nil, false
        for i, rec in ipairs(recs) do
            if i > (tonumber(sp.exportMax) or 500) then capped = true break end
            local ok, err = pcall(function()
                local name = sp.exportNameFor(rec.id, rec.title)
                local okW, whyW = writeOne(dir .. "/" .. name, sp.exportBody(rec))
                if not okW then error(whyW, 0) end
            end)
            if ok then wrote = wrote + 1
            else
                failed = failed + 1
                firstWhy = firstWhy or tostring(err)
            end
        end
        sp.saveNow()   -- the names it just handed out are part of the store

        local parts = { wrote .. " note" .. (wrote == 1 and "" or "s") .. " → " .. dir }
        if how == "local" then parts[#parts + 1] = "no OneDrive found — local folder" end
        if capped then parts[#parts + 1] = "stopped at " .. tostring(sp.exportMax) .. " (exportMax)" end
        if failed > 0 then parts[#parts + 1] = failed .. " could not be written (" .. tostring(firstWhy) .. ")" end
        local summary = table.concat(parts, " · ")
        sp.lastExport = { at = os.time(), why = tostring(why or "export"), dir = dir,
                          wrote = wrote, failed = failed, how = how, summary = summary }
        say("exported " .. summary)
        return failed == 0 and wrote > 0, summary
    end

    -- The Console door. Prints what happened either way.
    _G.scorpPadExport = function()
        local ok, summary = sp.exportAll("console")
        print("📤 Scorp Pad export — " .. tostring(summary))
        return ok, summary
    end

    -- ---- the 4 PM task --------------------------------------------------------
    local function checksum(s)
        local h = #s
        for i = 1, #s, 7 do h = (h * 31 + s:byte(i)) % 2147483647 end
        return tostring(h)
    end

    -- (title, notes, count) — every open tab with text, then today's closed
    -- rows. nil when there is nothing to send.
    function sp.dayBody(today)
        today = today or os.date("%Y-%m-%d")
        local parts, n = {}, 0
        for _, t in ipairs(sp.tabs) do
            if trim(t.text) ~= "" and not t.kind then
                n = n + 1
                parts[#parts + 1] = "## " .. sp.titleOf(t) .. "\n" .. trim(t.text)
            end
        end
        for _, h in ipairs(sp.history) do
            if os.date("%Y-%m-%d", h.closedAt or 0) == today and trim(h.text) ~= "" and not h.kind then
                n = n + 1
                parts[#parts + 1] = "## " .. (h.title or "Untitled") .. " (closed "
                    .. os.date("%H:%M", h.closedAt or 0) .. ")\n" .. trim(h.text)
            end
        end
        if n == 0 then return nil end
        local title = sp.titlePrefix .. os.date("%a %b %d", os.time())
        return title, table.concat(parts, "\n\n"), n
    end

    function sp.send(reason)
        reason = reason or "manual"
        local today = os.date("%Y-%m-%d")
        local title, notes, n = sp.dayBody(today)
        if not title then
            sp.lastSend = { at = os.time(), reason = reason, outcome = "nothing to send" }
            say(sp.sendAt .. " send skipped — nothing written today")
            return false, "nothing to send"
        end
        local sum = checksum(notes)
        if sp.sendOnlyIfChanged and sp.sent[today] == sum then
            sp.lastSend = { at = os.time(), reason = reason, outcome = "unchanged since the last send" }
            say(sp.sendAt .. " send skipped — unchanged since the last send")
            return false, "unchanged"
        end
        if not (core.asanaEnabled and _G.asanaSubmitTask) then
            sp.lastSend = { at = os.time(), reason = reason, outcome = "Asana is off on this Mac" }
            print("📝 Scorp Pad: " .. sp.sendAt .. " task not sent — Asana is off on this Mac "
                  .. "(secret.lua); the text is safe in " .. sp.file)
            return false, "asana off"
        end
        local ok, accepted = pcall(_G.asanaSubmitTask, title, notes, sp.assignee, "", {
            startDate = today, startTime = sp.startTime,
            dueDate   = today, dueTime   = sp.dueTime,
            comment   = sp.comment,
        })
        if ok and accepted then
            sp.sent[today] = sum
            sp.lastSend = { at = os.time(), reason = reason, outcome = "sent · " .. n .. " section"
                            .. (n == 1 and "" or "s"), title = title }
            sp.saveNow()
            say("task sent — " .. title)
            return true, title
        end
        sp.lastSend = { at = os.time(), reason = reason,
                        outcome = "rejected — " .. tostring(ok and "validation" or accepted) }
        warn("task not accepted (" .. tostring(ok and "validation failed" or accepted) .. ")")
        return false, "rejected"
    end
    _G.scratchPadSend = function() return sp.send("manual") end

    -- ---- the page -------------------------------------------------------------
    local function escapeHtml(s)
        return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;")
                :gsub(">", "&gt;"):gsub('"', "&quot;"))
    end
    local function jstr(s)
        s = tostring(s or "")
        s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "")
             :gsub("</", "<\\/")
        return '"' .. s .. '"'
    end

    function sp.historyJson()
        local rows = {}
        for i = 1, math.min(#sp.history, sp.historyRows) do
            local h = sp.history[i]
            local k = h.kind and sp.kinds[h.kind]
            rows[#rows + 1] = "{id:" .. jstr(h.id) .. ",t:" .. jstr((k and (k.badge .. " ") or "") .. (h.title or "Untitled"))
                .. ",w:" .. jstr(os.date("%b %d %H:%M", h.closedAt or 0))
                .. ",p:" .. jstr(oneLine(h.text):sub(1, sp.previewChars)) .. "}"
        end
        return "[" .. table.concat(rows, ",") .. "]"
    end

    function sp.buildHtml()
        local cur = sp.activeTab() or sp.newTab("")
        local tabsHtml = {}
        for i, t in ipairs(sp.tabs) do
            tabsHtml[#tabsHtml + 1] = '<div class="tab' .. (t.kind and (" " .. t.kind) or "") .. (t.id == cur.id and " on" or "")
                .. '" data-id="' .. escapeHtml(t.id) .. '"><span class="tt">'
                .. (sp.kindOf(t) and (sp.kindOf(t).badge .. " ") or "")
                .. escapeHtml(sp.titleOf(t)) .. '</span><span class="x" title="Close ⌘W">×</span></div>'
        end
        local theme = (_G.uiStyle and _G.uiStyle.cssOverride and _G.uiStyle.cssOverride()) or ""
        -- 6.171.2 — one number sizes the page: text at sp.fontSize, chrome 2–3 pt under it.
        local fs = tonumber(sp.fontSize) or 16
        if fs < 8 then fs = 8 end
        local function sized(html)
            return (html:gsub("FS1px", math.floor(fs - 2) .. "px"):gsub("FS2px", math.floor(fs - 3) .. "px")
                        :gsub("FSpx", math.floor(fs) .. "px"))
        end
        return sized([[<!doctype html><html><head><meta charset="utf-8"><style>
:root{color-scheme:dark}
html,body{margin:0;height:100%;background:#141418;color:#e8e8ec;font-family:-apple-system,Helvetica,sans-serif;font-size:FSpx;overflow:hidden}
#wrap{display:flex;flex-direction:column;height:100%}
header{display:flex;align-items:center;gap:8px;padding:6px 10px;background:#1c1c22;cursor:grab;user-select:none;-webkit-user-select:none}
header.dragging{cursor:grabbing}
header .grip{opacity:.5}
header .name{font-weight:600;flex:1}
header .hint{opacity:.55;font-size:FS2px}
header button{background:#2a2a33;color:#e8e8ec;border:0;border-radius:6px;padding:3px 8px;font-size:FS1px;cursor:pointer}
header button.pin.on{background:#4a7fe0;color:#fff}
header .bad{background:#7a2a2a;color:#ffd9d9;border-radius:6px;padding:3px 8px;font-size:FS2px}
#tabs{display:flex;gap:4px;padding:6px 8px 0;background:#18181d;overflow-x:auto}
.tab{display:flex;align-items:center;gap:6px;padding:4px 8px;border-radius:6px 6px 0 0;background:#202027;max-width:180px;cursor:default}
.tab.on{background:#3a3a48;box-shadow:inset 0 -3px 0 #4a7fe0;color:#fff}
.tab.capture{background:#1f2a33}.tab.capture.on{background:#2b3f4d;box-shadow:inset 0 -3px 0 #4fb3d9}
.tab.append{background:#2f2a1c}.tab.append.on{background:#4a4024;box-shadow:inset 0 -3px 0 #e0b04a}
.tab .tt{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tab .x{opacity:.5;cursor:pointer;padding:0 2px}
.tab .x:hover{opacity:1}
.tab.add{padding:4px 10px;opacity:.7;cursor:pointer}
textarea{flex:1;margin:0;padding:10px;border:0;outline:0;resize:none;background:#141418;color:#e8e8ec;
  font-family:Menlo,monospace;font-size:FSpx;line-height:1.45;font-weight:normal;font-style:normal}
#hist{height:34%;min-height:96px;display:flex;flex-direction:column;border-top:1px solid #2a2a33;background:#17171c}
#hist .bar{display:flex;align-items:center;gap:8px;padding:5px 10px}
#hist .bar .lab{opacity:.6;font-size:FS2px;letter-spacing:.04em}
#hist input{flex:1;background:#202027;border:1px solid #2a2a33;border-radius:6px;color:#e8e8ec;padding:3px 8px;font-size:FS1px;outline:0}
#hist input:focus{border-color:#4a7fe0}
#rows{overflow-y:auto;flex:1}
.row{display:flex;gap:10px;padding:4px 10px;cursor:pointer;border-bottom:1px solid #1f1f26}
.row:hover{background:#202027}
.row.sel{background:#2a2f45;outline:1px solid #7aa2f7}
.row .w{opacity:.5;white-space:nowrap;font-size:FS2px;min-width:86px}
.row .t{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:40%}
.row .p{opacity:.65;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;flex:1}
.empty{opacity:.45;padding:8px 10px;font-size:FS1px}
]] .. theme .. [[</style></head><body><div id="wrap">
<header id="bar"><span class="grip">⠿</span><span class="name">📝 Scorp Pad</span>
<span class="hint">]] .. escapeHtml(sp.kindOf(cur) and sp.kindOf(cur).hint or "⌘T new · ⌘W close · ⌃Tab cycle · Esc") .. [[</span>
]] .. (sp.lastSaveErr and ('<span class="bad" title="' .. escapeHtml(sp.lastSaveErr) .. '">⚠ not saved</span>') or "") .. [[
<button class="pin]] .. (sp.pinned and " on" or "") .. [[" id="pin" title="Pin: the pad stays up beside the app; Esc only hands the keyboard back">📌 ]] .. (sp.pinned and "Pinned" or "Pin") .. [[</button>
<button id="send" title="Create today's Asana task now instead of waiting for 16:00">→ Asana now</button>
<button id="close" title="Close (⇪1)">✕</button></header>
<div id="tabs">]] .. table.concat(tabsHtml) .. [[<div class="tab add" id="add" title="New tab ⌘T">+</div></div>
<textarea id="t" spellcheck="false" autofocus>]] .. escapeHtml(cur.text) .. [[</textarea>
<div id="hist"><div class="bar"><span class="lab">HISTORY</span><input id="q" placeholder="filter closed tabs…" value="]] .. escapeHtml(sp.filter) .. [["><span class="lab" id="cnt"></span></div><div id="rows"></div></div>
</div><script>
var ROWS = ]] .. sp.historyJson() .. [[;
var t = document.getElementById('t'), q = document.getElementById('q');
var ACTIVE = ]] .. jstr(cur.id) .. [[;
var CARET = ]] .. tostring(tonumber(sp.caret) or 0) .. [[;
function say(m){ m.text = t.value; m.sel = t.selectionStart; m.id = ACTIVE;
  try { window.webkit.messageHandlers.scratchPad.postMessage(m); } catch(e){} }
function esc(s){ return String(s).replace(/[&<>"]/g, function(c){ return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]; }); }
function draw(){
  var f = q.value.toLowerCase(), out = [], n = 0;
  for (var i = 0; i < ROWS.length; i++) { var r = ROWS[i];
    if (f && (r.t + ' ' + r.p).toLowerCase().indexOf(f) < 0) continue;
    n++; out.push('<div class="row" data-id="' + esc(r.id) + '"><span class="w">' + esc(r.w)
      + '</span><span class="t">' + esc(r.t) + '</span><span class="p">' + esc(r.p) + '</span></div>'); }
  document.getElementById('rows').innerHTML = out.length ? out.join('') :
    '<div class="empty">' + (ROWS.length ? 'nothing matches' : 'closed tabs land here — ⌘W') + '</div>';
  document.getElementById('cnt').textContent = n + ' / ' + ROWS.length;
}
draw();
q.addEventListener('input', function(){ SEL = -1; draw(); });
t.addEventListener('input', function(){ say({a:'edit'}); });
document.getElementById('rows').addEventListener('click', function(e){
  var el = e.target.closest('.row'); if (el) say({a:'restore', rid: el.getAttribute('data-id')}); });
document.getElementById('tabs').addEventListener('click', function(e){
  var x = e.target.closest('.x'); var tab = e.target.closest('.tab');
  if (e.target.id === 'add' || (tab && tab.id === 'add')) { say({a:'new'}); return; }
  if (!tab) return;
  if (x) say({a:'close', tid: tab.getAttribute('data-id')});
  else if (tab.getAttribute('data-id') !== ACTIVE) say({a:'switch', tid: tab.getAttribute('data-id')}); });
document.getElementById('pin').addEventListener('click', function(){ say({a:'pin'}); });
document.getElementById('send').addEventListener('click', function(){ say({a:'send'}); });
document.getElementById('close').addEventListener('click', function(){ say({a:'hide'}); });
var hdr = document.getElementById('bar');
hdr.addEventListener('mousedown', function(e){ if (e.button !== 0 || e.target.tagName === 'BUTTON') return;
  e.preventDefault(); hdr.classList.add('dragging'); say({a:'dragStart'}); });
window.addEventListener('mouseup', function(){ hdr.classList.remove('dragging'); });
document.addEventListener('keyup', function(e){
  if (e.key === 'F18' || e.keyCode === 79) say({a:'f18up'}); });

// ⌨️ 6.170.0 — ARROW THROUGH THE ROWS. LL: "in any window that has a
// list, we need to be able to arrow up and down." ⌥↑ / ⌥↓ always move
// the highlight; plain ↑ / ↓ do too whenever the caret is NOT in the
// text box (the text box keeps its own arrows). ⏎ (⌥⏎ from the text
// box) acts on the highlighted row. Every DOM call is guarded so a
// page without rows, or a test shim without a DOM, never throws.
var SEL = -1, ROWSEL = '#rows .row';
function rowsList(){ try { return Array.prototype.slice.call(document.querySelectorAll(ROWSEL)); } catch(e){ return []; } }
function inText(){ var a = null; try { a = document.activeElement; } catch(e){} return !!(a && a.tagName === 'TEXTAREA'); }
function moveSel(d){
  var rows = rowsList(); if (!rows.length) return false;
  var from = SEL < 0 ? (d > 0 ? -1 : rows.length) : SEL;
  SEL = Math.max(0, Math.min(rows.length - 1, from + d));
  for (var i = 0; i < rows.length; i++) { try { if (i === SEL) rows[i].classList.add('sel'); else rows[i].classList.remove('sel'); } catch(e){} }
  try { rows[SEL].scrollIntoView({ block: 'nearest' }); } catch(e){}
  return true;
}
function selRow(){ var rows = rowsList(); return (SEL >= 0 && SEL < rows.length) ? rows[SEL] : null; }
function rowKey(e){
  var arrow = e.key === 'ArrowDown' ? 1 : (e.key === 'ArrowUp' ? -1 : 0);
  if (arrow && (e.altKey || !inText())) { e.preventDefault(); moveSel(arrow); return true; }
  if (e.key === 'Enter' && !e.metaKey && (e.altKey || !inText())) {
    var r = selRow(); if (r) { e.preventDefault(); rowAct(r); return true; }
  }
  return false;
}
// ⏎ on a highlighted history row restores it (a click does the same).
function rowAct(r){ say({a:'restore', rid: r.getAttribute('data-id')}); }
document.addEventListener('keydown', function(e){
  var meta = e.metaKey || e.ctrlKey;
  if (e.key === 'Escape') { e.preventDefault(); say({a:'esc'}); return; }
  if (rowKey(e)) return;
  if (meta && (e.key === 't' || e.key === 'T')) { e.preventDefault(); say({a:'new'}); return; }
  if (meta && (e.key === 'w' || e.key === 'W')) { e.preventDefault(); say({a:'close', tid: ACTIVE}); return; }
  if (meta && e.key >= '1' && e.key <= '9') { e.preventDefault(); say({a:'nth', n: e.key}); return; }
  if (e.ctrlKey && e.key === 'Tab') { e.preventDefault(); say({a:'cycle', d: e.shiftKey ? -1 : 1}); return; }
  if (meta && e.shiftKey && (e.key === 's' || e.key === 'S')) { e.preventDefault(); say({a:'export'}); return; }
  if (meta && (e.key === 'f' || e.key === 'F')) { e.preventDefault(); q.focus(); q.select(); return; }
});
t.focus(); try { t.setSelectionRange(CARET, CARET); } catch(e){}
</script></body></html>]])
    end

    function sp.render()
        if not sp.webview then return end
        pcall(function() sp.webview:html(sp.buildHtml()) end)
    end

    -- ---- messages from the page ----------------------------------------------
    local function handleMessage(body)
        if type(body) ~= "table" then return end
        -- The text rides on EVERY message: whatever the action, the draft
        -- is in Lua before anything else happens.
        if body.id and body.text ~= nil then sp.setText(body.id, body.text) end
        sp.caret = tonumber(body.sel) or 0
        local a = body.a
        if a == "edit" then
            return
        elseif a == "new" then
            if sp.newTab("") then sp.caret = 0; sp.render() end
        elseif a == "close" then
            if sp.closeTab(tostring(body.tid or "")) then sp.caret = 0; sp.render() end
        elseif a == "switch" then
            if sp.findTab(tostring(body.tid or "")) then
                sp.active = tostring(body.tid); sp.caret = 0; sp.scheduleSave(); sp.render()
            end
        elseif a == "cycle" then
            -- ⌃Tab / ⌃⇧Tab (6.166.0) — round the tabs, wrapping
            local n = #sp.tabs
            if n > 1 then
                local _, i = sp.findTab(sp.active)
                local d = (tonumber(body.d) or 1) < 0 and -1 or 1
                local j = ((i or 1) - 1 + d) % n + 1
                sp.active = sp.tabs[j].id; sp.caret = 0; sp.scheduleSave(); sp.render()
            end
        elseif a == "nth" then
            local t = sp.tabs[tonumber(body.n) or 0]
            if t and t.id ~= sp.active then sp.active = t.id; sp.caret = 0; sp.scheduleSave(); sp.render() end
        elseif a == "restore" then
            if sp.restore(tostring(body.rid or "")) then sp.caret = 0; sp.render() end
        elseif a == "pin" then
            sp.pinned = not sp.pinned
            sp.saveNow()
            sp.render()
            pcall(function() hs.alert.show(sp.pinned and "📌 Pinned — Esc hands the keys back, ⇪1 closes"
                                           or "📌 Unpinned", 1.5) end)
        elseif a == "export" then
            local ok, summary = sp.exportAll("⌘⇧S")
            pcall(function() hs.alert.show((ok and "📤 Exported — " or "📤 ") .. tostring(summary), 4) end)
        elseif a == "send" then
            local ok, why = sp.send("button")
            if not ok then pcall(function() hs.alert.show("📝 Not sent — " .. tostring(why), 2) end) end
        elseif a == "esc" then
            if sp.pinned then sp.blur() else sp.hide() end
        elseif a == "hide" then
            sp.hide()
        elseif a == "dragStart" then
            sp.beginDrag()
        elseif a == "f18up" then
            if _G.hyperReleaseSeen then pcall(_G.hyperReleaseSeen, "the scratch pad") end
        end
    end
    sp.handleMessage = handleMessage   -- exposed for the test suite

    -- ---- dragging (Lua polls the mouse; JS mousemove dies past the edge) ----
    local function mousePosition()
        if type(hs.mouse) ~= "table" then return nil end
        for _, name in ipairs({ "absolutePosition", "getAbsolutePosition" }) do
            local fn = hs.mouse[name]
            if type(fn) == "function" then
                local ok, p = pcall(fn)
                if ok and type(p) == "table" and p.x and p.y then return p end
            end
        end
        return nil
    end
    local function leftButtonDown()
        local ok, btns = pcall(hs.eventtap.checkMouseButtons)
        if not ok or type(btns) ~= "table" then return false end
        return btns.left == true or btns[1] == true
    end
    function sp.endDrag()
        if sp.dragTimer then pcall(function() sp.dragTimer:stop() end); sp.dragTimer = nil end
        sp.dragOffset = nil
    end
    function sp.beginDrag()
        if not sp.webview then return end
        local okF, f = pcall(function() return sp.webview:frame() end)
        if not (okF and type(f) == "table") then return end
        local m = mousePosition()
        if not m then return end
        sp.endDrag()
        sp.dragOffset = { x = m.x - f.x, y = m.y - f.y }
        sp.dragTimer = hs.timer.doEvery(0.016, function()
            if not (sp.webview and sp.dragOffset) then sp.endDrag() return end
            if not leftButtonDown() then sp.endDrag() return end
            local p = mousePosition()
            if not p then sp.endDrag() return end
            pcall(function()
                local cur = sp.webview:frame()
                sp.webview:frame({ x = p.x - sp.dragOffset.x, y = p.y - sp.dragOffset.y,
                                   w = cur.w, h = cur.h })
            end)
        end)
    end

    -- ---- the window -------------------------------------------------------------
    function sp.applyNonActivating(view)
        if not view then return false, "there is no window" end
        local masks = hs.webview and hs.webview.windowMasks
        local bit   = type(masks) == "table" and masks.nonactivating or nil
        if type(bit) ~= "number" or bit < 1 then
            return false, "this Hammerspoon has no nonactivating window mask"
        end
        local function isSet(v) return (math.floor(v / bit) % 2) == 1 end
        local okGet, cur = pcall(function() return view:windowStyle() end)
        if not (okGet and type(cur) == "number") then return false, "the window style could not be read" end
        if not isSet(cur) then
            local okSet = pcall(function() view:windowStyle(cur + bit) end)
            if not okSet then return false, "the window style was rejected" end
        end
        local okRe, now = pcall(function() return view:windowStyle() end)
        if not (okRe and type(now) == "number") then return false, "the window style could not be read back" end
        if not isSet(now) then return false, "macOS dropped the mask" end
        return true, "applied"
    end

    function sp.isOpen() return sp.webview ~= nil end

    -- Pinned + Esc: the pad stays; the keyboard goes back to the app.
    -- Hiding and re-showing the same window is the only focus hand-off a
    -- non-activating panel has that touches no other app's windows.
    function sp.blur()
        if not sp.webview then return end
        pcall(function() sp.webview:hide() end)
        pcall(function() sp.webview:show() end)
    end

    function sp.hide()
        local host = sp.host()
        if not sp.webview and host and host.webview then host.hide() return end
        sp.endDrag()
        -- The old pads filed on close; their tabs still do. A failure
        -- keeps that tab (and the text) for next time.
        for i = #sp.tabs, 1, -1 do
            local t = sp.tabs[i]
            if sp.kindOf(t) then sp.closeTab(t.id) end
        end
        if sp.webview then
            pcall(function() sp.webview:delete() end)
            sp.webview = nil
        end
        sp.uc = nil
        if sp.dirty then sp.saveNow() end
        say("pad closed")
    end

    -- No webview must not mean no scratch space: the plain prompt edits
    -- the active tab and saves it the same way.
    local function promptFallback()
        local cur = sp.activeTab() or sp.newTab("")
        local okP, button, typed = pcall(hs.dialog.textPrompt, "Scorp Pad",
            "No web view on this Hammerspoon — this box edits the current tab.",
            cur.text or "", "Save", "Cancel")
        if not okP or button ~= "Save" then return end
        sp.setText(cur.id, typed)
        sp.saveNow()
    end

    function sp.show()
        if not sp.enabled then return end
        if sp.webview then sp.hide() return end
        local host = sp.host()
        if host then return host.toggleScratch() end
        return sp.open()
    end

    -- ⇪N / ⇪2 land here: one tab of that kind, made active, the pad up.
    -- opts.text replaces the tab's text; opts.prefix seeds an empty one.
    function sp.openKind(kind, opts)
        if not sp.kinds[kind] then return false end
        opts = opts or {}
        local t
        for _, x in ipairs(sp.tabs) do if x.kind == kind then t = x break end end
        if not t then t = sp.newTab("", kind) end
        if not t then return false end
        if opts.text ~= nil then t.text = tostring(opts.text) end
        if opts.prefix ~= nil and trim(t.text) == "" then t.text = tostring(opts.prefix) end
        t.updatedAt = os.time()
        sp.active, sp.caret = t.id, #t.text
        sp.scheduleSave()
        local host = sp.host()
        if host and not sp.webview then host.showScratch(t.id) return true end
        if sp.webview then sp.render() else sp.open() end
        return true
    end

    -- =====================================================================
    -- 📎 SEQUENTIAL COPY (6.182.0, ⇪2 — rebuilt 6.201.0)
    -- =====================================================================
    -- LL: "Can I select some text, and then immediately select some more
    -- text and have it append the text I just copied a few seconds before
    -- … so I can build a block of text that I can then edit quickly
    -- instead of having to make multiple copy/pastes to gather all the
    -- info."
    --
    -- 🚨 6.201.0 — ⌘V NEVER PASTED WHAT HE HAD JUST GRABBED. Until now
    -- each press appended the selection to a 📎 Collect TAB in the pad and
    -- put `t.text` — THE WHOLE TAB — on the clipboard. That tab is
    -- remembered in the store (sp.collectId) and was never emptied, so the
    -- block grew for as long as LL owned the feature; the COUNT beside it
    -- was not remembered (sp.collectCount, a plain 0 reset by every
    -- reload), so the alert said "1 grab" over a clipboard holding months
    -- of text. LL pasted the proof: the literal word "Collect", then every
    -- grab he had ever made, with the two from that minute at the very
    -- bottom. He also said he had no idea anything was being filed into
    -- the pad at all. His decision: "I'd like copy1, copy to be retained.
    -- And put on the clipboard, not into Scorp Pad."
    --
    -- 🔎 AND THE DIAGNOSIS THAT WAS WRONG, kept because the method matters.
    -- This was blamed on the borrowed clipboard first — 6.198.0 shipped a
    -- guard so pt.copySelection's restore could not land on the caller's
    -- own write. That guard is real and it works (LL's report: 10 borrows
    -- left alone, 0 put back). It was never this bug. What was never
    -- checked, through two releases, was the ONE question that settles a
    -- clipboard complaint: what does ⌘V actually paste? Ask for the
    -- artefact before theorising about the mechanism.
    --
    -- So the sequence lives in MEMORY and nothing here touches a tab, the
    -- store, the 4 PM task or the export. LL's existing Collect tab is left
    -- exactly where it is — it is his text, and this release stops feeding
    -- it, it does not delete it.
    --
    -- 🔑 THE RESET RULE, LL's choice of the three offered: COPYING ANYTHING
    -- ELSE STARTS A NEW SEQUENCE. Nothing else marks where one run of grabs
    -- ends, and a sequence that never ends is the bug above with a shorter
    -- memory. We know the change counter we last wrote, so a counter that
    -- has moved means somebody else copied and the next ⇪2 starts clean.
    --
    -- 🪟 IT NEVER RAISES THE WINDOW. The whole point is that you stay in
    -- the page you are reading; an alert names the running count instead.
    --
    -- 🛟 DEGRADES: no power_tools → it says the selection cannot be read
    -- and does nothing. A pasteboard that refuses the write is REPORTED,
    -- not swallowed, and the grabs STAY in the sequence — the next press
    -- carries them all, so a refused write costs a paste, never a grab.
    sp.collectTitle = "Collect"  -- the old tab's name; the report still points at it
    sp.collectJoin  = "\n\n"     -- between grabs; a settings override changes it
    sp.collectId    = nil        -- 6.182.0's tab, still remembered so the report can name it
    sp.collectSeq   = {}         -- the grabs in the CURRENT sequence, in order
    sp.collectCount = 0          -- #sp.collectSeq, kept beside it for the alert
    sp.collectMark  = nil        -- the pasteboard change counter we last wrote
    sp.collectLast  = nil        -- the block we last wrote, for the degrade below
    sp.collectResets = 0         -- sequences ended because something else copied
    sp.collectWhy   = "nothing grabbed yet"

    -- 🔑 IS THE CLIPBOARD STILL THE ONE WE LEFT? Pure, and it is the whole
    -- reset rule. The change counter is asked FIRST because it sees the two
    -- writes a comparison never can — the same text copied again, and
    -- anything that is not text. The CONTENTS are the degrade, for a
    -- Hammerspoon that cannot answer changeCount.
    --
    -- 🚨 NEITHER READABLE MEANS "NOT OURS" — the OPPOSITE default to
    -- pt.borrowIntact, deliberately. There the last resort has to be
    -- 6.132.0's promise that your clipboard comes back; here it has to be
    -- the promise this release exists to make, that ⌘V never pastes
    -- something you did not just grab. Each default protects the thing its
    -- own feature would otherwise destroy, and neither is a house style.
    function sp.collectContinues(markNow, textNow)
        if type(sp.collectMark) == "number" and type(markNow) == "number" then
            return markNow == sp.collectMark
        end
        if type(sp.collectLast) == "string" and type(textNow) == "string" then
            return textNow == sp.collectLast
        end
        return false
    end

    -- Start a fresh sequence, saying why. ONE place decides, so "how many
    -- grabs did that drop" is answered rather than guessed at.
    function sp.collectReset(why)
        local had = #sp.collectSeq
        sp.collectSeq, sp.collectCount = {}, 0
        sp.collectLast, sp.collectMark = nil, nil
        sp.collectWhy = why or "reset"
        if had > 0 then sp.collectResets = (sp.collectResets or 0) + 1 end
        return had
    end

    -- text → ok, block-or-why. PURE now — no tab, no store, no window, no
    -- alert — which is why the whole rule can be proven without a Mac.
    function sp.collect(text)
        text = trim(text)
        if text == "" then return false, "nothing was selected" end
        sp.collectSeq[#sp.collectSeq + 1] = text
        sp.collectCount = #sp.collectSeq
        return true, table.concat(sp.collectSeq, tostring(sp.collectJoin or "\n\n"))
    end

    function sp.open()
        if not sp.enabled then return end
        if sp.webview then return end
        if not (hs.webview and hs.webview.usercontent) then promptFallback() return end
        if #sp.tabs == 0 then sp.newTab("") end

        local screen = hs.screen.mainScreen and hs.screen.mainScreen()
        local sf = screen and screen:frame() or { x = 0, y = 0, w = 1440, h = 900 }
        local w = math.min(sp.width, sf.w - 40)
        local h = math.min(sp.height, sf.h - 40)
        local rect = { x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 3, w = w, h = h }
        if sp.pos and _G.clampToScreen then
            local okC, p = pcall(_G.clampToScreen, sp.pos, w, h)
            if okC and type(p) == "table" then rect.x, rect.y = p.x, p.y end
        end

        local okUc, uc = pcall(hs.webview.usercontent.new, "scratchPad")
        if not (okUc and uc) then promptFallback() return end
        sp.uc = uc     -- HELD: collect this and the JS bridge goes quiet
        pcall(function()
            uc:setCallback(function(msg)
                local ok, err = pcall(handleMessage, msg and msg.body)
                if not ok then print("📝 Scorp Pad: message handler — " .. tostring(err)) end
            end)
        end)
        local okV, view = pcall(hs.webview.new, rect, {}, uc)
        if not (okV and view) then sp.uc = nil; promptFallback() return end
        sp.webview = view
        pcall(function() view:windowTitle("Scorp Pad") end)
        pcall(function() view:allowTextEntry(true) end)
        pcall(function() view:closeOnEscape(false) end)
        pcall(function() view:level(hs.drawing.windowLevels.floating) end)
        -- 6.171.0 — the window itself is translucent (LL: 35%); the page keeps its own colours.
        if type(sp.alpha) == "number" and sp.alpha > 0 and sp.alpha < 1 then
            pcall(function() view:alpha(sp.alpha) end)
        end
        pcall(function() view:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" }) end)
        sp.nonActivatingApplied, sp.nonActivatingWhy = false, "not requested"
        if sp.nonActivating then
            sp.nonActivatingApplied, sp.nonActivatingWhy = sp.applyNonActivating(view)
            if not sp.nonActivatingApplied then
                print("📝 Scorp Pad: non-activating panel unavailable — "
                      .. tostring(sp.nonActivatingWhy) .. "; opening the pad will bring Hammerspoon forward.")
            end
        end
        sp.render()
        pcall(function() view:show() end)
        if sp.focusOnOpen then pcall(function() view:bringToFront(true) end) end
        -- 6.165.1 — this pad has the keyboard now; nobody holds ⇪ through
        -- that. If the F18 keyUp was lost on the way in, the watchdog
        -- lets go after 1.5 s of silence instead of 8.
        if _G.hyperExpectRelease then pcall(_G.hyperExpectRelease, 1.5, "the scratch pad") end
        sp.opens = sp.opens + 1
        say("pad opened — " .. #sp.tabs .. " tab" .. (#sp.tabs == 1 and "" or "s"))
    end
    sp.toggle = sp.show

    -- ---- registrations ------------------------------------------------------------
    sp.load()
    if #sp.tabs == 0 then sp.tabs = { { id = newId(), text = "", createdAt = os.time(), updatedAt = os.time() } }; sp.active = sp.tabs[1].id end

    core.hyperAddShortcut({}, sp.key, function() sp.toggle() end, "scratch pad")

    -- 📎 6.182.0 — ⇪2, the sequential copy. The selection is read through
    -- power_tools' one reader (accessibility first, ⌘C as the fallback,
    -- and it is the thing that says so honestly when an app answers
    -- neither), so this module never grows a second way to read a
    -- selection. No power_tools → the key says so and does nothing.
    sp.collectKey = "2"
    function sp.collectFromSelection()
        if not (_G.service and _G.service.has and _G.service.has("power.readSelection")) then
            pcall(function() hs.alert.show("📎 Sequential copy needs Power Tools\n(it is what reads the selection)", 3) end)
            return false, "power_tools is not loaded"
        end
        -- 🔑 6.201.0 — THE RESET IS DECIDED HERE, BEFORE THE SELECTION IS
        -- READ, and that is not a preference. power_tools BORROWS the
        -- pasteboard to read a ⌘C selection: it saves it, clears it,
        -- presses ⌘C and hands the result over, so by the time `text`
        -- arrives the change counter has moved two or three times and no
        -- longer says anything about who copied last. This is the only
        -- moment the question can be asked honestly.
        local markNow, textNow
        pcall(function() markNow = hs.pasteboard.changeCount() end)
        pcall(function() textNow = hs.pasteboard.getContents() end)
        if not sp.collectContinues(markNow, textNow) then
            sp.collectReset("something else was copied")
        end
        _G.service.call("power.readSelection", "📎", function(text)
            local ok, blockOrWhy = sp.collect(text)
            if not ok then
                pcall(function() hs.alert.show("📎 " .. tostring(blockOrWhy), 2) end)
                return
            end
            -- 📋 6.198.0 — THREE values, not two. hs.pasteboard.setContents
            -- answers FALSE on a refusal without throwing, so reading only
            -- pcall's own ok reported every refusal as a copy that worked
            -- — and the alert below then promised "⌘V pastes the block"
            -- over a pasteboard that had just said no. CLAUDE.md's 6.179.0
            -- rule, in the place it mattered most: this alert is the ONLY
            -- thing standing between LL and a ⌘V that pastes the wrong
            -- thing, so it is not allowed to be optimistic.
            local wrote  = false
            local okSet  = pcall(function()
                wrote = hs.pasteboard.setContents(blockOrWhy) ~= false
            end)
            local copied = okSet and wrote
            -- 🔑 REMEMBER WHAT WE LEFT so the NEXT press can tell whether
            -- anything else has copied since. Read AFTER the write — this
            -- is the counter the reset rule compares against, and reading
            -- it before would compare against the borrow's own clearing.
            -- A REFUSED write leaves no block of ours out there, so
            -- collectLast is cleared; the counter is still recorded,
            -- because nothing else copied either and the grabs already in
            -- the sequence are still worth carrying to the next press.
            sp.collectMark = nil
            pcall(function() sp.collectMark = hs.pasteboard.changeCount() end)
            sp.collectLast = copied and blockOrWhy or nil
            sp.collectWhy  = copied
                and (sp.collectCount .. (sp.collectCount == 1 and " grab" or " grabs")
                     .. " on the clipboard")
                or  "⚠️ the pasteboard REFUSED the block"
            local words = select(2, tostring(blockOrWhy):gsub("%S+", ""))
            pcall(function()
                hs.alert.show(string.format("📎 %d %s · %d words%s", sp.collectCount,
                    sp.collectCount == 1 and "grab" or "grabs", words,
                    copied and "  ·  ⌘V pastes the block"
                            or "\n⚠️ the clipboard refused — press again to retry"), 2)
            end)
        end)
        return true
    end
    core.hyperAddShortcut({}, sp.collectKey, function() sp.collectFromSelection() end,
                          "sequential copy")

    if _G.claimEscape then
        _G.claimEscape("scratchpad", nil, function() return sp.webview ~= nil and not sp.pinned end,
                       function() sp.hide() end)
    end

    _G.movablePanels = _G.movablePanels or {}
    table.insert(_G.movablePanels, {
        name  = "scratch pad",
        frame = function() return sp.webview and sp.webview:frame() end,
        move  = function(x, y)
            if not sp.webview then return end
            local f = sp.webview:frame()
            sp.webview:frame({ x = x, y = y, w = f.w, h = f.h })
            sp.pos = { x = x, y = y }
        end,
    })

    _G.editors = _G.editors or {}
    table.insert(_G.editors, {
        name  = "Scorp Pad",
        key   = "⇪" .. sp.key,
        what  = "tabs saved as you type; ⇪N / ⇪2 open here too",
        order = 22,
        view  = function()
            if sp.webview then return sp.webview end
            local host = sp.host()
            if host and host.webview and host.doc and host.doc.scratch then return host.webview end
            return nil
        end,
        show  = function()
            local host = sp.host()
            if sp.webview then return end
            if host then if not (host.webview and host.doc and host.doc.scratch) then host.showScratch(nil) end
            else sp.show() end
        end,
        size  = function() local t = sp.activeTab(); return t and #(t.text or "") or 0 end,
        text  = function() local t = sp.activeTab(); return t and t.text or "" end,
    })

    core.provide("scratch.show",   function() sp.show() return true end)
    core.provide("scratch.send",   function() return sp.send("service") end)
    core.provide("scratch.report", function() return _G.scratchPadReport() end)

    function _G.scratchPadReport()
        local L = {}
        L[#L + 1] = "📝 Scorp Pad — ⇪" .. sp.key .. (sp.enabled and "" or " (disabled)")
        L[#L + 1] = "   store: " .. sp.file .. (sp.lastSaveErr and ("  ⚠️ " .. sp.lastSaveErr) or "")
        L[#L + 1] = "   tabs: " .. #sp.tabs .. " · history: " .. #sp.history
                    .. " · saves: " .. sp.saves .. " · failed writes: " .. (sp.saveFails or 0)
                    .. (sp.dirty and " · unsaved keystrokes pending" or "")
        -- 📎 6.201.0 — THE SEQUENTIAL COPY HAD NO REPORT AT ALL, which is
        -- how it shipped a clipboard nobody could inspect: the alert said
        -- "1 grab" while ⌘V pasted months of text and there was no line
        -- anywhere that disagreed. Say what ⌘V would paste RIGHT NOW, and
        -- why the sequence is the length it is.
        local seqChars = #table.concat(sp.collectSeq or {}, tostring(sp.collectJoin or "\n\n"))
        L[#L + 1] = "   📎 ⇪2: " .. (sp.collectCount or 0)
                    .. ((sp.collectCount == 1) and " grab" or " grabs")
                    .. " in this sequence · " .. seqChars .. " characters"
                    .. " · " .. tostring(sp.collectWhy)
        L[#L + 1] = "      sequences ended by another copy: " .. (sp.collectResets or 0)
                    .. " · THIS SESSION only — a reload starts a new sequence"
        if sp.collectId then
            local old
            for _, t in ipairs(sp.tabs) do if t.id == sp.collectId then old = t end end
            L[#L + 1] = "      the pre-6.201.0 📎 " .. tostring(sp.collectTitle) .. " tab is "
                        .. (old and ("still in the pad, untouched — " .. #tostring(old.text)
                                     .. " characters, and nothing writes to it now")
                                 or "no longer among the tabs (⌘W sent it to the history)")
            -- 🚨 6.201.1 — AND IT IS STILL IN THE 4 PM TASK. sp.newTab was
            -- called without a `kind` (358), so dayBody's `not t.kind`
            -- test (646) has swept that tab into LL's Asana task EVERY DAY
            -- since 6.182.0, growing with it. 6.201.0 stopped feeding the
            -- tab; it cannot stop this without deleting or closing his
            -- text, which is not a release's decision to make. So it is
            -- SAID, with the one keystroke that ends it.
            if old and trim(old.text) ~= "" and not old.kind then
                L[#L + 1] = "      ⚠️ …and it still rides the 4 PM Asana task, as every open"
                            .. " tab does — ⌘W on that tab in ⇪N is what ends it"
            end
        end
        -- 6.177.0 — the way out, and whether it has been taken
        if sp.exportToVault == false then
            L[#L + 1] = "   export: off (settings: scratch_pad.exportToVault)"
        else
            local dir, how = sp.exportDir()
            L[#L + 1] = "   export: ⌘⇧S → " .. dir
                        .. (how == "local" and "  (no OneDrive found — local only)" or "")
                        .. (how == "cloud" and "  (the vault module is not loaded)" or "")
            local e = sp.lastExport
            L[#L + 1] = "   last  : " .. (e and (e.wrote .. " written " .. os.date("%b %d %H:%M", e.at)
                        .. " (" .. tostring(e.why) .. ")"
                        .. (e.failed > 0 and (" · " .. e.failed .. " failed") or ""))
                        or "never — _G.scorpPadExport() writes them now")
        end
        local host = sp.host()
        L[#L + 1] = "   window: " .. (host and "the Vault's (⇪1 opens the tabs there; viaVault = false for its own)" or "its own")
        L[#L + 1] = "   pad: " .. ((sp.webview or (host and host.webview)) and "open" or "closed") .. (sp.pinned and " · 📌 pinned" or "")
                    .. " · opens: " .. sp.opens .. " · non-activating: " .. tostring(sp.nonActivatingWhy)
        L[#L + 1] = "   4 PM: at " .. sp.sendAt .. " · " .. sp.startTime .. " → " .. sp.dueTime
                    .. " · assignee " .. sp.assignee .. " · "
                    .. (sp.sendTimer and "armed" or "NOT armed")
                    .. " · Asana " .. (core.asanaEnabled and "on" or "off on this Mac")
        if sp.lastSend then
            L[#L + 1] = "   last send: " .. os.date("%b %d %H:%M", sp.lastSend.at) .. " (" .. sp.lastSend.reason
                        .. ") — " .. sp.lastSend.outcome
        else
            L[#L + 1] = "   last send: never this session"
        end
        local out = table.concat(L, "\n")
        print(out)
        return out
    end
end

function M.warm(core)
    local sp = M.config
    if not sp then return end
    local ok, t = pcall(hs.timer.doAt, sp.sendAt, "1d", function() pcall(sp.send, "scheduled") end)
    if ok and t then sp.sendTimer = t     -- HELD
    else
        print("📝 Scorp Pad: the " .. sp.sendAt .. " send is not armed — " .. tostring(t))
        if _G.notices and _G.notices.record then
            pcall(_G.notices.record, "scratch", "the 4 PM task is not armed", tostring(t))
        end
    end
end

return M
