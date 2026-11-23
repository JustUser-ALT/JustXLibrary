-- JustXLibrary Function Test
-- Loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/LibraryFunctionTest.lua"))()
--
-- This is a UI-based test harness. Results are shown inside the window.
-- It tests public API availability, safe control construction, control methods,
-- tab/section APIs, lifecycle helpers and selected runtime services.
-- Destructive / environment-dependent operations are deliberately manual or skipped.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local SOURCE = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local Library

local function safeCall(fn)
    local ok, result = pcall(fn)
    if not ok then return false, tostring(result) end
    return true, result
end

local loaded, loadResult = safeCall(function()
    return loadstring(game:HttpGet(SOURCE))()
end)

if not loaded or type(loadResult) ~= "table" then
    warn("[Library Test] Could not load JustXLibrary: " .. tostring(loadResult))
    return
end

Library = loadResult

local windowOk, Window = safeCall(function()
    return Library:Window({
        Title = "JustXLibrary · Function Test",
        Config = "JustLib_FunctionTest",
        Width = 760,
        Height = 560,
        LoadIcons = false,
        Settings = true,
    })
end)

if not windowOk or not Window then
    warn("[Library Test] Window creation failed: " .. tostring(Window))
    return
end

local results = {}
local counts = {Passed = 0, Failed = 0, Skipped = 0}
local statusLabels = {}
local runAll

local function updateSummary()
    local total = counts.Passed + counts.Failed + counts.Skipped
    if results.Summary then
        results.Summary:Set(string.format(
            "Passed: %d   Failed: %d   Skipped: %d   Total: %d",
            counts.Passed, counts.Failed, counts.Skipped, total
        ))
    end
end

local function setResult(name, state, detail)
    local old = results[name]
    if old then
        counts[old] = math.max(0, counts[old] - 1)
    end
    results[name] = state
    counts[state] = counts[state] + 1

    local label = statusLabels[name]
    if label then
        local symbol = state == "Passed" and "✓" or state == "Failed" and "✕" or "–"
        local suffix = detail and ("  ·  " .. tostring(detail)) or ""
        label:Set(symbol .. "  " .. name .. suffix)
    end
    updateSummary()
end

local function test(name, fn)
    local ok, result = safeCall(fn)
    if ok and result ~= false then
        setResult(name, "Passed", result == true and nil or result)
        return true
    end
    setResult(name, "Failed", ok and "returned false" or result)
    return false
end

local function skip(name, reason)
    setResult(name, "Skipped", reason or "manual / environment-dependent")
end

local overview = Window:Tab({Name = "Overview", Icon = "activity", Type = "Grid"})
local coreTab = Window:Tab({Name = "Core API", Icon = "cpu", Type = "Grid"})
local controlsTab = Window:Tab({Name = "Controls", Icon = "sliders-horizontal", Type = "Grid"})
local layoutTab = Window:Tab({Name = "Layout", Icon = "layout-grid", Type = "Grid"})
local servicesTab = Window:Tab({Name = "Services", Icon = "wrench", Type = "Grid"})

local summarySection = overview:Section({Title = "Test Results", Column = 1})
results.Summary = summarySection:Text({Text = "Passed: 0   Failed: 0   Skipped: 0   Total: 0"})
summarySection:Text({Text = "Run the safe tests below. Individual controls can also be tested manually."})
summarySection:Button({
    Name = "Run All Safe Tests",
    Callback = function()
        if runAll then runAll() end
    end,
})
summarySection:Button({
    Name = "Reset Results",
    Callback = function()
        counts = {Passed = 0, Failed = 0, Skipped = 0}
        for name in pairs(results) do
            if name ~= "Summary" then results[name] = nil end
        end
        for name, label in pairs(statusLabels) do
            label:Set("…  " .. name .. "  ·  not run")
        end
        updateSummary()
    end,
})
local resultSection = overview:Section({Title = "Detailed Status", Column = 2})
local function addStatus(name)
    statusLabels[name] = resultSection:Text({Text = "…  " .. name .. "  ·  not run"})
end

local testNames = {
    "Library version",
    "Lifecycle API",
    "Theme API",
    "Streamer Mode API",
    "Window state API",
    "Tab API",
    "Section API",
    "Toggle",
    "ToggleGroup",
    "Slider",
    "Button",
    "Input",
    "Dropdown",
    "TextSlider",
    "ColorPicker",
    "Keybind",
    "Segmented",
    "Group",
    "Text and Label",
    "Screen",
    "Divider",
    "Custom",
    "MultiSection",
    "Preview control wrappers",
    "Notification",
    "Preview loader",
    "Settings page",
    "Home tab",
    "Addons API",
    "Remote API",
    "Confirm dialog",
}
for _, name in ipairs(testNames) do addStatus(name) end

local coreSection = coreTab:Section({Title = "Library / Lifecycle", Column = 1})
local controlSectionA = controlsTab:Section({Title = "Basic Controls", Column = 1})
local controlSectionB = controlsTab:Section({Title = "Advanced Controls", Column = 2})
local layoutSectionA = layoutTab:Section({Title = "Sections and Layout", Column = 1})
local layoutSectionB = layoutTab:Section({Title = "Navigation", Column = 2})
local serviceSection = servicesTab:Section({Title = "Runtime Services", Column = 1})
local manualSection = servicesTab:Section({Title = "Manual / Environment Tests", Column = 2})

local controlRefs = {}
local function createControl(name, fn)
    local ok, value = safeCall(fn)
    if ok and value ~= nil then
        controlRefs[name] = value
        setResult(name, "Passed", "created")
        return value
    end
    setResult(name, "Failed", ok and "no return value" or value)
    return nil
end

-- Create all supported section control types. These are isolated test controls,
-- use no persistent Flags and do not alter player/game state.
createControl("Toggle", function()
    return controlSectionA:Toggle({Name = "Test Toggle", Default = false})
end)
createControl("ToggleGroup", function()
    return controlSectionA:ToggleGroup({
        Name = "Test Toggle Group",
        Mode = "Move",
        Options = {"First", "Second", "Third"},
    })
end)
createControl("Slider", function()
    return controlSectionA:Slider({Name = "Test Slider", Min = 0, Max = 100, Step = 1, Default = 35})
end)
createControl("Button", function()
    return controlSectionA:Button({Name = "Test Button"})
end)
createControl("Input", function()
    return controlSectionA:Input({Name = "Test Input", Placeholder = "Type something..."})
end)
createControl("Dropdown", function()
    return controlSectionA:Dropdown({
        Name = "Test Dropdown",
        Options = {"Alpha", "Beta", "Gamma"},
        Search = true,
        MultiSelect = false,
    })
end)
createControl("TextSlider", function()
    return controlSectionB:TextSlider({
        Name = "Test Text Slider",
        Options = {"Low", "Medium", "High"},
        Default = "Medium",
    })
end)
createControl("ColorPicker", function()
    return controlSectionB:ColorPicker({Name = "Test Color", Default = Color3.fromRGB(90, 160, 255)})
end)
createControl("Keybind", function()
    return controlSectionB:Keybind({Name = "Test Keybind", Default = Enum.KeyCode.RightShift})
end)
createControl("Segmented", function()
    return controlSectionB:Segmented({
        Name = "Test Segmented",
        Options = {"One", "Two", "Three"},
        Default = "One",
    })
end)
createControl("Group", function()
    return controlSectionB:Group({
        Name = "Compact Group",
        A = {Type = "Button", Name = "A"},
        B = {Type = "Toggle", Name = "B"},
    })
end)
createControl("Text and Label", function()
    local text = controlSectionB:Text({Text = "Text control test"})
    local label = controlSectionB:Label({Text = "Label control test"})
    assert(text and label, "Text / Label returned nil")
    text:Set("Text control updated")
    label:Set("Label control updated")
    return true
end)
createControl("Screen", function()
    return controlSectionB:Screen({Name = "Screen Preview", Height = 72, Image = "rbxassetid://0"})
end)
createControl("Divider", function()
    controlSectionB:Divider({Label = "Divider Test"})
    return true
end)
createControl("Custom", function()
    return controlSectionB:Custom(34, function(frame)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Text = "Custom content container"
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextSize = 11
        label.Parent = frame
    end)
end)

createControl("Preview control wrappers", function()
    local button = controlSectionB:PreviewButton({Name = "Preview Button Wrapper"})
    local toggle = controlSectionB:PreviewToggle({Name = "Preview Toggle Wrapper"})
    local dropdown = controlSectionB:PreviewDropdown({Name = "Preview Dropdown Wrapper"})
    assert(button and toggle and dropdown, "Preview wrapper creation failed")
    return true
end)

createControl("Section API", function()
    assert(type(coreSection.Toggle) == "function", "Section:Toggle missing")
    assert(type(coreSection.Button) == "function", "Section:Button missing")
    assert(type(coreSection.Custom) == "function", "Section:Custom missing")
    return true
end)

local multiSection
createControl("MultiSection", function()
    multiSection = layoutSectionA:MultiSection({
        Title = "MultiSection Test",
        Pages = {"First", "Second"},
        Layout = "Rows",
        Columns = 2,
    })
    assert(multiSection, "MultiSection creation failed")
    local first = multiSection:Page("First")
    local second = multiSection:Page("Second")
    assert(first and second, "MultiSection:Page failed")
    first:Text({Text = "First page"})
    second:Text({Text = "Second page"})
    multiSection:Shared():Label({Text = "Shared area"})
    multiSection:SetPage("Second")
    assert(multiSection:GetPage() == "Second", "MultiSection page switch failed")
    multiSection:SetPage("First")
    return true
end)

createControl("Tab API", function()
    local tab = Window:Tab({Name = "Temporary Tab Test", Icon = "flask", Type = "Grid"})
    assert(tab and tab.Select and tab.Remove and tab.SetHidden and tab.SetLocked, "Tab API incomplete")
    tab:Select()
    tab:SetLocked(true)
    assert(tab:IsLocked(), "Tab lock did not apply")
    tab:SetLocked(false)
    assert(not tab:IsLocked(), "Tab unlock did not apply")
    tab:SetHidden(true)
    assert(tab:IsHidden(), "Tab hide did not apply")
    tab:SetHidden(false)
    assert(not tab:IsHidden(), "Tab show did not apply")
    tab:Remove()
    assert(tab:IsRemoved(), "Tab remove did not apply")
    return true
end)

createControl("Window state API", function()
    assert(type(Window.IsOpen) == "function", "Window:IsOpen missing")
    assert(type(Window.Open) == "function", "Window:Open missing")
    assert(type(Window.Close) == "function", "Window:Close missing")
    assert(type(Window.Toggle) == "function", "Window:Toggle missing")
    assert(type(Window.Destroy) == "function", "Window:Destroy missing")
    assert(Window:IsOpen() == true, "Window should be open after creation")
    return true
end)

local function checkGetSet(name, expected)
    local control = controlRefs[name]
    assert(control and type(control.Get) == "function" and type(control.Set) == "function", name .. " Get/Set missing")
    control:Set(expected)
    local value = control:Get()
    if type(value) == "table" then
        assert(value[1] == expected or value[expected] == true, name .. " value mismatch")
    else
        assert(value == expected, name .. " value mismatch: " .. tostring(value))
    end
    return true
end

local function runControlMethodTests()
    test("Toggle", function()
        local toggle = controlRefs.Toggle
        assert(toggle and toggle.Get and toggle.Set and toggle.Click and toggle.Watch, "Toggle methods missing")
        toggle:Set(true)
        assert(toggle:Get() == true, "Toggle Set/Get failed")
        toggle:Set(false)
        return true
    end)
    test("Slider", function() return checkGetSet("Slider", 72) end)
    test("Input", function() return checkGetSet("Input", "JustLib test input") end)
    test("Dropdown", function()
        local dropdown = controlRefs.Dropdown
        assert(dropdown and dropdown.Get and dropdown.Set and dropdown.Open, "Dropdown methods missing")
        dropdown:Set("Beta")
        assert(dropdown:Get().Beta == true, "Dropdown Set/Get failed")
        dropdown:Set(nil)
        return true
    end)
    test("TextSlider", function()
        local slider = controlRefs.TextSlider
        assert(slider and slider.Get and slider.Set, "TextSlider methods missing")
        slider:Set("High")
        assert(slider:Get() == "High", "TextSlider Set/Get failed")
        slider:Set("Medium")
        return true
    end)
    test("ColorPicker", function()
        local picker = controlRefs.ColorPicker
        assert(picker and picker.Get and picker.Set, "ColorPicker methods missing")
        local color = Color3.fromRGB(120, 180, 220)
        picker:Set(color)
        assert(picker:Get() == color, "ColorPicker Set/Get failed")
        return true
    end)
    test("Keybind", function()
        local keybind = controlRefs.Keybind
        assert(keybind and keybind.Get and keybind.Set and keybind.Press and keybind.Watch and keybind.OnPulse, "Keybind methods missing")
        keybind:Set(Enum.KeyCode.K)
        assert(keybind:Get() == Enum.KeyCode.K, "Keybind Set/Get failed")
        keybind:Set(Enum.KeyCode.RightShift)
        return true
    end)
    test("Segmented", function()
        local segmented = controlRefs.Segmented
        assert(segmented and segmented.Get and segmented.Set, "Segmented methods missing")
        segmented:Set("Three")
        assert(segmented:Get() == "Three", "Segmented Set/Get failed")
        segmented:Set("One")
        return true
    end)
    test("ToggleGroup", function()
        local group = controlRefs.ToggleGroup
        assert(group and group.Get and group.GetActive and group.Set and group.SetMode, "ToggleGroup methods missing")
        group:SetMode("Move")
        assert(group:Set("Second", true) == true, "ToggleGroup Set failed")
        assert(group:Get().Second == true, "ToggleGroup state mismatch")
        group:Set("Second", false)
        return true
    end)
    test("Button", function()
        local button = controlRefs.Button
        assert(button and button.Get and button.Click, "Button methods missing")
        local before = button:Get()
        button:Click()
        assert(button:Get() == before + 1, "Button Click failed")
        return true
    end)
    test("Group", function()
        local group = controlRefs.Group
        assert(group and group.A and group.B, "Group controls missing")
        return true
    end)
    test("Screen", function()
        local screen = controlRefs.Screen
        assert(screen and screen.SetImage and screen.SetPlayer, "Screen methods missing")
        screen:SetImage("rbxassetid://0")
        return true
    end)
end

local function runCoreTests()
    test("Library version", function()
        assert(type(Library.Version) == "string" and Library.Version ~= "", "Version missing")
        return "v" .. Library.Version
    end)
    test("Lifecycle API", function()
        assert(Library.IsAlive and Library.Track and Library.Connect and Library.Spawn and Library.Delay and Library.Defer and Library.OnUnload and Library.GetCleanupStats, "Lifecycle method missing")
        assert(Library:IsAlive(), "Library is not alive")
        local stats = Library:GetCleanupStats()
        assert(type(stats) == "table" and stats.Alive == true, "Cleanup stats invalid")
        local folder = Instance.new("Folder")
        folder.Name = "JustLibFunctionTestResource"
        Library:Track(folder)
        assert(folder.Parent == nil, "Tracked test resource unexpectedly parented")
        local event = Instance.new("BindableEvent")
        local fired = false
        Library:Track(event)
        Library:Connect(event.Event, function() fired = true end)
        event:Fire()
        assert(fired, "Tracked connection did not fire")
        Library:Spawn(function() end)
        Library:Defer(function() end)
        Library:Delay(0.05, function() end)
        local hookRegistered = Library:OnUnload(function() end)
        assert(hookRegistered == true, "OnUnload registration failed")
        return true
    end)
    test("Theme API", function()
        assert(Library.SetTheme and Library.GetTheme, "Theme methods missing")
        local previous = Library:GetTheme()
        assert(type(previous) == "string", "Current theme unavailable")
        assert(Library:SetTheme("Nord") == true, "SetTheme failed")
        assert(Library:GetTheme() == "Nord", "GetTheme mismatch")
        assert(Library:SetTheme(previous) == true, "Theme restore failed")
        return true
    end)
    test("Streamer Mode API", function()
        assert(Library.SetStreamerMode and Library.GetStreamerMode, "Streamer methods missing")
        local previous = Library:GetStreamerMode()
        assert(Library:SetStreamerMode(true) == true, "Enable streamer mode failed")
        assert(Library:GetStreamerMode() == true, "Streamer mode state mismatch")
        assert(Library:SetStreamerMode(previous) == true, "Restore streamer mode failed")
        return true
    end)
    test("Window state API", function()
        assert(Window:IsOpen() == true, "Window is not open")
        return true
    end)
    test("Notification", function()
        local result = Library:Notify({Title = "Function Test", Desc = "Notification API test", Type = "Info", Duration = 2})
        return result ~= false
    end)
end

local function runLayoutTests()
    test("Section API", function()
        assert(type(coreSection.Toggle) == "function" and type(coreSection.MultiSection) ~= "function", "Section API mismatch")
        return true
    end)
    test("Tab API", function()
        assert(type(Window.Tab) == "function" and type(Window.HomeTab) == "function", "Tab constructors missing")
        return true
    end)
    test("MultiSection", function()
        assert(multiSection and multiSection.Page and multiSection.Shared and multiSection.SetPage and multiSection.GetPage, "MultiSection API incomplete")
        return true
    end)
    test("Home tab", function()
        local home = Window:HomeTab({Name = "Home Test", WelcomeTitle = "Home tab test"})
        assert(home and home.Select and home.Remove, "HomeTab creation failed")
        home:Select()
        home:Remove()
        return true
    end)
end

local function runServiceTests()
    test("Streamer Mode API", function()
        return Library:GetStreamerMode() == false or Library:GetStreamerMode() == true
    end)
    test("Notification", function()
        assert(type(Window.Notify) == "function", "Window:Notify missing")
        return true
    end)
    skip("Preview loader", "opens a separate Preview UI; use the manual button")
    skip("Settings page", "creates the full Settings interface; use the manual button")
    skip("Addons API", "filesystem-dependent; only availability is checked")
    skip("Remote API", "creates a floating panel; use the manual button")
    skip("Confirm dialog", "opens a modal requiring a user decision")
end

runAll = function()
    runCoreTests()
    runControlMethodTests()
    runLayoutTests()
    runServiceTests()
    Library:Notify({
        Title = "Function Test",
        Desc = string.format("%d passed · %d failed · %d skipped", counts.Passed, counts.Failed, counts.Skipped),
        Type = counts.Failed == 0 and "Success" or "Warn",
        Duration = 4,
    })
end

coreSection:Button({Name = "Run Core API Tests", Callback = runCoreTests})
coreSection:Button({Name = "Run Control Method Tests", Callback = runControlMethodTests})
coreSection:Button({Name = "Run Layout Tests", Callback = runLayoutTests})
coreSection:Button({Name = "Run All Tests", Callback = function() runAll() end})

serviceSection:Button({
    Name = "Test Preview Loader",
    Callback = function()
        test("Preview loader", function()
            local preview = Library:Preview({Title = "Library Function Test Preview", TabName = "Test"})
            assert(preview and not preview.IsStub, "Preview failed to load")
            assert(Library:GetPreview() == preview, "GetPreview mismatch")
            return true
        end)
    end,
})
serviceSection:Button({
    Name = "Test Settings Page",
    Callback = function()
        test("Settings page", function()
            local settings = Window:Settings()
            assert(settings and settings.Frame, "Settings page failed to create")
            return true
        end)
    end,
})
serviceSection:Button({
    Name = "Test Addons API",
    Callback = function()
        test("Addons API", function()
            assert(type(Window.Addons) == "function", "Window:Addons missing")
            local addons = Window:Addons()
            assert(type(addons) == "table", "Addons API did not return a table")
            return true
        end)
    end,
})
serviceSection:Button({
    Name = "Test Remote API",
    Callback = function()
        test("Remote API", function()
            assert(type(Window.Remote) == "function", "Window:Remote missing")
            local remote = Window:Remote({Title = "Function Test Remote", Open = false})
            assert(type(remote) == "table", "Remote API failed")
            assert(remote.Toggle and remote.Button and remote.Keybind and remote.Show and remote.Hide and remote.Destroy, "Remote methods missing")
            return true
        end)
    end,
})
manualSection:Button({
    Name = "Test Confirm Dialog",
    Callback = function()
        test("Confirm dialog", function()
            assert(type(Library.Confirm) == "function", "Confirm API missing")
            local result = Library:Confirm({
                Title = "Confirm Test",
                Desc = "This is a manual confirmation test.",
                ConfirmText = "Confirm",
                CancelText = "Cancel",
            })
            return result ~= false
        end)
    end,
})
manualSection:Button({
    Name = "Test Window Search",
    Callback = function()
        test("Window Search", function()
            assert(type(Window.Search) == "function", "Window:Search missing")
            return Window:Search("Test") == true
        end)
    end,
})
manualSection:Button({
    Name = "Test Window Navigation",
    Callback = function()
        test("Window Navigation", function()
            local textControl = controlRefs["Text and Label"]
            assert(textControl, "Text test control missing")
            assert(type(Window.GoTo) == "function", "Window:GoTo missing")
            return Window:GoTo(textControl.Row) == true
        end)
    end,
})

-- API presence checks are separate from functional calls so a missing optional
-- method is reported explicitly rather than breaking the rest of the test suite.
test("Addons API", function()
    assert(type(Window.Addons) == "function", "Window:Addons missing")
    return true
end)
test("Remote API", function()
    assert(type(Window.Remote) == "function", "Window:Remote missing")
    return true
end)
test("Confirm dialog", function()
    assert(type(Library.Confirm) == "function", "Library:Confirm missing")
    return true
end)

Window:Open()
print("[Library Test] UI test hub loaded. Run tests from the Overview tab.")
