# Fix Scene Property Persistence

## Goal

Fix scene authoring operations so values set through `set_node_property` are converted into Godot-native Variant types before they are applied, allowing `save_current_scene` to persist edited properties into `.tscn` files.

## What I Already Know

* The reported failure is: `set_node_property` returns success, but after `save_current_scene` the saved `.tscn` loses `Polygon2D.polygon` and `Line2D.points` values.
* Color values can become black `(0, 0, 0, 1)` instead of the requested green value.
* The MCP TypeScript layer currently defines `set_node_property.value` as `z.unknown()` and forwards the value unchanged.
* The Godot plugin handler `handle_set_property` currently reads `params.value` and calls `undo_redo.add_do_property(node, property, value)` without converting JSON values to Godot-native types.
* `handle_save_scene` uses `EditorInterface.save_scene()`. The likely root cause is not custom save serialization, but that the node property was set with the wrong runtime Variant type before save.

## Requirements

* Convert common MCP JSON property shapes into Godot-native values before registering the undo/redo property mutation.
* Support `PackedVector2Array` properties used by:
  * `Polygon2D.polygon`
  * `Line2D.points`
* Support `Color` properties from JSON object and array representations.
* Preserve existing transaction and undo/redo behavior.
* Preserve explicit failure signaling for unsupported or invalid value shapes instead of returning success with a lossy value.
* Keep the Node MCP server API compatible; callers should still use `set_node_property` with `value`.

## Acceptance Criteria

* [x] `set_node_property` converts polygon/points input arrays into `PackedVector2Array` before applying them.
* [x] `set_node_property` converts color input into a `Color` value before applying it.
* [x] Invalid vector/color shapes return a specific error and do not register an editor mutation.
* [x] Source-level regression tests cover the conversion helper and `handle_set_property` call path.
* [x] `npm run build` passes.
* [x] `npm test` passes.
* [x] Manual Godot verification steps are documented for creating/saving a scene with `Polygon2D`, `Line2D`, and a green color property.

## Definition of Done

* Tests added or updated for the changed behavior.
* Lint/typecheck/test commands pass where the local environment supports them.
* Manual validation notes are included because `.tscn` save behavior depends on the Godot editor runtime.
* Trellis spec update is considered if the fix establishes a reusable JSON-to-Variant contract.

## Out of Scope

* Changing the external MCP tool name or top-level request schema.
* Implementing every Godot Variant type in this task.
* Adding `Rect2`, `Vector3`, `PackedColorArray`, or other Variant conversions before a concrete caller need is identified.
* Replacing `EditorInterface.save_scene()` with a custom scene serialization path unless code inspection proves it is required.
* Adding a full Godot editor integration test harness.

## Technical Approach

Add a plugin-side conversion layer used by `handle_set_property`. The converter should inspect the existing target property value or property metadata, then convert JSON-compatible inputs into the corresponding Godot type. For this bug, the MVP should prioritize `Vector2`, `PackedVector2Array`, and `Color`, because these directly cover the reported `Polygon2D`, `Line2D`, and color persistence failures.

## Decision (ADR-lite)

**Context**: MCP clients can only send JSON-compatible values, while Godot scene persistence expects native Variant types for many editable properties.

**Decision**: Perform JSON-to-Variant conversion in the Godot plugin before calling `UndoRedo.add_do_property`.

**Consequences**: The TypeScript MCP layer remains simple and backward compatible, while the editor plugin owns Godot-specific type semantics. Unsupported property types remain out of scope until new concrete failures appear.

## Manual Verification Plan

1. Start Godot 4.x with the plugin enabled and open a temporary scene.
2. Use MCP tools to add a `Polygon2D` node and set `polygon` to JSON points such as `[[0, 0], [64, 0], [64, 64], [0, 64]]`.
3. Use MCP tools to add a `Line2D` node and set `points` to JSON points such as `[{"x": 0, "y": 0}, {"x": 64, "y": 64}]`.
4. Set a color property, such as `Polygon2D.color`, to `{"r": 0, "g": 1, "b": 0, "a": 1}`.
5. Call `save_current_scene`, reopen the `.tscn`, and confirm the file contains the polygon/points data and the color remains green instead of black.
6. Send one invalid point, such as `[["bad", 0]]`, and confirm `set_node_property` returns `INVALID_PROPERTY_VALUE` without saving a lossy value.

## Verification Results

* `npm run build` passed.
* `npm run lint` passed.
* `npm test` passed: 35 passing, 1 skipped because the live Godot editor/plugin was not connected.
* `git diff --check` passed with only the expected Windows line-ending notice for `websocket_server.gd`.
* Manual Godot editor verification was not run in this session.

## Technical Notes

* Relevant code:
  * `addons/ai_godot_mcp/websocket_server.gd`
  * `src/server/createServer.ts`
  * `tests/scaffold.test.js`
  * `tests/runtime-log-capture.test.js`
* Relevant spec files:
  * `.trellis/spec/frontend/index.md`
  * `.trellis/spec/frontend/type-safety.md`
  * `.trellis/spec/frontend/quality-guidelines.md`
  * `.trellis/spec/frontend/state-management.md`
* Existing package scripts:
  * `npm run build`
  * `npm run lint`
  * `npm test`
