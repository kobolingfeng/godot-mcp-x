# godot-mcp-x

**English** · [简体中文](README.zh.md)

> **❤️ Support / 赞赏支持** — if godot-mcp-x saves you time, a small tip is hugely
> appreciated 🙏 如果这个项目帮到你,欢迎赞赏支持,非常感谢!
> **PayPal**: [paypal.me/koboling](https://paypal.me/koboling) · **WeChat 微信赞赏** ↓
>
> <img src="docs/wechat-reward.jpg" alt="WeChat 微信赞赏 QR" width="220">

A next-generation, **token-efficient** MCP server for AI-driven **Godot 4.7**
development. Clean-room core + battle-tested command logic, designed from day one
around the two things that actually matter for an AI agent: **fast, small,
correct responses** and **comprehensive editor + runtime control**.

> Status: **feature-complete & validated end-to-end** — **161 tools across 27
> groups**: project, scene, node, script, editor, analysis, resource, filesystem, ui,
> input map, animation, animation tree, physics, navigation, 3D builders, gridmap,
> skeleton, shader, particle, audio, tilemap, theme, batch, profiling, export, a
> full **runtime** (live in-game) channel, and **automated gameplay testing**
> (assertions, scenarios, monitors). Proven against a live 4.7-stable build
> (**167/167 round-trip calls green**, plus **13 unit tests** for the efficiency core).

## Why this exists (vs. godot-mcp-pro)

It started as a study of the mature `godot-mcp-pro` (172 tools). That tool works,
but two things hurt AI usage badly, and they're fixed here by design:

| Problem in the original | Fix in godot-mcp-x |
|---|---|
| Scene tree printed **full editor paths** (`/root/@EditorNode@…/SubViewport/Main/…`) → a mid-size scene = **73K chars**, blowing the token limit | Walks from the **edited scene root**; emits **scene-relative paths** (`Player/Camera3D`). Same scene → a few hundred chars. |
| No pagination/limits — `read_script` dumped 60K chars at once | **Source-side pagination** everywhere: `offset`/`limit` on scripts & scene files, `max_depth` on trees, paging on lists, + a TS-side budget clamp |
| `get_node_properties` returned everything | Returns **only changed (non-default)** props by default; opt into `include_defaults` or project specific `names[]` |
| 170+ tools repeat the same try/catch + JSON.stringify | **Declarative tool registry**: one uniform error/budget envelope, tools are pure data→data handlers |
| base64 screenshots over the wire | Saves a PNG, returns an **absolute file path** the host can read directly |
| (new capability) | **Live ClassDB introspection** (`list_classes`/`describe_class` with full method signatures) — ground-truth 4.7 API for correct codegen |
| (new capability) | **"Did you mean…?"** — typo'd type/property/method names **and node paths** (editor **and** runtime) return string-similarity suggestions, cutting agent retry round-trips |
| (new capability) | **Editor status dock** + `get_status` tool — live view of connected ports, command count, and play state |
| (new capability) | **Undoable edits** — node add/delete/rename/move/duplicate & property sets register with `EditorUndoRedoManager`, so a human can **Ctrl+Z** AI changes (+ `undo`/`redo` tools) |

The MCP server is a thin JSON-RPC proxy; the real perf is in **payload size** and
**editor-side serialization**, which is exactly where the work went.

## Architecture

```
 Claude / MCP client ──stdio──> godot-mcp-x server (Node/TS)
                                     │  WebSocket server on 127.0.0.1:6605-6609
                                     │  JSON-RPC 2.0 · heartbeat · multi-session
                                     │  dual-role routing (hello → editor | runtime)
                       ┌─────────────┴──────────────┐
              editor conn │                          │ runtime conn (only while playing)
                          ▼                          ▼
        Godot EDITOR + godot_mcp_x addon      RUNNING GAME + runtime_bridge autoload
        ws_client → router → commands/*.gd    direct WS → live get_tree()
        EditorInterface · ClassDB · scene     scene tree · props · input · frames
```
Reversed topology (server binds, editor dials) lets multiple sessions drive one
editor. **Ports 6605-6609** are deliberately distinct from godot-mcp-pro's
6505-6514, so both can run side by side.

## Install

1. **Build the server**
   ```bash
   cd server
   npm install
   npm run build
   ```
2. **Install the addon** — copy `addon/godot_mcp_x/` into your project's
   `res://addons/godot_mcp_x/`, then enable **Project → Project Settings →
   Plugins → Godot MCP X**. (See [INSTALL.md](INSTALL.md).)
3. **Register the MCP server** with your client. A ready-to-edit
   [.mcp.json](.mcp.json) is included:
   ```json
   { "mcpServers": { "godot-mcp-x": { "command": "node",
       "args": ["D:/GodotProjects/godot-mcp-x/server/build/index.js"] } } }
   ```
4. Open the editor. The plugin dials the server; tool calls now hit your live
   editor. Optional `GODOT_MCP_X_PORT` env var pins a fixed port.

## CLI (no MCP client needed)

After `npm run build`, drive the editor straight from a shell — handy for scripts
or to save context. Same handlers + transport as the MCP server (installable as
`godot-x` via the package bin).

```bash
node build/cli.js list [filter]            # list tools (optionally filtered)
node build/cli.js <tool> --help            # show a tool's parameters
node build/cli.js get_project_info
node build/cli.js add_node --type Sprite2D --name Hero --parent_path .
node build/cli.js set_node_property --path Hero --property position --value "Vector2(100,200)"
node build/cli.js get_scene_tree --max_depth 2
node build/cli.js batch_add_nodes --nodes '[{"type":"Node3D","name":"Lights"}]'
```

Values are auto-typed (numbers/bools and JSON `{...}`/`[...]` are parsed;
everything else stays a string) and validated against each tool's Zod schema, so
typos and missing required args fail fast with a clear message. Requires the
editor open with the plugin enabled.

### Daemon — warm connection (recommended)

A one-shot CLI call rebinds the WebSocket and waits for Godot to reconnect each
time (~1–2 s). Start a **daemon** once to keep the connection warm; subsequent
commands route to it over local HTTP and return in ~150 ms (≈5–10× faster):

```bash
node build/cli.js daemon        # long-lived: WS 6605-6609 + IPC 6610. Leave it running.
node build/cli.js status        # { daemon: true, ws_port, editor, runtime }
node build/cli.js get_game_info # auto-routes to the daemon
node build/cli.js stop-daemon
```

`godot-x <tool>` auto-detects a running daemon; if none is up it falls back to
one-shot, so scripts work either way. Override the IPC port with
`GODOT_MCP_X_DAEMON_PORT`. `status` also reports `concurrent_replaces` — non-zero
means two Godot instances are fighting over the port (keep only one). See
**[WALKTHROUGH.md](WALKTHROUGH.md)** for the full build-a-game loop.

### Runtime tools without an editor

Runtime tools (`get_game_screenshot`, `get_game_info`, `simulate_key`,
`execute_game_script`, …) work against a **standalone running game** — no editor
required. The game's `McpXRuntime` autoload dials in, and the CLI/daemon accepts an
editor **or** a runtime connection. So you can `godot --path .` your game and
screenshot / drive it directly. To catch a transient effect in one call:
`get_game_screenshot --run 'player._fire_nova()' --after 0.1` (or `--count 8` for a
burst).

### Headless asset import

To import freshly-added assets (new `.png`s, etc.) without opening the GUI:
`godot --headless --import path/to/project.godot`. **Gotcha:** `--editor --quit`
does *not* reliably write the `.import` sidecars, so `load()` returns null at
runtime — use `--import`.

## Tool modes (shrink context)

The full server registers 161 tools, and the tool list itself costs context. For
a focused session, load only the groups you need via `--mode` (or env
`GODOT_MCP_X_MODE`), plus `--tools` / `--exclude`:

| mode | tools | groups |
|---|--:|---|
| `full` (default) | 161 | everything |
| `minimal` | 47 | project, scene, node, script, editor |
| `3d` | 144 | common + physics, navigation, node3d, shader, particle, audio, animation_tree, gridmap, skeleton |
| `2d` | 114 | common + physics, tilemap, theme |
| `ui` | 76 | minimal + resource, theme, batch, runtime, ui |
| `test` | 70 | minimal + runtime, testing, profiling |

(common = minimal + analysis, resource, filesystem, ui, input, animation, batch, runtime, testing)

```jsonc
// .mcp.json — load only the 3D tools
{ "mcpServers": { "godot-mcp-x": { "command": "node",
    "args": ["D:/GodotProjects/godot-mcp-x/server/build/index.js", "--mode", "3d"] } } }
```

Or pick groups explicitly: `--tools project,scene,node,shader` / `--exclude export,profiling`.
Preview any mode: `node build/cli.js list --mode 3d`.

## Tools (current — 161)

- **project** (9): `get_project_info`, `get_project_settings`,
  `set_project_setting`, `get_filesystem_tree`, `list_autoloads`,
  `add_autoload`, `remove_autoload`, `uid_to_path`, `path_to_uid`
- **scene** (7): `get_scene_tree`, `get_current_scene`, `open_scene`,
  `save_scene`, `create_scene`, `get_scene_file_content`, `instance_scene`
- **node** (13): `add_node`, `delete_node`, `rename_node`, `move_node`,
  `duplicate_node`, `get_node_properties`, `set_node_property`,
  `set_node_properties`, `get_node_signals`, `connect_signal`,
  `set_node_groups`, `find_nodes`, `call_node_method`
- **script** (7): `read_script`, `create_script`, `write_script`, `edit_script`,
  `attach_script`, `validate_script`, `list_scripts`
- **editor** (11): `execute_editor_script`, `get_editor_errors`,
  `get_output_log`, `clear_output`, `get_editor_screenshot`, `reload_scripts`,
  `list_classes`, `describe_class`, `undo`, `redo`, `get_status`
- **analysis** (5): `search_files`, `search_in_files`, `find_script_references`,
  `get_scene_dependencies`, `analyze_scene_complexity`
- **resource** (3): `create_resource`, `read_resource`, `edit_resource`
- **filesystem** (4): `create_folder`, `rename_path`, `delete_path`, `duplicate_path`
- **ui** (2): `add_virtual_joystick` (4.7 touch stick → input actions), `set_anchor_preset`
- **input map** (4): `list_input_actions`, `add_input_action`,
  `remove_input_action`, `add_input_event`
- **animation** (5): `list_animations`, `get_animation_info`, `create_animation`,
  `add_animation_track`, `set_animation_keyframe`
- **physics** (5): `get_physics_layers`, `set_physics_layer_name`,
  `set_collision_layers`, `get_collision_info`, `setup_collision_shape`
- **3D** (5): `add_mesh_instance`, `setup_light` (directional/omni/spot/**area** = 4.7 AreaLight3D),
  `setup_camera`, `set_material`, `setup_environment`
- **runtime** (14): `play_scene`, `stop_scene`, `is_game_running`,
  `get_game_info`, `get_game_scene_tree`, `get_game_node_properties`,
  `set_game_node_property`, `execute_game_script`, `get_game_screenshot`,
  `simulate_action`, `simulate_key`, `get_autoload`, `find_game_nodes`,
  `call_game_method`
  — the in-game tools dial in over a **direct WebSocket** (no file polling);
  call `play_scene` first.
- **shader** (6): `create_shader`, `read_shader`, `edit_shader`, `assign_shader`,
  `set_shader_param`, `list_shader_uniforms`
- **audio** (5): `add_audio_player`, `list_audio_buses`, `add_audio_bus`,
  `set_bus_volume`, `add_bus_effect`
- **particle** (3): `create_particles`, `set_particle_process`, `get_particle_info`
- **navigation** (4): `setup_navigation_region`, `setup_navigation_agent`,
  `bake_navigation_mesh`, `get_navigation_info`
- **tilemap** (7, TileMapLayer-native): `tilemap_get_info`, `tilemap_set_cell`,
  `tilemap_get_cell`, `tilemap_erase_cell`, `tilemap_fill_rect`, `tilemap_clear`,
  `tilemap_get_used_cells`
- **theme** (7): `create_theme`, `set_theme_color`, `set_theme_constant`,
  `set_theme_font_size`, `set_theme_stylebox`, `get_theme_info`, `apply_theme`
- **animation tree** (6): `create_animation_tree`, `setup_state_machine`,
  `add_state`, `add_transition`, `get_animation_tree_info`, `set_tree_param`
- **batch** (3): `batch_add_nodes`, `batch_set_properties`, `batch_get_properties`
- **profiling** (1): `get_performance_monitors`
- **export** (2): `list_export_presets`, `get_export_info`
- **testing** (8, runtime): `assert_property`, `assert_node_exists`,
  `assert_screen_text`, `wait_for_node`, `monitor_property`, `record_frames`,
  `run_test_scenario`, `get_test_report` — automated gameplay regression in the
  live game (pass/fail report; intentional-fail verified)
- **gridmap** (6): `add_gridmap`, `gridmap_set_cell`, `gridmap_get_cell`,
  `gridmap_clear`, `gridmap_get_used_cells`, `gridmap_get_info`
- **skeleton** (9): `get_skeleton_info`, `list_bones`, `add_bone`,
  `set_bone_pose`, `reset_bone_poses`, `add_bone_attachment`,
  `add_skeleton_modifier`, `setup_look_at_modifier`, `list_skeleton_modifiers`
  — IK & bone constraints via the SkeletonModifier3D system (TwoBoneIK3D,
  FABRIK3D, CCDIK3D, LookAtModifier3D, SpringBoneSimulator3D, …)

## Roadmap

- [x] Runtime IPC: replaced the original's per-frame file polling with a direct
      game→server WebSocket (live scene tree, property get/set, input simulation,
      frame capture, in-game script exec) — dual-role editor/runtime routing
- [x] Ported: analysis, resource, input map, animation, physics, 3D builders,
      shader, audio, particle, navigation, tilemap (TileMapLayer-native),
      theme, animation_tree, batch, profiling, export — **all major domains covered**
- [x] CLI mode (no MCP client needed) — `godot-x <tool> --k v`, auto-typed + schema-validated; **warm-connection daemon** (`godot-x daemon`, ~150 ms/call vs ~1–2 s one-shot)
- [x] Per-mode tool filtering (full/minimal/2d/3d/ui/test + --tools/--exclude)
- [x] Niche tools: gridmap (3D block building), skeleton (bones/poses/attachments)
- [x] Quality pass: unit tests (vitest) for the efficiency core; `describe_class`
      method signatures; `call_node_method` / `call_game_method`; filesystem group
- [x] AI ergonomics: "did you mean…?" suggestions on typo'd type/property/method names
- [x] UndoRedo: node/property edits are undoable in the editor (Ctrl+Z) + `undo`/`redo`
      tools; also fixed `create_scene` to cleanly overwrite an already-open scene
- [x] Runtime parity for "did you mean…?" + closest-node-path suggestions; editor
      status dock + `get_status`; fixed a `get_editor_screenshot` hang on unfocused windows
- [x] Skeleton-IK & bone modifiers (SkeletonModifier3D: TwoBoneIK3D/FABRIK3D/LookAtModifier3D/…)
- [x] Deeper KB (11 docs): rendering/materials/lighting, physics/collision, resources/exports, skeleton-IK
- [ ] Optional remaining: android deploy (needs Android SDK + export templates)
- [x] Benchmark quantifying token wins vs. the original — see [BENCHMARK.md](BENCHMARK.md)
      (scene-tree output **−80%** on a real 137-node scene)

## Knowledge base

[knowledge/](knowledge/) — a reusable, AI-oriented Godot 4.7 reference (20 docs)
built and **verified against the live engine** while developing this tool:
what's new in 4.7, GDScript essentials, editor-automation recipes, API gotchas,
godot-mcp-x workflows, gameplay patterns, rendering/materials/lighting,
physics/collision, resources & @export, the SkeletonModifier3D IK system, and a
**deep-dive 4.7 changelog** (VirtualJoystick, DrawableTexture2D, ray-tracing
groundwork, HDR, Jolt SoftBody, GUI/input/editor/Android changes) — plus
UI/Control, shaders (Godot Shading Language), XR/OpenXR, performance &
optimization, multiplayer/networking, audio, and navigation guides — every
major engine subsystem.

## Dev / validation

`test_project/` is a throwaway Godot project for parse-checking the addon:
```bash
# parse every addon script (transitively covers the graph via plugin.gd)
"D:/Godot/Godot_v4.7-stable_win64.exe" --headless --path test_project --check-only \
  --script res://addons/godot_mcp_x/plugin.gd
# full end-to-end round trip (server + live editor + commands)
cd server && node test/handshake.js   # with the headless editor running
```

## License

MIT. Portions adapted from godot-mcp-pro (MIT). See [LICENSE](LICENSE).
