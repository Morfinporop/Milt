-- GRIMOHOD: базовое оружие. Атаки разрешены только во время раунда.

if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_base"
SWEP.Category = "GRIMOHOD"
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.UseHands = true
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false
SWEP.Weight = 5
SWEP.Slot = 0
SWEP.SlotPos = 1

SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:CanAttack()
    local owner = self:GetOwner()
    return IsValid(owner) and owner:Alive() and GRIM.IsActive()
end

function SWEP:SecondaryAttack()
end

-- Оружие не дропается при смене и не даёт стандартного HUD-сообщения
function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_DRAW)
    return true
end
