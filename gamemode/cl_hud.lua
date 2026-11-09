-- GRIMOHOD: HUD в стиле qmenu — баннеры, таймер, карточка роли, прицел,
-- лента убийств, хитмаркеры, направления урона, наблюдение, интро роли.

local UI = GRIM.UI
local PAL = GRIM.Palette
local S = UI.S
local ROLE = GRIM.ROLE
local ST = GRIM.STATE

GRIM.LocalRole = GRIM.LocalRole or 0
local HUD = {}
GRIM.HUD = HUD

local HIDE = {
    CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true,
    CHudCrosshair = true, CHudDamageIndicator = true, CHudDeathNotice = true,
}
hook.Add("HUDShouldDraw", "GRIM_HideDefaultHUD", function(name)
    if HIDE[name] then return false end
end)

local function LP()
    local ply = LocalPlayer()
    return IsValid(ply) and ply or nil
end

-- =====================================================================
-- Баннеры (крупные объявления по центру)
-- =====================================================================
local bannerQueue, bannerNow = {}, nil

function HUD.Banner(title, sub, icon, col, dur)
    bannerQueue[#bannerQueue + 1] = {title = title, sub = sub, icon = icon, col = col, dur = dur or 3}
end

net.Receive("grim_banner", function()
    local title = net.ReadString()
    local sub = net.ReadString()
    local icon = net.ReadString()
    local col = net.ReadColor()
    local dur = net.ReadFloat()
    HUD.Banner(title, sub, icon, col, dur)
end)

local function DrawBanner()
    if not bannerNow then
        bannerNow = table.remove(bannerQueue, 1)
        if not bannerNow then return end
        bannerNow.t0 = CurTime()
    end

    local b = bannerNow
    local t = CurTime() - b.t0
    if t > b.dur + 0.5 then
        bannerNow = nil
        return
    end

    local inK = UI.Ease.OutCubic(t / 0.35)
    local outK = t > b.dur and (1 - UI.Ease.InOut((t - b.dur) / 0.5)) or 1
    local k = math.min(inK, outK)

    local w, h = S(560), S(92)
    local x = ScrW() * 0.5 - w * 0.5
    local y = S(170) - (1 - inK) * S(24)

    UI.Panel(x, y, w, h, UI.BG.a * k)
    UI.Rect(x, y, S(4), h, UI.Fade(b.col, k))
    UI.Icon(b.icon, x + S(50), y + h * 0.5, S(44), UI.Fade(b.col, k))
    UI.Text(b.title, "GRIM_Big", x + S(96), y + S(18), UI.Fade(UI.WHITE, k))
    UI.Text(b.sub, "GRIM_Small", x + S(96), y + S(60), UI.Fade(UI.GREY, k))
end

-- =====================================================================
-- Интро роли (в начале подготовки)
-- =====================================================================
local intro

net.Receive("grim_role", function()
    local role = net.ReadUInt(3)
    GRIM.LocalRole = role
    if role ~= ROLE.NONE then
        intro = {role = role, t0 = CurTime()}
    end
end)

local function DrawIntro()
    if not intro then return end
    local info = GRIM.RoleInfo[intro.role]
    local t = CurTime() - intro.t0
    if t > 3.4 then
        intro = nil
        return
    end

    local fadeIn = UI.Ease.OutCubic(t / 0.4)
    local fadeOut = 1 - UI.Ease.InOut(math.Clamp((t - 2.8) / 0.6, 0, 1))
    local k = math.min(fadeIn, fadeOut)

    local w, h = S(680), S(230)
    local cx, cy = ScrW() * 0.5, ScrH() * 0.36 + (1 - fadeIn) * S(18)
    local x, y = cx - w * 0.5, cy - h * 0.5

    UI.Panel(x, y, w, h, UI.BG.a * k)
    UI.Accent(x, y, w, h, k)

    local iconScale = UI.Ease.OutBack(math.min(1, t / 0.6))
    local isz = S(120) * math.max(0.01, iconScale)
    UI.Rect(x + S(34), cy - isz / 2, isz, isz, UI.Fade(info.color, 0.14 * k))
    UI.Icon(info.icon, x + S(34) + isz / 2, cy, isz * 0.62, UI.Fade(info.color, k))

    local tx = x + S(190)
    UI.Text("ТЫ — " .. string.upper(info.name), "GRIM_Title", tx, y + S(34), UI.Fade(info.color, k))
    local typed = UI.Typed(info.desc, t - 0.4, 42)
    local lines = UI.Wrap(typed, "GRIM_Small", w - S(230))
    for i, line in ipairs(lines) do
        UI.Text(line, "GRIM_Small", tx, y + S(98) + (i - 1) * S(20), UI.Fade(UI.WHITE, k * 0.9))
    end
    UI.Text("Подготовка. Не выдавай свою роль.", "GRIM_Tiny", tx, y + h - S(34), UI.Fade(UI.GREY, k))
end

-- =====================================================================
-- Таймер и статус раунда (сверху по центру)
-- =====================================================================
local function FormatTime(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local function DrawTop(ply)
    local state = GRIM.GetState()
    local left = GetGlobalFloat("grim_stateend", 0) - CurTime()
    local round = GetGlobalInt("grim_round", 0)

    local label, col
    if state == ST.WAIT then
        label, col = "ОЖИДАНИЕ ИГРОКОВ  " .. team.NumPlayers(GRIM.TEAM_PLAYER) .. "/" .. GRIM.CV.MinPlayers:GetInt(), UI.GREY
    elseif state == ST.PREP then
        label, col = "ПОДГОТОВКА", UI.BLUE
    elseif state == ST.ACTIVE then
        label, col = "РАУНД " .. round, UI.ORANGE
    else
        label, col = "ИТОГИ", UI.GREEN
    end

    local w, h = S(380), S(46)
    local x, y = ScrW() * 0.5 - w * 0.5, S(14)
    local active = state == ST.ACTIVE
    UI.Panel(x, y, w, h)
    UI.Accent(x, y, w, h, active and 1 or 0)

    UI.Text(label, "GRIM_Tab", x + S(18), y + h * 0.5, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if state == ST.PREP or state == ST.ACTIVE or state == ST.END then
        local timeCol = UI.WHITE
        if state == ST.ACTIVE and left < 10 then
            timeCol = UI.Mix(UI.WHITE, UI.RED, UI.Pulse(8))
        end
        UI.Icon("clock", x + w - S(96), y + h * 0.5, S(20), UI.Fade(col, 0.9))
        UI.Text(FormatTime(left), "GRIM_Row", x + w - S(18), y + h * 0.5, timeCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

local function DrawLogo()
    local text = "GRIMOHOD"
    local cx, cy = ScrW() * 0.5, ScrH() * 0.28
    local font = "GRIM_Logo"
    surface.SetFont(font)
    local total = surface.GetTextSize(text)
    local x = cx - total * 0.5
    local t = CurTime()
    for i = 1, #text do
        local ch = string.sub(text, i, i)
        local dy = math.sin(t * 2.2 + i * 0.6) * S(6)
        local cw = surface.GetTextSize(string.sub(text, 1, i - 1))
        local col = i % 2 == 0 and UI.ORANGE or UI.WHITE
        draw.SimpleText(ch, font, x + cw + S(2), cy + dy + S(3), Color(0, 0, 0, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(ch, font, x + cw, cy + dy, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    UI.Text("Найди убийцу. Или стань им.", "GRIM_Small", cx, cy + S(50), UI.GREY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- =====================================================================
-- Левый верх: живые
-- =====================================================================
local function DrawAlive()
    local alive = 0
    local total = 0
    for _, p in ipairs(team.GetPlayers(GRIM.TEAM_PLAYER)) do
        total = total + 1
        if p:Alive() then alive = alive + 1 end
    end
    local x, y = S(24), S(20)
    local w, h = S(170), S(46)
    UI.Panel(x, y, w, h)
    UI.Icon("person", x + S(26), y + h * 0.5, S(24), UI.ORANGE)
    UI.Text("ЖИВЫХ", "GRIM_Tiny", x + S(50), y + S(9), UI.GREY)
    UI.Text(alive .. " / " .. total, "GRIM_Row", x + S(50), y + S(22), UI.WHITE)
end

-- =====================================================================
-- Низ слева: карточка игрока
-- =====================================================================
local function DrawCard(ply)
    local role = GRIM.LocalRole
    local info = GRIM.RoleInfo[role] or GRIM.RoleInfo[ROLE.NONE]
    local w, h = S(340), S(118)
    local x, y = S(24), ScrH() - S(24) - h

    UI.Panel(x, y, w, h)
    UI.Accent(x, y, w, h, 0)

    local box = S(78)
    local pulse = role == ROLE.MURDERER and UI.Pulse(4) or 0
    UI.Rect(x + S(16), y + S(20), box, box, UI.Fade(info.color, 0.14 + 0.08 * pulse))
    UI.Accent(x + S(16), y + S(20), box, box, 1)
    UI.Icon(info.icon, x + S(16) + box * 0.5, y + S(20) + box * 0.5, box * 0.6, info.color)

    local tx = x + S(112)
    UI.Text(string.upper(info.name), "GRIM_Row", tx, y + S(18), info.color)

    -- Здоровье
    local hp = math.Clamp(ply:Health(), 0, ply:GetMaxHealth() > 0 and ply:GetMaxHealth() or 100)
    local maxHp = ply:GetMaxHealth() > 0 and ply:GetMaxHealth() or 100
    local hpCol = hp < 35 and UI.RED or UI.ORANGE
    UI.Text("ЗДОРОВЬЕ", "GRIM_Tiny", tx, y + S(48), UI.GREY)
    UI.Text(tostring(math.floor(hp)), "GRIM_Tiny", x + w - S(16), y + S(48), UI.WHITE, TEXT_ALIGN_RIGHT)
    UI.Bar(tx, y + S(64), w - S(128), S(6), hp / maxHp, hpCol)

    -- Вторая строка: патроны или скрытность
    local wep = ply:GetActiveWeapon()
    if role == ROLE.MURDERER then
        local a = ply:GetColor().a
        local hidden = math.Clamp((255 - a) / 215, 0, 1)
        UI.Text("СКРЫТНОСТЬ", "GRIM_Tiny", tx, y + S(82), UI.GREY)
        UI.Bar(tx, y + S(98), w - S(128), S(6), hidden, UI.BLUE)
    elseif role == ROLE.DETECTIVE and IsValid(wep) and wep:GetClass() == "weapon_grim_magnum" then
        local reserve = ply:GetAmmoCount("357")
        UI.Text("ПАТРОНЫ", "GRIM_Tiny", tx, y + S(82), UI.GREY)
        UI.Text(wep:Clip1() .. " + " .. reserve, "GRIM_Row", tx, y + S(94), UI.WHITE)
    end

    -- Очки
    local pts = ply:GetNWInt("grim_points", 0)
    UI.Icon("coin", x + w - S(30), y + S(18), S(20), UI.ORANGE)
    UI.Text(tostring(pts), "GRIM_Row", x + w - S(48), y + S(18), UI.WHITE, TEXT_ALIGN_RIGHT)
end

-- =====================================================================
-- Прицел
-- =====================================================================
local function DrawCrosshair(ply)
    local cx, cy = ScrW() * 0.5, ScrH() * 0.5
    local wep = ply:GetActiveWeapon()
    local cd = 0
    if IsValid(wep) and wep.GetNextPrimaryFire then
        cd = math.max(0, wep:GetNextPrimaryFire() - CurTime())
    end
    local gap = S(5) + cd * S(16)

    local tr = ply:GetEyeTrace()
    local onTarget = IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity:Alive()
    local col = onTarget and UI.ORANGE or UI.WHITE
    local len = S(7)

    surface.SetDrawColor(col.r, col.g, col.b, 220)
    surface.DrawLine(cx - gap - len, cy, cx - gap, cy)
    surface.DrawLine(cx + gap, cy, cx + gap + len, cy)
    surface.DrawLine(cx, cy - gap - len, cx, cy - gap)
    surface.DrawLine(cx, cy + gap, cx, cy + gap + len)
    UI.Diamond(cx, cy, S(2), UI.Fade(col, 0.9))
end

-- =====================================================================
-- Направления урона и хитмаркеры
-- =====================================================================
local dmgMarks = {}
net.Receive("grim_damage", function()
    dmgMarks[#dmgMarks + 1] = {pos = net.ReadVector(), t = CurTime()}
end)

local function DrawDamageDirs(ply)
    local cx, cy = ScrW() * 0.5, ScrH() * 0.5
    local eyeYaw = EyeAngles().y
    local r = S(190)
    for i = #dmgMarks, 1, -1 do
        local m = dmgMarks[i]
        local age = CurTime() - m.t
        if age > 1.4 then
            table.remove(dmgMarks, i)
        else
            local k = 1 - age / 1.4
            local d = math.rad(((m.pos - ply:GetPos()):Angle().y) - eyeYaw)
            local dx, dy = -math.sin(d), -math.cos(d)
            local ex, ey = cx + dx * r, cy + dy * r
            local s = S(14)
            local px, py = -dy, dx
            draw.NoTexture()
            surface.SetDrawColor(PAL.RED.r, PAL.RED.g, PAL.RED.b, math.floor(230 * k))
            surface.DrawPoly({
                {x = ex + dx * s, y = ey + dy * s},
                {x = ex - dx * s * 0.5 + px * s * 0.7, y = ey - dy * s * 0.5 + py * s * 0.7},
                {x = ex - dx * s * 0.5 - px * s * 0.7, y = ey - dy * s * 0.5 - py * s * 0.7},
            })
        end
    end
end

local hitAt, hitKill = -10, false
-- Единственный обработчик grim_hit: остальные модули подписываются на хук GRIM_Hit
net.Receive("grim_hit", function()
    local kill = net.ReadBool()
    hitKill = kill
    hitAt = CurTime()
    hook.Run("GRIM_Hit", kill)
end)

local function DrawHitMarker()
    local age = (CurTime() - hitAt) / 0.28
    if age > 1 then return end
    local cx, cy = ScrW() * 0.5, ScrH() * 0.5
    local k = UI.Ease.OutCubic(age)
    local gap = S(8) + S(6) * (1 - k)
    local len = S(9)
    local col = hitKill and PAL.RED or PAL.WHITE
    local a = math.floor(255 * (1 - age))
    surface.SetDrawColor(col.r, col.g, col.b, a)
    for _, dir in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
        local x1, y1 = cx + dir[1] * gap, cy + dir[2] * gap
        surface.DrawLine(x1, y1, x1 + dir[1] * len, y1 + dir[2] * len)
    end
end

-- =====================================================================
-- Лента убийств (сверху справа)
-- =====================================================================
local feed = {}
net.Receive("grim_killfeed", function()
    local attacker = net.ReadString()
    local victim = net.ReadString()
    local weapon = net.ReadString()
    table.insert(feed, 1, {a = attacker, v = victim, w = weapon, t = CurTime()})
    while #feed > 6 do table.remove(feed) end
end)

local WEAPON_ICON = {knife = "knife", magnum = "bullet", other = "cross"}

local function DrawKillFeed()
    local right = ScrW() - S(24)
    local y = S(72)
    for i = #feed, 1, -1 do
        local e = feed[i]
        local age = CurTime() - e.t
        if age > 7 then
            table.remove(feed, i)
        else
            local appear = UI.Ease.OutCubic(age / 0.3)
            local fade = math.Clamp((7 - age) / 1, 0, 1)
            local k = math.min(appear, fade)
            local h = S(30)
            local w = S(380)
            local x = right - w + (1 - appear) * S(40)

            UI.Panel(x, y, w, h, UI.BG.a * k)
            local vx = x + w - S(12)
            local vName = UI.Fit(e.v, "GRIM_Card", S(170))
            UI.Text(vName, "GRIM_Card", vx, y + h * 0.5, UI.Fade(UI.WHITE, k), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            surface.SetFont("GRIM_Card")
            local vw = surface.GetTextSize(vName)
            UI.Icon(WEAPON_ICON[e.w] or "cross", vx - vw - S(28), y + h * 0.5, S(18), UI.Fade(PAL.RED, k))

            if e.a ~= "" then
                local aName = UI.Fit(e.a, "GRIM_Card", S(150))
                UI.Text(aName, "GRIM_Card", x + S(12), y + h * 0.5, UI.Fade(UI.ORANGE, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            y = y + h + S(6)
        end
    end
end

-- =====================================================================
-- Тосты (короткие уведомления слева по центру)
-- =====================================================================
local toasts = {}
net.Receive("grim_toast", function()
    local text = net.ReadString()
    local col = net.ReadColor()
    table.insert(toasts, 1, {text = text, col = col, t = CurTime()})
    while #toasts > 5 do table.remove(toasts) end
end)

local function DrawToasts()
    local x = S(24)
    local y = ScrH() * 0.5 + S(40)
    for i = #toasts, 1, -1 do
        local e = toasts[i]
        local age = CurTime() - e.t
        if age > 4 then
            table.remove(toasts, i)
        else
            local appear = UI.Ease.OutCubic(age / 0.25)
            local k = math.min(appear, math.Clamp((4 - age) / 0.8, 0, 1))
            local h = S(30)
            local w = S(420)
            UI.Panel(x - (1 - appear) * S(20), y, w, h, UI.BG.a * k)
            UI.Rect(x - (1 - appear) * S(20), y, S(3), h, UI.Fade(e.col, k))
            UI.Text(e.text, "GRIM_Small", x + S(14) - (1 - appear) * S(20), y + h * 0.5, UI.Fade(UI.WHITE, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            y = y + h + S(6)
        end
    end
end

-- Результат осмотра тела
net.Receive("grim_inspect", function()
    local name = net.ReadString()
    local role = net.ReadUInt(3)
    local killer = net.ReadString()
    local info = GRIM.RoleInfo[role] or GRIM.RoleInfo[ROLE.NONE]
    HUD.Toast("Осмотр: " .. name .. " — " .. info.name, info.color)
    if killer ~= "" then
        HUD.Toast("Убийца: " .. killer, PAL.RED)
    end
end)

function HUD.Toast(text, col)
    table.insert(toasts, 1, {text = text, col = col or UI.WHITE, t = CurTime()})
end

-- =====================================================================
-- Всплывающие «+очки» над тайниками
-- =====================================================================
local pops = {}
net.Receive("grim_coinpop", function()
    local pos = net.ReadVector()
    local amount = net.ReadInt(16)
    pops[#pops + 1] = {pos = pos, amount = amount, t = CurTime()}
end)

local function DrawCoinPops()
    for i = #pops, 1, -1 do
        local p = pops[i]
        local age = CurTime() - p.t
        if age > 1.2 then
            table.remove(pops, i)
        else
            local sp = (p.pos + Vector(0, 0, age * 40)):ToScreen()
            if sp.visible then
                local k = 1 - age / 1.2
                UI.Icon("coin", sp.x - S(22), sp.y, S(18), UI.Fade(UI.ORANGE, k))
                UI.Text("+" .. p.amount, "GRIM_Row", sp.x - S(6), sp.y, UI.Fade(UI.ORANGE, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end
end

-- =====================================================================
-- Наблюдение за живыми после смерти
-- =====================================================================
local function DrawSpectate(ply)
    local target = ply:GetObserverTarget()
    local name = IsValid(target) and target:IsPlayer() and target:Nick() or "—"
    local w, h = S(460), S(54)
    local x, y = ScrW() * 0.5 - w * 0.5, ScrH() - S(30) - h
    UI.Panel(x, y, w, h)
    UI.Icon("eye", x + S(34), y + h * 0.5, S(26), UI.ORANGE)
    UI.Text("НАБЛЮДЕНИЕ  ·  " .. UI.Fit(name, "GRIM_Row", S(260)), "GRIM_Row", x + S(64), y + S(14), UI.WHITE)
    UI.Text("ЛКМ / ПКМ — сменить игрока", "GRIM_Tiny", x + S(64), y + S(36), UI.GREY)
end

-- =====================================================================
-- Главный цикл отрисовки
-- =====================================================================
hook.Add("HUDPaint", "GRIM_HUD", function()
    local ply = LP()
    if not ply then return end

    local state = GRIM.GetState()
    if state == ST.WAIT then
        GRIM.LocalRole = ROLE.NONE
    end

    DrawTop(ply)

    if state == ST.WAIT then
        DrawLogo()
    end

    if ply:Team() == GRIM.TEAM_PLAYER and ply:Alive() and state ~= ST.WAIT then
        DrawAlive()
        DrawCard(ply)
        DrawCrosshair(ply)
        DrawHitMarker()
        DrawDamageDirs(ply)
    elseif not ply:Alive() and state ~= ST.WAIT and ply:GetObserverMode() ~= OBS_MODE_NONE then
        DrawSpectate(ply)
        DrawAlive()
    end

    DrawKillFeed()
    DrawToasts()
    DrawCoinPops()
    DrawBanner()
    DrawIntro()
end)

-- Скрываем подсказку с именем игрока под прицелом (в murder это читерство)
hook.Add("HUDDrawTargetID", "GRIM_NoTargetID", function()
    return false
end)
