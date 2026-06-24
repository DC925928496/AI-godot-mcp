# Error Handling

> How backend failures are surfaced to MCP clients.

---

## Overview

Raw exceptions should not cross the MCP boundary for expected operational
failures. Backend code should convert failures into structured, client-readable
tool responses wherever the SDK surface allows it.

---

## Error Handling Patterns

- Tool handlers should return structured failure results for:
  - bad input
  - missing files
  - missing Godot editor/plugin
  - unsupported Godot version
  - failed plugin/editor operations
- Unexpected process-level failures may still terminate the process, but only
  after logging to stderr.
- Failure messages should be actionable, not just technically correct.

---

## MCP Error Responses

When a tool fails, the response should:

- clearly state what failed
- distinguish validation failures from runtime failures
- include recovery hints when possible

Examples of useful recovery hints:

- confirm Godot 4.6.x is installed
- confirm the editor plugin is enabled
- confirm the target path points to a real Godot project
- confirm the editor/plugin connection is available

---

## Common Mistakes

- throwing generic exceptions for routine validation failures
- emitting vague messages like `Unknown error`
- returning success-shaped payloads for failed operations
- writing operational diagnostics to stdout instead of stderr

---

## Scenario: Batch 1 authoring capability tools

### 1. Scope / Trigger
- Trigger: new MCP tool signatures were added for scene opening, scene instancing, signal wiring, and input-map editing.

### 2. Signatures
- `open_scene(scene_path)`
- `instantiate_scene(parent_path, scene_path, node_name?)`
- `connect_signal(source_node_path, signal_name, target_node_path, method_name, deferred?, one_shot?)`
- `disconnect_signal(source_node_path, signal_name, target_node_path, method_name)`
- `get_input_map()`
- `bind_input_key(action_name, key, ctrl?, alt?, shift?, meta?)`

### 3. Contracts
- `scene_path` and other resource-like inputs must remain `res://` paths, not class names.
- `source_node_path`, `target_node_path`, and `parent_path` are node-path inputs and must not be reinterpreted as resource paths.
- `key` is a constrained symbolic key name or numeric keycode string, not an arbitrary event payload object.
- Node-side schemas must reject invalid Batch 1 arguments before `EditorConnection.send()` is called.
- Scene and signal write tools must pass the active `txn_id` through to the Godot plugin when an AI action is open.

### 4. Validation & Error Matrix
- invalid `scene_path` -> `INVALID_PATH`
- non-scene resource for `open_scene` / `instantiate_scene` -> `INVALID_SCENE`
- missing scene/resource -> `SCENE_NOT_FOUND`
- missing source/target/parent node -> `NODE_NOT_FOUND`
- missing signal -> `SIGNAL_NOT_FOUND`
- missing target method -> `METHOD_NOT_FOUND`
- duplicate signal connection -> `ALREADY_CONNECTED`
- missing signal connection to remove -> `CONNECTION_NOT_FOUND`
- unsupported keyboard alias -> `INVALID_KEY`
- empty input action name -> `INVALID_ACTION`

### 5. Good/Base/Bad Cases
- Good: open an existing `res://scenes/Battle.tscn` file and instance an existing `PackedScene` under a verified parent node.
- Base: create a new keyboard action with `bind_input_key("cursor_confirm", "ENTER")`.
- Bad: accept arbitrary strings as both scene paths and class names, or silently succeed when a signal target method does not exist.

### 6. Tests Required
- tool registration checks for all six Batch 1 tools
- handler-level validation checks proving invalid Batch 1 inputs do not send requests to Godot
- transaction propagation checks for `instantiate_scene`, `connect_signal`, and `disconnect_signal`
- build/test verification after server registration changes
- manual Godot verification for open scene, instance scene, signal connect/disconnect, input-map read, and keyboard binding

### 7. Wrong vs Correct
#### Wrong
- expose a generic `call_method` or raw signal payload tool and rely on the caller to know Godot internals.

#### Correct
- expose narrow task-level tools with explicit parameter schemas and stable validation errors.

---

## Scenario: Batch 2 project and scene-structure capability tools

### 1. Scope / Trigger
- Trigger: MCP tool signatures were added for autoload management, group membership, hierarchy reparenting, and node duplication.

### 2. Signatures
- `list_autoloads()`
- `set_autoload(name, path, is_singleton?)`
- `remove_autoload(name)`
- `add_node_to_group(node_path, group_name, persistent?)`
- `remove_node_from_group(node_path, group_name)`
- `reparent_node(node_path, new_parent_path, keep_global_transform?)`
- `duplicate_node(node_path, new_name?)`

### 3. Contracts
- Autoload mutation must use Godot `EditorPlugin` autoload APIs where the official API supports the requested mode.
- Only singleton autoload mutation is currently supported; `is_singleton: false` is invalid at the Node/MCP boundary.
- Resource paths must remain `res://` paths.
- Node paths must remain node paths and must not be reinterpreted as resource paths.
- Scene-structure write tools must pass the active `txn_id` through to the Godot plugin when an AI action is open.

### 4. Validation & Error Matrix
- invalid autoload name or group name -> schema validation failure before `EditorConnection.send()`
- unsupported non-singleton autoload -> schema validation failure before `EditorConnection.send()`
- invalid resource path -> schema validation failure before `EditorConnection.send()`
- missing node or parent node -> `NODE_NOT_FOUND`
- invalid node path -> `INVALID_NODE_PATH`
- root/self/descendant reparent request -> structured plugin error

### 5. Tests Required
- tool registration checks for all seven Batch 2 tools
- handler-level validation checks proving invalid Batch 2 inputs do not send requests to Godot
- transaction propagation checks for group, reparent, and duplicate operations
- source-level plugin guardrail checks for official autoload API usage and `Node.reparent`
- build/test verification after server registration changes
