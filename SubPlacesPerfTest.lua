--==================================================
-- JUSTLIB SUB-PLACES PERFORMANCE TEST
-- Opens the built-in Home tab with detailed Sub-Places profiling enabled.
--==================================================

local LibraryURL = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local JL = loadstring(game:HttpGet(LibraryURL))()

local Window = JL:Window({
    Name = "JustLib Sub-Places Performance Test",
    Config = "JustLib_SubPlacesPerfTest",
    Settings = true,
    DebugPerformance = true,
})

if not Window then
    warn("[Sub-Places Perf Test] Window creation was cancelled.")
    return
end

Window:HomeTab({
    Name = "Home",
    WelcomeTitle = "Sub-Places Performance Test",
    GetExecs = false,
    ShowFriends = false,
})

print("[Sub-Places Perf Test] Ready.")
print("[Sub-Places Perf Test] Open Home > Sub-Places and wait for the thumbnails.")
print("[Sub-Places Perf Test] Send all console lines beginning with [JustLib Perf] Sub-Places.")
