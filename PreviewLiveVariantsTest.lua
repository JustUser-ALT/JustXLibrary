-- Preview live variants test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewLiveVariantsTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Live Variants Test] JustLib failed to load.") return end

local Window = Library:Window({
    Title = "Preview Live Variants Test",
    Config = "JustX_PreviewLiveVariantsTest",
    Width = 520,
    Height = 440,
})
if not Window then warn("[Preview Live Variants Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Live Variants", Icon = "layers" })
local Section = Host:Section({ Title = "Dynamic variant updates" })

local Preview = Library:Preview({
    Title = "Live Variants",
    Icon = "layers",
    TabName = "Live Variants",
    Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
    warn("[Preview Live Variants Test] Preview failed to initialize.")
    return
end

local function makeModel(name, color, height)
    local model = Instance.new("Model")
    model.Name = name

    local body = Instance.new("Part")
    body.Name = "Body"
    body.Anchored = true
    body.Size = Vector3.new(3, height or 4, 2)
    body.Color = color
    body.Position = Vector3.new(0, (height or 4) / 2, 0)
    body.Parent = model

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Anchored = true
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(2, 2, 2)
    head.Color = Color3.fromRGB(235, 195, 145)
    head.Position = Vector3.new(0, (height or 4) + 1, 0)
    head.Parent = model

    model.PrimaryPart = body
    model.Parent = workspace
    return model
end

local baseModel = makeModel("PreviewVariantBase", Color3.fromRGB(115, 120, 135))
local outfitOne = makeModel("PreviewVariantBlue", Color3.fromRGB(65, 145, 235))
local outfitTwo = makeModel("PreviewVariantRed", Color3.fromRGB(225, 95, 90))
local outfitThree = makeModel("PreviewVariantGreen", Color3.fromRGB(80, 195, 130), 5)

local variants = {
    { Name = "Blue Outfit", Model = outfitOne, Description = "First live outfit variant." },
    { Name = "Red Outfit", Model = outfitTwo, Description = "Second live outfit variant." },
}

local Models = Preview:Tab({ Name = "Workspace Models", Icon = "box" })
local Source = Preview:Source({
    Name = "Live Character",
    Tab = Models,
    GetItems = function()
        return { "LiveCharacter" }
    end,
    Key = function(item)
        return item
    end,
    Map = function()
        return {
            Name = "Live Character",
            Type = "Player Model",
            Description = "Variants are rebuilt dynamically from the current game state.",
            Model = baseModel,
            Variants = variants,
        }
    end,
})

Preview:Open({ Tab = Models, Asset = "Live Character" })

local function refresh()
    Source:Refresh("LiveCharacter")
end

Section:Button({
    Name = "Add Green Outfit",
    Callback = function()
        local found = false
        for _, variant in ipairs(variants) do
            if variant.Name == "Green Outfit" then found = true end
        end
        if not found then
            variants[#variants + 1] = {
                Name = "Green Outfit",
                Model = outfitThree,
                Description = "Added while Preview is already open.",
            }
        end
        refresh()
    end,
})

Section:Button({
    Name = "Update Blue Outfit",
    Callback = function()
        outfitOne = makeModel("PreviewVariantBlueUpdated", Color3.fromRGB(
            math.random(70, 230), math.random(70, 230), math.random(70, 230)
        ), math.random(3, 6))
        for i, variant in ipairs(variants) do
            if variant.Name == "Blue Outfit" then
                variants[i] = {
                    Name = "Blue Outfit",
                    Model = outfitOne,
                    Description = "Updated live without changing its selected name.",
                }
                break
            end
        end
        refresh()
    end,
})

Section:Button({
    Name = "Remove Red Outfit",
    Callback = function()
        for i = #variants, 1, -1 do
            if variants[i].Name == "Red Outfit" then
                table.remove(variants, i)
            end
        end
        refresh()
    end,
})

Section:Button({
    Name = "Remove All Variants",
    Callback = function()
        table.clear(variants)
        refresh()
    end,
})

Section:Button({
    Name = "Restore Default Variants",
    Callback = function()
        variants = {
            { Name = "Blue Outfit", Model = outfitOne, Description = "Restored blue outfit." },
            { Name = "Red Outfit", Model = outfitTwo, Description = "Restored red outfit." },
        }
        refresh()
    end,
})

Section:Button({
    Name = "Remove Test Models",
    Callback = function()
        Source:Remove("LiveCharacter")
        for _, model in ipairs({ baseModel, outfitOne, outfitTwo, outfitThree }) do
            if model and model.Parent then model:Destroy() end
        end
    end,
})

print("[Preview Live Variants Test] Ready. Open the asset and test adding, updating, removing, and restoring variants.")
