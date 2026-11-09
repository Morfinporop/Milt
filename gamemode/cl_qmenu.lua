local FONT = "Montserrat"
local BG_COL = Color(20, 20, 26, 155)
local OUTLINE_COL = Color(255, 255, 255, 10)
local OUTLINE_TH = 1
local ORANGE = Color(241, 143, 38)
local GREEN = Color(88, 200, 84)
local WHITE = Color(255, 255, 255)
local GREY = Color(170, 170, 178)
local LETTER = Color(255, 255, 255, 60)

local SAVE_FILE = "elysium_qmenu.json"
local HOLD_TIME = 0.25
local MAX_RESULTS = 400
local ICON_BUDGET = 6
local ADMIN_ONLY_TABS = {ent = true, wep = true, veh = true, npc = true}

local TABS = {
    {id = "fav", name = "ИЗБРАННОЕ"},
    {id = "prop", name = "ПРОПЫ"},
    {id = "ent", name = "ПРЕДМЕТЫ"},
    {id = "wep", name = "ОРУЖИЕ"},
    {id = "veh", name = "ТРАНСПОРТ"},
    {id = "npc", name = "NPC"},
    {id = "tool", name = "ИНСТРУМЕНТЫ"}
}

local TYPE_ORDER = {"prop", "ent", "wep", "veh", "npc", "tool"}

local L = {}
local Root, Data
local Fav = {}
local ToolCV

local DIA = {{x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}}

local function S(v)
    return math.floor(v * ScrH() / 1080 + 0.5)
end

local function Font(name, size)
    surface.CreateFont(name, {
        font = FONT,
        size = S(size),
        weight = 700,
        antialias = true,
        extended = true
    })
end

local function Box(x, y, w, h, r, g, b, a)
    draw.NoTexture()
    surface.SetDrawColor(r, g, b, a)
    surface.DrawRect(x, y, w, h)
end

local function Border(x, y, w, h, r, g, b, a)
    draw.NoTexture()
    surface.SetDrawColor(r, g, b, a)
    surface.DrawOutlinedRect(x, y, w, h, L.OUT)
end

local function BorderK(x, y, w, h, k)
    Border(
        x, y, w, h,
        Lerp(k, OUTLINE_COL.r, ORANGE.r),
        Lerp(k, OUTLINE_COL.g, ORANGE.g),
        Lerp(k, OUTLINE_COL.b, ORANGE.b),
        Lerp(k, OUTLINE_COL.a, 255)
    )
end

local function DrawDiamond(cx, cy, r)
    DIA[1].x = cx
    DIA[1].y = cy - r
    DIA[2].x = cx + r
    DIA[2].y = cy
    DIA[3].x = cx
    DIA[3].y = cy + r
    DIA[4].x = cx - r
    DIA[4].y = cy
    draw.NoTexture()
    surface.SetDrawColor(ORANGE.r, ORANGE.g, ORANGE.b, 255)
    surface.DrawPoly(DIA)
end

local function Fit(txt, font, mw)
    surface.SetFont(font)
    if (surface.GetTextSize(txt)) <= mw then return txt end
    local n = utf8.len(txt) or #txt
    while n > 1 do
        n = n - 1
        local cut = (utf8.offset(txt, n + 1) or (#txt + 1)) - 1
        local s = string.sub(txt, 1, cut) .. "…"
        if (surface.GetTextSize(s)) <= mw then return s end
    end
    return "…"
end

local function Phrase(s)
    if not isstring(s) or s == "" then return "" end
    if string.sub(s, 1, 1) == "#" then
        return language.GetPhrase(string.sub(s, 2))
    end
    return s
end

local function Pick(v, fallback)
    local s = Phrase(v)
    if s == "" then return fallback end
    return s
end

local function Build()
    L.Scr = ScrH()
    L.ScrW = ScrW()
    L.W = math.min(S(1360), ScrW() - S(60))
    L.H = math.min(S(780), ScrH() - S(80))
    L.TH = S(46)
    L.TG = S(8)
    L.TPAD = S(24)
    L.OUT = OUTLINE_TH
    L.BGAP = S(14)
    L.SBW = S(230)
    L.CATH = S(38)
    L.CATG = S(5)
    L.CW = S(136)
    L.CH = S(162)
    L.PW = S(120)
    L.PAD = S(8)
    L.GG = S(10)
    L.TPW = S(340)
    L.VBW = S(6)
    L.VBG = S(10)

    Font("ElysiumQ_Tab", 17)
    Font("ElysiumQ_Row", 19)
    Font("ElysiumQ_Card", 15)
    Font("ElysiumQ_Small", 14)
    Font("ElysiumQ_Letter", 54)
end

Build()

local function LoadFav()
    local raw = file.Read(SAVE_FILE, "DATA")
    local t = raw and util.JSONToTable(raw)
    if not istable(t) then return end
    for _, k in ipairs(t) do
        if isstring(k) then Fav[k] = true end
    end
end

local function SaveFav()
    local out = {}
    for k in pairs(Fav) do
        out[#out + 1] = k
    end
    table.sort(out)
    file.Write(SAVE_FILE, util.TableToJSON(out))
end

LoadFav()

local function IsAdm()
    local lp = LocalPlayer()
    return IsValid(lp) and lp:IsAdmin()
end

local function ToolMode()
    if not ToolCV then ToolCV = GetConVar("gmod_toolmode") end
    return ToolCV and ToolCV:GetString() or ""
end

local function NewItem(tab, id, name, sub)
    name = name or id
    sub = sub or ""
    local cut = (utf8.offset(name, 2) or (#name + 1)) - 1
    local first = string.sub(name, 1, cut)
    return {
        tab = tab,
        id = id,
        key = tab .. ":" .. id,
        name = name,
        sub = sub,
        lname = string.lower(name),
        search = string.lower(name .. " " .. sub),
        letter = first ~= "" and string.upper(first) or "?"
    }
end

local function SetIcon(it, class, model)
    local m = Material("entities/" .. class .. ".png", "smooth")
    if m and not m:IsError() then
        it.mat = m
        return
    end
    if isstring(model) and model ~= "" and file.Exists(model, "GAME") then
        it.model = string.lower(model)
    end
end

local function Group(entries)
    table.sort(entries, function(a, b)
        if a.lname ~= b.lname then return a.lname < b.lname end
        return a.key < b.key
    end)
    local map, cats = {}, {}
    for _, it in ipairs(entries) do
        local n = it.cat or "Другое"
        local c = map[n]
        if not c then
            c = {name = n, items = {}}
            map[n] = c
            cats[#cats + 1] = c
        end
        c.items[#c.items + 1] = it
    end
    table.sort(cats, function(a, b) return a.name < b.name end)
    return cats, entries
end

local function Ordered(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na < nb end
        return tostring(a) < tostring(b)
    end)
    local out = {}
    for i, k in ipairs(keys) do
        out[i] = t[k]
    end
    return out
end

local function ReadLists()
    local lists = {}
    local ok, tbl = pcall(spawnmenu.GetPropTable)
    if ok and istable(tbl) then
        for id, sl in pairs(tbl) do
            if istable(sl) and istable(sl.contents) then
                lists[#lists + 1] = {
                    name = Pick(sl.name, tostring(id)),
                    contents = sl.contents,
                    order = tostring(sl.id or id)
                }
            end
        end
        table.sort(lists, function(a, b)
            if a.order ~= b.order then return a.order < b.order end
            return a.name < b.name
        end)
    end
    return lists
end

local function ReadFiles()
    local lists = {}
    local files = file.Find("settings/spawnlist_default/*.txt", "GAME")
    table.sort(files)
    for _, f in ipairs(files) do
        local raw = file.Read("settings/spawnlist_default/" .. f, "GAME")
        local kv = raw and util.KeyValuesToTable(raw)
        if istable(kv) and istable(kv.contents) then
            lists[#lists + 1] = {
                name = Pick(kv.name, f),
                contents = kv.contents
            }
        end
    end
    return lists
end

local function ParseLists(lists)
    local cats, all, seen = {}, {}, {}
    for _, sl in ipairs(lists) do
        local items = {}
        for _, c in ipairs(Ordered(sl.contents)) do
            if istable(c) and c.type == "model" and isstring(c.model) and c.model ~= "" then
                local mdl = string.lower(c.model)
                local skin = tonumber(c.skin) or 0
                local body = c.body ~= nil and tostring(c.body) or ""
                local id = mdl
                if skin ~= 0 or body ~= "" then
                    id = mdl .. "|" .. skin .. "|" .. body
                end
                local it = seen[id]
                if not it then
                    it = NewItem("prop", id, string.StripExtension(string.GetFileFromFilename(mdl)), mdl)
                    it.model = mdl
                    it.skin = skin
                    it.body = body
                    seen[id] = it
                    all[#all + 1] = it
                end
                items[#items + 1] = it
            end
        end
        if #items > 0 then
            cats[#cats + 1] = {name = sl.name, items = items}
        end
    end
    return cats, all
end

local function BuildProps()
    local cats, all = ParseLists(ReadLists())
    if #all == 0 then
        cats, all = ParseLists(ReadFiles())
    end
    return cats, all
end

local function BuildEnts()
    local out = {}
    for rawKey, e in pairs(list.Get("SpawnableEntities") or {}) do
        if istable(e) then
            local key = tostring(rawKey)
            local it = NewItem("ent", key, Pick(e.PrintName, key), key)
            it.cat = Pick(e.Category, "Другое")
            it.admin = e.AdminOnly and true or false
            local st = scripted_ents.Get(key)
            SetIcon(it, key, st and st.Model)
            out[#out + 1] = it
        end
    end
    return Group(out)
end

local function BuildWeps()
    local out = {}
    for rawClass, w in pairs(list.Get("Weapon") or {}) do
        if istable(w) and w.Spawnable then
            local class = tostring(rawClass)
            local it = NewItem("wep", class, Pick(w.PrintName, class), class)
            it.cat = Pick(w.Category, "Другое")
            it.admin = w.AdminOnly and true or false
            local sw = weapons.Get(class)
            SetIcon(it, class, sw and sw.WorldModel)
            out[#out + 1] = it
        end
    end
    return Group(out)
end

local function BuildVehs()
    local out = {}
    for rawKey, v in pairs(list.Get("Vehicles") or {}) do
        if istable(v) then
            local key = tostring(rawKey)
            local it = NewItem("veh", key, Pick(v.Name, key), key)
            it.cat = Pick(v.Category, "Другое")
            it.admin = v.AdminOnly and true or false
            SetIcon(it, key, v.Model)
            out[#out + 1] = it
        end
    end
    return Group(out)
end

local function BuildNpcs()
    local out = {}
    for rawKey, n in pairs(list.Get("NPC") or {}) do
        if istable(n) then
            local key = tostring(rawKey)
            local it = NewItem("npc", key, Pick(n.Name, key), key)
            it.cat = Pick(n.Category, "Другое")
            it.admin = n.AdminOnly and true or false
            SetIcon(it, key, n.Model)
            out[#out + 1] = it
        end
    end
    return Group(out)
end

local function BuildTools()
    local out = {}
    local ok, menu = pcall(spawnmenu.GetToolMenu, "Main")
    if not ok or not istable(menu) then return {}, {} end
    for _, cat in pairs(menu) do
        if istable(cat) then
            local cname = Pick(cat.Text or cat.ItemName, "Другое")
            local src = istable(cat.Items) and cat.Items or cat
            for _, item in pairs(src) do
                if istable(item) and isstring(item.ItemName) then
                    local it = NewItem("tool", item.ItemName, Pick(item.Text, item.ItemName), cname)
                    it.cat = cname
                    it.cmd = (isstring(item.Command) and item.Command ~= "") and item.Command or ("gmod_tool " .. item.ItemName)
                    it.ref = item
                    out[#out + 1] = it
                end
            end
        end
    end
    return Group(out)
end

local function EnsureData()
    if Data then return Data end
    Data = {flat = {}}
    local builders = {
        prop = BuildProps,
        ent = BuildEnts,
        wep = BuildWeps,
        veh = BuildVehs,
        npc = BuildNpcs,
        tool = BuildTools
    }
    for _, t in ipairs(TYPE_ORDER) do
        local ok, cats, all = pcall(builders[t])
        if not ok then
            ErrorNoHalt("[ElysiumQ] " .. t .. ": " .. tostring(cats) .. "\n")
            cats, all = {}, {}
        end
        Data[t] = {cats = cats or {}, all = all or {}}
        for _, it in ipairs(Data[t].all) do
            Data.flat[#Data.flat + 1] = it
        end
    end
    return Data
end

local function Filter(items, adm)
    if adm then return items end
    local out = {}
    for _, it in ipairs(items) do
        if not it.admin then
            out[#out + 1] = it
        end
    end
    return out
end

local function Search(q, adm)
    local words = {}
    for w in string.gmatch(string.lower(q), "%S+") do
        words[#words + 1] = w
    end
    local out = {}
    if #words == 0 then return out end
    for _, it in ipairs(Data.flat) do
        if adm or not it.admin then
            local ok = true
            for _, w in ipairs(words) do
                if not string.find(it.search, w, 1, true) then
                    ok = false
                    break
                end
            end
            if ok then
                out[#out + 1] = it
                if #out >= MAX_RESULTS then break end
            end
        end
    end
    return out
end

local function TabShown(id, adm)
    if id == "fav" then return true end
    if ADMIN_ONLY_TABS[id] and not adm then return false end
    local d = Data[id]
    return d ~= nil and #d.all > 0
end

local function Blur()
    if not IsValid(Root) then return end
    local b = Root.Board
    if IsValid(b) and IsValid(b.Entry) then
        b.Entry:KillFocus()
    end
    Root:SetKeyboardInputEnabled(false)
end

local function Close(instant)
    if not IsValid(Root) then return end
    Blur()
    Root.Target = 0
    Root:SetMouseInputEnabled(false)
    if instant then
        Root.K = 0
        Root:SetAlpha(0)
        Root:SetVisible(false)
    end
end

local function Activate(it)
    local t = it.tab
    if t == "prop" then
        RunConsoleCommand("gm_spawn", it.model, tostring(it.skin or 0), it.body or "")
    elseif t == "ent" then
        RunConsoleCommand("gm_spawnsent", it.id)
    elseif t == "wep" then
        RunConsoleCommand("gm_giveswep", it.id)
    elseif t == "veh" then
        RunConsoleCommand("gm_spawnvehicle", it.id)
    elseif t == "npc" then
        local cv = GetConVar("gmod_npcweapon")
        RunConsoleCommand("gmod_spawnnpc", it.id, cv and cv:GetString() or "")
    elseif t == "tool" then
        RunConsoleCommand(unpack(string.Explode(" ", it.cmd)))
        if IsValid(Root) and IsValid(Root.Board) then
            Root.Board:ShowTool(it)
        end
    end
end

local function ToggleFav(it)
    if Fav[it.key] then
        Fav[it.key] = nil
    else
        Fav[it.key] = true
    end
    SaveFav()
    if IsValid(Root) and IsValid(Root.Board) then
        Root.Board:OnFavChanged()
    end
end

local function StyleBar(vb)
    vb:SetWide(L.VBW)
    vb:SetHideButtons(true)
    vb.Paint = function(_, w, h)
        Box(0, 0, w, h, BG_COL.r, BG_COL.g, BG_COL.b, BG_COL.a)
    end
    vb.btnUp.Paint = function() end
    vb.btnDown.Paint = function() end
    vb.btnGrip.Paint = function(_, w, h)
        Box(0, 0, w, h, ORANGE.r, ORANGE.g, ORANGE.b, 255)
    end
end

local function CleanLabels(p)
    for _, c in ipairs(p:GetChildren()) do
        if c.GetText and c.SetText and c:GetText() == "Label" then
            c:SetText("")
        end
        CleanLabels(c)
    end
end

local function GridMetrics(g)
    local named = g.Named
    g.CW = named and L.CW or L.PW
    g.CH = named and L.CH or L.PW
    g.Isz = g.CW - L.PAD * 2
    g.RowH = g.CH + L.GG
end

local function NewIcon(parent)
    local ic = vgui.Create("SpawnIcon", parent)
    ic:SetMouseInputEnabled(false)
    for _, c in ipairs(ic:GetChildren()) do
        c:SetMouseInputEnabled(false)
    end
    ic.Paint = function() end
    ic.PaintOver = function() end
    ic:SetVisible(false)
    return ic
end

local function CreateGrid(parent)
    local g = vgui.Create("DPanel", parent)
    local vb = vgui.Create("DVScrollBar", g)
    vb:Dock(RIGHT)
    StyleBar(vb)

    g.VB = vb
    g.Items = {}
    g.Active = {}
    g.Free = {}
    g.Cols = 1
    g.Rows = 0
    g.VisRows = 1
    g.Named = true
    g.Hover = nil
    g.HK = 0
    g.Dirty = true
    g.Settled = true
    g.I0 = 0
    g.I1 = -1
    g.PrevScroll = 0
    g.PosScroll = -1
    g.LW = 0
    g.LH = 0
    g.Empty = ""
    GridMetrics(g)

    function g:ReleaseAll()
        for idx, ic in pairs(self.Active) do
            ic:SetVisible(false)
            self.Free[#self.Free + 1] = ic
            self.Active[idx] = nil
        end
    end

    function g:Recalc()
        local w, h = self:GetSize()
        if w < 10 or h < 10 then return end
        GridMetrics(self)
        local usable = w - self.VB:GetWide() - L.GG
        self.Cols = math.max(1, math.floor((usable + L.GG) / (self.CW + L.GG)))
        self.Rows = math.ceil(#self.Items / self.Cols)
        self.VisRows = math.ceil(h / self.RowH) + 1
        self.VB:SetUp(h, self.Rows * self.RowH)
        self:ReleaseAll()
        self.Dirty = true
        self.I0 = 0
        self.I1 = -1
        self.PosScroll = -1
    end

    function g:PerformLayout(w, h)
        if w == self.LW and h == self.LH then return end
        self.LW = w
        self.LH = h
        self:Recalc()
    end

    function g:SetItems(items, named, keep)
        local sc = keep and self.VB:GetScroll() or 0
        self.Items = items
        self.Named = named and true or false
        self.Hover = nil
        GridMetrics(self)
        self:Recalc()
        self.VB:SetScroll(sc)
        self.PrevScroll = self.VB:GetScroll()
    end

    function g:IndexAt(mx, my)
        local cw, G = self.CW, L.GG
        local ly = my + self.VB:GetScroll()
        if mx < 0 or ly < 0 then return nil end
        local col = math.floor(mx / (cw + G))
        local row = math.floor(ly / self.RowH)
        if col >= self.Cols then return nil end
        if mx - col * (cw + G) > cw then return nil end
        if ly - row * self.RowH > self.CH then return nil end
        local idx = row * self.Cols + col + 1
        if idx > #self.Items then return nil end
        return idx
    end

    function g:Think()
        local items = self.Items
        local n = #items
        local cols, rowH = self.Cols, self.RowH
        local scroll = self.VB:GetScroll()
        local first = math.max(0, math.floor(scroll / rowH))
        local i0 = first * cols + 1
        local i1 = math.min(n, (first + self.VisRows) * cols)
        local fast = math.abs(scroll - self.PrevScroll) > rowH * 0.3
        self.PrevScroll = scroll

        if self.Dirty or i0 ~= self.I0 or i1 ~= self.I1 then
            self.Dirty = false
            self.I0 = i0
            self.I1 = i1
            self.Settled = false
            for idx, ic in pairs(self.Active) do
                if idx < i0 or idx > i1 then
                    ic:SetVisible(false)
                    self.Free[#self.Free + 1] = ic
                    self.Active[idx] = nil
                end
            end
        end

        if scroll ~= self.PosScroll then
            self.PosScroll = scroll
            for _, ic in pairs(self.Active) do
                ic:SetPos(ic.BX, ic.BY - scroll)
            end
        end

        if not self.Settled and not fast then
            local budget = ICON_BUDGET
            local done = true
            for i = i0, i1 do
                if not self.Active[i] then
                    local it = items[i]
                    if it.model then
                        if budget <= 0 then
                            done = false
                            break
                        end
                        budget = budget - 1
                        local ic = table.remove(self.Free) or NewIcon(self)
                        local skin = it.skin or 0
                        local body = it.body or ""
                        local key = it.model .. "|" .. skin .. "|" .. body
                        if ic.Key ~= key then
                            ic.Key = key
                            ic:SetModel(it.model, skin, body)
                        end
                        ic:SetSize(self.Isz, self.Isz)
                        ic.BX = ((i - 1) % cols) * (self.CW + L.GG) + L.PAD
                        ic.BY = math.floor((i - 1) / cols) * rowH + L.PAD
                        ic:SetPos(ic.BX, ic.BY - scroll)
                        ic:SetVisible(true)
                        self.Active[i] = ic
                    end
                end
            end
            if done then self.Settled = true end
        end

        local idx
        if self:IsHovered() then
            local mx, my = self:CursorPos()
            idx = self:IndexAt(mx, my)
        end
        if idx ~= self.Hover then
            self.Hover = idx
            self.HK = 0
        end
        self.HK = math.min(1, self.HK + FrameTime() * 9)
    end

    function g:Paint(w, h)
        local items = self.Items
        local n = #items
        if n == 0 then
            draw.SimpleText(self.Empty, "ElysiumQ_Row", w * 0.5, h * 0.4, GREY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local cols, cw, ch, rowH, G = self.Cols, self.CW, self.CH, self.RowH, L.GG
        local scroll = self.VB:GetScroll()
        local first = math.max(0, math.floor(scroll / rowH))
        local i0 = first * cols + 1
        local i1 = math.min(n, (first + math.ceil(h / rowH) + 1) * cols)
        local named, pad, isz = self.Named, L.PAD, self.Isz
        local mode = ToolMode()

        local sx, sy = self:LocalToScreen(0, 0)
        render.SetScissorRect(sx, sy, sx + w - self.VB:GetWide(), sy + h, true)

        for i = i0, i1 do
            local it = items[i]
            local x = ((i - 1) % cols) * (cw + G)
            local y = math.floor((i - 1) / cols) * rowH - scroll

            if y + ch > 0 and y < h then
                local hk = (i == self.Hover) and self.HK or 0
                local sel = it.tab == "tool" and it.id == mode

                Box(x, y, cw, ch, BG_COL.r, BG_COL.g, BG_COL.b, BG_COL.a)
                if hk > 0 then
                    Box(x, y, cw, ch, ORANGE.r, ORANGE.g, ORANGE.b, 70 * hk)
                end
                if sel then
                    Border(x, y, cw, ch, GREEN.r, GREEN.g, GREEN.b, 255)
                else
                    BorderK(x, y, cw, ch, hk)
                end
                if Fav[it.key] then
                    DrawDiamond(x + cw - S(16), y + S(14), S(6))
                end

                local ix, iy = x + pad, y + pad
                if it.mat then
                    surface.SetMaterial(it.mat)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawTexturedRect(ix, iy, isz, isz)
                elseif not it.model then
                    draw.SimpleText(it.letter, "ElysiumQ_Letter", ix + isz * 0.5, iy + isz * 0.5, LETTER, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                if named then
                    if not it.fit then
                        it.fit = Fit(it.name, "ElysiumQ_Card", cw - pad * 2)
                    end
                    draw.SimpleText(it.fit, "ElysiumQ_Card", x + cw * 0.5, y + pad + isz + (ch - pad - isz) * 0.5, WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end

        render.SetScissorRect(0, 0, 0, 0, false)
    end

    function g:OnMousePressed(code)
        Blur()
        local mx, my = self:CursorPos()
        local idx = self:IndexAt(mx, my)
        local it = idx and self.Items[idx]
        if not it then return end
        if code == MOUSE_LEFT then
            Activate(it)
        elseif code == MOUSE_RIGHT then
            ToggleFav(it)
        end
    end

    function g:OnMouseWheeled(d)
        self.VB:AddScroll(-d * 3.5)
        return true
    end

    return g
end

local function CreateCat(b, i, c)
    local btn = vgui.Create("DButton")
    btn:SetText("")
    btn:Dock(TOP)
    btn:SetTall(L.CATH)
    btn:DockMargin(0, 0, L.VBW + L.VBG, L.CATG)
    btn.K = 0
    btn.Label = ""
    btn.Count = tostring(#c.items)

    btn.PerformLayout = function(s, w, h)
        s.Label = Fit(c.name, "ElysiumQ_Row", w - S(28) - S(56))
    end

    btn.Paint = function(s, w, h)
        s.K = math.Approach(s.K, s:IsHovered() and 1 or 0, FrameTime() * 10)
        local k = s.K

        Box(0, 0, w, h, BG_COL.r, BG_COL.g, BG_COL.b, BG_COL.a)
        if s.Active then
            Box(0, 0, w, h, ORANGE.r, ORANGE.g, ORANGE.b, 90)
        end
        if k > 0 then
            Box(0, 0, w, h, ORANGE.r, ORANGE.g, ORANGE.b, 90 * k)
        end

        BorderK(0, 0, w, h, s.Active and 1 or k)

        draw.SimpleText(s.Label, "ElysiumQ_Row", S(14), h * 0.5, WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(s.Count, "ElysiumQ_Small", w - S(12), h * 0.5, k > 0.5 and WHITE or GREY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        Blur()
        b:SelectCat(i)
    end

    return btn
end

local function FavItems(adm)
    local out = {}
    for _, it in ipairs(Data.flat) do
        if Fav[it.key] and (adm or not it.admin) then
            out[#out + 1] = it
        end
    end
    table.sort(out, function(a, c)
        if a.lname ~= c.lname then return a.lname < c.lname end
        return a.key < c.key
    end)
    return out
end

local function CreateBoard(root)
    local b = vgui.Create("EditablePanel", root)
    b:SetSize(L.W, L.H)
    b.Tab = "prop"
    b.CatIdx = 1
    b.Cats = {}
    b.Query = ""
    b.QueryAt = 0
    b.QueryDirty = false
    b.TabBtns = {}
    b.CatBtns = {}
    b.ToolPanels = {}
    b.ToolItem = nil
    b.SearchW = S(280)

    b.OnMousePressed = function()
        Blur()
    end

    local sb = vgui.Create("DPanel", b)
    sb:SetSize(b.SearchW, L.TH)
    sb:SetPos(L.W - b.SearchW, 0)

    local entry = vgui.Create("DTextEntry", sb)
    entry:SetPos(S(16), S(6))
    entry:SetSize(b.SearchW - S(32), L.TH - S(12))
    entry:SetFont("ElysiumQ_Row")
    entry:SetDrawLanguageID(false)
    entry.Paint = function(s)
        s:DrawTextEntryText(WHITE, Color(241, 143, 38, 110), WHITE)
    end
    entry.OnChange = function()
        b.QueryAt = CurTime() + 0.12
        b.QueryDirty = true
    end
    entry.OnEnter = function()
        Blur()
    end
    entry.OnKeyCodeTyped = function(s, code)
        if code == KEY_ESCAPE then
            Blur()
            gui.HideGameUI()
            Close()
            return
        end
        local base = baseclass.Get("DTextEntry")
        if base and base.OnKeyCodeTyped then
            return base.OnKeyCodeTyped(s, code)
        end
    end
    b.Entry = entry

    sb.K = 0
    sb.Paint = function(s, w, h)
        s.K = math.Approach(s.K, entry:HasFocus() and 1 or 0, FrameTime() * 10)
        Box(0, 0, w, h, BG_COL.r, BG_COL.g, BG_COL.b, BG_COL.a)
        BorderK(0, 0, w, h, s.K)
        if entry:GetValue() == "" then
            draw.SimpleText("ПОИСК ПРЕДМЕТОВ", "ElysiumQ_Tab", S(16), h * 0.5, GREY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local side = vgui.Create("DScrollPanel", b)
    StyleBar(side:GetVBar())
    side.Paint = function() end
    b.Side = side

    local tbx = vgui.Create("DPanel", b)
    tbx:SetVisible(false)
    tbx:DockPadding(L.OUT, S(40), L.OUT, L.OUT)
    tbx.Paint = function(_, w, h)
        Box(0, 0, w, h, BG_COL.r, BG_COL.g, BG_COL.b, BG_COL.a)
        Border(0, 0, w, h, OUTLINE_COL.r, OUTLINE_COL.g, OUTLINE_COL.b, OUTLINE_COL.a)
        local name = b.ToolItem and b.ToolItem.name or ""
        draw.SimpleText(Fit(name, "ElysiumQ_Row", w - S(32)), "ElysiumQ_Row", S(16), S(20), WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    b.ToolBox = tbx

    local tsc = vgui.Create("DScrollPanel", tbx)
    tsc:Dock(FILL)
    tsc.Paint = function() end
    StyleBar(tsc:GetVBar())
    b.ToolScroll = tsc

    b.Grid = CreateGrid(b)

    function b:BuildTabs()
        for _, t in ipairs(self.TabBtns) do
            if IsValid(t) then t:Remove() end
        end
        self.TabBtns = {}

        local adm = IsAdm()
        local list, widths, sum = {}, {}, 0
        surface.SetFont("ElysiumQ_Tab")
        for _, t in ipairs(TABS) do
            if TabShown(t.id, adm) then
                list[#list + 1] = t
                widths[#list] = (surface.GetTextSize(t.name))
                sum = sum + widths[#list]
            end
        end

        local n = #list
        if n == 0 then return end

        local avail = L.W - self.SearchW - L.BGAP
        local pad = math.Clamp((avail - sum - (n - 1) * L.TG) / (2 * n), S(8), L.TPAD)
        local x = 0

        for i, t in ipairs(list) do
            local w = math.floor(widths[i] + pad * 2)
            local btn = vgui.Create("DButton", self)
            btn:SetText("")
            btn:SetPos(x, 0)
            btn:SetSize(w, L.TH)
            btn.K = 0

            btn.Paint = function(s, bw, bh)
                s.K = math.Approach(s.K, s:IsHovered() and 1 or 0, FrameTime() * 10)
                local k = s.K
                local act = b.Tab == t.id

                Box(0, 0, bw, bh, BG_COL.r, BG_COL.g, BG_COL.b, BG_COL.a)
                if act then
                    Box(0, 0, bw, bh, ORANGE.r, ORANGE.g, ORANGE.b, 110)
                elseif k > 0 then
                    Box(0, 0, bw, bh, ORANGE.r, ORANGE.g, ORANGE.b, 90 * k)
                end

                BorderK(0, 0, bw, bh, act and 1 or k)

                draw.SimpleText(t.name, "ElysiumQ_Tab", bw * 0.5, bh * 0.5, WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            btn.DoClick = function()
                Blur()
                b.Query = ""
                b.QueryDirty = false
                b.Entry:SetValue("")
                b:SetTab(t.id)
            end

            self.TabBtns[#self.TabBtns + 1] = btn
            x = x + w + L.TG
        end
    end

    function b:BuildCats()
        local cats = {}
        local id = self.Tab
        if id ~= "fav" and Data[id] then
            local adm = IsAdm()
            local d = Data[id]
            local all = Filter(d.all, adm)
            if #all > 0 then
                cats[1] = {name = "Все", items = all}
                for _, c in ipairs(d.cats) do
                    local items = Filter(c.items, adm)
                    if #items > 0 then
                        cats[#cats + 1] = {name = c.name, items = items}
                    end
                end
            end
        end
        self.Cats = cats
    end

    function b:RebuildSide()
        self.Side:Clear()
        self.CatBtns = {}
        for i, c in ipairs(self.Cats) do
            local btn = CreateCat(self, i, c)
            self.Side:AddItem(btn)
            self.CatBtns[i] = btn
        end
        self:MarkCats()
    end

    function b:MarkCats()
        local searching = self.Query ~= ""
        for i, btn in ipairs(self.CatBtns) do
            if IsValid(btn) then
                btn.Active = (not searching) and i == self.CatIdx
            end
        end
    end

    function b:LayoutContent()
        local cy = L.TH + L.BGAP
        local chh = L.H - cy
        local x = 0

        local showSide = self.Tab ~= "fav"
        self.Side:SetVisible(showSide)
        if showSide then
            local sw = L.SBW + L.VBW + L.VBG
            self.Side:SetPos(0, cy)
            self.Side:SetSize(sw, chh)
            x = sw + L.BGAP
        end

        local right = L.W
        local showTool = self.Tab == "tool" and self.ToolItem ~= nil
        self.ToolBox:SetVisible(showTool)
        if showTool then
            right = L.W - L.TPW - L.BGAP
            self.ToolBox:SetPos(right + L.BGAP, cy)
            self.ToolBox:SetSize(L.TPW, chh)
        end

        self.Grid:SetPos(x, cy)
        self.Grid:SetSize(right - x, chh)
    end

    function b:Apply(keep)
        local adm = IsAdm()
        local grid = self.Grid
        local items, named
        local q = self.Query

        if q ~= "" then
            items = Search(q, adm)
            named = true
            grid.Empty = "Ничего не найдено"
        elseif self.Tab == "fav" then
            items = FavItems(adm)
            named = true
            grid.Empty = "Пусто. ПКМ по предмету добавляет его сюда"
        else
            local c = self.Cats[self.CatIdx]
            items = c and c.items or {}
            named = self.Tab ~= "prop"
            grid.Empty = "Здесь пока ничего нет"
        end

        self:MarkCats()
        self:LayoutContent()
        grid:SetItems(items, named, keep)
    end

    function b:SetTab(id, idx)
        self.Tab = id
        self:BuildCats()
        self.CatIdx = math.Clamp(idx or 1, 1, math.max(1, #self.Cats))
        self:RebuildSide()

        if id == "tool" and not self.ToolItem and Data.tool then
            local mode = ToolMode()
            for _, it in ipairs(Data.tool.all) do
                if it.id == mode then
                    self:ShowTool(it)
                    break
                end
            end
        end

        self:Apply()
    end

    function b:SelectCat(i)
        self.Query = ""
        self.QueryDirty = false
        self.Entry:SetValue("")
        self.CatIdx = i
        self:Apply()
    end

    function b:OnFavChanged()
        if self.Tab == "fav" and self.Query == "" then
            self:Apply(true)
        end
    end

    function b:MakeToolPanel(it)
        local fn = it.ref and it.ref.CPanelFunction
        if not isfunction(fn) then return nil end
        local cp = vgui.Create("ControlPanel", self.ToolScroll)
        if not IsValid(cp) then return nil end
        cp:Dock(TOP)
        if cp.SetLabel then cp:SetLabel("") end
        if IsValid(cp.Header) then
            cp.Header:SetText("")
            cp.Header:SetVisible(false)
        end
        self.ToolScroll:AddItem(cp)
        local ok, err = pcall(fn, cp)
        if not ok then
            ErrorNoHalt("[ElysiumQ] tool " .. tostring(it.id) .. ": " .. tostring(err) .. "\n")
            cp:Remove()
            return nil
        end
        CleanLabels(cp)
        cp:InvalidateLayout(true)
        timer.Simple(0, function()
            if IsValid(cp) then
                CleanLabels(cp)
            end
        end)
        return cp
    end

    function b:ShowTool(it)
        self.ToolItem = it
        for _, p in pairs(self.ToolPanels) do
            if IsValid(p) then p:SetVisible(false) end
        end

        local p = self.ToolPanels[it.id]
        if p == nil then
            p = self:MakeToolPanel(it) or false
            self.ToolPanels[it.id] = p
        end
        if IsValid(p) then
            p:SetVisible(true)
            if IsValid(p.Header) then p.Header:SetVisible(false) end
        end

        self:LayoutContent()
        self.ToolScroll:GetVBar():SetScroll(0)
        self.ToolScroll:InvalidateLayout(true)
        if IsValid(p) then
            p:InvalidateLayout(true)
        end
    end

    function b:OnOpen()
        self.Query = ""
        self.QueryDirty = false
        self.Entry:SetValue("")
        self:BuildTabs()
        if not TabShown(self.Tab, IsAdm()) then
            self.Tab = "fav"
            self.CatIdx = 1
        end
        self:SetTab(self.Tab, self.CatIdx)
    end

    function b:Think()
        if self.QueryDirty and CurTime() >= self.QueryAt then
            self.QueryDirty = false
            local q = string.Trim(self.Entry:GetValue() or "")
            if q ~= self.Query then
                self.Query = q
                self:Apply()
            end
        end
    end

    b.Paint = function() end

    return b
end

local function GetRoot()
    if IsValid(Root) then return Root end

    local r = vgui.Create("EditablePanel")
    r:SetSize(ScrW(), ScrH())
    r:SetVisible(false)
    r:SetAlpha(0)
    r.K = 0
    r.Target = 0
    r.OpenAt = 0

    Root = r

    local bd = CreateBoard(r)
    bd.BX = math.floor((ScrW() - L.W) * 0.5)
    bd.BY = math.floor((ScrH() - L.H) * 0.5)
    bd:SetPos(bd.BX, bd.BY)
    r.Board = bd

    function r:Paint(w, h)
        Box(0, 0, w, h, 0, 0, 0, 110)
    end

    function r:OnMousePressed()
        Blur()
        Close()
    end

    function r:Think()
        self.K = math.Approach(self.K, self.Target, FrameTime() * 7)
        local e = self.K * self.K * (3 - 2 * self.K)
        self:SetAlpha(255 * e)

        local b = self.Board
        b:SetPos(b.BX, b.BY + (1 - e) * S(20))

        if self.Target == 0 and self.K <= 0 then
            self:SetVisible(false)
        end
    end

    return r
end

local function Ensure()
    if L.Scr == ScrH() and L.ScrW == ScrW() then return end
    Build()
    if IsValid(Root) then
        Root:Remove()
        Root = nil
    end
    if Data then
        for _, it in ipairs(Data.flat) do
            it.fit = nil
        end
    end
end

hook.Add("OnScreenSizeChanged", "ElysiumQ_Fonts", Ensure)

local function IsOpen()
    return IsValid(Root) and Root.Target == 1
end

local function Open()
    Ensure()
    EnsureData()

    local r = GetRoot()
    r.Target = 1
    r.OpenAt = CurTime()
    r:SetVisible(true)
    r:MakePopup()
    r:SetKeyboardInputEnabled(false)
    r:SetMouseInputEnabled(true)
    r.Board:OnOpen()
end

hook.Add("OnSpawnMenuOpen", "ElysiumQ_Open", function()
    if hook.Run("SpawnMenuOpen") == false then return true end
    if IsOpen() then
        Close()
    else
        Open()
    end
    return true
end)

hook.Add("OnSpawnMenuClose", "ElysiumQ_Close", function()
    if IsOpen() and CurTime() - Root.OpenAt >= HOLD_TIME then
        Close()
    end
    return true
end)

hook.Add("OnTextEntryGetFocus", "ElysiumQ_Focus", function(p)
    if IsValid(Root) and IsValid(p) and p:HasParent(Root) then
        Root:SetKeyboardInputEnabled(true)
    end
end)

hook.Add("OnTextEntryLoseFocus", "ElysiumQ_Unfocus", function(p)
    if IsValid(Root) and IsValid(p) and p:HasParent(Root) then
        Root:SetKeyboardInputEnabled(false)
    end
end)
