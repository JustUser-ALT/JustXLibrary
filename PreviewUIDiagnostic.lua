-- JustXLibrary Legacy Preview diagnostic
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUIDiagnostic.lua"))()

local PREFIX = "[Preview Diagnostic]"
local function log(message)
    print(PREFIX .. " " .. tostring(message))
end
local function fail(stage, err)
    warn(PREFIX .. " FAILED at " .. stage .. ": " .. tostring(err))
end
local function runStage(name, callback)
    log("START " .. name)
    local ok, result = pcall(callback)
    if not ok then
        fail(name, result)
        return false, result
    end
    log("OK " .. name)
    return true, result
end

log("Script execution started.")

local ok, Library = runStage("load JustLib.lua", function()
    local source = game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua")
    assert(type(source) == "string" and #source > 0, "JustLib.lua download was empty")
    local chunk, compileError = loadstring(source)
    assert(chunk, compileError)
    local result = chunk()
    assert(type(result) == "table", "JustLib.lua did not return a library table")
    return result
end)
if not ok then return end

if type(Library.LoadIconPack) == "function" then
    runStage("load icon pack", function()
        Library:LoadIconPack()
    end)
else
    log("SKIP icon pack (method unavailable)")
end

local windowOk, Window = runStage("create Window", function()
    local result = Library:Window({
        Title = "Preview Diagnostic",
        Config = "JustLib_PreviewDiagnostic",
        Width = 560,
        Height = 440,
    })
    assert(result, "Library:Window returned nil")
    return result
end)
if not windowOk then return end

local homeOk = runStage("create HomeTab", function()
    Window:HomeTab({
        WelcomeTitle = "Preview Diagnostic",
        Changelog = {
            {
                Version = "Diagnostic",
                Title = "Legacy Preview",
                Description = "Checking the restored Preview module connection.",
                Changes = { "Stage-by-stage initialization test." },
            },
        },
    })
end)
if not homeOk then return end

local hostOk, HostTab = runStage("create host tab", function()
    local tab = Window:Tab({ Name = "Diagnostic", Icon = "flask-conical" })
    assert(tab, "Window:Tab returned nil")
    return tab
end)
if not hostOk then return end

local sectionOk, Section = runStage("create host section", function()
    local section = HostTab:Section({ Title = "Diagnostic" })
    assert(section, "Tab:Section returned nil")
    return section
end)
if not sectionOk then return end

local previewOk, Preview = runStage("Library:Preview initialization", function()
    local result = Library:Preview({
        Title = "Legacy Preview Diagnostic",
        Icon = "box",
        TabName = "Legacy Preview",
        Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/PreviewUI.lua",
    })
    assert(result, "Library:Preview returned nil")
    assert(not result.IsStub, "Library:Preview returned a stub; check the preceding JustLib warning")
    assert(type(result.Open) == "function", "Preview object has no Open method")
    return result
end)

if previewOk then
    local tabOk, Models = runStage("Preview:Tab", function()
        local tab = Preview:Tab({ Name = "Models", Icon = "box" })
        assert(tab, "Preview:Tab returned nil")
        return tab
    end)

    if tabOk then
        runStage("Models:Asset", function()
            local asset = Models:Asset({
                Name = "Diagnostic Cube",
                Type = "Test Model",
                Description = "A single part used to verify Preview rendering.",
                Build = function(model)
                    local part = Instance.new("Part")
                    part.Name = "DiagnosticPart"
                    part.Anchored = true
                    part.Size = Vector3.new(3, 3, 3)
                    part.Color = Color3.fromRGB(80, 170, 230)
                    part.Parent = model
                end,
            })
            assert(asset, "Models:Asset returned nil")
        end)
    end

    runStage("Preview:Open", function()
        Preview:Open("Models")
    end)
else
    log("Preview UI could not initialize; host window should still be visible.")
end

runStage("create diagnostic button", function()
    Section:Button({
        Name = "Run Preview:Open again",
        Icon = "eye",
        Callback = function()
            runStage("button callback -> Preview:Open", function()
                assert(Preview and not Preview.IsStub, "Preview is unavailable")
                Preview:Open("Models")
            end)
        end,
    })
end)

runStage("create Settings", function()
    Window:Settings()
end)

log("SCRIPT REACHED END. Host window setup completed.")
log("If the screen is still empty, send every console line beginning with " .. PREFIX)
