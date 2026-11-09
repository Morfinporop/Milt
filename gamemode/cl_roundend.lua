-- GRIMOHOD: экран итогов раунда — победитель, роли всех игроков, MVP.

local UI = GRIM.UI
local PAL = GRIM.Palette
local S = UI.S
local ROLE = GRIM.ROLE
local ST = GRIM.STATE

local summary

net.Receive("grim_roundend", function()
    local winner = net.ReadUInt(3)
    local reason = net.ReadString()
    local rows = net.ReadTable()
    summary = {winner = winner, reason = reason, rows = rows, t0 = CurTime(), sound = false}
end)

local HEADLINE = {
    [ROLE.MURDERER] = {text = "УБИЙЦА ПОБЕДИЛ", col = PAL.RED},
    [ROLE.INNOCENT] = {text = "НЕВИНОВНЫЕ ПОБЕДИЛИ", col = PAL.GREEN},
}

local function DrawSummary()
    if not summary then return end
    local age = CurTime() - summary.t0
    if GRIM.GetState() ~= ST.END and age > 1 then
        summary = nil
        return
    end

    if not summary.sound then
        summary.sound = true
        surface.PlaySound(summary.winner == ROLE.MURDERER and "buttons/combine_button1.wav" or "buttons/button14.wav")
    end

    local k = UI.Ease.OutCubic(age / 0.45)
    local rows = summary.rows
    local shownRows = math.min(#rows, 12)
    local w = S(900)
    local h = S(250) + shownRows * S(32) + S(40)
    local x = ScrW() * 0.5 - w * 0.5
    local y = ScrH() * 0.5 - h * 0.5 + (1 - k) * S(26)

    UI.Panel(x, y, w, h, UI.BG.a * k)
    local head = HEADLINE[summary.winner] or {text = "РАУНД ОТМЕНЁН", col = PAL.GREY}
    UI.Accent(x, y, w, h, k)
    UI.Rect(x, y, w, S(4), UI.Fade(head.col, k))

    local typed = UI.Typed(head.text, age - 0.2, 26)
    UI.Text(typed, "GRIM_Title", x + w * 0.5, y + S(44), UI.Fade(head.col, k), TEXT_ALIGN_CENTER)
    UI.Text(summary.reason, "GRIM_Small", x + w * 0.5, y + S(94), UI.Fade(UI.GREY, k), TEXT_ALIGN_CENTER)

    -- MVP: максимум очков
    local mvp
    for _, r in ipairs(rows) do
        if not mvp or r.points > mvp.points then mvp = r end
    end
    if mvp and mvp.points > 0 then
        local cy = y + S(140)
        UI.Icon("crown", x + S(60), cy, S(30), UI.Fade(UI.ORANGE, k))
        UI.Text("MVP  " .. UI.Fit(mvp.name, "GRIM_Row", S(420)) .. "  ·  " .. mvp.points .. " очк.", "GRIM_Row", x + S(96), cy, UI.Fade(UI.ORANGE, k), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local ty = y + S(176)
    UI.Text("ИГРОК", "GRIM_Tiny", x + S(32), ty, UI.Fade(UI.GREY, k))
    UI.Text("РОЛЬ", "GRIM_Tiny", x + S(440), ty, UI.Fade(UI.GREY, k))
    UI.Text("УБИЙСТВА", "GRIM_Tiny", x + S(720), ty, UI.Fade(UI.GREY, k), TEXT_ALIGN_RIGHT)
    UI.Text("ОЧКИ", "GRIM_Tiny", x + w - S(32), ty, UI.Fade(UI.GREY, k), TEXT_ALIGN_RIGHT)

    local ry = ty + S(24)
    for i = 1, shownRows do
        local r = rows[i]
        local info = GRIM.RoleInfo[r.role] or GRIM.RoleInfo[ROLE.NONE]
        local rowAge = math.Clamp((age - 0.3 - i * 0.05) / 0.25, 0, 1)
        local rk = k * UI.Ease.OutCubic(rowAge)
        local rh = S(32)

        UI.Rect(x + S(16), ry, w - S(32), rh - S(4), UI.Fade(info.color, 0.08 * rk))
        UI.Text(UI.Fit(r.name, "GRIM_Row", S(380)), "GRIM_Row", x + S(32), ry + rh * 0.5,
            UI.Fade(r.alive and UI.WHITE or UI.GREY, rk), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        UI.Icon(info.icon, x + S(452), ry + rh * 0.5, S(18), UI.Fade(info.color, rk))
        UI.Text(info.name, "GRIM_Small", x + S(470), ry + rh * 0.5, UI.Fade(info.color, rk), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        UI.Text(tostring(r.kills), "GRIM_Row", x + S(720), ry + rh * 0.5, UI.Fade(UI.WHITE, rk), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        UI.Text(tostring(r.points), "GRIM_Row", x + w - S(32), ry + rh * 0.5, UI.Fade(UI.ORANGE, rk), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        ry = ry + rh
    end

    local left = math.max(0, GetGlobalFloat("grim_stateend", 0) - CurTime())
    UI.Text("Следующий раунд через " .. math.ceil(left) .. " с", "GRIM_Tiny",
        x + w * 0.5, y + h - S(18), UI.Fade(UI.GREY, k), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "GRIM_RoundEnd", DrawSummary)
