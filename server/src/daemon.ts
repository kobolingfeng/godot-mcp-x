/**
 * godot-mcp-x daemon — keeps ONE persistent GodotConnection warm and serves tool
 * calls over local HTTP, so the CLI can fire many commands without rebinding the
 * WebSocket and waiting for Godot to reconnect each time (the #1 CLI friction).
 *
 *   godot-x daemon            # start (long-lived; binds WS 6605-6609 + IPC 6610)
 *   godot-x <tool> ...        # auto-routes to the daemon if one is running
 *   godot-x status            # show daemon + connection state
 *   godot-x stop-daemon       # stop it
 *
 * The client helpers (ipcRequest/daemonHealth) live here too so the port lives
 * in one place; cli.ts imports them.
 */
import http from "http";
import { GodotConnection } from "./core/connection.js";
import { allTools } from "./tools/groups.js";
import { formatErrorForMcp } from "./util/errors.js";

export const DEFAULT_IPC_PORT = 6610;

export function ipcPort(): number {
  return parseInt(process.env.GODOT_MCP_X_DAEMON_PORT || String(DEFAULT_IPC_PORT), 10);
}

/** Minimal localhost HTTP+JSON request used by the CLI client. */
export function ipcRequest(
  method: string,
  path: string,
  body?: unknown,
  timeoutMs = 4000,
): Promise<{ status: number; json: any }> {
  return new Promise((resolve, reject) => {
    const data = body !== undefined ? JSON.stringify(body) : undefined;
    const req = http.request(
      {
        host: "127.0.0.1",
        port: ipcPort(),
        path,
        method,
        headers: data ? { "content-type": "application/json", "content-length": Buffer.byteLength(data) } : {},
      },
      (res) => {
        let raw = "";
        res.on("data", (c) => (raw += c));
        res.on("end", () => {
          try {
            resolve({ status: res.statusCode ?? 0, json: raw ? JSON.parse(raw) : null });
          } catch {
            resolve({ status: res.statusCode ?? 0, json: null });
          }
        });
      },
    );
    req.on("error", reject);
    req.setTimeout(timeoutMs, () => req.destroy(new Error("timeout")));
    if (data) req.write(data);
    req.end();
  });
}

/** Returns daemon health, or null if no daemon is reachable. */
export async function daemonHealth(): Promise<{
  ws_port: number;
  editor: boolean;
  runtime: boolean;
  editor_seen?: number;
  runtime_seen?: number;
  concurrent_replaces: number;
} | null> {
  try {
    const r = await ipcRequest("GET", "/health", undefined, 600);
    return r.status === 200 && r.json?.ok ? r.json : null;
  } catch {
    return null;
  }
}

export async function runDaemon(): Promise<void> {
  const wsPortEnv = process.env.GODOT_MCP_X_PORT;
  const keepIdx = process.argv.indexOf("--keep");
  const keep: "first" | "last" =
    (process.env.GODOT_MCP_X_KEEP || (keepIdx >= 0 ? process.argv[keepIdx + 1] : "")) === "first" ? "first" : "last";
  const godot = new GodotConnection(parseInt(wsPortEnv || "6605", 10), !!wsPortEnv, { keep });
  await godot.connect();
  const byName = new Map(allTools.map((t) => [t.name, t]));
  const port = ipcPort();

  let closing = false;
  const shutdown = (): void => {
    if (closing) return;
    closing = true;
    console.error("[MCP-X daemon] shutting down");
    server.close();
    godot.disconnect();
    setTimeout(() => process.exit(0), 120);
  };

  const server = http.createServer((req, res) => {
    const send = (code: number, obj: unknown): void => {
      res.writeHead(code, { "content-type": "application/json" });
      res.end(JSON.stringify(obj));
    };
    if (req.method === "GET" && req.url === "/health") {
      send(200, { ok: true, ...godot.getStats() });
    } else if (req.method === "POST" && req.url === "/shutdown") {
      send(200, { ok: true });
      shutdown();
    } else if (req.method === "POST" && req.url === "/call") {
      let raw = "";
      req.on("data", (c) => (raw += c));
      req.on("end", () => {
        void handleCall(raw, send);
      });
    } else {
      send(404, { ok: false, error: "Not found" });
    }
  });

  async function handleCall(raw: string, send: (c: number, o: unknown) => void): Promise<void> {
    let payload: { tool?: string; args?: Record<string, unknown> };
    try {
      payload = JSON.parse(raw || "{}");
    } catch {
      send(400, { ok: false, error: "Invalid JSON body" });
      return;
    }
    const tool = payload.tool ? byName.get(payload.tool) : undefined;
    if (!tool) {
      send(404, { ok: false, error: `Unknown tool: ${payload.tool}` });
      return;
    }
    try {
      const result = await tool.handler(payload.args ?? {}, { godot });
      send(200, { ok: true, result });
    } catch (e) {
      send(200, { ok: false, error: formatErrorForMcp(e) });
    }
  }

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
  server.on("error", (e: NodeJS.ErrnoException) => {
    if (e.code === "EADDRINUSE") {
      console.error(`[MCP-X daemon] IPC port ${port} already in use — a daemon may already be running.`);
      godot.disconnect();
      process.exit(3);
    } else {
      console.error("[MCP-X daemon] HTTP error:", e.message);
    }
  });
  server.listen(port, "127.0.0.1", () => {
    console.error(`[MCP-X daemon] ready — WS ws://127.0.0.1:${godot.getPort()}  IPC http://127.0.0.1:${port}`);
    console.error("[MCP-X daemon] connection kept warm; run 'godot-x <tool> ...' to use it, 'godot-x stop-daemon' to stop.");
  });
}
