import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

/** Convenience builders for common 3D nodes (scene-relative parent paths). */
export const node3dTools: ToolDef[] = [
  tool({
    name: "add_mesh_instance",
    description: "Add a MeshInstance3D with a primitive mesh (box/sphere/cylinder/plane/capsule/torus).",
    schema: {
      parent_path: z.string().optional().describe("Parent (default '.')"),
      name: z.string().optional(),
      primitive: z.enum(["box", "sphere", "cylinder", "plane", "capsule", "torus"]).optional().describe("Default 'box'"),
    },
    handler: passthrough("add_mesh_instance"),
  }),
  tool({
    name: "setup_light",
    description: "Add a 3D light (directional/omni/spot) with optional energy & color.",
    schema: {
      parent_path: z.string().optional().describe("Parent (default '.')"),
      name: z.string().optional(),
      kind: z.enum(["directional", "omni", "spot", "area"]).optional().describe("Default 'directional'; 'area' = 4.7 AreaLight3D"),
      energy: z.number().optional(),
      color: z.string().optional().describe("e.g. 'Color(1,0.9,0.8,1)'"),
      area_size: z.string().optional().describe("AreaLight3D only, e.g. 'Vector2(2,1)'"),
    },
    handler: passthrough("setup_light"),
  }),
  tool({
    name: "setup_camera",
    description: "Add a Camera3D, optionally made current, with optional fov.",
    schema: {
      parent_path: z.string().optional().describe("Parent (default '.')"),
      name: z.string().optional(),
      fov: z.number().optional(),
      current: z.boolean().optional(),
    },
    handler: passthrough("setup_camera"),
  }),
  tool({
    name: "set_material",
    description: "Apply a StandardMaterial3D override to a MeshInstance3D surface.",
    schema: {
      path: z.string().describe("MeshInstance3D path (scene-relative)"),
      albedo: z.string().optional().describe("e.g. 'Color(1,0,0,1)'"),
      metallic: z.number().optional(),
      roughness: z.number().optional(),
      emission: z.string().optional().describe("Enables emission; e.g. 'Color(0,1,0,1)'"),
      surface: z.number().int().optional().describe("Surface index (default 0)"),
    },
    handler: passthrough("set_material"),
  }),
  tool({
    name: "setup_environment",
    description: "Add a WorldEnvironment with a procedural sky Environment.",
    schema: {
      parent_path: z.string().optional().describe("Parent (default '.')"),
      name: z.string().optional(),
    },
    handler: passthrough("setup_environment"),
  }),
];
