import { z } from "zod";
import { tool, passthrough, type ToolDef } from "../core/registry.js";

/** Project file management (res:// paths). Safe: single file / empty folder only. */
export const filesystemTools: ToolDef[] = [
  tool({
    name: "create_folder",
    description: "Create a folder (recursive) under res://.",
    schema: { path: z.string().describe("e.g. 'res://scenes/levels'") },
    handler: passthrough("create_folder"),
  }),
  tool({
    name: "rename_path",
    description: "Rename or move a file/folder. Note: does not rewrite references in other scenes.",
    schema: {
      from: z.string().describe("Existing res:// path"),
      to: z.string().describe("New res:// path"),
    },
    handler: passthrough("rename_path"),
  }),
  tool({
    name: "delete_path",
    description: "Delete a file (also drops its .uid/.import sidecars) or a folder. Folders need recursive=true unless empty.",
    schema: {
      path: z.string().describe("res:// path"),
      recursive: z.boolean().optional().describe("Delete a non-empty folder and its contents (default false)"),
    },
    handler: passthrough("delete_path"),
  }),
  tool({
    name: "duplicate_path",
    description: "Copy a file to a new res:// path.",
    schema: {
      from: z.string().describe("Source file"),
      to: z.string().describe("Destination path"),
    },
    handler: passthrough("duplicate_path"),
  }),
];
