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


static func scene_tree(root: Node, max_depth: int, include_internal: bool, include_props: bool) -> Dictionary:
	return _node_dict(root, root, 0, max_depth, include_internal, include_props)


static func _node_dict(root: Node, node: Node, depth: int, max_depth: int, include_internal: bool, include_props: bool) -> Dictionary:
	var d: Dictionary = {
		"name": String(node.name),
		"type": node.get_class(),
		"path": "." if node == root else String(root.get_path_to(node)),
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
	# Collapse instanced sub-scenes (like the Scene dock) unless asked otherwise.
	if (max_depth < 0 or depth < max_depth) and (include_internal or not is_instance):
		var kids: Array = []
		for child in node.get_children(include_internal):
			kids.append(_node_dict(root, child, depth + 1, max_depth, include_internal, include_props))
		if not kids.is_empty():
			d["children"] = kids
	return d


static func _free_ref(ref: Object) -> void:
	if ref == null:
		return
	if ref is Node:
		(ref as Node).free()
	elif not (ref is RefCounted):
		ref.free()
