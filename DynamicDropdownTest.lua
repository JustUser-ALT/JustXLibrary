--==================================================
-- JUSTLIB DYNAMIC DROPDOWN TEST
-- Local executor test: player lists update on join/leave
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
                Default = false,
            },
            {
                Type = "Toggle",
                Name = "Highlight",
                Default = false,
            },
        }
    end

    return values
end

local SingleDropdown = Section:Dropdown({
    Name = "Single Player",
    Options = getPlayerNames,
    Search = true,
    Callback = function(playerName)
        print("[Dynamic Dropdown] Selected player:", playerName)
    end,
})

local MultiDropdown = Section:Dropdown({
    Name = "Multiple Players",
    Options = getPlayerNames,
    MultiSelect = true,
    MaxSelect = 8,
    Search = true,
    Callback = function(selected)
        print("[Dynamic Dropdown] MultiSelect:", table.concat(selected, ", "))
    end,
})

local ValueDropdown = Section:ValueDropdown({
    Name = "Player Settings",
    Options = getPlayerNames,
    Values = getPlayerValues,
    Search = true,
    Callback = function(selected)
        print("[Dynamic Dropdown] ValueDropdown changed")
        for playerName,data in pairs(selected) do
            print("  ", playerName, data)
        end
    end,
})

local ValueMultiDropdown = Section:ValueDropdown({
    Name = "Multiple Player Settings",
    Options = getPlayerNames,
    Values = getPlayerValues,
    MultiSelect = true,
    MaxSelect = 8,
    Search = true,
    Callback = function(selected)
        print("[Dynamic Dropdown] ValueDropdown MultiSelect changed")
        for playerName,data in pairs(selected) do
            print("  ", playerName, data)
        end
    end,
})

local Status = Section:Label({
    Text = "Players detected: " .. tostring(#Players:GetPlayers()),
})

local controls = {
    SingleDropdown,
    MultiDropdown,
    ValueDropdown,
    ValueMultiDropdown,
}

local function refreshAll()
    local count = 0

    for _,control in ipairs(controls) do
        if control and control.Refresh then
            local ok,result = pcall(function()
                return control:Refresh()
            end)

            if ok and result then
                count = count + 1
            else
                warn("[Dynamic Dropdown] Refresh failed:", result)
            end
        end
    end

    Status:Set("Players detected: " .. tostring(#Players:GetPlayers()) .. " | Refreshed: " .. tostring(count) .. "/" .. tostring(#controls))
end

Section:Button({
    Name = "Refresh All Lists",
    Callback = refreshAll,
})

Players.PlayerAdded:Connect(function(player)
    task.delay(0.15, function()
        refreshAll()
        print("[Dynamic Dropdown] Player joined:", player.Name)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    task.delay(0.15, function()
        refreshAll()
        print("[Dynamic Dropdown] Player left:", player.Name)
    end)
end)

refreshAll()
print("[Dynamic Dropdown] Test loaded. Join or leave the server to test automatic updates.")
