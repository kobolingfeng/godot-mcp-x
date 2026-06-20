import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

/** TileMapLayer-native (TileMap is deprecated in 4.x). */
export const tilemapTools: ToolDef[] = [
  tool({
    name: "tilemap_get_info",
    description: "TileMapLayer summary: tileset assigned?, used cell count, enabled.",
    schema: { path: z.string().describe("TileMapLayer path (scene-relative)") },
    handler: passthrough("tilemap_get_info"),
  }),
  tool({
    name: "tilemap_set_cell",
    description: "Set a cell on a TileMapLayer.",
    schema: {
      path: z.string().describe("TileMapLayer path"),
      x: z.number().int(),
      y: z.number().int(),
      source_id: z.number().int().optional().describe("TileSet source id (default 0)"),
      atlas_x: z.number().int().optional(),
      atlas_y: z.number().int().optional(),
      alternative: z.number().int().optional(),
    },
    handler: passthrough("tilemap_set_cell"),
  }),
  tool({
    name: "tilemap_get_cell",
    description: "Read a cell's source id and atlas coords.",
    schema: {
      path: z.string().describe("TileMapLayer path"),
      x: z.number().int(),
      y: z.number().int(),
    },
    handler: passthrough("tilemap_get_cell"),
  }),
  tool({
    name: "tilemap_erase_cell",
    description: "Erase a cell on a TileMapLayer.",
    schema: {
      path: z.string().describe("TileMapLayer path"),
      x: z.number().int(),
      y: z.number().int(),
    },
    handler: passthrough("tilemap_erase_cell"),
  }),
  tool({
    name: "tilemap_fill_rect",
    description: "Fill a rectangular region of a TileMapLayer with one tile.",
    schema: {
      path: z.string().describe("TileMapLayer path"),
      x: z.number().int(),
      y: z.number().int(),
      w: z.number().int().describe("Width in cells"),
      h: z.number().int().describe("Height in cells"),
      source_id: z.number().int().optional(),
      atlas_x: z.number().int().optional(),
      atlas_y: z.number().int().optional(),
    },
    handler: passthrough("tilemap_fill_rect"),
  }),
  tool({
    name: "tilemap_clear",
    description: "Clear all cells of a TileMapLayer.",
    schema: { path: z.string().describe("TileMapLayer path") },
    handler: passthrough("tilemap_clear"),
  }),
  tool({
    name: "tilemap_get_used_cells",
    description: "List used cell coordinates of a TileMapLayer (paginated).",
    schema: {
      path: z.string().describe("TileMapLayer path"),
      offset: z.number().int().optional(),
      limit: z.number().int().optional().describe("Default 500"),
    },
    handler: passthrough("tilemap_get_used_cells"),
  }),
];
