# Error Handling

> How backend failures are surfaced to MCP clients.

---

## Overview

Raw exceptions should not cross the MCP boundary for expected operational
failures. Backend code should convert failures into structured, client-readable
tool responses wherever the SDK surface allows it.

---

## Error Handling Patterns

- Tool handlers should return structured failure results for:
  - bad input
  - missing files
  - missing Godot editor/plugin
  - unsupported Godot version
  - failed plugin/editor operations
- Unexpected process-level failures may still terminate the process, but only
  after logging to stderr.
- Failure messages should be actionable, not just technically correct.

---

## MCP Error Responses

When a tool fails, the response should:

- clearly state what failed
- distinguish validation failures from runtime failures
- include recovery hints when possible

Examples of useful recovery hints:

- confirm Godot 4.6.x is installed
- confirm the editor plugin is enabled
- confirm the target path points to a real Godot project
- confirm the editor/plugin connection is available

---

## Common Mistakes

- throwing generic exceptions for routine validation failures
- emitting vague messages like `Unknown error`
- returning success-shaped payloads for failed operations
- writing operational diagnostics to stdout instead of stderr
