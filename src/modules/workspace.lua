local function createWorkspaceModule(deps)
    local shared = deps.Shared
    local readfile = deps.ReadFile
    local writefile = deps.WriteFile
    local isfolder = deps.IsFolder
    local makefolder = deps.MakeFolder
    local loadstring = deps.LoadString

    local workspace = shared._JLWorkspace
    if type(workspace) ~= "table" or workspace.Version ~= 1 then
        workspace = {Version = 1, Hubs = {}, ActiveHubId = nil, MultiHubTabsEnabled = true}
        shared._JLWorkspace = workspace
    end
    if type(workspace.Hubs) ~= "table" then workspace.Hubs = {} end
    if type(workspace.ConfigSaveQueue) ~= "table" then workspace.ConfigSaveQueue = {} end
    if workspace.MultiHubTabsLoaded ~= true then
        local loaded
        if type(readfile) == "function" then
            local ok, raw = pcall(readfile, "JustX/HubSettings.lua")
            if ok and type(raw) == "string" and raw ~= "" and type(loadstring) == "function" then
                local okFn, fn = pcall(loadstring, raw)
                if okFn and type(fn) == "function" then
                    local okData, data = pcall(fn)
                    if okData and type(data) == "table" then loaded = data end
                end
            end
        end
        if type(loaded) == "table" and type(loaded.MultiHubTabs) == "boolean" then
            workspace.MultiHubTabsEnabled = loaded.MultiHubTabs
        elseif workspace.MultiHubTabsEnabled == nil then
            workspace.MultiHubTabsEnabled = true
        end
        workspace.MultiHubTabsLoaded = true
    end
    workspace.JoinPolicy = nil
    workspace.JoinPromptEnabled = nil
    workspace.JoinSettingsLoaded = nil

    local function saveSettings()
        if type(writefile) ~= "function" then return false end
        if type(isfolder) == "function" then
            local ok, exists = pcall(isfolder, "JustX")
            if not ok or not exists then
                if type(makefolder) == "function" then pcall(makefolder, "JustX") end
            end
        elseif type(makefolder) == "function" then
            pcall(makefolder, "JustX")
        end
        local data = "return {MultiHubTabs=" .. tostring(workspace.MultiHubTabsEnabled ~= false) .. "}"
        local ok = pcall(writefile, "JustX/HubSettings.lua", data)
        return ok
    end

    local function setActiveHub(hubId, openTarget)
        local target = workspace.Hubs[hubId]
        if not target or not target.alive then return false end
        workspace.ActiveHubId = hubId
        shared._JLActive = target
        for otherId, entry in pairs(workspace.Hubs) do
            if entry and entry.alive and type(entry.setWorkspaceVisible) == "function" then
                pcall(entry.setWorkspaceVisible, otherId == hubId)
            end
        end
        if openTarget == true and type(target.openWindow) == "function" then
            pcall(target.openWindow)
        end
        return true
    end
    workspace.SetActiveHub = setActiveHub

    local currentHubId = "JustLib"
    local guiRoots = {}
    local function scopedGuiName(baseName, hubId)
        local safe = tostring(hubId or "JustLib"):gsub('[\\/:*?"<>|]', "_"):gsub("[%c]", "_")
        return "JL_" .. safe .. "_" .. tostring(baseName or "UI")
    end
    local function registerHubGui(gui, baseName)
        if not gui then return nil end
        gui.Name = scopedGuiName(baseName, currentHubId)
        guiRoots[#guiRoots + 1] = gui
        return gui
    end
    local function resolveHubIdentity(opts)
        local raw = opts.HubId
        if raw == nil or tostring(raw):match("^%s*$") then raw = opts.Config end
        if raw == nil or tostring(raw):match("^%s*$") then raw = "JustLib" end
        return tostring(raw):match("^%s*(.-)%s*$")
    end

    return {
        Workspace = workspace,
        SaveSettings = saveSettings,
        SetCurrentHubId = function(value) currentHubId = tostring(value or "JustLib") end,
        GetCurrentHubId = function() return currentHubId end,
        GuiRoots = guiRoots,
        ScopedGuiName = scopedGuiName,
        RegisterGui = registerHubGui,
        ResolveHubIdentity = resolveHubIdentity,
    }
end
