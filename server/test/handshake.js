// End-to-end transport test: bind the WS server (as the real MCP server does),
// wait for the Godot editor plugin to dial in, then exercise a few commands.
// Run with: node test/handshake.js   (after `npm run build`)
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[test] WS server bound on port", godot.getPort(), "— waiting for Godot…");

const t0 = Date.now();
while (!godot.isConnected() && Date.now() - t0 < 25000) {
  await new Promise((r) => setTimeout(r, 200));
}
if (!godot.isConnected()) {
  console.error("[test] TIMEOUT — Godot never connected");
  process.exit(2);
}
console.error(`[test] Godot connected after ${Date.now() - t0}ms\n`);

let pass = 0;
let fail = 0;
async function call(method, params) {
  try {
    const r = await godot.sendCommand(method, params || {});
    const s = JSON.stringify(r);
    console.log(`PASS ${method}: ${s.length > 400 ? s.slice(0, 400) + "…" : s}`);
    pass++;
  } catch (e) {
    console.log(`FAIL ${method}: ${e.message}`);
    fail++;
  }
}

await call("get_project_info");
await call("get_filesystem_tree", { filter: "*.gd" });
await call("list_classes", { filter: "AreaLight" });
await call("describe_class", { name: "CharacterBody3D", members: ["properties"] });
await call("create_scene", { path: "res://__e2e_test.tscn", root_type: "Node3D", root_name: "World" });
await call("add_node", { type: "DirectionalLight3D", name: "Sun", parent_path: "." });
await call("get_scene_tree", {});
await call("get_node_properties", { path: "Sun" });

console.error(`\n[test] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
