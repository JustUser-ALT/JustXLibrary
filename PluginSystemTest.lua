-- JustXLibrary Plugin System Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/PluginSystemTest.lua"))()
--
-- Test flow:
-- 1. Open the Preview tab and select the Character asset.
-- 2. Open Plugins in the Preview sidebar and install Explorer and Animation.
-- 3. Return to the Character asset: Explorer and Animation pages should appear.
-- 4. Disable, enable and uninstall each plugin; its page should disappear and return.
-- 5. Reopen Preview to verify installed plugin state is restored.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
))()

if not Library then
    warn("[Plugin Test] JustLib failed to load.")
    return
end

if Library.LoadIconPack then
    pcall(function() Library:LoadIconPack() end)
end

local Window = Library:Window({
    Title = "Plugin System Test",
    Config = "JustLib_PluginTest",
    Width = 560,
    Height = 440,
})

if not Window then
    warn("[Plugin Test] Window creation failed.")
    return
end

local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local originalArchivable = character.Archivable
pcall(function() character.Archivable = true end)
local cloneOk, characterModel = pcall(function() return character:Clone() end)
pcall(function() character.Archivable = originalArchivable end)

if not cloneOk or not characterModel then
    warn("[Plugin Test] Could not clone the current character.")
    return
end

characterModel.Name = "Character Plugin Test"

local Preview = Library:Preview({
    Title = "Plugin System Test",
    Icon = "blocks",
    TabName = "Preview",
})

if not Preview or Preview.IsStub then
    warn("[Plugin Test] Preview failed to initialize.")
    characterModel:Destroy()
    return
end

local Models = Preview:Tab({
    Name = "Models",
    Icon = "user-round",
})

Models:Asset({
    Name = "Character",
    Type = "Character Model",
    Creator = "Local Player",
    Description = "A local character clone for testing the Explorer and Animation plugins.",
    Model = characterModel,
    Preview = true,
})

Preview:Open({Tab = "Models", Asset = "Character"})

print("[Plugin Test] Loaded. Open the Plugins tab inside Preview to install and test plugins.")
