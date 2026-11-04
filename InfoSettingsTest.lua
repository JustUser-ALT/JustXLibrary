--==================================================
-- JUSTLIB 4.2 INFO & SETTINGS TEST
-- Tests optional Tooltip, Info and Settings independently.
-- Run in a Roblox executor/local-script environment.
--==================================================

local LibraryURL = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local JL = loadstring(game:HttpGet(LibraryURL))()

local Window = JL:Window({
    Name = "JustLib 4.2 · Info & Settings",
    Config = "JustLib_InfoSettingsTest",
    Settings = true,
})

if not Window then
    warn("[Info & Settings Test] Window creation was cancelled.")
    return
end

local Tab = Window:Tab({
    Name = "Controls",
    Icon = "sliders-horizontal",
    Type = "Grid",
})

local Section = Tab:Section({
    Title = "Optional Control Extras",
    Icon = "settings-2",
    Column = 1,
})

local function safeAdd(label, callback)
    local ok, result = pcall(callback)
    if not ok then
        warn("[Info & Settings Test] FAILED:", label, result)
    else
        print("[Info & Settings Test] CREATED:", label)
    end
    return ok, result
end

safeAdd("Toggle / all three extras", function()
    return Section:Toggle({
        Name = "Player ESP",
        Flag = "Test_PlayerESP",
        Default = true,
        Tooltip = "Short hover/touch hint. This remains independent from Info.",
        Info = {
            Title = "Player ESP",
            Description = "Отображает игроков через стены.",
            Details = "Можно использовать дополнительные параметры, чтобы изменить дальность и отображение.",
            Warning = "Большая дальность может влиять на производительность.",
        },
        Settings = {
            {Type = "Toggle", Name = "Show Distance", Flag = "Test_ESP_Distance", Default = true},
            {Type = "Slider", Name = "Max Distance", Flag = "Test_ESP_Range", Min = 100, Max = 5000, Default = 1500, Suffix = " studs"},
            {Type = "ColorPicker", Name = "ESP Color", Flag = "Test_ESP_Color", Default = Color3.fromRGB(82,152,255)},
            {Type = "Dropdown", Name = "Display Mode", Flag = "Test_ESP_Mode", Options = {"Box", "Highlight", "Both"}, Default = "Highlight"},
            {Type = "Input", Name = "Custom Label", Flag = "Test_ESP_Label", Placeholder = "Player"},
            {Type = "Button", Name = "Reset ESP Settings", Callback = function()
                print("[Info & Settings Test] Reset settings button pressed.")
            end},
        },
        Callback = function(value)
            print("[Info & Settings Test] Player ESP:", value)
        end,
    })
end)

safeAdd("Button / Info only", function()
    return Section:Button({
        Name = "Information Only",
        Info = "Это пример контрола только с расширенной информацией. Окно настроек для него не создаётся.",
        Callback = function()
            print("[Info & Settings Test] Info-only button clicked.")
        end,
    })
end)

safeAdd("Dropdown / Tooltip only", function()
    return Section:Dropdown({
        Name = "Tooltip Only",
        Flag = "Test_TooltipDropdown",
        Options = {"Alpha", "Beta", "Gamma"},
        Default = "Alpha",
        Tooltip = "Только обычная подсказка — дополнительных иконок быть не должно.",
    })
end)

safeAdd("Slider / Settings only", function()
    return Section:Slider({
        Name = "Settings Only Slider",
        Flag = "Test_SettingsSlider",
        Min = 0,
        Max = 100,
        Default = 35,
        Settings = {
            {Type = "Toggle", Name = "Invert", Flag = "Test_Slider_Invert", Default = false},
            {Type = "Slider", Name = "Step Size", Flag = "Test_Slider_Step", Min = 1, Max = 20, Default = 5},
        },
    })
end)

safeAdd("Input / Info and Tooltip", function()
    return Section:Input({
        Name = "Custom Name",
        Flag = "Test_CustomName",
        Placeholder = "Enter a name...",
        Tooltip = "Обычная подсказка для поля ввода.",
        Info = {
            Description = "Поле принимает произвольный текст.",
            Details = "Изменения сохраняются в конфигурацию при потере фокуса.",
        },
    })
end)

safeAdd("ValueDropdown / top-level and nested extras", function()
    return Section:ValueDropdown({
        Name = "Loot Options",
        Flag = "Test_LootOptions",
        Options = {"Sword", "Shield", "Potion"},
        MultiSelect = true,
        Tooltip = "Выбери предмет, затем открой его вложенные параметры.",
        Info = {
            Description = "Настройки отдельных категорий лута.",
            Details = "У каждого предмета могут быть собственные Info, Settings и Tooltip.",
        },
        Settings = {
            {Type = "Toggle", Name = "Enable Loot Filter", Flag = "Test_LootFilter", Default = true},
            {Type = "Dropdown", Name = "Sort By", Flag = "Test_LootSort", Options = {"Name", "Distance", "Rarity"}, Default = "Rarity"},
        },
        Values = {
            Sword = {
                Mode = "Move",
                {
                    Type = "Toggle",
                    Name = "Always",
                    Master = true,
                    Default = true,
                    Tooltip = "Nested toggle tooltip.",
                    Info = "Этот переключатель управляет режимом Always.",
                    Settings = {
                        {Type = "Toggle", Name = "Notify", Flag = "Test_Sword_AlwaysNotify", Default = true},
                    },
                },
                {Type = "Toggle", Name = "Current"},
                {
                    Type = "Slider",
                    Name = "Range",
                    Min = 1,
                    Max = 10,
                    Default = 5,
                    Info = {
                        Description = "Дальность поиска меча.",
                        Warning = "Проверь производительность на больших значениях.",
                    },
                    Settings = {
                        {Type = "Slider", Name = "Minimum Range", Flag = "Test_Sword_MinRange", Min = 1, Max = 10, Default = 2},
                    },
                },
                {
                    Type = "Button",
                    Name = "Nested Action",
                    Info = "Проверка Info у вложенной кнопки.",
                    Callback = function()
                        print("[Info & Settings Test] Nested Sword action.")
                    end,
                },
            },
            Shield = {
                {Type = "Toggle", Name = "Enabled", Default = true},
                {
                    Type = "ColorPicker",
                    Name = "Shield Color",
                    Default = Color3.fromRGB(72,198,138),
                    Info = "Цвет щита.",
                },
            },
            Potion = {
                {Type = "Slider", Name = "Amount", Min = 1, Max = 5, Default = 2},
            },
        },
        Callback = function(values)
            print("[Info & Settings Test] Loot selection updated.")
        end,
    })
end)

print("[Info & Settings Test] Loaded. Check icon combinations, modal panels, settings controls and nested ValueDropdown items.")
