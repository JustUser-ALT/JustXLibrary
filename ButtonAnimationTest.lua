-- JustXLibrary Button Animation Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/ButtonAnimationTest.lua"))()

local PREFIX = "[Button Animation Test]"
local function log(message) print(PREFIX .. " " .. tostring(message)) end
local function fail(message) warn(PREFIX .. " " .. tostring(message)) end

local function runStep(name, callback)
    local ok, result = pcall(callback)
    if not ok then
        fail(name .. " FAILED: " .. tostring(result))
        return nil
    end
    log(name .. " OK")
    return result
end

log("Starting")

local Library = runStep("Library load", function()
    local source = game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua")
    assert(type(source) == "string" and #source > 0, "JustLib.lua download was empty")
    log("Downloaded JustLib.lua: " .. #source .. " bytes")

    local chunk, compileError = loadstring(source)
    assert(chunk, compileError)
    log("JustLib.lua compile OK")

    local result = chunk()
    assert(type(result) == "table", "JustLib.lua did not return a library table")
    return result
end)
if not Library then return end

local IconsLoaded = runStep("Lucide icon pack load", function()
    local loaded = Library:LoadIconPack()
    assert(loaded == true, "Icon pack request, compilation or initialization failed")
    return loaded
end)
if not IconsLoaded then
    fail("The UI can still be tested, but Lucide icons are unavailable. Check executor HTTP access to molto.pages.dev/source.lua.")
end

local Window = runStep("Window creation", function()
    return Library:Window({
        Title = "Button Animation Test",
        HubId = "JustX_ButtonAnimationTest",
        Config = "JustX_ButtonAnimationTest",
        DebugPerformance = true,
        LoadIcons = false,
    })
end)
if not Window then
    fail("Window was not returned. If a reload confirmation appeared, accept it; otherwise send the log above.")
    return
end

local Tab = runStep("Tab creation", function()
    return Window:Tab({Name = "Animation Tests", Icon = "settings", Type = "Grid"})
end)
if not Tab then return end

local Section = runStep("Section creation", function()
    return Tab:Section({Title = "Input and release feedback"})
end)
if not Section then return end

local clicks = 0
local function addTestButton(name, description)
    local result = runStep("Button creation: " .. name, function()
        return Section:Button({
            Name = name,
            Callback = function()
                clicks = clicks + 1
                log(name .. " callback fired; total clicks=" .. clicks)
            end,
        })
    end)
    if not result or not result.Instance then
        fail("Button instance missing: " .. name)
        return
    end

    local button = result.Instance
    button:GetAttributeChangedSignal("JLButtonState"):Connect(function()
        log(name .. " state=" .. tostring(button:GetAttribute("JLButtonState")))
    end)
    log("Created " .. name .. "; initial state=" .. tostring(button:GetAttribute("JLButtonState") or "Idle"))
end

addTestButton("Tap / Click", "tests Pressed -> Released -> Idle")
addTestButton("Rapid Press", "tests fast repeated input without stuck tweens")
addTestButton("Hold and Release", "tests returning to Idle after a longer press")

log("TEST READY: On Android tap, hold, release and rapidly tap each button. On PC hover, press, release and move away.")
log("Expected states: Touch = Pressed -> Released -> Idle; Mouse = Hover -> Pressed -> Released -> Hover/Idle.")
