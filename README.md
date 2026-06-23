# AI-godot-mcp

AI-godot-mcp is a standalone Godot MCP service scaffold focused on real game development workflows.

## Purpose

This project was extracted from an in-repository incubation package so it can evolve independently from the legacy `godot-mcp` root implementation.

## Current Scope

The scaffold currently provides:

- independent package metadata
- independent TypeScript build boundary
- independent docs entrypoints
- real stdio MCP server entrypoint skeleton
- placeholder Godot plugin entrypoint
- placeholder test entrypoint

Business logic and production tool handlers will be added incrementally in later steps.

## Standalone Bootstrapping

After cloning this repository:

1. Run `npm install`.
2. Run `npm run build`.
3. Run `npm test`.
4. Run `trellis init` in the repository root to initialize a fresh standalone Trellis workspace.

Detailed extraction notes live in [`docs/EXTRACTION.md`](./docs/EXTRACTION.md).
