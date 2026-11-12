local function createControlHelpersModule(deps)
    local Color3 = deps.Color3
    local Math = deps.Math
    local String = deps.String
    local ToString = deps.ToString

    local function skinKnob(knob, knobStroke)
        knob.BackgroundTransparency = 0
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knobStroke.Color = Color3.fromRGB(20, 20, 24)
        knobStroke.Transparency = 0
    end

    local function decimalsOf(step)
        local d = ToString(step):match("%.(%d+)$")
        return d and #d or 0
    end

    local function fmtNum(v, dec)
        if dec <= 0 then return ToString(Math.floor(v + 0.5)) end
        local s = String.format("%." .. dec .. "f", v)
        s = s:gsub("0+$", ""):gsub("%.$", "")
        return s
    end

    local function snap(v, vmin, vmax, step)
        v = Math.clamp(v, vmin, vmax)
        v = vmin + Math.floor((v - vmin) / step + 0.5) * step
        local m = 10 ^ decimalsOf(step)
        v = Math.floor(v * m + 0.5) / m
        return Math.clamp(v, vmin, vmax)
    end

    return {
        SkinKnob = skinKnob,
        DecimalsOf = decimalsOf,
        FormatNumber = fmtNum,
        Snap = snap
    }
end
