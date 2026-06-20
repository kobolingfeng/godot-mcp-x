import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

/** `type` is the control class the item belongs to, e.g. "Button", "Label". */
export const themeTools: ToolDef[] = [
  tool({
    name: "create_theme",
    description: "Create a Theme resource (.tres).",
    schema: {
      path: z.string().describe("res:// .tres path"),
      default_font_size: z.number().int().optional(),
    },
    handler: passthrough("create_theme"),
  }),
  tool({
    name: "set_theme_color",
    description: "Set a theme color item (e.g. name 'font_color', type 'Button').",
    schema: {
      path: z.string(),
      name: z.string().describe("Item name, e.g. 'font_color'"),
      type: z.string().describe("Control class, e.g. 'Button'"),
      color: z.string().describe("'Color(r,g,b,a)'"),
    },
    handler: passthrough("set_theme_color"),
  }),
  tool({
    name: "set_theme_constant",
    description: "Set a theme constant (e.g. name 'h_separation', type 'HBoxContainer').",
    schema: {
      path: z.string(),
      name: z.string(),
      type: z.string(),
      value: z.number().int(),
    },
    handler: passthrough("set_theme_constant"),
  }),
  tool({
    name: "set_theme_font_size",
    description: "Set a theme font size item (e.g. name 'font_size', type 'Label').",
    schema: {
      path: z.string(),
      name: z.string(),
      type: z.string(),
      size: z.number().int(),
    },
    handler: passthrough("set_theme_font_size"),
  }),
  tool({
    name: "set_theme_stylebox",
    description: "Set a theme stylebox (flat/empty/texture). For flat, pass bg_color.",
    schema: {
      path: z.string(),
      name: z.string().describe("e.g. 'normal', 'panel'"),
      type: z.string().describe("Control class"),
      stylebox: z.enum(["flat", "empty", "texture"]).optional().describe("Default 'flat'"),
      bg_color: z.string().optional().describe("'Color(r,g,b,a)' for flat"),
    },
    handler: passthrough("set_theme_stylebox"),
  }),
  tool({
    name: "get_theme_info",
    description: "List a theme's default font size and item types.",
    schema: { path: z.string() },
    handler: passthrough("get_theme_info"),
  }),
  tool({
    name: "apply_theme",
    description: "Assign a theme resource to a Control node.",
    schema: {
      node_path: z.string().describe("Control node (scene-relative)"),
      theme_path: z.string().describe("res:// theme .tres"),
    },
    handler: passthrough("apply_theme"),
  }),
];
