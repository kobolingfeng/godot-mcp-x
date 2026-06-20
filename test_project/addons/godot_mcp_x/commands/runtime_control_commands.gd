@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## Editor-side control of game playback. The runtime inspection commands live in
## runtime_bridge.gd (autoload, runs in the game process).


func get_commands() -> Dictionary:
	return {
		"play_scene": _play_scene,
		"stop_scene": _stop_scene,
		"is_game_running": _is_game_running,
	}


func _play_scene(params: Dictionary) -> Dictionary:
	var path := opt_str(params, "path", "")
	if path != "":
		if not FileAccess.file_exists(path):
			return fail("Scene not found: %s" % path)
		EditorInterface.play_custom_scene(path)
		return success({"playing": path})
	if edited_root() != null:
		EditorInterface.play_current_scene()
		return success({"playing": "current scene"})
	EditorInterface.play_main_scene()
	return success({"playing": "main scene"})


func _stop_scene(_params: Dictionary) -> Dictionary:
	EditorInterface.stop_playing_scene()
	return success({"stopped": true})


func _is_game_running(_params: Dictionary) -> Dictionary:
	return success({"playing": EditorInterface.is_playing_scene()})
