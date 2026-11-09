-- GRIMOHOD: общие константы, конфиг и ConVar'ы (сервер и клиент)

GM.Name = "GRIMOHOD"
GM.Author = "Morfinporop"
GM.Email = ""
GM.Website = ""

GRIM = GRIM or {}
GRIM.Version = "2.0.0"
GRIM.Folder = (GAMEMODE and GAMEMODE.Folder) or "gamemodes/grimohod"

GRIM.STATE = {WAIT = 0, PREP = 1, ACTIVE = 2, END = 3}
GRIM.ROLE = {NONE = 0, INNOCENT = 1, DETECTIVE = 2, MURDERER = 3}
GRIM.TEAM_SPEC = 1
GRIM.TEAM_PLAYER = 2

team.SetUp(GRIM.TEAM_SPEC, "Наблюдатели", Color(150, 150, 150))
team.SetUp(GRIM.TEAM_PLAYER, "Игроки", Color(241, 143, 38))

-- Палитра интерфейса (как в qmenu)
GRIM.Palette = {
    BG = Color(20, 20, 26, 155),
    OUTLINE = Color(255, 255, 255, 10),
    ORANGE = Color(241, 143, 38),
    GREEN = Color(88, 200, 84),
    RED = Color(232, 72, 72),
    BLUE = Color(74, 144, 235),
    WHITE = Color(255, 255, 255),
    GREY = Color(170, 170, 178),
    LETTER = Color(255, 255, 255, 60),
}

GRIM.RoleInfo = {
    [GRIM.ROLE.NONE] = {name = "Нет роли", icon = "person", color = GRIM.Palette.GREY, desc = ""},
    [GRIM.ROLE.INNOCENT] = {
        name = "Мирный житель",
        icon = "person",
        color = GRIM.Palette.GREEN,
        desc = "Выживи и найди убийцу. Собирай тайники, чтобы получать очки.",
    },
    [GRIM.ROLE.DETECTIVE] = {
        name = "Детектив",
        icon = "magnifier",
        color = GRIM.Palette.BLUE,
        desc = "У тебя есть магнум. Осмотри тело, чтобы узнать убийцу.",
    },
    [GRIM.ROLE.MURDERER] = {
        name = "Убийца",
        icon = "knife",
        color = GRIM.Palette.RED,
        desc = "Убей всех ножом. Стой неподвижно — и станешь почти невидимым.",
    },
}

-- Игровой баланс
GRIM.Config = {
    StealthAfter = 1.0,      -- секунд неподвижности до начала невидимости
    StealthAlpha = 40,       -- прозрачность убийцы в невидимости (0-255)
    KnifeDamage = 1000,
    KnifeRange = 72,
    KnifeDelay = 0.65,
    MagnumDamage = 200,
    MagnumDelay = 0.5,
    BodyLifetime = 90,
    MaxBots = 16,
    Points = {
        KillInnocent = 3,
        FindMurderer = 5,
        MistakeKill = -4,
        Survive = 2,
        MurdererWin = 5,
        Loot = 1,
    },
}

GRIM.NetNames = {
    "grim_role", "grim_banner", "grim_killfeed", "grim_hit", "grim_damage",
    "grim_roundend", "grim_coinpop", "grim_inspect", "grim_toast",
}

-- Серверные ConVar'ы
local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY)
GRIM.CV = {
    Bots = CreateConVar("grimohod_bots", "0", FLAGS, "Сколько ботов поддерживать на сервере (0-16)", 0, 16),
    MinPlayers = CreateConVar("grimohod_minplayers", "2", FLAGS, "Минимум игроков для старта раунда", 2, 16),
    PrepTime = CreateConVar("grimohod_preptime", "12", FLAGS, "Длительность подготовки (сек)", 3, 120),
    RoundTime = CreateConVar("grimohod_roundtime", "300", FLAGS, "Длительность раунда (сек)", 60, 1800),
    EndTime = CreateConVar("grimohod_endtime", "10", FLAGS, "Длительность экрана итогов (сек)", 3, 60),
    DetectiveMin = CreateConVar("grimohod_detective_min", "5", FLAGS, "Минимум игроков для появления детектива", 3, 32),
    LootRespawn = CreateConVar("grimohod_loot_respawn", "20", FLAGS, "Респавн тайника (сек)", 5, 300),
    Debug = CreateConVar("grimohod_debug", "0", FLAGS, "Отладочный вывод ботов и навигации", 0, 1),
}

function GRIM.IsActive()
    return GetGlobalInt("grim_state", GRIM.STATE.WAIT) == GRIM.STATE.ACTIVE
end

function GRIM.GetState()
    return GetGlobalInt("grim_state", GRIM.STATE.WAIT)
end
