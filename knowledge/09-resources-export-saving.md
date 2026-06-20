# Resources, @export vars & Saving (4.7)

## Resources vs Nodes

- **Node** = lives in the scene tree, has lifecycle (`_ready`, `_process`).
- **Resource** = shareable data (`.tres` text / `.res` binary): materials, meshes,
  curves, themes, your own data classes. Ref-counted; auto-freed. Multiple nodes
  can share one resource instance.

## Custom resources

```gdscript
# res://stats.gd
class_name Stats
extends Resource
@export var max_hp: int = 100
@export var speed: float = 5.0
@export var loot: Array[String] = []
```
Create/save/load:
```gdscript
var s := Stats.new(); s.max_hp = 200
ResourceSaver.save(s, "res://hero_stats.tres")
var loaded := load("res://hero_stats.tres") as Stats
```
godot-mcp-x: `create_resource {type, path, properties}`, `read_resource`,
`edit_resource`.

## @export annotations (inspector-exposed vars)

Common (all 4.x):
```gdscript
@export var title: String                       # plain
@export var target: Node3D                       # typed node picker (preferred over @export_node_path)
@export var scene: PackedScene
@export_range(0, 100, 1) var pct: int
@export_range(0.0, 1.0, 0.01) var ratio: float
@export_enum("Idle", "Run", "Jump") var state: String
@export_flags("Fire", "Water", "Earth") var elements: int
@export_multiline var description: String
@export_file("*.png") var icon_path: String
@export_dir var folder: String
@export_color_no_alpha var tint: Color
@export_exp_easing var curve: float
@export_flags_3d_physics var layers: int        # also 2d_physics / 3d_render / 3d_navigation
```
Inspector organization:
```gdscript
@export_group("Combat")        # groups following exports
@export_subgroup("Ranged")
@export_category("Debug")
```
Newer (4.4+):
```gdscript
@export_storage var _runtime_only            # saved but hidden from inspector
@export_tool_button("Bake") var bake_action  # clickable button → calls a Callable (in @tool scripts)
@export_custom(PROPERTY_HINT_NONE, "") var x # full manual control
```

## Scenes as resources

```gdscript
var ps: PackedScene = load("res://enemy.tscn")
var enemy := ps.instantiate()
# Build & save a scene from code (owner must be the root, see 03-editor-automation):
var packed := PackedScene.new(); packed.pack(root); ResourceSaver.save(packed, "res://x.tscn")
```

## Loading APIs

- `load(path)` — cached, blocking. `preload(path)` — at parse time (const).
- `ResourceLoader.load(path, type_hint, cache_mode)` — explicit control.
- `ResourceLoader.load_threaded_request(path)` + `load_threaded_get(path)` —
  background loading (avoid hitches loading big assets).
- `ResourceLoader.exists(path)` — check before loading.

## UIDs (`uid://…`)

Godot references resources by stable **UID** (in `.uid` sidecar files), so moving
a file doesn't break references. Convert:
`ResourceUID.text_to_id`, `ResourceUID.get_id_path`,
`ResourceLoader.get_resource_uid(path)`, `ResourceUID.id_to_text`.
godot-mcp-x: `uid_to_path`, `path_to_uid`. When deleting/moving a file by hand,
also handle its `.uid` (and `.import` for assets) sidecar — `delete_path` does this.

## Gotcha: resource sharing

Resources are shared by reference. To give each node its own copy, call
`resource.duplicate()` (or set `resource_local_to_scene = true`), otherwise edits
bleed across every user of that resource.
