@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## TileMapLayer-native (the modern 4.x tilemap API; TileMap is deprecated).


func get_commands() -> Dictionary:
	return {
		"tilemap_get_info": _info,
		"tilemap_set_cell": _set_cell,
		"tilemap_get_cell": _get_cell,
		"tilemap_erase_cell": _erase_cell,
		"tilemap_fill_rect": _fill_rect,
		"tilemap_clear": _clear,
		"tilemap_get_used_cells": _used_cells,
	}


func _layer(path: String) -> TileMapLayer:
	return resolve_node(path) as TileMapLayer


func _info(params: Dictionary) -> Dictionary:
	var layer := _layer(req_str(params, "path"))
	if layer == null:
		return fail("TileMapLayer not found at: %s" % req_str(params, "path"))
	return success({
		"path": rel_path(layer),
		"has_tileset": layer.tile_set != null,
		"used_cells": layer.get_used_cells().size(),
		"enabled": layer.enabled,
	})


func _set_cell(params: Dictionary) -> Dictionary:
	var layer := _layer(req_str(params, "path"))
	if layer == null:
		return fail("TileMapLayer not found")
	var coords := Vector2i(opt_int(params, "x", 0), opt_int(params, "y", 0))
	var src := opt_int(params, "source_id", 0)
	var atlas := Vector2i(opt_int(params, "atlas_x", 0), opt_int(params, "atlas_y", 0))
	var alt := opt_int(params, "alternative", 0)
	var u := undo_redo()
	u.create_action("Set tile", UndoRedo.MERGE_DISABLE, edited_root())
	u.add_undo_method(layer, "set_cell", coords, layer.get_cell_source_id(coords), layer.get_cell_atlas_coords(coords), layer.get_cell_alternative_tile(coords))
	u.add_do_method(layer, "set_cell", coords, src, atlas, alt)
	u.commit_action()
	return success({"path": rel_path(layer), "cell": [coords.x, coords.y]})


func _get_cell(params: Dictionary) -> Dictionary:
	var layer := _layer(req_str(params, "path"))
	if layer == null:
		return fail("TileMapLayer not found")
	var coords := Vector2i(opt_int(params, "x", 0), opt_int(params, "y", 0))
	var atlas := layer.get_cell_atlas_coords(coords)
	return success({
		"cell": [coords.x, coords.y],
		"source_id": layer.get_cell_source_id(coords),
		"atlas_coords": [atlas.x, atlas.y],
	})


func _erase_cell(params: Dictionary) -> Dictionary:
	var layer := _layer(req_str(params, "path"))
	if layer == null:
		return fail("TileMapLayer not found")
	var coords := Vector2i(opt_int(params, "x", 0), opt_int(params, "y", 0))
	layer.erase_cell(coords)
	mark_unsaved()
	return success({"erased": [coords.x, coords.y]})


func _fill_rect(params: Dictionary) -> Dictionary:
	var layer := _layer(req_str(params, "path"))
	if layer == null:
		return fail("TileMapLayer not found")
	var x := opt_int(params, "x", 0)
	var y := opt_int(params, "y", 0)
	var w := opt_int(params, "w", 1)
	var h := opt_int(params, "h", 1)
	var sid := opt_int(params, "source_id", 0)
	var atlas := Vector2i(opt_int(params, "atlas_x", 0), opt_int(params, "atlas_y", 0))
	var count := 0
	var u := undo_redo()
	u.create_action("Fill tiles", UndoRedo.MERGE_DISABLE, edited_root())
	for iy in range(y, y + h):
		for ix in range(x, x + w):
			var c := Vector2i(ix, iy)
			u.add_undo_method(layer, "set_cell", c, layer.get_cell_source_id(c), layer.get_cell_atlas_coords(c), layer.get_cell_alternative_tile(c))
			u.add_do_method(layer, "set_cell", c, sid, atlas, 0)
			count += 1
	u.commit_action()
	return success({"path": rel_path(layer), "filled": count})


func _clear(params: Dictionary) -> Dictionary:
	var layer := _layer(req_str(params, "path"))
	if layer == null:
		return fail("TileMapLayer not found")
	layer.clear()
	mark_unsaved()
	return success({"cleared": true})


func _used_cells(params: Dictionary) -> Dictionary:
	var layer := _layer(req_str(params, "path"))
	if layer == null:
		return fail("TileMapLayer not found")
	var cells: Array = []
	for c in layer.get_used_cells():
		cells.append([c.x, c.y])
	var offset := opt_int(params, "offset", 0)
	var limit := opt_int(params, "limit", 500)
	return success({
		"total": cells.size(),
		"offset": offset,
		"limit": limit,
		"has_more": offset + limit < cells.size(),
		"cells": cells.slice(offset, offset + limit),
	})
