// Smoke test: "did you mean…?" suggestions on typo'd type/property/method names.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke7] waiting for editor…");
const t0 = Date.now();
while (!godot.isConnected("editor") && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected("editor")) { console.error("[smoke7] timeout"); process.exit(2); }
console.error(`[smoke7] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function call(m, p) {
  try { const r = await godot.sendCommand(m, p || {}); console.log(`PASS ${m}: ${JSON.stringify(r).slice(0, 120)}`); pass++; return r; }
  catch (e) { console.log(`FAIL ${m}: ${e.message}`); fail++; return null; }
}
async function expectSuggest(m, p, expected) {
  try {
    await godot.sendCommand(m, p || {});
    console.log(`UNEXPECTED-PASS ${m}`); fail++;
  } catch (e) {
    const sugg = (e.data && e.data.suggestions) || [];
    const ok = sugg.includes(expected);
    console.log(`${ok ? "PASS" : "FAIL"} ${m}: "${e.message}" → ${JSON.stringify(sugg)}`);
    ok ? pass++ : fail++;
  }
}

await call("create_scene", { path: "res://__smoke7.tscn", root_type: "Node3D", root_name: "World" });
await expectSuggest("add_node", { type: "CharcterBody3D", name: "X" }, "CharacterBody3D");
await expectSuggest("set_node_property", { path: ".", property: "positon", value: "Vector3(1,0,0)" }, "position");
await expectSuggest("call_node_method", { path: ".", method: "get_chil_count" }, "get_child_count");
// a correct call still works
await call("set_node_property", { path: ".", property: "position", value: "Vector3(1,2,3)" });

console.error(`\n[smoke7] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
