--==================================================
-- JUSTLIB DYNAMIC DROPDOWN TEST
-- Local executor test: unified Dropdown API
--==================================================

local Players = game:GetService("Players")

local LibraryURL = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local JL = loadstring(game:HttpGet(LibraryURL))()

local Window = JL:Window({
    Name = "Dynamic Dropdown Test",
    Config = "JustLib_DynamicDropdownTest",
})

local Tab = Window:Tab({
    Name = "Dynamic Lists",
    Icon = "users",
    Type = "Grid",
})

local Section = Tab:Section({
    Title = "Player Dropdown Tests",
    Column = 1,
})

local function getPlayerNames()
    local names = {}

    for _,player in ipairs(Players:GetPlayers()) do
        names[#names + 1] = player.Name
    end

    table.sort(names)
    return names
end

local function getPlayerValues()
    local values = {}

    for _,player in ipairs(Players:GetPlayers()) do
        values[player.Name] = {
            {
                Type = "Toggle",
                Name = "Track",
                Master = true,
                Default = false,
            },
            {
                Type = "Toggle",
                Name = "Highlight",
                Default = false,
            },
            {
                Type = "ColorPicker",
                Name = "Highlight Color",
                Default = Color3.fromRGB(255, 80, 80),
            },
        }
    end

    return values
end

-- Standard single-select dropdown.
Section:Dropdown({
    Name = "Single Player",
    Options = getPlayerNames,

    Search = false,
    MultiSelect = false,
    Value = false,

    AutoUpdate = true,
    Interval = 5,

    Callback = function(playerName)
        print("[Dynamic Dropdown] Single:", playerName)
    end,
})

-- Standard multi-select dropdown.
Section:Dropdown({
    Name = "Multiple Players",
    Options = getPlayerNames,

    Search = true,
    MultiSelect = true,
    Value = false,

    AutoUpdate = true,
    Interval = 5,

    Callback = function(selected)
        print("[Dynamic Dropdown] MultiSelect:")
        for _,playerName in ipairs(selected) do
            print("  ", playerName)
        end
    end,
})

-- Value dropdown using the unified Dropdown API.
Section:Dropdown({
    Name = "Player Settings",
    Options = getPlayerNames,
    Values = getPlayerValues,

    Search = true,
    MultiSelect = false,
    Value = true,

    AutoUpdate = true,
    Interval = 5,

    Callback = function(selected)
        print("[Dynamic Dropdown] Value:")
        for playerName,data in pairs(selected) do
            print("  ", playerName, data)
        end
    end,
})

-- Value + MultiSelect.
Section:Dropdown({
    Name = "Multiple Player Settings",
    Options = getPlayerNames,
    Values = getPlayerValues,

    Search = true,
    MultiSelect = true,
    Value = true,

    AutoUpdate = true,
    Interval = 5,

    Callback = function(selected)
        print("[Dynamic Dropdown] Value MultiSelect:")
        for playerName,data in pairs(selected) do
            print("  ", playerName, data)
        end
    end,
})

Players.PlayerAdded:Connect(function(player)
    print("[Dynamic Dropdown Test] Player joined:", player.Name)
    print("[Dynamic Dropdown Test] The dropdowns will update automatically within 5 seconds.")
end)

Players.PlayerRemoving:Connect(function(player)
    print("[Dynamic Dropdown Test] Player leaving:", player.Name)
    print("[Dynamic Dropdown Test] The dropdowns will update automatically within 5 seconds.")
end)

print("[Dynamic Dropdown Test] Loaded.")
print("[Dynamic Dropdown Test] Join or leave the server and wait up to 5 seconds.")
print("[Dynamic Dropdown Test] Keep a dropdown open while waiting to test open-state preservation.")
