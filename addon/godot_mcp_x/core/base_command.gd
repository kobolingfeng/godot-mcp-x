@tool
extends Node

## Base class for all godot-mcp-x command modules.
## Subclasses override get_commands() → { "method_name": Callable }.

const Serialize := preload("res://addons/godot_mcp_x/core/serialize.gd")
const FULL_READ_LINE_PAGE_MAX_BYTES := 32 * 1024 * 1024

var editor_plugin: EditorPlugin


func get_commands() -> Dictionary:
	return {}


# ---------- response builders ----------
func success(data: Variant = {}) -> Dictionary:
	return {"result": data}


func fail(message: String, code: int = -32000, data: Dictionary = {}) -> Dictionary:
	return {"error": {"code": code, "message": message, "data": data}}


# ---------- param helpers ----------
func req_str(params: Dictionary, key: String) -> String:
	return str(params.get(key, ""))


func opt_str(params: Dictionary, key: String, def: String = "") -> String:
	var v: Variant = params.get(key, def)
	return str(v) if v != null else def


func opt_int(params: Dictionary, key: String, def: int = 0) -> int:
	var v: Variant = params.get(key, def)
	if v is int or v is float or v is String:
		return int(v)
	return def


func opt_bool(params: Dictionary, key: String, def: bool = false) -> bool:
	var v: Variant = params.get(key, def)
	return bool(v) if v != null else def


func opt_array(params: Dictionary, key: String) -> Array:
	var v: Variant = params.get(key, [])
	return v if v is Array else []


func opt_dict(params: Dictionary, key: String) -> Dictionary:
	var v: Variant = params.get(key, {})
	return v if v is Dictionary else {}


func has_key(params: Dictionary, key: String) -> bool:
	return params.has(key) and params[key] != null


# ---------- scene/node helpers ----------
func edited_root() -> Node:
	return EditorInterface.get_edited_scene_root()


## Resolve a SCENE-RELATIVE path. '.' / '' / '/root' → edited root.
func resolve_node(path: String) -> Node:
	var root := edited_root()
	if root == null:
		return null
	if path == "" or path == "." or path == "/root":
		return root
	var p := path
	if p.begins_with("/root/"):
		p = p.substr(6)
	elif p.begins_with("./"):
		p = p.substr(2)
	if p == String(root.name):
		return root
	return root.get_node_or_null(NodePath(p))


func rel_path(node: Node) -> String:
	var root := edited_root()
	if node == null or root == null:
		return ""
	if node == root:
		return "."
	return String(root.get_path_to(node))


## Reassign owner across a subtree so it is saved with the scene.
func set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		set_owner_recursive(child, owner)


## Set owner on a node AND its whole subtree.
func set_owner_inclusive(node: Node, owner: Node) -> void:
	node.owner = owner
	set_owner_recursive(node, owner)


## The editor's undo/redo manager — wrap mutations so the user can Ctrl+Z them.
func undo_redo() -> EditorUndoRedoManager:
	return editor_plugin.get_undo_redo()


## Add a freshly-created `node` under `parent` as ONE undoable editor action
## (do: add_child + take ownership; undo: remove_child), routed to the SCENE
## history so the user can Ctrl+Z it. Use this for every "create a node" command.
## `own_children`: own the whole subtree (default); pass false for instanced
## PackedScenes, where only the instance root should be owned by the edited scene.
func add_node_undoable(parent: Node, node: Node, action_name: String, own_children: bool = true) -> void:
	var u := undo_redo()
	u.create_action(action_name, UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_method(self, "_uadd_owned" if own_children else "_uadd_root", parent, node)
	u.add_undo_method(parent, "remove_child", node)
	u.add_do_reference(node)
	u.commit_action()


func _uadd_owned(parent: Node, node: Node) -> void:
	parent.add_child(node)
	set_owner_inclusive(node, edited_root())


func _uadd_root(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = edited_root()


## Do-helper for batched adds: resolves the parent at run time (so an earlier
## node in the same batch can be the parent of a later one) and applies properties.
func _uadd_batch(parent_path: String, node: Node, props: Dictionary) -> void:
	var parent := resolve_node(parent_path)
	if parent == null:
		parent = edited_root()
	parent.add_child(node)
	set_owner_inclusive(node, edited_root())
	for k: String in props:
		node.set(k, coerce_to(node.get(k), props[k]))


func _uremove(node: Node) -> void:
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)


## Set named properties on `obj` as ONE undoable action (capture old → set new),
## routed to the scene history so the user can Ctrl+Z it. Returns applied keys.
func set_props_undoable(obj: Object, props: Dictionary, action_name: String, coerce := true) -> Array:
	var applied: Array = []
	if props.is_empty():
		return applied
	var u := undo_redo()
	u.create_action(action_name, UndoRedo.MERGE_DISABLE, edited_root())
	for k: String in props:
		var old: Variant = obj.get(k)
		u.add_do_property(obj, k, coerce_to(old, props[k]) if coerce else props[k])
		u.add_undo_property(obj, k, old)
		applied.append(k)
	u.commit_action()
	return applied


## Coerce a JSON value into the type of an existing property value.
## Strings like "Vector3(0,1,0)" are parsed; plain strings stay strings; a
## property already typed as String is never reinterpreted.
func coerce_to(current: Variant, value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING:
		return value
	var s: String = value
	if typeof(current) == TYPE_STRING or typeof(current) == TYPE_STRING_NAME:
		return s
	var parsed: Variant = str_to_var(s)
	return parsed if parsed != null else s


func mark_unsaved() -> void:
	if edited_root() != null:
		EditorInterface.mark_scene_as_unsaved()


func fs_update(path: String) -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.update_file(path)


func globalize(path: String) -> String:
	return ProjectSettings.globalize_path(path)


## Closest candidates to `target` by string similarity — for "did you mean…?"
## error hints that save the agent a round-trip on typos.
func suggest(target: String, candidates: Variant) -> Array:
	var t := target.to_lower()
	var scored: Array = []
	for c in candidates:
		var cs := String(c)
		scored.append({"n": cs, "s": t.similarity(cs.to_lower())})
	scored.sort_custom(func(a, b): return a.s > b.s)
	var out: Array = []
	for i in range(mini(3, scored.size())):
		if scored[i].s >= 0.45:
			out.append(scored[i].n)
	return out


func node_has_property(node: Object, prop: String) -> bool:
	for p in node.get_property_list():
		if p.get("name", "") == prop:
			return true
	return false


## Closest existing scene-relative node paths to a (probably mistyped) one.
func node_path_suggestions(path: String) -> Array:
	var root := edited_root()
	if root == null:
		return []
	var best: Array = []
	_collect_path_suggestions(root, root, path.to_lower(), best)
	var out: Array = []
	for item in best:
		out.append(item.get("n", ""))
	return out


func _collect_paths(root: Node, node: Node, acc: Array) -> void:
	if node != root:
		acc.append(String(root.get_path_to(node)))
	for c in node.get_children():
		_collect_paths(root, c, acc)


func _collect_path_suggestions(root: Node, node: Node, target: String, best: Array) -> void:
	if node != root:
		_add_suggestion(best, target, String(root.get_path_to(node)))
	for c in node.get_children():
		_collect_path_suggestions(root, c, target, best)


func _add_suggestion(best: Array, target: String, candidate: String) -> void:
	var score := target.similarity(candidate.to_lower())
	if score < 0.45:
		return
	var at := 0
	while at < best.size() and float(best[at].get("s", 0.0)) >= score:
		at += 1
	best.insert(at, {"n": candidate, "s": score})
	if best.size() > 3:
		best.resize(3)


## Standard "node not found" failure, with did-you-mean path suggestions.
func fail_no_node(path: String) -> Dictionary:
	return fail("Node not found: %s" % path, -32000, {"suggestions": node_path_suggestions(path)})


func page_state(params: Dictionary, default_limit: int) -> Dictionary:
	var offset := maxi(0, opt_int(params, "offset", 0))
	var limit := maxi(1, opt_int(params, "limit", default_limit))
	var cap := offset + limit
	return {
		"offset": offset,
		"limit": limit,
		"total": 0,
		"items": [],
		"sorted": false,
		"collect_limit": maxi(cap, 20000),
	}


func page_add(page: Dictionary, item: Variant) -> void:
	var total := int(page["total"])
	var offset := int(page["offset"])
	var limit := int(page["limit"])
	var items: Array = page["items"]
	if total >= offset and items.size() < limit:
		items.append(item)
	page["total"] = total + 1


func page_result(page: Dictionary, items_key: String) -> Dictionary:
	var total := int(page["total"])
	var offset := int(page["offset"])
	var limit := int(page["limit"])
	var next := offset + limit
	var result := {
		"total": total,
		"offset": offset,
		"limit": limit,
		"has_more": next < total,
		"next_offset": next if next < total else null,
	}
	result[items_key] = page["items"]
	return result


func sorted_page_add(page: Dictionary, item: String) -> void:
	page["total"] = int(page["total"]) + 1
	var cap := int(page["offset"]) + int(page["limit"])
	var collect_limit := maxi(cap, int(page.get("collect_limit", cap)))
	var items: Array = page["items"]
	if not bool(page.get("sorted", false)) and items.size() < collect_limit:
		items.append(item)
		return
	if not bool(page.get("sorted", false)):
		items.sort()
		if items.size() > cap:
			items.resize(cap)
		page["sorted"] = true
	if items.size() == cap and item >= String(items[items.size() - 1]):
		return
	var at := 0
	while at < items.size() and String(items[at]) <= item:
		at += 1
	items.insert(at, item)
	if items.size() > cap:
		items.resize(cap)


func sorted_page_result(page: Dictionary, items_key: String) -> Dictionary:
	var total := int(page["total"])
	var offset := int(page["offset"])
	var limit := int(page["limit"])
	var next := offset + limit
	var items: Array = page["items"]
	if not bool(page.get("sorted", false)):
		items.sort()
		page["sorted"] = true
	if items.size() > next:
		items.resize(next)
	var start := mini(offset, items.size())
	var end := mini(next, items.size())
	var result := {
		"total": total,
		"offset": offset,
		"limit": limit,
		"has_more": next < total,
		"next_offset": next if next < total else null,
	}
	result[items_key] = items.slice(start, end)
	return result


func sorted_items_result(items: Array, params: Dictionary, default_limit: int, items_key: String) -> Dictionary:
	items.sort()
	var total := items.size()
	var offset := clampi(opt_int(params, "offset", 0), 0, total)
	var limit := maxi(1, opt_int(params, "limit", default_limit))
	var next := offset + limit
	var end := mini(next, total)
	var result := {
		"total": total,
		"offset": offset,
		"limit": limit,
		"has_more": next < total,
		"next_offset": next if next < total else null,
	}
	result[items_key] = items.slice(offset, end)
	return result


func paginate_file_lines(path: String, params: Dictionary, default_limit: int = 400) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fail("Cannot open: %s" % path)
	if f.get_length() <= FULL_READ_LINE_PAGE_MAX_BYTES:
		var text := f.get_as_text()
		f.close()
		return paginate_lines(path, text, params)
	var requested_offset := maxi(0, opt_int(params, "offset", 0))
	var limit := maxi(1, opt_int(params, "limit", default_limit))
	var requested_end := requested_offset + limit
	var total := 0
	var slice: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		if total >= requested_offset and total < requested_end:
			slice.append(line)
		total += 1
	f.close()
	var offset := mini(requested_offset, total)
	var next := offset + limit
	return success({
		"path": path,
		"total_lines": total,
		"offset": offset,
		"returned": slice.size(),
		"has_more": next < total,
		"next_offset": next if next < total else null,
		"content": "\n".join(slice),
	})


## Line-paginate a text blob into a success() payload. Shared by read_script and
## get_scene_file_content so large files are never returned whole.
func paginate_lines(path: String, text: String, params: Dictionary) -> Dictionary:
	var lines := text.split("\n")
	var total := lines.size()
	var offset := clampi(opt_int(params, "offset", 0), 0, total)
	var limit := maxi(1, opt_int(params, "limit", 400))
	var end := mini(offset + limit, total)
	var slice := lines.slice(offset, end)
	return success({
		"path": path,
		"total_lines": total,
		"offset": offset,
		"returned": slice.size(),
		"has_more": end < total,
		"next_offset": end if end < total else null,
		"content": "\n".join(slice),
	})
