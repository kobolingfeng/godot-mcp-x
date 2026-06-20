import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const physicsTools: ToolDef[] = [
  tool({
    name: "get_physics_layers",
    description: "Named 2D & 3D physics layers from project settings.",
    handler: passthrough("get_physics_layers"),
  }),
  tool({
    name: "set_physics_layer_name",
    description: "Name a physics layer (1-32) in project settings.",
    schema: {
      layer: z.number().int().describe("Layer number 1-32"),
      name: z.string().describe("Display name"),
      dimension: z.enum(["2d", "3d"]).optional().describe("Default '3d'"),
    },
    handler: passthrough("set_physics_layer_name"),
  }),
  tool({
    name: "set_collision_layers",
    description: "Set collision_layer/collision_mask bitmasks on a physics body.",
    schema: {
      path: z.string().describe("Scene-relative node path"),
      layer: z.number().int().optional().describe("collision_layer bitmask"),
      mask: z.number().int().optional().describe("collision_mask bitmask"),
    },
    handler: passthrough("set_collision_layers"),
  }),
  tool({
    name: "get_collision_info",
    description: "Read a node's collision_layer/collision_mask.",
    schema: { path: z.string().describe("Scene-relative node path") },
    handler: passthrough("get_collision_info"),
  }),
  tool({
    name: "setup_collision_shape",
    description: "Add a CollisionShape3D child (box/sphere/capsule) under a body.",
    schema: {
      path: z.string().describe("Body node (scene-relative)"),
      shape: z.enum(["box", "sphere", "capsule"]).optional().describe("Default 'box'"),
      name: z.string().optional(),
    },
    handler: passthrough("setup_collision_shape"),
  }),
];
