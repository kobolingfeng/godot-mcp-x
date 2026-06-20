@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## Project file management. Operates on res:// paths via DirAccess and rescans the
## editor filesystem afterward. Deliberately safe: single file or EMPTY folder
## only (no recursive delete). Note: moves/renames do NOT rewrite references in
## other scenes — fix those separately if needed.


func get_commands() -> Dictionary:
	return {
		"create_folder": _create_folder,
		"rename_path": _rename,
		"delete_path": _delete,
		"duplicate_path": _duplicate,
	}


func _rescan() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()


func _create_folder(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if path == "":
		return fail("'path' is required")
	var err := DirAccess.make_dir_recursive_absolute(globalize(path))
	if err != OK:
		return fail("Create folder failed (error %d)" % err)
	_rescan()
	return success({"created": path})


func _rename(params: Dictionary) -> Dictionary:
	var from := req_str(params, "from")
	var to := req_str(params, "to")
	if from == "" or to == "":
		return fail("'from' and 'to' are required (rename also moves across folders)")
	var err := DirAccess.rename_absolute(globalize(from), globalize(to))
	if err != OK:
		return fail("Rename failed (error %d)" % err)
	_rescan()
	return success({"renamed": "%s -> %s" % [from, to]})


func _delete(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if path == "":
		return fail("'path' is required")
	var abs := globalize(path)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(abs)
		if err != OK:
			return fail("Delete failed (error %d)" % err)
		# Also drop Godot sidecar metadata so the folder isn't left non-empty.
		for ext in [".uid", ".import"]:
			if FileAccess.file_exists(path + ext):
				DirAccess.remove_absolute(globalize(path + ext))
		_rescan()
		return success({"deleted": path})
	if DirAccess.open(abs) != null:
		if opt_bool(params, "recursive", false):
			_rm_rf(abs)
		else:
			var err := DirAccess.remove_absolute(abs)
			if err != OK:
				return fail("Folder not empty — pass recursive=true to delete its contents (error %d)" % err)
		_rescan()
		return success({"deleted": path, "recursive": opt_bool(params, "recursive", false)})
	return fail("Not found: %s" % path)


func _rm_rf(abs_dir: String) -> void:
	var d := DirAccess.open(abs_dir)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := abs_dir.path_join(name)
		if d.current_is_dir():
			_rm_rf(full)
		else:
			DirAccess.remove_absolute(full)
		name = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(abs_dir)


func _duplicate(params: Dictionary) -> Dictionary:
	var from := req_str(params, "from")
	var to := req_str(params, "to")
	if from == "" or to == "":
		return fail("'from' and 'to' are required")
	if not FileAccess.file_exists(from):
		return fail("File not found: %s" % from)
	var err := DirAccess.copy_absolute(globalize(from), globalize(to))
	if err != OK:
		return fail("Duplicate failed (error %d)" % err)
	_rescan()
	return success({"duplicated": "%s -> %s" % [from, to]})
