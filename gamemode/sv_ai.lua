-- GRIMOHOD: мозг ботов.
-- Бот — обычный игрок, которым управляем через StartCommand: движение, взгляд, кнопки.
-- Решения принимаются ~8 раз в секунду по роли:
--   убийца   — выбирает жертву (с учётом свидетелей), подкрадывается, бьёт ножом;
--   детектив — идёт осматривать тела, узнаёт убийцу и стреляет с задержкой реакции;
--   мирный   — убегает от ножа и тел, собирает тайники, подбирает магнум.
-- Перемещение идёт по навигации (navmesh или граф GRIM.Nav).

GRIM.AI = GRIM.AI or {}
local AI = GRIM.AI
local ROLE = GRIM.ROLE
local ST = GRIM.STATE

local SEE_SQR = 2200 * 2200
local MOVE = 10000
local TICK_MIN, TICK_RAND = 0.12, 0.06

local function Dbg(b, msg)
    if GRIM.CV.Debug:GetBool() then
        print("[GRIMOHOD/AI] " .. b.ply:Nick() .. ": " .. msg)
    end
end

local function ApproachAng(cur, goal, step)
    local dp = math.NormalizeAngle(goal.p - cur.p)
    local dy = math.NormalizeAngle(goal.y - cur.y)
    local len = math.sqrt(dp * dp + dy * dy)
    local t = (len > step and len > 0) and (step / len) or 1
    return Angle(math.Clamp(cur.p + dp * t, -89, 89), cur.y + dy * t, 0)
end

local function AngleDiff(a, b)
    return math.abs(math.NormalizeAngle(a.y - b.y)) + math.abs(math.NormalizeAngle(a.p - b.p))
end

local function CanSee(ply, target)
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = target:WorldSpaceCenter(),
        filter = ply,
        mask = MASK_SHOT,
    })
    return tr.Entity == target
end

local function CanSeePos(ply, pos)
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = pos,
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })
    return tr.Fraction > 0.97
end

local function HoldsKnife(ply)
    local w = ply:GetActiveWeapon()
    return IsValid(w) and w:GetClass() == "weapon_grim_knife"
end

local function IsVictim(p)
    return IsValid(p) and p:Alive() and p:Team() == GRIM.TEAM_PLAYER
        and p.GrimRole ~= ROLE.MURDERER and p.GrimRole ~= ROLE.NONE
end

local function AvailableLoot(e)
    return IsValid(e) and e.GrimTakenUntil == nil
end

-- Создание состояния мозга
function AI.Attach(bot)
    bot.GrimBrain = {
        ply = bot,
        view = bot:EyeAngles(),
        nextTick = 0,
        aimGoal = nil,
        moveGoal = nil,
        aimNoise = Angle(0, 0, 0),
        attack = false,
        attackRate = 0.6,
        nextAttack = 0,
        use = false,
        nextUse = 0,
        jump = false,
        nextJump = 0,
        sneak = false,
        path = nil,
        pathI = 1,
        pathGoal = nil,
        pathExpire = 0,
        stuckPos = nil,
        stuckAt = 0,
        stuckCount = 0,
        round = -1,
        knifeSeen = nil,
        bodySeen = nil,
        flee = 0,
        fleeFrom = nil,
        fleeGoal = nil,
        fleeAt = 0,
        wander = nil,
        wanderAt = 0,
        loot = nil,
        gun = nil,
        wantsGun = false,
        target = nil,
        targetAt = 0,
        reactAt = nil,
        idleYaw = 0,
        idleAt = 0,
        bodyReact = 0,
        lastMurderer = nil,
    }
end

-- Сброс решений при начале нового раунда
local function ResetRound(b)
    if b.round == GRIM.Round.Number then return end
    b.round = GRIM.Round.Number
    b.target, b.loot, b.gun, b.wander = nil, nil, nil, nil
    b.fleeGoal, b.fleeFrom, b.path = nil, nil, nil
    b.flee = 0
    b.reactAt = nil
    b.wantsGun = math.random() < 0.5
end

-- Управление командой (вызывается каждый usercmd)
function AI.Control(bot, cmd)
    local b = bot.GrimBrain
    if not b then return end

    if not bot:Alive() then
        cmd:ClearMovement()
        cmd:ClearButtons()
        return
    end

    local now = CurTime()
    if now >= b.nextTick then
        b.nextTick = now + TICK_MIN + math.Rand(0, TICK_RAND)
        AI.Think(b)
    end

    local dt = engine.TickInterval()

    -- Взгляд
    local moveAng
    if b.moveGoal then
        local d = b.moveGoal - bot:GetPos()
        d.z = 0
        if d:LengthSqr() > 16 then moveAng = d:Angle() end
    end

    local goal
    if b.aimGoal then
        goal = b.aimGoal + b.aimNoise
    elseif moveAng then
        goal = Angle(0, moveAng.y, 0)
    else
        goal = b.view
    end
    b.view = ApproachAng(b.view, goal, (b.aimGoal and 420 or 260) * dt)
    cmd:SetViewAngles(b.view)
    bot:SetEyeAngles(b.view)

    -- Движение относительно взгляда
    local fwd, side = 0, 0
    if moveAng then
        local rel = math.rad(math.NormalizeAngle(moveAng.y - b.view.y))
        fwd = math.cos(rel) * MOVE
        side = -math.sin(rel) * MOVE
    end
    cmd:SetForwardMove(fwd)
    cmd:SetSideMove(side)

    -- Кнопки
    local buttons = 0
    if b.attack and now >= b.nextAttack then
        buttons = bit.bor(buttons, IN_ATTACK)
        b.nextAttack = now + b.attackRate
    end
    if b.use and now >= b.nextUse then
        buttons = bit.bor(buttons, IN_USE)
        b.nextUse = now + 0.6
        b.use = false
    end
    if b.jump and now >= b.nextJump then
        buttons = bit.bor(buttons, IN_JUMP)
        b.nextJump = now + 0.8
        b.jump = false
    end
    if b.sneak then
        buttons = bit.bor(buttons, IN_WALK)
    end
    cmd:SetButtons(buttons)
end

-- Один цикл решений
function AI.Think(b)
    local bot = b.ply
    b.aimGoal, b.moveGoal = nil, nil
    b.attack, b.use, b.sneak = false, false, false
    b.aimNoise = Angle(math.Rand(-1.2, 1.2), math.Rand(-1.2, 1.2), 0)

    if not bot:Alive() then return end
    ResetRound(b)

    local state = GRIM.GetState()
    if state == ST.PREP then
        local now = CurTime()
        if now >= b.idleAt then
            b.idleAt = now + math.Rand(2, 4)
            b.idleYaw = math.Rand(-180, 180)
        end
        b.aimGoal = Angle(0, b.idleYaw, 0)
        return
    end
    if state ~= ST.ACTIVE then return end

    AI.Perceive(b)

    local role = bot.GrimRole
    if role == ROLE.MURDERER then
        AI.ThinkMurderer(b)
    elseif role == ROLE.DETECTIVE then
        AI.ThinkDetective(b)
    else
        AI.ThinkInnocent(b)
    end

    AI.CheckStuck(b)
end

-- Что бот видит: ножи, тела
function AI.Perceive(b)
    local bot = b.ply
    local eye = bot:GetPos()
    b.knifeSeen, b.bodySeen = nil, nil

    local bestKnife = math.huge
    for _, other in ipairs(GRIM.GetPlayers(true)) do
        if other ~= bot then
            local d = other:GetPos():DistToSqr(eye)
            if d < SEE_SQR and d < bestKnife and HoldsKnife(other) and CanSee(bot, other) then
                b.knifeSeen = other
                bestKnife = d
            end
        end
    end
    if b.knifeSeen and bestKnife > 500 * 500 then b.knifeSeen = nil end

    for _, rag in ipairs(GRIM.Bodies) do
        if IsValid(rag) and rag.GrimBody and not rag.GrimBody.inspected[bot:EntIndex()] then
            if rag:GetPos():DistToSqr(eye) < 700 * 700 and CanSeePos(bot, rag:WorldSpaceCenter()) then
                b.bodySeen = rag
                break
            end
        end
    end
end

-- Путь до цели: возвращает ближайший промежуточный узел
function AI.FollowTo(b, goal)
    local bot = b.ply
    local pos = bot:GetPos()
    local now = CurTime()

    if not b.path or now > b.pathExpire or not b.pathGoal or b.pathGoal:DistToSqr(goal) > 250 * 250 then
        local path = GRIM.Nav.Find(pos, goal) or {}
        table.insert(path, goal)
        b.path = path
        b.pathI = 1
        b.pathGoal = goal
        b.pathExpire = now + 3
    end

    local path = b.path
    while b.pathI < #path and (path[b.pathI] - pos):Length2D() < 42 do
        b.pathI = b.pathI + 1
    end

    local node = path[b.pathI] or goal
    if node.z - pos.z > 36 and (node - pos):Length2D() < 90 then
        b.jump = true
    end
    return node
end

-- Детектор застревания: если не двигаемся — прыжок, затем сброс целей
function AI.CheckStuck(b)
    local bot = b.ply
    local now = CurTime()
    if not b.moveGoal then
        b.stuckPos, b.stuckAt, b.stuckCount = bot:GetPos(), now, 0
        return
    end
    if now - b.stuckAt < 1.2 then return end

    local pos = bot:GetPos()
    if b.stuckPos and pos:Distance(b.stuckPos) < 30 then
        b.stuckCount = b.stuckCount + 1
        b.jump = true
        b.path = nil
        if b.stuckCount >= 3 then
            Dbg(b, "застрял, выбираю новую цель")
            b.wander, b.loot, b.fleeGoal, b.stuckCount = nil, nil, nil, 0
        end
    else
        b.stuckCount = 0
    end
    b.stuckPos, b.stuckAt = pos, now
end

function AI.Wander(b)
    local now = CurTime()
    local pos = b.ply:GetPos()
    if not b.wander or now > b.wanderAt or (b.wander - pos):Length2D() < 80 then
        b.wander = GRIM.Nav.RandomPos()
        b.wanderAt = now + math.Rand(10, 18)
    end
    b.moveGoal = AI.FollowTo(b, b.wander)
end

-- Точка, максимально далёкая от угрозы (из случайных кандидатов)
local function AwayFrom(pos, threat)
    local best, bestScore = nil, -math.huge
    for _ = 1, 8 do
        local c = GRIM.Nav.RandomPos()
        local score = c:Distance(threat) - 0.3 * c:Distance(pos)
        if score > bestScore then best, bestScore = c, score end
    end
    return best
end

function AI.Flee(b, threat)
    local now = CurTime()
    local pos = b.ply:GetPos()
    if not b.fleeGoal or now > b.fleeAt or (b.fleeGoal - pos):Length2D() < 100 then
        b.fleeGoal = AwayFrom(pos, threat)
        b.fleeAt = now + 6
    end
    b.moveGoal = AI.FollowTo(b, b.fleeGoal)
end

function AI.Witnesses(b, victim)
    local n = 0
    local vp = victim:GetPos()
    for _, p in ipairs(GRIM.GetPlayers(true)) do
        if p ~= b.ply and p ~= victim and p:GetPos():DistToSqr(vp) < 700 * 700 then
            n = n + 1
        end
    end
    return n
end

-- Убийца: выбирает жертву, у которой меньше свидетелей
local function PickVictim(b)
    local best, bestScore = nil, math.huge
    for _, p in ipairs(GRIM.GetPlayers(true)) do
        if p ~= b.ply and IsVictim(p) then
            local score = (p:GetPos() - b.ply:GetPos()):Length2D()
            score = (score + AI.Witnesses(b, p) * 900) * math.Rand(0.8, 1.2)
            if score < bestScore then best, bestScore = p, score end
        end
    end
    return best
end

function AI.ThinkMurderer(b)
    local bot = b.ply
    local knife = bot:GetWeapon("weapon_grim_knife")
    if not IsValid(knife) then
        bot:Give("weapon_grim_knife")
        return
    end
    if bot:GetActiveWeapon() ~= knife then
        bot:SelectWeapon("weapon_grim_knife")
    end

    local now = CurTime()
    if not IsVictim(b.target) or now > b.targetAt then
        b.target = PickVictim(b)
        b.targetAt = now + 25
    end

    local t = b.target
    if not IsValid(t) then
        AI.Wander(b)
        return
    end

    local tp = t:GetPos()
    local pos = bot:GetPos()
    local dz = math.abs(tp.z - pos.z)
    if (tp - pos):Length2D() < 70 and dz < 70 then
        b.aimGoal = (t:WorldSpaceCenter() - bot:EyePos()):Angle()
        b.attackRate = 0.7
        b.attack = AngleDiff(b.view, b.aimGoal) < 25
    else
        b.moveGoal = AI.FollowTo(b, tp)
        b.sneak = AI.Witnesses(b, t) > 0
    end
end

-- Детектив: сначала стреляет в известного убийцу, потом осматривает тела
function AI.ThinkDetective(b)
    local bot = b.ply
    local now = CurTime()
    local m = bot.GrimKnown

    if IsValid(m) and m:Alive() and m.GrimRole == ROLE.MURDERER then
        if CanSee(bot, m) then
            b.lastMurderer = m:GetPos()
            b.aimGoal = (m:WorldSpaceCenter() - bot:EyePos()):Angle()
            b.reactAt = b.reactAt or (now + 0.5)
            local wep = bot:GetWeapon("weapon_grim_magnum")
            local armed = IsValid(wep) and wep:Clip1() > 0
            if now >= b.reactAt and armed and AngleDiff(b.view, b.aimGoal) < 6 then
                b.attackRate = GRIM.Config.MagnumDelay + 0.15
                b.attack = true
            end
            if (m:GetPos() - bot:GetPos()):Length2D() > 600 then
                b.moveGoal = AI.FollowTo(b, m:GetPos())
            end
        else
            b.reactAt = nil
            b.moveGoal = AI.FollowTo(b, b.lastMurderer or m:GetPos())
        end
        return
    end

    b.reactAt = nil

    local body = nil
    local bestD = 3000 * 3000
    for _, rag in ipairs(GRIM.Bodies) do
        if IsValid(rag) and rag.GrimBody and not rag.GrimBody.inspected[bot:EntIndex()] then
            local d = rag:GetPos():DistToSqr(bot:GetPos())
            if d < bestD then body, bestD = rag, d end
        end
    end
    if body then
        local bp = body:WorldSpaceCenter()
        if (body:GetPos() - bot:GetPos()):Length2D() < 90 then
            b.aimGoal = (bp - bot:EyePos()):Angle()
            b.use = true
        else
            b.moveGoal = AI.FollowTo(b, body:GetPos())
        end
        return
    end

    AI.ThinkInnocent(b)
end

-- Мирный житель: бегство, подбор оружия, тайники, блуждание
function AI.ThinkInnocent(b)
    local bot = b.ply
    local now = CurTime()

    if b.knifeSeen and math.random() < 0.7 then
        b.flee = now + 6
        b.fleeFrom = b.knifeSeen:GetPos()
    elseif b.bodySeen and now > b.bodyReact then
        b.bodyReact = now + 10
        b.flee = now + 5
        b.fleeFrom = b.bodySeen:GetPos()
    end

    if now < b.flee and b.fleeFrom then
        AI.Flee(b, b.fleeFrom)
        return
    end

    if bot.GrimRole == ROLE.INNOCENT and b.wantsGun and not bot:HasWeapon("weapon_grim_magnum") then
        local gun = b.gun
        if not (IsValid(gun) and not IsValid(gun:GetOwner())) then
            gun = nil
            local bestD = 1500 * 1500
            for _, w in ipairs(ents.FindByClass("weapon_grim_magnum")) do
                local d = w:GetPos():DistToSqr(bot:GetPos())
                if not IsValid(w:GetOwner()) and d < bestD then gun, bestD = w, d end
            end
        end
        b.gun = gun
        if gun then
            b.moveGoal = AI.FollowTo(b, gun:GetPos())
            return
        end
    end

    local loot = b.loot
    if not AvailableLoot(loot) then
        loot = nil
        local bestD = 2500 * 2500
        for _, e in ipairs(ents.FindByClass("grim_loot")) do
            local d = e:GetPos():DistToSqr(bot:GetPos())
            if AvailableLoot(e) and d < bestD then loot, bestD = e, d end
        end
    end
    b.loot = loot

    if loot and math.random() < 0.85 then
        local lp = loot:WorldSpaceCenter()
        if (loot:GetPos() - bot:GetPos()):Length2D() < 90 then
            b.aimGoal = (lp - bot:EyePos()):Angle()
            b.use = true
        else
            b.moveGoal = AI.FollowTo(b, loot:GetPos())
        end
        return
    end

    AI.Wander(b)
end

hook.Add("StartCommand", "GRIM_BotControl", function(ply, cmd)
    if ply.GrimBrain then
        AI.Control(ply, cmd)
    end
end)
