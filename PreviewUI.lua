--[[
	local Preview = JL:Preview({
		Title = "Preview", Icon = "⬡", TabName = "Preview",
		Key = Enum.KeyCode.P,                      -- (необязательно) создать/удалить вкладку
		OnOpen = function(pv) end, OnClose = function(pv) end,
	})

	Preview:Open(target)    создаёт вкладку (если её нет) и переключается на неё.
	                        target: nil | "TabName" | Tab | Asset | {Tab="Models", Asset="Tree", Page="preview"}
	Preview:Close()         удаляет вкладку (то же делает крестик)
	Preview:CloseDrawer()   Preview:Toggle(target)  Preview:IsOpen()  Preview:SetTitle(text)  Preview:Destroy()
	Preview:OnClosed(fn)    Preview:GetTab(name)  Preview:GetTabs()  Preview:GetAsset(name)
	-- динамические источники: GetItems() + Added/Changed/Removed signals
	local Source = Preview:Source({
		Name = "Players", Tab = Models,
		GetItems = function() return game:GetService("Players"):GetPlayers() end,
		Added = Players.PlayerAdded, Changed = characterChanged, Removed = Players.PlayerRemoving,
		Key = function(player) return player.UserId end,
		Map = function(player) return { Name = player.Name, Type = "Player", Model = player.Character } end,
		Discover = { Enabled = true, Interval = 2, RemoveMissing = true }, -- периодическая сверка коллекции (0.5–30 сек)
		ObserveModels = true, -- автоматически отслеживать структуру и визуальные свойства моделей
		LiveMotion = true, -- опционально синхронизировать движение и позу выбранной модели (10–60 FPS, default 30)
		-- или LiveMotion = { Rate = 30 }
	})
	Source:Add(key, data)  Source:Update(key, patch)  Source:Refresh(key)  Source:Get(key)
	Source:Sync() -- принудительно сверить GetItems с текущими карточками
	Source:SetDiscovery(true/false)  Source:IsDiscoveryEnabled()
	Source:SetAutoObserve(key, true/false)
	Source:SetLiveMotion(key, true/false) -- синхронизировать движение/позу выбранной модели в большом Preview
	Preview:SetGrouping("Type" | "Creator" | "Category" | "None")  Preview:GetGrouping() -- группировка карточек
	Source:Remove(key)  Source:Clear()  Source:Destroy()

	-- левый список внутри вкладки
	local Models = Preview:Tab({ Name = "Models", Icon = "⬡" })
	local All    = Preview:Tab({ Name = "All", Icon = "▦", ShowAll = true })
	Preview:Header("Categories")
	Preview:Tab({ Name = "Weapons", Filter = function(asset) return asset.Type == "Weapon" end })

	-- ассеты
	local Tree = Models:Asset({
		Name = "Tree", Type = "Model",
		Creator = "Roblox", Created = "01.03.2024", Size = "1.5 MB", Version = "1.2",   -- всё необязательно
		Avatar = "rbxassetid://123",  или  AvatarUserId = 1,                           -- аватарка автора
		Description = "A simple tree.", Tags = { "nature" },
		Info = { { Label = "Polygons", Value = "1.2k", Icon = "▤" } },                  -- свои строки в Info
		Build = function(model) ... end,   или  Model = instance,  или  Image = "rbxassetid://..",
		Yaw = 0, Tilt = CFrame.Angles(0, 0, 0), Preview = true,
		Callback = function(asset) end,                                                 -- при выборе
		Actions = { { Name = "Equip", Icon = "✓", Callback = function(asset) end } },   -- меню "три точки"
	})
	Tree:Action({ Name, Icon, Callback })   -- ещё одно действие (максимум 5 на ассет)
	Models:Assets({ {...}, {...} })   Tree:Select()   Tree:Update({...})   Tree:Remove()
	Models:Clear()  Models:Open()  Models:Remove()

	-- свои страницы панели
	Preview:Page({ Name = "Stats", Icon = "▤", Visible = function(asset) return true end,
		Build = function(parent, asset, pv) ... return function() end end })   -- вернуть функцию очистки (необязательно)

	-- контролы страницы Actions. Вешаются на Preview (всегда), Tab (на вкладке) или Asset (только на нём)
	X:Button({ Name, Icon, Callback })              X:Toggle({ Name, Default, Flag, Callback(v) })
	X:Dropdown({ Name, Options, MultiSelect, MaxSelect, Default, Flag, Callback(v) })
	X:ColorPicker({ Name, Default, Flag, Callback(color) })
	X:Slider({ Name, Min, Max, Step, Default, Suffix, Flag, Callback(v) })
	X:Textbox({ Name, Placeholder, Default, Flag, Callback(text) })  -- Input остаётся алиасом
	X:Label({ Text })     X:Divider({ Label })
	Каждый контрол возвращает объект: :Get() :Set(v) :Remove()   Flag пишется в конфиг JustLib.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")

local GB, GM, G = Enum.Font.GothamBold, Enum.Font.GothamMedium, Enum.Font.Gotham
local V3, V2, CF, ANG, U2 = Vector3.new, Vector2.new, CFrame.new, CFrame.Angles, UDim2.new
local rgb = Color3.fromRGB
local QUINT, QUART = Enum.EasingStyle.Quint, Enum.EasingStyle.Quart
local OUT = Enum.EasingDirection.Out

local NAVW, GAP = 146, 8 -- ширина списка слева и отступ между колонками
local MAX_ACTIONS = 5

local B, C, ACCENTS -- заполняются в M.new (берутся у JustLib, темы меняются «на месте»)

local M = {}
M.__index = M
M.Version = "3.0"

--------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(inst, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, inst)
end

local function stroke(inst, col, th)
	return new("UIStroke", { Color = col, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
end

local function pad(inst, l, r, t, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r),
		PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
	}, inst)
end

local function txt(class, props, parent)
	local base = {
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = G, TextColor3 = C.txt,
		TextSize = 12, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
	}
	if class == "TextButton" then
		base.AutoButtonColor = false
	end
	for k, v in pairs(props) do
		base[k] = v
	end
	return new(class, base, parent)
end

local function tw(o, p, t, style, dir)
	if not o or not o.Parent then
		return
	end
	TS:Create(o, TweenInfo.new(t or 0.15, style or QUART, dir or OUT), p):Play()
end

local function safe(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[PreviewUI] " .. tostring(err))
	end
end

local function S(key, default)
	return B.cfgGet("_pv_" .. key, default)
end

local function curScale()
	local ok, s = pcall(function() return B.getScale and B.getScale() or 1 end)
	if ok and type(s) == "number" and s > 0 then
		return s
	end
	return 1
end

local function touchLast()
	return UIS:GetLastInputType() == Enum.UserInputType.Touch
end

local function isPtr(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function beginDrag(onMove, onEnd)
	local c1, c2
	c1 = B.keep(UIS.InputChanged:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			onMove(i)
		end
	end))
	c2 = B.keep(UIS.InputEnded:Connect(function(i)
		if isPtr(i) then
			c1:Disconnect()
			c2:Disconnect()
			if onEnd then
				onEnd()
			end
		end
	end))
end

-- Перетаскивание внутри ScrollingFrame: пока тянешь ползунок / колорпикер, панель не прокручивается
local function dragLocked(inst, onMove, onEnd)
	local frames = {}
	local sf = inst:FindFirstAncestorWhichIsA("ScrollingFrame")
	while sf do
		frames[#frames + 1] = sf
		sf.ScrollingEnabled = false
		sf = sf.Parent and sf.Parent:FindFirstAncestorWhichIsA("ScrollingFrame") or nil
	end
	beginDrag(onMove, function()
		for _, f in ipairs(frames) do
			f.ScrollingEnabled = true
		end
		if onEnd then
			onEnd()
		end
	end)
end

local function cleanDropdownLabel(value)
	local textValue = tostring(value or "")
	textValue = textValue:gsub("%[%]", ""):gsub("%s%s+", " ")
	return textValue:match("^%s*(.-)%s*$") or textValue
end



local function mkIcon(parent, icon, size, color)
	local raw = icon
	local resolved = type(raw) == "table" and raw or nil
	local fallbackGlyphs = {
		pin = "⌖", layers = "▱", filter = "▽", ["list-filter"] = "☷",
		["sliders-horizontal"] = "☷", ["chevron-down"] = "⌄",
	}
	if type(raw) == "string" and B and B.icon then
		local ok, value = pcall(B.icon, raw)
		if ok then
			resolved = value
		end
	end
	local url, glyph, font, fontFace, rectOffset, rectSize
	if type(resolved) == "table" then
		url = resolved.Url or resolved.Image or resolved.ImageUrl or resolved.Texture or resolved.Asset or resolved.AssetId or resolved.ImageId or resolved.Id
		glyph = resolved.Text or resolved.Glyph
		font = resolved.Font
		fontFace = resolved.FontFace
		rectOffset = resolved.ImageRectOffset
		rectSize = resolved.ImageRectSize
	elseif type(resolved) == "string" or type(resolved) == "number" then
		url = resolved
	end
	if url == nil then
		url = raw
	end
	local value = tostring(url or "")
	if value:match("^%d+$") then
		value = "rbxassetid://" .. value
	end
	if value:match("^rbxassetid://") or value:match("^rbxasset://") or value:match("^https?://") then
		local image = new("ImageLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
			Image = value, ImageColor3 = color, ScaleType = Enum.ScaleType.Fit,
			ImageRectOffset = typeof(rectOffset) == "Vector2" and rectOffset or Vector2.zero,
			ImageRectSize = typeof(rectSize) == "Vector2" and rectSize or Vector2.zero,
		}, parent)
		return image
	end
	local textValue = glyph
	if type(textValue) ~= "string" or textValue == "" or textValue == "[]" or textValue == "□" then
		textValue = fallbackGlyphs[type(raw) == "string" and raw or ""] or (type(raw) == "string" and raw or "")
	end
	local label = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Text = tostring(textValue),
		TextScaled = true, Font = font or GB, TextColor3 = color,
	}, parent)
	if fontFace then
		pcall(function() label.FontFace = fontFace end)
	end
	return label
end

local function setIconColor(ic, col)
	if ic:IsA("TextLabel") then
		tw(ic, { TextColor3 = col }, 0.18)
	else
		tw(ic, { ImageColor3 = col }, 0.18)
	end
end

local function mkSwitch(parent, pos, state)
	local track = new("Frame", {
		Position = pos, Size = UDim2.fromOffset(34, 18), BorderSizePixel = 0,
		BackgroundColor3 = state and C.togOn or C.togOff,
	}, parent)
	corner(track, 9)
	stroke(track, C.border, 1)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		Position = state and U2(1, -15, 0.5, -6) or U2(0, 3, 0.5, -6),
	}, track)
	corner(knob, 6)
	local sw = {}
	function sw.Set(v)
		tw(track, { BackgroundColor3 = v and C.togOn or C.togOff }, 0.16)
		tw(knob, { Position = v and U2(1, -15, 0.5, -6) or U2(0, 3, 0.5, -6) }, 0.2, QUINT)
	end
	return sw
end

local function snapNum(v, min, max, step)
	v = math.clamp(v, min, max)
	if step and step > 0 then
		v = math.floor((v - min) / step + 0.5) * step + min
		v = math.clamp(v, min, max)
	end
	return tonumber(string.format("%.6g", v)) or v
end

local function mkSlider(parent, pos, size, min, max, step, value, onChange)
	local track = new("Frame", { Position = pos, Size = size, BackgroundColor3 = C.slTrack, BorderSizePixel = 0 }, parent)
	corner(track, 3)
	local fill = new("Frame", { Size = U2(0, 0, 1, 0), BackgroundColor3 = ACCENTS[1], BorderSizePixel = 0 }, track)
	corner(fill, 3)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(12, 12), AnchorPoint = V2(0.5, 0.5), Position = U2(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	corner(knob, 6)
	local hit = new("TextButton", {
		Text = "", BackgroundTransparency = 1, Size = U2(1, 0, 0, 24), Position = U2(0, 0, 0.5, -12),
	}, track)
	local function show(v)
		local a = 0
		if max > min then
			a = (v - min) / (max - min)
		end
		fill.Size = U2(a, 0, 1, 0)
		knob.Position = U2(a, 0, 0.5, 0)
	end
	local function from(i)
		local ap, as = track.AbsolutePosition, track.AbsoluteSize
		local a = math.clamp((i.Position.X - ap.X) / math.max(as.X, 1), 0, 1)
		local v = snapNum(min + a * (max - min), min, max, step)
		show(v)
		onChange(v)
	end
	hit.InputBegan:Connect(function(i)
		if isPtr(i) then
			from(i)
			dragLocked(hit, from)
		end
	end)
	show(value)
	return { Set = show }
end

--------------------------------------------------------------------
-- 3D thumbnails (из Part'ов, ассеты не нужны)
--------------------------------------------------------------------
local function part(model, size, cf, color, shape, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.CFrame = cf
	p.Parent = model
	return p
end

local Ball, Cyl = Enum.PartType.Ball, Enum.PartType.Cylinder
local Neon, Metal = Enum.Material.Neon, Enum.Material.Metal

local function makeHead(model, color, y)
	local head = part(model, V3(2, 1, 1), CF(0, y, 0), color)
	new("SpecialMesh", { MeshType = Enum.MeshType.Head, Scale = V3(1.25, 1.25, 1.25) }, head)
	new("Decal", { Texture = "rbxasset://textures/face.png", Face = Enum.NormalId.Front }, head)
	return head
end

local Builders = {}

function Builders.R6(m)
	local c = rgb(165, 165, 192)
	part(m, V3(2, 2, 1), CF(0, 0, 0), c)
	makeHead(m, c, 1.5)
	part(m, V3(1, 2, 1), CF(-1.5, 0, 0), c)
	part(m, V3(1, 2, 1), CF(1.5, 0, 0), c)
	part(m, V3(1, 2, 1), CF(-0.5, -2, 0), c)
	part(m, V3(1, 2, 1), CF(0.5, -2, 0), c)
end

function Builders.Anime(m)
	local black, skin, hair = rgb(24, 24, 30), rgb(238, 224, 218), rgb(222, 224, 238)
	part(m, V3(2, 2, 1), CF(0, 0, 0), black)
	makeHead(m, skin, 1.5)
	part(m, V3(2.6, 0.7, 1.6), CF(0, 2.25, 0.05), hair)
	part(m, V3(2.6, 1.9, 0.6), CF(0, 1.6, 0.65), hair)
	part(m, V3(0.55, 0.8, 0.3), CF(-0.8, 2.85, 0) * ANG(0, 0, 0.25), black)
	part(m, V3(0.55, 0.8, 0.3), CF(0.8, 2.85, 0) * ANG(0, 0, -0.25), black)
	part(m, V3(1, 2, 1), CF(-1.5, 0, 0), black)
	part(m, V3(1, 2, 1), CF(1.5, 0, 0), black)
	part(m, V3(1, 2, 1), CF(-0.5, -2, 0), black)
	part(m, V3(1, 2, 1), CF(0.5, -2, 0), black)
	part(m, V3(1, 0.4, 1.1), CF(-0.5, -2.8, -0.05), hair)
	part(m, V3(1, 0.4, 1.1), CF(0.5, -2.8, -0.05), hair)
end

function Builders.Sword(m)
	local dark, neon = rgb(26, 22, 36), rgb(210, 70, 255)
	part(m, V3(0.3, 5.2, 0.12), CF(0, 1.9, 0), dark, nil, Metal)
	part(m, V3(0.06, 5.2, 0.14), CF(0.17, 1.9, 0), neon, nil, Neon)
	part(m, V3(0.06, 5.2, 0.14), CF(-0.17, 1.9, 0), neon, nil, Neon)
	part(m, V3(1.8, 0.28, 0.4), CF(0, -0.85, 0), dark, nil, Metal)
	part(m, V3(0.4, 0.4, 0.45), CF(0, -0.85, 0), neon, nil, Neon)
	part(m, V3(0.3, 1.3, 0.3), CF(0, -1.65, 0), rgb(40, 30, 55))
	part(m, V3(0.55, 0.55, 0.55), CF(0, -2.4, 0), neon, Ball, Neon)
end

function Builders.Checker(m)
	for i = 0, 5 do
		for j = 0, 5 do
			local c = ((i + j) % 2 == 0) and rgb(108, 111, 132) or rgb(68, 70, 92)
			part(m, V3(1.6, 0.2, 1.6), CF((i - 2.5) * 1.6, 0, (j - 2.5) * 1.6), c)
		end
	end
end

function Builders.Rock(m)
	local mat = Enum.Material.Slate
	part(m, V3(5, 5, 5), CF(0, 0, 0), rgb(112, 106, 96), Ball, mat)
	part(m, V3(3.5, 3.5, 3.5), CF(1.9, -0.7, 0.5), rgb(98, 94, 86), Ball, mat)
	part(m, V3(3, 3, 3), CF(-1.8, -0.8, -0.3), rgb(122, 116, 104), Ball, mat)
	part(m, V3(2.6, 2.6, 2.6), CF(0.3, 1.5, 0.6), rgb(104, 99, 90), Ball, mat)
end

function Builders.Tree(m)
	part(m, V3(4, 0.9, 0.9), CF(0, 2, 0) * ANG(0, 0, math.pi / 2), rgb(105, 74, 48), Cyl)
	part(m, V3(4.2, 4.2, 4.2), CF(0, 5.4, 0), rgb(52, 104, 48), Ball)
	part(m, V3(3.3, 3.3, 3.3), CF(-1.3, 4.4, 0.5), rgb(62, 118, 56), Ball)
	part(m, V3(3.3, 3.3, 3.3), CF(1.4, 4.3, -0.4), rgb(46, 94, 44), Ball)
	part(m, V3(2.8, 2.8, 2.8), CF(0, 7.2, 0), rgb(66, 124, 58), Ball)
end

function Builders.Car(m)
	local silver = rgb(165, 167, 182)
	part(m, V3(4.2, 1.2, 9), CF(0, 0.2, 0), silver)
	part(m, V3(3.4, 1, 4), CF(0, 1.3, 0.6), silver)
	part(m, V3(3.5, 0.6, 3.6), CF(0, 1.4, 0.6), rgb(28, 32, 46))
	part(m, V3(3.2, 0.15, 2.6), CF(0, 1.9, 0.6), silver)
	for _, x in ipairs({ -2.2, 2.2 }) do
		for _, z in ipairs({ -2.9, 3 }) do
			part(m, V3(0.9, 2, 2), CF(x, -0.4, z), rgb(24, 24, 30), Cyl)
		end
	end
	part(m, V3(0.9, 0.3, 0.1), CF(-1.3, 0.5, -4.52), rgb(255, 245, 210), nil, Neon)
	part(m, V3(0.9, 0.3, 0.1), CF(1.3, 0.5, -4.52), rgb(255, 245, 210), nil, Neon)
end

function Builders.Baseplate(m)
	part(m, V3(10, 0.8, 10), CF(0, 0, 0), rgb(88, 90, 102))
	for i = 0, 4 do
		for j = 0, 4 do
			part(m, V3(0.25, 1.1, 1.1), CF((i - 2) * 2, 0.5, (j - 2) * 2) * ANG(0, 0, math.pi / 2), rgb(96, 98, 110), Cyl)
		end
	end
end

function Builders.House(m)
	local warm = rgb(255, 190, 92)
	part(m, V3(8, 3, 6), CF(0, 0, 0), rgb(46, 50, 70))
	part(m, V3(7, 2.6, 5.4), CF(0, 2.8, 0), rgb(54, 58, 84))
	part(m, V3(8.4, 0.4, 6.4), CF(0, 4.3, 0), rgb(30, 32, 46))
	for _, x in ipairs({ -2.8, -1.2, 1.2, 2.8 }) do
		part(m, V3(1, 1.4, 0.1), CF(x, 0.1, -3.05), warm, nil, Neon)
	end
	for _, x in ipairs({ -2, 0, 2 }) do
		part(m, V3(1, 1.2, 0.1), CF(x, 2.9, -2.75), warm, nil, Neon)
	end
end

M.Builders = Builders

-- ViewportFrame с орбитальной камерой. Модель не двигается (только камера), поэтому вращение плавное.
-- Модель вписывается с запасом, поэтому края не обрезаются.
local function makeViewport(parent, src)
	local model
	local motionSource = src.Model
	if src.Model then
		local ok, c = pcall(function() return src.Model:Clone() end)
		if not ok or not c then
			return nil
		end
		if c:IsA("BasePart") then
			local wrap = Instance.new("Model")
			c.Parent = wrap
			c = wrap
		end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		model = c
	elseif src.Build then
		model = Instance.new("Model")
		local ok, err = pcall(src.Build, model)
		if not ok then
			warn("[PreviewUI] Build failed: " .. tostring(err))
		end
	else
		return nil
	end

	local motionParts = {}
	if motionSource then
		local sourceParts = {}
		local cloneParts = {}
		if motionSource:IsA("BasePart") then
			sourceParts[1] = motionSource
		else
			for _, d in ipairs(motionSource:GetDescendants()) do
				if d:IsA("BasePart") then sourceParts[#sourceParts + 1] = d end
			end
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then cloneParts[#cloneParts + 1] = d end
		end
		for i, sourcePart in ipairs(sourceParts) do
			local clonePart = cloneParts[i]
			if clonePart then
				motionParts[#motionParts + 1] = { source = sourcePart, clone = clonePart }
			end
		end
	end

	local okb, cf, size = pcall(function() return model:GetBoundingBox() end)
	if not okb or not cf then
		model:Destroy()
		return nil
	end
	model.WorldPivot = cf
	local center = cf.Position
	if src.Tilt then
		model:PivotTo(CF(center) * src.Tilt)
	end

	local vp = new("ViewportFrame", {
		-- Bright neutral studio lighting; preserve original asset colors without a dark overlay.
		BackgroundColor3 = rgb(68, 73, 88), BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1),
		Ambient = rgb(255, 255, 255), LightColor = rgb(255, 255, 255), LightDirection = V3(-0.2, -1, 0.35),
	}, parent)
	-- Round the actual rendered surface too; rounding only its outer holder leaves square viewport corners.
	corner(vp, 12)
	-- No gradient overlay: it can tint the rendered 3D content and make the whole stage look dim.
	model.Parent = vp

	local fov = 35
	local radius = math.max(size.Magnitude * 0.5, 0.5)
	local base = radius / math.sin(math.rad(fov / 2)) * 1.3
	-- Небольшая 3D-подиум-платформа и пол под моделью вместо пустого чёрного фона.
	local floorSize = math.max(radius * 4, 8)
	local floor = new("Part", {
		Name = "PreviewStageFloor", Anchored = true, CanCollide = false, CastShadow = true,
		Material = Enum.Material.SmoothPlastic, Color = rgb(112, 117, 132),
		Size = V3(floorSize, 0.12, floorSize),
		CFrame = CF(center.X, center.Y - size.Y * 0.5 - 0.06, center.Z),
	}, vp)
	local cam = new("Camera", { FieldOfView = fov }, vp)
	vp.CurrentCamera = cam
	local dir = V3(0.45, 0.4, -1).Unit
	local light = V3(-0.4, -1, 0.8)
	local startYaw = -(src.Yaw or 0)
	local h = { yaw = startYaw, tYaw = startYaw, zoom = 1, tZoom = 1, vel = 0, asset = src, model = model, animationActive = false }
	if motionSource and #motionParts > 0 then
		local ok, sourcePivot = pcall(function() return motionSource:GetPivot() end)
		if ok then
			local clonePivot = model:GetPivot()
			h.motionSource = motionSource
			h.motionModel = model
			h.motionParts = motionParts
			h.motionSourcePivot = sourcePivot
			h.motionClonePivot = clonePivot
			h.motionEnabled = src._liveMotionEnabled == true
			h.motionRate = math.clamp(tonumber(src._liveMotionRate) or 30, 10, 60)
			h.motionElapsed = 0
			function h.syncMotion()
				local source = h.motionSource
				if not source or not source.Parent or not h.motionModel or not h.motionModel.Parent then
					return false
				end
				local okPivot, currentPivot = pcall(function() return source:GetPivot() end)
				if not okPivot then return false end
				local targetPivot = currentPivot * h.motionSourcePivot:ToObjectSpace(h.motionClonePivot)
				local okMove = pcall(function() h.motionModel:PivotTo(targetPivot) end)
				if not okMove then return false end
				for _, pair in ipairs(h.motionParts) do
					if pair.source.Parent and pair.clone.Parent then
						local okPart, relative = pcall(function()
							return currentPivot:ToObjectSpace(pair.source.CFrame)
						end)
						if okPart then
							pcall(function() pair.clone.CFrame = targetPivot * relative end)
						end
					end
				end
				return true
			end
		end
	end

	local function place()
		local rot = ANG(0, h.yaw, 0)
		cam.CFrame = CFrame.lookAt(center + rot:VectorToWorldSpace(dir) * base * h.zoom, center)
		vp.LightDirection = rot:VectorToWorldSpace(light)
	end
	-- dt-независимое сглаживание: движение не «ступенчатое» ни на каком FPS
	function h.step(dt, auto, speed)
		dt = math.min(dt, 0.1)
		if math.abs(h.vel) > 0.01 then
			h.tYaw = h.tYaw + h.vel * dt
			h.vel = h.vel * math.exp(-dt * 2.8)
		else
			h.vel = 0
		end
		if auto then
			h.tYaw = h.tYaw + speed * dt
		end
		local a = 1 - math.exp(-dt * 13)
		h.yaw = h.yaw + (h.tYaw - h.yaw) * a
		h.zoom = h.zoom + (h.tZoom - h.zoom) * a
		place()
	end
	function h.drag(rad)
		h.tYaw = h.tYaw + rad
	end
	function h.zoomBy(f)
		h.tZoom = math.clamp(h.tZoom * f, 0.45, 2.4)
	end
	function h.reset()
		local two = math.pi * 2
		h.yaw = h.yaw % two
		h.tYaw = startYaw % two
		if h.yaw - h.tYaw > math.pi then
			h.tYaw = h.tYaw + two
		end
		h.tZoom = 1
		h.vel = 0
	end
	place()
	return h
end

local function normImage(s)
	s = tostring(s)
	if s:match("^%d+$") then
		return "rbxassetid://" .. s
	end
	return s
end

local function makeThumb(parent, asset)
	if asset.Image then
		local img = new("ImageLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Image = normImage(asset.Image), ScaleType = Enum.ScaleType.Fit,
		}, parent)
		corner(img, 12)
		img:SetAttribute("JLNoRepaint", true)
		return nil
	end
	local h = makeViewport(parent, asset)
	if h then
		return h
	end
	txt("TextLabel", {
		Text = "No preview", TextSize = 11, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
	}, parent)
	return nil
end

local function hasPreview(a)
	if a.Preview == false then
		return false
	end
	if a.Model ~= nil or a.Build ~= nil or a.Image ~= nil then
		return true
	end
	for _, variant in ipairs(a._variants or {}) do
		if variant.Model ~= nil or variant.Build ~= nil or variant.Image ~= nil then
			return true
		end
	end
	return false
end

local VARIANT_FIELDS = {
	"Model", "Build", "Image", "Description", "Tags", "Info", "Version", "Type",
	"Icon", "Yaw", "Tilt", "Creator", "Created", "Size", "Avatar", "AvatarUserId",
}

local function hasInfo(a)
	return a.Description ~= nil or a.Tags ~= nil or a.Info ~= nil or a.Creator ~= nil
		or a.Created ~= nil or a.Size ~= nil or a.Version ~= nil or a.Avatar ~= nil or a.AvatarUserId ~= nil
end

--------------------------------------------------------------------
-- контролы (страница Actions)
--------------------------------------------------------------------
local CtrlBuilders = {}
local RH = 32 -- высота строки контрола

local function rowFrame(parent, h, order)
	return new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = U2(1, 0, 0, h), LayoutOrder = order }, parent)
end

local function headButton(row, h)
	local b = txt("TextButton", { BackgroundTransparency = 0, BackgroundColor3 = C.btnBg, Size = U2(1, 0, 0, h) }, row)
	corner(b, 7)
	stroke(b, C.border, 1)
	b.MouseEnter:Connect(function()
		if not touchLast() then
			tw(b, { BackgroundColor3 = C.btnHov }, 0.12)
		end
	end)
	b.MouseLeave:Connect(function()
		tw(b, { BackgroundColor3 = C.btnBg }, 0.12)
	end)
	return b
end

CtrlBuilders.Button = function(def, parent, order)
	local o = def.o
	local row = rowFrame(parent, RH, order)
	local b = headButton(row, RH)
	b.Size = UDim2.fromScale(1, 1)
	local ix = 0
	if o.Icon then
		local ic = mkIcon(b, o.Icon, 14, ACCENTS[1])
		ic.Position = U2(0, 10, 0.5, -7)
		ix = 30
	end
	def._lbl = txt("TextLabel", {
		Text = def.name, Font = GB, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
		Position = U2(0, ix, 0, 0), Size = U2(1, -ix - 8, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
	}, b)
	b.Activated:Connect(function()
		tw(b, { BackgroundColor3 = ACCENTS[1] }, 0.07)
		B.delay(0.15, function()
			tw(b, { BackgroundColor3 = C.btnBg }, 0.2)
		end)
		def:Fire()
	end)
	return row
end

CtrlBuilders.Toggle = function(def, parent, order)
	local row = rowFrame(parent, RH, order)
	local bg = headButton(row, RH)
	bg.Size = UDim2.fromScale(1, 1)
	local lbl = txt("TextLabel", {
		Text = def.name, Font = GB, TextSize = 12, Position = U2(0, 10, 0, 0), Size = U2(1, -58, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, bg)
	local sw = mkSwitch(bg, U2(1, -44, 0.5, -9), def.value)
	def._refresh = function()
		sw.Set(def.value)
		lbl.Text = def.name
	end
	bg.Activated:Connect(function()
		def:Set(not def.value)
	end)
	return row
end

CtrlBuilders.Dropdown = function(def, parent, order)
	local HEAD, OPT = RH, 26
	local row = rowFrame(parent, HEAD, order)
	row.ClipsDescendants = true
	local head = headButton(row, HEAD)
	local lbl = txt("TextLabel", {
		Font = GB, TextSize = 12, Position = U2(0, 10, 0, 0), Size = U2(1, -34, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, head)
	local arrow = txt("TextLabel", {
		Text = "▼", Font = GB, TextSize = 9, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center, Position = U2(1, -24, 0, 0), Size = U2(0, 20, 1, 0),
	}, head)
	local list = new("ScrollingFrame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0, Visible = false,
		Position = U2(0, 0, 0, HEAD + 4), Size = U2(1, 0, 0, 0),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENTS[1],
	}, row)
	corner(list, 7)
	stroke(list, C.border, 1)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, list)
	table.insert(def._pv._scrollers, list)

	local open = false
	local optBtns = {}

	local function labelText()
		local picked = {}
		for _, opt in ipairs(def.options) do
			if def.sel[opt] then
				picked[#picked + 1] = tostring(opt)
			end
		end
		if #picked == 0 or def.o.Static then
			return def.name
		end
		return def.name .. ": " .. table.concat(picked, ", ")
	end

	local function resize()
		local lh = math.min(#def.options * (OPT + 2) + 6, 4 * (OPT + 2) + 6)
		list.Size = U2(1, 0, 0, lh)
		tw(row, { Size = U2(1, 0, 0, open and (HEAD + 4 + lh) or HEAD) }, 0.28, QUINT)
	end

	local function rebuild()
		for _, b in ipairs(optBtns) do
			b:Destroy()
		end
		optBtns = {}
		for i, opt in ipairs(def.options) do
			local on = def.sel[opt] == true
			-- фиксированная ширина: не зависит от особенностей ScrollingFrame
			local ob = txt("TextButton", {
				BackgroundTransparency = on and 0.85 or 1, BackgroundColor3 = ACCENTS[1],
				Size = U2(1, -8, 0, OPT), LayoutOrder = i,
			}, list)
			corner(ob, 5)
			txt("TextLabel", {
				Text = tostring(opt), Font = GB, TextSize = 11, TextColor3 = on and ACCENTS[1] or C.txt,
				Position = U2(0, 8, 0, 0), Size = U2(1, -30, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
			}, ob)
			if on then
				txt("TextLabel", {
					Text = "✓", Font = GB, TextSize = 11, TextColor3 = ACCENTS[1],
					TextXAlignment = Enum.TextXAlignment.Center, Position = U2(1, -22, 0, 0), Size = U2(0, 18, 1, 0),
				}, ob)
			end
			ob.Activated:Connect(function()
				if def.multi then
					local count = 0
					for _ in pairs(def.sel) do
						count = count + 1
					end
					if def.sel[opt] then
						def.sel[opt] = nil
					elseif count < def.maxSel then
						def.sel[opt] = true
					end
				else
					def.sel = {}
					def.sel[opt] = true
					open = false
					list.Visible = false
					arrow.Text = "▼"
				end
				def:_commit()
				resize()
			end)
			optBtns[#optBtns + 1] = ob
		end
	end

	def._refresh = function()
		lbl.Text = labelText()
		rebuild()
		resize()
	end
	head.Activated:Connect(function()
		open = not open
		list.Visible = open
		arrow.Text = open and "▲" or "▼"
		resize()
	end)
	def._refresh()
	return row
end

CtrlBuilders.ColorPicker = function(def, parent, order)
	local HEAD, PH = RH, 138
	local row = rowFrame(parent, HEAD, order)
	row.ClipsDescendants = true
	local head = headButton(row, HEAD)
	txt("TextLabel", {
		Text = def.name, Font = GB, TextSize = 12, Position = U2(0, 10, 0, 0), Size = U2(1, -64, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, head)
	local swatch = new("Frame", {
		Size = UDim2.fromOffset(34, 18), Position = U2(1, -44, 0.5, -9), BackgroundColor3 = def.value, BorderSizePixel = 0,
	}, head)
	corner(swatch, 5)
	stroke(swatch, C.border, 1)
	swatch:SetAttribute("JLNoRepaint", true)

	local pick = new("Frame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0, Visible = false,
		Position = U2(0, 0, 0, HEAD + 4), Size = U2(1, 0, 0, PH),
	}, row)
	corner(pick, 7)
	stroke(pick, C.border, 1)

	local h, s, v = Color3.toHSV(def.value)

	local svBg = new("Frame", {
		Position = U2(0, 8, 0, 8), Size = U2(1, -42, 0, 88), BorderSizePixel = 0, BackgroundColor3 = Color3.fromHSV(h, 1, 1),
	}, pick)
	corner(svBg, 5)
	svBg:SetAttribute("JLNoRepaint", true)
	local sat = new("Frame", { Size = U2(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, svBg)
	corner(sat, 5)
	sat:SetAttribute("JLNoRepaint", true)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, sat)
	local val = new("Frame", { Size = U2(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3 }, svBg)
	corner(val, 5)
	val:SetAttribute("JLNoRepaint", true)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, val)
	local svCursor = new("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 4 }, svBg)
	corner(svCursor, 5)
	stroke(svCursor, Color3.new(1, 1, 1), 2)
	local svHit = new("TextButton", { Size = U2(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 5 }, svBg)

	local hueBar = new("Frame", {
		Position = U2(1, -26, 0, 8), Size = U2(0, 18, 0, 88), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, pick)
	corner(hueBar, 4)
	hueBar:SetAttribute("JLNoRepaint", true)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 0, 0)), ColorSequenceKeypoint.new(0.167, rgb(255, 255, 0)),
			ColorSequenceKeypoint.new(0.333, rgb(0, 255, 0)), ColorSequenceKeypoint.new(0.5, rgb(0, 255, 255)),
			ColorSequenceKeypoint.new(0.667, rgb(0, 0, 255)), ColorSequenceKeypoint.new(0.833, rgb(255, 0, 255)),
			ColorSequenceKeypoint.new(1, rgb(255, 0, 0)),
		}),
	}, hueBar)
	local hueCursor = new("Frame", {
		Size = U2(1, 6, 0, 5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
	}, hueBar)
	corner(hueCursor, 2)
	hueCursor:SetAttribute("JLNoRepaint", true)
	local hueHit = new("TextButton", { Size = U2(1, 8, 1, 0), Position = U2(0, -4, 0, 0), BackgroundTransparency = 1, Text = "", ZIndex = 3 }, hueBar)

	local hexBox = txt("TextBox", {
		BackgroundTransparency = 0, BackgroundColor3 = C.pHdr, Font = GB, TextSize = 12,
		ClearTextOnFocus = false, Position = U2(0, 8, 0, 104), Size = U2(1, -16, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, pick)
	corner(hexBox, 5)
	stroke(hexBox, C.border, 1)

	local function visuals()
		local col = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = col
		svBg.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = U2(s, -5, 1 - v, -5)
		hueCursor.Position = U2(0, -3, h, -2)
		if not hexBox:IsFocused() then
			hexBox.Text = "#" .. col:ToHex():upper()
		end
	end
	local function commit()
		visuals()
		def:_setColor(Color3.fromHSV(h, s, v))
	end
	local function svFrom(i)
		local ap, as = svBg.AbsolutePosition, svBg.AbsoluteSize
		s = math.clamp((i.Position.X - ap.X) / math.max(as.X, 1), 0, 1)
		v = math.clamp(1 - (i.Position.Y - ap.Y) / math.max(as.Y, 1), 0, 1)
		commit()
	end
	local function hueFrom(i)
		local ap, as = hueBar.AbsolutePosition, hueBar.AbsoluteSize
		h = math.clamp((i.Position.Y - ap.Y) / math.max(as.Y, 1), 0, 1)
		commit()
	end
	-- dragLocked: пока тянешь цвет, панель не прокручивается вверх-вниз
	svHit.InputBegan:Connect(function(i)
		if isPtr(i) then
			svFrom(i)
			dragLocked(svHit, svFrom)
		end
	end)
	hueHit.InputBegan:Connect(function(i)
		if isPtr(i) then
			hueFrom(i)
			dragLocked(hueHit, hueFrom)
		end
	end)
	hexBox.FocusLost:Connect(function()
		local t = hexBox.Text:gsub("#", ""):gsub("%s", "")
		if #t == 6 then
			local ok, c3 = pcall(function() return Color3.fromHex(t) end)
			if ok and c3 then
				h, s, v = Color3.toHSV(c3)
				commit()
				return
			end
		end
		visuals()
	end)

	def._refresh = function()
		h, s, v = Color3.toHSV(def.value)
		visuals()
	end
	head.Activated:Connect(function()
		local on = not pick.Visible
		pick.Visible = on
		tw(row, { Size = U2(1, 0, 0, on and (HEAD + 4 + PH) or HEAD) }, 0.28, QUINT)
	end)
	visuals()
	return row
end

CtrlBuilders.Slider = function(def, parent, order)
	local row = rowFrame(parent, 44, order)
	local bg = new("Frame", { BackgroundColor3 = C.btnBg, BorderSizePixel = 0, Size = U2(1, 0, 1, 0) }, row)
	corner(bg, 7)
	stroke(bg, C.border, 1)
	local lbl = txt("TextLabel", {
		Text = def.name, Font = GB, TextSize = 12, Position = U2(0, 10, 0, 4), Size = U2(1, -76, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, bg)
	local suffix = def.o.Suffix or ""
	local vl = txt("TextLabel", {
		Font = GB, TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right,
		Position = U2(1, -64, 0, 4), Size = U2(0, 54, 0, 18),
	}, bg)
	local bar = mkSlider(bg, U2(0, 10, 0, 30), U2(1, -20, 0, 5), def.min, def.max, def.step, def.value, function(x)
		def:_slide(x)
		vl.Text = tostring(x) .. suffix
	end)
	def._refresh = function()
		lbl.Text = def.name
		bar.Set(def.value)
		vl.Text = tostring(def.value) .. suffix
	end
	def._refresh()
	return row
end

CtrlBuilders.Input = function(def, parent, order)
	local row = rowFrame(parent, RH, order)
	local bg = new("Frame", { BackgroundColor3 = C.input, BorderSizePixel = 0, Size = U2(1, 0, 1, 0) }, row)
	corner(bg, 7)
	stroke(bg, C.border, 1)
	local box = txt("TextBox", {
		PlaceholderText = def.o.Placeholder or def.name, PlaceholderColor3 = C.dim, Text = def.value,
		Font = GB, TextSize = 12, ClearTextOnFocus = false, Position = U2(0, 10, 0, 0), Size = U2(1, -20, 1, 0),
	}, bg)
	table.insert(def._pv._phs, box)
	box.FocusLost:Connect(function()
		def:_typed(box.Text)
	end)
	def._refresh = function()
		box.Text = def.value
	end
	return row
end

CtrlBuilders.Label = function(def, parent, order)
	local l = txt("TextLabel", {
		Text = def.value, TextSize = 11, TextColor3 = def.o.Color or C.dim, TextWrapped = true,
		Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order,
	}, parent)
	def._refresh = function()
		l.Text = def.value
	end
	return l
end

CtrlBuilders.Divider = function(def, parent, order)
	local row = rowFrame(parent, 16, order)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = U2(0, 0, 0.5, 0), Size = U2(1, 0, 0, 1) }, row)
	if def.o.Label then
		local w = math.min(#tostring(def.o.Label) * 7 + 14, 200)
		local bg = new("Frame", {
			BackgroundColor3 = C.panel, BorderSizePixel = 0, Position = U2(0.5, -w / 2, 0.5, -8), Size = UDim2.fromOffset(w, 16),
		}, row)
		txt("TextLabel", {
			Text = def.o.Label, Font = GB, TextSize = 10, TextColor3 = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center, Size = U2(1, 0, 1, 0),
		}, bg)
	end
	return row
end

local function initVal(o, default)
	if o.Flag then
		return B.cfgGet(o.Flag, default), B.cfgHas(o.Flag)
	end
	return default, false
end

local function storeFlag(o, val, store)
	if o.Flag then
		B.cfgSet(o.Flag, val, store)
	end
end

local function makeControl(container, kind, o)
	o = o or {}
	local pv = container._pv
	local def = { kind = kind, o = o, _pv = pv, _container = container, name = o.Name or kind }
	if container._isAsset then
		def.pinned = o.Pinned ~= false
		def.variantIndex = nil
		def.variantsPinned = nil
		if type(o.VariantsPinned) == "table" and #o.VariantsPinned > 0 then
			def.variantsPinned = {}
			for _, target in ipairs(o.VariantsPinned) do
				for i, variant in ipairs(container._variants or {}) do
					if target == i or target == variant.Name then
						def.variantsPinned[i] = true
					end
				end
			end
		elseif not def.pinned then
			if o.Variant ~= nil then
				for i, variant in ipairs(container._variants or {}) do
					if variant.Name == o.Variant then
						def.variantIndex = i
						break
					end
				end
			else
				def.variantIndex = container._variantIndex or 1
			end
		end
	end
	local had = false

	if kind == "Toggle" then
		local v
		v, had = initVal(o, o.Default == true)
		def.value = (v == true)
	elseif kind == "Dropdown" then
		def.options = o.Options or {}
		def.multi = (o.MultiSelect == true)
		def.maxSel = o.MaxSelect or (def.multi and math.max(#def.options, 1) or 1)
		local v
		v, had = initVal(o, o.Default)
		def.sel = {}
		if type(v) == "table" then
			for _, x in ipairs(v) do
				def.sel[x] = true
			end
		elseif v ~= nil and v ~= "" then
			def.sel[v] = true
		end
	elseif kind == "ColorPicker" then
		local v
		v, had = initVal(o, o.Default or Color3.new(1, 1, 1))
		if type(v) == "table" then
			v = rgb(v[1] or 255, v[2] or 255, v[3] or 255)
		end
		def.value = v
	elseif kind == "Slider" then
		def.min = o.Min or 0
		def.max = o.Max or 100
		def.step = o.Step or 1
		local v
		v, had = initVal(o, o.Default or def.min)
		def.value = snapNum(tonumber(v) or def.min, def.min, def.max, def.step)
	elseif kind == "Input" then
		local v
		v, had = initVal(o, o.Default or "")
		def.value = tostring(v or "")
	elseif kind == "Label" then
		def.value = tostring(o.Text or o.Name or "")
	end

	function def:Get()
		if kind == "Dropdown" then
			local arr = {}
			for _, opt in ipairs(self.options) do
				if self.sel[opt] then
					arr[#arr + 1] = opt
				end
			end
			if self.multi then
				return arr
			end
			return arr[1]
		end
		return self.value
	end

	function def:Fire()
		safe(o.Callback, self)
	end

	function def:_commit() -- Dropdown
		local v = self:Get()
		storeFlag(o, v)
		if self._refresh then
			self._refresh()
		end
		safe(o.Callback, v)
	end

	function def:_setColor(col, silent)
		self.value = col
		storeFlag(o, col, { math.round(col.R * 255), math.round(col.G * 255), math.round(col.B * 255) })
		if self._refresh and silent then
			self._refresh()
		end
		if not silent then
			safe(o.Callback, col)
		end
	end

	function def:_slide(v)
		self.value = v
		storeFlag(o, v)
		safe(o.Callback, v)
	end

	function def:_typed(t)
		self.value = t
		storeFlag(o, t)
		safe(o.Callback, t)
	end

	function def:Set(v, silent)
		if kind == "Toggle" then
			self.value = (v == true)
			storeFlag(o, self.value)
			if not silent then
				safe(o.Callback, self.value)
			end
		elseif kind == "Dropdown" then
			self.sel = {}
			if type(v) == "table" then
				for _, x in ipairs(v) do
					self.sel[x] = true
				end
			elseif v ~= nil and v ~= "" then
				self.sel[v] = true
			end
			storeFlag(o, self:Get())
			if not silent then
				safe(o.Callback, self:Get())
			end
		elseif kind == "ColorPicker" then
			if type(v) == "table" then
				v = rgb(v[1] or 255, v[2] or 255, v[3] or 255)
			end
			self:_setColor(v, true)
			if not silent then
				safe(o.Callback, v)
			end
		elseif kind == "Slider" then
			self.value = snapNum(tonumber(v) or self.min, self.min, self.max, self.step)
			storeFlag(o, self.value)
			if not silent then
				safe(o.Callback, self.value)
			end
		elseif kind == "Input" then
			self.value = tostring(v or "")
			storeFlag(o, self.value)
			if not silent then
				safe(o.Callback, self.value)
			end
		elseif kind == "Label" then
			self.value = tostring(v or "")
			if self._refresh then
				self._refresh()
			end
			return
		else
			return
		end
		if self._refresh then
			self._refresh()
		end
	end

	function def:SetName(t)
		self.name = tostring(t)
		if self._lbl then
			self._lbl.Text = self.name
		elseif self._refresh then
			self._refresh()
		end
	end

	function def:SetOptions(list)
		self.options = list or {}
		for k in pairs(self.sel or {}) do
			local keep = false
			for _, opt in ipairs(self.options) do
				if opt == k then
					keep = true
				end
			end
			if not keep then
				self.sel[k] = nil
			end
		end
		pv:_ctrlChanged()
	end

	function def:Remove()
		for i, d in ipairs(container._controls) do
			if d == self then
				table.remove(container._controls, i)
				break
			end
		end
		if o.Flag and B.registry[o.Flag] == self then
			B.registry[o.Flag] = nil
		end
		pv:_ctrlChanged()
	end
	def.Destroy = def.Remove

	if o.Flag then
		B.registry[o.Flag] = def
		if o.NoSave or kind == "Button" or kind == "Label" then
			B.noSave[o.Flag] = true
		else
			B.noSave[o.Flag] = nil
		end
	end

	container._controls[#container._controls + 1] = def
	pv:_ctrlChanged()
	if had and o.Callback and kind ~= "Button" and kind ~= "Label" then
		safe(o.Callback, def:Get())
	end
	return def
end

local KINDS = { "Button", "Toggle", "Dropdown", "ColorPicker", "Slider", "Input", "Label", "Divider" }

local function attachControls(obj)
	obj._controls = {}
	for _, kind in ipairs(KINDS) do
		obj[kind] = function(selfObj, o)
			return makeControl(selfObj, kind, o)
		end
	end
	obj.Textbox = function(selfObj, o)
		return makeControl(selfObj, "Input", o)
	end
end

for _, kind in ipairs(KINDS) do
	M[kind] = function(selfObj, o)
		return makeControl(selfObj, kind, o)
	end
end

-- Textbox is the public name; Input remains as a backward-compatible alias.
M.Textbox = function(selfObj, o)
	return makeControl(selfObj, "Input", o)
end

--------------------------------------------------------------------
-- страницы панели (drawer)
-- ВАЖНО: ширина строк задаётся явными отступами (Position/Size с offset), а не UIPadding внутри
-- ScrollingFrame: иначе правый отступ не учитывается и строки обрезаются правым краем.
--------------------------------------------------------------------
local PAGES = {}

local function pageScroll(parent, pv)
	local sf = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2, ScrollBarImageColor3 = ACCENTS[1], ScrollBarImageTransparency = 0.35,
		ScrollingDirection = Enum.ScrollingDirection.Y, ClipsDescendants = true,
	}, parent)
	table.insert(pv._scrollers, sf)
	local content = new("Frame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 10),
		Size = U2(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	}, sf)
	return sf, content
end

local function infoRow(parent, order, icon, label, value)
	local row = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 26), LayoutOrder = order }, parent)
	local ic = mkIcon(row, icon, 14, C.dim)
	ic.Position = UDim2.fromOffset(0, 6)
	txt("TextLabel", {
		Text = tostring(label), TextSize = 12, TextColor3 = C.dim, Position = UDim2.fromOffset(22, 0), Size = UDim2.fromOffset(70, 26),
	}, row)
	txt("TextLabel", {
		Text = tostring(value), Font = GM, TextSize = 12, TextColor3 = C.txt, TextXAlignment = Enum.TextXAlignment.Right,
		Position = U2(0, 92, 0, 0), Size = U2(1, -92, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
end

local function buildVariantSelector(parent, a)
	local variants = a._variants or {}
	local variantBar
	if #variants > 1 then
		local header = new("Frame", {
			BackgroundTransparency = 1, Size = U2(1, 0, 0, 24), LayoutOrder = 0,
		}, parent)
		local pinIcon = mkIcon(header, "pin", 15, C.dim)
		pinIcon.Position = UDim2.fromOffset(2, 4)
		txt("TextLabel", {
			Text = "Variants", Font = GB, TextSize = 12, TextColor3 = C.dim,
			Position = UDim2.fromOffset(25, 0), Size = U2(1, -25, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, header)
		variantBar = new("Frame", {
			Name = "VariantDropdown", BackgroundTransparency = 1, BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0), Size = U2(1, 0, 0, 36), ZIndex = 30, LayoutOrder = 1,
		}, parent)
			local selectedIndex = a._variantIndex or 1
			local selectedVariant = variants[selectedIndex]
			local trigger = txt("TextButton", {
				Name = "VariantDropdownButton", Text = "", TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = C.btnBg, BackgroundTransparency = 0.05,
				Size = UDim2.fromScale(1, 1), ZIndex = 31,
			}, variantBar)
			corner(trigger, 7)
			stroke(trigger, C.border, 1)
			local variantIcon = mkIcon(trigger, "layers", 15, C.dim)
			variantIcon.Position = UDim2.fromOffset(9, 10)
			variantIcon.ZIndex = 32
			local title = txt("TextLabel", {
				Text = "Version", Font = GM, TextSize = 9, TextColor3 = C.dim,
				Position = UDim2.fromOffset(31, 2), Size = U2(1, -54, 0, 11), ZIndex = 32,
			}, trigger)
			local current = txt("TextLabel", {
				Text = cleanDropdownLabel(selectedVariant and selectedVariant.Name or "Variant " .. selectedIndex),
				Font = GB, TextSize = 11, TextColor3 = C.txt,
				Position = UDim2.fromOffset(31, 13), Size = U2(1, -56, 0, 16),
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 32,
			}, trigger)
			local arrow = mkIcon(trigger, "chevron-down", 13, C.dim)
			arrow.ZIndex = 32
			arrow.AnchorPoint = V2(0.5, 0.5)
			arrow.Position = U2(1, -17, 0.5, 0)
			local menu = new("Frame", {
				Name = "VariantOptions", BackgroundColor3 = C.input, BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 40), Size = U2(1, 0, 0, math.min(#variants * 30 + 8, 128)),
				Visible = false, ZIndex = 35,
			}, variantBar)
			corner(menu, 7)
			stroke(menu, C.border, 1)
			pad(menu, 4, 4, 4, 4)
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, menu)
			local optionButtons = {}
			local function closeMenu()
				menu.Visible = false
				arrow.Rotation = 0
			end
			for i, variant in ipairs(variants) do
				local option = txt("TextButton", {
					Text = "", BackgroundColor3 = ACCENTS[1],
					BackgroundTransparency = i == selectedIndex and 0.84 or 1,
					Size = U2(1, 0, 0, 28), LayoutOrder = i, ZIndex = 36,
				}, menu)
				corner(option, 5)
				local optionName = cleanDropdownLabel(variant.Name or ("Variant " .. i))
				txt("TextLabel", {
					Text = optionName, Font = i == selectedIndex and GB or GM, TextSize = 11,
					TextColor3 = i == selectedIndex and ACCENTS[1] or C.txt,
					Position = UDim2.fromOffset(8, 0), Size = U2(1, -30, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 37,
				}, option)
				if i == selectedIndex then
					txt("TextLabel", {
						Text = "✓", Font = GB, TextSize = 11, TextColor3 = ACCENTS[1],
						TextXAlignment = Enum.TextXAlignment.Center, Position = U2(1, -24, 0, 0),
						Size = UDim2.fromOffset(18, 28), ZIndex = 37,
					}, option)
				end
				option.Activated:Connect(function()
					closeMenu()
					a:SetVariant(i)
				end)
				optionButtons[#optionButtons + 1] = option
			end
			trigger.Activated:Connect(function()
				menu.Visible = not menu.Visible
				arrow.Rotation = menu.Visible and 180 or 0
			end)
		end
end

-- Actions: все контролы ассета, его вкладки и самого Preview
PAGES.controllers = {
	id = "controllers", name = "Controllers", icon = "sliders-horizontal",
	build = function(parent, asset, pv)
		local _, content = pageScroll(parent, pv)
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, content)
		buildVariantSelector(content, asset)
		local list = pv:_controlsFor(asset)
		for i, def in ipairs(list) do
			local b = CtrlBuilders[def.kind]
			if b then
				local ok, err = pcall(b, def, content, i)
				if not ok then
					warn("[PreviewUI] control '" .. tostring(def.name) .. "' failed: " .. tostring(err))
				end
			end
		end
		new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 12), LayoutOrder = #list + 1 }, content)
		return function()
			for _, def in ipairs(list) do
				def._refresh = nil
				def._lbl = nil
			end
		end
	end,
}

-- Discover Animation instances stored in the model and animations exposed by its Animators.
local function discoverAnimations(asset)
	local model = asset and asset.Model
	if typeof(model) ~= "Instance" then
		return {}
	end
	local found, seen = {}, {}
	local function add(animation, state)
		if not animation or not animation:IsA("Animation") then return end
		local id = tostring(animation.AnimationId or "")
		local key = id ~= "" and id or animation:GetFullName()
		if seen[key] then
			if state == "Playing" then
				seen[key].State = "Playing"
			end
			return
		end
		local name = animation.Name
		if name == "" or string.lower(name) == "animation" then
			local ancestor = animation.Parent
			while ancestor and ancestor ~= model do
				local candidate = tostring(ancestor.Name or "")
				local lowered = string.lower(candidate)
				if candidate ~= "" and lowered ~= "animations" and lowered ~= "animate"
					and lowered ~= "animator" and lowered ~= "humanoid" then
					name = candidate
					break
				end
				ancestor = ancestor.Parent
			end
		end
		if name == "" or string.lower(name) == "animation" then
			name = "Animation " .. tostring(#found + 1)
		end
		local entry = {
			Name = name,
			AnimationId = id,
			Object = animation,
			State = state or "Available",
		}
		seen[key] = entry
		found[#found + 1] = entry
	end
	local descendants = model:GetDescendants()
	if model:IsA("Animation") then
		add(model, "Available")
	end
	for _, instance in ipairs(descendants) do
		if instance:IsA("Animation") then
			add(instance, "Available")
		elseif instance:IsA("Animator") then
			local ok, tracks = pcall(function()
					return instance:GetPlayingAnimationTracks()
				end)
			if ok then
				for _, track in ipairs(tracks) do
					local animation
					pcall(function() animation = track.Animation end)
					if animation then add(animation, "Playing") end
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return string.lower(a.Name) < string.lower(b.Name)
	end)
	local nameCounts = {}
	for _, entry in ipairs(found) do
		local base = entry.Name
		nameCounts[base] = (nameCounts[base] or 0) + 1
		if nameCounts[base] > 1 then
			entry.Name = base .. " " .. tostring(nameCounts[base])
		end
	end
	return found
end

-- Info: название, автор, аватарка, даты и любые свои строки
PAGES.info = {
	id = "info", name = "Info", icon = "info",
	build = function(parent, a, pv)
		local _, content = pageScroll(parent, pv)
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, content)

		local avatar = a.Avatar
		if not avatar and a.AvatarUserId then
			avatar = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(a.AvatarUserId) .. "&w=150&h=150"
		end
		local top = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 62), LayoutOrder = 1 }, content)
		local tx = 0
		if avatar then
			local av = new("ImageLabel", {
				BackgroundColor3 = C.badge, BorderSizePixel = 0, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(0, 5),
				Image = normImage(avatar), ScaleType = Enum.ScaleType.Crop,
			}, top)
			corner(av, 26)
			stroke(av, ACCENTS[1], 2)
			av:SetAttribute("JLNoRepaint", true)
			tx = 62
		end
		txt("TextLabel", {
			Text = tostring(a.Name), Font = GB, TextSize = 15, Position = UDim2.fromOffset(tx, 9), Size = U2(1, -tx, 0, 20),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, top)
		local sub = tostring(a.Type or "")
		if a.Creator then
			sub = (sub ~= "" and (sub .. "  ·  ") or "") .. "by " .. tostring(a.Creator)
		end
		txt("TextLabel", {
			Text = sub, TextSize = 11, TextColor3 = C.dim, Position = UDim2.fromOffset(tx, 31), Size = U2(1, -tx, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, top)


		local order = 3
		local function add(icon, label, value)
			if value ~= nil and value ~= "" then
				infoRow(content, order, icon, label, value)
				order = order + 1
			end
		end
		add("user-round", "Creator", a.Creator)
		add("calendar-days", "Created", a.Created)
		add("box", "Size", a.Size)
		add("git-branch", "Version", a.Version)
		add("tag", "Category", a.Cat)
		for _, r in ipairs(a.Info or {}) do
			add(r.Icon or "•", r.Label or "", r.Value or "")
		end

		if a.Description and a.Description ~= "" then
			txt("TextLabel", {
				Text = tostring(a.Description), TextSize = 12, TextColor3 = C.txt, TextWrapped = true, LineHeight = 1.3,
				TextYAlignment = Enum.TextYAlignment.Top, Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order,
			}, content)
			order = order + 1
		end

		if type(a.Tags) == "table" and #a.Tags > 0 then
			local wrap = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, content)
			order = order + 1
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, wrap)
			for i, t in ipairs(a.Tags) do
				local chip = txt("TextLabel", {
					Text = tostring(t), Font = GM, TextSize = 10, TextColor3 = ACCENTS[1], BackgroundTransparency = 0.85,
					BackgroundColor3 = ACCENTS[1], TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i,
				}, wrap)
				pad(chip, 8, 8, 0, 0)
				corner(chip, 10)
			end
		end
		new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 12), LayoutOrder = order }, content)
	end,
}

-- Preview: плавное 3D (камера крутится вокруг модели, инерция при перетаскивании, зум колесом/щипком)
PAGES.preview = {
	id = "preview", name = "Preview", icon = "box",
	build = function(parent, a, pv)
		local cleanups = {}
		local animations = discoverAnimations(a)
		-- Use one full-width rounded preview surface instead of nested inset frames.
		local topOffset = 0
		local box = new("Frame", {
			BackgroundColor3 = C.badge, BorderSizePixel = 0, Position = UDim2.fromOffset(0, topOffset),
			Size = U2(1, 0, 1, ( #animations > 0 and -108 or 0) - topOffset),
			ClipsDescendants = true,
		}, parent)
		corner(box, 12)
		stroke(box, C.border, 1)
		-- Expand the preview over the complete detail drawer; the same control exits fullscreen.
		local fullButton = txt("TextButton", {
			Name = "PreviewFullscreen", Text = "", BackgroundColor3 = C.btnBg,
			BackgroundTransparency = 0.22, AnchorPoint = V2(1, 0),
			Position = U2(1, -8, 0, 8), Size = UDim2.fromOffset(34, 34), ZIndex = 20,
		}, box)
		corner(fullButton, 8)
		stroke(fullButton, C.border, 1)
		local expandIcon = mkIcon(fullButton, "maximize-2", 11, C.txt)
		expandIcon.AnchorPoint = V2(0.5, 0.5)
		expandIcon.Position = U2(0.5, 0, 0.5, 0)
		expandIcon.ZIndex = 21
		local collapseIcon = mkIcon(fullButton, "minimize-2", 11, C.txt)
		collapseIcon.AnchorPoint = V2(0.5, 0.5)
		collapseIcon.Position = U2(0.5, 0, 0.5, 0)
		collapseIcon.ZIndex = 21
		local function syncFullscreenIcon()
			local active = pv._previewFullscreen == true
			expandIcon.Visible = not active
			collapseIcon.Visible = active
		end
		syncFullscreenIcon()
		fullButton.Activated:Connect(function()
			pv:_setPreviewFullscreen(not pv._previewFullscreen)
			syncFullscreenIcon()
		end)

		-- Keep a slim visible border around the preview instead of letting the 3D surface touch the frame edge.
		local inset = 6
		local inner = new("Frame", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(inset, inset),
			Size = U2(1, -inset * 2, 1, -inset * 2), ClipsDescendants = true,
		}, box)
		corner(inner, 9)

		local variants = a._variants or {}
		if #variants > 1 then
			local pager = new("Frame", {
				Name = "VariantPager", BackgroundColor3 = C.panel, BackgroundTransparency = 0.08,
				AnchorPoint = V2(1, 1), Position = U2(1, -8, 1, -8),
				Size = UDim2.fromOffset(132, 34), ZIndex = 25,
			}, box)
			corner(pager, 9)
			stroke(pager, C.border, 1)
			local function makePageButton(name, symbol, x, direction)
				local canMove = (a._variantIndex or 1) + direction >= 1 and (a._variantIndex or 1) + direction <= #variants
				local button = txt("TextButton", {
					Name = name, Text = symbol, Font = GB, TextSize = 18,
					TextColor3 = canMove and C.txt or C.dim,
					BackgroundColor3 = C.btnBg, BackgroundTransparency = canMove and 0.25 or 0.62,
					Position = UDim2.fromOffset(x, 3), Size = UDim2.fromOffset(28, 28), ZIndex = 26,
				}, pager)
				corner(button, 7)
				button.Activated:Connect(function()
					local nextIndex = (a._variantIndex or 1) + direction
					if nextIndex >= 1 and nextIndex <= #variants then
						a:SetVariant(nextIndex)
					end
				end)
				return button
			end
			makePageButton("PreviousVariant", "‹", 3, -1)
			local counter = txt("TextLabel", {
				Name = "VariantCounter", Text = tostring(a._variantIndex or 1) .. "/" .. tostring(#variants),
				Font = GM, TextSize = 12, TextColor3 = C.txt,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(34, 0), Size = UDim2.fromOffset(64, 34), ZIndex = 26,
			}, pager)
			makePageButton("NextVariant", "›", 101, 1)
		end

		local h = makeThumb(inner, a)
		if h then h.manualOnly = true end
		if #animations > 0 then
		local player = new("Frame", {
			Name = "AnimationTimelinePlayer", BackgroundColor3 = C.panel, BorderSizePixel = 0,
			Position = U2(0, 0, 1, -100), Size = U2(1, 0, 0, 92), ClipsDescendants = false,
		}, parent)
		corner(player, 10)
		stroke(player, C.border, 1)

		local selector = txt("TextButton", {
			Name = "AnimationSelector", Text = animations[1].Name,
			Font = GB, TextSize = 11, TextColor3 = C.txt,
			BackgroundColor3 = C.btnBg, BackgroundTransparency = 0.22,
			Position = U2(0, 10, 0, 5), Size = U2(0.58, -18, 0, 23),
			TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
		}, player)
		corner(selector, 7)
		stroke(selector, C.border, 1)
		pad(selector, 8, 22, 0, 0)
		local selectorArrow = mkIcon(selector, "chevron-down", 12, C.dim)
		selectorArrow.AnchorPoint = V2(1, 0.5)
		selectorArrow.Position = U2(1, -4, 0.5, 0)
		selectorArrow.Active = false

		local timeLabel = txt("TextLabel", {
			Name = "TimelineTime", Text = "0.00s / 0.00s",
			Font = Enum.Font.Code, TextSize = 9, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = U2(0.58, 0, 0, 5), Size = U2(0.42, -10, 0, 22),
		}, player)

		local timeline = new("Frame", {
			Name = "TimelineTrack", BackgroundColor3 = C.slTrack, BorderSizePixel = 0,
			Position = U2(0, 12, 0, 35), Size = U2(1, -24, 0, 4),
		}, player)
		corner(timeline, 3)
		local timelineFill = new("Frame", {
			Name = "TimelineFill", BackgroundColor3 = ACCENTS[1], BorderSizePixel = 0,
			Size = U2(0, 0, 1, 0),
		}, timeline)
		corner(timelineFill, 3)
		local timelineKnob = new("Frame", {
			Name = "TimelineKnob", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			AnchorPoint = V2(0.5, 0.5), Position = U2(0, 0, 0.5, 0), Size = UDim2.fromOffset(10, 10),
		}, timeline)
		corner(timelineKnob, 6)
		local timelineHit = txt("TextButton", {
			Name = "TimelineInput", Text = "", Position = U2(0, 0, 0.5, -13),
			Size = U2(1, 0, 0, 26), ZIndex = 4,
		}, timeline)

		local controls = new("Frame", {
			BackgroundTransparency = 1, Position = U2(0, 10, 0, 47), Size = U2(1, -20, 0, 34),
		}, player)
		local function controlButton(name, iconName, x, width)
			local button = txt("TextButton", {
				Name = name, Text = "", Font = GB, TextSize = 11, TextColor3 = C.txt,
				BackgroundColor3 = C.btnBg, BackgroundTransparency = 0.08,
				Position = U2(0, x, 0, 2), Size = UDim2.fromOffset(width, 28),
			}, controls)
			corner(button, 7)
			stroke(button, C.border, 1)
			if iconName then
				local icon = mkIcon(button, iconName, 13, C.txt)
				icon.AnchorPoint = V2(0.5, 0.5)
				icon.Position = U2(0.5, 0, 0.5, 0)
			end
			return button
		end
		local playButton = controlButton("PlayPause", "play", 0, 30)
		local stopButton = controlButton("Stop", "square", 36, 28)
		local backButton = controlButton("SeekBack", "rewind", 70, 32)
		local forwardButton = controlButton("SeekForward", "fast-forward", 108, 32)
		local speedButton = controlButton("PlaybackSpeed", nil, 146, 40)
		speedButton.Font = Enum.Font.Code
		speedButton.TextSize = 11
		speedButton.Text = "1.0x"
		local playIcon = mkIcon(playButton, "play", 13, C.txt)
		playIcon.AnchorPoint = V2(0.5, 0.5)
		playIcon.Position = U2(0.5, 0, 0.5, 0)
		local pauseIcon = mkIcon(playButton, "pause", 13, C.txt)
		pauseIcon.AnchorPoint = V2(0.5, 0.5)
		pauseIcon.Position = U2(0.5, 0, 0.5, 0)
		pauseIcon.Visible = false

		local menu = new("ScrollingFrame", {
			Name = "AnimationList", BackgroundColor3 = C.panel, BorderSizePixel = 0,
			AnchorPoint = V2(0, 1), Position = U2(0, 8, 1, -104),
			Size = U2(0.58, -18, 0, 162), Visible = false, ZIndex = 50,
			ClipsDescendants = true, CanvasSize = U2(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3, ScrollBarImageColor3 = C.dim,
		}, parent)
		corner(menu, 8)
		stroke(menu, C.border, 1)
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, menu)

		local currentTrack, currentAnimation, currentIndex
		local currentLength, playbackSpeed = 0, 1
		local isPlaying, isLoading, disposed = false, false, false
		local function formatTime(value)
			value = math.max(tonumber(value) or 0, 0)
			if value < 60 then return string.format("%.2fs", value) end
			return string.format("%02d:%05.2f", math.floor(value / 60), value % 60)
		end
		local function updateTimeline()
			local position = 0
			if currentTrack then
				pcall(function() position = currentTrack.TimePosition end)
			end
			local length = currentLength
			local alpha = length > 0 and math.clamp(position / length, 0, 1) or 0
			timelineFill.Size = U2(alpha, 0, 1, 0)
			timelineKnob.Position = U2(alpha, 0, 0.5, 0)
			timeLabel.Text = formatTime(position) .. " / " .. formatTime(length)
			playIcon.Visible = not isPlaying
			pauseIcon.Visible = isPlaying
		end
		local function stopCurrent()
			if currentTrack then
				pcall(function() currentTrack:Stop(0.08) end)
				pcall(function() currentTrack:Destroy() end)
				currentTrack = nil
			end
			currentAnimation = nil
			currentLength = 0
			isPlaying = false
			isLoading = false
			if h then h.animationActive = false end
			updateTimeline()
		end
		local function setPosition(value)
			if not currentTrack or currentLength <= 0 then return end
			local target = math.clamp(value, 0, currentLength)
			if not currentTrack.IsPlaying then
				pcall(function() currentTrack:Play(0) end)
				pcall(function() currentTrack:AdjustSpeed(0) end)
			end
			pcall(function() currentTrack.TimePosition = target end)
			updateTimeline()
		end
		local function setPlaying(enabled)
			if not currentTrack then return end
			if enabled then
				if currentLength > 0 and currentTrack.TimePosition >= currentLength - 0.03 then
					pcall(function() currentTrack.TimePosition = 0 end)
				end
				if not currentTrack.IsPlaying then
					pcall(function() currentTrack:Play(0.08) end)
				end
				pcall(function() currentTrack:AdjustSpeed(playbackSpeed) end)
				isPlaying = true
				if h then h.animationActive = true end
			else
				pcall(function() currentTrack:AdjustSpeed(0) end)
				isPlaying = false
				if h then h.animationActive = currentTrack ~= nil end
			end
			updateTimeline()
		end
		local function loadAnimation(index)
			if disposed or #animations == 0 then return end
			index = math.clamp(index, 1, #animations)
			local entry = animations[index]
			stopCurrent()
			currentIndex = index
			selector.Text = entry.Name
			if not entry.AnimationId or entry.AnimationId == "" then
				timeLabel.Text = "Animation ID unavailable"
				return
			end
			local model = h and h.model
			if not model then
				timeLabel.Text = "Preview model unavailable"
				return
			end
			local controller = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
			if not controller then
				controller = Instance.new("AnimationController")
				controller.Name = "PreviewAnimationController"
				controller.Parent = model
			end
			local animator = controller:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = controller
			end
			local animation = Instance.new("Animation")
			animation.Name = entry.Name
			animation.AnimationId = entry.AnimationId
			local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
			if not ok or not track then
				animation:Destroy()
				timeLabel.Text = "Could not load animation"
				return
			end
			currentTrack = track
			currentAnimation = animation
			if h then h.animationActive = true end
			isLoading = true
			timeLabel.Text = "Loading animation..."
			pcall(function()
				track.Looped = false
				track:Play(0)
				track:AdjustSpeed(0)
			end)
			task.spawn(function()
				local started = os.clock()
				while not disposed and currentTrack == track and os.clock() - started < 8 do
					local length = 0
					pcall(function() length = track.Length end)
					if length > 0 then
						currentLength = length
						pcall(function() track.TimePosition = 0 end)
						isLoading = false
						isPlaying = false
						if h then h.animationActive = true end
						updateTimeline()
						return
					end
					task.wait(0.08)
				end
				if not disposed and currentTrack == track then
					isLoading = false
					timeLabel.Text = "Length unavailable"
				end
			end)
			updateTimeline()
		end

		local menuButtons = {}
		local function rebuildMenu()
			for _, button in ipairs(menuButtons) do button:Destroy() end
			menuButtons = {}
			for i, entry in ipairs(animations) do
				local button = txt("TextButton", {
					Text = entry.Name, Font = GM, TextSize = 11, TextColor3 = C.txt,
					BackgroundTransparency = 1, Size = U2(1, -8, 0, 25),
					Position = U2(0, 4, 0, 0), LayoutOrder = i, ZIndex = 51,
					TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				}, menu)
				pad(button, 8, 6, 0, 0)
				button.Activated:Connect(function()
					menu.Visible = false
					loadAnimation(i)
				end)
				menuButtons[#menuButtons + 1] = button
			end
			menu.CanvasSize = U2(0, 0, 0, #animations * 27 + 6)
			menu.Size = U2(0.58, -18, 0, 162)
		end
		rebuildMenu()
		selector.Activated:Connect(function()
			if #animations > 0 then menu.Visible = not menu.Visible end
		end)

		playButton.Activated:Connect(function()
			if not currentTrack and #animations > 0 then
				loadAnimation(currentIndex or 1)
				return
			end
			if isLoading then return end
			setPlaying(not isPlaying)
		end)
		stopButton.Activated:Connect(function()
			if currentTrack then
				pcall(function() currentTrack:Stop(0.08) end)
				pcall(function() currentTrack.TimePosition = 0 end)
				isPlaying = false
				if h then h.animationActive = false end
				updateTimeline()
			end
		end)
		backButton.Activated:Connect(function()
			if currentTrack then setPosition((currentTrack.TimePosition or 0) - 1) end
		end)
		forwardButton.Activated:Connect(function()
			if currentTrack then setPosition((currentTrack.TimePosition or 0) + 1) end
		end)
		local speeds = { 0.25, 0.5, 1, 1.5, 2 }
		speedButton.Activated:Connect(function()
			local nextIndex = 1
			for i, speed in ipairs(speeds) do
				if speed == playbackSpeed then nextIndex = i % #speeds + 1 break end
			end
			playbackSpeed = speeds[nextIndex]
			speedButton.Text = string.format("%.2gx", playbackSpeed)
			if isPlaying and currentTrack then
				pcall(function() currentTrack:AdjustSpeed(playbackSpeed) end)
			end
		end)
		local function scrub(input)
			if currentLength <= 0 then return end
			local position, size = timeline.AbsolutePosition, timeline.AbsoluteSize
			local alpha = math.clamp((input.Position.X - position.X) / math.max(size.X, 1), 0, 1)
			setPosition(alpha * currentLength)
		end
		timelineHit.InputBegan:Connect(function(input)
			if isPtr(input) then
				scrub(input)
				dragLocked(timelineHit, scrub)
			end
		end)

		local updateConnection = RunService.RenderStepped:Connect(function()
			if disposed or not pv._root or not pv._root.Visible or not pv._drawerOpen then return end
			if currentTrack then
				if isPlaying and not currentTrack.IsPlaying then
					isPlaying = false
					if h then h.animationActive = false end
				end
				updateTimeline()
			end
		end)
		cleanups[#cleanups + 1] = function()
			disposed = true
			updateConnection:Disconnect()
			stopCurrent()
			if menu and menu.Parent then menu:Destroy() end
		end
		loadAnimation(1)
		end

		if h then
			local st = { dragging = false, resumeAt = 0, pinching = false }
			pv._viewers[h] = st
			cleanups[#cleanups + 1] = function()
				pv._viewers[h] = nil
			end
			local hit = txt("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5 }, box)
			local function insideHit(pos)
				local p, s = hit.AbsolutePosition, hit.AbsoluteSize
				local inPreview = pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
				if not inPreview then return false end
				local bp, bs = fullButton.AbsolutePosition, fullButton.AbsoluteSize
				local onFullscreenButton = pos.X >= bp.X and pos.X <= bp.X + bs.X and pos.Y >= bp.Y and pos.Y <= bp.Y + bs.Y
				return not onFullscreenButton
			end

			-- Mouse: drag to rotate / zoom vertically, wheel to zoom.
			hit.InputBegan:Connect(function(i)
				if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				st.dragging = true
				h.vel = 0
				local lastX, lastY, lastT = i.Position.X, i.Position.Y, os.clock()
				beginDrag(function(m)
					local now = os.clock()
					local dx, dy = m.Position.X - lastX, m.Position.Y - lastY
					local dt = math.max(now - lastT, 1 / 240)
					local rad = dx * 0.011
					h.drag(rad)
					h.vel = math.clamp(h.vel * 0.5 + (rad / dt) * 0.5, -14, 14)
					lastX, lastY, lastT = m.Position.X, m.Position.Y, now
				end, function()
					st.dragging = false
					st.resumeAt = os.clock() + 1.2
					if os.clock() - lastT > 0.08 then h.vel = 0 end
				end)
			end)
			hit.InputChanged:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseWheel then
					h.zoomBy(1 - i.Position.Z * 0.1)
				end
			end)

			-- Touch: track each finger explicitly. TouchPinch can be swallowed by GUI
			-- input routing on some mobile clients, so calculate pinch distance ourselves.
			local touches = {}
			local touchAnchor, pinchDistance, pinchZoom
			local function touchList()
				local list = {}
				for input, pos in pairs(touches) do
					list[#list + 1] = { input = input, pos = pos }
				end
				return list
			end
			local function distance(a, b)
				return (a - b).Magnitude
			end
			local function resetTouchAnchor()
				local list = touchList()
				if #list >= 2 then
					st.pinching = true
					st.dragging = false
					pinchDistance = math.max(distance(list[1].pos, list[2].pos), 1)
					pinchZoom = h.tZoom
					h.vel = 0
				elseif #list == 1 then
					st.pinching = false
					st.dragging = true
					touchAnchor = list[1].pos
					h.vel = 0
				else
					st.pinching = false
					st.dragging = false
					touchAnchor = nil
					pinchDistance = nil
				end
			end
			local began = UIS.TouchStarted:Connect(function(i)
				if not insideHit(i.Position) then return end
				touches[i] = i.Position
				resetTouchAnchor()
			end)
			local moved = UIS.TouchMoved:Connect(function(i)
				if not touches[i] then return end
				local previous = touches[i]
				touches[i] = i.Position
				local list = touchList()
				if #list >= 2 then
					local currentDistance = math.max(distance(list[1].pos, list[2].pos), 1)
					if pinchDistance then
						h.tZoom = math.clamp(pinchZoom * pinchDistance / currentDistance, 0.45, 2.4)
					end
					st.pinching = true
					st.dragging = false
					h.vel = 0
				elseif #list == 1 then
					local dx = i.Position.X - previous.X
					local dy = i.Position.Y - previous.Y
					h.drag(dx * 0.011)
				end
			end)
			local ended = UIS.TouchEnded:Connect(function(i)
				if touches[i] then
					touches[i] = nil
					resetTouchAnchor()
					st.resumeAt = os.clock() + 0.25
				end
			end)
			cleanups[#cleanups + 1] = function()
				began:Disconnect()
				moved:Disconnect()
				ended:Disconnect()
			end
		end
		return function()
			pv._previewRefresh = nil
			for _, fn in ipairs(cleanups) do
				fn()
			end
		end
	end,
}

--------------------------------------------------------------------
-- конструктор и данные
--------------------------------------------------------------------
local function matchQuery(a, q)
	q = string.lower(tostring(q or "")):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
	if q == "" then
		return true
	end
	local values = {}
	local function add(value)
		if value == nil then return end
		local kind = type(value)
		if kind == "string" or kind == "number" then
			values[#values + 1] = tostring(value)
		end
	end
	for _, key in ipairs({
		"Name", "Type", "Creator", "Author", "Description", "Version",
		"Size", "Created", "Category", "SubType", "DisplayName",
		"Source", "Id", "AssetId",
	}) do
		add(a[key])
	end
	for _, key in ipairs({ "Tags", "Keywords" }) do
		local list = a[key]
		if type(list) == "table" then
			for _, value in pairs(list) do add(value) end
		else
			add(list)
		end
	end
	if type(a.Info) == "table" then
		for _, row in pairs(a.Info) do
			if type(row) == "table" then
				add(row.Label)
				add(row.Value)
			else
				add(row)
			end
		end
	end
	local hay = string.lower(table.concat(values, " "))
	for term in string.gmatch(q, "%S+") do
		if not string.find(hay, term, 1, true) then
			return false
		end
	end
	return true
end

function M.new(bridge, opts)
	B, C, ACCENTS = bridge, bridge.C, bridge.ACCENTS
	opts = opts or {}
	-- Preview uses the same shared icon provider as the rest of JustXLibrary.
	if B.loadIconPack and (not B.hasIconPack or not B.hasIconPack()) then
		pcall(B.loadIconPack)
	end
	local self = setmetatable({}, M)
	self._pv = self
	self.alive = true
	self.Title = opts.Title or "Preview"
	self.Icon = opts.Icon or "⬡"
	self._opts = opts
	self._tabs, self._side, self._assets, self._pages = {}, {}, {}, {}
	self._sources = {}
	self._cards = {}
	self._cons = {}
	self._closedCbs = {}
	self._scrollers, self._phs = {}, {}
	self._viewers = {}
	self._order = 0
	self._type, self._query = "All", ""
	self._sort = { Key = "Default", Descending = false }
	self._grouping = "None"
	self._groupFrames = {}
	self._groupLayouts = {}
	self._groupListLayout = nil
	attachControls(self)

	table.insert(B.unloadHooks, function()
		self:Destroy()
	end)
	table.insert(B.themeHooks, function()
		self:_repaintExtras()
	end)
	if opts.Key then
		B.keep(UIS.InputBegan:Connect(function(i, gp)
			if gp or B.isListening() then
				return
			end
			if i.KeyCode == opts.Key then
				self:Toggle()
			end
		end))
	end
	return self
end

function M:Tab(o)
	o = o or {}
	local T = {
		_pv = self, _isTab = true, Name = o.Name or ("Tab " .. tostring(#self._tabs + 1)),
		Icon = o.Icon or "◼", ShowAll = o.ShowAll == true, Filter = o.Filter, assets = {},
	}
	attachControls(T)
	function T:Asset(a)
		return self._pv:_addAsset(self, a)
	end
	function T:Assets(list)
		local out = {}
		for _, a in ipairs(list or {}) do
			out[#out + 1] = self._pv:_addAsset(self, a, true)
		end
		self._pv:_assetsChanged()
		return out
	end
	function T:Clear()
		for i = #self.assets, 1, -1 do
			self.assets[i]:Remove(true)
		end
		self._pv:_assetsChanged()
	end
	function T:Open()
		return self._pv:Open(self)
	end
	function T:Remove()
		self._pv:_removeTab(self)
	end
	self._tabs[#self._tabs + 1] = T
	self._side[#self._side + 1] = { kind = "tab", tab = T }
	if self._root then
		self:_renderSidebar()
		if not self._activeTab then
			self:_activate(T)
		end
	end
	return T
end

-- Источники данных: стабильные ключи, обновление без пересоздания Preview.
function M:Source(o)
	o = o or {}
	local tab = type(o.Tab) == "string" and self:GetTab(o.Tab) or o.Tab
	if not tab then
		tab = self:Tab({ Name = o.TabName or o.Name or "Source", Icon = o.Icon or "◼" })
	end
	assert(tab._isTab and tab._pv == self, "Preview:Source Tab must belong to this Preview")
	local discoveryOptions = type(o.Discover) == "table" and o.Discover or {}
	local source = {
		_pv = self, _tab = tab, _items = {}, _order = {},
		Name = o.Name or tab.Name, _alive = true, _connections = {},
		_map = o.Map, _key = o.Key, _getItems = o.GetItems,
		_discoveryOptions = discoveryOptions,
		_discoveryEnabled = o.Discover == true or (type(o.Discover) == "table" and discoveryOptions.Enabled ~= false),
		_discoveryInterval = math.clamp(tonumber(discoveryOptions.Interval) or 2, 0.5, 30),
		_discoveryRemoveMissing = discoveryOptions.RemoveMissing ~= false,
		_discoveryToken = 0,
		_liveMotionOptions = type(o.LiveMotion) == "table" and o.LiveMotion or {},
		_liveMotionDefault = o.LiveMotion == true or type(o.LiveMotion) == "table",
		_observeOptions = type(o.ObserveModels) == "table" and o.ObserveModels or {},
		_observeDefault = o.ObserveModels == true or type(o.ObserveModels) == "table",
	}
	local function resolveKey(item)
		if type(source._key) == "function" then
			local ok, key = pcall(source._key, item, source)
			if ok and key ~= nil then return key end
			return nil
		end
		return item
	end

	local defaultObserveProperties = {
		BasePart = { "Color", "Size", "Material", "Transparency", "Reflectance", "Shape" },
		Decal = { "Texture", "Color3", "Transparency" },
		Texture = { "Texture", "Color3", "Transparency", "StudsPerTileU", "StudsPerTileV" },
		SpecialMesh = { "MeshId", "TextureId", "MeshType", "Scale", "Offset", "VertexColor" },
		SurfaceAppearance = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" },
	}
	local function disconnectObserver(entry)
		if not entry then return end
		entry._observeToken = (entry._observeToken or 0) + 1
		entry._observePending = false
		for _, connection in ipairs(entry._observeConnections or {}) do
			pcall(function() connection:Disconnect() end)
		end
		entry._observeConnections = {}
	end
	local function observeEntry(key)
		local entry = source._items[key]
		if not entry then return end
		disconnectObserver(entry)
		if not entry._observeEnabled or not entry.asset or not entry.asset._alive then return end
		local token = entry._observeToken
		local connections, watched = entry._observeConnections, {}
		local delayTime = tonumber(source._observeOptions.Debounce) or 0.18
		delayTime = math.clamp(delayTime, 0.05, 2)
		local function scheduleRefresh()
			if entry._observePending then return end
			entry._observePending = true
			task.delay(delayTime, function()
					if entry._observeToken ~= token then return end
					entry._observePending = false
					if not source._alive or source._items[key] ~= entry
						or not entry.asset or not entry.asset._alive then
						return
					end
					source:Refresh(key)
				end)
		end
		local function addConnection(signal, callback)
			local ok, connection = pcall(function() return signal:Connect(callback) end)
			if ok and connection then connections[#connections + 1] = connection end
		end
		local properties = source._observeOptions.Properties
		local function watchInstance(instance)
			if not instance or watched[instance] then return end
			watched[instance] = true
			local classProperties
			if type(properties) == "table" then
				classProperties = properties
			else
				for className, list in pairs(defaultObserveProperties) do
					if instance:IsA(className) then
						classProperties = list
						break
					end
				end
			end
			for _, property in ipairs(classProperties or {}) do
				pcall(function()
					addConnection(instance:GetPropertyChangedSignal(property), scheduleRefresh)
				end)
			end
			if instance:IsA("Model") then
				for _, property in ipairs({ "WorldPivot", "PrimaryPart" }) do
					pcall(function()
						addConnection(instance:GetPropertyChangedSignal(property), scheduleRefresh)
					end)
				end
			end
		end
		local roots, seenRoots = {}, {}
		local function addRoot(value)
			if typeof(value) ~= "Instance" then return end
			if not (value:IsA("Model") or value:IsA("BasePart")) or seenRoots[value] then return end
			seenRoots[value] = true
			roots[#roots + 1] = value
		end
		addRoot(entry.asset.Model)
		if entry.asset._baseVariantData then
			addRoot(entry.asset._baseVariantData.Model)
		end
		for _, variant in ipairs(entry.asset._variants or {}) do
			addRoot(variant.Model)
		end
		for _, root in ipairs(roots) do
			watchInstance(root)
			if root:IsA("Model") then
				for _, descendant in ipairs(root:GetDescendants()) do
					watchInstance(descendant)
				end
				addConnection(root.DescendantAdded, function(descendant)
					watchInstance(descendant)
					scheduleRefresh()
				end)
				addConnection(root.DescendantRemoving, scheduleRefresh)
			end
		end
		entry._observeConnections = connections
	end

	function source:Get(key)
		local entry = self._items[key]
		return entry and entry.asset or nil
	end
	function source:SetAutoObserve(key, enabled)
		local entry = self._items[key]
		if not entry then return false end
		entry._observeEnabled = enabled == true
		observeEntry(key)
		return true
	end
	function source:SetLiveMotion(key, enabled)
		local entry = self._items[key]
		if not entry or not entry.asset or not entry.asset._alive then return false end
		entry._liveMotionEnabled = enabled == true
		entry.asset._liveMotionEnabled = entry._liveMotionEnabled
		entry.asset._liveMotionRate = entry._liveMotionRate
		for h in pairs(self._pv._viewers or {}) do
			if h.asset == entry.asset then
				h.motionEnabled = entry._liveMotionEnabled
				h.motionElapsed = 0
			end
		end
		return true
	end
	function source:Add(key, data)
		if not self._alive or key == nil then return nil end
		local existing = self._items[key]
		local payload = data
		if payload == nil then payload = key end
		if type(self._map) == "function" then
			local ok, mapped = pcall(self._map, payload, key, self)
			if not ok then
				warn("[PreviewUI] source map failed: " .. tostring(mapped))
				return nil
			end
			payload = mapped
		end
		if type(payload) ~= "table" then
			payload = { Name = tostring(payload) }
		end
		if existing and existing.asset and existing.asset._alive then
			existing.item = data == nil and key or data
			existing.asset._liveMotionEnabled = existing._liveMotionEnabled
			existing.asset._liveMotionRate = existing._liveMotionRate
			existing.asset:Update(payload)
			observeEntry(key)
			return existing.asset
		end
		local item = data == nil and key or data
		local asset = self._pv:_addAsset(self._tab, payload, true)
		asset._source, asset._sourceKey = self, key
		local motionRate = math.clamp(tonumber(self._liveMotionOptions.Rate) or 30, 10, 60)
		asset._liveMotionEnabled = self._liveMotionDefault
		asset._liveMotionRate = motionRate
		self._items[key] = {
			asset = asset, item = item,
			_observeEnabled = self._observeDefault,
			_liveMotionEnabled = self._liveMotionDefault,
			_liveMotionRate = motionRate,
			_observeConnections = {}, _observeToken = 0,
		}
		self._order[#self._order + 1] = key
		observeEntry(key)
		self._pv:_assetsChanged()
		return asset
	end
	function source:Update(key, patch)
		local entry = self._items[key]
		if not entry or not entry.asset or not entry.asset._alive then return nil end
		entry.asset:Update(patch or {})
		observeEntry(key)
		return entry.asset
	end
	function source:Refresh(key)
		local entry = self._items[key]
		if not entry or not entry.asset or not entry.asset._alive then return nil end
		local payload = entry.item
		if type(self._map) == "function" then
			local ok, mapped = pcall(self._map, payload, key, self)
			if not ok then
				warn("[PreviewUI] source map failed: " .. tostring(mapped))
				return nil
			end
			payload = mapped
		end
		if type(payload) ~= "table" then
			payload = { Name = tostring(payload) }
		end
		entry.asset:Update(payload)
		observeEntry(key)
		return entry.asset
	end
	function source:Sync()
		if not self._alive or type(self._getItems) ~= "function" then
			return false
		end
		local ok, items = pcall(self._getItems, self)
		if not ok then
			warn("[PreviewUI] source GetItems failed: " .. tostring(items))
			return false
		end
		if type(items) ~= "table" then
			warn("[PreviewUI] source GetItems must return a table")
			return false
		end
		local present, count = {}, 0
		for _, item in pairs(items) do
			local key = resolveKey(item)
			if key ~= nil then
				present[key] = true
				count = count + 1
				source:Add(key, item)
			end
		end
		if self._discoveryRemoveMissing then
			for i = #self._order, 1, -1 do
				local key = self._order[i]
				if not present[key] then
					source:Remove(key)
				end
			end
		end
		return true, count
	end
	function source:SetDiscovery(enabled)
		if not self._alive then return false end
		if enabled == true then
			if type(self._getItems) ~= "function" then return false end
			if self._discoveryEnabled then return true end
			self._discoveryEnabled = true
			self._discoveryToken = self._discoveryToken + 1
			local token = self._discoveryToken
			task.spawn(function()
				while self._alive and self._discoveryEnabled and self._discoveryToken == token do
					task.wait(self._discoveryInterval)
					if self._alive and self._discoveryEnabled and self._discoveryToken == token then
						self:Sync()
					end
				end
			end)
			return true
		end
		self._discoveryEnabled = false
		self._discoveryToken = self._discoveryToken + 1
		return true
	end
	function source:IsDiscoveryEnabled()
		return self._alive and self._discoveryEnabled
	end
	function source:Remove(key)
		local entry = self._items[key]
		if not entry then return false end
		disconnectObserver(entry)
		self._items[key] = nil
		for i, value in ipairs(self._order) do
			if value == key then table.remove(self._order, i) break end
		end
		if entry.asset and entry.asset._alive then entry.asset:Remove(true) end
		self._pv:_assetsChanged()
		return true
	end
	function source:Clear()
		for i = #self._order, 1, -1 do self:Remove(self._order[i]) end
		return self
	end
	function source:Destroy()
		if not self._alive then return end
		self:SetDiscovery(false)
		self:Clear()
		self._alive = false
		for _, connection in ipairs(self._connections) do
			pcall(function() connection:Disconnect() end)
		end
		self._connections = {}
		for i, value in ipairs(self._pv._sources) do
			if value == self then table.remove(self._pv._sources, i) break end
		end
	end
	local function connect(signal, callback)
		if signal and type(signal.Connect) == "function" then
			local ok, connection = pcall(function() return signal:Connect(callback) end)
			if ok and connection then source._connections[#source._connections + 1] = connection end
		end
	end
	connect(o.Added, function(item)
		local key = resolveKey(item)
		if key ~= nil then source:Add(key, item) end
	end)
	connect(o.Changed, function(item)
		local key = resolveKey(item)
		if key ~= nil then source:Add(key, item) end
	end)
	connect(o.Removed, function(item)
		local key = resolveKey(item)
		if key ~= nil then source:Remove(key) end
	end)
	self._sources[#self._sources + 1] = source
	if type(o.GetItems) == "function" then
		source:Sync()
	end
	if source._discoveryEnabled then
		source._discoveryEnabled = false
		source:SetDiscovery(true)
	end
	return source
end

function M:Header(text)
	self._side[#self._side + 1] = { kind = "header", text = tostring(text or "") }
	if self._root then
		self:_renderSidebar()
	end
	return self
end

-- своя страница панели: Preview:Page({ Name, Icon, Visible = function(asset), Build = function(parent, asset, pv) return cleanup end })
function M:Page(o)
	o = o or {}
	local p = {
		id = "custom" .. tostring(#self._pages + 1), name = o.Name or "Page", icon = o.Icon or "◆",
		build = o.Build, visible = o.Visible, custom = true,
	}
	self._pages[#self._pages + 1] = p
	if self._root and self._selected then
		self:_refreshDrawer(false)
	end
	return p
end

function M:GetTab(name)
	for _, t in ipairs(self._tabs) do
		if t.Name == name then
			return t
		end
	end
	return nil
end

function M:GetTabs()
	local out = {}
	for i, t in ipairs(self._tabs) do
		out[i] = t
	end
	return out
end

function M:GetAsset(name)
	for _, a in ipairs(self._assets) do
		if a.Name == name then
			return a
		end
	end
	return nil
end

function M:_removeTab(T)
	for i = #self._sources, 1, -1 do
		if self._sources[i]._tab == T then self._sources[i]:Destroy() end
	end
	for i = #T.assets, 1, -1 do
		T.assets[i]:Remove(true)
	end
	for i, t in ipairs(self._tabs) do
		if t == T then
			table.remove(self._tabs, i)
			break
		end
	end
	for i, e in ipairs(self._side) do
		if e.tab == T then
			table.remove(self._side, i)
			break
		end
	end
	if self._activeTab == T then
		self._activeTab = nil
	end
	if self._root then
		self:_renderSidebar()
		self:_assetsChanged()
		if not self._activeTab and self._tabs[1] then
			self:_activate(self._tabs[1])
		end
	end
end

function M:_addAsset(tab, a, quiet)
	a = a or {}
	local asset = {}
	for k, v in pairs(a) do
		asset[k] = v
	end
	asset.Name = asset.Name or "Asset"
	asset._baseVariantData = {}
	asset._variants = type(asset.Variants) == "table" and asset.Variants or {}
	asset._variantIndex = 1
	for _, key in ipairs(VARIANT_FIELDS) do
		asset._baseVariantData[key] = asset[key]
	end
	asset.Variants = nil
	if asset._variants[1] then
		local first = asset._variants[1]
		for _, key in ipairs(VARIANT_FIELDS) do
			if first[key] ~= nil then
				asset[key] = first[key]
			end
		end
		asset._variantName = first.Name or "Variant 1"
	end
	asset.tab = tab
	asset._pv = self
	asset._isAsset = true
	asset._alive = true
	asset._actions = {}
	self._order = self._order + 1
	asset._order = self._order
	attachControls(asset)
	function asset:Select()
		self._pv:_goto(self)
	end
	local function applyVariant(self, index)
		local variant = self._variants[index]
		if not variant then
			for _, key in ipairs(VARIANT_FIELDS) do
				self[key] = self._baseVariantData[key]
			end
			self._variantIndex = 1
			self._variantName = nil
			return false
		end
		for _, key in ipairs(VARIANT_FIELDS) do
			local value = variant[key]
			if value == nil then
				value = self._baseVariantData[key]
			end
			self[key] = value
		end
		self._variantIndex = index
		self._variantName = variant.Name or ("Variant " .. tostring(index))
		return true
	end
	function asset:Update(t)
		local variants
		local hasVariants = false
		for k, v in pairs(t or {}) do
			if k == "Variants" then
				variants = v
				hasVariants = true
			else
				self[k] = v
				if self._baseVariantData[k] ~= nil or table.find(VARIANT_FIELDS, k) then
					self._baseVariantData[k] = v
				end
			end
		end
		if hasVariants then
			self:SetVariants(variants, true)
		end
		self._pv:_assetUpdated(self)
	end
	function asset:SetVariants(list, quiet)
		if type(list) ~= "table" then
			return false
		end
		local selectedName = self._variantName
		local nextVariants = {}
		for _, variant in ipairs(list) do
			if type(variant) == "table" then
				nextVariants[#nextVariants + 1] = variant
			end
		end
		self._variants = nextVariants
		local selectedIndex
		if selectedName then
			for i, variant in ipairs(nextVariants) do
				if variant.Name == selectedName then
					selectedIndex = i
					break
				end
			end
		end
		selectedIndex = selectedIndex or (#nextVariants > 0 and 1 or nil)
		applyVariant(self, selectedIndex)
		if not quiet then
			self._pv:_assetUpdated(self)
		end
		return true
	end
	function asset:SetVariant(target)
		local index
		if type(target) == "number" then
			index = math.floor(target)
		else
			for i, variant in ipairs(self._variants) do
				if variant.Name == target then
					index = i
					break
				end
			end
		end
		if not index or not self._variants[index] then
			return false
		end
		applyVariant(self, index)
		self._pv:_assetUpdated(self)
		return true
	end
	-- пункт меню "три точки" (до MAX_ACTIONS штук на ассет)
	function asset:Action(o2)
		o2 = o2 or {}
		if #self._actions >= MAX_ACTIONS then
			warn("[PreviewUI] '" .. tostring(self.Name) .. "': максимум " .. MAX_ACTIONS .. " действий")
			return nil
		end
		local act = { Name = o2.Name or "Action", Icon = o2.Icon, Callback = o2.Callback }
		self._actions[#self._actions + 1] = act
		function act:Remove()
			for i, x in ipairs(asset._actions) do
				if x == self then
					table.remove(asset._actions, i)
					break
				end
			end
		end
		return act
	end
	function asset:Remove(quietRemove)
		if not self._alive then
			return
		end
		self._alive = false
		for i, x in ipairs(self.tab.assets) do
			if x == self then
				table.remove(self.tab.assets, i)
				break
			end
		end
		for i, x in ipairs(self._pv._assets) do
			if x == self then
				table.remove(self._pv._assets, i)
				break
			end
		end
		if self._pv._selected == self then
			self._pv._selected = nil
		end
		if self._source and self._source._items[self._sourceKey] then
			self._source._items[self._sourceKey] = nil
			for i, key in ipairs(self._source._order) do
				if key == self._sourceKey then table.remove(self._source._order, i) break end
			end
		end
		if not quietRemove then
			self._pv:_assetsChanged()
		end
	end
	for _, act in ipairs(asset.Actions or {}) do
		asset:Action(act)
	end
	tab.assets[#tab.assets + 1] = asset
	self._assets[#self._assets + 1] = asset
	if not quiet then
		self:_assetsChanged()
	end
	return asset
end

function M:_assetsChanged()
	if not self._root then
		return
	end
	self:_syncCards()
	self:_applyFilter()
	if not self._selected and self._drawerOpen then
		self:_setDrawer(false)
	end
end

function M:_assetUpdated(asset)
	if not self._root then
		return
	end
	local c = self._cards[asset]
	if c then
		c.frame:Destroy()
		self._cards[asset] = nil
	end
	self:_syncCards()
	self:_applyFilter()
	if self._selected == asset and self._drawerOpen then
		self:_refreshDrawer(false)
	end
end

function M:_ctrlChanged()
	if self._root and self._selected and self._drawerOpen then
		self:_refreshDrawer(false)
	end
end

-- Сортировка карточек: Default, Name, Type, Creator, Author, Created, Size, Version, Category.
function M:SetSort(key, descending)
	local allowed = {
		Default = true, Name = true, Type = true, Creator = true, Author = true,
		Created = true, Size = true, Version = true, Category = true, Id = true, AssetId = true,
	}
	if type(key) == "table" then
		descending = key.Descending
		key = key.Key or key.By
	end
	key = key or "Default"
	if not allowed[key] then
		return false
	end
	self._sort = { Key = key, Descending = descending == true }
	self:_applyFilter()
	return true
end

function M:GetSort()
	local sort = self._sort or { Key = "Default", Descending = false }
	return sort.Key, sort.Descending
end

function M:SetTitle(t)
	self.Title = tostring(t)
	if self._titleL then
		self._titleL.Text = self.Title
	end
end

function M:OnClosed(fn)
	if type(fn) == "function" then
		self._closedCbs[#self._closedCbs + 1] = fn
	end
end

function M:IsOpen()
	return self._tab ~= nil
end

--------------------------------------------------------------------
-- вкладка в окне JustLib: создать / выбрать / удалить
--------------------------------------------------------------------
function M:Open(target)
	if not self.alive then
		return self
	end
	if not self._tab then
		if self:_build() == false then
			return self
		end
		safe(self._opts.OnOpen, self)
	end
	local win = B.getWin and B.getWin() or nil
	if win and win.IsOpen and not win:IsOpen() then
		win:Open()
	end
	if self._tab and self._tab.Select then
		self._tab:Select()
	end
	if target ~= nil then
		self:_goto(target)
	end
	return self
end

-- удаляет вкладку и всё, что в ней создано (то же делает крестик)
function M:Close()
	local t = self._tab
	if not t then
		return self
	end
	pcall(function() t:Remove() end)
	if self._tab then
		self:_teardown(false)
	end
	return self
end

function M:Toggle(target)
	if self._tab then
		return self:Close()
	end
	return self:Open(target)
end

function M:CloseDrawer()
	if self._root and self._drawerOpen then
		self._selected = nil
		self:_markSelected()
		self:_setDrawer(false)
	end
	return self
end

-- полная очистка: соединения, вьюпорты, меню, ссылки на элементы (GUI удаляет сама вкладка)
function M:_teardown(removeTab)
	local t = self._tab
	self._tab = nil
	self:_closeMenu()
	self:_cleanupPage()
	self:_clearLargePreview()
	for _, c in ipairs(self._cons) do
		pcall(function() c:Disconnect() end)
	end
	self._cons = {}
	for _, def in ipairs(self:_allControls()) do
		def._refresh = nil
		def._lbl = nil
	end
	if removeTab and t then
		pcall(function() t:Remove() end)
	end
	self._root, self._nav, self._card, self._drawer, self._titleL = nil, nil, nil, nil, nil
	self._navList, self._grid, self._gridLayout, self._d = nil, nil, nil, nil
	self._dTitle, self._dType, self._dTabs, self._dPages, self._pageRoot, self._indicator = nil, nil, nil, nil, nil, nil
	self._dLeft, self._dRight, self._dRightPage = nil, nil, nil
	self._dCollapse, self._dHeaderLine = nil, nil
	self._previewFullscreen = false
	self._cards, self._sideRefs, self._tabRefs, self._curPages = {}, {}, {}, {}
	self._scrollers, self._phs, self._viewers = {}, {}, {}
	self._activeTab, self._selected, self._drawerOpen, self._page = nil, nil, false, nil
	self._query, self._type = "", "All"
	for _, fn in ipairs(self._closedCbs) do
		safe(fn, self)
	end
	safe(self._opts.OnClose, self)
end

function M:_allControls()
	local out = {}
	for _, d in ipairs(self._controls) do
		out[#out + 1] = d
	end
	for _, t in ipairs(self._tabs) do
		for _, d in ipairs(t._controls) do
			out[#out + 1] = d
		end
	end
	for _, a in ipairs(self._assets) do
		for _, d in ipairs(a._controls) do
			out[#out + 1] = d
		end
	end
	return out
end

-- Unload JustLib вызывает именно это: уничтожает вкладку и стирает данные
function M:Destroy()
	if not self.alive then
		return
	end
	self.alive = false
	for i = #self._sources, 1, -1 do self._sources[i]:Destroy() end
	self:_teardown(true)
	for _, d in ipairs(self:_allControls()) do
		if d.o.Flag and B.registry[d.o.Flag] == d then
			B.registry[d.o.Flag] = nil
		end
	end
	self._tabs, self._side, self._assets, self._controls, self._pages = {}, {}, {}, {}, {}
	if B.onDestroyed then
		B.onDestroyed(self)
	end
end

--------------------------------------------------------------------
-- раскладка и настройки (страница "Preview UI" в Settings JustLib)
--------------------------------------------------------------------
function M:_applyPreviewFullscreen()
	if not self._dRight or not self._dLeft then
		return
	end
	local active = self._previewFullscreen == true
	self._dLeft.Visible = not active
	if self._dTitle then self._dTitle.Visible = not active end
	if self._dType then self._dType.Visible = not active end
	if self._dCollapse then self._dCollapse.Visible = not active end
	if self._dHeaderLine then self._dHeaderLine.Visible = not active end
	if active then
		self._dRight.Position = U2(0, 0, 0, 0)
		self._dRight.Size = U2(1, 0, 1, 0)
	else
		local leftW = math.clamp(math.floor(self._W * 0.39), 190, 330)
		self._dRight.Position = U2(0, leftW + 1, 0, 62)
		self._dRight.Size = U2(1, -leftW - 1, 1, -62)
	end
end

function M:_setPreviewFullscreen(enabled)
	self._previewFullscreen = enabled == true
	self:_applyPreviewFullscreen()
	return self._previewFullscreen
end

function M:_cacheSettings()
	self._auto = S("autorotate", true) == true
	self._speed = math.rad(tonumber(S("rotspeed", 40)) or 40)
	self._minCell = math.clamp(tonumber(S("card", 140)) or 140, 100, 240)
end

function M:_dims()
	local W, H = 624, 404
	if B.getContentSize then
		local ok, w, h = pcall(B.getContentSize)
		if ok and w and h then
			W, H = w, h
		end
	end
	return W, H
end

-- Позиции трёх колонок для закрытой / открытой панели.
-- Когда панель открыта и места мало, список слева уезжает за край: сетка остаётся достаточно широкой.
function M:_states(open)
	local W = self._W
	if open then
		return { navX = -(NAVW + GAP), cardX = -W, cardW = W, drawerX = 0 }
	end
	return { navX = 0, cardX = NAVW + GAP, cardW = W - (NAVW + GAP), drawerX = W }
end

function M:_relayout()
	if not self._root then
		return
	end
	local W, H = self:_dims()
	self._W, self._H = W, H
	self._DW = W
	local st = self:_states(self._drawerOpen == true)
	self._cardW = st.cardW
	self._nav.Size = U2(0, NAVW, 1, 0)
	self._card.Size = U2(0, st.cardW, 1, 0)
	self._drawer.Size = U2(1, 0, 1, 0)
	if self._dLeft then
		local leftW = math.clamp(math.floor(W * 0.39), 190, 330)
		self._dLeft.Size = U2(0, leftW, 1, -62)
		self._dRight.Position = U2(0, leftW + 1, 0, 62)
		self._dRight.Size = U2(1, -leftW - 1, 1, -62)
		self._dTabs.Size = U2(1, -20, 0, 42)
		self._dPages.Size = U2(1, 0, 1, -102)
		self:_applyPreviewFullscreen()
	end
	if not self._sliding then
		self._nav.Position = U2(0, st.navX, 0, 0)
		self._card.Position = U2(0, st.cardX, 0, 0)
		self._drawer.Position = U2(0, st.drawerX, 0, 0)
	end
	self:_fitGrid()
end

-- Сетка всегда заполняет всю ширину: число колонок и ширина карточек считаются от доступного места
function M:_fitGrid()
	local grid = self._grid
	if not grid or not self._cardW then
		return
	end
	local usable = self._cardW - 8 - 8 - 4 -- отступы сетки и полоса прокрутки
	local gap = 8
	local minCell = self._minCell or 140
	local cols = math.max(1, math.floor((usable + gap) / (minCell + gap)))
	local cw = math.floor((usable - gap * (cols - 1)) / cols)
	local th = math.clamp(math.floor(cw * 0.62), 60, 150)
	if self._cw == cw and self._th == th and self._cols == cols then
		return
	end
	self._cw, self._th, self._cols = cw, th, cols
	if self._gridLayout then
		self._gridLayout.CellSize = UDim2.fromOffset(cw, th + 44)
	end
	for _, layout in ipairs(self._groupLayouts or {}) do
		if layout and layout.Parent then
			layout.CellSize = UDim2.fromOffset(cw, th + 44)
		end
	end
	for _, c in pairs(self._cards) do
		self:_applyCardGeo(c)
	end
end

function M:_applyCardGeo(c)
	local th = self._th or 90
	c.thumb.Size = U2(1, 0, 0, th)
	c.label.Position = UDim2.fromOffset(0, th)
	c.label.Size = U2(1, 0, 1, -th)
	c.dots.Position = U2(1, -6, 0, th + 5)
end

function M:ApplySettings()
	self:_cacheSettings()
	if not self._root then
		return
	end
	self:_fitGrid()
	if self._previewRefresh then
		self._previewRefresh()
	end
end

-- то, что JustLib не перекрашивает сам (он меняет только цвета фона, текста и обводок)
function M:_repaintExtras()
	if not self._root then
		return
	end
	for _, sf in ipairs(self._scrollers) do
		if sf and sf.Parent then
			sf.ScrollBarImageColor3 = ACCENTS[1]
		end
	end
	for _, tb in ipairs(self._phs) do
		if tb and tb.Parent then
			tb.PlaceholderColor3 = C.dim
		end
	end
	self:_styleSidebar()
	self:_styleDrawerTabs(true)
	self:_markSelected(true)
end

--------------------------------------------------------------------
-- сборка вкладки
--------------------------------------------------------------------
function M:_build()
	local win = B.getWin and B.getWin() or nil
	if not win then
		B.notify({ Title = "Preview UI", Desc = "Create a JustLib window first: JL:Window({...})", Type = "Warn", Duration = 4 })
		return false
	end
	local tab = win:Tab({
		Name = self._opts.TabName or "Preview", Icon = self.Icon, Type = "Custom", Tooltip = self.Title,
		OnDeselect = function()
			if self._root then self._root.Visible = false end
		end,
		OnSelect = function()
			if self._root then self._root.Visible = true end
		end,
		OnClose = function()
			if self._tab then
				self:_teardown(false)
			end
		end,
	})
	if not tab then
		return false
	end
	self._tab = tab
	local root = tab.Frame
	self._root = root
	root.ClipsDescendants = true
	self._scrollers, self._phs, self._viewers = {}, {}, {}
	self._sideRefs, self._tabRefs, self._cards, self._curPages = {}, {}, {}, {}
	self._drawerOpen, self._selected, self._page = false, nil, nil
	self._cw, self._th, self._cols = nil, nil, nil
	self:_cacheSettings()
	self._W, self._H = self:_dims()
	self._DW = math.clamp(math.floor(self._W * 0.42), 230, 300)

	-- левая колонка: название + список вкладок Preview (как навигация в Settings) -------------
	local nav = new("Frame", { Name = "PvNav", BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = U2(0, NAVW, 1, 0) }, root)
	corner(nav, 10)
	stroke(nav, C.border, 1)
	self._nav = nav
	self._titleL = txt("TextLabel", {
		Text = self.Title, Font = GB, TextSize = 15, Position = UDim2.fromOffset(14, 12), Size = U2(1, -28, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, nav)
	self._subL = txt("TextLabel", {
		Text = "", Font = GM, TextSize = 10, TextColor3 = C.dim, Position = UDim2.fromOffset(14, 33), Size = U2(1, -28, 0, 14),
	}, nav)
	new("Frame", { BackgroundColor3 = C.divLine, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 56), Size = U2(1, -28, 0, 1) }, nav)
	local navList = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 64), Size = U2(1, 0, 1, -70),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, nav)
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, navList)
	self._navList = navList

	-- центральная карточка: поиск + фильтр + сетка + крестик ---------------------------------
	local card = new("Frame", { Name = "PvCard", BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = U2(0, 470, 1, 0) }, root)
	corner(card, 10)
	stroke(card, C.border, 1)
	self._card = card

	local searchBox = new("Frame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 8), Size = U2(1, -(8 + 6 + 96 + 6 + 28 + 8), 0, 28),
	}, card)
	corner(searchBox, 7)
	stroke(searchBox, C.border, 1)
	local lens = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(11, 11) }, searchBox)
	corner(lens, 6)
	stroke(lens, C.dim, 1.5)
	new("Frame", {
		BackgroundColor3 = C.dim, BorderSizePixel = 0, Rotation = 45,
		Position = UDim2.fromOffset(18, 19), Size = UDim2.fromOffset(6, 2),
	}, searchBox)
	local searchInput = txt("TextBox", {
		PlaceholderText = "Search...", PlaceholderColor3 = C.dim, TextSize = 12, ClearTextOnFocus = false,
		Position = UDim2.fromOffset(30, 0), Size = U2(1, -38, 1, 0),
	}, searchBox)
	table.insert(self._phs, searchInput)
	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		self._query = searchInput.Text
		self:_applyFilter()
	end)

	local ddButton = txt("TextButton", {
		BackgroundTransparency = 0, BackgroundColor3 = C.input,
		AnchorPoint = V2(1, 0), Position = U2(1, -(8 + 28 + 6), 0, 8), Size = UDim2.fromOffset(96, 28),
	}, card)
	corner(ddButton, 7)
	stroke(ddButton, C.border, 1)
	local filterIcon = mkIcon(ddButton, "filter", 14, C.dim)
	filterIcon.Position = UDim2.fromOffset(8, 7)
	local ddText = txt("TextLabel", {
		Text = "All", Font = GM, TextSize = 12, Position = UDim2.fromOffset(28, 0), Size = U2(1, -44, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, ddButton)
	local filterArrow = mkIcon(ddButton, "chevron-down", 12, C.dim)
	filterArrow.AnchorPoint = V2(0.5, 0.5)
	filterArrow.Position = U2(1, -13, 0.5, 0)
	local ddList = new("Frame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0, Visible = false, ZIndex = 30,
		AnchorPoint = V2(1, 0), Position = U2(1, -(8 + 28 + 6), 0, 40), Size = UDim2.fromOffset(96, 40),
	}, card)
	corner(ddList, 7)
	stroke(ddList, C.border, 1)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, ddList)
	pad(ddList, 3, 3, 3, 3)
	ddButton.Activated:Connect(function()
		ddList.Visible = not ddList.Visible
		filterArrow.Rotation = ddList.Visible and 180 or 0
	end)

	-- крестик: удаляет вкладку Preview целиком (другие вкладки JustLib остаются)
	local closeBtn = txt("TextButton", {
		BackgroundTransparency = 0, BackgroundColor3 = C.input, AnchorPoint = V2(1, 0),
		Position = U2(1, -8, 0, 8), Size = UDim2.fromOffset(28, 28),
	}, card)
	corner(closeBtn, 7)
	stroke(closeBtn, C.border, 1)
	local xLines = {}
	for _, rot in ipairs({ 45, -45 }) do
		local l = new("Frame", {
			AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 2),
			Rotation = rot, BackgroundColor3 = C.dim, BorderSizePixel = 0,
		}, closeBtn)
		corner(l, 1)
		xLines[#xLines + 1] = l
	end
	closeBtn.MouseEnter:Connect(function()
		if not touchLast() then
			for _, l in ipairs(xLines) do
				tw(l, { BackgroundColor3 = C.danger }, 0.12)
			end
		end
	end)
	closeBtn.MouseLeave:Connect(function()
		for _, l in ipairs(xLines) do
			tw(l, { BackgroundColor3 = C.dim }, 0.12)
		end
	end)
	closeBtn.Activated:Connect(function()
		self:Close()
	end)

	local grid = new("ScrollingFrame", {
		Name = "PvGrid", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 44), Size = U2(1, -8, 1, -48),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENTS[1], ScrollingDirection = Enum.ScrollingDirection.Y,
	}, card)
	table.insert(self._scrollers, grid)
	self._gridLayout = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(140, 134), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	-- запас вокруг карточек: рамка и подъём карточки при наведении не обрезаются краями
	pad(grid, 4, 4, 4, 12)
	self._grid = grid

	local emptyL = txt("TextLabel", {
		Text = "Nothing found", TextSize = 13, TextColor3 = C.dim, Visible = false,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = V2(0.5, 0), Position = U2(0.5, 0, 0, 90), Size = UDim2.fromOffset(240, 20),
	}, card)
	self._d = { empty = emptyL, ddText = ddText, ddList = ddList, ddArrow = filterArrow }

	-- Полноэкранный режим ассета: информация слева, большой предпросмотр справа.
	local drawer = new("Frame", {
		Name = "PvDrawer", BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true, ClipsDescendants = true, ZIndex = 2, Visible = false,
		Size = U2(1, 0, 1, 0), Position = U2(0, self._W, 0, 0),
	}, root)
	corner(drawer, 10)
	stroke(drawer, C.border, 1)
	self._drawer = drawer
	self._dTitle = txt("TextLabel", {
		Font = GB, TextSize = 15, Position = UDim2.fromOffset(14, 8), Size = U2(1, -50, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd,
	}, drawer)
	self._dType = txt("TextLabel", {
		TextSize = 11, TextColor3 = C.dim, Position = UDim2.fromOffset(14, 29), Size = U2(1, -50, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd,
	}, drawer)
	local collapse = txt("TextButton", {
		Text = "‹", Font = GB, TextSize = 22, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = V2(1, 0.5), Position = U2(1, -6, 0, 26), Size = UDim2.fromOffset(28, 28),
	}, drawer)
	self._dCollapse = collapse
	collapse.MouseEnter:Connect(function()
		if not touchLast() then
			tw(collapse, { TextColor3 = C.txt }, 0.12)
		end
	end)
	collapse.MouseLeave:Connect(function()
		tw(collapse, { TextColor3 = C.dim }, 0.12)
	end)
	collapse.Activated:Connect(function()
		self:CloseDrawer()
	end)
	self._dHeaderLine = new("Frame", {
		BackgroundColor3 = C.divLine, BackgroundTransparency = 0.4, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 52), Size = U2(1, 0, 0, 1),
	}, drawer)
	local leftW = math.clamp(math.floor(self._W * 0.39), 190, 330)
	local left = new("Frame", { Name = "PvDetailInfo", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 62), Size = U2(0, leftW, 1, -62) }, drawer)
	self._dLeft = left
	self._dTabs = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = U2(1, -20, 0, 42) }, left)
	new("Frame", { BackgroundColor3 = C.divLine, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = U2(0, 0, 0, 48), Size = U2(1, 0, 0, 1) }, left)
	self._dPages = new("Frame", {
		BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(0, 52), Size = U2(1, 0, 1, -54),
	}, left)
	local right = new("Frame", { Name = "PvDetailPreview", BackgroundColor3 = C.badge, BorderSizePixel = 0 }, drawer)
	self._dRight = right
	corner(right, 10)
	stroke(right, C.border, 1)
	self._dRightPage = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = U2(1, 0, 1, 0), Visible = false }, right)

	-- общий цикл для всех 3D-превью: плавно на любом FPS (на скрытой вкладке не работает)
	self._cons[#self._cons + 1] = RunService.RenderStepped:Connect(function(dt)
		if not self._root or not self._root.Visible then
			return
		end
		for h, st in pairs(self._viewers) do
			h.step(dt, self._auto and not h.manualOnly and not st.dragging and os.clock() > st.resumeAt, self._speed)
			if h.motionEnabled and not h.animationActive and h.syncMotion and h.manualOnly and self._drawerOpen
				and self._selected == h.asset then
				h.motionElapsed = h.motionElapsed + dt
				local interval = 1 / (h.motionRate or 30)
				if h.motionElapsed >= interval then
					h.motionElapsed = h.motionElapsed % interval
					h.syncMotion()
				end
			end
		end
	end)

	-- первичная отрисовка ------------------------------------------------------------------
	self:_relayout()
	self:_renderSidebar()
	self:_syncCards()
	local startTab = self._tabs[1]
	if S("remember", true) then
		local last = S("last", "")
		if type(last) == "string" then
			local tn = last:match("^[^|]*")
			if tn and self:GetTab(tn) then
				startTab = self:GetTab(tn)
			end
		end
		local pg = S("page", "")
		if type(pg) == "string" and pg ~= "" then
			self._page = pg
		end
	end
	self._restoring = true
	self:_activate(startTab)
	self._restoring = false
	return true
end

--------------------------------------------------------------------
-- список слева
--------------------------------------------------------------------
function M:_renderSidebar()
	local list = self._navList
	if not list then
		return
	end
	for _, ch in ipairs(list:GetChildren()) do
		if not ch:IsA("UIListLayout") then
			ch:Destroy()
		end
	end
	self._sideRefs = {}
	local n = 0
	for _, a in ipairs(self._assets) do
		if a._alive then
			n = n + 1
		end
	end
	self._subL.Text = tostring(n) .. (n == 1 and " item" or " items")
	if #self._side == 0 then
		txt("TextLabel", {
			Text = "No tabs yet", TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(NAVW - 12, 30), LayoutOrder = 1,
		}, list)
		return
	end
	local ord = 0
	for _, e in ipairs(self._side) do
		ord = ord + 1
		if e.kind == "header" then
			local h = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(NAVW - 12, 26), LayoutOrder = ord }, list)
			new("Frame", { BackgroundColor3 = C.divLine, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 4), Size = U2(1, -12, 0, 1) }, h)
			txt("TextLabel", {
				Text = e.text, Font = GB, TextSize = 10, TextColor3 = C.dim, Position = UDim2.fromOffset(8, 10), Size = U2(1, -8, 0, 14),
			}, h)
		else
			local tab = e.tab
			local b = txt("TextButton", {
				BackgroundTransparency = 1, BackgroundColor3 = ACCENTS[1], Size = UDim2.fromOffset(NAVW - 12, 32), LayoutOrder = ord,
			}, list)
			corner(b, 7)
			local bar = new("Frame", {
				BackgroundColor3 = ACCENTS[1], BorderSizePixel = 0, Position = U2(0, 0, 0.5, -8), Size = UDim2.fromOffset(3, 16), Visible = false,
			}, b)
			corner(bar, 2)
			local ic = mkIcon(b, tab.Icon, 14, C.dim)
			ic.Position = U2(0, 12, 0.5, -7)
			local lb = txt("TextLabel", {
				Text = tab.Name, Font = GB, TextSize = 12, TextColor3 = C.dim, Position = UDim2.fromOffset(34, 0),
				Size = U2(1, -40, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
			}, b)
			b.MouseEnter:Connect(function()
				if not touchLast() and tab ~= self._activeTab then
					tw(lb, { TextColor3 = C.txt }, 0.12)
				end
			end)
			b.MouseLeave:Connect(function()
				if tab ~= self._activeTab then
					tw(lb, { TextColor3 = C.dim }, 0.12)
				end
			end)
			b.Activated:Connect(function()
				if tab ~= self._activeTab then
					self:_activate(tab)
				end
			end)
			self._sideRefs[tab] = { btn = b, icon = ic, lbl = lb, bar = bar }
		end
	end
	self:_styleSidebar()
end

function M:_styleSidebar()
	for tab, r in pairs(self._sideRefs or {}) do
		if r.btn and r.btn.Parent then
			local on = (tab == self._activeTab)
			r.bar.Visible = on
			tw(r.btn, { BackgroundTransparency = on and 0.86 or 1 }, 0.22)
			tw(r.lbl, { TextColor3 = on and ACCENTS[1] or C.dim }, 0.18)
			setIconColor(r.icon, on and ACCENTS[1] or C.dim)
		end
	end
end

function M:_activate(tab)
	if not self._root then
		return
	end
	if self._drawerOpen then
		self._selected = nil
		self:_markSelected()
		self:_setDrawer(false, true)
	end
	self._activeTab = tab
	self._type = "All"
	if tab and not self._restoring and S("remember", true) then
		B.cfgSet("_pv_last", tab.Name)
	end
	self:_styleSidebar()
	self:_applyFilter()
	self:_popGrid()
end

--------------------------------------------------------------------
-- карточки и фильтры
--------------------------------------------------------------------
function M:_inScope(tab, a)
	if not tab then
		return false
	end
	if tab.Filter then
		local ok, r = pcall(tab.Filter, a)
		return ok and r == true
	end
	if tab.ShowAll then
		return true
	end
	return a.tab == tab
end

function M:_makeCard(asset)
	local card = new("Frame", {
		Name = asset.Name, LayoutOrder = asset._order, BackgroundColor3 = C.badge, BorderSizePixel = 0, Visible = false,
	}, self._grid)
	corner(card, 9)
	local st = stroke(card, C.border, 1)
	local sc = new("UIScale", {}, card)
	local th = self._th or 90
	local thumb = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, th) }, card)
	-- внутренний отступ: модель никогда не упирается в рамку
	pad(thumb, 6, 6, 6, 4)
	local label = new("Frame", { BackgroundColor3 = C.btnBg, BorderSizePixel = 0, Position = UDim2.fromOffset(0, th), Size = U2(1, 0, 1, -th) }, card)
	corner(label, 9)
	new("Frame", { BackgroundColor3 = C.btnBg, BorderSizePixel = 0, Size = U2(1, 0, 0, 10) }, label)
	local titleIcon
	if asset.Icon then
		titleIcon = mkIcon(label, asset.Icon, 14, C.dim)
		titleIcon.Position = UDim2.fromOffset(9, 7)
	end
	local titleX = titleIcon and 29 or 10
	local titleLabel = txt("TextLabel", {
		Text = asset.Name, Font = GM, TextSize = 12, Position = UDim2.fromOffset(titleX, 6), Size = U2(1, -titleX - 30, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, label)
	txt("TextLabel", {
		Text = tostring(asset.Type or asset.Creator or ""), TextSize = 10, TextColor3 = C.dim,
		Position = UDim2.fromOffset(10, 23), Size = U2(1, -20, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd,
	}, label)

	-- три точки: меню действий (sibling кликабельного слоя, иначе его перекроет)
	local dots = txt("TextButton", {
		BackgroundTransparency = 1, BackgroundColor3 = C.badge, AnchorPoint = V2(1, 0),
		Position = U2(1, -6, 0, th + 5), Size = UDim2.fromOffset(26, 20), ZIndex = 6,
	}, card)
	corner(dots, 6)
	for i = 0, 2 do
		local d = new("Frame", {
			BackgroundColor3 = C.dim, BorderSizePixel = 0, Size = UDim2.fromOffset(3, 3),
			Position = UDim2.fromOffset(5 + i * 6, 9), ZIndex = 7,
		}, dots)
		corner(d, 2)
	end
	dots.MouseEnter:Connect(function()
		if not touchLast() then
			tw(dots, { BackgroundTransparency = 0 }, 0.12)
		end
	end)
	dots.MouseLeave:Connect(function()
		tw(dots, { BackgroundTransparency = 1 }, 0.12)
	end)
	dots.Activated:Connect(function()
		self:_openMenu(asset, dots)
	end)

	local btn = txt("TextButton", { Size = U2(1, 0, 1, 0), ZIndex = 5 }, card)
	btn.MouseEnter:Connect(function()
		if not touchLast() and not card:GetAttribute("pop") then
			tw(sc, { Scale = 1.03 }, 0.22, QUINT)
			if asset ~= self._selected then
				tw(st, { Color = C.dim }, 0.18)
			end
		end
	end)
	btn.MouseLeave:Connect(function()
		tw(sc, { Scale = 1 }, 0.25, QUINT)
		if asset ~= self._selected then
			tw(st, { Color = C.border }, 0.18)
		end
	end)
	btn.Activated:Connect(function()
		self:_onCardClick(asset)
	end)
	return { frame = card, stroke = st, thumb = thumb, label = label, dots = dots, scale = sc, built = false, titleIcon = titleIcon, titleLabel = titleLabel }
end

function M:_ensureThumb(asset, c)
	if c.built then
		return
	end
	c.built = true
	makeThumb(c.thumb, asset)
end

function M:_syncCards()
	if not self._grid then
		return
	end
	for asset, c in pairs(self._cards) do
		if not asset._alive then
			c.frame:Destroy()
			self._cards[asset] = nil
		end
	end
	for _, asset in ipairs(self._assets) do
		if not self._cards[asset] then
			self._cards[asset] = self:_makeCard(asset)
		end
	end
	self:_renderSidebar()
end

-- плавное появление карточек при смене вкладки / перестроении сетки
function M:_popGrid()
	if not self._grid or not S("anim", true) then
		return
	end
	local n = 0
	for _, a in ipairs(self._assets) do
		local c = self._cards[a]
		if c and c.frame.Visible then
			n = n + 1
			local sc, frame = c.scale, c.frame
			local delay = math.min(n * 0.022, 0.26)
			sc.Scale = 0.9
			frame:SetAttribute("pop", true)
			B.delay(delay, function()
				if sc.Parent then
					tw(sc, { Scale = 1 }, 0.4, QUINT)
				end
			end)
			B.delay(delay + 0.4, function()
				if frame.Parent then
					frame:SetAttribute("pop", nil)
				end
			end)
		end
	end
	self._grid.CanvasPosition = V2(0, 0)
end

function M:_buildTypeList()
	local d = self._d
	if not d then
		return
	end
	for _, ch in ipairs(d.ddList:GetChildren()) do
		if ch:IsA("TextButton") then
			ch:Destroy()
		end
	end
	local types = self._types or { "All" }
	d.ddList.Size = UDim2.fromOffset(96, #types * 26 + (#types - 1) * 2 + 6)
	for i, t in ipairs(types) do
		local on = (t == self._type)
		local ob = txt("TextButton", {
			Text = cleanDropdownLabel(t), Font = GM, TextSize = 11, TextColor3 = on and ACCENTS[1] or C.txt, BackgroundColor3 = ACCENTS[1],
			BackgroundTransparency = on and 0.85 or 1, Size = UDim2.fromOffset(90, 26), LayoutOrder = i, ZIndex = 31,
		}, d.ddList)
		pad(ob, 8, 0, 0, 0)
		corner(ob, 5)
		ob.Activated:Connect(function()
			self._type = t
			d.ddList.Visible = false
			if d.ddArrow then d.ddArrow.Rotation = 0 end
			self:_applyFilter()
			self:_popGrid()
		end)
	end
	d.ddText.Text = cleanDropdownLabel(self._type)
end

function M:_useFlatGrid()
	if not self._grid then
		return
	end
	self._grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self._grid.CanvasSize = U2(0, 0, 0, 0)
	for _, c in pairs(self._cards) do
		if c.frame and c.frame.Parent ~= self._grid then
			c.frame.Parent = self._grid
		end
	end
	for _, frame in ipairs(self._groupFrames or {}) do
		if frame and frame.Parent then
			frame:Destroy()
		end
	end
	self._groupFrames = {}
	self._groupLayouts = {}
	if self._groupListLayout then
		self._groupListLayout:Destroy()
		self._groupListLayout = nil
	end
	if not self._gridLayout or not self._gridLayout.Parent then
		self._gridLayout = new("UIGridLayout", {
			CellSize = UDim2.fromOffset(self._cw or 140, (self._th or 90) + 44),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, self._grid)
	end
end

function M:_renderGroupedCards(visible)
	if not self._grid then
		return
	end
	local oldCanvasPosition = self._grid.CanvasPosition
	local visibleSet = {}
	for _, asset in ipairs(visible) do
		visibleSet[asset] = true
	end
	for asset, c in pairs(self._cards) do
		if c.frame then
			c.frame.Parent = visibleSet[asset] and self._grid or nil
		end
	end
	for _, frame in ipairs(self._groupFrames or {}) do
		if frame and frame.Parent then
			frame:Destroy()
		end
	end
	self._groupFrames = {}
	self._groupLayouts = {}
	if self._gridLayout then
		self._gridLayout:Destroy()
		self._gridLayout = nil
	end
	self._grid.AutomaticCanvasSize = Enum.AutomaticSize.None
	if not self._groupListLayout or not self._groupListLayout.Parent then
		self._groupListLayout = new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}, self._grid)
	end

	local grouped, names = {}, {}
	local field = self._grouping
	for _, asset in ipairs(visible) do
		local value = asset[field]
		local name = (value == nil or tostring(value) == "") and "Unknown" or tostring(value)
		if not grouped[name] then
			grouped[name] = {}
			names[#names + 1] = name
		end
		grouped[name][#grouped[name] + 1] = asset
	end
	table.sort(names, function(a, b)
		return string.lower(a) < string.lower(b)
	end)

	local columns = math.max(1, self._cols or 1)
	local cellHeight = (self._th or 90) + 44
	local cellWidth = self._cw or 140
	local totalHeight = 16
	for groupIndex, name in ipairs(names) do
		local count = #grouped[name]
		local rows = math.ceil(count / columns)
		local cardsHeight = rows * cellHeight + math.max(0, rows - 1) * 8
		local groupHeight = 25 + cardsHeight + 4
		local group = new("Frame", {
			Name = "Group_" .. tostring(groupIndex),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, groupHeight),
			LayoutOrder = groupIndex,
		}, self._grid)
		self._groupFrames[#self._groupFrames + 1] = group
		txt("TextLabel", {
			Text = name,
			Font = GB,
			TextSize = 11,
			TextColor3 = C.dim,
			Position = UDim2.fromOffset(5, 0),
			Size = UDim2.new(1, -10, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, group)
		new("Frame", {
			BackgroundColor3 = C.divLine,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(5, 20),
			Size = UDim2.new(1, -10, 0, 1),
		}, group)
		local cardsGrid = new("Frame", {
			Name = "GroupCards",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 25),
			Size = UDim2.new(1, 0, 0, cardsHeight),
		}, group)
		local layout = new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellWidth, cellHeight),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, cardsGrid)
		self._groupLayouts[#self._groupLayouts + 1] = layout
		for index, asset in ipairs(grouped[name]) do
			local card = self._cards[asset]
			if card then
				card.frame.Parent = cardsGrid
				card.frame.LayoutOrder = index
			end
		end
		totalHeight = totalHeight + groupHeight
		if groupIndex < #names then
			totalHeight = totalHeight + 10
		end
	end
	self._grid.CanvasSize = U2(0, 0, 0, totalHeight)
	local maxY = math.max(0, totalHeight - self._grid.AbsoluteSize.Y)
	self._grid.CanvasPosition = V2(oldCanvasPosition.X, math.clamp(oldCanvasPosition.Y, 0, maxY))
end

function M:SetGrouping(key)
	local allowed = { None = true, Type = true, Creator = true, Category = true }
	key = key or "None"
	if not allowed[key] then
		return false
	end
	if self._grouping == key then
		return true
	end
	self._grouping = key
	self:_applyFilter()
	return true
end

function M:GetGrouping()
	return self._grouping or "None"
end

function M:_applyFilter()
	if not self._grid or not self._d then
		return
	end
	local tab = self._activeTab
	local types, seen = { "All" }, { All = true }
	for _, a in ipairs(self._assets) do
		if self:_inScope(tab, a) and a.Type and not seen[a.Type] then
			seen[a.Type] = true
			types[#types + 1] = a.Type
		end
	end
	if not seen[self._type] then
		self._type = "All"
	end
	self._types = types
	local q = string.lower(self._query or "")
	local visible = {}
	for _, a in ipairs(self._assets) do
		local c = self._cards[a]
		if c then
			local ok = tab ~= nil and self:_inScope(tab, a) and (self._type == "All" or a.Type == self._type) and matchQuery(a, q)
			c.frame.Visible = ok
			if ok then
				visible[#visible + 1] = a
				self:_ensureThumb(a, c)
			end
		end
	end
	local sort = self._sort or { Key = "Default", Descending = false }
	local key = sort.Key or "Default"
	table.sort(visible, function(a, b)
		local av, bv
		if key == "Default" then
			av, bv = a._order or 0, b._order or 0
		else
			av, bv = a[key], b[key]
			av = av == nil and "" or tostring(av)
			bv = bv == nil and "" or tostring(bv)
			av, bv = string.lower(av), string.lower(bv)
		end
		if av == bv then
			return (a._order or 0) < (b._order or 0)
		end
		if sort.Descending then
			return av > bv
		end
		return av < bv
	end)
	if self._grouping and self._grouping ~= "None" then
		self:_renderGroupedCards(visible)
	else
		self:_useFlatGrid()
		for index, asset in ipairs(visible) do
			local card = self._cards[asset]
			if card then
				card.frame.LayoutOrder = index
			end
		end
	end
	self._d.empty.Visible = (#visible == 0)
	self:_buildTypeList()
	self:_markSelected(true)
end

function M:_markSelected(instant)
	for asset, c in pairs(self._cards) do
		local on = (asset == self._selected)
		local props = { Color = on and ACCENTS[1] or C.border, Thickness = on and 2 or 1 }
		if instant then
			c.stroke.Color, c.stroke.Thickness = props.Color, props.Thickness
		else
			tw(c.stroke, props, 0.22)
		end
	end
end

-- первый клик: выезжает панель, второй клик по тому же ассету: задвигается
function M:_onCardClick(asset)
	if self._drawerOpen and self._selected == asset then
		self:CloseDrawer()
	else
		self:_select(asset)
		self:_setDrawer(true)
	end
end

function M:_select(asset)
	self._selected = asset
	self:_markSelected()
	if asset then
		self:_refreshDrawer(self._drawerOpen)
		safe(asset.Callback, asset)
	end
end

function M:_goto(target)
	if not self._root then
		return
	end
	local tab, asset, page
	if type(target) == "string" then
		tab = self:GetTab(target)
	elseif type(target) == "table" then
		if target._isAsset then
			asset, tab = target, target.tab
		elseif target._isTab then
			tab = target
		else
			if target.Tab then
				tab = (type(target.Tab) == "string") and self:GetTab(target.Tab) or target.Tab
			end
			if target.Asset then
				if type(target.Asset) == "string" then
					asset = self:GetAsset(target.Asset)
				else
					asset = target.Asset
				end
				if asset and not tab then
					tab = asset.tab
				end
			end
			page = target.Page
		end
	end
	if tab and tab ~= self._activeTab then
		self:_activate(tab)
	end
	if asset then
		if page then
			self._page = page
		end
		self:_select(asset)
		self:_setDrawer(true)
	end
end

--------------------------------------------------------------------
-- меню "три точки"
--------------------------------------------------------------------
function M:_closeMenu()
	if self._menuBack then
		pcall(function() self._menuBack:Destroy() end)
	end
	self._menu, self._menuBack = nil, nil
end

function M:_openMenu(asset, anchor)
	if not self._root then
		return
	end
	self:_closeMenu()
	local items = {}
	local function openPage(id)
		return function()
			self._page = id
			self:_select(asset)
			self:_setDrawer(true)
		end
	end
	for _, page in ipairs(self:_pagesFor(asset)) do
		items[#items + 1] = { name = page.name, icon = page.icon, fn = openPage(page.id) }
	end
	for _, action in ipairs(asset._actions) do
		items[#items + 1] = { name = action.Name, icon = action.Icon, fn = function() safe(action.Callback, asset, action) end }
	end
	if #items == 0 then
		return
	end

	local back = txt("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 39 }, self._root)
	self._menuBack = back
	back.Activated:Connect(function()
		self:_closeMenu()
	end)
	local W, ITEM = 150, 30
	local H = #items * ITEM + 8
	local panel = new("Frame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 40, Active = true, Size = UDim2.fromOffset(W, H),
	}, back)
	corner(panel, 8)
	stroke(panel, C.border, 1)
	pad(panel, 4, 4, 4, 4)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	local s = curScale()
	local rp, bp, bs = self._root.AbsolutePosition, anchor.AbsolutePosition, anchor.AbsoluteSize
	local x = (bp.X - rp.X) / s + bs.X / s - W
	local y = (bp.Y - rp.Y) / s + bs.Y / s + 4
	x = math.clamp(x, 4, math.max(4, self._W - W - 4))
	if y + H > self._H - 4 then
		y = (bp.Y - rp.Y) / s - H - 4
	end
	panel.Position = UDim2.fromOffset(x, math.max(4, y))
	local ps = new("UIScale", { Scale = 0.88 }, panel)
	tw(ps, { Scale = 1 }, 0.22, QUINT)
	for i, it in ipairs(items) do
		local b = txt("TextButton", {
			BackgroundTransparency = 1, BackgroundColor3 = ACCENTS[1], Size = UDim2.fromOffset(W - 8, ITEM), LayoutOrder = i, ZIndex = 41,
		}, panel)
		corner(b, 6)
		local tx = 10
		if it.icon then
			local ic = mkIcon(b, it.icon, 14, ACCENTS[1])
			ic.Position = U2(0, 8, 0.5, -7)
			ic.ZIndex = 42
			tx = 30
		end
		txt("TextLabel", {
			Text = tostring(it.name), Font = GM, TextSize = 12, Position = UDim2.fromOffset(tx, 0), Size = U2(1, -tx - 4, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 42,
		}, b)
		b.MouseEnter:Connect(function()
			if not touchLast() then
				tw(b, { BackgroundTransparency = 0.85 }, 0.1)
			end
		end)
		b.MouseLeave:Connect(function()
			tw(b, { BackgroundTransparency = 1 }, 0.1)
		end)
		b.Activated:Connect(function()
			self:_closeMenu()
			it.fn()
		end)
	end
	self._menu = panel
end

--------------------------------------------------------------------
-- панель справа (drawer)
--------------------------------------------------------------------
function M:_animateAssetIntoDetail()
	if not S("anim", true) then
		if self._dRightPage then self._dRightPage.Visible = true end
		return false
	end
	local function reveal(root, delayTime)
		if not root then return end
		local objects = { root }
		for _, child in ipairs(root:GetDescendants()) do
			objects[#objects + 1] = child
		end
		for _, obj in ipairs(objects) do
			if obj:IsA("UIStroke") then
				local target = obj.Transparency
				obj.Transparency = 1
				B.delay(delayTime or 0, function()
					if obj.Parent then
						TS:Create(obj, TweenInfo.new(0.34, QUINT, OUT), { Transparency = target }):Play()
					end
				end)
			elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
				local textTarget, bgTarget = obj.TextTransparency, obj.BackgroundTransparency
				obj.TextTransparency, obj.BackgroundTransparency = 1, 1
				B.delay(delayTime or 0, function()
					if obj.Parent then
						TS:Create(obj, TweenInfo.new(0.34, QUINT, OUT), {
							TextTransparency = textTarget, BackgroundTransparency = bgTarget,
						}):Play()
					end
				end)
			elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
				local imageTarget, bgTarget = obj.ImageTransparency, obj.BackgroundTransparency
				obj.ImageTransparency, obj.BackgroundTransparency = 1, 1
				B.delay(delayTime or 0, function()
					if obj.Parent then
						TS:Create(obj, TweenInfo.new(0.38, QUINT, OUT), {
							ImageTransparency = imageTarget, BackgroundTransparency = bgTarget,
						}):Play()
					end
				end)
			elseif obj:IsA("ViewportFrame") or obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
				local bgTarget = obj.BackgroundTransparency
				obj.BackgroundTransparency = 1
				if obj:IsA("ViewportFrame") then
					local imageTarget = obj.ImageTransparency
					obj.ImageTransparency = 1
					B.delay(delayTime or 0, function()
						if obj.Parent then
							TS:Create(obj, TweenInfo.new(0.42, QUINT, OUT), {
								BackgroundTransparency = bgTarget, ImageTransparency = imageTarget,
							}):Play()
						end
					end)
				else
					B.delay(delayTime or 0, function()
						if obj.Parent then
							TS:Create(obj, TweenInfo.new(0.34, QUINT, OUT), { BackgroundTransparency = bgTarget }):Play()
						end
					end)
				end
			end
		end
	end
	if self._dRightPage then
		self._dRightPage.Visible = true
		local scale = new("UIScale", { Scale = 0.965 }, self._dRightPage)
		TS:Create(scale, TweenInfo.new(0.48, QUINT, OUT), { Scale = 1 }):Play()
		reveal(self._dRightPage, 0.02)
	end
	if self._dPages then
		reveal(self._dPages, 0.08)
	end
	if self._dTitle then reveal(self._dTitle, 0.06) end
	if self._dType then reveal(self._dType, 0.1) end
	if self._dTabs then reveal(self._dTabs, 0.12) end
	return true
end

function M:_setDrawer(open, instant)
	if not self._drawer then
		return
	end
	open = open == true
	if open == (self._drawerOpen == true) then
		return
	end
	self._drawerOpen = open
	local st = self:_states(open)
	local nav, card, drawer = self._nav, self._card, self._drawer
	self._cardW = st.cardW
	card.Size = U2(0, st.cardW, 1, 0)
	self:_fitGrid()
	if open then
		drawer.Visible = true
		if self._dRightPage then self._dRightPage.Visible = false end
		local animated = self:_animateAssetIntoDetail()
		if not animated and self._dRightPage then self._dRightPage.Visible = true end
	else
		self:_cleanupPage()
		self:_clearLargePreview()
	end
	self._slideTok = (self._slideTok or 0) + 1
	if instant then
		self._sliding = false
		nav.Position = U2(0, st.navX, 0, 0)
		card.Position = U2(0, st.cardX, 0, 0)
		drawer.Position = U2(0, st.drawerX, 0, 0)
		drawer.Visible = open
		return
	end
	local tok = self._slideTok
	if not S("anim", true) then
		nav.Position = U2(0, st.navX, 0, 0)
		card.Position = U2(0, st.cardX, 0, 0)
		drawer.Position = U2(0, st.drawerX, 0, 0)
		if not open then drawer.Visible = false end
		return
	end
	self._sliding = true
	local info = TweenInfo.new(open and 0.48 or 0.42, QUINT, OUT)
	TS:Create(nav, info, { Position = U2(0, st.navX, 0, 0) }):Play()
	TS:Create(card, info, { Position = U2(0, st.cardX, 0, 0) }):Play()
	TS:Create(drawer, info, { Position = U2(0, st.drawerX, 0, 0) }):Play()
	B.delay(open and 0.5 or 0.44, function()
		if self._slideTok ~= tok or not self._drawer then return end
		self._sliding = false
		if not open then self._drawer.Visible = false end
	end)
end

function M:_controlsFor(asset)
	local list, seen = {}, {}
	local function addFrom(container, assetScoped)
		if container and not seen[container] then
			seen[container] = true
			for _, d in ipairs(container._controls or {}) do
				local visible = true
				if assetScoped then
					local currentIndex = asset and asset._variantIndex or 1
					if d.variantsPinned then
						visible = d.variantsPinned[currentIndex] == true
					elseif d.pinned == false then
						visible = d.variantIndex == currentIndex
					end
				end
				if visible then
					list[#list + 1] = d
				end
			end
		end
	end
	if asset then
		addFrom(asset, true)
		addFrom(asset.tab)
	end
	addFrom(self._activeTab)
	addFrom(self)
	return list
end

function M:_pagesFor(asset)
	local out = { PAGES.info }
	local controls = self:_controlsFor(asset)
	local hasVariants = asset and type(asset._variants) == "table" and #asset._variants > 1
	if #controls > 0 or hasVariants then
		out[#out + 1] = PAGES.controllers
	end
	if hasPreview(asset) then
		out[#out + 1] = PAGES.preview
	end
	for _, p in ipairs(self._pages) do
		local show = true
		if p.visible then
			local ok, r = pcall(p.visible, asset)
			show = ok and r ~= false
		end
		if show and p.build then
			out[#out + 1] = p
		end
	end
	return out
end

function M:_cleanupPage()
	if self._pageCleanup then
		pcall(self._pageCleanup)
		self._pageCleanup = nil
	end
	if self._pageRoot then
		pcall(function() self._pageRoot:Destroy() end)
		self._pageRoot = nil
	end
end

function M:_renderDrawerTabs()
	local bar = self._dTabs
	if not bar then
		return
	end
	for _, ch in ipairs(bar:GetChildren()) do
		ch:Destroy()
	end
	self._tabRefs = {}
	local pages = self._curPages
	local n = #pages
	for i, p in ipairs(pages) do
		local b = txt("TextButton", {
			BackgroundTransparency = 1, Size = U2(1 / n, -4, 1, -4), Position = U2((i - 1) / n, 2, 0, 0),
		}, bar)
		corner(b, 7)
		local ic = mkIcon(b, p.icon, 16, C.dim)
		ic.AnchorPoint = V2(0.5, 0)
		ic.Position = U2(0.5, 0, 0, 4)
		local lb = txt("TextLabel", {
			Text = p.name, Font = GM, TextSize = 10, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
			Position = U2(0, 0, 0, 23), Size = U2(1, 0, 0, 13), TextTruncate = Enum.TextTruncate.AtEnd,
		}, b)
		b.MouseEnter:Connect(function()
			if not touchLast() and p.id ~= self._page then
				tw(b, { BackgroundTransparency = 0.9 }, 0.12)
			end
		end)
		b.MouseLeave:Connect(function()
			tw(b, { BackgroundTransparency = 1 }, 0.12)
		end)
		b.Activated:Connect(function()
			if p.id ~= self._page then
				self:_showPage(p.id, true)
			end
		end)
		self._tabRefs[p.id] = { btn = b, icon = ic, lbl = lb, idx = i }
	end
	local ind = new("Frame", {
		Name = "Indicator", BackgroundColor3 = ACCENTS[1], BorderSizePixel = 0, AnchorPoint = V2(0.5, 1),
		Position = U2(0.5, 0, 1, 0), Size = UDim2.fromOffset(24, 2),
	}, bar)
	corner(ind, 1)
	self._indicator = ind
	self._indN = n
end

function M:_styleDrawerTabs(instant)
	for id, r in pairs(self._tabRefs or {}) do
		if r.btn and r.btn.Parent then
			local on = (id == self._page)
			local col = on and ACCENTS[1] or C.dim
			if instant then
				r.lbl.TextColor3 = on and C.txt or C.dim
				if r.icon:IsA("TextLabel") then
					r.icon.TextColor3 = col
				else
					r.icon.ImageColor3 = col
				end
			else
				tw(r.lbl, { TextColor3 = on and C.txt or C.dim }, 0.18)
				setIconColor(r.icon, col)
			end
			if on and self._indicator and self._indicator.Parent then
				local pos = U2((r.idx - 0.5) / math.max(self._indN, 1), 0, 1, 0)
				if instant then
					self._indicator.Position = pos
				else
					tw(self._indicator, { Position = pos }, 0.4, QUINT)
				end
			end
		end
	end
end

function M:_showPage(id, animate)
	local a = self._selected
	if not a or not self._dPages then
		return
	end
	local page
	for _, p in ipairs(self._curPages) do
		if p.id == id then
			page = p
		end
	end
	if not page then
		page = self._curPages[1]
	end
	if not page then
		return
	end
	local changed = (self._page ~= page.id)
	self._page = page.id
	self:_cleanupPage()
	local pr = new("Frame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		Position = U2(0, 0, 0, animate and 14 or 0),
	}, self._dPages)
	self._pageRoot = pr
	local ok, cleanup = pcall(page.build, pr, a, self)
	if ok then
		if type(cleanup) == "function" then
			self._pageCleanup = cleanup
		end
	else
		warn("[PreviewUI] page '" .. tostring(page.name) .. "' failed: " .. tostring(cleanup))
	end
	if animate then
		tw(pr, { Position = U2(0, 0, 0, 0) }, 0.45, QUINT)
	end
	self:_styleDrawerTabs(not changed and not animate)
	if changed and S("remember", true) then
		B.cfgSet("_pv_page", page.id)
	end
end

function M:_clearLargePreview()
	self:_setPreviewFullscreen(false)
	if self._detailPreviewCleanup then
		pcall(self._detailPreviewCleanup)
		self._detailPreviewCleanup = nil
	end
	if self._dRightPage then
		for _, child in ipairs(self._dRightPage:GetChildren()) do child:Destroy() end
		self._dRightPage.Visible = false
	end
end

function M:_buildLargePreview(asset, enabled)
	if not self._dRightPage then
		return
	end
	if self._detailPreviewCleanup then
		pcall(self._detailPreviewCleanup)
		self._detailPreviewCleanup = nil
	end
	for _, child in ipairs(self._dRightPage:GetChildren()) do
		child:Destroy()
	end
	self._dRightPage.Visible = self._drawerOpen == true
	if enabled then
		local ok, cleanup = pcall(PAGES.preview.build, self._dRightPage, asset, self)
		if ok and type(cleanup) == "function" then
			self._detailPreviewCleanup = cleanup
		elseif not ok then
			warn("[PreviewUI] large preview failed: " .. tostring(cleanup))
		end
	else
		self:_setPreviewFullscreen(false)
		txt("TextLabel", {
			Text = "No preview available", TextSize = 13, TextColor3 = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
			Size = U2(1, 0, 1, 0),
		}, self._dRightPage)
	end
end

function M:_refreshDrawer(animate)
	if not self._drawer then
		return
	end
	local a = self._selected
	if not a then
		return
	end
	self._dTitle.Text = tostring(a.Name)
	local sub = tostring(a.Type or "")
	if a.Creator then
		sub = (sub ~= "" and (sub .. "  ·  ") or "") .. tostring(a.Creator)
	end
	self._dType.Text = sub
	local pages = self:_pagesFor(a)
	self._curPages = {}
	local hasLargePreview = false
	for _, p in ipairs(pages) do
		if p.id == "preview" then
			hasLargePreview = true
		else
			self._curPages[#self._curPages + 1] = p
		end
	end
	if #self._curPages == 0 then
		self._curPages[1] = { id = "empty", name = "Info", icon = "info", build = function(parent)
			txt("TextLabel", { Text = "No additional information", TextColor3 = C.dim, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = U2(1, 0, 0, 30) }, parent)
		end }
	end
	self:_renderDrawerTabs()
	if not self._page then
		self._page = self._curPages[1].id
	end
	local found = false
	for _, p in ipairs(self._curPages) do if p.id == self._page then found = true end end
	if not found then self._page = self._curPages[1].id end
	self:_showPage(self._page, animate)
	self:_buildLargePreview(a, hasLargePreview)
end

return M
