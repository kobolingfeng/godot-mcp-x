#!/usr/bin/env node
/**
 * godot-mcp-x CLI — drive Godot without an MCP client.
 *
 *   node build/cli.js list [filter]          list tools
 *   node build/cli.js <tool> --help          show a tool's parameters
 *   node build/cli.js <tool> --k v --k2 v2   run a tool and print the result
 *
 * Values are auto-typed: numbers/true/false/null and JSON {...}/[...] are parsed,
 * everything else stays a string. Reuses the exact same tool handlers + transport
 * as the MCP server.
 */
import { z, type ZodTypeAny } from "zod";
import { GodotConnection } from "./core/connection.js";
import { allTools, selectTools } from "./tools/groups.js";
import { runDaemon, daemonHealth, ipcRequest } from "./daemon.js";
import { runDoctor, runSetup } from "./setup.js";
import { listClients, installClient, installAll } from "./clients.js";

const argv = process.argv.slice(2);

function listTools(pool: typeof allTools, filter?: string, mode?: string): void {
  const tools = filter ? pool.filter((t) => t.name.includes(filter)) : pool;
  const label = mode ? ` (mode: ${mode})` : "";
  console.log(`godot-mcp-x CLI — ${tools.length}/${allTools.length} tools${label}\n`);
  for (const t of tools) console.log(`  ${t.name.padEnd(28)} ${t.description.split(/\. |\.$/)[0]}`);
  console.log(`\nRun 'godot-x <tool> --help' for parameters.`);
}

function toolHelp(tool: (typeof allTools)[number]): void {
  console.log(`${tool.name} — ${tool.description}`);
  const shape = (tool.schema ?? {}) as Record<string, ZodTypeAny>;
  const keys = Object.keys(shape);
  if (!keys.length) {
    console.log("  (no parameters)");
    return;
  }
  console.log("Parameters:");
  for (const k of keys) {
    const f = shape[k];
    const optional = f.isOptional?.() ? "optional" : "required";
    console.log(`  --${k.padEnd(20)} [${optional}] ${f.description ?? ""}`);
  }
}

function parseVal(s: string): unknown {
  if (/^-?\d+(\.\d+)?$/.test(s)) return Number(s);
  if (s === "true") return true;
  if (s === "false") return false;
  if (s === "null") return null;
  if ((s.startsWith("{") && s.endsWith("}")) || (s.startsWith("[") && s.endsWith("]"))) {
    try {
      return JSON.parse(s);
    } catch {
      /* keep as string */
    }
  }
  return s;
}

async function main(): Promise<void> {
  const first = argv[0];

  if (first === "daemon") {
    await runDaemon();
    return; // long-lived; keeps the process alive
  }
  if (first === "status" || first === "ping-daemon") {
    const h = await daemonHealth();
    console.log(JSON.stringify(h ? { daemon: true, ...h } : { daemon: false }, null, 2));
    return;
  }
  if (first === "stop-daemon") {
    try {
      await ipcRequest("POST", "/shutdown", {});
      console.log("daemon stopped");
    } catch {
      console.log("no daemon running");
    }
    return;
  }
  if (first === "doctor") {
    const pi = argv.indexOf("--project");
    await runDoctor(pi >= 0 ? argv[pi + 1] : undefined);
    return;
  }
  if (first === "setup") {
    const pi = argv.indexOf("--project");
    runSetup(pi >= 0 ? argv[pi + 1] : undefined);
    return;
  }
  if (first === "install" || first === "install-client") {
    const flag = (f: string): string | undefined => {
      const i = argv.indexOf(f);
      return i >= 0 ? argv[i + 1] : undefined;
    };
    const cwd = process.cwd();
    const sub = argv[1] && !argv[1].startsWith("--") ? argv[1] : undefined;
    if (!sub || sub === "list" || argv.includes("--list")) {
      console.log("MCP clients (● configured · ○ present · ‧ not found):\n");
      for (const c of listClients(cwd)) {
        console.log(`  ${c.configured ? "●" : c.exists ? "○" : "‧"} ${c.id.padEnd(15)} ${c.file}`);
      }
      console.log("\nUsage: godot-x install <client|all> [--scope user|project] [--name NAME] [--mode MODE]");
      return;
    }
    const opts = { scope: (flag("--scope") as "user" | "project") ?? "user", name: flag("--name"), mode: flag("--mode"), cwd };
    const results = sub === "all" ? installAll(opts) : [installClient(sub, opts)];
    for (const r of results) console.log(`${r.ok ? "✓" : "·"} ${r.id.padEnd(15)} ${r.msg}${r.ok ? "  → " + r.file : ""}`);
    return;
  }

  if (!first || ["list", "-l", "--list", "-h", "--help"].includes(first)) {
    const mi = argv.indexOf("--mode");
    const mode = mi >= 0 ? argv[mi + 1] : undefined;
    const filter = argv[1] && !argv[1].startsWith("--") ? argv[1] : undefined;
    listTools(mode ? selectTools({ mode }) : allTools, filter, mode);
    return;
  }

  const tool = allTools.find((t) => t.name === first);
  if (!tool) {
    console.error(`Unknown tool: ${first}\nRun 'list' to see all ${allTools.length} tools.`);
    process.exit(1);
  }

  const raw: Record<string, unknown> = {};
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--help" || a === "-h") {
      toolHelp(tool);
      return;
    }
    if (!a.startsWith("--")) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next === undefined || (next.startsWith("--") && !/^--?\d/.test(next))) {
      raw[key] = true;
    } else {
      raw[key] = parseVal(next);
      i++;
    }
  }

  let args: Record<string, unknown> = raw;
  if (tool.schema) {
    const parsed = z.object(tool.schema).safeParse(raw);
    if (!parsed.success) {
      console.error(`Invalid arguments for '${tool.name}':`);
      for (const issue of parsed.error.issues) {
        console.error(`  ${issue.path.join(".") || "(root)"}: ${issue.message}`);
      }
      console.error(`Run 'godot-x ${tool.name} --help'.`);
      process.exit(1);
    }
    args = parsed.data as Record<string, unknown>;
  }

  // Prefer a running daemon: warm connection, no WS rebind / reconnect wait.
  if (await daemonHealth()) {
    try {
      const r = await ipcRequest("POST", "/call", { tool: tool.name, args }, 60000);
      if (r.json?.ok) {
        const result = r.json.result;
        console.log(typeof result === "string" ? result : JSON.stringify(result, null, 2));
        process.exit(0);
      }
      console.error("Error:", r.json?.error ?? `daemon returned status ${r.status}`);
      process.exit(1);
    } catch (e) {
      console.error(`[daemon call failed: ${(e as Error).message}; falling back to one-shot]`);
    }
  }

  const fixedPort = process.env.GODOT_MCP_X_PORT;
  const godot = new GodotConnection(parseInt(fixedPort || "6605", 10), !!fixedPort);
  await godot.connect();

  // Wait for EITHER the editor or a running game (runtime) to dial in, so
  // runtime-only tools (get_game_screenshot, …) work against a standalone game
  // with no editor open.
  const t0 = Date.now();
  while (!godot.isConnected("editor") && !godot.isConnected("runtime") && Date.now() - t0 < 15000) {
    await new Promise((r) => setTimeout(r, 200));
  }
  if (!godot.isConnected("editor") && !godot.isConnected("runtime")) {
    console.error(
      "No Godot connected. Open the editor with the godot_mcp_x plugin enabled, " +
        "or run a game that autoloads McpXRuntime, then retry.",
    );
    godot.disconnect();
    process.exit(2);
  }

  try {
    const result = await tool.handler(args, { godot });
    console.log(typeof result === "string" ? result : JSON.stringify(result, null, 2));
    godot.disconnect();
    process.exit(0);
  } catch (e) {
    console.error("Error:", e instanceof Error ? e.message : String(e));
    godot.disconnect();
    process.exit(1);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
