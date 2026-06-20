import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

/** Scene-relative node paths everywhere ('.' = root, 'Player/Camera3D'). */
export const nodeTools: ToolDef[] = [
  tool({
    name: "add_node",
    description: "Add a node of the given class under a parent (scene-relative path). Optionally set initial properties.",
    schema: {
      type: z.string().describe("Node class, e.g. 'CharacterBody3D'"),
      name: z.string().describe("Node name"),
      parent_path: z.string().optional().describe("Scene-relative parent (default '.': root)"),
      properties: z.record(z.any()).optional().describe("Initial properties; string-encoded values like 'Vector3(0,1,0)' are parsed"),
    },
    handler: passthrough("add_node"),
  }),
  tool({
    name: "delete_node",
    description: "Delete a node (and its children) from the current scene.",
    schema: { path: z.string().describe("Scene-relative node path") },
    handler: passthrough("delete_node"),
  }),
  tool({
    name: "rename_node",
    description: "Rename a node.",
    schema: {
      path: z.string().describe("Scene-relative node path"),
      new_name: z.string().describe("New node name"),
    },
    handler: passthrough("rename_node"),
  }),
  tool({
    name: "move_node",
    description: "Reparent a node, optionally to a specific sibling index.",
    schema: {
      path: z.string().describe("Node to move (scene-relative)"),
      new_parent_path: z.string().describe("New parent (scene-relative)"),
      index: z.number().int().optional().describe("Sibling index under new parent"),
    },
    handler: passthrough("move_node"),
  }),
  tool({
    name: "duplicate_node",
    description: "Duplicate a node (deep) as a sibling.",
    schema: {
      path: z.string().describe("Node to duplicate"),
      new_name: z.string().optional().describe("Name for the copy"),
    },
    handler: passthrough("duplicate_node"),
  }),
  tool({
    name: "get_node_properties",
    description:
      "Properties of a node. By default returns ONLY non-default (changed) properties to save tokens. " +
      "Pass names[] to project specific properties, or include_defaults=true for the full set.",
    schema: {
      path: z.string().describe("Scene-relative node path"),
      names: z.array(z.string()).optional().describe("Only return these properties"),
      include_defaults: z.boolean().optional().describe("Include properties still at their class default (default false)"),
    },
    handler: passthrough("get_node_properties"),
  }),
  tool({
    name: "set_node_property",
    description: "Set one property on a node. String-encoded values (e.g. 'Color(1,0,0,1)') are parsed.",
    schema: {
      path: z.string().describe("Scene-relative node path"),
      property: z.string().describe("Property name, e.g. 'position'"),
      value: z.any().describe("New value; strings auto-parsed for Vector/Color/etc."),
    },
    handler: passthrough("set_node_property"),
  }),
  tool({
    name: "set_node_properties",
    description: "Set multiple properties on one node in a single call.",
    schema: {
      path: z.string().describe("Scene-relative node path"),
      properties: z.record(z.any()).describe("Map of property → value"),
    },
    handler: passthrough("set_node_properties"),
  }),
  tool({
    name: "get_node_signals",
    description: "List a node's signals and their current outgoing connections.",
    schema: { path: z.string().describe("Scene-relative node path") },
    handler: passthrough("get_node_signals"),
  }),
  tool({
    name: "connect_signal",
    description: "Connect a node's signal to a method on a target node.",
    schema: {
      from_path: z.string().describe("Emitter node (scene-relative)"),
      signal: z.string().describe("Signal name"),
      to_path: z.string().describe("Receiver node (scene-relative)"),
      method: z.string().describe("Method name on the receiver"),
    },
    handler: passthrough("connect_signal"),
  }),
  tool({
    name: "set_node_groups",
    description: "Replace a node's group membership with the given list.",
    schema: {
      path: z.string().describe("Scene-relative node path"),
      groups: z.array(z.string()).describe("Group names"),
    },
    handler: passthrough("set_node_groups"),
  }),
  tool({
    name: "find_nodes",
    description: "Find nodes in the current scene by class type and/or name pattern. Returns scene-relative paths.",
    schema: {
      type: z.string().optional().describe("Class filter, e.g. 'Light3D'"),
      pattern: z.string().optional().describe("Name glob, e.g. 'Enemy*'"),
      group: z.string().optional().describe("Group membership filter"),
      offset: z.number().int().optional(),
      limit: z.number().int().optional().describe("Max results (default 200)"),
    },
    handler: passthrough("find_nodes"),
  }),
  tool({
    name: "call_node_method",
    description:
      "Call a method on a node by name with positional args. String args like 'Vector3(0,1,0)' are " +
      "parsed; returns the method's return value.",
    schema: {
      path: z.string().describe("Scene-relative node path"),
      method: z.string().describe("Method name"),
      args: z.array(z.any()).optional().describe("Positional arguments"),
    },
    handler: passthrough("call_node_method"),
  }),
  tool({
    name: "build_tree",
    description:
      "Build a whole node subtree in ONE undoable action from a nested spec — far faster than many " +
      "add_node/set_property round-trips. Each node: {type, name?, script?, properties?, groups?, signals?[], " +
      'children?[]}. A property value may be an inline resource {"_res":"CircleShape2D","properties":{...}}. ' +
      "signals: [{signal, to (path relative to the built subtree root, '.'=root), method}].",
    schema: {
      parent_path: z.string().optional().describe("Scene-relative parent (default '.': root)"),
      tree: z
        .record(z.any())
        .describe('Root node spec {type, name?, script?, properties? (values may be {"_res":...}), groups?, signals?[], children?[]}'),
    },
    handler: passthrough("build_tree"),
  }),
];
