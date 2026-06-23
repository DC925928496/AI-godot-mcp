# Directory Structure

> How backend code is organized in this project.

---

## Overview

Unlike the legacy `godot-mcp` implementation, this project should not grow as
one giant `src/index.ts` file. The backend should stay split into small,
focused modules.

---

## Directory Layout

```text
src/
├── index.ts              # process entrypoint
├── server/
│   ├── createServer.ts   # MCP server construction
│   └── startServer.ts    # stdio transport bootstrap
└── install/
    └── index.ts          # install/uninstall workflow boundary
```

Planned growth shape:

```text
src/
├── server/
│   ├── tools/
│   ├── validation/
│   ├── transport/
│   ├── connection/
│   └── responses/
├── install/
└── shared/
```

---

## Module Organization

- `src/index.ts`
  - only starts the process
  - no business logic
- `src/server/`
  - MCP server construction
  - tool registration
  - transport bootstrap
- `src/install/`
  - plugin install/uninstall workflow
  - Godot project detection
- `src/shared/`
  - only when logic is shared across multiple backend modules

Do not recreate the legacy single-file architecture unless a very strong reason appears.

---

## Naming Conventions

- TypeScript identifiers: `camelCase`
- MCP tool names: `snake_case`
- files: `camelCase.ts`
- folders: lowercase by responsibility

---

## Examples

- [src/index.ts](/E:/code/AI-godot-mcp/src/index.ts)
- [src/server/createServer.ts](/E:/code/AI-godot-mcp/src/server/createServer.ts)
- [src/server/startServer.ts](/E:/code/AI-godot-mcp/src/server/startServer.ts)
- [src/install/index.ts](/E:/code/AI-godot-mcp/src/install/index.ts)
