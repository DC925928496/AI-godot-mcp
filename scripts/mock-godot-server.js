import { WebSocketServer } from "ws";

const PORT = 6550;
const wss = new WebSocketServer({ port: PORT });

console.log(`Mock Godot WebSocket server running on port ${PORT}`);

wss.on("connection", (ws) => {
  console.log("Client connected");

  ws.on("message", (data) => {
    const req = JSON.parse(data.toString());
    console.log("Received:", req.method);

    let response;
    switch (req.method) {
      case "get_project_context":
        response = {
          id: req.id,
          ok: true,
          data: {
            godot_version: "4.6.0",
            project_name: "TestProject",
            main_scene: "res://main.tscn",
            plugin_status: "connected",
          },
        };
        break;

      case "get_scene_tree":
        response = {
          id: req.id,
          ok: true,
          data: {
            name: "Root",
            type: "Node3D",
            children: [
              { name: "Camera", type: "Camera3D", children: [] },
              { name: "Player", type: "CharacterBody3D", children: [] },
            ],
          },
        };
        break;

      case "get_editor_logs":
        response = {
          id: req.id,
          ok: true,
          data: { logs: ["Log line 1", "Log line 2", "Warning: test"] },
        };
        break;

      case "begin_ai_action":
        response = { id: req.id, ok: true, data: { txn_id: "txn_123" } };
        break;

      case "end_ai_action":
        response = { id: req.id, ok: true, data: {} };
        break;

      case "add_node":
        response = { id: req.id, ok: true, data: { node_path: req.params?.parent_path + "/" + req.params?.node_name } };
        break;

      case "delete_node":
        response = { id: req.id, ok: true, data: {} };
        break;

      case "set_node_property":
        response = { id: req.id, ok: true, data: {} };
        break;

      case "create_scene":
        response = { id: req.id, ok: true, data: { scene_path: "res://" + req.params?.scene_name + ".tscn" } };
        break;

      case "save_current_scene":
        response = { id: req.id, ok: true, data: {} };
        break;

      case "attach_script":
        response = { id: req.id, ok: true, data: { script_path: req.params?.script_path } };
        break;

      case "play_current_scene":
        response = { id: req.id, ok: true, data: {} };
        break;

      case "stop_running_scene":
        response = { id: req.id, ok: true, data: {} };
        break;

      case "get_script_content":
        response = { id: req.id, ok: true, data: { content: "extends Node\n" } };
        break;

      case "list_scenes":
        response = { id: req.id, ok: true, data: { scenes: ["res://main.tscn", "res://level1.tscn"] } };
        break;

      default:
        response = {
          id: req.id,
          ok: false,
          error: { code: "UNKNOWN_METHOD", message: `Unknown method: ${req.method}` },
        };
    }

    ws.send(JSON.stringify(response));
  });

  ws.on("close", () => console.log("Client disconnected"));
});
