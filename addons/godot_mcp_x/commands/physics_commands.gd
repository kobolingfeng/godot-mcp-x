@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_physics_layers": _get_physics_layers,
		"set_physics_layer_name": _set_physics_layer_name,
		"set_collision_layers": _set_collision_layers,
		"get_collision_info": _get_collision_info,
		"setup_collision_shape": _setup_collision_shape,
	}


func _get_physics_layers(_params: Dictionary) -> Dictionary:
	var out2d: Dictionary = {}
	var out3d: Dictionary = {}
	for i in range(1, 33):
		var n2: String = ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % i, "")
		var n3: String = ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % i, "")
		if n2 != "":
			out2d[i] = n2
		if n3 != "":
			out3d[i] = n3
	return success({"2d": out2d, "3d": out3d})


func _set_physics_layer_name(params: Dictionary) -> Dictionary:
	var dim := opt_str(params, "dimension", "3d")
	var idx := opt_int(params, "layer", 0)
	if idx < 1 or idx > 32:
		return fail("'layer' must be 1-32")
	if dim != "2d" and dim != "3d":
		return fail("'dimension' must be '2d' or '3d'")
	ProjectSettings.set_setting("layer_names/%s_physics/layer_%d" % [dim, idx], req_str(params, "name"))
	var err := ProjectSettings.save()
	if err != OK:
		return fail("Save failed (error %d)" % err)
	return success({"dimension": dim, "layer": idx, "name": req_str(params, "name")})


func _set_collision_layers(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail("Node not found")
	var props := {}
	if has_key(params, "layer"):
		props["collision_layer"] = int(params["layer"])
	if has_key(params, "mask"):
		props["collision_mask"] = int(params["mask"])
	set_props_undoable(node, props, "Set collision layers", false)
	return success({
		"path": rel_path(node),
		"collision_layer": node.get("collision_layer"),
		"collision_mask": node.get("collision_mask"),
	})


func _get_collision_info(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail("Node not found")
	var info: Dictionary = {"path": rel_path(node), "type": node.get_class()}
	for prop in ["collision_layer", "collision_mask"]:
		var v: Variant = node.get(prop)
		if v != null:
			info[prop] = v
	return success(info)


func _setup_collision_shape(params: Dictionary) -> Dictionary:
	var body := resolve_node(req_str(params, "path"))
	if body == null:
		return fail("Body node not found: %s" % req_str(params, "path"))
	var cs := CollisionShape3D.new()
	cs.name = opt_str(params, "name", "CollisionShape3D")
	var shape: Shape3D
	match opt_str(params, "shape", "box"):
		"sphere":
			shape = SphereShape3D.new()
		"capsule":
			shape = CapsuleShape3D.new()
		_:
			shape = BoxShape3D.new()
	cs.shape = shape
	add_node_undoable(body, cs, "Add CollisionShape3D")
	return success({"path": rel_path(cs), "shape": shape.get_class()})
