# Quality Guidelines

> Code quality standards for the Node MCP server layer.

---

## Required Patterns

- TypeScript must remain `strict`.
- Use ESM imports consistently.
- Keep process entrypoints thin.
- Keep MCP server creation and transport bootstrap separate.
- Add JSDoc for non-trivial exported functions and boundaries.
- Preserve the separation between:
  - process bootstrap
  - tool registration
  - validation
  - install workflow

---

## Forbidden Patterns

- rebuilding the legacy one-file backend architecture
- mixing shell command construction with user input
- treating path-like inputs as class names or vice versa
- adding tool handlers without corresponding validation
- polluting stdout with diagnostic logs

---

## Testing Requirements

- `npm run build` must pass
- `npm test` must pass
- add targeted tests when new backend boundaries appear
- for safety-sensitive behavior, validate the guardrail before validating the happy path

---

## Code Review Checklist

- Is the new backend code in the correct module boundary?
- Are client-supplied paths validated?
- Are client-supplied Godot types validated?
- Does the code keep stdout clean for MCP transport use?
- Is the new behavior covered by at least build/test verification?

---

## Real examples in this repository

- [src/index.ts](/E:/code/AI-godot-mcp/src/index.ts)
  is the expected thin bootstrap entrypoint.
- [src/server/createServer.ts](/E:/code/AI-godot-mcp/src/server/createServer.ts)
  is the current example of exported backend logic living in the server module.
- [src/install/index.ts](/E:/code/AI-godot-mcp/src/install/index.ts)
  preserves a separate install workflow boundary instead of mixing install
  concerns into the MCP server path.
