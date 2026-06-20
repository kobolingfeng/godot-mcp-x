import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

/** Skeleton3D inspection & posing (imported rigs or hand-built skeletons). */
export const skeletonTools: ToolDef[] = [
  tool({
    name: "get_skeleton_info",
    description: "Skeleton3D summary: bone count.",
    schema: { path: z.string().describe("Skeleton3D path (scene-relative)") },
    handler: passthrough("get_skeleton_info"),
  }),
  tool({
    name: "list_bones",
    description: "List a skeleton's bones (index, name, parent index), paginated.",
    schema: {
      path: z.string().describe("Skeleton3D path"),
      offset: z.number().int().optional(),
      limit: z.number().int().optional().describe("Default 300"),
    },
    handler: passthrough("list_bones"),
  }),
  tool({
    name: "add_bone",
    description: "Add a bone to a skeleton, optionally parented to an existing bone.",
    schema: {
      path: z.string().describe("Skeleton3D path"),
      name: z.string().describe("Bone name"),
      parent: z.string().optional().describe("Parent bone name"),
    },
    handler: passthrough("add_bone"),
  }),
  tool({
    name: "set_bone_pose",
    description: "Pose a bone. position is 'Vector3(...)'; rotation is 'Quaternion(...)' or a 'Vector3(...)' euler (radians).",
    schema: {
      path: z.string().describe("Skeleton3D path"),
      bone: z.string().describe("Bone name or index"),
      position: z.string().optional(),
      rotation: z.string().optional(),
    },
    handler: passthrough("set_bone_pose"),
  }),
  tool({
    name: "reset_bone_poses",
    description: "Reset all bone poses to their rest transforms.",
    schema: { path: z.string().describe("Skeleton3D path") },
    handler: passthrough("reset_bone_poses"),
  }),
  tool({
    name: "add_bone_attachment",
    description: "Add a BoneAttachment3D under a skeleton, bound to a bone (parent props/effects to a bone).",
    schema: {
      path: z.string().describe("Skeleton3D path"),
      bone: z.string().describe("Bone name to attach to"),
      name: z.string().optional(),
    },
    handler: passthrough("add_bone_attachment"),
  }),
  tool({
    name: "add_skeleton_modifier",
    description:
      "Add any SkeletonModifier3D as a child of a Skeleton3D (IK & constraints): TwoBoneIK3D, FABRIK3D, " +
      "CCDIK3D, JacobianIK3D, SplineIK3D, ChainIK3D, LookAtModifier3D, SpringBoneSimulator3D, etc. " +
      "Set its properties via `properties` (NodePath strings are converted).",
    schema: {
      path: z.string().describe("Skeleton3D path (scene-relative)"),
      type: z.string().describe("SkeletonModifier3D subclass, e.g. 'TwoBoneIK3D'"),
      name: z.string().optional(),
      properties: z.record(z.any()).optional().describe("Modifier properties (bone names, target_node, etc.)"),
    },
    handler: passthrough("add_skeleton_modifier"),
  }),
  tool({
    name: "setup_look_at_modifier",
    description: "Convenience: add a LookAtModifier3D that makes a bone look at a target node.",
    schema: {
      path: z.string().describe("Skeleton3D path"),
      bone: z.string().describe("Bone that should look at the target"),
      target_path: z.string().optional().describe("NodePath to the target (relative to the modifier)"),
      name: z.string().optional(),
    },
    handler: passthrough("setup_look_at_modifier"),
  }),
  tool({
    name: "list_skeleton_modifiers",
    description: "List SkeletonModifier3D children of a skeleton (type, active, influence).",
    schema: { path: z.string().describe("Skeleton3D path") },
    handler: passthrough("list_skeleton_modifiers"),
  }),
];
