-- JustLib Storage Settings Test
-- Run this script to test Auto Save, Save Settings, Global Settings and the new file layout.
-- The Settings tab below is created by Window:Settings() and contains the real JustXLibrary interface settings.
-- Run this after StorageSettingsTest.lua to verify that Global Settings are shared across different hub configs.

local CONFIG_NAME = "JustLib_StorageTest_B"

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
    Width = 560,
    Height = 440,
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

-- This creates the actual library Settings tab (Interface, Appearance, Presets, etc.).
Window:Settings()

print("[Storage Test] Loaded with config:", CONFIG_NAME)
print("[Storage Test] Open Settings > Interface and Settings > Presets to verify shared settings.")
print("[Storage Test] Files are stored under Workspace/JustX/")
