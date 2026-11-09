-- GRIMOHOD: навигация для ботов.
-- Если на карте есть navmesh — используем его. Иначе строим граф проходимости
-- из точек спавна, тайников и сетки выборок по полу (с проверкой LOS).

GRIM.Nav = GRIM.Nav or {}
local NAV = GRIM.Nav
NAV.Mode = "none"
NAV.Ready = false
NAV.Nodes = {}

local LINK_DIST = 700
local LINK_DZ = 96
local GRID_STEP = 320

local function Dbg(msg)
    if GRIM.CV.Debug:GetBool() then print("[GRIMOHOD/NAV] " .. msg) end
end

-- Проверка, что между двумя точками может пройти игрок
local function HullClear(a, b)
    local tr = util.TraceHull({
        start = a + Vector(0, 0, 18),
        endpos = b + Vector(0, 0, 18),
        mins = Vector(-14, -14, 0),
        maxs = Vector(14, 14, 40),
        mask = MASK_PLAYERSOLID_BRUSHONLY,
    })
    return not tr.StartSolid and tr.Fraction >= 0.999
end

local function GroundAt(x, y, zTop, zBot)
    local tr = util.TraceLine({
        start = Vector(x, y, zTop),
        endpos = Vector(x, y, zBot),
        mask = MASK_PLAYERSOLID_BRUSHONLY,
    })
    if not tr.Hit or tr.StartSolid or tr.HitNormal.z < 0.7 then return nil end
    local p = tr.HitPos + Vector(0, 0, 4)
    -- нельзя ставить узел внутри геометрии
    if bit.band(util.PointContents(p + Vector(0, 0, 36)), CONTENTS_SOLID) ~= 0 then return nil end
    return p
end

local function AddNode(list, pos)
    for _, n in ipairs(list) do
        if n.pos:DistToSqr(pos) < 96 * 96 then return end
    end
    table.insert(list, {id = #list + 1, pos = pos, links = {}})
end

local function BuildGraph()
    local seeds = {}
    for _, p in ipairs(GRIM.Spawns.Points) do seeds[#seeds + 1] = p end
    for _, d in ipairs(GRIM.Loot.Data) do seeds[#seeds + 1] = d.pos end
    if #seeds == 0 then return end

    local mins, maxs = Vector(math.huge, math.huge, math.huge), Vector(-math.huge, -math.huge, -math.huge)
    for _, p in ipairs(seeds) do
        mins = Vector(math.min(mins.x, p.x), math.min(mins.y, p.y), math.min(mins.z, p.z))
        maxs = Vector(math.max(maxs.x, p.x), math.max(maxs.y, p.y), math.max(maxs.z, p.z))
    end

    local nodes = {}
    for _, p in ipairs(seeds) do AddNode(nodes, p) end

    for x = mins.x - 160, maxs.x + 160, GRID_STEP do
        for y = mins.y - 160, maxs.y + 160, GRID_STEP do
            local p = GroundAt(x, y, maxs.z + 160, mins.z - 320)
            if p then AddNode(nodes, p) end
        end
    end

    for i = 1, #nodes do
        local a = nodes[i]
        for j = i + 1, #nodes do
            local b = nodes[j]
            if math.abs(a.pos.z - b.pos.z) < LINK_DZ and a.pos:Distance(b.pos) < LINK_DIST and HullClear(a.pos, b.pos) then
                a.links[b.id] = true
                b.links[a.id] = true
            end
        end
    end

    NAV.Nodes = nodes
    Dbg("граф: " .. #nodes .. " узлов")
end

local areaCache = {}
local function WrapArea(area)
    local id = area:GetID()
    local n = areaCache[id]
    if not n then
        n = {area = area, id = id, pos = area:GetCenter()}
        areaCache[id] = n
    end
    return n
end

local graphBackend = {
    nearest = function(pos)
        local best, bestD = nil, math.huge
        for _, n in ipairs(NAV.Nodes) do
            local d = n.pos:DistToSqr(pos)
            if d < bestD then best, bestD = n, d end
        end
        return best
    end,
    neighbors = function(n)
        local out = {}
        for id in pairs(n.links) do out[#out + 1] = NAV.Nodes[id] end
        return out
    end,
    pos = function(n) return n.pos end,
    key = function(n) return n.id end,
}

local meshBackend = {
    nearest = function(pos)
        local a = navmesh.GetNearestNavArea(pos)
        return a and WrapArea(a) or nil
    end,
    neighbors = function(n)
        local out = {}
        for _, a in ipairs(n.area:GetAdjacentAreas()) do out[#out + 1] = WrapArea(a) end
        return out
    end,
    pos = function(n) return n.pos end,
    key = function(n) return n.id end,
}

function NAV.Build()
    NAV.Ready = false
    NAV.Nodes = {}
    areaCache = {}

    local areas = navmesh and navmesh.GetAllNavAreas and navmesh.GetAllNavAreas() or {}
    if #areas > 16 then
        NAV.Mode = "navmesh"
        NAV.Ready = true
        Dbg("используется navmesh (" .. #areas .. " зон)")
        return
    end

    NAV.Mode = "graph"
    BuildGraph()
    NAV.Ready = #NAV.Nodes > 0
end

-- Путь от from до to: массив Vector или nil
function NAV.Find(from, to)
    if not NAV.Ready then return nil end
    local backend = NAV.Mode == "navmesh" and meshBackend or graphBackend
    return GRIM.Util.AStar(backend, from, to, 4000)
end

-- Случайная проходимая точка на карте
function NAV.RandomPos()
    if NAV.Mode == "navmesh" then
        local areas = navmesh.GetAllNavAreas()
        if #areas > 0 then return areas[math.random(#areas)]:GetCenter() end
    elseif #NAV.Nodes > 0 then
        return NAV.Nodes[math.random(#NAV.Nodes)].pos
    end
    return GRIM.Spawns.Random()
end
