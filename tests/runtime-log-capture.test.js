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
const pluginEntrySource = readFileSync(
  join(projectRoot, "addons", "ai_godot_mcp", "plugin.gd"),
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

test("plugin registers Batch 1 authoring handlers", () => {
  const batchOneMethods = [
    "open_scene",
    "instantiate_scene",
    "connect_signal",
    "disconnect_signal",
    "get_input_map",
    "bind_input_key",
  ];

  for (const method of batchOneMethods) {
    assert.match(pluginSource, new RegExp(`"${method}":`));
  }
});

test("plugin keeps Batch 1 validation and persistence guardrails", () => {
  assert.match(pluginSource, /func _validate_scene_path\(path: String\) -> bool:/);
  assert.match(pluginSource, /func _validate_identifier\(value: String\) -> bool:/);
  assert.match(pluginSource, /connection\.get\("callable"\)/);
  assert.match(pluginSource, /InputMap\.load_from_project_settings\(\)/);
});

test("plugin keeps Batch 2 official API and validation guardrails", () => {
  assert.match(pluginEntrySource, /_ws_server\.editor_plugin = self/);
  assert.match(pluginSource, /editor_plugin\.add_autoload_singleton\(autoload_name, autoload_path\)/);
  assert.match(pluginSource, /editor_plugin\.remove_autoload_singleton\(autoload_name\)/);
  assert.match(pluginSource, /undo_redo\.add_do_method\(node, "reparent", new_parent, keep_global_transform\)/);
  assert.match(pluginSource, /func _validate_node_path\(path: String\) -> bool:/);
  assert.match(pluginSource, /func _validate_node_name\(node_name: String\) -> bool:/);
  assert.doesNotMatch(pluginSource, /autoload_singleton\//);
  assert.doesNotMatch(pluginSource, /node\.global_transform if keep_global_transform/);
});
