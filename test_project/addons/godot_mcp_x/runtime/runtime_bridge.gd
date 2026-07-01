extends Node

## godot-mcp-x RUNTIME bridge. Registered as an autoload by the editor plugin and
## runs ONLY in the playing game (this script is intentionally NOT @tool). It
## dials the MCP server on 6605-6609 and serves runtime inspection/control
## commands — a direct WebSocket replacing the original tool's per-frame file
## polling (no disk I/O, no editor relay).

const Serialize := preload("res://addons/godot_mcp_x/core/serialize.gd")

const BASE_PORT := 6605
const MAX_PORT := 6609
const RECONNECT_INTERVAL := 3.0
const BUFFER_SIZE := 16 * 1024 * 1024
const PING_INTERVAL := 5.0
const PATH_SUGGESTION_NODE_BUDGET := 5000
const SNIPPET_CACHE_MAX := 128

var _peers: Dictionary = {}
var _connected: Dictionary = {}
var _reconnect: Dictionary = {}
var _ping: Dictionary = {}
var _handlers: Dictionary = {}
var _test_log: Array = []


func _ready() -> void:
	# Keep polling the socket even when the game is paused, so tools can drive /
	# inspect a paused game (pause menus, frozen-state debugging).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_handlers = {
		"get_game_info": _get_game_info,
		"get_game_scene_tree": _get_game_scene_tree,
		"get_game_node_properties": _get_game_node_properties,
		"set_game_node_property": _set_game_node_property,
		"execute_game_script": _execute_game_script,
		"get_game_screenshot": _get_game_screenshot,
		"reload_game_script": _reload_game_script,
		"setup_multiplayer_peer": _setup_multiplayer_peer,
		"get_multiplayer_info": _get_multiplayer_info,
		"set_game_authority": _set_game_authority,
		"simulate_action": _simulate_action,
		"simulate_key": _simulate_key,
		"get_autoload": _get_autoload,
		"find_game_nodes": _find_game_nodes,
		"assert_property": _assert_property,
		"assert_node_exists": _assert_node_exists,
		"assert_screen_text": _assert_screen_text,
		"wait_for_node": _wait_for_node,
		"monitor_property": _monitor_property,
		"record_frames": _record_frames,
		"run_test_scenario": _run_test_scenario,
		"get_test_report": _get_test_report,
		"call_game_method": _call_game_method,
	}
	for p in range(BASE_PORT, MAX_PORT + 1):
		_connected[p] = false
		_reconnect[p] = 0.0
		_try_connect(p)
	print("[MCP-X] Runtime bridge dialing ports %d-%d" % [BASE_PORT, MAX_PORT])


func _try_connect(p: int) -> void:
	var ws := WebSocketPeer.new()
	ws.outbound_buffer_size = BUFFER_SIZE
	ws.inbound_buffer_size = BUFFER_SIZE
	_peers[p] = ws if ws.connect_to_url("ws://127.0.0.1:%d" % p) == OK else null


func _process(delta: float) -> void:
	for p in range(BASE_PORT, MAX_PORT + 1):
		var ws: WebSocketPeer = _peers.get(p)
		if ws == null:
			_reconnect[p] = _reconnect.get(p, 0.0) + delta
			if _reconnect[p] >= RECONNECT_INTERVAL:
				_reconnect[p] = 0.0
				_try_connect(p)
			continue
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if not _connected.get(p, false):
					_connected[p] = true
					_ping[p] = 0.0
					ws.send_text(JSON.stringify({"jsonrpc": "2.0", "method": "hello", "params": {"role": "runtime"}}))
				else:
					_ping[p] = _ping.get(p, 0.0) + delta
				while ws.get_available_packet_count() > 0:
					_dispatch(ws.get_packet().get_string_from_utf8(), p)
				if _ping.get(p, 0.0) >= PING_INTERVAL:
					_ping[p] = 0.0
					ws.send_text(JSON.stringify({"jsonrpc": "2.0", "method": "ping", "params": {}}))
			WebSocketPeer.STATE_CLOSED:
				_connected[p] = false
				_peers[p] = null
				_reconnect[p] = 0.0


func _send(p: int, text: String) -> void:
	var ws: WebSocketPeer = _peers.get(p)
	if ws and _connected.get(p, false):
		ws.send_text(text)


func _dispatch(text: String, port: int) -> void:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return
	var msg: Dictionary = json.data
	var method: String = msg.get("method", "")
	if method == "ping":
		_send(port, JSON.stringify({"jsonrpc": "2.0", "method": "pong", "params": {}}))
		return
	if method == "pong" or method == "hello":
		return
	var id: Variant = msg.get("id")
	var params: Dictionary = msg.get("params", {})
	if not _handlers.has(method):
		_respond(port, id, null, {"code": -32601, "message": "Runtime method not found: %s" % method})
		return
	_run.call_deferred(port, id, method, params)


func _run(port: int, id: Variant, method: String, params: Dictionary) -> void:
	var res: Variant = await (_handlers[method] as Callable).call(params)
	if res is Dictionary and res.has("error"):
		_respond(port, id, null, res["error"])
	else:
		_respond(port, id, res.get("result", {}) if res is Dictionary else res, null)


func _respond(port: int, id: Variant, result: Variant, err: Variant) -> void:
	var r: Dictionary = {"jsonrpc": "2.0", "id": id}
	if err != null:
		r["error"] = err
	else:
		r["result"] = result if result != null else {}
	_send(port, JSON.stringify(r))


# ---------- helpers ----------
func _ok(data: Variant = null) -> Dictionary:
	return {"result": data if data != null else {}}


func _fail(msg: String, code: int = -32000, data: Dictionary = {}) -> Dictionary:
	return {"error": {"code": code, "message": msg, "data": data}}


func _scene_root() -> Node:
	return get_tree().current_scene


func _resolve(path: String) -> Node:
	var root := _scene_root()
	if root == null:
		return null
	if path == "" or path == ".":
		return root
	var p := path
	if p.begins_with("/root/"):
		return get_tree().root.get_node_or_null(NodePath(p.substr(6)))
	if p.begins_with("./"):
		p = p.substr(2)
	return root.get_node_or_null(NodePath(p))


func _rel(node: Node) -> String:
	var root := _scene_root()
	if root == null:
		return String(node.get_path())
	if node == root:
		return "."
	return String(root.get_path_to(node))


func _suggest(target: String, candidates: Variant) -> Array:
	var t := target.to_lower()
	var scored: Array = []
	for c in candidates:
		scored.append({"n": String(c), "s": t.similarity(String(c).to_lower())})
	scored.sort_custom(func(a, b): return a.s > b.s)
	var out: Array = []
	for i in range(mini(3, scored.size())):
		if scored[i].s >= 0.45:
			out.append(scored[i].n)
	return out


func _has_property(node: Object, prop: String) -> bool:
	for p in node.get_property_list():
		if p.get("name", "") == prop:
			return true
	return false


func _node_paths() -> Array:
	var root := _scene_root()
	var paths: Array = []
	if root:
		_collect_paths(root, root, paths)
	return paths


func _node_path_suggestions(path: String) -> Array:
	var root := _scene_root()
	if root == null:
		return []
	var best: Array = []
	var state := {"visited": 0}
	_collect_path_suggestions(root, root, path.to_lower(), best, state)
	var out: Array = []
	for item in best:
		out.append(item.get("n", ""))
	return out


func _collect_paths(root: Node, node: Node, acc: Array) -> void:
	if node != root:
		acc.append(String(root.get_path_to(node)))
	for c in node.get_children():
		_collect_paths(root, c, acc)


func _collect_path_suggestions(root: Node, node: Node, target: String, best: Array, state: Dictionary) -> void:
	if int(state.get("visited", 0)) >= PATH_SUGGESTION_NODE_BUDGET:
		return
	state["visited"] = int(state.get("visited", 0)) + 1
	if node != root:
		_add_suggestion(best, target, String(root.get_path_to(node)))
	for c in node.get_children():
		if int(state.get("visited", 0)) >= PATH_SUGGESTION_NODE_BUDGET:
			break
		_collect_path_suggestions(root, c, target, best, state)


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


# ---------- handlers ----------
func _get_game_info(_params: Dictionary) -> Dictionary:
	var root := _scene_root()
	return _ok({
		"current_scene": root.scene_file_path if root else "",
		"root_name": String(root.name) if root else "",
		"fps": Engine.get_frames_per_second(),
		"node_count": get_tree().get_node_count(),
		"time_scale": Engine.time_scale,
	})


func _get_game_scene_tree(params: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _fail("No current scene in the running game")
	var tree := Serialize.scene_tree(
		root,
		int(params.get("max_depth", -1)),
		bool(params.get("include_internal", false)),
		bool(params.get("include_properties", false)),
		str(params.get("type_filter", "")),
		int(params.get("max_nodes", 0)),
	)
	return _ok({"scene": root.scene_file_path, "tree": tree})


func _get_game_node_properties(params: Dictionary) -> Dictionary:
	var node := _resolve(str(params.get("path", "")))
	if node == null:
		return _fail("Node not found: %s" % params.get("path", ""), -32000, {"suggestions": _node_path_suggestions(str(params.get("path", "")))})
	var props: Dictionary
	if params.has("names") and params["names"] is Array:
		props = Serialize.picked_properties(node, params["names"])
	elif bool(params.get("include_defaults", false)):
		props = Serialize.all_properties(node)
	else:
		props = Serialize.changed_properties(node)
	return _ok({"path": _rel(node), "type": node.get_class(), "properties": props})


func _set_game_node_property(params: Dictionary) -> Dictionary:
	var node := _resolve(str(params.get("path", "")))
	if node == null:
		return _fail("Node not found: %s" % params.get("path", ""), -32000, {"suggestions": _node_path_suggestions(str(params.get("path", "")))})
	var prop := str(params.get("property", ""))
	if prop == "":
		return _fail("'property' is required")
	if not params.has("value"):
		return _fail("'value' is required")
	if not _has_property(node, prop):
		var pnames: Array = []
		for p in node.get_property_list():
			pnames.append(p.get("name", ""))
		return _fail("Node %s has no property '%s'" % [node.get_class(), prop], -32000, {"suggestions": _suggest(prop, pnames)})
	var cur: Variant = node.get(prop)
	var val: Variant = params["value"]
	if val is String and typeof(cur) != TYPE_STRING and typeof(cur) != TYPE_STRING_NAME:
		var parsed: Variant = str_to_var(val)
		if parsed != null:
			val = parsed
	node.set(prop, val)
	return _ok({"path": _rel(node), "property": prop, "value": Serialize.to_json(node.get(prop))})


var _snippet_cache: Dictionary = {}
var _snippet_cache_order: Array = []


## Compile (and cache) a wrapped GDScript snippet — repeated identical calls
## (e.g. polling the same state) skip recompilation.
func _compile(src: String) -> GDScript:
	var key := "%d:%d" % [src.length(), src.hash()]
	var cached: Variant = _snippet_cache.get(key)
	if cached is GDScript:
		return cached
	var gd := GDScript.new()
	gd.source_code = src
	if gd.reload() != OK:
		return null
	_snippet_cache[key] = gd
	_snippet_cache_order.append(key)
	while _snippet_cache_order.size() > SNIPPET_CACHE_MAX:
		_snippet_cache.erase(_snippet_cache_order.pop_front())
	return gd


func _execute_game_script(params: Dictionary) -> Dictionary:
	var code := str(params.get("code", ""))
	if code.strip_edges() == "":
		return _fail("'code' is required")
	var indented := ""
	for line in code.split("\n"):
		indented += "\t" + line + "\n"
	var src := "extends Node\nvar _o: Array = []\nfunc _mcp_print(v): _o.append(str(v))\nfunc run() -> Variant:\n" + indented + "\treturn null\n"
	var gd := _compile(src)
	if gd == null:
		return _fail("Script failed to compile")
	var inst: Node = gd.new()
	add_child(inst)
	var ret: Variant = inst.call("run")
	while ret is Object and (ret as Object).get_class() == "GDScriptFunctionState":
		ret = await (ret as Object).completed
	var out: Array = inst.get("_o")
	inst.queue_free()
	return _ok({"output": out, "return_value": null if ret == null else str(ret)})


func _get_game_screenshot(params: Dictionary) -> Dictionary:
	var save_path := str(params.get("save_path", ""))
	if save_path == "":
		save_path = "user://mcp_x/game_screenshot.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	# Optional: run a GDScript snippet first (e.g. trigger a one-shot effect) so a
	# transient VFX can be captured in the SAME call (no inter-call latency).
	var run_code := str(params.get("run", ""))
	if run_code != "":
		await _run_snippet(run_code)
	var after := float(params.get("after", 0.0))
	if after > 0.0:
		await get_tree().create_timer(after).timeout
	var count := int(params.get("count", 1))
	if count <= 1:
		var one: Dictionary = await _capture_one(save_path)
		return _ok(one) if one.get("ok", false) else _fail(str(one.get("err", "capture failed")))
	# Burst: save_path used as a prefix — x.png -> x_0.png, x_1.png, ...
	var interval := float(params.get("interval", 0.1))
	var base := save_path.get_basename()
	var ext := save_path.get_extension()
	var frames: Array = []
	for i in count:
		var r: Dictionary = await _capture_one("%s_%d.%s" % [base, i, ext])
		if r.get("ok", false):
			frames.append(r.get("os_path"))
		if i < count - 1:
			await get_tree().create_timer(interval).timeout
	return _ok({"frames": frames, "count": frames.size(), "interval": interval})


func _capture_one(save_path: String) -> Dictionary:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return {"ok": false, "err": "Failed to capture game viewport"}
	if img.save_png(save_path) != OK:
		return {"ok": false, "err": "save_png failed"}
	return {"ok": true, "saved": save_path, "os_path": ProjectSettings.globalize_path(save_path), "width": img.get_width(), "height": img.get_height()}


func _run_snippet(code: String) -> void:
	var indented := ""
	for line in code.split("\n"):
		indented += "\t" + line + "\n"
	var gd := _compile("extends Node\nfunc run() -> Variant:\n" + indented + "\treturn null\n")
	if gd == null:
		return
	var inst: Node = gd.new()
	add_child(inst)
	var ret: Variant = inst.call("run")
	while ret is Object and (ret as Object).get_class() == "GDScriptFunctionState":
		ret = await (ret as Object).completed
	inst.queue_free()


func _simulate_action(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", ""))
	if action == "":
		return _fail("'action' is required")
	if not InputMap.has_action(action):
		return _fail("Unknown input action: %s" % action)
	var mode := str(params.get("mode", "tap"))
	if mode == "release":
		Input.action_release(action)
		return _ok({"action": action, "mode": "release"})
	Input.action_press(action, float(params.get("strength", 1.0)))
	if mode == "press":  # stays held until release (or the safety auto-release)
		var max_hold := float(params.get("max_hold", 10.0))
		if max_hold > 0.0:
			get_tree().create_timer(max_hold).timeout.connect(Input.action_release.bind(action))
		return _ok({"action": action, "mode": "press", "auto_release_in": max_hold})
	var dur := float(params.get("duration", 0.1))
	await get_tree().create_timer(dur).timeout
	Input.action_release(action)
	return _ok({"action": action, "duration": dur, "mode": "tap"})


func _simulate_key(params: Dictionary) -> Dictionary:
	var keystr := str(params.get("key", ""))
	var keycode := OS.find_keycode_from_string(keystr)
	if keycode == 0:
		return _fail("Unknown key: %s" % keystr)
	var mode := str(params.get("mode", "tap"))
	if mode == "release":
		_key_event(keycode, false)
		return _ok({"key": keystr, "mode": "release"})
	_key_event(keycode, true)
	if mode == "press":  # stays held until release (or the safety auto-release)
		var max_hold := float(params.get("max_hold", 10.0))
		if max_hold > 0.0:
			get_tree().create_timer(max_hold).timeout.connect(_key_event.bind(keycode, false))
		return _ok({"key": keystr, "mode": "press", "auto_release_in": max_hold})
	var dur := float(params.get("duration", 0.1))
	await get_tree().create_timer(dur).timeout
	_key_event(keycode, false)
	return _ok({"key": keystr, "duration": dur, "mode": "tap"})


func _key_event(keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _reload_game_script(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	if not ResourceLoader.exists(path):
		return _fail("Script not found: %s" % path)
	var sc: Variant = load(path)
	if not (sc is GDScript):
		return _fail("Not a GDScript: %s" % path)
	# load() returns the cached, in-memory script, so re-read the latest source
	# from disk before recompiling — otherwise reload() just rebuilds old code.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _fail("Cannot read: %s" % path)
	(sc as GDScript).source_code = f.get_as_text()
	f.close()
	var err: int = (sc as GDScript).reload(true)  # keep_state: preserve live instance vars
	if err != OK:
		return _fail("reload failed (error %d)" % err)
	return _ok({"reloaded": path})


func _setup_multiplayer_peer(params: Dictionary) -> Dictionary:
	var mode := str(params.get("mode", "server"))
	var port := int(params.get("port", 7777))
	var peer := ENetMultiplayerPeer.new()
	var err := OK
	if mode == "client":
		err = peer.create_client(str(params.get("host", "127.0.0.1")), port)
	else:
		err = peer.create_server(port, int(params.get("max_clients", 32)))
	if err != OK:
		return _fail("create_%s failed (error %d)" % [mode, err])
	multiplayer.multiplayer_peer = peer
	return _ok({"mode": mode, "port": port, "is_server": multiplayer.is_server(), "unique_id": multiplayer.get_unique_id()})


func _get_multiplayer_info(_params: Dictionary) -> Dictionary:
	var has_peer := multiplayer.multiplayer_peer != null
	var info := {"has_peer": has_peer}
	if has_peer:
		info["is_server"] = multiplayer.is_server()
		info["unique_id"] = multiplayer.get_unique_id()
		var peers: Array = []
		for p in multiplayer.get_peers():
			peers.append(p)
		info["peers"] = peers
	return _ok(info)


func _set_game_authority(params: Dictionary) -> Dictionary:
	var node := _resolve(str(params.get("path", "")))
	if node == null:
		return _fail("Node not found: %s" % str(params.get("path", "")))
	node.set_multiplayer_authority(int(params.get("id", 1)), bool(params.get("recursive", true)))
	return _ok({"path": str(params.get("path", "")), "authority": node.get_multiplayer_authority()})


func _get_autoload(params: Dictionary) -> Dictionary:
	var name := str(params.get("name", ""))
	var node := get_tree().root.get_node_or_null(NodePath(name))
	if node == null:
		return _fail("Autoload not found: %s" % name)
	return _ok({"name": name, "type": node.get_class(), "properties": Serialize.changed_properties(node)})


func _call_game_method(params: Dictionary) -> Dictionary:
	var node := _resolve(str(params.get("path", "")))
	if node == null:
		return _fail("Node not found: %s" % params.get("path", ""), -32000, {"suggestions": _node_path_suggestions(str(params.get("path", "")))})
	var method := str(params.get("method", ""))
	if not node.has_method(method):
		var mnames: Array = []
		for m in node.get_method_list():
			mnames.append(m.get("name", ""))
		return _fail("Node %s has no method '%s'" % [node.get_class(), method], -32000, {"suggestions": _suggest(method, mnames)})
	var args: Array = []
	for a in params.get("args", []):
		var v: Variant = a
		if v is String:
			var p: Variant = str_to_var(v)
			if p != null:
				v = p
		args.append(v)
	var ret: Variant = node.callv(method, args)
	return _ok({"path": _rel(node), "method": method, "return": Serialize.to_json(ret)})


func _find_game_nodes(params: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _fail("No current scene")
	var matches: Array = []
	var offset := maxi(0, int(params.get("offset", 0)))
	var limit := maxi(1, int(params.get("limit", 200)))
	var max_nodes := maxi(0, int(params.get("max_nodes", 0)))
	var state := {"visited": 0, "matched": 0, "has_more": false, "truncated": false}
	_collect(root, root, str(params.get("type", "")), str(params.get("pattern", "")), str(params.get("group", "")), matches, offset, limit, max_nodes, state)
	return _ok({
		"count": matches.size(),
		"matched": int(state.get("matched", 0)),
		"offset": offset,
		"limit": limit,
		"has_more": bool(state.get("has_more", false)),
		"next_offset": offset + limit if bool(state.get("has_more", false)) else null,
		"visited": int(state.get("visited", 0)),
		"truncated": bool(state.get("truncated", false)),
		"nodes": matches,
	})


func _collect(root: Node, node: Node, type: String, pattern: String, group: String, acc: Array, offset: int, limit: int, max_nodes: int, state: Dictionary) -> void:
	if bool(state.get("has_more", false)) or bool(state.get("truncated", false)):
		return
	if max_nodes > 0 and int(state.get("visited", 0)) >= max_nodes:
		state["truncated"] = true
		return
	state["visited"] = int(state.get("visited", 0)) + 1
	var ok := true
	if type != "" and not node.is_class(type):
		ok = false
	if ok and pattern != "" and not String(node.name).matchn(pattern):
		ok = false
	if ok and group != "" and not node.is_in_group(group):
		ok = false
	if ok:
		var matched := int(state.get("matched", 0))
		state["matched"] = matched + 1
		if matched < offset:
			pass
		elif acc.size() < limit:
			acc.append({
				"path": "." if node == root else String(root.get_path_to(node)),
				"type": node.get_class(),
				"name": String(node.name),
			})
		else:
			state["has_more"] = true
			return
	for c in node.get_children():
		if bool(state.get("has_more", false)) or bool(state.get("truncated", false)):
			break
		_collect(root, c, type, pattern, group, acc, offset, limit, max_nodes, state)


# ---------- testing / assertions ----------
func _record(entry: Dictionary) -> Dictionary:
	_test_log.append(entry)
	return entry


func _coerce_expected(v: Variant) -> Variant:
	if v is String:
		var p: Variant = str_to_var(v)
		if p != null:
			return p
	return v


func _eq_v(a: Variant, b: Variant) -> bool:
	return var_to_str(a) == var_to_str(b)


func _compare(actual: Variant, expected: Variant, op: String) -> bool:
	match op:
		"ne":
			return not _eq_v(actual, expected)
		"gt", "lt", "ge", "le", "near":
			if not ((actual is int or actual is float) and (expected is int or expected is float)):
				return false
			var a := float(actual)
			var b := float(expected)
			if op == "gt":
				return a > b
			if op == "lt":
				return a < b
			if op == "ge":
				return a >= b
			if op == "le":
				return a <= b
			return absf(a - b) <= 0.001
		"contains":
			if actual is Array:
				return (actual as Array).has(expected)
			return str(actual).contains(str(expected))
		_:
			return _eq_v(actual, expected)


func _assert_property(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	var node := _resolve(path)
	var prop := str(params.get("property", ""))
	var op := str(params.get("op", "eq"))
	var expected: Variant = _coerce_expected(params.get("expected"))
	if node == null:
		return _ok(_record({"assert": "property", "path": path, "pass": false, "reason": "node not found"}))
	var actual: Variant = node.get(prop)
	return _ok(_record({
		"assert": "property", "path": _rel(node), "property": prop, "op": op,
		"expected": Serialize.to_json(expected), "actual": Serialize.to_json(actual),
		"pass": _compare(actual, expected, op),
	}))


func _assert_node_exists(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	return _ok(_record({"assert": "node_exists", "path": path, "pass": _resolve(path) != null}))


func _assert_screen_text(params: Dictionary) -> Dictionary:
	var text := str(params.get("text", ""))
	var root := _scene_root()
	var found_at := ""
	if root != null and text != "":
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			var t: Variant = n.get("text")
			if t is String and (t as String).contains(text):
				found_at = _rel(n)
				break
			stack.append_array(n.get_children())
	return _ok(_record({"assert": "screen_text", "text": text, "pass": found_at != "", "found_at": found_at}))


func _wait_for_node(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	var timeout := float(params.get("timeout", 5.0))
	var elapsed := 0.0
	while elapsed < timeout:
		if _resolve(path) != null:
			return _ok({"found": true, "path": path, "elapsed": elapsed})
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return _ok({"found": false, "path": path, "elapsed": elapsed})


func _monitor_property(params: Dictionary) -> Dictionary:
	var node := _resolve(str(params.get("path", "")))
	if node == null:
		return _fail("Node not found")
	var prop := str(params.get("property", ""))
	var samples := maxi(1, int(params.get("samples", 10)))
	var interval := float(params.get("duration", 1.0)) / float(samples)
	var series: Array = []
	for i in range(samples):
		series.append(Serialize.to_json(node.get(prop)))
		await get_tree().create_timer(interval).timeout
	return _ok({"path": _rel(node), "property": prop, "samples": series.size(), "series": series})


func _record_frames(params: Dictionary) -> Dictionary:
	var count := maxi(1, int(params.get("count", 3)))
	var interval := float(params.get("interval", 0.2))
	var dir := str(params.get("save_dir", "user://mcp_x/frames"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var paths: Array = []
	for i in range(count):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var p := "%s/frame_%03d.png" % [dir, i]
			img.save_png(p)
			paths.append(ProjectSettings.globalize_path(p))
		if i < count - 1:
			await get_tree().create_timer(interval).timeout
	return _ok({"count": paths.size(), "frames": paths})


func _run_test_scenario(params: Dictionary) -> Dictionary:
	var scenario := str(params.get("name", "scenario"))
	var steps: Array = params.get("steps", []) if params.get("steps") is Array else []
	var results: Array = []
	var passed := 0
	var failed := 0
	for step in steps:
		if not (step is Dictionary):
			continue
		match str(step.get("type", "")):
			"key":
				await _simulate_key(step)
				results.append({"step": "key", "key": step.get("key", "")})
			"action":
				await _simulate_action(step)
				results.append({"step": "action", "action": step.get("action", "")})
			"wait":
				await get_tree().create_timer(float(step.get("seconds", 0.5))).timeout
				results.append({"step": "wait", "seconds": step.get("seconds", 0.5)})
			"wait_node":
				results.append((await _wait_for_node(step)).get("result", {}))
			"assert_property", "assert_node", "assert_text":
				var r: Dictionary = {}
				var st := str(step.get("type", ""))
				if st == "assert_property":
					r = (await _assert_property(step)).get("result", {})
				elif st == "assert_node":
					r = (await _assert_node_exists(step)).get("result", {})
				else:
					r = (await _assert_screen_text(step)).get("result", {})
				results.append(r)
				if r.get("pass", false):
					passed += 1
				else:
					failed += 1
			_:
				results.append({"step": "unknown", "type": step.get("type", "")})
	return _ok({"scenario": scenario, "passed": passed, "failed": failed, "total_asserts": passed + failed, "results": results})


func _get_test_report(params: Dictionary) -> Dictionary:
	var passed := 0
	var failed := 0
	for e in _test_log:
		if e.get("pass", false):
			passed += 1
		else:
			failed += 1
	var report: Dictionary = {"total": _test_log.size(), "passed": passed, "failed": failed, "log": _test_log.duplicate()}
	if bool(params.get("clear", false)):
		_test_log.clear()
	return _ok(report)
