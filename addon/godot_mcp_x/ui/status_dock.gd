@tool
extends VBoxContainer

## Editor dock showing godot-mcp-x live status: which MCP server ports the editor
## is connected to, how many commands are registered, and whether a game is
## playing. Refreshes ~1×/sec.

var ws_client: Node
var router: Node
var _info: Label
var _elapsed := 0.0


func _ready() -> void:
	name = "MCP-X"
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "godot-mcp-x"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	_refresh()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.0:
		_elapsed = 0.0
		_refresh()


func _refresh() -> void:
	var ports: Array = []
	if is_instance_valid(ws_client) and ws_client.has_method("get_connected_ports"):
		ports = ws_client.get_connected_ports()
	var cmds := 0
	if is_instance_valid(router) and router.has_method("methods"):
		cmds = router.methods().size()
	var status := "● connected" if not ports.is_empty() else "○ waiting for server…"
	var playing := EditorInterface.is_playing_scene()
	_info.text = "%s\nPorts: %s\nCommands: %d\nGame: %s" % [
		status,
		str(ports) if not ports.is_empty() else "(none)",
		cmds,
		"▶ playing" if playing else "■ stopped",
	]
