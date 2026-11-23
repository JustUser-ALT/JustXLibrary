-- Stats plugin: read-only breakdown of the selected asset's model.
local Plugin = {}

local function collect(model)
    local c = { parts = 0, meshes = 0, unions = 0, decals = 0, lights = 0, effects = 0, joints = 0, accessories = 0,
        humanoids = 0, animations = 0, scripts = 0, materials = {}, colors = {} }
    local function visit(d)
        if d:IsA("BasePart") then
            c.parts = c.parts + 1
            if d:IsA("MeshPart") then c.meshes = c.meshes + 1 elseif d:IsA("UnionOperation") then c.unions = c.unions + 1 end
            local m = d.Material.Name
            c.materials[m] = (c.materials[m] or 0) + 1
            local col = d.Color
            local key = string.format("#%02X%02X%02X", math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5))
            c.colors[key] = (c.colors[key] or 0) + 1
        elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") then c.decals = c.decals + 1
        elseif d:IsA("Light") then c.lights = c.lights + 1
        elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then c.effects = c.effects + 1
        elseif d:IsA("JointInstance") then c.joints = c.joints + 1
        elseif d:IsA("Accessory") then c.accessories = c.accessories + 1
        elseif d:IsA("Humanoid") then c.humanoids = c.humanoids + 1
        elseif d:IsA("Animation") then c.animations = c.animations + 1
        elseif d:IsA("LuaSourceContainer") then c.scripts = c.scripts + 1 end
    end
    visit(model)
    for _, d in ipairs(model:GetDescendants()) do visit(d) end
    return c
end

local function top(map, n)
    local list = {}
    for k, v in pairs(map) do list[#list + 1] = { k, v } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(n, #list) do out[i] = list[i] end
    return out
end

function Plugin.Init(context)
    assert(context and context.Preview, "Stats requires Preview context")
    local preview, ui = context.Preview, context.UI or {}
    local alive, page = true, nil

    local function build(parent, asset)
        if not alive or typeof(asset.Model) ~= "Instance" then return end
        local T, U2, V2 = ui.Theme(), ui.U2, ui.V2
        local make, text, corner, stroke = ui.Create, ui.Text, ui.Corner, ui.Stroke
        local model = asset.Model
        local c = collect(model)
        local ok, cf, size = pcall(function()
            if model:IsA("Model") then local a, b = model:GetBoundingBox(); return a, b end
            return model.CFrame, model.Size
        end)

        local sf = make("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0, Size = U2(1, 0, 1, 0), CanvasSize = U2(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
        }, parent)
        local body = make("Frame", { BackgroundTransparency = 1, Size = U2(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, sf)
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, body)

        local function section(order, name)
            text("TextLabel", { Text = string.upper(name), Font = ui.Fonts.Bold, TextSize = 11, TextColor3 = T.accent, LayoutOrder = order, Size = U2(1, 0, 0, 16) }, body)
        end
        local function grid(order)
            local g = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, body)
            local k = ui.Scale and ui.Scale() or 1
            local w = math.max(parent.AbsoluteSize.X / k, 240)
            local cols = math.clamp(math.floor((w + 8) / 128), 2, 5)
            make("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, CellSize = U2(1 / cols, -8, 0, 58), CellPadding = UDim2.fromOffset(8, 8) }, g)
            return g
        end
        local function stat(g, order, label, value)
            local f = make("Frame", { BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = order, ClipsDescendants = true }, g)
            corner(f, 10); stroke(f, T.border, 1, 0.35)
            text("TextLabel", { Text = tostring(value), Font = ui.Fonts.Bold, TextSize = 18, Position = U2(0, 10, 0, 8), Size = U2(1, -16, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd }, f)
            text("TextLabel", { Text = label, TextSize = 11, TextColor3 = T.dim, Position = U2(0, 10, 0, 32), Size = U2(1, -16, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, f)
        end

        section(1, "Overview")
        local g1 = grid(2)
        stat(g1, 1, "Parts", c.parts)
        stat(g1, 2, "MeshParts", c.meshes)
        stat(g1, 3, "Unions", c.unions)
        stat(g1, 4, "Joints", c.joints)
        stat(g1, 5, "Decals / textures", c.decals)
        stat(g1, 6, "Lights", c.lights)
        stat(g1, 7, "Effects", c.effects)
        stat(g1, 8, "Accessories", c.accessories)
        stat(g1, 9, "Humanoids", c.humanoids)
        stat(g1, 10, "Animations", c.animations)
        stat(g1, 11, "Scripts (stripped in preview)", c.scripts)
        if ok then
            stat(g1, 12, "Size (studs)", string.format("%.1f × %.1f × %.1f", size.X, size.Y, size.Z))
        end

        local function bars(order, title, map, colorOf)
            section(order, title)
            local items = top(map, 6)
            local total = 0
            for _, v in pairs(map) do total = total + v end
            local holder = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order + 1, Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, body)
            make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, holder)
            if #items == 0 then
                text("TextLabel", { Text = "Nothing to show.", TextColor3 = T.dim, TextSize = 12, Size = U2(1, 0, 0, 20) }, holder)
            end
            for i, it in ipairs(items) do
                local row = make("Frame", { BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = i, Size = U2(1, 0, 0, 30), ClipsDescendants = true }, holder)
                corner(row, 8)
                local fill = make("Frame", { BackgroundColor3 = colorOf(it[1]), BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = U2(math.max(it[2] / total, 0.02), 0, 1, 0) }, row)
                corner(fill, 8)
                text("TextLabel", { Text = it[1], TextSize = 12, Position = U2(0, 10, 0, 0), Size = U2(0.6, -10, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }, row)
                text("TextLabel", {
                    Text = string.format("%d  ·  %d%%", it[2], math.floor(it[2] / total * 100 + 0.5)), TextSize = 12, TextColor3 = T.txt,
                    TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = V2(1, 0), Position = U2(1, -10, 0, 0), Size = U2(0.4, -10, 1, 0),
                }, row)
            end
        end
        bars(10, "Materials", c.materials, function() return T.accent end)
        bars(20, "Top colors", c.colors, function(hex)
            local r, g, b = hex:match("#(%x%x)(%x%x)(%x%x)")
            return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
        end)
    end

    page = preview:Page({
        Name = "Stats", Icon = "chart-bar",
        Visible = function(asset) return asset ~= nil and typeof(asset.Model) == "Instance" end,
        Build = build,
    })
    return { Destroy = function()
        if not alive then return end
        alive = false
        if page then preview:RemovePage(page); page = nil end
    end }
end

return { Manifest = { Id = "stats", Name = "Stats", Version = "0.1.0", ApiVersion = 1 }, Init = Plugin.Init }
