import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const particleTools: ToolDef[] = [
  tool({
    name: "create_particles",
    description: "Add a GPUParticles3D (or 2D) with a ParticleProcessMaterial (and a default quad draw pass in 3D).",
    schema: {
      parent_path: z.string().optional().describe("Parent (default '.')"),
      name: z.string().optional(),
      dimension: z.enum(["3d", "2d"]).optional().describe("Default '3d'"),
      amount: z.number().int().optional().describe("Particle count (default 8)"),
      lifetime: z.number().optional().describe("Seconds"),
    },
    handler: passthrough("create_particles"),
  }),
  tool({
    name: "set_particle_process",
    description: "Set properties on a particle node's ParticleProcessMaterial (gravity, initial_velocity_min/max, …). String-encoded values parsed.",
    schema: {
      path: z.string().describe("GPUParticles node path (scene-relative)"),
      properties: z.record(z.any()).describe("ParticleProcessMaterial property → value"),
    },
    handler: passthrough("set_particle_process"),
  }),
  tool({
    name: "get_particle_info",
    description: "Particle node summary: amount/lifetime/emitting + changed process-material properties.",
    schema: { path: z.string().describe("GPUParticles node path (scene-relative)") },
    handler: passthrough("get_particle_info"),
  }),
];
