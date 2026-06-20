// Smoke test for the ported tool groups — exercises every new module's core
// path against a live 4.7 editor to catch runtime API mistakes.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke] bound on", godot.getPort(), "— waiting for Godot…");
const t0 = Date.now();
while (!godot.isConnected() && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected()) { console.error("[smoke] TIMEOUT"); process.exit(2); }
console.error(`[smoke] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function call(m, p) {
  try {
    const r = await godot.sendCommand(m, p || {});
    const s = JSON.stringify(r);
    console.log(`PASS ${m}: ${s.length > 220 ? s.slice(0, 220) + "…" : s}`);
    pass++; return r;
  } catch (e) { console.log(`FAIL ${m}: ${e.message}`); fail++; return null; }
}

// 3D builders
await call("create_scene", { path: "res://__smoke.tscn", root_type: "Node3D", root_name: "World" });
await call("add_mesh_instance", { primitive: "sphere", name: "Ball" });
await call("set_material", { path: "Ball", albedo: "Color(0.2,0.6,1,1)", roughness: 0.3, metallic: 0.5 });
await call("setup_light", { kind: "directional", name: "Sun", energy: 1.2, color: "Color(1,0.95,0.9,1)" });
await call("setup_camera", { name: "Cam", current: true, fov: 70 });
await call("setup_environment", {});
// physics
await call("setup_collision_shape", { path: ".", shape: "box", name: "Col" });
await call("set_collision_layers", { path: "Col", layer: 3, mask: 5 });
await call("get_collision_info", { path: "Col" });
await call("get_physics_layers", {});
await call("set_physics_layer_name", { layer: 5, name: "smoke_layer", dimension: "3d" });
// animation
await call("add_node", { type: "AnimationPlayer", name: "Anim" });
await call("create_animation", { player_path: "Anim", name: "spin", length: 2.0 });
await call("add_animation_track", { player_path: "Anim", anim_name: "spin", node_path: "Ball", property: "position" });
await call("set_animation_keyframe", { player_path: "Anim", anim_name: "spin", track_index: 0, time: 0.0, value: "Vector3(0,0,0)" });
await call("set_animation_keyframe", { player_path: "Anim", anim_name: "spin", track_index: 0, time: 1.0, value: "Vector3(0,2,0)" });
await call("get_animation_info", { player_path: "Anim", name: "spin" });
await call("list_animations", { player_path: "Anim" });
// input map
await call("add_input_action", { name: "smoke_jump", deadzone: 0.4 });
await call("add_input_event", { name: "smoke_jump", key: "Space" });
await call("list_input_actions", {});
await call("remove_input_action", { name: "smoke_jump" });
// resources
await call("create_resource", { type: "StandardMaterial3D", path: "res://__smoke_mat.tres", properties: { metallic: 0.8, roughness: 0.2 } });
await call("read_resource", { path: "res://__smoke_mat.tres" });
await call("edit_resource", { path: "res://__smoke_mat.tres", properties: { roughness: 0.6 } });
// analysis
await call("search_in_files", { query: "extends", file_type: "gd", max_results: 5 });
await call("analyze_scene_complexity", {});
await call("save_scene", {});

console.error(`\n[smoke] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
