import test from "node:test";
import assert from "node:assert/strict";

test("server scaffold exposes MCP server lifecycle methods", async () => {
  const { createServer } = await import("../build/server/createServer.js");
  const server = createServer({ connect: async () => {}, send: async () => ({}) });
  assert.equal(typeof server.connect, "function");
  assert.equal(typeof server.close, "function");
});

test("server registers Batch 1 authoring tools", async () => {
  const { createServer } = await import("../build/server/createServer.js");
  const server = createServer({ connect: async () => {}, send: async () => ({}) });
  const toolNames = Object.keys(server._registeredTools);

  assert.ok(toolNames.includes("open_scene"));
  assert.ok(toolNames.includes("instantiate_scene"));
  assert.ok(toolNames.includes("connect_signal"));
  assert.ok(toolNames.includes("disconnect_signal"));
  assert.ok(toolNames.includes("get_input_map"));
  assert.ok(toolNames.includes("bind_input_key"));
});

test("server registers Batch 2 project management tools", async () => {
  const { createServer } = await import("../build/server/createServer.js");
  const server = createServer({ connect: async () => {}, send: async () => ({}) });
  const toolNames = Object.keys(server._registeredTools);

  assert.ok(toolNames.includes("list_autoloads"));
  assert.ok(toolNames.includes("set_autoload"));
  assert.ok(toolNames.includes("remove_autoload"));
  assert.ok(toolNames.includes("add_node_to_group"));
  assert.ok(toolNames.includes("remove_node_from_group"));
  assert.ok(toolNames.includes("reparent_node"));
  assert.ok(toolNames.includes("duplicate_node"));
});
