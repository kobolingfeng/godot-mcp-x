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
      background: z.boolean().optional().describe("Start as a background job and return a job_id"),
    },
    handler: passthrough("search_files"),
  }),
  tool({
    name: "start_search_files",
    description: "Start a non-blocking filename search job. Poll with get_analysis_job.",
    schema: {
      query: z.string().describe("Filename substring or glob, e.g. 'player' or '*.tscn'"),
      path: z.string().optional().describe("Root (default res://)"),
      file_type: z.string().optional().describe("Extension filter, e.g. 'gd'"),
      max_results: z.number().int().optional().describe("Default 50"),
    },
    handler: passthrough("start_search_files"),
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
      background: z.boolean().optional().describe("Start as a background job and return a job_id"),
    },
    handler: passthrough("search_in_files"),
  }),
  tool({
    name: "start_search_in_files",
    description: "Start a non-blocking grep job across project text files. Poll with get_analysis_job.",
    schema: {
      query: z.string().describe("Text or regex to find"),
      path: z.string().optional().describe("Root (default res://)"),
      file_type: z.string().optional().describe("Extension filter, e.g. 'gd'"),
      regex: z.boolean().optional().describe("Treat query as regex (default false)"),
      max_results: z.number().int().optional().describe("Default 50"),
    },
    handler: passthrough("start_search_in_files"),
  }),
  tool({
    name: "get_analysis_job",
    description: "Poll an analysis background job and page through its matches or files.",
    schema: {
      job_id: z.string().describe("Job id returned by an analysis start_* tool"),
      offset: z.number().int().optional().describe("Result offset (default 0)"),
      limit: z.number().int().optional().describe("Maximum results to return (default 50)"),
    },
    handler: passthrough("get_analysis_job"),
  }),
  tool({
    name: "cancel_analysis_job",
    description: "Cancel a running analysis background job.",
    schema: {
      job_id: z.string().describe("Job id returned by an analysis start_* tool"),
    },
    handler: passthrough("cancel_analysis_job"),
  }),
  tool({
    name: "start_reference_index",
    description: "Start or refresh the project reference index in the background.",
    schema: {
      path: z.string().optional().describe("Root to index (default current root or res://)"),
      root: z.string().optional().describe("Alias for path"),
      force: z.boolean().optional().describe("Restart indexing even if an index exists"),
      refresh: z.boolean().optional().describe("Alias for force"),
    },
    handler: passthrough("start_reference_index"),
  }),
  tool({
    name: "get_reference_index_status",
    description: "Return reference index readiness, queued work, and cache size.",
    schema: {
      path: z.string().optional().describe("Root to check (default current root)"),
      root: z.string().optional().describe("Alias for path"),
    },
    handler: passthrough("get_reference_index_status"),
  }),
  tool({
    name: "find_script_references",
    description: "Find where a script is referenced across the project (by path and uid).",
    schema: {
      script_path: z.string().describe("res:// path to the .gd"),
      max_results: z.number().int().optional().describe("Maximum references to return (default 200)"),
      refresh: z.boolean().optional().describe("Force rebuilding the reference index"),
      background: z.boolean().optional().describe("When indexing is needed, start it in the background and return status"),
    },
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
    description: "Node count, max depth, scripts, and per-type histogram. .tscn paths use a fast non-instantiating parser.",
    schema: { path: z.string().optional().describe("Scene to analyze (default: currently edited scene)") },
    handler: passthrough("analyze_scene_complexity"),
  }),
];
