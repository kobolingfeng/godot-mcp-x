import { z } from "zod";
import { tool, passthrough, runtimePassthrough, type ToolDef } from "../core/registry.js";

/**
 * Runtime tools. play_scene/stop_scene/is_game_running run in the EDITOR; the
 * rest run inside the LIVE GAME (require play_scene first) via the runtime
 * bridge autoload — a direct WebSocket, not file polling.
 */
export const runtimeTools: ToolDef[] = [
  tool({
    name: "play_scene",
    description: "Start playing a scene (path, else the current scene, else the main scene). Required before any get_game_*/simulate_* tool.",
    schema: { path: z.string().optional().describe("Scene to play; omit for current/main scene") },
    handler: passthrough("play_scene"),
  }),
  tool({
    name: "stop_scene",
    description: "Stop the running game.",
    handler: passthrough("stop_scene"),
  }),
  tool({
    name: "is_game_running",
    description: "Whether the editor is currently playing a scene.",
    handler: passthrough("is_game_running"),
  }),
  tool({
    name: "reload_game_script",
    description: "Hot-reload a GDScript in the RUNNING game (recompiles + keeps live instance state) so you can iterate on logic without restarting. Pass the res:// script path you just edited.",
    schema: { path: z.string().describe("res:// path of the .gd to reload") },
    handler: runtimePassthrough("reload_game_script"),
  }),
  tool({
    name: "get_game_info",
    description: "Live game status: current scene, fps, node count, time scale. (Game must be running.)",
    handler: runtimePassthrough("get_game_info"),
  }),
  tool({
    name: "get_game_scene_tree",
    description: "Scene tree of the RUNNING game (scene-relative paths). Use max_depth to bound output.",
    schema: {
      max_depth: z.number().int().optional(),
      include_internal: z.boolean().optional(),
      include_properties: z.boolean().optional(),
    },
    handler: runtimePassthrough("get_game_scene_tree"),
  }),
  tool({
    name: "get_game_node_properties",
    description: "Live properties of a node in the running game (changed-only by default).",
    schema: {
      path: z.string().describe("Scene-relative node path in the running game"),
      names: z.array(z.string()).optional(),
      include_defaults: z.boolean().optional(),
    },
    handler: runtimePassthrough("get_game_node_properties"),
  }),
  tool({
    name: "set_game_node_property",
    description: "Set a property on a live node in the running game (hot-tweak gameplay).",
    schema: {
      path: z.string().describe("Scene-relative node path in the running game"),
      property: z.string(),
      value: z.any(),
    },
    handler: runtimePassthrough("set_game_node_property"),
  }),
  tool({
    name: "execute_game_script",
    description: "Run GDScript inside the running game (in a temp Node — get_tree() works; use _mcp_print to return output).",
    schema: { code: z.string().describe("GDScript body; call _mcp_print(x) to capture output") },
    maxChars: 40000,
    handler: runtimePassthrough("execute_game_script"),
  }),
  tool({
    name: "get_game_screenshot",
    description: "Screenshot the running game; saves a PNG and returns its absolute path (read it to view). Optionally run GDScript first / wait / capture a burst — to catch transient one-shot VFX.",
    schema: {
      save_path: z.string().optional().describe("res:// or user:// PNG path"),
      run: z.string().optional().describe("GDScript to run right before capture (e.g. trigger an effect) — catches transient VFX in one call"),
      after: z.number().optional().describe("Seconds to wait (after `run`) before capturing"),
      count: z.number().int().optional().describe("Capture a burst of N frames; save_path becomes a prefix (x_0.png, x_1.png, …)"),
      interval: z.number().optional().describe("Seconds between burst frames (default 0.1)"),
    },
    handler: runtimePassthrough("get_game_screenshot"),
  }),
  tool({
    name: "simulate_action",
    description: "Drive an input action in the running game. mode=tap presses & releases over a duration; press/release split the two so you can hold input across calls.",
    schema: {
      action: z.string().describe("Input action name (must exist in the input map)"),
      mode: z.enum(["tap", "press", "release"]).optional().describe("tap (press+hold+release, default) | press (hold until released) | release"),
      duration: z.number().optional().describe("Seconds held in tap mode (default 0.1)"),
      strength: z.number().optional().describe("0..1 (default 1)"),
      max_hold: z.number().optional().describe("press mode: auto-release after N seconds as a safety (default 10; 0 = never)"),
    },
    handler: runtimePassthrough("simulate_action"),
  }),
  tool({
    name: "simulate_key",
    description: "Drive a physical key in the running game. mode=tap presses & releases over a duration; press/release split the two so you can hold a key down across calls.",
    schema: {
      key: z.string().describe("Key name, e.g. 'W', 'Space', 'Escape'"),
      mode: z.enum(["tap", "press", "release"]).optional().describe("tap (press+hold+release, default) | press (hold until released) | release"),
      duration: z.number().optional().describe("Seconds held in tap mode (default 0.1)"),
      max_hold: z.number().optional().describe("press mode: auto-release after N seconds as a safety (default 10; 0 = never)"),
    },
    handler: runtimePassthrough("simulate_key"),
  }),
  tool({
    name: "get_autoload",
    description: "Inspect an autoload singleton's (changed) properties in the running game.",
    schema: { name: z.string().describe("Autoload name, e.g. 'GameState'") },
    handler: runtimePassthrough("get_autoload"),
  }),
  tool({
    name: "find_game_nodes",
    description: "Find live nodes in the running game by type/name/group.",
    schema: {
      type: z.string().optional(),
      pattern: z.string().optional().describe("Name glob"),
      group: z.string().optional(),
      limit: z.number().int().optional(),
    },
    handler: runtimePassthrough("find_game_nodes"),
  }),
  tool({
    name: "call_game_method",
    description: "Call a method on a live node in the running game (positional args; string args parsed). Returns the result.",
    schema: {
      path: z.string().describe("Scene-relative node path in the running game"),
      method: z.string(),
      args: z.array(z.any()).optional(),
    },
    handler: runtimePassthrough("call_game_method"),
  }),
];
