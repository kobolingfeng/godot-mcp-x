@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

const TEXT_EXTS := ["gd", "tscn", "tres", "gdshader", "cfg", "json", "txt", "md", "godot"]
const ANALYSIS_CACHE_MAX_FILE_BYTES := 32 * 1024 * 1024
const ANALYSIS_TEXT_CACHE_MAX_BYTES := 96 * 1024 * 1024
const REFERENCE_PATTERN := "(res://[^\"'\\s\\)\\],]+|uid://[A-Za-z0-9_]+)"
const REFERENCE_PREHEAT_FRAME_BUDGET_USEC := 4000
const REFERENCE_PREHEAT_BATCH_LIMIT := 96
const ANALYSIS_JOB_FRAME_BUDGET_USEC := 6000
const ANALYSIS_JOB_BATCH_LIMIT := 64
const ANALYSIS_JOB_MAX_RETAINED := 16

var _text_cache: Dictionary = {}
var _text_cache_bytes := 0
var _reference_index_ready := false
var _reference_index_dirty := true
var _reference_root := "res://"
var _reference_index: Dictionary = {}
var _reference_file_keys: Dictionary = {}
var _reference_meta: Dictionary = {}
var _reference_rx: RegEx = null
var _reference_preheating := false
var _reference_preheat_dir_queue: Array = []
var _reference_preheat_queue: Array = []
var _reference_preheat_index: Dictionary = {}
var _reference_preheat_file_keys: Dictionary = {}
var _reference_preheat_meta: Dictionary = {}
var _reference_preheat_active_file := ""
var _reference_preheat_active_pos := 0
var _reference_preheat_active_line := 0
var _reference_preheat_active_dir: DirAccess = null
var _reference_preheat_active_dir_path := ""
var _jobs: Dictionary = {}
var _job_seq := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		_connect_reference_index_signals()
		call_deferred("_schedule_reference_preheat")
	_update_processing()


func _process(_delta: float) -> void:
	if _reference_preheating:
		_process_reference_preheat()
	if not _jobs.is_empty():
		_process_analysis_jobs()
	_update_processing()


func get_commands() -> Dictionary:
	return {
		"search_files": _search_files,
		"start_search_files": _start_search_files,
		"search_in_files": _search_in_files,
		"start_search_in_files": _start_search_in_files,
		"get_analysis_job": _get_analysis_job,
		"cancel_analysis_job": _cancel_analysis_job,
		"start_reference_index": _start_reference_index,
		"get_reference_index_status": _get_reference_index_status,
		"find_script_references": _find_script_references,
		"get_scene_dependencies": _get_scene_dependencies,
		"analyze_scene_complexity": _analyze_scene_complexity,
	}


func _search_files(params: Dictionary) -> Dictionary:
	if opt_bool(params, "background", false):
		return _start_search_files(params)
	var query := req_str(params, "query")
	if query == "":
		return fail("'query' is required")
	var ftype := opt_str(params, "file_type", "")
	var max_results := opt_int(params, "max_results", 50)
	var results: Array = []
	_sf_walk(opt_str(params, "path", "res://"), query.to_lower(), ftype, max_results, results)
	return success({"query": query, "count": results.size(), "files": results})


func _start_search_files(params: Dictionary) -> Dictionary:
	var query := req_str(params, "query")
	if query == "":
		return fail("'query' is required")
	_job_seq += 1
	var id := "analysis-%d" % _job_seq
	_jobs[id] = {
		"id": id,
		"kind": "search_files",
		"status": "running",
		"query": query,
		"query_lower": query.to_lower(),
		"file_type": opt_str(params, "file_type", ""),
		"max_results": opt_int(params, "max_results", 50),
		"dirs": [opt_str(params, "path", "res://")],
		"pending_files": [],
		"active_dir": null,
		"active_dir_path": "",
		"files": [],
		"scanned_files": 0,
		"scanned_dirs": 0,
		"created_msec": Time.get_ticks_msec(),
		"updated_msec": Time.get_ticks_msec(),
	}
	_trim_analysis_jobs()
	_update_processing()
	return success({"job_id": id, "status": "running"})


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
	if opt_bool(params, "background", false):
		return _start_search_in_files(params)
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


func _start_search_in_files(params: Dictionary) -> Dictionary:
	var query := req_str(params, "query")
	if query == "":
		return fail("'query' is required")
	var rx: RegEx = null
	var regex := opt_bool(params, "regex", false)
	if regex:
		rx = RegEx.new()
		if rx.compile(query) != OK:
			return fail("Invalid regex: %s" % query)
	_job_seq += 1
	var id := "analysis-%d" % _job_seq
	_jobs[id] = {
		"id": id,
		"kind": "search_in_files",
		"status": "running",
		"query": query,
		"regex": regex,
		"rx": rx,
		"file_type": opt_str(params, "file_type", ""),
		"max_results": opt_int(params, "max_results", 50),
		"dirs": [opt_str(params, "path", "res://")],
		"pending_files": [],
		"active_dir": null,
		"active_dir_path": "",
		"active_file": "",
		"active_file_pos": 0,
		"active_file_line": 0,
		"matches": [],
		"scanned_files": 0,
		"scanned_dirs": 0,
		"created_msec": Time.get_ticks_msec(),
		"updated_msec": Time.get_ticks_msec(),
	}
	_trim_analysis_jobs()
	_update_processing()
	return success({"job_id": id, "status": "running"})


func _get_analysis_job(params: Dictionary) -> Dictionary:
	var id := req_str(params, "job_id")
	if id == "" or not _jobs.has(id):
		return fail("Analysis job not found: %s" % id)
	var job: Dictionary = _jobs[id]
	var kind := String(job.get("kind", ""))
	var items_key := "files" if kind == "search_files" else "matches"
	var items: Array = job.get(items_key, [])
	var pending_files: Array = job.get("pending_files", [])
	var offset := clampi(opt_int(params, "offset", 0), 0, items.size())
	var limit := maxi(1, opt_int(params, "limit", 50))
	var end := mini(offset + limit, items.size())
	var result := {
		"job_id": id,
		"kind": kind,
		"status": job.get("status", ""),
		"query": job.get("query", ""),
		"count": items.size(),
		"offset": offset,
		"limit": limit,
		"has_more": end < items.size(),
		"next_offset": end if end < items.size() else null,
		"scanned_files": job.get("scanned_files", 0),
		"scanned_dirs": job.get("scanned_dirs", 0),
		"pending_files": pending_files.size(),
		"current_file": job.get("active_file", ""),
		"current_dir": job.get("active_dir_path", ""),
		"error": job.get("error", ""),
	}
	result[items_key] = items.slice(offset, end)
	return success(result)


func _cancel_analysis_job(params: Dictionary) -> Dictionary:
	var id := req_str(params, "job_id")
	if id == "" or not _jobs.has(id):
		return fail("Analysis job not found: %s" % id)
	var job: Dictionary = _jobs[id]
	_clear_job_active_dir(job)
	job["status"] = "cancelled"
	job["updated_msec"] = Time.get_ticks_msec()
	_jobs[id] = job
	_update_processing()
	return success({"job_id": id, "status": "cancelled"})


func _process_analysis_jobs() -> void:
	var started := Time.get_ticks_usec()
	for id in _jobs.keys():
		var job: Dictionary = _jobs[id]
		if job.get("status", "") != "running":
			continue
		match String(job.get("kind", "")):
			"search_files":
				_process_file_search_job(job, started)
			"search_in_files":
				_process_search_job(job, started)
			_:
				job["status"] = "failed"
				job["error"] = "Unknown analysis job kind: %s" % String(job.get("kind", ""))
		_jobs[id] = job
		if Time.get_ticks_usec() - started >= ANALYSIS_JOB_FRAME_BUDGET_USEC:
			return


func _process_file_search_job(job: Dictionary, started: int) -> void:
	var dirs: Array = job.get("dirs", [])
	var pending_files: Array = job.get("pending_files", [])
	var files: Array = job.get("files", [])
	var max_results := int(job.get("max_results", 50))
	var processed := 0
	while files.size() < max_results and processed < ANALYSIS_JOB_BATCH_LIMIT:
		if Time.get_ticks_usec() - started >= ANALYSIS_JOB_FRAME_BUDGET_USEC:
			break
		if job.get("active_dir", null) != null:
			_process_job_active_dir(job, pending_files, started, false)
			if job.get("active_dir", null) != null:
				break
			dirs = job.get("dirs", [])
			processed += 1
			continue
		if not pending_files.is_empty():
			var file_path := String(pending_files.pop_back())
			job["scanned_files"] = int(job.get("scanned_files", 0)) + 1
			var name := file_path.get_file()
			if _file_name_matches(name, String(job.get("query", "")), String(job.get("query_lower", ""))):
				files.append(file_path)
			processed += 1
			continue
		if dirs.is_empty():
			break
		_start_job_active_dir(job, String(dirs.pop_back()))
		_process_job_active_dir(job, pending_files, started, false)
		if job.get("active_dir", null) != null:
			break
		dirs = job.get("dirs", [])
		processed += 1
	job["dirs"] = dirs
	job["pending_files"] = pending_files
	job["files"] = files
	job["updated_msec"] = Time.get_ticks_msec()
	if files.size() >= max_results:
		job["status"] = "complete"
		job["reason"] = "max_results"
	elif dirs.is_empty() and pending_files.is_empty() and job.get("active_dir", null) == null:
		job["status"] = "complete"
		job["reason"] = "exhausted"


func _start_job_active_dir(job: Dictionary, dir_path: String) -> void:
	_clear_job_active_dir(job)
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	job["active_dir"] = d
	job["active_dir_path"] = dir_path
	job["scanned_dirs"] = int(job.get("scanned_dirs", 0)) + 1


func _process_job_active_dir(job: Dictionary, pending_files: Array, started: int, text_only: bool) -> void:
	var d: DirAccess = job.get("active_dir", null)
	if d == null:
		return
	var dirs: Array = job.get("dirs", [])
	var ftype := String(job.get("file_type", ""))
	while true:
		if Time.get_ticks_usec() - started >= ANALYSIS_JOB_FRAME_BUDGET_USEC:
			job["dirs"] = dirs
			return
		var name := d.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full := String(job.get("active_dir_path", "")).path_join(name)
		if d.current_is_dir():
			if name != ".godot":
				dirs.append(full)
		else:
			var ext := name.get_extension()
			if text_only:
				if (ftype == "" and ext in TEXT_EXTS) or (ftype != "" and ext == ftype):
					pending_files.append(full)
			elif ftype == "" or ext == ftype:
				pending_files.append(full)
	job["dirs"] = dirs
	_clear_job_active_dir(job)


func _clear_job_active_dir(job: Dictionary) -> void:
	var d: DirAccess = job.get("active_dir", null)
	if d != null:
		d.list_dir_end()
	job["active_dir"] = null
	job["active_dir_path"] = ""


func _file_name_matches(name: String, query: String, query_lower: String) -> bool:
	return name.to_lower().contains(query_lower) or name.matchn(query)


func _process_search_job(job: Dictionary, started: int) -> void:
	var dirs: Array = job.get("dirs", [])
	var pending_files: Array = job.get("pending_files", [])
	var matches: Array = job.get("matches", [])
	var max_results := int(job.get("max_results", 50))
	var processed := 0
	while matches.size() < max_results and processed < ANALYSIS_JOB_BATCH_LIMIT:
		if Time.get_ticks_usec() - started >= ANALYSIS_JOB_FRAME_BUDGET_USEC:
			break
		if String(job.get("active_file", "")) != "":
			_process_active_search_file(job, started)
			matches = job.get("matches", [])
			if String(job.get("active_file", "")) != "" or matches.size() >= max_results:
				break
			processed += 1
			continue
		if job.get("active_dir", null) != null:
			_process_job_active_dir(job, pending_files, started, true)
			if job.get("active_dir", null) != null:
				break
			dirs = job.get("dirs", [])
			processed += 1
			continue
		if not pending_files.is_empty():
			job["active_file"] = String(pending_files.pop_back())
			job["active_file_pos"] = 0
			job["active_file_line"] = 0
			job["scanned_files"] = int(job.get("scanned_files", 0)) + 1
			_process_active_search_file(job, started)
			matches = job.get("matches", [])
			if String(job.get("active_file", "")) != "" or matches.size() >= max_results:
				break
			processed += 1
			continue
		if dirs.is_empty():
			break
		_start_job_active_dir(job, String(dirs.pop_back()))
		_process_job_active_dir(job, pending_files, started, true)
		if job.get("active_dir", null) != null:
			break
		processed += 1
		dirs = job.get("dirs", [])
	job["dirs"] = dirs
	job["pending_files"] = pending_files
	job["updated_msec"] = Time.get_ticks_msec()
	if matches.size() >= max_results:
		job["status"] = "complete"
		job["reason"] = "max_results"
	elif dirs.is_empty() and pending_files.is_empty() and String(job.get("active_file", "")) == "" and job.get("active_dir", null) == null:
		job["status"] = "complete"
		job["reason"] = "exhausted"


func _process_active_search_file(job: Dictionary, started: int) -> void:
	var path := String(job.get("active_file", ""))
	if path == "":
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_clear_active_search_file(job)
		return
	f.seek(int(job.get("active_file_pos", 0)))
	var line_no := int(job.get("active_file_line", 0))
	var query := String(job.get("query", ""))
	var rx: RegEx = job.get("rx", null)
	var max_results := int(job.get("max_results", 50))
	var matches: Array = job.get("matches", [])
	while not f.eof_reached() and matches.size() < max_results:
		if Time.get_ticks_usec() - started >= ANALYSIS_JOB_FRAME_BUDGET_USEC:
			break
		var line := f.get_line()
		line_no += 1
		var hit := (rx.search(line) != null) if rx != null else line.contains(query)
		if hit:
			matches.append({"file": path, "line": line_no, "text": line.strip_edges().left(200)})
	job["matches"] = matches
	job["active_file_pos"] = int(f.get_position())
	job["active_file_line"] = line_no
	var done := f.eof_reached() or matches.size() >= max_results
	f.close()
	if done:
		_clear_active_search_file(job)


func _clear_active_search_file(job: Dictionary) -> void:
	job["active_file"] = ""
	job["active_file_pos"] = 0
	job["active_file_line"] = 0


func _trim_analysis_jobs() -> void:
	if _jobs.size() <= ANALYSIS_JOB_MAX_RETAINED:
		return
	var ids: Array = _jobs.keys()
	ids.sort_custom(func(a, b): return int(_jobs[a].get("updated_msec", 0)) < int(_jobs[b].get("updated_msec", 0)))
	while _jobs.size() > ANALYSIS_JOB_MAX_RETAINED and not ids.is_empty():
		var id := String(ids.pop_front())
		if _jobs.has(id) and _jobs[id].get("status", "") != "running":
			_jobs.erase(id)


func _update_processing() -> void:
	var has_running_job := false
	for job in _jobs.values():
		if job.get("status", "") == "running":
			has_running_job = true
			break
	set_process(_reference_preheating or has_running_job)


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


func _start_reference_index(params: Dictionary) -> Dictionary:
	var root := _reference_root_from_params(params)
	var force := opt_bool(params, "force", opt_bool(params, "refresh", false))
	if _reference_preheating and _reference_root == root and not force:
		return success(_reference_index_status_data())
	if _reference_index_is_current(root) and not force:
		return success(_reference_index_status_data())
	_cancel_reference_preheat()
	_start_reference_preheat(root)
	return success(_reference_index_status_data())


func _get_reference_index_status(params: Dictionary) -> Dictionary:
	return success(_reference_index_status_data(_reference_root_from_params(params)))


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
		if opt_bool(params, "background", false):
			_start_reference_index({"path": "res://", "force": opt_bool(params, "refresh", false)})
			return success({
				"script": script_path,
				"uid": uid,
				"references": [],
				"count": 0,
				"indexed": false,
				"index_status": _reference_index_status_data("res://"),
			})
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


func _reference_root_from_params(params: Dictionary) -> String:
	var root := opt_str(params, "path", "")
	if root == "":
		root = opt_str(params, "root", _reference_root)
	if root == "":
		root = "res://"
	return root


func _reference_index_status_data(root: String = "") -> Dictionary:
	var target_root := root if root != "" else _reference_root
	var indexed_files := _reference_preheat_meta.size() if _reference_preheating else _reference_meta.size()
	var indexed_keys := _reference_preheat_index.size() if _reference_preheating else _reference_index.size()
	return {
		"root": target_root,
		"current_root": _reference_root,
		"ready": _reference_index_is_current(target_root),
		"dirty": _reference_index_dirty,
		"preheating": _reference_preheating,
		"queued_dirs": _reference_preheat_dir_queue.size(),
		"queued_files": _reference_preheat_queue.size(),
		"active_file": _reference_preheat_active_file,
		"active_dir": _reference_preheat_active_dir_path,
		"indexed_files": indexed_files,
		"indexed_keys": indexed_keys,
		"text_cache_bytes": _text_cache_bytes,
	}


func _connect_reference_index_signals() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs == null:
		return
	var filesystem_cb := Callable(self, "_on_reference_filesystem_changed")
	if fs.has_signal("filesystem_changed") and not fs.is_connected("filesystem_changed", filesystem_cb):
		fs.connect("filesystem_changed", filesystem_cb)
	var sources_cb := Callable(self, "_on_reference_sources_changed")
	if fs.has_signal("sources_changed") and not fs.is_connected("sources_changed", sources_cb):
		fs.connect("sources_changed", sources_cb)
	var reimported_cb := Callable(self, "_on_reference_resources_changed")
	if fs.has_signal("resources_reimported") and not fs.is_connected("resources_reimported", reimported_cb):
		fs.connect("resources_reimported", reimported_cb)
	var reload_cb := Callable(self, "_on_reference_resources_changed")
	if fs.has_signal("resources_reload") and not fs.is_connected("resources_reload", reload_cb):
		fs.connect("resources_reload", reload_cb)


func _on_reference_filesystem_changed() -> void:
	_mark_reference_index_dirty()


func _on_reference_sources_changed(_exist: bool) -> void:
	_mark_reference_index_dirty()


func _on_reference_resources_changed(_resources: PackedStringArray) -> void:
	if _reference_index_ready and not _reference_preheating:
		_update_reference_paths(_resources)
	else:
		_mark_reference_index_dirty()


func _mark_reference_index_dirty() -> void:
	_reference_index_ready = false
	_reference_index_dirty = true
	_reference_index.clear()
	_reference_file_keys.clear()
	_reference_meta.clear()
	_cancel_reference_preheat()
	call_deferred("_schedule_reference_preheat")


func _cancel_reference_preheat() -> void:
	if not _reference_preheating and _reference_preheat_dir_queue.is_empty() and _reference_preheat_queue.is_empty():
		return
	_reference_preheating = false
	_reference_preheat_dir_queue.clear()
	_reference_preheat_queue.clear()
	_reference_preheat_index.clear()
	_reference_preheat_file_keys.clear()
	_reference_preheat_meta.clear()
	_clear_reference_preheat_active_file()
	_clear_reference_preheat_active_dir()
	_update_processing()


func _schedule_reference_preheat() -> void:
	if not is_inside_tree() or _reference_preheating or _reference_index_is_current("res://"):
		return
	_start_reference_preheat("res://")


func _start_reference_preheat(root: String) -> void:
	_ensure_reference_regex()
	_reference_root = root
	_reference_preheat_meta.clear()
	_reference_preheat_dir_queue = [root]
	_reference_preheat_queue.clear()
	_reference_preheat_index.clear()
	_reference_preheat_file_keys.clear()
	_clear_reference_preheat_active_file()
	_clear_reference_preheat_active_dir()
	_reference_preheating = true
	_reference_index_dirty = true
	_update_processing()


func _process_reference_preheat() -> void:
	var started := Time.get_ticks_usec()
	var processed := 0
	while processed < REFERENCE_PREHEAT_BATCH_LIMIT:
		if Time.get_ticks_usec() - started >= REFERENCE_PREHEAT_FRAME_BUDGET_USEC:
			break
		if _reference_preheat_active_file != "":
			_process_reference_preheat_active_file(started)
			if _reference_preheat_active_file != "":
				break
		elif _reference_preheat_active_dir != null:
			_process_reference_preheat_active_dir(started)
			if _reference_preheat_active_dir != null:
				break
		elif not _reference_preheat_queue.is_empty():
			_reference_preheat_active_file = String(_reference_preheat_queue.pop_back())
			_reference_preheat_active_pos = 0
			_reference_preheat_active_line = 0
			_process_reference_preheat_active_file(started)
			if _reference_preheat_active_file != "":
				break
		elif not _reference_preheat_dir_queue.is_empty():
			_start_reference_preheat_active_dir(String(_reference_preheat_dir_queue.pop_back()))
			_process_reference_preheat_active_dir(started)
			if _reference_preheat_active_dir != null:
				break
		else:
			break
		processed += 1
	if _reference_preheat_active_file != "" or _reference_preheat_active_dir != null or not _reference_preheat_queue.is_empty() or not _reference_preheat_dir_queue.is_empty():
		return
	_reference_index = _reference_preheat_index
	_reference_file_keys = _reference_preheat_file_keys
	_reference_meta = _reference_preheat_meta
	_reference_preheat_dir_queue = []
	_reference_preheat_index = {}
	_reference_preheat_file_keys = {}
	_reference_preheat_meta = {}
	_reference_preheating = false
	_reference_index_ready = true
	_reference_index_dirty = false
	_update_processing()


func _process_reference_preheat_active_file(started: int) -> void:
	var path := _reference_preheat_active_file
	if path == "":
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_clear_reference_preheat_active_file()
		return
	f.seek(_reference_preheat_active_pos)
	var line_no := _reference_preheat_active_line
	while not f.eof_reached():
		if Time.get_ticks_usec() - started >= REFERENCE_PREHEAT_FRAME_BUDGET_USEC:
			break
		var line := f.get_line()
		line_no += 1
		if line.contains("res://") or line.contains("uid://"):
			_index_reference_line(path, line_no, line, _reference_preheat_index, _reference_preheat_file_keys)
	_reference_preheat_active_pos = int(f.get_position())
	_reference_preheat_active_line = line_no
	var done := f.eof_reached()
	f.close()
	if done:
		_clear_reference_preheat_active_file()


func _clear_reference_preheat_active_file() -> void:
	_reference_preheat_active_file = ""
	_reference_preheat_active_pos = 0
	_reference_preheat_active_line = 0


func _start_reference_preheat_active_dir(dir_path: String) -> void:
	_clear_reference_preheat_active_dir()
	_reference_preheat_active_dir = DirAccess.open(dir_path)
	if _reference_preheat_active_dir == null:
		return
	_reference_preheat_active_dir_path = dir_path
	_reference_preheat_active_dir.list_dir_begin()


func _process_reference_preheat_active_dir(started: int) -> void:
	if _reference_preheat_active_dir == null:
		return
	while true:
		if Time.get_ticks_usec() - started >= REFERENCE_PREHEAT_FRAME_BUDGET_USEC:
			return
		var name := _reference_preheat_active_dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full := _reference_preheat_active_dir_path.path_join(name)
		if _reference_preheat_active_dir.current_is_dir():
			if name != ".godot":
				_reference_preheat_dir_queue.append(full)
		else:
			var ext := name.get_extension()
			if ext in TEXT_EXTS:
				_reference_preheat_meta[full] = int(FileAccess.get_modified_time(full))
				_reference_preheat_queue.append(full)
	_clear_reference_preheat_active_dir()


func _clear_reference_preheat_active_dir() -> void:
	if _reference_preheat_active_dir != null:
		_reference_preheat_active_dir.list_dir_end()
	_reference_preheat_active_dir = null
	_reference_preheat_active_dir_path = ""


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
	_reference_file_keys.clear()
	_reference_meta = meta
	_reference_root = root
	for path in _reference_meta:
		_index_file_references(path, _reference_index, _reference_file_keys)
	_reference_index_ready = true
	_reference_index_dirty = false


func _refresh_reference_index_from_meta() -> void:
	if not _reference_index_ready or _reference_preheating:
		_mark_reference_index_dirty()
		return
	var meta: Dictionary = {}
	_collect_text_meta(_reference_root, meta)
	for path in _reference_meta.keys():
		if not meta.has(path):
			_remove_file_references(path, _reference_index, _reference_file_keys)
			_uncache_text(path)
	for path in meta:
		if int(_reference_meta.get(path, -1)) != int(meta[path]):
			_remove_file_references(path, _reference_index, _reference_file_keys)
			_uncache_text(path)
			_index_file_references(path, _reference_index, _reference_file_keys)
	_reference_meta = meta
	_reference_index_ready = true
	_reference_index_dirty = false


func _update_reference_paths(paths: PackedStringArray) -> void:
	if paths.is_empty():
		return
	for path in paths:
		var p := String(path)
		if not _is_text_path(p):
			continue
		_remove_file_references(p, _reference_index, _reference_file_keys)
		_uncache_text(p)
		if FileAccess.file_exists(p):
			_reference_meta[p] = int(FileAccess.get_modified_time(p))
			_index_file_references(p, _reference_index, _reference_file_keys)
		else:
			_reference_meta.erase(p)
	_reference_index_ready = true
	_reference_index_dirty = false


func _is_text_path(path: String) -> bool:
	return path.get_extension() in TEXT_EXTS


func _uncache_text(path: String) -> void:
	if not _text_cache.has(path):
		return
	var cached: Dictionary = _text_cache[path]
	_text_cache_bytes = maxi(0, _text_cache_bytes - int(cached.get("size", 0)))
	_text_cache.erase(path)


func _ensure_reference_regex() -> void:
	if _reference_rx == null:
		_reference_rx = RegEx.new()
		_reference_rx.compile(REFERENCE_PATTERN)


func _index_file_references(path: String, index: Dictionary, file_keys: Dictionary) -> void:
	var cached := _cached_text_result(path)
	if bool(cached.get("stream", false)):
		_index_file_references_stream(path, index, file_keys)
		return
	var text := String(cached.get("text", ""))
	if text == "" or (not text.contains("res://") and not text.contains("uid://")):
		return
	var ln := 0
	for line in text.split("\n"):
		ln += 1
		if line.contains("res://") or line.contains("uid://"):
			_index_reference_line(path, ln, line, index, file_keys)


func _index_file_references_stream(path: String, index: Dictionary, file_keys: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var ln := 0
	while not f.eof_reached():
		var line := f.get_line()
		ln += 1
		if line.contains("res://") or line.contains("uid://"):
			_index_reference_line(path, ln, line, index, file_keys)
	f.close()


func _index_reference_line(path: String, line_no: int, line: String, index: Dictionary, file_keys: Dictionary) -> void:
	for m in _reference_rx.search_all(line):
		var key := m.get_string(1)
		var refs: Array = index.get(key, [])
		refs.append({"file": path, "line": line_no, "text": line.strip_edges().left(200)})
		index[key] = refs
		var keys: Array = file_keys.get(path, [])
		if not keys.has(key):
			keys.append(key)
			file_keys[path] = keys


func _remove_file_references(path: String, index: Dictionary, file_keys: Dictionary) -> void:
	var keys: Array = file_keys.get(path, [])
	if keys.is_empty():
		keys = index.keys()
	for key in keys:
		if not index.has(key):
			continue
		var refs: Array = index[key]
		for i in range(refs.size() - 1, -1, -1):
			var ref: Dictionary = refs[i]
			if String(ref.get("file", "")) == path:
				refs.remove_at(i)
		if refs.is_empty():
			index.erase(key)
		else:
			index[key] = refs
	file_keys.erase(path)


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
	var stop_at_nodes := path.get_extension() == "tscn"
	while not f.eof_reached():
		var line := f.get_line()
		if stop_at_nodes and line.begins_with("[node "):
			break
		var at := line.find("path=\"res://")
		while at != -1:
			var start := at + 6
			var end := line.find("\"", start)
			if end == -1:
				break
			var p := line.substr(start, end - start)
			if not seen.has(p):
				seen[p] = true
				deps.append(p)
			at = line.find("path=\"res://", end)
	f.close()
	return success({"scene": path, "dependencies": deps, "count": deps.size()})


func _analyze_scene_complexity(params: Dictionary) -> Dictionary:
	var path := opt_str(params, "path", "")
	var root: Node
	var temp := false
	if path != "":
		if path.get_extension() == "tscn":
			return _analyze_tscn_complexity(path)
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


func _analyze_tscn_complexity(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fail("Cannot open: %s" % path)
	var stats: Dictionary = {"total_nodes": 0, "max_depth": 0, "scripts": 0, "by_type": {}, "source": "tscn"}
	var current_node := false
	var current_node_has_script := false
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("[node "):
			if current_node and current_node_has_script:
				stats["scripts"] += 1
			current_node = true
			current_node_has_script = false
			var t := _tscn_attr(line, "type", "Node")
			var depth := _tscn_parent_depth_from_line(line)
			stats["total_nodes"] += 1
			stats["max_depth"] = maxi(int(stats["max_depth"]), depth)
			stats["by_type"][t] = int(stats["by_type"].get(t, 0)) + 1
		elif current_node and line.begins_with("["):
			if current_node_has_script:
				stats["scripts"] += 1
			current_node = false
			current_node_has_script = false
		elif current_node and line.begins_with("script ="):
			current_node_has_script = true
	if current_node and current_node_has_script:
		stats["scripts"] += 1
	f.close()
	return success(stats)


func _tscn_attr(text: String, key: String, def: String = "") -> String:
	var marker := key + "=\""
	var start := text.find(marker)
	if start == -1:
		return def
	start += marker.length()
	var end := text.find("\"", start)
	if end == -1:
		return def
	return text.substr(start, end - start)


func _tscn_parent_depth_from_line(line: String) -> int:
	var marker := "parent=\""
	var start := line.find(marker)
	if start == -1:
		return 0
	start += marker.length()
	var end := line.find("\"", start)
	if end == -1:
		return 0
	if end == start:
		return 0
	var parent := line.substr(start, end - start)
	if parent == ".":
		return 1
	var depth := 2
	var at := parent.find("/")
	while at != -1:
		depth += 1
		at = parent.find("/", at + 1)
	return depth


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
