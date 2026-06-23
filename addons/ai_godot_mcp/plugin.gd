@tool
extends EditorPlugin

var _dock_instance = null
var _ws_server = null


func _enter_tree() -> void:
	var panel := VBoxContainer.new()
	panel.name = "AI-godot-mcp"

	var title := Label.new()
	title.text = "AI-godot-mcp: WebSocket server on port 6550"
	panel.add_child(title)

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Status: Connected"
	panel.add_child(status_label)

	var history_tree := Tree.new()
	history_tree.name = "HistoryTree"
	history_tree.set_columns(3)
	history_tree.set_column_titles_visible(true)
	history_tree.set_column_title(0, "Time")
	history_tree.set_column_title(1, "Method")
	history_tree.set_column_title(2, "Status")
	history_tree.custom_minimum_size.y = 200
	panel.add_child(history_tree)

	_dock_instance = panel
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock_instance)

	_ws_server = load("res://addons/ai_godot_mcp/websocket_server.gd").new()
	add_child(_ws_server)


func _exit_tree() -> void:
	if _ws_server:
		_ws_server.queue_free()
		_ws_server = null

	if _dock_instance != null:
		remove_control_from_docks(_dock_instance)
		_dock_instance.queue_free()
		_dock_instance = null
