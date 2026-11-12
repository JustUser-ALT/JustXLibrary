-- Icons module factory. Dependencies are injected; icon state stays on the library instance.
local function createIconsModule(deps)
    local JL = deps.JL
    local GB = deps.BoldFont
    local C = deps.Colors
    local Instance = deps.Instance
    local Enum = deps.Enum
    local UDim2 = deps.UDim2
    local Vector2 = deps.Vector2
    local typeof = deps.Typeof
    local game = deps.Game
    local loadstring = deps.LoadString

    JL._iconOverrides = {}
    JL._iconTextNodes = {}
    local ICON_PACK_URL = "https://molto.pages.dev/source.lua"
    local function iconAsset(name)
        local pack = JL._iconPack
        if not pack then return nil end
        local asset
        if type(pack.GetAsset) == "function" then
            local ok,value = pcall(pack.GetAsset, name)
            if ok then asset = value end
        end
        if asset == nil and type(pack.GetIcon) == "function" then
            local ok,value = pcall(pack.GetIcon, name)
            if ok then asset = value end
        end
        if typeof(asset) == "Instance" then
            if asset:IsA("ImageLabel") or asset:IsA("ImageButton") then
                asset = {Url = asset.Image, ImageRectOffset = asset.ImageRectOffset, ImageRectSize = asset.ImageRectSize}
            elseif asset:IsA("TextLabel") or asset:IsA("TextButton") then
                asset = {Text = asset.Text, Font = asset.Font, FontFace = asset.FontFace}
            else
                return nil
            end
        end
        if type(asset) == "string" or type(asset) == "number" then
            local value = tostring(asset)
            if value ~= "" then return {Url = value} end
            return nil
        end
        if type(asset) ~= "table" then return nil end
        local url = asset.Url or asset.Image or asset.ImageUrl or asset.Texture
            or asset.Asset or asset.AssetId or asset.ImageId or asset.Id
        local text = asset.Text or asset.Glyph
        if url ~= nil and tostring(url) ~= "" then
            return {
                Url = tostring(url),
                ImageRectOffset = typeof(asset.ImageRectOffset) == "Vector2" and asset.ImageRectOffset or Vector2.zero,
                ImageRectSize = typeof(asset.ImageRectSize) == "Vector2" and asset.ImageRectSize or Vector2.zero,
                FontFace = asset.FontFace,
                Text = text,
            }
        end
        if text ~= nil and tostring(text) ~= "" then
            return {Text = tostring(text), Font = asset.Font, FontFace = asset.FontFace}
        end
        return nil
    end
    local function iconImageId(value)
        local value = tostring(value or "")
        if value:match("^%d+$") then return "rbxassetid://" .. value end
        if value:match("^rbxassetid://") or value:match("^https?://") then return value end
        return nil
    end
    local function applyIcon(entry)
        local label = entry and entry.label
        if not (label and label.Parent) then return false end
        local raw = JL._iconOverrides[entry.name]
        local asset
        if raw ~= nil then
            if type(raw) == "table" then
                asset = raw
            else
                asset = {Url = tostring(raw)}
            end
        else
            asset = iconAsset(entry.name)
            if not asset and JL._iconPack and JL._iconPack[entry.name] ~= nil then
                local fallback = JL._iconPack[entry.name]
                if type(fallback) == "string" or type(fallback) == "number" then
                    asset = {Url = tostring(fallback)}
                end
            end
        end
        local imageUrl = asset and iconImageId(asset.Url or asset.Image or asset.Id)
        local image = label:FindFirstChild("JLIconAsset")
        if imageUrl then
            if not image then
                image = Instance.new("ImageLabel")
                image.Name = "JLIconAsset"
                image.BackgroundTransparency = 1
                image.BorderSizePixel = 0
                image.Size = UDim2.new(1,0,1,0)
                image.Position = UDim2.new(0,0,0,0)
                image.ScaleType = Enum.ScaleType.Fit
                image.ZIndex = label.ZIndex
                image.Parent = label
            end
            image.Image = imageUrl
            image.ImageRectOffset = typeof(asset.ImageRectOffset) == "Vector2" and asset.ImageRectOffset or Vector2.zero
            image.ImageRectSize = typeof(asset.ImageRectSize) == "Vector2" and asset.ImageRectSize or Vector2.zero
            image.ImageColor3 = label.TextColor3
            image.Visible = true
            label.Text = ""
            label.TextTransparency = 1
            return true
        end
        if image then image.Visible = false end
        if asset and asset.Text then
            label.Text = tostring(asset.Text)
            label.TextTransparency = 0
            if asset.FontFace then
                pcall(function() label.FontFace = asset.FontFace end)
            elseif asset.Font then
                pcall(function() label.Font = asset.Font end)
            end
            return true
        end
        label.Text = entry.name
        label.TextTransparency = 0
        label.Font = GB
        return false
    end
    local function refreshIconTextNodes()
        for i = #JL._iconTextNodes, 1, -1 do
            local entry = JL._iconTextNodes[i]
            if not (entry.label and entry.label.Parent) then
                table.remove(JL._iconTextNodes, i)
            else
                applyIcon(entry)
            end
        end
    end
    function JL:LoadIconPack(url)
        url = url or ICON_PACK_URL
        local ok,body = pcall(function() return game:HttpGet(url) end)
        if not ok or not body or body == "" then return false end
        local ok2,fn = pcall(loadstring, body)
        if not ok2 or type(fn) ~= "function" then return false end
        local ok3,mod = pcall(fn)
        if not ok3 or type(mod) ~= "table" then return false end
        if type(mod.SetProvider) == "function" then
            local providerOk = pcall(mod.SetProvider, "lucide")
            if not providerOk then return false end
        end
        JL._iconPack = mod
        refreshIconTextNodes()
        return true
    end
    function JL:SetIconType(iconType)
        if JL._iconPack then
            if JL._iconPack.SetProvider then pcall(JL._iconPack.SetProvider, iconType)
            elseif JL._iconPack.SetIconsType then pcall(JL._iconPack.SetIconsType, iconType) end
            refreshIconTextNodes()
        end
    end
    function JL:SetIcons(tbl)
        for k,v in pairs(tbl or {}) do JL._iconOverrides[k] = v end
        refreshIconTextNodes()
    end
    local function resolveIcon(s)
        local override = JL._iconOverrides[s]
        if override ~= nil then
            if type(override) == "table" then return override end
            return tostring(override)
        end
        local asset = iconAsset(s)
        if asset then return asset end
        if JL._iconPack and JL._iconPack[s] then return JL._iconPack[s] end
        return s
    end
    local function mkIcon(parent,icon,sz,z)
        sz = sz or 20; z = z or 13
        local name = tostring(icon)
        local resolved = resolveIcon(name)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0,sz,0,sz)
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.Text = name
        label.TextScaled = true
        label.Font = GB
        label.TextColor3 = C.txt
        label.ZIndex = z
        label.Parent = parent
        local entry = {label = label, name = name}
        JL._iconTextNodes[#JL._iconTextNodes + 1] = entry
        if type(resolved) == "table" then
            applyIcon(entry)
        elseif type(resolved) == "string" then
            local imageUrl = iconImageId(resolved)
            if imageUrl then
                applyIcon({label = label, name = name})
                local image = label:FindFirstChild("JLIconAsset")
                if not image then
                    image = Instance.new("ImageLabel")
                    image.Name = "JLIconAsset"
                    image.BackgroundTransparency = 1
                    image.BorderSizePixel = 0
                    image.Size = UDim2.new(1,0,1,0)
                    image.ScaleType = Enum.ScaleType.Fit
                    image.ZIndex = z
                    image.Parent = label
                end
                image.Image = imageUrl
                image.ImageColor3 = label.TextColor3
                label.Text = ""
                label.TextTransparency = 1
            else
                label.Text = resolved
            end
        end
        return label
    end

    return {
        Make = mkIcon
    }
end
