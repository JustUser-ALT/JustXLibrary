--[[
    JustXLibrary Addon: FreeCam
    Universal free camera for keyboard, mouse and touch devices.
]]
return {
    Info = {
        Name = "FreeCam",
        Author = "JustXLibrary",
        Version = "1.0.0",
        Description = "Universal free camera with touch controls and configurable movement.",
        Library = "4.4",
    },
    Init = function(Addon)
        local env = (getgenv and getgenv()) or _G
        if env.UniversalFreecam and env.UniversalFreecam.Destroy then
            pcall(env.UniversalFreecam.Destroy)
        end

        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UIS = game:GetService("UserInputService")
        local CAS = game:GetService("ContextActionService")
        local StarterGui = game:GetService("StarterGui")
        local Workspace = game:GetService("Workspace")

        local Config = {
            ToggleKeys = { Enum.KeyCode.LeftShift, Enum.KeyCode.P },
            TogglePosition = UDim2.new(0, 12, 0.18, 0),
            ButtonSize = 44,
            BaseSpeed = 64,
            SlowMultiplier = 0.25,
            PinchNotchesPerPixel = 0.02,
            JumpButtonGap = 12,
            RequireUnprocessedTouch = true,
            StickZoneWidthFraction = 0.5,
            StickZoneTopFraction = 0.3,
            FreezeCharacterOnTouch = true,
            FovMin = 1,
            FovMax = 120,
            RenderPriorityOffset = 1,
            HideGameGui = true,
            KeepVisibleGuiNames = {
                Antireset = true, TopBar = true, TouchGui = true, ContextActionGui = true,
            },
            HiddenCoreGuis = { "Backpack", "Chat", "Health", "PlayerList" },
        }

        local PI = math.pi
        local PAN_GAIN_PER_FRAME = (PI / 64) / 60
        local destroyed = false
        local connections = {}

        local function bind(signal, callback)
            local connection = signal:Connect(callback)
            connections[#connections + 1] = connection
            return connection
        end

        local function safeDisconnectAll(list)
            for _, connection in ipairs(list) do
                pcall(function() connection:Disconnect() end)
            end
            table.clear(list)
        end

        local Spring = {}
        Spring.__index = Spring
        function Spring.new(freq, pos)
            return setmetatable({ f = freq, p = pos, v = pos * 0 }, Spring)
        end
        function Spring:Update(dt, goal)
            local th = self.f * 2 * PI
            local offset = goal - self.p
            local decay = math.exp(-th * dt)
            local p1 = goal + (self.v * dt - offset * (th * dt + 1)) * decay
            local v1 = (th * dt * (offset * th - self.v) + self.v) * decay
            self.p, self.v = p1, v1
            return p1
        end
        function Spring:Reset(pos)
            self.p = pos
            self.v = pos * 0
        end

        local function zoomScale(fov)
            return math.sqrt(0.7002075382097097 / math.tan(math.rad(fov / 2)))
        end
        local function wrapYaw(y)
            return y % (2 * PI)
        end
        local function b2n(value)
            return value and 1 or 0
        end

        local settings = {
            SmoothCamera = Addon.Load("SmoothCamera", true) ~= false,
            CameraSpeed = math.clamp(tonumber(Addon.Load("CameraSpeed", 64)) or 64, 16, 128),
        }
        local function saveSetting(key, value)
            settings[key] = value
            Addon.Save(key, value)
        end

        local player = Players.LocalPlayer
        if not player then
            Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
            player = Players.LocalPlayer
        end
        local camera = Workspace.CurrentCamera
        bind(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
            if Workspace.CurrentCamera then camera = Workspace.CurrentCamera end
        end)

        local controls
        do
            local ok, result = pcall(function()
                local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
                return require(module):GetControls()
            end)
            if ok then
                controls = result
            else
                warn("[UniversalFreecam] PlayerModule controls unavailable, mobile joystick movement disabled: " .. tostring(result))
            end
        end

        local active = false
        local touchOnly = false
        local camPos = Vector3.new()
        local camRot = Vector2.new()
        local camFov = 70
        local panSpeed = Vector2.new(0.75, 1) * 8
        local posSpring = Spring.new(1.5, Vector3.new())
        local panSpring = Spring.new(1, Vector2.new())
        local fovSpring = Spring.new(4, 0)
        local keys = { W = 0, A = 0, S = 0, D = 0, E = 0, Q = 0 }
        local held = { up = false, down = false }
        local panDelta = Vector2.new()
        local wheelDelta = 0
        local freeTouches = {}
        local stickTouches = {}
        local touchOrder = {}
        local lastPinchDist = nil
        local saved = nil
        local disabledGuis = {}
        local savedCore = {}
        local freeze = nil
        local jumpButton, jumpOrigPos, jumpOrigVisible, downButton, upButton
        local buttonConns = {}
        local touchConns = {}
        local gui, toggleButton

        local function freezeCharacter()
            local char = player.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            freeze = {
                hum = hum, hrp = hrp, anchored = false,
                prevAnchored = hrp and hrp.Anchored or false,
            }
            if hum then
                freeze.walk = hum.WalkSpeed
                freeze.usePower = hum.UseJumpPower
                if freeze.usePower then
                    freeze.jump = hum.JumpPower
                    hum.JumpPower = 0
                else
                    freeze.jump = hum.JumpHeight
                    hum.JumpHeight = 0
                end
                hum.WalkSpeed = 0
            end
        end

        local function updateFreeze()
            local f = freeze
            if not f or f.anchored then return end
            local hrp = f.hrp
            if not hrp or not hrp.Parent then return end
            if f.hum and f.hum.Parent and f.hum.FloorMaterial == Enum.Material.Air then return end
            f.prevAnchored = hrp.Anchored
            hrp.Anchored = true
            f.anchored = true
        end

        local function unfreezeCharacter()
            local f = freeze
            freeze = nil
            if not f then return end
            if f.hrp and f.hrp.Parent and f.anchored then
                f.hrp.Anchored = f.prevAnchored
            end
            if f.hum and f.hum.Parent then
                f.hum.WalkSpeed = f.walk
                if f.usePower then
                    f.hum.JumpPower = f.jump
                else
                    f.hum.JumpHeight = f.jump
                end
            end
        end

        local function onKey(_, state, input)
            keys[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
            return Enum.ContextActionResult.Sink
        end
        local function onMousePan(_, _, input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                local delta = input.Delta
                panDelta += Vector2.new(-delta.Y, -delta.X)
                return Enum.ContextActionResult.Sink
            end
            return Enum.ContextActionResult.Pass
        end
        local function onWheel(_, _, input)
            wheelDelta += -input.Position.Z
            return Enum.ContextActionResult.Sink
        end

        local function isInStickZone(pos)
            if not camera then return false end
            local viewport = camera.ViewportSize
            return pos.X < viewport.X * Config.StickZoneWidthFraction
                and pos.Y > viewport.Y * Config.StickZoneTopFraction
        end
        local function removeTouch(input)
            freeTouches[input] = nil
            local index = table.find(touchOrder, input)
            if index then table.remove(touchOrder, index) end
            lastPinchDist = nil
        end
        local function onTouchStarted(input, processed)
            if processed and Config.RequireUnprocessedTouch then return end
            local pos = Vector2.new(input.Position.X, input.Position.Y)
            if isInStickZone(pos) then
                stickTouches[input] = true
                return
            end
            freeTouches[input] = { pos = pos }
            touchOrder[#touchOrder + 1] = input
            lastPinchDist = nil
        end
        local function onTouchMoved(input)
            local touch = freeTouches[input]
            if not touch then return end
            local pos = Vector2.new(input.Position.X, input.Position.Y)
            local delta = pos - touch.pos
            touch.pos = pos
            if #touchOrder >= 2 then
                local first, second = freeTouches[touchOrder[1]], freeTouches[touchOrder[2]]
                if first and second then
                    local distance = (first.pos - second.pos).Magnitude
                    if lastPinchDist then
                        wheelDelta += (lastPinchDist - distance) * Config.PinchNotchesPerPixel
                    end
                    lastPinchDist = distance
                end
            else
                panDelta += Vector2.new(-delta.Y, -delta.X)
            end
        end
        local function onTouchEnded(input)
            stickTouches[input] = nil
            if freeTouches[input] then removeTouch(input) end
        end
        local function pruneTouches()
            for input in pairs(stickTouches) do
                local state = input.UserInputState
                if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
                    stickTouches[input] = nil
                end
            end
            for index = #touchOrder, 1, -1 do
                local input = touchOrder[index]
                local state = input.UserInputState
                if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
                    removeTouch(input)
                end
            end
        end
        local function clearTouches()
            table.clear(freeTouches)
            table.clear(stickTouches)
            table.clear(touchOrder)
            lastPinchDist = nil
        end

        local function readVelocityInput()
            local velocity = Vector3.new(
                keys.D - keys.A,
                keys.E - keys.Q + b2n(held.up) - b2n(held.down),
                keys.S - keys.W
            )
            if touchOnly and controls then
                local move = controls:GetMoveVector()
                velocity += Vector3.new(move.X, 0, move.Z)
            end
            local slow = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
            return velocity * (slow and Config.SlowMultiplier or 1)
        end
        local function readPanInput(dt)
            local delta = panDelta
            panDelta = Vector2.new()
            if dt > 0 then return delta / dt * PAN_GAIN_PER_FRAME end
            return Vector2.new()
        end
        local function readFovInput(dt)
            local wheel = wheelDelta
            wheelDelta = 0
            return dt > 0 and (wheel / dt * (1 / 60)) or 0
        end

        local function step(dt)
            if not camera then return end
            pruneTouches()
            updateFreeze()

            local velocityGoal = readVelocityInput()
            local panGoal = readPanInput(dt)
            local fovGoal = readFovInput(dt)
            local velocity, pan, fovDelta
            if settings.SmoothCamera then
                velocity = posSpring:Update(dt, velocityGoal)
                pan = panSpring:Update(dt, panGoal)
                fovDelta = fovSpring:Update(dt, fovGoal)
            else
                velocity, pan, fovDelta = velocityGoal, panGoal, fovGoal
                posSpring:Reset(velocityGoal)
                panSpring:Reset(panGoal)
                fovSpring:Reset(fovGoal)
            end

            local zoom = zoomScale(camFov)
            camFov = math.clamp(camFov + fovDelta * 300 * (dt / zoom), Config.FovMin, Config.FovMax)
            local rotation = camRot + pan * panSpeed * (dt / zoom)
            camRot = Vector2.new(math.clamp(rotation.X, -PI / 2, PI / 2), wrapYaw(rotation.Y))
            local moved = CFrame.new(camPos)
                * CFrame.fromOrientation(camRot.X, camRot.Y, 0)
                * CFrame.new(Vector3.new(velocity.X, 0, velocity.Z) * settings.CameraSpeed * dt)
            camPos = moved.Position + Vector3.new(0, velocity.Y * settings.CameraSpeed * dt, 0)
            local cf = CFrame.new(camPos) * CFrame.fromOrientation(camRot.X, camRot.Y, 0)
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = cf
            camera.Focus = cf
            camera.FieldOfView = camFov
        end

        local function hideGameGui()
            if not Config.HideGameGui then return end
            for _, name in ipairs(Config.HiddenCoreGuis) do
                local coreType = Enum.CoreGuiType[name]
                if coreType then
                    local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreType)
                    if ok then
                        savedCore[name] = enabled
                        pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, false)
                    end
                end
            end
            local playerGui = player:FindFirstChildOfClass("PlayerGui")
            if playerGui then
                for _, screen in ipairs(playerGui:GetChildren()) do
                    if screen:IsA("ScreenGui") and screen.Enabled and screen ~= gui
                        and not Config.KeepVisibleGuiNames[screen.Name] then
                        screen.Enabled = false
                        disabledGuis[#disabledGuis + 1] = { gui = screen, wasEnabled = true }
                    end
                end
            end
        end
        local function restoreGameGui()
            for name, enabled in pairs(savedCore) do
                local coreType = Enum.CoreGuiType[name]
                if coreType then pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, enabled) end
            end
            table.clear(savedCore)
            for _, entry in ipairs(disabledGuis) do
                if entry.gui and entry.gui.Parent then entry.gui.Enabled = entry.wasEnabled end
            end
            table.clear(disabledGuis)
        end

        local function setButtonState()
            if toggleButton then
                toggleButton.BackgroundColor3 = active
                    and Color3.fromRGB(125, 82, 205)
                    or Color3.fromRGB(34, 34, 42)
                local glyph = toggleButton:FindFirstChild("CameraIcon")
                if glyph then glyph.ImageColor3 = active and Color3.fromRGB(255,255,255) or Color3.fromRGB(220,220,232) end
            end
        end

        local function setJumpButtonPressed(button, pressed)
            if not button or not button.Parent then return end
            local baseColor = Color3.fromRGB(255, 255, 255)
            if button:IsA("ImageButton") or button:IsA("ImageLabel") then
                button.ImageColor3 = pressed and Color3.fromRGB(205, 205, 215) or baseColor
            end
        end
        local function holdKey(button, key)
            local function finish()
                held[key] = false
                setJumpButtonPressed(button, false)
            end
            buttonConns[#buttonConns + 1] = button.InputBegan:Connect(function(input)
                local inputType = input.UserInputType
                if inputType ~= Enum.UserInputType.Touch and inputType ~= Enum.UserInputType.MouseButton1 then return end
                held[key] = true
                setJumpButtonPressed(button, true)
                local connection
                connection = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
                        finish()
                        connection:Disconnect()
                    end
                end)
                buttonConns[#buttonConns + 1] = connection
            end)
            buttonConns[#buttonConns + 1] = button.InputEnded:Connect(finish)
        end
        local function cloneFreecamTouchButton(original, name)
            local clone = original:Clone()
            for _, descendant in ipairs(clone:GetDescendants()) do
                if descendant:IsA("LuaSourceContainer") then descendant:Destroy() end
            end
            clone.Name = name
            clone.AutoButtonColor = false
            clone.Visible = true
            clone.Parent = original.Parent
            return clone
        end
        local function setupJumpButtons()
            local playerGui = player:FindFirstChildOfClass("PlayerGui")
            local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
            local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
            local original = frame and frame:FindFirstChild("JumpButton")
            if not original then
                warn("[UniversalFreecam] TouchGui.TouchControlFrame.JumpButton not found, vertical buttons unavailable")
                return
            end
            jumpButton, jumpOrigPos, jumpOrigVisible = original, original.Position, original.Visible
            upButton = cloneFreecamTouchButton(original, "UFCUpButton")
            downButton = cloneFreecamTouchButton(original, "UFCDownButton")
            upButton.Position = jumpOrigPos - UDim2.fromOffset(0, original.AbsoluteSize.Y + Config.JumpButtonGap)
            downButton.Position = jumpOrigPos
            downButton.Rotation = 180
            original.Visible = false
            holdKey(upButton, "up")
            holdKey(downButton, "down")
        end
        local function teardownJumpButtons()
            safeDisconnectAll(buttonConns)
            held.up, held.down = false, false
            if upButton then upButton:Destroy(); upButton = nil end
            if downButton then downButton:Destroy(); downButton = nil end
            if jumpButton and jumpButton.Parent then
                jumpButton.Position = jumpOrigPos
                jumpButton.Visible = jumpOrigVisible
                if jumpButton:IsA("ImageButton") or jumpButton:IsA("ImageLabel") then
                    jumpButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
                end
            end
            jumpButton = nil
        end

        local function bindInput()
            CAS:BindActionAtPriority("UFCKeys", onKey, false, Enum.ContextActionPriority.High.Value,
                Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.E, Enum.KeyCode.Q)
            CAS:BindActionAtPriority("UFCMousePan", onMousePan, false, -2, Enum.UserInputType.MouseMovement)
            CAS:BindActionAtPriority("UFCWheel", onWheel, false, Enum.ContextActionPriority.High.Value,
                Enum.UserInputType.MouseWheel)
            touchConns[#touchConns + 1] = UIS.TouchStarted:Connect(onTouchStarted)
            touchConns[#touchConns + 1] = UIS.TouchMoved:Connect(onTouchMoved)
            touchConns[#touchConns + 1] = UIS.TouchEnded:Connect(onTouchEnded)
        end
        local function unbindInput()
            CAS:UnbindAction("UFCKeys")
            CAS:UnbindAction("UFCMousePan")
            CAS:UnbindAction("UFCWheel")
            safeDisconnectAll(touchConns)
        end

        local function enable()
            if destroyed or active or not camera then return end
            active = true
            touchOnly = not UIS.KeyboardEnabled and not UIS.GamepadEnabled
            panSpeed = Vector2.new(0.75, 1) * (touchOnly and 12 or 8)
            saved = {
                cameraType = camera.CameraType,
                cframe = camera.CFrame,
                focus = camera.Focus,
                fov = camera.FieldOfView,
            }
            if touchOnly and Config.FreezeCharacterOnTouch then freezeCharacter() end
            local x, y = camera.CFrame:ToEulerAnglesYXZ()
            camRot = Vector2.new(x, wrapYaw(y))
            camPos = camera.CFrame.Position
            camFov = camera.FieldOfView
            posSpring:Reset(Vector3.new())
            panSpring:Reset(Vector2.new())
            fovSpring:Reset(0)
            panDelta, wheelDelta = Vector2.new(), 0
            clearTouches()
            hideGameGui()
            if UIS.TouchEnabled then setupJumpButtons() end
            bindInput()
            RunService:BindToRenderStep("UniversalFreecam", Enum.RenderPriority.Camera.Value + Config.RenderPriorityOffset, step)
            setButtonState()
        end
        local function disable()
            if not active then return end
            active = false
            pcall(RunService.UnbindFromRenderStep, RunService, "UniversalFreecam")
            unbindInput()
            teardownJumpButtons()
            clearTouches()
            for key in pairs(keys) do keys[key] = 0 end
            for key in pairs(held) do held[key] = false end
            panDelta, wheelDelta = Vector2.new(), 0
            unfreezeCharacter()
            restoreGameGui()
            if saved and camera then
                camera.FieldOfView = saved.fov
                camera.CameraType = saved.cameraType
                camera.CFrame = saved.cframe
                camera.Focus = saved.focus
            end
            saved = nil
            setButtonState()
        end
        local function toggle()
            if active then disable() else enable() end
        end

        local api
        local function destroy()
            if destroyed then return end
            disable()
            destroyed = true
            safeDisconnectAll(connections)
            if gui then gui:Destroy(); gui = nil end
            if env.UniversalFreecam == api then env.UniversalFreecam = nil end
        end

        -- Addon settings are native JustXLibrary controls and persist through Addon.Save/Load.
        Addon.Toggle({
            Name = "Smooth Camera",
            Tooltip = "Enable or disable camera movement and rotation smoothing.",
            Default = settings.SmoothCamera,
            Callback = function(value)
                saveSetting("SmoothCamera", value == true)
                posSpring:Reset(Vector3.new())
                panSpring:Reset(Vector2.new())
                fovSpring:Reset(0)
            end,
        })
        Addon.Slider({
            Name = "Camera Speed",
            Tooltip = "Movement speed in studs per second.",
            Min = 16,
            Max = 128,
            Step = 4,
            Default = settings.CameraSpeed,
            Callback = function(value)
                saveSetting("CameraSpeed", math.clamp(tonumber(value) or 64, 16, 128))
            end,
        })

        gui = Instance.new("ScreenGui")
        gui.Name = "UniversalFreecamGui"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 2147483647
        gui.IgnoreGuiInset = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

        toggleButton = Instance.new("TextButton")
        toggleButton.Name = "FreeCamToggle"
        toggleButton.Size = UDim2.fromOffset(Config.ButtonSize, Config.ButtonSize)
        toggleButton.Position = Config.TogglePosition
        toggleButton.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
        toggleButton.BackgroundTransparency = 0.08
        toggleButton.BorderSizePixel = 0
        toggleButton.AutoButtonColor = false
        toggleButton.Text = ""
        toggleButton.ZIndex = 20
        toggleButton.Parent = gui
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(1, 0)
        buttonCorner.Parent = toggleButton
        local buttonStroke = Instance.new("UIStroke")
        buttonStroke.Color = Color3.fromRGB(115, 93, 160)
        buttonStroke.Transparency = 0.2
        buttonStroke.Thickness = 1
        buttonStroke.Parent = toggleButton

        local cameraIcon = Instance.new("ImageLabel")
        cameraIcon.Name = "CameraIcon"
        cameraIcon.BackgroundTransparency = 1
        cameraIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        cameraIcon.Position = UDim2.fromScale(0.5, 0.5)
        cameraIcon.Size = UDim2.fromOffset(23, 23)
        cameraIcon.ImageColor3 = Color3.fromRGB(220, 220, 232)
        cameraIcon.ScaleType = Enum.ScaleType.Fit
        cameraIcon.ZIndex = 22
        cameraIcon.Parent = toggleButton
        cameraIcon.Visible = false

        -- Guaranteed non-emoji camera glyph while the Lucide image pack is loading
        -- or when the executor cannot render remote image assets.
        local cameraFallback = Instance.new("Frame")
        cameraFallback.Name = "CameraFallback"
        cameraFallback.BackgroundTransparency = 1
        cameraFallback.Size = UDim2.fromOffset(25, 22)
        cameraFallback.AnchorPoint = Vector2.new(0.5, 0.5)
        cameraFallback.Position = UDim2.fromScale(0.5, 0.5)
        cameraFallback.ZIndex = 21
        cameraFallback.Parent = toggleButton
        local cameraBody = Instance.new("Frame")
        cameraBody.Name = "CameraBody"
        cameraBody.Size = UDim2.fromOffset(22, 15)
        cameraBody.Position = UDim2.fromOffset(1, 6)
        cameraBody.BackgroundTransparency = 1
        cameraBody.BorderSizePixel = 0
        cameraBody.ZIndex = 21
        cameraBody.Parent = cameraFallback
        local cameraBodyCorner = Instance.new("UICorner")
        cameraBodyCorner.CornerRadius = UDim.new(0, 3)
        cameraBodyCorner.Parent = cameraBody
        local cameraBodyStroke = Instance.new("UIStroke")
        cameraBodyStroke.Color = Color3.fromRGB(220, 220, 232)
        cameraBodyStroke.Thickness = 1.8
        cameraBodyStroke.Parent = cameraBody
        local cameraLens = Instance.new("Frame")
        cameraLens.Name = "CameraLens"
        cameraLens.Size = UDim2.fromOffset(7, 7)
        cameraLens.Position = UDim2.fromOffset(8, 10)
        cameraLens.BackgroundTransparency = 1
        cameraLens.BorderSizePixel = 0
        cameraLens.ZIndex = 22
        cameraLens.Parent = cameraFallback
        local cameraLensCorner = Instance.new("UICorner")
        cameraLensCorner.CornerRadius = UDim.new(1, 0)
        cameraLensCorner.Parent = cameraLens
        local cameraLensStroke = Instance.new("UIStroke")
        cameraLensStroke.Color = Color3.fromRGB(220, 220, 232)
        cameraLensStroke.Thickness = 1.5
        cameraLensStroke.Parent = cameraLens
        local cameraTop = Instance.new("Frame")
        cameraTop.Name = "CameraTop"
        cameraTop.Size = UDim2.fromOffset(8, 4)
        cameraTop.Position = UDim2.fromOffset(5, 2)
        cameraTop.BackgroundColor3 = Color3.fromRGB(220, 220, 232)
        cameraTop.BorderSizePixel = 0
        cameraTop.ZIndex = 21
        cameraTop.Parent = cameraFallback
        local cameraTopCorner = Instance.new("UICorner")
        cameraTopCorner.CornerRadius = UDim.new(0, 2)
        cameraTopCorner.Parent = cameraTop

        local function loadCameraIcon()
            local library = Addon.Library
            local bridge = library and library._bridge
            if not bridge or type(bridge.icon) ~= "function" then return false end
            local ok, asset = pcall(bridge.icon, "camera")
            if not ok or type(asset) ~= "table" then return false end
            local image = asset.Url or asset.Image or asset.ImageUrl or asset.Texture
                or asset.Asset or asset.AssetId or asset.ImageId or asset.Id
            if image == nil then return false end
            image = tostring(image)
            if image:match("^%d+$") then image = "rbxassetid://" .. image end
            if not (image:match("^rbxassetid://") or image:match("^rbxasset://") or image:match("^https?://")) then
                return false
            end
            cameraIcon.Image = image
            if typeof(asset.ImageRectOffset) == "Vector2" then cameraIcon.ImageRectOffset = asset.ImageRectOffset end
            if typeof(asset.ImageRectSize) == "Vector2" then cameraIcon.ImageRectSize = asset.ImageRectSize end
            cameraIcon.Visible = true
            return true
        end
        task.spawn(function()
            for _ = 1, 24 do
                if destroyed or not cameraIcon.Parent then break end
                if loadCameraIcon() then break end
                task.wait(0.25)
            end
        end)

        bind(toggleButton.Activated, toggle)
        local parentOk = false
        local ok, ui = pcall(function() return gethui and gethui() end)
        if ok and ui then parentOk = pcall(function() gui.Parent = ui end) end
        if not parentOk then
            parentOk = pcall(function() gui.Parent = game:GetService("CoreGui") end)
        end
        if not parentOk or not gui.Parent then
            gui.Parent = player:WaitForChild("PlayerGui")
        end

        bind(UIS.InputBegan, function(input, processed)
            if processed then return end
            local keyList = Config.ToggleKeys
            if input.KeyCode ~= keyList[#keyList] then return end
            for index = 1, #keyList - 1 do
                if not UIS:IsKeyDown(keyList[index]) then return end
            end
            toggle()
        end)

        api = {
            Enable = enable,
            Disable = disable,
            Toggle = toggle,
            Destroy = destroy,
            SetSpeed = function(value)
                value = tonumber(value)
                if value then saveSetting("CameraSpeed", math.clamp(value, 16, 128)) end
            end,
            SetSmooth = function(value)
                saveSetting("SmoothCamera", value == true)
            end,
        }
        env.UniversalFreecam = api
        Addon.Keep(gui)
        Addon.OnUnload(destroy)
        setButtonState()
    end,
}
