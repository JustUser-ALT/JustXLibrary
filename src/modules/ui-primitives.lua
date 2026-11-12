-- UI primitives module factory. Shared low-level UI helpers are injected explicitly.
local function createUIPrimitivesModule(deps)
    local UIS = deps.UserInputService
    local Enum = deps.Enum
    local Vector2 = deps.Vector2
    local UDim2 = deps.UDim2
    local UDim = deps.UDim
    local Instance = deps.Instance
    local TextService = deps.TextService
    local G = deps.Font
    local C = deps.Colors
    local keep = deps.Keep
    local pcall = deps.PCall
    local math = deps.Math
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
    return {
        TouchLast = touchLast,
        Corner = corner,
        Stroke = stroke,
        Pad = pad,
        NewText = newTxt,
        FitHeight = fitH,
        IsPointer = isPtr,
        BeginDrag = beginDrag,
        Draggable = draggable
    }
end
