-- Preview live model test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewLiveModelsTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Live Models Test] JustLib failed to load.") return end

local Window = Library:Window({
    Title = "Preview Live Models Test",
    Config = "JustX_PreviewLiveModelsTest",
    Width = 520,
    Height = 420,
})
if not Window then warn("[Preview Live Models Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Live Models", Icon = "box" })
local Section = Host:Section({ Title = "Live model refresh" })

local Preview = Library:Preview({
    Title = "Live Models",
    Icon = "layers",
    TabName = "Live Models",
    Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
    warn("[Preview Live Models Test] Preview failed to initialize.")
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
    body.Position = Vector3.new(0, 3, 0)
    body.Parent = model

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Anchored = true
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(2, 2, 2)
    head.Color = Color3.fromRGB(235, 195, 145)
    head.Position = Vector3.new(0, 6, 0)
    head.Parent = model

    model.PrimaryPart = body
    model.Parent = workspace
    return model
end

local model = makeModel("PreviewLiveNPC", Color3.fromRGB(70, 145, 235))
local changed = Instance.new("BindableEvent")

local Models = Preview:Tab({ Name = "Workspace Models", Icon = "box" })
local Source = Preview:Source({
    Name = "Live NPC",
    Tab = Models,
    GetItems = function()
        return { model }
    end,
    Changed = changed.Event,
    Key = function(item)
        return item:GetAttribute("PreviewKey") or item.Name
    end,
    Map = function(item)
        return {
            Name = item.Name,
            Type = "Live Model",
            Description = "A Workspace model displayed as a safe viewport clone.",
            Model = item,
        }
    end,
})

Preview:Open({ Tab = Models, Asset = "PreviewLiveNPC" })

Section:Button({
    Name = "Add model part + Refresh",
    Callback = function()
        local extra = Instance.new("Part")
        extra.Name = "AddedPart"
        extra.Anchored = true
        extra.Size = Vector3.new(1, 1, 1)
        extra.Color = Color3.fromRGB(105, 220, 145)
        extra.Position = Vector3.new(2.2, 5, 0)
        extra.Parent = model
        Source:Refresh("PreviewLiveNPC")
    end,
})

Section:Button({
    Name = "Change model color + Refresh",
    Callback = function()
        local body = model:FindFirstChild("Body")
        if body then
            body.Color = Color3.fromRGB(math.random(70, 235), math.random(70, 235), math.random(70, 235))
            Source:Refresh("PreviewLiveNPC")
        end
    end,
})

Section:Button({
    Name = "Fire Changed event",
    Callback = function()
        changed:Fire(model)
    end,
})

Section:Button({
    Name = "Replace model",
    Callback = function()
        local oldModel = model
        model = makeModel("PreviewLiveNPC", Color3.fromRGB(220, 125, 75))
        Source:Add("PreviewLiveNPC", model)
        oldModel:Destroy()
    end,
})

Section:Button({
    Name = "Remove model",
    Callback = function()
        Source:Remove("PreviewLiveNPC")
        if model then
            model:Destroy()
        end
    end,
})

Section:Button({
    Name = "Re-add model",
    Callback = function()
        if not model or not model.Parent then
            model = makeModel("PreviewLiveNPC", Color3.fromRGB(70, 145, 235))
        end
        Source:Add("PreviewLiveNPC", model)
    end,
})

print("[Preview Live Models Test] Ready. Select the model in Preview, then test refresh, Changed, replacement, and removal.")
