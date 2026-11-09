-- GRIMOHOD: мозг ботов. Бот играет как человек, а не как «нуб у стены»:
--   * видит только то, что в поле зрения (конус ~150°) и не закрыто геометрией;
--   * помнит, где в последний раз видел игрока, и идёт туда, а не телепортируется к цели;
--   * слышит выстрелы и убийства в радиусе, с задержкой реакции;
--   * ходит по навигации, щупами обходит стены, прыгает через низкие преграды,
--     не спрыгивает с обрыва без причины и выбирается из застревания;
--   * роли: убийца подкрадывается и ждёт, пока уйдут свидетели; детектив стреляет
--     с задержкой реакции; мирный прячется от ножа и тел и собирает тайники.

GRIM.AI = GRIM.AI or {}
local AI = GRIM.AI
local ROLE = GRIM.ROLE
local ST = GRIM.STATE

local VIEW_DIST = 2400
local FOV_COS = math.cos(math.rad(75))   -- полуугол обзора 75°
local CLOSE_SENSE = 140                  -- ближе этого бот чувствует цель без взгляда
local MEM_TIME = 8                       -- сек помним игрока, потерянного из виду
local KNIFE_MEM = 6
local HEAR_TIME = 4
local TURN_MOVE, TURN_AIM, TURN_FAST = 540, 360, 900   -- град/с
local MOVE = 10000
local TICK_MIN, TICK_RAND = 0.12, 0.06
local STEP_PROBE = 52                    -- длина щупа вперёд
local TRY = {0, 35, -35, 70, -70, 110, -110}
local KNEE_MAXS = Vector(14, 14, 20)
local HEAD_MAXS = Vector(14, 14, 28)
local HULL_MINS = Vector(-14, -14, 0)

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

local function Clear(a, b, filter)
    local tr = util.TraceLine({start = a, endpos = b, filter = filter, mask = MASK_SOLID_BRUSHONLY})
    return tr.Fraction > 0.97 and not tr.StartSolid
end

-- Поле зрения: цель в конусе перед глазами (или очень близко)
local function InFOV(ply, pos)
    local eye = ply:EyePos()
    local d = pos - eye
    local len = d:Length()
    if len < CLOSE_SENSE then return true end
    return ply:GetAimVector():Dot(d / len) >= FOV_COS
end

-- Видит ли игрок другого игрока: поле зрения и прямая линия без стен и других тел
local function Sees(ply, ent)
    if not IsValid(ent) or not ent:Alive() then return false end
    local eye = ply:EyePos()
    local tp = ent:WorldSpaceCenter()
    if eye:DistToSqr(tp) > VIEW_DIST * VIEW_DIST then return false end
    if not InFOV(ply, tp) then return false end
    local tr = util.TraceLine({start = eye, endpos = tp, filter = ply, mask = MASK_SHOT})
    return tr.Entity == ent
end

-- Видит ли игрок точку в мире (для свидетелей и тел)
local function SeesPos(ply, pos)
    local eye = ply:EyePos()
    if eye:DistToSqr(pos) > VIEW_DIST * VIEW_DIST then return false end
    if not InFOV(ply, pos) then return false end
    return Clear(eye, pos, ply)
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

-- Сколько невиновных могут увидеть жертву рядом (кроме самого бота)
local function Witnesses(b, victim)
    local n = 0
    local vp = victim:WorldSpaceCenter()
    local vpos = victim:GetPos()
    for _, p in ipairs(GRIM.GetPlayers(true)) do
        if p ~= b.ply and p ~= victim and p.GrimRole ~= ROLE.MURDERER
            and p:GetPos():DistToSqr(vpos) < 900 * 900 and SeesPos(p, vp) then
            n = n + 1
        end
    end
    return n
end

-- Щуп препятствия: короткий хулл-трейс вперёд на заданной высоте
local function Probe(bot, dir, dist, lift, maxs)
    local p = bot:GetPos() + Vector(0, 0, lift)
    return util.TraceHull({
        start = p,
        endpos = p + dir * dist,
        mins = HULL_MINS,
        maxs = maxs,
        mask = MASK_PLAYERSOLID_BRUSHONLY,
        filter = bot,
    })
end

-- Есть ли под точкой впереди пол (нет — значит обрыв)
local function GroundAhead(bot, dir, dist)
    local p = bot:GetPos() + dir * dist
    local tr = util.TraceLine({
        start = p + Vector(0, 0, 30),
        endpos = p - Vector(0, 0, 120),
        mask = MASK_PLAYERSOLID_BRUSHONLY,
        filter = bot,
    })
    return tr.Hit and not tr.StartSolid
end

-- Выбор направления движения у стены: идём ближе к цели, если путь свободен.
-- Низкое препятствие прямо впереди — прыжок. Возвращает направление или nil.
local function Steer(b, flat, drop)
    local bot = b.ply
    local yaw = flat:Angle().y
    for _, off in ipairs(TRY) do
        local dir = Angle(0, yaw + off, 0):Forward()
        local low = Probe(bot, dir, STEP_PROBE, 12, KNEE_MAXS)
        if not low.Hit then
            if drop or GroundAhead(bot, dir, STEP_PROBE) then return dir end
        elseif off == 0 then
            local high = Probe(bot, dir, STEP_PROBE, 44, HEAD_MAXS)
            if not high.Hit then
                b.jump = true
                return dir
            end
        end
    end
    return nil
end

-- Точка укрытия: далеко от угрозы и, по возможности, вне её линии видимости
local function HideSpot(b, threat)
    local pos = b.ply:GetPos()
    local eye = threat + Vector(0, 0, 50)
    local best, bestScore = nil, -math.huge
    for _ = 1, 12 do
        local c = GRIM.Nav.RandomPos()
        if c then
            local d = c:Distance(threat)
            if d > 250 then
                local hidden = not Clear(eye, c + Vector(0, 0, 40))
                local score = math.min(d, 1500) - pos:Distance(c) * 0.2 + (hidden and 800 or 0)
                if score > bestScore then best, bestScore = c, score end
            end
        end
    end
    return best or GRIM.Spawns.Random()
end

-- Шум (выстрел, убийство): бот в радиусе услышит, даже без взгляда
function AI.Noise(pos, radius)
    local r2 = radius * radius
    local now = CurTime()
    for _, p in ipairs(player.GetAll()) do
        local b = IsValid(p) and p.GrimBrain
        if b and p:Alive() and p:GetPos():DistToSqr(pos) < r2 then
            b.heard = {pos = pos, t = now}
        end
    end
end

-- Создание состояния мозга
function AI.Attach(bot)
    bot.GrimBrain = {
        ply = bot,
        view = bot:EyeAngles(),
        nextTick = 0,
        aimGoal = nil,
        aimNoise = Angle(0, 0, 0),
        fastAim = false,
        moveDir = nil,
        jump = false,
        nextJump = 0,
        attack = false,
        attackRate = 0.6,
        nextAttack = 0,
        use = false,
        nextUse = 0,
        sneak = false,
        path = nil,
        pathI = 1,
        pathGoal = nil,
        pathExpire = 0,
        stuckPos = nil,
        stuckAt = 0,
        stuckCount = 0,
        sidestepUntil = 0,
        sidestepDir = nil,
        round = -1,
        mem = {},
        heard = nil,
        knifeSeen = nil,
        bodySeen = nil,
        threatAt = nil,
        flee = 0,
        fleeFrom = nil,
        fleeGoal = nil,
        fleeAt = 0,
        bodyReact = 0,
        wander = nil,
        wanderAt = 0,
        pauseUntil = 0,
        lookAt = 0,
        lookYaw = 0,
        loot = nil,
        gun = nil,
        wantsGun = false,
        target = nil,
        targetAt = 0,
        holdUntil = 0,
        reactAt = nil,
        idleAt = 0,
        idleYaw = 0,
    }
end

-- Сброс решений при начале нового раунда
local function ResetRound(b)
    if b.round == GRIM.Round.Number then return end
    b.round = GRIM.Round.Number
    b.mem = {}
    b.heard = nil
    b.target, b.loot, b.gun, b.wander = nil, nil, nil, nil
    b.fleeGoal, b.fleeFrom, b.path = nil, nil, nil
    b.flee = 0
    b.threatAt = nil
    b.reactAt = nil
    b.holdUntil = 0
    b.wantsGun = math.random() < 0.5
end

-- Управление командой (вызывается на каждый usercmd)
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

    -- Взгляд: сначала цель прицеливания, иначе направление движения
    local goal
    local speed = TURN_MOVE
    if b.aimGoal then
        goal = b.aimGoal + b.aimNoise
        speed = b.fastAim and TURN_FAST or TURN_AIM
    elseif b.moveDir then
        goal = Angle(0, b.moveDir:Angle().y, 0)
    else
        goal = b.view
    end
    b.view = ApproachAng(b.view, goal, speed * dt)
    cmd:SetViewAngles(b.view)
    bot:SetEyeAngles(b.view)

    -- Движение: вперёд только когда смотрим примерно туда, иначе сначала поворачиваемся
    local fwd, side = 0, 0
    if b.moveDir then
        local rel = math.rad(math.NormalizeAngle(b.moveDir:Angle().y - b.view.y))
        if math.abs(rel) < math.rad(55) then
            fwd = math.cos(rel) * MOVE
            side = -math.sin(rel) * MOVE
        end
    end
    cmd:SetForwardMove(fwd)
    cmd:SetSideMove(side)

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
    if b.jump and now >= b.nextJump and bot:OnGround() then
        buttons = bit.bor(buttons, IN_JUMP)
        b.nextJump = now + 0.8
        b.jump = false
    end
    if b.sneak then
        buttons = bit.bor(buttons, IN_WALK)
    end
    cmd:SetButtons(buttons)
end

-- Один цикл решений (~8 раз в секунду)
function AI.Think(b)
    local bot = b.ply
    b.aimGoal = nil
    b.fastAim = false
    b.moveDir = nil
    b.attack, b.use, b.sneak, b.jump = false, false, false, false
    b.aimNoise = Angle(math.Rand(-1, 1), math.Rand(-1, 1), 0)

    if not bot:Alive() then return end
    ResetRound(b)

    local state = GRIM.GetState()
    if state == ST.PREP then
        AI.Look(b)
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

    -- Принудительный обход после застревания
    if CurTime() < b.sidestepUntil and b.sidestepDir then
        b.moveDir = b.sidestepDir
        b.jump = true
    end

    AI.CheckStuck(b)
end

-- Восприятие: кто виден, что помнится, какие тела рядом
function AI.Perceive(b)
    local bot = b.ply
    local now = CurTime()
    local eye = bot:GetPos()
    b.knifeSeen, b.bodySeen = nil, nil

    local bestKnife = math.huge
    for _, other in ipairs(GRIM.GetPlayers(true)) do
        if other ~= bot then
            local idx = other:EntIndex()
            if Sees(bot, other) then
                local m = b.mem[idx] or {}
                b.mem[idx] = m
                m.ply = other
                m.pos = other:GetPos()
                m.t = now
                m.knife = HoldsKnife(other)
                local d = other:GetPos():DistToSqr(eye)
                if m.knife and d < bestKnife then
                    b.knifeSeen = other
                    bestKnife = d
                end
            end
        end
    end
    -- Забываем очень старые записи и отключившихся
    for idx, m in pairs(b.mem) do
        if not IsValid(m.ply) or now - m.t > 30 then b.mem[idx] = nil end
    end

    for _, rag in ipairs(GRIM.Bodies) do
        if IsValid(rag) and rag.GrimBody and not rag.GrimBody.inspected[bot:EntIndex()] then
            if rag:GetPos():DistToSqr(eye) < 700 * 700 and SeesPos(bot, rag:WorldSpaceCenter()) then
                b.bodySeen = rag
                break
            end
        end
    end
end

-- Недавно помнимая позиция игрока с ножом (даже если сейчас не виден)
local function RecentKnife(b)
    local now = CurTime()
    local best, bestD = nil, 1200 * 1200
    local eye = b.ply:GetPos()
    for _, m in pairs(b.mem) do
        if m.knife and IsValid(m.ply) and m.ply:Alive() and now - m.t < KNIFE_MEM then
            local d = m.pos:DistToSqr(eye)
            if d < bestD then best, bestD = m.pos, d end
        end
    end
    return best
end

-- Путь до цели: пройденные узлы отбрасываются, берётся упреждающий узел
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
    while b.pathI < #path and (path[b.pathI] - pos):Length2D() < 60 do
        b.pathI = b.pathI + 1
    end
    local i = b.pathI
    while i < #path and (path[i] - pos):Length2D() < 160 do
        i = i + 1
    end
    return path[i] or goal
end

-- Движение к цели: путь + обход препятствий
function AI.Go(b, goal, opts)
    local bot = b.ply
    local pos = bot:GetPos()
    local node = AI.FollowTo(b, goal)
    local flat = Vector(node.x - pos.x, node.y - pos.y, 0)
    if flat:LengthSqr() < 36 then return end

    local horiz = flat:Length()
    flat:Normalize()
    local drop = pos.z - node.z > 60
    local dir = Steer(b, flat, drop)
    if dir then
        b.moveDir = dir
        -- Узел выше — прыгаем, когда подошли к подъёму
        if node.z - pos.z > 28 and horiz < 120 then b.jump = true end
    else
        -- Впереди стена: отходим назад и пробуем другой путь
        b.moveDir = -flat
        b.path = nil
    end
    b.sneak = (opts and opts.sneak) or false
end

-- Осмотреться на месте (живой бот не стоит и не смотрит в одну точку)
function AI.Look(b)
    local now = CurTime()
    if now >= b.lookAt then
        b.lookAt = now + math.Rand(0.9, 1.8)
        b.lookYaw = b.view.y + math.Rand(-80, 80)
    end
    b.aimGoal = Angle(0, b.lookYaw, 0)
end

-- Детектор застревания: если не продвигаемся — прыжок, затем сброс целей и боковой уход
function AI.CheckStuck(b)
    local bot = b.ply
    local now = CurTime()
    if not b.moveDir then
        b.stuckPos, b.stuckAt, b.stuckCount = bot:GetPos(), now, 0
        return
    end
    if now - b.stuckAt < 1.2 then return end

    local pos = bot:GetPos()
    if b.stuckPos and pos:Distance(b.stuckPos) < 35 then
        b.stuckCount = b.stuckCount + 1
        b.jump = true
        b.path = nil
        if b.stuckCount >= 3 then
            Dbg(b, "застрял, меняю цель")
            b.wander, b.loot, b.fleeGoal, b.gun = nil, nil, nil, nil
            b.sidestepDir = Angle(0, math.Rand(-180, 180), 0):Forward()
            b.sidestepUntil = now + 1.2
            b.stuckCount = 0
        end
    else
        b.stuckCount = 0
    end
    b.stuckPos, b.stuckAt = pos, now
end

-- Блуждание: до случайной точки, на месте — осмотр по сторонам
function AI.Wander(b, sneak)
    local now = CurTime()
    local pos = b.ply:GetPos()
    if b.wander and (b.wander - pos):Length2D() < 80 then
        b.wander = nil
        b.pauseUntil = now + math.Rand(1.5, 4)
    end
    if now < b.pauseUntil then
        AI.Look(b)
        return
    end
    if not b.wander or now > b.wanderAt then
        b.wander = GRIM.Nav.RandomPos()
        b.wanderAt = now + math.Rand(12, 20)
    end
    AI.Go(b, b.wander, {sneak = sneak})
end

function AI.Flee(b, threat)
    local now = CurTime()
    local pos = b.ply:GetPos()
    if not b.fleeGoal or now > b.fleeAt or (b.fleeGoal - pos):Length2D() < 100 then
        b.fleeGoal = HideSpot(b, threat)
        b.fleeAt = now + 6
    end
    AI.Go(b, b.fleeGoal)
end

-- Убийца: выбирает жертву без свидетелей, подкрадывается, ждёт, пока уйдут свидетели
local function PickVictim(b)
    local best, bestScore = nil, math.huge
    for _, p in ipairs(GRIM.GetPlayers(true)) do
        if p ~= b.ply and IsVictim(p) then
            local dist = (p:GetPos() - b.ply:GetPos()):Length2D()
            local score = (dist + Witnesses(b, p) * 1500) * math.Rand(0.85, 1.15)
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

    -- Пережидаем рядом со свидетелями: стоим тихо, не двигаемся
    if now < b.holdUntil then
        b.sneak = true
        return
    end

    if not IsVictim(b.target) or now > b.targetAt then
        b.target = PickVictim(b)
        b.targetAt = now + 25
    end

    local t = b.target
    if not IsValid(t) then
        AI.Wander(b, true)
        return
    end

    local tp = t:GetPos()
    local pos = bot:GetPos()
    local dist = (tp - pos):Length2D()
    local dz = math.abs(tp.z - pos.z)

    -- Свидетели у жертвы — уходим в ожидание, потом выберем заново
    if dist > 150 and Witnesses(b, t) > 0 then
        b.holdUntil = now + math.Rand(2.5, 4.5)
        b.target = nil
        b.sneak = true
        return
    end

    if dist < 75 and dz < 70 then
        b.aimGoal = (t:WorldSpaceCenter() - bot:EyePos()):Angle()
        b.fastAim = true
        b.attackRate = 0.7
        b.attack = AngleDiff(b.view, b.aimGoal) < 25
        return
    end

    if Sees(bot, t) then
        AI.Go(b, tp, {sneak = dist < 600})
        return
    end

    -- Цель вне поля зрения: идём к последней известной точке
    local m = b.mem[t:EntIndex()]
    if m and now - m.t < MEM_TIME then
        AI.Go(b, m.pos, {sneak = true})
    else
        b.target = nil
        AI.Wander(b, true)
    end
end

-- Детектив: сначала стреляет в известного убийцу (с задержкой реакции), потом осматривает тела
function AI.ThinkDetective(b)
    local bot = b.ply
    local now = CurTime()
    local m = bot.GrimKnown

    if IsValid(m) and m:Alive() and m.GrimRole == ROLE.MURDERER then
        local mem = b.mem[m:EntIndex()]
        if Sees(bot, m) then
            b.aimGoal = (m:WorldSpaceCenter() - bot:EyePos()):Angle()
            b.fastAim = true
            b.reactAt = b.reactAt or (now + 0.5)
            local wep = bot:GetWeapon("weapon_grim_magnum")
            if IsValid(wep) then
                if bot:GetActiveWeapon() ~= wep then bot:SelectWeapon("weapon_grim_magnum") end
                local armed = wep:Clip1() > 0
                if now >= b.reactAt and armed and AngleDiff(b.view, b.aimGoal) < 6 then
                    b.attackRate = GRIM.Config.MagnumDelay + 0.15
                    b.attack = true
                end
            end
            if (m:GetPos() - bot:GetPos()):Length2D() > 600 then
                AI.Go(b, m:GetPos())
            end
            return
        end
        b.reactAt = nil
        if mem and now - mem.t < MEM_TIME then
            AI.Go(b, mem.pos)
            return
        end
    end
    b.reactAt = nil

    local body, bestD = nil, 3000 * 3000
    for _, rag in ipairs(GRIM.Bodies) do
        if IsValid(rag) and rag.GrimBody and not rag.GrimBody.inspected[bot:EntIndex()] then
            local d = rag:GetPos():DistToSqr(bot:GetPos())
            if d < bestD then body, bestD = rag, d end
        end
    end
    if body then
        if (body:GetPos() - bot:GetPos()):Length2D() < 90 then
            b.aimGoal = (body:WorldSpaceCenter() - bot:EyePos()):Angle()
            b.use = true
        else
            AI.Go(b, body:GetPos())
        end
        return
    end

    AI.ThinkInnocent(b)
end

-- Мирный житель: бегство от ножа и тел, подбор магнума, тайники, блуждание
function AI.ThinkInnocent(b)
    local bot = b.ply
    local now = CurTime()

    local danger = b.knifeSeen and b.knifeSeen:GetPos() or RecentKnife(b)
    if danger then
        b.threatAt = b.threatAt or (now + math.Rand(0.3, 0.7))
        if now >= b.threatAt then
            b.flee = now + 7
            b.fleeFrom = danger
        end
    else
        b.threatAt = nil
    end

    if b.heard and now - b.heard.t < HEAR_TIME and b.heard.pos:DistToSqr(bot:GetPos()) < 900 * 900 then
        b.flee = math.max(b.flee, now + 4)
        b.fleeFrom = b.heard.pos
        b.heard = nil
    end

    if b.bodySeen and now > b.bodyReact then
        b.bodyReact = now + 10
        b.flee = now + 5
        b.fleeFrom = b.bodySeen:GetPos()
    end

    if now < b.flee and b.fleeFrom then
        AI.Flee(b, b.fleeFrom)
        return
    end

    -- Магнум: идём за ним, если решили вооружиться
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
            if (gun:GetPos() - bot:GetPos()):Length2D() < 90 then
                b.aimGoal = (gun:WorldSpaceCenter() - bot:EyePos()):Angle()
                b.use = true
            else
                AI.Go(b, gun:GetPos())
            end
            return
        end
    end

    -- Тайники
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
        if (loot:GetPos() - bot:GetPos()):Length2D() < 90 then
            b.aimGoal = (loot:WorldSpaceCenter() - bot:EyePos()):Angle()
            b.use = true
        else
            AI.Go(b, loot:GetPos())
        end
        return
    end

    AI.Wander(b, false)
end

hook.Add("StartCommand", "GRIM_BotControl", function(ply, cmd)
    if ply.GrimBrain then
        AI.Control(ply, cmd)
    end
end)
