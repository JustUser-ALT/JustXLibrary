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
    Settings = false,
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
            Settings = false,
        })

        print("[Cleanup Test] New instance created:", NewWindow ~= nil)
    end,
})

print("[Cleanup Test] Loaded.")
print("[Cleanup Test] Create the tracked object, inspect stats, then test Unload.")
