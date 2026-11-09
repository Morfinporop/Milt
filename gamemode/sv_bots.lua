-- GRIMOHOD: менеджер ботов. Поддерживает количество из grimohod_bots.

GRIM.Bots = GRIM.Bots or {}
local BT = GRIM.Bots

local NAMES = {
    "Артём", "Миша", "Лёха", "Соня", "Ника", "Глеб", "Лиза", "Ваня",
    "Саша", "Тимур", "Ксюша", "Даня", "Марк", "Егор", "Вика", "Рома",
}

local function UniqueName()
    local used = {}
    for _, p in ipairs(player.GetAll()) do used[p:Nick()] = true end

    local base = NAMES[math.random(#NAMES)]
    local name, n = base, 1
    while used[name] do
        n = n + 1
        name = base .. " " .. n
    end
    return name
end

function BT.Create()
    local bot = player.CreateNextBot(UniqueName())
    if not IsValid(bot) then
        ErrorNoHalt("[GRIMOHOD] Не удалось создать бота\n")
        return false
    end
    bot.GrimIsBot = true
    GRIM.AI.Attach(bot)
    return true
end

function BT.Bots()
    local out = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p.GrimIsBot then out[#out + 1] = p end
    end
    return out
end

function BT.Sync()
    local want = math.Clamp(GRIM.CV.Bots:GetInt(), 0, GRIM.Config.MaxBots)
    local bots = BT.Bots()
    if #bots < want then
        BT.Create()
    elseif #bots > want then
        bots[#bots]:Kick("GRIMOHOD: бот удалён")
    end
end

function BT.KickAll()
    for _, b in ipairs(BT.Bots()) do
        b:Kick("GRIMOHOD: бот удалён")
    end
end

timer.Create("grimohod_bots_sync", 1.5, 0, BT.Sync)

concommand.Add("grimohod_bots_clear", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    BT.KickAll()
end)
