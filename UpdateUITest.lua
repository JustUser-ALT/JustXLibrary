-- JustLib Update UI test
-- Run once: the 4.4.11 popup should appear.
-- Close it and run again: it should stay closed, while Home > What's New
-- still lets you open either version from the history list.
-- To test another popup, change the newest Version below (for example 4.4.12).

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
))()

local Window = Library:Window({
    Title = "JustLib Update Test",
    Config = "JustLib_UpdateUITest",
    Width = 520,
    Height = 420,
})

if not Window then return end

Window:HomeTab({
    WelcomeTitle = "Update UI Test",
    Changelog = {
        {
            Version = "4.4.11",
            Title = "Update UI Redesign",
            Description = "A redesigned update popup and a cleaner version history.",
            Changes = {
                "New compact update popup appears once per version.",
                "Dismissed updates remain available in the Home changelog.",
                "Version details now include a full Changes list.",
            },
        },
        {
            Version = "4.4.10",
            Title = "Info & Settings",
            Description = "Refined compact Info and Settings panels.",
            Changes = {
                "Reduced panel dimensions.",
                "Adjusted spacing and controls.",
            },
        },
    },
})
