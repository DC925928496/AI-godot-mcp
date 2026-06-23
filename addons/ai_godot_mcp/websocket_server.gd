extends Node

var server := WebSocketPeer.new()
var clients: Array[WebSocketPeer] = []
var port := 6550
var undo_redo: EditorUndoRedoManager
var current_txn := {}  # {id: String, name: String, step_count: int}

func _ready() -> void:
	server.create_server(port)
	undo_redo = EditorInterface.get_editor_undo_redo()

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
		"begin_ai_action":
			return handle_begin_action(req)
		"end_ai_action":
			return handle_end_action(req)
		"rollback_txn":
			rollback_txn()
			return {"id": req.id, "ok": true, "data": {}}
		"add_node":
			return handle_add_node(req)
		"set_node_property":
			return handle_set_property(req)
		"delete_node":
			return handle_delete_node(req)
		"create_scene":
			return handle_create_scene(req)
		"load_resource":
			return handle_load_resource(req)
		"save_current_scene":
			return handle_save_scene(req)
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

# Transaction management
func handle_begin_action(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id", "")
	var name = params.get("name", "AI Action")

	if current_txn.is_empty():
		current_txn = {"id": txn_id, "name": name, "step_count": 0}
		undo_redo.create_action("AI: " + name)

	return {"id": req.id, "ok": true, "data": {"txn_id": txn_id}}

func handle_end_action(req: Dictionary) -> Dictionary:
	if not current_txn.is_empty():
		undo_redo.commit_action()
		current_txn.clear()
	return {"id": req.id, "ok": true, "data": {}}

func rollback_txn() -> void:
	current_txn.clear()

# Write operations
func handle_add_node(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "add_node"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	# Validate
	var parent_path = params.get("parent_path", "")
	var node_type = params.get("node_type", "")
	var node_name = params.get("node_name", "")

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var parent = root if parent_path == "." else root.get_node_or_null(parent_path)
	if not parent:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Parent not found: " + parent_path, "failed_step": step}}

	if not ClassDB.class_exists(node_type):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_TYPE", "message": "Invalid node type: " + node_type, "failed_step": step}}

	# Register operation (deferred execution)
	var new_node = ClassDB.instantiate(node_type)
	new_node.name = node_name
	new_node.owner = root

	undo_redo.add_do_method(parent, "add_child", new_node)
	undo_redo.add_do_property(new_node, "owner", root)
	undo_redo.add_undo_method(parent, "remove_child", new_node)

	if auto_txn:
		handle_end_action({"id": ""})

	var node_path = node_name if parent_path == "." else (parent_path + "/" + node_name if parent_path != "" else node_name)
	return {"id": req.id, "ok": true, "data": {"node_path": node_path}}

func handle_set_property(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "set_property"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var node_path = params.get("node_path", "")
	var property = params.get("property", "")
	var value = params.get("value")

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var node = root.get_node_or_null(node_path)
	if not node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Node not found: " + node_path, "failed_step": step}}

	if not property in node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_PROPERTY", "message": "Property not found: " + property, "failed_step": step}}

	var old_value = node.get(property)
	undo_redo.add_do_property(node, property, value)
	undo_redo.add_undo_property(node, property, old_value)

	if auto_txn:
		handle_end_action({"id": ""})

	return {"id": req.id, "ok": true, "data": {"old_value": old_value, "new_value": value}}

func handle_delete_node(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "delete_node"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var node_path = params.get("node_path", "")
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var node = root.get_node_or_null(node_path)
	if not node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Node not found: " + node_path, "failed_step": step}}

	var parent = node.get_parent()
	var node_index = node.get_index()
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(parent, "move_child", node, node_index)
	undo_redo.add_undo_property(node, "owner", node.owner)

	if auto_txn:
		handle_end_action({"id": ""})

	return {"id": req.id, "ok": true, "data": {"deleted_node_path": node_path}}

func handle_create_scene(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var scene_name = params.get("scene_name", "")
	var root_node_type = params.get("root_node_type", "Node2D")

	if not ClassDB.class_exists(root_node_type):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_TYPE", "message": "Invalid node type: " + root_node_type}}

	var new_scene = ClassDB.instantiate(root_node_type)
	new_scene.name = scene_name if scene_name != "" else root_node_type

	var packed_scene = PackedScene.new()
	packed_scene.pack(new_scene)

	var scene_path = "res://" + scene_name + ".tscn"
	var err = ResourceSaver.save(packed_scene, scene_path)
	if err != OK:
		return {"id": req.id, "ok": false, "error": {"code": "SAVE_FAILED", "message": "Failed to create scene: " + str(err)}}

	return {"id": req.id, "ok": true, "data": {"scene_path": scene_path}}

func handle_load_resource(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var resource_path = params.get("resource_path", "")
	var resource_type = params.get("resource_type", "")

	if not ResourceLoader.exists(resource_path):
		return {"id": req.id, "ok": false, "error": {"code": "RESOURCE_NOT_FOUND", "message": "Resource not found: " + resource_path}}

	var resource = ResourceLoader.load(resource_path)
	if not resource:
		return {"id": req.id, "ok": false, "error": {"code": "LOAD_FAILED", "message": "Failed to load resource: " + resource_path}}

	var actual_type = resource.get_class()
	if resource_type != "" and not resource.is_class(resource_type):
		return {"id": req.id, "ok": false, "error": {"code": "TYPE_MISMATCH", "message": "Expected " + resource_type + ", got " + actual_type}}

	var resource_uid = ResourceLoader.get_resource_uid(resource_path)
	return {"id": req.id, "ok": true, "data": {"resource_uid": str(resource_uid), "resource_type": actual_type}}

func handle_save_scene(req: Dictionary) -> Dictionary:
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open"}}

	var scene_path = root.scene_file_path
	if scene_path == "":
		return {"id": req.id, "ok": false, "error": {"code": "NO_PATH", "message": "Scene not saved yet"}}

	var err = EditorInterface.save_scene()
	if err != OK:
		return {"id": req.id, "ok": false, "error": {"code": "SAVE_FAILED", "message": "Save failed: " + str(err)}}

	return {"id": req.id, "ok": true, "data": {"saved_path": scene_path}}
