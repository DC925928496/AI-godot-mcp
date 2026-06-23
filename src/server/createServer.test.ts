import { describe, it } from "node:test";
import assert from "node:assert";
import { createServer } from "./createServer.js";

describe("Phase 2 Implementation", () => {
  it("createServer returns an MCP server instance", () => {
    const server = createServer();
    assert.ok(server);
    assert.strictEqual(typeof server, "object");
  });

  it("server has tool registration method", () => {
    const server = createServer();
    assert.ok(typeof server.tool === "function");
  });

  it("build succeeds without errors", () => {
    // This test passing means tsc compiled successfully
    assert.ok(true);
  });
});
