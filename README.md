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

## Vision

AI-godot-mcp aims to let ordinary people build Godot games with coding agents such as Codex, using this project as the editor bridge and the Godot editor as the live development surface.

The long-term goal is not to hard-code game-building workflows into MCP. The goal is to give agents a reliable Godot execution layer: the agent does the planning and reasoning, while AI-godot-mcp safely inspects, mutates, runs, and observes the editor on the agent's behalf.

## What Comes Next

The repository already has the low-level MCP bridge. The next direction is to make that bridge a better execution substrate for Codex-style agents:

- keep workflow intelligence in the agent layer, while expanding MCP into a more complete and composable Godot capability surface
- strengthen the observe-repair loop with clearer in-editor status, operation history, and run feedback
- lower the onboarding cost with starter templates, example projects, and docs that show how agents can drive the editor effectively
- expand the Godot authoring surface toward signals, input maps, scene instancing, autoloads, and common UI flows

## Features

### 🔍 Project Inspection
- **`get_project_context`** - Retrieve Godot version, project name, and plugin status
- **`get_scene_tree`** - Get current scene node tree (supports depth limit and type filtering)
- **`get_editor_logs`** - Fetch editor output panel logs (supports timestamp and level filtering)

### 🎨 Scene Editing
- **`create_scene`** - Create new scene files
- **`add_node`** - Add nodes to scene tree with automatic parent resolution
- **`set_node_property`** - Modify node properties with type validation
- **`delete_node`** - Delete nodes with full undo support
- **`load_resource`** - Load and reference external resources
- **`save_current_scene`** - Save current scene to disk

### ⚡ Transaction Management
- **`begin_ai_action` / `end_ai_action`** - Atomic batch operations with native UndoRedo integration

### 📝 Script Management
- **`attach_script`** - Attach GDScript to nodes with automatic template generation
- **`get_resource_uid`** - Get resource UID for cross-reference validation

### ▶️ Scene Execution
- **`play_current_scene`** - Run current scene in editor (F6)
- **`stop_running_scene`** - Stop running scene (F8)

### 🛠️ CLI Tools
- **`install`** - Deploy plugin to Godot projects with version validation
- **`uninstall`** - Clean removal of plugin from projects
- **`version`** - Display version and compatibility information

## Requirements

- **Godot**: 4.6.x only
- **Node.js**: ≥20.0.0

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
