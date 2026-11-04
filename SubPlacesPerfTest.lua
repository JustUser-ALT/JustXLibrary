--==================================================
-- JUSTLIB SUB-PLACES PERFORMANCE TEST
-- Verifies that Sub-Places opens without executor-based thumbnail downloads.
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
print("[Sub-Places Perf Test] Open Home > Sub-Places. The window should appear without waiting for thumbnail downloads.")
print("[Sub-Places Perf Test] Place icons use gradient initials; no thumbnail HTTP downloads should run. Send all [JustLib Perf] lines and report any freeze.")
