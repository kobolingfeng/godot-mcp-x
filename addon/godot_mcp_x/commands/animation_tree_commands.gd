@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_animation_tree": _create,
		"setup_state_machine": _setup_sm,
		"add_state": _add_state,
		"add_transition": _add_transition,
		"get_animation_tree_info": _info,
		"set_tree_param": _set_param,
	}


func _tree(path: String) -> AnimationTree:
	return resolve_node(path) as AnimationTree


func _create(params: Dictionary) -> Dictionary:
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail("Parent not found")
	var tree := AnimationTree.new()
	tree.name = opt_str(params, "name", "AnimationTree")
	var ap := opt_str(params, "anim_player_path", "")
	if ap != "":
		tree.set("anim_player", NodePath(ap))
	add_node_undoable(parent, tree, "Add AnimationTree")
	return success({"path": rel_path(tree)})


func _setup_sm(params: Dictionary) -> Dictionary:
	var tree := _tree(req_str(params, "tree_path"))
	if tree == null:
		return fail("AnimationTree not found")
	tree.set_tree_root(AnimationNodeStateMachine.new())
	mark_unsaved()
	return success({"tree": rel_path(tree), "root": "AnimationNodeStateMachine"})


func _add_state(params: Dictionary) -> Dictionary:
	var tree := _tree(req_str(params, "tree_path"))
	if tree == null:
		return fail("AnimationTree not found")
	var sm := tree.get_tree_root() as AnimationNodeStateMachine
	if sm == null:
		return fail("Tree root is not a state machine (call setup_state_machine first)")
	var name := req_str(params, "name")
	if name == "":
		return fail("'name' is required")
	var anim_node := AnimationNodeAnimation.new()
	if has_key(params, "animation"):
		anim_node.animation = req_str(params, "animation")
	sm.add_node(name, anim_node, Vector2(opt_int(params, "x", 0), opt_int(params, "y", 0)))
	mark_unsaved()
	return success({"state": name})


func _add_transition(params: Dictionary) -> Dictionary:
	var tree := _tree(req_str(params, "tree_path"))
	if tree == null:
		return fail("AnimationTree not found")
	var sm := tree.get_tree_root() as AnimationNodeStateMachine
	if sm == null:
		return fail("Tree root is not a state machine")
	var from := req_str(params, "from")
	var to := req_str(params, "to")
	if from == "" or to == "":
		return fail("'from' and 'to' are required")
	sm.add_transition(from, to, AnimationNodeStateMachineTransition.new())
	mark_unsaved()
	return success({"transition": "%s -> %s" % [from, to]})


func _info(params: Dictionary) -> Dictionary:
	var tree := _tree(req_str(params, "tree_path"))
	if tree == null:
		return fail("AnimationTree not found")
	var info: Dictionary = {
		"path": rel_path(tree),
		"active": tree.active,
		"anim_player": String(tree.get("anim_player")),
	}
	var root := tree.get_tree_root()
	info["tree_root"] = root.get_class() if root else null
	if root is AnimationNodeStateMachine:
		var states: Array = []
		for s in (root as AnimationNodeStateMachine).get_node_list():
			states.append(String(s))
		info["states"] = states
	return success(info)


func _set_param(params: Dictionary) -> Dictionary:
	var tree := _tree(req_str(params, "tree_path"))
	if tree == null:
		return fail("AnimationTree not found")
	var param := req_str(params, "param")
	if param == "":
		return fail("'param' is required")
	var key := param if param.begins_with("parameters/") else "parameters/" + param
	var val: Variant = params.get("value")
	if val is String:
		var p: Variant = str_to_var(val)
		if p != null:
			val = p
	set_props_undoable(tree, {key: val}, "Set tree param", false)
	return success({"param": key})
