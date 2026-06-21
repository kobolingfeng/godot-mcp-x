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

A `Theme` holds items keyed by `(item_name, control_class)` in five buckets:
**stylebox, color, font, font_size, constant** (icons too). Set `Control.theme` on a
subtree, or **`get_tree().root.theme`** to skin the WHOLE app from one place (basis of
a unified design system). godot-mcp-x: `create_theme`, `set_theme_*`, `apply_theme`.

**Build a theme in code (idiomatic — Godot's own editor themes do exactly this).** Keep
design tokens (colors / spacing / radius / font sizes) as constants, then build items
from them. Pro idiom: make ONE base `StyleBoxFlat` and `.duplicate()` it per state,
tweaking only what differs:
```gdscript
var base := StyleBoxFlat.new()
base.bg_color = SURFACE; base.set_corner_radius_all(10); base.set_content_margin_all(12)
var hover := base.duplicate(); hover.bg_color = SURFACE_HOVER
theme.set_stylebox("normal", "Button", base)
theme.set_stylebox("hover",  "Button", hover)
```
**Cover every state** or a control looks half-styled. Exact item names per control
(enumerate, don't guess: `ThemeDB.get_default_theme().get_stylebox_list("Button")`):
- **Button** sb `normal/hover/pressed/disabled/focus`; col `font_color` + `font_{hover,pressed,focus,hover_pressed,disabled}_color`.
- **CheckButton** sb `normal/hover/hover_pressed/pressed/disabled/focus`; the on/off switch is an **icon** (`checked`/`unchecked`), not a stylebox.
- **OptionButton** = Button styleboxes + icon `arrow`; its dropdown is a separate **PopupMenu** (style `panel`,`hover` + its own `font_color`/`font_hover_color`).
- **HSlider** sb `slider` (track) / `grabber_area` (fill) / `grabber_area_highlight`; the knob is an **icon** (`grabber`/`grabber_highlight`).
- **TabContainer** sb `tab_selected/tab_hovered/tab_unselected/tab_disabled/tab_focus/panel/tabbar_background`; col `font_{selected,hovered,unselected}_color`.
- **LineEdit** sb `normal/focus/read_only`; col `font_color/font_placeholder_color/caret_color/selection_color`.
- **PanelContainer**/**Panel** sb `panel`. Default `default_font_size` = 16.

**Type variations** — reusable named styles (a "Title" Label, a "Danger" Button):
```gdscript
theme.set_type_variation("Title", "Label")   # set_type_variation, NOT set_type_variation_base
theme.set_font_size("font_size", "Title", 30)
label.theme_type_variation = "Title"          # now resolves to 30
```
The setter is **`set_type_variation(variation, base)`** but the getter is
**`get_type_variation_base(variation)`** — and **`set_type_variation_base` does not
exist**. WITHOUT registering via `set_type_variation`, `theme_type_variation` silently
falls back to the control class (your custom size/colour is ignored). For one-off
sizing, per-node `add_theme_font_size_override(...)` also works.

**Polish idioms:** subtle `StyleBoxFlat.shadow_color/shadow_size/shadow_offset` for
depth; an opacity ramp for text hierarchy (high 1.0 / medium ~0.7 / low ~0.45); a tonal
surface ramp derived from one base colour; rounded corners + 1px borders for a modern,
lightweight look. **Editor vs code:** the visual Theme editor gives live preview (best
for hand-tuning a `.tres`); code/tokens win for dynamic or design-system themes. See
[03-editor-automation.md](03-editor-automation.md) for the inspector-vs-code rule.

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
- Theme type variations register with `set_type_variation(variation, base)` (getter is
  `get_type_variation_base`); **there is no `set_type_variation_base`** — calling it
  throws and aborts the whole `build_theme()`, leaving the UI unstyled. Verify a
  code-built theme actually applied with `get_tree().root.theme != null`.
