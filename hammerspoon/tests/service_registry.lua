-- =====================================================================
-- service_registry.lua — the gate's ONE service registry, and it is
-- init.lua's own (6.273.0)
-- =====================================================================
--     local reg = dofile(HS .. "/tests/service_registry.lua")(HS)
--     _G.service = reg.service
--     reg.provide("docs.front", function() return { path = "…" } end)
--     reg.calls            -- every name called, in order
--     reg.src ~= nil       -- the lift succeeded
--
-- 🔌 WHY THIS FILE EXISTS. test_anchors.lua carried a hand-written
-- registry under the comment "the service registry, exactly as init.lua
-- publishes it". It was not. It read:
--
--     call = function(n, ...) return true, SERVICES[n](...) end
--
-- and init.lua's reads `local ok, a, b, c = pcall(fn, ...)` and then
-- `return a, b, c` — the provider's OWN values, RAW, with nothing in
-- front of them. Two differences, both invisible at a call site:
--   1. the stub PREPENDS a `true` that the real one never sends, so a
--      module written against it reads every value one slot late; and
--   2. `return true, f(...)` truncates f to ONE value — a call in a
--      non-final position of an expression list is adjusted to one — so
--      the stub could never hand back three values at all.
--
-- modules/anchors.lua was written against that convention at all four
-- of its call sites and shipped in 6.180.0. On LL's Mac the document
-- leg, the moved-file resolver and the "pick a note" picker could never
-- work, and 106 checks were green for eighty-nine releases.
--
-- 🔑 SO THE GATE STOPS RE-TYPING IT. The block is LIFTED out of
-- init.lua's source (6.236.0's technique for `_G.baseScreenPick`), so a
-- suite cannot invent a calling convention and a change to init.lua's
-- registry reaches every suite in the same commit.
--
-- A lift that fails answers FALSELY rather than throwing, so a mutation
-- fails a check instead of killing the run (6.186.0). `reg.src` is nil
-- there, and the consumer asserts it.

-- 🚨 `opener` IS NOT OPTIONAL DECORATION. Several suites here replace
-- io.open with a fake filesystem before they load a module, and a lift
-- that reads init.lua through the fake gets nothing — then falls back to
-- the stand-in below, whose has() answers false, and every check about a
-- service quietly stops testing anything. test_vault cost a cycle to
-- exactly that. A suite with a fake io.open passes the REAL one here,
-- and asserts `reg.src ~= nil` so a failed lift is loud.
return function(HS, opener)
    local f = (opener or io.open)((HS or ".") .. "/init.lua", "r")
    local init = f and f:read("*a") or ""
    if f then f:close() end

    -- init.lua's block runs from `_G.service = {` to the first line that
    -- begins a `}` in column 1. Its inner tables are written inline, so
    -- nothing nested can end the match early.
    local src = init:match("(_G%.service = %{.-\n%})")

    local reg = { src = src, calls = {} }

    -- The lifted block prints and calls _G.diag.err on a refusal. Fill
    -- either in only if the suite has not, so a suite that WANTS to see
    -- those is untouched.
    _G.diag = _G.diag or {}
    if type(_G.diag.err) ~= "function" then _G.diag.err = function() end end

    if src then
        local chunk = load(src .. "\nreturn _G.service")
        if chunk then
            local ok, svc = pcall(chunk)
            if ok and type(svc) == "table" then reg.service = svc end
        end
    end

    -- 6.186.0: a stand-in that ANSWERS, so the consumer's own checks go
    -- red instead of the run ending on an index of a nil.
    reg.service = reg.service or {
        registry = {}, owner = {},
        provide = function() end,
        has     = function() return false end,
        call    = function() return nil end,
    }

    -- The call COUNTER hangs off the providers, never off `call` —
    -- wrapping `call` would re-introduce exactly the divergence this
    -- file exists to end.
    reg.provide = function(name, fn)
        reg.service.provide(name, function(...)
            reg.calls[#reg.calls + 1] = name
            return fn(...)
        end)
    end

    reg.called = function(name)
        for _, n in ipairs(reg.calls) do if n == name then return true end end
        return false
    end

    return reg
end
