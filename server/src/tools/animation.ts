import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const animationTools: ToolDef[] = [
  tool({
    name: "list_animations",
    description: "List animations on an AnimationPlayer.",
    schema: { player_path: z.string().describe("Scene-relative path to the AnimationPlayer") },
    handler: passthrough("list_animations"),
  }),
  tool({
    name: "get_animation_info",
    description: "Length, loop mode, and tracks of one animation.",
    schema: {
      player_path: z.string().describe("Scene-relative AnimationPlayer path"),
      name: z.string().describe("Animation name"),
    },
    handler: passthrough("get_animation_info"),
  }),
  tool({
    name: "create_animation",
    description: "Create an empty animation in the player's default library.",
    schema: {
      player_path: z.string().describe("Scene-relative AnimationPlayer path"),
      name: z.string().describe("New animation name"),
      length: z.number().optional().describe("Seconds (default 1.0)"),
    },
    handler: passthrough("create_animation"),
  }),
  tool({
    name: "add_animation_track",
    description: "Add a value track targeting node:property (e.g. 'Sprite:position').",
    schema: {
      player_path: z.string().describe("Scene-relative AnimationPlayer path"),
      anim_name: z.string().describe("Animation to add the track to"),
      node_path: z.string().describe("Track target node path (relative to the player)"),
      property: z.string().describe("Property to animate, e.g. 'position'"),
    },
    handler: passthrough("add_animation_track"),
  }),
  tool({
    name: "set_animation_keyframe",
    description: "Insert a keyframe at a time on a track. String values like 'Vector3(0,1,0)' are parsed.",
    schema: {
      player_path: z.string().describe("Scene-relative AnimationPlayer path"),
      anim_name: z.string().describe("Animation name"),
      track_index: z.number().int().describe("Track index (from add_animation_track / get_animation_info)"),
      time: z.number().describe("Keyframe time in seconds"),
      value: z.any().describe("Keyframe value"),
    },
    handler: passthrough("set_animation_keyframe"),
  }),
];
