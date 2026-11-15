-- Preview Live Sorting test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewLiveSortingTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Live Sorting Test] JustLib failed to load.") return end

local Window = Library:Window({
    Title = "Preview Live Sorting Test",
    Config = "JustX_PreviewLiveSortingTest",
    Width = 520,
    Height = 440,
})
if not Window then warn("[Preview Live Sorting Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Live Sorting", Icon = "arrow-down-wide-narrow" })
local Section = Host:Section({ Title = "Sort assets and keep order live" })

local Preview = Library:Preview({
    Title = "Live Sorting",
    Icon = "arrow-down-wide-narrow",
    TabName = "Live Sorting",
    Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
    warn("[Preview Live Sorting Test] Preview failed to initialize.")
    return
end

local items = {
    { Id = "A", Name = "Zebra Blade", Type = "Weapon", Creator = "Nova Studio", Version = "1.0" },
    { Id = "B", Name = "Amber Shield", Type = "Accessory", Creator = "Oak Works", Version = "2.0" },
    { Id = "C", Name = "Crystal Staff", Type = "Weapon", Creator = "Atlas Lab", Version = "1.5" },
}

local Models = Preview:Tab({ Name = "Sort Items", Icon = "layers" })
local Source = Preview:Source({
    Name = "Live Sorting Test Source",
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
            Version = item.Version,
        }
    end,
    Discover = {
        Enabled = true,
        Interval = 1,
        RemoveMissing = true,
    },
})

Preview:Open(Models)

local function setSort(key, descending)
    local ok = Preview:SetSort(key, descending)
    local currentKey, currentDescending = Preview:GetSort()
    print("[Preview Live Sorting Test] SetSort:", key, descending, "Accepted:", ok,
        "Current:", currentKey, currentDescending)
end

Section:Label({ Text = "Try each sort mode and check the card order. Sorting applies to the current filtered results and stays active during live updates." })

Section:Button({
    Name = "Name A → Z",
    Callback = function()
        setSort("Name", false)
    end,
})

Section:Button({
    Name = "Name Z → A",
    Callback = function()
        setSort("Name", true)
    end,
})

Section:Button({
    Name = "Type A → Z",
    Callback = function()
        setSort("Type", false)
    end,
})

Section:Button({
    Name = "Creator A → Z",
    Callback = function()
        setSort("Creator", false)
    end,
})

Section:Button({
    Name = "Default Order",
    Callback = function()
        setSort("Default", false)
    end,
})

Section:Button({
    Name = "Update Amber Shield",
    Callback = function()
        for _, item in ipairs(items) do
            if item.Id == "B" then
                item.Name = "Zenith Shield"
                item.Creator = "Vertex Works"
                item.Type = "Weapon"
                print("[Preview Live Sorting Test] Updated item B. Active Name/Creator/Type sorting should reposition it after discovery.")
                return
            end
        end
    end,
})

Section:Button({
    Name = "Add / Remove Test Item",
    Callback = function()
        for i, item in ipairs(items) do
            if item.Id == "D" then
                table.remove(items, i)
                print("[Preview Live Sorting Test] Removed Delta Hammer.")
                return
            end
        end
        items[#items + 1] = {
            Id = "D",
            Name = "Delta Hammer",
            Type = "Tool",
            Creator = "Nova Studio",
            Version = "1.1",
        }
        print("[Preview Live Sorting Test] Added Delta Hammer.")
    end,
})

Section:Button({
    Name = "Force Sync",
    Callback = function()
        local ok, count = Source:Sync()
        print("[Preview Live Sorting Test] Sync:", ok, "Items:", count)
    end,
})

Section:Button({
    Name = "Remove Test Source",
    Callback = function()
        Source:Destroy()
        print("[Preview Live Sorting Test] Source destroyed.")
    end,
})

print("[Preview Live Sorting Test] Ready. Test ascending/descending, different fields, then update/add/remove items while sorting is active.")
