import test from "node:test";
import assert from "node:assert/strict";

test("server scaffold exposes MCP server lifecycle methods", async () => {
  const { createServer } = await import("../build/server/createServer.js");
  const server = createServer();
  assert.equal(typeof server.connect, "function");
  assert.equal(typeof server.close, "function");
});
