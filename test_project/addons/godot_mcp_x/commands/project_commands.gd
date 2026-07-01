@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_project_info": _get_project_info,
		"get_project_settings": _get_project_settings,
		"set_project_setting": _set_project_setting,
		"get_filesystem_tree": _get_filesystem_tree,
		"list_autoloads": _list_autoloads,
		"add_autoload": _add_autoload,
		"remove_autoload": _remove_autoload,
		"uid_to_path": _uid_to_path,
		"path_to_uid": _path_to_uid,
	}


func _get_project_info(_params: Dictionary) -> Dictionary:
	return success({
		"project_name": ProjectSettings.get_setting("application/config/name", ""),
		"godot_version": Engine.get_version_info(),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"viewport": {
			"width": ProjectSettings.get_setting("display/window/size/viewport_width", 0),
			"height": ProjectSettings.get_setting("display/window/size/viewport_height", 0),
		},
		"autoloads": _autoloads(),
	})


func _autoloads() -> Dictionary:
	var out: Dictionary = {}
	for prop in ProjectSettings.get_property_list():
		var n: String = prop.get("name", "")
		if n.begins_with("autoload/"):
			out[n.substr(9)] = str(ProjectSettings.get_setting(n))
	return out


func _list_autoloads(_params: Dictionary) -> Dictionary:
	return success(_autoloads())


func _get_project_settings(params: Dictionary) -> Dictionary:
	var key := opt_str(params, "key", "")
	var section := opt_str(params, "section", "")
	if key != "":
		if not ProjectSettings.has_setting(key):
			return fail("Setting not found: %s" % key)
		return success({key: Serialize.to_json(ProjectSettings.get_setting(key))})

	var out: Dictionary = {}
	if section != "":
		for prop in ProjectSettings.get_property_list():
			var n: String = prop.get("name", "")
			if n.begins_with(section):
				out[n] = Serialize.to_json(ProjectSettings.get_setting(n))
		return success(out)

	# No filter → curated overview instead of dumping the entire file.
	for k in [
		"application/config/name",
		"application/run/main_scene",
		"display/window/size/viewport_width",
		"display/window/size/viewport_height",
		"rendering/renderer/rendering_method",
		"physics/common/physics_ticks_per_second",
	]:
		if ProjectSettings.has_setting(k):
			out[k] = Serialize.to_json(ProjectSettings.get_setting(k))
	return success(out)


func _set_project_setting(params: Dictionary) -> Dictionary:
	var key := req_str(params, "key")
	if key == "":
		return fail("'key' is required")
	if not params.has("value"):
		return fail("'value' is required")
	var current: Variant = ProjectSettings.get_setting(key) if ProjectSettings.has_setting(key) else null
	var value: Variant = coerce_to(current, params["value"])
	ProjectSettings.set_setting(key, value)
	var err := ProjectSettings.save()
	if err != OK:
		return fail("Failed to save project.godot (error %d)" % err)
	return success({"key": key, "value": Serialize.to_json(value)})


func _get_filesystem_tree(params: Dictionary) -> Dictionary:
	var root := opt_str(params, "path", "res://")
	var filter := opt_str(params, "filter", "")
	var max_depth := opt_int(params, "max_depth", 8)
	var sort := opt_bool(params, "sort", true)
	var sink := sorted_scan_state(params, 500) if sort else page_state(params, 500)
	if sort:
		_walk_sorted(root, 0, max_depth, filter, sink)
	else:
		_walk_unsorted(root, 0, max_depth, filter, sink)
	var result := sorted_scan_result(sink, params, 500, "files") if sort else page_result(sink, "files")
	result["root"] = root
	return success(result)


func _walk_sorted(dir_path: String, depth: int, max_depth: int, filter: String, sink: Dictionary) -> void:
	if depth > max_depth:
		return
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if name != ".godot":
				_walk_sorted(full, depth + 1, max_depth, filter, sink)
		elif not name.ends_with(".import"):
			if filter == "" or name.matchn(filter):
				if bool(sink.get("bounded", false)):
					sorted_scan_add(sink, full)
				else:
					var items: Array = sink["items"]
					if items.size() < SORTED_PAGE_BULK_LIMIT:
						items.append(full)
					else:
						sorted_scan_add(sink, full)
		name = d.get_next()
	d.list_dir_end()


func _walk_unsorted(dir_path: String, depth: int, max_depth: int, filter: String, sink: Dictionary) -> void:
	if depth > max_depth:
		return
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if name != ".godot":
				_walk_unsorted(full, depth + 1, max_depth, filter, sink)
		elif not name.ends_with(".import"):
			if filter == "" or name.matchn(filter):
				page_add(sink, full)
		name = d.get_next()
	d.list_dir_end()


func _add_autoload(params: Dictionary) -> Dictionary:
	var n := req_str(params, "name")
	var path := req_str(params, "path")
	if n == "" or path == "":
		return fail("'name' and 'path' are required")
	if not FileAccess.file_exists(path):
		return fail("Path does not exist: %s" % path)
	ProjectSettings.set_setting("autoload/%s" % n, "*" + path)
	var err := ProjectSettings.save()
	if err != OK:
		return fail("Save failed (error %d)" % err)
	return success({"name": n, "path": path})


func _remove_autoload(params: Dictionary) -> Dictionary:
	var n := req_str(params, "name")
	var key := "autoload/%s" % n
	if not ProjectSettings.has_setting(key):
		return fail("Autoload not found: %s" % n)
	ProjectSettings.set_setting(key, null)
	var err := ProjectSettings.save()
	if err != OK:
		return fail("Save failed (error %d)" % err)
	return success({"removed": n})


func _uid_to_path(params: Dictionary) -> Dictionary:
	var uid := req_str(params, "uid")
	var id := ResourceUID.text_to_id(uid)
	if id == -1 or not ResourceUID.has_id(id):
		return fail("Unknown UID: %s" % uid)
	return success({"uid": uid, "path": ResourceUID.get_id_path(id)})


func _path_to_uid(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	var id := ResourceLoader.get_resource_uid(path)
	if id == -1:
		return fail("No UID for path: %s" % path)
	return success({"path": path, "uid": ResourceUID.id_to_text(id)})
