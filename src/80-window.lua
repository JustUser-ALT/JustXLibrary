function JL:Window(opts)
    opts = opts or {}
    local hubConfig = Config.Fork()
    local _cfgData = hubConfig.Data
    local _memData = hubConfig.MemoryData
    local _globalSettingsData = hubConfig.GlobalSettingsData
    local _presetSettingsOverrides = hubConfig.PresetSettingsOverrides
    local cfgLoad = function(name) return hubConfig.Load(name) end
    local cfgSave = function() return hubConfig.Save() end
    local cfgHas = function(flag) return hubConfig.Has(flag) end
    local cfgSet = function(flag, value, store) return hubConfig.Set(flag, value, store) end
    local cfgGet = function(flag, default) return hubConfig.Get(flag, default) end
    local cfgFlush = function() return hubConfig.Flush() end
    local hubId = resolveHubIdentity(opts)
    local hubTitle = tostring(opts.Title or hubId)
    Workspace.SetCurrentHubId(hubId)
    local hubEntry
    _disposed = false
    JL._perfEnabled = opts.DebugPerformance == true
    local hubStartTick = tick()
    local windowBuildStarted = os.clock()
    local iconLoadStarted = os.clock()
    if not JL._iconPack and opts.LoadIcons ~= false then
        trackedSpawn(function()
            local ok = self:LoadIconPack(opts.IconPackURL)
            if JL._perfEnabled then
                warn("[JustLib Perf] Molto icon pack: " .. string.format("%.3f s", os.clock() - iconLoadStarted) .. " (loaded=" .. tostring(ok) .. ")")
            end
        end)
    end
    -- Resolve reloads by HubId. Different hubs coexist only while Multi-Hub Tabs is enabled.
    local sameHub = _workspace.Hubs[hubId]
    if sameHub and sameHub.alive then
        local reload = restartPrompt(
            "Tab Already Running",
            "Looks like \"" .. hubTitle .. "\" is already running. Are you sure you want to reload it?",
            "Reload Tab"
        )
        if not reload then return nil end
        if type(sameHub.destroy) == "function" then
            local ok, err = pcall(sameHub.destroy)
            if not ok then warn("[JustLib] Previous hub cleanup failed: " .. tostring(err)) end
        end
    elseif _workspace.MultiHubTabsEnabled == false then
        local previousHubs = {}
        local previousTitle = "another hub"
        for _, entry in pairs(_workspace.Hubs) do
            if entry and entry.alive and type(entry.destroy) == "function" then
                previousHubs[#previousHubs + 1] = entry
                if previousTitle == "another hub" then
                    previousTitle = tostring(entry.Title or entry.HubId or previousTitle)
                end
            end
        end
        if #previousHubs > 0 then
            local replace = restartPrompt(
                "Hub Already Running",
                "Since the \"Multi-Hub Tabs\" toggle is disabled, \"" .. previousTitle .. "\" will be overwritten by \"" .. hubTitle .. "\".",
                "Replace Hub"
            )
            if not replace then return nil end
            for _, entry in ipairs(previousHubs) do
                pcall(entry.destroy)
            end
        end
    end
    -- Remove leftover UI roots if an older build stopped partway through cleanup.
    -- This also prevents orphaned Remote panels from stacking after Restart Hub.
    removeOrphanedHubGuis(hubId)
    if opts.Config then cfgLoad(opts.Config) else loadGlobalSettings() end
    JL._activeCfgSet = cfgSet
    if type(opts.Backgrounds) == "table" then for k,v in pairs(opts.Backgrounds) do JL._bgs[k] = v end end
    if opts.Background ~= nil then JL._bgs.Window = opts.Background end
    do
        local savedTheme = tostring(cfgGet("_theme", JL._userTheme or "Midnight"))
        local th = JL._themes[savedTheme]
        if th then
            for k,v in pairs(th) do if k ~= "accents" then C[k] = v end end
            if th.accents then for i,v in ipairs(th.accents) do ACCENTS[i] = v end end
            JL._currentTheme = savedTheme; JL._userTheme = savedTheme
        end
    end
    local configKey = safeFileName(opts.Config or "JustLib")
    local profFolder = opts.ConfigFolder or ("JustX/Presets/" .. configKey)
    local legacyProfFolder = tostring(opts.Config or "JustLib") .. "_Presets"
    local legacyProfilesChecked = false
    local function fsReady() return writefile and readfile and listfiles and isfile and delfile end
    local function ensureProfFolder()
        ensureFolder(profFolder)
        if legacyProfilesChecked then return end
        legacyProfilesChecked = true
        if not (listfiles and readfile and writefile) then return end
        local ok, files = pcall(listfiles, legacyProfFolder)
        if not ok or type(files) ~= "table" then return end
        for _, oldPath in ipairs(files) do
            local nm = tostring(oldPath):match("([^\\/]+)%.json$")
            if nm then
                local target = profFolder .. "/" .. safeFileName(nm) .. ".json"
                local exists = false
                if isfile then local existsOk, result = pcall(isfile, target); exists = existsOk and result == true end
                if not exists then
                    local readOk, raw = pcall(readfile, oldPath)
                    if readOk and type(raw) == "string" and raw ~= "" then pcall(writefile, target, raw) end
                end
            end
        end
    end
    local function listProfiles()
        local out = {}
        if not fsReady() then return out end
        ensureProfFolder()
        local ok,files = pcall(listfiles, profFolder)
        if not ok or type(files) ~= "table" then return out end
        for _,p in ipairs(files) do
            local nm = tostring(p):match("([^\\/]+)%.json$")
            if nm then out[#out + 1] = nm end
        end
        table.sort(out)
        return out
    end
    local function snapshotFlags()
        local out = {}
        for flag,val in pairs(_cfgData) do
            if not tostring(flag):match("^_") and not tostring(flag):match("^addon%.") and not JL._noSave[flag] then out[flag] = val end
        end
        for flag,val in pairs(_memData) do
            if not tostring(flag):match("^_") and not tostring(flag):match("^addon%.") and not JL._noSave[flag] then out[flag] = val end
        end
        if cfgGet("_preset_save_settings", false) then
            for flag,val in pairs(_cfgData) do if isLibrarySetting(flag) then out[flag] = val end end
            for flag,val in pairs(_memData) do if isLibrarySetting(flag) then out[flag] = val end end
            if _workspace.GlobalSettingsEnabled then
                for flag,val in pairs(_globalSettingsData) do if isLibrarySetting(flag) then out[flag] = val end end
            end
            for flag,val in pairs(_presetSettingsOverrides) do if isLibrarySetting(flag) then out[flag] = val end end
        end
        return out
    end
    local function saveProfile(name)
        if not fsReady() then return false end
        ensureProfFolder()
        local fileName = safeFileName(name)
        local ok = pcall(writefile, profFolder .. "/" .. fileName .. ".json", HTTP:JSONEncode(snapshotFlags()))
        return ok
    end
    local function loadProfile(name)
        if not fsReady() then return false end
        ensureProfFolder()
        local path = profFolder .. "/" .. safeFileName(name) .. ".json"
        local ok,raw = pcall(readfile, path)
        if not ok or not raw or raw == "" then return false end
        local ok2,data = pcall(HTTP.JSONDecode, HTTP, raw)
        if not ok2 or type(data) ~= "table" then return false end
        hubConfig.ClearPresetSettingsOverrides()
        hubConfig.SetApplyingPreset(true)
        for flag,val in pairs(data) do
            if isLibrarySetting(flag) and flag == "_theme" then
                pcall(function() JL:SetTheme(val) end)
            else
                local ctrl = JL._registry[flag]
                if ctrl and ctrl.Set then
                    pcall(function() ctrl:Set(val) end)
                else
                    pcall(function() cfgSet(flag, val) end)
                end
            end
        end
        hubConfig.SetApplyingPreset(false)
        if JL._notifyReposition then pcall(JL._notifyReposition) end
        if JL._remoteRefresh then pcall(JL._remoteRefresh) end
        if JL._remoteRestorePos then pcall(JL._remoteRestorePos) end
        return true
    end
    local function deleteProfile(name)
        if not fsReady() then return false end
        ensureProfFolder()
        local path = profFolder .. "/" .. safeFileName(name) .. ".json"
        if isfile(path) then return (pcall(delfile, path)) end
        return false
    end
    local sg = registerHubGui(Instance.new("ScreenGui"), "Main"); sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.DisplayOrder = 999
    local ok = pcall(function() sg.Parent = game:GetService("CoreGui") end); if not ok then sg.Parent = PG end
    local _dead = false
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280,720)
    local labelsOn = cfgGet("_sidebar_labels", opts.SidebarLabels == true)
    local SBW, GAP, PADIN, COLGAP = (labelsOn and 64 or 42), 10, 8, 8
    local CWW = math.clamp(opts.Width or 640, 340, math.max(340, vp.X - SBW - GAP - 30))
    local WH  = math.clamp(opts.Height or 420, 240, math.max(240, vp.Y - 30))
    local WW  = SBW + GAP + CWW
    local IW  = CWW - 2 * PADIN
    local VIS = math.clamp(opts.Columns or 3, 1, 6)
    local usable = IW - 8
    while VIS > 1 and (usable - (VIS - 1) * COLGAP) / VIS < 150 do VIS = VIS - 1 end
    local colW = math.floor((usable - (VIS - 1) * COLGAP) / VIS)
    local listW = usable
    local animOn    = cfgGet("_anim", true)
    local userScale = (tonumber(cfgGet("_uiscale", 100)) or 100) / 100
    local blurPct   = tonumber(cfgGet("_blur", 0)) or 0
    local backdropV = tonumber(cfgGet("_backdrop", 65)) or 65
    local hotkey    = keyFromName(cfgGet("_hotkey", opts.Hotkey and opts.Hotkey.Name or "RightShift"))
    local showFps   = cfgGet("_showfps", true)
    local function measureTextW(text,size,font,maxW)
        local ok,b = pcall(function() return TextService:GetTextSize(tostring(text), size, font, Vector2.new(maxW, 30)) end)
        return ok and b.X or (#tostring(text) * (size * 0.6))
    end
    local badgeTitle = opts.Title or "JustLib"
    local badgeOffX = opts.Icon and 32 or 10
    local badgeTitleW = math.clamp(math.ceil(measureTextW(badgeTitle, 12, GB, 260)) + 10, 30, 220)
    local badgeFpsW = 46
    local badgeW = badgeOffX + badgeTitleW + 10 + 1 + 10 + badgeFpsW + 12
    local BPOS = {
        top    = UDim2.new(0.5,-badgeW / 2,0,14),
        center = UDim2.new(0.5,-badgeW / 2,0.5,-15),
        bottom = UDim2.new(0.5,-badgeW / 2,1,-44),
    }
    local badge2 = Instance.new("Frame"); badge2.Size = UDim2.new(0,badgeW,0,30); badge2.Position = _workspace.BadgePosition or BPOS[tostring(cfgGet("_badgepos","Top")):lower()] or BPOS.top
    badge2.BackgroundColor3 = C.badge; badge2.BorderSizePixel = 0; badge2.ZIndex = 60; badge2.Parent = sg; corner(8,badge2); stroke(C.border,1,badge2)
    BG.register("Badge", badge2, 8)
    JL._activeBadge = badge2
    if opts.Icon then local ic = mkIcon(badge2,opts.Icon,18,61); ic.Position = UDim2.new(0,8,0.5,-9) end
    local badgeTitleL = newTxt({Parent=badge2,Text=badgeTitle,Font=GB,Size=12,Sz=UDim2.new(0,badgeTitleW,1,0),Pos=UDim2.new(0,badgeOffX,0,0),Z=61})
    badgeTitleL.TextTruncate = Enum.TextTruncate.None
    local divF = Instance.new("Frame"); divF.Size = UDim2.new(0,1,0,16); divF.Position = UDim2.new(0,badgeOffX + badgeTitleW + 10,0.5,-8); divF.BackgroundColor3 = C.border; divF.BorderSizePixel = 0; divF.ZIndex = 61; divF.Parent = badge2
    local fpsL = newTxt({Parent=badge2,Text="60 FPS",Font=GB,Size=12,Color=C.fpsGrn,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,badgeFpsW,1,0),Pos=UDim2.new(0,badgeOffX + badgeTitleW + 20,0,0),Z=61})
    fpsL.Visible = showFps
    -- подгоняем ширину бейджа под реальный размер текста (TextService в некоторых клиентах занижает ширину)
    do
        local t0 = os.clock()
        local function fitBadge()
            local need = math.ceil(badgeTitleL.TextBounds.X) + 10
            if need <= badgeTitleW or need > 320 then return end
            badgeTitleW = need
            badgeW = badgeOffX + badgeTitleW + 10 + 1 + 10 + badgeFpsW + 12
            BPOS.top = UDim2.new(0.5,-badgeW / 2,0,14); BPOS.center = UDim2.new(0.5,-badgeW / 2,0.5,-15); BPOS.bottom = UDim2.new(0.5,-badgeW / 2,1,-44)
            badge2.Size = UDim2.new(0,badgeW,0,30)
            badgeTitleL.Size = UDim2.new(0,badgeTitleW,1,0)
            divF.Position = UDim2.new(0,badgeOffX + badgeTitleW + 10,0.5,-8)
            fpsL.Position = UDim2.new(0,badgeOffX + badgeTitleW + 20,0,0)
            if not _workspace.BadgePosition and os.clock() - t0 < 2 then badge2.Position = BPOS[tostring(cfgGet("_badgepos","Top")):lower()] or BPOS.top end
        end
        fitBadge()
        badgeTitleL:GetPropertyChangedSignal("TextBounds"):Connect(fitBadge)
    end
    local homeFpsLabel
    local fpsConn
    do
        local _lt = tick(); local _fr = 0
        fpsConn = keep(RunSvc.Heartbeat:Connect(function()
            _fr = _fr + 1; local n = tick()
            if n - _lt >= 0.5 then
                local fps = math.round(_fr / (n - _lt)); fpsL.Text = fps .. " FPS"
                fpsL.TextColor3 = fps >= 50 and C.fpsGrn or (fps >= 30 and Color3.fromRGB(255,200,72) or Color3.fromRGB(255,82,82))
                if homeFpsLabel then homeFpsLabel.Text = tostring(fps) end
                _fr = 0; _lt = n
            end
        end))
    end
    local badgeTap = Instance.new("TextButton"); badgeTap.Size = UDim2.new(1,0,1,0); badgeTap.BackgroundTransparency = 1; badgeTap.Text = ""; badgeTap.ZIndex = 62; badgeTap.Parent = badge2
    local win = Instance.new("Frame"); win.Size = UDim2.new(0,WW,0,WH); win.AnchorPoint = Vector2.new(0.5,0.5); win.Position = UDim2.new(0.5,0,0.5,0)
    win.BackgroundTransparency = 1; win.BorderSizePixel = 0; win.Visible = false; win.ClipsDescendants = false; win.Parent = sg
    JL._activeWin = win
    local winBg = Instance.new("Frame"); winBg.Name = "JLWindowBg"; winBg.Size = UDim2.new(1,0,1,0); winBg.BackgroundTransparency = 1; winBg.BorderSizePixel = 0; winBg.ZIndex = 0; winBg.Parent = win
    BG.register("Window", winBg, 12)
    local uiScale = Instance.new("UIScale"); uiScale.Scale = userScale; uiScale.Parent = win
    local function unscaleWin(px)
        local s = uiScale.Scale; if not s or s <= 0 then s = 1 end
        return px / s
    end
    local backdrop = Instance.new("Frame"); backdrop.Size = UDim2.new(0,CWW,0,WH); backdrop.Position = UDim2.new(0,SBW + GAP,0,0)
    backdrop.BackgroundColor3 = C.backdrop; backdrop.BackgroundTransparency = (opts.Backdrop == false) and 1 or (1 - backdropV / 100); backdrop.BorderSizePixel = 0; backdrop.Parent = win
    corner(12,backdrop); local bdStroke = stroke(C.border,1,backdrop); bdStroke.Transparency = 0.35
    local SBMODE = (opts.SidebarOverflow == "Columns") and "Columns" or "Scroll"
    local SBMAX = math.max(1, math.floor(tonumber(opts.MaxTabsPerColumn) or 5))
    local COLSP = 6
    local sbCols = {}
    local sbBtns = {}
    local sbQueued = false
    local function placeCol(col,x,animate)
        local h = col.frame.Size.Y.Offset
        local target = UDim2.new(0,x,0.5,-h / 2)
        col.x = x
        if animate then tw(col.frame,{Position = target},.28,Enum.EasingStyle.Quart,Enum.EasingDirection.Out) else col.frame.Position = target end
    end
    local function newSbColumn()
        local f = Instance.new("Frame"); f.Size = UDim2.new(0,SBW,0,0); f.Position = UDim2.new(0,0,0.5,0); f.BackgroundColor3 = C.sidebar; f.BorderSizePixel = 0; f.Parent = win
        corner(12,f); stroke(C.border,1,f)
        BG.register("Sidebar", f, 12)
        local sc = Instance.new("ScrollingFrame"); sc.Size = UDim2.new(1,0,1,0); sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0; sc.ScrollBarThickness = 0
        sc.ScrollingDirection = Enum.ScrollingDirection.Y; sc.CanvasSize = UDim2.new(0,0,0,0); sc.ClipsDescendants = true; sc.Parent = f
        local ls = Instance.new("UIListLayout"); ls.FillDirection = Enum.FillDirection.Vertical; ls.HorizontalAlignment = Enum.HorizontalAlignment.Center
        ls.VerticalAlignment = Enum.VerticalAlignment.Top; ls.Padding = UDim.new(0,8); ls.SortOrder = Enum.SortOrder.LayoutOrder; ls.Parent = sc; pad(0,0,10,10,sc)
        local col = {frame = f, scroll = sc, list = ls, x = nil}
        local function stepScroll(dir)
            local vh = unscaleWin(sc.AbsoluteWindowSize.Y)
            local maxY = math.max(0, unscaleWin(sc.AbsoluteCanvasSize.Y) - vh)
            local step = (labelsOn and 54 or 38) * 2
            local target = math.clamp(sc.CanvasPosition.Y + dir * step, 0, maxY)
            tw(sc,{CanvasPosition = Vector2.new(0,target)},.22)
        end
        local function mkArrow(up)
            local a = Instance.new("Frame"); a.Size = UDim2.new(1,-2,0,24); a.Position = up and UDim2.new(0,1,0,1) or UDim2.new(0,1,1,-25)
            a.BackgroundColor3 = C.sidebar; a.BorderSizePixel = 0; a.ZIndex = 20; a.Visible = false; a.Parent = f
            local g = Instance.new("UIGradient"); g.Rotation = 90
            g.Transparency = NumberSequence.new(up and {NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.6,0.15),NumberSequenceKeypoint.new(1,1)} or {NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.4,0.15),NumberSequenceKeypoint.new(1,0)})
            g.Parent = a; corner(11, a) -- те же скругления, что у рамки сайдбара
            local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,16); b.Position = up and UDim2.new(0,0,0,0) or UDim2.new(0,0,1,-16)
            b.BackgroundTransparency = 1; b.Text = ""; b.AutoButtonColor = false; b.ZIndex = 21; b.Parent = a
            local gi
            if JL._iconPack then
                gi = mkIcon(b, up and "chevron-up" or "chevron-down", 12, 22)
                if gi:IsA("TextLabel") then gi:Destroy(); gi = nil end
            end
            if gi then
                gi.ImageColor3 = C.dim; gi.AnchorPoint = Vector2.new(0.5,0.5); gi.Position = UDim2.new(0.5,0,0.5,0)
            else
                newTxt({Parent=b,Text = up and "^" or "v",Font=GB,Size=12,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Z=22})
            end
            b.MouseButton1Click:Connect(function() stepScroll(up and -1 or 1) end)
            return a
        end
        col.up = mkArrow(true); col.down = mkArrow(false)
        local function updArrows()
            -- стрелка показывается только если за краем есть вкладки (отступ 10px сверху и снизу не считается)
            local vh = unscaleWin(sc.AbsoluteWindowSize.Y); local y = sc.CanvasPosition.Y
            local bottom = unscaleWin(ls.AbsoluteContentSize.Y) + 10
            col.up.Visible = y > 10
            col.down.Visible = y + vh < bottom - 2
        end
        local function fit()
            local ch = unscaleWin(ls.AbsoluteContentSize.Y) + 20
            local h = math.min(ch, WH)
            sc.CanvasSize = UDim2.new(0,0,0,ch)
            f.Size = UDim2.new(0,SBW,0,h)
            f.Position = UDim2.new(0,col.x or 0,0.5,-h / 2)
            updArrows()
        end
        ls:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
        sc:GetPropertyChangedSignal("CanvasPosition"):Connect(updArrows)
        sc:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updArrows)
        sc:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updArrows)
        return col
    end
    local function relayoutSidebar()
        local vis = {}
        for id,b in pairs(sbBtns) do if b.Visible then vis[#vis + 1] = id end end
        table.sort(vis)
        local n = #vis
        local cap, ncol = math.huge, 1
        if SBMODE == "Columns" and n > 0 then
            local camV = workspace.CurrentCamera
            local vw = camV and camV.ViewportSize.X or 1280
            local leftRoom = (vw / math.max(userScale, 0.1) - WW) / 2 - 6
            local maxCols = math.max(1, 1 + math.floor(leftRoom / (SBW + COLSP)))
            cap = math.max(SBMAX, math.ceil(n / maxCols))
            ncol = math.max(1, math.ceil(n / cap))
        end
        while #sbCols < ncol do sbCols[#sbCols + 1] = newSbColumn() end
        for i,col in ipairs(sbCols) do
            col.frame.Visible = i <= ncol
            local x = -(ncol - i) * (SBW + COLSP)
            if col.x == nil then placeCol(col, x, false) elseif col.x ~= x then placeCol(col, x, true) end
        end
        for k,id in ipairs(vis) do
            local ci = (cap == math.huge) and 1 or math.ceil(k / cap)
            sbBtns[id].Parent = sbCols[ci].scroll
        end
    end
    local function queueSidebar()
        if sbQueued then return end
        sbQueued = true
        trackedDefer(function()
            sbQueued = false
            if not _dead then relayoutSidebar() end
        end)
    end
    local function revealTab(id)
        local b = sbBtns[id]; if not b then return end
        local sc = b.Parent; if not (sc and sc:IsA("ScrollingFrame")) then return end
        local rel = unscaleWin(b.AbsolutePosition.Y - sc.AbsolutePosition.Y)
        local bh = unscaleWin(b.AbsoluteSize.Y); local vh = unscaleWin(sc.AbsoluteWindowSize.Y)
        local y = sc.CanvasPosition.Y; local target = y
        if rel < 24 then target = y + rel - 24 elseif rel + bh > vh - 24 then target = y + rel + bh - vh + 24 end
        local maxY = math.max(0, unscaleWin(sc.AbsoluteCanvasSize.Y) - vh)
        target = math.clamp(target, 0, maxY)
        if math.abs(target - y) > 0.5 then tw(sc,{CanvasPosition = Vector2.new(0,target)},.2) end
    end
    relayoutSidebar()
    local content = Instance.new("Frame"); content.Size = UDim2.new(0,CWW,0,WH); content.Position = UDim2.new(0,SBW + GAP,0,0)
    content.BackgroundTransparency = 1; content.ClipsDescendants = true; content.Parent = win
    local tip = Instance.new("Frame"); tip.BackgroundColor3 = Color3.fromRGB(18,18,20); tip.BorderSizePixel = 0; tip.Visible = false; tip.ZIndex = 200; tip.Parent = win
    corner(6,tip); stroke(C.border,1,tip); pad(9,9,5,5,tip)
    local tipL = newTxt({Parent=tip,Text="",Font=GB,Size=11,Wrap=true,XAlign=Enum.TextXAlignment.Center,Z=201})
    local function showTip(guiObject,text)
        local maxW = 240
        local sz = TextService:GetTextSize(text, 11, GB, Vector2.new(maxW,200))
        local w = math.min(sz.X + 18, maxW + 18); local h = math.min(sz.Y + 10, 90)
        local rel = (guiObject.AbsolutePosition - win.AbsolutePosition) / uiScale.Scale
        local osz = guiObject.AbsoluteSize / uiScale.Scale
        local side = tostring(cfgGet("_tooltip_side","Right"))
        local x,y
        if side == "Left" then x = rel.X - w - 8; y = rel.Y + osz.Y / 2 - h / 2
        elseif side == "Top" then x = rel.X + osz.X / 2 - w / 2; y = rel.Y - h - 8
        elseif side == "Bottom" then x = rel.X + osz.X / 2 - w / 2; y = rel.Y + osz.Y + 8
        else x = rel.X + osz.X + 8; y = rel.Y + osz.Y / 2 - h / 2 end
        tip.Size = UDim2.new(0,w,0,h); tip.Position = UDim2.new(0, x, 0, y); tipL.Text = text; tip.Visible = true
    end
    local function hideTip() tip.Visible = false end
    local function attachTip(guiObject,text)
        if not text or text == "" then return end
        guiObject.MouseEnter:Connect(function() showTip(guiObject, text) end)
        guiObject.MouseLeave:Connect(hideTip)
    end
    local TABPOS = UDim2.new(0,PADIN,0,PADIN + 36)
    local function offPos(dir) return UDim2.new(dir,PADIN,0,PADIN) end
    local tabFrames = {}; local tabUI = {}; local tabScrollers = {}; local activeTabId = nil; local _tabCount = 0
    local function styleTab(id,active)
        local u = tabUI[id]; if not u then return end
        tw(u.btn,{BackgroundColor3 = active and Color3.fromRGB(24,44,74) or Color3.fromRGB(34,34,40)},.15)
        local col = active and ACCENTS[1] or C.dim
        if u.icon:IsA("TextLabel") then u.icon.TextColor3 = col else u.icon.ImageColor3 = col end
        if u.label then u.label.TextColor3 = col end
        u.ind.Visible = active
    end
    local function switchToTab(id)
        local prev = activeTabId
        if prev == id then return end
        local dir = (prev and id > prev) and 1 or -1
        for tid,fr in pairs(tabFrames) do
            if tid == id then
                fr.Visible = true
                if prev and animOn then fr.Position = offPos(dir); tw(fr,{Position = TABPOS},.22) else fr.Position = TABPOS end
            elseif tid == prev and animOn then
                tw(fr,{Position = offPos(-dir)},.22)
                trackedDelay(.23, function() if activeTabId ~= tid then fr.Visible = false end end)
            else
                fr.Visible = false
            end
        end
        for tid in pairs(tabUI) do styleTab(tid, tid == id) end
        activeTabId = id
        revealTab(id)
    end
    local blurObj
    local function applyBlur()
        if blurPct > 0 and JL._winOpen then
            if not blurObj or not blurObj.Parent then blurObj = Instance.new("BlurEffect"); blurObj.Name = "JLBlur"; blurObj.Parent = game:GetService("Lighting") end
            blurObj.Size = math.round(blurPct * 56 / 100); blurObj.Enabled = true
        elseif blurObj then blurObj.Enabled = false end
    end
    local isOpen = false
    local workspaceVisible = true
    local function setWorkspaceVisible(visible)
        if _dead then return false end
        workspaceVisible = visible == true
        win.Visible = workspaceVisible and isOpen
        badge2.Visible = workspaceVisible and not isOpen
        JL._winOpen = workspaceVisible and isOpen
        if hubEntry and hubEntry.alive and _workspace.Hubs[hubId] == hubEntry and _workspace.HubTabsFrame and _workspace.ActiveHubId == hubId then
            _workspace.HubTabsFrame.Visible = workspaceVisible and isOpen and _workspace.HubTabsFrame.Parent == win
        end
        applyBlur()
        return true
    end
    local function openW()
        if _dead then return end
        isOpen = true; JL._winOpen = workspaceVisible; win.Visible = workspaceVisible; badge2.Visible = false
        if hubEntry and hubEntry.alive and _workspace.Hubs[hubId] == hubEntry and _workspace.HubTabsFrame and _workspace.ActiveHubId == hubId then
            _workspace.HubTabsFrame.Visible = workspaceVisible and _workspace.HubTabsFrame.Parent == win
        end
        if animOn then uiScale.Scale = userScale * 0.88; tw(uiScale,{Scale = userScale},.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out) else uiScale.Scale = userScale end
        tw(badge2,{BackgroundColor3 = C.badgeHi},.15); applyBlur(); pcall(refreshWorkspaceTabs)
    end
    local function closeW()
        if _dead then return end
        isOpen = false; JL._winOpen = false; badge2.Visible = workspaceVisible
        if hubEntry and hubEntry.alive and _workspace.Hubs[hubId] == hubEntry and _workspace.HubTabsFrame and _workspace.ActiveHubId == hubId then
            _workspace.HubTabsFrame.Visible = false
        end
        if animOn then
            tw(uiScale,{Scale = userScale * 0.88},.18,Enum.EasingStyle.Quart,Enum.EasingDirection.In)
            trackedDelay(.19, function() if not isOpen or not workspaceVisible then win.Visible = false end end)
        else win.Visible = false end
        tw(badge2,{BackgroundColor3 = C.badge},.15); applyBlur(); pcall(refreshWorkspaceTabs)
    end
    draggable(badgeTap, badge2, function() if isOpen then closeW() else openW() end end, function(position)
        _workspace.BadgePosition = position
    end)
    keep(UIS.InputBegan:Connect(function(i,gp)
        if gp or JL._listening then return end
        if hotkey and i.KeyCode == hotkey then if isOpen then closeW() else openW() end end
    end))
    keep(UIS.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseWheel or not JL._winOpen or not UIS:IsKeyDown(Enum.KeyCode.LeftShift) then return end
        local t = tabScrollers[activeTabId]; if not t then return end
        local m = UIS:GetMouseLocation(); local ap,as = content.AbsolutePosition, content.AbsoluteSize
        if m.X < ap.X or m.X > ap.X + as.X or m.Y < ap.Y or m.Y > ap.Y + as.Y then return end
        t.go(t.cur() + (i.Position.Z > 0 and -1 or 1))
    end))
    local function destroyHub()
        if _dead then return end
        _dead = true; isOpen = false; JL._winOpen = false
        if hubEntry then hubEntry.alive = false end
        if hubEntry and _workspace.Hubs[hubId] == hubEntry then
            _workspace.Hubs[hubId] = nil
            if _workspace.ActiveHubId == hubId then
                _workspace.ActiveHubId = nil
                for otherId, otherEntry in pairs(_workspace.Hubs) do
                    if otherEntry and otherEntry.alive then
                        _workspace.ActiveHubId = otherId
                        break
                    end
                end
                if _workspace.ActiveHubId and _workspace.SetActiveHub then
                    _workspace.SetActiveHub(_workspace.ActiveHubId, true)
                end
            end
        end
        refreshWorkspaceTabs()
        JL._searchRegister = nil
        if JL._searchEntries then for k in pairs(JL._searchEntries) do JL._searchEntries[k] = nil end end
        if JL._searchPageTargets then for k in pairs(JL._searchPageTargets) do JL._searchPageTargets[k] = nil end end
        _disposed = true
        if shared._JLActive and shared._JLActive.destroy == destroyHub then
            shared._JLActive = nil
            local activeId = _workspace.ActiveHubId
            local activeEntry = activeId and _workspace.Hubs[activeId]
            if activeEntry and activeEntry.alive then shared._JLActive = activeEntry end
        end
        pcall(function() fpsConn:Disconnect() end)
        for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
        _conns = {}
        -- Cleanup must never abort the final GUI destruction.
        pcall(cleanupResources)
        pcall(function() if blurObj then blurObj:Destroy() end end)
        local hooks = {}
        for k,fn in ipairs(JL._unloadHooks) do hooks[k] = fn end
        for k = #JL._unloadHooks, 1, -1 do JL._unloadHooks[k] = nil end
        for _,fn in ipairs(hooks) do pcall(fn) end
        for k = #JL._themeHooks, 1, -1 do JL._themeHooks[k] = nil end
        for k = #JL._extraRoots, 1, -1 do
            local root = JL._extraRoots[k]
            if root then pcall(cleanupResource, root) end
            JL._extraRoots[k] = nil
        end
        JL._preview = nil
        for i = #_hubGuiRoots, 1, -1 do
            local root = _hubGuiRoots[i]
            _hubGuiRoots[i] = nil
            if root then pcall(function() root:Destroy() end) end
        end
        pcall(function() if sg and sg.Parent then sg:Destroy() end end)
        _cpSg = nil
        if JL._destroyActive == destroyHub then JL._destroyActive = nil end
        if JL._activeWin == win then JL._activeWin = nil end
        if JL._activeBadge == badge2 then JL._activeBadge = nil end
    end
    local Win = {}
    function Win:Open() if not isOpen then openW() end end
    function Win:Close() if isOpen then closeW() end end
    function Win:Toggle() if isOpen then closeW() else openW() end end
    function Win:Destroy() destroyHub() end
    function Win:Unload() destroyHub() end
    function Win:IsOpen() return isOpen end
    function Win:SetWorkspaceVisible(visible) return setWorkspaceVisible(visible) end
    function Win:IsWorkspaceVisible() return workspaceVisible end
    function Win:Track(resource, cleanup) return JL:Track(resource, cleanup) end
    function Win:Connect(signal, callback) return JL:Connect(signal, callback) end
    function Win:Spawn(callback, ...) return JL:Spawn(callback, ...) end
    function Win:Delay(seconds, callback, ...) return JL:Delay(seconds, callback, ...) end
    function Win:Defer(callback, ...) return JL:Defer(callback, ...) end
    function Win:OnUnload(callback) return JL:OnUnload(callback) end
    function Win:IsAlive() return JL:IsAlive() end
    JL._win = Win
    JL._bridge.getWin = function() if _dead then return nil end return Win end
    JL._bridge.getScale = function() return uiScale.Scale end
    JL._bridge.getContentSize = function() return CWW - 2 * PADIN, WH - 2 * PADIN end
    function Win:Notify(c) return JL:Notify(c) end
    function Win:SetBackground(kind,cfg) JL:SetBackground(kind,cfg) end
    function Win:ClearBackground(kind) JL:SetBackground(kind,nil) end
    GUIDE.nav = function(row)
        if not (row and row.Parent) then return end
        if not isOpen then openW(); task.wait(.3) end
        local tabId, p = nil, row
        while p and p ~= win do
            for tid,fr in pairs(tabFrames) do if fr == p then tabId = tid end end
            if tabId then break end
            p = p.Parent
        end
        if tabId and tabId ~= activeTabId then switchToTab(tabId); task.wait(.35) end
        local q, expanded = row.Parent, false
        while q and q ~= win do
            local pageSelect = JL._searchPageTargets[q]
            if pageSelect and pageSelect() then expanded = true end
            local sec = JL._secPanels[q]
            if sec and sec:IsCollapsed() then sec:SetCollapsed(false); expanded = true end
            q = q.Parent
        end
        if expanded then task.wait(.35) end
        local sc, panel
        q = row.Parent
        while q and q ~= win do
            if not panel and JL._secPanels[q] then panel = q end
            if q:IsA("ScrollingFrame") then sc = q; break end
            q = q.Parent
        end
        if not sc then return end
        local scale = math.max(uiScale.Scale, 0.01)
        local rowTop = (row.AbsolutePosition.Y - sc.AbsolutePosition.Y) / scale
        local rowH = row.AbsoluteSize.Y / scale
        local viewH = sc.AbsoluteWindowSize.Y / scale
        local maxY = math.max(0, sc.AbsoluteCanvasSize.Y / scale - viewH)
        local ty = math.clamp(sc.CanvasPosition.Y + rowTop - (viewH - rowH) / 2, 0, maxY)
        local tx = sc.CanvasPosition.X
        if panel and sc.ScrollingDirection ~= Enum.ScrollingDirection.Y then
            local viewW = sc.AbsoluteWindowSize.X / scale
            local maxX = math.max(0, sc.AbsoluteCanvasSize.X / scale - viewW)
            tx = math.clamp(sc.CanvasPosition.X + (panel.AbsolutePosition.X - sc.AbsolutePosition.X) / scale, 0, maxX)
        end
        tw(sc,{CanvasPosition = Vector2.new(tx,ty)},.45)
        task.wait(.5)
    end
    local searchEntries = {}
    JL._searchEntries = searchEntries
    local topBar = Instance.new("Frame")
    topBar.Name = "JLTopBar"
    topBar.Size = UDim2.new(0,CWW,0,42)
    topBar.Position = UDim2.new(0,SBW + GAP,0,0)
    topBar.BackgroundColor3 = C.sidebar
    topBar.BorderSizePixel = 0
    topBar.Parent = win
    topBar.ZIndex = 70
    corner(12,topBar)
    local topBarDivider = Instance.new("Frame")
    topBarDivider.Name = "JLTopBarDivider"
    topBarDivider.Size = UDim2.new(1,-24,0,2)
    topBarDivider.Position = UDim2.new(0,12,1,-2)
    topBarDivider.BackgroundColor3 = C.border
    topBarDivider.BorderSizePixel = 0
    topBarDivider.Parent = topBar
    topBarDivider.ZIndex = 71
    corner(1,topBarDivider)
    local searchButton = Instance.new("Frame")
    searchButton.Name = "JLGlobalSearchButton"
    searchButton.Size = UDim2.new(0,132,0,28)
    searchButton.Position = UDim2.new(1,-(PADIN + 102 + 132),0,5)
    searchButton.BackgroundColor3 = C.panel
    searchButton.BorderSizePixel = 0
    searchButton.Parent = win
    searchButton.ZIndex = 80
    corner(9,searchButton); stroke(C.border,1,searchButton)
    local searchButtonIcon = mkIcon(searchButton,"search",15,81)
    searchButtonIcon.Position = UDim2.new(0,10,0.5,-7)
    searchButtonIcon.Size = UDim2.new(0,15,0,14)
    if searchButtonIcon:IsA("TextLabel") then searchButtonIcon.TextColor3 = C.dim end
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "JLGlobalSearchInput"
    searchBox.Size = UDim2.new(1,-42,1,0)
    searchBox.Position = UDim2.new(0,34,0,0)
    searchBox.BackgroundTransparency = 1
    searchBox.BorderSizePixel = 0
    searchBox.ClearTextOnFocus = false
    searchBox.PlaceholderText = "Search controls"
    searchBox.PlaceholderColor3 = C.dim
    searchBox.Text = ""
    searchBox.TextColor3 = C.txt
    searchBox.TextSize = 11
    searchBox.Font = GM
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.Parent = searchButton
    searchBox.ZIndex = 82
    local function windowActionButton(name,label,x,color,callback)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.new(0,26,0,28)
        button.Position = UDim2.new(1,-(PADIN + x + 26),0,5)
        button.BackgroundColor3 = C.panel
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Text = label
        button.Font = GB
        button.TextSize = 16
        button.TextColor3 = color or C.txt
        button.Parent = win
        button.ZIndex = 80
        corner(8,button); stroke(C.border,1,button)
        button.MouseEnter:Connect(function() if not touchLast() then tw(button,{BackgroundColor3 = C.btnHov},.1) end end)
        button.MouseLeave:Connect(function() tw(button,{BackgroundColor3 = C.panel},.1) end)
        button.MouseButton1Click:Connect(callback)
        return button
    end
    windowActionButton("JLMinimizeButton","—",40,C.txt,function()
        closeW()
    end)
    windowActionButton("JLUnloadButton","X",0,Color3.fromRGB(255,255,255),function()
        if not showWorkspaceCloseDialog() and unloadDialog() then destroyHub() end
    end)
    local searchWidth = math.max(160,math.min(260,CWW - 2 * PADIN))
    local searchPanel = Instance.new("Frame")
    searchPanel.Name = "JLGlobalSearchPanel"
    searchPanel.Size = UDim2.new(0,searchWidth,0,0)
    searchPanel.Position = UDim2.new(1,-(PADIN + 102 + searchWidth),0,38)
    searchPanel.BackgroundColor3 = C.panel
    searchPanel.BorderSizePixel = 0
    searchPanel.Visible = false
    searchPanel.ClipsDescendants = true
    searchPanel.Parent = win
    searchPanel.ZIndex = 81
    corner(10,searchPanel); stroke(C.border,1,searchPanel)
    local searchResults = Instance.new("ScrollingFrame")
    searchResults.Name = "JLGlobalSearchResults"
    searchResults.Size = UDim2.new(1,-10,1,-10)
    searchResults.Position = UDim2.new(0,5,0,5)
    searchResults.BackgroundTransparency = 1
    searchResults.BorderSizePixel = 0
    searchResults.ScrollBarThickness = 3
    searchResults.ScrollBarImageColor3 = C.border
    searchResults.CanvasSize = UDim2.new(0,0,0,0)
    searchResults.Parent = searchPanel
    searchResults.ZIndex = 82
    local resultLayout = Instance.new("UIListLayout")
    resultLayout.Padding = UDim.new(0,4)
    resultLayout.SortOrder = Enum.SortOrder.LayoutOrder
    resultLayout.Parent = searchResults
    resultLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        searchResults.CanvasSize = UDim2.new(0,0,0,resultLayout.AbsoluteContentSize.Y + 4)
    end)
    local function searchPath(row)
        local tabName, sectionName, pageName
        local p = row
        while p and p ~= win do
            local page = p:GetAttribute("JLSearchPage")
            if page then pageName = page end
            local section = p:GetAttribute("JLSearchSection")
            if section then sectionName = section end
            for id,frame in pairs(tabFrames) do
                if frame == p then
                    local ui = tabUI[id]
                    tabName = ui and ui.name or ("Tab " .. tostring(id))
                    break
                end
            end
            p = p.Parent
        end
        local parts = {}
        if tabName then parts[#parts + 1] = tabName end
        if sectionName then parts[#parts + 1] = sectionName end
        if pageName then parts[#parts + 1] = pageName end
        return table.concat(parts,"  ›  ")
    end
    local function addSearchEntry(entry)
        if not entry or not entry.Row then return end
        entry.Path = searchPath(entry.Row)
        entry.SearchText = (tostring(entry.Name or "") .. " " .. tostring(entry.Kind or "") .. " " .. tostring(entry.ParentName or "") .. " " .. tostring(entry.Path or "")):lower()
        searchEntries[#searchEntries + 1] = entry
        return entry
    end
    JL._searchRegister = addSearchEntry
    local function clearSearchResults()
        for _,child in ipairs(searchResults:GetChildren()) do
            if child ~= resultLayout then child:Destroy() end
        end
    end
    local function refreshSearch()
        clearSearchResults()
        local query = searchBox.Text:lower():gsub("^%s+",""):gsub("%s+$","")
        if query == "" then
            searchPanel.Visible = false
            searchPanel.Size = UDim2.new(0,searchWidth,0,0)
            return
        end
        local matches = {}
        local indexedRows = {}
        for _,entry in ipairs(searchEntries) do
            local currentRow = entry.Control and entry.Control.Row or entry.Row
            if currentRow then indexedRows[currentRow] = true end
            if currentRow and currentRow.Parent and entry.SearchText:find(query,1,true) then
                entry.Row = currentRow
                matches[#matches + 1] = entry
            end
        end
        local function insideIndexedControl(object,tabFrame)
            local parent = object
            while parent and parent ~= tabFrame do
                if indexedRows[parent] then return true end
                parent = parent.Parent
            end
            return false
        end
        for _,tabFrame in pairs(tabFrames) do
            for _,object in ipairs(tabFrame:GetDescendants()) do
                if (object:IsA("TextButton") or object:IsA("TextBox")) and not insideIndexedControl(object,tabFrame) then
                    local label = object:IsA("TextBox") and object.PlaceholderText or object.Text
                    if not label or label == "" then
                        local childLabel = object:FindFirstChildWhichIsA("TextLabel",true)
                        label = childLabel and childLabel.Text or ""
                    end
                    label = tostring(label or "")
                    if label ~= "" then
                        local kind = object:IsA("TextBox") and "Input" or "Button"
                        local path = searchPath(object)
                        local searchText = (label .. " " .. kind .. " " .. path):lower()
                        if searchText:find(query,1,true) then
                            matches[#matches + 1] = {Name = label, Kind = kind, Path = path, SearchText = searchText, Row = object}
                        end
                    end
                end
            end
        end
        table.sort(matches,function(a,b)
            local an, bn = tostring(a.Name):lower(), tostring(b.Name):lower()
            if an ~= bn then return an < bn end
            return a.Path < b.Path
        end)
        for i = 1,math.min(#matches,60) do
            local entry = matches[i]
            local item = Instance.new("TextButton")
            item.Name = "JLSearchResult"
            item.Size = UDim2.new(1,-2,0,50)
            item.BackgroundColor3 = C.btnBg
            item.BorderSizePixel = 0
            item.AutoButtonColor = false
            item.Text = ""
            item.LayoutOrder = i
            item.Parent = searchResults
            item.ZIndex = 83
            corner(8,item); stroke(C.border,1,item)
            local resultDot = Instance.new("Frame")
            resultDot.Size = UDim2.new(0,3,0,24)
            resultDot.Position = UDim2.new(0,0,0.5,-12)
            resultDot.BackgroundColor3 = ACCENTS[1]
            resultDot.BorderSizePixel = 0
            resultDot.Parent = item
            resultDot.ZIndex = 84
            corner(2,resultDot)
            newTxt({Parent=item,Text=tostring(entry.Name),Font=GB,Size=12,Color=C.txt,Sz=UDim2.new(1,-28,0,17),Pos=UDim2.new(0,12,0,6),Z=84})
            newTxt({Parent=item,Text=(entry.Path ~= "" and entry.Path or "General") .. (entry.ParentName and ("  ›  " .. entry.ParentName) or "") .. "   ·   " .. tostring(entry.Kind),Font=GM,Size=9,Color=C.dim,Sz=UDim2.new(1,-28,0,14),Pos=UDim2.new(0,12,0,27),Z=84})
            item.MouseEnter:Connect(function() if not touchLast() then tw(item,{BackgroundColor3=C.btnHov},.1) end end)
            item.MouseLeave:Connect(function() tw(item,{BackgroundColor3=C.btnBg},.1) end)
            item.MouseButton1Click:Connect(function()
                searchPanel.Visible = false
                searchButton.Visible = true
                entry.Row = entry.Control and entry.Control.Row or entry.Row
                if entry.OpenValue and entry.Control and entry.Control.OpenValue then
                    pcall(entry.Control.OpenValue,entry.Control,entry.OpenValue)
                elseif entry.Control and entry.Control.Open then
                    pcall(entry.Control.Open,entry.Control)
                end
                trackedSpawn(function()
                    task.wait(.28)
                    local navRow = entry.Control and entry.Control.Row or entry.Row
                    if navRow and navRow.Parent then
                        GUIDE.nav(navRow)
                        local pulseRow = entry.TargetResolver and entry.TargetResolver() or entry.TargetRow
                        if entry.NestedIndex then
                            if pulseRow and pulseRow.Parent then GUIDE.pulse(pulseRow,2.6) end
                        else
                            GUIDE.pulse(pulseRow and pulseRow.Parent and pulseRow or navRow,2.6)
                        end
                    end
                end)
            end)
        end
        if #matches == 0 then
            newTxt({Parent=searchResults,Text="No results found",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-12,0,24),Pos=UDim2.new(0,6,0,6),Z=84})
        end
        local visibleCount = math.min(#matches,4)
        local panelHeight = #matches == 0 and 42 or (visibleCount * 54 + 10)
        searchPanel.Visible = true
        searchPanel.Size = UDim2.new(0,searchWidth,0,panelHeight)
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(refreshSearch)
    local function openSearch(capture)
        refreshSearch()
        if capture then trackedDefer(function() pcall(function() searchBox:CaptureFocus() end) end) end
    end
    searchBox.Focused:Connect(function()
        openSearch(false)
    end)
    searchBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            pcall(function() searchBox:ReleaseFocus() end)
        end
    end)
    local function pointInside(guiObject,point)
        if not guiObject or not guiObject.Visible then return false end
        local pos,size = guiObject.AbsolutePosition,guiObject.AbsoluteSize
        return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
    end
    keep(UIS.InputBegan:Connect(function(input)
        if not searchPanel.Visible then return end
        local inputType = input.UserInputType
        if inputType ~= Enum.UserInputType.Touch and inputType ~= Enum.UserInputType.MouseButton1 then return end
        local point = Vector2.new(input.Position.X,input.Position.Y)
        if pointInside(searchButton,point) or pointInside(searchPanel,point) then return end
        searchPanel.Visible = false
        searchPanel.Size = UDim2.new(0,searchWidth,0,0)
    end))
    function Win:Search(query)
        if query ~= nil then searchBox.Text = tostring(query) end
        openSearch(true)
        return true
    end
    function Win:GoTo(target)
        local el = type(target) == "string" and JL._registry[target] or target
        local row = (typeof(target) == "Instance") and target or (type(el) == "table" and el.Row)
        if not row then return false end
        trackedSpawn(function() GUIDE.nav(row); GUIDE.pulse(row, 2.4) end)
        return true
    end
    function Win:Tab(topts)
        topts = topts or {}; local typ = topts.Type or "Grid"; _tabCount = _tabCount + 1; local id = _tabCount
        local btn = Instance.new("TextButton"); btn.Size = labelsOn and UDim2.new(0,SBW - 12,0,46) or UDim2.new(0,30,0,30); btn.BackgroundColor3 = Color3.fromRGB(34,34,40); btn.Text = ""; btn.AutoButtonColor = false
        btn.BorderSizePixel = 0; btn.LayoutOrder = id; btn.Parent = sbCols[1].scroll; corner(8,btn)
        sbBtns[id] = btn; btn:GetPropertyChangedSignal("Visible"):Connect(queueSidebar); queueSidebar()
        local ic = mkIcon(btn, topts.Icon or "◼", 16, 14); ic.Position = labelsOn and UDim2.new(0.5,-8,0,8) or UDim2.new(0.5,-8,0.5,-8); ic.Size = UDim2.new(0,16,0,16)
        local tabLabel
        if labelsOn then tabLabel = newTxt({Parent=btn,Text=topts.Name or "",Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-4,0,12),Pos=UDim2.new(0,2,0,28),Z=14}) end
        if ic:IsA("TextLabel") then ic.TextColor3 = C.dim else ic.ImageColor3 = C.dim end
        local ind = Instance.new("Frame"); ind.Size = UDim2.new(0,3,0,14); ind.Position = UDim2.new(0,-5,0.5,-7); ind.BackgroundColor3 = ACCENTS[1]; ind.BorderSizePixel = 0; ind.Visible = false; ind.Parent = btn; corner(2,ind)
        tabUI[id] = {btn = btn, icon = ic, ind = ind, label = tabLabel, name = topts.Name or ("Tab " .. tostring(id))}
        attachTip(btn, topts.Tooltip or topts.Name)
        local tabLock = attachLockHidden(btn, {Locked = topts.Locked, Hidden = topts.Hidden, LockedMessage = topts.LockedMessage, LockedTitle = topts.LockedTitle, Requires = topts.Requires, HiddenUntil = topts.HiddenUntil, OpenStore = topts.OpenStore})
        local tabFrame = Instance.new("Frame"); tabFrame.Size = UDim2.new(1,-2 * PADIN,1,-2 * PADIN - 36); tabFrame.Position = TABPOS
        tabFrame.BackgroundTransparency = 1; tabFrame.Visible = false; tabFrame.Parent = content
        tabFrames[id] = tabFrame
        btn.MouseButton1Click:Connect(function() switchToTab(id) end)
        if not activeTabId and not topts.Hidden then activeTabId = id; tabFrame.Visible = true; styleTab(id,true) end
        local Tab = {Frame = tabFrame, Id = id}
        function Tab:SetLocked(v) tabLock.SetLocked(nil, v) end
        function Tab:SetHidden(v)
            tabLock.SetHidden(nil, v)
            if v and activeTabId == id then
                for otherId,fr in pairs(tabFrames) do
                    if otherId ~= id and tabUI[otherId] and tabUI[otherId].btn.Visible then switchToTab(otherId); break end
                end
            end
        end
        function Tab:IsLocked() return tabLock.IsLocked() end
        function Tab:IsHidden() return tabLock.IsHidden() end
        function Tab:ToggleLocked() return tabLock.ToggleLocked() end
        function Tab:ToggleHidden() local v = not tabLock.IsHidden(); self:SetHidden(v); return v end
        -- вкладку можно выбрать и удалить из кода (Preview UI использует это: крестик удаляет вкладку)
        function Tab:Select() if tabFrames[id] then switchToTab(id) end end
        function Tab:IsRemoved() return Tab._removed == true end
        function Tab:Remove()
            if Tab._removed then return end
            Tab._removed = true
            local wasActive = (activeTabId == id)
            tabFrames[id] = nil; tabUI[id] = nil; tabScrollers[id] = nil; sbBtns[id] = nil
            pcall(hideTip)
            pcall(function() btn:Destroy() end)
            pcall(function() tabFrame:Destroy() end)
            queueSidebar()
            if wasActive then
                activeTabId = nil
                local pick
                for oid,u in pairs(tabUI) do
                    if u.btn.Visible and oid < id and (not pick or oid > pick) then pick = oid end
                end
                if not pick then
                    for oid,u in pairs(tabUI) do
                        if u.btn.Visible and (not pick or oid < pick) then pick = oid end
                    end
                end
                if pick then switchToTab(pick) end
            end
            if topts.OnClose then pcall(topts.OnClose, Tab) end
        end
        local function mkScroll(dir)
            local sc = Instance.new("ScrollingFrame"); sc.Size = UDim2.new(1,0,1,0); sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0
            sc.ScrollBarThickness = 4; sc.ScrollBarImageColor3 = ACCENTS[1]; sc.CanvasSize = UDim2.new(0,0,0,0); sc.ScrollingDirection = dir; sc.Parent = tabFrame
            return sc
        end
        if typ == "Grid" then
            local scroll = mkScroll(Enum.ScrollingDirection.XY)
            local colCon = Instance.new("Frame"); colCon.Size = UDim2.new(0,0,0,0); colCon.Position = UDim2.new(0,3,0,3); colCon.BackgroundTransparency = 1; colCon.Parent = scroll
            local cols = {}; local ncols = 0; local secCount = {}
            local pager = Instance.new("Frame"); pager.Size = UDim2.new(1,0,0,24); pager.Position = UDim2.new(0,0,1,-24); pager.BackgroundTransparency = 1; pager.Visible = false; pager.Parent = tabFrame
            local pl = Instance.new("UIListLayout"); pl.FillDirection = Enum.FillDirection.Horizontal; pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
            pl.VerticalAlignment = Enum.VerticalAlignment.Center; pl.Padding = UDim.new(0,4); pl.SortOrder = Enum.SortOrder.LayoutOrder; pl.Parent = pager
            local chips = {}
            local function curCol() return math.floor(scroll.CanvasPosition.X / (colW + COLGAP) + 0.5) + 1 end
            local function curPage() return math.floor((curCol() - 1) / VIS) + 1 end
            local function numPages() return math.max(1, math.ceil(ncols / VIS)) end
            local function goCol(i)
                i = math.clamp(i, 1, math.max(1, ncols - VIS + 1))
                createTween(scroll, TweenInfo.new(.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new((i - 1) * (colW + COLGAP), scroll.CanvasPosition.Y)}):Play()
            end
            local function goPage(p)
                p = math.clamp(p, 1, numPages())
                goCol((p - 1) * VIS + 1)
            end
            local function paintChips()
                local p = curPage()
                for i,ch in ipairs(chips) do
                    local on = (i == p)
                    ch.BackgroundColor3 = on and ACCENTS[1] or C.btnBg; ch.TextColor3 = on and Color3.new(1,1,1) or C.dim
                end
            end
            local function mkChip(txt,order,fn)
                local b = Instance.new("TextButton"); b.Size = UDim2.new(0,24,0,18); b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.AutoButtonColor = false
                b.Text = txt; b.Font = GB; b.TextSize = 11; b.TextColor3 = C.dim; b.LayoutOrder = order; b.Parent = pager; corner(5,b)
                b.MouseButton1Click:Connect(fn); return b
            end
            local function rebuildPager()
                for _,c in ipairs(pager:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                chips = {}
                local np = numPages()
                local need = ncols > VIS
                pager.Visible = need
                scroll.Size = need and UDim2.new(1,0,1,-28) or UDim2.new(1,0,1,0)
                if not need then return end
                mkChip("‹", 0, function() goPage(curPage() - 1) end)
                for i = 1,np do chips[i] = mkChip(tostring(i), i, function() goPage(i) end) end
                mkChip("›", np + 1, function() goPage(curPage() + 1) end)
                paintChips()
            end
            scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(paintChips)
            tabScrollers[id] = {cur = curCol, go = goCol}
            local function relayout()
                local mH = 0
                for i = 1,ncols do
                    local hh = unscaleWin(cols[i].L.AbsoluteContentSize.Y)
                    cols[i].F.Size = UDim2.new(0,colW,0,hh); if hh > mH then mH = hh end
                end
                local total = ncols * colW + math.max(ncols - 1, 0) * COLGAP
                colCon.Size = UDim2.new(0,total,0,mH)
                scroll.CanvasSize = UDim2.new(0, (ncols > VIS) and (total + 8) or 0, 0, mH + 14)
            end
            local function getCol(i)
                while ncols < i do
                    ncols = ncols + 1; local k = ncols
                    local f = Instance.new("Frame"); f.Size = UDim2.new(0,colW,0,0); f.Position = UDim2.new(0,(k - 1) * (colW + COLGAP),0,0); f.BackgroundTransparency = 1; f.Parent = colCon
                    local L = Instance.new("UIListLayout"); L.FillDirection = Enum.FillDirection.Vertical; L.Padding = UDim.new(0,8); L.SortOrder = Enum.SortOrder.LayoutOrder; L.Parent = f
                    L:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(relayout)
                    cols[k] = {F = f, L = L}
                    rebuildPager()
                end
                relayout()
                return cols[i]
            end
            local NAMES = {left = 1, mid = 2, middle = 2, center = 2, right = 3}
            local function resolveCol(c)
                if type(c) == "number" then return math.max(1, math.floor(c)) end
                if type(c) == "string" then return NAMES[c:lower()] or tonumber(c) or 1 end
                local best,bc = 1,math.huge
                for i = 1,VIS do local n = secCount[i] or 0; if n < bc then best = i; bc = n end end
                return best
            end
            function Tab:Section(sopts)
                sopts = sopts or {}
                local ci = resolveCol(sopts.Column)
                secCount[ci] = (secCount[ci] or 0) + 1
                return makeSection(getCol(ci).F, sopts.Title or "Section", sg, secCount[ci], colW, sopts, uiScale, attachTip, hubConfig)
            end
            function Tab:MultiSection(sopts)
                sopts = sopts or {}
                local ci = resolveCol(sopts.Column)
                secCount[ci] = (secCount[ci] or 0) + 1
                return makeMultiSection(getCol(ci).F, sopts, sg, secCount[ci], colW, uiScale, attachTip, hubConfig)
            end
            for i = 1,VIS do getCol(i) end
        elseif typ == "Custom" then
        else
            local scroll = mkScroll(Enum.ScrollingDirection.Y)
            local listCon = Instance.new("Frame"); listCon.Size = UDim2.new(0,listW,0,0); listCon.Position = UDim2.new(0,3,0,3); listCon.BackgroundTransparency = 1; listCon.Parent = scroll
            local listL = Instance.new("UIListLayout"); listL.FillDirection = Enum.FillDirection.Vertical; listL.Padding = UDim.new(0,8); listL.SortOrder = Enum.SortOrder.LayoutOrder; listL.Parent = listCon
            listL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                local h = listL.AbsoluteContentSize.Y
                listCon.Size = UDim2.new(0,listW,0,h); scroll.CanvasSize = UDim2.new(0,0,0,h + 14)
            end)
            local _sOrd = 0
            function Tab:Section(sopts)
                sopts = sopts or {}; _sOrd = _sOrd + 1
                return makeSection(listCon, sopts.Title or "Section", sg, _sOrd, listW, sopts, uiScale, attachTip, hubConfig)
            end
            function Tab:MultiSection(sopts)
                sopts = sopts or {}; _sOrd = _sOrd + 1
                return makeMultiSection(listCon, sopts, sg, _sOrd, listW, uiScale, attachTip, hubConfig)
            end
        end
        return Tab
    end
    -- ===== Addons: файлы .lua / .txt из папки. Секции и контролы создаются автоматически по пометкам в комментариях =====
    local AM = {list = {}, tab = nil, building = false, booted = false}
    AM.dir = opts.AddonsFolder or "JustLib/Addons"
    local ADDON_EXT = {lua = true, txt = true, luau = true}
    local WARN_COL = Color3.fromRGB(255,190,80)
    local ERR_COL = Color3.fromRGB(255,82,82)
    local function amWarnOn() return cfgGet("_addons_warn", true) ~= false end
    local function amFsOK() return readfile and listfiles and isfolder and makefolder end
    local function amEnsureDir()
        if not (isfolder and makefolder) then return false end
        local path = ""
        for part in string.gmatch(AM.dir, "[^/\\]+") do
            path = (path == "") and part or (path .. "/" .. part)
            local ok,ex = pcall(isfolder, path)
            if ok and not ex then pcall(makefolder, path) end
        end
        local ok,ex = pcall(isfolder, AM.dir)
        return ok and ex == true
    end
    local function amTrim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    local function amCoerce(v)
        if v == "true" then return true elseif v == "false" then return false end
        return tonumber(v) or v
    end
    local function amVerParts(s)
        local t = {}
        for n in tostring(s or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
        return t
    end
    local function amVerCmp(a, b) -- >0: a новее b
        local x, y = amVerParts(a), amVerParts(b)
        for i = 1, 2 do -- сравниваем только major.minor: патч-версия (4.0.1) не считается новой
            local p, q = x[i] or 0, y[i] or 0
            if p ~= q then return p > q and 1 or -1 end
        end
        return 0
    end
    local function amShowVer(s) return "v" .. (tostring(s):gsub("^[vV]%s*", "")) end
    -- "Имя" tip="..." notify="..." default=true  /  Имя key=value
    local function amArgs(s)
        s = amTrim(s)
        local o, name = {}, nil
        local q, rest = s:match('^"([^"]*)"%s*(.*)$')
        if not q then q, rest = s:match("^'([^']*)'%s*(.*)$") end
        if q then name = q; s = rest
        elseif s:match("^[%w_]+%s*=") then name = nil
        else
            local pos = s:find("%s[%w_]+%s*=")
            if pos then name = s:sub(1, pos - 1); s = s:sub(pos + 1) else name = s; s = "" end
        end
        s = s:gsub('([%w_]+)%s*=%s*"([^"]*)"', function(k, v) o[k:lower()] = v; return "" end)
        s = s:gsub("([%w_]+)%s*=%s*'([^']*)'", function(k, v) o[k:lower()] = v; return "" end)
        for k, v in s:gmatch("([%w_]+)%s*=%s*([^%s]+)") do o[k:lower()] = amCoerce(v) end
        if name and name ~= "" then o.name = amTrim(name) end
        return o
    end
    local CTRL_KINDS = {toggle = true, button = true, slider = true, dropdown = true, input = true, label = true, divider = true}
    local NUMERIC_MODS = {default = true, min = true, max = true, step = true}
    local function amParse(src)
        local meta, ctrls, notes = {}, {}, {}
        local pending, libLine
        local n = 0
        for line in (src .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            line = line:gsub("\r$", "")
            local key, rest = line:match("^%s*%-%-@([%w_]+)%s*(.-)%s*$")
            if key then
                key = key:lower()
                if key == "name" then meta.name = rest
                elseif key == "author" then meta.author = rest
                elseif key == "version" then meta.version = rest
                elseif key == "lib" or key == "requires" or key == "target" or key == "jl" then meta.lib = rest
                elseif key == "description" or key == "desc" then meta.desc = rest
                elseif CTRL_KINDS[key] then
                    if pending then notes[#notes + 1] = "line " .. pending.line .. ": --@" .. pending.kind .. " has no function below it"; pending = nil end
                    local isStatic = (key == "label" or key == "divider")
                    local c = {kind = key, o = isStatic and {name = rest} or amArgs(rest), line = n}
                    if isStatic then ctrls[#ctrls + 1] = c else pending = c end
                elseif pending then
                    if key == "tooltip" then key = "tip" end
                    if NUMERIC_MODS[key] then pending.o[key] = amCoerce(rest) else pending.o[key] = rest end
                end
            else
                local v = line:match('^%s*local%s+Version%s*=%s*["\']([^"\']+)["\']') or line:match('^%s*Version%s*=%s*["\']([^"\']+)["\']')
                if v and not libLine then libLine = v end
                if pending then
                    local fname = line:match("^%s*local%s+function%s+([%w_]+)") or line:match("^%s*function%s+([%w_]+)%s*%(")
                        or line:match("^%s*local%s+([%w_]+)%s*=%s*function") or line:match("^%s*([%w_]+)%s*=%s*function")
                    if fname then
                        pending.fn = fname
                        if not pending.o.name then pending.o.name = fname end
                        ctrls[#ctrls + 1] = pending; pending = nil
                    elseif line:match("%S") and not line:match("^%s*%-%-") then
                        notes[#notes + 1] = "line " .. pending.line .. ": --@" .. pending.kind .. " must be followed by a function"
                        pending = nil
                    end
                end
            end
        end
        if pending then notes[#notes + 1] = "line " .. pending.line .. ": --@" .. pending.kind .. " has no function below it" end
        meta.lib = (meta.lib and meta.lib ~= "") and meta.lib or libLine
        return meta, ctrls, notes
    end
    -- добавляем в конец файла строки, которые отдают отмеченные функции библиотеке (работает и для local function)
    local function amBuildCode(src, ctrls)
        local names, seen = {}, {}
        for _, c in ipairs(ctrls) do
            if c.fn and not seen[c.fn] then seen[c.fn] = true; names[#names + 1] = string.format("__JLA.fn[%q] = %s", c.fn, c.fn) end
        end
        local body = src
        if #names > 0 then
            local lines = {}
            for line in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
            local at
            for i = #lines, 1, -1 do
                local l = lines[i]
                if l:match("%S") and not l:match("^%s*%-%-") then
                    if l:match("^%s*return[%s%(%{\"'%[]") or l:match("^%s*return%s*$") then at = i end
                    break
                end
            end
            local footer = table.concat(names, "\n")
            if at then table.insert(lines, at, footer); body = table.concat(lines, "\n")
            else body = src .. "\n" .. footer .. "\n" end
        end
        return "local Addon, __JLA = ...; " .. body
    end

    function AM.scan()
        AM.list = {}; AM.fsNote = nil
        if not amFsOK() then AM.fsNote = "Your executor does not support the file functions needed for Addons"; return end
        if not amEnsureDir() then AM.fsNote = "Could not open the folder " .. AM.dir; return end
        local ok,files = pcall(listfiles, AM.dir)
        if not ok or type(files) ~= "table" then AM.fsNote = "Could not read the folder " .. AM.dir; return end
        table.sort(files, function(x, y) return tostring(x):lower() < tostring(y):lower() end)
        local used = {}
        for _, p in ipairs(files) do
            local base, ext = tostring(p):match("([^\\/]+)%.(%w+)$")
            if base and ext and ADDON_EXT[ext:lower()] then
                local okr, src = pcall(readfile, p)
                if okr and type(src) == "string" and #src > 0 and #src < 600000 then
                    local id = base:lower():gsub("[^%w]+", "_")
                    local baseId, k = id, 1
                    while used[id] do k = k + 1; id = baseId .. k end
                    used[id] = true
                    src = src:gsub("^\239\187\191", "")
                    local meta, ctrls, notes = amParse(src)
                    if not meta.name or meta.name == "" then meta.name = base end
                    local a = {id = id, file = base .. "." .. ext, src = src, meta = meta, ctrls = ctrls, notes = notes, loaded = false, keeps = {}, unload = {}}
                    if meta.lib and meta.lib ~= "" then
                        local cmp = amVerCmp(JL.Version, meta.lib)
                        a.outdated = cmp > 0; a.needsNewer = cmp < 0
                    end
                    AM.list[#AM.list + 1] = a
                end
            end
        end
    end

    local function amSetErr(a, msg)
        a.err = msg
        JL:Notify({Title = a.meta.name, Desc = msg, Type = "Error", Duration = 5})
        if a.sec then
            pcall(function()
                if not a.errCtl then a.errCtl = a.sec:Label({Text = "", Color = ERR_COL}) end
                a.errCtl:Set("⚠ " .. msg); a.errCtl:SetHidden(false)
            end)
        end
    end
    local function amClearErr(a)
        a.err = nil
        if a.errCtl then pcall(function() a.errCtl:SetHidden(true) end) end
    end
    local function amFire(a, c, value)
        local n = c.o.notify
        if n == nil or n == false or c.kind == "slider" then return end
        local text
        if n == true then
            text = (c.kind == "toggle") and (c.name .. (value and " enabled" or " disabled")) or c.name
        else
            text = tostring(n)
            text = text:gsub("{state}", function() return value and "On" or "Off" end)
            text = text:gsub("{value}", function() return tostring(value) end)
            text = text:gsub("{name}", function() return c.name end)
        end
        local t = tostring(c.o.ntype or "Info"); t = t:sub(1, 1):upper() .. t:sub(2):lower()
        if t ~= "Success" and t ~= "Warn" and t ~= "Error" then t = "Info" end
        JL:Notify({Title = a.meta.name, Desc = text, Type = t, Duration = 3})
    end
    local function amCall(a, c, ...)
        local f = a.store and a.store.fn and a.store.fn[c.fn]
        if type(f) ~= "function" then
            amSetErr(a, "Function '" .. tostring(c.fn) .. "' was not found (define it at the top level of the file)")
            return false
        end
        local ok, err = pcall(f, ...)
        if not ok then amSetErr(a, tostring(c.name) .. ": " .. tostring(err)); return false end
        return true
    end
    local function amClean(a)
        for i = #a.keeps, 1, -1 do
            local x = a.keeps[i]
            pcall(function()
                local t = typeof(x)
                if t == "RBXScriptConnection" then x:Disconnect()
                elseif t == "Instance" then x:Destroy()
                elseif t == "function" then x()
                elseif t == "thread" then pcall(task.cancel, x)
                elseif t == "table" then
                    if x.Destroy then x:Destroy() elseif x.Disconnect then x:Disconnect() end
                end
            end)
        end
        a.keeps = {}
    end
    -- объект Addon, доступный коду аддона
    local function amApi(a)
        local api = {Name = a.meta.name, Id = a.id, Library = JL, LibVersion = JL.Version, Window = Win}
        local function dual(f) return function(x, ...) if x == api then return f(...) end return f(x, ...) end end
        api.Notify = dual(function(msg, typ, title)
            if type(msg) == "table" then JL:Notify(msg)
            else JL:Notify({Title = title or a.meta.name, Desc = tostring(msg), Type = typ or "Info", Duration = 3}) end
        end)
        api.Keep = dual(function(x) a.keeps[#a.keeps + 1] = x; return x end)
        api.OnUnload = dual(function(fn) if type(fn) == "function" then a.unload[#a.unload + 1] = fn end end)
        api.Save = dual(function(k, v) cfgSet("addon." .. a.id .. ".data." .. tostring(k), v) end)
        api.Load = dual(function(k, d) return cfgGet("addon." .. a.id .. ".data." .. tostring(k), d) end)
        return api
    end

    function AM.enable(a)
        if a.loaded then return true end
        local fn, err = loadstring(amBuildCode(a.src, a.ctrls), "=Addon_" .. a.id)
        if not fn then amSetErr(a, "Syntax error: " .. tostring(err)); return false end
        amClearErr(a)
        a.keeps = {}; a.unload = {}; a.store = {fn = {}}
        local api = amApi(a)
        local runErr
        a.thread = trackedSpawn(function()
            local ok, e = pcall(fn, api, a.store)
            if not ok then runErr = tostring(e) end
        end)
        if runErr then
            amClean(a); a.store = nil; a.thread = nil
            amSetErr(a, runErr)
            return false
        end
        a.loaded = true
        for _, c in ipairs(a.ctrls) do
            if c.ui and c.ui.SetLocked then pcall(function() c.ui:SetLocked(false) end) end
        end
        -- применяем текущие значения (включённые тоглы, слайдеры, списки)
        for _, c in ipairs(a.ctrls) do
            if c.fn then
                if c.kind == "toggle" then if c.state then amCall(a, c, true) end
                elseif c.kind == "slider" or c.kind == "dropdown" then if c.state ~= nil then amCall(a, c, c.state) end
                elseif c.kind == "input" then if c.state and c.state ~= "" then amCall(a, c, c.state) end end
            end
        end
        if amWarnOn() and (a.outdated or a.needsNewer) then
            local msg = a.outdated
                and ("Made for JustLib " .. amShowVer(a.meta.lib) .. ", you have " .. amShowVer(JL.Version) .. ". It may not work correctly.")
                or ("Needs JustLib " .. amShowVer(a.meta.lib) .. " or newer, you have " .. amShowVer(JL.Version) .. ". It may not work correctly.")
            JL:Notify({Title = a.meta.name, Desc = msg, Type = "Warn", Duration = 5})
        end
        return true
    end

    function AM.disable(a, skipUI)
        if not a.loaded then return end
        a.loaded = false
        for _, c in ipairs(a.ctrls) do
            if c.fn and c.kind == "toggle" and c.state then
                local f = a.store and a.store.fn and a.store.fn[c.fn]
                if type(f) == "function" then pcall(f, false) end
            end
        end
        for i = #a.unload, 1, -1 do pcall(a.unload[i]) end
        a.unload = {}
        amClean(a)
        if a.thread then pcall(task.cancel, a.thread); a.thread = nil end
        a.store = nil
        if skipUI then return end
        for _, c in ipairs(a.ctrls) do
            pcall(function()
                if c.kind == "toggle" and c.ui and c.state then c.ui:Set(false); c.state = false end
                if c.ui and c.ui.SetLocked then c.ui:SetLocked(true) end
            end)
        end
    end

    function AM.disableAll(skipUI)
        for _, a in ipairs(AM.list) do
            if a.loaded then
                if a.enableCtl and not skipUI then pcall(function() a.enableCtl:Set(false) end) end
                AM.disable(a, skipUI)
            end
        end
    end

    local function amBuildControl(a, sec, c)
        local o = c.o
        local nm = tostring(o.name or c.fn or c.kind)
        c.name = nm
        if c.kind == "label" then c.ui = sec:Label({Text = nm, Tooltip = o.tip and tostring(o.tip) or nil}); return end
        if c.kind == "divider" then c.ui = sec:Divider({Label = (nm ~= "" and nm or nil)}); return end
        local flag = "addon." .. a.id .. "." .. tostring(c.fn or (c.kind .. c.line))
        local b = {
            Name = nm, Tooltip = o.tip and tostring(o.tip) or nil, NoSave = true,
            Locked = true, LockedTitle = a.meta.name, LockedMessage = "Enable the addon first",
        }
        if o.icon then b.Icon = tostring(o.icon) end
        local function run(...)
            if AM.building or not a.loaded then return false end
            return amCall(a, c, ...)
        end
        if c.kind == "toggle" then
            b.Flag = flag; b.Default = (o.default == true)
            c.state = cfgGet(flag, b.Default) == true
            b.Callback = function(v) c.state = v; if run(v) then amFire(a, c, v) end end
            c.ui = sec:Toggle(b)
        elseif c.kind == "button" then
            b.Callback = function() if run() then amFire(a, c, true) end end
            c.ui = sec:Button(b)
        elseif c.kind == "slider" then
            b.Flag = flag
            b.Min = tonumber(o.min) or 0; b.Max = tonumber(o.max) or 100; b.Step = tonumber(o.step) or 1
            b.Default = tonumber(o.default) or b.Min
            if o.suffix then b.Suffix = tostring(o.suffix) end
            c.state = tonumber(cfgGet(flag, b.Default)) or b.Default
            b.Callback = function(v) c.state = v; run(v) end
            c.ui = sec:Slider(b)
        elseif c.kind == "dropdown" then
            local list = {}
            for part in tostring(o.options or ""):gmatch("[^,]+") do list[#list + 1] = amTrim(part) end
            b.Flag = flag; b.Options = list; b.MultiSelect = (o.multi == true)
            if o.default ~= nil then b.Default = tostring(o.default) end
            c.state = cfgGet(flag, b.Default)
            b.Callback = function(v) c.state = v; if run(v) then amFire(a, c, v) end end
            c.ui = sec:Dropdown(b)
        elseif c.kind == "input" then
            b.Flag = flag
            if o.placeholder then b.Placeholder = tostring(o.placeholder) end
            c.state = tostring(cfgGet(flag, o.default ~= nil and tostring(o.default) or "") or "")
            b.Callback = function(v) c.state = v; if run(v) then amFire(a, c, v) end end
            c.ui = sec:Input(b)
        end
    end

    local function amBuildSection(a)
        local sec = AM.tab:Section({Title = a.meta.name})
        a.sec = sec
        a.enableCtl = sec:Toggle({
            Name = "Enabled", Flag = "addon." .. a.id .. ".enabled", Default = false, NoSave = true, Tooltip = a.meta.desc,
            Callback = function(v)
                if AM.building then return end
                if v then if not AM.enable(a) then pcall(function() a.enableCtl:Set(false) end) end
                else AM.disable(a) end
            end,
        })
        local sub = {}
        if a.meta.author and a.meta.author ~= "" then sub[#sub + 1] = "by " .. a.meta.author end
        if a.meta.version and a.meta.version ~= "" then sub[#sub + 1] = amShowVer(a.meta.version) end
        sub[#sub + 1] = a.file
        sec:Label({Text = table.concat(sub, "  ·  ")})
        if a.meta.desc and a.meta.desc ~= "" then sec:Label({Text = a.meta.desc, Color = C.txt}) end
        if amWarnOn() then
            if a.outdated then
                sec:Label({Text = "⚠ Made for JustLib " .. amShowVer(a.meta.lib) .. " (you have " .. amShowVer(JL.Version) .. "). It may not work correctly.", Color = WARN_COL})
            elseif a.needsNewer then
                sec:Label({Text = "⚠ Needs JustLib " .. amShowVer(a.meta.lib) .. " or newer (you have " .. amShowVer(JL.Version) .. ").", Color = WARN_COL})
            end
        end
        for _, note in ipairs(a.notes) do sec:Label({Text = "⚠ " .. note, Color = WARN_COL}) end
        local hasCtl = false
        for _, c in ipairs(a.ctrls) do if c.kind ~= "label" and c.kind ~= "divider" then hasCtl = true end end
        if hasCtl then sec:Divider({Label = "Controls"}) end
        for _, c in ipairs(a.ctrls) do
            local ok, e = pcall(amBuildControl, a, sec, c)
            if not ok then sec:Label({Text = "⚠ " .. tostring(c.o.name or c.fn) .. ": " .. tostring(e), Color = ERR_COL}) end
        end
    end

    function AM.buildTab()
        if AM.tab then return end
        AM.building = true
        AM.tab = Win:Tab({Name = "Addons", Icon = "◈", Type = "Grid", Tooltip = "Addons"})
        local top = AM.tab:Section({Title = "Addons", Column = 1})
        top:Label({Text = "Folder: " .. AM.dir .. "  ·  .lua .txt .luau"})
        top:Label({Text = "⚠ Addons are code with full access. Only enable addons you trust.", Color = WARN_COL})
        if AM.fsNote then top:Label({Text = AM.fsNote, Color = ERR_COL}) end
        top:Toggle({
            Name = "Auto Save", Flag = "_addons_autosave", Default = false,
            Tooltip = "Off (default): addons and their toggles start disabled every launch. On: they are remembered and restored.",
            Callback = function(v)
                JL._addonAutoSave = v
                if AM.building then return end
                if v then cfgFlush() end
                JL:Notify({Title = "Addons", Desc = v and "Auto Save on: enabled addons will be restored next launch" or "Auto Save off: addons start disabled next launch", Type = "Info", Duration = 3})
            end,
        })
        top:Button({Name = "Reload Addons", Tooltip = "Re-reads the folder. Running addons are restarted", Callback = function() AM.refresh() end})
        top:Button({Name = "Disable All", Tooltip = "Turns off every running addon", Callback = function() AM.disableAll() end})
        if #AM.list == 0 and not AM.fsNote then
            top:Label({Text = "No addon files found yet. Put .lua or .txt files into the folder and press Reload Addons."})
        end
        for _, a in ipairs(AM.list) do
            local ok, e = pcall(amBuildSection, a)
            if not ok then warn("[JustLib] addon '" .. tostring(a.file) .. "' UI failed: " .. tostring(e)) end
        end
        AM.building = false
        -- Auto Save включён: поднимаем аддоны, которые были включены в прошлый раз
        for _, a in ipairs(AM.list) do
            if a.enableCtl and cfgGet("addon." .. a.id .. ".enabled", false) == true then
                if not AM.enable(a) then pcall(function() a.enableCtl:Set(false) end) end
            end
        end
    end

    function AM.removeTab()
        if AM.tab then
            local t = AM.tab; AM.tab = nil
            pcall(function() t:Remove() end)
        end
    end

    function AM.refresh()
        if not AM.tab then return end
        local keep = {}
        for _, a in ipairs(AM.list) do if a.loaded then keep[a.id] = true end end
        AM.disableAll()
        AM.removeTab()
        AM.scan()
        AM.buildTab()
        for _, a in ipairs(AM.list) do
            if keep[a.id] and not a.loaded then
                if AM.enable(a) then pcall(function() a.enableCtl:Set(true) end) end
            end
        end
        if AM.tab and AM.tab.Select then AM.tab:Select() end
    end

    function AM.setEnabled(on)
        if on then
            if not AM.tab then AM.scan(); AM.buildTab() end
        else
            AM.disableAll()
            AM.removeTab()
        end
    end
    function AM.boot()
        if AM.booted then return end
        AM.booted = true
        if cfgGet("_addons_on", false) == true then AM.setEnabled(true) end
    end
    table.insert(JL._unloadHooks, function() AM.disableAll(true) end)
    function Win:Addons() AM.boot(); return AM end
    JL._addons = AM
    -- ===== Remote: плавающая панель быстрого доступа (тоглы, кнопки и кейбинды под рукой; удобно на телефоне) =====
    -- Игрок сам выбирает, какие разрешённые разработчиком Toggle / Button / Keybind закреплять в Remote UI.
    local RM = {items = {}, available = {}, built = false, open = false, editMode = false, opts = {}, idCounts = {}}
    local RM_W, RM_HDR, RM_ROW, RM_GAP, RM_MAXROWS, RM_PILL = 208, 36, 32, 4, 7, 46
    local RM_KEYS = {LeftShift="LShift",RightShift="RShift",LeftControl="LCtrl",RightControl="RCtrl",LeftAlt="LAlt",RightAlt="RAlt",
        Return="Enter",Backspace="Back",Escape="Esc",Space="Space",Tab="Tab",CapsLock="Caps",Insert="Ins",Delete="Del",
        PageUp="PgUp",PageDown="PgDn",MouseButton1="LMB",MouseButton2="RMB",MouseButton3="MMB"}
    local function rmKeyName(k)
        if not k then return "None" end
        local n = (typeof(k) == "EnumItem") and k.Name or tostring(k)
        return RM_KEYS[n] or n
    end
    local function rmViewport()
        local cam = workspace.CurrentCamera
        return cam and cam.ViewportSize or Vector2.new(1280,720)
    end
    function RM.fit()
        local v = rmViewport()
        local base = math.clamp(math.min(v.X / 900, v.Y / 520), 0.8, 1.15)
        return base * (tonumber(cfgGet("_remote_scale", 100)) or 100) / 100
    end
    function RM.clamp()
        if not RM.holder then return end
        local v = rmViewport()
        local sz = RM.holder.Size
        local x = math.clamp(RM.px or 0, 0, math.max(0, v.X - sz.X.Offset))
        local y = math.clamp(RM.py or 0, 0, math.max(0, v.Y - sz.Y.Offset))
        RM.px, RM.py = x, y
        RM.holder.Position = UDim2.new(0,x,0,y)
    end
    function RM.savePos()
        local v = rmViewport()
        cfgSet("_remote_x", (RM.px or 0) / math.max(v.X, 1)); cfgSet("_remote_y", (RM.py or 0) / math.max(v.Y, 1))
    end
    function RM.restorePos()
        local v = rmViewport()
        RM.px = (tonumber(cfgGet("_remote_x", 0.012)) or 0.012) * v.X
        RM.py = (tonumber(cfgGet("_remote_y", 0.30)) or 0.30) * v.Y
        RM.clamp()
    end
    JL._remoteRestorePos = function() RM.restorePos() end
    function RM.setLogical(lw, lh)
        RM.lw, RM.lh = lw, lh
        local s = RM.s or 1
        RM.canvas.Size = UDim2.new(0,lw,0,lh)
        RM.holder.Size = UDim2.new(0,lw * s,0,lh * s)
        RM.clamp()
    end
    function RM.applyScale()
        if not RM.built then return end
        RM.s = RM.fit(); RM.scale.Scale = RM.s
        RM.setLogical(RM.lw or RM_PILL, RM.lh or RM_PILL)
    end
    function RM.applyOpacity()
        if not RM.built then return end
        local t = 1 - (tonumber(cfgGet("_remote_opacity", 94)) or 94) / 100
        RM.panel.BackgroundTransparency = t; RM.hdr.BackgroundTransparency = t; RM.hdrFix.BackgroundTransparency = t; RM.pill.BackgroundTransparency = t
    end
    local function rmCount()
        local n = 0
        for _,it in ipairs(RM.items) do
            if it.kind == "toggle" then local ok,v = pcall(it.ret.Get, it.ret); if ok and v then n = n + 1 end end
        end
        return n
    end
    function RM.updateBadge()
        if not RM.built then return end
        local n = rmCount()
        RM.hdrBadge.Visible = n > 0; RM.hdrBadgeTxt.Text = n .. " on"
        RM.pillBadge.Visible = n > 0; RM.pillBadgeTxt.Text = tostring(n)
    end
    function RM.layout(animate)
        if not RM.built then return end
        local n = #RM.items
        local shown = math.min(n, RM_MAXROWS)
        local bodyH = (n == 0) and 36 or (shown * (RM_ROW + RM_GAP) - RM_GAP)
        RM.panelH = RM_HDR + 6 + bodyH + 8
        RM.list.Position = UDim2.new(0,6,0,RM_HDR + 6); RM.list.Size = UDim2.new(1,-12,0,bodyH)
        RM.list.CanvasSize = UDim2.new(0,0,0,n * (RM_ROW + RM_GAP))
        RM.empty.Visible = (n == 0)
        if RM.open then
            RM.setLogical(RM_W, RM.panelH)
            if animate then tw(RM.panel,{Size = UDim2.new(1,0,0,RM.panelH)},.3,Enum.EasingStyle.Quint)
            else RM.panel.Size = UDim2.new(1,0,0,RM.panelH) end
        end
    end
    function RM.setOpen(open, instant)
        open = open and true or false
        RM.open = open; cfgSet("_remote_open", open)
        if not RM.built then return end
        local anim = (not instant) and cfgGet("_anim", true) ~= false
        RM.tok = (RM.tok or 0) + 1; local tok = RM.tok
        if open then
            RM.setLogical(RM_W, RM.panelH)
            RM.panel.Visible = true
            if anim then
                RM.panel.Size = UDim2.new(1,0,0,RM_PILL)
                tw(RM.panel,{Size = UDim2.new(1,0,0,RM.panelH)},.36,Enum.EasingStyle.Quint)
                tw(RM.pillScale,{Scale = 0},.14)
                trackedDelay(.15, function() if RM.tok == tok and RM.pill then RM.pill.Visible = false end end)
            else
                RM.panel.Size = UDim2.new(1,0,0,RM.panelH); RM.pill.Visible = false
            end
        else
            if anim then
                tw(RM.panel,{Size = UDim2.new(1,0,0,RM_PILL)},.26,Enum.EasingStyle.Quint)
                trackedDelay(.27, function()
                    if RM.tok ~= tok or not RM.pill then return end
                    RM.panel.Visible = false; RM.setLogical(RM_PILL, RM_PILL)
                    RM.pill.Visible = true; RM.pillScale.Scale = 0.5
                    tw(RM.pillScale,{Scale = 1},.32,Enum.EasingStyle.Back)
                end)
            else
                RM.panel.Visible = false; RM.setLogical(RM_PILL, RM_PILL); RM.pill.Visible = true; RM.pillScale.Scale = 1
            end
        end
        RM.updateBadge()
    end
    -- перетаскивание: за шапку или за кружок; короткое касание без движения считается нажатием
    local function rmDrag(handle, onTap)
        handle.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local startIn = Vector2.new(i.Position.X, i.Position.Y)
            local sx, sy = RM.px or 0, RM.py or 0
            local moved = false
            local c1, c2
            c1 = keep(UIS.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
                    local d = Vector2.new(m.Position.X, m.Position.Y) - startIn
                    if not moved and d.Magnitude > 6 then moved = true end
                    if moved then RM.px, RM.py = sx + d.X, sy + d.Y; RM.clamp() end
                end
            end))
            c2 = keep(UIS.InputEnded:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseButton1 or e.UserInputType == Enum.UserInputType.Touch then
                    c1:Disconnect(); c2:Disconnect()
                    if moved then RM.savePos() elseif onTap then onTap() end
                end
            end))
        end)
    end
    local function rmFlash(row, strokeObj)
        tw(row,{BackgroundColor3 = ACCENTS[1]},.07)
        tw(strokeObj,{Color = ACCENTS[1]},.07)
        trackedDelay(.16, function()
            if row.Parent then
                local on = row:GetAttribute("on")
                tw(row,{BackgroundColor3 = on and C.badgeHi or C.btnBg},.24); tw(strokeObj,{Color = C.border},.24)
            end
        end)
    end
    local function rmMakeRow(item)
        local row = Instance.new("TextButton"); row.Size = UDim2.new(0,RM_W - 16 - 4,0,RM_ROW); row.BackgroundColor3 = C.btnBg; row.BorderSizePixel = 0
        row.AutoButtonColor = false; row.Text = ""; row.LayoutOrder = item.order; row.Parent = RM.list
        corner(8, row); local st = stroke(C.border, 1, row)
        local label = newTxt({Parent=row,Text=item.name,Font=GB,Size=11,Sz=UDim2.new(1,-66,1,0),Pos=UDim2.new(0,10,0,0),Z=3})
        item.row = row
        local function pressFx() rmFlash(row, st) end
        if item.kind == "toggle" then
            local sw = mkSwitch(row, UDim2.new(1,-44,0.5,-9), item.ret:Get() and true or false, ACCENTS[1])
            item.refresh = function()
                local on = item.ret:Get() and true or false
                row:SetAttribute("on", on); sw.Set(on)
                tw(row,{BackgroundColor3 = on and C.badgeHi or C.btnBg},.2)
                tw(label,{TextColor3 = on and C.txt or C.dim},.2)
            end
            item.refresh()
            item.ret:Watch(function() item.refresh(); RM.updateBadge() end)
            row.MouseButton1Click:Connect(function() item.ret:Click() end)
        elseif item.kind == "button" then
            local ch = spChev(row, "right", C.dim, 4); ch.Position = UDim2.new(1,-16,0.5,0)
            row.MouseButton1Click:Connect(function() pressFx(); item.ret:Click() end)
        elseif item.kind == "keybind" then
            local chip = Instance.new("Frame"); chip.Size = UDim2.new(0,48,0,20); chip.AnchorPoint = Vector2.new(1,0.5); chip.Position = UDim2.new(1,-8,0.5,0)
            chip.BackgroundColor3 = C.input; chip.BorderSizePixel = 0; chip.Parent = row; corner(6, chip); stroke(C.border, 1, chip)
            local kt = newTxt({Parent=chip,Text=rmKeyName(item.ret:Get()),Font=GB,Size=10,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Z=4})
            item.ret:Watch(function(k) kt.Text = rmKeyName(k) end)
            if item.ret.OnPulse then item.ret:OnPulse(pressFx) end
            row.MouseButton1Click:Connect(function() pressFx(); item.ret:Press() end)
        end
        row.MouseEnter:Connect(function()
            if touchLast() then return end
            if not row:GetAttribute("on") then tw(row,{BackgroundColor3 = C.btnHov},.12) end
        end)
        row.MouseLeave:Connect(function()
            tw(row,{BackgroundColor3 = row:GetAttribute("on") and C.badgeHi or C.btnBg},.12)
        end)
        -- появление строки
        row.BackgroundTransparency = 1; label.TextTransparency = 1
        tw(row,{BackgroundTransparency = 0},.25); tw(label,{TextTransparency = 0},.25)
    end

    function RM.build()
        if RM.built then return end
        RM.built = true
        local gui = registerHubGui(Instance.new("ScreenGui"), "Remote"); gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 998
        local okp = pcall(function() gui.Parent = game:GetService("CoreGui") end); if not okp or not gui.Parent then gui.Parent = PG end
        RM.gui = gui
        table.insert(JL._extraRoots, gui)
        -- holder: размер в пикселях (его двигаем), canvas: логический размер + UIScale
        local holder = Instance.new("Frame"); holder.BackgroundTransparency = 1; holder.BorderSizePixel = 0; holder.Size = UDim2.new(0,RM_PILL,0,RM_PILL); holder.Parent = gui
        local canvas = Instance.new("Frame"); canvas.BackgroundTransparency = 1; canvas.BorderSizePixel = 0; canvas.Size = UDim2.new(0,RM_PILL,0,RM_PILL); canvas.Parent = holder
        local sc = Instance.new("UIScale"); sc.Parent = canvas
        RM.holder, RM.canvas, RM.scale = holder, canvas, sc

        -- развёрнутая панель
        local panel = Instance.new("Frame"); panel.Size = UDim2.new(1,0,0,RM_HDR); panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
        panel.ClipsDescendants = true; panel.Visible = false; panel.Parent = canvas; corner(12, panel); stroke(C.border, 1, panel)
        RM.panel = panel
        local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,RM_HDR); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = panel; corner(12, hdr)
        local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0,12); hfix.Position = UDim2.new(0,0,1,-12); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
        local hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,1,0); hline.BackgroundColor3 = C.divLine; hline.BorderSizePixel = 0; hline.Parent = hdr
        RM.hdr, RM.hdrFix = hdr, hfix
        for i = 0,2 do -- «ручка» для перетаскивания
            local d = Instance.new("Frame"); d.Size = UDim2.new(0,3,0,3); d.Position = UDim2.new(0,10 + i * 5,0.5,-1); d.BackgroundColor3 = C.dim; d.BorderSizePixel = 0; d.ZIndex = 3; d.Parent = hdr; corner(2, d)
        end
        local title = newTxt({Parent=hdr,Text=RM.opts.Title or "Remote",Font=GB,Size=12,Sz=UDim2.new(0,70,1,0),Pos=UDim2.new(0,30,0,0),Z=3})
        RM.title = title
        local bdg = Instance.new("Frame"); bdg.Size = UDim2.new(0,40,0,16); bdg.Position = UDim2.new(0,92,0.5,-8); bdg.BackgroundColor3 = ACCENTS[1]; bdg.BackgroundTransparency = 0.8; bdg.BorderSizePixel = 0
        bdg.Visible = false; bdg.ZIndex = 3; bdg.Parent = hdr; corner(8, bdg)
        RM.hdrBadge = bdg
        RM.hdrBadgeTxt = newTxt({Parent=bdg,Text="0 on",Font=GB,Size=10,Color=ACCENTS[1],XAlign=Enum.TextXAlignment.Center,Z=4})
        local drag = Instance.new("TextButton"); drag.Size = UDim2.new(1,-70,1,0); drag.BackgroundTransparency = 1; drag.Text = ""; drag.AutoButtonColor = false; drag.ZIndex = 2; drag.Parent = hdr
        rmDrag(drag, nil)
        local function hdrBtn(x, kind, fn)
            local b = Instance.new("TextButton"); b.Size = UDim2.new(0,26,0,26); b.Position = UDim2.new(1,x,0.5,-13); b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.Text = ""
            b.AutoButtonColor = false; b.ZIndex = 4; b.Parent = hdr; corner(7, b); stroke(C.border, 1, b)
            local ic = spIcon(kind, b, 14, C.dim, 5); ic.Position = UDim2.new(0.5,-7,0.5,-7)
            b.MouseEnter:Connect(function() if not touchLast() then tw(b,{BackgroundColor3 = C.btnHov},.12) end end)
            b.MouseLeave:Connect(function() tw(b,{BackgroundColor3 = C.btnBg},.12) end)
            b.MouseButton1Click:Connect(fn)
            return b
        end
        hdrBtn(-62, "window", function() Win:Toggle() end)
        hdrBtn(-32, "minus", function() RM.setOpen(false) end)

        local list = Instance.new("ScrollingFrame"); list.BackgroundTransparency = 1; list.BorderSizePixel = 0; list.ScrollBarThickness = 2; list.ScrollBarImageColor3 = ACCENTS[1]
        list.CanvasSize = UDim2.new(0,0,0,0); list.Parent = panel
        local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0,RM_GAP); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = list
        RM.list = list
        RM.empty = newTxt({Parent=panel,Text="Use Edit Remote Items to choose toggles, buttons and keybinds",Font=GM,Size=10,Color=C.dim,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-24,0,30),Pos=UDim2.new(0,12,0,RM_HDR + 10)})

        -- свёрнутая «таблетка»
        local pill = Instance.new("TextButton"); pill.Size = UDim2.new(0,RM_PILL,0,RM_PILL); pill.BackgroundColor3 = C.panel; pill.BorderSizePixel = 0; pill.Text = ""
        pill.AutoButtonColor = false; pill.Parent = canvas; corner(RM_PILL / 2, pill); stroke(ACCENTS[1], 1.5, pill)
        RM.pill = pill
        RM.pillScale = Instance.new("UIScale"); RM.pillScale.Parent = pill
        local mi = spIcon("menu", pill, 20, ACCENTS[1], 3); mi.Position = UDim2.new(0.5,-10,0.5,-10)
        local pb = Instance.new("Frame"); pb.Size = UDim2.new(0,18,0,18); pb.Position = UDim2.new(1,-16,0,-2); pb.BackgroundColor3 = C.togOn; pb.BorderSizePixel = 0
        pb.Visible = false; pb.ZIndex = 6; pb.Parent = pill; corner(9, pb)
        RM.pillBadge = pb
        RM.pillBadgeTxt = newTxt({Parent=pb,Text="0",Font=GB,Size=10,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center,Z=7})
        rmDrag(pill, function() RM.setOpen(true) end)

        RM.s = RM.fit(); sc.Scale = RM.s
        RM.restorePos()
        RM.applyOpacity()
        for _,it in ipairs(RM.items) do rmMakeRow(it) end
        RM.layout(false)
        RM.open = cfgGet("_remote_open", not touchLast()) == true
        RM.setLogical(RM_PILL, RM_PILL)
        RM.setOpen(RM.open, true)
        keep(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() RM.applyScale(); RM.restorePos() end))
    end

    local function rmPinnedMap()
        local map = cfgGet("_remote_pins", {})
        return type(map) == "table" and map or {}
    end
    function RM.isPinned(id)
        return rmPinnedMap()[id] == true
    end
    function RM.savePins(map)
        cfgSet("_remote_pins", map)
    end
    function RM.findItem(id)
        for i,item in ipairs(RM.items) do if item.id == id then return i,item end end
    end
    function RM.removeItem(id)
        local index = RM.findItem(id)
        if not index then return end
        table.remove(RM.items, index)
        for i,item in ipairs(RM.items) do item.order = i end
        if RM.built then RM.layout(true); RM.updateBadge() end
        RM.refresh()
    end
    function RM.refresh()
        local on = cfgGet("_remote_on", true) ~= false
        if on and #RM.items > 0 then
            RM.build()
            if RM.gui then RM.gui.Enabled = true end
        elseif RM.gui then
            RM.gui:Destroy()
            RM.gui, RM.built = nil, false
        end
    end
    JL._remoteRefresh = function() RM.refresh() end
    function RM.addItem(item)
        if item.id then
            local _,existing = RM.findItem(item.id)
            if existing then existing.ret = item.ret; existing.name = item.name; return existing end
        end
        item.order = #RM.items + 1
        RM.items[#RM.items + 1] = item
        if RM.built then
            rmMakeRow(item); RM.layout(true); RM.updateBadge()
        end
        RM.refresh()
        return item
    end
    function RM.setEditMode(enabled)
        RM.editMode = enabled == true
        JL._remoteEditActive = RM.editMode
        for _,button in ipairs(JL._metaButtons or {}) do
            if button and button.Parent then button.Visible = not RM.editMode end
        end
        for _,entry in ipairs(RM.available) do
            if entry.setEditLayout then entry.setEditLayout(RM.editMode) end
            if entry.pinButton then
                entry.pinButton.Visible = RM.editMode
                entry.pinButton.Text = RM.isPinned(entry.id) and "✓" or "+"
                entry.pinButton.BackgroundColor3 = RM.isPinned(entry.id) and ACCENTS[1] or C.btnBg
            end
        end
        if RM.editMode then
            JL:Notify({Title = "Remote Edit Mode", Desc = "Browse the tabs and tap + beside a supported control to pin it. Tap ✓ to remove it.", Type = "Info", Duration = 5})
        else
            JL:Notify({Title = "Remote Edit Mode", Desc = "Editing finished.", Type = "Success", Duration = 2})
        end
        return RM.editMode
    end
    function RM.togglePin(entry)
        local map = {}; for id,value in pairs(rmPinnedMap()) do map[id] = value end
        if map[entry.id] then
            map[entry.id] = nil
            RM.savePins(map)
            RM.removeItem(entry.id)
        else
            map[entry.id] = true
            RM.savePins(map)
            RM.addItem({id = entry.id, kind = entry.kind, name = entry.name, ret = entry.ret})
        end
        if entry.pinButton then
            entry.pinButton.Text = RM.isPinned(entry.id) and "✓" or "+"
            entry.pinButton.BackgroundColor3 = RM.isPinned(entry.id) and ACCENTS[1] or C.btnBg
        end
        return RM.isPinned(entry.id)
    end
    function RM.clearPins()
        RM.savePins({})
        RM.items = {}
        for _,entry in ipairs(RM.available) do
            if entry.pinButton then
                entry.pinButton.Text = "+"
                entry.pinButton.BackgroundColor3 = C.btnBg
            end
        end
        RM.refresh()
    end
    function RM.destroy()
        if RM.gui then pcall(function() RM.gui:Destroy() end) end
        for _,entry in ipairs(RM.available) do
            if entry.pinButton then pcall(function() entry.pinButton:Destroy() end) end
        end
        RM.gui, RM.built, RM.items, RM.available = nil, false, {}, {}
        RM.editMode = false
        JL._remoteEditActive = false
        for _,button in ipairs(JL._metaButtons or {}) do
            if button and button.Parent then button.Visible = true end
        end
        JL._remote = nil
    end
    -- Remote = true разрешает игроку закреплять функцию, но не добавляет её автоматически.
    JL._remoteAttach = function(kind, o, ret)
        if not o or not o.Remote or type(ret) ~= "table" or not ret.Row then return end
        local nm = (type(o.Remote) == "table" and o.Remote.Name) or o.Name or kind
        local baseId = tostring(o.Flag or (kind:lower() .. ":" .. tostring(nm)))
        RM.idCounts[baseId] = (RM.idCounts[baseId] or 0) + 1
        local id = baseId .. ":" .. tostring(RM.idCounts[baseId])
        local entry = {id = id, kind = kind:lower(), name = tostring(nm), ret = ret}
        -- Toggle owns its layout closure; this keeps the label and switch in sync.
        if entry.kind == "toggle" and type(ret._remoteEditLayout) == "function" then
            entry.setEditLayout = ret._remoteEditLayout
        end
        local pin = Instance.new("TextButton")
        pin.Name = "JLRemotePin"; pin.Size = UDim2.new(0,22,0,22); pin.AnchorPoint = Vector2.new(1,0.5)
        pin.Position = UDim2.new(1,-4,0.5,0); pin.BackgroundColor3 = C.btnBg; pin.BorderSizePixel = 0
        pin.AutoButtonColor = false; pin.Text = RM.isPinned(id) and "✓" or "+"; pin.Font = GB; pin.TextSize = 15
        pin.TextColor3 = Color3.new(1,1,1); pin.Visible = RM.editMode; pin.ZIndex = 20; pin.Parent = ret.Row
        if entry.setEditLayout then entry.setEditLayout(RM.editMode) end
        corner(6,pin); stroke(C.border,1,pin)
        pin.MouseButton1Click:Connect(function()
            if RM.editMode then RM.togglePin(entry) end
        end)
        entry.pinButton = pin
        RM.available[#RM.available + 1] = entry
        if RM.isPinned(id) then RM.addItem({id=id,kind=entry.kind,name=entry.name,ret=ret}) end
    end

    -- публичный объект: Win:Remote(...)
    local RemoteAPI = {}
    function RemoteAPI:Toggle(o)
        o = o or {}
        local state = cfgGet(o.Flag, o.Default or false) == true
        local watchers, ret = {}, {}
        local function fire(v) for _,w in ipairs(watchers) do pcall(w, v) end end
        ret.Get = function() return state end
        ret.Click = function()
            state = not state; cfgSet(o.Flag, state)
            if o.Callback then pcall(o.Callback, state) end
            fire(state)
        end
        ret.Set = function(_, v) state = v and true or false; cfgSet(o.Flag, state); fire(state) end
        ret.Watch = function(_, fn) watchers[#watchers + 1] = fn end
        if o.Key then keep(UIS.InputBegan:Connect(function(i,gp) if not gp and not JL._listening and i.KeyCode == o.Key then ret.Click() end end)) end
        RM.addItem({kind = "toggle", name = o.Name or "Toggle", ret = ret})
        return ret
    end
    function RemoteAPI:Button(o)
        o = o or {}
        local ret = {Click = function() if o.Callback then pcall(o.Callback) end end}
        if o.Key then keep(UIS.InputBegan:Connect(function(i,gp) if not gp and not JL._listening and i.KeyCode == o.Key then ret.Click() end end)) end
        RM.addItem({kind = "button", name = o.Name or "Button", ret = ret})
        return ret
    end
    function RemoteAPI:Keybind(o)
        o = o or {}
        local key = o.Key or o.Default
        local pulses, ret = {}, {}
        local function run() if o.Callback then pcall(o.Callback) end end
        ret.Get = function() return key end
        ret.Press = function() run() end
        ret.Watch = function() end
        ret.OnPulse = function(_, fn) pulses[#pulses + 1] = fn end
        if key then keep(UIS.InputBegan:Connect(function(i,gp)
            if not gp and not JL._listening and i.KeyCode == key then run(); for _,p in ipairs(pulses) do pcall(p) end end
        end)) end
        RM.addItem({kind = "keybind", name = o.Name or "Keybind", ret = ret})
        return ret
    end
    function RemoteAPI:Show() cfgSet("_remote_on", true); RM.refresh() end
    function RemoteAPI:Hide() if RM.gui then RM.gui.Enabled = false end end
    function RemoteAPI:SetOpen(v) RM.refresh(); if RM.built then RM.setOpen(v) end end
    function RemoteAPI:Edit(enabled)
        if enabled == nil then enabled = not RM.editMode end
        return RM.setEditMode(enabled)
    end
    function RemoteAPI:IsOpen() return RM.open end
    function RemoteAPI:SetPosition(ud)
        RM.refresh()
        if RM.built and ud then
            local v = rmViewport()
            RM.px = ud.X.Scale * v.X + ud.X.Offset; RM.py = ud.Y.Scale * v.Y + ud.Y.Offset
            RM.clamp(); RM.savePos()
        end
    end
    function RemoteAPI:Destroy() RM.destroy() end
    function RM.resetPos() cfgSet("_remote_x", 0.012); cfgSet("_remote_y", 0.30); RM.restorePos() end
    function Win:Remote(ropts)
        RM.opts = ropts or RM.opts or {}
        if RM.title and RM.opts.Title then RM.title.Text = RM.opts.Title end
        if RM.opts.Open ~= nil and not cfgHas("_remote_open") then cfgSet("_remote_open", RM.opts.Open) end
        if RM.opts.Key then
            keep(UIS.InputBegan:Connect(function(i,gp)
                if gp or JL._listening then return end
                if i.KeyCode == RM.opts.Key and RM.built then RM.setOpen(not RM.open) end
            end))
        end
        RM.refresh()
        JL._remote = RemoteAPI
        return RemoteAPI
    end
    table.insert(JL._unloadHooks, function() RM.destroy() end)
    table.insert(JL._themeHooks, function()
        if RM.built then
            pcall(function() RM.list.ScrollBarImageColor3 = ACCENTS[1] end)
            pcall(function() RM.hdrBadge.BackgroundColor3 = ACCENTS[1]; RM.hdrBadgeTxt.TextColor3 = ACCENTS[1] end)
        end
    end)
    function Win:Settings()
        if opts.Settings == false then return nil end
        local sTab = self:Tab({Icon = "settings", Type = "Custom", Name = "Settings"})
        local root = sTab.Frame
        local ACC = ACCENTS[1]
        local navW = 146
        local PW = IW - navW - 8
        local nav = Instance.new("Frame"); nav.Size = UDim2.new(0,navW,1,0); nav.BackgroundColor3 = C.panel; nav.BorderSizePixel = 0; nav.Parent = root; corner(10,nav); stroke(C.border,1,nav)
        newTxt({Parent=nav,Text=opts.Title or "JustLib",Font=GB,Size=15,Sz=UDim2.new(1,-28,0,20),Pos=UDim2.new(0,14,0,14)})
        newTxt({Parent=nav,Text="Settings · v" .. JL.Version,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-28,0,14),Pos=UDim2.new(0,14,0,35)})
        local nl = Instance.new("Frame"); nl.Size = UDim2.new(1,-28,0,1); nl.Position = UDim2.new(0,14,0,58); nl.BackgroundColor3 = C.divLine; nl.BackgroundTransparency = 0.4; nl.BorderSizePixel = 0; nl.Parent = nav
        local navList = Instance.new("ScrollingFrame"); navList.Name = "SettingsNavigation"; navList.Size = UDim2.new(1,-16,1,-74); navList.Position = UDim2.new(0,8,0,68)
        navList.BackgroundTransparency = 1; navList.BorderSizePixel = 0; navList.ClipsDescendants = true
        navList.ScrollBarThickness = 3; navList.ScrollBarImageColor3 = ACC; navList.ScrollingDirection = Enum.ScrollingDirection.Y
        navList.Active = true; navList.ScrollingEnabled = true
        navList.CanvasSize = UDim2.new(0,0,0,0); navList.AutomaticCanvasSize = Enum.AutomaticSize.Y; navList.Parent = nav
        local nlay = Instance.new("UIListLayout"); nlay.Padding = UDim.new(0,4); nlay.SortOrder = Enum.SortOrder.LayoutOrder; nlay.Parent = navList
        local navPadding = Instance.new("UIPadding"); navPadding.PaddingBottom = UDim.new(0,16); navPadding.Parent = navList
        local card = Instance.new("Frame"); card.Size = UDim2.new(1,-(navW + 8),1,0); card.Position = UDim2.new(0,navW + 8,0,0); card.BackgroundColor3 = C.panel; card.BorderSizePixel = 0; card.Parent = root; corner(10,card); stroke(C.border,1,card)
        local pgTitle = newTxt({Parent=card,Text="",Font=GB,Size=16,Sz=UDim2.new(1,-32,0,20),Pos=UDim2.new(0,16,0,12)})
        local pgSub = newTxt({Parent=card,Text="",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-32,0,14),Pos=UDim2.new(0,16,0,34)})
        local cl = Instance.new("Frame"); cl.Size = UDim2.new(1,-32,0,1); cl.Position = UDim2.new(0,16,0,56); cl.BackgroundColor3 = C.divLine; cl.BackgroundTransparency = 0.4; cl.BorderSizePixel = 0; cl.Parent = card
        local holder = Instance.new("Frame"); holder.Size = UDim2.new(1,0,1,-60); holder.Position = UDim2.new(0,0,0,60); holder.BackgroundTransparency = 1; holder.ClipsDescendants = true; holder.Parent = card
        local pages = {}; local pOrd = 0
        local function showPage(name)
            for n,p in pairs(pages) do
                local on = (n == name)
                p.sf.Visible = on; p.bar.Visible = on
                p.btn.BackgroundTransparency = on and 0.86 or 1; p.lbl.TextColor3 = on and ACC or C.dim
            end
            pgTitle.Text = name; pgSub.Text = pages[name].sub
        end
        local function newPage(name,sub)
            pOrd = pOrd + 1
            local sf = Instance.new("ScrollingFrame"); sf.Name = "JLSettingsPage_" .. tostring(name); sf:SetAttribute("JLSearchPage", tostring(name)); sf.Size = UDim2.new(1,0,1,0); sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0; sf.ScrollBarThickness = 3
            sf.ScrollBarImageColor3 = ACC; sf.CanvasSize = UDim2.new(0,0,0,0); sf.Visible = false; sf.Parent = holder
            local L = Instance.new("UIListLayout"); L.SortOrder = Enum.SortOrder.LayoutOrder; L.Parent = sf; pad(3,5,3,0,sf)
            L:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sf.CanvasSize = UDim2.new(0,0,0,unscaleWin(L.AbsoluteContentSize.Y) + 8) end)
            local nb = Instance.new("TextButton"); nb.Size = UDim2.new(1,0,0,32); nb.BackgroundColor3 = ACC; nb.BackgroundTransparency = 1; nb.BorderSizePixel = 0; nb.AutoButtonColor = false
            nb.Text = ""; nb.LayoutOrder = pOrd; nb.Parent = navList; corner(7,nb)
            local lbl = newTxt({Parent=nb,Text=name,Font=GB,Size=12,Color=C.dim,Sz=UDim2.new(1,-20,1,0),Pos=UDim2.new(0,14,0,0)})
            local bar = Instance.new("Frame"); bar.Size = UDim2.new(0,3,0,16); bar.Position = UDim2.new(0,0,0.5,-8); bar.BackgroundColor3 = ACC; bar.BorderSizePixel = 0; bar.Visible = false; bar.Parent = nb; corner(2,bar)
            pages[name] = {sf = sf, btn = nb, lbl = lbl, bar = bar, sub = sub}
            JL._searchPageTargets[sf] = function()
                if pages[name].sf.Visible then return false end
                showPage(name)
                return true
            end
            nb.MouseButton1Click:Connect(function() showPage(name) end)
            return sf
        end
        local rowOrd = 0
        local function mkRow(sf,title,desc,ctrlW)
            rowOrd = rowOrd + 1
            local labW = PW - 32 - ctrlW - 14
            local th = fitH(title, 13, GB, labW, 0, 0); local dh = desc and fitH(desc, 10, GM, labW, 0, 0) or 0
            local h = math.max(48, th + dh + (desc and 24 or 22))
            local row = Instance.new("Frame"); row.Name = "JLSettingsRow"; row:SetAttribute("JLSearchSection", tostring(title)); row.Size = UDim2.new(1,0,0,h); row.BackgroundTransparency = 1; row.BorderSizePixel = 0; row.LayoutOrder = rowOrd; row.Parent = sf
            if JL._searchRegister then JL._searchRegister({Name = title, Kind = "Settings", Row = row}) end
            newTxt({Parent=row,Text=title,Font=GB,Size=13,Wrap=true,Sz=UDim2.new(0,labW,0,th),Pos=UDim2.new(0,16,0,desc and 10 or math.floor((h - th) / 2))})
            if desc then newTxt({Parent=row,Text=desc,Font=GM,Size=10,Color=C.dim,Wrap=true,Sz=UDim2.new(0,labW,0,dh),Pos=UDim2.new(0,16,0,10 + th + 3)}) end
            local sep = Instance.new("Frame"); sep.Size = UDim2.new(1,-32,0,1); sep.Position = UDim2.new(0,16,1,-1); sep.BackgroundColor3 = C.divLine; sep.BackgroundTransparency = 0.6; sep.BorderSizePixel = 0; sep.Parent = row
            local ctrl = Instance.new("Frame"); ctrl.Size = UDim2.new(0,ctrlW,0,28); ctrl.AnchorPoint = Vector2.new(1,0.5); ctrl.Position = UDim2.new(1,-16,0.5,0); ctrl.BackgroundTransparency = 1; ctrl.Parent = row
            return row, ctrl
        end
        local resetters = {}
        local function addSwitch(sf,title,desc,flag,default,onChange)
            local _,ctrl = mkRow(sf, title, desc, 34)
            local state = cfgGet(flag, default)
            local sw = mkSwitch(ctrl, UDim2.new(0,0,0.5,-9), state, ACC)
            local function setState(value)
                state = value == true
                sw.Set(state)
                cfgSet(flag, state)
                if onChange then onChange(state) end
            end
            local hit = Instance.new("TextButton"); hit.Size = UDim2.new(1,0,1,0); hit.BackgroundTransparency = 1; hit.Text = ""; hit.Parent = ctrl
            hit.MouseButton1Click:Connect(function() setState(not state) end)
            resetters[#resetters + 1] = function() setState(default) end
            JL._registry[flag] = {Set = function(_,value) setState(value) end, Get = function() return state end}
            JL._noSave[flag] = nil
        end
        local function addSlider(sf,title,desc,flag,default,vmin,vmax,step,suffix,onChange)
            local _,ctrl = mkRow(sf, title, desc, 210)
            local cur = tonumber(cfgGet(flag, default)) or default
            local vl = newTxt({Parent=ctrl,Text=fmtNum(cur,0) .. suffix,Font=GB,Size=11,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,46,1,0),Pos=UDim2.new(1,-46,0,0)})
            local bar
            local function setValue(value)
                cur = snap(tonumber(value) or default, vmin, vmax, step)
                if bar then bar.Set(cur, true) end
                vl.Text = fmtNum(cur,0) .. suffix
                cfgSet(flag, cur)
                if onChange then onChange(cur) end
            end
            bar = mkSliderBar(ctrl, UDim2.new(0,7,0.5,-3), UDim2.new(1,-68,0,6), ACC, vmin, vmax, step, cur, function(v)
                cur = v
                vl.Text = fmtNum(v,0) .. suffix
                cfgSet(flag, v)
                if onChange then onChange(v) end
            end)
            resetters[#resetters + 1] = function() setValue(default) end
            JL._registry[flag] = {Set = function(_,value) setValue(value) end, Get = function() return cur end}
            JL._noSave[flag] = nil
        end
        local function addButton(sf,title,desc,text,danger,fn)
            local _,ctrl = mkRow(sf, title, desc, 100)
            local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,1,0); b.BackgroundColor3 = danger and C.danger or C.btnBg; b.BorderSizePixel = 0; b.Text = text
            b.Font = GB; b.TextSize = 12; b.TextColor3 = Color3.new(1,1,1); b.Parent = ctrl; corner(7,b)
            if not danger then stroke(C.border,1,b) end
            b.MouseButton1Click:Connect(fn)
        end
        local function addValue(sf,title,desc,text)
            local _,ctrl = mkRow(sf, title, desc, 170)
            newTxt({Parent=ctrl,Text=text,Font=GB,Size=11,Color=C.dim,XAlign=Enum.TextXAlignment.Right})
        end
        local pA = newPage("Interface", "Appearance, themes and interface controls")
        addSlider(pA, "UI Scale", "Enlarges or shrinks the whole window", "_uiscale", 100, 70, 130, 5, "%", function(v)
            userScale = v / 100; uiScale.Scale = userScale
        end)
        addSlider(pA, "Background Blur", "Blurs the game behind the hub while it is open", "_blur", 0, 0, 100, 1, "%", function(v)
            blurPct = v; applyBlur()
        end)
        addSlider(pA, "Window Backdrop", "Opacity of the dark panel behind the sections", "_backdrop", 65, 0, 100, 1, "%", function(v)
            backdropV = v; if opts.Backdrop ~= false then backdrop.BackgroundTransparency = 1 - v / 100 end
        end)
        addSwitch(pA, "Show FPS", "FPS counter on the badge", "_showfps", true, function(v) fpsL.Visible = v end)
        addSwitch(pA, "Animations", "Tab slide and open/close animations", "_anim", true, function(v) animOn = v end)
        addSwitch(pA, "Sidebar Labels", "Tab names under the sidebar icons. Takes effect the next time the hub starts", "_sidebar_labels", opts.SidebarLabels == true, function()
            JL:Notify({Title = "Sidebar", Desc = "Restart the hub to apply", Type = "Info", Duration = 3})
        end)
        local pT = pA
        rowOrd = rowOrd + 1
        local themeIntro = Instance.new("Frame"); themeIntro.Size = UDim2.new(1,0,0,26); themeIntro.BackgroundTransparency = 1; themeIntro.LayoutOrder = rowOrd; themeIntro.Parent = pT
        newTxt({Parent=themeIntro,Text="Pick a palette — everything on screen repaints live",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-32,1,0),Pos=UDim2.new(0,16,0,0)})
        rowOrd = rowOrd + 1
        local themeCols = math.max(1, math.floor((PW - 32 + 8) / 136))
        local themeRows = math.ceil(#JL._themeOrder / themeCols)
        local themeGridH = themeRows > 0 and (themeRows * 74 + (themeRows - 1) * 8) or 0
        local themeGrid = Instance.new("Frame"); themeGrid.Size = UDim2.new(1,-32,0,themeGridH); themeGrid.Position = UDim2.new(0,16,0,0); themeGrid.BackgroundTransparency = 1; themeGrid.LayoutOrder = rowOrd; themeGrid.Parent = pT
        local tgl = Instance.new("UIGridLayout"); tgl.CellSize = UDim2.new(0,128,0,74); tgl.CellPadding = UDim2.new(0,8,0,8); tgl.SortOrder = Enum.SortOrder.LayoutOrder; tgl.Parent = themeGrid
        table.insert(JL._noRepaintRoots, themeGrid)
        local themeCards = {}
        local function paintCards()
            for nm,ref in pairs(themeCards) do
                local on = (nm == JL._currentTheme)
                ref.sub.Text = on and "Active" or ""
                ref.ring.Thickness = on and 2 or 1
            end
        end
        for i,nm in ipairs(JL._themeOrder) do
            local th = JL._themes[nm]
            local card = Instance.new("Frame"); card.Size = UDim2.new(0,128,0,74); card.BackgroundColor3 = th.panel; card.BorderSizePixel = 0; card.LayoutOrder = i; card.Parent = themeGrid
            corner(9,card); local ring = stroke(th.accents[1],1,card)
            local prevBar = Instance.new("Frame"); prevBar.Size = UDim2.new(1,-12,0,28); prevBar.Position = UDim2.new(0,6,0,6); prevBar.BackgroundColor3 = th.pHdr; prevBar.BorderSizePixel = 0; prevBar.Parent = card; corner(6,prevBar)
            local dotsHolder = Instance.new("Frame"); dotsHolder.Size = UDim2.new(0,0,0,10); dotsHolder.Position = UDim2.new(0.5,0,0.5,-5); dotsHolder.AnchorPoint = Vector2.new(0.5,0); dotsHolder.BackgroundTransparency = 1; dotsHolder.Parent = prevBar
            local dl = Instance.new("UIListLayout"); dl.FillDirection = Enum.FillDirection.Horizontal; dl.Padding = UDim.new(0,4); dl.SortOrder = Enum.SortOrder.LayoutOrder; dl.Parent = dotsHolder
            dl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() dotsHolder.Size = UDim2.new(0,dl.AbsoluteContentSize.X,0,10) end)
            for k = 1,4 do
                local dot = Instance.new("Frame"); dot.Size = UDim2.new(0,10,0,10); dot.BackgroundColor3 = th.accents[k] or th.accents[1]; dot.BorderSizePixel = 0; dot.LayoutOrder = k; dot.Parent = dotsHolder; corner(5,dot)
            end
            newTxt({Parent=card,Text=nm,Font=GB,Size=12,Color=th.txt,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-8,0,16),Pos=UDim2.new(0,4,0,40)})
            local sub = newTxt({Parent=card,Text="",Font=GM,Size=9,Color=th.accents[1],XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-8,0,12),Pos=UDim2.new(0,4,0,57)})
            local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.Parent = card
            themeCards[nm] = {card = card, ring = ring, sub = sub}
            btn.MouseButton1Click:Connect(function() JL:SetTheme(nm); paintCards() end)
        end
        paintCards()
        local pI = pA
        do
            local _,ctrl = mkRow(pI, "Menu Key", "Click, then press a key. Esc cancels, Backspace clears", 84)
            local chip = mkKeyChip(ctrl, UDim2.new(0,0,0.5,-11), hotkey and hotkey.Name or "None", function(k)
                hotkey = k; cfgSet("_hotkey", k and k.Name or "None")
            end)
            JL._registry["_hotkey"] = {Set = function(_,value)
                local key = keyFromName(tostring(value or "None"))
                hotkey = key
                chip.Set(key)
                cfgSet("_hotkey", key and key.Name or "None")
            end, Get = function() return hotkey and hotkey.Name or "None" end}
            JL._noSave["_hotkey"] = nil
            resetters[#resetters + 1] = function() local k = keyFromName(opts.Hotkey and opts.Hotkey.Name or "RightShift"); hotkey = k; chip.Set(k); cfgSet("_hotkey", k and k.Name or "None") end
        end
        do
            local _,ctrl = mkRow(pI, "Badge Position", "Where the small FPS badge sits on screen", 190)
            local function apply(name)
                local p = BPOS[name:lower()]
                if p then
                    _workspace.BadgePosition = p
                    tw(badge2,{Position = p},.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
                end
                cfgSet("_badgepos", name)
            end
            local seg = mkSegmented(ctrl, UDim2.new(0,0,0,0), UDim2.new(1,0,1,0), {"Top","Center","Bottom"}, tostring(cfgGet("_badgepos","Top")), ACC, apply)
            JL._registry["_badgepos"] = {Set = function(_,value) seg.Set(value, true); apply(value) end, Get = function() return cfgGet("_badgepos","Top") end}
            JL._noSave["_badgepos"] = nil
            resetters[#resetters + 1] = function() seg.Set("Top", true); apply("Top") end
        end
        do
            local _,ctrl = mkRow(pI, "Tooltip Position", "Which side of a control its hover tooltip appears on", 260)
            local function applyTooltipSide(value) cfgSet("_tooltip_side", value) end
            local seg = mkSegmented(ctrl, UDim2.new(0,0,0,0), UDim2.new(1,0,1,0), {"Top","Bottom","Left","Right"}, tostring(cfgGet("_tooltip_side","Right")), ACC, applyTooltipSide)
            JL._registry["_tooltip_side"] = {Set = function(_,value) seg.Set(value, true); applyTooltipSide(value) end, Get = function() return cfgGet("_tooltip_side","Right") end}
            JL._noSave["_tooltip_side"] = nil
            resetters[#resetters + 1] = function() seg.Set("Right", true); applyTooltipSide("Right") end
        end
        local pPrivacy = newPage("Privacy", "Hide your identity on your screen while recording")
        addSwitch(pPrivacy, "Streamer Mode", "Locally masks your username and display name in visible UI text, including the hub, player list and overhead labels", "_streamer_mode", false, function(v)
            JL:SetStreamerMode(v)
        end)
        JL:SetStreamerMode(cfgGet("_streamer_mode", false) == true)
        local pN = newPage("Notifications", "What shows, where, and for how long")
        addSwitch(pN, "Show Regular", "Info / success notifications", "_notify_show_regular", true, function() end)
        addSwitch(pN, "Show Warnings", "Yellow warning notifications", "_notify_show_warning", true, function() end)
        addSwitch(pN, "Show Errors", "Red error notifications", "_notify_show_error", true, function() end)
        addSlider(pN, "Default Duration", "How long a notification stays, unless it sets its own Duration", "_notify_duration", 5, 2, 15, 1, "s", function() end)
        do
            local _,ctrl = mkRow(pN, "Notify Side", "Which corner of the screen notifications appear in", 260)
            local function applyNotifySide(value)
                cfgSet("_notify_side", value)
                if JL._notifyReposition then JL._notifyReposition() end
            end
            local seg = mkSegmented(ctrl, UDim2.new(0,0,0,0), UDim2.new(1,0,1,0), {"TopLeft","TopRight","BottomLeft","BottomRight"}, tostring(cfgGet("_notify_side","TopRight")), ACC, applyNotifySide)
            JL._registry["_notify_side"] = {Set = function(_,value) seg.Set(value, true); applyNotifySide(value) end, Get = function() return cfgGet("_notify_side","TopRight") end}
            JL._noSave["_notify_side"] = nil
            resetters[#resetters + 1] = function() seg.Set("TopRight", true); applyNotifySide("TopRight") end
        end
        addSwitch(pN, "Notify Stack", "Repeated notifications with the same text pile into one, shown as x1, x2...", "_notify_stack", false, function() end)
        addButton(pN, "Test Notification", "Sends a sample notification with your current settings", "Send", false, function()
            JL:Notify({Title = "Test Notification", Desc = "This is what your notifications look like.", Type = "Info"})
        end)
        local pV = newPage("Preview UI", "Settings for the Preview tab")
        local function pvApply() if JL._preview and JL._preview.ApplySettings then JL._preview:ApplySettings() end end
        addSwitch(pV, "Auto Rotate", "Spins the model on the Preview page. Drag to rotate by hand, scroll or pinch to zoom", "_pv_autorotate", true, function() pvApply() end)
        addSlider(pV, "Rotate Speed", "Degrees per second for Auto Rotate", "_pv_rotspeed", 40, 5, 180, 5, "°/s", function() pvApply() end)
        addSlider(pV, "Card Size", "Minimum width of the cards in the grid", "_pv_card", 140, 100, 240, 10, "px", function() pvApply() end)
        addSwitch(pV, "Animations", "Slide-out panel and card animations", "_pv_anim", true, function() end)
        addSwitch(pV, "Remember Last Tab", "Reopens the Preview tab on the tab and page you used last", "_pv_remember", true, function() end)
        addButton(pV, "Open Preview", "Creates the Preview tab if it does not exist and switches to it", "Open", false, function()
            if JL._preview then JL._preview:Open() else JL:Notify({Title = "Preview UI", Desc = "No Preview created. Use JL:Preview()", Type = "Warn", Duration = 3}) end
        end)
        local pD = newPage("Addons", "Extensions loaded from the Addons folder")
        addSwitch(pD, "Enable Addons", "Shows the Addons tab and lets you load addon files. Addons are code with full access: only use ones you trust", "_addons_on", false, function(v) AM.setEnabled(v) end)
        addSwitch(pD, "Version Warnings", "Warns when an addon was made for a different JustLib version", "_addons_warn", true, function() end)
        addButton(pD, "Reload Addons", "Re-reads the folder and restarts running addons", "Reload", false, function()
            if AM.tab then AM.refresh() else JL:Notify({Title = "Addons", Desc = "Turn on Enable Addons first", Type = "Warn", Duration = 3}) end
        end)
        addValue(pD, "Folder", "Put .lua / .txt files here. Mark functions with --@toggle / --@button / --@slider / --@dropdown above them", AM.dir)
        local pR = newPage("Remote", "Floating quick-access panel for toggles, buttons and keybinds")
        addButton(pR, "Edit Remote Items", "Enter edit mode, browse your tabs and pin supported controls with the + button beside them", "Edit", false, function()
            RM.setEditMode(not RM.editMode)
        end)
        addButton(pR, "Clear All Pins", "Removes every function from Remote UI", "Clear", false, function()
            if confirmDialog("Clear Remote UI", "Remove all pinned functions from Remote UI?", {Danger = true, ConfirmText = "Clear"}) then
                RM.clearPins()
            end
        end)
        addSwitch(pR, "Show Remote", "Shows the floating panel only when at least one function is pinned", "_remote_on", true, function() RM.refresh() end)
        addSlider(pR, "Remote Scale", "Size of the floating panel", "_remote_scale", 100, 70, 150, 5, "%", function() RM.applyScale() end)
        addSlider(pR, "Remote Opacity", "How solid the panel and its button are", "_remote_opacity", 94, 40, 100, 2, "%", function() RM.applyOpacity() end)
        addButton(pR, "Expand / Collapse", "Opens the panel or folds it into a small button", "Toggle", false, function()
            RM.refresh(); if RM.built then RM.setOpen(not RM.open) end
        end)
        addButton(pR, "Reset Position", "Moves the panel back to its default place", "Reset", false, function() RM.resetPos() end)
        local pP = newPage("Presets", "Save and load snapshots of your enabled features")
        addSwitch(pP, "Auto Save", "Remembers this hub's toggles and values between launches. Library settings are managed separately below", "_autosave", true, function(v)
            JL._autoSave = v
            if v then cfgFlush() end
        end)
        addSwitch(pP, "Save Settings", "Includes JustXLibrary interface settings when you create or rewrite a preset", "_preset_save_settings", false, function() end)
        addSwitch(pP, "Global Settings", "Shares JustXLibrary interface settings with other hubs using this library. Game toggles remain separate", "_global_settings", _workspace.GlobalSettingsEnabled, function(v)
            if v then
                hubConfig.ClearPresetSettingsOverrides()
                for flag,val in pairs(_globalSettingsData) do
                    if isLibrarySetting(flag) then
                        if flag == "_theme" then
                            pcall(function() JL:SetTheme(val) end)
                        else
                            local ctrl = JL._registry[flag]
                            if ctrl and ctrl.Set then pcall(function() ctrl:Set(val) end) end
                        end
                    end
                end
                if JL._notifyReposition then pcall(JL._notifyReposition) end
                if JL._remoteRefresh then pcall(JL._remoteRefresh) end
                if JL._remoteRestorePos then pcall(JL._remoteRestorePos) end
            end
        end)
        cfgSet("_multihub_tabs", _workspace.MultiHubTabsEnabled ~= false)
        addSwitch(pP, "Multi-Hub Tabs", "Allows different HubIds to stay open together as separate tabs. When disabled, a new hub replaces the currently running hub.", "_multihub_tabs", _workspace.MultiHubTabsEnabled ~= false, function(v)
            _workspace.MultiHubTabsEnabled = v == true
            saveWorkspaceSettings()
        end)
        local profileNameBox
        do
            local _,ctrl = mkRow(pP, "Preset Name", "Used by \"Save As New\" below", 180)
            profileNameBox = Instance.new("TextBox"); profileNameBox.Size = UDim2.new(1,0,0,26); profileNameBox.BackgroundColor3 = C.pHdr
            profileNameBox.BorderSizePixel = 0; profileNameBox.Font = GB; profileNameBox.TextSize = 12; profileNameBox.TextColor3 = C.txt
            profileNameBox.PlaceholderText = "my-preset"; profileNameBox.PlaceholderColor3 = C.dim; profileNameBox.ClearTextOnFocus = false
            profileNameBox.Text = ""; profileNameBox.Parent = ctrl; corner(6,profileNameBox); stroke(C.border,1,profileNameBox)
        end
        rowOrd = rowOrd + 1
        local selRow = Instance.new("Frame"); selRow.Size = UDim2.new(1,0,0,48); selRow.BackgroundTransparency = 1; selRow.LayoutOrder = rowOrd; selRow.Parent = pP
        newTxt({Parent=selRow,Text="Saved Presets",Font=GB,Size=13,Sz=UDim2.new(0,PW - 220,0,20),Pos=UDim2.new(0,16,0,14)})
        local selCtrl = Instance.new("Frame"); selCtrl.Size = UDim2.new(0,170,0,26); selCtrl.Position = UDim2.new(1,-186,0,11); selCtrl.BackgroundTransparency = 1; selCtrl.Parent = selRow
        local selBtn = Instance.new("TextButton"); selBtn.Size = UDim2.new(1,0,1,0); selBtn.BackgroundColor3 = C.btnBg; selBtn.AutoButtonColor = false; selBtn.BorderSizePixel = 0; selBtn.Text = ""; selBtn.Parent = selCtrl; corner(6,selBtn); stroke(C.border,1,selBtn)
        local selLbl = newTxt({Parent=selBtn,Text="— none —",Font=GB,Size=11,Sz=UDim2.new(1,-24,1,0),Pos=UDim2.new(0,8,0,0)})
        local selArr = newTxt({Parent=selBtn,Text="▼",Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,20,1,0),Pos=UDim2.new(1,-20,0,0)})
        local sep2 = Instance.new("Frame"); sep2.Size = UDim2.new(1,-32,0,1); sep2.Position = UDim2.new(0,16,1,-1); sep2.BackgroundColor3 = C.divLine; sep2.BackgroundTransparency = 0.6; sep2.BorderSizePixel = 0; sep2.Parent = selRow
        local list2 = Instance.new("ScrollingFrame"); list2.Size = UDim2.new(1,-32,0,0); list2.Position = UDim2.new(0,16,0,44); list2.BackgroundColor3 = C.pHdr; list2.BorderSizePixel = 0
        list2.ClipsDescendants = true; list2.ScrollBarThickness = 3; list2.ScrollBarImageColor3 = C.border; list2.CanvasSize = UDim2.new(0,0,0,0); list2.Visible = false; list2.Parent = selRow; corner(6,list2); stroke(C.border,1,list2)
        local lay2 = Instance.new("UIListLayout"); lay2.SortOrder = Enum.SortOrder.LayoutOrder; lay2.Padding = UDim.new(0,2); lay2.Parent = list2; pad(4,4,4,4,list2)
        lay2:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() list2.CanvasSize = UDim2.new(0,0,0,unscaleWin(lay2.AbsoluteContentSize.Y) + 8) end)
        local selectedProfile = (tostring(cfgGet("_autoload_name","")) ~= "") and cfgGet("_autoload_name","") or nil
        local open2 = false
        local function closeList2()
            open2 = false; selArr.Text = "▼"
            tw(list2,{Size = UDim2.new(1,-32,0,0)},.15); selRow.Size = UDim2.new(1,0,0,48)
            trackedDelay(.16, function() if not open2 then list2.Visible = false end end)
        end
        local function refreshProfiles()
            for _,c in ipairs(list2:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            local names = listProfiles()
            if selectedProfile and not table.find(names, selectedProfile) then selectedProfile = nil end
            selLbl.Text = selectedProfile or "— none —"
            for i,nm in ipairs(names) do
                local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,24); b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.AutoButtonColor = false
                b.Text = nm; b.Font = GB; b.TextSize = 11; b.TextColor3 = (nm == selectedProfile) and ACC or C.txt; b.LayoutOrder = i; b.Parent = list2; corner(5,b)
                b.MouseEnter:Connect(function() if touchLast() then return end tw(b,{BackgroundColor3 = C.btnHov},.1) end)
                b.MouseLeave:Connect(function() tw(b,{BackgroundColor3 = C.btnBg},.1) end)
                b.MouseButton1Click:Connect(function() selectedProfile = nm; selLbl.Text = nm; closeList2() end)
            end
        end
        selBtn.MouseButton1Click:Connect(function()
            open2 = not open2
            if open2 then
                refreshProfiles(); list2.Visible = true
                local h = math.min(#listProfiles() * 26 + 8, 130)
                selArr.Text = "▲"; tw(list2,{Size = UDim2.new(1,-32,0,h)},.18); selRow.Size = UDim2.new(1,0,0,48 + 4 + h)
            else closeList2() end
        end)
        refreshProfiles()
        addButton(pP, "Save As New", "Saves your currently enabled features under the name typed above", "Save", false, function()
            local nm = profileNameBox.Text:gsub("^%s+",""):gsub("%s+$","")
            if nm == "" then JL:Notify({Title = "Presets", Desc = "Type a name first", Type = "Warn", Duration = 3}); return end
            if saveProfile(nm) then
                JL:Notify({Title = "Preset Saved", Desc = "Saved \"" .. nm .. "\"", Type = "Success", Duration = 3})
                selectedProfile = safeFileName(nm); refreshProfiles()
            else
                JL:Notify({Title = "Presets", Desc = "Could not save — unsupported executor", Type = "Error", Duration = 4})
            end
        end)
        addButton(pP, "Load Selected", "Applies the selected preset's toggles immediately", "Load", false, function()
            if not selectedProfile then JL:Notify({Title = "Presets", Desc = "Pick a preset first", Type = "Warn", Duration = 3}); return end
            if loadProfile(selectedProfile) then
                JL:Notify({Title = "Preset Loaded", Desc = "Applied \"" .. selectedProfile .. "\"", Type = "Success", Duration = 3})
            else
                JL:Notify({Title = "Presets", Desc = "Could not load that preset", Type = "Error", Duration = 4})
            end
        end)
        addButton(pP, "Rewrite Selected", "Overwrites the selected preset with your current toggles", "Rewrite", false, function()
            if not selectedProfile then JL:Notify({Title = "Presets", Desc = "Pick a preset first", Type = "Warn", Duration = 3}); return end
            if saveProfile(selectedProfile) then
                JL:Notify({Title = "Preset Rewritten", Desc = "\"" .. selectedProfile .. "\" updated", Type = "Success", Duration = 3})
            end
        end)
        addButton(pP, "Delete Selected", "Permanently deletes the selected preset", "Delete", true, function()
            if not selectedProfile then JL:Notify({Title = "Presets", Desc = "Pick a preset first", Type = "Warn", Duration = 3}); return end
            local nm = selectedProfile
            if confirmDialog("Delete Preset", "Permanently delete \"" .. nm .. "\"?", {Danger = true, ConfirmText = "Delete", CancelText = "Cancel"}) then
                deleteProfile(nm)
                if cfgGet("_autoload_name","") == nm then cfgSet("_autoload_name","") end
                selectedProfile = nil; refreshProfiles()
            end
        end)
        addSwitch(pP, "Auto Load On Start", "Loads the selected preset automatically every time the hub starts", "_autoload", false, function(v)
            if v then
                if not selectedProfile then
                    JL:Notify({Title = "Presets", Desc = "Pick a preset to auto-load first", Type = "Warn", Duration = 3})
                end
                cfgSet("_autoload_name", selectedProfile or "")
            end
        end)
        addValue(pP, "Config File", "Interface settings always save. Toggles and values save while Auto Save is on", _cfgFile or "not set (nothing is saved)")
        addButton(pP, "Copy Config", "Copies the whole saved config (interface + toggles) as JSON to the clipboard", "Copy", false, function()
            if setclipboard then
                setclipboard(HTTP:JSONEncode(_cfgData)); JL:Notify({Title = "Config", Desc = "Copied to clipboard", Type = "Success", Duration = 3})
            else JL:Notify({Title = "Config", Desc = "Clipboard is not supported by your executor", Type = "Error", Duration = 4}) end
        end)
        local importBox
        do
            rowOrd = rowOrd + 1
            local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,72); row.BackgroundTransparency = 1; row.LayoutOrder = rowOrd; row.Parent = pP
            newTxt({Parent=row,Text="Import Config",Font=GB,Size=13,Sz=UDim2.new(1,-32,0,16),Pos=UDim2.new(0,16,0,8)})
            newTxt({Parent=row,Text="Paste a copied config below, then Import",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-32,0,12),Pos=UDim2.new(0,16,0,24)})
            local pasteBg = Instance.new("Frame"); pasteBg.Size = UDim2.new(1,-32,0,28); pasteBg.Position = UDim2.new(0,16,0,40); pasteBg.BackgroundColor3 = C.pHdr; pasteBg.BorderSizePixel = 0; pasteBg.Parent = row; corner(6,pasteBg); stroke(C.border,1,pasteBg)
            importBox = Instance.new("TextBox"); importBox.Size = UDim2.new(1,-16,1,0); importBox.Position = UDim2.new(0,8,0,0); importBox.BackgroundTransparency = 1
            importBox.PlaceholderText = "Paste JSON here..."; importBox.PlaceholderColor3 = C.dim; importBox.Font = GB; importBox.TextSize = 11; importBox.TextColor3 = C.txt
            importBox.ClearTextOnFocus = false; importBox.Text = ""; importBox.Parent = pasteBg
            local sep = Instance.new("Frame"); sep.Size = UDim2.new(1,-32,0,1); sep.Position = UDim2.new(0,16,1,-1); sep.BackgroundColor3 = C.divLine; sep.BackgroundTransparency = 0.6; sep.BorderSizePixel = 0; sep.Parent = row
        end
        addButton(pP, "Import Pasted Config", "Applies any matching feature toggles found in the pasted text above", "Import", false, function()
            local raw = importBox.Text
            if not raw or raw:gsub("%s","") == "" then JL:Notify({Title = "Presets", Desc = "Paste a config first", Type = "Warn", Duration = 3}); return end
            local ok,data = pcall(HTTP.JSONDecode, HTTP, raw)
            if not ok or type(data) ~= "table" then JL:Notify({Title = "Presets", Desc = "That doesn't look like valid config JSON", Type = "Error", Duration = 4}); return end
            local applied = 0
            for flag,val in pairs(data) do
                local ctrl = JL._registry[flag]
                if ctrl and ctrl.Set then pcall(function() ctrl:Set(val) end); applied = applied + 1 end
            end
            JL:Notify({Title = "Config Imported", Desc = applied .. " setting(s) applied", Type = (applied > 0) and "Success" or "Warn", Duration = 4})
        end)
        local pDebug = newPage("Debug", "Library information and recovery tools")
        addButton(pDebug, "Reset interface", "Restores every setting on the Interface page", "Reset", true, function()
            if confirmDialog("Reset Settings", "Restore all interface settings to their defaults?", {Danger = true, ConfirmText = "Reset"}) then
                for _,fn in ipairs(resetters) do pcall(fn) end
            end
        end)
        addValue(pDebug, "Version", nil, "JustLib v" .. JL.Version)
        addValue(pDebug, "Tabs loaded", nil, tostring(_tabCount))
        addValue(pDebug, "Columns", "Visible at once. Left Shift + wheel scrolls sideways", tostring(VIS))
        addButton(pDebug, "Close Hub", "Fully unloads the hub", "Unload", true, function()
            if unloadDialog() then destroyHub() end
        end)
        showPage("Interface")
        AM.boot()
        RM.refresh()
        return sTab
    end
    trackedDefer(function()
        if _dead then return end
        if cfgGet("_autoload", false) then
            local nm = cfgGet("_autoload_name", "")
            if nm and nm ~= "" then pcall(loadProfile, nm) end
        end
    end)
    function Win:HomeTab(hopts)
        hopts = hopts or {}
        local T = self:Tab({Name = hopts.Name or "Home", Icon = hopts.Icon or "house", Tooltip = hopts.Tooltip, Type = "Custom"})
        local id = T.Id
        if tabUI[id] then tabUI[id].btn.LayoutOrder = -1000 end
        switchToTab(id)
        local root = T.Frame
        local scroll = Instance.new("ScrollingFrame"); scroll.Size = UDim2.new(1,0,1,0); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = ACCENTS[1]; scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.Parent = root
        local listCon = Instance.new("Frame"); listCon.Size = UDim2.new(1,-6,0,0); listCon.Position = UDim2.new(0,3,0,3); listCon.BackgroundTransparency = 1; listCon.Parent = scroll
        local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0,10); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = listCon
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local h = unscaleWin(list.AbsoluteContentSize.Y)
            listCon.Size = UDim2.new(1,-6,0,h); scroll.CanvasSize = UDim2.new(0,0,0,h + 14)
        end)
        local ord = 0
        local function newCard(h)
            ord = ord + 1
            local c = Instance.new("Frame"); c.Size = UDim2.new(1,0,0,h); c.BackgroundColor3 = C.panel; c.BorderSizePixel = 0; c.LayoutOrder = ord; c.Parent = listCon
            corner(10,c); stroke(C.border,1,c)
            return c
        end
        do
            ord = ord + 1
            local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,26); row.BackgroundTransparency = 1; row.LayoutOrder = ord; row.Parent = listCon
            newTxt({Parent=row,Text="Welcome to " .. (hopts.WelcomeTitle or opts.Title or "the Hub") .. "!",Font=GB,Size=17,Sz=UDim2.new(1,0,1,0),Pos=UDim2.new(0,2,0,0)})
        end
        do
            local h = 180
            local card = newCard(h)
            card.BackgroundTransparency = 1
            for _,child in ipairs(card:GetChildren()) do
                if child:IsA("UIStroke") then child.Transparency = 1 end
            end

            local playerCard = Instance.new("Frame")
            playerCard.Name = "PlayerCard"
            playerCard.Size = UDim2.new(1,-194,0,180)
            playerCard.Position = UDim2.new(0,0,0,0)
            playerCard.BackgroundColor3 = C.panel
            playerCard.BorderSizePixel = 0
            playerCard.ClipsDescendants = true
            playerCard.Parent = card
            corner(10,playerCard)
            stroke(C.border,1,playerCard)

            local profileAccent = Instance.new("Frame")
            profileAccent.Size = UDim2.new(0,3,1,-20)
            profileAccent.Position = UDim2.new(0,0,0,10)
            profileAccent.BackgroundColor3 = ACCENTS[1]
            profileAccent.BorderSizePixel = 0
            profileAccent.Parent = playerCard
            corner(2,profileAccent)

            newTxt({Parent=playerCard,Text="PLAYER PROFILE",Font=GB,Size=10,Color=C.dim,Sz=UDim2.new(1,-104,0,14),Pos=UDim2.new(0,14,0,10)})

            local statusChip = Instance.new("Frame")
            statusChip.Name = "PlayerStatus"
            statusChip.Size = UDim2.new(0,78,0,22)
            statusChip.Position = UDim2.new(1,-90,0,7)
            statusChip.BackgroundColor3 = C.pHdr
            statusChip.BorderSizePixel = 0
            statusChip.Parent = playerCard
            corner(7,statusChip)
            local statusDot = Instance.new("Frame")
            statusDot.Size = UDim2.new(0,6,0,6)
            statusDot.Position = UDim2.new(0,8,0.5,-3)
            statusDot.BackgroundColor3 = C.fpsGrn
            statusDot.BorderSizePixel = 0
            statusDot.Parent = statusChip
            corner(3,statusDot)
            newTxt({Parent=statusChip,Text="ONLINE",Font=GB,Size=9,Color=C.fpsGrn,Sz=UDim2.new(1,-20,1,0),Pos=UDim2.new(0,18,0,0)})

            local avatar = Instance.new("ImageLabel")
            avatar.Size = UDim2.new(0,64,0,64)
            avatar.Position = UDim2.new(0,14,0,48)
            avatar.BackgroundColor3 = C.pHdr
            avatar.BorderSizePixel = 0
            avatar.Parent = playerCard
            avatar:SetAttribute("JLNoRepaint", true)
            corner(32,avatar)
            trackedSpawn(function()
                local ok,content = pcall(function()
                    return game:GetService("Players"):GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                end)
                if ok then avatar.Image = content end
            end)

            newTxt({Parent=playerCard,Text="Welcome back,",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-104,0,13),Pos=UDim2.new(0,90,0,48)})
            newTxt({Parent=playerCard,Text=LP.DisplayName,Font=GB,Size=16,Sz=UDim2.new(1,-104,0,22),Pos=UDim2.new(0,90,0,63)})
            newTxt({Parent=playerCard,Text="@" .. LP.Name,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-104,0,14),Pos=UDim2.new(0,90,0,86)})

            local profileDivider = Instance.new("Frame")
            profileDivider.Size = UDim2.new(1,-28,0,1)
            profileDivider.Position = UDim2.new(0,14,0,122)
            profileDivider.BackgroundColor3 = C.border
            profileDivider.BorderSizePixel = 0
            profileDivider.Parent = playerCard

            local execName,execVer = detectExecutor()
            local executorText = execName or "Unknown"
            if execVer and execVer ~= "" then executorText = executorText .. " " .. tostring(execVer) end
            newTxt({Parent=playerCard,Text="EXECUTOR",Font=GB,Size=9,Color=C.dim,Sz=UDim2.new(0.48,-18,0,12),Pos=UDim2.new(0,14,0,132)})
            newTxt({Parent=playerCard,Text=executorText,Font=GB,Size=11,Color=execName and C.txt or C.dim,Sz=UDim2.new(0.48,-18,0,16),Pos=UDim2.new(0,14,0,148)})
            newTxt({Parent=playerCard,Text="ACCOUNT AGE",Font=GB,Size=9,Color=C.dim,Sz=UDim2.new(0.48,-18,0,12),Pos=UDim2.new(0.52,4,0,132)})
            newTxt({Parent=playerCard,Text=tostring(LP.AccountAge) .. " days",Font=GB,Size=11,Sz=UDim2.new(0.48,-18,0,16),Pos=UDim2.new(0.52,4,0,148)})

            local changelogFrame = Instance.new("Frame")
            changelogFrame.Name = "ChangelogFrame"
            changelogFrame.Size = UDim2.new(0,180,0,180)
            changelogFrame.Position = UDim2.new(1,-180,0,0)
            changelogFrame.BackgroundColor3 = C.panel
            changelogFrame.BorderSizePixel = 0
            changelogFrame.ClipsDescendants = true
            changelogFrame.Parent = card
            corner(9,changelogFrame)
            stroke(C.border,1,changelogFrame)

            local changelogAccent = Instance.new("Frame")
            changelogAccent.Size = UDim2.new(1,-20,0,2)
            changelogAccent.Position = UDim2.new(0,10,0,0)
            changelogAccent.BackgroundColor3 = ACCENTS[1]
            changelogAccent.BorderSizePixel = 0
            changelogAccent.Parent = changelogFrame
            corner(1,changelogAccent)

            newTxt({Parent=changelogFrame,Text="JUSTLIB  /  UPDATES",Font=GB,Size=8,Color=C.dim,Sz=UDim2.new(1,-72,0,12),Pos=UDim2.new(0,10,0,8)})
            newTxt({Parent=changelogFrame,Text="RELEASE HISTORY",Font=GB,Size=9,Color=C.txt,Sz=UDim2.new(1,-20,0,14),Pos=UDim2.new(0,10,0,20)})
            local changelogCount = # (type(hopts.Changelog) == "table" and hopts.Changelog or {})
            newTxt({Parent=changelogFrame,Text=tostring(changelogCount) .. " VERSIONS",Font=GB,Size=7,Color=ACCENTS[1],XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,64,0,12),Pos=UDim2.new(1,-74,0,9)})

            local changelogScroll = Instance.new("ScrollingFrame")
            changelogScroll.Name = "ChangelogList"
            changelogScroll.Size = UDim2.new(1,-12,1,-48)
            changelogScroll.Position = UDim2.new(0,6,0,42)
            changelogScroll.BackgroundTransparency = 1
            changelogScroll.BorderSizePixel = 0
            changelogScroll.ScrollBarThickness = 2
            changelogScroll.ScrollBarImageColor3 = ACCENTS[1]
            changelogScroll.ScrollingDirection = Enum.ScrollingDirection.Y
            changelogScroll.CanvasSize = UDim2.new(0,0,0,0)
            changelogScroll.Parent = changelogFrame

            changelogScroll.Active = true
            local changelogLayout = Instance.new("UIListLayout")
            changelogLayout.Padding = UDim.new(0,5)
            changelogLayout.SortOrder = Enum.SortOrder.LayoutOrder
            changelogLayout.Parent = changelogScroll

            local function refreshChangelogCanvas()
                changelogScroll.CanvasSize = UDim2.new(0,0,0,changelogLayout.AbsoluteContentSize.Y + 6)
            end
            changelogLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshChangelogCanvas)

            local entries = type(hopts.Changelog) == "table" and hopts.Changelog or {}
            local entryCount = 0
            local function entryText(entry)
                local heading,description,version,changes
                if type(entry) == "table" then
                    heading = entry.Title or entry.Version or entry.Name
                    version = entry.Version
                    description = entry.Description or entry.Desc or entry.Text
                    changes = type(entry.Changes) == "table" and entry.Changes or {}
                else
                    description = entry
                    changes = {}
                end
                heading = heading ~= nil and tostring(heading) or nil
                version = version ~= nil and tostring(version) or nil
                description = description ~= nil and tostring(description) or ""
                return heading,description,version,changes
            end
            local function showChangelogDetails(entry,entryIndex)
                local heading,description,version,changes = entryText(entry)
                if not entryIndex then
                    for i,candidate in ipairs(entries) do
                        if candidate == entry then entryIndex = i; break end
                    end
                end
                entryIndex = entryIndex or 1
                local navigableCount = 0
                for _,candidate in ipairs(entries) do
                    local h,d = entryText(candidate)
                    if (h and h ~= "") or d ~= "" then navigableCount = navigableCount + 1 end
                end
                local existing = root:FindFirstChild("ChangelogDetailOverlay")
                if existing then existing:Destroy() end
                local camera = workspace.CurrentCamera
                local viewport = camera and camera.ViewportSize or Vector2.new(800,600)
                local panelW = math.min(320,math.max(250,viewport.X - 34))
                local panelH = math.min(280,math.max(215,viewport.Y - 100))
                local overlay = Instance.new("Frame")
                overlay.Name = "ChangelogDetailOverlay"
                overlay.Size = UDim2.new(1,0,1,0)
                overlay.BackgroundColor3 = Color3.fromRGB(3,5,9)
                overlay.BackgroundTransparency = 0.28
                overlay.BorderSizePixel = 0
                overlay.ZIndex = 80
                overlay.Parent = root
                local panel = Instance.new("Frame")
                panel.Name = "ChangelogDetailPanel"
                panel.Size = UDim2.new(0,panelW,0,panelH)
                panel.Position = UDim2.new(0.5,0,0.5,0)
                panel.AnchorPoint = Vector2.new(0.5,0.5)
                panel.BackgroundColor3 = C.panel
                panel.BorderSizePixel = 0
                panel.ClipsDescendants = true
                panel.ZIndex = 81
                panel.Parent = overlay
                corner(10,panel)
                stroke(C.border,1,panel)
                local rail = Instance.new("Frame")
                rail.Size = UDim2.new(0,3,1,-22)
                rail.Position = UDim2.new(0,0,0,11)
                rail.BackgroundColor3 = ACCENTS[1]
                rail.BorderSizePixel = 0
                rail.ZIndex = 82
                rail.Parent = panel
                corner(2,rail)
                newTxt({Parent=panel,Text="JUSTLIB  /  RELEASE ARCHIVE",Font=GB,Size=8,Color=C.dim,Sz=UDim2.new(1,-66,0,12),Pos=UDim2.new(0,15,0,12),Z=82})
                local close = Instance.new("TextButton")
                close.Name = "CloseChangelog"
                close.Size = UDim2.new(0,24,0,24)
                close.Position = UDim2.new(1,-34,0,7)
                close.BackgroundColor3 = C.pHdr
                close.BorderSizePixel = 0
                close.AutoButtonColor = false
                close.Text = "×"
                close.Font = GB
                close.TextSize = 17
                close.TextColor3 = C.txt
                close.ZIndex = 83
                close.Parent = panel
                corner(6,close)
                close.MouseButton1Click:Connect(function() overlay:Destroy() end)
                local titleText = heading and heading ~= "" and heading or "Update"
                local title = newTxt({Parent=panel,Text=titleText,Font=GB,Size=15,Sz=UDim2.new(1,-30,0,22),Pos=UDim2.new(0,15,0,35),Z=82})
                title.TextTruncate = Enum.TextTruncate.AtEnd
                if version and version ~= "" then
                    newTxt({Parent=panel,Text="VERSION  " .. version,Font=GB,Size=8,Color=ACCENTS[1],Sz=UDim2.new(1,-30,0,12),Pos=UDim2.new(0,15,0,59),Z=82})
                end
                local bodyY = version and 78 or 72
                local detailScroll = Instance.new("ScrollingFrame")
                detailScroll.Name = "ChangelogFullText"
                detailScroll.Size = UDim2.new(1,-30,1,-(bodyY + 54))
                detailScroll.Position = UDim2.new(0,15,0,bodyY)
                detailScroll.BackgroundTransparency = 1
                detailScroll.BorderSizePixel = 0
                detailScroll.ScrollBarThickness = 2
                detailScroll.ScrollBarImageColor3 = ACCENTS[1]
                detailScroll.ScrollingDirection = Enum.ScrollingDirection.Y
                detailScroll.Active = true
                detailScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
                detailScroll.CanvasSize = UDim2.new(0,0,0,0)
                detailScroll.ZIndex = 82
                detailScroll.Parent = panel
                local content = Instance.new("Frame")
                content.Name = "ChangelogContent"
                content.Size = UDim2.new(1,-6,0,0)
                content.BackgroundTransparency = 1
                content.AutomaticSize = Enum.AutomaticSize.Y
                content.Parent = detailScroll
                local layout = Instance.new("UIListLayout")
                layout.Padding = UDim.new(0,7)
                layout.SortOrder = Enum.SortOrder.LayoutOrder
                layout.Parent = content
                local desc = newTxt({Parent=content,Text=description ~= "" and description or "No description provided.",Font=GM,Size=10,Color=C.txt,Wrap=true,Sz=UDim2.new(1,-4,0,0),Pos=UDim2.new(0,2,0,0),Z=83})
                desc.AutomaticSize = Enum.AutomaticSize.Y
                desc.TextYAlignment = Enum.TextYAlignment.Top
                if #changes > 0 then
                    local label = newTxt({Parent=content,Text="IN THIS RELEASE",Font=GB,Size=8,Color=ACCENTS[1],Sz=UDim2.new(1,-4,0,12),Z=83})
                    label.LayoutOrder = 2
                    for i,change in ipairs(changes) do
                        local line = newTxt({Parent=content,Text="—  " .. tostring(change),Font=GM,Size=9,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-8,0,0),Pos=UDim2.new(0,4,0,0),Z=83})
                        line.AutomaticSize = Enum.AutomaticSize.Y
                        line.TextYAlignment = Enum.TextYAlignment.Top
                        line.LayoutOrder = i + 2
                    end
                end
                local navY = panelH - 39
                local function navButton(name,label,x,enabled,callback)
                    local button = Instance.new("TextButton")
                    button.Name = name
                    button.Size = UDim2.new(0,34,0,26)
                    button.Position = UDim2.new(0,x,0,navY)
                    button.BackgroundColor3 = C.pHdr
                    button.BackgroundTransparency = enabled and 0 or 0.55
                    button.BorderSizePixel = 0
                    button.AutoButtonColor = false
                    button.Text = label
                    button.Font = GB
                    button.TextSize = 15
                    button.TextColor3 = enabled and C.txt or C.dim
                    button.TextTransparency = enabled and 0 or 0.45
                    button.ZIndex = 83
                    button.Parent = panel
                    corner(6,button)
                    if enabled then button.Activated:Connect(callback) end
                    return button
                end
                local hasNewer = entryIndex > 1
                local hasOlder = entryIndex < #entries
                navButton("NewerVersion","‹",15,hasNewer,function()
                    local nextIndex = entryIndex - 1
                    while nextIndex >= 1 do
                        local h,d = entryText(entries[nextIndex])
                        if (h and h ~= "") or d ~= "" then
                            showChangelogDetails(entries[nextIndex],nextIndex)
                            return
                        end
                        nextIndex = nextIndex - 1
                    end
                end)
                newTxt({Parent=panel,Text=tostring(entryIndex) .. " / " .. tostring(navigableCount),Font=GB,Size=8,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-112,0,26),Pos=UDim2.new(0,56,0,navY),Z=83})
                navButton("OlderVersion","›",panelW - 49,hasOlder,function()
                    local nextIndex = entryIndex + 1
                    while nextIndex <= #entries do
                        local h,d = entryText(entries[nextIndex])
                        if (h and h ~= "") or d ~= "" then
                            showChangelogDetails(entries[nextIndex],nextIndex)
                            return
                        end
                        nextIndex = nextIndex + 1
                    end
                end)
            end
            local latestEntry,latestVersion
            for _,entry in ipairs(entries) do
                local _,_,version = entryText(entry)
                if version and version ~= "" then latestEntry = entry; latestVersion = version; break end
            end
            local function readSeenVersion()
                local path = "JustLib_UpdateState.json"
                if isfile and readfile then
                    local okExists,exists = pcall(isfile,path)
                    if okExists and exists then
                        local okRead,raw = pcall(readfile,path)
                        if okRead and raw and raw ~= "" then
                            local okDecode,data = pcall(HTTP.JSONDecode,HTTP,raw)
                            if okDecode and type(data) == "table" and data.Version then return tostring(data.Version) end
                        end
                    end
                end
                local configured = tostring(cfgGet("_jl_changelog_seen_version","") or "")
                if configured ~= "" then return configured end
                return tostring(shared._JLChangelogSeenVersion or "")
            end
            local function saveSeenVersion(version)
                local saved = false
                local path = "JustLib_UpdateState.json"
                if writefile and readfile and isfile then
                    local ok = pcall(function() writefile(path,HTTP:JSONEncode({Version=version})) end)
                    saved = ok
                end
                shared._JLChangelogSeenVersion = version
                if not saved then cfgSet("_jl_changelog_seen_version",version) end
            end
            local function showLatestUpdate()
                if not latestEntry or not latestVersion then return end
                local _,description,version,changes = entryText(latestEntry)
                local updateGui = registerHubGui(Instance.new("ScreenGui"), "Update")
                updateGui.ResetOnSpawn = false
                updateGui.IgnoreGuiInset = true
                updateGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                updateGui.DisplayOrder = (sg.DisplayOrder or 999) + 1
                local guiParent = sg.Parent
                if not guiParent then
                    local okCore,core = pcall(function() return game:GetService("CoreGui") end)
                    guiParent = okCore and core or PG
                end
                updateGui.Parent = guiParent
                JL:Track(updateGui)
                local camera = workspace.CurrentCamera
                local viewport = camera and camera.ViewportSize or Vector2.new(800,600)
                local panelW = math.min(310,math.max(250,viewport.X - 30))
                local panelH = math.min(238,math.max(210,viewport.Y - 70))
                local overlay = Instance.new("Frame")
                overlay.Name = "Backdrop"
                overlay.Size = UDim2.new(1,0,1,0)
                overlay.BackgroundColor3 = Color3.fromRGB(2,4,8)
                overlay.BackgroundTransparency = 0.34
                overlay.BorderSizePixel = 0
                overlay.ZIndex = 1
                overlay.Parent = updateGui
                local panel = Instance.new("Frame")
                panel.Name = "ReleasePanel"
                panel.Size = UDim2.new(0,panelW,0,panelH)
                panel.Position = UDim2.new(0.5,0,0.5,0)
                panel.AnchorPoint = Vector2.new(0.5,0.5)
                panel.BackgroundColor3 = C.panel
                panel.BorderSizePixel = 0
                panel.ClipsDescendants = true
                panel.ZIndex = 2
                panel.Parent = overlay
                corner(11,panel)
                stroke(C.border,1,panel)
                local rail = Instance.new("Frame")
                rail.Size = UDim2.new(0,3,1,-22)
                rail.Position = UDim2.new(0,0,0,11)
                rail.BackgroundColor3 = ACCENTS[1]
                rail.BorderSizePixel = 0
                rail.ZIndex = 3
                rail.Parent = panel
                corner(2,rail)
                newTxt({Parent=panel,Text="JUSTLIB  /  UPDATE",Font=GB,Size=8,Color=C.dim,Sz=UDim2.new(1,-66,0,12),Pos=UDim2.new(0,14,0,11),Z=3})
                local release = newTxt({Parent=panel,Text="NEW VERSION",Font=GB,Size=7,Color=ACCENTS[1],XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,82,0,18),Pos=UDim2.new(1,-112,0,8),Z=3})
                release.BackgroundColor3 = C.pHdr
                release.BackgroundTransparency = 0
                corner(5,release)
                local title = newTxt({Parent=panel,Text=(select(1,entryText(latestEntry)) or "A new update"),Font=GB,Size=15,Sz=UDim2.new(1,-28,0,22),Pos=UDim2.new(0,14,0,35),Z=3})
                title.TextTruncate = Enum.TextTruncate.AtEnd
                newTxt({Parent=panel,Text="VERSION  " .. version,Font=GB,Size=8,Color=ACCENTS[1],Sz=UDim2.new(1,-28,0,12),Pos=UDim2.new(0,14,0,59),Z=3})
                local descText = description ~= "" and description or "A new version of JustLib is ready."
                local desc = newTxt({Parent=panel,Text=descText,Font=GM,Size=9,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-28,0,27),Pos=UDim2.new(0,14,0,78),Z=3})
                desc.TextYAlignment = Enum.TextYAlignment.Top
                local listY = 112
                if #changes > 0 then
                    newTxt({Parent=panel,Text="WHAT'S CHANGED",Font=GB,Size=8,Color=C.txt,Sz=UDim2.new(1,-28,0,12),Pos=UDim2.new(0,14,0,listY),Z=3})
                    listY = listY + 16
                    local list = Instance.new("ScrollingFrame")
                    list.Name = "ReleaseHighlights"
                    list.Size = UDim2.new(1,-28,1,-(listY + 48))
                    list.Position = UDim2.new(0,14,0,listY)
                    list.BackgroundColor3 = C.pHdr
                    list.BackgroundTransparency = 0.15
                    list.BorderSizePixel = 0
                    list.ScrollBarThickness = 2
                    list.ScrollBarImageColor3 = ACCENTS[1]
                    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
                    list.CanvasSize = UDim2.new(0,0,0,0)
                    list.ScrollingDirection = Enum.ScrollingDirection.Y
                    list.Active = true
                    list.ZIndex = 3
                    list.Parent = panel
                    corner(6,list)
                    local padding = Instance.new("UIPadding")
                    padding.PaddingTop = UDim.new(0,7)
                    padding.PaddingBottom = UDim.new(0,7)
                    padding.PaddingLeft = UDim.new(0,8)
                    padding.PaddingRight = UDim.new(0,7)
                    padding.Parent = list
                    local ll = Instance.new("UIListLayout")
                    ll.Padding = UDim.new(0,5)
                    ll.SortOrder = Enum.SortOrder.LayoutOrder
                    ll.Parent = list
                    for i,change in ipairs(changes) do
                        local line = newTxt({Parent=list,Text="›   " .. tostring(change),Font=GM,Size=9,Color=C.txt,Wrap=true,Sz=UDim2.new(1,-8,0,0),Pos=UDim2.new(0,0,0,0),Z=4})
                        line.AutomaticSize = Enum.AutomaticSize.Y
                        line.TextYAlignment = Enum.TextYAlignment.Top
                        line.LayoutOrder = i
                    end
                end
                local divider = Instance.new("Frame")
                divider.Size = UDim2.new(1,-28,0,1)
                divider.Position = UDim2.new(0,14,1,-43)
                divider.BackgroundColor3 = C.border
                divider.BorderSizePixel = 0
                divider.ZIndex = 3
                divider.Parent = panel
                local continue = Instance.new("TextButton")
                continue.Name = "DismissUpdate"
                continue.Size = UDim2.new(1,-28,0,27)
                continue.Position = UDim2.new(0,14,1,-35)
                continue.BackgroundColor3 = ACCENTS[1]
                continue.BorderSizePixel = 0
                continue.AutoButtonColor = false
                continue.Text = "CONTINUE"
                continue.Font = GB
                continue.TextSize = 9
                continue.TextColor3 = Color3.new(1,1,1)
                continue.ZIndex = 4
                continue.Parent = panel
                corner(6,continue)
                local function closeUpdate()
                    saveSeenVersion(version)
                    updateGui:Destroy()
                end
                continue.MouseButton1Click:Connect(closeUpdate)
                local close = Instance.new("TextButton")
                close.Name = "CloseUpdate"
                close.Size = UDim2.new(0,20,0,20)
                close.Position = UDim2.new(1,-24,0,7)
                close.BackgroundTransparency = 1
                close.BorderSizePixel = 0
                close.AutoButtonColor = false
                close.Text = "×"
                close.Font = GB
                close.TextSize = 17
                close.TextColor3 = C.dim
                close.ZIndex = 5
                close.Parent = panel
                close.MouseButton1Click:Connect(closeUpdate)
            end
            for index,entry in ipairs(entries) do
                local heading,description,version = entryText(entry)
                if (heading and heading ~= "") or description ~= "" then
                    entryCount = entryCount + 1
                    local titleText = heading and heading ~= "" and heading or "UPDATE"
                    local item = Instance.new("Frame")
                    item.Name = "ChangelogEntry"
                    item.Size = UDim2.new(1,-4,0,34)
                    item.BackgroundColor3 = C.pHdr
                    item.BorderSizePixel = 0
                    item.LayoutOrder = index
                    item.Parent = changelogScroll
                    corner(6,item)
                    local marker = Instance.new("Frame")
                    marker.Size = UDim2.new(0,2,1,-10)
                    marker.Position = UDim2.new(0,0,0,5)
                    marker.BackgroundColor3 = ACCENTS[1]
                    marker.BorderSizePixel = 0
                    marker.Parent = item
                    corner(1,marker)
                    newTxt({Parent=item,Text=version and ("V" .. version) or titleText,Font=GB,Size=9,Color=ACCENTS[1],Sz=UDim2.new(1,-28,0,12),Pos=UDim2.new(0,8,0,4)})
                    local preview = description
                    if #preview > 78 then preview = preview:sub(1,75) .. "..." end
                    local descHeight = description ~= "" and fitH(preview,9,GM,146,11,2) or 11
                    local desc = newTxt({Parent=item,Text=preview ~= "" and preview or titleText,Font=GM,Size=9,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-28,0,descHeight),Pos=UDim2.new(0,8,0,17)})
                    desc.TextYAlignment = Enum.TextYAlignment.Top
                    local openHint = newTxt({Parent=item,Text="›",Font=GB,Size=18,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,16,1,0),Pos=UDim2.new(1,-20,0,0)})
                    openHint.ZIndex = 2
                    local click = Instance.new("TextButton")
                    click.Name = "OpenChangelogEntry"
                    click.Size = UDim2.new(1,0,1,0)
                    click.BackgroundTransparency = 1
                    click.BorderSizePixel = 0
                    click.AutoButtonColor = false
                    click.Text = ""
                    click.ZIndex = 5
                    click.Parent = item
                    click.MouseButton1Click:Connect(function() showChangelogDetails(entry,index) end)
                    item.Size = UDim2.new(1,-4,0,math.max(34,17 + math.min(descHeight,22) + 5))
                end
            end
            if entryCount == 0 then
                newTxt({Parent=changelogScroll,Text="No updates yet.",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-8,0,18),Pos=UDim2.new(0,4,0,4)})
            end
            refreshChangelogCanvas()
            if latestEntry and latestVersion and readSeenVersion() ~= latestVersion then
                showLatestUpdate()
            end
            if hopts.Tier or #SUB.order > 0 then
                local chip = Instance.new("TextButton")
                chip.AutoButtonColor = false
                chip.Text = ""
                chip.BackgroundColor3 = C.badgeHi
                chip.BorderSizePixel = 0
                chip.Parent = changelogFrame
                corner(7,chip)
                local chipStroke = stroke(ACCENTS[1],1,chip)
                local chipTxt = newTxt({Parent=chip,Text="",Font=GB,Size=10,Color=ACCENTS[1],XAlign=Enum.TextXAlignment.Center})
                local timeTxt = newTxt({Parent=changelogFrame,Text="",Font=GM,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,86,0,10),Pos=UDim2.new(1,-94,0,25)})
                changelogScroll.Position = UDim2.new(0,6,0,48)
                changelogScroll.Size = UDim2.new(1,-12,1,-54)
                local function refreshChip()
                    local info = JL:GetSubscriptionInfo()
                    local label = info.Subscribed and info.Name or (hopts.Tier or info.Name)
                    local custom = info.Tier and info.Tier.Color
                    local col = custom or ACCENTS[1]
                    local w = math.max(58, math.min(86, math.floor(TextService:GetTextSize(label, 10, GB, Vector2.new(120,20)).X) + 18))
                    chip.Size = UDim2.new(0,w,0,18)
                    chip.Position = UDim2.new(0,8,0,25)
                    chipTxt.Text = label
                    chipTxt.TextColor3 = col
                    chipStroke.Color = col
                    chipTxt:SetAttribute("JLNoRepaint", custom ~= nil)
                    chipStroke:SetAttribute("JLNoRepaint", custom ~= nil)
                    timeTxt.Text = info.TimeText or ""
                end
                refreshChip()
                JL:OnTierChanged(refreshChip)
                chip.MouseButton1Click:Connect(function()
                    if #SUB.order > 0 then JL:OpenSubscriptions() end
                end)
            end
        end
        do
            local h = 60
            local card = newCard(h)
            local row = Instance.new("Frame"); row.Size = UDim2.new(1,-16,1,-16); row.Position = UDim2.new(0,8,0,8); row.BackgroundTransparency = 1; row.Parent = card
            local rl = Instance.new("UIListLayout"); rl.FillDirection = Enum.FillDirection.Horizontal; rl.Padding = UDim.new(0,6); rl.SortOrder = Enum.SortOrder.LayoutOrder; rl.Parent = row
            local statW = 96
            local function stat(order,label,initial)
                local box = Instance.new("Frame"); box.Size = UDim2.new(0,statW,1,0); box.BackgroundTransparency = 1; box.LayoutOrder = order; box.Parent = row
                newTxt({Parent=box,Text=label,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,0,0,14),Pos=UDim2.new(0,0,0,2)})
                local v = newTxt({Parent=box,Text=initial,Font=GB,Size=16,Sz=UDim2.new(1,0,0,22),Pos=UDim2.new(0,0,0,18)})
                return v
            end
            local playersV = stat(1, "Players", "0/0")
            local fpsV = stat(2, "FPS", "60")
            homeFpsLabel = fpsV
            local pingV = stat(3, "Ping", "0ms")
            local sessV = stat(4, "Session", "0m 0s")
            local execV, friendsV
            if hopts.GetExecs then execV = stat(5, "Execs", "0") end
            if hopts.ShowFriends then friendsV = stat(hopts.GetExecs and 6 or 5, "Friends", "...") end
            local function refreshPlayers()
                local max = game.Players.MaxPlayers
                playersV.Text = #game.Players:GetPlayers() .. "/" .. max
            end
            refreshPlayers()
            keep(game.Players.PlayerAdded:Connect(refreshPlayers)); keep(game.Players.PlayerRemoving:Connect(refreshPlayers))
            trackedSpawn(function()
                while root.Parent do
                    local ok,ping = pcall(function() return LP:GetNetworkPing() end)
                    if ok then pingV.Text = math.round(ping * 1000) .. "ms" end
                    local secs = math.floor(tick() - hubStartTick)
                    sessV.Text = math.floor(secs / 60) .. "m " .. (secs % 60) .. "s"
                    if execV and hopts.GetExecs then local ok2,n = pcall(hopts.GetExecs); if ok2 and n then execV.Text = tostring(n) end end
                    task.wait(1)
                end
            end)
            if friendsV then
                trackedSpawn(function()
                    local ok,list2 = pcall(function()
                        local pages = LP:GetFriendsOnline(50)
                        return pages:GetCurrentPage()
                    end)
                    friendsV.Text = (ok and list2) and tostring(#list2) or "0"
                end)
            end
        end
        do
            local h = 164
            local card = newCard(h)
            local icon = Instance.new("ImageLabel"); icon.Size = UDim2.new(0,56,0,56); icon.Position = UDim2.new(0,12,0,12); icon.BackgroundColor3 = C.pHdr; icon.BorderSizePixel = 0; icon.Parent = card; corner(10,icon)
            icon:SetAttribute("JLNoRepaint", true)
            local nameL = newTxt({Parent=card,Text="Loading...",Font=GB,Size=14,Sz=UDim2.new(1,-84,0,18),Pos=UDim2.new(0,78,0,12)})
            local byL = newTxt({Parent=card,Text="",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-84,0,14),Pos=UDim2.new(0,78,0,32)})
            trackedSpawn(function()
                local ok,info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId, Enum.InfoType.Asset) end)
                if ok and info then
                    nameL.Text = info.Name or "Unknown"
                    byL.Text = "by " .. ((info.Creator and info.Creator.Name) or "Unknown")
                    if info.IconImageAssetId and info.IconImageAssetId ~= 0 then icon.Image = "rbxassetid://" .. info.IconImageAssetId end
                end
            end)
            newTxt({Parent=card,Text="Job ID  " .. game.JobId,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-84,0,14),Pos=UDim2.new(0,78,0,50)})
            newTxt({Parent=card,Text="Place " .. game.PlaceId .. "   Universe " .. game.GameId,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-24,0,14),Pos=UDim2.new(0,12,0,74)})
            local function mkBtnRow(y)
                local row = Instance.new("Frame"); row.Size = UDim2.new(1,-24,0,26); row.Position = UDim2.new(0,12,0,y); row.BackgroundTransparency = 1; row.Parent = card
                local rl = Instance.new("UIListLayout"); rl.FillDirection = Enum.FillDirection.Horizontal; rl.Padding = UDim.new(0,6); rl.SortOrder = Enum.SortOrder.LayoutOrder; rl.Parent = row
                return row
            end
            local btnRow1, btnRow2 = mkBtnRow(98), mkBtnRow(130)
            local function actBtn(parentRow,order2,label,w,cb)
                local b = Instance.new("TextButton"); b.Size = UDim2.new(0,w,0,26); b.LayoutOrder = order2; b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.AutoButtonColor = false
                b.Text = label; b.Font = GB; b.TextSize = 11; b.TextColor3 = C.txt; b.Parent = parentRow; corner(6,b); stroke(C.border,1,b)
                b.MouseEnter:Connect(function() if touchLast() then return end tw(b,{BackgroundColor3 = C.btnHov},.1) end)
                b.MouseLeave:Connect(function() tw(b,{BackgroundColor3 = C.btnBg},.1) end)
                b.MouseButton1Click:Connect(cb)
                return b
            end
            actBtn(btnRow1,1,"Rejoin",70,function() pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end) end)
            actBtn(btnRow1,2,"Server Hop",90,function() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LP) end) end)
            actBtn(btnRow1,3,"Copy Job ID",96,function()
                if setclipboard then setclipboard(game.JobId); JL:Notify({Title="Copied",Desc="Job ID copied",Type="Success",Duration=3})
                else JL:Notify({Title="Copy",Desc="Clipboard unsupported",Type="Error",Duration=3}) end
            end)
            actBtn(btnRow1,4,"Copy Universe",108,function()
                if setclipboard then setclipboard(tostring(game.GameId)); JL:Notify({Title="Copied",Desc="Universe ID copied",Type="Success",Duration=3})
                else JL:Notify({Title="Copy",Desc="Clipboard unsupported",Type="Error",Duration=3}) end
            end)
            actBtn(btnRow2,1,"Join Lowest Server",132,function()
                joinLowestServer(game.PlaceId, function(msg) JL:Notify({Title="Server Hop",Desc=msg,Type="Error",Duration=4}) end)
            end)
            actBtn(btnRow2,2,"Sub-Places",100,function()
                openSubPlaces(game.GameId)
            end)
        end
        if hopts.DiscordInvite or hopts.Website then
            local h = 60
            local card = newCard(h)
            local half = hopts.DiscordInvite and hopts.Website
            if hopts.DiscordInvite then
                local w = half and 0.5 or 1
                local box = Instance.new("Frame"); box.Size = UDim2.new(w,half and -20 or -16,1,-16); box.Position = UDim2.new(0,8,0,8); box.BackgroundTransparency = 1; box.Parent = card
                mkIcon(box, "message-circle", 20, 5).Position = UDim2.new(0,0,0,2)
                newTxt({Parent=box,Text="Join the community",Font=GB,Size=12,Sz=UDim2.new(1,-30,0,16),Pos=UDim2.new(0,28,0,0)})
                local sub = newTxt({Parent=box,Text=hopts.DiscordInvite,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-30,0,14),Pos=UDim2.new(0,28,0,18)})
                fetchDiscordInfo(hopts.DiscordInvite, function(info)
                    local bits = {}
                    if info.members then bits[#bits+1] = info.members .. " members" end
                    if info.online then bits[#bits+1] = info.online .. " online" end
                    if #bits > 0 then sub.Text = table.concat(bits, " · ") end
                end)
                local cbtn = Instance.new("TextButton"); cbtn.Size = UDim2.new(0,70,0,24); cbtn.Position = UDim2.new(1,-70,0,4); cbtn.BackgroundColor3 = C.btnBg; cbtn.BorderSizePixel = 0; cbtn.Text = "Copy"; cbtn.Font = GB; cbtn.TextSize = 11; cbtn.TextColor3 = C.txt; cbtn.Parent = box; corner(6,cbtn); stroke(C.border,1,cbtn)
                cbtn.MouseButton1Click:Connect(function()
                    if setclipboard then setclipboard(hopts.DiscordInvite); JL:Notify({Title="Copied",Desc="Invite link copied",Type="Success",Duration=3}) end
                end)
            end
            if hopts.Website then
                local box = Instance.new("Frame"); box.Size = UDim2.new(half and 0.5 or 1,half and -20 or -16,1,-16); box.Position = UDim2.new(half and 0.5 or 0,half and 12 or 8,0,8); box.BackgroundTransparency = 1; box.Parent = card
                mkIcon(box, "globe", 20, 5).Position = UDim2.new(0,0,0,2)
                newTxt({Parent=box,Text="Website",Font=GB,Size=12,Sz=UDim2.new(1,-30,0,16),Pos=UDim2.new(0,28,0,0)})
                newTxt({Parent=box,Text=hopts.Website,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-30,0,14),Pos=UDim2.new(0,28,0,18)})
                local cbtn = Instance.new("TextButton"); cbtn.Size = UDim2.new(0,70,0,24); cbtn.Position = UDim2.new(1,-70,0,4); cbtn.BackgroundColor3 = C.btnBg; cbtn.BorderSizePixel = 0; cbtn.Text = "Copy"; cbtn.Font = GB; cbtn.TextSize = 11; cbtn.TextColor3 = C.txt; cbtn.Parent = box; corner(6,cbtn); stroke(C.border,1,cbtn)
                cbtn.MouseButton1Click:Connect(function()
                    if setclipboard then setclipboard(hopts.Website); JL:Notify({Title="Copied",Desc="Website link copied",Type="Success",Duration=3}) end
                end)
            end
        end
        if hopts.Announcement then
            local h = fitH(hopts.Announcement, 11, GM, IW - 48, 40, 16)
            local card = newCard(h)
            newTxt({Parent=card,Text=hopts.Announcement,Font=GM,Size=11,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-24,1,-16),Pos=UDim2.new(0,12,0,8)})
        end
        return T
    end
    hubEntry = {
        HubId = hubId,
        Config = opts.Config,
        Title = hubTitle,
        alive = true,
        destroy = destroyHub,
        win = win,
        badge = badge2,
        setWorkspaceVisible = setWorkspaceVisible,
        openWindow = openW,
        isOpen = function() return isOpen end,
        GuiName = hubGuiName(hubId, false),
        RemoteGuiName = hubGuiName(hubId, true)
    }
    _workspace.Hubs[hubId] = hubEntry
    _workspace.SetActiveHub(hubId)
    refreshWorkspaceTabs()
    JL._destroyActive = destroyHub
    if JL._perfEnabled then
        warn("[JustLib Perf] Window build: " .. string.format("%.3f s", os.clock() - windowBuildStarted))
    end
    if opts.Settings ~= false then Win:Settings() end
    return Win
end
function JL:Unload()
    if self._destroyActive then self._destroyActive()
    else
        _disposed = true
        cleanupResources()
        for i = #_conns, 1, -1 do pcall(function() _conns[i]:Disconnect() end); _conns[i] = nil end
        local hooks = {}
        for i,fn in ipairs(self._unloadHooks or {}) do hooks[i] = fn end
        for i = #(self._unloadHooks or {}), 1, -1 do self._unloadHooks[i] = nil end
        for _,fn in ipairs(hooks) do pcall(fn) end
    end
end
function JL:Cleanup() return self:Unload() end
return JL
