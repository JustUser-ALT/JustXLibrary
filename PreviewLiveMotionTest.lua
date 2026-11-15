-- Preview live motion synchronization test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewLiveMotionTest.lua"))()

local RunService = game:GetService("RunService")
local Library = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Preview Live Motion Test] JustLib failed to load.") return end

local Window = Library:Window({
	Title = "Preview Live Motion Test",
	Config = "JustX_PreviewLiveMotionTest",
	Width = 520,
	Height = 440,
})
if not Window then warn("[Preview Live Motion Test] Window creation failed.") return end

local Host = Window:Tab({ Name = "Live Motion", Icon = "activity" })
local Section = Host:Section({ Title = "Live model motion" })

local Preview = Library:Preview({
	Title = "Live Motion",
	Icon = "activity",
	TabName = "Live Motion",
	Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
})
if not Preview or Preview.IsStub then
	warn("[Preview Live Motion Test] Preview failed to initialize.")
	return
end

local model = Instance.new("Model")
model.Name = "LiveMotionTestRig"

local root = Instance.new("Part")
root.Name = "Root"
root.Size = Vector3.new(2.5, 3, 1.5)
root.Anchored = true
root.CanCollide = false
root.Color = Color3.fromRGB(105, 125, 160)
root.CFrame = CFrame.new(0, 3, 0)
root.Parent = model

local arm = Instance.new("Part")
arm.Name = "AnimatedArm"
arm.Size = Vector3.new(1, 2.5, 1)
arm.Anchored = false
arm.CanCollide = false
arm.Color = Color3.fromRGB(225, 165, 105)
arm.Parent = model

local motor = Instance.new("Motor6D")
motor.Name = "Shoulder"
motor.Part0 = root
motor.Part1 = arm
motor.C0 = CFrame.new(1.7, 0.6, 0)
motor.C1 = CFrame.new(0, 1, 0)
motor.Parent = root

model.PrimaryPart = root
model.Parent = workspace

local Models = Preview:Tab({ Name = "Models", Icon = "box" })
local Source = Preview:Source({
	Name = "Live Motion Rig",
	Tab = Models,
	LiveMotion = { Rate = 30 },
	GetItems = function()
		return { "LiveMotionRig" }
	end,
	Key = function(item)
		return item
	end,
	Map = function()
		return {
			Name = "Live Motion Rig",
			Type = "Animated Model",
			Description = "Live Motion mirrors the source model pivot and animated part poses in the selected large Preview.",
			Model = model,
		}
	end,
})

Preview:Open({ Tab = Models, Asset = "Live Motion Rig" })

local running = false
local startedAt = 0
local animationConnection

local function startAnimation()
	if running then return end
	running = true
	startedAt = os.clock()
	animationConnection = RunService.RenderStepped:Connect(function()
		if not model.Parent then return end
		local t = os.clock() - startedAt
		root.CFrame = CFrame.new(math.sin(t * 0.8) * 4, 3 + math.sin(t * 1.4) * 0.5, 0)
			* CFrame.Angles(0, math.sin(t * 0.55) * 0.7, 0)
		motor.Transform = CFrame.Angles(0, 0, math.sin(t * 3) * 0.9)
	end)
end

local function stopAnimation()
	running = false
	if animationConnection then
		animationConnection:Disconnect()
		animationConnection = nil
	end
end

Section:Button({
	Name = "Start Model + Joint Motion",
	Callback = startAnimation,
})

Section:Button({
	Name = "Stop Animation",
	Callback = stopAnimation,
})

Section:Button({
	Name = "Disable Live Motion",
	Callback = function()
		Source:SetLiveMotion("LiveMotionRig", false)
	end,
})

Section:Button({
	Name = "Enable Live Motion",
	Callback = function()
		Source:SetLiveMotion("LiveMotionRig", true)
	end,
})

Section:Button({
	Name = "Remove Test Model",
	Callback = function()
		stopAnimation()
		Source:Remove("LiveMotionRig")
		if model and model.Parent then
			model:Destroy()
		end
	end,
})

print("[Preview Live Motion Test] Ready. Open the model Preview, start motion, then compare Live Motion enabled and disabled.");
