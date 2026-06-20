# 4.7 API Gotchas (each one was a real bug)

Concrete surprises found while building godot-mcp-x against 4.7-stable. These are
the things that compile-fail or silently no-op if you assume the "obvious" API.

### 1. `EditorInterface.save_scene_as()` returns `void`, not `Error`
✅ verified. Sibling `save_scene()` returns `Error` (int). So this **fails to
parse**:
```gdscript
var err: int = EditorInterface.save_scene_as(path)   # Parse Error: returns void
```
Do: call `save_scene_as(path)` without capturing, or use `save_scene()` /
`PackedScene.pack` when you need an error code.

### 2. Nodes without an `owner` are NOT saved
Adding a child is not enough. Set `node.owner = edited_scene_root` (and recurse
for whole subtrees after `duplicate()`/`reparent()`), or the node silently
vanishes on save.

### 3. `Node.get_path()` under the editor is full of editor chrome
You get `/root/@EditorNode@…/@SubViewport@…/<scene>/Player`. Never expose or
parse these. Anchor at `get_edited_scene_root()` and use `root.get_path_to(node)`
for clean scene-relative paths. (This was the original tool's 73K-char scene-tree
disaster.)

### 4. `str_to_var()` returns `null` for plain strings
`str_to_var("hello")` → `null`. Only Godot-literal syntax parses
(`"Vector3(…)"`, `"true"`, `"42"`). When coercing user values, treat `null` as
"keep the original string", and never reinterpret a property that is already a
`String`.

### 5. Signal connections need `CONNECT_PERSIST` to be saved
`from.connect(sig, cb)` works at runtime but isn't written to the `.tscn`. Use
`from.connect(sig, cb, CONNECT_PERSIST)` for editor-time connections you want
saved with the scene.

### 6. `ClassDB.instantiate()` leaks if you don't free it
Nodes aren't ref-counted. Any throwaway probe instance (e.g. to read class
defaults) must be `.free()`d. Resources (ref-counted) free themselves.

### 7. Pass `no_inheritance = true` to `ClassDB.class_get_*_list`
Otherwise a `describe_class` on, say, `CharacterBody3D` returns *all* of
`Node`/`Node3D`/`PhysicsBody3D`'s members too — hundreds of entries, mostly
noise. `true` returns only the class's own members.

### 8. `EditorInterface` is a global, not via `get_editor_interface()`
Since 4.3. In `@tool` scripts call `EditorInterface.foo()` directly. The old
`get_editor_interface()` accessor pattern is obsolete.

### 9. Reading large files: paginate at the source
Returning a whole 60K-char script/scene blows the model's context. Read by line
range (`offset`/`limit`) and report `total_lines` + `next_offset`. The same goes
for scene trees (use `max_depth`) and ClassDB dumps (use the `true` flag + paging).

### 10. Capturing a viewport image needs a frame first — but use `process_frame`
`vp.get_texture().get_image()` can return stale/empty data if called before the
frame is drawn, so await a frame first. **Do NOT** `await
RenderingServer.frame_post_draw` for this: that signal can stall (~30 s hang)
when the editor/game window is unfocused. Use `await get_tree().process_frame`
instead — it advances regardless of focus. (Cost a real screenshot-hang bug.)

### 11. Headless asset import: use `--import`, not `--editor --quit`
✅ verified on 4.7. To import resources without opening the editor GUI (e.g.
freshly added `.png`s, so `load()` works at runtime), run:
```
godot --headless --import <path/to/project.godot>
```
`godot --headless --editor --quit` loads the editor but does **not** reliably
write the `.import` sidecars / `.godot/imported/` cache — textures stay
unimported and `ResourceLoader.exists()` / `load()` return null at runtime.
(Found while integrating AI-generated sprites into a real game build.)
