-- Preview Live Grouping test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewLiveGroupingTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Live Grouping Test] JustLib failed to load.") return end

local Window = Library:Window({
    Title = "Preview Live Grouping Test",
    Config = "JustX_PreviewLiveGroupingTest",
    Width = 520,
    Height = 460,
})
if not Window then warn("[Preview Live Grouping Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Live Grouping", Icon = "layers-3" })
local Section = Host:Section({ Title = "Group assets and keep groups live" })

local Preview = Library:Preview({
    Title = "Live Grouping",
    Icon = "layers-3",
    TabName = "Live Grouping",
    Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
    warn("[Preview Live Grouping Test] Preview failed to initialize.")
    return
end

local items = {
    { Id = "A", Name = "Zebra Blade", Type = "Weapon", Creator = "Nova Studio", Category = "Melee" },
    { Id = "B", Name = "Amber Shield", Type = "Accessory", Creator = "Oak Works", Category = "Defense" },
    { Id = "C", Name = "Crystal Staff", Type = "Weapon", Creator = "Atlas Lab", Category = "Magic" },
    { Id = "D", Name = "Forest Charm", Type = "Accessory", Creator = "Oak Works" },
}

local Models = Preview:Tab({ Name = "Group Items", Icon = "layers" })
local Source = Preview:Source({
    Name = "Live Grouping Test Source",
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
            Type = item.Type,
            Creator = item.Creator,
            Category = item.Category,
        }
    end,
    Discover = {
        Enabled = true,
        Interval = 1,
        RemoveMissing = true,
    },
})

Preview:Open(Models)

local function setGrouping(key)
    local ok = Preview:SetGrouping(key)
    print("[Preview Live Grouping Test] SetGrouping:", key, "Accepted:", ok,
        "Current:", Preview:GetGrouping())
end

Section:Label({ Text = "Switch grouping modes. Check that cards are arranged under alphabetical headers, and that sorting, filtering and live updates keep the groups correct." })

Section:Button({
    Name = "Group by Type",
    Callback = function()
        setGrouping("Type")
    end,
})

Section:Button({
    Name = "Group by Creator",
    Callback = function()
        setGrouping("Creator")
    end,
})

Section:Button({
    Name = "Group by Category",
    Callback = function()
        setGrouping("Category")
    end,
})

Section:Button({
    Name = "Disable Grouping",
    Callback = function()
        setGrouping("None")
    end,
})

Section:Button({
    Name = "Update Amber Shield",
    Callback = function()
        for _, item in ipairs(items) do
            if item.Id == "B" then
                item.Name = "Zenith Shield"
                item.Type = "Weapon"
                item.Creator = "Vertex Works"
                item.Category = "Magic"
                print("[Preview Live Grouping Test] Updated item B. Its card should move into the matching live groups.")
                return
            end
        end
    end,
})

Section:Button({
    Name = "Add / Remove Test Item",
    Callback = function()
        for i, item in ipairs(items) do
            if item.Id == "E" then
                table.remove(items, i)
                print("[Preview Live Grouping Test] Removed Solar Bow.")
                return
            end
        end
        items[#items + 1] = {
            Id = "E",
            Name = "Solar Bow",
            Type = "Weapon",
            Creator = "Nova Studio",
            Category = "Ranged",
        }
        print("[Preview Live Grouping Test] Added Solar Bow.")
    end,
})

Section:Button({
    Name = "Force Sync",
    Callback = function()
        local ok, count = Source:Sync()
        print("[Preview Live Grouping Test] Sync:", ok, "Items:", count)
    end,
})

Section:Button({
    Name = "Remove Test Source",
    Callback = function()
        Source:Destroy()
        print("[Preview Live Grouping Test] Source destroyed.")
    end,
})

print("[Preview Live Grouping Test] Ready. Test Type/Creator/Category/None, then update/add/remove items while grouping is active.")
