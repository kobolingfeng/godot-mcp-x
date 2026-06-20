import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const batchTools: ToolDef[] = [
  tool({
    name: "batch_add_nodes",
    description:
      "Add many nodes in one call. Processed in order, so an earlier node can be the " +
      "parent_path of a later one. Each: {type, name, parent_path?, properties?}.",
    schema: {
      nodes: z
        .array(
          z.object({
            type: z.string(),
            name: z.string(),
            parent_path: z.string().optional(),
            properties: z.record(z.any()).optional(),
          })
        )
        .describe("Node definitions, applied top-to-bottom"),
    },
    handler: passthrough("batch_add_nodes"),
  }),
  tool({
    name: "batch_set_properties",
    description: "Set properties on multiple nodes in one call. Each: {path, properties}.",
    schema: {
      updates: z.array(z.object({ path: z.string(), properties: z.record(z.any()) })),
    },
    handler: passthrough("batch_set_properties"),
  }),
  tool({
    name: "batch_get_properties",
    description: "Get properties (changed-only, or projected by names[]) for multiple nodes at once.",
    schema: {
      paths: z.array(z.string()),
      names: z.array(z.string()).optional().describe("Project these properties; omit for changed-only"),
    },
    handler: passthrough("batch_get_properties"),
  }),
];
