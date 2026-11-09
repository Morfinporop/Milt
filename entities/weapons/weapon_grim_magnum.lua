-- GRIMOHOD: магнум детектива. Один выстрел — один труп. Перезарядка из резерва.

if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_grim_base"
SWEP.PrintName = "Магнум"
SWEP.Author = "GRIMOHOD"
SWEP.Instructions = "ЛКМ — выстрел, R — перезарядка"
SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.HoldType = "revolver"

SWEP.ViewModel = "models/weapons/c_357.mdl"
SWEP.WorldModel = "models/weapons/w_357.mdl"

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Ammo = "357"
SWEP.Primary.Delay = GRIM.Config.MagnumDelay
SWEP.Primary.Damage = GRIM.Config.MagnumDamage

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    if not self:CanAttack() then return end
    local owner = self:GetOwner()

    if self:Clip1() <= 0 then
        self:EmitSound("Weapon_Pistol.Empty")
        self:SetNextPrimaryFire(CurTime() + 0.35)
        return
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:TakePrimaryAmmo(1)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)
    self:EmitSound("Weapon_357.Single", 85, 100)

    if CLIENT then return end

    owner:ViewPunch(Angle(-4, math.Rand(-1, 1), 0))
    GRIM.AI.Noise(owner:GetPos(), 1400)

    local shoot = owner:GetShootPos()
    local aim = owner:GetAimVector()

    -- Визуальный трассер (без урона: урон наносим сами, чтобы знать инфликтор)
    owner:FireBullets({
        Num = 1,
        Src = shoot,
        Dir = aim,
        Spread = Vector(0, 0, 0),
        Tracer = 1,
        Damage = 0,
        Force = 0,
    })

    local tr = util.TraceLine({
        start = shoot,
        endpos = shoot + aim * 8192,
        filter = owner,
        mask = MASK_SHOT,
    })

    local victim = tr.Entity
    if IsValid(victim) and victim:IsPlayer() and victim:Alive() and victim ~= owner then
        local dmg = DamageInfo()
        dmg:SetDamage(self.Primary.Damage)
        dmg:SetDamageType(DMG_BULLET)
        dmg:SetAttacker(owner)
        dmg:SetInflictor(self)
        dmg:SetDamagePosition(tr.HitPos)
        dmg:SetDamageForce(aim * 5000)
        victim:TakeDamageInfo(dmg)
    end
end

function SWEP:Reload()
    if not self:CanAttack() then return end
    if self:Clip1() >= self.Primary.ClipSize or self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0 then return end
    self:DefaultReload(ACT_VM_RELOAD)
    self:EmitSound("Weapon_357.Reload")
end
