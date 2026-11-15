-- JustXLibrary Preview Structure Inspector Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewStructureTest.lua?v=20261115-icon-trace-3"))()

local Library = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua?v=20261115-icon-trace-3"
))()

if not Library then
	warn("[Structure Test] JustLib failed to load.")
	return
end

local iconOk, iconLoaded = pcall(function()
	return Library:LoadIconPack()
end)
warn("[Structure Test] IconPack load call: " .. tostring(iconOk) .. " / " .. tostring(iconLoaded))

local iconPack = Library._iconPack
warn("[Structure Test] IconPack instance: " .. typeof(iconPack))
if type(iconPack) == "table" then
	local keys = {}
	for key, value in pairs(iconPack) do
		keys[#keys + 1] = tostring(key) .. ":" .. typeof(value)
	end
	table.sort(keys)
	warn("[Structure Test] IconPack exports: " .. table.concat(keys, ", "))

	for _, iconName in ipairs({ "network", "box", "grid-2x2", "flask-conical" }) do
		local dotOk, dotValue = pcall(iconPack.GetAsset, iconName)
		local selfOk, selfValue = pcall(iconPack.GetAsset, iconPack, iconName)
		local function describe(value)
			if type(value) == "table" then
				return "table Url=" .. tostring(value.Url or value.Image or value.ImageUrl or value.Texture or value.AssetId or value.Id) .. " Text=" .. tostring(value.Text or value.Glyph)
			end
			return typeof(value) .. " " .. tostring(value)
		end
		warn("[Structure Test] GetAsset(" .. iconName .. ") dot: " .. tostring(dotOk) .. " / " .. describe(dotValue))
		warn("[Structure Test] GetAsset(self," .. iconName .. ") colon: " .. tostring(selfOk) .. " / " .. describe(selfValue))
	end
end

local bridge = Library._bridge
warn("[Structure Test] Library type: " .. typeof(Library))
warn("[Structure Test] Bridge type: " .. typeof(bridge))
warn("[Structure Test] Bridge icon type: " .. tostring(type(bridge) == "table" and typeof(bridge.icon) or "unavailable"))
warn("[Structure Test] Direct resolver error field: " .. tostring(Library._lastIconResolveError))

for _, iconName in ipairs({ "network", "box", "grid-2x2", "flask-conical" }) do
	local ok, value
	if type(bridge) == "table" and type(bridge.icon) == "function" then
		ok, value = pcall(bridge.icon, iconName)
	else
		ok, value = false, "bridge.icon is not a function"
	end
	local detail = typeof(value)
	if type(value) == "table" then
		detail = detail .. " Url=" .. tostring(value.Url or value.Image or value.ImageUrl or value.Texture or value.AssetId or value.Id) .. " Text=" .. tostring(value.Text or value.Glyph)
	elseif type(value) == "string" or type(value) == "number" then
		detail = detail .. " " .. tostring(value)
	end
	warn("[Structure Test] Bridge icon " .. iconName .. ": " .. tostring(ok) .. " / " .. detail)
	warn("[Structure Test] Bridge icon error " .. iconName .. ": " .. tostring(Library._lastIconResolveError))
end

local Window = Library:Window({
	Title = "Preview Structure Test",
	Config = "JustLib_PreviewStructureTest",
})

if not Window then
	warn("[Structure Test] Window creation failed.")
	return
end

local Host = Window:Tab({ Name = "Test", Icon = "flask-conical" })
local Section = Host:Section({ Title = "Model Structure Inspector" })
local Preview

local function makePart(parent, name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function buildSample(parent, neon)
	local bodyColor = neon and Color3.fromRGB(55, 185, 255) or Color3.fromRGB(105, 115, 140)
	local detailColor = neon and Color3.fromRGB(255, 90, 190) or Color3.fromRGB(220, 185, 110)

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = parent

	local body = makePart(geometry, "Body", Vector3.new(3, 2, 1.5), Vector3.new(0, 0, 0), bodyColor, neon and Enum.Material.Neon or Enum.Material.Metal)

	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "BodyMesh"
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.8, 1)
	mesh.Parent = body

	local decal = Instance.new("Decal")
	decal.Name = "FrontMark"
	decal.Face = Enum.NormalId.Front
	decal.Texture = "rbxasset://textures/face.png"
	decal.Parent = body

	local texture = Instance.new("Texture")
	texture.Name = "SurfacePattern"
	texture.Face = Enum.NormalId.Top
	texture.Texture = "rbxasset://textures/terrain/grass.png"
	texture.StudsPerTileU = 2
	texture.StudsPerTileV = 2
	texture.Parent = body

	local attachment = Instance.new("Attachment")
	attachment.Name = "EffectPoint"
	attachment.Position = Vector3.new(0, 1, 0)
	attachment.Parent = body

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "TestParticles"
	emitter.Enabled = false
	emitter.Rate = 8
	emitter.Parent = attachment

	local detail = makePart(geometry, "Core", Vector3.new(1, 1, 1), Vector3.new(0, 1.7, 0), detailColor, Enum.Material.Neon)
	detail.Shape = Enum.PartType.Ball

	local sound = Instance.new("Sound")
	sound.Name = "DemoSound"
	sound.SoundId = "rbxassetid://0"
	sound.Volume = 0.5
	sound.Parent = detail

	local sub = Instance.new("Model")
	sub.Name = "SubAssembly"
	sub.Parent = parent
	makePart(sub, "LeftPanel", Vector3.new(0.4, 2.2, 1.6), Vector3.new(-1.8, 0, 0), detailColor)
	makePart(sub, "RightPanel", Vector3.new(0.4, 2.2, 1.6), Vector3.new(1.8, 0, 0), detailColor)

	local value = Instance.new("BoolValue")
	value.Name = "IsDemo"
	value.Value = true
	value.Parent = parent
end

local function openPreview()
	if Preview and Preview.alive and Preview:IsOpen() then
		Preview:Open("Models")
		return
	end

	Preview = Library:Preview({
		Title = "Structure Inspector",
		Icon = "network",
		TabName = "Preview",
		Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua?v=20261115-icon-trace-3",
	})

	if not Preview or Preview.IsStub then
		warn("[Structure Test] Preview failed to initialize.")
		return
	end

	local Models = Preview:Tab({ Name = "Models", Icon = "box" })
	Preview:Tab({ Name = "All", Icon = "grid-2x2", ShowAll = true })

	local directModel = Instance.new("Model")
	directModel.Name = "DirectModelRoot"
	buildSample(directModel, false)

	Models:Asset({
		Name = "Instance Model",
		Type = "Structure Test",
		Creator = "JustXLibrary",
		Description = "Tests direct Model cloning, nested folders, parts, meshes, decals, textures, attachments and values.",
		Model = directModel,
	})

	Models:Asset({
		Name = "Builder Model",
		Type = "Structure Test",
		Creator = "JustXLibrary",
		Description = "Tests Build-based models and switching the Structure tree between variants.",
		Variants = {
			{
				Name = "Classic",
				Build = function(model)
					buildSample(model, false)
				end,
			},
			{
				Name = "Neon",
				Build = function(model)
					buildSample(model, true)
				end,
			},
		},
		Build = function(model)
			buildSample(model, false)
		end,
	})

	Preview:Open("Models")
	print("[Structure Test] Opened. Select an asset and open its Structure page.")
end

Section:Button({
	Name = "Open Structure Test",
	Icon = "network",
	Callback = openPreview,
})

Section:Button({
	Name = "Close Preview",
	Icon = "x",
	Callback = function()
		if Preview then Preview:Close() end
	end,
})

Window:Settings()
print("[Structure Test] Host window loaded.")
