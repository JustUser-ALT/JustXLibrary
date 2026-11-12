-- Background module factory. Dependencies are injected; background state stays on the library instance.
local function createBackgroundsModule(deps)
    local JL = deps.JL
    local Enum = deps.Enum
    local Instance = deps.Instance
    local UDim2 = deps.UDim2
    local Color3 = deps.Color3
    local Vector2 = deps.Vector2
    local task = deps.Task
    local clock = deps.Clock
    local math = deps.Math
    local trackedSpawn = deps.TrackedSpawn
    local corner = deps.Corner

    local BG = {reg = {}}
    JL._bgs = {}
    JL._newRows = {}
    local BG_SCALE = {Crop = Enum.ScaleType.Crop, Stretch = Enum.ScaleType.Stretch, Fit = Enum.ScaleType.Fit, Tile = Enum.ScaleType.Tile}
    local bgAnims = {}
    local bgRunning = false
    local function bgImage(v)
        local str = tostring(v or "")
        if str:match("^%d+$") then return "rbxassetid://" .. str end
        return str
    end
    local function bgStartAnim()
        if bgRunning then return end
        bgRunning = true
        trackedSpawn(function()
            local last = os.clock()
            while #bgAnims > 0 do
                task.wait(1 / 30)
                local now = os.clock(); local dt = now - last; last = now
                for i = #bgAnims,1,-1 do
                    local a = bgAnims[i]
                    if not (a.img and a.img.Parent) then
                        table.remove(bgAnims,i)
                    else
                        a.t = a.t + dt * a.fps
                        local f = math.floor(a.t) % a.count
                        if f ~= a.f then
                            a.f = f
                            a.img.ImageRectOffset = Vector2.new((f % a.cols) * a.fw, math.floor(f / a.cols) * a.fh)
                        end
                    end
                end
            end
            bgRunning = false
        end)
    end
    function BG.clear(face)
        for _,c in ipairs(face:GetChildren()) do if c.Name == "JLBg" then c:Destroy() end end
    end
    function BG.attach(face,cfg,radius)
        BG.clear(face)
        if cfg == nil or cfg == false then return end
        if type(cfg) ~= "table" then cfg = {Image = cfg} end
        if not cfg.Image then return end
        local img = Instance.new("ImageLabel"); img.Name = "JLBg"; img.Size = UDim2.new(1,0,1,0); img.BackgroundTransparency = 1; img.BorderSizePixel = 0; img.ZIndex = 0
        img.Image = bgImage(cfg.Image); img.ImageTransparency = cfg.Transparency or 0.25; img.ImageColor3 = cfg.Color or Color3.new(1,1,1)
        img.ScaleType = BG_SCALE[cfg.ScaleType or "Crop"] or Enum.ScaleType.Crop
        if img.ScaleType == Enum.ScaleType.Tile then local t = cfg.TileSize or 64; img.TileSize = UDim2.new(0,t,0,t) end
        img:SetAttribute("JLNoRepaint", true)
        corner(radius or 8, img)
        if cfg.Frames then
            local cols = math.max(1, math.floor(cfg.Frames.X)); local rows = math.max(1, math.floor(cfg.Frames.Y))
            local sheet = cfg.SheetSize or Vector2.new(1024,1024)
            local fw, fh = sheet.X / cols, sheet.Y / rows
            img.ImageRectSize = Vector2.new(fw,fh); img.ImageRectOffset = Vector2.new(0,0)
            if cfg.ScaleType == nil then img.ScaleType = Enum.ScaleType.Crop end
            bgAnims[#bgAnims + 1] = {img = img, t = 0, f = -1, fps = cfg.FPS or 12, cols = cols, fw = fw, fh = fh, count = math.max(1, math.floor(cfg.FrameCount or (cols * rows)))}
            bgStartAnim()
        end
        if (cfg.Dim or 0) > 0 then
            local d = Instance.new("Frame"); d.Size = UDim2.new(1,0,1,0); d.BackgroundColor3 = Color3.new(0,0,0); d.BackgroundTransparency = 1 - math.clamp(cfg.Dim,0,1); d.BorderSizePixel = 0
            d:SetAttribute("JLNoRepaint", true); d.Parent = img; corner(radius or 8, d)
        end
        img.Parent = face
    end
    function BG.register(kind,face,radius,own,elem)
        BG.reg[#BG.reg + 1] = {kind = kind, face = face, radius = radius, own = own ~= nil, elem = elem}
        local cfg = own
        if cfg == nil then cfg = JL._bgs[kind] end
        if cfg == nil and elem then cfg = JL._bgs.Element end
        if cfg then BG.attach(face, cfg, radius) end
    end
    function BG.face(row)
        for _,c in ipairs(row:GetChildren()) do
            if c:IsA("GuiObject") and c.BackgroundTransparency < 1 and c.Size == UDim2.new(1,0,1,0) then return c end
        end
        return row
    end
    function JL:SetBackground(kind,cfg)
        JL._bgs[kind] = cfg
        local keep = {}
        for _,e in ipairs(BG.reg) do
            if e.face and e.face.Parent then
                keep[#keep + 1] = e
                if not e.own then
                    if e.kind == kind then
                        BG.attach(e.face, cfg or (e.elem and JL._bgs.Element) or nil, e.radius)
                    elseif kind == "Element" and e.elem and JL._bgs[e.kind] == nil then
                        BG.attach(e.face, cfg, e.radius)
                    end
                end
            end
        end
        BG.reg = keep
    end
    function JL:GetBackground(kind) return JL._bgs[kind] end
    function JL:ClearBackground(kind) JL:SetBackground(kind, nil) end

    return {
        BG = BG
    }
end
