-- GRIMOHOD: игрок — спавн, снаряжение, урон, смерть, невидимость убийцы,
-- тела и осмотр, наблюдение за живыми после смерти.

GRIM.Player = GRIM.Player or {}
local PL = GRIM.Player
GRIM.Bodies = GRIM.Bodies or {}

local ROLE = GRIM.ROLE
local CFG = GRIM.Config
local PAL = GRIM.Palette

local MODELS = {
    "models/player/group01/male_01.mdl", "models/player/group01/male_02.mdl",
    "models/player/group01/male_03.mdl", "models/player/group01/male_04.mdl",
    "models/player/group01/male_05.mdl", "models/player/group01/male_06.mdl",
    "models/player/group01/male_07.mdl", "models/player/group01/male_08.mdl",
    "models/player/group01/male_09.mdl", "models/player/group01/female_01.mdl",
    "models/player/group01/female_02.mdl", "models/player/group01/female_03.mdl",
    "models/player/group01/female_04.mdl", "models/player/group01/female_06.mdl",
}

function PL.RandomModel()
    return MODELS[math.random(#MODELS)]
end

-- Очки игрока (сохраняются за сессию, видны в таблице)
function PL.AddPoints(ply, n, reason)
    if not IsValid(ply) or n == 0 then return end
    ply:SetNWInt("grim_points", math.max(0, ply:GetNWInt("grim_points", 0) + n))
    if reason then
        GRIM.Net.Toast(ply, string.format("%+d  %s", n, reason), n > 0 and PAL.GREEN or PAL.RED)
    end
end

function PL.ApplySpeeds(ply)
    local murderer = ply.GrimRole == ROLE.MURDERER
    ply:SetWalkSpeed(murderer and 200 or 190)
    ply:SetRunSpeed(murderer and 320 or 265)
end

-- Снаряжение по роли
function PL.GiveLoadout(ply)
    ply:StripWeapons()
    ply:StripAmmo()
    PL.ApplySpeeds(ply)

    if ply.GrimRole == ROLE.MURDERER then
        ply:Give("weapon_grim_knife")
        ply:SelectWeapon("weapon_grim_knife")
    elseif ply.GrimRole == ROLE.DETECTIVE then
        local wep = ply:Give("weapon_grim_magnum")
        if IsValid(wep) then wep:SetClip1(1) end
        ply:SetAmmo(1, "357")
        ply:SelectWeapon("weapon_grim_magnum")
    end
end

-- Возрождение на точке спавна (только при подготовке раунда)
function PL.Respawn(ply)
    if not IsValid(ply) then return end
    ply:UnSpectate()
    ply:SetTeam(GRIM.TEAM_PLAYER)
    ply.GrimModel = PL.RandomModel()
    ply:Spawn()
    ply:SetPos(GRIM.Spawns.Pick(ply))
    ply:SetEyeAngles(Angle(0, math.random(-180, 180), 0))
end

-- Перевод в наблюдатели (до следующего раунда)
function PL.SetSpectator(ply)
    if not IsValid(ply) then return end
    ply:SetTeam(GRIM.TEAM_SPEC)
    if ply:Alive() then ply:KillSilent() end
    PL.Spectate(ply)
end

function PL.Spectate(ply)
    if not IsValid(ply) then return end
    ply:StripWeapons()
    ply:Spectate(OBS_MODE_CHASE)
    local target = PL.NextAlive(ply, nil, 1)
    if IsValid(target) then ply:SpectateEntity(target) end
end

-- Следующий живой игрок для наблюдения (dir = 1 или -1)
function PL.NextAlive(ply, from, dir)
    local list = {}
    for _, p in ipairs(GRIM.GetPlayers(true)) do
        if p ~= ply then list[#list + 1] = p end
    end
    if #list == 0 then return nil end

    local idx = 0
    for i, p in ipairs(list) do
        if p == from then idx = i end
    end
    return list[((idx - 1 + dir) % #list) + 1]
end

-- Невидимость убийцы: стоя неподвижно, он постепенно растворяется
local function UpdateStealth(ply, dt)
    local active = GRIM.IsActive() and ply.GrimRole == ROLE.MURDERER and ply:Alive()
    local target = 255

    if active then
        if ply:GetVelocity():Length2D() > 15 then
            ply.GrimStillSince = nil
        elseif not ply.GrimStillSince then
            ply.GrimStillSince = CurTime()
        end
        if ply.GrimStillSince and CurTime() - ply.GrimStillSince >= CFG.StealthAfter then
            target = CFG.StealthAlpha
        end
    else
        ply.GrimStillSince = nil
    end

    local cur = ply.GrimAlpha or 255
    local nxt = math.Approach(cur, target, (target < cur and 160 or 260) * dt)
    ply.GrimAlpha = nxt

    local a = math.floor(nxt)
    if ply.GrimAppliedAlpha == a then return end
    ply.GrimAppliedAlpha = a

    local visible = a >= 254
    local col = Color(255, 255, 255, a)
    ply:SetRenderMode(visible and RENDERMODE_NORMAL or RENDERMODE_TRANSCOLOR)
    ply:SetColor(col)
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) then
        wep:SetRenderMode(visible and RENDERMODE_NORMAL or RENDERMODE_TRANSCOLOR)
        wep:SetColor(col)
    end
end

-- Фоновый тик: невидимость, переключение камеры наблюдателя
local function Tick()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            UpdateStealth(ply, 0.1)
            if ply:Team() == GRIM.TEAM_SPEC or not ply:Alive() then
                local t = ply:GetObserverTarget()
                if not IsValid(t) or not t:Alive() then
                    local n = PL.NextAlive(ply, nil, 1)
                    if IsValid(n) then ply:SpectateEntity(n) end
                end
            end
        end
    end
end
timer.Create("grimohod_player_tick", 0.1, 0, Tick)

-- Тело: сохраняем ссылку и планируем растворение
function PL.RegisterBody(victim, killer, role)
    local rag = victim:GetRagdollEntity()
    if not IsValid(rag) then return end

    rag.GrimBody = {
        name = victim:Nick(),
        role = role,
        killer = killer,
        inspected = {},
    }
    table.insert(GRIM.Bodies, rag)

    timer.Simple(CFG.BodyLifetime, function()
        PL.Dissolve(rag)
    end)
end

-- Эффект растворения сущности (env_entity_dissolver), затем удаление
function PL.Dissolve(ent)
    if not IsValid(ent) or ent.GrimDissolving then return end
    ent.GrimDissolving = true

    local name = "grim_dissolve_" .. ent:EntIndex() .. "_" .. math.floor(CurTime() * 100)
    ent:SetName(name)

    local dissolver = ents.Create("env_entity_dissolver")
    if IsValid(dissolver) then
        dissolver:SetKeyValue("dissolvetype", "0")
        dissolver:SetKeyValue("magnitude", "0")
        dissolver:SetPos(ent:GetPos())
        dissolver:SetKeyValue("target", name)
        dissolver:Spawn()
        dissolver:Fire("Dissolve", name, 0)
        dissolver:Fire("Kill", "", 2)
    end
    timer.Simple(2.2, function()
        if IsValid(ent) then ent:Remove() end
    end)
end

function PL.ClearBodies()
    for _, rag in ipairs(GRIM.Bodies) do
        PL.Dissolve(rag)
    end
    GRIM.Bodies = {}
end

-- Учёт убийства: лента, очки, свидетели-детективы
function PL.OnKill(victim, killer, inflictor, role)
    local weapon = "other"
    if IsValid(inflictor) then
        local c = inflictor:GetClass()
        if c == "weapon_grim_knife" then weapon = "knife"
        elseif c == "weapon_grim_magnum" then weapon = "magnum" end
    end

    GRIM.Net.KillFeed(IsValid(killer) and killer:Nick() or "", victim:Nick(), weapon)
    if not IsValid(killer) then return end

    killer.GrimKills = (killer.GrimKills or 0) + 1
    local P = CFG.Points

    if role == ROLE.MURDERER and killer ~= victim then
        PL.AddPoints(killer, P.FindMurderer, "убийца найден")
    elseif killer.GrimRole == ROLE.MURDERER then
        PL.AddPoints(killer, P.KillInnocent, "убийство")
        PL.WitnessKill(killer)
    elseif killer.GrimRole == ROLE.DETECTIVE then
        PL.AddPoints(killer, P.MistakeKill, "ошибка: невиновный")
        GRIM.Net.Toast(killer, "Ты убил невиновного. Будь осторожнее.", PAL.ORANGE)
    end
end

-- Детективы, стоящие рядом и видящие убийцу, узнают его
function PL.WitnessKill(murderer)
    for _, ply in ipairs(GRIM.GetPlayers(true)) do
        if ply.GrimRole == ROLE.DETECTIVE and ply:GetPos():DistToSqr(murderer:GetPos()) < 1200 * 1200 then
            local tr = util.TraceLine({
                start = ply:EyePos(),
                endpos = murderer:WorldSpaceCenter(),
                filter = ply,
                mask = MASK_SHOT,
            })
            if tr.Entity == murderer then
                ply.GrimKnown = murderer
                GRIM.Net.Toast(ply, "Ты видел убийцу: " .. murderer:Nick(), PAL.BLUE)
            end
        end
    end
end

-- Осмотр тела (E): узнаём жертву, детектив — ещё и убийцу
hook.Add("PlayerUse", "GRIM_InspectBody", function(ply, ent)
    if not IsValid(ent) or not ent.GrimBody or not ply:Alive() then return end
    if not GRIM.IsActive() then return end

    local body = ent.GrimBody
    local key = ply:EntIndex()
    if body.inspected[key] then return end
    body.inspected[key] = true

    local killerName = ""
    if ply.GrimRole == ROLE.DETECTIVE and IsValid(body.killer) then
        ply.GrimKnown = body.killer
        killerName = body.killer:Nick()
    end
    GRIM.Net.Inspect(ply, body.name, body.role, killerName)
end)

-- Урон: в раунде только от игроков, без урона от окружения и падений
hook.Add("EntityTakeDamage", "GRIM_Damage", function(target, dmg)
    if not target:IsPlayer() then return end

    local attacker = dmg:GetAttacker()
    if not GRIM.IsActive() or not target:Alive() then return true end
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == target then return true end
    if not attacker.GrimRole or attacker.GrimRole == GRIM.ROLE.NONE then return true end

    local inf = dmg:GetInflictor()
    if IsValid(inf) and inf:GetClass() == "weapon_grim_knife" and attacker.GrimRole ~= ROLE.MURDERER then
        return true
    end

    GRIM.Net.Hit(attacker, dmg:GetDamage() >= target:Health())
    GRIM.Net.Damage(target, attacker:GetPos())

    local ed = EffectData()
    ed:SetOrigin(dmg:GetDamagePosition())
    ed:SetNormal(Vector(0, 0, 1))
    ed:SetScale(1)
    util.Effect("BloodImpact", ed, true, true)
end)

hook.Add("PlayerDeath", "GRIM_PlayerDeath", function(victim, inflictor, attacker)
    local role = victim.GrimRole or ROLE.NONE
    local killer = (IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim) and attacker or nil

    if GRIM.IsActive() then
        PL.OnKill(victim, killer, inflictor, role)
    end
    PL.RegisterBody(victim, killer, role)

    local wep = victim:GetWeapon("weapon_grim_magnum")
    if IsValid(wep) then victim:DropWeapon(wep) end

    timer.Simple(0.6, function()
        if IsValid(victim) then PL.Spectate(victim) end
    end)
end)

-- Никакого автоматического респавна: возрождение только в подготовке раунда
hook.Add("PlayerDeathThink", "GRIM_NoRespawn", function()
    return true
end)

hook.Add("PlayerSpawn", "GRIM_PlayerSpawn", function(ply)
    if ply.GrimModel then ply:SetModel(ply.GrimModel) end
    ply.GrimStillSince = nil
    ply.GrimAlpha = 255
    ply.GrimAppliedAlpha = 255
    ply:SetRenderMode(RENDERMODE_NORMAL)
    ply:SetColor(Color(255, 255, 255, 255))
end)

hook.Add("PlayerLoadout", "GRIM_NoLoadout", function()
    return true
end)

hook.Add("KeyPress", "GRIM_SpectateCycle", function(ply, key)
    if ply:Alive() or ply:GetObserverMode() == OBS_MODE_NONE then return end
    if key ~= IN_ATTACK and key ~= IN_ATTACK2 then return end
    local dir = key == IN_ATTACK and 1 or -1
    local target = PL.NextAlive(ply, ply:GetObserverTarget(), dir)
    if IsValid(target) then ply:SpectateEntity(target) end
end)

hook.Add("PlayerNoClip", "GRIM_NoClip", function(ply)
    return ply:IsAdmin()
end)

hook.Add("GetFallDamage", "GRIM_NoFallDamage", function()
    return 0
end)
