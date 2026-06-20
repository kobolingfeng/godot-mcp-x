@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

const TEXT_EXTS := ["gd", "tscn", "tres", "gdshader", "cfg", "json", "txt", "md", "godot"]


func get_commands() -> Dictionary:
	return {
		"search_files": _search_files,
		"search_in_files": _search_in_files,
		"find_script_references": _find_script_references,
		"get_scene_dependencies": _get_scene_dependencies,
		"analyze_scene_complexity": _analyze_scene_complexity,
	}


func _search_files(params: Dictionary) -> Dictionary:
	var query := req_str(params, "query")
	if query == "":
		return fail("'query' is required")
	var ftype := opt_str(params, "file_type", "")
	var max_results := opt_int(params, "max_results", 50)
	var results: Array = []
	_sf_walk(opt_str(params, "path", "res://"), query.to_lower(), ftype, max_results, results)
	return success({"query": query, "count": results.size(), "files": results})


func _sf_walk(dir_path: String, q: String, ftype: String, maxr: int, acc: Array) -> void:
	if acc.size() >= maxr:
		return
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if acc.size() >= maxr:
			break
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if name != ".godot":
				_sf_walk(full, q, ftype, maxr, acc)
		elif (ftype == "" or name.get_extension() == ftype) and (name.to_lower().contains(q) or name.matchn(q)):
			acc.append(full)
		name = d.get_next()
	d.list_dir_end()


func _search_in_files(params: Dictionary) -> Dictionary:
	var query := req_str(params, "query")
	if query == "":
		return fail("'query' is required")
	var rx: RegEx = null
	if opt_bool(params, "regex", false):
		rx = RegEx.new()
		if rx.compile(query) != OK:
			return fail("Invalid regex: %s" % query)
	var ftype := opt_str(params, "file_type", "")
	var max_results := opt_int(params, "max_results", 50)
	var results: Array = []
	_sif_walk(opt_str(params, "path", "res://"), query, rx, ftype, max_results, results)
	return success({"query": query, "count": results.size(), "matches": results})


func _sif_walk(dir_path: String, query: String, rx: RegEx, ftype: String, maxr: int, acc: Array) -> void:
	if acc.size() >= maxr:
		return
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if acc.size() >= maxr:
			break
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if name != ".godot":
				_sif_walk(full, query, rx, ftype, maxr, acc)
		else:
			var ext := name.get_extension()
			if (ftype == "" and ext in TEXT_EXTS) or (ftype != "" and ext == ftype):
				_scan_file(full, query, rx, maxr, acc)
		name = d.get_next()
	d.list_dir_end()


func _scan_file(path: String, query: String, rx: RegEx, maxr: int, acc: Array) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var ln := 0
	while not f.eof_reached():
		if acc.size() >= maxr:
			break
		var line := f.get_line()
		ln += 1
		var hit := (rx.search(line) != null) if rx != null else line.contains(query)
		if hit:
			acc.append({"file": path, "line": ln, "text": line.strip_edges().left(200)})
	f.close()


func _find_script_references(params: Dictionary) -> Dictionary:
	var script_path := req_str(params, "script_path")
	if script_path == "":
		return fail("'script_path' is required")
	var uid := ""
	var id := ResourceLoader.get_resource_uid(script_path)
	if id != -1:
		uid = ResourceUID.id_to_text(id)
	var results: Array = []
	_sif_walk("res://", script_path, null, "", 200, results)
	if uid != "":
		_sif_walk("res://", uid, null, "", 200, results)
	return success({"script": script_path, "uid": uid, "references": results, "count": results.size()})


func _get_scene_dependencies(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if not FileAccess.file_exists(path):
		return fail("File not found: %s" % path)
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var deps: Array = []
	var rx := RegEx.new()
	rx.compile("path=\"(res://[^\"]+)\"")
	for m in rx.search_all(text):
		var p := m.get_string(1)
		if not deps.has(p):
			deps.append(p)
	return success({"scene": path, "dependencies": deps, "count": deps.size()})


func _analyze_scene_complexity(params: Dictionary) -> Dictionary:
	var path := opt_str(params, "path", "")
	var root: Node
	var temp := false
	if path != "":
		var ps: PackedScene = load(path)
		if ps == null:
			return fail("Failed to load: %s" % path)
		root = ps.instantiate()
		temp = true
	else:
		root = edited_root()
		if root == null:
			return fail("No scene open and no 'path' given")
	var stats: Dictionary = {"total_nodes": 0, "max_depth": 0, "scripts": 0, "by_type": {}}
	_analyze(root, 0, stats)
	if temp:
		root.free()
	return success(stats)


func _analyze(node: Node, depth: int, stats: Dictionary) -> void:
	stats["total_nodes"] += 1
	stats["max_depth"] = maxi(stats["max_depth"], depth)
	var t := node.get_class()
	stats["by_type"][t] = stats["by_type"].get(t, 0) + 1
	if node.get_script() != null:
		stats["scripts"] += 1
	for c in node.get_children():
		_analyze(c, depth + 1, stats)
