local JL = {}; JL.Flags = {}; JL._winOpen = false; JL._listening = false; JL.Version = "4.4.15"
JL._registry = {}; JL._noSave = {}

local Workspace = createWorkspaceModule({
    Shared = shared,
    ReadFile = readfile,
    WriteFile = writefile,
    IsFolder = isfolder,
    MakeFolder = makefolder,
    LoadString = loadstring,
})
local _workspace = Workspace.Workspace
local saveWorkspaceSettings = Workspace.SaveSettings
local resolveHubIdentity = Workspace.ResolveHubIdentity
local scopedGuiName = Workspace.ScopedGuiName
local registerHubGui = Workspace.RegisterGui
local _hubGuiRoots = Workspace.GuiRoots
local TS          = game:GetService("TweenService")
local UIS         = game:GetService("UserInputService")
local HTTP        = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RunSvc      = game:GetService("RunService")
local LP          = game:GetService("Players").LocalPlayer
local PG          = LP:WaitForChild("PlayerGui")
local GB = Enum.Font.GothamBold
local GM = Enum.Font.GothamMedium
local G  = Enum.Font.Gotham
local C = {
    panel   = Color3.fromRGB(40,40,44),   pHdr    = Color3.fromRGB(31,31,35),
    border  = Color3.fromRGB(66,66,72),   txt     = Color3.fromRGB(240,240,242),
    dim     = Color3.fromRGB(150,150,158),togOn   = Color3.fromRGB(46,204,113),
    togOff  = Color3.fromRGB(28,28,32),   slTrack = Color3.fromRGB(58,58,64),
    btnBg   = Color3.fromRGB(50,50,55),   btnHov  = Color3.fromRGB(66,66,73),
    sidebar = Color3.fromRGB(28,28,31),   fpsGrn  = Color3.fromRGB(72,214,92),
    badge   = Color3.fromRGB(33,33,37),   badgeHi = Color3.fromRGB(50,60,90),
    divLine = Color3.fromRGB(70,70,76),   input   = Color3.fromRGB(50,50,55),
    danger  = Color3.fromRGB(200,68,68),  backdrop= Color3.fromRGB(16,16,18),
}
local ACCENTS = {
    Color3.fromRGB(82,152,255), Color3.fromRGB(148,92,255),
    Color3.fromRGB(72,198,138), Color3.fromRGB(255,132,72),
    Color3.fromRGB(255,72,108), Color3.fromRGB(72,208,208),
}
local _ai = 0
local function nxAc() _ai = _ai + 1; return ACCENTS[((_ai - 1) % #ACCENTS) + 1] end
local _conns = {}
local _resources = {}
local _threads = {}
local _disposed = false
local function cleanupResource(resource, cleanup)
    pcall(function()
        if cleanup then cleanup(resource); return end
        local kind = typeof(resource)
        if kind == "RBXScriptConnection" then resource:Disconnect()
        elseif kind == "Instance" then resource:Destroy()
        elseif kind == "thread" then task.cancel(resource)
        elseif type(resource) == "function" then resource()
        elseif type(resource) == "table" then
            if resource.Destroy then resource:Destroy()
            elseif resource.Disconnect then resource:Disconnect()
            elseif resource.Cancel then resource:Cancel() end
        end
    end)
end
local function trackedRunner(record, callback)
    return function(...)
        if _disposed then _threads[record] = nil; return end
        local result = table.pack(pcall(callback, ...))
        _threads[record] = nil
        if not result[1] then error(result[2], 0) end
        return table.unpack(result, 2, result.n)
    end
end
local function trackedSpawn(callback, ...)
    if _disposed then return nil end
    local record = {}; _threads[record] = true
    record.thread = task.spawn(trackedRunner(record, callback), ...)
    return record.thread
end
local function trackedDelay(seconds, callback, ...)
    if _disposed then return nil end
    local record = {}; _threads[record] = true
    record.thread = task.delay(seconds, trackedRunner(record, callback), ...)
    return record.thread
end
local function trackedDefer(callback, ...)
    if _disposed then return nil end
    local record = {}; _threads[record] = true
    record.thread = task.defer(trackedRunner(record, callback), ...)
    return record.thread
end
local function cleanupResources()
    for record in pairs(_tweens) do
        _tweens[record] = nil
        if record.connection then pcall(function() record.connection:Disconnect() end) end
        if record.tween then
            pcall(function() record.tween:Cancel() end)
            pcall(function() record.tween:Destroy() end)
        end
    end
    for record in pairs(_threads) do
        if record.thread then pcall(task.cancel, record.thread) end
        _threads[record] = nil
    end
    for i = #_resources, 1, -1 do
        local item = _resources[i]
        _resources[i] = nil
        if item then pcall(cleanupResource, item.resource, item.cleanup) end
    end
end
local function keep(c) if c then _conns[#_conns + 1] = c end; return c end
function JL:Track(resource, cleanup)
    if resource == nil then return nil end
    if _disposed then cleanupResource(resource, cleanup); return resource end
    _resources[#_resources + 1] = {resource = resource, cleanup = cleanup}
    return resource
end
function JL:Connect(signal, callback)
    if _disposed then return nil end
    return keep(signal:Connect(callback))
end
function JL:Spawn(callback, ...)
    return trackedSpawn(callback, ...)
end
function JL:Delay(seconds, callback, ...)
    return trackedDelay(seconds, callback, ...)
end
function JL:Defer(callback, ...)
    return trackedDefer(callback, ...)
end
function JL:OnUnload(callback)
    if type(callback) ~= "function" then return false end
    if _disposed then pcall(callback); return false end
    self._unloadHooks[#self._unloadHooks + 1] = callback
    return true
end
function JL:IsAlive() return not _disposed end
function JL:GetCleanupStats()
    local connections, threads = 0, 0
    for _,connection in ipairs(_conns) do
        if connection and connection.Connected then connections = connections + 1 end
    end
    for _ in pairs(_threads) do threads = threads + 1 end
    return {Connections = connections, Threads = threads, Resources = #_resources, Alive = not _disposed}
end
local function touchLast() return UIS:GetLastInputType() == Enum.UserInputType.Touch end
local _tweens = {}
local function createTween(...)
    local tween = TS:Create(...)
    local record = {tween = tween}
    _tweens[record] = true
    record.connection = tween.Completed:Connect(function()
        _tweens[record] = nil
        if record.connection then pcall(function() record.connection:Disconnect() end) end
    end)
    return tween
end
local function tw(o,p,t,s,d)
    createTween(o, TweenInfo.new(t or .2, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p):Play()
end
local function corner(r,p) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r); c.Parent = p; return c end
local function stroke(col,t,p) local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = t; s.Parent = p; return s end
local function pad(l,r,t,b,p)
    local u = Instance.new("UIPadding")
    u.PaddingLeft = UDim.new(0,l); u.PaddingRight = UDim.new(0,r); u.PaddingTop = UDim.new(0,t); u.PaddingBottom = UDim.new(0,b)
    u.Parent = p; return u
end
local function newTxt(props)
    local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.BorderSizePixel = 0
    l.Font = props.Font or G; l.TextSize = props.Size or 11
    l.TextColor3 = props.Color or C.txt; l.Text = props.Text or ""
    l.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd; l.ZIndex = props.Z or 17
    if props.Wrap then l.TextWrapped = true; l.TextTruncate = Enum.TextTruncate.None end
    l.Size = props.Sz or UDim2.new(1,0,1,0); l.Position = props.Pos or UDim2.new(0,0,0,0)
    l.Parent = props.Parent; return l
end
local function fitH(text,size,font,w,minH,padV)
    local ok,b = pcall(function()
        return TextService:GetTextSize(tostring(text), size, font, Vector2.new(math.max(w,20), 10000))
    end)
    local th = ok and b.Y or (size + 2)
    return math.max(minH, th + padV)
end
local function isPtr(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function beginDrag(onMove,onEnd)
    local c1,c2
    c1 = keep(UIS.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then onMove(i) end
    end))
    c2 = keep(UIS.InputEnded:Connect(function(i)
        if isPtr(i) then c1:Disconnect(); c2:Disconnect(); if onEnd then onEnd() end end
    end))
end
local function draggable(handle,frame,onTap,onDragEnd)
    handle.InputBegan:Connect(function(i)
        if not isPtr(i) then return end
        local ds = Vector2.new(i.Position.X, i.Position.Y); local sp = frame.Position; local moved = false
        beginDrag(function(m)
            local d = Vector2.new(m.Position.X, m.Position.Y) - ds
            if d.Magnitude > 8 then moved = true end
            if moved then frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end
        end, function()
            if moved and onDragEnd then onDragEnd(frame.Position)
            elseif not moved and onTap then onTap() end
        end)
    end)
end
local Icons = createIconsModule({
    JL = JL,
    BoldFont = GB,
    Colors = C,
    Instance = Instance,
    Enum = Enum,
    UDim2 = UDim2,
    Vector2 = Vector2,
    Typeof = typeof,
    Game = game,
    LoadString = loadstring
})
local mkIcon = Icons.Make
local Backgrounds = createBackgroundsModule({
    JL = JL,
    Enum = Enum,
    Instance = Instance,
    UDim2 = UDim2,
    Color3 = Color3,
    Vector2 = Vector2,
    Task = task,
    Clock = os.clock,
    Math = math,
    TrackedSpawn = trackedSpawn,
    Corner = corner
})
local BG = Backgrounds.BG
local GUIDE = {pulses = {}, active = nil}
JL._secPanels = setmetatable({}, {__mode = "k"})
JL._searchPageTargets = {}
function GUIDE.targetOf(n)
    if n.Target then return n.Target end
    if n.Flag then return JL._registry[n.Flag] end
end
function GUIDE.met(n,base)
    local target = GUIDE.targetOf(n)
    if not target or not target.Get then return true end
    local v = target:Get()
    if n.Press then
        if base == nil then return false end
        return (tonumber(v) or 0) > base
    end
    if n.Check then
        local ok,res = pcall(n.Check, v)
        return (ok and res) and true or false
    end
    if n.State ~= nil then return v == n.State end
    return true
end
function GUIDE.stopPulse()
    for _,f in ipairs(GUIDE.pulses) do if f and f.Parent then f:Destroy() end end
    GUIDE.pulses = {}
end
function GUIDE.cancel() GUIDE.active = nil; GUIDE.stopPulse() end
function GUIDE.pulse(row,duration)
    local hl = Instance.new("Frame"); hl.Name = "JLGuideHL"; hl.Size = UDim2.new(1,0,1,0); hl.BackgroundColor3 = ACCENTS[1]; hl.BackgroundTransparency = 0.88
    hl.BorderSizePixel = 0; hl.ZIndex = 40; hl.Parent = row; corner(7,hl)
    hl:SetAttribute("JLNoRepaint", true)
    local st = stroke(ACCENTS[1], 2, hl); st:SetAttribute("JLNoRepaint", true)
    local info = TweenInfo.new(.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    createTween(hl, info, {BackgroundTransparency = 0.7}):Play()
    createTween(st, info, {Transparency = 0.75}):Play()
    GUIDE.pulses[#GUIDE.pulses + 1] = hl
    if duration and duration > 0 then trackedDelay(duration, function() if hl and hl.Parent then hl:Destroy() end end) end
    return hl
end
local function groupRules(o)
    if not o.Masters then return nil end
    local ml = o.Masters
    if type(ml) == "string" then ml = {ml} end
    local set = {}
    for _,m in ipairs(ml) do set[m] = true end
    return {list = ml, set = set, move = (o.Mode == "Move"), clear = o.ClearOthers ~= false}
end
function GUIDE.first(list,skip)
    for _,m in ipairs(list) do if m ~= skip and not GUIDE.met(m, nil) then return m end end
end
function GUIDE.start(src,n)
    GUIDE.cancel()
    local token = {}
    GUIDE.active = token
    trackedSpawn(function()
        local target = GUIDE.targetOf(n)
        local trow = target and target.Row
        local msg = n.Message or src.cfg.NeedsMessage
        if msg then JL:Notify({Title = n.Title or "Action required", Desc = msg, Type = "Warn", Duration = 3}) end
        if not (trow and trow.Parent) then GUIDE.active = nil; return end
        local base = n.Press and (tonumber(target:Get()) or 0) or nil
        if GUIDE.nav then GUIDE.nav(trow) end
        if GUIDE.active ~= token then return end
        GUIDE.pulse(trow)
        local t0 = os.clock()
        while GUIDE.active == token and os.clock() - t0 < (src.cfg.NeedsTimeout or 180) do
            if GUIDE.met(n, base) then break end
            task.wait(.15)
        end
        if GUIDE.active ~= token then return end
        GUIDE.stopPulse()
        if not GUIDE.met(n, base) then GUIDE.active = nil; return end
        local nxt = GUIDE.first(src.list, n)
        if nxt then GUIDE.start(src, nxt); return end
        GUIDE.active = nil
        if src.cfg.AutoReturn ~= false and src.row and src.row.Parent then
            task.wait(.25)
            if GUIDE.nav then GUIDE.nav(src.row) end
            GUIDE.pulse(src.row, 2.4)
        end
        if src.cfg.AutoApply and src.apply then src.apply() end
    end)
end
function GUIDE.block(o,row,apply)
    local list = o.Needs
    if list.Flag or list.Target then list = {list} end
    local first = GUIDE.first(list, nil)
    if not first then return false end
    GUIDE.start({row = row, cfg = o, list = list, apply = apply}, first)
    return true
end
JL._themes = {
    Midnight = {
        panel=Color3.fromRGB(40,40,44),    pHdr=Color3.fromRGB(31,31,35),
        border=Color3.fromRGB(66,66,72),   txt=Color3.fromRGB(240,240,242),
        dim=Color3.fromRGB(150,150,158),   togOn=Color3.fromRGB(46,204,113),
        togOff=Color3.fromRGB(28,28,32),   slTrack=Color3.fromRGB(58,58,64),
        btnBg=Color3.fromRGB(50,50,55),    btnHov=Color3.fromRGB(66,66,73),
        sidebar=Color3.fromRGB(28,28,31),  fpsGrn=Color3.fromRGB(72,214,92),
        badge=Color3.fromRGB(33,33,37),    badgeHi=Color3.fromRGB(50,60,90),
        divLine=Color3.fromRGB(70,70,76),  input=Color3.fromRGB(50,50,55),
        danger=Color3.fromRGB(200,68,68),  backdrop=Color3.fromRGB(16,16,18),
        accents={Color3.fromRGB(82,152,255),Color3.fromRGB(148,92,255),Color3.fromRGB(72,198,138),
                 Color3.fromRGB(255,132,72),Color3.fromRGB(255,72,108),Color3.fromRGB(72,208,208)},
    },
    Nord = {
        panel=Color3.fromRGB(46,52,64),    pHdr=Color3.fromRGB(38,43,53),
        border=Color3.fromRGB(76,86,106),  txt=Color3.fromRGB(236,239,244),
        dim=Color3.fromRGB(148,161,178),   togOn=Color3.fromRGB(163,190,140),
        togOff=Color3.fromRGB(30,34,42),   slTrack=Color3.fromRGB(59,66,82),
        btnBg=Color3.fromRGB(59,66,82),    btnHov=Color3.fromRGB(76,86,106),
        sidebar=Color3.fromRGB(36,41,51),  fpsGrn=Color3.fromRGB(163,190,140),
        badge=Color3.fromRGB(41,46,57),    badgeHi=Color3.fromRGB(59,81,108),
        divLine=Color3.fromRGB(76,86,106), input=Color3.fromRGB(59,66,82),
        danger=Color3.fromRGB(191,97,106), backdrop=Color3.fromRGB(22,25,31),
        accents={Color3.fromRGB(136,192,208),Color3.fromRGB(129,161,193),Color3.fromRGB(94,129,172),
                 Color3.fromRGB(163,190,140),Color3.fromRGB(235,203,139),Color3.fromRGB(180,142,173)},
    },
    Dracula = {
        panel=Color3.fromRGB(47,50,69),    pHdr=Color3.fromRGB(33,34,44),
        border=Color3.fromRGB(68,71,90),   txt=Color3.fromRGB(248,248,242),
        dim=Color3.fromRGB(98,114,164),    togOn=Color3.fromRGB(80,250,123),
        togOff=Color3.fromRGB(26,27,35),   slTrack=Color3.fromRGB(60,63,82),
        btnBg=Color3.fromRGB(58,61,80),    btnHov=Color3.fromRGB(74,77,98),
        sidebar=Color3.fromRGB(30,31,41),  fpsGrn=Color3.fromRGB(80,250,123),
        badge=Color3.fromRGB(36,37,48),    badgeHi=Color3.fromRGB(68,55,92),
        divLine=Color3.fromRGB(68,71,90),  input=Color3.fromRGB(58,61,80),
        danger=Color3.fromRGB(255,85,85),  backdrop=Color3.fromRGB(19,20,26),
        accents={Color3.fromRGB(255,121,198),Color3.fromRGB(189,147,249),Color3.fromRGB(80,250,123),
                 Color3.fromRGB(255,184,108),Color3.fromRGB(139,233,253),Color3.fromRGB(255,85,85)},
    },
    Emerald = {
        panel=Color3.fromRGB(24,36,30),    pHdr=Color3.fromRGB(17,27,22),
        border=Color3.fromRGB(45,71,58),   txt=Color3.fromRGB(228,242,234),
        dim=Color3.fromRGB(126,161,143),   togOn=Color3.fromRGB(52,211,153),
        togOff=Color3.fromRGB(14,22,18),   slTrack=Color3.fromRGB(37,58,48),
        btnBg=Color3.fromRGB(33,51,42),    btnHov=Color3.fromRGB(45,71,58),
        sidebar=Color3.fromRGB(16,25,21),  fpsGrn=Color3.fromRGB(74,222,128),
        badge=Color3.fromRGB(19,29,24),    badgeHi=Color3.fromRGB(24,64,48),
        divLine=Color3.fromRGB(45,71,58),  input=Color3.fromRGB(33,51,42),
        danger=Color3.fromRGB(220,90,90),  backdrop=Color3.fromRGB(9,15,12),
        accents={Color3.fromRGB(52,211,153),Color3.fromRGB(16,185,129),Color3.fromRGB(110,231,183),
                 Color3.fromRGB(251,191,36),Color3.fromRGB(34,211,238),Color3.fromRGB(163,230,182)},
    },
    Crimson = {
        panel=Color3.fromRGB(36,20,23),    pHdr=Color3.fromRGB(26,14,16),
        border=Color3.fromRGB(74,32,40),   txt=Color3.fromRGB(245,230,232),
        dim=Color3.fromRGB(166,122,128),   togOn=Color3.fromRGB(239,68,68),
        togOff=Color3.fromRGB(20,11,12),   slTrack=Color3.fromRGB(58,32,37),
        btnBg=Color3.fromRGB(48,27,31),    btnHov=Color3.fromRGB(74,32,40),
        sidebar=Color3.fromRGB(24,13,15),  fpsGrn=Color3.fromRGB(129,222,105),
        badge=Color3.fromRGB(28,16,18),    badgeHi=Color3.fromRGB(74,24,30),
        divLine=Color3.fromRGB(74,32,40),  input=Color3.fromRGB(48,27,31),
        danger=Color3.fromRGB(220,38,38),  backdrop=Color3.fromRGB(12,7,8),
        accents={Color3.fromRGB(239,68,68),Color3.fromRGB(248,113,113),Color3.fromRGB(251,146,60),
                 Color3.fromRGB(251,191,36),Color3.fromRGB(255,107,129),Color3.fromRGB(190,60,60)},
    },
    Cyberpunk = {
        panel=Color3.fromRGB(20,18,28),    pHdr=Color3.fromRGB(12,10,18),
        border=Color3.fromRGB(58,42,82),   txt=Color3.fromRGB(240,233,255),
        dim=Color3.fromRGB(139,122,168),   togOn=Color3.fromRGB(5,255,161),
        togOff=Color3.fromRGB(10,9,16),    slTrack=Color3.fromRGB(42,34,58),
        btnBg=Color3.fromRGB(34,28,48),    btnHov=Color3.fromRGB(58,42,82),
        sidebar=Color3.fromRGB(14,12,20),  fpsGrn=Color3.fromRGB(5,255,161),
        badge=Color3.fromRGB(17,14,24),    badgeHi=Color3.fromRGB(58,20,72),
        divLine=Color3.fromRGB(58,42,82),  input=Color3.fromRGB(34,28,48),
        danger=Color3.fromRGB(255,46,146), backdrop=Color3.fromRGB(8,6,13),
        accents={Color3.fromRGB(255,46,146),Color3.fromRGB(0,245,255),Color3.fromRGB(176,38,255),
                 Color3.fromRGB(255,225,86),Color3.fromRGB(5,255,161),Color3.fromRGB(255,110,199)},
    },
    Amoled = {
        panel=Color3.fromRGB(8,8,8),       pHdr=Color3.fromRGB(3,3,3),
        border=Color3.fromRGB(32,32,32),   txt=Color3.fromRGB(245,245,245),
        dim=Color3.fromRGB(140,140,140),   togOn=Color3.fromRGB(59,130,246),
        togOff=Color3.fromRGB(2,2,2),      slTrack=Color3.fromRGB(28,28,28),
        btnBg=Color3.fromRGB(18,18,18),    btnHov=Color3.fromRGB(32,32,32),
        sidebar=Color3.fromRGB(4,4,4),     fpsGrn=Color3.fromRGB(74,222,128),
        badge=Color3.fromRGB(5,5,5),       badgeHi=Color3.fromRGB(20,28,44),
        divLine=Color3.fromRGB(34,34,34),  input=Color3.fromRGB(18,18,18),
        danger=Color3.fromRGB(239,68,68),  backdrop=Color3.fromRGB(2,2,2),
        accents={Color3.fromRGB(59,130,246),Color3.fromRGB(168,85,247),Color3.fromRGB(16,185,129),
                 Color3.fromRGB(245,158,11),Color3.fromRGB(236,72,153),Color3.fromRGB(6,182,212)},
    },
    Daylight = {
        panel=Color3.fromRGB(252,252,253), pHdr=Color3.fromRGB(243,244,247),
        border=Color3.fromRGB(222,225,231),txt=Color3.fromRGB(28,30,36),
        dim=Color3.fromRGB(120,126,138),   togOn=Color3.fromRGB(34,197,94),
        togOff=Color3.fromRGB(214,217,224),slTrack=Color3.fromRGB(224,227,233),
        btnBg=Color3.fromRGB(240,241,245), btnHov=Color3.fromRGB(226,229,236),
        sidebar=Color3.fromRGB(246,247,250),fpsGrn=Color3.fromRGB(22,163,74),
        badge=Color3.fromRGB(252,252,253), badgeHi=Color3.fromRGB(223,232,255),
        divLine=Color3.fromRGB(222,225,231),input=Color3.fromRGB(240,241,245),
        danger=Color3.fromRGB(220,38,38),  backdrop=Color3.fromRGB(252,252,253),
        accents={Color3.fromRGB(37,99,235),Color3.fromRGB(124,58,237),Color3.fromRGB(5,150,105),
                 Color3.fromRGB(217,119,6),Color3.fromRGB(219,39,119),Color3.fromRGB(8,145,178)},
    },
}
JL._themeOrder = {"Midnight","Nord","Dracula","Emerald","Crimson","Cyberpunk","Amoled","Daylight"}
JL._currentTheme = "Midnight"
JL._userTheme = "Midnight"
JL._activeWin, JL._activeBadge = nil, nil
JL._noRepaintRoots = {}
local function walkRepaint(root,swap)
    local function excluded(obj)
        for _,r in ipairs(JL._noRepaintRoots) do
            if r and r.Parent and (obj == r or obj:IsDescendantOf(r)) then return true end
        end
        return false
    end
    local function paint(obj)
        if excluded(obj) then return end
        if obj:GetAttribute("JLNoRepaint") then return end
        pcall(function()
            if obj:IsA("UIStroke") then
                local nv = swap[obj.Color:ToHex()]; if nv then obj.Color = nv end
            elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                local nv = swap[obj.ImageColor3:ToHex()]; if nv then obj.ImageColor3 = nv end
                if obj.BackgroundTransparency < 1 then local nv2 = swap[obj.BackgroundColor3:ToHex()]; if nv2 then obj.BackgroundColor3 = nv2 end end
            elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local nv = swap[obj.TextColor3:ToHex()]; if nv then obj.TextColor3 = nv end
                if obj.BackgroundTransparency < 1 then local nv2 = swap[obj.BackgroundColor3:ToHex()]; if nv2 then obj.BackgroundColor3 = nv2 end end
            elseif obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
                if obj.BackgroundTransparency < 1 then local nv = swap[obj.BackgroundColor3:ToHex()]; if nv then obj.BackgroundColor3 = nv end end
            end
        end)
    end
    paint(root)
    for _,d in ipairs(root:GetDescendants()) do paint(d) end
end
local function applyTheme(name,persist)
    local theme = JL._themes[name]; if not theme then return false end
    local oldRoles = {}; for k,v in pairs(C) do oldRoles[k] = v end
    local oldAccents = {}; for i,v in ipairs(ACCENTS) do oldAccents[i] = v end
    for k,v in pairs(theme) do if k ~= "accents" then C[k] = v end end
    if theme.accents then for i,v in ipairs(theme.accents) do ACCENTS[i] = v end end
    JL._currentTheme = name
    local swap = {}
    for k,v in pairs(oldRoles) do if C[k] then swap[v:ToHex()] = C[k] end end
    for i,v in ipairs(oldAccents) do if ACCENTS[i] then swap[v:ToHex()] = ACCENTS[i] end end
    if JL._activeWin then walkRepaint(JL._activeWin, swap) end
    if JL._activeBadge then walkRepaint(JL._activeBadge, swap) end
    for _,nd in ipairs(shared._JLNotifs or {}) do if nd and nd.f then walkRepaint(nd.f, swap) end end
    for _,r in ipairs(JL._extraRoots or {}) do if r and r.Parent then walkRepaint(r, swap) end end
    for _,fn in ipairs(JL._themeHooks or {}) do pcall(fn, name) end
    if persist then pcall(function() if JL._activeCfgSet then JL._activeCfgSet("_theme", name) end end) end
    return true
end
function JL:SetTheme(name)
    if not JL._themes[name] then return false end
    JL._userTheme = name
    return applyTheme(name, true)
end
function JL:GetTheme() return JL._currentTheme end
-- Seasonal Themes удалены (были нестабильны). Старые вызовы оставлены пустышками, чтобы чужие скрипты не падали.
local function skinKnob(knob,knobStroke)
    knob.BackgroundTransparency = 0; knob.BackgroundColor3 = Color3.new(1,1,1)
    knobStroke.Color = Color3.fromRGB(20,20,24); knobStroke.Transparency = 0
end
function JL:SetSeason() end
function JL:GetSeason() return nil end
function JL:SetSeasonTheme() end
function JL:SetSeasonIcons() end
local function decimalsOf(step) local d = tostring(step):match("%.(%d+)$"); return d and #d or 0 end
local function fmtNum(v,dec)
    if dec <= 0 then return tostring(math.floor(v + 0.5)) end
    local s = string.format("%." .. dec .. "f", v)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    return s
end
local function snap(v,vmin,vmax,step)
    v = math.clamp(v, vmin, vmax)
    v = vmin + math.floor((v - vmin) / step + 0.5) * step
    local m = 10 ^ decimalsOf(step)
    v = math.floor(v * m + 0.5) / m
    return math.clamp(v, vmin, vmax)
end
