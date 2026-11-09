-- GRIMOHOD: точки появления игроков. Хранятся в одном конфиге по имени карты:
--   garrysmod/data/grimohod/spawns.json  ->  { "cs_office": [ {x,y,z}, ... ], "<карта>": [...] }
-- Админ расставляет точки прямо в игре (grimohod_spawn_add), всё сохраняется автоматически.

GRIM.Spawns = GRIM.Spawns or {}
local SP = GRIM.Spawns
SP.Points = {}
SP.Fallback = false
SP.FILE = "grimohod/spawns.json"

local function ReadConfig()
    local raw = file.Read(SP.FILE, "DATA")
    local t = raw and util.JSONToTable(raw)
    return istable(t) and t or {}
end

local function WriteConfig(cfg)
    file.CreateDir("grimohod")
    file.Write(SP.FILE, util.TableToJSON(cfg, true))
end

local function ToVec(v)
    if isstring(v) then
        local x, y, z = GRIM.Util.ParseTriple(v)
        if x then return Vector(x, y, z) end
        return nil
    end
    if istable(v) then
        local x, y, z = tonumber(v.x or v[1]), tonumber(v.y or v[2]), tonumber(v.z or v[3])
        if x and y and z then return Vector(x, y, z) end
    end
    return nil
end

-- Точки текущей карты из конфига
local function LoadConfigPoints(out)
    local cfg = ReadConfig()
    for _, p in ipairs(cfg[game.GetMap()] or {}) do
        local v = ToVec(p)
        if v then out[#out + 1] = v end
    end
end

-- Старый встроенный файл геймода (для карт, где точки ещё не расставлены)
local function LoadContentPoints(out)
    local raw = file.Read(GRIM.Folder .. "/content/data/grimohod/" .. game.GetMap() .. "/spawns.txt", "GAME")
    local tbl = raw and util.JSONToTable(raw)
    if not istable(tbl) then return end
    for _, s in ipairs(GRIM.Util.OrderedValues(tbl)) do
        local v = ToVec(s)
        if v then out[#out + 1] = v end
    end
end

function SP.Load()
    SP.Points = {}
    SP.Fallback = false

    LoadConfigPoints(SP.Points)
    if #SP.Points == 0 then LoadContentPoints(SP.Points) end
    if #SP.Points == 0 then
        for _, ent in ipairs(ents.FindByClass("info_player_*")) do
            table.insert(SP.Points, ent:GetPos())
        end
    end
    if #SP.Points == 0 then
        ErrorNoHalt("[GRIMOHOD] Нет точек спавна для карты " .. game.GetMap() .. " — поставьте их командой grimohod_spawn_add\n")
        SP.Points = {Vector(0, 0, 64)}
        SP.Fallback = true
    end
end

-- Сохранить точки текущей карты в конфиг и разослать админам
function SP.Save()
    local cfg = ReadConfig()
    local out = {}
    for i, v in ipairs(SP.Points) do
        out[i] = {x = math.Round(v.x, 2), y = math.Round(v.y, 2), z = math.Round(v.z, 2)}
    end
    cfg[game.GetMap()] = out
    WriteConfig(cfg)
    SP.Broadcast()
end

function SP.Broadcast()
    local admins = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:IsAdmin() then admins[#admins + 1] = p end
    end
    if #admins > 0 then GRIM.Net.Spawns(admins, SP.Points) end
end

-- Точка спавна, максимально далёкая от живых игроков (среди случайных кандидатов)
function SP.Pick(ignore)
    local pts = SP.Points
    local alive = {}
    for _, ply in ipairs(player.GetAll()) do
        if ply ~= ignore and ply:Alive() then alive[#alive + 1] = ply:GetPos() end
    end

    local best, bestD = pts[math.random(#pts)], -1
    for _ = 1, 12 do
        local p = pts[math.random(#pts)]
        local d = math.huge
        for _, a in ipairs(alive) do
            d = math.min(d, p:Distance(a))
        end
        if d > bestD then best, bestD = p, d end
        if bestD > 900 then break end
    end
    return best
end

function SP.Random()
    return SP.Points[math.random(#SP.Points)]
end

-- ---------------------------------------------------------------------
-- Команды администратора (из консоли или в игре)
-- ---------------------------------------------------------------------
local function IsAdmin(ply)
    return not IsValid(ply) or ply:IsAdmin()
end

local function Say(ply, msg)
    if IsValid(ply) then
        ply:ChatPrint("[GRIMOHOD] " .. msg)
    else
        print("[GRIMOHOD] " .. msg)
    end
end

-- Если стояла заглушка — первая реальная точка заменяет её
local function ClearFallback()
    if SP.Fallback then
        SP.Points = {}
        SP.Fallback = false
    end
end

concommand.Add("grimohod_spawn_add", function(ply, _, args)
    if not IsAdmin(ply) then return end
    local pos = IsValid(ply) and ply:GetPos() or Vector(0, 0, 0)
    ClearFallback()
    table.insert(SP.Points, pos)
    SP.Save()
    Say(ply, string.format("точка #%d добавлена (карта %s, всего %d)", #SP.Points, game.GetMap(), #SP.Points))
end)

-- grimohod_spawn_remove [номер] — без номера удаляет ближайшую к вам точку
concommand.Add("grimohod_spawn_remove", function(ply, _, args)
    if not IsAdmin(ply) then return end
    local idx = tonumber(args[1])
    if not idx and IsValid(ply) then
        local best, bestD = nil, math.huge
        for i, v in ipairs(SP.Points) do
            local d = v:DistToSqr(ply:GetPos())
            if d < bestD then best, bestD = i, d end
        end
        idx = best
    end
    if not idx or not SP.Points[idx] then
        Say(ply, "нет такой точки. Смотрите номера командой grimohod_spawn_list")
        return
    end
    table.remove(SP.Points, idx)
    SP.Save()
    Say(ply, string.format("точка #%d удалена (осталось %d)", idx, #SP.Points))
end)

concommand.Add("grimohod_spawn_list", function(ply)
    if not IsAdmin(ply) then return end
    Say(ply, string.format("карта %s: %d точек%s", game.GetMap(), #SP.Points, SP.Fallback and " (заглушка — точек ещё нет)" or ""))
    for i, v in ipairs(SP.Points) do
        print(string.format("  #%d  %.1f %.1f %.1f", i, v.x, v.y, v.z))
    end
end)

concommand.Add("grimohod_spawn_clear", function(ply)
    if not IsAdmin(ply) then return end
    SP.Points = {}
    SP.Fallback = false
    local cfg = ReadConfig()
    cfg[game.GetMap()] = nil
    WriteConfig(cfg)
    SP.Load()
    SP.Broadcast()
    Say(ply, "точки карты " .. game.GetMap() .. " очищены, в конфиге ничего не осталось")
end)

-- Клиент-админ просит точки для отображения в мире
net.Receive("grim_spawns_req", function(_, ply)
    if IsValid(ply) and ply:IsAdmin() then
        GRIM.Net.Spawns({ply}, SP.Points)
    end
end)
