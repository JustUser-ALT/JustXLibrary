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
local initialRootCFrame = root.CFrame
root.Parent = model

local motors = {}
local initialPartCFrames = { [root] = initialRootCFrame }

local function addLimb(name, size, color, c0, c1)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = false
	part.CanCollide = false
	part.Color = color
	part.CFrame = root.CFrame * c0 * c1:Inverse()
	initialPartCFrames[part] = part.CFrame
	part.Parent = model

	local motor = Instance.new("Motor6D")
	motor.Name = name .. "Motor"
	motor.Part0 = root
	motor.Part1 = part
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = root

	motors[name] = motor
	return part
end

addLimb(
	"Head",
	Vector3.new(1.4, 1.4, 1.4),
	Color3.fromRGB(225, 190, 145),
	CFrame.new(0, 1.85, 0),
	CFrame.new(0, -0.7, 0)
)

addLimb(
	"LeftArm",
	Vector3.new(0.8, 2.3, 0.8),
	Color3.fromRGB(225, 165, 105),
	CFrame.new(-1.65, 0.65, 0),
	CFrame.new(0, 1.15, 0)
)

addLimb(
	"RightArm",
	Vector3.new(0.8, 2.3, 0.8),
	Color3.fromRGB(195, 135, 90),
	CFrame.new(1.65, 0.65, 0),
	CFrame.new(0, 1.15, 0)
)

addLimb(
	"LeftLeg",
	Vector3.new(0.95, 2.4, 0.95),
	Color3.fromRGB(100, 145, 190),
	CFrame.new(-0.65, -1.45, 0),
	CFrame.new(0, 1.2, 0)
)

addLimb(
	"RightLeg",
	Vector3.new(0.95, 2.4, 0.95),
	Color3.fromRGB(80, 120, 170),
	CFrame.new(0.65, -1.45, 0),
	CFrame.new(0, 1.2, 0)
)

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
			Type = "Multi-joint animated model",
			Description = "Tests simultaneous Motor6D motion on the head, both arms and both legs, plus root movement.",
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

		root.CFrame = CFrame.new(
			math.sin(t * 0.65) * 3.5,
			3 + math.sin(t * 1.1) * 0.35,
			math.cos(t * 0.45) * 1.5
		) * CFrame.Angles(
			math.sin(t * 0.7) * 0.12,
			math.sin(t * 0.5) * 0.65,
			math.sin(t * 0.8) * 0.08
		)

		motors.Head.Transform = CFrame.Angles(
			math.sin(t * 1.7) * 0.12,
			math.sin(t * 1.2) * 0.45,
			math.sin(t * 1.4) * 0.08
		)

		motors.LeftArm.Transform = CFrame.Angles(
			math.sin(t * 2.4) * 0.8,
			0,
			math.sin(t * 2.4) * 0.55
		)

		motors.RightArm.Transform = CFrame.Angles(
			math.sin(t * 2.4 + math.pi) * 0.8,
			0,
			-math.sin(t * 2.4 + math.pi) * 0.55
		)

		motors.LeftLeg.Transform = CFrame.Angles(
			math.sin(t * 2.4 + math.pi) * 0.65,
			0,
			0
		)

		motors.RightLeg.Transform = CFrame.Angles(
			math.sin(t * 2.4) * 0.65,
			0,
			0
		)
	end)
end

local function stopAnimation(refreshPreview)
	running = false
	if animationConnection then
		animationConnection:Disconnect()
		animationConnection = nil
	end

	for _, motor in pairs(motors) do
		motor.Transform = CFrame.new()
	end

	-- Let the joint solver consume the cleared Motor6D transforms first.
	RunService.Heartbeat:Wait()

	-- Restore every part from its captured rest pose, not from the animated frame.
	for part, initialCFrame in pairs(initialPartCFrames) do
		if part and part.Parent then
			part.CFrame = initialCFrame
		end
	end
	root.CFrame = initialRootCFrame

	if refreshPreview ~= false and model.Parent then
		Source:Refresh("LiveMotionRig")
	end
end

Section:Button({
	Name = "Start Full Rig Motion",
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
		stopAnimation(false)
		Source:Remove("LiveMotionRig")
		if model and model.Parent then
			model:Destroy()
		end
	end,
})

print("[Preview Live Motion Test] Ready. Open the model Preview, start full rig motion, then compare Live Motion enabled and disabled.")
