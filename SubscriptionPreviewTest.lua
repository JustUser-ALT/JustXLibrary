-- JustXLibrary Subscription UI Preview Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/SubscriptionPreviewTest.lua?v=20261118-04"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua?v=20261118-04"
))()

if not Library then
    warn("[Subscription Preview Test] JustXLibrary failed to load.")
    return
end

local Window = Library:Window({
    Title = "Subscription Preview Test",
    Config = "JustLib_SubscriptionPreviewTest",
    Width = 560,
    Height = 420,
})

if not Window then
    warn("[Subscription Preview Test] Window creation failed.")
    return
end

-- Deliberately do not call Library:Subscriptions().
-- The built-in demo catalog should still open.
local guiRoots = {
    game:GetService("CoreGui"),
    game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),
}

local badge
for _,root in ipairs(guiRoots) do
    for _,obj in ipairs(root:GetDescendants()) do
        if obj.Name == "JLSubscriptionBadge" and obj:IsA("TextButton") then
            badge = obj
            break
        end
    end
    if badge then break end
end

if badge then
    print("[Subscription Preview Test] Badge width:", badge.Size.X.Offset)
    print("[Subscription Preview Test] Expected badge width: at least 64 px.")
else
    warn("[Subscription Preview Test] Subscription badge not found.")
end

Library:OpenSubscriptions()
task.wait(0.6)

local previewFound = false
for _,root in ipairs(guiRoots) do
    for _,obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Text == "Choose your level" then
            previewFound = true
            break
        end
    end
    if previewFound then break end
end

local selectorCount = 0
local detailFound = false
for _,root in ipairs(guiRoots) do
    for _,obj in ipairs(root:GetDescendants()) do
        if obj.Name:match("^Tier_%d+$") and obj:IsA("TextButton") then selectorCount = selectorCount + 1 end
        if obj.Name == "TierDetails" and obj:IsA("Frame") then detailFound = true end
    end
end

if selectorCount == 6 and detailFound then
    print("[Subscription Preview Test] PASS: all six tier selectors and the detail panel are present.")
else
    warn("[Subscription Preview Test] FAIL: selector count =", selectorCount, "detail panel =", detailFound)
end

if previewFound then
    print("[Subscription Preview Test] PASS: redesigned subscription screen opened without configuration.")
else
    warn("[Subscription Preview Test] FAIL: redesigned subscription screen title was not found.")
end
