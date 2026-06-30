# Fix MCP duplicate node scene editing in Godot

## Goal

Fix the Godot editor plugin so MCP scene-structure write tools can safely duplicate and place nodes in an edited scene without losing node visibility or triggering invalid owner errors.

## What happened

Real usage against `hex_tile.tscn` showed that `duplicate_node` reported success but the new node could not be resolved by later MCP calls such as `set_node_property`, and `get_scene_tree` did not show the duplicate. Godot logs also reported:

* `Invalid access to property or key 'step_count' on a base object of type 'Dictionary'`
* `Invalid owner. Owner must be an ancestor in the tree.`

This established that the failure was in the plugin implementation, not at the abstract MCP capability boundary.

## Requirements

* `duplicate_node` must add the duplicate into the edited scene tree so later MCP calls can resolve it by path.
* Scene write operations must not set invalid owners before nodes are attached under a valid ancestor.
* Transaction step tracking must not rely on `Dictionary` property syntax that can fail at runtime in GDScript.
* Related scene mutation paths that share the same owner or transaction patterns should be fixed together where the root cause is the same.

## Acceptance Criteria

* [ ] `duplicate_node` produces a node that is visible to `get_scene_tree`.
* [ ] Follow-up `set_node_property` calls can resolve the duplicated node by the returned path.
* [ ] Plugin code no longer uses `current_txn.step_count` property access.
* [ ] Owner restoration for add / instantiate / duplicate / reparent / delete paths follows valid tree ancestry.
* [ ] Regression coverage exists for transaction step access and owner assignment sequencing.

## Definition of Done

* Focused regression tests pass.
* Project build and test suite pass.
* The task documents the actual root cause and resulting fix scope.

## Technical Approach

Patch `addons/ai_godot_mcp/websocket_server.gd` to:

* centralize transaction step counting with a helper that uses dictionary key access
* resolve the correct owner from the real scene ancestry
* defer owner restoration until after nodes are attached to the tree
* restore subtree owners when reparenting or undoing delete-like operations

Add source-level regression tests that assert:

* dictionary-backed transaction step tracking is used
* duplicated / instantiated / added nodes no longer set `owner = root` eagerly
* owner restoration helpers are part of the mutation flow

## Out of Scope

* Adding brand-new MCP tools
* Redesigning scene generation workflows
* High-level board generation features such as hex-map authoring APIs

## Technical Notes

* User-reported failures came from `res://addons/ai_godot_mcp/websocket_server.gd` around duplicate/reparent flows.
* The target Godot project initially loaded an older copy of the plugin, which explained why duplicate visibility still failed until the project plugin was resynced and Godot was restarted.
* Final verification proved the fixed plugin could duplicate `GrassHex`, update the duplicate position, and read it back through the MCP scene tree.
