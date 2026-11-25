--[[
    JustXLibrary built-in addon: Console
    Install this file in the Addons folder and enable Addons in JustXLibrary.
]]

return {
    Info = {
        Name = "Console",
        Author = "JustXLibrary",
        Version = "1.0.0",
        Description = "A compact Lua console in the top bar.",
        Library = "4.4",
    },

    Init = function(Addon)
        local Players = game:GetService("Players")
        local UserInputService = game:GetService("UserInputService")
        local player = Players.LocalPlayer
        local parent = player and player:FindFirstChildOfClass("PlayerGui")
        if not parent then
            error("PlayerGui is unavailable")
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = "JustXConsole"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = parent
        Addon.Keep(gui)

        local panel = Instance.new("Frame")
        panel.Name = "Console"
        panel.Size = UDim2.fromOffset(520, 310)
        panel.Position = UDim2.new(0.5, -260, 0.5, -155)
        panel.BackgroundColor3 = Color3.fromRGB(19, 20, 25)
        panel.BorderSizePixel = 0
        panel.Visible = false
        panel.Parent = gui
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.fromRGB(55, 58, 69)
        outline.Thickness = 1
        outline.Parent = panel

        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 38)
        header.BackgroundColor3 = Color3.fromRGB(27, 29, 36)
        header.BorderSizePixel = 0
        header.Parent = panel
        Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.fromOffset(14, 0)
        title.Size = UDim2.new(1, -60, 1, 0)
        title.Font = Enum.Font.GothamSemibold
        title.Text = " >_   JUSTX CONSOLE"
        title.TextColor3 = Color3.fromRGB(220, 224, 235)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = header

        local close = Instance.new("TextButton")
        close.Size = UDim2.fromOffset(28, 26)
        close.Position = UDim2.new(1, -34, 0, 6)
        close.BackgroundColor3 = Color3.fromRGB(43, 45, 54)
        close.BorderSizePixel = 0
        close.Text = "×"
        close.TextColor3 = Color3.fromRGB(220, 224, 235)
        close.TextSize = 18
        close.Font = Enum.Font.Gotham
        close.Parent = header
        Instance.new("UICorner", close).CornerRadius = UDim.new(0, 7)
        close.MouseButton1Click:Connect(function() panel.Visible = false end)

        local output = Instance.new("ScrollingFrame")
        output.Name = "Output"
        output.Position = UDim2.fromOffset(12, 48)
        output.Size = UDim2.new(1, -24, 1, -100)
        output.BackgroundColor3 = Color3.fromRGB(14, 15, 19)
        output.BorderSizePixel = 0
        output.ScrollBarThickness = 3
        output.ScrollBarImageColor3 = Color3.fromRGB(83, 91, 110)
        output.CanvasSize = UDim2.new()
        output.Parent = panel
        Instance.new("UICorner", output).CornerRadius = UDim.new(0, 8)
        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 8)
        padding.PaddingBottom = UDim.new(0, 8)
        padding.PaddingLeft = UDim.new(0, 9)
        padding.PaddingRight = UDim.new(0, 9)
        padding.Parent = output
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = output

        local function writeLine(message, color)
            local line = Instance.new("TextLabel")
            line.BackgroundTransparency = 1
            line.Size = UDim2.new(1, -4, 0, 17)
            line.AutomaticSize = Enum.AutomaticSize.Y
            line.Font = Enum.Font.Code
            line.Text = tostring(message)
            line.TextColor3 = color or Color3.fromRGB(190, 198, 213)
            line.TextSize = 12
            line.TextWrapped = true
            line.TextXAlignment = Enum.TextXAlignment.Left
            line.Parent = output
            task.defer(function()
                output.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 18)
                output.CanvasPosition = Vector2.new(0, math.max(0, layout.AbsoluteContentSize.Y))
            end)
        end

        local input = Instance.new("TextBox")
        input.Name = "CommandInput"
        input.Position = UDim2.new(0, 12, 1, -42)
        input.Size = UDim2.new(1, -24, 0, 30)
        input.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
        input.BorderSizePixel = 0
        input.ClearTextOnFocus = false
        input.Font = Enum.Font.Code
        input.PlaceholderText = "Enter Lua code and press Enter..."
        input.PlaceholderColor3 = Color3.fromRGB(115, 122, 139)
        input.Text = ""
        input.TextColor3 = Color3.fromRGB(230, 234, 243)
        input.TextSize = 12
        input.TextXAlignment = Enum.TextXAlignment.Left
        input.Parent = panel
        Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)
        local inputPadding = Instance.new("UIPadding")
        inputPadding.PaddingLeft = UDim.new(0, 10)
        inputPadding.PaddingRight = UDim.new(0, 10)
        inputPadding.Parent = input

        local function execute(source)
            source = tostring(source or "")
            if source == "" then return end
            writeLine("» " .. source, Color3.fromRGB(126, 174, 255))
            if source == "clear" then
                for _, child in ipairs(output:GetChildren()) do
                    if child:IsA("TextLabel") then child:Destroy() end
                end
                output.CanvasSize = UDim2.new()
                return
            elseif source == "help" then
                writeLine("Commands: clear, help. You can also execute Lua code.")
                return
            end
            if type(loadstring) ~= "function" then
                writeLine("This executor does not provide loadstring.", Color3.fromRGB(255, 112, 112))
                return
            end
            local chunk, compileError = loadstring(source)
            if not chunk then
                writeLine(compileError, Color3.fromRGB(255, 112, 112))
                return
            end
            local ok, result = pcall(chunk)
            if not ok then
                writeLine(result, Color3.fromRGB(255, 112, 112))
            elseif result ~= nil then
                writeLine(result, Color3.fromRGB(151, 220, 166))
            else
                writeLine("Executed.", Color3.fromRGB(151, 220, 166))
            end
        end

        input.FocusLost:Connect(function(enterPressed)
            if not enterPressed then return end
            local command = input.Text
            input.Text = ""
            execute(command)
        end)

        local dragging, dragStart, startPosition
        header.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1
                and inputObject.UserInputType ~= Enum.UserInputType.Touch then return end
            dragging = true
            dragStart = inputObject.Position
            startPosition = panel.Position
        end)
        UserInputService.InputChanged:Connect(function(inputObject)
            if not dragging then return end
            if inputObject.UserInputType ~= Enum.UserInputType.MouseMovement
                and inputObject.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = inputObject.Position - dragStart
            panel.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end)
        UserInputService.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1
                or inputObject.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)

        local topbarButton = Addon.TopbarButton({
            Text = ">_",
            Callback = function()
                panel.Visible = not panel.Visible
                if panel.Visible then
                    writeLine("JustX Console ready. Type 'help' for commands.", Color3.fromRGB(151, 220, 166))
                end
            end,
        })
        Addon.Keep(topbarButton)
    end,
}
