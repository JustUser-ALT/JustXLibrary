# JustX Library — Developer Documentation

> API reference for the current JustX Library source. This document describes the public interfaces implemented in `JustLib.lua`; it does not document internal helpers.

## 1. Load the library

```lua
local Source = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local JustLib = loadstring(game:HttpGet(Source))()

local Window = JustLib:Window({
    Title = "My Hub",
    IconProvider = "lucide"
})
```

The loader returns the library table. `Window()` creates a hub and returns its window object. The library version is available as `JustLib.Version`.

## 2. Create a window

```lua
local Window = JustLib:Window({
    Title = "My Hub",
    Config = "MyHub",
    IconProvider = "lucide"
})
```

Implemented window options:

| Option | Purpose |
| --- | --- |
| `Title` | Hub title. |
| `Config` | Configuration identity/name for this hub. |
| `ConfigFolder` | Configuration folder override. |
| `IconProvider` | Icon provider passed to the icon loader. |
| `IconPackURL` | Custom icon-pack source URL. |
| `Background`, `Backgrounds` | Initial background configuration. |
| `DebugPerformance` | Enables window-build performance diagnostics. |
| `AddonsFolder` | Addon folder; defaults to `JustLib/Addons`. |

Icon loading is always enabled. `LoadIcons` is unsupported and ignored.

### Window methods

- `Open()`, `Close()`, `Toggle()`
- `IsOpen()`
- `Destroy()` / `Unload()`
- `Tab(options)`, `HomeTab(options)`, `Settings()`
- `Search(query)`, `GoTo(target)`
- `Notify(config)`
- `SetBackground(kind, config)`, `ClearBackground(kind)`
- `Addons()`, `Remote(options)`
- `SetWorkspaceVisible(boolean)`, `IsWorkspaceVisible()`
- Lifecycle helpers: `Track`, `Connect`, `Spawn`, `Delay`, `Defer`, `OnUnload`, `IsAlive`

## 3. Tabs and layout

Create a tab with:

```lua
local Tab = Window:Tab({
    Name = "Main",
    Icon = "house",
    Type = "Grid"
})
```

Tab options implemented in the source:

- `Name` or `Text`: displayed tab name.
- `Icon`, `Tooltip`
- `Type`: `"Grid"`, `"List"`, or `"Custom"`.
- `Locked`, `LockedTitle`, `LockedMessage`
- `Requires`, `Hidden`, `HiddenUntil`, `OpenStore`

Tab methods:

- `Section({Title, Column, Icon, Tooltip, Collapsed, ...})`
- `MultiSection({Title, Pages, Layout, Columns, ...})`
- `Select()`, `Remove()`, `IsRemoved()`
- `SetLocked(boolean)`, `IsLocked()`, `ToggleLocked()`
- `SetHidden(boolean)`, `IsHidden()`, `ToggleHidden()`

For Grid tabs, sections can be assigned to a column using `Column`. List tabs arrange sections vertically. Custom tabs expose their frame through `Tab.Frame` for custom UI construction.

### MultiSection

```lua
local Pages = Tab:MultiSection({
    Title = "Tools",
    Pages = {"General", "Visual", "Other"},
    Layout = "Auto",
    Columns = 3
})

Pages:Page("General"):Toggle({Name = "Example"})
Pages:Shared():Label({Text = "Shown on every page"})
Pages:SetPage("Visual")
```

Implemented methods: `Page(name)`, `Shared()`, `SetPage(name)`, `GetPage()`. A maximum of nine pages is supported. Layout modes are `Auto`, `Segmented`, `Scroll`, and `Rows`.

## 4. Sections and controls

Create a section:

```lua
local Main = Tab:Section({
    Title = "Player",
    Icon = "user",
    Column = 1,
    Collapsed = false
})
```

Sections support `SetCollapsed(boolean)`, `ToggleCollapsed()`, `IsCollapsed()`, and the lock/visibility methods `SetLocked`, `SetHidden`, `IsLocked`, `IsHidden`, `ToggleLocked`, `ToggleHidden`.

All controls accept a configuration table. Common options include `Name`, `Flag`, `Icon`, `Tooltip`, `Default`, `NoSave`, and `Callback` where applicable. A `Flag` identifies persisted state; use a unique flag for each control.

### Control reference

| Constructor | Main options | Callback / behavior |
| --- | --- | --- |
| `Toggle` | `Name, Flag, Default, Icon, Tooltip, NoSave, Needs, NeedsWhen, Remote` | `Callback(value)`; returns `Get, Set, Click, Watch`. |
| `ToggleGroup` | `Name, Options, Flag, Default, Mode, Masters, MaxActive, ClearOthers` | Grouped mutually managed toggles. |
| `Slider` | `Name, Flag, Min, Max, Default, Step, Increment, Suffix, Icon, IconLeft, IconRight` | `Callback(value)`; returns value accessors. |
| `Button` | `Name, Icon, Tooltip, Callback, Needs, Remote` | `Callback()`. |
| `Input` | `Name, Flag, Placeholder, Default, MultiLine, Icon, Icons, OptionIcons, NoSave` | `Callback(value)` and `OnChange(value)`. |
| `Dropdown` | `Name, Flag, Options, Default, MultiSelect, MaxSelect, Search, Static` | `Callback(value)`; supports option visibility/locking/requirements/tooltips. |
| `TextSlider` | `Name, Flag, Options, Default, Ticks, Icon, IconLeft, IconRight` | Text-based option slider. |
| `ColorPicker` | `Name, Flag, Default, Icon, Tooltip` | `Callback(color)`. |
| `Keybind` | `Name, Flag, Default, Icon, Tooltip, OnPress, Remote` | `Callback(key)`, `OnPress()`; returns `Get, Set, Press, Watch, OnPulse`. |
| `Segmented` | `Name, Flag, Options, Default, Tooltip` | `Callback(value)`; returns `Get, Set`. |
| `Group` | `Name, A, B, Tooltip` | Places two control definitions in a group. |
| `Text` | `Text, Size, Color, Align, Bold, RichText, Icon, Tooltip` | Static formatted text. |
| `Screen` | `Name, Image, Player, Height, ScaleType, ThumbSize, Tooltip` | Image/player preview; returns `SetImage(id)`, `SetPlayer(player)`. |
| `Label` | `Text, Color, Icon, RichText, Tooltip` | Label; returns `Set(text)`. |
| `Divider` | `Label` | Optional labeled separator. |
| `PreviewButton` | `Name, Target, Callback` | Opens the Preview UI for a target. |
| `PreviewToggle` | `Name, Target, Callback` | Preview action toggle. |
| `PreviewDropdown` | `Name, Callback` | Preview selection dropdown. |
| `Custom` | `height, setupFn` | Custom row/container construction. |

### Examples

```lua
Main:Toggle({
    Name = "Walk Speed",
    Flag = "walk_speed_enabled",
    Default = false,
    Callback = function(enabled)
        print("Enabled:", enabled)
    end
})

Main:Slider({
    Name = "Speed",
    Flag = "walk_speed",
    Min = 16,
    Max = 100,
    Step = 1,
    Default = 16,
    Suffix = " studs",
    Callback = function(value)
        print("Speed:", value)
    end
})

Main:Button({
    Name = "Print message",
    Callback = function()
        print("Hello from JustX")
    end
})

Main:Dropdown({
    Name = "Target",
    Flag = "target",
    Options = {"Nearest", "Furthest", "Random"},
    Default = "Nearest",
    Callback = function(value)
        print(value)
    end
})
```

### Control return objects

Where provided, controls expose methods such as `Get()`, `Set(value)`, `Click()`, `Watch(callback)`, and `Press()`. The exact methods vary by control; use the table above and the control-specific description rather than assuming every control has the same return API.

## 5. Notifications

```lua
JustLib:Notify({
    Title = "Saved",
    Desc = "Your settings have been saved.",
    Type = "Success",
    Duration = 4
})
```

Options:

- `Title`: notification heading.
- `Desc`: description text.
- `Type`: `"Info"`, `"Success"`, `"Warn"`, or `"Error"`.
- `Duration`: display duration in seconds.
- `Screen`: optional image, asset ID/URL, or player avatar.

Screen examples:

```lua
-- Asset ID or URL
JustLib:Notify({
    Title = "Custom image",
    Desc = "Image preview",
    Screen = "1234567890"
})

-- Player avatar (Player instance or numeric UserId)
JustLib:Notify({
    Title = "Player",
    Desc = "Avatar preview",
    Screen = {Player = game:GetService("Players").LocalPlayer}
})

-- Image configuration
JustLib:Notify({
    Title = "Image",
    Desc = "Fit the image",
    Screen = {
        Image = "rbxassetid://1234567890",
        ScaleType = Enum.ScaleType.Fit,
        ImageColor3 = Color3.new(1,1,1)
    }
})
```

Notification settings are available under Settings → Notifications: regular, warning and error visibility, default duration, stack behavior, screen corner, and Hide On Click.

## 6. Icons and backgrounds

### Icons

- `LoadIconPack(url, provider)`
- `SetIconType(provider)`
- `SetIcons(table)`

`SetIcons` accepts a map of icon names to asset values or supported asset tables. `IconProvider` and `IconPackURL` can be set when creating the window.

### Backgrounds

```lua
JustLib:SetBackground("Window", {
    Image = "rbxassetid://1234567890",
    ScaleType = Enum.ScaleType.Crop,
    Dim = 0.25
})
JustLib:SetBackground("Section", nil)
```

- `SetBackground(kind, config)`
- `GetBackground(kind)`
- `ClearBackground(kind)`

Background configurations support image presentation and optional sprite-sheet animation fields including `Frames`, `SheetSize`, `FPS`, and `FrameCount`.

## 7. Preview UI

Create the Preview interface with the library method:

```lua
local Preview = JustLib:Preview({
    Title = "My Preview",
    Subtitle = "Asset browser",
    Icon = "box",
    TabName = "Preview",
    Key = Enum.KeyCode.P,
    OnOpen = function() end,
    OnClose = function() end
})
```

Implemented Preview options include `Title`, `Subtitle`, `Icon`, `TabName`, `Key`, `OnOpen`, `OnClose`, and `PluginBase`.

### Preview methods

- `Open(target)`, `Close()`, `Toggle(target)`, `IsOpen()`, `SetTitle(title)`, `OnClosed(callback)`, `CloseDrawer()`, `Destroy()`
- `Tab(options)`, `Page(options)`, `RemovePage(page)`, `GetTab(name)`, `GetTabs()`
- `QuickAction(options)`
- `GetPlugins()`, `GetPlugin(id)`, `InstallPlugin(id)`, `EnablePlugin(id)`, `DisablePlugin(id)`, `UninstallPlugin(id)`, `SetPluginOpen(id, callback)`, `GetPluginUI()`
- `CreateIcon(parent, name, size, color)`, `CreateViewport(parent, asset, options)`, `RegisterPreviewExtension(id, build)`

A tab is created with `Preview:Tab({Name, Icon, ShowAll, Filter})`. Add assets with `Tab:Asset(assetDefinition)` or `Tab:Assets(list)`. Asset definitions support fields such as `Name`, `Type`, `Creator`, `Created`, `Size`, `Version`, `Description`, `Tags`, `Info`, `Model`, `Build`, `Image`, `Callback`, and `Actions` (up to five actions).

Tab methods include `Select()`, `Open()`, `Clear()`, and `Remove()`. Asset handles provide `Select()`, `Action(action)`, `Update(patch)`, and `Remove()`.

Add detail pages with `Preview:Page({Name, Icon, Visible, Build})`. `Build(parent, asset, preview)` can return a cleanup function. Remove pages with `Preview:RemovePage(page)`.

Preview controls can be attached to the Preview itself, a tab, or an asset:
`Button`, `Toggle`, `Dropdown`, `ColorPicker`, `Slider`, `Textbox`, `Label`, and `Divider`. Control handles provide `Get()`, `Set(value, silent)`, and `Remove()`.

The Preview module is loaded from `PreviewUI.lua`. Use `JustLib:GetPreview()` to retrieve the current Preview object. In the main library's Sections, `PreviewButton`, `PreviewToggle`, and `PreviewDropdown` provide links into Preview UI.

## 8. Confirmation and utility methods

- `JustLib:Confirm({Title, Desc, ...})` opens a confirmation dialog and returns the user's decision.
- `JustLib:SetStreamerMode(boolean)`, `GetStreamerMode()`
- `JustLib:Track(resource, cleanup)`
- `JustLib:Connect(signal, callback)`
- `JustLib:Spawn(callback, ...)`, `Delay(seconds, callback, ...)`, `Defer(callback, ...)`
- `JustLib:OnUnload(callback)`
- `JustLib:IsAlive()`, `GetCleanupStats()`
- `JustLib:Unload()` / `Cleanup()`

Use lifecycle helpers for connections, tasks, and resources that should be cleaned up when the hub unloads.

## 9. Addon development

Addons are loaded from the folder configured by `AddonsFolder` (default: `JustLib/Addons`). Supported file extensions are `.lua`, `.txt`, and `.luau`.

A modern addon receives `Addon` and `__JLA` as its varargs:

```lua
local Addon = ...

Addon:Toggle({
    Name = "Enabled",
    Default = false,
    Callback = function(value)
        print("Enabled:", value)
    end
})

Addon:Slider({
    Name = "Power",
    Min = 0,
    Max = 100,
    Step = 1,
    Default = 25,
    Callback = function(value)
        print("Power:", value)
    end
})
```

Addon API:

- Metadata fields: `Name`, `Id`, `Library`, `LibVersion`, `Window`.
- `Toggle(options)`, `Button(options)`, `Slider(options)`, `Dropdown(options)`, `Input(options)`, `Label(options)`, `Divider(options)`.
- `Notify(config)` or `Notify(message, type, title)`.
- `Save(key, value)`, `Load(key, default)`.
- `Keep(resource)`: register a resource for addon cleanup.
- `OnUnload(callback)`: register addon cleanup.
- `TopbarButton({Text, Callback})`.

Modern addon metadata can be declared with an `Info` table containing `Name`, `Author`, `Version`, `Description`, `Image` (or `Thumbnail` / `IconAsset`), and `Library`.

Legacy comment directives are also parsed:

```lua
--@name Example Addon
--@author Developer
--@version 1.0.0
--@description Example addon
--@toggle God Mode
--@tooltip Enables the feature
local function setGodMode(value)
    print(value)
end

--@button Print
local function printMessage()
    print("Hello")
end
```

Supported directives: `name`, `author`, `version`, `lib` / `requires` / `target` / `jl`, `description` / `desc`, `image` / `thumbnail` / `iconasset`, and control directives `toggle`, `button`, `slider`, `dropdown`, `input`, `label`, `divider`. A control directive must be followed by its function (except static label/divider declarations). Modifiers such as `default`, `min`, `max`, `step`, and `tooltip` apply to the pending control.

## 10. Compatibility notes

- The current source version audited for this documentation is **4.4.15**; the release commit updates the library to **5.0.0**.
- `LoadIcons` is not a supported window option; icon loading is always enabled.
- Use `Type = "Warn"` for warning notifications (not `"Warning"`).
- Addons execute with the permissions of the executor. Only install code you trust.
- This reference documents implemented public interfaces; internal module factories and private helper functions are intentionally omitted.
