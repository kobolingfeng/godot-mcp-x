@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"add_node": _add_node,
		"delete_node": _delete_node,
		"rename_node": _rename_node,
		"move_node": _move_node,
		"duplicate_node": _duplicate_node,
		"get_node_properties": _get_node_properties,
		"set_node_property": _set_node_property,
		"set_node_properties": _set_node_properties,
		"get_node_signals": _get_node_signals,
		"connect_signal": _connect_signal,
		"set_node_groups": _set_node_groups,
		"find_nodes": _find_nodes,
		"call_node_method": _call_method,
		"build_tree": _build_tree,
	}


func _add_node(params: Dictionary) -> Dictionary:
	var root := edited_root()
	if root == null:
		return fail("No scene is currently open")
	var type := req_str(params, "type")
	var nm := req_str(params, "name")
	if type == "" or nm == "":
		return fail("'type' and 'name' are required")
	if not ClassDB.can_instantiate(type):
		return fail("Cannot instantiate type: %s" % type, -32000, {"suggestions": suggest(type, ClassDB.get_class_list())})
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail("Parent not found: %s" % opt_str(params, "parent_path", "."))
	var node: Node = ClassDB.instantiate(type)
	if node == null:
		return fail("Failed to instantiate %s" % type)
	node.name = nm
	var applied: Array = []
	for k: String in opt_dict(params, "properties"):
		node.set(k, coerce_to(node.get(k), params["properties"][k]))
		applied.append(k)
	var u := undo_redo()
	u.create_action("Add %s" % nm, UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_method(self, "_ur_add", parent, node)
	u.add_undo_method(parent, "remove_child", node)
	u.add_do_reference(node)
	u.commit_action()
	return success({"path": rel_path(node), "type": type, "applied_properties": applied})


func _delete_node(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	if node == edited_root():
		return fail("Cannot delete the scene root")
	var p := rel_path(node)
	var parent := node.get_parent()
	var idx := node.get_index()
	var u := undo_redo()
	u.create_action("Delete %s" % node.name, UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_method(parent, "remove_child", node)
	u.add_undo_method(self, "_ur_readd", parent, node, idx)
	u.add_undo_reference(node)
	u.commit_action()
	return success({"deleted": p})


func _rename_node(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	var nn := req_str(params, "new_name")
	if nn == "":
		return fail("'new_name' is required")
	var old := node.name
	var u := undo_redo()
	u.create_action("Rename to %s" % nn, UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_property(node, "name", nn)
	u.add_undo_property(node, "name", old)
	u.commit_action()
	return success({"path": rel_path(node), "name": String(node.name)})


func _move_node(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	if node == edited_root():
		return fail("Cannot move the scene root")
	var new_parent := resolve_node(req_str(params, "new_parent_path"))
	if new_parent == null:
		return fail("New parent not found: %s" % req_str(params, "new_parent_path"))
	var old_parent := node.get_parent()
	var old_index := node.get_index()
	var u := undo_redo()
	u.create_action("Move %s" % node.name, UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_method(self, "_ur_reparent", node, new_parent, opt_int(params, "index", -1))
	u.add_undo_method(self, "_ur_reparent", node, old_parent, old_index)
	u.commit_action()
	return success({"path": rel_path(node)})


func _duplicate_node(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	if node == edited_root():
		return fail("Cannot duplicate the scene root")
	var dup := node.duplicate()
	if has_key(params, "new_name"):
		dup.name = req_str(params, "new_name")
	var parent := node.get_parent()
	var u := undo_redo()
	u.create_action("Duplicate %s" % node.name, UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_method(self, "_ur_add", parent, dup)
	u.add_undo_method(parent, "remove_child", dup)
	u.add_do_reference(dup)
	u.commit_action()
	return success({"path": rel_path(dup)})


func _get_node_properties(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	var props: Dictionary
	if has_key(params, "names"):
		props = Serialize.picked_properties(node, opt_array(params, "names"))
	elif opt_bool(params, "include_defaults", false):
		props = Serialize.all_properties(node)
	else:
		props = Serialize.changed_properties(node)
	return success({"path": rel_path(node), "type": node.get_class(), "properties": props})


func _set_node_property(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	var prop := req_str(params, "property")
	if prop == "":
		return fail("'property' is required")
	if not params.has("value"):
		return fail("'value' is required")
	if not node_has_property(node, prop):
		var names: Array = []
		for p in node.get_property_list():
			names.append(p.get("name", ""))
		return fail("Node %s has no property '%s'" % [node.get_class(), prop], -32000, {"suggestions": suggest(prop, names)})
	var old: Variant = node.get(prop)
	var u := undo_redo()
	u.create_action("Set %s" % prop, UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_property(node, prop, coerce_to(old, params["value"]))
	u.add_undo_property(node, prop, old)
	u.commit_action()
	return success({"path": rel_path(node), "property": prop, "value": Serialize.to_json(node.get(prop))})


func _set_node_properties(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	var applied: Array = []
	var u := undo_redo()
	u.create_action("Set properties", UndoRedo.MERGE_DISABLE, edited_root())
	for k: String in opt_dict(params, "properties"):
		var old: Variant = node.get(k)
		u.add_do_property(node, k, coerce_to(old, params["properties"][k]))
		u.add_undo_property(node, k, old)
		applied.append(k)
	u.commit_action()
	return success({"path": rel_path(node), "applied": applied})


func _get_node_signals(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	var sigs: Array = []
	for s in node.get_signal_list():
		var sname: String = s.get("name", "")
		var conns: Array = []
		for c in node.get_signal_connection_list(sname):
			var cb: Callable = c.get("callable")
			conns.append(_callable_desc(cb))
		var entry: Dictionary = {"name": sname}
		if not conns.is_empty():
			entry["connections"] = conns
		sigs.append(entry)
	return success({"path": rel_path(node), "signals": sigs})


func _callable_desc(cb: Callable) -> String:
	var obj := cb.get_object()
	if obj is Node:
		return "%s.%s" % [rel_path(obj), cb.get_method()]
	return str(cb.get_method())


func _connect_signal(params: Dictionary) -> Dictionary:
	var from := resolve_node(req_str(params, "from_path"))
	var to := resolve_node(req_str(params, "to_path"))
	if from == null or to == null:
		return fail("from_path or to_path not found")
	var sig := req_str(params, "signal")
	var method := req_str(params, "method")
	if not from.has_signal(sig):
		return fail("Signal not found on source: %s" % sig)
	var cb := Callable(to, method)
	if from.is_connected(sig, cb):
		return success({"already_connected": true})
	var err := from.connect(sig, cb, CONNECT_PERSIST)
	if err != OK:
		return fail("Connect failed (error %d)" % err)
	mark_unsaved()
	return success({"connected": "%s.%s -> %s.%s" % [rel_path(from), sig, rel_path(to), method]})


func _set_node_groups(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	var old_groups: Array = []
	for g in node.get_groups():
		var gs := String(g)
		if not gs.begins_with("_"):
			old_groups.append(gs)
	var groups := opt_array(params, "groups")
	var u := undo_redo()
	u.create_action("Set groups", UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_method(self, "_ur_set_groups", node, groups)
	u.add_undo_method(self, "_ur_set_groups", node, old_groups)
	u.commit_action()
	return success({"path": rel_path(node), "groups": groups})


func _find_nodes(params: Dictionary) -> Dictionary:
	var root := edited_root()
	if root == null:
		return fail("No scene is currently open")
	var page := page_state(params, 200)
	_collect(root, root, opt_str(params, "type", ""), opt_str(params, "pattern", ""), opt_str(params, "group", ""), page)
	return success(page_result(page, "nodes"))


func _collect(root: Node, node: Node, type: String, pattern: String, group: String, page: Dictionary) -> void:
	var ok := true
	if type != "" and not node.is_class(type):
		ok = false
	if ok and pattern != "" and not String(node.name).matchn(pattern):
		ok = false
	if ok and group != "" and not node.is_in_group(group):
		ok = false
	if ok:
		page_add(page, {
			"path": "." if node == root else String(root.get_path_to(node)),
			"type": node.get_class(),
			"name": String(node.name),
		})
	for c in node.get_children():
		_collect(root, c, type, pattern, group, page)


func _call_method(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null:
		return fail_no_node(req_str(params, "path"))
	var method := req_str(params, "method")
	if not node.has_method(method):
		var mnames: Array = []
		for m in node.get_method_list():
			mnames.append(m.get("name", ""))
		return fail("Node %s has no method '%s'" % [node.get_class(), method], -32000, {"suggestions": suggest(method, mnames)})
	var args: Array = []
	for a in opt_array(params, "args"):
		args.append(coerce_to(null, a))
	var ret: Variant = node.callv(method, args)
	return success({"path": rel_path(node), "method": method, "return": Serialize.to_json(ret)})


# ---------- build_tree: declarative subtree in one undoable action ----------
func _build_tree(params: Dictionary) -> Dictionary:
	var root := edited_root()
	if root == null:
		return fail("No scene is currently open")
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail("Parent not found: %s" % opt_str(params, "parent_path", "."))
	var spec := opt_dict(params, "tree")
	if spec.is_empty():
		return fail("'tree' (a node spec dict) is required")
	var count := [0]
	var conns: Array = []
	var node := _build_node(spec, count, conns)
	if node == null:
		return fail("Invalid 'type' in tree spec (cannot instantiate)")
	# Wire signals in-memory (paths relative to the subtree root) so they travel
	# with the subtree and survive undo/redo.
	var wired := 0
	for c in conns:
		var to_node: Node = node if c.to == "." else node.get_node_or_null(NodePath(c.to))
		if to_node != null and c.from.has_signal(c.sig):
			var cb := Callable(to_node, c.method)
			if not c.from.is_connected(c.sig, cb):
				c.from.connect(c.sig, cb, CONNECT_PERSIST)
				wired += 1
	add_node_undoable(parent, node, "Build %s" % node.name)
	return success({"root": rel_path(node), "created": count[0], "signals": wired})


func _build_node(spec: Dictionary, count: Array, conns: Array) -> Node:
	var type := str(spec.get("type", ""))
	if type == "" or not ClassDB.can_instantiate(type):
		return null
	var n: Node = ClassDB.instantiate(type)
	if n == null:
		return null
	if spec.has("name"):
		n.name = str(spec["name"])
	if spec.has("script"):
		var sp := str(spec["script"])
		if ResourceLoader.exists(sp):
			n.set_script(load(sp))
	var props: Variant = spec.get("properties", {})
	if props is Dictionary:
		for k: String in props:
			n.set(k, _build_value(n.get(k), props[k]))
	var groups: Variant = spec.get("groups", [])
	if groups is Array:
		for g in groups:
			n.add_to_group(str(g), true)
	var sigs: Variant = spec.get("signals", [])
	if sigs is Array:
		for s in sigs:
			if s is Dictionary and s.has("signal"):
				conns.append({"from": n, "sig": str(s["signal"]), "to": str(s.get("to", ".")), "method": str(s.get("method", ""))})
	count[0] += 1
	var children: Variant = spec.get("children", [])
	if children is Array:
		for c in children:
			if c is Dictionary:
				var child := _build_node(c, count, conns)
				if child != null:
					n.add_child(child)
	return n


## Coerce a build_tree property value; a value of {"_res": "ClassName", ...} is
## built into an inline Resource (recursively), else normal string coercion.
func _build_value(cur: Variant, val: Variant) -> Variant:
	if val is Dictionary and val.has("_res"):
		var r := _build_resource(val)
		if r != null:
			return r
	return coerce_to(cur, val)


func _build_resource(spec: Dictionary) -> Resource:
	var cls := str(spec.get("_res", ""))
	if cls == "" or not ClassDB.can_instantiate(cls):
		return null
	var obj: Variant = ClassDB.instantiate(cls)
	if not (obj is Resource):
		if obj is Object and not (obj is RefCounted):
			(obj as Object).free()
		return null
	var r := obj as Resource
	var props: Variant = spec.get("properties", {})
	if props is Dictionary:
		for k: String in props:
			r.set(k, _build_value(r.get(k), props[k]))
	return r


# ---------- UndoRedo do-helpers (called by EditorUndoRedoManager) ----------
func _ur_add(parent: Node, node: Node) -> void:
	parent.add_child(node)
	set_owner_inclusive(node, edited_root())


func _ur_readd(parent: Node, node: Node, idx: int) -> void:
	parent.add_child(node)
	parent.move_child(node, idx)
	set_owner_inclusive(node, edited_root())


func _ur_reparent(node: Node, new_parent: Node, index: int) -> void:
	node.reparent(new_parent, true)
	if index >= 0:
		new_parent.move_child(node, index)
	set_owner_inclusive(node, edited_root())


func _ur_set_groups(node: Node, groups: Array) -> void:
	for g in node.get_groups():
		var gs := String(g)
		if not gs.begins_with("_"):
			node.remove_from_group(gs)
	for g in groups:
		node.add_to_group(String(g), true)
