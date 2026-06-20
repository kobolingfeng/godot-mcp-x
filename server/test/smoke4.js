// Smoke test for niche groups: gridmap, skeleton.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke4] waiting for editor…");
const t0 = Date.now();
while (!godot.isConnected("editor") && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected("editor")) { console.error("[smoke4] timeout"); process.exit(2); }
console.error(`[smoke4] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function call(m, p) {
  try {
    const r = await godot.sendCommand(m, p || {});
    const s = JSON.stringify(r);
    console.log(`PASS ${m}: ${s.length > 200 ? s.slice(0, 200) + "…" : s}`);
    pass++; return r;
  } catch (e) { console.log(`FAIL ${m}: ${e.message}`); fail++; return null; }
}

await call("create_scene", { path: "res://__smoke4.tscn", root_type: "Node3D", root_name: "World" });
// gridmap
await call("add_gridmap", { name: "Map", cell_size: "Vector3(2,2,2)" });
await call("gridmap_set_cell", { path: "Map", x: 0, y: 0, z: 0, item: 0 });
await call("gridmap_set_cell", { path: "Map", x: 1, y: 0, z: 0, item: 0 });
await call("gridmap_get_cell", { path: "Map", x: 0, y: 0, z: 0 });
await call("gridmap_get_used_cells", { path: "Map" });
await call("gridmap_get_info", { path: "Map" });
await call("gridmap_clear", { path: "Map" });
// skeleton
await call("add_node", { type: "Skeleton3D", name: "Skel" });
await call("add_bone", { path: "Skel", name: "root" });
await call("add_bone", { path: "Skel", name: "spine", parent: "root" });
await call("list_bones", { path: "Skel" });
await call("set_bone_pose", { path: "Skel", bone: "spine", position: "Vector3(0,1,0)", rotation: "Vector3(0,0,0)" });
await call("add_bone_attachment", { path: "Skel", bone: "spine", name: "WeaponMount" });
await call("get_skeleton_info", { path: "Skel" });
await call("reset_bone_poses", { path: "Skel" });
await call("save_scene", {});

console.error(`\n[smoke4] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
