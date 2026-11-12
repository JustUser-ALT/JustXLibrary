-- ===== Sub-Places v2: список карточек с картинками + окно места (Teleport / Copy Teleport Script) =====
-- Иконки рисуются фреймами: символы вроде ◈ ➤ ❐ ✓ в шрифте Gotham отсутствуют и превращаются в квадраты
local function spIcon(kind, parent, size, color, z)
    z = z or 18
    local f = Instance.new("Frame"); f.Size = UDim2.new(0,size,0,size); f.BackgroundTransparency = 1; f.BorderSizePixel = 0; f.ZIndex = z; f.Parent = parent
    local function bar(w, h, x, y, rot)
        local b = Instance.new("Frame"); b.AnchorPoint = Vector2.new(0.5,0.5); b.Size = UDim2.new(0,w,0,h); b.Position = UDim2.new(0,x,0,y); b.Rotation = rot or 0
        b.BackgroundColor3 = color; b.BorderSizePixel = 0; b.ZIndex = z; b.Parent = f; corner(math.min(w,h) / 2, b); return b
    end
    local function ring(d, x, y, th)
        local r = Instance.new("Frame"); r.AnchorPoint = Vector2.new(0.5,0.5); r.Size = UDim2.new(0,d,0,d); r.Position = UDim2.new(0,x,0,y)
        r.BackgroundTransparency = 1; r.BorderSizePixel = 0; r.ZIndex = z; r.Parent = f; corner(d / 2, r); stroke(color, th, r); return r
    end
    local s = size
    if kind == "compass" then ring(s, s/2, s/2, 1.6); bar(2, s*0.55, s/2, s/2, 45)
    elseif kind == "pin" then ring(s*0.86, s/2, s/2, 1.6); bar(s*0.3, s*0.3, s/2, s/2, 0)
    elseif kind == "copy" then
        bar(s*0.45, 1.6, s*0.33, s*0.12, 0); bar(1.6, s*0.45, s*0.12, s*0.33, 0)
        local fr = Instance.new("Frame"); fr.Size = UDim2.new(0,s*0.58,0,s*0.58); fr.Position = UDim2.new(0,s*0.34,0,s*0.34); fr.BackgroundTransparency = 1; fr.BorderSizePixel = 0
        fr.ZIndex = z; fr.Parent = f; corner(2, fr); stroke(color, 1.6, fr)
    elseif kind == "info" then ring(s, s/2, s/2, 1.4); bar(2, 2, s/2, s*0.3, 0); bar(2, s*0.32, s/2, s*0.62, 0)
    elseif kind == "check" then bar(s*0.34, 2.2, s*0.34, s*0.58, 45); bar(s*0.7, 2.2, s*0.62, s*0.48, -50)
    elseif kind == "menu" then bar(s*0.72, 2.2, s/2, s*0.26, 0); bar(s*0.72, 2.2, s/2, s*0.5, 0); bar(s*0.72, 2.2, s/2, s*0.74, 0)
    elseif kind == "window" then
        local fr = Instance.new("Frame"); fr.Size = UDim2.new(0,s*0.86,0,s*0.68); fr.Position = UDim2.new(0,s*0.07,0,s*0.16); fr.BackgroundTransparency = 1; fr.BorderSizePixel = 0
        fr.ZIndex = z; fr.Parent = f; corner(2, fr); stroke(color, 1.5, fr); bar(s*0.78, 1.5, s/2, s*0.36, 0)
    elseif kind == "minus" then bar(s*0.62, 2.2, s/2, s/2, 0)
    end
    return f
end
local function spChev(parent, dir, color, z)
    local f = Instance.new("Frame"); f.Size = UDim2.new(0,10,0,10); f.AnchorPoint = Vector2.new(0.5,0.5); f.Position = UDim2.new(0.5,0,0.5,0)
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0; f.ZIndex = z or 18; f.Parent = parent
    local right = (dir == "right")
    for k = 1,2 do
        local b = Instance.new("Frame"); b.AnchorPoint = Vector2.new(0.5,0.5); b.Size = UDim2.new(0,7,0,2); b.Position = UDim2.new(0.5, right and -1 or 1, 0.5, (k == 1) and -2.5 or 2.5)
        b.Rotation = ((k == 1) == right) and 45 or -45; b.BackgroundColor3 = color; b.BorderSizePixel = 0; b.ZIndex = f.ZIndex; b.Parent = f; corner(1, b)
    end
    return f
end
-- Лёгкий попап без CanvasGroup: CanvasGroup перерисовывает всё окно на каждый кадр (наведение, прокрутка, ввод),
-- на телефонах это вызывало сильные фризы
local function spPopup(backdrop, w, h)
    local shell = Instance.new("Frame"); shell.AnchorPoint = Vector2.new(0.5,0.5); shell.Position = UDim2.new(0.5,0,0.5,0); shell.Size = UDim2.new(0,w,0,h)
    shell.BackgroundColor3 = C.panel; shell.BorderSizePixel = 0; shell.Parent = backdrop; corner(16, shell); stroke(C.border, 1, shell)
    local sc = Instance.new("UIScale"); sc.Parent = shell
    local function fit()
        local cam = workspace.CurrentCamera
        local v = cam and cam.ViewportSize or Vector2.new(1280,720)
        return math.min(1, (v.Y * 0.94) / h, (v.X * 0.96) / w)
    end
    local base = fit(); sc.Scale = base * 0.94
    local function show() base = fit(); sc.Scale = base * 0.94; tw(backdrop,{BackgroundTransparency = 0.45},.2); tw(sc,{Scale = base},.3,Enum.EasingStyle.Quint) end
    local function hide() tw(backdrop,{BackgroundTransparency = 1},.15); tw(sc,{Scale = base * 0.94},.15) end
    return shell, shell, show, hide
end
local function spInitial(name)
    local s = tostring(name or "?"):gsub("^%s+", "")
    local ok,ch = pcall(function() return utf8.char(utf8.codepoint(s, 1)) end)
    if ok and ch and ch ~= "" then return ch:upper() end
    return "?"
end
local function spColor(name)
    local h, s = 0, tostring(name or "")
    for i = 1,#s do h = (h * 31 + s:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.45, 0.55)
end
-- картинка места: градиент с буквой, поверх плавно проявляется иконка, когда она загрузится
local function spThumb(parent, pl, radius)
    local base = spColor(pl.name)
    local holder = Instance.new("Frame"); holder.Size = UDim2.new(1,0,1,0); holder.BackgroundColor3 = base; holder.BorderSizePixel = 0
    holder.ClipsDescendants = true; holder.Parent = parent; corner(radius, holder); holder:SetAttribute("JLNoRepaint", true)
    local g = Instance.new("UIGradient"); g.Rotation = 125; g.Color = ColorSequence.new(base:Lerp(Color3.new(1,1,1),0.12), base:Lerp(Color3.new(0,0,0),0.45)); g.Parent = holder
    local letter = newTxt({Parent=holder,Text=spInitial(pl.name),Font=GB,Size=34,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center,Z=2})
    letter.TextTransparency = 0.35
    local img = Instance.new("ImageLabel"); img.Size = UDim2.new(1,0,1,0); img.BackgroundTransparency = 1; img.ScaleType = Enum.ScaleType.Crop
    img.ImageTransparency = 1; img.ZIndex = 3; img.Parent = holder; img:SetAttribute("JLNoRepaint", true)
    local function setImage(asset)
        if not asset or not img.Parent then return end
        img.Image = asset
        tw(img,{ImageTransparency = 0},.35); tw(letter,{TextTransparency = 1},.35)
    end
    return holder, setImage
end
local spPlayersCache = {}
local function buildSubPlacesUI(universeId, places)
    local CoreGui = game:GetService("CoreGui")
    local sgP = registerHubGui(Instance.new("ScreenGui"), "SubPlaces"); sgP.ResetOnSpawn = false; sgP.IgnoreGuiInset = true; sgP.DisplayOrder = 1000
    local okp = pcall(function() sgP.Parent = CoreGui end); if not okp or not sgP.Parent then sgP.Parent = PG end
    local alive = true
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sgP
    local W, H = 540, 410
    local shell,card,showPopup,hidePopup = spPopup(bd, W, H)
    mkTopBar(card, ACCENTS[1])
    local HDR = 52
    local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,HDR); hdr.Position = UDim2.new(0,0,0,3); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = card; corner(14, hdr)
    local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    local hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,1,0); hline.BackgroundColor3 = C.divLine; hline.BorderSizePixel = 0; hline.ZIndex = 3; hline.Parent = hdr
    local hicon = spIcon("compass", hdr, 24, ACCENTS[1], 4); hicon.Position = UDim2.new(0,16,0.5,-12)
    local backBtn = Instance.new("TextButton"); backBtn.Size = UDim2.new(0,30,0,30); backBtn.Position = UDim2.new(0,10,0.5,-15); backBtn.BackgroundColor3 = C.btnBg; backBtn.BorderSizePixel = 0
    backBtn.Text = ""; backBtn.AutoButtonColor = false; backBtn.Visible = false; backBtn.ZIndex = 5; backBtn.Parent = hdr
    corner(8, backBtn); stroke(C.border, 1, backBtn); spChev(backBtn, "left", C.txt, 6)
    local titleL = newTxt({Parent=hdr,Text="Sub-Places",Font=GB,Size=15,Sz=UDim2.new(1,-110,0,20),Pos=UDim2.new(0,52,0,8),Z=4})
    local subL = newTxt({Parent=hdr,Text=#places .. " place" .. (#places == 1 and "" or "s") .. " in this experience",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-110,0,14),Pos=UDim2.new(0,52,0,28),Z=4})
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0,28,0,28); closeBtn.Position = UDim2.new(1,-40,0.5,-14); closeBtn.BackgroundColor3 = C.btnBg; closeBtn.BorderSizePixel = 0
    closeBtn.Text = ""; closeBtn.AutoButtonColor = false; closeBtn.ZIndex = 5; closeBtn.Parent = hdr; corner(8, closeBtn); stroke(C.border, 1, closeBtn)
    local xl = {}
    for _,rot in ipairs({45,-45}) do
        local l = Instance.new("Frame"); l.AnchorPoint = Vector2.new(0.5,0.5); l.Position = UDim2.new(0.5,0,0.5,0); l.Size = UDim2.new(0,12,0,2); l.Rotation = rot
        l.BackgroundColor3 = C.dim; l.BorderSizePixel = 0; l.ZIndex = 6; l.Parent = closeBtn; corner(1, l); xl[#xl + 1] = l
    end
    closeBtn.MouseEnter:Connect(function() if not touchLast() then for _,l in ipairs(xl) do tw(l,{BackgroundColor3 = C.danger},.12) end end end)
    closeBtn.MouseLeave:Connect(function() for _,l in ipairs(xl) do tw(l,{BackgroundColor3 = C.dim},.12) end end)
    local function closePopup()
        alive = false
        hidePopup()
        trackedDelay(.18, function() sgP:Destroy() end)
    end
    closeBtn.MouseButton1Click:Connect(closePopup)

    local body = Instance.new("Frame"); body.Position = UDim2.new(0,0,0,HDR + 3); body.Size = UDim2.new(1,0,1,-(HDR + 3)); body.BackgroundTransparency = 1; body.BorderSizePixel = 0
    body.ClipsDescendants = true; body.Parent = card
    local listPage = Instance.new("Frame"); listPage.Size = UDim2.new(1,0,1,0); listPage.BackgroundTransparency = 1; listPage.BorderSizePixel = 0; listPage.Parent = body
    local detailPage = Instance.new("Frame"); detailPage.Size = UDim2.new(1,0,1,0); detailPage.Position = UDim2.new(1,0,0,0); detailPage.BackgroundTransparency = 1
    detailPage.BorderSizePixel = 0; detailPage.Visible = false; detailPage.Parent = body

    -- иконки мест: сначала то, что есть сразу (иконка игры для текущего места), потом настоящие иконки мест
    local setters, assets = {}, {}
    local function applyAsset(id, asset)
        id = tostring(id); assets[id] = asset
        for _,fn in ipairs(setters[id] or {}) do pcall(fn, asset) end
    end
    local function thumbFor(parent, pl, radius)
        local holder,setImage = spThumb(parent, pl, radius)
        local id = tostring(pl.id)
        setters[id] = setters[id] or {}
        table.insert(setters[id], setImage)
        if assets[id] then setImage(assets[id]) end
        return holder
    end

    -- ===== список =====
    local searchBox = Instance.new("Frame"); searchBox.Size = UDim2.new(1,-28,0,30); searchBox.Position = UDim2.new(0,14,0,10); searchBox.BackgroundColor3 = C.input; searchBox.BorderSizePixel = 0; searchBox.Parent = listPage
    corner(8, searchBox); stroke(C.border, 1, searchBox)
    local lens = Instance.new("Frame"); lens.Size = UDim2.new(0,11,0,11); lens.Position = UDim2.new(0,11,0,9); lens.BackgroundTransparency = 1; lens.Parent = searchBox; corner(6, lens); stroke(C.dim, 1.5, lens)
    local lh = Instance.new("Frame"); lh.Size = UDim2.new(0,6,0,2); lh.Position = UDim2.new(0,19,0,20); lh.Rotation = 45; lh.BackgroundColor3 = C.dim; lh.BorderSizePixel = 0; lh.Parent = searchBox
    local search = Instance.new("TextBox"); search.Size = UDim2.new(1,-90,1,0); search.Position = UDim2.new(0,32,0,0); search.BackgroundTransparency = 1; search.Font = G; search.TextSize = 12
    search.TextColor3 = C.txt; search.PlaceholderText = "Search places..."; search.PlaceholderColor3 = C.dim; search.Text = ""; search.ClearTextOnFocus = false
    search.TextXAlignment = Enum.TextXAlignment.Left; search.Parent = searchBox
    local countL = newTxt({Parent=searchBox,Text="",Font=GM,Size=10,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,52,1,0),Pos=UDim2.new(1,-60,0,0)})

    local gridSc = Instance.new("ScrollingFrame"); gridSc.Position = UDim2.new(0,0,0,48); gridSc.Size = UDim2.new(1,0,1,-48); gridSc.BackgroundTransparency = 1; gridSc.BorderSizePixel = 0
    gridSc.ScrollBarThickness = 4; gridSc.ScrollBarImageColor3 = C.border; gridSc.CanvasSize = UDim2.new(0,0,0,0); gridSc.Parent = listPage
    local usable = W - 28 - 6
    local GAPC = 10
    local cols = 3
    local cw = math.floor((usable - GAPC * (cols - 1)) / cols)
    local grid = Instance.new("UIGridLayout"); grid.CellSize = UDim2.new(0,cw,0,150); grid.CellPadding = UDim2.new(0,GAPC,0,GAPC); grid.SortOrder = Enum.SortOrder.LayoutOrder; grid.Parent = gridSc
    pad(14,8,6,14,gridSc)
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() gridSc.CanvasSize = UDim2.new(0,0,0,grid.AbsoluteContentSize.Y + 22) end)
    local emptyL = newTxt({Parent=listPage,Text="No places found.",Font=GM,Size=12,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,0,24),Pos=UDim2.new(0,0,0,110)})
    emptyL.Visible = false
    showPopup()

    local showDetail
    local cards = {}
    local cardBuildStarted = os.clock()
    for i,pl in ipairs(places) do
        local isCur = (tostring(pl.id) == tostring(game.PlaceId))
        local cf = Instance.new("Frame"); cf.BackgroundColor3 = C.badge; cf.BorderSizePixel = 0; cf.LayoutOrder = i; cf.Parent = gridSc; corner(10, cf)
        local st = stroke(isCur and ACCENTS[1] or C.border, isCur and 1.5 or 1, cf)
        local imgBox = Instance.new("Frame"); imgBox.Size = UDim2.new(1,-12,0,92); imgBox.Position = UDim2.new(0,6,0,6); imgBox.BackgroundTransparency = 1; imgBox.Parent = cf
        thumbFor(imgBox, pl, 7)
        if isCur then
            local ck = Instance.new("Frame"); ck.Size = UDim2.new(0,20,0,20); ck.Position = UDim2.new(1,-26,0,6); ck.BackgroundColor3 = ACCENTS[1]; ck.BorderSizePixel = 0; ck.ZIndex = 8; ck.Parent = imgBox; corner(10, ck)
            local cki = spIcon("check", ck, 12, Color3.new(1,1,1), 9); cki.Position = UDim2.new(0.5,-6,0.5,-6)
        end
        newTxt({Parent=cf,Text=pl.name or ("Place " .. tostring(pl.id)),Font=GB,Size=12,Sz=UDim2.new(1,-20,0,16),Pos=UDim2.new(0,10,0,104)})
        newTxt({Parent=cf,Text=isCur and "Current location" or ("ID " .. tostring(pl.id)),Font=GM,Size=10,Color=isCur and ACCENTS[1] or C.dim,Sz=UDim2.new(1,-20,0,14),Pos=UDim2.new(0,10,0,122)})
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.AutoButtonColor = false; btn.ZIndex = 30; btn.Parent = cf
        btn.MouseEnter:Connect(function()
            if touchLast() then return end
            tw(cf,{BackgroundColor3 = C.btnBg},.15); if not isCur then tw(st,{Color = C.dim},.15) end
        end)
        btn.MouseLeave:Connect(function()
            tw(cf,{BackgroundColor3 = C.badge},.15); if not isCur then tw(st,{Color = C.border},.15) end
        end)
        btn.MouseButton1Click:Connect(function() showDetail(pl) end)
        cards[#cards + 1] = {frame = cf, pl = pl}
        if i % 6 == 0 and i < #places then task.wait() end
    end
    if JL._perfEnabled then
        warn("[JustLib Perf] Sub-Places cards: " .. tostring(#cards) .. " cards in " .. string.format("%.3f s", os.clock() - cardBuildStarted))
    end
    local function applySearch()
        local q = search.Text:lower()
        local n = 0
        for _,c in ipairs(cards) do
            local hay = (tostring(c.pl.name or "") .. " " .. tostring(c.pl.id)):lower()
            local ok = q == "" or hay:find(q, 1, true) ~= nil
            c.frame.Visible = ok
            if ok then n = n + 1 end
        end
        countL.Text = n .. "/" .. #cards
        emptyL.Visible = (#cards > 0 and n == 0) or #cards == 0
        emptyL.Text = (#cards == 0) and "No places found." or "No matches."
    end
    search:GetPropertyChangedSignal("Text"):Connect(applySearch)
    applySearch()

    -- ===== окно места =====
    local view = "list"
    local curPl
    local function slide(toDetail)
        view = toDetail and "detail" or "list"
        local info = TweenInfo.new(.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        if toDetail then
            detailPage.Visible = true; detailPage.Position = UDim2.new(0.14,0,0,0)
            createTween(detailPage, info, {Position = UDim2.new(0,0,0,0)}):Play()
            createTween(listPage, info, {Position = UDim2.new(-0.14,0,0,0)}):Play()
            backBtn.Visible = true; hicon.Visible = false
        else
            listPage.Visible = true
            createTween(listPage, info, {Position = UDim2.new(0,0,0,0)}):Play()
            createTween(detailPage, info, {Position = UDim2.new(0.14,0,0,0)}):Play()
            backBtn.Visible = false; hicon.Visible = true
            titleL.Text = "Sub-Places"; subL.Text = #places .. " place" .. (#places == 1 and "" or "s") .. " in this experience"
        end
        local mark = view
        trackedDelay(.4, function()
            if not alive or view ~= mark then return end
            if toDetail then listPage.Visible = false else detailPage.Visible = false end
        end)
    end
    backBtn.MouseButton1Click:Connect(function() if view == "detail" then slide(false) end end)
    backBtn.MouseEnter:Connect(function() if not touchLast() then tw(backBtn,{BackgroundColor3 = C.btnHov},.12) end end)
    backBtn.MouseLeave:Connect(function() tw(backBtn,{BackgroundColor3 = C.btnBg},.12) end)

    local function spButton(parent, y, text, iconKind, primary)
        local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,38); b.Position = UDim2.new(0,0,0,y)
        b.BackgroundColor3 = primary and ACCENTS[1] or C.btnBg; b.BorderSizePixel = 0; b.Text = ""; b.AutoButtonColor = false; b.Parent = parent
        corner(9, b); local st = stroke(primary and ACCENTS[1] or C.border, 1, b)
        local ic = spIcon(iconKind, b, 16, primary and Color3.new(1,1,1) or ACCENTS[1], 5); ic.Position = UDim2.new(0,14,0.5,-8)
        local lbl = newTxt({Parent=b,Text=text,Font=GB,Size=12,Color=primary and Color3.new(1,1,1) or C.txt,Sz=UDim2.new(1,-62,1,0),Pos=UDim2.new(0,40,0,0),Z=5})
        local ch = spChev(b, "right", primary and Color3.new(1,1,1) or C.dim, 5); ch.Position = UDim2.new(1,-20,0.5,0)
        local rest = b.BackgroundColor3
        b.MouseEnter:Connect(function()
            if touchLast() or b:GetAttribute("off") then return end
            tw(b,{BackgroundColor3 = primary and rest:Lerp(Color3.new(1,1,1),0.14) or C.btnHov},.12)
        end)
        b.MouseLeave:Connect(function() tw(b,{BackgroundColor3 = rest},.12) end)
        return b, lbl, ic, ch
    end

    local function loadPlayers(pl, label, force)
        local id = tostring(pl.id)
        local e = spPlayersCache[id]
        if e and not force and os.clock() - e.t < 60 then label.Text = e.text; return end
        label.Text = "..."
        trackedSpawn(function()
            local total, cursor, pages, truncated = 0, "", 0, false
            for _ = 1,4 do
                local res = execRequest({Url = "https://games.roblox.com/v1/games/" .. id .. "/servers/Public?limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or ""), Method = "GET"})
                local ok,data = false,nil
                if res and res.Body then ok,data = pcall(HTTP.JSONDecode, HTTP, res.Body) end
                if not ok or type(data) ~= "table" or type(data.data) ~= "table" then
                    if pages == 0 then if label.Parent then label.Text = "-" end; return end
                    break
                end
                for _,s in ipairs(data.data) do total = total + (tonumber(s.playing) or 0) end
                pages = pages + 1
                cursor = data.nextPageCursor
                if not cursor or cursor == "" then break end
                if pages == 4 then truncated = true end
            end
            local text = tostring(total) .. (truncated and "+" or "")
            spPlayersCache[id] = {t = os.clock(), text = text}
            if label.Parent and curPl == pl then label.Text = text end
        end)
    end

    showDetail = function(pl)
        curPl = pl
        for _,ch in ipairs(detailPage:GetChildren()) do ch:Destroy() end
        local isCur = (tostring(pl.id) == tostring(game.PlaceId))
        titleL.Text = pl.name or ("Place " .. tostring(pl.id))
        subL.Text = isCur and "You are here" or ("Place ID " .. tostring(pl.id))
        -- слева: картинка и две «таблетки»
        local imgBox = Instance.new("Frame"); imgBox.Size = UDim2.new(0,232,0,170); imgBox.Position = UDim2.new(0,16,0,16); imgBox.BackgroundTransparency = 1; imgBox.Parent = detailPage
        thumbFor(imgBox, pl, 12); stroke(C.border, 1, imgBox); corner(12, imgBox)
        if isCur then
            local tag = Instance.new("Frame"); tag.Size = UDim2.new(0,104,0,22); tag.Position = UDim2.new(0,8,0,8); tag.BackgroundColor3 = ACCENTS[1]; tag.BorderSizePixel = 0; tag.ZIndex = 8; tag.Parent = imgBox; corner(11, tag)
            local tci = spIcon("check", tag, 10, Color3.new(1,1,1), 9); tci.Position = UDim2.new(0,10,0.5,-5)
            newTxt({Parent=tag,Text="You are here",Font=GB,Size=10,Color=Color3.new(1,1,1),Sz=UDim2.new(1,-24,1,0),Pos=UDim2.new(0,24,0,0),Z=9})
        end
        local function chip(y, label, value, onClick)
            local c = Instance.new("TextButton"); c.Size = UDim2.new(0,232,0,28); c.Position = UDim2.new(0,16,0,y); c.BackgroundColor3 = C.badge; c.BorderSizePixel = 0; c.Text = ""; c.AutoButtonColor = false; c.Parent = detailPage
            corner(8, c); stroke(C.border, 1, c)
            newTxt({Parent=c,Text=label,Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(0.5,0,1,0),Pos=UDim2.new(0,10,0,0),Z=5})
            local v = newTxt({Parent=c,Text=value,Font=GB,Size=11,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0.5,-10,1,0),Pos=UDim2.new(0.5,0,0,0),Z=5})
            c.MouseEnter:Connect(function() if not touchLast() then tw(c,{BackgroundColor3 = C.btnBg},.12) end end)
            c.MouseLeave:Connect(function() tw(c,{BackgroundColor3 = C.badge},.12) end)
            c.MouseButton1Click:Connect(function() onClick(v) end)
            return v
        end
        chip(196, "Place ID", tostring(pl.id), function(v)
            if setclipboard then
                setclipboard(tostring(pl.id)); v.Text = "Copied!"
                trackedDelay(1.2, function() if v.Parent then v.Text = tostring(pl.id) end end)
            else JL:Notify({Title = "Copy", Desc = "Clipboard unsupported", Type = "Error", Duration = 3}) end
        end)
        local pv = chip(230, "Players online", "...", function(v) loadPlayers(pl, v, true) end)
        loadPlayers(pl, pv, false)
        -- справа: название, описание, кнопки
        local nm = newTxt({Parent=detailPage,Text=pl.name or ("Place " .. tostring(pl.id)),Font=GB,Size=18,Wrap=true,Sz=UDim2.new(0,260,0,46),Pos=UDim2.new(0,264,0,14)})
        nm.TextYAlignment = Enum.TextYAlignment.Top
        local desc = tostring(pl.description or "")
        if desc == "" then desc = "No description." end
        local dsc = Instance.new("ScrollingFrame"); dsc.Size = UDim2.new(0,260,0,108); dsc.Position = UDim2.new(0,264,0,66); dsc.BackgroundTransparency = 1; dsc.BorderSizePixel = 0
        dsc.ScrollBarThickness = 3; dsc.ScrollBarImageColor3 = C.border; dsc.CanvasSize = UDim2.new(0,0,0,0); dsc.Parent = detailPage
        local dh = fitH(desc, 12, GM, 250, 16, 4)
        local dl = newTxt({Parent=dsc,Text=desc,Font=GM,Size=12,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-8,0,dh),Pos=UDim2.new(0,0,0,0)})
        dl.TextYAlignment = Enum.TextYAlignment.Top
        dsc.CanvasSize = UDim2.new(0,0,0,dh + 4)
        local btnHost = Instance.new("Frame"); btnHost.Size = UDim2.new(0,260,0,84); btnHost.Position = UDim2.new(0,264,0,186); btnHost.BackgroundTransparency = 1; btnHost.Parent = detailPage
        local tp, tpLbl = spButton(btnHost, 0, isCur and "You are here" or "Teleport", "pin", true)
        if isCur then tp.BackgroundTransparency = 0.55; tp.AutoButtonColor = false; tp:SetAttribute("off", true) end
        local busy = false
        tp.MouseButton1Click:Connect(function()
            if isCur or busy then return end
            busy = true; tpLbl.Text = "Teleporting..."
            local ok = pcall(function() game:GetService("TeleportService"):Teleport(pl.id, LP) end)
            if not ok then
                JL:Notify({Title = "Teleport", Desc = "Teleport failed", Type = "Error", Duration = 4})
            end
            trackedDelay(4, function() busy = false; if tpLbl.Parent then tpLbl.Text = "Teleport" end end)
        end)
        local cp, cpLbl = spButton(btnHost, 46, "Copy Teleport Script", "copy", false)
        cp.MouseButton1Click:Connect(function()
            if setclipboard then
                setclipboard('game:GetService("TeleportService"):Teleport(' .. tostring(pl.id) .. ', game.Players.LocalPlayer)')
                cpLbl.Text = "Copied!"
                JL:Notify({Title = "Copied", Desc = "Teleport script copied", Type = "Success", Duration = 3})
                trackedDelay(1.4, function() if cpLbl.Parent then cpLbl.Text = "Copy Teleport Script" end end)
            else
                JL:Notify({Title = "Copy", Desc = "Clipboard unsupported", Type = "Error", Duration = 3})
            end
        end)
        -- нижняя подпись
        local fl = Instance.new("Frame"); fl.Size = UDim2.new(1,-32,0,1); fl.Position = UDim2.new(0,16,0,282); fl.BackgroundColor3 = C.divLine; fl.BorderSizePixel = 0; fl.Parent = detailPage
        local sh = spIcon("info", detailPage, 14, C.dim, 4); sh.Position = UDim2.new(0,16,0,298)
        newTxt({Parent=detailPage,Text=isCur and "You are already in this place." or "Teleporting will move you to the selected sub place.",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-60,0,16),Pos=UDim2.new(0,38,0,297)})
        slide(true)
    end

    -- настоящие иконки мест: Roblox thumbnails -> файл -> getcustomasset (если executor умеет); иначе остаётся градиент с буквой
    pcall(function()
        for _,pl in ipairs(places) do
            if tostring(pl.id) == tostring(game.PlaceId) then
                applyAsset(pl.id, "rbxthumb://type=GameIcon&id=" .. tostring(universeId) .. "&w=256&h=256")
            end
        end
    end)
    -- Для остальных мест оставляем локальный градиент с первой буквой.
    -- Не скачиваем миниатюры через executor request: синхронный HTTP может
    -- заморозить весь клиент даже из task.spawn/task.delay.
end
local function openSubPlaces(universeId)
    local hasReq = typeof(request) == "function" or typeof(http_request) == "function" or (syn and typeof(syn.request) == "function")
    if not hasReq then
        JL:Notify({Title = "Sub-Places", Desc = "Your executor doesn't support cross-origin requests", Type = "Error", Duration = 4})
        return
    end
    JL:Notify({Title = "Sub-Places", Desc = "Fetching place list...", Type = "Info", Duration = 2})
    trackedSpawn(function()
        local fetchStarted = os.clock()
        local places, cursor = {}, ""
        for _ = 1,3 do
            local res = execRequest({Url = "https://develop.roblox.com/v1/universes/" .. universeId .. "/places?sortOrder=Asc&limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or ""), Method = "GET"})
            if not res or not res.Body then
                if #places == 0 then JL:Notify({Title = "Sub-Places", Desc = "Could not fetch the place list", Type = "Error", Duration = 4}); return end
                break
            end
            local ok,data = pcall(HTTP.JSONDecode, HTTP, res.Body)
            if not ok or type(data) ~= "table" or not data.data then
                if #places == 0 then JL:Notify({Title = "Sub-Places", Desc = "Unexpected response from Roblox", Type = "Error", Duration = 4}); return end
                break
            end
            for _,pl in ipairs(data.data) do places[#places + 1] = pl end
            cursor = data.nextPageCursor
            if not cursor or cursor == "" then break end
        end
        if JL._perfEnabled then
            warn("[JustLib Perf] Sub-Places fetch: " .. tostring(#places) .. " places in " .. string.format("%.3f s", os.clock() - fetchStarted))
        end
        local uiStarted = os.clock()
        local ok,err = pcall(buildSubPlacesUI, universeId, places)
        if JL._perfEnabled then
            warn("[JustLib Perf] Sub-Places UI total: " .. string.format("%.3f s", os.clock() - uiStarted))
        end
        if not ok then
            JL:Notify({Title = "Sub-Places", Desc = "UI error: " .. tostring(err), Type = "Error", Duration = 5})
            local g = (PG and PG:FindFirstChild("JLSubPlaces")) or game:GetService("CoreGui"):FindFirstChild("JLSubPlaces")
            if g then g:Destroy() end
        end
    end)
end
