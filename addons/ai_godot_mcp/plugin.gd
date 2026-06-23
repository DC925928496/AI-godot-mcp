@tool
extends EditorPlugin

var _dock_instance = null
var _ws_server = null


func _enter_tree() -> void:
	var panel := PanelContainer.new()
	panel.name = "AI-godot-mcp"

	var label := Label.new()
	label.text = "AI-godot-mcp: WebSocket server on port 6550"
	panel.add_child(label)

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
