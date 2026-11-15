-- Preview Live Discovery test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewLiveDiscoveryTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Live Discovery Test] JustLib failed to load.") return end

local Window = Library:Window({
    Title = "Preview Live Discovery Test",
    Config = "JustX_PreviewLiveDiscoveryTest",
    Width = 520,
    Height = 440,
})
if not Window then warn("[Preview Live Discovery Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Live Discovery", Icon = "scan-search" })
local Section = Host:Section({ Title = "Automatic source discovery" })

local Preview = Library:Preview({
    Title = "Live Discovery",
    Icon = "scan-search",
    TabName = "Live Discovery",
    Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
    warn("[Preview Live Discovery Test] Preview failed to initialize.")
    return
end

local items = {
    { Id = "A", Name = "Discovery Item A", Color = Color3.fromRGB(85, 155, 235) },
    { Id = "B", Name = "Discovery Item B", Color = Color3.fromRGB(225, 145, 75) },
}

local Models = Preview:Tab({ Name = "Discovered", Icon = "layers" })
local Source = Preview:Source({
    Name = "Discovery Test Items",
    Tab = Models,
    GetItems = function()
        return items
    end,
    Key = function(item)
        return item.Id
    end,
    Map = function(item)
        return {
            Name = item.Name,
            Type = "Discovery Test",
            Description = "This card is maintained by periodic Source discovery.",
            Info = {
                { Label = "ID", Value = item.Id },
                { Label = "Color", Value = tostring(item.Color) },
            },
            Image = nil,
        }
    end,
    Discover = {
        Enabled = true,
        Interval = 1,
        RemoveMissing = true,
    },
})

Preview:Open({ Tab = Models, Asset = "Discovery Item A" })

Section:Button({
    Name = "Add Item C",
    Callback = function()
        for _, item in ipairs(items) do
            if item.Id == "C" then return end
        end
        items[#items + 1] = {
            Id = "C",
            Name = "Discovery Item C",
            Color = Color3.fromRGB(105, 205, 135),
        }
        print("[Preview Live Discovery Test] Added C to source collection. It should appear automatically.")
    end,
})

Section:Button({
    Name = "Rename Item B",
    Callback = function()
        for _, item in ipairs(items) do
            if item.Id == "B" then
                item.Name = "Discovery Item B Updated"
                item.Color = Color3.fromRGB(175, 115, 225)
                print("[Preview Live Discovery Test] Updated B. Its existing card should update automatically.")
                return
            end
        end
    end,
})

Section:Button({
    Name = "Remove Item A",
    Callback = function()
        for i, item in ipairs(items) do
            if item.Id == "A" then
                table.remove(items, i)
                print("[Preview Live Discovery Test] Removed A from source collection. Its card should disappear automatically.")
                return
            end
        end
    end,
})

Section:Button({
    Name = "Force Sync",
    Callback = function()
        local ok, count = Source:Sync()
        print("[Preview Live Discovery Test] Sync:", ok, "Items:", count)
    end,
})

Section:Button({
    Name = "Disable Discovery",
    Callback = function()
        Source:SetDiscovery(false)
        print("[Preview Live Discovery Test] Discovery enabled:", Source:IsDiscoveryEnabled())
    end,
})

Section:Button({
    Name = "Enable Discovery",
    Callback = function()
        Source:SetDiscovery(true)
        print("[Preview Live Discovery Test] Discovery enabled:", Source:IsDiscoveryEnabled())
    end,
})

Section:Button({
    Name = "Remove Test Source",
    Callback = function()
        Source:Destroy()
        print("[Preview Live Discovery Test] Source destroyed.")
    end,
})

print("[Preview Live Discovery Test] Ready. Add C, rename B, and remove A. Changes should be discovered within about one second.")
