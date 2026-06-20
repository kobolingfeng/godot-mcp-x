@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## Skeleton3D inspection & posing (works on imported rigs or hand-built skeletons).


func get_commands() -> Dictionary:
	return {
		"get_skeleton_info": _info,
		"list_bones": _list_bones,
		"add_bone": _add_bone,
		"set_bone_pose": _set_pose,
		"reset_bone_poses": _reset,
		"add_bone_attachment": _attach,
		"add_skeleton_modifier": _add_modifier,
		"setup_look_at_modifier": _setup_look_at,
		"list_skeleton_modifiers": _list_modifiers,
	}


func _sk(path: String) -> Skeleton3D:
	return resolve_node(path) as Skeleton3D


func _info(params: Dictionary) -> Dictionary:
	var sk := _sk(req_str(params, "path"))
	if sk == null:
		return fail("Skeleton3D not found: %s" % req_str(params, "path"))
	return success({"path": rel_path(sk), "bone_count": sk.get_bone_count()})


func _list_bones(params: Dictionary) -> Dictionary:
	var sk := _sk(req_str(params, "path"))
	if sk == null:
		return fail("Skeleton3D not found")
	var bones: Array = []
	for i in range(sk.get_bone_count()):
		bones.append({"index": i, "name": sk.get_bone_name(i), "parent": sk.get_bone_parent(i)})
	var offset := opt_int(params, "offset", 0)
	var limit := opt_int(params, "limit", 300)
	return success({
		"total": bones.size(),
		"offset": offset,
		"limit": limit,
		"has_more": offset + limit < bones.size(),
		"bones": bones.slice(offset, offset + limit),
	})


func _add_bone(params: Dictionary) -> Dictionary:
	var sk := _sk(req_str(params, "path"))
	if sk == null:
		return fail("Skeleton3D not found")
	var name := req_str(params, "name")
	if name == "":
		return fail("'name' is required")
	sk.add_bone(name)
	var idx := sk.find_bone(name)
	if has_key(params, "parent"):
		var pidx := sk.find_bone(req_str(params, "parent"))
		if pidx >= 0:
			sk.set_bone_parent(idx, pidx)
	mark_unsaved()
	return success({"bone": name, "index": idx})


func _set_pose(params: Dictionary) -> Dictionary:
	var sk := _sk(req_str(params, "path"))
	if sk == null:
		return fail("Skeleton3D not found")
	var bone := req_str(params, "bone")
	var idx := int(bone) if bone.is_valid_int() else sk.find_bone(bone)
	if idx < 0 or idx >= sk.get_bone_count():
		return fail("Bone not found: %s" % bone)
	var u := undo_redo()
	u.create_action("Set bone pose", UndoRedo.MERGE_DISABLE, edited_root())
	if has_key(params, "position"):
		var pp: Variant = str_to_var(req_str(params, "position"))
		if pp is Vector3:
			u.add_undo_method(sk, "set_bone_pose_position", idx, sk.get_bone_pose_position(idx))
			u.add_do_method(sk, "set_bone_pose_position", idx, pp)
	if has_key(params, "rotation"):
		var rr: Variant = str_to_var(req_str(params, "rotation"))
		var q: Variant = null
		if rr is Quaternion:
			q = rr
		elif rr is Vector3:
			q = Quaternion.from_euler(rr)
		if q != null:
			u.add_undo_method(sk, "set_bone_pose_rotation", idx, sk.get_bone_pose_rotation(idx))
			u.add_do_method(sk, "set_bone_pose_rotation", idx, q)
	u.commit_action()
	return success({"bone": bone, "index": idx})


func _reset(params: Dictionary) -> Dictionary:
	var sk := _sk(req_str(params, "path"))
	if sk == null:
		return fail("Skeleton3D not found")
	sk.reset_bone_poses()
	mark_unsaved()
	return success({"reset": true})


func _attach(params: Dictionary) -> Dictionary:
	var sk := _sk(req_str(params, "path"))
	if sk == null:
		return fail("Skeleton3D not found")
	var ba := BoneAttachment3D.new()
	ba.name = opt_str(params, "name", "BoneAttachment3D")
	add_node_undoable(sk, ba, "Add BoneAttachment3D")
	ba.bone_name = req_str(params, "bone")
	return success({"path": rel_path(ba), "bone": req_str(params, "bone")})


# ---------- IK / modifiers (SkeletonModifier3D system, 4.3+) ----------
func _add_modifier(params: Dictionary) -> Dictionary:
	var sk := _sk(req_str(params, "path"))
	if sk == null:
		return fail("Skeleton3D not found")
	var type := req_str(params, "type")
	if type == "":
		return fail("'type' is required (e.g. TwoBoneIK3D, FABRIK3D, CCDIK3D, LookAtModifier3D, SpringBoneSimulator3D)")
	if not ClassDB.class_exists(type) or not ClassDB.is_parent_class(type, "SkeletonModifier3D"):
		return fail("%s is not a SkeletonModifier3D" % type)
	var mod: Node = ClassDB.instantiate(type)
	if mod == null:
		return fail("Cannot instantiate %s" % type)
	mod.name = opt_str(params, "name", type)
	for k: String in opt_dict(params, "properties"):
		var cur: Variant = mod.get(k)
		var v: Variant = params["properties"][k]
		if typeof(cur) == TYPE_NODE_PATH and v is String:
			mod.set(k, NodePath(v))
		else:
			mod.set(k, coerce_to(cur, v))
	add_node_undoable(sk, mod, "Add %s" % type)
	return success({"path": rel_path(mod), "type": type})


func _setup_look_at(params: Dictionary) -> Dictionary:
	var sk := _sk(req_str(params, "path"))
	if sk == null:
		return fail("Skeleton3D not found")
	var mod := LookAtModifier3D.new()
	mod.name = opt_str(params, "name", "LookAtModifier3D")
	mod.bone_name = req_str(params, "bone")
	if has_key(params, "target_path"):
		mod.target_node = NodePath(req_str(params, "target_path"))
	add_node_undoable(sk, mod, "Add LookAtModifier3D")
	return success({"path": rel_path(mod), "bone": req_str(params, "bone")})


func _list_modifiers(params: Dictionary) -> Dictionary:
	var sk := _sk(req_str(params, "path"))
	if sk == null:
		return fail("Skeleton3D not found")
	var mods: Array = []
	for c in sk.get_children():
		if c is SkeletonModifier3D:
			var m := c as SkeletonModifier3D
			mods.append({"path": rel_path(c), "type": c.get_class(), "active": m.active, "influence": m.influence})
	return success({"skeleton": rel_path(sk), "modifiers": mods})
