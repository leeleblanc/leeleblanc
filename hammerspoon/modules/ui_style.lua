-- =====================================================================
-- MODULE: UI STYLE (6.90.0) — ONE style table every panel reads
-- =====================================================================
-- LL, looking at the pomodoro FOCUS card: "How many of the windows
-- could be in the GUI-style screenshot for the Pomodoro timer?"
--
-- The answer was "eleven, and no two of them agree on the numbers".
-- Each panel declared its own near-copy of the same dark card — the
-- calendar at radius 16, the ⌥Tab switcher at 18, the timer at 12;
-- three different blacks, three different strokes. Siblings, not
-- twins. This module is the fix: the FOCUS card's numbers live HERE,
-- once, and every panel reads them, so they finally match — and one
-- edit here restyles all of them at the next ⇪R.
--
--   CANVASES   pomodoro · mini calendar · key caster · ⌥Tab switcher ·
--              cheat sheet · task mirror (⇪T draft) · Asana legend
--   WEBVIEWS   capture pad · screenshot editor · task form · unified
--              search — they take the same colors as CSS, via
--              uiStyle.cssOverride() appended to each page's stylesheet
--
-- TWO RULES KEEP THIS SAFE:
--   1. Every consumer reads _G.uiStyle WITH A FALLBACK to the exact
--      values it shipped with. A boot where this module failed to load
--      looks like 6.89.0 — never like a crash, never like a blank
--      panel. That is also why this file must stay dependency-free:
--      it touches no hs.* API at all, so there is nothing here that
--      CAN fail on a bad boot.
--   2. This module only DEFINES. It draws nothing, binds no key, and
--      starts no timer — which is why it is safe to load first.
--
-- WHAT IS SHARED AND WHAT IS NOT, deliberately:
--   shared   the CARD — background, stroke, corner radius, the primary
--            and receded text colors, the selection blues, the amber
--            accent, the type scale
--   not      each panel's INNER layout — the calendar's day cells, the
--            switcher's translucent tile wash over window snapshots,
--            the editor's tool buttons. Those are content, not chrome,
--            and flattening them would break what they mean.
--
-- ✏️ EDIT THE TABLE BELOW and press ⇪R — every panel changes at once.
-- Machine profiles can override any token (M.config IS the table), so
-- the work Mac can run a different look without touching this file.

local M = {
    name  = "UI Style",
    order = 0.5,
    cheatsheet = {
        title = "🎨 UI STYLE (no key — the shared panel look)",
        entries = {
            { "what", "One table of colors/corners that 11 panels read" },
            { "edit", "modules/ui_style.lua ✏️ table — ⇪R applies it" },
            { "ref",  "The pomodoro FOCUS card is the reference look" },
        },
    },
}

function M.setup(core)

    -- ✏️ EDIT HERE — these are the FOCUS card's numbers, verbatim.
    local style = {
        -- the card itself
        bg     = { red = 0.09, green = 0.10, blue = 0.13, alpha = 0.92 },
        fg     = { white = 1.00, alpha = 0.97 },
        fgDim  = { white = 1.00, alpha = 0.55 },  -- captions, older lines
        stroke = { white = 1.00, alpha = 0.18 },  -- the hairline edge
        radius = 12,
        -- the pomodoro flash amber — THE accent of this config
        accent = { red = 1.00, green = 0.84, blue = 0.00, alpha = 0.96 },
        -- the selection blues (calendar's selected day was the nicest)
        select     = { red = 0.32, green = 0.58, blue = 0.98, alpha = 0.85 },
        selectSoft = { red = 0.30, green = 0.55, blue = 0.95, alpha = 0.16 },
        selectLine = { red = 0.45, green = 0.72, blue = 1.00, alpha = 0.95 },
        -- type scale (canvas point sizes)
        font   = { label = 12, body = 14, title = 24, big = 40 },
    }
    -- ----------------------------------------------------------------

    local function chan(v)
        if type(v) ~= "number" then v = 0 end
        return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5)
    end

    -- hs color table → CSS "rgba(r,g,b,a)". Accepts both shapes this
    -- config uses ({red,green,blue} and {white}); anything else comes
    -- back white rather than throwing inside a page builder.
    function style.css(c)
        if type(c) ~= "table" then return "rgba(255,255,255,1.00)" end
        local r, g, b = c.red, c.green, c.blue
        if c.white ~= nil then r, g, b = c.white, c.white, c.white end
        return string.format("rgba(%d,%d,%d,%.2f)",
                             chan(r), chan(g), chan(b), c.alpha or 1)
    end

    -- The card background as an OPAQUE hex — webview pages sit on a
    -- solid window, so translucency there would blend with white and
    -- lighten, not darken. #171a21 at today's numbers.
    function style.bgHex()
        local b = style.bg or {}
        return string.format("#%02x%02x%02x",
                             chan(b.red), chan(b.green), chan(b.blue))
    end

    -- A copy of the card background at a caller-chosen alpha. For the
    -- panels that keep their own translucency knob (the cheat sheet's
    -- alpha, §1.5's panelAlpha): they take the shared HUE and keep the
    -- see-through they had. A copy, never the shared table — a caller
    -- writing into its result must not restyle everyone else.
    function style.bgWith(alpha)
        local b = style.bg or {}
        return { red = b.red or 0, green = b.green or 0,
                 blue = b.blue or 0, alpha = alpha or b.alpha or 1 }
    end

    -- The one line each webview appends INSIDE its <style> block, after
    -- its own rules — CSS cascade means last-wins, so the shared colors
    -- override the page's hardcoded body without touching its layout.
    function style.cssOverride()
        return "body{background:" .. style.bgHex()
               .. ";color:" .. style.css(style.fg) .. "}"
    end

    _G.uiStyle = style
    if core and core.provide then
        core.provide("style.get", function() return style end)
    end
    M.config = style   -- machine profiles override tokens through this
end

return M
