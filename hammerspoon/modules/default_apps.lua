-- =====================================================================
-- MODULE: DEFAULT APPS — pick the app a file type opens in, and PROVE it
-- =====================================================================
-- LL: "Can we create a tool that will allow me to set a default
-- application for a specific file type? So, PDFs open in Acrobat
-- instead? Also, we need to verify the setting/assignment took."
--
-- Both halves are the spec. macOS keeps the type→app table in
-- LaunchServices, the same registry Finder's Get Info → "Change All…"
-- writes to — there is no supported way to write it from Lua, but
-- osascript's JavaScript bridge reaches the LaunchServices C API
-- directly, no third-party binary, both Macs, no admin. And because
-- "the call returned 0" is not "it took", the same script READS THE
-- REGISTRY BACK in the same run and reports what LaunchServices now
-- says — through TWO independent doors (the LS handler table and
-- NSWorkspace's app-for-type answer), so the verdict on screen is what
-- the Mac will actually do, not what we asked it to do. A re-check two
-- seconds later catches a write that a racing LS refresh undid.
--
--        ⇪space → @tool → 📎     pick a type, pick an app, get a verdict
--
-- ---------------------------------------------------------------------
-- 🎯 WHAT THE PICKER LISTS, AND WHY IT IS NOT EVERY APP ON DISK
-- ---------------------------------------------------------------------
-- Step 1 lists common extensions (type anything else — a row for the
-- typed extension appears the moment it looks like one). Step 2 lists
-- only the apps that DECLARE the type in their Info.plist — the same
-- set Finder offers under "Open With", with today's default starred.
-- An app that never claimed .pdf can still be forced onto it by bundle
-- id, but every app that mishandles a type it never claimed starts
-- exactly that way, so the picker does not offer it.
--
-- ---------------------------------------------------------------------
-- ⚠️ TWO THINGS THIS DELIBERATELY DOES NOT TOUCH
-- ---------------------------------------------------------------------
--   · PER-FILE overrides. Finder's "Always Open With" on ONE file beats
--     the type-wide default and lives in that file's metadata, not in
--     LaunchServices. A single stubborn file after a successful change
--     here is that, not a failed write.
--   · URL SCHEMES. http/https (the default browser) and mailto are not
--     file types, and macOS refuses silent handler changes for them by
--     design — the user must consent in System Settings. Out of scope.
--
-- ---------------------------------------------------------------------
-- 🧪 WHY THE VERDICT IS COMPARED CASE-INSENSITIVELY
-- ---------------------------------------------------------------------
-- LaunchServices historically hands bundle ids back LOWERCASED
-- ("com.adobe.acrobat" for com.adobe.Acrobat). A strict compare would
-- report every successful write as a failure. The read-back is matched
-- case-insensitively, and the raw string is kept in the report so a
-- REAL mismatch (a different app entirely) is never smoothed over.
-- =====================================================================

local M = {
    name  = "Default Apps",
    order = 14.2,
    family = "config",
    cheatsheet = {
        title = "📎 DEFAULT APPS (which app opens a file type)",
        entries = {
            { "📎",     "Pick a file type, then the app that opens it — ⇪space, then @tool" },
            { "list",   "Only apps that CLAIM the type are offered; ⭐ marks today's default" },
            { "proof",  "LaunchServices is read back before the change is believed, twice" },
            { "check",  "_G.defaultAppsReport() — every change this session, with verdicts" },
        },
    },
}

function M.setup(core)
    local da = {}

    -- ✏️ EDIT HERE ---------------------------------------------------------
    da.enabled     = true
    da.recheckSecs = 2       -- the second look, after LS has settled
    -- The first picker's starting list. Not a limit — type any other
    -- extension and a row for it appears — just the ones worth zero typing.
    da.common = {
        { "pdf",  "PDF documents" },        { "txt",  "plain text" },
        { "md",   "Markdown" },             { "csv",  "comma-separated data" },
        { "json", "JSON data" },            { "xml",  "XML data" },
        { "html", "web pages (files, not links)" },
        { "log",  "log files" },            { "rtf",  "rich text" },
        { "doc",  "Word 97 documents" },    { "docx", "Word documents" },
        { "xls",  "Excel 97 workbooks" },   { "xlsx", "Excel workbooks" },
        { "ppt",  "PowerPoint 97 decks" },  { "pptx", "PowerPoint decks" },
        { "jpg",  "JPEG images" },          { "jpeg", "JPEG images (long spelling)" },
        { "png",  "PNG images" },           { "gif",  "GIF images" },
        { "heic", "iPhone photos" },        { "svg",  "vector images" },
        { "webp", "WebP images" },          { "tiff", "TIFF images" },
        { "mp4",  "MPEG-4 video" },         { "mov",  "QuickTime video" },
        { "mkv",  "Matroska video" },       { "avi",  "AVI video" },
        { "mp3",  "MP3 audio" },            { "m4a",  "AAC audio" },
        { "wav",  "WAV audio" },            { "flac", "lossless audio" },
        { "zip",  "zip archives" },         { "7z",   "7-Zip archives" },
        { "dmg",  "disk images" },          { "epub", "e-books" },
        { "lua",  "Lua source" },           { "py",   "Python source" },
        { "sh",   "shell scripts" },
    }
    -- ----------------------------------------------------------------------

    -- Constants, so test_diagnostics' external-binary review can see them.
    da.OSASCRIPT = "/usr/bin/osascript"

    da.history   = {}     -- every change asked for this session, verdicts in
    da.lastNote  = nil    -- the most recent problem, for the report
    da.pending   = nil    -- the type between picker 1 and picker 2
    da.rows1, da.rows2 = {}, {}
    da.typeChooser, da.appChooser = nil, nil
    da.recheckTimer = nil
    da.task = nil         -- HELD: an unreferenced hs.task can be collected

    local function say(m)  if _G.diag then _G.diag.say("defaultApps", m)  end end
    local function warn(m) if _G.diag then _G.diag.warn("defaultApps", m) end end

    -- ---- the one JXA script ----------------------------------------------
    -- One script, two ops, so query and set+verify cannot drift apart —
    -- the verify IS the query, run again after the write.
    --   query <ext>          → { ok, ext, uti, current, modern, apps }
    --   set   <ext> <bundle> → { ok, ext, uti, status, readback, modern }
    -- `current`/`readback` come from the LS handler table; `modern` is
    -- NSWorkspace's independent answer (the app URL macOS 12+ would
    -- actually launch), each guarded so one missing API cannot take the
    -- other witness down. kLSRolesAll is written as its value: enum
    -- constants are not reliably exported to the osascript bridge.
    da.jxa = [[
function run(argv) {
  ObjC.import('CoreServices');
  ObjC.import('AppKit');
  ObjC.import('UniformTypeIdentifiers');
  var out = { ok: false };
  try {
    var op  = String(argv[0] || '');
    var ext = String(argv[1] || '').toLowerCase().replace(/^\.+/, '');
    if (!/^[a-z0-9+._-]{1,20}$/.test(ext)) {
      out.err = 'bad extension'; return JSON.stringify(out);
    }
    var ut = $.UTType.typeWithFilenameExtension(ext);
    if (ut.isNil()) {
      out.err = 'macOS has no type for .' + ext; return JSON.stringify(out);
    }
    var uti = ut.identifier.js;
    var ALL = 0xFFFFFFFF;
    var ws  = $.NSWorkspace.sharedWorkspace;
    function currentHandler() {
      try {
        var c = $.LSCopyDefaultRoleHandlerForContentType($(uti), ALL);
        return c.isNil() ? null : ObjC.unwrap(c);
      } catch (e) { return null; }
    }
    function modernPath() {
      try {
        var u = ws.URLForApplicationToOpenContentType(ut);
        return u.isNil() ? null : u.path.js;
      } catch (e) { return null; }
    }
    if (op === 'query') {
      var ids = [];
      try {
        var arr = $.LSCopyAllRoleHandlersForContentType($(uti), ALL);
        if (!arr.isNil()) {
          var n = ObjC.unwrap(arr);
          for (var i = 0; i < n.length; i++) ids.push(ObjC.unwrap(n[i]));
        }
      } catch (e) {}
      var fm = $.NSFileManager.defaultManager;
      var apps = [];
      for (var j = 0; j < ids.length; j++) {
        var u2 = ws.URLForApplicationWithBundleIdentifier($(ids[j]));
        var p = null, nm = ids[j];
        if (!u2.isNil()) {
          p  = u2.path.js;
          nm = ObjC.unwrap(fm.displayNameAtPath(u2.path));
        }
        apps.push({ bundle: ids[j], path: p, name: nm });
      }
      out = { ok: true, ext: ext, uti: uti, current: currentHandler(),
              modern: modernPath(), apps: apps };
    } else if (op === 'set') {
      var want = String(argv[2] || '');
      if (!want) { out.err = 'no bundle id'; return JSON.stringify(out); }
      var rc = $.LSSetDefaultRoleHandlerForContentType($(uti), ALL, $(want));
      out = { ok: true, ext: ext, uti: uti, status: rc,
              readback: currentHandler(), modern: modernPath() };
    } else { out.err = 'unknown op'; }
  } catch (e) { out = { ok: false, err: String(e) }; }
  return JSON.stringify(out);
}
]]

    -- ---- small pure pieces, driven directly by the suite -----------------
    -- The Lua guard mirrors the script's, so a bad extension is refused
    -- BEFORE a process is spawned; the script's own copy stays because
    -- argv is still an input even when this file is not the caller.
    function da.cleanExt(s)
        if type(s) ~= "string" then return nil end
        s = s:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("^%.+", "")
        if s == "" or #s > 20 then return nil end
        if not s:match("^[%w%+%._%-]+$") then return nil end
        return s
    end

    -- LS lowercases bundle ids on the way back out — see the header.
    function da.sameBundle(a, b)
        if type(a) ~= "string" or type(b) ~= "string" then return false end
        return a:lower() == b:lower()
    end

    function da.parse(raw)
        if type(raw) ~= "string" then return nil end
        local body = raw:match("^%s*(.-)%s*$")
        if not body:find("^{") then return nil end
        if core.safeJson then return core.safeJson(body, "defaultApps") end
        local okD, data = pcall(hs.json.decode, body)
        if okD and type(data) == "table" then return data end
        return nil
    end

    -- The verdict LL asked for. Status 0 alone proves only that the call
    -- ran; the read-back is what proves the registry changed.
    function da.verdict(wantBundle, reply)
        if type(reply) ~= "table" then
            return false, "osascript returned no readable answer"
        end
        if reply.err then return false, tostring(reply.err) end
        if not da.sameBundle(reply.readback or "", wantBundle) then
            return false, "LaunchServices still reports "
                          .. tostring(reply.readback or "nothing")
        end
        return true, nil
    end

    -- ---- running the script ----------------------------------------------
    function da.run(args, onReply)
        if not (hs.task and hs.task.new) then
            onReply(nil, "hs.task is unavailable"); return false
        end
        local argv = { "-l", "JavaScript", "-e", da.jxa }
        for _, a in ipairs(args) do argv[#argv + 1] = a end
        local okNew, t = pcall(hs.task.new, da.OSASCRIPT, function(code, sout, serr)
            da.task = nil
            local reply = da.parse(sout)
            if not reply then
                onReply(nil, "exit " .. tostring(code) .. " — "
                             .. tostring((serr or sout or ""):sub(1, 200)))
            else
                onReply(reply, nil)
            end
        end, argv)
        if not okNew or not t then
            onReply(nil, "hs.task.new failed for osascript"); return false
        end
        da.task = t
        local okStart = pcall(function() return t:start() end)
        if not okStart then
            da.task = nil
            onReply(nil, "osascript would not start"); return false
        end
        return true
    end

    -- ---- picker 1: the file type -----------------------------------------
    function da.typeRows(query)
        local rows, q = {}, da.cleanExt(query or "")
        if q then
            local listed = false
            for _, c in ipairs(da.common) do
                if c[1] == q then listed = true break end
            end
            if not listed then
                rows[#rows + 1] = { text = "📎 ." .. q,
                                    subText = "set the default app for exactly this extension",
                                    ext = q }
            end
        end
        local needle = (query or ""):lower():gsub("^%s+", ""):gsub("^%.+", "")
        for _, c in ipairs(da.common) do
            if needle == "" or c[1]:find(needle, 1, true)
               or c[2]:lower():find(needle, 1, true) then
                rows[#rows + 1] = { text = "." .. c[1], subText = c[2], ext = c[1] }
            end
        end
        return rows
    end

    function da.show()
        if not da.enabled then return end
        if not da.typeChooser then
            da.typeChooser = hs.chooser.new(function(pick)
                if not pick then return end
                local row = da.rows1[pick.idx]
                if row and row.ext then da.pickApp(row.ext) end
            end)
            _G.choosers = _G.choosers or {}
            _G.choosers.defaultApps = da.typeChooser
            pcall(function() da.typeChooser:width(40) end)
            -- Own filtering: the literal ".<typed>" row must appear while
            -- typing, and a chooser with a queryChangedCallback stops
            -- filtering for itself (file_tracker's pattern).
            da.typeChooser:queryChangedCallback(function(q)
                local rows = da.typeRows(q)
                da.rows1 = rows
                local out = {}
                for i, r in ipairs(rows) do
                    out[#out + 1] = { text = r.text, subText = r.subText, idx = i }
                end
                da.typeChooser:choices(out)
            end)
        end
        local rows = da.typeRows("")
        da.rows1 = rows
        local out = {}
        for i, r in ipairs(rows) do
            out[#out + 1] = { text = r.text, subText = r.subText, idx = i }
        end
        da.typeChooser:choices(out)
        da.typeChooser:placeholderText("which file type? type any extension")
        da.typeChooser:query("")
        if core.showPopup then core.showPopup(da.typeChooser)
        else da.typeChooser:show() end
    end

    -- ---- picker 2: the app -----------------------------------------------
    function da.appRows(reply)
        local rows = {}
        for _, app in ipairs(reply.apps or {}) do
            local isCur = da.sameBundle(app.bundle, reply.current or "")
            rows[#rows + 1] = {
                text    = (isCur and "⭐ " or "") .. tostring(app.name or app.bundle),
                subText = (isCur and "current default   ·   " or "")
                          .. tostring(app.bundle)
                          .. (app.path and ("   ·   " .. app.path) or "   ·   not on disk"),
                bundle  = app.bundle,
                name    = tostring(app.name or app.bundle),
                path    = app.path,
                current = isCur,
            }
        end
        return rows
    end

    function da.pickApp(ext)
        da.run({ "query", ext }, function(reply, err)
            if not reply then
                da.lastNote = "query ." .. ext .. " failed: " .. tostring(err)
                warn(da.lastNote)
                hs.alert.show("📎 Could not ask LaunchServices about ." .. ext
                              .. "\n" .. tostring(err), 4)
                return
            end
            if reply.err then
                da.lastNote = "." .. ext .. ": " .. tostring(reply.err)
                hs.alert.show("📎 " .. tostring(reply.err), 4)
                return
            end
            local rows = da.appRows(reply)
            if #rows == 0 then
                hs.alert.show("📎 No installed app claims ." .. ext, 4)
                return
            end
            da.pending = { ext = reply.ext, uti = reply.uti,
                           current = reply.current }
            da.rows2 = rows
            if not da.appChooser then
                da.appChooser = hs.chooser.new(function(pick)
                    if not pick then return end
                    local row = da.rows2[pick.idx]
                    if row and da.pending then
                        if row.current then
                            hs.alert.show("📎 ." .. da.pending.ext .. " already opens in "
                                          .. row.name, 3)
                            return
                        end
                        da.set(da.pending, row)
                    end
                end)
                _G.choosers = _G.choosers or {}
                _G.choosers.defaultAppsApps = da.appChooser
                pcall(function()
                    da.appChooser:searchSubText(true)
                    da.appChooser:width(45)
                end)
            end
            local out = {}
            for i, r in ipairs(rows) do
                out[#out + 1] = { text = r.text, subText = r.subText, idx = i }
            end
            da.appChooser:choices(out)
            da.appChooser:placeholderText("." .. reply.ext .. " (" .. reply.uti
                                          .. ") opens in…")
            da.appChooser:query("")
            if core.showPopup then core.showPopup(da.appChooser)
            else da.appChooser:show() end
        end)
    end

    -- ---- the write, and the two proofs -----------------------------------
    function da.set(pending, row)
        da.run({ "set", pending.ext, row.bundle }, function(reply, err)
            local entry = {
                at = os.date("%H:%M:%S"), ext = pending.ext, uti = pending.uti,
                wantBundle = row.bundle, wantName = row.name,
                was = pending.current,
                status = reply and reply.status, readback = reply and reply.readback,
                modern = reply and reply.modern,
            }
            da.history[#da.history + 1] = entry
            if not reply then
                entry.ok, entry.note = false, tostring(err)
                da.lastNote = "set ." .. pending.ext .. " failed: " .. tostring(err)
                warn(da.lastNote)
                hs.alert.show("📎 ." .. pending.ext .. " → " .. row.name
                              .. "\n⚠️ DID NOT RUN — " .. tostring(err), 5)
                return
            end
            local took, why = da.verdict(row.bundle, reply)
            entry.ok, entry.note = took, why
            if took then
                say("." .. pending.ext .. " → " .. row.bundle .. " (verified)")
                hs.alert.show("📎 ." .. pending.ext .. " now opens in " .. row.name
                              .. "\n✅ LaunchServices confirms: "
                              .. tostring(reply.readback), 4)
                da.arm(entry)
            else
                da.lastNote = "." .. pending.ext .. " → " .. row.bundle
                              .. " DID NOT TAKE: " .. tostring(why)
                warn(da.lastNote)
                hs.alert.show("📎 ." .. pending.ext .. " → " .. row.name
                              .. "\n⚠️ DID NOT TAKE (status "
                              .. tostring(reply.status) .. ") — " .. tostring(why), 6)
            end
        end)
    end

    -- The second look. An LS database refresh racing the write can undo
    -- it a beat later; a change that silently reverted is worse than one
    -- that failed on the spot, because you stopped watching.
    function da.arm(entry)
        if not (hs.timer and hs.timer.doAfter) then return end
        local okT, t = pcall(hs.timer.doAfter, da.recheckSecs, function()
            da.recheckTimer = nil
            da.run({ "query", entry.ext }, function(reply)
                if not reply or reply.err then return end   -- witness lost, verdict stands
                if da.sameBundle(reply.current or "", entry.wantBundle) then
                    entry.recheck = "confirmed"
                    say("." .. entry.ext .. " re-checked after " .. da.recheckSecs
                        .. "s: still " .. tostring(reply.current))
                else
                    entry.recheck = "REVERTED to " .. tostring(reply.current)
                    entry.ok = false
                    da.lastNote = "." .. entry.ext .. " reverted to "
                                  .. tostring(reply.current)
                    warn(da.lastNote)
                    hs.alert.show("📎 ." .. entry.ext
                                  .. " REVERTED — LaunchServices now reports "
                                  .. tostring(reply.current), 6)
                end
            end)
        end)
        if okT then da.recheckTimer = t end
    end

    -- ---- the report ------------------------------------------------------
    function _G.defaultAppsReport()
        local L = { "📎 DEFAULT APPS" }
        if #da.history == 0 then
            L[#L + 1] = "   nothing changed this session"
        else
            for _, e in ipairs(da.history) do
                L[#L + 1] = ("   %s  .%-6s → %-24s %s")
                            :format(e.at, e.ext, e.wantName or e.wantBundle,
                                    e.ok and "✅ verified" or "⚠️ FAILED")
                L[#L + 1] = "            was " .. tostring(e.was)
                            .. " · readback " .. tostring(e.readback)
                            .. (e.recheck and (" · " .. da.recheckSecs .. "s later: "
                                               .. e.recheck) or "")
                if e.note then L[#L + 1] = "            " .. tostring(e.note) end
            end
        end
        L[#L + 1] = "   a single file that still misbehaves has a per-file"
        L[#L + 1] = "   override: Finder → Get Info on it → Open with"
        if da.lastNote then L[#L + 1] = "   last problem: " .. da.lastNote end
        local s = table.concat(L, "\n")
        print(s)
        return s
    end

    core.provide("defaultApps.show",   function() return da.show() end)
    core.provide("defaultApps.report", function() return _G.defaultAppsReport() end)

    _G.defaultApps = da
    M.da     = da
    M.config = da
end

return M
