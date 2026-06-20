import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const projectTools: ToolDef[] = [
  tool({
    name: "get_project_info",
    description: "Godot project metadata: name, Godot version, renderer, viewport size, main scene, autoloads.",
    handler: passthrough("get_project_info"),
  }),
  tool({
    name: "get_project_settings",
    description: "Read project.godot settings. Omit args for a curated summary; pass section or key to narrow.",
    schema: {
      section: z.string().optional().describe("Section prefix, e.g. 'display/window'"),
      key: z.string().optional().describe("Exact key, e.g. 'display/window/size/viewport_width'"),
    },
    handler: passthrough("get_project_settings"),
  }),
  tool({
    name: "set_project_setting",
    description: "Set a project setting via the editor API (never edit project.godot by hand). Strings auto-parse to Vector2/bool/int/float.",
    schema: {
      key: z.string().describe("Setting key, e.g. 'application/run/main_scene'"),
      value: z.union([z.string(), z.number(), z.boolean()]).describe("Value; string is auto-coerced when possible"),
    },
    handler: passthrough("set_project_setting"),
  }),
  tool({
    name: "get_filesystem_tree",
    description: "Project file tree. Defaults to res://. Use filter (e.g. '*.gd') and max_depth to keep output small.",
    schema: {
      path: z.string().optional().describe("Root (default res://)"),
      filter: z.string().optional().describe("Glob, e.g. '*.tscn'"),
      max_depth: z.number().int().optional().describe("Max depth (default 8)"),
      offset: z.number().int().optional().describe("Pagination offset over flattened entries"),
      limit: z.number().int().optional().describe("Max entries (default 500)"),
    },
    handler: passthrough("get_filesystem_tree"),
  }),
  tool({
    name: "list_autoloads",
    description: "List project autoloads (singletons): name → path.",
    handler: passthrough("list_autoloads"),
  }),
  tool({
    name: "add_autoload",
    description: "Register an autoload singleton (script or scene) in project settings.",
    schema: {
      name: z.string().describe("Singleton name, e.g. 'GameState'"),
      path: z.string().describe("res:// path to .gd or .tscn"),
    },
    handler: passthrough("add_autoload"),
  }),
  tool({
    name: "remove_autoload",
    description: "Remove an autoload singleton from project settings.",
    schema: { name: z.string().describe("Singleton name to remove") },
    handler: passthrough("remove_autoload"),
  }),
  tool({
    name: "uid_to_path",
    description: "Resolve a uid:// reference to its res:// path.",
    schema: { uid: z.string().describe("e.g. 'uid://abc123'") },
    handler: passthrough("uid_to_path"),
  }),
  tool({
    name: "path_to_uid",
    description: "Resolve a res:// path to its uid:// reference.",
    schema: { path: z.string().describe("e.g. 'res://player.tscn'") },
    handler: passthrough("path_to_uid"),
  }),
];
