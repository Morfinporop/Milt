-- GRIMOHOD: распределение ролей. Убийца выбирается взвешенно: тот, кто давно не был убийцей, шанс выше.

GRIM.Role = GRIM.Role or {}
local ROLE = GRIM.ROLE

-- Игроки в команде участников (включая ботов). aliveOnly — только живые.
function GRIM.GetPlayers(aliveOnly)
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Team() == GRIM.TEAM_PLAYER and (not aliveOnly or ply:Alive()) then
            out[#out + 1] = ply
        end
    end
    return out
end

-- Назначает роли всем участникам. Возвращает убийцу и детектива (или nil).
function GRIM.Role.Assign()
    local players = GRIM.GetPlayers(false)
    for _, ply in ipairs(players) do
        ply.GrimRole = ROLE.INNOCENT
        ply.GrimKnown = nil
        ply.GrimKills = 0
        ply:SetNWInt("grim_shown", 0)
    end
    if #players < 2 then return nil, nil end

    local murderer = GRIM.Util.WeightedPick(players, function(p)
        return 1 + (p.GrimStreak or 0) * 1.5
    end)

    for _, p in ipairs(players) do
        p.GrimStreak = (p == murderer) and 0 or ((p.GrimStreak or 0) + 1)
    end
    murderer.GrimRole = ROLE.MURDERER

    local detective
    if #players >= GRIM.CV.DetectiveMin:GetInt() then
        local others = {}
        for _, p in ipairs(players) do
            if p ~= murderer then others[#others + 1] = p end
        end
        detective = GRIM.Util.WeightedPick(others, function() return 1 end)
        if IsValid(detective) then detective.GrimRole = ROLE.DETECTIVE end
    end

    return murderer, detective
end
