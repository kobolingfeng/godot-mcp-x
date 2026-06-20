// Smoke test: UndoRedo integration — add/set/delete are undoable & redoable.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke8] waiting for editor…");
const t0 = Date.now();
while (!godot.isConnected("editor") && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected("editor")) { console.error("[smoke8] timeout"); process.exit(2); }
console.error(`[smoke8] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
function check(cond, label) { console.log(`${cond ? "PASS" : "FAIL"} ${label}`); cond ? pass++ : fail++; }
const cmd = (m, p) => godot.sendCommand(m, p || {});
const has = (o, s) => JSON.stringify(o).includes(s);

await cmd("create_scene", { path: "res://__smoke8.tscn", root_type: "Node3D", root_name: "World" });
await cmd("add_node", { type: "Node3D", name: "Mover" });
check(has(await cmd("get_scene_tree", {}), "Mover"), "Mover present after add");

const u1 = await cmd("undo", {});
check(u1.undone === true, `undo add → ${JSON.stringify(u1)}`);
check(!has(await cmd("get_scene_tree", {}), "Mover"), "Mover gone after undo");

const r1 = await cmd("redo", {});
check(r1.redone === true, `redo add → ${JSON.stringify(r1)}`);
check(has(await cmd("get_scene_tree", {}), "Mover"), "Mover back after redo");

await cmd("set_node_property", { path: "Mover", property: "position", value: "Vector3(5,0,0)" });
let props = (await cmd("get_node_properties", { path: "Mover", names: ["position"] })).properties;
check(props.position === "Vector3(5, 0, 0)", `position set → ${props.position}`);
await cmd("undo", {});
props = (await cmd("get_node_properties", { path: "Mover", names: ["position"] })).properties;
check(props.position === "Vector3(0, 0, 0)", `position reverted by undo → ${props.position}`);

await cmd("delete_node", { path: "Mover" });
check(!has(await cmd("get_scene_tree", {}), "Mover"), "Mover deleted");
await cmd("undo", {});
check(has(await cmd("get_scene_tree", {}), "Mover"), "Mover restored after undo-delete");

await cmd("add_node", { type: "Node3D", name: "Holder" });
await cmd("move_node", { path: "Mover", new_parent_path: "Holder" });
check(has(await cmd("get_scene_tree", {}), "Holder/Mover"), "Mover moved under Holder");
await cmd("undo", {});
check(!has(await cmd("get_scene_tree", {}), "Holder/Mover"), "move undone");

await cmd("save_scene", {});
console.error(`\n[smoke8] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
