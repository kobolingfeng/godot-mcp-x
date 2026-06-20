import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const sceneTools: ToolDef[] = [
  tool({
    name: "get_scene_tree",
    description:
      "Structure of the currently edited scene as SCENE-RELATIVE paths (no editor-internal noise). " +
      "Defaults: structure only, no internal nodes. Use max_depth/type_filter to shrink output.",
    schema: {
      max_depth: z.number().int().optional().describe("Limit tree depth (default unlimited but clamped by budget)"),
      include_internal: z.boolean().optional().describe("Include editor-owned/internal children (default false)"),
      include_properties: z.boolean().optional().describe("Attach changed (non-default) properties per node (default false)"),
      type_filter: z.string().optional().describe("Only include nodes of this class (e.g. 'Light3D')"),
    },
    handler: passthrough("get_scene_tree"),
  }),
  tool({
    name: "get_current_scene",
    description: "Path + root node info of the scene currently open in the editor.",
    handler: passthrough("get_current_scene"),
  }),
  tool({
    name: "open_scene",
    description: "Open a scene file in the editor and make it the edited scene.",
    schema: { path: z.string().describe("res:// path to .tscn/.scn") },
    handler: passthrough("open_scene"),
  }),
  tool({
    name: "save_scene",
    description: "Save the current scene. Optionally save-as to a new path.",
    schema: { path: z.string().optional().describe("Save-as target (default: current scene path)") },
    handler: passthrough("save_scene"),
  }),
  tool({
    name: "create_scene",
    description: "Create a new scene file with a typed root node, and open it.",
    schema: {
      path: z.string().describe("res:// path for the new .tscn"),
      root_type: z.string().optional().describe("Root node class (default 'Node')"),
      root_name: z.string().optional().describe("Root node name (default derived from type)"),
    },
    handler: passthrough("create_scene"),
  }),
  tool({
    name: "get_scene_file_content",
    description: "Raw .tscn text, line-paginated. Use offset/limit to read a slice instead of the whole file.",
    schema: {
      path: z.string().describe("res:// path to scene file"),
      offset: z.number().int().optional().describe("First line (0-based, default 0)"),
      limit: z.number().int().optional().describe("Max lines (default 400)"),
    },
    handler: passthrough("get_scene_file_content"),
  }),
  tool({
    name: "instance_scene",
    description: "Instance a scene (.tscn) as a child of a node in the current scene.",
    schema: {
      scene_path: z.string().describe("res:// path of the scene to instance"),
      parent_path: z.string().optional().describe("Scene-relative parent (default '.': the root)"),
      name: z.string().optional().describe("Name for the instanced node"),
    },
    handler: passthrough("instance_scene"),
  }),
];
