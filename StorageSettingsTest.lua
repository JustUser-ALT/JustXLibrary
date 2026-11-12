-- JustLib Preview Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/StorageSettingsTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
))()

if not Library then
    warn("[Preview Test] JustLib failed to load.")
    return
end

if Library.LoadIconPack then
    pcall(function()
        Library:LoadIconPack()
    end)
end

local Window = Library:Window({
    Title = "JustLib Preview Test",
    Config = "JustLib_PreviewTest",
    Width = 560,
    Height = 440,
})

if not Window then
    warn("[Preview Test] Window creation failed.")
    return
end

Window:HomeTab({
    WelcomeTitle = "Preview Test",
    Changelog = {
        {
            Version = "Preview",
            Title = "Preview UI Testing",
            Description = "Testing real 3D assets, Lucide icons, variant switching and asset pages.",
            Changes = {
                "Three numbered sections and a Home tab.",
                "One asset card with three real 3D variants.",
                "Actions, Info and Preview are opened from the three-dot menu.",
            },
        },
    },
})

local TestTab = Window:Tab({
    Name = "Preview",
    Icon = "grid-2x2",
})

local Section1 = TestTab:Section({Title = "1"})
local Section2 = TestTab:Section({Title = "2"})
local Section3 = TestTab:Section({Title = "3"})

local Preview
local CrystalAsset

local function makePart(parent, name, size, position, color, shape, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.Size = size
    part.Position = position
    part.Color = color
    part.Shape = shape or Enum.PartType.Block
    part.Material = material or Enum.Material.SmoothPlastic
    part.Parent = parent
    return part
end

local function crystalBuild(color, accent)
    return function(model)
        makePart(model, "Crystal Core", Vector3.new(2.2, 2.8, 2.2), Vector3.new(0, 0, 0), color, Enum.PartType.Ball, Enum.Material.Neon)
        local top = makePart(model, "Top Shard", Vector3.new(0.9, 1.5, 0.9), Vector3.new(0, 1.7, 0), accent, Enum.PartType.Block, Enum.Material.Glass)
        top.CFrame = CFrame.new(0, 1.7, 0) * CFrame.Angles(0, math.rad(45), math.rad(45))
        local left = makePart(model, "Left Orb", Vector3.new(0.55, 0.55, 0.55), Vector3.new(-1.2, -0.6, 0), accent, Enum.PartType.Ball, Enum.Material.Neon)
        local right = makePart(model, "Right Orb", Vector3.new(0.55, 0.55, 0.55), Vector3.new(1.2, -0.6, 0), accent, Enum.PartType.Ball, Enum.Material.Neon)
    end
end

local function treeBuild(model)
    makePart(model, "Trunk", Vector3.new(1.2, 4, 1.2), Vector3.new(0, -1, 0), Color3.fromRGB(112, 76, 48), Enum.PartType.Cylinder)
    makePart(model, "Leaves", Vector3.new(4.5, 4.5, 4.5), Vector3.new(0, 2, 0), Color3.fromRGB(62, 166, 92), Enum.PartType.Ball, Enum.Material.Grass)
    makePart(model, "Fruit", Vector3.new(0.65, 0.65, 0.65), Vector3.new(1.1, 1.1, -1.2), Color3.fromRGB(240, 174, 62), Enum.PartType.Ball, Enum.Material.Neon)
end

local function robotBuild(model)
    makePart(model, "Body", Vector3.new(2.2, 2.6, 1.3), Vector3.new(0, 0, 0), Color3.fromRGB(92, 105, 128))
    makePart(model, "Head", Vector3.new(1.7, 1.5, 1.5), Vector3.new(0, 2.1, 0), Color3.fromRGB(150, 165, 190), Enum.PartType.Block, Enum.Material.Metal)
    makePart(model, "Left Eye", Vector3.new(0.28, 0.28, 0.15), Vector3.new(-0.4, 2.2, -0.78), Color3.fromRGB(70, 210, 255), Enum.PartType.Ball, Enum.Material.Neon)
    makePart(model, "Right Eye", Vector3.new(0.28, 0.28, 0.15), Vector3.new(0.4, 2.2, -0.78), Color3.fromRGB(70, 210, 255), Enum.PartType.Ball, Enum.Material.Neon)
    makePart(model, "Left Arm", Vector3.new(0.6, 2.2, 0.7), Vector3.new(-1.5, 0, 0), Color3.fromRGB(110, 125, 150))
    makePart(model, "Right Arm", Vector3.new(0.6, 2.2, 0.7), Vector3.new(1.5, 0, 0), Color3.fromRGB(110, 125, 150))
end

local function createPreview()
    if Preview and Preview.IsOpen and Preview:IsOpen() then
        Preview:Open({Tab = "Items", Asset = "Energy Crystal"})
        return
    end

    Preview = Library:Preview({
        Title = "Preview Test",
        Icon = "box",
        TabName = "Preview",
    })

    if not Preview or Preview.IsStub then
        warn("[Preview Test] Preview failed to initialize. Check JustLib warnings.")
        return
    end

    local Models = Preview:Tab({Name = "Models", Icon = "trees"})
    local Items = Preview:Tab({Name = "Items", Icon = "gem"})

    Models:Asset({
        Name = "Oak Tree",
        Icon = "trees",
        Type = "Environment Model",
        Creator = "Preview Test",
        Version = "1.0",
        Description = "A small stylized tree built from actual 3D parts. This is a generated preview, not an image placeholder.",
        Tags = {"Nature", "Environment", "3D"},
        Info = {
            {Label = "Parts", Value = "3", Icon = "boxes"},
            {Label = "Category", Value = "Environment", Icon = "leaf"},
        },
        Build = treeBuild,
    })

    Models:Asset({
        Name = "Mini Robot",
        Icon = "bot",
        Type = "Character Model",
        Creator = "Preview Test",
        Version = "1.0",
        Description = "A small robot assembled from separate body parts.",
        Tags = {"Robot", "Character", "3D"},
        Info = {
            {Label = "Parts", Value = "6", Icon = "boxes"},
            {Label = "Category", Value = "Character", Icon = "bot"},
        },
        Build = robotBuild,
    })

    CrystalAsset = Items:Asset({
        Name = "Energy Crystal",
        Icon = "gem",
        Type = "Collectible",
        Creator = "Preview Test",
        Description = "Choose a variant below. The 3D model, color, details and selected state change together.",
        Tags = {"Collectible", "Magic", "3D"},
        Variants = {
            {
                Name = "Ruby",
                Icon = "circle",
                Version = "Ruby",
                Description = "Ruby energy crystal. A hot red core with a bright glass shard.",
                Tags = {"Collectible", "Ruby", "Fire"},
                Build = crystalBuild(Color3.fromRGB(225, 48, 72), Color3.fromRGB(255, 174, 74)),
                Info = {
                    {Label = "Variant", Value = "Ruby", Icon = "gem"},
                    {Label = "Element", Value = "Fire", Icon = "flame"},
                    {Label = "Rarity", Value = "Rare", Icon = "award"},
                },
            },
            {
                Name = "Sapphire",
                Icon = "circle",
                Version = "Sapphire",
                Description = "Sapphire energy crystal. A cool blue core with icy highlights.",
                Tags = {"Collectible", "Sapphire", "Ice"},
                Build = crystalBuild(Color3.fromRGB(48, 125, 238), Color3.fromRGB(112, 225, 255)),
                Info = {
                    {Label = "Variant", Value = "Sapphire", Icon = "gem"},
                    {Label = "Element", Value = "Ice", Icon = "snowflake"},
                    {Label = "Rarity", Value = "Epic", Icon = "award"},
                },
            },
            {
                Name = "Emerald",
                Icon = "circle",
                Version = "Emerald",
                Description = "Emerald energy crystal. A vivid green core with luminous accents.",
                Tags = {"Collectible", "Emerald", "Nature"},
                Build = crystalBuild(Color3.fromRGB(44, 190, 112), Color3.fromRGB(170, 255, 126)),
                Info = {
                    {Label = "Variant", Value = "Emerald", Icon = "gem"},
                    {Label = "Element", Value = "Nature", Icon = "sprout"},
                    {Label = "Rarity", Value = "Legendary", Icon = "award"},
                },
            },
        },
    })

    CrystalAsset:Action({
        Name = "Reset Variant",
        Icon = "rotate-ccw",
        Callback = function(asset)
            asset:SetVariant("Ruby")
        end,
    })

    CrystalAsset:Toggle({
        Name = "Enable Crystal",
        Default = true,
        Flag = "PreviewTest_CrystalEnabled",
        Callback = function(value)
            print("[Preview Test] Crystal enabled:", value)
        end,
    })

    CrystalAsset:Slider({
        Name = "Crystal Scale",
        Min = 0.5,
        Max = 3,
        Step = 0.1,
        Default = 1,
        Suffix = "x",
        Flag = "PreviewTest_CrystalScale",
        Callback = function(value)
            print("[Preview Test] Crystal scale:", value)
        end,
    })

    CrystalAsset:Button({
        Name = "Apply Variant",
        Icon = "check",
        Callback = function()
            print("[Preview Test] Applied variant:", CrystalAsset._variantName or "Ruby")
        end,
    })

    Items:Toggle({
        Name = "Enable Item Actions",
        Default = false,
        Flag = "PreviewTest_ItemsEnabled",
        Callback = function(value)
            print("[Preview Test] Shared Items toggle:", value)
        end,
    })

    Preview:Open({Tab = "Items", Asset = "Energy Crystal", Page = "preview"})
    print("[Preview Test] Preview opened.")
end

Section1:Button({
    Name = "Open Preview",
    Icon = "eye",
    Callback = createPreview,
})

Section1:Button({
    Name = "Switch to Ruby",
    Icon = "gem",
    Callback = function()
        if CrystalAsset then CrystalAsset:SetVariant("Ruby") end
    end,
})

Section2:Button({
    Name = "Switch to Sapphire",
    Icon = "gem",
    Callback = function()
        if CrystalAsset then CrystalAsset:SetVariant("Sapphire") end
    end,
})

Section2:Button({
    Name = "Switch to Emerald",
    Icon = "gem",
    Callback = function()
        if CrystalAsset then CrystalAsset:SetVariant("Emerald") end
    end,
})

Section3:Toggle({
    Name = "Test Toggle",
    Flag = "PreviewTest_HubToggle",
    Default = true,
    Callback = function(value)
        print("[Preview Test] Hub toggle:", value)
    end,
})

Section3:Slider({
    Name = "Test Slider",
    Flag = "PreviewTest_HubSlider",
    Min = 0,
    Max = 100,
    Step = 1,
    Default = 50,
    Suffix = "%",
    Callback = function(value)
        print("[Preview Test] Hub slider:", value)
    end,
})

Window:Settings()

print("[Preview Test] Loaded. Open Preview and press Open Preview.")
