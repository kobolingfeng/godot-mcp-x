@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_particles": _create_particles,
		"set_particle_process": _set_particle_process,
		"get_particle_info": _get_particle_info,
	}


func _create_particles(params: Dictionary) -> Dictionary:
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail("Parent not found")
	var is2d := opt_str(params, "dimension", "3d") == "2d"
	var node: Node = GPUParticles2D.new() if is2d else GPUParticles3D.new()
	node.name = opt_str(params, "name", node.get_class())
	node.set("amount", opt_int(params, "amount", 8))
	if has_key(params, "lifetime"):
		node.set("lifetime", float(params["lifetime"]))
	node.set("process_material", ParticleProcessMaterial.new())
	if not is2d:
		node.set("draw_pass_1", QuadMesh.new())
	add_node_undoable(parent, node, "Add %s" % node.get_class())
	return success({"path": rel_path(node), "type": node.get_class()})


func _set_particle_process(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail("Node not found")
	var mat: Variant = node.get("process_material")
	if not (mat is ParticleProcessMaterial):
		return fail("Node has no ParticleProcessMaterial")
	var applied := set_props_undoable(mat, opt_dict(params, "properties"), "Set particle process")
	return success({"path": rel_path(node), "applied": applied})


func _get_particle_info(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail("Node not found")
	var info: Dictionary = {"path": rel_path(node), "type": node.get_class()}
	for p in ["amount", "lifetime", "emitting", "one_shot", "speed_scale", "explosiveness", "preprocess"]:
		var v: Variant = node.get(p)
		if v != null:
			info[p] = Serialize.to_json(v)
	var mat: Variant = node.get("process_material")
	if mat is ParticleProcessMaterial:
		info["process_material"] = Serialize.changed_properties(mat)
	return success(info)
