# Vision Roadmap

## Vision

The target product is not only a Godot editor bridge for advanced users. It should enable ordinary people to work with Codex-style agents and the Godot editor as a practical game-development loop:

1. describe an idea
2. let the agent inspect the project and current scene
3. let the agent change scenes and scripts safely
4. run the game immediately
5. observe feedback
6. iterate until the game becomes playable

## Boundary

The product boundary matters:

- Codex-style agents should own the planning and reasoning.
- AI-godot-mcp should own safe, observable, editor-side execution.
- The project should not try to hard-code high-level game-design workflows into MCP itself.

If a user says "build me a simple tactics framework", the agent should decide how to decompose that work. MCP should provide the Godot-side capabilities that let the agent carry out and verify that plan.

## What The Repository Already Has

The current repo already covers the bridge layer well enough to support follow-up product work:

- `src/server/createServer.ts` exposes the core MCP tool surface for inspection, mutation, script attachment, play/stop, and logs.
- `src/server/editorConnection.ts` provides the local editor bridge and request/response transport.
- `addons/ai_godot_mcp/websocket_server.gd` implements the editor-side service boundary, validation, UndoRedo-backed mutations, and basic runtime-log capture.
- `package.json` plus `src/cli/*` provide a distributable CLI install path for existing Godot projects.

This means the project already has the low-level building blocks. The next phase should make those building blocks more complete, observable, and composable for agent-driven execution.

## Main Gap To The Vision

The current tools are mostly atom-level operations. They are good building blocks for an agent, but they are not yet a complete or comfortable execution layer for the broader vision.

Main gaps:

- The public story is still "MCP bridge for Godot" more than "ordinary people can build games with agents".
- The tool surface is still incomplete for many real Godot authoring tasks, so the agent often lacks enough safe primitives to carry out its own plan.
- The editor-side UX is thin. `addons/ai_godot_mcp/plugin.gd` creates a dock shell, but it does not yet surface meaningful connection health, operation history, or guided recovery.
- The workflow for beginners starts at "install into an existing Godot project", not "go from idea to playable prototype".
- Real game-building primitives are still narrow. Current docs and code focus on scenes, nodes, scripts, and logs, but not yet on broader gameplay assembly flows such as signal wiring, input maps, UI assembly, scene instancing, autoload setup, or starter templates.

## Recommended Next Directions

### 1. Expand MCP As A Better Capability Layer

Priority: highest

Why:

- The agent can only reason over the capabilities it can actually execute.
- The current repo already has the right substrate direction; it now needs a broader and cleaner Godot-side surface.

Recommended direction:

- Keep high-level planning in Codex or the calling agent.
- Expand MCP with more safe, composable editor capabilities, especially around:
  - signal wiring
  - input map inspection and editing
  - scene instancing and replacement
  - autoload and project-setting management
  - common UI assembly support

### 2. Strengthen The Observe-Repair Loop Inside Godot

Priority: high

Why:

- The vision depends on fast agent iteration after each change.
- Non-expert users need clear feedback when something fails.

Recommended direction:

- Turn the dock from a static shell into a real operator console:
  - live connection status
  - recent AI actions
  - failed operation summaries
  - quick hints for recovery
- Keep improving structured log and run feedback so the agent and user can both tell what happened after a playtest.

### 3. Lower The Onboarding Cost For Non-Experts

Priority: high

Why:

- Current setup assumes an existing Godot project and a user who already understands MCP installation.
- The vision explicitly targets ordinary people, not only experienced Godot developers.

Recommended direction:

- Add a guided "first playable prototype" path:
  - starter project template
  - example agent usage patterns
  - one walkthrough from install to first playable loop
- Consider a CLI or docs path that helps users bootstrap a project, not only install the addon into one.

### 4. Prove The Agent Loop With Example Projects

Priority: medium

Why:

- The product vision is strongest when users can see an agent build something real, not only call isolated tools.

Recommended direction:

- Ship 1-2 sample Godot projects that demonstrate:
  - scene inspection
  - safe mutation
  - script attachment
  - run/log/debug loop
  - iterative improvement with Codex
- Use those examples as integration fixtures and public tutorials at the same time.

## Suggested Product Framing

Public-facing framing should shift from:

- "production-grade Godot MCP service"

to:

- "an agent-ready Godot development bridge that aims to let ordinary people build games with Codex-style assistants"

The first phrase should remain true, but the second phrase should become the larger story.
