// Unit tests for the efficiency core (run against built output: `npm test`).
import { describe, it, expect } from "vitest";
import { paginate, clampJson, estimateTokens, DEFAULT_MAX_CHARS } from "../../build/core/budget.js";
import { selectTools, MODES, GROUPS, allTools } from "../../build/tools/groups.js";

describe("estimateTokens", () => {
  it("scales with length", () => {
    expect(estimateTokens("")).toBe(0);
    expect(estimateTokens("x".repeat(35))).toBe(10); // 35 / 3.5
    expect(estimateTokens("abc")).toBeGreaterThan(0);
  });
});

describe("paginate", () => {
  const arr = Array.from({ length: 10 }, (_, i) => i);
  it("returns a window with metadata", () => {
    const p = paginate(arr, 0, 3);
    expect(p.items).toEqual([0, 1, 2]);
    expect(p.total).toBe(10);
    expect(p.has_more).toBe(true);
    expect(p.next_offset).toBe(3);
  });
  it("handles the last page", () => {
    const p = paginate(arr, 8, 5);
    expect(p.items).toEqual([8, 9]);
    expect(p.has_more).toBe(false);
    expect(p.next_offset).toBeNull();
  });
  it("clamps a negative offset and over-large offset", () => {
    expect(paginate(arr, -5, 2).offset).toBe(0);
    expect(paginate(arr, 100, 2).items).toEqual([]);
  });
});

describe("clampJson", () => {
  it("passes small payloads through as compact JSON", () => {
    const r = clampJson({ a: 1, b: "hi" });
    expect(r.content[0].text).toBe('{"a":1,"b":"hi"}');
    expect(r.isError).toBeUndefined();
  });
  it("truncates oversized payloads and appends a recovery note", () => {
    const big = { s: "x".repeat(DEFAULT_MAX_CHARS + 5000) };
    const r = clampJson(big);
    expect(r.content[0].text.length).toBeLessThanOrEqual(DEFAULT_MAX_CHARS);
    expect(r.content[0].text).toContain("OUTPUT TRUNCATED");
  });
  it("serializes strings without double-quoting", () => {
    expect(clampJson("plain").content[0].text).toBe("plain");
  });
});

describe("selectTools / modes", () => {
  it("full mode equals the whole catalog and has no duplicate names", () => {
    const full = selectTools({ mode: "full" });
    expect(full.length).toBe(allTools.length);
    const names = new Set(full.map((t) => t.name));
    expect(names.size).toBe(full.length);
  });
  it("minimal is a strict subset of full", () => {
    const min = selectTools({ mode: "minimal" });
    expect(min.length).toBeGreaterThan(0);
    expect(min.length).toBeLessThan(allTools.length);
  });
  it("explicit groups win over mode", () => {
    const picked = selectTools({ groups: ["project"] });
    expect(picked.every((t) => GROUPS.project.includes(t))).toBe(true);
  });
  it("exclude removes a group", () => {
    const withExport = selectTools({ mode: "full" }).some((t) => t.name === "list_export_presets");
    const without = selectTools({ mode: "full", exclude: ["export"] }).some((t) => t.name === "list_export_presets");
    expect(withExport).toBe(true);
    expect(without).toBe(false);
  });
  it("unknown mode falls back to full; unknown group is ignored", () => {
    expect(selectTools({ mode: "bogus" }).length).toBe(allTools.length);
    expect(selectTools({ groups: ["nope"] }).length).toBe(0);
  });
  it("every mode references only real groups", () => {
    for (const groups of Object.values(MODES)) {
      for (const g of groups) expect(GROUPS[g], `group ${g}`).toBeDefined();
    }
  });
});
