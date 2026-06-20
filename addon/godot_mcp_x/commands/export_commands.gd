@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## Read-only export-preset inspection. Actually running an export is a headless
## CLI step (godot --export-release "<preset>" <out>), not an editor API call.

const PRESETS_PATH := "res://export_presets.cfg"


func get_commands() -> Dictionary:
	return {
		"list_export_presets": _list,
		"get_export_info": _info,
	}


func _list(_params: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(PRESETS_PATH):
		return success({"presets": [], "note": "No export_presets.cfg — add an export preset in the editor first"})
	var cfg := ConfigFile.new()
	if cfg.load(PRESETS_PATH) != OK:
		return fail("Failed to read export_presets.cfg")
	var presets: Array = []
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			presets.append({
				"name": cfg.get_value(section, "name", ""),
				"platform": cfg.get_value(section, "platform", ""),
				"runnable": cfg.get_value(section, "runnable", false),
			})
	return success({"presets": presets, "count": presets.size()})


func _info(params: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(PRESETS_PATH):
		return fail("No export_presets.cfg")
	var cfg := ConfigFile.new()
	cfg.load(PRESETS_PATH)
	var want := req_str(params, "preset")
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			if want == "" or cfg.get_value(section, "name", "") == want:
				var info: Dictionary = {}
				for k in cfg.get_section_keys(section):
					info[k] = cfg.get_value(section, k)
				return success({"preset": cfg.get_value(section, "name", ""), "info": info})
	return fail("Preset not found: %s" % want)
