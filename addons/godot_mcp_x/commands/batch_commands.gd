@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"batch_add_nodes": _batch_add_nodes,
		"batch_set_properties": _batch_set_properties,
		"batch_get_properties": _batch_get_properties,
	}


func _batch_add_nodes(params: Dictionary) -> Dictionary:
	var root := edited_root()
	if root == null:
		return fail("No scene is currently open")
	var errors: Array = []
	var plan: Array = []
	for d in opt_array(params, "nodes"):
		if not (d is Dictionary):
			continue
		var type := str(d.get("type", ""))
		var nm := str(d.get("name", ""))
		if type == "" or nm == "" or not ClassDB.can_instantiate(type):
			errors.append("skip invalid: %s/%s" % [type, nm])
			continue
		var node: Node = ClassDB.instantiate(type)
		node.name = nm
		var props: Variant = d.get("properties", {})
		plan.append({"node": node, "parent": str(d.get("parent_path", ".")), "props": props if props is Dictionary else {}})
	if plan.is_empty():
		return fail("No valid nodes to add", -32000, {"errors": errors})
	# One undo action for the whole batch; parents resolve at run time, so an
	# earlier node can be the parent of a later one.
	var u := undo_redo()
	u.create_action("Add %d node(s)" % plan.size(), UndoRedo.MERGE_DISABLE, root)
	for p in plan:
		u.add_do_method(self, "_uadd_batch", p.parent, p.node, p.props)
		u.add_undo_method(self, "_uremove", p.node)
		u.add_do_reference(p.node)
	u.commit_action()
	var added: Array = []
	for p in plan:
		added.append(rel_path(p.node))
	return success({"added": added, "count": added.size(), "errors": errors})


func _batch_set_properties(params: Dictionary) -> Dictionary:
	var results: Array = []
	var ur := undo_redo()
	ur.create_action("Batch set properties", UndoRedo.MERGE_DISABLE, edited_root())
	for u in opt_array(params, "updates"):
		if not (u is Dictionary):
			continue
		var node := resolve_node(str(u.get("path", "")))
		if node == null:
			results.append({"path": u.get("path", ""), "ok": false})
			continue
		var props: Variant = u.get("properties", {})
		if props is Dictionary:
			for k: String in props:
				var old: Variant = node.get(k)
				ur.add_do_property(node, k, coerce_to(old, props[k]))
				ur.add_undo_property(node, k, old)
		results.append({"path": rel_path(node), "ok": true})
	ur.commit_action()
	return success({"results": results})


func _batch_get_properties(params: Dictionary) -> Dictionary:
	var names := opt_array(params, "names")
	var out: Dictionary = {}
	for p in opt_array(params, "paths"):
		var node := resolve_node(str(p))
		if node == null:
			out[str(p)] = null
		elif names.is_empty():
			out[str(p)] = Serialize.changed_properties(node)
		else:
			out[str(p)] = Serialize.picked_properties(node, names)
	return success({"nodes": out})
