// Unit tests for the one-command MCP-client config writer (per-client schemas).
import { describe, it, expect } from "vitest";
import os from "os";
import fs from "fs";
import path from "path";
import { mergeConfig, installClient } from "../../build/clients.js";

describe("mergeConfig", () => {
  it("mcpServers: adds godot-mcp-x and preserves existing servers", () => {
    const o = JSON.parse(mergeConfig("mcpServers", '{"mcpServers":{"other":{"command":"x"}}}', "godot-mcp-x", "node", ["a.js"]));
    expect(o.mcpServers.other.command).toBe("x");
    expect(o.mcpServers["godot-mcp-x"]).toEqual({ command: "node", args: ["a.js"] });
  });
  it("vscode: uses `servers` + type:stdio", () => {
    const o = JSON.parse(mergeConfig("vscode", "", "godot-mcp-x", "node", ["a.js"]));
    expect(o.servers["godot-mcp-x"]).toEqual({ type: "stdio", command: "node", args: ["a.js"] });
  });
  it("zed: uses context_servers + source:custom + env", () => {
    const o = JSON.parse(mergeConfig("zed", "", "godot-mcp-x", "node", ["a.js"]));
    expect(o.context_servers["godot-mcp-x"]).toEqual({ source: "custom", command: "node", args: ["a.js"], env: {} });
  });
  it("codex: appends a TOML block and is idempotent", () => {
    const first = mergeConfig("codex", "[other]\nx = 1\n", "godot-mcp-x", "node", ["a.js"]);
    expect(first).toContain("[mcp_servers.godot-mcp-x]");
    expect(first).toContain('command = "node"');
    expect(first).toContain("[other]"); // preserved
    expect(mergeConfig("codex", first, "godot-mcp-x", "node", ["a.js"])).toBe(first);
  });
  it("malformed existing JSON is replaced, not thrown", () => {
    const o = JSON.parse(mergeConfig("mcpServers", "not json {", "godot-mcp-x", "node", ["a.js"]));
    expect(o.mcpServers["godot-mcp-x"]).toBeTruthy();
  });
});

describe("installClient", () => {
  it("writes a real .mcp.json into a temp project", () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "mcpx-"));
    try {
      const r = installClient("claude-code", { scope: "project", cwd: tmp });
      expect(r.ok).toBe(true);
      const o = JSON.parse(fs.readFileSync(path.join(tmp, ".mcp.json"), "utf8"));
      expect(o.mcpServers["godot-mcp-x"].command).toBe("node");
      expect(o.mcpServers["godot-mcp-x"].args[0]).toContain("index.js");
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });
  it("unknown client → ok:false", () => {
    expect(installClient("notaclient").ok).toBe(false);
  });
});
