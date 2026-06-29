import { after, describe, it } from "node:test";
import assert from "node:assert";
import * as fs from "fs/promises";
import * as path from "path";
import { EditorConnection } from "./editorConnection.js";
import { WebSocket, WebSocketServer } from "ws";

const repoTempRoot = path.resolve(".tmp-tests", "editor-connection");

async function resetTempDir(name: string): Promise<string> {
  const dir = path.join(repoTempRoot, name);
  if (!dir.startsWith(repoTempRoot + path.sep)) {
    throw new Error(`Refusing to prepare temp directory outside ${repoTempRoot}`);
  }
  await fs.rm(dir, { recursive: true, force: true });
  await fs.mkdir(dir, { recursive: true });
  return dir;
}

async function writeToken(root: string, project: string, token: string): Promise<void> {
  const dir = path.join(root, project);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, "ai_mcp_token"), token, "utf-8");
}

async function createMockGodotServer(expectedToken: string): Promise<{ port: number; close: () => Promise<void> }> {
  const server = new WebSocketServer({ port: 0 });
  await new Promise<void>((resolve) => server.once("listening", resolve));

  server.on("connection", (socket) => {
    socket.on("message", (data) => {
      const req = JSON.parse(data.toString());
      if (req.auth_token !== expectedToken) {
        socket.send(JSON.stringify({
          id: req.id,
          ok: false,
          error: { code: "UNAUTHORIZED", message: "Invalid token" },
        }));
        return;
      }

      socket.send(JSON.stringify({
        id: req.id,
        ok: true,
        data: { project_name: "BattleDemo", plugin_status: "connected" },
      }));
    });
  });

  const address = server.address();
  assert.ok(address && typeof address === "object");

  return {
    port: address.port,
    close: () => new Promise<void>((resolve, reject) => {
      server.close((err) => err ? reject(err) : resolve());
    }),
  };
}

after(async () => {
  const resolvedRoot = path.resolve(repoTempRoot);
  if (!resolvedRoot.endsWith(path.join(".tmp-tests", "editor-connection"))) {
    throw new Error(`Refusing to clean unexpected temp root: ${resolvedRoot}`);
  }
  await fs.rm(resolvedRoot, { recursive: true, force: true });
});

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

  it("close does not schedule reconnects", () => {
    const conn = new EditorConnection(6553);
    let closeHandler: (() => void) | null = null;
    let closeCalled = false;
    const mockWs = {
      readyState: WebSocket.OPEN,
      close: () => {
        closeCalled = true;
        closeHandler?.();
      },
      on: (event: string, cb: () => void) => {
        if (event === "close") closeHandler = cb;
      },
      once: () => {},
      send: () => {},
    };
    (conn as any).ws = mockWs;
    (conn as any).reconnectAttempts = 0;
    (conn as any)._startPing();
    mockWs.on("close", () => {
      const shouldReconnect = !(conn as any).intentionalClose && (conn as any).reconnectAttempts < (conn as any).maxReconnects;
      (conn as any)._cleanup(shouldReconnect);
      if (shouldReconnect) (conn as any).reconnectAttempts++;
    });

    conn.close();

    assert.equal(closeCalled, true);
    assert.equal((conn as any).pending.size, 0);
    assert.equal((conn as any).pingInterval, null);
    assert.equal((conn as any).reconnectAttempts, (conn as any).maxReconnects);
  });

  it("authenticates with a project token when the fixed token is stale", async () => {
    const tokenRoot = await resetTempDir("project-token");
    await writeToken(tokenRoot, "ai_godot_mcp", "stale-token");
    await writeToken(tokenRoot, "BattleDemo", "active-token");
    const server = await createMockGodotServer("active-token");
    const conn = new EditorConnection(server.port, tokenRoot);

    try {
      await conn.connect();
      const result = await conn.send("get_project_context");
      assert.deepStrictEqual(result, { project_name: "BattleDemo", plugin_status: "connected" });
    } finally {
      conn.close();
      await server.close();
    }
  });

  it("preserves fixed token directory compatibility", async () => {
    const tokenRoot = await resetTempDir("fixed-token");
    await writeToken(tokenRoot, "ai_godot_mcp", "fixed-token");
    const server = await createMockGodotServer("fixed-token");
    const conn = new EditorConnection(server.port, tokenRoot);

    try {
      await conn.connect();
      const result = await conn.send("get_project_context");
      assert.deepStrictEqual(result, { project_name: "BattleDemo", plugin_status: "connected" });
    } finally {
      conn.close();
      await server.close();
    }
  });
});
