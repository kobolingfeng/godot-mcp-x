// Correctness check for the cached changed_properties: still returns ONLY changed
// props, defaults omitted, value correct, and stable across warm-cache calls.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke10] waiting for editor…");
const t0 = Date.now();
while (!godot.isConnected("editor") && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected("editor")) { console.error("[smoke10] timeout"); process.exit(2); }
console.error(`[smoke10] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
const cmd = (m, p) => godot.sendCommand(m, p || {});
function check(c, l) { console.log(`${c ? "PASS" : "FAIL"} ${l}`); c ? pass++ : fail++; }

await cmd("create_scene", { path: "res://__smoke10.tscn", root_type: "Node3D", root_name: "World" });
await cmd("add_node", { type: "Node3D", name: "N" });
await cmd("set_node_property", { path: "N", property: "position", value: "Vector3(1,2,3)" });
const p1 = (await cmd("get_node_properties", { path: "N" })).properties;
// Node3D stores 'transform' (position is a setter into it) → changed prop is transform.
check(typeof p1.transform === "string" && p1.transform.includes("1, 2, 3"), `changed transform reflects position → transform=${p1.transform}`);
check(!("visible" in p1), `default 'visible' omitted (keys: ${Object.keys(p1).join(",")})`);
// warm-cache second call must match
const p2 = (await cmd("get_node_properties", { path: "N" })).properties;
check(JSON.stringify(p1) === JSON.stringify(p2), "stable across warm-cache call");
// include_defaults must still expand to the full set
const full = (await cmd("get_node_properties", { path: "N", include_defaults: true })).properties;
check(Object.keys(full).length > Object.keys(p1).length && "visible" in full, `include_defaults expands (${Object.keys(full).length} props)`);

console.error(`\n[smoke10] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
