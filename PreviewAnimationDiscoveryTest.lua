-- Preview animation discovery test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewAnimationDiscoveryTest.lua"))()

local Library = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Animation Discovery Test] JustLib failed to load.") return end

local Window = Library:Window({
	Title = "Preview Animation Discovery Test",
	Config = "JustX_PreviewAnimationDiscoveryTest",
	Width = 520,
	Height = 440,
})
if not Window then warn("[Preview Animation Discovery Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Animation Test", Icon = "clapperboard" })
local Section = Host:Section({ Title = "Animation discovery" })

local Preview = Library:Preview({
	Title = "Animation Discovery",
	Icon = "clapperboard",
	TabName = "Animation Discovery",
	Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
	warn("[Preview Animation Discovery Test] Preview failed to initialize.")
	return
end

local model = Instance.new("Model")
model.Name = "AnimationDiscoveryTestModel"

local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Size = Vector3.new(2, 3, 1)
root.Anchored = true
root.CanCollide = false
root.Color = Color3.fromRGB(105, 125, 160)
root.CFrame = CFrame.new(0, 3, 0)
root.Parent = model

local humanoid = Instance.new("Humanoid")
humanoid.Parent = model

local animator = Instance.new("Animator")
animator.Parent = humanoid

local animationFolder = Instance.new("Folder")
animationFolder.Name = "Animations"
animationFolder.Parent = model

local function addAnimation(name, id)
	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = "rbxassetid://" .. id
	animation.Parent = animationFolder
	return animation
end

addAnimation("Idle", "507766666")
addAnimation("Walk", "507777826")
addAnimation("Run", "507767714")

model.PrimaryPart = root
model.Parent = workspace

local Models = Preview:Tab({ Name = "Models", Icon = "box" })
local Source = Preview:Source({
	Name = "Animation Discovery Model",
	Tab = Models,
	GetItems = function()
		return { "AnimationDiscoveryModel" }
	end,
	Key = function(item)
		return item
	end,
	Map = function()
		return {
			Name = "Animation Discovery Test",
			Type = "Animated Model",
			Description = "Contains three Animation instances and an Animator for testing automatic discovery.",
			Model = model,
		}
	end,
})

Preview:Open({ Tab = Models, Asset = "Animation Discovery Test" })

Section:Button({
	Name = "Refresh Animation List",
	Callback = function()
		Source:Refresh("AnimationDiscoveryModel")
	end,
})

Section:Button({
	Name = "Remove Test Model",
	Callback = function()
		Source:Remove("AnimationDiscoveryModel")
		if model and model.Parent then
			model:Destroy()
		end
	end,
})

print("[Preview Animation Discovery Test] Ready. Open the model and select its Animations page.")
