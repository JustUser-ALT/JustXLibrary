-- Guide module factory. Dependencies are injected; guide state stays private to the library instance.
local function createGuideModule(deps)
    local JL = deps.JL
    local Instance = deps.Instance
    local UDim2 = deps.UDim2
    local ACCENTS = deps.Accents
    local corner = deps.Corner
    local stroke = deps.Stroke
    local TweenInfo = deps.TweenInfo
    local Enum = deps.Enum
    local createTween = deps.CreateTween
    local trackedDelay = deps.TrackedDelay
    local trackedSpawn = deps.TrackedSpawn
    local task = deps.Task
    local clock = deps.Clock

    local GUIDE = {pulses = {}, active = nil}
    function GUIDE.targetOf(n)
        if n.Target then return n.Target end
        if n.Flag then return JL._registry[n.Flag] end
    end
    function GUIDE.met(n,base)
        local target = GUIDE.targetOf(n)
        if not target or not target.Get then return true end
        local v = target:Get()
        if n.Press then
            if base == nil then return false end
            return (tonumber(v) or 0) > base
        end
        if n.Check then
            local ok,res = pcall(n.Check, v)
            return (ok and res) and true or false
        end
        if n.State ~= nil then return v == n.State end
        return true
    end
    function GUIDE.stopPulse()
        for _,f in ipairs(GUIDE.pulses) do if f and f.Parent then f:Destroy() end end
        GUIDE.pulses = {}
    end
    function GUIDE.cancel() GUIDE.active = nil; GUIDE.stopPulse() end
    function GUIDE.pulse(row,duration)
        local hl = Instance.new("Frame"); hl.Name = "JLGuideHL"; hl.Size = UDim2.new(1,0,1,0); hl.BackgroundColor3 = ACCENTS[1]; hl.BackgroundTransparency = 0.88
        hl.BorderSizePixel = 0; hl.ZIndex = 40; hl.Parent = row; corner(7,hl)
        hl:SetAttribute("JLNoRepaint", true)
        local st = stroke(ACCENTS[1], 2, hl); st:SetAttribute("JLNoRepaint", true)
        local info = TweenInfo.new(.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        createTween(hl, info, {BackgroundTransparency = 0.7}):Play()
        createTween(st, info, {Transparency = 0.75}):Play()
        GUIDE.pulses[#GUIDE.pulses + 1] = hl
        if duration and duration > 0 then trackedDelay(duration, function() if hl and hl.Parent then hl:Destroy() end end) end
        return hl
    end
    local function groupRules(o)
        if not o.Masters then return nil end
        local ml = o.Masters
        if type(ml) == "string" then ml = {ml} end
        local set = {}
        for _,m in ipairs(ml) do set[m] = true end
        return {list = ml, set = set, move = (o.Mode == "Move"), clear = o.ClearOthers ~= false}
    end
    function GUIDE.first(list,skip)
        for _,m in ipairs(list) do if m ~= skip and not GUIDE.met(m, nil) then return m end end
    end
    function GUIDE.start(src,n)
        GUIDE.cancel()
        local token = {}
        GUIDE.active = token
        trackedSpawn(function()
            local target = GUIDE.targetOf(n)
            local trow = target and target.Row
            local msg = n.Message or src.cfg.NeedsMessage
            if msg then JL:Notify({Title = n.Title or "Action required", Desc = msg, Type = "Warn", Duration = 3}) end
            if not (trow and trow.Parent) then GUIDE.active = nil; return end
            local base = n.Press and (tonumber(target:Get()) or 0) or nil
            if GUIDE.nav then GUIDE.nav(trow) end
            if GUIDE.active ~= token then return end
            GUIDE.pulse(trow)
            local t0 = os.clock()
            while GUIDE.active == token and os.clock() - t0 < (src.cfg.NeedsTimeout or 180) do
                if GUIDE.met(n, base) then break end
                task.wait(.15)
            end
            if GUIDE.active ~= token then return end
            GUIDE.stopPulse()
            if not GUIDE.met(n, base) then GUIDE.active = nil; return end
            local nxt = GUIDE.first(src.list, n)
            if nxt then GUIDE.start(src, nxt); return end
            GUIDE.active = nil
            if src.cfg.AutoReturn ~= false and src.row and src.row.Parent then
                task.wait(.25)
                if GUIDE.nav then GUIDE.nav(src.row) end
                GUIDE.pulse(src.row, 2.4)
            end
            if src.cfg.AutoApply and src.apply then src.apply() end
        end)
    end
    function GUIDE.block(o,row,apply)
        local list = o.Needs
        if list.Flag or list.Target then list = {list} end
        local first = GUIDE.first(list, nil)
        if not first then return false end
        GUIDE.start({row = row, cfg = o, list = list, apply = apply}, first)
        return true
    end

    return {
        Guide = GUIDE,
        GroupRules = groupRules
    }
end
