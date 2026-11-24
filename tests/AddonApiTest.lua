return {
    Info = {
        Name = "Addon API Test",
        Author = "Neos",
        Version = "1.0.0",
        Description = "Checks the table-based Addon API and control callbacks."
    },

    Init = function(Addon)
        Addon:Label("Basic controls")

        Addon:Toggle({
            Name = "Test Toggle",
            Default = false,
            Callback = function(value)
                print("[Addon API Test] Toggle:", value)
            end
        })

        Addon:Button({
            Name = "Test Button",
            Callback = function()
                print("[Addon API Test] Button pressed")
                Addon:Notify("Button callback works", "Success")
            end
        })

        Addon:Slider({
            Name = "Test Slider",
            Min = 1,
            Max = 100,
            Step = 1,
            Default = 50,
            Callback = function(value)
                print("[Addon API Test] Slider:", value)
            end
        })

        Addon:Dropdown({
            Name = "Test Dropdown",
            Values = {"First", "Second", "Third"},
            Default = "First",
            Callback = function(value)
                print("[Addon API Test] Dropdown:", value)
            end
        })

        Addon:Input({
            Name = "Test Input",
            Placeholder = "Type something...",
            Callback = function(value)
                print("[Addon API Test] Input:", value)
            end
        })

        Addon:Divider("Storage and lifecycle")

        Addon:Button({
            Name = "Test Save / Load",
            Callback = function()
                Addon:Save("TestValue", "Storage works")
                local value = Addon:Load("TestValue", "No saved value")
                print("[Addon API Test] Saved value:", value)
                Addon:Notify(tostring(value), "Info")
            end
        })

        Addon:OnUnload(function()
            print("[Addon API Test] OnUnload called")
        end)

        Addon:Notify("Addon initialized", "Success")
    end
}
