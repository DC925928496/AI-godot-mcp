# Phase 6 Test Document: Authoring Capability Batches 1-2

## Test Environment

- Godot editor is running
- Plugin is installed and enabled
- MCP server is running
- A Godot project contains at least:
  - one target scene such as `res://scenes/Battle.tscn`
  - one instantiable scene such as `res://units/PlayerUnit.tscn`
  - one controller node script with a target method for signal wiring

## Batch 1 Test 1: Open Scene

```typescript
const result = await mcp.callTool("open_scene", {
  scene_path: "res://scenes/Battle.tscn"
});
console.log(result);
// Expect: opened scene path matches input
```

## Batch 1 Test 2: Instantiate PackedScene

```typescript
await mcp.callTool("begin_ai_action", { name: "Add player unit" });
const result = await mcp.callTool("instantiate_scene", {
  parent_path: ".",
  scene_path: "res://units/PlayerUnit.tscn",
  node_name: "PlayerUnit"
});
await mcp.callTool("end_ai_action", {});
console.log(result);
// Expect: node_path points to the instantiated node
```

## Batch 1 Test 3: Connect Signal

```typescript
const result = await mcp.callTool("connect_signal", {
  source_node_path: "PlayerUnit",
  signal_name: "turn_finished",
  target_node_path: "BattleController",
  method_name: "_on_player_turn_finished",
  deferred: false,
  one_shot: false
});
console.log(result);
// Expect: connected === true
```

## Batch 1 Test 4: Disconnect Signal

```typescript
const result = await mcp.callTool("disconnect_signal", {
  source_node_path: "PlayerUnit",
  signal_name: "turn_finished",
  target_node_path: "BattleController",
  method_name: "_on_player_turn_finished"
});
console.log(result);
// Expect: disconnected === true
```

## Batch 1 Test 5: Read Input Map

```typescript
const result = await mcp.callTool("get_input_map", {});
console.log(result);
// Expect: action list returned with event descriptions
```

## Batch 1 Test 6: Bind Keyboard Action

```typescript
const result = await mcp.callTool("bind_input_key", {
  action_name: "cursor_confirm",
  key: "ENTER"
});
console.log(result);
// Expect: action exists and event_text is returned
```

## Batch 2 Test 1: List Autoloads

```typescript
const result = await mcp.callTool("list_autoloads", {});
console.log(result);
// Expect: autoloads array with name, path, and is_singleton fields
```

## Batch 2 Test 2: Set Singleton Autoload

```typescript
const result = await mcp.callTool("set_autoload", {
  name: "GameManager",
  path: "res://scripts/game_manager.gd",
  is_singleton: true
});
console.log(result);
// Expect: singleton autoload is added through the Godot EditorPlugin API
```

## Batch 2 Test 3: Remove Autoload

```typescript
const result = await mcp.callTool("remove_autoload", {
  name: "GameManager"
});
console.log(result);
// Expect: autoload is removed through the Godot EditorPlugin API
```

## Batch 2 Test 4: Add And Remove Group Membership

```typescript
await mcp.callTool("begin_ai_action", { name: "Group membership" });
const addResult = await mcp.callTool("add_node_to_group", {
  node_path: "PlayerUnit",
  group_name: "units",
  persistent: true
});
const removeResult = await mcp.callTool("remove_node_from_group", {
  node_path: "PlayerUnit",
  group_name: "units"
});
await mcp.callTool("end_ai_action", {});
console.log({ addResult, removeResult });
// Expect: node is added to and removed from the group safely
```

## Batch 2 Test 5: Reparent Node

```typescript
await mcp.callTool("begin_ai_action", { name: "Move unit under container" });
const result = await mcp.callTool("reparent_node", {
  node_path: "PlayerUnit",
  new_parent_path: "Units",
  keep_global_transform: true
});
await mcp.callTool("end_ai_action", {});
console.log(result);
// Expect: node is reparented using Godot Node.reparent without transform errors
```

## Batch 2 Test 6: Duplicate Node

```typescript
const result = await mcp.callTool("duplicate_node", {
  node_path: "PlayerUnit",
  new_name: "PlayerUnitCopy"
});
console.log(result);
// Expect: duplicate_path points to the new node
```

## Acceptance Checklist

- [ ] `open_scene` opens a real `res://` scene
- [ ] `instantiate_scene` instances an existing PackedScene into the edited scene
- [ ] `connect_signal` validates and creates a persistent connection
- [ ] `disconnect_signal` removes an existing connection
- [ ] `get_input_map` returns structured action data
- [ ] `bind_input_key` creates or extends a keyboard input action
- [ ] `list_autoloads` returns normalized autoload data
- [ ] `set_autoload` and `remove_autoload` use the Godot EditorPlugin API
- [ ] `add_node_to_group` and `remove_node_from_group` update group membership
- [ ] `reparent_node` rejects invalid parent cycles and moves a valid node
- [ ] `duplicate_node` validates new names and creates a duplicate
