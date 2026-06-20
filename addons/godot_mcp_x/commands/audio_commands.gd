@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## Bus changes are applied to the live AudioServer and persisted by saving the
## project's bus layout resource.


func get_commands() -> Dictionary:
	return {
		"add_audio_player": _add_audio_player,
		"list_audio_buses": _list_audio_buses,
		"add_audio_bus": _add_audio_bus,
		"set_bus_volume": _set_bus_volume,
		"add_bus_effect": _add_bus_effect,
	}


func _layout_path() -> String:
	return ProjectSettings.get_setting("audio/buses/default_bus_layout", "res://default_bus_layout.tres")


func _save_layout() -> int:
	return ResourceSaver.save(AudioServer.generate_bus_layout(), _layout_path())


func _add_audio_player(params: Dictionary) -> Dictionary:
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail("Parent not found")
	var player: Node
	match opt_str(params, "dimension", "plain"):
		"2d":
			player = AudioStreamPlayer2D.new()
		"3d":
			player = AudioStreamPlayer3D.new()
		_:
			player = AudioStreamPlayer.new()
	player.name = opt_str(params, "name", player.get_class())
	var stream_path := opt_str(params, "stream", "")
	if stream_path != "" and ResourceLoader.exists(stream_path):
		player.set("stream", load(stream_path))
	if has_key(params, "bus"):
		player.set("bus", req_str(params, "bus"))
	add_node_undoable(parent, player, "Add %s" % player.get_class())
	return success({"path": rel_path(player), "type": player.get_class()})


func _list_audio_buses(_params: Dictionary) -> Dictionary:
	var buses: Array = []
	for i in range(AudioServer.get_bus_count()):
		var effects: Array = []
		for e in range(AudioServer.get_bus_effect_count(i)):
			effects.append(AudioServer.get_bus_effect(i, e).get_class())
		buses.append({
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"muted": AudioServer.is_bus_mute(i),
			"effects": effects,
		})
	return success({"buses": buses, "count": buses.size()})


func _add_audio_bus(params: Dictionary) -> Dictionary:
	var name := req_str(params, "name")
	if name == "":
		return fail("'name' is required")
	AudioServer.add_bus()
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, name)
	if has_key(params, "send"):
		AudioServer.set_bus_send(idx, req_str(params, "send"))
	var err := _save_layout()
	if err != OK:
		return fail("Failed to save bus layout (error %d)" % err)
	return success({"bus": name, "index": idx})


func _set_bus_volume(params: Dictionary) -> Dictionary:
	var bus := req_str(params, "bus")
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return fail("Bus not found: %s" % bus)
	AudioServer.set_bus_volume_db(idx, float(params.get("volume_db", 0.0)))
	var err := _save_layout()
	if err != OK:
		return fail("Failed to save bus layout (error %d)" % err)
	return success({"bus": bus, "volume_db": AudioServer.get_bus_volume_db(idx)})


func _add_bus_effect(params: Dictionary) -> Dictionary:
	var bus := req_str(params, "bus")
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return fail("Bus not found: %s" % bus)
	var cls := "AudioEffect" + req_str(params, "effect")
	if not ClassDB.can_instantiate(cls):
		return fail("Unknown effect '%s' (try Reverb, Delay, Distortion, EQ, Compressor…)" % req_str(params, "effect"))
	AudioServer.add_bus_effect(idx, ClassDB.instantiate(cls))
	var err := _save_layout()
	if err != OK:
		return fail("Failed to save bus layout (error %d)" % err)
	return success({"bus": bus, "effect": cls})
