# Fix Godot MCP Token Discovery

## Goal

Make the Node MCP server connect to the currently running Godot editor plugin when the Godot project name differs from `ai_godot_mcp`. Today the server reads only `app_userdata/ai_godot_mcp/ai_mcp_token`, but Godot writes plugin user data under the active project name, such as `BattleDemo`.

## Requirements

* Discover token files under Godot `app_userdata/*/ai_mcp_token` instead of relying only on the fixed `ai_godot_mcp` directory.
* Preserve compatibility with the existing fixed token location.
* Pick a token that authenticates with the running plugin on `localhost:6550`.
* Keep MCP stdout clean; no diagnostic logging to stdout.
* Surface actionable errors if no token can be read or no discovered token authenticates.

## Acceptance Criteria

* [ ] With `BattleDemo/ai_mcp_token` present and `ai_godot_mcp/ai_mcp_token` stale, `EditorConnection.connect()` can authenticate with the running plugin.
* [ ] Existing fixed-location token behavior remains covered.
* [ ] Build passes with strict TypeScript.
* [ ] Tests pass.

## Definition of Done

* Tests added or updated around token discovery/authentication.
* `npm run build` passes.
* `npm test` passes.
* Manual smoke check against the currently running Godot plugin succeeds.

## Technical Approach

Move token loading from a single hard-coded file to discovery of candidate token files in the Godot user data root. Attempt the existing fixed token path first for compatibility, then other project token files ordered by recent modification time. During `connect()`, open the WebSocket and send a lightweight authenticated probe, accepting the first token that succeeds.

## Decision (ADR-lite)

**Context**: Godot `OS.get_user_data_dir()` is project-specific, so the plugin writes tokens under the active project name. The Node side used a package-name directory and therefore read the wrong token.

**Decision**: Discover project token files and validate them against the running plugin before marking the editor connection ready.

**Consequences**: Connection startup may try multiple candidate tokens, but it avoids requiring users to manually synchronize token files or configure project names.

## Out of Scope

* Changing the Godot plugin token file format.
* Adding user-facing CLI flags or MCP config options for token paths.
* Changing the WebSocket protocol beyond the authentication probe.

## Technical Notes

* Main code path: `src/server/editorConnection.ts`.
* Relevant specs: `.trellis/spec/backend/index.md`, `.trellis/spec/backend/directory-structure.md`, `.trellis/spec/backend/error-handling.md`, `.trellis/spec/backend/quality-guidelines.md`, `.trellis/spec/backend/logging-guidelines.md`.
* Manual diagnosis found valid token at `C:/Users/dc/AppData/Roaming/Godot/app_userdata/BattleDemo/ai_mcp_token`; stale fixed token at `.../ai_godot_mcp/ai_mcp_token`.
