@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_resource": _create_resource,
		"read_resource": _read_resource,
		"edit_resource": _edit_resource,
	}


func _create_resource(params: Dictionary) -> Dictionary:
	var type := req_str(params, "type")
	var path := req_str(params, "path")
	if type == "" or path == "":
		return fail("'type' and 'path' are required")
	if not ClassDB.can_instantiate(type):
		return fail("Cannot instantiate: %s" % type)
	var obj: Object = ClassDB.instantiate(type)
	if not (obj is Resource):
		if obj is Node:
			(obj as Node).free()
		return fail("%s is not a Resource" % type)
	var res: Resource = obj
	for k: String in opt_dict(params, "properties"):
		res.set(k, coerce_to(res.get(k), params["properties"][k]))
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return fail("Save failed (error %d)" % err)
	fs_update(path)
	return success({"created": path, "type": type})


func _read_resource(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if not ResourceLoader.exists(path):
		return fail("Resource not found: %s" % path)
	var res := load(path)
	if res == null:
		return fail("Failed to load: %s" % path)
	var props: Dictionary
	if has_key(params, "names"):
		props = Serialize.picked_properties(res, opt_array(params, "names"))
	elif opt_bool(params, "include_defaults", false):
		props = Serialize.all_properties(res)
	else:
		props = Serialize.changed_properties(res)
	return success({"path": path, "type": res.get_class(), "properties": props})


func _edit_resource(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if not ResourceLoader.exists(path):
		return fail("Resource not found: %s" % path)
	var res := load(path)
	if res == null:
		return fail("Failed to load: %s" % path)
	var applied: Array = []
	for k: String in opt_dict(params, "properties"):
		res.set(k, coerce_to(res.get(k), params["properties"][k]))
		applied.append(k)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return fail("Save failed (error %d)" % err)
	fs_update(path)
	return success({"path": path, "applied": applied})
