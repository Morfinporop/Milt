-- GRIMOHOD: визуальные эффекты — виньетка при низком здоровье, цветокоррекция
-- для наблюдателя, подсветка тайников и оружия на полу.

local UI = GRIM.UI
local PAL = GRIM.Palette
local S = UI.S
local ST = GRIM.STATE

-- Красная виньетка: кольца полос с убывающей прозрачностью
local function Vignette(alpha)
    local w, h = ScrW(), ScrH()
    local steps = 14
    local band = S(14)
    for i = 0, steps - 1 do
        local inset = i * band
        local k = (1 - i / steps) ^ 2
        local col = Color(PAL.RED.r, 20, 24, math.floor(255 * alpha * k))
        UI.Rect(inset, inset, w - inset * 2, band, col)
        UI.Rect(inset, h - inset - band, w - inset * 2, band, col)
        UI.Rect(inset, inset + band, band, h - inset * 2 - band * 2, col)
        UI.Rect(w - inset - band, inset + band, band, h - inset * 2 - band * 2, col)
    end
end

hook.Add("HUDPaint", "GRIM_Vignette", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or not GRIM.IsActive() then return end
    local maxHp = math.max(1, ply:GetMaxHealth())
    local frac = ply:Health() / maxHp
    if frac >= 0.4 then return end
    local strength = (0.4 - frac) / 0.4
    local pulse = 0.75 + 0.25 * UI.Pulse(5)
    Vignette(math.Clamp(strength * pulse, 0, 1) * 0.85)
end)

-- Цветокоррекция: наблюдатель видит приглушённый мир, низкое здоровье — тоже
hook.Add("RenderScreenspaceEffects", "GRIM_ColorFX", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not GRIM.IsActive() then return end

    local tab = {
        ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
        ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
    }
    local dirty = false

    if not ply:Alive() then
        tab["$pp_colour_colour"] = 0.35
        tab["$pp_colour_brightness"] = -0.03
        tab["$pp_colour_contrast"] = 1.08
        dirty = true
    elseif ply:Health() < 40 then
        tab["$pp_colour_colour"] = 0.55
        dirty = true
    end

    if dirty then DrawColorModify(tab) end
end)

-- Подсветка тайников (зелёным, как в старом Murder) и оружия на полу (синим)
hook.Add("PreDrawHalos", "GRIM_Halos", function()
    if not GRIM.CV.Halo:GetBool() or not GRIM.IsActive() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local loot, guns = {}, {}
    for _, e in ipairs(ents.FindByClass("grim_loot")) do
        if not e:GetNoDraw() then loot[#loot + 1] = e end
    end
    for _, w in ipairs(ents.FindByClass("weapon_grim_magnum")) do
        if not IsValid(w:GetOwner()) then guns[#guns + 1] = w end
    end

    if #loot > 0 then halo.Add(loot, PAL.GREEN, 2, 2, 1, true, false) end
    if #guns > 0 then halo.Add(guns, PAL.BLUE, 2, 2, 1, true, false) end
end)

-- Вспышка при убийстве игрока, который тебя увидел
local flashAt = -10
hook.Add("HUDPaint", "GRIM_Flash", function()
    local age = (CurTime() - flashAt) / 0.5
    if age > 1 then return end
    UI.Rect(0, 0, ScrW(), ScrH(), Color(PAL.RED.r, PAL.RED.g, PAL.RED.b, math.floor(90 * (1 - age))))
end)

hook.Add("GRIM_Hit", "GRIM_FX_Hit", function(kill)
    if kill then flashAt = CurTime() end
end)
