-- Preview Live Search test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewLiveSearchTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Live Search Test] JustLib failed to load.") return end

local Window = Library:Window({
    Title = "Preview Live Search Test",
    Config = "JustX_PreviewLiveSearchTest",
    Width = 520,
    Height = 440,
})
if not Window then warn("[Preview Live Search Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Live Search", Icon = "search" })
local Section = Host:Section({ Title = "Search updates and metadata matching" })

local Preview = Library:Preview({
    Title = "Live Search",
    Icon = "search",
    TabName = "Live Search",
    Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
    warn("[Preview Live Search Test] Preview failed to initialize.")
    return
end

local items = {
    {
        Id = "A",
        Name = "Neon Sword",
        Creator = "Nova Studio",
        Type = "Weapon",
        Description = "A glowing energy blade.",
        Tags = { "Sci-Fi", "Melee" },
        Version = "2.1",
        Info = {
            { Label = "Rarity", Value = "Legendary" },
            { Label = "Damage", Value = "85" },
        },
        Color = Color3.fromRGB(190, 85, 255),
    },
    {
        Id = "B",
        Name = "Forest Shield",
        Creator = "Oak Works",
        Type = "Accessory",
        Description = "A sturdy wooden shield.",
        Tags = { "Nature", "Defense" },
        Version = "1.0",
        Info = {
            { Label = "Rarity", Value = "Rare" },
            { Label = "Defense", Value = "60" },
        },
        Color = Color3.fromRGB(90, 175, 115),
    },
}

local Models = Preview:Tab({ Name = "Search Items", Icon = "layers" })
local Source = Preview:Source({
    Name = "Live Search Test Source",
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
            Description = item.Description,
            Tags = item.Tags,
            Version = item.Version,
            Info = item.Info,
            Image = nil,
        }
    end,
    Discover = {
        Enabled = true,
        Interval = 1,
        RemoveMissing = true,
    },
})

Preview:Open(Models)

Section:Label({ Text = "In Preview search, try: neon sword, sword nova, sci-fi, legendary, forest defense, or oak." })
Section:Label({ Text = "Search terms should match in any order. Metadata changes should update results automatically." })

Section:Button({
    Name = "Update Neon Sword",
    Callback = function()
        for _, item in ipairs(items) do
            if item.Id == "A" then
                item.Name = "Plasma Blade"
                item.Creator = "Orbit Lab"
                item.Description = "A compact plasma weapon."
                item.Tags = { "Energy", "Melee" }
                item.Info = {
                    { Label = "Rarity", Value = "Mythic" },
                    { Label = "Damage", Value = "120" },
                }
                print("[Preview Live Search Test] Updated item A. Old search terms should stop matching; new terms should match after discovery.")
                return
            end
        end
    end,
})

Section:Button({
    Name = "Add Crystal Staff",
    Callback = function()
        for _, item in ipairs(items) do
            if item.Id == "C" then return end
        end
        items[#items + 1] = {
            Id = "C",
            Name = "Crystal Staff",
            Creator = "Nova Studio",
            Type = "Weapon",
            Description = "A frost magic staff.",
            Tags = { "Magic", "Ice" },
            Version = "1.4",
            Info = {
                { Label = "Rarity", Value = "Epic" },
                { Label = "Element", Value = "Frost" },
            },
            Color = Color3.fromRGB(105, 195, 235),
        }
        print("[Preview Live Search Test] Added Crystal Staff. Search 'crystal frost' after discovery.")
    end,
})

Section:Button({
    Name = "Remove Crystal Staff",
    Callback = function()
        for i, item in ipairs(items) do
            if item.Id == "C" then
                table.remove(items, i)
                print("[Preview Live Search Test] Removed Crystal Staff. Its search result should disappear after discovery.")
                return
            end
        end
    end,
})

Section:Button({
    Name = "Force Sync",
    Callback = function()
        local ok, count = Source:Sync()
        print("[Preview Live Search Test] Sync:", ok, "Items:", count)
    end,
})

Section:Button({
    Name = "Remove Test Source",
    Callback = function()
        Source:Destroy()
        print("[Preview Live Search Test] Source destroyed.")
    end,
})

print("[Preview Live Search Test] Ready. Test multi-word search, tags, Info labels/values, then update/add/remove items while a query is active.")
