-- Studio plugin: lighting and camera controls for every preview viewport (global Preview controls).
local Plugin = {}

local PRESETS = {
    Studio  = { ambient = Color3.fromRGB(165, 165, 182), light = Color3.fromRGB(255, 255, 255), yaw = 215, elev = 50 },
    Sunset  = { ambient = Color3.fromRGB(190, 140, 120), light = Color3.fromRGB(255, 190, 130), yaw = 280, elev = 22 },
    Night   = { ambient = Color3.fromRGB(70, 80, 125), light = Color3.fromRGB(140, 160, 255), yaw = 150, elev = 35 },
    Neutral = { ambient = Color3.fromRGB(200, 200, 200), light = Color3.fromRGB(235, 235, 235), yaw = 200, elev = 60 },
}

local function direction(yawDeg, elevDeg)
    local y, e = math.rad(yawDeg), math.rad(elevDeg)
    return Vector3.new(math.sin(y) * math.cos(e), -math.sin(e), math.cos(y) * math.cos(e))
end

function Plugin.Init(context)
    assert(context and context.Preview, "Studio requires Preview context")
    local preview = context.Preview
    local controls = {}
    local alive = true
    local yaw, elev = PRESETS.Studio.yaw, PRESETS.Studio.elev

    local function apply()
        if alive then preview:SetView({ lightDir = direction(yaw, elev) }) end
    end

    controls[#controls + 1] = preview:Divider({ Label = "Studio lighting" })
    controls[#controls + 1] = preview:Dropdown({ Name = "Lighting preset", Options = { "Studio", "Sunset", "Night", "Neutral" }, Default = "Studio",
        Flag = "_pv_studio_preset", Callback = function(name)
            local p = PRESETS[name]
            if not p or not alive then return end
            yaw, elev = p.yaw, p.elev
            preview:SetView({ ambient = p.ambient, light = p.light, lightDir = direction(yaw, elev) })
        end })
    controls[#controls + 1] = preview:ColorPicker({ Name = "Ambient color", Default = PRESETS.Studio.ambient, Flag = "_pv_studio_ambient",
        Callback = function(c) if alive then preview:SetView({ ambient = c }) end end })
    controls[#controls + 1] = preview:ColorPicker({ Name = "Light color", Default = PRESETS.Studio.light, Flag = "_pv_studio_light",
        Callback = function(c) if alive then preview:SetView({ light = c }) end end })
    controls[#controls + 1] = preview:Slider({ Name = "Light direction", Min = 0, Max = 360, Step = 5, Default = yaw, Suffix = "°", Flag = "_pv_studio_yaw",
        Callback = function(v) yaw = v; apply() end })
    controls[#controls + 1] = preview:Slider({ Name = "Light height", Min = 5, Max = 85, Step = 5, Default = elev, Suffix = "°", Flag = "_pv_studio_elev",
        Callback = function(v) elev = v; apply() end })
    controls[#controls + 1] = preview:Slider({ Name = "Field of view", Min = 20, Max = 90, Step = 1, Default = 40, Suffix = "°", Flag = "_pv_studio_fov",
        Callback = function(v) if alive then preview:SetView({ fov = v }) end end })
    controls[#controls + 1] = preview:Toggle({ Name = "Ground disc", Default = true, Flag = "_pv_studio_ground",
        Callback = function(v) if alive then preview:SetView({ ground = v == true }) end end })

    return { Destroy = function()
        if not alive then return end
        alive = false
        for _, c in ipairs(controls) do pcall(function() c:Remove() end) end
        preview:SetView({ fov = 40, ambient = Color3.fromRGB(165, 165, 182), light = Color3.new(1, 1, 1),
            lightDir = Vector3.new(-1, -1.2, -0.8), ground = true })
    end }
end

return { Manifest = { Id = "studio", Name = "Studio", Version = "0.1.0", ApiVersion = 1 }, Init = Plugin.Init }
