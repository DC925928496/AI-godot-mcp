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

test("plugin converts JSON scene property values into Godot Variant types", () => {
  assert.match(pluginSource, /func _convert_json_property_value\(value, old_value, property_info: Dictionary\) -> Dictionary:/);
  assert.match(pluginSource, /func _convert_json_to_vector2\(value\) -> Dictionary:/);
  assert.match(pluginSource, /func _convert_json_to_packed_vector2_array\(value\) -> Dictionary:/);
  assert.match(pluginSource, /func _convert_json_to_color\(value\) -> Dictionary:/);
  assert.match(pluginSource, /TYPE_PACKED_VECTOR2_ARRAY/);
  assert.match(pluginSource, /TYPE_VECTOR2/);
  assert.match(pluginSource, /TYPE_COLOR/);
  assert.match(pluginSource, /PackedVector2Array\(\)/);
  assert.match(pluginSource, /Vector2\(float\(/);
  assert.match(pluginSource, /Color\(float\(/);
});

test("set_node_property applies converted values and rejects invalid conversion input", () => {
  const conversionIndex = pluginSource.indexOf("var converted_value = _convert_json_property_value(value, old_value, property_info)");
  const errorIndex = pluginSource.indexOf('"code": "INVALID_PROPERTY_VALUE"');
  const applyIndex = pluginSource.indexOf('undo_redo.add_do_property(node, property, new_value)');

  assert.ok(conversionIndex > -1, "Expected handle_set_property to convert values before applying them");
  assert.ok(errorIndex > conversionIndex, "Expected invalid conversion errors after conversion");
  assert.ok(applyIndex > errorIndex, "Expected property mutation only after conversion succeeds");
  assert.doesNotMatch(pluginSource, /undo_redo\.add_do_property\(node, property, value\)/);
});

test("packed Vector2 array conversion reports the invalid point index", () => {
  assert.match(pluginSource, /Invalid Vector2 at index /);
  assert.match(pluginSource, /Expected PackedVector2Array as an array of \{x, y\} or \[x, y\] points/);
});
