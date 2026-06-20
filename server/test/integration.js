/**
 * Local integration harness — codifies the manual "drive a live game" check.
 * NOT part of CI (needs a Godot binary + a running editor/game).
 *
 *   1. cd server && npm run build
 *   2. open the editor on a project with the plugin enabled, OR run a game that
 *      autoloads McpXRuntime (e.g. the vampire_survivors demo)
 *   3. node test/integration.js
 *
 * It starts a daemon, waits for a connection, exercises core tools, asserts they
 * succeed, and shuts the daemon down. Exit code 0 = all passed.
 */
import http from "http";
import { spawn } from "child_process";

const IPC = parseInt(process.env.GODOT_MCP_X_DAEMON_PORT || "6610", 10);

function req(method, path, body) {
  return new Promise((resolve, reject) => {
    const data = body !== undefined ? JSON.stringify(body) : undefined;
    const r = http.request(
      { host: "127.0.0.1", port: IPC, path, method, headers: data ? { "content-type": "application/json", "content-length": Buffer.byteLength(data) } : {} },
      (res) => {
        let raw = "";
        res.on("data", (c) => (raw += c));
        res.on("end", () => resolve({ status: res.statusCode, json: raw ? JSON.parse(raw) : null }));
      },
    );
    r.on("error", reject);
    r.setTimeout(8000, () => r.destroy(new Error("timeout")));
    if (data) r.write(data);
    r.end();
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let passed = 0,
  failed = 0;
function check(name, ok, extra = "") {
  console.log(`${ok ? "✓" : "✗"} ${name}${extra ? "  " + extra : ""}`);
  ok ? passed++ : failed++;
}

async function main() {
  const daemon = spawn("node", ["build/cli.js", "daemon"], { stdio: "inherit" });
  try {
    // wait for daemon + a Godot connection
    let health = null;
    for (let i = 0; i < 30; i++) {
      await sleep(1000);
      try {
        health = (await req("GET", "/health")).json;
      } catch {
        continue;
      }
      if (health?.editor || health?.runtime) break;
      if (i === 2) console.log("…waiting for an editor or game to connect (open one now)…");
    }
    check("daemon up", !!health);
    check("editor or game connected", !!(health?.editor || health?.runtime), JSON.stringify(health));

    if (health?.runtime) {
      const info = await req("POST", "/call", { tool: "get_game_info", args: {} });
      check("get_game_info", info.json?.ok && info.json.result?.fps !== undefined);
      const shot = await req("POST", "/call", { tool: "get_game_screenshot", args: { save_path: "user://_it.png" } });
      check("get_game_screenshot", shot.json?.ok && !!shot.json.result?.os_path);
      const ev = await req("POST", "/call", { tool: "execute_game_script", args: { code: '_mcp_print("ok")' } });
      check("execute_game_script", ev.json?.ok && ev.json.result?.output?.[0] === "ok");
    } else if (health?.editor) {
      const tree = await req("POST", "/call", { tool: "get_current_scene", args: {} });
      check("get_current_scene", tree.json?.ok);
    }
  } finally {
    try {
      await req("POST", "/shutdown", {});
    } catch {
      /* ignore */
    }
    daemon.kill();
  }
  console.log(`\n${failed === 0 ? "PASS" : "FAIL"} — ${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
