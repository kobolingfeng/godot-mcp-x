import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const analysisTools: ToolDef[] = [
  tool({
    name: "search_files",
    description: "Find files by name (substring or glob). Paginated via max_results.",
    schema: {
      query: z.string().describe("Filename substring or glob, e.g. 'player' or '*.tscn'"),
      path: z.string().optional().describe("Root (default res://)"),
      file_type: z.string().optional().describe("Extension filter, e.g. 'gd'"),
      max_results: z.number().int().optional().describe("Default 50"),
    },
    handler: passthrough("search_files"),
  }),
  tool({
    name: "search_in_files",
    description: "Grep across project text files (.gd/.tscn/.tres/.gdshader/…). Returns file+line+text.",
    schema: {
      query: z.string().describe("Text or regex to find"),
      path: z.string().optional().describe("Root (default res://)"),
      file_type: z.string().optional().describe("Extension filter, e.g. 'gd'"),
      regex: z.boolean().optional().describe("Treat query as regex (default false)"),
      max_results: z.number().int().optional().describe("Default 50"),
    },
    handler: passthrough("search_in_files"),
  }),
  tool({
    name: "find_script_references",
    description: "Find where a script is referenced across the project (by path and uid).",
    schema: { script_path: z.string().describe("res:// path to the .gd") },
    handler: passthrough("find_script_references"),
  }),
  tool({
    name: "get_scene_dependencies",
    description: "List external resources (ext_resource) a .tscn depends on.",
    schema: { path: z.string().describe("res:// path to the scene") },
    handler: passthrough("get_scene_dependencies"),
  }),
  tool({
    name: "analyze_scene_complexity",
    description: "Node count, max depth, scripts, and per-type histogram for a scene (current scene if no path).",
    schema: { path: z.string().optional().describe("Scene to analyze (default: currently edited scene)") },
    handler: passthrough("analyze_scene_complexity"),
  }),
];
