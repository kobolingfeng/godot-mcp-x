import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const exportTools: ToolDef[] = [
  tool({
    name: "list_export_presets",
    description: "List export presets (name/platform/runnable) from export_presets.cfg.",
    handler: passthrough("list_export_presets"),
  }),
  tool({
    name: "get_export_info",
    description: "Full settings of one export preset (or the first if none named).",
    schema: { preset: z.string().optional().describe("Preset name") },
    handler: passthrough("get_export_info"),
  }),
];
