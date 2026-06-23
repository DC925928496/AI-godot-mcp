import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { EditorConnection } from "./editorConnection.js";

export function createServer(): McpServer {
  const conn = new EditorConnection();
  const server = new McpServer({ name: "ai-godot-mcp", version: "0.1.0" });

  conn.connect().catch(() => {});

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

  return server;
}
