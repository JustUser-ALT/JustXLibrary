-- Input Overflow test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/InputOverflowTest.lua"))()

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/JustLib.lua"
))()
if not Library then warn("[Input Overflow Test] JustLib failed to load.") return end

local Window = Library:Window({
    Title = "Input Overflow Test",
    Config = "JustX_InputOverflowTest",
    Width = 480,
    Height = 520,
})
if not Window then warn("[Input Overflow Test] Window creation failed.") return end

local Tab = Window:Tab({ Name = "Input Tests", Icon = "text-cursor-input" })
local Section = Tab:Section({ Title = "Text clipping and multiline layout" })

local single = Section:Input({
    Name = "Single-line Input",
    Placeholder = "A deliberately long placeholder that should remain inside the input field without overlapping nearby controls or changing the layout",
    Flag = "InputOverflow_Single",
})

local multi = Section:Input({
    Name = "Multiline Textbox",
    Placeholder = "A long multiline placeholder that should wrap inside the field and stay within its rounded background",
    MultiLine = true,
    Flag = "InputOverflow_Multi",
})

local longSingle = string.rep("This is a very long single-line value that must remain clipped to its input field. ", 8)
local longMulti = table.concat({
    "First line: multiline text should wrap within the textbox.",
    "Second line: long text must not escape the field boundaries.",
    "Third line: the component height must remain stable.",
    string.rep("Long content ", 24),
}, "\n")

Section:Button({
    Name = "Set Long Single-line Text",
    Callback = function()
        single:Set(longSingle)
        print("[Input Overflow Test] Set long single-line text. Check that it stays inside the field.")
    end,
})

Section:Button({
    Name = "Set Long Multiline Text",
    Callback = function()
        multi:Set(longMulti)
        print("[Input Overflow Test] Set multiline text. Check wrapping and clipping.")
    end,
})

Section:Button({
    Name = "Set Short Text",
    Callback = function()
        single:Set("Short value")
        multi:Set("First line\nSecond line")
    end,
})

Section:Button({
    Name = "Read Values",
    Callback = function()
        print("[Input Overflow Test] Single:", single:Get())
        print("[Input Overflow Test] Multiline:", multi:Get())
    end,
})

print("[Input Overflow Test] Ready. Check the long placeholders first, then use the buttons to test long and short values.")
