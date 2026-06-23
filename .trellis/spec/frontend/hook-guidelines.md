# Plugin Lifecycle Guidelines

> How plugin lifecycle and editor-entry behavior should be structured.

---

## Overview

This project does not use React-style hooks. In this repository, this file is
repurposed to document **plugin lifecycle conventions** for `EditorPlugin`
entrypoints and related editor-state integration.

---

## Lifecycle Patterns

- Put plugin activation logic in `_enter_tree()`.
- Put plugin teardown logic in `_exit_tree()`.
- Every object created and attached in `_enter_tree()` must be removed and freed in `_exit_tree()`.
- Keep lifecycle methods shallow:
  - construct or delegate
  - attach or remove
  - avoid embedding large operation logic directly inside entry methods

---

## Naming Conventions

- private instance fields may use a leading underscore, for example `_dock_instance`
- plugin lifecycle callbacks should use standard Godot method names exactly

---

## Common Mistakes

- creating dock/editor UI and never removing it on exit
- storing plugin state in globals without explicit lifecycle cleanup
- mixing long-running operational logic directly into `_enter_tree()` instead of delegating to helper modules later

---

## Real examples in this repository

- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
  is the baseline lifecycle example:
  `_enter_tree()` creates and mounts the dock,
  `_exit_tree()` removes it, frees it, and clears the instance field.
