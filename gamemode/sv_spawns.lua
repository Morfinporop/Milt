-- GRIMOHOD: точки появления игроков для карты

GRIM.Spawns = GRIM.Spawns or {}
local SP = GRIM.Spawns
SP.Points = {}

local function MapDataPath(name)
    return "grimohod/" .. game.GetMap() .. "/" .. name
end

-- Сначала ищем пользовательский файл в data/, затем встроенный в контенте геймода
function GRIM.ReadMapJSON(name)
    local path = MapDataPath(name)
    local raw = file.Read(path, "DATA")
    if not raw then
        raw = file.Read(GRIM.Folder .. "/content/data/" .. path, "GAME")
    end
    return raw and util.JSONToTable(raw) or nil
end

local function ToVector(s)
    local x, y, z = GRIM.Util.ParseTriple(s)
    if not x then return nil end
    return Vector(x, y, z)
end

function SP.Load()
    SP.Points = {}

    local tbl = GRIM.ReadMapJSON("spawns.txt")
    if istable(tbl) then
        for _, s in ipairs(GRIM.Util.OrderedValues(tbl)) do
            local v = ToVector(s)
            if v then table.insert(SP.Points, v) end
        end
    end

    if #SP.Points == 0 then
        for _, ent in ipairs(ents.FindByClass("info_player_*")) do
            table.insert(SP.Points, ent:GetPos())
        end
    end

    if #SP.Points == 0 then
        ErrorNoHalt("[GRIMOHOD] Нет точек спавна для карты " .. game.GetMap() .. "\n")
        table.insert(SP.Points, Vector(0, 0, 64))
    end
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

-- Добавить точку на текущей позиции (админ)
concommand.Add("grimohod_spawn_add", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local pos = IsValid(ply) and ply:GetPos() or Vector(0, 0, 0)
    table.insert(SP.Points, pos)
    print(string.format("[GRIMOHOD] Добавлена точка спавна #%d (%s)", #SP.Points, tostring(pos)))
end)

-- Сохранить текущие точки в data/grimohod/<карта>/spawns.txt (админ)
concommand.Add("grimohod_spawn_save", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local out = {}
    for i, v in ipairs(SP.Points) do
        out[tostring(i)] = string.format("[%.4f %.4f %.4f]", v.x, v.y, v.z)
    end
    local dir = "grimohod/" .. game.GetMap()
    file.CreateDir(dir)
    file.Write(dir .. "/spawns.txt", util.TableToJSON(out))
    print("[GRIMOHOD] Точки спавна сохранены: data/" .. dir .. "/spawns.txt")
end)
