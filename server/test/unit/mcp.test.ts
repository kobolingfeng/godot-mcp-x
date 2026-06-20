// Smoke test for the PRIMARY interface: the MCP server over stdio. Spawns the
// built server and drives it with the real MCP client (no Godot needed — a
// tool call with no editor connected must return a graceful error, not hang).
import { describe, it, expect } from "vitest";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

describe("MCP server (stdio)", () => {
  it("initializes, lists tools, and handles a call with no Godot gracefully", async () => {
    const transport = new StdioClientTransport({
      command: "node",
      args: ["build/index.js", "--mode", "minimal"],
      // a free, unlikely WS port so the test never collides with a running daemon/editor
      env: { ...process.env, GODOT_MCP_X_PORT: "6651" },
      stderr: "ignore",
    });
    const client = new Client({ name: "smoke", version: "1.0.0" });
    await client.connect(transport); // performs the initialize handshake

    const { tools } = await client.listTools();
    const names = tools.map((t) => t.name);
    expect(tools.length).toBeGreaterThan(0);
    expect(names).toContain("get_project_info");

    // No editor connected → the tool path must return isError, fast (not hang).
    const res = (await client.callTool({ name: "get_project_info", arguments: {} })) as { isError?: boolean };
    expect(res.isError).toBe(true);

    await client.close();
  }, 20000);
});
