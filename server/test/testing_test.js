// Runtime test for the testing/assertion tools (game runs main.tscn directly).
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[test2] waiting for game…");
const t0 = Date.now();
let ready = false;
while (Date.now() - t0 < 25000) {
  try { await godot.sendCommand("get_game_info", {}, "runtime"); ready = true; break; }
  catch { await new Promise((r) => setTimeout(r, 300)); }
}
if (!ready) { console.error("[test2] runtime never connected"); process.exit(2); }
console.error(`[test2] runtime connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function call(m, p) {
  try {
    const r = await godot.sendCommand(m, p || {}, "runtime");
    const s = JSON.stringify(r);
    console.log(`PASS ${m}: ${s.length > 260 ? s.slice(0, 260) + "…" : s}`);
    pass++; return r;
  } catch (e) { console.log(`FAIL ${m}: ${e.message}`); fail++; return null; }
}

await call("wait_for_node", { path: "Spinner", timeout: 3 });
await call("assert_node_exists", { path: "Spinner" });
await call("assert_property", { path: ".", property: "ticks", op: "gt", expected: 0 });
await call("monitor_property", { path: ".", property: "ticks", duration: 0.4, samples: 4 });
await call("record_frames", { count: 2, interval: 0.1 });
await call("run_test_scenario", {
  name: "demo_regression",
  steps: [
    { type: "wait", seconds: 0.2 },
    { type: "assert_node", path: "Camera3D" },
    { type: "assert_property", path: ".", property: "ticks", op: "gt", expected: 0 },
    { type: "assert_property", path: ".", property: "ticks", op: "eq", expected: 999999 }, // intentional FAIL
    { type: "key", key: "Space", duration: 0.05 },
  ],
});
await call("get_test_report", {});

console.error(`\n[test2] ${pass} tool calls ok, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
