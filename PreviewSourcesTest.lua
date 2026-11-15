-- Preview Sources API test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewSourcesTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Sources Test] JustLib failed to load.") return end

local Window = Library:Window({
    Title = "Preview Sources Test",
    Config = "JustX_PreviewSourcesTest",
    Width = 520,
    Height = 420,
})
if not Window then warn("[Preview Sources Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Sources", Icon = "database" })
local Section = Host:Section({ Title = "Dynamic source test" })

local Preview = Library:Preview({
    Title = "Live Sources",
    Icon = "layers",
    TabName = "Live Sources",
    Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
    warn("[Preview Sources Test] Preview failed to initialize.")
    return
end

local Models = Preview:Tab({ Name = "Live Models", Icon = "box" })
local added = Instance.new("BindableEvent")
local removed = Instance.new("BindableEvent")
local initial = {
    { Id = "npc-1", Name = "Test NPC", Type = "NPC", Description = "Loaded from GetItems." },
}

local Source = Preview:Source({
    Name = "NPC Source",
    Tab = Models,
    GetItems = function()
        return initial
    end,
    Added = added.Event,
    Removed = removed.Event,
    Key = function(item)
        return item.Id
    end,
    Map = function(item)
        return {
            Name = item.Name,
            Type = item.Type or "Entity",
            Description = item.Description,
            Image = item.Image,
        }
    end,
})

Preview:Open("Live Models")

local counter = 0
Section:Button({
    Name = "Add NPC",
    Callback = function()
        counter = counter + 1
        local item = {
            Id = "npc-" .. tostring(counter + 1),
            Name = "Dynamic NPC " .. tostring(counter),
            Type = "NPC",
            Description = "Added through the source event.",
        }
        added:Fire(item)
    end,
})

Section:Button({
    Name = "Update first NPC",
    Callback = function()
        Source:Update("npc-1", {
            Name = "Updated Test NPC",
            Description = "This text was changed without recreating Preview.",
        })
    end,
})

Section:Button({
    Name = "Remove first NPC",
    Callback = function()
        removed:Fire(initial[1])
    end,
})

Section:Button({
    Name = "Add controller to first NPC",
    Callback = function()
        local asset = Source:Get("npc-1")
        if asset then
            asset:Toggle({
                Name = "Test Controller",
                Default = true,
                Callback = function(value)
                    print("[Preview Sources Test] Toggle:", value)
                end,
            })
            asset:Select()
        end
    end,
})

Section:Button({
    Name = "Clear source",
    Callback = function()
        Source:Clear()
    end,
})

Section:Button({
    Name = "Re-add first NPC",
    Callback = function()
        Source:Add("npc-1", initial[1])
    end,
})

print("[Preview Sources Test] Ready. Check initial item, event add/remove, update, and dynamic Controllers page.")
