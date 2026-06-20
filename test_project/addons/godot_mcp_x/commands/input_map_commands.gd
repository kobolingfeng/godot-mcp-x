@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## Input actions are written to ProjectSettings ("input/<name>") so they PERSIST
## to project.godot — InputMap.add_action() alone is runtime-only and lost on
## reload.


func get_commands() -> Dictionary:
	return {
		"list_input_actions": _list,
		"add_input_action": _add,
		"remove_input_action": _remove,
		"add_input_event": _add_event,
	}


func _list(_params: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for prop in ProjectSettings.get_property_list():
		var n: String = prop.get("name", "")
		if not n.begins_with("input/"):
			continue
		var cfg: Variant = ProjectSettings.get_setting(n)
		var events: Array = []
		if cfg is Dictionary and cfg.has("events"):
			for ev in cfg["events"]:
				events.append(_event_desc(ev))
		out[n.substr(6)] = {
			"deadzone": cfg.get("deadzone", 0.5) if cfg is Dictionary else 0.5,
			"events": events,
		}
	return success({"actions": out, "count": out.size()})


func _event_desc(ev: Variant) -> String:
	if ev is InputEventKey:
		var k: InputEventKey = ev
		return "Key:" + OS.get_keycode_string(k.physical_keycode if k.physical_keycode != 0 else k.keycode)
	if ev is InputEventMouseButton:
		return "Mouse:%d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		return "Joy:%d" % (ev as InputEventJoypadButton).button_index
	return (ev as Object).get_class() if ev is Object else str(ev)


func _add(params: Dictionary) -> Dictionary:
	var name := req_str(params, "name")
	if name == "":
		return fail("'name' is required")
	var key := "input/" + name
	if ProjectSettings.has_setting(key):
		return fail("Action already exists: %s" % name)
	var deadzone := float(params.get("deadzone", 0.5))
	ProjectSettings.set_setting(key, {"deadzone": deadzone, "events": []})
	var err := ProjectSettings.save()
	if err != OK:
		return fail("Save failed (error %d)" % err)
	return success({"added": name, "deadzone": deadzone})


func _remove(params: Dictionary) -> Dictionary:
	var name := req_str(params, "name")
	var key := "input/" + name
	if not ProjectSettings.has_setting(key):
		return fail("Action not found: %s" % name)
	ProjectSettings.set_setting(key, null)
	var err := ProjectSettings.save()
	if err != OK:
		return fail("Save failed (error %d)" % err)
	return success({"removed": name})


func _add_event(params: Dictionary) -> Dictionary:
	var name := req_str(params, "name")
	var key := "input/" + name
	if not ProjectSettings.has_setting(key):
		return fail("Action not found: %s (add it first)" % name)
	var keystr := req_str(params, "key")
	if keystr == "":
		return fail("'key' is required (e.g. 'W', 'Space', 'Escape')")
	var keycode := OS.find_keycode_from_string(keystr)
	if keycode == 0:
		return fail("Unknown key: %s" % keystr)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	var cfg: Dictionary = ProjectSettings.get_setting(key)
	var events: Array = cfg.get("events", [])
	events.append(ev)
	cfg["events"] = events
	ProjectSettings.set_setting(key, cfg)
	var err := ProjectSettings.save()
	if err != OK:
		return fail("Save failed (error %d)" % err)
	return success({"action": name, "added_key": OS.get_keycode_string(keycode)})
