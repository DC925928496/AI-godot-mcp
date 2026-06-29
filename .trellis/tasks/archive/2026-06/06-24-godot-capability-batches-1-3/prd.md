# Expand Godot Authoring Capability Batches 1-3

## Goal

Expand `AI-godot-mcp` from a scene-editing bridge into a more complete Godot execution layer for Codex-style agents by adding the next three batches of real game-development capabilities.

This task establishes the full three-batch roadmap, then starts implementation from **Batch 1 and Batch 2** after the scope expansion.

## Context

The product boundary is:

- the agent owns planning and reasoning
- `AI-godot-mcp` owns safe, composable, observable Godot-side execution

So the project should not embed hard-coded game-design workflows. Instead, it should expose the Godot capabilities that let an agent carry out its own plan reliably.

## What I Already Know

- Current MCP tools cover:
  - scene inspection
  - scene/node mutations
  - script attachment
  - play/stop current scene
  - editor/runtime logs
- Current implementation paths are:
  - Node/MCP layer: `src/server/createServer.ts`, `src/server/editorConnection.ts`
  - Godot plugin layer: `addons/ai_godot_mcp/websocket_server.gd`
- The current tool surface is still too narrow for common Godot authoring tasks such as:
  - opening a specific scene
  - instancing `PackedScene`
  - connecting signals
  - editing input actions
  - managing autoloads
  - managing groups
  - reorganizing scene hierarchy

## Requirements

### Product requirement

The project must expose a broader, safe, composable Godot capability surface so that agents can implement real game features without relying on hidden editor assumptions or unsafe generic escape hatches.

### Batch plan

#### Batch 1: high-frequency authoring primitives

Implement these first:

- `open_scene(scene_path)`
- `instantiate_scene(parent_path, scene_path, node_name?)`
- `connect_signal(source_node_path, signal_name, target_node_path, method_name, deferred?, one_shot?)`
- `disconnect_signal(source_node_path, signal_name, target_node_path, method_name)`
- `get_input_map()`
- `bind_input_key(action_name, key, ctrl?, alt?, shift?, meta?)`

These should be sufficient to unlock common prototype work such as a tactics scene, scene composition, HUD control wiring, and keyboard-driven game loops.

#### Batch 2: project and structure management

Implement in this expanded task:

- `list_autoloads()`
- `set_autoload(name, path, is_singleton?)`
- `remove_autoload(name)`
- `add_node_to_group(node_path, group_name, persistent?)`
- `remove_node_from_group(node_path, group_name)`
- `reparent_node(node_path, new_parent_path, keep_global_transform?)`
- `duplicate_node(node_path, new_name?)`

#### Batch 3: editor execution quality-of-life

Plan for:

- `get_editor_state()`
- `open_resource(resource_path)`
- `rescan_filesystem()`
- `save_all_open_scenes()`

### Safety and boundary requirements

- Do not add generic `call_method` or arbitrary code execution tools.
- Do not add arbitrary project setting mutation.
- Preserve current path validation and class validation boundaries.
- Keep write operations transaction-friendly and aligned with existing UndoRedo patterns where applicable.
- Errors must remain structured with stable error codes and actionable messages.

### Implementation scope for this task

This task starts the roadmap by implementing **Batch 1 and Batch 2**.

Batch 3 should remain documented as the next approved follow-up scope, but not implemented in this task unless the scope is later expanded explicitly.

## Acceptance Criteria

### PRD acceptance

- [ ] The PRD captures all three capability batches.
- [ ] The PRD makes the planning-vs-execution boundary explicit.
- [ ] Batch 1 and Batch 2 are clearly marked as the implementation scope for this task.

### Batch 1 implementation acceptance

- [ ] `open_scene` opens a valid `res://` scene and returns the opened path.
- [ ] `instantiate_scene` instances an existing `PackedScene` into the current edited scene safely.
- [ ] `connect_signal` validates source node, target node, signal existence, and target method existence before connecting.
- [ ] `disconnect_signal` safely removes an existing connection and returns a clear result when no matching connection exists.
- [ ] `get_input_map` returns the current input actions in a machine-usable structure.
- [ ] `bind_input_key` can create or extend a keyboard action binding safely.
- [ ] Node-side tool registration and argument validation exist for all Batch 1 tools.
- [ ] Plugin-side handlers exist for all Batch 1 tools.
- [ ] `npm run lint` passes.
- [ ] Tests are updated or added for the new tool registration and validation behavior.

### Batch 2 implementation acceptance

- [ ] `list_autoloads` returns current autoload names, normalized paths, and singleton metadata.
- [ ] `set_autoload` uses the Godot `EditorPlugin.add_autoload_singleton` API where singleton autoloads are requested.
- [ ] `remove_autoload` uses the Godot `EditorPlugin.remove_autoload_singleton` API.
- [ ] `add_node_to_group` and `remove_node_from_group` validate node paths and group names before registering UndoRedo operations.
- [ ] `reparent_node` uses the Godot `Node.reparent` API and rejects root/self/descendant-parent requests.
- [ ] `duplicate_node` validates optional new node names on both Node/MCP and plugin sides.
- [ ] Node-side tool registration and argument validation exist for all Batch 2 tools.
- [ ] Plugin-side handlers exist for all Batch 2 tools.
- [ ] Tests are updated or added for Batch 2 registration, validation, and source-level plugin guardrails.

## Definition Of Done

- A child task PRD exists for the three-batch capability roadmap.
- Batch 1 and Batch 2 are implemented end-to-end in Node and Godot layers.
- Tests and docs needed for Batch 1 and Batch 2 land with the code.
- Batch 3 remains documented as the next approved follow-up scope.

## Out Of Scope

- Implementing Batch 3 in this task
- Adding arbitrary execution escape hatches
- Changing the product boundary so MCP owns gameplay reasoning

## Technical Notes

- Primary files likely to change:
  - `src/server/createServer.ts`
  - `addons/ai_godot_mcp/websocket_server.gd`
  - `addons/ai_godot_mcp/plugin.gd`
  - `src/server/createServer.test.ts`
  - `tests/runtime-log-capture.test.js`
  - `tests/server.test.js`
- Manual validation doc likely needed:
  - `test-phase6.md`

## Research References

- `../06-24-vision-dual-readmes-roadmap/research/vision-roadmap.md` — explains why the next product step is a broader capability layer rather than hard-coded workflows
