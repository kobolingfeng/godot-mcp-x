@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## Convenience builders for common 3D nodes. All set owner = edited root so they
## persist, and accept string-encoded values ("Color(1,0,0,1)") for colors.


func get_commands() -> Dictionary:
	return {
		"add_mesh_instance": _add_mesh_instance,
		"setup_light": _setup_light,
		"setup_camera": _setup_camera,
		"set_material": _set_material,
		"setup_environment": _setup_environment,
	}


func _parent(params: Dictionary) -> Node:
	return resolve_node(opt_str(params, "parent_path", "."))


func _add_mesh_instance(params: Dictionary) -> Dictionary:
	var parent := _parent(params)
	if parent == null:
		return fail("Parent not found")
	var mi := MeshInstance3D.new()
	mi.name = opt_str(params, "name", "MeshInstance3D")
	var mesh: Mesh
	match opt_str(params, "primitive", "box"):
		"sphere":
			mesh = SphereMesh.new()
		"cylinder":
			mesh = CylinderMesh.new()
		"plane":
			mesh = PlaneMesh.new()
		"capsule":
			mesh = CapsuleMesh.new()
		"torus":
			mesh = TorusMesh.new()
		_:
			mesh = BoxMesh.new()
	mi.mesh = mesh
	add_node_undoable(parent, mi, "Add MeshInstance3D")
	return success({"path": rel_path(mi), "mesh": mesh.get_class()})


func _setup_light(params: Dictionary) -> Dictionary:
	var parent := _parent(params)
	if parent == null:
		return fail("Parent not found")
	var light: Light3D
	match opt_str(params, "kind", "directional"):
		"omni":
			light = OmniLight3D.new()
		"spot":
			light = SpotLight3D.new()
		"area":
			light = AreaLight3D.new()  # 4.7 rectangular area light
		_:
			light = DirectionalLight3D.new()
	light.name = opt_str(params, "name", light.get_class())
	if has_key(params, "energy"):
		light.light_energy = float(params["energy"])
	if has_key(params, "color"):
		light.light_color = coerce_to(light.light_color, params["color"])
	if light is AreaLight3D and has_key(params, "area_size"):
		var sz: Variant = str_to_var(req_str(params, "area_size"))
		if sz is Vector2:
			light.set("area_size", sz)
	add_node_undoable(parent, light, "Add %s" % light.get_class())
	return success({"path": rel_path(light), "type": light.get_class()})


func _setup_camera(params: Dictionary) -> Dictionary:
	var parent := _parent(params)
	if parent == null:
		return fail("Parent not found")
	var cam := Camera3D.new()
	cam.name = opt_str(params, "name", "Camera3D")
	if has_key(params, "fov"):
		cam.fov = float(params["fov"])
	if has_key(params, "current"):
		cam.current = bool(params["current"])
	add_node_undoable(parent, cam, "Add Camera3D")
	return success({"path": rel_path(cam)})


func _set_material(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null or not (node is MeshInstance3D):
		return fail("MeshInstance3D not found at: %s" % req_str(params, "path"))
	var mat := StandardMaterial3D.new()
	if has_key(params, "albedo"):
		mat.albedo_color = coerce_to(mat.albedo_color, params["albedo"])
	if has_key(params, "metallic"):
		mat.metallic = float(params["metallic"])
	if has_key(params, "roughness"):
		mat.roughness = float(params["roughness"])
	if has_key(params, "emission"):
		mat.emission_enabled = true
		mat.emission = coerce_to(mat.emission, params["emission"])
	var surface := opt_int(params, "surface", 0)
	var mi := node as MeshInstance3D
	var old_mat: Material = mi.get_surface_override_material(surface)
	var u := undo_redo()
	u.create_action("Set material", UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_method(mi, "set_surface_override_material", surface, mat)
	u.add_undo_method(mi, "set_surface_override_material", surface, old_mat)
	u.commit_action()
	return success({"path": rel_path(node), "surface": surface})


func _setup_environment(params: Dictionary) -> Dictionary:
	var parent := _parent(params)
	if parent == null:
		return fail("Parent not found")
	var we := WorldEnvironment.new()
	we.name = opt_str(params, "name", "WorldEnvironment")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	we.environment = env
	add_node_undoable(parent, we, "Add WorldEnvironment")
	return success({"path": rel_path(we)})
