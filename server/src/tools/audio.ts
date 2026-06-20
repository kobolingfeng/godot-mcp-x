import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const audioTools: ToolDef[] = [
  tool({
    name: "add_audio_player",
    description: "Add an AudioStreamPlayer / 2D / 3D node, optionally with a stream and bus.",
    schema: {
      parent_path: z.string().optional().describe("Parent (default '.')"),
      name: z.string().optional(),
      dimension: z.enum(["plain", "2d", "3d"]).optional().describe("Default 'plain'"),
      stream: z.string().optional().describe("res:// audio resource to assign"),
      bus: z.string().optional().describe("Target bus name"),
    },
    handler: passthrough("add_audio_player"),
  }),
  tool({
    name: "list_audio_buses",
    description: "List audio buses with volume, mute, and effects.",
    handler: passthrough("list_audio_buses"),
  }),
  tool({
    name: "add_audio_bus",
    description: "Add an audio bus (persisted to the project bus layout).",
    schema: {
      name: z.string().describe("Bus name"),
      send: z.string().optional().describe("Bus to route output to (default Master)"),
    },
    handler: passthrough("add_audio_bus"),
  }),
  tool({
    name: "set_bus_volume",
    description: "Set an audio bus volume in dB (persisted).",
    schema: {
      bus: z.string().describe("Bus name"),
      volume_db: z.number().describe("Volume in dB (0 = unity, negative = quieter)"),
    },
    handler: passthrough("set_bus_volume"),
  }),
  tool({
    name: "add_bus_effect",
    description: "Add an effect to an audio bus (e.g. Reverb, Delay, Distortion, EQ, Compressor).",
    schema: {
      bus: z.string().describe("Bus name"),
      effect: z.string().describe("Effect short name, e.g. 'Reverb' → AudioEffectReverb"),
    },
    handler: passthrough("add_bus_effect"),
  }),
];
