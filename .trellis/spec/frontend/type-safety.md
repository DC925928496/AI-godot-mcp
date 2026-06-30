# Plugin Contract Safety

> Input and contract safety patterns for the Godot plugin layer.

---

## Overview

GDScript is dynamically typed, so this layer relies on explicit contract
discipline rather than compiler-enforced type safety.

---

## Contract Rules

- Treat all server-provided inputs as untrusted.
- Guard optional fields explicitly before use.
- Keep resource paths, class names, and node paths as separate concepts.
- Do not assume a value is safe because the server usually provides it.

---

## Validation Patterns

- check key presence before reading optional params
- normalize `res://` paths before use
- fail loudly when a required editor object, node, or resource is missing
- preserve explicit success/failure signaling for plugin operations

---

## Forbidden Patterns

- using one loosely defined input bag without validating expected keys
- treating arbitrary strings as both class names and resource paths
- continuing after failed load/open/lookup operations

---

## Scenario: Batch 1 authoring capability validation

### 1. Scope / Trigger
- Trigger: plugin-side handlers now support scene opening, `PackedScene` instancing, signal wiring, and input-map persistence.

### 2. Signatures
- `handle_open_scene(req)`
- `handle_instantiate_scene(req)`
- `handle_connect_signal(req)`
- `handle_disconnect_signal(req)`
- `handle_get_input_map(req)`
- `handle_bind_input_key(req)`

### 3. Contracts
- `open_scene` accepts only `res://*.tscn` scene paths.
- `instantiate_scene` accepts a parent node path plus a `PackedScene` resource path.
- signal wiring requires separate validation of:
  - source node existence
  - target node existence
  - signal existence
  - target method existence
- input-map mutation accepts only constrained key aliases / keycode strings and persists through `ProjectSettings`.
- signal connection metadata returned by Godot must be read as dictionary fields, not as assumed object properties.
- plugin-side handlers must keep their own validation guardrails even when the Node MCP layer already validates inputs.

### 4. Validation & Error Matrix
- bad `res://` path -> `INVALID_PATH`
- non-`.tscn` scene open request -> `INVALID_SCENE`
- missing node -> `NODE_NOT_FOUND`
- missing signal -> `SIGNAL_NOT_FOUND`
- missing method -> `METHOD_NOT_FOUND`
- repeated connection -> `ALREADY_CONNECTED`
- missing connection on disconnect -> `CONNECTION_NOT_FOUND`
- unsupported key alias -> `INVALID_KEY`

### 5. Good/Base/Bad Cases
- Good: connect `turn_finished` from a unit node to `_on_player_turn_finished` on a controller node after both endpoints are verified.
- Base: bind `ENTER` to a missing action and persist it into `ProjectSettings`.
- Bad: attempt to connect a signal without checking `has_signal()` or accept a non-scene resource in `instantiate_scene`.

### 6. Tests Required
- manual Godot verification for each handler
- regression check that handler registration in `handle_request()` stays aligned with Node-side tool registration
- source-level regression check for scene-path validation, identifier validation, signal connection dictionary access, and input-map persistence refresh

### 7. Wrong vs Correct
#### Wrong
- continue after a missing node, or assume a method exists because the caller usually sends a valid name.

#### Correct
- fail early with a specific error code before any editor mutation is registered in `UndoRedo`.

---

## Scenario: Batch 2 project and scene-structure validation

### 1. Scope / Trigger
- Trigger: plugin-side handlers now support autoload management, group membership, hierarchy reparenting, and node duplication.

### 2. Signatures
- `handle_list_autoloads(req)`
- `handle_set_autoload(req)`
- `handle_remove_autoload(req)`
- `handle_add_node_to_group(req)`
- `handle_remove_node_from_group(req)`
- `handle_reparent_node(req)`
- `handle_duplicate_node(req)`

### 3. Contracts
- Autoload mutation should go through `EditorPlugin.add_autoload_singleton` and `EditorPlugin.remove_autoload_singleton` instead of raw arbitrary project-setting mutation.
- Plugin-side handlers must fail clearly when the `EditorPlugin` API reference is unavailable.
- `reparent_node` should use Godot `Node.reparent(new_parent, keep_global_transform)` instead of manually reading `global_transform`.
- Reparenting must reject the edited scene root, the same node as parent, and descendant-parent cycles.
- `duplicate_node` must validate optional new names on the plugin side even when the Node/MCP layer already validates them.
- Group and hierarchy handlers must validate node paths before looking up nodes.

### 4. Validation & Error Matrix
- missing `EditorPlugin` reference -> `PLUGIN_API_UNAVAILABLE`
- unsupported non-singleton autoload mode -> `UNSUPPORTED_AUTOLOAD_MODE`
- invalid node path -> `INVALID_NODE_PATH`
- invalid duplicate name -> `INVALID_NODE_NAME`
- root reparent request -> `CANNOT_REPARENT_ROOT`
- self or descendant reparent request -> `INVALID_PARENT`

### 5. Tests Required
- source-level regression check for official autoload API calls
- source-level regression check for `Node.reparent`
- source-level regression check for node-path and node-name validation helpers
- manual Godot verification for autoload add/remove, group add/remove, reparent, and duplicate

---

## Scenario: Scene property JSON-to-Variant conversion

### 1. Scope / Trigger
- Trigger: `set_node_property` receives JSON-compatible MCP payloads for editor properties whose Godot scene persistence expects native Variant types.
- Trigger: scene save behavior depends on the property being assigned as the correct Godot type before `EditorInterface.save_scene()` runs.

### 2. Signatures
- Plugin-side handler:
  - `handle_set_property(req: Dictionary) -> Dictionary`
- Plugin-side conversion helpers:
  - `_convert_json_property_value(value, old_value, property_info: Dictionary) -> Dictionary`
  - `_convert_json_to_vector2(value) -> Dictionary`
  - `_convert_json_to_packed_vector2_array(value) -> Dictionary`
  - `_convert_json_to_color(value) -> Dictionary`

### 3. Contracts
- `set_node_property` request fields:
  - `node_path`: path to an existing node in the edited scene
  - `property`: name of an existing Godot property on that node
  - `value`: JSON-compatible payload from the MCP caller
- Supported conversion targets:
  - `Vector2` from `{x, y}` or `[x, y]`
  - `PackedVector2Array` from an array of `{x, y}` or `[x, y]` points
  - `Color` from `{r, g, b, a?}` or `[r, g, b, a?]`
- Conversion must run before `undo_redo.add_do_property(...)`.
- Unsupported target property types may still pass through unchanged, preserving existing behavior until a concrete conversion need exists.

### 4. Validation & Error Matrix
- missing node -> `NODE_NOT_FOUND`
- missing property -> `INVALID_PROPERTY`
- invalid `Vector2` object or array shape -> `INVALID_PROPERTY_VALUE`
- invalid `PackedVector2Array` point shape -> `INVALID_PROPERTY_VALUE` with the failing point index
- invalid `Color` object or array shape -> `INVALID_PROPERTY_VALUE`

### 5. Good/Base/Bad Cases
- Good: set `Polygon2D.polygon` with `[[0, 0], [64, 0], [64, 64]]`; the plugin converts it to `PackedVector2Array` before saving.
- Base: set a plain string or number property; unsupported target types pass through unchanged.
- Bad: set `Line2D.points` with `[["bad", 0]]`; the plugin returns `INVALID_PROPERTY_VALUE` and does not register an editor mutation.

### 6. Tests Required
- source-level regression proving conversion helpers exist for `Vector2`, `PackedVector2Array`, and `Color`
- source-level regression proving `handle_set_property` calls `_convert_json_property_value(...)` before `undo_redo.add_do_property(...)`
- source-level regression proving direct `undo_redo.add_do_property(node, property, value)` is not reintroduced
- manual Godot verification that `Polygon2D.polygon`, `Line2D.points`, and a green `Color` property persist after `save_current_scene`

### 7. Wrong vs Correct
#### Wrong
```gdscript
var value = params.get("value")
undo_redo.add_do_property(node, property, value)
```

#### Correct
```gdscript
var old_value = node.get(property)
var converted_value = _convert_json_property_value(value, old_value, property_info)
if not bool(converted_value.get("ok", false)):
	return {"ok": false, "error": {"code": "INVALID_PROPERTY_VALUE"}}
undo_redo.add_do_property(node, property, converted_value.get("value"))
```

---

## Real examples in this repository

- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
  keeps the current plugin contract minimal and explicit rather than reading
  from a loose unvalidated input bag.
- [addons/ai_godot_mcp/plugin.cfg](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.cfg)
  is a stable metadata contract that future plugin tooling should validate
  against instead of inferring plugin identity implicitly.
