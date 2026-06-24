import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { EditorConnection } from "./editorConnection.js";
import { z } from "zod";

export interface GodotEditorConnection {
  connect(): Promise<void>;
  send(method: string, params?: unknown, txnId?: string | null): Promise<unknown>;
}

const GodotIdentifierSchema = z.string().regex(
  /^[A-Za-z_][A-Za-z0-9_]*$/,
  "Must be a Godot-style identifier using letters, numbers, and underscores",
);
const NonEmptyNodePathSchema = z.string()
  .refine(value => value.trim().length > 0, "Node path must not be empty")
  .refine(value => !value.includes(".."), "Node path must not contain traversal segments");
const ScenePathSchema = z.string()
  .refine(value => value.startsWith("res://"), "Scene path must start with res://")
  .refine(value => !value.includes(".."), "Scene path must not contain traversal segments")
  .refine(value => !value.includes("\\"), "Scene path must use Godot resource path separators")
  .refine(value => value.endsWith(".tscn"), "Scene path must end with .tscn");
const NodeNameSchema = z.string()
  .refine(value => value.trim().length > 0, "Node name must not be empty")
  .refine(value => value === value.trim(), "Node name must not contain leading or trailing whitespace")
  .refine(value => !value.includes("/") && !value.includes("\\"), "Node name must not contain path separators")
  .refine(value => !value.includes(".."), "Node name must not contain traversal segments");
const KeyNameSchema = z.string()
  .refine(value => value.trim().length > 0, "Key must not be empty")
  .refine(value => value === value.trim(), "Key must not contain leading or trailing whitespace")
  .refine(value => /^[A-Za-z0-9_]+$/.test(value), "Key must be a symbolic key name or numeric keycode");

const BeginActionSchema = z.object({ name: z.string() });
const AddNodeSchema = z.object({ parent_path: z.string(), node_type: z.string(), node_name: z.string() });
const SetPropertySchema = z.object({ node_path: z.string(), property: z.string(), value: z.unknown() });
const DeleteNodeSchema = z.object({ node_path: z.string() });
const CreateSceneSchema = z.object({ scene_name: z.string(), root_node_type: z.string().optional() });
const LoadResourceSchema = z.object({ resource_path: z.string(), resource_type: z.string().optional() });
const AttachScriptSchema = z.object({ node_path: z.string(), script_path: z.string().endsWith(".gd") });
const GetResourceUidSchema = z.object({ resource_path: z.string() });
const GetEditorLogsSchema = z.object({ since_timestamp: z.number().optional(), filter_level: z.enum(["error", "warning", "info", "all"]).optional() });
const OpenSceneSchema = z.object({ scene_path: ScenePathSchema });
const InstantiateSceneSchema = z.object({
  parent_path: NonEmptyNodePathSchema,
  scene_path: ScenePathSchema,
  node_name: NodeNameSchema.optional(),
});
const ConnectSignalSchema = z.object({
  source_node_path: NonEmptyNodePathSchema,
  signal_name: GodotIdentifierSchema,
  target_node_path: NonEmptyNodePathSchema,
  method_name: GodotIdentifierSchema,
  deferred: z.boolean().optional(),
  one_shot: z.boolean().optional(),
});
const DisconnectSignalSchema = z.object({
  source_node_path: NonEmptyNodePathSchema,
  signal_name: GodotIdentifierSchema,
  target_node_path: NonEmptyNodePathSchema,
  method_name: GodotIdentifierSchema,
});
const BindInputKeySchema = z.object({
  action_name: GodotIdentifierSchema,
  key: KeyNameSchema,
  ctrl: z.boolean().optional(),
  alt: z.boolean().optional(),
  shift: z.boolean().optional(),
  meta: z.boolean().optional(),
});

// Batch 2: Project and structure management
const ResourcePathSchema = z.string()
  .refine(value => value.startsWith("res://"), "Resource path must start with res://")
  .refine(value => !value.includes(".."), "Resource path must not contain traversal segments")
  .refine(value => !value.includes("\\"), "Resource path must use Godot resource path separators");
const SetAutoloadSchema = z.object({
  name: GodotIdentifierSchema,
  path: ResourcePathSchema,
  is_singleton: z.literal(true).optional(),
});
const RemoveAutoloadSchema = z.object({
  name: GodotIdentifierSchema,
});
const AddNodeToGroupSchema = z.object({
  node_path: NonEmptyNodePathSchema,
  group_name: GodotIdentifierSchema,
  persistent: z.boolean().optional(),
});
const RemoveNodeFromGroupSchema = z.object({
  node_path: NonEmptyNodePathSchema,
  group_name: GodotIdentifierSchema,
});
const ReparentNodeSchema = z.object({
  node_path: NonEmptyNodePathSchema,
  new_parent_path: NonEmptyNodePathSchema,
  keep_global_transform: z.boolean().optional(),
});
const DuplicateNodeSchema = z.object({
  node_path: NonEmptyNodePathSchema,
  new_name: NodeNameSchema.optional(),
});

/**
 * Creates and configures the MCP server with Godot editor tools.
 */
export function createServer(conn: GodotEditorConnection = new EditorConnection()): McpServer {
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

  server.tool("get_editor_logs", "Get editor logs with filters", async (args: unknown) => {
    const params = GetEditorLogsSchema.parse(args);
    const data = await conn.send("get_editor_logs", params);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("open_scene", "Open a Godot scene by res:// path", async (args: unknown) => {
    const params = OpenSceneSchema.parse(args);
    const data = await conn.send("open_scene", params);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("instantiate_scene", "Instantiate a PackedScene into the current scene", async (args: unknown) => {
    const params = InstantiateSceneSchema.parse(args);
    const data = await conn.send("instantiate_scene", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("connect_signal", "Connect a signal between two nodes", async (args: unknown) => {
    const params = ConnectSignalSchema.parse(args);
    const data = await conn.send("connect_signal", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("disconnect_signal", "Disconnect a signal between two nodes", async (args: unknown) => {
    const params = DisconnectSignalSchema.parse(args);
    const data = await conn.send("disconnect_signal", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("get_input_map", "List project input actions", async () => {
    const data = await conn.send("get_input_map");
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("bind_input_key", "Create or extend a keyboard input binding", async (args: unknown) => {
    const params = BindInputKeySchema.parse(args);
    const data = await conn.send("bind_input_key", params);
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

  server.tool("play_current_scene", "Run current scene (F6)", async () => {
    const data = await conn.send("play_current_scene");
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("stop_running_scene", "Stop running scene (F8)", async () => {
    const data = await conn.send("stop_running_scene");
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  // Batch 2: Project and structure management
  server.tool("list_autoloads", "List project autoloads", async () => {
    const data = await conn.send("list_autoloads");
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("set_autoload", "Set or update an autoload", async (args: unknown) => {
    const params = SetAutoloadSchema.parse(args);
    const data = await conn.send("set_autoload", params);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("remove_autoload", "Remove an autoload", async (args: unknown) => {
    const params = RemoveAutoloadSchema.parse(args);
    const data = await conn.send("remove_autoload", params);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("add_node_to_group", "Add a node to a group", async (args: unknown) => {
    const params = AddNodeToGroupSchema.parse(args);
    const data = await conn.send("add_node_to_group", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("remove_node_from_group", "Remove a node from a group", async (args: unknown) => {
    const params = RemoveNodeFromGroupSchema.parse(args);
    const data = await conn.send("remove_node_from_group", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("reparent_node", "Reparent a node to a new parent", async (args: unknown) => {
    const params = ReparentNodeSchema.parse(args);
    const data = await conn.send("reparent_node", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  server.tool("duplicate_node", "Duplicate a node", async (args: unknown) => {
    const params = DuplicateNodeSchema.parse(args);
    const data = await conn.send("duplicate_node", params, currentTxnId);
    return { content: [{ type: "text", text: JSON.stringify(data) }] };
  });

  return server;
}
