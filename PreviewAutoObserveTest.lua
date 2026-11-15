-- Preview automatic live model observation test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewAutoObserveTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Auto Observe Test] JustLib failed to load.") return end

local Window = Library:Window({
    Title = "Preview Auto Observe Test",
    Config = "JustX_PreviewAutoObserveTest",
    Width = 520,
    Height = 440,
})
if not Window then warn("[Preview Auto Observe Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Auto Observe", Icon = "eye" })
local Section = Host:Section({ Title = "Live model observation" })

local Preview = Library:Preview({
    Title = "Auto Observe",
    Icon = "eye",
    TabName = "Auto Observe",
    Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
    warn("[Preview Auto Observe Test] Preview failed to initialize.")
    return
end

local function makeModel(name, color)
    local model = Instance.new("Model")
    model.Name = name
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Anchored = true
    body.Size = Vector3.new(3, 4, 2)
    body.Color = color
    body.Position = Vector3.new(0, 2, 0)
    body.Parent = model
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Anchored = true
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(2, 2, 2)
    head.Color = Color3.fromRGB(235, 195, 145)
    head.Position = Vector3.new(0, 5, 0)
    head.Parent = model
    model.PrimaryPart = body
    model.Parent = workspace
    return model
end

local baseModel = makeModel("AutoObserveBase", Color3.fromRGB(115, 120, 135))
local variantModel = makeModel("AutoObserveVariant", Color3.fromRGB(65, 145, 235))
local addedPart

local Models = Preview:Tab({ Name = "Models", Icon = "box" })
local Source = Preview:Source({
    Name = "Observed Model",
    Tab = Models,
    ObserveModels = {
        Debounce = 0.18,
    },
    GetItems = function()
        return { "ObservedModel" }
    end,
    Key = function(item)
        return item
    end,
    Map = function()
        return {
            Name = "Observed Model",
            Type = "Live Model",
            Description = "Changes to part properties and model structure are observed automatically.",
            Model = baseModel,
            Variants = {
                { Name = "Blue Variant", Model = variantModel },
            },
        }
    end,
})

Preview:Open({ Tab = Models, Asset = "Observed Model" })

Section:Button({
    Name = "Change Base Color + Size",
    Callback = function()
        local body = baseModel:FindFirstChild("Body")
        if body then
            body.Color = Color3.fromRGB(math.random(65, 235), math.random(65, 235), math.random(65, 235))
            body.Size = Vector3.new(3, math.random(3, 7), 2)
        end
    end,
})

Section:Button({
    Name = "Add Part",
    Callback = function()
        if addedPart and addedPart.Parent then return end
        addedPart = Instance.new("Part")
        addedPart.Name = "LiveAddedPart"
        addedPart.Anchored = true
        addedPart.Size = Vector3.new(1.5, 1.5, 1.5)
        addedPart.Color = Color3.fromRGB(235, 175, 65)
        addedPart.Position = Vector3.new(2.5, 1, 0)
        addedPart.Parent = baseModel
    end,
})

Section:Button({
    Name = "Remove Added Part",
    Callback = function()
        if addedPart then
            addedPart:Destroy()
            addedPart = nil
        end
    end,
})

Section:Button({
    Name = "Change Variant Model",
    Callback = function()
        local body = variantModel:FindFirstChild("Body")
        if body then
            body.Color = Color3.fromRGB(math.random(65, 235), math.random(65, 235), math.random(65, 235))
            body.Size = Vector3.new(3, math.random(3, 7), 2)
        end
    end,
})

Section:Button({
    Name = "Disable Auto Observe",
    Callback = function()
        Source:SetAutoObserve("ObservedModel", false)
    end,
})

Section:Button({
    Name = "Enable Auto Observe",
    Callback = function()
        Source:SetAutoObserve("ObservedModel", true)
    end,
})

Section:Button({
    Name = "Remove Test Models",
    Callback = function()
        Source:Remove("ObservedModel")
        for _, model in ipairs({ baseModel, variantModel }) do
            if model and model.Parent then model:Destroy() end
        end
    end,
})

print("[Preview Auto Observe Test] Ready. Change part color/size, add/remove a part, and switch to the variant to test automatic updates.")
