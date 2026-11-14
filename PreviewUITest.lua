--[[
    JustXLibrary - Legacy Preview UI Test
    Tests the restored PreviewUI.lua inside the real JustXLibrary window.
    Run in Delta / client executor.

    This is a test harness only. It does not modify the library or PreviewUI.
]]

local BASE = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/"

local function fetchModule(path)
    local ok, body = pcall(function()
        return game:HttpGet(BASE .. path)
    end)
    if not ok or type(body) ~= "string" or body == "" then
        error("Download failed: " .. path .. " | " .. tostring(body))
    end

    local fn, compileError = loadstring(body)
    if not fn then
        error("Compile failed: " .. path .. " | " .. tostring(compileError))
    end

    local okRun, result = pcall(fn)
    if not okRun then
        error("Execution failed: " .. path .. " | " .. tostring(result))
    end

    return result
end

local JL = fetchModule("JustLib.lua")
if type(JL) ~= "table" or type(JL.Window) ~= "function" then
    error("JustLib.lua did not return a valid library table")
end

-- Create the host window first: the legacy Preview is a tab inside this window.
local Window = JL:Window({
    Title = "Preview UI Test",
    HubId = "PreviewUITest",
    Settings = false,
    LoadIcons = false,
})

if not Window then
    error("JustLib:Window failed")
end

local Preview = JL:Preview({
    Title = "Asset Preview",
    Icon = "⬡",
    TabName = "Preview",
    Source = BASE .. "PreviewUI.lua",
})

if type(Preview) ~= "table" or Preview.IsStub then
    JL:Notify({
        Title = "Preview Test",
        Desc = "PreviewUI failed to load. Check the executor console for the exact error.",
        Type = "Error",
        Duration = 8,
    })
    return
end

local Models = Preview:Tab({ Name = "Models", Icon = "⬡" })
local Items = Preview:Tab({ Name = "Items", Icon = "▦" })
local All = Preview:Tab({ Name = "All", Icon = "✦", ShowAll = true })

Models:Assets({
    {
        Name = "Oak Tree",
        Type = "Model",
        Creator = "Preview Test",
        Created = "14.11.2026",
        Size = "1.5 MB",
        Version = "1.0",
        Description = "A sample model used to check the legacy Preview layout.",
        Tags = { "Nature", "Environment", "Test" },
        Info = {
            { Label = "Parts", Value = "12", Icon = "▤" },
            { Label = "Category", Value = "Nature", Icon = "◆" },
        },
        Build = function(model)
            local trunk = Instance.new("Part")
            trunk.Name = "Trunk"
            trunk.Anchored = true
            trunk.Size = Vector3.new(1.4, 5, 1.4)
            trunk.Position = Vector3.new(0, 2.5, 0)
            trunk.Color = Color3.fromRGB(105, 75, 48)
            trunk.Parent = model

            local leaves = Instance.new("Part")
            leaves.Name = "Leaves"
            leaves.Anchored = true
            leaves.Shape = Enum.PartType.Ball
            leaves.Size = Vector3.new(5, 5, 5)
            leaves.Position = Vector3.new(0, 6, 0)
            leaves.Color = Color3.fromRGB(65, 135, 82)
            leaves.Parent = model
        end,
        Actions = {
            {
                Name = "Test action",
                Icon = "✓",
                Callback = function()
                    JL:Notify({ Title = "Preview Test", Desc = "Oak Tree action works.", Type = "Success", Duration = 3 })
                end,
            },
        },
    },
    {
        Name = "Stone Pillar",
        Type = "Model",
        Creator = "Preview Test",
        Description = "Second sample card for checking the asset grid and selection drawer.",
        Tags = { "Stone", "Structure" },
        Build = function(model)
            local pillar = Instance.new("Part")
            pillar.Name = "Pillar"
            pillar.Anchored = true
            pillar.Size = Vector3.new(2, 7, 2)
            pillar.Position = Vector3.new(0, 3.5, 0)
            pillar.Material = Enum.Material.Slate
            pillar.Color = Color3.fromRGB(115, 120, 130)
            pillar.Parent = model
        end,
    },
    {
        Name = "Neon Crystal",
        Type = "Model",
        Creator = "Preview Test",
        Description = "A bright sample model for checking the 3D viewport.",
        Tags = { "Decoration", "Neon" },
        Build = function(model)
            local crystal = Instance.new("Part")
            crystal.Name = "Crystal"
            crystal.Anchored = true
            crystal.Size = Vector3.new(2, 4, 2)
            crystal.Position = Vector3.new(0, 2, 0)
            crystal.Material = Enum.Material.Neon
            crystal.Color = Color3.fromRGB(90, 160, 255)
            crystal.Parent = model
        end,
    },
})

Items:Assets({
    {
        Name = "Health Potion",
        Type = "Tool",
        Creator = "Preview Test",
        Description = "Sample item card with tags and custom information.",
        Tags = { "Consumable", "Test" },
        Info = {
            { Label = "Rarity", Value = "Rare", Icon = "✦" },
            { Label = "Stack", Value = "10", Icon = "▤" },
        },
        Image = "rbxassetid://0",
    },
    {
        Name = "Iron Sword",
        Type = "Tool",
        Creator = "Preview Test",
        Description = "Another item to test scrolling and switching categories.",
        Tags = { "Weapon", "Melee" },
        Image = "rbxassetid://0",
    },
})

Preview:Toggle("Models")
Preview:OnClosed(function()
    -- The host window remains open; only the Preview tab is removed.
end)

JL:Notify({
    Title = "Preview Test",
    Desc = "Legacy Preview loaded. Check the tab size, cards, drawer, scrolling and mobile layout.",
    Type = "Success",
    Duration = 5,
})
