import test from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, "..");

test("scaffold keeps plugin entry files in place", () => {
  assert.equal(
    existsSync(join(projectRoot, "addons", "ai_godot_mcp", "plugin.cfg")),
    true,
  );
  assert.equal(
    existsSync(join(projectRoot, "addons", "ai_godot_mcp", "plugin.gd")),
    true,
  );
});
