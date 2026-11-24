-- JustXLibrary Addons System Test
-- Run:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/tests/AddonSystemTest.lua"))()
--
-- Loads the current JustLib.lua release, creates an isolated Addons folder,
-- installs a harmless test addon, opens the real Addons UI and checks its runtime.
-- It does not touch the normal JustLib/Addons folder.

local SOURCE = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local TEST_FOLDER = "JustLib/Addons_TestHarness"
local TEST_FILE = TEST_FOLDER .. "/AddonSystemTest.lua"

local function log(message)
    print("[Addon System Test] " .. tostring(message))
end

local function ensureFolder(path)
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
        return false, "isfolder / makefolder unavailable"
    end
    local ok, exists = pcall(isfolder, path)
    if ok and exists then return true end
    local parent = path:match("^(.*)/[^/]+$")
    if parent then
        local parentOk, parentExists = pcall(isfolder, parent)
        if not parentOk or not parentExists then
            local madeParent, parentErr = ensureFolder(parent)
            if not madeParent then return false, parentErr end
        end
    end
    local made, err = pcall(makefolder, path)
    if not made then
        local checkOk, nowExists = pcall(isfolder, path)
        if not checkOk or not nowExists then return false, tostring(err) end
    end
    return true
end

local TEST_ADDON = [==[
return {
    Info = {
        Name = "Addon System Test",
        Author = "JustXLibrary",
        Version = "1.0.0",
        Description = "Runtime test for the new table-based Addon API."
    },

    Init = function(Addon)
        local state = shared.__JLAddonSystemTest or {}
        state.Init = (state.Init or 0) + 1
        shared.__JLAddonSystemTest = state

        Addon:Label("Addon controls")

        Addon:Toggle({
            Name = "Callback Test Toggle",
            Default = false,
            Callback = function(value)
                state.Toggle = value
                print("[Addon System Test] Toggle callback:", value)
            end
        })

        Addon:Button({
            Name = "Callback Test Button",
            Callback = function()
                state.Button = (state.Button or 0) + 1
                print("[Addon System Test] Button callback:", state.Button)
                Addon:Notify("Button callback works", "Success")
            end
        })

        Addon:Slider({
            Name = "Callback Test Slider",
            Min = 0,
            Max = 100,
            Step = 1,
            Default = 35,
            Callback = function(value)
                state.Slider = value
                print("[Addon System Test] Slider callback:", value)
            end
        })

        Addon:Dropdown({
            Name = "Callback Test Dropdown",
            Values = {"Alpha", "Beta", "Gamma"},
            Default = "Alpha",
            Callback = function(value)
                state.Dropdown = value
                print("[Addon System Test] Dropdown callback:", value)
            end
        })

        Addon:Input({
            Name = "Callback Test Input",
            Placeholder = "Enter any text...",
            Callback = function(value)
                state.Input = value
                print("[Addon System Test] Input callback:", value)
            end
        })

        Addon:Divider("Persistence")

        Addon:Button({
            Name = "Test Save / Load",
            Callback = function()
                Addon:Save("Probe", "Addon storage works")
                state.Storage = Addon:Load("Probe", "FAILED")
                print("[Addon System Test] Save / Load:", state.Storage)
                Addon:Notify(tostring(state.Storage), "Info")
            end
        })

        Addon:OnUnload(function()
            state.Unload = (state.Unload or 0) + 1
            print("[Addon System Test] OnUnload called:", state.Unload)
        end)

        Addon:Notify("Test addon initialized", "Success")
    end
}
]==]

log("Preparing isolated test addon folder...")
local fileReady, fileError = false, nil
if type(writefile) == "function" then
    local folderOk, folderError = ensureFolder(TEST_FOLDER)
    if folderOk then
        local writeOk, writeError = pcall(writefile, TEST_FILE, TEST_ADDON)
        fileReady = writeOk
        fileError = writeOk and nil or tostring(writeError)
    else
        fileError = tostring(folderError)
    end
else
    fileError = "writefile unavailable"
end
log(fileReady and ("Test addon written: " .. TEST_FILE) or ("Could not write test addon: " .. tostring(fileError)))

log("Downloading JustXLibrary...")
local sourceOk, source = pcall(function()
    return game:HttpGet(SOURCE)
end)
if not sourceOk or type(source) ~= "string" or source == "" then
    warn("[Addon System Test] Library download failed: " .. tostring(source))
    return
end

local compileOk, libraryLoader = pcall(loadstring, source)
if not compileOk or type(libraryLoader) ~= "function" then
    warn("[Addon System Test] Library compile failed: " .. tostring(libraryLoader))
    return
end

local runOk, Library = pcall(libraryLoader)
if not runOk or type(Library) ~= "table" then
    warn("[Addon System Test] Library startup failed: " .. tostring(Library))
    return
end
log("Library loaded. Version: " .. tostring(Library.Version or "unknown"))

local windowOk, Window = pcall(function()
    return Library:Window({
        Title = "JustXLibrary · Addons Test",
        Config = "JustLib_Addons_TestHarness",
        HubId = "AddonSystemTest",
        Width = 700,
        Height = 540,
        Settings = true,
        AddonsFolder = TEST_FOLDER,
    })
end)

if not windowOk or not Window then
    warn("[Addon System Test] Window creation failed: " .. tostring(Window))
    return
end
log("Test window created.")

local addonsOk, Addons = pcall(function()
    return Window:Addons()
end)
if not addonsOk or type(Addons) ~= "table" then
    warn("[Addon System Test] Window:Addons() failed: " .. tostring(Addons))
    return
end

local enableUiOk, enableUiError = pcall(function()
    Addons.setEnabled(true)
end)
if not enableUiOk then
    warn("[Addon System Test] Addons UI creation failed: " .. tostring(enableUiError))
end

local testTab
local tabOk, tabResult = pcall(function()
    testTab = Window:Tab({Name = "Addon Diagnostics", Icon = "activity", Type = "Grid"})
    return testTab
end)
if not tabOk or not testTab then
    warn("[Addon System Test] Diagnostics tab creation failed: " .. tostring(tabResult))
    return
end

local overview = testTab:Section({Title = "Automatic Checks", Column = 1})
local manual = testTab:Section({Title = "Manual Tests", Column = 2})
local statusLabels = {}

local function status(name, passed, detail)
    local symbol = passed and "✓" or "✕"
    local line = symbol .. "  " .. name .. (detail and (" · " .. tostring(detail)) or "")
    log(line)
    if statusLabels[name] then
        pcall(function() statusLabels[name]:Set(line) end)
    else
        local ok, label = pcall(function()
            return overview:Label({Text = line})
        end)
        if ok then statusLabels[name] = label end
    end
end

local function addManualLabel(name, text)
    local ok, label = pcall(function()
        return manual:Label({Text = text})
    end)
    if ok then statusLabels[name] = label end
end

status("Library loaded", type(Library) == "table", "Version " .. tostring(Library.Version or "?"))
status("Window created", Window ~= nil)
status("Addons API available", type(Window.Addons) == "function")
status("Addons UI created", Addons.tab ~= nil)
status("Isolated folder ready", fileReady, fileError or TEST_FOLDER)

local function findTestAddon()
    for _, addon in ipairs(Addons.list or {}) do
        if addon.file == "AddonSystemTest.lua" or addon.meta.name == "Addon System Test" then
            return addon
        end
    end
end

local testAddon = findTestAddon()
status("Test addon discovered", testAddon ~= nil, testAddon and testAddon.meta.name or (Addons.fsNote or "not found"))

if testAddon then
    status("New Lua table format detected", testAddon.modern == true)
    status("Addon metadata parsed", testAddon.meta.name == "Addon System Test",
        tostring(testAddon.meta.author or "?") .. " · " .. tostring(testAddon.meta.version or "?"))
    status("Standalone addon card created",
        testAddon.card ~= nil and testAddon.cardBadge ~= nil and testAddon.enableButton ~= nil,
        testAddon.card and testAddon.card.Name or "card UI missing")
    status("Addon control host created", testAddon.sec ~= nil and testAddon.sec.Toggle ~= nil)

    local enabled, enableError = pcall(function()
        return Addons.enable(testAddon)
    end)
    status("Addon Init executed", enabled and enableError == true and testAddon.loaded == true,
        enabled and (testAddon.err or "loaded") or tostring(enableError))

    local expected = {
        "Callback Test Toggle",
        "Callback Test Button",
        "Callback Test Slider",
        "Callback Test Dropdown",
        "Callback Test Input",
        "Test Save / Load",
    }
    local found = {}
    for _, control in ipairs(testAddon.ctrls or {}) do
        found[control.name or (control.o and control.o.Name)] = control
    end
    local allFound = true
    for _, name in ipairs(expected) do
        if not found[name] or not found[name].ui then allFound = false end
    end
    status("All interactive controls created", allFound, tostring(#(testAddon.ctrls or {})) .. " registered")

    local state = shared.__JLAddonSystemTest or {}
    status("Init state recorded", (state.Init or 0) >= 1, "Init calls: " .. tostring(state.Init or 0))

    local toggle = found["Callback Test Toggle"]
    if toggle and toggle.ui and type(toggle.ui.Set) == "function" then
        local toggleOk = pcall(function() toggle.ui:Set(true) end)
        task.wait(0.15)
        state = shared.__JLAddonSystemTest or {}
        status("Toggle callback", toggleOk and state.Toggle == true,
            "Tap the toggle manually if this executor does not fire callbacks from Set()")
    else
        status("Toggle callback", false, "Toggle UI:Set unavailable")
    end

    local unloadBefore = state.Unload or 0
    local disableOk = pcall(function()
        Addons.disable(testAddon)
    end)
    task.wait(0.1)
    state = shared.__JLAddonSystemTest or {}
    status("Disable / OnUnload", disableOk and not testAddon.loaded and (state.Unload or 0) > unloadBefore,
        "Unload calls: " .. tostring(state.Unload or 0))

    local reenableOk, reenableResult = pcall(function()
        return Addons.enable(testAddon)
    end)
    status("Re-enable addon", reenableOk and reenableResult == true and testAddon.loaded == true)
else
    status("New Lua table format detected", false, "test addon file was not scanned")
    status("Addon card created", false, Addons.fsNote or "no test addon entry")
    status("Addon Init executed", false, "requires file access")
    status("All interactive controls created", false, "requires file access")
end

addManualLabel("manual_intro", "Open the Addons tab. The test addon should appear as a separate rounded card with its own header, status badge, description, controls area and action buttons.")
addManualLabel("manual_import", "Tap + Import Addon and check that the multiline import window opens and closes.")
addManualLabel("manual_controls", "Tap each test control. Callback activity is printed in the executor console.")
addManualLabel("manual_storage", "Tap Test Save / Load inside the test addon card and check the console / notification.")

manual:Button({
    Name = "Check Callback Activity",
    Callback = function()
        local state = shared.__JLAddonSystemTest or {}
        local lines = {
            "Toggle: " .. tostring(state.Toggle),
            "Button calls: " .. tostring(state.Button or 0),
            "Slider: " .. tostring(state.Slider),
            "Dropdown: " .. tostring(state.Dropdown),
            "Input: " .. tostring(state.Input),
            "Storage: " .. tostring(state.Storage),
            "Unload calls: " .. tostring(state.Unload or 0),
        }
        log(table.concat(lines, " | "))
        if statusLabels.CallbackActivity then
            statusLabels.CallbackActivity:Set(table.concat(lines, "  ·  "))
        else
            statusLabels.CallbackActivity = manual:Label({Text = table.concat(lines, "  ·  ")})
        end
    end
})

manual:Button({
    Name = "Disable Test Addon",
    Callback = function()
        if testAddon then
            Addons.disable(testAddon)
            log("Test addon disabled.")
        end
    end
})

manual:Button({
    Name = "Enable Test Addon",
    Callback = function()
        if testAddon then
            local ok, result = pcall(function() return Addons.enable(testAddon) end)
            log("Enable result: " .. tostring(ok and result))
        end
    end
})

log("Test harness ready. Inspect the Addons tab and use the manual test buttons.")
