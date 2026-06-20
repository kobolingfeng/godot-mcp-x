// Smoke test for batch-2 groups: shader, audio, particle, navigation, tilemap.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke2] waiting for editor…");
const t0 = Date.now();
while (!godot.isConnected() && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected()) { console.error("[smoke2] timeout"); process.exit(2); }
console.error(`[smoke2] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function call(m, p) {
  try {
    const r = await godot.sendCommand(m, p || {});
    const s = JSON.stringify(r);
    console.log(`PASS ${m}: ${s.length > 200 ? s.slice(0, 200) + "…" : s}`);
    pass++; return r;
  } catch (e) { console.log(`FAIL ${m}: ${e.message}`); fail++; return null; }
}

await call("create_scene", { path: "res://__smoke2.tscn", root_type: "Node", root_name: "World" });
// shader
await call("add_mesh_instance", { primitive: "box", name: "Cube" });
await call("create_shader", { path: "res://__smoke2.gdshader", code: "shader_type spatial;\nuniform vec4 tint : source_color = vec4(1.0);\nvoid fragment(){ ALBEDO = tint.rgb; }\n" });
await call("list_shader_uniforms", { path: "res://__smoke2.gdshader" });
await call("assign_shader", { node_path: "Cube", shader_path: "res://__smoke2.gdshader" });
await call("set_shader_param", { node_path: "Cube", param: "tint", value: "Color(1,0,0,1)" });
// particle
await call("create_particles", { name: "FX", amount: 32, lifetime: 2.0 });
await call("set_particle_process", { path: "FX", properties: { gravity: "Vector3(0,-2,0)" } });
await call("get_particle_info", { path: "FX" });
// navigation
await call("setup_navigation_region", { name: "NavRegion" });
await call("get_navigation_info", {});
// audio
await call("add_audio_player", { name: "Music", dimension: "plain" });
await call("list_audio_buses", {});
await call("add_audio_bus", { name: "SFX" });
await call("set_bus_volume", { bus: "SFX", volume_db: -6 });
await call("add_bus_effect", { bus: "SFX", effect: "Reverb" });
// tilemap (TileMapLayer; cells store/render properly once a TileSet is assigned)
await call("add_node", { type: "TileMapLayer", name: "Tiles" });
await call("tilemap_get_info", { path: "Tiles" });
await call("tilemap_fill_rect", { path: "Tiles", x: 0, y: 0, w: 3, h: 3, source_id: 0 });
await call("tilemap_get_used_cells", { path: "Tiles" });
await call("tilemap_clear", { path: "Tiles" });
await call("save_scene", {});

console.error(`\n[smoke2] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
