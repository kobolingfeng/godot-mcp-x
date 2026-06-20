import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

export const scriptTools: ToolDef[] = [
  tool({
    name: "read_script",
    description:
      "Read a GDScript file, LINE-PAGINATED. Returns the requested slice plus total_lines — " +
      "use offset/limit to read large files in pieces instead of all at once.",
    schema: {
      path: z.string().describe("res:// path to .gd"),
      offset: z.number().int().optional().describe("First line, 0-based (default 0)"),
      limit: z.number().int().optional().describe("Max lines (default 400)"),
    },
    handler: passthrough("read_script"),
  }),
  tool({
    name: "create_script",
    description: "Create a new GDScript file. Optionally attach it to a node in the current scene.",
    schema: {
      path: z.string().describe("res:// path for the new .gd"),
      content: z.string().describe("Full script source"),
      attach_to: z.string().optional().describe("Scene-relative node path to attach the script to"),
    },
    handler: passthrough("create_script"),
  }),
  tool({
    name: "write_script",
    description: "Overwrite a GDScript file's full contents. Use edit_script for surgical changes.",
    schema: {
      path: z.string().describe("res:// path to .gd"),
      content: z.string().describe("New full source"),
    },
    handler: passthrough("write_script"),
  }),
  tool({
    name: "edit_script",
    description: "Replace an exact substring in a GDScript file (single occurrence). Fails if not found or ambiguous.",
    schema: {
      path: z.string().describe("res:// path to .gd"),
      old_text: z.string().describe("Exact text to replace (must be unique in file)"),
      new_text: z.string().describe("Replacement text"),
    },
    handler: passthrough("edit_script"),
  }),
  tool({
    name: "attach_script",
    description: "Attach an existing script to a node in the current scene.",
    schema: {
      node_path: z.string().describe("Scene-relative node path"),
      script_path: z.string().describe("res:// path to the .gd"),
    },
    handler: passthrough("attach_script"),
  }),
  tool({
    name: "validate_script",
    description: "Parse-check GDScript for errors. Validate a file by path, or inline source via content.",
    schema: {
      path: z.string().optional().describe("res:// path to validate"),
      content: z.string().optional().describe("Inline source to validate instead of a file"),
    },
    handler: passthrough("validate_script"),
  }),
  tool({
    name: "list_scripts",
    description: "List GDScript files in the project (paginated).",
    schema: {
      path: z.string().optional().describe("Root to scan (default res://)"),
      offset: z.number().int().optional(),
      limit: z.number().int().optional().describe("Max results (default 300)"),
    },
    handler: passthrough("list_scripts"),
  }),
];
