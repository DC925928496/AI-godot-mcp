# Architecture

## Current State

This package is an initial standalone scaffold for a new Godot MCP service intended for game developers.

## Planned Runtime Shape

- Node MCP server
  - accepts MCP tool calls
  - validates input
  - manages editor connection state
  - forwards requests to the Godot editor plugin
- Godot editor plugin
  - runs inside the editor as an `EditorPlugin`
  - exposes a local WebSocket service
  - reads and mutates scene state
  - wraps write operations in UndoRedo actions

## Repository Strategy

- This repository is the standalone extraction target for the new implementation line.
- Legacy `godot-mcp` remains a reference only and is not the long-term project root.

## Trellis Bootstrapping

At the standalone repository root:

1. install dependencies
2. confirm the project can `build` and `test`
3. run `trellis init`

The standalone repository should own its own Trellis metadata and workflow state from day one.
