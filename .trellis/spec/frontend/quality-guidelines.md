# Quality Guidelines

> Code quality standards for the Godot plugin / GDScript layer.

---

## Required Patterns

- Keep editor-plugin code separate from Node MCP server code.
- Preserve safe class instantiation boundaries.
- Preserve explicit success/failure signaling.
- Preserve save/pack verification style for any future scene/resource persistence flow.
- Keep plugin UI scaffolding simple until the editor service contract is real.

---

## Forbidden Patterns

- accepting raw `res://...` paths as class/type identifiers
- silently continuing after failed resource loads
- mixing plugin/editor diagnostics into unclear or ambiguous output channels
- bypassing explicit rollback or validation boundaries for write operations

---

## Testing Requirements

- validate plugin file presence
- keep at least one scaffold-level test proving the plugin boundary exists
- add manual verification steps when editor integration behavior is added

---

## Code Review Checklist

- Does the change preserve the plugin/server boundary?
- Does it keep resource paths and class names separate?
- Does it fail loudly on missing preconditions?
- Does it avoid introducing editor-side behavior that the server cannot safely observe or control?

---

## Real examples in this repository

- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
  is the baseline plugin-boundary example for lifecycle and teardown behavior.
- [tests/scaffold.test.js](/E:/code/AI-godot-mcp/tests/scaffold.test.js)
  is the current verification anchor that plugin scaffold files exist.
- [tests/server.test.js](/E:/code/AI-godot-mcp/tests/server.test.js)
  is the matching server-side verification anchor, reinforcing that plugin and
  server concerns are checked separately.
