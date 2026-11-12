local function mkSwitch(parent,pos,state,ac)
    local track = Instance.new("Frame"); track.Size = UDim2.new(0,34,0,18); track.Position = pos
    track.BackgroundColor3 = state and ac or C.togOff; track.BorderSizePixel = 0; track.Parent = parent; corner(9,track)
    local st = stroke(state and ac or C.border, 1, track)
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,12,0,12)
    knob.Position = state and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
    knob.BackgroundColor3 = state and Color3.new(1,1,1) or C.dim; knob.BorderSizePixel = 0; knob.Parent = track; corner(6,knob)
    local obj = {Frame = track}
    function obj.Set(v)
        tw(track,{BackgroundColor3 = v and ac or C.togOff},.15)
        tw(knob,{Position = v and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6), BackgroundColor3 = v and Color3.new(1,1,1) or C.dim},.15)
        tw(st,{Color = v and ac or C.border},.15)
    end
    return obj
end
local function mkSliderBar(parent,pos,size,ac,vmin,vmax,step,init,onChange,onRelease)
    local track = Instance.new("Frame"); track.Size = size; track.Position = pos; track.BackgroundColor3 = C.slTrack; track.BorderSizePixel = 0; track.Parent = parent; corner(3,track)
    local fill = Instance.new("Frame"); fill.BackgroundColor3 = ac; fill.BorderSizePixel = 0; fill.Parent = track; corner(3,fill)
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,14,0,14); knob.BackgroundColor3 = Color3.new(1,1,1); knob.BorderSizePixel = 0; knob.ZIndex = 2; knob.Parent = track; corner(7,knob)
    local knobStroke = stroke(Color3.fromRGB(20,20,24),1,knob)
    skinKnob(knob, knobStroke)
    local hit = Instance.new("TextButton"); hit.Size = UDim2.new(1,14,0,26); hit.Position = UDim2.new(0,-7,0.5,-13); hit.BackgroundTransparency = 1; hit.Text = ""; hit.AutoButtonColor = false; hit.ZIndex = 3; hit.Parent = track
    local val = snap(tonumber(init) or vmin, vmin, vmax, step)
    local function paint()
        local p = (vmax > vmin) and (val - vmin) / (vmax - vmin) or 0
        fill.Size = UDim2.new(p,0,1,0); knob.Position = UDim2.new(p,-7,0.5,-7)
    end
    paint()
    local obj = {}
    function obj.Set(v,silent)
        v = snap(tonumber(v) or vmin, vmin, vmax, step)
        local changed = (v ~= val); val = v; paint()
        if changed and not silent and onChange then onChange(v) end
    end
    function obj.Get() return val end
    local function fromX(x)
        local w = track.AbsoluteSize.X; if w <= 0 then return end
        local p = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        obj.Set(vmin + p * (vmax - vmin), false)
    end
    hit.InputBegan:Connect(function(i)
        if not isPtr(i) then return end
        fromX(i.Position.X); beginDrag(function(m) fromX(m.Position.X) end, onRelease)
    end)
    return obj
end
local function buildSteps(cfg)
    local steps = {}
    if cfg.Labels then
        for i,l in ipairs(cfg.Labels) do steps[i] = {label = tostring(l), value = (cfg.LabelValues and cfg.LabelValues[i]) or l} end
    else
        local mn,mx,st = cfg.Min or 1, cfg.Max or 5, cfg.Step or 1
        if st <= 0 then st = 1 end
        local dec = decimalsOf(st)
        local k = 0
        while mn + k * st <= mx + 1e-9 and k < 200 do
            local v = snap(mn + k * st, mn, mx, st)
            steps[#steps + 1] = {label = fmtNum(v, dec) .. (cfg.Suffix or ""), value = v}
            k = k + 1
        end
    end
    if cfg.All then
        local allStep = {label = cfg.AllText or "All", value = cfg.AllValue or "All"}
        if cfg.All == "Start" or cfg.All == "First" then table.insert(steps, 1, allStep) else steps[#steps + 1] = allStep end
    end
    return steps
end
local function mkSegmented(parent,pos,size,options,init,ac,onChange)
    local f = Instance.new("Frame"); f.Size = size; f.Position = pos; f.BackgroundColor3 = C.pHdr; f.BorderSizePixel = 0; f.Parent = parent; corner(8,f); stroke(C.border,1,f)
    local cur = init; local btns = {}; local n = math.max(#options,1)
    local function paint()
        for name,b in pairs(btns) do
            local on = (name == cur)
            tw(b,{BackgroundColor3 = on and ac or C.pHdr, TextColor3 = on and Color3.new(1,1,1) or C.dim},.15)
        end
    end
    local obj = {}
    for i,name in ipairs(options) do
        local b = Instance.new("TextButton"); b.Size = UDim2.new(1/n,-4,1,-6); b.Position = UDim2.new((i-1)/n,2,0,3)
        b.BackgroundColor3 = C.pHdr; b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Text = tostring(name); b.Font = GB
        b.TextSize = 11; b.TextScaled = true; b.TextColor3 = C.dim; b.Parent = f; corner(6,b)
        local tc = Instance.new("UITextSizeConstraint"); tc.MaxTextSize = 11; tc.MinTextSize = 6; tc.Parent = b
        btns[name] = b
        b.MouseButton1Click:Connect(function()
            if cur == name then return end
            cur = name; paint(); if onChange then onChange(name) end
        end)
    end
    paint()
    function obj.Set(v,silent) if btns[v] then cur = v; paint(); if not silent and onChange then onChange(v) end end end
    function obj.Get() return cur end
    return obj
end
-- Переключатель страниц мультисекции (до 9 страниц):
--   "Segmented" - как раньше, одна полоса (удобно для 2-3 страниц)
--   "Scroll"    - одна лента, которую можно листать вправо/влево (колесо, перетаскивание, стрелки)
--   "Rows"      - кнопки складываются в строки по N штук (по умолчанию 3 в строке)
local function mkPageTabs(parent,pos,size,options,init,ac,onChange,mode,cols,unscale)
    if mode ~= "Rows" and mode ~= "Scroll" then return mkSegmented(parent,pos,size,options,init,ac,onChange) end
    unscale = unscale or function(px) return px end
    local f = Instance.new("Frame"); f.Size = size; f.Position = pos; f.BorderSizePixel = 0; f.Parent = parent
    local cur = init; local btns = {}; local obj = {}
    if mode == "Scroll" then f.BackgroundColor3 = C.pHdr; corner(8,f); stroke(C.border,1,f) else f.BackgroundTransparency = 1 end
    local function paint()
        for name,b in pairs(btns) do
            local on = (name == cur)
            tw(b,{BackgroundColor3 = on and ac or C.pHdr, TextColor3 = on and Color3.new(1,1,1) or C.dim},.15)
        end
    end
    local function mkBtn(name, host)
        local b = Instance.new("TextButton"); b.BackgroundColor3 = C.pHdr; b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Text = tostring(name)
        b.Font = GB; b.TextSize = 11; b.TextColor3 = C.dim; b.Parent = host; corner(6,b)
        btns[name] = b
        b.MouseButton1Click:Connect(function()
            if cur == name then return end
            cur = name; paint()
            if obj.reveal then obj.reveal(name) end
            if onChange then onChange(name) end
        end)
        return b
    end
    if mode == "Rows" then
        local GAP, BH = 4, 26
        local n = #options; local c = math.max(cols or 3, 1)
        local idx, r = 1, 0
        while idx <= n do
            local k = math.min(c, n - idx + 1) -- последняя строка растягивается на всю ширину
            for j = 1,k do
                local b = mkBtn(options[idx + j - 1], f)
                b.Size = UDim2.new(1 / k, -GAP * (k - 1) / k, 0, BH)
                b.Position = UDim2.new((j - 1) / k, (j - 1) * GAP / k, 0, 2 + r * (BH + GAP))
                b.TextScaled = true
                local tc = Instance.new("UITextSizeConstraint"); tc.MaxTextSize = 11; tc.MinTextSize = 7; tc.Parent = b
            end
            idx = idx + k; r = r + 1
        end
    else
        local sc = Instance.new("ScrollingFrame"); sc.Size = UDim2.new(1,-4,1,-4); sc.Position = UDim2.new(0,2,0,2); sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0
        sc.ScrollBarThickness = 0; sc.ScrollingDirection = Enum.ScrollingDirection.X; sc.CanvasSize = UDim2.new(0,0,0,0)
        sc.ElasticBehavior = Enum.ElasticBehavior.Never; sc.Parent = f
        local lay = Instance.new("UIListLayout"); lay.FillDirection = Enum.FillDirection.Horizontal; lay.Padding = UDim.new(0,4); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = sc
        for i,name in ipairs(options) do
            local b = mkBtn(name, sc); b.LayoutOrder = i
            local okm,bm = pcall(function() return TextService:GetTextSize(tostring(name), 11, GB, Vector2.new(240,30)) end)
            b.Size = UDim2.new(0, math.max(52, math.ceil(okm and bm.X or (#tostring(name) * 7)) + 24), 1, 0)
        end
        local function arrow(left)
            local a = Instance.new("TextButton"); a.Size = UDim2.new(0,24,1,-4); a.Position = left and UDim2.new(0,2,0,2) or UDim2.new(1,-26,0,2)
            a.BackgroundColor3 = C.pHdr; a.BorderSizePixel = 0; a.Text = ""; a.AutoButtonColor = false; a.ZIndex = 6; a.Visible = false; a.Parent = f; corner(6,a)
            local g = Instance.new("UIGradient")
            g.Transparency = NumberSequence.new(left
                and {NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(0.6,0.12), NumberSequenceKeypoint.new(1,1)}
                or {NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.4,0.12), NumberSequenceKeypoint.new(1,0)})
            g.Parent = a
            for k = 1,2 do -- шеврон рисуется фреймами
                local ln = Instance.new("Frame"); ln.AnchorPoint = Vector2.new(0.5,0.5); ln.Size = UDim2.new(0,7,0,2); ln.BackgroundColor3 = C.txt; ln.BorderSizePixel = 0; ln.ZIndex = 7
                ln.Position = UDim2.new(0.5, left and -3 or 3, 0.5, (k == 1) and -3 or 3)
                ln.Rotation = ((k == 1) == (not left)) and 45 or -45; ln.Parent = a; corner(1,ln)
            end
            return a
        end
        local aL, aR = arrow(true), arrow(false)
        local function win() return unscale(sc.AbsoluteWindowSize.X) end
        local function total() return unscale(lay.AbsoluteContentSize.X) end
        local function upd()
            sc.CanvasSize = UDim2.new(0, total(), 0, 0)
            local x = sc.CanvasPosition.X
            aL.Visible = x > 2; aR.Visible = x + win() < total() - 2
        end
        local function scrollTo(x)
            x = math.clamp(x, 0, math.max(0, total() - win()))
            createTween(sc, TweenInfo.new(.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new(x,0)}):Play()
        end
        lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(upd)
        sc:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(upd)
        sc:GetPropertyChangedSignal("CanvasPosition"):Connect(upd)
        aL.MouseButton1Click:Connect(function() scrollTo(sc.CanvasPosition.X - 120) end)
        aR.MouseButton1Click:Connect(function() scrollTo(sc.CanvasPosition.X + 120) end)
        sc.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseWheel then scrollTo(sc.CanvasPosition.X - i.Position.Z * 80) end
        end)
        function obj.reveal(name) -- активная страница всегда в центре ленты
            local b = btns[name]; if not b then return end
            local rel = unscale(b.AbsolutePosition.X - sc.AbsolutePosition.X) + sc.CanvasPosition.X
            scrollTo(rel - win() / 2 + unscale(b.AbsoluteSize.X) / 2)
        end
        trackedDefer(upd)
    end
    paint()
    function obj.Set(v,silent) if btns[v] then cur = v; paint(); if obj.reveal then obj.reveal(v) end; if not silent and onChange then onChange(v) end end end
    function obj.Get() return cur end
    return obj
end
local function attachLockHidden(row,o)
    o = o or {}
    if o.Hidden then row.Visible = false end
    local locked = false
    local overlay
    local function build()
        if overlay then return end
        overlay = Instance.new("Frame"); overlay.Size = UDim2.new(1,0,1,0); overlay.BackgroundColor3 = Color3.new(0,0,0)
        overlay.BackgroundTransparency = 0.5; overlay.BorderSizePixel = 0; overlay.ZIndex = 50; overlay.Visible = false; overlay.Parent = row
        corner(7,overlay)
        local blocker = Instance.new("TextButton"); blocker.Size = UDim2.new(1,0,1,0); blocker.BackgroundTransparency = 1; blocker.Text = ""; blocker.ZIndex = 51; blocker.Parent = overlay
        blocker.MouseButton1Click:Connect(function()
            local msg = o.LockedMessage or (o.Requires and ("Requires " .. o.Requires))
            if msg then JL:Notify({Title = o.LockedTitle or "Locked", Desc = msg, Type = "Warn", Duration = 3}) end
            if o.Requires and o.OpenStore ~= false and JL.OpenSubscriptions then JL:OpenSubscriptions() end
        end)
        local badge = Instance.new("Frame"); badge.Size = UDim2.new(0,22,0,22); badge.AnchorPoint = Vector2.new(1,0.5); badge.Position = UDim2.new(1,-6,0.5,0)
        badge.BackgroundColor3 = Color3.fromRGB(40,40,44); badge.BorderSizePixel = 0; badge.ZIndex = 52; badge.Parent = overlay; corner(11,badge); stroke(Color3.fromRGB(90,90,98),1,badge)
        if JL._iconPack then
            local ic = mkIcon(badge, o.LockIcon or "lock", 13, 53)
            ic.AnchorPoint = Vector2.new(0.5,0.5); ic.Position = UDim2.new(0.5,0,0.5,0)
            if ic:IsA("TextLabel") then ic.TextColor3 = Color3.new(1,1,1) else ic.ImageColor3 = Color3.new(1,1,1) end
        else
            local body = Instance.new("Frame"); body.Size = UDim2.new(0,10,0,8); body.AnchorPoint = Vector2.new(0.5,0.5); body.Position = UDim2.new(0.5,0,0.5,3)
            body.BackgroundColor3 = Color3.new(1,1,1); body.BorderSizePixel = 0; body.ZIndex = 53; body.Parent = badge; corner(2,body)
            local ring = Instance.new("Frame"); ring.Size = UDim2.new(0,7,0,7); ring.AnchorPoint = Vector2.new(0.5,1); ring.Position = UDim2.new(0.5,0,0.5,0)
            ring.BackgroundTransparency = 1; ring.ZIndex = 52; ring.Parent = badge; corner(4,ring); stroke(Color3.new(1,1,1),1.5,ring)
        end
    end
    local function setLocked(v)
        locked = v
        if v then build(); overlay.Visible = true elseif overlay then overlay.Visible = false end
    end
    local function setHidden(v) row.Visible = not v end
    if o.Locked then setLocked(true) end
    if o.Requires or o.HiddenUntil then
        local function evalTier()
            if o.Requires then setLocked(not JL:HasTier(o.Requires)) end
            if o.HiddenUntil then setHidden(not JL:HasTier(o.HiddenUntil)) end
        end
        evalTier(); JL:OnTierChanged(evalTier)
    end
    return {
        SetLocked = function(_,v) setLocked(v) end,
        SetHidden = function(_,v) setHidden(v) end,
        ToggleLocked = function() setLocked(not locked); return locked end,
        ToggleHidden = function() setHidden(row.Visible); return not row.Visible end,
        IsLocked = function() return locked end,
        IsHidden = function() return not row.Visible end,
    }
end
local function keyFromName(n)
    if not n or n == "None" then return nil end
    local ok,k = pcall(function() return Enum.KeyCode[n] end)
    if ok then return k end
    return nil
end
local function shortKey(k)
    if not k then return "None" end
    local n = k.Name
    n = n:gsub("Left","L"):gsub("Right","R"):gsub("Control","Ctrl"):gsub("Return","Enter")
    return n
end
local function mkKeyChip(parent,pos,initName,onSet)
    local key = keyFromName(initName); local capturing = false
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0,84,0,22); btn.Position = pos; btn.BackgroundColor3 = C.pHdr; btn.BorderSizePixel = 0
    btn.AutoButtonColor = false; btn.Font = GB; btn.TextSize = 11; btn.TextColor3 = C.txt; btn.Text = shortKey(key); btn.Parent = parent; corner(6,btn)
    local st = stroke(C.border,1,btn)
    btn.MouseButton1Click:Connect(function()
        capturing = true; JL._listening = true; btn.Text = "press a key..."; st.Color = ACCENTS[1]
    end)
    keep(UIS.InputBegan:Connect(function(i)
        if not capturing or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        capturing = false; st.Color = C.border
        trackedDefer(function() JL._listening = false end)
        if i.KeyCode == Enum.KeyCode.Escape then btn.Text = shortKey(key); return end
        if i.KeyCode == Enum.KeyCode.Backspace then key = nil else key = i.KeyCode end
        btn.Text = shortKey(key); if onSet then onSet(key) end
    end))
    local obj = {Btn = btn}
    function obj.Get() return key end
    function obj.Set(k) key = k; btn.Text = shortKey(k) end
    return obj
end
local _cpSg = nil
local function ensureCpSg(sg)
    if not _cpSg or not _cpSg.Parent then
        _cpSg = Instance.new("Frame"); _cpSg.Size = UDim2.new(1,0,1,0); _cpSg.BackgroundColor3 = Color3.new(0,0,0)
        _cpSg.BackgroundTransparency = 0.5; _cpSg.BorderSizePixel = 0; _cpSg.ZIndex = 200; _cpSg.Active = true; _cpSg.Visible = false; _cpSg.Parent = sg
        local bd = _cpSg
        bd.InputBegan:Connect(function(i)
            if not isPtr(i) then return end
            local card = bd:FindFirstChild("Card"); if not card then bd.Visible = false; return end
            local pos = Vector2.new(i.Position.X, i.Position.Y); local cp = card.AbsolutePosition; local cs = card.AbsoluteSize
            if pos.X < cp.X or pos.X > cp.X + cs.X or pos.Y < cp.Y or pos.Y > cp.Y + cs.Y then bd.Visible = false end
        end)
    end
    return _cpSg
end
local function openColorPicker(sg,currentColor,callback)
    local bd = ensureCpSg(sg); bd.Visible = true
    local old = bd:FindFirstChild("Card"); if old then old:Destroy() end
    local h,s,v = Color3.toHSV(currentColor)
    local card = Instance.new("Frame"); card.Name = "Card"; card.Size = UDim2.new(0,260,0,332); card.Position = UDim2.new(0.5,-130,0.5,-166)
    card.BackgroundColor3 = C.panel; card.BorderSizePixel = 0; card.Active = true; card.Parent = bd; corner(12,card); stroke(C.border,1,card)
    local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,34); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = card; corner(12,hdr)
    local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    newTxt({Parent=hdr,Text="Color Picker",Font=GB,Size=13,Sz=UDim2.new(1,-90,1,0),Pos=UDim2.new(0,12,0,0)})
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0,24,0,24); closeBtn.Position = UDim2.new(1,-30,0.5,-12); closeBtn.BackgroundColor3 = C.danger
    closeBtn.Text = "✕"; closeBtn.Font = GB; closeBtn.TextSize = 12; closeBtn.TextColor3 = Color3.new(1,1,1); closeBtn.ZIndex = 5; closeBtn.Parent = hdr; corner(7,closeBtn)
    closeBtn.MouseButton1Click:Connect(function() bd.Visible = false end)
    draggable(hdr,card)
    local preview = Instance.new("Frame"); preview.Size = UDim2.new(0,28,0,20); preview.Position = UDim2.new(1,-66,0.5,-10); preview.BackgroundColor3 = currentColor; preview.BorderSizePixel = 0; preview.ZIndex = 5; preview.Parent = hdr; corner(5,preview); stroke(C.border,1,preview)
    local svBg = Instance.new("Frame"); svBg.Size = UDim2.new(1,-20,0,130); svBg.Position = UDim2.new(0,10,0,44); svBg.BackgroundColor3 = Color3.fromHSV(h,1,1); svBg.BorderSizePixel = 0; svBg.Parent = card; corner(6,svBg)
    local svSat = Instance.new("Frame"); svSat.Size = UDim2.new(1,0,1,0); svSat.BackgroundColor3 = Color3.new(1,1,1); svSat.BorderSizePixel = 0; svSat.ZIndex = 2; svSat.Parent = svBg; corner(6,svSat)
    local g1 = Instance.new("UIGradient"); g1.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}); g1.Parent = svSat
    local svVal = Instance.new("Frame"); svVal.Size = UDim2.new(1,0,1,0); svVal.BackgroundColor3 = Color3.new(0,0,0); svVal.BorderSizePixel = 0; svVal.ZIndex = 3; svVal.Parent = svBg; corner(6,svVal)
    local g2 = Instance.new("UIGradient"); g2.Rotation = 90; g2.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}); g2.Parent = svVal
    local svCursor = Instance.new("Frame"); svCursor.Size = UDim2.new(0,12,0,12); svCursor.BackgroundTransparency = 1; svCursor.ZIndex = 4; svCursor.Parent = svBg; corner(6,svCursor); stroke(Color3.new(1,1,1),2,svCursor)
    local svHit = Instance.new("TextButton"); svHit.Size = UDim2.new(1,0,1,0); svHit.BackgroundTransparency = 1; svHit.Text = ""; svHit.ZIndex = 5; svHit.Parent = svBg
    local hueBar = Instance.new("Frame"); hueBar.Size = UDim2.new(1,-20,0,12); hueBar.Position = UDim2.new(0,10,0,184); hueBar.BackgroundColor3 = Color3.new(1,1,1); hueBar.BorderSizePixel = 0; hueBar.Parent = card; corner(5,hueBar)
    local hueG = Instance.new("UIGradient"); hueG.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.167,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(0.333,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.667,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.833,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))}); hueG.Parent = hueBar
    local hueCursor = Instance.new("Frame"); hueCursor.Size = UDim2.new(0,8,1,6); hueCursor.BackgroundColor3 = Color3.new(1,1,1); hueCursor.BorderSizePixel = 0; hueCursor.ZIndex = 2; hueCursor.Parent = hueBar; corner(3,hueCursor); stroke(Color3.new(0,0,0),1,hueCursor)
    local hueHit = Instance.new("TextButton"); hueHit.Size = UDim2.new(1,0,1,8); hueHit.Position = UDim2.new(0,0,0,-4); hueHit.BackgroundTransparency = 1; hueHit.Text = ""; hueHit.ZIndex = 3; hueHit.Parent = hueBar
    local rgbBars = {}; local rgbVals = {}
    local hexBox
    local commit
    local chanCols = {Color3.fromRGB(255,90,90), Color3.fromRGB(90,220,120), Color3.fromRGB(90,150,255)}
    local function rgbChanged()
        local col = Color3.fromRGB(rgbBars[1].Get(), rgbBars[2].Get(), rgbBars[3].Get())
        h,s,v = Color3.toHSV(col)
    end
    for idx,lab in ipairs({"R","G","B"}) do
        local row = Instance.new("Frame"); row.Size = UDim2.new(1,-20,0,22); row.Position = UDim2.new(0,10,0,206 + (idx-1)*26); row.BackgroundTransparency = 1; row.Parent = card
        newTxt({Parent=row,Text=lab,Font=GB,Size=11,Color=C.dim,Sz=UDim2.new(0,14,1,0)})
        rgbVals[idx] = newTxt({Parent=row,Text="0",Font=GB,Size=11,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,34,1,0),Pos=UDim2.new(1,-34,0,0)})
        local col0 = Color3.fromHSV(h,s,v); local ch0 = (idx == 1 and col0.R) or (idx == 2 and col0.G) or col0.B
        rgbBars[idx] = mkSliderBar(row, UDim2.new(0,26,0.5,-3), UDim2.new(1,-72,0,6), chanCols[idx], 0, 255, 1, math.round(ch0 * 255), function()
            rgbChanged(); commit(idx)
        end)
    end
    local hexRow = Instance.new("Frame"); hexRow.Size = UDim2.new(1,-20,0,26); hexRow.Position = UDim2.new(0,10,0,292); hexRow.BackgroundTransparency = 1; hexRow.Parent = card
    newTxt({Parent=hexRow,Text="HEX",Font=GB,Size=11,Color=C.dim,Sz=UDim2.new(0,34,1,0)})
    hexBox = Instance.new("TextBox"); hexBox.Size = UDim2.new(1,-40,1,0); hexBox.Position = UDim2.new(0,40,0,0); hexBox.BackgroundColor3 = C.pHdr; hexBox.BorderSizePixel = 0
    hexBox.Font = GB; hexBox.TextSize = 12; hexBox.TextColor3 = C.txt; hexBox.ClearTextOnFocus = false; hexBox.Text = ""; hexBox.Parent = hexRow; corner(6,hexBox); stroke(C.border,1,hexBox)
    commit = function(srcIdx)
        local col = Color3.fromHSV(h,s,v)
        preview.BackgroundColor3 = col; svBg.BackgroundColor3 = Color3.fromHSV(h,1,1)
        svCursor.Position = UDim2.new(s,-6,1-v,-6); hueCursor.Position = UDim2.new(h,-4,0,-3)
        local chs = {col.R, col.G, col.B}
        for i = 1,3 do
            local n = math.round(chs[i] * 255)
            if i ~= srcIdx then rgbBars[i].Set(n, true) end
            rgbVals[i].Text = tostring(n)
        end
        local okh,hx = pcall(function() return col:ToHex() end)
        if okh and hexBox and not hexBox:IsFocused() then hexBox.Text = "#" .. hx:upper() end
        if callback then callback(col) end
    end
    hexBox.FocusLost:Connect(function()
        local t = hexBox.Text:gsub("#",""):gsub("%s","")
        if #t == 6 then
            local ok,c3 = pcall(function() return Color3.fromHex(t) end)
            if ok and c3 then h,s,v = Color3.toHSV(c3) end
        end
        commit(0)
    end)
    local function svFrom(i)
        local ap,as = svBg.AbsolutePosition, svBg.AbsoluteSize
        s = math.clamp((i.Position.X - ap.X) / as.X, 0, 1); v = math.clamp(1 - (i.Position.Y - ap.Y) / as.Y, 0, 1); commit(0)
    end
    svHit.InputBegan:Connect(function(i) if isPtr(i) then svFrom(i); beginDrag(svFrom) end end)
    local function hueFrom(i)
        local ap,as = hueBar.AbsolutePosition, hueBar.AbsoluteSize
        h = math.clamp((i.Position.X - ap.X) / as.X, 0, 1); commit(0)
    end
    hueHit.InputBegan:Connect(function(i) if isPtr(i) then hueFrom(i); beginDrag(hueFrom) end end)
    local cb0 = callback; callback = nil; commit(0); callback = cb0
end
local function compactWidth(cfg)
    if not cfg then return 0 end
    local t = cfg.Type or "Toggle"
    if t == "Toggle" then return 34
    elseif t == "ColorPicker" then return 30
    elseif t == "Keybind" then return 84
    elseif t == "Button" then return cfg.Width or 78
    elseif t == "Slider" then return cfg.Width or 96
    elseif t == "Segmented" then return cfg.Width or 110
    end
    return 0
end
local function mkCompactControl(parent,x,w,cfg,ac,regFlag,parentSg)
    cfg = cfg or {}
    local t = cfg.Type or "Toggle"
    if t == "Toggle" then
        local had = cfgHas(cfg.Flag); local state = cfgGet(cfg.Flag, cfg.Default or false)
        local sw = mkSwitch(parent, UDim2.new(0,x,0.5,-9), state, ac)
        local hit = Instance.new("TextButton"); hit.Size = UDim2.new(0,34,0,22); hit.Position = UDim2.new(0,x,0.5,-11); hit.BackgroundTransparency = 1; hit.Text = ""; hit.Parent = parent
        hit.MouseButton1Click:Connect(function()
            state = not state; sw.Set(state); cfgSet(cfg.Flag, state)
            if cfg.Callback then pcall(cfg.Callback, state) end
        end)
        if cfg.Callback and had then pcall(cfg.Callback, state) end
        local ret = {Set = function(_,v) state = v; sw.Set(v); cfgSet(cfg.Flag, v) end, Get = function() return state end}
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "ColorPicker" then
        local had = cfgHas(cfg.Flag)
        local cur = cfgGet(cfg.Flag, cfg.Default or Color3.fromRGB(255,255,255))
        if type(cur) == "table" then cur = Color3.fromRGB(cur[1] or 255, cur[2] or 255, cur[3] or 255) end
        if cfg.Flag then JL.Flags[cfg.Flag] = cur end
        local sw = Instance.new("TextButton"); sw.Size = UDim2.new(0,30,0,20); sw.Position = UDim2.new(0,x,0.5,-10); sw.BackgroundColor3 = cur; sw.AutoButtonColor = false; sw.Text = ""; sw.BorderSizePixel = 0; sw.Parent = parent
        corner(6,sw); stroke(C.border,1,sw); sw:SetAttribute("JLNoRepaint", true)
        sw.MouseButton1Click:Connect(function()
            openColorPicker(parentSg, cur, function(col)
                cur = col; sw.BackgroundColor3 = col
                cfgSet(cfg.Flag, col, {math.round(col.R * 255), math.round(col.G * 255), math.round(col.B * 255)})
                if cfg.Callback then pcall(cfg.Callback, col) end
            end)
        end)
        if cfg.Callback and had then pcall(cfg.Callback, cur) end
        local ret = {Get = function() return cur end, Set = function(_,v) cur = v; sw.BackgroundColor3 = v end}
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "Keybind" then
        local defName = (typeof(cfg.Default) == "EnumItem" and cfg.Default.Name) or (cfg.Default and tostring(cfg.Default)) or "None"
        local nm = cfgGet(cfg.Flag, defName)
        local chip = mkKeyChip(parent, UDim2.new(0,x,0.5,-11), nm, function(k)
            cfgSet(cfg.Flag, k and k.Name or "None"); if cfg.Callback then pcall(cfg.Callback, k) end
        end)
        local ret = {Get = function() return chip.Get() end, Set = function(_,k) chip.Set(k); cfgSet(cfg.Flag, k and k.Name or "None") end}
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "Slider" then
        local vmin = cfg.Min or 0; local vmax = cfg.Max or 100; local step = cfg.Step or 1; local dec = decimalsOf(step); local suffix = cfg.Suffix or ""
        local had = cfgHas(cfg.Flag)
        local val = snap(tonumber(cfgGet(cfg.Flag, cfg.Default or vmin)) or vmin, vmin, vmax, step)
        local valL = newTxt({Parent=parent,Text=fmtNum(val,dec) .. suffix,Font=GB,Size=10,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,w,0,12),Pos=UDim2.new(0,x,0.5,-17)})
        local bar = mkSliderBar(parent, UDim2.new(0,x,0.5,0), UDim2.new(0,w,0,6), ac, vmin, vmax, step, val, function(v)
            val = v; valL.Text = fmtNum(v,dec) .. suffix; cfgSet(cfg.Flag, v)
            if cfg.Callback then pcall(cfg.Callback, v) end
        end)
        if cfg.Callback and had then pcall(cfg.Callback, val) end
        local ret = {
            Get = function() return val end,
            Set = function(_,v) bar.Set(v, true); val = bar.Get(); valL.Text = fmtNum(val,dec) .. suffix; cfgSet(cfg.Flag, val) end,
        }
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "Segmented" then
        local opts2 = cfg.Options or {}; local had = cfgHas(cfg.Flag)
        local cur = cfgGet(cfg.Flag, cfg.Default or opts2[1])
        local seg = mkSegmented(parent, UDim2.new(0,x,0.5,-12), UDim2.new(0,w,0,24), opts2, cur, ac, function(v)
            cfgSet(cfg.Flag, v); if cfg.Callback then pcall(cfg.Callback, v) end
        end)
        if cfg.Callback and had then pcall(cfg.Callback, cur) end
        local ret = {Get = seg.Get, Set = function(_,v) seg.Set(v, true); cfgSet(cfg.Flag, v) end}
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "Button" then
        local b = Instance.new("TextButton"); b.Size = UDim2.new(0,w,0,26); b.Position = UDim2.new(0,x,0.5,-13); b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.AutoButtonColor = false
        b.Text = cfg.Name or "Button"; b.Font = GB; b.TextSize = 11; b.TextColor3 = C.txt; b.TextWrapped = true; b.Parent = parent
        corner(6,b); stroke(C.border,1,b)
        b.MouseEnter:Connect(function()
            if touchLast() then return end
            b:SetAttribute("JLHover", true); tw(b,{BackgroundColor3 = C.btnHov},.1)
        end)
        b.MouseLeave:Connect(function() b:SetAttribute("JLHover", false); tw(b,{BackgroundColor3 = C.btnBg},.1) end)
        b.MouseButton1Click:Connect(function()
            local fl = (b:GetAttribute("JLFlash") or 0) + 1; b:SetAttribute("JLFlash", fl)
            tw(b,{BackgroundColor3 = ac},.06)
            trackedDelay(.14, function()
                if b:GetAttribute("JLFlash") ~= fl then return end
                tw(b,{BackgroundColor3 = b:GetAttribute("JLHover") and C.btnHov or C.btnBg},.12)
            end)
            if cfg.Callback then pcall(cfg.Callback) end
        end)
        return {Instance = b}
    end
    return {}
end
