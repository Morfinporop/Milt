-- GRIMOHOD: отправка сетевых сообщений (сервер -> клиент)

GRIM.Net = GRIM.Net or {}
local NET = GRIM.Net

-- Роль игрока (видит только он сам)
function NET.Role(ply)
    if not IsValid(ply) then return end
    net.Start("grim_role")
    net.WriteUInt(ply.GrimRole or 0, 3)
    net.Send(ply)
end

-- Крупный баннер по центру экрана. target = nil -> всем
function NET.Banner(target, title, subtitle, icon, color, duration)
    net.Start("grim_banner")
    net.WriteString(title or "")
    net.WriteString(subtitle or "")
    net.WriteString(icon or "")
    net.WriteColor(color or GRIM.Palette.ORANGE)
    net.WriteFloat(duration or 3)
    if target then net.Send(target) else net.Broadcast() end
end

-- Лента убийств
function NET.KillFeed(attackerName, victimName, weapon)
    net.Start("grim_killfeed")
    net.WriteString(attackerName or "")
    net.WriteString(victimName or "")
    net.WriteString(weapon or "other")
    net.Broadcast()
end

-- Подтверждение попадания (для хитмаркера)
function NET.Hit(ply, kill)
    if not IsValid(ply) then return end
    net.Start("grim_hit")
    net.WriteBool(kill and true or false)
    net.Send(ply)
end

-- Направление урона (индикатор по краю экрана)
function NET.Damage(ply, fromPos)
    if not IsValid(ply) or not fromPos then return end
    net.Start("grim_damage")
    net.WriteVector(fromPos)
    net.Send(ply)
end

-- Итоги раунда
function NET.RoundEnd(winner, reason, rows)
    net.Start("grim_roundend")
    net.WriteUInt(winner or 0, 3)
    net.WriteString(reason or "")
    net.WriteTable(rows or {})
    net.Broadcast()
end

-- Всплывающее «+очки» над тайником
function NET.Coin(ply, pos, amount)
    if not IsValid(ply) then return end
    net.Start("grim_coinpop")
    net.WriteVector(pos)
    net.WriteInt(amount, 16)
    net.Send(ply)
end

-- Результат осмотра тела (приватно)
function NET.Inspect(ply, victimName, victimRole, killerName)
    if not IsValid(ply) then return end
    net.Start("grim_inspect")
    net.WriteString(victimName or "")
    net.WriteUInt(victimRole or 0, 3)
    net.WriteString(killerName or "")
    net.Send(ply)
end

-- Короткое уведомление (тост)
function NET.Toast(ply, text, color)
    if not IsValid(ply) then return end
    net.Start("grim_toast")
    net.WriteString(text or "")
    net.WriteColor(color or GRIM.Palette.WHITE)
    net.Send(ply)
end

