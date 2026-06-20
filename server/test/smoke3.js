// Smoke test for batch-3 groups: theme, animation_tree, batch, profiling, export.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke3] waiting for editor…");
const t0 = Date.now();
while (!godot.isConnected() && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected()) { console.error("[smoke3] timeout"); process.exit(2); }
console.error(`[smoke3] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function call(m, p) {
  try {
    const r = await godot.sendCommand(m, p || {});
    const s = JSON.stringify(r);
    console.log(`PASS ${m}: ${s.length > 200 ? s.slice(0, 200) + "…" : s}`);
    pass++; return r;
  } catch (e) { console.log(`FAIL ${m}: ${e.message}`); fail++; return null; }
}

await call("create_scene", { path: "res://__smoke3.tscn", root_type: "Node", root_name: "World" });
// theme
const TP = "res://__smoke3_theme.tres";
await call("create_theme", { path: TP, default_font_size: 14 });
await call("set_theme_color", { path: TP, name: "font_color", type: "Button", color: "Color(1,1,0,1)" });
await call("set_theme_constant", { path: TP, name: "h_separation", type: "HBoxContainer", value: 8 });
await call("set_theme_font_size", { path: TP, name: "font_size", type: "Label", size: 20 });
await call("set_theme_stylebox", { path: TP, name: "panel", type: "Panel", stylebox: "flat", bg_color: "Color(0.1,0.1,0.1,1)" });
await call("get_theme_info", { path: TP });
await call("add_node", { type: "Control", name: "UI" });
await call("apply_theme", { node_path: "UI", theme_path: TP });
// animation_tree
await call("add_node", { type: "AnimationPlayer", name: "Anim" });
await call("create_animation", { player_path: "Anim", name: "idle", length: 1.0 });
await call("create_animation", { player_path: "Anim", name: "run", length: 0.8 });
await call("create_animation_tree", { name: "Tree", anim_player_path: "../Anim" });
await call("setup_state_machine", { tree_path: "Tree" });
await call("add_state", { tree_path: "Tree", name: "idle", animation: "idle" });
await call("add_state", { tree_path: "Tree", name: "run", animation: "run" });
await call("add_transition", { tree_path: "Tree", from: "idle", to: "run" });
await call("get_animation_tree_info", { tree_path: "Tree" });
// batch
await call("batch_add_nodes", { nodes: [
  { type: "Node3D", name: "Group" },
  { type: "MeshInstance3D", name: "M1", parent_path: "Group" },
  { type: "MeshInstance3D", name: "M2", parent_path: "Group" },
] });
await call("batch_set_properties", { updates: [
  { path: "Group/M1", properties: { visible: false } },
  { path: "Group/M2", properties: { visible: true } },
] });
await call("batch_get_properties", { paths: ["Group/M1", "Group/M2"], names: ["visible"] });
// profiling + export
await call("get_performance_monitors", {});
await call("list_export_presets", {});
await call("save_scene", {});

console.error(`\n[smoke3] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
