-- JustXLibrary Legacy Preview UI Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUITest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()

if not Library then
    warn("[Preview Test] JustLib failed to load.")
    return
end

local Window = Library:Window({
    Title = "Legacy Preview Test",
    Config = "JustLib_LegacyPreviewTest",
    Width = 560,
    Height = 440,
})

if not Window then
    warn("[Preview Test] Window creation failed.")
    return
end

Window:HomeTab({
    WelcomeTitle = "Legacy Preview Test",
    Changelog = {
        {
            Version = "Restored",
            Title = "Old Preview UI",
            Description = "Testing the restored Preview module inside the normal JustXLibrary window.",
            Changes = {
                "Original Preview module from the restored branch.",
                "Multiple sample assets and 3D previews.",
                "No Asset Browser replacement or standalone preview window.",
            },
        },
    },
})

local HostTab = Window:Tab({ Name = "Test", Icon = "flask-conical" })
local HostSection = HostTab:Section({ Title = "Preview test" })

local Preview
local Models
local Items

local function makePart(parent, name, size, position, color, shape, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.Size = size
    p.Position = position
    p.Color = color
    p.Shape = shape or Enum.PartType.Block
    p.Material = material or Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end

local function openPreview()
    if Preview and Preview.alive and Preview:IsOpen() then
        Preview:Open("Models")
        return
    end

    Preview = Library:Preview({
        Title = "Preview Test",
        Icon = "box",
        TabName = "Preview",
        Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
    })

    if not Preview or Preview.IsStub then
        warn("[Preview Test] Preview initialization failed. Check the executor console for the JustLib warning.")
        return
    end

    Models = Preview:Tab({ Name = "Models", Icon = "trees" })
    Items = Preview:Tab({ Name = "Items", Icon = "package" })
    Preview:Tab({ Name = "All", Icon = "grid-2x2", ShowAll = true })

    Models:Assets({
        {
            Name = "Oak Tree",
            Type = "Environment Model",
            Creator = "Preview Test",
            Version = "1.0",
            Description = "A sample tree made from actual 3D parts.",
            Tags = { "Nature", "Environment", "3D" },
            Info = {
                { Label = "Parts", Value = "3", Icon = "boxes" },
                { Label = "Category", Value = "Environment", Icon = "leaf" },
            },
            Build = function(model)
                makePart(model, "Trunk", Vector3.new(1.2, 4, 1.2), Vector3.new(0, -1, 0), Color3.fromRGB(112, 76, 48), Enum.PartType.Cylinder)
                makePart(model, "Leaves", Vector3.new(4.5, 4.5, 4.5), Vector3.new(0, 2, 0), Color3.fromRGB(62, 166, 92), Enum.PartType.Ball, Enum.Material.Grass)
                makePart(model, "Fruit", Vector3.new(0.65, 0.65, 0.65), Vector3.new(1.1, 1.1, -1.2), Color3.fromRGB(240, 174, 62), Enum.PartType.Ball, Enum.Material.Neon)
            end,
        },
        {
            Name = "Mini Robot",
            Type = "Character Model",
            Creator = "Preview Test",
            Version = "1.0",
            Description = "A small robot assembled from separate parts.",
            Tags = { "Robot", "Character", "3D" },
            Build = function(model)
                makePart(model, "Body", Vector3.new(2.2, 2.6, 1.3), Vector3.new(0, 0, 0), Color3.fromRGB(92, 105, 128))
                makePart(model, "Head", Vector3.new(1.7, 1.5, 1.5), Vector3.new(0, 2.1, 0), Color3.fromRGB(150, 165, 190), Enum.PartType.Block, Enum.Material.Metal)
                makePart(model, "Left Eye", Vector3.new(0.28, 0.28, 0.15), Vector3.new(-0.4, 2.2, -0.78), Color3.fromRGB(70, 210, 255), Enum.PartType.Ball, Enum.Material.Neon)
                makePart(model, "Right Eye", Vector3.new(0.28, 0.28, 0.15), Vector3.new(0.4, 2.2, -0.78), Color3.fromRGB(70, 210, 255), Enum.PartType.Ball, Enum.Material.Neon)
            end,
        },
    })

    Items:Assets({
        {
            Name = "Energy Crystal",
            Type = "Collectible",
            Creator = "Preview Test",
            Description = "A sample neon crystal for testing the details drawer.",
            Tags = { "Collectible", "Magic", "3D" },
            Info = {
                { Label = "Rarity", Value = "Epic", Icon = "award" },
                { Label = "Element", Value = "Energy", Icon = "zap" },
            },
            Build = function(model)
                makePart(model, "Crystal Core", Vector3.new(2.2, 2.8, 2.2), Vector3.new(0, 0, 0), Color3.fromRGB(48, 125, 238), Enum.PartType.Ball, Enum.Material.Neon)
                local shard = makePart(model, "Crystal Shard", Vector3.new(0.9, 1.5, 0.9), Vector3.new(0, 1.7, 0), Color3.fromRGB(112, 225, 255), Enum.PartType.Block, Enum.Material.Glass)
                shard.CFrame = CFrame.new(0, 1.7, 0) * CFrame.Angles(0, math.rad(45), math.rad(45))
            end,
        },
    })

    Preview:Open("Models")
    print("[Preview Test] Preview opened.")
end

HostSection:Button({
    Name = "Open Legacy Preview",
    Icon = "eye",
    Callback = openPreview,
})

HostSection:Button({
    Name = "Close Preview",
    Icon = "x",
    Callback = function()
        if Preview then
            Preview:Close()
        end
    end,
})

Window:Settings()
print("[Preview Test] Host window loaded. Press Open Legacy Preview.")
