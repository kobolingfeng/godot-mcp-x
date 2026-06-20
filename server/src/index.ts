#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { GodotConnection } from "./core/connection.js";
import { registerTools } from "./core/registry.js";
import { selectTools } from "./tools/groups.js";

const INSTRUCTIONS = `godot-mcp-x — high-efficiency MCP for Godot 4.7.

Conventions:
- Node paths are ALWAYS scene-relative ('.' = the edited scene root, e.g. 'Player/Camera3D').
  Never use editor-internal '/root/@EditorNode@…' paths.
- Outputs are token-budgeted. Large reads (scene tree, scripts, scene files, file
  trees) are paginated or filtered — use max_depth / type_filter / offset+limit
  instead of fetching everything, and follow next_offset to page.
- get_node_properties returns only CHANGED (non-default) properties by default;
  pass include_defaults=true or names[] for more.
- Runtime tools (get_game_*, set_game_node_property, simulate_action/key,
  find_game_nodes, execute_game_script) need a LIVE game: call play_scene first,
  stop_scene when done. Editor tools keep working while the game runs.
- For anything not covered by a dedicated tool, use execute_editor_script (full
  editor API) and describe_class to introspect the live 4.7 ClassDB.`;

const explicitPort = process.env.GODOT_MCP_X_PORT;
const godot = new GodotConnection(parseInt(explicitPort || "6605", 10), !!explicitPort);

const server = new McpServer({ name: "godot-mcp-x", version: "0.1.0" }, { instructions: INSTRUCTIONS });

// Optional tool filtering to shrink the tool-list token cost for focused sessions:
//   --mode full|minimal|2d|3d|ui|test   (or GODOT_MCP_X_MODE)
//   --tools project,scene,node          (explicit group include)
//   --exclude export,profiling          (group exclude)
function argVal(flag: string): string | undefined {
  const i = process.argv.indexOf(flag);
  return i >= 0 ? process.argv[i + 1] : undefined;
}
const mode = process.env.GODOT_MCP_X_MODE ?? argVal("--mode") ?? "full";
const groupsArg = argVal("--tools");
const tools = selectTools({
  mode,
  groups: groupsArg ? groupsArg.split(",") : undefined,
  exclude: argVal("--exclude")?.split(","),
});
registerTools(server, godot, tools);

async function main(): Promise<void> {
  // Start the WS server (non-blocking). Tool calls fail with a clear message
  // until Godot connects.
  godot.connect().catch((err) => console.error(`[MCP-X] WS server start failed: ${err.message}`));

  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`[MCP-X] godot-mcp-x started (stdio) — ${tools.length} tools (mode: ${groupsArg ? "custom" : mode})`);
}

main().catch((err) => {
  console.error("[MCP-X] Fatal error:", err);
  process.exit(1);
});
