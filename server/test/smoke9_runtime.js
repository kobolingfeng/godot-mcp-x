// Smoke test: runtime did-you-mean (node path / property / method suggestions).
import { GodotConnection } from "../build/core/connection.js";

const godot = new GodotConnection();
await godot.connect();
console.error("[smoke9] waiting for the game (runtime)…");
const t0 = Date.now();
let info = null;
while (Date.now() - t0 < 25000) {
  try { info = await godot.sendCommand("get_game_info", {}, "runtime"); break; }
  catch { await new Promise((r) => setTimeout(r, 300)); }
}
if (!info) { console.error("[smoke9] runtime never connected"); process.exit(2); }
console.error(`[smoke9] runtime connected in ${Date.now() - t0}ms\n`);

let pass = 0, fail = 0;
async function expectSuggest(m, p, expected) {
  try {
    await godot.sendCommand(m, p || {}, "runtime");
    console.log(`UNEXPECTED-PASS ${m}`); fail++;
  } catch (e) {
    const sugg = (e.data && e.data.suggestions) || [];
    const ok = sugg.includes(expected);
    console.log(`${ok ? "PASS" : "FAIL"} ${m}: "${e.message}" → ${JSON.stringify(sugg)}`);
    ok ? pass++ : fail++;
  }
}

await expectSuggest("get_game_node_properties", { path: "Spiner" }, "Spinner");
await expectSuggest("set_game_node_property", { path: ".", property: "tiks", value: 1 }, "ticks");
await expectSuggest("call_game_method", { path: ".", method: "get_chil_count" }, "get_child_count");

console.error(`\n[smoke9] ${pass} passed, ${fail} failed`);
godot.disconnect();
process.exit(fail === 0 ? 0 : 1);
