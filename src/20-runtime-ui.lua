-- ===== Preview UI bridge (PreviewUI.lua берёт отсюда темы, конфиг и хуки Unload) =====
JL._extraRoots = {}; JL._themeHooks = {}; JL._unloadHooks = {}
JL._streamerMode = false
local streamerRecords = setmetatable({}, {__mode = "k"})
local streamerConnections = {}
local function streamerNames()
    local names, seen = {}, {}
    for _,name in ipairs({LP.Name, LP.DisplayName}) do
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    table.sort(names, function(a,b) return #a > #b end)
    return names
end
local function streamerMaskText(value)
    if type(value) ~= "string" or value == "" then return value end
    local names = streamerNames()
    for _,name in ipairs(names) do
        local charCount = #name
        if utf8 and utf8.len then
            local ok,count = pcall(utf8.len, name)
            if ok and count then charCount = count end
        end
        local replacement = string.rep("#", charCount)
        local parts, position = {}, 1
        while true do
            local first,last = string.find(value, name, position, true)
            if not first then
                parts[#parts + 1] = string.sub(value, position)
                break
            end
            parts[#parts + 1] = string.sub(value, position, first - 1)
            parts[#parts + 1] = replacement
            position = last + 1
        end
        value = table.concat(parts)
    end
    return value
end
local function streamerWatch(obj)
    if not JL._streamerMode or not obj or streamerRecords[obj] then return end
    local isText = false
    pcall(function()
        isText = obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
    end)
    if not isText then return end
    local record = {original = obj.Text, masked = nil, writing = false}
    streamerRecords[obj] = record
    local function apply()
        if record.writing then return end
        local current
        local ok = pcall(function() current = obj.Text end)
        if not ok then return end
        record.original = current
        local masked = streamerMaskText(current)
        record.masked = masked
        if masked ~= current then
            record.writing = true
            pcall(function() obj.Text = masked end)
            record.writing = false
        end
    end
    local ok,connection = pcall(function()
        return obj:GetPropertyChangedSignal("Text"):Connect(apply)
    end)
    if ok and connection then record.connection = connection end
    apply()
end
local function streamerStop()
    for _,connection in ipairs(streamerConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(streamerConnections)
    for obj,record in pairs(streamerRecords) do
        if record.connection then pcall(function() record.connection:Disconnect() end) end
        pcall(function()
            if obj.Parent and record.masked ~= nil and obj[record.property] == record.masked then
                obj[record.property] = record.original
            end
        end)
        streamerRecords[obj] = nil
    end
end
function JL:SetStreamerMode(enabled)
    enabled = enabled == true
    if JL._streamerMode == enabled then return true end
    JL._streamerMode = enabled
    if not enabled then
        streamerStop()
        return true
    end
    local ok,descendants = pcall(function() return game:GetDescendants() end)
    if ok then
        for _,obj in ipairs(descendants) do streamerWatch(obj) end
    end
    local added
    pcall(function()
        added = game.DescendantAdded:Connect(streamerWatch)
    end)
    if added then streamerConnections[#streamerConnections + 1] = added end
    return true
end
function JL:GetStreamerMode()
    return JL._streamerMode == true
end
table.insert(JL._unloadHooks, function()
    JL._streamerMode = false
    streamerStop()
end)

JL._remoteAttach = function() end -- заменяется, когда создаётся окно (Remote)
JL._bridge = {
    C = C, ACCENTS = ACCENTS, cfgGet = cfgGet, cfgSet = cfgSet, cfgHas = cfgHas,
    keep = keep, tw = tw, icon = resolveIcon,
    track = function(resource, cleanup) return JL:Track(resource, cleanup) end,
    connect = function(signal, callback) return JL:Connect(signal, callback) end,
    spawn = trackedSpawn, delay = trackedDelay, defer = trackedDefer,
    isAlive = function() return not _disposed end,
    registry = JL._registry, noSave = JL._noSave, flags = JL.Flags,
    extraRoots = JL._extraRoots, themeHooks = JL._themeHooks, unloadHooks = JL._unloadHooks,
    notify = function(c) return JL:Notify(c) end,
    isListening = function() return JL._listening end,
    onDestroyed = function(obj) if JL._preview == obj then JL._preview = nil end end,
}
do
    local CoreGui = game:GetService("CoreGui")
    shared._JLNotifs = shared._JLNotifs or {}
    local active = shared._JLNotifs
    local W,H = 200,55
    local MARGIN = 14
    local GAP = 72.5
    local function notifySide() return tostring(cfgGet("_notify_side","TopRight")) end
    local function edgeXY(side)
        local camObj = workspace.CurrentCamera
        local vp = camObj and camObj.ViewportSize or Vector2.new(1280,720)
        local top = (side == "TopLeft" or side == "TopRight")
        local left = (side == "TopLeft" or side == "BottomLeft")
        local x = left and MARGIN or (vp.X - W - MARGIN)
        local yBase = top and MARGIN or (vp.Y - H - MARGIN)
        return x, yBase, top, left
    end
    local function updPos()
        local x = edgeXY(notifySide())
        local top = (notifySide() == "TopLeft" or notifySide() == "TopRight")
        local camObj = workspace.CurrentCamera
        local vpY = camObj and camObj.ViewportSize.Y or 720
        local off = 0
        for k = #active, 1, -1 do
            local nd = active[k]
            if nd and nd.f then
                local y = top and (MARGIN + off) or (vpY - MARGIN - nd.h - off)
                tw(nd.f,{Position = UDim2.new(0,x,0,y)},.35,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)
                off = off + nd.h + 17.5
            end
        end
    end
    JL._notifyReposition = updPos
    local function typeAllowed(typ)
        if typ == "Warn" then return cfgGet("_notify_show_warning", true) end
        if typ == "Error" then return cfgGet("_notify_show_error", true) end
        return cfgGet("_notify_show_regular", true)
    end
    function JL:Notify(cfg2)
        if _disposed then return false end
        cfg2 = cfg2 or {}
        local typ = cfg2.Type or "Info"
        if not typeAllowed(typ) then return end
        local title = cfg2.Title or "JustLib"; local desc = cfg2.Desc or ""
        local dur = cfg2.Duration or tonumber(cfgGet("_notify_duration",5)) or 5
        local col=Color3.fromRGB(158,198,255); local ico="rbxassetid://70718918423383"
        if typ=="Error" then col=Color3.fromRGB(255,82,82); ico="rbxassetid://113114601887005"
        elseif typ=="Success" then col=Color3.fromRGB(145,255,128); ico="rbxassetid://18567015051"
        elseif typ=="Warn" then col=Color3.fromRGB(255,225,117); ico="rbxassetid://14863060512" end
        if cfgGet("_notify_stack", false) then
            for _,nd in ipairs(active) do
                if nd and not nd.closing and nd.title == title and nd.desc == desc and nd.typ == typ then
                    nd.count = nd.count + 1
                    if nd.countLbl then nd.countLbl.Text = "x" .. nd.count; nd.countLbl.Visible = true end
                    nd.restart(dur)
                    return
                end
            end
        end
        local side = notifySide()
        local x, yBase, top, left = edgeXY(side)
        local startX = left and (x - 260) or (x + 260)
        local titleH = math.max(20, math.min(TextService:GetTextSize(title, 14, GB, Vector2.new(116,200)).Y, 56))
        local descH = (desc == "") and 2 or math.max(14, math.min(TextService:GetTextSize(desc, 10, G, Vector2.new(180,2000)).Y + 2, 240))
        local barY = 2 + titleH + descH
        local h = barY + 5
        local camObj = workspace.CurrentCamera
        local vpY = camObj and camObj.ViewportSize.Y or 720
        local startY = top and MARGIN or (vpY - MARGIN - h)
        local sg2=registerHubGui(Instance.new("ScreenGui"), "Notif"); sg2.Parent=CoreGui; sg2.ClipToDeviceSafeArea=false; sg2.ResetOnSpawn=false
        local f=Instance.new("Frame"); f.BorderSizePixel=0; f.BackgroundColor3=Color3.fromRGB(0,0,0); f.Size=UDim2.new(0,W,0,h); f.Position=UDim2.new(0,startX,0,startY); f.Parent=sg2; corner(8,f)
        f:SetAttribute("JLNoRepaint", true)
        local te=Instance.new("Frame"); te.ZIndex=0; te.BorderSizePixel=0; te.BackgroundColor3=col; te.Size=UDim2.new(0,20,0,h); te.Position=UDim2.new(0,-3,0,0); te.Parent=f; corner(8,te)
        local ti=Instance.new("ImageLabel"); ti.BorderSizePixel=0; ti.BackgroundTransparency=1; ti.ImageColor3=col; ti.Image=ico; ti.Size=UDim2.new(0,15,0,15); ti.Position=UDim2.new(0,3,0,3); ti.Parent=f
        local titleLbl = newTxt({Parent=f,Text=title,Font=GB,Size=14,Color=Color3.new(1,1,1),Wrap=true,Sz=UDim2.new(0,116,0,titleH),Pos=UDim2.new(0,22,0,2),Z=5})
        titleLbl:SetAttribute("JLNoRepaint", true)
        local countLbl = newTxt({Parent=f,Text="",Font=GB,Size=12,Color=col,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,24,0,20),Pos=UDim2.new(1,-52,0,2),Z=5})
        countLbl.Visible = false
        local td=newTxt({Parent=f,Text=desc,Size=10,Color=Color3.new(1,1,1),Sz=UDim2.new(0,180,0,descH),Pos=UDim2.new(0,10,0,2 + titleH),Z=5,Wrap=true}); td.TextTransparency=0.25
        td.TextYAlignment = Enum.TextYAlignment.Top
        td:SetAttribute("JLNoRepaint", true)
        local db=Instance.new("Frame"); db.BorderSizePixel=0; db.BackgroundColor3=col; db.Size=UDim2.new(0,180,0,3); db.Position=UDim2.new(0,10,0,barY); db.BackgroundTransparency=0.2; db.Parent=f; corner(2,db)
        local cb=Instance.new("TextButton"); cb.BorderSizePixel=0; cb.BackgroundTransparency=1; cb.TextSize=14; cb.Font=GB; cb.TextColor3=Color3.new(1,1,1); cb.ZIndex=6; cb.Size=UDim2.new(0,20,0,20); cb.Position=UDim2.new(1,-22,0,2); cb.Text="x"; cb.Parent=f
        cb:SetAttribute("JLNoRepaint", true)
        local nd = {f=f, g=sg2, HubId=Workspace.GetCurrentHubId(), title=title, desc=desc, typ=typ, count=1, countLbl=countLbl, db=db, closing=false, h=h, gen=0}
        table.insert(active,nd)
        local function close()
            if nd.closing then return end; nd.closing=true
            if nd.barTw then nd.barTw:Cancel() end
            for i,v in ipairs(active) do if v==nd then table.remove(active,i); break end end
            updPos()
            if f and f.Parent then
                local exitX = left and (x - 260) or (x + 260)
                local t2=createTween(f,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Position=UDim2.new(0,exitX,0,f.Position.Y.Offset)}); t2:Play(); t2.Completed:Connect(function() sg2:Destroy() end)
            end
        end
        nd.close = close
        function nd.restart(d)
            nd.gen = nd.gen + 1
            local gen = nd.gen
            if nd.barTw then nd.barTw:Cancel() end
            db.Size = UDim2.new(0,180,0,3)
            local tween = createTween(db, TweenInfo.new(d,Enum.EasingStyle.Linear), {Size = UDim2.new(0,0,0,3)})
            nd.barTw = tween
            tween.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed and nd.gen == gen and not nd.closing then close() end
            end)
            tween:Play()
        end
        cb.MouseButton1Click:Connect(close)
        updPos()
        trackedDelay(.35, function() if not nd.closing and nd.gen == 0 then nd.restart(dur) end end)
    end
    table.insert(JL._unloadHooks, function()
        for i = #active, 1, -1 do
            local nd = active[i]
            if nd and nd.HubId == Workspace.GetCurrentHubId() then
                if nd.close then
                    pcall(nd.close)
                else
                    if nd.g then pcall(function() nd.g:Destroy() end) end
                    table.remove(active, i)
                end
            end
        end
        pcall(updPos)
    end)
end
local function mkPopup(backdrop,w,h,hero)
    local shell = Instance.new("Frame"); shell.Size = UDim2.new(0,w,0,h); shell.BackgroundTransparency = 1; shell.BorderSizePixel = 0
    shell.Position = UDim2.new(0.5,-w/2,0.5,-h/2 + 10); shell.Parent = backdrop
    local group = Instance.new("CanvasGroup"); group.Size = UDim2.new(1,0,1,0); group.BackgroundColor3 = C.panel; group.BorderSizePixel = 0
    group.ClipsDescendants = true
    group.GroupTransparency = 1; group.Parent = shell; corner(16,group)
    BG.register("Popup", group, 16)
    local outline = Instance.new("Frame"); outline.Size = UDim2.new(1,0,1,0); outline.BackgroundTransparency = 1; outline.BorderSizePixel = 0; outline.ZIndex = 50; outline.Parent = shell; corner(16,outline)
    local ol = stroke(C.border,1,outline); ol.Transparency = 1
    local heroH = 0
    local shineTw
    if hero then
        heroH = hero.Height or 76
        local col = hero.Color or ACCENTS[1]
        local band = Instance.new("Frame"); band.Size = UDim2.new(1,0,0,heroH); band.BackgroundColor3 = col; band.BorderSizePixel = 0; band.ClipsDescendants = true; band.Parent = group
        local bg = Instance.new("UIGradient"); bg.Rotation = 105; bg.Color = ColorSequence.new(col:Lerp(Color3.new(1,1,1),0.12), col:Lerp(Color3.new(0,0,0),0.45)); bg.Parent = band
        local shine = Instance.new("Frame"); shine.Size = UDim2.new(0.45,0,3,0); shine.Position = UDim2.new(-0.5,0,-1,0); shine.Rotation = 18
        shine.BackgroundColor3 = Color3.new(1,1,1); shine.BorderSizePixel = 0; shine.BackgroundTransparency = 1; shine.ZIndex = 2; shine.Parent = band
        local sg = Instance.new("UIGradient"); sg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.82),NumberSequenceKeypoint.new(1,1)}); sg.Parent = shine
        shineTw = createTween(shine, TweenInfo.new(3.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true), {Position = UDim2.new(1.15,0,-1,0)})
        shineTw:Play()
        if hero.Icon then
            local ic = mkIcon(band, hero.Icon, 26, 4); ic.AnchorPoint = Vector2.new(0.5,0.5); ic.Position = UDim2.new(0, (hero.Title and 30 or (w/2)), 0.5, 2)
            if not hero.Title then ic.Position = UDim2.new(0.5,0,0.5,2) end
            if ic:IsA("TextLabel") then ic.TextColor3 = Color3.new(1,1,1) else ic.ImageColor3 = Color3.new(1,1,1) end
            ic.ZIndex = 3
        end
        if hero.Title then
            local tx = hero.Icon and 56 or 18
            newTxt({Parent=band,Text=hero.Title,Font=GB,Size=17,Color=Color3.new(1,1,1),Sz=UDim2.new(1,-tx - 44,0,22),Pos=UDim2.new(0,tx,0,heroH/2 - (hero.Subtitle and 16 or 11)),Z=3})
            if hero.Subtitle then newTxt({Parent=band,Text=hero.Subtitle,Font=GM,Size=11,Color=Color3.new(1,1,1),Sz=UDim2.new(1,-tx - 44,0,14),Pos=UDim2.new(0,tx,0,heroH/2 + 6),Z=3}).TextTransparency = 0.2 end
        end
    end
    local function show()
        tw(backdrop,{BackgroundTransparency = 0.45},.2)
        tw(group,{GroupTransparency = 0},.2); tw(ol,{Transparency = 0},.2)
        tw(shell,{Position = UDim2.new(0.5,-w/2,0.5,-h/2)},.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    end
    local function hide()
        tw(backdrop,{BackgroundTransparency = 1},.15)
        tw(group,{GroupTransparency = 1},.15); tw(ol,{Transparency = 1},.15)
        tw(shell,{Position = UDim2.new(0.5,-w/2,0.5,-h/2 + 8)},.15)
        if shineTw then shineTw:Cancel() end
    end
    return shell, group, show, hide, heroH
end
local function mkTopBar(parent,color,z)
    local b = Instance.new("Frame"); b.Size = UDim2.new(1,-32,0,3); b.Position = UDim2.new(0,16,0,0); b.BackgroundColor3 = color; b.BorderSizePixel = 0
    if z then b.ZIndex = z end
    b.Parent = parent; corner(2,b)
    return b
end
local function confirmDialog(promptTitle,promptDesc,opts)
    opts = opts or {}
    local hasCheckbox = type(opts.CheckboxText) == "string" and opts.CheckboxText ~= ""
    local CoreGui = game:GetService("CoreGui")
    local sg3 = registerHubGui(Instance.new("ScreenGui"), "Confirm"); sg3.ResetOnSpawn = false; sg3.IgnoreGuiInset = true; sg3.DisplayOrder = 1000
    local okp = pcall(function() sg3.Parent = CoreGui end); if not okp or not sg3.Parent then sg3.Parent = PG end
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sg3
    local shell,card,showPopup,hidePopup = mkPopup(bd,280,hasCheckbox and 178 or 150)
    local accentCol = opts.Danger and C.danger or ACCENTS[1]
    local topBar = mkTopBar(card, accentCol)
    newTxt({Parent=card,Text=promptTitle,Font=GB,Size=15,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-20,0,20),Pos=UDim2.new(0,10,0,16)})
    newTxt({Parent=card,Text=promptDesc,Size=11,Color=C.dim,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-28,0,52),Pos=UDim2.new(0,14,0,42)})
    local checkboxValue = opts.CheckboxDefault == true
    if hasCheckbox then
        local checkboxRow = Instance.new("Frame")
        checkboxRow.Size = UDim2.new(1,-36,0,22)
        checkboxRow.Position = UDim2.new(0,18,0,105)
        checkboxRow.BackgroundTransparency = 1
        checkboxRow.Parent = card
        local checkboxBox = Instance.new("TextButton")
        checkboxBox.Size = UDim2.new(0,17,0,17)
        checkboxBox.Position = UDim2.new(0,0,0,2)
        checkboxBox.BackgroundColor3 = checkboxValue and ACCENTS[1] or C.btnBg
        checkboxBox.BorderSizePixel = 0
        checkboxBox.AutoButtonColor = false
        checkboxBox.Text = checkboxValue and "✓" or ""
        checkboxBox.Font = GB
        checkboxBox.TextSize = 12
        checkboxBox.TextColor3 = Color3.new(1,1,1)
        checkboxBox.Parent = checkboxRow
        corner(5,checkboxBox)
        stroke(C.border,1,checkboxBox)
        local checkboxLabel = Instance.new("TextButton")
        checkboxLabel.Size = UDim2.new(1,-25,1,0)
        checkboxLabel.Position = UDim2.new(0,25,0,0)
        checkboxLabel.BackgroundTransparency = 1
        checkboxLabel.BorderSizePixel = 0
        checkboxLabel.AutoButtonColor = false
        checkboxLabel.Text = opts.CheckboxText
        checkboxLabel.Font = GM
        checkboxLabel.TextSize = 11
        checkboxLabel.TextColor3 = C.dim
        checkboxLabel.TextXAlignment = Enum.TextXAlignment.Left
        checkboxLabel.Parent = checkboxRow
        local function toggleCheckbox()
            checkboxValue = not checkboxValue
            checkboxBox.Text = checkboxValue and "✓" or ""
            tw(checkboxBox,{BackgroundColor3 = checkboxValue and ACCENTS[1] or C.btnBg},.12)
        end
        checkboxBox.MouseButton1Click:Connect(toggleCheckbox)
        checkboxLabel.MouseButton1Click:Connect(toggleCheckbox)
    end
    local function mkB(txt,col,bordered,pos)
        local b = Instance.new("TextButton"); b.Size = UDim2.new(0.5,-22,0,32); b.Position = pos; b.BackgroundColor3 = col; b.Text = txt; b.Font = GB; b.TextSize = 13
        b.TextColor3 = Color3.new(1,1,1); b.AutoButtonColor = true; b.Parent = card; corner(8,b); if bordered then stroke(C.border,1,b) end; return b
    end
    local confirmBtn = mkB(opts.ConfirmText or "Yes", opts.Danger and C.danger or Color3.fromRGB(72,198,138), false, UDim2.new(0,14,1,-46))
    local cancelBtn  = mkB(opts.CancelText or "No",  C.btnBg, true, UDim2.new(0.5,8,1,-46))
    local result = nil
    confirmBtn.MouseButton1Click:Connect(function() if result == nil then result = true end end)
    cancelBtn.MouseButton1Click:Connect(function() if result == nil then result = false end end)
    showPopup()
    while result == nil do task.wait() end
    hidePopup(); task.wait(.16)
    sg3:Destroy()
    return result, checkboxValue
end
local function unloadDialog()
    local CoreGui = game:GetService("CoreGui")
    local sgU = registerHubGui(Instance.new("ScreenGui"), "Unload"); sgU.ResetOnSpawn = false; sgU.IgnoreGuiInset = true; sgU.DisplayOrder = 1000
    local okp = pcall(function() sgU.Parent = CoreGui end); if not okp or not sgU.Parent then sgU.Parent = PG end
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sgU
    local shell,card,showPopup,hidePopup = mkPopup(bd,340,222)
    local function dlgIcon(parent,name,sz,col,z)
        if not JL._iconPack then return nil end
        local ic = mkIcon(parent,name,sz,z)
        if ic:IsA("ImageLabel") then ic.ImageColor3 = col else ic:Destroy(); return nil end
        return ic
    end
    local accent = mkTopBar(card, C.danger, 12)
    local badge = Instance.new("Frame"); badge.Size = UDim2.new(0,38,0,38); badge.Position = UDim2.new(0,18,0,19); badge.BackgroundColor3 = C.panel:Lerp(C.danger,0.25); badge.BorderSizePixel = 0; badge.ZIndex = 12; badge.Parent = card; corner(10,badge)
    local warn = dlgIcon(badge,"triangle-alert",19,C.danger,13)
    if warn then warn.AnchorPoint = Vector2.new(0.5,0.5); warn.Position = UDim2.new(0.5,0,0.5,0) end
    newTxt({Parent=card,Text="Unload interface?",Font=GB,Size=16,Sz=UDim2.new(1,-86,0,23),Pos=UDim2.new(0,67,0,19),Z=12})
    newTxt({Parent=card,Text="You are about to close the hub",Font=G,Size=11,Color=C.dim,Sz=UDim2.new(1,-86,0,18),Pos=UDim2.new(0,67,0,43),Z=12})
    local div = Instance.new("Frame"); div.Size = UDim2.new(1,-36,0,1); div.Position = UDim2.new(0,18,0,72); div.BackgroundColor3 = C.border; div.BorderSizePixel = 0; div.ZIndex = 12; div.Parent = card
    newTxt({Parent=card,Text="The interface will be removed. Any running features may stop.",Font=G,Size=12,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-38,0,43),Pos=UDim2.new(0,19,0,87),Z=12}).TextYAlignment = Enum.TextYAlignment.Top
    local row = Instance.new("Frame"); row.Size = UDim2.new(1,-36,0,40); row.Position = UDim2.new(0,18,1,-58); row.BackgroundTransparency = 1; row.ZIndex = 12; row.Parent = card
    local lay = Instance.new("UIListLayout"); lay.FillDirection = Enum.FillDirection.Horizontal; lay.HorizontalAlignment = Enum.HorizontalAlignment.Center; lay.VerticalAlignment = Enum.VerticalAlignment.Center; lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Padding = UDim.new(0,10); lay.Parent = row
    local cancelBtn = Instance.new("TextButton"); cancelBtn.LayoutOrder = 1; cancelBtn.Size = UDim2.new(0.5,-5,1,0); cancelBtn.BackgroundColor3 = C.btnBg; cancelBtn.BorderSizePixel = 0; cancelBtn.AutoButtonColor = false
    cancelBtn.Text = "Cancel"; cancelBtn.Font = GM; cancelBtn.TextSize = 13; cancelBtn.TextColor3 = C.txt; cancelBtn.ZIndex = 13; cancelBtn.Parent = row; corner(8,cancelBtn); stroke(C.border,1,cancelBtn)
    local unloadBtn = Instance.new("TextButton"); unloadBtn.LayoutOrder = 2; unloadBtn.Size = UDim2.new(0.5,-5,1,0); unloadBtn.BackgroundColor3 = C.danger; unloadBtn.BorderSizePixel = 0; unloadBtn.AutoButtonColor = false
    unloadBtn.Text = ""; unloadBtn.ZIndex = 13; unloadBtn.Parent = row; corner(8,unloadBtn)
    local exitIcon = dlgIcon(unloadBtn,"log-out",15,Color3.new(1,1,1),14)
    if exitIcon then exitIcon.Position = UDim2.new(0,17,0.5,-7) end
    newTxt({Parent=unloadBtn,Text="Unload",Font=GB,Size=13,Color=Color3.new(1,1,1),XAlign=exitIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,Sz=UDim2.new(1,exitIcon and -42 or 0,1,0),Pos=UDim2.new(0,exitIcon and 37 or 0,0,0),Z=14})
    cancelBtn.MouseEnter:Connect(function() if touchLast() then return end tw(cancelBtn,{BackgroundColor3 = C.btnHov},.1) end)
    cancelBtn.MouseLeave:Connect(function() tw(cancelBtn,{BackgroundColor3 = C.btnBg},.1) end)
    unloadBtn.MouseEnter:Connect(function() tw(unloadBtn,{BackgroundColor3 = C.danger:Lerp(Color3.new(1,1,1),0.1)},.1) end)
    unloadBtn.MouseLeave:Connect(function() tw(unloadBtn,{BackgroundColor3 = C.danger},.1) end)
    local result = nil
    cancelBtn.Activated:Connect(function() if result == nil then result = false end end)
    unloadBtn.Activated:Connect(function() if result == nil then result = true end end)
    bd.InputBegan:Connect(function(i)
        if not isPtr(i) or result ~= nil then return end
        local p,s = shell.AbsolutePosition, shell.AbsoluteSize
        local x,y = i.Position.X, i.Position.Y
        if x < p.X or x > p.X + s.X or y < p.Y or y > p.Y + s.Y then result = false end
    end)
    showPopup()
    while result == nil do task.wait() end
    hidePopup(); task.wait(.16)
    sgU:Destroy()
    return result
end
function JL:Confirm(opts)
    opts = opts or {}
    return confirmDialog(opts.Title or "Are you sure?", opts.Desc or "", opts)
end
local function restartPrompt(titleText, descriptionText, actionText)
    local CoreGui = game:GetService("CoreGui")
    local sg4 = registerHubGui(Instance.new("ScreenGui"), "Restart"); sg4.ResetOnSpawn = false; sg4.IgnoreGuiInset = true; sg4.DisplayOrder = 1000
    local okp = pcall(function() sg4.Parent = CoreGui end); if not okp or not sg4.Parent then sg4.Parent = PG end
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sg4
    local shell,card,showPopup,hidePopup = mkPopup(bd,260,300)
    local glowHolder = Instance.new("Frame"); glowHolder.Size = UDim2.new(0,86,0,86); glowHolder.AnchorPoint = Vector2.new(0.5,0); glowHolder.Position = UDim2.new(0.5,0,0,34); glowHolder.BackgroundTransparency = 1; glowHolder.Parent = card
    local ring = Instance.new("Frame"); ring.Size = UDim2.new(1,0,1,0); ring.AnchorPoint = Vector2.new(0.5,0.5); ring.Position = UDim2.new(0.5,0,0.5,0); ring.BackgroundTransparency = 1; ring.Parent = glowHolder
    corner(43,ring); local ringStroke = stroke(ACCENTS[1],2,ring); ringStroke.Transparency = 0.3
    local pulseTw = createTween(ring, TweenInfo.new(1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true), {Size = UDim2.new(1.25,0,1.25,0)})
    local pulseFadeTw = createTween(ringStroke, TweenInfo.new(1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true), {Transparency = 0.85})
    pulseTw:Play(); pulseFadeTw:Play()
    local iconCircle = Instance.new("Frame"); iconCircle.Size = UDim2.new(0,64,0,64); iconCircle.AnchorPoint = Vector2.new(0.5,0.5); iconCircle.Position = UDim2.new(0.5,0,0.5,0); iconCircle.BackgroundColor3 = ACCENTS[1]; iconCircle.BorderSizePixel = 0; iconCircle.Parent = glowHolder; corner(32,iconCircle)
    local ig = Instance.new("UIGradient"); ig.Rotation = 100; ig.Color = ColorSequence.new(ACCENTS[1]:Lerp(Color3.new(1,1,1),0.15), ACCENTS[1]:Lerp(Color3.new(0,0,0),0.4)); ig.Parent = iconCircle
    local ic = mkIcon(iconCircle, "refresh-cw", 28, 4); ic.AnchorPoint = Vector2.new(0.5,0.5); ic.Position = UDim2.new(0.5,0,0.5,0)
    if ic:IsA("TextLabel") then ic.TextColor3 = Color3.new(1,1,1) else ic.ImageColor3 = Color3.new(1,1,1) end
    newTxt({Parent=card,Text=titleText or "Hub Already Running",Font=GB,Size=16,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-30,0,20),Pos=UDim2.new(0,15,0,130)})
    newTxt({Parent=card,Text=descriptionText or "Another JustLib hub is already open.",Font=GM,Size=11,Color=C.dim,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-36,0,44),Pos=UDim2.new(0,18,0,154)})
    local restartBtn = Instance.new("TextButton"); restartBtn.Size = UDim2.new(1,-32,0,38); restartBtn.Position = UDim2.new(0,16,1,-86); restartBtn.BackgroundColor3 = ACCENTS[1]; restartBtn.BorderSizePixel = 0; restartBtn.AutoButtonColor = false; restartBtn.Text = ""; restartBtn.Parent = card; corner(9,restartBtn)
    newTxt({Parent=restartBtn,Text=actionText or "Reload",Font=GB,Size=13,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center})
    local cancelBtn = Instance.new("TextButton"); cancelBtn.Size = UDim2.new(1,-32,0,32); cancelBtn.Position = UDim2.new(0,16,1,-40); cancelBtn.BackgroundTransparency = 1; cancelBtn.AutoButtonColor = false; cancelBtn.Text = ""; cancelBtn.Parent = card
    newTxt({Parent=cancelBtn,Text="Cancel",Font=GB,Size=12,Color=C.dim,XAlign=Enum.TextXAlignment.Center})
    local result = nil
    restartBtn.MouseEnter:Connect(function() tw(restartBtn,{BackgroundColor3 = ACCENTS[1]:Lerp(Color3.new(1,1,1),0.1)},.1) end)
    restartBtn.MouseLeave:Connect(function() tw(restartBtn,{BackgroundColor3 = ACCENTS[1]},.1) end)
    restartBtn.MouseButton1Click:Connect(function() if result == nil then result = true end end)
    cancelBtn.MouseButton1Click:Connect(function() if result == nil then result = false end end)
    showPopup()
    while result == nil do task.wait() end
    pulseTw:Cancel(); pulseFadeTw:Cancel()
    hidePopup(); task.wait(.16)
    sg4:Destroy()
    return result
end
local function detectExecutor()
    local ok,name,ver = pcall(function()
        if identifyexecutor then return identifyexecutor() end
        if getexecutorname then return getexecutorname() end
        return nil
    end)
    if ok and name then return tostring(name), ver and tostring(ver) or nil end
    return nil, nil
end
local function execRequest(reqOpts)
    local fn = (typeof(request) == "function" and request)
        or (typeof(http_request) == "function" and http_request)
        or (syn and typeof(syn.request) == "function" and syn.request)
    if not fn then return nil end
    local ok,res = pcall(fn, reqOpts)
    return ok and res or nil
end
local function joinLowestServer(placeId, onFail)
    local hasReq = typeof(request) == "function" or typeof(http_request) == "function" or (syn and typeof(syn.request) == "function")
    if not hasReq then
        if onFail then onFail("Your executor doesn't support cross-origin requests") end
        return
    end
    trackedSpawn(function()
        local best,bestN,cursor = nil,math.huge,""
        for _ = 1,6 do
            local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or "")
            local res = execRequest({Url = url, Method = "GET"})
            if not res or not res.Body then break end
            local ok,data = pcall(HTTP.JSONDecode, HTTP, res.Body)
            if not ok or type(data) ~= "table" or not data.data then break end
            for _,srv in ipairs(data.data) do
                if srv.playing and srv.id ~= game.JobId and srv.playing < bestN and (not srv.maxPlayers or srv.playing < srv.maxPlayers) then
                    bestN = srv.playing; best = srv.id
                end
            end
            cursor = data.nextPageCursor
            if not cursor or cursor == "" then break end
        end
        if best then
            local ok = pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(placeId, best, LP) end)
            if not ok and onFail then onFail("Teleport failed") end
        elseif onFail then
            onFail("No other server found")
        end
    end)
end
