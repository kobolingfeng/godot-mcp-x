@tool
extends RefCounted

## Pure serialization helpers shared by all commands.
## The scene-tree walker starts at the EDITED SCENE ROOT (not /root), so the
## editor's own UI nodes never leak into output — the root cause of the original
## tool's 73K-char path noise.


## Convert any Godot Variant into a JSON-friendly value.
## Math types become their var_to_str() form ("Vector3(1, 2, 3)") which is
## round-trippable via str_to_var() on the way back in.
static func to_json(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return String(v)
		TYPE_OBJECT:
			var o: Object = v
			if o == null:
				return null
			if o is Resource:
				var r := o as Resource
				return r.resource_path if r.resource_path != "" else "<%s>" % r.get_class()
			return "<%s>" % o.get_class()
		TYPE_ARRAY:
			var arr: Array = []
			for e in v:
				arr.append(to_json(e))
			return arr
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in v:
				d[str(k)] = to_json(v[k])
			return d
		_:
			# Vector*, Color, Quaternion, Rect2, Basis, Transform*, AABB, Plane, packed arrays…
			return var_to_str(v)


## Cache of per-class default snapshots ({prop: var_to_str(default)}). Engine
## class defaults are constant at runtime, so caching is safe — and it avoids
## re-instantiating the same class for every node (~4× faster on real scenes,
## and effectively free once warm across calls).
static var _default_cache: Dictionary = {}

const JSON_SAFE_MAX_DEPTH := 128


static func _class_defaults(cls: String) -> Dictionary:
	if _default_cache.has(cls):
		return _default_cache[cls]
	var defaults: Dictionary = {}
	if ClassDB.can_instantiate(cls):
		var ref: Object = ClassDB.instantiate(cls)
		for p in ref.get_property_list():
			if p.get("usage", 0) & PROPERTY_USAGE_STORAGE:
				var pname: String = p.get("name", "")
				if pname != "":
					defaults[pname] = var_to_str(ref.get(pname))
		_free_ref(ref)
	_default_cache[cls] = defaults
	return defaults


## Properties whose value differs from the class default — the big token saver for
## get_node_properties / scene-tree dumps. Uses the cached default snapshot.
static func changed_properties(node: Object) -> Dictionary:
	var out: Dictionary = {}
	var defaults := _class_defaults(node.get_class())
	for p in node.get_property_list():
		if not (p.get("usage", 0) & PROPERTY_USAGE_STORAGE):
			continue
		var pname: String = p.get("name", "")
		if pname == "":
			continue
		var val: Variant = node.get(pname)
		if defaults.has(pname) and defaults[pname] == var_to_str(val):
			continue
		out[pname] = to_json(val)
	return out


## Every storage property (full dump).
static func all_properties(node: Object) -> Dictionary:
	var out: Dictionary = {}
	for p in node.get_property_list():
		var usage: int = p.get("usage", 0)
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var pname: String = p.get("name", "")
		if pname != "":
			out[pname] = to_json(node.get(pname))
	return out


## Only the named properties (projection).
static func picked_properties(node: Object, names: Array) -> Dictionary:
	var out: Dictionary = {}
	for n in names:
		var pname := String(n)
		out[pname] = to_json(node.get(pname))
	return out


static func scene_tree(root: Node, max_depth: int, include_internal: bool, include_props: bool, type_filter: String = "", max_nodes: int = 0) -> Dictionary:
	var requested_max_depth := max_depth
	var effective_max_depth := max_depth
	var has_auto_depth_budget := false
	if max_depth < 0 or max_depth > JSON_SAFE_MAX_DEPTH:
		effective_max_depth = JSON_SAFE_MAX_DEPTH
		has_auto_depth_budget = true
	var budget := maxi(0, max_nodes)
	var truncated := false
	var depth_truncated := false
	var frames: Array = []
	var stack: Array = [{
		"node": root,
		"depth": 0,
		"path": ".",
		"parent": -1,
	}]
	while not stack.is_empty():
		var item: Dictionary = stack.pop_back()
		if budget > 0 and frames.size() >= budget:
			truncated = true
			break
		var node: Node = item["node"]
		var depth := int(item["depth"])
		var node_path := String(item["path"])
		var matches_filter := type_filter == "" or node.is_class(type_filter)
		var frame := {
			"parent": int(item["parent"]),
			"entry": _node_entry(root, node, node_path, include_props and matches_filter),
			"kids": [],
			"matches": matches_filter,
		}
		var frame_idx := frames.size()
		frames.append(frame)
		var is_instance := node != root and node.scene_file_path != ""
		if (effective_max_depth < 0 or depth < effective_max_depth) and (include_internal or not is_instance):
			var children := node.get_children(include_internal)
			for i in range(children.size() - 1, -1, -1):
				if budget > 0 and frames.size() + stack.size() >= budget:
					truncated = true
					break
				var child: Node = children[i]
				var child_path := String(child.name) if node_path == "." else node_path + "/" + String(child.name)
				stack.append({
					"node": child,
					"depth": depth + 1,
					"path": child_path,
					"parent": frame_idx,
				})
		elif has_auto_depth_budget and (include_internal or not is_instance) and node.get_child_count(include_internal) > 0:
			depth_truncated = true
	var out: Dictionary = {}
	for i in range(frames.size() - 1, -1, -1):
		var frame: Dictionary = frames[i]
		var kids: Array = frame["kids"]
		var include_node := bool(frame["matches"]) or type_filter == "" or not kids.is_empty()
		if not include_node:
			continue
		var entry: Dictionary = frame["entry"]
		if not kids.is_empty():
			kids.reverse()
			entry["children"] = kids
		var parent_idx := int(frame["parent"])
		if parent_idx >= 0:
			var parent_kids: Array = frames[parent_idx]["kids"]
			parent_kids.append(entry)
		else:
			out = entry
	if out.is_empty():
		out = {"name": String(root.name), "type": root.get_class(), "path": ".", "filtered": true}
	if truncated:
		out["truncated"] = true
		out["node_budget"] = max_nodes
	if depth_truncated:
		out["depth_truncated"] = true
		out["depth_budget"] = effective_max_depth
		out["requested_max_depth"] = requested_max_depth
	return out


static func _node_entry(root: Node, node: Node, node_path: String, include_props: bool) -> Dictionary:
	var d: Dictionary = {
		"name": String(node.name),
		"type": node.get_class(),
		"path": node_path,
	}
	var scr: Variant = node.get_script()
	if scr != null and scr is Resource and (scr as Resource).resource_path != "":
		d["script"] = (scr as Resource).resource_path
	var is_instance := node != root and node.scene_file_path != ""
	if is_instance:
		d["instance"] = node.scene_file_path
	if include_props:
		var changed := changed_properties(node)
		if not changed.is_empty():
			d["properties"] = changed
	var groups := node.get_groups()
	if not groups.is_empty():
		var g: Array = []
		for gr in groups:
			var gs := String(gr)
			if not gs.begins_with("_"):
				g.append(gs)
		if not g.is_empty():
			d["groups"] = g
	return d


static func _free_ref(ref: Object) -> void:
	if ref == null:
		return
	if ref is Node:
		(ref as Node).free()
	elif not (ref is RefCounted):
		ref.free()
