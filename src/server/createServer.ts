import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { EditorConnection } from "./editorConnection.js";
import { z } from "zod";

export interface GodotEditorConnection {
  connect(): Promise<void>;
  send(method: string, params?: unknown, txnId?: string | null): Promise<unknown>;
}

type ToolResult = {
  content: Array<{ type: "text"; text: string }>;
};

type ToolRegistrar = {
  registerTool(
    name: string,
    config: { description: string; inputSchema?: z.AnyZodObject },
    callback: (args: unknown) => Promise<ToolResult>,
  ): unknown;
};

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
  const toolRegistrar = server as unknown as ToolRegistrar;
  let currentTxnId: string | null = null;
  let txnTimeout: NodeJS.Timeout | null = null;

  conn.connect().catch(() => {});

  const createToolResult = (data: unknown) => ({
    content: [{ type: "text" as const, text: JSON.stringify(data) }],
  });

  const registerEditorTool = (
    name: string,
    description: string,
    callback: () => Promise<unknown>,
  ) => {
    toolRegistrar.registerTool(name, { description }, async () => createToolResult(await callback()));
  };

  const registerEditorToolWithInput = (
    name: string,
    description: string,
    inputSchema: z.AnyZodObject,
    callback: (params: unknown) => Promise<unknown>,
  ) => {
    toolRegistrar.registerTool(name, { description, inputSchema }, async (args: unknown) => {
      const params = inputSchema.parse(args);
      return createToolResult(await callback(params));
    });
  };

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

  registerEditorTool("get_project_context", "Get Godot project context", () => conn.send("get_project_context"));

  registerEditorTool("get_scene_tree", "Get current scene node tree", () => conn.send("get_scene_tree"));

  registerEditorToolWithInput("get_editor_logs", "Get editor logs with filters", GetEditorLogsSchema, params =>
    conn.send("get_editor_logs", params),
  );

  registerEditorToolWithInput("open_scene", "Open a Godot scene by res:// path", OpenSceneSchema, params =>
    conn.send("open_scene", params),
  );

  registerEditorToolWithInput("instantiate_scene", "Instantiate a PackedScene into the current scene", InstantiateSceneSchema, params =>
    conn.send("instantiate_scene", params, currentTxnId),
  );

  registerEditorToolWithInput("connect_signal", "Connect a signal between two nodes", ConnectSignalSchema, params =>
    conn.send("connect_signal", params, currentTxnId),
  );

  registerEditorToolWithInput("disconnect_signal", "Disconnect a signal between two nodes", DisconnectSignalSchema, params =>
    conn.send("disconnect_signal", params, currentTxnId),
  );

  registerEditorTool("get_input_map", "List project input actions", () => conn.send("get_input_map"));

  registerEditorToolWithInput("bind_input_key", "Create or extend a keyboard input binding", BindInputKeySchema, params =>
    conn.send("bind_input_key", params),
  );

  registerEditorToolWithInput("begin_ai_action", "Begin a transaction for multiple operations", BeginActionSchema, async params => {
    currentTxnId = `txn_${Date.now()}`;
    startTxnTimeout();
    return conn.send("begin_ai_action", params, currentTxnId);
  });

  registerEditorTool("end_ai_action", "Commit the current transaction", async () => {
    clearTxnTimeout();
    const data = await conn.send("end_ai_action", {}, currentTxnId);
    currentTxnId = null;
    return data;
  });

  registerEditorToolWithInput("add_node", "Add a node to the scene tree", AddNodeSchema, params =>
    conn.send("add_node", params, currentTxnId),
  );

  registerEditorToolWithInput("set_node_property", "Set a property on a node", SetPropertySchema, params =>
    conn.send("set_node_property", params, currentTxnId),
  );

  registerEditorToolWithInput("delete_node", "Delete a node from the scene", DeleteNodeSchema, params =>
    conn.send("delete_node", params, currentTxnId),
  );

  registerEditorToolWithInput("create_scene", "Create a new scene file", CreateSceneSchema, params =>
    conn.send("create_scene", params, currentTxnId),
  );

  registerEditorToolWithInput("load_resource", "Load a resource reference", LoadResourceSchema, params =>
    conn.send("load_resource", params, currentTxnId),
  );

  registerEditorTool("save_current_scene", "Save the current scene", () =>
    conn.send("save_current_scene", {}, currentTxnId),
  );

  registerEditorToolWithInput("attach_script", "Attach a GDScript to a node", AttachScriptSchema, params =>
    conn.send("attach_script", params, currentTxnId),
  );

  registerEditorToolWithInput("get_resource_uid", "Get resource UID and type", GetResourceUidSchema, params =>
    conn.send("get_resource_uid", params),
  );

  registerEditorTool("play_current_scene", "Run current scene (F6)", () => conn.send("play_current_scene"));

  registerEditorTool("stop_running_scene", "Stop running scene (F8)", () => conn.send("stop_running_scene"));

  // Batch 2: Project and structure management
  registerEditorTool("list_autoloads", "List project autoloads", () => conn.send("list_autoloads"));

  registerEditorToolWithInput("set_autoload", "Set or update an autoload", SetAutoloadSchema, params =>
    conn.send("set_autoload", params),
  );

  registerEditorToolWithInput("remove_autoload", "Remove an autoload", RemoveAutoloadSchema, params =>
    conn.send("remove_autoload", params),
  );

  registerEditorToolWithInput("add_node_to_group", "Add a node to a group", AddNodeToGroupSchema, params =>
    conn.send("add_node_to_group", params, currentTxnId),
  );

  registerEditorToolWithInput("remove_node_from_group", "Remove a node from a group", RemoveNodeFromGroupSchema, params =>
    conn.send("remove_node_from_group", params, currentTxnId),
  );

  registerEditorToolWithInput("reparent_node", "Reparent a node to a new parent", ReparentNodeSchema, params =>
    conn.send("reparent_node", params, currentTxnId),
  );

  registerEditorToolWithInput("duplicate_node", "Duplicate a node", DuplicateNodeSchema, params =>
    conn.send("duplicate_node", params, currentTxnId),
  );

  return server;
}
