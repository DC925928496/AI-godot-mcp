# AI-godot-mcp

[![MCP Server](https://badge.mcpx.dev?type=server)](https://modelcontextprotocol.io/introduction)
[![Made with Godot](https://img.shields.io/badge/Made%20with-Godot-478CBF?style=flat&logo=godot%20engine&logoColor=white)](https://godotengine.org)
[![GDScript](https://img.shields.io/badge/GDScript-478CBF?style=flat&logo=godot%20engine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![WebSocket](https://img.shields.io/badge/WebSocket-000000?style=flat&logo=socket.io&logoColor=white)](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
[![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](https://opensource.org/licenses/MIT)

**[中文文档](docs/README_zh.md)**

Production-grade Godot MCP service for AI-driven game development.

> Inspired by [dpeachpeach/godot-mcp](https://github.com/dpeachpeach/godot-mcp)

## Features

### Phase 1: Read-Only Tools
- **`get_project_context`** - Retrieve Godot version, project name, and plugin status
- **`get_scene_tree`** - Get current scene node tree (supports depth limit and type filtering)
- **`get_editor_logs`** - Fetch editor output panel logs (supports timestamp and level filtering)

### Phase 2: Scene Editing & Transactions
- **`create_scene`** - Create new scene files
- **`add_node`** - Add nodes to scene tree
- **`set_node_property`** - Modify node properties
- **`delete_node`** - Delete nodes (supports undo)
- **`load_resource`** - Load resource references
- **`save_current_scene`** - Save current scene
- **`begin_ai_action` / `end_ai_action`** - UndoRedo atomic transaction support

### Phase 3: Script Attachment
- **`attach_script`** - Attach GDScript to nodes
- **`get_resource_uid`** - Get resource UID for validation

### Phase 4: Scene Execution
- **`play_current_scene`** - Run current scene (F6)
- **`stop_running_scene`** - Stop running scene (F8)

### Phase 5: CLI Tools
- **`install`** - Deploy plugin to Godot projects
- **`uninstall`** - Remove plugin from projects
- **`version`** - Display version information

## Requirements

- **Godot**: 4.6.x only
- **Node.js**: ≥18.0.0

## Quick Start

### Installation

```bash
npx ai-godot-mcp install <godot-project-path>
```

### Enable Plugin

In Godot Editor:
1. Open your project
2. Navigate to **Project → Project Settings → Plugins**
3. Enable **"AI Godot MCP"**

### Configure MCP Client

#### Claude Code

```bash
claude mcp add ai-godot-mcp -- npx ai-godot-mcp
```

Restart Claude Code and the tools will be available.

<details>
<summary><strong>Other MCP Clients</strong></summary>

For any MCP-compatible client, use this configuration:

```json
{
  "mcpServers": {
    "ai-godot-mcp": {
      "command": "npx",
      "args": ["ai-godot-mcp"]
    }
  }
}
```

</details>

## Architecture

AI-godot-mcp uses a **WebSocket communication architecture**:

- **Node MCP Server** (WebSocket client) ↔ **Godot Editor Plugin** (WebSocket server on port 6550)
- All write operations integrate with Godot's native **UndoRedo** system, supporting atomic transactions
- Unified response format: `{ok: true, data}` or `{ok: false, error: {code, message, suggestions}}`

## CLI Commands

### install

```bash
npx ai-godot-mcp install <project-path>
```

Deploy plugin to Godot project with version compatibility validation (Godot 4.6.x only).

### uninstall

```bash
npx ai-godot-mcp uninstall <project-path>
```

Remove `addons/ai_godot_mcp/` directory from project.

### version

```bash
npx ai-godot-mcp version
```

Display version information and supported Godot versions.

## Building from Source

<details>
<summary>Expand to view</summary>

```bash
git clone https://github.com/DC925928496/AI-godot-mcp.git
cd AI-godot-mcp
npm install
npm run build
```

Then point your MCP client configuration to `build/index.js` instead of using `npx`.

</details>

## Troubleshooting

- **Godot version mismatch** → Ensure you're using Godot 4.6.x (verify with `godot --version`)
- **Plugin not enabled** → Check **Project → Project Settings → Plugins** in editor, ensure "AI Godot MCP" is checked
- **WebSocket connection failed** → Confirm plugin is started and port 6550 is not occupied
- **Tool call timeout** → Ensure Godot editor is running and plugin is loaded

## License

MIT
