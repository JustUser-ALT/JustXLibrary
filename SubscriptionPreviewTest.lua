-- JustXLibrary Subscription UI Preview Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/SubscriptionPreviewTest.lua?v=20261119-01"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua?v=20261119-01"
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

local tiers = {
    {Name="Free", Prefix="FREE", Tagline="A place to start", Description="The essential JustXLibrary experience.", Perks={"Core library access", "Standard interface customization"}, Color=Color3.fromRGB(112,125,148), Icon="sprout"},
    {Name="Premium", Prefix="PREM", Tagline="More room to create", Description="An expanded experience for regular creators.", Perks={"Extended customization concepts", "Premium profile identity"}, Color=Color3.fromRGB(80,145,255), Icon="zap"},
    {Name="Elite", Prefix="ELITE", Tagline="Built for power users", Description="A higher-tier concept for advanced users.", Perks={"Advanced feature concepts", "Exclusive interface themes"}, Color=Color3.fromRGB(166,105,255), Icon="crown"},
    {Name="Discord Booster", Prefix="BOOST", Tagline="Support the community", Description="A recognition tier for community supporters.", Perks={"Booster recognition", "Community supporter identity"}, Color=Color3.fromRGB(190,112,255), Icon="messages-square"},
    {Name="Contributor", Prefix="CONTRIB", Tagline="Help build JustX", Description="For people who contribute to the project.", Perks={"Contributor recognition", "Early preview concepts"}, Color=Color3.fromRGB(65,190,155), Icon="code-2"},
    {Name="Founder", Prefix="FOUNDER", Tagline="A part of the beginning", Description="A special concept for founding supporters.", Perks={"Founder recognition", "Legacy supporter identity"}, Color=Color3.fromRGB(230,175,82), Icon="flag"},
}

-- Preview-only link. Replace this with your own key page when testing a real project.
Library:Subscriptions({
    GetKeyURL = "https://example.com/getkey",
    File = "JustLib_SubscriptionPreviewTest",
    Tiers = tiers,
})

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
else
    warn("[Subscription Preview Test] Subscription badge not found.")
end

Library:OpenSubscriptions()
task.wait(0.6)

local titleFound, selectorCount, detailFound, activationButtonFound = false, 0, false, false
for _,root in ipairs(guiRoots) do
    for _,obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Text == "Choose your level" then titleFound = true end
        if obj.Name:match("^Tier_%d+$") and obj:IsA("TextButton") then selectorCount = selectorCount + 1 end
        if obj.Name == "TierDetails" and obj:IsA("ScrollingFrame") then detailFound = true end
        if obj:IsA("TextButton") and obj.Text == "Enter activation key   →" then activationButtonFound = true end
    end
end

if selectorCount == 6 and detailFound then
    print("[Subscription Preview Test] PASS: six tiers and detail panel found.")
else
    warn("[Subscription Preview Test] FAIL: selectors =", selectorCount, "detail panel =", detailFound)
end
if titleFound then
    print("[Subscription Preview Test] PASS: subscription screen opened.")
else
    warn("[Subscription Preview Test] FAIL: subscription screen title not found.")
end
if activationButtonFound then
    print("[Subscription Preview Test] PASS: activation action is visible.")
else
    warn("[Subscription Preview Test] Activation action was not detected in the initial view.")
end
