# Plugin Contract Safety

> Input and contract safety patterns for the Godot plugin layer.

---

## Overview

GDScript is dynamically typed, so this layer relies on explicit contract
discipline rather than compiler-enforced type safety.

---

## Contract Rules

- Treat all server-provided inputs as untrusted.
- Guard optional fields explicitly before use.
- Keep resource paths, class names, and node paths as separate concepts.
- Do not assume a value is safe because the server usually provides it.

---

## Validation Patterns

- check key presence before reading optional params
- normalize `res://` paths before use
- fail loudly when a required editor object, node, or resource is missing
- preserve explicit success/failure signaling for plugin operations

---

## Forbidden Patterns

- using one loosely defined input bag without validating expected keys
- treating arbitrary strings as both class names and resource paths
- continuing after failed load/open/lookup operations

---

## Real examples in this repository

- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
  keeps the current plugin contract minimal and explicit rather than reading
  from a loose unvalidated input bag.
- [addons/ai_godot_mcp/plugin.cfg](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.cfg)
  is a stable metadata contract that future plugin tooling should validate
  against instead of inferring plugin identity implicitly.
