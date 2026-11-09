-- GRIMOHOD: таблица игроков в стиле qmenu. Роли видны только после раунда.

local UI = GRIM.UI
local PAL = GRIM.Palette
local S = UI.S
local ROLE = GRIM.ROLE
local ST = GRIM.STATE

local shown = false

hook.Add("ScoreboardShow", "GRIM_ScoreboardShow", function()
    shown = true
    return true
end)

hook.Add("ScoreboardHide", "GRIM_ScoreboardHide", function()
    shown = false
    return true
end)

local function Sorted()
    local list = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then list[#list + 1] = p end
    end
    table.sort(list, function(a, b)
        local pa, pb = a:GetNWInt("grim_points", 0), b:GetNWInt("grim_points", 0)
        if pa ~= pb then return pa > pb end
        return a:Nick() < b:Nick()
    end)
    return list
end

local STATE_TEXT = {
    [ST.WAIT] = "ОЖИДАНИЕ",
    [ST.PREP] = "ПОДГОТОВКА",
    [ST.ACTIVE] = "В ИГРЕ",
    [ST.END] = "ИТОГИ",
}

local function DrawScoreboard()
    local k = UI.Anim("grim_score", shown and 1 or 0, 6)
    if k <= 0.01 then return end
    local e = UI.Ease.OutCubic(k)

    local list = Sorted()
    local rowH = S(34)
    local rows = math.min(#list, 16)
    local w = S(920)
    local h = S(150) + rows * rowH + S(54)
    local x = ScrW() * 0.5 - w * 0.5
    local y = ScrH() * 0.5 - h * 0.5 + (1 - e) * S(24)

    UI.Panel(x, y, w, h, UI.BG.a * k)
    UI.Accent(x, y, w, h, 0)

    -- Шапка
    UI.Text("GRIMOHOD", "GRIM_Title", x + S(28), y + S(22), UI.Fade(UI.ORANGE, k))
    local round = GetGlobalInt("grim_round", 0)
    local st = STATE_TEXT[GRIM.GetState()] or ""
    UI.Text("РАУНД " .. round .. "  ·  " .. st, "GRIM_Tab", x + S(28), y + S(72), UI.Fade(UI.WHITE, k))
    UI.Text(game.GetMap() .. "  ·  " .. #list .. " игроков", "GRIM_Small", x + w - S(28), y + S(78), UI.Fade(UI.GREY, k), TEXT_ALIGN_RIGHT)

    -- Заголовки колонок
    local cols = {
        {x = S(28), t = "ИГРОК", a = TEXT_ALIGN_LEFT},
        {x = S(470), t = "РОЛЬ", a = TEXT_ALIGN_LEFT},
        {x = S(640), t = "ОЧКИ", a = TEXT_ALIGN_RIGHT},
        {x = S(720), t = "УБИЙСТВА", a = TEXT_ALIGN_RIGHT},
        {x = S(800), t = "СМЕРТИ", a = TEXT_ALIGN_RIGHT},
        {x = S(892), t = "ПИНГ", a = TEXT_ALIGN_RIGHT},
    }
    local hy = y + S(116)
    UI.Rect(x + S(18), hy + S(20), w - S(36), 1, UI.Fade(UI.WHITE, 0.08 * k))
    for _, c in ipairs(cols) do
        UI.Text(c.t, "GRIM_Tiny", x + c.x, hy, UI.Fade(UI.GREY, k), c.a)
    end

    -- Строки
    local me = LocalPlayer()
    local ry = hy + S(30)
    for i = 1, rows do
        local p = list[i]
        local alive = p:Alive() and p:Team() == GRIM.TEAM_PLAYER
        local isMe = p == me

        if isMe then
            UI.Rect(x + S(14), ry, w - S(28), rowH - S(4), UI.Fade(UI.ORANGE, 0.14 * k))
        end

        UI.Rect(x + S(22), ry + rowH * 0.5 - S(4), S(8), S(8), alive and UI.Fade(PAL.GREEN, k) or UI.Fade(PAL.GREY, k * 0.6))
        UI.Text(UI.Fit(p:Nick(), "GRIM_Row", S(360)), "GRIM_Row", x + S(42), ry + rowH * 0.5, UI.Fade(isMe and UI.ORANGE or UI.WHITE, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local shownRole = p:GetNWInt("grim_shown", 0)
        if shownRole > 0 and GRIM.RoleInfo[shownRole] then
            local info = GRIM.RoleInfo[shownRole]
            UI.Icon(info.icon, x + S(484), ry + rowH * 0.5, S(18), UI.Fade(info.color, k))
            UI.Text(info.name, "GRIM_Small", x + S(500), ry + rowH * 0.5, UI.Fade(info.color, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        elseif p:Team() == GRIM.TEAM_SPEC then
            UI.Text("наблюдает", "GRIM_Small", x + S(470), ry + rowH * 0.5, UI.Fade(UI.GREY, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            UI.Text("—", "GRIM_Small", x + S(470), ry + rowH * 0.5, UI.Fade(UI.GREY, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local vals = {
            {x = cols[3].x, t = tostring(p:GetNWInt("grim_points", 0)), c = UI.ORANGE},
            {x = cols[4].x, t = tostring(p:Frags()), c = UI.WHITE},
            {x = cols[5].x, t = tostring(p:Deaths()), c = UI.WHITE},
            {x = cols[6].x, t = tostring(p:Ping()), c = UI.GREY},
        }
        for _, v in ipairs(vals) do
            UI.Text(v.t, "GRIM_Row", x + v.x, ry + rowH * 0.5, UI.Fade(v.c, k), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        ry = ry + rowH
    end

    if #list > rows then
        UI.Text("и ещё " .. (#list - rows), "GRIM_Small", x + w * 0.5, ry + S(4), UI.Fade(UI.GREY, k), TEXT_ALIGN_CENTER)
    end

    UI.Text("Очки копятся между раундами. Роли раскрываются в итогах.", "GRIM_Tiny",
        x + w * 0.5, y + h - S(22), UI.Fade(UI.GREY, k * 0.8), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "GRIM_Scoreboard", DrawScoreboard)
