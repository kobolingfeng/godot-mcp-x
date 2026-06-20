@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_scene_tree": _get_scene_tree,
		"get_current_scene": _get_current_scene,
		"open_scene": _open_scene,
		"save_scene": _save_scene,
		"create_scene": _create_scene,
		"get_scene_file_content": _get_scene_file_content,
		"instance_scene": _instance_scene,
	}


func _get_scene_tree(params: Dictionary) -> Dictionary:
	var root := edited_root()
	if root == null:
		return fail("No scene is currently open in the editor")
	var tree := Serialize.scene_tree(
		root,
		opt_int(params, "max_depth", -1),
		opt_bool(params, "include_internal", false),
		opt_bool(params, "include_properties", false),
		opt_str(params, "type_filter", ""),
		opt_int(params, "max_nodes", 0),
	)
	return success({"scene": root.scene_file_path, "tree": tree})


func _get_current_scene(_params: Dictionary) -> Dictionary:
	var root := edited_root()
	if root == null:
		return fail("No scene is currently open")
	return success({
		"path": root.scene_file_path,
		"root_name": String(root.name),
		"root_type": root.get_class(),
		"child_count": root.get_child_count(),
	})


func _open_scene(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if not FileAccess.file_exists(path):
		return fail("Scene not found: %s" % path)
	EditorInterface.open_scene_from_path(path)
	return success({"opened": path})


func _save_scene(params: Dictionary) -> Dictionary:
	if edited_root() == null:
		return fail("No scene is currently open")
	var path := opt_str(params, "path", "")
	if path != "":
		EditorInterface.save_scene_as(path)  # returns void in 4.7
		return success({"saved": path})
	var err := EditorInterface.save_scene()
	if err != OK:
		return fail("Save failed (error %d)" % err)
	return success({"saved": edited_root().scene_file_path})


func _create_scene(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if path == "":
		return fail("'path' is required")
	var root_type := opt_str(params, "root_type", "Node")
	if not ClassDB.can_instantiate(root_type):
		return fail("Cannot instantiate root type: %s" % root_type)
	var node: Node = ClassDB.instantiate(root_type)
	if node == null:
		return fail("Failed to instantiate %s" % root_type)
	node.name = opt_str(params, "root_name", root_type)
	var packed := PackedScene.new()
	if packed.pack(node) != OK:
		node.free()
		return fail("Failed to pack scene")
	# Claim the cache slot so overwriting an existing scene doesn't reopen a stale
	# cached/older version of the same path.
	packed.take_over_path(path)
	var err := ResourceSaver.save(packed, path)
	node.free()
	if err != OK:
		return fail("Failed to save scene (error %d)" % err)
	fs_update(path)
	EditorInterface.open_scene_from_path(path)
	# If this path was already the open scene, open is a no-op and the in-memory
	# (stale) version would persist — force a fresh load from the file we wrote.
	EditorInterface.reload_scene_from_path(path)
	return success({"created": path, "root_type": root_type})


func _get_scene_file_content(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if not FileAccess.file_exists(path):
		return fail("File not found: %s" % path)
	return paginate_file_lines(path, params)


func _instance_scene(params: Dictionary) -> Dictionary:
	var scene_path := req_str(params, "scene_path")
	if not FileAccess.file_exists(scene_path):
		return fail("Scene not found: %s" % scene_path)
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail("Parent not found: %s" % opt_str(params, "parent_path", "."))
	var ps: PackedScene = load(scene_path)
	if ps == null:
		return fail("Failed to load scene: %s" % scene_path)
	var inst := ps.instantiate()
	if has_key(params, "name"):
		inst.name = req_str(params, "name")
	add_node_undoable(parent, inst, "Instance %s" % scene_path.get_file(), false)
	return success({"path": rel_path(inst), "scene": scene_path})
