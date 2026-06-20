// Smoke test: ui group (VirtualJoystick, anchor preset) + AreaLight3D via setup_light.
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke11] waiting for editor…");
const t0 = Date.now();
while (!godot.isConnected("editor") && Date.now() - t0 < 25000) await new Promise((r) => setTimeout(r, 200));
if (!godot.isConnected("editor")) { console.error("[smoke11] timeout"); process.exit(2); }
console.error(`[smoke11] connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
const cmd = (m, p) => godot.sendCommand(m, p || {});
function check(c, l) { console.log(`${c ? "PASS" : "FAIL"} ${l}`); c ? pass++ : fail++; }
async function expectSuggest(m, p, expected) {
  try { await cmd(m, p); console.log(`UNEXPECTED-PASS ${m}`); fail++; }
  catch (e) { const s = (e.data && e.data.suggestions) || []; check(s.includes(expected), `${m} suggests ${expected} → ${JSON.stringify(s)}`); }
}

await cmd("create_scene", { path: "res://__smoke11.tscn", root_type: "Node", root_name: "Root" });
await cmd("add_node", { type: "Control", name: "HUD" });
const ap = await cmd("set_anchor_preset", { path: "HUD", preset: "full_rect" });
check(ap.preset === "full_rect", `set_anchor_preset → ${JSON.stringify(ap)}`);
const vj = await cmd("add_virtual_joystick", { parent_path: "HUD", name: "Move", mode: "dynamic", actions: { left: "ui_left", right: "ui_right" } });
check(vj.path === "HUD/Move", `virtual joystick added → ${JSON.stringify(vj)}`);
const jp = (await cmd("get_node_properties", { path: "HUD/Move", names: ["joystick_mode", "action_left"] })).properties;
check(jp.joystick_mode === 1 && jp.action_left === "ui_left", `joystick configured → ${JSON.stringify(jp)}`);
// AreaLight3D
await cmd("add_node", { type: "Node3D", name: "World3D" });
const al = await cmd("setup_light", { parent_path: "World3D", kind: "area", name: "AreaL", area_size: "Vector2(3,2)", energy: 2 });
check(al.type === "AreaLight3D", `area light created → ${JSON.stringify(al)}`);
const lp = (await cmd("get_node_properties", { path: "World3D/AreaL", names: ["area_size", "light_energy"] })).properties;
check(lp.area_size === "Vector2(3, 2)" && lp.light_energy === 2, `area light props → ${JSON.stringify(lp)}`);
// suggestion on bad preset
await expectSuggest("set_anchor_preset", { path: "HUD", preset: "fullrect" }, "full_rect");
await cmd("save_scene", {});

console.error(`\n[smoke11] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
