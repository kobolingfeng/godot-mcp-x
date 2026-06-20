// Unit tests for the project.godot patching logic in `setup` (fragile text munging).
import { describe, it, expect } from "vitest";
import { ensureInSection, ensurePluginEnabled } from "../../build/setup.js";

describe("ensureInSection", () => {
  it("appends a new section when missing", () => {
    const out = ensureInSection("config_version=5\n", "autoload", 'X="*res://x.gd"');
    expect(out).toContain("[autoload]");
    expect(out).toContain('X="*res://x.gd"');
  });
  it("inserts directly under an existing section header", () => {
    const out = ensureInSection('[autoload]\nA="a"\n', "autoload", 'B="b"');
    expect(out).toContain('B="b"');
    expect(out.indexOf('B="b"')).toBeLessThan(out.indexOf('A="a"'));
  });
});

describe("ensurePluginEnabled", () => {
  const PLUGIN = "res://addons/godot_mcp_x/plugin.cfg";
  it("adds the section when absent", () => {
    const out = ensurePluginEnabled("config_version=5\n");
    expect(out).toContain("[editor_plugins]");
    expect(out).toContain(PLUGIN);
  });
  it("appends to an existing enabled array (keeping others)", () => {
    const out = ensurePluginEnabled('[editor_plugins]\nenabled=PackedStringArray("res://addons/other/plugin.cfg")\n');
    expect(out).toContain("res://addons/other/plugin.cfg");
    expect(out).toContain(PLUGIN);
  });
  it("is idempotent when already present", () => {
    const text = `[editor_plugins]\nenabled=PackedStringArray("${PLUGIN}")\n`;
    expect(ensurePluginEnabled(text)).toBe(text);
  });
  it("adds enabled= when the section exists without it", () => {
    expect(ensurePluginEnabled("[editor_plugins]\n")).toContain(PLUGIN);
  });
});
