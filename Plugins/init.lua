-- Animation plugin 1.0: animator page with transport controls and a keyframe track timeline.
-- Tracks come from the authored KeyframeSequence when the client may read it; otherwise they are
-- reconstructed by sampling every Motor6D while the animation is scrubbed (approximate keyframes).
local Plugin = {}

local RunService = game:GetService("RunService")
local KeyframeProvider = game:GetService("KeyframeSequenceProvider")

local function discover(asset)
    local model = asset and asset.Model
    if typeof(model) ~= "Instance" then return {} end
    local out, seen = {}, {}
    local function add(animation, state)
        if not animation or not animation:IsA("Animation") then return end
        local id = tostring(animation.AnimationId or "")
        if id == "" then return end
        if seen[id] then
            if state == "Playing" then seen[id].State = state end
            return
        end
        local name = tostring(animation.Name or "")
        local generic = name == "" or name:lower():match("^animation%d*$") ~= nil
        if generic then
            local p = animation.Parent
            while p and p ~= model do
                local n = tostring(p.Name or "")
                local lower = n:lower()
                if n ~= "" and lower ~= "animations" and lower ~= "animate" and lower ~= "animator" and lower ~= "humanoid"
                    and lower ~= "animationcontroller" and not lower:match("^animation%d*$") then
                    name = n
                    break
                end
                p = p.Parent
            end
        else
            name = name:gsub("[Aa]nim$", "")
        end
        if name == "" or name:lower():match("^animation%d*$") then name = "Animation • " .. id:sub(-6) end
        seen[id] = { Name = name, AnimationId = id, Object = animation, State = state or "Available" }
        out[#out + 1] = seen[id]
    end
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("Animation") then
            add(item)
        elseif item:IsA("Animator") then
            local ok, tracks = pcall(function() return item:GetPlayingAnimationTracks() end)
            if ok then
                for _, track in ipairs(tracks) do
                    local animation
                    pcall(function() animation = track.Animation end)
                    if animation then add(animation, "Playing") end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.Name:lower() < b.Name:lower() end)
    local counts = {}
    for _, item in ipairs(out) do
        counts[item.Name] = (counts[item.Name] or 0) + 1
        if counts[item.Name] > 1 then item.Name = item.Name .. " " .. counts[item.Name] end
    end
    return out
end

local function getAnimator(model)
    if typeof(model) ~= "Instance" then return nil end
    local controller = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
    if not controller then
        controller = Instance.new("AnimationController")
        controller.Name = "PreviewAnimationController"
        controller.Parent = model
    end
    local animator = controller:FindFirstChildOfClass("Animator")
    if not animator then animator = Instance.new("Animator"); animator.Parent = controller end
    return animator
end

local function createTrack(animation, model)
    local id = typeof(animation) == "Instance" and animation:IsA("Animation") and animation.AnimationId or tostring(animation or "")
    if id:match("^%d+$") then id = "rbxassetid://" .. id end
    if id == "" then return nil, "ANIMATION_ID_MISSING" end
    local animator = getAnimator(model)
    if not animator then return nil, "PREVIEW_MODEL_UNAVAILABLE" end
    local object
    if typeof(animation) == "Instance" and animation:IsA("Animation") then
        object = animation:Clone()
    else
        object = Instance.new("Animation")
        object.AnimationId = id
    end
    local ok, track = pcall(function() return animator:LoadAnimation(object) end)
    if not ok or not track then object:Destroy(); return nil, "ANIMATION_LOAD_FAILED" end
    return track, object
end

-- Real keyframes. Returns nil when the client cannot read the sequence.
local function authoredLanes(animationId)
    local id = tostring(animationId or "")
    if id:match("^%d+$") then id = "rbxassetid://" .. id end
    local ok, seq = pcall(function() return KeyframeProvider:GetKeyframeSequenceAsync(id) end)
    if not ok or typeof(seq) ~= "Instance" or not seq:IsA("KeyframeSequence") then return nil end
    local lanes, order, length = {}, {}, 0
    for _, kf in ipairs(seq:GetKeyframes()) do
        length = math.max(length, kf.Time)
        local function walk(pose)
            if pose.Weight > 0 then
                local lane = lanes[pose.Name]
                if not lane then lane = {}; lanes[pose.Name] = lane; order[#order + 1] = pose.Name end
                if lane[#lane] ~= kf.Time then lane[#lane + 1] = kf.Time end
            end
            for _, sub in ipairs(pose:GetSubPoses()) do walk(sub) end
        end
        for _, pose in ipairs(kf:GetPoses()) do walk(pose) end
    end
    local loop = seq.Loop
    seq:Destroy()
    if #order == 0 then return nil end
    return { lanes = lanes, order = order, length = length, static = {}, source = "Authored keyframes", loop = loop }
end

-- Sampled keyframes: scrub the loaded track, read Motor6D.Transform, mark where the motion changes.
local function sampledLanes(rig, length, setTime, cancelled, progress)
    local joints = {}
    for _, d in ipairs(rig:GetDescendants()) do
        if d:IsA("Motor6D") and d.Part1 then joints[#joints + 1] = d end
    end
    local n = math.clamp(math.floor(length / 0.05), 4, 240)
    local samples = {}
    for j = 1, #joints do samples[j] = {} end
    for i = 0, n do
        if cancelled() then return nil end
        setTime(math.min(length, i * length / n))
        RunService.Heartbeat:Wait()
        RunService.Heartbeat:Wait()
        for j, m in ipairs(joints) do samples[j][i + 1] = m.Transform end
        progress(i / n)
    end
    local lanes, order, static = {}, {}, {}
    for j, m in ipairs(joints) do
        local s = samples[j]
        local mag, total = {}, 0
        for i = 2, #s do
            local rel = s[i - 1]:ToObjectSpace(s[i])
            local _, ang = rel:ToAxisAngle()
            mag[i] = rel.Position.Magnitude + math.abs(ang)
            total = total + mag[i]
        end
        local name = m.Part1.Name
        local times = {}
        if total > 0.01 then
            times[1] = 0
            local lastKey = 1
            for i = 2, #s - 1 do
                if math.abs((mag[i + 1] or 0) - mag[i]) > 0.004 and i - lastKey >= 2 then
                    times[#times + 1] = (i - 1) * length / n
                    lastKey = i
                end
            end
            times[#times + 1] = length
        else
            times = { 0, length }
            static[name] = true
        end
        if #times > 60 then
            local thin = {}
            for i = 1, #times, math.ceil(#times / 60) do thin[#thin + 1] = times[i] end
            times = thin
        end
        lanes[name] = times
        order[#order + 1] = name
    end
    if #order == 0 then return nil end
    return { lanes = lanes, order = order, length = length, static = static, source = "Sampled from playback (approximate keyframes)" }
end

local function hashColor(name)
    local h = 0
    for i = 1, #name do h = (h * 31 + name:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.5, 1)
end

function Plugin.Init(context)
    assert(context and context.Preview, "Animation requires Preview context")
    local preview, ui = context.Preview, context.UI or {}
    local alive, page, activeModel = true, nil, nil
    local oldPlay, oldCreate = preview.PlayAnimation, preview.CreateTrack

    preview.CreateTrack = function(_, animation, model)
        return createTrack(animation, model or activeModel)
    end
    preview.PlayAnimation = function(_, animation, model, fade)
        local track, object = preview:CreateTrack(animation, model)
        if not track then return nil, object end
        local ok, err = pcall(function() track:Play(tonumber(fade) or 0.1) end)
        if not ok then track:Destroy(); object:Destroy(); return nil, tostring(err) end
        return track, object
    end

    local function build(parent, asset, pv)
        if not alive or typeof(asset.Model) ~= "Instance" then return end
        local T, U2, V2 = ui.Theme(), ui.U2, ui.V2
        local make, text, icon, corner, stroke = ui.Create, ui.Text, ui.Icon, ui.Corner, ui.Stroke

        local vpObj = ui.Viewport(parent, asset, { Rig = true, Ground = true, Hint = false })
        local rig = vpObj.Model
        if not rig then
            vpObj:Destroy()
            text("TextLabel", { Text = "This asset has no model to animate.", TextColor3 = T.dim, TextSize = 12, Size = U2(1, 0, 0, 30) }, parent)
            return
        end
        getAnimator(rig)
        activeModel = rig
        local list = discover({ Model = rig })

        local function panel(pos, size)
            local f = make("Frame", { BackgroundColor3 = T.panel, BorderSizePixel = 0, Position = pos, Size = size, ClipsDescendants = true }, parent)
            corner(f, 12); stroke(f, T.border, 1, 0.3)
            return f
        end
        local transport = panel(U2(0, 0, 0.44, 6), U2(1, 0, 0, 84))
        local tracksP = panel(U2(0, 0, 0.44, 96), U2(1, 0, 0.56, -96))
        vpObj.Frame.Size = U2(1, 0, 0.44, 0)

        ---------------- state ----------------
        local track, object, length, index, rate = nil, nil, 0, 1, 1
        local playing, loop, disposed, loadId = false, false, false, 0
        local data, hideStatic, busy = nil, true, false
        local update, drawLanes, drawRuler

        ---------------- transport ----------------
        local selector = text("TextButton", {
            BackgroundTransparency = 0, BackgroundColor3 = T.input, Text = list[1] and "Select animation" or "No animations found  ·  enter an ID",
            Font = ui.Fonts.Medium, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, Position = U2(0, 8, 0, 8), Size = U2(1, -84, 0, 30),
        }, transport)
        corner(selector, 8)
        make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 26) }, selector)
        local arrow = icon(selector, "chevron-down", 14, T.dim); arrow.AnchorPoint, arrow.Position = V2(1, 0.5), U2(1, 20, 0.5, 0)
        local speed = text("TextButton", {
            BackgroundTransparency = 0, BackgroundColor3 = T.input, Text = "1x", Font = Enum.Font.Code, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = V2(1, 0), Position = U2(1, -8, 0, 8), Size = U2(0, 62, 0, 30),
        }, transport)
        corner(speed, 8)
        local function tbtn(x, name, fn)
            local b, ic = ui.IconButton(transport, name, 34, fn)
            b.Position = U2(0, x, 0, 44)
            return b, ic
        end
        local back = tbtn(8, "rewind", function() end)
        local play, playIcon = tbtn(46, "play", function() end)
        local pauseIcon = icon(play, "pause", 17, T.txt); pauseIcon.AnchorPoint, pauseIcon.Position, pauseIcon.Visible = V2(0.5, 0.5), U2(0.5, 0, 0.5, 0), false
        local stop = tbtn(84, "square", function() end)
        local forward = tbtn(122, "fast-forward", function() end)
        local loopBtn, loopIcon = tbtn(160, "repeat", function() end)
        playIcon.AnchorPoint, playIcon.Position = V2(0.5, 0.5), U2(0.5, 0, 0.5, 0)
        local timeLabel = text("TextLabel", {
            Text = "0.00s / 0.00s", Font = Enum.Font.Code, TextSize = 12, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Right,
            AnchorPoint = V2(1, 0), Position = U2(1, -10, 0, 44), Size = U2(1, -210, 0, 34), TextTruncate = Enum.TextTruncate.AtEnd,
        }, transport)

        local menu = make("ScrollingFrame", {
            BackgroundColor3 = T.panel, BorderSizePixel = 0, Position = U2(0, 8, 0.44, 40), Size = U2(1, -92, 0, 190), Visible = false, ZIndex = 30,
            CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
        }, parent)
        corner(menu, 10); stroke(menu, T.accent, 1, 0.3)
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, menu)
        make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, menu)

        ---------------- tracks panel ----------------
        local title = text("TextLabel", { Text = "Tracks", Font = ui.Fonts.Bold, TextSize = 13, Position = U2(0, 12, 0, 6), Size = U2(0, 120, 0, 20) }, tracksP)
        local status = text("TextLabel", {
            Text = "Pick an animation to see its tracks", TextSize = 11, TextColor3 = T.dim, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = U2(0, 70, 0, 6), Size = U2(1, -190, 0, 20),
        }, tracksP)
        local staticBtn = text("TextButton", {
            BackgroundTransparency = 0, BackgroundColor3 = T.input, Text = "Static: hidden", Font = ui.Fonts.Medium, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = V2(1, 0), Position = U2(1, -8, 0, 5), Size = U2(0, 104, 0, 22),
        }, tracksP)
        corner(staticBtn, 6)
        local ruler = text("TextButton", { BackgroundColor3 = T.card, BackgroundTransparency = 0, Position = U2(0, 100, 0, 32), Size = U2(1, -108, 0, 20), ClipsDescendants = true }, tracksP)
        corner(ruler, 4)
        local lanesScroll = make("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0, Position = U2(0, 0, 0, 56), Size = U2(1, 0, 1, -60),
            CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.dim,
        }, tracksP)
        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, lanesScroll)
        local overlay = make("Frame", { BackgroundTransparency = 1, Position = U2(0, 100, 0, 32), Size = U2(1, -108, 1, -36), ClipsDescendants = true }, tracksP)
        local playhead = make("Frame", { BackgroundColor3 = T.accent, BorderSizePixel = 0, Size = U2(0, 2, 1, 0), ZIndex = 5 }, overlay)

        ---------------- playback ----------------
        update = function()
            local pos = 0
            if track then pcall(function() pos = track.TimePosition end) end
            local alpha = length > 0 and math.clamp(pos / length, 0, 1) or 0
            playhead.Position = U2(alpha, -1, 0, 0)
            timeLabel.Text = string.format("%.2fs / %.2fs", pos, length)
            playIcon.Visible, pauseIcon.Visible = not playing, playing
        end
        local function stopTrack()
            if track then pcall(function() track:Stop(0.08); track:Destroy() end); track = nil end
            if object then object:Destroy(); object = nil end
            length, playing = 0, false
            update()
        end
        local function seek(pos)
            if not track or length <= 0 or busy then return end
            pos = math.clamp(pos, 0, length)
            if not track.IsPlaying then pcall(function() track:Play(0); track:AdjustSpeed(0) end) end
            pcall(function() track.TimePosition = pos end)
            update()
        end
        local function paintLoop()
            local col = loop and T.accent or T.txt
            if loopIcon:IsA("TextLabel") then loopIcon.TextColor3 = col else loopIcon.ImageColor3 = col end
        end

        drawRuler = function()
            for _, ch in ipairs(ruler:GetChildren()) do
                if not ch:IsA("UICorner") then ch:Destroy() end
            end
            if length <= 0 then return end
            local k = ui.Scale and ui.Scale() or 1
            local px = ruler.AbsoluteSize.X / k
            local step = 5
            for _, cand in ipairs({ 0.1, 0.25, 0.5, 1, 2, 5, 10 }) do
                if px / length * cand >= 48 then step = cand break end
            end
            local t = 0
            while t <= length + 1e-6 do
                local a = t / length
                make("Frame", { BackgroundColor3 = T.dim, BorderSizePixel = 0, Position = U2(a, 0, 1, -6), Size = U2(0, 1, 0, 6) }, ruler)
                text("TextLabel", {
                    Text = string.format(step < 1 and "%.2fs" or "%gs", t), TextSize = 10, TextColor3 = T.dim,
                    Position = U2(a, 3, 0, 0), Size = U2(0, 44, 0, 12),
                }, ruler)
                t = t + step
            end
        end

        drawLanes = function()
            for _, ch in ipairs(lanesScroll:GetChildren()) do
                if not ch:IsA("UIListLayout") then ch:Destroy() end
            end
            drawRuler()
            if not data then title.Text = "Tracks" return end
            local names, hiddenCount = {}, 0
            for _, n in ipairs(data.order) do
                if hideStatic and data.static[n] then hiddenCount = hiddenCount + 1 else names[#names + 1] = n end
            end
            title.Text = "Tracks  " .. #names
            staticBtn.Text = hideStatic and ("Static: hidden " .. hiddenCount) or "Static: shown"
            local len = math.max(data.length, length, 0.001)
            for i, name in ipairs(names) do
                local row = make("Frame", { BackgroundColor3 = T.card, BackgroundTransparency = i % 2 == 0 and 0.5 or 1, BorderSizePixel = 0, Size = U2(1, 0, 0, 26), LayoutOrder = i }, lanesScroll)
                local col = hashColor(name)
                text("TextLabel", { Text = name, TextSize = 11, TextColor3 = data.static[name] and T.dim or T.txt, TextTruncate = Enum.TextTruncate.AtEnd, Position = U2(0, 10, 0, 0), Size = U2(0, 88, 1, 0) }, row)
                local lane = make("Frame", { BackgroundTransparency = 1, Position = U2(0, 100, 0, 0), Size = U2(1, -108, 1, 0) }, row)
                make("Frame", { BackgroundColor3 = T.border, BorderSizePixel = 0, Position = U2(0, 0, 0.5, 0), Size = U2(1, 0, 0, 1) }, lane)
                for _, t in ipairs(data.lanes[name]) do
                    local d = text("TextButton", {
                        BackgroundTransparency = data.static[name] and 0.6 or 0, BackgroundColor3 = col, Text = "", Rotation = 45,
                        AnchorPoint = V2(0.5, 0.5), Position = U2(math.clamp(t / len, 0, 1), 0, 0.5, 0), Size = U2(0, 9, 0, 9),
                    }, lane)
                    corner(d, 2)
                    d.Activated:Connect(function() seek(t) end)
                end
            end
        end

        local function loadAnimation(i, custom)
            if disposed then return end
            loadId = loadId + 1
            local mine = loadId
            local entry = custom or list[math.clamp(i, 1, math.max(#list, 1))]
            if not entry then return end
            index = i
            stopTrack()
            data, busy = nil, true
            drawLanes()
            selector.Text = entry.Name
            status.Text = "Loading…"
            local newTrack, newObject = createTrack(entry.Object or entry.AnimationId, rig)
            if not newTrack then busy = false; status.Text = "Could not load this animation"; return end
            track, object = newTrack, newObject
            pcall(function() track.Looped = loop; track:Play(0); track:AdjustSpeed(0) end)
            task.spawn(function()
                local t0 = os.clock()
                while not disposed and loadId == mine and os.clock() - t0 < 8 do
                    local n = 0
                    pcall(function() n = newTrack.Length end)
                    if n > 0 then length = n break end
                    task.wait(0.08)
                end
                if disposed or loadId ~= mine then return end
                if length <= 0 then busy = false; status.Text = "Length unavailable"; update(); return end
                pcall(function() newTrack.TimePosition = 0 end)
                update()
                status.Text = "Reading keyframes…"
                local result = authoredLanes(entry.AnimationId)
                if disposed or loadId ~= mine then return end
                if not result then
                    status.Text = "Sampling tracks… 0%"
                    result = sampledLanes(rig, length, function(t) pcall(function() newTrack.TimePosition = t end) end,
                        function() return disposed or loadId ~= mine end,
                        function(a) status.Text = string.format("Sampling tracks… %d%%", math.floor(a * 100)) end)
                end
                if disposed or loadId ~= mine then return end
                busy = false
                pcall(function() newTrack.TimePosition = 0 end)
                if result then
                    data = result
                    status.Text = result.source
                    if result.loop then loop = true; paintLoop(); pcall(function() newTrack.Looped = true end) end
                else
                    status.Text = "No joints to read tracks from"
                end
                drawLanes()
                update()
            end)
            update()
        end

        ---------------- selector popup ----------------
        local function fillMenu()
            for _, ch in ipairs(menu:GetChildren()) do
                if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
            end
            local idBoxF = make("Frame", { BackgroundColor3 = T.input, BorderSizePixel = 0, Size = U2(1, 0, 0, 30), LayoutOrder = 0, ZIndex = 31 }, menu)
            corner(idBoxF, 8)
            local idBox = text("TextBox", { PlaceholderText = "Load by animation ID…", PlaceholderColor3 = T.dim, TextSize = 12, ClearTextOnFocus = false, Position = U2(0, 10, 0, 0), Size = U2(1, -20, 1, 0), ZIndex = 32 }, idBoxF)
            idBox.FocusLost:Connect(function(enter)
                local id = idBox.Text:match("%d+")
                if enter and id then
                    menu.Visible = false
                    local entry = { Name = "ID " .. id, AnimationId = "rbxassetid://" .. id }
                    list[#list + 1] = entry
                    loadAnimation(#list, entry)
                end
            end)
            for i, entry in ipairs(list) do
                local b = text("TextButton", { Text = entry.Name, Font = ui.Fonts.Medium, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, Size = U2(1, 0, 0, 30), LayoutOrder = i, ZIndex = 31 }, menu)
                make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, b)
                b.Activated:Connect(function() menu.Visible = false; loadAnimation(i) end)
            end
        end
        fillMenu()
        selector.Activated:Connect(function() menu.Visible = not menu.Visible end)

        ---------------- wiring ----------------
        play.Activated:Connect(function()
            if busy then return end
            if not track then
                if #list > 0 then loadAnimation(index) end
                return
            end
            if playing then
                pcall(function() track.TimePosition = track.TimePosition; track:AdjustSpeed(0) end)
                playing = false
            else
                local ok = pcall(function()
                    if length > 0 and track.TimePosition >= length - 0.03 then track.TimePosition = 0 end
                    if track.IsPlaying then track:AdjustSpeed(rate) else track:Play(0.08); track:AdjustSpeed(rate) end
                end)
                playing = ok
            end
            update()
        end)
        stop.Activated:Connect(function()
            if track and not busy then pcall(function() track:Stop(0.08); track.TimePosition = 0 end); playing = false; update() end
        end)
        back.Activated:Connect(function() if track then seek(track.TimePosition - 1) end end)
        forward.Activated:Connect(function() if track then seek(track.TimePosition + 1) end end)
        loopBtn.Activated:Connect(function()
            loop = not loop
            paintLoop()
            if track then pcall(function() track.Looped = loop end) end
        end)
        paintLoop()
        local rates = { 0.25, 0.5, 1, 1.5, 2 }
        speed.Activated:Connect(function()
            local nextIndex = 1
            for i, v in ipairs(rates) do if v == rate then nextIndex = i % #rates + 1 break end end
            rate = rates[nextIndex]
            speed.Text = string.format("%gx", rate)
            if playing and track then pcall(function() track:AdjustSpeed(rate) end) end
        end)
        staticBtn.Activated:Connect(function() hideStatic = not hideStatic; drawLanes() end)
        local function scrubAt(input)
            if length <= 0 then return end
            local p, z = ruler.AbsolutePosition, ruler.AbsoluteSize
            seek(math.clamp((input.Position.X - p.X) / math.max(z.X, 1), 0, 1) * length)
        end
        ruler.InputBegan:Connect(function(input)
            if ui.IsPointer(input) then scrubAt(input); ui.DragLocked(ruler, scrubAt) end
        end)
        local connection = ui.RunService.RenderStepped:Connect(function()
            if disposed or not pv._root or not pv._root.Visible or not pv._drawerOpen then return end
            if track then
                if playing and not track.IsPlaying then playing = false end
                update()
            end
        end)
        local sizeCon = ruler:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() drawRuler() end)

        update()
        if #list > 0 then loadAnimation(1) end
        return function()
            disposed = true
            connection:Disconnect(); sizeCon:Disconnect()
            stopTrack()
            if activeModel == rig then activeModel = nil end
            vpObj:Destroy()
        end
    end

    page = preview:Page({
        Name = "Animator", Icon = "clapperboard",
        Visible = function(asset) return asset ~= nil and typeof(asset.Model) == "Instance" end,
        Build = build,
    })
    return { Destroy = function()
        if not alive then return end
        alive = false
        if page then preview:RemovePage(page); page = nil end
        activeModel = nil
        preview.PlayAnimation, preview.CreateTrack = oldPlay, oldCreate
    end }
end

return { Manifest = { Id = "animation", Name = "Animation", Version = "1.0.0", ApiVersion = 1 }, Init = Plugin.Init }
