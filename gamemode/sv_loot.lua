-- GRIMOHOD: тайники (loot). Игрок нажимает E — получает очки, тайник уходит на перезарядку.

GRIM.Loot = GRIM.Loot or {}
local LT = GRIM.Loot
LT.Data = {}
LT.Fallback = "models/props_junk/garbage_bag001a.mdl"

function LT.Load()
    LT.Data = {}
    local tbl = GRIM.ReadMapJSON("loot.txt")
    if not istable(tbl) then return end

    for _, d in ipairs(GRIM.Util.OrderedValues(tbl)) do
        local x, y, z = GRIM.Util.ParseTriple(d.pos)
        local p, yaw, r = GRIM.Util.ParseTriple(d.angle)
        if x and isstring(d.model) then
            table.insert(LT.Data, {
                pos = Vector(x, y, z),
                ang = Angle(p or 0, yaw or 0, r or 0),
                model = string.lower(d.model),
            })
        end
    end
end

-- Пересоздать все тайники (вызывается при подготовке раунда)
function LT.Spawn()
    for _, ent in ipairs(ents.FindByClass("grim_loot")) do
        ent:Remove()
    end

    for _, d in ipairs(LT.Data) do
        local model = util.IsValidModel(d.model) and d.model or LT.Fallback
        local ent = ents.Create("grim_loot")
        if IsValid(ent) then
            ent:SetModel(model)
            ent:SetPos(d.pos)
            ent:SetAngles(d.ang)
            ent:Spawn()
            ent.GrimTakenUntil = nil
        end
    end
end

function LT.Collect(ent, ply)
    if not GRIM.IsActive() then return end
    if not IsValid(ent) then return end
    if ent.GrimTakenUntil and CurTime() < ent.GrimTakenUntil then return end
    if not IsValid(ply) or not ply:Alive() then return end

    ent.GrimTakenUntil = CurTime() + GRIM.CV.LootRespawn:GetFloat()
    ent:SetNoDraw(true)
    ent:EmitSound("items/ammo_pickup.wav", 70, 110)

    GRIM.Player.AddPoints(ply, GRIM.Config.Points.Loot, nil)
    GRIM.Net.Coin(ply, ent:WorldSpaceCenter(), GRIM.Config.Points.Loot)
end

-- Возврат тайников после перезарядки
local function Think()
    local now = CurTime()
    for _, ent in ipairs(ents.FindByClass("grim_loot")) do
        if ent.GrimTakenUntil and now >= ent.GrimTakenUntil then
            ent.GrimTakenUntil = nil
            ent:SetNoDraw(false)
            ent:EmitSound("buttons/button9.wav", 60, 120)
        end
    end
end

timer.Create("grimohod_loot_think", 0.5, 0, Think)
