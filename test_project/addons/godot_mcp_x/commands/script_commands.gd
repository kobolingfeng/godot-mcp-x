@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"read_script": _read_script,
		"create_script": _create_script,
		"write_script": _write_script,
		"edit_script": _edit_script,
		"attach_script": _attach_script,
		"validate_script": _validate_script,
		"list_scripts": _list_scripts,
	}


func _read_script(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if not FileAccess.file_exists(path):
		return fail("Script not found: %s" % path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fail("Cannot open: %s" % path)
	var text := f.get_as_text()
	f.close()
	return paginate_lines(path, text, params)


func _create_script(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if path == "":
		return fail("'path' is required")
	if FileAccess.file_exists(path):
		return fail("File already exists: %s (use write_script to overwrite)" % path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return fail("Cannot create: %s" % path)
	f.store_string(opt_str(params, "content", ""))
	f.close()
	fs_update(path)
	var attach := opt_str(params, "attach_to", "")
	if attach != "":
		var node := resolve_node(attach)
		if node == null:
			return fail("File created, but attach target not found: %s" % attach)
		node.set_script(load(path))
		mark_unsaved()
	return success({"created": path, "attached_to": attach})


func _write_script(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if path == "":
		return fail("'path' is required")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return fail("Cannot open for write: %s" % path)
	f.store_string(opt_str(params, "content", ""))
	f.close()
	fs_update(path)
	return success({"written": path})


func _edit_script(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	var old_text := opt_str(params, "old_text", "")
	if path == "" or old_text == "":
		return fail("'path' and 'old_text' are required")
	if not FileAccess.file_exists(path):
		return fail("Script not found: %s" % path)
	var rf := FileAccess.open(path, FileAccess.READ)
	var text := rf.get_as_text()
	rf.close()
	var count := text.count(old_text)
	if count == 0:
		return fail("old_text not found in file")
	if count > 1:
		return fail("old_text appears %d times — make it unique" % count)
	text = text.replace(old_text, opt_str(params, "new_text", ""))
	var wf := FileAccess.open(path, FileAccess.WRITE)
	wf.store_string(text)
	wf.close()
	fs_update(path)
	return success({"edited": path})


func _attach_script(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "node_path"))
	if node == null:
		return fail("Node not found: %s" % req_str(params, "node_path"))
	var sp := req_str(params, "script_path")
	if not FileAccess.file_exists(sp):
		return fail("Script not found: %s" % sp)
	var scr: Script = load(sp)
	if scr == null:
		return fail("Failed to load script: %s" % sp)
	node.set_script(scr)
	mark_unsaved()
	return success({"node": rel_path(node), "script": sp})


func _validate_script(params: Dictionary) -> Dictionary:
	var src := ""
	var path := opt_str(params, "path", "")
	if path != "":
		if not FileAccess.file_exists(path):
			return fail("Script not found: %s" % path)
		var f := FileAccess.open(path, FileAccess.READ)
		src = f.get_as_text()
		f.close()
	elif has_key(params, "content"):
		src = opt_str(params, "content", "")
	else:
		return fail("Provide 'path' or 'content'")
	var gd := GDScript.new()
	gd.source_code = src
	var err := gd.reload(true)
	return success({"valid": err == OK, "error_code": err})


func _list_scripts(params: Dictionary) -> Dictionary:
	var root := opt_str(params, "path", "res://")
	var files: Array = []
	_walk_gd(root, files)
	files.sort()
	var total := files.size()
	var offset := opt_int(params, "offset", 0)
	var limit := opt_int(params, "limit", 300)
	return success({
		"total": total,
		"offset": offset,
		"limit": limit,
		"has_more": offset + limit < total,
		"scripts": files.slice(offset, offset + limit),
	})


func _walk_gd(dir_path: String, acc: Array) -> void:
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
				_walk_gd(full, acc)
		elif name.ends_with(".gd"):
			acc.append(full)
		name = d.get_next()
	d.list_dir_end()
