extends Node

var server := WebSocketPeer.new()
var clients: Array[WebSocketPeer] = []
var port := 6550
var undo_redo: EditorUndoRedoManager
var current_txn := {}  # {id: String, name: String, step_count: int}
var auth_token := ""

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
		"get_editor_logs":
			return handle_get_logs(req)
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
		"attach_script":
			return handle_attach_script(req)
		"get_resource_uid":
			return handle_get_resource_uid(req)
		"play_current_scene":
			return handle_play_scene(req)
		"stop_running_scene":
			return handle_stop_scene(req)
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
	return path.begins_with("res://") and not ".." in path

func _validate_class_name(class_name: String) -> bool:
	var blacklist = ["EditorInterface", "ScriptEditor", "OS", "EditorPlugin", "EditorScript", "FileAccess", "DirAccess", "IP", "HTTPRequest", "Engine"]
	return class_name not in blacklist

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
