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

## Real examples in this repository

- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
  keeps the current plugin contract minimal and explicit rather than reading
  from a loose unvalidated input bag.
- [addons/ai_godot_mcp/plugin.cfg](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.cfg)
  is a stable metadata contract that future plugin tooling should validate
  against instead of inferring plugin identity implicitly.
