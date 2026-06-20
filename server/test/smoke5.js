// Smoke test: describe_class signatures, call_node_method, filesystem lifecycle.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke5] waiting for editor…");
const t0 = Date.now();
while (!godot.isConnected("editor") && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected("editor")) { console.error("[smoke5] timeout"); process.exit(2); }
console.error(`[smoke5] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function call(m, p) {
  try {
    const r = await godot.sendCommand(m, p || {});
    const s = JSON.stringify(r);
    console.log(`PASS ${m}: ${s.length > 220 ? s.slice(0, 220) + "…" : s}`);
    pass++; return r;
  } catch (e) { console.log(`FAIL ${m}: ${e.message}`); fail++; return null; }
}

// describe_class with signatures
const dc = await call("describe_class", { name: "CharacterBody3D", members: ["methods"] });
const hasSig = dc && JSON.stringify(dc.methods || []).includes("-> ");
console.log(`  signatures present: ${hasSig}`);
// call_node_method
await call("create_scene", { path: "res://__smoke5.tscn", root_type: "Node", root_name: "World" });
await call("add_node", { type: "Node3D", name: "Mover" });
await call("call_node_method", { path: "Mover", method: "translate", args: ["Vector3(1,2,3)"] });
await call("get_node_properties", { path: "Mover", names: ["position"] });
await call("call_node_method", { path: ".", method: "get_child_count" });
// filesystem lifecycle
await call("create_folder", { path: "res://__fstest" });
await call("create_script", { path: "res://__fstest/a.gd", content: "extends Node\n" });
await call("duplicate_path", { from: "res://__fstest/a.gd", to: "res://__fstest/b.gd" });
await call("rename_path", { from: "res://__fstest/b.gd", to: "res://__fstest/c.gd" });
await call("delete_path", { path: "res://__fstest/c.gd" });
await call("delete_path", { path: "res://__fstest/a.gd" });
await call("delete_path", { path: "res://__fstest", recursive: true });

console.error(`\n[smoke5] ${pass} passed, ${fail} failed, signatures=${hasSig}`);
godot.disconnect();
process.exit(fail === 0 && hasSig ? 0 : 1);
