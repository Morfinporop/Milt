-- GRIMOHOD: нож убийцы. Один удар — смерть невиновного.

if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_grim_base"
SWEP.PrintName = "Нож"
SWEP.Author = "GRIMOHOD"
SWEP.Instructions = "ЛКМ — удар ножом"
SWEP.Slot = 0
SWEP.SlotPos = 1
SWEP.HoldType = "knife"

local HAS_KNIFE_MODEL = file.Exists("models/weapons/c_knife_t.mdl", "GAME")
SWEP.ViewModel = HAS_KNIFE_MODEL and "models/weapons/c_knife_t.mdl" or "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = HAS_KNIFE_MODEL and "models/weapons/w_knife_t.mdl" or "models/weapons/w_crowbar.mdl"

SWEP.Primary.Delay = GRIM.Config.KnifeDelay
SWEP.Primary.Damage = GRIM.Config.KnifeDamage

local SWING_SOUNDS = {"weapons/knife/knife_slash1.wav", "weapons/knife/knife_slash2.wav"}
local HIT_SOUNDS = {"physics/flesh/flesh_impact_hard1.wav", "physics/flesh/flesh_impact_hard2.wav"}

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    if not self:CanAttack() then return end
    local owner = self:GetOwner()

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)
    self:EmitSound(SWING_SOUNDS[math.random(#SWING_SOUNDS)], 60, math.random(95, 105))

    if CLIENT then return end
    if owner.GrimRole ~= GRIM.ROLE.MURDERER then return end

    local shoot = owner:GetShootPos()
    local aim = owner:GetAimVector()
    local range = GRIM.Config.KnifeRange
    local tr = util.TraceHull({
        start = shoot,
        endpos = shoot + aim * range,
        filter = owner,
        mins = Vector(-10, -10, -10),
        maxs = Vector(10, 10, 10),
        mask = MASK_SHOT_HULL,
    })

    local victim = tr.Entity
    if not (IsValid(victim) and victim:IsPlayer() and victim:Alive() and victim ~= owner) then return end
    if victim.GrimRole == GRIM.ROLE.MURDERER then return end

    local dmg = DamageInfo()
    dmg:SetDamage(self.Primary.Damage)
    dmg:SetDamageType(DMG_SLASH)
    dmg:SetAttacker(owner)
    dmg:SetInflictor(self)
    dmg:SetDamagePosition(tr.HitPos)
    dmg:SetDamageForce(aim * 2000)
    victim:TakeDamageInfo(dmg)

    self:EmitSound(HIT_SOUNDS[math.random(#HIT_SOUNDS)], 75, 100)
end

function SWEP:Reload()
end
