-- Official Preview plugin registry.
-- Keep metadata here; implementation belongs to each plugin directory.
return {
    Version = 2,
    Plugins = {
        { Id = "animation", Name = "Animation", Description = "Animator page with transport controls and a keyframe track timeline.",
          Icon = "clapperboard", Version = "1.0.0", Author = "JustXLibrary", Entry = "Plugins/Animation/init.lua",
          Manifest = "Plugins/Animation/manifest.lua", Category = "Animation" },
        { Id = "explorer", Name = "Explorer", Description = "Object tree with live viewport selection, hide / isolate, search and a property editor.",
          Icon = "folder-tree", Version = "1.0.0", Author = "JustXLibrary", Entry = "Plugins/Explorer/init.lua",
          Manifest = "Plugins/Explorer/manifest.lua", Category = "Development" },
        { Id = "rig", Name = "Rig", Description = "Plain gray rig, your own avatar, or any player in the server as a previewable rig.",
          Icon = "user-round", Version = "0.1.0", Author = "JustXLibrary", Entry = "Plugins/Rig/init.lua",
          Manifest = "Plugins/Rig/manifest.lua", Category = "Rigs", Badge = "New" },
        { Id = "studio", Name = "Studio", Description = "Lighting presets, light direction, field of view and ground disc for every preview viewport.",
          Icon = "lightbulb", Version = "0.1.0", Author = "JustXLibrary", Entry = "Plugins/Studio/init.lua",
          Manifest = "Plugins/Studio/manifest.lua", Category = "Viewport", Badge = "New" },
        { Id = "materials", Name = "Materials", Description = "Paint studio: recolor, re-material and adjust transparency on a preview copy of the model.",
          Icon = "paintbrush", Version = "0.1.0", Author = "JustXLibrary", Entry = "Plugins/Materials/init.lua",
          Manifest = "Plugins/Materials/manifest.lua", Category = "Viewport", Badge = "New" },
        { Id = "stats", Name = "Stats", Description = "Read-only model breakdown: part counts, size, materials and dominant colors.",
          Icon = "chart-bar", Version = "0.1.0", Author = "JustXLibrary", Entry = "Plugins/Stats/init.lua",
          Manifest = "Plugins/Stats/manifest.lua", Category = "Development", Badge = "New" },
    },
}
