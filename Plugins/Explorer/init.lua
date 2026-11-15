-- Explorer plugin: hierarchy and selected-instance inspection.
local Explorer = {}

local function make(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

function Explorer.Init(context)
    assert(type(context) == "table" and context.Preview, "Explorer requires Preview context")
    local preview = context.Preview
    local bridge = context.Bridge or {}
    local colors = bridge.C or {}
    local accents = bridge.ACCENTS or {}
    local accent = accents[1] or Color3.fromRGB(95, 150, 255)
    local page

    page = preview:Page({
        Name = "Explorer",
        Icon = "network",
        Visible = function(asset)
            return asset ~= nil and (typeof(asset.Model) == "Instance" or type(asset.Build) == "function")
        end,
        Build = function(parent, asset)
            local panel = make("ScrollingFrame", {
                Name = "ExplorerScroll",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = colors.dim or Color3.fromRGB(130, 135, 150),
            }, parent)
            local content = make("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 8),
                Size = UDim2.new(1, -20, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            }, panel)
            make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 7),
            }, content)

            local source
            local owned = false
            if typeof(asset.Model) == "Instance" then
                local ok, clone = pcall(function() return asset.Model:Clone() end)
                if ok then source, owned = clone, true end
            elseif type(asset.Build) == "function" then
                source = Instance.new("Model")
                owned = true
                local ok = pcall(asset.Build, source)
                if not ok then source:Destroy(); source = nil end
            end

            if source and source:IsA("BasePart") then
                local wrapper = Instance.new("Model")
                source.Parent = wrapper
                source = wrapper
            end
            if not source then
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = "No model structure available",
                    TextColor3 = colors.dim or Color3.fromRGB(145, 150, 165),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    Size = UDim2.new(1, 0, 0, 36),
                }, content)
                return function()
                    if owned and source then source:Destroy() end
                end
            end

            local total = #source:GetDescendants() + 1
            local heading = make("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24),
                LayoutOrder = 1,
            }, content)
            make("TextLabel", {
                BackgroundTransparency = 1,
                Text = "MODEL HIERARCHY",
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = colors.dim or Color3.fromRGB(145, 150, 165),
                Size = UDim2.new(0.7, 0, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
            }, heading)
            make("TextLabel", {
                BackgroundTransparency = 1,
                Text = tostring(total) .. " objects",
                Font = Enum.Font.GothamMedium,
                TextSize = 10,
                TextColor3 = colors.dim or Color3.fromRGB(145, 150, 165),
                Position = UDim2.new(0.7, 0, 0, 0),
                Size = UDim2.new(0.3, 0, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Right,
            }, heading)

            local tree = make("Frame", {
                Name = "ExplorerTree",
                BackgroundColor3 = colors.panel or Color3.fromRGB(30, 32, 42),
                BackgroundTransparency = 0.12,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 2,
            }, content)
            corner(tree, 8)
            make("UIStroke", { Color = colors.border or Color3.fromRGB(65, 68, 82), Thickness = 1 }, tree)
            make("UIPadding", {
                PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5),
                PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
            }, tree)
            local treeLayout = make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 1),
            }, tree)

            local properties = make("Frame", {
                Name = "ExplorerProperties",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 3,
            }, content)
            make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
            }, properties)

            local expanded, selected = { [source] = true }, source
            local rowCount, maxRows, maxDepth = 0, 350, 24
            local function iconFor(item)
                if item:IsA("Model") then return "◇" end
                if item:IsA("Folder") then return "▰" end
                if item:IsA("BasePart") then return "◻" end
                if item:IsA("Animation") then return "▶" end
                if item:IsA("Sound") then return "♫" end
                if item:IsA("Attachment") then return "⊕" end
                if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then return "⌘" end
                return "◆"
            end
            local function read(item, key)
                local ok, value = pcall(function() return item[key] end)
                if not ok or value == nil then return nil end
                if typeof(value) == "Color3" then
                    return string.format("RGB(%d, %d, %d)", math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5))
                end
                if typeof(value) == "Vector3" then
                    return string.format("%.2f, %.2f, %.2f", value.X, value.Y, value.Z)
                end
                if typeof(value) == "CFrame" then
                    local pos = value.Position
                    return string.format("%.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z)
                end
                if typeof(value) == "EnumItem" then return value.Name end
                if typeof(value) == "Instance" then return value.Name end
                return tostring(value)
            end
            local function propertyKeys(item)
                local keys = { "Name", "ClassName" }
                if item:IsA("BasePart") then
                    for _, key in ipairs({ "Size", "Position", "Color", "Material", "Transparency", "Anchored", "CanCollide" }) do
                        keys[#keys + 1] = key
                    end
                end
                if item:IsA("MeshPart") then
                    keys[#keys + 1] = "MeshId"
                    keys[#keys + 1] = "TextureID"
                end
                if item:IsA("Animation") then keys[#keys + 1] = "AnimationId" end
                if item:IsA("Sound") then
                    keys[#keys + 1] = "SoundId"
                    keys[#keys + 1] = "Volume"
                end
                if item:IsA("Humanoid") then
                    keys[#keys + 1] = "Health"
                    keys[#keys + 1] = "WalkSpeed"
                end
                return keys
            end
            local function renderProperties()
                for _, child in ipairs(properties:GetChildren()) do
                    if child ~= properties:FindFirstChildOfClass("UIListLayout") then child:Destroy() end
                end
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = "SELECTED OBJECT",
                    Font = Enum.Font.GothamBold,
                    TextSize = 10,
                    TextColor3 = colors.dim or Color3.fromRGB(145, 150, 165),
                    Size = UDim2.new(1, 0, 0, 23),
                    LayoutOrder = 1,
                }, properties)
                local keys = propertyKeys(selected)
                local order = 2
                for _, key in ipairs(keys) do
                    local value = read(selected, key)
                    if value ~= nil then
                        local row = make("Frame", {
                            BackgroundColor3 = colors.panel or Color3.fromRGB(30, 32, 42),
                            BackgroundTransparency = order % 2 == 0 and 0.15 or 0.4,
                            BorderSizePixel = 0,
                            Size = UDim2.new(1, 0, 0, 25),
                            LayoutOrder = order,
                        }, properties)
                        corner(row, 5)
                        make("TextLabel", {
                            BackgroundTransparency = 1, Text = key,
                            Font = Enum.Font.GothamMedium, TextSize = 10,
                            TextColor3 = colors.dim or Color3.fromRGB(145, 150, 165),
                            Position = UDim2.fromOffset(8, 0),
                            Size = UDim2.new(0.4, -8, 1, 0),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                        }, row)
                        make("TextLabel", {
                            BackgroundTransparency = 1, Text = tostring(value),
                            Font = Enum.Font.Gotham, TextSize = 10,
                            TextColor3 = colors.txt or Color3.fromRGB(235, 237, 245),
                            Position = UDim2.new(0.4, 0, 0, 0),
                            Size = UDim2.new(0.6, -8, 1, 0),
                            TextXAlignment = Enum.TextXAlignment.Right,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                        }, row)
                        order = order + 1
                    end
                end
                make("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = tostring(#selected:GetChildren()) .. " direct children",
                    Font = Enum.Font.Gotham,
                    TextSize = 9,
                    TextColor3 = colors.dim or Color3.fromRGB(145, 150, 165),
                    Size = UDim2.new(1, 0, 0, 18),
                    LayoutOrder = order,
                }, properties)
            end

            local function renderTree()
                for _, child in ipairs(tree:GetChildren()) do
                    if child ~= treeLayout and not child:IsA("UIPadding") and not child:IsA("UIStroke") and not child:IsA("UICorner") then
                        child:Destroy()
                    end
                end
                rowCount = 0
                local function addNode(item, depth)
                    if rowCount >= maxRows or depth > maxDepth then return end
                    rowCount = rowCount + 1
                    local children = item:GetChildren()
                    local hasChildren = #children > 0
                    local isOpen = expanded[item] == true
                    local active = selected == item
                    local row = make("TextButton", {
                        Name = "Node_" .. rowCount,
                        Text = "",
                        BackgroundColor3 = active and accent or (colors.panel or Color3.fromRGB(30, 32, 42)),
                        BackgroundTransparency = active and 0.82 or 1,
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Size = UDim2.new(1, 0, 0, 27),
                        LayoutOrder = rowCount,
                    }, tree)
                    corner(row, 5)
                    if active then make("UIStroke", { Color = accent, Thickness = 1 }, row) end
                    local indent = math.min(depth, maxDepth) * 13
                    local arrow = make("TextButton", {
                        Text = hasChildren and (isOpen and "⌄" or "›") or "",
                        Font = Enum.Font.GothamBold, TextSize = 14,
                        TextColor3 = colors.dim or Color3.fromRGB(145, 150, 165),
                        BackgroundTransparency = 1,
                        Position = UDim2.fromOffset(indent, 0),
                        Size = UDim2.fromOffset(18, 27),
                    }, row)
                    arrow.Activated:Connect(function()
                        if hasChildren then expanded[item] = not expanded[item]; renderTree() end
                    end)
                    make("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = iconFor(item),
                        Font = Enum.Font.GothamBold, TextSize = 12,
                        TextColor3 = active and accent or (colors.dim or Color3.fromRGB(145, 150, 165)),
                        Position = UDim2.fromOffset(indent + 20, 0),
                        Size = UDim2.fromOffset(18, 27),
                    }, row)
                    make("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = tostring(item.Name),
                        Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium,
                        TextSize = 10,
                        TextColor3 = active and (colors.txt or Color3.new(1,1,1)) or (colors.dim or Color3.fromRGB(145, 150, 165)),
                        Position = UDim2.fromOffset(indent + 40, 0),
                        Size = UDim2.new(1, -(indent + 46), 1, 0),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                    }, row)
                    row.Activated:Connect(function()
                        selected = item
                        renderTree()
                        renderProperties()
                    end)
                    if isOpen then
                        for _, child in ipairs(children) do
                            addNode(child, depth + 1)
                            if rowCount >= maxRows then break end
                        end
                    end
                end
                addNode(source, 0)
                if total > maxRows then
                    make("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = "Tree limited to first " .. maxRows .. " visible rows",
                        Font = Enum.Font.Gotham, TextSize = 9,
                        TextColor3 = colors.dim or Color3.fromRGB(145, 150, 165),
                        Size = UDim2.new(1, 0, 0, 18),
                        LayoutOrder = rowCount + 1,
                    }, tree)
                end
            end

            renderTree()
            renderProperties()
            return function()
                if owned and source then pcall(function() source:Destroy() end) end
            end
        end,
    })

    return {
        Destroy = function()
            if page then
                preview:RemovePage(page)
                page = nil
            end
        end,
    }
end

return {
    Manifest = {
        Id = "explorer",
        Name = "Explorer",
        Version = "0.2.0",
        ApiVersion = 1,
    },
    Init = Explorer.Init,
}
