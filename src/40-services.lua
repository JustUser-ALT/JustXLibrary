local function fetchDiscordInfo(inviteUrl, callback)
    local code = tostring(inviteUrl):match("discord%.gg/([%w-]+)") or tostring(inviteUrl):match("discord%.com/invite/([%w-]+)")
    if not code then return end
    trackedSpawn(function()
        local ok,body = pcall(function() return game:HttpGet("https://discord.com/api/v10/invites/" .. code .. "?with_counts=true") end)
        if not ok or not body then return end
        local ok2,data = pcall(HTTP.JSONDecode, HTTP, body)
        if ok2 and type(data) == "table" then
            pcall(callback, {
                name = data.guild and data.guild.name,
                members = data.approximate_member_count,
                online = data.approximate_presence_count,
            })
        end
    end)
end
function JL:KeySystem(kopts)
    kopts = kopts or {}
    local keyFile = (kopts.ConfigFile or (kopts.Title or "JustLib") .. "_Key") .. ".json"
    local function checkKey(key)
        if kopts.Subscription then
            local ok,reason = JL:RedeemKey(key)
            return ok, reason
        end
        if kopts.KeyValidator then
            local ok,r = pcall(kopts.KeyValidator, key)
            if ok and r then return true end
            return false, (ok and type(r) == "string" and r) or nil
        end
        if kopts.Keys then
            for _,k in ipairs(kopts.Keys) do if k == key then return true end end
        end
        return false
    end
    if kopts.SaveKey and readfile and isfile and pcall(isfile, keyFile) and isfile(keyFile) then
        local ok,raw = pcall(readfile, keyFile)
        if ok and raw and raw ~= "" then
            local ok2,saved = pcall(HTTP.JSONDecode, HTTP, raw)
            if ok2 and type(saved) == "table" and saved.userId == LP.UserId and saved.key and checkKey(saved.key) then
                return true
            end
        end
    end
    local CoreGui = game:GetService("CoreGui")
    local sgK = registerHubGui(Instance.new("ScreenGui"), "KeySystem"); sgK.ResetOnSpawn = false; sgK.IgnoreGuiInset = true; sgK.DisplayOrder = 1000
    local okp = pcall(function() sgK.Parent = CoreGui end); if not okp or not sgK.Parent then sgK.Parent = PG end
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sgK
    local CW,CH = 580,352
    local shell,card,showPopup,hidePopup,heroH = mkPopup(bd,CW,CH,{
        Color = kopts.AccentColor or ACCENTS[1], Icon = kopts.Icon or "key-round",
        Title = kopts.Title or "Key System", Subtitle = kopts.Subtitle or "Key system",
    })
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0,26,0,26); closeBtn.Position = UDim2.new(1,-38,0,heroH/2 - 13); closeBtn.BackgroundColor3 = Color3.new(0,0,0); closeBtn.BackgroundTransparency = 0.65; closeBtn.Text = "x"; closeBtn.Font = GB; closeBtn.TextSize = 13; closeBtn.TextColor3 = Color3.new(1,1,1); closeBtn.ZIndex = 5; closeBtn.Parent = card; corner(8,closeBtn)
    local topY = heroH + 20
    local LW = 348
    local left = Instance.new("Frame"); left.Size = UDim2.new(0,LW,1,-topY - 16); left.Position = UDim2.new(0,20,0,topY); left.BackgroundTransparency = 1; left.Parent = card
    local divider = Instance.new("Frame"); divider.Size = UDim2.new(0,1,1,-topY - 20); divider.Position = UDim2.new(0,LW + 32,0,topY); divider.BackgroundColor3 = C.divLine; divider.BorderSizePixel = 0; divider.Parent = card
    local right = Instance.new("Frame"); right.Size = UDim2.new(0,CW - LW - 68,1,-topY - 16); right.Position = UDim2.new(0,LW + 48,0,topY); right.BackgroundTransparency = 1; right.Parent = card
    if kopts.Note then newTxt({Parent=left,Text=kopts.Note,Font=GM,Size=11,Color=C.dim,Wrap=true,Sz=UDim2.new(1,0,0,32),Pos=UDim2.new(0,0,0,0)}) end
    local inputY = kopts.Note and 40 or 0
    newTxt({Parent=left,Text="License key",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,0,0,14),Pos=UDim2.new(0,0,0,inputY)})
    local inputBg = Instance.new("Frame"); inputBg.Size = UDim2.new(1,0,0,38); inputBg.Position = UDim2.new(0,0,0,inputY + 18); inputBg.BackgroundColor3 = C.input; inputBg.BorderSizePixel = 0; inputBg.Parent = left; corner(8,inputBg)
    local inputStroke = stroke(C.border,1,inputBg)
    local keyIcon = mkIcon(inputBg, "key", 15, 3); keyIcon.Position = UDim2.new(0,12,0.5,-7); if keyIcon:IsA("TextLabel") then keyIcon.TextColor3 = C.dim else keyIcon.ImageColor3 = C.dim end
    local keyBox = Instance.new("TextBox"); keyBox.Size = UDim2.new(1,-40,1,0); keyBox.Position = UDim2.new(0,34,0,0); keyBox.BackgroundTransparency = 1
    keyBox.PlaceholderText = "Paste your key here"; keyBox.PlaceholderColor3 = C.dim; keyBox.Font = GB; keyBox.TextSize = 13; keyBox.TextColor3 = C.txt; keyBox.ClearTextOnFocus = false; keyBox.Text = ""; keyBox.Parent = inputBg
    local btnY = inputY + 64
    local submitBtn = Instance.new("TextButton"); submitBtn.Size = UDim2.new(0.62,-4,0,38); submitBtn.Position = UDim2.new(0,0,0,btnY); submitBtn.BackgroundColor3 = ACCENTS[1]; submitBtn.BorderSizePixel = 0; submitBtn.AutoButtonColor = false; submitBtn.Text = ""; submitBtn.Parent = left; corner(8,submitBtn)
    newTxt({Parent=submitBtn,Text="Submit",Font=GB,Size=13,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center})
    local getKeyBtn = Instance.new("TextButton"); getKeyBtn.Size = UDim2.new(0.38,-4,0,38); getKeyBtn.Position = UDim2.new(0.62,8,0,btnY); getKeyBtn.BackgroundColor3 = C.btnBg; getKeyBtn.BorderSizePixel = 0; getKeyBtn.AutoButtonColor = false; getKeyBtn.Text = ""; getKeyBtn.Parent = left; corner(8,getKeyBtn); stroke(C.border,1,getKeyBtn)
    newTxt({Parent=getKeyBtn,Text="Get a key",Font=GB,Size=12,XAlign=Enum.TextXAlignment.Center})
    getKeyBtn.MouseButton1Click:Connect(function()
        if not kopts.GetKeyURL then return end
        if setclipboard then setclipboard(kopts.GetKeyURL); JL:Notify({Title = "Get a Key", Desc = "Link copied — open it in your browser", Type = "Info", Duration = 4})
        else JL:Notify({Title = "Get a Key", Desc = kopts.GetKeyURL, Type = "Info", Duration = 6}) end
    end)
    local statusY = btnY + 52
    
    avatarBox:SetAttribute("JLNoRepaint", true)
    trackedSpawn(function()
        local ok,content = pcall(function() return game:GetService("Players"):GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
        if ok then avatarBox.Image = content end
    end)
    newTxt({Parent=left,Text="Welcome Back",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-46,0,12),Pos=UDim2.new(0,46,0,statusY + 2)})
    newTxt({Parent=left,Text=LP.DisplayName .. "!",Font=GB,Size=13,Sz=UDim2.new(1,-46,0,18),Pos=UDim2.new(0,46,0,statusY + 14)})
    newTxt({Parent=right,Text="Detected game",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,0,0,14)})
    local gameCard = Instance.new("Frame"); gameCard.Size = UDim2.new(1,0,0,54); gameCard.Position = UDim2.new(0,0,0,18); gameCard.BackgroundColor3 = C.pHdr; gameCard.BorderSizePixel = 0; gameCard.Parent = right; corner(9,gameCard)
    local gIcon = Instance.new("ImageLabel"); gIcon.Size = UDim2.new(0,38,0,38); gIcon.Position = UDim2.new(0,8,0.5,-19); gIcon.BackgroundColor3 = C.btnBg; gIcon.BorderSizePixel = 0; gIcon.Parent = gameCard; corner(7,gIcon)
    gIcon:SetAttribute("JLNoRepaint", true)
    local gName = newTxt({Parent=gameCard,Text="Loading...",Font=GB,Size=12,Wrap=true,Sz=UDim2.new(1,-56,0,16),Pos=UDim2.new(0,50,0,8)})
    local gSub = newTxt({Parent=gameCard,Text="",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-56,0,14),Pos=UDim2.new(0,50,0,26)})
    trackedSpawn(function()
        local ok,info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId, Enum.InfoType.Asset) end)
        if ok and info then
            gName.Text = kopts.GameName or info.Name or "Unknown"
            gSub.Text = "In list"
            if info.IconImageAssetId and info.IconImageAssetId ~= 0 then gIcon.Image = "rbxassetid://" .. info.IconImageAssetId end
        end
    end)
    local execName = detectExecutor()
    local rowY = 84
    local function statRow(label,value,valueColor)
        local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,18); row.Position = UDim2.new(0,0,0,rowY); row.BackgroundTransparency = 1; row.Parent = right
        newTxt({Parent=row,Text=label,Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(0.5,0,1,0)})
        local v = newTxt({Parent=row,Text=value,Font=GB,Size=11,Color=valueColor or C.txt,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0.5,0,1,0),Pos=UDim2.new(0.5,0,0,0)})
        rowY = rowY + 22
        return v
    end
    statRow("Executor", execName or "Unknown")
    local statusV = statRow("Status", "Key required", ACCENTS[4] or C.dim)
    if kopts.DiscordInvite then
        rowY = rowY + 6
        local commCard = Instance.new("Frame"); commCard.Size = UDim2.new(1,0,0,64); commCard.Position = UDim2.new(0,0,0,rowY); commCard.BackgroundColor3 = C.pHdr; commCard.BorderSizePixel = 0; commCard.Parent = right; corner(9,commCard)
        local dIcon = mkIcon(commCard, "message-circle", 20, 3); dIcon.Position = UDim2.new(0,10,0,8)
        newTxt({Parent=commCard,Text="Community",Font=GB,Size=11,Sz=UDim2.new(1,-16,0,14),Pos=UDim2.new(0,10,0,32)})
        local dSub = newTxt({Parent=commCard,Text="...",Font=GM,Size=9,Color=C.dim,Sz=UDim2.new(1,-16,0,12),Pos=UDim2.new(0,10,0,46)})
        fetchDiscordInfo(kopts.DiscordInvite, function(info2)
            local bits = {}
            if info2.members then bits[#bits+1] = info2.members .. " members" end
            if info2.online then bits[#bits+1] = info2.online .. " online" end
            if #bits > 0 then dSub.Text = table.concat(bits, " · ") end
        end)
        local joinBtn = Instance.new("TextButton"); joinBtn.Size = UDim2.new(0,50,0,22); joinBtn.Position = UDim2.new(1,-58,0,7); joinBtn.BackgroundColor3 = ACCENTS[1]; joinBtn.BorderSizePixel = 0; joinBtn.Text = "Join"; joinBtn.Font = GB; joinBtn.TextSize = 10; joinBtn.TextColor3 = Color3.new(1,1,1); joinBtn.Parent = commCard; corner(6,joinBtn)
        joinBtn.MouseButton1Click:Connect(function()
            if setclipboard then setclipboard(kopts.DiscordInvite); JL:Notify({Title = "Copied", Desc = "Invite link copied", Type = "Success", Duration = 3}) end
        end)
    end
    local result = nil
    closeBtn.MouseButton1Click:Connect(function() if result == nil then result = false end end)
    local function shakeInvalid(msg)
        tw(inputStroke,{Color = C.danger},.1)
        trackedDelay(.5, function() tw(inputStroke,{Color = C.border},.2) end)
        statusV.Text = "Invalid"; statusV.TextColor3 = C.danger
        JL:Notify({Title = "Key System", Desc = msg or "That key is not valid", Type = "Error", Duration = 4})
    end
    submitBtn.MouseButton1Click:Connect(function()
        local key = keyBox.Text:gsub("^%s+",""):gsub("%s+$","")
        if key == "" then shakeInvalid("Enter a key first"); return end
        statusV.Text = "Checking..."; statusV.TextColor3 = C.dim
        local valid,reason = checkKey(key)
        if valid then
            statusV.Text = "Valid"; statusV.TextColor3 = C.fpsGrn
            if kopts.SaveKey and writefile then
                pcall(writefile, keyFile, HTTP:JSONEncode({key = key, userId = LP.UserId}))
            end
            trackedDelay(.2, function() if result == nil then result = true end end)
        else
            shakeInvalid(reason)
        end
    end)
    showPopup()
    while result == nil do task.wait() end
    hidePopup(); task.wait(.16)
    sgK:Destroy()
    return result
end
local SUB = {tiers = {}, order = {}, current = nil, expDay = 0, key = nil, watchers = {}, opts = {}}
JL._sub = SUB
local function mul32(a,b)
    local ah,al = math.floor(a / 65536), a % 65536
    local bh,bl = math.floor(b / 65536), b % 65536
    return (((ah * bl + al * bh) % 65536) * 65536 + al * bl) % 4294967296
end
local function fnv32(str,seed)
    local h = seed
    for i = 1,#str do
        h = bit32.bxor(h, string.byte(str,i))
        h = mul32(h, 16777619)
    end
    h = bit32.bxor(h, bit32.rshift(h,15)); h = mul32(h, 2246822519)
    h = bit32.bxor(h, bit32.rshift(h,13)); h = mul32(h, 3266489917)
    return bit32.bxor(h, bit32.rshift(h,16))
end
local B36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local function toB36(n,width)
    local out = ""
    repeat
        local d = n % 36
        out = B36:sub(d + 1,d + 1) .. out
        n = math.floor(n / 36)
    until n == 0
    while width and #out < width do out = "0" .. out end
    return out
end
local function keySig(secret,tierName,bind,nonce,expS)
    local msg = secret .. "|" .. tierName .. "|" .. bind .. "|" .. nonce .. "|" .. expS
    return toB36(fnv32(msg,2166136261),7) .. toB36(fnv32(msg .. "#",2654435761),7)
end
local function bindValue(mode)
    if mode == "Name" then return LP.Name:lower() end
    return tostring(LP.UserId)
end
local function todayDay() return math.floor(DateTime.now().UnixTimestamp / 86400) end
local function subFile() return (SUB.opts.File or "JustLib") .. "_Sub.json" end
function JL:GenerateKey(g)
    g = g or {}
    assert(g.Secret and g.Tier, "GenerateKey needs Secret and Tier")
    local prefix = g.Prefix or (g.Tier:gsub("%s",""))
    local mode = g.Bind or "UserId"
    local bind = "0"
    if mode == "UserId" and g.UserId then bind = tostring(g.UserId)
    elseif mode == "Name" and g.Name then bind = tostring(g.Name):lower() end
    local expDay = 0
    if g.Days and g.Days > 0 then expDay = todayDay() + math.floor(g.Days) end
    local rnd = Random.new()
    local nonce = ""
    for _ = 1,6 do local d = rnd:NextInteger(1,36); nonce = nonce .. B36:sub(d,d) end
    local expS = toB36(expDay)
    return prefix .. "-" .. nonce .. "-" .. expS .. "-" .. keySig(g.Secret, g.Tier, bind, nonce, expS)
end
function JL:ValidateKey(key)
    key = tostring(key or ""):gsub("%s","")
    if key == "" then return nil, "Enter a key first" end
    local o = SUB.opts
    if o.Validator then
        local ok,tierName,extra = pcall(o.Validator, key)
        if ok and type(tierName) == "string" and SUB.tiers[tierName] then
            local expDay = (type(extra) == "number" and extra > 0) and math.floor(extra / 86400) or 0
            return tierName, expDay
        end
        if o.ValidatorOnly then return nil, (ok and type(extra) == "string") and extra or "Invalid key" end
    end
    if not o.Secret then return nil, "Invalid key" end
    local up = key:upper()
    for _,rk in ipairs(o.Revoked or {}) do
        if tostring(rk):upper() == up then return nil, "This key was revoked" end
    end
    local prefix,nonce,expS,sig = up:match("^(.+)%-(%w+)%-(%w+)%-(%w+)$")
    if not prefix then return nil, "That doesn't look like a valid key" end
    local tier
    for _,t in ipairs(SUB.order) do
        local p = t.Prefix or (t.Name:gsub("%s",""))
        if p:upper() == prefix then tier = t; break end
    end
    if not tier then return nil, "Unknown key type" end
    local expDay = tonumber(expS,36) or 0
    if expDay ~= 0 and expDay <= todayDay() then return nil, "This key has expired" end
    local mode = o.Bind or "UserId"
    local binds = {"0"}
    if mode ~= "None" then binds[#binds + 1] = bindValue(mode) end
    for _,b in ipairs(binds) do
        if keySig(o.Secret, tier.Name, b, nonce, expS) == sig then return tier.Name, expDay end
    end
    return nil, "Invalid key, or it belongs to another account"
end
local function notifyTier()
    for _,cb in ipairs(SUB.watchers) do pcall(cb, SUB.current) end
end
local function clearSaved()
    if delfile and isfile then pcall(function() if isfile(subFile()) then delfile(subFile()) end end) end
end
local function applyTier(tierName,expDay,key,persist)
    SUB.current = tierName; SUB.expDay = expDay or 0; SUB.key = key
    if persist and writefile then pcall(writefile, subFile(), HTTP:JSONEncode({key = key, userId = LP.UserId})) end
    notifyTier()
end
local function checkExpiry()
    if SUB.current and SUB.expDay ~= 0 and SUB.expDay <= todayDay() then
        clearSaved(); applyTier(nil,0,nil,false)
    end
end
local function levelOf(name)
    if not name then return 0 end
    for i,t in ipairs(SUB.order) do if t.Name == name then return i end end
    return 0
end
function JL:RedeemKey(key,expectTier)
    local t,extra = JL:ValidateKey(key)
    if not t then return false, extra end
    if expectTier and t ~= expectTier then return false, "That key is for " .. t .. ", not " .. expectTier end
    applyTier(t, extra, (tostring(key):gsub("%s","")), true)
    return true
end
function JL:DeactivateSubscription() clearSaved(); applyTier(nil,0,nil,false) end
function JL:GetTier() checkExpiry(); return SUB.current end
function JL:GetTierLevel() checkExpiry(); return levelOf(SUB.current) end
function JL:HasTier(name)
    if not name then return true end
    local need = levelOf(name)
    if need == 0 then return false end
    return JL:GetTierLevel() >= need
end
function JL:OnTierChanged(cb) SUB.watchers[#SUB.watchers + 1] = cb; return cb end
function JL:OffTierChanged(cb)
    for i,w in ipairs(SUB.watchers) do if w == cb then table.remove(SUB.watchers, i); break end end
end
function JL:GetSubscriptionInfo()
    checkExpiry()
    local timeText
    if SUB.current then
        if SUB.expDay == 0 then timeText = "Lifetime"
        else
            local left = SUB.expDay - todayDay()
            timeText = left .. (left == 1 and " day left" or " days left")
        end
    end
    return {Name = SUB.current or (SUB.opts.FreeName or "Free"), Tier = SUB.current and SUB.tiers[SUB.current] or nil, Subscribed = SUB.current ~= nil, TimeText = timeText}
end
function JL:Subscriptions(o)
    SUB.opts = o or {}; SUB.tiers = {}; SUB.order = {}
    for _,t in ipairs(SUB.opts.Tiers or {}) do SUB.tiers[t.Name] = t; SUB.order[#SUB.order + 1] = t end
    if readfile and isfile then
        local okf,exists = pcall(isfile, subFile())
        if okf and exists then
            local okr,raw = pcall(readfile, subFile())
            if okr and raw and raw ~= "" then
                local okj,saved = pcall(HTTP.JSONDecode, HTTP, raw)
                if okj and type(saved) == "table" and saved.userId == LP.UserId and saved.key then
                    local t2,extra = JL:ValidateKey(saved.key)
                    if t2 then SUB.current = t2; SUB.expDay = extra or 0; SUB.key = saved.key end
                end
            end
        end
    end
    checkExpiry()
    notifyTier()
end
function JL:OpenSubscriptions()
    if #SUB.order == 0 then JL:Notify({Title = "Subscriptions", Desc = "No subscriptions are configured", Type = "Warn", Duration = 3}); return end
    if SUB._gui and SUB._gui.Parent then return end
    local CoreGui = game:GetService("CoreGui")
    local sgS = registerHubGui(Instance.new("ScreenGui"), "Subscriptions"); sgS.ResetOnSpawn = false; sgS.IgnoreGuiInset = true; sgS.DisplayOrder = 1000
    local okp = pcall(function() sgS.Parent = CoreGui end); if not okp or not sgS.Parent then sgS.Parent = PG end
    SUB._gui = sgS
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sgS
    local PW,PH = 664,424
    local shell,card,showPopup,hidePopup,heroH = mkPopup(bd,PW,PH,{Color = ACCENTS[1], Icon = "gem", Title = "Subscriptions"})
    local statusL = newTxt({Parent=card,Text="",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-32,0,16),Pos=UDim2.new(0,18,0,heroH + 10)})
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0,26,0,26); closeBtn.Position = UDim2.new(1,-38,0,heroH/2 - 13); closeBtn.BackgroundColor3 = Color3.new(0,0,0); closeBtn.BackgroundTransparency = 0.65; closeBtn.Text = "x"; closeBtn.Font = GB; closeBtn.TextSize = 13; closeBtn.TextColor3 = Color3.new(1,1,1); closeBtn.Parent = card; corner(8,closeBtn)
    local scroll = Instance.new("ScrollingFrame"); scroll.Size = UDim2.new(1,-24,1,-heroH - 40); scroll.Position = UDim2.new(0,12,0,heroH + 32); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = C.border; scroll.ScrollingDirection = Enum.ScrollingDirection.X; scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize = Enum.AutomaticSize.X; scroll.Parent = card
    local lay = Instance.new("UIListLayout"); lay.FillDirection = Enum.FillDirection.Horizontal; lay.Padding = UDim.new(0,12); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = scroll
    pad(0,0,0,10,scroll)
    local wheelConn = keep(UIS.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseWheel then return end
        local m = UIS:GetMouseLocation(); local ap,as = scroll.AbsolutePosition, scroll.AbsoluteSize
        if m.X >= ap.X and m.X <= ap.X + as.X and m.Y >= ap.Y and m.Y <= ap.Y + as.Y then
            scroll.CanvasPosition = Vector2.new(math.max(0, scroll.CanvasPosition.X - i.Position.Z * 80), 0)
        end
    end))
    local build
    local watcher
    local function closePopup()
        pcall(function() wheelConn:Disconnect() end)
        if watcher then JL:OffTierChanged(watcher) end
        hidePopup()
        trackedDelay(.16, function() sgS:Destroy() end)
    end
    closeBtn.MouseButton1Click:Connect(closePopup)
    build = function()
        for _,c in ipairs(scroll:GetChildren()) do if c:IsA("CanvasGroup") then c:Destroy() end end
        local info = JL:GetSubscriptionInfo()
        statusL.Text = "Current plan: " .. info.Name .. (info.TimeText and (" · " .. info.TimeText) or "")
        for idx,t in ipairs(SUB.order) do
            local col = t.Color or ACCENTS[((idx - 1) % #ACCENTS) + 1]
            local tc = Instance.new("CanvasGroup"); tc.Size = UDim2.new(0,208,1,-6); tc.BackgroundColor3 = C.pHdr; tc.BorderSizePixel = 0; tc.LayoutOrder = idx; tc.Parent = scroll; corner(12,tc)
            local ts = stroke((info.Name == t.Name) and col or C.border, (info.Name == t.Name) and 2 or 1, tc)
            local art = Instance.new("Frame"); art.Size = UDim2.new(1,0,0,108); art.BackgroundColor3 = col; art.BorderSizePixel = 0; art.Parent = tc
            art:SetAttribute("JLNoRepaint", true)
            local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(col, col:Lerp(Color3.new(0,0,0), 0.55)); g.Rotation = 90; g.Parent = art
            if t.Image then
                local img = Instance.new("ImageLabel"); img.Size = UDim2.new(1,0,1,0); img.BackgroundTransparency = 1; img.ScaleType = Enum.ScaleType.Crop; img.Parent = art
                local id = tostring(t.Image); if id:match("^%d+$") then id = "rbxassetid://" .. id end
                img.Image = id; img:SetAttribute("JLNoRepaint", true)
            else
                local big = newTxt({Parent=art,Text=t.Name:sub(1,1):upper(),Font=GB,Size=44,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center}); big:SetAttribute("JLNoRepaint", true)
            end
            local nm = newTxt({Parent=tc,Text=t.Name,Font=GB,Size=21,Color=col,Sz=UDim2.new(1,-20,0,26),Pos=UDim2.new(0,12,0,116)}); nm:SetAttribute("JLNoRepaint", true)
            if t.Tagline then newTxt({Parent=tc,Text=t.Tagline,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-20,0,14),Pos=UDim2.new(0,12,0,143)}) end
            local perkText = t.Description
            if t.Perks then
                local lines = {}
                for _,p in ipairs(t.Perks) do lines[#lines + 1] = "• " .. p end
                perkText = table.concat(lines, "\n")
            end
            if perkText then newTxt({Parent=tc,Text=perkText,Font=GM,Size=11,Color=C.txt,Wrap=true,XAlign=Enum.TextXAlignment.Left,Sz=UDim2.new(1,-24,0,74),Pos=UDim2.new(0,12,0,164)}) end
            local act = Instance.new("Frame"); act.Size = UDim2.new(1,-24,0,64); act.Position = UDim2.new(0,12,1,-74); act.BackgroundTransparency = 1; act.Parent = tc
            local function clearAct() for _,c in ipairs(act:GetChildren()) do c:Destroy() end end
            local function mkBtn(text,y,h,bg,tcol,parent2)
                local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,h); b.Position = UDim2.new(0,0,0,y); b.BackgroundColor3 = bg; b.BorderSizePixel = 0; b.AutoButtonColor = true
                b.Text = text; b.Font = GB; b.TextSize = 12; b.TextColor3 = tcol; b.Parent = parent2 or act; corner(8,b); return b
            end
            local showIdle, showInput
            showIdle = function()
                clearAct()
                if info.Name == t.Name then
                    newTxt({Parent=act,Text="Active" .. (info.TimeText and (" · " .. info.TimeText) or ""),Font=GB,Size=11,Color=C.fpsGrn,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,0,18)})
                    local d = mkBtn("Deactivate", 26, 32, C.btnBg, C.txt); stroke(C.border,1,d)
                    d.MouseButton1Click:Connect(function()
                        if confirmDialog("Deactivate " .. t.Name, "Remove this subscription from this account?", {Danger = true, ConfirmText = "Deactivate", CancelText = "Cancel"}) then
                            JL:DeactivateSubscription()
                        end
                    end)
                elseif JL:HasTier(t.Name) then
                    newTxt({Parent=act,Text="Included in " .. info.Name,Font=GM,Size=11,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,1,0)})
                else
                    local a = mkBtn(t.ButtonText or "Activate", 14, 36, col, Color3.new(1,1,1)); a:SetAttribute("JLNoRepaint", true)
                    a.MouseButton1Click:Connect(function() showInput() end)
                end
            end
            showInput = function()
                clearAct()
                local boxBg = Instance.new("Frame"); boxBg.Size = UDim2.new(1,0,0,28); boxBg.BackgroundColor3 = C.input; boxBg.BorderSizePixel = 0; boxBg.Parent = act; corner(7,boxBg)
                local bs = stroke(C.border,1,boxBg)
                local box = Instance.new("TextBox"); box.Size = UDim2.new(1,-14,1,0); box.Position = UDim2.new(0,7,0,0); box.BackgroundTransparency = 1; box.PlaceholderText = "Paste your key"; box.PlaceholderColor3 = C.dim
                box.Font = GB; box.TextSize = 11; box.TextColor3 = C.txt; box.ClearTextOnFocus = false; box.Text = ""; box.Parent = boxBg
                local redeem = mkBtn("Redeem", 34, 28, col, Color3.new(1,1,1)); redeem:SetAttribute("JLNoRepaint", true)
                redeem.MouseButton1Click:Connect(function()
                    local ok,reason = JL:RedeemKey(box.Text, t.Name)
                    if ok then
                        JL:Notify({Title = t.Name, Desc = "Subscription activated", Type = "Success", Duration = 4})
                    else
                        tw(bs,{Color = C.danger},.1); trackedDelay(.5, function() tw(bs,{Color = C.border},.2) end)
                        JL:Notify({Title = "Subscriptions", Desc = reason or "Invalid key", Type = "Error", Duration = 4})
                    end
                end)
            end
            showIdle()
        end
    end
    watcher = JL:OnTierChanged(function() if sgS.Parent then build() end end)
    build()
    showPopup()
end
