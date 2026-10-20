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
    family = "config",
    cheatsheet = {
        title = "🎨 UI STYLE (no key — the shared panel look)",
        entries = {
            { "what", "One table of colors/corners that 11 panels read" },
            { "edit", "modules/ui_style.lua ✏️ table — ⇪R applies it" },
            { "ref",  "The pomodoro FOCUS card is the reference look" },
        },
    },
}

-- ---- PURE: is a control VISIBLE? (6.369.0) ------------------------------
-- 🔤 LL: "There is not 'X' in the note list to remove an entry." There
-- is. It has been there since 6.280.0 in the notes and since 6.364.0 in
-- the closed-tab strip, and he could not see it — which, for a control
-- you have to find before you can click it, is the same thing as absent.
--
-- 🔑 6.361.0's RULE IN A SECOND PLACE, and it is why this is arithmetic
-- rather than taste. That release found a tool unreachable for 267
-- releases because its key was printed in a glyph he could not map to a
-- physical key: WHEN A TOOL GOES UNUSED, CHECK THAT IT CAN BE READ
-- BEFORE CHECKING THAT IT IS CORRECT. Every rule in this config about a
-- control asks whether it WORKS. Not one asked whether it can be SEEN.
--
-- 📏 MEASURED, NOT ADJUSTED BY EYE. The ✕ was drawn at opacity 0.28–0.3
-- in #e8e8ec over the sidebar's #17171c, which blends to about #56565a
-- and carries a contrast ratio of 2.5:1. WCAG's floor for a control you
-- are meant to find and click is 3:1, and a thin glyph like ✕ is the
-- worst case inside that. So the number was below the floor, provably,
-- and "I cannot see it" was a correct report of a measurable defect.
local function srgb(c)
    c = c / 255
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function rgbOf(hex)
    hex = tostring(hex or ""):gsub("^#", "")
    if #hex == 3 then
        hex = hex:sub(1,1):rep(2) .. hex:sub(2,2):rep(2) .. hex:sub(3,3):rep(2)
    end
    if #hex ~= 6 or hex:find("%X") then return nil end
    return tonumber(hex:sub(1, 2), 16),
           tonumber(hex:sub(3, 4), 16),
           tonumber(hex:sub(5, 6), 16)
end

-- What a colour drawn at `alpha` over `bg` really is on screen. Opacity
-- is not a property of the ink — it is a blend, and the blend is what a
-- person's eye has to separate from the background.
function M.blend(fg, bg, alpha)
    local fr, fg_, fb = rgbOf(fg)
    local br, bg_, bb = rgbOf(bg)
    if not fr or not br then return nil end
    local a = tonumber(alpha)
    if not a then return nil end
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    local function mix(f, b) return math.floor((a * f + (1 - a) * b) + 0.5) end
    return ("#%02x%02x%02x"):format(mix(fr, br), mix(fg_, bg_), mix(fb, bb))
end

function M.luminance(hex)
    local r, g, b = rgbOf(hex)
    if not r then return nil end
    return 0.2126 * srgb(r) + 0.7152 * srgb(g) + 0.0722 * srgb(b)
end

-- WCAG 2.x contrast. Answers nil — never a number — for anything it
-- could not read: a report that invents a ratio for a colour it did not
-- understand is worse than one that says it could not tell (6.196.1).
function M.contrast(a, b)
    local la, lb = M.luminance(a), M.luminance(b)
    if not la or not lb then return nil end
    if lb > la then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

-- The alpha a dim control may rest at over `bg` and still clear `floor`.
-- PURE and searched rather than solved, because the sRGB curve is not
-- invertible in one line and a wrong closed form would be a number that
-- looks measured and is not.
function M.minAlphaFor(fg, bg, floor)
    floor = tonumber(floor) or M.minControlContrast
    for i = 5, 100 do
        local a = i / 100
        local c = M.contrast(M.blend(fg, bg, a), bg)
        if c and c >= floor then return a, c end
    end
    return nil
end

-- 📏 THE FLOOR, AND THE RESTING ALPHA THE GATE PROVES AGAINST IT.
-- 3:1 is WCAG's threshold for a non-text user-interface component. 0.55
-- is not a taste: it is the first value above the floor with room to
-- spare for a thin glyph, and over the #17171c sidebar it measures 5.3:1.
M.minControlContrast = 3.0
M.controlAlpha       = 0.55     -- a control at rest
M.controlHoverAlpha  = 0.85     -- under the pointer

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

    -- the contrast arithmetic is published on the table as well, so a
    -- panel can ask at runtime; it lives on M so the gate can prove the
    -- rule without running setup at all.
    style.blend, style.luminance, style.contrast = M.blend, M.luminance, M.contrast
    style.minAlphaFor        = M.minAlphaFor
    style.minControlContrast = M.minControlContrast
    style.controlAlpha       = M.controlAlpha
    style.controlHoverAlpha  = M.controlHoverAlpha

    _G.uiStyle = style
    if core and core.provide then
        core.provide("style.get", function() return style end)
    end
    M.config = style   -- machine profiles override tokens through this
end

return M
