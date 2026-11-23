-- Rig plugin: a plain gray rig, your own avatar, and every player in the server as previewable rigs.
local Plugin = {}

local Players = game:GetService("Players")

local GRAY = Color3.fromRGB(163, 162, 165)
local RIG_ENUM = { R15 = Enum.HumanoidRigType.R15, R6 = Enum.HumanoidRigType.R6 }
local SOURCE_SERVER, SOURCE_WEB = "Server character", "Web avatar"

local function cloneArchivable(source)
    local saved = {}
    local function allow(instance)
        local ok, old = pcall(function() return instance.Archivable end)
        if ok then
            saved[#saved + 1] = { instance, old }
            pcall(function() instance.Archivable = true end)
        end
    end
    allow(source)
    for _, descendant in ipairs(source:GetDescendants()) do allow(descendant) end
    local ok, copy = pcall(function() return source:Clone() end)
    for _, state in ipairs(saved) do
        pcall(function() state[1].Archivable = state[2] end)
    end
    if ok then return copy end
    return nil
end

local function applyPlain(model, color)
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("ShirtGraphic")
            or item:IsA("SurfaceAppearance") or item:IsA("BodyColors") or item:IsA("Decal")
            or item:IsA("CharacterMesh") then
            item:Destroy()
        end
    end
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("BasePart") then
            item.Color = color
            pcall(function() item.Material = Enum.Material.SmoothPlastic end)
            if item:IsA("MeshPart") then pcall(function() item.TextureID = "" end) end
        elseif item:IsA("SpecialMesh") then
            pcall(function() item.TextureId = "" end)
        end
    end
end

function Plugin.Init(context)
    assert(context and context.Preview, "Rig requires Preview context")
    local preview = context.Preview
    local localPlayer = Players.LocalPlayer
    local alive = true
    local settings = { source = SOURCE_SERVER, rigType = "R15", gray = GRAY, plain = false }
    local entries, byPlayer, connections = {}, {}, {}
    local quickAction

    local tab = preview:Tab({ Name = "Rigs", Icon = "user-round" })

    local function usesGray(entry)
        return entry.kind == "gray" or settings.plain
    end

    local function describe(entry)
        if entry.kind == "gray" then
            local description = Instance.new("HumanoidDescription")
            local c = settings.gray
            description.HeadColor, description.TorsoColor = c, c
            description.LeftArmColor, description.RightArmColor = c, c
            description.LeftLegColor, description.RightLegColor = c, c
            return description
        end
        local ok, description = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(entry.userId)
        end)
        if ok and description then return description end
        return nil, tostring(description)
    end

    -- Yields (web calls). Returns a detached Model or nil plus a reason.
    local function buildModel(entry)
        local model
        if entry.kind == "player" and settings.source == SOURCE_SERVER then
            local character = entry.player.Character
            if character then model = cloneArchivable(character) end
        end
        if not model then
            local description, err = describe(entry)
            if not description then return nil, "avatar description failed: " .. tostring(err) end
            local ok, built = pcall(function()
                return Players:CreateHumanoidModelFromDescription(description, RIG_ENUM[settings.rigType] or Enum.HumanoidRigType.R15)
            end)
            description:Destroy()
            if not ok or typeof(built) ~= "Instance" then
                return nil, "rig creation failed: " .. tostring(built)
            end
            model = built
        end
        model.Name = entry.name
        if usesGray(entry) then applyPlain(model, settings.gray) end
        return model
    end

    local function sourceText(entry)
        if entry.kind == "gray" then
            return "Plain gray rig (" .. settings.rigType .. ") built from an empty HumanoidDescription."
        end
        local from = settings.source == SOURCE_SERVER and "live server character (web avatar if it has none yet)" or "web avatar (" .. settings.rigType .. ")"
        return "Built from the " .. from .. (settings.plain and ", stripped to plain gray." or ".")
    end

    local function rebuild(entry)
        if not alive or entry.removed then return end
        entry.token = entry.token + 1
        local token = entry.token
        task.spawn(function()
            local model, err = buildModel(entry)
            if not alive or entry.removed or entry.token ~= token then
                if model then model:Destroy() end
                return
            end
            if not model then
                entry.asset:Update({ Description = "Could not build this rig: " .. tostring(err) })
                return
            end
            local old = entry.model
            entry.model = model
            entry.asset:Update({ Model = model, Description = sourceText(entry) })
            if old then old:Destroy() end
        end)
    end

    local pending = 0
    local function rebuildLater(filter)
        pending = pending + 1
        local mine = pending
        task.delay(0.35, function()
            if not alive or mine ~= pending then return end
            for _, entry in ipairs(entries) do
                if not filter or filter(entry) then rebuild(entry) end
            end
        end)
    end

    local function addEntry(entry)
        entry.token = 0
        entry.asset = tab:Asset({
            Name = entry.name, Type = "Rig", Creator = entry.creator, Description = "Building…", Tags = entry.tags,
            Actions = { { Name = "Rebuild", Icon = "refresh", Callback = function() rebuild(entry) end } },
        })
        entries[#entries + 1] = entry
        rebuild(entry)
    end

    local function addPlayer(player)
        if byPlayer[player] then return end
        local isMe = player == localPlayer
        local entry = {
            kind = "player", player = player, userId = player.UserId,
            name = isMe and (player.Name .. " (you)") or player.Name,
            creator = isMe and "You" or "Server player", tags = { "player", "avatar" },
        }
        byPlayer[player] = entry
        addEntry(entry)
        connections[#connections + 1] = player.CharacterAppearanceLoaded:Connect(function()
            if settings.source == SOURCE_SERVER then rebuild(entry) end
        end)
    end

    local function removePlayer(player)
        local entry = byPlayer[player]
        if not entry then return end
        byPlayer[player] = nil
        entry.removed = true
        for i, item in ipairs(entries) do
            if item == entry then table.remove(entries, i) break end
        end
        if entry.asset then entry.asset:Remove() end
        if entry.model then entry.model:Destroy() end
    end

    tab:Dropdown({ Name = "Appearance source", Options = { SOURCE_SERVER, SOURCE_WEB }, Default = SOURCE_SERVER,
        Flag = "_pv_rig_source", Callback = function(value)
            settings.source = value
            rebuildLater(function(entry) return entry.kind == "player" end)
        end })
    tab:Dropdown({ Name = "Rig type", Options = { "R15", "R6" }, Default = "R15",
        Flag = "_pv_rig_type", Callback = function(value)
            settings.rigType = value
            rebuildLater()
        end })
    tab:ColorPicker({ Name = "Gray tint", Default = GRAY, Flag = "_pv_rig_gray", Callback = function(color)
        settings.gray = color
        rebuildLater(usesGray)
    end })
    tab:Toggle({ Name = "Plain gray look for every rig", Default = false, Flag = "_pv_rig_plain", Callback = function(value)
        settings.plain = value == true
        rebuildLater()
    end })
    tab:Button({ Name = "Rebuild all rigs", Icon = "refresh", Callback = function() rebuildLater() end })

    addEntry({ kind = "gray", name = "Gray Rig", creator = "Rig plugin", tags = { "rig", "gray" } })
    if localPlayer then addPlayer(localPlayer) end
    for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end
    connections[#connections + 1] = Players.PlayerAdded:Connect(addPlayer)
    connections[#connections + 1] = Players.PlayerRemoving:Connect(removePlayer)

    if type(preview.QuickAction) == "function" then
        quickAction = preview:QuickAction({ Name = "Open Rigs", Icon = "user-round", Callback = function() tab:Open() end })
    end
    if type(preview.SetPluginOpen) == "function" then
        preview:SetPluginOpen(context.Id, function() tab:Open() end)
    end

    return {
        Destroy = function()
            if not alive then return end
            alive = false
            for _, connection in ipairs(connections) do connection:Disconnect() end
            for _, entry in ipairs(entries) do
                entry.removed = true
                if entry.model then entry.model:Destroy() end
            end
            entries = {}
            pcall(function() tab:Remove() end)
            if quickAction then quickAction:Remove() end
            if type(preview.SetPluginOpen) == "function" then preview:SetPluginOpen(context.Id, nil) end
        end,
    }
end

return { Manifest = { Id = "rig", Name = "Rig", Version = "0.1.0", ApiVersion = 1 }, Init = Plugin.Init }
