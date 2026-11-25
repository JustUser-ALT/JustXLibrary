# JustXLibrary Addons

Each addon lives in its own standalone `.lua` file in this directory.

## Rules

- Keep addon implementation code here, not inside `JustLib.lua`.
- One addon = one file (for example, `Console.lua`).
- Each addon must return a package table with `Info` metadata and its lifecycle functions, such as `Init`.
- The main library may contain only the addon's catalogue metadata and the relative filename used to download it.
- Catalogue download URLs must point to `Addons/<AddonFile>.lua`.
- Do not bundle addon source files into the main library or regenerate the main library from outdated source fragments.

## Current addons

- `Console.lua` — compact Lua console addon.
