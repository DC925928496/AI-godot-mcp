import { describe, it } from "node:test";
import assert from "node:assert";
import { EditorConnection } from "./editorConnection.js";
import { WebSocket } from "ws";

describe("EditorConnection", () => {
  it("send request times out after 10 seconds", async () => {
    const conn = new EditorConnection(6551);
    const mockWs = {
      readyState: WebSocket.OPEN,
      send: () => {},
      on: () => {},
      once: (event: string, cb: Function) => { if (event === "open") cb(); }
    };
    (conn as any).ws = mockWs;

    const start = Date.now();
    await assert.rejects(
      conn.send("test_method", {}, null),
      /Request timeout: test_method/
    );
    const elapsed = Date.now() - start;
    assert.ok(elapsed >= 10000 && elapsed < 11000);
  });

  it("send generates unique IDs for concurrent requests", async () => {
    const conn = new EditorConnection(6552);
    const ids = new Set<string>();
    const mockWs = {
      readyState: WebSocket.OPEN,
      send: (data: string) => {
        const req = JSON.parse(data);
        ids.add(req.id);
      },
      on: () => {},
      once: (event: string, cb: Function) => { if (event === "open") cb(); }
    };
    (conn as any).ws = mockWs;

    const promises = Array.from({ length: 100 }, (_, i) =>
      conn.send("test", { i }).catch(() => {})
    );

    await Promise.allSettled(promises);
    assert.strictEqual(ids.size, 100);
  });
});
