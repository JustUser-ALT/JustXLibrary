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
    if SUB._gui and SUB._gui.Parent then return end
    local previewOnly = #SUB.order == 0
    local displayTiers = SUB.order
    if previewOnly then
        displayTiers = {
            {Name = "Free", Tagline = "A place to start", Description = "The essential JustXLibrary experience.", Perks = {"Core library access", "Standard interface customization"}, Color = Color3.fromRGB(112, 125, 148)},
            {Name = "Premium", Tagline = "More room to create", Description = "An expanded experience for regular creators.", Perks = {"Extended customization concepts", "Premium profile identity"}, Color = Color3.fromRGB(80, 145, 255)},
            {Name = "Elite", Tagline = "Built for power users", Description = "A higher-tier concept for advanced users.", Perks = {"Advanced feature concepts", "Exclusive interface themes"}, Color = Color3.fromRGB(166, 105, 255)},
            {Name = "Discord Booster", Tagline = "Support the community", Description = "A recognition tier for community supporters.", Perks = {"Booster recognition", "Community supporter identity"}, Color = Color3.fromRGB(190, 112, 255)},
            {Name = "Contributor", Tagline = "Help build JustX", Description = "For people who contribute to the project.", Perks = {"Contributor recognition", "Early preview concepts"}, Color = Color3.fromRGB(65, 190, 155)},
            {Name = "Founder", Tagline = "A part of the beginning", Description = "A special concept for founding supporters.", Perks = {"Founder recognition", "Legacy supporter identity"}, Color = Color3.fromRGB(230, 175, 82)},
        }
    end

    local CoreGui = game:GetService("CoreGui")
    local sgS = registerHubGui(Instance.new("ScreenGui"), "Subscriptions")
    sgS.ResetOnSpawn = false; sgS.IgnoreGuiInset = true; sgS.DisplayOrder = 1000
    local okp = pcall(function() sgS.Parent = CoreGui end)
    if not okp or not sgS.Parent then sgS.Parent = PG end
    SUB._gui = sgS

    local camera = game:GetService("Workspace").CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800,600)
    local compact = viewport.X < 760 or viewport.Y < 520
    local PW = math.max(280, math.min(compact and 390 or 560, viewport.X - 24))
    local PH = math.max(300, math.min(compact and 440 or 460, viewport.Y - 24))
    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.fromScale(1,1); backdrop.BackgroundColor3 = Color3.fromRGB(5,8,15)
    backdrop.BackgroundTransparency = 1; backdrop.BorderSizePixel = 0; backdrop.Active = true; backdrop.Parent = sgS

    local shell = Instance.new("Frame")
    shell.Name = "SubscriptionStudio"; shell.Size = UDim2.new(0,PW,0,PH)
    shell.AnchorPoint = Vector2.new(.5,.5); shell.Position = UDim2.new(.5,0,.5,14)
    shell.BackgroundColor3 = C.panel; shell.BorderSizePixel = 0; shell.ClipsDescendants = true; shell.Parent = backdrop
    corner(18,shell); stroke(C.border,1,shell); BG.register("Popup",shell,18)

    local accent = Color3.fromRGB(120,104,255)
    local topGlow = Instance.new("Frame"); topGlow.Size = UDim2.new(1,-20,0,3)
    topGlow.Position = UDim2.new(0,10,0,0); topGlow.BackgroundColor3 = accent; topGlow.BorderSizePixel = 0; topGlow.Parent = shell
    corner(2,topGlow)
    local topGrad = Instance.new("UIGradient"); topGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(65,190,190)),
        ColorSequenceKeypoint.new(.5,Color3.fromRGB(120,104,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(236,151,105))
    }); topGrad.Parent = topGlow

    local header = Instance.new("Frame"); header.Size = UDim2.new(1,-28,0,48)
    header.Position = UDim2.new(0,14,0,8); header.BackgroundTransparency = 1; header.Parent = shell
    local mark = Instance.new("Frame"); mark.Size = UDim2.new(0,32,0,32)
    mark.Position = UDim2.new(0,0,0,7); mark.BackgroundColor3 = Color3.fromRGB(34,31,59); mark.BorderSizePixel = 0; mark.Parent = header; corner(12,mark)
    local markStroke = stroke(Color3.fromRGB(91,80,158),1,mark)
    local gem = mkIcon(mark,"gem",16,3); gem.AnchorPoint = Vector2.new(.5,.5); gem.Position = UDim2.fromScale(.5,.5)
    if gem:IsA("ImageLabel") then gem.ImageColor3 = Color3.fromRGB(190,180,255) else gem.TextColor3 = Color3.fromRGB(190,180,255) end
    newTxt({Parent=header,Text="MEMBERSHIP",Font=GB,Size=8,Color=Color3.fromRGB(145,137,180),Sz=UDim2.new(1,-88,0,10),Pos=UDim2.new(0,42,0,5)})
    newTxt({Parent=header,Text="Choose your level",Font=GB,Size=16,Color=C.txt,Sz=UDim2.new(1,-88,0,22),Pos=UDim2.new(0,42,0,17)})
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0,28,0,28)
    closeBtn.Position = UDim2.new(1,-28,0,7); closeBtn.BackgroundColor3 = C.btnBg
    closeBtn.BorderSizePixel = 0; closeBtn.Text = "×"; closeBtn.Font = GB; closeBtn.TextSize = 20
    closeBtn.TextColor3 = C.dim; closeBtn.Parent = header; corner(10,closeBtn); stroke(C.border,1,closeBtn)

    local currentBar = Instance.new("Frame"); currentBar.Size = UDim2.new(1,-28,0,46)
    currentBar.Position = UDim2.new(0,14,0,64); currentBar.BackgroundColor3 = C.pHdr
    currentBar.BorderSizePixel = 0; currentBar.Parent = shell; corner(12,currentBar)
    local currentAccent = Instance.new("Frame"); currentAccent.Size = UDim2.new(0,2,1,-16)
    currentAccent.Position = UDim2.new(0,6,0,8); currentAccent.BackgroundColor3 = Color3.fromRGB(105,203,164)
    currentAccent.BorderSizePixel = 0; currentAccent.Parent = currentBar; corner(2,currentAccent)
    newTxt({Parent=currentBar,Text="YOUR CURRENT ACCESS",Font=GB,Size=8,Color=C.dim,Sz=UDim2.new(1,-100,0,10),Pos=UDim2.new(0,12,0,6)})
    local currentName = newTxt({Parent=currentBar,Text="Free",Font=GB,Size=12,Color=C.txt,Sz=UDim2.new(1,-110,0,18),Pos=UDim2.new(0,12,0,21)})
    local currentMeta = newTxt({Parent=currentBar,Text="",Font=GM,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,92,0,16),Pos=UDim2.new(1,-102,0,15)})

    newTxt({Parent=shell,Text="EXPLORE LEVELS",Font=GB,Size=8,Color=C.dim,Sz=UDim2.new(1,-28,0,12),Pos=UDim2.new(0,14,0,118)})
    local selector = Instance.new("ScrollingFrame"); selector.Name = "TierSelector"
    selector.Size = UDim2.new(1,-28,0,compact and 44 or 46); selector.Position = UDim2.new(0,14,0,134)
    selector.BackgroundTransparency = 1; selector.BorderSizePixel = 0; selector.ScrollBarThickness = 2
    selector.ScrollBarImageColor3 = C.border; selector.ScrollingDirection = Enum.ScrollingDirection.X
    selector.AutomaticCanvasSize = Enum.AutomaticSize.X; selector.CanvasSize = UDim2.new(0,0,0,0); selector.Parent = shell
    local selectorLayout = Instance.new("UIListLayout"); selectorLayout.FillDirection = Enum.FillDirection.Horizontal
    selectorLayout.Padding = UDim.new(0,8); selectorLayout.SortOrder = Enum.SortOrder.LayoutOrder; selectorLayout.Parent = selector
    pad(0,0,0,4,selector)

    local detail = Instance.new("ScrollingFrame"); detail.Name = "TierDetails"
    detail.Position = UDim2.new(0,14,0,188)
    detail.Size = UDim2.new(1,-28,1,-202)
    detail.BackgroundColor3 = C.pHdr; detail.BorderSizePixel = 0; detail.Parent = shell
    detail.ScrollBarThickness = 2; detail.ScrollBarImageColor3 = C.border
    detail.ScrollingDirection = Enum.ScrollingDirection.Y
    detail.AutomaticCanvasSize = Enum.AutomaticSize.Y
    detail.CanvasSize = UDim2.new(0,0,0,0); detail.ClipsDescendants = true
    corner(12,detail)
    local detailGlow = Instance.new("Frame"); detailGlow.Size = UDim2.new(1,-20,0,3)
    detailGlow.Position = UDim2.new(0,10,0,0); detailGlow.BackgroundColor3 = accent
    detailGlow.BorderSizePixel = 0; detailGlow.Parent = detail
    corner(2,detailGlow)
    local detailGlowGradient = Instance.new("UIGradient")
    detailGlowGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,accent),ColorSequenceKeypoint.new(1,accent:Lerp(C.pHdr,.45))})
    detailGlowGradient.Parent = detailGlow
    local detailStroke = stroke(C.border,1,detail)
    local selectedIndex = 1
    local selectedTier = displayTiers[1]
    local actionMode = "idle"
    local watcher, wheelConn
    local closed = false

    local function refreshCurrent()
        local info = JL:GetSubscriptionInfo()
        currentName.Text = info.Name
        currentMeta.Text = info.TimeText or (info.Subscribed and "Active" or "Standard")
        if previewOnly then currentMeta.Text = "DEMO" end
    end
    local function makeButton(parent,textValue,size,pos,bg,fg)
        local b = Instance.new("TextButton"); b.Size = size; b.Position = pos
        b.BackgroundColor3 = bg; b.BorderSizePixel = 0; b.AutoButtonColor = false
        b.Text = textValue; b.Font = GB; b.TextSize = 12; b.TextColor3 = fg; b.Parent = parent
        corner(9,b); return b
    end
    local function clearDetail()
        for _,child in ipairs(detail:GetChildren()) do
            if child ~= detailGlow and child ~= detailStroke then child:Destroy() end
        end
    end
    local function renderDetail()
        if closed or not selectedTier then return end
        clearDetail()
        local t = selectedTier
        local info = JL:GetSubscriptionInfo()
        local col = t.Color or ACCENTS[((selectedIndex - 1) % #ACCENTS) + 1]
        detailGlow.BackgroundColor3 = col
        detailGlowGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,col),ColorSequenceKeypoint.new(1,col:Lerp(C.pHdr,.45))})
        detail.CanvasPosition = Vector2.new(0,0)
        local iconNames = {"sprout","zap","crown","messages-square","code-2","flag"}
        local iconName = t.Icon or iconNames[selectedIndex] or "gem"
        local emblemAura = Instance.new("Frame"); emblemAura.Name = "TierEmblemAura"
        emblemAura.Size = UDim2.new(0,58,0,58); emblemAura.Position = UDim2.new(1,-67,0,11)
        emblemAura.BackgroundColor3 = col; emblemAura.BackgroundTransparency = .88
        emblemAura.BorderSizePixel = 0; emblemAura.Parent = detail; corner(17,emblemAura)
        stroke(col,.8,emblemAura)
        local iconBadge = Instance.new("Frame"); iconBadge.Name = "TierEmblem"
        iconBadge.Size = UDim2.new(0,48,0,48); iconBadge.Position = UDim2.new(1,-62,0,16)
        iconBadge.BackgroundColor3 = col:Lerp(C.pHdr,.88); iconBadge.BorderSizePixel = 0
        iconBadge.Parent = detail; corner(13,iconBadge); stroke(col,.8,iconBadge)
        local emblemGradient = Instance.new("UIGradient")
        emblemGradient.Rotation = 35
        emblemGradient.Color = ColorSequence.new(col:Lerp(Color3.new(1,1,1),.18),col:Lerp(C.pHdr,.78))
        emblemGradient.Parent = iconBadge
        local heroIcon = mkIcon(iconBadge,iconName,25,15)
        heroIcon.AnchorPoint = Vector2.new(.5,.5); heroIcon.Position = UDim2.fromScale(.5,.5)
        heroIcon.TextColor3 = col
        local heroImage = heroIcon:FindFirstChild("JLIconAsset")
        if heroImage then heroImage.ImageColor3 = col end
        newTxt({Parent=detail,Text=string.upper(t.Tagline or "JUSTXLIBRARY ACCESS"),Font=GB,Size=8,Color=col,Sz=UDim2.new(1,-82,0,12),Pos=UDim2.new(0,14,0,16)})
        newTxt({Parent=detail,Text=t.Name,Font=GB,Size=compact and 20 or 23,Color=C.txt,Sz=UDim2.new(1,-82,0,30),Pos=UDim2.new(0,14,0,34)})
        local desc = t.Description or "A membership level for the JustXLibrary experience."
        newTxt({Parent=detail,Text=desc,Font=GM,Size=10,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-28,0,30),Pos=UDim2.new(0,14,0,72)})
        local dividerY = 112
        local div = Instance.new("Frame"); div.Size = UDim2.new(1,-28,0,1); div.Position = UDim2.new(0,14,0,dividerY)
        div.BackgroundColor3 = C.border; div.BorderSizePixel = 0; div.Parent = detail
        newTxt({Parent=detail,Text="WHAT'S INCLUDED",Font=GB,Size=8,Color=C.dim,Sz=UDim2.new(1,-28,0,11),Pos=UDim2.new(0,14,0,dividerY + 7)})
        local perks = t.Perks or {}
        local perkY = dividerY + 22
        local maxPerks = math.min(#perks, 4)
        for i=1,maxPerks do
            local p = Instance.new("Frame"); p.Size = UDim2.new(1,-28,0,20); p.Position = UDim2.new(0,14,0,perkY)
            p.BackgroundTransparency = 1; p.Parent = detail
            local check = Instance.new("Frame"); check.Size = UDim2.new(0,14,0,14); check.Position = UDim2.new(0,0,0,3)
            check.BackgroundColor3 = col:Lerp(C.pHdr,.72); check.BorderSizePixel = 0; check.Parent = p; corner(6,check)
            local tick = newTxt({Parent=check,Text="✓",Font=GB,Size=9,Color=col,XAlign=Enum.TextXAlignment.Center})
            newTxt({Parent=p,Text=tostring(perks[i]),Font=GM,Size=10,Color=C.txt,Sz=UDim2.new(1,-22,1,0),Pos=UDim2.new(0,22,0,0)})
            perkY = perkY + 21
        end
        if #perks == 0 then
            newTxt({Parent=detail,Text="Details will be announced soon.",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-28,0,18),Pos=UDim2.new(0,14,0,perkY)})
        end

        local action = Instance.new("Frame"); action.Name = "TierAction"
        action.Size = UDim2.new(1,-28,0,actionMode == "input" and 112 or 38); action.Position = UDim2.new(0,14,0,perkY + 8)
        action.BackgroundTransparency = 1; action.Parent = detail
        local function idle()
            for _,ch in ipairs(action:GetChildren()) do ch:Destroy() end
            if previewOnly then
                local label = (info.Name == t.Name) and "CURRENT LEVEL" or "CONCEPT PREVIEW"
                newTxt({Parent=action,Text=label,Font=GB,Size=10,Color=(info.Name == t.Name) and Color3.fromRGB(105,203,164) or C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,1,0)})
            elseif info.Name == t.Name then
                local active = newTxt({Parent=action,Text="ACTIVE  ·  " .. (info.TimeText or "Lifetime"),Font=GB,Size=11,Color=Color3.fromRGB(105,203,164),XAlign=Enum.TextXAlignment.Left,Sz=UDim2.new(.48,0,1,0)})
                local deactivate = makeButton(action,"Deactivate",UDim2.new(.48,0,0,36),UDim2.new(.52,0,.5,-18),C.btnBg,C.txt)
                stroke(C.border,1,deactivate)
                deactivate.Activated:Connect(function()
                    if confirmDialog("Deactivate " .. t.Name,"Remove this subscription from this account?",{Danger=true,ConfirmText="Deactivate",CancelText="Cancel"}) then
                        JL:DeactivateSubscription()
                    end
                end)
            elseif JL:HasTier(t.Name) then
                newTxt({Parent=action,Text="INCLUDED WITH " .. string.upper(info.Name),Font=GB,Size=10,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,1,0)})
            else
                local getKeyURL = SUB.opts.GetKeyURL
                if type(getKeyURL) == "string" and getKeyURL ~= "" then
                    local getKey = makeButton(action,"Get a key",UDim2.new(.48,0,0,34),UDim2.new(0,0,.5,-17),C.btnBg,C.txt)
                    stroke(C.border,1,getKey)
                    getKey.Activated:Connect(function()
                        local copied = false
                        if setclipboard then copied = pcall(setclipboard,getKeyURL) end
                        if copied then
                            JL:Notify({Title="Get a Key",Desc="Link copied — open it in your browser",Type="Info",Duration=4})
                        else
                            JL:Notify({Title="Get a Key",Desc=getKeyURL,Type="Info",Duration=6})
                        end
                    end)
                    local activate = makeButton(action,"Enter key  →",UDim2.new(.48,0,0,34),UDim2.new(.52,0,.5,-17),col,Color3.new(1,1,1))
                    activate:SetAttribute("JLNoRepaint",true)
                    activate.Activated:Connect(function() actionMode = "input"; renderDetail() end)
                else
                    local activate = makeButton(action,"Enter activation key   →",UDim2.new(1,0,0,34),UDim2.new(0,0,.5,-17),col,Color3.new(1,1,1))
                    activate:SetAttribute("JLNoRepaint",true)
                    activate.Activated:Connect(function() actionMode = "input"; renderDetail() end)
                end
            end
        end
        if actionMode == "input" and not previewOnly then
            local input = Instance.new("TextBox"); input.Size = UDim2.new(1,0,0,38); input.Position = UDim2.new(0,0,0,0)
            input.BackgroundColor3 = C.input; input.BorderSizePixel = 0; input.PlaceholderText = "Paste your activation key"
            input.PlaceholderColor3 = C.dim; input.TextColor3 = C.txt; input.Font = GB; input.TextSize = 12
            input.ClearTextOnFocus = false; input.Text = ""; input.Parent = action; corner(9,input); local inputStroke = stroke(C.border,1,input)
            local getKeyURL = SUB.opts.GetKeyURL
            local hasGetKeyURL = type(getKeyURL) == "string" and getKeyURL ~= ""
            local redeemWidth = hasGetKeyURL and .48 or 1
            local redeem = makeButton(action,"Redeem",UDim2.new(redeemWidth,hasGetKeyURL and -4 or 0,0,34),UDim2.new(hasGetKeyURL and .52 or 0,hasGetKeyURL and 4 or 0,0,46),col,Color3.new(1,1,1))
            redeem:SetAttribute("JLNoRepaint",true)
            redeem.Activated:Connect(function()
                local ok,reason = JL:RedeemKey(input.Text,t.Name)
                if ok then
                    actionMode = "idle"
                    JL:Notify({Title=t.Name,Desc="Subscription activated",Type="Success",Duration=4})
                    renderDetail()
                else
                    tw(inputStroke,{Color=C.danger},.1)
                    trackedDelay(.5,function() if inputStroke.Parent then tw(inputStroke,{Color=C.border},.2) end end)
                    JL:Notify({Title="Subscriptions",Desc=reason or "Invalid key",Type="Error",Duration=4})
                end
            end)
            if hasGetKeyURL then
                local getKey = makeButton(action,"Get a key",UDim2.new(.48,-4,0,34),UDim2.new(0,0,0,46),C.btnBg,C.txt)
                stroke(C.border,1,getKey)
                getKey.Activated:Connect(function()
                    local copied = false
                    if setclipboard then copied = pcall(setclipboard,getKeyURL) end
                    if copied then
                        JL:Notify({Title="Get a Key",Desc="Link copied — open it in your browser",Type="Info",Duration=4})
                    else
                        JL:Notify({Title="Get a Key",Desc=getKeyURL,Type="Info",Duration=6})
                    end
                end)
            end
            local back = makeButton(action,"←  Back",UDim2.new(0,76,0,24),UDim2.new(0,0,0,86),C.btnBg,C.dim)
            stroke(C.border,1,back)
            back.Activated:Connect(function() actionMode="idle"; renderDetail() end)
        else
            idle()
        end
    end

    local selectorButtons = {}
    local function selectTier(index)
        selectedIndex = index; selectedTier = displayTiers[index]; actionMode = "idle"
        for i,b in ipairs(selectorButtons) do
            local t = displayTiers[i]
            local selected = i == index
            tw(b,{BackgroundColor3 = C.pHdr},.12)
            local st = b:FindFirstChildOfClass("UIStroke")
            if st then st.Color = selected and (t.Color or accent) or C.border; st.Thickness = selected and 1.5 or 1; st.Transparency = selected and 0 or .35 end
            local tx = b:FindFirstChild("TierName")
            if tx then tx.TextColor3 = C.txt end
            local marker = b:FindFirstChild("TierSelectedAccent")
            if marker then marker.Visible = selected; marker.BackgroundColor3 = t.Color or accent end
        end
        renderDetail()
    end
    for i,t in ipairs(displayTiers) do
        local col = t.Color or ACCENTS[((i - 1) % #ACCENTS) + 1]
        local b = Instance.new("TextButton"); b.Name = "Tier_" .. tostring(i)
        b.Size = UDim2.new(0,compact and 126 or 142,0,compact and 42 or 44)
        b.BackgroundColor3 = C.pHdr; b.BorderSizePixel = 0; b.Text = ""; b.AutoButtonColor = false; b.LayoutOrder = i; b.Parent = selector
        corner(10,b); local st = stroke(C.border,1,b); st.Transparency = .35
        local selectedAccent = Instance.new("Frame"); selectedAccent.Name = "TierSelectedAccent"
        selectedAccent.Size = UDim2.new(1,-24,0,2); selectedAccent.Position = UDim2.new(0,12,1,-3)
        selectedAccent.BackgroundColor3 = col; selectedAccent.BorderSizePixel = 0; selectedAccent.Visible = false
        selectedAccent.Parent = b; corner(2,selectedAccent)
        local iconNames = {"sprout","zap","crown","messages-square","code-2","flag"}
        local iconName = t.Icon or iconNames[i] or "gem"
        local iconBadge = Instance.new("Frame"); iconBadge.Name = "TierIconBadge"
        iconBadge.Size = UDim2.new(0,28,0,28); iconBadge.Position = UDim2.new(0,7,.5,-14)
        iconBadge.BackgroundColor3 = col:Lerp(C.pHdr,.78); iconBadge.BorderSizePixel = 0; iconBadge.Parent = b
        corner(8,iconBadge)
        local tierIcon = mkIcon(iconBadge,iconName,16,14)
        tierIcon.AnchorPoint = Vector2.new(.5,.5); tierIcon.Position = UDim2.fromScale(.5,.5)
        tierIcon.TextColor3 = col
        local tierImage = tierIcon:FindFirstChild("JLIconAsset")
        if tierImage then tierImage.ImageColor3 = col end
        local label = newTxt({Parent=b,Text=t.Name,Font=GB,Size=9,Color=C.dim,Sz=UDim2.new(1,-42,1,0),Pos=UDim2.new(0,42,0,0)})
        label.Name = "TierName"
        selectorButtons[i] = b
        b.Activated:Connect(function() selectTier(i) end)
    end

    local function closePopup()
        if closed then return end
        closed = true
        if watcher then JL:OffTierChanged(watcher) end
        if wheelConn then pcall(function() wheelConn:Disconnect() end) end
        tw(backdrop,{BackgroundTransparency=1},.14)
        tw(shell,{Position=UDim2.new(.5,0,.5,12)},.14)
        trackedDelay(.16,function()
            if SUB._gui == sgS then SUB._gui = nil end
            sgS:Destroy()
        end)
    end
    closeBtn.Activated:Connect(closePopup)
    backdrop.InputBegan:Connect(function(input)
        if not isPtr(input) then return end
        local p,s = shell.AbsolutePosition,shell.AbsoluteSize
        local x,y = input.Position.X,input.Position.Y
        if x < p.X or x > p.X+s.X or y < p.Y or y > p.Y+s.Y then closePopup() end
    end)
    watcher = JL:OnTierChanged(function()
        if closed then return end
        refreshCurrent()
        renderDetail()
    end)
    refreshCurrent()
    selectTier(1)
    tw(backdrop,{BackgroundTransparency=.34},.2)
    tw(shell,{Position=UDim2.new(.5,0,.5,0)},.24,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
end
