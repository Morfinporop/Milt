-- GRIMOHOD: точки спавна в мире — видны только администраторам.
-- Оранжевый короб и номер над каждой точкой. Выключается ConVar grimohod_spawn_show.

local PAL = GRIM.Palette
local points = {}

GRIM.CV.ShowSpawns = CreateClientConVar("grimohod_spawn_show", "1", true, false, "Показывать точки спавна (только админам)")

net.Receive("grim_spawns", function()
    local n = net.ReadUInt(16)
    points = {}
    for i = 1, n do points[i] = net.ReadVector() end
end)

local function Request()
    local lp = LocalPlayer()
    if IsValid(lp) and lp:IsAdmin() then
        net.Start("grim_spawns_req")
        net.SendToServer()
    end
end

hook.Add("InitPostEntity", "GRIM_SpawnsRequest", function()
    timer.Simple(2, Request)
end)

local BOX_MINS, BOX_MAXS = Vector(-16, -16, 0), Vector(16, 16, 72)
local MAX_DIST_SQR = 4000 * 4000

hook.Add("PostDrawTranslucentRenderables", "GRIM_SpawnPoints", function(_, bSkybox)
    if bSkybox then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:IsAdmin() or not GRIM.CV.ShowSpawns:GetBool() then return end

    local eye = EyePos()
    local yaw = EyeAngles().y
    for i, v in ipairs(points) do
        if v:DistToSqr(eye) < MAX_DIST_SQR then
            render.DrawWireframeBox(v, Angle(0, 0, 0), BOX_MINS, BOX_MAXS, PAL.ORANGE, true)
            cam.Start3D2D(v + Vector(0, 0, 84), Angle(0, yaw - 90, 90), 0.25)
                draw.SimpleText(tostring(i), "GRIM_Row", 0, 0, PAL.ORANGE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        end
    end
end)
