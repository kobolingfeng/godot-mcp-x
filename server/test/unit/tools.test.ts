// Registry sanity — catches duplicate names / malformed tool defs / missing tools.
import { describe, it, expect } from "vitest";
import { allTools } from "../../build/tools/groups.js";

describe("tool registry", () => {
  it("has unique tool names", () => {
    const names = allTools.map((t) => t.name);
    expect(new Set(names).size).toBe(names.length);
  });

  it("every tool has a name, a real description, and a handler", () => {
    for (const t of allTools) {
      expect(t.name).toMatch(/^[a-z][a-z0-9_]*$/);
      expect(typeof t.description).toBe("string");
      expect(t.description.length).toBeGreaterThan(10);
      expect(typeof t.handler).toBe("function");
    }
  });

  it("includes the recently added tools", () => {
    const names = new Set(allTools.map((t) => t.name));
    for (const n of ["build_tree", "reload_game_script", "get_game_screenshot", "simulate_key", "simulate_action"]) {
      expect(names.has(n), `missing tool: ${n}`).toBe(true);
    }
  });
});
