# Migrate Product PRD And Core Specs From Legacy godot-mcp

## Goal

Migrate the active product requirements and the minimum viable coding/spec constraints from the legacy `godot-mcp` repository into `AI-godot-mcp`, so the new standalone repository becomes the canonical planning and implementation home for future work.

## Requirements

### Project Positioning

- `AI-godot-mcp` is the new standalone repository for the product.
- The legacy `godot-mcp` repository remains an upstream/reference codebase, not the long-term main project root.
- The product continues to be a Godot MCP service focused on real game development workflows rather than generic editor automation.

### Legacy godot-mcp Position

- The legacy project lives at the sibling repository path:
  - `E:/code/godot-mcp`
- It should be treated as:
  - reference implementation source
  - migration evidence source
  - security/history source
- It should not be treated as the canonical planning home once requirements and specs are migrated into this repository.

### Development Vision

- Build `AI-godot-mcp` into a production-grade Godot MCP service for game developers.
- Keep the product centered on editor-assisted game development workflows:
  - inspect current scene state
  - add or modify scene nodes safely
  - load resources
  - attach scripts
  - run the current scene
  - inspect editor logs
  - rollback failed multi-step actions safely
- Replace the legacy headless-script-first operating model with a safer editor-plugin-centered architecture over time.

### Scope Of This Migration Task

- Bring the active product PRD into this repository.
- Bring over the minimum spec rules that must not be lost:
  - Node/server-side safety constraints
  - MCP/backend error handling expectations
  - GDScript/plugin-side safety and quality rules
- Adapt migrated spec text so it matches this repository's current structure instead of the old single-file legacy layout.

## Acceptance Criteria

- [ ] This repository contains a product PRD for the standalone `AI-godot-mcp` line.
- [ ] The PRD explicitly states where the legacy `godot-mcp` repository lives and how it should be used.
- [ ] The PRD explicitly states the long-term development vision for `AI-godot-mcp`.
- [ ] The Trellis spec in this repository no longer consists only of bootstrap placeholders for the active backend/plugin layers.
- [ ] Carried-forward security constraints from legacy `godot-mcp` are documented in this repository's spec.

## Definition of Done

- The new repository has its own active PRD for this product line.
- The most important carried-forward spec rules are available locally under `.trellis/spec/`.
- The migrated spec text no longer instructs the AI to follow obsolete legacy-only directory assumptions.

## Out of Scope

- Implementing new runtime functionality
- Completing every placeholder spec file under `.trellis/spec/`
- Deleting the legacy `godot-mcp` repository

## Technical Notes

- Legacy reference repository: `E:/code/godot-mcp`
- Standalone repository: `E:/code/AI-godot-mcp`
- Current bootstrap spec structure was generic and needed project-specific replacement before implementation work could safely continue.
