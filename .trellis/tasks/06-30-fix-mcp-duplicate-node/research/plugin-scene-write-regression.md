# Plugin scene write regression

## Findings

* The editor plugin stores the current transaction in a plain `Dictionary` but many handlers access `current_txn.step_count` with property syntax. In GDScript this is not reliable for dictionary keys and matches the logged runtime error.
* `handle_add_node`, `handle_instantiate_scene`, and `handle_duplicate_node` set `node.owner = root` before the node is part of the scene tree. Godot requires owner to be an ancestor already in the tree, which matches the logged `Invalid owner` error.
* `handle_duplicate_node` and `handle_instantiate_scene` then schedule `add_child` and `owner` as two separate undo-redo steps. The intended order is valid, but the eager owner assignment happens too early and can abort the operation before the duplicate becomes visible to later calls.
* `handle_reparent_node` uses `Node.reparent(...)` but does not restore owner after moving across subtree boundaries. This can also surface owner-related save/editor inconsistencies when the new parent is under the edited root.

## Implication

The MCP failure is caused by plugin implementation bugs, not an MCP capability boundary. Fixing transaction access plus owner assignment timing should unblock duplicate-then-edit workflows.
