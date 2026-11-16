-- Animation plugin: discovery and playback controls for the Preview viewport.
local Plugin = {}

local function discover(asset)
    local model = asset and asset.Model
    if typeof(model) ~= "Instance" then return {} end
    local out, seen = {}, {}
    local function add(animation, state)
        if not animation or not animation:IsA("Animation") then return end
        local id = tostring(animation.AnimationId or "")
        if id == "" then return end
        local key = id
        if seen[key] then
            if state == "Playing" then seen[key].State = state end
            return
        end
        local name = tostring(animation.Name or "")
        local generic = name == "" or name:lower():match("^animation%d*$") ~= nil
        if generic then
            local p = animation.Parent
            while p and p ~= model do
                local n = tostring(p.Name or "")
                local lower = n:lower()
                if n ~= "" and lower ~= "animations" and lower ~= "animate"
                    and lower ~= "animator" and lower ~= "humanoid"
                    and lower ~= "animationcontroller" and not lower:match("^animation%d*$") then
                    name = n
                    break
                end
                p = p.Parent
            end
        else
            name = name:gsub("[Aa]nim$", "")
        end
        if name == "" or name:lower():match("^animation%d*$") then
            name = "Animation • " .. id:sub(-6)
        end
        seen[key] = { Name = name, AnimationId = id, Object = animation, State = state or "Available" }
        out[#out + 1] = seen[key]
    end
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("Animation") then
            add(item)
        elseif item:IsA("Animator") then
            local ok, tracks = pcall(function() return item:GetPlayingAnimationTracks() end)
            if ok then for _, track in ipairs(tracks) do
                local animation
                pcall(function() animation = track.Animation end)
                if animation then add(animation, "Playing") end
            end end
        end
    end
    table.sort(out, function(a,b) return a.Name:lower() < b.Name:lower() end)
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

function Plugin.Init(context)
    assert(context and context.Preview, "Animation requires Preview context")
    local preview, ui = context.Preview, context.UI or {}
    local alive, extension = true, nil
    local oldPlay, oldCreate = preview.PlayAnimation, preview.CreateTrack

    preview.CreateTrack = function(self, animation, model)
        model = model or (preview._selected and preview._selected.Model)
        return createTrack(animation, model)
    end
    preview.PlayAnimation = function(self, animation, model, fade)
        local track, object = preview:CreateTrack(animation, model)
        if not track then return nil, object end
        local ok, err = pcall(function() track:Play(tonumber(fade) or 0.1) end)
        if not ok then track:Destroy(); object:Destroy(); return nil, tostring(err) end
        return track, object
    end

    local function build(parent, asset, pv, ctx)
        local list = discover(asset)
        if not alive then return end
        -- The Preview viewport anchors every part by default. Keep the rig root fixed,
        -- but allow Motor6D joints to move so the animation is visible.
        local rig = ctx.Model
        if typeof(rig) == "Instance" and (rig:FindFirstChildOfClass("Humanoid") or rig:FindFirstChildOfClass("AnimationController")) then
            local root = rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart
            if not root then
                for _, part in ipairs(rig:GetDescendants()) do
                    if part:IsA("BasePart") then root = part; break end
                end
            end
            for _, part in ipairs(rig:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = part == root
                    part.CanCollide = false
                end
            end
        end
        local C, U = ui.Colors or {}, ui.U2 or UDim2.new
        local make, text, icon = ui.Create, ui.Text, ui.Icon
        if not make or not text or not icon then return end
        ctx.SetBottomInset(108)
        local panel = make("Frame", {
            Name="AnimationTimelinePlayer", BackgroundColor3=C.panel or Color3.fromRGB(32,34,43),
            BorderSizePixel=0, Position=U(0,0,1,-100), Size=U(1,0,0,92),
        }, parent)
        ui.Corner(panel,10); ui.Stroke(panel,C.border or Color3.fromRGB(65,68,82),1)
        local selector = text("TextButton", {
            Name="AnimationSelector", Text=list[1] and list[1].Name or "No animations found", Font=Enum.Font.GothamBold,
            TextSize=11, TextColor3=C.txt or Color3.new(1,1,1),
            BackgroundColor3=C.btnBg or Color3.fromRGB(45,48,60), Position=U(0,10,0,5),
            Size=U(0.58,-18,0,23), TextTruncate=Enum.TextTruncate.AtEnd,
        },panel)
        ui.Corner(selector,7); ui.Stroke(selector,C.border or Color3.fromRGB(65,68,82),1); ui.Pad(selector,8,22,0,0)
        local arrow=icon(selector,"chevron-down",12,C.dim); arrow.AnchorPoint=Vector2.new(1,0.5); arrow.Position=U(1,-4,0.5,0)
        local time=text("TextLabel",{Text="0.00s / 0.00s",Font=Enum.Font.Code,TextSize=9,TextColor3=C.dim,
            TextXAlignment=Enum.TextXAlignment.Right,Position=U(0.58,0,0,5),Size=U(0.42,-10,0,22)},panel)
        local bar=make("Frame",{BackgroundColor3=C.slTrack or Color3.fromRGB(65,68,82),BorderSizePixel=0,
            Position=U(0,12,0,35),Size=U(1,-24,0,4)},panel); ui.Corner(bar,3)
        local fill=make("Frame",{BackgroundColor3=ui.Accent or Color3.fromRGB(95,150,255),BorderSizePixel=0,Size=U(0,0,1,0)},bar); ui.Corner(fill,3)
        local knob=make("Frame",{BackgroundColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(.5,.5),
            Position=U(0,0,.5,0),Size=UDim2.fromOffset(10,10)},bar); ui.Corner(knob,5)
        local scrub=text("TextButton",{Text="",Position=U(0,0,.5,-13),Size=U(1,0,0,26),ZIndex=4},bar)
        local controls=make("Frame",{BackgroundTransparency=1,Position=U(0,10,0,47),Size=U(1,-20,0,34)},panel)
        local function button(name,glyph,x,w)
            local b=text("TextButton",{Name=name,Text="",BackgroundColor3=C.btnBg or Color3.fromRGB(45,48,60),
                Position=U(0,x,0,2),Size=UDim2.fromOffset(w,28)},controls)
            ui.Corner(b,7); ui.Stroke(b,C.border or Color3.fromRGB(65,68,82),1)
            if glyph then local i=icon(b,glyph,13,C.txt); i.AnchorPoint=Vector2.new(.5,.5); i.Position=U(.5,0,.5,0) end
            return b
        end
        local play,stop,back,forward,speed=button("PlayPause",nil,0,30),button("Stop","square",36,28),
            button("SeekBack","rewind",70,32),button("SeekForward","fast-forward",108,32),button("PlaybackSpeed",nil,146,40)
        speed.Font=Enum.Font.Code; speed.Text="1.0x"; speed.TextXAlignment=Enum.TextXAlignment.Center; speed.TextYAlignment=Enum.TextYAlignment.Center
        local playIcon=icon(play,"play",13,C.txt); playIcon.AnchorPoint=Vector2.new(.5,.5); playIcon.Position=U(.5,0,.5,0)
        local pauseIcon=icon(play,"pause",13,C.txt); pauseIcon.AnchorPoint=Vector2.new(.5,.5); pauseIcon.Position=U(.5,0,.5,0); pauseIcon.Visible=false
        local menu=make("ScrollingFrame",{Name="AnimationList",BackgroundColor3=C.panel or Color3.fromRGB(32,34,43),
            BorderSizePixel=0,AnchorPoint=Vector2.new(0,1),Position=U(0,8,1,-104),Size=U(.58,-18,0,162),
            Visible=false,ZIndex=50,Active=true,ScrollingEnabled=true,ScrollingDirection=Enum.ScrollingDirection.Y,
            AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=U(0,0,0,0),ScrollBarThickness=4,
            ScrollBarImageColor3=C.dim or Color3.fromRGB(130,135,150)},parent)
        ui.Corner(menu,8); ui.Stroke(menu,C.border or Color3.fromRGB(65,68,82),1)
        local menuLayout=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)},menu)
        menuLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            menu.CanvasSize=U(0,0,0,menuLayout.AbsoluteContentSize.Y+8)
        end)

        local track, object, length, index, rate = nil,nil,0,1,1
        local playing, loading, disposed = false,false,false
        local durationLabels = {}
        local function update()
            local pos=0; if track then pcall(function() pos=track.TimePosition end) end
            local alpha=length>0 and math.clamp(pos/length,0,1) or 0
            fill.Size=U(alpha,0,1,0); knob.Position=U(alpha,0,.5,0)
            time.Text=string.format("%.2fs / %.2fs",pos,length)
            playIcon.Visible=not playing; pauseIcon.Visible=playing
        end
        local function stopTrack()
            if track then pcall(function() track:Stop(.08); track:Destroy() end); track=nil end
            if object then object:Destroy(); object=nil end
            length=0; playing=false; loading=false
            if ctx.Viewer then ctx.Viewer.animationActive=false end
            update()
        end
        local function seek(pos)
            if not track or length<=0 then return end
            pos=math.clamp(pos,0,length)
            if not track.IsPlaying then pcall(function() track:Play(0); track:AdjustSpeed(0) end) end
            pcall(function() track.TimePosition=pos end); update()
        end
        local function load(i)
            if disposed then return end
            index=math.clamp(i,1,#list); local entry=list[index]
            stopTrack(); selector.Text=entry.Name
            if entry.AnimationId=="" then time.Text="Animation ID unavailable"; return end
            if typeof(ctx.Model)~="Instance" then time.Text="Preview model unavailable"; return end
            local newTrack,newObject=createTrack(entry.Object or entry.AnimationId,ctx.Model)
            if not newTrack then time.Text="Could not load animation"; return end
            track,object=newTrack,newObject; loading=true
            if ctx.Viewer then ctx.Viewer.animationActive=true end
            pcall(function() track.Looped=false; track:Play(0); track:AdjustSpeed(0) end)
            task.spawn(function()
                local started=os.clock()
                while not disposed and track==newTrack and os.clock()-started<8 do
                    local n=0; pcall(function() n=newTrack.Length end)
                    if n>0 then length=n; loading=false; pcall(function() newTrack.TimePosition=0 end); update(); return end
                    task.wait(.08)
                end
                if not disposed and track==newTrack then loading=false; time.Text="Length unavailable" end
            end)
            update()
        end
        for i,entry in ipairs(list) do
            local row=make("Frame",{Name="AnimationRow",BackgroundTransparency=1,Size=U(1,-8,0,27),
                LayoutOrder=i,ZIndex=51},menu)
            local item=text("TextButton",{Text=entry.Name,Font=Enum.Font.GothamMedium,TextSize=11,
                TextColor3=C.txt or Color3.new(1,1,1),BackgroundTransparency=1,Size=U(1,-58,1,0),
                Position=U(0,4,0,0),ZIndex=52,TextXAlignment=Enum.TextXAlignment.Left},row)
            ui.Pad(item,8,6,0,0)
            local duration=text("TextLabel",{Text="--:--",Font=Enum.Font.Code,TextSize=9,
                TextColor3=C.dim or Color3.fromRGB(140,145,160),BackgroundTransparency=1,
                AnchorPoint=Vector2.new(1,0),Position=U(1,-8,0,0),Size=U(0,48,1,0),
                TextXAlignment=Enum.TextXAlignment.Right,ZIndex=52},row)
            durationLabels[i]=duration
            item.Activated:Connect(function() menu.Visible=false; load(i) end)
        end
        selector.Active = #list > 0
        selector.Activated:Connect(function()
            if #list > 0 then menu.Visible=not menu.Visible end
        end)
        play.Activated:Connect(function()
            if not track then
                if #list > 0 then load(index) end
                return
            end
            if playing then
                pcall(function()
                    track.TimePosition = track.TimePosition
                    track:AdjustSpeed(0)
                end)
                playing=false
            else
                local ok=pcall(function()
                    if length>0 and track.TimePosition>=length-.03 then
                        track.TimePosition=0
                    end
                    if track.IsPlaying then
                        -- A paused track is still active; restore its speed without calling Play again.
                        track:AdjustSpeed(rate)
                    else
                        track:Play(.08)
                        track:AdjustSpeed(rate)
                    end
                end)
                playing=ok
            end
            update()
        end)
        stop.Activated:Connect(function() if track then pcall(function() track:Stop(.08); track.TimePosition=0 end); playing=false; update() end end)
        back.Activated:Connect(function() if track then seek(track.TimePosition-1) end end)
        forward.Activated:Connect(function() if track then seek(track.TimePosition+1) end end)
        local rates={.25,.5,1,1.5,2}
        speed.Activated:Connect(function()
            local nextIndex=1; for i,v in ipairs(rates) do if v==rate then nextIndex=i%#rates+1; break end end
            rate=rates[nextIndex]; speed.Text=string.format("%.2gx",rate)
            if playing and track then pcall(function() track:AdjustSpeed(rate) end) end
        end)
        local function scrubAt(input)
            if length<=0 then return end
            local p,z=bar.AbsolutePosition,bar.AbsoluteSize
            seek(math.clamp((input.Position.X-p.X)/math.max(z.X,1),0,1)*length)
        end
        scrub.InputBegan:Connect(function(input)
            if ui.IsPointer and ui.IsPointer(input) then scrubAt(input); if ui.DragLocked then ui.DragLocked(scrub,scrubAt) end end
        end)
        local connection=ui.RunService and ui.RunService.RenderStepped:Connect(function()
            if disposed or not pv._root or not pv._root.Visible or not pv._drawerOpen then return end
            if track then
                if playing and not track.IsPlaying then playing=false; if ctx.Viewer then ctx.Viewer.animationActive=false end end
                update()
            end
        end)
        if #list > 0 then
            selector.Text = "Select animation"
            -- Read durations in the background. Temporary tracks are immediately destroyed
            -- after their Length becomes available, so the list does not retain extra tracks.
            task.spawn(function()
                for i,entry in ipairs(list) do
                    if disposed then break end
                    local metaTrack,metaObject=createTrack(entry.Object or entry.AnimationId,ctx.Model)
                    if metaTrack then
                        local started=os.clock()
                        local durationValue=0
                        repeat
                            pcall(function() durationValue=metaTrack.Length end)
                            if durationValue>0 or disposed then break end
                            task.wait(.1)
                        until os.clock()-started>=2.5
                        pcall(function() metaTrack:Stop(0); metaTrack:Destroy() end)
                        if metaObject then metaObject:Destroy() end
                        if durationValue>0 then
                            entry.Duration=durationValue
                            local mins=math.floor(durationValue/60)
                            local secs=durationValue-mins*60
                            if durationLabels[i] and durationLabels[i].Parent then
                                durationLabels[i].Text=string.format("%d:%04.1f",mins,secs)
                            end
                        end
                    end
                    task.wait(.08)
                end
            end)
        else
            selector.Text = "No animations found"
            time.Text = "No usable Animation objects found in this model"
        end
        return function()
            disposed=true; if connection then connection:Disconnect() end
            stopTrack(); if menu and menu.Parent then menu:Destroy() end
        end
    end

    extension = preview:RegisterPreviewExtension("animation", build)
    return { Destroy=function()
        if not alive then return end; alive=false
        if extension then extension:Destroy(); extension=nil end
        preview.PlayAnimation=oldPlay; preview.CreateTrack=oldCreate
    end }
end

return { Manifest={Id="animation",Name="Animation",Version="0.4.2",ApiVersion=1}, Init=Plugin.Init }
