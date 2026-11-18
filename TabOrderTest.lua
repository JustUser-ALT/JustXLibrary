-- JustXLibrary Tab Order Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/TabOrderTest.lua?v=20261118-01"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua?v=20261118-01"
))()

if not Library then
    warn("[Tab Order Test] JustXLibrary failed to load.")
    return
end

local Window = Library:Window({
    Title = "Tab Order Test",
    Config = "JustLib_TabOrderTest",
    Width = 520,
    Height = 420,
})

if not Window then
    warn("[Tab Order Test] Window creation failed.")
    return
end

-- Intentionally do not create Home.
-- The first custom tab must open instead of Settings.
local First = Window:Tab({Name = "First", Icon = "house"})
local FirstSection = First:Section({Title = "Initial tab"})
FirstSection:Label({Text = "This tab must be selected automatically."})

local Second = Window:Tab({Name = "Second", Icon = "layers"})
local SecondSection = Second:Section({Title = "Second tab"})
SecondSection:Label({Text = "This tab must remain inactive on startup."})

task.wait(0.5)

local firstVisible = First.Frame.Visible
local secondVisible = Second.Frame.Visible

print("[Tab Order Test] First tab visible:", firstVisible)
print("[Tab Order Test] Second tab visible:", secondVisible)
print("[Tab Order Test] Expected: First = true, Second = false, Settings = last in sidebar.")

if firstVisible and not secondVisible then
    print("[Tab Order Test] PASS: first custom tab opened without Home.")
else
    warn("[Tab Order Test] FAIL: unexpected initial tab selection.")
end
