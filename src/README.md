# JustXLibrary source layout

The files in this directory are ordered source fragments of the original library, not standalone Lua modules. They deliberately share the original top-level lexical scope, so local functions and upvalues continue to work exactly as before.

Do not execute, require, or reorder individual fragments. The root `build.js` concatenates them byte-for-byte in manifest order to produce the distributable `JustLib.lua`.

Build:

```sh
node build.js
```

Verify the checked-in release matches the fragments:

```sh
node build.js --check
```

The first modularization pass preserves the original source text and behavior. Extracting independently initialized modules is a later refactor and must explicitly define dependency interfaces before any code is moved across lexical scopes.
