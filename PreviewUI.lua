--[[
	PreviewUI 4.0  (full remake, adaptive PC / phone layout)

	local Preview = JL:Preview({ Title = "JustX Preview", Subtitle = "Advanced development tools",
		Icon = "box", TabName = "Preview", Key = Enum.KeyCode.P, OnOpen = fn, OnClose = fn })

	Preview:Open(target)  Preview:Close()  Preview:Toggle(target)  Preview:IsOpen()  Preview:SetTitle(t)
	Preview:OnClosed(fn)  Preview:CloseDrawer()  Preview:Destroy()
	  target: nil | "TabName" | Tab | Asset | { Tab = "Models", Asset = "Tree", Page = "info" }

	-- asset categories (chips) and assets
	local Models = Preview:Tab({ Name = "Models", Icon = "box", ShowAll = false, Filter = function(asset) end })
	local Tree = Models:Asset({ Name, Type, Creator, Created, Size, Version, Description, Tags = {},
		Info = { { Label, Value, Icon } }, Model = instance | Build = function(model) end | Image = "rbxassetid://..",
		Callback = function(asset) end, Actions = { { Name, Icon, Callback(asset) } } })   -- max 5 actions
	Models:Assets({ {...}, {...} })  Tree:Select()  Tree:Update(patch)  Tree:Remove()  Models:Clear()  Models:Open()  Models:Remove()

	-- detail pages (tabs next to Preview / Info). Build returns an optional cleanup function.
	Preview:Page({ Name, Icon, Visible = function(asset) end, Build = function(parent, asset, pv) end })
	Preview:RemovePage(page)

	-- controls: on Preview (every asset), a Tab (assets of that tab) or an Asset (that asset only)
	X:Button({ Name, Icon, Callback })  X:Toggle({ Name, Default, Flag, Callback(v) })
	X:Dropdown({ Name, Options, MultiSelect, MaxSelect, Default, Flag, Callback(v) })
	X:ColorPicker({ Name, Default, Flag, Callback(color) })  X:Slider({ Name, Min, Max, Step, Default, Suffix, Flag, Callback(v) })
	X:Textbox({ Name, Placeholder, Default, Flag, Callback(text) })  X:Label({ Text })  X:Divider({ Label })
	control:Get()  control:Set(v, silent)  control:Remove()

	-- new in 4.0
	Preview:QuickAction({ Name, Icon, Callback }) -> { Remove }     Home screen shortcut
	Preview:SetPluginOpen(pluginId, fn | nil)                        what a plugin card's "Open" does
	Preview:GetPluginUI()  Preview:CreateIcon(parent, name, size, color)  Preview:RegisterPreviewExtension(id, build)
	Preview:GetPlugins() / InstallPlugin / EnablePlugin / DisablePlugin / UninstallPlugin

	Removed from 3.x: Source (Discover / ObserveModels / LiveMotion), SetGrouping, SetSort, asset variants, Header.
]]

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")

local GB, GM, G = Enum.Font.GothamBold, Enum.Font.GothamMedium, Enum.Font.Gotham
local V2, U2, rgb = Vector2.new, UDim2.new, Color3.fromRGB
local QUINT, QUART, OUT = Enum.EasingStyle.Quint, Enum.EasingStyle.Quart, Enum.EasingDirection.Out
local AUTO_Y, AUTO_X = Enum.AutomaticSize.Y, Enum.AutomaticSize.X

local DEFAULT_PLUGIN_BASE = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/"
local MAX_ACTIONS = 5
local BP_WIDE, BP_MID = 860, 560

local B, C, ACCENTS, T -- bridge, bridge colors, accents, resolved theme

local M = {}
M.__index = M
M.Version = "4.1"

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

local function stroke(inst, col, th, transparency)
	return new("UIStroke", {
		Color = col, Thickness = th or 1, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, inst)
end

local function pad(inst, l, r, t, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r),
		PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
	}, inst)
end

local function listLayout(parent, gap, horizontal)
	return new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, gap or 0),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
	}, parent)
end

local function txt(class, props, parent)
	local base = {
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = G, TextColor3 = T.txt,
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

-- While dragging a slider inside a ScrollingFrame the panel must not scroll.
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

local function cleanLabel(value)
	local s = tostring(value or "")
	s = s:gsub("%[%]", ""):gsub("%s%s+", " ")
	return s:match("^%s*(.-)%s*$") or s
end

local function snapNum(v, min, max, step)
	v = math.clamp(v, min, max)
	if step and step > 0 then
		v = math.floor((v - min) / step + 0.5) * step + min
		v = math.clamp(v, min, max)
	end
	return tonumber(string.format("%.6g", v)) or v
end

local FALLBACK_GLYPHS = {
	pin = "⌖", layers = "▱", filter = "▽", ["list-filter"] = "☷", ["sliders-horizontal"] = "☷",
	["chevron-down"] = "⌄", network = "⌘", box = "▣", info = "ⓘ", play = "▶", pause = "Ⅱ",
	["maximize-2"] = "⤢", ["minimize-2"] = "⤡", crosshair = "⊕", image = "▧", shapes = "⬡",
	palette = "◉", clapperboard = "▤", ["volume-2"] = "♫", sparkles = "✦", ["user-round"] = "◉",
	search = "⌕", ["chevron-right"] = "›", ["chevron-left"] = "‹", x = "×", check = "✓", plus = "+",
	settings = "⚙", ["more-horizontal"] = "•••", ["external-link"] = "↗", copy = "▢", refresh = "↻",
	trash = "⌫", house = "⌂", home = "⌂", blocks = "▦", ["layout-grid"] = "▦", list = "☰",
	["arrow-left"] = "‹", ["rotate-3d"] = "⟳", scan = "▢", download = "↓", power = "⏻", tag = "#",
	calendar = "▤", ["hard-drive"] = "▭", ["git-branch"] = "⑂", user = "◉", ["folder-tree"] = "⌘",
	zap = "ϟ", ["more-vertical"] = "⋮", ellipsis = "•••", eye = "◉", ["eye-off"] = "◌", crosshair = "⊕",
	["sliders-horizontal"] = "☰", expand = "⤢", ["chevrons-down"] = "⇊", ["chevrons-up"] = "⇈", ["square-stack"] = "▤",
	folder = "▤", code = "‹›", rewind = "◂◂", ["fast-forward"] = "▸▸", square = "■", ["repeat"] = "⟲", layers = "▱", paintbrush = "✎", ["chart-bar"] = "▥", lightbulb = "☀", cuboid = "▣", bone = "⌇", scissors = "✂",
}

local ICON_ALIASES = {
	house = { "home", "layout-dashboard" }, ["layout-grid"] = { "grid", "grid-2x2", "layout" },
	["more-horizontal"] = { "ellipsis", "more" }, ["more-vertical"] = { "ellipsis-vertical" },
	refresh = { "refresh-cw", "rotate-cw" }, trash = { "trash-2" }, ["rotate-3d"] = { "rotate-ccw", "refresh-cw" },
	scan = { "focus", "scan-line", "crosshair" }, ["arrow-left"] = { "chevron-left" }, download = { "arrow-down-to-line" },
	power = { "power-off" }, blocks = { "puzzle", "box" }, ["user-round"] = { "user" }, ["hard-drive"] = { "database" },
	["git-branch"] = { "tag" }, ["maximize-2"] = { "maximize", "expand" }, ["minimize-2"] = { "minimize", "shrink" },
	list = { "list-ordered", "menu" }, ["folder-tree"] = { "folder", "network" }, ["eye-off"] = { "eye-closed" },
}
local ICON_STATS = { ok = 0, missing = {} }

local function resolveIcon(name)
	if not (B and B.icon) then
		return nil
	end
	local tries = { name }
	for _, alias in ipairs(ICON_ALIASES[name] or {}) do
		tries[#tries + 1] = alias
	end
	for _, n in ipairs(tries) do
		local ok, value = pcall(B.icon, n)
		if ok and value ~= nil then
			if not ICON_STATS.seen then ICON_STATS.seen = {} end
			if not ICON_STATS.seen[name] then
				ICON_STATS.seen[name] = true
				ICON_STATS.ok = ICON_STATS.ok + 1
			end
			return value
		end
	end
	ICON_STATS.missing[name] = true
	return nil
end

local function mkIcon(parent, icon, size, color)
	local raw = icon
	local resolved = type(raw) == "table" and raw or nil
	if type(raw) == "string" then
		local value = resolveIcon(raw)
		if value ~= nil then
			resolved = value
		end
	end
	local url, glyph, font, fontFace, rectOffset, rectSize
	if type(resolved) == "table" then
		url = resolved.Url or resolved.Image or resolved.ImageUrl or resolved.Texture or resolved.Asset
			or resolved.AssetId or resolved.ImageId or resolved.Id
		glyph = resolved.Text or resolved.Glyph
		font = resolved.Font
		fontFace = resolved.FontFace
		rectOffset = resolved.ImageRectOffset
		rectSize = resolved.ImageRectSize
	elseif type(resolved) == "string" or type(resolved) == "number" then
		local rv = tostring(resolved)
		if rv:match("^%d+$") or rv:match("^rbxassetid://") or rv:match("^rbxasset://") or rv:match("^https?://") then
			url = rv
		elseif rv ~= tostring(raw or "") then
			glyph = rv
		end
	end
	local value = tostring(url or "")
	if value:match("^%d+$") then
		value = "rbxassetid://" .. value
	end
	if value:match("^rbxassetid://") or value:match("^rbxasset://") or value:match("^https?://") then
		return new("ImageLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
			Image = value, ImageColor3 = color, ScaleType = Enum.ScaleType.Fit,
			ImageRectOffset = typeof(rectOffset) == "Vector2" and rectOffset or Vector2.zero,
			ImageRectSize = typeof(rectSize) == "Vector2" and rectSize or Vector2.zero,
		}, parent)
	end
	local textValue = glyph
	if type(textValue) ~= "string" or textValue == "" or textValue == "[]" or textValue == "□" then
		textValue = FALLBACK_GLYPHS[type(raw) == "string" and raw or ""] or (type(raw) == "string" and raw or "")
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
	if not ic or not ic.Parent then
		return
	end
	if ic:IsA("TextLabel") then
		tw(ic, { TextColor3 = col }, 0.18)
	else
		tw(ic, { ImageColor3 = col }, 0.18)
	end
end

local function centerIcon(parent, name, size, color)
	local ic = mkIcon(parent, name, size, color)
	ic.AnchorPoint = V2(0.5, 0.5)
	ic.Position = U2(0.5, 0, 0.5, 0)
	return ic
end

-- Overlay children need explicit ZIndex when the host ScreenGui uses ZIndexBehavior.Global.
local function zAll(root, z)
	root.ZIndex = z
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = z
		end
	end
end

--------------------------------------------------------------------
-- theme (derived from the JustLib bridge palette, rebuilt on theme change)
--------------------------------------------------------------------
local function loadTheme()
	local function pick(key, fallback)
		local v = C and C[key]
		if typeof(v) == "Color3" then
			return v
		end
		return fallback
	end
	local accent = (ACCENTS and typeof(ACCENTS[1]) == "Color3") and ACCENTS[1] or rgb(139, 92, 246)
	local panel = pick("panel", rgb(22, 23, 36))
	T = {
		accent = accent,
		panel = panel,
		bg = panel:Lerp(Color3.new(0, 0, 0), 0.3),
		card = panel:Lerp(accent, 0.07),
		cardHi = panel:Lerp(accent, 0.18),
		input = pick("input", panel:Lerp(Color3.new(1, 1, 1), 0.05)),
		border = pick("border", rgb(52, 54, 80)),
		txt = pick("txt", rgb(238, 240, 252)),
		dim = pick("dim", rgb(142, 147, 176)),
		togOn = pick("togOn", accent),
		togOff = pick("togOff", rgb(52, 54, 78)),
		slTrack = pick("slTrack", rgb(44, 46, 68)),
		good = rgb(74, 214, 124),
		warn = rgb(255, 184, 77),
	}
end

--------------------------------------------------------------------
-- small widgets
--------------------------------------------------------------------
local function mkSwitch(parent, pos, state)
	local track = new("Frame", {
		Position = pos, Size = UDim2.fromOffset(40, 22), BorderSizePixel = 0,
		BackgroundColor3 = state and T.togOn or T.togOff,
	}, parent)
	corner(track, 11)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		Position = state and U2(1, -19, 0.5, -8) or U2(0, 3, 0.5, -8),
	}, track)
	corner(knob, 8)
	local sw = {}
	function sw.Set(v)
		tw(track, { BackgroundColor3 = v and T.togOn or T.togOff }, 0.16)
		tw(knob, { Position = v and U2(1, -19, 0.5, -8) or U2(0, 3, 0.5, -8) }, 0.2, QUINT)
	end
	return sw
end

local function mkSlider(parent, pos, size, min, max, step, value, onChange)
	local track = new("Frame", { Position = pos, Size = size, BackgroundColor3 = T.slTrack, BorderSizePixel = 0 }, parent)
	corner(track, 3)
	local fill = new("Frame", { Size = U2(0, 0, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0 }, track)
	corner(fill, 3)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(16, 16), AnchorPoint = V2(0.5, 0.5), Position = U2(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	corner(knob, 8)
	local hit = new("TextButton", {
		Text = "", BackgroundTransparency = 1, Size = U2(1, 0, 0, 30), Position = U2(0, 0, 0.5, -15),
	}, track)
	local function show(v)
		local a = 0
		if max > min then
			a = math.clamp((v - min) / (max - min), 0, 1)
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

-- o: Text, Icon, Primary, Size, Position, Order, Height, Callback
local function mkButton(parent, o)
	local base = o.Primary and T.accent or T.card
	local b = txt("TextButton", {
		BackgroundTransparency = 0, BackgroundColor3 = base, Text = "", ClipsDescendants = true,
		Size = o.Size or U2(1, 0, 0, o.Height or 40), Position = o.Position or U2(0, 0, 0, 0),
		LayoutOrder = o.Order or 0,
	}, parent)
	corner(b, 10)
	if not o.Primary then
		stroke(b, T.border, 1)
	end
	local fg = o.Primary and Color3.new(1, 1, 1) or T.txt
	local ic
	if o.Icon then
		ic = mkIcon(b, o.Icon, 16, o.Primary and fg or T.accent)
		ic.AnchorPoint, ic.Position = V2(0, 0.5), U2(0, 12, 0.5, 0)
	end
	local label = txt("TextLabel", {
		Text = o.Text or "", Font = GM, TextSize = 13, TextColor3 = fg, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(o.Icon and 34 or 8, 0), Size = U2(1, o.Icon and -42 or -16, 1, 0),
		TextXAlignment = o.Icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
	}, b)
	local hover = o.Primary and base:Lerp(Color3.new(1, 1, 1), 0.12) or T.cardHi
	b.MouseEnter:Connect(function()
		if not touchLast() then
			tw(b, { BackgroundColor3 = hover }, 0.12)
		end
	end)
	b.MouseLeave:Connect(function()
		tw(b, { BackgroundColor3 = base }, 0.12)
	end)
	b.Activated:Connect(function()
		safe(o.Callback)
	end)
	return b, label, ic
end

local function mkIconButton(parent, icon, size, onClick, bg)
	local b = txt("TextButton", {
		BackgroundTransparency = bg and 0.15 or 0, BackgroundColor3 = bg or T.card, Text = "",
		Size = UDim2.fromOffset(size, size),
	}, parent)
	corner(b, 10)
	stroke(b, T.border, 1, 0.3)
	local ic = centerIcon(b, icon, math.floor(size * 0.5), T.txt)
	b.MouseEnter:Connect(function()
		if not touchLast() then
			tw(b, { BackgroundColor3 = T.cardHi }, 0.12)
		end
	end)
	b.MouseLeave:Connect(function()
		tw(b, { BackgroundColor3 = bg or T.card }, 0.12)
	end)
	b.Activated:Connect(function()
		safe(onClick)
	end)
	return b, ic
end

local function badge(parent, text, color, pos)
	local f = new("Frame", {
		BackgroundColor3 = color, BackgroundTransparency = 0.82, BorderSizePixel = 0, ClipsDescendants = true,
		AutomaticSize = AUTO_X, Size = U2(0, 0, 0, 20), Position = pos or U2(0, 0, 0, 0),
	}, parent)
	new("UISizeConstraint", { MaxSize = Vector2.new(150, 20) }, f)
	corner(f, 10)
	pad(f, 8, 8, 0, 0)
	txt("TextLabel", {
		Text = text, Font = GM, TextSize = 11, TextColor3 = color, AutomaticSize = AUTO_X,
		Size = U2(0, 0, 1, 0),
	}, f)
	return f
end

--------------------------------------------------------------------
-- controls (Button / Toggle / Dropdown / ColorPicker / Slider / Input / Label / Divider)
--------------------------------------------------------------------
local function initVal(o, default)
	if not o.Flag then
		return default, false
	end
	local v = B.cfgGet(o.Flag, default)
	local has = B.cfgHas and B.cfgHas(o.Flag) or false
	return v, has
end

local STATEFUL = { Toggle = true, Dropdown = true, ColorPicker = true, Slider = true, Input = true, Label = true }

local function makeControl(owner, kind, o)
	o = o or {}
	local def = { kind = kind, o = o, owner = owner }
	local default
	if kind == "Toggle" then
		default = o.Default == true
	elseif kind == "Slider" then
		default = tonumber(o.Default) or tonumber(o.Min) or 0
	elseif kind == "ColorPicker" then
		default = typeof(o.Default) == "Color3" and o.Default or Color3.new(1, 1, 1)
	elseif kind == "Input" then
		default = tostring(o.Default or "")
	elseif kind == "Label" then
		default = tostring(o.Text or o.Name or "")
	elseif kind == "Dropdown" then
		if o.MultiSelect then
			default = type(o.Default) == "table" and o.Default or (o.Default ~= nil and { o.Default } or {})
		else
			default = o.Default
			if default == nil and type(o.Options) == "table" then
				default = o.Options[1]
			end
		end
	end
	def.value = default
	if o.Flag and STATEFUL[kind] and kind ~= "Label" then
		local v, has = initVal(o, default)
		if has and v ~= nil then
			def.value = v
			def.restored = true
		end
	end
	if kind == "Slider" then
		def.value = snapNum(tonumber(def.value) or default, o.Min or 0, o.Max or 100, o.Step)
	end

	function def:Get()
		return self.value
	end
	function def:Set(v, silent)
		if kind == "Slider" then
			v = snapNum(tonumber(v) or self.value, o.Min or 0, o.Max or 100, o.Step)
		end
		self.value = v
		if o.Flag and kind ~= "Label" then
			B.cfgSet(o.Flag, v)
		end
		if self._refresh then
			self._refresh()
		end
		if not silent then
			safe(o.Callback, v)
		end
	end
	function def:Remove()
		for i, d in ipairs(owner._controls) do
			if d == self then
				table.remove(owner._controls, i)
				break
			end
		end
		self._refresh = nil
		owner._pv:_ctrlChanged()
	end

	table.insert(owner._controls, def)
	owner._pv:_ctrlChanged()
	if def.restored then
		safe(o.Callback, def.value)
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
M.Textbox = function(selfObj, o)
	return makeControl(selfObj, "Input", o)
end

local function rowBase(parent, order, h)
	local r = new("Frame", {
		BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = order, Size = U2(1, 0, 0, h), ClipsDescendants = true,
	}, parent)
	corner(r, 10)
	stroke(r, T.border, 1, 0.35)
	return r
end

local function fmtNum(v)
	if math.abs(v - math.floor(v)) < 1e-6 then
		return tostring(math.floor(v))
	end
	return string.format("%.2f", v)
end

local function renderControl(parent, def, order)
	local o, kind = def.o, def.kind
	local name = tostring(o.Name or kind)

	if kind == "Divider" then
		local r = new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = U2(1, 0, 0, 24) }, parent)
		local hasLabel = o.Label and o.Label ~= ""
		if hasLabel then
			txt("TextLabel", {
				Text = tostring(o.Label), Font = GB, TextSize = 11, TextColor3 = T.dim, AutomaticSize = AUTO_X,
				Size = U2(0, 0, 1, 0),
			}, r)
		end
		new("Frame", {
			BackgroundColor3 = T.border, BorderSizePixel = 0, AnchorPoint = V2(1, 0.5),
			Position = U2(1, 0, 0.5, 0), Size = U2(hasLabel and 0.62 or 1, 0, 0, 1),
		}, r)
		return r
	end

	if kind == "Label" then
		local r = new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = U2(1, 0, 0, 0), AutomaticSize = AUTO_Y }, parent)
		local lb = txt("TextLabel", {
			Text = tostring(def.value or ""), TextSize = 12, TextColor3 = T.dim, TextWrapped = true,
			AutomaticSize = AUTO_Y, Size = U2(1, -8, 0, 0), Position = UDim2.fromOffset(4, 0),
		}, r)
		def._refresh = function()
			if lb.Parent then lb.Text = tostring(def.value or "") end
		end
		return r
	end

	if kind == "Button" then
		local b = mkButton(parent, {
			Text = name, Icon = o.Icon, Order = order, Height = 42,
			Callback = function() safe(o.Callback, def) end,
		})
		return b
	end

	if kind == "Toggle" then
		local r = rowBase(parent, order, 44)
		txt("TextLabel", {
			Text = name, Font = GM, TextSize = 13, Position = UDim2.fromOffset(14, 0), Size = U2(1, -76, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, r)
		local sw = mkSwitch(r, U2(1, -54, 0.5, -11), def.value == true)
		local hit = txt("TextButton", { Size = U2(1, 0, 1, 0) }, r)
		hit.Activated:Connect(function()
			def:Set(not def.value)
		end)
		def._refresh = function()
			if r.Parent then sw.Set(def.value == true) end
		end
		return r
	end

	if kind == "Slider" then
		local min, max = o.Min or 0, o.Max or 100
		local r = rowBase(parent, order, 60)
		txt("TextLabel", {
			Text = name, Font = GM, TextSize = 13, Position = UDim2.fromOffset(14, 8), Size = U2(1, -110, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, r)
		local valueLabel = txt("TextLabel", {
			Font = GM, TextSize = 12, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = V2(1, 0), Position = U2(1, -14, 0, 8), Size = UDim2.fromOffset(90, 18),
		}, r)
		local function text()
			valueLabel.Text = fmtNum(def.value) .. tostring(o.Suffix or "")
		end
		local slider = mkSlider(r, U2(0, 14, 0, 42), U2(1, -28, 0, 6), min, max, o.Step, def.value, function(v)
			def:Set(v)
		end)
		text()
		def._refresh = function()
			if r.Parent then
				text()
				slider.Set(def.value)
			end
		end
		return r
	end

	if kind == "Input" then
		local r = rowBase(parent, order, 48)
		txt("TextLabel", {
			Text = name, Font = GM, TextSize = 13, Position = UDim2.fromOffset(14, 0), Size = U2(0.38, -14, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, r)
		local boxFrame = new("Frame", {
			BackgroundColor3 = T.input, BorderSizePixel = 0, AnchorPoint = V2(1, 0.5),
			Position = U2(1, -10, 0.5, 0), Size = U2(0.62, -14, 0, 32),
		}, r)
		corner(boxFrame, 8)
		stroke(boxFrame, T.border, 1, 0.3)
		local box = txt("TextBox", {
			Text = tostring(def.value or ""), PlaceholderText = tostring(o.Placeholder or ""), PlaceholderColor3 = T.dim,
			ClearTextOnFocus = false, TextSize = 12, Position = UDim2.fromOffset(10, 0), Size = U2(1, -20, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, boxFrame)
		box.FocusLost:Connect(function()
			def:Set(box.Text)
		end)
		def._refresh = function()
			if box.Parent and not box:IsFocused() then box.Text = tostring(def.value or "") end
		end
		return r
	end

	-- expandable rows: Dropdown and ColorPicker
	local r = new("Frame", {
		BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = order, Size = U2(1, 0, 0, 44), AutomaticSize = AUTO_Y,
		ClipsDescendants = true,
	}, parent)
	corner(r, 10)
	stroke(r, T.border, 1, 0.35)
	listLayout(r, 0)
	local head = txt("TextButton", { Size = U2(1, 0, 0, 44), LayoutOrder = 1 }, r)
	txt("TextLabel", {
		Text = name, Font = GM, TextSize = 13, Position = UDim2.fromOffset(14, 0), Size = U2(0.5, -14, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, head)
	local chevron = txt("TextLabel", {
		Text = "⌄", Font = GB, TextSize = 16, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = V2(1, 0.5), Position = U2(1, -8, 0.5, 0), Size = UDim2.fromOffset(22, 22),
	}, head)
	local body = new("Frame", {
		BackgroundTransparency = 1, Size = U2(1, 0, 0, 0), AutomaticSize = AUTO_Y, Visible = false, LayoutOrder = 2,
	}, r)
	listLayout(body, 4)
	pad(body, 8, 8, 0, 8)
	local open = false
	head.Activated:Connect(function()
		open = not open
		body.Visible = open
		chevron.Text = open and "⌃" or "⌄"
	end)

	if kind == "Dropdown" then
		local multi = o.MultiSelect == true
		local options = type(o.Options) == "table" and o.Options or {}
		local valueLabel = txt("TextLabel", {
			Font = GM, TextSize = 12, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = V2(1, 0), Position = U2(1, -34, 0, 0), Size = U2(0.5, -40, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
		}, head)
		local buttons = {}
		local function selected(opt)
			if multi then
				return type(def.value) == "table" and table.find(def.value, opt) ~= nil
			end
			return def.value == opt
		end
		local function paint()
			if multi then
				local names = {}
				for _, v in ipairs(type(def.value) == "table" and def.value or {}) do
					names[#names + 1] = cleanLabel(v)
				end
				valueLabel.Text = #names > 0 and table.concat(names, ", ") or "None"
			else
				valueLabel.Text = cleanLabel(def.value)
			end
			for opt, bt in pairs(buttons) do
				local on = selected(opt)
				bt.BackgroundColor3 = on and T.cardHi or T.input
				bt.TextColor3 = on and T.txt or T.dim
			end
		end
		for i, opt in ipairs(options) do
			local bt = txt("TextButton", {
				BackgroundTransparency = 0, BackgroundColor3 = T.input, Text = cleanLabel(opt), Font = GM, TextSize = 12,
				Size = U2(1, 0, 0, 38), LayoutOrder = i, TextTruncate = Enum.TextTruncate.AtEnd,
			}, body)
			corner(bt, 8)
			pad(bt, 12, 8, 0, 0)
			buttons[opt] = bt
			bt.Activated:Connect(function()
				if multi then
					local list = {}
					for _, v in ipairs(type(def.value) == "table" and def.value or {}) do
						list[#list + 1] = v
					end
					local at = table.find(list, opt)
					if at then
						table.remove(list, at)
					elseif not o.MaxSelect or #list < o.MaxSelect then
						list[#list + 1] = opt
					end
					def:Set(list)
				else
					def:Set(opt)
					open = false
					body.Visible = false
					chevron.Text = "⌄"
				end
			end)
		end
		paint()
		def._refresh = function()
			if r.Parent then paint() end
		end
		return r
	end

	-- ColorPicker
	local swatch = new("Frame", {
		BackgroundColor3 = def.value, BorderSizePixel = 0, AnchorPoint = V2(1, 0.5),
		Position = U2(1, -38, 0.5, 0), Size = UDim2.fromOffset(34, 22),
	}, head)
	corner(swatch, 6)
	stroke(swatch, T.border, 1)
	local hv, sv, vv = def.value:ToHSV()
	local sliders = {}
	local function push()
		def:Set(Color3.fromHSV(hv, sv, vv))
	end
	local labels = { "Hue", "Saturation", "Brightness" }
	for i = 1, 3 do
		local line = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 34), LayoutOrder = i }, body)
		txt("TextLabel", {
			Text = labels[i], TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(78, 34),
		}, line)
		local start = (i == 1 and hv) or (i == 2 and sv) or vv
		sliders[i] = mkSlider(line, UDim2.fromOffset(88, 14), U2(1, -104, 0, 6), 0, 1, 0.001, start, function(v)
			if i == 1 then hv = v elseif i == 2 then sv = v else vv = v end
			push()
		end)
	end
	def._refresh = function()
		if not r.Parent then return end
		swatch.BackgroundColor3 = def.value
		local c, cur = def.value, Color3.fromHSV(hv, sv, vv)
		if math.abs(c.R - cur.R) + math.abs(c.G - cur.G) + math.abs(c.B - cur.B) > 0.01 then
			hv, sv, vv = c:ToHSV()
			sliders[1].Set(hv)
			sliders[2].Set(sv)
			sliders[3].Set(vv)
		end
	end
	return r
end

local function renderControls(parent, defs, pair)
	local order, i = 0, 1
	local function small(d)
		return d and (d.kind == "Toggle" or d.kind == "Button")
	end
	while i <= #defs do
		local d, nxt = defs[i], defs[i + 1]
		order = order + 1
		if pair and small(d) and small(nxt) then
			local rowF = new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = U2(1, 0, 0, 44) }, parent)
			local a = new("Frame", { BackgroundTransparency = 1, Size = U2(0.5, -3, 1, 0) }, rowF)
			local b = new("Frame", { BackgroundTransparency = 1, Position = U2(0.5, 3, 0, 0), Size = U2(0.5, -3, 1, 0) }, rowF)
			renderControl(a, d, 1)
			renderControl(b, nxt, 1)
			i = i + 2
		else
			renderControl(parent, d, order)
			i = i + 1
		end
	end
end

--------------------------------------------------------------------
-- 3D stage (used for card thumbnails and the large viewport)
--------------------------------------------------------------------
local VIEW = {
	fov = 40, ambient = rgb(165, 165, 182), light = Color3.new(1, 1, 1),
	lightDir = Vector3.new(-1, -1.2, -0.8), ground = true,
}
local VIEW_LISTENERS = {}

local function hasPreview(a)
	return typeof(a.Model) == "Instance" or type(a.Build) == "function" or a.Image ~= nil
end

local function cloneSource(src)
	local saved = {}
	local function allow(inst)
		local ok, old = pcall(function() return inst.Archivable end)
		if ok then
			saved[#saved + 1] = { inst, old }
			pcall(function() inst.Archivable = true end)
		end
	end
	allow(src)
	for _, d in ipairs(src:GetDescendants()) do
		allow(d)
	end
	local ok, c = pcall(function() return src:Clone() end)
	for _, s in ipairs(saved) do
		pcall(function() s[1].Archivable = s[2] end)
	end
	if not ok then
		return nil
	end
	return c
end

local function rootPartOf(model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				return d
			end
		end
	end
	return root
end

-- o.Model replaces asset.Model as the source; o.Rig anchors only the root so animations can move the rest.
local function makeModel(asset, o)
	o = o or {}
	local model
	local source = o.Model or asset.Model
	if typeof(source) == "Instance" then
		local c = cloneSource(source)
		if not c then
			return nil
		end
		if c:IsA("BasePart") then
			local wrap = Instance.new("Model")
			c.Parent = wrap
			c = wrap
		end
		if not c:IsA("Model") then
			c:Destroy()
			return nil
		end
		model = c
	elseif type(asset.Build) == "function" then
		model = Instance.new("Model")
		local ok, err = pcall(asset.Build, model)
		if not ok then
			warn("[PreviewUI] Build failed: " .. tostring(err))
		end
	else
		return nil
	end
	local root = o.Rig and rootPartOf(model) or nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = (not o.Rig) or d == root
			d.CanCollide = false
		elseif d:IsA("Humanoid") then
			pcall(function() d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
		end
	end
	return model
end

local function buildStage(vp, asset, withGround, o)
	local model = makeModel(asset, o)
	if not model then
		return nil
	end
	local world = Instance.new("WorldModel")
	world.Parent = vp
	model.Parent = world
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.Magnitude * 0.5, 0.5)
	if withGround then
		local d = radius * 2.4
		new("Part", {
			Name = "PreviewGround", Anchored = true, CanCollide = false, Material = Enum.Material.SmoothPlastic,
			Color = T.panel:Lerp(T.accent, 0.25), Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, d, d),
			Transparency = VIEW.ground and 0 or 1,
			CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 - 0.08, cf.Position.Z) * CFrame.Angles(0, 0, math.rad(90)),
		}, world)
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = VIEW.fov
	cam.Parent = vp
	vp.CurrentCamera = cam
	local dist = radius / math.sin(math.rad(cam.FieldOfView * 0.5)) * 1.08
	return { model = model, world = world, cam = cam, center = cf.Position, baseCenter = cf.Position, radius = radius, dist = dist }
end

local function aimCamera(st, yaw, pitch, dist)
	local off = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)) * dist
	st.cam.CFrame = CFrame.lookAt(st.center + off, st.center)
end

local function styleViewport(vp)
	vp.BackgroundTransparency = 1
	vp.Ambient = VIEW.ambient
	vp.LightColor = VIEW.light
	vp.LightDirection = VIEW.lightDir
end

local function cloneSource(src)
	local saved = {}
	local function allow(inst)
		local ok, old = pcall(function() return inst.Archivable end)
		if ok then
			saved[#saved + 1] = { inst, old }
			pcall(function() inst.Archivable = true end)
		end
	end
	allow(src)
	for _, d in ipairs(src:GetDescendants()) do
		allow(d)
	end
	local ok, c = pcall(function() return src:Clone() end)
	for _, s in ipairs(saved) do
		pcall(function() s[1].Archivable = s[2] end)
	end
	if not ok then
		return nil
	end
	return c
end

local function makeModel(asset)
	local model
	if typeof(asset.Model) == "Instance" then
		local c = cloneSource(asset.Model)
		if not c then
			return nil
		end
		if c:IsA("BasePart") then
			local wrap = Instance.new("Model")
			c.Parent = wrap
			c = wrap
		end
		if not c:IsA("Model") then
			c:Destroy()
			return nil
		end
		model = c
	elseif type(asset.Build) == "function" then
		model = Instance.new("Model")
		local ok, err = pcall(asset.Build, model)
		if not ok then
			warn("[PreviewUI] Build failed: " .. tostring(err))
		end
	else
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("Humanoid") then
			pcall(function() d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
		end
	end
	return model
end

local function buildStage(vp, asset, withGround)
	local model = makeModel(asset)
	if not model then
		return nil
	end
	local world = Instance.new("WorldModel")
	world.Parent = vp
	model.Parent = world
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.Magnitude * 0.5, 0.5)
	if withGround then
		local d = radius * 2.4
		new("Part", {
			Anchored = true, CanCollide = false, Material = Enum.Material.SmoothPlastic,
			Color = T.panel:Lerp(T.accent, 0.25), Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, d, d),
			CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 - 0.08, cf.Position.Z) * CFrame.Angles(0, 0, math.rad(90)),
		}, world)
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	local dist = radius / math.sin(math.rad(cam.FieldOfView * 0.5)) * 1.08
	return { model = model, world = world, cam = cam, center = cf.Position, radius = radius, dist = dist }
end

local function aimCamera(st, yaw, pitch, dist)
	local off = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)) * dist
	st.cam.CFrame = CFrame.lookAt(st.center + off, st.center)
end

local function styleViewport(vp)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(165, 165, 182)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1.2, -0.8)
end

--------------------------------------------------------------------
-- matching
--------------------------------------------------------------------
local function matchQuery(a, q)
	q = (q or ""):lower()
	if q == "" then
		return true
	end
	local hay = { tostring(a.Name or ""), tostring(a.Type or ""), tostring(a.Creator or "") }
	if type(a.Tags) == "table" then
		for _, t in ipairs(a.Tags) do
			hay[#hay + 1] = tostring(t)
		end
	end
	for _, h in ipairs(hay) do
		if h:lower():find(q, 1, true) then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------
-- construction
--------------------------------------------------------------------
function M.new(bridge, opts)
	B, C, ACCENTS = bridge, bridge.C, bridge.ACCENTS
	loadTheme()
	opts = opts or {}
	if B.loadIconPack and (not B.hasIconPack or not B.hasIconPack()) then
		pcall(B.loadIconPack)
	end
	local self = setmetatable({}, M)
	self._pv = self
	self.alive = true
	self.Title = opts.Title or "Preview"
	self.Icon = opts.Icon or "⬡"
	self._opts = opts
	self._tabs, self._assets, self._pages = {}, {}, {}
	self._cons, self._closedCbs = {}, {}
	self._quick, self._pluginOpen, self._busy = {}, {}, {}
	self._previewExtensions = {}
	self._cardOf, self._thumbQueue = {}, {}
	self._query, self._order, self._pageSeq = "", 0, 0
	self._ft = 1 / 60
	attachControls(self)

	self._settings = { _pv = self }
	attachControls(self._settings)
	self:_cacheSettings()
	self:_buildSettingsControls()

	-- Plugin Core lives outside PreviewUI; plugins own their implementation files.
	self._plugins, self._pluginLoadError = nil, nil
	local base = opts.PluginBase or DEFAULT_PLUGIN_BASE
	local function loadPluginCore(path)
		local okBody, body = pcall(function() return game:HttpGet(base .. path) end)
		if not okBody or type(body) ~= "string" or body == "" then
			return nil, "download failed: " .. tostring(body)
		end
		local fn, compileError = loadstring(body)
		if type(fn) ~= "function" then
			return nil, tostring(compileError)
		end
		local okModule, module = pcall(fn)
		if not okModule or type(module) ~= "table" then
			return nil, tostring(module)
		end
		return module
	end
	local registry, registryError = loadPluginCore("Plugins/Registry.lua")
	local managerModule, managerError = loadPluginCore("Plugins/PluginManager.lua")
	if registry and managerModule and type(managerModule.new) == "function" then
		local okManager, manager = pcall(managerModule.new, self, B, registry)
		if okManager and manager then
			self._plugins = manager
			pcall(function() manager:LoadInstalled() end)
		else
			self._pluginLoadError = tostring(manager)
		end
	else
		self._pluginLoadError = tostring(registryError or managerError or "Plugin Core unavailable")
		warn("[PreviewUI] Plugin Core unavailable: " .. self._pluginLoadError)
	end

	table.insert(B.unloadHooks, function()
		self:Destroy()
	end)
	table.insert(B.themeHooks, function()
		self:_onTheme()
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

function M:_cacheSettings()
	self._auto = S("autorotate", true) == true
	self._rotSpeed = math.rad(tonumber(S("rotspeed", 40)) or 40)
	self._minCell = math.clamp(tonumber(S("card", 140)) or 140, 100, 240)
	self._ground = S("ground", true) == true
	self._listMode = S("list", false) == true
end

function M:_buildSettingsControls()
	local s = self._settings
	makeControl(s, "Toggle", { Name = "Auto-rotate preview", Default = true, Flag = "_pv_autorotate",
		Callback = function(v) self._auto = v == true end })
	makeControl(s, "Slider", { Name = "Rotation speed", Min = 5, Max = 120, Step = 5, Default = 40, Suffix = "°/s",
		Flag = "_pv_rotspeed", Callback = function(v) self._rotSpeed = math.rad(v) end })
	makeControl(s, "Toggle", { Name = "Ground disc under models", Default = true, Flag = "_pv_ground",
		Callback = function(v) self._ground = v == true end })
	makeControl(s, "Slider", { Name = "Card size", Min = 100, Max = 240, Step = 10, Default = 140, Suffix = " px",
		Flag = "_pv_card", Callback = function(v)
			self._minCell = v
			self:_fitGrid()
		end })
	makeControl(s, "Dropdown", { Name = "Layout", Options = { "Auto", "Compact", "Wide" }, Default = "Auto",
		Flag = "_pv_layout", Callback = function() self:_scheduleLayout() end })
	makeControl(s, "Toggle", { Name = "Remember last page", Default = true, Flag = "_pv_remember" })
end

--------------------------------------------------------------------
-- plugin API
--------------------------------------------------------------------
function M:GetPlugins()
	if not self._plugins then return {} end
	return self._plugins:GetAvailable()
end

function M:GetPlugin(id)
	if not self._plugins then return nil end
	return self._plugins:Get(id)
end

function M:InstallPlugin(id)
	if not self._plugins then return false, self._pluginLoadError or "PLUGIN_CORE_UNAVAILABLE" end
	return self._plugins:Install(id)
end

function M:EnablePlugin(id)
	if not self._plugins then return false, self._pluginLoadError or "PLUGIN_CORE_UNAVAILABLE" end
	return self._plugins:Enable(id)
end

function M:DisablePlugin(id)
	if not self._plugins then return false, self._pluginLoadError or "PLUGIN_CORE_UNAVAILABLE" end
	return self._plugins:Disable(id)
end

function M:UninstallPlugin(id)
	if not self._plugins then return false, self._pluginLoadError or "PLUGIN_CORE_UNAVAILABLE" end
	return self._plugins:Uninstall(id)
end

function M:SetPluginOpen(id, fn)
	self._pluginOpen[id] = type(fn) == "function" and fn or nil
end

function M:QuickAction(o)
	local item = { Name = tostring(o.Name or "Action"), Icon = o.Icon or "zap", Callback = o.Callback }
	self._quick[#self._quick + 1] = item
	self:_pluginsChanged()
	local handle = {}
	function handle:Remove()
		for i, q in ipairs(self._owner._quick) do
			if q == item then
				table.remove(self._owner._quick, i)
				break
			end
		end
		local owner = self._owner
		owner:_pluginsChanged()
	end
	handle._owner = self
	return handle
end

function M:CreateIcon(parent, name, size, color)
	return mkIcon(parent, name, size or 14, color or T.dim)
end

function M:GetPluginUI()
	return {
		Create = new, Text = txt, Icon = mkIcon, Corner = corner, Stroke = stroke, Pad = pad,
		Colors = C, Accent = T.accent, Theme = function() return T end,
		Fonts = { Bold = GB, Medium = GM, Regular = G },
		U2 = U2, V2 = V2, RunService = RunService, TweenService = TS,
		IsPointer = isPtr, DragLocked = dragLocked, Scale = curScale, TouchLast = touchLast,
		Button = mkButton, IconButton = mkIconButton, Switch = mkSwitch, Slider = mkSlider, Badge = badge, List = listLayout,
		Tween = tw, Notify = function(o) B.notify(o) end,
		Viewport = function(parent, asset, o) return self:CreateViewport(parent, asset, o) end,
		Control = function(parent, kind, o, order) return self:RenderControl(parent, kind, o, order) end,
	}
end

-- Renders a stand-alone control (not registered on any owner) and returns def, row.
function M:RenderControl(parent, kind, o, order)
	local owner = { _controls = {}, _pv = { _ctrlChanged = function() end } }
	local def = makeControl(owner, kind, o)
	return def, renderControl(parent, def, order or 0)
end

function M:GetView()
	local copy = {}
	for k, v in pairs(VIEW) do
		copy[k] = v
	end
	return copy
end

function M:SetView(patch)
	for k, v in pairs(patch or {}) do
		if VIEW[k] ~= nil then
			VIEW[k] = v
		end
	end
	for _, fn in ipairs(VIEW_LISTENERS) do
		safe(fn)
	end
end

-- o: Position, Size, Rig (anchor only the root part), Model (clone this instead of asset.Model),
--    Ground, AutoRotate, Toolbar, Hint, OnFullscreen, OnClick(screenPos) (a tap, not a drag); obj:PartAt(screenPos). Returns { Frame, Viewport, Model, Camera, Toolbar,
--    Reset, Focus, SetModel, SetAutoRotate, AddButton, Destroy }.
function M:CreateViewport(parent, asset, o)
	o = o or {}
	local cons, obj = {}, {}
	local holder = new("Frame", {
		Name = "Viewport", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true,
		Position = o.Position or U2(0, 0, 0, 0), Size = o.Size or U2(1, 0, 1, 0),
	}, parent)
	corner(holder, 12)
	stroke(holder, T.border, 1, 0.3)
	new("UIGradient", { Color = ColorSequence.new(T.accent:Lerp(T.bg, 0.8), T.bg), Rotation = 90 }, holder)
	obj.Frame = holder
	local vp = new("ViewportFrame", { Size = U2(1, 0, 1, 0) }, holder)
	styleViewport(vp)
	obj.Viewport = vp

	local st
	local yaw, pitch, dist = 0.6, 0.22, 10
	local minD, maxD = 0.3, 100
	local dragging, resumeAt = false, 0
	local auto = o.AutoRotate
	if auto == nil then
		auto = self._auto
	end
	local function apply()
		if st then
			aimCamera(st, yaw, pitch, dist)
		end
	end
	local function build()
		for _, ch in ipairs(vp:GetChildren()) do
			ch:Destroy()
		end
		st, obj.Model, obj.Camera = nil, nil, nil
		if not (o.Model or hasPreview({ Model = asset.Model, Build = asset.Build })) then
			return false
		end
		local ok, res = pcall(buildStage, vp, asset, o.Ground ~= false and self._ground, o)
		if not (ok and res) then
			return false
		end
		st = res
		obj.Model, obj.Camera = res.model, res.cam
		dist = res.dist
		minD, maxD = math.max(res.radius * 0.05, 0.3), res.dist * 4
		apply()
		return true
	end
	local built = build()
	if not built then
		if asset.Image then
			local img = new("ImageLabel", { BackgroundTransparency = 1, Size = U2(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), ScaleType = Enum.ScaleType.Fit }, holder)
			local v = tostring(asset.Image)
			img.Image = v:match("^%d+$") and ("rbxassetid://" .. v) or v
		else
			txt("TextLabel", { Text = "No 3D preview for this asset.", TextColor3 = T.dim, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = U2(1, 0, 1, 0) }, holder)
		end
	end

	local function applyView()
		styleViewport(vp)
		if st then
			st.cam.FieldOfView = VIEW.fov
			local g = st.world:FindFirstChild("PreviewGround")
			if g then
				g.Transparency = VIEW.ground and 0 or 1
			end
			apply()
		end
	end
	VIEW_LISTENERS[#VIEW_LISTENERS + 1] = applyView

	local catcher = txt("TextButton", { Size = U2(1, 0, 1, 0), Text = "" }, holder)
	catcher.InputBegan:Connect(function(i)
		if not isPtr(i) or not st then
			return
		end
		dragging = true
		local last, moved = i.Position, 0
		beginDrag(function(i2)
			local d = i2.Position - last
			last = i2.Position
			moved = moved + math.abs(d.X) + math.abs(d.Y)
			yaw = yaw - d.X * 0.01
			pitch = math.clamp(pitch + d.Y * 0.01, -1.2, 1.4)
			apply()
		end, function()
			dragging = false
			resumeAt = os.clock() + 1.5
			if moved < 6 and o.OnClick then
				safe(o.OnClick, last)
			end
		end)
	end)
	catcher.InputChanged:Connect(function(i)
		if st and i.UserInputType == Enum.UserInputType.MouseWheel then
			dist = math.clamp(dist * (1 - i.Position.Z * 0.1), minD, maxD)
			apply()
		end
	end)
	local pinchBase = dist
	cons[#cons + 1] = B.keep(UIS.TouchPinch:Connect(function(_, scale, _, state)
		if not st or not holder.Parent or not (self._root and self._root.Visible) then
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchBase = dist
		end
		dist = math.clamp(pinchBase / math.max(scale, 0.05), minD, maxD)
		apply()
	end))
	cons[#cons + 1] = B.keep(RunService.RenderStepped:Connect(function(dt)
		if st and auto and not dragging and os.clock() >= resumeAt and holder.Parent and self._root and self._root.Visible then
			yaw = yaw + self._rotSpeed * dt
			apply()
		end
	end))

	local bar
	if o.Toolbar ~= false then
		bar = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = U2(0, 0, 0, 36), AutomaticSize = AUTO_X }, holder)
		listLayout(bar, 6, true)
	end
	obj.Toolbar = bar
	function obj:AddButton(icon, fn)
		if not bar then
			return nil
		end
		return mkIconButton(bar, icon, 36, fn, T.panel)
	end
	function obj:PartAt(pos)
		if not st then
			return nil
		end
		local rel = pos - vp.AbsolutePosition
		local ray = st.cam:ViewportPointToRay(rel.X, rel.Y)
		local res = st.world:Raycast(ray.Origin, ray.Direction * 2000)
		if res and res.Instance and res.Instance.Name ~= "PreviewGround" then
			return res.Instance
		end
		return nil
	end
	function obj:Reset()
		yaw, pitch = 0.6, 0.22
		if st then
			st.center, dist = st.baseCenter, st.dist
		end
		apply()
	end
	function obj:Focus(target)
		if not st then
			return
		end
		local c, r
		if typeof(target) == "Instance" and target:IsA("BasePart") then
			c, r = target.Position, math.max(target.Size.Magnitude * 0.5, 0.3)
		elseif typeof(target) == "Instance" and target:IsA("Model") then
			local cf, sz = target:GetBoundingBox()
			c, r = cf.Position, math.max(sz.Magnitude * 0.5, 0.3)
		end
		if not c then
			return self:Reset()
		end
		st.center = c
		dist = math.clamp(r / math.sin(math.rad(VIEW.fov * 0.5)) * 1.15, minD, maxD)
		apply()
	end
	local autoBtn, autoIcon
	local function paintAuto()
		if autoIcon then
			local col = auto and T.accent or T.txt
			if autoIcon:IsA("TextLabel") then autoIcon.TextColor3 = col else autoIcon.ImageColor3 = col end
		end
	end
	function obj:SetAutoRotate(v)
		auto = v == true
		paintAuto()
	end
	function obj:SetModel(m)
		o.Model = m
		build()
		applyView()
	end
	function obj:Destroy()
		for _, c in ipairs(cons) do
			pcall(function() c:Disconnect() end)
		end
		for i = #VIEW_LISTENERS, 1, -1 do
			if VIEW_LISTENERS[i] == applyView then
				table.remove(VIEW_LISTENERS, i)
			end
		end
		if holder.Parent then
			holder:Destroy()
		end
	end
	if bar then
		obj:AddButton("scan", function() obj:Reset() end)
		autoBtn, autoIcon = obj:AddButton("rotate-3d", function() obj:SetAutoRotate(not auto) end)
		paintAuto()
		if o.OnFullscreen then
			obj:AddButton("maximize-2", o.OnFullscreen)
		end
	end
	if o.Hint ~= false and st then
		txt("TextLabel", {
			Text = "Drag to rotate  ·  scroll or pinch to zoom", TextSize = 11, TextColor3 = T.dim, AnchorPoint = V2(0, 1),
			Position = U2(0, 12, 1, -8), Size = U2(1, -24, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd,
		}, holder)
	end
	return obj
end

function M:RegisterPreviewExtension(id, build)
	assert(type(id) == "string" and id ~= "", "Preview extension requires an id")
	assert(type(build) == "function", "Preview extension requires a Build callback")
	for _, item in ipairs(self._previewExtensions) do
		if item.Id == id then
			return nil, "PREVIEW_EXTENSION_EXISTS"
		end
	end
	local item = { Id = id, Build = build }
	self._previewExtensions[#self._previewExtensions + 1] = item
	local owner = self
	local handle = { Connected = true }
	function handle:Destroy()
		if not self.Connected then return end
		self.Connected = false
		for i = #owner._previewExtensions, 1, -1 do
			if owner._previewExtensions[i] == item then
				table.remove(owner._previewExtensions, i)
			end
		end
	end
	return handle
end

function M:Header()
	return self -- 3.x sidebar headers have no place in the chip bar; kept so old scripts still run
end

function M:Page(o)
	o = o or {}
	self._pageSeq = self._pageSeq + 1
	local p = {
		id = "custom" .. tostring(self._pageSeq), name = o.Name or "Page", icon = o.Icon or "◆",
		build = o.Build, visible = o.Visible, custom = true,
	}
	self._pages[#self._pages + 1] = p
	self:_refreshDetail()
	return p
end

function M:RemovePage(page)
	for i = #self._pages, 1, -1 do
		local cur = self._pages[i]
		if cur == page or cur.id == page then
			table.remove(self._pages, i)
			if self._page == cur.id then
				self._page = nil
			end
			self:_refreshDetail()
			return true
		end
	end
	return false
end

--------------------------------------------------------------------
-- tabs and assets
--------------------------------------------------------------------
function M:Tab(o)
	o = o or {}
	local T_ = {
		_pv = self, _isTab = true, Name = o.Name or ("Tab " .. tostring(#self._tabs + 1)),
		Icon = o.Icon or "box", ShowAll = o.ShowAll == true, Filter = o.Filter, assets = {},
	}
	attachControls(T_)
	function T_:Asset(a)
		return self._pv:_addAsset(self, a)
	end
	function T_:Assets(list)
		local out = {}
		for _, a in ipairs(list or {}) do
			out[#out + 1] = self._pv:_addAsset(self, a, true)
		end
		self._pv:_assetsChanged()
		return out
	end
	function T_:Clear()
		for i = #self.assets, 1, -1 do
			self.assets[i]:Remove(true)
		end
		self._pv:_assetsChanged()
	end
	function T_:Open()
		return self._pv:Open(self)
	end
	function T_:Remove()
		self._pv:_removeTab(self)
	end
	self._tabs[#self._tabs + 1] = T_
	self:_chipsChanged()
	return T_
end

function M:_removeTab(tab)
	for i = #tab.assets, 1, -1 do
		tab.assets[i]:Remove(true)
	end
	for i, t in ipairs(self._tabs) do
		if t == tab then
			table.remove(self._tabs, i)
			break
		end
	end
	if self._activeTab == tab then
		self._activeTab = nil
	end
	self:_chipsChanged()
	self:_assetsChanged()
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

function M:_addAsset(tab, a, quiet)
	a = a or {}
	self._order = self._order + 1
	local asset = {}
	for k, v in pairs(a) do
		asset[k] = v
	end
	asset._pv, asset.tab, asset._order = self, tab, self._order
	asset.Name = tostring(a.Name or ("Asset " .. tostring(self._order)))
	asset.Actions = {}
	for i, act in ipairs(a.Actions or {}) do
		if i <= MAX_ACTIONS then
			asset.Actions[i] = act
		end
	end
	attachControls(asset)

	function asset:Select()
		self._pv:_select(self)
		return self
	end
	function asset:Action(act)
		if #self.Actions < MAX_ACTIONS and type(act) == "table" then
			self.Actions[#self.Actions + 1] = act
		end
		return self
	end
	function asset:Update(patch)
		for k, v in pairs(patch or {}) do
			if k ~= "_pv" and k ~= "tab" then
				self[k] = v
			end
		end
		self._pv:_assetUpdated(self)
		return self
	end
	function asset:Remove(quiet2)
		if self._dead then
			return
		end
		self._dead = true
		local pv = self._pv
		for i, x in ipairs(pv._assets) do
			if x == self then table.remove(pv._assets, i) break end
		end
		for i, x in ipairs(self.tab.assets) do
			if x == self then table.remove(self.tab.assets, i) break end
		end
		local card = pv._cardOf[self]
		if card then
			card:Destroy()
			pv._cardOf[self] = nil
		end
		if pv._selected == self then
			pv:CloseDrawer()
		end
		if not quiet2 then
			pv:_assetsChanged()
		end
	end

	self._assets[#self._assets + 1] = asset
	tab.assets[#tab.assets + 1] = asset
	if not quiet then
		self:_assetsChanged()
	end
	return asset
end

--------------------------------------------------------------------
-- open / close / destroy (JustLib window tab)
--------------------------------------------------------------------
function M:IsOpen()
	return self._tab ~= nil
end

function M:SetTitle(t)
	self.Title = tostring(t or self.Title)
	if self._R and self._R.title then
		self._R.title.Text = self.Title
	end
end

function M:OnClosed(fn)
	self._closedCbs[#self._closedCbs + 1] = fn
end

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
		self:_closeDetail()
	end
	return self
end

function M:_teardown(removeTab)
	local t = self._tab
	self._tab = nil
	self:_closeMenu()
	self:_cleanupPage()
	for _, c in ipairs(self._cons) do
		pcall(function() c:Disconnect() end)
	end
	self._cons = {}
	for _, d in ipairs(self:_allControls()) do
		d._refresh = nil
	end
	if removeTab and t then
		pcall(function() t:Remove() end)
	end
	self._root, self._ui, self._R = nil, nil, nil
	self._cardOf, self._thumbQueue = {}, {}
	self._selected, self._drawerOpen, self._page, self._pageId = nil, false, nil, nil
	for _, fn in ipairs(self._closedCbs) do
		safe(fn, self)
	end
	safe(self._opts.OnClose, self)
end

function M:_allControls()
	local out = {}
	local function add(list)
		for _, d in ipairs(list or {}) do
			out[#out + 1] = d
		end
	end
	add(self._controls)
	add(self._settings._controls)
	for _, t in ipairs(self._tabs) do add(t._controls) end
	for _, a in ipairs(self._assets) do add(a._controls) end
	return out
end

function M:Destroy()
	if not self.alive then
		return
	end
	self.alive = false
	if self._plugins then
		pcall(function() self._plugins:Destroy() end)
		self._plugins = nil
	end
	self:_teardown(true)
	self._tabs, self._assets, self._controls, self._pages = {}, {}, {}, {}
	if B.onDestroyed then
		B.onDestroyed(self)
	end
end

function M:_onTheme()
	if not self._root then
		return
	end
	loadTheme()
	self:_construct()
end

function M:_con(signal, fn)
	local c = B.keep(signal:Connect(fn))
	self._cons[#self._cons + 1] = c
	return c
end

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
			if self._root then
				self._root.Visible = true
				self:_scheduleLayout()
			end
		end,
		OnClose = function()
			if self._tab then self:_teardown(false) end
		end,
	})
	if not tab then
		return false
	end
	self._tab = tab
	self._root = tab.Frame
	self._root.ClipsDescendants = true
	self._drawerOpen = false
	self:_cacheSettings()
	self:_construct()
	self:_con(self._root:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:_scheduleLayout()
	end)
	self:_con(UIS.InputBegan, function(i, gp)
		if gp or i.KeyCode ~= Enum.KeyCode.K or not (self._root and self._root.Visible) then
			return
		end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl) then
			self:_openPalette()
		end
	end)
	if B.hasIconPack and not B.hasIconPack() then
		task.spawn(function()
			local t0 = os.clock()
			while self.alive and self._R and not B.hasIconPack() and os.clock() - t0 < 20 do
				task.wait(0.25)
			end
			if self.alive and self._R and B.hasIconPack() then
				ICON_STATS.missing = {}
				self:_construct()
			end
		end)
	end
	local acc = 0
	self:_con(RunService.Heartbeat, function(dt)
		self._ft = self._ft * 0.92 + dt * 0.08
		acc = acc + dt
		if acc >= 0.5 then
			acc = 0
			local R = self._R
			if R and self._root and self._root.Visible then
				local ms = self._ft * 1000
				if R.statFT and R.statFT.Parent then R.statFT.Text = string.format("%.1f ms", ms) end
				if R.footL and R.footL.Parent then R.footL.Text = string.format("%d FPS  ·  %.1f ms", math.floor(1000 / math.max(ms, 0.1) + 0.5), ms) end
			end
		end
	end)
	return true
end

--------------------------------------------------------------------
-- layout
--------------------------------------------------------------------
function M:_dims()
	local W, H
	if B.getContentSize then
		local ok, w, h = pcall(B.getContentSize)
		if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
			W, H = w, h
		end
	end
	if not W and self._root then
		local s, k = self._root.AbsoluteSize, curScale()
		if s.X > 0 and s.Y > 0 then
			W, H = s.X / k, s.Y / k
		end
	end
	return W or 624, H or 404
end

function M:_scheduleLayout()
	if self._layoutQueued or not self._R then
		return
	end
	self._layoutQueued = true
	task.defer(function()
		self._layoutQueued = false
		if self._R then
			self:_layout()
		end
	end)
end

local NAV = {
	{ id = "home", name = "Home", icon = "house" },
	{ id = "assets", name = "Assets", icon = "box" },
	{ id = "plugins", name = "Plugins", icon = "blocks" },
	{ id = "settings", name = "Settings", icon = "settings" },
	{ id = "about", name = "About", icon = "info" },
}

function M:_layout()
	local R = self._R
	if not R or not R.nav or not R.nav.Parent then
		return
	end
	local W, H = self:_dims()
	local forced = S("layout", "Auto")
	local mode = W >= BP_WIDE and "wide" or (W >= BP_MID and "mid" or "compact")
	if forced == "Compact" then mode = "compact" elseif forced == "Wide" and W >= BP_MID then mode = "wide" end
	local modeChanged = mode ~= self._mode
	self._mode, self._W, self._H = mode, W, H
	local gap = 8
	local navW = (mode == "wide" and 152) or (mode == "mid" and 58) or 0
	local navH = mode == "compact" and 58 or 0
	if mode == "compact" then
		R.nav.Position, R.nav.Size = U2(0, gap, 1, -(navH + gap)), U2(1, -2 * gap, 0, navH)
	else
		R.nav.Position, R.nav.Size = U2(0, gap, 0, gap), U2(0, navW, 1, -2 * gap)
	end
	local mainX = navW > 0 and (navW + 2 * gap) or gap
	R.main.Position = U2(0, mainX, 0, gap)
	R.main.Size = U2(1, -(mainX + gap), 1, -(2 * gap) - (navH > 0 and (navH + gap) or 0))
	self._Wm = W - mainX - gap
	self._Hm = H - 2 * gap - (navH > 0 and (navH + gap) or 0)
	if modeChanged then
		self:_styleNav(true)
		R.sub.Visible = mode ~= "compact"
		R.palBtn.Visible = mode == "wide"
		R.search.Size = U2(1, mode == "wide" and -100 or -42, 1, 0)
	end
	self:_applyAssetsLayout()
	if modeChanged or math.abs((self._renderedW or 0) - self._Wm) > 30 then
		self._renderedW = self._Wm
		self:_renderCurrent()
	end
end

function M:_applyTopbar()
	local R = self._R
	if not R then return end
	local hide = self._mode ~= "wide" and self._pageId == "assets" and self._drawerOpen == true
	local foot = self._mode ~= "compact"
	R.top.Visible = not hide
	R.foot.Visible = foot
	local top, bottom = hide and 0 or 56, foot and 32 or 0
	R.pages.Position = U2(0, 0, 0, top)
	R.pages.Size = U2(1, 0, 1, -(top + bottom))
end

function M:_refreshFoot()
	local R = self._R
	if not R or not R.footM then return end
	R.footM.Text = self._selected and ("Selected: " .. tostring(self._selected.Name)) or "No asset selected"
	local plugins = self:GetPlugins()
	local active = 0
	for _, p in ipairs(plugins) do
		if p.Enabled then active = active + 1 end
	end
	R.footR.Text = string.format("%d/%d plugins  ·  v%s", active, #plugins, M.Version)
end

function M:_construct()
	if self._ui then
		self:_cleanupPage()
		self._ui:Destroy()
	end
	self._thumbQueue = {}
	self._cardOf = {}
	local ui = new("Frame", { Name = "PvRoot", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = U2(1, 0, 1, 0) }, self._root)
	new("UIGradient", { Color = ColorSequence.new(T.bg, T.bg:Lerp(T.accent, 0.12)), Rotation = 125 }, ui)
	self._ui = ui
	local R = {}
	self._R = R

	R.nav = new("Frame", { Name = "Nav", BackgroundColor3 = T.panel, BorderSizePixel = 0 }, ui)
	corner(R.nav, 14)
	stroke(R.nav, T.border, 1, 0.3)
	local navList = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 1, 0) }, R.nav)
	R.navLayout = listLayout(navList, 4)
	R.navList = navList
	R.navPad = pad(navList, 6, 6, 8, 8)
	R.navBtns = {}
	for i, item in ipairs(NAV) do
		local b = txt("TextButton", { BackgroundTransparency = 1, LayoutOrder = i, Size = U2(1, 0, 0, 42) }, navList)
		corner(b, 10)
		local ic = mkIcon(b, item.icon, 18, T.dim)
		local lb = txt("TextLabel", { Text = item.name, Font = GM, TextSize = 13, TextColor3 = T.dim, TextTruncate = Enum.TextTruncate.AtEnd }, b)
		local bar = new("Frame", { BackgroundColor3 = T.accent, BorderSizePixel = 0, Size = UDim2.fromOffset(3, 18), Visible = false }, b)
		corner(bar, 2)
		b.Activated:Connect(function()
			self:_showPage(item.id)
		end)
		b.MouseEnter:Connect(function()
			if not touchLast() and self._pageId ~= item.id then tw(b, { BackgroundTransparency = 0.88 }, 0.1) end
		end)
		b.MouseLeave:Connect(function()
			if self._pageId ~= item.id then tw(b, { BackgroundTransparency = 1 }, 0.1) end
		end)
		R.navBtns[item.id] = { btn = b, icon = ic, label = lb, bar = bar, index = i }
	end
	R.status = new("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(0, 1), Position = U2(0, 6, 1, -8), Size = U2(1, -12, 0, 34) }, R.nav)
	local dot = new("Frame", { BackgroundColor3 = T.good, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(8, 8) }, R.status)
	corner(dot, 4)
	R.statusText = txt("TextLabel", { Text = "Ready", Font = GM, TextSize = 12, TextColor3 = T.good, Position = UDim2.fromOffset(22, 0), Size = U2(1, -22, 0, 18) }, R.status)
	R.statusVer = txt("TextLabel", { Text = "v" .. M.Version, TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(22, 16), Size = U2(1, -22, 0, 16) }, R.status)

	R.main = new("Frame", { Name = "Main", BackgroundTransparency = 1 }, ui)
	R.top = new("Frame", { Name = "Top", BackgroundColor3 = T.panel, BorderSizePixel = 0, Size = U2(1, 0, 0, 48), ClipsDescendants = true }, R.main)
	corner(R.top, 14)
	stroke(R.top, T.border, 1, 0.3)
	local logo = txt("TextButton", { BackgroundTransparency = 0, BackgroundColor3 = T.accent, Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(36, 36) }, R.top)
	corner(logo, 10)
	centerIcon(logo, self.Icon, 20, Color3.new(1, 1, 1))
	logo.Activated:Connect(function() self:_openPalette() end)
	local sweep = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = V2(0, 1), Position = U2(0, 14, 1, 0), Size = U2(1, -28, 0, 2) }, R.top)
	local sweepG = new("UIGradient", {
		Color = ColorSequence.new(T.accent), Offset = V2(-1, 0),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
	}, sweep)
	TS:Create(sweepG, TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = V2(1, 0) }):Play()
	R.title = txt("TextLabel", { Text = self.Title, Font = GB, TextSize = 14, Position = UDim2.fromOffset(52, 6), Size = UDim2.fromOffset(150, 18), TextTruncate = Enum.TextTruncate.AtEnd }, R.top)
	R.sub = txt("TextLabel", {
		Text = self._opts.Subtitle or "Advanced development tools", TextSize = 11, TextColor3 = T.dim,
		Position = UDim2.fromOffset(52, 24), Size = UDim2.fromOffset(150, 16), TextTruncate = Enum.TextTruncate.AtEnd,
	}, R.top)
	local searchBox = new("Frame", {
		BackgroundColor3 = T.input, BorderSizePixel = 0, AnchorPoint = V2(1, 0.5),
		Position = U2(1, -8, 0.5, 0), Size = U2(1, -222, 0, 34),
	}, R.top)
	corner(searchBox, 10)
	stroke(searchBox, T.border, 1, 0.3)
	local lens = mkIcon(searchBox, "search", 16, T.dim)
	lens.Position = UDim2.fromOffset(10, 9)
	R.search = txt("TextBox", {
		PlaceholderText = "Search assets and plugins…", PlaceholderColor3 = T.dim, TextSize = 13, ClearTextOnFocus = false,
		Text = self._query, Position = UDim2.fromOffset(34, 0), Size = U2(1, -42, 1, 0),
	}, searchBox)
	R.searchBox = searchBox
	R.palBtn = txt("TextButton", {
		BackgroundTransparency = 0, BackgroundColor3 = T.card, Text = "Ctrl K", Font = GM, TextSize = 11, TextColor3 = T.dim,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = V2(1, 0.5), Position = U2(1, -6, 0.5, 0), Size = UDim2.fromOffset(52, 22),
	}, searchBox)
	corner(R.palBtn, 6)
	R.palBtn.Activated:Connect(function() self:_openPalette() end)
	R.search:GetPropertyChangedSignal("Text"):Connect(function()
		self._query = R.search.Text
		self:_onSearch()
	end)

	R.pages = new("Frame", { Name = "Pages", BackgroundTransparency = 1, ClipsDescendants = true }, R.main)
	R.pageFrames = {}
	local function scrollPage(id)
		local sf = new("ScrollingFrame", {
			Name = id, BackgroundTransparency = 1, BorderSizePixel = 0, Size = U2(1, 0, 1, 0), Visible = false,
			CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = AUTO_Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, R.pages)
		R.pageFrames[id] = sf
		return sf
	end
	R.home, R.plugins, R.settingsPage, R.about = scrollPage("home"), scrollPage("plugins"), scrollPage("settings"), scrollPage("about")
	self:_constructAssets(R)

	R.foot = new("Frame", { Name = "Foot", BackgroundColor3 = T.panel, BorderSizePixel = 0, AnchorPoint = V2(0, 1), Position = U2(0, 0, 1, 0), Size = U2(1, 0, 0, 26), ClipsDescendants = true }, R.main)
	corner(R.foot, 10)
	stroke(R.foot, T.border, 1, 0.3)
	R.footL = txt("TextLabel", { Text = "", Font = GM, TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(12, 0), Size = U2(0.3, -12, 1, 0) }, R.foot)
	R.footM = txt("TextLabel", { Text = "", TextSize = 11, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Position = U2(0.3, 0, 0, 0), Size = U2(0.4, 0, 1, 0) }, R.foot)
	R.footR = txt("TextLabel", { Text = "", TextSize = 11, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Right, Position = U2(0.7, 0, 0, 0), Size = U2(0.3, -12, 1, 0) }, R.foot)

	R.overlay = new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = U2(1, 0, 1, 0), ZIndex = 50, Visible = false }, ui)

	R.pageFrames.assets = R.assetsPage
	self._mode = nil
	self:_layout()
	local startPage = self._pageId or (S("remember", true) and S("page", "home") or "home")
	if not R.pageFrames[startPage] then
		startPage = "home"
	end
	self._pageId = nil
	self:_refreshFoot()
	self:_showPage(startPage)
	if self._selected and not self._selected._dead then
		self:_openDetail()
	end
end

function M:_styleNav(instant)
	local R = self._R
	if not R then return end
	local mode = self._mode or "wide"
	local n = #NAV
	if mode == "compact" then
		R.navLayout.FillDirection = Enum.FillDirection.Horizontal
		R.navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		R.navLayout.Padding = UDim.new(0, 0)
	else
		R.navLayout.FillDirection = Enum.FillDirection.Vertical
		R.navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		R.navLayout.Padding = UDim.new(0, 4)
	end
	R.status.Visible = mode == "wide"
	local px, py = mode == "compact" and 4 or 6, mode == "compact" and 4 or 8
	R.navPad.PaddingLeft, R.navPad.PaddingRight = UDim.new(0, px), UDim.new(0, px)
	R.navPad.PaddingTop, R.navPad.PaddingBottom = UDim.new(0, py), UDim.new(0, py)
	R.navList.Size = mode == "compact" and U2(1, 0, 1, 0) or U2(1, 0, 1, -50)
	for id, r in pairs(R.navBtns) do
		local on = id == self._pageId
		local col = on and T.txt or T.dim
		local iconCol = on and T.accent or T.dim
		r.btn.BackgroundColor3 = T.cardHi
		if instant then
			r.btn.BackgroundTransparency = on and 0.35 or 1
			r.label.TextColor3 = col
			if r.icon:IsA("TextLabel") then r.icon.TextColor3 = iconCol else r.icon.ImageColor3 = iconCol end
		else
			tw(r.btn, { BackgroundTransparency = on and 0.35 or 1 }, 0.15)
			tw(r.label, { TextColor3 = col }, 0.15)
			setIconColor(r.icon, iconCol)
		end
		r.bar.Visible = on and mode == "wide"
		if mode == "wide" then
			r.btn.Size = U2(1, 0, 0, 42)
			r.icon.AnchorPoint, r.icon.Position = V2(0, 0.5), U2(0, 14, 0.5, 0)
			r.label.Visible = true
			r.label.AnchorPoint, r.label.Position, r.label.Size = V2(0, 0), UDim2.fromOffset(44, 0), U2(1, -48, 1, 0)
			r.label.TextXAlignment = Enum.TextXAlignment.Left
			r.bar.Position = U2(0, 0, 0.5, -9)
		elseif mode == "mid" then
			r.btn.Size = U2(1, 0, 0, 44)
			r.icon.AnchorPoint, r.icon.Position = V2(0.5, 0.5), U2(0.5, 0, 0.5, 0)
			r.label.Visible = false
		else
			r.btn.Size = U2(1 / n, 0, 1, 0)
			r.icon.AnchorPoint, r.icon.Position = V2(0.5, 0), U2(0.5, 0, 0, 6)
			r.label.Visible = true
			r.label.AnchorPoint, r.label.Position, r.label.Size = V2(0, 0), UDim2.fromOffset(0, 28), U2(1, 0, 0, 16)
			r.label.TextXAlignment = Enum.TextXAlignment.Center
			r.label.TextSize = 11
		end
		if mode ~= "compact" then r.label.TextSize = 13 end
	end
end

--------------------------------------------------------------------
-- navigation
--------------------------------------------------------------------
function M:_showPage(id)
	local R = self._R
	if not R or not R.pageFrames[id] then
		return
	end
	local changed = self._pageId ~= id
	self._pageId = id
	for pid, f in pairs(R.pageFrames) do
		f.Visible = pid == id
	end
	self:_styleNav(false)
	self:_applyTopbar()
	local pf = R.pageFrames[id]
	if changed and pf then
		pf.Position = U2(0, 0, 0, 14)
		tw(pf, { Position = U2(0, 0, 0, 0) }, 0.28, QUINT)
	end
	R.search.PlaceholderText = id == "plugins" and "Search plugins…" or "Search assets…"
	if changed then
		self:_renderCurrent()
		if S("remember", true) then
			B.cfgSet("_pv_page", id)
		end
	end
end

function M:_renderCurrent()
	local id = self._pageId
	if id == "home" then self:_renderHome()
	elseif id == "plugins" then self:_renderPlugins()
	elseif id == "settings" then self:_renderSettings()
	elseif id == "about" then self:_renderAbout()
	elseif id == "assets" then
		self:_renderChips()
		self:_syncCards()
	end
end

function M:_onSearch()
	if self._pageId == "home" or self._pageId == "settings" or self._pageId == "about" then
		if self._query ~= "" then
			self:_showPage("assets")
		end
		return
	end
	if self._pageId == "plugins" then
		self:_renderPlugins()
	else
		self:_applyFilter()
	end
end

function M:_pluginsChanged()
	if not self._R then return end
	self:_refreshFoot()
	local id = self._pageId
	if id == "home" then self:_renderHome() elseif id == "plugins" then self:_renderPlugins() elseif id == "about" then self:_renderAbout() end
end

function M:_chipsChanged()
	if self._R and self._pageId == "assets" then
		self:_renderChips()
	end
end

function M:_assetsChanged()
	if not self._R or self._assetsQueued then return end
	self._assetsQueued = true
	task.defer(function()
		self._assetsQueued = false
		if not self._R then return end
		if self._pageId == "assets" then
			self:_renderChips()
			self:_syncCards()
		elseif self._pageId == "home" then
			self:_renderHome()
		end
	end)
end

function M:_assetUpdated(asset)
	if not self._R then return end
	local card = self._cardOf[asset]
	if card then
		card:Destroy()
		self._cardOf[asset] = nil
	end
	if self._pageId == "assets" then
		self:_syncCards()
	end
	if self._selected == asset then
		self:_refreshDetail()
	end
end

function M:_ctrlChanged()
	if not self._R or not self._drawerOpen or self._ctrlQueued then
		return
	end
	self._ctrlQueued = true
	task.defer(function()
		self._ctrlQueued = false
		if not (self._R and self._drawerOpen and self._selected) then
			return
		end
		local r = self._pageBtns and self._pageBtns.controls
		if r and r.btn.Parent then
			local n = #self:_controlsFor(self._selected)
			r.btn.Text = n > 0 and ("Controls  " .. n) or "Controls"
		end
		if self._page == "preview" or self._page == "controls" then
			self:_showDetailPage(self._page)
		end
	end)
end

function M:_goto(target)
	local tab, asset, page
	if type(target) == "string" then
		tab = self:GetTab(target)
		asset = (not tab) and self:GetAsset(target) or nil
	elseif type(target) == "table" then
		if target._isTab then
			tab = target
		elseif target._pv and target.Name and target.tab then
			asset = target
		else
			tab = type(target.Tab) == "string" and self:GetTab(target.Tab) or target.Tab
			asset = type(target.Asset) == "string" and self:GetAsset(target.Asset) or target.Asset
			page = target.Page
		end
	end
	self:_showPage("assets")
	if tab then
		self._activeTab = tab
		self:_renderChips()
		self:_applyFilter()
	end
	if asset then
		self:_select(asset)
		if page then
			self:_showDetailPage(page)
		end
	end
end

--------------------------------------------------------------------
-- plugin cards, Home, Plugins page
--------------------------------------------------------------------
local function freshContainer(scroll, gap)
	local old = scroll:FindFirstChild("C")
	if old then
		old:Destroy()
	end
	local c = new("Frame", { Name = "C", BackgroundTransparency = 1, Size = U2(1, -6, 0, 0), AutomaticSize = AUTO_Y }, scroll)
	listLayout(c, gap or 12)
	pad(c, 0, 0, 0, 12)
	return c
end

local function sectionHeader(parent, order, title, right, onRight)
	local f = new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = U2(1, 0, 0, 24) }, parent)
	txt("TextLabel", { Text = title, Font = GB, TextSize = 15, Size = U2(0.6, 0, 1, 0), Position = UDim2.fromOffset(2, 0) }, f)
	if right then
		local b = txt("TextButton", {
			Text = right, Font = GM, TextSize = 12, TextColor3 = T.accent, TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = V2(1, 0), Position = U2(1, 0, 0, 0), Size = UDim2.fromOffset(120, 24),
		}, f)
		b.Activated:Connect(function() safe(onRight) end)
	end
	return f
end

function M:_pluginState(p)
	if self._busy[p.Id] then
		return "busy"
	end
	if not p.Installed then
		return "available"
	end
	return p.Enabled and "active" or "disabled"
end

function M:_pluginCard(parent, p, order)
	local card = new("Frame", { BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = order, ClipsDescendants = true }, parent)
	corner(card, 14)
	stroke(card, T.border, 1, 0.3)
	local state = self:_pluginState(p)
	local iconBox = new("Frame", { BackgroundColor3 = T.accent, BackgroundTransparency = 0.82, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(40, 40) }, card)
	corner(iconBox, 10)
	centerIcon(iconBox, p.Icon or "blocks", 22, T.accent)
	txt("TextLabel", { Text = tostring(p.Name), Font = GB, TextSize = 14, Position = UDim2.fromOffset(62, 12), Size = U2(1, -150, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd }, card)
	txt("TextLabel", { Text = "v" .. tostring(p.Version or "?") .. "  ·  " .. tostring(p.Author or ""), TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(62, 32), Size = U2(1, -80, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, card)
	local tag, tagCol = nil, T.dim
	if state == "active" then tag, tagCol = "Active", T.good
	elseif state == "disabled" then tag, tagCol = "Disabled", T.warn
	elseif state == "busy" then tag, tagCol = "Working…", T.accent
	elseif p.Badge then tag, tagCol = tostring(p.Badge), T.accent end
	if tag then
		local bd = badge(card, tag, tagCol, U2(1, -12, 0, 12))
		bd.AnchorPoint = V2(1, 0)
	end
	txt("TextLabel", {
		Text = tostring(p.Description or ""), TextSize = 12, TextColor3 = T.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 62), Size = U2(1, -28, 1, -118), TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	local id = p.Id
	local function run(fn, okMsg)
		if self._busy[id] then return end
		self._busy[id] = true
		self:_pluginsChanged()
		task.spawn(function()
			local ok, a, b = pcall(fn)
			self._busy[id] = nil
			if not self.alive then return end
			local good = ok and a == true
			if not good then
				local msg = (not ok) and tostring(a) or tostring(b or "unknown error")
				B.notify({ Title = tostring(p.Name), Desc = msg, Type = "Warn", Duration = 6 })
			elseif okMsg then
				B.notify({ Title = tostring(p.Name), Desc = okMsg, Type = "Success", Duration = 3 })
			end
			self:_pluginsChanged()
		end)
	end
	if state == "available" then
		mkButton(card, { Text = "Install", Icon = "download", Primary = true, Position = U2(0, 12, 1, -50), Size = U2(1, -24, 0, 38),
			Callback = function() run(function() return self:InstallPlugin(id) end) end })
	elseif state == "busy" then
		local b = mkButton(card, { Text = "Please wait…", Position = U2(0, 12, 1, -50), Size = U2(1, -24, 0, 38) })
		b.Active = false
	else
		mkButton(card, { Text = "Open", Icon = "play", Primary = true, Position = U2(0, 12, 1, -50), Size = U2(1, -64, 0, 38),
			Callback = function() self:_openPlugin(p) end })
		local more = mkIconButton(card, "more-horizontal", 38, function() end)
		more.Position = U2(1, -50, 1, -50)
		more.Activated:Connect(function()
			local items = {}
			if state == "active" then
				items[#items + 1] = { Name = "Disable", Icon = "power", Callback = function() run(function() return self:DisablePlugin(id) end) end }
			else
				items[#items + 1] = { Name = "Enable", Icon = "power", Callback = function() run(function() return self:EnablePlugin(id) end, "Enabled") end }
			end
			items[#items + 1] = { Name = "Uninstall", Icon = "trash", Callback = function() run(function() return self:UninstallPlugin(id) end, "Uninstalled") end }
			self:_openMenuItems(items, more)
		end)
	end
	return card
end

function M:_openPlugin(p)
	local fn = self._pluginOpen[p.Id]
	if fn then
		safe(fn, p)
		return
	end
	self:_showPage("assets")
	B.notify({ Title = tostring(p.Name), Desc = "Select an asset: this plugin adds a page to its detail view.", Type = "Info", Duration = 4 })
end

function M:_pluginGrid(parent, order, list, minW, cardH)
	local holder = new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = U2(1, 0, 0, 0), AutomaticSize = AUTO_Y }, parent)
	local w = (self._Wm or 600) - 8
	local gap = 10
	local cols = math.clamp(math.floor((w + gap) / (minW + gap)), 1, 4)
	local cw = math.floor((w - gap * (cols - 1)) / cols)
	new("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder, CellSize = UDim2.fromOffset(cw, cardH),
		CellPadding = UDim2.fromOffset(gap, gap),
	}, holder)
	for i, p in ipairs(list) do
		self:_pluginCard(holder, p, i)
	end
	return holder
end

function M:_infoPanel(parent, order)
	local f = new("Frame", { BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = order, Size = U2(1, 0, 0, 0), AutomaticSize = AUTO_Y }, parent)
	corner(f, 14)
	stroke(f, T.border, 1, 0.3)
	pad(f, 14, 14, 12, 14)
	listLayout(f, 6)
	txt("TextLabel", { Text = "Info", Font = GB, TextSize = 14, Size = U2(1, 0, 0, 20), LayoutOrder = 1 }, f)
	txt("TextLabel", { Text = self.Title .. "  v" .. M.Version, Font = GM, TextSize = 13, TextColor3 = T.accent, Size = U2(1, 0, 0, 18), LayoutOrder = 2 }, f)
	local plugins = self:GetPlugins()
	local active = 0
	for _, p in ipairs(plugins) do if p.Enabled then active = active + 1 end end
	local function stat(order2, name, value)
		local line = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 20), LayoutOrder = order2 }, f)
		txt("TextLabel", { Text = name, TextColor3 = T.dim, TextSize = 12, Size = U2(0.6, 0, 1, 0) }, line)
		local v = txt("TextLabel", { Text = value, Font = GM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Size = U2(1, 0, 1, 0) }, line)
		return v
	end
	stat(3, "Assets", tostring(#self._assets))
	stat(4, "Plugins", tostring(#plugins))
	stat(5, "Active plugins", tostring(active))
	self._R.statFT = stat(6, "Frame time", string.format("%.1f ms", self._ft * 1000))
	return f
end

function M:_renderHome()
	local R = self._R
	if not R or not R.home then return end
	local c = freshContainer(R.home, 12)
	local mode = self._mode or "wide"
	local compact = mode == "compact"

	local hero = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, LayoutOrder = 1, Size = U2(1, 0, 0, compact and 168 or 176), ClipsDescendants = true }, c)
	corner(hero, 16)
	stroke(hero, T.border, 1, 0.3)
	new("UIGradient", { Color = ColorSequence.new(T.accent:Lerp(T.panel, 0.62), T.panel), Rotation = 20 }, hero)
	local orb = new("Frame", { BackgroundColor3 = T.accent, BackgroundTransparency = 0.78, BorderSizePixel = 0, AnchorPoint = V2(0.5, 0.5), Position = U2(1, -50, 0.5, 0), Size = UDim2.fromOffset(190, 190) }, hero)
	corner(orb, 95)
	local orb2 = new("Frame", { BackgroundColor3 = T.accent, BackgroundTransparency = 0.6, BorderSizePixel = 0, AnchorPoint = V2(0.5, 0.5), Position = U2(1, -50, 0.5, 0), Size = UDim2.fromOffset(96, 96) }, hero)
	corner(orb2, 48)
	TS:Create(orb, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = U2(1, -50, 0.5, 14) }):Play()
	badge(hero, "✦  Welcome to " .. self.Title, T.accent, UDim2.fromOffset(16, 16))
	txt("TextLabel", {
		Text = self._opts.HeroTitle or "Preview models, rigs and animations.", Font = GB, TextSize = compact and 17 or 22, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(16, 44), Size = U2(compact and 1 or 0.62, -32, 0, 56),
	}, hero)
	mkButton(hero, { Text = "Browse assets", Icon = "box", Primary = true, Position = UDim2.new(0, 16, 1, -54), Size = UDim2.fromOffset(compact and 132 or 150, 40), Callback = function() self:_showPage("assets") end })
	mkButton(hero, { Text = "Plugins", Icon = "blocks", Position = UDim2.new(0, compact and 158 or 176, 1, -54), Size = UDim2.fromOffset(compact and 96 or 120, 40), Callback = function() self:_showPage("plugins") end })

	local plugins = self:GetPlugins()
	sectionHeader(c, 2, "Plugins", "See all", function() self:_showPage("plugins") end)
	if #plugins == 0 then
		txt("TextLabel", {
			Text = self._pluginLoadError and ("Plugin Core unavailable: " .. self._pluginLoadError) or "No plugins in the registry yet.",
			TextColor3 = T.dim, TextSize = 12, TextWrapped = true, AutomaticSize = AUTO_Y, Size = U2(1, 0, 0, 0), LayoutOrder = 3,
		}, c)
	else
		local shown = {}
		for i = 1, math.min(#plugins, 4) do shown[i] = plugins[i] end
		self:_pluginGrid(c, 3, shown, 240, 168)
	end

	local lower = new("Frame", { BackgroundTransparency = 1, LayoutOrder = 4, Size = U2(1, 0, 0, 0), AutomaticSize = AUTO_Y }, c)
	local wide = mode ~= "compact" and (self._Wm or 600) >= 640
	listLayout(lower, 10, wide)
	local quick = new("Frame", {
		BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = 1, Size = wide and U2(0.5, -5, 0, 0) or U2(1, 0, 0, 0), AutomaticSize = AUTO_Y,
	}, lower)
	corner(quick, 14)
	stroke(quick, T.border, 1, 0.3)
	pad(quick, 12, 12, 12, 12)
	listLayout(quick, 6)
	txt("TextLabel", { Text = "Quick actions", Font = GB, TextSize = 14, Size = U2(1, 0, 0, 20), LayoutOrder = 0 }, quick)
	local actions = { { Name = "Browse assets", Icon = "box", Callback = function() self:_showPage("assets") end },
		{ Name = "Manage plugins", Icon = "blocks", Callback = function() self:_showPage("plugins") end } }
	for _, q in ipairs(self._quick) do actions[#actions + 1] = q end
	for i, q in ipairs(actions) do
		local b = txt("TextButton", { BackgroundTransparency = 0, BackgroundColor3 = T.input, Size = U2(1, 0, 0, 42), LayoutOrder = i }, quick)
		corner(b, 10)
		local ic = mkIcon(b, q.Icon, 16, T.accent)
		ic.Position = UDim2.fromOffset(12, 13)
		txt("TextLabel", { Text = q.Name, Font = GM, TextSize = 13, Position = UDim2.fromOffset(38, 0), Size = U2(1, -64, 1, 0) }, b)
		txt("TextLabel", { Text = "›", Font = GB, TextSize = 18, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Right, Position = U2(1, -12, 0, 0), AnchorPoint = V2(1, 0), Size = UDim2.fromOffset(20, 42) }, b)
		b.Activated:Connect(function() safe(q.Callback) end)
	end
	local info = self:_infoPanel(lower, 2)
	info.Size = wide and U2(0.5, -5, 0, 0) or U2(1, 0, 0, 0)
end

function M:_renderPlugins()
	local R = self._R
	if not R or not R.plugins then return end
	local c = freshContainer(R.plugins, 12)
	local all = self:GetPlugins()
	local list = {}
	for _, p in ipairs(all) do
		if matchQuery({ Name = p.Name, Type = p.Category, Creator = p.Author, Tags = { p.Description } }, self._query) then
			list[#list + 1] = p
		end
	end
	sectionHeader(c, 1, string.format("Plugins  ·  %d available", #list))
	if #all == 0 then
		txt("TextLabel", {
			Text = self._pluginLoadError and ("Plugin Core unavailable: " .. self._pluginLoadError) or "No plugins in the registry yet.",
			TextColor3 = T.dim, TextSize = 12, TextWrapped = true, AutomaticSize = AUTO_Y, Size = U2(1, 0, 0, 0), LayoutOrder = 2,
		}, c)
		return
	end
	if #list == 0 then
		txt("TextLabel", { Text = "No plugin matches your search.", TextColor3 = T.dim, TextSize = 12, Size = U2(1, 0, 0, 24), LayoutOrder = 2 }, c)
		return
	end
	self:_pluginGrid(c, 2, list, 260, 176)
end

function M:_renderSettings()
	local R = self._R
	if not R or not R.settingsPage then return end
	local c = freshContainer(R.settingsPage, 8)
	sectionHeader(c, 0, "Settings")
	for i, def in ipairs(self._settings._controls) do
		renderControl(c, def, i)
	end
end

function M:_renderAbout()
	local R = self._R
	if not R or not R.about then return end
	local c = freshContainer(R.about, 10)
	sectionHeader(c, 0, "About")
	local card = new("Frame", { BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = 1, Size = U2(1, 0, 0, 0), AutomaticSize = AUTO_Y }, c)
	corner(card, 14)
	stroke(card, T.border, 1, 0.3)
	pad(card, 14, 14, 14, 14)
	listLayout(card, 6)
	txt("TextLabel", { Text = self.Title, Font = GB, TextSize = 18, Size = U2(1, 0, 0, 24), LayoutOrder = 1 }, card)
	txt("TextLabel", { Text = "PreviewUI " .. M.Version, Font = GM, TextSize = 13, TextColor3 = T.accent, Size = U2(1, 0, 0, 18), LayoutOrder = 2 }, card)
	local core = self._plugins and "Plugin Core: loaded" or ("Plugin Core: unavailable (" .. tostring(self._pluginLoadError) .. ")")
	txt("TextLabel", { Text = core, TextSize = 12, TextColor3 = T.dim, TextWrapped = true, AutomaticSize = AUTO_Y, Size = U2(1, 0, 0, 0), LayoutOrder = 3 }, card)
	local missing = {}
	for name in pairs(ICON_STATS.missing) do missing[#missing + 1] = name end
	table.sort(missing)
	txt("TextLabel", {
		Text = string.format("Icons: %d resolved, %d missing%s", ICON_STATS.ok, #missing, #missing > 0 and (" (" .. table.concat(missing, ", ") .. ")") or ""),
		TextSize = 12, TextColor3 = #missing > 0 and T.warn or T.dim, TextWrapped = true, AutomaticSize = AUTO_Y, Size = U2(1, 0, 0, 0), LayoutOrder = 5,
	}, card)
	txt("TextLabel", {
		Text = "Plugins add pages to the asset detail view and can register their own asset categories and Home shortcuts.",
		TextSize = 12, TextColor3 = T.dim, TextWrapped = true, AutomaticSize = AUTO_Y, Size = U2(1, 0, 0, 0), LayoutOrder = 4,
	}, card)
end

--------------------------------------------------------------------
-- assets page: chips + grid + detail
--------------------------------------------------------------------
function M:_constructAssets(R)
	R.assetsPage = new("Frame", { Name = "assets", BackgroundTransparency = 1, Size = U2(1, 0, 1, 0), Visible = false }, R.pages)
	R.gridCol = new("Frame", { Name = "GridCol", BackgroundTransparency = 1, Size = U2(1, 0, 1, 0) }, R.assetsPage)
	local chipRow = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 38) }, R.gridCol)
	R.chips = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = U2(1, -92, 1, 0), CanvasSize = U2(0, 0, 0, 0),
		AutomaticCanvasSize = AUTO_X, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
	}, chipRow)
	listLayout(R.chips, 6, true)
	local views = new("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(1, 0), Position = U2(1, 0, 0, 0), Size = UDim2.fromOffset(86, 38) }, chipRow)
	local gridBtn = mkIconButton(views, "layout-grid", 38, function() self._listMode = false; B.cfgSet("_pv_list", false); self:_rebuildCards() end)
	local listBtn = mkIconButton(views, "list", 38, function() self._listMode = true; B.cfgSet("_pv_list", true); self:_rebuildCards() end)
	listBtn.Position = UDim2.fromOffset(44, 0)
	R.gridScroll = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 46), Size = U2(1, 0, 1, -46),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = AUTO_Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, R.gridCol)
	pad(R.gridScroll, 2, 8, 2, 8)
	R.gridLayout = new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, CellSize = UDim2.fromOffset(140, 190), CellPadding = UDim2.fromOffset(8, 8) }, R.gridScroll)
	R.empty = txt("TextLabel", {
		Text = "Nothing here yet.", TextColor3 = T.dim, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
		Position = U2(0, 0, 0, 80), Size = U2(1, 0, 0, 40), Visible = false,
	}, R.gridCol)

	R.detail = new("Frame", { Name = "Detail", BackgroundColor3 = T.panel, BorderSizePixel = 0, Visible = false, ClipsDescendants = true }, R.assetsPage)
	corner(R.detail, 14)
	stroke(R.detail, T.border, 1, 0.3)
	local head = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 56) }, R.detail)
	R.dBack = mkIconButton(head, "arrow-left", 38, function() self:_closeDetail() end)
	R.dBack.Position = UDim2.fromOffset(8, 9)
	R.dTitle = txt("TextLabel", { Font = GB, TextSize = 15, Position = UDim2.fromOffset(56, 8), Size = U2(1, -170, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd }, head)
	R.dSub = txt("TextLabel", { TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(56, 28), Size = U2(1, -170, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, head)
	R.dClose = mkIconButton(head, "x", 38, function() self:_closeDetail() end)
	R.dClose.AnchorPoint, R.dClose.Position = V2(1, 0), U2(1, -8, 0, 9)
	R.dMore = mkIconButton(head, "more-horizontal", 38, function() end)
	R.dMore.AnchorPoint, R.dMore.Position = V2(1, 0), U2(1, -52, 0, 9)
	R.dMore.Activated:Connect(function()
		if self._selected then self:_openMenu(self._selected, R.dMore) end
	end)
	R.dExpand = mkIconButton(head, "maximize-2", 38, function()
		self._expanded = not self._expanded
		self:_applyAssetsLayout()
		if self._page == "preview" or self._page == "controls" then
			self:_showDetailPage(self._page)
		end
	end)
	R.dExpand.AnchorPoint, R.dExpand.Position = V2(1, 0), U2(1, -96, 0, 9)
	R.dBar = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 58), Size = U2(1, -16, 0, 38),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = AUTO_X, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
	}, R.detail)
	listLayout(R.dBar, 6, true)
	R.dContent = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 102), Size = U2(1, -16, 1, -110), ClipsDescendants = true }, R.detail)
end

function M:_applyAssetsLayout()
	local R = self._R
	if not R or not R.gridCol then return end
	local W = self._Wm or 600
	local open = self._drawerOpen == true
	local overlay = self._mode ~= "wide"
	local gap = 10
	local detailW = math.clamp(math.floor(W * 0.5), 380, 620)
	if open and not overlay and not self._expanded then
		R.gridCol.Visible = true
		R.gridCol.Size = U2(0, W - detailW - gap, 1, 0)
		R.detail.Position, R.detail.Size = U2(1, -detailW, 0, 0), U2(0, detailW, 1, 0)
		self._gridW, self._detailW = W - detailW - gap, detailW
	elseif open then
		R.gridCol.Visible = false
		R.detail.Position, R.detail.Size = U2(0, 0, 0, 0), U2(1, 0, 1, 0)
		self._gridW, self._detailW = W, W
	else
		R.gridCol.Visible = true
		R.gridCol.Size = U2(1, 0, 1, 0)
		self._gridW = W
	end
	R.detail.Visible = open
	local backShown = overlay or self._expanded == true
	R.dBack.Visible = backShown
	R.dExpand.Visible = not overlay
	local tx = backShown and 56 or 14
	R.dTitle.Position, R.dSub.Position = UDim2.fromOffset(tx, 8), UDim2.fromOffset(tx, 28)
	R.dTitle.Size, R.dSub.Size = U2(1, -(tx + 150), 0, 20), U2(1, -(tx + 150), 0, 16)
	self:_fitGrid()
	self:_applyTopbar()
end

function M:_fitGrid()
	local R = self._R
	local layout = R and R.gridLayout
	if not layout then return end
	local w = (self._gridW or 400) - 12
	if self._listMode then
		layout.CellSize = U2(1, -4, 0, 64)
		layout.CellPadding = UDim2.fromOffset(0, 6)
	else
		local gap = 8
		local minCell = math.clamp(self._minCell or 140, 100, 240)
		local cols = math.max(1, math.floor((w + gap) / (minCell + gap)))
		local cw = math.floor((w - gap * (cols - 1)) / cols)
		layout.CellSize = UDim2.fromOffset(cw, math.floor(cw * 0.95) + 44)
		layout.CellPadding = UDim2.fromOffset(gap, gap)
	end
end

function M:_inScope(tab, a)
	if not tab or tab.ShowAll then
		return true
	end
	if tab.Filter then
		local ok, r = pcall(tab.Filter, a)
		return ok and r == true
	end
	return a.tab == tab
end

function M:_renderChips()
	local R = self._R
	if not R or not R.chips then return end
	for _, ch in ipairs(R.chips:GetChildren()) do
		if not ch:IsA("UIListLayout") then ch:Destroy() end
	end
	local list = { { name = "All", icon = "layout-grid" } }
	for _, t in ipairs(self._tabs) do
		list[#list + 1] = { name = t.Name, icon = t.Icon, tab = t }
	end
	for i, item in ipairs(list) do
		local on = (item.tab == self._activeTab)
		local b = txt("TextButton", {
			BackgroundTransparency = 0, BackgroundColor3 = on and T.cardHi or T.card, Text = item.name, Font = GM, TextSize = 13,
			TextColor3 = on and T.txt or T.dim, AutomaticSize = AUTO_X, Size = U2(0, 0, 1, 0), LayoutOrder = i,
		}, R.chips)
		corner(b, 12)
		pad(b, 32, 14, 0, 0)
		stroke(b, on and T.accent or T.border, 1, on and 0 or 0.4)
		local ic = mkIcon(b, item.icon, 16, on and T.accent or T.dim)
		ic.Position = UDim2.fromOffset(-22, 11)
		b.Activated:Connect(function()
			self._activeTab = item.tab
			self:_renderChips()
			self:_applyFilter()
		end)
	end
end

function M:_rebuildCards()
	for asset, card in pairs(self._cardOf) do
		card:Destroy()
		self._cardOf[asset] = nil
	end
	self:_fitGrid()
	if self._pageId == "assets" then
		self:_syncCards()
	end
end

function M:_syncCards()
	local R = self._R
	if not R or not R.gridScroll then return end
	for _, asset in ipairs(self._assets) do
		if not self._cardOf[asset] then
			self._cardOf[asset] = self:_makeCard(asset)
		end
	end
	self:_applyFilter()
end

function M:_applyFilter()
	local R = self._R
	if not R or not R.gridScroll then return end
	local shown = 0
	for _, asset in ipairs(self._assets) do
		local card = self._cardOf[asset]
		if card then
			local vis = self:_inScope(self._activeTab, asset) and matchQuery(asset, self._query)
			card.Visible = vis
			card.LayoutOrder = asset._order
			if vis then shown = shown + 1 end
		end
	end
	R.empty.Visible = shown == 0
	R.empty.Text = #self._assets == 0 and "No assets yet. Install a plugin or add assets with Preview:Tab()." or "No assets match."
	self:_markSelected()
end

function M:_pumpThumbs()
	if self._pumping then return end
	self._pumping = true
	task.spawn(function()
		while self.alive and self._R and #self._thumbQueue > 0 do
			local job = table.remove(self._thumbQueue, 1)
			local asset, holder, pulse = job[1], job[2], job[3]
			if holder.Parent and not asset._dead then
				for _, ch in ipairs(holder:GetChildren()) do
					if not ch:IsA("UICorner") then ch:Destroy() end
				end
				if asset.Image then
					local img = new("ImageLabel", { BackgroundTransparency = 1, Size = U2(1, 0, 1, 0), ScaleType = Enum.ScaleType.Fit }, holder)
					local v = tostring(asset.Image)
					img.Image = v:match("^%d+$") and ("rbxassetid://" .. v) or v
				elseif hasPreview(asset) then
					local vp = new("ViewportFrame", { Size = U2(1, 0, 1, 0) }, holder)
					styleViewport(vp)
					local ok, st = pcall(buildStage, vp, asset, false)
					if ok and st then
						aimCamera(st, 0.6, 0.22, st.dist)
					else
						vp:Destroy()
						centerIcon(holder, "box", 28, T.dim)
					end
				else
					centerIcon(holder, "box", 28, T.dim)
				end
			end
			if pulse then
				pulse:Cancel()
			end
			if holder.Parent then
				holder.BackgroundColor3 = T.bg
			end
			task.wait()
		end
		self._pumping = false
	end)
end

function M:_makeCard(asset)
	local R = self._R
	local list = self._listMode
	local cell = new("Frame", { Name = "Cell", BackgroundTransparency = 1, LayoutOrder = asset._order }, R.gridScroll)
	local card = txt("TextButton", {
		Name = "Card", BackgroundTransparency = 0, BackgroundColor3 = T.card, Text = "", ClipsDescendants = true,
		AnchorPoint = V2(0.5, 0.5), Position = U2(0.5, 0, 0.5, 0), Size = U2(1, 0, 1, 0),
	}, cell)
	corner(card, 12)
	stroke(card, T.border, 1, 0.3)
	local scale = new("UIScale", { Scale = 0.92 }, card)
	task.delay(math.min(asset._order * 0.012, 0.3), function()
		if scale.Parent then tw(scale, { Scale = 1 }, 0.35, QUINT) end
	end)
	local thumb = new("Frame", {
		BackgroundColor3 = T.bg, BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 8), Size = list and UDim2.fromOffset(48, 48) or U2(1, -16, 1, -56),
	}, card)
	corner(thumb, 10)
	local pulse = TS:Create(thumb, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundColor3 = T.cardHi })
	pulse:Play()
	txt("TextLabel", {
		Text = asset.Name, Font = GB, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = list and UDim2.fromOffset(66, 12) or U2(0, 10, 1, -42), Size = list and U2(1, -116, 0, 18) or U2(1, -40, 0, 18),
	}, card)
	txt("TextLabel", {
		Text = tostring(asset.Type or ""), TextSize = 11, TextColor3 = T.dim, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = list and UDim2.fromOffset(66, 32) or U2(0, 10, 1, -24), Size = list and U2(1, -116, 0, 16) or U2(1, -40, 0, 16),
	}, card)
	local nControls = #(asset._controls or {}) + #(asset.tab and asset.tab._controls or {})
	if nControls > 0 and not list then
		badge(card, tostring(nControls) .. " controls", T.accent, UDim2.fromOffset(14, 14))
	end
	local dots = txt("TextButton", {
		Text = "⋮", Font = GB, TextSize = 18, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = list and V2(1, 0.5) or V2(1, 1), Position = list and U2(1, -6, 0.5, 0) or U2(1, -4, 1, -6), Size = UDim2.fromOffset(32, 32),
	}, card)
	dots.Activated:Connect(function()
		self:_openMenu(asset, dots)
	end)
	card.Activated:Connect(function()
		self:_select(asset)
	end)
	card.MouseEnter:Connect(function()
		if touchLast() then return end
		tw(scale, { Scale = 1.025 }, 0.15)
		if self._selected ~= asset then tw(card, { BackgroundColor3 = T.cardHi }, 0.12) end
	end)
	card.MouseLeave:Connect(function()
		tw(scale, { Scale = 1 }, 0.15)
		if self._selected ~= asset then tw(card, { BackgroundColor3 = T.card }, 0.12) end
	end)
	self._thumbQueue[#self._thumbQueue + 1] = { asset, thumb, pulse }
	self:_pumpThumbs()
	return cell
end

function M:_markSelected()
	for asset, cell in pairs(self._cardOf) do
		local card = cell.Parent and cell:FindFirstChild("Card")
		if card then
			local on = asset == self._selected
			card.BackgroundColor3 = on and T.cardHi or T.card
			local st = card:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = on and T.accent or T.border
				st.Thickness = on and 2 or 1
				st.Transparency = on and 0 or 0.3
			end
		end
	end
end

--------------------------------------------------------------------
-- detail view
--------------------------------------------------------------------
function M:_select(asset)
	if not asset or asset._dead then return end
	if self._pageId ~= "assets" then
		self:_showPage("assets")
	end
	self._selected = asset
	self:_markSelected()
	self:_openDetail()
	self:_refreshFoot()
	safe(asset.Callback, asset)
end

function M:_openDetail()
	local R = self._R
	if not R or not self._selected then return end
	self._drawerOpen = true
	self:_applyAssetsLayout()
	if self._mode ~= "wide" then
		R.detail.Position = U2(0.12, 0, 0, 0)
		tw(R.detail, { Position = U2(0, 0, 0, 0) }, 0.3, QUINT)
	end
	self:_refreshDetail()
end

function M:_closeDetail()
	self:_cleanupPage()
	self._selected, self._drawerOpen, self._page, self._expanded = nil, false, nil, false
	self:_closeMenu()
	self:_markSelected()
	self:_applyAssetsLayout()
	self:_refreshFoot()
end

function M:_controlsFor(asset)
	local out, seen = {}, {}
	local function add(owner)
		for _, d in ipairs(owner and owner._controls or {}) do
			if not seen[d] then
				seen[d] = true
				out[#out + 1] = d
			end
		end
	end
	add(asset)
	add(asset and asset.tab)
	if self._activeTab and self._activeTab ~= (asset and asset.tab) then add(self._activeTab) end
	add(self)
	return out
end

function M:_pagesFor(asset)
	local n = #self:_controlsFor(asset)
	local out = {
		{ id = "preview", name = "Preview", icon = "box", build = function(parent, a) return self:_buildPreviewPage(parent, a) end },
		{ id = "controls", name = n > 0 and ("Controls  " .. n) or "Controls", icon = "sliders-horizontal",
			build = function(parent, a) return self:_buildControlsPage(parent, a) end },
		{ id = "info", name = "Info", icon = "info", build = function(parent, a) return self:_buildInfoPage(parent, a) end },
	}
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

function M:_refreshDetail()
	local R = self._R
	local a = self._selected
	if not R or not a or not self._drawerOpen then return end
	R.dTitle.Text = tostring(a.Name)
	local sub = tostring(a.Type or "")
	if a.Creator then
		sub = (sub ~= "" and (sub .. "  ·  ") or "") .. tostring(a.Creator)
	end
	R.dSub.Text = sub
	self._curPages = self:_pagesFor(a)
	for _, ch in ipairs(R.dBar:GetChildren()) do
		if not ch:IsA("UIListLayout") then ch:Destroy() end
	end
	self._pageBtns = {}
	for i, p in ipairs(self._curPages) do
		local b = txt("TextButton", {
			BackgroundTransparency = 0, BackgroundColor3 = T.card, Text = p.name, Font = GM, TextSize = 13,
			TextColor3 = T.dim, AutomaticSize = AUTO_X, Size = U2(0, 0, 1, 0), LayoutOrder = i,
		}, R.dBar)
		corner(b, 12)
		pad(b, 32, 14, 0, 0)
		local ic = mkIcon(b, p.icon, 16, T.dim)
		ic.Position = UDim2.fromOffset(-22, 11)
		b.Activated:Connect(function()
			self:_showDetailPage(p.id)
		end)
		self._pageBtns[p.id] = { btn = b, icon = ic }
	end
	local want = self._page
	local found = false
	for _, p in ipairs(self._curPages) do if p.id == want then found = true end end
	self:_showDetailPage(found and want or "preview")
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

function M:_showDetailPage(id)
	local R, a = self._R, self._selected
	if not R or not a or not self._curPages then return end
	local page
	for _, p in ipairs(self._curPages) do
		if p.id == id then page = p end
	end
	if not page then page = self._curPages[1] end
	self._page = page.id
	if self._mode == "wide" then
		local want = page.custom == true
		if self._expanded ~= want then
			self._expanded = want
			self:_applyAssetsLayout()
		end
	end
	self:_cleanupPage()
	for pid, r in pairs(self._pageBtns or {}) do
		local on = pid == page.id
		r.btn.BackgroundColor3 = on and T.cardHi or T.card
		r.btn.TextColor3 = on and T.txt or T.dim
		if r.icon:IsA("TextLabel") then r.icon.TextColor3 = on and T.accent or T.dim else r.icon.ImageColor3 = on and T.accent or T.dim end
	end
	local pr = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = U2(1, 0, 1, 0) }, R.dContent)
	self._pageRoot = pr
	local ok, cleanup = pcall(page.build, pr, a, self)
	if ok then
		if type(cleanup) == "function" then
			self._pageCleanup = cleanup
		end
	else
		warn("[PreviewUI] page '" .. tostring(page.name) .. "' failed: " .. tostring(cleanup))
		txt("TextLabel", { Text = "This page failed to load.", TextColor3 = T.dim, TextSize = 12, Size = U2(1, 0, 0, 30) }, pr)
	end
end

function M:_buildInfoPage(parent, a)
	local sf = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = U2(1, 0, 1, 0), CanvasSize = U2(0, 0, 0, 0),
		AutomaticCanvasSize = AUTO_Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
	}, parent)
	local c = new("Frame", { BackgroundTransparency = 1, Size = U2(1, -6, 0, 0), AutomaticSize = AUTO_Y }, sf)
	listLayout(c, 6)
	local order = 0
	local function row(icon, label, value)
		if value == nil or tostring(value) == "" then return end
		order = order + 1
		local r = rowBase(c, order, 40)
		local ic = mkIcon(r, icon or "info", 16, T.accent)
		ic.Position = UDim2.fromOffset(12, 12)
		txt("TextLabel", { Text = label, TextColor3 = T.dim, TextSize = 12, Position = UDim2.fromOffset(38, 0), Size = U2(0.4, -38, 1, 0) }, r)
		txt("TextLabel", { Text = tostring(value), Font = GM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, AnchorPoint = V2(1, 0), Position = U2(1, -12, 0, 0), Size = U2(0.6, -16, 1, 0) }, r)
	end
	row("tag", "Type", a.Type)
	row("user-round", "Creator", a.Creator)
	row("calendar", "Created", a.Created)
	row("hard-drive", "Size", a.Size)
	row("git-branch", "Version", a.Version)
	if type(a.Tags) == "table" and #a.Tags > 0 then
		local tags = {}
		for _, t in ipairs(a.Tags) do tags[#tags + 1] = tostring(t) end
		row("tag", "Tags", table.concat(tags, ", "))
	end
	if typeof(a.Model) == "Instance" then
		local parts = 0
		if a.Model:IsA("BasePart") then parts = 1 end
		for _, d in ipairs(a.Model:GetDescendants()) do
			if d:IsA("BasePart") then parts = parts + 1 end
		end
		row("box", "Parts", tostring(parts))
	end
	for _, extra in ipairs(type(a.Info) == "table" and a.Info or {}) do
		row(extra.Icon, tostring(extra.Label or ""), extra.Value)
	end
	if a.Description and tostring(a.Description) ~= "" then
		order = order + 1
		txt("TextLabel", {
			Text = tostring(a.Description), TextSize = 12, TextColor3 = T.dim, TextWrapped = true, AutomaticSize = AUTO_Y,
			Size = U2(1, -8, 0, 0), LayoutOrder = order,
		}, c)
	end
end

function M:_buildPreviewPage(parent, a)
	local previewable = hasPreview(a)
	local list = self:_controlsFor(a)
	local pair = (self._detailW or 400) >= 420
	local full, viewport = false, nil
	local scroll = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = AUTO_Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
	}, parent)
	local cl = new("Frame", { BackgroundTransparency = 1, Size = U2(1, -6, 0, 0), AutomaticSize = AUTO_Y }, scroll)
	listLayout(cl, 6)
	local function relayout()
		local frac = #list > 0 and 0.56 or 1
		if viewport then
			viewport.Frame.Size = full and U2(1, 0, 1, 0) or U2(1, 0, frac, #list > 0 and -4 or 0)
			scroll.Position, scroll.Size = U2(0, 0, frac, 4), U2(1, 0, 1 - frac, -4)
			scroll.Visible = not full and #list > 0
		else
			scroll.Position, scroll.Size, scroll.Visible = U2(0, 0, 0, 0), U2(1, 0, 1, 0), true
		end
	end
	if previewable then
		viewport = self:CreateViewport(parent, a, { OnFullscreen = function() full = not full; relayout() end })
	end
	if #list == 0 then
		txt("TextLabel", {
			Text = previewable and "No controls yet. Add some with Asset:Toggle(...) or install the Studio plugin for lighting controls."
				or "No preview available for this asset.",
			TextColor3 = T.dim, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
			Size = U2(1, 0, 0, 44),
		}, cl)
	end
	renderControls(cl, list, pair)
	relayout()
	return function()
		if viewport then
			viewport:Destroy()
		end
	end
end

function M:_buildControlsPage(parent, a)
	local sf = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = U2(1, 0, 1, 0), CanvasSize = U2(0, 0, 0, 0),
		AutomaticCanvasSize = AUTO_Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
	}, parent)
	local c = new("Frame", { BackgroundTransparency = 1, Size = U2(1, -6, 0, 0), AutomaticSize = AUTO_Y }, sf)
	listLayout(c, 10)
	local pair = (self._detailW or 400) >= 420
	local order, any = 0, false
	local function section(title, owner)
		local defs = owner and owner._controls or {}
		if #defs == 0 then
			return
		end
		any = true
		order = order + 1
		local sec = new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = U2(1, 0, 0, 0), AutomaticSize = AUTO_Y }, c)
		listLayout(sec, 6)
		txt("TextLabel", { Text = string.upper(title) .. "  ·  " .. #defs, Font = GB, TextSize = 11, TextColor3 = T.accent, Size = U2(1, 0, 0, 18), LayoutOrder = 0 }, sec)
		renderControls(sec, defs, pair)
	end
	section("This asset", a)
	section("Category · " .. tostring(a.tab and a.tab.Name or ""), a.tab)
	section("Global", self)
	if not any then
		txt("TextLabel", {
			Text = "No controls registered. Plugins and scripts add them with Preview:Toggle / Tab:Dropdown / Asset:ColorPicker …",
			TextColor3 = T.dim, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Size = U2(1, 0, 0, 60),
		}, c)
	end
end

--------------------------------------------------------------------
-- popup menu
--------------------------------------------------------------------
function M:_closeMenu()
	local R = self._R
	if R and R.overlay then
		for _, ch in ipairs(R.overlay:GetChildren()) do ch:Destroy() end
		R.overlay.Visible = false
	end
end

function M:_openMenu(asset, anchor)
	local items = { { Name = "Open", Icon = "play", Callback = function() self:_select(asset) end } }
	for _, act in ipairs(asset.Actions or {}) do
		items[#items + 1] = { Name = tostring(act.Name or "Action"), Icon = act.Icon or "zap", Callback = function() safe(act.Callback, asset) end }
	end
	local more = false
	local function scan(owner)
		for _, d in ipairs(owner and owner._controls or {}) do
			if d.kind == "Button" then
				items[#items + 1] = { Name = tostring(d.o.Name or "Button"), Icon = d.o.Icon or "zap", Callback = function() safe(d.o.Callback, d) end }
			elseif d.kind == "Toggle" then
				items[#items + 1] = { Name = tostring(d.o.Name or "Toggle") .. (d.value and "  ·  On" or "  ·  Off"), Icon = "power", Callback = function() d:Set(not d.value) end }
			elseif d.kind ~= "Label" and d.kind ~= "Divider" then
				more = true
			end
		end
	end
	scan(asset)
	scan(asset.tab)
	if more then
		items[#items + 1] = { Name = "More controls…", Icon = "sliders-horizontal", Callback = function()
			self:_select(asset)
			self:_showDetailPage("controls")
		end }
	end
	self:_openMenuItems(items, anchor)
end

function M:_openMenuItems(items, anchor)
	local R = self._R
	if not R or not anchor or not anchor.Parent then return end
	self:_closeMenu()
	R.overlay.Visible = true
	local catcher = txt("TextButton", { Size = U2(1, 0, 1, 0), ZIndex = 50 }, R.overlay)
	catcher.Activated:Connect(function() self:_closeMenu() end)
	while #items > 9 do
		table.remove(items)
	end
	local k = curScale()
	local w, itemH = 220, 40
	local h = #items * itemH + 12
	local W, H = self:_dims()
	local ap = (anchor.AbsolutePosition - R.overlay.AbsolutePosition) / k
	local asz = anchor.AbsoluteSize / k
	local x = math.clamp(ap.X + asz.X - w, 8, math.max(8, W - w - 8))
	local y = ap.Y + asz.Y + 4
	if y + h > H - 8 then y = math.max(8, ap.Y - h - 4) end
	local menu = new("Frame", { BackgroundColor3 = T.panel, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = 51 }, R.overlay)
	corner(menu, 12)
	stroke(menu, T.border, 1)
	pad(menu, 6, 6, 6, 6)
	listLayout(menu, 0)
	for i, item in ipairs(items) do
		local b = txt("TextButton", { Size = U2(1, 0, 0, itemH), LayoutOrder = i, ZIndex = 52 }, menu)
		corner(b, 8)
		local ic = mkIcon(b, item.Icon or "zap", 16, T.accent)
		ic.Position = UDim2.fromOffset(10, 12)
		ic.ZIndex = 53
		txt("TextLabel", { Text = item.Name, Font = GM, TextSize = 13, Position = UDim2.fromOffset(36, 0), Size = U2(1, -40, 1, 0), ZIndex = 53 }, b)
		b.MouseEnter:Connect(function() if not touchLast() then b.BackgroundTransparency = 0.85; b.BackgroundColor3 = T.accent end end)
		b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
		b.Activated:Connect(function()
			self:_closeMenu()
			safe(item.Callback)
		end)
	end
	zAll(menu, 52)
	menu.ZIndex = 51
end

function M:_openPalette()
	local R = self._R
	if not R then return end
	self:_closeMenu()
	R.overlay.Visible = true
	local W, H = self:_dims()
	local dim = txt("TextButton", { BackgroundTransparency = 0.5, BackgroundColor3 = Color3.new(0, 0, 0), Size = U2(1, 0, 1, 0), ZIndex = 50 }, R.overlay)
	dim.Activated:Connect(function() self:_closeMenu() end)
	local w = math.min(460, W - 24)
	local panel = new("Frame", {
		BackgroundColor3 = T.panel, BorderSizePixel = 0, AnchorPoint = V2(0.5, 0), ClipsDescendants = true, ZIndex = 51,
		Position = U2(0.5, 0, 0, math.floor(math.min(56, H * 0.1))), Size = UDim2.fromOffset(w, 52),
	}, R.overlay)
	corner(panel, 14)
	stroke(panel, T.accent, 1, 0.25)
	local lens = mkIcon(panel, "search", 18, T.accent)
	lens.Position = UDim2.fromOffset(14, 17)
	local box = txt("TextBox", {
		PlaceholderText = "Search pages, assets, plugins…", PlaceholderColor3 = T.dim, TextSize = 14, ClearTextOnFocus = false,
		Position = UDim2.fromOffset(44, 0), Size = U2(1, -56, 0, 52),
	}, panel)
	local results = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 52), Size = U2(1, 0, 0, 0) }, panel)
	listLayout(results, 2)
	pad(results, 6, 6, 2, 6)

	local all = {}
	for _, n in ipairs(NAV) do
		all[#all + 1] = { Name = "Go to " .. n.name, Hint = "Page", Icon = n.icon, Run = function() self:_showPage(n.id) end }
	end
	for _, t in ipairs(self._tabs) do
		all[#all + 1] = { Name = "Open " .. t.Name, Hint = "Category", Icon = t.Icon, Run = function() self:_goto(t) end }
	end
	for _, a in ipairs(self._assets) do
		all[#all + 1] = { Name = a.Name, Hint = tostring(a.Type or "Asset"), Icon = "box", Run = function() self:_select(a) end }
	end
	for _, p in ipairs(self:GetPlugins()) do
		local usable = p.Installed and p.Enabled
		all[#all + 1] = {
			Name = tostring(p.Name), Icon = p.Icon or "blocks",
			Hint = usable and "Plugin · open" or (p.Installed and "Plugin · disabled" or "Plugin · install"),
			Run = function() if usable then self:_openPlugin(p) else self:_showPage("plugins") end end,
		}
	end
	for _, q in ipairs(self._quick) do
		all[#all + 1] = { Name = q.Name, Hint = "Quick action", Icon = q.Icon, Run = function() safe(q.Callback) end }
	end

	local matches = {}
	local function refresh()
		for _, ch in ipairs(results:GetChildren()) do
			if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
		end
		local q = box.Text:lower()
		matches = {}
		for _, item in ipairs(all) do
			if q == "" or item.Name:lower():find(q, 1, true) or item.Hint:lower():find(q, 1, true) then
				matches[#matches + 1] = item
				if #matches >= 7 then break end
			end
		end
		local h = #matches > 0 and (#matches * 42 + 10) or 0
		results.Size = U2(1, 0, 0, h)
		panel.Size = UDim2.fromOffset(w, 52 + h)
		for i, item in ipairs(matches) do
			local b = txt("TextButton", { BackgroundTransparency = i == 1 and 0.8 or 1, BackgroundColor3 = T.accent, Size = U2(1, 0, 0, 40), LayoutOrder = i }, results)
			corner(b, 8)
			local ic = mkIcon(b, item.Icon or "zap", 16, T.accent)
			ic.Position = UDim2.fromOffset(10, 12)
			txt("TextLabel", { Text = item.Name, Font = GM, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(36, 0), Size = U2(1, -150, 1, 0) }, b)
			txt("TextLabel", {
				Text = item.Hint, TextSize = 11, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
				AnchorPoint = V2(1, 0), Position = U2(1, -10, 0, 0), Size = UDim2.fromOffset(104, 40),
			}, b)
			b.Activated:Connect(function()
				self:_closeMenu()
				safe(item.Run)
			end)
		end
		zAll(panel, 52)
		panel.ZIndex = 51
	end
	box:GetPropertyChangedSignal("Text"):Connect(refresh)
	box.FocusLost:Connect(function(enter)
		if enter and matches[1] then
			local run = matches[1].Run
			self:_closeMenu()
			safe(run)
		end
	end)
	refresh()
	box:CaptureFocus()
end

return M
