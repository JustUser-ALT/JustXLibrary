local function isDividerOpt(o) return type(o) == "table" and o.Divider ~= nil end
local function dividerHeight(o) return (type(o.Divider) == "string") and 22 or 12 end
local function mkOptDivider(container,order,o,h)
    local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,h); row.BackgroundTransparency = 1; row.LayoutOrder = order; row.Parent = container
    local line = Instance.new("Frame"); line.Size = UDim2.new(1,0,0,1); line.Position = UDim2.new(0,0,0.5,0); line.BackgroundColor3 = C.divLine; line.BorderSizePixel = 0; line.Parent = row
    if type(o.Divider) == "string" then
        local lw = math.min(#o.Divider * 6 + 14, 140)
        local chip = Instance.new("Frame"); chip.Size = UDim2.new(0,lw,0,14); chip.Position = UDim2.new(0.5,-lw / 2,0.5,-7); chip.BackgroundColor3 = C.pHdr; chip.BorderSizePixel = 0; chip.Parent = row
        newTxt({Parent=chip,Text=o.Divider,Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center})
    end
end
local function attachWidgets(content,INNER,ac,uiScale,parentSg,attachTip,config)
    local cfgGet, cfgSet, cfgHas = config.Get, config.Set, config.Has
    local function unscale(px)
        local s = (uiScale and uiScale.Scale) or 1
        if not s or s <= 0 then s = 1 end
        return px / s
    end
    local iOrd = 0
    local Sec = {}
    local ICONW = 22
    local function iconAtLabel(holder,icon,topH)
        if not icon then return 0 end
        local ic = mkIcon(holder, icon, 15, 5); ic.Position = UDim2.new(0,4,0,math.floor((topH - 15) / 2)); ic.Size = UDim2.new(0,15,0,15)
        if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end
        return ICONW
    end
    local function edgeIcon(holder,icon,left,y)
        if not icon then return 0 end
        local ic = mkIcon(holder, icon, 14, 5); ic.Size = UDim2.new(0,14,0,14)
        ic.Position = left and UDim2.new(0,5,0,y) or UDim2.new(1,-19,0,y)
        if ic:IsA("TextLabel") then ic.TextColor3 = C.dim else ic.ImageColor3 = C.dim end
        return 20
    end
    local function iconSlot(holder,icon)
        if not icon then return 0 end
        local ic = mkIcon(holder, icon, 15, 5); ic.Position = UDim2.new(0,10,0.5,-7); ic.Size = UDim2.new(0,15,0,15)
        if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end
        return ICONW
    end
    local function tip(guiObject,text) if attachTip then attachTip(guiObject, text) end end
    JL._metaButtons = JL._metaButtons or {}
    local function openMetaPanel(title, meta, settingsMode)
        local overlay = Instance.new("Frame")
        overlay.Name = "JLMetaOverlay"; overlay.Size = UDim2.new(1,0,1,0)
        overlay.BackgroundColor3 = C.backdrop; overlay.BackgroundTransparency = 0.28
        overlay.BorderSizePixel = 0; overlay.ZIndex = 90; overlay.Parent = parentSg
        local panel = Instance.new("Frame")
        panel.Name = "JLMetaPanel"; panel.Size = UDim2.new(0.68,0,0.52,0)
        panel.Position = UDim2.new(0.5,0,0.5,0); panel.AnchorPoint = Vector2.new(0.5,0.5)
        panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
        panel.ClipsDescendants = true; panel.ZIndex = 91; panel.Parent = overlay
        corner(12,panel); stroke(C.border,1,panel)
        local limit = Instance.new("UISizeConstraint")
        limit.MinSize = Vector2.new(190,150); limit.MaxSize = Vector2.new(300,340); limit.Parent = panel
        local accentBar = Instance.new("Frame")
        accentBar.Size = UDim2.new(1,0,0,3); accentBar.BackgroundColor3 = ac
        accentBar.BorderSizePixel = 0; accentBar.ZIndex = 94; accentBar.Parent = panel
        local head = Instance.new("Frame")
        head.Size = UDim2.new(1,0,0,42); head.Position = UDim2.new(0,0,0,3)
        head.BackgroundColor3 = C.pHdr; head.BorderSizePixel = 0; head.ZIndex = 92; head.Parent = panel
        local iconTile = Instance.new("Frame")
        iconTile.Size = UDim2.new(0,25,0,25); iconTile.Position = UDim2.new(0,10,0,8)
        iconTile.BackgroundColor3 = C.badgeHi; iconTile.BorderSizePixel = 0; iconTile.ZIndex = 93; iconTile.Parent = head
        corner(10,iconTile)
        newTxt({Parent=iconTile,Text=settingsMode and "⚙" or "ⓘ",Font=GB,Size=13,Color=ac,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,1,0),Z=94})
        newTxt({Parent=head,Text=tostring(title or (settingsMode and "Settings" or "Information")),Font=GB,Size=11,Color=C.txt,Sz=UDim2.new(1,-76,0,16),Pos=UDim2.new(0,43,0,6),Z=94})
        newTxt({Parent=head,Text=settingsMode and "Customize this item" or "Item information and details",Font=GM,Size=8,Color=C.dim,Sz=UDim2.new(1,-76,0,12),Pos=UDim2.new(0,43,0,22),Z=94})
        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0,22,0,22); close.Position = UDim2.new(1,-30,0,8)
        close.BackgroundColor3 = C.btnBg; close.BorderSizePixel = 0; close.AutoButtonColor = false
        close.Text = "×"; close.Font = GB; close.TextSize = 18; close.TextColor3 = C.txt
        close.ZIndex = 95; close.Parent = head; corner(9,close); stroke(C.border,1,close)
        close.MouseEnter:Connect(function() if not touchLast() then tw(close,{BackgroundColor3=C.btnHov},0.1) end end)
        close.MouseLeave:Connect(function() tw(close,{BackgroundColor3=C.btnBg},0.1) end)
        close.MouseButton1Click:Connect(function() overlay:Destroy() end)
        local body = Instance.new("ScrollingFrame")
        body.Size = UDim2.new(1,-14,1,-51); body.Position = UDim2.new(0,7,0,48)
        body.BackgroundTransparency = 1; body.BorderSizePixel = 0
        body.ScrollBarThickness = 3; body.ScrollBarImageColor3 = ac
        body.ScrollingDirection = Enum.ScrollingDirection.Y; body.Active = true
        body.AutomaticCanvasSize = Enum.AutomaticSize.Y; body.CanvasSize = UDim2.new(0,0,0,0)
        body.ZIndex = 92; body.Parent = panel
        if settingsMode then
            local layout = Instance.new("UIListLayout")
            layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0,6); layout.Parent = body
            pad(2,2,3,6,body)
            local innerWidth = math.max(170, math.min(264, panel.AbsoluteSize.X - 28))
            local nested = attachWidgets(body,innerWidth,ac,uiScale,parentSg,attachTip,config)
            local count = 0
            for _,definition in ipairs(type(meta) == "table" and meta or {}) do
                if type(definition) == "table" then
                    count = count + 1
                    local kind = tostring(definition.Type or "Toggle")
                    if kind == "Textbox" or kind == "TextBox" then kind = "Input" end
                    local create = nested[kind]
                    if type(create) == "function" then
                        local config = {}
                        for k,v in pairs(definition) do config[k] = v end
                        config.Flag = config.Flag or ("JLMeta_" .. tostring(title) .. "_" .. tostring(config.Name or kind))
                        create(nested,config)
                    else
                        newTxt({Parent=body,Text="Unsupported setting: " .. kind,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-8,0,20),Z=93})
                    end
                end
            end
            if count == 0 then newTxt({Parent=body,Text="No settings are available for this item.",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-8,0,24),Pos=UDim2.new(0,4,0,4),Z=93}) end
        else
            local info = type(meta) == "table" and meta or {Description=tostring(meta or "")}
            local blocks = {
                {Title=info.Title or "Overview",Text=info.Description or info.Desc or info.Text,Kind="main"},
                {Title=info.DetailsTitle or "Additional details",Text=info.Details,Kind="detail"},
                {Title=info.Warning and (info.WarningTitle or "Important") or nil,Text=info.Warning,Kind="warning"},
            }
            local y, count = 4, 0
            for _,item in ipairs(blocks) do
                if item.Text and tostring(item.Text) ~= "" then
                    count = count + 1
                    local headingText = item.Title and tostring(item.Title) or ""
                    local cardWidth = math.max(140,panel.AbsoluteSize.X - 36)
                    local titleHeight = headingText ~= "" and fitH(headingText,11,GB,cardWidth,16,4) or 0
                    local descHeight = fitH(tostring(item.Text),10,GM,cardWidth,18,9)
                    local card = Instance.new("Frame")
                    card.Size = UDim2.new(1,-6,0,titleHeight + descHeight + (titleHeight > 0 and 5 or 0) + 18)
                    card.Position = UDim2.new(0,2,0,y)
                    card.BackgroundColor3 = item.Kind == "warning" and C.pHdr or C.btnBg
                    card.BorderSizePixel = 0; card.ZIndex = 93; card.Parent = body
                    corner(9,card)
                    local accent = Instance.new("Frame")
                    accent.Size = UDim2.new(0,3,1,-18); accent.Position = UDim2.new(0,0,0,9)
                    accent.BackgroundColor3 = item.Kind == "warning" and C.danger or ac
                    accent.BorderSizePixel = 0; accent.ZIndex = 94; accent.Parent = card; corner(2,accent)
                    local content = Instance.new("Frame")
                    content.Size = UDim2.new(1,-22,1,-12); content.Position = UDim2.new(0,12,0,6)
                    content.BackgroundTransparency = 1; content.ZIndex = 94; content.Parent = card
                    if titleHeight > 0 then
                        newTxt({Parent=content,Text=headingText,Font=GB,Size=11,Color=item.Kind == "warning" and C.danger or ac,Wrap=true,Sz=UDim2.new(1,0,0,titleHeight),Z=95})
                    end
                    local desc = newTxt({Parent=content,Text=tostring(item.Text),Font=GM,Size=10,Color=C.txt,Wrap=true,Sz=UDim2.new(1,0,0,descHeight),Pos=UDim2.new(0,0,0,titleHeight > 0 and titleHeight + 5 or 0),Z=95})
                    desc.TextYAlignment = Enum.TextYAlignment.Top
                    y = y + card.Size.Y.Offset + 6
                end
            end
            if count == 0 then newTxt({Parent=body,Text="No additional information has been provided.",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-8,0,24),Pos=UDim2.new(0,4,0,4),Z=93}) end
            body.CanvasSize = UDim2.new(0,0,0,y + 6)
        end
    end
    local function addMetaButtons(row, definition)
        if type(definition) ~= "table" or not row then return end
        local settings = type(definition.Settings) == "table" and #definition.Settings > 0
        local info = definition.Info ~= nil and definition.Info ~= false and definition.Info ~= ""
        if not settings and not info then return end

        -- Metadata actions use a separate wrapper. The control row and its
        -- internal GUI hierarchy are not resized or repositioned.
        local parent = row.Parent
        if not parent then return end
        local wrapper = Instance.new("Frame")
        wrapper.Name = "JLMetaRow"
        wrapper.Size = UDim2.new(1,0,0,0)
        wrapper.AutomaticSize = Enum.AutomaticSize.Y
        wrapper.BackgroundTransparency = 1
        wrapper.BorderSizePixel = 0
        wrapper.ClipsDescendants = false
        wrapper.LayoutOrder = row.LayoutOrder
        wrapper.Parent = parent

        local originalSize = row.Size
        row.Parent = wrapper
        row.Position = UDim2.new(0,0,0,18)
        row.Size = originalSize

        local capsule = Instance.new("Frame")
        capsule.Name = "JLMetaActions"
        capsule.Size = UDim2.new(0,(settings and info) and 38 or 19,0,16)
        capsule.Position = UDim2.new(1,-4,0,1)
        capsule.AnchorPoint = Vector2.new(1,0)
        capsule.BackgroundColor3 = C.pHdr
        capsule.BorderSizePixel = 0
        capsule.ZIndex = 56
        capsule.Parent = wrapper
        corner(7,capsule)

        local function make(iconName,help,order,action)
            local button = Instance.new("TextButton")
            button.Name = iconName == "settings" and "JLSettingsAction" or "JLInfoAction"
            button.Size = UDim2.new(0,17,0,16)
            button.Position = UDim2.new(0,(order-1)*19,0,0)
            button.BackgroundTransparency = 1
            button.BorderSizePixel = 0
            button.AutoButtonColor = false
            button.Text = ""
            button.ZIndex = 57
            button.Parent = capsule
            local icon = mkIcon(button,iconName,11,58)
            icon.AnchorPoint = Vector2.new(0.5,0.5)
            icon.Position = UDim2.new(0.5,0,0.5,0)
            icon.Size = UDim2.new(0,11,0,11)
            if icon:IsA("TextLabel") then icon.TextColor3 = ac else icon.ImageColor3 = ac end
            button.MouseEnter:Connect(function()
                if touchLast() then return end
                tw(capsule,{BackgroundColor3=C.btnHov},0.1)
            end)
            button.MouseLeave:Connect(function()
                tw(capsule,{BackgroundColor3=C.pHdr},0.1)
            end)
            tip(button,help)
            button.MouseButton1Click:Connect(action)
            JL._metaButtons[#JL._metaButtons + 1] = button
            button.Visible = not JL._remoteEditActive
        end

        local order = 1
        if settings then
            make("settings","Settings",order,function()
                openMetaPanel((definition.Name or "Control") .. " · Settings",definition.Settings,true)
            end)
            order = order + 1
        end
        if info then
            make("info","More information",order,function()
                openMetaPanel((definition.Name or "Control") .. " · Info",definition.Info,false)
            end)
        end
    end
    local function newRow(h2)
        iOrd = iOrd + 1
        local r = Instance.new("Frame"); r.Size = UDim2.new(1,0,0,h2); r.BackgroundTransparency = 1; r.BorderSizePixel = 0; r.LayoutOrder = iOrd; r.Parent = content
        JL._newRows[#JL._newRows + 1] = r
        return r
    end
    local function hover(b,base,hov)
        b.MouseEnter:Connect(function()
            if touchLast() then return end
            b:SetAttribute("JLHover", true); tw(b,{BackgroundColor3 = C.btnHov},.1)
        end)
        b.MouseLeave:Connect(function()
            b:SetAttribute("JLHover", false); tw(b,{BackgroundColor3 = C.btnBg},.1)
        end)
    end
    local function regFlag(flag,ctrl,noSave)
        if not flag then return end
        JL._registry[flag] = ctrl
        if noSave then JL._noSave[flag] = true else JL._noSave[flag] = nil end
    end
    local function mergeLock(ret,row,o)
        local lh = attachLockHidden(row, o)
        ret.SetLocked = lh.SetLocked; ret.SetHidden = lh.SetHidden; ret.IsLocked = lh.IsLocked; ret.IsHidden = lh.IsHidden
        ret.ToggleLocked = lh.ToggleLocked; ret.ToggleHidden = lh.ToggleHidden
        ret.Row = row
        return ret
    end
    function Sec:Toggle(o)
        o = o or {}
        local had = cfgHas(o.Flag); local state = cfgGet(o.Flag, o.Default or false)
        local name = o.Name or "Toggle"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 48 - iconW
        local row = newRow(fitH(name, 12, GB, labW, 32, 14))
        local bg = Instance.new("TextButton"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.btnBg; bg.Text = ""; bg.AutoButtonColor = false; bg.BorderSizePixel = 0; bg.Parent = row
        corner(7,bg); stroke(C.border,1,bg); hover(bg, C.btnBg, C.btnHov); tip(bg, o.Tooltip)
        iconSlot(bg, o.Icon)
        local titleLabel = newTxt({Parent=bg,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local sw = mkSwitch(bg, UDim2.new(1,-44,0.5,-9), state, ac)
        local ret
        local watchers = {}
        local function notifyW(v) for _,w in ipairs(watchers) do pcall(w, v) end end
        local function commitState(v)
            state = v; sw.Set(v); cfgSet(o.Flag, v)
            if o.Callback then pcall(o.Callback, v) end
            notifyW(v)
        end
        local function click()
            local nxt = not state
            local when = o.NeedsWhen or "On"
            if o.Needs and (when == "Both" or (when == "On") == nxt) and GUIDE.block(o, row, function() commitState(nxt) end) then return end
            commitState(nxt)
        end
        bg.MouseButton1Click:Connect(click)
        if o.Callback and had then pcall(o.Callback, state) end
        ret = {
            Set = function(_,v) state = v; sw.Set(v); cfgSet(o.Flag, v); notifyW(v) end, Get = function() return state end,
            Click = function() click() end, Watch = function(_,fn) watchers[#watchers + 1] = fn end,
        }
        -- Keep the Remote edit layout inside this Toggle's scope so it can resize
        -- the real label and switch instances instead of relying on out-of-scope locals.
        ret._remoteEditLayout = function(editing)
            local reserve = editing and 32 or 0
            bg.Size = UDim2.new(1,-reserve,bg.Size.Y.Scale,bg.Size.Y.Offset)
            bg.ClipsDescendants = true
            titleLabel.Size = UDim2.new(0,math.max(0,labW - reserve - (editing and 8 or 0)),1,0)
            titleLabel.ClipsDescendants = true
            sw.Frame.Position = UDim2.new(1,editing and -76 or -44,0.5,-9)
        end
        regFlag(o.Flag, ret, o.NoSave)
        local out = mergeLock(ret, row, o)
        if o.Remote then JL._remoteAttach("Toggle", o, out) end
        return out
    end
    function Sec:ToggleGroup(o)
        o = o or {}
        local mode = (o.Mode == "Move") and "Move" or "Lock"
        local clearOthers = o.ClearOthers ~= false
        local maxActive = tonumber(o.MaxActive)
        local order, defs, items, state, mset, fifo = {}, {}, {}, {}, {}, {}
        for _,it in ipairs(o.Options or {}) do
            local d = type(it) == "table" and it or {Name = tostring(it)}
            local n = d.Name or "Item"
            order[#order + 1] = n; defs[n] = d
        end
        if #order == 0 then return nil end
        local masterList = {}
        local ml = o.Masters
        if type(ml) == "string" then ml = {ml} end
        for _,m in ipairs(ml or {order[1]}) do if defs[m] and not mset[m] then mset[m] = true; masterList[#masterList + 1] = m end end
        local defaults = {}
        if type(o.Default) == "string" then defaults[o.Default] = true
        elseif type(o.Default) == "table" then for _,n in ipairs(o.Default) do defaults[n] = true end end
        local msg = o.LockedMessage or ("Turn off " .. table.concat(masterList, " / ") .. " first")
        local building = true
        local function anyMaster() for _,m in ipairs(masterList) do if state[m] then return true end end return false end
        local function activeList() local t = {}; for _,n in ipairs(order) do if state[n] then t[#t + 1] = n end end; return t end
        local function refreshLocks()
            local lock = mode == "Lock" and anyMaster()
            for _,n in ipairs(order) do if not mset[n] then items[n]:SetLocked(lock) end end
        end
        local function fire(n,v,quiet)
            if quiet then return end
            local d = defs[n]
            if d.Callback then pcall(d.Callback, v) end
            if o.Callback then pcall(o.Callback, n, v, activeList()) end
        end
        local function dropFifo(n)
            for i = #fifo,1,-1 do if fifo[i] == n then table.remove(fifo,i) end end
        end
        local function setQuiet(n,v)
            state[n] = v; items[n]:Set(v)
            dropFifo(n)
            if v and not mset[n] then fifo[#fifo + 1] = n end
        end
        local function onChange(n,v,quiet)
            state[n] = v
            dropFifo(n)
            if v and not mset[n] then fifo[#fifo + 1] = n end
            if v then
                if mset[n] then
                    if clearOthers then
                        for _,x in ipairs(order) do
                            if not mset[x] and state[x] then setQuiet(x,false); fire(x,false,quiet) end
                        end
                    end
                else
                    if mode == "Move" then
                        for _,m in ipairs(masterList) do
                            if state[m] then setQuiet(m,false); fire(m,false,quiet) end
                        end
                    end
                    if maxActive and maxActive >= 1 then
                        while #fifo > maxActive do
                            local old = table.remove(fifo,1)
                            if old == n then break end
                            setQuiet(old,false); fire(old,false,quiet)
                        end
                    end
                end
            end
            refreshLocks()
            fire(n,v,quiet)
        end
        if o.Name then self:Divider({Label = o.Name}) end
        local hadSaved = false
        for _,n in ipairs(order) do
            local d = defs[n]
            local flag = d.Flag or (o.Flag and (o.Flag .. "_" .. n) or nil)
            if cfgHas(flag) then hadSaved = true end
            items[n] = self:Toggle({
                Name = n, Flag = flag, Default = d.Default or defaults[n] or false, Icon = d.Icon, Tooltip = d.Tooltip, NoSave = o.NoSave,
                Background = d.Background or o.Background, LockedTitle = o.LockedTitle or "Locked", LockedMessage = msg, LockIcon = o.LockIcon,
                Callback = function(v) if building then state[n] = v else onChange(n,v) end end,
            })
            state[n] = items[n]:Get()
        end
        building = false
        if anyMaster() and clearOthers then
            for _,x in ipairs(order) do if not mset[x] and state[x] then setQuiet(x,false) end end
        end
        for _,n in ipairs(order) do if state[n] and not mset[n] then fifo[#fifo + 1] = n end end
        if maxActive and maxActive >= 1 then
            while #fifo > maxActive do setQuiet(table.remove(fifo,1),false) end
        end
        refreshLocks()
        if hadSaved then for _,n in ipairs(order) do fire(n,state[n]) end end
        local ret = {Items = items}
        function ret.Get() local t = {}; for k,v in pairs(state) do t[k] = v end; return t end
        function ret.GetActive() return activeList() end
        function ret.GetMode() return mode end
        function ret.SetMode(_,m) mode = (m == "Move") and "Move" or "Lock"; refreshLocks() end
        function ret.Set(_,n,v,fireCallbacks)
            if items[n] == nil then return false end
            v = v and true or false
            if state[n] == v then return true end
            if mode == "Lock" and v and not mset[n] and anyMaster() then return false end
            items[n]:Set(v)
            onChange(n,v,fireCallbacks ~= true)
            return true
        end
        return ret
    end
    function Sec:Slider(o)
        o = o or {}
        local vmin = o.Min or 0; local vmax = o.Max or 100; local step = o.Step or o.Increment or 1
        local dec = decimalsOf(step); local suffix = o.Suffix or ""
        local had = cfgHas(o.Flag)
        local val = snap(tonumber(cfgGet(o.Flag, o.Default or vmin)) or vmin, vmin, vmax, step)
        local name = o.Name or "Slider"; local iconW = o.Icon and ICONW or 0
        local topH = fitH(name, 12, GB, INNER - 4 - 66 - iconW, 18, 2)
        local row = newRow(topH + 24)
        tip(row, o.Tooltip)
        iconAtLabel(row, o.Icon, topH)
        local eL = edgeIcon(row, o.IconLeft, true, topH + 5)
        local eR = edgeIcon(row, o.IconRight, false, topH + 5)
        newTxt({Parent=row,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(1,-66 - iconW,0,topH),Pos=UDim2.new(0,4 + iconW,0,0)})
        local box = Instance.new("TextBox"); box.Size = UDim2.new(0,58,0,18); box.Position = UDim2.new(1,-58,0,math.floor((topH - 18) / 2))
        box.BackgroundColor3 = C.pHdr; box.BorderSizePixel = 0; box.Font = GB; box.TextSize = 11; box.TextColor3 = C.dim; box.ClearTextOnFocus = false
        box.Text = fmtNum(val, dec) .. suffix; box.Parent = row; corner(5,box)
        local bar
        bar = mkSliderBar(row, UDim2.new(0,6 + eL,0,topH + 9), UDim2.new(1,-12 - eL - eR,0,6), ac, vmin, vmax, step, val, function(v)
            val = v; box.Text = fmtNum(v, dec) .. suffix; cfgSet(o.Flag, v)
            if o.Callback then pcall(o.Callback, v) end
        end)
        box.Focused:Connect(function() box.Text = fmtNum(val, dec); box.TextColor3 = C.txt end)
        box.FocusLost:Connect(function()
            box.TextColor3 = C.dim
            local n = tonumber(box.Text); if n then bar.Set(n, false) end
            box.Text = fmtNum(val, dec) .. suffix
        end)
        if o.Callback and had then pcall(o.Callback, val) end
        local ret = {
            Set = function(_,v) bar.Set(v, true); val = bar.Get(); box.Text = fmtNum(val, dec) .. suffix; cfgSet(o.Flag, val) end,
            Get = function() return val end,
        }
        regFlag(o.Flag, ret, o.NoSave)
        return mergeLock(ret, row, o)
    end
    function Sec:Button(o)
        o = o or {}
        local iconW = o.Icon and ICONW or 0
        local row = newRow(fitH(o.Name or "Button", 12, GB, INNER - 20 - iconW, 32, 14))
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundColor3 = C.btnBg; btn.BorderSizePixel = 0; btn.AutoButtonColor = false
        btn.Text = ""; btn.Font = GB; btn.TextSize = 12; btn.TextColor3 = C.txt; btn.Parent = row
        corner(7,btn); stroke(C.border,1,btn); hover(btn, C.btnBg, C.btnHov); tip(btn, o.Tooltip)
        iconSlot(btn, o.Icon)
        newTxt({Parent=btn,Text=o.Name or "Button",Font=GB,Size=12,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-10 - iconW,1,0),Pos=UDim2.new(0,iconW,0,0)})
        local presses = 0
        local function press()
            presses = presses + 1
            local fl = (btn:GetAttribute("JLFlash") or 0) + 1; btn:SetAttribute("JLFlash", fl)
            tw(btn,{BackgroundColor3 = ac},.06)
            trackedDelay(.14, function()
                if btn:GetAttribute("JLFlash") ~= fl then return end
                tw(btn,{BackgroundColor3 = btn:GetAttribute("JLHover") and C.btnHov or C.btnBg},.12)
            end)
            if o.Callback then pcall(o.Callback) end
        end
        local function activate()
            if o.Needs and GUIDE.block(o, row, press) then return end
            press()
        end
        btn.MouseButton1Click:Connect(activate)
        local bret = {Instance = btn, Get = function() return presses end, Click = function() activate() end}
        regFlag(o.Flag, bret, true)
        local out = mergeLock(bret, row, o)
        if o.Remote then JL._remoteAttach("Button", o, out) end
        return out
    end
    function Sec:Input(o)
        o = o or {}
        local iconW = o.Icon and ICONW or 0
        local row = newRow(o.MultiLine and 64 or 32)
        local bg = Instance.new("Frame"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.input; bg.BorderSizePixel = 0; bg.Parent = row; corner(7,bg); stroke(C.border,1,bg)
        tip(bg, o.Tooltip); iconSlot(bg, o.Icon)
        local box = Instance.new("TextBox"); box.Size = UDim2.new(1,-16 - iconW,1,0); box.Position = UDim2.new(0,8 + iconW,0,0); box.BackgroundTransparency = 1
        box.PlaceholderText = o.Placeholder or (o.Name or "Input"); box.PlaceholderColor3 = C.dim; box.Text = cfgGet(o.Flag, "") or ""
        box.Font = GB; box.TextSize = 12; box.TextColor3 = C.txt; box.ClearTextOnFocus = false; box.MultiLine = o.MultiLine or false; box.TextWrapped = o.MultiLine or false
        box.TextXAlignment = Enum.TextXAlignment.Left; box.Parent = bg
        box.FocusLost:Connect(function(enter)
            if enter or o.OnChange then cfgSet(o.Flag, box.Text); if o.Callback then pcall(o.Callback, box.Text) end end
        end)
        if o.OnChange then box:GetPropertyChangedSignal("Text"):Connect(function() cfgSet(o.Flag, box.Text); if o.Callback then pcall(o.Callback, box.Text) end end) end
        local ret = {Get = function() return box.Text end, Set = function(_,v) box.Text = v end}
        regFlag(o.Flag, ret, o.NoSave)
        return mergeLock(ret, row, o)
    end
    local function getDropdownOptionIcon(optionName,o)
        local custom = o.OptionIcons and o.OptionIcons[optionName]
        if custom ~= nil then return custom, nil end
        if o.Icons == true then
            local players = game:GetService("Players")
            for _,player in ipairs(players:GetPlayers()) do
                if player.Name == tostring(optionName) or player.DisplayName == tostring(optionName) then
                    return nil, player
                end
            end
        end
        return nil, nil
    end
    local function addDropdownOptionIcon(parent,optionName,o,height)
        local custom,player = getDropdownOptionIcon(optionName,o)
        if player then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0,20,0,20)
            img.Position = UDim2.new(0,7,0,math.floor((height - 20) / 2))
            img.BackgroundColor3 = C.pHdr
            img.BorderSizePixel = 0
            img.ScaleType = Enum.ScaleType.Crop
            img.Parent = parent
            corner(10,img)
            img:SetAttribute("JLNoRepaint", true)
            trackedSpawn(function()
                local ok,content = pcall(function()
                    return game:GetService("Players"):GetUserThumbnailAsync(player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
                end)
                if ok and img.Parent then img.Image = content end
            end)
            return 24
        elseif custom ~= nil then
            local ic = mkIcon(parent,custom,20,5)
            ic.Position = UDim2.new(0,7,0,math.floor((height - 20) / 2))
            ic.Size = UDim2.new(0,20,0,20)
            if ic:IsA("TextLabel") then
                ic.TextColor3 = ac
            elseif tostring(custom):match("^%d+$") or tostring(custom):match("^rbxassetid://") then
                ic.ImageColor3 = Color3.new(1,1,1)
                ic.ScaleType = Enum.ScaleType.Fit
            else
                ic.ImageColor3 = ac
            end
            return 24
        end
        return 0
    end
    function Sec:Dropdown(o)
        o = o or {}
        local rawOptions = o.Options or {}
        local options, optionMeta, optionLabels = {}, {}, {}
        for _,entry in ipairs(rawOptions) do
            if isDividerOpt(entry) then options[#options + 1] = entry
            elseif type(entry) == "table" then
                local value = entry.Value
                if value == nil then value = entry.Name end
                if value ~= nil then options[#options + 1] = value; optionMeta[value] = entry; optionLabels[value] = tostring(entry.Name or value) end
            else options[#options + 1] = entry; optionLabels[entry] = tostring(entry) end
        end
        local multi = o.MultiSelect; local maxSel = o.MaxSelect or (multi and math.max(#options,1) or 1)
        local selected = {}
        local had = cfgHas(o.Flag)
        local saved = cfgGet(o.Flag, o.Default)
        if saved then
            if type(saved) == "table" then for _,v in ipairs(saved) do selected[v] = true end
            elseif saved ~= "" then selected[saved] = true end
        end
        local baseName = o.Name or "Dropdown"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 30 - iconW
        local function labelText()
            if o.Static then return baseName end
            local picked = {}
            for _,opt in ipairs(options) do if not isDividerOpt(opt) and selected[opt] then picked[#picked + 1] = optionLabels[opt] or tostring(opt) end end
            if #picked == 0 then return baseName end
            return baseName .. ": " .. table.concat(picked, ", ")
        end
        local bgH = fitH(labelText(), 12, GB, labW, 32, 14)
        local row = newRow(bgH)
        local bg = Instance.new("TextButton"); bg.Size = UDim2.new(1,0,0,bgH); bg.BackgroundColor3 = C.btnBg; bg.Text = ""; bg.AutoButtonColor = false; bg.BorderSizePixel = 0; bg.Parent = row
        corner(7,bg); stroke(C.border,1,bg); hover(bg, C.btnBg, C.btnHov); tip(bg, o.Tooltip)
        iconSlot(bg, o.Icon)
        local lbl = newTxt({Parent=bg,Text=labelText(),Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local darr = newTxt({Parent=bg,Text="▼",Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,28,1,0),Pos=UDim2.new(1,-28,0,0)})
        local optW = INNER - 8 - 16; local heights = {}; local total = 8
        for i,optName in ipairs(options) do
            local meta = optionMeta[optName]
            local label = optionLabels[optName] or tostring(optName)
            local actionsWidth = meta and ((meta.Info and 22 or 0) + (type(meta.Settings) == "table" and #meta.Settings > 0 and 22 or 0)) or 0
            heights[i] = isDividerOpt(optName) and dividerHeight(optName) or fitH(label, 11, GB, optW - actionsWidth, 30, 12)
            total = total + heights[i] + 2
        end
        if o.Search then total = total + 28 end
        local TOTAL = math.min(total, 180); local dropOpen = false
        local container = Instance.new("ScrollingFrame"); container.Size = UDim2.new(1,0,0,0); container.Position = UDim2.new(0,0,0,bgH + 4); container.BackgroundColor3 = C.pHdr
        container.BorderSizePixel = 0; container.Visible = false; container.ClipsDescendants = true; container.ScrollBarThickness = 3; container.ScrollBarImageColor3 = C.border
        container.CanvasSize = UDim2.new(0,0,0,0); container.Parent = row; corner(7,container); stroke(C.border,1,container)
        local cStack = Instance.new("UIListLayout"); cStack.SortOrder = Enum.SortOrder.LayoutOrder; cStack.Padding = UDim.new(0,2); cStack.Parent = container; pad(4,4,4,4,container)
        cStack:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() container.CanvasSize = UDim2.new(0,0,0,unscale(cStack.AbsoluteContentSize.Y) + 8) end)
        local optRefs = {}
        local sBox
        if o.Search then
            local sHold = Instance.new("Frame"); sHold.Size = UDim2.new(1,0,0,24); sHold.BackgroundTransparency = 1; sHold.LayoutOrder = 0; sHold.Parent = container
            sBox = Instance.new("TextBox"); sBox.Size = UDim2.new(1,0,1,0); sBox.BackgroundColor3 = C.input; sBox.BorderSizePixel = 0
            sBox.PlaceholderText = "Search..."; sBox.PlaceholderColor3 = C.dim; sBox.Font = GB; sBox.TextSize = 11; sBox.TextColor3 = C.txt
            sBox.ClearTextOnFocus = false; sBox.Text = ""; sBox.Parent = sHold; corner(5,sBox); stroke(C.border,1,sBox)
            sBox:GetPropertyChangedSignal("Text"):Connect(function()
                local q = sBox.Text:lower()
                for nm,ref in pairs(optRefs) do
                    ref.opt.Visible = (q == "") or tostring(nm):lower():find(q,1,true) ~= nil
                end
            end)
        end
        local function refreshLabel()
            local t = labelText(); lbl.Text = t
            bgH = fitH(t, 12, GB, labW, 32, 14)
            bg.Size = UDim2.new(1,0,0,bgH); container.Position = UDim2.new(0,0,0,bgH + 4)
            row.Size = UDim2.new(1,0,0,(dropOpen and (bgH + 4 + TOTAL) or bgH))
        end
        local function mark(ref,on) ref.mark.Visible = on; ref.label.TextColor3 = on and ac or C.txt end
        local rules = multi and groupRules(o) or nil
        local function masterOn()
            if not rules then return false end
            for _,m in ipairs(rules.list) do if selected[m] then return true end end
            return false
        end
        local function refreshBlocked()
            if not rules then return end
            local lock = (not rules.move) and masterOn()
            for nm,ref in pairs(optRefs) do ref.label.TextTransparency = (lock and not rules.set[nm]) and 0.6 or 0 end
        end
        local function normalize()
            if rules and rules.clear and masterOn() then
                for nm in pairs(selected) do if not rules.set[nm] then selected[nm] = nil end end
            end
        end
        normalize()
        for i,optName in ipairs(options) do
            if isDividerOpt(optName) then
                mkOptDivider(container, i, optName, heights[i])
            else
            local meta = optionMeta[optName]
            local labelText = optionLabels[optName] or tostring(optName)
            local actionCount = meta and ((meta.Info and 1 or 0) + (type(meta.Settings) == "table" and #meta.Settings > 0 and 1 or 0)) or 0
            local actionWidth = actionCount * 25
            local opt = Instance.new("Frame"); opt.Size = UDim2.new(1,0,0,heights[i]); opt.BackgroundColor3 = C.btnBg
            opt.BorderSizePixel = 0; opt.LayoutOrder = i; opt.Parent = container; corner(6,opt)
            local selectButton = Instance.new("TextButton")
            selectButton.Name = "JLDropdownOptionSelect"; selectButton.Size = UDim2.new(1,-actionWidth,1,0)
            selectButton.BackgroundTransparency = 1; selectButton.BorderSizePixel = 0
            selectButton.AutoButtonColor = false; selectButton.Text = ""; selectButton.Parent = opt
            local optIconW = addDropdownOptionIcon(selectButton,optName,o,heights[i])
            local optLbl = newTxt({Parent=selectButton,Text=labelText,Font=GB,Size=11,Wrap=true,Sz=UDim2.new(1,-16-optIconW,1,0),Pos=UDim2.new(0,10+optIconW,0,0)})
            local mk = Instance.new("Frame"); mk.Size = UDim2.new(0,3,0.6,0); mk.Position = UDim2.new(0,2,0.2,0)
            mk.BackgroundColor3 = ac; mk.BorderSizePixel = 0; mk.Parent = selectButton; corner(2,mk)
            optRefs[optName] = {opt = opt, button = selectButton, mark = mk, label = optLbl}
            mark(optRefs[optName], selected[optName] or false)
            hover(opt, C.btnBg, C.btnHov)
            if o.OptionTooltips then tip(selectButton, o.OptionTooltips[optName]) end
            if meta then
                local actionIndex = 0
                local function addOptionAction(iconName,caption,callback)
                    actionIndex = actionIndex + 1
                    local button = Instance.new("TextButton")
                    button.Name = iconName == "info" and "JLOptionInfo" or "JLOptionSettings"
                    button.Size = UDim2.new(0,22,0,22); button.Position = UDim2.new(1,-(actionIndex * 25) + 1,0.5,-11)
                    button.BackgroundColor3 = C.pHdr; button.BorderSizePixel = 0
                    button.AutoButtonColor = false; button.Text = ""; button.ZIndex = 16; button.Parent = opt
                    corner(6,button)
                    local glyph = mkIcon(button,iconName,12,17)
                    glyph.AnchorPoint = Vector2.new(0.5,0.5); glyph.Position = UDim2.new(0.5,0,0.5,0)
                    glyph.Size = UDim2.new(0,12,0,12)
                    if glyph:IsA("TextLabel") then glyph.TextColor3 = ac else glyph.ImageColor3 = ac end
                    tip(button,caption)
                    button.MouseButton1Click:Connect(callback)
                    JL._metaButtons[#JL._metaButtons + 1] = button
                    button.Visible = not JL._remoteEditActive
                end
                if type(meta.Settings) == "table" and #meta.Settings > 0 then
                    addOptionAction("settings","Item settings",function() openMetaPanel(labelText .. " · Settings",meta.Settings,true) end)
                end
                if meta.Info then
                    addOptionAction("info","Item information",function() openMetaPanel(labelText .. " · Info",meta.Info,false) end)
                end
            end
            if o.OptionLocked or o.OptionHidden or o.OptionRequires or o.OptionHiddenUntil then
                attachLockHidden(opt, {
                    Locked = o.OptionLocked and o.OptionLocked[optName],
                    Hidden = o.OptionHidden and o.OptionHidden[optName],
                    Requires = o.OptionRequires and o.OptionRequires[optName],
                    HiddenUntil = o.OptionHiddenUntil and o.OptionHiddenUntil[optName],
                    LockedMessage = o.LockedMessage, LockedTitle = o.LockedTitle,
                })
            end
            selectButton.MouseButton1Click:Connect(function()
                if multi then
                    local willSelect = not selected[optName]
                    if rules and willSelect and not rules.move and not rules.set[optName] and masterOn() then
                        JL:Notify({Title = "Locked", Desc = "Turn off " .. table.concat(rules.list, " / ") .. " first", Type = "Warn", Duration = 2.5})
                        return
                    end
                    local cnt = 0; for _ in pairs(selected) do cnt = cnt + 1 end
                    if rules and willSelect then
                        local drop = {}
                        if rules.set[optName] then
                            if rules.clear then for nm in pairs(selected) do if not rules.set[nm] then drop[#drop + 1] = nm end end end
                        elseif rules.move then
                            for _,m in ipairs(rules.list) do if selected[m] then drop[#drop + 1] = m end end
                        end
                        if cnt - #drop >= maxSel then return end
                        for _,nm in ipairs(drop) do selected[nm] = nil; if optRefs[nm] then mark(optRefs[nm], false) end end
                        selected[optName] = true; mark(optRefs[optName], true)
                    elseif selected[optName] then selected[optName] = nil; mark(optRefs[optName], false)
                    elseif cnt < maxSel then selected[optName] = true; mark(optRefs[optName], true)
                    else return end
                    refreshBlocked()
                    local sel = {}; for _,nm in ipairs(options) do if not isDividerOpt(nm) and selected[nm] then sel[#sel + 1] = nm end end
                    cfgSet(o.Flag, sel); refreshLabel(); if o.Callback then pcall(o.Callback, sel) end
                else
                    for _,ref in pairs(optRefs) do mark(ref, false) end
                    if selected[optName] then
                        selected = {}
                        cfgSet(o.Flag, nil)
                        refreshLabel()
                        if o.Callback then pcall(o.Callback, nil) end
                    else
                        selected = {}; selected[optName] = true; mark(optRefs[optName], true)
                        cfgSet(o.Flag, optName); refreshLabel()
                        if o.Callback then pcall(o.Callback, optName) end
                    end
                end
            end)
            end
        end
        refreshBlocked()
        bg.MouseButton1Click:Connect(function()
            dropOpen = not dropOpen; container.Visible = true
            tw(container,{Size = UDim2.new(1,0,0,dropOpen and TOTAL or 0)},.2)
            tw(row,{Size = UDim2.new(1,0,0,(dropOpen and (bgH + 4 + TOTAL) or bgH))},.2)
            darr.Text = dropOpen and "▲" or "▼"
            if not dropOpen then trackedDelay(.21, function() if not dropOpen then container.Visible = false end end) end
        end)
        if o.Callback and had then
            if multi then local sel = {}; for _,nm in ipairs(options) do if not isDividerOpt(nm) and selected[nm] then sel[#sel + 1] = nm end end; pcall(o.Callback, sel)
            else for k in pairs(selected) do pcall(o.Callback, k) end end
        end
        ret = {
            _searchTargetRows = searchTargetRows,
            _searchOptionRows = optRefs,
            Open = function()
                if not dropOpen then
                    dropOpen = true; container.Visible = true
                    tw(container,{Size = UDim2.new(1,0,0,TOTAL)},.2)
                    tw(row,{Size = UDim2.new(1,0,0,bgH + 4 + TOTAL)},.2)
                    darr.Text = "▲"
                end
            end,
            Get = function() return selected end,
            Set = function(_,v)
                selected = {}
                if type(v) == "table" then for _,x in ipairs(v) do selected[x] = true end elseif v then selected[v] = true end
                normalize()
                for nm,ref in pairs(optRefs) do mark(ref, selected[nm] or false) end
                refreshBlocked()
                refreshLabel()
            end,
            GetDynamicState = function()
                return {Open = dropOpen, Search = sBox and sBox.Text or nil, CanvasPosition = container.CanvasPosition}
            end,
            RestoreDynamicState = function(_,state)
                if type(state) ~= "table" then return end
                if sBox and state.Search ~= nil then sBox.Text = state.Search end
                if state.Open then
                    dropOpen = true
                    container.Visible = true
                    container.Size = UDim2.new(1,0,0,TOTAL)
                    row.Size = UDim2.new(1,0,0,bgH + 4 + TOTAL)
                    darr.Text = "▲"
                end
                if state.CanvasPosition then
                    trackedDefer(function()
                        if container.Parent then container.CanvasPosition = state.CanvasPosition end
                    end)
                end
            end,
        }
        regFlag(o.Flag, ret, o.NoSave)
        local control = mergeLock(ret, row, o)
        addMetaButtons(row,o)
        return control
    end
    function Sec:TextSlider(o)
        o = o or {}
        local steps
        if o.Options then
            steps = {}
            for i,l in ipairs(o.Options) do steps[i] = {label = tostring(l), value = l} end
        else
            steps = buildSteps(o)
        end
        if #steps == 0 then steps = {{label = "-", value = 0}} end
        local n = #steps
        local had = cfgHas(o.Flag)
        local function idxOf(v)
            if v == nil then return nil end
            for i,s in ipairs(steps) do if s.value == v or s.label == tostring(v) then return i end end
        end
        local init = idxOf(cfgGet(o.Flag, o.Default)) or idxOf(o.Default) or 1
        local name = o.Name or "Level"; local iconW = o.Icon and ICONW or 0
        local widest = 0
        for _,s in ipairs(steps) do widest = math.max(widest, TextService:GetTextSize(s.label, 11, GB, Vector2.new(300,20)).X) end
        local chipW = math.clamp(math.ceil(widest) + 20, 58, 130)
        local topH = fitH(name, 12, GB, INNER - 14 - chipW - iconW, 18, 2)
        local ticks = n > 1 and n <= 12 and o.Ticks ~= false
        local row = newRow(topH + 24 + (ticks and 8 or 0))
        tip(row, o.Tooltip); iconAtLabel(row, o.Icon, topH)
        local eL = edgeIcon(row, o.IconLeft, true, topH + 5)
        local eR = edgeIcon(row, o.IconRight, false, topH + 5)
        newTxt({Parent=row,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(1,-chipW - 10 - iconW,0,topH),Pos=UDim2.new(0,4 + iconW,0,0)})
        local chip = Instance.new("TextLabel"); chip.Size = UDim2.new(0,chipW,0,18); chip.Position = UDim2.new(1,-chipW,0,math.floor((topH - 18) / 2)); chip.BackgroundColor3 = C.pHdr; chip.BorderSizePixel = 0
        chip.Font = GB; chip.TextSize = 11; chip.TextColor3 = ac; chip.Text = steps[init].label; chip.Parent = row; corner(5,chip)
        local cur = init
        local bar = mkSliderBar(row, UDim2.new(0,6 + eL,0,topH + 9), UDim2.new(1,-12 - eL - eR,0,6), ac, 1, n, 1, init, function(v)
            cur = v; chip.Text = steps[v].label; cfgSet(o.Flag, steps[v].value)
            if o.Callback then pcall(o.Callback, steps[v].value, v, steps[v].label) end
        end)
        if ticks then
            local holder = Instance.new("Frame"); holder.Size = UDim2.new(1,-12 - eL - eR,0,4); holder.Position = UDim2.new(0,6 + eL,0,topH + 22); holder.BackgroundTransparency = 1; holder.Parent = row
            for i = 1,n do
                local t = Instance.new("Frame"); t.Size = UDim2.new(0,2,1,0); t.Position = UDim2.new((i - 1) / (n - 1),-1,0,0); t.BackgroundColor3 = C.border; t.BackgroundTransparency = 0.35; t.BorderSizePixel = 0; t.Parent = holder
            end
        end
        if o.Callback and had then pcall(o.Callback, steps[init].value, init, steps[init].label) end
        local ret = {
            Get = function() return steps[cur].value, cur, steps[cur].label end,
            Set = function(_,v)
                local i = idxOf(v) or (type(v) == "number" and math.clamp(math.floor(v), 1, n)) or cur
                bar.Set(i, true); cur = i; chip.Text = steps[i].label; cfgSet(o.Flag, steps[i].value)
            end,
        }
        regFlag(o.Flag, ret, o.NoSave)
        return mergeLock(ret, row, o)
    end
    Sec.NumberTextSlider = Sec.TextSlider
    function Sec:ColorPicker(o)
        o = o or {}
        local had = cfgHas(o.Flag)
        local cur = cfgGet(o.Flag, o.Default or Color3.fromRGB(255,255,255))
        if type(cur) == "table" then cur = Color3.fromRGB(cur[1] or 255, cur[2] or 255, cur[3] or 255) end
        if o.Flag then JL.Flags[o.Flag] = cur end
        local name = o.Name or "Color"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 52 - iconW
        local row = newRow(fitH(name, 12, GB, labW, 32, 14))
        local bg = Instance.new("TextButton"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.btnBg; bg.Text = ""; bg.AutoButtonColor = false; bg.BorderSizePixel = 0; bg.Parent = row
        corner(7,bg); stroke(C.border,1,bg); hover(bg, C.btnBg, C.btnHov); tip(bg, o.Tooltip)
        iconSlot(bg, o.Icon)
        newTxt({Parent=bg,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local sw = Instance.new("Frame"); sw.Size = UDim2.new(0,34,0,18); sw.Position = UDim2.new(1,-44,0.5,-9); sw.BackgroundColor3 = cur; sw.BorderSizePixel = 0; sw.Parent = bg; corner(5,sw); stroke(C.border,1,sw)
        sw:SetAttribute("JLNoRepaint", true)
        bg.MouseButton1Click:Connect(function()
            openColorPicker(parentSg, cur, function(col)
                cur = col; sw.BackgroundColor3 = col
                cfgSet(o.Flag, col, {math.round(col.R * 255), math.round(col.G * 255), math.round(col.B * 255)})
                if o.Callback then pcall(o.Callback, col) end
            end)
        end)
        if o.Callback and had then pcall(o.Callback, cur) end
        local ret = {Get = function() return cur end, Set = function(_,v) cur = v; sw.BackgroundColor3 = v end}
        regFlag(o.Flag, ret, o.NoSave)
        return mergeLock(ret, row, o)
    end
    function Sec:Keybind(o)
        o = o or {}
        local defName = (typeof(o.Default) == "EnumItem" and o.Default.Name) or (o.Default and tostring(o.Default)) or "None"
        local nm = cfgGet(o.Flag, defName)
        local name = o.Name or "Keybind"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 96 - iconW
        local row = newRow(fitH(name, 12, GB, labW, 32, 14))
        local bg = Instance.new("Frame"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.btnBg; bg.BorderSizePixel = 0; bg.Parent = row; corner(7,bg); stroke(C.border,1,bg)
        tip(bg, o.Tooltip); iconSlot(bg, o.Icon)
        newTxt({Parent=bg,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local kw, pw = {}, {}
        local chip = mkKeyChip(bg, UDim2.new(1,-94,0.5,-11), nm, function(k)
            cfgSet(o.Flag, k and k.Name or "None"); if o.Callback then pcall(o.Callback, k) end
            for _,w in ipairs(kw) do pcall(w, k) end
        end)
        keep(UIS.InputBegan:Connect(function(i,gp)
            if gp or JL._listening then return end
            local k = chip.Get()
            if k and i.KeyCode == k then
                if o.OnPress then pcall(o.OnPress) end
                for _,w in ipairs(pw) do pcall(w) end
            end
        end))
        local ret = {
            Get = function() return chip.Get() end,
            Set = function(_,k) chip.Set(k); cfgSet(o.Flag, k and k.Name or "None"); for _,w in ipairs(kw) do pcall(w, k) end end,
            Press = function() if o.OnPress then pcall(o.OnPress) end; for _,w in ipairs(pw) do pcall(w) end end,
            Watch = function(_,fn) kw[#kw + 1] = fn end, OnPulse = function(_,fn) pw[#pw + 1] = fn end,
        }
        regFlag(o.Flag, ret, o.NoSave)
        local out = mergeLock(ret, row, o)
        if o.Remote then JL._remoteAttach("Keybind", o, out) end
        return out
    end
    function Sec:Segmented(o)
        o = o or {}
        local opts2 = o.Options or {}; local had = cfgHas(o.Flag)
        local cur = cfgGet(o.Flag, o.Default or opts2[1])
        local nameH = o.Name and fitH(o.Name, 12, GB, INNER - 8, 16, 2) or 0
        local yOff = (nameH > 0) and (nameH + 4) or 0
        local row = newRow(yOff + 28)
        tip(row, o.Tooltip)
        if o.Name then newTxt({Parent=row,Text=o.Name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(1,-8,0,nameH),Pos=UDim2.new(0,4,0,0)}) end
        local seg = mkSegmented(row, UDim2.new(0,0,0,yOff), UDim2.new(1,0,0,28), opts2, cur, ac, function(v)
            cfgSet(o.Flag, v); if o.Callback then pcall(o.Callback, v) end
        end)
        if o.Callback and had then pcall(o.Callback, cur) end
        local ret = {Get = seg.Get, Set = function(_,v) seg.Set(v, true); cfgSet(o.Flag, v) end}
        regFlag(o.Flag, ret, o.NoSave)
        return mergeLock(ret, row, o)
    end
    function Sec:Group(o)
        o = o or {}
        local wA, wB = compactWidth(o.A), compactWidth(o.B)
        local gap = (o.A and o.B) and 14 or 0
        local totalW = wA + wB + gap
        local startX = math.max(10, INNER - totalW - 10)
        local labW = math.max(30, startX - 14)
        local name = o.Name or ""
        local h = math.max(36, fitH(name, 12, GB, labW, 0, 14))
        local row = newRow(h)
        tip(row, o.Tooltip)
        newTxt({Parent=row,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10,0,0)})
        local ctrls = {}
        local x = startX
        if o.A then ctrls.A = mkCompactControl(row, x, wA, o.A, ac, regFlag, parentSg, cfgGet, cfgSet, cfgHas); x = x + wA + gap end
        if o.B then ctrls.B = mkCompactControl(row, x, wB, o.B, ac, regFlag, parentSg, cfgGet, cfgSet, cfgHas) end
        return mergeLock(ctrls, row, o)
    end
    function Sec:Text(o)
        o = o or {}
        local sz = o.Size or 15
        local fnt = (o.Bold == false) and GM or GB
        local iconW = o.Icon and (ICONW + 4) or 0
        local h0 = fitH(o.Text or "", sz, fnt, INNER - 8 - iconW, 16, 6)
        local row = newRow(math.max(h0, iconW > 0 and 20 or 0))
        tip(row, o.Tooltip)
        if o.Icon then local ic = mkIcon(row,o.Icon,16,5); ic.Position = UDim2.new(0,4,0,1); ic.Size = UDim2.new(0,16,0,16); if ic:IsA("TextLabel") then ic.TextColor3 = o.Color or ac else ic.ImageColor3 = o.Color or ac end end
        local l = newTxt({Parent=row,Text=o.Text or "",Size=sz,Color=o.Color or C.txt,Wrap=true,XAlign=o.Align or Enum.TextXAlignment.Left,Sz=UDim2.new(1,-8 - iconW,1,0),Pos=UDim2.new(0,4 + iconW,0,0)})
        l.Font = fnt
        if o.RichText then l.RichText = true end
        return mergeLock({Set = function(_,t) l.Text = t; row.Size = UDim2.new(1,0,0,fitH(t, sz, fnt, INNER - 8 - iconW, 16, 6)) end}, row, o)
    end
    function Sec:Screen(o)
        o = o or {}
        local h = o.Height or 120
        local yOff = 0
        local row
        if o.Name then
            row = newRow(h + 22)
            newTxt({Parent=row,Text=o.Name,Font=GB,Size=12,Sz=UDim2.new(1,-8,0,18),Pos=UDim2.new(0,4,0,0)})
            yOff = 22
        else
            row = newRow(h)
        end
        local box = Instance.new("Frame"); box.Size = UDim2.new(1,0,0,h); box.Position = UDim2.new(0,0,0,yOff); box.BackgroundColor3 = C.pHdr; box.BorderSizePixel = 0; box.ClipsDescendants = true; box.Parent = row
        corner(8,box); stroke(C.border,1,box); tip(box, o.Tooltip)
        local img = Instance.new("ImageLabel"); img.Size = UDim2.new(1,-12,1,-12); img.Position = UDim2.new(0,6,0,6); img.BackgroundTransparency = 1
        img.ScaleType = o.ScaleType or Enum.ScaleType.Fit; img.Parent = box
        img:SetAttribute("JLNoRepaint", true)
        local status = newTxt({Parent=box,Text="",Font=GM,Size=11,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,1,0)})
        local function setId(id)
            local s = tostring(id)
            img.Image = s:match("^%d+$") and ("rbxassetid://" .. s) or s
        end
        local function setPlayer(plr)
            status.Text = "loading..."
            trackedSpawn(function()
                local userId = (typeof(plr) == "Instance") and plr.UserId or tonumber(plr)
                if not userId then status.Text = "invalid player"; return end
                local ok,content = pcall(function()
                    return game:GetService("Players"):GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, o.ThumbSize or Enum.ThumbnailSize.Size180x180)
                end)
                if ok then img.Image = content; status.Text = "" else status.Text = "failed to load" end
            end)
        end
        if o.Player then setPlayer(o.Player) elseif o.Image then setId(o.Image) end
        return mergeLock({SetImage = function(_,id) setId(id) end, SetPlayer = function(_,plr) setPlayer(plr) end}, row, o)
    end
    function Sec:Label(o)
        o = o or {}
        local iconW = o.Icon and (ICONW + 2) or 0
        local h0 = fitH(o.Text or "", 11, G, INNER - 8 - iconW, 18, 4)
        local row = newRow(h0)
        tip(row, o.Tooltip)
        if o.Icon then local ic = mkIcon(row,o.Icon,13,5); ic.Position = UDim2.new(0,4,0,2); ic.Size = UDim2.new(0,13,0,13); if ic:IsA("TextLabel") then ic.TextColor3 = C.dim else ic.ImageColor3 = C.dim end end
        local l = newTxt({Parent=row,Text=o.Text or "",Size=11,Color=o.Color or C.dim,Wrap=true,Sz=UDim2.new(1,-8 - iconW,1,0),Pos=UDim2.new(0,4 + iconW,0,0)})
        if o.RichText then l.RichText = true end
        return mergeLock({Set = function(_,t) l.Text = t; row.Size = UDim2.new(1,0,0,fitH(t, 11, G, INNER - 8 - iconW, 18, 4)) end}, row, o)
    end
    function Sec:Divider(o)
        local row = newRow(16)
        local line = Instance.new("Frame"); line.Size = UDim2.new(1,0,0,1); line.Position = UDim2.new(0,0,0.5,0); line.BackgroundColor3 = C.divLine; line.BorderSizePixel = 0; line.Parent = row
        if o and o.Label then
            local LW = math.min(#o.Label * 7 + 14, INNER)
            local bg = Instance.new("Frame"); bg.Size = UDim2.new(0,LW,0,14); bg.Position = UDim2.new(0.5,-LW/2,0.5,-7); bg.BackgroundColor3 = C.panel; bg.BorderSizePixel = 0; bg.Parent = row
            newTxt({Parent=bg,Text=o.Label,Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center})
        end
    end
    -- ===== Preview UI: открытие из кнопки / тогла / дропдауна =====
    local function pvResolve(o)
        local pv = (o and o.Preview) or JL._preview
        if type(pv) == "table" and rawget(pv, "IsStub") then return nil end
        return pv
    end
    local function pvMissing()
        JL:Notify({Title = "Preview UI", Desc = "Create it first: local Preview = JL:Preview({...})", Type = "Warn", Duration = 3})
    end
    local function pvCopy(o) local t = {}; for k,v in pairs(o or {}) do t[k] = v end; return t end
    function Sec:PreviewButton(o)
        o = o or {}; local o2 = pvCopy(o); local cb = o.Callback
        o2.Name = o.Name or "Open Preview"
        o2.Callback = function()
            local pv = pvResolve(o)
            if pv then pv:Open(o.Target) else pvMissing() end
            if cb then pcall(cb, pv) end
        end
        return self:Button(o2)
    end
    function Sec:PreviewToggle(o)
        o = o or {}; local o2 = pvCopy(o); local cb = o.Callback
        o2.Name = o.Name or "Preview Window"
        o2.Callback = function(v)
            local pv = pvResolve(o)
            if not pv then pvMissing(); return end
            if v then pv:Open(o.Target) else pv:Close() end
            if cb then pcall(cb, v) end
        end
        local ctrl = self:Toggle(o2)
        local pv0 = pvResolve(o)
        if pv0 and pv0.OnClosed then
            pv0:OnClosed(function() if ctrl and ctrl.Set then pcall(function() ctrl:Set(false) end) end end)
        end
        return ctrl
    end
    function Sec:PreviewDropdown(o)
        o = o or {}; local o2 = pvCopy(o); local cb = o.Callback
        o2.Name = o.Name or "Open Preview tab"
        o2.Options = function()
            local p = pvResolve(o)
            local names = {}
            if p then
                for _,t in ipairs(p:GetTabs()) do names[#names + 1] = t.Name end
            end
            return names
        end
        o2.Static = true; o2.MultiSelect = nil
        o2.Callback = function(sel)
            local p = pvResolve(o)
            if not p then pvMissing(); return end
            if sel and sel ~= "" then p:Open(sel) end
            if cb then pcall(cb, sel) end
        end
        return self:Dropdown(o2)
    end
    function Sec:Custom(height,setupFn)
        iOrd = iOrd + 1
        local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,height); f.BackgroundTransparency = 1; f.LayoutOrder = iOrd; f.ClipsDescendants = true; f.Parent = content
        if setupFn then setupFn(f) end
        return f
    end
    for _,kind in ipairs({"Toggle","Slider","Button","Input","Dropdown","TextSlider","Segmented","Keybind","ColorPicker","Group","Screen"}) do
        local orig = Sec[kind]
        if orig then
            Sec[kind] = function(self,o)
                local from = #JL._newRows
                local ret = orig(self,o)
                local own = type(o) == "table" and o.Background or nil
                local rows = JL._newRows
                for i = from + 1, #rows do
                    BG.register(kind, BG.face(rows[i]), 7, own, true)
                    if type(o) == "table" and (kind == "Toggle" or kind == "Slider" or kind == "Button" or kind == "Input") then addMetaButtons(rows[i],o) end
                end
                if from == 0 then JL._newRows = {} end
                return ret
            end
        end
    end
    -- ===== Dynamic Dropdown options =====
    -- Options and Values accept tables or provider functions.
    -- AutoUpdate polls the providers; Refresh() remains available for manual updates.
    local function copyDropdownOptions(src)
        local out = {}
        for k,v in pairs(src or {}) do out[k] = v end
        return out
    end
    local function cloneDropdownData(value,seen)
        if type(value) ~= "table" then return value end
        seen = seen or {}
        if seen[value] then return seen[value] end
        local out = {}
        seen[value] = out
        for k,v in pairs(value) do
            out[cloneDropdownData(k,seen)] = cloneDropdownData(v,seen)
        end
        return out
    end
    local function sameDropdownData(a,b,seen)
        if a == b then return true end
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return false end
        seen = seen or {}
        if seen[a] == b then return true end
        seen[a] = b
        for k,v in pairs(a) do
            if not sameDropdownData(v,b[k],seen) then return false end
        end
        for k in pairs(b) do
            if a[k] == nil then return false end
        end
        return true
    end
    local function resolveDropdownOptions(source,fallback)
        if type(source) == "function" then
            local ok,result = pcall(source)
            if ok and type(result) == "table" then return result end
            return fallback or {}
        end
        if type(source) == "table" then return source end
        return {}
    end
    do
        local create = Sec.Dropdown
        Sec.Dropdown = function(self,o)
            o = o or {}
            local optionsSource = o.Options
            local lastOptions = cloneDropdownData(resolveDropdownOptions(optionsSource,{}))
            local buildOpts = copyDropdownOptions(o)
            buildOpts.Options = lastOptions
            local stable = create(self,buildOpts)
            if type(stable) ~= "table" then return stable end
            local refreshing = false
            local overrideOptions
            local refreshFn
            local function refresh()
                if refreshing then return false end
                local oldRow = stable.Row
                if not oldRow or not oldRow.Parent then return false end
                local oldWrapper = oldRow.Parent.Name == "JLMetaRow" and oldRow.Parent or nil
                local oldRoot = oldWrapper or oldRow
                refreshing = true
                local nextOptions = cloneDropdownData(resolveDropdownOptions(overrideOptions or optionsSource,lastOptions))
                if sameDropdownData(lastOptions,nextOptions) then
                    refreshing = false
                    return true
                end
                local previous
                if stable.Get then
                    local ok,value = pcall(stable.Get)
                    if ok then previous = value end
                end
                local uiState
                if stable.GetDynamicState then
                    local ok,value = pcall(stable.GetDynamicState,stable)
                    if ok then uiState = value end
                end
                local nextOpts = copyDropdownOptions(o)
                nextOpts.Options = nextOptions
                nextOpts._DynamicState = uiState
                nextOpts.Callback = nil
                local oldLayout = oldRoot.LayoutOrder
                local oldLocked = stable.IsLocked and stable.IsLocked() or false
                local oldHidden = stable.IsHidden and stable.IsHidden() or false
                local ok,newControl = pcall(create,self,nextOpts)
                if not ok or type(newControl) ~= "table" then
                    refreshing = false
                    return false
                end
                local selectedList = {}
                if type(previous) == "table" then
                    for _,item in ipairs(nextOptions) do
                        if not isDividerOpt(item) then
                            local value = type(item) == "table" and (item.Value or item.Name) or item
                            if value ~= nil and previous[value] then selectedList[#selectedList + 1] = value end
                        end
                    end
                elseif previous ~= nil then
                    for _,item in ipairs(nextOptions) do
                        if not isDividerOpt(item) then
                            local value = type(item) == "table" and (item.Value or item.Name) or item
                            if value == previous then selectedList[1] = value; break end
                        end
                    end
                end
                if not o.MultiSelect and #selectedList > 1 then
                    selectedList = {selectedList[1]}
                end
                if newControl.Set then
                    pcall(newControl.Set,newControl,o.MultiSelect and selectedList or selectedList[1])
                end
                if o.Flag then
                    cfgSet(o.Flag,o.MultiSelect and selectedList or selectedList[1])
                end
                if uiState and newControl.RestoreDynamicState then
                    pcall(newControl.RestoreDynamicState,newControl,uiState)
                end
                if newControl.Row then
                    local newWrapper = newControl.Row.Parent and newControl.Row.Parent.Name == "JLMetaRow" and newControl.Row.Parent or nil
                    (newWrapper or newControl.Row).LayoutOrder = oldLayout
                end
                if oldLocked and newControl.SetLocked then pcall(newControl.SetLocked,newControl,true) end
                if oldHidden and newControl.SetHidden then pcall(newControl.SetHidden,newControl,true) end
                if oldWrapper then oldWrapper:Destroy() else oldRow:Destroy() end
                for i = #(JL._metaButtons or {}), 1, -1 do
                    local button = JL._metaButtons[i]
                    if not button or not button.Parent then table.remove(JL._metaButtons, i) end
                end
                for k in pairs(stable) do stable[k] = nil end
                for k,v in pairs(newControl) do stable[k] = v end
                lastOptions = nextOptions
                stable.Refresh = refreshFn
                stable.SetOptions = function(_,list)
                    if type(list) ~= "table" then return false end
                    overrideOptions = list
                    return refreshFn()
                end
                if o.Flag then JL._registry[o.Flag] = stable end
                refreshing = false
                return true
            end
            refreshFn = refresh
            stable.Refresh = refreshFn
            stable.SetOptions = function(_,list)
                if type(list) ~= "table" then return false end
                overrideOptions = list
                return refreshFn()
            end
            local interval
            if o.AutoUpdate == true then
                interval = tonumber(o.Interval) or 5
            elseif o.RefreshInterval ~= nil then
                interval = tonumber(o.RefreshInterval)
            end
            if interval and interval > 0 then
                trackedSpawn(function()
                    while stable.Row and stable.Row.Parent do
                        task.wait(math.max(interval,0.1))
                        if stable.Row and stable.Row.Parent then refreshFn() end
                    end
                end)
            end
            return stable
        end
    end
    local searchMethods = {
        Toggle = true, ToggleGroup = true, Slider = true, Button = true, Input = true,
        Dropdown = true, TextSlider = true, NumberTextSlider = true, ColorPicker = true,
        Keybind = true, Segmented = true, Group = true, Text = true, Screen = true,
        Label = true, PreviewButton = true, PreviewToggle = true, PreviewDropdown = true,
    }
    for methodName in pairs(searchMethods) do
        local original = Sec[methodName]
        if type(original) == "function" then
            Sec[methodName] = function(self, o, ...)
                local result = original(self, o, ...)
                if type(result) == "table" and result.Row and type(o) == "table" and JL._searchRegister then
                    JL._searchRegister({Name = o.Name or methodName, Kind = methodName, Row = result.Row, Control = result})
                    if methodName == "Dropdown" and type(o.Options) == "table" then
                        for _, optionName in ipairs(o.Options) do
                            if not isDividerOpt(optionName) then
                                local optionKey = type(optionName) == "table" and (optionName.Value or optionName.Name) or optionName
                                JL._searchRegister({
                                    Name = tostring(optionKey), Kind = "Option",
                                    ParentName = o.Name or methodName, Row = result.Row, Control = result,
                                    TargetResolver = function()
                                        local refs = result._searchOptionRows
                                        local ref = refs and refs[optionKey]
                                        return ref and ref.opt or nil
                                    end,
                                })
                            end
                        end
                    end
                end
                return result
            end
        end
    end
    return Sec
end
local function makeSection(parentFrame,title,parentSg,layoutOrder,colW,so,uiScale,attachTip,config)
    so = so or {}
    local ac = nxAc()
    local iconW = so.Icon and 22 or 0
    local INNER = colW - 16
    local HH = math.max(34, fitH(title, 13, GB, colW - 54 - iconW, 0, 0) + 16)
    local function unscale(px)
        local s = (uiScale and uiScale.Scale) or 1
        if not s or s <= 0 then s = 1 end
        return px / s
    end
    local panel = Instance.new("Frame"); panel.Size = UDim2.new(1,0,0,HH); panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
    panel:SetAttribute("JLSearchSection", tostring(title or "Section"))
    panel.LayoutOrder = layoutOrder or 1; panel.ClipsDescendants = true; panel.Parent = parentFrame
    corner(10,panel); stroke(C.border,1,panel)
    BG.register("Section", panel, 10, so.Background)
    local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,HH); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = panel; corner(10,hdr)
    local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    local pill = Instance.new("Frame"); pill.Size = UDim2.new(0,3,0,14); pill.Position = UDim2.new(0,10,0.5,-7); pill.BackgroundColor3 = ac; pill.BorderSizePixel = 0; pill.ZIndex = 3; pill.Parent = hdr; corner(2,pill)
    if so.Icon then local ic = mkIcon(hdr, so.Icon, 15, 3); ic.Position = UDim2.new(0,22,0.5,-7); ic.Size = UDim2.new(0,15,0,15); if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end end
    newTxt({Parent=hdr,Text=title,Font=GB,Size=13,Wrap=true,Sz=UDim2.new(1,-54 - iconW,1,0),Pos=UDim2.new(0,22 + iconW,0,0),Z=3})
    local arrow = newTxt({Parent=hdr,Text="▼",Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,30,1,0),Pos=UDim2.new(1,-30,0,0),Z=3})
    local secBtn = Instance.new("TextButton"); secBtn.Size = UDim2.new(1,0,1,0); secBtn.BackgroundTransparency = 1; secBtn.Text = ""; secBtn.ZIndex = 4; secBtn.Parent = hdr
    if attachTip and so.Tooltip then attachTip(hdr, so.Tooltip) end
    local hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,0,HH); hline.BackgroundColor3 = ac; hline.BackgroundTransparency = 0.55; hline.BorderSizePixel = 0; hline.Parent = panel
    local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,0,0); content.Position = UDim2.new(0,0,0,HH + 1); content.BackgroundTransparency = 1; content.ClipsDescendants = true; content.Parent = panel
    local list = Instance.new("UIListLayout"); list.FillDirection = Enum.FillDirection.Vertical; list.Padding = UDim.new(0,6); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = content
    pad(8,8,8,8,content)
    local collapsed = so.Collapsed or false; local storedH = 0; local animating = false
    local function fullH() return HH + 1 + storedH end
    local function updatePanel()
        local ch = list.AbsoluteContentSize.Y
        storedH = (ch > 0) and (unscale(ch) + 16) or 0
        content.Size = UDim2.new(1,0,0,storedH)
        if not collapsed and not animating then panel.Size = UDim2.new(1,0,0,fullH()) end
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePanel)
    local function setCollapsed(c)
        collapsed = c; animating = true
        hfix.Visible = not c; hline.Visible = not c
        tw(arrow,{Rotation = c and 180 or 0},.2)
        if c then
            tw(panel,{Size = UDim2.new(1,0,0,HH)},.18)
            trackedDelay(.2, function() animating = false; if collapsed then content.Visible = false end end)
        else
            content.Visible = true; tw(panel,{Size = UDim2.new(1,0,0,fullH())},.18)
            trackedDelay(.2, function() animating = false; updatePanel() end)
        end
    end
    secBtn.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end)
    if collapsed then content.Visible = false; arrow.Rotation = 180; hfix.Visible = false; hline.Visible = false end
    local Sec = attachWidgets(content, INNER, ac, uiScale, parentSg, attachTip, config)
    Sec.Panel = panel
    function Sec:SetCollapsed(c) if c ~= collapsed then setCollapsed(c) end end
    JL._secPanels[panel] = Sec
    function Sec:ToggleCollapsed() setCollapsed(not collapsed); return collapsed end
    function Sec:IsCollapsed() return collapsed end
    local secLock = attachLockHidden(panel, so)
    Sec.SetLocked = secLock.SetLocked; Sec.SetHidden = secLock.SetHidden
    Sec.IsLocked = secLock.IsLocked; Sec.IsHidden = secLock.IsHidden
    Sec.ToggleLocked = secLock.ToggleLocked; Sec.ToggleHidden = secLock.ToggleHidden
    return Sec
end
local function makeMultiSection(parentFrame,sopts,parentSg,layoutOrder,colW,uiScale,attachTip,config)
    sopts = sopts or {}
    local ac = nxAc()
    local INNER = colW - 16
    local pages = sopts.Pages or {"Page 1","Page 2"}
    if #pages > 9 then -- максимум 9 страниц
        warn("[JustLib] MultiSection supports up to 9 pages; extra pages were ignored")
        local cut = {}; for i = 1,9 do cut[i] = pages[i] end; pages = cut
    end
    local iconW = sopts.Icon and 22 or 0
    local titleH = sopts.Title and 20 or 0
    -- Layout: "Auto" (до 3 страниц - одна полоса, больше - строки), "Segmented", "Scroll" (лента) или "Rows" (строки по Columns штук)
    local mode = tostring(sopts.Layout or "Auto")
    if mode == "Auto" then mode = (#pages <= 3) and "Segmented" or "Rows" end
    if mode ~= "Scroll" and mode ~= "Rows" then mode = "Segmented" end
    local cols = math.clamp(math.floor(tonumber(sopts.Columns) or 3), 2, 5)
    local swH = 28
    if mode == "Rows" then local rowsN = math.ceil(#pages / cols); swH = rowsN * 26 + (rowsN - 1) * 4 + 4 end
    local HH = 12 + swH + titleH
    local function unscale(px)
        local s = (uiScale and uiScale.Scale) or 1
        if not s or s <= 0 then s = 1 end
        return px / s
    end
    local panel = Instance.new("Frame"); panel.Size = UDim2.new(1,0,0,HH); panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
    panel:SetAttribute("JLSearchSection", tostring(sopts.Title or "MultiSection"))
    panel.LayoutOrder = layoutOrder or 1; panel.ClipsDescendants = true; panel.Parent = parentFrame
    corner(10,panel); stroke(C.border,1,panel)
    BG.register("Section", panel, 10)
    local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,HH); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = panel; corner(10,hdr)
    local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    if sopts.Title then newTxt({Parent=hdr,Text=sopts.Title,Font=GB,Size=12,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-16,0,16),Pos=UDim2.new(0,8,0,3),Z=3}) end
    if sopts.Icon then local ic = mkIcon(hdr, sopts.Icon, 16, 3); ic.Position = UDim2.new(0,8,0,titleH + 12); ic.Size = UDim2.new(0,16,0,16); if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end end
    if attachTip and sopts.Tooltip then attachTip(hdr, sopts.Tooltip) end
    local hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,0,HH); hline.BackgroundColor3 = ac; hline.BackgroundTransparency = 0.55; hline.BorderSizePixel = 0; hline.Parent = panel
    local activePage = pages[1]
    local contents = {}; local storedH = {}
    local sharedH = 0 -- высота блока общих элементов (Shared = true): он всегда сверху, на любой странице
    local function contentY() return HH + 1 + sharedH + ((sharedH > 0) and 1 or 0) end
    local function repaint()
        panel.Size = UDim2.new(1,0,0, contentY() + (storedH[activePage] or 0))
        for nm,c in pairs(contents) do c.Visible = (nm == activePage); c.Position = UDim2.new(0,0,0,contentY()) end
    end
    local switcher = mkPageTabs(hdr, UDim2.new(0,8 + iconW,0,6 + titleH), UDim2.new(1,-16 - iconW,0,swH), pages, activePage, ac, function(v)
        activePage = v; repaint()
    end, mode, cols, unscale)
    local sharedHost = Instance.new("Frame"); sharedHost.Size = UDim2.new(1,0,0,0); sharedHost.Position = UDim2.new(0,0,0,HH + 1)
    sharedHost:SetAttribute("JLSearchPage", "Shared")
    sharedHost.BackgroundTransparency = 1; sharedHost.BorderSizePixel = 0; sharedHost.ClipsDescendants = true; sharedHost.Parent = panel
    local sharedList = Instance.new("UIListLayout"); sharedList.Padding = UDim.new(0,6); sharedList.SortOrder = Enum.SortOrder.LayoutOrder; sharedList.Parent = sharedHost
    pad(8,8,8,8,sharedHost)
    local sharedLine = Instance.new("Frame"); sharedLine.Size = UDim2.new(1,-16,0,1); sharedLine.BackgroundColor3 = C.divLine; sharedLine.BorderSizePixel = 0
    sharedLine.Visible = false; sharedLine.Parent = panel
    sharedList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local ch = sharedList.AbsoluteContentSize.Y
        sharedH = (ch > 0) and (unscale(ch) + 16) or 0
        sharedHost.Size = UDim2.new(1,0,0,sharedH)
        sharedLine.Visible = sharedH > 0; sharedLine.Position = UDim2.new(0,8,0,HH + 1 + sharedH)
        repaint()
    end)
    local sharedSec = attachWidgets(sharedHost, INNER, ac, uiScale, parentSg, attachTip, config)
    -- любой элемент страницы с Shared = true (или Pinned = true) создаётся в общем блоке сверху
    local function redirect(sec)
        for k,fn in pairs(sec) do
            if type(fn) == "function" and type(k) == "string" and k:match("^%u") and type(sharedSec[k]) == "function" then
                sec[k] = function(self, o, ...)
                    if type(o) == "table" and (o.Shared or o.Pinned) then return sharedSec[k](sharedSec, o, ...) end
                    return fn(self, o, ...)
                end
            end
        end
    end
    local pageSecs = {}
    for _,name in ipairs(pages) do
        local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,0,0); content.Position = UDim2.new(0,0,0,contentY())
        content:SetAttribute("JLSearchPage", tostring(name))
        content.BackgroundTransparency = 1; content.ClipsDescendants = true; content.Visible = (name == activePage); content.Parent = panel
        local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0,6); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = content
        pad(8,8,8,8,content)
        storedH[name] = 0
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local ch = list.AbsoluteContentSize.Y
            storedH[name] = (ch > 0) and (unscale(ch) + 16) or 0
            content.Size = UDim2.new(1,0,0,storedH[name])
            if name == activePage then repaint() end
        end)
        contents[name] = content
        pageSecs[name] = attachWidgets(content, INNER, ac, uiScale, parentSg, attachTip, config)
        redirect(pageSecs[name])
    end
    local MS = {Panel = panel}
    function MS:Page(name) return pageSecs[name] end
    function MS:Shared() return sharedSec end -- общий блок напрямую: MS:Shared():Toggle({...})
    function MS:SetPage(name) if contents[name] and name ~= activePage then activePage = name; switcher.Set(name, true); repaint() end end
    function MS:GetPage() return activePage end
    for pageName,pageFrame in pairs(contents) do
        JL._searchPageTargets[pageFrame] = function()
            if activePage == pageName then return false end
            MS:SetPage(pageName)
            return true
        end
    end
    local msLock = attachLockHidden(panel, sopts)
    MS.SetLocked = msLock.SetLocked; MS.SetHidden = msLock.SetHidden
    MS.IsLocked = msLock.IsLocked; MS.IsHidden = msLock.IsHidden
    MS.ToggleLocked = msLock.ToggleLocked; MS.ToggleHidden = msLock.ToggleHidden
    return MS
end
