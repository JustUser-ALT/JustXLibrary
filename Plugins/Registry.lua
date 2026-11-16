-- Official Preview plugin registry.
-- Keep metadata here; implementation belongs to each plugin directory.
return {
    Version = 1,
    Plugins = {
        {
            Id = "animation",
            Name = "Animation",
            Description = "Animation playback, tracks and animation asset tools.",
            Icon = "clapperboard",
            Version = "0.4.2",
            Author = "JustXLibrary",
            Entry = "Plugins/Animation/init.lua",
            Manifest = "Plugins/Animation/manifest.lua",
            Category = "Animation",
        },
        {
            Id = "explorer",
            Name = "Explorer",
            Description = "Browse asset hierarchies, inspect instances and properties.",
            Icon = "folder-tree",
            Version = "0.3.0",
            Author = "JustXLibrary",
            Entry = "Plugins/Explorer/init.lua",
            Manifest = "Plugins/Explorer/manifest.lua",
            Category = "Development",
        },
    },
}
