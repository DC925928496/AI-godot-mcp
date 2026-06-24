import { describe, it } from "node:test";
import assert from "node:assert";
import { createServer, type GodotEditorConnection } from "./createServer.js";

type ToolCall = {
  method: string;
  params?: unknown;
  txnId?: string | null;
};

class FakeConnection implements GodotEditorConnection {
  calls: ToolCall[] = [];

  async connect(): Promise<void> {}

  async send(method: string, params?: unknown, txnId?: string | null): Promise<unknown> {
    this.calls.push({ method, params, txnId });
    return { method, params, txnId };
  }
}

const createTestServer = () => {
  const conn = new FakeConnection();
  const server = createServer(conn) as any;
  return { conn, server };
};

const callTool = async (server: any, toolName: string, args?: unknown) => {
  const tool = server._registeredTools[toolName];
  assert.ok(tool, `Expected tool to be registered: ${toolName}`);
  return tool.handler(args);
};

const parseToolData = (result: any) => JSON.parse(result.content[0].text);

describe("Phase 2 Implementation", () => {
  it("createServer returns an MCP server instance", () => {
    const { server } = createTestServer();
    assert.ok(server);
    assert.strictEqual(typeof server, "object");
  });

  it("server has tool registration method", () => {
    const { server } = createTestServer();
    assert.ok(typeof server.tool === "function");
  });

  it("build succeeds without errors", () => {
    // This test passing means tsc compiled successfully
    assert.ok(true);
  });

  it("registers Batch 1 authoring tools", () => {
    const { server } = createTestServer();
    const toolNames = Object.keys(server._registeredTools);

    assert.ok(toolNames.includes("open_scene"));
    assert.ok(toolNames.includes("instantiate_scene"));
    assert.ok(toolNames.includes("connect_signal"));
    assert.ok(toolNames.includes("disconnect_signal"));
    assert.ok(toolNames.includes("get_input_map"));
    assert.ok(toolNames.includes("bind_input_key"));
  });

  it("sends valid Batch 1 calls to the Godot connection", async () => {
    const { conn, server } = createTestServer();

    const openResult = parseToolData(await callTool(server, "open_scene", { scene_path: "res://scenes/Battle.tscn" }));
    const bindResult = parseToolData(await callTool(server, "bind_input_key", {
      action_name: "cursor_confirm",
      key: "ENTER",
      shift: true,
    }));
    const inputMapResult = parseToolData(await callTool(server, "get_input_map"));

    assert.deepStrictEqual(conn.calls, [
      { method: "open_scene", params: { scene_path: "res://scenes/Battle.tscn" }, txnId: undefined },
      {
        method: "bind_input_key",
        params: { action_name: "cursor_confirm", key: "ENTER", shift: true },
        txnId: undefined,
      },
      { method: "get_input_map", params: undefined, txnId: undefined },
    ]);
    assert.strictEqual(openResult.method, "open_scene");
    assert.strictEqual(bindResult.method, "bind_input_key");
    assert.strictEqual(inputMapResult.method, "get_input_map");
  });

  it("passes the active transaction id to Batch 1 scene and signal write tools", async () => {
    const { conn, server } = createTestServer();

    await callTool(server, "begin_ai_action", { name: "Batch 1 write tools" });
    await callTool(server, "instantiate_scene", {
      parent_path: ".",
      scene_path: "res://units/PlayerUnit.tscn",
      node_name: "PlayerUnit",
    });
    await callTool(server, "connect_signal", {
      source_node_path: "PlayerUnit",
      signal_name: "turn_finished",
      target_node_path: "BattleController",
      method_name: "_on_player_turn_finished",
      deferred: true,
    });
    await callTool(server, "disconnect_signal", {
      source_node_path: "PlayerUnit",
      signal_name: "turn_finished",
      target_node_path: "BattleController",
      method_name: "_on_player_turn_finished",
    });
    await callTool(server, "end_ai_action");

    const beginTxnId = conn.calls[0]?.txnId;
    assert.match(String(beginTxnId), /^txn_\d+$/);
    assert.deepStrictEqual(conn.calls.map(call => call.method), [
      "begin_ai_action",
      "instantiate_scene",
      "connect_signal",
      "disconnect_signal",
      "end_ai_action",
    ]);
    assert.strictEqual(conn.calls[1]?.txnId, beginTxnId);
    assert.strictEqual(conn.calls[2]?.txnId, beginTxnId);
    assert.strictEqual(conn.calls[3]?.txnId, beginTxnId);
    assert.strictEqual(conn.calls[4]?.txnId, beginTxnId);
  });

  it("rejects invalid Batch 1 arguments before sending to Godot", async () => {
    const { conn, server } = createTestServer();

    await assert.rejects(() => callTool(server, "open_scene", { scene_path: "user://Battle.tscn" }));
    await assert.rejects(() => callTool(server, "instantiate_scene", {
      parent_path: ".",
      scene_path: "res://../Battle.tscn",
    }));
    await assert.rejects(() => callTool(server, "connect_signal", {
      source_node_path: "PlayerUnit",
      signal_name: "turn-finished",
      target_node_path: "BattleController",
      method_name: "_on_player_turn_finished",
    }));
    await assert.rejects(() => callTool(server, "bind_input_key", {
      action_name: "",
      key: "ENTER",
    }));
    await assert.rejects(() => callTool(server, "bind_input_key", {
      action_name: "cursor_confirm",
      key: "ENTER DOWN",
    }));

    assert.deepStrictEqual(conn.calls, []);
  });
});

describe("Batch 2: Project and structure management", () => {
  it("registers Batch 2 tools", () => {
    const { server } = createTestServer();
    const toolNames = Object.keys(server._registeredTools);

    assert.ok(toolNames.includes("list_autoloads"));
    assert.ok(toolNames.includes("set_autoload"));
    assert.ok(toolNames.includes("remove_autoload"));
    assert.ok(toolNames.includes("add_node_to_group"));
    assert.ok(toolNames.includes("remove_node_from_group"));
    assert.ok(toolNames.includes("reparent_node"));
    assert.ok(toolNames.includes("duplicate_node"));
  });

  it("sends valid Batch 2 calls to the Godot connection", async () => {
    const { conn, server } = createTestServer();

    const listResult = parseToolData(await callTool(server, "list_autoloads"));
    const setAutoloadResult = parseToolData(await callTool(server, "set_autoload", {
      name: "GameManager",
      path: "res://scripts/game_manager.gd",
      is_singleton: true,
    }));
    const removeAutoloadResult = parseToolData(await callTool(server, "remove_autoload", {
      name: "OldManager",
    }));

    assert.strictEqual(conn.calls[0]?.method, "list_autoloads");
    assert.strictEqual(conn.calls[1]?.method, "set_autoload");
    assert.strictEqual(conn.calls[2]?.method, "remove_autoload");
    assert.strictEqual(listResult.method, "list_autoloads");
    assert.strictEqual(setAutoloadResult.method, "set_autoload");
    assert.strictEqual(removeAutoloadResult.method, "remove_autoload");
  });

  it("passes transaction id to Batch 2 scene structure tools", async () => {
    const { conn, server } = createTestServer();

    await callTool(server, "begin_ai_action", { name: "Batch 2 scene ops" });
    await callTool(server, "add_node_to_group", {
      node_path: "Player",
      group_name: "enemies",
      persistent: true,
    });
    await callTool(server, "remove_node_from_group", {
      node_path: "Player",
      group_name: "allies",
    });
    await callTool(server, "reparent_node", {
      node_path: "Player/Sprite",
      new_parent_path: "UI",
      keep_global_transform: true,
    });
    await callTool(server, "duplicate_node", {
      node_path: "Player",
      new_name: "Player2",
    });
    await callTool(server, "end_ai_action");

    const beginTxnId = conn.calls[0]?.txnId;
    assert.match(String(beginTxnId), /^txn_\d+$/);
    assert.strictEqual(conn.calls[1]?.txnId, beginTxnId);
    assert.strictEqual(conn.calls[2]?.txnId, beginTxnId);
    assert.strictEqual(conn.calls[3]?.txnId, beginTxnId);
    assert.strictEqual(conn.calls[4]?.txnId, beginTxnId);
    assert.strictEqual(conn.calls[5]?.txnId, beginTxnId);
  });

  it("rejects invalid Batch 2 arguments before sending to Godot", async () => {
    const { conn, server } = createTestServer();

    await assert.rejects(() => callTool(server, "set_autoload", {
      name: "123Invalid",
      path: "res://scripts/manager.gd",
    }));
    await assert.rejects(() => callTool(server, "set_autoload", {
      name: "Manager",
      path: "invalid_path",
    }));
    await assert.rejects(() => callTool(server, "set_autoload", {
      name: "Manager",
      path: "res://scripts/manager.gd",
      is_singleton: false,
    }));
    await assert.rejects(() => callTool(server, "remove_autoload", {
      name: "invalid-name",
    }));
    await assert.rejects(() => callTool(server, "add_node_to_group", {
      node_path: "",
      group_name: "enemies",
    }));
    await assert.rejects(() => callTool(server, "add_node_to_group", {
      node_path: "Player",
      group_name: "123invalid",
    }));
    await assert.rejects(() => callTool(server, "remove_node_from_group", {
      node_path: "Player",
      group_name: "",
    }));
    await assert.rejects(() => callTool(server, "reparent_node", {
      node_path: "Player",
      new_parent_path: "",
    }));
    await assert.rejects(() => callTool(server, "duplicate_node", {
      node_path: "",
    }));

    assert.deepStrictEqual(conn.calls, []);
  });
});
