# Walkthrough — building a game with godot-mcp-x

godot-mcp-x's sweet spot is the **runtime feedback loop**: run the game, look at
it, poke it, tweak it live, repeat — without leaving your agent or shell. This is
the workflow that built and validated the bundled `vampire_survivors` demo.

## What it's good at (and what it isn't)

- **Great at** — inspecting and *driving a running Godot*: screenshots, live
  scene tree, reading/poking live node state, simulating input, running GDScript
  inside the live game; plus precise, **undoable** editor edits.
- **Use your editor / direct file writes for** authoring lots of script & scene
  content. Hand-writing `.gd`/`.tscn` beats dozens of `add_node`/`set_property`
  round-trips. Let the MCP do what files can't: **run and observe.**

## 1. Install

1. Copy `addon/godot_mcp_x` into your project's `addons/` and enable the
   **godot_mcp_x** plugin (Project ▸ Project Settings ▸ Plugins).
2. The plugin registers the runtime bridge autoload for you. (Manual:
   `McpXRuntime="*res://addons/godot_mcp_x/runtime/runtime_bridge.gd"`.)
3. Build the server: `cd server && npm i && npm run build`.

## 2. Start the daemon (recommended)

The CLI works one-shot, but each command rebinds the WebSocket and waits for
Godot to reconnect (~1–2 s). Start a **daemon** once to keep the connection warm
— commands then return in ~150 ms:

```bash
godot-x daemon        # leave running (binds WS 6605-6609 + IPC 6610)
godot-x status        # { daemon: true, editor: …, runtime: … }
godot-x stop-daemon
```

Any `godot-x <tool>` auto-routes to the daemon if one is up, else falls back to
one-shot. Driving from an AI agent? Launch `godot-x daemon` as a background
process; every later tool call is then a cheap client.

## 3. The loop

1. **Author** gameplay — your scripts/scenes (editor or file tools). The demo is
   fully code-driven: `scripts/{game,player,enemy,projectile,xp_gem,art}.gd` and a
   one-node `main.tscn`; entities are instantiated with `preload(script).new()`.
2. **Run** it — open the editor and `godot-x play_scene`, or just run the project
   (`godot --path .`). The runtime bridge dials in either way.
3. **Look** — `godot-x get_game_screenshot --save_path user://shot.png` (read the
   PNG), `godot-x get_game_info` (fps / node count / scene).
4. **Inspect** — `godot-x get_game_scene_tree --max_depth 2`,
   `godot-x get_game_node_properties --path Player`.
5. **Hot-tweak** (the superpower) —
   `godot-x execute_game_script --code 'get_tree().get_first_node_in_group("player").add_xp(150)'`,
   `godot-x set_game_node_property …`, `godot-x call_game_method …`.
6. **Simulate input** — `godot-x simulate_key --key D --duration 1.5`.
7. Tweak code, re-run, repeat.

## 4. Worked example — the demo

How `vampire_survivors` was built and validated end-to-end:

- **Art** — generated with the codex `image_gen` tool on a pure-magenta key, then
  chroma-keyed to transparent PNGs (prompt archived in `_codex_assets.txt`).
- **SFX** — synthesized as WAVs by a tiny Python script (`assets/_make_sfx.py`).
- **VFX** — third-party 2D fire/electric packs dropped into `res://VFX/` and
  instantiated as skills (Fire Nova, Lightning chain).
- **Validation** — launched the standalone game, `get_game_screenshot` to confirm
  it renders, `simulate_key` to walk the player into the gem field (XP → level-up
  confirmed live), `execute_game_script` to hot-level the player and spawn a boss
  for a showcase shot. No manual clicking.

## 5. Editor edits are all undoable

Every node-creating and property/state-setting tool routes through the editor's
UndoRedo (scene history): `add_node`, `add_mesh_instance`, `instance_scene`,
`set_node_property`, `set_node_groups`, `set_collision_layers`, `set_material`,
`batch_*`, gridmap/tilemap cells, bone poses, … So a stray edit is just **Ctrl+Z**
in the editor.

## 6. Gotchas (learned the hard way)

- **Headless import** — to import freshly added assets without the GUI, use
  `godot --headless --import <project.godot>`. `--editor --quit` does **not**
  reliably write `.import` files, so `load()` returns null at runtime.
- **One server per port** — run only ONE editor/daemon on 6605 at a time. Multiple
  Godot instances all dial 6605 and the server keeps the last; stale state then
  looks like a bug. Kill strays first.
- **Transient VFX in screenshots** — one-shot effects (~0.5 s) are hard to time via
  async calls; use a persistent effect or `record_frames` to capture them.
- **Shrink the tool surface** — `godot-x list --mode 2d` (or `minimal/3d/ui/test`)
  loads only the groups you need.

## Runtime tools cheat-sheet

| tool | what |
|---|---|
| `play_scene` / `stop_scene` | start / stop the game (editor side) |
| `get_game_screenshot` | PNG of the running game → file path |
| `get_game_info` | fps, node count, current scene |
| `get_game_scene_tree` | live tree (scene-relative paths) |
| `get_game_node_properties` | live node props (changed-only) |
| `set_game_node_property` | hot-set a live property |
| `call_game_method` | call a method on a live node |
| `execute_game_script` | run GDScript in the live game (`_mcp_print(x)` returns output) |
| `simulate_key` / `simulate_action` | drive input |
| `find_game_nodes` | find live nodes by type / name / group |
