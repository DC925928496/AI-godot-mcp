# Plugin Directory Structure

> How the Godot editor plugin layer is organized in this project.

---

## Overview

The plugin layer lives under `addons/ai_godot_mcp/` and should remain clearly
separate from the Node MCP server implementation under `src/`.

Current scaffold layout:

```text
addons/ai_godot_mcp/
├── plugin.cfg
├── plugin.gd
├── dock/
└── scripts/
```

---

## Module Organization

- `plugin.cfg`
  - Godot plugin metadata entrypoint
- `plugin.gd`
  - `EditorPlugin` lifecycle entrypoint
  - attaches/removes dock UI
- `dock/`
  - reserved for dock UI scenes/scripts once the plugin UI grows
- `scripts/`
  - reserved for plugin-side service, editor integration, and scene operation helpers

Keep editor-plugin code in `addons/ai_godot_mcp/`.
Do not mix plugin runtime code into the Node `src/` tree.

---

## Naming Conventions

- plugin folder: lowercase with underscores
- GDScript files: `snake_case.gd` when multiple files appear
- plugin entry file: `plugin.gd`
- Godot plugin metadata file: `plugin.cfg`

---

## Examples

- [addons/ai_godot_mcp/plugin.cfg](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.cfg)
- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
