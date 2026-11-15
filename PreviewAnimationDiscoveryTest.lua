-- Preview animation timeline player test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewAnimationDiscoveryTest.lua"))()

local Players = game:GetService("Players")
local player = Players.LocalPlayer
if not player then
	warn("[Preview Animation Player Test] LocalPlayer is unavailable.")
	return
end

local character = player.Character or player.CharacterAdded:Wait()
if not character then
	warn("[Preview Animation Player Test] Character is unavailable.")
	return
end

local Library = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Animation Player Test] JustLib failed to load.") return end

local Window = Library:Window({
	Title = "Preview Animation Player Test",
	Config = "JustX_PreviewAnimationPlayerTest",
	Width = 520,
	Height = 440,
})
if not Window then warn("[Preview Animation Player Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Animation Player", Icon = "clapperboard" })
local Section = Host:Section({ Title = "Preview animation timeline" })

local Preview = Library:Preview({
	Title = "Animation Player",
	Icon = "clapperboard",
	TabName = "Animation Player",
	Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
	warn("[Preview Animation Player Test] Preview failed to initialize.")
	return
end

local Models = Preview:Tab({ Name = "Models", Icon = "box" })
local Source = Preview:Source({
	Name = "Character Animation Player",
	Tab = Models,
	GetItems = function()
		return { "LocalCharacter" }
	end,
	Key = function(item)
		return item
	end,
	Map = function()
		return {
			Name = "Character Animation Preview",
			Type = "Live character rig clone",
			Description = "Tests animation playback, pause, stop, seeking and speed changes on the Preview clone. The original character is not animated by the Preview player.",
			Model = character,
		}
	end,
})

Preview:Open({ Tab = Models, Asset = "Character Animation Preview" })

Section:Button({
	Name = "Refresh Character Preview",
	Callback = function()
		character = player.Character or character
		Source:Refresh("LocalCharacter")
	end,
})

Section:Button({
	Name = "Remove Test Preview",
	Callback = function()
		Source:Remove("LocalCharacter")
	end,
})

print("[Preview Animation Player Test] Ready. Open the character Preview and use the Animation Player below the viewport.")
