# Real Editor Runtime Log Capture And Diagnostics

## Goal

Implement the first truly reliable debug-feedback loop for `AI-godot-mcp`, so an agent can:

1. run the current scene
2. fetch real runtime/editor diagnostics after the run starts
3. distinguish basic lifecycle events from runtime failures
4. use those diagnostics to continue debugging instead of guessing

This task is the first implementation follow-up to the readiness assessment in:

- `.trellis/tasks/06-23-ai-godot-mcp-agent-readiness-prd/prd.md`

## What I Already Know

- The current implementation already exposes:
  - `play_current_scene`
  - `stop_running_scene`
  - `get_editor_logs`
- Those tools currently do not provide a real runtime feedback loop.
- The current plugin-side log buffer is mostly synthetic:
  - scene start
  - scene stop
  - placeholder hook for future capture
- The archived Phase 4 design docs originally considered Output panel interception and other speculative approaches.
- Official Godot documentation provides a more concrete basis for this task:
  - when running a project from the editor, logged text is displayed in the Output panel
  - Godot also writes built-in file logs to `user://logs/godot.log` by default on desktop
  - file logging path and enablement are configurable by project settings
  - since Godot 4.5, GDScript errors include script backtraces in editor/debug contexts, and those backtraces are also logged to the session log file

## Problem Statement

The repository already supports scene execution commands, but it still lacks a dependable source of post-run diagnostics. As a result:

- agents can run a scene but cannot reliably inspect real failures afterward
- `get_editor_logs` overpromises and underdelivers
- developers cannot trust the MCP loop for iterative Godot debugging

The critical gap is not "more tools." The gap is "real signal after execution."

## Decision

Implement runtime diagnostics by tailing Godot's built-in file log from the editor plugin, then exposing those ingested lines through `get_editor_logs`.

### Why This Approach

- It uses an official Godot logging mechanism rather than undocumented editor internals.
- It does not require invasive script rewriting or patching user gameplay code.
- It can surface:
  - `print()` output in debug/editor runs
  - `printerr()` / `push_error()` / `push_warning()` output
  - script backtraces written by the engine
  - crash/backtrace evidence available in log files
- It is substantially more realistic than the current placeholder buffer.

### Explicit Non-Decision

This task will **not** implement full Output panel interception or a custom runtime debugger protocol. Those remain possible future upgrades if file-tail diagnostics prove insufficient.

## Scope

### In Scope

- plugin-side runtime log path resolution based on Godot project settings
- plugin-side log tailing of the current session log file
- ingestion of new log lines into `_log_buffer`
- simple severity classification for ingested lines
- scene lifecycle diagnostics around `play_current_scene` / `stop_running_scene`
- actionable warnings when file logging is disabled or unavailable
- updated task/test artifacts as needed to verify the change without a live editor by default

### Out Of Scope

- full editor Output panel introspection
- WebSocket log streaming / push mode
- custom logger/autoload injection into user projects
- debugger protocol integration
- connection management hardening unrelated to log capture
- global cleanup of all Phase 4 documentation drift

## Requirements

### Functional Requirements

#### 1. Real runtime log source

The plugin must resolve the runtime log path using Godot project settings:

- prefer `debug/file_logging/log_path` when set
- otherwise fall back to the default desktop path under `user://logs/godot.log`

#### 2. Incremental log ingestion

The plugin must track an offset into the current log file and ingest only newly appended content.

#### 3. Buffer behavior

`get_editor_logs` must return a merged buffer that includes:

- runtime file-log entries
- scene lifecycle entries produced by the plugin
- existing timestamp/level/source shape

#### 4. Severity and source

Each ingested log entry must still expose:

- `timestamp`
- `level`
- `message`
- `source`

`source` should continue distinguishing at least:

- `runtime`
- `editor`

#### 5. Scene-run diagnostics

`play_current_scene` should provide enough context to make subsequent log pulls meaningful:

- scene path
- running status
- whether runtime log capture is expected to work
- warning/suggestion when file logging is disabled or the log path cannot be resolved

#### 6. Query behavior

`get_editor_logs` must continue supporting:

- `since_timestamp`
- `filter_level`

and should poll/import new runtime log content before filtering and returning results.

### Quality Requirements

- keep MCP stdout clean
- preserve backward-compatible tool names
- avoid invasive project mutation
- do not invent "successful" diagnostics when runtime log capture is unavailable

## Implementation Plan

### Plugin layer

- add runtime-log state fields to `websocket_server.gd`
- resolve and normalize the log path
- reset cursor state before or during `play_current_scene`
- poll/tail newly appended log text
- split lines safely, handling partial trailing lines
- classify lines by severity heuristics
- append normalized entries into `_log_buffer`

### Backend layer

- keep existing tool names stable
- only change Node-side behavior if response payload needs minor enrichment for diagnostics

### Verification

- `npm run build`
- targeted Node tests
- integration script remains manual or opt-in unless the default suite is updated to skip gracefully when Godot/plugin is absent

## Acceptance Criteria

- [ ] Running `play_current_scene` records a truthful lifecycle event and indicates whether runtime log capture is available.
- [ ] `get_editor_logs` ingests new lines from the runtime log file instead of returning only synthetic buffer entries.
- [ ] Runtime log entries are returned with `timestamp`, `level`, `message`, and `source`.
- [ ] `get_editor_logs({ since_timestamp, filter_level })` still works after runtime-file ingestion is added.
- [ ] If file logging is disabled or the log file cannot be opened, the caller receives an actionable signal instead of silent success theater.
- [ ] The repository still builds successfully after the change.
- [ ] Verification commands do not rely on a live Godot editor by default, or the remaining limitation is explicitly isolated and documented.

## Risks

### Log flush timing

Official docs note that `print()` flush behavior depends on build mode. In editor/debug workflows this is acceptable, but it may still introduce slight delays between scene execution and visible stdout-derived log lines.

### Log format variability

Godot's log lines are not guaranteed to match one rigid format. Severity classification will therefore be heuristic-based and must prefer robustness over overfitting.

### Cross-session ambiguity

The built-in log file is session-based and rotated. This task should focus on the current active session and not attempt historical log archaeology beyond what is needed for crash evidence.

## Technical Notes

### Files likely to change

- `addons/ai_godot_mcp/websocket_server.gd`
- `README.md` or `docs/README_zh.md` only if behavior text must be minimally corrected
- test scripts only if required to keep local verification meaningful

### Research references

- Godot stable logging docs:
  - built-in file logging default path and settings
  - script backtraces in file logs
  - custom logger support (future option, not current implementation)
