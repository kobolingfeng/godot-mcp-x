import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const editorTools: ToolDef[] = [
  tool({
    name: "execute_editor_script",
    description:
      "Run arbitrary GDScript inside the editor (full EditorInterface/ClassDB access). " +
      "Use _mcp_print(value) to return output. The single most powerful escape hatch.",
    schema: {
      code: z.string().describe("GDScript body; call _mcp_print(x) to capture output"),
    },
    maxChars: 40000,
    handler: passthrough("execute_editor_script"),
  }),
  tool({
    name: "get_editor_errors",
    description: "Recent errors/warnings from the editor log (compile errors, script warnings).",
    schema: { max_lines: z.number().int().optional().describe("Log lines to scan (default 80)") },
    handler: passthrough("get_editor_errors"),
  }),
  tool({
    name: "get_output_log",
    description: "Tail of the editor/output log.",
    schema: { max_lines: z.number().int().optional().describe("Lines to return (default 100)") },
    handler: passthrough("get_output_log"),
  }),
  tool({
    name: "clear_output",
    description: "Clear the editor Output panel.",
    handler: passthrough("clear_output"),
  }),
  tool({
    name: "get_editor_screenshot",
    description: "Screenshot the editor viewport. Pass save_path to write a PNG and get back a path instead of base64.",
    schema: { save_path: z.string().optional().describe("res:// or user:// PNG path; omit for base64") },
    maxChars: 2_000_000,
    handler: passthrough("get_editor_screenshot"),
  }),
  tool({
    name: "reload_scripts",
    description: "Force-reload changed scripts in the editor (apply external edits).",
    handler: passthrough("reload_scripts"),
  }),
  tool({
    name: "list_classes",
    description:
      "Query the live Godot 4.7 ClassDB. Without args returns counts; with a filter returns matching class names. " +
      "Use describe_class for details on one class.",
    schema: {
      filter: z.string().optional().describe("Substring/glob to match class names, e.g. 'Light'"),
      inherits: z.string().optional().describe("Only classes deriving from this base"),
      offset: z.number().int().optional(),
      limit: z.number().int().optional().describe("Max names (default 200)"),
    },
    handler: passthrough("list_classes"),
  }),
  tool({
    name: "describe_class",
    description:
      "Introspect one engine class from the live 4.7 ClassDB: parent, method signatures (args + return types), " +
      "properties, signals, enums, constants. Ground-truth API for writing correct 4.7 code.",
    schema: {
      name: z.string().describe("Class name, e.g. 'CharacterBody3D'"),
      members: z
        .array(z.enum(["methods", "properties", "signals", "enums", "constants"]))
        .optional()
        .describe("Which member kinds to include (default all)"),
    },
    handler: passthrough("describe_class"),
  }),
  tool({
    name: "undo",
    description: "Undo the last editor edit. godot-mcp-x mutations (add/delete/rename/move/duplicate node, set property) register with the editor's undo history.",
    handler: passthrough("undo"),
  }),
  tool({
    name: "redo",
    description: "Redo the last undone editor edit.",
    handler: passthrough("redo"),
  }),
  tool({
    name: "get_status",
    description: "godot-mcp-x status: connected MCP server ports, registered command count, and whether a game is playing.",
    handler: passthrough("get_status"),
  }),
];
