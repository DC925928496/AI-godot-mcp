# Plugin Layer Guidelines

> Best practices for the Godot editor plugin layer in this project.

---

## Overview

This directory is temporarily stored under `frontend` because the fresh Trellis
template created a `backend/frontend` split. In this project, the files here
should be interpreted as **Godot editor plugin and GDScript layer guidance**,
not browser UI guidance.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Plugin-side file layout | Active |
| [Component Guidelines](./component-guidelines.md) | Godot plugin/UI/component conventions | Active |
| [Hook Guidelines](./hook-guidelines.md) | Plugin lifecycle and editor-entry conventions | Active |
| [State Management](./state-management.md) | Editor plugin runtime state boundaries | Active |
| [Quality Guidelines](./quality-guidelines.md) | GDScript/plugin quality bar | Active |
| [Type Safety](./type-safety.md) | Godot-side input and contract safety rules | Active |

---

## Pre-Development Checklist

Before writing plugin-side code, confirm:

- [ ] Read [./directory-structure.md](./directory-structure.md)
- [ ] Read [./component-guidelines.md](./component-guidelines.md)
- [ ] Read [./hook-guidelines.md](./hook-guidelines.md)
- [ ] Read [./state-management.md](./state-management.md)
- [ ] Read [./quality-guidelines.md](./quality-guidelines.md)
- [ ] Touched plugin inputs, paths, or editor objects? Read [./type-safety.md](./type-safety.md)

---

**Language**: All documentation should be written in **English**.
