# Plugin State Management

> How runtime state should be handled inside the Godot editor plugin layer.

---

## Overview

The plugin layer currently has only minimal local state. As the editor plugin
grows, state should remain explicit and scoped by responsibility.

---

## State Categories

- **ephemeral UI state**
  - current dock widgets
  - temporary labels / view state
- **connection state**
  - editor service status
  - connection health / transport lifecycle
- **operation state**
  - active AI action
  - recent operation history
  - rollback/UndoRedo metadata

---

## Rules

- Keep simple state on the plugin instance when there is only one owner.
- Promote state into dedicated helper scripts only when multiple plugin modules need it.
- Separate UI state from editor-operation state.
- Separate connection state from UndoRedo/operation state.

---

## Common Mistakes

- storing unrelated state in one generic dictionary
- coupling dock UI state directly to editor service internals
- keeping stale references after plugin teardown

---

## Real examples in this repository

- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
  currently keeps only one piece of plugin-owned state, `_dock_instance`,
  on the plugin object itself and clears it explicitly on teardown.
- [tests/scaffold.test.js](/E:/code/AI-godot-mcp/tests/scaffold.test.js)
  is the scaffold-level verification anchor that the plugin boundary remains in
  place while runtime state is intentionally small.
