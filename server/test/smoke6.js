// Smoke test: Skeleton-IK / SkeletonModifier3D tools.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke6] waiting for editor…");
const t0 = Date.now();
while (!godot.isConnected("editor") && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected("editor")) { console.error("[smoke6] timeout"); process.exit(2); }
console.error(`[smoke6] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function call(m, p) {
  try {
    const r = await godot.sendCommand(m, p || {});
    console.log(`PASS ${m}: ${JSON.stringify(r).slice(0, 200)}`);
    pass++; return r;
  } catch (e) { console.log(`FAIL ${m}: ${e.message}`); fail++; return null; }
}
async function expectFail(m, p) {
  try { await godot.sendCommand(m, p || {}); console.log(`UNEXPECTED-PASS ${m}`); fail++; }
  catch (e) { console.log(`PASS(expected-fail) ${m}: ${e.message.slice(0, 70)}`); pass++; }
}

await call("create_scene", { path: "res://__smoke6.tscn", root_type: "Node3D", root_name: "World" });
await call("add_node", { type: "Skeleton3D", name: "Skel" });
await call("add_bone", { path: "Skel", name: "root" });
await call("add_bone", { path: "Skel", name: "upper", parent: "root" });
await call("add_bone", { path: "Skel", name: "lower", parent: "upper" });
await call("add_node", { type: "Node3D", name: "Target" });
await call("add_skeleton_modifier", { path: "Skel", type: "TwoBoneIK3D", name: "LegIK" });
await call("add_skeleton_modifier", { path: "Skel", type: "FABRIK3D", name: "ArmIK", properties: { active: true, influence: 0.8 } });
await call("setup_look_at_modifier", { path: "Skel", bone: "upper", target_path: "../../Target", name: "HeadLook" });
await call("list_skeleton_modifiers", { path: "Skel" });
await expectFail("add_skeleton_modifier", { path: "Skel", type: "Node3D" }); // not a modifier
await call("save_scene", {});

console.error(`\n[smoke6] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
