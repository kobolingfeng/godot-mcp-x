@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## In Godot 4.x animations live inside an AnimationLibrary on the player, not
## directly on the AnimationPlayer. We use the default ("") library.


func get_commands() -> Dictionary:
	return {
		"list_animations": _list_animations,
		"get_animation_info": _get_animation_info,
		"create_animation": _create_animation,
		"add_animation_track": _add_animation_track,
		"set_animation_keyframe": _set_animation_keyframe,
	}


func _player(path: String) -> AnimationPlayer:
	return resolve_node(path) as AnimationPlayer


func _list_animations(params: Dictionary) -> Dictionary:
	var p := _player(req_str(params, "player_path"))
	if p == null:
		return fail("AnimationPlayer not found at: %s" % req_str(params, "player_path"))
	var anims: Array = []
	for a in p.get_animation_list():
		anims.append(String(a))
	return success({"player": rel_path(p), "animations": anims, "count": anims.size()})


func _get_animation_info(params: Dictionary) -> Dictionary:
	var p := _player(req_str(params, "player_path"))
	if p == null:
		return fail("AnimationPlayer not found")
	var aname := req_str(params, "name")
	if not p.has_animation(aname):
		return fail("Animation not found: %s" % aname)
	var anim := p.get_animation(aname)
	var tracks: Array = []
	for i in range(anim.get_track_count()):
		tracks.append({"index": i, "path": String(anim.track_get_path(i)), "type": anim.track_get_type(i)})
	return success({
		"name": aname,
		"length": anim.length,
		"loop_mode": anim.loop_mode,
		"track_count": anim.get_track_count(),
		"tracks": tracks,
	})


func _ensure_library(p: AnimationPlayer) -> AnimationLibrary:
	for ln in p.get_animation_library_list():
		if String(ln) == "":
			return p.get_animation_library(ln)
	var lib := AnimationLibrary.new()
	p.add_animation_library("", lib)
	return lib


func _create_animation(params: Dictionary) -> Dictionary:
	var p := _player(req_str(params, "player_path"))
	if p == null:
		return fail("AnimationPlayer not found")
	var aname := req_str(params, "name")
	if aname == "":
		return fail("'name' is required")
	if p.has_animation(aname):
		return fail("Animation already exists: %s" % aname)
	var anim := Animation.new()
	anim.length = float(params.get("length", 1.0))
	var err := _ensure_library(p).add_animation(aname, anim)
	if err != OK:
		return fail("add_animation failed (error %d)" % err)
	mark_unsaved()
	return success({"player": rel_path(p), "name": aname, "length": anim.length})


func _add_animation_track(params: Dictionary) -> Dictionary:
	var p := _player(req_str(params, "player_path"))
	if p == null:
		return fail("AnimationPlayer not found")
	var aname := req_str(params, "anim_name")
	if not p.has_animation(aname):
		return fail("Animation not found: %s" % aname)
	var node_path := req_str(params, "node_path")
	var prop := req_str(params, "property")
	if node_path == "" or prop == "":
		return fail("'node_path' and 'property' are required")
	var anim := p.get_animation(aname)
	var idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath(node_path + ":" + prop))
	mark_unsaved()
	return success({"anim": aname, "track_index": idx, "path": node_path + ":" + prop})


func _set_animation_keyframe(params: Dictionary) -> Dictionary:
	var p := _player(req_str(params, "player_path"))
	if p == null:
		return fail("AnimationPlayer not found")
	var aname := req_str(params, "anim_name")
	if not p.has_animation(aname):
		return fail("Animation not found: %s" % aname)
	var anim := p.get_animation(aname)
	var track := opt_int(params, "track_index", -1)
	if track < 0 or track >= anim.get_track_count():
		return fail("Invalid track_index: %d" % track)
	if not params.has("value"):
		return fail("'value' is required")
	var time := float(params.get("time", 0.0))
	anim.track_insert_key(track, time, coerce_to(null, params["value"]))
	mark_unsaved()
	return success({"anim": aname, "track": track, "time": time})
