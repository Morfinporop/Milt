-- GRIMOHOD: тема интерфейса в стиле qmenu
-- Тёмные полупрозрачные панели, тонкая белая обводка, оранжевый акцент,
-- ромбы-маркеры, шрифт Montserrat, масштаб от высоты экрана (1080p = базовый).

GRIM.UI = GRIM.UI or {}
local UI = GRIM.UI
local PAL = GRIM.Palette

UI.FONT = "Montserrat"
UI.BG = PAL.BG
UI.OUTLINE = PAL.OUTLINE
UI.ORANGE = PAL.ORANGE
UI.GREEN = PAL.GREEN
UI.RED = PAL.RED
UI.BLUE = PAL.BLUE
UI.WHITE = PAL.WHITE
UI.GREY = PAL.GREY

-- Масштабирование: S(v) — пиксели для базового 1080p
function UI.S(v)
    return math.floor(v * ScrH() / 1080 + 0.5)
end
local S = UI.S

-- Все шрифты — Montserrat 700, как в qmenu
local FONTS = {
    Logo = {size = 64},
    Title = {size = 40},
    Big = {size = 30},
    Row = {size = 19},
    Tab = {size = 17},
    Card = {size = 15},
    Small = {size = 14},
    Tiny = {size = 12},
    Letter = {size = 54},
}

function UI.BuildFonts()
    for name, f in pairs(FONTS) do
        surface.CreateFont("GRIM_" .. name, {
            font = UI.FONT,
            size = S(f.size),
            weight = 700,
            antialias = true,
            extended = true,
        })
    end
end
UI.BuildFonts()
hook.Add("OnScreenSizeChanged", "GRIM_UI_Fonts", UI.BuildFonts)

-- Цвет с умножением альфы (для fade)
function UI.Fade(c, k)
    return Color(c.r, c.g, c.b, math.floor(c.a * math.Clamp(k, 0, 1)))
end

function UI.Mix(a, b, t)
    return Color(Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b), Lerp(t, a.a, b.a))
end

function UI.Rect(x, y, w, h, col)
    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, col.a)
    surface.DrawRect(x, y, w, h)
end

function UI.Outline(x, y, w, h, col)
    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, col.a)
    surface.DrawOutlinedRect(x, y, w, h, 1)
end

-- Базовая панель qmenu: фон + едва заметная обводка
function UI.Panel(x, y, w, h, alpha)
    UI.Rect(x, y, w, h, Color(UI.BG.r, UI.BG.g, UI.BG.b, alpha or UI.BG.a))
    UI.Outline(x, y, w, h, UI.OUTLINE)
end

-- Обводка, которая плавно становится оранжевой (как BorderK в qmenu)
function UI.Accent(x, y, w, h, k)
    k = math.Clamp(k, 0, 1)
    UI.Outline(x, y, w, h, Color(
        Lerp(k, UI.OUTLINE.r, UI.ORANGE.r),
        Lerp(k, UI.OUTLINE.g, UI.ORANGE.g),
        Lerp(k, UI.OUTLINE.b, UI.ORANGE.b),
        Lerp(k, UI.OUTLINE.a, 255)
    ))
end

function UI.Text(txt, font, x, y, col, ax, ay)
    draw.SimpleText(txt, font, x, y, col, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end

-- Обрезка текста с многоточием под ширину
function UI.Fit(txt, font, maxW)
    surface.SetFont(font)
    if surface.GetTextSize(txt) <= maxW then return txt end
    local n = utf8.len(txt) or #txt
    while n > 1 do
        n = n - 1
        local cut = (utf8.offset(txt, n + 1) or (#txt + 1)) - 1
        local s = string.sub(txt, 1, cut) .. "…"
        if surface.GetTextSize(s) <= maxW then return s end
    end
    return "…"
end

-- Перенос текста по словам
function UI.Wrap(txt, font, maxW)
    surface.SetFont(font)
    local lines, line = {}, ""
    for word in string.gmatch(txt, "%S+") do
        local try = (line == "") and word or (line .. " " .. word)
        if surface.GetTextSize(try) > maxW and line ~= "" then
            lines[#lines + 1] = line
            line = word
        else
            line = try
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

-- Ромб-маркер (избранное в qmenu)
function UI.Diamond(cx, cy, r, col)
    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, col.a)
    surface.DrawPoly({
        {x = cx, y = cy - r}, {x = cx + r, y = cy},
        {x = cx, y = cy + r}, {x = cx - r, y = cy},
    })
end

function UI.Bar(x, y, w, h, frac, col, bg)
    UI.Rect(x, y, w, h, bg or Color(255, 255, 255, 18))
    local fw = math.floor(w * math.Clamp(frac, 0, 1))
    if fw > 0 then UI.Rect(x, y, fw, h, col) end
end

-- Кривые плавности
UI.Ease = {
    OutCubic = function(t)
        t = math.Clamp(t, 0, 1)
        return 1 - (1 - t) ^ 3
    end,
    OutBack = function(t)
        t = math.Clamp(t, 0, 1)
        local c1 = 1.70158
        local c3 = c1 + 1
        return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
    end,
    InOut = function(t)
        t = math.Clamp(t, 0, 1)
        if t < 0.5 then return 2 * t * t end
        return 1 - (-2 * t + 2) ^ 2 / 2
    end,
}

-- Плавное значение по ключу (скорость — единиц в секунду)
local anims = {}
function UI.Anim(key, target, speed)
    local v = anims[key]
    if v == nil then v = target end
    v = math.Approach(v, target, speed * FrameTime())
    anims[key] = v
    return v
end

function UI.Pulse(speed)
    return 0.5 + 0.5 * math.sin(CurTime() * speed)
end

-- Печатная машинка: сколько символов показать за время t
function UI.Typed(txt, t, cps)
    local n = utf8.len(txt) or #txt
    local shown = math.min(n, math.floor(math.max(0, t) * cps))
    local cut = (utf8.offset(txt, shown + 1) or (#txt + 1)) - 1
    return string.sub(txt, 1, cut)
end

-- Клиентские ConVar'ы
GRIM.CV.Halo = CreateClientConVar("grimohod_halo", "1", true, false, "Подсветка тайников и оружия на полу")
