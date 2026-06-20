import { type ToolDef } from "../core/registry.js";
import { projectTools } from "./project.js";
import { sceneTools } from "./scene.js";
import { nodeTools } from "./node.js";
import { scriptTools } from "./script.js";
import { editorTools } from "./editor.js";
import { analysisTools } from "./analysis.js";
import { resourceTools } from "./resource.js";
import { inputMapTools } from "./input-map.js";
import { animationTools } from "./animation.js";
import { physicsTools } from "./physics.js";
import { node3dTools } from "./node3d.js";
import { runtimeTools } from "./runtime.js";
import { shaderTools } from "./shader.js";
import { audioTools } from "./audio.js";
import { particleTools } from "./particle.js";
import { navigationTools } from "./navigation.js";
import { tilemapTools } from "./tilemap.js";
import { themeTools } from "./theme.js";
import { animationTreeTools } from "./animation-tree.js";
import { batchTools } from "./batch.js";
import { profilingTools } from "./profiling.js";
import { exportTools } from "./export.js";
import { testingTools } from "./testing.js";
import { gridmapTools } from "./gridmap.js";
import { skeletonTools } from "./skeleton.js";
import { filesystemTools } from "./filesystem.js";
import { uiTools } from "./ui.js";
import { mpTools } from "./mp.js";

/** Named tool groups, in canonical order. */
export const GROUPS: Record<string, ToolDef[]> = {
  project: projectTools,
  scene: sceneTools,
  node: nodeTools,
  script: scriptTools,
  editor: editorTools,
  analysis: analysisTools,
  resource: resourceTools,
  input: inputMapTools,
  animation: animationTools,
  physics: physicsTools,
  node3d: node3dTools,
  runtime: runtimeTools,
  shader: shaderTools,
  audio: audioTools,
  particle: particleTools,
  navigation: navigationTools,
  tilemap: tilemapTools,
  theme: themeTools,
  animation_tree: animationTreeTools,
  batch: batchTools,
  profiling: profilingTools,
  export: exportTools,
  testing: testingTools,
  gridmap: gridmapTools,
  skeleton: skeletonTools,
  filesystem: filesystemTools,
  ui: uiTools,
  mp: mpTools,
};

const MINIMAL = ["project", "scene", "node", "script", "editor"];
const COMMON = [...MINIMAL, "analysis", "resource", "filesystem", "input", "animation", "batch", "runtime", "testing", "ui"];

/**
 * Modes select a subset of groups so a focused session only pays the tool-list
 * token cost for what it needs. 'full' is everything.
 */
export const MODES: Record<string, string[]> = {
  full: Object.keys(GROUPS),
  minimal: MINIMAL,
  "2d": [...COMMON, "physics", "tilemap", "theme", "mp"],
  "3d": [...COMMON, "physics", "navigation", "node3d", "shader", "particle", "audio", "animation_tree", "gridmap", "skeleton", "mp"],
  ui: [...MINIMAL, "resource", "theme", "batch", "runtime", "ui"],
  test: [...MINIMAL, "runtime", "testing", "profiling"],
};

export interface SelectOpts {
  mode?: string;
  groups?: string[];
  exclude?: string[];
}

/** Resolve a tool set from a mode name and/or explicit group include/exclude. */
export function selectTools(opts: SelectOpts = {}): ToolDef[] {
  const names = opts.groups && opts.groups.length ? opts.groups : MODES[opts.mode ?? "full"] ?? MODES.full;
  const excluded = new Set(opts.exclude ?? []);
  const seen = new Set<string>();
  const picked: ToolDef[] = [];
  for (const g of names) {
    if (excluded.has(g)) continue;
    const arr = GROUPS[g];
    if (!arr) continue;
    for (const t of arr) {
      if (!seen.has(t.name)) {
        seen.add(t.name);
        picked.push(t);
      }
    }
  }
  return picked;
}

/** Every tool (mode = full). */
export const allTools: ToolDef[] = selectTools();
