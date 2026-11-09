-- GRIMOHOD: векторные иконки (полигоны). Не требуют внешних материалов.

GRIM.UI = GRIM.UI or {}
local UI = GRIM.UI
local ICONS = {}

local function Poly(pts, col)
    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, col.a)
    surface.DrawPoly(pts)
end

local function Circle(cx, cy, r, col, seg)
    seg = seg or 28
    local pts = {}
    for i = 0, seg - 1 do
        local a = math.pi * 2 * i / seg
        pts[#pts + 1] = {x = cx + math.cos(a) * r, y = cy + math.sin(a) * r}
    end
    Poly(pts, col)
end

-- Кольцо из выпуклых четырёхугольников
local function Ring(cx, cy, r, th, col, seg)
    seg = seg or 32
    local ro, ri = r + th / 2, r - th / 2
    for i = 0, seg - 1 do
        local a1 = math.pi * 2 * i / seg
        local a2 = math.pi * 2 * (i + 1) / seg
        local c1, s1 = math.cos(a1), math.sin(a1)
        local c2, s2 = math.cos(a2), math.sin(a2)
        Poly({
            {x = cx + c1 * ro, y = cy + s1 * ro},
            {x = cx + c2 * ro, y = cy + s2 * ro},
            {x = cx + c2 * ri, y = cy + s2 * ri},
            {x = cx + c1 * ri, y = cy + s1 * ri},
        }, col)
    end
end

local function Line(x1, y1, x2, y2, th, col)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return end
    local nx, ny = -dy / len * th / 2, dx / len * th / 2
    Poly({
        {x = x1 + nx, y = y1 + ny}, {x = x2 + nx, y = y2 + ny},
        {x = x2 - nx, y = y2 - ny}, {x = x1 - nx, y = y1 - ny},
    }, col)
end

ICONS.knife = function(cx, cy, s, c)
    local function p(x, y) return {x = cx + x * s, y = cy + y * s} end
    Poly({p(0, -0.5), p(0.13, 0.02), p(-0.13, 0.02)}, c)
    Poly({p(-0.21, 0.02), p(0.21, 0.02), p(0.21, 0.1), p(-0.21, 0.1)}, c)
    Poly({p(-0.07, 0.1), p(0.07, 0.1), p(0.07, 0.46), p(-0.07, 0.46)}, c)
end

ICONS.magnifier = function(cx, cy, s, c)
    Ring(cx - 0.08 * s, cy - 0.08 * s, 0.28 * s, 0.09 * s, c)
    Line(cx + 0.14 * s, cy + 0.14 * s, cx + 0.42 * s, cy + 0.42 * s, 0.12 * s, c)
end

ICONS.person = function(cx, cy, s, c)
    Circle(cx, cy - 0.2 * s, 0.17 * s, c)
    local pts = {}
    for i = 0, 20 do
        local a = math.pi + math.pi * i / 20
        pts[#pts + 1] = {x = cx + math.cos(a) * 0.34 * s, y = cy + 0.44 * s + math.sin(a) * 0.26 * s}
    end
    Poly(pts, c)
end

ICONS.coin = function(cx, cy, s, c)
    Ring(cx, cy, 0.34 * s, 0.1 * s, c)
    Circle(cx, cy, 0.18 * s, UI.Fade(c, 0.5))
end

ICONS.clock = function(cx, cy, s, c)
    Ring(cx, cy, 0.36 * s, 0.09 * s, c)
    Line(cx, cy, cx, cy - 0.22 * s, 0.09 * s, c)
    Line(cx, cy, cx + 0.17 * s, cy + 0.08 * s, 0.09 * s, c)
end

ICONS.heart = function(cx, cy, s, c)
    Circle(cx - 0.14 * s, cy - 0.1 * s, 0.2 * s, c)
    Circle(cx + 0.14 * s, cy - 0.1 * s, 0.2 * s, c)
    Poly({
        {x = cx - 0.34 * s, y = cy - 0.02 * s},
        {x = cx + 0.34 * s, y = cy - 0.02 * s},
        {x = cx, y = cy + 0.4 * s},
    }, c)
end

ICONS.eye = function(cx, cy, s, c)
    local upper, lower = {}, {}
    for i = 0, 24 do
        local t = i / 24
        local x = cx + (-0.46 + 0.92 * t) * s
        upper[#upper + 1] = {x = x, y = cy - 0.26 * s * math.sin(math.pi * t)}
        lower[#lower + 1] = {x = x, y = cy + 0.26 * s * math.sin(math.pi * t)}
    end
    local pts = {}
    for _, p in ipairs(upper) do pts[#pts + 1] = p end
    for i = #lower, 1, -1 do pts[#pts + 1] = lower[i] end
    Poly(pts, c)
    Circle(cx, cy, 0.14 * s, Color(20, 20, 26, 255))
    Circle(cx, cy, 0.07 * s, c)
end

ICONS.crown = function(cx, cy, s, c)
    local function p(x, y) return {x = cx + x * s, y = cy + y * s} end
    Poly({p(-0.4, 0.18), p(-0.4, -0.2), p(-0.18, 0.05)}, c)
    Poly({p(-0.18, 0.05), p(0, -0.28), p(0.18, 0.05)}, c)
    Poly({p(0.18, 0.05), p(0.4, -0.2), p(0.4, 0.18)}, c)
    Poly({p(-0.4, 0.18), p(0.4, 0.18), p(0.4, 0.3), p(-0.4, 0.3)}, c)
end

ICONS.bullet = function(cx, cy, s, c)
    local function p(x, y) return {x = cx + x * s, y = cy + y * s} end
    Poly({p(-0.13, 0.45), p(-0.13, -0.1), p(0, -0.46), p(0.13, -0.1), p(0.13, 0.45)}, c)
end

ICONS.cross = function(cx, cy, s, c)
    Line(cx - 0.3 * s, cy - 0.3 * s, cx + 0.3 * s, cy + 0.3 * s, 0.12 * s, c)
    Line(cx + 0.3 * s, cy - 0.3 * s, cx - 0.3 * s, cy + 0.3 * s, 0.12 * s, c)
end

ICONS.arrow = function(cx, cy, s, c)
    local function p(x, y) return {x = cx + x * s, y = cy + y * s} end
    Poly({p(0, -0.5), p(0.42, 0.42), p(-0.42, 0.42)}, c)
end

ICONS.warn = function(cx, cy, s, c)
    local function p(x, y) return {x = cx + x * s, y = cy + y * s} end
    Poly({p(0, -0.46), p(0.46, 0.38), p(-0.46, 0.38)}, c)
    Poly({p(-0.05, -0.12), p(0.05, -0.12), p(0.04, 0.18), p(-0.04, 0.18)}, UI.Fade(Color(20, 20, 26), 1))
    Circle(cx, cy + 0.3 * s, 0.035 * s, UI.Fade(Color(20, 20, 26), 1))
end

ICONS.round = function(cx, cy, s, c)
    Ring(cx, cy, 0.36 * s, 0.09 * s, c)
    Circle(cx, cy, 0.12 * s, c)
end

-- Отрисовка иконки по имени. col — цвет, s — размер в пикселях
function UI.Icon(name, cx, cy, s, col)
    local fn = ICONS[name]
    if fn then fn(cx, cy, s, col or UI.WHITE) end
end

-- Иконка в квадратной рамке
function UI.IconBox(name, x, y, size, col)
    UI.Rect(x, y, size, size, UI.Fade(col, 0.16))
    UI.Accent(x, y, size, size, 1)
    UI.Icon(name, x + size / 2, y + size / 2, size * 0.62, col)
end
