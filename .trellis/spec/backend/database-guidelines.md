# Safety Contract

> Carried-forward validation rules that remain mandatory in the new backend.

---

## Why this file exists

This project does not currently have a database layer. This file is repurposed
to hold the most important carried-forward safety contract from the legacy
`godot-mcp` implementation, because these rules are more important than keeping
an empty ORM template around.

---

## Path validation

- Every client-supplied path must be treated as untrusted.
- Reject traversal patterns such as `..`.
- When a path is expected to point at a Godot project, verify the project
  boundary explicitly, for example by checking for `project.godot`.

This applies to future tool inputs such as:

- `projectPath`
- `scenePath`
- `filePath`
- `scriptPath`
- `resourcePath`

---

## Class-name validation

- Any client-supplied Godot class/type name must be validated before use.
- A type/class field must never accept `res://...` or any raw path-like value.
- The legacy project fixed an RCE-class bug by separating class-name inputs
  from script/resource path inputs. Do not regress that boundary.

---

## Command execution

- Use argument-array based process execution only.
- Do not use shell-interpolated command strings for Godot or CLI invocations.
- Do not allow user-supplied strings to flow into a shell command template.

---

## Resource loading boundary

- Resource paths and class/type names are separate trust domains.
- A resource path may be loaded only through the intended resource-loading path.
- A class/type input must never be reinterpreted as a loadable script path.
