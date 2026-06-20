import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const uiTools: ToolDef[] = [
  tool({
    name: "add_virtual_joystick",
    description:
      "Add a 4.7 VirtualJoystick (touchscreen). Wire it to input-map actions so movement code that reads " +
      "those actions works on touch. Defaults to a bottom-left anchor.",
    schema: {
      parent_path: z.string().optional().describe("Parent Control (default '.')"),
      name: z.string().optional(),
      mode: z.enum(["fixed", "dynamic", "following"]).optional().describe("Default 'fixed'"),
      actions: z
        .object({
          left: z.string().optional(),
          right: z.string().optional(),
          up: z.string().optional(),
          down: z.string().optional(),
        })
        .optional()
        .describe("Map directions to input-map action names, e.g. {left:'move_left', …}"),
    },
    handler: passthrough("add_virtual_joystick"),
  }),
  tool({
    name: "set_anchor_preset",
    description:
      "Lay out a Control via an anchor preset: full_rect, center, top_left/right, bottom_left/right, " +
      "center_left/right/top/bottom, top_wide/bottom_wide/left_wide/right_wide, hcenter_wide/vcenter_wide. " +
      "Also sets offsets unless keep_offsets=true.",
    schema: {
      path: z.string().describe("Control node path (scene-relative)"),
      preset: z.string().describe("Preset name, e.g. 'full_rect'"),
      keep_offsets: z.boolean().optional().describe("Set anchors only, leave offsets (default false)"),
    },
    handler: passthrough("set_anchor_preset"),
  }),
];
