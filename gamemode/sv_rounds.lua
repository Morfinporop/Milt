-- GRIMOHOD: машина состояний раунда.
--   WAIT   — ждём минимум игроков
--   PREP   — подготовка: роли розданы, все на спавне, убийца ещё не может бить
--   ACTIVE — игра: проверка победы каждые 0.2 с, таймер раунда
--   END    — итоги, затем новый раунд

GRIM.Round = GRIM.Round or {}
local RD = GRIM.Round
local ST = GRIM.STATE
local ROLE = GRIM.ROLE
local CFG = GRIM.Config
local NET = GRIM.Net

RD.State = ST.WAIT
RD.Number = 0
RD.EndAt = 0
RD.NextCheck = 0
RD.Murderer = nil
RD.Detective = nil
RD.Winner = nil
RD.Reason = nil

local function SetState(state, duration)
    RD.State = state
    RD.EndAt = duration and (CurTime() + duration) or 0
    SetGlobalInt("grim_state", state)
    SetGlobalFloat("grim_stateend", RD.EndAt)
end

local function MinPlayers()
    return math.max(2, GRIM.CV.MinPlayers:GetInt())
end

-- Удаляем тела, предметы на полу, пересоздаём карту и тайники
function RD.Cleanup()
    GRIM.Player.ClearBodies()

    game.CleanUpMap(false, {})

    for _, wep in ipairs(ents.FindByClass("weapon_*")) do
        if IsValid(wep) and not IsValid(wep:GetOwner()) then wep:Remove() end
    end

    GRIM.Loot.Spawn()
end

function RD.BeginPrep()
    RD.Number = RD.Number + 1
    SetGlobalInt("grim_round", RD.Number)
    RD.Winner, RD.Reason = nil, nil

    RD.Cleanup()

    -- Все подключённые присоединяются к раунду
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:SetTeam(GRIM.TEAM_PLAYER)
            ply.GrimRole = ROLE.NONE
        end
    end
    for _, ply in ipairs(GRIM.GetPlayers(false)) do
        GRIM.Player.Respawn(ply)
    end

    RD.Murderer, RD.Detective = GRIM.Role.Assign()

    for _, ply in ipairs(GRIM.GetPlayers(false)) do
        GRIM.Player.GiveLoadout(ply)
        NET.Role(ply)
    end

    SetState(ST.PREP, GRIM.CV.PrepTime:GetFloat())
    NET.Banner(nil, "РАУНД " .. RD.Number, "Подготовка. Убийца среди вас.", "round", GRIM.Palette.ORANGE, 3)
end

function RD.BeginActive()
    SetState(ST.ACTIVE, GRIM.CV.RoundTime:GetFloat())
    RD.NextCheck = 0
    NET.Banner(nil, "ИГРА НАЧАЛАСЬ", "Найдите убийцу, пока не поздно", "knife", GRIM.Palette.RED, 3)
end

-- Завершение раунда: очки, раскрытие ролей, итоги
function RD.End(winner, reason)
    if RD.State ~= ST.ACTIVE then return end
    RD.Winner, RD.Reason = winner, reason

    local rows = {}
    for _, ply in ipairs(GRIM.GetPlayers(false)) do
        local role = ply.GrimRole or ROLE.NONE
        local alive = ply:Alive()

        if winner == ROLE.INNOCENT and alive and role ~= ROLE.MURDERER and role ~= ROLE.NONE then
            GRIM.Player.AddPoints(ply, CFG.Points.Survive, "выжил")
        elseif winner == ROLE.MURDERER and role == ROLE.MURDERER then
            GRIM.Player.AddPoints(ply, CFG.Points.MurdererWin, "победа")
        end

        ply:SetNWInt("grim_shown", role)
        rows[#rows + 1] = {
            name = ply:Nick(),
            role = role,
            alive = alive,
            kills = ply.GrimKills or 0,
            points = ply:GetNWInt("grim_points", 0),
        }
    end
    table.sort(rows, function(a, b)
        if a.points ~= b.points then return a.points > b.points end
        return a.name < b.name
    end)

    NET.RoundEnd(winner or 0, reason or "", rows)
    SetState(ST.END, GRIM.CV.EndTime:GetFloat())
end

function RD.CheckWin()
    local players = GRIM.GetPlayers(false)
    if #players < MinPlayers() then
        return RD.End(0, "Недостаточно игроков")
    end

    local m = RD.Murderer
    if not IsValid(m) or m:Team() ~= GRIM.TEAM_PLAYER or m.GrimRole ~= ROLE.MURDERER then
        return RD.End(ROLE.INNOCENT, "Убийца покинул игру")
    end
    if not m:Alive() then
        return RD.End(ROLE.INNOCENT, "Убийца уничтожен")
    end

    local innocentsAlive = 0
    for _, p in ipairs(players) do
        if p:Alive() and p.GrimRole ~= ROLE.MURDERER and p.GrimRole ~= ROLE.NONE then
            innocentsAlive = innocentsAlive + 1
        end
    end
    if innocentsAlive == 0 then
        return RD.End(ROLE.MURDERER, "Все мирные мертвы")
    end
end

-- Главный цикл состояний
function RD.Think()
    local now = CurTime()
    local count = #GRIM.GetPlayers(false)

    if RD.State == ST.WAIT then
        if count >= MinPlayers() then RD.BeginPrep() end

    elseif RD.State == ST.PREP then
        if count < MinPlayers() then
            SetState(ST.WAIT)
            NET.Banner(nil, "ОЖИДАНИЕ ИГРОКОВ", "Нужно минимум " .. MinPlayers(), "person", GRIM.Palette.GREY, 3)
        elseif now >= RD.EndAt then
            RD.BeginActive()
        end

    elseif RD.State == ST.ACTIVE then
        if now >= RD.NextCheck then
            RD.NextCheck = now + 0.2
            RD.CheckWin()
        end
        if RD.State == ST.ACTIVE and now >= RD.EndAt then
            RD.End(ROLE.INNOCENT, "Время вышло")
        end

    elseif RD.State == ST.END then
        if now >= RD.EndAt then
            if count >= MinPlayers() then RD.BeginPrep() else SetState(ST.WAIT) end
        end
    end
end

-- Новый игрок: в ожидании — сразу в игру, иначе — наблюдать до следующего раунда
function RD.OnJoin(ply)
    if not IsValid(ply) then return end
    ply.GrimRole = ROLE.NONE
    if RD.State == ST.WAIT then
        GRIM.Player.Respawn(ply)
    else
        GRIM.Player.SetSpectator(ply)
    end
end

function RD.Init()
    SetState(ST.WAIT)
    SetGlobalInt("grim_round", 0)
    timer.Create("grimohod_round", 0.1, 0, RD.Think)
end

hook.Add("PlayerInitialSpawn", "GRIM_Join", function(ply)
    timer.Simple(0.3, function()
        RD.OnJoin(ply)
    end)
end)

concommand.Add("grimohod_restart", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    if RD.State == ST.ACTIVE then
        RD.End(0, "Перезапуск администратором")
    end
    SetState(ST.WAIT)
end)

-- Админ: запустить подготовку немедленно (при ожидании и хотя бы 2 игроках)
concommand.Add("grimohod_forcestart", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    if RD.State ~= ST.WAIT then
        if IsValid(ply) then ply:ChatPrint("[GRIMOHOD] Раунд уже идёт.") end
        return
    end
    if #GRIM.GetPlayers(false) < 2 then
        if IsValid(ply) then ply:ChatPrint("[GRIMOHOD] Нужно минимум 2 игрока.") end
        return
    end
    RD.BeginPrep()
end)
