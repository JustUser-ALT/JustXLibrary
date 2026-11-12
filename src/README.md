# JustXLibrary source layout

The files in this directory are ordered source fragments used to build the single-file release. They are not loaded independently at runtime. The root `build.js` concatenates them in manifest order to produce `JustLib.lua`.

Most legacy fragments still share the original top-level Lua scope so existing local-function and upvalue relationships remain intact.

## Isolated modules

`modules/config.lua` defines the Config module factory. It receives its dependencies explicitly and keeps its internal state inside the factory closure. `10-config.lua` initializes that module and exposes only the small compatibility API needed by the rest of the existing library.

This is the first true module extraction. Future modules should follow the same pattern: explicit dependencies, a narrow returned API, and no runtime `HttpGet` or external file loading.

Do not execute, require, or reorder individual source fragments.

## Build

```sh
node build.js
```

## Verify the release

```sh
node build.js --check
```

The build check compares the checked-in `JustLib.lua` byte-for-byte with the concatenated source fragments.

`modules/guide.lua` defines the guided-requirements flow, target-state checks, pulsing highlights, navigation handoff, and group rules. Its factory receives the UI and task/tween helpers explicitly; `GUIDE` and `groupRules` are exposed to the existing control and window fragments.

`modules/backgrounds.lua` defines the UI background registry, attachment/rendering logic, and sprite-sheet animation loop. It receives the tracked task runner and UI primitives explicitly, and exposes the registry as `BG` for the existing UI fragments.

`modules/icons.lua` defines the icon pack, override, rendering, and refresh subsystem. Its factory receives the library instance and UI primitives explicitly, and exposes the icon constructor through a narrow API.

`modules/workspace.lua` defines the shared workspace and Multi-Hub state module. It owns hub registration, active-hub switching, per-hub GUI naming/registration, and the persisted Multi-Hub Tabs setting. Its factory receives filesystem and shared-state dependencies explicitly.
