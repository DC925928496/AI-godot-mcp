extends Node

var server := WebSocketPeer.new()
var clients: Array[WebSocketPeer] = []
var port := 6550

func _ready() -> void:
	server.create_server(port)

func _process(_delta: float) -> void:
	server.poll()

	if server.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while server.get_available_packet_count() > 0:
			var peer := server.accept()
			if peer:
				clients.append(peer)

	for client in clients:
		client.poll()
		if client.get_ready_state() == WebSocketPeer.STATE_OPEN:
			while client.get_available_packet_count() > 0:
				var data := client.get_packet().get_string_from_utf8()
				var response := handle_request(JSON.parse_string(data))
				client.send_text(JSON.stringify(response))
		elif client.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			clients.erase(client)

func handle_request(req: Dictionary) -> Dictionary:
	match req.get("method"):
		"get_project_context":
			return {
				"id": req.id,
				"ok": true,
				"data": {
					"godot_version": Engine.get_version_info().string,
					"project_name": ProjectSettings.get_setting("application/config/name"),
					"main_scene": ProjectSettings.get_setting("application/run/main_scene"),
					"plugin_status": "connected"
				}
			}
		"get_scene_tree":
			var edited := EditorInterface.get_edited_scene_root()
			return {
				"id": req.id,
				"ok": true,
				"data": serialize_node(edited, req.get("params", {}).get("depth", 5))
			}
		"get_editor_logs":
			return {
				"id": req.id,
				"ok": true,
				"data": {"logs": []}
			}
		_:
			return {"id": req.id, "ok": false, "error": {"code": "UNKNOWN_METHOD", "message": "Unknown method"}}

func serialize_node(node: Node, depth: int) -> Dictionary:
	if not node or depth <= 0:
		return {}
	return {
		"name": node.name,
		"type": node.get_class(),
		"children": node.get_children().map(func(c): return serialize_node(c, depth - 1))
	}
