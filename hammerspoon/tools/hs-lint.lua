-- =====================================================================
-- hs-lint.lua — the bugs this config has actually shipped, made findable
-- =====================================================================
--     lua5.4 tools/hs-lint.lua [path to hammerspoon dir]
--
-- WHY THIS EXISTS, and why it is not a generic Lua linter. Every rule
-- below is a bug that REACHED LL'S MAC. Not a style opinion, not a
-- best-practice list copied from somewhere — a receipt. Each one names
-- the version it was found in, so nobody has to take the rule on trust.
--
-- THE POINT IS TO STOP FIXING THESE ONE AT A TIME. Every one of these
-- classes was found by a crash, a freeze, or a muted microphone, and
-- fixed in the single place it was noticed. A rule finds every OTHER
-- place it lives, today and in every file written after today.
--
-- ⚠️ A LINTER THAT CRIES WOLF GETS TURNED OFF. Rules here are narrow on
-- purpose: a check that is 80% right is worse than no check, because the
-- 20% teaches you to skim past output you should be reading. Where a
-- precise rule was not possible, the rule is not here.
--
-- ✏️ TO SILENCE ONE, put this on the line or the line above:
--        -- hs-lint: allow <rule-id> — <why>
-- The reason is REQUIRED. A bare suppression is itself reported: the
-- point of an exception is that someone thought about it, and a reason
-- is the only evidence that anyone did.

local HS = (arg and arg[1]) or "."
local findings, filesSeen = {}, 0

-- ---------------------------------------------------------------------
-- THE RULES
-- ---------------------------------------------------------------------
-- Each: id, severity, why (the receipt), and either `line` (per line) or
-- `file` (whole-file). Line functions get (code, lineNo, ctx) where
-- `code` has comments and string literals blanked out — see scrub().
local RULES = {}
local STRIP    -- forward declaration; defined below

local function rule(t) RULES[#RULES + 1] = t end

-- 🚨 6.65.1 — this crashed Hammerspoon on macOS 26.6.1, twice, with an
-- uncaught Objective-C exception in Apple Event handling.
rule{ id = "applescript-in-process", sev = "ERROR",
  why = "hs.osascript.applescript runs NSAppleScript IN PROCESS and sends "
     .. "Apple Events on the main thread. An ObjC exception there ABORTS "
     .. "the app, and a Lua pcall CANNOT catch it. Shell out to "
     .. "/usr/bin/osascript via hs.task (async) or hs.execute (sync).",
  line = function(code) return code:find("hs%.osascript%.applescript") end }

-- 🚨 6.62.0 — four times in one Console session, on a two-screen Mac.
rule{ id = "canvas-empty-elements", sev = "ERROR",
  why = "replaceElements({}) does NOT mean 'draw nothing'. hs.canvas only "
     .. "unwraps the single-table form when it is NON-empty, so {} is read "
     .. "as one element with no key-value pairs and THROWS. Substitute a "
     .. "single { action = 'skip' } element.",
  line = function(code) return code:find("replaceElements%s*%(%s*{%s*}%s*%)") end }

-- 🚨 6.64.0 — one character; the whole config failed to load.
rule{ id = "paren-starts-line", sev = "ERROR",
  why = "A line beginning with '(' continues the PREVIOUS statement. After "
     .. "x = f() it reads as calling f()'s return value: 'attempt to call a "
     .. "number value', and the config does not load at all. Lua has no "
     .. "statement terminator — end the previous line with a semicolon.",
  line = function(code, _, ctx)
      if not code:match("^%s*%(") then return false end
      return ctx.prevCode and ctx.prevCode:match("%)%s*$") ~= nil
  end }

-- 🚨 6.65.1 — caught before shipping, but only just.
rule{ id = "lua-quote-for-shell", sev = "ERROR",
  why = "('%q'):format is LUA quoting: it escapes a newline as "
     .. "backslash-newline. In the shell that is a line CONTINUATION, so a "
     .. "multi-line script arrives as one joined line and fails to compile. "
     .. "Use single quotes with '\\'' for embedded quotes.",
  line = function(code, _, ctx)
      if not code:find('%%q"?%s*%)?:?f?o?r?m?a?t?') then return false end
      if not code:find("%%q") then return false end
      return ctx.fileText:find("hs%.execute") or ctx.fileText:find("osascript")
  end }

-- 🚨 6.47.0 — a wedged app could hold the keyboard for as long as it liked.
rule{ id = "ax-without-timeout", sev = "ERROR", file = true,
  why = "Every hs.axuielement question crosses a process boundary and can "
     .. "hang. setTimeout() must be called on the element BEFORE anything "
     .. "is asked of it, or one wedged app holds the main thread — and "
     .. "with it your keyboard.",
  check = function(text)
      if not text:find("axuielement") then return end
      if not text:find("attributeValue") then return end
      if text:find("setTimeout") then return end
      return { 1, "this file asks Accessibility questions but never calls "
                  .. "setTimeout on the element" }
  end }

-- 🚨 A collected timer stops firing; a collected canvas vanishes; a
-- collected menubar item disappears from the menu bar. All three have
-- happened in this project, and all three look like "it works sometimes".
rule{ id = "unheld-object", sev = "WARN",
  why = "The result is discarded, so nothing references this object and Lua "
     .. "may collect it mid-life. A collected timer stops firing, a "
     .. "collected menubar item disappears, a collected hs.task is reaped "
     .. "before its callback runs. Assign it to something that outlives "
     .. "the call.",
  line = function(code)
      -- Only a BARE call at the start of a statement: no '=', no 'return',
      -- no 'local'. Anything assigned is by definition held.
      local s = code:match("^%s*(.*)$") or ""
      if s:match("^[%w_%.%[%]]+%s*=") or s:match("^local%s") or s:match("^return%s") then
          return false
      end
      return s:match("^hs%.timer%.doEvery%s*%(")
          or s:match("^hs%.timer%.doAfter%s*%(")
          or s:match("^hs%.menubar%.new%s*%(")
          or s:match("^hs%.pathwatcher%.new%s*%(")
          or s:match("^hs%.eventtap%.new%s*%(")
  end }

-- 🚨 6.65.0 — the Tool Picker would have reported "ran it" while doing
-- nothing at all.
rule{ id = "service-call-unchecked", sev = "WARN", file = true,
  why = "_G.service.call does NOT throw on a missing provider — it prints "
     .. "and returns nil. A pcall around it therefore succeeds whether the "
     .. "service ran or never existed. Check _G.service.has first when the "
     .. "outcome is reported back to the user.",
  check = function(text, name)
      if name == "init.lua" then return end          -- defines it
      if not text:find("service%.call") then return end
      if text:find("service%.has") then return end
      if not text:find("hs%.alert") then return end  -- only when it REPORTS
      return { 1, "calls service.call and reports an outcome, but never "
                  .. "checks service.has" }
  end }

-- 🚨 6.62.0 — the Capture Pad's queue and parked list became ONE table.
rule{ id = "adopt-decoded-table", sev = "WARN",
  why = "Assigning a JSON decoder's table straight into state adopts a "
     .. "table you did not build. Two fields can end up sharing one table, "
     .. "and every write to one is a write to the other. Copy element by "
     .. "element.",
  line = function(code)
      return code:match("=%s*hs%.json%.decode%s*%(") ~= nil
         and code:match("^%s*local%s") == nil
  end }

-- 🚨 SHIPPED IN 6.69.0 AND IT COST EVERY SNIPPET. hs.fs.dir returns TWO
-- values — the iterator AND the directory object it walks. The iterator
-- is a C function that reads the directory out of that second value on
-- every call, so dropping it hands the iterator a nil state:
--     bad argument #1 to 'for iterator' (directory metatable expected,
--     got nil)
-- warm() died on the first directory it touched and not one of LL's
-- 2,006 snippets loaded. capture_pad.lua had always had it right.
--
-- The two safe forms:
--     for entry in hs.fs.dir(path) do              -- for takes all three
--     local it, obj = hs.fs.dir(path) ; for e in it, obj do
-- The unsafe one is capturing ONE value and iterating it alone, which is
-- what a pcall around the call makes easy to write by accident.
rule{ id = "fs-dir-loses-state", sev = "ERROR", file = true,
  why = "hs.fs.dir returns (iterator, directoryObject) and the iterator "
     .. "needs that second value. Capturing one variable and writing "
     .. "`for e in iter do` throws 'directory metatable expected, got "
     .. "nil' at runtime — never at load, so nothing catches it until "
     .. "the feature is silently dead. Capture both and iterate "
     .. "`in iter, dirObj`.",
  check = function(code)
      -- Names bound from an hs.fs.dir call, whether direct or via pcall.
      -- pcall(hs.fs.dir, …) puts `ok` first, so `local ok, iter = pcall(…)`
      -- captures TWO names and still only ONE real return value — which
      -- is exactly the shape that reads as correct and is not.
      local single = {}
      for names, rhs in code:gmatch("local%s+([%w_%s,]-)%s*=%s*([^\n]-hs%.fs%.dir[^\n]*)") do
          local parts = {}
          for id in names:gmatch("[%w_]+") do parts[#parts + 1] = id end
          local captured = rhs:find("pcall") and (#parts - 1) or #parts
          if captured == 1 and parts[#parts] then single[parts[#parts]] = true end
      end
      if not next(single) then return false end
      local n = 0
      for line in (code .. "\n"):gmatch("([^\n]*)\n") do
          n = n + 1
          for name in pairs(single) do
              -- `for e in iter do` — the state is missing. `in iter, obj`
              -- is the correct form and must not be flagged.
              if line:find("for%s+[%w_%s,]+%s+in%s+" .. name .. "%s+do") then
                  return { n, name .. " is the iterator alone — its "
                              .. "directory object was dropped" }
              end
          end
      end
      return false
  end }

-- 🚨 The cheat sheet is full of ⇪[ ⇪\ ⇪- ⇪/ ⇪= and every one of those is
-- a Lua pattern operator.
rule{ id = "pattern-on-variable", sev = "WARN",
  why = "find/match on a VARIABLE runs Lua's pattern engine over whatever "
     .. "that variable holds. A user-typed '[' or '%' is then a malformed "
     .. "pattern and throws. Pass true as find's fourth argument for plain "
     .. "text, or escape the input.",
  line = function(code)
      -- :find(ident) or :find(ident, n) — a literal pattern is fine, and a
      -- third `true` argument is the fix, so both are excluded.
      local inside = code:match(":find%s*%(([^%)]*)%)")
      if not inside then return false end
      if inside:find('"') or inside:find("'") then return false end   -- literal
      if inside:find("true") then return false end                    -- plain
      -- ✏️ THE CONVENTION, and it is enforced rather than assumed: a
      -- variable holding a DELIBERATE pattern is named `pat` or
      -- `pattern`. focus_mode's window rules and file_tracker's noise
      -- lists are patterns on purpose, and flagging them would teach
      -- everyone to skim this rule's output. Anything else holding a
      -- string being fed to find() is user text until proven otherwise.
      local id = inside:match("^%s*([%w_%.]+)%s*,?%s*%d*%s*$")
      if not id then return false end
      local base = id:match("([%w_]+)$") or id
      if base == "pat" or base == "pattern" or base == "pats" then return false end
      return true
  end }

-- 🚨 6.72.0 — FOUND BY LOADING ALL THREE KEYBOARD TAPS IN ONE PROCESS.
-- This config now has three eventtaps watching every keystroke, and two
-- of them TYPE BACK into the document. Every character either of them
-- injects arrives at the other two looking exactly like a keypress, so a
-- tap that does not check the shared guard will:
--   · read a correction or an expansion into its own buffer, and
--   · in the expander's case, EXPAND a word autocorrect just fixed.
-- The expander's header claimed it stood down for the guard. It did not;
-- only the write side went through withInjection. Nothing noticed until
-- the three ran together.
rule{ id = "keyboard-tap-ignores-injection", sev = "ERROR", file = true,
  why = "An hs.eventtap watching keyDown must check _G.typingInjection() "
     .. "and return early. Another module's synthetic typing is "
     .. "indistinguishable from yours at this layer, so without it a "
     .. "correction feeds a snippet expander and an expansion feeds a "
     .. "spelling corrector. See core/coexist.lua.",
  check = function(code)
      -- Only taps that watch keyDown. Mouse-only and scroll taps are not
      -- affected: nothing in this config injects those.
      if not code:find("hs%.eventtap%.new") then return false end
      if not code:find("types%.keyDown") then return false end
      if code:find("_G%.typingInjection") then return false end
      local n = 0
      for line in (code .. "\n"):gmatch("([^\n]*)\n") do
          n = n + 1
          if line:find("hs%.eventtap%.new") then
              return { n, "watches keyDown and never checks the guard" }
          end
      end
      return { 1, "watches keyDown and never checks the guard" }
  end }

-- 🚨 6.77.0 — RAIL 3 OF core/hyper_key.lua's GLOBAL FALLBACK, ENFORCED
-- RATHER THAN REMEMBERED. On a Mac whose Carbon hotkey layer is dead, the
-- event tap runs the handlers recorded from hs.hotkey.bind. That is only
-- safe because every one of them is permanently enabled: everything that
-- arms and disarms at runtime — the cheat sheet's keys, ⌥Tab's nav keys —
-- is built with hs.hotkey.new, which the recording wrapper never sees.
-- A bound-then-disabled hotkey would be fired by the tap WHILE DISABLED,
-- which is the cheat sheet's bare alphabet typing into nothing.
rule{ id = "bound-hotkey-later-disabled", sev = "ERROR", file = true,
  why = "A hotkey created with hs.hotkey.bind and later :disable()d is "
     .. "recorded in _G.globalDispatch and would still be fired by the "
     .. "event-tap fallback while disabled. Use hs.hotkey.new + :enable() "
     .. "for anything that arms and disarms — the wrapper never sees "
     .. "those, which is exactly the point. See core/hyper_key.lua.",
  check = function(code)
      local n, boundAt = 0, nil
      for line in (code .. "\n"):gmatch("([^\n]*)\n") do
          n = n + 1
          if line:match("^%s*%-%-") then goto continue end
          -- `local x = hs.hotkey.bind(` — a RETAINED bind, i.e. one whose
          -- object is kept, which is the only kind that can be disabled.
          local var = line:match("local%s+([%w_]+)%s*=%s*hs%.hotkey%.bind")
                   or line:match("([%w_%.%[%]\"']+)%s*=%s*hs%.hotkey%.bind")
          if var then boundAt = boundAt or { n, var } end
          if boundAt and line:find(":disable%(%)") then
              return { n, "a bind()-created hotkey is disabled here" }
          end
          ::continue::
      end
      return false
  end }

-- 🚨 The same three taps, the other half of the lesson. A callback that
-- throws does not stop — it raises into Hammerspoon's event machinery on
-- EVERY KEYSTROKE, and macOS switches off taps that behave that way.
rule{ id = "eventtap-callback-unguarded", sev = "WARN", file = true,
  why = "An hs.eventtap callback body should be pcall'd, returning false "
     .. "on failure. Everything inside reaches into an event object, and "
     .. "an error there escapes into the event system once per keystroke "
     .. "rather than failing once. Count consecutive failures and stand "
     .. "down rather than degrade the whole keyboard.",
  check = function(code)
      if not code:find("hs%.eventtap%.new") then return false end
      if not code:find("types%.keyDown") then return false end
      -- The guarded shape: a named handler invoked through pcall.
      if code:find("pcall%s*%(%s*[%w_%.]+%s*,%s*ev%s*%)") then return false end
      local n = 0
      for line in (code .. "\n"):gmatch("([^\n]*)\n") do
          n = n + 1
          if line:find("hs%.eventtap%.new") then
              return { n, "callback body is not pcall'd" }
          end
      end
      return { 1, "callback body is not pcall'd" }
  end }

-- 🚨 6.75.0 — A TWO-MINUTE BEACHBALL WAITING TO HAPPEN. hs.execute is
-- SYNCHRONOUS: it blocks the only thread Hammerspoon has. Run osascript
-- through it and you inherit AppleScript's DEFAULT TIMEOUT OF TWO
-- MINUTES — so a Finder or Outlook that is wedged (network volume,
-- mid-relaunch, waiting on a permissions prompt) freezes the Mac,
-- keyboard taps included, for as long as it sulks.
rule{ id = "sync-osascript-no-timeout", sev = "WARN", file = true,
  why = "A synchronous osascript with no `with timeout of N seconds` "
     .. "inherits AppleScript's two-minute default and blocks "
     .. "Hammerspoon's only thread for all of it. Wrap the script, or "
     .. "use hs.task and take the answer in a callback.",
  check = function(code)
      if not code:find("hs%.execute") then return false end
      if not code:find("osascript") then return false end
      if code:find("with timeout of") then return false end
      local n = 0
      for line in (code .. "\n"):gmatch("([^\n]*)\n") do
          n = n + 1
          if line:find("hs%.execute") and line:find("osascript") then
              return { n, "no `with timeout of` anywhere in this file" }
          end
      end
      return { 1, "no `with timeout of` anywhere in this file" }
  end }

-- 🚨 Private APIs are what break on a new macOS. This is INFO, not a
-- defect: hs.spaces is legitimate and there is no public alternative.
-- It is here so that when the next OS lands, one command lists every
-- place that has to be re-verified.
rule{ id = "private-api", sev = "INFO",
  why = "hs.spaces drives PRIVATE macOS APIs. Nothing is wrong with using "
     .. "it, but it is the first thing to break on a major macOS release "
     .. "and it can wedge Mission Control when it does. Listed so it can be "
     .. "re-verified deliberately after every OS update.",
  line = function(code) return code:find("hs%.spaces%.") end }

-- 🚨 hs.execute blocks the main thread until the child exits.
rule{ id = "blocking-main-thread", sev = "INFO",
  why = "hs.execute and waitUntilExit BLOCK the main thread, which is also "
     .. "the thread that draws your screen and reads your keyboard. "
     .. "Acceptable on a keypress for something fast and certain; never on "
     .. "a timer or a watcher.",
  line = function(code)
      return code:find("hs%.execute%s*%(") or code:find(":waitUntilExit%s*%(")
  end }

-- Module contract, checked rather than assumed.
rule{ id = "module-contract", sev = "ERROR", file = true,
  why = "A loader-managed module must expose M.setup(core) and end with "
     .. "return M. Without both, the loader records it as failed and the "
     .. "feature is silently absent.",
  check = function(text, name, path)
      if not path:find("/modules/") then return end
      local miss = {}
      if not text:find("function M%.setup") then miss[#miss+1] = "M.setup" end
      if not text:find("\nreturn M") then miss[#miss+1] = "return M" end
      if #miss == 0 then return end
      return { 1, "missing " .. table.concat(miss, " and ") }
  end }

-- 🚨 6.66.3 — from LL's Console, on a hotkey press while Safari's
-- URL-completion popup was on screen:
--   NSInternalInconsistencyException … -[NSRemoteView
--   containingWindowWillOrderOnScreen:] … canvas_show
rule{ id = "canvas-show-unprotected", sev = "ERROR", file = true, raw = true,
  why = "canvas:show() THROWS when another process's remote view is "
     .. "mid-transition — Safari's URL completion and Spotlight are the "
     .. "usual culprits. The throw abandons the rest of the open sequence, "
     .. "so state is set, the canvas half-orders on screen, and the config "
     .. "believes a panel is open that you cannot see. Use "
     .. "_G.showCanvasSafely(canvas, label), which retries once a run loop "
     .. "turn later and reports through the ledger if it still refuses.",
  check = function(_, name, path, raw)
      if name == "init.lua" then return end          -- defines the helper
      local src = STRIP(raw)
      local bare, safe = 0, 0
      for line in src:gmatch("[^\n]+") do
          if line:find("[%w_%.]*[Cc]anvas[%w_%.]*:show%s*%(")
             and not line:find("showCanvasSafely") then
              bare = bare + 1
          end
      end
      for _ in src:gmatch("showCanvasSafely") do safe = safe + 1 end
      -- ⚠️ COUNTED, NOT FORBIDDEN, because the CORRECT pattern contains a
      -- bare show on purpose:
      --      if _G.showCanvasSafely then _G.showCanvasSafely(c, "x")
      --      else pcall(function() c:show() end) end
      -- That fallback exists because a module can load before init.lua has
      -- defined the helper, and it is on its own line. A rule that flagged
      -- any bare show would report all three correct call sites — which is
      -- exactly what the first version of this rule did.
      if bare == 0 or bare <= safe then return end
      return { 1, bare .. " bare canvas:show() call(s) against " .. safe
                  .. " protected — route them through _G.showCanvasSafely" }
  end }

-- 🚨 6.66.1 — "my shortcuts don't work over full screen apps". They did.
-- The PANELS were invisible, which is indistinguishable from a dead key.
rule{ id = "canvas-not-fullscreen", sev = "ERROR",
  why = "A canvas without fullScreenAuxiliary CANNOT DRAW over a "
     .. "full-screen app. The shortcut fires, the panel is created, and "
     .. "nothing appears — which reads as a broken shortcut, not a drawing "
     .. "bug, and is the hardest kind of failure to report. 'stationary' "
     .. "does NOT cover this: it means 'do not move me when Spaces "
     .. "change'. Use behaviorAsLabels({ 'canJoinAllSpaces', "
     .. "'fullScreenAuxiliary' }).",
  -- ⚠️ FILE-LEVEL AND OVER RAW TEXT, for two reasons that each defeat the
  -- obvious per-line version:
  --   1. scrub() BLANKS STRING LITERALS before rules see a line, so
  --      "fullScreenAuxiliary" is invisible to a normal rule — the first
  --      draft of this check flagged all twelve correct call sites.
  --   2. the call is routinely split across lines:
  --          c:behaviorAsLabels({ "canJoinAllSpaces",
  --                               "fullScreenAuxiliary" })
  -- Counting both tokens in the whole file handles both, and the count
  -- comparison is what makes it precise: one missing flag anywhere in a
  -- file with several correct calls still shows up.
  file = true, raw = true,
  check = function(_, name, path, raw)
      local src = STRIP(raw)
      local calls, flags = 0, 0
      for _ in src:gmatch("behaviorAsLabels") do calls = calls + 1 end
      for _ in src:gmatch("fullScreenAuxiliary") do flags = flags + 1 end
      if calls == 0 or flags >= calls then return end
      return { 1, calls .. " behaviorAsLabels call(s) but only " .. flags
                  .. " fullScreenAuxiliary — one panel cannot draw over a "
                  .. "full-screen app" }
  end }

-- 🚨 Deprecated in Hammerspoon; hs.canvas replaced it years ago.
rule{ id = "deprecated-drawing", sev = "WARN",
  why = "hs.drawing is deprecated in favour of hs.canvas and is not "
     .. "maintained. Mixing the two also means two different coordinate "
     .. "and level systems in one config.",
  line = function(code)
      return code:find("hs%.drawing%.[%w]") and not code:find("windowLevels")
  end }

-- ---------------------------------------------------------------------
-- SCRUBBING — comments and string literals are blanked before matching.
-- ---------------------------------------------------------------------
-- Without this, every rule fires on the paragraph explaining the rule.
-- This file is 40% comments by design and most of them quote the very
-- calls being banned.
local function scrub(line, inBlock)
    local out, i, n = {}, 1, #line
    -- inside a --[[ ]] block: blank until it closes
    if inBlock then
        local e = line:find("%]%]")
        if not e then return string.rep(" ", n), true end
        return string.rep(" ", e + 1) .. scrub(line:sub(e + 2), false), false
    end
    while i <= n do
        local c = line:sub(i, i)
        if c == "-" and line:sub(i, i + 3) == "--[[" then
            local e = line:find("%]%]", i + 4)
            if not e then return table.concat(out) .. string.rep(" ", n - i + 1), true end
            out[#out + 1] = string.rep(" ", e + 1 - i); i = e + 2
        elseif c == "-" and line:sub(i, i + 1) == "--" then
            out[#out + 1] = string.rep(" ", n - i + 1); i = n + 1
        elseif c == '"' or c == "'" then
            -- Keep the quotes so "is this a literal" checks still work,
            -- blank the contents so their text cannot match a rule.
            local q, j = c, i + 1
            while j <= n do
                local d = line:sub(j, j)
                if d == "\\" then j = j + 2
                elseif d == q then break
                else j = j + 1 end
            end
            out[#out + 1] = q .. string.rep(" ", math.max(0, j - i - 1)) .. q
            i = j + 1
        else
            out[#out + 1] = c; i = i + 1
        end
    end
    return table.concat(out), false
end

-- Comments stripped, STRING LITERALS KEPT. scrub() blanks both, which is
-- right for nearly every rule and wrong for the one rule that has to read
-- what is inside a string. Counting over raw text is not the answer
-- either: the first version of canvas-not-fullscreen counted a mention of
-- fullScreenAuxiliary in a COMMENT as a use of it, so the file explaining
-- the fix silenced the check on itself.
function STRIP(text)
    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local i, n, keep = 1, #line, {}
        while i <= n do
            local c = line:sub(i, i)
            if c == "-" and line:sub(i, i + 1) == "--" then break end
            if c == '"' or c == "'" then
                local q, j = c, i + 1
                while j <= n do
                    local d = line:sub(j, j)
                    if d == "\\" then j = j + 2
                    elseif d == q then break
                    else j = j + 1 end
                end
                keep[#keep + 1] = line:sub(i, math.min(j, n))
                i = j + 1
            else
                keep[#keep + 1] = c; i = i + 1
            end
        end
        out[#out + 1] = table.concat(keep)
    end
    return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------
local function suppressions(lines, i)
    -- Same line or the line above. The reason after the dash is required.
    for _, k in ipairs({ i, i - 1 }) do
        local l = lines[k]
        if l then
            local id, why = l:match("hs%-lint:%s*allow%s+([%w%-]+)%s*(.*)$")
            if id then return id, (why or ""):gsub("^[%s%-—]+", "") end
        end
    end
end

local function lintFile(path, name)
    local fh = io.open(path, "r")
    if not fh then return end
    local text = fh:read("*a"); fh:close()
    filesSeen = filesSeen + 1

    local lines = {}
    for l in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end

    -- 🚨 FILE-LEVEL RULES GET THE SCRUBBED TEXT, not the raw file.
    -- Reading raw, a rule fires on the COMMENT that documents the very
    -- call it is looking for — mini_calendar and quick_append were both
    -- reported for a service.call that exists only in an example line
    -- explaining how to call them. A linter whose first three findings
    -- are its own documentation is one nobody reads twice.
    local codeLines, blk = {}, false
    for i, l in ipairs(lines) do codeLines[i], blk = scrub(l, blk) end
    local codeText = table.concat(codeLines, "\n")

    local function add(sev, id, line, why, extra)
        findings[#findings + 1] = { sev = sev, id = id, file = name,
                                    line = line, why = why, extra = extra }
    end

    -- whole-file rules. Their suppression may live ANYWHERE in the file:
    -- the finding is reported at line 1 because it is about the file as a
    -- whole, and demanding the waiver sit on line 1 would push it above
    -- the header comment where nobody would ever read it.
    for _, r in ipairs(RULES) do
        if r.file then
            local hit = r.check(codeText, name, path, text)
            if hit then
                -- 🚨 ESCAPE THE ID. Rule ids contain '-', which is a
                -- QUANTIFIER in a Lua pattern, so "service-call-unchecked"
                -- interpolated raw matches "servicecallunchecked" and the
                -- waiver silently never applies. This linter's own
                -- pattern-on-variable rule is about exactly this class of
                -- mistake, and it made it anyway — which is the argument
                -- for the rule, not against it.
                local esc = r.id:gsub("%p", "%%%0")
                local why = text:match("hs%-lint:%s*allow%s+" .. esc .. "%s*(.-)\n")
                if why then
                    why = why:gsub("^[%s%-—]+", "")
                    if why == "" then
                        add("WARN", "bare-suppression", 1,
                            "A suppression with no reason is not a decision, it "
                            .. "is a silenced alarm. Say why after a dash.",
                            "suppresses " .. r.id)
                    end
                else
                    add(r.sev, r.id, hit[1], r.why, hit[2])
                end
            end
        end
    end

    -- per-line rules
    local inBlock, prevCode = false, nil
    local ctx = { fileText = codeText, name = name }
    for i, raw in ipairs(lines) do
        local code
        code, inBlock = scrub(raw, inBlock)
        ctx.prevCode = prevCode
        if code:match("%S") then
            for _, r in ipairs(RULES) do
                if not r.file and r.line(code, i, ctx) then
                    local sid, why = suppressions(lines, i)
                    if sid == r.id then
                        if why == "" then
                            add("WARN", "bare-suppression", i,
                                "A suppression with no reason is not a decision, "
                                .. "it is a silenced alarm. Say why after a dash.",
                                "suppresses " .. r.id)
                        end
                    else
                        add(r.sev, r.id, i, r.why)
                    end
                end
            end
            prevCode = code
        end
    end
end

-- ---------------------------------------------------------------------
local function ls(dir, pat)
    local out, p = {}, io.popen('ls "' .. dir .. '"/' .. pat .. ' 2>/dev/null')
    if p then
        for l in p:lines() do out[#out + 1] = l end
        p:close()
    end
    return out
end

local targets = { HS .. "/init.lua" }
for _, f in ipairs(ls(HS, "core/*.lua"))    do targets[#targets + 1] = f end
for _, f in ipairs(ls(HS, "modules/*.lua")) do targets[#targets + 1] = f end

for _, p in ipairs(targets) do
    lintFile(p, (p:gsub("^" .. HS:gsub("%p", "%%%0") .. "/", "")))
end

-- ---------------------------------------------------------------------
-- REPORT — grouped by rule, because the whole point is to see a CLASS of
-- bug in one place rather than fixing instances one at a time.
-- ---------------------------------------------------------------------
local ORDER = { ERROR = 1, WARN = 2, INFO = 3 }
table.sort(findings, function(a, b)
    if ORDER[a.sev] ~= ORDER[b.sev] then return ORDER[a.sev] < ORDER[b.sev] end
    if a.id ~= b.id then return a.id < b.id end
    if a.file ~= b.file then return a.file < b.file end
    return a.line < b.line
end)

local W = io.write
W("════════════════════════════════════════════════════════════\n")
W(" HAMMERSPOON LINT   ", filesSeen, " files\n")
W("════════════════════════════════════════════════════════════\n")

local counts = { ERROR = 0, WARN = 0, INFO = 0 }
local lastId
for _, f in ipairs(findings) do
    counts[f.sev] = counts[f.sev] + 1
    if f.id ~= lastId then
        lastId = f.id
        W("\n", ({ ERROR = "🚨", WARN = "⚠️ ", INFO = "ℹ️ " })[f.sev],
          " ", f.sev, "  ", f.id, "\n")
        for chunk in f.why:gmatch("[^\n]+") do
            -- wrapped to 68 so a finding stays readable in a narrow terminal
            local cur = ""
            for word in chunk:gmatch("%S+") do
                if #cur + #word + 1 > 68 then W("   ", cur, "\n"); cur = word
                else cur = (cur == "" and word) or (cur .. " " .. word) end
            end
            if cur ~= "" then W("   ", cur, "\n") end
        end
    end
    W(string.format("      %s:%d%s\n", f.file, f.line,
                    f.extra and ("  — " .. f.extra) or ""))
end

-- ℹ️ INFO IS A REGISTER, NOT A QUEUE. ERROR and WARN are defects and are
-- meant to reach zero. INFO is an inventory of things that are CORRECT but
-- fragile — private APIs that break on a macOS release, calls that block
-- the main thread — and the point of an inventory is that it stays
-- visible. Waivers deliberately do not clear it: after every OS update,
-- this list is what you re-verify.
if counts.INFO > 0 then
    W("\n   ℹ️  The notes above are a REGISTER, not a to-do list. They are\n")
    W("      correct code with a known fragility — re-read them after every\n")
    W("      macOS update, which is when they are most likely to matter.\n")
end
W("\n────────────────────────────────────────────────────────────\n")
W(string.format(" %d error, %d warning, %d note\n",
                counts.ERROR, counts.WARN, counts.INFO))
if counts.ERROR == 0 then
    W(" ✅ no ERROR-level findings\n")
end
W("════════════════════════════════════════════════════════════\n")
os.exit(counts.ERROR == 0 and 0 or 1)
