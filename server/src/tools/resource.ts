import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const resourceTools: ToolDef[] = [
  tool({
    name: "create_resource",
    description: "Create and save a Resource (.tres/.res) of the given class with optional initial properties.",
    schema: {
      type: z.string().describe("Resource class, e.g. 'StandardMaterial3D'"),
      path: z.string().describe("res:// save path, e.g. 'res://mat.tres'"),
      properties: z.record(z.any()).optional().describe("Initial properties; string-encoded values parsed"),
    },
    handler: passthrough("create_resource"),
  }),
  tool({
    name: "read_resource",
    description: "Load a resource and return its changed (non-default) properties; include_defaults for all.",
    schema: {
      path: z.string().describe("res:// path to the resource"),
      names: z.array(z.string()).optional().describe("Only return these properties"),
      include_defaults: z.boolean().optional().describe("Return every property (default false)"),
    },
    handler: passthrough("read_resource"),
  }),
  tool({
    name: "edit_resource",
    description: "Set properties on an existing resource and re-save it.",
    schema: {
      path: z.string().describe("res:// path to the resource"),
      properties: z.record(z.any()).describe("Map of property → value"),
    },
    handler: passthrough("edit_resource"),
  }),
];
