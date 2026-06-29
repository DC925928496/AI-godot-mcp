# Quality Guidelines

> Code quality standards for the Node MCP server layer.

---

## Required Patterns

- TypeScript must remain `strict`.
- Use ESM imports consistently.
- Keep process entrypoints thin.
- Keep MCP server creation and transport bootstrap separate.
- Add JSDoc for non-trivial exported functions and boundaries.
- Preserve the separation between:
  - process bootstrap
  - tool registration
  - validation
  - install workflow

---

## Forbidden Patterns

- rebuilding the legacy one-file backend architecture
- mixing shell command construction with user input
- treating path-like inputs as class names or vice versa
- adding tool handlers without corresponding validation
- polluting stdout with diagnostic logs

---

## Testing Requirements

- `npm run build` must pass
- `npm test` must pass
- add targeted tests when new backend boundaries appear
- for safety-sensitive behavior, validate the guardrail before validating the happy path

---

## Code Review Checklist

- Is the new backend code in the correct module boundary?
- Are client-supplied paths validated?
- Are client-supplied Godot types validated?
- Does the code keep stdout clean for MCP transport use?
- Is the new behavior covered by at least build/test verification?

---

## Scenario: Editor Connection Shutdown

### 1. Scope / Trigger

- Trigger: code opens a WebSocket connection from the Node MCP layer to the
  Godot editor plugin and later closes it intentionally.

### 2. Signatures

- `EditorConnection.connect()`
- `EditorConnection.send(method, params?, txnId?)`
- `EditorConnection.close()`

### 3. Contracts

- `close()` is the public shutdown path for callers and tests.
- Intentional shutdown must clear ping timers and pending request timers.
- Intentional shutdown must not schedule reconnect attempts.
- Unexpected socket close may still use the reconnect path.

### 4. Validation & Error Matrix

- pending requests during intentional close -> reject with `Connection closed`
- pending requests during reconnecting close -> reject with
  `Connection lost, reconnecting...`
- explicit `close()` -> no reconnect timer, no live ping interval

### 5. Good / Base / Bad Cases

- Good: `test-p0.mjs` calls `conn.close()` after a successful Godot integration
  run and the Node process exits naturally.
- Base: an unexpected plugin/editor disconnect triggers the bounded reconnect
  logic.
- Bad: directly calling `ws.close()` from outside the class and letting the
  internal close handler schedule reconnect timers that keep tests alive.

### 6. Tests Required

- Unit regression proving `close()` clears intervals and does not schedule
  reconnects.
- Integration smoke test proving `test-p0.mjs` exits after play/log/stop.

### 7. Wrong vs Correct

#### Wrong

```js
conn["ws"]?.close();
```

#### Correct

```ts
conn.close();
```

---

## Scenario: Editor Connection Token Discovery

### 1. Scope / Trigger

- Trigger: code opens a WebSocket connection from the Node MCP layer to the
  Godot editor plugin and must authenticate with the plugin token file.

### 2. Signatures

- `new EditorConnection(port = 6550, godotUserDataRoot?)`
- `EditorConnection.connect()`
- `EditorConnection.send(method, params?, txnId?)`

### 3. Contracts

- Godot writes `ai_mcp_token` under `OS.get_user_data_dir()`, which is scoped to
  the opened Godot project name, for example
  `app_userdata/BattleDemo/ai_mcp_token`.
- The Node side must not assume the project directory is always
  `app_userdata/ai_godot_mcp`.
- Candidate tokens must include the legacy fixed directory first for backward
  compatibility, then other `app_userdata/*/ai_mcp_token` files.
- `connect()` must authenticate a candidate token with a lightweight editor
  request before treating the connection as ready.
- Failed candidates must close their sockets intentionally so stale auth probes
  do not schedule reconnect attempts.

### 4. Validation & Error Matrix

- no readable token files -> actionable error naming the Godot user data root
  and advising that the editor/plugin must be running
- stale token returns `UNAUTHORIZED` -> try the next candidate token
- all candidates fail -> actionable error with one-editor/plugin-restart hints
- successful probe -> `send()` uses the authenticated token for subsequent
  requests

### 5. Good / Base / Bad Cases

- Good: `BattleDemo/ai_mcp_token` authenticates while
  `ai_godot_mcp/ai_mcp_token` is stale.
- Base: only `ai_godot_mcp/ai_mcp_token` exists and still authenticates.
- Bad: reading a single hard-coded token path and reporting `WebSocket not
  connected` even though the plugin is listening with a different project token.

### 6. Tests Required

- Unit regression where the fixed token is stale and a project token succeeds.
- Unit regression where the fixed token remains the only valid token.
- `npm run build`, `npm run lint`, and `npm test` after connection changes.
- Manual smoke check against a running Godot editor when this behavior changes.

### 7. Wrong vs Correct

#### Wrong

```ts
await fs.readFile(path.join(userDataRoot, "ai_godot_mcp", "ai_mcp_token"), "utf-8");
```

#### Correct

```ts
for (const candidate of await discoverTokenCandidates(userDataRoot)) {
  await connectAndProbe(candidate);
}
```

---

## Scenario: MCP Tool Input Schema Registration

### 1. Scope / Trigger

- Trigger: Node MCP code registers a tool that accepts caller arguments and
  forwards those arguments to the Godot editor plugin.

### 2. Signatures

- `McpServer.registerTool(name, { description, inputSchema }, handler)`
- `EditorConnection.send(method, params?, txnId?)`
- WebSocket request payload:
  `{ id, method, params, txn_id?, auth_token }`

### 3. Contracts

- Every parameterized MCP tool must pass an `inputSchema` during tool
  registration, not only parse arguments inside the handler.
- `tools/list` must expose every caller-supplied field through JSON Schema so
  agents know which arguments to send.
- Tool handlers must parse the same schema before calling
  `EditorConnection.send()`.
- The Godot WebSocket protocol continues to receive arguments under the
  top-level `params` field.
- Zero-argument tools may omit `inputSchema` and send no params, or explicitly
  send `{}` when the plugin method expects an empty params object.

### 4. Validation & Error Matrix

- missing `inputSchema` for a parameterized tool -> `tools/list` shows an empty
  object schema and agents call the handler with `undefined`
- malformed arguments -> MCP/handler schema validation fails before
  `EditorConnection.send()`
- valid arguments -> handler forwards the parsed object as `params`
- transaction-aware tool -> handler forwards the active `txn_id` unchanged

### 5. Good / Base / Bad Cases

- Good: `create_scene` appears in `tools/list` with `scene_name` required and
  forwards `{ scene_name, root_node_type? }` as WebSocket `params`.
- Base: `get_project_context` has no `inputSchema` and sends no params.
- Bad: `server.tool("create_scene", "Create a new scene file", async args =>
  CreateSceneSchema.parse(args))` validates only inside the handler, leaving
  the MCP tool definition empty for agents.

### 6. Tests Required

- Unit regression asserting every parameterized registered tool has
  `_registeredTools[name].inputSchema`.
- MCP client/server regression using `tools/list` to assert the generated JSON
  Schema includes required fields such as `create_scene.scene_name`.
- Handler regression proving valid arguments are forwarded to
  `EditorConnection.send(method, params, txnId)`.
- `npm run build`, `npm run lint`, and `npm test` after registration changes.

### 7. Wrong vs Correct

#### Wrong

```ts
server.tool("create_scene", "Create a new scene file", async (args: unknown) => {
  const params = CreateSceneSchema.parse(args);
  return conn.send("create_scene", params, currentTxnId);
});
```

#### Correct

```ts
server.registerTool(
  "create_scene",
  { description: "Create a new scene file", inputSchema: CreateSceneSchema },
  async (args: unknown) => {
    const params = CreateSceneSchema.parse(args);
    return conn.send("create_scene", params, currentTxnId);
  },
);
```

---

## Real examples in this repository

- [src/index.ts](/E:/code/AI-godot-mcp/src/index.ts)
  is the expected thin bootstrap entrypoint.
- [src/server/createServer.ts](/E:/code/AI-godot-mcp/src/server/createServer.ts)
  is the current example of exported backend logic living in the server module.
- [src/install/index.ts](/E:/code/AI-godot-mcp/src/install/index.ts)
  preserves a separate install workflow boundary instead of mixing install
  concerns into the MCP server path.
