import { z } from "zod";
import { tool, passthrough, runtimePassthrough, type ToolDef } from "../core/registry.js";

/**
 * High-level multiplayer (Godot's MultiplayerSpawner / MultiplayerSynchronizer /
 * SceneReplicationConfig). Spawner & synchronizer scaffolding is editor-side and
 * undoable; peer setup, authority and live state run in the GAME (play_scene first).
 */
export const mpTools: ToolDef[] = [
  tool({
    name: "add_multiplayer_spawner",
    description:
      "Add a MultiplayerSpawner under a parent: it auto-spawns/despawns the given scenes on clients " +
      "when the server adds/removes them under spawn_path. Undoable.",
    schema: {
      parent_path: z.string().optional().describe("Scene-relative parent (default '.')"),
      scenes: z.array(z.string()).optional().describe("res:// scene paths the spawner may spawn"),
      spawn_path: z.string().optional().describe("Scene-relative node that spawned instances are added under (default: the spawner's parent)"),
      name: z.string().optional(),
    },
    handler: passthrough("add_multiplayer_spawner"),
  }),
  tool({
    name: "add_multiplayer_synchronizer",
    description:
      "Add a MultiplayerSynchronizer under a node and build its SceneReplicationConfig to replicate the " +
      "listed properties (e.g. position, rotation) from the authority to peers. Undoable.",
    schema: {
      path: z.string().describe("Node whose properties to replicate (the synchronizer is added as its child)"),
      properties: z.array(z.string()).describe("Properties to replicate: 'position', 'rotation', or 'Child:prop'"),
      spawn: z.boolean().optional().describe("Send each property's value on spawn (default true)"),
      interval: z.number().optional().describe("Replication interval in seconds (0 = every frame)"),
      name: z.string().optional(),
    },
    handler: passthrough("add_multiplayer_synchronizer"),
  }),
  tool({
    name: "setup_multiplayer_peer",
    description:
      "In the RUNNING game, create an ENet server or client peer and assign it to the SceneTree's " +
      "multiplayer (loopback/testing; shipping games usually do this in their own code).",
    schema: {
      mode: z.enum(["server", "client"]).optional().describe("server (default) or client"),
      port: z.number().int().optional().describe("Port (default 7777)"),
      host: z.string().optional().describe("client mode: server host (default 127.0.0.1)"),
      max_clients: z.number().int().optional().describe("server mode: max clients (default 32)"),
    },
    handler: runtimePassthrough("setup_multiplayer_peer"),
  }),
  tool({
    name: "get_multiplayer_info",
    description: "Live multiplayer state of the running game: has_peer, is_server, unique_id, connected peers.",
    handler: runtimePassthrough("get_multiplayer_info"),
  }),
  tool({
    name: "set_game_authority",
    description: "Set the multiplayer authority (owning peer id) of a live node in the running game.",
    schema: {
      path: z.string().describe("Scene-relative node path in the running game"),
      id: z.number().int().describe("Peer id that owns the node (1 = server)"),
      recursive: z.boolean().optional().describe("Apply to descendants too (default true)"),
    },
    handler: runtimePassthrough("set_game_authority"),
  }),
];
