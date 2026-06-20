import { WebSocketServer, WebSocket } from "ws";
import { randomUUID } from "crypto";
import { JsonRpcRequest, PendingRequest, GodotTarget } from "../util/types.js";
import { GodotConnectionError, GodotCommandError, TimeoutError } from "../util/errors.js";

/**
 * Transport between the MCP server (this process) and Godot.
 *
 * Two kinds of Godot client can connect to the same port and are tracked
 * separately, identified by a "hello" message on connect:
 *   - "editor"  — the editor plugin (always present)
 *   - "runtime" — the RUNNING GAME's autoload (present only while playing)
 *
 * This replaces the original tool's per-frame file polling for runtime
 * inspection: the game dials the server directly over WebSocket. Editor tools
 * route to the editor connection, runtime tools to the game connection.
 *
 * Topology is reversed (THIS process is the WS server) so multiple sessions can
 * each own a port; ports 6605-6609 avoid godot-mcp-pro's 6505-6514.
 */
const BASE_PORT = 6605;
const MAX_PORT = 6609;
const COMMAND_TIMEOUT_MS = 30000;
const HEARTBEAT_INTERVAL_MS = 10000;
const HEARTBEAT_TIMEOUT_MS = HEARTBEAT_INTERVAL_MS * 3;
const TCP_KEEPALIVE_DELAY_MS = 5000;

interface RoledSocket extends WebSocket {
  __role?: GodotTarget;
}

export class GodotConnection {
  private wss: WebSocketServer | null = null;
  private editorClient: RoledSocket | null = null;
  private runtimeClient: RoledSocket | null = null;
  private port: number;
  private fixedPort: boolean;
  private basePort: number;
  private maxPort: number;
  private pendingRequests: Map<string, PendingRequest> = new Map();
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private lastPong: Record<GodotTarget, number> = { editor: 0, runtime: 0 };
  private connSeen: Record<GodotTarget, number> = { editor: 0, runtime: 0 };
  private concurrentReplaces = 0;
  private keepPolicy: "first" | "last";

  constructor(
    port: number = BASE_PORT,
    fixedPort = false,
    options: { basePort?: number; maxPort?: number; keep?: "first" | "last" } = {}
  ) {
    this.port = port;
    this.fixedPort = fixedPort;
    this.basePort = options.basePort ?? BASE_PORT;
    this.maxPort = options.maxPort ?? MAX_PORT;
    this.keepPolicy = options.keep ?? "last";
  }

  async connect(): Promise<void> {
    if (this.wss) return;
    const candidates = this.fixedPort
      ? [this.port]
      : Array.from({ length: this.maxPort - this.basePort + 1 }, (_, i) => this.basePort + i);

    let lastError: Error | null = null;
    for (const port of candidates) {
      try {
        const wss = await this.bind(port);
        this.wss = wss;
        this.port = port;
        this.attachConnectionHandler(wss);
        console.error(`[MCP-X] WebSocket server listening on ws://127.0.0.1:${port}`);
        return;
      } catch (err) {
        lastError = err as Error;
        if ((err as NodeJS.ErrnoException).code !== "EADDRINUSE") {
          console.error(`[MCP-X] Bind failed on port ${port}: ${(err as Error).message}`);
        }
      }
    }
    const range = this.fixedPort ? String(this.port) : `${this.basePort}-${this.maxPort}`;
    throw new GodotConnectionError(
      `Failed to bind WebSocket server on port range ${range}. Last error: ${lastError?.message ?? "unknown"}.`
    );
  }

  private bind(port: number): Promise<WebSocketServer> {
    return new Promise<WebSocketServer>((resolve, reject) => {
      const wss = new WebSocketServer({ port, host: "127.0.0.1" });
      const onError = (err: Error) => {
        wss.off("listening", onListening);
        wss.close();
        reject(err);
      };
      const onListening = () => {
        wss.off("error", onError);
        wss.on("error", (err: Error) => console.error("[MCP-X] WebSocket server error:", err.message));
        resolve(wss);
      };
      wss.once("error", onError);
      wss.once("listening", onListening);
    });
  }

  private attachConnectionHandler(wss: WebSocketServer): void {
    wss.on("connection", (ws: RoledSocket) => {
      const sock = (ws as unknown as { _socket?: { setKeepAlive?: (e: boolean, d: number) => void } })._socket;
      sock?.setKeepAlive?.(true, TCP_KEEPALIVE_DELAY_MS);
      console.error("[MCP-X] Godot client connected (awaiting hello)");
      ws.on("message", (data: Buffer) => this.handleMessage(ws, data.toString()));
      ws.on("close", () => this.onClose(ws));
      ws.on("error", (err: Error) => console.error("[MCP-X] WebSocket error:", err.message));
    });
  }

  private assignRole(ws: RoledSocket, role: GodotTarget): void {
    ws.__role = role;
    this.connSeen[role]++;
    const existing = role === "runtime" ? this.runtimeClient : this.editorClient;
    if (existing && existing !== ws) {
      const concurrent = existing.readyState === WebSocket.OPEN;
      if (concurrent) {
        this.concurrentReplaces++;
        if (this.keepPolicy === "first") {
          console.error(
            `[MCP-X] ⚠ keep=first: a ${role} already owns port ${this.port}; rejecting the newcomer. ` +
              `Close the extra Godot instance.`,
          );
          ws.__role = undefined;
          ws.close(1000, `keep=first: port already owned by another ${role}`);
          return;
        }
        console.error(
          `[MCP-X] ⚠ TWO ${role} clients connected at once on port ${this.port}. Using the newest ` +
            `and dropping the previous — but multiple Godot instances open on this project ALL dial ` +
            `this port, and the stale state that results looks like a bug. Keep exactly ONE ${role} ` +
            `(close the others, or run the daemon with --keep first).`,
        );
      }
      existing.close(1000, "Replaced");
    }
    if (role === "runtime") this.runtimeClient = ws;
    else this.editorClient = ws;
    this.lastPong[role] = Date.now();
    console.error(`[MCP-X] ${role === "runtime" ? "Game (runtime)" : "Editor"} connected`);
    if (!this.heartbeatTimer) this.startHeartbeat();
  }

  private onClose(ws: RoledSocket): void {
    if (this.editorClient === ws) {
      this.editorClient = null;
      this.rejectPending("editor", new GodotConnectionError("Editor disconnected"));
      console.error("[MCP-X] Editor disconnected");
    }
    if (this.runtimeClient === ws) {
      this.runtimeClient = null;
      this.rejectPending("runtime", new GodotConnectionError("Game stopped (runtime disconnected)"));
      console.error("[MCP-X] Game (runtime) disconnected");
    }
    if (!this.editorClient && !this.runtimeClient) this.stopHeartbeat();
  }

  disconnect(): void {
    this.stopHeartbeat();
    this.editorClient?.close(1000, "Server shutting down");
    this.runtimeClient?.close(1000, "Server shutting down");
    this.editorClient = null;
    this.runtimeClient = null;
    if (this.wss) {
      this.wss.close();
      this.wss = null;
    }
    this.rejectAllPending(new GodotConnectionError("Server shut down"));
  }

  isConnected(target: GodotTarget = "editor"): boolean {
    const c = target === "runtime" ? this.runtimeClient : this.editorClient;
    return c?.readyState === WebSocket.OPEN;
  }

  getPort(): number {
    return this.port;
  }

  /** Connection stats for surfacing multi-instance situations to the user. */
  getStats(): {
    ws_port: number;
    editor: boolean;
    runtime: boolean;
    editor_seen: number;
    runtime_seen: number;
    concurrent_replaces: number;
  } {
    return {
      ws_port: this.port,
      editor: this.isConnected("editor"),
      runtime: this.isConnected("runtime"),
      editor_seen: this.connSeen.editor,
      runtime_seen: this.connSeen.runtime,
      concurrent_replaces: this.concurrentReplaces,
    };
  }

  async sendCommand(
    method: string,
    params: Record<string, unknown> = {},
    target: GodotTarget = "editor"
  ): Promise<unknown> {
    const client = target === "runtime" ? this.runtimeClient : this.editorClient;
    if (!client || client.readyState !== WebSocket.OPEN) {
      throw new GodotConnectionError(
        target === "runtime"
          ? "The game is not running. Call play_scene first (runtime tools need a live game)."
          : "Godot editor is not connected. Enable the godot_mcp_x plugin and keep the editor open."
      );
    }

    const id = randomUUID();
    const request: JsonRpcRequest = { jsonrpc: "2.0", method, params, id };
    return new Promise<unknown>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new TimeoutError(method, COMMAND_TIMEOUT_MS));
      }, COMMAND_TIMEOUT_MS);
      this.pendingRequests.set(id, { resolve, reject, timer, target });
      client.send(JSON.stringify(request));
    });
  }

  private handleMessage(ws: RoledSocket, data: string): void {
    let msg: { method?: string; id?: string | null; result?: unknown; error?: { code: number; message: string; data?: Record<string, unknown> }; params?: { role?: string } };
    try {
      msg = JSON.parse(data);
    } catch {
      console.error("[MCP-X] Failed to parse message from Godot:", data.slice(0, 200));
      return;
    }

    if (msg.method === "hello") {
      this.assignRole(ws, msg.params?.role === "runtime" ? "runtime" : "editor");
      return;
    }
    if (msg.method === "pong") {
      if (ws.__role) this.lastPong[ws.__role] = Date.now();
      return;
    }
    if (msg.method === "ping") {
      if (ws.__role) this.lastPong[ws.__role] = Date.now();
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ jsonrpc: "2.0", method: "pong", params: {} }));
      }
      return;
    }

    if (!msg.id) return;
    const pending = this.pendingRequests.get(msg.id);
    if (!pending) return;
    clearTimeout(pending.timer);
    this.pendingRequests.delete(msg.id);
    if (msg.error) {
      pending.reject(new GodotCommandError(msg.error.code, msg.error.message, msg.error.data));
    } else {
      pending.resolve(msg.result);
    }
  }

  private rejectPending(target: GodotTarget, error: Error): void {
    for (const [id, p] of this.pendingRequests) {
      if (p.target === target) {
        clearTimeout(p.timer);
        p.reject(error);
        this.pendingRequests.delete(id);
      }
    }
  }

  private rejectAllPending(error: Error): void {
    for (const [, p] of this.pendingRequests) {
      clearTimeout(p.timer);
      p.reject(error);
    }
    this.pendingRequests.clear();
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      for (const role of ["editor", "runtime"] as GodotTarget[]) {
        const client = role === "runtime" ? this.runtimeClient : this.editorClient;
        if (!client || client.readyState !== WebSocket.OPEN) continue;
        if (Date.now() - this.lastPong[role] > HEARTBEAT_TIMEOUT_MS) {
          console.error(`[MCP-X] Heartbeat timeout (${role}) — terminating`);
          const dead = client;
          if (role === "runtime") this.runtimeClient = null;
          else this.editorClient = null;
          this.rejectPending(role, new GodotConnectionError(`Heartbeat timeout — ${role} lost`));
          dead.terminate();
          continue;
        }
        client.send(JSON.stringify({ jsonrpc: "2.0", method: "ping", params: {} }));
      }
      if (!this.editorClient && !this.runtimeClient) this.stopHeartbeat();
    }, HEARTBEAT_INTERVAL_MS);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }
}
