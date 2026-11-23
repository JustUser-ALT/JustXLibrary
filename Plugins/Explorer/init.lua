-- Explorer plugin 1.0: object tree, live viewport selection, hide / isolate, properties.
local Explorer = {}

local ROW = 30
local MAX_ROWS = 5000

local function iconFor(i)
    if i:IsA("Model") then return "box" end
    if i:IsA("Folder") then return "folder" end
    if i:IsA("BasePart") then return "cuboid" end
    if i:IsA("Humanoid") then return "user-round" end
    if i:IsA("Decal") or i:IsA("Texture") or i:IsA("SurfaceAppearance") then return "image" end
    if i:IsA("JointInstance") then return "bone" end
    if i:IsA("Attachment") then return "crosshair" end
    if i:IsA("ParticleEmitter") or i:IsA("Beam") or i:IsA("Trail") then return "sparkles" end
    if i:IsA("Light") then return "lightbulb" end
    if i:IsA("Accessory") then return "shapes" end
    if i:IsA("Animation") or i:IsA("Animator") or i:IsA("AnimationController") then return "clapperboard" end
    if i:IsA("Sound") then return "volume-2" end
    if i:IsA("LuaSourceContainer") then return "code" end
    return "box"
end

local function fmt(v)
    local t = typeof(v)
    if t == "number" then return (string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")) end
    if t == "Vector3" then return string.format("%.2f, %.2f, %.2f", v.X, v.Y, v.Z) end
    if t == "Color3" then return string.format("#%02X%02X%02X", math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5)) end
    if t == "EnumItem" then return v.Name end
    if t == "Instance" then return v.Name end
    return tostring(v)
end

local function specs(inst)
    local l = { { "Name", "str" }, { "ClassName", "ro" } }
    local function add(...) for _, s in ipairs({ ... }) do l[#l + 1] = s end end
    if inst:IsA("BasePart") then
        add({ "Size", "ro" }, { "Position", "ro" }, { "Orientation", "ro" }, { "Color", "color" }, { "Material", "enum" },
            { "Transparency", "num" }, { "Reflectance", "num" }, { "Anchored", "bool" }, { "CanCollide", "bool" }, { "CastShadow", "bool" })
        if inst:IsA("MeshPart") then add({ "MeshId", "ro" }, { "TextureID", "str" }) end
    end
    if inst:IsA("Model") then add({ "PrimaryPart", "ro" }) end
    if inst:IsA("Humanoid") then add({ "RigType", "ro" }, { "DisplayName", "str" }, { "Health", "num" }, { "MaxHealth", "num" }) end
    if inst:IsA("Decal") or inst:IsA("Texture") then add({ "Texture", "str" }, { "Transparency", "num" }, { "Color3", "color" }, { "Face", "enum" }) end
    if inst:IsA("SpecialMesh") then add({ "MeshType", "enum" }, { "Scale", "ro" }) end
    if inst:IsA("Light") then add({ "Enabled", "bool" }, { "Brightness", "num" }, { "Color", "color" }) end
    if inst:IsA("ParticleEmitter") then add({ "Enabled", "bool" }, { "Rate", "num" }) end
    if inst:IsA("JointInstance") then add({ "Part0", "ro" }, { "Part1", "ro" }) end
    if inst:IsA("Animation") then add({ "AnimationId", "ro" }) end
    if inst:IsA("Accessory") then add({ "AccessoryType", "ro" }) end
    if inst:IsA("Attachment") then add({ "Position", "ro" }) end
    return l
end

function Explorer.Init(context)
    assert(context and context.Preview, "Explorer requires Preview context")
    local preview, ui = context.Preview, context.UI or {}
    local alive, page = true, nil

    local function build(parent, asset)
        if not alive or typeof(asset.Model) ~= "Instance" then return end
        local T, U2, V2 = ui.Theme(), ui.U2, ui.V2
        local make, text, icon, corner, stroke = ui.Create, ui.Text, ui.Icon, ui.Corner, ui.Stroke
        local TS = ui.TweenService

        local state = { selected = nil, expanded = {}, hidden = {}, orig = {}, dim = true, filter = "", segment = "tree" }
        local rows, boxes, cons = {}, {}, {}
        local model, vpObj
        local scroll, propScroll, nameLabel, classLabel, countLabel, renderTree, renderProps, applyDisplay, select

        vpObj = ui.Viewport(parent, asset, { Ground = true, OnClick = function(pos)
            local part = vpObj:PartAt(pos)
            if part and model and part:IsDescendantOf(model) then select(part) end
        end })
        model = vpObj.Model
        if not model then
            vpObj:Destroy()
            text("TextLabel", { Text = "This asset has no model to explore.", TextColor3 = T.dim, TextSize = 12, Size = U2(1, 0, 0, 30) }, parent)
            return
        end
        state.expanded[model] = true

        local function panel(name)
            local f = make("Frame", { Name = name, BackgroundColor3 = T.panel, BorderSizePixel = 0, ClipsDescendants = true }, parent)
            corner(f, 12); stroke(f, T.border, 1, 0.3)
            return f
        end
        local treeP, propP = panel("ExplorerTree"), panel("ExplorerProperties")
        local seg = make("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 34), Visible = false }, parent)
        local segBtns = {}

        local function pathOf(inst)
            local parts, cur = {}, inst
            while cur and cur ~= model.Parent do
                table.insert(parts, 1, cur.Name)
                if cur == model then break end
                cur = cur.Parent
            end
            return table.concat(parts, ".")
        end

        local function effHidden(inst)
            local cur = inst
            while cur do
                if state.hidden[cur] then return true end
                if cur == model then break end
                cur = cur.Parent
            end
            return false
        end

        ---------------- display (hide / dim / selection boxes) ----------------
        local function clearBoxes()
            for _, b in ipairs(boxes) do pcall(function() b:Destroy() end) end
            boxes = {}
        end

        applyDisplay = function()
            local sel = state.selected
            local selParts = {}
            if sel then
                if sel:IsA("BasePart") then selParts[sel] = true end
                for _, d in ipairs(sel:GetDescendants()) do if d:IsA("BasePart") then selParts[d] = true end end
            end
            local dim = state.dim and sel ~= nil and sel ~= model
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BasePart") then
                    if state.orig[d] == nil then state.orig[d] = d.Transparency end
                    local t = state.orig[d]
                    if effHidden(d) then t = 1 elseif dim and not selParts[d] then t = math.max(t, 0.8) end
                    d.Transparency = t
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    if state.orig[d] == nil then state.orig[d] = d.Transparency end
                    local t = state.orig[d]
                    local owner = d.Parent
                    if effHidden(d) then t = 1 elseif dim and owner and owner:IsA("BasePart") and not selParts[owner] then t = math.max(t, 0.8) end
                    d.Transparency = t
                elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") then
                    if state.orig[d] == nil then state.orig[d] = d.Enabled end
                    d.Enabled = state.orig[d] and not effHidden(d)
                end
            end
            clearBoxes()
            if sel and sel ~= model then
                local n = 0
                for part in pairs(selParts) do
                    n = n + 1
                    if n > 120 then break end
                    local b = Instance.new("BoxHandleAdornment")
                    b.Adornee, b.Size, b.Color3 = part, part.Size, T.accent
                    b.Transparency, b.AlwaysOnTop, b.ZIndex = 0.35, true, 1
                    b.Parent = vpObj.Viewport
                    TS:Create(b, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.75 }):Play()
                    boxes[#boxes + 1] = b
                end
            end
        end

        ---------------- tree ----------------
        local function flatten()
            rows = {}
            local q = state.filter:lower()
            local memo = {}
            local function match(inst)
                if memo[inst] ~= nil then return memo[inst] end
                local any = inst.Name:lower():find(q, 1, true) ~= nil or inst.ClassName:lower():find(q, 1, true) ~= nil
                if not any then
                    for _, c in ipairs(inst:GetChildren()) do if match(c) then any = true break end end
                end
                memo[inst] = any
                return any
            end
            local function walk(inst, depth)
                if #rows >= MAX_ROWS or (q ~= "" and not match(inst)) then return end
                rows[#rows + 1] = { inst = inst, depth = depth }
                local kids = inst:GetChildren()
                if #kids > 0 and (state.expanded[inst] or q ~= "") then
                    for _, c in ipairs(kids) do walk(c, depth + 1) end
                end
            end
            walk(model, 0)
            local hiddenCount = 0
            for _ in pairs(state.hidden) do hiddenCount = hiddenCount + 1 end
            countLabel.Text = string.format("%d shown  ·  %d hidden", #rows, hiddenCount)
            scroll.CanvasSize = U2(0, 0, 0, #rows * ROW + 6)
        end

        local drawn = {}
        renderTree = function()
            for _, f in ipairs(drawn) do f:Destroy() end
            drawn = {}
            local k = ui.Scale and ui.Scale() or 1
            local y = scroll.CanvasPosition.Y
            local first = math.max(1, math.floor(y / ROW))
            local last = math.min(#rows, first + math.ceil(scroll.AbsoluteSize.Y / k / ROW) + 2)
            for i = first, last do
                local r = rows[i]
                local inst = r.inst
                local sel, hid = inst == state.selected, effHidden(inst)
                local f = make("TextButton", {
                    Name = "Row", BackgroundColor3 = T.accent, BackgroundTransparency = sel and 0.7 or 1, Text = "", AutoButtonColor = false,
                    Position = U2(0, 2, 0, 3 + (i - 1) * ROW), Size = U2(1, -8, 0, ROW - 2), BorderSizePixel = 0,
                }, scroll)
                corner(f, 6)
                drawn[#drawn + 1] = f
                local x = 4 + r.depth * 14
                local kids = #inst:GetChildren() > 0
                local arrow = text("TextButton", {
                    Text = kids and ((state.expanded[inst] or state.filter ~= "") and "▾" or "▸") or "", TextColor3 = T.dim, TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Center, Position = U2(0, x, 0, 0), Size = U2(0, 18, 1, 0),
                }, f)
                arrow.Activated:Connect(function()
                    if kids then state.expanded[inst] = not state.expanded[inst]; flatten(); renderTree() end
                end)
                local ic = icon(f, iconFor(inst), 15, hid and T.dim or (inst:IsA("BasePart") and Color3.fromRGB(130, 180, 255) or T.accent))
                ic.Position = U2(0, x + 20, 0.5, -7.5)
                text("TextLabel", {
                    Text = inst.Name, TextSize = 12, TextColor3 = hid and T.dim or T.txt, TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = U2(0, x + 40, 0, 0), Size = U2(1, -(x + 40 + 34), 1, 0),
                }, f)
                local eye = text("TextButton", { Text = "", AnchorPoint = V2(1, 0.5), Position = U2(1, -2, 0.5, 0), Size = U2(0, 30, 1, 0) }, f)
                local ei = icon(eye, hid and "eye-off" or "eye", 15, state.hidden[inst] and T.accent or T.dim)
                ei.AnchorPoint, ei.Position = V2(0.5, 0.5), U2(0.5, 0, 0.5, 0)
                eye.Activated:Connect(function()
                    state.hidden[inst] = (not state.hidden[inst]) or nil
                    applyDisplay(); flatten(); renderTree(); renderProps()
                end)
                f.Activated:Connect(function() select(inst) end)
            end
        end

        ---------------- properties ----------------
        local function setProp(inst, name, value)
            local ok = pcall(function() inst[name] = value end)
            if not ok then return false end
            if name == "Transparency" or name == "Enabled" then state.orig[inst] = value end
            if name == "Name" then flatten(); renderTree() end
            applyDisplay()
            renderProps()
            return true
        end

        renderProps = function()
            for _, ch in ipairs(propScroll:GetChildren()) do
                if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
            end
            local inst = state.selected
            if not inst then
                nameLabel.Text, classLabel.Text = "Nothing selected", "Tap a row or the model"
                return
            end
            nameLabel.Text = inst.Name
            classLabel.Text = inst.ClassName .. "  ·  " .. pathOf(inst)
            local order = 0
            local function row(label, kind, current, onSet)
                order = order + 1
                local r = make("Frame", { BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = order, Size = U2(1, 0, 0, 34), ClipsDescendants = true }, propScroll)
                corner(r, 8)
                text("TextLabel", { Text = label, TextSize = 12, TextColor3 = T.dim, Position = U2(0, 10, 0, 0), Size = U2(0.38, -10, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }, r)
                if kind == "bool" then
                    local sw = ui.Switch(r, U2(1, -50, 0.5, -11), current == true)
                    local hit = text("TextButton", { Size = U2(1, 0, 1, 0) }, r)
                    hit.Activated:Connect(function() onSet(not current) end)
                    return sw
                end
                local boxF = make("Frame", { BackgroundColor3 = T.input, BorderSizePixel = 0, AnchorPoint = V2(1, 0.5), Position = U2(1, -6, 0.5, 0), Size = U2(0.62, -8, 0, 26) }, r)
                corner(boxF, 6)
                if kind == "color" then
                    local sw = make("Frame", { BackgroundColor3 = current, BorderSizePixel = 0, Position = U2(0, 6, 0.5, -7), Size = U2(0, 22, 0, 14) }, boxF)
                    corner(sw, 4)
                end
                if kind == "ro" or kind == "enum" then
                    local b = text("TextButton", {
                        Text = fmt(current), TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = kind == "ro" and T.dim or T.txt,
                        Position = U2(0, 8, 0, 0), Size = U2(1, -16, 1, 0),
                    }, boxF)
                    if kind == "enum" and typeof(current) == "EnumItem" then
                        b.Activated:Connect(function()
                            local items = current.EnumType:GetEnumItems()
                            for i, it in ipairs(items) do
                                if it == current then onSet(items[i % #items + 1]) break end
                            end
                        end)
                    end
                    return
                end
                local box = text("TextBox", {
                    Text = fmt(current), TextSize = 12, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = U2(0, kind == "color" and 32 or 8, 0, 0), Size = U2(1, kind == "color" and -38 or -16, 1, 0),
                }, boxF)
                box.FocusLost:Connect(function()
                    if kind == "num" then
                        local n = tonumber(box.Text)
                        if n then onSet(n) else box.Text = fmt(current) end
                    elseif kind == "color" then
                        local r, g, b = box.Text:match("^#?(%x%x)(%x%x)(%x%x)$")
                        if r then onSet(Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))) else box.Text = fmt(current) end
                    else
                        onSet(box.Text)
                    end
                end)
            end
            for _, sp in ipairs(specs(inst)) do
                local ok, value = pcall(function() return inst[sp[1]] end)
                if ok and value ~= nil then
                    local kind = sp[2]
                    if kind ~= "ro" and kind ~= "bool" and (typeof(value) == "Instance") then kind = "ro" end
                    row(sp[1], kind, value, function(v) setProp(inst, sp[1], v) end)
                end
            end
            for key, value in pairs(inst:GetAttributes()) do
                row("@" .. key, "ro", value, function() end)
            end
        end

        select = function(inst)
            state.selected = inst
            if inst then
                local p = inst.Parent
                while p and p ~= model.Parent do state.expanded[p] = true; p = p.Parent end
            end
            flatten()
            if inst then
                for i, r in ipairs(rows) do
                    if r.inst == inst then
                        scroll.CanvasPosition = Vector2.new(0, math.max(0, (i - 3) * ROW))
                        break
                    end
                end
            end
            renderTree(); renderProps(); applyDisplay()
        end

        ---------------- tree panel chrome ----------------
        local bar = make("Frame", { BackgroundTransparency = 1, Position = U2(0, 8, 0, 8), Size = U2(1, -16, 0, 34) }, treeP)
        local searchF = make("Frame", { BackgroundColor3 = T.input, BorderSizePixel = 0, Size = U2(1, -128, 1, 0) }, bar)
        corner(searchF, 8)
        local lens = icon(searchF, "search", 14, T.dim); lens.Position = U2(0, 8, 0.5, -7)
        local search = text("TextBox", { PlaceholderText = "Search objects…", PlaceholderColor3 = T.dim, TextSize = 12, ClearTextOnFocus = false, Position = U2(0, 28, 0, 0), Size = U2(1, -34, 1, 0) }, searchF)
        search:GetPropertyChangedSignal("Text"):Connect(function() state.filter = search.Text; flatten(); renderTree() end)
        local function tbtn(i, name, fn)
            local b = ui.IconButton(bar, name, 30, fn)
            b.AnchorPoint, b.Position = V2(1, 0), U2(1, -(3 - i) * 32 - 0, 0, 2)
            return b
        end
        tbtn(3, "chevrons-down", function()
            for _, d in ipairs(model:GetDescendants()) do if #d:GetChildren() > 0 then state.expanded[d] = true end end
            flatten(); renderTree()
        end)
        tbtn(2, "chevrons-up", function() state.expanded = { [model] = true }; flatten(); renderTree() end)
        tbtn(1, "eye", function() state.hidden = {}; applyDisplay(); flatten(); renderTree(); renderProps() end)
        scroll = make("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0, Position = U2(0, 0, 0, 48), Size = U2(1, 0, 1, -72),
            CanvasSize = U2(0, 0, 0, 0), ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim, ScrollingDirection = Enum.ScrollingDirection.Y,
        }, treeP)
        countLabel = text("TextLabel", { Text = "", TextSize = 11, TextColor3 = T.dim, AnchorPoint = V2(0, 1), Position = U2(0, 12, 1, -4), Size = U2(1, -24, 0, 18) }, treeP)
        cons[#cons + 1] = scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function() renderTree() end)

        ---------------- properties panel chrome ----------------
        nameLabel = text("TextLabel", { Font = ui.Fonts.Bold, TextSize = 14, Position = U2(0, 12, 0, 8), Size = U2(1, -24, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd }, propP)
        classLabel = text("TextLabel", { TextSize = 11, TextColor3 = T.dim, Position = U2(0, 12, 0, 26), Size = U2(1, -24, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, propP)
        local acts = make("Frame", { BackgroundTransparency = 1, Position = U2(0, 8, 0, 48), Size = U2(1, -16, 0, 70) }, propP)
        make("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, CellSize = U2(1 / 3, -4, 0, 32), CellPadding = UDim2.fromOffset(6, 6) }, acts)
        local _
        local function act(order, label, ic, fn)
            local b, lb = ui.Button(acts, { Text = label, Icon = ic, Order = order, Callback = fn })
            return b, lb
        end
        local dimLabel
        act(1, "Focus", "scan", function() if state.selected then vpObj:Focus(state.selected) end end)
        act(2, "Hide", "eye-off", function()
            local s = state.selected
            if s then state.hidden[s] = (not state.hidden[s]) or nil; applyDisplay(); flatten(); renderTree(); renderProps() end
        end)
        act(3, "Isolate", "crosshair", function()
            local s = state.selected
            if not s or s == model then return end
            state.hidden = {}
            local child, cur = s, s.Parent
            while cur and child ~= model do
                for _, sib in ipairs(cur:GetChildren()) do if sib ~= child then state.hidden[sib] = true end end
                child, cur = cur, cur.Parent
            end
            applyDisplay(); flatten(); renderTree(); renderProps()
        end)
        act(4, "Delete", "trash", function()
            local s = state.selected
            if not s or s == model then return end
            state.hidden[s], state.selected = nil, s.Parent
            s:Destroy()
            flatten(); renderTree(); renderProps(); applyDisplay()
        end)
        act(5, "Path", "copy", function()
            local s = state.selected
            if s and type(setclipboard) == "function" then
                pcall(setclipboard, pathOf(s))
                ui.Notify({ Title = "Explorer", Desc = "Path copied", Type = "Success", Duration = 2 })
            elseif s then
                ui.Notify({ Title = "Explorer", Desc = pathOf(s), Type = "Info", Duration = 5 })
            end
        end)
        _, dimLabel = act(6, "Dim: on", "layers", function()
            state.dim = not state.dim
            dimLabel.Text = state.dim and "Dim: on" or "Dim: off"
            applyDisplay()
        end)
        propScroll = make("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0, Position = U2(0, 8, 0, 124), Size = U2(1, -16, 1, -132),
            CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
        }, propP)
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, propScroll)

        vpObj:AddButton("refresh", function()
            vpObj:SetModel(nil)
            model = vpObj.Model
            state.expanded, state.hidden, state.orig, state.selected = { [model] = true }, {}, {}, nil
            boxes = {}
            flatten(); renderTree(); renderProps()
        end)

        ---------------- adaptive layout ----------------
        local function showSegment(name)
            state.segment = name
            for n, b in pairs(segBtns) do
                b.BackgroundColor3 = n == name and T.cardHi or T.card
                b.TextColor3 = n == name and T.txt or T.dim
            end
            local map = { tree = treeP, view = vpObj.Frame, props = propP }
            for n, f in pairs(map) do f.Visible = n == name end
        end
        for i, def in ipairs({ { "tree", "Tree" }, { "view", "Preview" }, { "props", "Properties" } }) do
            local b = text("TextButton", {
                BackgroundTransparency = 0, BackgroundColor3 = T.card, Text = def[2], Font = ui.Fonts.Medium, TextSize = 12, TextColor3 = T.dim,
                TextXAlignment = Enum.TextXAlignment.Center, Position = U2((i - 1) / 3, i == 1 and 0 or 3, 0, 0), Size = U2(1 / 3, i == 2 and -6 or -3, 1, -4),
            }, seg)
            corner(b, 10)
            b.Activated:Connect(function() showSegment(def[1]) end)
            segBtns[def[1]] = b
        end
        local function layout()
            local k = ui.Scale and ui.Scale() or 1
            local w = parent.AbsoluteSize.X / k
            if w >= 700 then
                seg.Visible = false
                local tw_, pw = math.clamp(math.floor(w * 0.3), 210, 300), math.clamp(math.floor(w * 0.3), 230, 330)
                treeP.Position, treeP.Size = U2(0, 0, 0, 0), U2(0, tw_, 1, 0)
                vpObj.Frame.Position, vpObj.Frame.Size = U2(0, tw_ + 8, 0, 0), U2(1, -(tw_ + pw + 16), 1, 0)
                propP.Position, propP.Size = U2(1, -pw, 0, 0), U2(0, pw, 1, 0)
                treeP.Visible, vpObj.Frame.Visible, propP.Visible = true, true, true
            else
                seg.Visible = true
                for _, f in ipairs({ treeP, vpObj.Frame, propP }) do
                    f.Position, f.Size = U2(0, 0, 0, 40), U2(1, 0, 1, -40)
                end
                showSegment(state.segment)
            end
            renderTree()
        end
        cons[#cons + 1] = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

        flatten(); renderProps(); layout(); applyDisplay()
        return function()
            for _, c in ipairs(cons) do pcall(function() c:Disconnect() end) end
            clearBoxes()
            vpObj:Destroy()
        end
    end

    page = preview:Page({
        Name = "Explorer", Icon = "folder-tree",
        Visible = function(asset) return asset ~= nil and typeof(asset.Model) == "Instance" end,
        Build = build,
    })
    return { Destroy = function()
        if not alive then return end
        alive = false
        if page then preview:RemovePage(page); page = nil end
    end }
end

return { Manifest = { Id = "explorer", Name = "Explorer", Version = "1.0.0", ApiVersion = 1 }, Init = Explorer.Init }
