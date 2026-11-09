GM.Name 	= "Murder"
GM.Author 	= "MechanicalMind"
// credits to Minty Fresh for some styling on the scoreboard
// credits to Waddlesworth for the logo and menu icon
GM.Email 	= ""
GM.Website 	= "www.codingconcoctions.com/murder/"

team.SetUp(1, "Наблюдатели", Color(150, 150, 150))
team.SetUp(2, "Игроки", Color(26, 120, 245))

GM.ShowAdminsOnScoreboard = CreateConVar("mu_scoreboard_show_admins", 1, bit.bor(FCVAR_NOTIFY, FCVAR_REPLICATED), "Показывать админов в списке игроков" )
GM.AdminPanelAllowed = CreateConVar("mu_allow_admin_panel", 1, bit.bor(FCVAR_NOTIFY, FCVAR_REPLICATED), "Нужно ли разрешить администраторам использовать mu_admin_panel" )
GM.ShowSpectateInfo = CreateConVar("mu_show_spectate_info", 1, bit.bor(FCVAR_NOTIFY, FCVAR_REPLICATED), "Должен показывать имя и цвет игроков зрителю" )
