/**
 * One-command MCP-client configuration. `godot-x install <client>` merges the
 * godot-mcp-x server into a client's config file (preserving existing entries).
 * Each client has its own path + schema; the merge functions are pure (tested).
 */
import fs from "fs";
import path from "path";
import os from "os";
import { fileURLToPath } from "url";

/** Absolute path to the built MCP server entry (build/index.js, next to this file). */
export function serverEntry(): string {
  return path.resolve(path.dirname(fileURLToPath(import.meta.url)), "index.js");
}

const HOME = os.homedir();
const APPDATA = process.env.APPDATA || path.join(HOME, "AppData", "Roaming");
const PLAT = process.platform;

export type ClientFmt = "mcpServers" | "vscode" | "zed" | "codex";

export interface ClientDef {
  id: string;
  label: string;
  fmt: ClientFmt;
  /** Resolve the config file for a scope ('user' default; 'project' where supported). */
  file: (scope: "user" | "project", cwd: string) => string;
}

export const CLIENTS: ClientDef[] = [
  {
    id: "claude-code",
    label: "Claude Code",
    fmt: "mcpServers",
    file: (s, cwd) => (s === "project" ? path.join(cwd, ".mcp.json") : path.join(HOME, ".claude.json")),
  },
  {
    id: "claude-desktop",
    label: "Claude Desktop",
    fmt: "mcpServers",
    file: () =>
      PLAT === "win32"
        ? path.join(APPDATA, "Claude", "claude_desktop_config.json")
        : PLAT === "darwin"
          ? path.join(HOME, "Library", "Application Support", "Claude", "claude_desktop_config.json")
          : path.join(HOME, ".config", "Claude", "claude_desktop_config.json"),
  },
  {
    id: "cursor",
    label: "Cursor",
    fmt: "mcpServers",
    file: (s, cwd) => (s === "project" ? path.join(cwd, ".cursor", "mcp.json") : path.join(HOME, ".cursor", "mcp.json")),
  },
  {
    id: "windsurf",
    label: "Windsurf",
    fmt: "mcpServers",
    file: () => path.join(HOME, ".codeium", "windsurf", "mcp_config.json"),
  },
  {
    id: "vscode",
    label: "VS Code (Copilot)",
    fmt: "vscode",
    file: (_s, cwd) => path.join(cwd, ".vscode", "mcp.json"),
  },
  {
    id: "zed",
    label: "Zed",
    fmt: "zed",
    file: () => (PLAT === "win32" ? path.join(APPDATA, "Zed", "settings.json") : path.join(HOME, ".config", "zed", "settings.json")),
  },
  {
    id: "codex",
    label: "Codex",
    fmt: "codex",
    file: () => path.join(HOME, ".codex", "config.toml"),
  },
];

/** Merge the server entry into a client's existing config text. Pure → unit-tested. */
export function mergeConfig(fmt: ClientFmt, existing: string, name: string, command: string, args: string[]): string {
  if (fmt === "codex") {
    const header = `[mcp_servers.${name}]`;
    if (existing.includes(header)) return existing; // idempotent
    const block = `[mcp_servers.${name}]\ncommand = ${JSON.stringify(command)}\nargs = ${JSON.stringify(args)}\n`;
    return (existing.trim() ? existing.replace(/\s*$/, "") + "\n\n" : "") + block;
  }
  let obj: Record<string, any> = {};
  if (existing.trim()) {
    try {
      obj = JSON.parse(existing);
    } catch {
      obj = {};
    }
  }
  if (fmt === "vscode") {
    obj.servers = obj.servers ?? {};
    obj.servers[name] = { type: "stdio", command, args };
  } else if (fmt === "zed") {
    obj.context_servers = obj.context_servers ?? {};
    obj.context_servers[name] = { source: "custom", command, args, env: {} };
  } else {
    obj.mcpServers = obj.mcpServers ?? {};
    obj.mcpServers[name] = { command, args };
  }
  return JSON.stringify(obj, null, 2) + "\n";
}

export interface InstallOpts {
  scope?: "user" | "project";
  name?: string;
  mode?: string;
  cwd?: string;
}

export interface InstallResult {
  id: string;
  file: string;
  ok: boolean;
  msg: string;
}

export function installClient(id: string, opts: InstallOpts = {}): InstallResult {
  const def = CLIENTS.find((c) => c.id === id);
  if (!def) return { id, file: "", ok: false, msg: `unknown client (try: ${CLIENTS.map((c) => c.id).join(", ")})` };
  const cwd = opts.cwd ?? process.cwd();
  const file = def.file(opts.scope ?? "user", cwd);
  const name = opts.name ?? "godot-mcp-x";
  const args = opts.mode ? [serverEntry(), "--mode", opts.mode] : [serverEntry()];
  let existing = "";
  try {
    existing = fs.readFileSync(file, "utf8");
  } catch {
    /* new file */
  }
  try {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, mergeConfig(def.fmt, existing, name, "node", args));
  } catch (e) {
    return { id, file, ok: false, msg: (e as Error).message };
  }
  return { id, file, ok: true, msg: existing.trim() ? "updated" : "created" };
}

export function listClients(cwd: string): { id: string; label: string; file: string; exists: boolean; configured: boolean }[] {
  return CLIENTS.map((c) => {
    const file = c.file("user", cwd);
    let exists = false;
    let configured = false;
    try {
      const t = fs.readFileSync(file, "utf8");
      exists = true;
      configured = t.includes("godot-mcp-x");
    } catch {
      /* missing */
    }
    return { id: c.id, label: c.label, file, exists, configured };
  });
}

/** Configure every client whose config directory already exists (i.e. likely installed). */
export function installAll(opts: InstallOpts = {}): InstallResult[] {
  const cwd = opts.cwd ?? process.cwd();
  return CLIENTS.map((c) => {
    const file = c.file(opts.scope ?? "user", cwd);
    if (!fs.existsSync(path.dirname(file))) return { id: c.id, file, ok: false, msg: "skipped (not detected)" };
    return installClient(c.id, opts);
  });
}
