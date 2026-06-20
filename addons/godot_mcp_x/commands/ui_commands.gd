@tool
extends "res://addons/godot_mcp_x/core/base_command.gd"

## UI / Control helpers, incl. the 4.7 VirtualJoystick.

const LAYOUT_PRESETS := {
	"top_left": Control.PRESET_TOP_LEFT,
	"top_right": Control.PRESET_TOP_RIGHT,
	"bottom_left": Control.PRESET_BOTTOM_LEFT,
	"bottom_right": Control.PRESET_BOTTOM_RIGHT,
	"center_left": Control.PRESET_CENTER_LEFT,
	"center_top": Control.PRESET_CENTER_TOP,
	"center_right": Control.PRESET_CENTER_RIGHT,
	"center_bottom": Control.PRESET_CENTER_BOTTOM,
	"center": Control.PRESET_CENTER,
	"left_wide": Control.PRESET_LEFT_WIDE,
	"top_wide": Control.PRESET_TOP_WIDE,
	"right_wide": Control.PRESET_RIGHT_WIDE,
	"bottom_wide": Control.PRESET_BOTTOM_WIDE,
	"vcenter_wide": Control.PRESET_VCENTER_WIDE,
	"hcenter_wide": Control.PRESET_HCENTER_WIDE,
	"full_rect": Control.PRESET_FULL_RECT,
}
const JOYSTICK_MODES := {"fixed": 0, "dynamic": 1, "following": 2}


func get_commands() -> Dictionary:
	return {
		"add_virtual_joystick": _add_virtual_joystick,
		"set_anchor_preset": _set_anchor_preset,
	}


func _add_virtual_joystick(params: Dictionary) -> Dictionary:
	var parent := resolve_node(opt_str(params, "parent_path", "."))
	if parent == null:
		return fail("Parent not found")
	var vj := VirtualJoystick.new()
	vj.name = opt_str(params, "name", "VirtualJoystick")
	var mode := opt_str(params, "mode", "fixed")
	if JOYSTICK_MODES.has(mode):
		vj.set("joystick_mode", JOYSTICK_MODES[mode])
	var actions := opt_dict(params, "actions")
	for dir in ["left", "right", "up", "down"]:
		if actions.has(dir):
			vj.set("action_" + dir, str(actions[dir]))
	add_node_undoable(parent, vj, "Add VirtualJoystick")
	# Touch sticks usually live in a screen corner — default to bottom-left.
	vj.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	return success({"path": rel_path(vj), "mode": mode})


func _set_anchor_preset(params: Dictionary) -> Dictionary:
	var node := resolve_node(req_str(params, "path"))
	if node == null or not (node is Control):
		return fail("Control node not found: %s" % req_str(params, "path"))
	var preset := opt_str(params, "preset", "full_rect")
	if not LAYOUT_PRESETS.has(preset):
		return fail("Unknown preset '%s' (e.g. full_rect, center, bottom_left, top_wide)" % preset, -32000, {"suggestions": suggest(preset, LAYOUT_PRESETS.keys())})
	var c := node as Control
	if opt_bool(params, "keep_offsets", false):
		c.set_anchors_preset(LAYOUT_PRESETS[preset])
	else:
		c.set_anchors_and_offsets_preset(LAYOUT_PRESETS[preset])
	mark_unsaved()
	return success({"path": rel_path(node), "preset": preset})
