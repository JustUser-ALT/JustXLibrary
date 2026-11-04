--==================================================
-- JUSTLIB ICON PACK / MOLTO ADAPTER TEST
-- Executor test: structured assets, Lucide names, fallback and refresh
--==================================================

local LibraryURL = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local JL = loadstring(game:HttpGet(LibraryURL))()

local Window = JL:Window({
    Name = "JustLib Icon Adapter Test",
    Config = "JustLib_IconAdapterTest",
    Settings = true,
    DebugPerformance = true,
})

if not Window then
    warn("[Icon Test] Window creation was cancelled.")
    return
end

local Tab = Window:Tab({
    Name = "Icons",
    Icon = "images",
    Type = "Grid",
})

local Section = Tab:Section({
    Title = "Molto / Lucide",
    Column = 1,
})

local iconNames = {
    "house",
    "moon",
    "settings",
    "heart",
    "shield",
    "search",
    "folder",
    "message-circle",
    "gamepad-2",
    "not-a-real-lucide-icon",
}

for _,name in ipairs(iconNames) do
    Section:Button({
        Name = "Icon: " .. name,
        Icon = name,
        Callback = function()
            print("[Icon Test] Clicked:", name)
        end,
    })
end

local function inspectIcons()
    local root = JL._activeWin
    local total, images, cropped, brokenText = 0, 0, 0, 0
    if root then
        for _,obj in ipairs(root:GetDescendants()) do
            if obj:IsA("TextLabel") and obj:FindFirstChild("JLIconAsset") then
                total = total + 1
                local image = obj.JLIconAsset
                if image:IsA("ImageLabel") and image.Image ~= "" then
                    images = images + 1
                    if image.ImageRectSize.X > 0 and image.ImageRectSize.Y > 0 then
                        cropped = cropped + 1
                    end
                end
            end
            if obj:IsA("TextLabel") and obj.Text:match("^table: 0x") then
                brokenText = brokenText + 1
            end
        end
    end
    print("[Icon Test] Image-backed icon nodes:", total)
    print("[Icon Test] Image URLs assigned:", images)
    print("[Icon Test] Atlas-cropped icons:", cropped)
    print("[Icon Test] Invalid table-address labels (expected 0):", brokenText)
    print("[Icon Test] Molto loaded:", JL._iconPack ~= nil)
end

Section:Button({
    Name = "Reload Molto Icon Pack",
    Callback = function()
        local ok = JL:LoadIconPack()
        print("[Icon Test] LoadIconPack:", ok)
        task.delay(0.25, inspectIcons)
    end,
})

Section:Button({
    Name = "Refresh Lucide Provider",
    Callback = function()
        JL:SetIconType("lucide")
        task.delay(0.25, inspectIcons)
    end,
})

Section:Button({
    Name = "Inspect Rendered Icons",
    Callback = inspectIcons,
})

task.delay(2, inspectIcons)

print("[Icon Test] Loaded. Check the icons, then press Inspect Rendered Icons.")
