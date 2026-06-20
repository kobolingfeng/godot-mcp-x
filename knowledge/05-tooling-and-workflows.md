# Driving Godot 4.7 via godot-mcp-x — workflows

How an AI agent should actually use the tools. (Tool names are godot-mcp-x's;
the ideas transfer to any Godot MCP.)

## The two worlds: editor vs runtime

- **Editor tools** act on the scene open in the editor (build/inspect/save). Always
  available once the plugin is connected.
- **Runtime tools** (`get_game_*`, `set_game_node_property`, `simulate_*`,
  `find_game_nodes`, `execute_game_script`, the `assert_*`/`run_test_scenario`
  testing tools) act on the **running game** — call `play_scene` first, `stop_scene`
  after. Editor tools keep working while the game runs.

## Golden rules

1. **Paths are scene-relative.** `.` = scene root, `Player/Camera3D` = a descendant.
   Never the editor-internal `/root/@EditorNode@…` form.
2. **Read narrow.** Prefer `max_depth`, `type_filter`/`find_nodes`, `offset`+`limit`
   over fetching everything; follow `next_offset` to page. `get_node_properties`
   returns only changed props by default.
3. **Inspector over code** for static visual values — `set_node_property` keeps
   them visible/tweakable; only hardcode what must be dynamic.
4. **Escape hatches:** anything without a dedicated tool → `execute_editor_script`
   (editor) / `execute_game_script` (game). Unsure of an API → `describe_class`.

## Workflow: build a scene from scratch

```
create_scene path=res://enemy.tscn root_type=CharacterBody3D root_name=Enemy
add_node type=CollisionShape3D name=Col parent_path=.        # or setup_collision_shape
add_mesh_instance primitive=capsule name=Body
create_script path=res://enemy.gd attach_to=.
write_script path=res://enemy.gd content="…"
set_node_properties path=. properties={"collision_layer":2}
save_scene
```
Batch the node creation with `batch_add_nodes` when adding several at once.

## Workflow: inspect an unfamiliar project

```
get_project_info                      # version, renderer, autoloads, main scene
get_scene_tree max_depth=2            # shape first, then drill in
get_node_properties path=Player       # changed props only
search_in_files query="func _ready"   # find code
analyze_scene_complexity              # node counts / hotspots
```

## Workflow: play & test a game (regression)

```
play_scene
wait_for_node path=Player timeout=5
run_test_scenario name=jump steps=[
  {type:"assert_property", path:"Player", property:"velocity", op:"eq", expected:"Vector3(0,0,0)"},
  {type:"action", action:"jump", duration:0.1},
  {type:"wait", seconds:0.2},
  {type:"assert_property", path:"Player", property:"position", op:"ne", expected:"Vector3(0,0,0)"}
]
get_game_screenshot                   # returns a PNG path — read it to look
get_test_report
stop_scene
```

## Workflow: hot-tweak a running game

```
play_scene
set_game_node_property path=Player property=speed value=12
monitor_property path=Player property=position duration=1 samples=10
```
Then port the value you liked back to the editor with `set_node_property` + `save_scene`.

## Token efficiency

- Run the server in a focused **mode** (`--mode 3d`, etc.) so only relevant tools
  load. Preview with `node build/cli.js list --mode 3d`.
- Screenshots return a **file path**, not base64 — read the file to view it.
- Use the **CLI** (`godot-x <tool> --k v`) for one-off calls to avoid loading the
  whole tool surface into a chat.
