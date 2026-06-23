# AI-godot-mcp Agent Readiness Assessment And Gap-Closure Plan

## Goal

Assess whether the current `AI-godot-mcp` repository already satisfies the design goal:

> "用于开发者使用 claude code / codex 等智能体来开发 Godot 游戏使用"

Then convert that assessment into a concrete, prioritized product plan that can guide the next implementation tasks. The outcome of this task is not code delivery. The outcome is a repo-backed PRD that distinguishes what already works, what is still missing, what is misleading in the current product surface, and what should be implemented first if the project is meant to become a reliable agent-facing Godot development tool.

## What I Already Know

- The repository positions itself as a production-grade Godot MCP service for AI-driven game development in `README.md`.
- The product architecture is Node MCP server over stdio plus a Godot `EditorPlugin` communicating over local WebSocket on port `6550`.
- The current MCP surface includes project inspection, scene editing, transaction APIs, script attachment, scene execution, and CLI install/uninstall/version commands.
- The current backend implementation lives in:
  - `src/server/createServer.ts`
  - `src/server/editorConnection.ts`
  - `src/server/startServer.ts`
- The current Godot plugin implementation lives in:
  - `addons/ai_godot_mcp/plugin.gd`
  - `addons/ai_godot_mcp/websocket_server.gd`
- Current tests are primarily lightweight build/shape checks plus a manual integration script:
  - `tests/server.test.js`
  - `tests/scaffold.test.js`
  - `src/server/*.test.ts`
  - `test-p0.mjs`
- Local validation performed during assessment:
  - `npm run build` passed.
  - `npm test` failed because `test-p0.mjs` expects a live Godot editor + enabled plugin and currently runs as part of the default test suite.

## Current Assessment

### Headline Judgment

The project does **not yet fully satisfy** the design goal as a dependable developer tool for agent-driven Godot game development.

Current status is better described as:

- a credible architectural MVP
- a partially working editor bridge
- not yet a stable end-to-end development platform for Claude Code / Codex style agent workflows

### What Already Supports The Design Goal

- There is a real MCP server entrypoint for agent clients.
- There is a real Godot editor plugin boundary rather than a purely headless script model.
- Core game-development-oriented capabilities are present in some form:
  - read project context
  - inspect current scene tree
  - create scenes
  - add/delete nodes
  - set properties
  - attach scripts
  - run/stop current scene
- There is at least an intended rollback model through `begin_ai_action` / `end_ai_action` and `EditorUndoRedoManager`.
- There is a packaging/distribution path via npm CLI commands.

### Why It Is Not Yet Good Enough

#### 1. The debug feedback loop is not real yet

The most important missing capability for an agent-oriented Godot development workflow is trustworthy feedback after a change. Right now:

- `get_editor_logs` returns only an internal memory buffer, not actual editor/runtime output.
- the log capture hook is mostly placeholder code
- the buffer is currently populated only by synthetic `play/stop` messages

This means agents can mutate scenes and start scenes, but they cannot reliably see the real compile/runtime/editor failures needed to continue debugging.

#### 2. The documented product surface is ahead of the implementation

There are multiple places where README/product claims overstate the real implementation:

- `get_scene_tree` documentation promises depth limit and type filtering, but MCP-side input currently exposes neither of those in a validated schema.
- plugin-side scene serialization uses only depth, not type filtering.
- `attach_script` documentation promises automatic template generation, but actual implementation only attaches an already-existing `.gd` file and fails otherwise.

This is risky for agent-facing tooling because the client prompt and tool contract become unreliable.

#### 3. Tool responses are not optimized for agent consumption

Tool handlers currently stringify result payloads into plain text content instead of returning richer structured responses. That is acceptable for a prototype but weaker than desired for reliable multi-step agent orchestration.

#### 4. Connection state and operational diagnostics are underdeveloped

- backend startup swallows initial connection failures
- the plugin dock shows `Status: Connected` as static text rather than true connection state
- request history UI exists only as empty scaffolding
- the system provides weak visibility into whether the editor bridge is healthy, degraded, or disconnected

For human developers working with agents, this makes failures ambiguous and increases time spent guessing whether the problem is in Codex/Claude, MCP transport, WebSocket, plugin state, or Godot runtime.

#### 5. Test strategy does not yet prove product readiness

The current tests mostly verify existence of objects or files, not the critical gameplay-development workflow:

- inspect current project
- inspect scene
- mutate scene
- attach valid/invalid script
- run scene
- receive real errors/logs
- rollback failed multi-step action

The default `npm test` suite also currently includes a live-editor-dependent script, which causes a false-negative local readiness signal unless a manual runtime environment is already prepared.

#### 6. Product metadata is inconsistent

Repository/package metadata says `1.0.2`, while MCP server/plugin metadata still report `0.1.0`. That weakens release confidence and makes debugging compatibility questions harder.

## Product Requirements

### Primary Product Position

`AI-godot-mcp` should become a tool that lets developers use Claude Code, Codex, and similar coding agents to iteratively build Godot games with a reliable editor-in-the-loop workflow.

### Core Workflow The Product Must Support

The minimum viable agent workflow is:

1. connect to the running Godot editor deterministically
2. inspect project and current scene state
3. mutate scene structure and node properties safely
4. attach scripts or reference scripts safely
5. run the scene
6. observe real execution/editor feedback
7. repair based on that feedback
8. rollback or recover cleanly when a multi-step edit fails

If any one of these steps is unreliable, the overall developer-agent workflow is unreliable.

### Non-Negotiable Product Qualities

- tool contract must match implementation
- connection status must be observable by both agent and developer
- failure modes must be explicit, actionable, and debuggable
- default tests must reflect actual repository health
- scene mutation safety must remain stricter than generic file editing

## Prioritized Gap-Closure Plan

### P0: Establish A Real Debug/Feedback Loop

This is the highest priority because without it the product cannot reliably support iterative game development by an agent.

Scope:

- make `get_editor_logs` return real editor/runtime/script error output rather than synthetic buffer entries
- define what "logs" means:
  - editor output
  - runtime errors
  - script load/parse failures
  - scene run/stop events
- ensure play/run failures are visible to the MCP caller in a machine-usable way
- define the retention/filtering rules clearly

### P1: Align Product Contract With Reality

Scope:

- either implement or remove mismatched README claims
- make `get_scene_tree` support the documented parameters or reduce the promise
- make `attach_script` behavior explicit:
  - attach-existing-script only
  - or generate template when missing
- review all tool descriptions for exact behavioral accuracy

### P1: Improve Agent-Facing Response Quality

Scope:

- reduce reliance on JSON-as-text when practical
- ensure errors consistently include stable codes and useful suggestions
- make transaction/rollback outcomes explicit enough for downstream agent reasoning

### P1: Make Connection State Observable

Scope:

- stop swallowing initial connection failures silently
- expose connection state clearly in MCP responses
- make plugin dock status truthful
- decide whether request history is a real feature or should be removed until implemented

### P2: Fix Default Verification Strategy

Scope:

- keep fast deterministic unit tests in default `npm test`
- move live Godot editor checks into opt-in integration tests
- add scenario-driven tests around:
  - tool registration
  - request validation
  - connection loss behavior
  - error propagation
  - CLI validation behavior

### P2: Clean Up Release/Metadata Consistency

Scope:

- unify version numbers across package, MCP server, and plugin metadata
- review compatibility messaging for Godot 4.6.x
- confirm install/version output matches the real release line

## Acceptance Criteria

- [ ] The PRD clearly states that current repo status is "promising MVP, not yet fully design-complete."
- [ ] The PRD distinguishes strengths, blocking gaps, and lower-priority polish work.
- [ ] The PRD identifies the debug feedback loop as the first implementation priority.
- [ ] The PRD identifies documentation/implementation drift as a blocking trust issue.
- [ ] The PRD captures the current testing weakness, including the `npm test` failure mode with live-editor-dependent test coverage.
- [ ] The PRD is actionable enough to split into follow-up implementation tasks without redoing the initial repo assessment.

## Definition Of Done

- A Trellis task exists for this assessment.
- The task contains a repo-backed `prd.md`.
- The PRD can serve as the canonical planning input for follow-up implementation tasks.
- The task has enough context seeded that a later implementation task can reference the relevant specs.

## Out Of Scope

- Implementing the fixes described by this PRD
- Refactoring current MCP responses in this task
- Changing test code in this task
- Archiving or resolving older task history

## Technical Notes

### Files inspected during assessment

- `README.md`
- `docs/README_zh.md`
- `package.json`
- `src/index.ts`
- `src/server/createServer.ts`
- `src/server/editorConnection.ts`
- `src/server/startServer.ts`
- `src/cli/index.ts`
- `src/cli/install.ts`
- `src/cli/uninstall.ts`
- `src/cli/validate.ts`
- `src/cli/version.ts`
- `addons/ai_godot_mcp/plugin.cfg`
- `addons/ai_godot_mcp/plugin.gd`
- `addons/ai_godot_mcp/websocket_server.gd`
- `tests/server.test.js`
- `tests/scaffold.test.js`
- `src/server/createServer.test.ts`
- `src/server/editorConnection.test.ts`
- `test-p0.mjs`

### Evidence snapshots from the assessment

- MCP server currently registers the expected high-level tools, but returns stringified JSON payloads.
- `conn.connect().catch(() => {})` suppresses startup connection errors in the backend.
- Godot plugin log capture has placeholder hooks and does not yet represent a real debug stream.
- Plugin dock UI is largely static scaffold.
- Default test suite currently depends on a manual Godot runtime path through `test-p0.mjs`.

### Recommended follow-up task split

1. Real editor/runtime log capture and scene-run diagnostics
2. Tool contract alignment (`README` vs implementation)
3. Connection state / dock observability hardening
4. Test suite restructuring
5. Version and release metadata cleanup
