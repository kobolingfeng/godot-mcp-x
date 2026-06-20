import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const inputMapTools: ToolDef[] = [
  tool({
    name: "list_input_actions",
    description: "List project input actions (persisted in project.godot) with their events.",
    handler: passthrough("list_input_actions"),
  }),
  tool({
    name: "add_input_action",
    description: "Create a project input action (persisted). Add events with add_input_event.",
    schema: {
      name: z.string().describe("Action name, e.g. 'jump'"),
      deadzone: z.number().optional().describe("Default 0.5"),
    },
    handler: passthrough("add_input_action"),
  }),
  tool({
    name: "remove_input_action",
    description: "Remove a project input action.",
    schema: { name: z.string().describe("Action name") },
    handler: passthrough("remove_input_action"),
  }),
  tool({
    name: "add_input_event",
    description: "Bind a physical key to an input action (e.g. key 'W', 'Space', 'Escape').",
    schema: {
      name: z.string().describe("Existing action name"),
      key: z.string().describe("Key name, e.g. 'W', 'Space', 'Escape', 'Left'"),
    },
    handler: passthrough("add_input_event"),
  }),
];
