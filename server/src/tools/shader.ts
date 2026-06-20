import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const shaderTools: ToolDef[] = [
  tool({
    name: "create_shader",
    description: "Create a .gdshader file with the given code (defaults to a spatial stub).",
    schema: {
      path: z.string().describe("res:// path ending in .gdshader"),
      code: z.string().optional().describe("Shader source (default 'shader_type spatial;')"),
    },
    handler: passthrough("create_shader"),
  }),
  tool({
    name: "read_shader",
    description: "Read a .gdshader file, line-paginated.",
    schema: {
      path: z.string().describe("res:// path to .gdshader"),
      offset: z.number().int().optional(),
      limit: z.number().int().optional().describe("Default 400"),
    },
    handler: passthrough("read_shader"),
  }),
  tool({
    name: "edit_shader",
    description: "Replace a unique substring in a .gdshader file.",
    schema: {
      path: z.string().describe("res:// path to .gdshader"),
      old_text: z.string().describe("Exact unique text to replace"),
      new_text: z.string().describe("Replacement"),
    },
    handler: passthrough("edit_shader"),
  }),
  tool({
    name: "assign_shader",
    description: "Wrap a shader in a ShaderMaterial and assign it to a node (MeshInstance3D surface / GeometryInstance3D override / CanvasItem material).",
    schema: {
      node_path: z.string().describe("Scene-relative node path"),
      shader_path: z.string().describe("res:// path to .gdshader"),
      surface: z.number().int().optional().describe("MeshInstance3D surface index (default 0)"),
    },
    handler: passthrough("assign_shader"),
  }),
  tool({
    name: "set_shader_param",
    description: "Set a uniform on a node's ShaderMaterial (assign_shader first). String values like 'Color(1,0,0,1)' are parsed.",
    schema: {
      node_path: z.string().describe("Scene-relative node path"),
      param: z.string().describe("Uniform name"),
      value: z.any(),
      surface: z.number().int().optional(),
    },
    handler: passthrough("set_shader_param"),
  }),
  tool({
    name: "list_shader_uniforms",
    description: "List the uniforms (name + type) declared in a .gdshader.",
    schema: { path: z.string().describe("res:// path to .gdshader") },
    handler: passthrough("list_shader_uniforms"),
  }),
];
