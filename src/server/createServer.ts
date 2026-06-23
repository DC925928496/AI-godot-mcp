import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { EditorConnection } from "./editorConnection.js";
import { z } from "zod";

const BeginActionSchema = z.object({ name: z.string() });
const AddNodeSchema = z.object({ parent_path: z.string(), node_type: z.string(), node_name: z.string() });
const SetPropertySchema = z.object({ node_path: z.string(), property: z.string(), value: z.unknown() });
const DeleteNodeSchema = z.object({ node_path: z.string() });
const CreateSceneSchema = z.object({ scene_name: z.string(), root_node_type: z.string().optional() });
const LoadResourceSchema = z.object({ resource_path: z.string(), resource_type: z.string().optional() });
const AttachScriptSchema = z.object({ node_path: z.string(), script_path: z.string().endsWith(".gd") });
const GetResourceUidSchema = z.object({ resource_path: z.string() });

/**
 * Creates and configures the MCP server with Godot editor tools.
 */
export function createServer(): McpServer {
  const conn = new EditorConnection();
  const server = new McpServer({ name: "ai-godot-mcp", version: "0.1.0" });
  let currentTxnId: string | null = null;
  let txnTimeout: NodeJS.Timeout | null = null;

  conn.connect().catch(() => {});

  const clearTxnTimeout = () => {
    if (txnTimeout) {
      clearTimeout(txnTimeout);
      txnTimeout = null;
    }
  };

  const startTxnTimeout = () => {
    clearTxnTimeout();
    txnTimeout = setTimeout(async () => {
      if (currentTxnId) {
        await conn.send("rollback_txn", {}, currentTxnId);
        currentTxnId = null;
      }
    }, 30000);
  };

  server.tool("get_project_context", "Get Godot project context", async () => {
    const data = await conn.send("get_project_context");
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("get_scene_tree", "Get current scene node tree", async () => {
    const data = await conn.send("get_scene_tree");
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("get_editor_logs", "Get recent editor logs", async () => {
    const data = await conn.send("get_editor_logs");
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("begin_ai_action", "Begin a transaction for multiple operations", async (args: unknown) => {
    const params = BeginActionSchema.parse(args);
    currentTxnId = `txn_${Date.now()}`;
    startTxnTimeout();
    const data = await conn.send("begin_ai_action", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("end_ai_action", "Commit the current transaction", async () => {
    clearTxnTimeout();
    const data = await conn.send("end_ai_action", {}, currentTxnId);
    currentTxnId = null;
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("add_node", "Add a node to the scene tree", async (args: unknown) => {
    const params = AddNodeSchema.parse(args);
    const data = await conn.send("add_node", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("set_node_property", "Set a property on a node", async (args: unknown) => {
    const params = SetPropertySchema.parse(args);
    const data = await conn.send("set_node_property", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("delete_node", "Delete a node from the scene", async (args: unknown) => {
    const params = DeleteNodeSchema.parse(args);
    const data = await conn.send("delete_node", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("create_scene", "Create a new scene file", async (args: unknown) => {
    const params = CreateSceneSchema.parse(args);
    const data = await conn.send("create_scene", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("load_resource", "Load a resource reference", async (args: unknown) => {
    const params = LoadResourceSchema.parse(args);
    const data = await conn.send("load_resource", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("save_current_scene", "Save the current scene", async () => {
    const data = await conn.send("save_current_scene", {}, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("attach_script", "Attach a GDScript to a node", async (args: unknown) => {
    const params = AttachScriptSchema.parse(args);
    const data = await conn.send("attach_script", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("get_resource_uid", "Get resource UID and type", async (args: unknown) => {
    const params = GetResourceUidSchema.parse(args);
    const data = await conn.send("get_resource_uid", params);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  return server;
}
