/**
 * `godot-x doctor` / `godot-x setup` — onboarding helpers.
 *   doctor [--project <dir>]   check server/daemon/connection, and (if given) a project's install
 *   setup  --project <dir>     copy the addon in + register the autoload + enable the plugin
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { daemonHealth } from "./daemon.js";

const AUTOLOAD_LINE = 'McpXRuntime="*res://addons/godot_mcp_x/runtime/runtime_bridge.gd"';
const PLUGIN_PATH = "res://addons/godot_mcp_x/plugin.cfg";

/** Repo addon source — this file is <repo>/server/build/setup.js. */
function addonSrc(): string {
  return path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../addons/godot_mcp_x");
}

function projGodot(project: string): string {
  return project.endsWith("project.godot") ? project : path.join(project, "project.godot");
}

export async function runDoctor(project?: string): Promise<void> {
  const checks: { ok: boolean; name: string; hint?: string }[] = [];
  const src = addonSrc();
  checks.push({ ok: fs.existsSync(src), name: "addon source present", hint: "reinstall godot-mcp-x" });
  const health = await daemonHealth();
  checks.push({ ok: !!health, name: "daemon running", hint: "start it: godot-x daemon" });
  if (health) {
    checks.push({
      ok: health.editor || health.runtime,
      name: "editor or game connected",
      hint: "open the editor (plugin enabled) or run the game",
    });
    if (health.concurrent_replaces > 0)
      checks.push({
        ok: false,
        name: `no port contention (concurrent_replaces=${health.concurrent_replaces})`,
        hint: "close extra Godot instances on this project",
      });
  }
  if (project) {
    const pg = projGodot(project);
    if (!fs.existsSync(pg)) {
      checks.push({ ok: false, name: `project.godot at ${pg}`, hint: "pass a Godot project dir" });
    } else {
      const dir = path.dirname(pg);
      const text = fs.readFileSync(pg, "utf8");
      checks.push({ ok: fs.existsSync(path.join(dir, "addons/godot_mcp_x")), name: "addon installed in project", hint: `godot-x setup --project "${dir}"` });
      checks.push({ ok: text.includes("runtime_bridge.gd"), name: "McpXRuntime autoload registered", hint: `godot-x setup --project "${dir}"` });
      checks.push({ ok: text.includes("godot_mcp_x/plugin.cfg"), name: "plugin enabled", hint: "enable godot_mcp_x in Project Settings ▸ Plugins (or run setup)" });
    }
  } else {
    checks.push({ ok: true, name: "(pass --project <dir> to also check a project's install)" });
  }
  for (const c of checks) console.log(`${c.ok ? "✓" : "✗"} ${c.name}${!c.ok && c.hint ? `  → ${c.hint}` : ""}`);
  const failed = checks.filter((c) => !c.ok).length;
  console.log(`\n${failed === 0 ? "All good." : `${failed} issue(s) — see hints above.`}`);
}

export function runSetup(project?: string): void {
  if (!project) {
    console.error("Usage: godot-x setup --project <godot project dir>");
    process.exit(1);
  }
  const pg = projGodot(project);
  const dir = path.dirname(pg);
  if (!fs.existsSync(pg)) {
    console.error(`No project.godot at ${pg}`);
    process.exit(1);
  }
  const dst = path.join(dir, "addons/godot_mcp_x");
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.cpSync(addonSrc(), dst, { recursive: true });
  console.log(`✓ copied addon → ${dst}`);

  let text = fs.readFileSync(pg, "utf8");
  let changed = false;
  if (!text.includes("runtime_bridge.gd")) {
    text = ensureInSection(text, "autoload", AUTOLOAD_LINE);
    changed = true;
    console.log("✓ registered McpXRuntime autoload");
  }
  if (!text.includes("godot_mcp_x/plugin.cfg")) {
    text = ensurePluginEnabled(text);
    changed = true;
    console.log("✓ enabled godot_mcp_x plugin");
  }
  if (changed) fs.writeFileSync(pg, text);
  else console.log("✓ project.godot already configured");
  console.log("\nDone. Build the server (cd server && npm run build) and open the editor on this project.");
}

/** Insert `line` right after `[section]`, or append the section if missing. */
export function ensureInSection(text: string, section: string, line: string): string {
  const header = `[${section}]`;
  const idx = text.indexOf(header);
  if (idx < 0) return text.replace(/\s*$/, "") + `\n\n${header}\n${line}\n`;
  const at = idx + header.length;
  return text.slice(0, at) + `\n${line}` + text.slice(at);
}

export function ensurePluginEnabled(text: string): string {
  const header = "[editor_plugins]";
  const line = `enabled=PackedStringArray("${PLUGIN_PATH}")`;
  if (!text.includes(header)) return text.replace(/\s*$/, "") + `\n\n${header}\n${line}\n`;
  const m = text.match(/enabled=PackedStringArray\(([^)]*)\)/);
  if (m) {
    if (m[1].includes(PLUGIN_PATH)) return text;
    const inner = m[1].trim();
    return text.replace(m[0], `enabled=PackedStringArray(${inner.length ? `${inner}, ` : ""}"${PLUGIN_PATH}")`);
  }
  const at = text.indexOf(header) + header.length;
  return text.slice(0, at) + `\n${line}` + text.slice(at);
}
