-- GRIMOHOD: серверная инициализация

AddCSLuaFile("shared.lua")
AddCSLuaFile("sh_util.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_theme.lua")
AddCSLuaFile("cl_icons.lua")
AddCSLuaFile("cl_hud.lua")
AddCSLuaFile("cl_fx.lua")
AddCSLuaFile("cl_scoreboard.lua")
AddCSLuaFile("cl_roundend.lua")
AddCSLuaFile("cl_qmenu.lua")
AddCSLuaFile("cl_spawns.lua")

include("shared.lua")
include("sh_util.lua")
include("sv_net.lua")
include("sv_spawns.lua")
include("sv_loot.lua")
include("sv_nav.lua")
include("sv_roles.lua")
include("sv_player.lua")
include("sv_rounds.lua")
include("sv_ai.lua")
include("sv_bots.lua")

for _, name in ipairs(GRIM.NetNames) do
    util.AddNetworkString(name)
end

hook.Add("Initialize", "GRIM_Initialize", function()
    GRIM.Spawns.Load()
    GRIM.Loot.Load()
    GRIM.Round.Init()
end)

hook.Add("InitPostEntity", "GRIM_InitPostEntity", function()
    -- Навигация строится после того, как карта полностью загружена
    timer.Simple(1, function()
        GRIM.Nav.Build()
    end)
end)
