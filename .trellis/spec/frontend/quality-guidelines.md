# Quality Guidelines

> Code quality standards for the Godot plugin / GDScript layer.

---

## Required Patterns

- Keep editor-plugin code separate from Node MCP server code.
- Preserve safe class instantiation boundaries.
- Preserve explicit success/failure signaling.
- Preserve save/pack verification style for any future scene/resource persistence flow.
- Keep plugin UI scaffolding simple until the editor service contract is real.

---

## Forbidden Patterns

- accepting raw `res://...` paths as class/type identifiers
- silently continuing after failed resource loads
- mixing plugin/editor diagnostics into unclear or ambiguous output channels
- bypassing explicit rollback or validation boundaries for write operations

---

## Testing Requirements

- validate plugin file presence
- keep at least one scaffold-level test proving the plugin boundary exists
- add manual verification steps when editor integration behavior is added

---

## Code Review Checklist

- Does the change preserve the plugin/server boundary?
- Does it keep resource paths and class names separate?
- Does it fail loudly on missing preconditions?
- Does it avoid introducing editor-side behavior that the server cannot safely observe or control?

---

## Scenario: Godot 4 WebSocket Server Compatibility

### 1. Scope / Trigger

- Trigger: plugin-side WebSocket transport code starts or accepts local MCP
  connections from the Godot editor.
- Trigger: GDScript parser/static-analysis compatibility affects whether the
  plugin script can load at editor startup.

### 2. Signatures

- Plugin-side transport:
  - `TCPServer.listen(port)`
  - `TCPServer.is_connection_available()`
  - `TCPServer.take_connection()`
  - `WebSocketPeer.accept_stream(tcp_peer)`

### 3. Contracts

- The plugin remains the WebSocket server on port `6550`.
- The Node MCP layer remains the WebSocket client and must not require request
  or payload shape changes for this transport implementation detail.
- Each accepted TCP connection must create a fresh `WebSocketPeer`.
- Plugin teardown must close accepted peers and stop the `TCPServer`.

### 4. Validation & Error Matrix

- `listen(port)` returns non-`OK` -> call `push_error(...)` and add an editor
  log entry; do not pretend the server is available.
- `accept_stream(tcp_peer)` returns non-`OK` -> call `push_error(...)`, add an
  editor log entry, and disconnect the TCP peer.
- client state is `STATE_CLOSED` -> remove that peer from the client list.

### 5. Good / Base / Bad Cases

- Good: `TCPServer` accepts a pending TCP stream, a new `WebSocketPeer` wraps it
  with `accept_stream`, and existing JSON request/response handling stays
  unchanged.
- Base: no pending connection; `_process()` only polls existing peers.
- Bad: using `WebSocketPeer.create_server()` or `WebSocketPeer.accept()` as a
  listener API in Godot 4; those calls prevent the plugin script from loading.

### 6. Tests Required

- Source-level regression proving `websocket_server.gd` contains:
  - `TCPServer.new()`
  - `.listen(port)`
  - `.is_connection_available()`
  - `.take_connection()`
  - `.accept_stream(tcp_peer)`
- Source-level regression proving it does not contain:
  - `.create_server(`
  - `.accept()`
- Manual Godot validation:
  - enable the plugin in Godot 4.x
  - confirm `websocket_server.gd` loads without parse errors
  - connect with the Node MCP client on port `6550`

### 7. Wrong vs Correct

#### Wrong

```gdscript
var server := WebSocketPeer.new()
server.create_server(port)
var peer := server.accept()
```

#### Correct

```gdscript
var server := TCPServer.new()
server.listen(port)
var tcp_peer := server.take_connection()
var peer := WebSocketPeer.new()
peer.accept_stream(tcp_peer)
```

> Parser-safety note: prefer explicit calls such as `path.contains("..")` and
> `not (script is GDScript)` over ambiguous `not X in Y` or `not X is Type`
> forms in plugin startup scripts. Do not use GDScript keywords such as
> `class_name` as parameter/local names, and prefer explicit local types over
> `:=` when Godot cannot infer the return type during `--check-only`.

---

## Real examples in this repository

- [addons/ai_godot_mcp/plugin.gd](/E:/code/AI-godot-mcp/addons/ai_godot_mcp/plugin.gd)
  is the baseline plugin-boundary example for lifecycle and teardown behavior.
- [tests/scaffold.test.js](/E:/code/AI-godot-mcp/tests/scaffold.test.js)
  is the current verification anchor that plugin scaffold files exist.
- [tests/server.test.js](/E:/code/AI-godot-mcp/tests/server.test.js)
  is the matching server-side verification anchor, reinforcing that plugin and
  server concerns are checked separately.
