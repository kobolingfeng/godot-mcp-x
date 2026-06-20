@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_shader": _create_shader,
		"read_shader": _read_shader,
		"edit_shader": _edit_shader,
		"assign_shader": _assign_shader,
		"set_shader_param": _set_shader_param,
		"list_shader_uniforms": _list_shader_uniforms,
	}


func _create_shader(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if path == "":
		return fail("'path' is required (.gdshader)")
	if FileAccess.file_exists(path):
		return fail("File already exists: %s (use edit_shader)" % path)
	var code := opt_str(params, "code", "shader_type spatial;\n")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return fail("Cannot create: %s" % path)
	f.store_string(code)
	f.close()
	fs_update(path)
	return success({"created": path})


func _read_shader(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if not FileAccess.file_exists(path):
		return fail("Shader not found: %s" % path)
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	return paginate_lines(path, text, params)


func _edit_shader(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	var old_text := opt_str(params, "old_text", "")
	if path == "" or old_text == "":
		return fail("'path' and 'old_text' are required")
	if not FileAccess.file_exists(path):
		return fail("Shader not found: %s" % path)
	var rf := FileAccess.open(path, FileAccess.READ)
	var text := rf.get_as_text()
	rf.close()
	var count := text.count(old_text)
	if count == 0:
		return fail("old_text not found")
	if count > 1:
		return fail("old_text appears %d times — make it unique" % count)
	text = text.replace(old_text, opt_str(params, "new_text", ""))
	var wf := FileAccess.open(path, FileAccess.WRITE)
	wf.store_string(text)
	wf.close()
	fs_update(path)
	return success({"edited": path})


func _assign_shader(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "node_path"))
	if node == null:
		return fail("Node not found: %s" % req_str(params, "node_path"))
	var sp := req_str(params, "shader_path")
	if not FileAccess.file_exists(sp):
		return fail("Shader not found: %s" % sp)
	var sh: Variant = load(sp)
	if not (sh is Shader):
		return fail("Not a Shader: %s" % sp)
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if node is MeshInstance3D:
		(node as MeshInstance3D).set_surface_override_material(opt_int(params, "surface", 0), mat)
	elif node is GeometryInstance3D:
		node.set("material_override", mat)
	elif node is CanvasItem:
		node.set("material", mat)
	else:
		return fail("Node type %s has no material slot" % node.get_class())
	mark_unsaved()
	return success({"node": rel_path(node), "shader": sp})


func _node_shader_material(node: Node, surface: int) -> ShaderMaterial:
	var mat: Variant = null
	if node is MeshInstance3D:
		mat = (node as MeshInstance3D).get_surface_override_material(surface)
	elif node is GeometryInstance3D:
		mat = node.get("material_override")
	elif node is CanvasItem:
		mat = node.get("material")
	return mat as ShaderMaterial


func _set_shader_param(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "node_path"))
	if node == null:
		return fail("Node not found")
	var mat := _node_shader_material(node, opt_int(params, "surface", 0))
	if mat == null:
		return fail("Node has no ShaderMaterial (assign_shader first)")
	var param := req_str(params, "param")
	if param == "":
		return fail("'param' is required")
	if not params.has("value"):
		return fail("'value' is required")
	var val: Variant = params["value"]
	if val is String:
		var p: Variant = str_to_var(val)
		if p != null:
			val = p
	mat.set_shader_parameter(param, val)
	mark_unsaved()
	return success({"node": rel_path(node), "param": param})


func _list_shader_uniforms(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if not FileAccess.file_exists(path):
		return fail("Shader not found: %s" % path)
	var sh: Variant = load(path)
	if not (sh is Shader):
		return fail("Not a Shader: %s" % path)
	var uniforms: Array = []
	for u in (sh as Shader).get_shader_uniform_list():
		uniforms.append({"name": u.get("name", ""), "type": type_string(u.get("type", 0))})
	return success({"shader": path, "uniforms": uniforms, "count": uniforms.size()})
