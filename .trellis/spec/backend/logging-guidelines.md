# Logging Guidelines

> How logging is done in this project.

---

## Overview

This project runs an MCP server over stdio. That makes logging discipline
non-negotiable:

- `stdout` is reserved for MCP transport traffic
- operational diagnostics belong on `stderr`
- plugin-facing success payloads belong in structured MCP tool results, not logs

The scaffold currently relies on platform logging primitives such as
`console.error()` for failure reporting. If a dedicated logger is introduced
later, it must preserve the same channel separation.

---

## Log Levels

- `debug`
  - local development tracing only
  - should stay sparse and easy to disable
- `info`
  - process lifecycle milestones
  - install/setup milestones
- `warn`
  - recoverable runtime problems
  - unsupported or degraded-but-survivable states
- `error`
  - failed startup
  - failed tool execution because of server/editor-side runtime issues
  - uncaught or terminating failures

---

## Structured Logging

Logs should remain compact and human-readable. Include enough context to debug
an issue without leaking sensitive or high-volume payloads.

Preferred fields when context is needed:

- operation or tool name
- target project or resource identifier
- failure category
- short recovery hint

Avoid dumping whole request bodies, full file contents, or large editor payloads.

---

## What to Log

- server startup and shutdown failures
- validation failures that indicate incorrect caller usage patterns
- editor/plugin connection failures
- unsupported Godot version detection
- write operation failures or rollback failures
- install/setup failures affecting plugin deployment or activation guidance

---

## What NOT to Log

- MCP transport payloads on `stdout`
- secrets, tokens, or local credential material
- full project file contents unless a user explicitly requests diagnostic dumps
- noisy per-frame or per-node editor spam that obscures actionable failures
- success-path chatter for routine operations that already return structured MCP results

---

## Real examples in this repository

- [src/index.ts](/E:/code/AI-godot-mcp/src/index.ts)
  is the current thin process entrypoint, so any future diagnostics added here
  must keep stdout clean for MCP transport.
- [src/server/startServer.ts](/E:/code/AI-godot-mcp/src/server/startServer.ts)
  is the stdio transport boundary that makes stdout/stderr separation
  non-negotiable.
- [src/server/createServer.ts](/E:/code/AI-godot-mcp/src/server/createServer.ts)
  is the current server-construction boundary where future operational logging
  should stay compact and avoid dumping transport payloads.
