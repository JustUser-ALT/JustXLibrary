-- JustXLibrary Button Animation Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/ButtonAnimationTest.lua"))()

local PREFIX = "[Button Animation Test]"
local function log(message) print(PREFIX .. " " .. tostring(message)) end
local function fail(message) warn(PREFIX .. " " .. tostring(message)) end

local ok, Library = pcall(function()
    local source = game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua")
    assert(type(source) == "string" and #source > 0, "JustLib.lua download was empty")
    local chunk, compileError = loadstring(source)
    assert(chunk, compileError)
    local result = chunk()
    assert(type(result) == "table", "JustLib.lua did not return a library table")
    return result
end)
if not ok then fail("Library load failed: " .. tostring(Library)); return end

local Window = Library:Window({
    Title = "Button Animation Test",
    Config = "JustX_ButtonAnimationTest",
})
if not Window then fail("Window creation failed"); return end

local Tab = Window:Tab({Name = "Animation Tests", Icon = "mouse-pointer-click"})
local Section = Tab:Section({Title = "Input and release feedback"})
local clicks = 0

local function addTestButton(name, description)
    local result = Section:Button({
        Name = name,
        Callback = function()
            clicks = clicks + 1
            log(name .. " callback fired; total clicks=" .. clicks)
        end,
    })
    assert(result and result.Instance, "Button did not return its Instance: " .. name)
    local button = result.Instance
    button:GetAttributeChangedSignal("JLButtonState"):Connect(function()
        log(name .. " state=" .. tostring(button:GetAttribute("JLButtonState")))
    end)
    log("Created " .. name .. " (" .. description .. "); initial state=" .. tostring(button:GetAttribute("JLButtonState") or "Idle"))
    return button
end

addTestButton("Tap / Click", "tests Pressed -> Released -> Idle")
addTestButton("Rapid Press", "tests fast repeated input without stuck tweens")
addTestButton("Hold and Release", "tests returning to Idle after a longer press")

log("TEST READY: On Android tap, hold, release and rapidly tap each button. On PC hover, press, release and move away.")
log("Expected states: Touch = Pressed -> Released -> Idle; Mouse = Hover -> Pressed -> Released -> Hover/Idle.")
