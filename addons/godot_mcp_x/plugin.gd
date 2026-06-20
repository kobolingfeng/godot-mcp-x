@tool
extends EditorPlugin

## godot-mcp-x editor plugin entry point.
## Spins up the command router and the WebSocket client that dials the MCP
## server(s) on ports 6605-6609.

const WSClient := preload("res://addons/godot_mcp_x/transport/ws_client.gd")
const Router := preload("res://addons/godot_mcp_x/core/router.gd")
const StatusDock := preload("res://addons/godot_mcp_x/ui/status_dock.gd")

const RUNTIME_AUTOLOAD := "McpXRuntime"
const RUNTIME_PATH := "res://addons/godot_mcp_x/runtime/runtime_bridge.gd"

var _ws: Node
var _router: Node
var _dock: Control


func _enter_tree() -> void:
	_router = Router.new()
	_router.name = "McpXRouter"
	_router.editor_plugin = self
	add_child(_router)

	_ws = WSClient.new()
	_ws.name = "McpXWsClient"
	_ws.router = _router
	add_child(_ws)
	_ws.start()

	_dock = StatusDock.new()
	_dock.ws_client = _ws
	_dock.router = _router
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, _dock)

	# Register the runtime bridge so it auto-starts inside the played game.
	if not ProjectSettings.has_setting("autoload/" + RUNTIME_AUTOLOAD):
		add_autoload_singleton(RUNTIME_AUTOLOAD, RUNTIME_PATH)

	print("[MCP-X] Plugin enabled — dialing ws://127.0.0.1:6605-6609")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if _ws:
		_ws.stop()
		_ws.queue_free()
		_ws = null
	if _router:
		_router.queue_free()
		_router = null
	if ProjectSettings.has_setting("autoload/" + RUNTIME_AUTOLOAD):
		remove_autoload_singleton(RUNTIME_AUTOLOAD)
	print("[MCP-X] Plugin disabled")
