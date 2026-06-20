import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { ZodRawShape } from "zod";
import { GodotConnection } from "./connection.js";
import { clampJson, DEFAULT_MAX_CHARS } from "./budget.js";
import { formatErrorForMcp } from "../util/errors.js";

export interface ToolCtx {
  godot: GodotConnection;
}

/**
 * Declarative tool definition. The handler returns plain JSON-serializable data;
 * the registry wraps it with uniform error handling + budget clamping, so tool
 * authors never repeat try/catch or JSON.stringify boilerplate (the original
 * repeated that block 170+ times).
 */
export interface ToolDef {
  name: string;
  description: string;
  /** Zod raw shape (object of zod validators). Omit for no-arg tools. */
  schema?: ZodRawShape;
  /** Per-tool output char ceiling. Defaults to DEFAULT_MAX_CHARS. */
  maxChars?: number;
  handler: (args: Record<string, any>, ctx: ToolCtx) => Promise<unknown> | unknown;
}

/** Convenience identity helper for authoring tools with inferred typing. */
export function tool(def: ToolDef): ToolDef {
  return def;
}

/**
 * Thin handler for the common case: forward args straight to a Godot command of
 * the same name and return its result. Most tools are exactly this.
 */
export function passthrough(method: string): ToolDef["handler"] {
  return async (args, ctx) => ctx.godot.sendCommand(method, args);
}

/** Like passthrough, but routes to the RUNNING GAME (runtime) connection. */
export function runtimePassthrough(method: string): ToolDef["handler"] {
  return async (args, ctx) => ctx.godot.sendCommand(method, args, "runtime");
}

export function registerTools(server: McpServer, godot: GodotConnection, tools: ToolDef[]): void {
  for (const t of tools) {
    server.tool(t.name, t.description, t.schema ?? {}, async (args: Record<string, any>) => {
      try {
        const result = await t.handler(args ?? {}, { godot });
        return clampJson(result, t.maxChars ?? DEFAULT_MAX_CHARS);
      } catch (e) {
        return { content: [{ type: "text" as const, text: formatErrorForMcp(e) }], isError: true };
      }
    });
  }
}
