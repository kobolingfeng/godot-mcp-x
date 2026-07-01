@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

const SNIPPET_CACHE_MAX := 128

var _snippet_cache: Dictionary = {}
var _snippet_cache_order: Array = []


func get_commands() -> Dictionary:
	return {
		"execute_editor_script": _execute_editor_script,
		"get_editor_errors": _get_editor_errors,
		"get_output_log": _get_output_log,
		"clear_output": _clear_output,
		"get_editor_screenshot": _get_editor_screenshot,
		"reload_scripts": _reload_scripts,
		"reload_mcp_commands": _reload_mcp_commands,
		"list_classes": _list_classes,
		"describe_class": _describe_class,
		"undo": _undo,
		"redo": _redo,
		"get_status": _get_status,
	}


func _get_status(_params: Dictionary) -> Dictionary:
	var ws := editor_plugin.get_node_or_null("McpXWsClient")
	var router := editor_plugin.get_node_or_null("McpXRouter")
	var ports: Array = []
	if ws and ws.has_method("get_connected_ports"):
		ports = ws.get_connected_ports()
	var cmds := 0
	if router and router.has_method("methods"):
		cmds = router.methods().size()
	return success({
		"version": "0.1.0",
		"connected_ports": ports,
		"commands": cmds,
		"playing": EditorInterface.is_playing_scene(),
	})


# ---------------------------------------------------------------------------
# execute_editor_script — wrap user code in run() with an _mcp_print() capture.
# ---------------------------------------------------------------------------
func _execute_editor_script(params: Dictionary) -> Dictionary:
	var code := opt_str(params, "code", "")
	if code.strip_edges() == "":
		return fail("'code' is required")

	var indented := ""
	for line in code.split("\n"):
		indented += "\t" + line + "\n"
	var src := (
		"@tool\nextends RefCounted\n"
		+ "var _mcp_output: Array = []\n"
		+ "func _mcp_print(v: Variant) -> void:\n\t_mcp_output.append(str(v))\n"
		+ "func run() -> Variant:\n"
		+ indented
		+ "\treturn null\n"
	)

	var compiled := _compile_snippet(src)
	if int(compiled.get("error", OK)) != OK:
		var rerr := int(compiled.get("error", ERR_PARSE_ERROR))
		return fail("Script failed to compile (error %d)" % rerr, -32000, {"source": src})
	var gd: GDScript = compiled.get("script") as GDScript

	var inst: Object = gd.new()
	var ret: Variant = inst.call("run")
	while ret is Object and (ret as Object).get_class() == "GDScriptFunctionState":
		ret = await (ret as Object).completed

	var output: Array = inst.get("_mcp_output")
	return success({"output": output, "return_value": null if ret == null else str(ret)})


func _compile_snippet(src: String) -> Dictionary:
	var key := "%d:%d" % [src.length(), src.hash()]
	var cached: Variant = _snippet_cache.get(key)
	if cached is GDScript:
		return {"script": cached, "error": OK}
	var gd := GDScript.new()
	gd.source_code = src
	var err := gd.reload()
	if err != OK:
		return {"script": null, "error": err}
	_snippet_cache[key] = gd
	_snippet_cache_order.append(key)
	while _snippet_cache_order.size() > SNIPPET_CACHE_MAX:
		_snippet_cache.erase(_snippet_cache_order.pop_front())
	return {"script": gd, "error": OK}


# ---------------------------------------------------------------------------
# Errors / logs — read the editor Output panel, with a log-file fallback.
# ---------------------------------------------------------------------------
func _get_editor_errors(params: Dictionary) -> Dictionary:
	var max_lines := opt_int(params, "max_lines", 80)
	var errors: Array = []
	var base := EditorInterface.get_base_control()

	# 1. Output panel (runtime errors, warnings, prints)
	var editor_log: Node = base.find_child("Output", true, false)
	if editor_log:
		var rtl := _find_rtl(editor_log)
		if rtl:
			var lines := rtl.get_parsed_text().split("\n")
			var start := maxi(0, lines.size() - max_lines)
			for i in range(start, lines.size()):
				var ln: String = lines[i]
				if ln.contains("ERROR") or ln.contains("SCRIPT ERROR") or ln.contains("Parse Error") or ln.contains("WARNING"):
					errors.append(ln.strip_edges())

	# 2. Script editor compile errors (red-background lines)
	var se := EditorInterface.get_script_editor()
	if se:
		var cur := se.get_current_script()
		var ce := _find_code_edit(se)
		if ce and cur:
			for i in range(ce.get_line_count()):
				var bg: Color = ce.get_line_background_color(i)
				if bg.r > 0.8 and bg.a > 0.0:
					errors.append("COMPILE ERROR: %s:%d - %s" % [cur.resource_path, i + 1, ce.get_line(i).strip_edges()])

	# 3. Log-file fallback
	if errors.is_empty() and FileAccess.file_exists("user://logs/godot.log"):
		var f := FileAccess.open("user://logs/godot.log", FileAccess.READ)
		if f:
			var lines: Array = []
			while not f.eof_reached():
				if lines.size() >= max_lines:
					lines.pop_front()
				lines.append(f.get_line())
			f.close()
			for i in range(lines.size()):
				if lines[i].contains("ERROR"):
					errors.append(lines[i].strip_edges())

	return success({"errors": errors, "count": errors.size()})


func _get_output_log(params: Dictionary) -> Dictionary:
	var max_lines := opt_int(params, "max_lines", 100)
	var filter := opt_str(params, "filter", "")
	var base := EditorInterface.get_base_control()
	var editor_log: Node = base.find_child("Output", true, false)
	var rtl := _find_rtl(editor_log) if editor_log else null
	if rtl == null:
		return fail("Output panel not accessible")
	var all_lines := rtl.get_parsed_text().split("\n")
	var start := maxi(0, all_lines.size() - max_lines)
	var out: Array = []
	for i in range(start, all_lines.size()):
		if filter == "" or all_lines[i].contains(filter):
			out.append(all_lines[i])
	return success({"lines": out, "count": out.size()})


func _clear_output(_params: Dictionary) -> Dictionary:
	var base := EditorInterface.get_base_control()
	var editor_log: Node = base.find_child("Output", true, false)
	var rtl := _find_rtl(editor_log) if editor_log else null
	if rtl:
		rtl.clear()
	return success({"cleared": true})


func _get_editor_screenshot(params: Dictionary) -> Dictionary:
	var save_path := opt_str(params, "save_path", "")
	if save_path == "":
		save_path = "user://mcp_x/editor_screenshot.png"
	var os_path := globalize(save_path)
	DirAccess.make_dir_recursive_absolute(os_path.get_base_dir())

	var vp := EditorInterface.get_base_control().get_viewport()
	# Use an idle frame, not RenderingServer.frame_post_draw: the render signal can
	# stall when the editor window is unfocused (Godot throttles drawing), hanging
	# the capture. Idle frames always fire.
	await editor_plugin.get_tree().process_frame
	var img := vp.get_texture().get_image()
	if img == null:
		return fail("Failed to capture editor viewport")
	var err := img.save_png(save_path)
	if err != OK:
		return fail("save_png failed (error %d)" % err)
	return success({"saved": save_path, "os_path": os_path, "width": img.get_width(), "height": img.get_height()})


func _reload_scripts(_params: Dictionary) -> Dictionary:
	EditorInterface.get_resource_filesystem().scan()
	return success({"reloaded": true})


func _reload_mcp_commands(_params: Dictionary) -> Dictionary:
	EditorInterface.get_resource_filesystem().scan()
	var router := editor_plugin.get_node_or_null("McpXRouter")
	if router == null or not router.has_method("reload_commands"):
		return fail("McpXRouter is not available")
	var result: Dictionary = router.reload_commands()
	return success(result)


# ---------------------------------------------------------------------------
# ClassDB introspection — live 4.7 API ground-truth.
# ---------------------------------------------------------------------------
func _list_classes(params: Dictionary) -> Dictionary:
	var filter := opt_str(params, "filter", "")
	var inherits := opt_str(params, "inherits", "")
	var matched: Array = []
	for c in ClassDB.get_class_list():
		var cs := String(c)
		if filter != "" and not cs.matchn("*" + filter + "*"):
			continue
		if inherits != "" and not ClassDB.is_parent_class(cs, inherits):
			continue
		matched.append(cs)
	matched.sort()
	var total := matched.size()
	var offset := opt_int(params, "offset", 0)
	var limit := opt_int(params, "limit", 200)
	return success({
		"total": total,
		"offset": offset,
		"limit": limit,
		"has_more": offset + limit < total,
		"classes": matched.slice(offset, offset + limit),
	})


func _describe_class(params: Dictionary) -> Dictionary:
	var cls := req_str(params, "name")
	if not ClassDB.class_exists(cls):
		return fail("Unknown class: %s" % cls)
	var members := opt_array(params, "members")
	var want := func(k: String) -> bool: return members.is_empty() or members.has(k)

	var out: Dictionary = {
		"name": cls,
		"parent": ClassDB.get_parent_class(cls),
		"can_instantiate": ClassDB.can_instantiate(cls),
	}
	if want.call("properties"):
		var props: Array = []
		for p in ClassDB.class_get_property_list(cls, true):
			props.append({"name": p.get("name", ""), "type": type_string(p.get("type", 0))})
		out["properties"] = props
	if want.call("methods"):
		var ms: Array = []
		for m in ClassDB.class_get_method_list(cls, true):
			ms.append(_method_signature(m))
		out["methods"] = ms
	if want.call("signals"):
		var ss: Array = []
		for s in ClassDB.class_get_signal_list(cls, true):
			ss.append(s.get("name", ""))
		out["signals"] = ss
	if want.call("enums"):
		var es: Dictionary = {}
		for e in ClassDB.class_get_enum_list(cls, true):
			var consts: Array = []
			for cn in ClassDB.class_get_enum_constants(cls, e, true):
				consts.append(String(cn))
			es[String(e)] = consts
		out["enums"] = es
	if want.call("constants"):
		var cs2: Array = []
		for c in ClassDB.class_get_integer_constant_list(cls, true):
			cs2.append(String(c))
		out["constants"] = cs2
	return success(out)


func _undo(_params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return fail("No scene is currently open")
	var urm := editor_plugin.get_undo_redo()
	var ur := urm.get_history_undo_redo(urm.get_object_history_id(root))
	if ur == null or not ur.has_undo():
		return success({"undone": false, "reason": "nothing to undo"})
	var action := ur.get_current_action_name()
	ur.undo()
	await editor_plugin.get_tree().create_timer(0.1).timeout  # let the editor fully settle before the next read
	return success({"undone": true, "action": action})


func _redo(_params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return fail("No scene is currently open")
	var urm := editor_plugin.get_undo_redo()
	var ur := urm.get_history_undo_redo(urm.get_object_history_id(root))
	if ur == null or not ur.has_redo():
		return success({"redone": false, "reason": "nothing to redo"})
	ur.redo()
	await editor_plugin.get_tree().create_timer(0.1).timeout  # let the editor fully settle before the next read
	return success({"redone": true, "action": ur.get_current_action_name()})


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _method_signature(m: Dictionary) -> String:
	var parts: Array = []
	for a in m.get("args", []):
		parts.append("%s: %s" % [a.get("name", ""), _type_name(a, false)])
	return "%s(%s) -> %s" % [m.get("name", ""), ", ".join(parts), _type_name(m.get("return", {}), true)]


func _type_name(info: Dictionary, is_return: bool) -> String:
	var cn: String = info.get("class_name", "")
	if cn != "":
		return cn
	var t: int = info.get("type", 0)
	if t == 0:
		return "void" if is_return else "Variant"
	return type_string(t)


func _find_rtl(node: Node, depth: int = 0) -> RichTextLabel:
	if node == null or depth > 8:
		return null
	if node is RichTextLabel:
		return node as RichTextLabel
	for child in node.get_children():
		var found := _find_rtl(child, depth + 1)
		if found:
			return found
	return null


func _find_code_edit(node: Node, depth: int = 0) -> CodeEdit:
	if node == null or depth > 8:
		return null
	if node is CodeEdit:
		return node as CodeEdit
	for child in node.get_children():
		var found := _find_code_edit(child, depth + 1)
		if found:
			return found
	return null
