# UI & Control (Godot 4.7)

The Control/UI system: layout, containers, theming, and the 4.7 additions.

## Anchors & offsets (the core layout model)

Every `Control` is positioned by 4 **anchors** (0–1 fractions of the parent rect)
plus 4 **offsets** (pixels from those anchors). You rarely set them by hand — use
a **preset**:

- `set_anchors_and_offsets_preset(preset)` — anchors **and** snaps offsets (this is
  what "Layout → Full Rect / Center" in the editor does).
- `set_anchors_preset(preset)` — anchors only (keep current offsets).

`LayoutPreset` values ✅: `PRESET_TOP_LEFT`(0) `TOP_RIGHT`(1) `BOTTOM_LEFT`(2)
`BOTTOM_RIGHT`(3) `CENTER_LEFT`(4) `CENTER_TOP`(5) `CENTER_RIGHT`(6)
`CENTER_BOTTOM`(7) `CENTER`(8) `LEFT_WIDE`(9) `TOP_WIDE`(10) `RIGHT_WIDE`(11)
`BOTTOM_WIDE`(12) `VCENTER_WIDE`(13) `HCENTER_WIDE`(14) `FULL_RECT`(15).

godot-mcp-x: `set_anchor_preset {path, preset:"full_rect"|"center"|…}`.

```gdscript
$Panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # fill parent
$Label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)      # center
```

## Containers (let layout be automatic)

Children of a `Container` are auto-positioned; **don't** set their anchors/offsets
(the container overrides them) — use **size flags** instead.

- `VBoxContainer` / `HBoxContainer` — stack vertically / horizontally
- `GridContainer` (`columns`) — grid
- `MarginContainer` — padding (theme constants `margin_*`)
- `CenterContainer` — center one child
- `PanelContainer` — bg panel that hugs its child
- `ScrollContainer` — scrollable viewport
- `TabContainer`, `SplitContainer`, `FlowContainer`, `AspectRatioContainer`

Per-child layout via **size flags**:
```gdscript
button.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # take extra space
button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
button.custom_minimum_size = Vector2(120, 40)
# 4.7: Control.custom_maximum_size caps the size too
```

## Common Control nodes

`Label`, `RichTextLabel` (BBCode), `Button`/`TextureButton`/`CheckBox`/
`OptionButton`, `LineEdit`/`TextEdit`/`CodeEdit`, `ProgressBar`/`Slider`,
`TextureRect`, `NinePatchRect`, `ColorRect`, `Panel`, `Tree`, `ItemList`,
`TabBar`, `Popup`/`PopupMenu`/`AcceptDialog`/`FileDialog`.

## Theming

A `Theme` resource holds colors/constants/fonts/styleboxes keyed by
`(item_name, control_class)`. Set `Control.theme` to apply to a subtree, or
per-node overrides via `add_theme_color_override(...)` etc. godot-mcp-x theme
tools: `create_theme`, `set_theme_color/constant/font_size/stylebox`,
`apply_theme`. See [03-editor-automation.md](03-editor-automation.md) for the
inspector-vs-code rule.

## Touch input — VirtualJoystick (4.7 ✅)

`VirtualJoystick` (a `Control`) gives mobile a thumbstick. Its
`action_left/right/up/down` map to **input-map actions**, so the same
`Input.get_vector(...)` movement code works on desktop and touch.

```gdscript
# (or godot-mcp-x: add_virtual_joystick {mode, actions:{left,right,up,down}})
var vj := VirtualJoystick.new()
vj.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC   # FIXED / DYNAMIC / FOLLOWING
vj.action_left = "move_left"; vj.action_right = "move_right"
vj.action_up = "move_up"; vj.action_down = "move_down"
vj.visibility_mode = VirtualJoystick.VISIBILITY_WHEN_TOUCHED
$HUD.add_child(vj)
```

## 4.7 GUI changes (see [11-godot-4.7-deep-dive.md](11-godot-4.7-deep-dive.md))

Control **visual transform offsets** (translate/rotate/scale without disturbing
container layout), `custom_maximum_size`, `PopupMenu` search, `Tree` drag-drop
indicators, `RichTextLabel` `em`-unit images + better tables + triple-click
selection, conic `GradientTexture2D`.

## Gotchas

- Inside a Container, setting anchors/offsets does nothing — use size flags +
  `custom_minimum_size`.
- A root UI scene is usually a `Control` set to `PRESET_FULL_RECT`, or a
  `CanvasLayer` for HUDs that float over the game.
- `mouse_filter` (`STOP`/`PASS`/`IGNORE`) controls whether a Control eats input —
  a full-rect Control with default `STOP` silently blocks clicks beneath it.
