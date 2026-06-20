@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

const TEXT_EXTS := ["gd", "tscn", "tres", "gdshader", "cfg", "json", "txt", "md", "godot"]
const ANALYSIS_CACHE_MAX_FILE_BYTES := 32 * 1024 * 1024
const ANALYSIS_TEXT_CACHE_MAX_BYTES := 96 * 1024 * 1024
const REFERENCE_PATTERN := "(res://[^\"'\\s\\)\\],]+|uid://[A-Za-z0-9_]+)"
const REFERENCE_PREHEAT_FRAME_BUDGET_USEC := 4000
const REFERENCE_PREHEAT_BATCH_LIMIT := 96

var _text_cache: Dictionary = {}
var _text_cache_bytes := 0
var _reference_index_ready := false
var _reference_index_dirty := true
var _reference_root := "res://"
var _reference_index: Dictionary = {}
var _reference_meta: Dictionary = {}
var _reference_rx: RegEx = null
var _reference_preheating := false
var _reference_preheat_queue: Array = []
var _reference_preheat_index: Dictionary = {}
var _reference_preheat_meta: Dictionary = {}


func _ready() -> void:
	_connect_reference_index_signals()
	set_process(false)
	call_deferred("_schedule_reference_preheat")


func _process(_delta: float) -> void:
	if _reference_preheating:
		_process_reference_preheat()


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
	var cached := _cached_text_result(path)
	if bool(cached.get("stream", false)):
		_scan_file_stream(path, query, rx, maxr, acc)
		return
	var text := String(cached.get("text", ""))
	if text == "":
		return
	if rx != null:
		if rx.search(text) == null:
			return
	elif not text.contains(query):
		return
	var ln := 0
	for line in text.split("\n"):
		if acc.size() >= maxr:
			break
		ln += 1
		var hit := (rx.search(line) != null) if rx != null else line.contains(query)
		if hit:
			acc.append({"file": path, "line": ln, "text": line.strip_edges().left(200)})


func _scan_file_stream(path: String, query: String, rx: RegEx, maxr: int, acc: Array) -> void:
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
	var queries: Array = [script_path]
	if uid != "":
		queries.append(uid)
	var max_results := opt_int(params, "max_results", 200)
	if opt_bool(params, "refresh", false) or not _reference_index_is_current("res://"):
		_cancel_reference_preheat()
		_build_reference_index("res://")
	results = _reference_lookup(queries, max_results)
	return success({"script": script_path, "uid": uid, "references": results, "count": results.size(), "indexed": true})


func _sif_walk_any(dir_path: String, queries: Array, ftype: String, maxr: int, acc: Array) -> void:
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
				_sif_walk_any(full, queries, ftype, maxr, acc)
		else:
			var ext := name.get_extension()
			if (ftype == "" and ext in TEXT_EXTS) or (ftype != "" and ext == ftype):
				_scan_file_any(full, queries, maxr, acc)
		name = d.get_next()
	d.list_dir_end()


func _scan_file_any(path: String, queries: Array, maxr: int, acc: Array) -> void:
	var cached := _cached_text_result(path)
	if bool(cached.get("stream", false)):
		_scan_file_any_stream(path, queries, maxr, acc)
		return
	var text := String(cached.get("text", ""))
	if text == "" or not _text_contains_any(text, queries):
		return
	var ln := 0
	for line in text.split("\n"):
		if acc.size() >= maxr:
			break
		ln += 1
		if _text_contains_any(line, queries):
			acc.append({"file": path, "line": ln, "text": line.strip_edges().left(200)})


func _scan_file_any_stream(path: String, queries: Array, maxr: int, acc: Array) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var ln := 0
	while not f.eof_reached():
		if acc.size() >= maxr:
			break
		var line := f.get_line()
		ln += 1
		var hit := false
		for q in queries:
			if line.contains(str(q)):
				hit = true
				break
		if hit:
			acc.append({"file": path, "line": ln, "text": line.strip_edges().left(200)})
	f.close()


func _text_contains_any(text: String, queries: Array) -> bool:
	for q in queries:
		if text.contains(str(q)):
			return true
	return false


func _cached_text_result(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"text": ""}
	var size := int(f.get_length())
	if size > ANALYSIS_CACHE_MAX_FILE_BYTES:
		f.close()
		return {"stream": true}
	var mtime := int(FileAccess.get_modified_time(path))
	if _text_cache.has(path):
		var cached: Dictionary = _text_cache[path]
		if int(cached.get("mtime", -1)) == mtime and int(cached.get("size", -1)) == size:
			f.close()
			return {"text": String(cached.get("text", ""))}
		_text_cache_bytes -= int(cached.get("size", 0))
	var text := f.get_as_text()
	f.close()
	if _text_cache_bytes + size > ANALYSIS_TEXT_CACHE_MAX_BYTES:
		_text_cache.clear()
		_text_cache_bytes = 0
	if size <= ANALYSIS_TEXT_CACHE_MAX_BYTES:
		_text_cache[path] = {"mtime": mtime, "size": size, "text": text}
		_text_cache_bytes += size
	return {"text": text}


func _reference_index_is_current(root: String) -> bool:
	return _reference_index_ready and not _reference_index_dirty and _reference_root == root


func _connect_reference_index_signals() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs == null:
		return
	var filesystem_cb := Callable(self, "_on_reference_filesystem_changed")
	if not fs.filesystem_changed.is_connected(filesystem_cb):
		fs.filesystem_changed.connect(filesystem_cb)
	var sources_cb := Callable(self, "_on_reference_sources_changed")
	if not fs.sources_changed.is_connected(sources_cb):
		fs.sources_changed.connect(sources_cb)
	var reimported_cb := Callable(self, "_on_reference_resources_changed")
	if not fs.resources_reimported.is_connected(reimported_cb):
		fs.resources_reimported.connect(reimported_cb)
	var reload_cb := Callable(self, "_on_reference_resources_changed")
	if not fs.resources_reload.is_connected(reload_cb):
		fs.resources_reload.connect(reload_cb)


func _on_reference_filesystem_changed() -> void:
	_mark_reference_index_dirty()


func _on_reference_sources_changed(_exist: bool) -> void:
	_mark_reference_index_dirty()


func _on_reference_resources_changed(_resources: PackedStringArray) -> void:
	_mark_reference_index_dirty()


func _mark_reference_index_dirty() -> void:
	_reference_index_ready = false
	_reference_index_dirty = true
	_reference_index.clear()
	_reference_meta.clear()
	_cancel_reference_preheat()
	call_deferred("_schedule_reference_preheat")


func _cancel_reference_preheat() -> void:
	if not _reference_preheating and _reference_preheat_queue.is_empty():
		return
	_reference_preheating = false
	_reference_preheat_queue.clear()
	_reference_preheat_index.clear()
	_reference_preheat_meta.clear()
	set_process(false)


func _schedule_reference_preheat() -> void:
	if not is_inside_tree() or _reference_preheating or _reference_index_is_current("res://"):
		return
	_start_reference_preheat("res://")


func _start_reference_preheat(root: String) -> void:
	_ensure_reference_regex()
	_reference_root = root
	_reference_preheat_meta.clear()
	_collect_text_meta(root, _reference_preheat_meta)
	_reference_preheat_queue = _reference_preheat_meta.keys()
	_reference_preheat_index.clear()
	_reference_preheating = true
	_reference_index_dirty = true
	set_process(true)


func _process_reference_preheat() -> void:
	var started := Time.get_ticks_usec()
	var processed := 0
	while not _reference_preheat_queue.is_empty() and processed < REFERENCE_PREHEAT_BATCH_LIMIT:
		if Time.get_ticks_usec() - started >= REFERENCE_PREHEAT_FRAME_BUDGET_USEC:
			break
		var path := String(_reference_preheat_queue.pop_back())
		_index_file_references(path, _reference_preheat_index)
		processed += 1
	if not _reference_preheat_queue.is_empty():
		return
	_reference_index = _reference_preheat_index
	_reference_meta = _reference_preheat_meta
	_reference_preheat_index = {}
	_reference_preheat_meta = {}
	_reference_preheating = false
	_reference_index_ready = true
	_reference_index_dirty = false
	set_process(false)


func _collect_text_meta(dir_path: String, meta: Dictionary) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if name != ".godot":
				_collect_text_meta(full, meta)
		else:
			var ext := name.get_extension()
			if ext in TEXT_EXTS:
				meta[full] = int(FileAccess.get_modified_time(full))
		name = d.get_next()
	d.list_dir_end()


func _build_reference_index(root: String) -> void:
	_ensure_reference_regex()
	var meta: Dictionary = {}
	_collect_text_meta(root, meta)
	_reference_index.clear()
	_reference_meta = meta
	_reference_root = root
	for path in _reference_meta:
		_index_file_references(path, _reference_index)
	_reference_index_ready = true
	_reference_index_dirty = false


func _ensure_reference_regex() -> void:
	if _reference_rx == null:
		_reference_rx = RegEx.new()
		_reference_rx.compile(REFERENCE_PATTERN)


func _index_file_references(path: String, index: Dictionary) -> void:
	var cached := _cached_text_result(path)
	if bool(cached.get("stream", false)):
		_index_file_references_stream(path, index)
		return
	var text := String(cached.get("text", ""))
	if text == "" or (not text.contains("res://") and not text.contains("uid://")):
		return
	var ln := 0
	for line in text.split("\n"):
		ln += 1
		if line.contains("res://") or line.contains("uid://"):
			_index_reference_line(path, ln, line, index)


func _index_file_references_stream(path: String, index: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var ln := 0
	while not f.eof_reached():
		var line := f.get_line()
		ln += 1
		if line.contains("res://") or line.contains("uid://"):
			_index_reference_line(path, ln, line, index)
	f.close()


func _index_reference_line(path: String, line_no: int, line: String, index: Dictionary) -> void:
	for m in _reference_rx.search_all(line):
		var key := m.get_string(1)
		var refs: Array = index.get(key, [])
		refs.append({"file": path, "line": line_no, "text": line.strip_edges().left(200)})
		index[key] = refs


func _reference_lookup(queries: Array, max_results: int) -> Array:
	var results: Array = []
	var seen: Dictionary = {}
	for q in queries:
		var refs: Array = _reference_index.get(str(q), [])
		for ref in refs:
			var sig := "%s:%d" % [ref.get("file", ""), int(ref.get("line", 0))]
			if seen.has(sig):
				continue
			seen[sig] = true
			results.append(ref)
			if results.size() >= max_results:
				return results
	return results


func _get_scene_dependencies(params: Dictionary) -> Dictionary:
	var path := req_str(params, "path")
	if not FileAccess.file_exists(path):
		return fail("File not found: %s" % path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fail("Cannot open: %s" % path)
	var deps: Array = []
	var seen: Dictionary = {}
	var rx := RegEx.new()
	rx.compile("path=\"(res://[^\"]+)\"")
	if f.get_length() <= FULL_READ_LINE_PAGE_MAX_BYTES:
		var text := f.get_as_text()
		for m in rx.search_all(text):
			var p := m.get_string(1)
			if not seen.has(p):
				seen[p] = true
				deps.append(p)
	else:
		while not f.eof_reached():
			var line := f.get_line()
			for m in rx.search_all(line):
				var p := m.get_string(1)
				if not seen.has(p):
					seen[p] = true
					deps.append(p)
	f.close()
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
	var stats := _analyze_iterative(root)
	if temp:
		root.free()
	return success(stats)


func _analyze_iterative(root: Node) -> Dictionary:
	var stats: Dictionary = {"total_nodes": 0, "max_depth": 0, "scripts": 0, "by_type": {}}
	var stack: Array = [{"node": root, "depth": 0}]
	while not stack.is_empty():
		var item: Dictionary = stack.pop_back()
		var node: Node = item["node"]
		var depth := int(item["depth"])
		stats["total_nodes"] += 1
		stats["max_depth"] = maxi(stats["max_depth"], depth)
		var t := node.get_class()
		stats["by_type"][t] = stats["by_type"].get(t, 0) + 1
		if node.get_script() != null:
			stats["scripts"] += 1
		for c in node.get_children():
			stack.append({"node": c, "depth": depth + 1})
	return stats
