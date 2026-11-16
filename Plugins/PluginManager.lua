-- Preview Plugin Manager.
-- Plugin code is fetched from the same repository branch and runs in the caller's
-- environment. This is a lifecycle manager, not a security sandbox.
local Manager = {}
Manager.__index = Manager

local BASE = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/preview/asset-browser-transfer/"

local function copyTable(source)
    local out = {}
    for k, v in pairs(source or {}) do
        if type(v) == "table" then
            out[k] = copyTable(v)
        else
            out[k] = v
        end
    end
    return out
end

local function validId(id)
    return type(id) == "string" and id:match("^[%w_%-]+$") ~= nil
end

function Manager.new(preview, bridge, registry)
    local self = setmetatable({}, Manager)
    self.Preview = preview
    self.Bridge = bridge
    self.Registry = {}
    self.Installed = {}
    self.Enabled = {}
    self.Loaded = {}
    self._destroyed = false

    for _, item in ipairs((registry and registry.Plugins) or {}) do
        if type(item) == "table" and validId(item.Id) and type(item.Entry) == "string" then
            self.Registry[item.Id] = copyTable(item)
        end
    end
    return self
end

function Manager:GetAvailable()
    local out = {}
    for _, item in pairs(self.Registry) do
        local entry = copyTable(item)
        entry.Installed = self.Installed[entry.Id] == true
        entry.Enabled = self.Enabled[entry.Id] == true
        out[#out + 1] = entry
    end
    table.sort(out, function(a, b) return a.Name < b.Name end)
    return out
end

function Manager:Get(id)
    local item = self.Registry[id]
    if not item then return nil end
    local out = copyTable(item)
    out.Installed = self.Installed[id] == true
    out.Enabled = self.Enabled[id] == true
    return out
end

function Manager:IsInstalled(id)
    return self.Installed[id] == true
end

function Manager:IsEnabled(id)
    return self.Enabled[id] == true
end

function Manager:_notify(title, description, kind)
    local notify = self.Bridge and self.Bridge.notify
    if type(notify) == "function" then
        pcall(notify, {Title = title, Desc = description, Type = kind or "Info", Duration = 5})
    end
end

function Manager:_download(path)
    if type(path) ~= "string" or path == "" or path:find("..", 1, true) then
        return nil, "Invalid plugin source path"
    end
    local gameRef = game
    local ok, body = pcall(function()
        return gameRef:HttpGet(BASE .. path)
    end)
    if not ok or type(body) ~= "string" or body == "" then
        return nil, "Could not download plugin source: " .. tostring(body)
    end
    local head = body:sub(1, 180):lower()
    if body:sub(1, 1) == "<" or head:find("404", 1, true) or head:find("not found", 1, true) then
        return nil, "Plugin source was not found: " .. path
    end
    return body
end

function Manager:_loadModule(path)
    local body, err = self:_download(path)
    if not body then return nil, err end
    if type(loadstring) ~= "function" then
        return nil, "loadstring is unavailable in this environment"
    end
    local fn, compileError = loadstring(body)
    if type(fn) ~= "function" then
        return nil, "Plugin compile failed: " .. tostring(compileError)
    end
    local ok, module = pcall(fn)
    if not ok or type(module) ~= "table" then
        return nil, "Plugin module failed: " .. tostring(module)
    end
    return module
end

function Manager:_context(id)
    local manager = self
    local context = {
        Preview = self.Preview,
        Bridge = self.Bridge,
        UI = self.Preview and self.Preview:GetPluginUI() or {},
        Icon = function(parent, name, size, color)
            return manager.Preview:CreateIcon(parent, name, size, color)
        end,
        Plugins = self,
        Id = id,
        Notify = function(title, description, kind)
            manager:_notify(title, description, kind)
        end,
        IsAlive = function()
            return not manager._destroyed and manager.Preview and manager.Preview.alive == true
        end,
    }
    return context
end

function Manager:_start(id)
    local definition = self.Registry[id]
    if not definition then return false, "PLUGIN_NOT_FOUND" end
    if self.Loaded[id] then return true, self.Loaded[id] end

    local module, err = self:_loadModule(definition.Entry)
    if not module then return false, "PLUGIN_LOAD_FAILED: " .. tostring(err) end

    local manifest = module.Manifest
    if type(manifest) ~= "table" or manifest.Id ~= id then
        return false, "PLUGIN_MANIFEST_INVALID"
    end
    if type(module.Init) ~= "function" then
        return false, "PLUGIN_INIT_MISSING"
    end

    local ok, result = pcall(module.Init, self:_context(id))
    if not ok then
        return false, "PLUGIN_INIT_FAILED: " .. tostring(result)
    end

    local record = {
        Module = module,
        Instance = result,
        Cleanup = type(result) == "function" and result or
            (type(result) == "table" and type(result.Destroy) == "function" and function()
                result:Destroy()
            end or nil),
        Version = tostring(manifest.Version or definition.Version or "0"),
    }
    self.Loaded[id] = record
    return true, record
end

function Manager:_stop(id)
    local record = self.Loaded[id]
    if not record then return true end
    self.Loaded[id] = nil
    if type(record.Cleanup) == "function" then
        local ok, err = pcall(record.Cleanup)
        if not ok then
            warn("[Preview Plugins] cleanup failed for " .. id .. ": " .. tostring(err))
        end
    end
    return true
end

function Manager:Install(id)
    if self._destroyed then return false, "PREVIEW_DESTROYED" end
    local definition = self.Registry[id]
    if not definition then return false, "PLUGIN_NOT_FOUND" end
    if self.Installed[id] then return true, "ALREADY_INSTALLED" end

    -- Validate source and manifest before persisting installation state.
    local module, err = self:_loadModule(definition.Entry)
    if not module then return false, err end
    if type(module.Manifest) ~= "table" or module.Manifest.Id ~= id or type(module.Init) ~= "function" then
        return false, "PLUGIN_PACKAGE_INVALID"
    end

    self.Installed[id] = true
    self.Enabled[id] = true
    local bridge = self.Bridge
    if bridge and type(bridge.cfgSet) == "function" then
        bridge.cfgSet("_pv_plugin_" .. id .. "_installed", true)
        bridge.cfgSet("_pv_plugin_" .. id .. "_enabled", true)
    end

    local ok, result = self:_start(id)
    if not ok then
        self.Installed[id], self.Enabled[id] = nil, nil
        if bridge and type(bridge.cfgSet) == "function" then
            bridge.cfgSet("_pv_plugin_" .. id .. "_installed", false)
            bridge.cfgSet("_pv_plugin_" .. id .. "_enabled", false)
        end
        return false, result
    end
    self:_notify("Plugin installed", definition.Name .. " is ready.", "Success")
    return true, result
end

function Manager:Enable(id)
    if not self.Registry[id] then return false, "PLUGIN_NOT_FOUND" end
    if not self.Installed[id] then return false, "PLUGIN_NOT_INSTALLED" end
    if self.Enabled[id] then return true, "ALREADY_ENABLED" end
    local ok, result = self:_start(id)
    if not ok then return false, result end
    self.Enabled[id] = true
    if self.Bridge and self.Bridge.cfgSet then
        self.Bridge.cfgSet("_pv_plugin_" .. id .. "_enabled", true)
    end
    return true, result
end

function Manager:Disable(id)
    if not self.Registry[id] then return false, "PLUGIN_NOT_FOUND" end
    if not self.Installed[id] then return false, "PLUGIN_NOT_INSTALLED" end
    self:_stop(id)
    self.Enabled[id] = nil
    if self.Bridge and self.Bridge.cfgSet then
        self.Bridge.cfgSet("_pv_plugin_" .. id .. "_enabled", false)
    end
    return true
end

function Manager:Uninstall(id)
    if not self.Registry[id] then return false, "PLUGIN_NOT_FOUND" end
    self:_stop(id)
    self.Installed[id], self.Enabled[id] = nil, nil
    if self.Bridge and self.Bridge.cfgSet then
        self.Bridge.cfgSet("_pv_plugin_" .. id .. "_installed", false)
        self.Bridge.cfgSet("_pv_plugin_" .. id .. "_enabled", false)
    end
    return true
end

function Manager:LoadInstalled()
    if self._destroyed then return false end
    for id in pairs(self.Registry) do
        local bridge = self.Bridge
        local installed = bridge and bridge.cfgGet and bridge.cfgGet("_pv_plugin_" .. id .. "_installed", false) == true
        local enabled = bridge and bridge.cfgGet and bridge.cfgGet("_pv_plugin_" .. id .. "_enabled", true) ~= false
        if installed then
            self.Installed[id] = true
            if enabled then
                local ok, err = self:_start(id)
                if ok then
                    self.Enabled[id] = true
                else
                    self.Enabled[id] = nil
                    warn("[Preview Plugins] could not restore " .. id .. ": " .. tostring(err))
                end
            end
        end
    end
    return true
end

function Manager:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    for id in pairs(self.Loaded) do
        self:_stop(id)
    end
    self.Registry, self.Installed, self.Enabled, self.Loaded = {}, {}, {}, {}
    self.Preview, self.Bridge = nil, nil
end

return Manager
