import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

/** GridMap — 3D block/tile level building (items come from a MeshLibrary). */
export const gridmapTools: ToolDef[] = [
  tool({
    name: "add_gridmap",
    description: "Add a GridMap node, optionally with a cell_size and MeshLibrary.",
    schema: {
      parent_path: z.string().optional().describe("Parent (default '.')"),
      name: z.string().optional(),
      cell_size: z.string().optional().describe("'Vector3(2,2,2)'"),
      mesh_library: z.string().optional().describe("res:// MeshLibrary resource"),
    },
    handler: passthrough("add_gridmap"),
  }),
  tool({
    name: "gridmap_set_cell",
    description: "Set a GridMap cell to a MeshLibrary item index (item -1 clears it).",
    schema: {
      path: z.string().describe("GridMap path"),
      x: z.number().int(),
      y: z.number().int(),
      z: z.number().int(),
      item: z.number().int().optional().describe("MeshLibrary item id (default 0)"),
      orientation: z.number().int().optional().describe("0-23 orthogonal orientation"),
    },
    handler: passthrough("gridmap_set_cell"),
  }),
  tool({
    name: "gridmap_get_cell",
    description: "Read the item index at a GridMap cell (-1 = empty).",
    schema: { path: z.string(), x: z.number().int(), y: z.number().int(), z: z.number().int() },
    handler: passthrough("gridmap_get_cell"),
  }),
  tool({
    name: "gridmap_clear",
    description: "Clear all GridMap cells.",
    schema: { path: z.string() },
    handler: passthrough("gridmap_clear"),
  }),
  tool({
    name: "gridmap_get_used_cells",
    description: "List used GridMap cell coordinates (paginated).",
    schema: {
      path: z.string(),
      offset: z.number().int().optional(),
      limit: z.number().int().optional().describe("Default 500"),
    },
    handler: passthrough("gridmap_get_used_cells"),
  }),
  tool({
    name: "gridmap_get_info",
    description: "GridMap summary: mesh_library assigned?, cell_size, used cell count.",
    schema: { path: z.string() },
    handler: passthrough("gridmap_get_info"),
  }),
];
