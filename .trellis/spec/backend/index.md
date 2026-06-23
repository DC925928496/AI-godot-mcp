# Backend Development Guidelines

> Best practices for the Node.js MCP server layer in this project.

---

## Overview

This layer is the standalone MCP server that AI clients talk to over stdio.
It is responsible for:

- MCP tool registration
- request validation
- local editor/plugin connection management
- safe coordination with the Godot editor plugin

The current repository is no longer the legacy `godot-mcp` root. However, some
security and error-handling rules from that project are intentionally carried
forward and remain non-negotiable.

---

## Pre-Development Checklist

Before writing backend code, confirm:

- [ ] Read [./directory-structure.md](./directory-structure.md)
- [ ] Read [./error-handling.md](./error-handling.md)
- [ ] Read [./quality-guidelines.md](./quality-guidelines.md)
- [ ] Read [./logging-guidelines.md](./logging-guidelines.md)
- [ ] Touched any client-supplied path or Godot class input? Read the carried-forward constraints in [./database-guidelines.md](./database-guidelines.md)

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Node MCP server module layout | Active |
| [Database Guidelines](./database-guidelines.md) | Repurposed safety contract for path/class validation | Active |
| [Error Handling](./error-handling.md) | MCP-safe error responses and failure propagation | Active |
| [Quality Guidelines](./quality-guidelines.md) | TypeScript and tool-layer quality bar | Active |
| [Logging Guidelines](./logging-guidelines.md) | stderr discipline and operational logging | Active |

---

**Language**: All documentation should be written in **English**.
