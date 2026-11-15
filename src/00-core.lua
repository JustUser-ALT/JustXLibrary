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
local _disposed = false
local Lifecycle = createLifecycleModule({
    TweenService = TS,
    TweenInfo = TweenInfo,
    Enum = Enum,
    Task = task,
    Typeof = typeof,
    PCall = pcall,
    Pack = table.pack,
    Unpack = table.unpack,
    Error = error,
    Type = type,
    Pairs = pairs,
    IPairs = ipairs,
    IsDisposed = function() return _disposed end
})
local _conns = Lifecycle.Connections
local _resources = Lifecycle.Resources
local _threads = Lifecycle.Threads
local cleanupResource = Lifecycle.CleanupResource
local cleanupResources = Lifecycle.CleanupResources
local keep = Lifecycle.Keep
local trackedSpawn = Lifecycle.TrackedSpawn
local trackedDelay = Lifecycle.TrackedDelay
local trackedDefer = Lifecycle.TrackedDefer
local createTween = Lifecycle.CreateTween
local tw = Lifecycle.Tween
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
local UIPrimitives = createUIPrimitivesModule({
    UserInputService = UIS,
    Enum = Enum,
    Vector2 = Vector2,
    UDim2 = UDim2,
    UDim = UDim,
    Instance = Instance,
    TextService = TextService,
    Font = G,
    Colors = C,
    Keep = keep,
    PCall = pcall,
    Math = math
})
local touchLast = UIPrimitives.TouchLast
local _buttonFeedbackStates = setmetatable({}, {__mode = "k"})
local function buttonFeedback(button, baseColor, hoverColor, pressedColor, visualTarget)
    if not button or not button:IsA("GuiObject") or _buttonFeedbackStates[button] then return end
    visualTarget = visualTarget or button
    baseColor = baseColor or visualTarget.BackgroundColor3
    hoverColor = hoverColor or baseColor
    pressedColor = pressedColor or baseColor:Lerp(hoverColor, 0.55)
    local state = {BaseColor=baseColor, HoverColor=hoverColor, PressedColor=pressedColor, VisualTarget=visualTarget, Hovered=false, PressedInput=nil, Tween=nil, Token=0, Name="Idle"}
    _buttonFeedbackStates[button] = state
    local function setState(name, color, duration)
        state.Token = state.Token + 1
        state.Name = name
        if button.Parent then button:SetAttribute("JLButtonState", name) end
        if state.Tween then pcall(function() state.Tween:Cancel() end) end
        if not visualTarget.Parent then return end
        local ok, tween = pcall(function()
            return createTween(visualTarget, TweenInfo.new(duration or 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3=color})
        end)
        if ok and tween then state.Tween=tween; tween:Play() end
    end
    button.MouseEnter:Connect(function()
        if touchLast() then return end
        state.Hovered=true
        if not state.PressedInput then setState("Hover",state.HoverColor,0.1) end
    end)
    button.MouseLeave:Connect(function()
        state.Hovered=false
        if not state.PressedInput then setState("Idle",state.BaseColor,0.1) end
    end)
    button.InputBegan:Connect(function(input)
        local kind=input.UserInputType
        if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
        state.PressedInput=input
        setState("Pressed",state.PressedColor,0.06)
    end)
end
keep(UIS.InputEnded:Connect(function(input)
    for button,state in pairs(_buttonFeedbackStates) do
        local pressed=state.PressedInput
        if pressed and (pressed==input or (pressed.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)) then
            state.PressedInput=nil
            local targetName=state.Hovered and not touchLast() and "Hover" or "Idle"
            local targetColor=targetName=="Hover" and state.HoverColor or state.BaseColor
            state.Token=state.Token+1
            local token=state.Token
            state.Name="Released"
            if button.Parent then button:SetAttribute("JLButtonState","Released") end
            if state.Tween then pcall(function() state.Tween:Cancel() end) end
            if state.VisualTarget.Parent then
                local ok,tween=pcall(function()
                    return createTween(state.VisualTarget,TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundColor3=targetColor})
                end)
                if ok and tween then state.Tween=tween; tween:Play() end
            end
            trackedDelay(0.12,function()
                if state.Token==token and button.Parent then state.Name=targetName; button:SetAttribute("JLButtonState",targetName) end
            end)
        end
    end
end))
local corner = UIPrimitives.Corner
local stroke = UIPrimitives.Stroke
local pad = UIPrimitives.Pad
local newTxt = UIPrimitives.NewText
local fitH = UIPrimitives.FitHeight
local isPtr = UIPrimitives.IsPointer
local beginDrag = UIPrimitives.BeginDrag
local draggable = UIPrimitives.Draggable
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
function JL:SetSeason() end
function JL:GetSeason() return nil end
function JL:SetSeasonTheme() end
function JL:SetSeasonIcons() end
local ControlHelpers = createControlHelpersModule({
    Color3 = Color3,
    Math = math,
    String = string,
    ToString = tostring
})
local skinKnob = ControlHelpers.SkinKnob
local decimalsOf = ControlHelpers.DecimalsOf
local fmtNum = ControlHelpers.FormatNumber
local snap = ControlHelpers.Snap
