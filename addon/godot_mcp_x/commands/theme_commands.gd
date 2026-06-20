@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_theme": _create_theme,
		"set_theme_color": _set_color,
		"set_theme_constant": _set_constant,
		"set_theme_font_size": _set_font_size,
		"set_theme_stylebox": _set_stylebox,
		"get_theme_info": _info,
		"apply_theme": _apply,
	}


func _load_theme(path: String) -> Theme:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Theme


func _create_theme(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if path == "":
		return fail("'path' is required")
	var t := Theme.new()
	if has_key(params, "default_font_size"):
		t.default_font_size = opt_int(params, "default_font_size", 16)
	var err := ResourceSaver.save(t, path)
	if err != OK:
		return fail("Save failed (error %d)" % err)
	fs_update(path)
	return success({"created": path})


func _set_color(params: Dictionary) -> Dictionary:
	var t := _load_theme(req_str(params, "path"))
	if t == null:
		return fail("Theme not found")
	var name := req_str(params, "name")
	var type := req_str(params, "type")
	if name == "" or type == "":
		return fail("'name' and 'type' are required (type = control class, e.g. 'Button')")
	var c: Variant = str_to_var(opt_str(params, "color", "Color(1,1,1,1)"))
	if not (c is Color):
		return fail("Invalid color — use 'Color(r,g,b,a)'")
	t.set_color(name, type, c)
	ResourceSaver.save(t, req_str(params, "path"))
	return success({"set": "%s/%s" % [type, name]})


func _set_constant(params: Dictionary) -> Dictionary:
	var t := _load_theme(req_str(params, "path"))
	if t == null:
		return fail("Theme not found")
	var name := req_str(params, "name")
	var type := req_str(params, "type")
	if name == "" or type == "":
		return fail("'name' and 'type' are required")
	t.set_constant(name, type, opt_int(params, "value", 0))
	ResourceSaver.save(t, req_str(params, "path"))
	return success({"set": "%s/%s = %d" % [type, name, opt_int(params, "value", 0)]})


func _set_font_size(params: Dictionary) -> Dictionary:
	var t := _load_theme(req_str(params, "path"))
	if t == null:
		return fail("Theme not found")
	var name := req_str(params, "name")
	var type := req_str(params, "type")
	if name == "" or type == "":
		return fail("'name' and 'type' are required")
	t.set_font_size(name, type, opt_int(params, "size", 16))
	ResourceSaver.save(t, req_str(params, "path"))
	return success({"set": "%s/%s = %d" % [type, name, opt_int(params, "size", 16)]})


func _set_stylebox(params: Dictionary) -> Dictionary:
	var t := _load_theme(req_str(params, "path"))
	if t == null:
		return fail("Theme not found")
	var name := req_str(params, "name")
	var type := req_str(params, "type")
	if name == "" or type == "":
		return fail("'name' and 'type' are required")
	var sb: StyleBox
	match opt_str(params, "stylebox", "flat"):
		"empty":
			sb = StyleBoxEmpty.new()
		"texture":
			sb = StyleBoxTexture.new()
		_:
			var flat := StyleBoxFlat.new()
			if has_key(params, "bg_color"):
				var c: Variant = str_to_var(req_str(params, "bg_color"))
				if c is Color:
					flat.bg_color = c
			sb = flat
	t.set_stylebox(name, type, sb)
	ResourceSaver.save(t, req_str(params, "path"))
	return success({"set": "%s/%s" % [type, name], "stylebox": sb.get_class()})


func _info(params: Dictionary) -> Dictionary:
	var t := _load_theme(req_str(params, "path"))
	if t == null:
		return fail("Theme not found")
	var types: Array = []
	for ty in t.get_type_list():
		types.append(String(ty))
	return success({"path": req_str(params, "path"), "default_font_size": t.default_font_size, "types": types})


func _apply(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "node_path"))
	if node == null or not (node is Control):
		return fail("Control node not found at: %s" % req_str(params, "node_path"))
	var t := _load_theme(req_str(params, "theme_path"))
	if t == null:
		return fail("Theme not found: %s" % req_str(params, "theme_path"))
	(node as Control).theme = t
	mark_unsaved()
	return success({"node": rel_path(node), "theme": req_str(params, "theme_path")})
