-- Materials plugin: recolor and re-material the preview copy of a model (the original asset is never touched).
local Plugin = {}

local MATERIALS = { "Plastic", "SmoothPlastic", "Neon", "Metal", "DiamondPlate", "Glass", "ForceField", "Wood", "Marble", "Granite", "Ice", "Fabric" }
local SWATCHES = {
    Color3.fromRGB(163, 162, 165), Color3.fromRGB(255, 255, 255), Color3.fromRGB(33, 33, 38), Color3.fromRGB(235, 70, 80),
    Color3.fromRGB(255, 160, 60), Color3.fromRGB(250, 220, 80), Color3.fromRGB(80, 200, 120), Color3.fromRGB(70, 150, 255),
    Color3.fromRGB(140, 90, 255), Color3.fromRGB(240, 110, 200),
}

function Plugin.Init(context)
    assert(context and context.Preview, "Materials requires Preview context")
    local preview, ui = context.Preview, context.UI or {}
    local alive, page = true, nil

    local function build(parent, asset)
        if not alive or typeof(asset.Model) ~= "Instance" then return end
        local T, U2, V2 = ui.Theme(), ui.U2, ui.V2
        local make, text, icon, corner, stroke = ui.Create, ui.Text, ui.Icon, ui.Corner, ui.Stroke

        local vpObj = ui.Viewport(parent, asset, { Ground = true, Hint = false })
        local model = vpObj.Model
        if not model then
            vpObj:Destroy()
            text("TextLabel", { Text = "This asset has no model to paint.", TextColor3 = T.dim, TextSize = 12, Size = U2(1, 0, 0, 30) }, parent)
            return
        end
        local original, parts = {}, {}
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                parts[#parts + 1] = d
                original[d] = { d.Color, d.Material, d.Transparency, d.Reflectance }
            end
        end
        local selected = nil
        local scope = "All parts"
        local drawList

        local side = make("Frame", { BackgroundColor3 = T.panel, BorderSizePixel = 0, ClipsDescendants = true }, parent)
        corner(side, 12); stroke(side, T.border, 1, 0.3)
        local scroll = make("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0, Position = U2(0, 8, 0, 8), Size = U2(1, -16, 1, -16), CanvasSize = U2(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
        }, side)
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, scroll)

        local function targets()
            if scope == "Selected part" and selected then return { selected } end
            return parts
        end
        local function each(fn)
            for _, p in ipairs(targets()) do if p.Parent then fn(p) end end
        end

        local order = 0
        local function nextOrder() order = order + 1 return order end
        local function label(textValue)
            text("TextLabel", { Text = string.upper(textValue), Font = ui.Fonts.Bold, TextSize = 11, TextColor3 = T.accent, LayoutOrder = nextOrder(), Size = U2(1, 0, 0, 18) }, scroll)
        end

        label("Apply to")
        local scopeDef = ui.Control(scroll, "Dropdown", { Name = "Scope", Options = { "All parts", "Selected part" }, Default = "All parts",
            Callback = function(v) scope = v end }, nextOrder())

        label("Paint")
        local sw = make("Frame", { BackgroundTransparency = 1, LayoutOrder = nextOrder(), Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, scroll)
        make("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, CellSize = UDim2.fromOffset(34, 34), CellPadding = UDim2.fromOffset(6, 6) }, sw)
        for i, col in ipairs(SWATCHES) do
            local b = text("TextButton", { BackgroundTransparency = 0, BackgroundColor3 = col, Text = "", LayoutOrder = i }, sw)
            corner(b, 8); stroke(b, T.border, 1, 0.2)
            b.Activated:Connect(function() each(function(p) p.Color = col end) end)
        end
        ui.Control(scroll, "ColorPicker", { Name = "Custom color", Default = Color3.fromRGB(139, 92, 246),
            Callback = function(c) each(function(p) p.Color = c end) end }, nextOrder())

        label("Surface")
        ui.Control(scroll, "Dropdown", { Name = "Material", Options = MATERIALS, Default = "Plastic",
            Callback = function(v)
                local item = Enum.Material[v]
                if item then each(function(p) p.Material = item end) end
            end }, nextOrder())
        ui.Control(scroll, "Slider", { Name = "Transparency", Min = 0, Max = 1, Step = 0.05, Default = 0,
            Callback = function(v) each(function(p) p.Transparency = v end) end }, nextOrder())
        ui.Control(scroll, "Slider", { Name = "Reflectance", Min = 0, Max = 1, Step = 0.05, Default = 0,
            Callback = function(v) each(function(p) p.Reflectance = v end) end }, nextOrder())

        label("Parts")
        local listHolder = make("Frame", { BackgroundTransparency = 1, LayoutOrder = nextOrder(), Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, scroll)
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, listHolder)
        drawList = function()
            for _, ch in ipairs(listHolder:GetChildren()) do
                if not ch:IsA("UIListLayout") then ch:Destroy() end
            end
            for i, p in ipairs(parts) do
                if i > 150 then break end
                local on = p == selected
                local b = text("TextButton", {
                    BackgroundTransparency = on and 0.6 or 0, BackgroundColor3 = on and T.accent or T.card, Text = p.Name, TextSize = 12,
                    TextTruncate = Enum.TextTruncate.AtEnd, Size = U2(1, 0, 0, 28), LayoutOrder = i,
                }, listHolder)
                corner(b, 7)
                make("UIPadding", { PaddingLeft = UDim.new(0, 28), PaddingRight = UDim.new(0, 8) }, b)
                local dot = make("Frame", { BackgroundColor3 = p.Color, BorderSizePixel = 0, Position = U2(0, -20, 0.5, -6), Size = U2(0, 12, 0, 12) }, b)
                corner(dot, 6)
                b.Activated:Connect(function()
                    selected = p
                    vpObj:Focus(p)
                    drawList()
                end)
            end
        end
        drawList()

        local reset = ui.Button(scroll, { Text = "Reset to original", Icon = "refresh", Order = nextOrder(), Callback = function()
            for p, o in pairs(original) do
                if p.Parent then p.Color, p.Material, p.Transparency, p.Reflectance = o[1], o[2], o[3], o[4] end
            end
            drawList()
        end })

        local function layout()
            local k = ui.Scale and ui.Scale() or 1
            local w = parent.AbsoluteSize.X / k
            if w >= 620 then
                local sw_ = math.clamp(math.floor(w * 0.36), 240, 340)
                vpObj.Frame.Position, vpObj.Frame.Size = U2(0, 0, 0, 0), U2(1, -(sw_ + 8), 1, 0)
                side.Position, side.Size = U2(1, -sw_, 0, 0), U2(0, sw_, 1, 0)
            else
                vpObj.Frame.Position, vpObj.Frame.Size = U2(0, 0, 0, 0), U2(1, 0, 0.42, 0)
                side.Position, side.Size = U2(0, 0, 0.42, 6), U2(1, 0, 0.58, -6)
            end
        end
        layout()
        local con = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
        return function()
            con:Disconnect()
            vpObj:Destroy()
        end
    end

    page = preview:Page({
        Name = "Materials", Icon = "paintbrush",
        Visible = function(asset) return asset ~= nil and typeof(asset.Model) == "Instance" end,
        Build = build,
    })
    return { Destroy = function()
        if not alive then return end
        alive = false
        if page then preview:RemovePage(page); page = nil end
    end }
end

return { Manifest = { Id = "materials", Name = "Materials", Version = "0.1.0", ApiVersion = 1 }, Init = Plugin.Init }
