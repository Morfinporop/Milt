-- GRIMOHOD: тайник. E — получить очки. После сбора уходит на перезарядку (см. GRIM.Loot).

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Тайник"
ENT.Author = "GRIMOHOD"
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:Initialize()
    if SERVER then
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end
    end
end

function ENT:Use(activator)
    if SERVER and IsValid(activator) and activator:IsPlayer() and GRIM.Loot then
        GRIM.Loot.Collect(self, activator)
    end
end
