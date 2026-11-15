-- Preview Plugin Core test
-- Run:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewPluginCoreTest.lua?v=20261116-plugins-7"))()

local ROOT = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/"
local Library = loadstring(game:HttpGet(ROOT .. "JustLib.lua?v=20261116-plugins-7"))()
if not Library then
    warn("[Plugin Core Test] JustLib failed to load")
    return
end

local Window = Library:Window({
    Title = "Preview Plugin Core Test",
    Config = "JustLib_PreviewPluginCoreTest",
})
if not Window then
    warn("[Plugin Core Test] Window creation failed")
    return
end

local Host = Window:Tab({Name = "Plugin Tests", Icon = "plug"})
local Tests = Host:Section({Title = "Plugin Core"})
local Preview = Library:Preview({
    Title = "Plugin Core Test",
    TabName = "Preview",
    Source = ROOT .. "PreviewUI.lua?v=20261116-plugins-7",
})
if not Preview or Preview.IsStub then
    warn("[Plugin Core Test] Preview failed to initialize")
    Tests:Button({
        Name = "Preview initialization failed",
        Icon = "alert-circle",
        Callback = function()
            warn("[Plugin Core Test] Preview is unavailable")
        end,
    })
    Window:Open()
    return
end

local function log(label, ok, result)
    warn("[Plugin Core Test] " .. label .. " => " .. tostring(ok) .. " / " .. tostring(result))
end

local SampleTab = Preview:Tab({Name = "Plugin Samples", Icon = "box"})
local SampleAsset = SampleTab:Asset({
    Name = "Explorer Sample",
    Type = "Model",
    Creator = "JustXLibrary",
    Description = "A small hierarchy used to verify the Explorer plugin.",
    Build = function(model)
        local folder = Instance.new("Folder")
        folder.Name = "Geometry"
        folder.Parent = model

        local block = Instance.new("Part")
        block.Name = "MainBlock"
        block.Size = Vector3.new(4, 2, 4)
        block.Anchored = true
        block.Color = Color3.fromRGB(90, 150, 235)
        block.Parent = folder

        local detail = Instance.new("Part")
        detail.Name = "Detail"
        detail.Size = Vector3.new(1, 3, 1)
        detail.Position = Vector3.new(0, 2, 0)
        detail.Anchored = true
        detail.Parent = block

        local attachment = Instance.new("Attachment")
        attachment.Name = "Pivot"
        attachment.Parent = block
    end,
})

local available = Preview:GetPlugins()
warn("[Plugin Core Test] Available plugins: " .. tostring(#available))
for _, item in ipairs(available) do
    log("Registry " .. tostring(item.Id), item.Id ~= nil and item.Entry ~= nil, tostring(item.Name) .. " v" .. tostring(item.Version))
end

Tests:Button({
    Name = "Test install lifecycle",
    Icon = "download",
    Callback = function()
        for _, item in ipairs(Preview:GetPlugins()) do
            local okInstall, installResult = Preview:InstallPlugin(item.Id)
            log("Install " .. item.Id, okInstall, installResult)
            if okInstall then
                local okDisable, disableResult = Preview:DisablePlugin(item.Id)
                log("Disable " .. item.Id, okDisable, disableResult)
                local okEnable, enableResult = Preview:EnablePlugin(item.Id)
                log("Enable " .. item.Id, okEnable, enableResult)
                local okRemove, removeResult = Preview:UninstallPlugin(item.Id)
                log("Uninstall " .. item.Id, okRemove, removeResult)
            end
        end
    end,
})

Tests:Button({
    Name = "Open Explorer Sample",
    Icon = "network",
    Callback = function()
        Preview:Open(SampleAsset)
    end,
})

Tests:Button({
    Name = "Open Plugins tab",
    Icon = "blocks",
    Callback = function()
        Preview:Open("Plugins")
    end,
})

Tests:Button({
    Name = "Show plugin states",
    Icon = "list",
    Callback = function()
        for _, item in ipairs(Preview:GetPlugins()) do
            log(item.Id, item.Installed, "enabled=" .. tostring(item.Enabled))
        end
    end,
})

Tests:Button({
    Name = "Close Preview",
    Icon = "x",
    Callback = function()
        Preview:Close()
    end,
})

Preview:Open()
Window:Open()
warn("[Plugin Core Test] Loaded. Run 'Test install lifecycle' and inspect output.")
