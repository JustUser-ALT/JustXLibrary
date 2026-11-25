--[[
    JustXLibrary Addon: Console
    Adapted from the supplied Delta Console v1.0 source.
    Console UI uses PlayerGui and local glyph icons isolated from the hub.
]]
return {
    Info = {
        Name = "Console",
        Author = "JustXLibrary",
        Version = "1.1.0",
        Description = "Full log console integrated into the JustXLibrary topbar.",
        Library = "4.4",
    },
    Init = function(Addon)
--[[
	Delta Console v1.0
	Executor script (Luau). Run it through Delta; re-executing replaces the old instance.

	Log sources:
	  Print / Warning / Error  -> LogService.MessageOut message types.
	  Script                   -> output produced through print/warn/error called from scripts that run
	                              AFTER this one (executor global environment is wrapped, see "Source tagging").
	  Game                     -> every other message (game scripts, engine/core messages, and anything
	                              that cannot be attributed to an executor script).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")

----------------------------------------------------------------------------------------------------
-- Config
----------------------------------------------------------------------------------------------------
local CONFIG = {
	Version = "v1.0",
	SettingsFile = "JustXConsole_settings.json",
	BlockedFile = "JustXConsole_blocked.json", -- { [GameId or PlaceId] = { blocked message texts } }
	BaseSize = Vector2.new(720, 410),
	PendingTtl = 2, -- seconds a print/warn/error call waits for its MessageOut twin
	FlushPerFrame = 30, -- max log rows created per frame
	MaxDisplayChars = 1500, -- row display cap; copy always uses the full text
}

----------------------------------------------------------------------------------------------------
-- Executor environment (used only for print/warn/error source tagging)
----------------------------------------------------------------------------------------------------
local env = (getgenv and getgenv()) or _G

----------------------------------------------------------------------------------------------------
-- Settings (persisted when the executor has readfile/writefile)
----------------------------------------------------------------------------------------------------
local settings = {
	UIScale = 1,
	AutoScroll = true,
	Timestamps = true,
	FlashNew = true,
	MaxLogs = 300,
}

local function saveSettings()
	if writefile then
		pcall(function()
			writefile(CONFIG.SettingsFile, HttpService:JSONEncode(settings))
		end)
	end
end

do
	if isfile and readfile then
		pcall(function()
			if isfile(CONFIG.SettingsFile) then
				local data = HttpService:JSONDecode(readfile(CONFIG.SettingsFile))
				for key, default in pairs(settings) do
					if type(data[key]) == type(default) then
						settings[key] = data[key]
					end
				end
			end
		end)
	end
	settings.UIScale = math.clamp(settings.UIScale, 0.5, 1.5)
	settings.MaxLogs = math.clamp(settings.MaxLogs, 100, 10000)
end

----------------------------------------------------------------------------------------------------
-- Palette
----------------------------------------------------------------------------------------------------
local WHITE = Color3.new(1, 1, 1)
local C = {
	window = Color3.fromRGB(14, 14, 24),
	windowTop = Color3.fromRGB(21, 17, 40),
	panel = Color3.fromRGB(16, 16, 27),
	panelStroke = Color3.fromRGB(34, 32, 54),
	chip = Color3.fromRGB(27, 27, 42),
	chipRed = Color3.fromRGB(46, 24, 40),
	btn = Color3.fromRGB(28, 28, 44),
	btnHover = Color3.fromRGB(40, 38, 64),
	purple = Color3.fromRGB(110, 76, 235),
	purpleLight = Color3.fromRGB(167, 139, 250),
	purpleBg = Color3.fromRGB(38, 28, 86),
	purpleBgHover = Color3.fromRGB(52, 40, 112),
	text = Color3.fromRGB(240, 240, 250),
	chipText = Color3.fromRGB(205, 205, 225),
	sub = Color3.fromRGB(140, 140, 168),
	dim = Color3.fromRGB(112, 112, 138),
	line = Color3.fromRGB(30, 30, 46),
	track = Color3.fromRGB(44, 44, 66),
	green = Color3.fromRGB(74, 222, 128),
	greenBg = Color3.fromRGB(16, 52, 36),
	amber = Color3.fromRGB(251, 176, 52),
	amberBg = Color3.fromRGB(60, 42, 14),
	red = Color3.fromRGB(255, 72, 72),
	redBg = Color3.fromRGB(58, 20, 30),
	redBgHover = Color3.fromRGB(78, 26, 38),
	blue = Color3.fromRGB(96, 175, 255),
	blueBg = Color3.fromRGB(20, 44, 84),
}

local KIND_COLOR = {
	Print = Color3.fromRGB(238, 238, 248),
	Warning = C.amber,
	Error = C.red,
}

local KIND_ACCENT = {
	Print = Color3.fromRGB(128, 128, 160),
	Warning = C.amber,
	Error = C.red,
}
local KIND_TINT = { Print = 1, Warning = 0.9, Error = 0.85 } -- row background transparency
local KIND_ICON = { Print = "info", Warning = "triangle-alert", Error = "circle-alert" }
local KIND_PILL_BG = { Print = Color3.fromRGB(44, 44, 68), Warning = C.amberBg, Error = C.redBg }
local CHIP_ON = {
	Print = Color3.fromRGB(92, 104, 160),
	Warning = Color3.fromRGB(196, 128, 20),
	Error = Color3.fromRGB(204, 44, 56),
}

local SOURCE_STYLE = {
	Script = { icon = "code-xml", color = C.purpleLight, bg = Color3.fromRGB(40, 30, 92) },
	Game = { icon = "gamepad-2", color = C.blue, bg = C.blueBg },
}

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------
local conns = {}
local loopTweens = {}
local destroyed = false

local function bind(signal, fn)
	local c = signal:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local function new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	return new("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius) })
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Parent = parent,
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(parent, l, t, r, b)
	return new("UIPadding", {
		Parent = parent,
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
	})
end

local function tween(obj, duration, props, style, direction)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function loopTween(obj, info, props)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	loopTweens[#loopTweens + 1] = tw
	return tw
end

local function setZ(root, z)
	if root:IsA("GuiObject") then
		root.ZIndex = z
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = z + 1
		end
	end
end

local function label(parent, props)
	local base = {
		Parent = parent,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return new("TextLabel", base)
end

----------------------------------------------------------------------------------------------------
-- Icons (local glyphs; isolated from the hub's icon system)
----------------------------------------------------------------------------------------------------
local ICON_FALLBACK = {
	terminal = ">_", settings = "⚙", minus = "−", x = "×",
	search = "⌕", crown = "♛", info = "i", check = "✓",
	["chevron-down"] = "v", ["code-xml"] = "</>",
	["gamepad-2"] = "G", gamepad = "G",
	["triangle-alert"] = "!", ["circle-alert"] = "!",
	pause = "Ⅱ", play = "▶", ["arrow-left"] = "<",
	copy = "▣", trash = "▤", ban = "×", ["layout-grid"] = "▦",
}
-- Console glyphs are deliberately plain TextLabels with unique names.
-- They do not register with, or inherit assets from, JustLib's Icon Pack.
local function icon(parent, name, size, color, fallback, props)
	if name == "trash" then
		local root = new("Frame", {
			Parent = parent, Name = "JXConsoleGlyph_trash",
			BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
		})
		local lid = new("Frame", {
			Parent = root, Name = "Lid", AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.18, 0), Size = UDim2.new(0.72, 0, 0, 2),
			BackgroundColor3 = color, BorderSizePixel = 0,
		})
		local handle = new("Frame", {
			Parent = root, Name = "Handle", AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.06, 0), Size = UDim2.new(0.28, 0, 0, 2),
			BackgroundColor3 = color, BorderSizePixel = 0,
		})
		local body = new("Frame", {
			Parent = root, Name = "Body", AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.28, 0), Size = UDim2.new(0.58, 0, 0.62, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0,
		})
		new("UICorner", { Parent = body, CornerRadius = UDim.new(0, 2) })
		new("UIStroke", { Parent = body, Color = color, Thickness = 1.5 })
		for k, v in pairs(props or {}) do root[k] = v end
		return root
	end
	local glyph = new("TextLabel", {
		Parent = parent, Name = "JXConsoleGlyph_" .. tostring(name),
		BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
		Text = fallback or ICON_FALLBACK[name] or "•",
		TextColor3 = color, Font = Enum.Font.GothamBold,
		TextScaled = true, TextWrapped = false, BorderSizePixel = 0,
	})
	for k, v in pairs(props or {}) do glyph[k] = v end
	return glyph
end
local function setIconColor(glyph, color)
	if not (glyph and glyph.Parent) then return end
	if glyph:IsA("TextLabel") then
		glyph.TextColor3 = color
	else
		for _, child in ipairs(glyph:GetDescendants()) do
			if child:IsA("UIStroke") then child.Color = color
			elseif child:IsA("GuiObject") then child.BackgroundColor3 = color end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Root GUI
----------------------------------------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "JustXConsole",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2147483647,
	ZIndexBehavior = Enum.ZIndexBehavior.Global,
})
do
	-- JustXLibrary itself is hosted in CoreGui. Keep Console in the same GUI layer
	-- so DisplayOrder is compared against the library rather than another container.
	local coreGui = game:GetService("CoreGui")
	local ok = pcall(function() gui.Parent = coreGui end)
	if not ok or not gui.Parent then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	Addon.Keep(gui)
end

local holder = new("Frame", {
	Name = "Holder",
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
})

local window = new("Frame", {
	Name = "Window",
	Parent = holder,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(CONFIG.BaseSize.X, CONFIG.BaseSize.Y),
	BackgroundColor3 = C.window,
	BorderSizePixel = 0,
})
corner(window, 18)
local winScale = new("UIScale", { Parent = window, Scale = 0.05 })
new("UIGradient", {
	Parent = window,
	Rotation = 90,
	Color = ColorSequence.new(C.windowTop, C.window),
})
local winStroke = stroke(window, WHITE, 2)
local winStrokeGradient = new("UIGradient", {
	Parent = winStroke,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 92, 246)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(62, 52, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 92, 246)),
	}),
})
loopTween(winStrokeGradient, TweenInfo.new(9, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 })

local function fitScale()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return math.min(1, (vs.X - 24) / CONFIG.BaseSize.X, (vs.Y - 24) / CONFIG.BaseSize.Y)
end

local function currentScale()
	return math.max(0.2, fitScale() * settings.UIScale)
end

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------
local logs = {}
local nextId = 0
local paused = false
local held = {}
local blocked = {}
local blockedCount = 0
local blockedGroups = {} -- transient groups linked to a selected error and its stack
local blockKey = tostring((game.GameId ~= 0) and game.GameId or game.PlaceId)

local function loadBlocked()
	if not (isfile and readfile) then
		return
	end
	pcall(function()
		if isfile(CONFIG.BlockedFile) then
			local data = HttpService:JSONDecode(readfile(CONFIG.BlockedFile))
			local mine = type(data) == "table" and data[blockKey] or nil
			if type(mine) == "table" then
				for _, text in ipairs(mine) do
					if type(text) == "string" and not blocked[text] then
						blocked[text] = true
						blockedCount += 1
					end
				end
			end
		end
	end)
end

-- returns true only when the file was really written
local function saveBlocked()
	if not writefile then
		return false
	end
	return (pcall(function()
		local data = {}
		if isfile and readfile and isfile(CONFIG.BlockedFile) then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(readfile(CONFIG.BlockedFile))
			end)
			if ok and type(decoded) == "table" then
				data = decoded
			end
		end
		local texts = {}
		for text in pairs(blocked) do
			texts[#texts + 1] = text
		end
		table.sort(texts)
		data[blockKey] = (#texts > 0) and texts or nil
		writefile(CONFIG.BlockedFile, HttpService:JSONEncode(data))
	end))
end

loadBlocked()
local minimized = false
local unread = 0
local typeFilter = { Print = false, Warning = false, Error = false }
local searchText = ""
local visibleCount = 0

-- forward declarations
local updateStatus, applyFilters, toast, closeMenus, setSelected, updateTopbarBadge

----------------------------------------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------------------------------------
local function makeButton(parent, size, bg, bgHover, strokeColor, radius)
	local b = new("TextButton", {
		Parent = parent,
		Size = size,
		BackgroundColor3 = bg,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
	})
	corner(b, radius or 10)
	local st = strokeColor and stroke(b, strokeColor, 1.2) or nil
	local sc = new("UIScale", { Parent = b })
	bind(b.MouseEnter, function()
		tween(b, 0.15, { BackgroundColor3 = bgHover })
	end)
	bind(b.MouseLeave, function()
		tween(b, 0.15, { BackgroundColor3 = bg })
		tween(sc, 0.12, { Scale = 1 })
	end)
	bind(b.MouseButton1Down, function()
		tween(sc, 0.08, { Scale = 0.95 })
	end)
	bind(b.MouseButton1Up, function()
		tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	return b, st
end

-- icon + text (+ optional trailing icon) centered in a button; returns pieces for later restyling
local function buttonContent(btn, iconName, fallback, text, color, trailingIcon)
	new("UIListLayout", {
		Parent = btn,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local ic = icon(btn, iconName, 20, color, fallback, { LayoutOrder = 1 })
	local txt = label(btn, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = text,
		TextColor3 = color,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
	})
	local chev
	if trailingIcon then
		chev = icon(btn, "chevron-down", 16, color, "v", { LayoutOrder = 3 })
	end
	return ic, txt, chev
end

----------------------------------------------------------------------------------------------------
-- Header
----------------------------------------------------------------------------------------------------
local header = new("Frame", {
	Name = "Header",
	Parent = window,
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundTransparency = 1,
})

local logo = new("Frame", {
	Parent = header,
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = C.purpleBg,
})
corner(logo, 11)
stroke(logo, C.purple, 1.6)
icon(logo, "terminal", 24, C.purpleLight, ">_", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
})

label(header, {
	Position = UDim2.fromOffset(64, 7),
	Size = UDim2.fromOffset(300, 24),
	Text = "Console",
	Font = Enum.Font.GothamBold,
	TextSize = 21,
})
label(header, {
	Position = UDim2.fromOffset(64, 31),
	Size = UDim2.fromOffset(380, 16),
	Text = "View logs, manage output and control the console.",
	TextSize = 12,
	TextColor3 = C.sub,
})

local controls = new("Frame", {
	Parent = header,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0, 28),
	Size = UDim2.fromOffset(0, 36),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
})
new("UIListLayout", {
	Parent = controls,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local badge = new("Frame", {
	Parent = controls,
	LayoutOrder = 1,
	Size = UDim2.fromOffset(92, 32),
	BackgroundColor3 = C.greenBg,
})
corner(badge, 16)
local badgeDot = new("Frame", {
	Parent = badge,
	Position = UDim2.fromOffset(14, 11),
	Size = UDim2.fromOffset(10, 10),
	BackgroundColor3 = C.green,
})
corner(badgeDot, 5)
local badgeText = label(badge, {
	Position = UDim2.fromOffset(32, 0),
	Size = UDim2.new(1, -36, 1, 0),
	Text = "Active",
	TextColor3 = C.green,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
})
local badgePulse = loopTween(
	badgeDot,
	TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ BackgroundTransparency = 0.65 }
)

local function separator(order)
	return new("Frame", {
		Parent = controls,
		LayoutOrder = order,
		Size = UDim2.fromOffset(1, 24),
		BackgroundColor3 = Color3.fromRGB(52, 50, 74),
		BorderSizePixel = 0,
	})
end

local function headerIconButton(order, iconName, fallback)
	local b = makeButton(controls, UDim2.fromOffset(34, 34), C.window, C.btnHover, nil, 9)
	b.LayoutOrder = order
	b.BackgroundTransparency = 1
	local ic = icon(b, iconName, 22, C.sub, fallback, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	bind(b.MouseEnter, function()
		b.BackgroundTransparency = 0
		setIconColor(ic, WHITE)
	end)
	bind(b.MouseLeave, function()
		b.BackgroundTransparency = 1
		setIconColor(ic, C.sub)
	end)
	return b, ic
end

separator(2)
local gearBtn = headerIconButton(3, "settings", "*")
separator(4)
local minBtn = headerIconButton(5, "minus", "-")

----------------------------------------------------------------------------------------------------
-- Dragging (window via header, mini button via itself)
----------------------------------------------------------------------------------------------------
local function makeDraggable(handle, target, onMove, onTap)
	local dragging, moved = false, false
	local startInput, startPoint, startPos
	bind(handle.InputBegan, function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		dragging, moved = true, false
		startInput = input
		startPoint = Vector2.new(input.Position.X, input.Position.Y)
		startPos = target.Position
	end)
	bind(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input ~= startInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - startPoint
		if not moved and delta.Magnitude > 6 then
			moved = true
		end
		if moved then
			onMove(startPos, delta)
		end
	end)
	bind(UserInputService.InputEnded, function(input)
		if not dragging then
			return
		end
		local same = input == startInput
			or (startInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
		if same then
			dragging = false
			if not moved and onTap then
				onTap()
			end
		end
	end)
end

makeDraggable(header, holder, function(startPos, delta)
	holder.Position = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)
end)

----------------------------------------------------------------------------------------------------
-- Main panel: filter chips, search, log list
----------------------------------------------------------------------------------------------------
local panel = new("Frame", {
	Name = "Panel",
	Parent = window,
	Position = UDim2.fromOffset(12, 58),
	Size = UDim2.new(1, -24, 0, 272),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
})
corner(panel, 12)
stroke(panel, C.panelStroke, 1.2)

local chipScroll = new("ScrollingFrame", {
	Parent = panel,
	Position = UDim2.fromOffset(10, 7),
	Size = UDim2.new(1, -178, 0, 32),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	ScrollingDirection = Enum.ScrollingDirection.X,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
})
new("UIListLayout", {
	Parent = chipScroll,
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
})

local chips = {}
local chipDefs = {
	{ "All", "layout-grid", WHITE },
	{ "Print", "info", C.chipText },
	{ "Warning", "triangle-alert", C.amber },
	{ "Error", "circle-alert", C.red },
}

local function filtersActive()
	for _, v in pairs(typeFilter) do
		if v then
			return true
		end
	end
	return searchText ~= ""
end

local function chipIsOn(name)
	if name == "All" then
		for _, v in pairs(typeFilter) do
			if v then
				return false
			end
		end
		return true
	end
	return typeFilter[name] == true
end

local function refreshChips()
	for name, chip in pairs(chips) do
		local on = chipIsOn(name)
		tween(chip.btn, 0.18, { BackgroundColor3 = on and (CHIP_ON[name] or C.purple) or (name == "Error" and C.chipRed or C.chip) })
		tween(chip.label, 0.18, { TextColor3 = on and WHITE or C.chipText })
		setIconColor(chip.icon, on and WHITE or chip.accent)
	end
end

for i, def in ipairs(chipDefs) do
	local name, iconName, accent = def[1], def[2], def[3]
	local btn = makeButton(chipScroll, UDim2.fromOffset(0, 32), C.chip, C.btnHover, nil, 16)
	btn.LayoutOrder = i
	btn.AutomaticSize = Enum.AutomaticSize.X
	padding(btn, 12, 0, 14, 0)
	new("UIListLayout", {
		Parent = btn,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local ic = icon(btn, iconName, 17, accent, nil, { LayoutOrder = 1 })
	local txt = label(btn, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = name,
		TextColor3 = C.chipText,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
	})
	chips[name] = { btn = btn, icon = ic, label = txt, accent = accent }
	bind(btn.Activated, function()
		if name == "All" then
			for k in pairs(typeFilter) do
				typeFilter[k] = false
			end
		else
			typeFilter[name] = not typeFilter[name]
		end
		applyFilters()
	end)
end

local searchBox = new("Frame", {
	Parent = panel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 7),
	Size = UDim2.fromOffset(150, 32),
	BackgroundColor3 = C.chip,
})
corner(searchBox, 16)
local searchStroke = stroke(searchBox, C.panelStroke, 1.2)
icon(searchBox, "search", 17, C.sub, nil, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 11, 0.5, 0),
})
local searchInput = new("TextBox", {
	Parent = searchBox,
	Position = UDim2.fromOffset(34, 0),
	Size = UDim2.new(1, -42, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextColor3 = C.text,
	PlaceholderText = "Search logs...",
	PlaceholderColor3 = C.sub,
	Text = "",
	ClearTextOnFocus = false,
	TextXAlignment = Enum.TextXAlignment.Left,
})
bind(searchInput.Focused, function()
	tween(searchStroke, 0.15, { Color = C.purple })
end)
bind(searchInput.FocusLost, function()
	tween(searchStroke, 0.15, { Color = C.panelStroke })
end)
bind(searchInput:GetPropertyChangedSignal("Text"), function()
	searchText = string.lower(searchInput.Text)
	applyFilters()
end)

new("Frame", {
	Parent = panel,
	Position = UDim2.fromOffset(10, 46),
	Size = UDim2.new(1, -20, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
})

local list = new("ScrollingFrame", {
	Name = "LogList",
	Parent = panel,
	Position = UDim2.fromOffset(6, 50),
	Size = UDim2.new(1, -12, 1, -56),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.purple,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
new("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder })

local emptyLabel = label(panel, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 22),
	Size = UDim2.fromOffset(300, 24),
	Text = "No logs to show",
	TextColor3 = C.dim,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextSize = 15,
})

----------------------------------------------------------------------------------------------------
-- Action bar
----------------------------------------------------------------------------------------------------
local actions = new("Frame", {
	Name = "Actions",
	Parent = window,
	Position = UDim2.fromOffset(12, 338),
	Size = UDim2.new(1, -24, 0, 34),
	BackgroundTransparency = 1,
})
local actionsLeft = new("Frame", {
	Parent = actions,
	Size = UDim2.new(1, -170, 1, 0),
	BackgroundTransparency = 1,
})
new("UIListLayout", {
	Parent = actionsLeft,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local copyBtn = makeButton(actionsLeft, UDim2.fromOffset(142, 34), C.purpleBg, C.purpleBgHover, C.purple, 10)
copyBtn.LayoutOrder = 1
local _, _, copyChev = buttonContent(copyBtn, "copy", "c", "Copy", WHITE, true)

local clearBtn = makeButton(actionsLeft, UDim2.fromOffset(142, 34), C.purpleBg, C.purpleBgHover, C.purple, 10)
clearBtn.LayoutOrder = 2
local _, _, clearChev = buttonContent(clearBtn, "trash", "t", "Clear", WHITE, true)

local pauseBtn = makeButton(actionsLeft, UDim2.fromOffset(112, 34), C.purpleBg, C.purpleBgHover, C.purple, 10)
pauseBtn.LayoutOrder = 3
local pauseIcon, pauseText = buttonContent(pauseBtn, "pause", "||", "Pause", WHITE, false)

local blockBtn = makeButton(actions, UDim2.fromOffset(160, 34), C.redBg, C.redBgHover, Color3.fromRGB(120, 36, 48), 10)
blockBtn.AnchorPoint = Vector2.new(1, 0)
blockBtn.Position = UDim2.fromScale(1, 0)
buttonContent(blockBtn, "ban", "x", "Block Selected", C.red, false)

----------------------------------------------------------------------------------------------------
-- Status bar
----------------------------------------------------------------------------------------------------
local status = new("Frame", {
	Name = "Status",
	Parent = window,
	Position = UDim2.fromOffset(12, 380),
	Size = UDim2.new(1, -24, 0, 22),
	BackgroundTransparency = 1,
})
local statusLeft = new("Frame", {
	Parent = status,
	Size = UDim2.new(1, -120, 1, 0),
	BackgroundTransparency = 1,
})
new("UIListLayout", {
	Parent = statusLeft,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
icon(statusLeft, "info", 18, C.sub, "i", { LayoutOrder = 1 })
local statusText = label(statusLeft, {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, 18),
	AutomaticSize = Enum.AutomaticSize.X,
	Text = "Total: 0 logs",
	TextColor3 = C.sub,
	TextSize = 14,
})

local function tinyButton(order, text)
	local b = new("TextButton", {
		Parent = statusLeft,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = C.purpleLight,
	})
	bind(b.MouseEnter, function()
		tween(b, 0.12, { TextColor3 = WHITE })
	end)
	bind(b.MouseLeave, function()
		tween(b, 0.12, { TextColor3 = C.purpleLight })
	end)
	return b
end
local selectVisibleBtn = tinyButton(3, "Select visible")
local deselectBtn = tinyButton(4, "Deselect")

local versionBadge = new("Frame", {
	Parent = status,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),	Size = UDim2.fromOffset(0, 22),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C.btn,
})
corner(versionBadge, 11)
stroke(versionBadge, C.panelStroke, 1)
padding(versionBadge, 8, 0, 10, 0)
new("UIListLayout", {
	Parent = versionBadge,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
})
icon(versionBadge, "crown", 15, C.purpleLight, nil, { LayoutOrder = 1 })
label(versionBadge, {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, 16),
	AutomaticSize = Enum.AutomaticSize.X,
	Text = "Console " .. CONFIG.Version,
	TextColor3 = C.sub,
	TextSize = 12,
})

----------------------------------------------------------------------------------------------------
-- Toast
----------------------------------------------------------------------------------------------------
local toastFrame = new("Frame", {
	Name = "Toast",
	Parent = window,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, 340),
	Size = UDim2.fromOffset(0, 32),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C.purpleBg,
	BackgroundTransparency = 1,
	Visible = false,
})
corner(toastFrame, 16)
local toastStroke = stroke(toastFrame, C.purple, 1.4, 1)
padding(toastFrame, 16, 0, 16, 0)
local toastText = label(toastFrame, {
	Size = UDim2.fromOffset(0, 32),
	AutomaticSize = Enum.AutomaticSize.X,
	Text = "",
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	TextTransparency = 1,
})
local toastToken = 0

function toast(text, kind)
	if destroyed then
		return
	end
	toastToken += 1
	local token = toastToken
	local col = C.purple
	local bg = C.purpleBg
	if kind == "error" then
		col, bg = C.red, C.redBg
	elseif kind == "warn" then
		col, bg = C.amber, C.amberBg
	end
	toastText.Text = text
	toastFrame.BackgroundColor3 = bg
	toastStroke.Color = col
	toastFrame.Visible = true
	toastFrame.Position = UDim2.new(0.5, 0, 0, 350)
	tween(toastFrame, 0.25, { Position = UDim2.new(0.5, 0, 0, 340), BackgroundTransparency = 0.05 }, Enum.EasingStyle.Back)
	tween(toastStroke, 0.25, { Transparency = 0 })
	tween(toastText, 0.25, { TextTransparency = 0 })
	task.delay(1.8, function()
		if destroyed or token ~= toastToken then
			return
		end
		tween(toastFrame, 0.25, { BackgroundTransparency = 1 })
		tween(toastStroke, 0.25, { Transparency = 1 })
		tween(toastText, 0.25, { TextTransparency = 1 })
		task.delay(0.26, function()
			if not destroyed and token == toastToken then
				toastFrame.Visible = false
			end
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- Log rows
----------------------------------------------------------------------------------------------------
local function passes(e)
	local typeOn = false
	for _, v in pairs(typeFilter) do
		if v then
			typeOn = true
		end
	end
	if typeOn and not typeFilter[e.kind] then
		return false
	end
	if searchText ~= "" and not string.find(e.lower, searchText, 1, true) then
		return false
	end
	return true
end

local function relayoutRow(e)
	local ui = e.ui
	local x = 40
	ui.time.Visible = settings.Timestamps
	if settings.Timestamps then
		ui.time.Position = UDim2.fromOffset(40, 0)
		x = 124
	end
	ui.pill.Position = UDim2.fromOffset(x, 4)
	x += 94
	ui.msg.Position = UDim2.fromOffset(x, 0)
	ui.msg.Size = UDim2.new(1, -(x + 92), 0, 0)
end

function setSelected(e, value)
	e.selected = value
	local ui = e.ui
	if not ui then
		return
	end
	tween(ui.box, 0.15, { BackgroundColor3 = value and C.purple or C.panel })
	ui.boxStroke.Color = value and C.purple or C.dim
	ui.check.Visible = value
	tween(ui.sel, 0.15, { BackgroundTransparency = value and 0.8 or 1 })
end

local function buildRow(e)
	local color = KIND_COLOR[e.kind]
	local accent = KIND_ACCENT[e.kind]
	local row = new("Frame", {
		Name = "Row",
		Parent = list,
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = accent,
		BackgroundTransparency = KIND_TINT[e.kind],
		BorderSizePixel = 0,
		LayoutOrder = e.id,
	})
	e.row = row

	local tap = new("TextButton", {
		Parent = row,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	local sel = new("Frame", {
		Parent = row,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.purple,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	local flash = new("Frame", {
		Parent = row,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	new("Frame", {
		Name = "Accent",
		Parent = row,
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	})

	local box = new("Frame", {
		Parent = row,
		Position = UDim2.fromOffset(14, 5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = C.panel,
	})
	corner(box, 5)
	local boxStroke = stroke(box, C.dim, 1.4)
	local check = icon(box, "check", 14, WHITE, "v", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Visible = false,
	})

	local timeLabel = label(row, {
		Size = UDim2.fromOffset(80, 28),
		Text = "[" .. e.time .. "]",
		Font = Enum.Font.Code,
		TextSize = 14,
		TextColor3 = C.dim,
	})

	local pill = new("Frame", {
		Parent = row,
		Size = UDim2.fromOffset(86, 20),
		BackgroundColor3 = KIND_PILL_BG[e.kind],
	})
	corner(pill, 6)
	stroke(pill, accent, 1, 0.55)
	new("UIListLayout", {
		Parent = pill,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	icon(pill, KIND_ICON[e.kind], 14, accent, nil, { LayoutOrder = 1 })
	label(pill, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = e.kind,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local shown = e.text
	if #shown > CONFIG.MaxDisplayChars then
		shown = string.sub(shown, 1, CONFIG.MaxDisplayChars) .. "…"
	end
	local msg = label(row, {
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = shown,
		Font = Enum.Font.Code,
		TextSize = 14,
		TextColor3 = color,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = false,
	})
	padding(msg, 0, 6, 0, 7)

	local style = SOURCE_STYLE[e.source]
	local tagPill = new("Frame", {
		Parent = row,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 4),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = style.bg,
	})
	corner(tagPill, 6)
	padding(tagPill, 8, 0, 9, 0)
	new("UIListLayout", {
		Parent = tagPill,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	icon(tagPill, style.icon, 13, style.color, nil, { LayoutOrder = 1 })
	label(tagPill, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = e.source,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = style.color,
	})

	new("Frame", {
		Parent = row,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.line,
		BorderSizePixel = 0,
	})

	e.ui = { box = box, boxStroke = boxStroke, check = check, time = timeLabel, pill = pill, msg = msg, sel = sel }
	relayoutRow(e)

	bind(tap.Activated, function()
		setSelected(e, not e.selected)
		updateStatus()
	end)

	if settings.FlashNew then
		flash.BackgroundTransparency = 0.6
		tween(flash, 0.8, { BackgroundTransparency = 1 })
	end
end

function updateStatus()
	if destroyed then
		return
	end
	local selected = 0
	for _, e in ipairs(logs) do
		if e.selected then
			selected += 1
		end
	end
	local txt = string.format("Total: %d logs  •  Selected: %d", #logs, selected)
	if filtersActive() then
		txt ..= string.format("  •  Showing: %d", visibleCount)
	end
	statusText.Text = txt
	emptyLabel.Visible = visibleCount == 0
end

function applyFilters()
	visibleCount = 0
	for _, e in ipairs(logs) do
		local ok = passes(e)
		e.visible = ok
		if e.row then
			e.row.Visible = ok
		end
		if ok then
			visibleCount += 1
		end
	end
	refreshChips()
	updateStatus()
end

local function removeWhere(pred)
	local n = 0
	for i = #logs, 1, -1 do
		local e = logs[i]
		if pred(e) then
			if e.row then
				e.row:Destroy()
			end
			table.remove(logs, i)
			n += 1
		end
	end
	applyFilters()
	return n
end

local function trimLogs()
	-- Keep the configured total limit, but evict Game rows before Script rows.
	-- Source filters are visual only; hidden Game traffic must not erase diagnostics.
	while #logs > settings.MaxLogs do
		local removeIndex
		for i, entry in ipairs(logs) do
			if entry.source == "Game" then
				removeIndex = i
				break
			end
		end
		removeIndex = removeIndex or 1
		local old = table.remove(logs, removeIndex)
		if old.visible then
			visibleCount = math.max(0, visibleCount - 1)
		end
		if old.row then
			old.row:Destroy()
		end
	end
end

local scrollTicks = 0
local function commit(item)
	if blocked[item.text] or (item.groupId and blockedGroups[item.groupId]) then
		return
	end
	nextId += 1
	local e = {
		id = nextId,
		time = item.time,
		kind = item.kind,
		text = item.text,
		lower = string.lower(item.text),
		source = item.source,
		groupId = item.groupId,
		selected = false,
	}
	e.visible = passes(e)
	logs[#logs + 1] = e
	buildRow(e)
	e.row.Visible = e.visible
	if e.visible then
		visibleCount += 1
	end
	trimLogs()
	if minimized then
		unread += 1
	end
	if updateTopbarBadge then updateTopbarBadge() end
end

----------------------------------------------------------------------------------------------------
-- Source tagging (executor print/warn/error wrappers) + LogService capture
----------------------------------------------------------------------------------------------------
local origPrint = env.print or print
local origWarn = env.warn or warn
local origError = env.error or error
local hadOwnPrint = rawget(env, "print") ~= nil
local hadOwnWarn = rawget(env, "warn") ~= nil
local hadOwnError = rawget(env, "error") ~= nil

local pending = {}

local function joinArgs(...)
	local parts = table.pack(...)
	local out = table.create(parts.n)
	for i = 1, parts.n do
		out[i] = tostring(parts[i])
	end
	return table.concat(out, " ")
end

local function tagScript(kind, ...)
	pending[#pending + 1] = { kind = kind, text = joinArgs(...), at = os.clock() }
	if #pending > 400 then
		table.remove(pending, 1)
	end
end

local function claimScript(kind, text)
	local now = os.clock()
	for i = #pending, 1, -1 do
		if now - pending[i].at > CONFIG.PendingTtl then
			table.remove(pending, i)
		end
	end
	for i, p in ipairs(pending) do
		if p.kind == kind then
			local hit
			if p.text == "" then
				hit = text == ""
			else
				hit = string.find(text, p.text, 1, true) ~= nil
			end
			if hit then
				table.remove(pending, i)
				return true
			end
		end
	end
	return false
end

local function wrappedPrint(...)
	pcall(tagScript, "Print", ...)
	return origPrint(...)
end
local function wrappedWarn(...)
	pcall(tagScript, "Warning", ...)
	return origWarn(...)
end
local function wrappedError(message, level)
	pcall(tagScript, "Error", message)
	return origError(message, level)
end

pcall(function()
	env.print = wrappedPrint
	env.warn = wrappedWarn
	env.error = wrappedError
end)

local KIND_BY_TYPE = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Print",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

local inbox = {}
local inboxHead = 1

local nextGroupId = 0
local activeErrorGroup = nil
local swallowStack = false
bind(LogService.MessageOut, function(message, messageType)
	local kind = KIND_BY_TYPE[messageType] or "Print"
	local isStackLine = messageType == Enum.MessageType.MessageInfo
		and (message == "Stack Begin" or message == "Stack End" or string.find(message, "^Script '") ~= nil)

	-- Error rows and their following stack lines share a transient group ID.
	-- This lets Block Selected purge stack lines already queued in inbox/held.
	if kind == "Error" then
		nextGroupId += 1
		activeErrorGroup = nextGroupId
		if blocked[message] then
			swallowStack = true
			return
		end
	elseif isStackLine and activeErrorGroup then
		if swallowStack then
			if message == "Stack End" then
				swallowStack = false
				activeErrorGroup = nil
			end
			return
		end
	else
		activeErrorGroup = nil
		swallowStack = false
	end

	local groupId = isStackLine and activeErrorGroup or (kind == "Error" and activeErrorGroup or nil)
	local source = claimScript(kind, message) and "Script" or "Game"
	inbox[#inbox + 1] = {
		text = message,
		kind = kind,
		source = source,
		time = os.date("%H:%M:%S"),
		groupId = groupId,
	}
	if isStackLine and message == "Stack End" then
		activeErrorGroup = nil
	end
end)

bind(RunService.Heartbeat, function()
	if scrollTicks > 0 then
		scrollTicks -= 1
		if scrollTicks == 0 then
			list.CanvasPosition = Vector2.new(0, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y))
		end
	end
	if inboxHead > #inbox then
		if updateTopbarBadge then updateTopbarBadge() end
		return
	end
	local atBottom = list.CanvasPosition.Y + list.AbsoluteWindowSize.Y >= list.AbsoluteCanvasSize.Y - 40
	local processed = 0
	while inboxHead <= #inbox and processed < CONFIG.FlushPerFrame do
		local item = inbox[inboxHead]
		inbox[inboxHead] = false
		inboxHead += 1
		processed += 1
		if item then
			if paused then
				held[#held + 1] = item
				if #held > settings.MaxLogs then
					table.remove(held, 1)
				end
			else
				commit(item)
			end
		end
	end
	if inboxHead > #inbox then
		table.clear(inbox)
		inboxHead = 1
	end
	updateStatus()
	if settings.AutoScroll and atBottom then
		scrollTicks = 2
	end
	if updateTopbarBadge then updateTopbarBadge() end
end)

----------------------------------------------------------------------------------------------------
-- Copy / Clear / Block / Pause logic
----------------------------------------------------------------------------------------------------
local function formatEntry(e)
	return string.format("[%s] [%s] %s", e.time, e.kind, e.text)
end

local function copyWhere(pred, noun)
	local lines, n = {}, 0
	for _, e in ipairs(logs) do
		if pred(e) then
			n += 1
			lines[n] = formatEntry(e)
		end
	end
	if n == 0 then
		toast("Nothing to copy", "warn")
		return
	end
	local setClip = setclipboard or toclipboard or (syn and syn.write_clipboard) or (Clipboard and Clipboard.set)
	if not setClip then
		toast("Clipboard not supported by this executor", "error")
		return
	end
	local ok = pcall(setClip, table.concat(lines, "\n"))
	if ok then
		toast(string.format("Copied %d %s", n, noun))
	else
		toast("Copy failed", "error")
	end
end

local function clearWhere(pred, noun)
	local n = removeWhere(pred)
	if n == 0 then
		toast("Nothing to clear", "warn")
	else
		toast(string.format("Cleared %d %s", n, noun))
	end
end

local function kindIs(kind)
	return function(e)
		return e.kind == kind
	end
end
local function everything()
	return true
end
local function isSelected(e)
	return e.selected
end

local blockedLabelRefresh = function() end

local function isBlockedItem(item)
	return item and (blocked[item.text] or (item.groupId and blockedGroups[item.groupId]))
end

local function purgeBlockedQueues()
	for i = #held, 1, -1 do
		if isBlockedItem(held[i]) then
			table.remove(held, i)
		end
	end
	for i = inboxHead, #inbox do
		if isBlockedItem(inbox[i]) then
			inbox[i] = false
		end
	end
end

local function blockSelected()
	local texts, n = {}, 0
	for _, e in ipairs(logs) do
		if e.selected and not blocked[e.text] then
			blocked[e.text] = true
			blockedCount += 1
			n += 1
			texts[e.text] = true
			if e.kind == "Error" and e.groupId then
				blockedGroups[e.groupId] = true
			end
		end
	end
	if n == 0 then
		local anySel = false
		for _, e in ipairs(logs) do
			anySel = anySel or e.selected
		end
		toast(anySel and "Already blocked" or "Select logs first", "warn")
		return
	end
	removeWhere(function(e)
		return blocked[e.text] == true or (e.groupId and blockedGroups[e.groupId])
	end)
	purgeBlockedQueues()
	blockedLabelRefresh()
	local saved = saveBlocked()
	toast(
		string.format("Blocked %d message%s%s", n, n == 1 and "" or "s", saved and "" or " (not saved to file)"),
		saved and nil or "warn"
	)
end

local function setPaused(value)
	paused = value
	if paused then
		badgePulse:Cancel()
		badgeDot.BackgroundTransparency = 0
		tween(badge, 0.2, { BackgroundColor3 = C.amberBg })
		tween(badgeDot, 0.2, { BackgroundColor3 = C.amber })
		badgeText.Text = "Paused"
		tween(badgeText, 0.2, { TextColor3 = C.amber })
		pauseText.Text = "Resume"
		pauseIcon.Name = "Icon_play"
		iconRegistry[pauseIcon] = "play"
		applyIcon(pauseIcon, "play")
		toast("Paused — new logs are held", "warn")
	else
		tween(badge, 0.2, { BackgroundColor3 = C.greenBg })
		tween(badgeDot, 0.2, { BackgroundColor3 = C.green })
		badgeText.Text = "Active"
		tween(badgeText, 0.2, { TextColor3 = C.green })
		badgePulse:Play()
		pauseText.Text = "Pause"
		iconRegistry[pauseIcon] = "pause"
		applyIcon(pauseIcon, "pause")
		local atBottom = list.CanvasPosition.Y + list.AbsoluteWindowSize.Y >= list.AbsoluteCanvasSize.Y - 40
		local n = #held
		for i = 1, n do
			commit(held[i])
		end
		table.clear(held)
		updateStatus()
		applyFilters()
		if settings.AutoScroll and atBottom then
			scrollTicks = 2
		end
		toast(n > 0 and string.format("Resumed — %d held logs added", n) or "Resumed")
	end
end

bind(pauseBtn.Activated, function()
	setPaused(not paused)
end)
bind(blockBtn.Activated, blockSelected)
bind(selectVisibleBtn.Activated, function()
	for _, e in ipairs(logs) do
		if e.visible then
			setSelected(e, true)
		end
	end
	updateStatus()
end)
bind(deselectBtn.Activated, function()
	for _, e in ipairs(logs) do
		if e.selected then
			setSelected(e, false)
		end
	end
	updateStatus()
end)

----------------------------------------------------------------------------------------------------
-- Dropdown menus
----------------------------------------------------------------------------------------------------
local catcher = new("TextButton", {
	Name = "MenuCatcher",
	Parent = window,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 55,
})

local openMenu
local menus = {}

local function makeMenu(anchor, chev, items)
	-- parented to the window, NOT the button: the button owns a UIListLayout that would
	-- otherwise treat the menu as a layout item (overlapping the label and pushing the chevron out)
	local menu = new("Frame", {
		Parent = window,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(12, 330),
		Size = UDim2.fromOffset(210, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(22, 20, 38),
		Visible = false,
	})
	corner(menu, 12)
	stroke(menu, C.purple, 1.4)
	padding(menu, 6, 6, 6, 6)
	new("UIListLayout", { Parent = menu, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	local sc = new("UIScale", { Parent = menu, Scale = 0.9 })

	for i, item in ipairs(items) do
		if item.separator then
			new("Frame", {
				Parent = menu,
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = C.line,
				BorderSizePixel = 0,
			})
		else
			local b = new("TextButton", {
				Parent = menu,
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = C.btnHover,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
			})
			corner(b, 8)
			icon(b, item.icon, 18, item.color or C.chipText, nil, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
			})
			label(b, {
				Position = UDim2.fromOffset(38, 0),
				Size = UDim2.new(1, -44, 1, 0),
				Text = item.text,
				Font = Enum.Font.GothamMedium,
				TextSize = 14,
				TextColor3 = C.text,
			})
			bind(b.MouseEnter, function()
				tween(b, 0.12, { BackgroundTransparency = 0.2 })
			end)
			bind(b.MouseLeave, function()
				tween(b, 0.12, { BackgroundTransparency = 1 })
			end)
			bind(b.Activated, function()
				closeMenus()
				item.fn()
			end)
		end
	end
	setZ(menu, 60)
	local entry = { frame = menu, scale = sc, anchor = anchor, chev = chev }
	menus[#menus + 1] = entry
	return entry
end

function closeMenus()
	if not catcher.Visible then
		return
	end
	catcher.Visible = false
	for _, m in ipairs(menus) do
		if m.chev then
			tween(m.chev, 0.2, { Rotation = 0 })
		end
		if m.frame.Visible then
			local frame = m.frame
			tween(m.scale, 0.12, { Scale = 0.9 })
			task.delay(0.12, function()
				if not destroyed and not catcher.Visible then
					frame.Visible = false
				end
			end)
		end
	end
end

function openMenu(entry)
	if entry.frame.Visible and catcher.Visible then
		closeMenus()
		return
	end
	for _, m in ipairs(menus) do
		if m ~= entry then
			m.frame.Visible = false
			if m.chev then
				tween(m.chev, 0.2, { Rotation = 0 })
			end
		end
	end
	local rel = (entry.anchor.AbsolutePosition - window.AbsolutePosition) / math.max(winScale.Scale, 0.01)
	entry.frame.Position = UDim2.fromOffset(rel.X, rel.Y - 8)
	catcher.Visible = true
	entry.scale.Scale = 0.9
	entry.frame.Visible = true
	tween(entry.scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	if entry.chev then
		tween(entry.chev, 0.2, { Rotation = 180 })
	end
end

bind(catcher.Activated, closeMenus)

local copyMenu = makeMenu(copyBtn, copyChev, {
	{ text = "Copy All", icon = "copy", fn = function() copyWhere(everything, "logs") end },
	{ text = "Copy Selected", icon = "copy-check", fn = function() copyWhere(isSelected, "selected logs") end },
	{ separator = true },
	{ text = "Copy Prints", icon = "info", fn = function() copyWhere(kindIs("Print"), "prints") end },
	{ text = "Copy Warnings", icon = "triangle-alert", color = C.amber, fn = function() copyWhere(kindIs("Warning"), "warnings") end },
	{ text = "Copy Errors", icon = "circle-alert", color = C.red, fn = function() copyWhere(kindIs("Error"), "errors") end },
})
local clearMenu = makeMenu(clearBtn, clearChev, {
	{ text = "Clear All", icon = "trash", fn = function() clearWhere(everything, "logs") end },
	{ text = "Clear Selected", icon = "trash", fn = function() clearWhere(isSelected, "selected logs") end },
	{ separator = true },
	{ text = "Clear Prints", icon = "info", fn = function() clearWhere(kindIs("Print"), "prints") end },
	{ text = "Clear Warnings", icon = "triangle-alert", color = C.amber, fn = function() clearWhere(kindIs("Warning"), "warnings") end },
	{ text = "Clear Errors", icon = "circle-alert", color = C.red, fn = function() clearWhere(kindIs("Error"), "errors") end },
})
bind(copyBtn.Activated, function()
	openMenu(copyMenu)
end)
bind(clearBtn.Activated, function()
	openMenu(clearMenu)
end)

----------------------------------------------------------------------------------------------------
-- Settings panel
----------------------------------------------------------------------------------------------------
local SETTINGS_Y = 58
local settingsPanel = new("Frame", {
	Name = "Settings",
	Parent = window,
	Position = UDim2.fromOffset(12, SETTINGS_Y),
	Size = UDim2.new(1, -24, 0, 314),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Active = true,
	Visible = false,
})
corner(settingsPanel, 12)
stroke(settingsPanel, C.panelStroke, 1.2)

local backBtn = makeButton(settingsPanel, UDim2.fromOffset(32, 32), C.btn, C.btnHover, nil, 9)
backBtn.Position = UDim2.fromOffset(10, 8)
icon(backBtn, "arrow-left", 20, C.text, "<", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
})
label(settingsPanel, {
	Position = UDim2.fromOffset(52, 8),
	Size = UDim2.fromOffset(300, 20),
	Text = "Settings",
	Font = Enum.Font.GothamBold,
	TextSize = 18,
})
label(settingsPanel, {
	Position = UDim2.fromOffset(52, 28),
	Size = UDim2.fromOffset(400, 14),
	Text = "Changes apply instantly and are saved when the executor supports files.",
	TextSize = 11,
	TextColor3 = C.sub,
})
new("Frame", {
	Parent = settingsPanel,
	Position = UDim2.fromOffset(10, 48),
	Size = UDim2.new(1, -20, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
})

local settingsList = new("ScrollingFrame", {
	Parent = settingsPanel,
	Position = UDim2.fromOffset(8, 54),
	Size = UDim2.new(1, -16, 1, -60),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.purple,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
new("UIListLayout", { Parent = settingsList, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
padding(settingsList, 0, 2, 6, 6)

local settingOrder = 0
local function settingCard(height, title, desc)
	settingOrder += 1
	local card = new("Frame", {
		Parent = settingsList,
		LayoutOrder = settingOrder,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = C.chip,
	})
	corner(card, 10)
	stroke(card, C.panelStroke, 1)
	label(card, {
		Position = UDim2.fromOffset(14, 9),
		Size = UDim2.new(1, -200, 0, 18),
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
	})
	if desc then
		label(card, {
			Position = UDim2.fromOffset(14, 29),
			Size = UDim2.new(1, -150, 0, 14),
			Text = desc,
			TextSize = 11,
			TextColor3 = C.sub,
		})
	end
	return card
end

local function makeToggle(card, init, onChange)
	local on = init
	local sw = new("TextButton", {
		Parent = card,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(44, 24),
		BackgroundColor3 = on and C.purple or C.track,
		AutoButtonColor = false,
		Text = "",
	})
	corner(sw, 12)
	local knob = new("Frame", {
		Parent = sw,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = on and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),		BackgroundColor3 = WHITE,
	})
	corner(knob, 10)
	bind(sw.Activated, function()
		on = not on
		tween(sw, 0.18, { BackgroundColor3 = on and C.purple or C.track })
		tween(knob, 0.22, { Position = on and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }, Enum.EasingStyle.Back)
		onChange(on)
	end)
end

local function makeSlider(card, min, max, step, init, format, onChange, onRelease)
	local value = init
	local valueLabel = label(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 9),
		Size = UDim2.fromOffset(80, 18),
		Text = format(init),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.purpleLight,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	})
	local track = new("Frame", {
		Parent = card,
		Position = UDim2.new(0, 14, 0, 50),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = C.track,
		BorderSizePixel = 0,
	})
	corner(track, 3)
	local fill = new("Frame", {
		Parent = track,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.purple,
		BorderSizePixel = 0,
	})
	corner(fill, 3)
	local knob = new("Frame", {
		Parent = track,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	})
	corner(knob, 9)
	stroke(knob, C.purple, 2.5)
	local hit = new("TextButton", {
		Parent = track,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 20, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
	})
	local function render(v)
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		valueLabel.Text = format(v)
	end
	render(value)

	local dragging, startInput = false, nil
	local function setFromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = math.floor((min + a * (max - min)) / step + 0.5) * step
		v = tonumber(string.format("%.3f", math.clamp(v, min, max)))
		if v ~= value then
			value = v
			render(v)
			onChange(v)
		end
	end
	bind(hit.InputBegan, function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		dragging, startInput = true, input
		settingsList.ScrollingEnabled = false
		tween(knob, 0.12, { Size = UDim2.fromOffset(22, 22) }, Enum.EasingStyle.Back)
		setFromX(input.Position.X)
	end)
	bind(UserInputService.InputChanged, function(input)
		if dragging and (input == startInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
			setFromX(input.Position.X)
		end
	end)
	bind(UserInputService.InputEnded, function(input)
		if dragging and (input == startInput or (startInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
			dragging = false
			settingsList.ScrollingEnabled = true
			tween(knob, 0.15, { Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Back)
			saveSettings()
			if onRelease then
				onRelease()
			end
		end
	end)
end

do
	local card = settingCard(66, "UI Scale", nil)
	makeSlider(card, 0.5, 1.5, 0.05, settings.UIScale, function(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end, function(v)
		settings.UIScale = v
		if not minimized then
			winScale.Scale = currentScale()
		end
	end)
end
do
	local card = settingCard(66, "Max stored logs", "100 to 10000. High values can lag.")
	makeSlider(card, 100, 10000, 100, settings.MaxLogs, function(v)
		return tostring(math.floor(v))
	end, function(v)
		settings.MaxLogs = math.floor(v)
	end, function()
		trimLogs()
		applyFilters()
	end)
end
do
	local card = settingCard(54, "Auto-scroll", "Follow new logs while you are at the bottom of the list.")
	makeToggle(card, settings.AutoScroll, function(v)
		settings.AutoScroll = v
		saveSettings()
	end)
end
do
	local card = settingCard(54, "Show timestamps", "Show the [HH:MM:SS] column in every row.")
	makeToggle(card, settings.Timestamps, function(v)
		settings.Timestamps = v
		for _, e in ipairs(logs) do
			relayoutRow(e)
		end
		saveSettings()
	end)
end
do
	local card = settingCard(54, "Flash new logs", "Short highlight on rows when they arrive.")
	makeToggle(card, settings.FlashNew, function(v)
		settings.FlashNew = v
		saveSettings()
	end)
end
local blockedPanel = new("Frame", {
	Name = "BlockedPanel",
	Parent = window,
	Position = UDim2.fromOffset(12, SETTINGS_Y),
	Size = UDim2.new(1, -24, 0, 314),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Active = true,
	Visible = false,
})
corner(blockedPanel, 12)
stroke(blockedPanel, C.panelStroke, 1.2)
local blockedBack = makeButton(blockedPanel, UDim2.fromOffset(32, 32), C.btn, C.btnHover, nil, 9)
blockedBack.Position = UDim2.fromOffset(10, 8)
icon(blockedBack, "arrow-left", 20, C.text, "<", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
})
label(blockedPanel, {
	Position = UDim2.fromOffset(52, 8),
	Size = UDim2.fromOffset(300, 20),
	Text = "Blocked messages",
	Font = Enum.Font.GothamBold,
	TextSize = 18,
})
local blockedSub = label(blockedPanel, {
	Position = UDim2.fromOffset(52, 28),
	Size = UDim2.new(1, -180, 0, 14),
	Text = "",
	TextSize = 11,
	TextColor3 = C.sub,
})
local unblockAllBtn = makeButton(blockedPanel, UDim2.fromOffset(110, 32), C.redBg, C.redBgHover, Color3.fromRGB(120, 36, 48), 9)
unblockAllBtn.AnchorPoint = Vector2.new(1, 0)
unblockAllBtn.Position = UDim2.new(1, -10, 0, 8)
label(unblockAllBtn, {
	Size = UDim2.fromScale(1, 1),
	Text = "Unblock all",
	TextColor3 = C.red,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Center,
})
new("Frame", {
	Parent = blockedPanel,
	Position = UDim2.fromOffset(10, 48),
	Size = UDim2.new(1, -20, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
})
local blockedList = new("ScrollingFrame", {
	Parent = blockedPanel,
	Position = UDim2.fromOffset(8, 54),
	Size = UDim2.new(1, -16, 1, -60),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.purple,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
new("UIListLayout", { Parent = blockedList, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
padding(blockedList, 0, 2, 6, 6)
local blockedEmpty = label(blockedPanel, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(300, 24),
	Text = "Nothing blocked in this game",
	TextColor3 = C.dim,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextSize = 15,
})
setZ(blockedPanel, 30)

local function refreshBlockedList()
	for _, child in ipairs(blockedList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local texts = {}
	for text in pairs(blocked) do
		texts[#texts + 1] = text
	end
	table.sort(texts)
	blockedEmpty.Visible = #texts == 0
	blockedSub.Text = string.format(
		"%d blocked in this game — %s",
		#texts,
		writefile and "kept after rejoin until you unblock" or "this executor has no writefile, so not kept after rejoin"
	)
	for i, text in ipairs(texts) do
		local row = new("Frame", {
			Parent = blockedList,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = C.chip,
		})
		corner(row, 9)
		stroke(row, C.panelStroke, 1)
		label(row, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -112, 1, 0),
			Text = (string.gsub(text, "%s+", " ")),
			Font = Enum.Font.Code,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = C.chipText,
		})
		local ub = makeButton(row, UDim2.fromOffset(84, 28), C.purpleBg, C.purpleBgHover, C.purple, 8)
		ub.AnchorPoint = Vector2.new(1, 0.5)
		ub.Position = UDim2.new(1, -8, 0.5, 0)
		label(ub, {
			Size = UDim2.fromScale(1, 1),
			Text = "Unblock",
			TextColor3 = WHITE,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		setZ(row, 31)
		bind(ub.Activated, function()
			if blocked[text] then
				blocked[text] = nil
				blockedCount -= 1
			end
			local saved = saveBlocked()
			blockedLabelRefresh()
			refreshBlockedList()
			toast(saved and "Unblocked" or "Unblocked (not saved to file)", saved and nil or "warn")
		end)
	end
end

local blockedOpen = false
local function showBlockedPanel(open)
	if open == blockedOpen then
		return
	end
	blockedOpen = open
	if open then
		refreshBlockedList()
		blockedPanel.Position = UDim2.fromOffset(12, SETTINGS_Y + 18)
		blockedPanel.Visible = true
		tween(blockedPanel, 0.3, { Position = UDim2.fromOffset(12, SETTINGS_Y) }, Enum.EasingStyle.Back)
	else
		tween(blockedPanel, 0.18, { Position = UDim2.fromOffset(12, SETTINGS_Y + 18) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.18, function()
			if not destroyed and not blockedOpen then
				blockedPanel.Visible = false
			end
		end)
	end
end
bind(blockedBack.Activated, function()
	showBlockedPanel(false)
end)
bind(unblockAllBtn.Activated, function()
	blocked = {}
	blockedCount = 0
	local saved = saveBlocked()
	blockedLabelRefresh()
	refreshBlockedList()
	toast(saved and "Blocklist cleared" or "Cleared (not saved to file)", saved and nil or "warn")
end)

do
	local card = settingCard(54, "Blocked messages", "0 blocked")
	local desc
	for _, child in ipairs(card:GetChildren()) do
		if child:IsA("TextLabel") and child.TextSize == 11 then
			desc = child
		end
	end
	blockedLabelRefresh = function()
		if desc then
			desc.Text = string.format("%d blocked in this game (exact text match)", blockedCount)
		end
	end
	blockedLabelRefresh()
	local manage = makeButton(card, UDim2.fromOffset(84, 30), C.purpleBg, C.purpleBgHover, C.purple, 9)
	manage.AnchorPoint = Vector2.new(1, 0.5)
	manage.Position = UDim2.new(1, -14, 0.5, 0)
	label(manage, {
		Size = UDim2.fromScale(1, 1),
		Text = "Manage",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	bind(manage.Activated, function()
		showBlockedPanel(true)
	end)
end

setZ(settingsPanel, 20)

local settingsOpen = false
local function showSettings(open)
	if open == settingsOpen then
		return
	end
	settingsOpen = open
	closeMenus()
	if not open then
		showBlockedPanel(false)
	end
	if open then
		settingsPanel.Position = UDim2.fromOffset(12, SETTINGS_Y + 18)
		settingsPanel.Visible = true
		tween(settingsPanel, 0.3, { Position = UDim2.fromOffset(12, SETTINGS_Y) }, Enum.EasingStyle.Back)
	else
		tween(settingsPanel, 0.18, { Position = UDim2.fromOffset(12, SETTINGS_Y + 18) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.18, function()
			if not destroyed and not settingsOpen then
				settingsPanel.Visible = false
			end
		end)
	end
end
bind(gearBtn.Activated, function()
	showSettings(not settingsOpen)
end)
bind(backBtn.Activated, function()
	showSettings(false)
end)

setZ(toastFrame, 70)

----------------------------------------------------------------------------------------------------
-- Hide / show through the JustXLibrary topbar
----------------------------------------------------------------------------------------------------
local openWindow, minimizeWindow
local topbarButton = Addon.TopbarButton({
	Text = ">_",
	Callback = function()
		if minimized then openWindow() else minimizeWindow() end
	end,
})
Addon.Keep(topbarButton)
local topbarBadge = new("Frame", {
	Name = "UnreadBadge", Parent = topbarButton, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 5, 0, -5), Size = UDim2.fromOffset(0, 16),
	AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.red,
	BorderSizePixel = 0, Visible = false, ZIndex = 90,
})
corner(topbarBadge, 8)
padding(topbarBadge, 5, 0, 5, 0)
local topbarBadgeText = label(topbarBadge, {
	Name = "Count", Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
	Text = "0", TextColor3 = WHITE, Font = Enum.Font.GothamBold,
	TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 91,
})
updateTopbarBadge = function()
	local show = minimized and unread > 0 and not destroyed
	topbarBadge.Visible = show
	if show then topbarBadgeText.Text = unread > 99 and "99+" or tostring(unread) end
end
openWindow = function()
	minimized = false
	unread = 0
	updateTopbarBadge()
	window.Visible = true
	winScale.Scale = 0.05
	tween(winScale, 0.4, { Scale = currentScale() }, Enum.EasingStyle.Back)
end
minimizeWindow = function()
	if minimized then return end
	minimized = true
	closeMenus()
	tween(winScale, 0.22, { Scale = 0.05 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	task.delay(0.22, function()
		if minimized and not destroyed then window.Visible = false end
	end)
	updateTopbarBadge()
end
-- The minus button hides the window without unloading the addon.
bind(minBtn.Activated, minimizeWindow)

----------------------------------------------------------------------------------------------------
-- Destroy / lifecycle
----------------------------------------------------------------------------------------------------
local function destroy()
	if destroyed then
		return
	end
	destroyed = true
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	for _, tw in ipairs(loopTweens) do
		pcall(function()
			tw:Cancel()
		end)
	end
	pcall(function()
		if env.print == wrappedPrint then
			env.print = hadOwnPrint and origPrint or nil
		end
		if env.warn == wrappedWarn then
			env.warn = hadOwnWarn and origWarn or nil
		end
		if env.error == wrappedError then
			env.error = hadOwnError and origError or nil
		end
	end)
	table.clear(logs)
	table.clear(inbox)
	table.clear(held)
	table.clear(pending)
	if gui then
		gui:Destroy()
	end
end

Addon.OnUnload(destroy)

pcall(function()
	local cam = workspace.CurrentCamera
	if cam then
		bind(cam:GetPropertyChangedSignal("ViewportSize"), function()
			if not minimized then
				tween(winScale, 0.2, { Scale = currentScale() })
			end
		end)
	end
end)

applyFilters()
updateTopbarBadge()
tween(winScale, 0.45, { Scale = currentScale() }, Enum.EasingStyle.Back)
    end,
}
