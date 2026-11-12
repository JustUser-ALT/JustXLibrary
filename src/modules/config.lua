-- Config module factory. Dependencies are injected; config state stays private.
local function createConfigModule(deps)
    local JL = deps.JL
    local _workspace = deps.Workspace
    local HTTP = deps.HTTP
    local readfile = deps.ReadFile
    local writefile = deps.WriteFile
    local isfolder = deps.IsFolder
    local makefolder = deps.MakeFolder
    local loadstring = deps.LoadString
    local task = deps.Task

    local _cfgFile = nil
    local _cfgData = {}
    local _memData = {}
    local _globalSettingsFile = "JustX/Settings.lua"
    _workspace.GlobalSettings = type(_workspace.GlobalSettings) == "table" and _workspace.GlobalSettings or {}
    _workspace.GlobalSettingsEnabled = _workspace.GlobalSettingsEnabled ~= false
    _workspace.GlobalSettingsLoaded = _workspace.GlobalSettingsLoaded == true
    local _globalSettingsData = _workspace.GlobalSettings
    local _applyingPreset = false
    local _presetSettingsOverrides = {}
    local _autoSave = true
    local _addonAutoSave = false
    JL._autoSave = _autoSave; JL._addonAutoSave = _addonAutoSave
    JL._globalSettingsEnabled = _workspace.GlobalSettingsEnabled ~= false

local function safeFileName(value)
    local name = tostring(value or "JustLib")
    name = name:gsub("[\\/:*?\"<>|]", "_"):gsub("[%c]", "_")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or name == "." or name == ".." then name = "JustLib" end
    return name
end
local function ensureFolder(path)
    if type(path) ~= "string" or path == "" then return false end
    local current = ""
    for part in string.gmatch(path, "[^/\\]+") do
        current = (current == "") and part or (current .. "/" .. part)
        local exists = false
        if isfolder then
            local ok, result = pcall(isfolder, current)
            exists = ok and result == true
        end
        if not exists and makefolder then pcall(makefolder, current) end
    end
    if isfolder then
        local ok, result = pcall(isfolder, path)
        return ok and result == true
    end
    return makefolder ~= nil
end
local function serializeLua(value, seen)
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return "0" end
        return tostring(value)
    end
    if kind == "boolean" then return tostring(value) end
    if kind ~= "table" then return "nil" end
    seen = seen or {}
    if seen[value] then return "{}" end
    seen[value] = true
    local parts = {}
    for key, item in pairs(value) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" then
            parts[#parts + 1] = "[" .. serializeLua(key, seen) .. "]=" .. serializeLua(item, seen)
        end
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end
local function isLibrarySetting(flag)
    if type(flag) ~= "string" or flag:sub(1,1) ~= "_" then return false end
    local excluded = {
        _autosave = true, _addons_autosave = true, _autoload = true,
        _autoload_name = true, _preset_save_settings = true,
        _global_settings = true, _enabled = true, _jl_changelog_seen_version = true,
    }
    return not excluded[flag]
end
local function saveGlobalSettings()
    if not writefile or _workspace.GlobalSaveQueued then return end
    _workspace.GlobalSaveQueued = true
    -- This write belongs to the shared workspace, not to one hub's lifetime.
    task.delay(.4, function()
        _workspace.GlobalSaveQueued = false
        ensureFolder("JustX")
        _globalSettingsData._enabled = _workspace.GlobalSettingsEnabled ~= false
        pcall(function()
            writefile(_globalSettingsFile, "return " .. serializeLua(_globalSettingsData))
        end)
    end)
end
local function loadGlobalSettings()
    if not _workspace.GlobalSettingsLoaded then
        local loaded = {}
        if readfile then
            local ok, raw = pcall(readfile, _globalSettingsFile)
            if ok and type(raw) == "string" and raw ~= "" and type(loadstring) == "function" then
                local okFn, fn = pcall(loadstring, raw)
                if okFn and type(fn) == "function" then
                    local okData, data = pcall(fn)
                    if okData and type(data) == "table" then loaded = data end
                end
            end
        end
        for key in pairs(_globalSettingsData) do _globalSettingsData[key] = nil end
        for key, value in pairs(loaded) do _globalSettingsData[key] = value end
        _workspace.GlobalSettingsEnabled = _globalSettingsData._enabled ~= false
        _workspace.GlobalSettingsLoaded = true
    end
    JL._globalSettingsEnabled = _workspace.GlobalSettingsEnabled ~= false
end
local function persistable(flag)
    if type(flag) ~= "string" then return true end
    if flag:sub(1,1) == "_" then return true end -- настройки интерфейса сохраняются всегда
    if flag:sub(1,6) == "addon." then return _addonAutoSave == true end
    return _autoSave ~= false
end
local function cfgLoad(name)
    loadGlobalSettings()
    local configName = safeFileName(name)
    ensureFolder("JustX/Configs")
    _cfgFile = "JustX/Configs/" .. configName .. ".json"
    for key in pairs(_cfgData) do _cfgData[key] = nil end
    local pendingSave = _workspace.ConfigSaveQueue[_cfgFile]
    if pendingSave and type(pendingSave.data) == "string" and pendingSave.data ~= "" then
        local decodeOk, data = pcall(HTTP.JSONDecode, HTTP, pendingSave.data)
        if decodeOk and type(data) == "table" then for key, value in pairs(data) do _cfgData[key] = value end end
    elseif readfile then
        local ok, raw = pcall(readfile, _cfgFile)
        if (not ok or not raw or raw == "") then
            local legacyPath = tostring(name) .. ".json"
            local oldOk, oldRaw = pcall(readfile, legacyPath)
            if oldOk and type(oldRaw) == "string" and oldRaw ~= "" then
                local decodeOk, oldData = pcall(HTTP.JSONDecode, HTTP, oldRaw)
                if decodeOk and type(oldData) == "table" then
                    for key, value in pairs(oldData) do _cfgData[key] = value end
                    if writefile then pcall(writefile, _cfgFile, oldRaw) end
                end
            end
        else
            local decodeOk, data = pcall(HTTP.JSONDecode, HTTP, raw)
            if decodeOk and type(data) == "table" then for key, value in pairs(data) do _cfgData[key] = value end end
        end
    end
    _autoSave = (_cfgData._autosave ~= false)
    _addonAutoSave = (_cfgData._addons_autosave == true)
    JL._autoSave = _autoSave; JL._addonAutoSave = _addonAutoSave
    if _workspace.GlobalSettingsEnabled then
        local seeded = false
        for flag,val in pairs(_cfgData) do
            if isLibrarySetting(flag) and _globalSettingsData[flag] == nil then
                _globalSettingsData[flag] = val
                seeded = true
            end
        end
        if seeded then saveGlobalSettings() end
    end
    return _cfgFile
end
local function cfgSave()
    if not (_cfgFile and writefile) then return end
    local okEncode, encoded = pcall(HTTP.JSONEncode, HTTP, _cfgData)
    if not okEncode or type(encoded) ~= "string" then return end
    local path = _cfgFile
    local queue = _workspace.ConfigSaveQueue
    local pending = queue[path]
    if pending then
        pending.data = encoded
        return
    end
    pending = {data = encoded}
    queue[path] = pending
    -- Config writes must outlive the hub being reloaded or destroyed.
    task.delay(.4, function()
        if queue[path] ~= pending then return end
        local payload = pending.data
        ensureFolder("JustX/Configs")
        pcall(function() writefile(path, payload) end)
        if queue[path] == pending then queue[path] = nil end
    end)
end
local function cfgHas(flag)
    if flag == nil then return false end
    if flag == "_global_settings" then return true end
    if isLibrarySetting(flag) and _presetSettingsOverrides[flag] ~= nil then return true end
    if isLibrarySetting(flag) and _workspace.GlobalSettingsEnabled and _globalSettingsData[flag] ~= nil then return true end
    if persistable(flag) then return _cfgData[flag] ~= nil end
    return _memData[flag] ~= nil
end
local function cfgSet(flag,val,store)
    if not flag then return end
    if store == nil then store = val end
    if flag == "_autosave" then _autoSave = val ~= false; JL._autoSave = _autoSave end
    if flag == "_addons_autosave" then _addonAutoSave = val == true; JL._addonAutoSave = _addonAutoSave end
    JL.Flags[flag] = val
    if flag == "_global_settings" then
        if val == true then for key in pairs(_presetSettingsOverrides) do _presetSettingsOverrides[key] = nil end end
        _workspace.GlobalSettingsEnabled = val == true
        JL._globalSettingsEnabled = _workspace.GlobalSettingsEnabled
        _globalSettingsData._enabled = _workspace.GlobalSettingsEnabled
        saveGlobalSettings()
        return
    end
    if persistable(flag) then _cfgData[flag] = store; _memData[flag] = nil; cfgSave()
    else _memData[flag] = store end
    if isLibrarySetting(flag) then
        if _applyingPreset then
            _presetSettingsOverrides[flag] = store
        else
            _presetSettingsOverrides[flag] = nil
            if _workspace.GlobalSettingsEnabled then
                _globalSettingsData[flag] = store
                saveGlobalSettings()
            end
        end
    end
end
local function cfgGet(flag,default)
    if flag then
        if flag == "_global_settings" then
            JL.Flags[flag] = _workspace.GlobalSettingsEnabled
            return _workspace.GlobalSettingsEnabled
        end
        if isLibrarySetting(flag) and _presetSettingsOverrides[flag] ~= nil then
            JL.Flags[flag] = _presetSettingsOverrides[flag]
            return _presetSettingsOverrides[flag]
        end
        if isLibrarySetting(flag) and _workspace.GlobalSettingsEnabled and _globalSettingsData[flag] ~= nil then
            JL.Flags[flag] = _globalSettingsData[flag]
            return _globalSettingsData[flag]
        end
        if persistable(flag) then
            if _cfgData[flag] ~= nil then JL.Flags[flag] = _cfgData[flag]; return _cfgData[flag] end
        elseif _memData[flag] ~= nil then
            JL.Flags[flag] = _memData[flag]; return _memData[flag]
        end
        JL.Flags[flag] = default
    end
    return default
end
-- Auto Save снова включили: записываем на диск то, что копилось в памяти
local function cfgFlush()
    local any = false
    for flag,v in pairs(_memData) do
        if persistable(flag) then _cfgData[flag] = v; _memData[flag] = nil; any = true end
    end
    if any then cfgSave() end
end

    JL._cfgFlush = cfgFlush
    return {
        Data = _cfgData,
        MemoryData = _memData,
        GlobalSettingsData = _globalSettingsData,
        PresetSettingsOverrides = _presetSettingsOverrides,
        Load = cfgLoad,
        Save = cfgSave,
        Has = cfgHas,
        Set = cfgSet,
        Get = cfgGet,
        Flush = cfgFlush,
        SafeFileName = safeFileName,
        EnsureFolder = ensureFolder,
        IsLibrarySetting = isLibrarySetting,
        LoadGlobalSettings = loadGlobalSettings,
        GetFile = function() return _cfgFile end,
        SetApplyingPreset = function(value) _applyingPreset = value == true end,
        ClearPresetSettingsOverrides = function()
            for key in pairs(_presetSettingsOverrides) do _presetSettingsOverrides[key] = nil end
        end,
        Fork = function() return createConfigModule(deps) end
    }
end
