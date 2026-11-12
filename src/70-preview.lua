-- ===== Preview UI loader =====
JL.PreviewSource = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/PreviewUI.lua"
-- Если файл не нашёлся или сломан, показываем, ЧТО именно пришло (строка с ошибкой, размер, начало файла)
local function previewDiag(body, err)
    local info = ""
    local ln = tonumber(tostring(err):match(":(%d+):"))
    if ln then
        local i = 0
        for line in (body .. "\n"):gmatch("([^\n]*)\n") do
            i = i + 1
            if i == ln then info = " | line " .. ln .. ": " .. line:sub(1, 70); break end
        end
    end
    return tostring(err) .. info .. " | " .. #body .. " bytes, starts with: " .. body:sub(1, 40):gsub("%s+", " ")
end
local function loadPreviewModule(src)
    if type(src) == "table" then return src end
    if type(src) == "function" then local ok,m = pcall(src); if ok then return m end return nil, tostring(m) end
    local body, how
    if type(src) == "string" then
        if src:match("^https?://") then
            how = "url"
            local ok,r = pcall(function() return game:HttpGet(src) end)
            if ok then body = r else return nil, "download failed (" .. tostring(r) .. "). Check JL.PreviewSource: " .. src end
        elseif readfile then
            how = "file"
            local ok,r = pcall(readfile, src); if ok then body = r else return nil, "file not found: " .. src end
        end
    end
    if not body or body == "" then return nil, "empty source: " .. tostring(src) end
    body = body:gsub("^\239\187\191", "")
    local head = body:sub(1, 200):lower()
    if body:sub(1, 1) == "<" or head:match("^404") or head:match("not found") then
        return nil, "the server returned a web page / 404 instead of PreviewUI.lua. Check JL.PreviewSource: " .. tostring(src)
    end
    local fn,err = loadstring(body)
    if not fn then return nil, previewDiag(body, err) end
    local ok,mod = pcall(fn)
    if not ok or type(mod) ~= "table" then return nil, tostring(mod) end
    return mod
end
-- Заглушка: если Preview не загрузился, остальной скрипт продолжает работать (вызовы просто ничего не делают)
local function previewStub()
    local function ghost()
        local t = {}
        setmetatable(t, {__index = function() return ghost() end, __call = function() return ghost() end})
        return t
    end
    local stub = ghost()
    rawset(stub, "IsStub", true); rawset(stub, "alive", false)
    return stub
end
function JL:Preview(popts)
    popts = popts or {}
    if JL._preview and JL._preview.alive then return JL._preview end
    local mod,err = loadPreviewModule(popts.Source or JL.PreviewSource)
    if not mod or not mod.new then
        warn("[JustLib] Could not load PreviewUI: " .. tostring(err))
        JL:Notify({Title = "Preview UI", Desc = "Could not load PreviewUI: " .. tostring(err), Type = "Error", Duration = 9})
        return previewStub()
    end
    local ok,obj = pcall(mod.new, JL._bridge, popts)
    if not ok then
        warn("[JustLib] PreviewUI init failed: " .. tostring(obj))
        JL:Notify({Title = "Preview UI", Desc = "Init failed: " .. tostring(obj), Type = "Error", Duration = 9})
        return previewStub()
    end
    JL._preview = obj
    return obj
end
function JL:GetPreview() return JL._preview end
local function hubGuiName(hubId, remote)
    return scopedGuiName(remote and "Remote" or "Main", hubId)
end
local function removeOrphanedHubGuis(hubId)
    -- Only clean roots belonging to this identity; never remove another hub's UI.
    local prefix = "JL_" .. safeFileName(hubId) .. "_"
    local names = {
        [hubGuiName(hubId, false)] = true,
        [hubGuiName(hubId, true)] = true
    }
    if hubId == "JustLib" then
        names.JustLib = true
        names.JLRemote = true
    end
    local containers = {}
    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and core then containers[#containers + 1] = core end
    if PG then containers[#containers + 1] = PG end
    for _, container in ipairs(containers) do
        pcall(function()
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("ScreenGui") and (names[child.Name] or child.Name:sub(1, #prefix) == prefix) then
                    child:Destroy()
                end
            end
        end)
    end
end
local refreshWorkspaceTabs
local function showWorkspaceCloseDialog()
    refreshWorkspaceTabs()
    local gui = _workspace.HubTabsGui
    if not gui or not gui.Parent then return false end
    local activeId = _workspace.ActiveHubId
    local activeEntry = activeId and _workspace.Hubs[activeId]
    if not activeEntry or not activeEntry.alive then return false end
    local old = _workspace.CloseDialogFrame
    if old then pcall(function() old:Destroy() end) end

    local overlay = Instance.new("Frame")
    overlay.Name = "CloseHubDialog"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.42
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 20
    overlay.Parent = gui
    _workspace.CloseDialogFrame = overlay

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.Size = UDim2.new(0, 300, 0, 166)
    panel.BackgroundColor3 = Color3.fromRGB(34, 36, 43)
    panel.BorderSizePixel = 0
    panel.ZIndex = 21
    panel.Parent = overlay
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panel
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(75, 80, 94)
    panelStroke.Parent = panel

    local heading = Instance.new("TextLabel")
    heading.BackgroundTransparency = 1
    heading.Position = UDim2.new(0, 14, 0, 13)
    heading.Size = UDim2.new(1, -28, 0, 24)
    heading.Font = Enum.Font.GothamBold
    heading.Text = "Close Library"
    heading.TextSize = 16
    heading.TextColor3 = Color3.fromRGB(245, 246, 250)
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.ZIndex = 22
    heading.Parent = panel

    local description = Instance.new("TextLabel")
    description.BackgroundTransparency = 1
    description.Position = UDim2.new(0, 14, 0, 42)
    description.Size = UDim2.new(1, -28, 0, 38)
    description.Font = Enum.Font.Gotham
    description.Text = "Choose what you want to close."
    description.TextSize = 12
    description.TextColor3 = Color3.fromRGB(170, 175, 187)
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.ZIndex = 22
    description.Parent = panel

    local function makeChoice(name, textValue, x, width, color, callback)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Position = UDim2.new(0, x, 1, -48)
        button.Size = UDim2.new(0, width, 0, 34)
        button.BackgroundColor3 = color
        button.BorderSizePixel = 0
        button.Text = textValue
        button.Font = Enum.Font.GothamSemibold
        button.TextSize = 11
        button.TextColor3 = Color3.fromRGB(245, 246, 250)
        button.ZIndex = 22
        button.Parent = panel
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = button
        button.MouseButton1Click:Connect(function()
            if _workspace.CloseDialogFrame == overlay then
                _workspace.CloseDialogFrame = nil
            end
            overlay:Destroy()
            callback()
        end)
    end

    makeChoice("CloseCurrent", "This Hub", 12, 84, Color3.fromRGB(62, 105, 174), function()
        if activeEntry.alive and type(activeEntry.destroy) == "function" then
            pcall(activeEntry.destroy)
        end
        refreshWorkspaceTabs()
    end)
    makeChoice("CloseAll", "All Hubs", 108, 84, Color3.fromRGB(165, 62, 70), function()
        local snapshot = {}
        for _, item in pairs(_workspace.Hubs) do
            if item and item.alive then snapshot[#snapshot + 1] = item end
        end
        for _, item in ipairs(snapshot) do
            if item.alive and type(item.destroy) == "function" then pcall(item.destroy) end
        end
        refreshWorkspaceTabs()
    end)
    makeChoice("Cancel", "Cancel", 204, 84, Color3.fromRGB(58, 61, 70), function() end)
    return true
end

refreshWorkspaceTabs = function()
    local entries = {}
    for id, entry in pairs(_workspace.Hubs) do
        if entry and entry.alive then
            entries[#entries + 1] = {Id = id, Entry = entry}
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.Entry.Title or a.Id):lower() < tostring(b.Entry.Title or b.Id):lower()
    end)

    local gui = _workspace.HubTabsGui
    if #entries < 1 then
        if gui then pcall(function() gui:Destroy() end) end
        _workspace.HubTabsGui = nil
        _workspace.HubTabsFrame = nil
        _workspace.CloseDialogFrame = nil
        return
    end

    local existingBar = _workspace.HubTabsFrame
    if gui and gui.Parent and (not existingBar or not existingBar.Parent) then
        pcall(function() gui:Destroy() end)
        gui = nil
        _workspace.HubTabsGui = nil
        _workspace.HubTabsFrame = nil
    end

    if not gui or not gui.Parent then
        gui = Instance.new("ScreenGui")
        gui.Name = "JL_WorkspaceTabs"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 10000
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local okCore, core = pcall(function() return game:GetService("CoreGui") end)
        if okCore and core then
            local okParent = pcall(function() gui.Parent = core end)
            if not okParent or not gui.Parent then gui.Parent = PG end
        else
            gui.Parent = PG
        end

        local bar = Instance.new("Frame")
        bar.Name = "HubTabs"
        bar.AnchorPoint = Vector2.new(0.5, 1)
        bar.Position = UDim2.new(0.5, 0, 0, -7)
        bar.Size = UDim2.new(0, 300, 0, 32)
        bar.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
        bar.BackgroundTransparency = 0.08
        bar.BorderSizePixel = 0
        bar.ClipsDescendants = true
        bar.ZIndex = 90
        bar.Parent = gui
        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(0, 9)
        barCorner.Parent = bar
        local barStroke = Instance.new("UIStroke")
        barStroke.Color = Color3.fromRGB(78, 86, 105)
        barStroke.Transparency = 0.32
        barStroke.Thickness = 1
        barStroke.Parent = bar

        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "HubList"
        scroll.Position = UDim2.new(0, 5, 0, 4)
        scroll.Size = UDim2.new(1, -10, 1, -8)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 2
        scroll.ScrollBarImageColor3 = Color3.fromRGB(105, 137, 190)
        scroll.ScrollingDirection = Enum.ScrollingDirection.X
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
        scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
        scroll.ZIndex = 91
        scroll.Parent = bar
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 4)
        layout.Parent = scroll
        local listPadding = Instance.new("UIPadding")
        listPadding.PaddingLeft = UDim.new(0, 1)
        listPadding.PaddingRight = UDim.new(0, 1)
        listPadding.Parent = scroll

        _workspace.HubTabsGui = gui
        _workspace.HubTabsFrame = bar
    end

    local bar = _workspace.HubTabsFrame
    if not bar or not bar.Parent then return end
    local activeEntry = _workspace.ActiveHubId and _workspace.Hubs[_workspace.ActiveHubId]
    local activeWindow = activeEntry and activeEntry.win
    local activeOpen = activeEntry and type(activeEntry.isOpen) == "function" and activeEntry.isOpen() == true
    if activeWindow and activeWindow.Parent then
        bar.Parent = activeWindow
        local windowWidth = activeWindow.Size.X.Offset
        bar.Size = UDim2.new(0, math.clamp(windowWidth - 24, 210, 340), 0, 32)
        bar.Position = UDim2.new(0.5, 0, 0, -7)
    else
        bar.Parent = gui
    end
    bar.Visible = #entries >= 2 and activeWindow ~= nil and activeOpen
    local scroll = bar:FindFirstChild("HubList")
    if not scroll then return end
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    for index, item in ipairs(entries) do
        local entry = item.Entry
        local active = item.Id == _workspace.ActiveHubId
        local title = tostring(entry.Title or item.Id)
        local button = Instance.new("TextButton")
        button.Name = "Hub_" .. tostring(index)
        button.LayoutOrder = index
        button.Size = UDim2.new(0, math.clamp(#title * 6 + 24, 82, 142), 1, -1)
        button.BackgroundColor3 = active and Color3.fromRGB(48, 67, 101) or Color3.fromRGB(35, 38, 46)
        button.BackgroundTransparency = active and 0 or 0.18
        button.BorderSizePixel = 0
        button.Text = title
        button.Font = Enum.Font.GothamSemibold
        button.TextSize = 11
        button.TextColor3 = active and Color3.fromRGB(225, 236, 255) or Color3.fromRGB(180, 185, 198)
        button.TextTruncate = Enum.TextTruncate.AtEnd
        button.ZIndex = 92
        button.Parent = scroll
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 7)
        buttonCorner.Parent = button
        if active then
            local activeStroke = Instance.new("UIStroke")
            activeStroke.Color = Color3.fromRGB(104, 151, 224)
            activeStroke.Transparency = 0.35
            activeStroke.Thickness = 1
            activeStroke.Parent = button
        end
        button.MouseButton1Click:Connect(function()
            if _workspace.ActiveHubId == item.Id then return end
            if _workspace.Hubs[item.Id] and _workspace.Hubs[item.Id].alive then
                _workspace.SetActiveHub(item.Id, true)
                refreshWorkspaceTabs()
            end
        end)
    end
end
