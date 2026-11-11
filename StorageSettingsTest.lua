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
            Description = "Test the Preview layout, asset cards, variants and controls.",
            Changes = {
                "Home tab is available in the test hub.",
                "One Key asset is used to test multiple variants in one card.",
                "Three numbered sections contain Preview test controls.",
            },
        },
    },
})

local TestTab = Window:Tab({
    Name = "Preview",
    Icon = "grid",
})

local Section1 = TestTab:Section({
    Title = "1",
})

local Section2 = TestTab:Section({
    Title = "2",
})

local Section3 = TestTab:Section({
    Title = "3",
})

local Preview
local KeyAsset
local CurrentVariant = "Yellow"

local function setVariant(asset, variant)
    CurrentVariant = variant
    local details = {
        Yellow = {
            Description = "Yellow Key variant. This is the same asset card with a different selected variant.",
            Tags = {"Key", "Yellow"},
            Info = {
                {Label = "Variant", Value = "Yellow", Icon = "●"},
                {Label = "Rarity", Value = "Common", Icon = "◆"},
            },
        },
        Green = {
            Description = "Green Key variant. The asset itself remains the same; only its variant data changes.",
            Tags = {"Key", "Green"},
            Info = {
                {Label = "Variant", Value = "Green", Icon = "●"},
                {Label = "Rarity", Value = "Uncommon", Icon = "◆"},
            },
        },
        Orange = {
            Description = "Orange Key variant. The asset itself remains the same; only its variant data changes.",
            Tags = {"Key", "Orange"},
            Info = {
                {Label = "Variant", Value = "Orange", Icon = "●"},
                {Label = "Rarity", Value = "Rare", Icon = "◆"},
            },
        },
    }
    local data = details[variant]
    if asset and data then
        asset:Update({
            Name = "Key",
            Type = "Item",
            Version = variant,
            Description = data.Description,
            Tags = data.Tags,
            Info = data.Info,
        })
        print("[Preview Test] Selected variant:", variant)
    end
end

local function createPreview()
    if Preview and Preview.IsOpen and Preview:IsOpen() then
        Preview:Open({Tab = "Items", Asset = "Key"})
        return
    end

    Preview = Library:Preview({
        Title = "Preview Test",
        Icon = "⬡",
        TabName = "Preview",
    })

    if not Preview or Preview.IsStub then
        warn("[Preview Test] Preview failed to initialize. Check the JustLib warnings.")
        return
    end

    local Models = Preview:Tab({Name = "Models", Icon = "⬡"})
    local Items = Preview:Tab({Name = "Items", Icon = "▦"})

    Models:Asset({
        Name = "Oak Tree",
        Type = "Model",
        Creator = "Preview Test",
        Version = "1.0",
        Description = "A sample model asset used to inspect the card and details layout.",
        Tags = {"Nature", "Model"},
        Info = {
            {Label = "Parts", Value = "12", Icon = "▤"},
            {Label = "Size", Value = "Medium", Icon = "◫"},
        },
        Image = "rbxassetid://6031094678",
    })

    KeyAsset = Items:Asset({
        Name = "Key",
        Type = "Item",
        Creator = "Preview Test",
        Version = "Yellow",
        Description = "Yellow Key variant.",
        Tags = {"Key", "Yellow"},
        Info = {
            {Label = "Variant", Value = "Yellow", Icon = "●"},
            {Label = "Rarity", Value = "Common", Icon = "◆"},
        },
        Image = "rbxassetid://6031094678",
    })

    KeyAsset:Action({
        Name = "Yellow Key",
        Icon = "●",
        Callback = function(asset)
            setVariant(asset, "Yellow")
        end,
    })
    KeyAsset:Action({
        Name = "Green Key",
        Icon = "●",
        Callback = function(asset)
            setVariant(asset, "Green")
        end,
    })
    KeyAsset:Action({
        Name = "Orange Key",
        Icon = "●",
        Callback = function(asset)
            setVariant(asset, "Orange")
        end,
    })

    KeyAsset:Toggle({
        Name = "Enable Key",
        Default = true,
        Flag = "PreviewTest_KeyEnabled",
        Callback = function(value)
            print("[Preview Test] Key enabled:", value)
        end,
    })

    KeyAsset:Slider({
        Name = "Key Scale",
        Min = 0.5,
        Max = 3,
        Step = 0.1,
        Default = 1,
        Suffix = "x",
        Flag = "PreviewTest_KeyScale",
        Callback = function(value)
            print("[Preview Test] Key scale:", value)
        end,
    })

    KeyAsset:Button({
        Name = "Apply Variant",
        Icon = "check",
        Callback = function()
            print("[Preview Test] Applied variant:", CurrentVariant)
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

    Preview:Open({Tab = "Items", Asset = "Key"})
    print("[Preview Test] Preview opened.")
end

Section1:Button({
    Name = "Open Preview",
    Icon = "eye",
    Callback = createPreview,
})

Section1:Button({
    Name = "Switch to Yellow",
    Icon = "circle",
    Callback = function()
        if KeyAsset then setVariant(KeyAsset, "Yellow") end
    end,
})

Section2:Button({
    Name = "Switch to Green",
    Icon = "circle",
    Callback = function()
        if KeyAsset then setVariant(KeyAsset, "Green") end
    end,
})

Section2:Button({
    Name = "Switch to Orange",
    Icon = "circle",
    Callback = function()
        if KeyAsset then setVariant(KeyAsset, "Orange") end
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

print("[Preview Test] Loaded. Open the Preview tab and press Open Preview.")
