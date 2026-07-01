@tool
extends Node

## Maps JSON-RPC method names → command handler Callables, and dispatches.

const MODULE_PATHS := [
	"res://addons/godot_mcp_x/commands/project_commands.gd",
	"res://addons/godot_mcp_x/commands/scene_commands.gd",
	"res://addons/godot_mcp_x/commands/node_commands.gd",
	"res://addons/godot_mcp_x/commands/script_commands.gd",
	"res://addons/godot_mcp_x/commands/editor_commands.gd",
	"res://addons/godot_mcp_x/commands/analysis_commands.gd",
	"res://addons/godot_mcp_x/commands/resource_commands.gd",
	"res://addons/godot_mcp_x/commands/input_map_commands.gd",
	"res://addons/godot_mcp_x/commands/animation_commands.gd",
	"res://addons/godot_mcp_x/commands/physics_commands.gd",
	"res://addons/godot_mcp_x/commands/node_3d_commands.gd",
	"res://addons/godot_mcp_x/commands/runtime_control_commands.gd",
	"res://addons/godot_mcp_x/commands/shader_commands.gd",
	"res://addons/godot_mcp_x/commands/audio_commands.gd",
	"res://addons/godot_mcp_x/commands/particle_commands.gd",
	"res://addons/godot_mcp_x/commands/navigation_commands.gd",
	"res://addons/godot_mcp_x/commands/tilemap_commands.gd",
	"res://addons/godot_mcp_x/commands/theme_commands.gd",
	"res://addons/godot_mcp_x/commands/animation_tree_commands.gd",
	"res://addons/godot_mcp_x/commands/batch_commands.gd",
	"res://addons/godot_mcp_x/commands/profiling_commands.gd",
	"res://addons/godot_mcp_x/commands/export_commands.gd",
	"res://addons/godot_mcp_x/commands/gridmap_commands.gd",
	"res://addons/godot_mcp_x/commands/skeleton_commands.gd",
	"res://addons/godot_mcp_x/commands/fs_commands.gd",
	"res://addons/godot_mcp_x/commands/ui_commands.gd",
	"res://addons/godot_mcp_x/commands/mp_commands.gd",
]

var editor_plugin: EditorPlugin
var _handlers: Dictionary = {}
var _command_nodes: Array[Node] = []


func _ready() -> void:
	_register()


func _register() -> void:
	for path in MODULE_PATHS:
		var script: Script = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
		if script == null:
			push_error("[MCP-X] Failed to load command module: %s" % path)
			continue
		var cmd: Node = script.new()
		cmd.editor_plugin = editor_plugin
		add_child(cmd)
		_command_nodes.append(cmd)
		var cmds: Dictionary = cmd.get_commands()
		for mname: String in cmds:
			if _handlers.has(mname):
				push_warning("[MCP-X] Duplicate command '%s' — overwriting" % mname)
			_handlers[mname] = cmds[mname]
	print("[MCP-X] Registered %d commands" % _handlers.size())


func reload_commands() -> Dictionary:
	for cmd in _command_nodes:
		if is_instance_valid(cmd):
			remove_child(cmd)
			cmd.queue_free()
	_command_nodes.clear()
	_handlers.clear()
	_register()
	return {"commands": _handlers.size()}


func methods() -> Array:
	return _handlers.keys()


## Returns a Dictionary that is either {"result": ...} or {"error": {...}}.
func execute(method: String, params: Dictionary) -> Dictionary:
	if not _handlers.has(method):
		return {
			"error": {
				"code": -32601,
				"message": "Method not found: %s" % method,
				"data": {"available": _handlers.keys()},
			}
		}
	var handler: Callable = _handlers[method]
	# Handlers may or may not be coroutines; await works for both in GDScript 4.
	var result: Variant = await handler.call(params)
	if result is Dictionary:
		return result
	return {"result": result}
