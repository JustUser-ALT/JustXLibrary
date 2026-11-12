local Config = createConfigModule({
    JL = JL,
    Workspace = _workspace,
    HTTP = HTTP,
    ReadFile = readfile,
    WriteFile = writefile,
    IsFolder = isfolder,
    MakeFolder = makefolder,
    LoadString = loadstring,
    Task = task
})
local _cfgFile = nil
local _cfgData = Config.Data
local _memData = Config.MemoryData
local _globalSettingsData = Config.GlobalSettingsData
local _presetSettingsOverrides = Config.PresetSettingsOverrides
local function safeFileName(value) return Config.SafeFileName(value) end
local function ensureFolder(path) return Config.EnsureFolder(path) end
local function isLibrarySetting(flag) return Config.IsLibrarySetting(flag) end
local function loadGlobalSettings() return Config.LoadGlobalSettings() end
local function cfgLoad(name)
    _cfgFile = Config.Load(name)
    return _cfgFile
end
local function cfgSave() return Config.Save() end
local function cfgHas(flag) return Config.Has(flag) end
local function cfgSet(flag, val, store) return Config.Set(flag, val, store) end
local function cfgGet(flag, default) return Config.Get(flag, default) end
