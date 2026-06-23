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

## Scenario: Runtime Log Capture Via Built-In File Logging

### 1. Scope / Trigger

- Trigger: `play_current_scene`, `stop_running_scene`, and `get_editor_logs`
  together define a cross-layer diagnostics contract between the Godot plugin
  layer and MCP callers.
- Trigger: plugin runtime state now includes a file-log cursor and degraded
  availability state, so future changes must preserve both the internal state
  model and the caller-visible contract.

### 2. Signatures

- Plugin-side handlers:
  - `handle_play_scene(req: Dictionary) -> Dictionary`
  - `handle_stop_scene(req: Dictionary) -> Dictionary`
  - `handle_get_logs(req: Dictionary) -> Dictionary`
- Plugin-side helper/state boundaries:
  - `_refresh_runtime_log_config() -> void`
  - `_reset_runtime_log_cursor() -> void`
  - `_poll_runtime_log() -> void`
  - `_get_runtime_log_capture_status() -> Dictionary`

### 3. Contracts

- Project settings read by the plugin:
  - `debug/file_logging/enable_file_logging`
  - `debug/file_logging/log_path`
- Runtime log fallback path:
  - `user://logs/godot.log`
- `play_current_scene` success payload must include:
  - `scene_path: string`
  - `status: "running"`
  - `log_capture: Dictionary`
- `stop_running_scene` success payload must include:
  - `stopped: bool`
  - `log_capture: Dictionary`
- `get_editor_logs` success payload must include:
  - `logs: Array[Dictionary]`
  - `log_capture: Dictionary`
- `log_capture` must include:
  - `mode`
  - `enabled`
  - `available`
  - `log_path`
  - `message`
  - `suggestions`
- Log entries returned to callers must include:
  - `timestamp`
  - `level`
  - `message`
  - `source`

### 4. Validation & Error Matrix

- file logging disabled -> return success payload with `log_capture.enabled=false`
  and actionable enablement guidance; do not fake runtime log availability
- log path unresolved -> return success payload with degraded `log_capture`
  state and guidance; do not emit empty-success theater
- log file missing before first run -> degraded `log_capture` message is allowed
- log file open fails -> preserve error text in `log_capture.message`
- scene not open -> `play_current_scene` must still fail with explicit
  `NO_SCENE`
- log polling must tolerate:
  - file truncation/rotation
  - partial trailing lines
  - no new content

### 5. Good / Base / Bad Cases

- Good:
  - scene starts, log file exists, new lines are tailed, and `get_editor_logs`
    returns runtime entries plus `log_capture.available=true`
- Base:
  - scene starts but log file is not created yet; caller still receives a
    truthful `log_capture` status and can retry later
- Bad:
  - plugin returns `logs: []` with no degraded state even though runtime log
    capture is disabled or unavailable

### 6. Tests Required

- Source-level regression proving the plugin references:
  - `debug/file_logging/enable_file_logging`
  - `debug/file_logging/log_path`
  - `user://logs/godot.log`
- Source-level regression proving runtime diagnostics helpers exist:
  - `_poll_runtime_log`
  - `_get_runtime_log_capture_status`
  - `log_capture` in success payloads
- Integration/manual validation:
  - start scene in Godot 4.6.x
  - call `get_editor_logs`
  - confirm runtime output/backtrace lines appear
  - confirm disabled/missing log-file states are surfaced honestly

### 7. Wrong vs Correct

#### Wrong

- assuming editor Output panel interception is the primary contract without a
  stable API boundary
- returning only synthetic start/stop messages and calling that runtime logging
- clearing degraded state before it can be returned to the caller

#### Correct

- use built-in file logging as the first supported runtime diagnostics source
- treat runtime log availability as explicit plugin state
- return actionable degraded `log_capture` metadata whenever runtime diagnostics
  are unavailable or incomplete

---

## Real examples in this repository

- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
  currently keeps only one piece of plugin-owned state, `_dock_instance`,
  on the plugin object itself and clears it explicitly on teardown.
- [tests/scaffold.test.js](/E:/code/AI-godot-mcp/tests/scaffold.test.js)
  is the scaffold-level verification anchor that the plugin boundary remains in
  place while runtime state is intentionally small.
