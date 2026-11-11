-- JustLib Preview UI test
-- Run this script to create and open a standalone Preview UI with sample assets.
-- It tests the Preview window, tabs, asset cards, details drawer, and asset controls.

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

local Preview = Library:Preview({
    Title = "Preview UI Test",
    Icon = "⬡",
    TabName = "Preview Test",
})

if not Preview or Preview.IsStub then
    warn("[Preview Test] Preview UI failed to initialize. Check the JustLib console warnings.")
    return
end

local Models = Preview:Tab({Name = "Models", Icon = "⬡"})
local Items = Preview:Tab({Name = "Items", Icon = "▦"})

local Tree = Models:Asset({
    Name = "Oak Tree",
    Type = "Model",
    Creator = "Preview Test",
    Version = "1.0",
    Description = "A sample model asset used to test the Preview details panel.",
    Tags = {"Nature", "Model"},
    Info = {
        {Label = "Parts", Value = "12", Icon = "▤"},
        {Label = "Size", Value = "Medium", Icon = "◫"},
    },
    Image = "rbxassetid://6031094678",
})

Tree:Toggle({
    Name = "Enable Tree",
    Default = true,
    Flag = "PreviewTest_TreeEnabled",
    Callback = function(value)
        print("[Preview Test] Tree toggle:", value)
    end,
})

Tree:Slider({
    Name = "Tree Scale",
    Min = 0.5,
    Max = 3,
    Step = 0.1,
    Default = 1,
    Suffix = "x",
    Flag = "PreviewTest_TreeScale",
    Callback = function(value)
        print("[Preview Test] Tree scale:", value)
    end,
})

Tree:Button({
    Name = "Test Action",
    Icon = "✓",
    Callback = function()
        print("[Preview Test] Tree action clicked")
    end,
})

Items:Asset({
    Name = "Yellow Key",
    Type = "Item",
    Creator = "Preview Test",
    Version = "1.0",
    Description = "A sample key item.",
    Tags = {"Key", "Yellow"},
    Info = {
        {Label = "Color", Value = "Yellow", Icon = "●"},
        {Label = "Rarity", Value = "Common", Icon = "◆"},
    },
    Image = "rbxassetid://6031094678",
})

Items:Asset({
    Name = "Green Key",
    Type = "Item",
    Creator = "Preview Test",
    Version = "1.0",
    Description = "Another sample item for testing the asset list.",
    Tags = {"Key", "Green"},
    Info = {
        {Label = "Color", Value = "Green", Icon = "●"},
        {Label = "Rarity", Value = "Uncommon", Icon = "◆"},
    },
    Image = "rbxassetid://6031094678",
})

Items:Toggle({
    Name = "Enable Item Actions",
    Default = false,
    Flag = "PreviewTest_ItemsEnabled",
    Callback = function(value)
        print("[Preview Test] Shared Items toggle:", value)
    end,
})

Preview:Open({Tab = "Models", Asset = "Oak Tree"})
print("[Preview Test] Preview UI opened.")
