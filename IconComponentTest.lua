--==================================================
-- JUSTLIB ICON COMPONENT INTEGRATION TEST
-- Tests icon rendering inside actual JustLib controls.
--==================================================

local LibraryURL = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local JL = loadstring(game:HttpGet(LibraryURL))()

local Window = JL:Window({
    Name = "JustLib Icon Component Test",
    Config = "JustLib_IconComponentTest",
    Settings = true,
    DebugPerformance = true,
})

if not Window then
    warn("[Icon Component Test] Window creation was cancelled.")
    return
end

local function safeAdd(label, callback)
    local ok, result = pcall(callback)
    if not ok then
        warn("[Icon Component Test] FAILED:", label, result)
    else
        print("[Icon Component Test] CREATED:", label)
    end
    return ok, result
end

-- Grid tabs: verifies icons in the actual tab navigation.
local mainTab = Window:Tab({
    Name = "Controls",
    Icon = "layout-grid",
    Type = "Grid",
})

local multiTab = Window:Tab({
    Name = "MultiSection",
    Icon = "panels-top-left",
    Type = "Grid",
})

-- Standard section header icon and control-level icons.
local section = mainTab:Section({
    Title = "Standard Controls",
    Icon = "sliders-horizontal",
    Column = 1,
})

safeAdd("Toggle", function()
    return section:Toggle({
        Name = "Icon Toggle",
        Icon = "shield-check",
        Default = true,
        Callback = function(value)
            print("[Icon Component Test] Toggle:", value)
        end,
    })
end)

safeAdd("Button", function()
    return section:Button({
        Name = "Icon Button",
        Icon = "mouse-pointer-click",
        Callback = function()
            print("[Icon Component Test] Button clicked")
        end,
    })
end)

safeAdd("Slider", function()
    return section:Slider({
        Name = "Icon Slider",
        Icon = "gauge",
        Min = 0,
        Max = 100,
        Default = 35,
    })
end)

safeAdd("Dropdown", function()
    return section:Dropdown({
        Name = "Icon Dropdown",
        Icon = "list-filter",
        Options = {"Alpha", "Beta", "Gamma"},
        Default = "Alpha",
        Search = true,
    })
end)

safeAdd("ValueDropdown", function()
    return section:ValueDropdown({
        Name = "Icon ValueDropdown",
        Icon = "package",
        Options = {"Sword", "Shield", "Potion"},
        MultiSelect = true,
        Values = {
            Sword = {
                Mode = "Move",
                {Type = "Toggle", Name = "Always", Master = true, Default = true},
                {Type = "Toggle", Name = "Current"},
                {Type = "Slider", Name = "Range", Min = 1, Max = 10, Default = 5},
                {Type = "Button", Name = "Nested Action"},
            },
            Shield = {
                {Type = "Toggle", Name = "Enabled", Default = true},
            },
            Potion = {
                {Type = "Slider", Name = "Amount", Min = 1, Max = 5, Default = 2},
            },
        },
    })
end)

-- MultiSection: page selector icons, section header icon and controls on pages.
local multi = multiTab:MultiSection({
    Title = "Icon Pages",
    Icon = "panels-top-left",
    Pages = {"Items", "Loot", "Tools", "Other"},
    Layout = "Rows",
    Columns = 2,
})

safeAdd("MultiSection / Items Toggle", function()
    return multi:Page("Items"):Toggle({
        Name = "Items Toggle",
        Icon = "package-check",
        Default = true,
    })
end)

safeAdd("MultiSection / Loot Button", function()
    return multi:Page("Loot"):Button({
        Name = "Loot Button",
        Icon = "gem",
        Callback = function()
            print("[Icon Component Test] Loot button clicked")
        end,
    })
end)

safeAdd("MultiSection / Tools Dropdown", function()
    return multi:Page("Tools"):Dropdown({
        Name = "Tools Dropdown",
        Icon = "wrench",
        Options = {"Hammer", "Key", "Flashlight"},
        Default = "Hammer",
    })
end)

safeAdd("MultiSection / Shared Toggle", function()
    return multi:Shared():Toggle({
        Name = "Shared Toggle",
        Icon = "pin",
        Default = false,
    })
end)

-- Switch to each page once so page switching and delayed rendering are exercised.
task.delay(1, function()
    for _, pageName in ipairs({"Items", "Loot", "Tools", "Other"}) do
        multi:SetPage(pageName)
        task.wait(0.35)
    end
    multi:SetPage("Items")
    print("[Icon Component Test] Page cycle completed.")
end)

print("[Icon Component Test] Loaded. Check tab, section, control and MultiSection icons.")
