import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const animationTreeTools: ToolDef[] = [
  tool({
    name: "create_animation_tree",
    description: "Add an AnimationTree node, optionally wired to an AnimationPlayer.",
    schema: {
      parent_path: z.string().optional().describe("Parent (default '.')"),
      name: z.string().optional(),
      anim_player_path: z.string().optional().describe("NodePath to the AnimationPlayer, relative to the tree"),
    },
    handler: passthrough("create_animation_tree"),
  }),
  tool({
    name: "setup_state_machine",
    description: "Set an AnimationTree's root to a new AnimationNodeStateMachine.",
    schema: { tree_path: z.string().describe("AnimationTree path (scene-relative)") },
    handler: passthrough("setup_state_machine"),
  }),
  tool({
    name: "add_state",
    description: "Add a state (an animation) to the tree's state machine.",
    schema: {
      tree_path: z.string(),
      name: z.string().describe("State name"),
      animation: z.string().optional().describe("Animation name to play in this state"),
      x: z.number().int().optional(),
      y: z.number().int().optional(),
    },
    handler: passthrough("add_state"),
  }),
  tool({
    name: "add_transition",
    description: "Add a transition between two states.",
    schema: {
      tree_path: z.string(),
      from: z.string(),
      to: z.string(),
    },
    handler: passthrough("add_transition"),
  }),
  tool({
    name: "get_animation_tree_info",
    description: "Tree root type, anim_player, active flag, and state list.",
    schema: { tree_path: z.string() },
    handler: passthrough("get_animation_tree_info"),
  }),
  tool({
    name: "set_tree_param",
    description: "Set an AnimationTree blend parameter (e.g. param 'blend_position', value 'Vector2(1,0)').",
    schema: {
      tree_path: z.string(),
      param: z.string().describe("Param path (with or without leading 'parameters/')"),
      value: z.any(),
    },
    handler: passthrough("set_tree_param"),
  }),
];
