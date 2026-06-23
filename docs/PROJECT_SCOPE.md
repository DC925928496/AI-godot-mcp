# Project Scope

## Product Direction

AI-godot-mcp is a Godot MCP service focused on real game development workflows rather than generic editor automation.

## Intended Core Flow

The target workflow is:

1. inspect the current scene
2. modify scene structure and properties safely
3. attach existing scripts to nodes
4. run the current scene
5. read editor logs
6. rollback safely when an operation fails

## Current Phase

The project is still in scaffold phase. The current deliverable is a stable standalone boundary with build, test, plugin entry, and stdio server entrypoint ready for further implementation.
