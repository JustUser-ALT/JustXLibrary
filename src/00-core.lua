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
JL._secPanels = setmetatable({}, {__mode = "k"})
JL._searchPageTargets = {}
local GuideModule = createGuideModule({
    JL = JL,
    Instance = Instance,
    UDim2 = UDim2,
    Accents = ACCENTS,
    Corner = corner,
    Stroke = stroke,
    TweenInfo = TweenInfo,
    Enum = Enum,
    CreateTween = createTween,
    TrackedDelay = trackedDelay,
    TrackedSpawn = trackedSpawn,
    Task = task,
    Clock = os.clock
})
local GUIDE = GuideModule.Guide
local groupRules = GuideModule.GroupRules
JL._themes = createThemesModule({
    JL = JL,
    Colors = C,
    Accents = ACCENTS,
    Shared = shared,
    Color3 = Color3,
    PCall = pcall,
    Pairs = pairs,
    IPairs = ipairs
})
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
