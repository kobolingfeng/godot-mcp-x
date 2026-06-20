@tool
extends Node

## Maps JSON-RPC method names → command handler Callables, and dispatches.

const MODULES := [
	preload("res://addons/godot_mcp_x/commands/project_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/scene_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/node_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/script_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/editor_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/analysis_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/resource_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/input_map_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/animation_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/physics_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/node_3d_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/runtime_control_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/shader_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/audio_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/particle_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/navigation_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/tilemap_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/theme_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/animation_tree_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/batch_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/profiling_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/export_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/gridmap_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/skeleton_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/fs_commands.gd"),
	preload("res://addons/godot_mcp_x/commands/ui_commands.gd"),
]

var editor_plugin: EditorPlugin
var _handlers: Dictionary = {}


func _ready() -> void:
	_register()


func _register() -> void:
	for m in MODULES:
		var cmd: Node = m.new()
		cmd.editor_plugin = editor_plugin
		add_child(cmd)
		var cmds: Dictionary = cmd.get_commands()
		for mname: String in cmds:
			if _handlers.has(mname):
				push_warning("[MCP-X] Duplicate command '%s' — overwriting" % mname)
			_handlers[mname] = cmds[mname]
	print("[MCP-X] Registered %d commands" % _handlers.size())


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
