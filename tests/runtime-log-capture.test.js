import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, "..");
const pluginSource = readFileSync(
  join(projectRoot, "addons", "ai_godot_mcp", "websocket_server.gd"),
  "utf8",
);

test("plugin runtime diagnostics use Godot file logging settings", () => {
  assert.match(pluginSource, /debug\/file_logging\/enable_file_logging/);
  assert.match(pluginSource, /debug\/file_logging\/log_path/);
  assert.match(pluginSource, /user:\/\/logs\/godot\.log/);
});

test("plugin runtime diagnostics expose log_capture metadata", () => {
  assert.match(pluginSource, /"_?log_capture"/);
  assert.match(pluginSource, /func _poll_runtime_log\(\)/);
  assert.match(pluginSource, /func _get_runtime_log_capture_status\(\)/);
});
