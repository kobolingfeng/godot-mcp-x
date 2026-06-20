// End-to-end RUNTIME test: bind the server, run the game directly (its autoload
// runtime bridge dials in as role=runtime), then drive runtime tools.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[rt] bound on", godot.getPort(), "— waiting for the game (runtime)…");

const t0 = Date.now();
let info = null;
while (Date.now() - t0 < 25000) {
  try { info = await godot.sendCommand("get_game_info", {}, "runtime"); break; }
  catch { await new Promise((r) => setTimeout(r, 300)); }
}
if (!info) { console.error("[rt] runtime never connected"); process.exit(2); }
console.error(`[rt] runtime connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function call(m, p) {
  try {
    const r = await godot.sendCommand(m, p || {}, "runtime");
    const s = JSON.stringify(r);
    console.log(`PASS ${m}: ${s.length > 240 ? s.slice(0, 240) + "…" : s}`);
    pass++; return r;
  } catch (e) { console.log(`FAIL ${m}: ${e.message}`); fail++; return null; }
}

console.log(`PASS get_game_info: ${JSON.stringify(info).slice(0, 240)}`); pass++;
await call("get_game_scene_tree", {});
await call("find_game_nodes", { type: "Camera3D" });
await call("get_game_node_properties", { path: ".", names: ["ticks"] });
await call("set_game_node_property", { path: ".", property: "ticks", value: 999 });
await call("get_game_node_properties", { path: ".", names: ["ticks"] });
await call("execute_game_script", { code: "_mcp_print(get_tree().get_node_count())\n_mcp_print(get_tree().current_scene.name)" });
await call("simulate_key", { key: "Space", duration: 0.05 });
await call("get_game_screenshot", {});

console.error(`\n[rt] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
