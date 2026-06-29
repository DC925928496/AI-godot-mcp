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

Choose one MCP server startup method, then load the Godot editor plugin for the
project you want the agent to operate on.

### Option 1: npx

```bash
npx ai-godot-mcp install "<godot-project-path>"
```

Use this when you want npm to download and run the published package on demand.
The MCP client starts the stdio server with `npx ai-godot-mcp`.

#### Claude Code

```bash
claude mcp add ai-godot-mcp -- npx ai-godot-mcp
```

#### Other MCP Clients

Use this server configuration:

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

### Option 2: GitHub Releases

Use this when you downloaded the packaged release artifact instead of pulling
from npm at runtime.

```bash
npm install -g "./ai-godot-mcp-<version>.tgz"
ai-godot-mcp install "<godot-project-path>"
```

Then point your MCP client at the installed command:

```bash
claude mcp add ai-godot-mcp -- ai-godot-mcp
```

```json
{
  "mcpServers": {
    "ai-godot-mcp": {
      "command": "ai-godot-mcp",
      "args": []
    }
  }
}
```

If a release also provides `plugin-only.zip`, that file only installs the Godot
addon manually. It does not start the Node MCP server; use one of the server
startup methods above or below.

### Option 3: Build from Source

Use this when developing the project locally or testing unpublished changes.

```bash
git clone https://github.com/DC925928496/AI-godot-mcp.git
cd AI-godot-mcp
npm install
npm run build
node build/cli/index.js install "<godot-project-path>"
```

Then point your MCP client to the built server entrypoint:

```bash
claude mcp add ai-godot-mcp -- node "E:/code/AI-godot-mcp/build/index.js"
```

```json
{
  "mcpServers": {
    "ai-godot-mcp": {
      "command": "node",
      "args": ["E:/code/AI-godot-mcp/build/index.js"]
    }
  }
}
```

Re-run `npm run build` after changing TypeScript source.

### Load the Godot Plugin

After installing or copying the addon:

1. Open exactly one target Godot project.
2. Navigate to **Project → Project Settings → Plugins**.
3. Enable **"AI Godot MCP"**.
4. Restart or reload your MCP client so it discovers the server tools.

Only one Godot project should load the plugin at a time. The plugin listens on
local port `6550`; if two editors load it, one editor may fail to bind the port
or the MCP server may connect to the wrong project. Before switching projects,
disable the plugin or close the current Godot editor, then enable it in the next
project.

## Architecture

AI-godot-mcp uses a **WebSocket communication architecture**:

- **Node MCP Server** (WebSocket client) ↔ **Godot Editor Plugin** (WebSocket server on port 6550)
- All write operations integrate with Godot's native **UndoRedo** system, supporting atomic transactions
- Unified response format: `{ok: true, data}` or `{ok: false, error: {code, message, suggestions}}`

## CLI Commands

### MCP server

```bash
npx ai-godot-mcp
```

Starts the MCP server over stdio. MCP clients usually run this command for you.
For a release package installed globally, use `ai-godot-mcp`. For a source
checkout, use `node build/index.js` after `npm run build`.

### install

```bash
npx ai-godot-mcp install "<project-path>"
```

Deploy plugin to Godot project with version compatibility validation (Godot 4.6.x only).

### uninstall

```bash
npx ai-godot-mcp uninstall "<project-path>"
```

Remove `addons/ai_godot_mcp/` directory from project.

### version

```bash
npx ai-godot-mcp version
```

Display version information and supported Godot versions.

## Troubleshooting

- **Godot version mismatch** → Ensure you're using Godot 4.6.x (verify with `godot --version`)
- **Plugin not enabled** → Check **Project → Project Settings → Plugins** in editor, ensure "AI Godot MCP" is checked
- **WebSocket connection failed** → Confirm plugin is started and port 6550 is not occupied
- **Tool call timeout** → Ensure Godot editor is running and plugin is loaded

## License

MIT
