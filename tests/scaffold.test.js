import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, "..");

test("scaffold keeps plugin entry files in place", () => {
  assert.equal(
    existsSync(join(projectRoot, "addons", "ai_godot_mcp", "plugin.cfg")),
    true,
  );
  assert.equal(
    existsSync(join(projectRoot, "addons", "ai_godot_mcp", "plugin.gd")),
    true,
  );
});

test("plugin WebSocket server uses Godot 4 TCP accept_stream flow", () => {
  const serverScript = readFileSync(
    join(projectRoot, "addons", "ai_godot_mcp", "websocket_server.gd"),
    "utf8",
  );

  assert.match(serverScript, /TCPServer\.new\(\)/);
  assert.match(serverScript, /\.listen\(port\)/);
  assert.match(serverScript, /\.is_connection_available\(\)/);
  assert.match(serverScript, /\.take_connection\(\)/);
  assert.match(serverScript, /\.accept_stream\(tcp_peer\)/);
  assert.doesNotMatch(serverScript, /\.create_server\(/);
  assert.doesNotMatch(serverScript, /\.accept\(\)/);
});

test("plugin source avoids ambiguous Godot parser forms", () => {
  const serverScript = readFileSync(
    join(projectRoot, "addons", "ai_godot_mcp", "websocket_server.gd"),
    "utf8",
  );

  assert.doesNotMatch(serverScript, /not "\.\."\s+in/);
  assert.doesNotMatch(serverScript, /not "\\\\"\s+in/);
  assert.doesNotMatch(serverScript, /if not property in node:/);
  assert.doesNotMatch(serverScript, /if not script is GDScript:/);
  assert.doesNotMatch(serverScript, /class_name: String/);
  assert.match(serverScript, /func _object_has_property/);
  assert.match(serverScript, /var data: String = client\.get_packet\(\)\.get_string_from_utf8\(\)/);
});
