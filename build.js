// Build JustXLibrary's distributable single-file release.
// The source fragments intentionally share one Lua lexical scope.
// Do not load them independently or reorder this manifest.
const fs = require("node:fs");
const path = require("node:path");
const root = __dirname;
const parts = [
  "src/modules/workspace.lua",
  "src/modules/icons.lua",
  "src/modules/backgrounds.lua",
  "src/modules/guide.lua",
  "src/modules/themes.lua",
  "src/modules/lifecycle.lua",
  "src/modules/ui-primitives.lua",
  "src/00-core.lua",
  "src/modules/config.lua",
  "src/10-config.lua",
  "src/20-runtime-ui.lua",
  "src/30-subplaces.lua",
  "src/40-services.lua",
  "src/50-controls.lua",
  "src/60-ui-controls.lua",
  "src/70-preview.lua",
  "src/80-window.lua",
];
const outputPath = path.join(root, "JustLib.lua");
const output = parts.map(file => fs.readFileSync(path.join(root, file), "utf8")).join("");
if (process.argv.includes("--check")) {
  if (!fs.existsSync(outputPath)) {
    console.error("JustLib.lua is missing. Run: node build.js");
    process.exit(1);
  }
  const current = fs.readFileSync(outputPath, "utf8");
  if (current !== output) {
    console.error("Build check failed: JustLib.lua differs from src/ fragments.");
    process.exit(1);
  }
  console.log("Build check passed: JustLib.lua matches all source fragments.");
} else {
  fs.writeFileSync(outputPath, output, "utf8");
  console.log("Built JustLib.lua from " + parts.length + " source fragments.");
}
