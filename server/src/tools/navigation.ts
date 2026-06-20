import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const navigationTools: ToolDef[] = [
  tool({
    name: "setup_navigation_region",
    description: "Add a NavigationRegion3D with an empty NavigationMesh (bake it afterwards).",
    schema: {
      parent_path: z.string().optional().describe("Parent (default '.')"),
      name: z.string().optional(),
    },
    handler: passthrough("setup_navigation_region"),
  }),
  tool({
    name: "setup_navigation_agent",
    description: "Add a NavigationAgent3D child to a node (e.g. an enemy).",
    schema: {
      path: z.string().describe("Node to attach the agent to"),
      radius: z.number().optional(),
    },
    handler: passthrough("setup_navigation_agent"),
  }),
  tool({
    name: "bake_navigation_mesh",
    description: "Bake the navigation mesh of a NavigationRegion3D from scene geometry (async).",
    schema: { path: z.string().describe("NavigationRegion3D path (scene-relative)") },
    handler: passthrough("bake_navigation_mesh"),
  }),
  tool({
    name: "get_navigation_info",
    description: "List NavigationRegion3D nodes in the current scene.",
    handler: passthrough("get_navigation_info"),
  }),
];
