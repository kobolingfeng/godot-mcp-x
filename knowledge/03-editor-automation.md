# Editor Automation Recipes (4.7)

How to manipulate the editor and the edited scene from `@tool`/editor scripts.
Every `EditorInterface` method below is **✅ verified present on 4.7**.

## EditorInterface — the entry points you actually need

```gdscript
EditorInterface.get_edited_scene_root() -> Node     # root of the scene in the tab
EditorInterface.open_scene_from_path(path)          # open/switch scene
EditorInterface.reload_scene_from_path(path)
EditorInterface.save_scene() -> Error               # ⚠ returns Error (int)
EditorInterface.save_scene_as(path, with_preview=true) -> void   # ⚠ returns VOID
EditorInterface.mark_scene_as_unsaved()
EditorInterface.get_resource_filesystem() -> EditorFileSystem
EditorInterface.get_script_editor() -> ScriptEditor
EditorInterface.get_base_control() -> Control       # root of the editor UI
EditorInterface.get_selection() -> EditorSelection
EditorInterface.get_editor_paths() -> EditorPaths
EditorInterface.get_editor_main_screen() -> VBoxContainer
```

## Scene-relative node paths (the #1 efficiency rule)

`Node.get_path()` from anything under the editor returns the **full editor tree**
path (`/root/@EditorNode@…/SubViewport/<scene>/…`) — huge and useless. Instead
always anchor at the edited scene root:

```gdscript
var root := EditorInterface.get_edited_scene_root()
var rel := root.get_path_to(some_node)   # -> "Player/Camera3D"  (clean!)
var node := root.get_node_or_null("Player/Camera3D")
# Convention: "." / "" → the root itself.
```

## Adding nodes that actually SAVE

A node is only written to the `.tscn` if its `owner` is the scene root:

```gdscript
var n := ClassDB.instantiate("Sprite2D")
n.name = "Icon"
parent.add_child(n)
n.owner = EditorInterface.get_edited_scene_root()   # ← REQUIRED or it won't save
```
After `reparent()` / `duplicate()`, re-assign `owner` for the **whole subtree**:

```gdscript
func set_owner_recursive(node: Node, owner: Node) -> void:
    for c in node.get_children():
        c.owner = owner
        set_owner_recursive(c, owner)
```

## Saving a scene robustly (version-proof)

`save_scene_as` returns void (can't check error). To save the live edited root
with an error code regardless of editor state, pack it yourself:

```gdscript
var root := EditorInterface.get_edited_scene_root()
var packed := PackedScene.new()
var err := packed.pack(root)               # captures children whose owner == root
if err == OK:
    err = ResourceSaver.save(packed, root.scene_file_path)
```
Creating a brand-new scene file:

```gdscript
var r := ClassDB.instantiate("Node3D"); r.name = "World"
var ps := PackedScene.new(); ps.pack(r)
ResourceSaver.save(ps, "res://world.tscn")
r.free()
EditorInterface.get_resource_filesystem().update_file("res://world.tscn")
EditorInterface.open_scene_from_path("res://world.tscn")
```

## Refresh the filesystem after writing files

After writing a `.gd`/`.tscn` directly with `FileAccess`, tell the editor:

```gdscript
EditorInterface.get_resource_filesystem().update_file(path)  # single file
EditorInterface.get_resource_filesystem().scan()             # full rescan
```

## ClassDB introspection (live API ground-truth)

```gdscript
ClassDB.class_exists("AreaLight3D")                       # bool
ClassDB.get_class_list()                                  # all 1549 names
ClassDB.is_parent_class("CharacterBody3D", "Node")       # bool
ClassDB.get_parent_class("AreaLight3D")                  # "Light3D"
ClassDB.can_instantiate("Node3D")                        # bool
ClassDB.class_get_property_list("AreaLight3D", true)      # true = own members only
ClassDB.class_get_method_list("Node", true)
ClassDB.class_get_signal_list("Button", true)
ClassDB.class_get_enum_list("Light3D", true)
ClassDB.class_get_enum_constants("Light3D", "BakeMode", true)
ClassDB.class_get_integer_constant_list("Node", true)
type_string(TYPE_VECTOR3)                                 # "Vector3"
```
Pass `true` (no_inheritance) to keep output focused on the class's *own* members
— big token saver. Need inherited members too? Describe the parent as well.

## ResourceUID (uid:// <-> res://)

```gdscript
var id := ResourceUID.text_to_id("uid://abc")   # -1 if malformed
ResourceUID.has_id(id)
ResourceUID.get_id_path(id)                      # -> "res://..."
ResourceLoader.get_resource_uid("res://x.tscn")  # path -> id (-1 if none)
ResourceUID.id_to_text(id)                       # -> "uid://..."
```

## Screenshot the editor viewport (return a file, not base64)

```gdscript
var vp := EditorInterface.get_base_control().get_viewport()
await RenderingServer.frame_post_draw
var img := vp.get_texture().get_image()
img.save_png("user://shot.png")
var os_path := ProjectSettings.globalize_path("user://shot.png")  # absolute → readable by host tools
```

## Reading editor errors / output

No public API returns the Output panel text — walk the UI:
`EditorInterface.get_base_control().find_child("Output", true, false)`, then find
the descendant `RichTextLabel` and read `get_parsed_text()`. Script compile
errors show as red line backgrounds in the `CodeEdit`
(`get_line_background_color(i).r > 0.8`). Fallback: read `user://logs/godot.log`.
