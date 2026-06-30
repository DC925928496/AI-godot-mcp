# Write The Product Vision Into Dual READMEs And Capture The Next-Direction Roadmap

## Goal

Reflect the user's product vision in both public README files, and capture a repo-backed direction note for what the project should do next to realize that vision.

The vision to preserve is:

> ordinary people should be able to use Codex-style agents, together with this project and the Godot client, to develop games

The architectural boundary to preserve is:

> Codex or another agent should own the planning and reasoning; AI-godot-mcp should provide the safe Godot-side execution layer rather than embedding product-specific creation workflows into MCP itself

## What I Already Know

- The public English README is `README.md`.
- The public Chinese README is `docs/README_zh.md`.
- The current repository already provides the low-level bridge needed for an agent-in-the-loop workflow:
  - project inspection
  - scene tree inspection
  - scene/node mutations
  - script attachment
  - play/stop current scene
  - editor/runtime log retrieval
  - CLI install/uninstall/version
- The current product messaging already says the project is for AI-driven game development, but it does not yet clearly express the broader end-user vision for non-expert creators.
- The repository also lacks a concise public statement of what the next product direction should be now that the low-level MCP bridge exists.
- The clarified direction is not to move game-design reasoning into MCP, but to make MCP a richer and more dependable capability layer for agent-driven execution.

## Requirements

- Add an explicit vision section to `README.md`.
- Add an explicit vision section to `docs/README_zh.md`.
- Keep the English and Chinese positioning aligned.
- Add a concise public-facing "what comes next" section to both README files.
- Base the roadmap wording on the current repository state rather than generic product language.
- Make the client/agent vs MCP boundary explicit: planning stays with Codex-style agents; safe execution stays with this project.
- Save a deeper internal roadmap note under this task's `research/` directory for future follow-up tasks.

## Acceptance Criteria

- [ ] `README.md` states that the project aims to let ordinary people build Godot games with Codex-style agents plus the Godot editor.
- [ ] `docs/README_zh.md` states the same vision in Chinese.
- [ ] Both README files summarize the next product direction without contradicting current implementation reality.
- [ ] Both README files make the planning-vs-execution boundary explicit.
- [ ] A task research artifact exists that explains the next direction from repository evidence.
- [ ] No runtime code behavior changes are introduced by this task.

## Definition Of Done

- The vision is visible in both public README files.
- The next-direction framing is visible in both public README files.
- A deeper internal roadmap note exists for future implementation tasks.
- The task can be resumed later without redoing the repo assessment.

## Out Of Scope

- Implementing any of the roadmap items
- Changing the MCP tool surface
- Refactoring tests or release metadata
- Revising unrelated project documentation

## Technical Notes

- Files inspected for this task:
  - `README.md`
  - `docs/README_zh.md`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_SCOPE.md`
  - `docs/phases/product-overview.md`
  - `docs/phases/phase-2-scene-mutations.md`
  - `docs/phases/phase-3-script-attachment.md`
  - `docs/phases/phase-4-scene-execution.md`
  - `docs/phases/phase-5-packaging.md`
  - `src/server/createServer.ts`
  - `src/server/editorConnection.ts`
  - `addons/ai_godot_mcp/plugin.gd`
  - `addons/ai_godot_mcp/websocket_server.gd`

## Research References

- `research/vision-roadmap.md` — repo-backed analysis of the gap between today's low-level bridge and the longer-term "ordinary people + Codex + Godot" product vision
