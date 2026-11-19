-- JustXLibrary InfoPanel Preview Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/InfoPanelTest.lua?v=20261119-02"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua?v=20261119-02"
))()

if not Library then
    warn("[InfoPanel Test] JustXLibrary failed to load.")
    return
end

local Window = Library:Window({
    Title = "InfoPanel Preview",
    Config = "JustLib_InfoPanelPreview",
    Width = 560,
    Height = 460,
})

if not Window then
    warn("[InfoPanel Test] Window creation failed.")
    return
end

-- Grid: numbering stays global even when sections occupy different columns.
local GridTab = Window:Tab({Name = "Grid", Icon = "layout-grid"})
local warning = GridTab:InfoPanel({
    Type = "Warning",
    Text = "Some features may not work correctly in this game. Check the affected sections before using them.",
    Sections = {1, 2, 4},
})

local gridSections = {}
gridSections[1] = GridTab:Section({Title = "Movement"})
gridSections[2] = GridTab:Section({Title = "Visual"})
gridSections[3] = GridTab:MultiSection({
    Title = "Player",
    Pages = {"General", "Extra"},
    Layout = "Segmented",
})
gridSections[4] = GridTab:Section({Title = "Misc"})

-- Every tab starts its own section numbering from 1.
local ListTab = Window:Tab({Name = "List", Icon = "list"})
local danger = ListTab:InfoPanel({
    Type = "Danger",
    Text = "This feature is temporarily unavailable. Do not use the controls in the affected section.",
    Sections = {1},
})
ListTab:Section({Title = "Unavailable feature"})
ListTab:Section({Title = "Other settings"})

local InfoTab = Window:Tab({Name = "Info", Icon = "info"})
local info = InfoTab:InfoPanel({
    Type = "Info",
    Text = "This is a neutral information message. It wraps automatically on narrow screens.",
    Sections = "1",
})
InfoTab:Section({Title = "General information"})

task.wait(0.5)

local function check(name, panel, expectedType, expectedSections)
    if not panel or not panel.Parent then
        warn("[InfoPanel Test] FAIL:", name, "panel was not created.")
        return
    end
    local gotType = panel:GetAttribute("JLInfoType")
    local gotSections = panel:GetAttribute("JLInfoSections")
    if gotType == expectedType and gotSections == expectedSections then
        print("[InfoPanel Test] PASS:", name, gotType, gotSections)
    else
        warn("[InfoPanel Test] FAIL:", name, "got", gotType, gotSections)
    end
end

check("Grid warning", warning, "Warning", "1,2,4")
check("List danger", danger, "Danger", "1")
check("Info", info, "Info", "1")

for i,section in ipairs(gridSections) do
    local index = section.Panel and section.Panel:GetAttribute("JLSectionIndex")
    print("[InfoPanel Test] Grid section", i, "index:", index)
end

Window:Settings()
print("[InfoPanel Test] Loaded. Check all three tabs and mobile text wrapping.")
