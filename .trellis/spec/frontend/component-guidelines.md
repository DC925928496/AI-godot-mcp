# Plugin Conventions

> How the Godot editor plugin layer should behave.

---

## Naming

- Use `snake_case` for GDScript functions, vars, and params.
- Match plugin-side parameter names to the expected Godot-side contract.
- Keep plugin UI labels and dock titles stable and intentional.

---

## Path Handling

- Normalize Godot resource paths to `res://` where applicable.
- Never assume a bare relative path resolves against the intended project root.

---

## Output Channels

- stdout-like success output and stderr-like failure output must remain intentionally separated wherever plugin scripts interact with server-side execution flows.
- Avoid noisy output that makes operational results harder to consume.

---

## Optional Inputs

- Guard optional parameters explicitly before reading them.
- Do not assume a key exists just because the calling tool usually provides it.

---

## Resource Handling

- Resource path inputs and class/type inputs must remain distinct.
- When assigning resource-like values, use the explicit resource-loading path rather than assuming every string is a plain value.

---

## Real examples in this repository

- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
  shows the current minimal plugin UI component shape:
  one dock panel, one label, explicit attachment to the editor dock.
- [addons/ai_godot_mcp/plugin.cfg](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.cfg)
  is the metadata contract the plugin component layer must continue to match.
