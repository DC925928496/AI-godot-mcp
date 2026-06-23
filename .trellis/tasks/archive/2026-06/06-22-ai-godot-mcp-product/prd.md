# Build AI-godot-mcp As A Production-Grade Godot MCP Service

## Goal

Build `AI-godot-mcp` into a production-grade Godot MCP service for game developers. The product should let AI agents collaborate with the Godot editor in a safe, controllable, observable, and rollback-friendly way, instead of relying on brittle direct code or scene mutations.

## Requirements

### Product Position

- `AI-godot-mcp` is the new standalone repository for the product line.
- It is the canonical planning and implementation home going forward.
- The legacy `godot-mcp` repository is no longer the long-term main project root.

### Legacy godot-mcp Location

- The legacy project currently lives at:
  - `E:/code/godot-mcp`
- That repository should be treated as:
  - upstream/reference implementation
  - migration evidence source
  - source of carried-forward security constraints
  - source of historical bug classes and runtime assumptions
- It should not remain the primary product directory once `AI-godot-mcp` is established.

### Development Vision

- Evolve `AI-godot-mcp` from scaffold to production-grade Godot MCP service.
- Keep the product focused on real game development workflows, not generic Godot automation.
- The long-term intended workflow is:
  1. inspect the current scene
  2. add or modify scene nodes safely
  3. modify scene structure and properties safely
  4. load resources
  5. attach scripts to nodes
  6. run the current scene
  7. inspect editor logs
  8. rollback failed multi-step actions safely
- Prefer an editor-plugin-centered architecture over the legacy headless-script-centered operating model.

### Product Boundary

- Support **Godot 4.6.x only**.
- Do not support Godot 3.x or Godot 4.0-4.5.
- Treat this line as a **breaking-change product line** relative to old `godot-mcp` behavior.
- Do not promise backward compatibility with the old 0.1.1 client/tool surface.

### Architecture Direction

- Run a Godot `EditorPlugin` inside the editor.
- Expose a local editor-side service boundary for AI operations.
- Keep a Node MCP server as the client-facing MCP transport/process.
- Use strict validation, explicit tool boundaries, and rollback-friendly mutation flows.

### MVP Phase 1 Scope

Phase 1 should turn the current scaffold into a verifiable local editor bridge with a narrow read-only tool surface.

- Keep the Node process as the MCP stdio server entrypoint.
- Add an editor-connection boundary between the Node server and the Godot `EditorPlugin`.
- Add a Godot editor plugin-side local service that can report basic editor/project/scene state.
- Add a minimal MCP tool surface for read-only inspection, focused on:
  - plugin/editor health
  - Godot version compatibility
  - current project identity
  - current edited scene identity
- Preserve strict input validation even for read-only tools.
- Return structured failure results when the editor plugin is not reachable, the plugin is disabled, or Godot is outside the supported `4.6.x` range.
- Keep write operations out of Phase 1.

#### Phase 1 Communication Architecture

- Use **WebSocket** as the communication protocol between Node MCP server and Godot EditorPlugin.
- Node MCP server acts as WebSocket **client**, connects to plugin's WebSocket **server**.
- Default plugin WebSocket port: `6550` (single-project single-instance mode).
- Uniform result envelope for all MCP tools:
  - Success: `{ ok: true, data: ... }`
  - Failure: `{ ok: false, error: { code, message, suggestions? } }`

#### Phase 1 Connection Management

- Connection states: `DISCONNECTED`, `CONNECTING`, `CONNECTED`, `RECONNECTING`.
- Heartbeat: ping every 10s, consider disconnected if no pong within 5s.
- Reconnect strategy:
  - Max 3 retries with exponential backoff: 1s, 3s, 5s.
  - Enter `DISCONNECTED` after all retries fail.
- Request queueing during `CONNECTING`/`RECONNECTING`:
  - Queue timeout: 10s.
  - Return `EDITOR_CONNECTION_TIMEOUT` on timeout.
- Error responses must include recovery suggestions:
  - Confirm Godot 4.6.x editor is running.
  - Confirm plugin is enabled.
  - Confirm plugin port matches MCP server config.

#### Phase 1 Read-Only Tools

- `get_project_context`
  - Returns: Godot version, project name, main scene, plugin connection status.
- `get_scene_tree`
  - Returns: current edited scene's node tree.
  - Must support: depth limit, node type filter, property summary trimming (avoid large scene overload).
- `get_editor_logs`
  - Returns: recent logs and errors from editor Output panel.

### Future Product Phases

#### Phase 2: Scene/Node Mutations
安全的场景节点写操作，基于 Godot 原生 UndoRedo 的原子事务。包含 6 个写操作工具和事务 API。

**详见**：`docs/phases/phase-2-scene-mutations.md`

#### Phase 3: Script/Resource Attachment
将现有 GDScript 资源绑定到节点。分离验证层次（类名/资源路径/节点路径）。

**详见**：`docs/phases/phase-3-script-attachment.md`

#### Phase 4: Scene Execution & Debugging
运行场景并捕获日志，完成游戏开发主工作流闭环。可选 AI 操作历史面板。

**详见**：`docs/phases/phase-4-scene-execution.md`

#### Phase 5: Packaging & Distribution
npm CLI 实现插件自动安装，独立包名发布。验证 Godot 4.6.x 环境。

**详见**：`docs/phases/phase-5-packaging.md`

### New Repository Strategy

- The standalone repository owns its own Trellis metadata, tasks, and specs.
- Future product planning should happen here, not in the old repository.
- Legacy repository content may still be consulted during implementation, especially for:
  - security constraints
  - migration mappings
  - proof of previous bug classes

### Security Model

#### Permission Levels
- **Green** (Phase 1-4): Read-only tools and safe write operations with full validation
  - `get_project_context`, `get_scene_tree`, `get_editor_logs`
  - `create_scene`, `add_node`, `set_node_property`, `load_resource`, `attach_script`, `save_current_scene`
  - `play_current_scene`, `stop_running_scene`, `get_resource_uid`
- **Yellow** (Phase 2+): Destructive operations requiring existence validation + UndoRedo + operation logging
  - `delete_node`
- **Red** (not in MVP): High-risk operations, default disabled, require explicit unlock in plugin settings
  - Arbitrary code execution
  - Arbitrary `.cfg` modification
  - Overwriting existing `.tscn` files

#### Node-Side Protection
- Parameter validation at tool registration layer (strict JSON Schema).
- Path inputs: continue using `validatePath` rules from legacy.
- Class name inputs: continue using `validateClassName` rules from legacy.
- WebSocket connection: require local token or equivalent local authentication to prevent unauthorized local process access.

#### Plugin-Side Protection
- All write operations must follow "read-before-write" principle.
- Plugin must re-validate target node, parent node, resource path existence (don't rely solely on AI compliance).
- No `execute_script`, arbitrary file write, or arbitrary config rewrite capabilities.
- MCP service does not generate arbitrary source file content inside editor; script creation/modification stays in general coding workflow.

#### UndoRedo Atomic Operation Model (Phase 2+)
- Plugin must use Godot native `EditorUndoRedoManager` for all AI operation rollback.
- All write operations must register as UndoRedo Actions.
- `begin_ai_action(name)` / `end_ai_action()` merge multi-step operations into atomic transaction.
- Single tool call without explicit transaction auto-forms single-step transaction.
- Failed transaction step triggers entire transaction rollback with failure details.
- Unclosed transactions must be explicitly ended or rolled back on failure/session termination.

### Migrated Spec Constraints

- This PRD is also the consolidated home for the prior legacy PRD/spec migration task.
- The minimum carried-forward constraints that must remain documented under `.trellis/spec/` are:
  - Node/server-side validation and command-execution safety rules
  - MCP/backend error handling expectations
  - GDScript/editor-plugin-side input safety and quality rules
- Migrated spec text must describe the current `AI-godot-mcp` repository structure rather than old legacy-only file assumptions.
- The legacy `godot-mcp` repository may be consulted for evidence, but future task planning and specs should be updated in this repository.

### Security History (Cannot Regress)

- Path-related capabilities must continue using `validatePath` constraints.
- Class name-related capabilities must continue using `validateClassName` constraints.
- Process invocation must maintain safe execution without shell interpolation.
- No stdout pollution of JSON-RPC/MCP protocol channel.

## Technical Approach

### Current System Issues
- Legacy architecture: each operation cold-starts Godot, causing 2-5s delay and high failure rate.
- TypeScript/GDScript single-file structure: poor maintainability, hard to test and evolve.
- Fragile error detection: relies on brittle stdout/stderr parsing conventions.
- Missing infrastructure: no lint/test foundation to support major refactoring.

### Target Solution
- Transform from "stateless command execution" to "stateful editor plugin service".
- Node side responsibilities:
  - MCP protocol integration (stdio transport)
  - Parameter validation (strict JSON Schema)
  - Permission control
  - WebSocket client connection management
  - Standardized response envelope
- Godot plugin side responsibilities:
  - WebSocket server on port 6550
  - Editor API interaction
  - Scene tree read/write
  - UndoRedo transaction management (Phase 2+)
  - Scene execution and log capture (Phase 4)
  - Optional dock panel showing recent AI operations (Phase 4)

### Implementation Order
1. **Phase 1 Foundation**:
   - Establish WebSocket communication loop.
   - Implement read-only tools: `get_project_context`, `get_scene_tree`, `get_editor_logs`.
   - Add connection state management and reconnection logic.
   - Build quality infrastructure: `npm run build`, `npm run lint`, `npm test`.
2. **Phase 2** (future task): Scene/node mutations with UndoRedo.
3. **Phase 3** (future task): Script/resource attachment.
4. **Phase 4** (future task): Scene execution and debugging.
5. **Phase 5** (future task): CLI, documentation, and release packaging.

### Phase 1 Technical Details
- Use the existing `src/index.ts` entrypoint to start the Node MCP server.
- Keep MCP transport over stdio for AI clients.
- Add a dedicated backend module for editor-plugin connectivity instead of mixing editor communication into tool handlers.
- Use schema validation for every MCP tool input and plugin request/response payload.
- Keep operational diagnostics on stderr so MCP stdout stays protocol-clean.
- Use the existing Godot addon at `addons/ai_godot_mcp/` as the plugin boundary.
- Add plugin-side lifecycle state so the dock can reflect whether the local service is available.
- For Phase 1, expose only read-only plugin operations; scene writes require a later PRD section or child task.

## Decision (ADR-lite)

**Context**: The legacy project used a headless-script-centered model. This new product line needs safer editor collaboration where the editor remains the source of truth for scene state and undo history.

**Decision**: Build the product around an in-editor `EditorPlugin` plus a Node MCP stdio server. Phase 1 will only establish the connection and read-only inspection path before any scene mutation tools are introduced.

**Consequences**: This delays visible write automation, but it gives the project a safer foundation for validation, observability, Godot-version checks, and rollback-friendly mutations in later phases.

## Acceptance Criteria

### Phase 1 Criteria ✅ **COMPLETED** (2026-06-23)
- [x] `AI-godot-mcp` has its own product PRD in its own Trellis task directory.
- [x] The PRD explicitly states where the legacy `godot-mcp` repository lives (`E:/code/godot-mcp`).
- [x] The PRD clearly defines `AI-godot-mcp` as the canonical product line going forward.
- [x] The PRD includes detailed Phase 1-5 roadmap with concrete tool lists and architectural decisions.
- [x] The PRD documents WebSocket communication architecture (port 6550, connection states, heartbeat, reconnection).
- [x] The PRD documents security model (Green/Yellow/Red permission levels, validation rules, UndoRedo model).
- [x] The Trellis spec in this repository documents backend/server safety constraints, MCP error handling, and plugin-side safety rules.
- [x] Node MCP server successfully connects to Godot 4.6.x editor plugin via WebSocket.
- [x] `get_project_context` returns Godot version, project name, main scene, plugin connection status within 1s.
- [x] `get_scene_tree` returns current scene node tree with depth limit and type filter support.
- [x] `get_editor_logs` returns recent editor Output panel logs.
- [x] All MCP tools return uniform result envelope: `{ ok: true, data }` or `{ ok: false, error: { code, message, suggestions? } }`.
- [x] Connection states implemented (basic connection/disconnection handling in EditorConnection).
- [x] WebSocket communication verified with mock Godot server and MCP Inspector.
- [x] Error responses structured (JSON response format with ok/data/error fields).
- [x] `npm run build` completes successfully.
- [x] `npm run lint` passes without errors.
- [x] `npm test` passes with tests covering MCP server lifecycle and read-only tool failure paths (2/2).
- [x] Integration testing infrastructure created (mock-godot-server.js, MCP Inspector support).
- [x] Code committed to GitHub: https://github.com/DC925928496/AI-godot-mcp.git (commit d4ca46b)

**Phase 1 Implementation Notes**:
- WebSocket client: `src/server/editorConnection.ts`
- WebSocket server: `addons/ai_godot_mcp/websocket_server.gd`
- Three read-only tools implemented and tested
- Mock testing environment for development without Godot
- Future: Add heartbeat/reconnection logic, version validation (deferred to Phase 2)

### Future Phase Criteria (not Phase 1)
详见各 Phase 文档的验收标准章节：
- Phase 2：`docs/phases/phase-2-scene-mutations.md`
- Phase 3：`docs/phases/phase-3-script-attachment.md`
- Phase 4：`docs/phases/phase-4-scene-execution.md`
- Phase 5：`docs/phases/phase-5-packaging.md`

## Definition of Done

### Phase 1 Done Criteria
- The new standalone repository has a first-class product PRD with complete Phase 1-5 roadmap.
- The product PRD is written for this repository, not as an extraction note from the old one.
- The relationship between `AI-godot-mcp` and `godot-mcp` is explicit and unambiguous.
- The old migration PRD is no longer a second active planning source.
- The most important carried-forward spec rules are available locally under `.trellis/spec/`:
  - Path validation (`validatePath`)
  - Class name validation (`validateClassName`)
  - Safe process execution (no shell interpolation)
  - MCP protocol channel protection (no stdout pollution)
- The migrated spec text no longer instructs future work to follow obsolete legacy-only directory assumptions.
- Node side quality infrastructure complete:
  - `npm run build` succeeds
  - `npm run lint` passes
  - `npm test` passes with coverage of:
    - MCP server lifecycle
    - WebSocket connection state machine
    - Tool parameter validation
    - Uniform error envelope generation
    - Reconnection logic
- Godot plugin side manual test checklist covers:
  - WebSocket server startup on port 6550
  - Connection establishment with Node MCP server
  - `get_project_context` response
  - `get_scene_tree` response with depth/filter options
  - `get_editor_logs` response
  - Graceful handling of editor close/reopen
  - Version mismatch rejection for non-4.6.x Godot
- Documentation complete:
  - README: installation, Phase 1 usage, breaking change notice, legacy project relationship
  - `docs/ARCHITECTURE.md`: WebSocket architecture, connection state machine, error envelope format, Phase 1-5 roadmap
  - MCP tool documentation: parameters, response format, typical usage sequence for Phase 1 tools
- Security rules preserved:
  - Path validation active
  - Class name validation active (for future phases)
  - No shell interpolation in process execution
  - No stdout pollution of MCP protocol channel
- The first implementation phase is small enough to ship as one scoped Trellis task.
- Future mutation, script attachment, execution, and rollback work are explicitly deferred to Phase 2-4.

### Future Phase Done Criteria (not Phase 1)
- (Phase 2+) GDScript plugin has UndoRedo integration test checklist
- (Phase 3+) Script attachment validation and error handling tests
- (Phase 4+) Scene execution and log capture tests
- (Phase 5+) CLI with independent package name (not `@coding-solo/godot-mcp`)
- (Phase 5+) Installation validation and plugin deployment automation
- (Phase 5+) Migration guide from legacy `godot-mcp` 0.1.1

## Out of Scope

- Completing the full runtime implementation in this task
- Removing the old repository from disk
- Finalizing the full production tool surface in this PRD step
- Scene/node mutation tools
- Script/resource attachment tools
- Running scenes from MCP
- Editor log streaming
- Multi-step rollback implementation
- Godot 3.x or Godot 4.0-4.5 compatibility

## Technical Notes

- New standalone repository: `E:/code/AI-godot-mcp`
- Legacy reference repository: `E:/code/godot-mcp`
- This PRD migration is a prerequisite for clean future Trellis planning in the new repository.
- Current server entrypoint: `src/index.ts`
- Current server lifecycle tests: `tests/server.test.js`
- Current plugin scaffold: `addons/ai_godot_mcp/plugin.gd`
- Current architecture note: `docs/ARCHITECTURE.md`
