-- GRIMOHOD: таблица игроков в стиле qmenu.
-- Это VGUI-панель: при открытии появляется курсор, строки подсвечиваются при наведении.
-- Роли видны только после раунда (grim_shown).

local UI = GRIM.UI
local PAL = GRIM.Palette
local S = UI.S
local ST = GRIM.STATE

local HOLD_FADE = 7
local ROW_H = 34
local MAX_ROWS = 16

local board

local STATE_TEXT = {
    [ST.WAIT] = "ОЖИДАНИЕ",
    [ST.PREP] = "ПОДГОТОВКА",
    [ST.ACTIVE] = "В ИГРЕ",
    [ST.END] = "ИТОГИ",
}

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

-- Геометрия колонок (в базовых пикселях 1080p, масштабируется S)
local COLS = {
    {x = 28, t = "ИГРОК", a = TEXT_ALIGN_LEFT},
    {x = 470, t = "РОЛЬ", a = TEXT_ALIGN_LEFT},
    {x = 640, t = "ОЧКИ", a = TEXT_ALIGN_RIGHT},
    {x = 720, t = "УБИЙСТВА", a = TEXT_ALIGN_RIGHT},
    {x = 800, t = "СМЕРТИ", a = TEXT_ALIGN_RIGHT},
    {x = 892, t = "ПИНГ", a = TEXT_ALIGN_RIGHT},
}

local function Draw(self, w, h)
    local k = self.K
    local list = Sorted()
    local rows = math.min(#list, MAX_ROWS)
    local rowH = S(ROW_H)
    local pw = S(920)
    local ph = S(150) + rows * rowH + S(54)
    local x = w * 0.5 - pw * 0.5
    local y = h * 0.5 - ph * 0.5 + (1 - UI.Ease.OutCubic(k)) * S(24)

    -- Фон и обводка как у qmenu
    UI.Panel(x, y, pw, ph, UI.BG.a * k)
    UI.Accent(x, y, pw, ph, 0)

    -- Шапка
    UI.Text("GRIMOHOD", "GRIM_Title", x + S(28), y + S(22), UI.Fade(UI.ORANGE, k))
    local st = STATE_TEXT[GRIM.GetState()] or ""
    UI.Text("РАУНД " .. GetGlobalInt("grim_round", 0) .. "  ·  " .. st, "GRIM_Tab", x + S(28), y + S(72), UI.Fade(UI.WHITE, k))
    UI.Text(game.GetMap() .. "  ·  " .. #list .. " игроков", "GRIM_Small", x + pw - S(28), y + S(78),
        UI.Fade(UI.GREY, k), TEXT_ALIGN_RIGHT)

    -- Заголовки колонок
    local hy = y + S(116)
    UI.Rect(x + S(18), hy + S(20), pw - S(36), 1, UI.Fade(UI.WHITE, 0.08 * k))
    for _, c in ipairs(COLS) do
        UI.Text(c.t, "GRIM_Tiny", x + S(c.x), hy, UI.Fade(UI.GREY, k), c.a)
    end

    -- Строки
    local me = LocalPlayer()
    local ry = hy + S(30)
    local mx, my = gui.MousePos()
    for i = 1, rows do
        local p = list[i]
        if IsValid(p) then
        local hov = mx >= x and mx <= x + pw and my >= ry and my < ry + rowH
        local hk = hov and 1 or 0
        local alive = p:Alive() and p:Team() == GRIM.TEAM_PLAYER
        local isMe = p == me

        if isMe then
            UI.Rect(x + S(14), ry, pw - S(28), rowH - S(4), UI.Fade(UI.ORANGE, 0.14 * k))
        elseif hk > 0 then
            UI.Rect(x + S(14), ry, pw - S(28), rowH - S(4), UI.Fade(UI.WHITE, 0.05 * k))
        end

        UI.Rect(x + S(22), ry + rowH * 0.5 - S(4), S(8), S(8),
            alive and UI.Fade(PAL.GREEN, k) or UI.Fade(PAL.GREY, k * 0.6))
        UI.Text(UI.Fit(p:Nick(), "GRIM_Row", S(360)), "GRIM_Row", x + S(42), ry + rowH * 0.5,
            UI.Fade(isMe and UI.ORANGE or UI.WHITE, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local role = p:GetNWInt("grim_shown", 0)
        local info = GRIM.RoleInfo[role]
        if role > 0 and info then
            UI.Icon(info.icon, x + S(484), ry + rowH * 0.5, S(18), UI.Fade(info.color, k))
            UI.Text(info.name, "GRIM_Small", x + S(500), ry + rowH * 0.5, UI.Fade(info.color, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            local t = p:Team() == GRIM.TEAM_SPEC and "наблюдает" or "—"
            UI.Text(t, "GRIM_Small", x + S(470), ry + rowH * 0.5, UI.Fade(UI.GREY, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local vals = {
            {c = COLS[3], t = tostring(p:GetNWInt("grim_points", 0)), col = UI.ORANGE},
            {c = COLS[4], t = tostring(p:Frags()), col = UI.WHITE},
            {c = COLS[5], t = tostring(p:Deaths()), col = UI.WHITE},
            {c = COLS[6], t = tostring(p:Ping()), col = UI.GREY},
        }
        for _, v in ipairs(vals) do
            UI.Text(v.t, "GRIM_Row", x + S(v.c.x), ry + rowH * 0.5, UI.Fade(v.col, k), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        end
        ry = ry + rowH
    end

    if #list > rows then
        UI.Text("и ещё " .. (#list - rows), "GRIM_Small", x + pw * 0.5, ry + S(4), UI.Fade(UI.GREY, k), TEXT_ALIGN_CENTER)
    end

    UI.Text("Очки копятся между раундами. Роли раскрываются в итогах.", "GRIM_Tiny",
        x + pw * 0.5, y + ph - S(22), UI.Fade(UI.GREY, k * 0.8), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function Build()
    if IsValid(board) then return board end
    local p = vgui.Create("EditablePanel")
    p:SetSize(ScrW(), ScrH())
    p:SetPos(0, 0)
    p:SetVisible(false)
    p:SetAlpha(0)
    p.K = 0
    p.Target = 0
    p.Paint = function(self, w, h)
        if self.K <= 0 then return end
        Draw(self, w, h)
    end
    p.Think = function(self)
        self.K = math.Approach(self.K, self.Target, FrameTime() * HOLD_FADE)
        self:SetAlpha(255 * UI.Ease.OutCubic(self.K))
        if self.Target == 0 and self.K <= 0 then
            self:SetVisible(false)
            self:SetMouseInputEnabled(false)
        end
    end
    board = p
    return p
end

hook.Add("ScoreboardShow", "GRIM_ScoreboardShow", function()
    local p = Build()
    p.Target = 1
    p:SetVisible(true)
    p:MakePopup()
    p:SetKeyboardInputEnabled(false)
    p:SetMouseInputEnabled(true)
    return true
end)

hook.Add("ScoreboardHide", "GRIM_ScoreboardHide", function()
    if IsValid(board) then
        board.Target = 0
        board:SetMouseInputEnabled(false)
        board:SetKeyboardInputEnabled(false)
    end
    return true
end)
