extends Node

var server := WebSocketPeer.new()
var clients: Array[WebSocketPeer] = []
var port := 6550
var undo_redo: EditorUndoRedoManager
var current_txn := {}  # {id: String, name: String, step_count: int}
var auth_token := ""
var editor_plugin: EditorPlugin = null

# Log capture system
var _log_buffer: Array[Dictionary] = []
var _max_log_size := 1000
var _is_scene_running := false
var _runtime_log_enabled := false
var _runtime_log_path := ""
var _runtime_log_offset := 0
var _runtime_log_partial_line := ""
var _runtime_log_last_level := "info"
var _runtime_log_last_error := ""

func _ready() -> void:
	auth_token = _generate_token()
	_save_token_to_file()
	server.create_server(port)
	undo_redo = EditorInterface.get_editor_undo_redo()
	_setup_log_capture()

func _generate_token() -> String:
	var crypto = Crypto.new()
	return crypto.generate_random_bytes(32).hex_encode()

func _save_token_to_file():
	var dir_path = OS.get_user_data_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file = FileAccess.open(dir_path + "/ai_mcp_token", FileAccess.WRITE)
	if file:
		file.store_string(auth_token)
		file.close()

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
				var response := handle_request(JSON.parse_string(data), client)
				client.send_text(JSON.stringify(response))
		elif client.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			clients.erase(client)

func handle_request(req: Dictionary, client: WebSocketPeer = null) -> Dictionary:
	if req.get("auth_token", "") != auth_token:
		return {"id": req.get("id", ""), "ok": false, "error": {"code": "UNAUTHORIZED", "message": "Invalid token"}}
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
		"open_scene":
			return handle_open_scene(req)
		"get_editor_logs":
			return handle_get_logs(req)
		"get_input_map":
			return handle_get_input_map(req)
		"bind_input_key":
			return handle_bind_input_key(req)
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
		"instantiate_scene":
			return handle_instantiate_scene(req)
		"load_resource":
			return handle_load_resource(req)
		"save_current_scene":
			return handle_save_scene(req)
		"connect_signal":
			return handle_connect_signal(req)
		"disconnect_signal":
			return handle_disconnect_signal(req)
		"attach_script":
			return handle_attach_script(req)
		"get_resource_uid":
			return handle_get_resource_uid(req)
		"play_current_scene":
			return handle_play_scene(req)
		"stop_running_scene":
			return handle_stop_scene(req)
		"list_autoloads":
			return handle_list_autoloads(req)
		"set_autoload":
			return handle_set_autoload(req)
		"remove_autoload":
			return handle_remove_autoload(req)
		"add_node_to_group":
			return handle_add_node_to_group(req)
		"remove_node_from_group":
			return handle_remove_node_from_group(req)
		"reparent_node":
			return handle_reparent_node(req)
		"duplicate_node":
			return handle_duplicate_node(req)
		_:
			return {"id": req.id, "ok": false, "error": {"code": "UNKNOWN_METHOD", "message": "Unknown method"}}

func serialize_node(node: Node, depth: int) -> Dictionary:
	if not node or depth <= 0:
		return {}

	var result = {
		"name": node.name,
		"type": node.get_class(),
		"children": node.get_children().map(func(c): return serialize_node(c, depth - 1))
	}

	var props = {}
	for prop in node.get_property_list():
		if prop.usage & PROPERTY_USAGE_EDITOR:
			props[prop.name] = str(node.get(prop.name))
	if props.size() > 0:
		result["properties"] = props

	var script = node.get_script()
	if script:
		result["script"] = script.resource_path

	var groups = node.get_groups()
	if groups.size() > 0:
		result["groups"] = groups

	return result

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

func _validate_path(path: String) -> bool:
	return path.begins_with("res://") and not ".." in path and not "\\" in path

func _validate_scene_path(path: String) -> bool:
	return _validate_path(path) and path.ends_with(".tscn")

func _validate_identifier(value: String) -> bool:
	if value == "":
		return false
	var first = value.unicode_at(0)
	if not ((first >= 65 and first <= 90) or (first >= 97 and first <= 122) or first == 95):
		return false
	for index in range(1, value.length()):
		var code = value.unicode_at(index)
		if not ((code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			return false
	return true

func _validate_node_path(path: String) -> bool:
	return path != "" and path == path.strip_edges() and not ".." in path and not "\\" in path

func _validate_node_name(node_name: String) -> bool:
	return node_name != "" and node_name == node_name.strip_edges() and not "/" in node_name and not "\\" in node_name and not ".." in node_name

func _get_autoload_path(setting_value) -> String:
	var autoload_path = str(setting_value)
	return autoload_path.substr(1) if autoload_path.begins_with("*") else autoload_path

func _is_autoload_singleton(setting_value) -> bool:
	return str(setting_value).begins_with("*")

func _validate_class_name(class_name: String) -> bool:
	var blacklist = ["EditorInterface", "ScriptEditor", "OS", "EditorPlugin", "EditorScript", "FileAccess", "DirAccess", "IP", "HTTPRequest", "Engine"]
	return class_name not in blacklist

func _get_target_node(root: Node, node_path: String):
	return root if node_path == "." else root.get_node_or_null(node_path)

func _find_signal_connection_flags(source_node: Object, signal_name: String, callable: Callable) -> int:
	for connection in source_node.get_signal_connection_list(signal_name):
		if connection.get("callable") == callable:
			return int(connection.get("flags", 0))
	return -1

func _serialize_input_event(event: InputEvent) -> Dictionary:
	var data = {
		"class": event.get_class(),
		"as_text": event.as_text(),
	}
	if event is InputEventKey:
		data["keycode"] = event.keycode
		data["physical_keycode"] = event.physical_keycode
		data["ctrl"] = event.ctrl_pressed
		data["alt"] = event.alt_pressed
		data["shift"] = event.shift_pressed
		data["meta"] = event.meta_pressed
	return data

func _input_events_equal(left: InputEvent, right: InputEvent) -> bool:
	if left.get_class() != right.get_class():
		return false
	if left is InputEventKey and right is InputEventKey:
		return left.keycode == right.keycode and left.physical_keycode == right.physical_keycode and left.ctrl_pressed == right.ctrl_pressed and left.alt_pressed == right.alt_pressed and left.shift_pressed == right.shift_pressed and left.meta_pressed == right.meta_pressed
	return left.as_text() == right.as_text()

func _get_project_input_actions() -> Array[String]:
	var actions: Array[String] = []
	for prop in ProjectSettings.get_property_list():
		var property_name = str(prop.name)
		if property_name.begins_with("input/"):
			actions.append(property_name.substr(6))
	actions.sort()
	return actions

func _get_project_input_setting(action_name: String) -> Dictionary:
	var setting_key = "input/" + action_name
	var current_value = ProjectSettings.get_setting(setting_key, {"deadzone": 0.2, "events": []})
	if current_value is Dictionary:
		return current_value.duplicate(true)
	return {"deadzone": 0.2, "events": []}

func _get_keycode_from_name(key_name: String) -> Key:
	var normalized = key_name.strip_edges().to_upper()
	if normalized == "ENTER":
		return KEY_ENTER
	if normalized == "ESC" or normalized == "ESCAPE":
		return KEY_ESCAPE
	if normalized == "SPACE":
		return KEY_SPACE
	if normalized == "TAB":
		return KEY_TAB
	if normalized == "BACKSPACE":
		return KEY_BACKSPACE
	if normalized == "DELETE":
		return KEY_DELETE
	if normalized == "INSERT":
		return KEY_INSERT
	if normalized == "HOME":
		return KEY_HOME
	if normalized == "END":
		return KEY_END
	if normalized == "PAGE_UP":
		return KEY_PAGEUP
	if normalized == "PAGE_DOWN":
		return KEY_PAGEDOWN
	if normalized == "UP":
		return KEY_UP
	if normalized == "DOWN":
		return KEY_DOWN
	if normalized == "LEFT":
		return KEY_LEFT
	if normalized == "RIGHT":
		return KEY_RIGHT
	if normalized.length() == 1:
		var unicode_value = normalized.unicode_at(0)
		if unicode_value >= 65 and unicode_value <= 90:
			return unicode_value
		if unicode_value >= 48 and unicode_value <= 57:
			return unicode_value
	if normalized.is_valid_int():
		return int(normalized)
	return KEY_NONE

func _save_project_settings() -> Error:
	var save_err = ProjectSettings.save()
	if save_err == OK:
		InputMap.load_from_project_settings()
	return save_err

func handle_open_scene(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var scene_path = params.get("scene_path", "")

	if not _validate_path(scene_path):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_PATH", "message": "Invalid scene path: " + scene_path}}

	if not _validate_scene_path(scene_path):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_SCENE", "message": "Scene path must end with .tscn: " + scene_path}}

	if not ResourceLoader.exists(scene_path):
		return {"id": req.id, "ok": false, "error": {"code": "SCENE_NOT_FOUND", "message": "Scene not found: " + scene_path}}

	EditorInterface.open_scene_from_path(scene_path)
	return {"id": req.id, "ok": true, "data": {"scene_path": scene_path, "opened": true}}

func handle_get_input_map(req: Dictionary) -> Dictionary:
	var actions: Array[Dictionary] = []
	for action_name in _get_project_input_actions():
		var action_config = _get_project_input_setting(action_name)
		var serialized_events: Array[Dictionary] = []
		for event in action_config.get("events", []):
			serialized_events.append(_serialize_input_event(event))
		actions.append({
			"action_name": action_name,
			"deadzone": float(action_config.get("deadzone", 0.2)),
			"events": serialized_events,
		})
	return {"id": req.id, "ok": true, "data": {"actions": actions}}

func handle_bind_input_key(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var action_name = params.get("action_name", "").strip_edges()
	var key_name = params.get("key", "").strip_edges()

	if not _validate_identifier(action_name):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_ACTION", "message": "Action name must not be empty"}}

	var keycode = _get_keycode_from_name(key_name)
	if keycode == KEY_NONE:
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_KEY", "message": "Unsupported key: " + key_name}}

	var action_config = _get_project_input_setting(action_name)
	var events: Array = action_config.get("events", [])
	var event = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.ctrl_pressed = params.get("ctrl", false)
	event.alt_pressed = params.get("alt", false)
	event.shift_pressed = params.get("shift", false)
	event.meta_pressed = params.get("meta", false)

	for existing_event in events:
		if _input_events_equal(existing_event, event):
			return {"id": req.id, "ok": true, "data": {"action_name": action_name, "event_text": event.as_text(), "created": false}}

	events.append(event)
	action_config["events"] = events
	if not action_config.has("deadzone"):
		action_config["deadzone"] = 0.2
	ProjectSettings.set_setting("input/" + action_name, action_config)
	var save_err = _save_project_settings()
	if save_err != OK:
		return {"id": req.id, "ok": false, "error": {"code": "SAVE_FAILED", "message": "Failed to save input map changes: " + str(save_err)}}

	return {"id": req.id, "ok": true, "data": {"action_name": action_name, "event_text": event.as_text(), "created": true}}

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

	if not ClassDB.class_exists(node_type) or not _validate_class_name(node_type):
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

	if not ClassDB.class_exists(root_node_type) or not _validate_class_name(root_node_type):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_TYPE", "message": "Invalid node type: " + root_node_type}}

	var scene_path = "res://" + scene_name
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"

	if not _validate_path(scene_path):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_PATH", "message": "Invalid path: " + scene_path}}

	if ResourceLoader.exists(scene_path):
		return {"id": req.id, "ok": false, "error": {"code": "FILE_EXISTS", "message": "Scene already exists: " + scene_path}}

	var dir_path = scene_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var new_scene = ClassDB.instantiate(root_node_type)
	new_scene.name = scene_name.get_file().get_basename()

	var packed_scene = PackedScene.new()
	packed_scene.pack(new_scene)

	var err = ResourceSaver.save(packed_scene, scene_path)
	if err != OK:
		return {"id": req.id, "ok": false, "error": {"code": "SAVE_FAILED", "message": "Failed to create scene: " + str(err)}}

	return {"id": req.id, "ok": true, "data": {"scene_path": scene_path}}

func handle_instantiate_scene(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "instantiate_scene"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var parent_path = params.get("parent_path", "")
	var scene_path = params.get("scene_path", "")
	var node_name = params.get("node_name", "")

	if not _validate_path(scene_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_PATH", "message": "Invalid scene path: " + scene_path, "failed_step": step}}

	if not _validate_scene_path(scene_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_SCENE", "message": "Scene path must end with .tscn: " + scene_path, "failed_step": step}}

	if node_name != "" and not _validate_identifier(node_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_NODE_NAME", "message": "Invalid node name: " + node_name, "failed_step": step}}

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var parent = _get_target_node(root, parent_path)
	if not parent:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Parent not found: " + parent_path, "failed_step": step}}

	if not ResourceLoader.exists(scene_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "SCENE_NOT_FOUND", "message": "Scene not found: " + scene_path, "failed_step": step}}

	var packed_scene = ResourceLoader.load(scene_path)
	if not packed_scene or not (packed_scene is PackedScene):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_SCENE", "message": "Resource is not a PackedScene: " + scene_path, "failed_step": step}}

	var instance = packed_scene.instantiate()
	if not instance:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INSTANTIATE_FAILED", "message": "Failed to instantiate scene: " + scene_path, "failed_step": step}}

	if node_name != "":
		instance.name = node_name
	instance.owner = root

	undo_redo.add_do_method(parent, "add_child", instance)
	undo_redo.add_do_property(instance, "owner", root)
	undo_redo.add_undo_method(parent, "remove_child", instance)

	if auto_txn:
		handle_end_action({"id": ""})

	var created_path = instance.name if parent_path == "." else (parent_path + "/" + instance.name if parent_path != "" else instance.name)
	return {"id": req.id, "ok": true, "data": {"node_path": created_path, "scene_path": scene_path}}

func handle_load_resource(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var resource_path = params.get("resource_path", "")
	var resource_type = params.get("resource_type", "")

	if not _validate_path(resource_path):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_PATH", "message": "Invalid path: " + resource_path}}

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

func handle_connect_signal(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "connect_signal"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var source_node_path = params.get("source_node_path", "")
	var signal_name = params.get("signal_name", "")
	var target_node_path = params.get("target_node_path", "")
	var method_name = params.get("method_name", "")
	var deferred = params.get("deferred", false)
	var one_shot = params.get("one_shot", false)

	if not _validate_identifier(signal_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_SIGNAL", "message": "Invalid signal name: " + signal_name, "failed_step": step}}

	if not _validate_identifier(method_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_METHOD", "message": "Invalid method name: " + method_name, "failed_step": step}}

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var source_node = _get_target_node(root, source_node_path)
	if not source_node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Source node not found: " + source_node_path, "failed_step": step}}

	var target_node = _get_target_node(root, target_node_path)
	if not target_node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Target node not found: " + target_node_path, "failed_step": step}}

	if not source_node.has_signal(signal_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "SIGNAL_NOT_FOUND", "message": "Signal not found: " + signal_name, "failed_step": step}}

	if not target_node.has_method(method_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "METHOD_NOT_FOUND", "message": "Method not found on target node: " + method_name, "failed_step": step}}

	var callable = Callable(target_node, method_name)
	if source_node.is_connected(signal_name, callable):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "ALREADY_CONNECTED", "message": "Signal is already connected", "failed_step": step}}

	var flags = CONNECT_PERSIST
	if deferred:
		flags |= CONNECT_DEFERRED
	if one_shot:
		flags |= CONNECT_ONE_SHOT

	undo_redo.add_do_method(source_node, "connect", signal_name, callable, flags)
	undo_redo.add_undo_method(source_node, "disconnect", signal_name, callable)

	if auto_txn:
		handle_end_action({"id": ""})

	return {"id": req.id, "ok": true, "data": {"connected": true, "flags": flags}}

func handle_disconnect_signal(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "disconnect_signal"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var source_node_path = params.get("source_node_path", "")
	var signal_name = params.get("signal_name", "")
	var target_node_path = params.get("target_node_path", "")
	var method_name = params.get("method_name", "")

	if not _validate_identifier(signal_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_SIGNAL", "message": "Invalid signal name: " + signal_name, "failed_step": step}}

	if not _validate_identifier(method_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_METHOD", "message": "Invalid method name: " + method_name, "failed_step": step}}

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var source_node = _get_target_node(root, source_node_path)
	if not source_node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Source node not found: " + source_node_path, "failed_step": step}}

	var target_node = _get_target_node(root, target_node_path)
	if not target_node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Target node not found: " + target_node_path, "failed_step": step}}

	if not source_node.has_signal(signal_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "SIGNAL_NOT_FOUND", "message": "Signal not found: " + signal_name, "failed_step": step}}

	if not target_node.has_method(method_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "METHOD_NOT_FOUND", "message": "Method not found on target node: " + method_name, "failed_step": step}}

	var callable = Callable(target_node, method_name)
	var existing_flags = _find_signal_connection_flags(source_node, signal_name, callable)
	if existing_flags == -1:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "CONNECTION_NOT_FOUND", "message": "Signal connection not found", "failed_step": step}}

	undo_redo.add_do_method(source_node, "disconnect", signal_name, callable)
	undo_redo.add_undo_method(source_node, "connect", signal_name, callable, existing_flags)

	if auto_txn:
		handle_end_action({"id": ""})

	return {"id": req.id, "ok": true, "data": {"disconnected": true}}

func handle_attach_script(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "attach_script"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var node_path = params.get("node_path", "")
	var script_path = params.get("script_path", "")

	if not _validate_path(script_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_PATH", "message": "Invalid script path: " + script_path, "failed_step": step}}

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var node = root.get_node_or_null(node_path)
	if not node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Node not found: " + node_path, "failed_step": step}}

	if not ResourceLoader.exists(script_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "SCRIPT_NOT_FOUND", "message": "Script file does not exist: " + script_path, "suggestions": ["Verify script path", "Check file exists in project"]}}

	var script = ResourceLoader.load(script_path)
	if not script:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_SCRIPT", "message": "Failed to load script (syntax error or invalid format)", "suggestions": ["Fix script syntax errors before attaching"]}}

	if not script is GDScript:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_SCRIPT", "message": "Resource is not a GDScript: " + script.get_class()}}

	var old_script = node.get_script()
	undo_redo.add_do_method(node, "set_script", script)
	undo_redo.add_undo_method(node, "set_script", old_script)

	if auto_txn:
		handle_end_action({"id": ""})

	var resource_uid = ResourceLoader.get_resource_uid(script_path)
	return {"id": req.id, "ok": true, "data": {"attached_script": script_path, "resource_uid": str(resource_uid)}}

func handle_get_resource_uid(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var resource_path = params.get("resource_path", "")

	if not _validate_path(resource_path):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_PATH", "message": "Invalid path: " + resource_path}}

	if not ResourceLoader.exists(resource_path):
		return {"id": req.id, "ok": false, "error": {"code": "RESOURCE_NOT_FOUND", "message": "Resource not found: " + resource_path}}

	var resource = ResourceLoader.load(resource_path)
	if not resource:
		return {"id": req.id, "ok": false, "error": {"code": "LOAD_FAILED", "message": "Failed to load resource: " + resource_path}}

	var resource_uid = ResourceLoader.get_resource_uid(resource_path)
	var resource_type = resource.get_class()

	return {"id": req.id, "ok": true, "data": {"uid": str(resource_uid), "type": resource_type}}

# Phase 4: Scene execution & logging
func _setup_log_capture():
	_refresh_runtime_log_config()

func _add_log(level: String, message: String, source: String):
	_log_buffer.append({"timestamp": int(Time.get_unix_time_from_system()), "level": level, "message": message, "source": source})
	if _log_buffer.size() > _max_log_size:
		_log_buffer.pop_front()

func _get_project_setting(name: String, fallback):
	if ProjectSettings.has_method("get_setting_with_override") and ProjectSettings.has_setting(name):
		return ProjectSettings.get_setting_with_override(name)
	return ProjectSettings.get_setting(name, fallback)

func _refresh_runtime_log_config() -> void:
	_runtime_log_enabled = bool(_get_project_setting("debug/file_logging/enable_file_logging", true))
	var configured_path = str(_get_project_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	if configured_path == "":
		configured_path = "user://logs/godot.log"
	_runtime_log_path = ProjectSettings.globalize_path(configured_path)

func _reset_runtime_log_cursor() -> void:
	_refresh_runtime_log_config()
	_runtime_log_last_error = ""
	_runtime_log_partial_line = ""
	_runtime_log_last_level = "info"
	_runtime_log_offset = 0
	if not _runtime_log_enabled or _runtime_log_path == "":
		return
	if not FileAccess.file_exists(_runtime_log_path):
		return
	var log_file = FileAccess.open(_runtime_log_path, FileAccess.READ)
	if not log_file:
		_runtime_log_last_error = "Failed to open runtime log file: " + _runtime_log_path
		return
	_runtime_log_offset = log_file.get_length()
	log_file.close()

func _get_runtime_log_capture_status() -> Dictionary:
	_refresh_runtime_log_config()
	var status = {
		"mode": "file",
		"enabled": _runtime_log_enabled,
		"available": false,
		"log_path": _runtime_log_path,
		"message": "",
		"suggestions": []
	}

	if not _runtime_log_enabled:
		status["message"] = "Project setting debug/file_logging/enable_file_logging is disabled."
		status["suggestions"] = ["Enable Project Settings > Debug > File Logging > Enable File Logging."]
		return status

	if _runtime_log_path == "":
		status["message"] = "Could not resolve the runtime log path."
		status["suggestions"] = ["Set Project Settings > Debug > File Logging > Log Path or use the default user://logs/godot.log path."]
		return status

	if _runtime_log_last_error != "":
		status["message"] = _runtime_log_last_error
		status["suggestions"] = ["Confirm the log path is writable and readable by the editor.", "Run the current scene once to let Godot create the log file if needed."]
		return status

	if FileAccess.file_exists(_runtime_log_path):
		status["available"] = true
		status["message"] = "Runtime log capture is active."
		return status

	status["message"] = "Runtime log file has not been created yet."
	status["suggestions"] = ["Run the current scene once to let Godot create the file.", "Confirm Project Settings > Debug > File Logging is enabled."]
	return status

func _classify_runtime_log_level(message: String, previous_level: String) -> String:
	var normalized = message.strip_edges()
	var lower = normalized.to_lower()
	if normalized.begins_with("at:") or normalized.begins_with("from:") or lower.begins_with("stack trace") or lower.begins_with("script backtrace") or lower.begins_with("user script backtrace") or normalized.begins_with("at "):
		return previous_level if previous_level == "error" or previous_level == "warning" else "info"
	if lower.contains("error") or lower.contains("failed") or lower.contains("invalid ") or lower.contains("parse error") or lower.contains("script backtrace") or lower.contains("stack trace") or lower.contains("attempt to"):
		return "error"
	if lower.contains("warning") or lower.contains("deprecated"):
		return "warning"
	return "info"

func _poll_runtime_log() -> void:
	_refresh_runtime_log_config()
	_runtime_log_last_error = ""
	if not _runtime_log_enabled or _runtime_log_path == "":
		return
	if not FileAccess.file_exists(_runtime_log_path):
		return
	var log_file = FileAccess.open(_runtime_log_path, FileAccess.READ)
	if not log_file:
		_runtime_log_last_error = "Failed to open runtime log file: " + _runtime_log_path
		return

	var file_length = log_file.get_length()
	if file_length < _runtime_log_offset:
		_runtime_log_offset = 0
		_runtime_log_partial_line = ""
		_runtime_log_last_level = "info"

	if file_length == _runtime_log_offset:
		log_file.close()
		return

	log_file.seek(_runtime_log_offset)
	var chunk_size = file_length - _runtime_log_offset
	var runtime_chunk = log_file.get_buffer(chunk_size).get_string_from_utf8()
	_runtime_log_offset = file_length
	log_file.close()

	if _runtime_log_partial_line != "":
		runtime_chunk = _runtime_log_partial_line + runtime_chunk
		_runtime_log_partial_line = ""

	if runtime_chunk == "":
		return

	var normalized_chunk = runtime_chunk.replace("\r\n", "\n").replace("\r", "\n")
	var ends_with_newline = normalized_chunk.ends_with("\n")
	var lines = normalized_chunk.split("\n")
	if not ends_with_newline and lines.size() > 0:
		_runtime_log_partial_line = lines[lines.size() - 1]
		lines.resize(lines.size() - 1)

	for line in lines:
		var message = String(line).strip_edges()
		if message == "":
			continue
		var level = _classify_runtime_log_level(message, _runtime_log_last_level)
		_runtime_log_last_level = level
		_add_log(level, message, "runtime")

func handle_play_scene(req: Dictionary) -> Dictionary:
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open"}}
	_reset_runtime_log_cursor()
	_is_scene_running = true
	_add_log("info", "Scene started: " + root.scene_file_path, "editor")
	EditorInterface.play_current_scene()
	return {"id": req.id, "ok": true, "data": {"scene_path": root.scene_file_path, "status": "running", "log_capture": _get_runtime_log_capture_status()}}

func handle_stop_scene(req: Dictionary) -> Dictionary:
	_poll_runtime_log()
	EditorInterface.stop_playing_scene()
	_is_scene_running = false
	_add_log("info", "Scene stopped", "editor")
	return {"id": req.id, "ok": true, "data": {"stopped": true, "log_capture": _get_runtime_log_capture_status()}}

func handle_get_logs(req: Dictionary) -> Dictionary:
	_poll_runtime_log()
	var params = req.get("params", {})
	var since_ts = params.get("since_timestamp", 0)
	var filter_level = params.get("filter_level", "all")
	var filtered = _log_buffer.filter(func(log):
		return log.timestamp > since_ts and (filter_level == "all" or log.level == filter_level)
	)
	return {"id": req.id, "ok": true, "data": {"logs": filtered, "log_capture": _get_runtime_log_capture_status()}}

# Batch 2: Project and structure management
func handle_list_autoloads(req: Dictionary) -> Dictionary:
	var autoloads: Array[Dictionary] = []
	for prop in ProjectSettings.get_property_list():
		var property_name = str(prop.name)
		if property_name.begins_with("autoload/"):
			var autoload_name = property_name.substr(9)
			var autoload_setting = ProjectSettings.get_setting(property_name)
			autoloads.append({
				"name": autoload_name,
				"path": _get_autoload_path(autoload_setting),
				"is_singleton": _is_autoload_singleton(autoload_setting),
			})
	return {"id": req.id, "ok": true, "data": {"autoloads": autoloads}}

func handle_set_autoload(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var autoload_name = params.get("name", "")
	var autoload_path = params.get("path", "")
	var is_singleton = params.get("is_singleton", true)

	if not _validate_identifier(autoload_name):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_NAME", "message": "Invalid autoload name: " + autoload_name}}

	if not is_singleton:
		return {"id": req.id, "ok": false, "error": {"code": "UNSUPPORTED_AUTOLOAD_MODE", "message": "Only singleton autoloads are supported through the Godot EditorPlugin API"}}

	if not _validate_path(autoload_path):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_PATH", "message": "Invalid autoload path: " + autoload_path}}

	if not ResourceLoader.exists(autoload_path):
		return {"id": req.id, "ok": false, "error": {"code": "RESOURCE_NOT_FOUND", "message": "Resource not found: " + autoload_path}}

	if not editor_plugin:
		return {"id": req.id, "ok": false, "error": {"code": "PLUGIN_API_UNAVAILABLE", "message": "EditorPlugin API is not available for autoload management"}}

	var setting_key = "autoload/" + autoload_name
	if ProjectSettings.has_setting(setting_key):
		editor_plugin.remove_autoload_singleton(autoload_name)
	editor_plugin.add_autoload_singleton(autoload_name, autoload_path)

	var save_err = ProjectSettings.save()
	if save_err != OK:
		return {"id": req.id, "ok": false, "error": {"code": "SAVE_FAILED", "message": "Failed to save autoload settings: " + str(save_err)}}

	return {"id": req.id, "ok": true, "data": {"name": autoload_name, "path": autoload_path, "is_singleton": is_singleton}}

func handle_remove_autoload(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var autoload_name = params.get("name", "")

	if not _validate_identifier(autoload_name):
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_NAME", "message": "Invalid autoload name: " + autoload_name}}

	var setting_key = "autoload/" + autoload_name
	if not ProjectSettings.has_setting(setting_key):
		return {"id": req.id, "ok": false, "error": {"code": "AUTOLOAD_NOT_FOUND", "message": "Autoload not found: " + autoload_name}}

	if not editor_plugin:
		return {"id": req.id, "ok": false, "error": {"code": "PLUGIN_API_UNAVAILABLE", "message": "EditorPlugin API is not available for autoload management"}}

	editor_plugin.remove_autoload_singleton(autoload_name)

	var save_err = ProjectSettings.save()
	if save_err != OK:
		return {"id": req.id, "ok": false, "error": {"code": "SAVE_FAILED", "message": "Failed to save autoload settings: " + str(save_err)}}

	return {"id": req.id, "ok": true, "data": {"removed": autoload_name}}

func handle_add_node_to_group(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "add_node_to_group"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var node_path = params.get("node_path", "")
	var group_name = params.get("group_name", "")
	var persistent = params.get("persistent", false)

	if not _validate_node_path(node_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_NODE_PATH", "message": "Invalid node path: " + node_path, "failed_step": step}}

	if not _validate_identifier(group_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_GROUP", "message": "Invalid group name: " + group_name, "failed_step": step}}

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var node = _get_target_node(root, node_path)
	if not node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Node not found: " + node_path, "failed_step": step}}

	if node.is_in_group(group_name):
		if auto_txn:
			handle_end_action({"id": ""})
		return {"id": req.id, "ok": true, "data": {"node_path": node_path, "group": group_name, "already_in_group": true}}

	undo_redo.add_do_method(node, "add_to_group", group_name, persistent)
	undo_redo.add_undo_method(node, "remove_from_group", group_name)

	if auto_txn:
		handle_end_action({"id": ""})

	return {"id": req.id, "ok": true, "data": {"node_path": node_path, "group": group_name, "added": true}}

func handle_remove_node_from_group(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "remove_node_from_group"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var node_path = params.get("node_path", "")
	var group_name = params.get("group_name", "")

	if not _validate_node_path(node_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_NODE_PATH", "message": "Invalid node path: " + node_path, "failed_step": step}}

	if not _validate_identifier(group_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_GROUP", "message": "Invalid group name: " + group_name, "failed_step": step}}

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var node = _get_target_node(root, node_path)
	if not node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Node not found: " + node_path, "failed_step": step}}

	if not node.is_in_group(group_name):
		if auto_txn:
			handle_end_action({"id": ""})
		return {"id": req.id, "ok": true, "data": {"node_path": node_path, "group": group_name, "not_in_group": true}}

	undo_redo.add_do_method(node, "remove_from_group", group_name)
	undo_redo.add_undo_method(node, "add_to_group", group_name, false)

	if auto_txn:
		handle_end_action({"id": ""})

	return {"id": req.id, "ok": true, "data": {"node_path": node_path, "group": group_name, "removed": true}}

func handle_reparent_node(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "reparent_node"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var node_path = params.get("node_path", "")
	var new_parent_path = params.get("new_parent_path", "")
	var keep_global_transform = params.get("keep_global_transform", true)

	if not _validate_node_path(node_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_NODE_PATH", "message": "Invalid node path: " + node_path, "failed_step": step}}

	if not _validate_node_path(new_parent_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_NODE_PATH", "message": "Invalid new parent path: " + new_parent_path, "failed_step": step}}

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var node = _get_target_node(root, node_path)
	if not node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Node not found: " + node_path, "failed_step": step}}

	var new_parent = _get_target_node(root, new_parent_path)
	if not new_parent:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "New parent not found: " + new_parent_path, "failed_step": step}}

	if node == root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "CANNOT_REPARENT_ROOT", "message": "Cannot reparent the edited scene root", "failed_step": step}}

	if node == new_parent or node.is_ancestor_of(new_parent):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_PARENT", "message": "New parent cannot be the node itself or one of its descendants", "failed_step": step}}

	var old_parent = node.get_parent()
	if not old_parent:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_PARENT", "message": "Node has no parent", "failed_step": step}}

	if old_parent == new_parent:
		if auto_txn:
			handle_end_action({"id": ""})
		return {"id": req.id, "ok": true, "data": {"node_path": node_path, "old_parent": old_parent.name, "new_parent": new_parent.name, "unchanged": true}}

	var old_index = node.get_index()
	undo_redo.add_do_method(node, "reparent", new_parent, keep_global_transform)
	undo_redo.add_undo_method(node, "reparent", old_parent, keep_global_transform)
	undo_redo.add_undo_method(old_parent, "move_child", node, old_index)

	if auto_txn:
		handle_end_action({"id": ""})

	return {"id": req.id, "ok": true, "data": {"node_path": node_path, "old_parent": old_parent.name, "new_parent": new_parent.name}}

func handle_duplicate_node(req: Dictionary) -> Dictionary:
	var params = req.get("params", {})
	var txn_id = req.get("txn_id")
	var auto_txn = txn_id == null or txn_id == ""

	if auto_txn:
		txn_id = "auto_" + str(Time.get_ticks_msec())
		handle_begin_action({"id": "", "params": {"name": "duplicate_node"}, "txn_id": txn_id})

	current_txn.step_count += 1
	var step = current_txn.step_count

	var node_path = params.get("node_path", "")
	var new_name = params.get("new_name", "")

	if not _validate_node_path(node_path):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_NODE_PATH", "message": "Invalid node path: " + node_path, "failed_step": step}}

	if new_name != "" and not _validate_node_name(new_name):
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "INVALID_NODE_NAME", "message": "Invalid node name: " + new_name, "failed_step": step}}

	var root = EditorInterface.get_edited_scene_root()
	if not root:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_SCENE", "message": "No scene open", "failed_step": step}}

	var node = _get_target_node(root, node_path)
	if not node:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NODE_NOT_FOUND", "message": "Node not found: " + node_path, "failed_step": step}}

	var parent = node.get_parent()
	if not parent:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "NO_PARENT", "message": "Node has no parent", "failed_step": step}}

	var duplicate = node.duplicate()
	if not duplicate:
		rollback_txn()
		return {"id": req.id, "ok": false, "error": {"code": "DUPLICATE_FAILED", "message": "Failed to duplicate node", "failed_step": step}}

	if new_name != "":
		duplicate.name = new_name
	else:
		duplicate.name = node.name + "_copy"
	duplicate.owner = root

	undo_redo.add_do_method(parent, "add_child", duplicate)
	undo_redo.add_do_property(duplicate, "owner", root)
	undo_redo.add_undo_method(parent, "remove_child", duplicate)

	if auto_txn:
		handle_end_action({"id": ""})

	var parent_node = node.get_parent()
	var parent_path_str = ""
	if parent_node != root:
		parent_path_str = root.get_path_to(parent_node)
	var duplicate_path = duplicate.name if parent_path_str == "" else (parent_path_str + "/" + duplicate.name)
	return {"id": req.id, "ok": true, "data": {"original_path": node_path, "duplicate_path": duplicate_path}}
