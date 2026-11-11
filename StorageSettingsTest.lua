-- JustLib Storage Settings Test
-- Run this script to test Auto Save, Save Settings, Global Settings and the new file layout.
-- To test cross-hub Global Settings, change CONFIG_NAME to "JustLib_StorageTest_B" and run again.
-- Check the Presets page for Save Settings and Global Settings.

local CONFIG_NAME = "JustLib_StorageTest_A"

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
))()

if not Library then
    warn("[Storage Test] JustLib failed to load.")
    return
end

local Window = Library:Window({
    Title = "JustLib Storage Test",
    Config = CONFIG_NAME,
    Width = 520,
    Height = 420,
})

if not Window then
    warn("[Storage Test] Window creation failed.")
    return
end

local Tab = Window:Tab({
    Name = "Storage",
    Icon = "save",
})

local Section = Tab:Section({
    Title = "Test Controls",
})

Section:Toggle({
    Name = "Auto Save Test",
    Flag = "StorageTest_AutoSave",
    Default = false,
    Callback = function(value)
        print("[Storage Test] Toggle:", value)
    end,
})

Section:Slider({
    Name = "Saved Value",
    Flag = "StorageTest_Value",
    Min = 0,
    Max = 100,
    Step = 1,
    Default = 25,
    Suffix = "%",
    Callback = function(value)
        print("[Storage Test] Slider:", value)
    end,
})

print("[Storage Test] Loaded with config:", CONFIG_NAME)
print("[Storage Test] Files are stored under Workspace/JustX/")
