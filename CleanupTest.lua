--==================================================
-- JUSTLIB CLEANUP MANAGER TEST
-- Local executor test: Unload / Reload resource cleanup
--==================================================

local Players = game:GetService("Players")

local LibraryURL = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local JL = loadstring(game:HttpGet(LibraryURL))()

local Window = JL:Window({
    Name = "JustLib Cleanup Test",
    Config = "JustLib_CleanupTest",
    Settings = true,
})

if not Window then
    warn("[Cleanup Test] Window creation was cancelled.")
    return
end

local Tab = Window:Tab({
    Name = "Cleanup",
    Icon = "trash-2",
    Type = "Grid",
})

local Section = Tab:Section({
    Title = "Resource Tracking",
    Column = 1,
})

local PrivacySection = Tab:Section({
    Title = "Streamer Mode",
    Column = 2,
})

local function makePrivacyLabel(name,text)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.Parent = game:GetService("CoreGui")
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromOffset(320,32)
    label.Position = UDim2.fromOffset(20,20)
    label.BackgroundTransparency = 0
    label.Text = text
    label.Parent = gui
    return gui,label
end

local privacyGui,privacyLabel = makePrivacyLabel("JL_StreamerModeTest", "Player: " .. Players.LocalPlayer.DisplayName .. " (@" .. Players.LocalPlayer.Name .. ")")
local privacyAvatar = Instance.new("ImageLabel")
privacyAvatar.Name = "StreamerModeTestAvatar"
privacyAvatar.Size = UDim2.fromOffset(48,48)
privacyAvatar.Position = UDim2.fromOffset(350,20)
privacyAvatar.BackgroundTransparency = 0
privacyAvatar.Parent = privacyGui
task.spawn(function()
    local ok,content = pcall(function()
        return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    end)
    if ok and privacyAvatar.Parent then privacyAvatar.Image = content end
end)

PrivacySection:Toggle({
    Name = "Streamer Mode Test",
    Default = false,
    Callback = function(value)
        JL:SetStreamerMode(value)
        print("[Cleanup Test] Streamer Mode:", JL:GetStreamerMode())
    end,
})
PrivacySection:Button({
    Name = "Update Test Name",
    Callback = function()
        privacyLabel.Text = "Leaderboard: " .. Players.LocalPlayer.Name
        print("[Cleanup Test] Updated test label. Streamer Mode should mask it if enabled.")
    end,
})
PrivacySection:Button({
    Name = "Remove Test Label",
    Callback = function()
        if privacyGui then privacyGui:Destroy(); privacyGui = nil; privacyAvatar = nil end
    end,
})


-- These controls are eligible for player pinning through Settings > Remote > Edit Remote Items.
Section:Toggle({
    Name = "Remote Test Toggle",
    Flag = "CleanupTest_RemoteToggle",
    Default = false,
    Remote = {Name = "Cleanup Toggle"},
    Callback = function(value)
        print("[Cleanup Test] Remote toggle:", value)
    end,
})

Section:Button({
    Name = "Remote Test Button",
    Remote = {Name = "Cleanup Button"},
    Callback = function()
        print("[Cleanup Test] Remote button pressed.")
    end,
})

local trackedFolder
local loopTicks = 0
local delayedCallbackFired = false

-- This connection should be disconnected by JL:Unload().
JL:Connect(Players.PlayerAdded, function(player)
    print("[Cleanup Test] Player joined:", player.Name)
end)

-- This loop should be cancelled by JL:Unload().
JL:Spawn(function()
    while JL:IsAlive() do
        loopTicks = loopTicks + 1
        task.wait(0.25)
    end
end)

-- This delayed callback should never run if the hub is unloaded first.
JL:Delay(30, function()
    delayedCallbackFired = true
    warn("[Cleanup Test] Delayed callback unexpectedly fired.")
end)

JL:OnUnload(function()
    print("[Cleanup Test] OnUnload hook executed.")
end)

Section:Button({
    Name = "Create tracked test object",
    Callback = function()
        if trackedFolder and trackedFolder.Parent then
            trackedFolder:Destroy()
        end

        trackedFolder = Instance.new("Folder")
        trackedFolder.Name = "JL_CleanupTestResource"
        trackedFolder.Parent = workspace
        JL:Track(trackedFolder)

        print("[Cleanup Test] Test object created and registered.")
    end,
})

Section:Button({
    Name = "Show cleanup stats",
    Callback = function()
        local stats = JL:GetCleanupStats()
        print("[Cleanup Test] Alive:", stats.Alive)
        print("[Cleanup Test] Connections:", stats.Connections)
        print("[Cleanup Test] Threads:", stats.Threads)
        print("[Cleanup Test] Resources:", stats.Resources)
        print("[Cleanup Test] Loop ticks:", loopTicks)
    end,
})

Section:Button({
    Name = "Unload + verify cleanup",
    Callback = function()
        local ticksBeforeUnload = loopTicks
        print("[Cleanup Test] Unloading library...")
        Window:Unload()

        -- Intentionally untracked verification task: it must survive the unload.
        task.delay(1, function()
            local stats = JL:GetCleanupStats()
            print("[Cleanup Test] ----- RESULT -----")
            print("[Cleanup Test] Alive should be false:", stats.Alive)
            print("[Cleanup Test] Connections should be 0:", stats.Connections)
            print("[Cleanup Test] Threads should be 0:", stats.Threads)
            print("[Cleanup Test] Resources should be 0:", stats.Resources)
            print("[Cleanup Test] Tracked object removed:", not trackedFolder or trackedFolder.Parent == nil)
            print("[Cleanup Test] Loop stopped:", loopTicks == ticksBeforeUnload)
            print("[Cleanup Test] Delayed callback stayed cancelled:", not delayedCallbackFired)
        end)
    end,
})

Section:Button({
    Name = "Reload library instance",
    Callback = function()
        print("[Cleanup Test] Loading a new library instance...")
        local NewJL = loadstring(game:HttpGet(LibraryURL))()
        local NewWindow = NewJL:Window({
            Name = "JustLib Cleanup Reload Test",
            Config = "JustLib_CleanupTest",
            Settings = true,
        })

        if NewWindow then
            local ReloadTab = NewWindow:Tab({
                Name = "Reloaded",
                Icon = "refresh-cw",
                Type = "Grid",
            })
            local ReloadSection = ReloadTab:Section({
                Title = "Restart Result",
                Column = 1,
            })
            ReloadSection:Button({
                Name = "Hub restarted successfully",
                Callback = function()
                    print("[Cleanup Test] Restarted hub is responsive.")
                end,
            })
            NewWindow:HomeTab({
                Name = "Home",
                WelcomeTitle = "Cleanup Test Reloaded",
                Announcement = "The hub was restarted. Use Settings > About to unload it.",
            })
        end

        print("[Cleanup Test] New instance created:", NewWindow ~= nil)

        task.delay(1, function()
            local CoreGui = game:GetService("CoreGui")
            local PlayerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local containers = {CoreGui}
            if PlayerGui then containers[#containers + 1] = PlayerGui end
            local counts = {JustLib = 0, JLRemote = 0}
            for _, container in ipairs(containers) do
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("ScreenGui") and counts[child.Name] ~= nil then
                        counts[child.Name] = counts[child.Name] + 1
                    end
                end
            end
            print("[Cleanup Test] JustLib UI roots (expected 1):", counts.JustLib)
            print("[Cleanup Test] Remote UI roots (expected 0-1):", counts.JLRemote)
            if counts.JustLib ~= 1 or counts.JLRemote > 1 then
                warn("[Cleanup Test] Duplicate library UI detected.")
            end
        end)
    end,
})

-- Built-in Remote UI. The controls above can be selected in Edit Remote Items.
local Remote = Window:Remote({
    Title = "Cleanup Test Remote",
    Key = Enum.KeyCode.RightControl,
})

Section:Button({
    Name = "Toggle Remote Edit Mode",
    Callback = function()
        local enabled = Remote:Edit()
        print("[Cleanup Test] Remote edit mode:", enabled)
    end,
})

-- Built-in Settings tab (Interface, Notifications, Preview UI, Remote, Presets, About, etc.).
local SettingsTab = Window:Settings()

task.delay(1, function()
    local root = Window and Window.Frame
    local nav
    if root then
        for _, item in ipairs(root:GetDescendants()) do
            if item.Name == "SettingsNavigation" then
                nav = item
                break
            end
        end
    end
    if nav and nav:IsA("ScrollingFrame") then
        print("[Cleanup Test] Settings navigation is scrollable:",
            nav.CanvasSize.Y.Offset > nav.AbsoluteSize.Y)
    else
        warn("[Cleanup Test] SettingsNavigation ScrollingFrame not found.")
    end
end)

-- Built-in Home tab with the standard player / game / session cards.
local HomeTab = Window:HomeTab({
    Name = "Home",
    WelcomeTitle = "JustLib Cleanup Test",
    Changelog = {
        {Title = "4.0.7", Description = "Added the Home Changelog panel."},
        "Updated the Home executor label.",
        "This list is configured from the test script, not inside JustLib.lua.",
    },
})

task.delay(1, function()
    local homeFrame = HomeTab and HomeTab.Frame
    local playerCard = homeFrame and homeFrame:FindFirstChild("PlayerCard", true)
    local changelogFrame = homeFrame and homeFrame:FindFirstChild("ChangelogFrame", true)
    local changelogList = changelogFrame and changelogFrame:FindFirstChild("ChangelogList", true)
    local playerStatus = playerCard and playerCard:FindFirstChild("PlayerStatus", true)
    local changelogEntries = 0
    local clickableEntries = 0
    if changelogList then
        for _, child in ipairs(changelogList:GetChildren()) do
            if child.Name == "ChangelogEntry" then
                changelogEntries = changelogEntries + 1
                if child:FindFirstChild("OpenChangelogEntry") then
                    clickableEntries = clickableEntries + 1
                end
            end
        end
    end
    local duplicateExecutorCard = false
    if homeFrame then
        for _, child in ipairs(homeFrame:GetDescendants()) do
            if child:IsA("TextLabel") and child.Text == "Detected: " then
                duplicateExecutorCard = true
            end
        end
    end
    print("[Cleanup Test] Home Player Card created:", playerCard ~= nil)
    print("[Cleanup Test] Home Player status created:", playerStatus ~= nil)
    print("[Cleanup Test] Home Changelog frame created:", changelogFrame ~= nil)
    print("[Cleanup Test] Home Changelog list created:", changelogList ~= nil)
    print("[Cleanup Test] Changelog entries rendered (expected 3):", changelogEntries)
    print("[Cleanup Test] Changelog entries clickable (expected 3):", clickableEntries)
    print("[Cleanup Test] Duplicate Executor card absent:", not duplicateExecutorCard)
    if changelogList then
        print("[Cleanup Test] Changelog content height:", changelogList.CanvasSize.Y.Offset)
        print("[Cleanup Test] Changelog scrolling enabled:", changelogList.Active and changelogList.ScrollingDirection == Enum.ScrollingDirection.Y)
    end
end)

JL:Notify({Title = "Cleanup test", Desc = "This notification should disappear when the library unloads.", Duration = 60})

print("[Cleanup Test] Loaded.")
print("[Cleanup Test] Create the tracked object, inspect stats, then test Unload.")
