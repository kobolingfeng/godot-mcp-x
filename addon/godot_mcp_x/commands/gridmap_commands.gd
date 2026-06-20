@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## GridMap — 3D tile/block level building. Cells store an item index from the
## assigned MeshLibrary (item -1 = empty).


func get_commands() -> Dictionary:
	return {
		"add_gridmap": _add,
		"gridmap_set_cell": _set_cell,
		"gridmap_get_cell": _get_cell,
		"gridmap_clear": _clear,
		"gridmap_get_used_cells": _used,
		"gridmap_get_info": _info,
	}


func _gm(path: String) -> GridMap:
	return resolve_node(path) as GridMap


func _add(params: Dictionary) -> Dictionary:
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail("Parent not found")
	var gm := GridMap.new()
	gm.name = opt_str(params, "name", "GridMap")
	if has_key(params, "cell_size"):
		var c: Variant = str_to_var(req_str(params, "cell_size"))
		if c is Vector3:
			gm.cell_size = c
	if has_key(params, "mesh_library"):
		var ml: Variant = load(req_str(params, "mesh_library"))
		if ml is MeshLibrary:
			gm.mesh_library = ml
	add_node_undoable(parent, gm, "Add GridMap")
	return success({"path": rel_path(gm)})


func _set_cell(params: Dictionary) -> Dictionary:
	var gm := _gm(req_str(params, "path"))
	if gm == null:
		return fail("GridMap not found: %s" % req_str(params, "path"))
	var pos := Vector3i(opt_int(params, "x", 0), opt_int(params, "y", 0), opt_int(params, "z", 0))
	var item := opt_int(params, "item", 0)
	var orient := opt_int(params, "orientation", 0)
	var old_item := gm.get_cell_item(pos)
	var old_orient := gm.get_cell_item_orientation(pos)
	var u := undo_redo()
	u.create_action("Set gridmap cell", UndoRedo.MERGE_DISABLE, edited_root())
	u.add_do_method(gm, "set_cell_item", pos, item, orient)
	u.add_undo_method(gm, "set_cell_item", pos, old_item, old_orient)
	u.commit_action()
	return success({"path": rel_path(gm), "cell": [pos.x, pos.y, pos.z], "item": item})


func _get_cell(params: Dictionary) -> Dictionary:
	var gm := _gm(req_str(params, "path"))
	if gm == null:
		return fail("GridMap not found")
	var pos := Vector3i(opt_int(params, "x", 0), opt_int(params, "y", 0), opt_int(params, "z", 0))
	return success({"cell": [pos.x, pos.y, pos.z], "item": gm.get_cell_item(pos)})


func _clear(params: Dictionary) -> Dictionary:
	var gm := _gm(req_str(params, "path"))
	if gm == null:
		return fail("GridMap not found")
	gm.clear()
	mark_unsaved()
	return success({"cleared": true})


func _used(params: Dictionary) -> Dictionary:
	var gm := _gm(req_str(params, "path"))
	if gm == null:
		return fail("GridMap not found")
	var used := gm.get_used_cells()
	var total := used.size()
	var offset := clampi(opt_int(params, "offset", 0), 0, total)
	var limit := maxi(1, opt_int(params, "limit", 500))
	var end := mini(offset + limit, total)
	var cells: Array = []
	for i in range(offset, end):
		var c: Vector3i = used[i]
		cells.append([c.x, c.y, c.z])
	return success({
		"total": total,
		"offset": offset,
		"limit": limit,
		"has_more": end < total,
		"next_offset": end if end < total else null,
		"cells": cells,
	})


func _info(params: Dictionary) -> Dictionary:
	var gm := _gm(req_str(params, "path"))
	if gm == null:
		return fail("GridMap not found")
	return success({
		"path": rel_path(gm),
		"has_mesh_library": gm.mesh_library != null,
		"cell_size": Serialize.to_json(gm.cell_size),
		"used_cells": gm.get_used_cells().size(),
	})
